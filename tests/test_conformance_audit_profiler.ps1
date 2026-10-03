#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "conformance_audit_profiler_contract_v1.json"
$closurePath = Join-Path $sdkRoot "conformance_audit_profiler_closure_v1.json"
$profilerPath = Join-Path $sdkRoot "measure_conformance_audit_durations.ps1"
$inventoryPath = Join-Path $sdkRoot "closure_evidence_mode_inventory.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Cap1Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP1 profiler test failed: $Message" }
}

function Get-Cap1TestRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

foreach ($path in @(
    $contractPath, $closurePath, $profilerPath, $inventoryPath,
    $artifactStorePath, $runnerPath
)) {
    Assert-Cap1Test (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}
. $artifactStorePath

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$closure = Get-Content -LiteralPath $closurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$frozenInventoryCommit = [string]$closure.prospective_boundary.source_commit
$inventoryRelativePath = "sdk/closure_evidence_mode_inventory.json"
$frozenInventorySpec = "${frozenInventoryCommit}:$inventoryRelativePath"
$frozenInventoryBlobOid = (& git -C $repoRoot rev-parse $frozenInventorySpec).Trim()
Assert-Cap1Test (
    $LASTEXITCODE -eq 0 -and
    $frozenInventoryCommit -ceq "8262f853d5dc5d59d7ba50f1991eaacc9608c3c4" -and
    $frozenInventoryBlobOid -ceq "a1722392dfa2b63fb37bfe3ac961c75f3059fc6e"
) "frozen CAP1 inventory Git identity changed or disappeared"
$frozenInventoryLines = @(& git -C $repoRoot cat-file blob $frozenInventoryBlobOid)
Assert-Cap1Test ($LASTEXITCODE -eq 0) (
    "frozen CAP1 inventory blob could not be read"
)
$frozenInventoryText = ($frozenInventoryLines -join "`n") + "`n"
$inventory = $frozenInventoryText |
    ConvertFrom-Json -AsHashtable -Depth 32
$liveInventory = Get-Content -LiteralPath $inventoryPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$livePaths = [Collections.Generic.HashSet[string]]::new(
    [StringComparer]::Ordinal
)
foreach ($entry in @($liveInventory.entries)) {
    [void]$livePaths.Add([string]$entry.path)
}
$missingFrozenPaths = @($inventory.entries | Where-Object {
    -not $livePaths.Contains([string]$_.path)
})
$profilerSource = Get-Content -LiteralPath $profilerPath -Raw
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-Cap1Test (
    [string]$contract.status -ceq
        "prospective_development_profiler_no_reuse_authority" -and
    [int]$contract.production_inventory.expected_audit_count -eq 95 -and
    [int]$inventory.audit_count -eq 95 -and
    [int]$liveInventory.audit_count -ge [int]$inventory.audit_count -and
    $missingFrozenPaths.Count -eq 0 -and
    [int]$inventory.world_build_count -eq 0 -and
    -not [bool]$inventory.physical_execution_authorized -and
    -not [bool]$inventory.physical_acceptance_authority -and
    [bool]$contract.claims.development_observation_only -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_authority -and
    -not [bool]$contract.claims.release_authority -and
    $profilerSource.Contains("continue_after_failure_for_complete_ranking") -eq
        $false -and
    $profilerSource.Contains(
        "CAP1 profiler is retired for new production runs after CAP1-C1",
        [StringComparison]::Ordinal
    ) -and
    $profilerSource.Contains('foreach ($entry in $selectedEntries)') -and
    $profilerSource.Contains('if ($failureCount -ne 0) { exit 1 }') -and
    $runnerSource.Contains(
        "tests\test_conformance_audit_profiler.ps1",
        [StringComparison]::Ordinal
    )
) "contract, inventory, profiler, or canonical route changed"

$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source
$retiredOutput = @(& $pwsh `
    -NoLogo `
    -NoProfile `
    -File $profilerPath `
    2>&1)
$retiredExitCode = $LASTEXITCODE
Assert-Cap1Test (
    $retiredExitCode -ne 0 -and
    (($retiredOutput -join " ").Contains(
        "CAP1 profiler is retired for new production runs after CAP1-C1",
        [StringComparison]::Ordinal
    ))
) "retired CAP1 production route remained executable"

$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-cap1-test-" + [guid]::NewGuid().ToString("N")
)
[void][IO.Directory]::CreateDirectory($testRoot)
$frozenInventoryPath = Join-Path $testRoot "cap1-frozen-inventory.json"
[IO.File]::WriteAllText(
    $frozenInventoryPath,
    $frozenInventoryText,
    [Text.UTF8Encoding]::new($false)
)
$selectedPath = "tests/test_qsdk_r23d13_closure.ps1"
try {
    $profileOutput = @(& $pwsh `
        -NoLogo `
        -NoProfile `
        -File $profilerPath `
        -InventoryPathOverride $frozenInventoryPath `
        -IncludePath $selectedPath `
        -EvidenceRootOverride $testRoot `
        -TestOnly `
        2>&1)
    $profileExitCode = $LASTEXITCODE
    Assert-Cap1Test ($profileExitCode -eq 0) (
        "test-only profile failed: " + ($profileOutput -join " ")
    )
    $profileRunRoots = @(Get-ChildItem -LiteralPath (
        Join-Path $testRoot "conformance-audit-profiles"
    ) -Directory)
    Assert-Cap1Test ($profileRunRoots.Count -eq 1) (
        "test-only profiler did not create exactly one run"
    )
    $profilePath = Join-Path $profileRunRoots[0].FullName "profile.json"
    $profile = Get-Content -LiteralPath $profilePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 64
    $receipt = @($profile.receipts)[0]
    $ranking = @($profile.ranking)[0]
    Assert-Cap1Test (
        [string]$profile.schema_version -ceq
            "sporespore_conformance_audit_duration_profile_v1" -and
        [string]$profile.status -ceq
            "complete_development_observation_all_selected_passed" -and
        [int]$profile.input.selected_audit_count -eq 1 -and
        [int]$profile.input.production_inventory_count -eq 95 -and
        [int]$profile.summary.selected_audit_count -eq 1 -and
        [int]$profile.summary.pass_count -eq 1 -and
        [int]$profile.summary.failure_count -eq 0 -and
        [double]$profile.summary.total_audit_seconds -gt 0 -and
        [bool]$profile.summary.serialized -and
        [string]$receipt.audit_path -ceq $selectedPath -and
        [bool]$receipt.passed -and
        [int]$receipt.exit_code -eq 0 -and
        -not [bool]$receipt.timed_out -and
        -not [bool]$receipt.timeout_is_proven_hang -and
        [string]$receipt.stdout_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        [long]$receipt.stdout_byte_length -gt 0 -and
        [string]$receipt.stderr_sha256 -ceq
            "sha256:e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" -and
        [long]$receipt.stderr_byte_length -eq 0 -and
        [string]$ranking.audit_path -ceq $selectedPath -and
        [double]$ranking.duration_seconds -eq [double]$receipt.duration_seconds -and
        [bool]$profile.test_only -and
        [bool]$profile.development_observation_only -and
        -not [bool]$profile.audit_dependency_complete -and
        -not [bool]$profile.runtime_profile_complete -and
        -not [bool]$profile.cold_equivalence_complete -and
        -not [bool]$profile.production_cache_lookup_permitted -and
        -not [bool]$profile.production_result_reuse_permitted -and
        -not [bool]$profile.historical_audit_waiver_permitted -and
        -not [bool]$profile.physical_authority -and
        -not [bool]$profile.scientific_authority -and
        -not [bool]$profile.release_authority
    ) "test-only profile content or claim boundary changed"

    foreach ($artifact in @(
        [ordered]@{
            sha = [string]$receipt.stdout_sha256
            bytes = [long]$receipt.stdout_byte_length
        },
        [ordered]@{
            sha = [string]$receipt.stderr_sha256
            bytes = [long]$receipt.stderr_byte_length
        },
        [ordered]@{
            sha = Get-Cap1TestRawSha256 $profilePath
            bytes = (Get-Item -LiteralPath $profilePath).Length
        }
    )) {
        $hex = ([string]$artifact.sha).Substring(7)
        Assert-Cap1Test (Test-SporeSporeStoredArtifact `
            -Directory (Join-Path $testRoot "artifacts\sha256\$hex") `
            -ExpectedSha256 $hex `
            -ExpectedByteLength ([long]$artifact.bytes)) (
            "profile or stream CAS verification failed: $($artifact.sha)"
        )
    }

    $selectedEntry = @($inventory.entries | Where-Object {
        [string]$_.path -ceq $selectedPath
    })[0]
    $mutatedInventory = [ordered]@{
        schema_version = [string]$inventory.schema_version
        audit_count = 1
        entries = @([ordered]@{
            path = [string]$selectedEntry.path
            raw_sha256 = "0" * 64
            historical_identity_mode =
                [string]$selectedEntry.historical_identity_mode
            manual_review_required = [bool]$selectedEntry.manual_review_required
        })
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
    $mutatedInventoryPath = Join-Path $testRoot "mutated-inventory.json"
    [IO.File]::WriteAllText(
        $mutatedInventoryPath,
        ($mutatedInventory | ConvertTo-Json -Depth 16) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
    $mutationOutput = @(& $pwsh `
        -NoLogo `
        -NoProfile `
        -File $profilerPath `
        -InventoryPathOverride $mutatedInventoryPath `
        -IncludePath $selectedPath `
        -EvidenceRootOverride (Join-Path $testRoot "mutation") `
        -TestOnly `
        2>&1)
    $mutationExitCode = $LASTEXITCODE
    Assert-Cap1Test (
        $mutationExitCode -ne 0 -and
        (($mutationOutput -join " ").Contains(
            "audit source hash differs from CEP1",
            [StringComparison]::Ordinal
        ))
    ) "CEP1 audit-source mutation was accepted"

    Write-Output (
        "CONFORMANCE_AUDIT_PROFILER_PASS production_audits=95 selected=1 " +
        "serialized=True stdout_cas=True stderr_cas=True profile_cas=True " +
        "source_mutation=True pinned_inventory_source=True " +
        "live_inventory_growth_decoupled=True " +
        "cap1_production_retired=True " +
        "timeout_hang_claim=False cache=disabled worlds=0 " +
        "physical_authority=False release_authority=False"
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [IO.Path]::GetFullPath($testRoot)
        $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
        if (-not $resolved.StartsWith(
                $temp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -or
            (Split-Path -Leaf $resolved) -notlike 'sporespore-cap1-test-*') {
            throw "Refusing unsafe CAP1 test cleanup: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
