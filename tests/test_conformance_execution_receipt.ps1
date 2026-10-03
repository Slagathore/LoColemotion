#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$modulePath = Join-Path $repoRoot "sdk\conformance_execution_receipt.ps1"
$runnerPath = Join-Path $repoRoot (
    "sdk\run_conformance_execution_receipt_commissioning.ps1"
)
$canonicalRunnerPath = Join-Path $repoRoot "sdk\run_conformance.ps1"

function Assert-ExecutionReceipt {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw "Conformance execution-receipt test failed: $Message" }
}

foreach ($path in @($modulePath, $runnerPath, $canonicalRunnerPath)) {
    Assert-ExecutionReceipt (Test-Path -LiteralPath $path -PathType Leaf) (
        "missing source: $path"
    )
}
. $modulePath

$contract = Get-SporeSporeConformanceExecutionReceiptContract
$runnerSource = Get-Content -LiteralPath $runnerPath -Raw
$canonicalRunnerSource = Get-Content -LiteralPath $canonicalRunnerPath -Raw
Assert-ExecutionReceipt (
    [string]$contract.status -ceq
        "prospective_one_audit_cold_equivalence_uncommissioned" -and
    @($contract.candidate_audits).Count -eq 1 -and
    [string]$contract.candidate_audits[0].audit_path -ceq
        "tests/test_qsdk_r23d13_closure.ps1" -and
    [int]$contract.candidate_audits[0].worlds_opened_by_audit -eq 0 -and
    -not [bool]$contract.claims.cold_equivalence_complete -and
    -not [bool]$contract.claims.production_cache_lookup_permitted -and
    -not [bool]$contract.claims.production_result_reuse_permitted -and
    -not [bool]$contract.claims.historical_audit_waiver_permitted -and
    -not [bool]$contract.claims.physical_execution_authorized -and
    -not [bool]$contract.claims.scientific_authority -and
    -not [bool]$contract.claims.release_authority -and
    $runnerSource.Contains('if ($Mode -ceq "Execute")') -and
    $runnerSource.Contains("audit_invocation_count = 0") -and
    $runnerSource.Contains("Read-SporeSporeConformanceExecutionCandidate") -and
    $canonicalRunnerSource.Contains(
        "tests\test_conformance_execution_receipt.ps1",
        [StringComparison]::Ordinal
    )
) "CER1 contract or canonical routing changed"

$input = Get-SporeSporeConformanceExecutionInputCandidate `
    -RepoRoot $repoRoot `
    -TestOnly
Assert-ExecutionReceipt (
    [string]$input.schema_version -ceq
        "sporespore_conformance_execution_input_candidate_v1" -and
    [string]$input.status -ceq "complete_candidate_reuse_uncommissioned" -and
    [string]$input.audit_path -ceq "tests/test_qsdk_r23d13_closure.ps1" -and
    [string]$input.input_key_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
    [int]$input.implementation_file_count -eq 11 -and
    [int]$input.process_environment_name_count -gt 0 -and
    [bool]$input.complete -and
    -not [bool]$input.production_cache_lookup_permitted -and
    -not [bool]$input.production_result_reuse_permitted -and
    -not [bool]$input.physical_authority -and
    -not [bool]$input.release_authority -and
    -not ([string]$input.input_key_sha256).Contains(
        [IO.Path]::GetFullPath($repoRoot),
        [StringComparison]::OrdinalIgnoreCase
    )
) "live CER1 input candidate changed"

$environmentProbeName = "SPORESPORE_CER1_TEST_" + [guid]::NewGuid().ToString("N")
$priorEnvironmentProbe = [Environment]::GetEnvironmentVariable(
    $environmentProbeName,
    [EnvironmentVariableTarget]::Process
)
try {
    [Environment]::SetEnvironmentVariable(
        $environmentProbeName,
        "mutated",
        [EnvironmentVariableTarget]::Process
    )
    $environmentMutated = Get-SporeSporeConformanceExecutionInputCandidate `
        -RepoRoot $repoRoot `
        -TestOnly
    Assert-ExecutionReceipt (
        [string]$environmentMutated.input_key_sha256 -cne
            [string]$input.input_key_sha256
    ) "complete process-environment mutation did not invalidate the input key"
} finally {
    [Environment]::SetEnvironmentVariable(
        $environmentProbeName,
        $priorEnvironmentProbe,
        [EnvironmentVariableTarget]::Process
    )
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) (
    "sporespore-cer1-test-" + [guid]::NewGuid().ToString("N")
)
[void][IO.Directory]::CreateDirectory($testRoot)

function New-Cer1CaseRoot {
    param([string]$Name)
    $path = Join-Path $testRoot $Name
    [void][IO.Directory]::CreateDirectory($path)
    return $path
}

$marker = (
    "QSDK_R23D13_CLOSURE_PASS status=valid-none worlds=2 " +
    "successor_authorized=False physical_authority=False"
)
$stdout = "setup`r`n$marker`r`n"
$stderr = ""

try {
    $successRoot = New-Cer1CaseRoot "success"
    $publication = Publish-SporeSporeConformanceExecutionCandidate `
        -RepoRoot $repoRoot `
        -InputCandidate $input `
        -ExitCode 0 `
        -Stdout $stdout `
        -Stderr $stderr `
        -EvidenceRootOverride $successRoot `
        -TestOnly
    $readBack = Read-SporeSporeConformanceExecutionCandidate `
        -RepoRoot $repoRoot `
        -ExpectedInputKeySha256 ([string]$input.input_key_sha256) `
        -EvidenceRootOverride $successRoot `
        -TestOnly
    Assert-ExecutionReceipt (
        [string]$publication.record_sha256 -cmatch '^sha256:[0-9a-f]{64}$' -and
        [string]$publication.result_projection_sha256 -ceq
            [string]$readBack.result_projection_sha256 -and
        [string]$readBack.status -ceq
            "verified_read_back_not_production_reuse" -and
        [string]$readBack.stdout -ceq "setup`n$marker`n" -and
        [string]$readBack.stderr -ceq "" -and
        [int]$readBack.audit_invocation_count -eq 0 -and
        -not [bool]$readBack.cold_equivalence_complete -and
        -not [bool]$readBack.production_cache_lookup_permitted -and
        -not [bool]$readBack.production_result_reuse_permitted -and
        -not [bool]$readBack.physical_authority -and
        -not [bool]$readBack.release_authority
    ) "executed candidate and verified read-back projection differ"

    $duplicateRejected = $false
    try {
        [void](Publish-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -InputCandidate $input `
            -ExitCode 0 `
            -Stdout ("$marker`nchanged`n") `
            -Stderr "" `
            -EvidenceRootOverride $successRoot `
            -TestOnly)
    } catch { $duplicateRejected = $true }
    Assert-ExecutionReceipt $duplicateRejected `
        "same input key accepted a second candidate publication"

    $wrongKeyRejected = $false
    try {
        [void](Read-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -ExpectedInputKeySha256 ("sha256:" + ("0" * 64)) `
            -EvidenceRootOverride $successRoot `
            -TestOnly)
    } catch { $wrongKeyRejected = $true }
    Assert-ExecutionReceipt $wrongKeyRejected "input-key mutation was accepted"

    $failedExitRejected = $false
    try {
        [void](Publish-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -InputCandidate $input `
            -ExitCode 17 `
            -Stdout $stdout `
            -Stderr "failed" `
            -EvidenceRootOverride (New-Cer1CaseRoot "failed-exit") `
            -TestOnly)
    } catch { $failedExitRejected = $true }
    Assert-ExecutionReceipt $failedExitRejected `
        "failed execution was accepted for candidate publication"

    $duplicateMarkerRejected = $false
    try {
        [void](Publish-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -InputCandidate $input `
            -ExitCode 0 `
            -Stdout ("$marker`n$marker`n") `
            -Stderr "" `
            -EvidenceRootOverride (New-Cer1CaseRoot "duplicate-marker") `
            -TestOnly)
    } catch { $duplicateMarkerRejected = $true }
    Assert-ExecutionReceipt $duplicateMarkerRejected `
        "duplicate terminal marker was accepted"

    $recordCorruptRoot = New-Cer1CaseRoot "record-corrupt"
    $recordCorruptPublication = Publish-SporeSporeConformanceExecutionCandidate `
        -RepoRoot $repoRoot -InputCandidate $input -ExitCode 0 `
        -Stdout $stdout -Stderr "" -EvidenceRootOverride $recordCorruptRoot `
        -TestOnly
    [IO.File]::WriteAllBytes(
        [string]$recordCorruptPublication.record_path,
        [Text.UTF8Encoding]::new($false).GetBytes("{}`n")
    )
    $recordCorruptionRejected = $false
    try {
        [void](Read-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -ExpectedInputKeySha256 ([string]$input.input_key_sha256) `
            -EvidenceRootOverride $recordCorruptRoot `
            -TestOnly)
    } catch { $recordCorruptionRejected = $true }
    Assert-ExecutionReceipt $recordCorruptionRejected `
        "candidate record byte corruption was accepted"

    $payloadCorruptRoot = New-Cer1CaseRoot "payload-corrupt"
    $payloadCorruptPublication = Publish-SporeSporeConformanceExecutionCandidate `
        -RepoRoot $repoRoot -InputCandidate $input -ExitCode 0 `
        -Stdout $stdout -Stderr "" -EvidenceRootOverride $payloadCorruptRoot `
        -TestOnly
    $stdoutPayload = Join-Path $payloadCorruptRoot (
        "artifacts\sha256\" +
        ([string]$payloadCorruptPublication.stdout_sha256).Substring(7) +
        "\payload.bin"
    )
    $payloadBytes = [IO.File]::ReadAllBytes($stdoutPayload)
    $payloadBytes[0] = $payloadBytes[0] -bxor 1
    [IO.File]::WriteAllBytes($stdoutPayload, $payloadBytes)
    $payloadCorruptionRejected = $false
    try {
        [void](Read-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -ExpectedInputKeySha256 ([string]$input.input_key_sha256) `
            -EvidenceRootOverride $payloadCorruptRoot `
            -TestOnly)
    } catch { $payloadCorruptionRejected = $true }
    Assert-ExecutionReceipt $payloadCorruptionRejected `
        "output payload byte corruption was accepted"

    $payloadMissingRoot = New-Cer1CaseRoot "payload-missing"
    $payloadMissingPublication = Publish-SporeSporeConformanceExecutionCandidate `
        -RepoRoot $repoRoot -InputCandidate $input -ExitCode 0 `
        -Stdout $stdout -Stderr "" -EvidenceRootOverride $payloadMissingRoot `
        -TestOnly
    $missingStdoutPayload = Join-Path $payloadMissingRoot (
        "artifacts\sha256\" +
        ([string]$payloadMissingPublication.stdout_sha256).Substring(7) +
        "\payload.bin"
    )
    Remove-Item -LiteralPath $missingStdoutPayload -Force
    $missingPayloadRejected = $false
    try {
        [void](Read-SporeSporeConformanceExecutionCandidate `
            -RepoRoot $repoRoot `
            -ExpectedInputKeySha256 ([string]$input.input_key_sha256) `
            -EvidenceRootOverride $payloadMissingRoot `
            -TestOnly)
    } catch { $missingPayloadRejected = $true }
    Assert-ExecutionReceipt $missingPayloadRejected `
        "missing output payload was accepted"

    # Exercise the actual wrapper boundary in two distinct PowerShell
    # processes. Execute runs the already-closed audit exactly once; ReadBack
    # has no process-launch branch and must reproduce the same input/result
    # projections with an invocation count of zero.
    $routeRoot = New-Cer1CaseRoot "two-process-route"
    $pwsh = (Get-Command pwsh -CommandType Application -ErrorAction Stop |
        Select-Object -First 1).Source
    $executedOutput = @(& $pwsh `
        -NoLogo `
        -NoProfile `
        -File $runnerPath `
        -Mode Execute `
        -EvidenceRootOverride $routeRoot `
        -TestOnly `
        2>&1)
    $executedExitCode = $LASTEXITCODE
    Assert-ExecutionReceipt ($executedExitCode -eq 0) (
        "two-process execute route failed: " + ($executedOutput -join " ")
    )
    $readBackOutput = @(& $pwsh `
        -NoLogo `
        -NoProfile `
        -File $runnerPath `
        -Mode ReadBack `
        -EvidenceRootOverride $routeRoot `
        -TestOnly `
        2>&1)
    $readBackExitCode = $LASTEXITCODE
    Assert-ExecutionReceipt ($readBackExitCode -eq 0) (
        "two-process read-back route failed: " + ($readBackOutput -join " ")
    )
    $executedSummaryLine = [string]@($executedOutput | Where-Object {
        ([string]$_).StartsWith(
            "CONFORMANCE_EXECUTION_CANDIDATE_EXECUTED ",
            [StringComparison]::Ordinal
        )
    })[-1]
    $readBackSummaryLine = [string]@($readBackOutput | Where-Object {
        ([string]$_).StartsWith(
            "CONFORMANCE_EXECUTION_CANDIDATE_READBACK ",
            [StringComparison]::Ordinal
        )
    })[-1]
    Assert-ExecutionReceipt (
        -not [string]::IsNullOrWhiteSpace($executedSummaryLine) -and
        -not [string]::IsNullOrWhiteSpace($readBackSummaryLine)
    ) "two-process route omitted its compact summaries"
    $executedSummary = $executedSummaryLine.Substring(
        "CONFORMANCE_EXECUTION_CANDIDATE_EXECUTED ".Length
    ) | ConvertFrom-Json -AsHashtable -Depth 16
    $readBackSummary = $readBackSummaryLine.Substring(
        "CONFORMANCE_EXECUTION_CANDIDATE_READBACK ".Length
    ) | ConvertFrom-Json -AsHashtable -Depth 16
    Assert-ExecutionReceipt (
        [string]$executedSummary.input_key_sha256 -ceq
            [string]$readBackSummary.input_key_sha256 -and
        [string]$executedSummary.result_projection_sha256 -ceq
            [string]$readBackSummary.result_projection_sha256 -and
        [int]$executedSummary.audit_invocation_count -eq 1 -and
        [int]$readBackSummary.audit_invocation_count -eq 0 -and
        -not [bool]$executedSummary.cold_equivalence_complete -and
        -not [bool]$readBackSummary.cold_equivalence_complete -and
        -not [bool]$executedSummary.production_result_reuse_permitted -and
        -not [bool]$readBackSummary.production_result_reuse_permitted -and
        -not [bool]$executedSummary.physical_authority -and
        -not [bool]$readBackSummary.physical_authority -and
        -not [bool]$executedSummary.release_authority -and
        -not [bool]$readBackSummary.release_authority
    ) "two-process execute/read-back projections differ"

    Write-Output (
        "CONFORMANCE_EXECUTION_RECEIPT_PASS audits=1 input_complete=True " +
        "implementation_files=11 environment_invalidation=True " +
        "canonical_lf=True two_process_route=True execute_invocations=1 " +
        "readback_invocations=0 projection_equal=True " +
        "key_mutation=True record_corruption=True payload_corruption=True " +
        "payload_missing=True failed_exit=True duplicate_marker=True " +
        "same_key_refusal=True cold_equivalence=False cache=disabled " +
        "worlds=0 physical_authority=False release_authority=False"
    )
} finally {
    if (Test-Path -LiteralPath $testRoot) {
        $resolved = [IO.Path]::GetFullPath($testRoot)
        $temp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/')
        if (-not $resolved.StartsWith(
                $temp + [IO.Path]::DirectorySeparatorChar,
                [StringComparison]::OrdinalIgnoreCase
            ) -or
            (Split-Path -Leaf $resolved) -notlike 'sporespore-cer1-test-*') {
            throw "Refusing unsafe CER1 test cleanup: $resolved"
        }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
