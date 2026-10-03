#requires -Version 7.0

<#
Consume and retain one official QSDK-R10B zero-world qualification identity.

This wrapper never authorizes or executes physics. It requires a clean pushed
checkout equal to live main, creates a deterministic durable evidence directory
before launching the implementation audit, and retains the exact attempt,
stdout, stderr, parsed receipt, and terminal completion record. The directory
name is source-and-role bound, so a failed qualification cannot be retried under
a fresh timestamp while pretending to be the same attempt.
#>

[CmdletBinding()]
param(
    [ValidateSet("development_route_ghost", "held_out_finite_decision")]
    [string]$CampaignRole = "development_route_ghost",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [ValidateRange(60, 1800)]
    [int]$TimeoutSeconds = 600
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath("C:\Users\Cole\CodeStuff\games\SporeSpore")
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$evidenceRootPath = [IO.Path]::GetFullPath($EvidenceRoot)
$auditPath = Join-Path $PSScriptRoot "conformance\qsdk_r10b_zero_world_implementation.py"
$godotPath = [IO.Path]::GetFullPath($Godot)
$passMarker = "QSDK_R10B_ZERO_WORLD_IMPLEMENTATION_PASS "
$completionMarker = "QSDK_R10B_ZERO_WORLD_QUALIFICATION_COMPLETE "
$qualifiedSourcePathCount = 85
$qualifiedSourcePathSha256 = "sha256:4bfe0e8a7cbdb920655cb3082b6e2a7182f4f05ac76e24142a73acca640a7a8d"
$l2SuccessorDesignSha256 = "sha256:5acc66edbc274616898b25ede236207ff77ca92e596ffbf171472ca9dfc7a478"
$l3SuccessorDesignSha256 = "sha256:ad8d147ee5a508aee3104fb346dcedde692568a9f9093a73e3bdbca638901f76"
$consumedL1PhysicalInvalidClosureSha256 = "sha256:b9f8304e229d1a897137bafcce51ee6089b11b15742f624ccf38d202b8fe35a1"
$consumedL2PhysicalInvalidClosureSha256 = "sha256:5f6242e2cab9658a54c673717596c7649fac785136d29d8798192bfc0f60babb"
$campaign = if ($CampaignRole -ceq "development_route_ghost") {
    [ordered]@{
        id = "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        question_class = "development"
        ordered_cell_ids = @("baseline_s50300", "push_s50300")
        maximum_world_count = 2
    }
} else {
    [ordered]@{
        id = "QSDK-R10B-BOUNDED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
        question_class = "finite decision"
        ordered_cell_ids = @(
            "baseline_s50301", "push_s50301",
            "baseline_s50302", "push_s50302",
            "baseline_s50303", "push_s50303"
        )
        maximum_world_count = 6
    }
}
$mutexName = "Global\SporeSpore.QSDK.R10B.ZeroWorldQualification.$CampaignRole.v2"

function Write-Utf8CreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $stream = [IO.File]::Open(
        $Path,
        [IO.FileMode]::CreateNew,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $bytes = [Text.UTF8Encoding]::new($false).GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush($true)
    } finally {
        $stream.Dispose()
    }
}

function Write-JsonCreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    Write-Utf8CreateNew -Path $Path -Text (($Value | ConvertTo-Json -Depth 100) + "`n")
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) { throw "QSDK_R10B_QUALIFICATION_GIT_$Label" }
    $value = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) {
        throw "QSDK_R10B_QUALIFICATION_GIT_${Label}_EMPTY"
    }
    return $value
}

function Get-CleanPushedIdentity {
    $root = Get-GitText -Arguments @("rev-parse", "--show-toplevel") -Label "ROOT"
    $remote = Get-GitText -Arguments @("remote", "get-url", "origin") -Label "REMOTE"
    $branch = Get-GitText -Arguments @("branch", "--show-current") -Label "BRANCH"
    $head = Get-GitText -Arguments @("rev-parse", "HEAD") -Label "HEAD"
    $tree = Get-GitText -Arguments @("rev-parse", "HEAD^{tree}") -Label "TREE"
    $parent = Get-GitText -Arguments @("rev-parse", "HEAD^") -Label "PARENT"
    $origin = Get-GitText -Arguments @("rev-parse", "origin/main") -Label "ORIGIN_MAIN"
    $status = Get-GitText -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) -Label "STATUS" -AllowEmpty
    $liveLine = Get-GitText -Arguments @(
        "ls-remote", "origin", "refs/heads/main"
    ) -Label "LIVE_MAIN"
    $liveParts = @($liveLine -split "\s+" | Where-Object { $_ })
    if (
        [IO.Path]::GetFullPath($root) -cne $expectedRoot -or
        $repoRoot -cne $expectedRoot -or
        $remote -cne $expectedRemote -or
        $branch -cne "main" -or
        -not [string]::IsNullOrEmpty($status) -or
        $head -cne $origin -or
        $liveParts.Count -ne 2 -or
        [string]$liveParts[0] -cne $head -or
        [string]$liveParts[1] -cne "refs/heads/main"
    ) {
        throw "QSDK_R10B_QUALIFICATION_SOURCE_NOT_CLEAN_PUSHED_LIVE_MAIN"
    }
    return [ordered]@{
        root = $repoRoot
        remote = $remote
        branch = $branch
        commit = $head
        parent_commit = $parent
        tree = $tree
        origin_main_commit = $origin
        live_main_commit = [string]$liveParts[0]
        clean = $true
    }
}

function Invoke-PythonAudit {
    param([Parameter(Mandatory)][string]$PythonPath)
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $PythonPath
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-B", $auditPath, "--godot", $godotPath, "--official-qualification"
    )) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = [DateTime]::UtcNow
    if (-not $process.Start()) { throw "QSDK_R10B_QUALIFICATION_AUDIT_START_FAILED" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if ($timedOut) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        [void]$process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { $process.ExitCode } else { -1 }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        started_utc = $started.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
        stdout = $stdout
        stderr = $stderr
    }
}

$mutex = [Threading.Mutex]::new($false, $mutexName)
$mutexAcquired = $false
$outputPath = ""
try {
    try {
        $mutexAcquired = $mutex.WaitOne(0)
    } catch [Threading.AbandonedMutexException] {
        $mutexAcquired = $true
        throw "QSDK_R10B_QUALIFICATION_ABANDONED_OWNER"
    }
    if (-not $mutexAcquired) { throw "QSDK_R10B_QUALIFICATION_ALREADY_RUNNING" }
    if (-not (Test-Path -LiteralPath $auditPath -PathType Leaf)) {
        throw "QSDK_R10B_QUALIFICATION_AUDIT_MISSING"
    }
    if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
        throw "QSDK_R10B_QUALIFICATION_GODOT_MISSING"
    }
    if (-not (Test-Path -LiteralPath $evidenceRootPath -PathType Container)) {
        throw "QSDK_R10B_QUALIFICATION_EVIDENCE_ROOT_MISSING"
    }
    $python = (Get-Command python -ErrorAction Stop).Source
    $identityBefore = Get-CleanPushedIdentity
    $roleSlug = $CampaignRole.Replace("_", "-")
    $outputPath = Join-Path $evidenceRootPath (
        "qsdk-r10b-$roleSlug-zero-world-qualification-" +
        ([string]$identityBefore.commit).Substring(0, 12)
    )
    if (Test-Path -LiteralPath $outputPath) {
        throw "QSDK_R10B_QUALIFICATION_IDENTITY_ALREADY_CONSUMED"
    }
    [void][IO.Directory]::CreateDirectory($outputPath)

    $attemptPath = Join-Path $outputPath "qualification_attempt.json"
    $attempt = [ordered]@{
        schema_version = "sporespore_qsdk_r10b_zero_world_qualification_attempt_v4"
        gate_id = "QSDK-R10B"
        campaign_id = [string]$campaign.id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        ledger_scope = [ordered]@{
            subsystem = "recovery"
            engine_scope = "godot_jolt"
            authority_mode = "single_attempt_official_zero_world_qualification"
            question_class = [string]$campaign.question_class
        }
        source = $identityBefore
        qualified_source_path_count = $qualifiedSourcePathCount
        qualified_source_path_sha256 = $qualifiedSourcePathSha256
        l2_successor_design_sha256 = $l2SuccessorDesignSha256
        l3_successor_design_sha256 = $l3SuccessorDesignSha256
        consumed_l1_physical_invalid_closure_sha256 = `
            $consumedL1PhysicalInvalidClosureSha256
        consumed_l2_physical_invalid_closure_sha256 = `
            $consumedL2PhysicalInvalidClosureSha256
        ordered_cell_ids = @($campaign.ordered_cell_ids)
        maximum_world_count = [int]$campaign.maximum_world_count
        output_root = $outputPath
        official_qualification_attempt_count_for_source_and_role = 1
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew -Path $attemptPath -Value $attempt

    $execution = Invoke-PythonAudit -PythonPath $python
    $stdoutPath = Join-Path $outputPath "audit_stdout.log"
    $stderrPath = Join-Path $outputPath "audit_stderr.log"
    Write-Utf8CreateNew -Path $stdoutPath -Text ([string]$execution.stdout)
    Write-Utf8CreateNew -Path $stderrPath -Text ([string]$execution.stderr)
    if ([bool]$execution.timed_out -or [int]$execution.exit_code -ne 0) {
        throw "QSDK_R10B_QUALIFICATION_AUDIT_FAILED_OR_TIMED_OUT"
    }
    $markerLines = @(
        ([string]$execution.stdout -split "`r?`n") |
            Where-Object { $_.StartsWith($passMarker, [StringComparison]::Ordinal) }
    )
    if ($markerLines.Count -ne 1) {
        throw "QSDK_R10B_QUALIFICATION_PASS_MARKER_COUNT"
    }
    $receipt = $markerLines[0].Substring($passMarker.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
    if (
        [string]$receipt.schema_version -cne `
            "sporespore_qsdk_r10b_zero_world_implementation_audit_v4" -or
        -not [bool]$receipt.ok -or
        -not [bool]$receipt.official_qualification_mode -or
        -not [bool]$receipt.worktree_clean -or
        -not [bool]$receipt.head_origin_main_equal -or
        -not [bool]$receipt.head_live_remote_main_equal -or
        [string]$receipt.source_commit -cne [string]$identityBefore.commit -or
        [int]$receipt.qualified_source_path_count -ne $qualifiedSourcePathCount -or
        [string]$receipt.qualified_source_path_sha256 -cne $qualifiedSourcePathSha256 -or
        [string]$receipt.l2_successor_design_raw_sha256 -cne $l2SuccessorDesignSha256 -or
        -not [bool]$receipt.l2_successor_design_audit_passed -or
        [string]$receipt.l3_successor_design_raw_sha256 -cne $l3SuccessorDesignSha256 -or
        -not [bool]$receipt.l3_successor_design_audit_passed -or
        -not [bool]$receipt.l1_physical_identity_consumed -or
        [bool]$receipt.l1_same_identity_rerun_permitted -or
        [string]$receipt.l2_physical_invalid_closure_raw_sha256 -cne `
            $consumedL2PhysicalInvalidClosureSha256 -or
        -not [bool]$receipt.l2_physical_invalid_closure_audit_passed -or
        -not [bool]$receipt.l2_physical_identity_consumed -or
        [bool]$receipt.l2_same_identity_rerun_permitted -or
        [int]$receipt.l2_valid_behavior_result_count -ne 0 -or
        -not [bool]$receipt.l3_retained_trace_validation_passed -or
        [int]$receipt.l3_retained_trace_row_count -ne 2640 -or
        [int]$receipt.l3_projection_receipt_acceptance_count -ne 2640 -or
        [int]$receipt.l3_exported_axis_acceptance_count -ne 2640 -or
        [int]$receipt.l3_behavior_reclassification_count -ne 0 -or
        [int]$receipt.retained_raw_quaternion_refusal_count_per_source_gate -ne 2 -or
        [int]$receipt.retained_projected_quaternion_acceptance_count_per_source_gate -ne 2 -or
        [int]$receipt.additional_nonidentity_projected_acceptance_count_per_source_gate -ne 2 -or
        [int]$receipt.zero_quaternion_projection_refusal_count_per_source_gate -ne 1 -or
        [int]$receipt.projection_receipt_mutation_rejection_count_per_source_gate -ne 3 -or
        [int]$receipt.model_construction_count -ne 0 -or
        [int]$receipt.world_attempt_count -ne 0 -or
        [int]$receipt.world_build_count -ne 0 -or
        [int]$receipt.native_readback_count -ne 0 -or
        [int]$receipt.solver_step_count -ne 0 -or
        [bool]$receipt.physical_acceptance_authority -or
        [bool]$receipt.release_authority
    ) {
        throw "QSDK_R10B_QUALIFICATION_RECEIPT_INVALID"
    }
    $receiptPath = Join-Path $outputPath "qualification_receipt.json"
    Write-JsonCreateNew -Path $receiptPath -Value $receipt
    $identityAfter = Get-CleanPushedIdentity
    if ([string]$identityAfter.commit -cne [string]$identityBefore.commit) {
        throw "QSDK_R10B_QUALIFICATION_SOURCE_DRIFTED"
    }

    $completionPath = Join-Path $outputPath "qualification_completion.json"
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r10b_zero_world_qualification_completion_v4"
        gate_id = "QSDK-R10B"
        campaign_id = [string]$campaign.id
        campaign_role = $CampaignRole
        status = "complete_valid_official_zero_world_qualification"
        source = $identityAfter
        output_root = $outputPath
        attempt = [ordered]@{
            path = "qualification_attempt.json"
            byte_length = [int64](Get-Item -LiteralPath $attemptPath).Length
            raw_sha256 = Get-PrefixedSha256 $attemptPath
        }
        stdout = [ordered]@{
            path = "audit_stdout.log"
            byte_length = [int64](Get-Item -LiteralPath $stdoutPath).Length
            raw_sha256 = Get-PrefixedSha256 $stdoutPath
        }
        stderr = [ordered]@{
            path = "audit_stderr.log"
            byte_length = [int64](Get-Item -LiteralPath $stderrPath).Length
            raw_sha256 = Get-PrefixedSha256 $stderrPath
        }
        receipt = [ordered]@{
            path = "qualification_receipt.json"
            byte_length = [int64](Get-Item -LiteralPath $receiptPath).Length
            raw_sha256 = Get-PrefixedSha256 $receiptPath
        }
        official_zero_world_qualification_passed = $true
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew -Path $completionPath -Value $completion
    Write-Output (
        $completionMarker +
        ([ordered]@{
            output_root = $outputPath
            completion_path = $completionPath
            completion_sha256 = Get-PrefixedSha256 $completionPath
            source_commit = [string]$identityAfter.commit
            campaign_role = $CampaignRole
            physical_execution_authorized = $false
        } | ConvertTo-Json -Compress)
    )
} catch {
    if (
        -not [string]::IsNullOrWhiteSpace($outputPath) -and
        (Test-Path -LiteralPath $outputPath -PathType Container)
    ) {
        $failurePath = Join-Path $outputPath "qualification_failure.json"
        if (-not (Test-Path -LiteralPath $failurePath)) {
            Write-JsonCreateNew -Path $failurePath -Value ([ordered]@{
                schema_version = "sporespore_qsdk_r10b_zero_world_qualification_failure_v4"
                gate_id = "QSDK-R10B"
                campaign_role = $CampaignRole
                status = "consumed_invalid_or_incomplete_zero_world_qualification"
                failure = $_.Exception.Message
                completed_utc = [DateTime]::UtcNow.ToString("o")
                output_root = $outputPath
                physical_execution_authorized = $false
                physical_acceptance_authority = $false
                release_authority = $false
            })
        }
    }
    throw
} finally {
    if ($mutexAcquired) {
        $mutex.ReleaseMutex()
    }
    $mutex.Dispose()
}
