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
    "r23d78_production_route_three_engine_turning_implementation_v1.json"
)
$implementationMaterializer = Join-Path $turningRoot (
    "materialize_r23d78_implementation.py"
)
$declarationPath = Join-Path $turningRoot (
    "r23d78_fresh_finite_three_engine_turning_decision_v1.json"
)
$manifestPath = Join-Path $turningRoot (
    "r23d78_campaign_attestation_manifest_v1.json"
)
$manifestMaterializer = Join-Path $turningRoot (
    "materialize_r23d78_campaign_attestation_manifest.py"
)
$zeroWorldGatePath = Join-Path $repoRoot (
    "tests\test_qsdk_r23d78_zero_world.ps1"
)
$evaluatorPath = Join-Path $turningRoot (
    "r23d78_production_route_three_engine_turning_evaluator.py"
)
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d78_supervisor.ps1"
$provenanceContractPath = Join-Path $repoRoot (
    "sdk\closure_evidence_provenance_contract.json"
)
$provenanceInventoryPath = Join-Path $repoRoot (
    "sdk\closure_evidence_mode_inventory.json"
)
$provenanceGatePath = Join-Path $repoRoot (
    "tests\test_closure_evidence_provenance_contract.ps1"
)
$campaignId = "QSDK-R23D78-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"

function Assert-R23D78Role([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "QSDK-R23D78 $Role ROLE: $Message" }
}

function Resolve-R23D78RoleApplication([string]$Value, [string]$Fallback) {
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

function Get-R23D78RoleSha256([string]$Path) {
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Invoke-R23D78RoleProcess(
    [string]$FileName,
    [string[]]$Arguments,
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

function Get-R23D78RoleMarker([string]$Text, [string]$Prefix) {
    $lines = @($Text -split "`r?`n" | Where-Object {
        ([string]$_).StartsWith($Prefix, [StringComparison]::Ordinal)
    })
    Assert-R23D78Role ($lines.Count -eq 1) (
        "expected one '$Prefix' marker, observed $($lines.Count)"
    )
    return $lines[0].Substring($Prefix.Length) |
        ConvertFrom-Json -AsHashtable -Depth 100
}

$pythonHost = Resolve-R23D78RoleApplication $Python $mujocoPython
$powerShellHost = Resolve-R23D78RoleApplication $PowerShell "pwsh"
$godotHost = Resolve-R23D78RoleApplication $Godot $Godot

Assert-R23D78Role (
    (& git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot.TrimEnd("\", "/") -and
    (& git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "repository identity changed"
foreach ($path in @(
    $implementationPath,
    $implementationMaterializer,
    $declarationPath,
    $manifestPath,
    $manifestMaterializer,
    $zeroWorldGatePath,
    $evaluatorPath,
    $supervisorPath,
    $provenanceContractPath,
    $provenanceInventoryPath,
    $provenanceGatePath
)) {
    Assert-R23D78Role (Test-Path -LiteralPath $path -PathType Leaf) (
        "role source is missing: $path"
    )
}

$implementation = Get-Content -LiteralPath $implementationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$declaration = Get-Content -LiteralPath $declarationPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$manifest = Get-Content -LiteralPath $manifestPath -Raw |
    ConvertFrom-Json -AsHashtable -Depth 100
$zeroWorldGate = Get-Command $zeroWorldGatePath
$manifestProvenanceBindings = @($manifest.source_bindings | Where-Object {
    [string]$_.path -cin @(
        "sdk/closure_evidence_provenance_contract.json",
        "sdk/closure_evidence_mode_inventory.json",
        "tests/test_closure_evidence_provenance_contract.ps1"
    )
})

Assert-R23D78Role (
    [string]$implementation.campaign_id -ceq $campaignId -and
    [string]$implementation.gate_id -ceq "QSDK-R23D78" -and
    [string]$implementation.question_class -ceq "finite_decision" -and
    [bool]$implementation.claims.implementation_complete -and
    [bool]$implementation.claims.complete_zero_world_gate_passed -and
    [bool]$implementation.claims.both_predecessor_replays_passed -and
    [bool]$implementation.evaluator.r23d77_existing_file_identity_verifier_bound -and
    -not [bool]$implementation.claims.native_smoke_passed -and
    -not [bool]$implementation.claims.new_native_smoke_required -and
    -not [bool]$implementation.claims.full_seeded_world_ghost_used -and
    -not [bool]$implementation.claims.physical_campaign_opened -and
    @($implementation.ordered_cell_ids).Count -eq 9 -and
    [int]$implementation.dependency_inventory.transitive_path_count -eq 227 -and
    @($implementation.dependency_digests.Keys).Count -eq 227
) "implementation authority changed"
Assert-R23D78Role (
    [string]$declaration.campaign_id -ceq $campaignId -and
    -not [bool]$declaration.post_zero_world_native_smoke.required_before_qualification -and
    [int]$declaration.post_zero_world_native_smoke.maximum_world_count -eq 0 -and
    [int]$declaration.post_zero_world_native_smoke.maximum_solver_step_count_per_world -eq 0 -and
    [int]$declaration.post_zero_world_native_smoke.r23d76_complete_native_horizon_count_used_for_route_adequacy -eq 9 -and
    -not [bool]$declaration.post_zero_world_native_smoke.r23d76_reused_as_r23d78_finite_result
) "native-route adequacy boundary changed"
Assert-R23D78Role (
    $zeroWorldGate.Parameters.ContainsKey(
        "ExpectProductionConformanceLockHeld"
    ) -and
    $zeroWorldGate.Parameters[
        "ExpectProductionConformanceLockHeld"
    ].ParameterType -eq [Management.Automation.SwitchParameter]
) "zero-world parent-lock binding changed"
Assert-R23D78Role (
    [string]$manifest.campaign_id -ceq $campaignId -and
    [string]$manifest.question_class -ceq "finite_decision" -and
    [int]$manifest.declared_physical_world_count -eq 9 -and
    [int]$manifest.declared_lineage_gate_count -eq 1 -and
    [int]$manifest.declared_campaign_gate_count -eq 3 -and
    [int]$manifest.declared_total_gate_count -eq 4 -and
    [int]$manifest.declared_role_binding_count -eq 3 -and
    @($manifest.source_bindings).Count -eq 233 -and
    [string]$manifest.lineage_gates[0].path -ceq
        "tests/test_qsdk_r23d78_zero_world.ps1" -and
    (@($manifest.lineage_gates[0].arguments) -contains
        "-ExpectProductionConformanceLockHeld") -and
    (@($manifest.lineage_gates[0].arguments) -notcontains "-Python") -and
    (@($manifest.lineage_gates[0].arguments) -notcontains "<python>") -and
    -not [bool]$manifest.native_smoke_waiver.new_smoke_required -and
    [int]$manifest.native_smoke_waiver.r23d76_complete_native_horizon_count -eq 9 -and
    -not [bool]$manifest.native_smoke_waiver.r23d76_reused_as_r23d78_result -and
    [bool]$manifest.qualification_runtime_partition.outer_commissioned_runtime_python_recorded_by_attestation -and
    -not [bool]$manifest.qualification_runtime_partition.lineage_outer_python_argument_forwarded -and
    [string]$manifest.qualification_runtime_partition.lineage_mujoco_python_resolution -ceq
        "tests/test_qsdk_r23d78_zero_world.ps1 default sdk/adapters/mujoco/.venv/Scripts/python.exe" -and
    [string]$manifest.qualification_runtime_partition.first_test_only_ghost.status -ceq
        "retained_non_official_runtime_partition_failure" -and
    [string]$manifest.qualification_runtime_partition.first_test_only_ghost.source_commit -ceq
        "0e47997990617ee5582b6ebacd552ad4a29378af" -and
    [bool]$manifest.qualification_runtime_partition.first_test_only_ghost.test_only -and
    [bool]$manifest.qualification_runtime_partition.first_test_only_ghost.global_gates_skipped -and
    [int]$manifest.qualification_runtime_partition.first_test_only_ghost.failed_gate_ordinal -eq 1 -and
    [string]$manifest.qualification_runtime_partition.first_test_only_ghost.failed_gate_id -ceq
        "R23D78-COMPLETE-ZERO-WORLD" -and
    [string]$manifest.qualification_runtime_partition.first_test_only_ghost.failure_code -ceq
        "outer_system_python_missing_mujoco_module" -and
    [int]$manifest.qualification_runtime_partition.first_test_only_ghost.retained_file_count -eq 4 -and
    [long]$manifest.qualification_runtime_partition.first_test_only_ghost.retained_byte_count -eq 4355 -and
    [int]$manifest.qualification_runtime_partition.first_test_only_ghost.physical_process_launch_count -eq 0 -and
    [int]$manifest.qualification_runtime_partition.first_test_only_ghost.physical_world_count -eq 0 -and
    [int]$manifest.qualification_runtime_partition.first_test_only_ghost.model_construction_count -eq 0 -and
    [int]$manifest.qualification_runtime_partition.first_test_only_ghost.solver_step_count -eq 0 -and
    -not [bool]$manifest.qualification_runtime_partition.campaign_semantics_changed -and
    [int]$manifest.qualification_runtime_partition.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [int]$manifest.qualification_runtime_partition.physical_world_count -eq 0 -and
    [string]$manifest.qualification_predecessor_failure.status -ceq
        "retained_failed_closed_global_gate_4_before_campaign_roles" -and
    [string]$manifest.qualification_predecessor_failure.process_question_class -ceq
        "development" -and
    [string]$manifest.qualification_predecessor_failure.physical_question_class_inherited_unchanged -ceq
        "finite_decision" -and
    [string]$manifest.qualification_predecessor_failure.source_commit -ceq
        "0e47997990617ee5582b6ebacd552ad4a29378af" -and
    [string]$manifest.qualification_predecessor_failure.source_tree_git_oid -ceq
        "685aa3738e16e0fd00ad849787bc75cab75d5527" -and
    [int]$manifest.qualification_predecessor_failure.passed_global_gate_count -eq 3 -and
    [int]$manifest.qualification_predecessor_failure.failed_gate_ordinal -eq 4 -and
    [string]$manifest.qualification_predecessor_failure.failed_gate_id -ceq
        "CAK1-EVIDENCE-PROVENANCE" -and
    [int]$manifest.qualification_predecessor_failure.campaign_role_gate_count -eq 0 -and
    [int]$manifest.qualification_predecessor_failure.model_construction_count -eq 0 -and
    [int]$manifest.qualification_predecessor_failure.world_attempt_count -eq 0 -and
    [int]$manifest.qualification_predecessor_failure.world_build_count -eq 0 -and
    [int]$manifest.qualification_predecessor_failure.solver_step_count -eq 0 -and
    [int]$manifest.qualification_predecessor_failure.retained_file_count -eq 13 -and
    [long]$manifest.qualification_predecessor_failure.retained_byte_count -eq 12653 -and
    @($manifest.qualification_predecessor_failure.critical_evidence).Count -eq 3 -and
    -not [bool]$manifest.qualification_predecessor_failure.same_source_rerun_allowed -and
    [bool]$manifest.qualification_predecessor_failure.distinct_corrected_clean_pushed_source_required -and
    [int]$manifest.qualification_predecessor_failure.threshold_selector_evaluator_result_or_interpretation_change_count -eq 0 -and
    [string]$manifest.provenance_reconciliation.contract_path -ceq
        "sdk/closure_evidence_provenance_contract.json" -and
    [string]$manifest.provenance_reconciliation.inventory_path -ceq
        "sdk/closure_evidence_mode_inventory.json" -and
    [string]$manifest.provenance_reconciliation.gate_path -ceq
        "tests/test_closure_evidence_provenance_contract.ps1" -and
    [int]$manifest.provenance_reconciliation.complete_inventory_population_size -eq 184 -and
    [bool]$manifest.provenance_reconciliation.complete_inventory_population_compared -and
    [int]$manifest.provenance_reconciliation.added_audit_count -eq 1 -and
    [int]$manifest.provenance_reconciliation.changed_audit_count -eq 0 -and
    [int]$manifest.provenance_reconciliation.removed_audit_count -eq 0 -and
    [string]$manifest.provenance_reconciliation.added_entry.path -ceq
        "tests/test_qsdk_r23d76_physical_closure.ps1" -and
    -not [bool]$manifest.provenance_reconciliation.historical_result_reinterpreted -and
    [int]$manifest.provenance_reconciliation.physical_world_count -eq 0 -and
    $manifestProvenanceBindings.Count -eq 3 -and
    -not [bool]$manifest.physical_execution_authorized -and
    -not [bool]$manifest.physical_acceptance_authority
) "campaign manifest boundary changed"
foreach ($binding in @(
    [ordered]@{
        Path = "sdk/closure_evidence_provenance_contract.json"
        FullPath = $provenanceContractPath
        ManifestSha = [string]$manifest.provenance_reconciliation.contract_raw_sha256
    },
    [ordered]@{
        Path = "sdk/closure_evidence_mode_inventory.json"
        FullPath = $provenanceInventoryPath
        ManifestSha = [string]$manifest.provenance_reconciliation.inventory_raw_sha256
    },
    [ordered]@{
        Path = "tests/test_closure_evidence_provenance_contract.ps1"
        FullPath = $provenanceGatePath
        ManifestSha = [string]$manifest.provenance_reconciliation.gate_raw_sha256
    }
)) {
    $sourceBinding = @($manifestProvenanceBindings | Where-Object {
        [string]$_.path -ceq [string]$binding.Path
    })
    Assert-R23D78Role (
        $sourceBinding.Count -eq 1 -and
        [string]$sourceBinding[0].raw_sha256 -ceq
            (Get-R23D78RoleSha256 $binding.FullPath) -and
        [string]$binding.ManifestSha -ceq
            (Get-R23D78RoleSha256 $binding.FullPath)
    ) "provenance source binding changed: $($binding.Path)"
}

$receipt = switch ($Role) {
    "worker" {
        $implementationCheck = Invoke-R23D78RoleProcess $pythonHost @(
            "-B", $implementationMaterializer, "check"
        )
        $manifestCheck = Invoke-R23D78RoleProcess $pythonHost @(
            "-B", $manifestMaterializer, "check"
        )
        Assert-R23D78Role (
            [int]$implementationCheck.exit_code -eq 0 -and
            -not [bool]$implementationCheck.timed_out -and
            [string]$implementationCheck.stdout -cmatch
                "QSDK_R23D78_IMPLEMENTATION" -and
            [int]$manifestCheck.exit_code -eq 0 -and
            -not [bool]$manifestCheck.timed_out -and
            [string]$manifestCheck.stdout -cmatch
                "QSDK_R23D78_ATTESTATION_MANIFEST"
        ) (
            "materialized worker/manifest binding drifted: " +
            "$($implementationCheck.stderr) $($manifestCheck.stderr)"
        )
        $workerCount = 0
        foreach ($engineId in @("godot_jolt", "rapier_parry", "mujoco")) {
            $worker = $implementation.workers[$engineId]
            $path = Join-Path $repoRoot ([string]$worker.path)
            Assert-R23D78Role (
                (Test-Path -LiteralPath $path -PathType Leaf) -and
                (Get-R23D78RoleSha256 $path) -ceq [string]$worker.raw_sha256 -and
                [bool]$worker.shared_native_kernel_reused -and
                [bool]$worker.implementation_complete -and
                -not [bool]$worker.physical_execution_authorized -and
                -not [bool]$worker.physical_acceptance_authority
            ) "worker binding changed: $engineId"
            $workerCount += 1
        }
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d78_worker_role_gate_v1"
            bound_worker_count = $workerCount
            complete_dependency_inventory_bound = $true
            native_smoke_waiver_bound = $true
            r23d77_existing_file_identity_verifier_bound = $true
            authorization_receipt_contract_bound = $true
            returned_before_model = $true
        }
    }
    "evaluator" {
        Assert-R23D78Role (
            [string]$implementation.evaluator.path -ceq
                "sdk/turning/r23d78_production_route_three_engine_turning_evaluator.py" -and
            [string]$implementation.evaluator.raw_sha256 -ceq
                (Get-R23D78RoleSha256 $evaluatorPath) -and
            [bool]$implementation.evaluator.accepted_algorithm_rebound_without_threshold_change -and
            [bool]$implementation.evaluator.engine_aware_startup_binding -and
            [bool]$implementation.evaluator.r23d77_existing_file_identity_verifier_bound -and
            (@($implementation.evaluator.outcome_classes) -join "|") -ceq
                "positive|negative|invalid|incomplete"
        ) "evaluator binding changed"
        $compile = Invoke-R23D78RoleProcess $pythonHost @(
            "-B", "-m", "py_compile", $evaluatorPath
        )
        Assert-R23D78Role (
            [int]$compile.exit_code -eq 0 -and -not [bool]$compile.timed_out
        ) "evaluator compile failed: $($compile.stderr)"
        [ordered]@{
            schema_version = "sporespore_qsdk_r23d78_evaluator_role_gate_v1"
            accepted_algorithm_bound_without_threshold_change = $true
            engine_aware_startup_binding = $true
            r23d77_existing_file_identity_verifier_bound = $true
            outcome_class_count = 4
            returned_before_model = $true
        }
    }
    "supervisor" {
        $process = Invoke-R23D78RoleProcess $powerShellHost @(
            "-NoLogo", "-NoProfile", "-File", $supervisorPath,
            "-RolePreflight",
            "-Python", $pythonHost,
            "-Godot", $godotHost,
            "-PowerShell", $powerShellHost
        ) 900
        Assert-R23D78Role (
            [int]$process.exit_code -eq 0 -and -not [bool]$process.timed_out
        ) "supervisor role preflight failed: $($process.stderr) $($process.stdout)"
        $supervisor = Get-R23D78RoleMarker $process.stdout (
            "QSDK_R23D78_SUPERVISOR_ROLE_PREFLIGHT "
        )
        Assert-R23D78Role (
            [string]$supervisor.campaign_id -ceq $campaignId -and
            [string]$supervisor.gate_id -ceq "QSDK-R23D78" -and
            [string]$supervisor.question_class -ceq "finite_decision" -and
            [int]$supervisor.implementation_dependency_count -eq 227 -and
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
            schema_version = "sporespore_qsdk_r23d78_supervisor_role_gate_v1"
            implementation_dependency_count =
                [int]$supervisor.implementation_dependency_count
            terminal_transport_control_count =
                [int]$supervisor.terminal_transport_control_count
            success_terminal_transport_control_count =
                [int]$supervisor.success_terminal_transport_control_count
            failure_terminal_transport_control_count =
                [int]$supervisor.failure_terminal_transport_control_count
            clean_git_source_bindings_checked =
                [bool]$supervisor.clean_git_source_bindings_checked
            returned_before_model = $true
        }
    }
}

$receipt["campaign_id"] = $campaignId
$receipt["gate_id"] = "QSDK-R23D78"
$receipt["question_class"] = "finite_decision"
$receipt["role"] = $Role
$receipt["model_construction_count"] = 0
$receipt["world_attempt_count"] = 0
$receipt["world_build_count"] = 0
$receipt["physical_execution_authorized"] = $false
$receipt["physical_acceptance_authority"] = $false

$prefix = switch ($Role) {
    "worker" { "QSDK_R23D78_CAMPAIGN_WORKER_ROLE_PASS " }
    "evaluator" { "QSDK_R23D78_CAMPAIGN_EVALUATOR_ROLE_PASS " }
    default { "QSDK_R23D78_CAMPAIGN_SUPERVISOR_ROLE_PASS " }
}
Write-Output ($prefix + ($receipt | ConvertTo-Json -Compress -Depth 100))
