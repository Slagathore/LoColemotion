#requires -Version 7.0

$script:SporeSporeRuntimeProfileContractPath = Join-Path `
    $PSScriptRoot "conformance_runtime_profile_contract_v1.json"
$script:SporeSporeRuntimeProfileRegistryPath = Join-Path `
    $PSScriptRoot "conformance_runtime_profile_registry_v1.json"

function Get-SporeSporeConformanceRuntimeProfileContract {
    [CmdletBinding()]
    param()
    $contract = Get-Content `
        -LiteralPath $script:SporeSporeRuntimeProfileContractPath `
        -Raw | ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$contract.schema_version -cne
        "sporespore_conformance_runtime_profile_contract_v1" -or
        [string]$contract.status -cne
        "active_one_complete_profile_cache_disabled" -or
        [bool]$contract.claims.runtime_inventory_complete -or
        [bool]$contract.claims.host_semantics_complete -or
        [bool]$contract.claims.cache_lookup_permitted -or
        [bool]$contract.claims.result_reuse_permitted -or
        [bool]$contract.claims.physical_execution_authorized) {
        throw "Conformance runtime-profile contract exceeds its authority."
    }
    return $contract
}

function Get-SporeSporeConformanceRuntimeProfileRegistry {
    [CmdletBinding()]
    param()
    $registry = Get-Content `
        -LiteralPath $script:SporeSporeRuntimeProfileRegistryPath `
        -Raw | ConvertFrom-Json -AsHashtable -Depth 32
    if ([string]$registry.schema_version -cne
        "sporespore_conformance_runtime_profile_registry_v1" -or
        [string]$registry.status -cne
        "one_complete_profile_other_audits_unregistered_cache_disabled" -or
        [bool]$registry.runtime_inventory_complete -or
        [bool]$registry.host_semantics_complete -or
        [bool]$registry.cache_lookup_permitted -or
        [bool]$registry.result_reuse_permitted -or
        [bool]$registry.physical_authority) {
        throw "Conformance runtime-profile registry exceeds its authority."
    }
    return $registry
}

function Get-SporeSporeRuntimeConfigFileReceipt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Role,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$RelativePath
    )
    $inventory = Get-SporeSporeDeclaredFileInventory `
        -Root $Root `
        -RelativePaths @($RelativePath) `
        -InventoryId "git_config_$Role"
    $entry = @($inventory.entries)[0]
    return [ordered]@{
        role = $Role
        path_token = "git_config:$Role"
        byte_length = [long]$entry.byte_length
        raw_sha256 = [string]$entry.raw_sha256
        raw_value_retained = $false
    }
}

function Get-SporeSporeConformanceRuntimeProfileCandidate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)

    $repo = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
    $contract = Get-SporeSporeConformanceRuntimeProfileContract
    $registry = Get-SporeSporeConformanceRuntimeProfileRegistry
    if (@($registry.profiles).Count -ne
            [int]$contract.profile_authority.registered_profile_count -or
        [int]$registry.registered_profile_count -ne
            [int]$contract.profile_authority.registered_profile_count -or
        [int]$registry.complete_profile_count -ne
            [int]$contract.profile_authority.complete_profile_count -or
        [int]$registry.registered_audit_binding_count -ne
            [int]$contract.profile_authority.registered_audit_binding_count -or
        [int]$registry.complete_audit_binding_count -ne
            [int]$contract.profile_authority.complete_audit_binding_count) {
        throw "Runtime-profile registry counts changed without contract update."
    }
    $profile = @($registry.profiles)[0]
    if ([string]$profile.profile_id -cne
        "windows-powershell-git-r23d13-parent-child-v2" -or
        @($profile.audit_bindings).Count -ne 1 -or
        [string]@($profile.audit_bindings)[0] -cne
        "tests/test_qsdk_r23d13_closure.ps1" -or
        -not [bool]$profile.declared_runtime_files_complete -or
        -not [bool]$profile.native_child_reads_complete -or
        -not [bool]$profile.host_semantics_complete -or
        -not [bool]$profile.audit_binding_complete -or
        [bool]$profile.reuse_permitted) {
        throw "Runtime-profile registry identity changed."
    }

    $sourceFiles = Get-SporeSporeDeclaredFileInventory `
        -Root $repo `
        -RelativePaths @($profile.measured_source_bindings.path) `
        -InventoryId "r23d13_runtime_profile_measured_sources"
    $declaredSourceByPath =
        [System.Collections.Generic.Dictionary[string, object]]::new(
            [StringComparer]::OrdinalIgnoreCase
        )
    foreach ($binding in @($profile.measured_source_bindings)) {
        if (-not $declaredSourceByPath.TryAdd([string]$binding.path, $binding)) {
            throw "Runtime-profile measured source binding is duplicate."
        }
    }
    foreach ($entry in @($sourceFiles.entries)) {
        $declared = $declaredSourceByPath[[string]$entry.path]
        if ($null -eq $declared -or
            [long]$entry.byte_length -ne [long]$declared.byte_length -or
            [string]$entry.raw_sha256 -cne [string]$declared.raw_sha256) {
            throw "Runtime-profile measured source binding changed: $($entry.path)"
        }
    }

    $powerShellRoot = [System.IO.Path]::GetFullPath($PSHOME).TrimEnd('\', '/')
    $powerShellFiles = Get-SporeSporeDeclaredFileInventory `
        -Root $powerShellRoot `
        -RelativePaths @($profile.powershell.relative_files) `
        -InventoryId "powershell_r23d13_parent"
    if ([int]$powerShellFiles.file_count -ne
            [int]$profile.powershell.observed_file_count -or
        [long]$powerShellFiles.byte_count -ne
            [long]$profile.powershell.observed_byte_count) {
        throw "PowerShell runtime profile file count or byte count changed."
    }
    $powerShellIdentity = [ordered]@{
        ps_version = $PSVersionTable.PSVersion.ToString()
        ps_edition = [string]$PSVersionTable.PSEdition
        git_commit_id = [string]$PSVersionTable.GitCommitId
        process_architecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        os_architecture = [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        os_description = [Runtime.InteropServices.RuntimeInformation]::OSDescription
    }

    $gitCommand = Get-Command git -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    $gitCommandPath = [System.IO.Path]::GetFullPath($gitCommand.Source)
    $gitRoot = [System.IO.Path]::GetFullPath(
        (Split-Path -Parent (Split-Path -Parent $gitCommandPath))
    ).TrimEnd('\', '/')
    $gitCommandRelative = [System.IO.Path]::GetRelativePath(
        $gitRoot,
        $gitCommandPath
    ).Replace('\', '/')
    if ($gitCommandRelative -cne [string]$profile.git.command_relative_path) {
        throw "Resolved Git command is outside the declared runtime shape."
    }
    $gitFiles = Get-SporeSporeDeclaredFileInventory `
        -Root $gitRoot `
        -RelativePaths @($profile.git.relative_files) `
        -InventoryId "git_r23d13_parent"
    $gitVersion = @(& $gitCommandPath --version 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Git version probe failed." }
    $gitExecPath = @(& $gitCommandPath --exec-path 2>&1) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw "Git exec-path probe failed." }
    $gitExecFull = [System.IO.Path]::GetFullPath($gitExecPath.Trim())
    $gitExecRelative = [System.IO.Path]::GetRelativePath(
        $gitRoot,
        $gitExecFull
    ).Replace('\', '/')
    if ($gitExecRelative -cne [string]$profile.git.exec_path_relative_path) {
        throw "Git exec path is outside the declared runtime shape."
    }

    $systemConfig = Join-Path $gitRoot "etc\gitconfig"
    $userProfile = [Environment]::GetFolderPath(
        [Environment+SpecialFolder]::UserProfile
    )
    $globalConfig = Join-Path $userProfile ".gitconfig"
    $repoConfig = Join-Path $repo ".git\config"
    $configSpecifications = @(
        [ordered]@{
            role = "system"
            root = $gitRoot
            relative = "etc/gitconfig"
            absolute = $systemConfig
        },
        [ordered]@{
            role = "global"
            root = $userProfile
            relative = ".gitconfig"
            absolute = $globalConfig
        },
        [ordered]@{
            role = "repository"
            root = $repo
            relative = ".git/config"
            absolute = $repoConfig
        }
    )
    $configReceipts = [System.Collections.Generic.List[object]]::new()
    foreach ($specification in $configSpecifications) {
        $configReceipts.Add((Get-SporeSporeRuntimeConfigFileReceipt `
            -Role ([string]$specification.role) `
            -Root ([string]$specification.root) `
            -RelativePath ([string]$specification.relative)))
    }
    $originLines = @(& $gitCommandPath `
        -C $repo `
        config `
        --show-origin `
        --name-only `
        --list 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "Git configuration-origin probe failed." }
    $originPaths = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($line in $originLines) {
        $text = [string]$line
        $tab = $text.IndexOf("`t", [StringComparison]::Ordinal)
        $origin = if ($tab -ge 0) { $text.Substring(0, $tab) } else { $text }
        if (-not $origin.StartsWith("file:", [StringComparison]::Ordinal)) {
            throw "Git reported an undeclared non-file configuration origin."
        }
        $originPath = $origin.Substring(5)
        if (-not [System.IO.Path]::IsPathRooted($originPath)) {
            $originPath = Join-Path $repo $originPath
        }
        [void]$originPaths.Add([System.IO.Path]::GetFullPath($originPath))
    }
    $expectedOrigins = [System.Collections.Generic.HashSet[string]]::new(
        [StringComparer]::OrdinalIgnoreCase
    )
    foreach ($specification in $configSpecifications) {
        [void]$expectedOrigins.Add(
            [System.IO.Path]::GetFullPath([string]$specification.absolute)
        )
    }
    if (-not $originPaths.SetEquals($expectedOrigins)) {
        throw "Git configuration origins differ from the declared profile."
    }

    $windowsRoot = [System.IO.Path]::GetFullPath(
        [Environment]::GetEnvironmentVariable("SystemRoot")
    ).TrimEnd('\', '/')
    $windowsFiles = Get-SporeSporeDeclaredFileInventory `
        -Root $windowsRoot `
        -RelativePaths @($profile.host.windows_relative_files) `
        -InventoryId "windows_host_r23d13_parent_child"
    if ([int]$windowsFiles.file_count -ne
            [int]$profile.host.windows_observed_file_count -or
        [long]$windowsFiles.byte_count -ne
            [long]$profile.host.windows_observed_byte_count) {
        throw "Windows host runtime file count or byte count changed."
    }
    $commonApplicationData = [System.IO.Path]::GetFullPath(
        [Environment]::GetFolderPath(
            [Environment+SpecialFolder]::CommonApplicationData
        )
    ).TrimEnd('\', '/')
    $defenderFiles = Get-SporeSporeDeclaredFileInventory `
        -Root $commonApplicationData `
        -RelativePaths @($profile.host.common_application_data_relative_files) `
        -InventoryId "defender_host_r23d13_parent_child"
    if ([int]$defenderFiles.file_count -ne
            [int]$profile.host.common_application_data_observed_file_count -or
        [long]$defenderFiles.byte_count -ne
            [long]$profile.host.common_application_data_observed_byte_count) {
        throw "Defender host runtime file count or byte count changed."
    }
    $currentVersion = Get-ItemProperty `
        -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $sourceDrive = [System.IO.DriveInfo]::new(
        [System.IO.Path]::GetPathRoot($repo)
    )
    $hostSemantics = [ordered]@{
        product_name = [string]$currentVersion.ProductName
        display_version = [string]$currentVersion.DisplayVersion
        current_build = [string]$currentVersion.CurrentBuild
        ubr = [int]$currentVersion.UBR
        build_lab_ex = [string]$currentVersion.BuildLabEx
        installation_type = [string]$currentVersion.InstallationType
        os_version = [Environment]::OSVersion.VersionString
        framework_description =
            [Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
        os_description =
            [Runtime.InteropServices.RuntimeInformation]::OSDescription
        process_architecture =
            [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
        os_architecture =
            [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
        culture = [Globalization.CultureInfo]::CurrentCulture.Name
        ui_culture = [Globalization.CultureInfo]::CurrentUICulture.Name
        time_zone = [TimeZoneInfo]::Local.Id
        input_encoding = [Console]::InputEncoding.WebName
        output_encoding = [Console]::OutputEncoding.WebName
        source_volume_format = $sourceDrive.DriveFormat
    }
    foreach ($name in @($profile.host.semantics.Keys)) {
        if (-not $hostSemantics.Contains($name) -or
            [string]$hostSemantics[$name] -cne
            [string]$profile.host.semantics[$name]) {
            throw "Host semantic identity changed: $name"
        }
    }
    if ($hostSemantics.Count -ne @($profile.host.semantics.Keys).Count) {
        throw "Host semantic identity has undeclared fields."
    }
    $hostProjection = [ordered]@{
        schema_version = "sporespore_r23d13_host_runtime_inventory_v1"
        windows_inventory_sha256 = [string]$windowsFiles.inventory_sha256
        defender_inventory_sha256 = [string]$defenderFiles.inventory_sha256
        semantics = $hostSemantics
    }

    $profileReceipt = [ordered]@{
        profile_id = [string]$profile.profile_id
        audit_bindings = @($profile.audit_bindings)
        measured_source = [ordered]@{
            file_count = [int]$sourceFiles.file_count
            byte_count = [long]$sourceFiles.byte_count
            inventory_sha256 = [string]$sourceFiles.inventory_sha256
        }
        powershell = [ordered]@{
            identity = $powerShellIdentity
            root_in_digest = $false
            file_count = [int]$powerShellFiles.file_count
            byte_count = [long]$powerShellFiles.byte_count
            inventory_sha256 = [string]$powerShellFiles.inventory_sha256
        }
        git = [ordered]@{
            version_output = $gitVersion.Trim()
            command_relative_path = $gitCommandRelative
            exec_path_relative_path = $gitExecRelative
            root_in_digest = $false
            file_count = [int]$gitFiles.file_count
            byte_count = [long]$gitFiles.byte_count
            inventory_sha256 = [string]$gitFiles.inventory_sha256
            configuration_file_count = $configReceipts.Count
            configuration = @($configReceipts)
        }
        host = [ordered]@{
            windows_file_count = [int]$windowsFiles.file_count
            windows_byte_count = [long]$windowsFiles.byte_count
            windows_inventory_sha256 = [string]$windowsFiles.inventory_sha256
            defender_file_count = [int]$defenderFiles.file_count
            defender_byte_count = [long]$defenderFiles.byte_count
            defender_inventory_sha256 = [string]$defenderFiles.inventory_sha256
            semantics = $hostSemantics
            inventory_sha256 =
                Get-SporeSporeDependencyObjectSha256 $hostProjection
        }
        declared_runtime_files_complete =
            [bool]$profile.declared_runtime_files_complete
        native_child_reads_complete = [bool]$profile.native_child_reads_complete
        host_semantics_complete = [bool]$profile.host_semantics_complete
        audit_binding_complete = [bool]$profile.audit_binding_complete
        reuse_permitted = $false
    }
    $projection = [ordered]@{
        schema_version = "sporespore_conformance_runtime_profile_inventory_v1"
        profiles = @($profileReceipt)
    }
    return [ordered]@{
        schema_version = "sporespore_conformance_runtime_profile_candidate_v1"
        status = "partial_runtime_profile_cache_disabled"
        registered_profile_count = [int]$registry.registered_profile_count
        complete_profile_count = [int]$registry.complete_profile_count
        registered_audit_binding_count =
            [int]$registry.registered_audit_binding_count
        complete_audit_binding_count =
            [int]$registry.complete_audit_binding_count
        inventory_sha256 = Get-SporeSporeDependencyObjectSha256 $projection
        profiles = @($profileReceipt)
        raw_git_configuration_values_retained = $false
        runtime_inventory_complete = $false
        host_semantics_complete = $false
        transitive_dependency_complete = $false
        cache_lookup_permitted = $false
        result_reuse_permitted = $false
        physical_authority = $false
        release_authority = $false
    }
}
