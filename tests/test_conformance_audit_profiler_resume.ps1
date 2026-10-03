#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot "conformance_audit_profiler_contract_v2.json"
$profilerPath = Join-Path $sdkRoot "measure_conformance_audit_durations_v2.ps1"
$inventoryPath = Join-Path $sdkRoot "closure_evidence_mode_inventory.json"
$artifactStorePath = Join-Path $sdkRoot "content_addressed_artifact_store.ps1"
$dependencyKeyPath = Join-Path $sdkRoot "conformance_dependency_key.ps1"
$commissioningRunnerPath = Join-Path $sdkRoot (
    "run_conformance_audit_profiler_resume_commissioning.ps1"
)
$runnerPath = Join-Path $sdkRoot "run_conformance.ps1"

function Assert-Cap2Test {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "CAP2 profiler test failed: $Message" }
}

foreach ($path in @(
    $contractPath, $profilerPath, $inventoryPath, $artifactStorePath,
    $dependencyKeyPath, $commissioningRunnerPath, $runnerPath
)) {
    Assert-Cap2Test (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing input: $path"
    )
}
. $artifactStorePath

$contract = Get-Content -LiteralPath $contractPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$inventory = Get-Content -LiteralPath $inventoryPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 32
$profilerSource = Get-Content -LiteralPath $profilerPath -Raw
$commissioningRunnerSource = Get-Content -LiteralPath $commissioningRunnerPath -Raw
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
Assert-Cap2Test (
    [string]$contract.status -ceq
        "prospective_crash_resilient_development_profiler_uncommissioned" -and
    [bool]$contract.predecessor.new_production_runs_through_v1_refuse -and
    [bool]$contract.predecessor.v1_test_only_regression_route_retained -and
    @($contract.commissioning.selected_audits).Count -eq 2 -and
    [string]$contract.production_inventory.expected_remote_url -ceq
        "https://github.com/Slagathore/sporespore.git" -and
    [bool]$contract.execution.production_requires_live_remote_main_equal_head -and
    [int]$contract.commissioning.controlled_stop_after_published_receipt_count -eq 1 -and
    [bool]$contract.incremental_retention.run_manifest_content_addressed_before_first_audit -and
    [bool]$contract.incremental_retention.stdout_and_stderr_content_addressed_before_receipt -and
    [bool]$contract.incremental_retention.per_audit_receipt_content_addressed_before_atomic_publication -and
    [bool]$contract.resume.complete_process_environment_digest_is_keyed -and
    [bool]$contract.resume.receipt_prefix_must_be_contiguous_from_ordinal_one -and
    [bool]$contract.resume.verified_receipts_are_not_reexecuted -and
    -not [bool]$contract.claims.crash_resilient_resume_commissioned -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_authority -and
    -not [bool]$contract.claims.release_authority -and
    $profilerSource.Contains('[IO.FileShare]::None') -and
    $profilerSource.Contains('[IO.File]::Move($pendingReceiptPath, $receiptPath)') -and
    $profilerSource.IndexOf(
        '$stdoutArtifact = Publish-SporeSporeContentAddressedArtifact',
        [StringComparison]::Ordinal
    ) -lt $profilerSource.IndexOf(
        '[IO.File]::Move($pendingReceiptPath, $receiptPath)',
        [StringComparison]::Ordinal
    ) -and
    $profilerSource.Contains('CAP2_RECEIPT_PREFIX_VERIFIED') -and
    $commissioningRunnerSource.Contains('$startOutput = @(& $pwsh') -and
    $commissioningRunnerSource.Contains('$resumeOutput = @(& $pwsh') -and
    $commissioningRunnerSource.Contains(
        '$firstReceiptAfterSha -ceq $firstReceiptSha'
    ) -and
    $runnerSource.Contains(
        "tests\test_conformance_audit_profiler_resume.ps1",
        [StringComparison]::Ordinal
    )
) "contract, publication order, resume branch, or canonical route changed"

$selectedEntries = @($contract.commissioning.selected_audits | ForEach-Object {
    $selectedPath = [string]$_
    $matches = @($inventory.entries | Where-Object {
        [string]$_.path -ceq $selectedPath
    })
    Assert-Cap2Test ($matches.Count -eq 1) (
        "commissioning audit is not unique in CEP1: $selectedPath"
    )
    $matches[0]
})

$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-cap2-test-" + [guid]::NewGuid().ToString("N")
)
[void][IO.Directory]::CreateDirectory($testRoot)
$testInventoryPath = Join-Path $testRoot "inventory.json"
$reversedInventoryPath = Join-Path $testRoot "inventory-reversed.json"
$pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
    Select-Object -First 1).Source

function Write-Cap2TestInventory {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Entries
    )
    $projection = [ordered]@{
        schema_version = "sporespore_closure_evidence_mode_inventory_v1"
        audit_count = $Entries.Count
        entries = @($Entries | ForEach-Object {
            [ordered]@{
                path = [string]$_.path
                raw_sha256 = [string]$_.raw_sha256
                historical_identity_mode = [string]$_.historical_identity_mode
                manual_review_required = [bool]$_.manual_review_required
            }
        })
        world_build_count = 0
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
    }
    [IO.File]::WriteAllText(
        $Path,
        ($projection | ConvertTo-Json -Depth 16) + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Cap2TestProfiler {
    param(
        [Parameter(Mandatory)][string]$EvidenceRoot,
        [Parameter(Mandatory)][string]$InventoryOverride,
        [string]$ResumeRunId = "",
        [int]$StopAfterReceiptCount = 0
    )
    $arguments = [Collections.Generic.List[string]]::new()
    foreach ($argument in @(
        "-NoLogo", "-NoProfile", "-File", $profilerPath,
        "-InventoryPathOverride", $InventoryOverride,
        "-EvidenceRootOverride", $EvidenceRoot,
        "-TestOnly"
    )) { $arguments.Add($argument) }
    if (-not [string]::IsNullOrWhiteSpace($ResumeRunId)) {
        $arguments.Add("-ResumeRunId")
        $arguments.Add($ResumeRunId)
    }
    if ($StopAfterReceiptCount -gt 0) {
        $arguments.Add("-StopAfterPublishedReceiptCount")
        $arguments.Add([string]$StopAfterReceiptCount)
    }
    $output = @(& $pwsh @arguments 2>&1)
    $exitCode = $LASTEXITCODE
    return [ordered]@{
        exit_code = $exitCode
        output = [object[]]$output
        text = ($output -join "`n")
    }
}

function Get-Cap2TestMarker {
    param(
        [Parameter(Mandatory)][object[]]$Output,
        [Parameter(Mandatory)][string]$Prefix
    )
    $lines = @($Output | ForEach-Object { [string]$_ } | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-Cap2Test ($lines.Count -eq 1) (
        "expected exactly one marker '$Prefix', found $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 16
}

function Get-Cap2CaseRunRoot {
    param([string]$EvidenceRoot, [string]$RunId)
    return Join-Path $EvidenceRoot "conformance-audit-profiles-v2\$RunId"
}

function Start-Cap2InterruptedCase {
    param([Parameter(Mandatory)][string]$EvidenceRoot)
    [void][IO.Directory]::CreateDirectory($EvidenceRoot)
    $started = Invoke-Cap2TestProfiler `
        -EvidenceRoot $EvidenceRoot `
        -InventoryOverride $testInventoryPath `
        -StopAfterReceiptCount 1
    Assert-Cap2Test (
        [int]$started.exit_code -eq 90 -and
        $started.text.Contains("CAP2_CONTROLLED_STOP", [StringComparison]::Ordinal)
    ) "controlled interruption did not stop after one published receipt: $($started.text)"
    $created = Get-Cap2TestMarker `
        -Output $started.output -Prefix "CAP2_RUN_CREATED "
    $stopped = Get-Cap2TestMarker `
        -Output $started.output -Prefix "CAP2_CONTROLLED_STOP "
    $runId = [string]$created.run_id
    $runRoot = Get-Cap2CaseRunRoot -EvidenceRoot $EvidenceRoot -RunId $runId
    $receiptPath = Join-Path $runRoot "receipts\001.json"
    Assert-Cap2Test (
        [string]$created.manifest_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        [int]$stopped.published_receipt_count -eq 1 -and
        [int]$stopped.audit_invocation_count -eq 1 -and
        -not [bool]$stopped.authority -and
        (Test-Path -LiteralPath (Join-Path $runRoot "run_manifest.json") -PathType Leaf) -and
        (Test-Path -LiteralPath $receiptPath -PathType Leaf) -and
        -not (Test-Path -LiteralPath (Join-Path $runRoot "profile.json"))
    ) "interrupted run did not retain exactly one manifest/receipt prefix"
    return [ordered]@{
        evidence_root = $EvidenceRoot
        run_id = $runId
        run_root = $runRoot
        receipt_path = $receiptPath
        receipt_sha256 = "sha256:" + (
            Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256
        ).Hash.ToLowerInvariant()
        manifest_sha256 = [string]$created.manifest_sha256
    }
}

function Assert-Cap2TestCas {
    param(
        [string]$EvidenceRoot,
        [string]$Sha256,
        [long]$ByteLength,
        [string]$Label
    )
    $hex = $Sha256.Substring(7)
    Assert-Cap2Test (Test-SporeSporeStoredArtifact `
        -Directory (Join-Path $EvidenceRoot "artifacts\sha256\$hex") `
        -ExpectedSha256 $hex `
        -ExpectedByteLength $ByteLength) "$Label CAS verification failed"
}

Write-Cap2TestInventory -Path $testInventoryPath -Entries $selectedEntries
Write-Cap2TestInventory -Path $reversedInventoryPath `
    -Entries ([object[]]@($selectedEntries[1], $selectedEntries[0]))

try {
    $mainCase = Start-Cap2InterruptedCase `
        -EvidenceRoot (Join-Path $testRoot "main")
    $firstReceiptBytes = (Get-Item -LiteralPath $mainCase.receipt_path).Length
    Assert-Cap2TestCas -EvidenceRoot $mainCase.evidence_root `
        -Sha256 $mainCase.receipt_sha256 `
        -ByteLength $firstReceiptBytes -Label "first immediate receipt"

    $mutationName = "SPORESPORE_CAP2_TEST_" + [guid]::NewGuid().ToString("N")
    try {
        [Environment]::SetEnvironmentVariable(
            $mutationName,
            "mutation",
            [EnvironmentVariableTarget]::Process
        )
        $environmentMutation = Invoke-Cap2TestProfiler `
            -EvidenceRoot $mainCase.evidence_root `
            -InventoryOverride $testInventoryPath `
            -ResumeRunId $mainCase.run_id
        Assert-Cap2Test (
            [int]$environmentMutation.exit_code -ne 0 -and
            $environmentMutation.text.Contains(
                "live input key differs from the run",
                [StringComparison]::Ordinal
            )
        ) "complete process-environment mutation was accepted"
    } finally {
        [Environment]::SetEnvironmentVariable(
            $mutationName,
            [System.Management.Automation.Language.NullString]::Value,
            [EnvironmentVariableTarget]::Process
        )
    }

    $selectionMutation = Invoke-Cap2TestProfiler `
        -EvidenceRoot $mainCase.evidence_root `
        -InventoryOverride $reversedInventoryPath `
        -ResumeRunId $mainCase.run_id
    Assert-Cap2Test (
        [int]$selectionMutation.exit_code -ne 0 -and
        $selectionMutation.text.Contains(
            "live input key differs from the run",
            [StringComparison]::Ordinal
        )
    ) "ordered audit-selection mutation was accepted"

    $lease = [IO.File]::Open(
        (Join-Path $mainCase.run_root ".cap2.lock"),
        [IO.FileMode]::Open,
        [IO.FileAccess]::ReadWrite,
        [IO.FileShare]::None
    )
    try {
        $concurrent = Invoke-Cap2TestProfiler `
            -EvidenceRoot $mainCase.evidence_root `
            -InventoryOverride $testInventoryPath `
            -ResumeRunId $mainCase.run_id
        Assert-Cap2Test (
            [int]$concurrent.exit_code -ne 0 -and
            $concurrent.text.Contains(
                "exclusive run lease unavailable",
                [StringComparison]::Ordinal
            )
        ) "concurrent resume acquired the run lease"
    } finally { $lease.Dispose() }

    $orphanPending = Join-Path $mainCase.run_root "pending\orphan-test"
    [void][IO.Directory]::CreateDirectory($orphanPending)
    [IO.File]::WriteAllText(
        (Join-Path $orphanPending "partial.txt"),
        "non-authoritative pending bytes",
        [Text.UTF8Encoding]::new($false)
    )
    $resumed = Invoke-Cap2TestProfiler `
        -EvidenceRoot $mainCase.evidence_root `
        -InventoryOverride $testInventoryPath `
        -ResumeRunId $mainCase.run_id
    Assert-Cap2Test ([int]$resumed.exit_code -eq 0) (
        "valid exact resume failed: $($resumed.text)"
    )
    $resumeSummary = Get-Cap2TestMarker `
        -Output $resumed.output -Prefix "CAP2_PROFILE_COMPLETE "
    $firstReceiptAfter = "sha256:" + (
        Get-FileHash -LiteralPath $mainCase.receipt_path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    $profilePath = Join-Path $mainCase.run_root "profile.json"
    $profile = Get-Content -LiteralPath $profilePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 64
    Assert-Cap2Test (
        $firstReceiptAfter -ceq [string]$mainCase.receipt_sha256 -and
        [int]$profile.summary.selected_audit_count -eq 2 -and
        [int]$profile.summary.pass_count -eq 2 -and
        [int]$profile.summary.failure_count -eq 0 -and
        [int]$profile.summary.resumed_receipt_count -eq 1 -and
        [int]$profile.summary.audit_invocation_count_this_process -eq 1 -and
        [int]$profile.summary.orphan_pending_directory_count -eq 1 -and
        [int]$profile.summary.world_build_count -eq 0 -and
        @($profile.receipt_index).Count -eq 2 -and
        @($profile.receipts).Count -eq 2 -and
        [int]$resumeSummary.resumed_receipt_count -eq 1 -and
        [int]$resumeSummary.audit_invocation_count -eq 1 -and
        [int]$resumeSummary.worlds -eq 0 -and
        -not [bool]$resumeSummary.physical_authority -and
        -not [bool]$resumeSummary.release_authority -and
        [bool]$profile.test_only -and
        -not [bool]$profile.commissioning -and
        [bool]$profile.crash_resilient_resume_candidate -and
        -not [bool]$profile.crash_resilient_resume_commissioned -and
        -not [bool]$profile.production_cache_lookup_permitted -and
        -not [bool]$profile.production_result_reuse_permitted -and
        -not [bool]$profile.physical_authority -and
        -not [bool]$profile.scientific_authority -and
        -not [bool]$profile.release_authority
    ) "resume reexecuted a receipt or changed the profile authority boundary"

    foreach ($indexEntry in @($profile.receipt_index)) {
        $receipt = @($profile.receipts | Where-Object {
            [int]$_.ordinal -eq [int]$indexEntry.ordinal
        })[0]
        Assert-Cap2TestCas -EvidenceRoot $mainCase.evidence_root `
            -Sha256 ([string]$indexEntry.receipt_sha256) `
            -ByteLength ([long]$indexEntry.receipt_byte_length) `
            -Label "receipt $($indexEntry.ordinal)"
        Assert-Cap2TestCas -EvidenceRoot $mainCase.evidence_root `
            -Sha256 ([string]$receipt.stdout_sha256) `
            -ByteLength ([long]$receipt.stdout_byte_length) `
            -Label "stdout $($indexEntry.ordinal)"
        Assert-Cap2TestCas -EvidenceRoot $mainCase.evidence_root `
            -Sha256 ([string]$receipt.stderr_sha256) `
            -ByteLength ([long]$receipt.stderr_byte_length) `
            -Label "stderr $($indexEntry.ordinal)"
    }
    $profileSha = "sha256:" + (
        Get-FileHash -LiteralPath $profilePath -Algorithm SHA256
    ).Hash.ToLowerInvariant()
    Assert-Cap2TestCas -EvidenceRoot $mainCase.evidence_root `
        -Sha256 $profileSha -ByteLength (Get-Item $profilePath).Length `
        -Label "final profile"

    $completedResume = Invoke-Cap2TestProfiler `
        -EvidenceRoot $mainCase.evidence_root `
        -InventoryOverride $testInventoryPath `
        -ResumeRunId $mainCase.run_id
    Assert-Cap2Test (
        [int]$completedResume.exit_code -ne 0 -and
        $completedResume.text.Contains(
            "completed run cannot be resumed",
            [StringComparison]::Ordinal
        )
    ) "completed profile accepted another resume"

    $manifestCase = Start-Cap2InterruptedCase `
        -EvidenceRoot (Join-Path $testRoot "manifest-corrupt")
    [IO.File]::AppendAllText(
        (Join-Path $manifestCase.run_root "run_manifest.json"),
        " ",
        [Text.UTF8Encoding]::new($false)
    )
    $manifestCorrupt = Invoke-Cap2TestProfiler `
        -EvidenceRoot $manifestCase.evidence_root `
        -InventoryOverride $testInventoryPath `
        -ResumeRunId $manifestCase.run_id
    Assert-Cap2Test (
        [int]$manifestCorrupt.exit_code -ne 0 -and
        $manifestCorrupt.text.Contains(
            "run manifest CAS verification failed",
            [StringComparison]::Ordinal
        )
    ) "manifest byte corruption was accepted"

    $receiptCase = Start-Cap2InterruptedCase `
        -EvidenceRoot (Join-Path $testRoot "receipt-corrupt")
    [IO.File]::AppendAllText(
        $receiptCase.receipt_path,
        " ",
        [Text.UTF8Encoding]::new($false)
    )
    $receiptCorrupt = Invoke-Cap2TestProfiler `
        -EvidenceRoot $receiptCase.evidence_root `
        -InventoryOverride $testInventoryPath `
        -ResumeRunId $receiptCase.run_id
    Assert-Cap2Test (
        [int]$receiptCorrupt.exit_code -ne 0 -and
        $receiptCorrupt.text.Contains(
            "receipt ordinal 1 CAS verification failed",
            [StringComparison]::Ordinal
        )
    ) "receipt byte corruption was accepted"

    $payloadCase = Start-Cap2InterruptedCase `
        -EvidenceRoot (Join-Path $testRoot "payload-corrupt")
    $payloadReceipt = Get-Content -LiteralPath $payloadCase.receipt_path -Raw |
        ConvertFrom-Json -AsHashtable -Depth 32
    $payloadPath = Join-Path $payloadCase.evidence_root (
        "artifacts\sha256\" +
        ([string]$payloadReceipt.stdout_sha256).Substring(7) +
        "\payload.bin"
    )
    $payloadBytes = [IO.File]::ReadAllBytes($payloadPath)
    Assert-Cap2Test ($payloadBytes.Length -gt 0) "stdout payload was unexpectedly empty"
    $payloadBytes[0] = $payloadBytes[0] -bxor 1
    [IO.File]::WriteAllBytes($payloadPath, $payloadBytes)
    $payloadCorrupt = Invoke-Cap2TestProfiler `
        -EvidenceRoot $payloadCase.evidence_root `
        -InventoryOverride $testInventoryPath `
        -ResumeRunId $payloadCase.run_id
    Assert-Cap2Test (
        [int]$payloadCorrupt.exit_code -ne 0 -and
        $payloadCorrupt.text.Contains(
            "stdout ordinal 1 CAS verification failed",
            [StringComparison]::Ordinal
        )
    ) "stdout payload corruption was accepted"

    $gapCase = Start-Cap2InterruptedCase `
        -EvidenceRoot (Join-Path $testRoot "receipt-gap")
    [IO.File]::Move(
        $gapCase.receipt_path,
        (Join-Path $gapCase.run_root "receipts\002.json")
    )
    $gapResume = Invoke-Cap2TestProfiler `
        -EvidenceRoot $gapCase.evidence_root `
        -InventoryOverride $testInventoryPath `
        -ResumeRunId $gapCase.run_id
    Assert-Cap2Test (
        [int]$gapResume.exit_code -ne 0 -and
        $gapResume.text.Contains(
            "receipt prefix is not contiguous at ordinal 1",
            [StringComparison]::Ordinal
        )
    ) "receipt ordinal gap was accepted"

    Write-Output (
        "CONFORMANCE_AUDIT_PROFILER_RESUME_PASS selected=2 interrupted=1 " +
        "resumed=1 resume_invocations=1 first_receipt_unchanged=True " +
        "manifest_cas=True receipt_cas=True output_cas=True profile_cas=True " +
        "environment_mutation=True selection_order_mutation=True " +
        "concurrent_lease=True manifest_corruption=True receipt_corruption=True " +
        "payload_corruption=True receipt_gap=True completed_resume=True " +
        "pending_non_authoritative=True cache=disabled worlds=0 " +
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
            (Split-Path -Leaf $resolved) -notlike 'sporespore-cap2-test-*') {
            throw "Refusing unsafe CAP2 test cleanup: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
