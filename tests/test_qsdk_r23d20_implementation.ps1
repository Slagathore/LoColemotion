#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$contractPath = Join-Path $repoRoot "sdk\turning\r23d20_physical_implementation_contract_v1.json"
$preregistrationPath = Join-Path $repoRoot "sdk\turning\r23d20_actual_session_integration_recovery_preregistration_v1.json"
$controllerPath = Join-Path $repoRoot "sdk\core\src\controller.rs"
$runtimePath = Join-Path $repoRoot "sdk\core\src\runtime.rs"
$adapterPath = Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$supervisorPath = Join-Path $repoRoot "sdk\run_qsdk_r23d20_supervisor.ps1"
$workerPath = Join-Path $repoRoot "tests\test_sdk_qsdk_r23d20_godot_jolt_physical_worker.gd"
$closurePath = Join-Path $repoRoot "sdk\turning\r23d20_physical_closure_v1.json"

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistrationSha = "sha256:" + (
    Get-FileHash -LiteralPath $preregistrationPath -Algorithm SHA256
).Hash.ToLowerInvariant()
$controller = Get-Content -Raw -LiteralPath $controllerPath
$runtime = Get-Content -Raw -LiteralPath $runtimePath
$adapter = Get-Content -Raw -LiteralPath $adapterPath
$supervisor = Get-Content -Raw -LiteralPath $supervisorPath
$worker = Get-Content -Raw -LiteralPath $workerPath
$paths = @($contract.dependency_closure.required_dependency_paths_by_worker.godot_jolt)
$missing = @($paths | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path $repoRoot ([string]$_)) -PathType Leaf)
})

$valid = (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d20_physical_implementation_contract_v1" -and
    [string]$contract.campaign_id -ceq
        "QSDK-R23D20-ACTUAL-SESSION-INTEGRATION-RECOVERY-GODOT-DEVELOPMENT" -and
    [string]$contract.gate_id -ceq "QSDK-R23D20" -and
    [string]$contract.lineage.preregistration_raw_sha256 -ceq $preregistrationSha -and
    [string]$contract.integration_recovery.controller_policy_id -ceq
        "sporespore_balanced_wave_r23d19_heading_aligned_path_v1" -and
    -not [bool]$contract.integration_recovery.controller_or_physics_change -and
    [bool]$contract.integration_recovery.godot_adapter_selected_policy_start_allowlisted -and
    [bool]$contract.integration_recovery.exact_selected_policy_start_and_runtime_canary -and
    [bool]$contract.integration_recovery.actual_diagnostics_composition_canary -and
    [bool]$contract.integration_recovery.structured_worker_terminal_parsed_independent_of_exit_code -and
    [int]$contract.supervisor.declared_world_count -eq 3 -and
    (@($contract.supervisor.ordered_engine_ids) -join "|") -ceq "godot_jolt" -and
    (@($contract.supervisor.ordered_arm_ids) -join "|") -ceq
        "reference_zero|positive_heading|negative_heading" -and
    [bool]$contract.supervisor.all_cells_serial_without_outcome_early_stop -and
    -not [bool]$contract.supervisor.parallel_execution_permitted -and
    -not [bool]$contract.supervisor.replacement_or_selective_rerun_permitted -and
    [bool]$contract.authorization.commissioned_lca1_adoption_required -and
    [bool]$contract.authorization.positive_and_mutated_exact_worker_authorization_canaries_required -and
    -not [bool]$contract.authorization.physical_execution_authorized -and
    $paths.Count -gt 50 -and
    $paths.Count -eq @($paths | Sort-Object -Unique).Count -and
    $missing.Count -eq 0 -and
    $controller.Contains("BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID") -and
    $controller.Contains("COMMAND_HEADING_ALIGNED_TASK_FRAME_MODE_ID") -and
    $runtime.Contains("command_heading_aligned_lateral_axis") -and
    $adapter.Contains("BALANCED_WAVE_R23D19_HEADING_ALIGNED_PATH_POLICY_ID") -and
    $adapter.Contains("_is_r23d19_heading_aligned_path_policy") -and
    $worker.Contains('authority_options["controller_policy_id"] = R23D20_CONTROLLER_POLICY_ID') -and
    $worker.Contains("_r23d20_selected_policy_adapter_boundary") -and
    $worker.Contains("_r23d20_actual_diagnostics_composition_canary") -and
    $supervisor.Contains("Resolve-R23D20WorkerTerminal") -and
    $supervisor.Contains('marker_kind = "worker_failure_terminal"') -and
    -not (Test-Path -LiteralPath $closurePath)
)

if (-not $valid) {
    throw "QSDK-R23D20 implementation contract audit failed; missing=$($missing -join ',')"
}

Write-Host (
    "QSDK_R23D20_IMPLEMENTATION_PASS " +
    (@{ dependency_count = $paths.Count; declared_world_count = 3;
        model_construction_count = 0; world_attempt_count = 0; world_build_count = 0;
        physical_execution_authorized = $false; physical_acceptance_authority = $false } |
        ConvertTo-Json -Compress)
)
