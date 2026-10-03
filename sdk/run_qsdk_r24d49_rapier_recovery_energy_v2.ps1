#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("Ghost", "Development")]
    [string]$Mode,
    [string]$EvidenceRoot =
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)

$shared = Join-Path $PSScriptRoot "run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"
$forward = @{
    Mode = $Mode
    ContractRelativePath =
        "sdk/recovery/r24d49_rapier_runtime_binding_contract_v1.json"
    EvidenceRoot = $EvidenceRoot
}
if ($Mode -ceq "Development") {
    $forward.StageAuthorityContractRelativePath =
        "sdk/recovery/r24d49_stage_b_ghost_authority_contract_v1.json"
    $forward.StageAuthorityContractRawSha256 =
        "sha256:a11e5f297c0557c0b849b88da38bc61b8c926f6c84b8435119eb442f0aee6244"
}
& $shared @forward
exit $LASTEXITCODE
