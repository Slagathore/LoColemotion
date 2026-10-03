#requires -Version 7.0

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$sdkRoot = Join-Path $repoRoot "sdk"
$contractPath = Join-Path $sdkRoot (
    "turning\r23d12_physical_implementation_contract_v1.json"
)
$preregistrationPath = Join-Path $sdkRoot (
    "turning\r23d12_measurement_semantics_preregistration_v1.json"
)
$dependencyPath = Join-Path $sdkRoot "turning\r23d12_dependency_closure.ps1"
$campaignId = (
    "QSDK-R23D12-INDEPENDENT-PLANNER-AND-SUPPORT-MARGIN-SEMANTICS-" +
    "BILATERAL-TURN-DEVELOPMENT"
)

function Assert-R23D12Implementation {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-R23D12ImplementationRawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return "sha256:" + (
        Get-FileHash -LiteralPath $Path -Algorithm SHA256
    ).Hash.ToLowerInvariant()
}

function Get-R23D12ImplementationSource {
    param([Parameter(Mandatory)][string]$RelativePath)
    $path = Join-Path $repoRoot $RelativePath
    Assert-R23D12Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D12 implementation source is missing: $RelativePath"
    )
    return [IO.File]::ReadAllText($path)
}

function Assert-R23D12ImplementationSourceContains {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Needles
    )
    $source = Get-R23D12ImplementationSource $RelativePath
    foreach ($needle in $Needles) {
        Assert-R23D12Implementation (
            $source.Contains($needle, [StringComparison]::Ordinal)
        ) "QSDK-R23D12 source seam is missing: $RelativePath :: $needle"
    }
}

function Assert-R23D12ImplementationSourceExcludes {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string[]]$Needles
    )
    $source = Get-R23D12ImplementationSource $RelativePath
    foreach ($needle in $Needles) {
        Assert-R23D12Implementation (
            -not $source.Contains($needle, [StringComparison]::Ordinal)
        ) "QSDK-R23D12 forbidden source alias is present: $RelativePath :: $needle"
    }
}

Assert-R23D12Implementation (
    (git -C $repoRoot rev-parse --show-toplevel).Trim().Replace("/", "\") -ceq
        $repoRoot -and
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "QSDK-R23D12 implementation repository identity changed"
foreach ($path in @($contractPath, $preregistrationPath, $dependencyPath)) {
    Assert-R23D12Implementation (Test-Path -LiteralPath $path -PathType Leaf) (
        "QSDK-R23D12 implementation authority is missing: $path"
    )
}

$contract = Get-Content -Raw -LiteralPath $contractPath |
    ConvertFrom-Json -AsHashtable -Depth 100
$preregistration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 100
Assert-R23D12Implementation (
    [string]$contract.schema_version -ceq
        "sporespore_qsdk_r23d12_physical_implementation_contract_v1" -and
    [string]$contract.campaign_id -ceq $campaignId -and
    [string]$contract.gate_id -ceq "QSDK-R23D12" -and
    [string]$contract.release_gate_id -ceq "QSDK-R23" -and
    [string]$contract.preregistration_raw_sha256 -ceq
        (Get-R23D12ImplementationRawSha256 $preregistrationPath) -and
    [string]$contract.inherited_unchanged_policy_id -ceq
        "sporespore_support_centroid_assisted_quiescent_taper_v1" -and
    @($contract.workers).Count -eq 3 -and
    @($contract.workers.engine_id) -join "|" -ceq
        "mujoco|rapier_parry|godot_jolt" -and
    @($contract.workers | Where-Object {
        -not [bool]$_.physical_worker_implemented -or
        [int]$_.physical_world_count_before_freeze -ne 0
    }).Count -eq 0 -and
    [int]$contract.fixed_schedule.turning_controller_step_count -eq 2992 -and
    [int]$contract.fixed_schedule.terminal_quiescent_taper_step_count -eq 900 -and
    [int]$contract.fixed_schedule.total_trace_row_count_per_cell -eq 3892 -and
    [int]$contract.fixed_schedule.maximum_active_neutral_acquisition_step_count -eq 540 -and
    [int]$contract.fixed_schedule.minimum_quiescent_taper_step_count -eq 120 -and
    [int]$contract.fixed_schedule.minimum_post_handoff_zero_actuation_step_count -eq 360 -and
    [int]$contract.fixed_schedule.exact_post_handoff_native_application_count -eq 0 -and
    [bool]$contract.stability_assisted_taper_implementation.transition_applies_to_following_step -and
    [bool]$contract.stability_assisted_taper_implementation.taper_scale_applied_to_canonical_velocity_before_host_mapping_required -and
    [bool]$contract.stability_assisted_taper_implementation.handoff_is_irreversible -and
    -not [bool]$contract.stability_assisted_taper_implementation.post_handoff_reactivation_permitted -and
    -not [bool]$contract.stability_assisted_taper_implementation.post_handoff_native_actuation_permitted -and
    -not [bool]$contract.stability_assisted_taper_implementation.deadline_forced_handoff_can_pass -and
    [int]$contract.stability_assisted_taper_implementation.inherited_temporal_oracle_canary_count_per_worker_route -eq 5 -and
    [int]$contract.stability_assisted_taper_implementation.composition_canary_count_per_native_route -eq 7 -and
    [int]$contract.stability_assisted_taper_implementation.composition_mutation_control_count_per_native_route -eq 18 -and
    [int]$contract.stability_assisted_taper_implementation.godot_jolt_actuation_bridge_canary_count -eq 3 -and
    [int]$contract.stability_assisted_taper_implementation.diagnostic_valid_canary_count_per_native_route -eq 7 -and
    [int]$contract.stability_assisted_taper_implementation.diagnostic_active_cross_product_count_per_native_route -eq 6 -and
    [int]$contract.stability_assisted_taper_implementation.diagnostic_mutation_control_count_per_native_route -eq 14 -and
    [bool]$contract.stability_assisted_taper_implementation.critical_r23d11_failure_shape_accepted_per_native_route -and
    -not [bool]$contract.independent_diagnostic_availability_implementation.physical_result_observed_before_implementation -and
    -not [bool]$contract.independent_diagnostic_availability_implementation.decision_or_acceptance_threshold_changed -and
    [bool]$contract.independent_diagnostic_availability_implementation.planner_and_support_margin_availability_are_independent -and
    [bool]$contract.independent_diagnostic_availability_implementation.observation_unavailable_with_measured_finite_margin_is_valid -and
    [bool]$contract.independent_diagnostic_availability_implementation.passive_support_margin_is_finite_when_qualified_support_exists_otherwise_null -and
    [bool]$contract.production_evaluator.trace_retention_cli_producer_consumer_integration_required -and
    [bool]$contract.production_evaluator.evaluator_success_marker_requires_zero_exit_and_forbids_generic_marker -and
    [bool]$contract.supervisor.evaluator_expected_source_commit_forwarded_from_frozen_source
) "QSDK-R23D12 physical implementation contract changed"
Assert-R23D12Implementation (
    [string]$preregistration.schema_version -ceq
        "sporespore_qsdk_r23d12_measurement_semantics_preregistration_v1" -and
    [string]$preregistration.campaign_id -ceq $campaignId -and
    [int]$preregistration.future_physical_topology_if_all_zero_world_stages_pass.stage_a_declared_world_count -eq 2 -and
    [int]$preregistration.future_physical_topology_if_all_zero_world_stages_pass.stage_b_declared_world_count_if_launched -eq 9 -and
    -not [bool]$preregistration.stage_zero_authority.physical_execution_authorized -and
    -not [bool]$preregistration.claim_boundary.physical_acceptance_authority
) "QSDK-R23D12 preregistration identity changed"

$exactPaths = @($contract.source_binding_policy.exact_paths)
Assert-R23D12Implementation (
    $exactPaths.Count -gt 0 -and
    @($exactPaths | Group-Object -CaseSensitive | Where-Object Count -gt 1).Count -eq 0 -and
    @($exactPaths | Where-Object {
        [IO.Path]::IsPathRooted([string]$_) -or
        ([string]$_).Contains("\") -or
        ([string]$_).Contains("*") -or
        ([string]$_).Contains("?") -or
        -not (Test-Path -LiteralPath (Join-Path $repoRoot ([string]$_)) -PathType Leaf)
    }).Count -eq 0
) "QSDK-R23D12 source-binding policy is not exact and complete"

. $dependencyPath
$manifest = Get-R23D12DependencyManifest -RepoRoot $repoRoot
$pathSet = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($path in $exactPaths) { [void]$pathSet.Add([string]$path) }
Assert-R23D12Implementation (
    [string]$manifest.schema_version -ceq
        "sporespore_qsdk_r23d12_worker_dependency_manifest_v1" -and
    @($manifest.ordered_worker_ids).Count -eq 3 -and
    [int]$manifest.unique_dependency_count -eq 58 -and
    @($manifest.union_paths | Where-Object {
        -not $pathSet.Contains([string]$_)
    }).Count -eq 0
) "QSDK-R23D12 dependency closure changed or escaped the source binding set"

Assert-R23D12ImplementationSourceContains `
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_stability_assisted_taper_physical.py" `
    @(
        "def physical_authorization(",
        "def authorization_preflight(",
        "def run_physical(",
        "MujocoBw19vRobot(",
        "evaluator.retain_trace("
        "diagnostics.validate_diagnostic_semantics("
        '"minimum_dynamic_support_margin_availability"'
    )
$mujocoSource = Get-R23D12ImplementationSource (
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_stability_assisted_taper_physical.py"
)
Assert-R23D12Implementation (
    $mujocoSource.IndexOf("physical_authorization(cell, source_commit)") -lt
        $mujocoSource.IndexOf("MujocoBw19vRobot(")
) "QSDK-R23D12 MuJoCo model construction precedes authorization"
Assert-R23D12ImplementationSourceExcludes `
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_stability_assisted_taper_physical.py" `
    @(
        '"terminal_stability_assisted_taper_step_count"',
        '"stability_assisted_taper_gate_passed"'
    )

Assert-R23D12ImplementationSourceContains `
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_physical.rs" `
    @(
        "fn r23d12_physical_authorization(",
        "run_qsdk_r23d12_rapier_authorization_preflight_impl(",
        "run_qsdk_r23d12_rapier_physical_impl(",
        "QSDK_R23D12_RAP_PHYSICAL_AUTHORIZATION_REQUIRED",
        'R23D12_TRACE_RETENTION_MARKER: &str = "QSDK_R23D12_TRACE_RETENTION "'
        '"minimum_dynamic_support_margin_availability"'
    )
$rapierFixtureSource = Get-R23D12ImplementationSource (
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_physical.rs"
)
$rapierR23D12Start = $rapierFixtureSource.IndexOf(
    "const R23D12_PREREGISTRATION_RAW",
    [StringComparison]::Ordinal
)
Assert-R23D12Implementation ($rapierR23D12Start -ge 0) (
    "QSDK-R23D12 Rapier production section is missing"
)
$rapierR23D12Source = $rapierFixtureSource.Substring($rapierR23D12Start)
Assert-R23D12Implementation (
    $rapierR23D12Source.Contains(
        "let prefix = R23D12_TRACE_RETENTION_MARKER;",
        [StringComparison]::Ordinal
    ) -and
    -not $rapierR23D12Source.Contains(
        'QSDK_R23D12_EVALUATION ',
        [StringComparison]::Ordinal
    )
) "QSDK-R23D12 Rapier trace-retention consumer marker drifted"
Assert-R23D12ImplementationSourceContains `
    "sdk/adapters/rapier/src/qsdk_r23d12_measurement_semantics.rs" `
    @(
        "run_qsdk_r23d12_rapier_authorization_preflight(",
        "run_qsdk_r23d12_rapier_physical("
    )

Assert-R23D12ImplementationSourceContains `
    "tests/test_sdk_qsdk_r23d12_stability_assisted_taper_godot_jolt_physical_worker.gd" `
    @(
        "func _r12_run_physical(",
        "_r12_physical_authorization(cell, source_commit)",
        "_r12_retain_trace(",
        'var marker := "QSDK_R23D12_TRACE_RETENTION "',
        "_r12_source_bindings_exact(",
        "production_trace_constructor_canary_count"
        '"minimum_dynamic_support_margin_availability"'
    )
$godotSource = Get-R23D12ImplementationSource (
    "tests/test_sdk_qsdk_r23d12_stability_assisted_taper_godot_jolt_physical_worker.gd"
)
Assert-R23D12Implementation (
    $godotSource.IndexOf("_r12_physical_authorization(cell, source_commit)") -lt
        $godotSource.IndexOf("var summary: Dictionary = await _r8_run_wave(prepared, false)")
) "QSDK-R23D12 Godot/Jolt world route precedes authorization"

$physicalWorkerPaths = @(
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d12_stability_assisted_taper_physical.py",
    "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d12_physical.rs",
    "tests/test_sdk_qsdk_r23d12_stability_assisted_taper_godot_jolt_physical_worker.gd"
)
foreach ($path in $physicalWorkerPaths) {
    Assert-R23D12ImplementationSourceContains $path @(
        '"terminal_quiescent_taper_step_count"',
        '"quiescent_taper_step_count"',
        '"quiescent_taper_gate_passed"'
    )
}

Assert-R23D12ImplementationSourceContains "sdk/run_qsdk_r23d12_supervisor.ps1" @(
    '$stageAId = "mujoco_stability_assisted_taper_screen"',
    '"mujoco__stability_assisted_taper__$armId"',
    '"$engineId`__stability_assisted_taper__$armId"',
    '"physical",',
    '"sporespore_mujoco_adapter.qsdk_r23d12_stability_assisted_taper_physical"',
    'Get-R23D12TerminalMarkerClassification',
    'Publish-SporeSporeContentAddressedArtifact',
    '"--expected-source-commit", $ExpectedSourceCommit',
    '-ExpectedSourceCommit ([string]$Source.commit)',
    'evaluator exited nonzero after retention',
    'evaluator emitted the forbidden generic marker',
    'stage_a_reports_may_substitute_for_stage_b = $false'
)

$receipt = [ordered]@{
    schema_version = "sporespore_qsdk_r23d12_physical_implementation_audit_v1"
    campaign_id = $campaignId
    gate_id = "QSDK-R23D12"
    implementation_contract_raw_sha256 = Get-R23D12ImplementationRawSha256 $contractPath
    worker_implementation_count = 3
    native_diagnostic_route_count = 3
    complete_trace_retention_path_count = 3
    declared_worker_dependency_count = 58
    single_supervisor_count = 1
    physical_process_launch_count = 0
    model_construction_count = 0
    world_attempt_count = 0
    world_build_count = 0
    physical_execution_authorized = $false
    physical_acceptance_authority = $false
}
Write-Host (
    "QSDK_R23D12_IMPLEMENTATION_AUDIT " +
    ($receipt | ConvertTo-Json -Depth 40 -Compress)
)
Write-Host (
    "QSDK_R23D12_IMPLEMENTATION_PASS workers=3 native_diagnostic_routes=3 " +
    "trace_retention_paths=3 dependencies=58 supervisor=1 models=0 worlds=0 " +
    "physical_authority=False"
)
