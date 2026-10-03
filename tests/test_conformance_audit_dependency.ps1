#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$dependencyModulePath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$auditModulePath = Join-Path $sdkRoot "conformance_audit_dependency.ps1"
$contractPath = Join-Path $sdkRoot "conformance_audit_dependency_contract_v1.json"
$registryPath = Join-Path $sdkRoot "conformance_audit_dependency_registry_v1.json"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-AuditDependency([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "CONFORMANCE_AUDIT_DEPENDENCY $Message"
    }
}

foreach ($path in @(
    $dependencyModulePath,
    $auditModulePath,
    $contractPath,
    $registryPath,
    $runnerPath
)) {
    Assert-AuditDependency `
        (Test-Path -LiteralPath $path -PathType Leaf) `
        "required source is missing: $path"
}
[void][scriptblock]::Create((Get-Content -LiteralPath $auditModulePath -Raw))
. $dependencyModulePath

$contract = Get-SporeSporeConformanceAuditDependencyContract
$registry = Get-SporeSporeConformanceAuditDependencyRegistry
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-AuditDependency (
    [int]$contract.authority.cep1_audit_count -eq 167 -and
    [int]$contract.authority.registered_audit_count -eq 1 -and
    [int]$contract.authority.complete_audit_count -eq 1 -and
    [int]$contract.authority.unregistered_audit_count -eq 166 -and
    [string]$contract.maintenance_reconciliation.reconciliation_id -ceq
        "CAD1-LCA1-RC8-PREFLIGHT-CEP1-COUNT" -and
    [bool]$contract.maintenance_reconciliation.failure_observed -and
    [string]$contract.maintenance_reconciliation.failure_message -ceq
        "Audit-dependency registry no longer reconciles with CEP1." -and
    [int]$contract.maintenance_reconciliation.pre_reconciliation_contract_cep1_audit_count -eq 164 -and
    [int]$contract.maintenance_reconciliation.pre_reconciliation_registry_cep1_audit_count -eq 164 -and
    [int]$contract.maintenance_reconciliation.observed_cep1_audit_count -eq 167 -and
    [int]$contract.maintenance_reconciliation.post_reconciliation_contract_cep1_audit_count -eq 167 -and
    [int]$contract.maintenance_reconciliation.post_reconciliation_registry_cep1_audit_count -eq 167 -and
    [int]$contract.maintenance_reconciliation.registered_audit_count -eq 1 -and
    [int]$contract.maintenance_reconciliation.complete_audit_count -eq 1 -and
    [int]$contract.maintenance_reconciliation.post_reconciliation_unregistered_audit_count -eq 166 -and
    (@($contract.maintenance_reconciliation.newly_reconciled_unregistered_audit_paths) -join "|") -ceq
        "tests/test_qsdk_r23d62_dependency_closure.ps1|tests/test_qsdk_r24d8_active_step_snapshot_timing_positive_closure.ps1|tests/test_qsdk_r24d9_one_hinge_numerical_telemetry_physical_failure_closure.ps1" -and
    [string]$contract.maintenance_reconciliation.immutable_prior_reconciliation.reconciliation_id -ceq
        "CAD1-R24D7-POSTCLOSURE-CEP1-COUNT" -and
    [int]$contract.maintenance_reconciliation.immutable_prior_reconciliation.observed_cep1_audit_count -eq 164 -and
    [int]$contract.maintenance_reconciliation.immutable_prior_reconciliation.post_reconciliation_unregistered_audit_count -eq 163 -and
    -not [bool]$contract.maintenance_reconciliation.immutable_prior_reconciliation.historical_result_or_interpretation_changed -and
    [int]$contract.maintenance_reconciliation.immutable_prior_reconciliation.maintenance_process_physical_world_count -eq 0 -and
    [int]$contract.maintenance_reconciliation.dependency_registration_added_count -eq 0 -and
    -not [bool]$contract.maintenance_reconciliation.external_evidence_completeness_promoted -and
    -not [bool]$contract.maintenance_reconciliation.cache_lookup_permitted -and
    -not [bool]$contract.maintenance_reconciliation.result_reuse_permitted -and
    -not [bool]$contract.maintenance_reconciliation.historical_result_or_interpretation_changed -and
    [int]$contract.maintenance_reconciliation.maintenance_process_physical_world_count -eq 0 -and
    -not [bool]$contract.maintenance_reconciliation.physical_acceptance_authority -and
    -not [bool]$contract.maintenance_reconciliation.release_authority -and
    -not [bool]$contract.claims.external_evidence_inventory_complete -and
    -not [bool]$contract.claims.transitive_dependency_key_complete -and
    -not [bool]$contract.claims.cache_lookup_permitted -and
    -not [bool]$contract.claims.result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    [int]$registry.complete_audit_count -eq 1 -and
    -not [bool]$registry.result_reuse_permitted -and
    $runnerSource.Contains(
        "tests\test_conformance_audit_dependency.ps1",
        [StringComparison]::Ordinal
    )
) "contract, registry, or canonical runner exceeded the candidate boundary"

$live = Get-SporeSporeConformanceAuditDependencyCandidate -RepoRoot $repoRoot
$liveEntry = @($live.entries)[0]
$liveShapes = @($liveEntry.dependency_shapes)
Assert-AuditDependency (
    [string]$live.schema_version -ceq
        "sporespore_conformance_audit_dependency_candidate_v1" -and
    [string]$live.status -ceq
        "one_complete_audit_other_audits_unregistered_reuse_disabled" -and
    [int]$live.cep1_audit_count -eq 167 -and
    [int]$live.registered_audit_count -eq 1 -and
    [int]$live.complete_audit_count -eq 1 -and
    [int]$live.unregistered_audit_count -eq 166 -and
    [string]$live.inventory_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
    [string]$liveEntry.audit_path -ceq
        "tests/test_qsdk_r23d13_closure.ps1" -and
    $liveShapes.Count -eq 4 -and
    [int]$liveShapes[0].file_count -eq 26 -and
    [long]$liveShapes[0].byte_count -eq 35559068 -and
    [bool]$liveShapes[0].matches_declared -and
    [long]$liveShapes[1].byte_count -eq 3564 -and
    [bool]$liveShapes[1].matches_declared -and
    [int]$liveShapes[2].matching_directory_count -ge 1 -and
    [int]$liveShapes[3].object_count -eq 2 -and
    [bool]$liveShapes[3].git_object_ids_recomputed -and
    [string]$liveShapes[3].objects[0].role -ceq "frozen_source_commit" -and
    [string]$liveShapes[3].objects[0].object_type -ceq "commit" -and
    [string]$liveShapes[3].objects[1].role -ceq "frozen_source_tree" -and
    [string]$liveShapes[3].objects[1].object_type -ceq "tree" -and
    [bool]$liveEntry.external_evidence_complete -and
    [bool]$liveEntry.runtime_complete -and
    [bool]$liveEntry.transitive_dependency_complete -and
    -not [bool]$live.external_evidence_inventory_complete -and
    -not [bool]$live.runtime_complete -and
    -not [bool]$live.transitive_dependency_complete -and
    -not [bool]$live.cache_lookup_permitted -and
    -not [bool]$live.result_reuse_permitted -and
    -not [bool]$live.physical_authority
) "live partial registry was malformed, stale, or over-authoritative"

$targetParent = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
$testRoot = Join-Path $targetParent (
    "conformance-audit-dependency-test-" + [guid]::NewGuid().ToString("N")
)
$treeRoot = Join-Path $testRoot "tree"
$queryRoot = Join-Path $testRoot "query"
[void][System.IO.Directory]::CreateDirectory($treeRoot)
[void][System.IO.Directory]::CreateDirectory($queryRoot)
try {
    [System.IO.File]::WriteAllText(
        (Join-Path $treeRoot "a.txt"),
        "alpha`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $treeA = Get-SporeSporeDirectoryFileInventory `
        -Root $treeRoot `
        -InventoryId "synthetic_tree"
    [System.IO.File]::WriteAllText(
        (Join-Path $treeRoot "a.txt"),
        "beta`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $treeB = Get-SporeSporeDirectoryFileInventory `
        -Root $treeRoot `
        -InventoryId "synthetic_tree"
    Assert-AuditDependency (
        [string]$treeA.inventory_sha256 -cne
        [string]$treeB.inventory_sha256
    ) "directory-tree content mutation did not invalidate its digest"

    $matchA = Join-Path $queryRoot "campaign-a"
    $otherA = Join-Path $queryRoot "unrelated-a"
    [void][System.IO.Directory]::CreateDirectory($matchA)
    [void][System.IO.Directory]::CreateDirectory($otherA)
    [System.IO.File]::WriteAllText(
        (Join-Path $matchA "completion.json"),
        "{}`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [System.IO.File]::WriteAllText(
        (Join-Path $otherA "completion.json"),
        "{}`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $queryA = Get-SporeSporeEvidenceDirectoryQueryInventory `
        -EvidenceRoot $queryRoot `
        -ImmediateChildNamePrefix "campaign-" `
        -ChildFileProbe "completion.json"
    $otherB = Join-Path $queryRoot "unrelated-b"
    [void][System.IO.Directory]::CreateDirectory($otherB)
    $queryB = Get-SporeSporeEvidenceDirectoryQueryInventory `
        -EvidenceRoot $queryRoot `
        -ImmediateChildNamePrefix "campaign-" `
        -ChildFileProbe "completion.json"
    Assert-AuditDependency (
        [string]$queryA.inventory_sha256 -ceq
        [string]$queryB.inventory_sha256
    ) "an unrelated query-prefix append invalidated the bounded query"

    $matchB = Join-Path $queryRoot "campaign-b"
    [void][System.IO.Directory]::CreateDirectory($matchB)
    $queryC = Get-SporeSporeEvidenceDirectoryQueryInventory `
        -EvidenceRoot $queryRoot `
        -ImmediateChildNamePrefix "campaign-" `
        -ChildFileProbe "completion.json"
    [System.IO.File]::WriteAllText(
        (Join-Path $matchB "completion.json"),
        "{`"closed`":true}`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $queryD = Get-SporeSporeEvidenceDirectoryQueryInventory `
        -EvidenceRoot $queryRoot `
        -ImmediateChildNamePrefix "campaign-" `
        -ChildFileProbe "completion.json"
    Assert-AuditDependency (
        [string]$queryB.inventory_sha256 -cne
            [string]$queryC.inventory_sha256 -and
        [string]$queryC.inventory_sha256 -cne
            [string]$queryD.inventory_sha256
    ) "matching directory or child-probe mutation did not invalidate the query"

    $missingRejected = $false
    try {
        [void](Get-SporeSporeDirectoryFileInventory `
            -Root (Join-Path $testRoot "missing") `
            -InventoryId "missing")
    } catch { $missingRejected = $true }
    Assert-AuditDependency $missingRejected "missing declared tree was accepted"

    $frozenObjects = @(
        [ordered]@{
            role = "frozen_source_tree"
            object_id = "891455b0665c44043698cbee9539a5c4be35df65"
            object_type = "tree"
        },
        [ordered]@{
            role = "frozen_source_commit"
            object_id = "2283625319c1d082082f584d288511d403608952"
            object_type = "commit"
        }
    )
    $gitA = Get-SporeSporeGitObjectSetInventory `
        -RepoRoot $repoRoot -Objects $frozenObjects -InventoryId "synthetic_git"
    $gitB = Get-SporeSporeGitObjectSetInventory `
        -RepoRoot $repoRoot -Objects @($frozenObjects[1], $frozenObjects[0]) `
        -InventoryId "synthetic_git"
    $headCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
    $headTree = (& git -C $repoRoot rev-parse "HEAD^{tree}").Trim()
    $gitChanged = Get-SporeSporeGitObjectSetInventory `
        -RepoRoot $repoRoot `
        -Objects @(
            [ordered]@{
                role = "frozen_source_commit"
                object_id = $headCommit
                object_type = "commit"
            },
            [ordered]@{
                role = "frozen_source_tree"
                object_id = $headTree
                object_type = "tree"
            }
        ) `
        -InventoryId "synthetic_git"
    Assert-AuditDependency (
        [string]$gitA.inventory_sha256 -ceq [string]$gitB.inventory_sha256 -and
        [string]$gitA.inventory_sha256 -cne
            [string]$gitChanged.inventory_sha256 -and
        [bool]$gitA.git_object_ids_recomputed -and
        @($gitA.objects | Where-Object {
            -not [bool]$_.git_object_id_recomputed -or
            [string]$_.raw_content_sha256 -cnotmatch "^sha256:[0-9a-f]{64}$"
        }).Count -eq 0
    ) "Git-object set was order-sensitive, mutation-blind, or unverified"
    $missingGitRejected = $false
    try {
        [void](Get-SporeSporeGitObjectSetInventory `
            -RepoRoot $repoRoot `
            -Objects @([ordered]@{
                role = "missing"
                object_id = "0000000000000000000000000000000000000000"
                object_type = "commit"
            }))
    } catch { $missingGitRejected = $true }
    $wrongTypeRejected = $false
    try {
        [void](Get-SporeSporeGitObjectSetInventory `
            -RepoRoot $repoRoot `
            -Objects @([ordered]@{
                role = "wrong_type"
                object_id = "891455b0665c44043698cbee9539a5c4be35df65"
                object_type = "commit"
            }))
    } catch { $wrongTypeRejected = $true }
    Assert-AuditDependency (
        $missingGitRejected -and $wrongTypeRejected
    ) "missing or wrong-type Git object was accepted"

    Write-Output (
        "CONFORMANCE_AUDIT_DEPENDENCY_PASS cep1=167 registered=1 " +
        "complete=1 unregistered=166 live_tree_files=26 " +
        "tree_mutation=True bounded_query=True matching_mutation=True " +
        "git_objects=2 git_raw_rehash=True git_order_stable=True " +
        "git_mutation=True git_missing_refusal=True git_type_refusal=True " +
        "missing_refusal=True external_evidence_complete=True " +
        "observer=development_only cache=disabled " +
        "worlds=0 physical_authority=False"
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
