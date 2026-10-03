#requires -Version 7.0

$script:SporeSporeDependencyContractPath = Join-Path `
    $PSScriptRoot "conformance_dependency_contract_v1.json"
$script:SporeSporeDependencyArtifactStorePath = Join-Path `
    $PSScriptRoot "content_addressed_artifact_store.ps1"
$script:SporeSporeAuditDependencyModulePath = Join-Path `
    $PSScriptRoot "conformance_audit_dependency.ps1"
$script:SporeSporeRuntimeProfileModulePath = Join-Path `
    $PSScriptRoot "conformance_runtime_profile.ps1"
$script:SporeSporeAuthorizationKernelModulePath = Join-Path `
    $PSScriptRoot "conformance_authorization_kernel.ps1"

. $script:SporeSporeDependencyArtifactStorePath
. $script:SporeSporeAuditDependencyModulePath
. $script:SporeSporeRuntimeProfileModulePath
. $script:SporeSporeAuthorizationKernelModulePath

function Get-SporeSporeConformanceDependencyContract {
    [CmdletBinding()]
    param()
    if (-not (Test-Path -LiteralPath $script:SporeSporeDependencyContractPath -PathType Leaf)) {
        throw "Conformance dependency contract is missing."
    }
    $contract = Get-Content -LiteralPath $script:SporeSporeDependencyContractPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$contract.schema_version -cne
        "sporespore_conformance_dependency_contract_v1" -or
        [string]$contract.status -cne "active_candidate_key_cache_disabled" -or
        [bool]$contract.candidate_authority.transitive_dependency_key_complete -or
        [bool]$contract.candidate_authority.undeclared_dependency_detection_complete -or
        [bool]$contract.candidate_authority.host_semantics_key_complete -or
        [bool]$contract.candidate_authority.lookup_permitted -or
        [bool]$contract.candidate_authority.reuse_permitted -or
        [bool]$contract.candidate_authority.cache_hit_authority) {
        throw "Conformance dependency contract exceeds its commissioned authority."
    }
    return $contract
}

function Get-SporeSporeDependencyBytesSha256 {
    param([AllowEmptyCollection()][Parameter(Mandatory)][byte[]]$Bytes)
    $hash = [System.Security.Cryptography.SHA256]::HashData($Bytes)
    return "sha256:" + [Convert]::ToHexString($hash).ToLowerInvariant()
}

function Get-SporeSporeDependencyStringSha256 {
    param([AllowEmptyString()][Parameter(Mandatory)][string]$Value)
    return Get-SporeSporeDependencyBytesSha256 `
        ([System.Text.Encoding]::UTF8.GetBytes($Value))
}

function Get-SporeSporeDependencyRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-SporeSporeDependencyObjectSha256 {
    param([Parameter(Mandatory)][object]$Value)
    $json = $Value | ConvertTo-Json -Depth 64 -Compress
    return Get-SporeSporeDependencyStringSha256 $json
}

function Get-SporeSporeDependencyRelativePath {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RelativePath
    )
    if ([string]::IsNullOrWhiteSpace($RelativePath) -or
        [System.IO.Path]::IsPathRooted($RelativePath) -or
        $RelativePath.Contains("`n", [StringComparison]::Ordinal) -or
        $RelativePath.Contains("`r", [StringComparison]::Ordinal)) {
        throw "Dependency path must be a nonempty newline-free relative path: '$RelativePath'"
    }
    $normalized = $RelativePath.Replace('\', '/')
    $segments = @($normalized -split '/')
    $invalidNameCharacters = [System.IO.Path]::GetInvalidFileNameChars()
    if ($segments.Count -eq 0 -or @($segments | Where-Object {
        [string]::IsNullOrEmpty($_) -or
        $_ -ceq "." -or
        $_ -ceq ".." -or
        $_.IndexOfAny($invalidNameCharacters) -ge 0 -or
        $_.EndsWith(" ", [StringComparison]::Ordinal) -or
        $_.EndsWith(".", [StringComparison]::Ordinal)
    }).Count -ne 0) {
        throw "Dependency path contains an unsafe or noncanonical segment: '$RelativePath'"
    }
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $resolved = [System.IO.Path]::GetFullPath(
        (Join-Path $resolvedRoot ($normalized.Replace('/', '\')))
    )
    $prefix = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar
    if (-not $resolved.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Dependency path escapes its declared root: '$RelativePath'"
    }
    return [ordered]@{
        relative_path = $normalized
        absolute_path = $resolved
    }
}

function Assert-SporeSporeDependencyPathHasNoReparsePoint {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$AbsolutePath,
        [System.Collections.Generic.HashSet[string]]$CheckedPaths
    )
    if ($null -eq $CheckedPaths) {
        $CheckedPaths = [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )
    }
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    $resolvedPath = [System.IO.Path]::GetFullPath($AbsolutePath)
    if ($CheckedPaths.Add($resolvedRoot)) {
        $rootItem = Get-Item -LiteralPath $resolvedRoot -Force
        if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Dependency root is a reparse point: $resolvedRoot"
        }
    }
    $relative = [System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedPath)
    $current = $resolvedRoot
    foreach ($segment in @($relative -split '[\\/]')) {
        $current = Join-Path $current $segment
        if ($CheckedPaths.Add($current) -and (Test-Path -LiteralPath $current)) {
            $item = Get-Item -LiteralPath $current -Force
            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Dependency path crosses a reparse point: $current"
            }
        }
    }
}

function Get-SporeSporeDeclaredFileInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$RelativePaths,
        [string]$InventoryId = "declared_files"
    )
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Dependency inventory root is missing: $resolvedRoot"
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $recordByPath = [System.Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $checkedReparsePaths = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($path in $RelativePaths) {
        $resolved = Get-SporeSporeDependencyRelativePath `
            -Root $resolvedRoot `
            -RelativePath $path
        if (-not $seen.Add([string]$resolved.relative_path)) {
            throw "Dependency inventory contains a duplicate/case-colliding path: $path"
        }
        if (-not (Test-Path -LiteralPath $resolved.absolute_path -PathType Leaf)) {
            throw "Declared dependency file is missing: $($resolved.relative_path)"
        }
        Assert-SporeSporeDependencyPathHasNoReparsePoint `
            -Root $resolvedRoot `
            -AbsolutePath $resolved.absolute_path `
            -CheckedPaths $checkedReparsePaths
        $item = Get-Item -LiteralPath $resolved.absolute_path -Force
        if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Declared dependency file is a reparse point: $($resolved.relative_path)"
        }
        $recordByPath.Add([string]$resolved.relative_path, [ordered]@{
            path = [string]$resolved.relative_path
            byte_length = [long]$item.Length
            raw_sha256 = Get-SporeSporeDependencyRawSha256 $resolved.absolute_path
        })
    }
    $orderedPaths = [string[]]@($recordByPath.Keys)
    [Array]::Sort($orderedPaths, [StringComparer]::Ordinal)
    $records = @($orderedPaths | ForEach-Object { $recordByPath[$_] })
    $projection = [ordered]@{
        schema_version = "sporespore_declared_file_inventory_v1"
        inventory_id = $InventoryId
        entries = $records
    }
    $byteCount = 0L
    foreach ($record in $records) {
        $byteCount += [long]$record.byte_length
    }
    return [ordered]@{
        schema_version = "sporespore_declared_file_inventory_receipt_v1"
        inventory_id = $InventoryId
        root_in_digest = $false
        file_count = $records.Count
        byte_count = $byteCount
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        entries = $records
    }
}

function Get-SporeSporeDirectoryFileInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$InventoryId = "directory_files"
    )
    $resolvedRoot = [System.IO.Path]::GetFullPath($Root).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
        throw "Dependency directory root is missing: $resolvedRoot"
    }
    Assert-SporeSporeDependencyPathHasNoReparsePoint `
        -Root $resolvedRoot `
        -AbsolutePath $resolvedRoot
    $items = @(Get-ChildItem -LiteralPath $resolvedRoot -Recurse -Force)
    $reparse = @($items | Where-Object {
        ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0
    })
    if ($reparse.Count -ne 0) {
        throw "Dependency directory contains a reparse point: $($reparse[0].FullName)"
    }
    $paths = @($items | Where-Object { -not $_.PSIsContainer } | ForEach-Object {
        [System.IO.Path]::GetRelativePath($resolvedRoot, $_.FullName)
    })
    return Get-SporeSporeDeclaredFileInventory `
        -Root $resolvedRoot `
        -RelativePaths $paths `
        -InventoryId $InventoryId
}

function Get-SporeSporeEnvironmentReferenceInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$SourceRelativePaths,
        [string[]]$BaselineNames = @()
    )
    $sourceExtensions = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($extension in @(".ps1", ".psm1", ".py", ".rs", ".gd", ".cs")) {
        [void]$sourceExtensions.Add($extension)
    }
    $names = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($name in $BaselineNames) {
        if ($name -cnotmatch "^[A-Za-z_][A-Za-z0-9_]*$") {
            throw "Invalid baseline environment name: '$name'"
        }
        [void]$names.Add($name)
    }
    $constantPatterns = @(
        '\$env:([A-Za-z_][A-Za-z0-9_]*)',
        'GetEnvironmentVariable\s*\(\s*["'']([A-Za-z_][A-Za-z0-9_]*)["'']',
        'os\.environ\s*\[\s*["'']([A-Za-z_][A-Za-z0-9_]*)["'']',
        'os\.(?:getenv|environ\.get)\s*\(\s*["'']([A-Za-z_][A-Za-z0-9_]*)["'']',
        '(?:(?:std::)?env)::var(?:_os)?\s*\(\s*["'']([A-Za-z_][A-Za-z0-9_]*)["'']',
        'OS\.get_environment\s*\(\s*["'']([A-Za-z_][A-Za-z0-9_]*)["'']'
    )
    $dynamicPatterns = @(
        'GetEnvironmentVariable\s*\((?!\s*["''])',
        'os\.(?:getenv|environ\.get)\s*\((?!\s*["''])',
        '(?:(?:std::)?env)::var(?:_os)?\s*\((?!\s*["''])',
        'OS\.get_environment\s*\((?!\s*["''])',
        'Get-ChildItem\s+(?:-Path\s+)?Env:',
        '\[Environment\]::GetEnvironmentVariables\s*\('
    )
    $dynamic = [System.Collections.Generic.List[object]]::new()
    foreach ($relativePath in $SourceRelativePaths) {
        $resolved = Get-SporeSporeDependencyRelativePath `
            -Root $Root `
            -RelativePath $relativePath
        if (-not $sourceExtensions.Contains(
            [System.IO.Path]::GetExtension($resolved.relative_path))) {
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved.absolute_path -PathType Leaf)) {
            throw "Environment-reference source is missing: $($resolved.relative_path)"
        }
        $source = Get-Content -LiteralPath $resolved.absolute_path -Raw
        foreach ($pattern in $constantPatterns) {
            foreach ($match in [regex]::Matches(
                $source,
                $pattern,
                [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                [void]$names.Add($match.Groups[1].Value)
            }
        }
        foreach ($pattern in $dynamicPatterns) {
            if ([regex]::IsMatch(
                $source,
                $pattern,
                [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
                $dynamic.Add([ordered]@{
                    path = [string]$resolved.relative_path
                    pattern_sha256 = Get-SporeSporeDependencyStringSha256 $pattern
                })
            }
        }
    }
    $orderedNames = [string[]]@($names)
    [Array]::Sort($orderedNames, [StringComparer]::Ordinal)
    $entries = @($orderedNames | ForEach-Object {
        $value = [Environment]::GetEnvironmentVariable($_, "Process")
        [ordered]@{
            name = $_
            present = $null -ne $value
            value_sha256 = if ($null -eq $value) {
                $null
            } else { Get-SporeSporeDependencyStringSha256 $value }
        }
    })
    $dynamicByKey = [System.Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($record in $dynamic) {
        $key = [string]$record.path + "`0" + [string]$record.pattern_sha256
        if (-not $dynamicByKey.ContainsKey($key)) {
            $dynamicByKey.Add($key, $record)
        }
    }
    $dynamicKeys = [string[]]@($dynamicByKey.Keys)
    [Array]::Sort($dynamicKeys, [StringComparer]::Ordinal)
    $orderedDynamic = @($dynamicKeys | ForEach-Object { $dynamicByKey[$_] })
    $projection = [ordered]@{
        schema_version = "sporespore_environment_reference_inventory_v1"
        entries = $entries
        dynamic_references = $orderedDynamic
    }
    return [ordered]@{
        schema_version = "sporespore_environment_reference_inventory_receipt_v1"
        referenced_name_count = $entries.Count
        dynamic_reference_count = $dynamic.Count
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        entries = $entries
        dynamic_references = $orderedDynamic
        raw_values_retained = $false
    }
}

function Get-SporeSporeProcessEnvironmentInventory {
    [CmdletBinding()]
    param()
    $variables = [Environment]::GetEnvironmentVariables("Process")
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $names = [System.Collections.Generic.List[string]]::new()
    foreach ($key in $variables.Keys) {
        $name = [string]$key
        if ($name -cnotmatch "^[^=\x00]+$") {
            throw "Process environment contains an invalid variable name."
        }
        if (-not $seen.Add($name)) {
            throw "Process environment contains a case-colliding variable name: $name"
        }
        $names.Add($name)
    }
    $orderedNames = [string[]]@($names)
    [Array]::Sort($orderedNames, [StringComparer]::Ordinal)
    $entries = @($orderedNames | ForEach-Object {
        $value = [string]$variables[$_]
        [ordered]@{
            name = $_
            value_sha256 = Get-SporeSporeDependencyStringSha256 $value
        }
    })
    $projection = [ordered]@{
        schema_version = "sporespore_process_environment_inventory_v1"
        entries = $entries
    }
    return [ordered]@{
        schema_version = "sporespore_process_environment_inventory_receipt_v1"
        variable_count = $entries.Count
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        entries = $entries
        raw_values_retained = $false
    }
}

function Get-SporeSporeReferencedCasInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$SourceRelativePaths,
        [string]$EvidenceRoot = ""
    )
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $evidence = if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repo
    } else { [System.IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/') }
    $casRoot = Join-Path $evidence "artifacts\sha256"
    if (-not (Test-Path -LiteralPath $casRoot -PathType Container)) {
        throw "Content-addressed evidence root is missing: $casRoot"
    }
    Assert-SporeSporeDependencyPathHasNoReparsePoint `
        -Root $casRoot `
        -AbsolutePath $casRoot
    $available = [System.Collections.Generic.Dictionary[string, string]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($directory in @(Get-ChildItem -LiteralPath $casRoot -Directory -Force)) {
        if ($directory.Name -cnotmatch "^[0-9a-f]{64}$") {
            throw "CAS root contains a noncanonical object directory: $($directory.FullName)"
        }
        if (($directory.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "CAS object directory is a reparse point: $($directory.FullName)"
        }
        $available.Add($directory.Name, $directory.FullName)
    }
    $textExtensions = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($extension in @(
        ".cfg", ".cs", ".gd", ".json", ".lock", ".md", ".ps1", ".psm1",
        ".py", ".rs", ".toml", ".tsv", ".txt", ".yaml", ".yml"
    )) {
        [void]$textExtensions.Add($extension)
    }
    $selected = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $explicit = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $literal = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::Ordinal
    )
    $explicitPattern = 'artifacts[\\/]+sha256[\\/]+([0-9a-f]{64})(?:[\\/]+payload\.bin)?'
    $literalPattern = '(?<![0-9a-f])(?:sha256:)?([0-9a-f]{64})(?![0-9a-f])'
    foreach ($relativePath in $SourceRelativePaths) {
        $resolved = Get-SporeSporeDependencyRelativePath `
            -Root $repo `
            -RelativePath $relativePath
        if (-not $textExtensions.Contains(
            [System.IO.Path]::GetExtension($resolved.relative_path))) {
            continue
        }
        if (-not (Test-Path -LiteralPath $resolved.absolute_path -PathType Leaf)) {
            throw "CAS-reference source is missing: $($resolved.relative_path)"
        }
        $source = Get-Content -LiteralPath $resolved.absolute_path -Raw
        foreach ($match in [regex]::Matches(
            $source,
            $explicitPattern,
            [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $digest = $match.Groups[1].Value.ToLowerInvariant()
            [void]$explicit.Add($digest)
            if (-not $available.ContainsKey($digest)) {
                throw "Tracked source explicitly references a missing CAS object: $digest"
            }
            [void]$selected.Add($digest)
        }
        foreach ($match in [regex]::Matches(
            $source,
            $literalPattern,
            [Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $digest = $match.Groups[1].Value.ToLowerInvariant()
            [void]$literal.Add($digest)
            if ($available.ContainsKey($digest)) {
                [void]$selected.Add($digest)
            }
        }
    }
    $digests = [string[]]@($selected)
    [Array]::Sort($digests, [StringComparer]::Ordinal)
    $entries = [System.Collections.Generic.List[object]]::new()
    $byteCount = 0L
    foreach ($digest in $digests) {
        $directory = $available[$digest]
        $manifestPath = Join-Path $directory "manifest.json"
        $payloadPath = Join-Path $directory "payload.bin"
        if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf) -or
            -not (Test-Path -LiteralPath $payloadPath -PathType Leaf)) {
            throw "Referenced CAS object is incomplete: $digest"
        }
        $manifest = Get-Content -LiteralPath $manifestPath -Raw |
            ConvertFrom-Json -AsHashtable -Depth 16
        $expectedLength = [long]$manifest.byte_length
        if (-not (Test-SporeSporeStoredArtifact `
            -Directory $directory `
            -ExpectedSha256 $digest `
            -ExpectedByteLength $expectedLength)) {
            throw "Referenced CAS object failed payload/manifest verification: $digest"
        }
        $byteCount += $expectedLength
        $entries.Add([ordered]@{
            sha256 = "sha256:$digest"
            byte_length = $expectedLength
            payload_relative_path = "artifacts/sha256/$digest/payload.bin"
            manifest_raw_sha256 = Get-SporeSporeDependencyRawSha256 $manifestPath
        })
    }
    $projection = [ordered]@{
        schema_version = "sporespore_referenced_cas_inventory_v1"
        entries = @($entries)
    }
    return [ordered]@{
        schema_version = "sporespore_referenced_cas_inventory_receipt_v1"
        status = "referenced_cas_observed_non_cas_incomplete"
        explicit_reference_count = $explicit.Count
        sha256_literal_count = $literal.Count
        matched_object_count = $entries.Count
        matched_payload_byte_count = $byteCount
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        entries = @($entries)
        explicit_missing_count = 0
        payloads_and_manifests_verified = $true
        unrelated_cas_objects_in_key = $false
        non_cas_evidence_dependency_detection_complete = $false
    }
}

function Invoke-SporeSporeDependencyGit {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )
    $lines = @(& git -C $RepoRoot @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "Dependency Git probe failed: git $($Arguments -join ' '): $($lines -join ' ')"
    }
    return [ordered]@{
        exit_code = $exitCode
        text = ($lines -join "`n").Trim()
    }
}

function New-SporeSporeConformanceDependencyKeyCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$ExpectedRemote = "https://github.com/Slagathore/sporespore.git"
    )
    $contract = Get-SporeSporeConformanceDependencyContract
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $head = (Invoke-SporeSporeDependencyGit $repo @("rev-parse", "HEAD")).text
    $tree = (Invoke-SporeSporeDependencyGit $repo @("rev-parse", "HEAD^{tree}")).text
    $originMainProbe = Invoke-SporeSporeDependencyGit `
        $repo @("rev-parse", "origin/main") -AllowFailure
    $remoteProbe = Invoke-SporeSporeDependencyGit `
        $repo @("remote", "get-url", "origin") -AllowFailure
    $status = (Invoke-SporeSporeDependencyGit `
        $repo @("status", "--porcelain=v1", "--untracked-files=all")).text
    $treeListing = (Invoke-SporeSporeDependencyGit `
        $repo @("ls-tree", "-r", "--full-tree", "HEAD")).text
    $trackedText = (Invoke-SporeSporeDependencyGit `
        $repo @("-c", "core.quotePath=false", "ls-files", "--cached")).text
    $trackedPaths = if ([string]::IsNullOrWhiteSpace($trackedText)) {
        @()
    } else { @($trackedText -split "`n") }
    if (@($trackedPaths | Where-Object {
        $_.Contains("`r") -or
        ($_.StartsWith('"', [StringComparison]::Ordinal) -and
            $_.EndsWith('"', [StringComparison]::Ordinal))
    }).Count -ne 0) {
        throw "Tracked dependency inventory contains a quoted or newline path."
    }
    $checkout = Get-SporeSporeDeclaredFileInventory `
        -Root $repo `
        -RelativePaths $trackedPaths `
        -InventoryId "git_tracked_checkout"
    $environment = Get-SporeSporeEnvironmentReferenceInventory `
        -Root $repo `
        -SourceRelativePaths $trackedPaths `
        -BaselineNames @($contract.environment_boundary.baseline_names)
    $processEnvironment = Get-SporeSporeProcessEnvironmentInventory
    $referencedCas = Get-SporeSporeReferencedCasInventory `
        -RepoRoot $repo `
        -SourceRelativePaths $trackedPaths
    $auditDependencies = Get-SporeSporeConformanceAuditDependencyCandidate `
        -RepoRoot $repo
    $runtimeProfiles = Get-SporeSporeConformanceRuntimeProfileCandidate `
        -RepoRoot $repo
    $authorizationKernel = `
        Get-SporeSporeConformanceAuthorizationKernelCandidate -RepoRoot $repo
    $combinedEvidenceProjection = [ordered]@{
        schema_version =
            "sporespore_conformance_combined_evidence_inventory_v1"
        referenced_cas_inventory_sha256 =
            [string]$referencedCas.inventory_sha256
        audit_dependency_inventory_sha256 =
            [string]$auditDependencies.inventory_sha256
    }
    $combinedEvidenceSha256 = Get-SporeSporeDependencyObjectSha256 `
        $combinedEvidenceProjection
    $sourceEligible = (
        [string]::IsNullOrWhiteSpace($status) -and
        $originMainProbe.exit_code -eq 0 -and
        $head -ceq [string]$originMainProbe.text -and
        $remoteProbe.exit_code -eq 0 -and
        [string]$remoteProbe.text -ceq $ExpectedRemote
    )
    $keyProjection = [ordered]@{
        schema_version = "sporespore_conformance_dependency_key_projection_v1"
        contract_schema_version = [string]$contract.schema_version
        head = $head
        head_tree = $tree
        origin_main = if ($originMainProbe.exit_code -eq 0) {
            [string]$originMainProbe.text
        } else { $null }
        remote_url = if ($remoteProbe.exit_code -eq 0) {
            [string]$remoteProbe.text
        } else { $null }
        status_sha256 = Get-SporeSporeDependencyStringSha256 $status
        git_tree_listing_sha256 = Get-SporeSporeDependencyStringSha256 $treeListing
        checkout_inventory_sha256 = [string]$checkout.inventory_sha256
        environment_inventory_sha256 = [string]$environment.inventory_sha256
        process_environment_inventory_sha256 = `
            [string]$processEnvironment.inventory_sha256
        source_eligible = $sourceEligible
        runtime_inventory_sha256 = [string]$runtimeProfiles.inventory_sha256
        evidence_inventory_sha256 = $combinedEvidenceSha256
        authorization_kernel_inventory_sha256 =
            [string]$authorizationKernel.inventory_sha256
    }
    return [ordered]@{
        schema_version = "sporespore_conformance_dependency_key_candidate_v1"
        status = "candidate_incomplete_cache_disabled"
        key_sha256 = Get-SporeSporeDependencyObjectSha256 $keyProjection
        source = [ordered]@{
            head = $head
            head_tree = $tree
            origin_main = if ($originMainProbe.exit_code -eq 0) {
                [string]$originMainProbe.text
            } else { $null }
            remote_url = if ($remoteProbe.exit_code -eq 0) {
                [string]$remoteProbe.text
            } else { $null }
            status_sha256 = Get-SporeSporeDependencyStringSha256 $status
            clean_pushed_expected_remote = $sourceEligible
            git_tree_listing_sha256 = $keyProjection.git_tree_listing_sha256
            tracked_file_count = [int]$checkout.file_count
            tracked_byte_count = [long]$checkout.byte_count
            checkout_inventory_sha256 = [string]$checkout.inventory_sha256
        }
        environment = [ordered]@{
            status = "complete_process_environment_observed"
            referenced_name_count = [int]$environment.referenced_name_count
            dynamic_reference_count = [int]$environment.dynamic_reference_count
            referenced_inventory_sha256 = [string]$environment.inventory_sha256
            complete_process_name_count = [int]$processEnvironment.variable_count
            complete_process_inventory_sha256 = `
                [string]$processEnvironment.inventory_sha256
            dynamic_reference_values_covered = $true
            raw_values_retained = $false
        }
        runtime = [ordered]@{
            status = [string]$runtimeProfiles.status
            registered_profile_count =
                [int]$runtimeProfiles.registered_profile_count
            complete_profile_count =
                [int]$runtimeProfiles.complete_profile_count
            registered_audit_binding_count =
                [int]$runtimeProfiles.registered_audit_binding_count
            complete_audit_binding_count =
                [int]$runtimeProfiles.complete_audit_binding_count
            inventory_sha256 = [string]$runtimeProfiles.inventory_sha256
            raw_git_configuration_values_retained = $false
            host_semantics_complete = $false
            inventory_complete = $false
        }
        evidence = [ordered]@{
            status =
                "referenced_cas_and_partial_audit_evidence_observed_incomplete"
            explicit_reference_count = [int]$referencedCas.explicit_reference_count
            sha256_literal_count = [int]$referencedCas.sha256_literal_count
            matched_object_count = [int]$referencedCas.matched_object_count
            matched_payload_byte_count = [long]$referencedCas.matched_payload_byte_count
            referenced_cas_inventory_sha256 =
                [string]$referencedCas.inventory_sha256
            audit_dependency_inventory_sha256 =
                [string]$auditDependencies.inventory_sha256
            inventory_sha256 = $combinedEvidenceSha256
            payloads_and_manifests_verified = $true
            unrelated_cas_objects_in_key = $false
            cep1_audit_count = [int]$auditDependencies.cep1_audit_count
            registered_audit_count =
                [int]$auditDependencies.registered_audit_count
            complete_audit_count = [int]$auditDependencies.complete_audit_count
            unregistered_audit_count =
                [int]$auditDependencies.unregistered_audit_count
            non_cas_evidence_dependency_detection_complete = $false
            inventory_complete = $false
        }
        authorization_kernel = [ordered]@{
            status = [string]$authorizationKernel.status
            global_gate_count = [int]$authorizationKernel.global_gate_count
            godot_required_gate_count =
                [int]$authorizationKernel.godot_required_gate_count
            campaign_negative_control_role_count =
                [int]$authorizationKernel.campaign_negative_control_role_count
            inventory_sha256 = [string]$authorizationKernel.inventory_sha256
            global_gate_declaration_complete =
                [bool]$authorizationKernel.global_gate_declaration_complete
            canonical_runner_bindings_complete =
                [bool]$authorizationKernel.canonical_runner_bindings_complete
            global_gate_execution_complete = $false
            campaign_negative_controls_complete = $false
            cold_equivalence_complete = $false
            kernel_commissioned = $false
            physical_launch_permitted = $false
        }
        transitive_dependency_key_complete = $false
        undeclared_dependency_detection_complete = $false
        host_semantics_key_complete = $false
        cache_lookup_permitted = $false
        result_reuse_permitted = $false
        physical_authority = $false
        release_authority = $false
    }
}
