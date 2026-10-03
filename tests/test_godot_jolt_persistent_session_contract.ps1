#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\godot_jolt_persistent_session_contract.json"
$corePath = Join-Path $repoRoot "sdk\core\src\ffi.rs"
$headerPath = Join-Path $repoRoot "sdk\include\sporespore_locomotion.h"
$manifestPath = Join-Path $repoRoot "sdk\versioning\c_abi_manifest_v1.json"
$registryPath = Join-Path $repoRoot "sdk\versioning\schema_registry_v1.json"
$rustAdapterPath = Join-Path $repoRoot "sdk\adapters\godot\src\lib.rs"
$pythonPath = Join-Path $repoRoot "sdk\python\sporespore_locomotion.py"
$gdAdapterPath = Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$runnerPaths = @(
    (Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"),
    (Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped_bw30n_fixed_horizon.gd")
)
$benchmarkPath = Join-Path $repoRoot "sdk\run_godot_jolt_persistent_session_benchmark.ps1"
$conformancePath = Join-Path $repoRoot "sdk\run_conformance.ps1"

function Assert-Exact {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Get-ExactBlock {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Start,
        [Parameter(Mandatory = $true)][string]$End
    )
    $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
    Assert-Exact ($startIndex -ge 0) "Missing block start '$Start'."
    $endIndex = $Text.IndexOf(
        $End,
        $startIndex + $Start.Length,
        [StringComparison]::Ordinal
    )
    Assert-Exact ($endIndex -gt $startIndex) "Missing block end '$End'."
    return $Text.Substring($startIndex, $endIndex - $startIndex)
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$identity = $contract["execution_identity"]
$lifecycle = $contract["lifecycle_contract"]
$equivalence = $contract["equivalence_contract"]
$benchmark = $contract["benchmark_execution_contract"]
$observation = $contract["development_benchmark_observation"]
$failClosed = $contract["fail_closed_contract"]
$future = $contract["future_campaign_requirements"]
$evidence = $contract["evidence_boundary"]
$version = "sporespore_godot_balanced_wave_persistent_session_v1"
$runtimeSchema = "sporespore_godot_controller_session_execution_contract_v1"
$createSchema = "sporespore_balanced_wave_policy_session_create_request_v1"
$stepSchema = "sporespore_balanced_wave_policy_session_step_request_v1"
$memorySchema = "sporespore_balanced_wave_policy_initial_memory_request_v1"

Assert-Exact (
    [string]$contract["schema_version"] -ceq
        "sporespore_godot_jolt_persistent_session_contract_declaration_v1" -and
    [string]$contract["contract_id"] -ceq "GJPS1" -and
    [string]$contract["status"] -ceq "active_zero_world_contract"
) "GJPS1 declaration identity changed."
Assert-Exact (
    [string]$identity["session_execution_version"] -ceq $version -and
    [string]$identity["runtime_contract_schema_version"] -ceq $runtimeSchema -and
    [string]$identity["create_request_schema_version"] -ceq $createSchema -and
    [string]$identity["step_request_schema_version"] -ceq $stepSchema -and
    [string]$identity["initial_memory_request_schema_version"] -ceq $memorySchema -and
    [string]$identity["c_abi_initial_memory_symbol"] -ceq
        "ss_balanced_wave_policy_initial_memory_json" -and
    [string]$identity["controller_memory_initialization"] -ceq
        "explicit_named_policy" -and
    [string]$identity["handle_type"] -ceq "process_local_opaque_nonzero_u64" -and
    [string]$identity["controller_memory_transport"] -ceq "explicit_every_step" -and
    [bool]$identity["compiled_morphology_reused"] -and
    [bool]$identity["controller_profile_reused"] -and
    [bool]$identity["automatic_destroy_on_adapter_release"] -and
    [bool]$identity["explicit_terminal_shutdown_supported"]
) "GJPS1 execution identity changed."
Assert-Exact (
    [int]$lifecycle["create_count_per_balanced_wave_adapter_start"] -eq 1 -and
    [bool]$lifecycle["step_requires_active_handle"] -and
    -not [bool]$lifecycle["step_mutates_hidden_controller_state"] -and
    [bool]$lifecycle["step_size_query_is_pure"] -and
    [int]$lifecycle["destroy_count_per_handle"] -eq 1 -and
    [bool]$lifecycle["adapter_release_destroys_active_handle"] -and
    [bool]$lifecycle["startup_failure_after_create_destroys_active_handle"] -and
    [bool]$lifecycle["successful_runner_explicitly_destroys_active_handle"] -and
    [bool]$lifecycle["automatic_drop_is_fallback_not_normal_success_path"] -and
    [string]$lifecycle["explicit_shutdown_receipt_schema_version"] -ceq
        "sporespore_godot_jolt_adapter_shutdown_receipt_v1"
) "GJPS1 lifecycle contract changed."
Assert-Exact (
    [string]$equivalence["comparison"] -ceq
        "exact_status_and_serialized_output_bytes" -and
    -not [bool]$equivalence["floating_point_tolerance_used"] -and
    [int]$equivalence["world_build_count"] -eq 0 -and
    -not [bool]$equivalence["physical_acceptance_authority"]
) "GJPS1 equivalence contract changed."
Assert-Exact (
    @($contract["required_source_routes"]).Count -eq 10 -and
    @($future["all_new_godot_jolt_physical_declarations_must_pin"]).Count -eq 11 -and
    @($future["all_new_worker_preflights_must_assert"]).Count -eq 12 -and
    [string]$future["freeze_mismatch_timing"] -ceq "before_physics_world_entry" -and
    -not [bool]$future["old_campaign_interpretation_changes_allowed"]
) "GJPS1 source or future-campaign obligations changed."
Assert-Exact (
    -not [bool]$failClosed["silent_stateless_fallback_for_balanced_wave"] -and
    [int]$failClosed["failure_world_build_count"] -eq 0 -and
    [int]$failClosed["failure_scene_tree_insertion_count"] -eq 0 -and
    -not [bool]$failClosed["failure_physics_state_modified"] -and
    -not [bool]$failClosed["failure_physical_acceptance_authority"]
) "GJPS1 fail-closed boundary changed."
Assert-Exact (
    [string]$benchmark["entrypoint"] -ceq
        "sdk/run_godot_jolt_persistent_session_benchmark.ps1" -and
    [bool]$benchmark["cargo_target_must_be_outside_repository"] -and
    -not [bool]$benchmark["canonical_sdk_target_permitted"] -and
    [bool]$benchmark["canonical_release_artifact_hashes_verified_unchanged"] -and
    [bool]$benchmark["canonical_release_artifact_backups_retained"] -and
    [string]$benchmark["stateless_reference"] -ceq
        "GJTP1 preallocated single-pass" -and
    [string]$observation["status"] -in @("not_yet_executed", "complete_dirty_source_zero_world")
) "GJPS1 benchmark contract changed."
Assert-Exact (
    [int]$evidence["world_build_count"] -eq 0 -and
    -not [bool]$evidence["physical_acceptance_authority"] -and
    -not [bool]$evidence["walking_acceptance"] -and
    [bool]$evidence["whole_cell_speedup_requires_separate_measurement"] -and
    -not [bool]$evidence["cross_engine_equivalence"] -and
    -not [bool]$evidence["release_authorized"] -and
    -not [bool]$evidence["completed_engine_neutral_sdk"]
) "GJPS1 evidence boundary inflated."

$core = Get-Content -Raw -LiteralPath $corePath
foreach ($required in @(
    "NEXT_BALANCED_WAVE_POLICY_SESSION_HANDLE",
    "BALANCED_WAVE_POLICY_SESSIONS",
    "Mutex<HashMap<u64, Arc<BalancedWaveController>>>",
    "pub unsafe extern `"C`" fn ss_balanced_wave_policy_session_create_json(",
    "pub unsafe extern `"C`" fn ss_balanced_wave_policy_session_step_json(",
    "pub extern `"C`" fn ss_balanced_wave_policy_session_destroy(",
    $createSchema,
    $stepSchema,
    "balanced_wave_policy_session_handle_unknown",
    "ss_balanced_wave_policy_initial_memory_json",
    $memorySchema
)) {
    Assert-Exact ($core.Contains($required)) "Portable core is missing '$required'."
}
$sessionStepBlock = Get-ExactBlock $core (
    "pub unsafe extern `"C`" fn ss_balanced_wave_policy_session_step_json("
) "pub extern `"C`" fn ss_balanced_wave_policy_session_destroy("
Assert-Exact (
    $sessionStepBlock.Contains("controller.step(") -and
    -not $sessionStepBlock.Contains("compile_bounded_quadruped") -and
    -not $sessionStepBlock.Contains("new_for_policy")
) "The persistent step path recompiles morphology or controller policy."

$header = Get-Content -Raw -LiteralPath $headerPath
foreach ($required in @(
    "uint64_t *session_handle",
    "uint64_t session_handle",
    "ss_balanced_wave_policy_session_create_json(",
    "ss_balanced_wave_policy_session_step_json(",
    "ss_balanced_wave_policy_session_destroy(",
    "ss_balanced_wave_policy_initial_memory_json(",
    "Handles are process-local, opaque, nonzero",
    "Controller memory remains explicit in every step request"
)) {
    Assert-Exact ($header.Contains($required)) "Public header is missing '$required'."
}

$manifest = Get-Content -Raw -LiteralPath $manifestPath |
    ConvertFrom-Json -AsHashtable -Depth 32
$manifestByName = @{}
foreach ($entry in $manifest["symbols"]) { $manifestByName[$entry["name"]] = $entry }
Assert-Exact (
    $manifestByName.Count -eq $manifest["symbols"].Count -and
    [string]$manifestByName["ss_balanced_wave_policy_initial_memory_json"]["input_schema"] -ceq $memorySchema -and
    [string]$manifestByName["ss_balanced_wave_policy_session_create_json"]["input_schema"] -ceq $createSchema -and
    [string]$manifestByName["ss_balanced_wave_policy_session_step_json"]["input_schema"] -ceq $stepSchema -and
    $null -eq $manifestByName["ss_balanced_wave_policy_session_destroy"]["input_schema"]
) "C ABI manifest does not bind all three GJPS1 lifecycle symbols."
$registry = Get-Content -Raw -LiteralPath $registryPath |
    ConvertFrom-Json -AsHashtable -Depth 32
$registeredSchemas = @($registry["schemas"] | ForEach-Object { [string]$_["schema_id"] })
Assert-Exact (
    $registeredSchemas.Contains($memorySchema) -and
    $registeredSchemas.Contains($createSchema) -and
    $registeredSchemas.Contains($stepSchema)
) "GJPS1 schemas are absent from the public registry."

$rustAdapter = Get-Content -Raw -LiteralPath $rustAdapterPath
foreach ($required in @(
    "pub const CONTROLLER_SESSION_EXECUTION_VERSION: &str",
    $version,
    $runtimeSchema,
    $memorySchema,
    "`"controller_memory_initialization`": `"explicit_named_policy`"",
    "fn controller_session_execution_contract_json(&self) -> GString",
    "fn balanced_wave_policy_session_create_json(&mut self, input: GString)",
    "fn balanced_wave_policy_initial_memory_json(&self, input: GString)",
    "fn balanced_wave_policy_session_step_json(&self, input: GString)",
    "fn balanced_wave_policy_session_destroy_json(&mut self)",
    "impl Drop for SporeLocomotionSdk",
    "fn persistent_session_matches_stateless_bytes_and_fails_after_destroy()"
)) {
    Assert-Exact ($rustAdapter.Contains($required)) "Godot Rust adapter is missing '$required'."
}
$python = Get-Content -Raw -LiteralPath $pythonPath
Assert-Exact (
    $python.Contains("class BalancedWavePolicySession:") -and
    $python.Contains("def balanced_wave_policy_initial_memory(") -and
    $python.Contains("def create_balanced_wave_policy_session(") -and
    $python.Contains("def close(self) -> None:")
) "Python convenience binding does not own the GJPS1 lifecycle."

$gdAdapter = Get-Content -Raw -LiteralPath $gdAdapterPath
foreach ($required in @(
    "const CONTROLLER_SESSION_EXECUTION_VERSION := (",
    $version,
    "ADAPTER_CONTROLLER_SESSION_VERSION_METHOD_MISSING",
    "ADAPTER_CONTROLLER_SESSION_EXECUTION_VERSION_MISMATCH",
    "ADAPTER_CONTROLLER_SESSION_CONTRACT_MISMATCH",
    "balanced_wave_policy_session_create_json",
    "balanced_wave_policy_session_step_json",
    "balanced_wave_policy_session_destroy_json",
    "func shutdown() -> Dictionary:",
    "sporespore_godot_jolt_adapter_shutdown_receipt_v1",
    "balanced_wave_policy_initial_memory_json",
    $memorySchema,
    "`"controller_session_execution`"",
    "`"controller_session_execution_contract_sha256`""
)) {
    Assert-Exact ($gdAdapter.Contains($required)) "GDScript adapter is missing '$required'."
}
$validationIndex = $gdAdapter.IndexOf(
    "var transport_receipt := _validate_transport_api(_api)",
    [StringComparison]::Ordinal
)
$descriptorIndex = $gdAdapter.IndexOf(
    "_descriptor = descriptor.duplicate(true)",
    [StringComparison]::Ordinal
)
Assert-Exact (
    $validationIndex -ge 0 -and $descriptorIndex -gt $validationIndex
) "GJPS1 validation no longer precedes descriptor compilation."
$requestBlock = Get-ExactBlock $gdAdapter "func _controller_step_request(" "func _is_balanced_wave_policy("
Assert-Exact (
    $requestBlock.Contains("if not _is_balanced_wave_policy(_controller_policy_id):") -and
    $requestBlock.Contains('request["descriptor"] = _descriptor') -and
    -not $requestBlock.Contains('request["policy_id"]')
) "Balanced-wave session requests can still carry redundant descriptor or policy fields."

foreach ($runnerPath in $runnerPaths) {
    $runner = Get-Content -Raw -LiteralPath $runnerPath
    $preflightIndex = $runner.IndexOf(
        "SdkGodotJoltAdapterScript.preflight_transport_execution()",
        [StringComparison]::Ordinal
    )
    $returnIndex = $runner.IndexOf("if preflight_before_world:", [StringComparison]::Ordinal)
    $worldIndex = $runner.IndexOf("await _build_fixture(", [StringComparison]::Ordinal)
    Assert-Exact (
        $preflightIndex -ge 0 -and
        $returnIndex -gt $preflightIndex -and
        $worldIndex -gt $returnIndex -and
        $runner.Contains('"sdk_transport_execution_receipt"') -and
        $runner.Contains("sdk_adapter.shutdown()") -and
        $runner.Contains('"sdk_adapter_shutdown_receipt"')
    ) "A real-physics runner does not retain GJPS1 before world construction: $runnerPath"
}

$benchmarkRunner = Get-Content -Raw -LiteralPath $benchmarkPath
foreach ($required in @(
    "SporeSpore_Evidence",
    "--target-dir `$isolatedTarget",
    "benchmark_persistent_session_against_stateless_single_pass",
    "GODOT_JOLT_SESSION_BENCHMARK_CANONICAL_ARTIFACT_MUTATION",
    "GODOT_JOLT_SESSION_BENCHMARK_EVIDENCE_ROOT_ALREADY_EXISTS",
    "GODOT_JOLT_SESSION_BENCHMARK_SOURCE_DRIFT",
    "canonical-release-artifact-backup",
    "development_native_boundary_microbenchmark_only",
    'physical_acceptance_authority = $false',
    "world_build_count = 0"
)) {
    Assert-Exact ($benchmarkRunner.Contains($required)) "Benchmark runner is missing '$required'."
}
$conformance = Get-Content -Raw -LiteralPath $conformancePath
Assert-Exact (
    $conformance.Contains("test_godot_jolt_persistent_session_contract.ps1") -and
    $conformance.Contains("test_sdk_godot_jolt_persistent_session_contract.gd")
) "GJPS1 source and live audits are not mandatory in normal conformance."

$authorityPaths = @(
    (Join-Path $repoRoot "docs\README.md"),
    (Join-Path $repoRoot "docs\ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md"),
    (Join-Path $repoRoot "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"),
    (Join-Path $repoRoot "sdk\README.md")
)
foreach ($authorityPath in $authorityPaths) {
    $authority = Get-Content -Raw -LiteralPath $authorityPath
    Assert-Exact (
        $authority.Contains("godot_jolt_persistent_session_contract.json") -and
        $authority.Contains($version) -and
        $authority.Contains("run_godot_jolt_persistent_session_benchmark.ps1")
    ) "Repository authority does not identify GJPS1: $authorityPath"
}

$contractHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $contractPath).Hash.ToLowerInvariant()
Write-Host (
    "GODOT_JOLT_PERSISTENT_SESSION_SOURCE_CONTRACT_PASS " +
    "version=$version symbols=4 schemas=3 runners=2 worlds=0 " +
    "physical_authority=False contract_sha256=sha256:$contractHash"
)
