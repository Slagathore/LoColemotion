#!/usr/bin/env python3
"""Engine-aware native startup-trace/evaluator conformance for QSDK-R23D75.

R23D75 is outcome-exposed, zero-world software development.  It leaves the
consumed R23D74 campaign, its native rows, its evaluator and its interpretation
immutable.  This successor selects one of the two already-observed startup
contracts from the declared native engine identity, then reuses the accepted
retained-trace algorithms process-locally.

The public preflight is deliberately compact.  The optional retained replay
reads the exact nine R23D74 traces and opens no model or physics world.  Neither
path computes or repairs an R23D74 turning result.
"""

from __future__ import annotations

import argparse
import copy
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path
import sys
from threading import RLock
from typing import Any, Callable, Mapping, Sequence

import r23d38_mujoco_startup_ramp_stabilization as unconditional_design
import r23d58_godot_cap_source_factorial_evaluator as accepted
import r23d60_godot_fixture_knee_held_out_turning_validation as support_design
import r23d65_selected_profile_three_engine_turning_validation_evaluator as inherited
import r23d74_production_route_runtime as design
import r23d74_production_route_three_engine_turning_evaluator as r23d74_evaluator


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent.parent
DECLARATION_PATH = ROOT / "r23d75_native_startup_trace_evaluator_conformance_v1.json"
R23D74_CLOSURE_PATH = (
    ROOT / "r23d74_production_route_three_engine_turning_validation_closure_v1.json"
)

CAMPAIGN_ID = "QSDK-R23D75-NATIVE-STARTUP-TRACE-EVALUATOR-CONFORMANCE-DEVELOPMENT"
GATE_ID = "QSDK-R23D75"
QUESTION_CLASS = "development"
DECLARATION_SCHEMA = (
    "sporespore_qsdk_r23d75_native_startup_trace_evaluator_conformance_"
    "development_v1"
)
TRACE_SUMMARY_SCHEMA = "sporespore_qsdk_r23d75_native_trace_summary_v1"
PREFLIGHT_SCHEMA = "sporespore_qsdk_r23d75_zero_world_preflight_v1"
REPLAY_SCHEMA = "sporespore_qsdk_r23d75_r23d74_retained_trace_replay_v1"
R23D74_CLOSURE_SHA256 = (
    "sha256:912d930498e56f6997f75aa1f97d99653d22d235fd511b3c180b26a0521f07d3"
)
SUPPORT_LOSS_STARTUP_ID = support_design.STARTUP_TRANSFORM_ID
UNCONDITIONAL_STARTUP_ID = unconditional_design.STARTUP_RAMP_ID
STARTUP_STEP_COUNT = unconditional_design.STARTUP_RAMP_STEPS
COMPACT_LAST_STEP = 360
SAMPLED_BOUNDARY_STEPS = (0, 1, 3, 4, 358, 359, 360)

FALSE_CLAIMS = {
    "r23d74_result_repaired": False,
    "finite_three_engine_turning": False,
    "portable_basic_turning": False,
    "q_sdk_r23_satisfied": False,
    "cross_engine_equivalence": False,
    "population_robustness": False,
    "arbitrary_quadruped_coverage": False,
    "prone_to_standing": False,
    "release_authorized": False,
    "physical_acceptance_authority": False,
}


class R23D75ConformanceError(RuntimeError):
    """The declaration, binding, compact control or retained replay is invalid."""


class StartupBindingError(ValueError):
    """A startup transform was requested or stepped outside its exact contract."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D75ConformanceError(code)


def raw_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return "sha256:" + digest.hexdigest()


def _finite(value: Any) -> bool:
    return (
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value))
    )


@dataclass
class UnconditionalOneCycleStartup:
    """Evaluator state matching the exact R23D74 MuJoCo trace fields."""

    next_semantic_step: int = 0
    trigger_step: int | None = None
    minimum_probe_support_count: int = len(support_design.LIMB_IDS)

    def step(
        self,
        semantic_step: int,
        ordered_foot_contacts_before: Mapping[str, bool],
    ) -> dict[str, object]:
        if (
            not isinstance(semantic_step, int)
            or isinstance(semantic_step, bool)
            or semantic_step != self.next_semantic_step
            or not 0 <= semantic_step < design.CONTROLLER_STEPS
        ):
            raise StartupBindingError(
                f"R23D75_UNCONDITIONAL_SEMANTIC_STEP_INVALID:{semantic_step}:"
                f"expected_{self.next_semantic_step}"
            )
        contacts = ordered_foot_contacts_before
        if not isinstance(contacts, Mapping) or set(contacts) != set(
            support_design.LIMB_IDS
        ):
            raise StartupBindingError("R23D75_UNCONDITIONAL_CONTACT_IDENTITY_INVALID")
        if any(type(contacts[limb_id]) is not bool for limb_id in support_design.LIMB_IDS):
            raise StartupBindingError("R23D75_UNCONDITIONAL_CONTACT_VALUE_INVALID")

        support_count = sum(int(contacts[limb_id]) for limb_id in support_design.LIMB_IDS)
        self.minimum_probe_support_count = min(
            self.minimum_probe_support_count,
            support_count,
        )
        scale = unconditional_design.startup_velocity_scale(semantic_step)
        self.next_semantic_step += 1
        return {
            "startup_transform_id": UNCONDITIONAL_STARTUP_ID,
            "startup_policy": "unconditional_one_cycle",
            "startup_velocity_scale": scale,
            "startup_ramp_active": scale < 1.0,
            "startup_ramp_triggered": False,
            "startup_ramp_trigger_step": None,
            # The native row uses this legacy field for the current row's
            # support count; the aggregate summary carries the true minimum.
            "startup_probe_minimum_support_count": support_count,
        }


@dataclass(frozen=True)
class StartupTransformSpec:
    engine_id: str
    startup_transform_id: str
    startup_ramp_id: str
    startup_policy: str
    startup_step_count: int
    trace_policy_field_required: bool
    governor_factory: Callable[[], Any]


def startup_transform_spec(engine_id: str) -> StartupTransformSpec:
    """Return the exact native transform for one declared engine, or refuse."""

    if engine_id in ("godot_jolt", "rapier_parry"):
        return StartupTransformSpec(
            engine_id=engine_id,
            startup_transform_id=SUPPORT_LOSS_STARTUP_ID,
            startup_ramp_id=SUPPORT_LOSS_STARTUP_ID,
            startup_policy="support_loss_probe_then_identity_or_one_cycle",
            startup_step_count=STARTUP_STEP_COUNT,
            trace_policy_field_required=False,
            governor_factory=support_design.SupportLossConditionedStartup,
        )
    if engine_id == "mujoco":
        return StartupTransformSpec(
            engine_id=engine_id,
            startup_transform_id=UNCONDITIONAL_STARTUP_ID,
            startup_ramp_id=UNCONDITIONAL_STARTUP_ID,
            startup_policy="unconditional_one_cycle",
            startup_step_count=STARTUP_STEP_COUNT,
            trace_policy_field_required=True,
            governor_factory=UnconditionalOneCycleStartup,
        )
    raise StartupBindingError(f"R23D75_ENGINE_ID_UNSUPPORTED:{engine_id}")


def load_declaration() -> dict[str, Any]:
    try:
        value = json.loads(DECLARATION_PATH.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise R23D75ConformanceError(
            f"R23D75_DECLARATION_UNREADABLE:{type(error).__name__}"
        ) from error

    parent = value.get("immutable_parent", {})
    question = value.get("development_question", {})
    finding = value.get("causal_finding", {})
    binding = value.get("exact_engine_startup_binding", {})
    adequacy = value.get("provenance_and_adequacy", {})
    zero_world = value.get("required_zero_world_gate", {})
    forbidden = value.get("forbidden_changes", {})
    claims = value.get("claims", {})
    next_boundary = value.get("next_boundary", {})

    expected_bindings = {
        engine_id: {
            "startup_transform_id": spec.startup_transform_id,
            "startup_ramp_id": spec.startup_ramp_id,
            "startup_policy": spec.startup_policy,
            "startup_step_count": spec.startup_step_count,
            "trace_policy_field_required": spec.trace_policy_field_required,
        }
        for engine_id in design.ENGINES
        for spec in (startup_transform_spec(engine_id),)
    }
    invalid = (
        value.get("schema_version") != DECLARATION_SCHEMA
        or value.get("status")
        != "prospective_zero_world_development_declared_implementation_pending"
        or value.get("campaign_id") != CAMPAIGN_ID
        or value.get("gate_id") != GATE_ID
        or value.get("work_id") != CAMPAIGN_ID
        or value.get("question_class") != QUESTION_CLASS
        or value.get("scientific_role")
        != "outcome_exposed_software_conformance_development"
        or value.get("physical_question_declared") is not False
        or value.get("physical_campaign_opened") is not False
        or parent.get("gate_id") != design.GATE_ID
        or parent.get("campaign_id") != design.CAMPAIGN_ID
        or parent.get("closure_path")
        != "sdk/turning/r23d74_production_route_three_engine_turning_validation_closure_v1.json"
        or parent.get("closure_raw_sha256") != R23D74_CLOSURE_SHA256
        or parent.get("seed_consumed") is not True
        or parent.get("parent_rerun_allowed") is not False
        or parent.get("parent_result_reinterpreted") is not False
        or question.get("answer_scope") != "software_and_retained_trace_conformance_only"
        or question.get("behavioral_success_question_asked") is not False
        or question.get("turning_result_computed") is not False
        or question.get("new_physical_evidence_collected") is not False
        or finding.get("finding_id")
        != "r23d74_mujoco_startup_trace_evaluator_binding_mismatch_v1"
        or finding.get("native_mujoco_startup_transform_id")
        != UNCONDITIONAL_STARTUP_ID
        or finding.get("observed_evaluator_startup_transform_id")
        != SUPPORT_LOSS_STARTUP_ID
        or finding.get("physics_failure_established") is not False
        or finding.get("threshold_or_selector_failure_established") is not False
        or finding.get("native_trace_rewrite_permitted") is not False
        or binding.get("binding_selector") != "declared_native_engine_id_only"
        or binding.get("unknown_engine_refusal_required") is not True
        or binding.get("arm_identity_may_change_binding") is not False
        or any(binding.get(engine_id) != expected for engine_id, expected in expected_bindings.items())
        or adequacy.get("threshold_provenance")
        != "no_behavior_threshold_is_introduced_or_invoked"
        or adequacy.get("equivalence_margin") is not None
        or adequacy.get("non_inferiority_margin") is not None
        or adequacy.get("cohort") != "all_nine_exact_outcome_exposed_r23d74_native_traces"
        or adequacy.get("cohort_selection")
        != "complete_enumeration_from_the_immutable_r23d74_closure"
        or adequacy.get("retained_trace_count_required") != 9
        or adequacy.get("retained_trace_count_per_engine_required") != 3
        or adequacy.get("sampling_used") is not False
        or adequacy.get("population_claim_permitted") is not False
        or not isinstance(adequacy.get("adequacy_argument"), str)
        or not adequacy.get("adequacy_argument")
        or zero_world.get("compact_startup_sequence_last_semantic_step")
        != COMPACT_LAST_STEP
        or zero_world.get("sampled_boundary_steps") != list(SAMPLED_BOUNDARY_STEPS)
        or any(
            zero_world.get(key) is not True
            for key in (
                "complete_engine_binding_enumeration_required",
                "full_support_identity_control_required",
                "probe_support_loss_trigger_control_required",
                "post_probe_support_loss_nontrigger_control_required",
                "unconditional_contact_independence_control_required",
                "cross_engine_binding_mutation_rejection_required",
                "startup_identity_scale_policy_and_shape_mutation_rejection_required",
                "all_nine_retained_native_trace_replay_required_for_closure",
            )
        )
        or zero_world.get("full_seeded_world_ghost_required") is not False
        or any(
            zero_world.get(key) != 0
            for key in (
                "model_construction_count",
                "world_attempt_count",
                "world_build_count",
                "solver_step_count",
            )
        )
        or zero_world.get("physical_execution_authorized") is not False
        or zero_world.get("physical_acceptance_authority") is not False
        or any(forbidden.get(key) is not False for key in forbidden)
        or claims != FALSE_CLAIMS
        or next_boundary.get("r23d75_closure_requires_all_declared_zero_world_controls")
        is not True
        or next_boundary.get("r23d75_closure_requires_all_nine_exact_retained_trace_replays")
        is not True
        or next_boundary.get("fresh_finite_turning_decision_requires_new_campaign_identity_and_seed")
        is not True
        or next_boundary.get("r23d74_rerun_or_selective_repair_permitted") is not False
        or next_boundary.get("physical_world_permitted_by_this_declaration") is not False
    )
    _require(not invalid, "R23D75_DECLARATION_INVALID")
    return value


def _contacts(support_count: int) -> dict[str, bool]:
    _require(
        isinstance(support_count, int)
        and not isinstance(support_count, bool)
        and 0 <= support_count <= len(support_design.LIMB_IDS),
        "R23D75_SYNTHETIC_SUPPORT_COUNT_INVALID",
    )
    return {
        limb_id: index < support_count
        for index, limb_id in enumerate(support_design.LIMB_IDS)
    }


def _compact_sequence(
    engine_id: str,
    support_count_for_step: Callable[[int], int],
) -> list[dict[str, Any]]:
    spec = startup_transform_spec(engine_id)
    governor = spec.governor_factory()
    rows: list[dict[str, Any]] = []
    for semantic_step in range(COMPACT_LAST_STEP + 1):
        contacts = _contacts(support_count_for_step(semantic_step))
        expected = governor.step(semantic_step, contacts)
        row: dict[str, Any] = {
            "semantic_step": semantic_step,
            "ordered_foot_contacts_before": contacts,
            "startup_ramp_id": spec.startup_ramp_id,
            "startup_ramp_residual_count": design.ACTUATOR_COUNT,
            "startup_transform_residual_count": design.ACTUATOR_COUNT,
            "startup_ramp_maximum_absolute_residual_rad_s": 0.0,
            "startup_transform_maximum_absolute_residual_rad_s": 0.0,
            **expected,
        }
        if engine_id == "mujoco":
            row["observed_support_count"] = sum(int(value) for value in contacts.values())
        rows.append(row)
    return rows


_SUPPORT_ONLY_FIELDS = {
    "startup_probe_active",
    "startup_probe_support_count",
    "startup_probe_complete_support_loss",
    "startup_transform_decision_locked",
    "startup_ramp_local_step",
}
_UNCONDITIONAL_ONLY_FIELDS = {
    "startup_policy",
    "startup_probe_minimum_support_count",
    "observed_support_count",
}


def validate_startup_sequence(engine_id: str, rows: Any) -> dict[str, Any]:
    """Validate the compact exact-prefix contract without constructing physics."""

    spec = startup_transform_spec(engine_id)
    failures: list[str] = []
    if not isinstance(rows, list) or len(rows) != COMPACT_LAST_STEP + 1:
        return {
            "schema_version": "sporespore_qsdk_r23d75_compact_startup_sequence_v1",
            "ok": False,
            "engine_id": engine_id,
            "failure_codes": ["R23D75_COMPACT_ROW_COUNT_INVALID"],
        }

    governor = spec.governor_factory()
    active_count = 0
    zero_count = 0
    unity_count = 0
    for semantic_step, row in enumerate(rows):
        if not isinstance(row, Mapping):
            failures.append(f"R23D75_COMPACT_ROW_INVALID:{semantic_step}")
            continue
        contacts = row.get("ordered_foot_contacts_before")
        try:
            expected = governor.step(semantic_step, contacts)
        except (TypeError, ValueError) as error:
            failures.append(
                f"R23D75_COMPACT_CONTACTS_INVALID:{semantic_step}:{type(error).__name__}"
            )
            continue
        scale = float(expected["startup_velocity_scale"])
        active_count += int(scale < 1.0)
        zero_count += int(scale == 0.0)
        unity_count += int(scale == 1.0)
        invalid = (
            row.get("semantic_step") != semantic_step
            or row.get("startup_ramp_id") != spec.startup_ramp_id
            or any(row.get(field) != value for field, value in expected.items())
            or row.get("startup_ramp_residual_count") != design.ACTUATOR_COUNT
            or row.get("startup_transform_residual_count") != design.ACTUATOR_COUNT
            or not _finite(row.get("startup_ramp_maximum_absolute_residual_rad_s"))
            or row.get("startup_transform_maximum_absolute_residual_rad_s")
            != row.get("startup_ramp_maximum_absolute_residual_rad_s")
        )
        if spec.trace_policy_field_required:
            support_count = sum(int(value) for value in contacts.values())
            invalid = invalid or (
                row.get("startup_policy") != spec.startup_policy
                or row.get("observed_support_count") != support_count
                or row.get("startup_probe_minimum_support_count") != support_count
                or any(field in row for field in _SUPPORT_ONLY_FIELDS)
            )
        else:
            invalid = invalid or any(field in row for field in _UNCONDITIONAL_ONLY_FIELDS)
            invalid = invalid or any(field not in row for field in _SUPPORT_ONLY_FIELDS)
        if invalid:
            failures.append(f"R23D75_COMPACT_STARTUP_INVALID:{semantic_step}")

    return {
        "schema_version": "sporespore_qsdk_r23d75_compact_startup_sequence_v1",
        "ok": not failures,
        "engine_id": engine_id,
        "startup_transform_id": spec.startup_transform_id,
        "startup_policy": spec.startup_policy,
        "row_count": len(rows),
        "startup_ramp_active_step_count": active_count,
        "startup_ramp_exact_zero_scale_step_count": zero_count,
        "startup_ramp_exact_unity_scale_step_count": unity_count,
        "startup_ramp_triggered": governor.trigger_step is not None,
        "startup_ramp_trigger_step": governor.trigger_step,
        "minimum_observed_support_count": governor.minimum_probe_support_count,
        "failure_codes": failures[:32],
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_acceptance_authority": False,
    }


_ACCEPTED_VALIDATE_TRACE = accepted.validate_trace
_R23D74_CELL_BY_ID = design.cell_by_id
_R23D74_EXPECTED_SEGMENT_COUNTS = design.expected_segment_counts
_BINDING_LOCK = RLock()


def _configure_accepted_evaluator_for_cell(item: Any) -> StartupTransformSpec:
    """Bind immutable accepted algorithms to one exact native startup contract."""

    # A prior call in the same process may have selected MuJoCo.  Restore the
    # frozen R23D74 support-loss identity before its own runtime projection audit.
    design.STARTUP_TRANSFORM_ID = SUPPORT_LOSS_STARTUP_ID
    design.cell_by_id = _R23D74_CELL_BY_ID
    design.expected_segment_counts = _R23D74_EXPECTED_SEGMENT_COUNTS
    r23d74_evaluator._configure_inherited_evaluator()
    inherited._bind_accepted_core()
    spec = startup_transform_spec(item.engine_id)
    design.STARTUP_RAMP_ID = spec.startup_ramp_id
    design.STARTUP_TRANSFORM_ID = spec.startup_transform_id
    design.STARTUP_RAMP_STEPS = spec.startup_step_count
    design.SupportLossConditionedStartup = spec.governor_factory
    design.StartupTransformError = ValueError
    accepted.design = design
    return spec


def _native_startup_shape_failures(
    rows: Any,
    spec: StartupTransformSpec,
) -> list[str]:
    if not isinstance(rows, list) or len(rows) != design.CONTROLLER_STEPS:
        return ["R23D75_NATIVE_STARTUP_ROW_COUNT_INVALID"]
    for semantic_step, row in enumerate(rows):
        if not isinstance(row, Mapping):
            return [f"R23D75_NATIVE_STARTUP_ROW_INVALID:{semantic_step}"]
        contacts = row.get("ordered_foot_contacts_before")
        if not isinstance(contacts, Mapping) or set(contacts) != set(
            support_design.LIMB_IDS
        ):
            return [f"R23D75_NATIVE_STARTUP_CONTACTS_INVALID:{semantic_step}"]
        common_invalid = (
            row.get("startup_ramp_id") != spec.startup_ramp_id
            or row.get("startup_transform_id") != spec.startup_transform_id
            or row.get("startup_ramp_residual_count") != design.ACTUATOR_COUNT
            or row.get("startup_transform_residual_count") != design.ACTUATOR_COUNT
            or not _finite(row.get("startup_ramp_maximum_absolute_residual_rad_s"))
            or not _finite(row.get("startup_transform_maximum_absolute_residual_rad_s"))
            or float(row["startup_transform_maximum_absolute_residual_rad_s"])
            != float(row["startup_ramp_maximum_absolute_residual_rad_s"])
        )
        if spec.trace_policy_field_required:
            support_count = sum(int(contacts[limb_id]) for limb_id in support_design.LIMB_IDS)
            shape_invalid = (
                row.get("startup_policy") != spec.startup_policy
                or row.get("observed_support_count") != support_count
                or row.get("startup_probe_minimum_support_count") != support_count
                or any(field in row for field in _SUPPORT_ONLY_FIELDS)
            )
        else:
            shape_invalid = any(field in row for field in _UNCONDITIONAL_ONLY_FIELDS) or any(
                field not in row for field in _SUPPORT_ONLY_FIELDS
            )
        if common_invalid or shape_invalid:
            return [f"R23D75_NATIVE_STARTUP_SHAPE_INVALID:{semantic_step}"]
    return []


def validate_trace(cell_id: str, rows: Any) -> dict[str, Any]:
    """Validate one exact R23D74 native trace under its declared engine binding."""

    with _BINDING_LOCK:
        item = design.cell_by_id(cell_id)
        spec = _configure_accepted_evaluator_for_cell(item)
        summary = _ACCEPTED_VALIDATE_TRACE(cell_id, rows)
        failures = list(summary.get("failure_codes", []))
        shape_failures = _native_startup_shape_failures(rows, spec)
        cap_failures = inherited._trace_profile_cap_failures(rows, item)
        failures.extend(shape_failures)
        failures.extend(cap_failures)
        failures = list(dict.fromkeys(failures))
        summary.update(
            schema_version=TRACE_SUMMARY_SCHEMA,
            ok=not failures,
            failure_codes=failures[:64],
            source_campaign_id=design.CAMPAIGN_ID,
            conformance_campaign_id=CAMPAIGN_ID,
            conformance_gate_id=GATE_ID,
            question_class=QUESTION_CLASS,
            engine_id=item.engine_id,
            arm_id=item.arm_id,
            startup_transform_id=spec.startup_transform_id,
            startup_policy=spec.startup_policy,
            exact_native_startup_shape_observed=not shape_failures,
            exact_public_profile_caps_observed=not cap_failures,
            r23d74_result_reinterpreted=False,
            turning_result_computed=False,
            model_construction_count=0,
            world_attempt_count=0,
            world_build_count=0,
            solver_step_count=0,
            physical_acceptance_authority=False,
        )
        return summary


def _mutation_rejected(engine_id: str, rows: list[dict[str, Any]]) -> bool:
    try:
        return validate_startup_sequence(engine_id, rows).get("ok") is not True
    except (RuntimeError, ValueError, TypeError):
        return True


def run_zero_world_preflight() -> dict[str, Any]:
    """Run the complete compact positive, boundary and negative controls."""

    declaration = load_declaration()
    _require(raw_sha256(R23D74_CLOSURE_PATH) == R23D74_CLOSURE_SHA256, "R23D75_PARENT_DIGEST")

    full_support = lambda _step: len(support_design.LIMB_IDS)
    zero_support = lambda _step: 0
    late_loss = lambda step: len(support_design.LIMB_IDS) if step <= 3 else 0

    positive_sequences = {
        "godot_full_support": _compact_sequence("godot_jolt", full_support),
        "rapier_full_support": _compact_sequence("rapier_parry", full_support),
        "support_loss_trigger": _compact_sequence("godot_jolt", zero_support),
        "support_loss_after_probe": _compact_sequence("rapier_parry", late_loss),
        "mujoco_full_support": _compact_sequence("mujoco", full_support),
        "mujoco_zero_support": _compact_sequence("mujoco", zero_support),
    }
    validations = {
        name: validate_startup_sequence(
            "mujoco"
            if name.startswith("mujoco")
            else ("rapier_parry" if name in ("rapier_full_support", "support_loss_after_probe") else "godot_jolt"),
            rows,
        )
        for name, rows in positive_sequences.items()
    }
    _require(all(value.get("ok") is True for value in validations.values()), "R23D75_POSITIVE_CONTROL")
    _require(
        validations["godot_full_support"]["startup_ramp_triggered"] is False
        and validations["rapier_full_support"]["startup_ramp_triggered"] is False
        and validations["support_loss_trigger"]["startup_ramp_trigger_step"] == 0
        and validations["support_loss_after_probe"]["startup_ramp_triggered"] is False
        and validations["mujoco_full_support"]["startup_ramp_active_step_count"] == 359
        and validations["mujoco_full_support"]["startup_ramp_exact_zero_scale_step_count"] == 1
        and validations["mujoco_full_support"]["startup_ramp_exact_unity_scale_step_count"] == 2,
        "R23D75_BOUNDARY_CONTROL",
    )
    full_scales = [row["startup_velocity_scale"] for row in positive_sequences["mujoco_full_support"]]
    zero_scales = [row["startup_velocity_scale"] for row in positive_sequences["mujoco_zero_support"]]
    _require(full_scales == zero_scales, "R23D75_UNCONDITIONAL_CONTACT_DEPENDENCE")

    mapping = {engine_id: startup_transform_spec(engine_id) for engine_id in design.ENGINES}
    _require(
        tuple(mapping) == tuple(design.ENGINES)
        and mapping["godot_jolt"].startup_transform_id == SUPPORT_LOSS_STARTUP_ID
        and mapping["rapier_parry"].startup_transform_id == SUPPORT_LOSS_STARTUP_ID
        and mapping["mujoco"].startup_transform_id == UNCONDITIONAL_STARTUP_ID,
        "R23D75_ENGINE_BINDING_CONTROL",
    )

    mutation_cases: list[tuple[str, list[dict[str, Any]]]] = []
    for engine_id, source_name in (
        ("godot_jolt", "godot_full_support"),
        ("rapier_parry", "rapier_full_support"),
        ("mujoco", "mujoco_full_support"),
    ):
        for field, replacement in (
            ("startup_transform_id", "wrong"),
            ("startup_ramp_id", "wrong"),
            ("startup_velocity_scale", 0.125),
            ("startup_ramp_active", "wrong"),
        ):
            candidate = copy.deepcopy(positive_sequences[source_name])
            candidate[0][field] = replacement
            mutation_cases.append((engine_id, candidate))

    candidate = copy.deepcopy(positive_sequences["mujoco_full_support"])
    candidate[0].pop("startup_policy")
    mutation_cases.append(("mujoco", candidate))
    candidate = copy.deepcopy(positive_sequences["mujoco_full_support"])
    candidate[0]["observed_support_count"] = 3
    mutation_cases.append(("mujoco", candidate))
    candidate = copy.deepcopy(positive_sequences["godot_full_support"])
    candidate[0]["startup_policy"] = "unconditional_one_cycle"
    mutation_cases.append(("godot_jolt", candidate))
    candidate = copy.deepcopy(positive_sequences["godot_full_support"])
    candidate[1]["semantic_step"] = 2
    mutation_cases.append(("godot_jolt", candidate))
    candidate = copy.deepcopy(positive_sequences["godot_full_support"])
    candidate[0]["ordered_foot_contacts_before"].pop(support_design.LIMB_IDS[0])
    mutation_cases.append(("godot_jolt", candidate))
    mutation_cases.append(("godot_jolt", copy.deepcopy(positive_sequences["mujoco_full_support"])))
    mutation_cases.append(("mujoco", copy.deepcopy(positive_sequences["godot_full_support"])))

    mutation_rejections = sum(
        int(_mutation_rejected(engine_id, rows)) for engine_id, rows in mutation_cases
    )
    _require(
        mutation_rejections == len(mutation_cases),
        "R23D75_STARTUP_MUTATION_ACCEPTED",
    )
    unsupported_engine_rejected = False
    try:
        startup_transform_spec("unknown")
    except StartupBindingError:
        unsupported_engine_rejected = True
    _require(unsupported_engine_rejected, "R23D75_UNKNOWN_ENGINE_ACCEPTED")

    return {
        "schema_version": PREFLIGHT_SCHEMA,
        "status": "complete_zero_world_gate_passed_retained_trace_replay_pending",
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "immutable_parent_closure_raw_sha256": raw_sha256(R23D74_CLOSURE_PATH),
        "declared_engine_count": len(mapping),
        "complete_engine_binding_enumeration_count": len(mapping),
        "compact_positive_sequence_count": len(validations),
        "compact_row_count_per_sequence": COMPACT_LAST_STEP + 1,
        "sampled_boundary_steps": list(SAMPLED_BOUNDARY_STEPS),
        "startup_mutation_rejection_count": mutation_rejections,
        "unsupported_engine_rejection_count": int(unsupported_engine_rejected),
        "full_seeded_world_ghost_run": False,
        "retained_native_trace_replay_performed": False,
        "behavioral_success_prediction_made": False,
        "turning_result_computed": False,
        "r23d74_result_reinterpreted": False,
        "threshold_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "claims": copy.deepcopy(FALSE_CLAIMS),
        "declaration_status": declaration["status"],
    }


def _load_trace(path: Path) -> list[dict[str, Any]]:
    if path.name.endswith(".ndjson"):
        rows: list[dict[str, Any]] = []
        with path.open("r", encoding="utf-8") as handle:
            for line in handle:
                rows.append(json.loads(line))
        return rows
    value = json.loads(path.read_text(encoding="utf-8"))
    _require(isinstance(value, list), "R23D75_RETAINED_TRACE_NOT_ARRAY")
    return value


def replay_r23d74_retained_traces() -> dict[str, Any]:
    """Replay all exact retained R23D74 traces as development evidence only."""

    preflight = run_zero_world_preflight()
    closure = json.loads(R23D74_CLOSURE_PATH.read_text(encoding="utf-8"))
    _require(
        closure.get("schema_version") == "sporespore_qsdk_r23d74_physical_closure_v1"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_first_attempt_mujoco_startup_trace_evaluator_binding_mismatch",
        "R23D75_PARENT_CLOSURE_STATUS_INVALID",
    )
    cells = closure.get("observed_cells")
    _require(isinstance(cells, list) and len(cells) == 9, "R23D75_PARENT_CELL_EVIDENCE_INVALID")
    evidence_by_cell = {
        entry.get("cell_id"): entry for entry in cells if isinstance(entry, Mapping)
    }
    _require(len(evidence_by_cell) == 9, "R23D75_PARENT_CELL_IDENTITY_INVALID")

    trace_replays: list[dict[str, Any]] = []
    total_row_count = 0
    engine_counts = {engine_id: 0 for engine_id in design.ENGINES}
    for item in design.cells():
        evidence = evidence_by_cell.get(item.cell_id)
        _require(isinstance(evidence, Mapping), f"R23D75_PARENT_CELL_MISSING:{item.cell_id}")
        retained = evidence.get("retained_trace")
        _require(isinstance(retained, Mapping), f"R23D75_PARENT_TRACE_MISSING:{item.cell_id}")
        path = Path(str(retained.get("path", "")))
        _require(path.is_file(), f"R23D75_PARENT_TRACE_UNREADABLE:{item.cell_id}")
        observed_digest = raw_sha256(path)
        _require(
            observed_digest == retained.get("raw_sha256")
            and path.stat().st_size == retained.get("byte_length"),
            f"R23D75_PARENT_TRACE_BYTES_INVALID:{item.cell_id}",
        )
        rows = _load_trace(path)
        summary = validate_trace(item.cell_id, rows)
        total_row_count += len(rows)
        engine_counts[item.engine_id] += 1
        trace_replays.append(
            {
                "cell_id": item.cell_id,
                "engine_id": item.engine_id,
                "arm_id": item.arm_id,
                "retained_trace_path": path.as_posix(),
                "retained_trace_raw_sha256": observed_digest,
                "retained_trace_byte_length": path.stat().st_size,
                "row_count": len(rows),
                "startup_transform_id": summary.get("startup_transform_id"),
                "startup_policy": summary.get("startup_policy"),
                "startup_ramp_active_step_count": summary.get(
                    "startup_ramp_active_step_count"
                ),
                "startup_ramp_exact_zero_scale_step_count": summary.get(
                    "startup_ramp_exact_zero_scale_step_count"
                ),
                "startup_ramp_exact_unity_scale_step_count": summary.get(
                    "startup_ramp_exact_unity_scale_step_count"
                ),
                "failure_codes": summary.get("failure_codes", []),
                "conformance_passed": summary.get("ok") is True,
                "turning_result_computed": False,
                "physical_acceptance_authority": False,
            }
        )
    passed = (
        all(entry["conformance_passed"] for entry in trace_replays)
        and total_row_count == 9 * design.CONTROLLER_STEPS
        and all(count == 3 for count in engine_counts.values())
    )
    return {
        "schema_version": REPLAY_SCHEMA,
        "status": (
            "complete_exact_retained_native_trace_replay_passed"
            if passed
            else "complete_exact_retained_native_trace_replay_failed"
        ),
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": QUESTION_CLASS,
        "scientific_role": "outcome_exposed_software_conformance_development",
        "declaration_raw_sha256": raw_sha256(DECLARATION_PATH),
        "immutable_parent_closure_raw_sha256": raw_sha256(R23D74_CLOSURE_PATH),
        "zero_world_preflight": preflight,
        "trace_replays": trace_replays,
        "retained_trace_count": len(trace_replays),
        "retained_trace_row_count": total_row_count,
        "retained_trace_count_by_engine": engine_counts,
        "complete_enumeration_used": True,
        "sampling_used": False,
        "conformance_passed": passed,
        "r23d74_result_repaired": False,
        "r23d74_result_reinterpreted": False,
        "turning_result_computed": False,
        "behavior_threshold_invoked": False,
        "equivalence_or_non_inferiority_test_invoked": False,
        "population_inference_attempted": False,
        "new_physical_world_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "claims": copy.deepcopy(FALSE_CLAIMS),
    }


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("preflight", "replay-r23d74"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    try:
        if arguments.command == "preflight":
            value = run_zero_world_preflight()
            marker = "QSDK_R23D75_ZERO_WORLD_PREFLIGHT "
        else:
            value = replay_r23d74_retained_traces()
            marker = "QSDK_R23D75_RETAINED_TRACE_REPLAY "
        print(
            marker
            + json.dumps(
                value,
                allow_nan=False,
                ensure_ascii=False,
                separators=(",", ":"),
                sort_keys=True,
            )
        )
        return 0 if value.get("conformance_passed", True) is True else 1
    except (
        R23D75ConformanceError,
        StartupBindingError,
        accepted.R23D58EvaluationError,
        accepted.inherited.R23D34EvaluationError,
        inherited.R23D65EvaluationError,
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        TypeError,
        ValueError,
    ) as error:
        print(
            f"QSDK_R23D75_FAILURE {type(error).__name__}:{error}",
            file=sys.stderr,
        )
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
