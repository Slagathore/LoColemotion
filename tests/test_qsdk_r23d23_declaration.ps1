#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$declarationPath = Join-Path $repoRoot (
    "sdk\turning\r23d23_reduced_yaw_transfer_preregistration_v1.json"
)
$closurePath = Join-Path $repoRoot "sdk\turning\r23d21_physical_closure_v1.json"
$closureAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d21_closure.ps1"
$invalidPredecessorClosurePath = Join-Path $repoRoot (
    "sdk\turning\r23d22_physical_closure_v1.json"
)
$invalidPredecessorAuditPath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d22_closure.ps1"
)
$r23d23ClosurePath = Join-Path $repoRoot "sdk\turning\r23d23_physical_closure_v1.json"

function Assert-R23D23Declaration([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D23 declaration: $Message" }
}
function Get-R23D23DeclarationSha([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D23Declaration (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $declarationPath, $closurePath, $closureAuditPath,
    $invalidPredecessorClosurePath, $invalidPredecessorAuditPath
)) {
    Assert-R23D23Declaration (Test-Path -LiteralPath $path -PathType Leaf) (
        "required input missing: $path"
    )
}
Assert-R23D23Declaration (-not (Test-Path -LiteralPath $r23d23ClosurePath)) (
    "successor identity is already closed"
)

$d = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath |
    ConvertFrom-Json -AsHashtable -Depth 100
$invalidPredecessor = Get-Content -Raw -LiteralPath $invalidPredecessorClosurePath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D23Declaration (
    [string]$d.schema_version -ceq
        "sporespore_qsdk_r23d23_reduced_yaw_transfer_preregistration_v1" -and
    [string]$d.status -ceq "prospectively_frozen_zero_world_only" -and
    [string]$d.campaign_id -ceq
        "QSDK-R23D23-IMPLEMENTATION-RECOVERY-TRANSFER-CONFORMANCE" -and
    [string]$d.gate_id -ceq "QSDK-R23D23" -and
    [string]$d.study_classification -ceq
        "prospective_exact_finite_implementation_recovery_three_engine_transfer_conformance" -and
    [string]$d.immutable_godot_lineage.closure_raw_sha256 -ceq
        (Get-R23D23DeclarationSha $closurePath) -and
    [string]$d.immutable_godot_lineage.closure_audit_raw_sha256 -ceq
        (Get-R23D23DeclarationSha $closureAuditPath) -and
    [bool]$d.immutable_godot_lineage.same_identity_rerun_forbidden -and
    [bool]$d.immutable_godot_lineage.scientific_positive -and
    [bool]$d.immutable_godot_lineage.development_informed -and
    -not [bool]$d.immutable_godot_lineage.independent_validation -and
    @($d.immutable_godot_lineage.cells).Count -eq 3
) "immutable Godot/Jolt binding changed"

$invalid = $d.immutable_invalid_predecessor_lineage
Assert-R23D23Declaration (
    [string]$invalid.gate_id -ceq "QSDK-R23D22" -and
    [string]$invalid.closure_raw_sha256 -ceq
        (Get-R23D23DeclarationSha $invalidPredecessorClosurePath) -and
    [string]$invalid.closure_audit_raw_sha256 -ceq
        (Get-R23D23DeclarationSha $invalidPredecessorAuditPath) -and
    [string]$invalid.status -ceq [string]$invalidPredecessor.status -and
    [int]$invalid.world_attempt_count -eq 6 -and
    [int]$invalid.world_build_count -eq 6 -and
    [int]$invalid.execution_valid_report_count -eq 1 -and
    [int]$invalid.worker_failure_count -eq 5 -and
    [bool]$invalid.same_identity_rerun_forbidden -and
    -not [bool]$invalid.outcomes_reused_or_reinterpreted -and
    @($invalid.verified_failure_mechanisms).Count -eq 2
) "immutable invalid R23D22 predecessor binding changed"

$declaredCells = @($d.immutable_godot_lineage.cells)
$closedCells = @($closure.cells)
Assert-R23D23Declaration ($closedCells.Count -eq 3) "R23D21 cell count changed"
for ($index = 0; $index -lt 3; $index++) {
    foreach ($field in @(
        "cell_id", "arm_id", "turn_heading_offset_rad", "terminal_cas_sha256",
        "trace_cas_sha256", "trace_byte_length", "turn_phase_yaw_delta_rad",
        "walking_and_taper_gate_passed"
    )) {
        Assert-R23D23Declaration (
            $declaredCells[$index][$field] -ceq $closedCells[$index][$field]
        ) "R23D21 cell projection drifted: $index/$field"
    }
}

Assert-R23D23Declaration (
    [string]$d.controller_transfer.controller_policy_id -ceq
        "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1" -and
    [double]$d.controller_transfer.yaw_error_stride_gain_per_rad -eq 1.0 -and
    [string]$d.controller_transfer.cross_track_frame_mode_id -ceq
        "command_heading_aligned_task_frame_v1" -and
    -not [bool]$d.controller_transfer.controller_changed_from_r23d21 -and
    -not [bool]$d.controller_transfer.engine_specific_gait_logic_permitted -and
    [int]$d.inherited_physical_contract.controller_step_count -eq 2992 -and
    [int]$d.inherited_physical_contract.terminal_step_count -eq 960 -and
    [double]$d.inherited_physical_contract.minimum_command_conditioned_yaw_separation_rad -eq 0.01
) "controller or inherited physical contract changed"
Assert-R23D23Declaration (
    [bool]$d.implementation_recovery.scientifically_distinct_successor_required -and
    -not [bool]$d.implementation_recovery.controller_or_physics_semantics_changed -and
    [bool]$d.implementation_recovery.adapter_receipt_oracle_corrected -and
    [bool]$d.implementation_recovery.mujoco_terminal_policy_binding_corrected -and
    [bool]$d.implementation_recovery.nonzero_heading_aligned_receipt_canaries_required -and
    [bool]$d.implementation_recovery.legacy_fixed_axis_oracle_rejection_required -and
    [int]$d.implementation_recovery.receipt_field_mutation_rejection_count_per_engine -eq 5 -and
    -not [bool]$d.implementation_recovery.model_construction_permitted_during_recovery_canaries
) "implementation-recovery boundary changed"

$matrix = $d.prospective_matrix
Assert-R23D23Declaration (
    (@($matrix.ordered_engine_ids) -join "|") -ceq "rapier_parry|mujoco" -and
    (@($matrix.ordered_arm_ids) -join "|") -ceq
        "reference_zero|positive_heading|negative_heading" -and
    @($matrix.ordered_cell_ids).Count -eq 6 -and
    [int]$matrix.declared_new_world_count -eq 6 -and
    [int]$matrix.declared_composite_cell_count -eq 9 -and
    [bool]$matrix.serialized_execution_required -and
    [bool]$matrix.all_cells_run_without_outcome_early_stop -and
    -not [bool]$matrix.selective_replacement_or_rerun_permitted -and
    -not [bool]$matrix.formal_cross_engine_equivalence_study -and
    [bool]$matrix.same_engine_reference_conditioning_required
) "prospective matrix changed"
Assert-R23D23Declaration (
    [bool]$d.decision_rule.positive_establishes_only_finite_three_engine_candidate -and
    -not [bool]$d.decision_rule.positive_satisfies_qsdk_r23 -and
    -not [bool]$d.decision_rule.positive_establishes_cross_engine_equivalence -and
    [bool]$d.zero_world_entry_gate.campaign_local_gates_plus_cep1_required -and
    [bool]$d.zero_world_entry_gate.exact_r23d22_invalid_closure_and_audit_binding_required -and
    [bool]$d.zero_world_entry_gate.nonzero_heading_aligned_receipt_regression_required_in_both_new_engines -and
    [bool]$d.zero_world_entry_gate.mujoco_successor_policy_restoration_binding_regression_required -and
    -not [bool]$d.zero_world_entry_gate.full_historical_cold_sweep_required_per_campaign -and
    -not [bool]$d.zero_world_entry_gate.physical_execution_authorized -and
    [int]$d.zero_world_entry_gate.world_attempt_count -eq 0 -and
    [int]$d.zero_world_entry_gate.world_build_count -eq 0
) "decision or zero-world boundary changed"

$closureOutput = & pwsh -NoLogo -NoProfile -File $closureAuditPath 2>&1 | Out-String
Assert-R23D23Declaration (
    $LASTEXITCODE -eq 0 -and
    $closureOutput.Contains("QSDK_R23D21_CLOSURE_PASS ", [StringComparison]::Ordinal)
) "immutable R23D21 closure audit failed: $closureOutput"

$invalidClosureOutput = & pwsh -NoLogo -NoProfile -File $invalidPredecessorAuditPath 2>&1 |
    Out-String
Assert-R23D23Declaration (
    $LASTEXITCODE -eq 0 -and
    $invalidClosureOutput.Contains(
        "QSDK_R23D22_CLOSURE_PASS ", [StringComparison]::Ordinal
    )
) "immutable R23D22 closure audit failed: $invalidClosureOutput"

Write-Host (
    "QSDK_R23D23_DECLARATION_PASS historical_cells=3 invalid_predecessors=1 new_cells=6 " +
    "composite_cells=9 engines=3 models=0 worlds=0 physical_authority=False"
)
