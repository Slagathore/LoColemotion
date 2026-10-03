#!/usr/bin/env python3
"""Materialize the narrow R23D76 native campaign bindings.

The clean-pushed R23D76 declaration commit is the exact source parent.  This
tool projects the already executed R23D74 production workers to the fresh
R23D76 identity and seed, then binds the R23D75-closed engine-aware startup
evaluator.  It imports no physics library and opens no model or world.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "c9104b1e83d415a4bc140e0355b4dce01d8f586d"


class MaterializationError(RuntimeError):
    """The exact R23D76 source projection could not be composed."""


def _source(relative: str) -> str:
    process = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_COMMIT}:{relative}"],
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        raise MaterializationError(
            f"R23D76_SOURCE_UNREADABLE:{relative}:"
            + process.stderr.decode(errors="replace")
        )
    return process.stdout.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D76_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:160]!r}"
        )
    return text.replace(old, new)


def _section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(f"R23D76_SECTION_START_INVALID:{start!r}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(f"R23D76_SECTION_END_INVALID:{end!r}")
    return text[start_index:end_index]


def _identity(text: str) -> str:
    replacements = (
        ("R23D74", "R23D76"),
        ("r23d74", "r23d76"),
        ("23_193", "23_197"),
        ("23193", "23197"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _fixture(text: str) -> str:
    replacements = (
        ("0.00004413922579260543", "0.0008048271993175149"),
        ("-0.003177209757268429", "0.006968908477574587"),
        ("-0.0031423636246472597", "0.0011139935813844204"),
        ("0.0016733058728277683", "0.0009957263246178627"),
        ("0.0016716052778065205", "0.001996839651837945"),
        ("-0.0006206459365785122", "0.0015670480206608772"),
        ("0.0009215378668159246", "0.0010064903181046247"),
        ("0.000_044_139_225_792_605_43", "0.000_804_827_199_317_514_9"),
        ("-0.003_177_209_757_268_429", "0.006_968_908_477_574_587"),
        ("-0.003_142_363_624_647_259_7", "0.001_113_993_581_384_420_4"),
        ("0.001_673_305_872_827_768_3", "0.000_995_726_324_617_862_7"),
        ("0.001_671_605_277_806_520_5", "0.001_996_839_651_837_945"),
        ("-0.000_620_645_936_578_512_2", "0.001_567_048_020_660_877_2"),
        ("0.000_921_537_866_815_924_6", "0.001_006_490_318_104_624_7"),
        ('"gait_phase_offset_ticks": 0', '"gait_phase_offset_ticks": -3'),
        ("gait_phase_offset_ticks: 0", "gait_phase_offset_ticks: -3"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _common(relative: str) -> str:
    return _fixture(_identity(_source(relative)))


def _rustfmt(text: str) -> str:
    process = subprocess.run(
        ["rustfmt", "--edition", "2024", "--emit", "stdout"],
        input=text,
        capture_output=True,
        check=False,
        encoding="utf-8",
    )
    if process.returncode != 0:
        raise MaterializationError("R23D76_RUSTFMT_FAILED:" + process.stderr.strip())
    return process.stdout.replace("\r\n", "\n")


def _runtime() -> str:
    text = _common("sdk/turning/r23d74_production_route_runtime.py")
    text = _replace_exact(
        text,
        '''MUJOCO_STARTUP_RAMP_ID = "canonical_velocity_smoothstep_one_gait_cycle_v1"
MUJOCO_STARTUP_RAMP_STEP_COUNT = 360
''',
        '''NATIVE_STARTUP_BINDING_CONTRACT_ID = (
    "QSDK-R23D75-NATIVE-STARTUP-TRACE-EVALUATOR-CONFORMANCE-DEVELOPMENT"
)
SUPPORT_LOSS_STARTUP_ID = "support_loss_latched_smoothstep_one_cycle_v1"
MUJOCO_STARTUP_RAMP_ID = "canonical_velocity_smoothstep_one_gait_cycle_v1"
MUJOCO_STARTUP_RAMP_STEP_COUNT = 360
STARTUP_TRANSFORM_BY_ENGINE = {
    "godot_jolt": SUPPORT_LOSS_STARTUP_ID,
    "rapier_parry": SUPPORT_LOSS_STARTUP_ID,
    "mujoco": MUJOCO_STARTUP_RAMP_ID,
}
''',
    )
    text = _replace_exact(text, 'selection.get("first_candidate")', 'selection.get("first_fresh_candidate")')
    text = _replace_exact(
        text,
        'selection.get("first_candidate_token_occurrence_count_at_declaration_parent")',
        'selection.get("first_fresh_candidate_token_occurrence_count_at_declaration_parent")',
    )
    text = _replace_exact(
        text,
        '''            "mujoco_startup_ramp_id": MUJOCO_STARTUP_RAMP_ID,
            "mujoco_startup_ramp_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
''',
        '''            "native_startup_binding_contract_id": NATIVE_STARTUP_BINDING_CONTRACT_ID,
            "startup_transform_by_engine": STARTUP_TRANSFORM_BY_ENGINE,
            "startup_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
''',
    )
    text = _replace_exact(
        text,
        '''        and change.get("prospective_evidence_window_origin_opt_in") is True
        and change.get("mujoco_unconditional_one_cycle_startup_ramp") is True
''',
        '''        and change.get("engine_aware_native_startup_evaluator_binding") is True
''',
    )
    text = _replace_exact(
        text,
        '''        "engine_or_arm_population_changed",
        "historical_campaign_changed",
''',
        '''        "engine_or_arm_population_changed",
        "native_startup_policy_changed",
        "historical_campaign_changed",
''',
    )
    text = _replace_exact(
        text,
        '''        "r23d71_closure_replay_required",
        "three_engine_execution_route_closure_replay_required",
        "measurement_origin_parity_replay_required",
        "r23d73_closure_replay_required",
''',
        '''        "r23d74_closure_replay_required",
        "r23d75_conformance_closure_replay_required",
''',
    )
    text = _replace_exact(
        text,
        '''    authorization = value.get("physical_authorization", {})
    claims = value.get("claims", {})
''',
        '''    smoke = value.get("post_zero_world_native_smoke", {})
    _require(
        smoke.get("required_before_qualification") is True
        and smoke.get("engine_count") == 3
        and smoke.get("maximum_world_count") == 3
        and smoke.get("maximum_solver_step_count_per_world") == 2
        and smoke.get("uses_held_out_seed_23197") is False
        and smoke.get("behavior_thresholds_applied") is False
        and smoke.get("behavioral_success_prediction_allowed") is False
        and smoke.get("finite_evidence") is False
        and smoke.get("physical_acceptance_authority") is False,
        "BOUNDED_NATIVE_SMOKE_INVALID",
    )

    authorization = value.get("physical_authorization", {})
    claims = value.get("claims", {})
''',
    )
    text = _replace_exact(
        text,
        '''        and claims.get("zero_world_gate_passed") is False
        and claims.get("physical_campaign_opened") is False
''',
        '''        and claims.get("zero_world_gate_passed") is False
        and claims.get("native_smoke_passed") is False
        and claims.get("physical_campaign_opened") is False
''',
    )
    text = _replace_exact(
        text,
        '''        and schedule["mujoco_startup_ramp_id"] == MUJOCO_STARTUP_RAMP_ID
        and schedule["mujoco_startup_ramp_step_count"]
        == MUJOCO_STARTUP_RAMP_STEP_COUNT
''',
        '''        and schedule["native_startup_binding_contract_id"]
        == NATIVE_STARTUP_BINDING_CONTRACT_ID
        and schedule["startup_transform_by_engine"] == STARTUP_TRANSFORM_BY_ENGINE
        and schedule["startup_step_count"] == MUJOCO_STARTUP_RAMP_STEP_COUNT
''',
    )
    text = _replace_exact(
        text,
        '''        "mujoco_startup_ramp_id": MUJOCO_STARTUP_RAMP_ID,
        "mujoco_startup_ramp_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
''',
        '''        "native_startup_binding_contract_id": NATIVE_STARTUP_BINDING_CONTRACT_ID,
        "startup_transform_by_engine": copy.deepcopy(STARTUP_TRANSFORM_BY_ENGINE),
        "startup_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
''',
    )
    return text


def _evaluator() -> str:
    text = _common(
        "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py"
    )
    text = _replace_exact(
        text,
        "from typing import Any, Mapping, Sequence\n",
        "from threading import RLock\nfrom typing import Any, Mapping, Sequence\n",
    )
    text = _replace_exact(
        text,
        "import r23d76_production_route_runtime as design\n",
        '''import r23d75_native_startup_trace_evaluator_conformance as startup_binding
import r23d76_production_route_runtime as design
''',
    )
    text = _replace_exact(
        text,
        "EvaluationError = inherited.R23D65EvaluationError\n",
        '''EvaluationError = inherited.R23D65EvaluationError
_R23D76_CELL_BY_ID = design.cell_by_id
_R23D76_EXPECTED_SEGMENT_COUNTS = design.expected_segment_counts
''',
    )
    text = _replace_exact(
        text,
        '''    design.validate_runtime_projection()
    inherited.design = design
''',
        '''    design.cell_by_id = _R23D76_CELL_BY_ID
    design.expected_segment_counts = _R23D76_EXPECTED_SEGMENT_COUNTS
    design.STARTUP_TRANSFORM_ID = design.SUPPORT_LOSS_STARTUP_ID
    design.validate_runtime_projection()
    inherited.design = design
''',
    )
    text = _replace_exact(
        text,
        '''    inherited.FALSE_CLAIMS = copy.deepcopy(FALSE_CLAIMS)
    inherited.load_declaration = design.load_declaration
''',
        '''    inherited.FALSE_CLAIMS = copy.deepcopy(FALSE_CLAIMS)
    inherited.load_declaration = design.load_declaration
    accepted.validate_trace = _ACCEPTED_VALIDATE_TRACE
    inherited.validate_trace = _INHERITED_VALIDATE_TRACE
''',
    )
    binding = '''_ACCEPTED_VALIDATE_TRACE = accepted.validate_trace
_INHERITED_VALIDATE_TRACE = inherited.validate_trace
_BINDING_LOCK = RLock()


def _install_engine_aware_validation() -> None:
    accepted.validate_trace = validate_trace
    inherited.validate_trace = validate_trace


def _configure_engine_for_cell(item: Any) -> startup_binding.StartupTransformSpec:
    _configure_inherited_evaluator()
    inherited._bind_accepted_core()
    spec = startup_binding.startup_transform_spec(item.engine_id)
    design.STARTUP_RAMP_ID = spec.startup_ramp_id
    design.STARTUP_TRANSFORM_ID = spec.startup_transform_id
    design.STARTUP_RAMP_STEPS = spec.startup_step_count
    design.SupportLossConditionedStartup = spec.governor_factory
    design.StartupTransformError = ValueError
    accepted.design = design
    _install_engine_aware_validation()
    return spec


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    """Validate one R23D76 trace under the startup contract for its engine."""

    with _BINDING_LOCK:
        item = design.cell_by_id(cell_id)
        spec = _configure_engine_for_cell(item)
        summary = _ACCEPTED_VALIDATE_TRACE(cell_id, rows)
        failures = list(summary.get("failure_codes", []))
        shape_failures = startup_binding._native_startup_shape_failures(rows, spec)
        cap_failures = inherited._trace_profile_cap_failures(rows, item)
        failures.extend(shape_failures)
        failures.extend(cap_failures)
        failures = list(dict.fromkeys(failures))
        summary.update(
            schema_version=TRACE_SUMMARY_SCHEMA,
            ok=not failures,
            failure_codes=failures[:64],
            engine_id=item.engine_id,
            arm_id=item.arm_id,
            startup_transform_id=spec.startup_transform_id,
            startup_policy=spec.startup_policy,
            engine_aware_startup_binding=True,
            exact_native_startup_shape_observed=not shape_failures,
            exact_public_profile_caps_observed=not cap_failures,
            physical_acceptance_authority=False,
        )
        return summary


'''
    text = _replace_exact(text, "def retain_trace(**kwargs: Any) -> dict[str, Any]:\n", binding + "def retain_trace(**kwargs: Any) -> dict[str, Any]:\n")
    text = _replace_exact(
        text,
        '''def retain_trace(**kwargs: Any) -> dict[str, Any]:
    _configure_inherited_evaluator()
    receipt = inherited.retain_trace(**kwargs)
''',
        '''def retain_trace(**kwargs: Any) -> dict[str, Any]:
    item = design.cell_by_id(str(kwargs.get("cell_id", "")))
    _configure_engine_for_cell(item)
    receipt = inherited.retain_trace(**kwargs)
''',
    )
    text = _replace_exact(
        text,
        '''    _configure_inherited_evaluator()
    terminal_failures = _terminal_contract_failures(entries)
''',
        '''    _configure_inherited_evaluator()
    _install_engine_aware_validation()
    terminal_failures = _terminal_contract_failures(entries)
''',
    )
    text = _replace_exact(
        text,
        '''    value = inherited.run_zero_world_preflight()
    controls = _synthetic_outcome_controls()
''',
        '''    value = inherited.run_zero_world_preflight()
    startup_controls = startup_binding.run_zero_world_preflight()
    _configure_inherited_evaluator()
    controls = _synthetic_outcome_controls()
''',
    )
    text = _replace_exact(
        text,
        '''        complete_outcome_controls=controls,
        model_construction_count=0,
''',
        '''        complete_outcome_controls=controls,
        engine_aware_startup_binding={
            "godot_jolt": startup_binding.SUPPORT_LOSS_STARTUP_ID,
            "rapier_parry": startup_binding.SUPPORT_LOSS_STARTUP_ID,
            "mujoco": startup_binding.UNCONDITIONAL_STARTUP_ID,
        },
        startup_binding_control=startup_controls,
        model_construction_count=0,
''',
    )
    return text


def _godot_worker() -> str:
    text = _common("tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd")
    text = _replace_exact(
        text,
        '''const R23D76_MUJOCO_STARTUP_RAMP_ID := "canonical_velocity_smoothstep_one_gait_cycle_v1"
const R23D76_MUJOCO_STARTUP_RAMP_STEP_COUNT := 360
''',
        '''const R23D76_NATIVE_STARTUP_BINDING_CONTRACT_ID := (
	"QSDK-R23D75-NATIVE-STARTUP-TRACE-EVALUATOR-CONFORMANCE-DEVELOPMENT"
)
const R23D76_SUPPORT_LOSS_STARTUP_ID := "support_loss_latched_smoothstep_one_cycle_v1"
const R23D76_MUJOCO_STARTUP_RAMP_ID := "canonical_velocity_smoothstep_one_gait_cycle_v1"
const R23D76_MUJOCO_STARTUP_RAMP_STEP_COUNT := 360
const R23D76_STARTUP_TRANSFORM_BY_ENGINE := {
	"godot_jolt": R23D76_SUPPORT_LOSS_STARTUP_ID,
	"rapier_parry": R23D76_SUPPORT_LOSS_STARTUP_ID,
	"mujoco": R23D76_MUJOCO_STARTUP_RAMP_ID,
}
''',
    )
    text = _replace_exact(
        text,
        '''		and String(schedule.get("mujoco_startup_ramp_id", "")) == R23D76_MUJOCO_STARTUP_RAMP_ID
		and int(schedule.get("mujoco_startup_ramp_step_count", -1)) == R23D76_MUJOCO_STARTUP_RAMP_STEP_COUNT
''',
        '''		and (
			String(schedule.get("native_startup_binding_contract_id", ""))
			== R23D76_NATIVE_STARTUP_BINDING_CONTRACT_ID
		)
		and schedule.get("startup_transform_by_engine", {}) == R23D76_STARTUP_TRANSFORM_BY_ENGINE
		and int(schedule.get("startup_step_count", -1)) == R23D76_MUJOCO_STARTUP_RAMP_STEP_COUNT
''',
    )
    text = _replace_exact(
        text,
        '''	var dependencies: Dictionary = value.get("dependency_digests", {})
	var exact: bool = (
''',
        '''	var dependencies: Dictionary = value.get("dependency_digests", {})
	var zero_world_pending := (
		String(value.get("status", ""))
		== (
			"implementation_complete_zero_world_gate_pending_"
			+ "bounded_native_smoke_pending_physical_not_authorized"
		)
		and not bool(claims.get("complete_zero_world_gate_passed", true))
	)
	var zero_world_passed := (
		String(value.get("status", ""))
		== (
			"implementation_complete_complete_zero_world_gate_passed_"
			+ "bounded_native_smoke_pending_physical_not_authorized"
		)
		and bool(claims.get("complete_zero_world_gate_passed", false))
	)
	var exact: bool = (
''',
    )
    text = _replace_exact(
        text,
        '''		and (
			String(value.get("status", ""))
			== (
				"implementation_complete_complete_zero_world_gate_passed_"
				+ "physical_not_authorized"
			)
		)
''',
        '''		and (zero_world_pending or zero_world_passed)
''',
    )
    text = _replace_exact(
        text,
        '''		and bool(claims.get("implementation_complete", false))
		and bool(claims.get("complete_zero_world_gate_passed", false))
''',
        '''		and bool(claims.get("implementation_complete", false))
''',
    )
    text = _replace_exact(
        text,
        '''		and bool(freeze.get("complete_zero_world_gate_passed", false))
		and (
''',
        '''		and bool(freeze.get("complete_zero_world_gate_passed", false))
		and (
			String(freeze.get("authorization_fixture_kind", ""))
			== "non_authoritative_zero_world_ghost"
			or bool(implementation.get("claims", {}).get("complete_zero_world_gate_passed", false))
		)
		and (
''',
    )
    return text


def _mujoco_worker() -> str:
    text = _common(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d74_turning_route.py"
    )
    text = _replace_exact(
        text,
        '''    worker = value.get("workers", {}).get(ENGINE_ID, {})
    exact = (
''',
        '''    worker = value.get("workers", {}).get(ENGINE_ID, {})
    claims = value.get("claims", {})
    zero_world_pending = (
        value.get("status")
        == (
            "implementation_complete_zero_world_gate_pending_"
            "bounded_native_smoke_pending_physical_not_authorized"
        )
        and claims.get("complete_zero_world_gate_passed") is False
    )
    zero_world_passed = (
        value.get("status")
        == (
            "implementation_complete_complete_zero_world_gate_passed_"
            "bounded_native_smoke_pending_physical_not_authorized"
        )
        and claims.get("complete_zero_world_gate_passed") is True
    )
    exact = (
''',
    )
    text = _replace_exact(
        text,
        '''        and value.get("status")
        == (
            "implementation_complete_complete_zero_world_gate_passed_"
            "physical_not_authorized"
        )
''',
        '''        and (zero_world_pending or zero_world_passed)
''',
    )
    text = _replace_exact(
        text,
        '''        and value.get("claims", {}).get("implementation_complete") is True
        and value.get("claims", {}).get("complete_zero_world_gate_passed")
        is True
''',
        '''        and claims.get("implementation_complete") is True
''',
    )
    text = _replace_exact(
        text,
        '''        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("implementation_dependency_digests")
''',
        '''        and freeze.get("complete_zero_world_gate_passed") is True
        and (
            freeze.get("authorization_fixture_kind")
            == "non_authoritative_zero_world_ghost"
            or implementation.get("claims", {}).get("complete_zero_world_gate_passed")
            is True
        )
        and freeze.get("implementation_dependency_digests")
''',
    )
    return text


def _rapier_route() -> str:
    text = _common("sdk/adapters/rapier/src/qsdk_r23d74_turning_route.rs")
    text = _replace_exact(
        text,
        '''    let worker = &value["workers"][R23D76_ENGINE_ID];
    let worker_raw = fs::read(root.join(WORKER_PATH))
''',
        '''    let worker = &value["workers"][R23D76_ENGINE_ID];
    let zero_world_pending = value["status"]
        == "implementation_complete_zero_world_gate_pending_bounded_native_smoke_pending_physical_not_authorized"
        && value["claims"]["complete_zero_world_gate_passed"] == false;
    let zero_world_passed = value["status"]
        == "implementation_complete_complete_zero_world_gate_passed_bounded_native_smoke_pending_physical_not_authorized"
        && value["claims"]["complete_zero_world_gate_passed"] == true;
    let worker_raw = fs::read(root.join(WORKER_PATH))
''',
    )
    text = _replace_exact(
        text,
        '''        && value["status"]
            == "implementation_complete_complete_zero_world_gate_passed_physical_not_authorized"
''',
        '''        && (zero_world_pending || zero_world_passed)
''',
    )
    text = _replace_exact(
        text,
        '''        && value["claims"]["implementation_complete"] == true
        && value["claims"]["complete_zero_world_gate_passed"] == true
''',
        '''        && value["claims"]["implementation_complete"] == true
''',
    )
    text = _replace_exact(
        text,
        '''        && freeze["complete_zero_world_gate_passed"] == true
        && freeze["implementation_dependency_digests"] == implementation["dependency_digests"]
''',
        '''        && freeze["complete_zero_world_gate_passed"] == true
        && (freeze["authorization_fixture_kind"] == "non_authoritative_zero_world_ghost"
            || implementation["claims"]["complete_zero_world_gate_passed"] == true)
        && freeze["implementation_dependency_digests"] == implementation["dependency_digests"]
''',
    )
    return _rustfmt(text)


def _supervisor() -> str:
    text = _common("sdk/run_qsdk_r23d74_supervisor.ps1")
    text = _replace_exact(
        text,
        '''    $implementation = Get-Content -LiteralPath $implementationPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    Assert-R23D76 (
''',
        '''    $implementation = Get-Content -LiteralPath $implementationPath -Raw |
        ConvertFrom-Json -AsHashtable -Depth 100
    $zeroWorldPending = (
        [string]$implementation.status -ceq
            "implementation_complete_zero_world_gate_pending_bounded_native_smoke_pending_physical_not_authorized" -and
        -not [bool]$implementation.claims.complete_zero_world_gate_passed
    )
    $zeroWorldPassed = (
        [string]$implementation.status -ceq
            "implementation_complete_complete_zero_world_gate_passed_bounded_native_smoke_pending_physical_not_authorized" -and
        [bool]$implementation.claims.complete_zero_world_gate_passed
    )
    Assert-R23D76 (
''',
    )
    text = _replace_exact(
        text,
        '''        [bool]$implementation.claims.implementation_complete -and
        [bool]$implementation.claims.complete_zero_world_gate_passed -and
''',
        '''        [bool]$implementation.claims.implementation_complete -and
        ($zeroWorldPending -or $zeroWorldPassed) -and
        (-not $RunPhysical -or $zeroWorldPassed) -and
''',
    )
    return text


def _rapier_kernel() -> str:
    relative = "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    text = _source(relative)

    constants = _fixture(_identity(_section(
        text,
        "pub const R23D74_CAMPAIGN_ID: &str =",
        "pub(crate) const TURNING_ROUTE_ID: &str =",
    )))
    text = _replace_exact(
        text,
        "pub(crate) const TURNING_ROUTE_ID: &str =",
        constants + "pub(crate) const TURNING_ROUTE_ID: &str =",
    )

    trace = _fixture(_identity(_section(
        text,
        "pub(crate) fn r23d74_project_production_trace_row(",
        "fn r23d68_retain_trace(",
    )))
    text = _replace_exact(text, "fn r23d68_retain_trace(\n", trace + "fn r23d68_retain_trace(\n")

    retention = _fixture(_identity(_section(
        text,
        "fn r23d74_retain_trace(",
        "fn turning_route_retain_trace(",
    )))
    text = _replace_exact(text, "fn turning_route_retain_trace(\n", retention + "fn turning_route_retain_trace(\n")

    core = _fixture(_identity(_section(
        text,
        "pub(crate) fn run_r23d74_rapier_physical_core(",
        "fn run_r23d27_rapier_physical_world(",
    )))
    core = _replace_exact(
        core,
        "        || plan.r23d71_route\n        || !plan.r23d76_route\n",
        "        || plan.r23d71_route\n        || plan.r23d74_route\n        || !plan.r23d76_route\n",
    )
    text = _replace_exact(text, "fn run_r23d27_rapier_physical_world(\n", core + "fn run_r23d27_rapier_physical_world(\n")

    plan = _fixture(_identity(_section(
        text,
        "    const R23D74_ROUTE: Self = Self {\n",
        "    const fn with_evidence_window_measurement_origin",
    )))
    plan = _replace_exact(
        plan,
        "        r23d76_route: true,\n",
        "        r23d74_route: false,\n        r23d76_route: true,\n",
    )
    text = _replace_exact(
        text,
        "    const fn with_evidence_window_measurement_origin",
        plan + "    const fn with_evidence_window_measurement_origin",
    )

    text = _replace_exact(
        text,
        "    r23d74_route: bool,\n",
        "    r23d74_route: bool,\n    r23d76_route: bool,\n",
    )
    text = text.replace(
        "        r23d74_route: false,\n",
        "        r23d74_route: false,\n        r23d76_route: false,\n",
    )
    text = _replace_exact(
        text,
        "        r23d74_route: true,\n",
        "        r23d74_route: true,\n        r23d76_route: false,\n",
    )
    text = _replace_exact(
        text,
        "        r23d74_route: false,\n        r23d76_route: false,\n        r23d76_route: true,\n",
        "        r23d74_route: false,\n        r23d76_route: true,\n",
    )
    text = text.replace(
        "        || plan.r23d74_route\n",
        "        || plan.r23d74_route\n        || plan.r23d76_route\n",
    )
    text = _replace_exact(
        text,
        '''        || plan.r23d74_route
        || plan.r23d76_route
        || !plan.r23d76_route
''',
        '''        || plan.r23d74_route
        || !plan.r23d76_route
''',
    )
    text = _replace_exact(
        text,
        '''        } else if execution_plan.r23d74_route {
            r23d74_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
        '''        } else if execution_plan.r23d74_route {
            r23d74_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d76_route {
            r23d76_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
    )
    text = _replace_exact(
        text,
        '''    } else if execution_plan.r23d74_route {
        r23d74_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
        '''    } else if execution_plan.r23d74_route {
        r23d74_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d76_route {
        r23d76_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
    )
    return _rustfmt(text)


def _rapier_lib() -> str:
    text = _source("sdk/adapters/rapier/src/lib.rs")
    text = _replace_exact(
        text,
        "mod qsdk_r23d74_turning_route;\n",
        "mod qsdk_r23d74_turning_route;\nmod qsdk_r23d76_receipt_contract;\nmod qsdk_r23d76_turning_route;\n",
    )
    text = _replace_exact(
        text,
        '''pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D74_CAMPAIGN_ID, R23D74_CAMPAIGN_SEED, R23D74_GATE_ID, R23D74_STAGE_ID,
};
''',
        '''pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D74_CAMPAIGN_ID, R23D74_CAMPAIGN_SEED, R23D74_GATE_ID, R23D74_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D76_CAMPAIGN_ID, R23D76_CAMPAIGN_SEED, R23D76_GATE_ID, R23D76_STAGE_ID,
};
''',
    )
    text = _replace_exact(
        text,
        '''pub use qsdk_r23d74_turning_route::{
    run_qsdk_r23d74_rapier_authorization_preflight, run_qsdk_r23d74_rapier_complete_row_ghost,
    run_qsdk_r23d74_rapier_physical, run_qsdk_r23d74_rapier_preflight,
    run_qsdk_r23d74_success_terminal_projection_ghost,
};
''',
        '''pub use qsdk_r23d74_turning_route::{
    run_qsdk_r23d74_rapier_authorization_preflight, run_qsdk_r23d74_rapier_complete_row_ghost,
    run_qsdk_r23d74_rapier_physical, run_qsdk_r23d74_rapier_preflight,
    run_qsdk_r23d74_success_terminal_projection_ghost,
};
pub use qsdk_r23d76_turning_route::{
    run_qsdk_r23d76_rapier_authorization_preflight, run_qsdk_r23d76_rapier_complete_row_ghost,
    run_qsdk_r23d76_rapier_physical, run_qsdk_r23d76_rapier_preflight,
    run_qsdk_r23d76_success_terminal_projection_ghost,
};
''',
    )
    return _rustfmt(text)


def _plain(relative: str) -> str:
    return _common(relative)


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk/turning/r23d76_production_route_runtime.py", _runtime),
    (
        ROOT / "sdk/turning/r23d76_production_route_three_engine_turning_evaluator.py",
        _evaluator,
    ),
    (ROOT / "sdk/turning/r23d76_receipt_contract.py", lambda: _plain("sdk/turning/r23d74_receipt_contract.py")),
    (ROOT / "sdk/turning/r23d76_receipt_contract.gd", lambda: _plain("sdk/turning/r23d74_receipt_contract.gd")),
    (ROOT / "tests/test_sdk_qsdk_r23d76_godot_jolt_worker.gd", _godot_worker),
    (
        ROOT / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d76_turning_route.py",
        _mujoco_worker,
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d76_receipt_contract.rs",
        lambda: _rustfmt(_plain("sdk/adapters/rapier/src/qsdk_r23d74_receipt_contract.rs")),
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d76_turning_route.rs",
        _rapier_route,
    ),
    (
        ROOT / "sdk/adapters/rapier/src/bin/qsdk_r23d76_turning_route.rs",
        lambda: _rustfmt(_plain("sdk/adapters/rapier/src/bin/qsdk_r23d74_turning_route.rs")),
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
        _rapier_kernel,
    ),
    (ROOT / "sdk/adapters/rapier/src/lib.rs", _rapier_lib),
    (ROOT / "sdk/run_qsdk_r23d76_supervisor.ps1", _supervisor),
)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    for path, compose in OUTPUTS:
        raw = compose().encode("utf-8")
        relative = path.relative_to(ROOT).as_posix()
        if arguments.command == "write":
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        elif not path.is_file() or path.read_bytes() != raw:
            raise MaterializationError(f"R23D76_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D76 native bindings {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
