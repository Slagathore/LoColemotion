#requires -Version 7.0

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$PSNativeCommandUseErrorActionPreference = $false

function Assert-Exact {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Assert-Close {
    param(
        [double]$Actual,
        [double]$Expected,
        [double]$Tolerance,
        [string]$Message
    )
    Assert-Exact (
        [double]::IsFinite($Actual) -and
        [math]::Abs($Actual - $Expected) -le $Tolerance
    ) $Message
}

function Get-RawSha256 {
    param([Parameter(Mandatory)][string]$Path)
    return (
        Get-FileHash -Algorithm SHA256 -LiteralPath $Path
    ).Hash.ToLowerInvariant()
}

function Assert-DeclaredRepoFile {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$ExpectedRawSha256,
        [Parameter(Mandatory)][string]$RepoRoot
    )
    $path = [IO.Path]::GetFullPath((Join-Path $RepoRoot $RelativePath))
    $prefix = $RepoRoot.TrimEnd('\', '/') +
        [IO.Path]::DirectorySeparatorChar
    Assert-Exact (
        $path.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase) -and
        (Test-Path -LiteralPath $path -PathType Leaf) -and
        (Get-RawSha256 -Path $path) -ceq
            $ExpectedRawSha256.Replace("sha256:", "")
    ) "C6-MJC-HC-VH3 declared source changed: $RelativePath"
}

$repoRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$sdkRoot = Join-Path $repoRoot "sdk"
$mujocoRoot = Join-Path $sdkRoot "adapters\mujoco"
$python = Join-Path $mujocoRoot ".venv\Scripts\python.exe"
$preregistrationPath = Join-Path $sdkRoot (
    "mujoco_c6_velocity_only_stability_host_characterization_" +
    "vh3_preregistration.json"
)
$implementationPath = Join-Path $mujocoRoot (
    "sporespore_mujoco_adapter\" +
    "velocity_only_stability_characterization_vh3.py"
)
$runnerPath = Join-Path $sdkRoot (
    "run_mujoco_c6_velocity_only_stability_host_characterization_vh3.ps1"
)
$closurePath = Join-Path $sdkRoot (
    "mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json"
)
$evidenceRoot = [IO.Path]::GetFullPath(
    (Join-Path (Split-Path -Parent $repoRoot) "SporeSpore_Evidence")
)
$expectedPreregistrationSha256 = (
    "cfdacfb19d03f52250ab9d4a001566f51a9d435c76715489e1b51b1386b985fe"
)
$expectedImplementationSha256 = (
    "93b993e2af075c0b667d0e7cad9f7b5d6089ed2c8296133afcd70b23342f924b"
)
$expectedRunnerSha256 = (
    "2d16ad9afcfd76a97f2fbbb843953775320498d9f4f8ccc6780bc30c69237411"
)
$expectedBaseIds = @(
    "unloaded_vn075",
    "unloaded_vp075",
    "unloaded_vn225",
    "unloaded_vp225",
    "loaded_vn150_tn075",
    "loaded_vn150_tp075",
    "loaded_vn150_tn225",
    "loaded_vn150_tp225",
    "loaded_vp150_tn075",
    "loaded_vp150_tp075",
    "loaded_vp150_tn225",
    "loaded_vp150_tp225"
)
$expectedCanaries = @(
    "missing_cell",
    "wrong_substep_count",
    "wrong_initial_velocity",
    "wrong_initial_velocity_numeric_readback",
    "unsafe_declared_saturated_band_crossing_ratio",
    "wrong_generalized_inertia_readback",
    "missing_trace",
    "wrong_trace_cardinality",
    "wrong_velocity_response",
    "wrong_loaded_force_response",
    "missing_transient_saturation",
    "missing_saturation_recovery",
    "forged_recovery_streak_over_failing_trace",
    "coherent_anchor_limit_violation",
    "force_mapping_mismatch",
    "impulse_limit",
    "world_count_inflation",
    "physical_authority_inflation"
)

Assert-Exact (
    (git -C $repoRoot rev-parse --show-toplevel).Trim() -ceq
        $repoRoot.Replace("\", "/")
) "C6-MJC-HC-VH3 freeze audit ran outside SporeSpore"
Assert-Exact (
    (git -C $repoRoot remote get-url origin).Trim() -ceq
        "https://github.com/Slagathore/sporespore.git"
) "C6-MJC-HC-VH3 freeze audit origin mismatch"
foreach ($path in @(
    $python,
    $preregistrationPath,
    $implementationPath,
    $runnerPath
)) {
    Assert-Exact (
        Test-Path -LiteralPath $path -PathType Leaf
    ) "C6-MJC-HC-VH3 freeze source missing: $path"
}
Assert-Exact (
    -not (Test-Path -LiteralPath $closurePath -PathType Leaf)
) "C6-MJC-HC-VH3 prospective freeze cannot coexist with a closure"

$beforeEvidence = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh3-*" `
        -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
)
Assert-Exact (
    $beforeEvidence.Count -eq 0
) "C6-MJC-HC-VH3 evidence exists; use a closure audit, not this freeze audit"
Assert-Exact (
    (Get-RawSha256 -Path $preregistrationPath) -ceq
        $expectedPreregistrationSha256 -and
    (Get-RawSha256 -Path $implementationPath) -ceq
        $expectedImplementationSha256 -and
    (Get-RawSha256 -Path $runnerPath) -ceq $expectedRunnerSha256
) "C6-MJC-HC-VH3 frozen source bytes changed"

$declaration = Get-Content -Raw -LiteralPath $preregistrationPath |
    ConvertFrom-Json -AsHashtable -Depth 64
Assert-Exact (
    [string]$declaration.schema_version -ceq
        "sporespore_mujoco_c6_velocity_only_stability_host_characterization_vh3_preregistration_v1" -and
    [string]$declaration.campaign_id -ceq
        "C6-MUJOCO-VELOCITY-ONLY-STABILITY-HOST-CHARACTERIZATION-VH3" -and
    [string]$declaration.gate_id -ceq "C6-MJC-HC-VH3" -and
    [string]$declaration.status -ceq
        "frozen_before_first_c6_mjc_hc_vh3_physics_world" -and
    [string]$declaration.implementation_parent_commit -ceq
        "81c30f3e7461a58e3c695104b2c5402b264be94c" -and
    [string]$declaration.study_class -ceq
        "exact_finite_initial_condition_and_load_stability_characterization" -and
    [bool]$declaration.estimand.all_cells_required -and
    -not [bool]$declaration.estimand.population_inference -and
    -not [bool]$declaration.estimand.selector_present -and
    [bool]$declaration.scientifically_distinct_successor.
        vh1_remains_closed_complete_valid_negative -and
    [bool]$declaration.scientifically_distinct_successor.
        no_vh1_threshold_result_or_cell_reinterpreted -and
    [bool]$declaration.scientifically_distinct_successor.
        vh2_remains_closed_consumed_implementation_invalid -and
    [bool]$declaration.scientifically_distinct_successor.
        vh2_produced_no_scientific_result_to_reinterpret -and
    [bool]$declaration.scientifically_distinct_successor.
        vh2_process_identity_not_reused
) "C6-MJC-HC-VH3 identity or immutable VH1 boundary changed"

$hostIdentity = $declaration.host_identity
$fixture = $declaration.fixture
$grid = $declaration.physical_grid
$cellGate = $declaration.cell_gate
$preflightContract = $declaration.preflight_contract
Assert-Exact (
    [string]$hostIdentity.engine -ceq "MuJoCo" -and
    [string]$hostIdentity.engine_version -ceq "3.11.0" -and
    [string]$hostIdentity.python_version -ceq "3.11.9" -and
    [string]$hostIdentity.numpy_version -ceq "2.4.6" -and
    [double]$hostIdentity.portable_controller_timestep_s -eq (1.0 / 120.0) -and
    [double]$hostIdentity.internal_physics_timestep_s -eq (1.0 / 600.0) -and
    [int]$hostIdentity.internal_physics_steps_per_controller_step -eq 5 -and
    [string]$hostIdentity.integrator -ceq "implicitfast" -and
    [string]$hostIdentity.solver -ceq "Newton" -and
    [int]$hostIdentity.solver_iterations -eq 20 -and
    [int]$hostIdentity.line_search_iterations -eq 7 -and
    [double]$fixture.joint_armature -eq 0.01 -and
    [bool]$fixture.physical_generalized_inertia_readback_required -and
    [double]$fixture.maximum_generalized_inertia_readback_error_kg_m2 -eq
        1.0e-12 -and
    [string]$declaration.host_source_semantics.
        python_generalized_inertia_field -ceq "M" -and
    [string]$declaration.host_source_semantics.
        python_forbidden_generalized_inertia_field -ceq "qM" -and
    [string]$declaration.host_source_semantics.python_mj_fullM_signature -ceq (
        "mj_fullM(m: mujoco._structs.MjModel, d: mujoco._structs.MjData, " +
        "dst: typing.Annotated[numpy.typing.NDArray[numpy.float64], " +
        '"[m, n]", "flags.writeable", "flags.c_contiguous"]) -> None'
    ) -and
    -not [bool]$fixture.contacts_enabled
) "C6-MJC-HC-VH3 host or generalized-inertia fixture changed"
Assert-Close `
    -Actual ([double]$fixture.analytic_effective_joint_inertia_kg_m2) `
    -Expected (1.0 / 60.0) `
    -Tolerance 1.0e-15 `
    -Message "C6-MJC-HC-VH3 analytic effective inertia changed"

Assert-Exact (
    [int]$grid.worlds -eq 24 -and
    [int]$grid.replacement_worlds -eq 0 -and
    [int]$grid.outer_controller_steps_per_cell -eq 360 -and
    [int]$grid.internal_physics_steps_per_outer_step -eq 5 -and
    [int]$grid.internal_trace_records_per_cell -eq 1800 -and
    [int]$grid.aggregate_internal_trace_records -eq 43200 -and
    ([string[]]@($grid.internal_trace_row_schema) -join "|") -ceq (
        "global_internal_index|outer_index|substep_index|time_s|" +
        "joint_position_rad|joint_velocity_rad_s|actuator_force_nm|" +
        "generalized_actuator_torque_nm|external_applied_torque_nm|" +
        "generalized_inertia_kg_m2|" +
        "joint_anchor_world_position_residual_m"
    ) -and
    [int]$grid.first_acceptable_outer_step -eq 120 -and
    [int]$grid.required_consecutive_acceptable_outer_steps -eq 120 -and
    [bool]$grid.early_stop_forbidden -and
    ([string[]]@($grid.base_target_load_cells | ForEach-Object {
        [string]$_.base_id
    }) -join "|") -ceq ($expectedBaseIds -join "|") -and
    ([string[]]@($grid.initial_condition_profiles | ForEach-Object {
        [string]$_.profile_id
    }) -join "|") -ceq "zero|adverse"
) "C6-MJC-HC-VH3 finite grid, trace, or initial-condition order changed"
Assert-Exact (
    [bool]$cellGate.
        numeric_initial_joint_velocity_readback_must_equal_declared_initial_condition -and
    [bool]$cellGate.
        production_evaluator_must_reconstruct_all_terminal_responses_recovery_streaks_threshold_maxima_and_violation_counts_from_the_internal_trace
) "C6-MJC-HC-VH3 trace-derived production evaluator contract changed"
Assert-Exact (
    [bool]$preflightContract.must_run_before_any_physics_world -and
    [bool]$preflightContract.must_verify_python_binding_surface_before_any_world -and
    [bool]$preflightContract.must_use_production_report_evaluator -and
    [bool]$preflightContract.perfect_synthetic_serialized_result_must_pass -and
    [int]$preflightContract.negative_control_count -eq 18 -and
    [int]$preflightContract.binding_surface_canary_count -eq 3 -and
    @($preflightContract.binding_surface_canaries).Count -eq 3 -and
    ([string[]]@($preflightContract.negative_controls) -join "|") -ceq
        ($expectedCanaries -join "|") -and
    [int]$preflightContract.world_build_count -eq 0 -and
    -not [bool]$preflightContract.physics_state_modified -and
    -not [bool]$preflightContract.physical_acceptance_authority
) "C6-MJC-HC-VH3 zero-world whole-gate preflight contract changed"

$mechanism = $declaration.stability_mechanism
Assert-Close `
    -Actual ([double]$mechanism.vh1_exact_fixture_saturated_band_crossing_ratio) `
    -Expected 5.0 `
    -Tolerance 1.0e-14 `
    -Message "C6-MJC-HC-VH3 VH1 mechanism witness changed"
Assert-Close `
    -Actual ([double]$mechanism.vh3_exact_fixture_saturated_band_crossing_ratio) `
    -Expected 1.0 `
    -Tolerance 1.0e-14 `
    -Message "C6-MJC-HC-VH3 exact-fixture ratio changed"
Assert-Close `
    -Actual ([double]$mechanism.vh3_armature_only_upper_saturated_band_crossing_ratio) `
    -Expected (5.0 / 3.0) `
    -Tolerance 1.0e-14 `
    -Message "C6-MJC-HC-VH3 armature-only upper ratio changed"
Assert-Exact (
    [double]$mechanism.strict_single_saturated_step_no_full_linear_band_skip_upper_bound -eq 2.0 -and
    [bool]$mechanism.exact_fixture_and_armature_only_crossing_ratios_must_be_below_bound -and
    [bool]$mechanism.calculation_must_pass_in_zero_world_preflight -and
    [bool]$mechanism.physical_generalized_inertia_must_match_the_declared_analytic_fixture -and
    [bool]$mechanism.physical_result_must_retain_internal_step_traces
) "C6-MJC-HC-VH3 stability mechanism boundary changed"

Assert-Exact (
    [bool]$declaration.claim_boundary.
        exact_finite_mujoco_velocity_only_stability_host_characterization_if_passed -and
    [bool]$declaration.claim_boundary.
        exact_finite_transient_force_saturation_recovery_if_passed -and
    -not [bool]$declaration.claim_boundary.
        continuous_gain_inertia_timestep_velocity_or_load_domain -and
    -not [bool]$declaration.claim_boundary.mujoco_selected_policy_locomotion -and
    -not [bool]$declaration.claim_boundary.mujoco_walking -and
    -not [bool]$declaration.claim_boundary.cross_engine_equivalence -and
    -not [bool]$declaration.claim_boundary.release_authority -and
    -not [bool]$declaration.claim_boundary.physical_acceptance_authority
) "C6-MJC-HC-VH3 finite conditional claim boundary changed"

foreach ($source in @(
    @{
        path = [string]$declaration.semantic_parent.profile_path
        hash = [string]$declaration.semantic_parent.profile_raw_sha256
    },
    @{
        path = [string]$declaration.semantic_parent.semantics_path
        hash = [string]$declaration.semantic_parent.semantics_raw_sha256
    },
    @{
        path = [string]$declaration.semantic_parent.canonical_implementation_path
        hash = [string]$declaration.semantic_parent.canonical_implementation_raw_sha256
    },
    @{
        path = [string]$declaration.semantic_parent.rapier_velocity_only_closure_path
        hash = [string]$declaration.semantic_parent.rapier_velocity_only_closure_raw_sha256
    },
    @{
        path = [string]$declaration.scientifically_distinct_successor.vh1_closure_path
        hash = [string]$declaration.scientifically_distinct_successor.vh1_closure_raw_sha256
    },
    @{
        path = [string]$declaration.scientifically_distinct_successor.vh2_closure_path
        hash = [string]$declaration.scientifically_distinct_successor.vh2_closure_raw_sha256
    },
    @{
        path = [string]$declaration.host_source_semantics.requirements_lock_path
        hash = [string]$declaration.host_source_semantics.requirements_lock_windows_checkout_raw_sha256
    }
)) {
    Assert-DeclaredRepoFile `
        -RelativePath ([string]$source.path) `
        -ExpectedRawSha256 ([string]$source.hash) `
        -RepoRoot $repoRoot
}
Assert-Exact (
    @($declaration.host_source_semantics.installed_wheel_files).Count -eq 9
) "C6-MJC-HC-VH3 installed-runtime source inventory changed"

$implementation = Get-Content -Raw -LiteralPath $implementationPath
$preflightMatch = [regex]::Match(
    $implementation,
    '(?s)def run_stability_host_preflight\(\).*?(?=\ndef _option_xml\()'
)
Assert-Exact (
    $preflightMatch.Success -and
    $preflightMatch.Value -notmatch 'MjModel|from_xml|(?<![A-Za-z0-9_])_model\('
) "C6-MJC-HC-VH3 preflight acquired a physics-world constructor"
foreach ($witness in @(
    'TRACE_WIDTH = 11',
    'evaluate_stability_host_report(perfect)',
    'evaluate_stability_host_report(json.loads(serialized))',
    'json.dumps(perfect, allow_nan=False',
    'len(canaries) == 18 and all(canaries.values())',
    'mujoco.MjModel.from_xml_string(xml)',
    '<velocity name="motor" joint="hinge" gear="1 0 0 0 0 0"',
    '"mjdata_has_M": hasattr(mujoco.MjData, "M")',
    '"mjdata_has_qM": hasattr(mujoco.MjData, "qM")',
    'mujoco.mj_fullM(model, data, dense)',
    'np.asarray(data.M).shape == (1,)',
    'generalized_inertia_readback = _generalized_inertia_readback(model, data)',
    'initial_velocity_readback = float(data.qvel[dof_address])',
    '"initial_joint_velocity_readback_rad_s": initial_velocity_readback',
    'maximum_anchor = max(maximum_anchor, anchor)',
    'cell.get("first_acceptable_outer_step") != first_acceptable',
    'maximum_anchor > ANCHOR_TOLERANCE_M',
    'reconstructed_counts = {',
    'observation = mujoco.MjData(model)',
    'mujoco.mj_forward(model, observation)',
    'for substep in range(INTERNAL_STEPS_PER_OUTER)',
    'mujoco.mj_step(model, data)',
    '"internal_step_trace": trace',
    '"generalized_inertia_readback_mismatch_count"'
)) {
    Assert-Exact (
        $implementation.Contains($witness)
    ) "C6-MJC-HC-VH3 implementation witness missing: $witness"
}

Push-Location -LiteralPath $mujocoRoot
try {
    $directLines = @(
        & $python `
            -m sporespore_mujoco_adapter.velocity_only_stability_characterization_vh3 `
            --preflight-only
    )
    Assert-Exact ($LASTEXITCODE -eq 0) (
        "C6-MJC-HC-VH3 direct zero-world preflight failed"
    )
    $modelTrap = @(
        & $python -c (
            "import json; import sporespore_mujoco_adapter." +
            "velocity_only_stability_characterization_vh3 as m; " +
            "m._model=lambda: (_ for _ in ()).throw(" +
            "RuntimeError('MODEL_CONSTRUCTOR_CALLED')); " +
            "print(json.dumps(m.run_stability_host_preflight()," +
            "separators=(',',':')))"
        )
    )
    Assert-Exact ($LASTEXITCODE -eq 0) (
        "C6-MJC-HC-VH3 model-constructor trap preflight failed"
    )
} finally {
    Pop-Location
}

$direct = ($directLines -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable -Depth 64
$trapped = ($modelTrap -join [Environment]::NewLine) |
    ConvertFrom-Json -AsHashtable -Depth 64
foreach ($receipt in @($direct, $trapped)) {
    Assert-Exact (
        [bool]$receipt.ok -and
        [bool]$receipt.perfect_synthetic_result_passed -and
        [bool]$receipt.perfect_synthetic_serialization_round_trip_passed -and
        [int]$receipt.declared_cell_count -eq 24 -and
        [int]$receipt.declared_internal_trace_record_count -eq 43200 -and
        [int]$receipt.negative_control_count -eq 18 -and
        @($receipt.negative_controls_rejected.Values | Where-Object {
            -not [bool]$_
        }).Count -eq 0 -and
        [int]$receipt.binding_surface_canary_count -eq 3 -and
        @($receipt.binding_surface_canaries_passed.Values | Where-Object {
            -not [bool]$_
        }).Count -eq 0 -and
        [bool]$receipt.host_identity.binding_surface.mjdata_has_M -and
        -not [bool]$receipt.host_identity.binding_surface.mjdata_has_qM -and
        [int]$receipt.host_identity.verified_wheel_file_count -eq 9 -and
        [int]$receipt.host_identity.world_build_count -eq 0 -and
        [int]$receipt.world_build_count -eq 0 -and
        -not [bool]$receipt.physics_state_modified -and
        -not [bool]$receipt.physical_acceptance_authority
    ) "C6-MJC-HC-VH3 zero-world receipt is incomplete or inflated"
}
Assert-Close `
    -Actual ([double]$direct.stability_mechanism.vh3_exact_fixture_saturated_band_crossing_ratio) `
    -Expected 1.0 `
    -Tolerance 1.0e-14 `
    -Message "C6-MJC-HC-VH3 preflight exact-fixture ratio changed"
Assert-Exact (
    [double]$direct.stability_mechanism.
        vh3_armature_only_saturated_band_crossing_ratio -lt 2.0
) "C6-MJC-HC-VH3 preflight armature-only bound failed"

$runner = Get-Content -Raw -LiteralPath $runnerPath
foreach ($guard in @(
    'Specify exactly one of -PreflightOnly or -RunPhysical',
    'prior evidence exists; same-identity rerun is forbidden',
    'Enter-SporeSporeLocomotionOperationLock -Role physical',
    'exact full-Godot V2 attestation',
    'physical execution requires distinct clean HEAD == origin/main == live GitHub main',
    '[IO.FileMode]::CreateNew',
    'physical_process_launch_consumes_identity = $true',
    'source changed after attempt reservation; physical launch refused',
    'Start-Process',
    '-WindowStyle Hidden',
    'process exited without retaining report.json',
    'audit the closure instead'
)) {
    Assert-Exact (
        $runner.Contains($guard)
    ) "C6-MJC-HC-VH3 runner guard missing: $guard"
}

& $runnerPath -PreflightOnly
Assert-Exact (
    $LASTEXITCODE -eq 0
) "C6-MJC-HC-VH3 supervised zero-world preflight failed"

$afterEvidence = @(
    Get-ChildItem -LiteralPath $evidenceRoot -Directory `
        -Filter "c6-mujoco-velocity-only-stability-vh3-*" `
        -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
)
Assert-Exact (
    ($afterEvidence -join "|") -ceq ($beforeEvidence -join "|")
) "C6-MJC-HC-VH3 freeze audit created physical evidence"

Write-Host (
    "C6_MJC_HC_VH3_FREEZE_PASS cells=24 traces=43200 canaries=18 " +
    "binding_canaries=3 stability=5->1 armature_upper=1.666667 worlds=0 " +
    "physical_authority=False"
)
