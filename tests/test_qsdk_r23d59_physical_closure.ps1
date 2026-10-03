#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$evidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
$artifactRoot = Join-Path $evidenceRoot "artifacts\sha256"
$closurePath = Join-Path $repoRoot (
    "sdk\turning\r23d59_godot_knee_source_finite_decision_closure_v1.json"
)
$auditPath = [IO.Path]::GetFullPath($PSCommandPath)
$sourceCommit = "22020d397ea4ce952a67051a843c22b388f0f78b"
$sourceTree = "3c6cd67694c6e28312fadd7af8892997a867656c"
$campaignId = (
    "QSDK-R23D59-GODOT-KNEE-CAP-SOURCE-THREE-SEED-FINITE-DECISION"
)
$attemptId = "fdee70092dd147fa96ec6fb8dc29b4c8"
$classification = (
    "valid_complete_fixture_knee_profile_selected_r23d59_finite_decision"
)
$closedStatus = (
    "closed_consumed_valid_complete_fixture_knee_profile_selected_" +
    "r23d59_finite_decision"
)
$attemptRoot = Join-Path $evidenceRoot "qsdk-r23d59-20260815T214443Z"
$expectedCellIds = @(
    "godot_jolt__s21513__portable_hip__portable_knee",
    "godot_jolt__s21513__portable_hip__fixture_knee",
    "godot_jolt__s21514__portable_hip__portable_knee",
    "godot_jolt__s21514__portable_hip__fixture_knee",
    "godot_jolt__s21515__portable_hip__portable_knee",
    "godot_jolt__s21515__portable_hip__fixture_knee"
)

function Assert-R23D59Closure([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D59 closure: $Message" }
}

function Get-R23D59Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D59BytesSha256([byte[]]$Bytes) {
    $stream = [IO.MemoryStream]::new($Bytes, $false)
    try {
        return "sha256:" + [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($stream)
        ).ToLowerInvariant()
    } finally { $stream.Dispose() }
}

function Get-R23D59GitBlobBytes([string]$Commit, [string]$RelativePath) {
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
    Assert-R23D59Closure ($process.Start()) "could not start git cat-file"
    $memory = [IO.MemoryStream]::new()
    try {
        $process.StandardOutput.BaseStream.CopyTo($memory)
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
        Assert-R23D59Closure ($process.ExitCode -eq 0) (
            "historical blob unavailable: $RelativePath; $stderr"
        )
        return ,([byte[]]$memory.ToArray())
    } finally {
        $memory.Dispose()
        $process.Dispose()
    }
}

function Add-R23D59CasReceipts(
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
            Add-R23D59CasReceipts $property.Value $Receipts
        }
        return
    }
    if ($Value -is [Collections.IDictionary]) {
        foreach ($child in $Value.Values) {
            Add-R23D59CasReceipts $child $Receipts
        }
        return
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            Add-R23D59CasReceipts $child $Receipts
        }
    }
}

function Assert-R23D59CasGroup($Group) {
    $first = @($Group.Group)[0]
    $sha = [string]$first.sha256
    $byteLength = [long]$first.byte_length
    Assert-R23D59Closure ($sha -cmatch '^sha256:[0-9a-f]{64}$') (
        "invalid CAS digest: $sha"
    )
    foreach ($receipt in @($Group.Group)) {
        Assert-R23D59Closure (
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
    Assert-R23D59Closure (
        (Test-Path -LiteralPath $payload -PathType Leaf) -and
        (Test-Path -LiteralPath $manifestPath -PathType Leaf) -and
        (Get-Item -LiteralPath $payload).Length -eq $byteLength -and
        (Get-R23D59Sha256 $payload) -ceq $sha
    ) "CAS payload changed: $sha"
    $manifest = Get-Content -Raw -LiteralPath $manifestPath |
        ConvertFrom-Json -Depth 20
    Assert-R23D59Closure (
        [string]$manifest.schema_version -ceq
            "sporespore_content_addressed_artifact_manifest_v1" -and
        [string]$manifest.algorithm -ceq "sha256" -and
        [string]$manifest.sha256 -ceq $sha -and
        [long]$manifest.byte_length -eq $byteLength -and
        [string]$manifest.payload_name -ceq "payload.bin"
    ) "CAS manifest changed: $sha"
}

function Find-R23D59ClosedRecord($Value) {
    if ($null -eq $Value) { return $null }
    if ($Value -is [Collections.IDictionary]) {
        if ($Value.Contains("closed_r23d59_attempt")) {
            return $Value["closed_r23d59_attempt"]
        }
        foreach ($child in $Value.Values) {
            $found = Find-R23D59ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Management.Automation.PSCustomObject]) {
        $property = $Value.PSObject.Properties["closed_r23d59_attempt"]
        if ($null -ne $property) { return $property.Value }
        foreach ($childProperty in $Value.PSObject.Properties) {
            $found = Find-R23D59ClosedRecord $childProperty.Value
            if ($null -ne $found) { return $found }
        }
        return $null
    }
    if ($Value -is [Collections.IEnumerable] -and $Value -isnot [string]) {
        foreach ($child in $Value) {
            $found = Find-R23D59ClosedRecord $child
            if ($null -ne $found) { return $found }
        }
    }
    return $null
}

function Test-R23D59ClaimVector($Value) {
    try {
        return (
            [bool]$Value.r23d59_complete_six_world_attempt_executed -and
            [bool]$Value.r23d59_all_six_cells_execution_valid -and
            [bool]$Value.r23d59_full_precision_traces_retained -and
            [bool]$Value.r23d59_complete_dependency_inventory_proved -and
            [bool]$Value.r23d59_finite_profile_selected -and
            [bool]$Value.r23d59_selected_profile_is_portable_hip_fixture_knee -and
            [bool]$Value.r23d60_preregistration_permitted -and
            -not [bool]$Value.r23d60_campaign_opened -and
            -not [bool]$Value.godot_jolt_turning -and
            -not [bool]$Value.finite_three_engine_turning -and
            -not [bool]$Value.portable_basic_turning -and
            -not [bool]$Value.cross_engine_equivalence -and
            -not [bool]$Value.population_robustness -and
            -not [bool]$Value.arbitrary_quadruped_coverage -and
            -not [bool]$Value.prone_to_standing -and
            -not [bool]$Value.q_sdk_r23_satisfied -and
            -not [bool]$Value.release_authorized -and
            -not [bool]$Value.physical_acceptance_authority
        )
    } catch { return $false }
}

function Test-R23D59ClosureSemanticVector($Value) {
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
            -not [bool]$Value.reserved_r23d60_seed_consumed -and
            -not [bool]$Value.successor_campaign_opened -and
            [bool]$Value.physical_series_paused_before_successor -and
            [bool]$Value.preflight_history.initial_incomplete_local_inventory_observed -and
            [int]$Value.preflight_history.initial_incomplete_local_inventory_path_count -eq 126 -and
            [int]$Value.preflight_history.initial_incomplete_local_inventory_edge_count -eq 145 -and
            -not [bool]$Value.preflight_history.initial_incomplete_receipt_reuse_authorized -and
            [int]$Value.preflight_history.corrected_transitive_path_count -eq 128 -and
            [int]$Value.preflight_history.corrected_transitive_edge_count -eq 146 -and
            [bool]$Value.preflight_history.corrected_complete_zero_world_gate_passed -and
            [bool]$Value.preflight_history.corrected_clean_pushed_same_source_replay_passed -and
            [int]$Value.preflight_history.corrected_zero_world_model_construction_count -eq 0 -and
            [int]$Value.preflight_history.corrected_zero_world_world_attempt_count -eq 0 -and
            [int]$Value.preflight_history.corrected_zero_world_world_build_count -eq 0 -and
            -not [bool]$Value.preflight_history.physics_controller_threshold_selector_evaluator_or_observed_result_changed -and
            [int]$Value.physical_evidence.retained_file_count -eq 49 -and
            [long]$Value.physical_evidence.retained_byte_count -eq 413913213 -and
            [int]$Value.physical_evidence.content_addressed_receipt_reference_count -eq 376 -and
            [int]$Value.physical_evidence.content_addressed_unique_object_count -eq 209 -and
            [int]$Value.physical_evidence.invalid_content_addressed_reference_count -eq 0 -and
            [int]$Value.physical_evidence.physical_freeze_source_binding_count -eq 128 -and
            [int]$Value.physical_evidence.physical_freeze_transitive_edge_count -eq 146 -and
            [bool]$Value.physical_evidence.complete_dependency_inventory_proved -and
            [string]$Value.official_result.classification -ceq $classification -and
            [int]$Value.official_result.observed_world_attempt_count -eq 6 -and
            [int]$Value.official_result.observed_world_build_count -eq 6 -and
            [int]$Value.official_result.execution_valid_cell_count -eq 6 -and
            [int]$Value.official_result.common_physical_gate_pass_cell_count -eq 3 -and
            [int]$Value.official_result.common_physical_gate_fail_cell_count -eq 3 -and
            [int]$Value.official_result.retained_trace_row_count -eq 17952 -and
            [int]$Value.official_result.retained_actuator_application_count -eq 143616 -and
            [bool]$Value.official_result.matrix_execution_valid -and
            -not [bool]$Value.official_result.portable_hip_portable_knee_profile_adequate -and
            [bool]$Value.official_result.portable_hip_fixture_knee_profile_adequate -and
            [string]$Value.official_result.selected_profile_id -ceq
                "portable_hip__fixture_knee" -and
            [bool]$Value.official_result.strict_finite_conjunction_used -and
            -not [bool]$Value.official_result.turning_gate_invoked -and
            -not [bool]$Value.official_result.superiority_test_invoked -and
            -not [bool]$Value.official_result.equivalence_or_non_inferiority_test_invoked -and
            -not [bool]$Value.official_result.population_inference_attempted -and
            -not [bool]$Value.official_result.posthoc_threshold_or_selector_change_performed -and
            [bool]$Value.bounded_interpretation.fixture_knee_profile_passed_all_frozen_common_gates_in_all_three_declared_worlds -and
            [bool]$Value.bounded_interpretation.portable_knee_profile_failed_only_r23d34_contact_cycles_in_all_three_declared_worlds -and
            [int]$Value.bounded_interpretation.portable_knee_common_gate_rear_contact_cycle_total -eq 0 -and
            [int]$Value.bounded_interpretation.fixture_knee_common_gate_rear_contact_cycle_total -eq 36 -and
            [bool]$Value.bounded_interpretation.selected_profile_binding_for_r23d60_preregistration_authorized -and
            -not [bool]$Value.bounded_interpretation.r23d59_cells_may_count_as_r23d60_held_out_worlds -and
            -not [bool]$Value.bounded_interpretation.fixture_knee_selection_establishes_population_repeatability -and
            -not [bool]$Value.bounded_interpretation.fixture_knee_selection_establishes_godot_turning -and
            -not [bool]$Value.bounded_interpretation.fixture_knee_selection_establishes_three_engine_turning -and
            [bool]$Value.successor_requirements.distinct_r23d60_campaign_identity_required -and
            [bool]$Value.successor_requirements.r23d59_rerun_forbidden -and
            [bool]$Value.successor_requirements.r23d60_may_be_preregistered_from_this_finite_decision -and
            [bool]$Value.successor_requirements.r23d60_selected_profile_must_be_portable_hip_fixture_knee -and
            [int]$Value.successor_requirements.r23d60_reserved_seed -eq 21516 -and
            -not [bool]$Value.successor_requirements.r23d60_seed_threshold_schedule_or_arm_set_may_change_from_r23d59_result -and
            [bool]$Value.successor_requirements.r23d60_separate_complete_zero_world_gate_required -and
            [bool]$Value.successor_requirements.r23d60_separate_clean_pushed_qualification_and_adoption_required -and
            -not [bool]$Value.successor_requirements.r23d60_physical_world_opened_by_this_closure -and
            -not [bool]$Value.successor_requirements.physical_successor_authorized_by_this_closure -and
            (Test-R23D59ClaimVector $Value.claims)
        )
    } catch { return $false }
}

function Assert-R23D59Close([double]$Actual, [double]$Expected, [string]$Name) {
    Assert-R23D59Closure ([Math]::Abs($Actual - $Expected) -le 1e-12) (
        "$Name changed: expected $Expected, observed $Actual"
    )
}

Assert-R23D59Closure ($repoRoot -ceq $expectedRoot) "repository root changed"
$observedTop = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
$observedRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-R23D59Closure (
    $LASTEXITCODE -eq 0 -and
    [IO.Path]::GetFullPath($observedTop) -ceq $expectedRoot -and
    $observedRemote -ceq $expectedRemote
) "repository identity changed"

Assert-R23D59Closure (Test-Path -LiteralPath $closurePath -PathType Leaf) (
    "closure is missing: $closurePath"
)
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -Depth 100
Assert-R23D59Closure (
    [string]$closure.schema_version -ceq
        "sporespore_qsdk_r23d59_godot_knee_source_finite_decision_closure_v1" -and
    [string]$closure.campaign_id -ceq $campaignId -and
    [string]$closure.gate_id -ceq "QSDK-R23D59" -and
    [string]$closure.release_gate_id -ceq "QSDK-R23" -and
    [string]$closure.question_class -ceq "finite_decision" -and
    @($closure.ordered_cells).Count -eq 6 -and
    (Test-R23D59ClosureSemanticVector $closure)
) "closure identity or semantic vector changed"

$observedTree = (& git -C $repoRoot rev-parse "$sourceCommit`^{tree}").Trim()
Assert-R23D59Closure ($LASTEXITCODE -eq 0 -and $observedTree -ceq $sourceTree) (
    "physical source tree changed or is unavailable"
)

$attestationSpec = $closure.qualification_history.accepted_scoped_attestation
$adoptionSpec = $closure.qualification_history.adoption
foreach ($spec in @($attestationSpec, $adoptionSpec)) {
    $path = [IO.Path]::GetFullPath([string]$spec.path)
    Assert-R23D59Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$spec.byte_length -and
        (Get-R23D59Sha256 $path) -ceq [string]$spec.raw_sha256
    ) "qualification artifact changed: $path"
}
$attestation = Get-Content -Raw -LiteralPath ([string]$attestationSpec.path) |
    ConvertFrom-Json -Depth 100
$adoption = Get-Content -Raw -LiteralPath ([string]$adoptionSpec.path) |
    ConvertFrom-Json -Depth 100
Assert-R23D59Closure (
    [string]$attestation.status -ceq
        "campaign_local_godot_including_qualification_passed" -and
    [string]$attestation.source.commit -ceq $sourceCommit -and
    [string]$attestation.source.tree_git_oid -ceq $sourceTree -and
    [bool]$attestation.source.worktree_clean -and
    [bool]$attestation.source.clean_pushed_live -and
    [int]$attestation.executed_gate_count -eq 22 -and
    [int]$attestation.declared_physical_world_count -eq 6 -and
    @($attestation.gate_receipts).Count -eq 22 -and
    (@($attestation.gate_receipts | Where-Object { -not [bool]$_.passed }).Count -eq 0) -and
    (@($attestation.gate_receipts | Measure-Object physical_world_count -Sum).Sum -eq 0) -and
    -not [bool]$attestation.claims.physical_campaign_executed -and
    -not [bool]$attestation.claims.physical_acceptance_authority -and
    [string]$adoption.status -ceq
        "commissioned_campaign_local_qualification_adopted_for_physical_launch" -and
    [string]$adoption.source_commit -ceq $sourceCommit -and
    [string]$adoption.source_tree_git_oid -ceq $sourceTree -and
    [string]$adoption.scoped_attestation_raw_sha256 -ceq
        [string]$attestationSpec.raw_sha256 -and
    [int]$adoption.declared_physical_world_count -eq 6 -and
    [int]$adoption.executed_gate_count -eq 22 -and
    [int]$adoption.gate_cas_object_count -eq 66 -and
    [bool]$adoption.physical_launch_prerequisite_satisfied -and
    [bool]$adoption.all_gate_cas_objects_verified -and
    [bool]$adoption.scoped_attestation_cas_verified -and
    [bool]$adoption.clean_pushed_live_source_verified -and
    -not [bool]$adoption.physical_acceptance_authority -and
    -not [bool]$adoption.release_authority
) "qualification or adoption authority changed"

$inventory = @($closure.physical_evidence.file_inventory)
$actualFiles = @(Get-ChildItem -LiteralPath $attemptRoot -Recurse -File)
Assert-R23D59Closure (
    $inventory.Count -eq 49 -and
    $actualFiles.Count -eq 49 -and
    [long]($actualFiles | Measure-Object Length -Sum).Sum -eq 413913213
) "retained evidence inventory cardinality changed"
$inventoryPaths = @($inventory | ForEach-Object { [string]$_.path } | Sort-Object)
$actualPaths = @($actualFiles | ForEach-Object {
    $_.FullName.Substring($attemptRoot.Length + 1).Replace('\', '/')
} | Sort-Object)
Assert-R23D59Closure (
    ($inventoryPaths -join "`n") -ceq ($actualPaths -join "`n")
) "retained evidence file set changed"
foreach ($entry in $inventory) {
    $path = Join-Path $attemptRoot ([string]$entry.path).Replace('/', '\')
    Assert-R23D59Closure (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-Item -LiteralPath $path).Length -eq [long]$entry.byte_length -and
        (Get-R23D59Sha256 $path) -ceq [string]$entry.raw_sha256
    ) "retained evidence bytes changed: $($entry.path)"
}

$metadataFiles = @($inventory | Where-Object {
    [string]$_.path -like "*.json" -and
    [string]$_.path -notlike "pending-traces/*"
} | ForEach-Object {
    Join-Path $attemptRoot ([string]$_.path).Replace('/', '\')
}) + @([string]$attestationSpec.path, [string]$adoptionSpec.path)
Assert-R23D59Closure ($metadataFiles.Count -eq 15) (
    "CAS-bearing metadata file count changed"
)
$receipts = [Collections.Generic.List[object]]::new()
foreach ($metadataPath in $metadataFiles) {
    Add-R23D59CasReceipts (
        Get-Content -Raw -LiteralPath $metadataPath | ConvertFrom-Json -Depth 100
    ) $receipts
}
$receiptGroups = @($receipts | Group-Object { [string]$_.sha256 })
Assert-R23D59Closure (
    $receipts.Count -eq 376 -and
    $receiptGroups.Count -eq 209
) "CAS receipt counts changed"
foreach ($group in $receiptGroups) { Assert-R23D59CasGroup $group }

$freeze = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "physical-freeze.json") |
    ConvertFrom-Json -Depth 100
$authorization = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "attempt-authorization.json"
) | ConvertFrom-Json -Depth 100
$authorizationPreflight = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "authorization-preflight.json"
) | ConvertFrom-Json -Depth 100
$terminalManifest = @(Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "terminal-paths.json"
) | ConvertFrom-Json -Depth 20)
$evaluation = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "complete-evaluation.json"
) | ConvertFrom-Json -Depth 100
$report = Get-Content -Raw -LiteralPath (Join-Path $attemptRoot "report.json") |
    ConvertFrom-Json -Depth 100
$completion = Get-Content -Raw -LiteralPath (
    Join-Path $attemptRoot "completion.json"
) | ConvertFrom-Json -Depth 100

Assert-R23D59Closure (
    [string]$freeze.schema_version -ceq
        "sporespore_qsdk_r23d59_physical_freeze_v1" -and
    [string]$freeze.status -ceq "frozen_supervisor_only_physical_authorized" -and
    [string]$freeze.source_commit -ceq $sourceCommit -and
    [string]$freeze.source_tree_git_oid -ceq $sourceTree -and
    [string]$freeze.origin_main_commit -ceq $sourceCommit -and
    [string]$freeze.live_github_main_commit -ceq $sourceCommit -and
    [bool]$freeze.dependency_inventory_complete -and
    [int]$freeze.dependency_inventory.transitive_path_count -eq 128 -and
    [int]$freeze.dependency_inventory.edge_count -eq 146 -and
    [string]$freeze.dependency_inventory.inventory_projection_sha256 -ceq
        "sha256:ab425e8a909a5d577a4a9c6bb061c778f9547ed86ab86fe8cadab31465ee3720" -and
    [bool]$freeze.dependency_inventory.expected_transitive_path_set_exact -and
    [bool]$freeze.dependency_inventory.checkout_bytes_equal_git_blobs -and
    [bool]$freeze.dependency_inventory.all_paths_tracked_with_exact_case -and
    [bool]$freeze.dependency_inventory.recursive_local_python_import_inventory_complete -and
    [bool]$freeze.dependency_inventory.recursive_gdscript_preload_and_load_inventory_complete -and
    [bool]$freeze.dependency_inventory.powershell_static_dot_source_and_subprocess_path_inventory_complete -and
    [bool]$freeze.dependency_inventory.declaration_bound_source_inventory_complete -and
    [int]$freeze.dependency_inventory.model_construction_count -eq 0 -and
    [int]$freeze.dependency_inventory.world_attempt_count -eq 0 -and
    [int]$freeze.dependency_inventory.world_build_count -eq 0 -and
    @($freeze.source_bindings).Count -eq 128 -and
    @($freeze.runtime_artifacts).Count -eq 1 -and
    @($freeze.external_runtime_bindings).Count -eq 3 -and
    [int]$freeze.declared_world_count -eq 6 -and
    (@($freeze.ordered_matrix_cell_ids) -join "`n") -ceq
        ($expectedCellIds -join "`n") -and
    [bool]$freeze.serial_execution_required -and
    [bool]$freeze.all_cells_run_regardless_of_intermediate_outcome -and
    [bool]$freeze.complete_zero_world_gate_passed -and
    [bool]$freeze.source_checkout_bytes_equal_git_blobs -and
    [bool]$freeze.reproducible_runtime_materialization_passed -and
    [bool]$freeze.physical_execution_authorized -and
    -not [bool]$freeze.terminal_restoration_or_taper_invoked -and
    -not [bool]$freeze.physical_acceptance_authority
) "physical freeze changed"

$sourceBindings = @($freeze.source_bindings)
Assert-R23D59Closure (
    @($sourceBindings.path | Sort-Object -Unique).Count -eq 128 -and
    @($sourceBindings.git_blob_oid | Sort-Object -Unique).Count -eq 128
) "source binding cardinality or uniqueness changed"
$sourceBytes = [Collections.Generic.Dictionary[string, byte[]]]::new(
    [StringComparer]::Ordinal
)
foreach ($binding in $sourceBindings) {
    $relative = [string]$binding.path
    $bytes = Get-R23D59GitBlobBytes $sourceCommit $relative
    $oid = (& git -C $repoRoot rev-parse "$sourceCommit`:$relative").Trim()
    Assert-R23D59Closure (
        $LASTEXITCODE -eq 0 -and
        $oid -ceq [string]$binding.git_blob_oid -and
        (Get-R23D59BytesSha256 $bytes) -ceq [string]$binding.raw_sha256 -and
        [bool]$binding.raw_checkout_equals_git_blob
    ) "historical source binding changed: $relative"
    $sourceBytes[$relative] = $bytes
}

Assert-R23D59Closure (
    [string]$authorization.schema_version -ceq
        "sporespore_qsdk_r23d59_attempt_v1" -and
    [string]$authorization.source_commit -ceq $sourceCommit -and
    [string]$authorization.attempt_id -ceq $attemptId -and
    [bool]$authorization.physical_execution_authorized -and
    [bool]$authorization.single_use_supervisor_authorization -and
    [bool]$authorization.matrix_authorization_immutable_before_first_world -and
    [bool]$authorization.source_worktree_clean -and
    [bool]$authorization.source_matches_live_github_main -and
    [bool]$authorization.operation_lock_held -and
    [bool]$authorization.campaign_attestation_adoption_valid -and
    [bool]$authorization.content_addressed_inputs_retained -and
    [bool]$authorization.one_shot_attempt_unconsumed -and
    -not [bool]$authorization.physical_acceptance_authority
) "attempt authorization changed"
Assert-R23D59Closure (
    [string]$authorizationPreflight.schema_version -ceq
        "sporespore_qsdk_r23d59_authorization_preflight_matrix_v1" -and
    [string]$authorizationPreflight.source_commit -ceq $sourceCommit -and
    [int]$authorizationPreflight.receipt_count -eq 6 -and
    [int]$authorizationPreflight.model_construction_count -eq 0 -and
    [int]$authorizationPreflight.world_attempt_count -eq 0 -and
    [int]$authorizationPreflight.world_build_count -eq 0 -and
    -not [bool]$authorizationPreflight.physical_acceptance_authority
) "authorization preflight summary changed"
$preflightIds = @($authorizationPreflight.ordered_receipts | ForEach-Object {
    [string]$_.cell_id
})
Assert-R23D59Closure (($preflightIds -join "`n") -ceq ($expectedCellIds -join "`n")) (
    "authorization preflight order changed"
)
foreach ($entry in @($authorizationPreflight.ordered_receipts)) {
    Assert-R23D59Closure (
        [bool]$entry.worker_receipt.authorization_passed -and
        [bool]$entry.worker_receipt.returned_before_model -and
        [int]$entry.worker_receipt.model_construction_count -eq 0 -and
        [int]$entry.worker_receipt.world_attempt_count -eq 0 -and
        [int]$entry.worker_receipt.world_build_count -eq 0 -and
        [int]$entry.process.exit_code -eq 0 -and
        -not [bool]$entry.process.timed_out -and
        [bool]$entry.process.supervisor_terminated -and
        [bool]$entry.process.termination_protocol_valid -and
        -not [bool]$entry.physical_acceptance_authority
    ) "authorization preflight receipt changed: $($entry.cell_id)"
}

Assert-R23D59Closure ($terminalManifest.Count -eq 6) "terminal manifest changed"
$terminals = @($terminalManifest | ForEach-Object {
    $path = [IO.Path]::GetFullPath([string]$_)
    Assert-R23D59Closure (
        $path.StartsWith(
            [IO.Path]::GetFullPath($artifactRoot) + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        (Test-Path -LiteralPath $path -PathType Leaf)
    ) "terminal manifest escaped or is missing: $path"
    Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -Depth 100
})
$terminalIds = @($terminals | ForEach-Object { [string]$_.cell_id })
Assert-R23D59Closure (($terminalIds -join "`n") -ceq ($expectedCellIds -join "`n")) (
    "terminal order changed"
)

Assert-R23D59Closure (
    [string]$evaluation.schema_version -ceq
        "sporespore_qsdk_r23d59_complete_finite_decision_evaluation_v1" -and
    [string]$evaluation.classification -ceq $classification -and
    [string]$evaluation.source_commit -ceq $sourceCommit -and
    [int]$evaluation.cell_count -eq 6 -and
    [bool]$evaluation.all_declared_cells_executed_or_retained_as_failures -and
    [bool]$evaluation.all_cells_run_regardless_of_intermediate_outcome -and
    [int]$evaluation.fresh_decision_seed_count -eq 3 -and
    [int]$evaluation.matched_profile_count_per_seed -eq 2 -and
    [bool]$evaluation.finite_decision.matrix_execution_valid -and
    -not [bool]$evaluation.finite_decision.profile_adequacy.portable_hip__portable_knee -and
    [bool]$evaluation.finite_decision.profile_adequacy.portable_hip__fixture_knee -and
    [string]$evaluation.finite_decision.selected_profile_id -ceq
        "portable_hip__fixture_knee" -and
    [string]$evaluation.finite_decision.decision_id -ceq
        "fixture_knee_selected_only_fixture_knee_finite_adequate" -and
    [bool]$evaluation.finite_decision.strict_finite_conjunction_used -and
    [bool]$evaluation.finite_decision.r23d60_may_be_preregistered_from_this_result -and
    -not [bool]$evaluation.reserved_r23d60_seed_consumed -and
    -not [bool]$evaluation.turning_gate_invoked -and
    -not [bool]$evaluation.posthoc_threshold_or_selector_change_performed -and
    -not [bool]$evaluation.cross_engine_equivalence_test_invoked -and
    -not [bool]$evaluation.population_inference_attempted -and
    [bool]$evaluation.claims.r23d59_finite_profile_selected -and
    -not [bool]$evaluation.claims.r23d60_campaign_opened -and
    -not [bool]$evaluation.claims.godot_jolt_turning -and
    -not [bool]$evaluation.claims.finite_three_engine_turning -and
    -not [bool]$evaluation.claims.prone_to_standing -and
    -not [bool]$evaluation.claims.release_authority -and
    -not [bool]$evaluation.physical_acceptance_authority
) "complete evaluator result changed"

$evaluationByCell = @{}
foreach ($entry in @($evaluation.cell_evaluations)) {
    $evaluationByCell[[string]$entry.cell_id] = $entry
}
$terminalByCell = @{}
foreach ($entry in $terminals) { $terminalByCell[[string]$entry.cell_id] = $entry }
foreach ($expected in @($closure.ordered_cells)) {
    $cellId = [string]$expected.cell_id
    $terminal = $terminalByCell[$cellId]
    $cellEvaluation = $evaluationByCell[$cellId]
    Assert-R23D59Closure ($null -ne $terminal -and $null -ne $cellEvaluation) (
        "cell is missing: $cellId"
    )
    $terminalLocal = Join-Path $attemptRoot (
        "cells\$cellId\terminal.json"
    )
    Assert-R23D59Closure (
        [string]$terminal.schema_version -ceq
            "sporespore_qsdk_r23d59_engine_cell_report_v1" -and
        [string]$terminal.campaign_id -ceq $campaignId -and
        [string]$terminal.source_commit -ceq $sourceCommit -and
        [string]$terminal.profile_id -ceq [string]$expected.profile_id -and
        [int]$terminal.campaign_seed -eq [int]$expected.campaign_seed -and
        [bool]$terminal.execution.integrity_passed -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        [int]$terminal.execution.controller_semantic_step_count -eq 2992 -and
        [int]$terminal.execution.validated_portable_command_count -eq 23936 -and
        [int]$terminal.execution.native_actuation_application_count -eq 23936 -and
        [int]$terminal.execution.portable_impulse_violation_count -eq 0 -and
        [bool]$terminal.execution.trace_retained_before_terminal_entry -and
        [bool]$terminal.godot_execution_predicates.ok -and
        @($terminal.godot_execution_predicates.failed_predicate_ids).Count -eq 0 -and
        [string]$terminal.trace_artifact.sha256 -ceq [string]$expected.trace_raw_sha256 -and
        [long]$terminal.trace_artifact.byte_length -eq [long]$expected.trace_byte_length -and
        [bool]$terminal.trace_artifact.godot_json_full_precision -and
        [bool]$terminal.trace_artifact.godot_json_sorted_keys -and
        [int]$terminal.trace_summary.row_count -eq 2992 -and
        [int]$terminal.trace_summary.observation_application_count -eq 23936 -and
        [bool]$cellEvaluation.execution_valid -eq [bool]$expected.execution_valid -and
        [bool]$cellEvaluation.common_physical_gate_passed -eq
            [bool]$expected.common_physical_gate_passed -and
        (@($cellEvaluation.failed_gate_ids) -join "`n") -ceq
            (@($expected.failed_gate_ids) -join "`n") -and
        (Get-R23D59Sha256 $terminalLocal) -ceq
            [string]$expected.terminal_raw_sha256 -and
        -not [bool]$terminal.claims.godot_jolt_turning -and
        -not [bool]$terminal.claims.finite_three_engine_turning -and
        -not [bool]$terminal.claims.r23d59_finite_profile_selected -and
        -not [bool]$terminal.claims.r23d60_campaign_opened -and
        -not [bool]$terminal.claims.physical_acceptance_authority
    ) "terminal or evaluation cell changed: $cellId"
    foreach ($limb in @("front_left", "front_right", "rear_left", "rear_right")) {
        Assert-R23D59Closure (
            [int]$terminal.measurements.contact_cycle_count_by_limb.$limb -eq
                [int]$expected.common_gate_contact_cycle_count_by_limb.$limb
        ) "contact-cycle value changed: $cellId/$limb"
    }
    Assert-R23D59Close ([double]$terminal.measurements.final_forward_displacement_m) `
        ([double]$expected.final_forward_displacement_m) "$cellId forward displacement"
    Assert-R23D59Close ([double]$terminal.measurements.turn_phase_yaw_delta_rad) `
        ([double]$expected.turn_phase_yaw_delta_rad_descriptive_only) "$cellId yaw context"
    Assert-R23D59Close ([double]$terminal.measurements.minimum_torso_height_m) `
        ([double]$expected.minimum_torso_height_m) "$cellId torso height"
    Assert-R23D59Close ([double]$terminal.measurements.maximum_tilt_rad) `
        ([double]$expected.maximum_tilt_rad) "$cellId maximum tilt"
    Assert-R23D59Closure (
        [int]$terminal.measurements.torso_ground_contact_step_count -eq 0
    ) "torso-ground contact changed: $cellId"
}

$portableEvaluations = @($evaluation.cell_evaluations | Where-Object {
    [string]$_.profile_id -ceq "portable_hip__portable_knee"
})
$fixtureEvaluations = @($evaluation.cell_evaluations | Where-Object {
    [string]$_.profile_id -ceq "portable_hip__fixture_knee"
})
Assert-R23D59Closure (
    $portableEvaluations.Count -eq 3 -and
    @($portableEvaluations | Where-Object { [bool]$_.common_physical_gate_passed }).Count -eq 0 -and
    @($portableEvaluations | Where-Object {
        (@($_.failed_gate_ids) -join "`n") -ceq "R23D34_CONTACT_CYCLES"
    }).Count -eq 3 -and
    $fixtureEvaluations.Count -eq 3 -and
    @($fixtureEvaluations | Where-Object { [bool]$_.common_physical_gate_passed }).Count -eq 3 -and
    @($fixtureEvaluations | Where-Object { @($_.failed_gate_ids).Count -ne 0 }).Count -eq 0
) "finite profile conjunction changed"

Assert-R23D59Closure (
    [string]$report.schema_version -ceq
        "sporespore_qsdk_r23d59_campaign_report_v1" -and
    [string]$report.source.commit -ceq $sourceCommit -and
    [string]$report.attempt_id -ceq $attemptId -and
    [string]$report.result_classification -ceq $classification -and
    [int]$report.authorization_preflight_count -eq 6 -and
    @($report.ordered_cells).Count -eq 6 -and
    [bool]$report.all_six_cells_executed_or_retained_as_failures -and
    [bool]$report.world_build_count_exact -and
    [int]$report.world_build_count_lower_bound -eq 6 -and
    [int]$report.world_build_count_upper_bound -eq 6 -and
    -not [bool]$report.terminal_restoration_or_taper_invoked -and
    [string]$report.complete_evaluation_cas.sha256 -ceq
        "sha256:18a7d84cf63cacdd9d06d1968fe642389871093e0dff049be4d5a0f7015b6729" -and
    -not [bool]$report.claims.godot_jolt_turning -and
    -not [bool]$report.claims.finite_three_engine_turning -and
    -not [bool]$report.claims.r23d60_campaign_opened -and
    -not [bool]$report.claims.release_authority -and
    [string]$completion.schema_version -ceq
        "sporespore_qsdk_r23d59_completion_v1" -and
    [string]$completion.status -ceq $classification -and
    [string]$completion.source_commit -ceq $sourceCommit -and
    [string]$completion.attempt_id -ceq $attemptId -and
    [int]$completion.cell_count -eq 6 -and
    [int]$completion.world_count -eq 6 -and
    [bool]$completion.world_count_exact -and
    [string]$completion.selected_profile_id -ceq "portable_hip__fixture_knee" -and
    [bool]$completion.one_shot_attempt_consumed -and
    -not [bool]$completion.replacement_or_selective_rerun_permitted -and
    -not [bool]$completion.physical_acceptance_authority -and
    [string]$completion.report_cas.sha256 -ceq
        "sha256:618cc95a43e40035172a0c781703538d8b3359790e871ff89c23a8617e2c6ef6"
) "report or completion changed"

$tempBase = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
$tempRoot = Join-Path $tempBase (
    "sporespore-r23d59-closure-" + [Guid]::NewGuid().ToString("N")
)
Assert-R23D59Closure (
    $tempRoot.StartsWith(
        $tempBase + [IO.Path]::DirectorySeparatorChar,
        [StringComparison]::OrdinalIgnoreCase
    )
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
        "sdk\turning\r23d59_godot_knee_source_finite_decision_evaluator.py"
    )
    $evaluatorOutput = @(& $Python $evaluatorPath evaluate-complete `
        --manifest (Join-Path $attemptRoot "terminal-paths.json") `
        --expected-source-commit $sourceCommit --repo-root $repoRoot 2>&1)
    Assert-R23D59Closure ($LASTEXITCODE -eq 0) ($evaluatorOutput -join "`n")
    $marker = "QSDK_R23D59_COMPLETE_EVALUATION "
    $lines = @($evaluatorOutput | Where-Object {
        [string]$_ -and ([string]$_).StartsWith($marker, [StringComparison]::Ordinal)
    })
    Assert-R23D59Closure ($lines.Count -eq 1) "pinned evaluator marker changed"
    $replayed = ([string]$lines[0]).Substring($marker.Length) |
        ConvertFrom-Json -Depth 100
    Assert-R23D59Closure (
        [string]$replayed.classification -ceq $classification -and
        [string]$replayed.source_commit -ceq $sourceCommit -and
        [int]$replayed.cell_count -eq 6 -and
        [bool]$replayed.finite_decision.matrix_execution_valid -and
        -not [bool]$replayed.finite_decision.profile_adequacy.portable_hip__portable_knee -and
        [bool]$replayed.finite_decision.profile_adequacy.portable_hip__fixture_knee -and
        [string]$replayed.finite_decision.selected_profile_id -ceq
            "portable_hip__fixture_knee" -and
        -not [bool]$replayed.turning_gate_invoked -and
        -not [bool]$replayed.posthoc_threshold_or_selector_change_performed -and
        -not [bool]$replayed.claims.godot_jolt_turning -and
        -not [bool]$replayed.claims.physical_acceptance_authority
    ) "pinned evaluator no longer reproduces the complete result"
} finally {
    if (
        (Test-Path -LiteralPath $tempRoot -PathType Container) -and
        $tempRoot.StartsWith(
            $tempBase + [IO.Path]::DirectorySeparatorChar,
            [StringComparison]::OrdinalIgnoreCase
        )
    ) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}

$mutations = @(
    { param($v) $v.status = "closed_positive" },
    { param($v) $v.source_commit = "0" * 40 },
    { param($v) $v.attempt_id = "wrong" },
    { param($v) $v.identity_consumed = $false },
    { param($v) $v.same_identity_rerun_allowed = $true },
    { param($v) $v.selective_rerun_allowed = $true },
    { param($v) $v.successor_campaign_opened = $true },
    { param($v) $v.reserved_r23d60_seed_consumed = $true },
    { param($v) $v.preflight_history.initial_incomplete_receipt_reuse_authorized = $true },
    { param($v) $v.preflight_history.corrected_transitive_path_count = 126 },
    { param($v) $v.physical_evidence.complete_dependency_inventory_proved = $false },
    { param($v) $v.official_result.observed_world_build_count = 5 },
    { param($v) $v.official_result.execution_valid_cell_count = 5 },
    { param($v) $v.official_result.common_physical_gate_pass_cell_count = 6 },
    { param($v) $v.official_result.portable_hip_portable_knee_profile_adequate = $true },
    { param($v) $v.official_result.portable_hip_fixture_knee_profile_adequate = $false },
    { param($v) $v.official_result.selected_profile_id = "portable_hip__portable_knee" },
    { param($v) $v.official_result.turning_gate_invoked = $true },
    { param($v) $v.official_result.superiority_test_invoked = $true },
    { param($v) $v.official_result.equivalence_or_non_inferiority_test_invoked = $true },
    { param($v) $v.official_result.population_inference_attempted = $true },
    { param($v) $v.official_result.posthoc_threshold_or_selector_change_performed = $true },
    { param($v) $v.bounded_interpretation.r23d59_cells_may_count_as_r23d60_held_out_worlds = $true },
    { param($v) $v.bounded_interpretation.fixture_knee_selection_establishes_population_repeatability = $true },
    { param($v) $v.bounded_interpretation.fixture_knee_selection_establishes_godot_turning = $true },
    { param($v) $v.successor_requirements.r23d60_reserved_seed = 21515 },
    { param($v) $v.successor_requirements.r23d60_seed_threshold_schedule_or_arm_set_may_change_from_r23d59_result = $true },
    { param($v) $v.successor_requirements.physical_successor_authorized_by_this_closure = $true },
    { param($v) $v.claims.r23d60_campaign_opened = $true },
    { param($v) $v.claims.godot_jolt_turning = $true },
    { param($v) $v.claims.finite_three_engine_turning = $true },
    { param($v) $v.claims.prone_to_standing = $true },
    { param($v) $v.claims.release_authorized = $true }
)
$mutationRejectionCount = 0
foreach ($mutation in $mutations) {
    $candidate = $closure | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
    & $mutation $candidate
    if (-not (Test-R23D59ClosureSemanticVector $candidate)) {
        $mutationRejectionCount++
    }
}
Assert-R23D59Closure ($mutationRejectionCount -eq $mutations.Count) (
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
    $turningGates[0].proof.closed_r23d59_attempt
} else { $null }
$matrixRecord = Find-R23D59ClosedRecord $supportMatrix
$closureHash = Get-R23D59Sha256 $closurePath
$auditHash = Get-R23D59Sha256 $auditPath
Assert-R23D59Closure (
    $turningGates.Count -eq 1 -and
    $null -ne $contractRecord -and
    $null -ne $matrixRecord -and
    [string]$contractRecord.status -ceq $closedStatus -and
    [string]$matrixRecord.status -ceq $closedStatus -and
    [string]$contractRecord.closure_path -ceq
        "sdk/turning/r23d59_godot_knee_source_finite_decision_closure_v1.json" -and
    [string]$matrixRecord.closure_path -ceq [string]$contractRecord.closure_path -and
    [string]$contractRecord.closure_raw_sha256 -ceq $closureHash -and
    [string]$matrixRecord.closure_sha256 -ceq $closureHash -and
    [string]$contractRecord.closure_audit_path -ceq
        "tests/test_qsdk_r23d59_physical_closure.ps1" -and
    [string]$matrixRecord.closure_audit_path -ceq
        [string]$contractRecord.closure_audit_path -and
    [string]$contractRecord.closure_audit_raw_sha256 -ceq $auditHash -and
    [string]$matrixRecord.closure_audit_sha256 -ceq $auditHash -and
    [string]$contractRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$matrixRecord.physical_source_commit -ceq $sourceCommit -and
    [string]$contractRecord.attempt_id -ceq $attemptId -and
    [string]$matrixRecord.attempt_id -ceq $attemptId -and
    [int]$contractRecord.world_count -eq 6 -and
    [int]$matrixRecord.world_count -eq 6 -and
    [int]$contractRecord.execution_valid_cell_count -eq 6 -and
    [int]$matrixRecord.execution_valid_cell_count -eq 6 -and
    [int]$contractRecord.common_gate_pass_cell_count -eq 3 -and
    [int]$matrixRecord.common_gate_pass_cell_count -eq 3 -and
    [bool]$contractRecord.complete_dependency_inventory_proved -and
    [bool]$matrixRecord.complete_dependency_inventory_proved -and
    [string]$contractRecord.selected_profile_id -ceq "portable_hip__fixture_knee" -and
    [string]$matrixRecord.selected_profile_id -ceq "portable_hip__fixture_knee" -and
    -not [bool]$contractRecord.portable_profile_adequate -and
    -not [bool]$matrixRecord.portable_profile_adequate -and
    [bool]$contractRecord.fixture_knee_profile_adequate -and
    [bool]$matrixRecord.fixture_knee_profile_adequate -and
    [bool]$contractRecord.r23d60_preregistration_permitted -and
    [bool]$matrixRecord.r23d60_preregistration_permitted -and
    [int]$contractRecord.r23d60_reserved_seed -eq 21516 -and
    [int]$matrixRecord.r23d60_reserved_seed -eq 21516 -and
    -not [bool]$contractRecord.r23d60_campaign_opened -and
    -not [bool]$matrixRecord.r23d60_campaign_opened -and
    -not [bool]$contractRecord.godot_jolt_turning -and
    -not [bool]$matrixRecord.godot_jolt_turning -and
    -not [bool]$contractRecord.finite_three_engine_turning -and
    -not [bool]$matrixRecord.finite_three_engine_turning -and
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
    [string]$_.id -ceq "qsdk_r23d59_physical_closure"
})
Assert-R23D59Closure (
    $workbenchRuns.Count -eq 1 -and
    [string]$workbenchRuns[0].kind -ceq "closure_audit" -and
    [string]$workbenchRuns[0].world_policy -ceq "retained_evidence_only" -and
    [string]$workbenchRuns[0].risk -ceq "safe" -and
    [string]$workbenchRuns[0].runner_path -ceq
        "tests/test_qsdk_r23d59_physical_closure.ps1" -and
    @($workbenchRuns[0].arguments).Count -eq 0 -and
    @($workbenchRuns[0].proofs).Count -eq 2 -and
    [string]$workbenchRuns[0].proofs[0].expected_sha256 -ceq
        $closureHash.Substring(7) -and
    [string]$workbenchRuns[0].proofs[1].expected_sha256 -ceq
        $auditHash.Substring(7)
) "workbench closure exposure changed"

$attempts = @(Get-ChildItem -LiteralPath $evidenceRoot -Directory | Where-Object {
    $_.Name -like "qsdk-r23d59-*" -and
    (Test-Path -LiteralPath (Join-Path $_.FullName "attempt-authorization.json") -PathType Leaf)
})
Assert-R23D59Closure (
    $attempts.Count -eq 1 -and
    [IO.Path]::GetFullPath($attempts[0].FullName) -ceq
        [IO.Path]::GetFullPath($attemptRoot)
) "R23D59 one-shot attempt count changed"

Write-Host (
    "QSDK_R23D59_CLOSURE_PASS classification=fixture_knee_selected " +
    "worlds=6 execution_valid=6 common_pass=3 common_fail=3 " +
    "portable_adequate=False fixture_adequate=True selected=portable_hip__fixture_knee " +
    "portable_rear_cycles=0 fixture_rear_cycles=36 rows=17952 applications=143616 " +
    "cas_refs=376 cas_unique=209 source_paths=128 dependency_edges=146 " +
    "evaluator_replay=True mutations=$mutationRejectionCount rerun=False " +
    "r60_seed_consumed=False turning=False prone=False " +
    "physical_authority=False release=False"
)
