param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [string]$Python = "C:\Program Files\Python311\python.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
$evidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$sourceCommit = "ecfc191bcc97ea53b089e9862a5d0b5a7a8ad6b5"
$sourceTree = "484a99d201ac7200e34039d16e1b0b56d0b47f7a"
$attemptId = "5d29697174f04d6c9d5a89dda2288165"
$campaignId = (
    "QSDK-R23D58-GODOT-CAP-SOURCE-FACTORIAL-REAR-CONTACT-" +
    "MECHANISM-DEVELOPMENT"
)
$classification = (
    "valid_complete_outcome_exposed_godot_cap_source_factorial_" +
    "rear_contact_mechanism_development"
)
$closedStatus = "closed_consumed_$classification"
$attemptRoot = Join-Path $evidenceRoot (
    "qsdk-r23d58-ecfc191-development-attempt-1"
)
$qualificationRoot = Join-Path $evidenceRoot (
    "qsdk-r23d58-qualification-ecfc191"
)
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d58_godot_cap_source_factorial_closure_v1.json"
)
$auditPath = Join-Path $repoRoot "tests\test_qsdk_r23d58_physical_closure.ps1"
$profileIds = @(
    "portable_hip__portable_knee",
    "portable_hip__fixture_knee",
    "fixture_hip__portable_knee",
    "fixture_hip__fixture_knee"
)
$limbIds = @("rear_left", "front_left", "rear_right", "front_right")
$expectedCommonGate = @($false, $true, $false, $true)
$expectedCycles = @(
    @(0, 4, 0, 3),
    @(8, 5, 8, 4),
    @(0, 5, 0, 3),
    @(8, 4, 11, 4)
)
$expectedContactSteps = @(
    @(2992, 2880, 2992, 2870),
    @(2649, 2755, 2702, 2759),
    @(2992, 2846, 2992, 2862),
    @(2658, 2853, 2635, 2797)
)
$expectedFirstLoss = @(
    @($null, 546, $null, 908),
    @(328, 517, 235, 773),
    @($null, 584, $null, 950),
    @(327, 517, 235, 801)
)
$expectedDisplacement = @(
    0.697227154275465,
    1.21881712747736,
    0.492776162367969,
    1.25721381107103
)
$expectedYaw = @(
    -0.325518754199972,
    -0.0620165357279967,
    -0.189481373641816,
    -0.137711520263665
)
$expectedHeight = @(
    0.426941990852356,
    0.427165299654007,
    0.425986915826797,
    0.42715123295784
)
$expectedTilt = @(
    0.0540085717211964,
    0.14434317394159,
    0.0602876427788427,
    0.134424688301668
)
$expectedTraceSha = @(
    "sha256:fd8cac6aed2a5278a911aa28352a77788fd36943400b112545c96862b439c3b5",
    "sha256:8c9b7307621e5310f0f85c6a6ca7b403f6c559290297ea2f44ad5861be233046",
    "sha256:248e2a219b2ab8334b567fbe25601c376ec21119809867794cb89e9750c98efa",
    "sha256:3605375d4e7bcb25b5dfc4476a9d487fc96e0d8da8dd3ab22d25238d15d02e00"
)
$expectedTraceBytes = @(34752288, 34493865, 34541860, 34249326)
$numericTolerance = 1.0e-12

function Assert-R23D58Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D58 CLOSURE: $Message" }
}

function Assert-R23D58Near(
    [double]$Actual,
    [double]$Expected,
    [double]$Tolerance,
    [string]$Message
) {
    Assert-R23D58Closure (
        [double]::IsFinite($Actual) -and
        [Math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-R23D58Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D58BytesSha256([byte[]]$Bytes) {
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($Bytes)
    ).ToLowerInvariant()
}

function Get-R23D58GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D58Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D58Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Add-R23D58CasReceipts(
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
        ) { $Receipts.Add($Value) }
        foreach ($property in $Value.PSObject.Properties) {
            Add-R23D58CasReceipts $property.Value $Receipts
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($child in $Value.Values) {
            Add-R23D58CasReceipts $child $Receipts
        }
        return
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            Add-R23D58CasReceipts $child $Receipts
        }
    }
}

function Assert-R23D58CasGroup($Group) {
    $first = @($Group.Group)[0]
    $sha = [string]$first.sha256
    $byteLength = [long]$first.byte_length
    Assert-R23D58Closure ($sha -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $sha"
    )
    foreach ($receipt in @($Group.Group)) {
        Assert-R23D58Closure (
            [string]$receipt.schema_version -ceq
                "sporespore_content_addressed_artifact_receipt_v1" -and
            [string]$receipt.sha256 -ceq $sha -and
            [long]$receipt.byte_length -eq $byteLength -and
            -not [bool]$receipt.test_only -and
            -not [bool]$receipt.physical_acceptance_authority
        ) "CAS receipt semantics changed: $sha"
    }
    $directory = Join-Path $artifactRoot $sha.Substring(7)
    $payload = Join-Path $directory "payload.bin"
    $manifestPath = Join-Path $directory "manifest.json"
    Assert-R23D58Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $byteLength -and
        (Get-R23D58Sha256 $payload) -ceq $sha
    ) "CAS payload changed: $sha"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D58Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $sha -and
        [long]$manifest.byte_length -eq $byteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $sha"
}

function Find-R23D58ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d58_attempt")) {
            return $Value["closed_r23d58_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D58ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d58_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($childProperty in $Value.PSObject.Properties) {
            $found = Find-R23D58ClosedRecord $childProperty.Value
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D58ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D58ClaimVector($Value) {
    try {
        return (
            [bool]$Value.r23d58_complete_four_world_attempt_executed -and
            [bool]$Value.r23d58_all_four_cells_execution_valid -and
            [bool]$Value.r23d58_full_precision_traces_retained -and
            [bool]$Value.live_fixture_actuator_cap_binding_verified -and
            [bool]$Value.actuator_phase_characterization_complete -and
            [bool]$Value.cap_source_factorial_characterization_complete -and
            [bool]$Value.within_attempt_knee_cap_source_sensitivity_observed -and
            -not [bool]$Value.compiled_cap_causality_established -and
            -not [bool]$Value.rear_contact_mechanism_selected -and
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

function Test-R23D58ClosureSemanticVector($Value) {
    try {
        return (
            [string]$Value.status -ceq $closedStatus -and
            [string]$Value.source_commit -ceq $sourceCommit -and
            [string]$Value.source_tree_git_oid -ceq $sourceTree -and
            [string]$Value.attempt_id -ceq $attemptId -and
            [bool]$Value.identity_consumed -and
            -not [bool]$Value.same_identity_rerun_allowed -and
            -not [bool]$Value.selective_rerun_allowed -and
            -not [bool]$Value.replacement_rerun_allowed -and
            -not [bool]$Value.fresh_held_out_condition_consumed -and
            -not [bool]$Value.successor_campaign_opened -and
            [bool]$Value.physical_series_paused_before_successor -and
            [string]$Value.official_result.classification -ceq $classification -and
            [int]$Value.official_result.observed_world_attempt_count -eq 4 -and
            [int]$Value.official_result.observed_world_build_count -eq 4 -and
            [int]$Value.official_result.execution_valid_cell_count -eq 4 -and
            [int]$Value.official_result.contextual_common_physical_gate_pass_cell_count -eq 2 -and
            [int]$Value.official_result.contextual_common_physical_gate_fail_cell_count -eq 2 -and
            [int]$Value.official_result.retained_trace_row_count -eq 11968 -and
            [int]$Value.official_result.retained_actuator_application_count -eq 95744 -and
            [bool]$Value.official_result.live_fixture_actuator_cap_binding_verified -and
            [bool]$Value.official_result.cap_source_factorial_characterization_complete -and
            -not [bool]$Value.official_result.all_contextual_common_physical_gates_passed -and
            -not [bool]$Value.official_result.turning_gate_invoked -and
            -not [bool]$Value.official_result.turning_mechanism_selected -and
            -not [bool]$Value.official_result.rear_contact_mechanism_selected -and
            -not [bool]$Value.official_result.compiled_cap_causality_established -and
            [int]$Value.physical_evidence.postclosure_detected_unbound_runtime_dependency_count -eq 4 -and
            [string]$Value.postclosure_provenance_finding.classification -ceq
                "explicit_physical_freeze_source_inventory_incomplete_but_clean_pushed_git_tree_reconstructible" -and
            [bool]$Value.postclosure_provenance_finding.detected_during_first_cold_closure_replay -and
            [int]$Value.postclosure_provenance_finding.total_omitted_runtime_dependency_count -eq 4 -and
            [int]$Value.postclosure_provenance_finding.omitted_transitive_python_import_count -eq 3 -and
            [int]$Value.postclosure_provenance_finding.omitted_declaration_binding_count -eq 1 -and
            [bool]$Value.postclosure_provenance_finding.all_omitted_imports_resolve_to_exact_blobs_in_source_commit -and
            [bool]$Value.postclosure_provenance_finding.cold_evaluator_replay_passed_after_exact_git_blob_materialization -and
            -not [bool]$Value.postclosure_provenance_finding.prospective_explicit_dependency_inventory_complete -and
            [bool]$Value.postclosure_provenance_finding.full_clean_pushed_source_tree_identity_complete -and
            -not [bool]$Value.postclosure_provenance_finding.result_payload_or_interpretation_changed -and
            -not [bool]$Value.postclosure_provenance_finding.result_reclassified -and
            -not [bool]$Value.postclosure_provenance_finding.result_reuse_authorized -and
            -not [bool]$Value.postclosure_provenance_finding.physical_acceptance_authority -and
            [bool]$Value.bounded_interpretation.portable_knee_profiles_reproduced_continuous_rear_contact -and
            [bool]$Value.bounded_interpretation.fixture_knee_profiles_observed_rear_contact_cycles -and
            -not [bool]$Value.bounded_interpretation.hip_source_change_alone_restored_rear_contact_cycles -and
            [bool]$Value.bounded_interpretation.within_attempt_knee_cap_source_sensitivity_observed -and
            -not [bool]$Value.bounded_interpretation.one_world_per_profile_repeatability_adequate -and
            -not [bool]$Value.bounded_interpretation.production_mechanism_selection_adequate -and
            -not [bool]$Value.bounded_interpretation.turning_acceptance_adequate -and
            [bool]$Value.successor_requirements.distinct_campaign_identity_required -and
            [bool]$Value.successor_requirements.r23d58_rerun_forbidden -and
            [bool]$Value.successor_requirements.selective_profile_rerun_forbidden -and
            -not [bool]$Value.successor_requirements.retained_r23d58_evidence_may_be_promoted_to_mechanism_selection -and
            -not [bool]$Value.successor_requirements.retained_r23d58_evidence_may_be_promoted_to_turning_acceptance -and
            -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
            (Test-R23D58ClaimVector $Value.claims)
        )
    } catch { return $false }
}

function Get-R23D58MetricDelta($Contrast, [string]$MetricId) {
    $matches = @($Contrast.ordered_metric_deltas | Where-Object {
        [string]$_.metric_id -ceq $MetricId
    })
    Assert-R23D58Closure ($matches.Count -eq 1) (
        "contrast metric cardinality changed: $MetricId"
    )
    return [double]$matches[0].delta
}

Assert-R23D58Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure is missing: $closurePath"
)
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -Depth 100
Assert-R23D58Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d58_godot_cap_source_factorial_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D58" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.question_class -ceq "development" -and
    [int]$closure.campaign_seed -eq 21512 -and
    (Test-R23D58ClosureSemanticVector $closure)
) "closure identity or semantic vector changed"

$observedTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
Assert-R23D58Closure ($LASTEXITCODE -eq 0 -and $observedTree -ceq $sourceTree) (
    "physical source tree changed or is unavailable"
)

$attestationSpec = $closure.qualification_history.accepted_scoped_attestation
$adoptionSpec = $closure.qualification_history.adoption
foreach ($spec in @($attestationSpec, $adoptionSpec)) {
    $path = [IO.Path]::GetFullPath([string]$spec.path)
    Assert-R23D58Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$spec.byte_length -and
        (Get-R23D58Sha256 $path) -ceq [string]$spec.raw_sha256
    ) "qualification artifact changed: $path"
}
$attestation = Get-Content -Raw -LiteralPath ([string]$attestationSpec.path) |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath ([string]$adoptionSpec.path) |
    ConvertFrom-Json -Depth 100
Assert-R23D58Closure (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [int]$attestation.executed_gate_count -eq 21 -and
    [int]$attestation.declared_physical_world_count -eq 4 -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.physical_acceptance_authority -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$attestationSpec.raw_sha256 -and
    [int]$adoption.declared_physical_world_count -eq 4 -and
    [int]$adoption.executed_gate_count -eq 21 -and
    [int]$adoption.gate_cas_object_count -eq 63 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "qualification or adoption authority changed"

$inventory = @($closure.physical_evidence.file_inventory)
$actualFiles = @(Get-ChildItem -LiteralPath $attemptRoot -Recurse -File)
Assert-R23D58Closure (
    $inventory.Count -eq 26 -and
    $actualFiles.Count -eq 26 -and
    [long]$closure.physical_evidence.retained_byte_count -eq 277082567
) "retained evidence inventory cardinality changed"
$inventoryPaths = @($inventory | ForEach-Object { [string]$_.path } | Sort-Object)
$actualPaths = @($actualFiles | ForEach-Object {
    $_.FullName.Substring($attemptRoot.Length + 1).Replace('\', '/')
} | Sort-Object)
Assert-R23D58Closure (
    ($inventoryPaths -join "`n") -ceq ($actualPaths -join "`n")
) "retained evidence file set changed"
foreach ($entry in $inventory) {
    $path = Join-Path $attemptRoot ([string]$entry.path).Replace('/', '\')
    Assert-R23D58Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length -and
        (Get-R23D58Sha256 $path) -ceq [string]$entry.raw_sha256
    ) "retained evidence bytes changed: $($entry.path)"
}

$metadataFiles = @($inventory | Where-Object {
    [string]$_.path -like "*.json" -and
    [string]$_.path -notlike "pending-traces/*"
} | ForEach-Object {
    Join-Path $attemptRoot ([string]$_.path).Replace('/', '\')
}) + @([string]$attestationSpec.path, [string]$adoptionSpec.path)
Assert-R23D58Closure ($metadataFiles.Count -eq 12) (
    "CAS-bearing metadata file count changed"
)
$receipts = [Collections.Generic.List[object]]::new()
foreach ($metadataPath in $metadataFiles) {
    Add-R23D58CasReceipts (
        Get-Content -Raw -LiteralPath $metadataPath |
            ConvertFrom-Json -Depth 100
    ) $receipts
}
$receiptGroups = @($receipts | Group-Object { [string]$_.sha256 })
Assert-R23D58Closure (
    $receipts.Count -eq 269 -and
    $receiptGroups.Count -eq 153 -and
    [int]$closure.physical_evidence.content_addressed_receipt_reference_count -eq 269 -and
    [int]$closure.physical_evidence.content_addressed_unique_object_count -eq 153 -and
    [int]$closure.physical_evidence.invalid_content_addressed_reference_count -eq 0
) "CAS receipt counts changed"
foreach ($group in $receiptGroups) { Assert-R23D58CasGroup $group }

$freeze = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "physical-freeze.json") |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "attempt-authorization.json"
) | ConvertFrom-Json -Depth 100
$terminalManifest = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "terminal-paths.json"
) | ConvertFrom-Json -Depth 20
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "complete-evaluation.json"
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "report.json") |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "completion.json"
) | ConvertFrom-Json -Depth 100
Assert-R23D58Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d58_physical_freeze_v1" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [int]$freeze.declared_world_count -eq 4 -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.physical_acceptance_authority -and
    @($freeze.source_bindings).Count -eq 87 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3
) "physical freeze changed"
Assert-R23D58Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d58_attempt_v1" -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.source_worktree_clean -and
    [bool]$authorization.source_matches_live_github_main -and
    [bool]$authorization.operation_lock_held -and
    [bool]$authorization.campaign_attestation_adoption_valid -and
    -not [bool]$authorization.physical_acceptance_authority
) "attempt authorization changed"
Assert-R23D58Closure (
    @($terminalManifest).Count -eq 4 -and
    [string]$completion.schema_version -ceq
        "sporespore_qsdk_r23d58_completion_v1" -and
    [string]$completion.status -ceq $classification -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.cell_count -eq 4 -and
    [int]$completion.world_count -eq 4 -and
    [bool]$completion.world_count_exact -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$report.result_classification -ceq $classification -and
    [bool]$report.all_four_cells_executed_or_retained_as_failures -and
    [bool]$report.world_build_count_exact -and
    [int]$report.world_build_count_lower_bound -eq 4 -and
    [int]$report.world_build_count_upper_bound -eq 4 -and
    -not [bool]$report.terminal_restoration_or_taper_invoked
) "completion or report boundary changed"
Assert-R23D58Closure (
    [string]$evaluation.schema_version -ceq
        "sporespore_qsdk_r23d58_complete_evaluation_v1" -and
    [string]$evaluation.classification -ceq $classification -and
    [string]$evaluation.source_commit -ceq $sourceCommit -and
    [string]$evaluation.question_class -ceq "development" -and
    [int]$evaluation.cell_count -eq 4 -and
    [bool]$evaluation.all_declared_cells_executed_or_retained_as_failures -and
    [bool]$evaluation.engine_result.all_cells_execution_valid -and
    -not [bool]$evaluation.engine_result.all_contextual_common_physical_gates_passed -and
    [bool]$evaluation.engine_result.live_fixture_actuator_cap_binding_verified -and
    [bool]$evaluation.engine_result.cap_source_factorial_characterization_complete -and
    -not [bool]$evaluation.engine_result.turning_gate_invoked -and
    -not [bool]$evaluation.engine_result.turning_mechanism_selected -and
    [bool]$evaluation.claims.cap_source_factorial_characterization_complete -and
    -not [bool]$evaluation.claims.compiled_cap_causality_established -and
    -not [bool]$evaluation.claims.rear_contact_mechanism_selected -and
    -not [bool]$evaluation.claims.physical_acceptance_authority
) "complete evaluation boundary changed"

for ($profileIndex = 0; $profileIndex -lt $profileIds.Count; $profileIndex++) {
    $profileId = $profileIds[$profileIndex]
    $closureProfile = @($closure.ordered_profiles)[$profileIndex]
    $cellEvaluation = @($evaluation.cell_evaluations)[$profileIndex]
    $characterization = $evaluation.engine_result.characterization_by_profile.$profileId
    Assert-R23D58Closure (
        [string]$closureProfile.profile_id -ceq $profileId -and
        [string]$cellEvaluation.profile_id -ceq $profileId -and
        [bool]$cellEvaluation.execution_valid -and
        [bool]$cellEvaluation.common_physical_gate_passed -eq
            $expectedCommonGate[$profileIndex] -and
        [bool]$closureProfile.contextual_common_physical_gate_passed -eq
            $expectedCommonGate[$profileIndex] -and
        [int]$characterization.observation_row_count -eq 2992 -and
        [int]$characterization.application_count -eq 23936 -and
        -not [bool]$characterization.measured_motor_impulse_available -and
        -not [bool]$characterization.measured_motor_torque_available -and
        -not [bool]$characterization.mechanism_selected -and
        -not [bool]$characterization.turning_gate_invoked -and
        -not [bool]$characterization.physical_acceptance_authority
    ) "profile execution boundary changed: $profileId"
    $expectedFailures = if ($expectedCommonGate[$profileIndex]) {
        @()
    } else { @("R23D34_CONTACT_CYCLES") }
    Assert-R23D58Closure (
        (@($cellEvaluation.failed_gate_ids) -join "|") -ceq
            ($expectedFailures -join "|") -and
        (@($closureProfile.failed_gate_ids) -join "|") -ceq
            ($expectedFailures -join "|")
    ) "profile failed-gate vector changed: $profileId"
    foreach ($limb in @($characterization.per_limb_contact_characterization)) {
        $limbIndex = [Array]::IndexOf($limbIds, [string]$limb.limb_id)
        Assert-R23D58Closure ($limbIndex -ge 0) (
            "unexpected limb: $($limb.limb_id)"
        )
        $closureCycles = [int]$closureProfile.contact_cycles.($limbIds[$limbIndex])
        $closureSteps = [int]$closureProfile.contact_true_steps.($limbIds[$limbIndex])
        Assert-R23D58Closure (
            [int]$limb.complete_contact_cycle_count -eq
                $expectedCycles[$profileIndex][$limbIndex] -and
            [int]$limb.contact_true_step_count -eq
                $expectedContactSteps[$profileIndex][$limbIndex] -and
            $closureCycles -eq $expectedCycles[$profileIndex][$limbIndex] -and
            $closureSteps -eq $expectedContactSteps[$profileIndex][$limbIndex]
        ) "contact characterization changed: $profileId/$($limb.limb_id)"
        $expectedLoss = $expectedFirstLoss[$profileIndex][$limbIndex]
        if ($null -eq $expectedLoss) {
            Assert-R23D58Closure (
                $null -eq $limb.first_contact_loss_semantic_step_or_null -and
                $null -eq $closureProfile.first_contact_loss_semantic_step.($limbIds[$limbIndex])
            ) "null first-loss boundary changed: $profileId/$($limb.limb_id)"
        } else {
            Assert-R23D58Closure (
                [int]$limb.first_contact_loss_semantic_step_or_null -eq
                    [int]$expectedLoss -and
                [int]$closureProfile.first_contact_loss_semantic_step.($limbIds[$limbIndex]) -eq
                    [int]$expectedLoss
            ) "first-loss boundary changed: $profileId/$($limb.limb_id)"
        }
    }
    Assert-R23D58Near (
        [double]$characterization.torso_pose_and_displacement_context.displacement_norm_m
    ) $expectedDisplacement[$profileIndex] $numericTolerance (
        "displacement changed: $profileId"
    )
    Assert-R23D58Near (
        [double]$characterization.torso_pose_and_displacement_context.yaw_delta_rad
    ) $expectedYaw[$profileIndex] $numericTolerance "yaw changed: $profileId"
    Assert-R23D58Near (
        [double]$characterization.torso_pose_and_displacement_context.minimum_torso_height_m
    ) $expectedHeight[$profileIndex] $numericTolerance (
        "minimum height changed: $profileId"
    )
    Assert-R23D58Near (
        [double]$characterization.torso_pose_and_displacement_context.maximum_absolute_torso_tilt_rad
    ) $expectedTilt[$profileIndex] $numericTolerance (
        "maximum tilt changed: $profileId"
    )
    Assert-R23D58Closure (
        [int]$characterization.torso_contact_characterization.contact_true_step_count -eq 0
    ) "torso contact changed: $profileId"
    $cellId = [string]$cellEvaluation.cell_id
    $terminalPath = Join-Path $attemptRoot "cells\$cellId\terminal.json"
    $terminal = Get-Content -Raw -LiteralPath $terminalPath |
        ConvertFrom-Json -Depth 100
    Assert-R23D58Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d58_engine_cell_report_v1" -and
        [string]$terminal.profile_id -ceq $profileId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
        [bool]$terminal.trace_summary.ok -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [string]$terminal.trace_artifact.sha256 -ceq
            $expectedTraceSha[$profileIndex] -and
        [long]$terminal.trace_artifact.byte_length -eq
            $expectedTraceBytes[$profileIndex] -and
        [bool]$terminal.trace_artifact.godot_json_full_precision -and
        [bool]$terminal.trace_artifact.godot_json_sorted_keys -and
        -not [bool]$terminal.trace_artifact.physical_acceptance_authority -and
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0
    ) "retained terminal changed: $profileId"
}

$contrastBlock = $evaluation.engine_result.predeclared_factorial_contrasts
$contrasts = @($contrastBlock.ordered_contrasts)
$contrastIds = @(
    "knee_source_at_portable_hip",
    "knee_source_at_fixture_hip",
    "hip_source_at_portable_knee",
    "hip_source_at_fixture_knee",
    "interaction"
)
Assert-R23D58Closure (
    $contrasts.Count -eq 5 -and
    [int]$contrastBlock.ordered_contrast_count -eq 5 -and
    [int]$contrastBlock.outcome_threshold_count -eq 0 -and
    -not [bool]$contrastBlock.superiority_margin_declared -and
    -not [bool]$contrastBlock.equivalence_or_non_inferiority_margin_declared -and
    -not [bool]$contrastBlock.mechanism_selected -and
    -not [bool]$contrastBlock.posthoc_profile_selection_performed -and
    -not [bool]$contrastBlock.turning_gate_invoked -and
    -not [bool]$contrastBlock.physical_acceptance_authority
) "factorial contrast authority changed"
for ($contrastIndex = 0; $contrastIndex -lt $contrastIds.Count; $contrastIndex++) {
    Assert-R23D58Closure (
        [string]$contrasts[$contrastIndex].contrast_id -ceq
            $contrastIds[$contrastIndex] -and
        -not [bool]$contrasts[$contrastIndex].mechanism_selection_authority -and
        -not [bool]$contrasts[$contrastIndex].superiority_or_equivalence_interpretation
    ) "factorial contrast order changed"
}
$expectedRearDeltas = @(@(8, 8), @(8, 11), @(0, 0), @(0, 3), @(0, 3))
for ($contrastIndex = 0; $contrastIndex -lt $contrasts.Count; $contrastIndex++) {
    Assert-R23D58Near (
        Get-R23D58MetricDelta $contrasts[$contrastIndex] (
            "limb.rear_left.complete_contact_cycle_count"
        )
    ) $expectedRearDeltas[$contrastIndex][0] 0.0 (
        "rear-left contrast changed: $($contrastIds[$contrastIndex])"
    )
    Assert-R23D58Near (
        Get-R23D58MetricDelta $contrasts[$contrastIndex] (
            "limb.rear_right.complete_contact_cycle_count"
        )
    ) $expectedRearDeltas[$contrastIndex][1] 0.0 (
        "rear-right contrast changed: $($contrastIds[$contrastIndex])"
    )
}

$sourceBindings = @($freeze.source_bindings)
Assert-R23D58Closure (
    $sourceBindings.Count -eq 87 -and
    [int]$closure.physical_evidence.physical_freeze_source_binding_count -eq 87
) "physical source binding count changed"
$sourceBytes = @{}
foreach ($binding in $sourceBindings) {
    $relative = [string]$binding.path
    Assert-R23D58Closure (
        [bool]$binding.raw_checkout_equals_git_blob -and
        [string]$binding.raw_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        [string]$binding.git_blob_oid -cmatch '^[0-9a-f]{40}$'
    ) "source binding schema changed: $relative"
    $bytes = Get-R23D58GitBlobBytes $sourceCommit $relative
    Assert-R23D58Closure (
        (Get-R23D58BytesSha256 $bytes) -ceq [string]$binding.raw_sha256
    ) "pinned source bytes changed: $relative"
    $observedOid = (& git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R23D58Closure (
        $LASTEXITCODE -eq 0 -and
        $observedOid -ceq [string]$binding.git_blob_oid
    ) "pinned source object changed: $relative"
    $sourceBytes[$relative] = $bytes
}

$omittedImports = @(
    $closure.postclosure_provenance_finding.omitted_transitive_python_imports
)
$expectedOmittedPaths = @(
    "sdk/turning/r23d56_godot_valid_route_actuator_phase_characterization.py",
    "sdk/turning/r23d54_godot_actuator_phase_characterization.py",
    "sdk/turning/r23d53_godot_warmup_preserving_origin_reanchor.py"
)
$expectedOmittedOids = @(
    "1a30907e5237e645141dfb41de444f37b74e298f",
    "6457405b169909ebc194e67f487716a950a143e1",
    "4e16cd8a3b28b112eb16c81c1032db466f7e27db"
)
$expectedOmittedSha = @(
    "sha256:d3e0a3bc2c76d42964c1a5b3a069e43375f8d361b7cc77edcb5ad5e01dd2471a",
    "sha256:fbb4a0dfc622183e81abe5b9016621dd640685772c4a11e19582064eb2e4765c",
    "sha256:4fbaa2b7ce5e095af50841669949b82b2cfea9852066a996133b5f61f3a9d9c1"
)
$expectedOmittedBytes = @(5157, 4735, 4423)
Assert-R23D58Closure ($omittedImports.Count -eq 3) (
    "omitted transitive import count changed"
)
for ($omittedIndex = 0; $omittedIndex -lt 3; $omittedIndex++) {
    $spec = $omittedImports[$omittedIndex]
    $relative = [string]$spec.path
    Assert-R23D58Closure (
        $relative -ceq $expectedOmittedPaths[$omittedIndex] -and
        [string]$spec.git_blob_oid -ceq $expectedOmittedOids[$omittedIndex] -and
        [string]$spec.raw_sha256 -ceq $expectedOmittedSha[$omittedIndex] -and
        [long]$spec.byte_length -eq $expectedOmittedBytes[$omittedIndex] -and
        -not (@($sourceBindings.path) -ccontains $relative)
    ) "omitted transitive import declaration changed: $relative"
    $bytes = Get-R23D58GitBlobBytes $sourceCommit $relative
    $observedOid = (& git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R23D58Closure (
        $LASTEXITCODE -eq 0 -and
        $observedOid -ceq [string]$spec.git_blob_oid -and
        (Get-R23D58BytesSha256 $bytes) -ceq [string]$spec.raw_sha256 -and
        $bytes.Length -eq [long]$spec.byte_length
    ) "omitted transitive import blob changed: $relative"
    $sourceBytes[$relative] = $bytes
}
$omittedDeclarationBindings = @(
    $closure.postclosure_provenance_finding.omitted_declaration_bindings
)
Assert-R23D58Closure ($omittedDeclarationBindings.Count -eq 1) (
    "omitted declaration binding count changed"
)
$declarationSpec = $omittedDeclarationBindings[0]
$declarationRelative = [string]$declarationSpec.path
Assert-R23D58Closure (
    $declarationRelative -ceq "tests/test_sdk_godot_jolt_full_authority.gd" -and
    [string]$declarationSpec.dependency_role -ceq
        "r23d58_declaration_bound_zero_world_regression_source_reverified_by_evaluator" -and
    [string]$declarationSpec.git_blob_oid -ceq
        "cbce55e6003d82b4492db93caf0212cc4e44948c" -and
    [string]$declarationSpec.raw_sha256 -ceq
        "sha256:1774e75cab49b24432294865e2d10f5469fad234fd1a7b0ea6d9a5dd7e960d52" -and
    [long]$declarationSpec.byte_length -eq 9691 -and
    -not (@($sourceBindings.path) -ccontains $declarationRelative)
) "omitted declaration binding declaration changed"
$declarationBytes = Get-R23D58GitBlobBytes $sourceCommit $declarationRelative
$declarationOid = (& git -C $repoRoot rev-parse (
    "$sourceCommit`:$declarationRelative"
)).Trim()
Assert-R23D58Closure (
    $LASTEXITCODE -eq 0 -and
    $declarationOid -ceq [string]$declarationSpec.git_blob_oid -and
    (Get-R23D58BytesSha256 $declarationBytes) -ceq
        [string]$declarationSpec.raw_sha256 -and
    $declarationBytes.Length -eq [long]$declarationSpec.byte_length
) "omitted declaration binding blob changed"
$sourceBytes[$declarationRelative] = $declarationBytes

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempBase (
    "sporespore-r23d58-closure-" + [Guid]::NewGuid().ToString("N")
)
Assert-R23D58Closure (
    $tempRoot.StartsWith($tempBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase)
) "temporary evaluator root escaped system temp"
New-Item -ItemType Directory -Path $tempRoot -ErrorAction Stop | Out-Null
try {
    foreach ($relative in $sourceBytes.Keys) {
        $target = Join-Path $tempRoot ([string]$relative).Replace('/', '\')
        $parent = Split-Path -Parent $target
        if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        [IO.File]::WriteAllBytes($target, [byte[]]$sourceBytes[$relative])
    }
    $evaluatorPath = Join-Path $tempRoot (
        "sdk\turning\r23d58_godot_cap_source_factorial_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D58Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $marker = "QSDK_R23D58_COMPLETE_EVALUATION "
    $lines = @($evaluatorOutput | Where-Object {
        [string]$_ -and ([string]$_).StartsWith($marker, [StringComparison]::Ordinal)
    })
    Assert-R23D58Closure ($lines.Count -eq 1) (
        "pinned evaluator marker changed"
    )
    $replayed = ([string]$lines[0]).Substring($marker.Length) |
        ConvertFrom-Json -Depth 100
    Assert-R23D58Closure (
        [string]$replayed.classification -ceq $classification -and
        [string]$replayed.source_commit -ceq $sourceCommit -and
        [int]$replayed.cell_count -eq 4 -and
        [bool]$replayed.engine_result.all_cells_execution_valid -and
        -not [bool]$replayed.engine_result.all_contextual_common_physical_gates_passed -and
        [bool]$replayed.claims.cap_source_factorial_characterization_complete -and
        -not [bool]$replayed.claims.rear_contact_mechanism_selected -and
        -not [bool]$replayed.claims.turning_mechanism_selected -and
        -not [bool]$replayed.claims.physical_acceptance_authority
    ) "pinned evaluator no longer reproduces the complete result"
} finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

$mutations = @(
    { param($v) $v.status = "closed_positive" },
    { param($v) $v.source_commit = "0" * 40 },
    { param($v) $v.attempt_id = "wrong" },
    { param($v) $v.identity_consumed = $false },
    { param($v) $v.same_identity_rerun_allowed = $true },
    { param($v) $v.selective_rerun_allowed = $true },
    { param($v) $v.successor_campaign_opened = $true },
    { param($v) $v.official_result.observed_world_build_count = 3 },
    { param($v) $v.official_result.execution_valid_cell_count = 3 },
    { param($v) $v.official_result.contextual_common_physical_gate_pass_cell_count = 4 },
    { param($v) $v.official_result.retained_trace_row_count = 0 },
    { param($v) $v.official_result.all_contextual_common_physical_gates_passed = $true },
    { param($v) $v.official_result.turning_gate_invoked = $true },
    { param($v) $v.official_result.turning_mechanism_selected = $true },
    { param($v) $v.official_result.rear_contact_mechanism_selected = $true },
    { param($v) $v.official_result.compiled_cap_causality_established = $true },
    { param($v) $v.postclosure_provenance_finding.prospective_explicit_dependency_inventory_complete = $true },
    { param($v) $v.postclosure_provenance_finding.result_reuse_authorized = $true },
    { param($v) $v.bounded_interpretation.hip_source_change_alone_restored_rear_contact_cycles = $true },
    { param($v) $v.bounded_interpretation.one_world_per_profile_repeatability_adequate = $true },
    { param($v) $v.bounded_interpretation.production_mechanism_selection_adequate = $true },
    { param($v) $v.bounded_interpretation.turning_acceptance_adequate = $true },
    { param($v) $v.successor_requirements.retained_r23d58_evidence_may_be_promoted_to_mechanism_selection = $true },
    { param($v) $v.successor_requirements.retained_r23d58_evidence_may_be_promoted_to_turning_acceptance = $true },
    { param($v) $v.successor_requirements.physical_successor_authorized_by_this_closure = $true },
    { param($v) $v.claims.compiled_cap_causality_established = $true },
    { param($v) $v.claims.rear_contact_mechanism_selected = $true },
    { param($v) $v.claims.godot_jolt_r23d29_turning = $true },
    { param($v) $v.claims.prone_to_standing = $true },
    { param($v) $v.claims.release_authorized = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 |
        ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D58ClosureSemanticVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D58Closure ($mutationRejectionCount -eq $mutations.Count) (
    "closure semantic mutation controls changed"
)

$releaseContract = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
) | ConvertFrom-Json -Depth 100
$supportMatrix = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
) | ConvertFrom-Json -Depth 100
$turningGates = @($releaseContract.gates | Where-Object {
    [string]$_.gate_id -ceq "QSDK-R23"
})
$contractRecord = if ($turningGates.Count -eq 1) {
    $turningGates[0].proof.closed_r23d58_attempt
} else { $null }
$matrixRecord = Find-R23D58ClosedRecord $supportMatrix
$closureHash = Get-R23D58Sha256 $closurePath
$auditHash = Get-R23D58Sha256 $auditPath
Assert-R23D58Closure (
    $turningGates.Count -eq 1 -and
    $null -ne $contractRecord -and
    $null -ne $matrixRecord -and
    [string]$contractRecord.status -ceq $closedStatus -and
    [string]$matrixRecord.status -ceq $closedStatus -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d58_godot_cap_source_factorial_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq
        [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.closure_audit_path -ceq
        "tests/test_qsdk_r23d58_physical_closure.ps1" -and
    [string]$matrixRecord.closure_audit_path -ceq
        [string]$contractRecord.closure_audit_path -and
    [string]$contractRecord.closure_audit_raw_sha256 -ceq $auditHash -and
    [string]$matrixRecord.closure_audit_sha256 -ceq $auditHash -and
    [string]$contractRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$matrixRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$contractRecord.attempt_id -ceq $attemptId -and
    [string]$matrixRecord.attempt_id -ceq $attemptId -and
    [int]$contractRecord.world_count -eq 4 -and
    [int]$matrixRecord.world_count -eq 4 -and
    [int]$contractRecord.execution_valid_cell_count -eq 4 -and
    [int]$matrixRecord.execution_valid_cell_count -eq 4 -and
    [int]$contractRecord.contextual_common_gate_pass_cell_count -eq 2 -and
    [int]$matrixRecord.contextual_common_gate_pass_cell_count -eq 2 -and
    [bool]$contractRecord.cap_source_factorial_characterization_complete -and
    [bool]$matrixRecord.cap_source_factorial_characterization_complete -and
    [bool]$contractRecord.within_attempt_knee_cap_source_sensitivity_observed -and
    [bool]$matrixRecord.within_attempt_knee_cap_source_sensitivity_observed -and
    [int]$contractRecord.postclosure_detected_unbound_runtime_dependency_count -eq 4 -and
    [int]$matrixRecord.postclosure_detected_unbound_runtime_dependency_count -eq 4 -and
    -not [bool]$contractRecord.prospective_explicit_dependency_inventory_complete -and
    -not [bool]$matrixRecord.prospective_explicit_dependency_inventory_complete -and
    [bool]$contractRecord.full_clean_pushed_source_tree_identity_complete -and
    [bool]$matrixRecord.full_clean_pushed_source_tree_identity_complete -and
    -not [bool]$contractRecord.result_reuse_authorized -and
    -not [bool]$matrixRecord.result_reuse_authorized -and
    -not [bool]$contractRecord.rear_contact_mechanism_selected -and
    -not [bool]$matrixRecord.rear_contact_mechanism_selected -and
    -not [bool]$contractRecord.turning_acceptance -and
    -not [bool]$matrixRecord.turning_acceptance -and
    -not [bool]$contractRecord.prone_to_standing -and
    -not [bool]$matrixRecord.prone_to_standing -and
    -not [bool]$contractRecord.release_authorized -and
    -not [bool]$matrixRecord.release_authorized -and
    -not [bool]$contractRecord.physical_acceptance_authority -and
    -not [bool]$matrixRecord.physical_acceptance_authority
) "release contract or support matrix closure boundary changed"

$catalog = Get-Content -Raw -LiteralPath (
    Join-Path $repoRoot "sdk\workbench\experiment_catalog.json"
) | ConvertFrom-Json -Depth 100
$workbenchRuns = @($catalog.runs | Where-Object {
    [string]$_.id -ceq "qsdk_r23d58_physical_closure"
})
Assert-R23D58Closure (
    $workbenchRuns.Count -eq 1 -and
    [string]$workbenchRuns[0].kind -ceq "closure_audit" -and
    [string]$workbenchRuns[0].world_policy -ceq "retained_evidence_only" -and
    [string]$workbenchRuns[0].risk -ceq "safe" -and
    [string]$workbenchRuns[0].runner_path -ceq
        "tests/test_qsdk_r23d58_physical_closure.ps1" -and
    @($workbenchRuns[0].arguments).Count -eq 0 -and
    @($workbenchRuns[0].proofs).Count -eq 2 -and
    [string]$workbenchRuns[0].proofs[0].expected_sha256 -ceq
        $closureHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[1].expected_sha256 -ceq
        $auditHash.Substring(7)
) "workbench closure exposure changed"

$attempts = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
    $_.Name -like "qsdk-r23d58-*-development-attempt-*" -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "completion.json") -PathType Leaf)
})
Assert-R23D58Closure (
    $attempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($attempts[0].FullName) -ceq
        [IO.Path]::GetFullPath($attemptRoot)
) "R23D58 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D58_CLOSURE_PASS classification=valid_complete_descriptive " +
    "worlds=4 execution_valid=4 contextual_pass=2 contextual_fail=2 " +
    "portable_knee_rear_cycles=0 fixture_knee_rear_cycles=35 " +
    "rows=11968 applications=95744 cas_refs=269 cas_unique=153 " +
    "source_bindings=87 transitive_imports=3 declaration_bindings_omitted=1 " +
    "dependency_inventory_complete=False " +
    "evaluator_replay=True " +
    "mutations=$mutationRejectionCount rerun=False selection=False " +
    "turning=False prone=False physical_authority=False release=False"
)
