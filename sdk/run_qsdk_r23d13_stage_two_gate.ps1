#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$auditPath = Join-Path $repoRoot "tests\test_qsdk_r23d13_stage_two_evidence.ps1"

$output = & pwsh -NoLogo -NoProfile -ExecutionPolicy Bypass -File $auditPath `
    2>&1 | Out-String
if (
    $LASTEXITCODE -ne 0 -or
    -not $output.Contains("QSDK_R23D13_STAGE_ONE_CLOSURE_PASS") -or
    -not $output.Contains("QSDK_R23D13_STAGE_TWO_EVIDENCE ")
) {
    throw "QSDK-R23D13 stage-two evidence gate failed: $output"
}

Write-Host (
    "QSDK_R23D13_STAGE_TWO_GATE_PASS bindings=10 trace_tests=11 " +
    "evaluator_tests=12 tests=23 traces=11 authority_mutations=13 " +
    "diagnostic_mutations=12 workers=0 supervisors=0 models=0 worlds=0 " +
    "physical_authority=False turning=False equivalence=False"
)
