#requires -Version 7.0

Set-StrictMode -Version Latest

$script:SporeSporeCampaignAttestationSchema =
    "sporespore_locomotion_campaign_attestation_v1"
$script:SporeSporeCampaignAttestationContractPath = Join-Path `
    $PSScriptRoot "locomotion_campaign_attestation_contract_v1.json"
$script:SporeSporeCampaignAttestationRunnerPath = Join-Path `
    $PSScriptRoot "run_locomotion_campaign_attestation.ps1"
$script:SporeSporeCampaignAttestationCoreBindingPaths = @(
    "sdk/run_conformance.ps1",
    "sdk/run_locomotion_campaign_attestation.ps1",
    "sdk/locomotion_campaign_attestation.ps1",
    "sdk/locomotion_campaign_attestation_contract_v1.json",
    "sdk/locomotion_operation_lock.ps1",
    "sdk/locomotion_full_conformance_attestation.ps1",
    "sdk/content_addressed_artifact_store.ps1",
    "sdk/conformance_authorization_kernel.ps1",
    "sdk/conformance_authorization_kernel_contract_v1.json",
    "sdk/conformance_authorization_kernel_manifest_v1.json"
)
$script:SporeSporeCampaignAttestationClaimNames = @(
    "campaign_local_qualification_passed",
    "cold_commissioning_complete",
    "physical_launch_prerequisite_satisfied",
    "physical_campaign_executed",
    "scientific_result",
    "walking_acceptance",
    "turning_acceptance",
    "cross_engine_equivalence",
    "arbitrary_quadruped_coverage",
    "release_authority",
    "physical_acceptance_authority"
)

. (Join-Path $PSScriptRoot "locomotion_operation_lock.ps1")
. (Join-Path $PSScriptRoot "locomotion_full_conformance_attestation.ps1")
. (Join-Path $PSScriptRoot "content_addressed_artifact_store.ps1")
. (Join-Path $PSScriptRoot "conformance_authorization_kernel.ps1")

function Get-SporeSporeCampaignAttestationSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-SporeSporeCampaignAttestationObjectSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Value)
    $json = $Value | ConvertTo-Json -Depth 100 -Compress
    $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
    return "sha256:" + [Convert]::ToHexString(
        [Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Copy-SporeSporeCampaignAttestationObject {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Value)
    return $Value | ConvertTo-Json -Depth 100 -Compress |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Get-SporeSporeCampaignAttestationContract {
    [CmdletBinding()]
    param([string]$Path = $script:SporeSporeCampaignAttestationContractPath)
    $contract = Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    if ([string]$contract.schema_version -cne
        "sporespore_locomotion_campaign_attestation_contract_v1" -or
        [string]$contract.status -cne
        "prospective_uncommissioned_physical_authority_disabled" -or
        [int]$contract.global_kernel.required_gate_count -ne 12 -or
        @($contract.global_kernel.required_safeguards).Count -ne 12 -or
        @($contract.campaign_scope.required_negative_control_roles).Count -ne 3 -or
        -not [bool]$contract.claims.campaign_local_attestation_implemented -or
        [bool]$contract.commissioning.commissioned -or
        [bool]$contract.commissioning.physical_launch_prerequisite_may_be_satisfied) {
        throw "Campaign-local attestation contract exceeds its prospective authority."
    }
    foreach ($name in $script:SporeSporeCampaignAttestationClaimNames) {
        if ($name -ceq "campaign_local_qualification_passed") {
            if ([bool]$contract.claims[$name]) {
                throw "Campaign-local attestation contract pre-claims qualification."
            }
            continue
        }
        if (-not $contract.claims.Contains($name) -or [bool]$contract.claims[$name]) {
            throw "Campaign-local attestation contract inflates claim '$name'."
        }
    }
    return $contract
}

function Resolve-SporeSporeCampaignAttestationPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath.Contains("\") -or
        $RelativePath.Contains("`r") -or
        $RelativePath.Contains("`n")) {
        throw "Campaign-local attestation path is not canonical: $RelativePath"
    }
    $segments = @($RelativePath.Split('/'))
    if ($segments.Count -eq 0 -or @($segments | Where-Object {
        [string]::IsNullOrEmpty($_) -or $_ -ceq "." -or $_ -ceq ".."
    }).Count -ne 0) {
        throw "Campaign-local attestation path escapes or is empty: $RelativePath"
    }
    $root = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $absolute = [IO.Path]::GetFullPath(
        (Join-Path $root ($RelativePath.Replace('/', '\')))
    )
    $prefix = $root + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Campaign-local attestation path escaped the repository: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        throw "Campaign-local attestation source is missing: $RelativePath"
    }
    $cursor = $absolute
    while (-not $cursor.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Campaign-local attestation path contains a reparse point: $RelativePath"
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -ceq $cursor) {
            throw "Campaign-local attestation path ancestry is invalid: $RelativePath"
        }
        $cursor = $parent
    }
    return [ordered]@{
        relative_path = $RelativePath
        absolute_path = $absolute
    }
}

function Get-SporeSporeCampaignAttestationGitBlobOid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    return Invoke-SporeSporeAttestationGit $RepoRoot @(
        "rev-parse", "${Commit}:$RelativePath"
    )
}

function Get-SporeSporeCampaignAttestationGitBlobRawSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Commit,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "git"
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-C", $RepoRoot, "cat-file", "blob", "${Commit}:$RelativePath"
    )) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    try {
        if (-not $process.Start()) {
            throw "Campaign-local attestation could not start Git blob reader."
        }
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $hasher = [Security.Cryptography.SHA256]::Create()
        try {
            $digest = $hasher.ComputeHash($process.StandardOutput.BaseStream)
        } finally { $hasher.Dispose() }
        $process.WaitForExit()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "Campaign-local Git blob read failed for $RelativePath`: $stderr"
        }
        return "sha256:" + [Convert]::ToHexString($digest).ToLowerInvariant()
    } finally { $process.Dispose() }
}

function Get-SporeSporeCampaignAttestationManifest {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    $manifest = Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    if ([string]$manifest.schema_version -cne
        "sporespore_locomotion_campaign_attestation_manifest_v1" -or
        [string]$manifest.status -cnotin @(
            "cold_commissioning_only",
            "prospective_zero_world_physical_candidate"
        ) -or
        [string]::IsNullOrWhiteSpace([string]$manifest.campaign_id) -or
        [string]$manifest.question_class -cnotin @(
            "development", "finite_decision", "superiority",
            "equivalence_non_inferiority"
        ) -or
        -not [bool]$manifest.godot_including -or
        [bool]$manifest.skip_godot -or
        [bool]$manifest.physical_execution_authorized -or
        [bool]$manifest.physical_acceptance_authority -or
        [bool]$manifest.release_authority) {
        throw "Campaign-local attestation manifest is malformed or exceeds authority."
    }
    if (([string]$manifest.status -ceq "cold_commissioning_only" -and (
            [bool]$manifest.physical_launch_candidate -or
            [int]$manifest.declared_physical_world_count -ne 0
        )) -or
        ([string]$manifest.status -ceq
            "prospective_zero_world_physical_candidate" -and (
            -not [bool]$manifest.physical_launch_candidate -or
            [int]$manifest.declared_physical_world_count -lt 1
        ))) {
        throw "Campaign-local attestation manifest launch-candidate scope drifted."
    }
    $claimNames = @($manifest.claims.Keys | Sort-Object)
    $expectedClaimNames = @($script:SporeSporeCampaignAttestationClaimNames |
        Sort-Object)
    if (($claimNames | ConvertTo-Json -Compress) -cne
        ($expectedClaimNames | ConvertTo-Json -Compress)) {
        throw "Campaign-local attestation manifest claim schema drifted."
    }
    foreach ($name in $script:SporeSporeCampaignAttestationClaimNames) {
        if ([bool]$manifest.claims[$name]) {
            throw "Campaign-local attestation manifest inflates claim '$name'."
        }
    }
    return $manifest
}

function Test-SporeSporeCampaignAttestationUnsafeArgument {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Argument)
    return (
        $Argument.Contains("`r") -or $Argument.Contains("`n") -or
        $Argument -cmatch '(?i)(^|[-_/])run[-_]?physical($|[-_/])' -or
        $Argument -cmatch '(?i)(^|[-_/])authorize[-_]?physical($|[-_/])' -or
        $Argument -cmatch '(?i)(^|[-_/])physical[-_]?execution($|[-_/])'
    )
}

function Get-SporeSporeCampaignAttestationCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [string]$ContractPath = $script:SporeSporeCampaignAttestationContractPath,
        [string]$CanonicalRunnerPath = (Join-Path $PSScriptRoot "run_conformance.ps1"),
        [switch]$TestOnly
    )
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $contract = Get-SporeSporeCampaignAttestationContract -Path $ContractPath
    $manifestResolved = [IO.Path]::GetFullPath($ManifestPath)
    if (-not (Test-Path -LiteralPath $manifestResolved -PathType Leaf)) {
        throw "Campaign-local attestation manifest is missing."
    }
    $manifest = Get-SporeSporeCampaignAttestationManifest -Path $manifestResolved
    $repoPrefix = $repo + [IO.Path]::DirectorySeparatorChar
    if (-not $manifestResolved.StartsWith(
        $repoPrefix,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Campaign-local attestation manifest must be inside the repository."
    }
    $manifestRelative = $manifestResolved.Substring($repoPrefix.Length).
        Replace('\', '/')
    $kernel = Get-SporeSporeConformanceAuthorizationKernelCandidate `
        -RepoRoot $repo `
        -RunnerPath $CanonicalRunnerPath `
        -TestOnly:$TestOnly
    if ([int]$kernel.global_gate_count -ne
        [int]$contract.global_kernel.required_gate_count -or
        [int]$kernel.godot_required_gate_count -lt 1 -or
        -not [bool]$kernel.global_gate_declaration_complete -or
        -not [bool]$kernel.canonical_runner_bindings_complete) {
        throw "Campaign-local attestation global safety kernel is incomplete."
    }
    $requiredSafeguards = @($contract.global_kernel.required_safeguards)
    for ($index = 0; $index -lt $requiredSafeguards.Count; $index++) {
        if ([string]$kernel.gates[$index].safeguard_id -cne
            [string]$requiredSafeguards[$index]) {
            throw "Campaign-local attestation global safeguard order drifted."
        }
    }

    $tracked = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    if (-not $TestOnly) {
        $trackedOutput = @(& git -C $repo -c core.quotePath=false ls-files --cached)
        if ($LASTEXITCODE -ne 0) {
            throw "Campaign-local attestation tracked-path inventory failed."
        }
        foreach ($line in $trackedOutput) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                [void]$tracked.Add(([string]$line).Replace('\', '/'))
            }
        }
    }

    $coreBindingReceipts = [Collections.Generic.List[object]]::new()
    foreach ($relativePath in @($script:SporeSporeCampaignAttestationCoreBindingPaths) +
        @($manifestRelative)) {
        $resolved = Resolve-SporeSporeCampaignAttestationPath `
            -RepoRoot $repo -RelativePath $relativePath
        if (-not $TestOnly -and -not $tracked.Contains($relativePath)) {
            throw "Campaign-local core source is not tracked: $relativePath"
        }
        $actualHash = Get-SporeSporeCampaignAttestationSha256 `
            $resolved.absolute_path
        $gitBlob = if ($TestOnly -and -not $tracked.Contains($relativePath)) {
            "test-only-untracked"
        } else {
            Get-SporeSporeCampaignAttestationGitBlobOid `
                -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
        }
        $gitBlobRaw = if ($TestOnly -and -not $tracked.Contains($relativePath)) {
            "test-only-untracked"
        } else {
            Get-SporeSporeCampaignAttestationGitBlobRawSha256 `
                -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
        }
        if (-not $TestOnly -and $actualHash -cne $gitBlobRaw) {
            throw "Campaign-local core checkout differs from Git blob: $relativePath"
        }
        $coreBindingReceipts.Add([ordered]@{
            path = $relativePath
            raw_sha256 = $actualHash
            git_blob_oid = $gitBlob
            git_blob_raw_sha256 = $gitBlobRaw
        })
    }

    $globalGateReceipts = [Collections.Generic.List[object]]::new()
    foreach ($gate in @($kernel.gates)) {
        $relativePath = [string]$gate.path
        $resolved = Resolve-SporeSporeCampaignAttestationPath `
            -RepoRoot $repo -RelativePath $relativePath
        $actualHash = Get-SporeSporeCampaignAttestationSha256 `
            $resolved.absolute_path
        if ($actualHash -cne [string]$gate.raw_sha256) {
            throw "Campaign-local global-kernel source drifted: $relativePath"
        }
        $globalGateReceipts.Add([ordered]@{
            ordinal = [int]$gate.ordinal
            gate_id = [string]$gate.gate_id
            safeguard_id = [string]$gate.safeguard_id
            invocation_kind = [string]$gate.invocation_kind
            path = $relativePath
            arguments = @($gate.arguments)
            canonical_runner_marker = [string]$gate.canonical_runner_marker
            requires_godot = [bool]$gate.requires_godot
            byte_length = [long]$gate.byte_length
            raw_sha256 = $actualHash
            git_blob_oid = if ($TestOnly) { "test-only-untracked" } else {
                Get-SporeSporeCampaignAttestationGitBlobOid `
                    -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
            }
            git_blob_raw_sha256 = if ($TestOnly) { "test-only-untracked" } else {
                Get-SporeSporeCampaignAttestationGitBlobRawSha256 `
                    -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
            }
        })
    }

    $allGates = @($manifest.lineage_gates) + @($manifest.campaign_gates)
    if (@($manifest.lineage_gates).Count -lt 1 -or
        @($manifest.campaign_gates).Count -lt 3 -or
        [int]$manifest.declared_lineage_gate_count -ne
            @($manifest.lineage_gates).Count -or
        [int]$manifest.declared_campaign_gate_count -ne
            @($manifest.campaign_gates).Count -or
        [int]$manifest.declared_total_gate_count -ne $allGates.Count) {
        throw "Campaign-local attestation gate counts disagree."
    }
    $ids = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $roleCounts = [ordered]@{ worker = 0; evaluator = 0; supervisor = 0 }
    $gateReceipts = [Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $allGates.Count; $index++) {
        $gate = $allGates[$index]
        $ordinal = $index + 1
        $gateId = [string]$gate.gate_id
        $role = [string]$gate.role
        $kind = [string]$gate.invocation_kind
        $relativePath = [string]$gate.path
        $marker = [string]$gate.terminal_marker_prefix
        if ([int]$gate.ordinal -ne $ordinal -or
            [string]::IsNullOrWhiteSpace($gateId) -or -not $ids.Add($gateId) -or
            $gateId -cnotmatch '^[A-Z0-9][A-Z0-9_.-]{2,95}$' -or
            $kind -cnotin @("powershell_file", "godot_script", "python_file",
                "python_unittest") -or
            [string]::IsNullOrWhiteSpace($marker) -or
            $marker.Contains("`r") -or $marker.Contains("`n") -or
            @($gate.arguments | Where-Object {
                Test-SporeSporeCampaignAttestationUnsafeArgument ([string]$_)
            }).Count -ne 0) {
            throw "Campaign-local attestation gate semantics are invalid: $gateId"
        }
        if ($index -lt @($manifest.lineage_gates).Count) {
            if ($role -cne "lineage") {
                throw "Campaign-local lineage gate role drifted: $gateId"
            }
        } else {
            if (-not $roleCounts.Contains($role)) {
                throw "Campaign-local campaign gate role is invalid: $gateId"
            }
            $roleCounts[$role] = [int]$roleCounts[$role] + 1
        }
        $expectedExtension = switch ($kind) {
            "powershell_file" { ".ps1" }
            "godot_script" { ".gd" }
            "python_file" { ".py" }
            "python_unittest" { ".py" }
        }
        if ([IO.Path]::GetExtension($relativePath) -cne $expectedExtension) {
            throw "Campaign-local gate extension does not match invocation: $gateId"
        }
        $resolved = Resolve-SporeSporeCampaignAttestationPath `
            -RepoRoot $repo `
            -RelativePath $relativePath
        $actualHash = Get-SporeSporeCampaignAttestationSha256 `
            -Path $resolved.absolute_path
        if ([string]$gate.raw_sha256 -cne $actualHash) {
            throw "Campaign-local gate raw digest drifted: $gateId"
        }
        if (-not $TestOnly -and -not $tracked.Contains($relativePath)) {
            throw "Campaign-local gate source is not tracked: $relativePath"
        }
        $gitBlob = if ($TestOnly) { "test-only-untracked" } else {
            Get-SporeSporeCampaignAttestationGitBlobOid `
                -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
        }
        $gitBlobRaw = if ($TestOnly) { "test-only-untracked" } else {
            Get-SporeSporeCampaignAttestationGitBlobRawSha256 `
                -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
        }
        if (-not $TestOnly -and $actualHash -cne $gitBlobRaw) {
            throw "Campaign-local gate checkout differs from Git blob: $gateId"
        }
        $gateReceipts.Add([ordered]@{
            ordinal = $ordinal
            gate_id = $gateId
            role = $role
            invocation_kind = $kind
            path = $relativePath
            absolute_path = $resolved.absolute_path
            arguments = @($gate.arguments)
            terminal_marker_prefix = $marker
            raw_sha256 = $actualHash
            git_blob_oid = $gitBlob
            git_blob_raw_sha256 = $gitBlobRaw
        })
    }
    foreach ($role in @("worker", "evaluator", "supervisor")) {
        if ([int]$roleCounts[$role] -lt 1) {
            throw "Campaign-local attestation has no '$role' negative-control gate."
        }
    }

    $bindingReceipts = [Collections.Generic.List[object]]::new()
    $bindingPaths = [Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($binding in @($manifest.source_bindings)) {
        $relativePath = [string]$binding.path
        if (-not $bindingPaths.Add($relativePath)) {
            throw "Campaign-local source binding is duplicated: $relativePath"
        }
        $resolved = Resolve-SporeSporeCampaignAttestationPath `
            -RepoRoot $repo `
            -RelativePath $relativePath
        $actualHash = Get-SporeSporeCampaignAttestationSha256 $resolved.absolute_path
        if ([string]$binding.raw_sha256 -cne $actualHash) {
            throw "Campaign-local source binding digest drifted: $relativePath"
        }
        if (-not $TestOnly -and -not $tracked.Contains($relativePath)) {
            throw "Campaign-local source binding is not tracked: $relativePath"
        }
        $bindingGitBlob = if ($TestOnly) { "test-only-untracked" } else {
            Get-SporeSporeCampaignAttestationGitBlobOid `
                -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
        }
        $bindingGitBlobRaw = if ($TestOnly) { "test-only-untracked" } else {
            Get-SporeSporeCampaignAttestationGitBlobRawSha256 `
                -RepoRoot $repo -Commit HEAD -RelativePath $relativePath
        }
        if (-not $TestOnly -and $actualHash -cne $bindingGitBlobRaw) {
            throw "Campaign-local checkout differs from Git blob: $relativePath"
        }
        $bindingReceipts.Add([ordered]@{
            path = $relativePath
            raw_sha256 = $actualHash
            git_blob_oid = $bindingGitBlob
            git_blob_raw_sha256 = $bindingGitBlobRaw
        })
    }
    if ($bindingReceipts.Count -lt 1) {
        throw "Campaign-local attestation has no transitive source bindings."
    }
    foreach ($gate in @($gateReceipts)) {
        if (-not $bindingPaths.Contains([string]$gate.path)) {
            throw "Campaign-local gate is absent from source bindings: $($gate.gate_id)"
        }
    }
    $dependencyPath = [string]$manifest.dependency_authority.path
    if ([string]::IsNullOrWhiteSpace($dependencyPath) -or
        -not $bindingPaths.Contains($dependencyPath)) {
        throw "Campaign-local dependency authority is absent from source bindings."
    }
    $dependencyBinding = @($bindingReceipts | Where-Object {
        [string]$_.path -ceq $dependencyPath
    })
    if ($dependencyBinding.Count -ne 1 -or
        [string]$manifest.dependency_authority.raw_sha256 -cne
            [string]$dependencyBinding[0].raw_sha256) {
        throw "Campaign-local dependency authority digest drifted."
    }
    $roleBindings = @($manifest.campaign_role_bindings)
    if ([int]$manifest.declared_role_binding_count -ne 3 -or
        $roleBindings.Count -ne 3) {
        throw "Campaign-local role-binding counts disagree."
    }
    $requiredRoles = @("worker", "evaluator", "supervisor")
    for ($index = 0; $index -lt $requiredRoles.Count; $index++) {
        $binding = $roleBindings[$index]
        $role = $requiredRoles[$index]
        $sourcePath = [string]$binding.source_path
        $testPath = [string]$binding.test_path
        $testGateId = [string]$binding.test_gate_id
        if ([string]$binding.role -cne $role -or
            -not $bindingPaths.Contains($sourcePath) -or
            -not $bindingPaths.Contains($testPath)) {
            throw "Campaign-local '$role' role binding is incomplete."
        }
        $sourceReceipt = @($bindingReceipts | Where-Object {
            [string]$_.path -ceq $sourcePath
        })
        $testReceipt = @($bindingReceipts | Where-Object {
            [string]$_.path -ceq $testPath
        })
        $testGate = @($gateReceipts | Where-Object {
            [string]$_.gate_id -ceq $testGateId -and
            [string]$_.role -ceq $role -and
            [string]$_.path -ceq $testPath
        })
        if ($sourceReceipt.Count -ne 1 -or $testReceipt.Count -ne 1 -or
            $testGate.Count -ne 1 -or
            [string]$binding.source_raw_sha256 -cne
                [string]$sourceReceipt[0].raw_sha256 -or
            [string]$binding.test_raw_sha256 -cne
                [string]$testReceipt[0].raw_sha256) {
            throw "Campaign-local '$role' source/test digest binding drifted."
        }
    }
    $projectedCampaignGates = @($gateReceipts | ForEach-Object {
        [ordered]@{
            ordinal = [int]$_.ordinal
            gate_id = [string]$_.gate_id
            role = [string]$_.role
            invocation_kind = [string]$_.invocation_kind
            path = [string]$_.path
            arguments = @($_.arguments)
            terminal_marker_prefix = [string]$_.terminal_marker_prefix
            raw_sha256 = [string]$_.raw_sha256
            git_blob_oid = [string]$_.git_blob_oid
            git_blob_raw_sha256 = [string]$_.git_blob_raw_sha256
        }
    })
    $projection = [ordered]@{
        schema_version = "sporespore_locomotion_campaign_attestation_candidate_projection_v1"
        contract_raw_sha256 = Get-SporeSporeCampaignAttestationSha256 $ContractPath
        manifest_raw_sha256 = Get-SporeSporeCampaignAttestationSha256 $manifestResolved
        canonical_runner_raw_sha256 = Get-SporeSporeCampaignAttestationSha256 $CanonicalRunnerPath
        global_kernel_inventory_sha256 = [string]$kernel.inventory_sha256
        campaign_id = [string]$manifest.campaign_id
        question_class = [string]$manifest.question_class
        declared_physical_world_count = [int]$manifest.declared_physical_world_count
        global_gates = @($globalGateReceipts)
        core_source_bindings = @($coreBindingReceipts)
        campaign_gates = $projectedCampaignGates
        source_bindings = @($bindingReceipts)
        dependency_authority = $manifest.dependency_authority
        campaign_role_bindings = $roleBindings
    }
    return [ordered]@{
        schema_version = "sporespore_locomotion_campaign_attestation_candidate_v1"
        status = "prospective_uncommissioned_authority_disabled"
        campaign_id = [string]$manifest.campaign_id
        question_class = [string]$manifest.question_class
        declared_physical_world_count = [int]$manifest.declared_physical_world_count
        inventory_sha256 = Get-SporeSporeCampaignAttestationObjectSha256 $projection
        contract = $contract
        manifest = $manifest
        global_kernel = $kernel
        global_gates = @($globalGateReceipts)
        core_source_bindings = @($coreBindingReceipts)
        campaign_gates = @($gateReceipts)
        source_bindings = @($bindingReceipts)
        dependency_authority = $manifest.dependency_authority
        campaign_role_bindings = $roleBindings
        global_gate_count = @($kernel.gates).Count
        lineage_gate_count = @($manifest.lineage_gates).Count
        campaign_gate_count = @($manifest.campaign_gates).Count
        campaign_roles_complete = $true
        godot_including = $true
        commissioned = $false
        physical_launch_prerequisite_satisfied = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Get-SporeSporeCampaignAttestationCommandIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Command,
        [Parameter(Mandatory)][string[]]$VersionArguments
    )
    $resolved = (Get-Command $Command -ErrorAction Stop).Source
    $path = [IO.Path]::GetFullPath($resolved)
    $versionLines = @(& $path @VersionArguments 2>&1)
    if ($LASTEXITCODE -ne 0 -or $versionLines.Count -lt 1) {
        throw "Campaign-local attestation runtime identity failed: $Command"
    }
    return [ordered]@{
        executable_path = $path
        executable_sha256 = Get-SporeSporeCampaignAttestationSha256 $path
        version = ([string]$versionLines[0]).Trim()
    }
}

function Get-SporeSporeCampaignAttestationRuntimeIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Godot,
        [string]$Python = "python"
    )
    return [ordered]@{
        godot = Get-SporeSporeAttestationGodotIdentity -Godot $Godot
        powershell = Get-SporeSporeAttestationPowerShellIdentity
        python = Get-SporeSporeCampaignAttestationCommandIdentity `
            -Command $Python -VersionArguments @("--version")
        git = Get-SporeSporeCampaignAttestationCommandIdentity `
            -Command "git" -VersionArguments @("--version")
        cargo = Get-SporeSporeCampaignAttestationCommandIdentity `
            -Command "cargo" -VersionArguments @("--version")
        rustc = Get-SporeSporeCampaignAttestationCommandIdentity `
            -Command "rustc" -VersionArguments @("--version")
        host = [ordered]@{
            os_description = [Runtime.InteropServices.RuntimeInformation]::OSDescription
            os_architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
            process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
            framework_description = [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            machine_name = [Environment]::MachineName
        }
    }
}

function Assert-SporeSporeCampaignAttestationOutputRoot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$OutputRoot,
        [switch]$TestOnly
    )
    $resolved = [IO.Path]::GetFullPath($OutputRoot).TrimEnd('\', '/')
    if (Test-Path -LiteralPath $resolved) {
        throw "Campaign-local attestation output root already exists: $resolved"
    }
    if (-not $TestOnly) {
        $evidence = (Get-SporeSporeArtifactEvidenceRoot -RepoRoot $RepoRoot).
            TrimEnd('\', '/')
        $prefix = $evidence + [IO.Path]::DirectorySeparatorChar
        if (-not $resolved.StartsWith(
            $prefix,
            [StringComparison]::OrdinalIgnoreCase
        )) {
            throw "Campaign-local attestation output must be inside $evidence"
        }
    }
    return $resolved
}

function Expand-SporeSporeCampaignAttestationArgument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Argument,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Godot,
        [Parameter(Mandatory)][string]$Python
    )
    if ($Argument -ceq "<repo-root>") { return $RepoRoot }
    if ($Argument -ceq "<canonical-godot>") {
        return [IO.Path]::GetFullPath($Godot)
    }
    if ($Argument -ceq "<python>") { return $Python }
    return $Argument
}

function New-SporeSporeCampaignAttestationProcessStartInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Gate,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Godot,
        [Parameter(Mandatory)][string]$Python
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.WorkingDirectory = $RepoRoot
    foreach ($name in @($start.Environment.Keys)) {
        if ([string]$name -clike "SPORESPORE_*") {
            [void]$start.Environment.Remove([string]$name)
        }
    }
    $kind = [string]$Gate.invocation_kind
    $path = [string]$Gate.absolute_path
    $arguments = @($Gate.arguments | ForEach-Object {
        Expand-SporeSporeCampaignAttestationArgument `
            -Argument ([string]$_) -RepoRoot $RepoRoot -Godot $Godot -Python $Python
    })
    switch ($kind) {
        "powershell_file" {
            $start.FileName = (Get-Command pwsh -ErrorAction Stop).Source
            foreach ($argument in @("-NoLogo", "-NoProfile", "-File", $path) +
                $arguments) { [void]$start.ArgumentList.Add($argument) }
        }
        "godot_script" {
            $start.FileName = [IO.Path]::GetFullPath($Godot)
            foreach ($argument in @(
                "--headless", "--path", $RepoRoot, "--script",
                "res://$([string]$Gate.path)"
            ) + $arguments) { [void]$start.ArgumentList.Add($argument) }
        }
        "python_file" {
            $start.FileName = (Get-Command $Python -ErrorAction Stop).Source
            [void]$start.ArgumentList.Add($path)
            foreach ($argument in $arguments) { [void]$start.ArgumentList.Add($argument) }
        }
        "python_unittest" {
            $start.FileName = (Get-Command $Python -ErrorAction Stop).Source
            $start.WorkingDirectory = Split-Path -Parent $path
            foreach ($argument in @("-m", "unittest", "-v", (Split-Path -Leaf $path)) +
                $arguments) { [void]$start.ArgumentList.Add($argument) }
        }
        default { throw "Unsupported campaign-local invocation kind: $kind" }
    }
    return $start
}

function Invoke-SporeSporeCampaignAttestationGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Gate,
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$Godot,
        [Parameter(Mandatory)][string]$Python,
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][int]$Ordinal,
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 3600,
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly,
        [switch]$RequireTerminalMarker
    )
    $safeId = ([string]$Gate.gate_id) -replace '[^A-Za-z0-9_.-]', '_'
    $stem = "{0:D3}-{1}" -f $Ordinal, $safeId
    $stdoutPath = Join-Path $OutputRoot "$stem.stdout.log"
    $stderrPath = Join-Path $OutputRoot "$stem.stderr.log"
    $receiptPath = Join-Path $OutputRoot "$stem.receipt.json"
    $startInfo = New-SporeSporeCampaignAttestationProcessStartInfo `
        -Gate $Gate -RepoRoot $RepoRoot -Godot $Godot -Python $Python
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $started = [DateTime]::UtcNow
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) {
        throw "Campaign-local attestation could not start gate '$safeId'."
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "CAMPAIGN_ATTESTATION_PROGRESS gate=$safeId elapsed_seconds=" +
                $timer.Elapsed.TotalSeconds.ToString(
                    "F1", [Globalization.CultureInfo]::InvariantCulture
                )
            )
            $nextHeartbeat += 30.0
        }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(10000)
            break
        }
    }
    $timer.Stop()
    $completed = [DateTime]::UtcNow
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { [int]$process.ExitCode } else { -1 }
    $process.Dispose()
    [IO.File]::WriteAllText($stdoutPath, $stdout, [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($stderrPath, $stderr, [Text.UTF8Encoding]::new($false))
    $markerLines = @(if ($RequireTerminalMarker) {
        $stdout -split "`r?`n" | Where-Object {
            $_.StartsWith(
                [string]$Gate.terminal_marker_prefix,
                [StringComparison]::Ordinal
            )
        }
    })
    $passed = (
        -not $timedOut -and $exitCode -eq 0 -and
        (-not $RequireTerminalMarker -or $markerLines.Count -eq 1)
    )
    $stdoutCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $RepoRoot -ArtifactPath $stdoutPath -MediaType "text/plain" `
        -EvidenceRootOverride $EvidenceRootOverride -TestOnly:$TestOnly
    $stderrCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $RepoRoot -ArtifactPath $stderrPath -MediaType "text/plain" `
        -EvidenceRootOverride $EvidenceRootOverride -TestOnly:$TestOnly
    $receipt = [ordered]@{
        schema_version = "sporespore_locomotion_campaign_attestation_gate_receipt_v1"
        ordinal = $Ordinal
        gate_id = [string]$Gate.gate_id
        role = [string]$Gate.role
        invocation_kind = [string]$Gate.invocation_kind
        path = [string]$Gate.path
        source_raw_sha256 = [string]$Gate.raw_sha256
        source_git_blob_oid = [string]$Gate.git_blob_oid
        source_git_blob_raw_sha256 = [string]$Gate.git_blob_raw_sha256
        arguments = @($Gate.arguments)
        terminal_marker_prefix = [string]$Gate.terminal_marker_prefix
        terminal_marker_required = [bool]$RequireTerminalMarker
        terminal_marker_count = $markerLines.Count
        terminal_marker = if ($markerLines.Count -eq 1) { $markerLines[0] } else { $null }
        started_utc = $started.ToString("o")
        completed_utc = $completed.ToString("o")
        duration_seconds = $timer.Elapsed.TotalSeconds
        timed_out = $timedOut
        exit_code = $exitCode
        passed = $passed
        stdout_path = $stdoutPath
        stdout_cas = $stdoutCas
        stderr_path = $stderrPath
        stderr_cas = $stderrCas
        physical_process_launch_count = 0
        physical_world_count = 0
        physical_acceptance_authority = $false
    }
    [IO.File]::WriteAllText(
        $receiptPath,
        ($receipt | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $receiptCas = Publish-SporeSporeContentAddressedArtifact `
        -RepoRoot $RepoRoot -ArtifactPath $receiptPath `
        -MediaType "application/json" -EvidenceRootOverride $EvidenceRootOverride `
        -TestOnly:$TestOnly
    $receipt.receipt_path = $receiptPath
    $receipt.receipt_cas = $receiptCas
    if (-not $passed) {
        throw (
            "Campaign-local attestation gate failed: $safeId exit=$exitCode " +
            "timeout=$timedOut marker_count=$($markerLines.Count)"
        )
    }
    Write-Host (
        "CAMPAIGN_ATTESTATION_GATE_PASS ordinal=$Ordinal gate=$safeId " +
        "duration_seconds=$($timer.Elapsed.TotalSeconds.ToString('F3', [Globalization.CultureInfo]::InvariantCulture))"
    )
    return $receipt
}

function New-SporeSporeCampaignAttestationDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Candidate,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Source,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Runtime,
        [Parameter(Mandatory)][System.Collections.IDictionary]$OperationLock,
        [Parameter(Mandatory)][object[]]$GateReceipts,
        [Parameter(Mandatory)][DateTime]$StartedUtc,
        [Parameter(Mandatory)][DateTime]$CompletedUtc,
        [switch]$TestOnly
    )
    return [ordered]@{
        schema_version = $script:SporeSporeCampaignAttestationSchema
        status = "campaign_local_godot_including_qualification_passed"
        test_only = [bool]$TestOnly
        campaign_id = [string]$Candidate.campaign_id
        question_class = [string]$Candidate.question_class
        declared_physical_world_count = [int]$Candidate.declared_physical_world_count
        candidate_inventory_sha256 = [string]$Candidate.inventory_sha256
        global_kernel_inventory_sha256 =
            [string]$Candidate.global_kernel.inventory_sha256
        core_source_bindings = @($Candidate.core_source_bindings)
        campaign_source_bindings = @($Candidate.source_bindings)
        dependency_authority = $Candidate.dependency_authority
        campaign_role_bindings = @($Candidate.campaign_role_bindings)
        source = $Source
        runtime = $Runtime
        operation_lock = $OperationLock
        started_utc = $StartedUtc.ToUniversalTime().ToString("o")
        completed_utc = $CompletedUtc.ToUniversalTime().ToString("o")
        duration_seconds = ($CompletedUtc - $StartedUtc).TotalSeconds
        global_gate_count = [int]$Candidate.global_gate_count
        lineage_gate_count = [int]$Candidate.lineage_gate_count
        campaign_gate_count = [int]$Candidate.campaign_gate_count
        executed_gate_count = @($GateReceipts).Count
        gate_receipts = @($GateReceipts)
        godot_including = $true
        all_gates_executed = $true
        all_gate_streams_content_addressed = $true
        commissioned = $false
        claims = [ordered]@{
            campaign_local_qualification_passed = $true
            cold_commissioning_complete = $false
            physical_launch_prerequisite_satisfied = $false
            physical_campaign_executed = $false
            scientific_result = $false
            walking_acceptance = $false
            turning_acceptance = $false
            cross_engine_equivalence = $false
            arbitrary_quadruped_coverage = $false
            release_authority = $false
            physical_acceptance_authority = $false
        }
    }
}

function Test-SporeSporeCampaignAttestationDocument {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Document,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Candidate,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedSource,
        [Parameter(Mandatory)][System.Collections.IDictionary]$ExpectedRuntime,
        [switch]$AllowTestOnly
    )
    $failures = [Collections.Generic.List[string]]::new()
    if ([string]$Document.schema_version -cne $script:SporeSporeCampaignAttestationSchema) {
        $failures.Add("SCHEMA")
    }
    if ([string]$Document.status -cne
        "campaign_local_godot_including_qualification_passed") {
        $failures.Add("STATUS")
    }
    if ([bool]$Document.test_only -and -not $AllowTestOnly) {
        $failures.Add("TEST_ONLY_FORBIDDEN")
    }
    if ([string]$Document.campaign_id -cne [string]$Candidate.campaign_id -or
        [string]$Document.candidate_inventory_sha256 -cne
            [string]$Candidate.inventory_sha256) {
        $failures.Add("CANDIDATE_IDENTITY")
    }
    if ([string]$Document.global_kernel_inventory_sha256 -cne
            [string]$Candidate.global_kernel.inventory_sha256 -or
        (@($Document.core_source_bindings) | ConvertTo-Json -Depth 100 -Compress) -cne
            (@($Candidate.core_source_bindings) | ConvertTo-Json -Depth 100 -Compress) -or
        (@($Document.campaign_source_bindings) | ConvertTo-Json -Depth 100 -Compress) -cne
            (@($Candidate.source_bindings) | ConvertTo-Json -Depth 100 -Compress)) {
        $failures.Add("SOURCE_BINDINGS")
    }
    foreach ($field in @(
        "repository_root", "remote_url", "commit", "tree_git_oid",
        "origin_main", "live_github_main"
    )) {
        if ([string]$Document.source[$field] -cne [string]$ExpectedSource[$field]) {
            $failures.Add("SOURCE_$($field.ToUpperInvariant())")
        }
    }
    if (-not [bool]$Document.test_only -and (
        -not [bool]$Document.source.worktree_clean -or
        -not [bool]$Document.source.clean_pushed_live
    )) {
        $failures.Add("SOURCE_NOT_CLEAN_PUSHED_LIVE")
    }
    if (($Document.runtime | ConvertTo-Json -Depth 100 -Compress) -cne
        ($ExpectedRuntime | ConvertTo-Json -Depth 100 -Compress)) {
        $failures.Add("RUNTIME_IDENTITY")
    }
    try {
        $started = ConvertTo-SporeSporeAttestationUtcDateTime $Document.started_utc
        $completed = ConvertTo-SporeSporeAttestationUtcDateTime $Document.completed_utc
        if ($completed -lt $started -or
            [Math]::Abs(
                ($completed - $started).TotalSeconds - [double]$Document.duration_seconds
            ) -gt 0.001) {
            $failures.Add("TIMING")
        }
    } catch { $failures.Add("TIMING") }
    if (-not [bool]$Document.godot_including -or
        -not [bool]$Document.all_gates_executed -or
        -not [bool]$Document.all_gate_streams_content_addressed -or
        [bool]$Document.commissioned -or
        [int]$Document.executed_gate_count -ne (
            [int]$Candidate.global_gate_count +
            [int]$Candidate.lineage_gate_count +
            [int]$Candidate.campaign_gate_count
        ) -or @($Document.gate_receipts).Count -ne
            [int]$Document.executed_gate_count -or
        @($Document.gate_receipts | Where-Object {
            -not [bool]$_.passed -or [bool]$_.timed_out -or
            [int]$_.exit_code -ne 0 -or [int]$_.physical_world_count -ne 0 -or
            ([string]$_.role -cne "global_safety_kernel" -and (
                -not [bool]$_.terminal_marker_required -or
                [int]$_.terminal_marker_count -ne 1
            ))
        }).Count -ne 0) {
        $failures.Add("EXECUTION")
    }
    $expectedGates = @()
    if ([int]$Candidate.global_gate_count -gt 0) {
        $expectedGates += @($Candidate.global_gates)
    }
    $expectedGates += @($Candidate.campaign_gates)
    if ($expectedGates.Count -ne @($Document.gate_receipts).Count) {
        $failures.Add("GATE_BINDINGS")
    } else {
        for ($index = 0; $index -lt $expectedGates.Count; $index++) {
            $expectedGate = $expectedGates[$index]
            $actualGate = $Document.gate_receipts[$index]
            if ([int]$actualGate.ordinal -ne $index + 1 -or
                [string]$actualGate.gate_id -cne [string]$expectedGate.gate_id -or
                [string]$actualGate.path -cne [string]$expectedGate.path -or
                [string]$actualGate.source_raw_sha256 -cne
                    [string]$expectedGate.raw_sha256 -or
                [string]$actualGate.source_git_blob_oid -cne
                    [string]$expectedGate.git_blob_oid -or
                [string]$actualGate.source_git_blob_raw_sha256 -cne
                    [string]$expectedGate.git_blob_raw_sha256) {
                $failures.Add("GATE_BINDINGS")
            }
            foreach ($casField in @("stdout_cas", "stderr_cas", "receipt_cas")) {
                try {
                    $cas = $actualGate[$casField]
                    $digest = [string]$cas.sha256
                    $directory = Split-Path -Parent ([string]$cas.payload_path)
                    if ($digest -cnotmatch '^sha256:[0-9a-f]{64}$' -or
                        -not (Test-SporeSporeStoredArtifact `
                            -Directory $directory `
                            -ExpectedSha256 $digest.Substring(7) `
                            -ExpectedByteLength ([long]$cas.byte_length))) {
                        $failures.Add("GATE_CAS")
                    }
                } catch { $failures.Add("GATE_CAS") }
            }
        }
    }
    if (-not [bool]$Document.operation_lock.acquired -or
        [string]$Document.operation_lock.role -cne "conformance" -or
        [bool]$Document.operation_lock.test_only -ne [bool]$Document.test_only -or
        (-not [bool]$Document.test_only -and
            [string]$Document.operation_lock.mutex_name -cne
                (Get-SporeSporeLocomotionOperationMutexName))) {
        $failures.Add("OPERATION_LOCK")
    }
    $actualNames = @($Document.claims.Keys | Sort-Object)
    $expectedNames = @($script:SporeSporeCampaignAttestationClaimNames | Sort-Object)
    if (($actualNames | ConvertTo-Json -Compress) -cne
        ($expectedNames | ConvertTo-Json -Compress)) {
        $failures.Add("CLAIM_SCHEMA")
    }
    foreach ($name in $script:SporeSporeCampaignAttestationClaimNames) {
        $expected = $name -ceq "campaign_local_qualification_passed"
        if (-not $Document.claims.Contains($name) -or
            [bool]$Document.claims[$name] -ne $expected) {
            $failures.Add("CLAIM::$name")
        }
    }
    return [ordered]@{
        ok = $failures.Count -eq 0
        failure_codes = @($failures | Sort-Object -Unique)
        campaign_local_qualification_passed = $failures.Count -eq 0
        physical_launch_prerequisite_satisfied = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}

function Invoke-SporeSporeCampaignAttestation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$Godot,
        [Parameter(Mandatory)][string]$OutputRoot,
        [string]$Python = "python",
        [ValidateRange(1, 7200)][int]$GateTimeoutSeconds = 3600,
        [string]$MutexName = (Get-SporeSporeLocomotionOperationMutexName),
        [string]$EvidenceRootOverride = "",
        [switch]$TestOnly,
        [switch]$SkipGlobalGatesForTestOnly
    )
    if ($SkipGlobalGatesForTestOnly -and -not $TestOnly) {
        throw "Skipping global campaign-attestation gates is test-only."
    }
    $repo = [IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $output = Assert-SporeSporeCampaignAttestationOutputRoot `
        -RepoRoot $repo -OutputRoot $OutputRoot -TestOnly:$TestOnly
    $sourceAtStart = Get-SporeSporeAttestationSourceIdentity `
        -RepoRoot $repo `
        -RequireCleanPushedLive:(-not $TestOnly)
    $candidate = Get-SporeSporeCampaignAttestationCandidate `
        -RepoRoot $repo -ManifestPath $ManifestPath -TestOnly:$TestOnly
    $runtime = Get-SporeSporeCampaignAttestationRuntimeIdentity `
        -Godot $Godot -Python $Python
    $operationLock = Enter-SporeSporeLocomotionOperationLock `
        -Role conformance -MutexName $MutexName -TestOnly:$TestOnly
    if (-not [bool]$operationLock.acquired) {
        throw "Campaign-local attestation could not acquire the locomotion operation lock."
    }
    $started = [DateTime]::UtcNow
    $failure = $null
    try {
        [void][IO.Directory]::CreateDirectory($output)
        $receipts = [Collections.Generic.List[object]]::new()
        $ordinal = 0
        if (-not $SkipGlobalGatesForTestOnly) {
            foreach ($gate in @($candidate.global_gates)) {
                $ordinal += 1
                $executionGate = Copy-SporeSporeCampaignAttestationObject $gate
                $executionGate.role = "global_safety_kernel"
                $executionGate.absolute_path = (
                    Resolve-SporeSporeCampaignAttestationPath `
                        -RepoRoot $repo -RelativePath ([string]$gate.path)
                ).absolute_path
                $executionGate.terminal_marker_prefix = ""
                if ([string]$executionGate.invocation_kind -cin @(
                    "godot_script", "python_unittest"
                )) {
                    # CAK1 records the complete canonical-runner invocation
                    # template for these two kinds. This runner supplies that
                    # template itself, so only true extra arguments survive.
                    $executionGate.arguments = @()
                }
                $receipts.Add((Invoke-SporeSporeCampaignAttestationGate `
                    -Gate $executionGate -RepoRoot $repo -Godot $Godot `
                    -Python $Python -OutputRoot $output -Ordinal $ordinal `
                    -TimeoutSeconds $GateTimeoutSeconds `
                    -EvidenceRootOverride $EvidenceRootOverride -TestOnly:$TestOnly))
            }
        }
        foreach ($gate in @($candidate.campaign_gates)) {
            $ordinal += 1
            $receipts.Add((Invoke-SporeSporeCampaignAttestationGate `
                -Gate $gate -RepoRoot $repo -Godot $Godot -Python $Python `
                -OutputRoot $output -Ordinal $ordinal `
                -TimeoutSeconds $GateTimeoutSeconds `
                -EvidenceRootOverride $EvidenceRootOverride -TestOnly:$TestOnly `
                -RequireTerminalMarker))
        }
        $sourceAtEnd = Get-SporeSporeAttestationSourceIdentity `
            -RepoRoot $repo `
            -RequireCleanPushedLive:(-not $TestOnly)
        if ([string]$sourceAtEnd.commit -cne [string]$sourceAtStart.commit -or
            [string]$sourceAtEnd.tree_git_oid -cne [string]$sourceAtStart.tree_git_oid -or
            (-not $TestOnly -and -not [bool]$sourceAtEnd.worktree_clean)) {
            throw "Source changed during campaign-local attestation."
        }
        $completed = [DateTime]::UtcNow
        $documentCandidate = $candidate
        if ($SkipGlobalGatesForTestOnly) {
            $documentCandidate = Copy-SporeSporeCampaignAttestationObject $candidate
            $documentCandidate.global_gate_count = 0
        }
        $document = New-SporeSporeCampaignAttestationDocument `
            -Candidate $documentCandidate -Source $sourceAtEnd -Runtime $runtime `
            -OperationLock (Get-SporeSporeLocomotionOperationLockPublicReceipt $operationLock) `
            -GateReceipts @($receipts) -StartedUtc $started -CompletedUtc $completed `
            -TestOnly:$TestOnly
        $validation = Test-SporeSporeCampaignAttestationDocument `
            -Document $document -Candidate $documentCandidate `
            -ExpectedSource $sourceAtEnd -ExpectedRuntime $runtime `
            -AllowTestOnly:$TestOnly
        if (-not [bool]$validation.ok) {
            throw "Constructed campaign-local attestation failed: $($validation.failure_codes -join ', ')"
        }
        $attestationPath = Join-Path $output "attestation.json"
        [IO.File]::WriteAllText(
            $attestationPath,
            ($document | ConvertTo-Json -Depth 100) + "`n",
            [Text.UTF8Encoding]::new($false)
        )
        $serialized = Get-Content -LiteralPath $attestationPath -Raw |
            ConvertFrom-Json -AsHashtable -Depth 100
        $serializedValidation = Test-SporeSporeCampaignAttestationDocument `
            -Document $serialized -Candidate $documentCandidate `
            -ExpectedSource $sourceAtEnd -ExpectedRuntime $runtime `
            -AllowTestOnly:$TestOnly
        if (-not [bool]$serializedValidation.ok) {
            throw "Serialized campaign-local attestation failed: $($serializedValidation.failure_codes -join ', ')"
        }
        $attestationCas = Publish-SporeSporeContentAddressedArtifact `
            -RepoRoot $repo -ArtifactPath $attestationPath `
            -MediaType "application/json" -EvidenceRootOverride $EvidenceRootOverride `
            -TestOnly:$TestOnly
        Write-Host (
            "CAMPAIGN_LOCAL_ATTESTATION_PASS campaign=$($candidate.campaign_id) " +
            "global_gates=$($candidate.global_gate_count) " +
            "lineage_gates=$($candidate.lineage_gate_count) " +
            "campaign_gates=$($candidate.campaign_gate_count) worlds=0 " +
            "commissioned=False physical_prerequisite=False physical_authority=False"
        )
        return [ordered]@{
            path = $attestationPath
            sha256 = Get-SporeSporeCampaignAttestationSha256 $attestationPath
            cas = $attestationCas
            source_commit = [string]$sourceAtEnd.commit
            source_tree_git_oid = [string]$sourceAtEnd.tree_git_oid
            campaign_id = [string]$candidate.campaign_id
            campaign_local_qualification_passed = $true
            commissioned = $false
            physical_launch_prerequisite_satisfied = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    } catch {
        $failure = $_
        if (Test-Path -LiteralPath $output -PathType Container) {
            $failurePath = Join-Path $output "failure.json"
            if (-not (Test-Path -LiteralPath $failurePath)) {
                $failureDocument = [ordered]@{
                    schema_version = "sporespore_locomotion_campaign_attestation_failure_v1"
                    campaign_id = [string]$candidate.campaign_id
                    source_commit = [string]$sourceAtStart.commit
                    started_utc = $started.ToString("o")
                    failed_utc = [DateTime]::UtcNow.ToString("o")
                    message = [string]$_.Exception.Message
                    campaign_local_qualification_passed = $false
                    physical_launch_prerequisite_satisfied = $false
                    physical_acceptance_authority = $false
                    release_authority = $false
                }
                [IO.File]::WriteAllText(
                    $failurePath,
                    ($failureDocument | ConvertTo-Json -Depth 32) + "`n",
                    [Text.UTF8Encoding]::new($false)
                )
                [void](Publish-SporeSporeContentAddressedArtifact `
                    -RepoRoot $repo -ArtifactPath $failurePath `
                    -MediaType "application/json" `
                    -EvidenceRootOverride $EvidenceRootOverride -TestOnly:$TestOnly)
            }
        }
    } finally {
        Exit-SporeSporeLocomotionOperationLock $operationLock
    }
    if ($null -ne $failure) { throw $failure }
}
