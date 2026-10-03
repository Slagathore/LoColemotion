#requires -Version 7.0

## Thin R158 binding for the shared compact native-observation supervisor.

[CmdletBinding()]
param(
    [ValidateSet("Preflight", "Physical")][string]$Mode = "Preflight",
    [switch]$RunPhysical,
    [string]$AuthorizationPath = "",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$ErrorActionPreference = "Stop"
$shared = Join-Path $PSScriptRoot "run_compact_godot_native_observation.ps1"
& $shared `
    -ContractRelativePath (
        "sdk/recovery/" +
        "r24d158_godot_jolt_rotation_integration_energy_field_population_contract_v1.json"
    ) `
    -Mode $Mode `
    -RunPhysical:$RunPhysical `
    -AuthorizationPath $AuthorizationPath `
    -EvidenceRoot $EvidenceRoot
exit $LASTEXITCODE
