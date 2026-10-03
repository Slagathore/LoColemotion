[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$testPath = Join-Path (
    $repoRoot
) "tests\test_sdk_policy_aware_physical_receipt_composition.gd"
$terminalMarker = (
    "POLICY_AWARE_PHYSICAL_RECEIPT_COMPOSITION_PASS " +
    "summaries=5 candidates=4 controls=1 historical_canaries=3 " +
    "mismatch_canaries=5 worlds=0 physical_authority=False"
)

if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable not found: $Godot"
}
if (-not (Test-Path -LiteralPath $testPath -PathType Leaf)) {
    throw "Policy-aware receipt-composition test not found: $testPath"
}

$output = (& $Godot `
    --headless `
    --path $repoRoot `
    --script res://tests/test_sdk_policy_aware_physical_receipt_composition.gd `
    2>&1 | Out-String)
$exitCode = $LASTEXITCODE
Write-Host $output.TrimEnd()
if (
    $exitCode -ne 0 -or
    [System.Text.RegularExpressions.Regex]::IsMatch(
        $output,
        '(?m)^ERROR:'
    ) -or
    -not $output.Contains($terminalMarker, [StringComparison]::Ordinal)
) {
    throw (
        "Policy-aware physical receipt-composition preflight failed " +
        "with exit code $exitCode"
    )
}
