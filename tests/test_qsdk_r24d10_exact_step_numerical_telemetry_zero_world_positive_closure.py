#!/usr/bin/env python3
"""Audit the immutable QSDK-R24D10 complete zero-world positive closure."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


REPO_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
SOURCE_COMMIT = "11df9b566dda911c6c3f1a8ad76369c8ee0c340e"
SOURCE_TREE = "3daee26820a8a9a6fbbc177ce4eaec2469b1d1dd"
GODOT_COMMIT = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
PATCH_SHA = "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
MANIFEST_RELATIVE = Path(
    "sdk/recovery/"
    "r24d10_godot_jolt_exact_step_numerical_telemetry_validation_manifest.json"
)
CLOSURE_RELATIVE = Path(
    "sdk/recovery/"
    "r24d10_godot_jolt_exact_step_numerical_telemetry_"
    "zero_world_positive_closure_v1.json"
)
AUDIT_RELATIVE = Path(
    "tests/"
    "test_qsdk_r24d10_exact_step_numerical_telemetry_"
    "zero_world_positive_closure.py"
)
RUN_ROOT = EVIDENCE_ROOT / (
    "qsdk-r24d10-exact-step-numerical-telemetry/zero-world/"
    "20260826T190352433Z-11df9b56-65f7856d452f"
)
RECEIPT_SHA = "sha256:093db061d3bb4799c4ac6a0a4c30364031297aee4b27608ef797cea05c6bb34f"
RECEIPT_BYTES = 91320
EXPECTED_STAGE_NAMES = [
    "immutable_r24d9_failure_closure_recheck",
    "r24d10_manifest_freeze_and_parser_audit",
    "independent_godot_cold_cleanup",
    "independent_godot_cold_build",
    "exact_step_evaluator_shaped_zero_world_template",
    "custom_runtime_zero_object_worker",
    "independent_exact_step_synthetic_evaluation",
]
EXPECTED_CLAIMS = {
    "complete_zero_world_gate_passed": True,
    "exact_step_schedule_source_qualified": True,
    "physical_characterization_executed": False,
    "native_numerical_telemetry_characterized": False,
    "numerical_accuracy_accepted": False,
    "instrumented_profile_promoted": False,
    "stock_godot_profile_promoted": False,
    "recovery_world_opened": False,
    "prone_to_standing_world_opened": False,
    "turning_claim_changed": False,
    "cross_engine_equivalence_claimed": False,
    "q_sdk_r24_satisfied": False,
    "physical_authorization": False,
    "physical_acceptance_authority": False,
    "release_authority": False,
}


class AuditFailure(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditFailure(f"QSDK-R24D10 zero-world positive closure: {code}")


def strict_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        require(key not in result, f"duplicate_json_key:{key}")
        result[key] = value
    return result


def load_json_bytes(data: bytes, code: str) -> dict[str, Any]:
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=strict_object)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AuditFailure(f"{code}:{exc}") from exc
    require(isinstance(value, dict), f"{code}:root_not_object")
    return value


def load_json(path: Path, code: str) -> dict[str, Any]:
    require(path.is_file(), f"{code}:missing:{path}")
    return load_json_bytes(path.read_bytes(), code)


def sha256_bytes(data: bytes) -> str:
    return "sha256:" + hashlib.sha256(data).hexdigest()


def file_receipt(path: Path) -> tuple[str, int]:
    data = path.read_bytes()
    return sha256_bytes(data), len(data)


def git(*arguments: str, binary: bool = False) -> bytes | str:
    completed = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
    )
    require(
        completed.returncode == 0,
        f"git:{' '.join(arguments)}:{completed.stderr.decode(errors='replace')}",
    )
    if binary:
        return completed.stdout
    return completed.stdout.decode("utf-8").strip()


def historical_blob(relative: Path) -> bytes:
    return git("show", f"{SOURCE_COMMIT}:{relative.as_posix()}", binary=True)  # type: ignore[return-value]


def is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def semantic_vector(candidate: dict[str, Any]) -> bool:
    try:
        source = candidate["source"]
        predecessor = candidate["predecessor_authority"]
        runtime = candidate["runtime"]
        zero = candidate["zero_world_qualification"]
        worker = candidate["zero_world_worker"]
        evaluation = candidate["zero_world_evaluation"]
        retention = candidate["retention"]
        statistics = candidate["statistical_claim_boundary"]
        immutable = candidate["immutability"]
        next_boundary = candidate["next_boundary"]
        audit = candidate["audit_contract"]
        return (
            candidate["schema_version"]
            == "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_positive_closure_v1"
            and candidate["closure_id"] == "QSDK-R24D10-ZW1-CLOSURE"
            and candidate["gate_id"] == "QSDK-R24D10"
            and candidate["question_class"] == "development"
            and candidate["status"]
            == "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization"
            and candidate["result_class"]
            == "valid_complete_zero_world_source_toolchain_and_synthetic_shape_qualification"
            and source["commit"] == SOURCE_COMMIT
            and source["tree_git_oid"] == SOURCE_TREE
            and source["remote"] == EXPECTED_REMOTE
            and source["clean_pushed_before_qualification"] is True
            and source["local_upstream_cached_live_equal_before_qualification"] is True
            and source["worktree_count"] == 1
            and source["validation_manifest"]["raw_sha256"]
            == "sha256:11b115989572eab55565ac6b0568a8986873daa236f0c3b9e36190840210dad7"
            and source["validation_manifest"]["source_binding_count"] == 19
            and predecessor["closure_id"] == "QSDK-R24D9-PH1-CLOSURE"
            and predecessor["raw_sha256"]
            == "sha256:ef054432bf3aa15673a49c9765a3221ffd337c2becb9ba96f1951c81f87b4fde"
            and predecessor["r24d9_result_reused_or_reinterpreted"] is False
            and predecessor["r24d9_campaign_repaired_or_rerun"] is False
            and runtime["godot_source_commit"] == GODOT_COMMIT
            and runtime["combined_patch_raw_sha256"] == PATCH_SHA
            and runtime["console_binary_raw_sha256"]
            == "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
            and runtime["engine_binary_raw_sha256"]
            == "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
            and runtime["retained_binary_pair_executed"] is True
            and runtime["reproducible_build_claimed"] is False
            and runtime["result_reuse_authority"] is False
            and zero["receipt_raw_sha256"] == RECEIPT_SHA
            and zero["receipt_byte_length"] == RECEIPT_BYTES
            and zero["stage_count"] == 7
            and zero["stage_pass_count"] == 7
            and zero["stage_names_in_order"] == EXPECTED_STAGE_NAMES
            and zero["same_source_zero_world_attempt_count"] == 1
            and zero["same_source_zero_world_rerun_allowed"] is False
            and zero["world_attempt_count"] == 0
            and zero["world_build_count"] == 0
            and zero["solver_step_count"] == 0
            and worker["real_custom_runtime_executed"] is True
            and worker["invalid_rid_refused"] is True
            and worker["template_shape_matches"] is True
            and worker["synthetic_envelope_is_physical_observation"] is False
            and worker["world_attempt_count"] == 0
            and evaluation["evidence_kind"] == "synthetic_zero_world"
            and evaluation["execution_valid"] is True
            and evaluation["first_retained_space_step_sequence"] == 1
            and evaluation["last_retained_space_step_sequence"] == 20
            and evaluation["observed_retained_awake_space_step_token_count"] == 20
            and evaluation["token_derived_physics_step_count"] == 20
            and evaluation["pre_sample_physics_frame_count"] == 0
            and evaluation["extra_unretained_post_activation_step_count"] == 0
            and evaluation["all_declared_initial_real_t_projections_preserved"] is True
            and evaluation["native_numerical_telemetry_characterized"] is False
            and retention["run_file_count"] == 23
            and retention["run_unique_content_digest_count"] == 19
            and retention["run_total_byte_length"] == 189650583
            and retention["receipt_embedded_cas_reference_count"] == 15
            and retention["receipt_embedded_unique_cas_digest_count"] == 12
            and len(retention["complete_run_inventory"]) == 23
            and statistics["empirical_acceptance_threshold_count"] == 0
            and statistics["superiority_margin_count"] == 0
            and statistics["equivalence_or_non_inferiority_margin_count"] == 0
            and statistics["physical_sample_count"] == 0
            and statistics["population_claim_count"] == 0
            and immutable["same_source_zero_world_rerun_forbidden"] is True
            and immutable["observed_receipt_or_evaluation_rewritten"] is False
            and immutable["result_reuse_authority"] is False
            and next_boundary["physical_execution_authorized"] is False
            and next_boundary["distinct_explicit_physical_authorization_required"] is True
            and next_boundary["next_physical_declaration_may_be_authored"] is True
            and next_boundary["canonical_prone_to_standing_world_authorized"] is False
            and audit["minimum_semantic_mutation_rejection_count"] == 24
            and audit["complete_run_inventory_must_match"] is True
            and audit["all_embedded_cas_receipts_must_verify"] is True
            and candidate["claims"] == EXPECTED_CLAIMS
        )
    except (KeyError, TypeError, ValueError):
        return False


def set_nested(candidate: dict[str, Any], path: str, value: Any) -> None:
    parts = path.split(".")
    cursor: Any = candidate
    for part in parts[:-1]:
        cursor = cursor[part]
    cursor[parts[-1]] = value


def walk_cas(value: Any, path: str = "") -> list[tuple[str, dict[str, Any]]]:
    found: list[tuple[str, dict[str, Any]]] = []
    if isinstance(value, dict):
        if value.get("schema_version") == "sporespore_content_addressed_artifact_receipt_v1":
            found.append((path, value))
        for key, child in value.items():
            found.extend(walk_cas(child, f"{path}/{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(walk_cas(child, f"{path}/{index}"))
    return found


def verify_cas(receipt: dict[str, Any], code: str) -> str:
    digest = receipt["sha256"]
    length = receipt["byte_length"]
    require(isinstance(digest, str) and digest.startswith("sha256:"), f"{code}:digest")
    payload = Path(receipt["payload_path"])
    manifest_path = Path(receipt["manifest_path"])
    require(is_within(payload, EVIDENCE_ROOT), f"{code}:payload_boundary")
    require(is_within(manifest_path, EVIDENCE_ROOT), f"{code}:manifest_boundary")
    require(payload.is_file() and manifest_path.is_file(), f"{code}:files_missing")
    require(file_receipt(payload) == (digest, length), f"{code}:payload_identity")
    manifest = load_json(manifest_path, f"{code}:manifest")
    require(
        manifest["schema_version"] == "sporespore_content_addressed_artifact_manifest_v1"
        and manifest["algorithm"] == "sha256"
        and manifest["sha256"] == digest
        and manifest["byte_length"] == length
        and manifest["payload_name"] == "payload.bin",
        f"{code}:manifest_identity",
    )
    return digest


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    args = parser.parse_args()

    require(Path(git("rev-parse", "--show-toplevel")) == REPO_ROOT, "repository_root")
    require(git("remote", "get-url", "origin") == EXPECTED_REMOTE, "repository_remote")
    require(git("rev-parse", f"{SOURCE_COMMIT}^{{tree}}") == SOURCE_TREE, "source_tree")

    closure_path = REPO_ROOT / CLOSURE_RELATIVE
    closure = load_json(closure_path, "closure_json")
    require(semantic_vector(closure), "closure_semantic_vector")

    manifest_bytes = historical_blob(MANIFEST_RELATIVE)
    manifest_identity = closure["source"]["validation_manifest"]
    require(
        sha256_bytes(manifest_bytes) == manifest_identity["raw_sha256"]
        and len(manifest_bytes) == manifest_identity["byte_length"]
        and git("rev-parse", f"{SOURCE_COMMIT}:{MANIFEST_RELATIVE.as_posix()}")
        == manifest_identity["git_blob_oid"],
        "historical_manifest_identity",
    )
    manifest = load_json_bytes(manifest_bytes, "historical_manifest_json")
    bindings = manifest["source_bindings"]
    require(len(bindings) == 19, "historical_manifest_binding_count")
    for binding in bindings:
        relative = Path(binding["path"])
        blob = historical_blob(relative)
        require(
            sha256_bytes(blob) == binding["raw_sha256"]
            and len(blob) == binding["byte_length"]
            and git("rev-parse", f"{SOURCE_COMMIT}:{relative.as_posix()}")
            == binding["git_blob_oid"],
            f"historical_binding:{relative.as_posix()}",
        )

    predecessor = closure["predecessor_authority"]
    predecessor_relative = Path(predecessor["path"])
    predecessor_bytes = historical_blob(predecessor_relative)
    require(
        sha256_bytes(predecessor_bytes) == predecessor["raw_sha256"],
        "predecessor_closure_identity",
    )
    publication_bytes = git(
        "show",
        f"{predecessor['publication_commit']}:{predecessor_relative.as_posix()}",
        binary=True,
    )
    require(publication_bytes == predecessor_bytes, "predecessor_publication_blob")

    inventory = closure["retention"]["complete_run_inventory"]
    declared_paths = [entry["path"] for entry in inventory]
    require(declared_paths == sorted(declared_paths), "inventory_order")
    actual_paths = sorted(
        path.relative_to(RUN_ROOT).as_posix()
        for path in RUN_ROOT.rglob("*")
        if path.is_file()
    )
    require(actual_paths == declared_paths, "complete_run_inventory_population")
    for entry in inventory:
        path = RUN_ROOT / entry["path"]
        require(
            file_receipt(path) == (entry["raw_sha256"], entry["byte_length"]),
            f"run_inventory_identity:{entry['path']}",
        )
    require(
        len(inventory) == 23
        and len({entry["raw_sha256"] for entry in inventory}) == 19
        and sum(entry["byte_length"] for entry in inventory) == 189650583,
        "run_inventory_totals",
    )

    receipt_path = RUN_ROOT / "receipt.json"
    require(file_receipt(receipt_path) == (RECEIPT_SHA, RECEIPT_BYTES), "receipt_identity")
    receipt = load_json(receipt_path, "receipt_json")
    zero = closure["zero_world_qualification"]
    require(
        receipt["schema_version"]
        == "sporespore_qsdk_r24d10_exact_step_numerical_telemetry_zero_world_receipt_v1"
        and receipt["ok"] is True
        and receipt["gate_id"] == "QSDK-R24D10"
        and receipt["question_class"] == "development"
        and receipt["status"] == closure["status"]
        and receipt["source"]["head"] == SOURCE_COMMIT
        and receipt["source"]["upstream"] == SOURCE_COMMIT
        and receipt["source"]["cached_origin_main"] == SOURCE_COMMIT
        and receipt["source"]["live_origin_main"] == SOURCE_COMMIT
        and receipt["source"]["worktree_clean"] is True
        and receipt["validation_manifest"]["raw_sha256"]
        == closure["source"]["validation_manifest"]["raw_sha256"],
        "receipt_source_and_status",
    )
    stages = receipt["stages"]
    require(
        len(stages) == 7
        and [stage["index"] for stage in stages] == list(range(1, 8))
        and [stage["name"] for stage in stages] == EXPECTED_STAGE_NAMES
        and abs(sum(stage["duration_s"] for stage in stages) - zero["total_stage_duration_s"])
        < 1e-9,
        "receipt_stage_population",
    )

    attempt = load_json(RUN_ROOT / "attempt.json", "attempt_json")
    require(
        attempt["schema_version"] == "sporespore_qsdk_r24d10_zero_world_attempt_v1"
        and attempt["status"] == "consumed_before_first_stage"
        and attempt["source_commit"] == SOURCE_COMMIT
        and attempt["zero_world_attempt_count"] == 1
        and attempt["same_source_rerun_allowed"] is False
        and attempt["world_attempt_count"] == 0
        and attempt["world_build_count"] == 0
        and attempt["solver_step_count"] == 0,
        "attempt_identity_and_counts",
    )

    worker = receipt["worker"]["receipt"]
    require(
        worker["ok"] is True
        and worker["execution_nonce"] == zero["execution_nonce"]
        and worker["engine_freeze_matches"] is True
        and worker["fixture_description_matches"] is True
        and worker["invalid_rid_refused"] is True
        and worker["template_shape_matches"] is True
        and worker["template_identity_matches"] is True
        and worker["synthetic_first_retained_space_step_sequence"] == 1
        and worker["synthetic_last_retained_space_step_sequence"] == 20
        and worker["synthetic_pre_sample_physics_frame_count"] == 0
        and worker["synthetic_envelope_is_physical_observation"] is False
        and worker["world_attempt_count"] == 0
        and worker["world_build_count"] == 0
        and worker["solver_step_count"] == 0,
        "worker_receipt",
    )
    evaluation = receipt["evaluation"]["receipt"]
    exact = evaluation["exact_step_execution"]
    require(
        evaluation["ok"] is True
        and evaluation["evidence_kind"] == "synthetic_zero_world"
        and evaluation["execution_valid"] is True
        and evaluation["native_numerical_telemetry_characterized"] is False
        and exact["first_retained_space_step_sequence"] == 1
        and exact["last_retained_space_step_sequence"] == 20
        and exact["observed_retained_awake_space_step_token_count"] == 20
        and exact["token_derived_physics_step_count"] == 20
        and exact["pre_sample_physics_frame_count"] == 0
        and exact["extra_unretained_post_activation_step_count"] == 0
        and exact["all_declared_initial_real_t_projections_preserved"] is True,
        "evaluation_receipt",
    )
    require(
        receipt["actual_counts"]
        == {
            "active_physics_object_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_world_count": 0,
        },
        "receipt_actual_counts",
    )
    require(
        receipt["claims"]
        == {
            "complete_zero_world_gate_passed": True,
            "exact_step_schedule_source_qualified": True,
            "physical_characterization_executed": False,
            "native_numerical_telemetry_characterized": False,
            "numerical_accuracy_accepted": False,
            "instrumented_profile_promoted": False,
            "recovery_world_opened": False,
            "prone_to_standing_world_opened": False,
            "turning_claim_changed": False,
            "cross_engine_equivalence_claimed": False,
            "physical_authorization": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "receipt_claims",
    )

    cas_references = walk_cas(receipt)
    require(len(cas_references) == 15, "embedded_cas_reference_count")
    verified: set[str] = set()
    for path, cas in cas_references:
        digest = cas["sha256"]
        if digest not in verified:
            verify_cas(cas, f"embedded_cas:{path}")
            verified.add(digest)
    require(len(verified) == 12, "embedded_unique_cas_digest_count")

    receipt_cas = {
        "sha256": zero["receipt_raw_sha256"],
        "byte_length": zero["receipt_byte_length"],
        "payload_path": zero["receipt_cas_payload_path"],
        "manifest_path": zero["receipt_cas_manifest_path"],
    }
    receipt_cas["schema_version"] = "sporespore_content_addressed_artifact_receipt_v1"
    verify_cas(receipt_cas, "receipt_cas")

    mutations: list[tuple[str, Any]] = [
        ("schema_version", "mutated"),
        ("closure_id", "QSDK-R24D10-ZW1-MUTATED"),
        ("status", "failed"),
        ("result_class", "physical_characterization"),
        ("source.commit", "0" * 40),
        ("source.tree_git_oid", "0" * 40),
        ("source.clean_pushed_before_qualification", False),
        ("source.validation_manifest.raw_sha256", "sha256:" + "0" * 64),
        ("source.validation_manifest.source_binding_count", 18),
        ("predecessor_authority.raw_sha256", "sha256:" + "1" * 64),
        ("predecessor_authority.r24d9_result_reused_or_reinterpreted", True),
        ("runtime.godot_source_commit", "0" * 40),
        ("runtime.combined_patch_raw_sha256", "sha256:" + "2" * 64),
        ("runtime.console_binary_raw_sha256", "sha256:" + "3" * 64),
        ("runtime.result_reuse_authority", True),
        ("zero_world_qualification.receipt_raw_sha256", "sha256:" + "4" * 64),
        ("zero_world_qualification.stage_count", 6),
        ("zero_world_qualification.same_source_zero_world_rerun_allowed", True),
        ("zero_world_qualification.world_attempt_count", 1),
        ("zero_world_worker.invalid_rid_refused", False),
        ("zero_world_worker.synthetic_envelope_is_physical_observation", True),
        ("zero_world_evaluation.first_retained_space_step_sequence", 2),
        ("zero_world_evaluation.last_retained_space_step_sequence", 21),
        ("zero_world_evaluation.token_derived_physics_step_count", 19),
        ("zero_world_evaluation.pre_sample_physics_frame_count", 1),
        ("zero_world_evaluation.all_declared_initial_real_t_projections_preserved", False),
        ("retention.run_file_count", 22),
        ("retention.run_unique_content_digest_count", 18),
        ("statistical_claim_boundary.empirical_acceptance_threshold_count", 1),
        ("immutability.same_source_zero_world_rerun_forbidden", False),
        ("next_boundary.physical_execution_authorized", True),
        ("claims.native_numerical_telemetry_characterized", True),
        ("claims.prone_to_standing_world_opened", True),
        ("claims.release_authority", True),
    ]
    rejected = 0
    for path, value in mutations:
        candidate = copy.deepcopy(closure)
        set_nested(candidate, path, value)
        if not semantic_vector(candidate):
            rejected += 1
    require(rejected == len(mutations), "semantic_mutation_controls")
    require(rejected >= closure["audit_contract"]["minimum_semantic_mutation_rejection_count"], "minimum_mutations")

    if not args.allow_prospective_uncommitted:
        require(git("status", "--short") == "", "dirty_worktree")
        for relative in (CLOSURE_RELATIVE, AUDIT_RELATIVE):
            require(
                historical_or_head_bytes(relative) == (REPO_ROOT / relative).read_bytes(),
                f"committed_current_file:{relative.as_posix()}",
            )

    print(
        "QSDK_R24D10_EXACT_STEP_ZERO_WORLD_POSITIVE_CLOSURE_PASS "
        f"mutations={rejected} source_bindings={len(bindings)} "
        f"run_files={len(inventory)} unique_digests=19 "
        f"cas_references={len(cas_references)} unique_cas={len(verified)} "
        "worlds=0 builds=0 solver_steps=0 physical_authority=false"
    )
    return 0


def historical_or_head_bytes(relative: Path) -> bytes:
    return git("show", f"HEAD:{relative.as_posix()}", binary=True)  # type: ignore[return-value]


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditFailure as exc:
        print(str(exc))
        raise SystemExit(1) from exc
