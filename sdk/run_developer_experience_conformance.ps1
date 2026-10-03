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
$contractPath = Join-Path $sdkRoot "developer_experience_contract_v1.json"
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
    return (
        $resolvedCandidate.StartsWith(
            $prefix,
            [StringComparison]::OrdinalIgnoreCase
        )
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

function Read-SingleJsonOutput {
    param(
        [object[]]$Lines,
        [string]$Label
    )
    $jsonLines = @(
        $Lines |
            Where-Object {
                $_ -is [string] -and $_.TrimStart().StartsWith(
                    "{",
                    [StringComparison]::Ordinal
                )
            }
    )
    Assert-Exact (
        $jsonLines.Count -eq 1
    ) "$Label did not emit exactly one JSON object"
    try {
        return $jsonLines[0] | ConvertFrom-Json
    } catch {
        throw "$Label emitted invalid JSON: $($_.Exception.Message)"
    }
}

Assert-Exact (
    Test-Path -LiteralPath $sdkRoot -PathType Container
) "SDK package root not found: $sdkRoot"
foreach ($relativePath in @(
    "Cargo.toml",
    "Cargo.lock",
    "README.md",
    "developer_experience_contract_v1.json",
    "developer_experience_validation_manifest.json",
    "docs\QUADRUPED_SDK_INTEGRATION.md",
    "python\sporespore_locomotion.py",
    "examples\quadruped_quickstart.py",
    "examples\reference_quadruped.py",
    "diagnostics\descriptor_diagnostics.py",
    "diagnostics\__main__.py",
    "record_replay\canonical_recording.py",
    "record_replay\__main__.py",
    "developer_experience\test_developer_experience.py"
)) {
    Assert-Exact (
        Test-Path -LiteralPath (Join-Path $sdkRoot $relativePath) -PathType Leaf
    ) "Developer-experience package file is missing: $relativePath"
}

$contract = Read-JsonObject -Path $contractPath
Assert-Exact (
    [string]$contract.schema_version -ceq
    "sporespore_developer_experience_contract_v1" -and
    [string]$contract.release_gate_id -ceq "QSDK-R16" -and
    [bool]$contract.requires_clean_room_candidate -and
    -not [bool]$contract.claims.r16_passed -and
    -not [bool]$contract.claims.release_authorized -and
    -not [bool]$contract.claims.physical_acceptance_authority
) "Developer-experience source contract is invalid"

$packageManifest = $null
$packageManifestSha256 = $null
$sourceIdentity = $null
if ($RequireIsolatedPackage) {
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
    Assert-Exact (
        -not (Test-Path -LiteralPath (Join-Path $sdkRoot ".git"))
    ) "Clean-room package contains source-repository metadata"
    foreach ($forbiddenEntry in @("project.godot", "scripts", "tests")) {
        Assert-Exact (
            -not (Test-Path -LiteralPath (Join-Path $sdkRoot $forbiddenEntry))
        ) "Clean-room package contains game-tree entry '$forbiddenEntry'"
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
        -not [bool]$warning.publication_authorized
    ) "Clean-room candidate claim boundary is invalid"
    if ($sdk1Candidate) {
        $authorizationPath = [System.IO.Path]::GetFullPath(
            [string]$packageManifest.readiness_report.source_path
        )
        Assert-Exact (
            -not (
                $authorizationPath -ceq $sdkRoot -or
                (Test-IsInsidePath -Candidate $authorizationPath -Parent $sdkRoot) -or
                $authorizationPath -ceq $forbiddenRoot -or
                (Test-IsInsidePath -Candidate $authorizationPath -Parent $forbiddenRoot)
            ) -and
            (Test-Path -LiteralPath $authorizationPath -PathType Leaf)
        ) "SDK1 candidate authorization must be retained outside package and source"
        $authorizationSha256 = Get-Sha256 -Path $authorizationPath
        Assert-Exact (
            $authorizationSha256 -ceq
                [string]$packageManifest.readiness_report.sha256 -and
            [string]$packageManifest.readiness_report.schema_version -ceq
                "sporespore_quadruped_sdk1_milestone_readiness_report_v1" -and
            (Test-Path -LiteralPath $releaseContractPath -PathType Leaf) -and
            (Test-Path -LiteralPath $supportMatrixPath -PathType Leaf) -and
            (Get-Sha256 -Path $releaseContractPath) -ceq
                [string]$packageManifest.readiness_report.contract_sha256 -and
            (Get-Sha256 -Path $supportMatrixPath) -ceq
                [string]$packageManifest.readiness_report.support_matrix_sha256
        ) "SDK1 candidate authorization bindings are invalid"
        $authorization = Read-JsonObject -Path $authorizationPath
        $sdk1AuthorityValidatorPath = Join-Path (
            $sdkRoot
        ) "release\assert_quadruped_sdk1_candidate_authority.ps1"
        Assert-Exact (
            Test-Path -LiteralPath $sdk1AuthorityValidatorPath -PathType Leaf
        ) "SDK1 candidate-authority validator is missing from the package"
        . $sdk1AuthorityValidatorPath
        [void](Assert-QuadrupedSdk1CandidateAuthority `
            -Report $authorization `
            -ExpectedReleaseId ([string]$packageManifest.release_id) `
            -ExpectedSourceCommit ([string]$packageManifest.source_commit) `
            -ExpectedMappingId ([string]$packageManifest.readiness_report.mapping_id) `
            -ExpectedMappingSha256 ([string]$packageManifest.readiness_report.mapping_sha256) `
            -ExpectedContractSha256 ([string]$packageManifest.readiness_report.contract_sha256) `
            -ExpectedSupportMatrixSha256 ([string]$packageManifest.readiness_report.support_matrix_sha256)
        )
    }
    $manifestFiles = @($packageManifest.files)
    Assert-Exact (
        [int]$packageManifest.file_count -eq $manifestFiles.Count
    ) "Clean-room package manifest file count is invalid"
    foreach ($entry in $manifestFiles) {
        $entryPath = [System.IO.Path]::GetFullPath(
            (Join-Path $sdkRoot ([string]$entry.path))
        )
        Assert-Exact (
            Test-IsInsidePath -Candidate $entryPath -Parent $sdkRoot
        ) "Package manifest entry escaped the package root: $($entry.path)"
        Assert-Exact (
            Test-Path -LiteralPath $entryPath -PathType Leaf
        ) "Package manifest entry is missing: $($entry.path)"
        Assert-Exact (
            (Get-Sha256 -Path $entryPath) -ceq [string]$entry.sha256
        ) "Package manifest entry hash mismatch: $($entry.path)"
    }
    $packageManifestSha256 = Get-Sha256 -Path $packageManifestPath
    $sourceIdentity = [ordered]@{
        authority = "package_manifest"
        commit = [string]$packageManifest.source_commit
        package_manifest_sha256 = $packageManifestSha256
        package_file_hashes_verified = $true
        source_repository_clean = $null
        source_matches_origin_main = $null
    }
    Assert-Exact (
        -not [string]::IsNullOrWhiteSpace($Report)
    ) "Isolated-package R16 validation requires a durable -Report path"
    $isolatedReportPath = [System.IO.Path]::GetFullPath($Report)
    Assert-Exact (
        -not (
            $isolatedReportPath -ceq $sdkRoot -or
            (Test-IsInsidePath -Candidate $isolatedReportPath -Parent $sdkRoot)
        )
    ) "R16 report must be retained outside the clean-room package"
} else {
    $sourceRepoRoot = [System.IO.Path]::GetFullPath(
        (Split-Path -Parent $sdkRoot)
    )
    $sourceStatus = @(
        & git -C $sourceRepoRoot status --porcelain=v1 --untracked-files=all
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Could not inspect source status"
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
        commit = $sourceCommit
        origin_main = $originMain
        clean = $sourceStatus.Count -eq 0
        matches_origin_main = $sourceCommit -ceq $originMain
        status_entries = $sourceStatus
    }
    if (-not [string]::IsNullOrWhiteSpace($Report)) {
        Assert-Exact (
            [bool]$sourceIdentity.clean -and
            [bool]$sourceIdentity.matches_origin_main
        ) "Retained source conformance requires clean HEAD equal to origin/main"
    }
}

if (-not $SkipBuild) {
    Push-Location -LiteralPath $sdkRoot
    try {
        & cargo build `
            -p sporespore-locomotion-core `
            --release `
            --offline
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
            $candidate = Join-Path $sdkRoot "target\$profile\$name"
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

$tempParent = [System.IO.Path]::GetFullPath(
    [System.IO.Path]::GetTempPath()
).TrimEnd(
    [System.IO.Path]::DirectorySeparatorChar,
    [System.IO.Path]::AltDirectorySeparatorChar
)
$runRoot = Join-Path $tempParent (
    "sporespore-sdk-developer-experience-" +
    [Guid]::NewGuid().ToString("N")
)
[void][System.IO.Directory]::CreateDirectory($runRoot)
$recordingPath = Join-Path $runRoot "quickstart-recording.jsonl"
$previousPythonPath = $env:PYTHONPATH
$previousLibrary = $env:SPORESPORE_LOCOMOTION_LIBRARY
try {
    $env:PYTHONPATH = $sdkRoot
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $libraryPath

    $unitLines = @(
        & python `
            -m unittest discover `
            -s (Join-Path $sdkRoot "developer_experience") `
            -p "test_*.py" `
            -v 2>&1
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Developer-experience unit conformance failed"

    $quickstartLines = @(
        & python `
            (Join-Path $sdkRoot "examples\quadruped_quickstart.py") `
            --library $libraryPath `
            --recording $recordingPath 2>&1
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Standalone quadruped quickstart failed"
    $quickstart = Read-SingleJsonOutput `
        -Lines $quickstartLines `
        -Label "quadruped quickstart"
    Assert-Exact (
        [bool]$quickstart.recording_integrity_verified -and
        [bool]$quickstart.deterministic_policy_replay_exact -and
        [bool]$quickstart.all_outputs_pure -and
        [int]$quickstart.frame_count -eq 2 -and
        [int]$quickstart.ordered_actuator_command_count -eq 16 -and
        [int]$quickstart.world_build_count -eq 0 -and
        -not [bool]$quickstart.physics_trajectory_recorded_or_replayed -and
        -not [bool]$quickstart.walking_acceptance -and
        -not [bool]$quickstart.physical_acceptance_authority
    ) "Standalone quickstart claim or execution boundary is invalid"

    $verifyLines = @(
        & python `
            -m record_replay `
            verify `
            $recordingPath `
            --library $libraryPath 2>&1
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Record/replay CLI verification failed"
    $verify = Read-SingleJsonOutput `
        -Lines $verifyLines `
        -Label "recording verifier"
    Assert-Exact (
        [bool]$verify.integrity_verified -and
        -not [bool]$verify.deterministic_replay_executed -and
        [int]$verify.world_build_count -eq 0 -and
        -not [bool]$verify.physical_acceptance_authority
    ) "Record/replay verification receipt is invalid"

    $replayLines = @(
        & python `
            -m record_replay `
            replay `
            $recordingPath `
            --library $libraryPath 2>&1
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Record/replay CLI deterministic replay failed"
    $replay = Read-SingleJsonOutput `
        -Lines $replayLines `
        -Label "recording replay"
    Assert-Exact (
        [bool]$replay.integrity_verified -and
        [bool]$replay.deterministic_replay_executed -and
        [bool]$replay.deterministic_replay_exact -and
        -not [bool]$replay.physics_trajectory_replayed -and
        -not [bool]$replay.walking_acceptance -and
        [int]$replay.world_build_count -eq 0 -and
        -not [bool]$replay.physical_acceptance_authority
    ) "Record/replay deterministic replay receipt is invalid"

    $diagnosticLines = @(
        & python `
            -m diagnostics `
            --reference `
            --library $libraryPath 2>&1
    )
    Assert-Exact (
        $LASTEXITCODE -eq 0
    ) "Descriptor diagnostics CLI failed"
    $diagnostic = Read-SingleJsonOutput `
        -Lines $diagnosticLines `
        -Label "descriptor diagnostics"
    Assert-Exact (
        [bool]$diagnostic.accepted -and
        [int]$diagnostic.ordered_body_count -eq 9 -and
        [int]$diagnostic.ordered_actuator_count -eq 8 -and
        [int]$diagnostic.branch_surface_count -eq 0 -and
        [int]$diagnostic.world_build_count -eq 0 -and
        -not [bool]$diagnostic.walking_acceptance -and
        -not [bool]$diagnostic.physical_acceptance_authority
    ) "Descriptor diagnostics receipt is invalid"
} finally {
    $env:PYTHONPATH = $previousPythonPath
    $env:SPORESPORE_LOCOMOTION_LIBRARY = $previousLibrary
}

$receipt = [ordered]@{
    schema_version = "sporespore_developer_experience_conformance_report_v1"
    status = if ($RequireIsolatedPackage) {
        "clean_room_candidate_passed"
    } else {
        "source_conformance_passed_package_validation_pending"
    }
    release_gate_id = "QSDK-R16"
    package_root = $sdkRoot
    validation_scope = if ($RequireIsolatedPackage) {
        "clean_room_candidate"
    } else {
        "source_tree"
    }
    source_conformance_passed = $true
    clean_room_candidate_validated = [bool]$RequireIsolatedPackage
    r16_passed = [bool]$RequireIsolatedPackage
    source = $sourceIdentity
    sdk_version = [string]$quickstart.sdk_version
    abi_generation = [int]$quickstart.abi_generation
    policy_id = [string]$quickstart.policy_id
    library = [ordered]@{
        path = $libraryPath
        sha256 = Get-Sha256 -Path $libraryPath
    }
    package_manifest_sha256 = $packageManifestSha256
    conformance = [ordered]@{
        unit_test_count = 8
        unit_test_failure_count = 0
        quickstart_passed = $true
        diagnostics_passed = $true
        recording_verify_passed = $true
        deterministic_policy_replay_passed = $true
        negative_tamper_numeric_gap_version_policy_tests_passed = $true
        package_inventory_and_isolation_passed = [bool]$RequireIsolatedPackage
    }
    recording = [ordered]@{
        sha256 = [string]$quickstart.recording_sha256
        frame_count = [int]$quickstart.frame_count
        ordered_actuator_command_count =
            [int]$quickstart.ordered_actuator_command_count
        integrity_verified = [bool]$verify.integrity_verified
        deterministic_policy_replay_exact =
            [bool]$replay.deterministic_replay_exact
        physics_trajectory_recorded_or_replayed = $false
    }
    claims = [ordered]@{
        release_authorized = $false
        publication_authorized = $false
        walking_acceptance = $false
        physics_replay = $false
        world_build_count = 0
        physical_acceptance_authority = $false
        completed_engine_neutral_sdk = $false
    }
}

if (-not [string]::IsNullOrWhiteSpace($Report)) {
    $reportPath = [System.IO.Path]::GetFullPath($Report)
    $reportParent = Split-Path -Parent $reportPath
    Assert-Exact (
        Test-Path -LiteralPath $reportParent -PathType Container
    ) "Developer-experience report parent does not exist: $reportParent"
    Assert-Exact (
        -not (Test-Path -LiteralPath $reportPath)
    ) "Refusing to overwrite developer-experience report: $reportPath"
    [System.IO.File]::WriteAllText(
        $reportPath,
        ($receipt | ConvertTo-Json -Depth 50) + "`n",
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Host (
    "DEVELOPER_EXPERIENCE_CONFORMANCE " +
    ($receipt | ConvertTo-Json -Depth 50 -Compress)
)

$resolvedRunRoot = [System.IO.Path]::GetFullPath($runRoot)
Assert-Exact (
    $resolvedRunRoot.StartsWith(
        $tempParent + [System.IO.Path]::DirectorySeparatorChar +
        "sporespore-sdk-developer-experience-",
        [StringComparison]::Ordinal
    ) -and
    (Split-Path -Parent $resolvedRunRoot) -ceq $tempParent
) "Refusing to clean unexpected developer-experience run root"
Remove-Item -LiteralPath $resolvedRunRoot -Recurse -Force
