#!/usr/bin/env python3
"""Zero-world source audit for the QSDK-R24D14 native projection gate."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
GODOT_ROOT = Path(r"C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7")
DECLARATION = ROOT / "sdk/recovery/r24d14_godot_native_float_projection_preregistration_v1.json"
MANIFEST = ROOT / "sdk/recovery/r24d14_godot_native_float_projection_validation_manifest.json"
PREDECESSOR = ROOT / "sdk/recovery/r24d13_godot_jolt_braking_mechanism_activation_physical_attempt_closure_v1.json"
WORKER = ROOT / "tests/test_sdk_qsdk_r24d14_godot_native_float_projection_worker.gd"
EVALUATOR = ROOT / "sdk/recovery/r24d14_godot_jolt_braking_mechanism_activation_evaluator.py"
RUNNER = ROOT / "sdk/run_qsdk_r24d14_native_float_projection_qualification.ps1"
EXPECTED_REPO_ROOT = "C:/Users/Cole/CodeStuff/games/SporeSpore"
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EXPECTED_PREDECESSOR_SHA = "sha256:2fa82f2a04d579612fbc34cfc62875f6b8f5acca63a41dd3a1da1d2d5bbdb725"
EXPECTED_PREDECESSOR_BYTES = 10665


def fail(code: str) -> None:
    raise SystemExit(f"QSDK-R24D14 native projection source audit: {code}")


def require(condition: bool, code: str) -> None:
    if not condition:
        fail(code)


def read_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(type(value) is dict, f"json_object:{path}")
    return value


def receipt(path: Path) -> tuple[str, int, str]:
    data = path.read_bytes()
    return "sha256:" + hashlib.sha256(data).hexdigest(), len(data), git("hash-object", "--", path.relative_to(ROOT).as_posix())


def git(*args: str, cwd: Path = ROOT) -> str:
    result = subprocess.run(
        ["git", "-C", str(cwd), *args],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    require(result.returncode == 0, f"git:{'_'.join(args)}:{result.stderr.strip()}")
    return result.stdout.strip()


def validate_declaration(value: dict[str, Any]) -> None:
    require(
        value.get("schema_version")
        == "sporespore_qsdk_r24d14_godot_native_float_projection_preregistration_v1",
        "declaration_schema",
    )
    require(value.get("gate_id") == "QSDK-R24D14", "declaration_gate")
    require(value.get("question_class") == "development", "declaration_class")
    require(
        value.get("status")
        == "prospective_zero_step_native_projection_source_implemented_qualification_pending",
        "declaration_status",
    )
    predecessor = value.get("predecessor", {})
    require(predecessor.get("gate_id") == "QSDK-R24D13", "predecessor_gate")
    require(predecessor.get("closure_raw_sha256") == EXPECTED_PREDECESSOR_SHA, "predecessor_sha")
    require(predecessor.get("closure_byte_length") == EXPECTED_PREDECESSOR_BYTES, "predecessor_bytes")
    require(predecessor.get("attempt_consumed") is True, "predecessor_consumed")
    require(predecessor.get("same_source_rerun_forbidden") is True, "predecessor_rerun")
    require(predecessor.get("accepted_physical_characterization") is False, "predecessor_acceptance")

    observed = value.get("observed_failure_preserved", {})
    require(observed.get("frozen_r24d13_binary64_hex") == "3f60624ddffffffa", "old_impulse_hex")
    require(observed.get("native_readback_binary64_hex") == "3f60624de0000000", "native_impulse_hex")
    require(observed.get("unreached_frozen_timestep_binary64_hex") == "3f8111111ffffffd", "old_dt_hex")
    require(observed.get("native_telemetry_timestep_binary64_hex") == "3f81111120000000", "native_dt_hex")
    require(observed.get("adjacent_values_are_numerically_unequal") is True, "adjacent_values")
    require(observed.get("r24d13_result_changed_or_reinterpreted") is False, "predecessor_rewrite")

    fields = value.get("exact_representation_contract", {}).get("fields", [])
    require(type(fields) is list and len(fields) == 3, "representation_field_count")
    expected = [
        ("3b03126f", "3f60624de0000000", "0.0020000000949949026"),
        ("3c088889", "3f81111120000000", "0.008333333767950535"),
        ("3d4ccccd", "3fa99999a0000000", "0.05000000074505806"),
    ]
    for index, (binary32, binary64, json_text) in enumerate(expected):
        field = fields[index]
        require(field.get("native_binary32_hex") == binary32, f"field_{index}_binary32")
        require(field.get("binary32_promoted_to_binary64_hex") == binary64, f"field_{index}_binary64")
        require(field.get("required_json_number_text") == json_text, f"field_{index}_json")
    exact_contract = value.get("exact_representation_contract", {})
    require(exact_contract.get("comparison_kind") == "exact_ieee_754_identity", "comparison_kind")
    require(exact_contract.get("tolerance") == 0.0, "tolerance")
    require(exact_contract.get("empirical_threshold") is False, "empirical_threshold")

    calibration = value.get("development_calibration", {})
    require(calibration.get("separate_from_official_qualification") is True, "calibration_separation")
    require(calibration.get("status") == "retained_development_failure_zero_world_zero_step", "calibration_status")
    require(calibration.get("attempt_population_count") == 4, "calibration_population")
    require(calibration.get("invalid_or_incomplete_attempt_count") == 3, "calibration_invalid_count")
    require(calibration.get("passing_attempt_count") == 1, "calibration_passing_count")
    require(calibration.get("first_attempt_raw_sha256") == "sha256:2cde38ee17ad731c0241e896bb29cd136e09d015fc9cdadb65eafa331b7252ee", "calibration_attempt_sha")
    require(calibration.get("first_raw_report_raw_sha256") == "sha256:1988adbf99fdd2a3cced0d9ad8b27705d29b7ddceebaa677f0b7d0df99367e0d", "calibration_report_sha")
    require(len(calibration.get("additional_invalid_or_incomplete_attempts", [])) == 2, "calibration_additional_count")
    require(calibration.get("passing_receipt_raw_sha256") == "sha256:33a0c38659ff776bd5753c4b2490dfd96672635d2c0efc53445ac2e9d52d5207", "calibration_passing_receipt")
    require(calibration.get("passing_source_was_clean_pushed") is False, "calibration_not_official")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        require(calibration.get(key) == 0, f"calibration_{key}")
    require(calibration.get("physical_authority") is False, "calibration_physical_authority")
    require(calibration.get("release_authority") is False, "calibration_release_authority")

    probe = value.get("zero_step_native_probe", {})
    for key, expected_value in {
        "native_joint_allocation_count": 1,
        "native_joint_release_call_count": 1,
        "body_count": 0,
        "space_count": 0,
        "viewport_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }.items():
        require(probe.get(key) == expected_value, f"probe_{key}")
    require(len(probe.get("route", [])) == 9, "probe_route_count")

    adequacy = value.get("adequacy", {})
    for key in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        require(adequacy.get(key) == 0, f"adequacy_{key}")
    boundary = value.get("execution_boundary", {})
    require(boundary.get("official_qualification_count") == 0, "qualification_count")
    require(boundary.get("physical_supervisor_implemented") is False, "physical_supervisor")
    require(boundary.get("physical_execution_authorized_now") is False, "physical_authorization")
    for key in ("world_attempt_count", "world_build_count", "solver_step_count"):
        require(boundary.get(key) == 0, f"boundary_{key}")
    claims = value.get("claims", {})
    require(claims.get("zero_step_native_projection_source_implemented") is True, "source_implemented")
    for key in (
        "complete_zero_step_qualification_passed",
        "physical_characterization_executed",
        "native_braking_mechanism_activation_observed",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "native_capability_conjunction_complete",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "turning_claim_changed",
        "cross_engine_equivalence_claimed",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        require(claims.get(key) is False, f"claim_{key}")


def assert_tokens(path: Path, tokens: tuple[str, ...], role: str) -> None:
    text = path.read_text(encoding="utf-8")
    for token in tokens:
        require(token in text, f"{role}_token:{token}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-committed", action="store_true")
    args = parser.parse_args()

    require(ROOT.as_posix() == EXPECTED_REPO_ROOT, "repository_root")
    require(git("remote", "get-url", "origin") == EXPECTED_REMOTE, "repository_remote")
    require(git("branch", "--show-current") == "main", "branch")
    require(len(git("rev-parse", "HEAD")) == 40, "head")
    require(len(git("worktree", "list", "--porcelain").split("worktree ")) - 1 == 1, "worktree_count")

    declaration = read_json(DECLARATION)
    validate_declaration(declaration)
    predecessor_sha = "sha256:" + hashlib.sha256(PREDECESSOR.read_bytes()).hexdigest()
    require(predecessor_sha == EXPECTED_PREDECESSOR_SHA, "predecessor_live_sha")
    require(PREDECESSOR.stat().st_size == EXPECTED_PREDECESSOR_BYTES, "predecessor_live_bytes")

    manifest = read_json(MANIFEST)
    require(
        manifest.get("schema_version")
        == "sporespore_qsdk_r24d14_godot_native_float_projection_validation_manifest_v1",
        "manifest_schema",
    )
    require(manifest.get("gate_id") == "QSDK-R24D14", "manifest_gate")
    require(manifest.get("question_class") == "development", "manifest_class")
    require(manifest.get("includes_self") is False, "manifest_self")
    bindings = manifest.get("source_bindings", [])
    require(type(bindings) is list, "manifest_bindings_type")
    require(len(bindings) == manifest.get("source_binding_count"), "manifest_binding_count")
    seen: set[str] = set()
    head = git("rev-parse", "HEAD")
    for binding in bindings:
        relative = binding.get("path")
        require(type(relative) is str and relative not in seen, f"binding_duplicate:{relative}")
        seen.add(relative)
        path = (ROOT / relative).resolve()
        require(path.is_relative_to(ROOT), f"binding_escape:{relative}")
        require(path.is_file(), f"binding_missing:{relative}")
        raw_sha, byte_length, blob = receipt(path)
        require(binding.get("raw_sha256") == raw_sha, f"binding_sha:{relative}")
        require(binding.get("byte_length") == byte_length, f"binding_bytes:{relative}")
        require(binding.get("git_blob_oid") == blob, f"binding_blob:{relative}")
        if args.require_committed:
            require(git("rev-parse", f"{head}:{relative}") == blob, f"binding_uncommitted:{relative}")

    native_bindings = manifest.get("native_source_bindings", [])
    require(len(native_bindings) == manifest.get("native_source_binding_count") == 6, "native_binding_count")
    native_seen: set[str] = set()
    for binding in native_bindings:
        relative = binding.get("path")
        require(type(relative) is str and relative not in native_seen, f"native_duplicate:{relative}")
        native_seen.add(relative)
        path = (GODOT_ROOT / relative).resolve()
        require(path.is_relative_to(GODOT_ROOT), f"native_escape:{relative}")
        data = path.read_bytes()
        require(binding.get("raw_sha256") == "sha256:" + hashlib.sha256(data).hexdigest(), f"native_sha:{relative}")
        require(binding.get("byte_length") == len(data), f"native_bytes:{relative}")

    assert_tokens(
        GODOT_ROOT / "scene/3d/physics/joints/joint_3d.cpp",
        ("joint = PhysicsServer3D::get_singleton()->joint_create();",),
        "native_joint",
    )
    assert_tokens(
        GODOT_ROOT / "scene/3d/physics/joints/hinge_joint_3d.cpp",
        ("void HingeJoint3D::set_param(Param p_param, real_t p_value)", "params[p_param] = p_value;", "real_t HingeJoint3D::get_param", "return params[p_param];"),
        "native_hinge_property",
    )
    assert_tokens(
        GODOT_ROOT / "modules/jolt_physics/jolt_physics_server_3d.cpp",
        ("active_space->step((float)p_step);", 'result["solver_step_s"] = motor_telemetry.solver_step_s;'),
        "native_server_projection",
    )
    assert_tokens(
        GODOT_ROOT / "modules/jolt_physics/spaces/jolt_space_3d.cpp",
        ("void JoltSpace3D::step(float p_step)", "_capture_joint_telemetry(p_step);"),
        "native_space_projection",
    )
    assert_tokens(
        GODOT_ROOT / "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
        ("float solver_step_s = 0.0f;",),
        "native_telemetry_storage",
    )
    assert_tokens(
        GODOT_ROOT / "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
        ("const float solver_step_s = constraint->GetMotorTelemetryStep();", "motor_telemetry_snapshot.solver_step_s = solver_step_s;"),
        "native_telemetry_capture",
    )

    assert_tokens(
        WORKER,
        (
            'mode != "native_projection_preflight"',
            "PhysicsServer3D.set_active(false)",
            "var joint := HingeJoint3D.new()",
            "joint.set_param(HingeJoint3D.PARAM_MOTOR_MAX_IMPULSE, 0.002)",
            "var timestep_float32_store := PackedFloat32Array([1.0 / 120.0])",
            'JSON.stringify(report, "", true, true)',
            'serialized_report.find("0.0020000000949949026")',
            'serialized_report.find("0.008333333767950535")',
            '"godot_json_parser_is_production_evaluator": false',
            '"production_evaluator_parser": "python_json"',
            '"world_attempt_count": 0',
            '"world_build_count": 0',
            '"solver_step_count": 0',
        ),
        "worker",
    )
    assert_tokens(
        EVALUATOR,
        (
            'EXPECTED_NATIVE_IMPULSE = struct.unpack("<f", bytes.fromhex("6f12033b"))[0]',
            'EXPECTED_NATIVE_TIMESTEP = struct.unpack("<f", bytes.fromhex("8988083c"))[0]',
            'REJECTED_R24D13_IMPULSE = float("0.0020000000949949")',
            'REJECTED_R24D13_TIMESTEP = float("0.00833333376795053")',
            'module.EXPECTED_REAL_T_IMPULSE = EXPECTED_NATIVE_IMPULSE',
            'module.EXPECTED_DT = EXPECTED_NATIVE_TIMESTEP',
        ),
        "evaluator",
    )
    assert_tokens(
        RUNNER,
        (
            '[ValidateSet("Development", "Qualification")]',
            'Enter-SporeSporeLocomotionOperationLock -Role "conformance"',
            '"--mode=native_projection_preflight"',
            "world_attempt_count = 0",
            'same_source_official_qualification_rerun_allowed = $false',
            'production_evaluator_parser = "python_json"',
            'Get-R24D14RepositoryBoundary -RequireCleanPushed:$requireQualification',
        ),
        "runner",
    )

    mutation_specs: list[tuple[tuple[str, ...], Any]] = [
        (("gate_id",), "QSDK-MUTATED"),
        (("question_class",), "finite_decision"),
        (("status",), "qualified"),
        (("predecessor", "closure_raw_sha256"), "sha256:" + "0" * 64),
        (("predecessor", "attempt_consumed"), False),
        (("observed_failure_preserved", "native_readback_binary64_hex"), "3f60624ddffffffa"),
        (("observed_failure_preserved", "r24d13_result_changed_or_reinterpreted"), True),
        (("exact_representation_contract", "tolerance"), 1e-9),
        (("development_calibration", "physical_authority"), True),
        (("development_calibration", "attempt_population_count"), 3),
        (("zero_step_native_probe", "native_joint_allocation_count"), 2),
        (("zero_step_native_probe", "world_attempt_count"), 1),
        (("zero_step_native_probe", "solver_step_count"), 1),
        (("adequacy", "empirical_acceptance_threshold_count"), 1),
        (("execution_boundary", "official_qualification_count"), 1),
        (("execution_boundary", "physical_execution_authorized_now"), True),
        (("claims", "complete_zero_step_qualification_passed"), True),
        (("claims", "release_authority"), True),
    ]
    rejected = 0
    for path, replacement in mutation_specs:
        mutated = copy.deepcopy(declaration)
        target: Any = mutated
        for part in path[:-1]:
            target = target[part]
        target[path[-1]] = replacement
        try:
            validate_declaration(mutated)
        except SystemExit:
            rejected += 1
        else:
            fail(f"mutation_accepted:{'.'.join(path)}")

    if args.require_committed:
        require(git("status", "--short") == "", "committed_dirty_worktree")
        manifest_relative = MANIFEST.relative_to(ROOT).as_posix()
        require(
            git("rev-parse", f"{head}:{manifest_relative}")
            == git("hash-object", "--", manifest_relative),
            "manifest_uncommitted",
        )

    print(
        "QSDK_R24D14_NATIVE_PROJECTION_SOURCE_PASS "
        f"bindings={len(bindings)} native_sources={len(native_bindings)} "
        f"mutations={rejected} worlds=0 builds=0 solver_steps=0 "
        "physical_authority=false release_authority=false"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
