#requires -Version 7.0

<#
Consume and retain one official QSDK-R10E zero-world qualification identity.

This wrapper cannot authorize or execute physics. It requires a clean pushed
checkout equal to live main, owns the repository-wide locomotion operation lock
for the entire audit, and retains every terminal result in the durable evidence
root. A failed source-and-role identity is consumed and is never retried.
#>

[CmdletBinding()]
param(
    [ValidateSet("development_route_ghost", "held_out_finite_decision")]
    [string]$CampaignRole = "held_out_finite_decision",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [ValidateRange(300, 3600)]
    [int]$TimeoutSeconds = 1800
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:ExpectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$script:ExpectedRemote = "https://github.com/Slagathore/sporespore.git"
$script:ExpectedEvidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$script:EvidenceRoot = [IO.Path]::GetFullPath($EvidenceRoot)
$script:GodotPath = [IO.Path]::GetFullPath($Godot)
$script:AuditPath = Join-Path $PSScriptRoot (
    "conformance\qsdk_r10e_zero_world_implementation.py"
)
$script:OperationLockPath = Join-Path $PSScriptRoot "locomotion_operation_lock.ps1"
$script:ActiveAdapterPath = Join-Path $PSScriptRoot (
    "target\debug\sporespore_godot_adapter.dll"
)
$script:PassMarker = "QSDK_R10E_ZERO_WORLD_IMPLEMENTATION_PASS "
$script:CompletionMarker = "QSDK_R10E_ZERO_WORLD_QUALIFICATION_COMPLETE "
$script:QualificationLockEnvironment = (
    "SPORESPORE_QSDK_R10E_QUALIFICATION_LOCK_HELD"
)
$script:AttemptPathEnvironment = "SPORESPORE_QSDK_R10E_ATTEMPT"
$script:AttemptTokenEnvironment = "SPORESPORE_QSDK_R10E_TOKEN"
$script:ExpectedDesignSha256 = (
    "sha256:791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a"
)
$script:ExpectedR10dDevelopmentSha256 = (
    "sha256:dbbdeb257a260a64c730459880d8d4d66682ec94b65ec8f3beaeb4c38a3cdcc9"
)
$script:ExpectedR10dHeldOutSha256 = (
    "sha256:4a96145b54161a166e735bfd884e497772774d0f9e1e11ae8db6b8fa557c4ed2"
)
$script:ExpectedR05eSha256 = (
    "sha256:dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e"
)
$script:ExpectedSupervisorRefusalSha256 = (
    "sha256:831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0"
)
$script:ExpectedL2HeldOutFailureClosureSha256 = (
    "sha256:29942c4f666d3cc7d88388945bb450d6d64f01a6757f72f7a38e149b5d351211"
)

# Installed with the finalized recursive dependency closure.
$script:QualifiedSourcePathCount = 91
$script:QualifiedSourcePathSha256 = (
    "sha256:348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67"
)

$script:Campaigns = @{
    development_route_ghost = [ordered]@{
        repair_id = "QSDK-R10E-L2"
        qualification_permitted = $false
        attempt_schema = "sporespore_qsdk_r10e_zero_world_qualification_attempt_v1"
        completion_schema = "sporespore_qsdk_r10e_zero_world_qualification_completion_v1"
        campaign_id = (
            "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        )
        question_class = "development"
        slug = "development-route-ghost"
        ordered_cell_ids = @("baseline_s40002", "push_s40002")
        maximum_future_world_count = 2
    }
    held_out_finite_decision = [ordered]@{
        repair_id = "QSDK-R10E-L3"
        qualification_permitted = $true
        attempt_schema = "sporespore_qsdk_r10e_zero_world_qualification_attempt_v2"
        completion_schema = "sporespore_qsdk_r10e_zero_world_qualification_completion_v2"
        campaign_id = (
            "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
        )
        question_class = "finite decision"
        slug = "held-out-finite-decision"
        ordered_cell_ids = @(
            "baseline_s40101", "push_s40101",
            "baseline_s40102", "push_s40102",
            "baseline_s40103", "push_s40103"
        )
        maximum_future_world_count = 6
    }
}


function Assert-R10eQualification {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Code
    )
    if (-not $Condition) { throw $Code }
}


function Test-ExactJsonIntegerZero {
    param([AllowNull()][object]$Value)
    return (
        ($Value -is [int32] -or $Value -is [int64]) -and
        [int64]$Value -eq 0
    )
}


function Write-Utf8CreateNew {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    $stream = [IO.File]::Open(
        [IO.Path]::GetFullPath($Path),
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
        [Parameter(Mandatory)][object]$Value
    )
    $json = $Value | ConvertTo-Json -Depth 100
    Write-Utf8CreateNew -Path $Path -Text ($json.Replace("`r`n", "`n") + "`n")
}


function Get-PrefixedSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}


function Get-FileBinding {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string]$RelativeTo = ""
    )
    $resolved = [IO.Path]::GetFullPath($Path)
    $display = $resolved.Replace("\", "/")
    if ($RelativeTo) {
        $display = [IO.Path]::GetRelativePath(
            [IO.Path]::GetFullPath($RelativeTo), $resolved
        ).Replace("\", "/")
    }
    return [ordered]@{
        path = $display
        byte_length = [int64](Get-Item -LiteralPath $resolved).Length
        raw_sha256 = Get-PrefixedSha256 -Path $resolved
    }
}


function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Environment = @{},
        [string[]]$ClearEnvironment = @(),
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 120
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.WorkingDirectory = $script:RepoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $null = $start.ArgumentList.Add([string]$argument)
    }
    foreach ($name in $ClearEnvironment) {
        $null = $start.Environment.Remove([string]$name)
    }
    foreach ($name in $Environment.Keys) {
        $start.Environment[[string]$name] = [string]$Environment[$name]
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $startedUtc = [DateTime]::UtcNow
    Assert-R10eQualification $process.Start() "QUALIFICATION_PROCESS_NOT_STARTED"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    $killedTree = $false
    if (-not $completed) {
        try {
            $process.Kill($true)
            $killedTree = $true
        } catch {
            $killedTree = $false
        }
        $null = $process.WaitForExit(10000)
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($process.HasExited) { [int]$process.ExitCode } else { -1 }
    $process.Dispose()
    return [ordered]@{
        started_utc = $startedUtc.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
        completed = [bool]$completed
        timed_out = -not [bool]$completed
        killed_process_tree = $killedTree
        exit_code = $exitCode
        stdout = [string]$stdout
        stderr = [string]$stderr
    }
}


function Invoke-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowEmpty
    )
    $result = Invoke-CapturedProcess -FilePath "git" -Arguments (
        @("-C", $script:RepoRoot) + $Arguments
    ) -TimeoutSeconds 60
    Assert-R10eQualification (
        $result.completed -and $result.exit_code -eq 0
    ) ("GIT_FAILED:" + $Label)
    $value = $result.stdout.Trim()
    Assert-R10eQualification (
        $AllowEmpty -or $value.Length -gt 0
    ) ("GIT_EMPTY:" + $Label)
    return $value
}


function Get-SingleMarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker
    )
    $lines = @(
        $Stdout -split "`r?`n" |
            Where-Object { $_.StartsWith($Marker, [StringComparison]::Ordinal) }
    )
    Assert-R10eQualification ($lines.Count -eq 1) "IMPLEMENTATION_MARKER_COUNT"
    try {
        return $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw ("IMPLEMENTATION_MARKER_JSON:" + $_.Exception.Message)
    }
}


function Assert-ZeroWorldReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R10eQualification (
        $Receipt.Contains("ok") -and
        $Receipt["ok"] -is [bool] -and
        [bool]$Receipt["ok"]
    ) ($Label + "_NOT_OK")
    foreach ($counter in @(
        "model_construction_count", "world_attempt_count", "world_build_count",
        "scene_tree_insertion_count", "native_readback_count", "solver_step_count"
    )) {
        Assert-R10eQualification (
            $Receipt.Contains($counter) -and
            (Test-ExactJsonIntegerZero $Receipt[$counter])
        ) ($Label + "_" + $counter)
    }
    foreach ($field in @(
        "physics_state_modified", "physical_acceptance_authority", "release_authority"
    )) {
        Assert-R10eQualification (
            $Receipt.Contains($field) -and
            $Receipt[$field] -is [bool] -and
            -not [bool]$Receipt[$field]
        ) ($Label + "_" + $field)
    }
}


function Get-LedgerScope {
    return [ordered]@{
        subsystem = "recovery"
        engine_scope = "godot_jolt"
        authority_mode = "official_zero_world_qualification"
        question_class = [string]$script:Campaigns[$CampaignRole].question_class
    }
}


function Get-CleanLiveSource {
    $top = Invoke-GitText -Arguments @(
        "rev-parse", "--show-toplevel"
    ) -Label "TOPLEVEL"
    $remote = Invoke-GitText -Arguments @(
        "remote", "get-url", "origin"
    ) -Label "REMOTE"
    $branch = Invoke-GitText -Arguments @(
        "branch", "--show-current"
    ) -Label "BRANCH"
    $status = Invoke-GitText -Arguments @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) -Label "STATUS" -AllowEmpty
    $head = Invoke-GitText -Arguments @("rev-parse", "HEAD") -Label "HEAD"
    $tree = Invoke-GitText -Arguments @("rev-parse", "HEAD^{tree}") -Label "TREE"
    $origin = Invoke-GitText -Arguments @(
        "rev-parse", "origin/main"
    ) -Label "ORIGIN_MAIN"
    $liveRecord = Invoke-GitText -Arguments @(
        "ls-remote", "origin", "refs/heads/main"
    ) -Label "LIVE_MAIN"
    $liveParts = @($liveRecord -split "\s+" | Where-Object { $_ })
    Assert-R10eQualification (
        [IO.Path]::GetFullPath($top) -ceq $script:ExpectedRoot -and
        $remote -ceq $script:ExpectedRemote -and
        $branch -ceq "main" -and
        $status.Length -eq 0 -and
        $head -ceq $origin -and
        $liveParts.Count -eq 2 -and
        [string]$liveParts[0] -ceq $head -and
        [string]$liveParts[1] -ceq "refs/heads/main"
    ) "CLEAN_LIVE_MAIN_REQUIRED"
    return [ordered]@{
        commit = $head
        tree = $tree
        branch = $branch
        remote = $remote
        origin_main_commit = $origin
        live_main_commit = [string]$liveParts[0]
        clean = $true
    }
}


Assert-R10eQualification (
    $script:RepoRoot -ceq $script:ExpectedRoot
) "CANONICAL_ROOT"
Assert-R10eQualification (
    $script:EvidenceRoot -ceq $script:ExpectedEvidenceRoot
) "EVIDENCE_ROOT"
Assert-R10eQualification (
    $script:QualifiedSourcePathCount -gt 0 -and
    $script:QualifiedSourcePathSha256 -match '^sha256:[0-9a-f]{64}$'
) "SOURCE_BINDING_NOT_FINALIZED"
Assert-R10eQualification (
    Test-Path -LiteralPath $script:EvidenceRoot -PathType Container
) "EVIDENCE_ROOT_MISSING"
foreach ($path in @(
    $script:GodotPath,
    $script:AuditPath,
    $script:OperationLockPath,
    $script:ActiveAdapterPath
)) {
    Assert-R10eQualification (
        Test-Path -LiteralPath $path -PathType Leaf
    ) ("QUALIFICATION_INPUT_MISSING:" + $path)
}
$pythonCommand = Get-Command -Name $Python -CommandType Application -ErrorAction Stop
$script:PythonPath = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
$pwshCommand = Get-Command -Name "pwsh" -CommandType Application -ErrorAction Stop
$script:PwshPath = [IO.Path]::GetFullPath([string]$pwshCommand.Source)
. $script:OperationLockPath

$qualificationRoot = ""
$rootCreated = $false
$attemptPath = ""
$stdoutPath = ""
$stderrPath = ""
$implementationPath = ""
$runtimePath = ""
$completionPath = ""
$lockReceipt = $null
$source = $null
$campaign = $null
$startedUtc = [DateTime]::UtcNow.ToString("o")
try {
    $lockReceipt = Enter-SporeSporeLocomotionOperationLock `
        -Role qualification `
        -TimeoutMilliseconds 0
    Assert-R10eQualification (
        [bool]$lockReceipt.acquired -and
        -not [bool]$lockReceipt.abandoned_owner_recovered
    ) "LOCOMOTION_OPERATION_LOCK_BUSY"

    $source = Get-CleanLiveSource
    $campaign = $script:Campaigns[$CampaignRole]
    Assert-R10eQualification (
        [bool]$campaign.qualification_permitted
    ) "HISTORICAL_DEVELOPMENT_ROUTE_REQUALIFICATION_FORBIDDEN"
    $qualificationRoot = Join-Path $script:EvidenceRoot (
        "qsdk-r10e-{0}-zero-world-qualification-{1}" -f
            [string]$campaign.slug, $source.commit.Substring(0, 12)
    )
    Assert-R10eQualification (
        -not (Test-Path -LiteralPath $qualificationRoot)
    ) "QUALIFICATION_IDENTITY_ALREADY_CONSUMED"
    $null = [IO.Directory]::CreateDirectory($qualificationRoot)
    $rootCreated = $true

    $attemptPath = Join-Path $qualificationRoot "qualification_attempt.json"
    $stdoutPath = Join-Path $qualificationRoot "qualification_stdout.log"
    $stderrPath = Join-Path $qualificationRoot "qualification_stderr.log"
    $implementationPath = Join-Path $qualificationRoot "implementation_audit.json"
    $runtimePath = Join-Path $qualificationRoot "runtime_identity.json"
    $completionPath = Join-Path $qualificationRoot "qualification_completion.json"
    $attempt = [ordered]@{
        schema_version = [string]$campaign.attempt_schema
        status = "started_consumed_official_zero_world_qualification"
        gate_id = "QSDK-R10E"
        repair_id = [string]$campaign.repair_id
        campaign_id = [string]$campaign.campaign_id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        ledger_scope = Get-LedgerScope
        source_commit = [string]$source.commit
        source = $source
        output_root = $qualificationRoot.Replace("\", "/")
        qualified_source_path_count = $script:QualifiedSourcePathCount
        qualified_source_path_sha256 = $script:QualifiedSourcePathSha256
        r10e_design_sha256 = $script:ExpectedDesignSha256
        r10d_development_closure_sha256 = $script:ExpectedR10dDevelopmentSha256
        r10d_held_out_closure_sha256 = $script:ExpectedR10dHeldOutSha256
        r05e_physical_closure_sha256 = $script:ExpectedR05eSha256
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        l2_held_out_failure_closure_sha256 = (
            $script:ExpectedL2HeldOutFailureClosureSha256
        )
        godot = Get-FileBinding -Path $script:GodotPath
        active_adapter = Get-FileBinding -Path $script:ActiveAdapterPath
        operation_lock = (
            Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lockReceipt
        )
        started_utc = $startedUtc
        maximum_official_qualification_attempt_count_for_source_and_role = 1
        same_identity_rerun_permitted = $false
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

    $execution = Invoke-CapturedProcess `
        -FilePath $script:PythonPath `
        -Arguments @(
            "-B", $script:AuditPath,
            "--godot", $script:GodotPath,
            "--require-tracked",
            "--official-qualification"
        ) `
        -Environment @{
            $script:QualificationLockEnvironment = "1"
        } `
        -ClearEnvironment @(
            $script:AttemptPathEnvironment,
            $script:AttemptTokenEnvironment
        ) `
        -TimeoutSeconds $TimeoutSeconds
    Write-Utf8CreateNew -Path $stdoutPath -Text $execution.stdout
    Write-Utf8CreateNew -Path $stderrPath -Text $execution.stderr
    Assert-R10eQualification (
        $execution.completed -and
        -not $execution.timed_out -and
        $execution.exit_code -eq 0
    ) "IMPLEMENTATION_AUDIT_FAILED_OR_TIMED_OUT"

    $receipt = Get-SingleMarkerJson `
        -Stdout $execution.stdout `
        -Marker $script:PassMarker
    Assert-ZeroWorldReceipt -Receipt $receipt -Label "IMPLEMENTATION_AUDIT"
    Assert-R10eQualification (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r10e_zero_world_implementation_audit_v1" -and
        [string]$receipt.status -ceq
            "closed_passing_official_zero_world_qualification" -and
        [string]$receipt.gate_id -ceq "QSDK-R10E" -and
        [string]$receipt.repair_id -ceq [string]$campaign.repair_id -and
        [bool]$receipt.official_qualification -and
        [string]$receipt.source_commit -ceq [string]$source.commit -and
        [string]$receipt.source_tree -ceq [string]$source.tree -and
        [string]$receipt.source_branch -ceq "main" -and
        [bool]$receipt.source_clean -and
        [bool]$receipt.source_origin_main_equal -and
        [bool]$receipt.source_live_main_equal -and
        [int]$receipt.qualified_source_path_count -eq
            $script:QualifiedSourcePathCount -and
        [string]$receipt.qualified_source_path_sha256 -ceq
            $script:QualifiedSourcePathSha256 -and
        [bool]$receipt.all_qualified_source_paths_tracked -and
        [bool]$receipt.tracked_source_required -and
        [string]$receipt.r10e_design_raw_sha256 -ceq
            $script:ExpectedDesignSha256 -and
        [string]$receipt.r10d_development_closure_raw_sha256 -ceq
            $script:ExpectedR10dDevelopmentSha256 -and
        [string]$receipt.r10d_held_out_closure_raw_sha256 -ceq
            $script:ExpectedR10dHeldOutSha256 -and
        [string]$receipt.r05e_physical_closure_raw_sha256 -ceq
            $script:ExpectedR05eSha256 -and
        [string]$receipt.predecessor_physical_supervisor_refusal_closure_raw_sha256 -ceq
            $script:ExpectedSupervisorRefusalSha256 -and
        [string]$receipt.l2_held_out_failure_closure_raw_sha256 -ceq
            $script:ExpectedL2HeldOutFailureClosureSha256 -and
        -not [bool]$receipt.predecessor_physical_attempt_identity_consumed -and
        [bool]$receipt.dependency_closure_audit_passed -and
        [bool]$receipt.authority_materializer_self_test_passed -and
        [bool]$receipt.physical_closure_self_test_passed -and
        [bool]$receipt.static_authorization_boundary_passed -and
        [bool]$receipt.operation_lock_boundary_passed -and
        [string]$receipt.operation_lock_mode -ceq
            "held_by_official_qualification_wrapper" -and
        -not [bool]$receipt.physical_execution_authorized
    ) "IMPLEMENTATION_RECEIPT_RECONCILIATION"

    Write-JsonCreateNew -Path $implementationPath -Value $receipt
    $runtime = $receipt.runtime_identity
    Assert-R10eQualification (
        $runtime -is [System.Collections.IDictionary] -and
        [string]$runtime.schema_version -ceq
            "sporespore_qsdk_r10e_runtime_identity_v1" -and
        [string]$runtime.source_commit -ceq [string]$source.commit -and
        [bool]$runtime.runtime_identity_complete -and
        [string]$runtime.active_adapter_raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $script:ActiveAdapterPath) -and
        [string]$runtime.active_adapter.path -ceq
            "sdk/target/debug/sporespore_godot_adapter.dll" -and
        [int64]$runtime.active_adapter.byte_length -eq
            [int64](Get-Item -LiteralPath $script:ActiveAdapterPath).Length -and
        [string]$runtime.active_adapter.raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $script:ActiveAdapterPath) -and
        [string]$runtime.godot_console.path -ceq
            $script:GodotPath.Replace("\", "/") -and
        [string]$runtime.godot_console.raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $script:GodotPath) -and
        [int64]$runtime.godot_console.byte_length -eq
            [int64](Get-Item -LiteralPath $script:GodotPath).Length -and
        [string]$runtime.python.path -ceq
            $script:PythonPath.Replace("\", "/") -and
        [string]$runtime.python.raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $script:PythonPath) -and
        [int64]$runtime.python.byte_length -eq
            [int64](Get-Item -LiteralPath $script:PythonPath).Length -and
        [string]$runtime.python.version -ceq
            [string]$runtime.python_version -and
        [string]$runtime.powershell.path -ceq
            $script:PwshPath.Replace("\", "/") -and
        [string]$runtime.powershell.raw_sha256 -ceq
            (Get-PrefixedSha256 -Path $script:PwshPath) -and
        [int64]$runtime.powershell.byte_length -eq
            [int64](Get-Item -LiteralPath $script:PwshPath).Length -and
        [string]$runtime.powershell.version -ceq
            [string]$runtime.powershell_version
    ) "RUNTIME_IDENTITY_RECONCILIATION"
    Write-JsonCreateNew -Path $runtimePath -Value $runtime

    $endSource = Get-CleanLiveSource
    Assert-R10eQualification (
        [string]$endSource.commit -ceq [string]$source.commit -and
        [string]$endSource.tree -ceq [string]$source.tree
    ) "SOURCE_DRIFT_DURING_QUALIFICATION"

    $completion = [ordered]@{
        schema_version = [string]$campaign.completion_schema
        status = "closed_passing_official_zero_world_qualification"
        gate_id = "QSDK-R10E"
        repair_id = [string]$campaign.repair_id
        campaign_id = [string]$campaign.campaign_id
        campaign_role = $CampaignRole
        question_class = [string]$campaign.question_class
        ledger_scope = Get-LedgerScope
        source_commit = [string]$source.commit
        source_tree = [string]$source.tree
        qualification_started_utc = $startedUtc
        qualification_completed_utc = [DateTime]::UtcNow.ToString("o")
        qualification_root = $qualificationRoot.Replace("\", "/")
        qualification_attempt = Get-FileBinding `
            -Path $attemptPath `
            -RelativeTo $qualificationRoot
        implementation_audit = Get-FileBinding `
            -Path $implementationPath `
            -RelativeTo $qualificationRoot
        runtime_identity = Get-FileBinding `
            -Path $runtimePath `
            -RelativeTo $qualificationRoot
        qualification_stdout = Get-FileBinding `
            -Path $stdoutPath `
            -RelativeTo $qualificationRoot
        qualification_stderr = Get-FileBinding `
            -Path $stderrPath `
            -RelativeTo $qualificationRoot
        qualified_source_path_count = $script:QualifiedSourcePathCount
        qualified_source_path_sha256 = $script:QualifiedSourcePathSha256
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        l2_held_out_failure_closure_sha256 = (
            $script:ExpectedL2HeldOutFailureClosureSha256
        )
        official_zero_world_qualification_passed = $true
        source_unchanged_during_qualification = $true
        operation_lock_serialization_passed = $true
        ordered_future_cell_ids = @($campaign.ordered_cell_ids)
        maximum_future_world_count = [int]$campaign.maximum_future_world_count
        maximum_future_campaign_attempt_count = 1
        same_identity_rerun_permitted = $false
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
        $script:CompletionMarker +
        ([ordered]@{
            campaign_role = $CampaignRole
            repair_id = [string]$campaign.repair_id
            source_commit = [string]$source.commit
            qualification_root = $qualificationRoot.Replace("\", "/")
            completion_path = $completionPath.Replace("\", "/")
            completion_sha256 = Get-PrefixedSha256 -Path $completionPath
            official_zero_world_qualification_passed = $true
            world_attempt_count = 0
            world_build_count = 0
            solver_step_count = 0
            physical_execution_authorized = $false
        } | ConvertTo-Json -Compress)
    )
} catch {
    if ($rootCreated -and $qualificationRoot) {
        $failurePath = Join-Path $qualificationRoot "qualification_failure.json"
        if (-not (Test-Path -LiteralPath $failurePath)) {
            try {
                Write-JsonCreateNew -Path $failurePath -Value ([ordered]@{
                    schema_version = (
                        "sporespore_qsdk_r10e_zero_world_qualification_failure_v2"
                    )
                    status = "closed_failed_identity_consumed"
                    gate_id = "QSDK-R10E"
                    repair_id = if ($null -ne $campaign) {
                        [string]$campaign.repair_id
                    } else { "QSDK-R10E-L3" }
                    campaign_role = $CampaignRole
                    source_commit = if ($null -ne $source) {
                        [string]$source.commit
                    } else { "" }
                    qualification_root = $qualificationRoot.Replace("\", "/")
                    started_utc = $startedUtc
                    failed_utc = [DateTime]::UtcNow.ToString("o")
                    failure_code = [string]$_.Exception.Message
                    superseded_physical_supervisor_refusal_sha256 = (
                        $script:ExpectedSupervisorRefusalSha256
                    )
                    l2_held_out_failure_closure_sha256 = (
                        $script:ExpectedL2HeldOutFailureClosureSha256
                    )
                    same_identity_rerun_permitted = $false
                    physical_execution_authorized = $false
                    model_construction_count = 0
                    world_attempt_count = 0
                    world_build_count = 0
                    native_readback_count = 0
                    solver_step_count = 0
                    physics_state_modified = $false
                    physical_acceptance_authority = $false
                    release_authority = $false
                })
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
