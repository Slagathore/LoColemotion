#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("worker", "evaluator", "supervisor")]
    [string]$Role,
    [string]$Python = "",
    [string]$Godot = (
        "C:\Users\Cole\CodeStuff\Misc\Godot\" +
        "Godot_v4.7-stable_mono_win64_console.exe"
    ),
    [string]$PowerShell = "pwsh"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$turningRoot = Join-Path $repoRoot "sdk\turning"
$mujocoPython = Join-Path $repoRoot (
    "sdk\adapters\mujoco\.venv\Scripts\python.exe"
)
$implementationPath = Join-Path $turningRoot (
    "r23d76_production_route_three_engine_turning_implementation_v1.json"
)
$implementationMaterializer = Join-Path $turningRoot (
    "materialize_r23d76_implementation.py"
)
$manifestPath = Join-Path $turningRoot (
    "r23d76_campaign_attestation_manifest_v1.json"
)
$manifestMaterializer = Join-Path $turningRoot (
    "materialize_r23d76_campaign_attestation_manifest.py"
)
$smokeClosurePath = Join-Path $turningRoot (
    "r23d76_bounded_native_smoke_v3_closure.json"
)
$smokeClosureAuditPath = Join-Path $repoRoot (
    "sdk\audit_r23d76_bounded_native_smoke_v3_closure.py"
)
$zeroWorldQualificationGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d76_zero_world_qualification_v3.ps1"
)
$firstQualificationFailurePath = Join-Path $turningRoot (
    "r23d76_first_campaign_qualification_failure_v1.json"
)
$firstQualificationFailureAuditPath = Join-Path $repoRoot (
    "sdk\audit_r23d76_first_campaign_qualification_failure.py"
)
$secondQualificationFailurePath = Join-Path $turningRoot (
    "r23d76_second_campaign_qualification_failure_v1.json"
)
$secondQualificationFailureAuditPath = Join-Path $repoRoot (
    "sdk\audit_r23d76_second_campaign_qualification_failure.py"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d76_production_route_three_engine_turning_evaluator.py"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d76_supervisor.ps1"
$campaignId = "QSDK-R23D76-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"

function Assert-R23D76Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D76 $Role ROLE: $Message" }
}

function Resolve-R23D76RoleApplication([string]$Value, [string]$Fallback) {
    $candidate = if ([string]::IsNullOrWhiteSpace($Value)) {
        $Fallback
    } else {
        $Value
    }
    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return [IO.Path]::GetFullPath($candidate)
    }
    $command = Get-Command $candidate -CommandType Application -ErrorAction Stop |
        Select-Object -First 1
    return [IO.Path]::GetFullPath([string]$command.Source)
}

function Get-R23D76RoleSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D76RoleProcess(
    [string]$FileName,
    [string[]]$Arguments,
    [int]$TimeoutSeconds = 300
) {
    $start = [Diagnostics.ProcessStartInfo]::new()
    $start.FileName = $FileName
    $start.WorkingDirectory = $repoRoot
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    foreach ($argument in $Arguments) { [void]$start.ArgumentList.Add($argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $start
    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        try { $process.Kill($true) } catch { }
        [void]$process.WaitForExit(10000)
    } else {
        $process.WaitForExit()
    }
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { 124 } else { $process.ExitCode }
    $process.Dispose()
    return [ordered]@{
        exit_code = [int]$exitCode
        timed_out = [bool]$timedOut
        stdout = [string]$stdout
        stderr = [string]$stderr
    }
}

function Get-R23D76RoleMarker([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D76Role ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$pythonHost = Resolve-R23D76RoleApplication $Python $mujocoPython
$powerShellHost = Resolve-R23D76RoleApplication $PowerShell "pwsh"
$godotHost = Resolve-R23D76RoleApplication $Godot $Godot

Assert-R23D76Role (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $implementationPath,
    $implementationMaterializer,
    $manifestPath,
    $manifestMaterializer,
    $smokeClosurePath,
    $smokeClosureAuditPath,
    $zeroWorldQualificationGatePath,
    $firstQualificationFailurePath,
    $firstQualificationFailureAuditPath,
    $secondQualificationFailurePath,
    $secondQualificationFailureAuditPath,
    $evaluatorPath,
    $supervisorPath
)) {
    Assert-R23D76Role (Test-Path -LiteralPath $path -PathType Leaf) (
        "role source is missing: $path"
    )
}

$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$smoke = Get-Content -LiteralPath $smokeClosurePath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$firstQualificationFailure =
    Get-Content -LiteralPath $firstQualificationFailurePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
$secondQualificationFailure =
    Get-Content -LiteralPath $secondQualificationFailurePath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$zeroWorldQualificationGate = Get-Command $zeroWorldQualificationGatePath
Assert-R23D76Role (
    [string]$implementation.campaign_id -ceq $campaignId -and
    [string]$implementation.gate_id -ceq "QSDK-R23D76" -and
    [string]$implementation.question_class -ceq "finite_decision" -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    [bool]$implementation.claims.both_predecessor_replays_passed -and
    -not [bool]$implementation.claims.bounded_native_smoke_passed -and
    -not [bool]$implementation.claims.full_seeded_world_ghost_used -and
    -not [bool]$implementation.claims.physical_campaign_opened -and
    @($implementation.ordered_cell_ids).Count -eq 9 -and
    [int]$implementation.dependency_inventory.transitive_path_count -eq 222 -and
    @($implementation.dependency_digests.Keys).Count -eq 222
) "implementation authority changed"
Assert-R23D76Role (
    [string]$smoke.status -ceq
        "closed_complete_integration_valid_bounded_native_smoke" -and
    [bool]$smoke.claims.bounded_native_smoke_passed -and
    -not [bool]$smoke.claims.held_out_seed_23197_opened -and
    -not [bool]$smoke.claims.physical_campaign_opened -and
    [int]$smoke.observed_population.complete_native_producer_population_count -eq 3 -and
    [int]$smoke.observed_population.world_build_count -eq 3 -and
    [int]$smoke.observed_population.exact_observed_solver_step_count -eq 6 -and
    [bool]$smoke.retained_attempt.attempt_identity_consumed -and
    -not [bool]$smoke.retained_attempt.same_source_rerun_allowed
) "bounded native smoke closure changed"
Assert-R23D76Role (
    [string]$firstQualificationFailure.status -ceq
        "closed_incomplete_zero_world_qualification_manifest_parameter_binding_failure" -and
    [string]$firstQualificationFailure.source_authority.source_commit -ceq
        "3435117a68314821fd5fc9eadec950241e66baec" -and
    [bool]$firstQualificationFailure.source_authority.source_was_clean_pushed_and_live_equal -and
    [bool]$firstQualificationFailure.retained_qualification_attempt.attempt_identity_consumed -and
    -not [bool]$firstQualificationFailure.retained_qualification_attempt.same_source_qualification_rerun_allowed -and
    [int]$firstQualificationFailure.observed_gate_population.global_gate_pass_count -eq 12 -and
    [int]$firstQualificationFailure.observed_gate_population.failed_ordinal -eq 13 -and
    [string]$firstQualificationFailure.observed_gate_population.failed_gate_id -ceq
        "R23D76-COMPLETE-ZERO-WORLD" -and
    [int]$firstQualificationFailure.observed_gate_population.model_construction_count -eq 0 -and
    [int]$firstQualificationFailure.observed_gate_population.world_attempt_count -eq 0 -and
    [int]$firstQualificationFailure.observed_gate_population.world_build_count -eq 0 -and
    -not [bool]$firstQualificationFailure.diagnosis.physics_or_behavior_failure -and
    -not [bool]$firstQualificationFailure.claims.campaign_local_qualification_passed
) "first campaign qualification failure closure changed"
Assert-R23D76Role (
    [string]$secondQualificationFailure.status -ceq
        "closed_incomplete_zero_world_qualification_mujoco_runtime_path_binding_failure" -and
    [string]$secondQualificationFailure.source_authority.source_commit -ceq
        "5ddb573e711885abda4a66b53b946cad1a3236b6" -and
    [bool]$secondQualificationFailure.source_authority.source_was_clean_pushed_and_live_equal -and
    [bool]$secondQualificationFailure.retained_qualification_attempt.attempt_identity_consumed -and
    -not [bool]$secondQualificationFailure.retained_qualification_attempt.same_source_qualification_rerun_allowed -and
    [int]$secondQualificationFailure.observed_gate_population.global_gate_pass_count -eq 12 -and
    [int]$secondQualificationFailure.observed_gate_population.failed_ordinal -eq 13 -and
    [bool]$secondQualificationFailure.observed_gate_population.lineage_gate_body_started -and
    [string]$secondQualificationFailure.diagnosis.failure_class -ceq
        "qualification_wrapper_missing_mujoco_runtime_search_path_binding" -and
    -not [bool]$secondQualificationFailure.diagnosis.wrapper_self_bound_mujoco_site_packages -and
    [int]$secondQualificationFailure.observed_gate_population.model_construction_count -eq 0 -and
    [int]$secondQualificationFailure.observed_gate_population.world_attempt_count -eq 0 -and
    [int]$secondQualificationFailure.observed_gate_population.world_build_count -eq 0 -and
    -not [bool]$secondQualificationFailure.diagnosis.physics_or_behavior_failure -and
    -not [bool]$secondQualificationFailure.claims.campaign_local_qualification_passed
) "second campaign qualification failure closure changed"
Assert-R23D76Role (
    $zeroWorldQualificationGate.Parameters.ContainsKey(
        "ExpectProductionConformanceLockHeld"
    ) -and
    $zeroWorldQualificationGate.Parameters[
        "ExpectProductionConformanceLockHeld"
    ].ParameterType -eq [Management.Automation.SwitchParameter]
) "qualification zero-world outer-lock parameter binding changed"
Assert-R23D76Role (
    [string]$manifest.campaign_id -ceq $campaignId -and
    [string]$manifest.question_class -ceq "finite_decision" -and
    [int]$manifest.declared_physical_world_count -eq 9 -and
    [int]$manifest.declared_lineage_gate_count -eq 2 -and
    [int]$manifest.declared_campaign_gate_count -eq 3 -and
    [int]$manifest.declared_total_gate_count -eq 5 -and
    [int]$manifest.bounded_native_smoke_closure.native_engine_count -eq 3 -and
    [int]$manifest.bounded_native_smoke_closure.world_build_count -eq 3 -and
    [int]$manifest.bounded_native_smoke_closure.solver_step_count -eq 6 -and
    -not [bool]$manifest.bounded_native_smoke_closure.behavior_outcome_evaluated -and
    -not [bool]$manifest.bounded_native_smoke_closure.held_out_seed_23197_opened -and
    [string]$manifest.lineage_gates[0].path -ceq
        "tests/test_qsdk_r23d76_zero_world_qualification_v3.ps1" -and
    (@($manifest.lineage_gates[0].arguments) -contains
        "-ExpectProductionConformanceLockHeld") -and
    [string]$manifest.first_campaign_qualification_failure.path -ceq
        "sdk/turning/r23d76_first_campaign_qualification_failure_v1.json" -and
    [int]$manifest.first_campaign_qualification_failure.global_gate_pass_count -eq 12 -and
    [int]$manifest.first_campaign_qualification_failure.failed_ordinal -eq 13 -and
    -not [bool]$manifest.first_campaign_qualification_failure.reusable -and
    [string]$manifest.second_campaign_qualification_failure.path -ceq
        "sdk/turning/r23d76_second_campaign_qualification_failure_v1.json" -and
    [string]$manifest.second_campaign_qualification_failure.failure_class -ceq
        "qualification_wrapper_missing_mujoco_runtime_search_path_binding" -and
    [int]$manifest.second_campaign_qualification_failure.global_gate_pass_count -eq 12 -and
    [int]$manifest.second_campaign_qualification_failure.failed_ordinal -eq 13 -and
    -not [bool]$manifest.second_campaign_qualification_failure.reusable -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.physical_acceptance_authority
) "campaign manifest boundary changed"

$receipt = switch ($Role) {
    "worker" {
        $implementationCheck = Invoke-R23D76RoleProcess $pythonHost @(
            $implementationMaterializer, "check"
        )
        $manifestCheck = Invoke-R23D76RoleProcess $pythonHost @(
            $manifestMaterializer, "check"
        )
        Assert-R23D76Role (
            [int]$implementationCheck.exit_code -eq 0 -and
            -not [bool]$implementationCheck.timed_out -and
            [string]$implementationCheck.stdout -cmatch
                "QSDK_R23D76_IMPLEMENTATION" -and
            [int]$manifestCheck.exit_code -eq 0 -and
            -not [bool]$manifestCheck.timed_out -and
            [string]$manifestCheck.stdout -cmatch
                "QSDK_R23D76_ATTESTATION_MANIFEST"
        ) (
            "materialized worker/manifest binding drifted: " +
            "$($implementationCheck.stderr) $($manifestCheck.stderr)"
        )
        $workerCount = 0
        foreach ($engineId in @("godot_jolt", "rapier_parry", "mujoco")) {
            $worker = $implementation.workers[$engineId]
            $path = Join-Path $repoRoot ([string]$worker.path)
            Assert-R23D76Role (
                (Test-Path -LiteralPath $path -PathType Leaf) -and
                (Get-R23D76RoleSha256 $path) -ceq [string]$worker.raw_sha256 -and
                [bool]$worker.shared_native_kernel_reused -and
                [bool]$worker.implementation_complete -and
                -not [bool]$worker.physical_execution_authorized -and
                -not [bool]$worker.physical_acceptance_authority
            ) "worker binding changed: $engineId"
            $workerCount += 1
        }
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d76_worker_role_gate_v1"
            bound_worker_count = $workerCount
            complete_dependency_inventory_bound = $true
            bounded_native_smoke_closure_bound = $true
            authorization_receipt_contract_bound = $true
            returned_before_model = $true
        }
    }
    "evaluator" {
        Assert-R23D76Role (
            [string]$implementation.evaluator.path -ceq
                "sdk/turning/r23d76_production_route_three_engine_turning_evaluator.py" -and
            [string]$implementation.evaluator.raw_sha256 -ceq
                (Get-R23D76RoleSha256 $evaluatorPath) -and
            [bool]$implementation.evaluator.accepted_algorithm_rebound_without_threshold_change -and
            [bool]$implementation.evaluator.engine_aware_startup_binding -and
            (@($implementation.evaluator.outcome_classes) -join "|") -ceq
                "positive|negative|invalid|incomplete"
        ) "evaluator binding changed"
        $compile = Invoke-R23D76RoleProcess $pythonHost @(
            "-m", "py_compile", $evaluatorPath
        )
        Assert-R23D76Role (
            [int]$compile.exit_code -eq 0 -and -not [bool]$compile.timed_out
        ) "evaluator compile failed: $($compile.stderr)"
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d76_evaluator_role_gate_v1"
            accepted_algorithm_bound_without_threshold_change = $true
            engine_aware_startup_binding = $true
            outcome_class_count = 4
            returned_before_model = $true
        }
    }
    "supervisor" {
        $process = Invoke-R23D76RoleProcess $powerShellHost @(
            "-NoLogo", "-NoProfile", "-File", $supervisorPath,
            "-RolePreflight",
            "-Python", $pythonHost,
            "-Godot", $godotHost,
            "-PowerShell", $powerShellHost
        ) 600
        Assert-R23D76Role (
            [int]$process.exit_code -eq 0 -and -not [bool]$process.timed_out
        ) "supervisor role preflight failed: $($process.stderr) $($process.stdout)"
        $supervisor = Get-R23D76RoleMarker $process.stdout (
            "QSDK_R23D76_SUPERVISOR_ROLE_PREFLIGHT "
        )
        Assert-R23D76Role (
            [string]$supervisor.campaign_id -ceq $campaignId -and
            [string]$supervisor.gate_id -ceq "QSDK-R23D76" -and
            [string]$supervisor.question_class -ceq "finite_decision" -and
            [int]$supervisor.implementation_dependency_count -eq 222 -and
            [int]$supervisor.terminal_transport_control_count -eq 6 -and
            [int]$supervisor.success_terminal_transport_control_count -eq 3 -and
            [int]$supervisor.failure_terminal_transport_control_count -eq 3 -and
            [bool]$supervisor.supervisor_physical_entry_implemented -and
            [bool]$supervisor.returned_before_model -and
            [int]$supervisor.model_construction_count -eq 0 -and
            [int]$supervisor.world_attempt_count -eq 0 -and
            [int]$supervisor.world_build_count -eq 0 -and
            -not [bool]$supervisor.physical_execution_authorized -and
            -not [bool]$supervisor.physical_acceptance_authority
        ) "supervisor role receipt changed"
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d76_supervisor_role_gate_v1"
            implementation_dependency_count =
                [int]$supervisor.implementation_dependency_count
            terminal_transport_control_count =
                [int]$supervisor.terminal_transport_control_count
            success_terminal_transport_control_count =
                [int]$supervisor.success_terminal_transport_control_count
            failure_terminal_transport_control_count =
                [int]$supervisor.failure_terminal_transport_control_count
            returned_before_model = $true
        }
    }
}

$receipt["campaign_id"] = $campaignId
$receipt["gate_id"] = "QSDK-R23D76"
$receipt["question_class"] = "finite_decision"
$receipt["role"] = $Role
$receipt["model_construction_count"] = 0
$receipt["world_attempt_count"] = 0
$receipt["world_build_count"] = 0
$receipt["physical_execution_authorized"] = $false
$receipt["physical_acceptance_authority"] = $false

$prefix = switch ($Role) {
    "worker" { "QSDK_R23D76_CAMPAIGN_WORKER_ROLE_PASS " }
    "evaluator" { "QSDK_R23D76_CAMPAIGN_EVALUATOR_ROLE_PASS " }
    default { "QSDK_R23D76_CAMPAIGN_SUPERVISOR_ROLE_PASS " }
}
Write-Output ($prefix + ($receipt | ConvertTo-Json -Compress -Depth 100))
