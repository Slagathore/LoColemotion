"""Independent reference host for the public SporeSpore adapter contract.

This fixture intentionally owns no physics world. It exercises morphology,
state, selected-policy, actuation, safe-zero, ordering, and applied-feedback
semantics through the real public C ABI.
"""

from __future__ import annotations

import copy
import hashlib
import json
import re
from pathlib import Path
from typing import Any, Mapping

try:
    from sporespore_locomotion import (
        LocomotionCore,
        SELECTED_BALANCED_WAVE_CANDIDATE_ID,
        SELECTED_BALANCED_WAVE_POLICY_ID,
        reference_quadruped,
    )
except ImportError:
    from python.sporespore_locomotion import (
        LocomotionCore,
        SELECTED_BALANCED_WAVE_CANDIDATE_ID,
        SELECTED_BALANCED_WAVE_POLICY_ID,
        reference_quadruped,
    )


ADAPTER_KIT_ROOT = Path(__file__).resolve().parent
CONTRACT_PATH = ADAPTER_KIT_ROOT / "adapter_contract_v1.json"
REFERENCE_MANIFEST_PATH = (
    ADAPTER_KIT_ROOT / "reference_adapter_manifest_v1.json"
)
ADAPTER_RECEIPT_SCHEMA = "sporespore_adapter_applied_actuation_receipt_v1"
ID_PATTERN = re.compile(r"^[a-z][a-z0-9_]*$")


class AdapterContractError(RuntimeError):
    """A typed public-adapter contract violation."""

    def __init__(self, failure_code: str, detail: str) -> None:
        super().__init__(f"{failure_code}:{detail}")
        self.failure_code = failure_code
        self.detail = detail


def _require(condition: bool, failure_code: str, detail: str = "") -> None:
    if not condition:
        raise AdapterContractError(failure_code, detail)


def _read_json_object(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        raise AdapterContractError(
            "ADAPTER_JSON_INVALID",
            f"{path}:{error}",
        ) from error
    _require(
        isinstance(value, dict),
        "ADAPTER_JSON_NOT_OBJECT",
        str(path),
    )
    return value


def canonical_json(value: Mapping[str, Any]) -> str:
    """Return canonical JSON for manifests containing exact JSON primitives."""

    return json.dumps(
        value,
        allow_nan=False,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    )


def canonical_sha256(value: Mapping[str, Any]) -> str:
    payload = canonical_json(value).encode("utf-8")
    return f"sha256:{hashlib.sha256(payload).hexdigest()}"


def load_adapter_contract() -> dict[str, Any]:
    contract = _read_json_object(CONTRACT_PATH)
    _require(
        contract.get("schema_version")
        == "sporespore_adapter_authoring_contract_v1",
        "ADAPTER_CONTRACT_SCHEMA_INVALID",
    )
    _require(
        contract.get("contract_id")
        == "sporespore_engine_adapter_boundary_v1",
        "ADAPTER_CONTRACT_ID_INVALID",
    )
    selected = contract.get("selected_quadruped_controller")
    _require(
        isinstance(selected, dict),
        "ADAPTER_SELECTED_POLICY_MISSING",
    )
    _require(
        selected.get("candidate_id")
        == SELECTED_BALANCED_WAVE_CANDIDATE_ID,
        "ADAPTER_SELECTED_CANDIDATE_MISMATCH",
    )
    _require(
        selected.get("policy_id") == SELECTED_BALANCED_WAVE_POLICY_ID,
        "ADAPTER_SELECTED_POLICY_MISMATCH",
    )
    _require(
        selected.get("legacy_unnamed_entrypoints_allowed_for_new_adapters")
        is False,
        "ADAPTER_LEGACY_ENTRYPOINT_ESCALATION",
    )
    authority = contract.get("authority_partition")
    _require(
        isinstance(authority, dict)
        and "controller_policy_substitution"
        in authority.get("forbidden_adapter_authority", []),
        "ADAPTER_POLICY_AUTHORITY_NOT_FORBIDDEN",
    )
    _require(
        contract.get("canonical_frame", {}).get("coordinate_frame_id")
        == "right_handed_x_forward_y_up_z_right_si_v1",
        "ADAPTER_CANONICAL_FRAME_INVALID",
    )
    _require(
        contract.get("actuation", {}).get(
            "direct_base_pose_or_velocity_locomotor_write_allowed"
        )
        is False,
        "ADAPTER_ROOT_WRITE_NOT_FORBIDDEN",
    )
    return contract


def load_reference_manifest(
    contract: Mapping[str, Any] | None = None,
) -> dict[str, Any]:
    active_contract = (
        dict(contract) if contract is not None else load_adapter_contract()
    )
    manifest = _read_json_object(REFERENCE_MANIFEST_PATH)
    expected_fields = set(
        active_contract["capability_manifest"]["required_top_level_fields"]
    )
    _require(
        set(manifest) == expected_fields,
        "ADAPTER_MANIFEST_FIELDS_INVALID",
        (
            f"actual={sorted(manifest)} "
            f"expected={sorted(expected_fields)}"
        ),
    )
    _require(
        manifest.get("schema_version")
        == "sporespore_adapter_capability_manifest_v1",
        "ADAPTER_MANIFEST_SCHEMA_INVALID",
    )
    adapter_id = manifest.get("adapter_id")
    _require(
        isinstance(adapter_id, str) and ID_PATTERN.fullmatch(adapter_id),
        "ADAPTER_MANIFEST_ID_INVALID",
        str(adapter_id),
    )
    _require(
        manifest.get("fixture_role")
        == "independent_public_surface_reference",
        "ADAPTER_FIXTURE_ROLE_INVALID",
    )
    host = manifest.get("host")
    _require(
        isinstance(host, dict)
        and host.get("world_construction") is False
        and host.get("fixed_step_numerator_s") == 1
        and host.get("fixed_step_denominator_s") == 120,
        "ADAPTER_REFERENCE_HOST_INVALID",
    )
    required_cells = active_contract["capability_manifest"][
        "required_conformance_cells"
    ]
    conformance = manifest.get("conformance")
    _require(
        isinstance(conformance, dict)
        and all(conformance.get(cell) is True for cell in required_cells),
        "ADAPTER_AUTHORING_CELLS_NOT_DECLARED",
    )
    for cell in (
        "c2_kinematic",
        "c3_passive_dynamics",
        "c4_actuator",
        "c5_contact",
        "c6_locomotion",
    ):
        _require(
            conformance.get(cell) is False,
            "ADAPTER_PHYSICAL_CONFORMANCE_ESCALATION",
            cell,
        )
    claims = manifest.get("claims")
    _require(
        isinstance(claims, dict)
        and all(value is False for value in claims.values()),
        "ADAPTER_REFERENCE_CLAIM_ESCALATION",
    )
    return manifest


class ReferenceHostAdapter:
    """A zero-world adapter that implements the complete public host loop."""

    def __init__(self, core: LocomotionCore | None = None) -> None:
        self.contract = load_adapter_contract()
        self.manifest = load_reference_manifest(self.contract)
        self.core = core if core is not None else LocomotionCore()
        self.manifest_sha256 = self.core.canonicalize_json(
            self.manifest
        )["sha256"]
        self.descriptor = reference_quadruped("reference_external_adapter")
        compiled = self.core.compile_bounded_quadruped(self.descriptor)
        self.compiled = compiled["morphology"]
        self.profile = self.core.balanced_wave_policy_profile(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            self.descriptor,
        )
        _require(
            self.profile.get("policy_id")
            == SELECTED_BALANCED_WAVE_POLICY_ID,
            "ADAPTER_NAMED_POLICY_PROFILE_MISMATCH",
        )
        _require(
            self.profile.get("physical_acceptance_authority") is False,
            "ADAPTER_PROFILE_AUTHORITY_ESCALATION",
        )
        self.memory = self.core.balanced_wave_policy_initial_memory(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            self.descriptor,
        )
        self.previous_applied_actuation: dict[str, Any] | None = None
        self.next_semantic_step = 0

    @property
    def ordered_joint_ids(self) -> list[str]:
        return list(self.compiled["ordered_joint_ids"])

    @property
    def ordered_actuator_ids(self) -> list[str]:
        return list(self.compiled["ordered_actuator_ids"])

    @property
    def ordered_contact_site_ids(self) -> list[str]:
        return list(self.compiled["ordered_contact_site_ids"])

    def build_state_frame(
        self,
        semantic_step: int,
        *,
        contacts_available: bool = True,
        previous_applied_actuation: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        if contacts_available:
            contacts = [
                {
                    "contact_site_id": contact_id,
                    "presence": True,
                    "bears_support": True,
                    "normal_load_n": None,
                    "provenance": {
                        "adapter_id": self.manifest["adapter_id"],
                        "engine_contact_ids": [f"{contact_id}_mock_contact"],
                        "aggregation_rule_id": "qualified_bearing_no_load_v1",
                        "quality": "qualified_bearing",
                    },
                }
                for contact_id in self.ordered_contact_site_ids
            ]
        else:
            contacts = [
                {
                    "contact_site_id": contact_id,
                    "presence": None,
                    "bears_support": None,
                    "normal_load_n": None,
                    "provenance": {
                        "adapter_id": self.manifest["adapter_id"],
                        "engine_contact_ids": [],
                        "aggregation_rule_id": "observation_unavailable_v1",
                        "quality": "unavailable",
                    },
                }
                for contact_id in self.ordered_contact_site_ids
            ]
        previous = (
            copy.deepcopy(previous_applied_actuation)
            if previous_applied_actuation is not None
            else None
        )
        return {
            "schema_version": "sporespore_state_frame_v1",
            "semantic_step": semantic_step,
            "sample_time_s": semantic_step / 120.0,
            "base_pose_world": {
                "position_m": {"x": 0.0, "y": 0.44, "z": 0.0},
                "orientation_xyzw": {
                    "x": 0.0,
                    "y": 0.0,
                    "z": 0.0,
                    "w": 1.0,
                },
            },
            "base_twist_world": {
                "linear_velocity_m_s": {"x": 0.0, "y": 0.0, "z": 0.0},
                "angular_velocity_rad_s": {
                    "x": 0.0,
                    "y": 0.0,
                    "z": 0.0,
                },
            },
            "ordered_joint_observations": [
                {
                    "joint_id": joint_id,
                    "position_rad": 0.0,
                    "velocity_rad_s": 0.0,
                    "anchor_error_m": 0.0,
                    "validity": {
                        "position": True,
                        "velocity": True,
                        "anchor_error": True,
                    },
                }
                for joint_id in self.ordered_joint_ids
            ],
            "ordered_contact_observations": contacts,
            "previous_applied_actuation": previous,
            "gravity_world_m_s2": {"x": 0.0, "y": -9.81, "z": 0.0},
            "task_frame": {
                "origin_world_m": {"x": 0.0, "y": 0.0, "z": 0.0},
                "forward_axis_world_unit": {
                    "x": 1.0,
                    "y": 0.0,
                    "z": 0.0,
                },
                "lateral_axis_world_unit": {
                    "x": 0.0,
                    "y": 0.0,
                    "z": 1.0,
                },
                "up_axis_world_unit": {
                    "x": 0.0,
                    "y": 1.0,
                    "z": 0.0,
                },
                "reference_yaw_rad": 0.0,
            },
            "adapter_capability_sha256": self.manifest_sha256,
        }

    @staticmethod
    def build_motion_command(semantic_step: int) -> dict[str, Any]:
        return {
            "schema_version": "sporespore_motion_command_v2",
            "command_id": f"reference_walk_{semantic_step}",
            "desired_planar_velocity_task_m_s": {
                "x": 0.2,
                "y": 0.0,
                "z": 0.0,
            },
            "desired_heading_rad": 0.0,
            "desired_yaw_rate_rad_s": None,
            "gait_family_id": "lateral_wave",
            "speed_class": "walk",
            "gait_amplitude": 1.0,
            "phase_progression_mode": "contact_gated",
            "valid_from_step": semantic_step,
            "valid_through_step": semantic_step,
            "authority": "test_fixture",
        }

    def build_step_request(
        self,
        semantic_step: int,
        *,
        contacts_available: bool = True,
        previous_applied_actuation: Mapping[str, Any] | None = None,
        memory: Mapping[str, Any] | None = None,
    ) -> dict[str, Any]:
        return {
            "descriptor": copy.deepcopy(self.descriptor),
            "memory": copy.deepcopy(
                self.memory if memory is None else dict(memory)
            ),
            "state": self.build_state_frame(
                semantic_step,
                contacts_available=contacts_available,
                previous_applied_actuation=previous_applied_actuation,
            ),
            "command": self.build_motion_command(semantic_step),
        }

    def validate_actuation_frame(
        self,
        actuation: Mapping[str, Any],
        semantic_step: int,
    ) -> None:
        _require(
            actuation.get("schema_version")
            == "sporespore_actuation_frame_v1",
            "ADAPTER_ACTUATION_SCHEMA_INVALID",
        )
        _require(
            actuation.get("semantic_step") == semantic_step,
            "ADAPTER_ACTUATION_STEP_MISMATCH",
        )
        commands = actuation.get("ordered_commands")
        _require(
            isinstance(commands, list)
            and [entry.get("actuator_id") for entry in commands]
            == self.ordered_actuator_ids,
            "ADAPTER_ACTUATION_ORDER_INVALID",
        )
        _require(
            actuation.get("receipt", {}).get("policy_id")
            == SELECTED_BALANCED_WAVE_POLICY_ID,
            "ADAPTER_ACTUATION_POLICY_MISMATCH",
        )
        _require(
            actuation.get("receipt", {}).get("adapter_capability_sha256")
            == self.manifest_sha256,
            "ADAPTER_CAPABILITY_DIGEST_MISMATCH",
        )
        _require(
            actuation.get("world_build_count") == 0
            and actuation.get("physical_acceptance_authority") is False,
            "ADAPTER_ACTUATION_AUTHORITY_ESCALATION",
        )
        safe = actuation.get("safe_no_actuation") is True
        for command in commands:
            _require(
                command.get("mode") == "position_velocity",
                "ADAPTER_ACTUATOR_MODE_UNSUPPORTED",
                str(command.get("actuator_id")),
            )
            maximum_speed = command.get("maximum_target_speed_rad_s")
            target_velocity = command.get("target_velocity_rad_s")
            _require(
                isinstance(maximum_speed, (int, float))
                and isinstance(target_velocity, (int, float))
                and abs(target_velocity) <= maximum_speed + 1.0e-12,
                "ADAPTER_TARGET_VELOCITY_OUT_OF_BOUNDS",
                str(command.get("actuator_id")),
            )
            _require(
                command.get("valid_through_step", -1) >= semantic_step,
                "ADAPTER_COMMAND_EXPIRED",
                str(command.get("actuator_id")),
            )
            if safe:
                _require(
                    target_velocity == 0.0
                    and command.get("residual_contribution_rad_s") == 0.0
                    and command.get("safety_contribution_rad_s") == 0.0,
                    "ADAPTER_SAFE_ZERO_HAS_AUTHORITY",
                    str(command.get("actuator_id")),
                )

    def apply_actuation_frame(
        self,
        actuation: Mapping[str, Any],
    ) -> tuple[dict[str, Any], dict[str, Any]]:
        semantic_step = int(actuation["semantic_step"])
        self.validate_actuation_frame(actuation, semantic_step)
        applied_commands = [
            {
                "actuator_id": command["actuator_id"],
                "applied_target_position_rad": command[
                    "clamped_target_position_rad"
                ],
                "applied_target_velocity_rad_s": command[
                    "target_velocity_rad_s"
                ],
                "host_clamped": False,
            }
            for command in actuation["ordered_commands"]
        ]
        receipt = {
            "schema_version": ADAPTER_RECEIPT_SCHEMA,
            "adapter_id": self.manifest["adapter_id"],
            "semantic_step": semantic_step,
            "source_controller_receipt_sha256": actuation["receipt_sha256"],
            "ordered_commands": copy.deepcopy(applied_commands),
            "safe_no_actuation_preserved": (
                actuation["safe_no_actuation"] is True
            ),
            "applied_exactly_once": True,
            "direct_root_locomotion_write": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
        receipt_sha256 = self.core.canonicalize_json(receipt)["sha256"]
        previous_observation = {
            "source_semantic_step": semantic_step,
            "ordered_commands": applied_commands,
            "adapter_receipt_sha256": receipt_sha256,
        }
        return receipt, previous_observation

    def advance(
        self,
        *,
        contacts_available: bool = True,
    ) -> dict[str, Any]:
        semantic_step = self.next_semantic_step
        request = self.build_step_request(
            semantic_step,
            contacts_available=contacts_available,
            previous_applied_actuation=self.previous_applied_actuation,
        )
        output = self.core.balanced_wave_policy_step(
            SELECTED_BALANCED_WAVE_POLICY_ID,
            request,
        )
        self.validate_actuation_frame(output["actuation"], semantic_step)
        receipt, previous = self.apply_actuation_frame(output["actuation"])
        self.memory = copy.deepcopy(output["next_memory"])
        self.previous_applied_actuation = previous
        self.next_semantic_step += 1
        return {
            "controller_output": output,
            "adapter_receipt": receipt,
            "adapter_receipt_sha256": previous[
                "adapter_receipt_sha256"
            ],
            "previous_applied_actuation": copy.deepcopy(previous),
        }
