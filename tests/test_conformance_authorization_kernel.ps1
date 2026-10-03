#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$modulePath = Join-Path $sdkRoot "conformance_authorization_kernel.ps1"
$contractPath = Join-Path $sdkRoot "conformance_authorization_kernel_contract_v1.json"
$manifestPath = Join-Path $sdkRoot "conformance_authorization_kernel_manifest_v1.json"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-AuthorizationKernel([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw "CONFORMANCE_AUTHORIZATION_KERNEL $Message"
    }
}

foreach ($path in @($modulePath, $contractPath, $manifestPath, $runnerPath)) {
    Assert-AuthorizationKernel `
        (Test-Path -LiteralPath $path -PathType Leaf) `
        "required source is missing: $path"
}
[void][scriptblock]::Create((Get-Content -LiteralPath $modulePath -Raw))
. $modulePath

$contract = Get-SporeSporeConformanceAuthorizationKernelContract
$manifest = Get-SporeSporeConformanceAuthorizationKernelManifest
$live = Get-SporeSporeConformanceAuthorizationKernelCandidate -RepoRoot $repoRoot
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-AuthorizationKernel (
    [int]$contract.authority.global_gate_count -eq 12 -and
    [int]$contract.authority.required_campaign_negative_control_role_count -eq 3 -and
    @($contract.required_global_safeguards).Count -eq 12 -and
    @($manifest.gates).Count -eq 12 -and
    @($manifest.required_campaign_negative_control_roles).Count -eq 3 -and
    $runnerSource.Contains(
        "tests\test_conformance_authorization_kernel.ps1",
        [StringComparison]::Ordinal
    ) -and
    [string]$live.schema_version -ceq
        "sporespore_conformance_authorization_kernel_candidate_v1" -and
    [string]$live.status -ceq
        "declared_unexecuted_uncommissioned_authority_disabled" -and
    [string]$live.inventory_sha256 -cmatch "^sha256:[0-9a-f]{64}$" -and
    [int]$live.global_gate_count -eq 12 -and
    [int]$live.godot_required_gate_count -eq 3 -and
    [int]$live.campaign_negative_control_role_count -eq 3 -and
    [bool]$live.global_gate_declaration_complete -and
    [bool]$live.canonical_runner_bindings_complete -and
    -not [bool]$live.global_gate_execution_complete -and
    -not [bool]$live.campaign_negative_controls_complete -and
    -not [bool]$live.cold_equivalence_complete -and
    -not [bool]$live.kernel_commissioned -and
    -not [bool]$live.cache_lookup_permitted -and
    -not [bool]$live.result_reuse_permitted -and
    -not [bool]$live.physical_launch_permitted -and
    -not [bool]$live.physical_authority -and
    -not [bool]$live.release_authority
) "live kernel candidate was malformed or exceeded authority"

$targetParent = [System.IO.Path]::GetFullPath((Join-Path $sdkRoot "target"))
$testRoot = Join-Path $targetParent (
    "conformance-authorization-kernel-test-" + [guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($testRoot)
function Write-TestJson([string]$Path, [object]$Value) {
    [System.IO.File]::WriteAllText(
        $Path,
        ($Value | ConvertTo-Json -Depth 64) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
}
function Copy-Json([object]$Value) {
    return $Value | ConvertTo-Json -Depth 64 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 64
}
function Assert-Rejected([scriptblock]$Action, [string]$Label) {
    $rejected = $false
    try { & $Action } catch { $rejected = $true }
    Assert-AuthorizationKernel $rejected "$Label was accepted"
}

try {
    $duplicate = Copy-Json $manifest
    $duplicate.gates[1].gate_id = [string]$duplicate.gates[0].gate_id
    $duplicatePath = Join-Path $testRoot "duplicate.json"
    Write-TestJson $duplicatePath $duplicate
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $duplicatePath -TestOnly)
    } "duplicate gate identity"

    $reordered = Copy-Json $manifest
    $reordered.gates[1].ordinal = 7
    $reorderedPath = Join-Path $testRoot "reordered.json"
    Write-TestJson $reorderedPath $reordered
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $reorderedPath -TestOnly)
    } "non-sequential gate ordinal"

    $missing = Copy-Json $manifest
    $missing.gates[0].path = "tests/does_not_exist.ps1"
    $missingPath = Join-Path $testRoot "missing.json"
    Write-TestJson $missingPath $missing
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $missingPath -TestOnly)
    } "missing gate source"

    $escape = Copy-Json $manifest
    $escape.gates[0].path = "../outside.ps1"
    $escapePath = Join-Path $testRoot "escape.json"
    Write-TestJson $escapePath $escape
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $escapePath -TestOnly)
    } "repository path escape"

    $marker = Copy-Json $manifest
    $marker.gates[0].canonical_runner_marker = "ABSENT_KERNEL_MARKER"
    $markerPath = Join-Path $testRoot "marker.json"
    Write-TestJson $markerPath $marker
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $markerPath -TestOnly)
    } "missing canonical runner binding"

    $role = Copy-Json $manifest
    $role.required_campaign_negative_control_roles[0].bound = $true
    $rolePath = Join-Path $testRoot "role.json"
    Write-TestJson $rolePath $role
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $rolePath -TestOnly)
    } "undeclared campaign-role binding"

    $unsafe = Copy-Json $manifest
    $unsafe.gates[8].arguments = @("-SkipBuild", "-RunPhysical")
    $unsafePath = Join-Path $testRoot "unsafe.json"
    Write-TestJson $unsafePath $unsafe
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ManifestPath $unsafePath -TestOnly)
    } "physical invocation argument"

    $inflated = Copy-Json $contract
    $inflated.claims.physical_launch_permitted = $true
    $inflatedPath = Join-Path $testRoot "inflated.json"
    Write-TestJson $inflatedPath $inflated
    Assert-Rejected {
        [void](Get-SporeSporeConformanceAuthorizationKernelCandidate `
            -RepoRoot $repoRoot -ContractPath $inflatedPath -TestOnly)
    } "inflated physical-launch claim"

    $argumentMutation = Copy-Json $manifest
    $argumentMutation.gates[8].arguments = @("-SkipBuild", "-SyntheticMutation")
    $argumentPath = Join-Path $testRoot "argument.json"
    Write-TestJson $argumentPath $argumentMutation
    $mutated = Get-SporeSporeConformanceAuthorizationKernelCandidate `
        -RepoRoot $repoRoot -ManifestPath $argumentPath -TestOnly
    Assert-AuthorizationKernel (
        [string]$mutated.inventory_sha256 -cne [string]$live.inventory_sha256
    ) "invocation-argument mutation did not invalidate the kernel digest"

    Write-Output (
        "CONFORMANCE_AUTHORIZATION_KERNEL_PASS global_gates=12 " +
        "godot_required=3 campaign_roles=3 declarations=True " +
        "runner_bindings=True execution_complete=False roles_bound=False " +
        "cold_equivalence=False commissioned=False cache=disabled " +
        "worlds=0 physical_authority=False release_authority=False"
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
