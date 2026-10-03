#requires -Version 7.0

<#
Consume and retain one official QSDK-R10D zero-world qualification identity.

This wrapper never authorizes or executes physics. It requires a clean pushed
checkout equal to live main, holds the repository-wide locomotion operation
lock for the entire audit, creates a deterministic durable evidence directory,
and retains the attempt, process output, parsed audit receipt, and completion.
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
    [int]$TimeoutSeconds = 1200
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$expectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$expectedRemote = "https://github.com/Slagathore/sporespore.git"
$expectedEvidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$evidenceRootPath = [IO.Path]::GetFullPath($EvidenceRoot)
$auditPath = Join-Path $PSScriptRoot (
    "conformance\qsdk_r10d_zero_world_implementation.py"
)
$operationLockPath = Join-Path $PSScriptRoot "locomotion_operation_lock.ps1"
$activeAdapterPath = Join-Path $PSScriptRoot (
    "target\debug\sporespore_godot_adapter.dll"
)
$godotPath = [IO.Path]::GetFullPath($Godot)
$passMarker = "QSDK_R10D_ZERO_WORLD_IMPLEMENTATION_PASS "
$completionMarker = "QSDK_R10D_ZERO_WORLD_QUALIFICATION_COMPLETE "
$qualificationSchema = (
    "sporespore_qsdk_r10d_zero_world_qualification_completion_v2"
)
$repairId = "QSDK-R10D-L1"
$qualifiedSourcePathCount = 88
$qualifiedSourcePathSha256 = (
    "sha256:fde0b22bd6fbe0a51a07949efeb93550db16bdb580de39f192192f4d63c897e2"
)
$r10cDesignSha256 = (
    "sha256:2f2a4f86562e3398d69fc08510c347ed1634a2331f45ce58651db7bbb8aae4a8"
)
$r10bHeldOutClosureSha256 = (
    "sha256:108473a00fb7d789862996b85e95ef255cc62b5e2c6037aecb556bd77dce625a"
)
$r05ePhysicalClosureSha256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
$r10dL1DesignSha256 = (
    "sha256:f98f9f057e6f583b6f0f356a983cdcbcb4d6818f217fe055edd96ddcbf326db3"
)
$consumedR10dPhysicalClosureSha256 = (
    "sha256:fbefa85145bcd5bb05c3672c4fe6a0b56eaf75751ae8ed5dae9ff724487b4475"
)
$campaign = if ($CampaignRole -ceq "development_route_ghost") {
    [ordered]@{
        id = (
            "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-" +
            "UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        )
        question_class = "development"
        role_slug = "development-route-ghost"
        ordered_cell_ids = @("baseline_s40001", "push_s40001")
        maximum_world_count = 2
    }
} else {
    [ordered]@{
        id = (
            "QSDK-R10D-SUPPORTED-START-PHASE-ROBUST-" +
            "UPRIGHT-PUSH-RECOVERY-VALIDATION"
        )
        question_class = "finite decision"
        role_slug = "held-out-finite-decision"
        ordered_cell_ids = @(
            "baseline_s40101", "push_s40101",
            "baseline_s40102", "push_s40102",
            "baseline_s40103", "push_s40103"
        )
        maximum_world_count = 6
    }
}

function Assert-Exact {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

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
    $text = ($Value | ConvertTo-Json -Depth 100) + [Environment]::NewLine
    Write-Utf8CreateNew -Path $Path -Text $text
}

function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-FileIdentity {
    param([Parameter(Mandatory)][string]$Path)
    $resolved = [IO.Path]::GetFullPath($Path)
    return [ordered]@{
        path = $resolved
        byte_length = [int64](Get-Item -LiteralPath $resolved).Length
        raw_sha256 = Get-PrefixedSha256 -Path $resolved
    }
}

function Get-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowEmpty
    )
    $lines = @(& git -C $repoRoot @Arguments 2>&1)
    Assert-Exact ($LASTEXITCODE -eq 0) "Git check failed: $Label"
    $value = (($lines | ForEach-Object { [string]$_ }) -join [char]10).Trim()
    if (-not $AllowEmpty) {
        Assert-Exact (
            -not [string]::IsNullOrWhiteSpace($value)
        ) "Git check returned empty output: $Label"
    }
    return $value
}

function Get-SingleMarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker
    )
    $lines = @(
        $Stdout -split "\r?\n" |
            Where-Object {
                $_.StartsWith($Marker, [StringComparison]::Ordinal)
            }
    )
    Assert-Exact (
        $lines.Count -eq 1
    ) "Expected exactly one $($Marker.Trim()) receipt"
    return (
        $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    )
}

function Assert-ZeroWorldReceipt {
    param(
        [Parameter(Mandatory)][hashtable]$Receipt,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-Exact ([bool]$Receipt.ok) "$Label did not pass"
    foreach ($counter in @(
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "scene_tree_insertion_count",
        "native_readback_count",
        "solver_step_count"
    )) {
        Assert-Exact (
            [int64]$Receipt[$counter] -eq 0
        ) "$Label crossed zero-world boundary: $counter"
    }
    Assert-Exact (
        -not [bool]$Receipt.physics_state_modified -and
        -not [bool]$Receipt.physical_acceptance_authority -and
        -not [bool]$Receipt.release_authority
    ) "$Label exposed physical or release authority"
}

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FileName,
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][int]$TimeoutSeconds,
        [hashtable]$AdditionalEnvironment = @{}
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in $AdditionalEnvironment.Keys) {
        $start.Environment[[string]$name] = [string]$AdditionalEnvironment[$name]
    }
    foreach ($argument in $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-Exact $process.Start() "Failed to start qualification audit"
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
        started_utc = $startedUtc.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
        exit_code = $exitCode
        timed_out = $timedOut
        killed_process_tree = $killedTree
        stdout = $stdout
        stderr = $stderr
    }
}

Assert-Exact ($repoRoot -ceq $expectedRoot) "Canonical repository root changed"
Assert-Exact (
    $evidenceRootPath -ceq $expectedEvidenceRoot
) "QSDK-R10D evidence root changed"
foreach ($path in @(
    $auditPath,
    $operationLockPath,
    $activeAdapterPath,
    $godotPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "Required qualification input is missing: $path"
}

$pythonCommand = Get-Command python -ErrorAction Stop
$pythonPath = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
. $operationLockPath

$qualificationRoot = $null
$rootCreated = $false
$lockReceipt = $null
try {
    $lockArguments = @{
        Role = "qualification"
        TimeoutMilliseconds = 0
    }
    $lockReceipt = Enter-SporeSporeLocomotionOperationLock @lockArguments
    Assert-Exact (
        [bool]$lockReceipt.acquired
    ) "Another locomotion physical or qualification operation owns the lock"

    $top = Get-GitText -Arguments @(
        "rev-parse", "--show-toplevel"
    ) -Label "repository root"
    $remote = Get-GitText -Arguments @(
        "remote", "get-url", "origin"
    ) -Label "origin URL"
    $branch = Get-GitText -Arguments @(
        "branch", "--show-current"
    ) -Label "branch"
    $status = Get-GitText -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) -Label "worktree status" -AllowEmpty
    $head = Get-GitText -Arguments @(
        "rev-parse", "HEAD"
    ) -Label "HEAD"
    $tree = Get-GitText -Arguments @(
        "rev-parse", "HEAD^{tree}"
    ) -Label "HEAD tree"
    $origin = Get-GitText -Arguments @(
        "rev-parse", "origin/main"
    ) -Label "origin/main"
    $liveLine = Get-GitText -Arguments @(
        "ls-remote", "origin", "refs/heads/main"
    ) -Label "live origin/main"
    $liveParts = @($liveLine -split "\s+" | Where-Object { $_ })
    Assert-Exact (
        [IO.Path]::GetFullPath($top) -ceq $expectedRoot -and
        $remote -ceq $expectedRemote -and
        $branch -ceq "main" -and
        [string]::IsNullOrEmpty($status) -and
        $head -ceq $origin -and
        $liveParts.Count -eq 2 -and
        [string]$liveParts[0] -ceq $head -and
        [string]$liveParts[1] -ceq "refs/heads/main"
    ) "Official qualification requires clean pushed source equal to live main"

    $qualificationRoot = Join-Path $evidenceRootPath (
        "qsdk-r10d-{0}-zero-world-qualification-{1}" -f
            [string]$campaign.role_slug, $head.Substring(0, 12)
    )
    Assert-Exact (
        -not (Test-Path -LiteralPath $qualificationRoot)
    ) "This source-and-role qualification identity is already consumed"
    [void][IO.Directory]::CreateDirectory($qualificationRoot)
    $rootCreated = $true

    $attemptPath = Join-Path $qualificationRoot "attempt.json"
    $stdoutPath = Join-Path $qualificationRoot "stdout.log"
    $stderrPath = Join-Path $qualificationRoot "stderr.log"
    $receiptPath = Join-Path $qualificationRoot "implementation-receipt.json"
    $completionPath = Join-Path $qualificationRoot "completion.json"
    $attempt = [ordered]@{
        schema_version = (
            "sporespore_qsdk_r10d_zero_world_qualification_attempt_v2"
        )
        status = "started_official_zero_world_qualification"
        gate_id = "QSDK-R10D"
        repair_id = $repairId
        campaign_id = [string]$campaign.id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        started_utc = [DateTime]::UtcNow.ToString("o")
        output_root = $qualificationRoot
        source = [ordered]@{
            commit = $head
            tree = $tree
            branch = $branch
            remote = $remote
            origin_main_commit = $origin
            live_main_commit = [string]$liveParts[0]
            clean = $true
        }
        qualified_source_path_count = $qualifiedSourcePathCount
        qualified_source_path_sha256 = $qualifiedSourcePathSha256
        r10c_design_sha256 = $r10cDesignSha256
        r10d_l1_design_sha256 = $r10dL1DesignSha256
        consumed_r10d_physical_closure_sha256 = (
            $consumedR10dPhysicalClosureSha256
        )
        consumed_r10b_held_out_closure_sha256 = (
            $r10bHeldOutClosureSha256
        )
        r05e_physical_closure_sha256 = $r05ePhysicalClosureSha256
        godot = Get-FileIdentity -Path $godotPath
        active_adapter = Get-FileIdentity -Path $activeAdapterPath
        operation_lock = (
            Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lockReceipt
        )
        physical_execution_authorized = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew -Path $attemptPath -Value $attempt

    $processArguments = @(
        "-B",
        $auditPath,
        "--godot",
        $godotPath,
        "--official-qualification"
    )
    $processEnvironment = @{
        SPORESPORE_QSDK_R10D_QUALIFICATION_LOCK_HELD = "1"
    }
    $invokeArguments = @{
        FileName = $pythonPath
        Arguments = $processArguments
        TimeoutSeconds = $TimeoutSeconds
        AdditionalEnvironment = $processEnvironment
    }
    $execution = Invoke-CapturedProcess @invokeArguments
    Write-Utf8CreateNew -Path $stdoutPath -Text ([string]$execution.stdout)
    Write-Utf8CreateNew -Path $stderrPath -Text ([string]$execution.stderr)
    Assert-Exact (
        -not [bool]$execution.timed_out -and
        [int]$execution.exit_code -eq 0
    ) "The official R10D implementation audit failed or timed out"

    $receiptArguments = @{
        Stdout = [string]$execution.stdout
        Marker = $passMarker
    }
    $receipt = Get-SingleMarkerJson @receiptArguments
    Assert-ZeroWorldReceipt -Receipt $receipt -Label "implementation audit"
    Assert-Exact (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r10d_zero_world_implementation_audit_v1" -and
        [string]$receipt.gate_id -ceq "QSDK-R10D" -and
        [string]$receipt.repair_id -ceq $repairId -and
        [string]$receipt.source_commit -ceq $head -and
        [string]$receipt.source_tree -ceq $tree -and
        [string]$receipt.source_branch -ceq "main" -and
        [bool]$receipt.source_clean -and
        [bool]$receipt.source_origin_main_equal -and
        [bool]$receipt.source_live_main_equal -and
        [bool]$receipt.official_qualification_mode -and
        [int]$receipt.qualified_source_path_count -eq
            $qualifiedSourcePathCount -and
        [string]$receipt.qualified_source_path_sha256 -ceq
            $qualifiedSourcePathSha256 -and
        [bool]$receipt.all_qualified_source_paths_tracked -and
        [bool]$receipt.tracked_source_required -and
        [string]$receipt.r10c_design_raw_sha256 -ceq
            $r10cDesignSha256 -and
        [string]$receipt.r10d_l1_design_raw_sha256 -ceq
            $r10dL1DesignSha256 -and
        [string]$receipt.consumed_r10d_physical_closure_raw_sha256 -ceq
            $consumedR10dPhysicalClosureSha256 -and
        [string]$receipt.r10b_held_out_closure_raw_sha256 -ceq
            $r10bHeldOutClosureSha256 -and
        [string]$receipt.r05e_physical_closure_raw_sha256 -ceq
            $r05ePhysicalClosureSha256 -and
        [bool]$receipt.dependency_closure_audit_passed -and
        [bool]$receipt.authority_materializer_self_test_passed -and
        [bool]$receipt.static_authorization_boundary_passed -and
        [bool]$receipt.operation_lock_boundary_passed -and
        [string]$receipt.operation_lock_mode -ceq
            "held_by_official_qualification_wrapper" -and
        -not [bool]$receipt.physical_execution_authorized
    ) "The official R10D implementation receipt is not exact"

    $runtime = $receipt.runtime_identity_projection.identity
    Assert-Exact (
        [string]$runtime.godot.raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $godotPath) -and
        [int64]$runtime.godot.byte_length -eq
            [int64](Get-Item -LiteralPath $godotPath).Length -and
        [string]$runtime.active_adapter.raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $activeAdapterPath) -and
        [int64]$runtime.active_adapter.byte_length -eq
            [int64](Get-Item -LiteralPath $activeAdapterPath).Length
    ) "The qualified Godot or native adapter identity drifted"

    Write-JsonCreateNew -Path $receiptPath -Value $receipt
    $completion = [ordered]@{
        schema_version = $qualificationSchema
        status = "complete_passing_official_zero_world_qualification"
        gate_id = "QSDK-R10D"
        repair_id = $repairId
        campaign_id = [string]$campaign.id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        qualification_passed = $true
        completed_utc = [DateTime]::UtcNow.ToString("o")
        qualification_root = $qualificationRoot
        source = [ordered]@{
            commit = $head
            tree = $tree
            branch = $branch
            remote = $remote
            origin_main_commit = $origin
            live_main_commit = [string]$liveParts[0]
            clean = $true
        }
        attempt = Get-FileIdentity -Path $attemptPath
        retained_files = @(
            Get-FileIdentity -Path $attemptPath
            Get-FileIdentity -Path $stdoutPath
            Get-FileIdentity -Path $stderrPath
            Get-FileIdentity -Path $receiptPath
        )
        implementation_receipt = Get-FileIdentity -Path $receiptPath
        runtime_identity_projection = $receipt.runtime_identity_projection
        qualified_source_path_count = $qualifiedSourcePathCount
        qualified_source_path_sha256 = $qualifiedSourcePathSha256
        all_qualified_source_paths_tracked = $true
        r10c_design_sha256 = $r10cDesignSha256
        r10d_l1_design_sha256 = $r10dL1DesignSha256
        consumed_r10d_physical_closure_sha256 = (
            $consumedR10dPhysicalClosureSha256
        )
        consumed_r10b_held_out_closure_sha256 = (
            $r10bHeldOutClosureSha256
        )
        r05e_physical_closure_sha256 = $r05ePhysicalClosureSha256
        ordered_cell_ids = @($campaign.ordered_cell_ids)
        maximum_future_world_count = [int]$campaign.maximum_world_count
        operation_lock_serialization_passed = $true
        physical_execution_authorized = $false
        locomotion_outcome_exposure_count = 0
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        scene_tree_insertion_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-JsonCreateNew -Path $completionPath -Value $completion
    Write-Output (
        $completionMarker +
        ([ordered]@{
            campaign_role = $CampaignRole
            source_commit = $head
            qualification_root = $qualificationRoot
            completion_path = $completionPath
            completion_sha256 = Get-PrefixedSha256 -Path $completionPath
            qualification_passed = $true
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_execution_authorized = $false
        } | ConvertTo-Json -Compress)
    )
} catch {
    if ($rootCreated -and $null -ne $qualificationRoot) {
        $failurePath = Join-Path $qualificationRoot "failure.json"
        if (-not (Test-Path -LiteralPath $failurePath)) {
            try {
                $failure = [ordered]@{
                    schema_version = (
                        "sporespore_qsdk_r10d_" +
                        "zero_world_qualification_failure_v2"
                    )
                    gate_id = "QSDK-R10D"
                    repair_id = $repairId
                    campaign_role = $CampaignRole
                    failed_utc = [DateTime]::UtcNow.ToString("o")
                    failure = [string]$_.Exception.Message
                    qualification_passed = $false
                    same_qualification_identity_rerun_permitted = $false
                    physical_execution_authorized = $false
                    model_construction_count = 0
                    world_attempt_count = 0
                    world_build_count = 0
                    native_readback_count = 0
                    solver_step_count = 0
                    physics_state_modified = $false
                    physical_acceptance_authority = $false
                    release_authority = $false
                }
                Write-JsonCreateNew -Path $failurePath -Value $failure
            } catch {
                # Preserve the original terminal failure.
            }
        }
    }
    Write-Error $_
    exit 1
} finally {
    if ($null -ne $lockReceipt -and [bool]$lockReceipt.acquired) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lockReceipt
    }
}
