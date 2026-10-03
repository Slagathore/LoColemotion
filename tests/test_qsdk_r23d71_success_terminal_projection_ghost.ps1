#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$python = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
$godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
$projectorPath = Join-Path $repoRoot "sdk\locomotion_terminal_execution_projection.ps1"
$successSchema = "sporespore_qsdk_r23d71_engine_cell_report_v1"
$failureSchema = "sporespore_qsdk_r23d71_worker_failure_v1"
$forbiddenRootKeys = @(
    "world_attempt_count",
    "world_build_count",
    "world_build_count_exact",
    "world_build_count_lower_bound",
    "world_build_count_upper_bound"
)

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "QSDK-R23D71 SUCCESS TERMINAL GHOST: $Message"
    }
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $python -PathType Leaf) -and
    (Test-Path -LiteralPath $godot -PathType Leaf) -and
    (Test-Path -LiteralPath $projectorPath -PathType Leaf)
) "repository, Python, Godot, or shared projector authority changed"

. $projectorPath

$pythonOutput = @(& $python -B (
    Join-Path $repoRoot "tests\test_qsdk_r23d71_success_terminal_projection_ghost.py"
) 2>&1 | ForEach-Object { [string]$_ })
Assert-Exact ($LASTEXITCODE -eq 0) "MuJoCo producer ghost failed"
$pythonMarkers = @($pythonOutput | Where-Object {
    $_ -clike "QSDK_R23D71_MUJOCO_SUCCESS_TERMINAL_GHOST *"
})
Assert-Exact ($pythonMarkers.Count -eq 1) "MuJoCo marker population changed"
$mujocoReceipt = $pythonMarkers[0].Substring(
    "QSDK_R23D71_MUJOCO_SUCCESS_TERMINAL_GHOST ".Length
) | ConvertFrom-Json -AsHashtable

$godotOutput = @(& $godot --headless --path $repoRoot --script (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d71_success_terminal_projection_ghost.gd"
) 2>&1 | ForEach-Object { [string]$_ })
Assert-Exact ($LASTEXITCODE -eq 0) "Godot producer ghost failed"
$godotMarkers = @($godotOutput | Where-Object {
    $_ -clike "QSDK_R23D71_GODOT_SUCCESS_TERMINAL_GHOST *"
})
Assert-Exact ($godotMarkers.Count -eq 1) "Godot marker population changed"
$godotReceipt = $godotMarkers[0].Substring(
    "QSDK_R23D71_GODOT_SUCCESS_TERMINAL_GHOST ".Length
) | ConvertFrom-Json -AsHashtable

$priorTarget = $env:CARGO_TARGET_DIR
try {
    $env:CARGO_TARGET_DIR = Join-Path $repoRoot "sdk\target\r23d71-success-terminal-ghost"
    $rapierOutput = @(& cargo test --manifest-path (
        Join-Path $repoRoot "sdk\Cargo.toml"
    ) -p sporespore-rapier-adapter r23d71_success_terminal_projection_ghost `
        -- --nocapture 2>&1 | ForEach-Object { [string]$_ })
} finally {
    $env:CARGO_TARGET_DIR = $priorTarget
}
Assert-Exact ($LASTEXITCODE -eq 0) "Rapier producer ghost failed"
$rapierMarkers = @($rapierOutput | Where-Object {
    $_ -clike "*QSDK_R23D71_RAPIER_SUCCESS_TERMINAL_GHOST *"
})
Assert-Exact ($rapierMarkers.Count -eq 1) "Rapier marker population changed"
$rapierMarker = $rapierMarkers[0]
$rapierJson = $rapierMarker.Substring(
    $rapierMarker.IndexOf("QSDK_R23D71_RAPIER_SUCCESS_TERMINAL_GHOST ") +
        "QSDK_R23D71_RAPIER_SUCCESS_TERMINAL_GHOST ".Length
)
$rapierReceipt = [ordered]@{
    terminal = $rapierJson | ConvertFrom-Json -AsHashtable
    actual_producer_function = "normalize_terminal"
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_acceptance_authority = $false
}

$producerReceipts = [ordered]@{
    godot_jolt = $godotReceipt
    rapier_parry = $rapierReceipt
    mujoco = $mujocoReceipt
}
$positiveCount = 0
$negativeCount = 0
foreach ($engineId in $producerReceipts.Keys) {
    $receipt = $producerReceipts[$engineId]
    $terminal = $receipt.terminal
    Assert-Exact (
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_acceptance_authority -and
        [string]$terminal.schema_version -ceq $successSchema -and
        $terminal.execution -is [Collections.IDictionary] -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        -not $terminal.Contains("model_construction_count")
    ) "$engineId positive producer shape changed"
    foreach ($rootKey in $forbiddenRootKeys) {
        Assert-Exact (-not $terminal.Contains($rootKey)) (
            "$engineId retained forbidden positive root key $rootKey"
        )
    }
    $projection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $terminal `
        -SuccessSchemas @($successSchema) `
        -FailureSchemas @($failureSchema)
    Assert-Exact (
        [string]$projection.projection_source -ceq "execution" -and
        [int]$projection.world_attempt_count -eq 1 -and
        [int]$projection.world_build_count -eq 1 -and
        [bool]$projection.world_build_count_exact
    ) "$engineId actual shared projection changed"
    $positiveCount += 1

    foreach ($rootKey in $forbiddenRootKeys) {
        $mutation = [ordered]@{}
        foreach ($key in $terminal.Keys) { $mutation[$key] = $terminal[$key] }
        $mutation[$rootKey] = if ($rootKey -ceq "world_build_count_exact") {
            $true
        } else { 0 }
        $rejected = $false
        try {
            $null = Get-SporeSporeTerminalExecutionProjection `
                -Terminal $mutation `
                -SuccessSchemas @($successSchema) `
                -FailureSchemas @($failureSchema)
        } catch {
            $rejected = $_.Exception.Message -clike (
                "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID:*"
            )
        }
        Assert-Exact $rejected "$engineId mutation accepted: $rootKey"
        $negativeCount += 1
    }
}

Assert-Exact ($positiveCount -eq 3) "positive producer population changed"
Assert-Exact ($negativeCount -eq 15) "negative decision population changed"

Write-Host (
    "[turning/3e] PASS R23D71 success-terminal ghost: producers=3 " +
    "projector=1 positives=3 negatives=15 models=0 worlds=0 " +
    "behavior_prediction=False"
)
