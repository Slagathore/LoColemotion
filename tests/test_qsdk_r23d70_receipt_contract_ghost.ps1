#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$python = "C:\Program Files\Python311\python.exe"
$godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
$powershell = "C:\Program Files\PowerShell\7\pwsh.exe"
$outputRoot = Join-Path (
    Join-Path $repoRoot "sdk\target\r23d70-receipt-contract-ghost"
) ([Guid]::NewGuid().ToString("N"))

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D70 RECEIPT GHOST: $Message" }
}

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository authority changed"

$pythonOutput = @(& $python (
    Join-Path $repoRoot "tests\test_qsdk_r23d70_receipt_contract_ghost.py"
) --output-root $outputRoot --powershell $powershell 2>&1 | ForEach-Object { [string]$_ })
Assert-Exact ($LASTEXITCODE -eq 0) "Python producer/MuJoCo ghost failed"
$pythonMarkers = @($pythonOutput | Where-Object {
    $_ -clike "QSDK_R23D70_PYTHON_RECEIPT_GHOST *"
})
Assert-Exact ($pythonMarkers.Count -eq 1) "Python ghost marker population changed"
$pythonReceipt = $pythonMarkers[0].Substring(
    "QSDK_R23D70_PYTHON_RECEIPT_GHOST ".Length
) | ConvertFrom-Json
$receiptPath = [IO.Path]::GetFullPath([string]$pythonReceipt.receipt_path)
Assert-Exact (
    [int]$pythonReceipt.published_trace_row_count -eq 2 -and
    [bool]$pythonReceipt.actual_cas_publisher_passed -and
    [bool]$pythonReceipt.producer_projection_passed -and
    [bool]$pythonReceipt.mujoco_consumer_positive_passed -and
    [int]$pythonReceipt.mujoco_negative_decision_count -eq 4 -and
    [int]$pythonReceipt.model_construction_count -eq 0 -and
    [int]$pythonReceipt.world_attempt_count -eq 0 -and
    [int]$pythonReceipt.world_build_count -eq 0 -and
    -not [bool]$pythonReceipt.physical_acceptance_authority -and
    (Test-Path -LiteralPath $receiptPath -PathType Leaf)
) "Python receipt semantics changed"

$godotOutput = @(& $godot --headless --path $repoRoot --script (
    Join-Path $repoRoot "tests\test_sdk_qsdk_r23d70_receipt_contract_ghost.gd"
) -- $receiptPath 2>&1 | ForEach-Object { [string]$_ })
Assert-Exact ($LASTEXITCODE -eq 0) "Godot consumer ghost failed"
$godotMarkers = @($godotOutput | Where-Object {
    $_ -clike "QSDK_R23D70_GODOT_RECEIPT_GHOST *"
})
Assert-Exact ($godotMarkers.Count -eq 1) "Godot ghost marker population changed"
$godotReceipt = $godotMarkers[0].Substring(
    "QSDK_R23D70_GODOT_RECEIPT_GHOST ".Length
) | ConvertFrom-Json
Assert-Exact (
    [bool]$godotReceipt.positive_passed -and
    [int]$godotReceipt.negative_decision_count -eq 4 -and
    [int]$godotReceipt.model_construction_count -eq 0 -and
    [int]$godotReceipt.world_attempt_count -eq 0 -and
    [int]$godotReceipt.world_build_count -eq 0 -and
    -not [bool]$godotReceipt.physical_acceptance_authority
) "Godot receipt semantics changed"

$priorReceiptPath = $env:SPORESPORE_R23D70_RECEIPT_GHOST_PATH
try {
    $env:SPORESPORE_R23D70_RECEIPT_GHOST_PATH = $receiptPath
    $rapierOutput = @(& cargo test --manifest-path (
        Join-Path $repoRoot "sdk\Cargo.toml"
    ) -p sporespore-rapier-adapter r23d70_receipt_contract_ghost -- --nocapture 2>&1 |
        ForEach-Object { [string]$_ })
} finally {
    $env:SPORESPORE_R23D70_RECEIPT_GHOST_PATH = $priorReceiptPath
}
Assert-Exact ($LASTEXITCODE -eq 0) "Rapier consumer ghost failed"
Assert-Exact (
    @($rapierOutput | Where-Object {
        $_ -clike "*QSDK_R23D70_RAPIER_RECEIPT_GHOST positive=true negative_decisions=4 models=0 worlds=0*"
    }).Count -eq 1
) "Rapier receipt marker changed"

$negativeDecisionCount =
    [int]$pythonReceipt.mujoco_negative_decision_count +
    [int]$godotReceipt.negative_decision_count + 4
Assert-Exact ($negativeDecisionCount -eq 12) "complete negative population changed"

Write-Host (
    "[turning/3e] PASS R23D70 receipt-contract ghost: producer=1 consumers=3 " +
    "rows=2 positive_surfaces=4 negative_decisions=12 models=0 worlds=0 " +
    "behavior_prediction=False"
)
