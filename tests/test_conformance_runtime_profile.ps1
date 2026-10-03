#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$dependencyModulePath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$runtimeModulePath = Join-Path $sdkRoot "conformance_runtime_profile.ps1"
$contractPath = Join-Path $sdkRoot "conformance_runtime_profile_contract_v1.json"
$registryPath = Join-Path $sdkRoot "conformance_runtime_profile_registry_v1.json"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-RuntimeProfile([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "CONFORMANCE_RUNTIME_PROFILE $Message"
    }
}

foreach ($path in @(
    $dependencyModulePath,
    $runtimeModulePath,
    $contractPath,
    $registryPath,
    $runnerPath
)) {
    Assert-RuntimeProfile `
        (Test-Path -LiteralPath $path -PathType Leaf) `
        "required source is missing: $path"
}
[void][scriptblock]::Create((Get-Content -LiteralPath $runtimeModulePath -Raw))
. $dependencyModulePath

$contract = Get-SporeSporeConformanceRuntimeProfileContract
$registry = Get-SporeSporeConformanceRuntimeProfileRegistry
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-RuntimeProfile (
    [int]$contract.profile_authority.registered_profile_count -eq 1 -and
    [int]$contract.profile_authority.complete_profile_count -eq 1 -and
    [int]$contract.profile_authority.registered_audit_binding_count -eq 1 -and
    [int]$contract.profile_authority.complete_audit_binding_count -eq 1 -and
    -not [bool]$contract.claims.runtime_inventory_complete -and
    -not [bool]$contract.claims.host_semantics_complete -and
    -not [bool]$contract.claims.cache_lookup_permitted -and
    -not [bool]$contract.claims.result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    [int]$registry.registered_profile_count -eq 1 -and
    [int]$registry.complete_profile_count -eq 1 -and
    -not [bool]$registry.result_reuse_permitted -and
    $runnerSource.Contains(
        "tests\test_conformance_runtime_profile.ps1",
        [StringComparison]::Ordinal
    )
) "contract, registry, or canonical runner exceeded the profile boundary"

$live = Get-SporeSporeConformanceRuntimeProfileCandidate -RepoRoot $repoRoot
$profile = @($live.profiles)[0]
Assert-RuntimeProfile (
    [string]$live.schema_version -ceq
        "sporespore_conformance_runtime_profile_candidate_v1" -and
    [string]$live.status -ceq "partial_runtime_profile_cache_disabled" -and
    [int]$live.registered_profile_count -eq 1 -and
    [int]$live.complete_profile_count -eq 1 -and
    [int]$live.registered_audit_binding_count -eq 1 -and
    [int]$live.complete_audit_binding_count -eq 1 -and
    [string]$live.inventory_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
    [string]$profile.profile_id -ceq
        "windows-powershell-git-r23d13-parent-child-v2" -and
    [int]$profile.measured_source.file_count -eq 7 -and
    [long]$profile.measured_source.byte_count -eq 147207 -and
    [string]$profile.measured_source.inventory_sha256 -cmatch
        "^sha256:[0-9a-f]{64}$" -and
    [int]$profile.powershell.file_count -eq 86 -and
    [long]$profile.powershell.byte_count -gt 0 -and
    [string]$profile.powershell.inventory_sha256 -cmatch
        "^sha256:[0-9a-f]{64}$" -and
    [int]$profile.git.file_count -eq 7 -and
    [long]$profile.git.byte_count -gt 0 -and
    [int]$profile.git.configuration_file_count -eq 3 -and
    [string]$profile.git.inventory_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
    @($profile.git.configuration | Where-Object {
        [bool]$_.raw_value_retained -or
        $_.Contains("absolute_path") -or
        $_.Contains("raw_value")
    }).Count -eq 0 -and
    [int]$profile.host.windows_file_count -eq 59 -and
    [long]$profile.host.windows_byte_count -eq 57481608 -and
    [string]$profile.host.windows_inventory_sha256 -cmatch
        "^sha256:[0-9a-f]{64}$" -and
    [int]$profile.host.defender_file_count -eq 2 -and
    [long]$profile.host.defender_byte_count -eq 2506800 -and
    [string]$profile.host.defender_inventory_sha256 -cmatch
        "^sha256:[0-9a-f]{64}$" -and
    [string]$profile.host.inventory_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
    [string]$profile.host.semantics.source_volume_format -ceq "NTFS" -and
    [bool]$profile.declared_runtime_files_complete -and
    [bool]$profile.native_child_reads_complete -and
    [bool]$profile.host_semantics_complete -and
    [bool]$profile.audit_binding_complete -and
    [bool]$registry.profiles[0].completeness_scope.
        closed_child_refuses_before_git_engine_model_worker_or_world_route -and
    -not [bool]$registry.profiles[0].completeness_scope.
        wall_clock_or_scheduling_threshold_in_exact_audit_route -and
    -not [bool]$registry.profiles[0].completeness_scope.
        scope_extends_to_other_audits_or_physical_routes -and
    -not [bool]$live.raw_git_configuration_values_retained -and
    -not [bool]$live.runtime_inventory_complete -and
    -not [bool]$live.host_semantics_complete -and
    -not [bool]$live.transitive_dependency_complete -and
    -not [bool]$live.cache_lookup_permitted -and
    -not [bool]$live.result_reuse_permitted -and
    -not [bool]$live.physical_authority
) "live runtime profile was malformed, leaked config, or exceeded authority"

$targetParent = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
$testRoot = Join-Path $targetParent (
    "conformance-runtime-profile-test-" + [guid]::NewGuid().ToString("N")
)
$rootA = Join-Path $testRoot "root-a"
$rootB = Join-Path $testRoot "root-b"
[void][System.IO.Directory]::CreateDirectory($rootA)
[void][System.IO.Directory]::CreateDirectory($rootB)
try {
    foreach ($root in @($rootA, $rootB)) {
        [System.IO.File]::WriteAllText(
            (Join-Path $root "runtime.dll"),
            "same-runtime`n",
            [System.Text.UTF8Encoding]::new($false)
        )
    }
    $runtimeA = Get-SporeSporeDeclaredFileInventory `
        -Root $rootA `
        -RelativePaths @("runtime.dll") `
        -InventoryId "synthetic_runtime"
    $runtimeB = Get-SporeSporeDeclaredFileInventory `
        -Root $rootB `
        -RelativePaths @("runtime.dll") `
        -InventoryId "synthetic_runtime"
    Assert-RuntimeProfile (
        [string]$runtimeA.inventory_sha256 -ceq
        [string]$runtimeB.inventory_sha256
    ) "runtime inventory was not install-root independent"

    [System.IO.File]::WriteAllText(
        (Join-Path $rootB "runtime.dll"),
        "changed-runtime`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $runtimeChanged = Get-SporeSporeDeclaredFileInventory `
        -Root $rootB `
        -RelativePaths @("runtime.dll") `
        -InventoryId "synthetic_runtime"
    Assert-RuntimeProfile (
        [string]$runtimeA.inventory_sha256 -cne
        [string]$runtimeChanged.inventory_sha256
    ) "runtime file mutation did not invalidate the inventory"

    $secretText = "credential.example=do-not-retain-this-value`n"
    [System.IO.File]::WriteAllText(
        (Join-Path $rootA ".gitconfig"),
        $secretText,
        [System.Text.UTF8Encoding]::new($false)
    )
    $configReceipt = Get-SporeSporeRuntimeConfigFileReceipt `
        -Role "synthetic" `
        -Root $rootA `
        -RelativePath ".gitconfig"
    $serializedConfig = $configReceipt | ConvertTo-Json -Compress
    Assert-RuntimeProfile (
        [string]$configReceipt.raw_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
        -not [bool]$configReceipt.raw_value_retained -and
        -not $serializedConfig.Contains(
            "do-not-retain-this-value",
            [StringComparison]::Ordinal
        )
    ) "runtime configuration receipt retained a raw value"

    $registryOriginalPath = $script:SporeSporeRuntimeProfileRegistryPath
    $registryMutation = $registry | ConvertTo-Json -Depth 64 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 64
    $registryMutation.profiles[0].host.semantics.time_zone = "Mutated/Zone"
    $registryMutationPath = Join-Path $testRoot "mutated-registry.json"
    [System.IO.File]::WriteAllText(
        $registryMutationPath,
        ($registryMutation | ConvertTo-Json -Depth 64) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $hostMutationRejected = $false
    try {
        $script:SporeSporeRuntimeProfileRegistryPath = $registryMutationPath
        [void](Get-SporeSporeConformanceRuntimeProfileCandidate -RepoRoot $repoRoot)
    } catch { $hostMutationRejected = $true }
    finally { $script:SporeSporeRuntimeProfileRegistryPath = $registryOriginalPath }
    Assert-RuntimeProfile $hostMutationRejected `
        "host semantic mutation was accepted by the completed profile"

    $sourceMutation = $registry | ConvertTo-Json -Depth 64 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 64
    $sourceMutation.profiles[0].measured_source_bindings[0].raw_sha256 =
        "sha256:" + ("0" * 64)
    $sourceMutationPath = Join-Path $testRoot "source-mutated-registry.json"
    [System.IO.File]::WriteAllText(
        $sourceMutationPath,
        ($sourceMutation | ConvertTo-Json -Depth 64) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    $sourceMutationRejected = $false
    try {
        $script:SporeSporeRuntimeProfileRegistryPath = $sourceMutationPath
        [void](Get-SporeSporeConformanceRuntimeProfileCandidate -RepoRoot $repoRoot)
    } catch { $sourceMutationRejected = $true }
    finally { $script:SporeSporeRuntimeProfileRegistryPath = $registryOriginalPath }
    Assert-RuntimeProfile $sourceMutationRejected `
        "measured source mutation was accepted by the completed profile"

    $missingRejected = $false
    try {
        [void](Get-SporeSporeDeclaredFileInventory `
            -Root $rootA `
            -RelativePaths @("missing.dll") `
            -InventoryId "missing_runtime")
    } catch { $missingRejected = $true }
    Assert-RuntimeProfile $missingRejected "missing runtime file was accepted"

    Write-Output (
        "CONFORMANCE_RUNTIME_PROFILE_PASS profiles=1 complete=1 " +
        "audit_bindings=1 binding_complete=1 measured_sources=7 " +
        "powershell_files=86 git_files=7 windows_files=59 defender_files=2 " +
        "git_configs=3 root_independent=True runtime_mutation=True " +
        "host_mutation=True source_mutation=True config_redaction=True " +
        "missing_refusal=True profile_host_complete=True " +
        "aggregate_host_complete=False cache=disabled worlds=0 " +
        "physical_authority=False"
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
