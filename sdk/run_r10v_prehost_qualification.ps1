#requires -Version 7.5
# Host controls must run outside the production no-breakaway job and main lock.
param()
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'run_development_interfaces.ps1') -Library
$prehostModule=Join-Path $PSScriptRoot 'conformance/r10v_prehost_qualification.py'
$begin=@(& $pythonPath -B $prehostModule --begin)
if ($LASTEXITCODE -ne 0 -or $begin.Count -ne 1) { throw 'R10V_PREHOST_BEGIN_REFUSED' }
$prehostRoot=($begin[0] | ConvertFrom-Json -AsHashtable).root
Write-Output ('R10V_PREHOST_ROOT '+$prehostRoot)
$contract=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'development/r10v_safety_stage_contract_v3.json') -Raw | ConvertFrom-Json -AsHashtable
$prehostCompleted=[Collections.Generic.List[object]]::new()
$previousRegistry=$env:SPORESPORE_R10V_PREHOST_ROOT
$env:SPORESPORE_R10V_PREHOST_ROOT=$prehostRoot
try {
    foreach ($spec in $contract.stages) {
        if ($spec.id -notin $contract.prehost_stage_ids) { continue }
        $selected=@{id=$spec.id;pattern=$spec.pattern;tests=[int]$spec.tests;timeout_seconds=[int]$contract.stage_timeout_overrides_seconds[$spec.id]}
        $receipt=Invoke-DevelopmentStage $selected $prehostRoot
        $prehostCompleted.Add($receipt)
        Write-Output ('R10V_PREHOST_STAGE '+(ConvertTo-SporeSporeExactJson -Value $receipt))
        if (-not $receipt.passed) { break }
    }
} finally {
    $env:SPORESPORE_R10V_PREHOST_ROOT=$previousRegistry
    Write-DevelopmentFile (Join-Path $prehostRoot 'stages.json') ([Text.Encoding]::UTF8.GetBytes((ConvertTo-SporeSporeExactJson -Value $prehostCompleted.ToArray())))
}
& $pythonPath -B $prehostModule --finish $prehostRoot
exit $LASTEXITCODE
