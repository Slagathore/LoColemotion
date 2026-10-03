#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet("ZeroWorld", "AuthorityCheck", "Physical")]
    [string]$Mode = "ZeroWorld",
    [ValidateSet("development_route_ghost", "held_out_finite_decision")]
    [string]$CampaignRole = "development_route_ghost",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$Python = "python",
    [ValidateRange(30, 3600)]
    [int]$CellTimeoutSeconds = 900,
    [switch]$AuthorizePhysical
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$script:RepoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$script:ExpectedRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore"
)
$script:ExpectedRemote = "https://github.com/Slagathore/sporespore.git"
$script:EvidenceRoot = [IO.Path]::GetFullPath(
    "C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence"
)
$script:WorkerScript = (
    "res://tests/test_sdk_qsdk_r10e_" +
    "observer_minimized_upright_push_recovery_worker.gd"
)
$script:SourceScript = (
    "res://tests/test_sdk_qsdk_r10e_" +
    "observer_minimized_upright_push_recovery_source.gd"
)
$script:DeferredTraceTest = (
    "res://tests/test_sdk_qsdk_r10e_deferred_recovery_trace_zero_world.gd"
)
$script:ScalarReceiptTest = (
    "res://tests/test_sdk_qsdk_r10e_" +
    "native_impulse_scalar_receipt_validation_zero_world.gd"
)
$script:DependencyAudit = Join-Path (
    $script:RepoRoot
) "sdk\conformance\qsdk_r10e_dependency_closure.py"
$script:PhysicalClosureAudit = Join-Path (
    $script:RepoRoot
) "sdk\conformance\qsdk_r10e_physical_closure.py"
$script:OperationLockPath = Join-Path (
    $script:RepoRoot
) "sdk\locomotion_operation_lock.ps1"
$script:AdapterPath = Join-Path (
    $script:RepoRoot
) "sdk\target\debug\sporespore_godot_adapter.dll"
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
$script:ExpectedSupervisorRefusalPath = (
    "sdk/qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json"
)
$script:ExpectedSupervisorRefusalBytes = 5728
$script:ExpectedL2HeldOutFailureClosureSha256 = (
    "sha256:29942c4f666d3cc7d88388945bb450d6d64f01a6757f72f7a38e149b5d351211"
)
$script:ExpectedL2HeldOutFailureClosurePath = (
    "sdk/qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json"
)
$script:ExpectedL2HeldOutFailureClosureBytes = 14311

# Installed with the final recursive dependency closure.
$script:ExpectedSourceCount = 91
$script:ExpectedSourcePathSha256 = (
    "sha256:348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67"
)

$script:Roles = @{
    development_route_ghost = [ordered]@{
        repair_id = "QSDK-R10E-L2"
        physical_execution_permitted = $false
        qualification_completion_schema = (
            "sporespore_qsdk_r10e_zero_world_qualification_completion_v1"
        )
        stage_schema = "sporespore_qsdk_r10e_stage_freeze_v2"
        authority_schema = "sporespore_qsdk_r10e_execution_authority_v2"
        campaign_start_schema = "sporespore_qsdk_r10e_physical_campaign_start_v1"
        campaign_report_schema = "sporespore_qsdk_r10e_physical_campaign_report_v1"
        campaign_id = (
            "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-ROUTE-GHOST"
        )
        question_class = "development"
        seeds = @(40002)
        ordered_cell_ids = @("baseline_s40002", "push_s40002")
        stage_path = (
            "sdk/qsdk_r10e_development_route_ghost_" +
            "zero_world_qualification_closure_v2.json"
        )
        authority_path = (
            "sdk/qsdk_r10e_development_route_ghost_execution_authority_v2.json"
        )
        physical_closure_path = (
            "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json"
        )
        output_slug = "development-route-ghost"
    }
    held_out_finite_decision = [ordered]@{
        repair_id = "QSDK-R10E-L3"
        physical_execution_permitted = $true
        qualification_completion_schema = (
            "sporespore_qsdk_r10e_zero_world_qualification_completion_v2"
        )
        stage_schema = "sporespore_qsdk_r10e_stage_freeze_v3"
        authority_schema = "sporespore_qsdk_r10e_execution_authority_v3"
        campaign_start_schema = "sporespore_qsdk_r10e_physical_campaign_start_v2"
        campaign_report_schema = "sporespore_qsdk_r10e_physical_campaign_report_v2"
        campaign_id = (
            "QSDK-R10E-OBSERVER-MINIMIZED-UPRIGHT-PUSH-RECOVERY-VALIDATION"
        )
        question_class = "finite decision"
        seeds = @(40101, 40102, 40103)
        ordered_cell_ids = @(
            "baseline_s40101", "push_s40101",
            "baseline_s40102", "push_s40102",
            "baseline_s40103", "push_s40103"
        )
        stage_path = (
            "sdk/qsdk_r10e_held_out_finite_decision_" +
            "zero_world_qualification_closure_v3.json"
        )
        authority_path = (
            "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v3.json"
        )
        physical_closure_path = (
            "sdk/qsdk_r10e_held_out_finite_decision_physical_closure_v3.json"
        )
        output_slug = "held-out-finite-decision"
    }
}

$script:SourceMarker = (
    "QSDK_R10E_OBSERVER_MINIMIZED_UPRIGHT_PUSH_RECOVERY_SOURCE_ZERO_WORLD "
)
$script:ContractMarker = "QSDK_R10E_WORKER_CONTRACT_ZERO_WORLD "
$script:PreflightMarker = "QSDK_R10E_WORKER_ENTRYPOINT_ZERO_WORLD "
$script:CellMarker = "QSDK_R10E_PHYSICAL_CELL "
$script:PairMarker = "QSDK_R10E_PAIR_EVALUATION_ZERO_WORLD "
$script:DependencyMarker = "QSDK_R10E_DEPENDENCY_CLOSURE_PASS "
$script:ReportAuditMarker = "QSDK_R10E_PHYSICAL_REPORT_AUDIT_PASS "
$script:ZeroWorldMarker = "QSDK_R10E_SUPERVISOR_ZERO_WORLD_PASS "
$script:AuthorityMarker = "QSDK_R10E_SUPERVISOR_AUTHORITY_CHECK_PASS "
$script:PhysicalMarker = "QSDK_R10E_SUPERVISOR_PHYSICAL_CLOSED "
$script:AttemptEnvironment = "SPORESPORE_QSDK_R10E_ATTEMPT"
$script:TokenEnvironment = "SPORESPORE_QSDK_R10E_TOKEN"


function Assert-R10e {
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


function Get-Sha256 {
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
    $item = Get-Item -LiteralPath $resolved
    return [ordered]@{
        path = $display
        byte_length = [long]$item.Length
        raw_sha256 = Get-Sha256 -Path $resolved
    }
}


function Read-JsonObject {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Label
    )
    Assert-R10e (Test-Path -LiteralPath $Path -PathType Leaf) ($Label + "_MISSING")
    try {
        return Get-Content -Raw -LiteralPath $Path -Encoding UTF8 | ConvertFrom-Json -Depth 100
    } catch {
        throw ($Label + "_UNREADABLE:" + $_.Exception.Message)
    }
}


function Write-NewJson {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )
    Assert-R10e (-not (Test-Path -LiteralPath $Path)) "OUTPUT_ALREADY_EXISTS"
    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    $json = $Value | ConvertTo-Json -Depth 100
    [IO.File]::WriteAllText(
        [IO.Path]::GetFullPath($Path),
        $json.Replace("`r`n", "`n") + "`n",
        [Text.UTF8Encoding]::new($false)
    )
}


function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [hashtable]$Environment = @{},
        [string[]]$ClearEnvironment = @(),
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 120
    )
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $FilePath
    $info.WorkingDirectory = $script:RepoRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $null = $info.ArgumentList.Add($argument) }
    foreach ($name in $ClearEnvironment) { $null = $info.Environment.Remove($name) }
    foreach ($name in $Environment.Keys) {
        $info.Environment[[string]$name] = [string]$Environment[$name]
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    $startedUtc = [DateTime]::UtcNow
    Assert-R10e $process.Start() "PROCESS_START_FAILED"
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        try { $process.Kill($true) } catch {}
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($completed) { [int]$process.ExitCode } else { $null }
    $process.Dispose()
    return [ordered]@{
        completed = [bool]$completed
        timed_out = -not [bool]$completed
        exit_code = $exitCode
        started_utc = $startedUtc.ToString("o")
        completed_utc = [DateTime]::UtcNow.ToString("o")
        stdout = [string]$stdout
        stderr = [string]$stderr
    }
}


function Get-MarkerJson {
    param(
        [Parameter(Mandatory)][string]$Stdout,
        [Parameter(Mandatory)][string]$Marker,
        [Parameter(Mandatory)][string]$Label
    )
    $matches = @(
        $Stdout -split "`r?`n" | Where-Object { $_.StartsWith($Marker) }
    )
    Assert-R10e ($matches.Count -eq 1) ($Label + "_MARKER_COUNT")
    $json = $matches[0].Substring($Marker.Length)
    try {
        $receipt = $json | ConvertFrom-Json -Depth 100
    } catch {
        throw ($Label + "_MARKER_JSON:" + $_.Exception.Message)
    }
    return [ordered]@{ json = $json; receipt = $receipt }
}


function Invoke-GodotScript {
    param(
        [Parameter(Mandatory)][string]$Script,
        [string[]]$UserArguments = @(),
        [hashtable]$Environment = @{},
        [ValidateRange(1, 7200)][int]$TimeoutSeconds = 120
    )
    Assert-R10e (Test-Path -LiteralPath $Godot -PathType Leaf) "GODOT_CONSOLE_MISSING"
    $arguments = @("--headless", "--path", $script:RepoRoot, "--script", $Script)
    if ($UserArguments.Count -gt 0) { $arguments += "--"; $arguments += $UserArguments }
    $invocation = @{
        FilePath = $Godot
        Arguments = $arguments
        Environment = $Environment
        ClearEnvironment = @($script:AttemptEnvironment, $script:TokenEnvironment)
        TimeoutSeconds = $TimeoutSeconds
    }
    return Invoke-CapturedProcess @invocation
}


function Invoke-GitText {
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowEmpty
    )
    $result = Invoke-CapturedProcess -FilePath "git" -Arguments (@("-C", $script:RepoRoot) + $Arguments)
    Assert-R10e ($result.completed -and $result.exit_code -eq 0) (
        "GIT_FAILED:" + ($Arguments -join " ")
    )
    $value = $result.stdout.Trim()
    Assert-R10e ($AllowEmpty -or $value.Length -gt 0) (
        "GIT_EMPTY:" + ($Arguments -join " ")
    )
    return $value
}


function Assert-RepositoryIdentity {
    param([switch]$RequireCleanLive)
    Assert-R10e ($script:RepoRoot -ceq $script:ExpectedRoot) "CANONICAL_ROOT"
    $top = [IO.Path]::GetFullPath((Invoke-GitText @("rev-parse", "--show-toplevel")))
    Assert-R10e ($top -ceq $script:ExpectedRoot) "GIT_TOPLEVEL"
    Assert-R10e (
        (Invoke-GitText @("remote", "get-url", "origin")) -ceq $script:ExpectedRemote
    ) "REMOTE"
    $head = Invoke-GitText @("rev-parse", "HEAD")
    $origin = Invoke-GitText @("rev-parse", "origin/main")
    $branch = Invoke-GitText @("branch", "--show-current")
    $status = Invoke-GitText @(
        "status", "--porcelain=v1", "--untracked-files=all"
    ) -AllowEmpty
    $live = ""
    if ($RequireCleanLive) {
        $liveResult = Invoke-CapturedProcess -FilePath "git" -Arguments @(
            "-C", $script:RepoRoot, "ls-remote", "origin", "refs/heads/main"
        ) -TimeoutSeconds 60
        Assert-R10e (
            $liveResult.completed -and $liveResult.exit_code -eq 0
        ) "LIVE_MAIN_QUERY"
        $parts = @($liveResult.stdout.Trim() -split "\s+")
        Assert-R10e (
            $parts.Count -eq 2 -and $parts[1] -ceq "refs/heads/main"
        ) "LIVE_MAIN_FORMAT"
        $live = $parts[0]
        Assert-R10e (
            $branch -ceq "main" -and
            $status.Length -eq 0 -and
            $head -ceq $origin -and
            $head -ceq $live
        ) "CLEAN_LIVE_MAIN_REQUIRED"
    }
    return [ordered]@{
        source_commit = $head
        source_tree = Invoke-GitText @("rev-parse", "HEAD^{tree}")
        branch = $branch
        clean = $status.Length -eq 0
        origin_main = $origin
        live_main = $live
    }
}


function Assert-ZeroWorldReceipt {
    param(
        [Parameter(Mandatory)][object]$Receipt,
        [Parameter(Mandatory)][string]$Label,
        [switch]$AllowFailure
    )
    if (-not $AllowFailure) {
        Assert-R10e (
            (Test-ObjectProperty $Receipt "ok") -and
            $Receipt.ok -is [bool] -and
            [bool]$Receipt.ok
        ) ($Label + "_NOT_OK")
    }
    foreach ($field in @(
        "model_construction_count", "world_attempt_count", "world_build_count",
        "scene_tree_insertion_count", "native_readback_count", "solver_step_count"
    )) {
        Assert-R10e (
            (Test-ObjectProperty $Receipt $field) -and
            (Test-ExactJsonIntegerZero $Receipt.$field)
        ) ($Label + "_" + $field)
    }
    foreach ($field in @(
        "physics_state_modified", "physical_acceptance_authority", "release_authority"
    )) {
        Assert-R10e (
            (Test-ObjectProperty $Receipt $field) -and
            $Receipt.$field -is [bool] -and
            -not [bool]$Receipt.$field
        ) ($Label + "_" + $field)
    }
}


function Invoke-ZeroWorldJsonGate {
    param(
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Marker,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$Label
    )
    $result = Invoke-GodotScript -Script $Script -UserArguments $Arguments
    Assert-R10e (
        $result.completed -and $result.exit_code -eq 0
    ) ($Label + "_PROCESS")
    $parsed = Get-MarkerJson -Stdout $result.stdout -Marker $Marker -Label $Label
    Assert-ZeroWorldReceipt -Receipt $parsed.receipt -Label $Label
    return $parsed.receipt
}


function Invoke-ZeroWorldMarkerGate {
    param(
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string]$Marker,
        [Parameter(Mandatory)][string]$Label
    )
    $result = Invoke-GodotScript -Script $Script
    Assert-R10e (
        $result.completed -and $result.exit_code -eq 0
    ) ($Label + "_PROCESS")
    $matches = @($result.stdout -split "`r?`n" | Where-Object { $_ -ceq $Marker })
    Assert-R10e ($matches.Count -eq 1) ($Label + "_MARKER")
    return [ordered]@{ ok = $true; marker = $Marker }
}


function Invoke-DependencyAudit {
    param([switch]$RequireTracked)
    $arguments = @("-B", $script:DependencyAudit)
    if ($RequireTracked) { $arguments += "--require-tracked" }
    $result = Invoke-CapturedProcess -FilePath $Python -Arguments $arguments
    Assert-R10e (
        $result.completed -and $result.exit_code -eq 0
    ) "DEPENDENCY_AUDIT_PROCESS"
    $parsed = Get-MarkerJson -Stdout $result.stdout -Marker $script:DependencyMarker -Label "DEPENDENCY"
    Assert-ZeroWorldReceipt -Receipt $parsed.receipt -Label "DEPENDENCY"
    Assert-R10e (
        [bool]$parsed.receipt.qualification_finalized -and
        [int]$parsed.receipt.qualified_source_path_count -eq $script:ExpectedSourceCount -and
        [string]$parsed.receipt.qualified_source_path_sha256 -ceq (
            $script:ExpectedSourcePathSha256
        )
    ) "DEPENDENCY_BINDING"
    return $parsed.receipt
}


function Invoke-SupervisorZeroWorld {
    Assert-R10e (-not $AuthorizePhysical) "ZERO_WORLD_PHYSICAL_SWITCH_FORBIDDEN"
    $repo = Assert-RepositoryIdentity
    $source = Invoke-ZeroWorldJsonGate -Script $script:SourceScript -Marker $script:SourceMarker -Label "SOURCE"
    $deferred = Invoke-ZeroWorldMarkerGate -Script $script:DeferredTraceTest -Marker "QSDK_R10E_DEFERRED_RECOVERY_TRACE_ZERO_WORLD_PASS" -Label "DEFERRED_TRACE"
    $scalar = Invoke-ZeroWorldMarkerGate -Script $script:ScalarReceiptTest -Marker "QSDK_R10E_NATIVE_IMPULSE_SCALAR_RECEIPT_ZERO_WORLD_PASS" -Label "SCALAR_RECEIPT"
    $contract = Invoke-ZeroWorldJsonGate -Script $script:WorkerScript -Marker $script:ContractMarker -Arguments @("contract") -Label "WORKER_CONTRACT"
    $preflights = @()
    foreach ($role in @("development_route_ghost", "held_out_finite_decision")) {
        $preflightArguments = @{
            Script = $script:WorkerScript
            Marker = $script:PreflightMarker
            Arguments = @("preflight", $role)
            Label = "PREFLIGHT_" + $role
        }
        $preflights += Invoke-ZeroWorldJsonGate @preflightArguments
    }
    $physicalClosurePaths = @(
        [string]$script:Roles.development_route_ghost.physical_closure_path,
        [string]$script:Roles.held_out_finite_decision.physical_closure_path
    )
    Assert-ExactStringSequence -Actual $physicalClosurePaths -Expected @(
        "sdk/qsdk_r10e_development_route_ghost_physical_closure_v2.json",
        "sdk/qsdk_r10e_held_out_finite_decision_physical_closure_v3.json"
    ) -Code "PHYSICAL_CLOSURE_PATH_SELECTION"
    $historicalBypass = Invoke-GodotScript -Script $script:WorkerScript -UserArguments @(
        "physical", "development_route_ghost", "matched_no_impulse_control", "40002"
    )
    Assert-R10e (
        $historicalBypass.completed -and $historicalBypass.exit_code -ne 0
    ) "HISTORICAL_DEVELOPMENT_BYPASS_PROCESS"
    $historicalBypassParsed = Get-MarkerJson `
        -Stdout $historicalBypass.stdout `
        -Marker $script:CellMarker `
        -Label "HISTORICAL_DEVELOPMENT_BYPASS"
    Assert-ZeroWorldReceipt `
        -Receipt $historicalBypassParsed.receipt `
        -Label "HISTORICAL_DEVELOPMENT_BYPASS" `
        -AllowFailure
    Assert-R10e (
        [string]$historicalBypassParsed.receipt.failure_code -ceq (
            "QSDK_R10E_HISTORICAL_DEVELOPMENT_ROUTE_RERUN_FORBIDDEN"
        )
    ) "HISTORICAL_DEVELOPMENT_BYPASS_FAILURE_CODE"
    $bypass = Invoke-GodotScript -Script $script:WorkerScript -UserArguments @(
        "physical", "held_out_finite_decision", "matched_no_impulse_control", "40101"
    )
    Assert-R10e (
        $bypass.completed -and $bypass.exit_code -ne 0
    ) "CURRENT_HELD_OUT_BYPASS_PROCESS"
    $bypassParsed = Get-MarkerJson `
        -Stdout $bypass.stdout `
        -Marker $script:CellMarker `
        -Label "CURRENT_HELD_OUT_BYPASS"
    Assert-ZeroWorldReceipt `
        -Receipt $bypassParsed.receipt `
        -Label "CURRENT_HELD_OUT_BYPASS" `
        -AllowFailure
    Assert-R10e (
        [string]$bypassParsed.receipt.failure_code -ceq (
            "QSDK_R10E_PHYSICAL_AUTHORIZATION_REQUIRED"
        )
    ) "CURRENT_HELD_OUT_BYPASS_FAILURE_CODE"
    $dependency = Invoke-DependencyAudit
    $emptyPopulationTerminalization = Test-EmptyPopulationTerminalization
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10e_supervisor_zero_world_v1"
        gate_id = "QSDK-R10E"
        repair_id = "QSDK-R10E-L3"
        ledger_scope = [ordered]@{
            subsystem = "recovery"
            engine_scope = "godot_jolt"
            authority_mode = "zero_world_supervisor_qualification"
            question_class = "development"
        }
        ok = $true
        failure_code = ""
        source_commit = $repo.source_commit
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        l2_held_out_failure_closure_sha256 = (
            $script:ExpectedL2HeldOutFailureClosureSha256
        )
        source_gate = $source
        deferred_trace_gate = $deferred
        scalar_receipt_gate = $scalar
        worker_contract = $contract
        entrypoint_preflights = $preflights
        physical_closure_path_controls = $physicalClosurePaths
        physical_closure_path_control_count = $physicalClosurePaths.Count
        direct_physical_bypass_refused = $true
        direct_physical_bypass_failure_code = [string]$bypassParsed.receipt.failure_code
        historical_development_route_bypass_refused = $true
        historical_development_route_bypass_failure_code = (
            [string]$historicalBypassParsed.receipt.failure_code
        )
        empty_population_terminalization = $emptyPopulationTerminalization
        dependency_closure = $dependency
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
}


function Assert-ExactStringSequence {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][object[]]$Expected,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R10e ($Actual.Count -eq $Expected.Count) ($Code + "_COUNT")
    for ($index = 0; $index -lt $Expected.Count; $index++) {
        Assert-R10e (
            [string]$Actual[$index] -ceq [string]$Expected[$index]
        ) ($Code + "_ORDER")
    }
}


function Assert-ExactStringSet {
    param(
        [Parameter(Mandatory)][object[]]$Actual,
        [Parameter(Mandatory)][object[]]$Expected,
        [Parameter(Mandatory)][string]$Code
    )
    $actualSorted = @(
        $Actual | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive
    )
    $expectedSorted = @(
        $Expected | ForEach-Object { [string]$_ } | Sort-Object -CaseSensitive
    )
    Assert-ExactStringSequence `
        -Actual $actualSorted `
        -Expected $expectedSorted `
        -Code $Code
}


function Get-ChangedPaths {
    param([Parameter(Mandatory)][string]$Commit)
    $text = Invoke-GitText @(
        "diff-tree", "--no-commit-id", "--name-only", "--no-renames", "-r", $Commit
    ) -AllowEmpty
    if (-not $text) { return @() }
    return @($text -split "`r?`n")
}


function Get-CurrentRuntimeProjection {
    param([Parameter(Mandatory)][string]$SourceCommit)
    Assert-R10e (Test-Path -LiteralPath $Godot -PathType Leaf) "GODOT_CONSOLE_MISSING"
    Assert-R10e (
        Test-Path -LiteralPath $script:AdapterPath -PathType Leaf
    ) "ACTIVE_ADAPTER_MISSING"
    $godotVersion = Invoke-CapturedProcess -FilePath $Godot -Arguments @("--version") -TimeoutSeconds 30
    Assert-R10e (
        $godotVersion.completed -and $godotVersion.exit_code -eq 0
    ) "GODOT_VERSION_FAILED"
    $pythonCommand = Get-Command `
        -Name $Python `
        -CommandType Application `
        -ErrorAction Stop
    $pythonPath = [IO.Path]::GetFullPath([string]$pythonCommand.Source)
    $pwshCommand = Get-Command `
        -Name "pwsh" `
        -CommandType Application `
        -ErrorAction Stop
    $pwshPath = [IO.Path]::GetFullPath([string]$pwshCommand.Source)
    $pythonVersion = Invoke-CapturedProcess `
        -FilePath $pythonPath `
        -Arguments @("--version") `
        -TimeoutSeconds 30
    Assert-R10e (
        $pythonVersion.completed -and $pythonVersion.exit_code -eq 0
    ) "PYTHON_VERSION_FAILED"
    $powershellVersion = Invoke-CapturedProcess `
        -FilePath $pwshPath `
        -Arguments @(
            "-NoLogo", "-NoProfile", "-Command",
            '$PSVersionTable.PSVersion.ToString()'
        ) `
        -TimeoutSeconds 30
    Assert-R10e (
        $powershellVersion.completed -and $powershellVersion.exit_code -eq 0
    ) "POWERSHELL_VERSION_FAILED"
    $godotItem = Get-Item -LiteralPath $Godot
    $adapterItem = Get-Item -LiteralPath $script:AdapterPath
    $pythonItem = Get-Item -LiteralPath $pythonPath
    $pwshItem = Get-Item -LiteralPath $pwshPath
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10e_runtime_identity_projection_v1"
        source_commit = $SourceCommit
        godot_console_path = [IO.Path]::GetFullPath($Godot).Replace("\", "/")
        godot_console_byte_length = [long]$godotItem.Length
        godot_console_raw_sha256 = Get-Sha256 -Path $Godot
        godot_version = @(
            ($godotVersion.stdout + $godotVersion.stderr).Trim() -split "`r?`n"
        ) -join " "
        active_adapter_path = "sdk/target/debug/sporespore_godot_adapter.dll"
        active_adapter_byte_length = [long]$adapterItem.Length
        active_adapter_raw_sha256 = Get-Sha256 -Path $script:AdapterPath
        python_path = $pythonPath.Replace("\", "/")
        python_byte_length = [long]$pythonItem.Length
        python_raw_sha256 = Get-Sha256 -Path $pythonPath
        python_version = @(
            ($pythonVersion.stdout + $pythonVersion.stderr).Trim() -split "`r?`n"
        ) -join " "
        powershell_path = $pwshPath.Replace("\", "/")
        powershell_byte_length = [long]$pwshItem.Length
        powershell_raw_sha256 = Get-Sha256 -Path $pwshPath
        powershell_version = @(
            ($powershellVersion.stdout + $powershellVersion.stderr).Trim() -split "`r?`n"
        ) -join " "
        runtime_identity_complete = $true
    }
}


function Assert-QualifiedRuntimeCurrent {
    param(
        [Parameter(Mandatory)][object]$Recorded,
        [Parameter(Mandatory)][object]$Current
    )
    Assert-R10e (
        [string]$Recorded.schema_version -ceq "sporespore_qsdk_r10e_runtime_identity_v1" -and
        [string]$Recorded.source_commit -ceq [string]$Current.source_commit -and
        [string]$Recorded.godot_console.path -ceq [string]$Current.godot_console_path -and
        [int64]$Recorded.godot_console.byte_length -eq [int64]$Current.godot_console_byte_length -and
        [string]$Recorded.godot_console.raw_sha256 -ceq [string]$Current.godot_console_raw_sha256 -and
        [string]$Recorded.godot_console.version -ceq [string]$Current.godot_version -and
        [string]$Recorded.active_adapter.path -ceq [string]$Current.active_adapter_path -and
        [int64]$Recorded.active_adapter.byte_length -eq [int64]$Current.active_adapter_byte_length -and
        [string]$Recorded.active_adapter.raw_sha256 -ceq [string]$Current.active_adapter_raw_sha256 -and
        [string]$Recorded.python.path -ceq [string]$Current.python_path -and
        [int64]$Recorded.python.byte_length -eq [int64]$Current.python_byte_length -and
        [string]$Recorded.python.raw_sha256 -ceq [string]$Current.python_raw_sha256 -and
        [string]$Recorded.python_version -ceq [string]$Current.python_version -and
        [string]$Recorded.powershell.path -ceq [string]$Current.powershell_path -and
        [int64]$Recorded.powershell.byte_length -eq [int64]$Current.powershell_byte_length -and
        [string]$Recorded.powershell.raw_sha256 -ceq [string]$Current.powershell_raw_sha256 -and
        [string]$Recorded.powershell_version -ceq [string]$Current.powershell_version -and
        [bool]$Recorded.runtime_identity_complete
    ) "QUALIFIED_RUNTIME_DRIFT"
}


function Assert-BoundFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Binding,
        [Parameter(Mandatory)][string]$Code
    )
    Assert-R10e (Test-Path -LiteralPath $Path -PathType Leaf) ($Code + "_MISSING")
    $item = Get-Item -LiteralPath $Path
    Assert-R10e (
        [int64]$Binding.byte_length -eq [int64]$item.Length -and
        [string]$Binding.raw_sha256 -ceq (Get-Sha256 -Path $Path)
    ) ($Code + "_IDENTITY")
}


function Get-QualifiedPhysicalAuthority {
    param([switch]$RequireUnusedOutput)
    Assert-R10e (
        $script:ExpectedSourceCount -gt 0 -and
        $script:ExpectedSourcePathSha256 -cmatch '^sha256:[0-9a-f]{64}$'
    ) "IMPLEMENTATION_QUALIFICATION_NOT_FINALIZED"
    $repo = Assert-RepositoryIdentity -RequireCleanLive
    $spec = $script:Roles[$CampaignRole]
    $authorityRelative = [string]$spec.authority_path
    $stageRelative = [string]$spec.stage_path
    $authorityPath = [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $authorityRelative))
    $stagePath = [IO.Path]::GetFullPath((Join-Path $script:RepoRoot $stageRelative))
    Assert-R10e (Test-Path -LiteralPath $authorityPath -PathType Leaf) "AUTHORITY_MISSING"
    Assert-R10e (Test-Path -LiteralPath $stagePath -PathType Leaf) "STAGE_FREEZE_MISSING"
    $authorizationCommit = [string]$repo.source_commit
    Assert-ExactStringSequence -Actual @(Get-ChangedPaths -Commit $authorizationCommit) -Expected @($authorityRelative) -Code "AUTHORITY_COMMIT_PATH"
    $stageCommit = Invoke-GitText @("rev-parse", "HEAD^")
    Assert-ExactStringSequence -Actual @(Get-ChangedPaths -Commit $stageCommit) -Expected @($stageRelative) -Code "STAGE_COMMIT_PATH"
    $authority = Read-JsonObject -Path $authorityPath -Label "AUTHORITY"
    $stage = Read-JsonObject -Path $stagePath -Label "STAGE"
    $sourceCommit = [string]$stage.source_commit
    Assert-R10e ($sourceCommit -cmatch '^[0-9a-f]{40}$') "SOURCE_COMMIT_FORMAT"
    Assert-R10e (
        (Invoke-GitText @("rev-parse", ($stageCommit + "^"))) -ceq $sourceCommit
    ) "STAGE_PARENT_NOT_SOURCE"
    $diffFromSource = @(
        (Invoke-GitText @(
            "diff", "--name-only", "--no-renames", ($sourceCommit + ".." + $authorizationCommit)
        )) -split "`r?`n"
    )
    Assert-ExactStringSet `
        -Actual $diffFromSource `
        -Expected @($stageRelative, $authorityRelative) `
        -Code "ORDINAL_AUTHORITY_PATHS"
    Assert-R10e (
        [string]$stage.schema_version -ceq [string]$spec.stage_schema -and
        [string]$stage.status -ceq "closed_passing_official_zero_world_qualification" -and
        [string]$stage.gate_id -ceq "QSDK-R10E" -and
        [string]$stage.repair_id -ceq [string]$spec.repair_id -and
        [string]$stage.campaign_id -ceq [string]$spec.campaign_id -and
        [string]$stage.campaign_role -ceq $CampaignRole -and
        [string]$stage.question_class -ceq [string]$spec.question_class -and
        [string]$stage.qualification_parent_commit -ceq $sourceCommit -and
        [int]$stage.qualified_source_path_count -eq $script:ExpectedSourceCount -and
        [string]$stage.qualified_source_path_sha256 -ceq $script:ExpectedSourcePathSha256 -and
        [string]$stage.r10e_design_sha256 -ceq $script:ExpectedDesignSha256 -and
        [string]$stage.r10d_development_closure_sha256 -ceq $script:ExpectedR10dDevelopmentSha256 -and
        [string]$stage.r10d_held_out_closure_sha256 -ceq $script:ExpectedR10dHeldOutSha256 -and
        [string]$stage.r05e_physical_closure_sha256 -ceq $script:ExpectedR05eSha256 -and
        [string]$stage.superseded_physical_supervisor_refusal.raw_sha256 -ceq (
            $script:ExpectedSupervisorRefusalSha256
        ) -and
        [string]$stage.superseded_physical_supervisor_refusal.path -ceq (
            $script:ExpectedSupervisorRefusalPath
        ) -and
        [int64]$stage.superseded_physical_supervisor_refusal.byte_length -eq (
            $script:ExpectedSupervisorRefusalBytes
        ) -and
        [string]$stage.superseded_physical_supervisor_refusal.status -ceq
            "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed" -and
        [string]$stage.superseded_physical_supervisor_refusal.repair_id -ceq
            "QSDK-R10E-L2" -and
        -not [bool]$stage.superseded_physical_supervisor_refusal.physical_attempt_identity_consumed -and
        [int]$stage.superseded_physical_supervisor_refusal.world_attempt_count -eq 0 -and
        [int]$stage.superseded_physical_supervisor_refusal.world_build_count -eq 0 -and
        [int]$stage.superseded_physical_supervisor_refusal.solver_step_count -eq 0 -and
        [string]$stage.consumed_l2_held_out_failure_closure.path -ceq
            $script:ExpectedL2HeldOutFailureClosurePath -and
        [int64]$stage.consumed_l2_held_out_failure_closure.byte_length -eq
            $script:ExpectedL2HeldOutFailureClosureBytes -and
        [string]$stage.consumed_l2_held_out_failure_closure.raw_sha256 -ceq
            $script:ExpectedL2HeldOutFailureClosureSha256 -and
        [string]$stage.consumed_l2_held_out_failure_closure.status -ceq
            "closed_consumed_invalid_or_incomplete_no_finite_decision" -and
        [string]$stage.consumed_l2_held_out_failure_closure.repair_id -ceq
            "QSDK-R10E-L2" -and
        [bool]$stage.consumed_l2_held_out_failure_closure.physical_identity_consumed -and
        -not [bool]$stage.consumed_l2_held_out_failure_closure.same_identity_rerun_permitted -and
        [bool]$stage.official_zero_world_qualification_passed -and
        -not [bool]$stage.physical_execution_authorized_by_freeze -and
        -not [bool]$stage.physical_acceptance_authority -and
        -not [bool]$stage.release_authority -and
        [int]$stage.maximum_world_count -eq @($spec.ordered_cell_ids).Count -and
        [int]$stage.maximum_campaign_attempt_count -eq 1
    ) "STAGE_FIELDS"
    $refusalPath = Join-Path $script:RepoRoot $script:ExpectedSupervisorRefusalPath
    Assert-BoundFile `
        -Path $refusalPath `
        -Binding $stage.superseded_physical_supervisor_refusal `
        -Code "SUPERSEDED_PHYSICAL_SUPERVISOR_REFUSAL"
    Assert-R10e (
        [string]$stage.superseded_physical_supervisor_refusal.git_blob_oid -ceq (
            Invoke-GitText @(
                "rev-parse",
                ($sourceCommit + ":" + $script:ExpectedSupervisorRefusalPath)
            )
        )
    ) "SUPERSEDED_PHYSICAL_SUPERVISOR_REFUSAL_BLOB"
    $l2FailurePath = Join-Path $script:RepoRoot $script:ExpectedL2HeldOutFailureClosurePath
    Assert-BoundFile `
        -Path $l2FailurePath `
        -Binding $stage.consumed_l2_held_out_failure_closure `
        -Code "L2_HELD_OUT_FAILURE_CLOSURE"
    Assert-R10e (
        [string]$stage.consumed_l2_held_out_failure_closure.git_blob_oid -ceq (
            Invoke-GitText @(
                "rev-parse",
                ($sourceCommit + ":" + $script:ExpectedL2HeldOutFailureClosurePath)
            )
        )
    ) "L2_HELD_OUT_FAILURE_CLOSURE_BLOB"
    Assert-ExactStringSequence -Actual @($stage.ordered_cell_ids) -Expected @($spec.ordered_cell_ids) -Code "STAGE_CELL_ORDER"
    Assert-R10e (
        [string]$authority.schema_version -ceq [string]$spec.authority_schema -and
        [string]$authority.status -ceq "authorized_single_use_unconsumed" -and
        [string]$authority.gate_id -ceq "QSDK-R10E" -and
        [string]$authority.repair_id -ceq [string]$spec.repair_id -and
        [string]$authority.campaign_id -ceq [string]$spec.campaign_id -and
        [string]$authority.campaign_role -ceq $CampaignRole -and
        [string]$authority.question_class -ceq [string]$spec.question_class -and
        [bool]$authority.authorization_commit_derived_from_current_head -and
        [string]$authority.authorization_parent_commit -ceq $stageCommit -and
        [string]$authority.qualification_parent_commit -ceq $sourceCommit -and
        [string]$authority.source_commit -ceq $sourceCommit -and
        [string]$authority.stage_freeze_sha256 -ceq (Get-Sha256 -Path $stagePath) -and
        [int]$authority.qualified_source_path_count -eq $script:ExpectedSourceCount -and
        [string]$authority.qualified_source_path_sha256 -ceq $script:ExpectedSourcePathSha256 -and
        [string]$authority.superseded_physical_supervisor_refusal_sha256 -ceq (
            $script:ExpectedSupervisorRefusalSha256
        ) -and
        [string]$authority.l2_held_out_failure_closure_sha256 -ceq (
            $script:ExpectedL2HeldOutFailureClosureSha256
        ) -and
        [bool]$authority.zero_world_qualification_passed -and
        [bool]$authority.physical_execution_authorized -and
        -not [bool]$authority.physical_identity_consumed -and
        -not [bool]$authority.same_identity_rerun_permitted -and
        -not [bool]$authority.physical_acceptance_authority -and
        -not [bool]$authority.release_authority -and
        [int]$authority.maximum_world_count -eq @($spec.ordered_cell_ids).Count -and
        [int]$authority.maximum_campaign_attempt_count -eq 1
    ) "AUTHORITY_FIELDS"
    Assert-ExactStringSequence -Actual @($authority.ordered_cell_ids) -Expected @($spec.ordered_cell_ids) -Code "AUTHORITY_CELL_ORDER"
    $expectedOutput = [IO.Path]::GetFullPath((Join-Path $script:EvidenceRoot (
        "qsdk-r10e-" + [string]$spec.output_slug + "-physical-" +
        $sourceCommit.Substring(0, 12)
    )))
    Assert-R10e (
        [IO.Path]::GetFullPath([string]$authority.output_root) -ceq $expectedOutput
    ) "AUTHORITY_OUTPUT_ROOT"
    if ($RequireUnusedOutput) {
        Assert-R10e (-not (Test-Path -LiteralPath $expectedOutput)) "PHYSICAL_IDENTITY_CONSUMED"
    }
    $qualificationBinding = $stage.qualification_completion
    $expectedQualificationRoot = [IO.Path]::GetFullPath((Join-Path (
        $script:EvidenceRoot
    ) (
        "qsdk-r10e-" + [string]$spec.output_slug +
        "-zero-world-qualification-" + $sourceCommit.Substring(0, 12)
    )))
    $qualificationPath = [IO.Path]::GetFullPath([string]$qualificationBinding.path)
    Assert-R10e (
        $qualificationPath -ceq (
            Join-Path $expectedQualificationRoot "qualification_completion.json"
        )
    ) "QUALIFICATION_COMPLETION_PATH"
    Assert-BoundFile -Path $qualificationPath -Binding $qualificationBinding -Code "QUALIFICATION"
    $completion = Read-JsonObject -Path $qualificationPath -Label "QUALIFICATION_COMPLETION"
    Assert-R10e (
        [string]$completion.schema_version -ceq [string]$spec.qualification_completion_schema -and
        [string]$completion.status -ceq "closed_passing_official_zero_world_qualification" -and
        [string]$completion.gate_id -ceq "QSDK-R10E" -and
        [string]$completion.repair_id -ceq [string]$spec.repair_id -and
        [string]$completion.campaign_id -ceq [string]$spec.campaign_id -and
        [string]$completion.campaign_role -ceq $CampaignRole -and
        [string]$completion.question_class -ceq [string]$spec.question_class -and
        [string]$completion.ledger_scope.subsystem -ceq "recovery" -and
        [string]$completion.ledger_scope.engine_scope -ceq "godot_jolt" -and
        [string]$completion.ledger_scope.authority_mode -ceq "official_zero_world_qualification" -and
        [string]$completion.ledger_scope.question_class -ceq [string]$spec.question_class -and
        [string]$completion.source_commit -ceq $sourceCommit -and
        [string]$completion.source_tree -ceq (
            Invoke-GitText @("rev-parse", ($sourceCommit + "^{tree}"))
        ) -and
        [IO.Path]::GetFullPath([string]$completion.qualification_root) -ceq
            $expectedQualificationRoot -and
        [int]$completion.qualified_source_path_count -eq $script:ExpectedSourceCount -and
        [string]$completion.qualified_source_path_sha256 -ceq
            $script:ExpectedSourcePathSha256 -and
        [string]$completion.superseded_physical_supervisor_refusal_sha256 -ceq
            $script:ExpectedSupervisorRefusalSha256 -and
        [string]$completion.l2_held_out_failure_closure_sha256 -ceq
            $script:ExpectedL2HeldOutFailureClosureSha256 -and
        [bool]$completion.official_zero_world_qualification_passed -and
        [bool]$completion.source_unchanged_during_qualification -and
        [bool]$completion.operation_lock_serialization_passed -and
        [int]$completion.maximum_future_world_count -eq
            @($spec.ordered_cell_ids).Count -and
        [int]$completion.maximum_future_campaign_attempt_count -eq 1 -and
        -not [bool]$completion.same_identity_rerun_permitted -and
        -not [bool]$completion.physical_execution_authorized -and
        -not [bool]$completion.physical_acceptance_authority -and
        -not [bool]$completion.release_authority
    ) "QUALIFICATION_COMPLETION_FIELDS"
    Assert-ExactStringSequence `
        -Actual @($completion.ordered_future_cell_ids) `
        -Expected @($spec.ordered_cell_ids) `
        -Code "QUALIFICATION_FUTURE_CELL_ORDER"
    $qualificationRoot = Split-Path -Parent $qualificationPath
    Assert-R10e (
        $qualificationRoot -ceq $expectedQualificationRoot -and
        [string]$completion.runtime_identity.path -ceq "runtime_identity.json"
    ) "QUALIFICATION_RUNTIME_PATH"
    $runtimePath = [IO.Path]::GetFullPath((Join-Path $qualificationRoot (
        [string]$completion.runtime_identity.path
    )))
    Assert-BoundFile -Path $runtimePath -Binding $completion.runtime_identity -Code "RUNTIME_IDENTITY"
    $recordedRuntime = Read-JsonObject -Path $runtimePath -Label "RUNTIME_IDENTITY"
    $currentRuntime = Get-CurrentRuntimeProjection -SourceCommit $sourceCommit
    Assert-QualifiedRuntimeCurrent -Recorded $recordedRuntime -Current $currentRuntime
    $dependency = Invoke-DependencyAudit -RequireTracked
    return [ordered]@{
        source_commit = $sourceCommit
        source_tree = Invoke-GitText @("rev-parse", ($sourceCommit + "^{tree}"))
        authorization_commit = $authorizationCommit
        authorization_parent_commit = $stageCommit
        qualification_parent_commit = $sourceCommit
        stage_path = $stagePath
        stage_sha256 = Get-Sha256 -Path $stagePath
        authority_path = $authorityPath
        authority_sha256 = Get-Sha256 -Path $authorityPath
        output_root = $expectedOutput
        authority = $authority
        stage = $stage
        runtime_identity = $recordedRuntime
        runtime_identity_path = $runtimePath
        runtime_identity_sha256 = Get-Sha256 -Path $runtimePath
        dependency = $dependency
        committed_graph_authority_check_passed = $true
    }
}


function Invoke-SupervisorAuthorityCheck {
    Assert-R10e (-not $AuthorizePhysical) "AUTHORITY_CHECK_PHYSICAL_SWITCH_FORBIDDEN"
    Assert-R10e (
        [bool]$script:Roles[$CampaignRole].physical_execution_permitted
    ) "HISTORICAL_DEVELOPMENT_ROUTE_AUTHORITY_CONSUMED"
    $authority = Get-QualifiedPhysicalAuthority -RequireUnusedOutput
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10e_supervisor_authority_check_v1"
        gate_id = "QSDK-R10E"
        repair_id = [string]$script:Roles[$CampaignRole].repair_id
        campaign_id = [string]$script:Roles[$CampaignRole].campaign_id
        campaign_role = $CampaignRole
        ledger_scope = [ordered]@{
            subsystem = "recovery"
            engine_scope = "godot_jolt"
            authority_mode = "committed_graph_authority_check"
            question_class = [string]$script:Roles[$CampaignRole].question_class
        }
        ok = $true
        failure_code = ""
        source_commit = $authority.source_commit
        authorization_commit = $authority.authorization_commit
        authorization_parent_commit = $authority.authorization_parent_commit
        qualification_parent_commit = $authority.qualification_parent_commit
        stage_freeze_sha256 = $authority.stage_sha256
        execution_authority_sha256 = $authority.authority_sha256
        runtime_identity_sha256 = $authority.runtime_identity_sha256
        superseded_physical_supervisor_refusal_sha256 = (
            $script:ExpectedSupervisorRefusalSha256
        )
        output_root_absent = -not (Test-Path -LiteralPath $authority.output_root)
        ordered_cell_ids = @($script:Roles[$CampaignRole].ordered_cell_ids)
        maximum_world_count = @($script:Roles[$CampaignRole].ordered_cell_ids).Count
        maximum_campaign_attempt_count = 1
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
}


function Write-NewText {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Text
    )
    Assert-R10e (-not (Test-Path -LiteralPath $Path)) "TEXT_OUTPUT_ALREADY_EXISTS"
    $parent = Split-Path -Parent $Path
    if ($parent) { [IO.Directory]::CreateDirectory($parent) | Out-Null }
    [IO.File]::WriteAllText(
        [IO.Path]::GetFullPath($Path),
        $Text.Replace("`r`n", "`n"),
        [Text.UTF8Encoding]::new($false)
    )
}


function New-LedgerScope {
    param(
        [Parameter(Mandatory)][string]$AuthorityMode,
        [Parameter(Mandatory)][string]$QuestionClass
    )
    return [ordered]@{
        subsystem = "recovery"
        engine_scope = "godot_jolt"
        authority_mode = $AuthorityMode
        question_class = $QuestionClass
    }
}


function Get-CellIdentity {
    param([Parameter(Mandatory)][string]$CellId)
    Assert-R10e (
        $CellId -cmatch '^(baseline|push)_s([0-9]+)$'
    ) "CELL_ID_FORMAT"
    return [ordered]@{
        arm_id = if ($Matches[1] -ceq "baseline") {
            "matched_no_impulse_control"
        } else {
            "lateral_upright_impulse"
        }
        seed = [int]$Matches[2]
    }
}


function New-PhysicalAttempt {
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][object]$LockReceipt,
        [Parameter(Mandatory)][string]$CellId,
        [Parameter(Mandatory)][string]$CellDirectory,
        [Parameter(Mandatory)][string]$Token
    )
    $identity = Get-CellIdentity -CellId $CellId
    $spec = $script:Roles[$CampaignRole]
    return [ordered]@{
        schema_version = "sporespore_qsdk_r10e_physical_attempt_v1"
        gate_id = "QSDK-R10E"
        repair_id = [string]$spec.repair_id
        campaign_id = [string]$spec.campaign_id
        campaign_role = $CampaignRole
        question_class = [string]$spec.question_class
        ledger_scope = New-LedgerScope -AuthorityMode "physical_cell_attempt" -QuestionClass ([string]$spec.question_class)
        authorization_token = $Token
        arm_id = [string]$identity.arm_id
        campaign_seed = [int]$identity.seed
        cell_id = $CellId
        output_root = [IO.Path]::GetFullPath($Context.output_root).Replace("\", "/")
        source_commit = [string]$Context.source_commit
        authorization_commit = [string]$Context.authorization_commit
        authorization_parent_commit = [string]$Context.authorization_parent_commit
        qualification_parent_commit = [string]$Context.qualification_parent_commit
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
        qualified_source_path_count = $script:ExpectedSourceCount
        qualified_source_path_sha256 = $script:ExpectedSourcePathSha256
        stage_freeze_path = [IO.Path]::GetFullPath($Context.stage_path).Replace("\", "/")
        stage_freeze_sha256 = [string]$Context.stage_sha256
        execution_authority_path = [IO.Path]::GetFullPath($Context.authority_path).Replace("\", "/")
        execution_authority_sha256 = [string]$Context.authority_sha256
        operation_lock = $LockReceipt
        supervisor_physical_authorized = $true
        synthetic_authorization_preflight = $false
        maximum_world_attempt_count = 1
        maximum_world_build_count = 1
        world_attempt_count_before_worker = 0
        world_build_count_before_worker = 0
        same_identity_rerun_permitted = $false
        physical_acceptance_authority = $false
        release_authority = $false
        attempt_path = [IO.Path]::GetFullPath((Join-Path $CellDirectory "attempt.json")).Replace("\", "/")
    }
}


function Test-ObjectProperty {
    param(
        [AllowNull()][object]$Value,
        [Parameter(Mandatory)][string]$Name
    )
    return $null -ne $Value -and $null -ne $Value.PSObject.Properties[$Name]
}


function Convert-CellProjection {
    param(
        [Parameter(Mandatory)][string]$CellId,
        [Parameter(Mandatory)][object]$Process,
        [Parameter(Mandatory)][string]$AttemptPath,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath,
        [AllowNull()][string]$ReceiptPath,
        [AllowNull()][object]$Receipt,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ParseFailure,
        [Parameter(Mandatory)][string]$OutputRoot
    )
    $identity = Get-CellIdentity -CellId $CellId
    $hasReceipt = $null -ne $Receipt
    $evaluation = if ($hasReceipt -and (Test-ObjectProperty $Receipt "evaluation")) {
        $Receipt.evaluation
    } else { $null }
    $observer = if (
        $null -ne $evaluation -and
        (Test-ObjectProperty $evaluation "observer_instrumentation")
    ) { $evaluation.observer_instrumentation } else { $null }
    $observerReceipt = if (
        $null -ne $observer -and (Test-ObjectProperty $observer "receipt")
    ) { $observer.receipt } else { $null }
    $worldKnown = $hasReceipt -and (Test-ObjectProperty $Receipt "world_build_count")
    $receiptBinding = if ($ReceiptPath) {
        Get-FileBinding -Path $ReceiptPath -RelativeTo $OutputRoot
    } else { $null }
    return [ordered]@{
        cell_id = $CellId
        arm_id = [string]$identity.arm_id
        campaign_seed = [int]$identity.seed
        attempted = $true
        process_completed = [bool]$Process.completed
        timed_out = [bool]$Process.timed_out
        process_exit_code = $Process.exit_code
        marker_receipt_parsed = $hasReceipt
        parse_failure = $ParseFailure
        worker_ok = (
            $hasReceipt -and
            (Test-ObjectProperty $Receipt "ok") -and
            [bool]$Receipt.ok
        )
        failure_code = if (
            $hasReceipt -and (Test-ObjectProperty $Receipt "failure_code")
        ) { [string]$Receipt.failure_code } else { $ParseFailure }
        world_build_count_known = $worldKnown
        world_build_count = if ($worldKnown) { [int]$Receipt.world_build_count } else { 0 }
        external_push_application_count = if (
            $hasReceipt -and
            (Test-ObjectProperty $Receipt "runtime_summary_projection") -and
            (Test-ObjectProperty $Receipt.runtime_summary_projection "external_push_application_count")
        ) { [int]$Receipt.runtime_summary_projection.external_push_application_count } else { $null }
        evaluation = [ordered]@{
            ok = (
                $null -ne $evaluation -and
                (Test-ObjectProperty $evaluation "ok") -and
                [bool]$evaluation.ok
            )
            failure_code = if (
                $null -ne $evaluation -and
                (Test-ObjectProperty $evaluation "failure_code")
            ) { [string]$evaluation.failure_code } else { $ParseFailure }
            outcome_complete = (
                $null -ne $evaluation -and
                (Test-ObjectProperty $evaluation "outcome_complete") -and
                [bool]$evaluation.outcome_complete
            )
            evidence_valid = (
                $null -ne $evaluation -and
                (Test-ObjectProperty $evaluation "evidence_valid") -and
                [bool]$evaluation.evidence_valid
            )
            behavior_passed = if (
                $null -ne $evaluation -and
                (Test-ObjectProperty $evaluation "behavior_passed")
            ) { [bool]$evaluation.behavior_passed } else { $null }
        }
        observer_instrumentation = [ordered]@{
            valid = (
                $null -ne $observer -and
                (Test-ObjectProperty $observer "ok") -and
                [bool]$observer.ok
            )
            live_prohibited_operation_count = if (
                $null -ne $observer -and
                (Test-ObjectProperty $observer "live_prohibited_operation_count")
            ) { [int]$observer.live_prohibited_operation_count } else { -1 }
            post_solver_materialized_row_count_matches_trace_row_count = (
                $null -ne $observerReceipt -and
                (Test-ObjectProperty $observerReceipt "post_solver_materialized_row_count_matches_trace_row_count") -and
                [bool]$observerReceipt.post_solver_materialized_row_count_matches_trace_row_count
            )
            post_solver_projection_receipt_count_matches_trace_row_count = (
                $null -ne $observerReceipt -and
                (Test-ObjectProperty $observerReceipt "post_solver_projection_receipt_count_matches_trace_row_count") -and
                [bool]$observerReceipt.post_solver_projection_receipt_count_matches_trace_row_count
            )
        }
        attempt_binding = Get-FileBinding -Path $AttemptPath -RelativeTo $OutputRoot
        receipt_binding = $receiptBinding
        stdout_binding = Get-FileBinding -Path $StdoutPath -RelativeTo $OutputRoot
        stderr_binding = Get-FileBinding -Path $StderrPath -RelativeTo $OutputRoot
    }
}


function Test-ValidCellProjection {
    param([Parameter(Mandatory)][object]$Cell)
    return (
        [bool]$Cell.attempted -and
        [bool]$Cell.process_completed -and
        -not [bool]$Cell.timed_out -and
        [int]$Cell.process_exit_code -eq 0 -and
        [bool]$Cell.marker_receipt_parsed -and
        [bool]$Cell.worker_ok -and
        [bool]$Cell.world_build_count_known -and
        [int]$Cell.world_build_count -eq 1 -and
        [bool]$Cell.evaluation.ok -and
        [bool]$Cell.evaluation.outcome_complete -and
        [bool]$Cell.evaluation.evidence_valid -and
        $null -ne $Cell.evaluation.behavior_passed -and
        [bool]$Cell.observer_instrumentation.valid -and
        [int]$Cell.observer_instrumentation.live_prohibited_operation_count -eq 0 -and
        [bool]$Cell.observer_instrumentation.post_solver_materialized_row_count_matches_trace_row_count -and
        [bool]$Cell.observer_instrumentation.post_solver_projection_receipt_count_matches_trace_row_count
    )
}


function Invoke-PhysicalCell {
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][object]$LockReceipt,
        [Parameter(Mandatory)][string]$CellId
    )
    $cellDirectory = Join-Path $Context.output_root $CellId
    Assert-R10e (-not (Test-Path -LiteralPath $cellDirectory)) "CELL_IDENTITY_ALREADY_USED"
    [IO.Directory]::CreateDirectory($cellDirectory) | Out-Null
    $token = [Guid]::NewGuid().ToString("N")
    $attemptArguments = @{
        Context = $Context
        LockReceipt = $LockReceipt
        CellId = $CellId
        CellDirectory = $cellDirectory
        Token = $token
    }
    $attempt = New-PhysicalAttempt @attemptArguments
    $attemptPath = Join-Path $cellDirectory "attempt.json"
    Write-NewJson -Path $attemptPath -Value $attempt
    $identity = Get-CellIdentity -CellId $CellId
    $environment = @{
        $script:AttemptEnvironment = [IO.Path]::GetFullPath($attemptPath)
        $script:TokenEnvironment = $token
    }
    $processArguments = @{
        Script = $script:WorkerScript
        UserArguments = @(
            "physical", $CampaignRole, [string]$identity.arm_id, [string]$identity.seed
        )
        Environment = $environment
        TimeoutSeconds = $CellTimeoutSeconds
    }
    $process = Invoke-GodotScript @processArguments
    $stdoutPath = Join-Path $cellDirectory "stdout.txt"
    $stderrPath = Join-Path $cellDirectory "stderr.txt"
    Write-NewText -Path $stdoutPath -Text $process.stdout
    Write-NewText -Path $stderrPath -Text $process.stderr
    $receipt = $null
    $receiptPath = $null
    $parseFailure = ""
    try {
        $parsed = Get-MarkerJson -Stdout $process.stdout -Marker $script:CellMarker -Label $CellId
        $receipt = $parsed.receipt
        $receiptPath = Join-Path $cellDirectory "receipt.json"
        Write-NewText -Path $receiptPath -Text ($parsed.json + "`n")
    } catch {
        $parseFailure = $_.Exception.Message
    }
    $projectionArguments = @{
        CellId = $CellId
        Process = $process
        AttemptPath = $attemptPath
        StdoutPath = $stdoutPath
        StderrPath = $stderrPath
        ReceiptPath = $receiptPath
        Receipt = $receipt
        ParseFailure = $parseFailure
        OutputRoot = $Context.output_root
    }
    return Convert-CellProjection @projectionArguments
}


function Convert-PairProjection {
    param(
        [Parameter(Mandatory)][string]$PairId,
        [Parameter(Mandatory)][object]$Process,
        [Parameter(Mandatory)][string]$StdoutPath,
        [Parameter(Mandatory)][string]$StderrPath,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ReceiptPath,
        [AllowNull()][object]$Receipt,
        [Parameter(Mandatory)][AllowEmptyString()][string]$ParseFailure,
        [Parameter(Mandatory)][string]$OutputRoot
    )
    $hasReceipt = $null -ne $Receipt
    return [ordered]@{
        pair_id = $PairId
        evaluator_completed = [bool]$Process.completed
        timed_out = [bool]$Process.timed_out
        process_exit_code = $Process.exit_code
        marker_receipt_parsed = $hasReceipt
        parse_failure = $ParseFailure
        receipt_binding = if ($hasReceipt) {
            Get-FileBinding -Path $ReceiptPath -RelativeTo $OutputRoot
        } else { $null }
        stdout_binding = Get-FileBinding -Path $StdoutPath -RelativeTo $OutputRoot
        stderr_binding = Get-FileBinding -Path $StderrPath -RelativeTo $OutputRoot
        evaluation = [ordered]@{
            ok = (
                $hasReceipt -and
                (Test-ObjectProperty $Receipt "ok") -and
                [bool]$Receipt.ok
            )
            failure_code = if (
                $hasReceipt -and (Test-ObjectProperty $Receipt "failure_code")
            ) { [string]$Receipt.failure_code } else { $ParseFailure }
            outcome_complete = (
                $hasReceipt -and
                (Test-ObjectProperty $Receipt "outcome_complete") -and
                [bool]$Receipt.outcome_complete
            )
            evidence_valid = (
                $hasReceipt -and
                (Test-ObjectProperty $Receipt "evidence_valid") -and
                [bool]$Receipt.evidence_valid
            )
            behavior_passed = if (
                $hasReceipt -and (Test-ObjectProperty $Receipt "behavior_passed")
            ) { [bool]$Receipt.behavior_passed } else { $null }
            native_effect_confirmed = (
                $hasReceipt -and
                (Test-ObjectProperty $Receipt "native_effect_confirmed") -and
                [bool]$Receipt.native_effect_confirmed
            )
        }
    }
}


function Test-ValidPairProjection {
    param([Parameter(Mandatory)][object]$Pair)
    return (
        [bool]$Pair.evaluator_completed -and
        -not [bool]$Pair.timed_out -and
        [int]$Pair.process_exit_code -eq 0 -and
        [bool]$Pair.marker_receipt_parsed -and
        [bool]$Pair.evaluation.ok -and
        [bool]$Pair.evaluation.outcome_complete -and
        [bool]$Pair.evaluation.evidence_valid -and
        $null -ne $Pair.evaluation.behavior_passed -and
        [bool]$Pair.evaluation.native_effect_confirmed
    )
}


function Invoke-PhysicalPair {
    param(
        [Parameter(Mandatory)][object]$Context,
        [Parameter(Mandatory)][int]$Seed
    )
    $pairId = "pair_s" + $Seed
    $pairDirectory = Join-Path $Context.output_root $pairId
    Assert-R10e (-not (Test-Path -LiteralPath $pairDirectory)) "PAIR_IDENTITY_ALREADY_USED"
    [IO.Directory]::CreateDirectory($pairDirectory) | Out-Null
    $baselinePath = Join-Path $Context.output_root (
        "baseline_s" + $Seed + "\receipt.json"
    )
    $pushPath = Join-Path $Context.output_root (
        "push_s" + $Seed + "\receipt.json"
    )
    Assert-R10e (Test-Path -LiteralPath $baselinePath -PathType Leaf) "PAIR_BASELINE_MISSING"
    Assert-R10e (Test-Path -LiteralPath $pushPath -PathType Leaf) "PAIR_PUSH_MISSING"
    $process = Invoke-GodotScript -Script $script:WorkerScript -UserArguments @(
        "pair-evaluate", $baselinePath, $pushPath
    ) -TimeoutSeconds 180
    $stdoutPath = Join-Path $pairDirectory "stdout.txt"
    $stderrPath = Join-Path $pairDirectory "stderr.txt"
    Write-NewText -Path $stdoutPath -Text $process.stdout
    Write-NewText -Path $stderrPath -Text $process.stderr
    $receipt = $null
    $receiptPath = Join-Path $pairDirectory "receipt.json"
    $parseFailure = ""
    try {
        $parsed = Get-MarkerJson -Stdout $process.stdout -Marker $script:PairMarker -Label $pairId
        $receipt = $parsed.receipt
        Write-NewText -Path $receiptPath -Text ($parsed.json + "`n")
    } catch {
        $parseFailure = $_.Exception.Message
    }
    if ($null -eq $receipt) { $receiptPath = "" }
    $projectionArguments = @{
        PairId = $pairId
        Process = $process
        StdoutPath = $stdoutPath
        StderrPath = $stderrPath
        ReceiptPath = $receiptPath
        Receipt = $receipt
        ParseFailure = $parseFailure
        OutputRoot = $Context.output_root
    }
    return Convert-PairProjection @projectionArguments
}


function Get-PhysicalOutcome {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Cells,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Pairs,
        [Parameter(Mandatory)][int]$WorldAttemptCount,
        [Parameter(Mandatory)][bool]$WorldBuildCountKnown,
        [Parameter(Mandatory)][int]$WorldBuildCount
    )
    $spec = $script:Roles[$CampaignRole]
    $expectedCells = @($spec.ordered_cell_ids)
    $expectedPairs = @($spec.seeds | ForEach-Object { "pair_s" + $_ })
    $observedCells = @($Cells | ForEach-Object { [string]$_.cell_id })
    $observedPairs = @($Pairs | ForEach-Object { [string]$_.pair_id })
    $cellOrderExact = $true
    try {
        Assert-ExactStringSequence -Actual $observedCells -Expected $expectedCells -Code "OUTCOME_CELL_ORDER"
    } catch { $cellOrderExact = $false }
    $pairOrderExact = $true
    try {
        Assert-ExactStringSequence -Actual $observedPairs -Expected $expectedPairs -Code "OUTCOME_PAIR_ORDER"
    } catch { $pairOrderExact = $false }
    $validCells = $cellOrderExact
    foreach ($cell in $Cells) { if (-not (Test-ValidCellProjection $cell)) { $validCells = $false } }
    $validPairs = $pairOrderExact
    foreach ($pair in $Pairs) { if (-not (Test-ValidPairProjection $pair)) { $validPairs = $false } }
    $attemptsExact = (
        $WorldAttemptCount -eq $expectedCells.Count -and
        $WorldBuildCountKnown -and
        $WorldBuildCount -eq $expectedCells.Count
    )
    $validComplete = $validCells -and $validPairs -and $attemptsExact
    $behavior = $null
    $classification = "invalid_or_incomplete_no_behavioral_conclusion"
    if ($validComplete) {
        $behavior = $true
        foreach ($cell in $Cells) {
            if (-not [bool]$cell.evaluation.behavior_passed) { $behavior = $false }
        }
        foreach ($pair in $Pairs) {
            if (-not [bool]$pair.evaluation.behavior_passed) { $behavior = $false }
        }
        $classification = if ($behavior) {
            "valid_complete_behavior_positive"
        } else { "valid_complete_behavior_finite_negative" }
    }
    $observerValidCount = @(
        $Cells | Where-Object { [bool]$_.observer_instrumentation.valid }
    ).Count
    return [ordered]@{
        classification = $classification
        route_execution_valid = $validComplete
        outcome_complete = $validComplete
        evidence_valid = $validComplete
        behavior_passed = $behavior
        attempted_cell_count = @($Cells | Where-Object { [bool]$_.attempted }).Count
        valid_complete_cell_count = if ($validCells) { $expectedCells.Count } else { 0 }
        valid_complete_pair_count = if ($validPairs) { $expectedPairs.Count } else { 0 }
        native_effect_pair_count = if ($validPairs) { $expectedPairs.Count } else { 0 }
        observer_valid_cell_count = $observerValidCount
        held_out_qualification_eligible = (
            $CampaignRole -ceq "development_route_ghost" -and $validComplete
        )
        separate_qsdk_r10_adoption_eligible = (
            $CampaignRole -ceq "held_out_finite_decision" -and $behavior -eq $true
        )
    }
}


function Test-EmptyPopulationTerminalization {
    $outcome = Get-PhysicalOutcome `
        -Cells @() `
        -Pairs @() `
        -WorldAttemptCount 0 `
        -WorldBuildCountKnown $true `
        -WorldBuildCount 0
    Assert-R10e (
        [string]$outcome.classification -ceq
            "invalid_or_incomplete_no_behavioral_conclusion" -and
        -not [bool]$outcome.route_execution_valid -and
        -not [bool]$outcome.outcome_complete -and
        -not [bool]$outcome.evidence_valid -and
        $null -eq $outcome.behavior_passed -and
        [int]$outcome.attempted_cell_count -eq 0 -and
        [int]$outcome.valid_complete_cell_count -eq 0 -and
        [int]$outcome.valid_complete_pair_count -eq 0 -and
        [int]$outcome.native_effect_pair_count -eq 0 -and
        [int]$outcome.observer_valid_cell_count -eq 0 -and
        -not [bool]$outcome.held_out_qualification_eligible -and
        -not [bool]$outcome.separate_qsdk_r10_adoption_eligible
    ) "EMPTY_POPULATION_TERMINALIZATION"
    return [ordered]@{
        ok = $true
        failure_code = ""
        repair_id = "QSDK-R10E-L3"
        empty_cells_accepted = $true
        empty_pairs_accepted = $true
        invalid_or_incomplete_preserved = $true
        behavioral_conclusion_available = $false
        model_construction_count = 0
        world_attempt_count = 0
        world_build_count = 0
        native_readback_count = 0
        solver_step_count = 0
        physics_state_modified = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
}


function Get-ReportStatus {
    param([Parameter(Mandatory)][string]$Classification)
    if ($Classification -ceq "valid_complete_behavior_positive") {
        return "closed_consumed_valid_complete_behavior_positive"
    }
    if ($Classification -ceq "valid_complete_behavior_finite_negative") {
        return "closed_consumed_valid_complete_behavior_finite_negative"
    }
    return "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
}


function Invoke-ReportAudit {
    param([Parameter(Mandatory)][string]$ReportPath)
    $result = Invoke-CapturedProcess -FilePath $Python -Arguments @(
        "-B", $script:PhysicalClosureAudit, "audit-report", "--report", $ReportPath
    ) -TimeoutSeconds 300
    Assert-R10e (
        $result.completed -and $result.exit_code -eq 0
    ) ("PHYSICAL_REPORT_AUDIT_FAILED:" + ($result.stdout + $result.stderr))
    return (Get-MarkerJson -Stdout $result.stdout -Marker $script:ReportAuditMarker -Label "REPORT_AUDIT").receipt
}


function Invoke-ClosureCompilation {
    param(
        [Parameter(Mandatory)][string]$ReportPath,
        [Parameter(Mandatory)][string]$ClosurePath
    )
    $result = Invoke-CapturedProcess -FilePath $Python -Arguments @(
        "-B", $script:PhysicalClosureAudit, "compile", "--report", $ReportPath,
        "--output", $ClosurePath
    ) -TimeoutSeconds 300
    Assert-R10e (
        $result.completed -and $result.exit_code -eq 0
    ) ("PHYSICAL_CLOSURE_COMPILATION_FAILED:" + ($result.stdout + $result.stderr))
    return Get-FileBinding -Path $ClosurePath -RelativeTo $script:RepoRoot
}


function Invoke-SupervisorPhysical {
    Assert-R10e $AuthorizePhysical "PHYSICAL_SWITCH_REQUIRED"
    Assert-R10e (
        [bool]$script:Roles[$CampaignRole].physical_execution_permitted
    ) "HISTORICAL_DEVELOPMENT_ROUTE_RERUN_FORBIDDEN"
    Assert-R10e (
        [IO.Path]::GetFullPath($script:EvidenceRoot) -ceq $script:EvidenceRoot
    ) "EVIDENCE_ROOT"
    $closureRelativePath = [string]$script:Roles[$CampaignRole].physical_closure_path
    Assert-R10e (
        $closureRelativePath -ceq
            [string]$script:Roles[$CampaignRole].physical_closure_path -and
        $closureRelativePath -cmatch '^sdk/qsdk_r10e_[a-z0-9_]+_physical_closure_v3\.json$'
    ) "PHYSICAL_CLOSURE_PATH"
    $closurePath = Join-Path $script:RepoRoot $closureRelativePath
    $context = Get-QualifiedPhysicalAuthority -RequireUnusedOutput
    . $script:OperationLockPath
    $lockRole = if ($CampaignRole -ceq "development_route_ghost") {
        "physical_development"
    } else { "physical" }
    $lock = Enter-SporeSporeLocomotionOperationLock -Role $lockRole
    Assert-R10e ([bool]$lock.acquired) "OPERATION_LOCK_NOT_ACQUIRED"
    try {
        if ([bool]$lock.abandoned_owner_recovered) {
            throw "OPERATION_LOCK_ABANDONED_OWNER_RECOVERED"
        }
        $publicLock = Get-SporeSporeLocomotionOperationLockPublicReceipt -Receipt $lock
        $outputCreated = $false
        $cells = [Collections.Generic.List[object]]::new()
        $pairs = [Collections.Generic.List[object]]::new()
        $worldAttemptCount = 0
        $worldBuildCount = 0
        $worldBuildCountKnown = $true
        $terminalFailure = ""
        $reportPath = Join-Path $context.output_root "terminal_report.json"
        $campaignStartPath = Join-Path $context.output_root "campaign_start.json"
        try {
            Assert-R10e (
                -not (Test-Path -LiteralPath $context.output_root)
            ) "PHYSICAL_IDENTITY_CONSUMED_AFTER_LOCK"
            [IO.Directory]::CreateDirectory($context.output_root) | Out-Null
            $outputCreated = $true
            $start = [ordered]@{
                schema_version = [string]$script:Roles[$CampaignRole].campaign_start_schema
                gate_id = "QSDK-R10E"
                repair_id = [string]$script:Roles[$CampaignRole].repair_id
                campaign_id = [string]$script:Roles[$CampaignRole].campaign_id
                campaign_role = $CampaignRole
                question_class = [string]$script:Roles[$CampaignRole].question_class
                ledger_scope = New-LedgerScope `
                    -AuthorityMode "physical_campaign_start" `
                    -QuestionClass ([string]$script:Roles[$CampaignRole].question_class)
                source_commit = $context.source_commit
                authorization_commit = $context.authorization_commit
                superseded_physical_supervisor_refusal_sha256 = (
                    $script:ExpectedSupervisorRefusalSha256
                )
                l2_held_out_failure_closure_sha256 = (
                    $script:ExpectedL2HeldOutFailureClosureSha256
                )
                ordered_cell_ids = @($script:Roles[$CampaignRole].ordered_cell_ids)
                maximum_world_count = @($script:Roles[$CampaignRole].ordered_cell_ids).Count
                maximum_campaign_attempt_count = 1
                physical_identity_consumed_on_directory_creation = $true
                same_identity_rerun_permitted = $false
                operation_lock = $publicLock
                started_utc = [DateTime]::UtcNow.ToString("o")
                physical_acceptance_authority = $false
                release_authority = $false
            }
            Write-NewJson -Path $campaignStartPath -Value $start
            foreach ($cellId in @($script:Roles[$CampaignRole].ordered_cell_ids)) {
                $worldAttemptCount += 1
                $cell = Invoke-PhysicalCell -Context $context -LockReceipt $publicLock -CellId $cellId
                $cells.Add($cell)
                if ([bool]$cell.world_build_count_known) {
                    $worldBuildCount += [int]$cell.world_build_count
                } else { $worldBuildCountKnown = $false }
                if (-not (Test-ValidCellProjection $cell)) {
                    $terminalFailure = (
                        "CELL_INVALID_OR_INCOMPLETE:" + $cellId + ":" +
                        [string]$cell.failure_code
                    )
                    break
                }
                if ([string]$cell.arm_id -ceq "lateral_upright_impulse") {
                    $pair = Invoke-PhysicalPair -Context $context -Seed ([int]$cell.campaign_seed)
                    $pairs.Add($pair)
                    if (-not (Test-ValidPairProjection $pair)) {
                        $terminalFailure = "PAIR_INVALID_OR_INCOMPLETE:pair_s" + $cell.campaign_seed
                        break
                    }
                }
            }
        } catch {
            $caughtFailure = $_.Exception.Message
            $terminalFailure = if ($terminalFailure) {
                $terminalFailure + "|SUPERVISOR_EXCEPTION:" + $caughtFailure
            } else { $caughtFailure }
            $worldBuildCountKnown = $false
        }
        Assert-R10e $outputCreated "PHYSICAL_OUTPUT_NOT_CREATED"
        $outcomeArguments = @{
            Cells = @($cells)
            Pairs = @($pairs)
            WorldAttemptCount = $worldAttemptCount
            WorldBuildCountKnown = $worldBuildCountKnown
            WorldBuildCount = $worldBuildCount
        }
        $outcome = Get-PhysicalOutcome @outcomeArguments
        $spec = $script:Roles[$CampaignRole]
        $report = [ordered]@{
            schema_version = [string]$spec.campaign_report_schema
            status = Get-ReportStatus -Classification ([string]$outcome.classification)
            gate_id = "QSDK-R10E"
            campaign_id = [string]$spec.campaign_id
            campaign_role = $CampaignRole
            question_class = [string]$spec.question_class
            ledger_scope = New-LedgerScope -AuthorityMode "consumed_physical_campaign_report" -QuestionClass ([string]$spec.question_class)
            source = [ordered]@{
                repair_id = [string]$spec.repair_id
                source_commit = $context.source_commit
                authorization_commit = $context.authorization_commit
                authorization_parent_commit = $context.authorization_parent_commit
                qualification_parent_commit = $context.qualification_parent_commit
                r10e_design_sha256 = $script:ExpectedDesignSha256
                r10d_development_closure_sha256 = $script:ExpectedR10dDevelopmentSha256
                r10d_held_out_closure_sha256 = $script:ExpectedR10dHeldOutSha256
                r05e_physical_closure_sha256 = $script:ExpectedR05eSha256
                qualified_source_path_count = $script:ExpectedSourceCount
                qualified_source_path_sha256 = $script:ExpectedSourcePathSha256
                superseded_physical_supervisor_refusal_sha256 = (
                    $script:ExpectedSupervisorRefusalSha256
                )
                l2_held_out_failure_closure_sha256 = (
                    $script:ExpectedL2HeldOutFailureClosureSha256
                )
            }
            authority = [ordered]@{
                committed_graph_authority_check_passed = $context.committed_graph_authority_check_passed
                single_use_authority_consumed_by_this_report = $true
                stage_freeze_sha256 = $context.stage_sha256
                execution_authority_sha256 = $context.authority_sha256
            }
            runtime_identity = [ordered]@{
                runtime_identity_complete = [bool]$context.runtime_identity.runtime_identity_complete
                runtime_identity_path = [IO.Path]::GetFullPath(
                    $context.runtime_identity_path
                ).Replace("\", "/")
                runtime_identity_byte_length = [int64](
                    Get-Item -LiteralPath $context.runtime_identity_path
                ).Length
                runtime_identity_sha256 = $context.runtime_identity_sha256
                active_adapter_raw_sha256 = [string]$context.runtime_identity.active_adapter.raw_sha256
            }
            output_root = [IO.Path]::GetFullPath($context.output_root).Replace("\", "/")
            ordered_cell_ids = @($spec.ordered_cell_ids)
            expected_pair_ids = @(
                $spec.seeds | ForEach-Object { "pair_s" + [int]$_ }
            )
            campaign_start_binding = Get-FileBinding `
                -Path $campaignStartPath `
                -RelativeTo $context.output_root
            cells = @($cells)
            pairs = @($pairs)
            world_attempt_count = $worldAttemptCount
            world_build_count_known = $worldBuildCountKnown
            world_build_count = $worldBuildCount
            maximum_world_count = @($spec.ordered_cell_ids).Count
            campaign_attempt_count = 1
            maximum_campaign_attempt_count = 1
            terminal_failure = $terminalFailure
            outcome = $outcome
            physical_identity_consumed = $true
            same_identity_rerun_permitted = $false
            terminal_report_retained = $true
            operation_lock = $publicLock
            completed_utc = [DateTime]::UtcNow.ToString("o")
            physical_acceptance_authority = $false
            release_authority = $false
        }
        Write-NewJson -Path $reportPath -Value $report
        $audit = Invoke-ReportAudit -ReportPath $reportPath
        $closure = Invoke-ClosureCompilation -ReportPath $reportPath -ClosurePath $closurePath
        return [ordered]@{
            schema_version = "sporespore_qsdk_r10e_supervisor_physical_closure_v1"
            gate_id = "QSDK-R10E"
            repair_id = [string]$spec.repair_id
            campaign_role = $CampaignRole
            ledger_scope = New-LedgerScope -AuthorityMode "physical_campaign_terminal_closure" -QuestionClass ([string]$spec.question_class)
            ok = [bool]$outcome.route_execution_valid
            failure_code = if ([bool]$outcome.route_execution_valid) { "" } else { $terminalFailure }
            report_path = $reportPath
            report_raw_sha256 = Get-Sha256 -Path $reportPath
            report_audit = $audit
            closure_binding = $closure
            outcome = $outcome
            physical_identity_consumed = $true
            same_identity_rerun_permitted = $false
            physical_acceptance_authority = $false
            release_authority = $false
        }
    } finally {
        Exit-SporeSporeLocomotionOperationLock -Receipt $lock
    }
}


try {
    $result = switch ($Mode) {
        "ZeroWorld" { Invoke-SupervisorZeroWorld }
        "AuthorityCheck" { Invoke-SupervisorAuthorityCheck }
        "Physical" { Invoke-SupervisorPhysical }
    }
    $marker = switch ($Mode) {
        "ZeroWorld" { $script:ZeroWorldMarker }
        "AuthorityCheck" { $script:AuthorityMarker }
        "Physical" { $script:PhysicalMarker }
    }
    Write-Output ($marker + ($result | ConvertTo-Json -Depth 100 -Compress))
    if ($Mode -ceq "Physical" -and -not [bool]$result.ok) { exit 1 }
    exit 0
} catch {
    $failure = [ordered]@{
        schema_version = "sporespore_qsdk_r10e_supervisor_failure_v1"
        gate_id = "QSDK-R10E"
        repair_id = [string]$script:Roles[$CampaignRole].repair_id
        campaign_role = $CampaignRole
        mode = $Mode
        ledger_scope = New-LedgerScope -AuthorityMode "supervisor_refusal" -QuestionClass ([string]$script:Roles[$CampaignRole].question_class)
        ok = $false
        failure_code = $_.Exception.Message
        physical_execution_authorized = $false
        physical_acceptance_authority = $false
        release_authority = $false
    }
    Write-Output ("QSDK_R10E_SUPERVISOR_FAIL " + ($failure | ConvertTo-Json -Depth 100 -Compress))
    exit 1
}
