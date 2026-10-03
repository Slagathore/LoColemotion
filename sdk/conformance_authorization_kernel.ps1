#requires -Version 7.0

$script:SporeSporeAuthorizationKernelContractPath = Join-Path `
    $PSScriptRoot "conformance_authorization_kernel_contract_v1.json"
$script:SporeSporeAuthorizationKernelManifestPath = Join-Path `
    $PSScriptRoot "conformance_authorization_kernel_manifest_v1.json"

function Get-SporeSporeAuthorizationKernelSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-SporeSporeAuthorizationKernelObjectSha256 {
    [CmdletBinding()]
    param([Parameter(Mandatory)][object]$Value)
    $json = $Value | ConvertTo-Json -Depth 64 -Compress
    $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($json)
    return "sha256:" + [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

function Get-SporeSporeConformanceAuthorizationKernelContract {
    [CmdletBinding()]
    param([string]$Path = $script:SporeSporeAuthorizationKernelContractPath)
    $contract = Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 64
    if ([string]$contract.schema_version -cne
        "sporespore_conformance_authorization_kernel_contract_v1" -or
        [string]$contract.status -cne
        "active_declared_uncommissioned_authority_disabled" -or
        -not [bool]$contract.claims.global_gate_declaration_complete -or
        [bool]$contract.claims.global_gate_execution_complete -or
        [bool]$contract.claims.campaign_negative_controls_complete -or
        [bool]$contract.claims.cold_equivalence_complete -or
        [bool]$contract.claims.kernel_commissioned -or
        [bool]$contract.claims.cache_lookup_permitted -or
        [bool]$contract.claims.result_reuse_permitted -or
        [bool]$contract.claims.physical_launch_permitted -or
        [bool]$contract.claims.physical_acceptance_authority -or
        [bool]$contract.claims.release_authority) {
        throw "Conformance authorization-kernel contract exceeds its authority."
    }
    return $contract
}

function Get-SporeSporeConformanceAuthorizationKernelManifest {
    [CmdletBinding()]
    param([string]$Path = $script:SporeSporeAuthorizationKernelManifestPath)
    $manifest = Get-Content -LiteralPath $Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 64
    if ([string]$manifest.schema_version -cne
        "sporespore_conformance_authorization_kernel_manifest_v1" -or
        [string]$manifest.status -cne
        "declared_global_gates_unexecuted_campaign_roles_unbound" -or
        [bool]$manifest.global_gate_execution_complete -or
        [bool]$manifest.campaign_negative_controls_complete -or
        [bool]$manifest.cold_equivalence_complete -or
        [bool]$manifest.kernel_commissioned -or
        [bool]$manifest.cache_lookup_permitted -or
        [bool]$manifest.result_reuse_permitted -or
        [bool]$manifest.physical_launch_permitted -or
        [bool]$manifest.release_authority) {
        throw "Conformance authorization-kernel manifest exceeds its authority."
    }
    return $manifest
}

function Resolve-SporeSporeAuthorizationKernelRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$RelativePath
    )
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath.Contains("\") -or
        $RelativePath.Contains("`r") -or
        $RelativePath.Contains("`n")) {
        throw "Authorization-kernel path is not canonical: $RelativePath"
    }
    $segments = @($RelativePath.Split('/'))
    if ($segments.Count -eq 0 -or @($segments | Where-Object {
        [string]::IsNullOrEmpty($_) -or $_ -ceq "." -or $_ -ceq ".."
    }).Count -ne 0) {
        throw "Authorization-kernel path escapes or has an empty segment: $RelativePath"
    }
    $root = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $absolute = [System.IO.Path]::GetFullPath(
        (Join-Path $root ($RelativePath.Replace('/', '\')))
    )
    $prefix = $root + [System.IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Authorization-kernel path escaped the repository: $RelativePath"
    }
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        throw "Authorization-kernel gate source is missing: $RelativePath"
    }
    $cursor = $absolute
    while (-not $cursor.Equals($root, [StringComparison]::OrdinalIgnoreCase)) {
        $item = Get-Item -LiteralPath $cursor -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Authorization-kernel path contains a reparse point: $RelativePath"
        }
        $parent = Split-Path -Parent $cursor
        if ([string]::IsNullOrWhiteSpace($parent) -or $parent -ceq $cursor) {
            throw "Authorization-kernel path ancestry is invalid: $RelativePath"
        }
        $cursor = $parent
    }
    return [ordered]@{
        relative_path = $RelativePath
        absolute_path = $absolute
    }
}

function Get-SporeSporeConformanceAuthorizationKernelCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$ContractPath = $script:SporeSporeAuthorizationKernelContractPath,
        [string]$ManifestPath = $script:SporeSporeAuthorizationKernelManifestPath,
        [string]$RunnerPath = "",
        [switch]$TestOnly
    )
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $contract = Get-SporeSporeConformanceAuthorizationKernelContract `
        -Path $ContractPath
    $manifest = Get-SporeSporeConformanceAuthorizationKernelManifest `
        -Path $ManifestPath
    $runner = if ([string]::IsNullOrWhiteSpace($RunnerPath)) {
        Join-Path $repo (
            ([string]$contract.authority.canonical_runner_path).Replace('/', '\')
        )
    } else { [System.IO.Path]::GetFullPath($RunnerPath) }
    if (-not (Test-Path -LiteralPath $runner -PathType Leaf)) {
        throw "Authorization-kernel canonical runner is missing."
    }
    $runnerSource = Get-Content -LiteralPath $runner -Raw
    $tracked = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    if (-not $TestOnly) {
        $trackedOutput = @(& git -C $repo -c core.quotePath=false ls-files --cached)
        if ($LASTEXITCODE -ne 0) {
            throw "Authorization-kernel tracked-path inventory failed."
        }
        foreach ($line in $trackedOutput) {
            if (-not [string]::IsNullOrWhiteSpace([string]$line)) {
                [void]$tracked.Add(([string]$line).Replace('\', '/'))
            }
        }
    }
    $requiredSafeguards = @($contract.required_global_safeguards)
    $gates = @($manifest.gates)
    if ([int]$contract.authority.global_gate_count -ne $gates.Count -or
        [int]$manifest.global_gate_count -ne $gates.Count -or
        $requiredSafeguards.Count -ne $gates.Count) {
        throw "Authorization-kernel global gate counts disagree."
    }
    $ids = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $safeguards = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $paths = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $gateReceipts = [System.Collections.Generic.List[object]]::new()
    for ($index = 0; $index -lt $gates.Count; $index++) {
        $gate = $gates[$index]
        $ordinal = $index + 1
        $gateId = [string]$gate.gate_id
        $safeguardId = [string]$gate.safeguard_id
        $path = [string]$gate.path
        $kind = [string]$gate.invocation_kind
        $marker = [string]$gate.canonical_runner_marker
        if ([int]$gate.ordinal -ne $ordinal -or
            [string]::IsNullOrWhiteSpace($gateId) -or -not $ids.Add($gateId) -or
            -not $safeguards.Add($safeguardId) -or
            -not $paths.Add($path) -or
            $requiredSafeguards[$index] -cne $safeguardId) {
            throw "Authorization-kernel gate order, identity, or safeguard drifted."
        }
        if ($kind -cnotin @("powershell_file", "godot_script", "python_unittest")) {
            throw "Authorization-kernel invocation kind is invalid: $kind"
        }
        $expectedExtension = switch ($kind) {
            "powershell_file" { ".ps1" }
            "godot_script" { ".gd" }
            "python_unittest" { ".py" }
        }
        if ([System.IO.Path]::GetExtension($path) -cne $expectedExtension -or
            @($gate.arguments | Where-Object {
                [string]$_ -in @("-SkipGodot", "-RunPhysical")
            }).Count -ne 0) {
            throw "Authorization-kernel invocation semantics are unsafe: $gateId"
        }
        $resolved = Resolve-SporeSporeAuthorizationKernelRelativePath `
            -RepoRoot $repo `
            -RelativePath $path
        if (-not $TestOnly -and -not $tracked.Contains($path)) {
            throw "Authorization-kernel gate source is not tracked: $path"
        }
        if ([string]::IsNullOrWhiteSpace($marker) -or
            -not $runnerSource.Contains($marker, [StringComparison]::Ordinal)) {
            throw "Authorization-kernel gate is absent from canonical runner: $gateId"
        }
        $item = Get-Item -LiteralPath $resolved.absolute_path -Force
        $gateReceipts.Add([ordered]@{
            ordinal = $ordinal
            gate_id = $gateId
            safeguard_id = $safeguardId
            invocation_kind = $kind
            path = $path
            arguments = @($gate.arguments)
            canonical_runner_marker = $marker
            requires_godot = [bool]$gate.requires_godot
            byte_length = [long]$item.Length
            raw_sha256 = Get-SporeSporeAuthorizationKernelSha256 `
                -Path $resolved.absolute_path
        })
    }
    $roles = @($manifest.required_campaign_negative_control_roles)
    $requiredRoles = @($contract.campaign_negative_control_interface.required_roles)
    if ([int]$contract.authority.required_campaign_negative_control_role_count -ne
        $roles.Count -or $roles.Count -ne $requiredRoles.Count) {
        throw "Authorization-kernel campaign-role counts disagree."
    }
    for ($index = 0; $index -lt $roles.Count; $index++) {
        $role = $roles[$index]
        if ([string]$role.role -cne [string]$requiredRoles[$index] -or
            [string]$role.binding_status -cne
            "unbound_until_distinct_successor_preregistration" -or
            -not [bool]$role.requires_exact_source_digest -or
            -not [bool]$role.requires_exact_test_digest -or
            -not [bool]$role.requires_retained_refusal_receipt -or
            [bool]$role.bound) {
            throw "Authorization-kernel campaign-role interface drifted."
        }
    }
    $projection = [ordered]@{
        schema_version =
            "sporespore_conformance_authorization_kernel_projection_v1"
        contract_raw_sha256 = Get-SporeSporeAuthorizationKernelSha256 `
            -Path $ContractPath
        manifest_raw_sha256 = Get-SporeSporeAuthorizationKernelSha256 `
            -Path $ManifestPath
        canonical_runner_raw_sha256 = Get-SporeSporeAuthorizationKernelSha256 `
            -Path $runner
        gates = @($gateReceipts)
        campaign_roles = @($roles)
    }
    return [ordered]@{
        schema_version =
            "sporespore_conformance_authorization_kernel_candidate_v1"
        status = "declared_unexecuted_uncommissioned_authority_disabled"
        inventory_sha256 = Get-SporeSporeAuthorizationKernelObjectSha256 `
            -Value $projection
        global_gate_count = $gateReceipts.Count
        godot_required_gate_count = @($gateReceipts | Where-Object {
            [bool]$_.requires_godot
        }).Count
        campaign_negative_control_role_count = $roles.Count
        global_gate_declaration_complete = $true
        canonical_runner_bindings_complete = $true
        global_gate_execution_complete = $false
        campaign_negative_controls_complete = $false
        cold_equivalence_complete = $false
        kernel_commissioned = $false
        cache_lookup_permitted = $false
        result_reuse_permitted = $false
        physical_launch_permitted = $false
        physical_authority = $false
        release_authority = $false
        gates = @($gateReceipts)
        campaign_roles = @($roles)
    }
}
