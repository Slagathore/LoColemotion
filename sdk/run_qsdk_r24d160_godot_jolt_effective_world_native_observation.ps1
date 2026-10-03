#requires -Version 7.0

## Thin R160 binding for the shared compact native-observation supervisor.

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
        "r24d160_godot_jolt_effective_world_native_observation_contract_v1.json"
    ) `
    -Mode $Mode `
    -RunPhysical:$RunPhysical `
    -AuthorizationPath $AuthorizationPath `
    -EvidenceRoot $EvidenceRoot
exit $LASTEXITCODE
