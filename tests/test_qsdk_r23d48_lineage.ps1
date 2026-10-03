#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$preregistrationPath = Join-Path $turningRoot (
    "r23d48_support_loss_conditioned_three_engine_turning_preregistration_v1.json"
)
$expectedBindings = [ordered]@{
    r23d42_closure_raw_sha256 = [ordered]@{
        path = "r23d42_three_engine_startup_ramp_turning_closure_v1.json"
        sha256 = "sha256:1f75146d2c211ff33980d267a0024b53391c5fbdefb2059773e97f436f02651b"
    }
    r23d44_closure_raw_sha256 = [ordered]@{
        path = "r23d44_rapier_paired_startup_transform_closure_v1.json"
        sha256 = "sha256:5e48ede1cb22f9e9d2ea7190e1d6a2ca6ff1fa278796c4b27f76e1979eb88d4a"
    }
    r23d47_closure_raw_sha256 = [ordered]@{
        path = "r23d47_support_loss_conditioned_startup_closure_v1.json"
        sha256 = "sha256:c69d3c1c0076122db87891b4c8aeb1065433944630226a314c646d06daf5eb94"
    }
    measurement_closure_raw_sha256 = [ordered]@{
        path = "r23d31_cycle_integrated_directional_response_closure_v1.json"
        sha256 = "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c"
    }
}

function Assert-R23D48Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D48 LINEAGE: $Message" }
}

function Get-R23D48Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D48Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$lineage = $preregistration.immutable_lineage
$successor = $preregistration.scientifically_distinct_successor
$basis = $preregistration.outcome_exposed_mechanism_basis
$matrix = $preregistration.frozen_matrix

foreach ($field in $expectedBindings.Keys) {
    $binding = $expectedBindings[$field]
    $observed = Get-R23D48Hash (Join-Path $turningRoot $binding.path)
    Assert-R23D48Lineage (
        $observed -ceq [string]$binding.sha256 -and
        [string]$lineage[$field] -ceq [string]$binding.sha256
    ) "immutable binding changed: $field"
}

Assert-R23D48Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [string]$preregistration.study_classification -ceq
        "prospective_exact_finite_fresh_three_engine_support_loss_conditioned_turning_validation" -and
    [bool]$lineage.r23d42_identity_consumed -and
    [bool]$lineage.r23d44_identity_consumed -and
    [bool]$lineage.r23d47_identity_consumed -and
    -not [bool]$lineage.historical_result_reinterpreted -and
    -not [bool]$lineage.historical_world_reused_as_a_new_cell -and
    -not [bool]$lineage.same_identity_rerun_permitted -and
    -not [bool]$lineage.selective_retry_permitted
) "immutable predecessor interpretation changed"

Assert-R23D48Lineage (
    [bool]$basis.development_only_selection -and
    [int]$basis.mujoco_first_complete_support_loss_semantic_step -eq 3 -and
    -not [bool]$basis.rapier_complete_support_loss_during_probe -and
    -not [bool]$basis.godot_jolt_complete_support_loss_during_probe -and
    -not [bool]$basis.discovery_can_establish_fresh_seed_result -and
    -not [bool]$basis.discovery_can_establish_population_separator
) "outcome-exposed mechanism basis changed"

Assert-R23D48Lineage (
    [int]$successor.fresh_held_out_seed -eq 21512 -and
    [bool]$successor.fresh_held_out_condition_selected -and
    -not [bool]$successor.seed_outcome_exposed_before_preregistration -and
    [string]$successor.startup_transform_id -ceq
        "support_loss_latched_smoothstep_one_cycle_v1" -and
    [bool]$successor.startup_transform_applied_to_all_engines_and_arms -and
    [int]$successor.engine_identity_input_count -eq 0 -and
    [int]$successor.arm_identity_input_count -eq 0 -and
    [int]$matrix.declared_world_count -eq 9 -and
    [bool]$matrix.serial_execution_required -and
    [bool]$matrix.all_cells_run_regardless_of_intermediate_outcome -and
    -not [bool]$preregistration.claims.finite_three_engine_turning -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "prospective R48 boundary changed"

Write-Host (
    "QSDK_R23D48_LINEAGE_PASS predecessors=4 seed=21512 worlds=9 " +
    "transform=support_loss_latched_smoothstep_one_cycle_v1 physical=False"
)
