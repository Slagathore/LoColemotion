param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$sourceCommit = "cedd787f548929c03e114d33f6cdf28c35e62b5f"
$sourceTree = "3f4cce230b2db7ecb5e35d55ac5a4a6493c45177"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d56-20260815T113410Z"
$qualificationRoot = Join-Path $evidenceRoot (
    "r23d56-scoped-attestation-cedd787-20260815T112909Z"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d56_godot_valid_route_actuator_phase_" +
    "characterization_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d56_closure.ps1"
$diagnosticPath = Join-Path $repoRoot (
    "sdk\turning\r23d56_trace_retention_postclosure_diagnostic.py"
)
$classification = (
    "invalid_complete_outcome_exposed_godot_valid_route_actuator_phase_" +
    "characterization_development"
)
$campaignId = (
    "QSDK-R23D56-GODOT-VALID-ROUTE-ACTUATOR-PHASE-" +
    "CHARACTERIZATION-DEVELOPMENT"
)
$rootFailure = "QSDK_R23D56_GJT_TRACE_RETENTION_FAILED:1"
$expectedArms = @("reference_zero", "positive_heading", "negative_heading")
$expectedTargetResidualCounts = @(740, 788, 675)
$expectedAffectedRowCounts = @(692, 727, 632)
$expectedTargetResidualMaxima = @(
    9.769962669640937e-15,
    9.769962643171157e-15,
    9.769962663023492e-15
)
$numericTolerance = 1.0e-24

function Assert-R23D56Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D56 CLOSURE: $Message" }
}

function Assert-R23D56Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D56Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-R23D56Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D56BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D56GitBlobBytes([string]$Commit, [string]$RelativePath) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $repoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    Assert-R23D56Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D56Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D56Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D56Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D56Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D56Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D56Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D56LocalFile(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D56Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-R23D56Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
}

function Assert-R23D56PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D56LocalFile $Path $Sha256 $ByteLength
    $payload = Assert-R23D56Cas $Sha256 $ByteLength
    Assert-R23D56Closure (
        (Get-R23D56Sha256 $payload) -ceq (Get-R23D56Sha256 $Path)
    ) "retained artifact and CAS diverged: $Path"
    return $payload
}

function Add-R23D56CasReceipts(
    $Value,
    [Collections.Generic.List[object]]$Receipts
) {
    if ($null -eq $Value) { return }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $schema = $Value.PSObject.Properties["schema_version"]
        if (
            $null -ne $schema -and
            [string]$schema.Value -ceq
                "sporespore_content_addressed_artifact_receipt_v1"
        ) {
            $Receipts.Add($Value)
        }
        foreach ($property in $Value.PSObject.Properties) {
            Add-R23D56CasReceipts $property.Value $Receipts
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($child in $Value.Values) {
            Add-R23D56CasReceipts $child $Receipts
        }
        return
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            Add-R23D56CasReceipts $child $Receipts
        }
    }
}

function Find-R23D56ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d56_attempt")) {
            return $Value["closed_r23d56_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D56ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d56_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($property in $Value.PSObject.Properties) {
            $found = Find-R23D56ClosedRecord $property.Value
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D56ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D56ClosureSemanticVector($Value) {
    try {
        return (
            [string]$Value.schema_version -ceq
                "sporespore_qsdk_r23d56_godot_valid_route_actuator_phase_characterization_closure_v1" -and
            [string]$Value.status -ceq
                "closed_consumed_invalid_complete_outcome_exposed_godot_valid_route_actuator_phase_characterization_development" -and
            [string]$Value.source_commit -ceq $sourceCommit -and
            [string]$Value.source_tree_git_oid -ceq $sourceTree -and
            [string]$Value.attempt_id -ceq "a5fc8ec49fd84ed28368944016e6fff0" -and
            [bool]$Value.identity_consumed -and
            -not [bool]$Value.same_identity_rerun_allowed -and
            -not [bool]$Value.selective_rerun_allowed -and
            -not [bool]$Value.replacement_rerun_allowed -and
            -not [bool]$Value.successor_campaign_opened -and
            [string]$Value.official_result.classification -ceq $classification -and
            [int]$Value.official_result.observed_world_build_count -eq 3 -and
            [int]$Value.official_result.execution_valid_cell_count -eq 0 -and
            [int]$Value.official_result.diagnostic_complete_raw_trace_row_count -eq 8976 -and
            [int]$Value.official_result.valid_retained_trace_row_count -eq 0 -and
            -not [bool]$Value.official_result.actuator_phase_characterization_complete -and
            -not [bool]$Value.official_result.turning_mechanism_selected -and
            [string]$Value.ordered_cells[0].root_failure_code -ceq $rootFailure -and
            [int]$Value.ordered_cells[0].actual_trace_row_count -eq 2992 -and
            [double]$Value.postclosure_diagnosis.frozen_report_recomputation_consistency_tolerance -eq 1.0e-15 -and
            [int]$Value.postclosure_diagnosis.aggregate.target_report_consistency_over_1e_15_count -eq 2203 -and
            [int]$Value.postclosure_diagnosis.aggregate.target_readback_tolerance_violation_count -eq 0 -and
            [bool]$Value.successor_requirements.distinct_campaign_identity_required -and
            [bool]$Value.successor_requirements.r23d56_rerun_forbidden -and
            [bool]$Value.successor_requirements.fresh_physical_worlds_required_for_any_successor_result -and
            -not [bool]$Value.successor_requirements.retained_r23d56_rows_may_be_promoted_to_a_valid_result -and
            -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
            [bool]$Value.claims.r23d56_complete_three_world_attempt_executed -and
            [bool]$Value.claims.r23d56_complete_raw_rows_preserved -and
            [bool]$Value.claims.r23d56_live_cap_route_conformant_as_postfailure_diagnostic_fact -and
            -not [bool]$Value.claims.r23d56_valid_physical_characterization -and
            -not [bool]$Value.claims.live_fixture_actuator_cap_binding_verified -and
            -not [bool]$Value.claims.actuator_phase_characterization_complete -and
            -not [bool]$Value.claims.turning_mechanism_selected -and
            -not [bool]$Value.claims.godot_jolt_r23d29_turning -and
            -not [bool]$Value.claims.portable_basic_turning -and
            -not [bool]$Value.claims.finite_three_engine_turning -and
            -not [bool]$Value.claims.cross_engine_equivalence -and
            -not [bool]$Value.claims.q_sdk_r23_satisfied -and
            -not [bool]$Value.claims.prone_to_standing -and
            -not [bool]$Value.claims.release_authorized -and
            -not [bool]$Value.claims.physical_acceptance_authority
        )
    } catch { return $false }
}

$gitRoot = [IO.Path]::GetFullPath(
    (git -C $repoRoot rev-parse --show-toplevel).Trim()
).TrimEnd('\', '/')
Assert-R23D56Closure (
    $gitRoot -ieq $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository authority changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D56Closure (Test-R23D56ClosureSemanticVector $closure) (
    "closure identity or immutable disposition changed"
)
Assert-R23D56Closure (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D56" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.question_class -ceq "development" -and
    [int]$closure.campaign_seed -eq 21512 -and
    -not [bool]$closure.fresh_held_out_condition_consumed
) "scientific question class or finite identity changed"

$tree = (git -C $repoRoot show -s --format=%T $sourceCommit).Trim()
Assert-R23D56Closure (
    $LASTEXITCODE -eq 0 -and $tree -ceq $sourceTree
) "source commit or tree is unavailable"
Assert-R23D56Closure (
    (Get-R23D56Sha256 $diagnosticPath) -ceq
        [string]$closure.postclosure_diagnosis.postclosure_diagnostic.raw_sha256 -and
    (Get-Item -LiteralPath $diagnosticPath).Length -eq
        [long]$closure.postclosure_diagnosis.postclosure_diagnostic.byte_length -and
    -not [bool]$closure.postclosure_diagnosis.postclosure_diagnostic.writes_evidence -and
    -not [bool]$closure.postclosure_diagnosis.postclosure_diagnostic.reinterprets_r23d56
) "postclosure diagnostic source changed"

$attestationSpec = $closure.qualification_history.accepted_scoped_attestation
$adoptionSpec = $closure.qualification_history.adoption
$attestationPayload = Assert-R23D56PathAndCas (
    [string]$attestationSpec.path
) ([string]$attestationSpec.raw_sha256) ([long]$attestationSpec.byte_length)
$adoptionPayload = Assert-R23D56PathAndCas (
    [string]$adoptionSpec.path
) ([string]$adoptionSpec.raw_sha256) ([long]$adoptionSpec.byte_length)
$attestation = Get-Content -Raw -LiteralPath $attestationPayload |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath $adoptionPayload |
    ConvertFrom-Json -Depth 100
$gateCasReferences = @(
    foreach ($gate in $attestation.gate_receipts) {
        $gate.stdout_cas
        $gate.stderr_cas
        $gate.receipt_cas
    }
)
Assert-R23D56Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_v1" -and
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.campaign_id -ceq $campaignId -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 6 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 21 -and
    @($attestation.gate_receipts).Count -eq 21 -and
    @($attestation.core_source_bindings).Count -eq 11 -and
    @($attestation.campaign_source_bindings).Count -eq 27 -and
    @($attestation.campaign_role_bindings).Count -eq 3 -and
    $gateCasReferences.Count -eq 63 -and
    @($attestation.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.exit_code -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0 -or
        [int]$_.physical_world_count -ne 0
    }).Count -eq 0 -and
    [bool]$attestation.claims.campaign_local_qualification_passed -and
    -not [bool]$attestation.claims.physical_launch_prerequisite_satisfied -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.scientific_result -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.release_authority -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "accepted zero-world qualification changed"
Assert-R23D56Closure (
    [string]$adoption.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_adoption_v1" -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$attestationSpec.raw_sha256 -and
    [int]$adoption.executed_gate_count -eq 21 -and
    [int]$adoption.gate_cas_object_count -eq 63 -and
    [bool]$adoption.commissioned_executor_verified -and
    [bool]$adoption.campaign_local_attestation_verified -and
    [bool]$adoption.all_gate_cas_objects_verified -and
    [bool]$adoption.runtime_matches_commissioning -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "campaign-local adoption changed"

$inventory = @($closure.physical_evidence.file_inventory)
Assert-R23D56Closure (
    $inventory.Count -eq 21 -and
    @($inventory | Where-Object { $_.relative_path -like '*.json' }).Count -eq 15 -and
    @($inventory | Where-Object { $_.relative_path -like '*.rows.json' }).Count -eq 3 -and
    @($inventory | Where-Object {
        $_.relative_path -like '*.trace-diagnostic.json'
    }).Count -eq 3
) "retained evidence inventory declaration changed"
$actualFiles = @(
    Get-ChildItem -LiteralPath $attemptRoot -File -Recurse | Sort-Object FullName
)
Assert-R23D56Closure ($actualFiles.Count -eq 21) (
    "retained evidence tree file count changed"
)
$inventoryByPath = @{}
foreach ($entry in $inventory) {
    $relative = [string]$entry.relative_path
    Assert-R23D56Closure (-not $inventoryByPath.ContainsKey($relative)) (
        "duplicate retained inventory path: $relative"
    )
    $inventoryByPath[$relative] = $entry
    $localPath = Join-Path $attemptRoot $relative
    if ($relative -like '*.rows.json') {
        Assert-R23D56LocalFile (
            $localPath
        ) ([string]$entry.raw_sha256) ([long]$entry.byte_length)
    } else {
        [void](Assert-R23D56PathAndCas (
            $localPath
        ) ([string]$entry.raw_sha256) ([long]$entry.byte_length))
    }
}
foreach ($file in $actualFiles) {
    $relative = [IO.Path]::GetRelativePath($attemptRoot, $file.FullName).
        Replace('\', '/')
    Assert-R23D56Closure ($inventoryByPath.ContainsKey($relative)) (
        "unbound local evidence file: $relative"
    )
}

$allReceipts = [Collections.Generic.List[object]]::new()
$metadataJson = @($inventory | Where-Object {
    $_.relative_path -like '*.json' -and
    $_.relative_path -notlike 'pending-traces/*'
})
Assert-R23D56Closure ($metadataJson.Count -eq 9) (
    "metadata JSON file count changed"
)
foreach ($entry in $metadataJson) {
    $value = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot ([string]$entry.relative_path)
    ) | ConvertFrom-Json -Depth 100
    Add-R23D56CasReceipts $value $allReceipts
}
foreach ($entry in $inventory | Where-Object {
    $_.relative_path -like 'pending-traces/*.json'
}) {
    $hasReceipt = Select-String -LiteralPath (
        Join-Path $attemptRoot ([string]$entry.relative_path)
    ) -SimpleMatch "sporespore_content_addressed_artifact_receipt_v1" -Quiet
    Assert-R23D56Closure (-not $hasReceipt) (
        "unaccounted nested CAS receipt in $($entry.relative_path)"
    )
}
$uniqueReceipts = @{}
foreach ($receipt in $allReceipts) {
    $digest = [string]$receipt.sha256
    $length = [long]$receipt.byte_length
    if ($uniqueReceipts.ContainsKey($digest)) {
        Assert-R23D56Closure ([long]$uniqueReceipts[$digest] -eq $length) (
            "one CAS digest declared multiple byte lengths: $digest"
        )
    } else {
        $uniqueReceipts[$digest] = $length
    }
}
Assert-R23D56Closure (
    $allReceipts.Count -eq 220 -and $uniqueReceipts.Count -eq 116 -and
    [int]$closure.physical_evidence.content_addressed_receipt_reference_count -eq 220 -and
    [int]$closure.physical_evidence.content_addressed_unique_object_count -eq 116 -and
    [int]$closure.physical_evidence.unbound_local_file_count -eq 0 -and
    [bool]$closure.physical_evidence.raw_rows_exactly_mirrored_inside_cas_diagnostics
) "complete evidence graph cardinality changed"
foreach ($receipt in $uniqueReceipts.GetEnumerator()) {
    [void](Assert-R23D56Cas ([string]$receipt.Key) ([long]$receipt.Value))
}

$freeze = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "physical-freeze.json"
) | ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "attempt-authorization.json"
) | ConvertFrom-Json -Depth 100
$terminalManifest = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "terminal-paths.json"
) | ConvertFrom-Json -Depth 30
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "complete-evaluation.json"
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "report.json"
) | ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "completion.json"
) | ConvertFrom-Json -Depth 30
Assert-R23D56Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d56_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 96 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 96 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 4 -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze or complete zero-world prerequisite changed"
Assert-R23D56Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d56_attempt_v1" -and
    [string]$authorization.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.freeze_raw_sha256 -ceq
        [string]$closure.physical_evidence.physical_freeze.raw_sha256 -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.matrix_authorization_immutable_before_first_world -and
    [bool]$authorization.source_worktree_clean -and
    [bool]$authorization.source_matches_live_github_main -and
    [bool]$authorization.operation_lock_held -and
    [bool]$authorization.campaign_attestation_adoption_valid -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    [bool]$authorization.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$authorization.physical_acceptance_authority
) "attempt authorization changed"
Assert-R23D56Closure (
    [string]$completion.schema_version -ceq
        "sporespore_qsdk_r23d56_completion_v1" -and
    [string]$completion.status -ceq $classification -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.attempt_id -ceq [string]$closure.attempt_id -and
    [int]$completion.cell_count -eq 3 -and
    [int]$completion.world_count -eq 3 -and
    [bool]$completion.world_count_exact -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$report.result_classification -ceq $classification -and
    [bool]$report.all_three_cells_executed_or_retained_as_failures -and
    [bool]$report.world_build_count_exact -and
    [int]$report.world_build_count_lower_bound -eq 3 -and
    [int]$report.world_build_count_upper_bound -eq 3 -and
    -not [bool]$report.terminal_restoration_or_taper_invoked -and
    [string]$evaluation.classification -ceq $classification -and
    [int]$evaluation.cell_count -eq 3 -and
    [bool]$evaluation.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$evaluation.all_declared_cells_executed_or_retained_as_failures -and
    -not [bool]$evaluation.engine_result.all_cells_execution_valid -and
    -not [bool]$evaluation.engine_result.live_fixture_actuator_cap_binding_verified -and
    -not [bool]$evaluation.engine_result.actuator_phase_characterization_complete -and
    -not [bool]$evaluation.engine_result.turning_gate_invoked -and
    -not [bool]$evaluation.engine_result.turning_mechanism_selected
) "complete invalid disposition changed"

Assert-R23D56Closure (
    @($closure.ordered_cells).Count -eq 3 -and
    @($report.ordered_cells).Count -eq 3 -and
    @($evaluation.cell_evaluations).Count -eq 3 -and
    @($terminalManifest).Count -eq 3
) "ordered finite matrix count changed"
for ($index = 0; $index -lt 3; $index++) {
    $spec = $closure.ordered_cells[$index]
    $terminal = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot ([string]$spec.terminal_relative_path)
    ) | ConvertFrom-Json -Depth 100
    $reported = $report.ordered_cells[$index]
    $evaluated = $evaluation.cell_evaluations[$index]
    $traceDiagnostic = $terminal.trace_diagnostic
    $cap = $terminal.raw_sdk_authority_summary.
        r23d56_live_fixture_actuator_cap_binding_receipt
    Assert-R23D56Closure (
        [string]$spec.arm_id -ceq $expectedArms[$index] -and
        [string]$terminalManifest[$index] -ceq (
            Join-Path (
                Join-Path $artifactRoot (
                    [string]$spec.terminal_raw_sha256
                ).Substring(7)
            ) "payload.bin"
        ) -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d56_worker_failure_v1" -and
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq [string]$spec.cell_id -and
        [string]$terminal.arm_id -ceq [string]$spec.arm_id -and
        [string]$terminal.failure_code -ceq $rootFailure -and
        [int]$terminal.world_attempt_count -eq 1 -and
        [int]$terminal.world_build_count -eq 1 -and
        $null -eq $terminal.trace_artifact -and
        [string]$traceDiagnostic.schema_version -ceq
            "sporespore_qsdk_r23d56_trace_diagnostic_v1" -and
        @($traceDiagnostic.failure_codes).Count -eq 0 -and
        [int]$traceDiagnostic.declared_row_count -eq 2992 -and
        [int]$traceDiagnostic.actual_row_count -eq 2992 -and
        [int]$traceDiagnostic.reported_row_count -eq 2992 -and
        [int]$traceDiagnostic.contiguous_row_count -eq 2992 -and
        [int]$traceDiagnostic.first_missing_semantic_step -eq 2992 -and
        [bool]$traceDiagnostic.complete -and
        [string]$terminal.trace_diagnostic_artifact.sha256 -ceq
            [string]$spec.diagnostic_raw_sha256 -and
        [int]$reported.process.exit_code -eq 1 -and
        -not [bool]$reported.process.timed_out -and
        [bool]$reported.process.supervisor_terminated -and
        [bool]$reported.process.termination_protocol_valid -and
        [string]$reported.terminal_schema -ceq
            "sporespore_qsdk_r23d56_worker_failure_v1" -and
        [string]$evaluated.entry_kind -ceq "worker_failure" -and
        -not [bool]$evaluated.execution_valid -and
        (@($evaluated.failed_gate_ids) -join ',') -ceq $rootFailure -and
        [bool]$terminal.raw_sdk_authority_summary.ok -and
        [string]$terminal.raw_sdk_authority_summary.failure_code -ceq "" -and
        [bool]$terminal.raw_sdk_authority_summary.
            r23d56_live_fixture_actuator_cap_binding_integrity_passed -and
        [bool]$cap.ok -and
        [int]$cap.write_count -eq 8 -and
        [int]$cap.readback_count -eq 8 -and
        [int]$cap.validated_actuator_count -eq 8 -and
        [int]$cap.unique_host_joint_object_count -eq 8 -and
        [int]$cap.prebinding_mismatch_count -eq 8 -and
        [bool]$cap.all_postbinding_readbacks_match -and
        [bool]$cap.configured_parameter_readback_only -and
        -not [bool]$cap.measured_motor_torque_available -and
        -not [bool]$cap.measured_motor_impulse_available -and
        [int]$spec.target_report_consistency_over_1e_15_count -eq
            $expectedTargetResidualCounts[$index] -and
        [int]$spec.target_report_consistency_affected_row_count -eq
            $expectedAffectedRowCounts[$index]
    ) "cell $index retained failure or cap receipt changed"
    Assert-R23D56Near (
        [double]$cap.maximum_postbinding_readback_error_nms
    ) 1.85094532756391e-9 $numericTolerance (
        "cell $index cap readback maximum changed"
    )
    Assert-R23D56Near (
        [double]$spec.maximum_target_report_recomputation_residual_rad_s
    ) $expectedTargetResidualMaxima[$index] $numericTolerance (
        "cell $index target report residual changed"
    )
}

foreach ($claimSet in @($evaluation.claims, $report.claims)) {
    Assert-R23D56Closure (
        -not [bool]$claimSet.live_fixture_actuator_cap_binding_verified -and
        -not [bool]$claimSet.actuator_phase_characterization_complete -and
        -not [bool]$claimSet.turning_mechanism_selected -and
        -not [bool]$claimSet.godot_jolt_r23d29_turning -and
        -not [bool]$claimSet.finite_three_engine_turning -and
        -not [bool]$claimSet.portable_basic_turning -and
        -not [bool]$claimSet.q_sdk_r23_satisfied -and
        -not [bool]$claimSet.cross_engine_equivalence -and
        -not [bool]$claimSet.population_robustness -and
        -not [bool]$claimSet.prone_to_standing -and
        -not [bool]$claimSet.release_authorized -and
        -not [bool]$claimSet.physical_acceptance_authority
    ) "stored physical claim vector changed"
}

$diagnosticSources = @($closure.postclosure_diagnosis.frozen_source_bindings)
Assert-R23D56Closure ($diagnosticSources.Count -eq 5) (
    "postclosure frozen source count changed"
)
$sourceText = @{}
foreach ($source in $diagnosticSources) {
    $relative = [string]$source.path
    $bytes = Get-R23D56GitBlobBytes $sourceCommit $relative
    $oid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D56Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$source.git_blob_oid -and
        $bytes.Length -eq [long]$source.byte_length -and
        (Get-R23D56BytesSha256 $bytes) -ceq [string]$source.raw_sha256
    ) "historical diagnostic source changed: $relative"
    $sourceText[$relative] = [Text.Encoding]::UTF8.GetString($bytes)
    $matching = @($freeze.source_bindings | Where-Object {
        [string]$_.path -ceq $relative
    })
    Assert-R23D56Closure ($matching.Count -eq 1) (
        "direct physical source binding missing: $relative"
    )
    $sourceIndex = [Array]::IndexOf(
        [object[]]@($freeze.source_bindings), $matching[0]
    )
    $receipt = $freeze.content_addressed_inputs.source_bindings[$sourceIndex]
    Assert-R23D56Closure (
        $sourceIndex -ge 0 -and
        [string]$matching[0].git_blob_oid -ceq [string]$source.git_blob_oid -and
        [string]$matching[0].raw_sha256 -ceq [string]$source.raw_sha256 -and
        [string]$receipt.sha256 -ceq [string]$source.raw_sha256 -and
        [long]$receipt.byte_length -eq [long]$source.byte_length
    ) "direct physical source identity changed: $relative"
    [void](Assert-R23D56Cas (
        [string]$receipt.sha256
    ) ([long]$receipt.byte_length))
}
$evaluatorText = [string]$sourceText[
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_evaluator.py"
]
Assert-R23D56Closure (
    $evaluatorText.Contains(
        "abs(target_error - abs(target_readback - applied)) <= 1.0e-15"
    ) -and
    $evaluatorText.Contains(
        "abs(impulse_error - abs(impulse_readback - declared_impulse))"
    ) -and
    $evaluatorText.Contains("<= 1.0e-15")
) "frozen report-consistency predicate changed"

# Rebuild the exact frozen SDK evaluator namespace and run both its original
# complete evaluator and today's read-only diagnostic against retained files.
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempBase (
    "sporespore-r23d56-closure-" + [Guid]::NewGuid().ToString("N")
)))
$tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
Assert-R23D56Closure (
    $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)
) "temporary evaluator root escaped system temp"
try {
    for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
        $binding = $freeze.source_bindings[$index]
        $relative = [string]$binding.path
        if ($relative -notmatch '^sdk/') { continue }
        $sourcePayload = [string](
            $freeze.content_addressed_inputs.source_bindings[$index].payload_path
        )
        $destination = Join-Path $tempRoot $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath $sourcePayload -Destination $destination
    }
    $evaluatorPath = Join-Path $tempRoot (
        "sdk\turning\r23d56_godot_valid_route_actuator_phase_" +
        "characterization_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D56Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $evaluationMarker = "QSDK_R23D56_COMPLETE_EVALUATION "
    $evaluationLines = @($evaluatorOutput | Where-Object {
        $_.StartsWith($evaluationMarker)
    })
    Assert-R23D56Closure ($evaluationLines.Count -eq 1) (
        "pinned evaluator marker changed"
    )
    $recomputedEvaluation = $evaluationLines[0].Substring(
        $evaluationMarker.Length
    ) | ConvertFrom-Json -Depth 100
    Assert-R23D56Closure (
        ($recomputedEvaluation | ConvertTo-Json -Depth 100 -Compress) -ceq
        ($evaluation | ConvertTo-Json -Depth 100 -Compress)
    ) "pinned evaluator no longer reproduces the complete invalid evaluation"

    $diagnosticOutput = @(& $Python $diagnosticPath `
        --source-root $tempRoot --attempt-root $attemptRoot `
        --expected-source-commit $sourceCommit 2>&1)
    Assert-R23D56Closure ($LASTEXITCODE -eq 0) ($diagnosticOutput -join "`n")
    $diagnosticMarker = "QSDK_R23D56_POSTCLOSURE_DIAGNOSTIC "
    $diagnosticLines = @($diagnosticOutput | Where-Object {
        $_.StartsWith($diagnosticMarker)
    })
    Assert-R23D56Closure ($diagnosticLines.Count -eq 1) (
        "postclosure diagnostic marker changed"
    )
    $diagnostic = $diagnosticLines[0].Substring($diagnosticMarker.Length) |
        ConvertFrom-Json -Depth 100
    Assert-R23D56Closure (
        [string]$diagnostic.schema_version -ceq
            "sporespore_qsdk_r23d56_trace_retention_postclosure_diagnostic_v1" -and
        [string]$diagnostic.source_commit -ceq $sourceCommit -and
        [int]$diagnostic.cell_count -eq 3 -and
        [int]$diagnostic.row_count -eq 8976 -and
        [int]$diagnostic.application_count -eq 71808 -and
        [int]$diagnostic.target_report_consistency_over_frozen_tolerance_count -eq 2203 -and
        [int]$diagnostic.target_report_consistency_affected_row_count -eq 2051 -and
        [bool]$diagnostic.all_other_primitive_actuator_link_failure_counts_zero -and
        [bool]$diagnostic.live_fixture_actuator_cap_route_observed_conformant -and
        -not [bool]$diagnostic.reference_only_1e_12_tolerance_is_successor_authority -and
        -not [bool]$diagnostic.configured_readback_is_measured_torque_or_impulse -and
        [bool]$diagnostic.r23d56_remains_invalid_complete -and
        -not [bool]$diagnostic.r23d56_result_reinterpreted -and
        -not [bool]$diagnostic.turning_result -and
        -not [bool]$diagnostic.physical_acceptance_authority
    ) "postclosure aggregate diagnosis changed"
    for ($index = 0; $index -lt 3; $index++) {
        $cell = $diagnostic.cells[$index]
        Assert-R23D56Closure (
            [string]$cell.arm_id -ceq $expectedArms[$index] -and
            [int]$cell.row_count -eq 2992 -and
            [int]$cell.application_count -eq 23936 -and
            [bool]$cell.raw_rows_equal_diagnostic_rows -and
            [int]$cell.primitive_predicate_counts.
                target_report_consistency_over_frozen_tolerance_count -eq
                $expectedTargetResidualCounts[$index] -and
            [int]$cell.target_report_consistency_affected_row_count -eq
                $expectedAffectedRowCounts[$index] -and
            [int]$cell.first_target_report_consistency_failure.semantic_step -eq 100 -and
            [int]$cell.first_target_report_consistency_failure.application_index -eq 1 -and
            [string]$cell.first_target_report_consistency_failure.actuator_id -ceq
                "front_left_knee_motor" -and
            [int]$cell.primitive_predicate_counts.
                target_report_consistency_over_reference_1e_12_count -eq 0 -and
            [int]$cell.primitive_predicate_counts.
                impulse_report_consistency_over_frozen_tolerance_count -eq 0 -and
            [int]$cell.primitive_predicate_counts.
                target_readback_tolerance_violation_count -eq 0 -and
            [int]$cell.primitive_predicate_counts.
                impulse_readback_tolerance_violation_count -eq 0 -and
            [int]$cell.primitive_predicate_counts.phase_link_mismatch_count -eq 0 -and
            [int]$cell.primitive_predicate_counts.contact_link_mismatch_count -eq 0 -and
            [string]$cell.frozen_evaluator_first_failure_codes[0] -ceq
                "R23D56_OBSERVATION_APPLICATION_LINK:1:100" -and
            [bool]$cell.downstream_cardinality_and_identity_failures_are_link_omission_projections -and
            [bool]$cell.raw_sdk_authority_summary_ok -and
            [int]$cell.cap_binding_write_count -eq 8 -and
            [int]$cell.cap_binding_readback_count -eq 8
        ) "postclosure cell $index diagnosis changed"
    }
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedCleanup = [IO.Path]::GetFullPath($tempRoot)
        Assert-R23D56Closure (
            $resolvedCleanup.StartsWith(
                $tempPrefix, [StringComparison]::OrdinalIgnoreCase
            )
        ) "temporary cleanup target escaped system temp"
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
}

$mutations = @(
    { param($v) $v.status = "closed_positive" },
    { param($v) $v.source_commit = "0" * 40 },
    { param($v) $v.attempt_id = "different" },
    { param($v) $v.same_identity_rerun_allowed = $true },
    { param($v) $v.successor_campaign_opened = $true },
    { param($v) $v.official_result.classification = "valid_complete_positive" },
    { param($v) $v.official_result.observed_world_build_count = 2 },
    { param($v) $v.official_result.execution_valid_cell_count = 1 },
    { param($v) $v.official_result.diagnostic_complete_raw_trace_row_count = 0 },
    { param($v) $v.ordered_cells[0].root_failure_code = "different" },
    { param($v) $v.ordered_cells[0].actual_trace_row_count = 0 },
    { param($v) $v.postclosure_diagnosis.frozen_report_recomputation_consistency_tolerance = 1e-12 },
    { param($v) $v.postclosure_diagnosis.aggregate.target_report_consistency_over_1e_15_count = 0 },
    { param($v) $v.successor_requirements.retained_r23d56_rows_may_be_promoted_to_a_valid_result = $true },
    { param($v) $v.successor_requirements.physical_successor_authorized_by_this_closure = $true },
    { param($v) $v.claims.r23d56_valid_physical_characterization = $true },
    { param($v) $v.claims.live_fixture_actuator_cap_binding_verified = $true },
    { param($v) $v.claims.godot_jolt_r23d29_turning = $true },
    { param($v) $v.claims.prone_to_standing = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D56ClosureSemanticVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D56Closure ($mutationRejectionCount -eq $mutations.Count) (
    "closure semantic mutation controls changed"
)

$releaseContract = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
) | ConvertFrom-Json -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
) | ConvertFrom-Json -Depth 100
$turningGate = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$contractRecord = if ($turningGate.Count -eq 1) {
    $turningGate[0].proof.closed_r23d56_attempt
} else { $null }
$matrixRecord = Find-R23D56ClosedRecord $supportMatrix
$closureHash = Get-R23D56Sha256 $closurePath
$auditHash = Get-R23D56Sha256 $closureAuditPath
Assert-R23D56Closure (
    $turningGate.Count -eq 1 -and
    $null -ne $contractRecord -and $null -ne $matrixRecord -and
    [string]$contractRecord.status -ceq [string]$closure.status -and
    [string]$matrixRecord.status -ceq [string]$closure.status -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.closure_audit_path -ceq
        "tests/test_qsdk_r23d56_closure.ps1" -and
    [string]$matrixRecord.closure_audit_path -ceq
        [string]$contractRecord.closure_audit_path -and
    [string]$contractRecord.closure_audit_raw_sha256 -ceq $auditHash -and
    [string]$matrixRecord.closure_audit_sha256 -ceq $auditHash -and
    [string]$contractRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$matrixRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$contractRecord.attempt_id -ceq [string]$closure.attempt_id -and
    [string]$matrixRecord.attempt_id -ceq [string]$closure.attempt_id -and
    [int]$contractRecord.observed_world_build_count -eq 3 -and
    [int]$matrixRecord.observed_world_build_count -eq 3 -and
    [int]$contractRecord.execution_valid_cell_count -eq 0 -and
    [int]$matrixRecord.execution_valid_cell_count -eq 0 -and
    [int]$contractRecord.diagnostic_complete_raw_trace_row_count -eq 8976 -and
    [int]$matrixRecord.diagnostic_complete_raw_trace_row_count -eq 8976 -and
    [int]$contractRecord.valid_retained_trace_row_count -eq 0 -and
    [int]$matrixRecord.valid_retained_trace_row_count -eq 0 -and
    [bool]$contractRecord.identity_consumed -and
    [bool]$matrixRecord.identity_consumed -and
    -not [bool]$contractRecord.same_identity_rerun_allowed -and
    -not [bool]$matrixRecord.same_identity_rerun_allowed -and
    [int]$contractRecord.target_report_consistency_over_1e_15_count -eq 2203 -and
    [int]$matrixRecord.target_report_consistency_over_1e_15_count -eq 2203 -and
    [bool]$contractRecord.live_cap_route_conformant_as_postfailure_diagnostic_fact -and
    [bool]$matrixRecord.live_cap_route_conformant_as_postfailure_diagnostic_fact -and
    -not [bool]$contractRecord.live_fixture_actuator_cap_binding_verified -and
    -not [bool]$matrixRecord.live_fixture_actuator_cap_binding_verified -and
    -not [bool]$contractRecord.actuator_phase_characterization_complete -and
    -not [bool]$matrixRecord.actuator_phase_characterization_complete -and
    -not [bool]$contractRecord.turning_mechanism_selected -and
    -not [bool]$matrixRecord.turning_mechanism_selected -and
    -not [bool]$contractRecord.godot_jolt_turning_validation -and
    -not [bool]$matrixRecord.godot_jolt_turning_validation -and
    -not [bool]$contractRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
    -not [bool]$contractRecord.q_sdk_r23_satisfied -and
    -not [bool]$matrixRecord.q_sdk_r23_satisfied -and
    -not [bool]$contractRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized -and
    -not [bool]$contractRecord.physical_acceptance_authority -and
    -not [bool]$matrixRecord.physical_acceptance_authority
) "release contract or support matrix closure boundary changed"

$completedAttempts = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
        $_.Name -like "qsdk-r23d56-20*" -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
    }
)
Assert-R23D56Closure (
    $completedAttempts.Count -eq 1 -and
    $completedAttempts[0].FullName -ceq $attemptRoot
) "R23D56 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D56_CLOSURE_PASS classification=complete_invalid worlds=3 " +
    "execution_valid=0 raw_rows=8976 valid_rows=0 applications=71808 " +
    "cap_route_diagnostic=True target_report_roundtrip_failures=2203 " +
    "other_primitive_link_failures=0 evaluator_replay=True cas_refs=220 " +
    "cas_unique=116 mutations=$mutationRejectionCount rerun=False " +
    "turning=False prone=False release=False"
)
