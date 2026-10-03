param([string]$Declaration, [string]$OutputPath)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../sdk/run_r10dg_physical.ps1') -Library
$value = Get-Content -Raw -LiteralPath $Declaration | ConvertFrom-Json -AsHashtable -Depth 100
$context = New-R10dgLaunchContext $value $Declaration
Assert-QsdkR10fL15LaunchContext $context
$value.runtime.images.godot_engine.raw_sha256 = 'sha256:' + ('0' * 64)
$refused = $false
try { $null = New-R10dgLaunchContext $value $Declaration } catch { $refused = $_.Exception.Message -eq 'R10DG_CONTEXT_HOST' }
if (-not $refused) { throw 'R10DG_CROSSED_HOST_ACCEPTED' }
Write-R10dgNew $OutputPath (ConvertTo-SporeSporeExactJson @{ok=$true;context=$context;crossed_host_refused=$refused;world_build_count=0;solver_step_count=0})
