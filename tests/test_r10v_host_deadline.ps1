#requires -Version 7.5
param([Parameter(Mandatory)][string]$Fixture, [Parameter(Mandatory)][string]$Output)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../sdk/run_development_recovery_smoke.ps1" -Library -ProfileSteps -ReuseContextChecks
# This synthetic component input bypasses candidate selection only. It executes
# the actual production declaration-field function, without opening a world.
$fixtureValue = Get-Content -LiteralPath $Fixture -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$candidateSelection = $fixtureValue.selection
$r10vSelected = $true
$r10vDevelopmentContext = $fixtureValue.declaration.r10v_development
$fields = Get-DevelopmentCandidateFields
$value = $fixtureValue.declaration
foreach ($key in $fields.Keys) { $value[$key] = $fields[$key] }
$value.worker_resource = $candidateSelection.worker_selection.worker
$value.step_cost_profile_id = 'recovery_step_cost_wall_clock_v1'
$value.context_cache_profile_id = 'recovery_exact_context_checks_v1'
$value.context_cache_call_sites = @('epoch_preflight', 'global_context_validation')
$value.official_qualification = $false
$value.physical_acceptance_authority = $false
$value.release_authority = $false
if (Test-Path -LiteralPath $Output) { throw 'R10V_COMPONENT_OUTPUT_EXISTS' }
$value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Output -Encoding utf8NoBOM
