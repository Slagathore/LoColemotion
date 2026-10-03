#requires -Version 7.0

$script:SporeSporeAuditDependencyContractPath = Join-Path `
    $PSScriptRoot "conformance_audit_dependency_contract_v1.json"
$script:SporeSporeAuditDependencyRegistryPath = Join-Path `
    $PSScriptRoot "conformance_audit_dependency_registry_v1.json"

function Get-SporeSporeConformanceAuditDependencyContract {
    [CmdletBinding()]
    param()
    $contract = Get-Content `
        -LiteralPath $script:SporeSporeAuditDependencyContractPath `
        -Raw | ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$contract.schema_version -cne
        "sporespore_conformance_audit_dependency_contract_v1" -or
        [string]$contract.status -cne
        "active_one_complete_audit_reuse_disabled" -or
        [bool]$contract.claims.external_evidence_inventory_complete -or
        [bool]$contract.claims.transitive_dependency_key_complete -or
        [bool]$contract.claims.cache_lookup_permitted -or
        [bool]$contract.claims.result_reuse_permitted -or
        [bool]$contract.claims.physical_execution_authorized) {
        throw "Conformance audit-dependency contract exceeds its authority."
    }
    return $contract
}

function Get-SporeSporeConformanceAuditDependencyRegistry {
    [CmdletBinding()]
    param()
    $registry = Get-Content `
        -LiteralPath $script:SporeSporeAuditDependencyRegistryPath `
        -Raw | ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$registry.schema_version -cne
        "sporespore_conformance_audit_dependency_registry_v1" -or
        [string]$registry.status -cne
        "one_complete_audit_other_audits_unregistered_reuse_disabled" -or
        [bool]$registry.external_evidence_inventory_complete -or
        [bool]$registry.cache_lookup_permitted -or
        [bool]$registry.result_reuse_permitted -or
        [bool]$registry.physical_authority) {
        throw "Conformance audit-dependency registry exceeds its authority."
    }
    return $registry
}

function Get-SporeSporeEvidenceDirectoryQueryInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [AllowEmptyString()][string]$RelativeRoot = "",
        [Parameter(Mandatory)][string]$ImmediateChildNamePrefix,
        [Parameter(Mandatory)][string]$ChildFileProbe,
        [string]$InventoryId = "evidence_directory_query"
    )
    if ([string]::IsNullOrEmpty($ImmediateChildNamePrefix) -or
        $ImmediateChildNamePrefix.Contains("/") -or
        $ImmediateChildNamePrefix.Contains("\") -or
        [string]::IsNullOrWhiteSpace($ChildFileProbe)) {
        throw "Directory-query prefix or child probe is invalid."
    }
    $evidence = [System.IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
    $queryRoot = $evidence
    if (-not [string]::IsNullOrEmpty($RelativeRoot)) {
        $resolved = Get-SporeSporeDependencyRelativePath `
            -Root $evidence `
            -RelativePath $RelativeRoot
        $queryRoot = [string]$resolved.absolute_path
    }
    if (-not (Test-Path -LiteralPath $queryRoot -PathType Container)) {
        throw "Declared evidence query root is missing: $queryRoot"
    }
    Assert-SporeSporeDependencyPathHasNoReparsePoint `
        -Root $evidence `
        -AbsolutePath $queryRoot
    $probeRelative = Get-SporeSporeDependencyRelativePath `
        -Root $queryRoot `
        -RelativePath $ChildFileProbe
    $probeName = [string]$probeRelative.relative_path
    $directoryByName =
        [System.Collections.Generic.Dictionary[string, object]]::new(
            [StringComparer]::Ordinal
        )
    foreach ($directory in @(Get-ChildItem `
        -LiteralPath $queryRoot `
        -Directory `
        -Force)) {
        if ($directory.Name.StartsWith(
            $ImmediateChildNamePrefix,
            [StringComparison]::Ordinal
        )) {
            $directoryByName.Add($directory.Name, $directory)
        }
    }
    $directoryNames = [string[]]@($directoryByName.Keys)
    [Array]::Sort($directoryNames, [StringComparer]::Ordinal)
    $entries = [System.Collections.Generic.List[object]]::new()
    foreach ($directoryName in $directoryNames) {
        $directory = $directoryByName[$directoryName]
        if (($directory.Attributes -band
            [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            throw "Evidence directory-query match is a reparse point: $($directory.FullName)"
        }
        $probePath = Join-Path $directory.FullName ($probeName.Replace('/', '\'))
        Assert-SporeSporeDependencyPathHasNoReparsePoint `
            -Root $queryRoot `
            -AbsolutePath $probePath
        $exists = Test-Path -LiteralPath $probePath
        if ($exists -and -not (Test-Path -LiteralPath $probePath -PathType Leaf)) {
            throw "Evidence directory-query child probe is not a file: $probePath"
        }
        $present = $exists
        $entries.Add([ordered]@{
            directory_name = $directory.Name
            child_probe_relative_path = $probeName
            child_probe_present = $present
            child_probe_byte_length = if ($present) {
                [long](Get-Item -LiteralPath $probePath -Force).Length
            } else { $null }
            child_probe_raw_sha256 = if ($present) {
                Get-SporeSporeDependencyRawSha256 $probePath
            } else { $null }
        })
    }
    $projection = [ordered]@{
        schema_version = "sporespore_evidence_directory_query_inventory_v1"
        relative_root = $RelativeRoot.Replace('\', '/')
        immediate_child_name_prefix = $ImmediateChildNamePrefix
        child_file_probe = $probeName
        entries = @($entries)
    }
    return [ordered]@{
        schema_version =
            "sporespore_evidence_directory_query_inventory_receipt_v1"
        inventory_id = $InventoryId
        root_in_digest = $false
        matching_directory_count = $entries.Count
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        entries = @($entries)
    }
}

function Get-SporeSporeGitObjectSetInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][object[]]$Objects,
        [string]$InventoryId = "git_object_set"
    )
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    if (-not (Test-Path -LiteralPath (Join-Path $repo ".git") -PathType Container)) {
        throw "Declared Git-object root is not a repository."
    }
    $byRole = [System.Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($object in @($Objects)) {
        $role = [string]$object.role
        $objectId = [string]$object.object_id
        $expectedType = [string]$object.object_type
        if ([string]::IsNullOrWhiteSpace($role) -or
            -not $byRole.TryAdd($role, $object) -or
            $objectId -cnotmatch "^[0-9a-f]{40}$" -or
            $expectedType -cnotin @("blob", "commit", "tag", "tree")) {
            throw "Declared Git-object identity is invalid or duplicate."
        }
    }
    if ($byRole.Count -eq 0) { throw "Declared Git-object set is empty." }
    $roles = [string[]]@($byRole.Keys)
    [Array]::Sort($roles, [StringComparer]::Ordinal)
    $gitCommand = Get-Command git -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    $start = [System.Diagnostics.ProcessStartInfo]::new()
    $start.FileName = [string]$gitCommand.Source
    $start.WorkingDirectory = $repo
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @("-C", $repo, "cat-file", "--batch")) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) { throw "Git-object batch process did not start." }
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $stream = $process.StandardOutput.BaseStream
    $receipts = [System.Collections.Generic.List[object]]::new()
    try {
        foreach ($role in $roles) {
            $process.StandardInput.WriteLine([string]$byRole[$role].object_id)
        }
        $process.StandardInput.Close()
        foreach ($role in $roles) {
            $object = $byRole[$role]
            $objectId = [string]$object.object_id
            $headerBytes = [System.Collections.Generic.List[byte]]::new()
            while ($true) {
                $value = $stream.ReadByte()
                if ($value -lt 0) {
                    throw "Git-object batch ended before header: $role $objectId"
                }
                if ($value -eq 10) { break }
                if ($headerBytes.Count -ge 512) {
                    throw "Git-object batch header exceeded its bound."
                }
                $headerBytes.Add([byte]$value)
            }
            $header = [System.Text.Encoding]::ASCII.GetString($headerBytes.ToArray()).TrimEnd("`r")
            $parts = @($header.Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
            if ($parts.Count -ne 3 -or $parts[0] -cne $objectId) {
                throw "Declared Git object is unavailable or resolved ambiguously: $role $objectId"
            }
            $actualType = [string]$parts[1]
            $objectSize = 0L
            if ($actualType -cne [string]$object.object_type -or
                -not [long]::TryParse(
                    [string]$parts[2],
                    [Globalization.NumberStyles]::None,
                    [Globalization.CultureInfo]::InvariantCulture,
                    [ref]$objectSize
                ) -or $objectSize -lt 0 -or $objectSize -gt [int]::MaxValue) {
                throw "Declared Git object type or size is invalid: $role $objectId"
            }
            $content = [byte[]]::new([int]$objectSize)
            $offset = 0
            while ($offset -lt $content.Length) {
                $read = $stream.Read($content, $offset, $content.Length - $offset)
                if ($read -le 0) {
                    throw "Git-object batch ended before content: $role $objectId"
                }
                $offset += $read
            }
            if ($stream.ReadByte() -ne 10) {
                throw "Git-object batch content separator is invalid: $role $objectId"
            }
            $gitHeader = [System.Text.Encoding]::ASCII.GetBytes(
                "$actualType $objectSize`0"
            )
            $gitHasher = [Security.Cryptography.IncrementalHash]::CreateHash(
                [Security.Cryptography.HashAlgorithmName]::SHA1
            )
            try {
                $gitHasher.AppendData($gitHeader)
                $gitHasher.AppendData($content)
                $recomputedObjectId = [Convert]::ToHexString(
                    $gitHasher.GetHashAndReset()
                ).ToLowerInvariant()
            } finally { $gitHasher.Dispose() }
            if ($recomputedObjectId -cne $objectId) {
                throw "Declared Git object raw bytes failed identity rehash: $role $objectId"
            }
            $contentSha256 = "sha256:" + [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($content)
            ).ToLowerInvariant()
            $receipts.Add([ordered]@{
                role = $role
                object_id = $objectId
                object_type = $actualType
                object_size = $objectSize
                raw_content_sha256 = $contentSha256
                git_object_id_recomputed = $true
            })
        }
        $process.WaitForExit(10000) | Out-Null
        if (-not $process.HasExited) {
            $process.Kill($true)
            throw "Git-object batch process timed out."
        }
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0 -or -not [string]::IsNullOrWhiteSpace($stderr)) {
            throw "Git-object batch process failed: $stderr"
        }
    } finally {
        if (-not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
    $projection = [ordered]@{
        schema_version = "sporespore_git_object_set_inventory_v1"
        objects = @($receipts)
    }
    return [ordered]@{
        schema_version = "sporespore_git_object_set_inventory_receipt_v1"
        inventory_id = $InventoryId
        repository_path_in_digest = $false
        object_count = $receipts.Count
        git_object_ids_recomputed = $true
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        objects = @($receipts)
    }
}

function Get-SporeSporeConformanceAuditDependencyCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [string]$EvidenceRoot = ""
    )
    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $evidence = if ([string]::IsNullOrWhiteSpace($EvidenceRoot)) {
        Get-SporeSporeArtifactEvidenceRoot -RepoRoot $repo
    } else {
        [System.IO.Path]::GetFullPath($EvidenceRoot).TrimEnd('\', '/')
    }
    $contract = Get-SporeSporeConformanceAuditDependencyContract
    $registry = Get-SporeSporeConformanceAuditDependencyRegistry
    $cep1Path = Join-Path $repo ([string]$contract.authority.cep1_inventory_path)
    $cep1 = Get-Content -LiteralPath $cep1Path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    $runtimeRegistryPath = Join-Path $repo `
        "sdk\conformance_runtime_profile_registry_v1.json"
    $runtimeRegistry = Get-Content -LiteralPath $runtimeRegistryPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    $completeRuntimeBindings =
        [System.Collections.Generic.HashSet[string]]::new(
            [StringComparer]::Ordinal
        )
    foreach ($runtimeProfile in @($runtimeRegistry.profiles)) {
        if ([bool]$runtimeProfile.audit_binding_complete -and
            [bool]$runtimeProfile.declared_runtime_files_complete -and
            [bool]$runtimeProfile.native_child_reads_complete -and
            [bool]$runtimeProfile.host_semantics_complete) {
            foreach ($binding in @($runtimeProfile.audit_bindings)) {
                [void]$completeRuntimeBindings.Add([string]$binding)
            }
        }
    }
    if ([string]$cep1.schema_version -cne
        "sporespore_closure_evidence_mode_inventory_v1" -or
        [int]$cep1.audit_count -ne [int]$contract.authority.cep1_audit_count -or
        [int]$registry.cep1_audit_count -ne [int]$cep1.audit_count) {
        throw "Audit-dependency registry no longer reconciles with CEP1."
    }
    $cep1ByPath = [System.Collections.Generic.Dictionary[string, object]]::new(
        [StringComparer]::Ordinal
    )
    foreach ($entry in @($cep1.entries)) {
        $cep1ByPath.Add([string]$entry.path, $entry)
    }
    $seen = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    $receipts = [System.Collections.Generic.List[object]]::new()
    $completeCount = 0
    foreach ($entry in @($registry.entries)) {
        $auditPath = [string]$entry.audit_path
        if (-not $seen.Add($auditPath) -or -not $cep1ByPath.ContainsKey($auditPath)) {
            throw "Registered audit is duplicate or absent from CEP1: $auditPath"
        }
        $cep1Entry = $cep1ByPath[$auditPath]
        $resolvedAudit = Get-SporeSporeDependencyRelativePath `
            -Root $repo `
            -RelativePath $auditPath
        $auditRawSha256 = Get-SporeSporeDependencyRawSha256 `
            $resolvedAudit.absolute_path
        if ($auditRawSha256 -cne [string]$entry.audit_raw_sha256 -or
            $auditRawSha256.Substring(7) -cne [string]$cep1Entry.raw_sha256 -or
            [string]$entry.cep1_historical_identity_mode -cne
            [string]$cep1Entry.historical_identity_mode) {
            throw "Registered audit identity no longer matches CEP1: $auditPath"
        }
        $shapeReceipts = [System.Collections.Generic.List[object]]::new()
        foreach ($shape in @($entry.dependency_shapes)) {
            $kind = [string]$shape.kind
            if ($kind -ceq "directory_tree") {
                $resolved = Get-SporeSporeDependencyRelativePath `
                    -Root $evidence `
                    -RelativePath ([string]$shape.evidence_relative_path)
                $inventory = Get-SporeSporeDirectoryFileInventory `
                    -Root $resolved.absolute_path `
                    -InventoryId "$auditPath::$kind"
                $closureTreeLines = @($inventory.entries | ForEach-Object {
                    "{0}`t{1}`t{2}" -f $_.path, $_.byte_length, (
                        [string]$_.raw_sha256
                    ).Substring(7)
                })
                $closureTreeSha256 = Get-SporeSporeDependencyStringSha256 (
                    ($closureTreeLines -join "`n") + "`n"
                )
                $shapeReceipts.Add([ordered]@{
                    kind = $kind
                    evidence_relative_path = [string]$resolved.relative_path
                    file_count = [int]$inventory.file_count
                    byte_count = [long]$inventory.byte_count
                    inventory_sha256 = [string]$inventory.inventory_sha256
                    closure_tree_sha256 = $closureTreeSha256
                    matches_declared = (
                        [int]$inventory.file_count -eq [int]$shape.declared_file_count -and
                        [long]$inventory.byte_count -eq [long]$shape.declared_byte_count -and
                        $closureTreeSha256 -ceq
                        [string]$shape.declared_closure_tree_sha256
                    )
                })
            } elseif ($kind -ceq "file") {
                $inventory = Get-SporeSporeDeclaredFileInventory `
                    -Root $evidence `
                    -RelativePaths @([string]$shape.evidence_relative_path) `
                    -InventoryId "$auditPath::$kind"
                $record = @($inventory.entries)[0]
                $shapeReceipts.Add([ordered]@{
                    kind = $kind
                    evidence_relative_path = [string]$record.path
                    byte_count = [long]$record.byte_length
                    raw_sha256 = [string]$record.raw_sha256
                    inventory_sha256 = [string]$inventory.inventory_sha256
                    matches_declared = (
                        [long]$record.byte_length -eq [long]$shape.declared_byte_count -and
                        [string]$record.raw_sha256 -ceq
                        [string]$shape.declared_raw_sha256
                    )
                })
            } elseif ($kind -ceq "directory_query") {
                $inventory = Get-SporeSporeEvidenceDirectoryQueryInventory `
                    -EvidenceRoot $evidence `
                    -RelativeRoot ([string]$shape.evidence_relative_root) `
                    -ImmediateChildNamePrefix `
                        ([string]$shape.immediate_child_name_prefix) `
                    -ChildFileProbe ([string]$shape.child_file_probe) `
                    -InventoryId "$auditPath::$kind"
                $shapeReceipts.Add([ordered]@{
                    kind = $kind
                    matching_directory_count =
                        [int]$inventory.matching_directory_count
                    inventory_sha256 = [string]$inventory.inventory_sha256
                })
            } elseif ($kind -ceq "git_object_set") {
                $inventory = Get-SporeSporeGitObjectSetInventory `
                    -RepoRoot $repo `
                    -Objects @($shape.objects) `
                    -InventoryId "$auditPath::$kind"
                $shapeReceipts.Add([ordered]@{
                    kind = $kind
                    object_count = [int]$inventory.object_count
                    git_object_ids_recomputed =
                        [bool]$inventory.git_object_ids_recomputed
                    inventory_sha256 = [string]$inventory.inventory_sha256
                    objects = @($inventory.objects)
                })
            } else {
                throw "Unknown audit-dependency shape '$kind' for $auditPath"
            }
        }
        $entryComplete = (
            [bool]$entry.external_evidence_complete -and
            [bool]$entry.runtime_complete -and
            [bool]$entry.transitive_dependency_complete
        )
        if ([bool]$entry.runtime_complete -ne
            $completeRuntimeBindings.Contains($auditPath)) {
            throw "Audit runtime-complete state disagrees with runtime profile: $auditPath"
        }
        if ($entryComplete) { $completeCount++ }
        $receipts.Add([ordered]@{
            audit_path = $auditPath
            status = [string]$entry.status
            audit_raw_sha256 = $auditRawSha256
            dependency_shapes = @($shapeReceipts)
            external_evidence_complete = [bool]$entry.external_evidence_complete
            runtime_complete = [bool]$entry.runtime_complete
            transitive_dependency_complete =
                [bool]$entry.transitive_dependency_complete
            reuse_permitted = $false
        })
    }
    $registeredCount = $receipts.Count
    $unregisteredCount = [int]$cep1.audit_count - $registeredCount
    if ($registeredCount -ne [int]$contract.authority.registered_audit_count -or
        $completeCount -ne [int]$contract.authority.complete_audit_count -or
        $unregisteredCount -ne [int]$contract.authority.unregistered_audit_count -or
        $registeredCount -ne @($registry.entries).Count -or
        $completeCount -ne [int]$registry.complete_audit_count -or
        $unregisteredCount -ne [int]$registry.unregistered_audit_count) {
        throw "Audit-dependency registry counts changed without contract update."
    }
    $projection = [ordered]@{
        schema_version = "sporespore_conformance_audit_dependency_inventory_v1"
        cep1_inventory_raw_sha256 = Get-SporeSporeDependencyRawSha256 $cep1Path
        entries = @($receipts)
    }
    return [ordered]@{
        schema_version =
            "sporespore_conformance_audit_dependency_candidate_v1"
        status = "one_complete_audit_other_audits_unregistered_reuse_disabled"
        cep1_audit_count = [int]$cep1.audit_count
        registered_audit_count = $registeredCount
        complete_audit_count = $completeCount
        unregistered_audit_count = $unregisteredCount
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        entries = @($receipts)
        external_evidence_inventory_complete = $false
        runtime_complete = $false
        transitive_dependency_complete = $false
        cache_lookup_permitted = $false
        result_reuse_permitted = $false
        physical_authority = $false
        release_authority = $false
    }
}
