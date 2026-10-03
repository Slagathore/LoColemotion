[CmdletBinding()]
param([Parameter(Mandatory)][string]$Declaration, [Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
. (Join-Path $PSScriptRoot 'run_qsdk_r10f_continuous_passive_recovery.ps1') -DevelopmentLibrary
$value = Get-Content -LiteralPath $Declaration -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$script:RepairId = 'QSDK-R10F-L15'
$script:WorkerResource = 'res://sdk/adapters/godot/gdscript/r10dg_development_worker_v1.gd'
$script:RawSchema = 'sporespore_development_recovery_candidate_child_v1'
$script:RawMarker = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
$script:WorkId = 'SDK1-GODOT-RECOVERY-CANDIDATE-V1'
$script:DevelopmentSeed = 71248
$script:DevelopmentSeedLabel = $value.r10dg_development.seed.label
$script:DevelopmentSeedSha256 = $value.r10dg_development.seed.sha256
$script:PhysicalAttemptId = $value.attempt_id
$binding = @{ authority=@{source_commit=$value.source_snapshot.head};
    authority_sha256=('sha256:' + (Get-FileHash -LiteralPath $Declaration -Algorithm SHA256).Hash.ToLowerInvariant());
    l14_exact_runtime_images=$value.runtime; l15_prepared_context_expectation=$value.prepared_context_expectation }
$environment = New-QsdkR10fL9ChildEnvironment -Descriptor $value.children[0] -Binding $binding
Write-Utf8CreateNew $OutputPath (ConvertTo-SporeSporeExactJson $environment)
