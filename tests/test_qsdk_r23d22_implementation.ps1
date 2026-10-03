#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$implementationPath = Join-Path $sdkRoot (
    "turning\r23d22_physical_implementation_contract_v1.json"
)
$declarationPath = Join-Path $sdkRoot (
    "turning\r23d22_reduced_yaw_transfer_preregistration_v1.json"
)
$rapierParentPath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced.rs"
)
$rapierWorkerPath = Join-Path $sdkRoot (
    "adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d22_physical.rs"
)
$mujocoWorkerPath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d22_physical.py"
)
$mujocoBasePath = Join-Path $sdkRoot (
    "adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d2_heading_response.py"
)
$tracePath = Join-Path $sdkRoot "turning\r23d22_physical_trace.py"
$evaluatorPath = Join-Path $sdkRoot "turning\r23d22_physical_evaluator.py"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d22_supervisor.ps1"
$closurePath = Join-Path $sdkRoot "turning\r23d22_physical_closure_v1.json"

function Assert-R23D22Implementation([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D22 implementation: $Message" }
}
function Get-R23D22ImplementationSha([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

foreach ($path in @(
    $implementationPath, $declarationPath, $rapierParentPath, $rapierWorkerPath,
    $mujocoWorkerPath, $mujocoBasePath, $tracePath, $evaluatorPath, $supervisorPath
)) {
    Assert-R23D22Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "required source missing: $path"
    )
}
Assert-R23D22Implementation (-not (Test-Path -LiteralPath $closurePath)) (
    "successor identity is already closed"
)

$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$declaration = Get-Content -Raw -LiteralPath $declarationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D22Implementation (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d22_physical_implementation_contract_v1" -and
    [string]$implementation.status -ceq
        "dormant_physical_implementation_zero_world_only_pending_clean_push_freeze" -and
    [string]$implementation.campaign_id -ceq [string]$declaration.campaign_id -and
    [string]$implementation.gate_id -ceq "QSDK-R23D22" -and
    [string]$implementation.preregistration_raw_sha256 -ceq
        (Get-R23D22ImplementationSha $declarationPath) -and
    [string]$implementation.lineage.predecessor_closure_raw_sha256 -ceq
        [string]$declaration.immutable_godot_lineage.closure_raw_sha256 -and
    [bool]$implementation.lineage.historical_godot_cells_are_bound_not_reexecuted
) "identity or lineage binding changed"

$controller = $implementation.controller_transfer
Assert-R23D22Implementation (
    [string]$controller.controller_policy_id -ceq
        "sporespore_balanced_wave_r23d21_reduced_yaw_authority_v1" -and
    [double]$controller.yaw_error_stride_gain_per_rad -eq 1.0 -and
    [string]$controller.cross_track_frame_mode_id -ceq
        "command_heading_aligned_task_frame_v1" -and
    [bool]$controller.rapier_exact_profile_canary_required -and
    [bool]$controller.mujoco_exact_profile_canary_required -and
    -not [bool]$controller.engine_specific_gait_logic_permitted -and
    -not [bool]$controller.controller_or_physics_change_from_r23d21_permitted
) "controller transfer contract changed"

$rapierParent = Get-Content -Raw -LiteralPath $rapierParentPath
$rapierWorker = Get-Content -Raw -LiteralPath $rapierWorkerPath
$mujocoWorker = Get-Content -Raw -LiteralPath $mujocoWorkerPath
$mujocoBase = Get-Content -Raw -LiteralPath $mujocoBasePath
$trace = Get-Content -Raw -LiteralPath $tracePath
$evaluator = Get-Content -Raw -LiteralPath $evaluatorPath
Assert-R23D22Implementation (
    $rapierParent.Contains("fn compile_boundary_for_policy(") -and
    $rapierParent.Contains("compile_boundary_for_policy(SELECTED_BALANCED_WAVE_POLICY_ID)") -and
    $rapierWorker.Contains("compile_boundary_for_policy(R23D22_CONTROLLER_POLICY_ID)") -and
    $rapierWorker.Contains("yaw_error_stride_gain_per_rad != 1.0") -and
    $rapierWorker.Contains("COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID") -and
    -not $rapierWorker.Contains("let (compiled, controller) = compile_boundary().map_err(&before_world)?")
) "Rapier exact policy plumbing changed"
Assert-R23D22Implementation (
    $mujocoBase.Contains("policy_id: str = POLICY_ID") -and
    $mujocoBase.Contains("balanced_wave_policy_profile(policy_id, descriptor)") -and
    $mujocoWorker.Contains("class _R23D22PolicyBoundBase") -and
    $mujocoWorker.Contains("policy_id=CONTROLLER_POLICY_ID") -and
    $mujocoWorker.Contains('controller_profile.get("yaw_error_stride_gain_per_rad") != 1.0') -and
    $mujocoWorker.Contains('controller_profile.get("cross_track_frame_mode_id")')
) "MuJoCo exact policy plumbing changed"
Assert-R23D22Implementation (
    $trace.Contains('MATRIX_ENGINES = ("rapier_parry", "mujoco")') -and
    $trace.Contains("CONTROLLER_POLICY_ID =") -and
    $evaluator.Contains("R23D21_CLOSURE_SHA256") -and
    $evaluator.Contains("same_engine_command_conditioned_response") -and
    $evaluator.Contains("conditioned_failure_count")
) "six-cell evaluator or historical binding changed"

$supervisor = $implementation.supervisor
Assert-R23D22Implementation (
    (@($supervisor.ordered_engine_ids) -join "|") -ceq "rapier_parry|mujoco" -and
    @($supervisor.ordered_matrix_cell_ids).Count -eq 6 -and
    [int]$supervisor.declared_world_count -eq 6 -and
    [bool]$supervisor.all_cells_serial_without_outcome_early_stop -and
    -not [bool]$supervisor.parallel_execution_permitted -and
    -not [bool]$supervisor.replacement_or_selective_rerun_permitted -and
    [bool]$supervisor.single_supervisor_attempt_required
) "supervisor matrix changed"

$workers = @($implementation.workers)
$dependencies = $implementation.dependency_closure
$union = @(
    @($dependencies.required_dependency_paths_by_worker.mujoco) +
    @($dependencies.required_dependency_paths_by_worker.rapier_parry) |
    Sort-Object -Unique -CaseSensitive
)
Assert-R23D22Implementation (
    $workers.Count -eq 2 -and
    (@($workers.engine_id) -join "|") -ceq "mujoco|rapier_parry" -and
    [int]$dependencies.declared_worker_count -eq 2 -and
    (@($dependencies.declared_worker_ids) -join "|") -ceq "mujoco|rapier_parry" -and
    $union.Count -eq 57 -and
    [int]$dependencies.declared_unique_dependency_count -eq $union.Count -and
    [int]$implementation.production_authorization_canaries.positive_canary_count -eq 2 -and
    [int]$implementation.terminal_marker_contract.declared_family_count -eq 2
) "worker, dependency, authorization, or marker count changed"

$sourcePaths = @($implementation.source_binding_policy.exact_paths)
Assert-R23D22Implementation (
    @($sourcePaths | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -eq 0
) "source-binding list has duplicates"
foreach ($path in $sourcePaths) {
    Assert-R23D22Implementation (
        Test-Path -LiteralPath (Join-Path $repoRoot ([string]$path)) -PathType Leaf
    ) "source binding is missing: $path"
}
foreach ($path in $union) {
    Assert-R23D22Implementation ($sourcePaths -ccontains $path) (
        "worker dependency is absent from source bindings: $path"
    )
}
Assert-R23D22Implementation (
    -not [bool]$implementation.authorization.physical_execution_authorized -and
    [int]$implementation.authorization.world_attempt_count -eq 0 -and
    [int]$implementation.authorization.world_build_count -eq 0 -and
    -not [bool]$implementation.claims.finite_three_engine_turning_candidate -and
    -not [bool]$implementation.claims.cross_engine_equivalence -and
    -not [bool]$implementation.claims.physical_acceptance_authority
) "zero-world or claim boundary changed"

Write-Host (
    "QSDK_R23D22_IMPLEMENTATION_PASS workers=2 identities=6 dependencies=57 " +
    "historical_godot_cells=3 policy_canaries=2 models=0 worlds=0 " +
    "physical_authority=False"
)
