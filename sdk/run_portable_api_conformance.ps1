#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$PackageRoot = $PSScriptRoot,
    [string]$Library = "",
    [switch]$SkipBuild,
    [switch]$RequireIsolatedPackage,
    [string]$ForbiddenSourceRoot = "",
    [string]$Report = ""
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PackageRoot).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$targetRoot = Join-Path $sdkRoot "target"
$contractPath = Join-Path (
    $sdkRoot
) "portable_api\portable_api_contract_v2.json"
$inventoryPath = Join-Path (
    $sdkRoot
) "release\quadruped_package_source_inventory_v1.json"
$releaseContractPath = Join-Path (
    $sdkRoot
) "release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path (
    $sdkRoot
) "release\quadruped_support_matrix.json"

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (
        "sha256:" +
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    )
}

function Get-BytesSha256 {
    param([byte[]]$Bytes)
    return (
        "sha256:" +
        [Convert]::ToHexString(
            [Security.Cryptography.SHA256]::HashData($Bytes)
        ).ToLowerInvariant()
    )
}

function Test-IsInsidePath {
    param(
        [string]$Candidate,
        [string]$Parent
    )
    $resolvedCandidate = [System.IO.Path]::GetFullPath($Candidate)
    $resolvedParent = [System.IO.Path]::GetFullPath($Parent).TrimEnd(
        [System.IO.Path]::DirectorySeparatorChar,
        [System.IO.Path]::AltDirectorySeparatorChar
    )
    $prefix = $resolvedParent + [System.IO.Path]::DirectorySeparatorChar
    return $resolvedCandidate.StartsWith(
        $prefix,
        [StringComparison]::OrdinalIgnoreCase
    )
}

function Read-JsonObject {
    param([string]$Path)
    try {
        $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    } catch {
        throw "Invalid JSON at ${Path}: $($_.Exception.Message)"
    }
    Assert-Exact (
        $null -ne $value -and $value -is [pscustomobject]
    ) "Expected a JSON object at $Path"
    return $value
}

function Read-PrefixedJsonOutput {
    param(
        [object[]]$Lines,
        [string]$Prefix,
        [string]$Label
    )
    $matches = @(
        $Lines |
            ForEach-Object { [string]$_ } |
            Where-Object {
                $_.StartsWith($Prefix, [StringComparison]::Ordinal)
            }
    )
    Assert-Exact (
        $matches.Count -eq 1
    ) "$Label did not emit exactly one prefixed JSON object"
    try {
        return $matches[0].Substring($Prefix.Length) | ConvertFrom-Json
    } catch {
        throw "$Label emitted invalid JSON: $($_.Exception.Message)"
    }
}

function Get-UnittestCount {
    param(
        [object[]]$Lines,
        [string]$Label
    )
    $counts = @(
        $Lines |
            ForEach-Object {
                if ([string]$_ -match '^Ran ([0-9]+) tests? in ') {
                    [int]$Matches[1]
                }
            }
    )
    Assert-Exact (
        $counts.Count -eq 1 -and $counts[0] -gt 0
    ) "$Label did not report exactly one positive unittest count"
    return $counts[0]
}

function Get-RustTestCount {
    param([object[]]$Lines)
    $counts = @(
        $Lines |
            ForEach-Object {
                if (
                    [string]$_ -match
                    'test result: ok\. ([0-9]+) passed; 0 failed;'
                ) {
                    [int]$Matches[1]
                }
            }
    )
    Assert-Exact (
        $counts.Count -eq 1 -and $counts[0] -gt 0
    ) "Portable-core Rust suite did not report one positive passing count"
    return $counts[0]
}

Assert-Exact (
    Test-Path -LiteralPath $sdkRoot -PathType Container
) "SDK package root not found: $sdkRoot"
Assert-Exact (
    Test-Path -LiteralPath $contractPath -PathType Leaf
) "Portable API contract not found: $contractPath"
Assert-Exact (
    Test-Path -LiteralPath $inventoryPath -PathType Leaf
) "Package source inventory not found: $inventoryPath"

$contract = Read-JsonObject -Path $contractPath
$inventory = Read-JsonObject -Path $inventoryPath
Assert-Exact (
    [string]$contract.schema_version -ceq
        "sporespore_portable_api_contract_v2" -and
    [string]$contract.release_gate_id -ceq "QSDK-R01" -and
    [bool]$contract.requires_clean_room_candidate -and
    [bool]$contract.clean_room_acceptance.candidate_authorization_report_required -and
    [bool]$contract.clean_room_acceptance.candidate_authorization_report_hash_must_match_package_manifest -and
    [bool]$contract.clean_room_acceptance.candidate_authorization_source_commit_must_match_package_manifest -and
    [bool]$contract.clean_room_acceptance.candidate_authorization_report_must_be_outside_package_and_source -and
    [bool]$contract.clean_room_acceptance.build_artifacts_must_be_created_inside_package -and
    [bool]$contract.clean_room_acceptance.library_override_forbidden -and
    [bool]$contract.clean_room_acceptance.retained_source_report_library_override_forbidden -and
    [bool]$contract.clean_room_acceptance.report_must_be_retained_outside_package_and_source -and
    -not [bool]$contract.claim_boundary.r01_passed -and
    -not [bool]$contract.claim_boundary.sdk1_m01_passed -and
    -not [bool]$contract.claim_boundary.release_authorized -and
    -not [bool]$contract.claim_boundary.publication_authorized -and
    -not [bool]$contract.claim_boundary.physical_acceptance_authority
) "Portable API source contract is invalid"
Assert-Exact (
    [string]$inventory.schema_version -ceq
        "sporespore_quadruped_package_source_inventory_v1" -and
    [string]$inventory.source_root -ceq "sdk" -and
    -not [bool]$inventory.claim_boundary.inventory_is_a_package_authorization -and
    -not [bool]$inventory.claim_boundary.inventory_is_a_publication_authorization -and
    -not [bool]$inventory.claim_boundary.physical_acceptance_authority
) "Package source inventory claim boundary is invalid"

$requiredPortablePaths = @(
    $inventory.required_portable_api_paths | ForEach-Object { [string]$_ }
)
Assert-Exact (
    $requiredPortablePaths.Count -gt 0 -and
    @($requiredPortablePaths | Select-Object -Unique).Count -eq
        $requiredPortablePaths.Count
) "Required portable API package paths are empty or duplicated"
foreach ($relativePath in $requiredPortablePaths) {
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($relativePath) -and
        $relativePath -notmatch '\\' -and
        $relativePath -notmatch '(^|/)\.\.(/|$)' -and
        -not [System.IO.Path]::IsPathRooted($relativePath)
    ) "Unsafe required portable API path: $relativePath"
    Assert-Exact (
        Test-Path -LiteralPath (Join-Path $sdkRoot $relativePath) -PathType Leaf
    ) "Required portable API package file is missing: $relativePath"
}

$packageManifest = $null
$packageManifestSha256 = $null
$candidateAuthorizationReceipt = $null
$sourceIdentity = $null
$sourceRepoRoot = $null
$packageEntries = @()
$packageAuthority = ""
if ($RequireIsolatedPackage) {
    Assert-Exact (
        -not $SkipBuild
    ) "Retained isolated-package R01 validation may not skip its package build"
    Assert-Exact (
        [string]::IsNullOrWhiteSpace($Library)
    ) "Isolated-package R01 validation forbids a library override"
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($ForbiddenSourceRoot)
    ) "Isolated-package validation requires -ForbiddenSourceRoot"
    $forbiddenRoot = [System.IO.Path]::GetFullPath($ForbiddenSourceRoot)
    Assert-Exact (
        -not (
            $sdkRoot -ceq $forbiddenRoot -or
            (Test-IsInsidePath -Candidate $sdkRoot -Parent $forbiddenRoot)
        )
    ) "Clean-room package is inside the forbidden game source tree"
    foreach ($forbiddenEntry in @($inventory.forbidden_package_entries)) {
        Assert-Exact (
            -not (Test-Path -LiteralPath (Join-Path $sdkRoot ([string]$forbiddenEntry)))
        ) "Clean-room package contains forbidden entry '$forbiddenEntry'"
    }

    $packageManifestPath = Join-Path $sdkRoot "PACKAGE_MANIFEST.json"
    $warningPath = Join-Path $sdkRoot "NOT_FOR_DISTRIBUTION.json"
    Assert-Exact (
        Test-Path -LiteralPath $packageManifestPath -PathType Leaf
    ) "Clean-room package manifest is missing"
    Assert-Exact (
        Test-Path -LiteralPath $warningPath -PathType Leaf
    ) "Clean-room non-distribution marker is missing"
    $packageManifest = Read-JsonObject -Path $packageManifestPath
    $warning = Read-JsonObject -Path $warningPath
    $candidateArtifactRole = [string]$packageManifest.artifact_role
    $sdk1Candidate = $candidateArtifactRole -ceq
        "sdk1_clean_room_conformance_candidate"
    $fullProgramCandidate = $candidateArtifactRole -ceq
        "clean_room_conformance_candidate"
    $expectedCandidateAuthorityScope = if ($sdk1Candidate) {
        "bounded_sdk1_17_plus_3"
    } else {
        "full_program_22_plus_3"
    }
    Assert-Exact (
        [string]$packageManifest.schema_version -ceq
            "sporespore_quadruped_sdk_package_manifest_v1" -and
        [string]$packageManifest.source_commit -match '^[0-9a-f]{40}$' -and
        ($sdk1Candidate -xor $fullProgramCandidate) -and
        [string]$packageManifest.candidate_authority_scope -ceq
            $expectedCandidateAuthorityScope -and
        -not [bool]$packageManifest.release_authorized -and
        -not [bool]$packageManifest.publication_authorized -and
        [string]$warning.schema_version -ceq
            "sporespore_quadruped_sdk_nonrelease_candidate_warning_v1" -and
        [string]$warning.artifact_role -ceq $candidateArtifactRole -and
        [string]$warning.candidate_authority_scope -ceq
            $expectedCandidateAuthorityScope -and
        -not [bool]$warning.release_authorized -and
        -not [bool]$warning.publication_authorized -and
        [string]$warning.source_commit -ceq
            [string]$packageManifest.source_commit -and
        (@($warning.prohibited_uses) -join "|") -ceq
            "publication|distribution|physical_acceptance_claim|completed_sdk_claim"
    ) "Clean-room candidate claim boundary is invalid"
    $authorizationPath = [System.IO.Path]::GetFullPath(
        [string]$packageManifest.readiness_report.source_path
    )
    Assert-Exact (
        -not (
            $authorizationPath -ceq $sdkRoot -or
            (Test-IsInsidePath -Candidate $authorizationPath -Parent $sdkRoot) -or
            $authorizationPath -ceq $forbiddenRoot -or
            (Test-IsInsidePath -Candidate $authorizationPath -Parent $forbiddenRoot)
        )
    ) "Candidate authorization report must be outside the package and source tree"
    Assert-Exact (
        Test-Path -LiteralPath $authorizationPath -PathType Leaf
    ) "Candidate authorization report is missing: $authorizationPath"
    $authorizationSha256 = Get-Sha256 -Path $authorizationPath
    Assert-Exact (
        $authorizationSha256 -ceq
            [string]$packageManifest.readiness_report.sha256
    ) "Candidate authorization report hash differs from the package manifest"
    $authorization = Read-JsonObject -Path $authorizationPath
    Assert-Exact (
        (Test-Path -LiteralPath $releaseContractPath -PathType Leaf) -and
        (Test-Path -LiteralPath $supportMatrixPath -PathType Leaf) -and
        (Get-Sha256 -Path $releaseContractPath) -ceq
            [string]$packageManifest.readiness_report.contract_sha256 -and
        (Get-Sha256 -Path $supportMatrixPath) -ceq
            [string]$packageManifest.readiness_report.support_matrix_sha256
    ) "Packaged release authorities differ from the candidate authorization"
    if ($sdk1Candidate) {
        $sdk1AuthorityValidatorPath = Join-Path (
            $sdkRoot
        ) "release\assert_quadruped_sdk1_candidate_authority.ps1"
        Assert-Exact (
            Test-Path -LiteralPath $sdk1AuthorityValidatorPath -PathType Leaf
        ) "SDK1 candidate-authority validator is missing from the package"
        Assert-Exact (
            [string]$packageManifest.readiness_report.schema_version -ceq
                "sporespore_quadruped_sdk1_milestone_readiness_report_v1" -and
            [string]$packageManifest.readiness_report.mapping_id -ceq
                [string]$authorization.mapping_id -and
            [string]$packageManifest.readiness_report.mapping_sha256 -ceq
                [string]$authorization.mapping.sha256
        ) "SDK1 package manifest does not bind its bounded authorization"
        . $sdk1AuthorityValidatorPath
        $validatedAuthorization = Assert-QuadrupedSdk1CandidateAuthority `
            -Report $authorization `
            -ExpectedReleaseId ([string]$packageManifest.release_id) `
            -ExpectedSourceCommit ([string]$packageManifest.source_commit) `
            -ExpectedMappingId ([string]$packageManifest.readiness_report.mapping_id) `
            -ExpectedMappingSha256 ([string]$packageManifest.readiness_report.mapping_sha256) `
            -ExpectedContractSha256 ([string]$packageManifest.readiness_report.contract_sha256) `
            -ExpectedSupportMatrixSha256 ([string]$packageManifest.readiness_report.support_matrix_sha256)
        $candidateAuthorizationReceipt = [ordered]@{
            path = $authorizationPath
            sha256 = $authorizationSha256
            authority_scope = [string]$validatedAuthorization.authority_scope
            schema_version = [string]$validatedAuthorization.schema_version
            mapping_id = [string]$validatedAuthorization.mapping_id
            source_commit = [string]$validatedAuthorization.source_commit
            clean_room_candidate_authorized = $true
            release_authorized = $false
            publication_authorized = $false
        }
    } else {
        Assert-Exact (
            [string]$packageManifest.readiness_report.schema_version -ceq
                "sporespore_quadruped_sdk_release_readiness_report_v1" -and
            [string]$authorization.schema_version -ceq
                "sporespore_quadruped_sdk_release_readiness_report_v1" -and
            [bool]$authorization.clean_room_candidate_authorized -and
            -not [bool]$authorization.release_ready -and
            -not [bool]$authorization.package_authorized -and
            -not [bool]$authorization.publication_authorized -and
            -not [bool]$authorization.clean_room_candidate_publication_authorized -and
            @($authorization.clean_room_candidate_blocking_gate_ids).Count -eq 0 -and
            (@($authorization.clean_room_candidate_validation_gate_ids) -join "|") -ceq
                "QSDK-R01|QSDK-R16|QSDK-R20" -and
            @($authorization.clean_room_candidate_blocking_conditions).Count -eq 0 -and
            [string]$authorization.release_id -ceq
                [string]$packageManifest.release_id -and
            [string]$authorization.source.commit -ceq
                [string]$packageManifest.source_commit -and
            [string]$authorization.source.origin_main -ceq
                [string]$packageManifest.source_commit -and
            [bool]$authorization.source.clean -and
            [bool]$authorization.source.matches_origin_main -and
            @($authorization.source.status_entries).Count -eq 0 -and
            [string]$authorization.contract.sha256 -ceq
                [string]$packageManifest.readiness_report.contract_sha256 -and
            [string]$authorization.support_matrix.sha256 -ceq
                [string]$packageManifest.readiness_report.support_matrix_sha256 -and
            (Get-Sha256 -Path $releaseContractPath) -ceq
                [string]$packageManifest.readiness_report.contract_sha256
        ) "Candidate authorization report does not authorize this exact source"
        $candidateAuthorizationReceipt = [ordered]@{
            path = $authorizationPath
            sha256 = $authorizationSha256
            authority_scope = "full_program_22_plus_3"
            schema_version = [string]$authorization.schema_version
            source_commit = [string]$authorization.source.commit
            clean_room_candidate_authorized = $true
            release_authorized = $false
            publication_authorized = $false
        }
    }
    $manifestFiles = @($packageManifest.files)
    Assert-Exact (
        [int]$packageManifest.file_count -eq $manifestFiles.Count -and
        @($manifestFiles.path | Select-Object -Unique).Count -eq
            $manifestFiles.Count
    ) "Clean-room package manifest file set is invalid"
    foreach ($entry in $manifestFiles) {
        $relativePath = ([string]$entry.path).Replace("\", "/")
        $entryPath = [System.IO.Path]::GetFullPath(
            (Join-Path $sdkRoot $relativePath)
        )
        Assert-Exact (
            Test-IsInsidePath -Candidate $entryPath -Parent $sdkRoot
        ) "Package manifest entry escaped the package root: $relativePath"
        Assert-Exact (
            Test-Path -LiteralPath $entryPath -PathType Leaf
        ) "Package manifest entry is missing: $relativePath"
        $actualSha256 = Get-Sha256 -Path $entryPath
        Assert-Exact (
            $actualSha256 -ceq [string]$entry.sha256
        ) "Package manifest entry hash mismatch: $relativePath"
        $packageEntries += [ordered]@{
            path = $relativePath
            sha256 = $actualSha256
            byte_length = (Get-Item -LiteralPath $entryPath).Length
        }
    }
    $packagePaths = @($packageEntries | ForEach-Object { [string]$_.path })
    foreach ($requiredPath in $requiredPortablePaths) {
        Assert-Exact (
            $requiredPath -cin $packagePaths
        ) "Required portable API path is absent from package manifest: $requiredPath"
    }
    $packageItems = @(Get-ChildItem -LiteralPath $sdkRoot -Recurse -Force)
    Assert-Exact (
        @(
            $packageItems |
                Where-Object {
                    ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
                }
        ).Count -eq 0
    ) "Clean-room package contains a symbolic link or reparse point"
    $actualPackageFiles = @(
        $packageItems |
            Where-Object { -not $_.PSIsContainer } |
            ForEach-Object {
                $_.FullName.Substring($sdkRoot.Length).TrimStart(
                    [System.IO.Path]::DirectorySeparatorChar,
                    [System.IO.Path]::AltDirectorySeparatorChar
                ).Replace("\", "/")
            } |
            Sort-Object
    )
    $expectedPackageFiles = @(
        @($manifestFiles | ForEach-Object { [string]$_.path }) +
            @("NOT_FOR_DISTRIBUTION.json", "PACKAGE_MANIFEST.json") |
            Sort-Object
    )
    Assert-Exact (
        ($actualPackageFiles -join "|") -ceq ($expectedPackageFiles -join "|")
    ) "Clean-room package contains an unlisted or missing file"
    $packageManifestSha256 = Get-Sha256 -Path $packageManifestPath
    $sourceIdentity = [ordered]@{
        authority = "package_manifest"
        commit = [string]$packageManifest.source_commit
        package_manifest_sha256 = $packageManifestSha256
        candidate_authorization_report_sha256 = $authorizationSha256
        package_file_hashes_verified = $true
        source_repository_clean = $null
        source_matches_origin_main = $null
    }
    $packageAuthority = "package_manifest"
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($Report)
    ) "Isolated-package R01 validation requires a durable -Report path"
    $isolatedReportPath = [System.IO.Path]::GetFullPath($Report)
    Assert-Exact (
        -not (
            $isolatedReportPath -ceq $sdkRoot -or
            (Test-IsInsidePath -Candidate $isolatedReportPath -Parent $sdkRoot) -or
            $isolatedReportPath -ceq $forbiddenRoot -or
            (Test-IsInsidePath -Candidate $isolatedReportPath -Parent $forbiddenRoot)
        )
    ) "R01 report must be retained outside the clean-room package and source tree"
} else {
    $sourceRepoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
    $sourceTopLevel = (& git -C $sourceRepoRoot rev-parse --show-toplevel).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        [System.IO.Path]::GetFullPath($sourceTopLevel) -ceq $sourceRepoRoot
    ) "SDK root is not inside the expected source-repository root"
    $sourceRemoteUrl = (& git -C $sourceRepoRoot remote get-url origin).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        $sourceRemoteUrl -ceq "https://github.com/Slagathore/sporespore.git"
    ) "Source origin is not the authoritative SporeSpore remote"
    $sourceStatus = @(
        & git -C $sourceRepoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "Could not inspect source status"
    $sourceCommit = (& git -C $sourceRepoRoot rev-parse HEAD).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($sourceCommit)
    ) "Could not resolve source commit"
    $originMain = (& git -C $sourceRepoRoot rev-parse origin/main).Trim()
    Assert-Exact (
        $LASTEXITCODE -eq 0 -and
        -not [string]::IsNullOrWhiteSpace($originMain)
    ) "Could not resolve origin/main"
    $sourceIdentity = [ordered]@{
        authority = "git"
        root = $sourceRepoRoot
        remote_url = $sourceRemoteUrl
        commit = $sourceCommit
        origin_main = $originMain
        live_origin_main = $null
        clean = $sourceStatus.Count -eq 0
        matches_origin_main = $sourceCommit -ceq $originMain
        matches_live_origin_main = $null
        status_entries = $sourceStatus
    }
    if (-not [string]::IsNullOrWhiteSpace($Report)) {
        Assert-Exact (
            -not $SkipBuild
        ) "Retained source R01 conformance may not skip its release build"
        Assert-Exact (
            [string]::IsNullOrWhiteSpace($Library)
        ) "Retained source R01 conformance forbids a library override"
        Assert-Exact (
            [bool]$sourceIdentity.clean -and
            [bool]$sourceIdentity.matches_origin_main
        ) "Retained source conformance requires clean HEAD equal to origin/main"
        $sourceReportPath = [System.IO.Path]::GetFullPath($Report)
        Assert-Exact (
            -not (
                $sourceReportPath -ceq $sourceRepoRoot -or
                (Test-IsInsidePath `
                    -Candidate $sourceReportPath `
                    -Parent $sourceRepoRoot)
            )
        ) "Retained R01 source report must be outside the source repository"
        $liveLines = @(
            & git -C $sourceRepoRoot ls-remote `
                --exit-code `
                origin `
                refs/heads/main
        )
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Could not resolve live origin main"
        $liveHeads = @(
            $liveLines |
                ForEach-Object {
                    if (
                        [string]$_ -match
                        '^([0-9a-f]{40})\s+refs/heads/main$'
                    ) {
                        $Matches[1]
                    }
                }
        )
        Assert-Exact (
            $liveHeads.Count -eq 1 -and
            [string]$liveHeads[0] -ceq $sourceCommit
        ) "Retained source conformance requires HEAD equal to live origin main"
        $sourceIdentity.live_origin_main = [string]$liveHeads[0]
        $sourceIdentity.matches_live_origin_main = $true
    }

    $pathspecs = @($inventory.git_pathspecs | ForEach-Object { [string]$_ })
    . (Join-Path $sdkRoot 'release/assert_package_pathspecs.ps1')
    Assert-QuadrupedPackagePathspecs -Pathspecs $pathspecs
    $trackedFiles = @(
        & git -C $sourceRepoRoot ls-files `
            --cached `
            --others `
            --exclude-standard `
            -- `
            @pathspecs
    )
    Assert-Exact ($LASTEXITCODE -eq 0) "Could not enumerate package source files"
    Assert-Exact ($trackedFiles.Count -gt 0) "No tracked package source files found"
    foreach ($repoRelativePath in ($trackedFiles | Sort-Object -Unique)) {
        Assert-Exact (
            $repoRelativePath.StartsWith("sdk/", [StringComparison]::Ordinal)
        ) "Package source escaped SDK root: $repoRelativePath"
        $sourcePath = [System.IO.Path]::GetFullPath(
            (Join-Path $sourceRepoRoot $repoRelativePath)
        )
        Assert-Exact (
            Test-IsInsidePath -Candidate $sourcePath -Parent $sdkRoot
        ) "Package source escaped SDK root: $repoRelativePath"
        Assert-Exact (
            Test-Path -LiteralPath $sourcePath -PathType Leaf
        ) "Tracked package source is missing: $repoRelativePath"
        $packageEntries += [ordered]@{
            path = $repoRelativePath.Substring("sdk/".Length).Replace("\", "/")
            sha256 = Get-Sha256 -Path $sourcePath
            byte_length = (Get-Item -LiteralPath $sourcePath).Length
        }
    }
    $packagePaths = @($packageEntries | ForEach-Object { [string]$_.path })
    foreach ($requiredPath in $requiredPortablePaths) {
        Assert-Exact (
            $requiredPath -cin $packagePaths
        ) "Required portable API path is absent from tracked package source: $requiredPath"
    }
    $packageAuthority = if ([bool]$sourceIdentity.clean) {
        "git_tracked_inventory"
    } else {
        "working_tree_package_projection"
    }
}

if (-not [string]::IsNullOrWhiteSpace($Report)) {
    $earlyReportPath = [System.IO.Path]::GetFullPath($Report)
    $earlyReportParent = Split-Path -Parent $earlyReportPath
    Assert-Exact (
        Test-Path -LiteralPath $earlyReportParent -PathType Container
    ) "Portable API report parent does not exist: $earlyReportParent"
    Assert-Exact (
        -not (Test-Path -LiteralPath $earlyReportPath)
    ) "Refusing to overwrite portable API report: $earlyReportPath"
}

$projectionLines = @(
    $packageEntries |
        Sort-Object -Property path |
        ForEach-Object { "$($_.path)`t$($_.sha256)" }
)
$projectionText = ($projectionLines -join "`n") + "`n"
$projectionSha256 = Get-BytesSha256 -Bytes (
    [Text.UTF8Encoding]::new($false).GetBytes($projectionText)
)
$packageByteLength = [long](
    (
        $packageEntries |
            ForEach-Object { [long]$_.byte_length } |
            Measure-Object -Sum
    ).Sum
)
Assert-Exact (
    $packageEntries.Count -gt 0 -and $packageByteLength -gt 0
) "Package source projection is unexpectedly empty"

if (-not $SkipBuild) {
    Push-Location -LiteralPath $sdkRoot
    try {
        & cargo build `
            -p sporespore-locomotion-core `
            --release `
            --offline `
            --target-dir $targetRoot
        Assert-Exact (
            $LASTEXITCODE -eq 0
        ) "Portable core release build failed"
    } finally {
        Pop-Location
    }
}

$libraryPath = ""
if (-not [string]::IsNullOrWhiteSpace($Library)) {
    $libraryPath = [System.IO.Path]::GetFullPath($Library)
} else {
    $libraryNames = if ($IsWindows) {
        @("sporespore_locomotion_core.dll")
    } elseif ($IsMacOS) {
        @("libsporespore_locomotion_core.dylib")
    } else {
        @("libsporespore_locomotion_core.so")
    }
    foreach ($profile in @("release", "debug")) {
        foreach ($name in $libraryNames) {
            $candidate = Join-Path $targetRoot "$profile\$name"
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                $libraryPath = [System.IO.Path]::GetFullPath($candidate)
                break
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($libraryPath)) {
            break
        }
    }
}
Assert-Exact (
    -not [string]::IsNullOrWhiteSpace($libraryPath) -and
    (Test-Path -LiteralPath $libraryPath -PathType Leaf)
) "Portable core dynamic library was not found"

$previousRustMinStack = $env:RUST_MIN_STACK
# Large debug-only policy values exceed the default Windows test-thread stack.
# Keep every assertion, fix the resource bound, and limit concurrent test stacks.
$rustTestStackBytes = 8 * 1024 * 1024
$rustTestThreads = 4
Push-Location -LiteralPath $sdkRoot
try {
    $env:RUST_MIN_STACK = [string]$rustTestStackBytes
    $rustTestLines = @(
        & cargo test `
            -p sporespore-locomotion-core `
            --lib `
            --offline `
            --target-dir $targetRoot -- --test-threads=$rustTestThreads 2>&1
    )
    $rustTestExit = $LASTEXITCODE
} finally {
    $env:RUST_MIN_STACK = $previousRustMinStack
    Pop-Location
}
if ($rustTestExit -ne 0) {
    $rustTestLines | ForEach-Object { Write-Host ([string]$_) }
}
Assert-Exact (
    $rustTestExit -eq 0
) "Portable-core Rust unit conformance failed"
$rustTestCount = Get-RustTestCount -Lines $rustTestLines

$previousPythonPath = $env:PYTHONPATH
$previousLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = $sdkRoot
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $libraryPath

    Push-Location -LiteralPath $sdkRoot
    try {
        $negativeControlLines = @(
            & python -m unittest -v portable_api.test_conformance 2>&1
        )
        $negativeControlExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($negativeControlExit -ne 0) {
        $negativeControlLines | ForEach-Object { Write-Host ([string]$_) }
    }
    Assert-Exact (
        $negativeControlExit -eq 0
    ) "Portable API surface mutation controls failed"
    $negativeControlTestCount = Get-UnittestCount `
        -Lines $negativeControlLines `
        -Label "portable API mutation suite"
    Assert-Exact (
        $negativeControlTestCount -eq
            [int]$contract.surface_test_contract.total_surface_unit_test_count -and
        [int]$contract.surface_test_contract.current_source_positive_control_count -eq 1 -and
        [int]$contract.surface_test_contract.deliberate_mutation_negative_control_count -eq 10
    ) "Portable API surface test counts differ from the frozen contract"

    $surfaceLines = @(
        & python `
            -m portable_api.conformance `
            --sdk-root $sdkRoot `
            --library $libraryPath 2>&1
    )
    $surfaceExit = $LASTEXITCODE
    if ($surfaceExit -ne 0) {
        $surfaceLines | ForEach-Object { Write-Host ([string]$_) }
    }
    Assert-Exact (
        $surfaceExit -eq 0
    ) "Portable API exact surface audit failed"
    $surface = Read-PrefixedJsonOutput `
        -Lines $surfaceLines `
        -Prefix "PORTABLE_API_SURFACE_CONFORMANCE " `
        -Label "portable API exact surface audit"
    Assert-Exact (
        [bool]$surface.ok -and
        [string]$surface.release_gate_id -ceq "QSDK-R01" -and
        [int]$surface.contract_symbol_count -eq 83 -and
        [int]$surface.rust_export_count -eq 83 -and
        [int]$surface.c_declaration_count -eq 83 -and
        [int]$surface.python_ctypes_signature_count -eq 83 -and
        [bool]$surface.rust_c_python_exact_signature_parity -and
        [bool]$surface.all_dynamic_library_exports_resolved -and
        [int]$surface.library.resolved_export_count -eq 83 -and
        [int]$surface.library.invoked_export_count -eq 83 -and
        [int]$surface.library.buffer_protocol_symbol_count -eq 80 -and
        [int]$surface.library.typed_malformed_json_refusal_count -eq 77 -and
        [int]$surface.library.output_only_success_count -eq 4 -and
        [int]$surface.physics_model_construction_count -eq 0 -and
        [int]$surface.world_build_count -eq 0 -and
        [int]$surface.solver_step_count -eq 0 -and
        -not [bool]$surface.physical_acceptance_authority -and
        -not [bool]$surface.release_authorized -and
        -not [bool]$surface.publication_authorized
    ) "Portable API exact surface receipt violated its terminal contract"

    $pythonRoot = Join-Path $sdkRoot "python"
    Push-Location -LiteralPath $pythonRoot
    try {
        $pythonSmokeLines = @(
            & python -m unittest -v test_ctypes_smoke.py 2>&1
        )
        $pythonSmokeExit = $LASTEXITCODE
    } finally {
        Pop-Location
    }
    if ($pythonSmokeExit -ne 0) {
        $pythonSmokeLines | ForEach-Object { Write-Host ([string]$_) }
    }
    Assert-Exact (
        $pythonSmokeExit -eq 0
    ) "Python C-ABI end-to-end conformance failed"
    $pythonSmokeTestCount = Get-UnittestCount `
        -Lines $pythonSmokeLines `
        -Label "Python C-ABI smoke suite"
    $extensionLines = @(& python -m unittest -v portable_api.test_sdk1_extension 2>&1)
    $extensionExit = $LASTEXITCODE
    if ($extensionExit -ne 0) { $extensionLines | ForEach-Object { Write-Host ([string]$_) } }
    Assert-Exact ($extensionExit -eq 0) "SDK1 additive binding conformance failed"
    $extensionTestCount = Get-UnittestCount -Lines $extensionLines -Label "SDK1 additive binding suite"
    Assert-Exact ($extensionTestCount -eq [int]$contract.extension_unit_test_count) "SDK1 extension test count"
} finally {
    $env:PYTHONPATH = $previousPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $previousLibrary
}

if ($RequireIsolatedPackage) {
    foreach ($entry in @($packageManifest.files)) {
        $entryPath = [System.IO.Path]::GetFullPath(
            (Join-Path $sdkRoot ([string]$entry.path))
        )
        Assert-Exact (
            (Get-Sha256 -Path $entryPath) -ceq [string]$entry.sha256
        ) "Packaged source changed during conformance: $($entry.path)"
    }
}

$receipt = [ordered]@{
    schema_version = "sporespore_portable_api_conformance_report_v1"
    status = if ($RequireIsolatedPackage) {
        "clean_room_candidate_passed"
    } else {
        "source_conformance_passed_clean_room_candidate_pending"
    }
    release_gate_id = "QSDK-R01"
    sdk1_milestone_id = "SDK1-M01"
    ledger_scope = [ordered]@{
        subsystem = "release"
        engine_scope = "engine_neutral"
        authority_mode = "zero_world_source_and_package_conformance"
        question_class = "development"
    }
    package_root = $sdkRoot
    validation_scope = if ($RequireIsolatedPackage) {
        "clean_room_candidate"
    } else {
        "source_tree"
    }
    source_conformance_passed = $true
    clean_room_candidate_validated = [bool]$RequireIsolatedPackage
    r01_passed = [bool]$RequireIsolatedPackage
    sdk1_m01_passed = [bool]$RequireIsolatedPackage
    source = $sourceIdentity
    contract = [ordered]@{
        path = $contractPath
        sha256 = Get-Sha256 -Path $contractPath
        schema_version = [string]$contract.schema_version
    }
    package_source_inventory = [ordered]@{
        path = $inventoryPath
        sha256 = Get-Sha256 -Path $inventoryPath
        schema_version = [string]$inventory.schema_version
    }
    candidate_authorization = $candidateAuthorizationReceipt
    package_projection = [ordered]@{
        authority = $packageAuthority
        file_count = $packageEntries.Count
        total_byte_length = $packageByteLength
        canonical_path_sha256_digest = $projectionSha256
        required_portable_api_path_count = $requiredPortablePaths.Count
        all_required_portable_api_paths_present = $true
        all_file_hashes_verified = $true
        package_manifest_sha256 = $packageManifestSha256
        isolated_from_source_repository = [bool]$RequireIsolatedPackage
        package_inventory_and_isolation_passed = [bool]$RequireIsolatedPackage
    }
    sdk_version = [string]$surface.sdk_version
    abi_generation = [int]$surface.abi_generation
    library = [ordered]@{
        path = $libraryPath
        sha256 = Get-Sha256 -Path $libraryPath
        resolved_export_count = [int]$surface.library.resolved_export_count
        invoked_export_count = [int]$surface.library.invoked_export_count
        buffer_protocol_symbol_count =
            [int]$surface.library.buffer_protocol_symbol_count
    }
    conformance = [ordered]@{
        cell_count = @($contract.source_conformance_cells).Count
        passed_cell_count = @($contract.source_conformance_cells).Count
        failed_cell_count = 0
        rust_unit_test_count = $rustTestCount
        rust_test_profile = "debug"
        rust_test_min_stack_bytes = $rustTestStackBytes
        rust_test_threads = $rustTestThreads
        rust_unit_test_failure_count = 0
        python_ctypes_test_count = $pythonSmokeTestCount
        python_ctypes_test_failure_count = 0
        sdk1_extension_test_count = $extensionTestCount
        sdk1_extension_test_failure_count = 0
        surface_negative_control_count =
            [int]$contract.surface_test_contract.deliberate_mutation_negative_control_count
        surface_negative_control_rejection_count =
            [int]$contract.surface_test_contract.deliberate_mutation_negative_control_count
        current_source_positive_control_count =
            [int]$contract.surface_test_contract.current_source_positive_control_count
        contract_symbol_count = [int]$surface.contract_symbol_count
        rust_export_count = [int]$surface.rust_export_count
        c_declaration_count = [int]$surface.c_declaration_count
        python_ctypes_signature_count = [int]$surface.python_ctypes_signature_count
        dynamic_library_resolved_export_count =
            [int]$surface.library.resolved_export_count
        dynamic_library_invoked_export_count =
            [int]$surface.library.invoked_export_count
        dynamic_typed_malformed_json_refusal_count =
            [int]$surface.library.typed_malformed_json_refusal_count
        dynamic_output_only_success_count =
            [int]$surface.library.output_only_success_count
        exact_signature_parity_passed = $true
        real_dynamic_library_load_passed = $true
        caller_owned_buffer_and_typed_refusal_paths_passed = $true
        package_source_projection_passed = $true
        package_inventory_and_isolation_passed = [bool]$RequireIsolatedPackage
    }
    execution = [ordered]@{
        physics_engine_process_count = 0
        physics_model_construction_count = 0
        world_build_count = 0
        native_physics_read_count = 0
        solver_step_count = 0
    }
    claims = [ordered]@{
        release_authorized = $false
        publication_authorized = $false
        walking_acceptance = $false
        physical_acceptance_authority = $false
        completed_engine_neutral_sdk = $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($Report)) {
    $reportPath = [System.IO.Path]::GetFullPath($Report)
    if (-not $RequireIsolatedPackage) {
        $finalStatus = @(
            & git -C $sourceRepoRoot status --porcelain=v1 --untracked-files=all
        )
        Assert-Exact (
            $LASTEXITCODE -eq 0 -and $finalStatus.Count -eq 0
        ) "Source changed or became dirty during retained R01 conformance"
        $finalHead = (& git -C $sourceRepoRoot rev-parse HEAD).Trim()
        $finalOriginMain = (& git -C $sourceRepoRoot rev-parse origin/main).Trim()
        Assert-Exact (
            $LASTEXITCODE -eq 0 -and
            $finalHead -ceq [string]$sourceIdentity.commit -and
            $finalOriginMain -ceq [string]$sourceIdentity.origin_main
        ) "Source identity changed during retained R01 conformance"
    }
    $reportParent = Split-Path -Parent $reportPath
    Assert-Exact (
        Test-Path -LiteralPath $reportParent -PathType Container
    ) "Portable API report parent does not exist: $reportParent"
    Assert-Exact (
        -not (Test-Path -LiteralPath $reportPath)
    ) "Refusing to overwrite portable API report: $reportPath"
    [System.IO.File]::WriteAllText(
        $reportPath,
        ($receipt | ConvertTo-Json -Depth 50) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Host (
    "PORTABLE_API_CONFORMANCE " +
    ($receipt | ConvertTo-Json -Depth 50 -Compress)
)
Write-Host (
    "Portable API conformance passed: 83 exact Rust/C/Python symbols, " +
    "$rustTestCount Rust tests, $pythonSmokeTestCount Python C-ABI tests, " +
    "$($negativeControlTestCount - 1) mutation refusals, zero worlds."
)
