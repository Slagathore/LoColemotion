#!/usr/bin/env python3
"""Materialize the narrow R23D74 native campaign bindings.

The clean, pushed R23D74 declaration commit is the exact source parent.  This
tool projects the already closed R23D71 full-horizon workers and supervisor to
the fresh R23D74 identity and seed.  Later functions apply only the separately
closed transport, evidence-origin, and MuJoCo startup-ramp bindings.  It imports
no physics library and opens no model or world.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "8b25295505507a21cc187a046f5385e023286966"


class MaterializationError(RuntimeError):
    """The exact R23D74 source projection could not be composed."""


def _source(relative: str) -> str:
    process = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_COMMIT}:{relative}"],
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        raise MaterializationError(
            f"R23D74_SOURCE_UNREADABLE:{relative}:"
            + process.stderr.decode(errors="replace")
        )
    return process.stdout.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D74_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:140]!r}"
        )
    return text.replace(old, new)


def _replace_first_exact(
    text: str,
    old: str,
    new: str,
    *,
    observed_count: int,
    replacement_count: int,
) -> str:
    observed = text.count(old)
    if observed != observed_count or not 0 <= replacement_count <= observed_count:
        raise MaterializationError(
            "R23D74_PREFIX_ANCHOR_COUNT_INVALID:"
            f"{observed}:{observed_count}:{replacement_count}:{old[:140]!r}"
        )
    return text.replace(old, new, replacement_count)


def _section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(f"R23D74_SECTION_START_INVALID:{start!r}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(f"R23D74_SECTION_END_INVALID:{end!r}")
    return text[start_index:end_index]


def _replace_section(text: str, start: str, end: str, replacement: str) -> str:
    return text.replace(_section(text, start, end), replacement, 1)


def _replace_tail(text: str, start: str, replacement: str) -> str:
    observed = text.count(start)
    if observed != 1:
        raise MaterializationError(
            f"R23D74_TAIL_START_INVALID:{observed}:1:{start!r}"
        )
    return text[: text.index(start)] + replacement


def _identity(text: str) -> str:
    replacements = (
        (
            "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-"
            "THREE-ENGINE-TURNING-VALIDATION",
            "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION",
        ),
        (
            "r23d71_success_terminal_projection_repaired_three_engine_turning_"
            "preregistration_v1.json",
            "r23d74_fresh_finite_three_engine_turning_decision_v1.json",
        ),
        (
            "success_terminal_projection_repaired_three_engine_turning_validation",
            "fresh_finite_three_engine_turning_decision",
        ),
        ("R23D71", "R23D74"),
        ("r23d71", "r23d74"),
        ("23_191", "23_193"),
        ("23191", "23193"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _fixture(text: str) -> str:
    replacements = (
        ("0.0002604132751002908", "0.00004413922579260543"),
        ("-0.0049262382090091705", "-0.003177209757268429"),
        ("0.002370542846620083", "-0.0031423636246472597"),
        ("0.0037111244164407253", "0.0016733058728277683"),
        ("-0.0003552224952727556", "0.0016716052778065205"),
        ("-0.0022123241797089577", "-0.0006206459365785122"),
        ("0.00008024764247238636", "0.0009215378668159246"),
        ("0.000_260_413_275_100_290_8", "0.000_044_139_225_792_605_43"),
        ("-0.004_926_238_209_009_170_5", "-0.003_177_209_757_268_429"),
        ("0.002_370_542_846_620_083", "-0.003_142_363_624_647_259_7"),
        ("0.003_711_124_416_440_725_3", "0.001_673_305_872_827_768_3"),
        ("-0.000_355_222_495_272_755_6", "0.001_671_605_277_806_520_5"),
        ("-0.002_212_324_179_708_957_7", "-0.000_620_645_936_578_512_2"),
        ("0.000_080_247_642_472_386_36", "0.000_921_537_866_815_924_6"),
        ('"gait_phase_offset_ticks": -1', '"gait_phase_offset_ticks": 0'),
        ("gait_phase_offset_ticks: -1", "gait_phase_offset_ticks: 0"),
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
        raise MaterializationError("R23D74_RUSTFMT_FAILED:" + process.stderr.strip())
    return process.stdout.replace("\r\n", "\n")


def _runtime() -> str:
    text = _common("sdk/turning/r23d71_production_route_runtime.py")
    text = _replace_section(
        text,
        "SCHEMA = (\n",
        "GATE_ID = ",
        '''SCHEMA = "sporespore_qsdk_r23d74_fresh_finite_three_engine_turning_decision_v1"
STATUS = "prospective_declaration_complete_implementation_pending_physical_not_authorized"
CAMPAIGN_ID = "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
''',
    )
    text = _replace_exact(
        text,
        "CAMPAIGN_SEED = 23_193\n",
        '''CAMPAIGN_SEED = 23_193
MEASUREMENT_ORIGIN_POLICY_ID = "evidence_window_start_semantic_step_v1"
MEASUREMENT_ORIGIN_SEMANTIC_STEP = 472
MUJOCO_STARTUP_RAMP_ID = "canonical_velocity_smoothstep_one_gait_cycle_v1"
MUJOCO_STARTUP_RAMP_STEP_COUNT = 360
''',
    )
    return _replace_tail(
        text,
        "def validate_declaration(value: dict[str, Any]) -> None:\n",
        '''def validate_declaration(value: dict[str, Any]) -> None:
    """Validate the exact fresh finite R23D74 source declaration."""

    _require(value.get("schema_version") == SCHEMA, "SCHEMA_INVALID")
    _require(value.get("status") == STATUS, "STATUS_INVALID")
    _require(value.get("campaign_id") == CAMPAIGN_ID, "CAMPAIGN_ID_INVALID")
    _require(value.get("gate_id") == GATE_ID, "GATE_ID_INVALID")
    _require(value.get("release_gate_id") == "QSDK-R23", "RELEASE_GATE_ID_INVALID")
    _require(value.get("question_class") == QUESTION_CLASS, "QUESTION_CLASS_INVALID")
    _require(
        value.get("ledger_scope")
        == {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "prospective_declaration",
            "question_class": QUESTION_CLASS,
        },
        "LEDGER_SCOPE_INVALID",
    )
    _require(value.get("not_development_work") is True, "DEVELOPMENT_CLASS_INVALID")
    _require(value.get("not_superiority_work") is True, "SUPERIORITY_CLASS_INVALID")
    _require(
        value.get("not_equivalence_or_non_inferiority_work") is True,
        "EQUIVALENCE_CLASS_INVALID",
    )

    selection = value.get("held_out_seed_selection", {})
    _require(selection.get("seed") == CAMPAIGN_SEED, "FRESH_SEED_INVALID")
    _require(selection.get("first_candidate") == CAMPAIGN_SEED, "CANDIDATE_INVALID")
    _require(
        selection.get("first_candidate_token_occurrence_count_at_declaration_parent")
        == 0,
        "FRESH_SEED_OCCURRENCE_INVALID",
    )
    _require(
        selection.get("selection_performed_after_development_design_frozen") is True
        and selection.get("physical_outcome_observed_at_selection") is False
        and selection.get("physical_world_opened_at_selection") is False
        and selection.get("held_out_for_prospective_native_validation") is True,
        "HELD_OUT_SELECTION_INVALID",
    )

    fixture = value.get("seed_fixture_compilation", {})
    compiled = copy.deepcopy(fixture.get("compiled_initial_perturbation", {}))
    compiled.pop("cohort", None)
    _require(fixture.get("seed") == CAMPAIGN_SEED, "FIXTURE_SEED_INVALID")
    _require(compiled == INITIAL_PERTURBATION, "FIXTURE_INVALID")
    _require(
        fixture.get("model_construction_count") == 0
        and fixture.get("world_attempt_count") == 0
        and fixture.get("world_build_count") == 0,
        "FIXTURE_WORLD_COUNT_INVALID",
    )

    population = value.get("finite_population", {})
    _require(population.get("engine_order") == list(ENGINES), "ENGINE_ORDER_INVALID")
    _require(
        population.get("arm_order") == [arm_id for arm_id, _ in ARMS],
        "ARM_ORDER_INVALID",
    )
    _require(
        population.get("arm_heading_offsets_rad")
        == {arm_id: offset for arm_id, offset in ARMS},
        "ARM_OFFSETS_INVALID",
    )
    _require(
        population.get("ordered_cell_ids") == [item.cell_id for item in cells()],
        "CELL_ORDER_INVALID",
    )
    _require(
        population.get("declared_engine_count") == 3
        and population.get("declared_arm_count") == 3
        and population.get("declared_cell_count") == 9
        and population.get("sampling_used") is False
        and population.get("complete_enumeration_required") is True
        and population.get("all_cells_run_regardless_of_intermediate_behavior") is True
        and population.get("selective_completion_or_rerun_allowed") is False
        and population.get("population_inference_beyond_declared_matrix_allowed")
        is False,
        "FINITE_POPULATION_INVALID",
    )

    schedule = value.get("fixed_schedule", {})
    _require(
        schedule
        == {
            "controller_semantic_step_count": CONTROLLER_STEPS,
            "first_semantic_step": 0,
            "last_semantic_step": CONTROLLER_STEPS - 1,
            "reference_warmup_step_count": TURN_START_STEP,
            "commanded_turn_step_count": TURN_END_STEP_EXCLUSIVE - TURN_START_STEP,
            "reference_recovery_step_count": RECOVERY_DURATION_STEPS,
            "reference_continuation_step_count": (
                CONTROLLER_STEPS - TURN_END_STEP_EXCLUSIVE - RECOVERY_DURATION_STEPS
            ),
            "turn_start_semantic_step": TURN_START_STEP,
            "turn_end_semantic_step_exclusive": TURN_END_STEP_EXCLUSIVE,
            "forward_displacement_measurement_origin_policy_id": (
                MEASUREMENT_ORIGIN_POLICY_ID
            ),
            "forward_displacement_measurement_origin_semantic_step": (
                MEASUREMENT_ORIGIN_SEMANTIC_STEP
            ),
            "mujoco_startup_ramp_id": MUJOCO_STARTUP_RAMP_ID,
            "mujoco_startup_ramp_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
        },
        "FIXED_SCHEDULE_INVALID",
    )

    change = value.get("scientific_change_budget", {})
    _require(
        change.get("fresh_campaign_identity") is True
        and change.get("fresh_seed_and_compiled_initial_perturbation") is True
        and change.get("prospective_evidence_window_origin_opt_in") is True
        and change.get("mujoco_unconditional_one_cycle_startup_ramp") is True
        and change.get("new_campaign_transport_identities") is True,
        "ALLOWED_CHANGE_BUDGET_INVALID",
    )
    for key in (
        "physical_command_changed",
        "behavior_threshold_changed",
        "selector_changed",
        "cycle_measurement_changed",
        "behavior_evaluator_changed",
        "controller_changed",
        "public_profile_changed",
        "schedule_changed",
        "engine_or_arm_population_changed",
        "historical_campaign_changed",
        "historical_evidence_reused_as_r23d74_result",
    ):
        _require(change.get(key) is False, f"FORBIDDEN_CHANGE_INVALID:{key}")

    thresholds = value.get("thresholds_and_estimator", {})
    expected_common = copy.deepcopy(base.load_declaration()["frozen_common_physical_gates"])
    expected_common.pop("maximum_portable_impulse_violation_count", None)
    _require(
        thresholds.get("common_physical_gate_vector") == expected_common,
        "COMMON_GATE_VECTOR_INVALID",
    )
    _require(
        thresholds.get("minimum_positive_raw_cycle_shift_rad") == 0.01
        and thresholds.get("maximum_negative_raw_cycle_shift_rad") == -0.01
        and thresholds.get("minimum_positive_reference_conditioned_cycle_shift_rad")
        == 0.01
        and thresholds.get("minimum_negative_reference_conditioned_cycle_shift_rad")
        == 0.01,
        "TURNING_THRESHOLDS_INVALID",
    )
    _require(
        thresholds.get("equivalence_margin") is None
        and thresholds.get("non_inferiority_margin") is None
        and thresholds.get("equivalence_or_non_inferiority_interpretation_allowed")
        is False,
        "MARGIN_INVALID",
    )

    zero_world = value.get("required_zero_world_implementation_gate", {})
    _require(
        zero_world.get("full_seeded_world_ghost_required") is False
        and zero_world.get("behavioral_success_prediction_allowed") is False,
        "GHOST_SCOPE_INVALID",
    )
    for key in (
        "production_worker_parse_and_route_construction_required",
        "compact_success_terminal_projection_required",
        "exact_seed_fixture_recompilation_required",
        "complete_three_engine_source_binding_required",
        "complete_nine_cell_selector_proof_required",
        "authorization_failure_before_model_required",
        "threshold_and_schedule_mutation_controls_required",
        "r23d71_closure_replay_required",
        "three_engine_execution_route_closure_replay_required",
        "measurement_origin_parity_replay_required",
        "r23d73_closure_replay_required",
    ):
        _require(zero_world.get(key) is True, f"ZERO_WORLD_CONTROL_INVALID:{key}")
    _require(
        all(
            zero_world.get(key) == 0
            for key in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        ),
        "ZERO_WORLD_COUNT_INVALID",
    )

    authorization = value.get("physical_authorization", {})
    claims = value.get("claims", {})
    _require(
        authorization.get("physical_execution_authorized") is False
        and authorization.get("physical_acceptance_authority") is False,
        "SOURCE_AUTHORIZATION_INVALID",
    )
    _require(
        claims.get("implementation_complete") is False
        and claims.get("zero_world_gate_passed") is False
        and claims.get("physical_campaign_opened") is False
        and claims.get("finite_three_engine_turning") is False
        and claims.get("portable_basic_turning") is False
        and claims.get("release_score_before") == "10/25"
        and claims.get("release_score_after") == "10/25"
        and claims.get("release_authorized") is False,
        "SOURCE_CLAIMS_INVALID",
    )


def load_declaration() -> dict[str, Any]:
    """Project R23D74 identity onto the unchanged R23D66 behavior contract."""

    source = load_source_declaration()
    projected = copy.deepcopy(base.load_declaration())
    projected.update(
        schema_version=SCHEMA,
        status=STATUS,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        release_gate_id="QSDK-R23",
        ledger_scope=copy.deepcopy(source["ledger_scope"]),
        physical_question_class=QUESTION_CLASS,
        question_class=QUESTION_CLASS,
        physical_question_declared=True,
        physical_campaign_opened=False,
        seed_fixture_compilation=copy.deepcopy(source["seed_fixture_compilation"]),
        fixed_schedule=copy.deepcopy(source["fixed_schedule"]),
        thresholds_and_estimator=copy.deepcopy(source["thresholds_and_estimator"]),
    )
    matrix = projected["frozen_matrix"]
    matrix.update(
        stage_id=STAGE_ID,
        seed=CAMPAIGN_SEED,
        initial_perturbation=copy.deepcopy(INITIAL_PERTURBATION),
        cells=[
            {
                "cell_id": item.cell_id,
                "engine_id": item.engine_id,
                "arm_id": item.arm_id,
                "turn_heading_offset_rad": item.turn_heading_offset_rad,
            }
            for item in cells()
        ],
    )
    return projected


def validate_runtime_projection() -> dict[str, Any]:
    source = load_source_declaration()
    projected = load_declaration()
    matrix = projected["frozen_matrix"]
    projected_cells = [asdict(item) for item in cells()]
    schedule = source["fixed_schedule"]
    population = source["finite_population"]
    exact = (
        matrix["seed"] == CAMPAIGN_SEED
        and matrix["controller_step_count"] == CONTROLLER_STEPS
        and matrix["turn_start_step"] == TURN_START_STEP
        and matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        and matrix["recovery_duration_steps"] == RECOVERY_DURATION_STEPS
        and matrix["ordered_engine_ids"] == population["engine_order"]
        and matrix["ordered_arm_ids"] == population["arm_order"]
        and matrix["initial_perturbation"] == INITIAL_PERTURBATION
        and [item["cell_id"] for item in projected_cells]
        == population["ordered_cell_ids"]
        and schedule["controller_semantic_step_count"] == CONTROLLER_STEPS
        and schedule["forward_displacement_measurement_origin_semantic_step"]
        == MEASUREMENT_ORIGIN_SEMANTIC_STEP
        and schedule["mujoco_startup_ramp_id"] == MUJOCO_STARTUP_RAMP_ID
        and schedule["mujoco_startup_ramp_step_count"]
        == MUJOCO_STARTUP_RAMP_STEP_COUNT
        and sum(_declared_segment_counts().values()) == CONTROLLER_STEPS
    )
    _require(exact, "PROJECTION_INVALID")
    return {
        "schema_version": "sporespore_qsdk_r23d74_runtime_projection_v1",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "cell_count": len(projected_cells),
        "segment_counts": _declared_segment_counts(),
        "controller_step_count": CONTROLLER_STEPS,
        "measurement_origin_policy_id": MEASUREMENT_ORIGIN_POLICY_ID,
        "measurement_origin_semantic_step": MEASUREMENT_ORIGIN_SEMANTIC_STEP,
        "mujoco_startup_ramp_id": MUJOCO_STARTUP_RAMP_ID,
        "mujoco_startup_ramp_step_count": MUJOCO_STARTUP_RAMP_STEP_COUNT,
        "source_declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "root_behavior_contract_raw_sha256": raw_sha256(base.DECLARATION_PATH),
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
    }
''',
    )


def _evaluator() -> str:
    text = _common(
        "sdk/turning/r23d71_production_route_three_engine_turning_evaluator.py"
    )
    text = _replace_exact(
        text,
        '''def retain_trace(**kwargs: Any) -> dict[str, Any]:
    _configure_inherited_evaluator()
    receipt = inherited.retain_trace(**kwargs)
    return project_retention_receipt(
        receipt, expected_row_count=design.CONTROLLER_STEPS
    )


''',
        '''def retain_trace(**kwargs: Any) -> dict[str, Any]:
    _configure_inherited_evaluator()
    receipt = inherited.retain_trace(**kwargs)
    artifact = receipt.get("trace_artifact")
    if not isinstance(artifact, Mapping):
        raise EvaluationError("QSDK_R23D74_TRACE_ARTIFACT_NOT_OBJECT")
    enriched_artifact = copy.deepcopy(dict(artifact))
    enriched_artifact.update(
        trace_transport_id=TRACE_TRANSPORT_ID,
        trace_transport_engine_id=receipt.get("engine_id"),
        canonical_ndjson=True,
        full_precision=True,
    )
    receipt.update(
        question_class=design.QUESTION_CLASS,
        trace_artifact=enriched_artifact,
    )
    return project_retention_receipt(
        receipt, expected_row_count=design.CONTROLLER_STEPS
    )


def _terminal_contract_failures(
    entries: Sequence[dict[str, Any]],
) -> list[str]:
    failures: list[str] = []
    for entry, item in zip(entries, design.cells(), strict=False):
        prefix = f"{item.engine_id}:{item.arm_id}"
        if entry.get("question_class") != design.QUESTION_CLASS:
            failures.append(f"{prefix}:QUESTION_CLASS")
        artifact = entry.get("trace_artifact")
        if not isinstance(artifact, Mapping):
            failures.append(f"{prefix}:TRACE_ARTIFACT")
            continue
        if artifact.get("trace_transport_id") != TRACE_TRANSPORT_ID:
            failures.append(f"{prefix}:TRACE_TRANSPORT_ID")
        if artifact.get("trace_transport_engine_id") != item.engine_id:
            failures.append(f"{prefix}:TRACE_TRANSPORT_ENGINE_ID")
        if artifact.get("canonical_ndjson") is not True:
            failures.append(f"{prefix}:CANONICAL_NDJSON")
        if artifact.get("full_precision") is not True:
            failures.append(f"{prefix}:FULL_PRECISION")
        if type(artifact.get("byte_length")) is not int:
            failures.append(f"{prefix}:BYTE_LENGTH_INTEGER")
    if len(entries) != len(design.cells()):
        failures.append("COMPLETE_ENTRY_COUNT")
    return failures


''',
    )
    text = _replace_exact(
        text,
        '''    _configure_inherited_evaluator()
    value = inherited.evaluate_complete_entries(
''',
        '''    _configure_inherited_evaluator()
    terminal_failures = _terminal_contract_failures(entries)
    if terminal_failures:
        raise EvaluationError(
            "QSDK_R23D74_SUCCESS_TERMINAL_CONTRACT_INVALID:"
            + ",".join(terminal_failures)
        )
    value = inherited.evaluate_complete_entries(
''',
    )
    return text


def _receipt_python() -> str:
    return _common("sdk/turning/r23d71_receipt_contract.py")


def _receipt_godot() -> str:
    return _common("sdk/turning/r23d71_receipt_contract.gd")


def _receipt_rust() -> str:
    return _rustfmt(_common("sdk/adapters/rapier/src/qsdk_r23d71_receipt_contract.rs"))


def _godot_worker() -> str:
    text = _common("tests/test_sdk_qsdk_r23d71_godot_jolt_worker.gd")
    text = _replace_exact(
        text,
        '''const R23D74_PREREGISTRATION_SCHEMA := "sporespore_qsdk_r23d74_success_terminal_projection_repaired_three_engine_turning_preregistration_v1"
''',
        '''const R23D74_PREREGISTRATION_SCHEMA := "sporespore_qsdk_r23d74_fresh_finite_three_engine_turning_decision_v1"
''',
    )
    text = _replace_exact(
        text,
        "const R23D74_RECOVERY_END_STEP_EXCLUSIVE := 2400\n",
        '''const R23D74_RECOVERY_END_STEP_EXCLUSIVE := 2400
const R23D74_MEASUREMENT_ORIGIN_POLICY_ID := "evidence_window_start_semantic_step_v1"
const R23D74_MEASUREMENT_ORIGIN_SEMANTIC_STEP := 472
const R23D74_MUJOCO_STARTUP_RAMP_ID := "canonical_velocity_smoothstep_one_gait_cycle_v1"
const R23D74_MUJOCO_STARTUP_RAMP_STEP_COUNT := 360
''',
    )
    text = _replace_section(
        text,
        "func _campaign_prepare(cell: Dictionary) -> Dictionary:\n",
        "\t# Compile the already accepted full-horizon fixture",
        '''func _campaign_prepare(cell: Dictionary) -> Dictionary:
	var contract := _r23d74_implementation_contract()
	if not bool(contract.get("ok", false)):
		return contract
	var declaration := R23D74BaseWorkerScript._read_json(R23D74_PREREGISTRATION_PATH)
	var inherited := R23D74BaseWorkerScript._read_json(R23D74_INHERITED_BEHAVIOR_PATH)
	var population: Dictionary = declaration.get("finite_population", {})
	var schedule: Dictionary = declaration.get("fixed_schedule", {})
	var inherited_matrix: Dictionary = inherited.get("frozen_matrix", {})
	var source_claims: Dictionary = declaration.get("claims", {})
	var source_authorization: Dictionary = declaration.get("physical_authorization", {})
	var declared_cell := (
		cell.duplicate(true)
		if population.get("ordered_cell_ids", []).has(String(cell.get("cell_id", "")))
		else {}
	)
	var declaration_exact: bool = (
		String(declaration.get("schema_version", "")) == R23D74_PREREGISTRATION_SCHEMA
		and (
			String(declaration.get("status", ""))
			== "prospective_declaration_complete_implementation_pending_physical_not_authorized"
		)
		and String(declaration.get("campaign_id", "")) == R23D74_CAMPAIGN_ID
		and String(declaration.get("gate_id", "")) == R23D74_GATE_ID
		and String(declaration.get("question_class", "")) == "finite_decision"
		and bool(declaration.get("not_development_work", false))
		and bool(declaration.get("not_superiority_work", false))
		and bool(declaration.get("not_equivalence_or_non_inferiority_work", false))
		and not bool(source_authorization.get("physical_execution_authorized", true))
		and not bool(source_authorization.get("physical_acceptance_authority", true))
		and not bool(source_claims.get("implementation_complete", true))
		and not bool(source_claims.get("zero_world_gate_passed", true))
		and not bool(source_claims.get("physical_campaign_opened", true))
		and population.get("engine_order", []) == R23D74_ORDERED_ENGINE_IDS
		and population.get("arm_order", []) == R23D74_ORDERED_ARM_IDS
		and population.get("arm_heading_offsets_rad", {}) == R23D74_ARM_OFFSETS
		and int(population.get("declared_engine_count", -1)) == 3
		and int(population.get("declared_arm_count", -1)) == 3
		and int(population.get("declared_cell_count", -1)) == 9
		and population.get("ordered_cell_ids", []) == _r23d74_expected_cell_ids()
		and bool(population.get("complete_enumeration_required", false))
		and bool(population.get("all_cells_run_regardless_of_intermediate_behavior", false))
		and not bool(population.get("sampling_used", true))
		and not bool(population.get("selective_completion_or_rerun_allowed", true))
		and int(schedule.get("controller_semantic_step_count", -1)) == R23D74_CONTROLLER_STEPS
		and int(schedule.get("first_semantic_step", -1)) == 0
		and int(schedule.get("last_semantic_step", -1)) == R23D74_CONTROLLER_STEPS - 1
		and int(schedule.get("turn_start_semantic_step", -1)) == R23D74_TURN_START_STEP
		and int(schedule.get("turn_end_semantic_step_exclusive", -1)) == R23D74_TURN_END_STEP_EXCLUSIVE
		and (
			String(schedule.get("forward_displacement_measurement_origin_policy_id", ""))
			== R23D74_MEASUREMENT_ORIGIN_POLICY_ID
		)
		and (
			int(schedule.get("forward_displacement_measurement_origin_semantic_step", -1))
			== R23D74_MEASUREMENT_ORIGIN_SEMANTIC_STEP
		)
		and String(schedule.get("mujoco_startup_ramp_id", "")) == R23D74_MUJOCO_STARTUP_RAMP_ID
		and int(schedule.get("mujoco_startup_ramp_step_count", -1)) == R23D74_MUJOCO_STARTUP_RAMP_STEP_COUNT
		and int(inherited_matrix.get("controller_step_count", -1)) == R23D74_CONTROLLER_STEPS
		and int(inherited_matrix.get("turn_start_step", -1)) == R23D74_TURN_START_STEP
		and int(inherited_matrix.get("turn_end_step_exclusive", -1)) == R23D74_TURN_END_STEP_EXCLUSIVE
		and (
			int(inherited_matrix.get("recovery_duration_steps", -1))
			== R23D74_RECOVERY_END_STEP_EXCLUSIVE - R23D74_TURN_END_STEP_EXCLUSIVE
		)
		and String(inherited_matrix.get("controller_policy_id", "")) == R23D74_POLICY_ID
		and String(inherited_matrix.get("task_frame_origin_policy_id", "")) == R23D74_TASK_ORIGIN_POLICY_ID
		and bool(inherited_matrix.get("serial_execution_required", false))
		and bool(inherited_matrix.get("fresh_world_required_per_cell", false))
		and String(declared_cell.get("engine_id", "")) == R23D74_ENGINE_ID
		and String(declared_cell.get("arm_id", "")) == String(cell["arm_id"])
		and (
			float(declared_cell.get("turn_heading_offset_rad", INF))
			== float(cell["turn_heading_offset_rad"])
		)
	)
	if not declaration_exact:
		return _r23d74_failure(
			"QSDK_R23D74_GJT_DECLARATION_INVALID",
			{"declared_cell": declared_cell, "live_cell": cell},
		)

''',
    )
    text = _replace_exact(
        text,
        '''	var artifact: Dictionary = (receipt.get("trace_artifact", {}) as Dictionary).duplicate(true)
	artifact["trace_transport_id"] = R23D74_TRACE_TRANSPORT_ID
	artifact["godot_runtime_version"] = String(Engine.get_version_info().get("string", ""))
	artifact["selected_godot_invocation"] = R23D74_TRACE_TRANSPORT_INVOCATION
	artifact["godot_json_sorted_keys"] = true
	artifact["godot_json_full_precision"] = true
	receipt["trace_artifact"] = artifact
''',
        '''	if String(receipt.get("question_class", "")) != "finite_decision":
		return _r23d74_failure("QSDK_R23D74_GJT_TRACE_QUESTION_CLASS_INVALID")
	var artifact_projection := _r23d74_canonical_trace_artifact(receipt.get("trace_artifact", {}))
	if not bool(artifact_projection.get("ok", false)):
		return _r23d74_failure(
			"QSDK_R23D74_GJT_%s" % String(artifact_projection.get("failure_code", "TRACE_ARTIFACT_INVALID"))
		)
	var artifact: Dictionary = artifact_projection["artifact"]
	if (
		String(artifact.get("trace_transport_id", "")) != R23D74_TRACE_TRANSPORT_ID
		or String(artifact.get("trace_transport_engine_id", "")) != R23D74_ENGINE_ID
		or not bool(artifact.get("canonical_ndjson", false))
		or not bool(artifact.get("full_precision", false))
	):
		return _r23d74_failure("QSDK_R23D74_GJT_TRACE_ARTIFACT_TRANSPORT_INVALID")
	var summary: Dictionary = (receipt.get("trace_summary", {}) as Dictionary).duplicate(true)
	var summary_length_value: Variant = summary.get("byte_length", null)
	if typeof(summary_length_value) != TYPE_INT and typeof(summary_length_value) != TYPE_FLOAT:
		return _r23d74_failure("QSDK_R23D74_GJT_TRACE_SUMMARY_BYTE_LENGTH_TYPE_INVALID")
	var summary_length_float := float(summary_length_value)
	var summary_length_int := int(summary_length_value)
	if (
		is_nan(summary_length_float)
		or is_inf(summary_length_float)
		or summary_length_int < 0
		or summary_length_float != float(summary_length_int)
		or summary_length_int != int(artifact["byte_length"])
	):
		return _r23d74_failure("QSDK_R23D74_GJT_TRACE_SUMMARY_BYTE_LENGTH_VALUE_INVALID")
	summary["byte_length"] = summary_length_int
	artifact["godot_runtime_version"] = String(Engine.get_version_info().get("string", ""))
	artifact["selected_godot_invocation"] = R23D74_TRACE_TRANSPORT_INVOCATION
	artifact["godot_json_sorted_keys"] = true
	artifact["godot_json_full_precision"] = true
	receipt["trace_artifact"] = artifact
	receipt["trace_summary"] = summary
''',
    )
    text = _replace_exact(
        text,
        "static func _r23d74_implementation_contract() -> Dictionary:\n",
        '''static func _r23d74_canonical_trace_artifact(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {"ok": false, "failure_code": "TRACE_ARTIFACT_TYPE_INVALID"}
	var artifact: Dictionary = (value as Dictionary).duplicate(true)
	var byte_length_value: Variant = artifact.get("byte_length", null)
	if typeof(byte_length_value) != TYPE_INT and typeof(byte_length_value) != TYPE_FLOAT:
		return {"ok": false, "failure_code": "TRACE_ARTIFACT_BYTE_LENGTH_TYPE_INVALID"}
	var byte_length_float := float(byte_length_value)
	var byte_length_int := int(byte_length_value)
	if (
		is_nan(byte_length_float)
		or is_inf(byte_length_float)
		or byte_length_int < 0
		or byte_length_float != float(byte_length_int)
	):
		return {"ok": false, "failure_code": "TRACE_ARTIFACT_BYTE_LENGTH_VALUE_INVALID"}
	artifact["byte_length"] = byte_length_int
	return {"ok": true, "failure_code": "", "artifact": artifact}


static func _r23d74_implementation_contract() -> Dictionary:
''',
    )
    return text


def _mujoco_worker() -> str:
    text = _common(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d71_turning_route.py"
    )
    text = _replace_exact(text, "import json\n", "import json\nimport math\n")
    text = _replace_exact(
        text,
        '''import r23d74_production_route_runtime as design  # noqa: E402
import r23d74_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402
''',
        '''import r23d38_mujoco_startup_ramp_stabilization as ramp_design  # noqa: E402
import r23d74_production_route_runtime as design  # noqa: E402
import r23d74_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402
''',
    )
    text = _replace_exact(
        text,
        "FALSE_CLAIMS = copy.deepcopy(evaluator.FALSE_CLAIMS)\n",
        '''FALSE_CLAIMS = copy.deepcopy(evaluator.FALSE_CLAIMS)
_INHERITED_CORE_RUN_PHYSICAL = production._core.run_physical
''',
    )
    text = _replace_exact(
        text,
        '''    if failures:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_TRACE_RETENTION_RECEIPT_INVALID:"
            + ",".join(failures),
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


def _configure_shared_kernel() -> None:
''',
        '''    artifact = receipt.get("trace_artifact")
    if receipt.get("question_class") != "finite_decision":
        failures.append("R23D74_QUESTION_CLASS_MISMATCH")
    if not isinstance(artifact, Mapping):
        failures.append("R23D74_TRACE_ARTIFACT_NOT_OBJECT")
    else:
        if artifact.get("trace_transport_id") != evaluator.TRACE_TRANSPORT_ID:
            failures.append("R23D74_TRACE_TRANSPORT_ID_MISMATCH")
        if artifact.get("trace_transport_engine_id") != ENGINE_ID:
            failures.append("R23D74_TRACE_TRANSPORT_ENGINE_ID_MISMATCH")
        if artifact.get("canonical_ndjson") is not True:
            failures.append("R23D74_TRACE_CANONICAL_NDJSON_MISMATCH")
        if artifact.get("full_precision") is not True:
            failures.append("R23D74_TRACE_FULL_PRECISION_MISMATCH")
        if type(artifact.get("byte_length")) is not int:
            failures.append("R23D74_TRACE_BYTE_LENGTH_NOT_INTEGER")
    if failures:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_TRACE_RETENTION_RECEIPT_INVALID:"
            + ",".join(failures),
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt


class _UnconditionalStartupRampRun:
    """Compose the closed R38 ramp without importing a development campaign."""

    def __init__(self) -> None:
        self.reset()

    def reset(self) -> None:
        self.pending_support: dict[int, int] = {}
        self.rows: dict[int, dict[str, Any]] = {}
        self.composition_step_count = 0
        self.ramped_step_count = 0
        self.exact_zero_scale_step_count = 0
        self.exact_unity_scale_step_count = 0
        self.maximum_absolute_residual_rad_s = 0.0
        self.minimum_observed_support_count = len(production.LIMB_IDS)

    def capture_contacts(
        self,
        semantic_step: int,
        contacts: Mapping[str, bool],
    ) -> None:
        if semantic_step in self.pending_support or semantic_step in self.rows:
            raise RuntimeError("QSDK_R23D74_MJC_CONTACT_CAPTURE_DUPLICATE")
        if set(contacts) != set(production.LIMB_IDS):
            raise RuntimeError("QSDK_R23D74_MJC_CONTACT_CAPTURE_INVALID")
        support_count = sum(bool(contacts[item]) for item in production.LIMB_IDS)
        self.pending_support[semantic_step] = support_count
        self.minimum_observed_support_count = min(
            self.minimum_observed_support_count,
            support_count,
        )

    def compose(self, actuation: dict[str, Any]) -> list[dict[str, Any]]:
        semantic_step = int(actuation.get("semantic_step", -1))
        commands = actuation.get("ordered_commands")
        try:
            support_count = self.pending_support.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D74_MJC_CONTACT_CAPTURE_MISSING") from error
        if (
            semantic_step in self.rows
            or not isinstance(commands, list)
            or len(commands) != design.ACTUATOR_COUNT
            or production._RUNTIME.controller_commands is None
            or semantic_step in production._RUNTIME.controller_commands
        ):
            raise RuntimeError("QSDK_R23D74_MJC_RAMP_STEP_BINDING_INVALID")
        production._RUNTIME.controller_commands[semantic_step] = copy.deepcopy(commands)
        scale = ramp_design.startup_velocity_scale(semantic_step)
        residuals: list[dict[str, Any]] = []
        maximum = 0.0
        for command in commands:
            actuator_id = command.get("actuator_id")
            legacy_velocity = float(
                command.get("target_velocity_rad_s", float("nan"))
            )
            portable_canonical = -legacy_velocity
            delta = portable_canonical * (scale - 1.0)
            if not isinstance(actuator_id, str) or not all(
                math.isfinite(value) for value in (legacy_velocity, delta)
            ):
                raise RuntimeError("QSDK_R23D74_MJC_RAMP_NONFINITE")
            maximum = max(maximum, abs(delta))
            residuals.append(
                {
                    "schema_version": "sporespore_canonical_velocity_residual_v1",
                    "actuator_id": actuator_id,
                    "canonical_velocity_delta_rad_s": delta,
                    "command_not_measurement": True,
                    "physical_acceptance_authority": False,
                }
            )
        self.rows[semantic_step] = {
            "startup_ramp_id": design.MUJOCO_STARTUP_RAMP_ID,
            "startup_transform_id": design.MUJOCO_STARTUP_RAMP_ID,
            "startup_policy": "unconditional_one_cycle",
            "startup_velocity_scale": scale,
            "startup_ramp_active": scale < 1.0,
            "startup_ramp_triggered": False,
            "startup_ramp_trigger_step": None,
            "startup_probe_minimum_support_count": support_count,
            "observed_support_count": support_count,
            "startup_ramp_residual_count": len(residuals),
            "startup_ramp_maximum_absolute_residual_rad_s": maximum,
            "startup_transform_residual_count": len(residuals),
            "startup_transform_maximum_absolute_residual_rad_s": maximum,
        }
        self.composition_step_count += 1
        self.ramped_step_count += int(scale < 1.0)
        self.exact_zero_scale_step_count += int(scale == 0.0)
        self.exact_unity_scale_step_count += int(scale == 1.0)
        self.maximum_absolute_residual_rad_s = max(
            self.maximum_absolute_residual_rad_s,
            maximum,
        )
        return residuals

    def trace_fields(self, semantic_step: int) -> dict[str, Any]:
        try:
            return self.rows.pop(semantic_step)
        except KeyError as error:
            raise RuntimeError("QSDK_R23D74_MJC_RAMP_TRACE_BINDING_INVALID") from error

    def summary(self) -> dict[str, Any]:
        exact = self.composition_step_count == design.CONTROLLER_STEPS
        return {
            "startup_ramp_id": design.MUJOCO_STARTUP_RAMP_ID,
            "startup_transform_id": design.MUJOCO_STARTUP_RAMP_ID,
            "startup_policy": "unconditional_one_cycle",
            "startup_ramp_step_count": ramp_design.STARTUP_RAMP_STEPS,
            "startup_ramp_triggered": False,
            "startup_ramp_trigger_step": None,
            "startup_probe_minimum_support_count": self.minimum_observed_support_count,
            "startup_ramp_composition_step_count": self.composition_step_count,
            "startup_ramp_active_step_count": self.ramped_step_count,
            "startup_ramp_exact_zero_scale_step_count": (
                self.exact_zero_scale_step_count
            ),
            "startup_ramp_exact_unity_scale_step_count": (
                self.exact_unity_scale_step_count
            ),
            "maximum_absolute_startup_ramp_residual_rad_s": (
                self.maximum_absolute_residual_rad_s
            ),
            "startup_ramp_composition_integrity_passed": (
                exact and not self.pending_support and not self.rows
            ),
            "startup_transform_composition_integrity_passed": (
                exact and not self.pending_support and not self.rows
            ),
        }


def _measurement_plan() -> Any:
    return production._core.evidence_window_forward_displacement_measurement_origin_plan(
        design.MEASUREMENT_ORIGIN_SEMANTIC_STEP
    )


def _measurement_origin_preflight() -> dict[str, Any]:
    value = production._core.run_forward_displacement_measurement_origin_preflight(
        _measurement_plan(),
        controller_steps=design.CONTROLLER_STEPS,
    )
    origin = value.get("measurement_origin", {})
    if (
        origin.get("policy_id") != design.MEASUREMENT_ORIGIN_POLICY_ID
        or origin.get("semantic_step") != design.MEASUREMENT_ORIGIN_SEMANTIC_STEP
        or origin.get("captured_before_controller_step") is not True
        or origin.get("task_frame_reanchors_change_measurement_origin") is not False
        or value.get("model_construction_count") != 0
        or value.get("world_attempt_count") != 0
        or value.get("world_build_count") != 0
    ):
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_MEASUREMENT_ORIGIN_PREFLIGHT_INVALID"
        )
    return value


def _startup_ramp_preflight() -> dict[str, Any]:
    steps = (0, 1, ramp_design.STARTUP_RAMP_STEPS - 1, ramp_design.STARTUP_RAMP_STEPS)
    scales = {str(step): ramp_design.startup_velocity_scale(step) for step in steps}
    exact = (
        ramp_design.STARTUP_RAMP_ID == design.MUJOCO_STARTUP_RAMP_ID
        and ramp_design.STARTUP_RAMP_STEPS == design.MUJOCO_STARTUP_RAMP_STEP_COUNT
        and scales["0"] == 0.0
        and 0.0 < scales["1"] < 1.0
        and scales[str(ramp_design.STARTUP_RAMP_STEPS - 1)] == 1.0
        and scales[str(ramp_design.STARTUP_RAMP_STEPS)] == 1.0
        and all(math.isfinite(value) for value in scales.values())
    )
    if not exact:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_STARTUP_RAMP_PREFLIGHT_INVALID"
        )
    return {
        "schema_version": "sporespore_qsdk_r23d74_mujoco_startup_ramp_preflight_v1",
        "startup_ramp_id": design.MUJOCO_STARTUP_RAMP_ID,
        "startup_policy": "unconditional_one_cycle",
        "startup_ramp_step_count": design.MUJOCO_STARTUP_RAMP_STEP_COUNT,
        "sampled_scales": scales,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
    }


def _r23d74_core_preflight_bridge(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    **kwargs: Any,
) -> dict[str, Any]:
    plan = kwargs.get("forward_displacement_measurement_origin_plan")
    if plan is not None and (
        getattr(plan, "policy_id", None) != design.MEASUREMENT_ORIGIN_POLICY_ID
        or getattr(plan, "semantic_step", None)
        != design.MEASUREMENT_ORIGIN_SEMANTIC_STEP
    ):
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_MEASUREMENT_ORIGIN_PLAN_INVALID"
        )
    return production.run_preflight(
        stage_id,
        onset_id,
        CAMPAIGN_SEED,
        PROFILE_ID,
        arm_id,
    )


def _r23d74_core_run_physical(
    stage_id: str,
    onset_id: str,
    arm_id: str,
    source_commit: str,
    **kwargs: Any,
) -> dict[str, Any]:
    if kwargs.get("forward_displacement_measurement_origin_plan") is not None:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_DUPLICATE_MEASUREMENT_ORIGIN_PLAN"
        )
    return _INHERITED_CORE_RUN_PHYSICAL(
        stage_id,
        onset_id,
        arm_id,
        source_commit,
        forward_displacement_measurement_origin_plan=_measurement_plan(),
    )


def _configure_shared_kernel() -> None:
''',
    )
    text = _replace_exact(
        text,
        '''    production._retain_trace = _retain_trace

    production._design.CAMPAIGN_ID = CAMPAIGN_ID
''',
        '''    production._retain_trace = _retain_trace
    production._RAMP = _UnconditionalStartupRampRun()
    production.public_design.STARTUP_TRANSFORM_ID = design.MUJOCO_STARTUP_RAMP_ID

    production._design.CAMPAIGN_ID = CAMPAIGN_ID
''',
    )
    text = _replace_exact(
        text,
        '''        "run_preflight": production._inherited_physical_entry_preflight_bridge,
    }
''',
        '''        "run_preflight": _r23d74_core_preflight_bridge,
        "run_physical": _r23d74_core_run_physical,
    }
''',
    )
    text = _replace_exact(
        text,
        '''        gate_id=GATE_ID,
        stage_id=STAGE_ID,
''',
        '''        gate_id=GATE_ID,
        question_class="finite_decision",
        stage_id=STAGE_ID,
''',
    )
    text = _replace_exact(
        text,
        '''        if arguments.command == "preflight":
            value = production.run_preflight(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
            )
            marker = "QSDK_R23D74_MUJOCO_PREFLIGHT "
''',
        '''        if arguments.command == "preflight":
            value = production.run_preflight(
                arguments.stage,
                arguments.onset,
                arguments.campaign_seed,
                arguments.profile,
                arguments.arm,
            )
            value.update(
                question_class="finite_decision",
                measurement_origin_preflight=_measurement_origin_preflight(),
                unconditional_startup_ramp_preflight=_startup_ramp_preflight(),
                measurement_origin_policy_id=design.MEASUREMENT_ORIGIN_POLICY_ID,
                measurement_origin_semantic_step=(
                    design.MEASUREMENT_ORIGIN_SEMANTIC_STEP
                ),
                startup_ramp_id=design.MUJOCO_STARTUP_RAMP_ID,
                startup_ramp_step_count=design.MUJOCO_STARTUP_RAMP_STEP_COUNT,
                model_construction_count=0,
                world_attempt_count=0,
                world_build_count=0,
                solver_step_count=0,
                physical_acceptance_authority=False,
            )
            marker = "QSDK_R23D74_MUJOCO_PREFLIGHT "
''',
    )
    text = _replace_exact(
        text,
        '''    for root_key in (
        "model_construction_count",
''',
        '''    origin = terminal.get("forward_displacement_measurement_origin", {})
    measurements = terminal.get("measurements", {})
    execution = terminal.get("execution", {})
    artifact = terminal.get("trace_artifact", {})
    exact = (
        terminal.get("question_class") == "finite_decision"
        and origin.get("policy_id") == design.MEASUREMENT_ORIGIN_POLICY_ID
        and origin.get("semantic_step") == design.MEASUREMENT_ORIGIN_SEMANTIC_STEP
        and origin.get("captured_before_controller_step") is True
        and origin.get("task_frame_reanchors_change_measurement_origin") is False
        and measurements.get("startup_ramp_id") == design.MUJOCO_STARTUP_RAMP_ID
        and measurements.get("startup_policy") == "unconditional_one_cycle"
        and measurements.get("startup_ramp_step_count")
        == design.MUJOCO_STARTUP_RAMP_STEP_COUNT
        and execution.get("startup_ramp_composition_integrity_passed") is True
        and execution.get("startup_transform_composition_integrity_passed") is True
        and artifact.get("trace_transport_id") == evaluator.TRACE_TRANSPORT_ID
        and artifact.get("trace_transport_engine_id") == ENGINE_ID
        and artifact.get("canonical_ndjson") is True
        and artifact.get("full_precision") is True
        and type(artifact.get("byte_length")) is int
    )
    if not exact:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D74_MJC_SUCCESS_TERMINAL_CONTRACT_INVALID",
            world_attempt_count=1,
            world_build_count=1,
            terminal_receipt=terminal,
        )
    for root_key in (
        "model_construction_count",
''',
    )
    return text


def _rapier_route() -> str:
    text = _common("sdk/adapters/rapier/src/qsdk_r23d71_turning_route.rs")
    text = _replace_exact(
        text,
        '''const IMMEDIATE_BASE_RAW: &str = include_str!(
    "../../../turning/r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json"
);
const IMMEDIATE_BASE_PATH: &str = "sdk/turning/r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json";
''',
        "",
    )
    text = _replace_section(
        text,
        "fn normalize_terminal(mut value: Value, arm_id: &str, source_commit: &str, report: bool) -> Value {\n",
        "pub fn run_qsdk_r23d74_rapier_preflight(\n",
        '''fn normalize_terminal(mut value: Value, arm_id: &str, source_commit: &str, report: bool) -> Value {
    let Some(object) = value.as_object_mut() else {
        return failure(
            "QSDK_R23D74_RAP_PHYSICAL_TERMINAL_NOT_OBJECT",
            arm_id,
            Some(source_commit),
            0,
            0,
            0,
        );
    };
    if let Some(transport) = object
        .get_mut("trace_transport")
        .and_then(Value::as_object_mut)
    {
        transport.insert(
            "trace_transport_id".to_owned(),
            Value::String(R23D74_TRACE_TRANSPORT_ID.to_owned()),
        );
    }
    let artifact = object.get("trace_artifact").cloned().unwrap_or(Value::Null);
    let origin = object
        .get("forward_displacement_measurement_origin")
        .cloned()
        .unwrap_or(Value::Null);
    let contract_exact = !report
        || (artifact["trace_transport_id"] == R23D74_TRACE_TRANSPORT_ID
            && artifact["trace_transport_engine_id"] == R23D74_ENGINE_ID
            && artifact["canonical_ndjson"] == true
            && artifact["full_precision"] == true
            && artifact["byte_length"].as_u64().is_some()
            && origin["policy_id"] == "evidence_window_start_semantic_step_v1"
            && origin["semantic_step"] == 472
            && origin["captured_before_controller_step"] == true
            && origin["task_frame_reanchors_change_measurement_origin"] == false);
    let normalized_report = report && contract_exact;
    object.insert(
        "schema_version".to_owned(),
        Value::String(
            (if normalized_report {
                REPORT_SCHEMA
            } else {
                FAILURE_SCHEMA
            })
            .to_owned(),
        ),
    );
    object.insert(
        "campaign_id".to_owned(),
        Value::String(R23D74_CAMPAIGN_ID.to_owned()),
    );
    object.insert(
        "gate_id".to_owned(),
        Value::String(R23D74_GATE_ID.to_owned()),
    );
    object.insert(
        "question_class".to_owned(),
        Value::String("finite_decision".to_owned()),
    );
    object.insert(
        "stage_id".to_owned(),
        Value::String(R23D74_STAGE_ID.to_owned()),
    );
    object.insert("cell_id".to_owned(), Value::String(exact_cell_id(arm_id)));
    object.insert(
        "engine_id".to_owned(),
        Value::String(R23D74_ENGINE_ID.to_owned()),
    );
    object.insert(
        "campaign_seed".to_owned(),
        Value::from(R23D74_CAMPAIGN_SEED),
    );
    object.insert(
        "profile_id".to_owned(),
        Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned()),
    );
    object.insert(
        "profile_sha256".to_owned(),
        Value::String(R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned()),
    );
    object.insert(
        "host_mapping_id".to_owned(),
        Value::String(HOST_MAPPING_ID.to_owned()),
    );
    object.insert("arm_id".to_owned(), Value::String(arm_id.to_owned()));
    object.insert(
        "turn_heading_offset_rad".to_owned(),
        arm_heading_offset(arm_id),
    );
    object.insert(
        "source_commit".to_owned(),
        Value::String(source_commit.to_owned()),
    );
    object.insert("claims".to_owned(), false_claims());
    object.insert(
        "physical_acceptance_authority".to_owned(),
        Value::Bool(false),
    );
    if report && !contract_exact {
        object.insert(
            "failure_stage".to_owned(),
            Value::String("settlement_complete".to_owned()),
        );
        object.insert(
            "failure_code".to_owned(),
            Value::String("QSDK_R23D74_RAP_SUCCESS_TERMINAL_CONTRACT_INVALID".to_owned()),
        );
        object.insert("model_construction_count".to_owned(), Value::from(1));
        object.insert("world_attempt_count".to_owned(), Value::from(1));
        object.insert("world_build_count".to_owned(), Value::from(1));
    } else if normalized_report {
        for root_key in [
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "world_build_count_exact",
            "world_build_count_lower_bound",
            "world_build_count_upper_bound",
        ] {
            object.remove(root_key);
        }
    } else {
        object
            .entry("model_construction_count".to_owned())
            .or_insert(Value::from(0));
        object
            .entry("world_attempt_count".to_owned())
            .or_insert(Value::from(0));
        object
            .entry("world_build_count".to_owned())
            .or_insert(Value::from(0));
    }
    value
}

''',
    )
    text = _replace_section(
        text,
        "pub fn run_qsdk_r23d74_rapier_preflight(\n",
        "pub fn run_qsdk_r23d74_rapier_authorization_preflight(\n",
        '''pub fn run_qsdk_r23d74_rapier_preflight(
    stage_id: &str,
    onset_id: &str,
    campaign_seed: u64,
    profile_id: &str,
    arm_id: &str,
) -> Result<Value, String> {
    validate_identity(stage_id, onset_id, campaign_seed, profile_id, arm_id)?;
    let implementation = implementation_contract()?;
    let (_, declaration) = read_json(
        &repo_root()?.join(PREREGISTRATION_PATH),
        "QSDK_R23D74_RAP_PREREGISTRATION_UNREADABLE",
    )?;
    let (_, inherited) = read_json(
        &repo_root()?.join(INHERITED_BEHAVIOR_PATH),
        "QSDK_R23D74_RAP_INHERITED_BEHAVIOR_UNREADABLE",
    )?;
    let kernel = run_r23d74_rapier_kernel_preflight(arm_id)?;
    let binding = resolve_production_public_profile_binding_v1()?;
    let population = &declaration["finite_population"];
    let schedule = &declaration["fixed_schedule"];
    let fixture = &declaration["seed_fixture_compilation"]["compiled_initial_perturbation"];
    let inherited_matrix = &inherited["frozen_matrix"];
    let kernel_fixture = &kernel["initial_perturbation"];
    let exact = kernel_fixture["campaign_seed"] == fixture["campaign_seed"]
        && kernel_fixture["fixture_vertical_clearance_m"]
            == fixture["fixture_vertical_clearance_m"]
        && kernel_fixture["fixture_yaw_rad"] == fixture["fixture_yaw_rad"]
        && kernel_fixture["initial_linear_velocity_world_m_s"]
            == fixture["initial_linear_velocity_world_m_s"]
        && kernel_fixture["initial_torso_angular_velocity_world_rad_s"]
            == fixture["initial_torso_angular_velocity_world_rad_s"]
        && kernel_fixture["gait_phase_offset_ticks"] == fixture["gait_phase_offset_ticks"]
        && kernel["campaign_seed"] == R23D74_CAMPAIGN_SEED
        && kernel["cell_id"] == exact_cell_id(arm_id)
        && kernel["turn_heading_offset_rad"] == arm_heading_offset(arm_id)
        && kernel["controller_step_count"] == CONTROLLER_STEPS
        && kernel["terminal_step_count"] == 0
        && kernel["turn_start_step"] == TURN_START_STEP
        && kernel["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && kernel["shared_native_kernel_reused"] == true
        && kernel["forward_displacement_measurement_origin_policy_id"]
            == "evidence_window_start_semantic_step_v1"
        && kernel["forward_displacement_measurement_origin_semantic_step"] == 472
        && kernel["forward_displacement_measurement_origin_preflight"]["world_build_count"] == 0
        && declaration["schema_version"]
            == "sporespore_qsdk_r23d74_fresh_finite_three_engine_turning_decision_v1"
        && declaration["status"]
            == "prospective_declaration_complete_implementation_pending_physical_not_authorized"
        && declaration["campaign_id"] == R23D74_CAMPAIGN_ID
        && declaration["gate_id"] == R23D74_GATE_ID
        && declaration["question_class"] == "finite_decision"
        && declaration["not_development_work"] == true
        && declaration["not_superiority_work"] == true
        && declaration["not_equivalence_or_non_inferiority_work"] == true
        && declaration["physical_authorization"]["physical_execution_authorized"] == false
        && declaration["physical_authorization"]["physical_acceptance_authority"] == false
        && declaration["claims"]["implementation_complete"] == false
        && declaration["claims"]["zero_world_gate_passed"] == false
        && declaration["claims"]["physical_campaign_opened"] == false
        && population["engine_order"] == json!(["godot_jolt", "rapier_parry", "mujoco"])
        && population["arm_order"]
            == json!(["reference_zero", "positive_heading", "negative_heading"])
        && population["arm_heading_offsets_rad"]
            == json!({"reference_zero": 0.0, "positive_heading": 0.2, "negative_heading": -0.2})
        && population["ordered_cell_ids"] == json!(expected_cell_ids())
        && population["declared_engine_count"] == 3
        && population["declared_arm_count"] == 3
        && population["declared_cell_count"] == 9
        && population["sampling_used"] == false
        && population["complete_enumeration_required"] == true
        && population["all_cells_run_regardless_of_intermediate_behavior"] == true
        && population["selective_completion_or_rerun_allowed"] == false
        && schedule["controller_semantic_step_count"] == CONTROLLER_STEPS
        && schedule["turn_start_semantic_step"] == TURN_START_STEP
        && schedule["turn_end_semantic_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && schedule["reference_recovery_step_count"]
            == RECOVERY_END_STEP_EXCLUSIVE - TURN_END_STEP_EXCLUSIVE
        && schedule["forward_displacement_measurement_origin_policy_id"]
            == "evidence_window_start_semantic_step_v1"
        && schedule["forward_displacement_measurement_origin_semantic_step"] == 472
        && inherited_matrix["controller_step_count"] == CONTROLLER_STEPS
        && inherited_matrix["turn_start_step"] == TURN_START_STEP
        && inherited_matrix["turn_end_step_exclusive"] == TURN_END_STEP_EXCLUSIVE
        && inherited_matrix["recovery_duration_steps"]
            == RECOVERY_END_STEP_EXCLUSIVE - TURN_END_STEP_EXCLUSIVE
        && binding.ordered_mappings.len() == 8
        && binding.resolution_receipt["requested_profile_id"]
            == R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        && binding.host_mapping_receipt["host_mapping_id"] == HOST_MAPPING_ID;
    if !exact {
        return Err("QSDK_R23D74_RAP_PREFLIGHT_BINDING_INVALID".to_owned());
    }
    let dependency_count = implementation["dependency_digests"]
        .as_object()
        .map_or(0, Map::len);
    Ok(json!({
        "schema_version": PREFLIGHT_SCHEMA,
        "ok": true,
        "failure_code": "",
        "campaign_id": R23D74_CAMPAIGN_ID,
        "gate_id": R23D74_GATE_ID,
        "question_class": "finite_decision",
        "stage_id": R23D74_STAGE_ID,
        "cell_id": exact_cell_id(arm_id),
        "engine_id": R23D74_ENGINE_ID,
        "campaign_seed": R23D74_CAMPAIGN_SEED,
        "profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "host_mapping_id": HOST_MAPPING_ID,
        "arm_id": arm_id,
        "turn_heading_offset_rad": arm_heading_offset(arm_id),
        "controller_step_count": CONTROLLER_STEPS,
        "turn_start_step": TURN_START_STEP,
        "turn_end_step_exclusive": TURN_END_STEP_EXCLUSIVE,
        "recovery_end_step_exclusive": RECOVERY_END_STEP_EXCLUSIVE,
        "measurement_origin_policy_id": "evidence_window_start_semantic_step_v1",
        "measurement_origin_semantic_step": 472,
        "measurement_origin_preflight":
            kernel["forward_displacement_measurement_origin_preflight"].clone(),
        "expected_segment_counts": {
            "reference_warmup": 600,
            "commanded_turn": 1200,
            "reference_recovery": 600,
            "reference_continuation": 592,
        },
        "implementation_dependency_count": dependency_count,
        "public_profile_force_plan_actuator_count": binding.ordered_mappings.len(),
        "public_profile_route_compiled": true,
        "fresh_perturbation_compiled": true,
        "shared_native_kernel_reused": true,
        "physical_worker_implemented": true,
        "returned_before_model": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": false,
        "physical_acceptance_authority": false,
    }))
}

''',
    )
    text = _replace_exact(
        text,
        '''            "schema_version": "sporespore_qsdk_r23d70_engine_cell_report_v1",
            "execution": {
''',
        '''            "schema_version": "sporespore_qsdk_r23d74_engine_cell_report_v1",
            "trace_artifact": {
                "trace_transport_id": R23D74_TRACE_TRANSPORT_ID,
                "trace_transport_engine_id": R23D74_ENGINE_ID,
                "canonical_ndjson": true,
                "full_precision": true,
                "byte_length": 0,
            },
            "forward_displacement_measurement_origin": {
                "policy_id": "evidence_window_start_semantic_step_v1",
                "semantic_step": 472,
                "captured_before_controller_step": true,
                "task_frame_reanchors_change_measurement_origin": false,
            },
            "execution": {
''',
    )
    return _rustfmt(text)


def _rapier_binary() -> str:
    return _rustfmt(
        _common("sdk/adapters/rapier/src/bin/qsdk_r23d71_turning_route.rs")
    )


def _rapier_kernel() -> str:
    relative = "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    text = _source(relative)

    r23d71_constants = _section(
        text,
        "pub const R23D71_CAMPAIGN_ID: &str =\n",
        "pub(crate) const TURNING_ROUTE_ID: &str =\n",
    )
    r23d74_constants = _fixture(_identity(r23d71_constants))

    r23d71_trace = _section(
        text,
        "pub(crate) fn r23d71_project_production_trace_row(\n",
        "fn r23d68_retain_trace(\n",
    )
    r23d74_trace = _fixture(_identity(r23d71_trace))

    r23d71_retention = _section(
        text,
        "fn r23d71_retain_trace(\n",
        "fn turning_route_retain_trace(\n",
    )
    r23d74_retention = _fixture(_identity(r23d71_retention))

    r23d71_core = _section(
        text,
        "pub(crate) fn run_r23d71_rapier_physical_core(\n",
        "fn run_r23d27_rapier_physical_world(\n",
    )
    r23d74_core = _fixture(_identity(r23d71_core))
    r23d74_core = _replace_exact(
        r23d74_core,
        '''        || plan.r23d70_route
        || !plan.r23d74_route
''',
        '''        || plan.r23d70_route
        || plan.r23d71_route
        || !plan.r23d74_route
        || plan.forward_displacement_measurement_origin
            != (ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            })
''',
    )
    r23d74_core = _replace_exact(
        r23d74_core,
        '''    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d74_rapier_shared_kernel_preflight_v1",
''',
        '''    let measurement_origin_preflight =
        run_forward_displacement_measurement_origin_preflight(
            EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            R23D27_CONTROLLER_STEPS,
        )?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d74_rapier_shared_kernel_preflight_v1",
''',
    )
    r23d74_core = _replace_exact(
        r23d74_core,
        '''        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "initial_perturbation": {
''',
        '''        "turn_end_step_exclusive": plan.turn_end_step_exclusive,
        "forward_displacement_measurement_origin_policy_id":
            EVIDENCE_WINDOW_MEASUREMENT_ORIGIN_POLICY_ID,
        "forward_displacement_measurement_origin_semantic_step":
            EVIDENCE_WINDOW_START_SEMANTIC_STEP,
        "forward_displacement_measurement_origin_preflight": measurement_origin_preflight,
        "initial_perturbation": {
''',
    )

    r23d71_plan = _section(
        text,
        "    const R23D71_ROUTE: Self = Self {\n",
        "    const fn with_evidence_window_measurement_origin",
    )
    r23d74_plan = _identity(r23d71_plan)
    r23d74_plan = _replace_exact(
        r23d74_plan,
        "        r23d74_route: true,\n",
        "        r23d71_route: false,\n        r23d74_route: true,\n",
    )
    r23d74_plan = _replace_exact(
        r23d74_plan,
        '''        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::LegacyMutableTaskFrame,
''',
        '''        forward_displacement_measurement_origin:
            ForwardDisplacementMeasurementOriginPlan::EvidenceWindowStart {
                semantic_step: EVIDENCE_WINDOW_START_SEMANTIC_STEP,
            },
''',
    )

    text = _replace_exact(
        text,
        r23d71_constants + "pub(crate) const TURNING_ROUTE_ID: &str =\n",
        r23d71_constants + r23d74_constants + "pub(crate) const TURNING_ROUTE_ID: &str =\n",
    )
    text = _replace_exact(
        text,
        r23d71_trace + "fn r23d68_retain_trace(\n",
        r23d71_trace + r23d74_trace + "fn r23d68_retain_trace(\n",
    )
    text = _replace_exact(
        text,
        r23d71_retention + "fn turning_route_retain_trace(\n",
        r23d71_retention + r23d74_retention + "fn turning_route_retain_trace(\n",
    )
    text = _replace_exact(
        text,
        r23d71_core + "fn run_r23d27_rapier_physical_world(\n",
        r23d71_core + r23d74_core + "fn run_r23d27_rapier_physical_world(\n",
    )

    text = _replace_exact(
        text,
        "    r23d71_route: bool,\n",
        "    r23d71_route: bool,\n    r23d74_route: bool,\n",
    )
    text = _replace_exact(
        text,
        "        r23d71_route: false,\n",
        "        r23d71_route: false,\n        r23d74_route: false,\n",
        count=7,
    )
    text = _replace_exact(
        text,
        "        r23d71_route: true,\n",
        "        r23d71_route: true,\n        r23d74_route: false,\n",
    )
    text = _replace_first_exact(
        text,
        "        || plan.r23d71_route\n",
        "        || plan.r23d71_route\n        || plan.r23d74_route\n",
        observed_count=4,
        replacement_count=3,
    )
    text = _replace_exact(
        text,
        "    const fn with_evidence_window_measurement_origin",
        r23d74_plan + "    const fn with_evidence_window_measurement_origin",
    )

    text = _replace_exact(
        text,
        '''        } else if execution_plan.r23d71_route {
            r23d71_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
        '''        } else if execution_plan.r23d71_route {
            r23d71_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d74_route {
            r23d74_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
    )
    text = _replace_exact(
        text,
        '''    } else if execution_plan.r23d71_route {
        r23d71_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
        '''    } else if execution_plan.r23d71_route {
        r23d71_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d74_route {
        r23d74_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
    )
    return _rustfmt(text)


def _rapier_lib() -> str:
    text = _source("sdk/adapters/rapier/src/lib.rs")
    text = _replace_exact(
        text,
        "mod qsdk_r23d71_turning_route;\n",
        "mod qsdk_r23d71_turning_route;\nmod qsdk_r23d74_receipt_contract;\nmod qsdk_r23d74_turning_route;\n",
    )
    text = _replace_exact(
        text,
        '''pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D71_CAMPAIGN_ID, R23D71_CAMPAIGN_SEED, R23D71_GATE_ID, R23D71_STAGE_ID,
};
''',
        '''pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D71_CAMPAIGN_ID, R23D71_CAMPAIGN_SEED, R23D71_GATE_ID, R23D71_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D74_CAMPAIGN_ID, R23D74_CAMPAIGN_SEED, R23D74_GATE_ID, R23D74_STAGE_ID,
};
''',
    )
    text = _replace_exact(
        text,
        '''pub use qsdk_r23d71_turning_route::{
    run_qsdk_r23d71_rapier_authorization_preflight, run_qsdk_r23d71_rapier_complete_row_ghost,
    run_qsdk_r23d71_rapier_physical, run_qsdk_r23d71_rapier_preflight,
    run_qsdk_r23d71_success_terminal_projection_ghost,
};
''',
        '''pub use qsdk_r23d71_turning_route::{
    run_qsdk_r23d71_rapier_authorization_preflight, run_qsdk_r23d71_rapier_complete_row_ghost,
    run_qsdk_r23d71_rapier_physical, run_qsdk_r23d71_rapier_preflight,
    run_qsdk_r23d71_success_terminal_projection_ghost,
};
pub use qsdk_r23d74_turning_route::{
    run_qsdk_r23d74_rapier_authorization_preflight, run_qsdk_r23d74_rapier_complete_row_ghost,
    run_qsdk_r23d74_rapier_physical, run_qsdk_r23d74_rapier_preflight,
    run_qsdk_r23d74_success_terminal_projection_ghost,
};
''',
    )
    return _rustfmt(text)


def _supervisor() -> str:
    text = _common("sdk/run_qsdk_r23d71_supervisor.ps1")
    text = _replace_exact(
        text,
        '''$campaignId = (
    "QSDK-R23D74-SUCCESS-TERMINAL-PROJECTION-REPAIRED-" +
    "THREE-ENGINE-TURNING-VALIDATION"
)
''',
        '''$campaignId = "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
''',
    )
    text = _replace_exact(
        text,
        '''$preregistrationPath = Join-Path $turningRoot (
    "r23d74_success_terminal_projection_repaired_three_engine_turning_" +
    "preregistration_v1.json"
)
''',
        '''$preregistrationPath = Join-Path $turningRoot (
    "r23d74_fresh_finite_three_engine_turning_decision_v1.json"
)
''',
    )
    text = _replace_exact(
        text,
        '''                question_class = "equivalence_non_inferiority"
''',
        '''                question_class = "finite_decision"
''',
    )
    text = _replace_exact(
        text,
        '''            work_class = "development_then_complete_population_equivalence_non_inferiority"
''',
        '''            work_class = "zero_world_finite_decision_route_qualification"
''',
    )
    return text


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk/turning/r23d74_production_route_runtime.py", _runtime),
    (
        ROOT / "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py",
        _evaluator,
    ),
    (ROOT / "sdk/turning/r23d74_receipt_contract.py", _receipt_python),
    (ROOT / "sdk/turning/r23d74_receipt_contract.gd", _receipt_godot),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d74_receipt_contract.rs",
        _receipt_rust,
    ),
    (ROOT / "tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd", _godot_worker),
    (
        ROOT
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d74_turning_route.py",
        _mujoco_worker,
    ),
    (ROOT / "sdk/adapters/rapier/src/qsdk_r23d74_turning_route.rs", _rapier_route),
    (
        ROOT / "sdk/adapters/rapier/src/bin/qsdk_r23d74_turning_route.rs",
        _rapier_binary,
    ),
    (
        ROOT
        / "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
        _rapier_kernel,
    ),
    (ROOT / "sdk/adapters/rapier/src/lib.rs", _rapier_lib),
    (ROOT / "sdk/run_qsdk_r23d74_supervisor.ps1", _supervisor),
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
            raise MaterializationError(f"R23D74_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D74 native bindings {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
