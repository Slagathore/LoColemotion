#requires -Version 7.0

<#
Consume and retain exactly one official QSDK-R10F development zero-world
qualification for a clean pushed source commit.

This wrapper has no physical mode and cannot authorize or execute physics. It
owns the repository-wide locomotion operation lock for the entire audit,
creates the durable attempt identity before starting the audit, and never
deletes or retries a failed identity.
#>

[CmdletBinding()]
param(
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\" +
        "qsdk-r24d157-godot-jolt-rotation-integration-energy-v6\" +
        "development-cold-build-ed4ec00a\" +
        "godot.windows.editor.dev.x86_64.console.exe"
    ),
    [string]$Python = "python",
    [string]$EvidenceRoot = "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence",
    [ValidateRange(300, 3600)][int]$TimeoutSeconds = 1800,
    [switch]$L15
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "qsdk_r10f_l14_runtime_binding.ps1")

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:ExpectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$script:ExpectedRemote = "https://github.com/Slagathore/sporespore.git"
$script:ExpectedEvidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$script:AuditPath = Join-Path $PSScriptRoot (
    "conformance\qsdk_r10f_zero_world_implementation.py"
)
$script:ManifestPath = Join-Path $PSScriptRoot "qsdk_r10f_dependency_manifest_v19.json"
$script:DesignPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
$script:RepairDesignPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_l14_terminal_boundary_successor_design_v1.json"
)
$script:ActiveAdapterPath = Join-Path $PSScriptRoot (
    "target\debug\sporespore_godot_adapter.dll"
)
$script:OperationLockPath = Join-Path $PSScriptRoot "locomotion_operation_lock.ps1"
$script:PassMarker = "QSDK_R10F_ZERO_WORLD_IMPLEMENTATION_PASS "
$script:CompletionMarker = "QSDK_R10F_ZERO_WORLD_QUALIFICATION_COMPLETE "
$script:QualificationLockEnvironment = (
    "SPORESPORE_QSDK_R10F_QUALIFICATION_LOCK_HELD"
)
$script:ExpectedDesignSha256 = (
    "sha256:696cc5ee80002e39968d27c6f21fa97f9309b7f08d3caad2961699ceb7184dfa"
)
$script:ExpectedRepairDesignBytes = 13371
$script:ExpectedRepairDesignSha256 = (
    "sha256:ef04ca607078dbd67e2944f5970ba100fd8cbf970539fccc4dabdfd5c2d5691f"
)
$script:RepairId = "QSDK-R10F-L14"
$script:BranchCompletenessAddendumPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_l14_no_resume_branch_completeness_addendum_v1.json"
)
$script:ExpectedBranchCompletenessAddendumBytes = 8763
$script:ExpectedBranchCompletenessAddendumSha256 = (
    "sha256:01f40035e6cbae84621b28bdca1cd8d18a7a15876ceb44adfd668956d6b14f76"
)
# Exact source-only coverage contract; this literal is not a passing receipt.
$script:ExpectedL14ComponentReceiptJson = '{"base_design_raw_sha256":"sha256:ef04ca607078dbd67e2944f5970ba100fd8cbf970539fccc4dabdfd5c2d5691f","branch_completeness_addendum_sha256":"sha256:01f40035e6cbae84621b28bdca1cd8d18a7a15876ceb44adfd668956d6b14f76","coverage":{"actual_independent_report_and_v15_closure_builder_consumed":true,"actual_powershell_binding_receipt_corruption_count":48,"actual_powershell_complete_pair_source_consumed":true,"actual_powershell_frozen_binding_corruption_count":83,"actual_powershell_source_binding_positive_count":3,"actual_runtime_guards_before_identity_and_each_child":true,"addendum_design_corruption_count":23,"addendum_design_positive_count":1,"authority_binding_test_count":9,"base_design_corruption_count":18,"base_design_positive_count":1,"complete_proven_no_resume_negative_handoff_count":3,"complete_resumed_route_four_handoffs_preserved":true,"failed_health_or_missing_peer_never_qualifies_a_route":true,"frozen_no_resume_diagnosis_test_count":1,"future_authority_graph_is_in_memory_test_fixture_only":true,"missing_resume_alone_never_qualifies_a_negative":true,"no_resume_test_count":18,"pre_resume_terminal_cause_count":7,"python_test_count":55,"retained_physical_result_reclassified":false,"runtime_binding_test_count":11,"sdk1_m07_satisfied":false,"selected_runtime_image_count":5,"shared_authority_corruption_count":31,"shared_authority_positive_count":4,"terminal_consumer_test_count":10,"walking_v2_control_count":32,"walking_v2_malformed_input_count":20,"walking_v2_retained_segment_count":2,"worker_retention_test_count":6,"worker_source_control_count":14},"gate_id":"QSDK-R10F","ledger_scope":{"authority_mode":"zero_world_production_component_qualification","engine_scope":"godot_jolt","question_class":"development","subsystem":"recovery"},"model_construction_count":0,"native_readback_count":0,"ok":true,"physical_acceptance_authority":false,"physical_execution_authorized":false,"physics_state_modified":false,"release_authority":false,"repair_id":"QSDK-R10F-L14","scene_tree_insertion_count":0,"schema_version":"sporespore_qsdk_r10f_l14_complete_component_qualification_v1","solver_step_count":0,"test_suites":[{"passed":true,"path":"tests/test_qsdk_r10f_l14_terminal_consumers.py","test_count":10},{"passed":true,"path":"tests/test_qsdk_r10f_l14_production_terminal_paths.py","test_count":6},{"passed":true,"path":"tests/test_qsdk_r10f_l14_no_resume_terminal.py","test_count":18},{"passed":true,"path":"tests/test_qsdk_r10f_l14_authority_contract.py","test_count":9},{"passed":true,"path":"tests/test_qsdk_r10f_l14_no_resume_diagnosis.py","test_count":1},{"passed":true,"path":"tests/test_qsdk_r10f_l14_runtime_binding.py","test_count":11}],"world_attempt_count":0,"world_build_count":0}'
$script:ExpectedQualificationFailureClosureSha256 = (
    "sha256:3aed8ce62bc18369f5698e78174e7fb85a36e8595d8d43196af4dad6a86db5a1"
)
$script:SupervisorRefusalPath = Join-Path $PSScriptRoot (
    "qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json"
)
$script:ExpectedSupervisorRefusalBytes = 6486
$script:ExpectedSupervisorRefusalSha256 = (
    "sha256:93e60e8fe747a8ba7a5b6a1621175ce4bf877f537a2a5d03d01ff9e186e1140f"
)
$script:PredecessorPhysicalClosurePath = Join-Path $PSScriptRoot (
    "qsdk_r10f_development_route_ghost_physical_closure_v14.json"
)
$script:ExpectedPredecessorPhysicalClosureBytes = 9998
$script:ExpectedPredecessorPhysicalClosureSha256 = (
    "sha256:1df9bd1896deb23989d6a3c080948a21805a1465b2682748d7e31c7fa1bdd4cb"
)
$script:PhysicalEnvironmentNames = @(
    "SPORESPORE_GODOT_RECOVERY_AUTHORIZATION_SHA256",
    "SPORESPORE_GODOT_RECOVERY_SOURCE_COMMIT",
    "SPORESPORE_GODOT_RECOVERY_ATTEMPT_ID",
    "SPORESPORE_GODOT_RECOVERY_SUPERVISED_TERMINATION",
    "SPORESPORE_GODOT_RECOVERY_TERMINATION_NONCE",
    "SPORESPORE_GODOT_RECOVERY_GATE_ID",
    "SPORESPORE_GODOT_RECOVERY_GATE_TOKEN",
    "SPORESPORE_GODOT_RECOVERY_RAW_SCHEMA",
    "SPORESPORE_GODOT_RECOVERY_WORK_ID",
    "SPORESPORE_GODOT_RECOVERY_RAW_MARKER",
    "SPORESPORE_GODOT_RECOVERY_READY_MARKER",
    "SPORESPORE_GODOT_RECOVERY_PROGRESS_MARKER",
    "SPORESPORE_GODOT_RECOVERY_PROGRESS_CADENCE_STEPS",
    "SPORESPORE_GODOT_RECOVERY_SEED",
    "SPORESPORE_GODOT_RECOVERY_SEED_LABEL",
    "SPORESPORE_GODOT_RECOVERY_SEED_SHA256",
    "SPORESPORE_GODOT_RECOVERY_ACTUATOR_MODE",
    "SPORESPORE_GODOT_RECOVERY_CONTROLLER_ID",
    "SPORESPORE_GODOT_RECOVERY_ENERGY_ROUTE_ID",
    "SPORESPORE_GODOT_RECOVERY_PARENT_ATTEMPT_ID",
    "SPORESPORE_GODOT_RECOVERY_CHILD_ROLE"
)


function Assert-R10fQualification {
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


function Read-JsonHashtable {
    param([Parameter(Mandatory)][string]$Path)
    Assert-R10fQualification (
        Test-Path -LiteralPath $Path -PathType Leaf
    ) "JSON_INPUT_MISSING"
    try {
        return Get-Content -Raw -LiteralPath $Path |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw ("JSON_INPUT_INVALID:" + $_.Exception.Message)
    }
}


function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Environment = @{},
        [string[]]$ClearEnvironment = @(),
        [ValidateRange(1, 3600)][int]$TimeoutSeconds = 120
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
    Assert-R10fQualification $process.Start() "QUALIFICATION_PROCESS_NOT_STARTED"
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
    $result = Invoke-CapturedProcess `
        -FilePath "git" `
        -Arguments (@("-C", $script:RepoRoot) + $Arguments) `
        -TimeoutSeconds 60
    Assert-R10fQualification (
        $result.completed -and $result.exit_code -eq 0
    ) ("GIT_FAILED:" + $Label)
    $value = $result.stdout.Trim()
    Assert-R10fQualification (
        $AllowEmpty -or $value.Length -gt 0
    ) ("GIT_EMPTY:" + $Label)
    return $value
}


function Invoke-L15QualificationAudit {
    param(
        [Parameter(Mandatory)][string]$OutputRoot,
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [ValidateRange(1, 3600)][int]$TimeoutSeconds
    )
    # Copy the original pipe bytes directly into create-once durable files.
    # No PowerShell JSON or text decoding touches the scientific transcript.
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FilePath
    $start.WorkingDirectory = $script:RepoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $null = $start.ArgumentList.Add($argument) }
    foreach ($name in $script:PhysicalEnvironmentNames) {
        $null = $start.Environment.Remove($name)
    }
    $start.Environment[$script:QualificationLockEnvironment] = "1"
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $started = $false
    $stdoutFile = $null
    $stderrFile = $null
    $stdoutTask = $null
    $stderrTask = $null
    try {
        $stdoutFile = [IO.File]::Open(
            (Join-Path $OutputRoot "qualification_stdout.log"),
            [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read
        )
        $stderrFile = [IO.File]::Open(
            (Join-Path $OutputRoot "qualification_stderr.log"),
            [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::Read
        )
        $started = $process.Start()
        Assert-R10fQualification $started "L15_QUALIFICATION_PROCESS_NOT_STARTED"
        $stdoutTask = $process.StandardOutput.BaseStream.CopyToAsync($stdoutFile)
        $stderrTask = $process.StandardError.BaseStream.CopyToAsync($stderrFile)
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)
        if (-not $completed) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $null = $stdoutTask.GetAwaiter().GetResult()
        $null = $stderrTask.GetAwaiter().GetResult()
        $stdoutFile.Flush($true)
        $stderrFile.Flush($true)
        return [ordered]@{
            completed = [bool]$completed
            timed_out = -not [bool]$completed
            exit_code = [int]$process.ExitCode
        }
    } finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        # A failed or timed-out child is still joined and its partial bytes kept.
        try {
            if ($null -ne $stdoutTask) { $null = $stdoutTask.GetAwaiter().GetResult() }
            if ($null -ne $stderrTask) { $null = $stderrTask.GetAwaiter().GetResult() }
        } finally {
            if ($null -ne $stdoutFile) { $stdoutFile.Dispose() }
            if ($null -ne $stderrFile) { $stderrFile.Dispose() }
            $process.Dispose()
        }
    }
}


function Invoke-L15QualificationLifecycle {
    param(
        [Parameter(Mandatory)][ValidateSet("prepare", "complete")][string]$Phase,
        [Parameter(Mandatory)][string]$SourceCommit,
        [int]$ExitCode = 0
    )
    $arguments = @(
        "-B", (Join-Path $script:RepoRoot "sdk/conformance/qsdk_r10f_authority_materializer.py"),
        ($Phase + "-l15-qualification"), "--source-commit", $SourceCommit
    )
    if ($Phase -ceq "complete") { $arguments += @("--exit-code", [string]$ExitCode) }
    $result = Invoke-CapturedProcess -FilePath $script:PythonPath -Arguments $arguments `
        -Environment @{
            $script:QualificationLockEnvironment = "1"
            SPORESPORE_QSDK_R10F_QUALIFICATION_OWNER_JSON = (
                Get-SporeSporeLocomotionOperationLockPublicReceipt $lock |
                    ConvertTo-Json -Compress -Depth 10
            )
        } `
        -ClearEnvironment $script:PhysicalEnvironmentNames -TimeoutSeconds 600
    Assert-R10fQualification (
        $result.completed -and -not $result.timed_out -and
        $result.exit_code -eq 0 -and $result.stderr.Length -eq 0
    ) ("L15_QUALIFICATION_" + $Phase.ToUpperInvariant() + "_REFUSED:" + $result.stderr)
    $suffix = if ($Phase -ceq "prepare") { "PREPARED" } else { "COMPLETE" }
    $marker = "QSDK_R10F_L15_QUALIFICATION_" + $suffix + " "
    $lines = @($result.stdout -split "`r?`n" | Where-Object { $_.Length -gt 0 })
    Assert-R10fQualification (
        $lines.Count -eq 1 -and $lines[0].StartsWith($marker, [StringComparison]::Ordinal)
    ) "L15_QUALIFICATION_LIFECYCLE_PUBLICATION"
    $receipt = Get-SingleMarkerJson $result.stdout $marker
    Assert-R10fQualification (
        $receipt.source_commit -ceq $SourceCommit -and
        $receipt.repair_id -ceq "QSDK-R10F-L15" -and
        $receipt.official_source_origin_authenticated -is [bool] -and
        $receipt.official_source_origin_authenticated -and
        $receipt.official_qualification_passed -is [bool] -and
        $receipt.official_qualification_passed -eq ($Phase -ceq "complete")
    ) "L15_QUALIFICATION_LIFECYCLE_CONTRACT"
    Assert-ZeroWorldReceipt $receipt
    return $receipt
}


function Get-CleanLiveSource {
    $top = Invoke-GitText @("rev-parse", "--show-toplevel") "TOPLEVEL"
    $remote = Invoke-GitText @("remote", "get-url", "origin") "REMOTE"
    $branch = Invoke-GitText @("branch", "--show-current") "BRANCH"
    $status = Invoke-GitText @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) "STATUS" -AllowEmpty
    $head = Invoke-GitText @("rev-parse", "HEAD") "HEAD"
    $tree = Invoke-GitText @("rev-parse", "HEAD^{tree}") "TREE"
    $origin = Invoke-GitText @("rev-parse", "origin/main") "ORIGIN_MAIN"
    $live = Invoke-GitText @(
        "ls-remote", "origin", "refs/heads/main"
    ) "LIVE_MAIN"
    $fields = @($live -split "\s+" | Where-Object { $_ })
    Assert-R10fQualification (
        [IO.Path]::GetFullPath($top) -ceq $script:ExpectedRoot -and
        $remote -ceq $script:ExpectedRemote -and
        $branch -ceq "main" -and
        $status.Length -eq 0 -and
        $head -ceq $origin -and
        $fields.Count -eq 2 -and
        [string]$fields[0] -ceq $head -and
        [string]$fields[1] -ceq "refs/heads/main"
    ) "CLEAN_PUSHED_LIVE_MAIN_REQUIRED"
    return [ordered]@{
        commit = $head
        tree = $tree
        branch = $branch
        remote = $remote
        origin_main_commit = $origin
        live_main_commit = [string]$fields[0]
        clean = $true
    }
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
    Assert-R10fQualification ($lines.Count -eq 1) "IMPLEMENTATION_MARKER_COUNT"
    try {
        return $lines[0].Substring($Marker.Length) |
            ConvertFrom-Json -AsHashtable -Depth 100
    } catch {
        throw ("IMPLEMENTATION_MARKER_JSON:" + $_.Exception.Message)
    }
}


function Read-L15QualificationCandidateOutput {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$StdoutBytes,
        [Parameter(Mandatory)][AllowEmptyCollection()][byte[]]$StderrBytes,
        [Parameter(Mandatory)][AllowNull()][object]$ExitCode,
        [Parameter(Mandatory)][string]$SourceCommit
    )
    # The original candidate remains a string of exact JSON bytes. PowerShell
    # never decodes/re-encodes its scientific numbers or promotes source flags.
    # The actual Python reader independently reopens the complete source key.
    Assert-R10fQualification (
        (Test-ExactJsonIntegerZero $ExitCode) -and
        $SourceCommit -cmatch '^[0-9a-f]{40}$'
    ) "L15_OUTPUT_PROCESS_OR_SOURCE"
    $request = [ordered]@{
        source_commit = $SourceCommit
        exit_code = $ExitCode
        stdout_base64 = [Convert]::ToBase64String($StdoutBytes)
        stderr_base64 = [Convert]::ToBase64String($StderrBytes)
    } | ConvertTo-Json -Compress -Depth 10
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $script:PythonPath
    $start.WorkingDirectory = $script:RepoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardInput = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.StandardInputEncoding = [Text.UTF8Encoding]::new($false, $true)
    $start.StandardOutputEncoding = [Text.UTF8Encoding]::new($false, $true)
    $start.StandardErrorEncoding = [Text.UTF8Encoding]::new($false, $true)
    foreach ($argument in @(
        "-B", (Join-Path $script:RepoRoot "sdk/conformance/qsdk_r10f_authority_materializer.py"),
        "read-l15-candidate-output"
    )) { $null = $start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $processStarted = $false
    try {
        $processStarted = $process.Start()
        Assert-R10fQualification $processStarted "L15_OUTPUT_READER_NOT_STARTED"
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Write($request)
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(300000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "L15_OUTPUT_READER_TIMEOUT"
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        Assert-R10fQualification ($process.ExitCode -eq 0) (
            "L15_OUTPUT_READER_REFUSED:" + $stderr
        )
        $prefix = "QSDK_R10F_L15_QUALIFICATION_OUTPUT_PASS "
        $lines = @($stdout -split "`r?`n" | Where-Object { $_.Length -gt 0 })
        Assert-R10fQualification (
            $lines.Count -eq 1 -and
            $lines[0].StartsWith($prefix, [StringComparison]::Ordinal) -and
            $stderr.Length -eq 0
        ) "L15_OUTPUT_READER_PUBLICATION"
        $receipt = $lines[0].Substring($prefix.Length) | ConvertFrom-Json -AsHashtable -Depth 100
        Assert-R10fQualification (
            $receipt.schema_version -ceq "sporespore_qsdk_r10f_l15_qualification_output_reader_v1" -and
            $receipt.source_commit -ceq $SourceCommit -and
            $receipt.ok -is [bool] -and $receipt.ok -and
            $receipt.complete_candidate_validated -is [bool] -and $receipt.complete_candidate_validated -and
            $receipt.complete_source_records_independently_reopened -is [bool] -and $receipt.complete_source_records_independently_reopened
        ) "L15_OUTPUT_READER_CONTRACT"
        foreach ($name in @(
            "official_source_origin_authenticated", "qualification_or_physical_identity_created",
            "qualification_directory_validated", "physical_execution_authorized",
            "physical_acceptance_authority", "release_authority", "physics_state_modified"
        )) {
            Assert-R10fQualification (
                $receipt[$name] -is [bool] -and -not $receipt[$name]
            ) ("L15_OUTPUT_READER_SCOPE:" + $name)
        }
        return $receipt
    } finally {
        # Join any helper owned by this call even if pipe I/O or decoding failed.
        if ($processStarted -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        $process.Dispose()
    }
}


function Assert-ZeroWorldReceipt {
    param([Parameter(Mandatory)][System.Collections.IDictionary]$Receipt)
    Assert-R10fQualification (
        $Receipt.Contains("ok") -and $Receipt.ok -is [bool] -and [bool]$Receipt.ok
    ) "IMPLEMENTATION_NOT_OK"
    foreach ($counter in @(
        "model_construction_count", "world_attempt_count", "world_build_count",
        "scene_tree_insertion_count", "native_readback_count", "solver_step_count"
    )) {
        Assert-R10fQualification (
            $Receipt.Contains($counter) -and
            (Test-ExactJsonIntegerZero $Receipt[$counter])
        ) ("IMPLEMENTATION_NONZERO:" + $counter)
    }
    foreach ($field in @(
        "physics_state_modified", "physical_acceptance_authority", "release_authority"
    )) {
        Assert-R10fQualification (
            $Receipt.Contains($field) -and
            $Receipt[$field] -is [bool] -and
            -not [bool]$Receipt[$field]
        ) ("IMPLEMENTATION_AUTHORITY_DRIFT:" + $field)
    }
}


function Test-ExactJsonSourceValue {
    param([AllowNull()]$Actual, [AllowNull()]$Expected)
    if ($null -eq $Actual -or $null -eq $Expected) {
        return ($null -eq $Actual -and $null -eq $Expected)
    }
    if ($Expected -is [System.Collections.IDictionary]) {
        if ($Actual -isnot [System.Collections.IDictionary] -or
            $Actual.Count -ne $Expected.Count) { return $false }
        foreach ($key in $Expected.Keys) {
            $matchingKeys = @($Actual.Keys | Where-Object { [string]$_ -ceq [string]$key })
            if ($matchingKeys.Count -ne 1 -or
                -not (Test-ExactJsonSourceValue $Actual[$key] $Expected[$key])) { return $false }
        }
        return $true
    }
    if ($Expected -is [System.Collections.IList]) {
        if ($Actual -isnot [System.Collections.IList] -or
            $Actual.Count -ne $Expected.Count) { return $false }
        for ($i = 0; $i -lt $Expected.Count; $i++) {
            if (-not (Test-ExactJsonSourceValue $Actual[$i] $Expected[$i])) { return $false }
        }
        return $true
    }
    if ($Expected -is [bool]) {
        return ($Actual -is [bool] -and $Actual -eq $Expected)
    }
    if ($Expected -is [int] -or $Expected -is [long]) {
        return (($Actual -is [int] -or $Actual -is [long]) -and $Actual -eq $Expected)
    }
    if ($Expected -is [string]) {
        return ($Actual -is [string] -and $Actual -ceq $Expected)
    }
    return ($Actual.GetType() -eq $Expected.GetType() -and $Actual -eq $Expected)
}


function Assert-ImplementationReceipt {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Receipt,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Source,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Policy
    )
    Assert-ZeroWorldReceipt $receipt
    Assert-ZeroWorldReceipt $receipt.root_design_audit
    Assert-ZeroWorldReceipt $receipt.predecessor_qualification_failure_audit
    Assert-QsdkR10fL14RuntimeBinding $receipt.runtime_identity.l14_exact_runtime_images
    $expectedL14 = $script:ExpectedL14ComponentReceiptJson | ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R10fQualification (
        $Receipt.Contains("l14_component_qualification") -and
        (Test-ExactJsonSourceValue $Receipt.l14_component_qualification $expectedL14)
    ) "IMPLEMENTATION_L14_COMPONENT_RECEIPT"
    Assert-R10fQualification (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r10f_zero_world_implementation_audit_v1" -and
        [string]$receipt.status -ceq
            "passed_complete_zero_world_implementation" -and
        [string]$receipt.gate_id -ceq "QSDK-R10F" -and
        [string]$receipt.repair_id -ceq $script:RepairId -and
        [bool]$receipt.source.official_qualification -and
        [string]$receipt.source.source_commit -ceq [string]$source.commit -and
        [string]$receipt.source.source_tree -ceq [string]$source.tree -and
        [bool]$receipt.source.source_clean -and
        [bool]$receipt.source.source_origin_main_equal -and
        [bool]$receipt.source.source_live_main_equal -and
        [int64]$receipt.qualified_source_path_count -eq
            [int64]$policy.expected_qualified_source_count -and
        [string]$receipt.qualified_source_path_sha256 -ceq
            [string]$policy.expected_qualified_source_path_sha256 -and
        [string]$receipt.design_raw_sha256 -ceq $script:ExpectedDesignSha256 -and
        [string]$receipt.root_design_audit.schema_version -ceq
            "sporespore_qsdk_r10f_continuous_passive_recovery_successor_design_audit_v1" -and
        [string]$receipt.root_design_audit.design_raw_sha256 -ceq
            $script:ExpectedDesignSha256 -and
        [string]$receipt.root_design_audit.bound_authority_source_mode -ceq
            "authored_parent_historical_replay_with_explicit_l13_successor_drift" -and
        [int64]$receipt.root_design_audit.current_disk_drift_path_count -eq 1 -and
        @($receipt.root_design_audit.current_disk_drift_paths).Count -eq 1 -and
        [string]$receipt.root_design_audit.current_disk_drift_paths[0] -ceq
            "scripts/lab/gait/sdk_godot_jolt_adapter.gd" -and
        [string]$receipt.root_design_audit.successor_authorization_repair_id -ceq
            "QSDK-R10F-L13" -and
        [string]$receipt.root_design_audit.active_repair_id -ceq
            $script:RepairId -and
        [string]$receipt.root_design_audit.scene_tree_counter_source -ceq
            "successor_zero_world_projection_after_complete_historical_validation" -and
        [string]$receipt.predecessor_qualification_failure_closure_raw_sha256 -ceq
            $script:ExpectedQualificationFailureClosureSha256 -and
        [int64]$receipt.predecessor_qualification_failure_audit.retained_file_count -eq 4 -and
        [int64]$receipt.predecessor_qualification_failure_audit.retained_total_byte_length -eq 28659 -and
        [string]$receipt.repair_design_raw_sha256 -ceq
            $script:ExpectedRepairDesignSha256 -and
        [string]$receipt.branch_completeness_addendum_sha256 -ceq
            $script:ExpectedBranchCompletenessAddendumSha256 -and
        [string]$receipt.superseded_physical_supervisor_refusal_sha256 -ceq
            $script:ExpectedSupervisorRefusalSha256 -and
        [string]$receipt.consumed_predecessor_physical_closure_sha256 -ceq
            $script:ExpectedPredecessorPhysicalClosureSha256 -and
        [int64]$receipt.positive_case_count -eq 24 -and
        [int64]$receipt.forced_failure_case_count -eq 237 -and
        [int64]$receipt.zero_world_receipt.walking_actuation_handoff_positive_control_count -eq 5 -and
        [int64]$receipt.zero_world_receipt.walking_actuation_handoff_mutation_rejection_count -eq 22 -and
        [int64]$receipt.zero_world_receipt.walking_ledger_l13_positive_control_count -eq 15 -and
        [int64]$receipt.zero_world_receipt.walking_ledger_l13_mutation_rejection_count -eq 16 -and
        [int64]$receipt.zero_world_receipt.walking_ledger_failure_retention_positive_control_count -eq 1 -and
        [int64]$receipt.zero_world_receipt.walking_ledger_failure_retention_mutation_rejection_count -eq 15 -and
        [int64]$receipt.zero_world_receipt.production_shaped_l13_walking_fixture_count -eq 3 -and
        [int64]$receipt.zero_world_receipt.detached_l13_hinge_parameter_container_count -eq 24 -and
        [int64]$receipt.zero_world_receipt.qualified_r69_projection_count -eq 8 -and
        -not [bool]$receipt.physical_execution_authorized
    ) "IMPLEMENTATION_RECEIPT_FIELDS"
}


Assert-R10fQualification (
    $script:RepoRoot -ceq $script:ExpectedRoot
) "CANONICAL_ROOT"
Assert-R10fQualification (
    [IO.Path]::GetFullPath($EvidenceRoot) -ceq $script:ExpectedEvidenceRoot
) "EVIDENCE_ROOT_NOT_EXACT"
foreach ($path in @(
    $script:AuditPath,
    $script:ManifestPath,
    $script:DesignPath,
    $script:RepairDesignPath,
    $script:BranchCompletenessAddendumPath,
    $script:SupervisorRefusalPath,
    $script:PredecessorPhysicalClosurePath,
    $script:ActiveAdapterPath,
    $script:OperationLockPath,
    [IO.Path]::GetFullPath($Godot)
)) {
    Assert-R10fQualification (
        Test-Path -LiteralPath $path -PathType Leaf
    ) ("QUALIFICATION_INPUT_MISSING:" + $path)
}
Assert-R10fQualification (
    (Get-PrefixedSha256 $script:DesignPath) -ceq $script:ExpectedDesignSha256
) "DESIGN_SHA256"
Assert-R10fQualification (
    [int64](Get-Item -LiteralPath $script:RepairDesignPath).Length -eq
        $script:ExpectedRepairDesignBytes -and
    (Get-PrefixedSha256 $script:RepairDesignPath) -ceq
        $script:ExpectedRepairDesignSha256
) "REPAIR_DESIGN_BINDING"
Assert-R10fQualification (
    [int64](Get-Item -LiteralPath $script:BranchCompletenessAddendumPath).Length -eq
        $script:ExpectedBranchCompletenessAddendumBytes -and
    (Get-PrefixedSha256 $script:BranchCompletenessAddendumPath) -ceq
        $script:ExpectedBranchCompletenessAddendumSha256
) "BRANCH_COMPLETENESS_ADDENDUM_BINDING"
Assert-R10fQualification (
    [int64](Get-Item -LiteralPath $script:SupervisorRefusalPath).Length -eq
        $script:ExpectedSupervisorRefusalBytes -and
    (Get-PrefixedSha256 $script:SupervisorRefusalPath) -ceq
        $script:ExpectedSupervisorRefusalSha256
) "SUPERSEDED_SUPERVISOR_REFUSAL_BINDING"
Assert-R10fQualification (
    [int64](Get-Item -LiteralPath $script:PredecessorPhysicalClosurePath).Length -eq
        $script:ExpectedPredecessorPhysicalClosureBytes -and
    (Get-PrefixedSha256 $script:PredecessorPhysicalClosurePath) -ceq
        $script:ExpectedPredecessorPhysicalClosureSha256
) "CONSUMED_PREDECESSOR_PHYSICAL_CLOSURE_BINDING"
$pythonCommand = Get-Command -Name $Python -CommandType Application -ErrorAction Stop
$script:PythonPath = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
$script:GodotPath = [IO.Path]::GetFullPath($Godot)
. $script:OperationLockPath

$lock = $null
$rootCreated = $false
$qualificationRoot = ""
$source = $null
$completion = $null
$startedUtc = [DateTime]::UtcNow.ToString("o")
try {
    $lock = Enter-SporeSporeLocomotionOperationLock `
        -Role qualification `
        -TimeoutMilliseconds 0
    Assert-R10fQualification (
        [bool]$lock.acquired -and
        -not [bool]$lock.abandoned_owner_recovered
    ) "LOCOMOTION_OPERATION_LOCK_BUSY"
    $source = Get-CleanLiveSource
    if ($L15) {
        # Validate the same five pinned images before consuming the L15 source.
        $null = Get-QsdkR10fL14RuntimeBinding -Godot $script:GodotPath -PythonExecutable $script:PythonPath
        $prepared = Invoke-L15QualificationLifecycle -Phase prepare -SourceCommit $source.commit
        $qualificationRoot = Join-Path $script:ExpectedEvidenceRoot (
            "qsdk-r10f-l15-zero-world-qualification-" + $source.commit.Substring(0, 12)
        )
        Assert-R10fQualification (
            [IO.Path]::GetFullPath($prepared.output_root) -ceq $qualificationRoot
        ) "L15_QUALIFICATION_PREPARED_PATH"
        $rootCreated = $true
        $execution = Invoke-L15QualificationAudit -OutputRoot $qualificationRoot `
            -FilePath $script:PythonPath -Arguments @(
                "-B", $script:AuditPath, "--godot", $script:GodotPath,
                "--l15-qualification-candidate"
            ) -TimeoutSeconds $TimeoutSeconds
        Assert-R10fQualification (
            $execution.completed -and -not $execution.timed_out -and $execution.exit_code -eq 0
        ) "L15_IMPLEMENTATION_AUDIT_FAILED_OR_TIMED_OUT"
        $completion = Invoke-L15QualificationLifecycle -Phase complete `
            -SourceCommit $source.commit -ExitCode $execution.exit_code
    } else {
    $manifest = Read-JsonHashtable $script:ManifestPath
    $policy = $manifest.policy
    Assert-R10fQualification (
        [string]$manifest.schema_version -ceq
            "sporespore_qsdk_r10f_dependency_manifest_v19" -and
        [string]$manifest.repair_id -ceq $script:RepairId -and
        [string]$manifest.status -ceq
            "prospective_complete_transitive_source_closure_zero_world" -and
        [int64]$policy.expected_qualified_source_count -gt 0 -and
        [string]$policy.expected_qualified_source_path_sha256 -cmatch
            '^sha256:[0-9a-f]{64}$'
    ) "SOURCE_BINDING_NOT_FINALIZED"

    # Resolve and hash the selected images before consuming an official identity.
    $qualificationRuntime = Get-QsdkR10fL14RuntimeBinding -Godot $script:GodotPath -PythonExecutable $script:PythonPath

    $qualificationRoot = Join-Path $script:ExpectedEvidenceRoot (
        "qsdk-r10f-development-route-ghost-zero-world-qualification-" +
        $source.commit.Substring(0, 12)
    )
    Assert-R10fQualification (
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
        schema_version = "sporespore_qsdk_r10f_zero_world_qualification_attempt_v1"
        status = "started_consumed_official_zero_world_qualification"
        gate_id = "QSDK-R10F"
        repair_id = $script:RepairId
        campaign_id = "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = [ordered]@{
            subsystem = "recovery"
            engine_scope = "godot_jolt"
            authority_mode = "official_zero_world_qualification"
            question_class = "development"
        }
        source = $source
        source_commit = [string]$source.commit
        output_root = $qualificationRoot.Replace("\", "/")
        qualified_source_path_count = [int64]$policy.expected_qualified_source_count
        qualified_source_path_sha256 = [string]$policy.expected_qualified_source_path_sha256
        dependency_manifest_raw_sha256 = Get-PrefixedSha256 $script:ManifestPath
        r10f_design_sha256 = $script:ExpectedDesignSha256
        repair_design_sha256 = $script:ExpectedRepairDesignSha256
        branch_completeness_addendum_sha256 = $script:ExpectedBranchCompletenessAddendumSha256
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        consumed_predecessor_physical_closure_sha256 = (
            $script:ExpectedPredecessorPhysicalClosureSha256
        )
        godot = Get-FileBinding $script:GodotPath
        l14_exact_runtime_images = $qualificationRuntime
        active_adapter = Get-FileBinding $script:ActiveAdapterPath -RelativeTo $script:RepoRoot
        operation_lock = Get-SporeSporeLocomotionOperationLockPublicReceipt $lock
        started_utc = $startedUtc
        maximum_official_qualification_attempt_count_for_source = 1
        same_identity_rerun_permitted = $false
        physical_execution_authorized = $false
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
    Write-JsonCreateNew $attemptPath $attempt

    $execution = Invoke-CapturedProcess `
        -FilePath $script:PythonPath `
        -Arguments @(
            "-B", $script:AuditPath,
            "--godot", $script:GodotPath,
            "--official-qualification"
        ) `
        -Environment @{
            $script:QualificationLockEnvironment = "1"
        } `
        -ClearEnvironment $script:PhysicalEnvironmentNames `
        -TimeoutSeconds $TimeoutSeconds
    Write-Utf8CreateNew $stdoutPath ([string]$execution.stdout)
    Write-Utf8CreateNew $stderrPath ([string]$execution.stderr)
    Assert-R10fQualification (
        $execution.completed -and
        -not $execution.timed_out -and
        $execution.exit_code -eq 0
    ) "IMPLEMENTATION_AUDIT_FAILED_OR_TIMED_OUT"
    $receipt = Get-SingleMarkerJson $execution.stdout $script:PassMarker
    Assert-ImplementationReceipt -Receipt $receipt -Source $source -Policy $policy
    Assert-R10fQualification (
        Test-QsdkR10fL14RuntimeValue $qualificationRuntime $receipt.runtime_identity.l14_exact_runtime_images
    ) "L14_RUNTIME_CHANGED_DURING_QUALIFICATION"
    Write-JsonCreateNew $implementationPath $receipt
    Write-JsonCreateNew $runtimePath $receipt.runtime_identity

    $completion = [ordered]@{
        schema_version = "sporespore_qsdk_r10f_zero_world_qualification_completion_v1"
        status = "closed_passing_official_zero_world_qualification"
        gate_id = "QSDK-R10F"
        repair_id = $script:RepairId
        campaign_id = "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
        campaign_role = "development_route_ghost"
        question_class = "development"
        ledger_scope = [ordered]@{
            subsystem = "recovery"
            engine_scope = "godot_jolt"
            authority_mode = "official_zero_world_qualification"
            question_class = "development"
        }
        source_commit = [string]$source.commit
        source_tree = [string]$source.tree
        output_root = $qualificationRoot.Replace("\", "/")
        qualified_source_path_count = [int64]$policy.expected_qualified_source_count
        qualified_source_path_sha256 = [string]$policy.expected_qualified_source_path_sha256
        dependency_manifest_raw_sha256 = Get-PrefixedSha256 $script:ManifestPath
        r10f_design_sha256 = $script:ExpectedDesignSha256
        repair_design_sha256 = $script:ExpectedRepairDesignSha256
        branch_completeness_addendum_sha256 = $script:ExpectedBranchCompletenessAddendumSha256
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        consumed_predecessor_physical_closure_sha256 = (
            $script:ExpectedPredecessorPhysicalClosureSha256
        )
        qualification_attempt = Get-FileBinding $attemptPath
        implementation_audit = Get-FileBinding $implementationPath
        runtime_identity = Get-FileBinding $runtimePath
        l14_exact_runtime_images = $qualificationRuntime
        qualification_stdout = Get-FileBinding $stdoutPath
        qualification_stderr = Get-FileBinding $stderrPath
        official_zero_world_qualification_passed = $true
        physical_execution_authorized_by_qualification = $false
        same_identity_rerun_permitted = $false
        completed_utc = [DateTime]::UtcNow.ToString("o")
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
    Write-JsonCreateNew $completionPath $completion
    }
} catch {
    $qualificationError = [string]$_.Exception.Message
    if ($rootCreated) {
        $failurePath = Join-Path $qualificationRoot "qualification_failure.json"
        if (-not (Test-Path -LiteralPath $failurePath)) {
            $failure = [ordered]@{
                schema_version = "sporespore_qsdk_r10f_zero_world_qualification_failure_v1"
                status = "closed_failed_consumed_official_zero_world_qualification"
                gate_id = "QSDK-R10F"
                repair_id = if ($L15) { "QSDK-R10F-L15" } else { $script:RepairId }
                source_commit = if ($null -eq $source) { "" } else { [string]$source.commit }
                output_root = $qualificationRoot.Replace("\", "/")
                failure_code = $qualificationError
                same_identity_rerun_permitted = $false
                physical_execution_authorized = $false
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
            try { Write-JsonCreateNew $failurePath $failure } catch { }
        }
    }
    throw $qualificationError
} finally {
    if (
        $null -ne $lock -and
        [bool]$lock.acquired -and
        -not [bool]$lock.released
    ) {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
}

Write-Output (
    $(if ($L15) { "QSDK_R10F_L15_ZERO_WORLD_QUALIFICATION_COMPLETE " } else { $script:CompletionMarker }) +
    ($completion | ConvertTo-Json -Compress -Depth 100)
)
