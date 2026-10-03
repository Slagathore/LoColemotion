#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [ValidateRange(300, 3600)][int]$TimeoutSeconds = 1800
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$sdkRoot = [IO.Path]::GetFullPath($PSScriptRoot)
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $sdkRoot))
$implementationAuditPath = Join-Path $repoRoot "tests\test_qsdk_r23d8_implementation.ps1"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d8_supervisor.ps1"
$campaignId = "QSDK-R23D8-AUTHORIZATION-CLOSED-NEUTRAL-STANCE-BILATERAL-TURN-DEVELOPMENT"
$gateId = "QSDK-R23D8"

function Assert-R23D8ZeroWorld {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Invoke-R23D8ZeroWorldProcess {
    param(
        [Parameter(Mandatory)][string]$Path,
        [string[]]$Arguments = @(),
        [Parameter(Mandatory)][string]$Label
    )
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = "pwsh"
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($name in @(
        "SPORESPORE_QSDK_R23D8_FREEZE",
        "SPORESPORE_QSDK_R23D8_ATTEMPT",
        "SPORESPORE_QSDK_R23D8_TOKEN",
        "SPORESPORE_QSDK_R23D8_STAGE",
        "SPORESPORE_QSDK_R23D8_CELL",
        "SPORESPORE_QSDK_R23D8_ENGINE",
        "SPORESPORE_QSDK_R23D8_ATTEMPT_ROOT"
    )) {
        [void]$start.Environment.Remove($name)
    }
    foreach ($argument in @("-NoLogo", "-NoProfile", "-File", $Path) + $Arguments) {
        [void]$start.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    $timer = [Diagnostics.Stopwatch]::StartNew()
    Assert-R23D8ZeroWorld $process.Start() (
        "QSDK-R23D8 zero-world gate failed to start $Label"
    )
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = $false
    $nextHeartbeat = 30.0
    while (-not $process.WaitForExit(1000)) {
        if ($timer.Elapsed.TotalSeconds -ge $nextHeartbeat) {
            Write-Host (
                "QSDK_R23D8_ZERO_WORLD_PROGRESS gate=$Label elapsed_seconds=" +
                $timer.Elapsed.TotalSeconds.ToString(
                    "F1", [Globalization.CultureInfo]::InvariantCulture
                )
            )
            $nextHeartbeat += 30.0
        }
        if ($timer.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            $timedOut = $true
            try { $process.Kill($true) } catch { }
            [void]$process.WaitForExit(10000)
            break
        }
    }
    $timer.Stop()
    $result = [ordered]@{
        exit_code = if ($process.HasExited) { $process.ExitCode } else { -1 }
        timed_out = $timedOut
        duration_seconds = $timer.Elapsed.TotalSeconds
        stdout = $stdoutTask.GetAwaiter().GetResult()
        stderr = $stderrTask.GetAwaiter().GetResult()
    }
    $process.Dispose()
    if ($result.stdout) { Write-Host ([string]$result.stdout).TrimEnd() }
    if ($result.stderr) { Write-Host ([string]$result.stderr).TrimEnd() }
    return $result
}

function Get-R23D8ZeroWorldMarker {
    param(
        [Parameter(Mandatory)][string]$Text,
        [Parameter(Mandatory)][string]$Prefix
    )
    $matches = @($Text -split "`r?`n" | Where-Object {
        $_.StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D8ZeroWorld ($matches.Count -eq 1) (
        "QSDK-R23D8 expected one '$Prefix' marker, observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @($implementationAuditPath, $supervisorPath, $Godot)) {
    Assert-R23D8ZeroWorld (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D8 zero-world input is missing: $path"
    )
}
Assert-R23D8ZeroWorld (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D8 zero-world repository identity mismatch"

$statusBefore = @(& git -C $repoRoot status --short --untracked-files=all)
$audit = Invoke-R23D8ZeroWorldProcess `
    -Path $implementationAuditPath `
    -Label "implementation-audit"
Assert-R23D8ZeroWorld (
    -not [bool]$audit.timed_out -and [int]$audit.exit_code -eq 0
) "QSDK-R23D8 implementation audit failed"
$auditReceipt = Get-R23D8ZeroWorldMarker `
    -Text $audit.stdout `
    -Prefix "QSDK_R23D8_IMPLEMENTATION_AUDIT "
Assert-R23D8ZeroWorld (
    [int]$auditReceipt.worker_implementation_count -eq 3 -and
    [int]$auditReceipt.native_terminal_stance_route_count -eq 3 -and
    [int]$auditReceipt.complete_trace_retention_path_count -eq 3 -and
    [int]$auditReceipt.retained_pre_attempt_incident_count -eq 1 -and
    [int]$auditReceipt.world_attempt_count -eq 0 -and
    [int]$auditReceipt.world_build_count -eq 0 -and
    -not [bool]$auditReceipt.physical_execution_authorized -and
    -not [bool]$auditReceipt.physical_acceptance_authority
) "QSDK-R23D8 implementation audit receipt changed"

$supervisor = Invoke-R23D8ZeroWorldProcess `
    -Path $supervisorPath `
    -Arguments @("-PreflightOnly", "-Python", $Python, "-Godot", $Godot) `
    -Label "supervisor-preflight"
Assert-R23D8ZeroWorld (
    -not [bool]$supervisor.timed_out -and [int]$supervisor.exit_code -eq 0
) "QSDK-R23D8 supervisor preflight failed"
$supervisorReceipt = Get-R23D8ZeroWorldMarker `
    -Text $supervisor.stdout `
    -Prefix "QSDK_R23D8_SUPERVISOR_PREFLIGHT "
Assert-R23D8ZeroWorld (
    [int]$supervisorReceipt.runtime_materialization_pass_count -eq 1 -and
    [int]$supervisorReceipt.external_runtime_binding_pass_count -eq 4 -and
    [int]$supervisorReceipt.stage_zero_gate_pass_count -eq 2 -and
    [int]$supervisorReceipt.retained_pre_attempt_incident_audit_pass_count -eq 1 -and
    [int]$supervisorReceipt.authorization_canary_runner_preflight_pass_count -eq 1 -and
    [int]$supervisorReceipt.declared_worker_dependency_count -eq 28 -and
    [int]$supervisorReceipt.terminal_marker_family_count -eq 3 -and
    [int]$supervisorReceipt.terminal_marker_case_count -eq 15 -and
    [int]$supervisorReceipt.worker_gate_pass_count -eq 3 -and
    [int]$supervisorReceipt.production_evaluator_test_count -eq 8 -and
    [int]$supervisorReceipt.physical_authorization_refusal_count -eq 1 -and
    [int]$supervisorReceipt.stage_a_declared_cell_count -eq 2 -and
    [int]$supervisorReceipt.stage_b_declared_cell_count_if_selected -eq 9 -and
    [int]$supervisorReceipt.actual_world_attempt_count -eq 0 -and
    [int]$supervisorReceipt.actual_world_build_count -eq 0 -and
    -not [bool]$supervisorReceipt.physical_execution_authorized -and
    -not [bool]$supervisorReceipt.physical_acceptance_authority
) "QSDK-R23D8 supervisor receipt changed"

$statusAfter = @(& git -C $repoRoot status --short --untracked-files=all)
Assert-R23D8ZeroWorld (
    [string]::Join("`n", $statusAfter) -ceq [string]::Join("`n", $statusBefore)
) "QSDK-R23D8 zero-world gate changed the worktree"

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d8_complete_zero_world_gate_v1"
    campaign_id = $campaignId
    gate_id = $gateId
    implementation_audit_pass_count = 1
    runtime_materialization_pass_count = 1
    external_runtime_binding_pass_count = 4
    stage_zero_gate_pass_count = 2
    retained_pre_attempt_incident_audit_pass_count = 1
    authorization_canary_runner_preflight_pass_count = 1
    declared_worker_dependency_count = 28
    terminal_marker_family_count = 3
    terminal_marker_case_count = 15
    physical_worker_gate_pass_count = 3
    production_evaluator_test_count = 8
    physical_authorization_refusal_count = 1
    stage_a_declared_cell_count = 2
    stage_b_declared_cell_count_if_selected = 9
    exact_controller_horizon_step_count = 2992
    exact_terminal_stance_horizon_step_count = 540
    exact_passive_horizon_step_count = 240
    exact_trace_row_count_per_cell = 3772
    physical_process_launch_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    command_conditioned_turning = $false
    bilateral_signed_turning = $false
    portable_basic_turning = $false
    cross_engine_equivalence = $false
    q_sdk_r23_satisfied = $false
    release_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D8_ZERO_WORLD_GATE " +
    ($receipt | ConvertTo-Json -Depth 50 -Compress)
)
Write-Host (
    "QSDK_R23D8_ZERO_WORLD_PASS implementation=1 runtime_materialization=1 " +
    "external_runtimes=4 " +
    "stage_zero=2 incident=1 authorization_canary_preflight=1 dependencies=28 " +
    "marker_families=3 marker_cases=15 workers=3 " +
    "evaluator_tests=8 physical_refusal=1 stage_a_cells=2 " +
    "stage_b_cells=9 controller_steps=2992 stance_steps=540 " +
    "passive_steps=240 trace_rows=3772 worlds=0 physical_authority=False"
)
