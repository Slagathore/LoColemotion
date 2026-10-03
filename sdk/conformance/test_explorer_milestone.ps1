[CmdletBinding()]
param([Parameter(Mandatory)][string]$Output)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$sdk=Split-Path $PSScriptRoot -Parent
if (Test-Path -LiteralPath $Output) { throw 'Use a fresh durable output directory' }
[void][IO.Directory]::CreateDirectory($Output)
$mapping=Join-Path $sdk 'release/quadruped_sdk1_milestone_mapping_v1.json'
$compiler=Join-Path $sdk 'compile_quadruped_sdk1_milestone_readiness.ps1'
$passed=[Collections.Generic.List[string]]::new()
foreach ($case in @('positive','closure_hash','auditor_hash','historical_missing')) {
    $value=Get-Content -Raw -LiteralPath $mapping | ConvertFrom-Json -Depth 100
    $m20=@($value.sdk1_contract.milestones | Where-Object milestone_id -EQ 'SDK1-M20')[0]
    $expected='passed'
    if ($case -eq 'closure_hash') { $m20.source.proof.raw_sha256='sha256:'+('0'*64); $expected='invalid_proof' }
    if ($case -eq 'auditor_hash') { $m20.source.proof.auditor_raw_sha256='sha256:'+('0'*64); $expected='invalid_proof' }
    if ($case -eq 'historical_missing') { $m20.source.proof=[pscustomobject]@{kind='missing';reason='Declared missing historical Explorer proof'}; $expected='missing' }
    $inputPath=Join-Path $Output ($case+'-mapping.json')
    $reportPath=Join-Path $Output ($case+'-report.json')
    [IO.File]::WriteAllText($inputPath,($value | ConvertTo-Json -Depth 100),[Text.UTF8Encoding]::new($false))
    & $compiler -Mapping $inputPath -Output $reportPath 6>$null | Out-Null
    $report=Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json -Depth 100
    $result=@($report.milestones | Where-Object milestone_id -EQ 'SDK1-M20')[0]
    if ($result.disposition -cne $expected) { throw "$case returned $($result.disposition), expected $expected" }
    if ($report.claims.sdk1_released -or $report.claims.publication_authorized) { throw 'Interface proof granted release authority' }
    if ($case -ne 'positive' -and $report.clean_room_candidate_authorized) { throw 'Missing or invalid Explorer evidence authorized a candidate' }
    $passed.Add($case)
}
$result=[ordered]@{ok=$true;cases_passed=@($passed);world_build_count=0;solver_step_count=0}
$result | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Output 'result.json') -Encoding utf8NoBOM
$result | ConvertTo-Json -Compress
