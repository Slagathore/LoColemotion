#requires -Version 7.0

param([switch]$SkipGodot)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))

$closureOutput = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File (
    Join-Path $repoRoot "tests\test_qsdk_r23d12_stage_zero_closure.ps1"
) 2>&1 | Out-String
if (
    $LASTEXITCODE -ne 0 -or
    -not $closureOutput.Contains("QSDK_R23D12_STAGE_ZERO_CLOSURE_PASS")
) {
    throw "QSDK-R23D12 immutable stage-zero closure failed: $closureOutput"
}

$arguments = @(
    "-NoLogo", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File",
    (Join-Path $repoRoot "tests\test_qsdk_r23d12_native_semantics.ps1")
)
if ($SkipGodot) { $arguments += "-SkipGodot" }
$nativeOutput = & pwsh @arguments 2>&1 | Out-String
if (
    $LASTEXITCODE -ne 0 -or
    -not $nativeOutput.Contains("QSDK_R23D12_NATIVE_SEMANTICS_PASS")
) {
    throw "QSDK-R23D12 native-semantics audit failed: $nativeOutput"
}

$engineCount = 2 + [int](-not $SkipGodot)
Write-Host (
    "QSDK_R23D12_STAGE_ONE_GATE_PASS engines=$engineCount " +
    "godot=$(-not $SkipGodot) valid=$($engineCount * 7) " +
    "cross_product=$($engineCount * 6) mutations=$($engineCount * 14) " +
    "vectors_exact=True workers=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)
