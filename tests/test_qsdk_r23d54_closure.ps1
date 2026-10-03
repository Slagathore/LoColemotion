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
$sourceCommit = "0026a06eb7a3eaf17ad67b894304af918a38ef14"
$sourceTree = "8135f3ca1efda447749f2c2621d4071ea91f26d1"
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d54-20260815T061333Z"
$qualificationRoot = Join-Path $evidenceRoot (
    "r23d54-scoped-attestation-0026a06-20260815T060115Z"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d54_godot_actuator_phase_characterization_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d54_closure.ps1"
$classification = (
    "invalid_complete_outcome_exposed_godot_actuator_phase_" +
    "characterization_development"
)
$campaignId = "QSDK-R23D54-GODOT-ACTUATOR-PHASE-CHARACTERIZATION-DEVELOPMENT"
$traceFailure = "SDK_ACTUATOR_PHASE_APPLICATION_MISMATCH:front_left_hip_motor"
$rootFailure = "QSDK_R23D54_GJT_TRACE_INCOMPLETE"
$expectedArms = @("reference_zero", "positive_heading", "negative_heading")
$numericTolerance = 1.0e-15

function Assert-R23D54Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D54 CLOSURE: $Message" }
}

function Assert-R23D54Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D54Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-R23D54Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D54BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D54GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D54Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D54Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D54Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D54Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D54Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D54Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D54Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D54PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D54Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-R23D54Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
    $payload = Assert-R23D54Cas $Sha256 $ByteLength
    Assert-R23D54Closure (
        (Get-R23D54Sha256 $payload) -ceq (Get-R23D54Sha256 $Path)
    ) "retained artifact and CAS diverged: $Path"
    return $payload
}

function Add-R23D54CasReceipts(
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
            Add-R23D54CasReceipts $property.Value $Receipts
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($child in $Value.Values) {
            Add-R23D54CasReceipts $child $Receipts
        }
        return
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            Add-R23D54CasReceipts $child $Receipts
        }
    }
}

function Find-R23D54ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d54_attempt")) {
            return $Value["closed_r23d54_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D54ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d54_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($property in $Value.PSObject.Properties) {
            $found = Find-R23D54ClosedRecord $property.Value
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D54ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D54ClosureSemanticVector($Value) {
    try {
        return (
            [string]$Value.schema_version -ceq
                "sporespore_qsdk_r23d54_godot_actuator_phase_characterization_closure_v1" -and
            [string]$Value.status -ceq
                "closed_consumed_invalid_complete_outcome_exposed_godot_actuator_phase_characterization_development" -and
            [string]$Value.source_commit -ceq $sourceCommit -and
            [string]$Value.source_tree_git_oid -ceq $sourceTree -and
            [string]$Value.attempt_id -ceq "fe1bbcb35961481da3b86275aabd752d" -and
            [bool]$Value.identity_consumed -and
            -not [bool]$Value.same_identity_rerun_allowed -and
            -not [bool]$Value.selective_rerun_allowed -and
            -not [bool]$Value.replacement_rerun_allowed -and
            -not [bool]$Value.successor_campaign_opened -and
            [string]$Value.official_result.classification -ceq $classification -and
            [int]$Value.official_result.observed_world_build_count -eq 3 -and
            [int]$Value.official_result.execution_valid_cell_count -eq 0 -and
            [int]$Value.official_result.valid_trace_row_count -eq 0 -and
            -not [bool]$Value.official_result.actuator_phase_characterization_complete -and
            -not [bool]$Value.official_result.turning_gate_invoked -and
            -not [bool]$Value.official_result.turning_mechanism_selected -and
            [string]$Value.ordered_cells[0].trace_failure_code -ceq $traceFailure -and
            [int]$Value.ordered_cells[0].first_missing_semantic_step -eq 0 -and
            [double]$Value.postclosure_diagnosis.first_ordered_actuator.frozen_readback_tolerance_nms -eq
                2.5e-7 -and
            [double]$Value.postclosure_diagnosis.compiled_descriptor.front_hip_maximum_impulse_nms -eq
                0.05362625170687301 -and
            [bool]$Value.successor_requirements.distinct_campaign_identity_required -and
            [bool]$Value.successor_requirements.r23d54_rerun_forbidden -and
            -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
            [bool]$Value.claims.r23d54_complete_three_world_attempt_executed -and
            [bool]$Value.claims.r23d54_live_actuator_application_nonconformance_observed -and
            [bool]$Value.claims.static_source_comparison_proves_impulse_cap_mismatch_sufficient_for_observed_composite_failure -and
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
Assert-R23D54Closure (
    $gitRoot -ieq $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository authority changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D54Closure (Test-R23D54ClosureSemanticVector $closure) (
    "closure identity or immutable disposition changed"
)
Assert-R23D54Closure (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D54" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.question_class -ceq "development" -and
    [int]$closure.campaign_seed -eq 21512 -and
    -not [bool]$closure.fresh_held_out_condition_consumed
) "scientific question class or finite identity changed"

$tree = (git -C $repoRoot show -s --format=%T $sourceCommit).Trim()
Assert-R23D54Closure (
    $LASTEXITCODE -eq 0 -and $tree -ceq $sourceTree
) "source commit or tree is unavailable"

$qualification = $closure.qualification_history
$attestationSpec = $qualification.accepted_scoped_attestation
$adoptionSpec = $qualification.adoption
$attestationPayload = Assert-R23D54PathAndCas (
    [string]$attestationSpec.path
) ([string]$attestationSpec.raw_sha256) ([long]$attestationSpec.byte_length)
$adoptionPayload = Assert-R23D54PathAndCas (
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
Assert-R23D54Closure (
    [string]$attestation.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_v1" -and
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.campaign_id -ceq $campaignId -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.global_gate_count -eq 12 -and
    [int]$attestation.lineage_gate_count -eq 3 -and
    [int]$attestation.campaign_gate_count -eq 3 -and
    [int]$attestation.executed_gate_count -eq 18 -and
    @($attestation.gate_receipts).Count -eq 18 -and
    @($attestation.core_source_bindings).Count -eq 11 -and
    @($attestation.campaign_source_bindings).Count -eq 55 -and
    @($attestation.campaign_role_bindings).Count -eq 3 -and
    $gateCasReferences.Count -eq 54 -and
    @($attestation.gate_receipts | Where-Object {
        -not [bool]$_.passed -or [int]$_.exit_code -ne 0 -or
        [int]$_.physical_process_launch_count -ne 0 -or
        [int]$_.physical_world_count -ne 0
    }).Count -eq 0 -and
    [bool]$attestation.claims.campaign_local_qualification_passed -and
    -not [bool]$attestation.claims.physical_launch_prerequisite_satisfied -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.scientific_result -and
    -not [bool]$attestation.claims.walking_acceptance -and
    -not [bool]$attestation.claims.turning_acceptance -and
    -not [bool]$attestation.claims.release_authority -and
    -not [bool]$attestation.claims.physical_acceptance_authority
) "accepted zero-world qualification changed"
Assert-R23D54Closure (
    [string]$adoption.schema_version -ceq
        "sporespore_locomotion_campaign_attestation_adoption_v1" -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$attestationSpec.raw_sha256 -and
    [int]$adoption.executed_gate_count -eq 18 -and
    [int]$adoption.gate_cas_object_count -eq 54 -and
    [bool]$adoption.commissioned_executor_verified -and
    [bool]$adoption.campaign_local_attestation_verified -and
    [bool]$adoption.all_gate_cas_objects_verified -and
    [bool]$adoption.runtime_matches_commissioning -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority -and
    [bool]$adoption.claims.commissioned_executor_verified -and
    [bool]$adoption.claims.campaign_local_qualification_passed -and
    [bool]$adoption.claims.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.claims.physical_campaign_executed -and
    -not [bool]$adoption.claims.scientific_result -and
    -not [bool]$adoption.claims.walking_acceptance -and
    -not [bool]$adoption.claims.turning_acceptance -and
    -not [bool]$adoption.claims.release_authority -and
    -not [bool]$adoption.claims.physical_acceptance_authority
) "campaign-local adoption changed"

$inventory = @($closure.physical_evidence.file_inventory)
Assert-R23D54Closure (
    $inventory.Count -eq 18 -and
    @($inventory | Where-Object { $_.relative_path -like '*.json' }).Count -eq 12
) "retained evidence inventory declaration changed"
$actualFiles = @(
    Get-ChildItem -LiteralPath $attemptRoot -File -Recurse |
        Sort-Object FullName
)
Assert-R23D54Closure ($actualFiles.Count -eq 18) (
    "retained evidence tree file count changed"
)
$inventoryByPath = @{}
foreach ($entry in $inventory) {
    $relative = [string]$entry.relative_path
    Assert-R23D54Closure (-not $inventoryByPath.ContainsKey($relative)) (
        "duplicate retained inventory path: $relative"
    )
    $inventoryByPath[$relative] = $entry
    [void](Assert-R23D54PathAndCas (
        (Join-Path $attemptRoot $relative)
    ) ([string]$entry.raw_sha256) ([long]$entry.byte_length))
}
foreach ($file in $actualFiles) {
    $relative = [IO.Path]::GetRelativePath($attemptRoot, $file.FullName).
        Replace('\', '/')
    Assert-R23D54Closure ($inventoryByPath.ContainsKey($relative)) (
        "unbound local evidence file: $relative"
    )
}

$allReceipts = [Collections.Generic.List[object]]::new()
foreach ($entry in $inventory | Where-Object { $_.relative_path -like '*.json' }) {
    $value = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot ([string]$entry.relative_path)
    ) | ConvertFrom-Json -Depth 100
    Add-R23D54CasReceipts $value $allReceipts
}
$uniqueReceipts = @{}
foreach ($receipt in $allReceipts) {
    $digest = [string]$receipt.sha256
    $length = [long]$receipt.byte_length
    if ($uniqueReceipts.ContainsKey($digest)) {
        Assert-R23D54Closure ([long]$uniqueReceipts[$digest] -eq $length) (
            "one CAS digest declared multiple byte lengths: $digest"
        )
    } else {
        $uniqueReceipts[$digest] = $length
    }
}
Assert-R23D54Closure (
    $allReceipts.Count -eq 232 -and $uniqueReceipts.Count -eq 122 -and
    [int]$closure.physical_evidence.content_addressed_receipt_reference_count -eq 232 -and
    [int]$closure.physical_evidence.content_addressed_unique_object_count -eq 122 -and
    [int]$closure.physical_evidence.unbound_local_file_count -eq 0
) "complete evidence graph cardinality changed"
foreach ($receipt in $uniqueReceipts.GetEnumerator()) {
    [void](Assert-R23D54Cas ([string]$receipt.Key) ([long]$receipt.Value))
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
Assert-R23D54Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d54_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 102 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 102 -and
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
Assert-R23D54Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d54_attempt_v1" -and
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
Assert-R23D54Closure (
    [string]$completion.schema_version -ceq
        "sporespore_qsdk_r23d54_completion_v1" -and
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
    -not [bool]$evaluation.engine_result.actuator_phase_characterization_complete -and
    -not [bool]$evaluation.engine_result.turning_gate_invoked -and
    -not [bool]$evaluation.engine_result.turning_mechanism_selected
) "complete invalid disposition changed"

Assert-R23D54Closure (@($closure.ordered_cells).Count -eq 3) (
    "ordered closure cell count changed"
)
Assert-R23D54Closure (@($report.ordered_cells).Count -eq 3) (
    "ordered report cell count changed"
)
Assert-R23D54Closure (@($evaluation.cell_evaluations).Count -eq 3) (
    "ordered evaluation cell count changed"
)
Assert-R23D54Closure (@($terminalManifest).Count -eq 3) (
    "terminal manifest count changed"
)
for ($index = 0; $index -lt 3; $index++) {
    $spec = $closure.ordered_cells[$index]
    $terminal = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot ([string]$spec.terminal_relative_path)
    ) | ConvertFrom-Json -Depth 100
    $diagnostic = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot ([string]$spec.diagnostic_relative_path)
    ) | ConvertFrom-Json -Depth 30
    $reported = $report.ordered_cells[$index]
    $evaluated = $evaluation.cell_evaluations[$index]
    Assert-R23D54Closure (
        [string]$spec.arm_id -ceq $expectedArms[$index] -and
        [string]$terminalManifest[$index] -ceq (
            Join-Path (
                Join-Path $artifactRoot (
                    [string]$spec.terminal_raw_sha256
                ).Substring(7)
            ) "payload.bin"
        ) -and
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d54_worker_failure_v1" -and
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.cell_id -ceq [string]$spec.cell_id -and
        [string]$terminal.arm_id -ceq [string]$spec.arm_id -and
        [string]$terminal.failure_code -ceq $rootFailure -and
        [int]$terminal.world_attempt_count -eq 1 -and
        [int]$terminal.world_build_count -eq 1 -and
        $null -eq $terminal.trace_artifact -and
        [string]$terminal.trace_diagnostic.schema_version -ceq
            "sporespore_qsdk_r23d54_trace_diagnostic_v1" -and
        (@($terminal.trace_diagnostic.failure_codes) -join ',') -ceq
            $traceFailure -and
        [int]$terminal.trace_diagnostic.declared_row_count -eq 2992 -and
        [int]$terminal.trace_diagnostic.actual_row_count -eq 0 -and
        [int]$terminal.trace_diagnostic.reported_row_count -eq 0 -and
        [int]$terminal.trace_diagnostic.contiguous_row_count -eq 0 -and
        [int]$terminal.trace_diagnostic.first_missing_semantic_step -eq 0 -and
        -not [bool]$terminal.trace_diagnostic.complete -and
        [string]$diagnostic.cell_id -ceq [string]$spec.cell_id -and
        (@($diagnostic.failure_codes) -join ',') -ceq $traceFailure -and
        [string]$terminal.trace_diagnostic_artifact.sha256 -ceq
            [string]$spec.diagnostic_raw_sha256 -and
        [int]$reported.process.exit_code -eq 1 -and
        -not [bool]$reported.process.timed_out -and
        [bool]$reported.process.supervisor_terminated -and
        [bool]$reported.process.termination_protocol_valid -and
        [string]$reported.terminal_schema -ceq
            "sporespore_qsdk_r23d54_worker_failure_v1" -and
        [int]$reported.world_attempt_count -eq 1 -and
        [int]$reported.world_build_count -eq 1 -and
        [string]$evaluated.entry_kind -ceq "worker_failure" -and
        -not [bool]$evaluated.execution_valid -and
        -not [bool]$evaluated.common_physical_gate_passed -and
        (@($evaluated.failed_gate_ids) -join ',') -ceq $rootFailure
    ) "cell $index retained failure changed"
}

foreach ($claimSet in @($evaluation.claims, $report.claims)) {
    Assert-R23D54Closure (
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

$sourceText = @{}
$diagnosticSources = @(
    $closure.postclosure_diagnosis.postclosure_diagnostic_sources
)
Assert-R23D54Closure ($diagnosticSources.Count -eq 14) (
    "postclosure diagnostic source count changed"
)
foreach ($source in $diagnosticSources) {
    $relative = [string]$source.path
    $bytes = Get-R23D54GitBlobBytes $sourceCommit $relative
    $oid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D54Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$source.git_blob_oid -and
        $bytes.Length -eq [long]$source.byte_length -and
        (Get-R23D54BytesSha256 $bytes) -ceq [string]$source.raw_sha256
    ) "historical diagnostic source changed: $relative"
    $sourceText[$relative] = [Text.Encoding]::UTF8.GetString($bytes)
    $matching = @($freeze.source_bindings | Where-Object {
        [string]$_.path -ceq $relative
    })
    if ([bool]$source.directly_bound_in_physical_freeze) {
        Assert-R23D54Closure ($matching.Count -eq 1) (
            "direct physical source binding missing: $relative"
        )
        $sourceIndex = [Array]::IndexOf(
            [object[]]@($freeze.source_bindings),
            $matching[0]
        )
        Assert-R23D54Closure (
            $sourceIndex -ge 0 -and
            [string]$matching[0].git_blob_oid -ceq [string]$source.git_blob_oid -and
            [string]$matching[0].raw_sha256 -ceq [string]$source.raw_sha256
        ) "direct physical source identity changed: $relative"
        $receipt = $freeze.content_addressed_inputs.source_bindings[$sourceIndex]
        [void](Assert-R23D54Cas (
            [string]$receipt.sha256
        ) ([long]$receipt.byte_length))
        Assert-R23D54Closure (
            [string]$receipt.sha256 -ceq [string]$source.raw_sha256 -and
            [long]$receipt.byte_length -eq [long]$source.byte_length
        ) "direct physical source CAS binding changed: $relative"
    } else {
        Assert-R23D54Closure ($matching.Count -eq 0) (
            "declared transitive source omission changed: $relative"
        )
    }
}

$coreText = [string]$sourceText["sdk/core/src/quadruped.rs"]
$adapterText = [string]$sourceText["scripts/lab/gait/sdk_godot_jolt_adapter.gd"]
$waveText = [string]$sourceText["scripts/lab/gait/physical_wave_gait_quadruped.gd"]
$fixtureText = [string]$sourceText["scripts/lab/gait/physical_quadruped_fixture_spec.gd"]
$r23d3WorkerText = [string]$sourceText["tests/test_sdk_qsdk_r23d3_godot_jolt_worker.gd"]
$r23d2Contract = [string]$sourceText["sdk/turning/r23d2_development_contract_v1.json"] |
    ConvertFrom-Json -Depth 30
$applyStart = $adapterText.IndexOf("func apply_authority(", [StringComparison]::Ordinal)
$applyEnd = $adapterText.IndexOf(
    "func record_external_terminal_authority_application(",
    $applyStart,
    [StringComparison]::Ordinal
)
$canaryStart = $adapterText.IndexOf(
    "func preflight_explicit_balanced_wave_heading_runtime_boundary(",
    [StringComparison]::Ordinal
)
$canaryEnd = $adapterText.IndexOf("func apply_authority(", $canaryStart)
Assert-R23D54Closure (
    $applyStart -ge 0 -and $applyEnd -gt $applyStart -and
    $canaryStart -ge 0 -and $canaryEnd -gt $canaryStart
) "historical adapter function boundaries changed"
$applyText = $adapterText.Substring($applyStart, $applyEnd - $applyStart)
$canaryText = $adapterText.Substring($canaryStart, $canaryEnd - $canaryStart)
Assert-R23D54Closure (
    $coreText.Contains("0.055 * mass_multiplier") -and
    $coreText.Contains("0.045 * mass_multiplier") -and
    $fixtureText.Contains('"hip_max_impulse_nms": 0.055') -and
    $fixtureText.Contains('"knee_base_max_impulse_nms": 0.045') -and
    $r23d3WorkerText.Contains('"actuator_impulse_scale": 1.015') -and
    $waveText.Contains('float(motor_impulses["hip_max_impulse_nms"]) * hip_impulse_scale') -and
    $waveText.Contains('float(motor_impulses["knee_base_max_impulse_nms"])') -and
    $waveText.Contains('* knee_motor_impulse_scale') -and
    $waveText.Contains('joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, maximum_motor_impulse_nms)') -and
    $applyText.Contains("HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY") -and
    $applyText.Contains("joint.get_param(") -and
    $applyText.Contains("HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE") -and
    $applyText -notmatch
        'set_param\([\s\r\n]*HingeJoint3D\.PARAM_MOTOR_MAX_IMPULSE' -and
    $canaryText.Contains("var joint := HingeJoint3D.new()") -and
    $canaryText.Contains("HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE") -and
    $canaryText.Contains('float(actuator.get("maximum_impulse_nms", NAN))')
) "historical cap construction, adapter application, or canary route changed"

$frontMultiplier = [double](
    $r23d2Contract.fixture.descriptor.front_limb_mass_scale
)
$rearMultiplier = 2.0 - $frontMultiplier
$frontHip = 0.055 * $frontMultiplier
$frontKnee = 0.045 * $frontMultiplier
$rearHip = 0.055 * $rearMultiplier
$rearKnee = 0.045 * $rearMultiplier
$liveHip = 0.055 * 1.015
$liveKnee = 0.045 * 10.0 * 1.015
$firstDifference = [Math]::Abs($liveHip - $frontHip)
$differenceRatio = $firstDifference / 2.5e-7
$diagnosis = $closure.postclosure_diagnosis
Assert-R23D54Near $frontMultiplier 0.975022758306782 $numericTolerance (
    "front limb mass scale changed"
)
Assert-R23D54Near $rearMultiplier 1.024977241693218 $numericTolerance (
    "rear limb mass scale changed"
)
Assert-R23D54Near $frontHip (
    [double]$diagnosis.compiled_descriptor.front_hip_maximum_impulse_nms
) $numericTolerance "front hip compiled cap changed"
Assert-R23D54Near $frontKnee (
    [double]$diagnosis.compiled_descriptor.front_knee_maximum_impulse_nms
) $numericTolerance "front knee compiled cap changed"
Assert-R23D54Near $rearHip (
    [double]$diagnosis.compiled_descriptor.rear_hip_maximum_impulse_nms
) $numericTolerance "rear hip compiled cap changed"
Assert-R23D54Near $rearKnee (
    [double]$diagnosis.compiled_descriptor.rear_knee_maximum_impulse_nms
) $numericTolerance "rear knee compiled cap changed"
Assert-R23D54Near $liveHip (
    [double]$diagnosis.live_fixture.realized_hip_maximum_impulse_nms
) $numericTolerance "live hip cap changed"
Assert-R23D54Near $liveKnee (
    [double]$diagnosis.live_fixture.realized_knee_maximum_impulse_nms
) $numericTolerance "live knee cap changed"
Assert-R23D54Near $firstDifference (
    [double]$diagnosis.first_ordered_actuator.absolute_impulse_cap_difference_nms
) $numericTolerance "first actuator cap difference changed"
Assert-R23D54Near $differenceRatio (
    [double]$diagnosis.first_ordered_actuator.difference_to_tolerance_ratio
) 1.0e-9 "first actuator cap mismatch ratio changed"
Assert-R23D54Closure (
    $firstDifference -gt 2.5e-7 -and
    [string]$diagnosis.first_ordered_actuator.actuator_id -ceq
        "front_left_hip_motor" -and
    [bool]$diagnosis.adapter_application.sets_motor_target_velocity -and
    -not [bool]$diagnosis.adapter_application.sets_compiled_maximum_impulse_on_live_host_joint -and
    [bool]$diagnosis.adapter_application.reads_motor_maximum_impulse -and
    [bool]$diagnosis.adapter_application.compares_readback_to_compiled_descriptor_cap -and
    [bool]$diagnosis.zero_world_canary_limitation.detached_hinge_joint_used -and
    [bool]$diagnosis.zero_world_canary_limitation.compiled_maximum_impulse_set_before_validation -and
    -not [bool]$diagnosis.zero_world_canary_limitation.live_fixture_joint_path_exercised -and
    @($diagnosis.physical_freeze_transitive_source_binding_omission.omitted_exact_source_paths).Count -eq 3 -and
    -not [bool]$diagnosis.physical_freeze_transitive_source_binding_omission.omission_caused_observed_application_mismatch -and
    [bool]$diagnosis.physical_freeze_transitive_source_binding_omission.successor_must_bind_transitive_sources_directly
) "postclosure diagnosis or observed-versus-proven boundary changed"

# Rebuild the evaluator namespace from the frozen source CAS receipts, never
# from today's evaluator bytes. The retained terminal paths remain the finite
# physical evidence inputs.
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempBase (
    "sporespore-r23d54-closure-" + [Guid]::NewGuid().ToString("N")
)))
$tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
Assert-R23D54Closure (
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
        "sdk\turning\r23d54_godot_actuator_phase_characterization_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D54Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $marker = "QSDK_R23D54_COMPLETE_EVALUATION "
    $markerLines = @($evaluatorOutput | Where-Object { $_.StartsWith($marker) })
    Assert-R23D54Closure ($markerLines.Count -eq 1) (
        "pinned evaluator marker changed"
    )
    $recomputed = $markerLines[0].Substring($marker.Length) |
        ConvertFrom-Json -Depth 100
    $storedCanonical = $evaluation | ConvertTo-Json -Depth 100 -Compress
    $recomputedCanonical = $recomputed | ConvertTo-Json -Depth 100 -Compress
    Assert-R23D54Closure ($recomputedCanonical -ceq $storedCanonical) (
        "pinned evaluator no longer reproduces the exact complete evaluation"
    )
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedCleanup = [IO.Path]::GetFullPath($tempRoot)
        Assert-R23D54Closure (
            $resolvedCleanup.StartsWith(
                $tempPrefix,
                [StringComparison]::OrdinalIgnoreCase
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
    { param($v) $v.ordered_cells[0].trace_failure_code = "different" },
    { param($v) $v.ordered_cells[0].first_missing_semantic_step = 1 },
    { param($v) $v.postclosure_diagnosis.compiled_descriptor.front_hip_maximum_impulse_nms = 0.055 },
    { param($v) $v.postclosure_diagnosis.first_ordered_actuator.frozen_readback_tolerance_nms = 0.01 },
    { param($v) $v.claims.actuator_phase_characterization_complete = $true },
    { param($v) $v.claims.godot_jolt_r23d29_turning = $true },
    { param($v) $v.claims.prone_to_standing = $true },
    { param($v) $v.successor_requirements.physical_successor_authorized_by_this_closure = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D54ClosureSemanticVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D54Closure ($mutationRejectionCount -eq $mutations.Count) (
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
    $turningGate[0].proof.closed_r23d54_attempt
} else { $null }
$matrixRecord = Find-R23D54ClosedRecord $supportMatrix
$closureHash = Get-R23D54Sha256 $closurePath
$auditHash = Get-R23D54Sha256 $closureAuditPath
Assert-R23D54Closure (
    $turningGate.Count -eq 1 -and
    $null -ne $contractRecord -and $null -ne $matrixRecord -and
    [string]$turningGate[0].proof.prospective_r23d54_actuator_phase_characterization.status -ceq
        "prospective_zero_world_only" -and
    [int]$turningGate[0].proof.prospective_r23d54_actuator_phase_characterization.physical_world_attempt_count -eq 0 -and
    [string]$contractRecord.status -ceq [string]$closure.status -and
    [string]$matrixRecord.status -ceq [string]$closure.status -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d54_godot_actuator_phase_characterization_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.closure_audit_path -ceq
        "tests/test_qsdk_r23d54_closure.ps1" -and
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
    [int]$contractRecord.valid_trace_row_count -eq 0 -and
    [int]$matrixRecord.valid_trace_row_count -eq 0 -and
    [bool]$contractRecord.identity_consumed -and
    [bool]$matrixRecord.identity_consumed -and
    -not [bool]$contractRecord.same_identity_rerun_allowed -and
    -not [bool]$matrixRecord.same_identity_rerun_allowed -and
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
    Get-ChildItem -LiteralPath $evidenceRoot -Directory |
        Where-Object {
            $_.Name -like "qsdk-r23d54-20*" -and
            (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
        }
)
Assert-R23D54Closure (
    $completedAttempts.Count -eq 1 -and
    $completedAttempts[0].FullName -ceq $attemptRoot
) "R23D54 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D54_CLOSURE_PASS classification=complete_invalid " +
    "worlds=3 execution_valid=0 trace_rows=0 observed_failure=application_mismatch " +
    "source_proven_cap_mismatch=True evaluator_replay=True cas_refs=232 " +
    "cas_unique=122 mutations=$mutationRejectionCount rerun=False " +
    "turning=False prone=False release=False"
)
