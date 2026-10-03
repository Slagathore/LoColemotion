#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "",
    [string]$Cargo = ""
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$mujocoPython = Join-Path $repoRoot "sdk\adapters\mujoco\.venv\Scripts\python.exe"
$pythonHost = if ([string]::IsNullOrWhiteSpace($Python)) { $mujocoPython } else { $Python }
$cargoHost = if ([string]::IsNullOrWhiteSpace($Cargo)) {
    (Get-Command cargo -ErrorAction Stop).Source
} else { $Cargo }
$projectorPath = Join-Path $repoRoot "sdk\locomotion_terminal_execution_projection.ps1"
$successSchema = "sporespore_qsdk_r23d74_engine_cell_report_v1"
$failureSchema = "sporespore_qsdk_r23d74_worker_failure_v1"
$forbiddenRootKeys = @(
    "world_attempt_count",
    "world_build_count",
    "world_build_count_exact",
    "world_build_count_lower_bound",
    "world_build_count_upper_bound"
)

function Assert-R23D74Ghost([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D74 SUCCESS TERMINAL GHOST: $Message" }
}

Assert-R23D74Ghost (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    (Test-Path -LiteralPath $pythonHost -PathType Leaf) -and
    (Test-Path -LiteralPath $Godot -PathType Leaf) -and
    (Test-Path -LiteralPath $cargoHost -PathType Leaf) -and
    (Test-Path -LiteralPath $projectorPath -PathType Leaf)
) "repository or runtime authority changed"
. $projectorPath

$pythonOutput = @(& $pythonHost -B (
    Join-Path $repoRoot "tests\test_qsdk_r23d74_success_terminal_projection_ghost.py"
) 2>&1 | ForEach-Object { [string]$_ })
Assert-R23D74Ghost ($LASTEXITCODE -eq 0) "MuJoCo producer ghost failed: $($pythonOutput -join ' ')"
$pythonPrefix = "QSDK_R23D74_MUJOCO_SUCCESS_TERMINAL_GHOST "
$pythonMarkers = @($pythonOutput | Where-Object { $_.StartsWith($pythonPrefix) })
Assert-R23D74Ghost ($pythonMarkers.Count -eq 1) "MuJoCo marker population changed"
$mujocoReceipt = $pythonMarkers[0].Substring($pythonPrefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100

$godotOutput = @(& $Godot --headless --path $repoRoot --script (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d74_success_terminal_projection_ghost.gd"
) 2>&1 | ForEach-Object { [string]$_ })
Assert-R23D74Ghost ($LASTEXITCODE -eq 0) "Godot producer ghost failed: $($godotOutput -join ' ')"
$godotPrefix = "QSDK_R23D74_GODOT_SUCCESS_TERMINAL_GHOST "
$godotMarkers = @($godotOutput | Where-Object { $_.StartsWith($godotPrefix) })
Assert-R23D74Ghost ($godotMarkers.Count -eq 1) "Godot marker population changed"
$godotReceipt = $godotMarkers[0].Substring($godotPrefix.Length) |
    ConvertFrom-Json -AsHashtable -Depth 100

$rapierOutput = @(& $cargoHost test --quiet --manifest-path (
    Join-Path $repoRoot "sdk\Cargo.toml"
) -p sporespore-rapier-adapter r23d74_success_terminal_projection_ghost `
    -- --nocapture 2>&1 | ForEach-Object { [string]$_ })
Assert-R23D74Ghost ($LASTEXITCODE -eq 0) "Rapier producer ghost failed: $($rapierOutput -join ' ')"
$rapierPrefix = "QSDK_R23D74_RAPIER_SUCCESS_TERMINAL_GHOST "
$rapierMarkers = @($rapierOutput | Where-Object { $_.Contains($rapierPrefix) })
Assert-R23D74Ghost ($rapierMarkers.Count -eq 1) "Rapier marker population changed"
$rapierLine = [string]$rapierMarkers[0]
$rapierTerminal = $rapierLine.Substring(
    $rapierLine.IndexOf($rapierPrefix, [StringComparison]::Ordinal) + $rapierPrefix.Length
) | ConvertFrom-Json -AsHashtable -Depth 100
$rapierReceipt = [ordered]@{
    terminal = $rapierTerminal
    actual_producer_function = "normalize_terminal"
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_acceptance_authority = $false
}

$receipts = [ordered]@{
    godot_jolt = $godotReceipt
    rapier_parry = $rapierReceipt
    mujoco = $mujocoReceipt
}
$positiveCount = 0
$negativeCount = 0
foreach ($engineId in $receipts.Keys) {
    $receipt = $receipts[$engineId]
    $terminal = $receipt.terminal
    Assert-R23D74Ghost (
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physical_acceptance_authority -and
        [string]$terminal.schema_version -ceq $successSchema -and
        [string]$terminal.question_class -ceq "finite_decision" -and
        [int]$terminal.execution.world_attempt_count -eq 1 -and
        [int]$terminal.execution.world_build_count -eq 1 -and
        -not $terminal.Contains("model_construction_count")
    ) "$engineId positive producer shape changed"
    foreach ($rootKey in $forbiddenRootKeys) {
        Assert-R23D74Ghost (-not $terminal.Contains($rootKey)) (
            "$engineId retained forbidden positive root key $rootKey"
        )
    }
    $projection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $terminal -SuccessSchemas @($successSchema) `
        -FailureSchemas @($failureSchema)
    Assert-R23D74Ghost (
        [string]$projection.projection_source -ceq "execution" -and
        [int]$projection.world_attempt_count -eq 1 -and
        [int]$projection.world_build_count -eq 1 -and
        [bool]$projection.world_build_count_exact
    ) "$engineId shared projection changed"
    $positiveCount += 1
    foreach ($rootKey in $forbiddenRootKeys) {
        $mutation = [ordered]@{}
        foreach ($key in $terminal.Keys) { $mutation[$key] = $terminal[$key] }
        $mutation[$rootKey] = if ($rootKey -ceq "world_build_count_exact") { $true } else { 0 }
        $rejected = $false
        try {
            $null = Get-SporeSporeTerminalExecutionProjection `
                -Terminal $mutation -SuccessSchemas @($successSchema) `
                -FailureSchemas @($failureSchema)
        } catch {
            $rejected = $_.Exception.Message -clike (
                "TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID:*"
            )
        }
        Assert-R23D74Ghost $rejected "$engineId mutation accepted: $rootKey"
        $negativeCount += 1
    }
}
Assert-R23D74Ghost ($positiveCount -eq 3 -and $negativeCount -eq 15) (
    "producer or mutation population changed"
)
Write-Output (
    "[turning/3e] PASS R23D74 success-terminal ghost: producers=3 " +
    "projector=1 positives=3 negatives=15 models=0 worlds=0 prediction=False"
)
