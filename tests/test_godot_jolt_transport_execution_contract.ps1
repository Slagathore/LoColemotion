#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = [System.IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$contractPath = Join-Path $repoRoot "sdk\godot_jolt_transport_execution_contract.json"
$rustPath = Join-Path $repoRoot "sdk\adapters\godot\src\lib.rs"
$adapterPath = Join-Path $repoRoot "scripts\lab\gait\sdk_godot_jolt_adapter.gd"
$runnerPaths = @(
    (Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped.gd"),
    (Join-Path $repoRoot "scripts\lab\gait\physical_wave_gait_quadruped_bw30n_fixed_horizon.gd")
)
$gaitScriptRoot = Join-Path $repoRoot "scripts\lab\gait"
$conformancePath = Join-Path $repoRoot "sdk\run_conformance.ps1"
$benchmarkPath = Join-Path $repoRoot "sdk\run_godot_jolt_transport_benchmark.ps1"

function Assert-Exact {
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Condition,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    if (-not $Condition) { throw $Message }
}

function Get-ExactBlock {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [Parameter(Mandatory = $true)]
        [string]$Start,
        [Parameter(Mandatory = $true)]
        [string]$End
    )
    $startIndex = $Text.IndexOf($Start, [StringComparison]::Ordinal)
    Assert-Exact ($startIndex -ge 0) "Missing block start '$Start'."
    $endIndex = $Text.IndexOf($End, $startIndex + $Start.Length, [StringComparison]::Ordinal)
    Assert-Exact ($endIndex -gt $startIndex) "Missing block end '$End'."
    return $Text.Substring($startIndex, $endIndex - $startIndex)
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 64
$identity = $contract["execution_identity"]
$failClosed = $contract["fail_closed_contract"]
$future = $contract["future_campaign_requirements"]
$benchmark = $contract["benchmark_execution_contract"]
$benchmarkObservation = $contract["development_benchmark_observation"]
$evidence = $contract["evidence_boundary"]
$requiredSourceRoutes = @($contract["required_source_routes"])

$expectedVersion = "sporespore_godot_json_preallocated_single_pass_v1"
$expectedRuntimeSchema = "sporespore_godot_transport_execution_contract_v1"
Assert-Exact (
    [string]$contract["schema_version"] -ceq
        "sporespore_godot_transport_execution_contract_declaration_v1" -and
    [string]$contract["contract_id"] -ceq "GJTP1" -and
    [string]$contract["status"] -ceq "active_zero_world_contract"
) "GJTP1 declaration identity changed."
Assert-Exact (
    [string]$identity["transport_execution_version"] -ceq $expectedVersion -and
    [string]$identity["runtime_contract_schema_version"] -ceq $expectedRuntimeSchema -and
    [string]$identity["input_transport"] -ceq "normalized_json_utf8" -and
    [string]$identity["output_transport"] -ceq "json_utf8" -and
    [int]$identity["initial_output_capacity_bytes"] -eq 16384 -and
    [int]$identity["normal_path_native_invocation_count"] -eq 1 -and
    [int]$identity["overflow_retry_limit"] -eq 1
) "GJTP1 execution identity changed."
Assert-Exact (
    -not [bool]$failClosed["silent_legacy_fallback"] -and
    [int]$failClosed["failure_world_build_count"] -eq 0 -and
    [int]$failClosed["failure_scene_tree_insertion_count"] -eq 0 -and
    -not [bool]$failClosed["failure_physics_state_modified"] -and
    -not [bool]$failClosed["failure_physical_acceptance_authority"]
) "GJTP1 fail-closed boundary changed."
Assert-Exact (
    @($future["all_new_godot_jolt_physical_declarations_must_pin"]).Count -eq 6 -and
    @($future["all_new_worker_preflights_must_assert"]).Count -eq 7 -and
    [string]$future["freeze_mismatch_timing"] -ceq "before_physics_world_entry" -and
    -not [bool]$future["old_campaign_interpretation_changes_allowed"]
) "GJTP1 future-campaign obligations changed."
Assert-Exact (
    $requiredSourceRoutes.Count -eq 5 -and
    $requiredSourceRoutes[0] -ceq "sdk/adapters/godot/src/lib.rs" -and
    $requiredSourceRoutes[1] -ceq "scripts/lab/gait/sdk_godot_jolt_adapter.gd" -and
    $requiredSourceRoutes[2] -ceq "scripts/lab/gait/physical_wave_gait_quadruped.gd" -and
    $requiredSourceRoutes[3] -ceq
        "scripts/lab/gait/physical_wave_gait_quadruped_bw30n_fixed_horizon.gd" -and
    $requiredSourceRoutes[4] -ceq "sdk/run_godot_jolt_transport_benchmark.ps1"
) "GJTP1 required source routes changed."
Assert-Exact (
    [string]$benchmark["entrypoint"] -ceq
        "sdk/run_godot_jolt_transport_benchmark.ps1" -and
    [bool]$benchmark["cargo_target_must_be_outside_repository"] -and
    -not [bool]$benchmark["canonical_sdk_target_permitted"] -and
    [bool]$benchmark["reusable_isolated_cargo_cache_permitted"] -and
    [bool]$benchmark["durable_evidence_root_required"] -and
    -not [bool]$benchmark["existing_evidence_root_permitted"] -and
    -not [bool]$benchmark["source_drift_permitted"] -and
    [bool]$benchmark["canonical_release_artifact_hashes_verified_unchanged"] -and
    [bool]$benchmark["canonical_release_artifact_backups_retained"] -and
    -not [bool]$benchmark["direct_release_benchmark_in_canonical_sdk_target_permitted"] -and
    [int]$benchmark["world_build_count"] -eq 0 -and
    -not [bool]$benchmark["physical_acceptance_authority"] -and
    [string]$benchmark["claim_scope"] -ceq
        "development_native_boundary_microbenchmark_only"
) "GJTP1 benchmark isolation contract changed."
Assert-Exact (
    [string]$benchmarkObservation["status"] -ceq
        "complete_dirty_source_zero_world" -and
    [string]$benchmarkObservation["source_head"] -ceq
        "416b2fb67c48c15c2aebc89315db913154f0cc31" -and
    -not [bool]$benchmarkObservation["source_worktree_clean"] -and
    [int]$benchmarkObservation["iterations"] -eq 2000 -and
    [int]$benchmarkObservation["input_bytes"] -eq 5162 -and
    [int]$benchmarkObservation["output_bytes"] -eq 5524 -and
    [double]$benchmarkObservation["single_pass_seconds"] -eq 0.578064 -and
    [double]$benchmarkObservation["legacy_two_pass_seconds"] -eq 1.078275 -and
    [double]$benchmarkObservation["native_boundary_speedup"] -eq 1.8653 -and
    [string]$benchmarkObservation["receipt_sha256"] -ceq
        "sha256:2acd9011499707b4e6822b120cae9d982b8d4cb3d7a5b762a098def4c9612949" -and
    [string]$benchmarkObservation["transcript_sha256"] -ceq
        "sha256:409dec4c32f9aab345b685966eeec6d7089117de74a14c02b78dd8aedcde2a6e" -and
    [bool]$benchmarkObservation["canonical_release_artifacts_unchanged"] -and
    [int]$benchmarkObservation["world_build_count"] -eq 0 -and
    -not [bool]$benchmarkObservation["total_cell_speedup_claimed"] -and
    -not [bool]$benchmarkObservation["physical_acceptance_authority"]
) "GJTP1 retained development benchmark observation changed."
Assert-Exact (
    [int]$evidence["world_build_count"] -eq 0 -and
    -not [bool]$evidence["physical_acceptance_authority"] -and
    -not [bool]$evidence["walking_acceptance"] -and
    -not [bool]$evidence["performance_improvement_claimed_before_benchmark"] -and
    -not [bool]$evidence["cross_engine_equivalence"] -and
    -not [bool]$evidence["release_authorized"] -and
    -not [bool]$evidence["completed_engine_neutral_sdk"]
) "GJTP1 evidence boundary inflated."

$rust = Get-Content -Raw -LiteralPath $rustPath
foreach ($required in @(
    "pub const TRANSPORT_EXECUTION_VERSION: &str",
    $expectedVersion,
    $expectedRuntimeSchema,
    "const INITIAL_OUTPUT_CAPACITY_BYTES: usize = 16 * 1024;",
    "const OVERFLOW_RETRY_LIMIT: usize = 1;",
    "fn transport_execution_version(&self) -> GString",
    "fn transport_execution_contract_json(&self) -> GString",
    "normal_path_native_invocation_count",
    "fn normal_path_executes_the_native_operation_exactly_once()",
    "fn no_input_normal_path_executes_the_native_operation_exactly_once()",
    "fn oversized_output_uses_one_exact_size_retry()"
)) {
    Assert-Exact ($rust.Contains($required)) "Rust transport implementation is missing '$required'."
}
$inputBlock = Get-ExactBlock $rust "fn invoke_input_json(" "fn invoke_no_input_json("
Assert-Exact (
    $inputBlock.Contains("vec![0_u8; INITIAL_OUTPUT_CAPACITY_BYTES]") -and
    $inputBlock.Contains("if first_status != SS_BUFFER_TOO_SMALL") -and
    $inputBlock.Contains("output.resize(required, 0)") -and
    $inputBlock.Contains("GODOT_ADAPTER_OUTPUT_RETRY_EXHAUSTED") -and
    -not $inputBlock.Contains("null_mut")
) "Rust input transport no longer proves preallocated single-pass plus one exact-size retry."
$productionRust = $rust.Substring(
    0,
    $rust.IndexOf("#[cfg(test)]", [StringComparison]::Ordinal)
)
Assert-Exact (
    -not $productionRust.Contains("GODOT_ADAPTER_SIZE_QUERY_FAILED") -and
    -not $productionRust.Contains("ptr::null_mut()")
) "The mandatory null-output size-query route was reintroduced."

$adapter = Get-Content -Raw -LiteralPath $adapterPath
foreach ($required in @(
    "const TRANSPORT_EXECUTION_VERSION := `"$expectedVersion`"",
    "const TRANSPORT_INITIAL_OUTPUT_CAPACITY_BYTES := 16384",
    "const TRANSPORT_NORMAL_PATH_NATIVE_INVOCATION_COUNT := 1",
    "const TRANSPORT_OVERFLOW_RETRY_LIMIT := 1",
    "static func preflight_transport_execution() -> Dictionary:",
    "static func _validate_transport_api(api: Object) -> Dictionary:",
    "ADAPTER_TRANSPORT_VERSION_METHOD_MISSING",
    "ADAPTER_TRANSPORT_EXECUTION_VERSION_MISMATCH",
    "ADAPTER_TRANSPORT_CONTRACT_MISMATCH",
    "`"transport_execution`": _transport_execution_contract.duplicate(true)",
    "`"transport_execution_contract_sha256`": _transport_execution_contract_sha256"
)) {
    Assert-Exact ($adapter.Contains($required)) "GDScript transport route is missing '$required'."
}
$startupValidationIndex = $adapter.IndexOf(
    "var transport_receipt := _validate_transport_api(_api)",
    [StringComparison]::Ordinal
)
$descriptorCompileIndex = $adapter.IndexOf(
    "_descriptor = descriptor.duplicate(true)",
    [StringComparison]::Ordinal
)
Assert-Exact (
    $startupValidationIndex -ge 0 -and
    $descriptorCompileIndex -gt $startupValidationIndex
) "Adapter startup does not validate transport identity before descriptor compilation."

$discoveredRunnerPaths = @(
    Get-ChildItem -LiteralPath $gaitScriptRoot -File -Filter "*.gd" |
        Where-Object {
            $candidate = Get-Content -Raw -LiteralPath $_.FullName
            $candidate.Contains("SdkGodotJoltAdapterScript") -and
                $candidate.Contains("await _build_fixture(")
        } |
        ForEach-Object { [System.IO.Path]::GetFullPath($_.FullName) } |
        Sort-Object
)
$expectedRunnerPaths = @(
    $runnerPaths |
        ForEach-Object { [System.IO.Path]::GetFullPath($_) } |
        Sort-Object
)
Assert-Exact (
    $discoveredRunnerPaths.Count -eq $expectedRunnerPaths.Count -and
    ($discoveredRunnerPaths -join "`n") -ceq ($expectedRunnerPaths -join "`n")
) "The real-physics runner set changed without updating the GJTP1 contract and audit."

foreach ($runnerPath in $runnerPaths) {
    $runner = Get-Content -Raw -LiteralPath $runnerPath
    $transportIndex = $runner.IndexOf(
        "SdkGodotJoltAdapterScript.preflight_transport_execution()",
        [StringComparison]::Ordinal
    )
    $preflightReturnIndex = $runner.IndexOf(
        "if preflight_before_world:",
        [StringComparison]::Ordinal
    )
    $worldBuildIndex = $runner.IndexOf("await _build_fixture(", [StringComparison]::Ordinal)
    Assert-Exact (
        $transportIndex -ge 0 -and
        $preflightReturnIndex -gt $transportIndex -and
        $worldBuildIndex -gt $preflightReturnIndex
    ) "Transport validation is not before both preflight return and world construction in '$runnerPath'."
    foreach ($required in @(
        "SDK_TRANSPORT_PREFLIGHT_FAILED:",
        "`"sdk_transport_execution_receipt`"",
        "`"world_build_count`": 0",
        "`"scene_tree_insertion_count`": 0",
        "`"physics_state_modified`": false",
        "`"physical_acceptance_authority`": false"
    )) {
        Assert-Exact ($runner.Contains($required)) "Runner '$runnerPath' is missing '$required'."
    }
}

$conformance = Get-Content -Raw -LiteralPath $conformancePath
Assert-Exact (
    $conformance.Contains("test_godot_jolt_transport_execution_contract.ps1") -and
    $conformance.Contains("test_sdk_godot_jolt_transport_execution_contract.gd")
) "GJTP1 audits are not wired into normal conformance."

$benchmarkRunner = Get-Content -Raw -LiteralPath $benchmarkPath
foreach ($required in @(
    "SporeSpore_Evidence",
    "cargo-target",
    "--target-dir",
    "benchmark_single_pass_against_legacy_two_pass_balanced_wave",
    "GODOT_JOLT_TRANSPORT_BENCHMARK_CANONICAL_ARTIFACT_MUTATION",
    "GODOT_JOLT_TRANSPORT_BENCHMARK_EVIDENCE_ROOT_ALREADY_EXISTS",
    "GODOT_JOLT_TRANSPORT_BENCHMARK_SOURCE_DRIFT",
    "GODOT_JOLT_TRANSPORT_BENCHMARK_TARGET_EVIDENCE_OVERLAP",
    "canonical-release-artifact-backup",
    "development_native_boundary_microbenchmark_only",
    'physical_acceptance_authority = $false',
    "world_build_count = 0"
)) {
    Assert-Exact ($benchmarkRunner.Contains($required)) (
        "Isolated benchmark runner is missing '$required'."
    )
}
Assert-Exact (
    $benchmarkRunner.Contains('$isolatedTarget') -and
    -not $benchmarkRunner.Contains("sdk\\target --release")
) "GJTP1 benchmark runner no longer proves isolated Cargo output."
$cargoBlock = Get-ExactBlock $benchmarkRunner '$output = @(' '$cargoExitCode = $LASTEXITCODE'
Assert-Exact (
    $cargoBlock.Contains('--target-dir $isolatedTarget') -and
    -not $cargoBlock.Contains('$canonicalTarget')
) "GJTP1 benchmark Cargo invocation is not confined to the isolated target."

$authorityPaths = @(
    (Join-Path $repoRoot "docs\README.md"),
    (Join-Path $repoRoot "docs\ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md"),
    (Join-Path $repoRoot "docs\SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md"),
    (Join-Path $repoRoot "sdk\README.md")
)
foreach ($authorityPath in $authorityPaths) {
    $authority = Get-Content -Raw -LiteralPath $authorityPath
    Assert-Exact (
        $authority.Contains("godot_jolt_transport_execution_contract.json") -and
        $authority.Contains($expectedVersion) -and
        $authority.Contains("16,384") -and
        $authority.Contains("run_godot_jolt_transport_benchmark.ps1")
    ) "Repository authority '$authorityPath' no longer identifies the exact GJTP1 route."
}

$contractHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $contractPath).Hash.ToLowerInvariant()
Write-Host (
    "GODOT_JOLT_TRANSPORT_EXECUTION_SOURCE_CONTRACT_PASS " +
    "version=$expectedVersion capacity=16384 normal_calls=1 overflow_retries=1 " +
    "runners=2 negative_canaries=3 worlds=0 physical_authority=False " +
    "contract_sha256=sha256:$contractHash"
)
