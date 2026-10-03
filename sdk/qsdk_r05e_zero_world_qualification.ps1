#requires -Version 7.0

<#
Consume and retain one official QSDK-R05E zero-world qualification identity.

This wrapper never authorizes or executes physics. It requires clean source
equal to cached and live main, creates a durable source/campaign claim before
launching the audit, and retains the exact attempt, stdout, stderr, parsed
receipt, and terminal completion record outside the repository.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet(
        "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST",
        "QSDK-R05E-EXACT-FINITE-MORPHOLOGY-VALIDATION"
    )]
    [string]$CampaignId,
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$auditPath = Join-Path $sdkRoot "conformance\qsdk_r05e_zero_world_implementation.py"
$godotPath = [IO.Path]::GetFullPath($Godot)
$evidenceRoot = [IO.Path]::GetFullPath((
    Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence"
))
$receiptPrefix = "QSDK_R05E_ZERO_WORLD_IMPLEMENTATION_PASS "
$mutexName = "Global\SporeSpore.QSDK.R05E.ZeroWorldQualification.Serial.v1"
$auditTimeoutSeconds = 1800

$campaign = if ($CampaignId -ceq "QSDK-R05E-DEVELOPMENT-ROUTE-GHOST") {
    [ordered]@{
        slug = "development-route-ghost"
        gate_id = "QSDK-R05E-GHOST"
        question_class = "development"
        qualification_closure_relative_path = (
            "sdk/qsdk_r05e_development_route_ghost_" +
            "zero_world_qualification_closure_v1.json"
        )
        execution_authority_relative_path = (
            "sdk/qsdk_r05e_development_route_ghost_execution_authority.json"
        )
        prerequisite_path = ""
    }
} else {
    [ordered]@{
        slug = "exact-finite-morphology"
        gate_id = "QSDK-R05E"
        question_class = "finite decision"
        qualification_closure_relative_path = (
            "sdk/qsdk_r05e_exact_finite_morphology_" +
            "zero_world_qualification_closure_v1.json"
        )
        execution_authority_relative_path = (
            "sdk/qsdk_r05e_exact_finite_execution_authority.json"
        )
        prerequisite_path = (
            "sdk/qsdk_r05e_development_route_ghost_physical_closure_v1.json"
        )
    }
}

function Write-R05EUtf8CreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $parent = Split-Path -Parent $Path
    [void][IO.Directory]::CreateDirectory($parent)
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

function Write-R05EJsonCreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)]$Value
    )
    Write-R05EUtf8CreateNew `
        -Path $Path `
        -Text (($Value | ConvertTo-Json -Depth 100) + "`n")
}

function Get-R05ERawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:$((Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant())"
}

function Invoke-R05EGitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    if ($LASTEXITCODE -ne 0) {
        throw "QSDK_R05E_QUALIFICATION_GIT_$Label"
    }
    $value = (($lines | ForEach-Object { [string]$_ }) -join "`n").Trim()
    if (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($value)) {
        throw "QSDK_R05E_QUALIFICATION_GIT_${Label}_EMPTY"
    }
    return $value
}

$qualificationMutex = [Threading.Mutex]::new($false, $mutexName)
$mutexAcquired = $false
$outputDirectory = ""
$completionPath = ""
$startedUtc = [DateTime]::UtcNow.ToString("o")
try {
    try {
        $mutexAcquired = $qualificationMutex.WaitOne(0)
    } catch [Threading.AbandonedMutexException] {
        $mutexAcquired = $true
        throw "QSDK_R05E_QUALIFICATION_ABANDONED_OWNER"
    }
    if (-not $mutexAcquired) {
        throw "QSDK_R05E_QUALIFICATION_ALREADY_RUNNING"
    }
    if ($repoRoot -cne $expectedRoot) {
        throw "QSDK_R05E_QUALIFICATION_WRONG_ROOT"
    }
    if (-not (Test-Path -LiteralPath $auditPath -PathType Leaf)) {
        throw "QSDK_R05E_QUALIFICATION_AUDIT_MISSING"
    }
    if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
        throw "QSDK_R05E_QUALIFICATION_GODOT_MISSING"
    }
    if (-not (Test-Path -LiteralPath $evidenceRoot -PathType Container)) {
        throw "QSDK_R05E_QUALIFICATION_EVIDENCE_ROOT_MISSING"
    }

    $remote = Invoke-R05EGitText -Arguments @("remote", "get-url", "origin") `
        -Label "REMOTE"
    $branch = Invoke-R05EGitText -Arguments @("branch", "--show-current") `
        -Label "BRANCH"
    $head = Invoke-R05EGitText -Arguments @("rev-parse", "HEAD") -Label "HEAD"
    $originMain = Invoke-R05EGitText `
        -Arguments @("rev-parse", "origin/main") `
        -Label "ORIGIN_MAIN"
    $status = Invoke-R05EGitText `
        -Arguments @("status", "--porcelain=v1", "--untracked-files=all") `
        -Label "STATUS" `
        -AllowEmpty
    $liveRecord = Invoke-R05EGitText `
        -Arguments @("ls-remote", "origin", "refs/heads/main") `
        -Label "LIVE_MAIN"
    $liveParts = @($liveRecord -split "\s+" | Where-Object { $_ })
    if (
        $remote -cne $expectedRemote -or
        $branch -cne "main" -or
        -not [string]::IsNullOrEmpty($status) -or
        $head -cne $originMain -or
        $liveParts.Count -ne 2 -or
        [string]$liveParts[0] -cne $head -or
        [string]$liveParts[1] -cne "refs/heads/main"
    ) {
        throw "QSDK_R05E_QUALIFICATION_SOURCE_NOT_CLEAN_LIVE_EQUAL"
    }
    foreach ($relative in @(
        [string]$campaign.qualification_closure_relative_path,
        [string]$campaign.execution_authority_relative_path
    )) {
        if (Test-Path -LiteralPath (Join-Path $repoRoot $relative)) {
            throw "QSDK_R05E_QUALIFICATION_TARGET_ALREADY_EXISTS:$relative"
        }
    }
    if (
        -not [string]::IsNullOrWhiteSpace([string]$campaign.prerequisite_path) -and
        -not (Test-Path -LiteralPath (
            Join-Path $repoRoot ([string]$campaign.prerequisite_path)
        ) -PathType Leaf)
    ) {
        throw "QSDK_R05E_QUALIFICATION_PREREQUISITE_MISSING"
    }

    $pythonCommands = @(
        Get-Command -Name "python" -CommandType Application -ErrorAction Stop
    )
    if ($pythonCommands.Count -lt 1) {
        throw "QSDK_R05E_QUALIFICATION_PYTHON_MISSING"
    }
    $pythonPath = [string](
        Get-Item -LiteralPath ([string]$pythonCommands[0].Source)
    ).FullName
    $timestamp = [DateTime]::UtcNow.ToString("yyyyMMddTHHmmssfffZ")
    $outputDirectory = Join-Path $evidenceRoot (
        "qsdk-r05e-$([string]$campaign.slug)-zero-world-qualification-" +
        "$timestamp-$($head.Substring(0, 8))"
    )
    $claimsDirectory = Join-Path $evidenceRoot (
        "qsdk-r05e-zero-world-qualification-claims"
    )
    [void][IO.Directory]::CreateDirectory($claimsDirectory)
    $claimPath = Join-Path $claimsDirectory (
        "$([string]$campaign.slug)-$head.json"
    )
    $claim = [ordered]@{
        schema_version = "sporespore_qsdk_r05e_zero_world_qualification_claim_v1"
        status = "consumed_before_audit_launch"
        campaign_id = $CampaignId
        gate_id = [string]$campaign.gate_id
        question_class = [string]$campaign.question_class
        source_commit = $head
        output_directory = $outputDirectory.Replace("\", "/")
        started_utc = $startedUtc
        maximum_official_qualification_attempt_count_for_source = 1
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R05EJsonCreateNew -Path $claimPath -Value $claim
    [void][IO.Directory]::CreateDirectory($outputDirectory)

    $attemptPath = Join-Path $outputDirectory "qualification_attempt.json"
    $stdoutPath = Join-Path $outputDirectory "qualification_stdout.log"
    $stderrPath = Join-Path $outputDirectory "qualification_stderr.log"
    $receiptPath = Join-Path $outputDirectory "qualification_receipt.json"
    $completionPath = Join-Path $outputDirectory "qualification_completion.json"
    Write-R05EJsonCreateNew -Path $attemptPath -Value ([ordered]@{
        schema_version = "sporespore_qsdk_r05e_zero_world_qualification_attempt_v1"
        status = "started_consumed"
        campaign_id = $CampaignId
        gate_id = [string]$campaign.gate_id
        question_class = [string]$campaign.question_class
        source_commit = $head
        branch = $branch
        remote = $remote
        origin_main_commit = $originMain
        live_main_commit = [string]$liveParts[0]
        godot_path = $godotPath.Replace("\", "/")
        python_path = $pythonPath.Replace("\", "/")
        started_utc = $startedUtc
        official_qualification = $true
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    })

    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $pythonPath
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in @(
        "-B", $auditPath, "--godot", $godotPath, "--official-qualification"
    )) {
        [void]$start.ArgumentList.Add([string]$argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    if (-not $process.Start()) {
        throw "QSDK_R05E_QUALIFICATION_AUDIT_PROCESS_NOT_STARTED"
    }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $auditTimedOut = -not $process.WaitForExit($auditTimeoutSeconds * 1000)
    if ($auditTimedOut) {
        try {
            $process.Kill($true)
        } catch {
        }
        [void]$process.WaitForExit(10000)
    }
    if (-not $process.HasExited) {
        $process.Dispose()
        throw "QSDK_R05E_QUALIFICATION_AUDIT_PROCESS_TREE_NOT_TERMINATED"
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = $process.ExitCode
    $process.Dispose()
    Write-R05EUtf8CreateNew -Path $stdoutPath -Text $stdout
    Write-R05EUtf8CreateNew -Path $stderrPath -Text $stderr
    if ($auditTimedOut) {
        throw "QSDK_R05E_QUALIFICATION_AUDIT_TIMEOUT"
    }
    if ($exitCode -ne 0) {
        throw "QSDK_R05E_QUALIFICATION_AUDIT_FAILED:$exitCode"
    }
    $receiptLines = @(
        $stdout -split "\r?\n" |
            Where-Object { $_.StartsWith($receiptPrefix, [StringComparison]::Ordinal) }
    )
    if ($receiptLines.Count -ne 1) {
        throw "QSDK_R05E_QUALIFICATION_RECEIPT_COUNT"
    }
    try {
        $receipt = $receiptLines[0].Substring($receiptPrefix.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw "QSDK_R05E_QUALIFICATION_RECEIPT_JSON"
    }
    if (
        $receipt -isnot [System.Collections.IDictionary] -or
        [string]$receipt.schema_version -cne
            "sporespore_qsdk_r05e_zero_world_implementation_audit_v1" -or
        -not [bool]$receipt.ok -or
        -not [bool]$receipt.official_qualification_mode -or
        [string]$receipt.source_commit -cne $head -or
        [string]$receipt.branch -cne "main" -or
        -not [bool]$receipt.worktree_clean -or
        -not [bool]$receipt.head_origin_main_equal -or
        -not [bool]$receipt.head_live_remote_main_equal -or
        -not [bool]$receipt.dependency_all_qualified_paths_lf_checkout_policy -or
        -not [bool]$receipt.dependency_all_qualified_paths_tracked -or
        -not [bool]$receipt.dependency_tracked_source_required -or
        [int]$receipt.model_construction_count -ne 0 -or
        [int]$receipt.world_attempt_count -ne 0 -or
        [int]$receipt.world_build_count -ne 0 -or
        [int]$receipt.native_readback_count -ne 0 -or
        [int]$receipt.solver_step_count -ne 0 -or
        [bool]$receipt.physics_state_modified -or
        [bool]$receipt.physical_execution_authorized -or
        [bool]$receipt.physical_acceptance_authority -or
        [bool]$receipt.release_authority
    ) {
        throw "QSDK_R05E_QUALIFICATION_RECEIPT_RECONCILIATION"
    }

    $endRemote = Invoke-R05EGitText `
        -Arguments @("remote", "get-url", "origin") `
        -Label "END_REMOTE"
    $endBranch = Invoke-R05EGitText `
        -Arguments @("branch", "--show-current") `
        -Label "END_BRANCH"
    $endHead = Invoke-R05EGitText `
        -Arguments @("rev-parse", "HEAD") `
        -Label "END_HEAD"
    $endOriginMain = Invoke-R05EGitText `
        -Arguments @("rev-parse", "origin/main") `
        -Label "END_ORIGIN_MAIN"
    $endStatus = Invoke-R05EGitText `
        -Arguments @("status", "--porcelain=v1", "--untracked-files=all") `
        -Label "END_STATUS" `
        -AllowEmpty
    $endLiveRecord = Invoke-R05EGitText `
        -Arguments @("ls-remote", "origin", "refs/heads/main") `
        -Label "END_LIVE_MAIN"
    $endLiveParts = @($endLiveRecord -split "\s+" | Where-Object { $_ })
    if (
        $endRemote -cne $remote -or
        $endBranch -cne $branch -or
        $endHead -cne $head -or
        $endOriginMain -cne $head -or
        -not [string]::IsNullOrEmpty($endStatus) -or
        $endLiveParts.Count -ne 2 -or
        [string]$endLiveParts[0] -cne $head -or
        [string]$endLiveParts[1] -cne "refs/heads/main"
    ) {
        throw "QSDK_R05E_QUALIFICATION_SOURCE_DRIFT_DURING_AUDIT"
    }
    Write-R05EJsonCreateNew -Path $receiptPath -Value $receipt
    $receiptSha256 = Get-R05ERawSha256 $receiptPath
    $receiptByteLength = [int64](Get-Item -LiteralPath $receiptPath).Length
    $completedUtc = [DateTime]::UtcNow.ToString("o")
    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r05e_zero_world_qualification_completion_v1"
        status = "complete_pass_zero_world_physics_still_sealed"
        campaign_id = $CampaignId
        gate_id = [string]$campaign.gate_id
        source_commit = $head
        started_utc = $startedUtc
        completed_utc = $completedUtc
        audit_exit_code = $exitCode
        qualification_receipt_path = $receiptPath.Replace("\", "/")
        qualification_receipt_sha256 = $receiptSha256
        qualification_receipt_byte_length = $receiptByteLength
        stdout_sha256 = Get-R05ERawSha256 $stdoutPath
        stderr_sha256 = Get-R05ERawSha256 $stderrPath
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-R05EJsonCreateNew -Path $completionPath -Value $completion
    Write-Output (
        "QSDK_R05E_OFFICIAL_QUALIFICATION_RETAINED " +
        ($completion | ConvertTo-Json -Compress -Depth 30)
    )
} catch {
    if (
        -not [string]::IsNullOrWhiteSpace($outputDirectory) -and
        (Test-Path -LiteralPath $outputDirectory -PathType Container) -and
        -not [string]::IsNullOrWhiteSpace($completionPath) -and
        -not (Test-Path -LiteralPath $completionPath)
    ) {
        Write-R05EJsonCreateNew -Path $completionPath -Value ([ordered]@{
            schema_version = "sporespore_qsdk_r05e_zero_world_qualification_completion_v1"
            status = "failed_retained_identity_consumed"
            campaign_id = $CampaignId
            gate_id = [string]$campaign.gate_id
            started_utc = $startedUtc
            completed_utc = [DateTime]::UtcNow.ToString("o")
            failure = $_.Exception.Message
            physical_execution_authorized = $false
            physical_acceptance_authority = $false
            release_authority = $false
        })
    }
    throw
} finally {
    if ($mutexAcquired) {
        try {
            $qualificationMutex.ReleaseMutex()
        } catch {
        }
    }
    $qualificationMutex.Dispose()
}
