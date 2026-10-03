#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$auditPath = Join-Path $repoRoot "tests\test_qsdk_r23d13_declaration.ps1"

$output = @(
    & pwsh `
        -NoLogo `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $auditPath `
        -Python $Python 2>&1
) -join "`n"
if ($LASTEXITCODE -ne 0 -or -not $output.Contains("QSDK_R23D13_DECLARATION_PASS")) {
    throw "QSDK-R23D13 stage-zero declaration audit failed: $output"
}
$global:LASTEXITCODE = 0

Write-Host (
    "QSDK_R23D13_STAGE_ZERO_GATE_PASS canaries=10 mutations=20 gains=0 " +
    "native_routes=0 workers=0 physical_processes=0 models=0 worlds=0 " +
    "turning=False equivalence=False physical_authority=False"
)
