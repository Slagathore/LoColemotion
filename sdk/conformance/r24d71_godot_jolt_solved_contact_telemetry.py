#!/usr/bin/env python3
"""Compact R71 solved-contact source audit over shared zero-world controls."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance import godot_recovery_route_zero_world_controls as controls  # noqa: E402

CONTRACT = ROOT / "sdk/recovery/r24d71_godot_jolt_solved_contact_telemetry_contract_v1.json"
PREDECESSOR = ROOT / "sdk/recovery/r24d70_godot_behavior_receipt_acceptance_negative_closure_v1.json"
PATCH = ROOT / "sdk/adapters/godot/engine_patches/godot_4_7_jolt_solved_contact_telemetry_v3.patch"
CAPABILITY = ROOT / "sdk/adapters/godot/gdscript/recovery_capability_instrumented_v2.gd"
ROUTE = ROOT / "sdk/adapters/godot/gdscript/recovery_native_route_v1.gd"
WORLD = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
CORE = ROOT / "sdk/core/src/recovery_runtime.rs"
SOURCE_MARKER = "QSDK_R24D71_GODOT_JOLT_SOLVED_CONTACT_TELEMETRY_SOURCE_PASS"
PROFILE = "godot_4_7_jolt_sporespore_motor_and_solved_contact_telemetry_v3"
COLLECTOR = "sporespore_godot_jolt_motor_and_solved_contact_v3_recovery_collector_v1"

WORKER_SPECS = (
    {
        "id": "r71_binding",
        "path": ROOT / "tests/test_sdk_qsdk_r24d71_godot_jolt_solved_contact_telemetry_binding_zero_world.gd",
        "marker": "QSDK_R24D71_GODOT_SOLVED_CONTACT_BINDING_ZERO_WORLD ",
        "expected": {"ok": True, "assertion_count": 7,
                     "passed_assertion_count": 7, "receipt_field_count": 15,
                     "invalid_rid_refusal_count": 1},
    },
    {
        "id": "r71_contract",
        "path": ROOT / "tests/test_sdk_qsdk_r24d71_godot_solved_contact_contract_zero_world.gd",
        "marker": "QSDK_R24D71_GODOT_SOLVED_CONTACT_CONTRACT_ZERO_WORLD ",
        "expected": {"ok": True, "positive_exact_count": 2,
                     "mutation_population_count": 18,
                     "exact_mutation_rejection_count": 18,
                     "missing_variant_rejection_count": 1},
    },
    {
        "id": "profile_capability",
        "path": ROOT / "tests/test_sdk_qsdk_r24d16_godot_profile_scoped_recovery_capability_zero_world.gd",
        "marker": "QSDK_R24D16_GODOT_PROFILE_CAPABILITY_ZERO_WORLD ",
        "user_args": ("--expected_profile=instrumented",),
        "expected": {"ok": True, "instrumented_profile_selected": True,
                     "exact_binary_pair_match": True,
                     "observed_profile_id": PROFILE,
                     "supported_channel_count": 10},
    },
    {
        "id": "portable_route",
        "path": ROOT / "tests/test_sdk_qsdk_r24d57_godot_native_recovery_route_zero_world.gd",
        "marker": "QSDK_R24D57_GODOT_NATIVE_RECOVERY_ROUTE_ZERO_WORLD ",
        "user_args": ("--expected_profile=instrumented",),
        "expected": {"ok": True, "instrumented_profile_selected": True,
                     "collection_support_status": "supported_exact",
                     "mutation_rejection_count": 6,
                     "native_world_blueprint_count": 1},
    },
)


def _load(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    controls.require(isinstance(value, dict), f"JSON_ROOT:{path.name}")
    return value


def _sha(path: Path) -> str:
    return "sha256:" + hashlib.sha256(path.read_bytes()).hexdigest()


def _markers(path: Path, values: tuple[str, ...]) -> None:
    source = path.read_text(encoding="utf-8")
    for value in values:
        controls.require(value in source, f"SOURCE_MARKER:{path.name}:{value}")


def validate_sources() -> dict[str, int]:
    contract = _load(CONTRACT)
    controls.require_fields(contract, {
        "gate_id": "QSDK-R24D71", "question_class": "development",
        "physical_question_declared": False, "finite_decision_declared": False,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
    }, "QUESTION")
    controls.require_fields(contract["ledger_scope"], {
        "subsystem": "recovery", "engine_scope": "godot_jolt",
        "authority_mode": "prospective_development_contract",
        "question_class": "development",
    }, "LEDGER_SCOPE")
    predecessor = contract["bound_predecessors"][0]
    controls.require_fields(predecessor, {
        "path": PREDECESSOR.relative_to(ROOT).as_posix(),
        "raw_sha256": _sha(PREDECESSOR),
        "byte_length": PREDECESSOR.stat().st_size,
        "closure_status": "closed_consumed_valid_finite_negative_distal_support_timeout",
        "same_identity_rerun_permitted": False,
        "result_reclassified": False,
    }, "PREDECESSOR")

    provenance = contract["native_source_provenance"]
    controls.require_fields(provenance, {
        "upstream_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
        "patch_path": PATCH.relative_to(ROOT).as_posix(),
        "patch_raw_sha256": _sha(PATCH),
        "patch_byte_length": PATCH.stat().st_size,
        "modified_path_count": 15,
        "exact_live_dependency_diff_must_equal_patch_bytes": True,
    }, "NATIVE_SOURCE")
    dependency = Path(provenance["dependency_checkout_path"])
    head = subprocess.run(["git", "rev-parse", "HEAD"], cwd=dependency,
                          capture_output=True, text=True, check=True).stdout.strip()
    controls.require(head == provenance["upstream_commit"], "DEPENDENCY_HEAD")
    diff = subprocess.run(
        ["git", "diff", "--binary", "--full-index", "--no-ext-diff"],
        cwd=dependency, capture_output=True, check=True,
    ).stdout
    controls.require(diff == PATCH.read_bytes(), "DEPENDENCY_DIFF")
    names = subprocess.run(["git", "diff", "--name-only"], cwd=dependency,
                           capture_output=True, text=True, check=True).stdout.splitlines()
    controls.require(names == provenance["modified_paths"], "DEPENDENCY_PATHS")

    runtime = contract["exact_runtime"]
    console, engine = Path(runtime["console_path"]), Path(runtime["engine_path"])
    controls.require_fields(runtime, {
        "console_sha256": _sha(console), "console_byte_length": console.stat().st_size,
        "engine_sha256": _sha(engine), "engine_byte_length": engine.stat().st_size,
    }, "RUNTIME")
    build = contract["retained_development_runtime"]
    build_receipt = Path(build["receipt_path"])
    controls.require_fields(build, {
        "receipt_raw_sha256": _sha(build_receipt),
        "receipt_byte_length": build_receipt.stat().st_size,
        "official_clean_pushed_qualification": False,
    }, "BUILD_RECEIPT")

    inventory = contract["source_inventory"]
    controls.require(len(inventory) == 18 == len(set(inventory)), "SOURCE_INVENTORY")
    for relative in inventory:
        controls.require((ROOT / relative).is_file(), f"SOURCE_MISSING:{relative}")
    parent = contract["authored_parent_commit"]
    repository_head = subprocess.run(
        ["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True,
        text=True, check=True,
    ).stdout.strip()
    if repository_head != parent:
        changed = subprocess.run(
            ["git", "diff", "--name-only", f"{parent}..{repository_head}"],
            cwd=ROOT, capture_output=True, text=True, check=True,
        ).stdout.splitlines()
        controls.require(changed == inventory, "COMMIT_PATH_POPULATION")
    _markers(PATCH, (
        "GetSolvedContactPointImpulses", "capture_solved_contact_impulses",
        "space_get_solved_contact_telemetry", 'result["complete"]',
    ))
    _markers(CAPABILITY, (PROFILE, "SOLVED_CONTACT_METHOD_NAME",
                         "PROMOTED_CHANNEL_INDEXES := [3, 4, 5, 8]"))
    _markers(ROUTE, (COLLECTOR, "telemetry_method_registered"))
    _markers(CORE, (PROFILE, COLLECTOR))
    _markers(WORLD, (
        "native_solved_contact_telemetry_contract_v1(",
        "space_get_solved_contact_telemetry(world_3d.space)",
        "godot_jolt_exact_post_solve_distal_capsule_lower_cap_contact_v1",
        '"native_post_solve_contact_constraint_lambda"',
    ))
    controls.require(WORLD.read_text(encoding="utf-8").count(
        "space_get_solved_contact_telemetry(world_3d.space)") == 1,
        "SOLVED_CONTACT_RUNTIME_CALL_COUNT")
    return {
        "focused_source_inventory_count": 18,
        "bound_predecessor_count": 1,
        "native_patch_path_count": 15,
        "current_zero_world_worker_count": len(WORKER_SPECS),
        "historical_closure_audits_executed_count": 0,
    }


def run_preflight(core_library: Path) -> dict[str, Any]:
    counts = validate_sources()
    controls.require(core_library.is_file(), "CORE_LIBRARY_MISSING")
    executable = controls.validate_exact_runtime_and_inventory(
        ROOT, _load(CONTRACT), 18
    )
    receipts = controls.run_zero_world_worker_specs(
        ROOT, executable, WORKER_SPECS
    )
    return {
        "schema_version": "sporespore_qsdk_r24d71_godot_solved_contact_preflight_v1",
        "gate_id": "QSDK-R24D71", "ok": True,
        "runtime_id": COLLECTOR, "runtime_version": PROFILE,
        **counts,
        **{f"{key}_receipt": value for key, value in receipts.items()},
        "native_runtime_observation_collection_executed": False,
        "held_out_cell_access_count": 0, "model_construction_count": 0,
        "world_attempt_count": 0, "world_build_count": 0,
        "solver_step_count": 0, "physics_state_modified": False,
        "physical_question_opened": False, "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False, "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--core-library", type=Path)
    args = parser.parse_args()
    if args.core_library is None:
        counts = validate_sources()
        print(SOURCE_MARKER, " ".join(f"{key}={value}" for key, value in counts.items()))
        return 0
    print(json.dumps(run_preflight(args.core_library.resolve()),
                     separators=(",", ":"), sort_keys=True))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D71_GODOT_JOLT_SOLVED_CONTACT_TELEMETRY_FAIL {error}",
              file=sys.stderr)
        raise SystemExit(1) from error
