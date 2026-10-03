#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$predecessorPath = Join-Path $turningRoot (
    "r23d42_three_engine_startup_ramp_turning_closure_v1.json"
)
$preregistrationPath = Join-Path $turningRoot (
    "r23d43_rapier_retention_hardened_turning_preregistration_v1.json"
)
$expectedPredecessorHash = (
    "sha256:1f75146d2c211ff33980d267a0024b53391c5fbdefb2059773e97f436f02651b"
)

function Assert-R23D43Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D43 LINEAGE: $Message" }
}

function Get-R23D43Hash([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

$predecessor = Get-Content -Raw -LiteralPath $predecessorPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$lineage = $preregistration.immutable_lineage
$successor = $preregistration.scientifically_distinct_successor
$retention = $preregistration.production_trace_retention_gate

Assert-R23D43Lineage (
    (Get-R23D43Hash $predecessorPath) -ceq $expectedPredecessorHash -and
    [string]$lineage.r23d42_physical_closure -ceq
        "sdk/turning/r23d42_three_engine_startup_ramp_turning_closure_v1.json"
) "R42 closure binding changed"

Assert-R23D43Lineage (
    [bool]$predecessor.identity_consumed -and
    -not [bool]$predecessor.same_identity_rerun_allowed -and
    [bool]$lineage.r23d42_identity_consumed -and
    -not [bool]$lineage.r23d42_same_identity_rerun_permitted -and
    -not [bool]$lineage.r23d42_outcome_reinterpreted -and
    -not [bool]$lineage.r23d42_worlds_reused_as_r23d43_cells -and
    [bool]$lineage.r23d42_rapier_production_failure_text_was_incomplete -and
    [bool]$lineage.r23d42_postclosure_rows_do_not_create_acceptance_authority
) "R42 negative and no-rerun boundary changed"

Assert-R23D43Lineage (
    [string]$preregistration.status -ceq "prospective_zero_world_only" -and
    [int]$successor.fresh_held_out_seed -eq 21511 -and
    [bool]$successor.fresh_held_out_condition_selected -and
    -not [bool]$successor.outcome_exposed_before_preregistration -and
    -not [bool]$successor.same_initial_condition_as_r23d42 -and
    -not [bool]$successor.controller_behavior_changed -and
    -not [bool]$successor.measurement_changed -and
    -not [bool]$successor.threshold_changed -and
    -not [bool]$successor.physics_changed -and
    [int]$successor.evidence_implementation_change_count -eq 5 -and
    [int]$preregistration.frozen_matrix.declared_world_count -eq 3 -and
    [bool]$retention.required_before_first_world -and
    [int]$retention.synthetic_trace_row_count -eq 2992 -and
    [int]$retention.world_build_count -eq 0 -and
    -not [bool]$preregistration.claims.finite_rapier_turning_replication -and
    -not [bool]$preregistration.claims.cross_engine_equivalence
) "prospective R43 repair boundary changed"

Write-Host (
    "QSDK_R23D43_LINEAGE_PASS predecessor=R23D42 seed=21511 worlds=3 " +
    "controller_changes=0 evidence_repairs=5 physical=False"
)
