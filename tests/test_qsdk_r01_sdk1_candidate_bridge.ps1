#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$compilerPath = Join-Path $sdkRoot "compile_quadruped_sdk1_milestone_readiness.ps1"
$packagerPath = Join-Path $sdkRoot "package_quadruped_sdk.ps1"
$validatorPath = Join-Path (
    $sdkRoot
) "release\assert_quadruped_sdk1_candidate_authority.ps1"
$designPath = Join-Path (
    $sdkRoot
) "release\qsdk_r01_sdk1_candidate_bridge_design_v1.json"
$inventoryPath = Join-Path (
    $sdkRoot
) "release\quadruped_package_source_inventory_v1.json"
$releaseContractPath = Join-Path (
    $sdkRoot
) "release\quadruped_release_contract.json"
$supportMatrixPath = Join-Path (
    $sdkRoot
) "release\quadruped_support_matrix.json"
$systemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd(
    [IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar
)
$testRoot = Join-Path (
    $systemTempRoot
) ("sporespore_qsdk_r01_sdk1_bridge_" + [Guid]::NewGuid().ToString("N"))

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Read-JsonObject([string]$Path) {
    $value = Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json -Depth 100
    Assert-True ($null -ne $value -and $value -is [pscustomobject]) (
        "Expected a JSON object at $Path"
    )
    return $value
}

function Copy-JsonObject([pscustomobject]$Value) {
    return $Value | ConvertTo-Json -Depth 100 | ConvertFrom-Json -Depth 100
}

function Get-Sha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Get-LiveSdk1Report {
    $lines = @(& pwsh -NoProfile -File $compilerPath 6>$null)
    Assert-True ($LASTEXITCODE -eq 0) "SDK1 readiness compiler failed"
    $prefix = "QUADRUPED_SDK1_MILESTONE_READINESS "
    $markers = @($lines | Where-Object {
        $_ -is [string] -and $_.StartsWith($prefix, [StringComparison]::Ordinal)
    })
    Assert-True ($markers.Count -eq 1) "SDK1 compiler did not emit one report"
    return $markers[0].Substring($prefix.Length) | ConvertFrom-Json -Depth 100
}

function ConvertTo-PositiveShapeFixture([pscustomobject]$LiveReport) {
    $fixture = Copy-JsonObject $LiveReport
    $validationIds = @("SDK1-M01", "SDK1-M11", "SDK1-M15")
    foreach ($milestone in @($fixture.milestones)) {
        if ($validationIds -ccontains [string]$milestone.milestone_id) {
            $milestone.disposition = "missing"
        } else {
            $milestone.disposition = "passed"
        }
    }
    $fixture.status = "blocked"
    $fixture.sdk1_milestones_complete = $false
    $fixture.mapping_completion_authorizes_release = $false
    $fixture.clean_room_candidate_authorized = $true
    $fixture.clean_room_candidate_release_authorized = $false
    $fixture.clean_room_candidate_publication_authorized = $false
    $fixture.clean_room_candidate_artifact_role = (
        "sdk1_clean_room_conformance_candidate"
    )
    $fixture.source.clean = $true
    $fixture.source.matches_origin_main = $true
    $fixture.source.origin_main = [string]$fixture.source.commit
    $fixture.source.status_entries = @()
    $fixture.sdk1_counts.total = 20
    $fixture.sdk1_counts.passed = 17
    $fixture.sdk1_counts.missing = 3
    $fixture.sdk1_counts.contradicted = 0
    $fixture.sdk1_counts.invalid_proof = 0
    $fixture.clean_room_candidate_blocking_milestone_ids = @()
    $fixture.clean_room_candidate_blocking_conditions = @()
    $fixture.blocking_milestone_ids = $validationIds
    $fixture.support_matrix.consistent_with_gate_dispositions = $true
    $fixture.support_matrix.failures = @()
    $fixture.full_program.denominator_changed = $false
    $fixture.claims.bounded_sdk1_scope_mapped = $true
    $fixture.claims.clean_room_candidate_is_full_program_candidate = $false
    $fixture.claims.clean_room_candidate_is_release = $false
    $fixture.claims.sdk1_released = $false
    $fixture.claims.publication_authorized = $false
    return $fixture
}

function Assert-FixtureAccepted(
    [pscustomobject]$Fixture,
    [pscustomobject]$ExpectedBindings = $Fixture
) {
    return Assert-QuadrupedSdk1CandidateAuthority `
        -Report $Fixture `
        -ExpectedReleaseId ([string]$ExpectedBindings.release_id) `
        -ExpectedSourceCommit ([string]$ExpectedBindings.source.commit) `
        -ExpectedMappingId ([string]$ExpectedBindings.mapping_id) `
        -ExpectedMappingSha256 ([string]$ExpectedBindings.mapping.sha256) `
        -ExpectedContractSha256 ([string]$ExpectedBindings.contract.sha256) `
        -ExpectedSupportMatrixSha256 ([string]$ExpectedBindings.support_matrix.sha256)
}

try {
    [void][IO.Directory]::CreateDirectory($testRoot)
    Assert-True (
        (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("\", "/") -ceq
            $repoRoot.Replace("\", "/")
    ) "QSDK-R01 bridge test is not running in the authoritative checkout"
    Assert-True (
        (& git -C $repoRoot remote get-url origin).Trim() -ceq
            "https://github.com/Slagathore/sporespore.git"
    ) "QSDK-R01 bridge test found the wrong origin"
    foreach ($path in @(
        $compilerPath,
        $packagerPath,
        $validatorPath,
        $designPath,
        $inventoryPath,
        $releaseContractPath,
        $supportMatrixPath
    )) {
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) (
            "Required QSDK-R01 bridge path is missing: $path"
        )
    }

    $design = Read-JsonObject $designPath
    Assert-True (
        [string]$design.schema_version -ceq
            "sporespore_qsdk_r01_sdk1_candidate_bridge_design_v1" -and
        [string]$design.status -ceq
            "implemented_zero_world_bridge_candidate_execution_still_blocked" -and
        [string]$design.ledger_scope.subsystem -ceq "release" -and
        [string]$design.ledger_scope.engine_scope -ceq "engine_neutral" -and
        [string]$design.ledger_scope.authority_mode -ceq
            "bounded_sdk1_candidate_preparation" -and
        [string]$design.ledger_scope.question_class -ceq "development" -and
        -not [bool]$design.current_boundary.candidate_created -and
        -not [bool]$design.current_boundary.candidate_runner_executed -and
        -not [bool]$design.current_boundary.q_sdk_r01_satisfied -and
        -not [bool]$design.current_boundary.sdk1_m01_satisfied -and
        -not [bool]$design.current_boundary.score_change
    ) "QSDK-R01 bridge design claim boundary is invalid"

    $inventory = Read-JsonObject $inventoryPath
    $requiredPaths = @($inventory.required_portable_api_paths | ForEach-Object {
        [string]$_
    })
    Assert-True (
        "release/assert_quadruped_sdk1_candidate_authority.ps1" -cin
            $requiredPaths -and
        "release/quadruped_release_contract.json" -cin $requiredPaths -and
        "release/quadruped_sdk1_milestone_mapping_v1.json" -cin $requiredPaths -and
        "release/quadruped_support_matrix.json" -cin $requiredPaths
    ) "Package inventory does not require every SDK1 authorization input"

    . $validatorPath
    $liveReport = Get-LiveSdk1Report
    $fixture = ConvertTo-PositiveShapeFixture $liveReport
    $accepted = Assert-FixtureAccepted $fixture
    Assert-True (
        [string]$accepted.authority_scope -ceq "bounded_sdk1_17_plus_3" -and
        [bool]$accepted.clean_room_candidate_authorized -and
        -not [bool]$accepted.release_authorized -and
        -not [bool]$accepted.publication_authorized
    ) "Positive-shape SDK1 authorization fixture was not accepted exactly"

    $mutations = @(
        @{ label = "schema"; apply = { param($x) $x.schema_version = "wrong" } },
        @{ label = "release_authority"; apply = { param($x) $x.clean_room_candidate_release_authorized = $true } },
        @{ label = "dirty_source"; apply = { param($x) $x.source.clean = $false } },
        @{ label = "mapping_hash"; apply = { param($x) $x.mapping.sha256 = "sha256:wrong" } },
        @{ label = "contract_hash"; apply = { param($x) $x.contract.sha256 = "sha256:wrong" } },
        @{ label = "support_hash"; apply = { param($x) $x.support_matrix.sha256 = "sha256:wrong" } },
        @{ label = "count"; apply = { param($x) $x.sdk1_counts.passed = 16 } },
        @{ label = "validation_order"; apply = { param($x) $x.clean_room_candidate_validation_gate_ids = @("QSDK-R16", "QSDK-R01", "QSDK-R20") } },
        @{ label = "blocker"; apply = { param($x) $x.clean_room_candidate_blocking_conditions = @("SDK1-M07") } },
        @{ label = "deferred_gate"; apply = { param($x) $x.deferred_full_program_gate_ids = @("QSDK-R06") } },
        @{ label = "prerequisite"; apply = { param($x) ($x.milestones | Where-Object milestone_id -eq "SDK1-M07").disposition = "missing" } },
        @{ label = "premature_validation"; apply = { param($x) ($x.milestones | Where-Object milestone_id -eq "SDK1-M01").disposition = "passed" } },
        @{ label = "full_program_claim"; apply = { param($x) $x.claims.clean_room_candidate_is_full_program_candidate = $true } }
    )
    $rejectionCount = 0
    foreach ($mutation in $mutations) {
        $mutated = Copy-JsonObject $fixture
        & $mutation.apply $mutated
        $refused = $false
        try {
            [void](Assert-FixtureAccepted $mutated $fixture)
        } catch {
            $refused = $true
        }
        Assert-True $refused (
            "SDK1 authority validator accepted mutation '$($mutation.label)'"
        )
        $rejectionCount += 1
    }
    Assert-True ($rejectionCount -eq 13) "Unexpected mutation-refusal count"

    $forgedFixture = Copy-JsonObject $fixture
    $forgedFixture.source.commit = "0000000000000000000000000000000000000001"
    $forgedFixture.source.origin_main = [string]$forgedFixture.source.commit
    $forgedPath = Join-Path $testRoot "forged_sdk1_authority.json"
    [IO.File]::WriteAllText(
        $forgedPath,
        ($forgedFixture | ConvertTo-Json -Depth 100) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $forgedOutput = Join-Path $testRoot "forged_candidate"
    $forgedRefused = $false
    try {
        & $packagerPath `
            -ReadinessReport $forgedPath `
            -OutputDirectory $forgedOutput `
            -Sdk1CleanRoomCandidate `
            6>$null | Out-Null
    } catch {
        $forgedRefused = $true
    }
    Assert-True $forgedRefused (
        "SDK1 packager trusted retained authority without exact live reauthorization"
    )
    Assert-True (-not (Test-Path -LiteralPath $forgedOutput)) (
        "Forged SDK1 authority created a package"
    )

    $conflictOutput = Join-Path $testRoot "conflicting_candidate_modes"
    $conflictRefused = $false
    try {
        & $packagerPath `
            -ReadinessReport $forgedPath `
            -OutputDirectory $conflictOutput `
            -CleanRoomCandidate `
            -Sdk1CleanRoomCandidate `
            6>$null | Out-Null
    } catch {
        $conflictRefused = $true
    }
    Assert-True $conflictRefused "Packager accepted conflicting candidate modes"
    Assert-True (-not (Test-Path -LiteralPath $conflictOutput)) (
        "Conflicting candidate modes created a package"
    )
    Assert-True (
        @(Get-ChildItem -LiteralPath $testRoot -Directory -Filter "*.incomplete-*").Count -eq 0
    ) "Rejected SDK1 bridge tests left an incomplete package directory"

    $releaseContract = Read-JsonObject $releaseContractPath
    $r01 = @($releaseContract.gates | Where-Object {
        [string]$_.gate_id -ceq "QSDK-R01"
    })
    Assert-True (
        $r01.Count -eq 1 -and
        [string]$r01[0].proof.kind -ceq "missing"
    ) "Bridge implementation prematurely advanced QSDK-R01"

    Write-Host (
        "QSDK_R01_SDK1_CANDIDATE_BRIDGE passed=1 positive_shape=1 " +
        "mutation_refusals=$rejectionCount forged_live_refusal=1 " +
        "conflicting_mode_refusal=1 package_created=0 worlds=0 solver_steps=0"
    )
} finally {
    $resolvedTestRoot = [IO.Path]::GetFullPath($testRoot)
    $expectedPrefix = $systemTempRoot + [IO.Path]::DirectorySeparatorChar
    Assert-True (
        $resolvedTestRoot.StartsWith(
            $expectedPrefix,
            [StringComparison]::OrdinalIgnoreCase
        ) -and
        [IO.Path]::GetFileName($resolvedTestRoot).StartsWith(
            "sporespore_qsdk_r01_sdk1_bridge_",
            [StringComparison]::Ordinal
        )
    ) "Refusing to clean an unexpected SDK1 bridge test path"
    if (Test-Path -LiteralPath $resolvedTestRoot) {
        Remove-Item -LiteralPath $resolvedTestRoot -Recurse -Force
    }
}
