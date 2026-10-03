#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    )
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$mujocoSitePackages = Join-Path $mujocoRoot ".venv\Lib\site-packages"
$campaignId = "QSDK-R23D64-RAPIER-LAUNCH-CONTRACT-REPAIRED-SELECTED-PROFILE-MATCHED-THREE-ENGINE-TURNING-VALIDATION"
$evaluatorPath = Join-Path $turningRoot (
    "r23d64_selected_profile_three_engine_turning_validation_evaluator_v2.py"
)
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d64_supervisor.ps1"
$godotWorkerGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d64_godot_jolt_physical_worker.ps1"
)
$rapierWorkerGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d64_rapier_physical_worker.ps1"
)
$mujocoWorkerGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d64_mujoco_physical_worker.ps1"
)

function Assert-R23D64Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D64 $Role role: $Message" }
}

function Resolve-R23D64RoleApplication([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D64Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty Source
    ))
}

function Invoke-R23D64RoleProcess(
    [string]$FileName,
    [string[]]$Arguments,
    [hashtable]$Environment = @{},
    [int]$TimeoutSeconds = 1200
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    foreach ($entry in $Environment.GetEnumerator()) {
        $start.Environment[[string]$entry.Key] = [string]$entry.Value
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch {}
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    return [ordered]@{
        exit_code = $exitCode
        timed_out = $timedOut
        stdout = $stdout
        stderr = $stderr
    }
}

function Get-R23D64RoleMarkerJson([string]$Text, [string]$Prefix) {
    $matches = @([regex]::Split($Text, "\r?\n") | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D64Role ($matches.Count -eq 1) (
        "expected one $Prefix marker, observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

function Assert-R23D64RoleMarker([string]$Text, [string]$Prefix) {
    $matches = @([regex]::Split($Text, "\r?\n") | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D64Role ($matches.Count -eq 1) (
        "expected one $Prefix marker, observed $($matches.Count)"
    )
}

foreach ($path in @(
    $evaluatorPath,
    $supervisorPath,
    $godotWorkerGatePath,
    $rapierWorkerGatePath,
    $mujocoWorkerGatePath,
    $Godot
)) {
    Assert-R23D64Role (Test-Path -LiteralPath $path -PathType Leaf) (
        "role dependency missing: $path"
    )
}
$pythonHost = Resolve-R23D64RoleApplication $Python
$powerShellHost = Resolve-R23D64RoleApplication "pwsh"
$pythonEnvironment = @{
    "PYTHONPATH" = (@(
        (Join-Path $sdkRoot "python"),
        $turningRoot,
        $mujocoRoot,
        $mujocoSitePackages
    ) -join [IO.Path]::PathSeparator)
}

if ($Role -ceq "worker") {
    $definitions = @(
        [ordered]@{
            engine_id = "godot_jolt"
            path = $godotWorkerGatePath
            arguments = @("-Godot", $Godot)
            marker = "QSDK_R23D64_GODOT_WORKER_ZERO_WORLD_PASS "
        },
        [ordered]@{
            engine_id = "rapier_parry"
            path = $rapierWorkerGatePath
            arguments = @("-Python", $pythonHost)
            marker = "QSDK_R23D64_RAPIER_WORKER_ZERO_WORLD_PASS "
        },
        [ordered]@{
            engine_id = "mujoco"
            path = $mujocoWorkerGatePath
            arguments = @("-Python", $pythonHost)
            marker = "QSDK_R23D64_MUJOCO_PHYSICAL_WORKER_PASS "
        }
    )
    $engineCount = 0
    foreach ($definition in $definitions) {
        $arguments = @(
            "-NoLogo",
            "-NoProfile",
            "-File",
            [string]$definition.path
        ) + @($definition.arguments)
        $result = Invoke-R23D64RoleProcess -FileName $powerShellHost -Arguments $arguments -Environment $pythonEnvironment
        Assert-R23D64Role (
            [int]$result.exit_code -eq 0 -and -not [bool]$result.timed_out
        ) (
            "$($definition.engine_id) worker gate failed: " +
            "$($result.stderr) $($result.stdout)"
        )
        Assert-R23D64RoleMarker $result.stdout ([string]$definition.marker)
        $engineCount++
    }
    Assert-R23D64Role ($engineCount -eq 3) "three-engine worker role incomplete"
    Write-Host (
        "QSDK_R23D64_CAMPAIGN_WORKER_ROLE_PASS engines=3 cells=9 " +
        "worker_mutations=33 models=0 worlds=0 physical_authority=False"
    )
    exit 0
}

if ($Role -ceq "evaluator") {
    $result = Invoke-R23D64RoleProcess -FileName $pythonHost -Arguments @(
        $evaluatorPath,
        "preflight"
    ) -Environment $pythonEnvironment
    Assert-R23D64Role (
        [int]$result.exit_code -eq 0 -and -not [bool]$result.timed_out
    ) "evaluator failed: $($result.stderr) $($result.stdout)"
    $receipt = Get-R23D64RoleMarkerJson $result.stdout (
        "QSDK_R23D64_EVALUATOR_V2_PREFLIGHT "
    )
    Assert-R23D64Role (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d64_evaluator_preflight_v2" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq "QSDK-R23D64" -and
        [string]$receipt.question_class -ceq "finite_decision" -and
        [int]$receipt.declared_cell_count -eq 9 -and
        [int]$receipt.engine_count -eq 3 -and
        [int]$receipt.valid_trace_canary_count -eq 9 -and
        [int]$receipt.task_origin_and_schedule_mutation_rejection_count -eq 30 -and
        [int]$receipt.actuator_observation_mutation_rejection_count -eq 60 -and
        [int]$receipt.public_profile_projection_mutation_rejection_count -eq 48 -and
        [int]$receipt.per_engine_trace_cap_mutation_rejection_count -eq 3 -and
        [int]$receipt.turning_decision_mutation_rejection_count -eq 8 -and
        [int]$receipt.complete_matrix_order_mutation_rejection_count -eq 9 -and
        [bool]$receipt.genuine_godot_trace_cold_baseline_passed -and
        -not [bool]$receipt.historical_world_reused_as_r23d64_cell -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        [bool]$receipt.turning_gate_invoked -and
        -not [bool]$receipt.superiority_test_invoked -and
        -not [bool]$receipt.equivalence_or_non_inferiority_test_invoked -and
        -not [bool]$receipt.population_inference_attempted -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "evaluator receipt invalid"
    Write-Host (
        "QSDK_R23D64_CAMPAIGN_EVALUATOR_ROLE_PASS cells=9 engines=3 " +
        "decision_mutations=8 order_mutations=9 models=0 worlds=0 " +
        "physical_authority=False"
    )
    exit 0
}

$supervisor = Invoke-R23D64RoleProcess -FileName $powerShellHost -Arguments @(
    "-NoLogo",
    "-NoProfile",
    "-File",
    $supervisorPath,
    "-PreflightOnly",
    "-Python",
    $pythonHost,
    "-PowerShell",
    $powerShellHost,
    "-Godot",
    $Godot
) -Environment $pythonEnvironment -TimeoutSeconds 1800
Assert-R23D64Role (
    [int]$supervisor.exit_code -eq 0 -and -not [bool]$supervisor.timed_out
) (
    "supervisor preflight failed: " +
    "$($supervisor.stderr) $($supervisor.stdout)"
)
$receipt = Get-R23D64RoleMarkerJson $supervisor.stdout (
    "QSDK_R23D64_ZERO_WORLD_PASS "
)
Assert-R23D64Role (
    [string]$receipt.campaign_id -ceq $campaignId -and
    [string]$receipt.gate_id -ceq "QSDK-R23D64" -and
    [string]$receipt.question_class -ceq "finite_decision" -and
    [bool]$receipt.complete_dependency_inventory_proved -and
    [bool]$receipt.immutable_parent_closure_replayed -and
    [bool]$receipt.rejected_evaluator_v1_preserved -and
    [bool]$receipt.evaluator_v2_complete_matrix_proved -and
    [bool]$receipt.all_three_public_profile_routes_proved -and
    [bool]$receipt.all_three_worker_zero_world_gates_proved -and
    [bool]$receipt.all_three_authorization_receipt_producers_conform -and
    [int]$receipt.authorization_receipt_schema_negative_controls_passed -eq 12 -and
    [bool]$receipt.complete_negative_controls_proved -and
    [bool]$receipt.all_worker_cells_preflighted -and
    [int]$receipt.campaign_gate_count -eq 14 -and
    [int]$receipt.worker_preflight_count -eq 9 -and
    [int]$receipt.declared_cell_count -eq 9 -and
    [int]$receipt.declared_world_count -eq 9 -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    [bool]$receipt.turning_gate_invoked -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority
) "supervisor receipt invalid"
Write-Host (
    "QSDK_R23D64_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=9 engines=3 " +
    "dependency_complete=True gates=14 receipt_schema_controls=12 models=0 worlds=0 " +
    "physical_authority=False"
)
