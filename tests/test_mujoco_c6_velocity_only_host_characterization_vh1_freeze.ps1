#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$preregistrationPath = Join-Path (
    $sdkRoot
) "mujoco_c6_velocity_only_host_characterization_vh1_preregistration.json"
$implementationPath = Join-Path (
    $mujocoRoot
) "sporespore_mujoco_adapter\velocity_only_characterization.py"
$runnerPath = Join-Path (
    $sdkRoot
) "run_mujoco_c6_velocity_only_host_characterization_vh1.ps1"
$closurePath = Join-Path (
    $sdkRoot
) "mujoco_c6_velocity_only_host_characterization_vh1_closure.json"
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$expectedPreregistrationSha256 = (
    "0a4fad451f39987bbeaa0ed8fb5ae17d5dff76445ead28c89de7d5ff0cb611c5"
)
$expectedImplementationSha256 = (
    "f9805810f86b749d4d8a5d9bc37cd3440c3a6d5c5188b2e363e03256e644da29"
)
$expectedRunnerSha256 = (
    "600a483682ec8541c97b0d0287701b10f6264b2cb328d0b48e07f0c23610b534"
)
$expectedCellIds = @(
    "unloaded_vn075",
    "unloaded_vp075",
    "unloaded_vn225",
    "unloaded_vp225",
    "loaded_vn150_tn075",
    "loaded_vn150_tp075",
    "loaded_vn150_tn225",
    "loaded_vn150_tp225",
    "loaded_vp150_tn075",
    "loaded_vp150_tp075",
    "loaded_vp150_tn225",
    "loaded_vp150_tp225"
)

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "C6-MJC-HC-VH1 freeze audit ran outside SporeSpore"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "C6-MJC-HC-VH1 freeze audit origin mismatch"
foreach ($path in @($python, $preregistrationPath, $implementationPath, $runnerPath)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "C6-MJC-HC-VH1 freeze source missing: $path"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "C6-MJC-HC-VH1 prospective freeze cannot coexist with a closure"
Assert-Exact (
    @(Get-ChildItem -LiteralPath $evidenceRoot -Directory `
        -Filter "c6-mujoco-velocity-only-vh1-*" `
        -ErrorAction SilentlyContinue).Count -eq 0
) "C6-MJC-HC-VH1 evidence already exists; use a closure audit, not the freeze audit"
Assert-Exact (
    (Get-RawSha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationSha256 -and
    (Get-RawSha256 -Path $implementationPath) -ceq
        $expectedImplementationSha256 -and
    (Get-RawSha256 -Path $runnerPath) -ceq $expectedRunnerSha256
) "C6-MJC-HC-VH1 frozen source bytes changed"

$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$declaration.campaign_id -ceq
        "C6-MUJOCO-VELOCITY-ONLY-HOST-CHARACTERIZATION-VH1" -and
    [string]$declaration.gate_id -ceq "C6-MJC-HC-VH1" -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_mjc_hc_vh1_physics_world" -and
    [string]$declaration.study_class -ceq
        "exact_finite_cell_velocity_only_host_characterization" -and
    [string]$declaration.host_identity.engine_version -ceq "3.11.0" -and
    [string]$declaration.host_identity.python_version -ceq "3.11.9" -and
    [string]$declaration.host_identity.numpy_version -ceq "2.4.6" -and
    [int]$declaration.host_identity.solver_iterations -eq 20 -and
    [int]$declaration.host_identity.line_search_iterations -eq 7 -and
    [string]$declaration.motor_profile.profile_id -ceq
        "mujoco_velocity_servo_force_limited_v1" -and
    [string]$declaration.motor_profile.transmission_type -ceq "mjTRN_JOINT" -and
    [double]$declaration.motor_profile.velocity_gain_nm_s_per_rad -eq 10.0 -and
    [double]$declaration.motor_profile.maximum_force_nm -eq 6.0 -and
    [double]$declaration.motor_profile.
        maximum_declared_load_fraction_of_force_limit -eq 0.375 -and
    -not [bool]$declaration.motor_profile.native_position_target -and
    -not [bool]$declaration.motor_profile.independent_native_position_feedback -and
    [bool]$declaration.motor_profile.saturation_boundary.
        every_declared_physical_load_is_strictly_sub_limit -and
    -not [bool]$declaration.motor_profile.saturation_boundary.
        dynamic_force_saturation_response_characterized -and
    [int]$declaration.physical_grid.worlds -eq 12 -and
    [int]$declaration.physical_grid.replacement_worlds -eq 0 -and
    [bool]$declaration.physical_grid.early_stop_forbidden -and
    [bool]$declaration.preflight_contract.must_run_before_any_physics_world -and
    [bool]$declaration.preflight_contract.
        perfect_synthetic_serialization_round_trip_must_pass -and
    [int]$declaration.preflight_contract.world_build_count -eq 0 -and
    -not [bool]$declaration.preflight_contract.physics_state_modified -and
    [bool]$declaration.execution_contract.
        physical_execution_requires_global_locomotion_operation_lock -and
    [bool]$declaration.execution_contract.
        physical_execution_requires_exact_full_godot_v2_conformance_attestation -and
    -not [bool]$declaration.claim_boundary.dynamic_force_saturation_response -and
    -not [bool]$declaration.claim_boundary.mujoco_walking -and
    -not [bool]$declaration.claim_boundary.physical_acceptance_authority
) "C6-MJC-HC-VH1 declaration identity, grid, or claim boundary changed"

$cellIds = @($declaration.physical_grid.ordered_cells | ForEach-Object {
    [string]$_.cell_id
})
Assert-Exact (
    ($cellIds -join "|") -ceq ($expectedCellIds -join "|") -and
    @($cellIds | Sort-Object -Unique).Count -eq 12
) "C6-MJC-HC-VH1 declared cell order or cardinality changed"
Assert-Exact (
    @($declaration.host_source_semantics.installed_wheel_files).Count -eq 9 -and
    [string]$declaration.host_source_semantics.official_header_semantics.xanchor `
        -cmatch "world coordinates" -and
    [string]$declaration.host_source_semantics.observation_timing `
        -cmatch "separate MjData observation buffer"
) "C6-MJC-HC-VH1 installed-runtime or observation semantics changed"

$implementation = Get-Content -Raw -LiteralPath $implementationPath
$preflightMatch = [regex]::Match(
    $implementation,
    '(?s)def run_velocity_only_host_preflight\(\).*?(?=\ndef _model\()'
)
Assert-Exact (
    $preflightMatch.Success -and
    $preflightMatch.Value -notmatch 'MjModel|from_xml|_model\('
) "C6-MJC-HC-VH1 preflight acquired a physics-world constructor"
foreach ($requiredSourceWitness in @(
    '<velocity name="motor" joint="hinge" gear="1 0 0 0 0 0"',
    'observation = mujoco.MjData\(model\)',
    'mujoco.mj_forward\(model, observation\)',
    'observation.qfrc_actuator',
    'observation.qfrc_applied',
    'observation.xanchor',
    'DECLARED_ANCHOR_WORLD_M',
    'maximum_actuation_space_to_joint_space_force_error_nm',
    'evaluate_velocity_only_host_report\(report\)',
    'allow_nan=False'
)) {
    Assert-Exact (
        $implementation -match $requiredSourceWitness
    ) "C6-MJC-HC-VH1 implementation witness missing: $requiredSourceWitness"
}
Assert-Exact (
    $implementation -notmatch 'maximum_anchor_error_m'
) "C6-MJC-HC-VH1 revived the invalid generic anchor-error label"

Push-Location -LiteralPath $mujocoRoot
try {
    $preflightText = & $python `
        -m sporespore_mujoco_adapter.velocity_only_characterization `
        --preflight-only
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "C6-MJC-HC-VH1 direct zero-world preflight failed"
} finally {
    Pop-Location
}
$preflight = ($preflightText -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [bool]$preflight.ok -and
    [bool]$preflight.perfect_synthetic_result_passed -and
    [bool]$preflight.perfect_synthetic_serialization_round_trip_passed -and
    [int]$preflight.declared_cell_count -eq 12 -and
    [int]$preflight.negative_control_count -eq 10 -and
    @($preflight.negative_controls_rejected.Values | Where-Object {
        -not [bool]$_
    }).Count -eq 0 -and
    [int]$preflight.host_identity.verified_wheel_file_count -eq 9 -and
    [int]$preflight.host_identity.world_build_count -eq 0 -and
    [int]$preflight.world_build_count -eq 0 -and
    -not [bool]$preflight.physics_state_modified -and
    -not [bool]$preflight.physical_acceptance_authority
) "C6-MJC-HC-VH1 zero-world preflight receipt is invalid"

$runnerSource = Get-Content -Raw -LiteralPath $runnerPath
foreach ($guard in @(
    'Specify exactly one of -PreflightOnly or -RunPhysical',
    'prior evidence exists; same-identity rerun is forbidden',
    'Enter-SporeSporeLocomotionOperationLock -Role physical',
    'exact full-Godot V2 attestation',
    'HEAD == origin/main == live GitHub main',
    'physical_process_launch_consumes_identity',
    'FileMode]::CreateNew',
    'WindowStyle Hidden',
    'source changed after attempt reservation',
    'closure instead',
    'Close it without'
)) {
    Assert-Exact (
        $runnerSource.Contains($guard)
    ) "C6-MJC-HC-VH1 runner guard missing: $guard"
}

& $runnerPath -PreflightOnly
Assert-Exact (
    $LASTEXITCODE -eq 0
) "C6-MJC-HC-VH1 supervised zero-world preflight failed"

Write-Host (
    "C6_MJC_HC_VH1_FREEZE_PASS cells=12 negative_controls=10 " +
    "wheel_files=9 solver=20/7 worlds=0 native_position_feedback=False " +
    "saturation_dynamics=False physical_authority=False"
)
