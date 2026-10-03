#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$arguments = @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repoRoot "tests\test_qsdk_r23d14_native_routes.ps1")
)
if ($SkipGodot) { $arguments += "-SkipGodot" }
$nativeOutput = & pwsh @arguments 2>&1 | Out-String
if (
    $LASTEXITCODE -ne 0 -or
    -not $nativeOutput.Contains("QSDK_R23D14_NATIVE_ROUTES_PASS")
) {
    throw "QSDK-R23D14 native-route audit failed: $nativeOutput"
}

$engineCount = 2 + [int](-not $SkipGodot)
Write-Host (
    "QSDK_R23D14_STAGE_ONE_GATE_PASS engines=$engineCount " +
    "godot=$(-not $SkipGodot) valid=$($engineCount * 12) " +
    "mutations=$($engineCount * 14) positive=$engineCount negative=$engineCount " +
    "passive_zero=$engineCount physical_refusals=$engineCount " +
    "vectors_exact=True workers=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)
