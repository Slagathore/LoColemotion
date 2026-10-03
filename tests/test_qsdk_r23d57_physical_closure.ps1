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
$sourceCommit = "f0993e7e4886ff51254fb4de47f22a1bf0cc7ebe"
$sourceTree = "80c04f096ddfd417a8fb6b85e14710f66f464185"
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d57-f0993e7-development-attempt-1"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d57_godot_full_precision_trace_actuator_phase_" +
    "characterization_closure_v1.json"
)
$closureAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d57_physical_closure.ps1"
)
$classification = (
    "invalid_complete_outcome_exposed_godot_full_precision_trace_" +
    "actuator_phase_characterization_development"
)
$campaignId = (
    "QSDK-R23D57-GODOT-FULL-PRECISION-TRACE-ACTUATOR-PHASE-" +
    "CHARACTERIZATION-DEVELOPMENT"
)
$expectedArms = @("reference_zero", "positive_heading", "negative_heading")
$expectedOffsets = @(0.0, 0.2, -0.2)
$expectedForward = @(
    0.514632344245911,
    0.299461394548416,
    0.497536212205887
)
$expectedTilt = @(
    0.0540085717211964,
    0.0692034511327201,
    0.0488561717103758
)
$expectedHeight = @(
    0.426941990852356,
    0.425224155187607,
    0.428052693605423
)
$expectedYaw = @(
    0.234239237930057,
    -0.124264007004137,
    0.135642733949379
)
$expectedCycles = @(
    @(3, 3, 0, 0),
    @(2, 3, 0, 0),
    @(3, 3, 0, 0)
)
$expectedTraceSha256 = @(
    "sha256:eb2ff18c41d2bab9b8d006644b9a8a7f06cbff278e492d8217028bdcee1116ff",
    "sha256:5524c95a232b76d9cf5d3c815a3568d506aa52ad7743809b3e757f2078d888ce",
    "sha256:7a04707f0c5b73cb1fdbe1b7c39a1165ccecfce0bce6966e467517b3008346b6"
)
$expectedTraceBytes = @(34752288, 34723920, 34780527)
$failedGateIds = @(
    "R23D34_CONTACT_CYCLES",
    "R23D57_CAP_BINDING_APPLICATION_IDENTITY_INVALID"
)
$numericTolerance = 1.0e-15

function Assert-R23D57Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D57 CLOSURE: $Message" }
}

function Assert-R23D57Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D57Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-R23D57Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D57BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D57GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D57Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D57Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Assert-R23D57Cas([string]$Sha256, [long]$ByteLength) {
    Assert-R23D57Closure ($Sha256 -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $Sha256"
    )
    $directory = Join-Path $artifactRoot $Sha256.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D57Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $ByteLength -and
        (Get-R23D57Sha256 $payload) -ceq $Sha256
    ) "CAS payload changed: $Sha256"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D57Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $Sha256 -and
        [long]$manifest.byte_length -eq $ByteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $Sha256"
    return $payload
}

function Assert-R23D57LocalFile(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D57Closure (
        (Test-Path -LiteralPath $Path -PathType Leaf) -and
        (Get-Item -LiteralPath $Path).Length -eq $ByteLength -and
        (Get-R23D57Sha256 $Path) -ceq $Sha256
    ) "retained artifact changed: $Path"
}

function Assert-R23D57PathAndCas(
    [string]$Path,
    [string]$Sha256,
    [long]$ByteLength
) {
    Assert-R23D57LocalFile $Path $Sha256 $ByteLength
    $payload = Assert-R23D57Cas $Sha256 $ByteLength
    Assert-R23D57Closure (
        (Get-R23D57Sha256 $payload) -ceq (Get-R23D57Sha256 $Path)
    ) "retained artifact and CAS diverged: $Path"
    return $payload
}

function Add-R23D57CasReceipts(
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
            Add-R23D57CasReceipts $property.Value $Receipts
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($child in $Value.Values) {
            Add-R23D57CasReceipts $child $Receipts
        }
        return
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            Add-R23D57CasReceipts $child $Receipts
        }
    }
}

function Find-R23D57ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d57_attempt")) {
            return $Value["closed_r23d57_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D57ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d57_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($property in $Value.PSObject.Properties) {
            $found = Find-R23D57ClosedRecord $property.Value
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D57ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D57ClaimVector($Value) {
    try {
        return (
            [bool]$Value.r23d57_complete_three_world_attempt_executed -and
            [bool]$Value.r23d57_full_precision_traces_retained -and
            [bool]$Value.r23d57_full_precision_trace_transport_observed_working -and
            [bool]$Value.r23d57_invalid_cap_identity_cause_bounded_to_dual_json_serialization_precision -and
            [bool]$Value.r23d57_rear_feet_continuously_contacted_ground_as_postfailure_diagnostic_fact -and
            -not [bool]$Value.r23d57_valid_physical_characterization -and
            -not [bool]$Value.live_fixture_actuator_cap_binding_verified -and
            -not [bool]$Value.actuator_phase_characterization_complete -and
            -not [bool]$Value.turning_mechanism_selected -and
            -not [bool]$Value.godot_jolt_r23d29_turning -and
            -not [bool]$Value.finite_three_engine_turning -and
            -not [bool]$Value.portable_basic_turning -and
            -not [bool]$Value.cross_engine_equivalence -and
            -not [bool]$Value.population_robustness -and
            -not [bool]$Value.q_sdk_r23_satisfied -and
            -not [bool]$Value.prone_to_standing -and
            -not [bool]$Value.release_authorized -and
            -not [bool]$Value.physical_acceptance_authority
        )
    } catch { return $false }
}

function Test-R23D57ClosureSemanticVector($Value) {
    try {
        return (
            [string]$Value.schema_version -ceq
                "sporespore_qsdk_r23d57_godot_full_precision_trace_actuator_phase_characterization_closure_v1" -and
            [string]$Value.status -ceq
                "closed_consumed_invalid_complete_outcome_exposed_godot_full_precision_trace_actuator_phase_characterization_development" -and
            [string]$Value.source_commit -ceq $sourceCommit -and
            [string]$Value.source_tree_git_oid -ceq $sourceTree -and
            [string]$Value.attempt_id -ceq
                "3bb645c8cb444f988d88f5dbe1fb8211" -and
            [bool]$Value.identity_consumed -and
            -not [bool]$Value.same_identity_rerun_allowed -and
            -not [bool]$Value.selective_rerun_allowed -and
            -not [bool]$Value.replacement_rerun_allowed -and
            -not [bool]$Value.successor_campaign_opened -and
            [string]$Value.official_result.classification -ceq $classification -and
            [int]$Value.official_result.observed_world_build_count -eq 3 -and
            [int]$Value.official_result.execution_valid_cell_count -eq 0 -and
            [int]$Value.official_result.retained_trace_row_count -eq 8976 -and
            [int]$Value.official_result.retained_actuator_application_count -eq 71808 -and
            [bool]$Value.official_result.full_precision_trace_transport_succeeded -and
            -not [bool]$Value.official_result.live_fixture_actuator_cap_binding_verified_by_frozen_evaluator -and
            -not [bool]$Value.official_result.actuator_phase_characterization_complete -and
            -not [bool]$Value.official_result.turning_gate_invoked -and
            -not [bool]$Value.official_result.turning_mechanism_selected -and
            [int]$Value.postclosure_diagnosis.cap_binding_application_identity_failure.comparison_count -eq 24 -and
            [int]$Value.postclosure_diagnosis.cap_binding_application_identity_failure.declared_cap_exact_mismatch_count -eq 24 -and
            [int]$Value.postclosure_diagnosis.contextual_contact_gate_failure.rear_contact_loss_transition_count -eq 0 -and
            [int]$Value.postclosure_diagnosis.contextual_contact_gate_failure.rear_contact_gain_transition_count -eq 0 -and
            -not [bool]$Value.postclosure_diagnosis.contextual_contact_gate_failure.cap_route_causality_established -and
            -not [bool]$Value.postclosure_diagnosis.contextual_contact_gate_failure.threshold_change_authorized -and
            -not [bool]$Value.postclosure_diagnosis.raw_yaw_diagnostic_only.turning_result -and
            [bool]$Value.successor_requirements.distinct_campaign_identity_required -and
            [bool]$Value.successor_requirements.r23d57_rerun_forbidden -and
            -not [bool]$Value.successor_requirements.retained_r23d57_evidence_may_be_promoted_to_a_valid_result -and
            -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
            (Test-R23D57ClaimVector $Value.claims)
        )
    } catch { return $false }
}

$gitRoot = [IO.Path]::GetFullPath(
    (git -C $repoRoot rev-parse --show-toplevel).Trim()
).TrimEnd('\', '/')
Assert-R23D57Closure (
    $gitRoot -ieq $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository authority changed"

$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D57Closure (Test-R23D57ClosureSemanticVector $closure) (
    "closure identity or immutable disposition changed"
)
Assert-R23D57Closure (
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D57" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.question_class -ceq "development" -and
    [int]$closure.campaign_seed -eq 21512 -and
    -not [bool]$closure.fresh_held_out_condition_consumed
) "scientific question class or finite identity changed"

$tree = (git -C $repoRoot show -s --format=%T $sourceCommit).Trim()
Assert-R23D57Closure (
    $LASTEXITCODE -eq 0 -and $tree -ceq $sourceTree
) "source commit or tree is unavailable"

$attestationSpec = $closure.qualification_history.accepted_scoped_attestation
$adoptionSpec = $closure.qualification_history.adoption
$attestationPayload = Assert-R23D57PathAndCas (
    [string]$attestationSpec.path
) ([string]$attestationSpec.raw_sha256) ([long]$attestationSpec.byte_length)
$adoptionPayload = Assert-R23D57PathAndCas (
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
Assert-R23D57Closure (
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
foreach ($receipt in $gateCasReferences) {
    [void](Assert-R23D57Cas (
        [string]$receipt.sha256
    ) ([long]$receipt.byte_length))
}
Assert-R23D57Closure (
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
    [bool]$adoption.scoped_attestation_cas_verified -and
    [bool]$adoption.clean_pushed_live_source_verified -and
    [bool]$adoption.runtime_matches_commissioning -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "campaign-local adoption changed"

$inventory = @($closure.physical_evidence.file_inventory)
Assert-R23D57Closure (
    $inventory.Count -eq 21 -and
    @($inventory | Where-Object { $_.relative_path -like '*.json' }).Count -eq 12 -and
    @($inventory | Where-Object { $_.relative_path -like '*.rows.json' }).Count -eq 3 -and
    @($inventory | Where-Object { $_.relative_path -like 'traces/*.ndjson' }).Count -eq 3
) "retained evidence inventory declaration changed"
$actualFiles = @(
    Get-ChildItem -LiteralPath $attemptRoot -File -Recurse | Sort-Object FullName
)
Assert-R23D57Closure ($actualFiles.Count -eq 21) (
    "retained evidence tree file count changed"
)
$inventoryByPath = @{}
foreach ($entry in $inventory) {
    $relative = [string]$entry.relative_path
    Assert-R23D57Closure (-not $inventoryByPath.ContainsKey($relative)) (
        "duplicate retained inventory path: $relative"
    )
    $inventoryByPath[$relative] = $entry
    $localPath = Join-Path $attemptRoot $relative
    if ($relative -like '*.rows.json') {
        Assert-R23D57LocalFile (
            $localPath
        ) ([string]$entry.raw_sha256) ([long]$entry.byte_length)
    } else {
        [void](Assert-R23D57PathAndCas (
            $localPath
        ) ([string]$entry.raw_sha256) ([long]$entry.byte_length))
    }
}
foreach ($file in $actualFiles) {
    $relative = [IO.Path]::GetRelativePath($attemptRoot, $file.FullName).
        Replace('\', '/')
    Assert-R23D57Closure ($inventoryByPath.ContainsKey($relative)) (
        "unbound local evidence file: $relative"
    )
}

$allReceipts = [Collections.Generic.List[object]]::new()
$metadataJson = @($inventory | Where-Object {
    $_.relative_path -like '*.json' -and
    $_.relative_path -notlike 'pending-traces/*'
})
Assert-R23D57Closure ($metadataJson.Count -eq 9) (
    "metadata JSON file count changed"
)
foreach ($entry in $metadataJson) {
    $value = Get-Content -Raw -LiteralPath (
        Join-Path $attemptRoot ([string]$entry.relative_path)
    ) | ConvertFrom-Json -Depth 100
    Add-R23D57CasReceipts $value $allReceipts
}
foreach ($entry in $inventory | Where-Object {
    $_.relative_path -like 'pending-traces/*.json'
}) {
    $hasReceipt = Select-String -LiteralPath (
        Join-Path $attemptRoot ([string]$entry.relative_path)
    ) -SimpleMatch "sporespore_content_addressed_artifact_receipt_v1" -Quiet
    Assert-R23D57Closure (-not $hasReceipt) (
        "unaccounted nested CAS receipt in $($entry.relative_path)"
    )
}
$uniqueReceipts = @{}
foreach ($receipt in $allReceipts) {
    $digest = [string]$receipt.sha256
    $length = [long]$receipt.byte_length
    if ($uniqueReceipts.ContainsKey($digest)) {
        Assert-R23D57Closure ([long]$uniqueReceipts[$digest] -eq $length) (
            "one CAS digest declared multiple byte lengths: $digest"
        )
    } else {
        $uniqueReceipts[$digest] = $length
    }
}
Assert-R23D57Closure (
    $allReceipts.Count -eq 252 -and $uniqueReceipts.Count -eq 132 -and
    [int]$closure.physical_evidence.content_addressed_receipt_reference_count -eq 252 -and
    [int]$closure.physical_evidence.content_addressed_unique_object_count -eq 132 -and
    [int]$closure.physical_evidence.invalid_content_addressed_reference_count -eq 0 -and
    [int]$closure.physical_evidence.unbound_local_file_count -eq 0
) "complete evidence graph cardinality changed"
foreach ($receipt in $uniqueReceipts.GetEnumerator()) {
    [void](Assert-R23D57Cas ([string]$receipt.Key) ([long]$receipt.Value))
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
Assert-R23D57Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d57_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    @($freeze.source_bindings).Count -eq 112 -and
    @($freeze.content_addressed_inputs.source_bindings).Count -eq 112 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3 -and
    @($freeze.content_addressed_inputs.runtime_bindings).Count -eq 4 -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [int]$freeze.declared_world_count -eq 3 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze or complete zero-world prerequisite changed"
Assert-R23D57Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d57_attempt_v1" -and
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
    [bool]$authorization.content_addressed_inputs_retained -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    [bool]$authorization.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$authorization.physical_acceptance_authority
) "attempt authorization changed"
Assert-R23D57Closure (
    [string]$completion.schema_version -ceq
        "sporespore_qsdk_r23d57_completion_v1" -and
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
Assert-R23D57Closure (@($terminalManifest).Count -eq 3) (
    "terminal manifest cardinality changed"
)
foreach ($claimSet in @($evaluation.claims, $report.claims)) {
    Assert-R23D57Closure (
        -not [bool]$claimSet.live_fixture_actuator_cap_binding_verified -and
        -not [bool]$claimSet.actuator_phase_characterization_complete -and
        -not [bool]$claimSet.turning_mechanism_selected -and
        -not [bool]$claimSet.godot_jolt_r23d29_turning -and
        -not [bool]$claimSet.finite_three_engine_turning -and
        -not [bool]$claimSet.portable_basic_turning -and
        -not [bool]$claimSet.cross_engine_equivalence -and
        -not [bool]$claimSet.population_robustness -and
        -not [bool]$claimSet.prone_to_standing -and
        -not [bool]$claimSet.release_authorized -and
        -not [bool]$claimSet.physical_acceptance_authority
    ) "stored physical claim vector changed"
}

# Prove every source/runtime receipt in the immutable physical freeze.
for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
    $binding = $freeze.source_bindings[$index]
    $receipt = $freeze.content_addressed_inputs.source_bindings[$index]
    $relative = [string]$binding.path
    $bytes = Get-R23D57GitBlobBytes $sourceCommit $relative
    $oid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D57Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$binding.git_blob_oid -and
        [bool]$binding.raw_checkout_equals_git_blob -and
        (Get-R23D57BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        [string]$receipt.sha256 -ceq [string]$binding.raw_sha256 -and
        [long]$receipt.byte_length -eq $bytes.Length
    ) "frozen source binding changed: $relative"
    [void](Assert-R23D57Cas (
        [string]$receipt.sha256
    ) ([long]$receipt.byte_length))
}
for ($index = 0; $index -lt 4; $index++) {
    $binding = if ($index -eq 0) {
        $freeze.runtime_artifacts[0]
    } else {
        $freeze.external_runtime_bindings[$index - 1]
    }
    $receipt = $freeze.content_addressed_inputs.runtime_bindings[$index]
    Assert-R23D57Closure (
        [string]$receipt.sha256 -ceq [string]$binding.raw_sha256
    ) "frozen runtime binding changed: $($binding.name)"
    [void](Assert-R23D57Cas (
        [string]$receipt.sha256
    ) ([long]$receipt.byte_length))
}

$diagnosticSources = @($closure.postclosure_diagnosis.frozen_source_bindings)
Assert-R23D57Closure ($diagnosticSources.Count -eq 5) (
    "postclosure frozen source count changed"
)
$sourceText = @{}
foreach ($source in $diagnosticSources) {
    $relative = [string]$source.path
    $bytes = Get-R23D57GitBlobBytes $sourceCommit $relative
    $oid = (git -C $repoRoot rev-parse "${sourceCommit}:$relative").Trim()
    Assert-R23D57Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$source.git_blob_oid -and
        $bytes.Length -eq [long]$source.byte_length -and
        (Get-R23D57BytesSha256 $bytes) -ceq [string]$source.raw_sha256
    ) "historical diagnostic source changed: $relative"
    $sourceText[$relative] = [Text.Encoding]::UTF8.GetString($bytes)
}
$workerText = [string]$sourceText[
    "tests/test_sdk_qsdk_r23d57_godot_jolt_physical_worker.gd"
]
$evaluatorText = [string]$sourceText[
    "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_evaluator.py"
]
$commonEvaluatorText = [string]$sourceText[
    "sdk/turning/r23d34_native_r23d29_transfer_evaluator.py"
]
Assert-R23D57Closure (
    $workerText.Contains('JSON.stringify(rows, "", true, true)') -and
    $workerText.Contains('JSON.stringify(terminal)') -and
    $evaluatorText.Contains(
        'float(binding.get("declared_maximum_impulse_nms"))'
    ) -and
    $evaluatorText.Contains(
        '!= float(application.get("declared_maximum_impulse_nms"))'
    ) -and
    $commonEvaluatorText.Contains('contacts[limb] < 2')
) "frozen serialization or contact-cycle predicates changed"

# Materialize a pinned evaluator namespace and replay the exact frozen result.
$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = [IO.Path]::GetFullPath((Join-Path $tempBase (
    "sporespore-r23d57-closure-" + [Guid]::NewGuid().ToString("N")
)))
$tempPrefix = $tempBase + [IO.Path]::DirectorySeparatorChar
Assert-R23D57Closure (
    $tempRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase)
) "temporary evaluator root escaped system temp"
try {
    for ($index = 0; $index -lt @($freeze.source_bindings).Count; $index++) {
        $binding = $freeze.source_bindings[$index]
        $relative = [string]$binding.path
        $sourcePayload = [string](
            $freeze.content_addressed_inputs.source_bindings[$index].payload_path
        )
        $destination = Join-Path $tempRoot $relative
        [void][IO.Directory]::CreateDirectory((Split-Path -Parent $destination))
        Copy-Item -LiteralPath $sourcePayload -Destination $destination
    }
    $evaluatorPath = Join-Path $tempRoot (
        "sdk\turning\r23d57_godot_full_precision_trace_actuator_phase_" +
        "characterization_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D57Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $evaluationMarker = "QSDK_R23D57_COMPLETE_EVALUATION "
    $evaluationLines = @($evaluatorOutput | Where-Object {
        $_.StartsWith($evaluationMarker)
    })
    Assert-R23D57Closure ($evaluationLines.Count -eq 1) (
        "pinned evaluator marker changed"
    )
    $recomputedEvaluation = $evaluationLines[0].Substring(
        $evaluationMarker.Length
    ) | ConvertFrom-Json -Depth 100
    Assert-R23D57Closure (
        ($recomputedEvaluation | ConvertTo-Json -Depth 100 -Compress) -ceq
        ($evaluation | ConvertTo-Json -Depth 100 -Compress)
    ) "pinned evaluator no longer reproduces the complete invalid evaluation"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        $resolvedCleanup = [IO.Path]::GetFullPath($tempRoot)
        Assert-R23D57Closure (
            $resolvedCleanup.StartsWith(
                $tempPrefix, [StringComparison]::OrdinalIgnoreCase
            )
        ) "temporary cleanup target escaped system temp"
        Remove-Item -LiteralPath $resolvedCleanup -Recurse -Force
    }
}

# Recompute the exact terminal/first-trace mismatch and all rear-contact facts.
$declaredCapMismatchCount = 0
$identityMismatchCount = 0
$receiptReadbackToleranceFailureCount = 0
$bindingErrorToleranceFailureCount = 0
$readbackMatchesFalseCount = 0
$minimumDeclaredCapDelta = [double]::PositiveInfinity
$maximumDeclaredCapDelta = 0.0
$maximumReceiptToApplicationReadbackDelta = 0.0
$totalRows = 0
$totalApplications = 0
for ($cellIndex = 0; $cellIndex -lt 3; $cellIndex++) {
    $cell = $closure.ordered_cells[$cellIndex]
    Assert-R23D57Closure (
        [string]$cell.arm_id -ceq $expectedArms[$cellIndex] -and
        [double]$cell.turn_heading_offset_rad -eq $expectedOffsets[$cellIndex] -and
        [string]$cell.entry_kind -ceq "report" -and
        -not [bool]$cell.execution_valid -and
        -not [bool]$cell.common_physical_gate_passed -and
        (@($cell.failed_gate_ids) -join '|') -ceq ($failedGateIds -join '|') -and
        [int]$cell.world_attempt_count -eq 1 -and
        [int]$cell.world_build_count -eq 1 -and
        [int]$cell.controller_semantic_step_count -eq 2992 -and
        [int]$cell.validated_portable_command_count -eq 23936 -and
        [int]$cell.native_actuation_application_count -eq 23936 -and
        [int]$cell.actuator_application_mismatch_count -eq 0 -and
        [int]$cell.trace_row_count -eq 2992 -and
        [string]$cell.trace_sha256 -ceq $expectedTraceSha256[$cellIndex] -and
        [long]$cell.trace_byte_length -eq $expectedTraceBytes[$cellIndex] -and
        [int]$cell.rear_left_contact_true_step_count -eq 2992 -and
        [int]$cell.rear_right_contact_true_step_count -eq 2992 -and
        [int]$cell.rear_contact_loss_transition_count -eq 0 -and
        [int]$cell.rear_contact_gain_transition_count -eq 0 -and
        [int]$cell.torso_ground_contact_step_count -eq 0 -and
        -not [bool]$cell.startup_ramp_triggered -and
        [int]$cell.startup_ramp_active_step_count -eq 0
    ) "closed cell identity changed: $cellIndex"
    Assert-R23D57Near ([double]$cell.final_forward_displacement_m) (
        $expectedForward[$cellIndex]
    ) $numericTolerance "forward metric changed: $cellIndex"
    Assert-R23D57Near ([double]$cell.maximum_tilt_rad) (
        $expectedTilt[$cellIndex]
    ) $numericTolerance "tilt metric changed: $cellIndex"
    Assert-R23D57Near ([double]$cell.minimum_torso_height_m) (
        $expectedHeight[$cellIndex]
    ) $numericTolerance "height metric changed: $cellIndex"
    Assert-R23D57Near ([double]$cell.turn_phase_yaw_delta_rad) (
        $expectedYaw[$cellIndex]
    ) $numericTolerance "raw yaw metric changed: $cellIndex"
    $cycles = $cell.contact_cycle_count_by_limb
    Assert-R23D57Closure (
        [int]$cycles.front_left -eq $expectedCycles[$cellIndex][0] -and
        [int]$cycles.front_right -eq $expectedCycles[$cellIndex][1] -and
        [int]$cycles.rear_left -eq 0 -and
        [int]$cycles.rear_right -eq 0
    ) "contact-cycle metric changed: $cellIndex"

    $terminalPath = Join-Path $attemptRoot (
        "cells\$($cell.cell_id)\terminal.json"
    )
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    Assert-R23D57Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d57_engine_cell_report_v1" -and
        [string]$terminal.arm_id -ceq $expectedArms[$cellIndex] -and
        [string]$terminal.cell_id -ceq [string]$cell.cell_id -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
        [bool]$terminal.godot_execution_predicates.ok -and
        [bool]$terminal.trace_summary.ok -and
        @($terminal.trace_summary.failure_codes).Count -eq 0 -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [int]$terminal.trace_summary.observation_application_count -eq 23936 -and
        [bool]$terminal.trace_artifact.godot_json_full_precision -and
        [string]$terminal.trace_artifact.selected_godot_invocation -ceq
            'JSON.stringify(rows, "", true, true)' -and
        [int]$terminal.measurements.safe_no_actuation_count -eq 0 -and
        [int]$terminal.measurements.controller_error_count -eq 0 -and
        [int]$terminal.measurements.nonfinite_observation_count -eq 0 -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0 -and
        [int]$terminal.measurements.startup_probe_minimum_support_count -eq 3 -and
        [int]$terminal.measurements.startup_ramp_active_step_count -eq 0 -and
        [int]$terminal.measurements.startup_ramp_exact_unity_scale_step_count -eq 2992
    ) "retained terminal execution facts changed: $cellIndex"

    $tracePath = Join-Path $attemptRoot "traces\$($cell.cell_id).ndjson"
    Assert-R23D57LocalFile (
        $tracePath
    ) ([string]$cell.trace_sha256) ([long]$cell.trace_byte_length)
    $reader = [IO.File]::OpenText($tracePath)
    $rowCount = 0
    $rearLeftTrueCount = 0
    $rearRightTrueCount = 0
    $rearLossCount = 0
    $rearGainCount = 0
    $firstRow = $null
    try {
        while (($line = $reader.ReadLine()) -ne $null) {
            $row = $line | ConvertFrom-Json -Depth 100
            if ($rowCount -eq 0) { $firstRow = $row }
            Assert-R23D57Closure (
                [string]$row.cell_id -ceq [string]$cell.cell_id -and
                [int]$row.semantic_step -eq $rowCount
            ) "trace row identity changed: $cellIndex/$rowCount"
            $beforeLeft = [bool]$row.ordered_foot_contacts_before.rear_left
            $afterLeft = [bool]$row.ordered_foot_contacts_after.rear_left
            $beforeRight = [bool]$row.ordered_foot_contacts_before.rear_right
            $afterRight = [bool]$row.ordered_foot_contacts_after.rear_right
            if ($afterLeft) { $rearLeftTrueCount++ }
            if ($afterRight) { $rearRightTrueCount++ }
            if ($beforeLeft -and -not $afterLeft) { $rearLossCount++ }
            if ($beforeRight -and -not $afterRight) { $rearLossCount++ }
            if (-not $beforeLeft -and $afterLeft) { $rearGainCount++ }
            if (-not $beforeRight -and $afterRight) { $rearGainCount++ }
            $rowCount++
        }
    } finally {
        $reader.Dispose()
    }
    Assert-R23D57Closure (
        $rowCount -eq 2992 -and
        $rearLeftTrueCount -eq 2992 -and
        $rearRightTrueCount -eq 2992 -and
        $rearLossCount -eq 0 -and $rearGainCount -eq 0
    ) "rear-contact trace diagnosis changed: $cellIndex"
    $totalRows += $rowCount

    $receipt = $terminal.godot_execution_predicates.raw_sdk_authority_summary.
        r23d57_live_fixture_actuator_cap_binding_receipt
    $bindings = @($receipt.ordered_bindings)
    $applications = @($firstRow.actuator_phase_observation.ordered_applications)
    $readbackTolerance = [double]$firstRow.actuator_phase_observation.readback_tolerance
    Assert-R23D57Closure (
        [bool]$terminal.godot_execution_predicates.raw_sdk_authority_summary.
            r23d57_live_fixture_actuator_cap_binding_integrity_passed -and
        [bool]$receipt.all_postbinding_readbacks_match -and
        $bindings.Count -eq 8 -and $applications.Count -eq 8 -and
        $readbackTolerance -eq 2.5e-7
    ) "cap receipt shape changed: $cellIndex"
    for ($applicationIndex = 0; $applicationIndex -lt 8; $applicationIndex++) {
        $binding = $bindings[$applicationIndex]
        $application = $applications[$applicationIndex]
        if (
            [string]$binding.actuator_id -cne [string]$application.actuator_id -or
            [string]$binding.joint_id -cne [string]$application.joint_id -or
            [string]$binding.host_joint_id -cne [string]$application.host_joint_id -or
            [string]$binding.limb_id -cne [string]$application.limb_id
        ) { $identityMismatchCount++ }
        $declaredDelta = [Math]::Abs(
            [double]$binding.declared_maximum_impulse_nms -
            [double]$application.declared_maximum_impulse_nms
        )
        if ($declaredDelta -ne 0.0) {
            $declaredCapMismatchCount++
            $minimumDeclaredCapDelta = [Math]::Min(
                $minimumDeclaredCapDelta, $declaredDelta
            )
            $maximumDeclaredCapDelta = [Math]::Max(
                $maximumDeclaredCapDelta, $declaredDelta
            )
        }
        $readbackDelta = [Math]::Abs(
            [double]$binding.motor_maximum_impulse_readback_nms -
            [double]$application.motor_maximum_impulse_readback_nms
        )
        $maximumReceiptToApplicationReadbackDelta = [Math]::Max(
            $maximumReceiptToApplicationReadbackDelta, $readbackDelta
        )
        if ($readbackDelta -gt $readbackTolerance) {
            $receiptReadbackToleranceFailureCount++
        }
        if ([double]$binding.readback_error_nms -gt $readbackTolerance) {
            $bindingErrorToleranceFailureCount++
        }
        if (
            $binding.readback_matches -isnot [bool] -or
            -not [bool]$binding.readback_matches -or
            -not [bool]$application.maximum_impulse_readback_matches
        ) { $readbackMatchesFalseCount++ }
        $totalApplications++
    }
}
$capDiagnosis = $closure.postclosure_diagnosis.
    cap_binding_application_identity_failure
Assert-R23D57Closure (
    $totalRows -eq 8976 -and $totalApplications -eq 24 -and
    $declaredCapMismatchCount -eq 24 -and
    $identityMismatchCount -eq 0 -and
    $receiptReadbackToleranceFailureCount -eq 0 -and
    $bindingErrorToleranceFailureCount -eq 0 -and
    $readbackMatchesFalseCount -eq 0 -and
    [int]$capDiagnosis.comparison_count -eq 24 -and
    [int]$capDiagnosis.declared_cap_exact_mismatch_count -eq 24 -and
    [int]$capDiagnosis.actuator_joint_host_joint_and_limb_identity_mismatch_count -eq 0 -and
    [int]$capDiagnosis.receipt_readback_tolerance_failure_count -eq 0 -and
    [int]$capDiagnosis.binding_error_tolerance_failure_count -eq 0 -and
    [int]$capDiagnosis.readback_matches_false_count -eq 0 -and
    -not [bool]$capDiagnosis.actual_live_host_binding_mismatch_observed -and
    -not [bool]$capDiagnosis.r23d57_evaluator_repair_permitted
) "exact cap identity diagnosis changed"
Assert-R23D57Near $minimumDeclaredCapDelta (
    [double]$capDiagnosis.minimum_nonzero_declared_cap_delta_nms
) 1.0e-32 "minimum declared-cap delta changed"
Assert-R23D57Near $maximumDeclaredCapDelta (
    [double]$capDiagnosis.maximum_declared_cap_delta_nms
) 1.0e-32 "maximum declared-cap delta changed"
Assert-R23D57Near $maximumReceiptToApplicationReadbackDelta (
    [double]$capDiagnosis.maximum_receipt_to_application_readback_delta_nms
) 1.0e-32 "receipt/application readback delta changed"

$mutations = @(
    { param($v) $v.status = "closed_positive" },
    { param($v) $v.source_commit = "0" * 40 },
    { param($v) $v.attempt_id = "different" },
    { param($v) $v.same_identity_rerun_allowed = $true },
    { param($v) $v.successor_campaign_opened = $true },
    { param($v) $v.official_result.classification = "valid_complete_positive" },
    { param($v) $v.official_result.observed_world_build_count = 2 },
    { param($v) $v.official_result.execution_valid_cell_count = 1 },
    { param($v) $v.official_result.retained_trace_row_count = 0 },
    { param($v) $v.official_result.retained_actuator_application_count = 0 },
    { param($v) $v.official_result.full_precision_trace_transport_succeeded = $false },
    { param($v) $v.postclosure_diagnosis.cap_binding_application_identity_failure.declared_cap_exact_mismatch_count = 0 },
    { param($v) $v.postclosure_diagnosis.contextual_contact_gate_failure.rear_contact_loss_transition_count = 1 },
    { param($v) $v.postclosure_diagnosis.contextual_contact_gate_failure.cap_route_causality_established = $true },
    { param($v) $v.postclosure_diagnosis.raw_yaw_diagnostic_only.turning_result = $true },
    { param($v) $v.successor_requirements.retained_r23d57_evidence_may_be_promoted_to_a_valid_result = $true },
    { param($v) $v.successor_requirements.physical_successor_authorized_by_this_closure = $true },
    { param($v) $v.claims.r23d57_valid_physical_characterization = $true },
    { param($v) $v.claims.godot_jolt_r23d29_turning = $true },
    { param($v) $v.claims.prone_to_standing = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D57ClosureSemanticVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D57Closure ($mutationRejectionCount -eq $mutations.Count) (
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
    $turningGate[0].proof.closed_r23d57_attempt
} else { $null }
$matrixRecord = Find-R23D57ClosedRecord $supportMatrix
$closureHash = Get-R23D57Sha256 $closurePath
$auditHash = Get-R23D57Sha256 $closureAuditPath
Assert-R23D57Closure (
    $turningGate.Count -eq 1 -and
    $null -ne $contractRecord -and $null -ne $matrixRecord -and
    [string]$contractRecord.status -ceq [string]$closure.status -and
    [string]$matrixRecord.status -ceq [string]$closure.status -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d57_godot_full_precision_trace_actuator_phase_characterization_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.closure_audit_path -ceq
        "tests/test_qsdk_r23d57_physical_closure.ps1" -and
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
    [int]$contractRecord.retained_trace_row_count -eq 8976 -and
    [int]$matrixRecord.retained_trace_row_count -eq 8976 -and
    [int]$contractRecord.retained_actuator_application_count -eq 71808 -and
    [int]$matrixRecord.retained_actuator_application_count -eq 71808 -and
    [int]$contractRecord.declared_cap_exact_mismatch_count -eq 24 -and
    [int]$matrixRecord.declared_cap_exact_mismatch_count -eq 24 -and
    [int]$contractRecord.rear_contact_cycle_count -eq 0 -and
    [int]$matrixRecord.rear_contact_cycle_count -eq 0 -and
    [bool]$contractRecord.identity_consumed -and
    [bool]$matrixRecord.identity_consumed -and
    -not [bool]$contractRecord.same_identity_rerun_allowed -and
    -not [bool]$matrixRecord.same_identity_rerun_allowed -and
    [bool]$contractRecord.full_precision_trace_transport_succeeded -and
    [bool]$matrixRecord.full_precision_trace_transport_succeeded -and
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
        $_.Name -like "qsdk-r23d57-*" -and
        (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json"))
    }
)
Assert-R23D57Closure (
    $completedAttempts.Count -eq 1 -and
    $completedAttempts[0].FullName -ceq $attemptRoot
) "R23D57 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D57_CLOSURE_PASS classification=complete_invalid worlds=3 " +
    "execution_valid=0 full_precision_rows=8976 applications=71808 " +
    "declared_cap_exact_mismatches=24 identity_mismatches=0 " +
    "rear_contact_cycles=0 rear_contact_true_steps=17952 " +
    "evaluator_replay=True cas_refs=252 cas_unique=132 " +
    "mutations=$mutationRejectionCount rerun=False turning=False " +
    "prone=False release=False"
)
