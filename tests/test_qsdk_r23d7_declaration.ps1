[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$declarationPath = Join-Path $repoRoot "sdk\turning\r23d7_neutral_stance_preregistration_v1.json"
$designPath = Join-Path $repoRoot "sdk\turning\r23d7_neutral_stance.py"
$pythonTestPath = Join-Path $repoRoot "sdk\turning\test_r23d7_neutral_stance.py"
$closurePath = Join-Path $repoRoot "sdk\turning\r23d6_physical_closure_v1.json"

foreach ($path in @($declarationPath, $designPath, $pythonTestPath, $closurePath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "QSDK_R23D7_DECLARATION_MISSING:$path"
    }
}

$declaration = Get-Content -Raw -LiteralPath $declarationPath | ConvertFrom-Json -Depth 100
$closure = Get-Content -Raw -LiteralPath $closurePath | ConvertFrom-Json -Depth 100
$closureHash = "sha256:" + (Get-FileHash -Algorithm SHA256 -LiteralPath $closurePath).Hash.ToLowerInvariant()

if (
    $declaration.schema_version -ne "sporespore_qsdk_r23d7_neutral_stance_preregistration_v1" -or
    $declaration.status -ne "stage_zero_preregistered_neutral_stance_successor_no_workers_no_physical_authorization" -or
    $declaration.campaign_id -ne "QSDK-R23D7-NEUTRAL-STANCE-ACQUISITION-BILATERAL-TURN-DEVELOPMENT" -or
    $declaration.gate_id -ne "QSDK-R23D7" -or
    $declaration.release_gate_id -ne "QSDK-R23" -or
    $declaration.lineage.predecessor_status -ne $closure.status -or
    $declaration.lineage.predecessor_closure_raw_sha256 -ne $closureHash -or
    $declaration.lineage.predecessor_same_identity_rerun_allowed -ne $false -or
    $declaration.lineage.predecessor_scientific_negative -ne $true -or
    $declaration.scientifically_distinct_successor.predecessor_downward_endpoint_velocity_search_removed -ne $true -or
    $declaration.scientifically_distinct_successor.predecessor_per_contact_pose_capture_removed -ne $true -or
    $declaration.inherited_unchanged_scientific_contract.outcome_numeric_thresholds_changed -ne $false -or
    $declaration.inherited_unchanged_scientific_contract.stage_a_selector_changed -ne $false -or
    $declaration.frozen_schedule_and_gate_snapshot.turning_controller_semantic_step_count -ne 2992 -or
    $declaration.frozen_schedule_and_gate_snapshot.terminal_stance_step_count -ne 540 -or
    $declaration.frozen_schedule_and_gate_snapshot.maximum_four_contact_acquisition_steps -ne 180 -or
    $declaration.frozen_schedule_and_gate_snapshot.required_consecutive_all_four_contact_hold_steps -ne 360 -or
    $declaration.frozen_schedule_and_gate_snapshot.passive_settle_step_count -ne 240 -or
    $declaration.frozen_schedule_and_gate_snapshot.total_traced_step_count -ne 3772 -or
    $declaration.stage_a_mujoco_terminal_stance_screen.declared_world_count -ne 2 -or
    $declaration.stage_b_three_engine_confirmation.declared_world_count_if_launched -ne 9 -or
    $declaration.authorization.physical_execution_authorized -ne $false -or
    $declaration.authorization.worker_implementation_authorized -ne $true -or
    $declaration.claim_boundary.command_conditioned_turning -ne $false -or
    $declaration.claim_boundary.physical_acceptance_authority -ne $false
) {
    throw "QSDK_R23D7_DECLARATION_INVALID"
}

$python = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
    throw "QSDK_R23D7_PYTHON_MISSING:$python"
}

$env:PYTHONPATH = @(
    (Join-Path $repoRoot "sdk\turning"),
    (Join-Path $repoRoot "sdk\python"),
    (Join-Path $repoRoot "sdk\adapters\mujoco")
) -join [IO.Path]::PathSeparator

try {
    $unitOutput = & $python -m unittest -v $pythonTestPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK_R23D7_UNIT_FAILED:$($unitOutput -join [Environment]::NewLine)"
    }
    $preflightText = & $python $designPath 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK_R23D7_PREFLIGHT_FAILED:$($preflightText -join [Environment]::NewLine)"
    }
} finally {
    Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
}

$preflight = ($preflightText -join [Environment]::NewLine) | ConvertFrom-Json -Depth 100
if (
    $preflight.ok -ne $true -or
    $preflight.compiled_morphology_id -ne "qsdk_r05_generated_s169" -or
    $preflight.ordered_actuator_ids.Count -ne 8 -or
    $preflight.neutral_target_inside_all_joint_limits -ne $true -or
    $preflight.canary_count -ne 5 -or
    $preflight.mutation_control_count -ne 10 -or
    $preflight.neutral_target_activation_count -ne 8 -or
    $preflight.physics_adapter_start_count -ne 0 -or
    $preflight.physical_process_launch_count -ne 0 -or
    $preflight.model_construction_count -ne 0 -or
    $preflight.world_attempt_count -ne 0 -or
    $preflight.world_build_count -ne 0 -or
    $preflight.physical_execution_authorized -ne $false -or
    $preflight.physical_acceptance_authority -ne $false
) {
    throw "QSDK_R23D7_PREFLIGHT_INVALID"
}

Write-Output (
    "QSDK_R23D7_DECLARATION_PASS policy={0} canaries={1} mutations={2} actuators={3} worlds={4} physical_authority={5}" -f
    $declaration.neutral_stance_policy_contract.policy_id,
    $preflight.canary_count,
    $preflight.mutation_control_count,
    $preflight.neutral_target_activation_count,
    $preflight.world_attempt_count,
    $preflight.physical_acceptance_authority
)
