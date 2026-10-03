#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$pythonRoot = Join-Path $sdkRoot "python"
$turningRoot = Join-Path $sdkRoot "turning"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$library = Join-Path $sdkRoot "target\release\sporespore_locomotion_core.dll"
$manifest = Join-Path $sdkRoot "Cargo.toml"
$audit = Join-Path `
    $repoRoot "tests\test_qsdk_r23d23_postclosure_forward_receipt_compatibility.ps1"
$closureAudit = Join-Path $repoRoot "tests\test_qsdk_r23d23_closure.ps1"

function Assert-R23D23D1([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D23-D1 gate: $Message" }
}

foreach ($path in @(
    $python,
    $manifest,
    $audit,
    $closureAudit,
    (Join-Path $mujocoRoot (
        "sporespore_mujoco_adapter\" +
        "qsdk_r23d23_postclosure_forward_receipt_compatibility.py"
    )),
    (Join-Path $mujocoRoot (
        "test_qsdk_r23d23_postclosure_forward_receipt_compatibility.py"
    ))
)) {
    Assert-R23D23D1 (Test-Path -LiteralPath $path -PathType Leaf) (
        "required input missing: $path"
    )
}
Assert-R23D23D1 (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/") -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"

$evidenceRoot = Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
$attemptRootsBefore = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "qsdk-r23d2*" }
).Count

& cargo build --quiet --release --locked --offline `
    --manifest-path $manifest --package sporespore-locomotion-core
Assert-R23D23D1 ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $library)) (
    "portable core build failed"
)

$oldLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
$oldPythonPath = $env:PYTHONPATH
try {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $library
    $env:PYTHONPATH = (
        $mujocoRoot + [IO.Path]::PathSeparator +
        $pythonRoot + [IO.Path]::PathSeparator +
        $turningRoot
    )
    $unitOutput = & $python -m unittest -v `
        test_qsdk_r23d8_neutral_stance_composition `
        test_qsdk_r23d23_physical `
        test_qsdk_r23d23_postclosure_forward_receipt_compatibility `
        2>&1 | Out-String
    $unitExit = $LASTEXITCODE
} finally {
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $oldLibrary
    $env:PYTHONPATH = $oldPythonPath
}
Assert-R23D23D1 ($unitExit -eq 0) "unit tests failed: $unitOutput"

$auditOutput = & pwsh -NoLogo -NoProfile -File $audit 2>&1 | Out-String
$auditExit = $LASTEXITCODE
$closureOutput = & pwsh -NoLogo -NoProfile -File $closureAudit 2>&1 | Out-String
$closureExit = $LASTEXITCODE
$global:LASTEXITCODE = 0
Assert-R23D23D1 (
    $auditExit -eq 0 -and
    $auditOutput.Contains("QSDK_R23D23_POSTCLOSURE_FORWARD_RECEIPT_D1_PASS")
) "post-closure audit failed: $auditOutput"
Assert-R23D23D1 (
    $closureExit -eq 0 -and
    $closureOutput.Contains("QSDK_R23D23_CLOSURE_PASS")
) "immutable R23D23 closure regressed: $closureOutput"

$attemptRootsAfter = @(
    Get-ChildItem -LiteralPath $evidenceRoot `
        -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "qsdk-r23d2*" }
).Count
Assert-R23D23D1 ($attemptRootsAfter -eq $attemptRootsBefore) (
    "zero-world gate created a physical attempt root"
)

Write-Host (
    "QSDK_R23D23_POSTCLOSURE_FORWARD_RECEIPT_ZERO_WORLD_PASS " +
    "unit_tests=10 real_arms=3 mutations=22 retained_cells=6 " +
    "models=0 worlds=0 physical=False turning=False release=False"
)
