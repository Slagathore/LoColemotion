#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)][ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "python",
    [string]$Godot = "C:\Users\Cole\CodeStuff\Misc\Godot\Godot_v4.7-stable_mono_win64_console.exe"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$turningRoot = Join-Path $sdkRoot "turning"
$workerResource = "res://tests/test_sdk_qsdk_r23d59_godot_jolt_physical_worker.gd"
$evaluatorPath = Join-Path $turningRoot "r23d59_godot_knee_source_finite_decision_evaluator.py"
$supervisorPath = Join-Path $sdkRoot "run_qsdk_r23d59_supervisor.ps1"
$campaignId = "QSDK-R23D59-GODOT-KNEE-CAP-SOURCE-THREE-SEED-FINITE-DECISION"
$stageId = "godot_knee_cap_source_three_seed_finite_decision"
$seedOrder = @(21513, 21514, 21515)
$profileOrder = @(
    "portable_hip__portable_knee",
    "portable_hip__fixture_knee"
)

. (Join-Path $sdkRoot "godot_receipt_terminated_process.ps1")

function Assert-R23D59Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D59 $Role role: $Message" }
}

function Resolve-R23D59RoleApplication([string]$Command) {
    if ([IO.Path]::IsPathFullyQualified($Command)) {
        $resolved = [IO.Path]::GetFullPath($Command)
        Assert-R23D59Role (Test-Path -LiteralPath $resolved -PathType Leaf) (
            "application missing: $resolved"
        )
        return $resolved
    }
    return [IO.Path]::GetFullPath([string](
        Get-Command $Command -CommandType Application -ErrorAction Stop |
            Select-Object -First 1 -ExpandProperty Source
    ))
}

function Invoke-R23D59RoleProcess(
    [string]$FileName,
    [string[]]$Arguments,
    [hashtable]$Environment = @{},
    [int]$TimeoutSeconds = 900
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
    } else { $process.WaitForExit() }
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

function Get-R23D59RoleMarkerJson([string]$Text, [string]$Prefix) {
    $matches = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D59Role ($matches.Count -eq 1) (
        "expected one $Prefix marker, observed $($matches.Count)"
    )
    return $matches[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

foreach ($path in @(
    (Join-Path $repoRoot "tests\test_sdk_qsdk_r23d59_godot_jolt_physical_worker.gd"),
    $evaluatorPath,
    $supervisorPath,
    $Godot
)) {
    Assert-R23D59Role (Test-Path -LiteralPath $path -PathType Leaf) (
        "role dependency missing: $path"
    )
}
$pythonHost = Resolve-R23D59RoleApplication $Python
$powerShellHost = Resolve-R23D59RoleApplication "pwsh"

if ($Role -ceq "worker") {
    $receiptCount = 0
    foreach ($seed in $seedOrder) {
        foreach ($profile in $profileOrder) {
            $nonce = [Guid]::NewGuid().ToString("N")
            $environment = @{
                "SPORESPORE_QSDK_R23D59_SUPERVISED_TERMINATION" = "1"
                "SPORESPORE_QSDK_R23D59_TERMINATION_NONCE" = $nonce
            }
            $result = Invoke-SporeSporeGodotReceiptTerminatedProcess `
                -FileName $Godot -Arguments @(
                    "--headless", "--path", $repoRoot, "--script", $workerResource,
                    "--", "--preflight-only", "--stage", $stageId,
                    "--onset", "onset_600", "--seed", [string]$seed,
                    "--profile", $profile
            ) -WorkingDirectory $repoRoot `
                -ReadyMarkerPrefix "QSDK_R23D59_GODOT_SUPERVISOR_TERMINATION_READY " `
                -ExpectedNonce $nonce -Environment $environment `
                -ScrubEnvironmentNames @(
                    "SPORESPORE_QSDK_R23D59_FREEZE",
                    "SPORESPORE_QSDK_R23D59_ATTEMPT",
                    "SPORESPORE_QSDK_R23D59_TOKEN"
                ) -TimeoutSeconds 300
            Assert-R23D59Role (
                [int]$result.exit_code -eq 0 -and
                -not [bool]$result.timed_out -and
                [bool]$result.termination_protocol_valid -and
                [bool]$result.supervisor_terminated -and
                [string]$result.termination_ready_receipt.worker_receipt_kind -ceq "preflight"
            ) "worker termination invalid: $seed/$profile"
            $receipt = Get-R23D59RoleMarkerJson $result.stdout (
                "QSDK_R23D59_GODOT_JOLT_PREFLIGHT "
            )
            Assert-R23D59Role (
                [string]$receipt.schema_version -ceq
                    "sporespore_qsdk_r23d59_godot_jolt_worker_preflight_v1" -and
                [bool]$receipt.ok -and
                [string]$receipt.campaign_id -ceq $campaignId -and
                [string]$receipt.gate_id -ceq "QSDK-R23D59" -and
                [string]$receipt.engine_id -ceq "godot_jolt" -and
                [string]$receipt.stage_id -ceq $stageId -and
                [string]$receipt.cell_id -ceq (
                    "godot_jolt__s{0}__{1}" -f $seed, $profile
                ) -and
                [int]$receipt.campaign_seed -eq $seed -and
                [string]$receipt.profile_id -ceq $profile -and
                [bool]$receipt.compiled_initial_perturbation_matches_declaration -and
                [int]$receipt.model_construction_count -eq 0 -and
                [int]$receipt.world_attempt_count -eq 0 -and
                [int]$receipt.world_build_count -eq 0 -and
                -not [bool]$receipt.turning_gate_invoked -and
                -not [bool]$receipt.physical_acceptance_authority
            ) "worker receipt invalid: $seed/$profile"
            $receiptCount++
        }
    }
    Assert-R23D59Role ($receiptCount -eq 6) "worker matrix preflight incomplete"
    Write-Host (
        "QSDK_R23D59_CAMPAIGN_WORKER_ROLE_PASS cells=$receiptCount " +
        "seeds=3 profiles=2 models=0 worlds=0 physical_authority=False"
    )
    exit 0
}

if ($Role -ceq "evaluator") {
    $result = Invoke-R23D59RoleProcess -FileName $pythonHost -Arguments @(
        $evaluatorPath, "preflight"
    ) -Environment @{
        "PYTHONPATH" = (@(
            (Join-Path $sdkRoot "python"),
            $turningRoot
        ) -join [IO.Path]::PathSeparator)
    } -TimeoutSeconds 300
    Assert-R23D59Role ($result.exit_code -eq 0 -and -not $result.timed_out) (
        "evaluator failed: $($result.stderr) $($result.stdout)"
    )
    $receipt = Get-R23D59RoleMarkerJson $result.stdout (
        "QSDK_R23D59_EVALUATOR_PREFLIGHT "
    )
    Assert-R23D59Role (
        [string]$receipt.schema_version -ceq
            "sporespore_qsdk_r23d59_evaluator_preflight_v1" -and
        [string]$receipt.campaign_id -ceq $campaignId -and
        [string]$receipt.gate_id -ceq "QSDK-R23D59" -and
        [string]$receipt.question_class -ceq "finite_decision" -and
        [int]$receipt.declared_cell_count -eq 6 -and
        [int]$receipt.valid_trace_canary_count -eq 6 -and
        [int]$receipt.trace_mutation_rejection_count -eq 30 -and
        [int]$receipt.observation_mutation_rejection_count -eq 20 -and
        [int]$receipt.live_fixture_cap_binding_projection_positive_control_count -eq 6 -and
        [int]$receipt.live_fixture_cap_binding_projection_mutation_rejection_count -eq 21 -and
        [int]$receipt.finite_decision_table_positive_control_count -eq 5 -and
        [int]$receipt.strict_profile_conjunction_mutation_rejection_count -eq 6 -and
        [int]$receipt.complete_matrix_order_mutation_rejection_count -eq 5 -and
        [int]$receipt.observation_row_count_per_trace -eq 2992 -and
        [int]$receipt.observation_application_count_per_trace -eq 23936 -and
        [int]$receipt.model_construction_count -eq 0 -and
        [int]$receipt.world_attempt_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.turning_gate_invoked -and
        -not [bool]$receipt.superiority_test_invoked -and
        -not [bool]$receipt.equivalence_or_non_inferiority_test_invoked -and
        -not [bool]$receipt.population_inference_attempted -and
        -not [bool]$receipt.physical_execution_authorized -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "evaluator receipt invalid"
    Write-Host (
        "QSDK_R23D59_CAMPAIGN_EVALUATOR_ROLE_PASS cells=6 " +
        "decision_cases=5 conjunction_mutations=6 models=0 worlds=0 " +
        "physical_authority=False"
    )
    exit 0
}

$supervisor = Invoke-R23D59RoleProcess -FileName $powerShellHost -Arguments @(
    "-NoLogo", "-NoProfile", "-File", $supervisorPath,
    "-PreflightOnly", "-Python", $pythonHost, "-PowerShell", $powerShellHost,
    "-Godot", $Godot
) -TimeoutSeconds 900
Assert-R23D59Role ($supervisor.exit_code -eq 0 -and -not $supervisor.timed_out) (
    "supervisor preflight failed: $($supervisor.stderr) $($supervisor.stdout)"
)
$receipt = Get-R23D59RoleMarkerJson $supervisor.stdout (
    "QSDK_R23D59_ZERO_WORLD_PASS "
)
Assert-R23D59Role (
    [string]$receipt.campaign_id -ceq $campaignId -and
    [bool]$receipt.complete_dependency_inventory_proved -and
    [bool]$receipt.immutable_parent_closure_replayed -and
    [bool]$receipt.all_worker_cells_preflighted -and
    [int]$receipt.worker_preflight_count -eq 6 -and
    [int]$receipt.invalid_cell_negative_control_count -eq 5 -and
    [int]$receipt.authorization_negative_control_count -eq 1 -and
    [int]$receipt.model_construction_count -eq 0 -and
    [int]$receipt.world_attempt_count -eq 0 -and
    [int]$receipt.world_build_count -eq 0 -and
    -not [bool]$receipt.turning_gate_invoked -and
    -not [bool]$receipt.physical_execution_authorized -and
    -not [bool]$receipt.physical_acceptance_authority
) "supervisor receipt invalid"
Write-Host (
    "QSDK_R23D59_CAMPAIGN_SUPERVISOR_ROLE_PASS cells=6 dependency_complete=True " +
    "models=0 worlds=0 physical_authority=False"
)
