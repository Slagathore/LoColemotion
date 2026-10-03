#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$modulePath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$contractPath = Join-Path $sdkRoot "conformance_dependency_contract_v1.json"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-DependencyKey([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "CONFORMANCE_DEPENDENCY_KEY $Message"
    }
}

foreach ($path in @($modulePath, $contractPath, $runnerPath)) {
    Assert-DependencyKey `
        (Test-Path -LiteralPath $path -PathType Leaf) `
        "required source is missing: $path"
}
[void][scriptblock]::Create((Get-Content -LiteralPath $modulePath -Raw))
. $modulePath

$contract = Get-SporeSporeConformanceDependencyContract
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
$moduleSource = Get-Content -LiteralPath $modulePath -Raw
Assert-DependencyKey `
    (-not [bool]$contract.candidate_authority.transitive_dependency_key_complete -and
        -not [bool]$contract.candidate_authority.undeclared_dependency_detection_complete -and
        -not [bool]$contract.candidate_authority.host_semantics_key_complete -and
        -not [bool]$contract.candidate_authority.lookup_permitted -and
        -not [bool]$contract.candidate_authority.reuse_permitted -and
        [bool]$contract.candidate_authority.full_source_exact_conformance_remains_required) `
    "candidate contract exceeded its uncommissioned authority"
Assert-DependencyKey `
    ((@($contract.per_audit_external_dependency_candidate_boundary.
        dependency_shapes) -join "|") -ceq
        "file|directory_tree|directory_query|git_object_set" -and
        [int]$contract.per_audit_external_dependency_candidate_boundary.
            cep1_audit_count -eq 167 -and
        [int]$contract.per_audit_external_dependency_candidate_boundary.
            registered_audit_count -eq 1 -and
        [int]$contract.per_audit_external_dependency_candidate_boundary.
            complete_audit_count -eq 1 -and
        [int]$contract.per_audit_external_dependency_candidate_boundary.
            unregistered_audit_count -eq 166) `
    "per-audit dependency declaration was stale or omitted the Git-object closure"
Assert-DependencyKey `
    ($runnerSource.Contains(
        "tests\test_conformance_dependency_key.ps1",
        [StringComparison]::Ordinal) -and
        -not $runnerSource.Contains("UseCached", [StringComparison]::OrdinalIgnoreCase) -and
        -not $moduleSource.Contains("lookup_performed = `$true", [StringComparison]::Ordinal) -and
        -not $moduleSource.Contains("result_reused = `$true", [StringComparison]::Ordinal)) `
    "canonical runner lost the key audit or made reuse reachable"

$liveCandidate = New-SporeSporeConformanceDependencyKeyCandidate `
    -RepoRoot $repoRoot
Assert-DependencyKey `
    ([string]$liveCandidate.schema_version -ceq
        "sporespore_conformance_dependency_key_candidate_v1" -and
        [string]$liveCandidate.status -ceq "candidate_incomplete_cache_disabled" -and
        [string]$liveCandidate.key_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
        [int]$liveCandidate.source.tracked_file_count -gt 0 -and
        [long]$liveCandidate.source.tracked_byte_count -gt 0 -and
        [int]$liveCandidate.environment.referenced_name_count -gt 0 -and
        [string]$liveCandidate.environment.status -ceq
            "complete_process_environment_observed" -and
        [int]$liveCandidate.environment.complete_process_name_count -gt 0 -and
        [string]$liveCandidate.environment.complete_process_inventory_sha256 -cmatch
            "^sha256:[0-9a-f]{64}$" -and
        [bool]$liveCandidate.environment.dynamic_reference_values_covered -and
        [string]$liveCandidate.runtime.status -ceq
            "partial_runtime_profile_cache_disabled" -and
        [int]$liveCandidate.runtime.registered_profile_count -eq 1 -and
        [int]$liveCandidate.runtime.complete_profile_count -eq 1 -and
        [int]$liveCandidate.runtime.registered_audit_binding_count -eq 1 -and
        [int]$liveCandidate.runtime.complete_audit_binding_count -eq 1 -and
        [string]$liveCandidate.runtime.inventory_sha256 -cmatch
            "^sha256:[0-9a-f]{64}$" -and
        -not [bool]$liveCandidate.runtime.raw_git_configuration_values_retained -and
        -not [bool]$liveCandidate.runtime.host_semantics_complete -and
        -not [bool]$liveCandidate.runtime.inventory_complete -and
        [string]$liveCandidate.evidence.status -ceq
            "referenced_cas_and_partial_audit_evidence_observed_incomplete" -and
        [bool]$liveCandidate.evidence.payloads_and_manifests_verified -and
        -not [bool]$liveCandidate.evidence.unrelated_cas_objects_in_key -and
        [int]$liveCandidate.evidence.cep1_audit_count -eq 167 -and
        [int]$liveCandidate.evidence.registered_audit_count -eq 1 -and
        [int]$liveCandidate.evidence.complete_audit_count -eq 1 -and
        [int]$liveCandidate.evidence.unregistered_audit_count -eq 166 -and
        -not [bool]$liveCandidate.evidence.inventory_complete -and
        [string]$liveCandidate.authorization_kernel.status -ceq
            "declared_unexecuted_uncommissioned_authority_disabled" -and
        [int]$liveCandidate.authorization_kernel.global_gate_count -eq 12 -and
        [int]$liveCandidate.authorization_kernel.godot_required_gate_count -eq 3 -and
        [int]$liveCandidate.authorization_kernel.
            campaign_negative_control_role_count -eq 3 -and
        [string]$liveCandidate.authorization_kernel.inventory_sha256 -cmatch
            "^sha256:[0-9a-f]{64}$" -and
        [bool]$liveCandidate.authorization_kernel.
            global_gate_declaration_complete -and
        [bool]$liveCandidate.authorization_kernel.
            canonical_runner_bindings_complete -and
        -not [bool]$liveCandidate.authorization_kernel.
            global_gate_execution_complete -and
        -not [bool]$liveCandidate.authorization_kernel.
            campaign_negative_controls_complete -and
        -not [bool]$liveCandidate.authorization_kernel.cold_equivalence_complete -and
        -not [bool]$liveCandidate.authorization_kernel.kernel_commissioned -and
        -not [bool]$liveCandidate.authorization_kernel.physical_launch_permitted -and
        -not [bool]$liveCandidate.transitive_dependency_key_complete -and
        -not [bool]$liveCandidate.cache_lookup_permitted -and
        -not [bool]$liveCandidate.result_reuse_permitted -and
        -not [bool]$liveCandidate.physical_authority) `
    "live repository candidate was absent, malformed, or over-authoritative"

$targetParent = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
$testRoot = Join-Path $targetParent (
    "conformance-dependency-key-test-" + [guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($testRoot)
$oldSecret = [Environment]::GetEnvironmentVariable(
    "SPORESPORE_DEPENDENCY_TEST_SECRET",
    "Process"
)
$emptyName = "SPORESPORE_DEPENDENCY_TEST_EMPTY"
$missingName = "SPORESPORE_DEPENDENCY_TEST_MISSING"
$oldEmpty = [Environment]::GetEnvironmentVariable($emptyName, "Process")
$oldMissing = [Environment]::GetEnvironmentVariable($missingName, "Process")
$unreferencedName = "SPORESPORE_DEPENDENCY_TEST_UNREFERENCED"
$oldUnreferenced = [Environment]::GetEnvironmentVariable(
    $unreferencedName,
    "Process"
)
try {
    Assert-DependencyKey `
        ((Get-SporeSporeDependencyStringSha256 "") -ceq
            "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855") `
        "empty-string SHA-256 was rejected or changed"
    $rootA = Join-Path $testRoot "root-a"
    $rootB = Join-Path $testRoot "root-b"
    foreach ($root in @($rootA, $rootB)) {
        [void][System.IO.Directory]::CreateDirectory((Join-Path $root "nested"))
        [System.IO.File]::WriteAllText(
            (Join-Path $root "alpha.txt"),
            "alpha`n",
            [System.Text.UTF8Encoding]::new($false)
        )
        [System.IO.File]::WriteAllText(
            (Join-Path $root "nested\beta.txt"),
            "beta`n",
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    $ordered = Get-SporeSporeDeclaredFileInventory `
        -Root $rootA `
        -RelativePaths @("nested\beta.txt", "alpha.txt") `
        -InventoryId "fixture"
    $reordered = Get-SporeSporeDeclaredFileInventory `
        -Root $rootA `
        -RelativePaths @("alpha.txt", "nested/beta.txt") `
        -InventoryId "fixture"
    $otherRoot = Get-SporeSporeDeclaredFileInventory `
        -Root $rootB `
        -RelativePaths @("alpha.txt", "nested/beta.txt") `
        -InventoryId "fixture"
    Assert-DependencyKey `
        ([string]$ordered.inventory_sha256 -ceq [string]$reordered.inventory_sha256 -and
            [string]$ordered.inventory_sha256 -ceq [string]$otherRoot.inventory_sha256 -and
            [long]$ordered.byte_count -eq 11 -and
            [int]$ordered.file_count -eq 2) `
        "canonical inventory is order- or root-dependent"

    [System.IO.File]::WriteAllText(
        (Join-Path $rootB "nested\beta.txt"),
        "BETA`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $mutated = Get-SporeSporeDeclaredFileInventory `
        -Root $rootB `
        -RelativePaths @("alpha.txt", "nested/beta.txt") `
        -InventoryId "fixture"
    Assert-DependencyKey `
        ([string]$mutated.inventory_sha256 -cne [string]$ordered.inventory_sha256) `
        "file-content mutation did not invalidate the inventory"

    $missingRejected = $false
    try {
        [void](Get-SporeSporeDeclaredFileInventory `
            -Root $rootA `
            -RelativePaths @("missing.txt"))
    } catch { $missingRejected = $true }
    Assert-DependencyKey $missingRejected "missing declared input was accepted"

    $escapeRejected = $false
    try {
        [void](Get-SporeSporeDeclaredFileInventory `
            -Root $rootA `
            -RelativePaths @("..\escape.txt"))
    } catch { $escapeRejected = $true }
    Assert-DependencyKey $escapeRejected "path escape was accepted"

    $outsideRoot = Join-Path $testRoot "junction-target"
    [void][System.IO.Directory]::CreateDirectory($outsideRoot)
    [System.IO.File]::WriteAllText(
        (Join-Path $outsideRoot "outside.txt"),
        "outside`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    [void](New-Item `
        -ItemType Junction `
        -Path (Join-Path $rootA "junction") `
        -Target $outsideRoot)
    $reparseRejected = $false
    try {
        [void](Get-SporeSporeDeclaredFileInventory `
            -Root $rootA `
            -RelativePaths @("junction/outside.txt"))
    } catch { $reparseRejected = $true }
    Assert-DependencyKey $reparseRejected "reparse-point path was accepted"

    $duplicateRejected = $false
    try {
        [void](Get-SporeSporeDeclaredFileInventory `
            -Root $rootA `
            -RelativePaths @("alpha.txt", "ALPHA.TXT"))
    } catch { $duplicateRejected = $true }
    Assert-DependencyKey $duplicateRejected "case-colliding dependency was accepted"

    $envRoot = Join-Path $testRoot "environment"
    [void][System.IO.Directory]::CreateDirectory($envRoot)
    $constantSource = Join-Path $envRoot "constant.ps1"
    [System.IO.File]::WriteAllText(
        $constantSource,
        ('Write-Output $env:SPORESPORE_DEPENDENCY_TEST_SECRET' + "`n" +
            'Write-Output $env:SPORESPORE_DEPENDENCY_TEST_EMPTY' + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_DEPENDENCY_TEST_SECRET",
        "first-secret-value",
        "Process"
    )
    Set-Item -LiteralPath "Env:$emptyName" -Value ""
    Remove-Item -LiteralPath "Env:$missingName" -ErrorAction SilentlyContinue
    $environmentA = Get-SporeSporeEnvironmentReferenceInventory `
        -Root $envRoot `
        -SourceRelativePaths @("constant.ps1") `
        -BaselineNames @($missingName)
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_DEPENDENCY_TEST_SECRET",
        "second-secret-value",
        "Process"
    )
    $environmentB = Get-SporeSporeEnvironmentReferenceInventory `
        -Root $envRoot `
        -SourceRelativePaths @("constant.ps1") `
        -BaselineNames @($missingName)
    $serializedEnvironment = $environmentB | ConvertTo-Json -Depth 16 -Compress
    $emptyEntry = @($environmentB.entries | Where-Object {
        [string]$_['name'] -ceq $emptyName
    })[0]
    $missingEntry = @($environmentB.entries | Where-Object {
        [string]$_['name'] -ceq $missingName
    })[0]
    Assert-DependencyKey `
        ($environmentA.referenced_name_count -eq 3 -and
            $environmentA.dynamic_reference_count -eq 0 -and
            [string]$environmentA.inventory_sha256 -cne
                [string]$environmentB.inventory_sha256 -and
            [bool]$emptyEntry.present -and
            [string]$emptyEntry.value_sha256 -ceq
                "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" -and
            -not [bool]$missingEntry.present -and
            $null -eq $missingEntry.value_sha256 -and
            -not $serializedEnvironment.Contains(
                "second-secret-value",
                [StringComparison]::Ordinal)) `
        "environment mutation, empty/missing distinction, or redaction failed"

    $dynamicSource = Join-Path $envRoot "dynamic.ps1"
    [System.IO.File]::WriteAllText(
        $dynamicSource,
        '[Environment]::GetEnvironmentVariable($name)' + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $dynamic = Get-SporeSporeEnvironmentReferenceInventory `
        -Root $envRoot `
        -SourceRelativePaths @("dynamic.ps1")
    Assert-DependencyKey `
        ($dynamic.dynamic_reference_count -eq 1) `
        "dynamic environment lookup was not classified"

    [Environment]::SetEnvironmentVariable(
        $unreferencedName,
        "unreferenced-first",
        "Process"
    )
    $completeEnvironmentA = Get-SporeSporeProcessEnvironmentInventory
    [Environment]::SetEnvironmentVariable(
        $unreferencedName,
        "unreferenced-second",
        "Process"
    )
    $completeEnvironmentB = Get-SporeSporeProcessEnvironmentInventory
    $serializedCompleteEnvironment = $completeEnvironmentB |
        ConvertTo-Json -Depth 16 -Compress
    Assert-DependencyKey `
        ([string]$completeEnvironmentA.inventory_sha256 -cne
            [string]$completeEnvironmentB.inventory_sha256 -and
            -not [bool]$completeEnvironmentB.raw_values_retained -and
            -not $serializedCompleteEnvironment.Contains(
                "unreferenced-second",
                [StringComparison]::Ordinal)) `
        "complete process environment did not invalidate or redact"

    $runtimeRoot = Join-Path $testRoot "runtime"
    [void][System.IO.Directory]::CreateDirectory($runtimeRoot)
    [System.IO.File]::WriteAllBytes(
        (Join-Path $runtimeRoot "runtime.bin"),
        [byte[]](1, 2, 3, 4)
    )
    $runtimeA = Get-SporeSporeDirectoryFileInventory `
        -Root $runtimeRoot `
        -InventoryId "runtime"
    [System.IO.File]::WriteAllBytes(
        (Join-Path $runtimeRoot "runtime.bin"),
        [byte[]](1, 2, 3, 5)
    )
    $runtimeB = Get-SporeSporeDirectoryFileInventory `
        -Root $runtimeRoot `
        -InventoryId "runtime"
    Assert-DependencyKey `
        ([string]$runtimeA.inventory_sha256 -cne [string]$runtimeB.inventory_sha256) `
        "declared runtime mutation did not invalidate its inventory"

    $casRepo = Join-Path $testRoot "cas-repo"
    $casEvidence = Join-Path $testRoot "cas-evidence"
    [void][System.IO.Directory]::CreateDirectory($casRepo)
    [void][System.IO.Directory]::CreateDirectory($casEvidence)
    $artifactA = Join-Path $testRoot "artifact-a.bin"
    $artifactB = Join-Path $testRoot "artifact-b.bin"
    [System.IO.File]::WriteAllBytes($artifactA, [byte[]](10, 20, 30))
    [System.IO.File]::WriteAllBytes($artifactB, [byte[]](40, 50, 60, 70))
    $publishedA = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $casRepo `
        -ArtifactPath $artifactA `
        -EvidenceRootOverride $casEvidence `
        -TestOnly
    $digestA = [string]$publishedA.sha256
    $casSource = Join-Path $casRepo "references.ps1"
    [System.IO.File]::WriteAllText(
        $casSource,
        ('# artifacts/sha256/' + $digestA.Substring(7) + '/payload.bin' + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    $casInventoryA = Get-SporeSporeReferencedCasInventory `
        -RepoRoot $casRepo `
        -SourceRelativePaths @("references.ps1") `
        -EvidenceRoot $casEvidence
    Assert-DependencyKey `
        ($casInventoryA.explicit_reference_count -eq 1 -and
            $casInventoryA.matched_object_count -eq 1 -and
            $casInventoryA.matched_payload_byte_count -eq 3 -and
            -not [bool]$casInventoryA.unrelated_cas_objects_in_key -and
            [string]$casInventoryA.entries[0].sha256 -ceq $digestA) `
        "referenced CAS inventory included the wrong object set"
    $publishedB = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $casRepo `
        -ArtifactPath $artifactB `
        -EvidenceRootOverride $casEvidence `
        -TestOnly
    $casInventoryAfterUnrelatedAppend = Get-SporeSporeReferencedCasInventory `
        -RepoRoot $casRepo `
        -SourceRelativePaths @("references.ps1") `
        -EvidenceRoot $casEvidence
    Assert-DependencyKey `
        ([string]$casInventoryA.inventory_sha256 -ceq
            [string]$casInventoryAfterUnrelatedAppend.inventory_sha256 -and
            $casInventoryAfterUnrelatedAppend.matched_object_count -eq 1) `
        "unrelated CAS append invalidated the referenced inventory"
    [System.IO.File]::WriteAllBytes(
        $publishedA.payload_path,
        [byte[]](10, 20, 31)
    )
    $corruptionRejected = $false
    try {
        [void](Get-SporeSporeReferencedCasInventory `
            -RepoRoot $casRepo `
            -SourceRelativePaths @("references.ps1") `
            -EvidenceRoot $casEvidence)
    } catch { $corruptionRejected = $true }
    Assert-DependencyKey $corruptionRejected "corrupt referenced CAS payload was accepted"
    $missingDigest = "0" * 64
    [System.IO.File]::WriteAllText(
        $casSource,
        ('# artifacts/sha256/' + $missingDigest + '/payload.bin' + "`n"),
        [System.Text.UTF8Encoding]::new($false)
    )
    $missingCasRejected = $false
    try {
        [void](Get-SporeSporeReferencedCasInventory `
            -RepoRoot $casRepo `
            -SourceRelativePaths @("references.ps1") `
            -EvidenceRoot $casEvidence)
    } catch { $missingCasRejected = $true }
    Assert-DependencyKey $missingCasRejected "explicit missing CAS object was accepted"

    Write-Output (
        "CONFORMANCE_DEPENDENCY_KEY_PASS files=2 root_independent=True " +
        "order_independent=True content_mutation=True missing_refusal=True " +
        "escape_refusal=True reparse_refusal=True duplicate_refusal=True " +
        "environment_mutation=True " +
        "dynamic_lookup_classified=True runtime_mutation=True cache=disabled " +
        "cas_reference=True cas_corruption_refusal=True " +
        "cas_missing_refusal=True cas_unrelated_append_stable=True " +
        "live_files=$($liveCandidate.source.tracked_file_count) " +
        "live_environment_names=$($liveCandidate.environment.referenced_name_count) " +
        "live_process_environment_names=$($liveCandidate.environment.complete_process_name_count) " +
        "live_cas_objects=$($liveCandidate.evidence.matched_object_count) " +
        "worlds=0 physical_authority=False"
    )
} finally {
    [Environment]::SetEnvironmentVariable(
        "SPORESPORE_DEPENDENCY_TEST_SECRET",
        $oldSecret,
        "Process"
    )
    if ($null -eq $oldEmpty) {
        Remove-Item -LiteralPath "Env:$emptyName" -ErrorAction SilentlyContinue
    } else {
        Set-Item -LiteralPath "Env:$emptyName" -Value $oldEmpty
    }
    if ($null -eq $oldMissing) {
        Remove-Item -LiteralPath "Env:$missingName" -ErrorAction SilentlyContinue
    } else {
        Set-Item -LiteralPath "Env:$missingName" -Value $oldMissing
    }
    [Environment]::SetEnvironmentVariable(
        $unreferencedName,
        $oldUnreferenced,
        "Process"
    )
    $resolvedTestRoot = [System.IO.Path]::GetFullPath($testRoot)
    $safePrefix = $targetParent.TrimEnd('\', '/') +
        [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTestRoot.StartsWith(
        $safePrefix,
        [StringComparison]::OrdinalIgnoreCase
    ) -or (Split-Path -Leaf $resolvedTestRoot) -notlike
        "conformance-dependency-key-test-*") {
        throw "Refusing unsafe conformance-dependency-key test cleanup: $resolvedTestRoot"
    }
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
