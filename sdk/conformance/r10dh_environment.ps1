[CmdletBinding()]
param([string]$Declaration = '', [string]$OutputPath = '', [string]$Batch = '')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot '../run_qsdk_r10f_continuous_passive_recovery.ps1') -DevelopmentLibrary
function Write-R10dhEnvironment {
param([string]$Declaration, [string]$OutputPath)
$value = Get-Content -LiteralPath $Declaration -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$prepared = Get-Content -LiteralPath (Join-Path (Split-Path $Declaration) 'prepared-context.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$script:RepairId = 'QSDK-R10F-L15'
$script:WorkerResource = $value.worker_resource
$script:RawSchema = 'sporespore_development_recovery_candidate_child_v1'
$script:RawMarker = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
$script:WorkId = 'SDK1-GODOT-RECOVERY-CANDIDATE-V1'
$script:DevelopmentSeed = [int]$value.seed
$script:DevelopmentSeedLabel = $value.r10dh_campaign.seed.label
$script:DevelopmentSeedSha256 = 'sha256:' + [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($script:DevelopmentSeedLabel))).ToLowerInvariant()
$script:PhysicalAttemptId = $value.attempt_id
$binding = @{authority=@{source_commit=$value.source_snapshot.head};
    authority_sha256=('sha256:' + (Get-FileHash -LiteralPath $Declaration -Algorithm SHA256).Hash.ToLowerInvariant());
    l14_exact_runtime_images=$value.runtime; l15_prepared_context_expectation=$prepared.expectation}
$environment = New-QsdkR10fL9ChildEnvironment -Descriptor $value.children[0] -Binding $binding
$environment.environment['SPORESPORE_R10DH_DECLARATION'] = $Declaration.Replace('\','/')
Write-Utf8CreateNew $OutputPath (ConvertTo-SporeSporeExactJson $environment)
}
if (-not [string]::IsNullOrWhiteSpace($Batch)) {
    $rows = Get-Content -LiteralPath (Join-Path $Batch 'cells.json') -Raw | ConvertFrom-Json -AsHashtable
    foreach ($row in $rows) {
        Write-R10dhEnvironment (Join-Path $row.folder 'declaration.json') (Join-Path $row.folder 'environment.json')
    }
} else {
    if ([string]::IsNullOrWhiteSpace($Declaration) -or [string]::IsNullOrWhiteSpace($OutputPath)) { throw 'R10DH_ENVIRONMENT_ARGUMENTS' }
    Write-R10dhEnvironment $Declaration $OutputPath
}
