[CmdletBinding()]
param(
    [string]$Contract = (
        Join-Path $PSScriptRoot "quadruped_distribution_licensing_contract_v1.json"
    ),
    [string]$SourceInventory = (
        Join-Path $PSScriptRoot "quadruped_package_source_inventory_v1.json"
    ),
    [string]$Output = "",
    [switch]$RequireReady
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$releaseRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$sdkRoot = [IO.Path]::GetFullPath((Split-Path -Parent $releaseRoot))
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$contractPath = [IO.Path]::GetFullPath($Contract)
$inventoryPath = [IO.Path]::GetFullPath($SourceInventory)

function Assert-Exact([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonObject([string]$Path) {
    Assert-Exact (Test-Path -LiteralPath $Path -PathType Leaf) (
        "Required distribution source is missing: $Path"
    )
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
    Assert-Exact ($null -ne $value -and $value -is [pscustomobject]) (
        "Expected one JSON object at $Path"
    )
    return $value
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-OptionalString([object]$Value) {
    if ($null -eq $Value) {
        return ""
    }
    return [string]$Value
}

function Test-IsInsidePath([string]$Candidate, [string]$Parent) {
    $candidatePath = [IO.Path]::GetFullPath($Candidate)
    $parentPath = [IO.Path]::GetFullPath($Parent).TrimEnd(
        [IO.Path]::DirectorySeparatorChar,
        [IO.Path]::AltDirectorySeparatorChar
    )
    $prefix = $parentPath + [IO.Path]::DirectorySeparatorChar
    return $candidatePath.StartsWith(
        $prefix,
        [StringComparison]::OrdinalIgnoreCase
    )
}

$contractObject = Read-JsonObject $contractPath
$sourceInventoryObject = Read-JsonObject $inventoryPath
Assert-Exact (
    [string]$contractObject.schema_version -ceq
        "sporespore_quadruped_distribution_licensing_contract_v1" -and
    [string]$contractObject.release_gate_id -ceq "QSDK-R19" -and
    [string]$contractObject.sdk1_milestone_id -ceq "SDK1-M14"
) "Unexpected distribution/licensing contract identity"
Assert-Exact (
    [string]$contractObject.ledger_scope.subsystem -ceq "release" -and
    [string]$contractObject.ledger_scope.engine_scope -ceq "engine_neutral" -and
    [string]$contractObject.ledger_scope.question_class -ceq "development"
) "Distribution/licensing ledger scope is invalid"
Assert-Exact (
    @("owner_decision_pending", "active_distribution_decision") -ccontains
        [string]$contractObject.status
) "Unsupported distribution/licensing contract status"
Assert-Exact (
    [string]$sourceInventoryObject.schema_version -ceq
        "sporespore_quadruped_package_source_inventory_v1" -and
    [string]$sourceInventoryObject.source_root -ceq "sdk" -and
    -not [bool]$sourceInventoryObject.claim_boundary.inventory_is_a_package_authorization -and
    -not [bool]$sourceInventoryObject.claim_boundary.inventory_is_a_publication_authorization
) "Package source inventory claim boundary is invalid"
Assert-Exact (
    -not [bool]$contractObject.claim_boundary.contract_alone_satisfies_qsdk_r19 -and
    -not [bool]$contractObject.claim_boundary.contract_alone_satisfies_sdk1_m14 -and
    -not [bool]$contractObject.claim_boundary.package_authorized -and
    -not [bool]$contractObject.claim_boundary.publication_authorized -and
    -not [bool]$contractObject.claim_boundary.release_authorized -and
    -not [bool]$contractObject.claim_boundary.physical_acceptance_authority
) "Distribution/licensing contract escaped its non-authoritative boundary"

$observedRoot = (& git -C $repoRoot rev-parse --show-toplevel).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    [IO.Path]::GetFullPath($observedRoot) -ceq $repoRoot
) "Distribution compiler is not running in the canonical repository"
$observedRemote = (& git -C $repoRoot remote get-url origin).Trim()
Assert-Exact (
    $LASTEXITCODE -eq 0 -and
    $observedRemote -ceq [string]$contractObject.repository.expected_remote
) "Distribution compiler observed an unexpected origin remote"
$sourceCommit = (& git -C $repoRoot rev-parse HEAD).Trim()
Assert-Exact ($LASTEXITCODE -eq 0 -and $sourceCommit -match '^[0-9a-f]{40}$') (
    "Could not resolve the distribution source commit"
)
$originMain = (& git -C $repoRoot rev-parse origin/main).Trim()
$originResolved = $LASTEXITCODE -eq 0 -and $originMain -match '^[0-9a-f]{40}$'
$sourceStatus = @(
    & git -C $repoRoot status --porcelain=v1 --untracked-files=all
)
Assert-Exact ($LASTEXITCODE -eq 0) "Could not inspect distribution source status"
$sourceClean = $sourceStatus.Count -eq 0
$sourceMatchesOriginMain = $originResolved -and $sourceCommit -ceq $originMain

$lockPath = Join-Path $repoRoot (
    [string]$contractObject.locked_dependency_population.cargo_lock_path
)
Assert-Exact (
    (Get-Sha256 $lockPath) -ceq
        [string]$contractObject.locked_dependency_population.cargo_lock_sha256 -and
    (Get-Item -LiteralPath $lockPath).Length -eq
        [long]$contractObject.locked_dependency_population.cargo_lock_byte_length
) "Locked dependency population changed without a contract update"
$manifestPath = Join-Path $repoRoot (
    [string]$contractObject.locked_dependency_population.workspace_manifest_path
)
$metadataOutput = @(
    & cargo metadata `
        --manifest-path $manifestPath `
        --locked `
        --offline `
        --format-version 1
)
Assert-Exact ($LASTEXITCODE -eq 0) "Locked offline Cargo metadata failed"
try {
    $metadata = ($metadataOutput -join "`n") | ConvertFrom-Json -Depth 100
} catch {
    throw "Cargo metadata did not emit valid JSON: $($_.Exception.Message)"
}
$workspacePackages = @(
    $metadata.packages |
        Where-Object { $null -eq $_.source } |
        Sort-Object name, version
)
$externalPackages = @(
    $metadata.packages |
        Where-Object { $null -ne $_.source } |
        Sort-Object name, version
)
Assert-Exact (
    $workspacePackages.Count -eq
        [int]$contractObject.locked_dependency_population.workspace_package_count
) "Workspace package count drifted"
Assert-Exact (
    $externalPackages.Count -eq
        [int]$contractObject.locked_dependency_population.external_package_count
) "External locked dependency count drifted"
Assert-Exact (
    @($externalPackages | Where-Object {
        [string]::IsNullOrWhiteSpace((Get-OptionalString $_.license))
    }).Count -eq 0
) "A locked external dependency has no declared license expression"
$actualWorkspaceProjection = @(
    $workspacePackages | ForEach-Object {
        $manifestRelativePath = [IO.Path]::GetRelativePath(
            $repoRoot,
            [string]$_.manifest_path
        ).Replace("\", "/")
        "$($_.name)|$($_.version)|$manifestRelativePath"
    }
)
$expectedWorkspaceProjection = @(
    $contractObject.locked_dependency_population.workspace_packages |
        Sort-Object name, version |
        ForEach-Object {
            "$($_.name)|$($_.version)|$($_.manifest_path)"
        }
)
Assert-Exact (
    ($actualWorkspaceProjection -join "`n") -ceq
        ($expectedWorkspaceProjection -join "`n")
) "Workspace package identity projection drifted"
$actualExpressionCounts = @(
    $externalPackages |
        Group-Object license |
        Sort-Object Name |
        ForEach-Object { "$($_.Name)|$($_.Count)" }
)
$expectedExpressionCounts = @(
    $contractObject.locked_dependency_population.declared_license_expression_counts |
        Sort-Object expression |
        ForEach-Object { "$($_.expression)|$($_.count)" }
)
Assert-Exact (
    ($actualExpressionCounts -join "`n") -ceq
        ($expectedExpressionCounts -join "`n")
) "Locked dependency license-expression population drifted"

$pathspecs = @(
    $sourceInventoryObject.git_pathspecs | ForEach-Object { [string]$_ }
)
$trackedFiles = @(& git -C $repoRoot ls-files -- @pathspecs | Sort-Object -Unique)
Assert-Exact ($LASTEXITCODE -eq 0 -and $trackedFiles.Count -gt 0) (
    "Could not enumerate the package source projection"
)
$trackedPackagePaths = @(
    $trackedFiles | ForEach-Object {
        $_.Substring("sdk/".Length).Replace("\", "/")
    }
)
$binaryLikePaths = @($trackedPackagePaths | Where-Object {
    $_ -match '(?i)\.(exe|dll|pdb|lib|a|so|dylib|wasm|rlib|pyc)$'
})
Assert-Exact (
    -not [bool]$contractObject.distribution_scope.compiled_artifacts_allowed_in_source_projection -and
    $binaryLikePaths.Count -eq 0
) "Compiled artifact entered the source-first package projection"
$patchPaths = @(
    $trackedFiles | Where-Object {
        $_ -match '^sdk/adapters/godot/engine_patches/[^/]+\.patch$'
    }
)
$expectedPatchEntries = @(
    $contractObject.distribution_scope.godot_jolt_patch_files |
        Sort-Object path
)
Assert-Exact (
    $patchPaths.Count -eq
        [int]$contractObject.distribution_scope.godot_jolt_patch_count -and
    ($patchPaths -join "|") -ceq
        (@($expectedPatchEntries | ForEach-Object { [string]$_.path }) -join "|")
) "Godot/Jolt redistributed patch population drifted"
foreach ($patch in $expectedPatchEntries) {
    $patchPath = Join-Path $repoRoot ([string]$patch.path)
    Assert-Exact (
        (Get-Sha256 $patchPath) -ceq [string]$patch.sha256 -and
        (Get-Item -LiteralPath $patchPath).Length -eq [long]$patch.byte_length
    ) "Godot/Jolt patch identity drifted: $($patch.path)"
}

$selectedLicense = Get-OptionalString (
    $contractObject.owner_decision.selected_spdx_expression
)
$copyrightHolder = Get-OptionalString (
    $contractObject.owner_decision.copyright_holder
)
$standardOptions = @(
    $contractObject.owner_decision.standard_options |
        ForEach-Object { [string]$_ }
)
Assert-Exact (
    ($standardOptions -join "|") -ceq
        "MIT OR Apache-2.0|Apache-2.0|MIT" -and
    [bool]$contractObject.owner_decision.custom_or_proprietary_terms_require_new_reviewed_contract
) "Distribution owner-choice population drifted"
$decisionRecorded = (
    [string]$contractObject.status -ceq "active_distribution_decision" -and
    [string]$contractObject.owner_decision.status -ceq "selected" -and
    $standardOptions -ccontains $selectedLicense -and
    -not [string]::IsNullOrWhiteSpace($copyrightHolder)
)
if ([string]$contractObject.status -ceq "owner_decision_pending") {
    Assert-Exact (
        [string]$contractObject.owner_decision.status -ceq "pending" -and
        [string]::IsNullOrWhiteSpace($selectedLicense) -and
        [string]::IsNullOrWhiteSpace($copyrightHolder) -and
        @($contractObject.legal_file_bindings).Count -eq 0
    ) "Pending distribution contract contains an implicit owner decision"
}

$requiredRoles = @(
    $contractObject.legal_file_contract.common_required_roles |
        ForEach-Object { [string]$_ }
)
if ($selectedLicense -ceq "MIT OR Apache-2.0") {
    $requiredRoles += @(
        $contractObject.legal_file_contract.dual_or_apache_required_roles |
            ForEach-Object { [string]$_ }
    )
    $requiredRoles += @(
        $contractObject.legal_file_contract.dual_required_roles |
            ForEach-Object { [string]$_ }
    )
} elseif ($selectedLicense -ceq "Apache-2.0") {
    $requiredRoles += @(
        $contractObject.legal_file_contract.dual_or_apache_required_roles |
            ForEach-Object { [string]$_ }
    )
}
$requiredRoles = @($requiredRoles | Sort-Object -Unique)
$legalBindings = @($contractObject.legal_file_bindings)
$legalFailures = [Collections.Generic.List[object]]::new()
$boundRoles = @($legalBindings | ForEach-Object { [string]$_.role })
if (
    @($boundRoles | Sort-Object -Unique).Count -ne $boundRoles.Count -or
    (@($boundRoles | Sort-Object) -join "|") -cne ($requiredRoles -join "|")
) {
    [void]$legalFailures.Add([ordered]@{
        failure_code = "LEGAL_ROLE_POPULATION_MISMATCH"
        expected_roles = $requiredRoles
        actual_roles = @($boundRoles | Sort-Object)
    })
}
foreach ($binding in $legalBindings) {
    $relativePath = ([string]$binding.path).Replace("\", "/")
    if (
        [string]::IsNullOrWhiteSpace($relativePath) -or
        [IO.Path]::IsPathRooted($relativePath) -or
        $relativePath -match '(^|/)\.\.(/|$)'
    ) {
        [void]$legalFailures.Add([ordered]@{
            failure_code = "UNSAFE_LEGAL_FILE_PATH"
            path = $relativePath
        })
        continue
    }
    $legalPath = Join-Path $sdkRoot $relativePath
    if (-not (Test-Path -LiteralPath $legalPath -PathType Leaf)) {
        [void]$legalFailures.Add([ordered]@{
            failure_code = "LEGAL_FILE_MISSING"
            path = $relativePath
        })
        continue
    }
    if (
        ((Get-Item -LiteralPath $legalPath).Attributes -band
            [IO.FileAttributes]::ReparsePoint) -ne 0
    ) {
        [void]$legalFailures.Add([ordered]@{
            failure_code = "LEGAL_FILE_IS_REPARSE_POINT"
            path = $relativePath
        })
    }
    if ($trackedPackagePaths -cnotcontains $relativePath) {
        [void]$legalFailures.Add([ordered]@{
            failure_code = "LEGAL_FILE_NOT_IN_PACKAGE_PROJECTION"
            path = $relativePath
        })
    }
    if (
        (Get-Sha256 $legalPath) -cne [string]$binding.sha256 -or
        (Get-Item -LiteralPath $legalPath).Length -ne [long]$binding.byte_length
    ) {
        [void]$legalFailures.Add([ordered]@{
            failure_code = "LEGAL_FILE_IDENTITY_MISMATCH"
            path = $relativePath
        })
    }
    if (
        [bool]$binding.must_contain_copyright_holder -and
        -not [string]::IsNullOrWhiteSpace($copyrightHolder) -and
        -not (Get-Content -Raw -LiteralPath $legalPath).Contains(
            $copyrightHolder,
            [StringComparison]::Ordinal
        )
    ) {
        [void]$legalFailures.Add([ordered]@{
            failure_code = "COPYRIGHT_HOLDER_NOT_FOUND"
            path = $relativePath
        })
    }
}
$legalFilesValid = $decisionRecorded -and $legalFailures.Count -eq 0
$workspaceLicenseProjection = @(
    $workspacePackages | ForEach-Object {
        [ordered]@{
            name = [string]$_.name
            version = [string]$_.version
            license = Get-OptionalString $_.license
            manifest_path = [IO.Path]::GetRelativePath(
                $repoRoot,
                [string]$_.manifest_path
            ).Replace("\", "/")
        }
    }
)
$workspaceLicenseMetadataValid = (
    $decisionRecorded -and
    @($workspaceLicenseProjection | Where-Object {
        [string]$_.license -cne $selectedLicense
    }).Count -eq 0
)

$blockingConditions = [Collections.Generic.List[string]]::new()
if ([string]::IsNullOrWhiteSpace($selectedLicense)) {
    [void]$blockingConditions.Add("QSDK-R19-OWNER-LICENSE-CHOICE")
}
if ([string]::IsNullOrWhiteSpace($copyrightHolder)) {
    [void]$blockingConditions.Add("QSDK-R19-COPYRIGHT-HOLDER")
}
if (-not $decisionRecorded) {
    [void]$blockingConditions.Add("QSDK-R19-OWNER-DECISION-RECORD")
}
if (-not $legalFilesValid) {
    [void]$blockingConditions.Add("QSDK-R19-LEGAL-FILE-BINDINGS")
}
if (-not $workspaceLicenseMetadataValid) {
    [void]$blockingConditions.Add("QSDK-R19-CARGO-LICENSE-METADATA")
}
if (-not $sourceClean) {
    [void]$blockingConditions.Add("QSDK-R19-SOURCE-CLEAN")
}
if (-not $sourceMatchesOriginMain) {
    [void]$blockingConditions.Add("QSDK-R19-SOURCE-ORIGIN-MAIN")
}
$r19Passed = $blockingConditions.Count -eq 0
$report = [ordered]@{
    schema_version = "sporespore_quadruped_distribution_licensing_readiness_report_v1"
    status = if ($r19Passed) { "passed" } elseif ($decisionRecorded) { "blocked" } else { "owner_decision_pending" }
    release_gate_id = "QSDK-R19"
    sdk1_milestone_id = "SDK1-M14"
    ledger_scope = $contractObject.ledger_scope
    source = [ordered]@{
        commit = $sourceCommit
        origin_main = if ($originResolved) { $originMain } else { $null }
        clean = $sourceClean
        matches_origin_main = $sourceMatchesOriginMain
        status_entries = $sourceStatus
    }
    contract = [ordered]@{
        path = [IO.Path]::GetRelativePath($repoRoot, $contractPath).Replace("\", "/")
        sha256 = Get-Sha256 $contractPath
    }
    package_source_inventory = [ordered]@{
        path = [IO.Path]::GetRelativePath($repoRoot, $inventoryPath).Replace("\", "/")
        sha256 = Get-Sha256 $inventoryPath
        tracked_file_count = $trackedFiles.Count
        binary_like_file_count = $binaryLikePaths.Count
        source_first_projection_passed = $binaryLikePaths.Count -eq 0
    }
    owner_decision = [ordered]@{
        recorded = $decisionRecorded
        selected_spdx_expression = if ([string]::IsNullOrWhiteSpace($selectedLicense)) { $null } else { $selectedLicense }
        copyright_holder = if ([string]::IsNullOrWhiteSpace($copyrightHolder)) { $null } else { $copyrightHolder }
        standard_options = $standardOptions
        custom_or_proprietary_terms_require_new_reviewed_contract = $true
    }
    locked_dependencies = [ordered]@{
        cargo_lock_sha256 = Get-Sha256 $lockPath
        workspace_package_count = $workspacePackages.Count
        external_package_count = $externalPackages.Count
        external_packages_with_declared_license_count = @(
            $externalPackages | Where-Object {
                -not [string]::IsNullOrWhiteSpace((Get-OptionalString $_.license))
            }
        ).Count
        declared_license_expression_counts = @(
            $externalPackages |
                Group-Object license |
                Sort-Object Name |
                ForEach-Object {
                    [ordered]@{
                        expression = [string]$_.Name
                        count = [int]$_.Count
                    }
                }
        )
        packages = @(
            $externalPackages | ForEach-Object {
                [ordered]@{
                    name = [string]$_.name
                    version = [string]$_.version
                    source = [string]$_.source
                    license = [string]$_.license
                }
            }
        )
    }
    workspace_packages = $workspaceLicenseProjection
    redistributed_patch_population = [ordered]@{
        count = $patchPaths.Count
        exact_identity_passed = $true
        files = $expectedPatchEntries
    }
    legal_files = [ordered]@{
        required_roles = $requiredRoles
        binding_count = $legalBindings.Count
        bindings_valid = $legalFilesValid
        failures = @($legalFailures)
    }
    blocking_conditions = @($blockingConditions)
    r19_passed = $r19Passed
    sdk1_m14_passed = $r19Passed
    execution = [ordered]@{
        physics_engine_process_count = 0
        physics_model_construction_count = 0
        world_build_count = 0
        native_physics_read_count = 0
        solver_step_count = 0
    }
    claims = [ordered]@{
        dependency_license_metadata_inventory_complete = $true
        package_source_projection_contains_compiled_artifacts = $false
        owner_license_choice_inferred = $false
        package_authorized = $false
        publication_authorized = $false
        release_authorized = $false
        physical_acceptance_authority = $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($Output)) {
    $outputPath = [IO.Path]::GetFullPath($Output)
    Assert-Exact (-not (Test-Path -LiteralPath $outputPath)) (
        "Refusing to overwrite distribution readiness output: $outputPath"
    )
    Assert-Exact (
        $outputPath -cne $repoRoot -and
        -not (Test-IsInsidePath -Candidate $outputPath -Parent $repoRoot)
    ) "Distribution readiness output must be retained outside the source repository"
    $outputParent = Split-Path -Parent $outputPath
    if (-not [string]::IsNullOrWhiteSpace($outputParent)) {
        [void][IO.Directory]::CreateDirectory($outputParent)
    }
    $temporaryPath = $outputPath + ".incomplete-" + [Guid]::NewGuid().ToString("N")
    Assert-Exact (-not (Test-Path -LiteralPath $temporaryPath)) (
        "Distribution readiness temporary path already exists: $temporaryPath"
    )
    [IO.File]::WriteAllText(
        $temporaryPath,
        ($report | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    Move-Item -LiteralPath $temporaryPath -Destination $outputPath
}

Write-Output (
    "QUADRUPED_DISTRIBUTION_LICENSING_READINESS " +
    ($report | ConvertTo-Json -Depth 100 -Compress)
)
Write-Host (
    "Quadruped distribution/licensing readiness: status=$($report.status) " +
    "workspace=$($workspacePackages.Count) dependencies=$($externalPackages.Count) " +
    "patches=$($patchPaths.Count) blockers=$($blockingConditions.Count)"
)

if ($RequireReady -and -not $r19Passed) {
    throw (
        "Quadruped distribution/licensing is blocked by: " +
        ($blockingConditions -join ", ")
    )
}
