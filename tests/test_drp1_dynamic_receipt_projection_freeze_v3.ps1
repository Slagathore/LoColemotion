#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$freezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json"
$predecessorFreezePath = Join-Path $repoRoot `
    "sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"
$run1AuditPath = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_run1_result.ps1"
$run2AuditPath = Join-Path $repoRoot `
    "tests\test_drp1_dynamic_receipt_projection_run2_result.ps1"
$runnerPath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1.ps1"
$conformancePath = Join-Path $repoRoot "sdk\run_conformance.ps1"
$zeroWorldGatePath = Join-Path $repoRoot `
    "sdk\run_balanced_wave_dynamic_receipt_projection_drp1_zero_world_gate.ps1"
$regressionId = "BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1"
$gateId = "DRP1"
$parentCommit = "5d7b45029a2bbf3e5bcc57c8774db15215fcdccf"
$predecessorFreezeSha256 = `
    "13dc2eeff72915551f126dabdba844cceee5f88aaaecf7932b6b1ad028e5fac6"
$run2ResultSha256 = `
    "c40fd2bceeddbb048fad9e73c748c6ce074db65eb504a3a183e8f5e4d8c10355"

function Assert-Drp1FreezeV3 {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Drp1FreezeV3RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
}

Assert-Drp1FreezeV3 (
    (Test-Path -LiteralPath $freezePath -PathType Leaf) -and
    (Test-Path -LiteralPath $predecessorFreezePath -PathType Leaf) -and
    (Get-Drp1FreezeV3RawSha256 -Path $predecessorFreezePath) -ceq
        $predecessorFreezeSha256
) "$gateId revision-three freeze or immutable revision-two predecessor is missing"

$freeze = Get-Content -Raw -LiteralPath $freezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$predecessor = [System.Collections.IDictionary]$freeze.predecessor_freeze
$run2 = [System.Collections.IDictionary]$freeze.predecessor_launch_result
$correction = [System.Collections.IDictionary]$freeze.correction_scope
$witness = [System.Collections.IDictionary]$freeze.stage_three_zero_world_witness
$classification = [System.Collections.IDictionary]$freeze.classification
$inherited = [System.Collections.IDictionary]$freeze.inherited_contract

Assert-Drp1FreezeV3 (
    [string]$freeze.schema_version -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v3" -and
    [string]$freeze.status -ceq
        "frozen_after_run2_pre_world_schema_mismatch_and_complete_v3_zero_world_gate" -and
    [string]$freeze.regression_id -ceq $regressionId -and
    [string]$freeze.gate_id -ceq $gateId -and
    [string]$freeze.freeze_parent_commit -ceq $parentCommit -and
    [int]$freeze.freeze_revision -eq 3 -and
    [bool]$freeze.full_godot_conformance_regression_ready_after_clean_push -and
    -not [bool]$freeze.standalone_regression_physics_authorized
) "$gateId revision-three freeze identity or authority changed"

Assert-Drp1FreezeV3 (
    [string]$predecessor.path -ceq
        "sdk/balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json" -and
    [string]$predecessor.raw_sha256 -ceq $predecessorFreezeSha256 -and
    [string]$predecessor.source_commit -ceq $parentCommit -and
    [int]$predecessor.source_binding_count -eq 32 -and
    [bool]$predecessor.route_specific_nested_walking_schema_preserved
) "$gateId revision-two predecessor boundary changed"

Assert-Drp1FreezeV3 (
    [string]$run2.result_path -ceq
        "sdk/balanced_wave_dynamic_receipt_projection_drp1_run2_result.json" -and
    [string]$run2.result_raw_sha256 -ceq $run2ResultSha256 -and
    [string]$run2.source_commit -ceq $parentCommit -and
    [int]$run2.world_build_count -eq 0 -and
    [int]$run2.physical_process_launch_count -eq 0 -and
    [int]$run2.dynamic_receipt_count -eq 0 -and
    [int]$run2.source_binding_match_count -eq 32 -and
    [int]$run2.source_binding_mismatch_count -eq 0 -and
    -not [bool]$run2.attestation_published -and
    -not [bool]$run2.scientific_result -and
    -not [bool]$run2.locomotion_negative -and
    [bool]$run2.same_repeatable_regression_id_may_rerun
) "$gateId run-two predecessor boundary changed"

Assert-Drp1FreezeV3 (
    [string]$correction.selected_freeze_path_before -ceq
        "sdk/balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json" -and
    [string]$correction.required_schema_before -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v1" -and
    [string]$correction.selected_freeze_path_after -ceq
        "sdk/balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json" -and
    [string]$correction.required_schema_after -ceq
        "sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v3" -and
    [bool]$correction.selected_and_required_schema_are_identical -and
    [int]$correction.regression_worlds_exposed_before_freeze -eq 0 -and
    -not [bool]$correction.worker_changed -and
    -not [bool]$correction.controller_changed -and
    -not [bool]$correction.evaluator_changed -and
    -not [bool]$correction.regression_matrix_changed -and
    -not [bool]$correction.route_identity_changed -and
    -not [bool]$correction.seed_changed -and
    -not [bool]$correction.threshold_changed -and
    -not [bool]$correction.claim_contract_changed
) "$gateId revision-three correction scope inflated or changed"

Assert-Drp1FreezeV3 (
    [bool]$witness.actual_godot_worker_zero_world_gate_passed -and
    [bool]$witness.godot_skipped_zero_world_gate_passed -and
    [int]$witness.worker_entrypoint_count -eq 24 -and
    [int]$witness.constructed_final_receipt_rejection_count -eq 24 -and
    [int]$witness.route_specific_nested_schema_preflight_count -eq 24 -and
    [int]$witness.cross_route_nested_schema_rejection_count -eq 24 -and
    [int]$witness.authorization_refusal_canary_count -eq 2 -and
    [int]$witness.evaluator_gate_count -eq 12 -and
    [int]$witness.evaluator_gate_canary_count -eq 12 -and
    [int]$witness.malformed_receipt_fail_closed_canary_count -eq 1 -and
    [int]$witness.cross_route_evaluator_schema_canary_count -eq 2 -and
    [int]$witness.regression_world_build_count -eq 0 -and
    [int]$witness.regression_physical_process_launch_count -eq 0 -and
    -not [bool]$witness.locomotion_outcome_exposed
) "$gateId revision-three zero-world witness changed"

Assert-Drp1FreezeV3 (
    [bool]$classification.ordinary_repeatable_regression_test_physics -and
    -not [bool]$classification.scientific_campaign -and
    -not [bool]$classification.one_shot_identity -and
    -not [bool]$classification.candidate_or_policy_selection_permitted -and
    -not [bool]$classification.walking_or_nuisance_acceptance_permitted -and
    [bool]$classification.rerunnable_after_implementation_freeze -and
    -not [bool]$classification.scientific_evidence_retained -and
    -not [bool]$classification.new_scientific_outcome_consumed
) "$gateId repeatable noncampaign classification changed"

Assert-Drp1FreezeV3 (
    [string]$inherited.path -ceq
        "sdk/balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json" -and
    [string]$inherited.raw_sha256 -ceq $predecessorFreezeSha256 -and
    [bool]$inherited.route_order_unchanged -and
    [bool]$inherited.challenge_profiles_unchanged -and
    [bool]$inherited.regression_seed_order_unchanged -and
    [int]$inherited.expected_world_count -eq 24 -and
    [int]$inherited.expected_gate_count -eq 12 -and
    [bool]$inherited.route_specific_nested_schema_unchanged -and
    [bool]$inherited.walking_count_not_evaluator_input -and
    [bool]$inherited.fresh_validation_seeds_remain_unopened
) "$gateId inherited revision-two contract changed"

$v2 = Get-Content -Raw -LiteralPath $predecessorFreezePath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-Drp1FreezeV3 (
    (@($v2.regression_matrix.route_order) -join "|") -ceq
        "DRP1-REFERENCE-ROUTE|DRP1-SUCCESSOR-ROUTE" -and
    (@($v2.regression_matrix.challenge_profile_order) -join "|") -ceq
        "bw6n_baseline_v1|bw6n_rough_v1|bw6n_push_v1|bw6n_sensor_noise_v1" -and
    (@($v2.regression_matrix.regression_seed_order) -join "|") -ceq
        "22001|22002|22003" -and
    (@($v2.regression_matrix.reserved_fresh_independent_validation_seed_ids) -join "|") -ceq
        "49101|49102|49103" -and
    [int]$v2.regression_matrix.expected_world_count -eq 24 -and
    [int]$v2.complete_evaluator_contract.expected_gate_count -eq 12 -and
    [bool]$v2.complete_evaluator_contract.walking_count_is_not_an_evaluator_input
) "$gateId exact inherited v2 matrix or evaluator contract changed"

foreach ($entry in $freeze.claim_boundary.GetEnumerator()) {
    Assert-Drp1FreezeV3 (-not [bool]$entry.Value) (
        "$gateId claim inflated at revision-three freeze: $($entry.Key)"
    )
}

$bindings = [System.Collections.IDictionary]$freeze.source_bindings
Assert-Drp1FreezeV3 ($bindings.Count -eq 36) (
    "$gateId v3 source binding surface must contain exactly 36 members"
)
foreach ($entry in $bindings.GetEnumerator()) {
    $binding = [System.Collections.IDictionary]$entry.Value
    $relativePath = [string]$binding.path
    $expectedHash = [string]$binding.raw_sha256
    $absolutePath = [IO.Path]::GetFullPath((Join-Path $repoRoot $relativePath))
    $repoPrefix = $repoRoot.TrimEnd("\", "/") + [IO.Path]::DirectorySeparatorChar
    Assert-Drp1FreezeV3 (
        $absolutePath.StartsWith($repoPrefix, [StringComparison]::OrdinalIgnoreCase) -and
        $expectedHash -cmatch "^[0-9a-f]{64}$" -and
        (Test-Path -LiteralPath $absolutePath -PathType Leaf) -and
        (Get-Drp1FreezeV3RawSha256 -Path $absolutePath) -ceq $expectedHash
    ) "$gateId v3 source binding changed: $($entry.Key)"
}

& pwsh -NoLogo -NoProfile -File $run1AuditPath
Assert-Drp1FreezeV3 ($LASTEXITCODE -eq 0) "$gateId run-one audit failed"
& pwsh -NoLogo -NoProfile -File $run2AuditPath
Assert-Drp1FreezeV3 ($LASTEXITCODE -eq 0) "$gateId run-two audit failed"

$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
$conformanceSource = Get-Content -Raw -LiteralPath $conformancePath
foreach ($marker in @(
    '"sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json"',
    '"sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v3"',
    "Test-Drp1FreezeBindings -Freeze `$freeze",
    "DRP1_FULL_GODOT_REGRESSION_PASS"
)) {
    Assert-Drp1FreezeV3 (
        $runnerSource.Contains($marker, [StringComparison]::Ordinal)
    ) "$gateId v3 runner marker is missing: $marker"
}
Assert-Drp1FreezeV3 (
    -not $runnerSource.Contains(
        '"sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v2.json"',
        [StringComparison]::Ordinal
    ) -and
    -not $runnerSource.Contains(
        '"sporespore_balanced_wave_dynamic_receipt_projection_drp1_freeze_v1"',
        [StringComparison]::Ordinal
    )
) "$gateId v3 runner retained a predecessor freeze selector or schema requirement"

foreach ($marker in @(
    '"sdk\balanced_wave_dynamic_receipt_projection_drp1_run2_result.json"',
    '"tests\test_drp1_dynamic_receipt_projection_run2_result.ps1"',
    '"sdk\balanced_wave_dynamic_receipt_projection_drp1_freeze_v3.json"',
    '"tests\test_drp1_dynamic_receipt_projection_freeze_v3.ps1"'
)) {
    Assert-Drp1FreezeV3 (
        $conformanceSource.Contains($marker, [StringComparison]::Ordinal)
    ) "$gateId complete conformance marker is missing: $marker"
}

foreach ($path in @($runnerPath, $conformancePath, $zeroWorldGatePath)) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $path,
        [ref]$tokens,
        [ref]$parseErrors
    )
    Assert-Drp1FreezeV3 ($parseErrors.Count -eq 0) (
        "$gateId v3 PowerShell source no longer parses: $path"
    )
}

Write-Host (
    "DRP1_STAGE_THREE_FREEZE_PASS revision=3 predecessor_worlds=0 " +
    "predecessor_workers=0 predecessor_bindings=32/32 worlds=0 cells=24 gates=12 " +
    "source_bindings=$($bindings.Count) selected_schema=v3 required_schema=v3 " +
    "entrypoints=24 evaluator_canaries=12 malformed_receipt_canary=1 " +
    "cross_route_evaluator_canaries=2 nested_walking_schemas=24 " +
    "cross_route_schema_rejections=24 authorization_canaries=2 " +
    "regression_ready_after_clean_push=True one_shot=False selection_authority=False " +
    "walking_authority=False physical_authority=False " +
    "freeze_sha256=$(Get-Drp1FreezeV3RawSha256 -Path $freezePath)"
)
