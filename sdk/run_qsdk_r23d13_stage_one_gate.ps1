#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))

$closureOutput = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
    Join-Path $repoRoot "tests\test_qsdk_r23d13_stage_zero_closure.ps1"
) 2>&1 | Out-String
if (
    $LASTEXITCODE -ne 0 -or
    -not $closureOutput.Contains("QSDK_R23D13_STAGE_ZERO_CLOSURE_PASS")
) {
    throw "QSDK-R23D13 immutable stage-zero closure failed: $closureOutput"
}

$arguments = @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repoRoot "tests\test_qsdk_r23d13_native_routes.ps1")
)
if ($SkipGodot) { $arguments += "-SkipGodot" }
$nativeOutput = & pwsh @arguments 2>&1 | Out-String
if (
    $LASTEXITCODE -ne 0 -or
    -not $nativeOutput.Contains("QSDK_R23D13_NATIVE_ROUTES_PASS")
) {
    throw "QSDK-R23D13 native-route audit failed: $nativeOutput"
}

$engineCount = 2 + [int](-not $SkipGodot)
Write-Host (
    "QSDK_R23D13_STAGE_ONE_GATE_PASS engines=$engineCount " +
    "godot=$(-not $SkipGodot) valid=$($engineCount * 10) " +
    "mutations=$($engineCount * 20) critical=$engineCount " +
    "positive_no_regression=$engineCount passive_zero=$engineCount " +
    "physical_refusals=$engineCount vectors_exact=True workers=0 models=0 " +
    "worlds=0 physical_authority=False turning=False equivalence=False"
)
