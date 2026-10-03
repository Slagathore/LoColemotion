#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$godot = (
    "C:\Users\Cole\CodeStuff\Misc\Godot\" +
    "Godot_v4.7-stable_mono_win64_console.exe"
)
$mujocoPython = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
$godotGhost = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d69_complete_row_ghost.gd"
$mujocoGhost = Join-Path $repoRoot "tests\test_qsdk_r23d69_mujoco_complete_row_ghost.py"
$godotWorker = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d69_godot_jolt_worker.gd"
$rapierProducer = Join-Path $repoRoot (
    "sdk\adapters\rapier\src\qsdk_r23d3_phase_balanced\r23d27_physical.rs"
)
$rapierWorker = Join-Path $repoRoot "sdk\adapters\rapier\src\qsdk_r23d69_turning_route.rs"
$mujocoProducer = Join-Path $repoRoot (
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\" +
    "qsdk_r23d65_selected_profile_turning.py"
)
$mujocoWorker = Join-Path $repoRoot (
    "sdk\adapters\mujoco\sporespore_mujoco_adapter\qsdk_r23d69_turning_route.py"
)

function Assert-R23D69Rows([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D69 COMPLETE ROWS: $Message" }
}

function Get-R23D69Marker($Lines, [string]$Prefix) {
    $matches = @($Lines | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D69Rows ($matches.Count -eq 1) (
        "expected one '$Prefix' marker; output=$(@($Lines) -join ' ')"
    )
    return ([string]$matches[0]).Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    $godot,
    $mujocoPython,
    $godotGhost,
    $mujocoGhost,
    $godotWorker,
    $rapierProducer,
    $rapierWorker,
    $mujocoProducer,
    $mujocoWorker
)) {
    Assert-R23D69Rows (Test-Path -LiteralPath $path -PathType Leaf) "missing path: $path"
}

$godotWorkerSource = Get-Content -LiteralPath $godotWorker -Raw
$rapierProducerSource = Get-Content -LiteralPath $rapierProducer -Raw
$rapierWorkerSource = Get-Content -LiteralPath $rapierWorker -Raw
$mujocoProducerSource = Get-Content -LiteralPath $mujocoProducer -Raw
$mujocoWorkerSource = Get-Content -LiteralPath $mujocoWorker -Raw
Assert-R23D69Rows (
    $godotWorkerSource.Contains(
        'trace_options["actuator_phase_observation_schema_version"]'
    ) -and
    $godotWorkerSource.Contains(
        'static func _r23d69_project_complete_trace_row('
    ) -and
    $godotWorkerSource.Contains(
        'var observation := R23D69WaveGaitScript.validate_sdk_actuator_phase_observation(row)'
    )
) "Godot physical route is not bound to the complete-row repair"
Assert-R23D69Rows (
    $rapierProducerSource.Contains(
        'pub(crate) fn r23d69_project_production_trace_row('
    ) -and
    $rapierProducerSource.Contains(
        'r23d69_trace_row(trace_row, semantic_step, &cell)'
    ) -and
    $rapierWorkerSource.Contains(
        'run_qsdk_r23d69_rapier_complete_row_ghost'
    )
) "Rapier ghost and physical route do not share the row projection"
Assert-R23D69Rows (
    $mujocoProducerSource.Contains('def _native_json_bool(value: Any) -> bool:') -and
    $mujocoProducerSource.Contains(
        'application["target_velocity_readback_matches"] = _native_json_bool('
    ) -and
    $mujocoWorkerSource.Contains('def _project_failure_terminal(') -and
    $mujocoWorkerSource.Contains('value = _project_failure_terminal(error, arguments)')
) "MuJoCo native boolean or failure projection repair is not on the physical route"

$godotOutput = @(& $godot --headless --path $repoRoot `
    --script res://tests/test_sdk_qsdk_r23d69_complete_row_ghost.gd 2>&1)
Assert-R23D69Rows ($LASTEXITCODE -eq 0) "Godot ghost failed: $($godotOutput -join ' ')"
$godotReceipt = Get-R23D69Marker $godotOutput "QSDK_R23D69_GODOT_COMPLETE_ROW_GHOST "
Assert-R23D69Rows (
    [bool]$godotReceipt.ok -and
    [int]$godotReceipt.representative_complete_row_count -eq 7 -and
    [bool]$godotReceipt.actual_shared_row_composer_used -and
    [bool]$godotReceipt.actual_production_projection_used -and
    [bool]$godotReceipt.actuator_phase_observation_validated_per_row -and
    [int]$godotReceipt.strict_json_round_trip_count -eq 7 -and
    [int]$godotReceipt.model_construction_count -eq 0 -and
    [int]$godotReceipt.world_attempt_count -eq 0 -and
    [int]$godotReceipt.world_build_count -eq 0 -and
    -not [bool]$godotReceipt.physical_acceptance_authority
) "Godot complete-row receipt changed"

$prior = Get-Location
try {
    Set-Location -LiteralPath $repoRoot
    $rapierOutput = @(& cargo test --manifest-path sdk/Cargo.toml `
        -p sporespore-rapier-adapter `
        compact_complete_rows_use_the_physical_projection -- --nocapture 2>&1)
    $rapierExit = $LASTEXITCODE
} finally {
    Set-Location -LiteralPath $prior.Path
}
Assert-R23D69Rows ($rapierExit -eq 0) "Rapier row ghost failed: $($rapierOutput -join ' ')"
Assert-R23D69Rows (
    (@($rapierOutput | Where-Object {
        [string]$_ -cmatch 'test .*compact_complete_rows_use_the_physical_projection.* ok'
    })).Count -eq 1
) "Rapier row ghost test population changed"

$mujocoOutput = @(& $mujocoPython $mujocoGhost 2>&1)
Assert-R23D69Rows ($LASTEXITCODE -eq 0) "MuJoCo ghost failed: $($mujocoOutput -join ' ')"
$mujocoReceipt = Get-R23D69Marker $mujocoOutput "QSDK_R23D69_MUJOCO_COMPLETE_ROW_GHOST "
Assert-R23D69Rows (
    [bool]$mujocoReceipt.ok -and
    [int]$mujocoReceipt.representative_complete_row_count -eq 7 -and
    [bool]$mujocoReceipt.actual_native_row_composer_used -and
    [bool]$mujocoReceipt.actual_native_boolean_projection_used -and
    [int]$mujocoReceipt.strict_json_allow_nan_false_count -eq 9 -and
    [int]$mujocoReceipt.failure_projection_case_count -eq 2 -and
    [bool]$mujocoReceipt.inner_failure_stage_and_counts_preserved -and
    [int]$mujocoReceipt.model_construction_count -eq 0 -and
    [int]$mujocoReceipt.world_attempt_count -eq 0 -and
    [int]$mujocoReceipt.world_build_count -eq 0 -and
    -not [bool]$mujocoReceipt.physical_acceptance_authority
) "MuJoCo complete-row receipt changed"

Write-Output (
    "[turning/3e] PASS R23D69 compact complete-production-row ghosts: " +
    "rows=21 boundaries=7 engines=3 failure_projections=2 models=0 worlds=0 " +
    "behavior_prediction=False"
)
