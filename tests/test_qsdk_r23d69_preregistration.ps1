#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d69_complete_production_row_conformance_repaired_" +
    "three_engine_turning_preregistration_v1.json"
)
$compilerPath = Join-Path $repoRoot "sdk\turning\r23d69_seed_fixture_compiler.gd"
$implementationPath = Join-Path $repoRoot (
    "sdk\turning\r23d69_production_route_three_engine_turning_" +
    "implementation_v1.json"
)
$releasePath = Join-Path $repoRoot "sdk\release\quadruped_release_contract.json"
$supportPath = Join-Path $repoRoot "sdk\release\quadruped_support_matrix.json"
$godotPath = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
$parentCommit = "e26cc416e1478e82137f36c19a1270c79d11b1f9"
$parentTree = "0f2ed1503179b3817d53ebe9ac1060e5ec052163"
$campaignId = (
    "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-" +
    "THREE-ENGINE-TURNING-VALIDATION"
)
$declarationStatus = (
    "prospective_declaration_complete_compact_production_row_ghosts_and_" +
    "implementation_pending_physical_not_authorized"
)
$implementationStatus = (
    "implementation_complete_complete_zero_world_gate_passed_" +
    "physical_not_authorized"
)

function Assert-R23D69([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D69 PREREGISTRATION: $Message" }
}

function Get-RawSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Find-R23D69Objects([object]$Value) {
    $found = [Collections.Generic.List[object]]::new()
    function Visit([object]$Item) {
        if ($null -eq $Item) { return }
        if ($Item -is [Collections.IDictionary]) {
            if (
                $Item.Contains("campaign_id") -and
                [string]$Item["campaign_id"] -ceq $campaignId
            ) {
                $found.Add($Item)
            }
            foreach ($child in $Item.Values) { Visit $child }
            return
        }
        if ($Item -is [PSCustomObject]) {
            $property = $Item.PSObject.Properties["campaign_id"]
            if ($null -ne $property -and [string]$property.Value -ceq $campaignId) {
                $found.Add($Item)
            }
            foreach ($child in $Item.PSObject.Properties.Value) { Visit $child }
            return
        }
        if ($Item -is [Collections.IEnumerable] -and $Item -isnot [string]) {
            foreach ($child in $Item) { Visit $child }
        }
    }
    Visit $Value
    return @($found)
}

foreach ($path in @(
    $declarationPath,
    $compilerPath,
    $implementationPath,
    $releasePath,
    $supportPath,
    $godotPath
)) {
    Assert-R23D69 (Test-Path -LiteralPath $path -PathType Leaf) "missing path: $path"
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$parentActual = (& git -C $repoRoot rev-parse $parentCommit).Trim()
$treeActual = (& git -C $repoRoot rev-parse "$parentCommit`^{tree}").Trim()
Assert-R23D69 (
    $LASTEXITCODE -eq 0 -and
    $parentActual -ceq $parentCommit -and
    $treeActual -ceq $parentTree -and
    [string]$declaration.declaration_parent.commit -ceq $parentCommit -and
    [string]$declaration.declaration_parent.tree_git_oid -ceq $parentTree -and
    [bool]$declaration.declaration_parent.clean_pushed_live_equal
) "clean-pushed declaration parent changed"

$decimalMatches = @(& git -C $repoRoot grep -n -E '(^|[^0-9])23187([^0-9]|$)' `
    $parentCommit -- . 2>$null)
Assert-R23D69 ($LASTEXITCODE -in @(0, 1)) "decimal seed search failed"
$groupedMatches = @(& git -C $repoRoot grep -n -E '(^|[^0-9])23,187([^0-9]|$)' `
    $parentCommit -- . 2>$null)
Assert-R23D69 ($LASTEXITCODE -in @(0, 1)) "grouped seed search failed"
Assert-R23D69 (
    @($decimalMatches + $groupedMatches | Sort-Object -Unique).Count -eq 0 -and
    [int]$declaration.scientific_distinction_and_change_budget.fresh_seed -eq 23187 -and
    [int]$declaration.scientific_distinction_and_change_budget.first_candidate_after_consumed_seed -eq 23187 -and
    [int]$declaration.scientific_distinction_and_change_budget.first_candidate_token_occurrence_count_at_declaration_parent -eq 0
) "fresh seed is not the first unused odd successor"

$expectedBindings = [ordered]@{
    "sdk/turning/r23d68_production_route_three_engine_turning_validation_closure_v1.json" =
        "sha256:d67ce89cc8bf6cc3d07e3a39f59642fee92bbe95308d9dcee6c55b4bd5358cd3"
    "tests/test_qsdk_r23d68_physical_closure.ps1" =
        "sha256:3c9be16c384b54aa4a4d66dce17d0726da462c6e6c09e1de1c5a8d36391fe284"
    "sdk/turning/r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json" =
        "sha256:6d538c8678951c92bce81e32ba29d076148ad640653d7a3164ad2388614a10b7"
    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json" =
        "sha256:d625d911c6f582a1bccd5bf6b8fd019e93befd7893dc0e6ededbd5870c32571a"
    "sdk/turning/r23d69_seed_fixture_compiler.gd" =
        "sha256:44252a8081b34eef63a776acbb2995fa7f41b2c4e1b8c8ba3c4bd3983288a04a"
}
foreach ($entry in $expectedBindings.GetEnumerator()) {
    Assert-R23D69 (
        (Get-RawSha256 (Join-Path $repoRoot $entry.Key)) -ceq $entry.Value
    ) "binding changed: $($entry.Key)"
}

$observed = @($declaration.observed_predecessor_integration_population.items)
$expectedObserved = [ordered]@{
    godot_actuator_phase_observation_missing = @(
        "godot_jolt", 3, "scripts/lab/gait/physical_wave_gait_quadruped.gd",
        "21800d942fbc63c599a8c48f64bd0031e2016e95"
    )
    rapier_post_schedule_segment_relabel = @(
        "rapier_parry", 3,
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
        "a820dcbbe4baa8d4fc9fca28e66412a8c263e590"
    )
    mujoco_non_native_boolean_strict_json_failure = @(
        "mujoco", 3,
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d65_selected_profile_turning.py",
        "6c4fb2052adda03d32d3309129b75369fed897f6"
    )
    mujoco_outer_failure_projection_lost_inner_counts = @(
        "mujoco", 3,
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d68_turning_route.py",
        "06d85f7841100bedc5222d64dd62b592f5a3f464"
    )
}
Assert-R23D69 (
    $observed.Count -eq 4 -and
    [int]$declaration.observed_predecessor_integration_population.population_size -eq 4 -and
    [bool]$declaration.observed_predecessor_integration_population.complete_population_required -and
    -not [bool]$declaration.observed_predecessor_integration_population.sampling_used
) "observed integration population changed"
foreach ($item in $observed) {
    $expected = $expectedObserved[[string]$item.failure_id]
    Assert-R23D69 ($null -ne $expected) "unexpected observed failure"
    $blob = (& git -C $repoRoot rev-parse "$parentCommit`:$([string]$item.observed_producer_path)").Trim()
    Assert-R23D69 (
        [string]$item.engine_id -ceq $expected[0] -and
        [int]$item.affected_cell_count -eq [int]$expected[1] -and
        [string]$item.observed_producer_path -ceq $expected[2] -and
        [string]$item.observed_producer_git_blob_oid -ceq $expected[3] -and
        $blob -ceq $expected[3]
    ) "observed failure provenance changed: $([string]$item.failure_id)"
}

$matrix = $declaration.frozen_matrix
$expectedCells = foreach ($engine in @("godot_jolt", "rapier_parry", "mujoco")) {
    foreach ($arm in @("reference_zero", "positive_heading", "negative_heading")) {
        "r23d69__$engine`__s23187__$arm"
    }
}
Assert-R23D69 (
    [string]$declaration.schema_version -ceq
        "sporespore_qsdk_r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1" -and
    [string]$declaration.status -ceq $declarationStatus -and
    [string]$declaration.campaign_id -ceq $campaignId -and
    [string]$declaration.gate_id -ceq "QSDK-R23D69" -and
    [string]$declaration.physical_question_class -ceq "finite_decision" -and
    [string]$declaration.integration_repair_work_class -ceq
        "development_then_complete_population_equivalence_non_inferiority" -and
    [int]$matrix.campaign_seed -eq 23187 -and
    (@($matrix.engine_order) -join ",") -ceq "godot_jolt,rapier_parry,mujoco" -and
    (@($matrix.arm_order) -join ",") -ceq
        "reference_zero,positive_heading,negative_heading" -and
    (@($matrix.ordered_cell_ids) -join ",") -ceq ($expectedCells -join ",") -and
    [int]$matrix.declared_cell_count -eq 9 -and
    [bool]$matrix.complete_population_required -and
    -not [bool]$matrix.sampling_used
) "campaign identity or complete matrix changed"

$ghosts = $declaration.compact_development_ghosts
Assert-R23D69 (
    (@($ghosts.representative_semantic_steps) -join ",") -ceq
        "599,600,1799,1800,2399,2400,2991" -and
    [int]$ghosts.engine_count -eq 3 -and
    [int]$ghosts.representative_complete_row_count -eq 21 -and
    [bool]$ghosts.godot_actual_shared_row_composer_required -and
    [bool]$ghosts.rapier_actual_shared_segment_projection_required -and
    [bool]$ghosts.mujoco_actual_native_boolean_projection_required -and
    [bool]$ghosts.frozen_row_contract_required -and
    [bool]$ghosts.strict_json_allow_nan_false_required -and
    [int]$ghosts.failure_projection_case_count -eq 2 -and
    [bool]$ghosts.inner_failure_receipt_preservation_required -and
    -not [bool]$ghosts.full_seeded_world_required -and
    -not [bool]$ghosts.behavioral_success_prediction_allowed -and
    [int]$ghosts.model_construction_count -eq 0 -and
    [int]$ghosts.world_attempt_count -eq 0 -and
    [int]$ghosts.world_build_count -eq 0
) "compact production-row ghost contract changed"

$provenance = $declaration.threshold_and_population_provenance
$claims = $declaration.claims
Assert-R23D69 (
    [double]$provenance.equivalence_margin -eq 0.0 -and
    [double]$provenance.non_inferiority_margin -eq 0.0 -and
    [int]$provenance.physical_cohort_size -eq 9 -and
    [int]$provenance.integration_failure_population_size -eq 4 -and
    [int]$provenance.representative_complete_row_population_size -eq 21 -and
    [bool]$claims.declaration_complete -and
    -not [bool]$claims.implementation_complete -and
    -not [bool]$claims.compact_complete_production_row_ghosts_passed -and
    -not [bool]$claims.physical_campaign_opened -and
    -not [bool]$claims.finite_three_engine_turning -and
    -not [bool]$claims.q_sdk_r23_satisfied -and
    -not [bool]$claims.cross_engine_equivalence -and
    -not [bool]$claims.prone_to_standing -and
    -not [bool]$claims.release_authority -and
    [string]$claims.release_score_before -ceq "10/25" -and
    [string]$claims.release_score_after -ceq "10/25" -and
    -not [bool]$declaration.physical_execution_authorized -and
    [int]$declaration.world_attempt_count -eq 0 -and
    [int]$declaration.world_build_count -eq 0
) "threshold, claim, or zero-world boundary changed"

$godotOutput = @(& $godotPath --headless --path $repoRoot `
    --script res://sdk/turning/r23d69_seed_fixture_compiler.gd 2>&1)
Assert-R23D69 ($LASTEXITCODE -eq 0) "seed compiler failed"
$markers = @($godotOutput | Where-Object {
    [string]$_ -clike "QSDK_R23D69_SEED_FIXTURES *"
})
Assert-R23D69 ($markers.Count -eq 1) "seed compiler marker population changed"
$receipt = ([string]$markers[0]).Substring("QSDK_R23D69_SEED_FIXTURES ".Length) |
    ConvertFrom-Json -AsHashtable -Depth 100
$actualFixture = $receipt.fixtures[0]
$expectedFixture = $declaration.seed_fixture_compilation.compiled_initial_perturbation
Assert-R23D69 (
    [string]$receipt.schema_version -ceq "sporespore_qsdk_r23d69_seed_fixtures_v1" -and
    (@($receipt.r23d69_unopened_held_out_seeds) -join ",") -ceq "23187" -and
    @($receipt.fixtures).Count -eq 1 -and
    [int]$actualFixture.campaign_seed -eq [int]$expectedFixture.campaign_seed -and
    [string]$actualFixture.cohort -ceq [string]$expectedFixture.cohort -and
    [double]$actualFixture.fixture_vertical_clearance_m -eq
        [double]$expectedFixture.fixture_vertical_clearance_m -and
    [double]$actualFixture.fixture_yaw_rad -eq [double]$expectedFixture.fixture_yaw_rad -and
    (@($actualFixture.initial_linear_velocity_world_m_s) | ConvertTo-Json -Compress) -ceq
        (@($expectedFixture.initial_linear_velocity_world_m_s) | ConvertTo-Json -Compress) -and
    (@($actualFixture.initial_torso_angular_velocity_world_rad_s) | ConvertTo-Json -Compress) -ceq
        (@($expectedFixture.initial_torso_angular_velocity_world_rad_s) | ConvertTo-Json -Compress) -and
    [int]$actualFixture.gait_phase_offset_ticks -eq
        [int]$expectedFixture.gait_phase_offset_ticks -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0
) "compiled seed fixture changed"

$release = Get-Content -Raw -LiteralPath $releasePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$support = Get-Content -Raw -LiteralPath $supportPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$declarationSha = Get-RawSha256 $declarationPath
$auditSha = Get-RawSha256 $PSCommandPath
$compilerSha = Get-RawSha256 $compilerPath
$implementationSha = Get-RawSha256 $implementationPath
$releaseObjects = @(Find-R23D69Objects $release)
$supportObjects = @(Find-R23D69Objects $support)
Assert-R23D69 (
    $releaseObjects.Count -eq 1 -and
    $supportObjects.Count -eq 1 -and
    @($releaseObjects + $supportObjects | Where-Object {
        [string]$_.status -cne $implementationStatus -or
        [string]$_.preregistration_raw_sha256 -cne $declarationSha -or
        [string]$_.declaration_audit_raw_sha256 -cne $auditSha -or
        [string]$_.seed_fixture_compiler_raw_sha256 -cne $compilerSha -or
        [string]$_.implementation_contract_path -cne
            "sdk/turning/r23d69_production_route_three_engine_turning_implementation_v1.json" -or
        [string]$_.implementation_contract_raw_sha256 -cne $implementationSha -or
        [int]$_.implementation_dependency_count -ne 214 -or
        [int]$_.fresh_seed -ne 23187 -or
        [int]$_.declared_cell_count -ne 9 -or
        -not [bool]$_.implementation_complete -or
        -not [bool]$_.compact_complete_production_row_ghosts_passed -or
        -not [bool]$_.complete_zero_world_gate_passed -or
        [bool]$_.qualification_passed -or
        [bool]$_.campaign_attestation_adopted -or
        [bool]$_.physical_campaign_opened -or
        [bool]$_.q_sdk_r23_satisfied -or
        [bool]$_.release_authorized
    }).Count -eq 0
) "live authority projection changed"

Write-Output (
    "[turning/3e] PASS R23D69 prospective declaration: parent=e26cc416 " +
    "seed=23187 occurrences=0 failures=4 row_witnesses=21 cells=9 " +
    "models=0 worlds=0 physics=False QSDK-R23=False score=10/25"
)
