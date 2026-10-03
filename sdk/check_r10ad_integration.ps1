#requires -Version 7.5
[CmdletBinding()]
param([ValidateSet('native','host','startup','transport','launch','authority','report','upright','ready','timeout','walking','headers','retention','runtime','workflow')][string[]]$Stages=@('native','host'))
$ErrorActionPreference='Stop'
$repoRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if ((& git -C $repoRoot rev-parse --show-toplevel) -cne $repoRoot.Replace('\','/') -or
    (& git -C $repoRoot remote get-url origin) -cne 'https://github.com/Slagathore/sporespore.git') {throw 'R10AD_REPOSITORY'}
. (Join-Path $PSScriptRoot 'locomotion_operation_lock.ps1')
$operation=Enter-SporeSporeLocomotionOperationLock -Role conformance
if (-not $operation.acquired -or $operation.abandoned_owner_recovered) {throw 'R10AD_OPERATION_LOCK_BUSY'}
$out=Join-Path (Split-Path $repoRoot -Parent) ('SporeSpore_Evidence/r10ad-integration-'+[Guid]::NewGuid().ToString('N'))
$patterns=@{native='test_r10ad_native_interfaces.py';host='test_r10ad_host.py';startup='test_r10ad_startup_preflight.py';transport='test_r10ad_startup_transport.py';launch='test_r10ad_launch_guard.py';authority='test_r10ad_native_world_authority.py';report='test_r10ad_complete_report.py';upright='test_r10ad_upright_report_gate.py';ready='test_r10ad_ready_report_gate.py';timeout='test_r10ad_timeout_report_gate.py';walking='test_r10ad_walking_report_gate.py';headers='test_r10ad_smoke_reader.py';retention='test_r10ad_retention_gate.py';runtime='test_r10ad_runtime.py';workflow='test_r10ad_workflow_audit.py'}
$receipts=@()
try {
    $null=New-Item -ItemType Directory -Path $out
    Write-Output ('R10AD_INTEGRATION_ROOT '+$out)
    foreach ($stage in $Stages) {
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot ('tests/'+$patterns[$stage])))) {throw 'R10AD_TEST_MISSING'}
        $previousCandidate=$env:SPORESPORE_DEVELOPMENT_TEST_CANDIDATE
        if ($stage -eq 'runtime') {$env:SPORESPORE_DEVELOPMENT_TEST_CANDIDATE='sdk/development/recovery_candidates/r10ad-contact-frame-diagnostic-v1.json'}
        & 'C:/Program Files/Python311/python.exe' -B -m unittest discover -s tests -p $patterns[$stage] -v 1> (Join-Path $out ($stage+'.stdout.log')) 2> (Join-Path $out ($stage+'.stderr.log'))
        $code=$LASTEXITCODE
        $env:SPORESPORE_DEVELOPMENT_TEST_CANDIDATE=$previousCandidate
        $receipts+=@{stage=$stage;pattern=$patterns[$stage];exit_code=$code}
        $receipts | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $out 'stages.json') -Encoding utf8NoBOM
        Get-Content -LiteralPath (Join-Path $out ($stage+'.stdout.log'))
        Get-Content -LiteralPath (Join-Path $out ($stage+'.stderr.log'))
        if ($code -ne 0) {throw ('R10AD_COMPONENT_FAILED:'+ $stage)}
    }
} finally {
    Exit-SporeSporeLocomotionOperationLock -Receipt $operation
    if (Test-Path -LiteralPath $out) {
        $operation | Select-Object * -ExcludeProperty _mutex_handle | ConvertTo-Json -Depth 20 |
            Set-Content -LiteralPath (Join-Path $out 'operation-lock.json') -Encoding utf8NoBOM
    }
}
