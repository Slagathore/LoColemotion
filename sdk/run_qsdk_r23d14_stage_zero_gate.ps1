#requires -Version 7.0

[CmdletBinding()]
param([string]$Python = "python")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$auditPath = Join-Path $repoRoot "tests\test_qsdk_r23d14_declaration.ps1"

$output = @(
    & pwsh -NoLogo -NoProfile -File $auditPath -Python $Python 2>&1
) -join "`n"
if (
    $LASTEXITCODE -ne 0 -or
    -not $output.Contains("QSDK_R23D14_DECLARATION_PASS")
) {
    throw "QSDK-R23D14 stage-zero declaration audit failed: $output"
}
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D14_STAGE_ZERO_GATE_PASS canaries=12 mutations=14 gains=0 " +
    "development_worlds=2 confirmation_cells=9 native_routes=0 workers=0 " +
    "physical_processes=0 models=0 worlds=0 turning=False " +
    "equivalence=False physical_authority=False"
)
