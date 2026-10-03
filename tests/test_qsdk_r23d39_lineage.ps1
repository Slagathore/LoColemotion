#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$records = @(
    [ordered]@{
        name = "r23d31"
        path = "r23d31_cycle_integrated_directional_response_closure_v1.json"
        sha256 = "sha256:364f44e3a974d81e6b98073e02e4c46abf927cbabed933d0d1aae706e5890b4c"
        schema = "sporespore_qsdk_r23d31_cycle_integrated_directional_response_closure_v1"
        status = "closed_valid_complete_positive_measurement_validation_candidate"
        required_claim = "finite_rapier_cycle_integrated_measurement_validation"
    },
    [ordered]@{
        name = "r23d32"
        path = "r23d32_finite_rapier_turning_replication_closure_v1.json"
        sha256 = "sha256:40c7f4797916a5780d331f2676b2956875a35f28f79ef2043db30fef0eb09c93"
        schema = "sporespore_qsdk_r23d32_finite_rapier_turning_replication_closure_v1"
        status = "closed_valid_complete_positive_finite_rapier_turning_validation"
        required_claim = "finite_rapier_turning_validation"
    },
    [ordered]@{
        name = "r23d35"
        path = "r23d35_godot_trace_recovery_closure_v1.json"
        sha256 = "sha256:6f96ed00593ead67a118d1c07a6c54fb8f5892aa2599a121fd59c1f2efb6f148"
        schema = "sporespore_qsdk_r23d35_godot_trace_recovery_closure_v1"
        status = "closed_valid_complete_positive_finite_godot_jolt_r23d29_turning"
        required_claim = "finite_godot_jolt_turning"
    },
    [ordered]@{
        name = "r23d38"
        path = "r23d38_mujoco_startup_ramp_stabilization_closure_v1.json"
        sha256 = "sha256:e6a0a965a5b07f70ee7e080315b43157fa6e5c5129c09c94cdee8af27faeeef5"
        schema = "sporespore_qsdk_r23d38_mujoco_startup_ramp_stabilization_closure_v1"
        status = "closed_consumed_valid_complete_positive_startup_ramp_stabilization"
        required_claim = "finite_mujoco_r23d29_seed_21507_startup_ramp_walking"
    }
)

function Assert-R23D39Lineage([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D39 LINEAGE: $Message" }
}

function Get-R23D39Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

Assert-R23D39Lineage (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace('/', '\') -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

foreach ($record in $records) {
    $path = Join-Path $turningRoot ([string]$record.path)
    Assert-R23D39Lineage (
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-R23D39Sha256 $path) -ceq [string]$record.sha256
    ) "closure bytes changed: $($record.name)"
    $closure = Get-Content -Raw -LiteralPath $path | ConvertFrom-Json -Depth 100
    $claimName = [string]$record.required_claim
    Assert-R23D39Lineage (
        [string]$closure.schema_version -ceq [string]$record.schema -and
        [string]$closure.status -ceq [string]$record.status -and
        [bool]$closure.identity_consumed -and
        -not [bool]$closure.same_identity_rerun_allowed -and
        [bool]$closure.claims.$claimName -and
        -not [bool]$closure.claims.cross_engine_equivalence -and
        -not [bool]$closure.claims.release_authorized
    ) "closure claim boundary changed: $($record.name)"
}

$r38 = Get-Content -Raw -LiteralPath (
    Join-Path $turningRoot "r23d38_mujoco_startup_ramp_stabilization_closure_v1.json"
) | ConvertFrom-Json -Depth 100
Assert-R23D39Lineage (
    [string]$r38.official_result.classification -ceq
        "valid_complete_positive_startup_ramp_stabilization" -and
    [bool]$r38.official_result.execution_valid -and
    [bool]$r38.official_result.common_physical_gate_passed -and
    [bool]$r38.official_result.scientific_selector_legally_completed -and
    [bool]$r38.official_result.outcome_exposed_development_screen -and
    -not [bool]$r38.official_result.fresh_held_out_condition_consumed -and
    -not [bool]$r38.official_result.turning_tested -and
    [double]$r38.measurements.final_forward_displacement_m -eq
        1.6546781589105957 -and
    [double]$r38.measurements.maximum_tilt_rad -eq
        0.07943305657545596
) "R23D38 accepted startup-ramp result changed"

$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$savedPythonPath = $env:PYTHONPATH
$savedLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = (@(
        (Join-Path $sdkRoot "python"),
        $mujocoRoot,
        (Join-Path $mujocoRoot ".venv\Lib\site-packages"),
        $turningRoot
    ) -join [IO.Path]::PathSeparator)
    $env:SPORESPORE_LOCOMOTION_LIBRARY = Join-Path (
        $sdkRoot
    ) "target\debug\sporespore_locomotion_core.dll"
    $refusal = @(
        & python -m `
            sporespore_mujoco_adapter.qsdk_r23d38_startup_ramp_stabilization `
            preflight --stage "mujoco_r23d29_startup_ramp_stabilization" `
            --onset "onset_600" --arm "reference_zero" 2>&1
    ) | Out-String
    $refusalExitCode = $LASTEXITCODE
} finally {
    $env:PYTHONPATH = $savedPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $savedLibrary
}
Assert-R23D39Lineage (
    $refusalExitCode -ne 0 -and
    $refusal.Contains('"failure_code":"QSDK_R23D38_MJC_CLOSED"')
) "closed R23D38 worker refusal changed: $refusal"

Write-Host (
    "QSDK_R23D39_LINEAGE_PASS closures=4 r38_walking=True " +
    "rapier_turning=True godot_turning=True cross_engine=False worlds=0"
)
