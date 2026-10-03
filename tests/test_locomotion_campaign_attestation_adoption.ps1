#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$modulePath = Join-Path $repoRoot "sdk\locomotion_campaign_attestation_adoption.ps1"
. $modulePath

function Assert-Lca1Adoption([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "LCA1_ADOPTION $Message" }
}

function Copy-Lca1Adoption([object]$Value) {
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$contract = Get-SporeSporeCampaignAdoptionContract
Assert-Lca1Adoption (
    @($contract.commissioned_core_source_bindings).Count -eq 10 -and
    [bool]$contract.claims.commissioned_executor_verified -and
    [bool]$contract.claims.physical_launch_prerequisite_may_be_satisfied -and
    -not [bool]$contract.claims.physical_acceptance_authority
) "contract boundary changed"

$commissioningAuditPath = Join-Path $repoRoot (
    [string]$contract.commissioning_closure.audit_path
)
$commissioningAuditOutput = @(& $commissioningAuditPath *>&1)
$commissioningAuditSucceeded = $?
Assert-Lca1Adoption (
    $commissioningAuditSucceeded -and
    @($commissioningAuditOutput | Where-Object {
        ([string]$_).StartsWith(
            [string]$contract.commissioning_closure.required_terminal_marker_prefix,
            [StringComparison]::Ordinal
        )
    }).Count -eq 1
) "commissioning audit information-stream marker was not captured exactly once"

$roles = @(
    [ordered]@{ role = "worker"; source_path = "worker"; test_gate_id = "W" },
    [ordered]@{ role = "evaluator"; source_path = "evaluator"; test_gate_id = "E" },
    [ordered]@{ role = "supervisor"; source_path = "supervisor"; test_gate_id = "S" }
)
$expected = [ordered]@{
    campaign_id = "TEST-CAMPAIGN"
    source_commit = "1111111111111111111111111111111111111111"
    source_tree_git_oid = "2222222222222222222222222222222222222222"
    manifest_raw_sha256 = "sha256:" + ("3" * 64)
    scoped_attestation_raw_sha256 = "sha256:" + ("4" * 64)
    commissioning_closure_raw_sha256 =
        [string]$contract.commissioning_closure.raw_sha256
    commissioning_audit_raw_sha256 =
        [string]$contract.commissioning_closure.audit_raw_sha256
    runtime_inventory_sha256 = "sha256:" + ("5" * 64)
    candidate_inventory_sha256 = "sha256:" + ("6" * 64)
    declared_physical_world_count = 9
    global_gate_count = 12
    lineage_gate_count = 1
    campaign_gate_count = 3
    executed_gate_count = 16
    gate_cas_object_count = 48
    role_bindings = $roles
}
$document = [ordered]@{
    schema_version = "sporespore_locomotion_campaign_attestation_adoption_v1"
    status = "commissioned_campaign_local_qualification_adopted_for_physical_launch"
    campaign_id = [string]$expected.campaign_id
    source_commit = [string]$expected.source_commit
    source_tree_git_oid = [string]$expected.source_tree_git_oid
    manifest_raw_sha256 = [string]$expected.manifest_raw_sha256
    scoped_attestation_raw_sha256 = [string]$expected.scoped_attestation_raw_sha256
    commissioning_closure_raw_sha256 = [string]$expected.commissioning_closure_raw_sha256
    commissioning_audit_raw_sha256 = [string]$expected.commissioning_audit_raw_sha256
    runtime_inventory_sha256 = [string]$expected.runtime_inventory_sha256
    candidate_inventory_sha256 = [string]$expected.candidate_inventory_sha256
    declared_physical_world_count = 9
    global_gate_count = 12
    lineage_gate_count = 1
    campaign_gate_count = 3
    executed_gate_count = 16
    gate_cas_object_count = 48
    role_bindings = $roles
    commissioned_executor_verified = $true
    campaign_local_attestation_verified = $true
    all_gate_cas_objects_verified = $true
    scoped_attestation_cas_verified = $true
    clean_pushed_live_source_verified = $true
    runtime_matches_commissioning = $true
    physical_launch_prerequisite_satisfied = $true
    physical_acceptance_authority = $false
    release_authority = $false
    claims = [ordered]@{
        commissioned_executor_verified = $true
        campaign_local_qualification_passed = $true
        physical_launch_prerequisite_satisfied = $true
        physical_campaign_executed = $false
        scientific_result = $false
        walking_acceptance = $false
        turning_acceptance = $false
        cross_engine_equivalence = $false
        release_authority = $false
        physical_acceptance_authority = $false
    }
}
$positive = Test-SporeSporeCampaignAdoptionDocument `
    -Document $document -Expected $expected
Assert-Lca1Adoption ([bool]$positive.ok) "intact adoption document refused"

$mutations = @(
    @{ path = "schema_version"; value = "wrong" },
    @{ path = "status"; value = "wrong" },
    @{ path = "campaign_id"; value = "WRONG" },
    @{ path = "source_commit"; value = "0" * 40 },
    @{ path = "manifest_raw_sha256"; value = "sha256:" + ("0" * 64) },
    @{ path = "scoped_attestation_raw_sha256"; value = "sha256:" + ("0" * 64) },
    @{ path = "runtime_inventory_sha256"; value = "sha256:" + ("0" * 64) },
    @{ path = "executed_gate_count"; value = 15 },
    @{ path = "role_bindings"; value = @($roles[1], $roles[0], $roles[2]) },
    @{ path = "runtime_matches_commissioning"; value = $false },
    @{ path = "physical_launch_prerequisite_satisfied"; value = $false },
    @{ path = "physical_acceptance_authority"; value = $true }
)
$refusals = 0
foreach ($mutation in $mutations) {
    $mutated = Copy-Lca1Adoption $document
    $mutated[[string]$mutation.path] = $mutation.value
    $result = Test-SporeSporeCampaignAdoptionDocument `
        -Document $mutated -Expected $expected
    Assert-Lca1Adoption (-not [bool]$result.ok) (
        "mutation was accepted: $($mutation.path)"
    )
    $refusals++
}
$claimMutations = 0
foreach ($claim in @(
    "physical_campaign_executed", "scientific_result", "walking_acceptance",
    "turning_acceptance", "cross_engine_equivalence", "release_authority",
    "physical_acceptance_authority"
)) {
    $mutated = Copy-Lca1Adoption $document
    $mutated.claims[$claim] = $true
    $result = Test-SporeSporeCampaignAdoptionDocument `
        -Document $mutated -Expected $expected
    Assert-Lca1Adoption (-not [bool]$result.ok) "claim inflation accepted: $claim"
    $claimMutations++
}

Write-Host (
    "LCA1_ADOPTION_PASS commissioned_core=10 commissioning_marker=1 " +
    "positive=1 mutations=$refusals " +
    "claim_mutations=$claimMutations worlds=0 physical_prerequisite=False " +
    "physical_authority=False release_authority=False"
)
