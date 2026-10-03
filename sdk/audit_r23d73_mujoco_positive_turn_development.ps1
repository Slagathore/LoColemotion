#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$turningRoot = Join-Path $sdkRoot "turning"
$pythonHost = if ([string]::IsNullOrWhiteSpace($Python)) {
    Join-Path $mujocoRoot ".venv\Scripts\python.exe"
} else {
    [IO.Path]::GetFullPath($Python)
}
$contractPath = Join-Path $turningRoot (
    "r23d73_mujoco_selected_profile_positive_turn_development_v1.json"
)
$implementationPath = Join-Path $turningRoot (
    "r23d73_mujoco_selected_profile_positive_turn_development_implementation_v1.json"
)
$workerPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\qsdk_r23d73_positive_turn_development.py"
)
$testPath = Join-Path $mujocoRoot "test_r23d73_positive_turn_development.py"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d73_supervisor.ps1"
$auditPath = $PSCommandPath
$r72ClosureAuditPath = Join-Path $sdkRoot (
    "audit_r23d72_mujoco_preturn_startup_development_closure.ps1"
)
$originParityAuditPath = Join-Path $sdkRoot (
    "audit_forward_displacement_measurement_origin_parity_v1.ps1"
)
$expectedRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore"
$expectedRemote = "https://github.com/Slagathore/sporespore.git"

function Assert-R23D73Audit([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "[turning/mujoco] R23D73 audit: $Message"
    }
}

function Get-R23D73AuditSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D73AuditProcess([string]$FileName, [string[]]$Arguments) {
    $lines = @(& $FileName @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    Assert-R23D73Audit ($exitCode -eq 0) (
        "$FileName failed with exit $exitCode`: $($lines -join ' ')"
    )
    return $lines
}

$top = [IO.Path]::GetFullPath((git -C $repoRoot rev-parse --show-toplevel).Trim())
$remote = (git -C $repoRoot remote get-url origin).Trim()
Assert-R23D73Audit ($LASTEXITCODE -eq 0) "repository identity could not be read"
Assert-R23D73Audit ($top -ceq $expectedRoot) "repository root mismatch: $top"
Assert-R23D73Audit ($remote -ceq $expectedRemote) "origin mismatch: $remote"

foreach ($path in @(
    $contractPath,
    $implementationPath,
    $workerPath,
    $testPath,
    $supervisorPath,
    $auditPath,
    $r72ClosureAuditPath,
    $originParityAuditPath,
    $pythonHost
)) {
    Assert-R23D73Audit (Test-Path -LiteralPath $path -PathType Leaf) (
        "required path missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$implementation = Get-Content -Raw -LiteralPath $implementationPath |
    ConvertFrom-Json -AsHashtable -Depth 100

Assert-R23D73Audit (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d73_mujoco_selected_profile_positive_turn_development_v1" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D73-MUJOCO-SELECTED-PROFILE-POSITIVE-TURN-DEVELOPMENT" -and
    [string]$contract.gate_id -ceq "QSDK-R23D73" -and
    [string]$contract.status -ceq "prospective_zero_world_only" -and
    [string]$contract.ledger_scope.subsystem -ceq "turning" -and
    [string]$contract.ledger_scope.engine_scope -ceq "mujoco" -and
    [string]$contract.ledger_scope.question_class -ceq "development" -and
    [bool]$contract.scientific_role.repeatable_calibration_or_training_work -and
    -not [bool]$contract.scientific_role.finite_decision -and
    -not [bool]$contract.scientific_role.equivalence_or_non_inferiority -and
    [bool]$contract.scientific_role.outcome_exposed_fixture -and
    -not [bool]$contract.scientific_role.population_inference_allowed -and
    [bool]$contract.scientific_role.turning_tested -and
    [int]$contract.fixture.campaign_seed -eq 23191 -and
    [string]$contract.fixture.arm_id -ceq "positive_heading" -and
    [string]$contract.intervention.startup_ramp_id -ceq
        "canonical_velocity_smoothstep_one_gait_cycle_v1" -and
    [int]$contract.intervention.startup_ramp_step_count -eq 360 -and
    -not [bool]$contract.intervention.support_loss_trigger_used -and
    -not [bool]$contract.intervention.partial_support_threshold_added -and
    [int]$contract.fixed_horizon.first_semantic_step -eq 0 -and
    [int]$contract.fixed_horizon.last_semantic_step -eq 2991 -and
    [int]$contract.fixed_horizon.controller_step_count -eq 2992 -and
    [int]$contract.fixed_horizon.reference_warmup_step_count -eq 600 -and
    [int]$contract.fixed_horizon.commanded_turn_step_count -eq 1200 -and
    [int]$contract.fixed_horizon.reference_recovery_step_count -eq 600 -and
    [int]$contract.fixed_horizon.after_declared_schedule_step_count -eq 592 -and
    [double]$contract.fixed_horizon.turn_heading_offset_rad -eq 0.2 -and
    [int]$contract.fixed_horizon.forward_displacement_measurement_origin_semantic_step -eq 472 -and
    [int]$contract.fixed_horizon.declared_physical_world_count -eq 1 -and
    [bool]$contract.development_gate.all_common_physical_gates_required -and
    [double]$contract.development_gate.common_physical_gates.minimum_final_forward_displacement_m -eq 0.030123046875 -and
    [double]$contract.development_gate.common_physical_gates.maximum_tilt_rad -eq 0.6 -and
    [double]$contract.development_gate.common_physical_gates.minimum_torso_height_m -eq 0.2499708652072946 -and
    [int]$contract.development_gate.common_physical_gates.minimum_contact_cycles_per_limb -eq 2 -and
    [int]$contract.development_gate.common_physical_gates.exact_controller_semantic_step_count -eq 2992 -and
    [int]$contract.development_gate.common_physical_gates.exact_validated_portable_command_count -eq 23936 -and
    [int]$contract.development_gate.common_physical_gates.exact_native_actuation_application_count -eq 23936 -and
    [double]$contract.development_gate.raw_signed_cycle_shift.minimum_rad -eq 0.01 -and
    -not [bool]$contract.development_gate.reference_conditioned_cycle_shift_evaluated -and
    -not [bool]$contract.development_gate.bilateral_directional_response_evaluated -and
    [int]$contract.zero_world_gate.negative_control_classes.Count -eq 5 -and
    [int]$contract.zero_world_gate.model_construction_count -eq 0 -and
    [int]$contract.zero_world_gate.world_attempt_count -eq 0 -and
    [int]$contract.zero_world_gate.world_build_count -eq 0 -and
    [int]$contract.zero_world_gate.solver_step_count -eq 0 -and
    [bool]$contract.authorization.clean_pushed_source_required -and
    [bool]$contract.authorization.global_physical_operation_lock_required -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    -not [bool]$contract.claims.turning_established -and
    -not [bool]$contract.claims.positive_heading_turning_cell_established -and
    -not [bool]$contract.claims.cross_engine_equivalence -and
    -not [bool]$contract.claims.release_readiness_score_changed -and
    -not [bool]$contract.claims.release_authorized
) "prospective contract semantics changed"

$expectedBindings = [ordered]@{
    "sdk/turning/r23d73_mujoco_selected_profile_positive_turn_development_v1.json" =
        Get-R23D73AuditSha256 $contractPath
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d73_positive_turn_development.py" =
        Get-R23D73AuditSha256 $workerPath
    "sdk/adapters/mujoco/test_r23d73_positive_turn_development.py" =
        Get-R23D73AuditSha256 $testPath
    "sdk/run_qsdk_r23d73_supervisor.ps1" = Get-R23D73AuditSha256 $supervisorPath
    "sdk/audit_r23d73_mujoco_positive_turn_development.ps1" =
        Get-R23D73AuditSha256 $auditPath
}
$observedBindings = @{}
foreach ($binding in @($implementation.source_bindings)) {
    $observedBindings[[string]$binding.path] = [string]$binding.raw_sha256
}
$bindingsExact = $observedBindings.Count -eq $expectedBindings.Count
foreach ($path in $expectedBindings.Keys) {
    $bindingsExact = $bindingsExact -and
        $observedBindings.ContainsKey($path) -and
        [string]$observedBindings[$path] -ceq [string]$expectedBindings[$path]
}
Assert-R23D73Audit (
    [string]$implementation.schema_version -ceq
        "sporespore_qsdk_r23d73_mujoco_selected_profile_positive_turn_development_implementation_v1" -and
    [string]$implementation.campaign_id -ceq [string]$contract.campaign_id -and
    [string]$implementation.gate_id -ceq "QSDK-R23D73" -and
    [string]$implementation.status -ceq
        "prospective_implemented_complete_zero_world_gate_passed_physical_not_opened" -and
    [string]$implementation.question_class -ceq "development" -and
    [bool]$implementation.outcome_exposed_fixture -and
    [int]$implementation.declared_physical_world_count -eq 1 -and
    [int]$implementation.zero_world.model_construction_count -eq 0 -and
    [int]$implementation.zero_world.world_attempt_count -eq 0 -and
    [int]$implementation.zero_world.world_build_count -eq 0 -and
    [int]$implementation.zero_world.solver_step_count -eq 0 -and
    [int]$implementation.zero_world.focused_test_count -eq 8 -and
    [int]$implementation.zero_world.negative_control_class_count -eq 5 -and
    -not [bool]$implementation.physical_campaign_opened -and
    [bool]$implementation.turning_tested -and
    -not [bool]$implementation.claims.turning_established -and
    -not [bool]$implementation.claims.cross_engine_equivalence -and
    -not [bool]$implementation.claims.release_readiness_score_changed -and
    -not [bool]$implementation.claims.release_authorized -and
    $bindingsExact
) "implementation authority or source bindings changed"

$workerText = Get-Content -Raw -LiteralPath $workerPath
$supervisorText = Get-Content -Raw -LiteralPath $supervisorPath
foreach ($required in @(
    "CONTROLLER_STEPS = 2_992",
    "LAST_SEMANTIC_STEP = 2_991",
    "TURN_DURATION_STEPS = TURN_END_STEP_EXCLUSIVE - TURN_START_STEP",
    "STARTUP_RAMP_ID = ramp_design.STARTUP_RAMP_ID",
    "support_loss_trigger_used",
    "EVIDENCE_ORIGIN_STEP",
    "commanded_turn_step_count=TURN_DURATION_STEPS",
    "turning_tested=True",
    "valid_complete_positive_turn_development",
    "valid_complete_negative_turn_development",
    "invalid_or_incomplete_positive_turn_development"
)) {
    Assert-R23D73Audit ($workerText.Contains($required)) (
        "worker lost required semantic: $required"
    )
}
foreach ($required in @(
    "Get-R23D73SourceIdentity -RequireCleanPushedLive",
    "Invoke-SporeSporeR23D3PinnedCargo",
    "Enter-SporeSporeLocomotionOperationLock",
    "authorization-preflight",
    "declared_world_count = 1",
    "one_shot_attempt_unconsumed = `$true",
    "retained_every_terminal_class = `$true"
)) {
    Assert-R23D73Audit ($supervisorText.Contains($required)) (
        "supervisor lost required gate: $required"
    )
}

$priorPythonPath = $env:PYTHONPATH
try {
    $env:PYTHONPATH = @(
        $mujocoRoot,
        (Join-Path $sdkRoot "python"),
        $turningRoot
    ) -join [IO.Path]::PathSeparator
    [void](Invoke-R23D73AuditProcess $pythonHost @(
        "-m", "unittest", "-q",
        "sdk.adapters.mujoco.test_r23d73_positive_turn_development"
    ))
} finally {
    $env:PYTHONPATH = $priorPythonPath
}

[void](Invoke-R23D73AuditProcess "pwsh" @(
    "-NoProfile", "-File", $supervisorPath, "-PreflightOnly", "-Python", $pythonHost
))
[void](Invoke-R23D73AuditProcess "pwsh" @(
    "-NoProfile", "-File", $r72ClosureAuditPath
))
[void](Invoke-R23D73AuditProcess "pwsh" @(
    "-NoProfile", "-File", $originParityAuditPath
))

Write-Output (
    "[turning/mujoco] R23D73 prospective audit PASS: " +
    "8 focused tests, 5 negative-control classes, R23D72/origin evidence exact, " +
    "0 models/worlds/solver steps, physical not opened"
)
