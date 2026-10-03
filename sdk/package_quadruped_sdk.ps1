[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ReadinessReport,

    [Parameter(Mandatory = $true)]
    [string]$OutputDirectory,

    [switch]$CleanRoomCandidate,

    [switch]$Sdk1CleanRoomCandidate,

    [string]$Python = 'C:/Program Files/Python311/python.exe'
)

$ErrorActionPreference = "Stop"
$sdkRoot = [System.IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$compilerPath = Join-Path $sdkRoot "compile_quadruped_sdk_release_readiness.ps1"
$sdk1CompilerPath = Join-Path $sdkRoot "compile_quadruped_sdk1_milestone_readiness.ps1"
$sdk1AuthorityValidatorPath = Join-Path (
    $sdkRoot
) "release\assert_quadruped_sdk1_candidate_authority.ps1"
$contractPath = Join-Path $sdkRoot "release\quadruped_release_contract.json"
$inventoryPath = Join-Path (
    $sdkRoot
) "release\quadruped_package_source_inventory_v1.json"
$readinessPath = [System.IO.Path]::GetFullPath($ReadinessReport)
$outputPath = [System.IO.Path]::GetFullPath($OutputDirectory).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$outputParent = [System.IO.Path]::GetFullPath((Split-Path -Parent $outputPath))
$stagingPath = (
    $outputPath +
    ".incomplete-" +
    [Guid]::NewGuid().ToString("N")
)

function Assert-Exact {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
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

function Get-Sha256 {
    param([string]$Path)
    return (
        "sha256:" +
        (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
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

function Invoke-LiveReadiness {
    if ($Sdk1CleanRoomCandidate) {
        $lines = @(& $sdk1CompilerPath -RequireCandidate 6>$null)
        $prefix = "QUADRUPED_SDK1_MILESTONE_READINESS "
    } elseif ($CleanRoomCandidate) {
        $lines = @(& $compilerPath -RequireCandidate 6>$null)
        $prefix = "QUADRUPED_SDK_RELEASE_READINESS "
    } else {
        $lines = @(& $compilerPath -RequireReady 6>$null)
        $prefix = "QUADRUPED_SDK_RELEASE_READINESS "
    }
    $reportLines = @(
        $lines |
            Where-Object {
                $_ -is [string] -and $_.StartsWith(
                    $prefix,
                    [StringComparison]::Ordinal
                )
            }
    )
    Assert-Exact (
        $reportLines.Count -eq 1
    ) "Live readiness compiler did not emit exactly one report"
    return (
        $reportLines[0].Substring($prefix.Length) |
            ConvertFrom-Json
    )
}

$candidateModeCount = @(
    $CleanRoomCandidate,
    $Sdk1CleanRoomCandidate
).Where({ [bool]$_ }).Count
Assert-Exact (
    $candidateModeCount -le 1
) "Choose at most one clean-room candidate mode"
$candidateRequested = $candidateModeCount -eq 1
if ($Sdk1CleanRoomCandidate) {
    Assert-Exact (
        Test-Path -LiteralPath $sdk1CompilerPath -PathType Leaf
    ) "SDK1 readiness compiler is missing: $sdk1CompilerPath"
    Assert-Exact (
        Test-Path -LiteralPath $sdk1AuthorityValidatorPath -PathType Leaf
    ) "SDK1 candidate-authority validator is missing: $sdk1AuthorityValidatorPath"
    . $sdk1AuthorityValidatorPath
}

Assert-Exact (
    Test-Path -LiteralPath $readinessPath -PathType Leaf
) "Readiness report not found: $readinessPath"
Assert-Exact (
    Test-Path -LiteralPath $outputParent -PathType Container
) "Package output parent must already exist: $outputParent"
Assert-Exact (
    -not (Test-Path -LiteralPath $outputPath)
) "Refusing to overwrite package output: $outputPath"
Assert-Exact (
    -not (Test-Path -LiteralPath $stagingPath)
) "Package staging path already exists: $stagingPath"
Assert-Exact (
    -not (
        $outputPath -ceq $repoRoot -or
        (
            Test-IsInsidePath `
                -Candidate $outputPath `
                -Parent $repoRoot
        )
    )
) "Package output must be outside the source repository"
if ($candidateRequested) {
    Assert-Exact (
        -not (
            $readinessPath -ceq $repoRoot -or
            (Test-IsInsidePath -Candidate $readinessPath -Parent $repoRoot)
        )
    ) "Candidate readiness report must be outside the source repository"
}

$retainedReport = Read-JsonObject -Path $readinessPath
if ($Sdk1CleanRoomCandidate) {
    Assert-Exact (
        [string]$retainedReport.schema_version -ceq
            "sporespore_quadruped_sdk1_milestone_readiness_report_v1"
    ) "Unsupported SDK1 candidate-readiness report schema"
    [void](Assert-QuadrupedSdk1CandidateAuthority `
        -Report $retainedReport `
        -ExpectedReleaseId ([string]$retainedReport.release_id) `
        -ExpectedSourceCommit ([string]$retainedReport.source.commit) `
        -ExpectedMappingId ([string]$retainedReport.mapping_id) `
        -ExpectedMappingSha256 ([string]$retainedReport.mapping.sha256) `
        -ExpectedContractSha256 ([string]$retainedReport.contract.sha256) `
        -ExpectedSupportMatrixSha256 ([string]$retainedReport.support_matrix.sha256)
    )
} else {
    Assert-Exact (
        [string]$retainedReport.schema_version -ceq
        "sporespore_quadruped_sdk_release_readiness_report_v1"
    ) "Unsupported readiness report schema"
}
if ($CleanRoomCandidate) {
    Assert-Exact (
        [bool]$retainedReport.clean_room_candidate_authorized
    ) "Retained readiness report does not authorize a clean-room candidate"
    Assert-Exact (
        -not [bool]$retainedReport.release_ready -and
        -not [bool]$retainedReport.package_authorized -and
        -not [bool]$retainedReport.publication_authorized -and
        -not [bool](
            $retainedReport.clean_room_candidate_publication_authorized
        )
    ) "A clean-room candidate must not carry release or publication authority"
    Assert-Exact (
        @($retainedReport.clean_room_candidate_blocking_gate_ids).Count -eq 0
    ) "Retained readiness report still has candidate-stage blockers"
} else {
    if (-not $Sdk1CleanRoomCandidate) {
        Assert-Exact (
            [bool]$retainedReport.release_ready -and
            [bool]$retainedReport.package_authorized -and
            [bool]$retainedReport.publication_authorized
        ) "Retained readiness report does not authorize final packaging"
        Assert-Exact (
            @($retainedReport.blocking_gate_ids).Count -eq 0
        ) "Retained readiness report still contains final-release blockers"
    }
}

# The retained receipt is not trusted by itself. Re-run the exact compiler
# against the current clean source and current evidence before creating any
# package directory. This prevents a hand-edited "ready": true report from
# authorizing publication.
$liveReport = Invoke-LiveReadiness
if ($Sdk1CleanRoomCandidate) {
    [void](Assert-QuadrupedSdk1CandidateAuthority `
        -Report $liveReport `
        -ExpectedReleaseId ([string]$retainedReport.release_id) `
        -ExpectedSourceCommit ([string]$retainedReport.source.commit) `
        -ExpectedMappingId ([string]$retainedReport.mapping_id) `
        -ExpectedMappingSha256 ([string]$retainedReport.mapping.sha256) `
        -ExpectedContractSha256 ([string]$retainedReport.contract.sha256) `
        -ExpectedSupportMatrixSha256 ([string]$retainedReport.support_matrix.sha256)
    )
} elseif ($CleanRoomCandidate) {
    Assert-Exact (
        [bool]$liveReport.clean_room_candidate_authorized -and
        -not [bool]$liveReport.release_ready -and
        -not [bool]$liveReport.package_authorized -and
        -not [bool]$liveReport.publication_authorized -and
        -not [bool](
            $liveReport.clean_room_candidate_publication_authorized
        )
    ) "Live readiness compiler did not authorize only the candidate stage"
} else {
    Assert-Exact (
        [bool]$liveReport.release_ready -and
        [bool]$liveReport.package_authorized -and
        [bool]$liveReport.publication_authorized
    ) "Live readiness compiler did not authorize final packaging"
}
Assert-Exact (
    [string]$liveReport.release_id -ceq [string]$retainedReport.release_id
) "Retained and live release IDs differ"
Assert-Exact (
    [string]$liveReport.source.commit -ceq
    [string]$retainedReport.source.commit
) "Retained readiness source commit differs from live source"
Assert-Exact (
    [string]$liveReport.source.origin_main -ceq
    [string]$retainedReport.source.origin_main
) "Retained readiness origin/main differs from live source"
Assert-Exact (
    [bool]$liveReport.source.clean -and
    [bool]$liveReport.source.matches_origin_main
) "Live source is not clean and pushed"
Assert-Exact (
    [string]$liveReport.contract.sha256 -ceq
    [string]$retainedReport.contract.sha256
) "Retained readiness contract differs from the live contract"
Assert-Exact (
    [string]$liveReport.contract.sha256 -ceq
    (Get-Sha256 -Path $contractPath)
) "Live contract hash does not match the source file"
Assert-Exact (
    [string]$liveReport.support_matrix.sha256 -ceq
    [string]$retainedReport.support_matrix.sha256
) "Retained readiness support matrix differs from the live source"
Assert-Exact (
    [bool]$liveReport.support_matrix.consistent_with_gate_dispositions -and
    [bool]$retainedReport.support_matrix.consistent_with_gate_dispositions
) "Support matrix is inconsistent with release-gate dispositions"
if ($Sdk1CleanRoomCandidate) {
    Assert-Exact (
        [string]$liveReport.mapping_id -ceq
            [string]$retainedReport.mapping_id -and
        [string]$liveReport.mapping.sha256 -ceq
            [string]$retainedReport.mapping.sha256
    ) "Retained and live SDK1 mapping identities differ"
}

$sourceInventory = Read-JsonObject -Path $inventoryPath
Assert-Exact (
    [string]$sourceInventory.schema_version -ceq
        "sporespore_quadruped_package_source_inventory_v1" -and
    [string]$sourceInventory.source_root -ceq "sdk" -and
    -not [bool](
        $sourceInventory.claim_boundary.inventory_is_a_package_authorization
    ) -and
    -not [bool](
        $sourceInventory.claim_boundary.inventory_is_a_publication_authorization
    )
) "Package source inventory is invalid"

$retainedDispositions = if ($Sdk1CleanRoomCandidate) {
    @(
        $retainedReport.milestones |
            ForEach-Object {
                "$($_.milestone_id)=$($_.disposition)"
            }
    )
} else {
    @(
        $retainedReport.gates |
            ForEach-Object {
                "$($_.gate_id)=$($_.disposition)"
            }
    )
}
$liveDispositions = if ($Sdk1CleanRoomCandidate) {
    @(
        $liveReport.milestones |
            ForEach-Object {
                "$($_.milestone_id)=$($_.disposition)"
            }
    )
} else {
    @(
        $liveReport.gates |
            ForEach-Object {
                "$($_.gate_id)=$($_.disposition)"
            }
    )
}
Assert-Exact (
    ($retainedDispositions -join "|") -ceq ($liveDispositions -join "|")
) "Retained and live gate dispositions differ"

$pathspecs = @(
    $sourceInventory.git_pathspecs | ForEach-Object { [string]$_ }
)
. (Join-Path $sdkRoot 'release/assert_package_pathspecs.ps1')
Assert-QuadrupedPackagePathspecs -Pathspecs $pathspecs
$resourceLines = @(& $Python -B -X utf8 (Join-Path $sdkRoot 'release/check_package_resources.py'))
Assert-Exact ($LASTEXITCODE -eq 0 -and $resourceLines.Count -eq 1) 'Package compile-time resource check failed'
$resourceCheck = $resourceLines[0] | ConvertFrom-Json
Assert-Exact ($resourceCheck.ok -eq $true -and $resourceCheck.world_build_count -eq 0) 'Package resource inventory incomplete'
$trackedFiles = @(& git -C $repoRoot ls-files -- @pathspecs)
Assert-Exact ($LASTEXITCODE -eq 0) "Could not enumerate package source files"
Assert-Exact ($trackedFiles.Count -gt 0) "No tracked SDK package files found"

$trackedPackagePaths = @(
    $trackedFiles |
        ForEach-Object { $_.Substring("sdk/".Length).Replace("\", "/") }
)
foreach (
    $requiredPath in @(
        $sourceInventory.required_portable_api_paths |
            ForEach-Object { [string]$_ }
    )
) {
    Assert-Exact (
        $requiredPath -cin $trackedPackagePaths
    ) "Required portable API path is absent from package source: $requiredPath"
}

$packageEntries = @()
foreach ($repoRelativePath in ($trackedFiles | Sort-Object -Unique)) {
    $sourcePath = [System.IO.Path]::GetFullPath(
        (Join-Path $repoRoot $repoRelativePath)
    )
    Assert-Exact (
        Test-IsInsidePath -Candidate $sourcePath -Parent $sdkRoot
    ) "Package source escaped SDK root: $repoRelativePath"
    Assert-Exact (
        Test-Path -LiteralPath $sourcePath -PathType Leaf
    ) "Tracked package source is missing: $repoRelativePath"
    $packageRelativePath = $repoRelativePath.Substring("sdk/".Length)
    $packageEntries += [ordered]@{
        path = $packageRelativePath.Replace("\", "/")
        source_path = $sourcePath
        sha256 = Get-Sha256 -Path $sourcePath
    }
}

try {
    [void][System.IO.Directory]::CreateDirectory($stagingPath)
    foreach ($entry in $packageEntries) {
        $destination = Join-Path $stagingPath $entry.path
        $destinationParent = Split-Path -Parent $destination
        [void][System.IO.Directory]::CreateDirectory($destinationParent)
        Copy-Item -LiteralPath $entry.source_path -Destination $destination
        Assert-Exact (
            (Get-Sha256 -Path $destination) -ceq [string]$entry.sha256
        ) "Copied package file failed hash verification: $($entry.path)"
    }

    $manifestArtifactRole = if ($Sdk1CleanRoomCandidate) {
        "sdk1_clean_room_conformance_candidate"
    } elseif ($CleanRoomCandidate) {
        "clean_room_conformance_candidate"
    } else {
        "final_release"
    }
    $candidateAuthorityScope = if ($Sdk1CleanRoomCandidate) {
        "bounded_sdk1_17_plus_3"
    } elseif ($CleanRoomCandidate) {
        "full_program_22_plus_3"
    } else {
        "final_release"
    }
    $manifest = [ordered]@{
        schema_version = "sporespore_quadruped_sdk_package_manifest_v1"
        release_id = [string]$liveReport.release_id
        artifact_role = $manifestArtifactRole
        candidate_authority_scope = $candidateAuthorityScope
        release_authorized = -not $candidateRequested
        publication_authorized = -not $candidateRequested
        source_commit = [string]$liveReport.source.commit
        readiness_report = [ordered]@{
            source_path = $readinessPath
            sha256 = Get-Sha256 -Path $readinessPath
            schema_version = [string]$liveReport.schema_version
            contract_sha256 = [string]$liveReport.contract.sha256
            support_matrix_sha256 = [string]$liveReport.support_matrix.sha256
            mapping_id = if ($Sdk1CleanRoomCandidate) {
                [string]$liveReport.mapping_id
            } else {
                $null
            }
            mapping_sha256 = if ($Sdk1CleanRoomCandidate) {
                [string]$liveReport.mapping.sha256
            } else {
                $null
            }
        }
        file_count = $packageEntries.Count
        files = @(
            $packageEntries |
                ForEach-Object {
                    [ordered]@{
                        path = $_.path
                        sha256 = $_.sha256
                    }
                }
        )
        claim_boundary = $liveReport.claims
    }
    $manifestPath = Join-Path $stagingPath "PACKAGE_MANIFEST.json"
    [System.IO.File]::WriteAllText(
        $manifestPath,
        (
            $manifest |
                ConvertTo-Json -Depth 100
        ) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
    if ($candidateRequested) {
        $warningPath = Join-Path $stagingPath "NOT_FOR_DISTRIBUTION.json"
        $warning = [ordered]@{
            schema_version = (
                "sporespore_quadruped_sdk_nonrelease_candidate_warning_v1"
            )
            artifact_role = $manifestArtifactRole
            candidate_authority_scope = $candidateAuthorityScope
            release_authorized = $false
            publication_authorized = $false
            purpose = (
                "Run package-bound R01, R16, and R20 conformance only."
            )
            source_commit = [string]$liveReport.source.commit
            prohibited_uses = @(
                "publication",
                "distribution",
                "physical_acceptance_claim",
                "completed_sdk_claim"
            )
        }
        [System.IO.File]::WriteAllText(
            $warningPath,
            (
                $warning |
                    ConvertTo-Json -Depth 20
            ) + "`n",
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    Move-Item -LiteralPath $stagingPath -Destination $outputPath
} catch {
    if (Test-Path -LiteralPath $stagingPath) {
        $resolvedStagingPath = [System.IO.Path]::GetFullPath($stagingPath)
        Assert-Exact (
            $resolvedStagingPath.StartsWith(
                $outputPath + ".incomplete-",
                [StringComparison]::Ordinal
            ) -and
            (Split-Path -Parent $resolvedStagingPath) -ceq $outputParent
        ) "Refusing to clean unexpected package staging path: $resolvedStagingPath"
        Remove-Item -LiteralPath $resolvedStagingPath -Recurse -Force
    }
    throw
}

$artifactRole = "final release"
$extraFileDescription = "PACKAGE_MANIFEST.json"
if ($candidateRequested) {
    $artifactRole = if ($Sdk1CleanRoomCandidate) {
        "non-publishable SDK1 clean-room candidate"
    } else {
        "non-publishable full-program clean-room candidate"
    }
    $extraFileDescription = (
        "PACKAGE_MANIFEST.json and NOT_FOR_DISTRIBUTION.json"
    )
}
Write-Host (
    "Quadruped SDK $artifactRole created: $outputPath " +
    "($($packageEntries.Count) source files plus $extraFileDescription)"
)
