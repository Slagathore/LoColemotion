#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$diagnosisRoot = Join-Path $repoRoot "sdk\trace_analysis"
$preregistrationPath = Join-Path $turningRoot (
    "r23d44_rapier_paired_startup_transform_preregistration_v1.json"
)

function Assert-R23D44Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D44 LINEAGE: $Message" }
}

function Get-R23D44Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$lineage = $preregistration.immutable_lineage
$paired = $preregistration.paired_causal_development
$repair = $preregistration.implementation_repair_boundary
$matrix = $preregistration.frozen_matrix
$retention = $preregistration.production_trace_retention_gate
$bindings = @{
    r23d30_physical_closure_raw_sha256 = Join-Path $turningRoot (
        "r23d30_cycle_coherent_directional_response_closure_v1.json"
    )
    r23d43_physical_closure_raw_sha256 = Join-Path $turningRoot (
        "r23d43_rapier_retention_hardened_turning_closure_v1.json"
    )
    r23d43_startup_transform_diagnosis_closure_raw_sha256 = Join-Path $diagnosisRoot (
        "r23d43_rapier_startup_transform_diagnosis_closure_v1.json"
    )
}
foreach ($field in $bindings.Keys) {
    Assert-R23D44Lineage (
        [string]$lineage[$field] -ceq (Get-R23D44Hash $bindings[$field])
    ) "lineage binding changed: $field"
}

Assert-R23D44Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [bool]$lineage.r23d30_identity_consumed -and
    [bool]$lineage.r23d43_identity_consumed -and
    -not [bool]$lineage.same_identity_rerun_permitted -and
    -not [bool]$lineage.historical_result_reinterpreted -and
    -not [bool]$lineage.historical_world_reused_as_new_cell -and
    [bool]$lineage.diagnosis_found_seed_and_transform_confounded -and
    [bool]$lineage.diagnosis_authorized_only_a_paired_same_seed_development_successor
) "consumed predecessor or diagnosis boundary changed"

Assert-R23D44Lineage (
    [int]$paired.campaign_seed -eq 21504 -and
    [bool]$paired.seed_was_outcome_exposed_before_preregistration -and
    -not [bool]$paired.fresh_or_held_out_condition -and
    -not [bool]$paired.validation_or_replication_study -and
    [bool]$paired.same_initial_perturbation_across_candidates -and
    [string]$paired.sole_declared_candidate_difference -ceq
        "startup_velocity_transform" -and
    @($paired.ordered_candidate_ids).Count -eq 2 -and
    -not [bool]$paired.controller_behavior_changed -and
    -not [bool]$paired.measurement_changed -and
    -not [bool]$paired.threshold_changed -and
    -not [bool]$paired.physics_changed -and
    -not [bool]$paired.morphology_changed -and
    -not [bool]$paired.population_or_cross_seed_inference_permitted
) "paired exact-seed development boundary changed"

Assert-R23D44Lineage (
    [bool]$repair.windows_same_file_cas_verifier_repair -and
    [bool]$repair.path_text_equality_for_file_identity_forbidden -and
    [bool]$repair.ordinary_and_extended_windows_namespace_positive_control_required -and
    [bool]$repair.wrong_existing_file_negative_control_required -and
    -not [bool]$repair.old_r23d43_official_result_repaired_or_reclassified -and
    [int]$matrix.declared_world_count -eq 6 -and
    [int]$retention.synthetic_trace_count -eq 2 -and
    [int]$retention.synthetic_trace_row_count -eq 5984 -and
    [int]$retention.world_build_count -eq 0 -and
    -not [bool]$preregistration.claims.finite_rapier_turning_validation -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "repair, finite matrix, or claim boundary changed"

Write-Host (
    "QSDK_R23D44_LINEAGE_PASS predecessors=R23D30,R23D43 seed=21504 " +
    "candidates=2 worlds=6 controller_changes=0 threshold_changes=0 " +
    "validation=False physical=False"
)
