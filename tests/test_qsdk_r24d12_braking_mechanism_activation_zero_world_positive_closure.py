#!/usr/bin/env python3
"""Audit the immutable QSDK-R24D12 complete zero-world positive closure."""

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
SOURCE_COMMIT = "7b807819a6ed1d1864f5a5410bbb9b17667624e1"
SOURCE_TREE = "b07a5f72720e69d542d0c44bd932dde63e4546a8"
GODOT_COMMIT = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
PATCH_SHA = "sha256:9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
RUN_ID = "20260826T220001659Z-7b807819-1c77888f5b1c"
RUN_ROOT = EVIDENCE_ROOT / (
    "qsdk-r24d12-braking-mechanism-activation/zero-world/" + RUN_ID
)
RECEIPT_SHA = "sha256:f8fd379f95f89197b1742efeeed41b55d0c71948634aaaf6d7a62d661f3aeb77"
RECEIPT_BYTES = 20588
DECLARATION_RELATIVE = Path(
    "sdk/recovery/"
    "r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1.json"
)
MANIFEST_RELATIVE = Path(
    "sdk/recovery/"
    "r24d12_godot_jolt_braking_mechanism_activation_validation_manifest.json"
)
CLOSURE_RELATIVE = Path(
    "sdk/recovery/"
    "r24d12_godot_jolt_braking_mechanism_activation_"
    "zero_world_positive_closure_v1.json"
)
AUDIT_RELATIVE = Path(
    "tests/test_qsdk_r24d12_braking_mechanism_activation_"
    "zero_world_positive_closure.py"
)
EXPECTED_STAGE_NAMES = [
    "r24d12_freeze_and_mutation_audit",
    "r24d10_cold_baseline_and_exact_runtime_reuse_key",
    "evaluator_shaped_zero_world_template",
    "custom_runtime_zero_object_worker",
    "independent_synthetic_evaluation",
]
EXPECTED_CLAIMS = {
    "complete_zero_world_gate_passed": True,
    "corrected_activation_route_source_qualified": True,
    "exact_runtime_reuse_key_passed": True,
    "physical_characterization_executed": False,
    "braking_mechanism_activated": False,
    "numerical_accuracy_accepted": False,
    "instrumented_profile_promoted": False,
    "stock_godot_profile_promoted": False,
    "native_capability_conjunction_complete": False,
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
        raise AuditFailure(f"QSDK-R24D12 zero-world positive closure: {code}")


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
    return git(  # type: ignore[return-value]
        "show", f"{SOURCE_COMMIT}:{relative.as_posix()}", binary=True
    )


def is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
        return True
    except ValueError:
        return False


def verify_cas(cas: dict[str, Any], code: str) -> None:
    require(
        cas.get("schema_version")
        == "sporespore_content_addressed_artifact_receipt_v1",
        f"{code}:schema",
    )
    digest = cas.get("sha256")
    byte_length = cas.get("byte_length")
    require(
        isinstance(digest, str)
        and digest.startswith("sha256:")
        and len(digest) == 71,
        f"{code}:digest",
    )
    require(type(byte_length) is int and byte_length >= 0, f"{code}:byte_length")
    payload = Path(str(cas.get("payload_path", "")))
    manifest_path = Path(str(cas.get("manifest_path", "")))
    require(is_within(payload, EVIDENCE_ROOT / "artifacts"), f"{code}:payload_scope")
    require(
        is_within(manifest_path, EVIDENCE_ROOT / "artifacts"),
        f"{code}:manifest_scope",
    )
    require(payload.is_file(), f"{code}:payload_missing")
    require(manifest_path.is_file(), f"{code}:manifest_missing")
    require(file_receipt(payload) == (digest, byte_length), f"{code}:payload_bytes")
    manifest = load_json(manifest_path, f"{code}:manifest")
    require(
        manifest
        == {
            "schema_version": "sporespore_content_addressed_artifact_manifest_v1",
            "algorithm": "sha256",
            "sha256": digest,
            "byte_length": byte_length,
            "payload_name": "payload.bin",
            "media_type": manifest.get("media_type"),
        },
        f"{code}:manifest_semantics",
    )


def walk_cas(value: Any, path: str = "root") -> list[tuple[str, dict[str, Any]]]:
    found: list[tuple[str, dict[str, Any]]] = []
    if isinstance(value, dict):
        if value.get("schema_version") == "sporespore_content_addressed_artifact_receipt_v1":
            found.append((path, value))
        for key, child in value.items():
            found.extend(walk_cas(child, f"{path}.{key}"))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            found.extend(walk_cas(child, f"{path}[{index}]"))
    return found


def set_nested(document: dict[str, Any], path: str, value: Any) -> None:
    parts = path.split(".")
    target: Any = document
    for part in parts[:-1]:
        target = target[part]
    target[parts[-1]] = value


def semantic_vector(candidate: dict[str, Any], audit_sha: str) -> bool:
    try:
        source = candidate["source"]
        predecessor = candidate["predecessor_authority"]
        diagnosis = candidate["source_diagnosis"]
        runtime = candidate["runtime_reuse"]
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
            == "sporespore_qsdk_r24d12_braking_mechanism_activation_zero_world_positive_closure_v1"
            and candidate["closure_id"] == "QSDK-R24D12-ZW1-CLOSURE"
            and candidate["gate_id"] == "QSDK-R24D12"
            and candidate["work_id"]
            == "QSDK-R24D12-GODOT-JOLT-BRAKING-MECHANISM-ACTIVATION-CHARACTERIZATION"
            and candidate["question_class"] == "development"
            and candidate["status"]
            == "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization"
            and candidate["result_class"]
            == "valid_complete_zero_world_source_runtime_reuse_and_synthetic_shape_qualification"
            and source["remote"] == EXPECTED_REMOTE
            and source["commit"] == SOURCE_COMMIT
            and source["tree_git_oid"] == SOURCE_TREE
            and source["clean_pushed_before_qualification"] is True
            and source["local_upstream_cached_live_equal_before_qualification"] is True
            and source["worktree_count"] == 1
            and source["preregistration"]["raw_sha256"]
            == "sha256:b7df002a1886b9e690a887747039b0414606135e4673a0ace612436151bacc3c"
            and source["validation_manifest"]["raw_sha256"]
            == "sha256:de7a04123cb25f14f37056acb96eabc031daccc63c1cfc8243a8fd27d75116a5"
            and source["validation_manifest"]["source_binding_count"] == 15
            and predecessor["gate_id"] == "QSDK-R24D11"
            and predecessor["raw_sha256"]
            == "sha256:7418141ac1ac5fd4a6fab8a34956346ccd721792630025939e837f7b698440a4"
            and predecessor["result_rewritten_or_rethresholded"] is False
            and predecessor["same_source_rerun"] is False
            and diagnosis["godot_source_commit"] == GODOT_COMMIT
            and diagnosis["raw_sha256"]
            == "sha256:36842eb8765e1a4abe9eb2fbb20d85ab14b653c7333bd043beb2c6cab5392408"
            and diagnosis["physical_mechanism_activation_proved_by_source_alone"] is False
            and runtime["combined_patch_raw_sha256"] == PATCH_SHA
            and runtime["console_binary_raw_sha256"]
            == "sha256:ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
            and runtime["engine_binary_raw_sha256"]
            == "sha256:2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
            and runtime["engine_build_reused"] is True
            and runtime["campaign_result_reused"] is False
            and runtime["physical_evidence_reused"] is False
            and runtime["reuse_key_passed"] is True
            and zero["run_id"] == RUN_ID
            and zero["receipt_raw_sha256"] == RECEIPT_SHA
            and zero["receipt_byte_length"] == RECEIPT_BYTES
            and zero["stage_count"] == 5
            and zero["stage_pass_count"] == 5
            and zero["stage_names_in_order"] == EXPECTED_STAGE_NAMES
            and zero["same_source_zero_world_attempt_count"] == 1
            and zero["same_source_zero_world_rerun_allowed"] is False
            and zero["active_physics_object_count"] == 0
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
            and evaluation["cell_count"] == 4
            and evaluation["retained_sample_count"] == 4
            and evaluation["synthetic_motor_enabled_braking_witness_count"] == 2
            and evaluation["synthetic_motor_disabled_zero_witness_count"] == 2
            and evaluation["native_braking_mechanism_activation_observed"] is False
            and evaluation["numerical_accuracy_accepted"] is False
            and retention["run_file_count"] == 19
            and retention["run_unique_content_digest_count"] == 15
            and retention["run_total_byte_length"] == 138204
            and retention["receipt_embedded_cas_reference_count"] == 14
            and retention["receipt_embedded_unique_cas_digest_count"] == 11
            and len(retention["complete_run_inventory"]) == 19
            and statistics["empirical_acceptance_threshold_count"] == 0
            and statistics["superiority_margin_count"] == 0
            and statistics["equivalence_or_non_inferiority_margin_count"] == 0
            and statistics["physical_sample_count"] == 0
            and statistics["population_claim_count"] == 0
            and immutable["same_source_zero_world_rerun_forbidden"] is True
            and immutable["observed_receipt_or_evaluation_rewritten"] is False
            and immutable["campaign_result_reuse_authority"] is False
            and next_boundary["physical_execution_authorized"] is False
            and next_boundary["distinct_explicit_physical_authorization_required"] is True
            and next_boundary["next_question_class"] == "development"
            and next_boundary["canonical_prone_to_standing_world_authorized"] is False
            and audit["implementation_path"] == AUDIT_RELATIVE.as_posix()
            and audit["implementation_raw_sha256"] == audit_sha
            and audit["minimum_semantic_mutation_rejection_count"] == 30
            and candidate["claims"] == EXPECTED_CLAIMS
        )
    except (KeyError, TypeError, ValueError):
        return False


def validate_inventory(closure: dict[str, Any]) -> list[dict[str, Any]]:
    expected = closure["retention"]["complete_run_inventory"]
    require(isinstance(expected, list), "inventory_not_list")
    observed: list[dict[str, Any]] = []
    for path in sorted(p for p in RUN_ROOT.rglob("*") if p.is_file()):
        digest, byte_length = file_receipt(path)
        observed.append(
            {
                "path": path.relative_to(RUN_ROOT).as_posix(),
                "raw_sha256": digest,
                "byte_length": byte_length,
            }
        )
    require(observed == expected, "complete_run_inventory")
    require(len({item["raw_sha256"] for item in observed}) == 15, "unique_digests")
    require(sum(item["byte_length"] for item in observed) == 138204, "total_bytes")
    return observed


def validate_source_bindings(closure: dict[str, Any]) -> list[dict[str, Any]]:
    manifest_bytes = historical_blob(MANIFEST_RELATIVE)
    manifest = load_json_bytes(manifest_bytes, "historical_manifest")
    require(
        sha256_bytes(manifest_bytes)
        == closure["source"]["validation_manifest"]["raw_sha256"],
        "historical_manifest_digest",
    )
    bindings = manifest.get("source_bindings")
    require(isinstance(bindings, list) and len(bindings) == 15, "source_bindings")
    for binding in bindings:
        relative = Path(binding["path"])
        data = historical_blob(relative)
        require(sha256_bytes(data) == binding["raw_sha256"], f"binding_sha:{relative}")
        require(len(data) == binding["byte_length"], f"binding_bytes:{relative}")
        oid = git("rev-parse", f"{SOURCE_COMMIT}:{relative.as_posix()}")
        require(oid == binding["git_blob_oid"], f"binding_blob:{relative}")
    return bindings


def validate_receipt(closure: dict[str, Any]) -> tuple[dict[str, Any], int, int]:
    receipt_path = RUN_ROOT / "receipt.json"
    require(file_receipt(receipt_path) == (RECEIPT_SHA, RECEIPT_BYTES), "receipt_bytes")
    receipt = load_json(receipt_path, "receipt")
    require(receipt["ok"] is True, "receipt_not_ok")
    require(receipt["gate_id"] == "QSDK-R24D12", "receipt_gate")
    require(receipt["question_class"] == "development", "receipt_question")
    require(
        receipt["status"]
        == "complete_zero_world_gate_passed_physical_execution_still_forbidden_pending_explicit_separate_authorization",
        "receipt_status",
    )
    source = receipt["source"]
    require(
        source["head"] == SOURCE_COMMIT
        and source["upstream"] == SOURCE_COMMIT
        and source["cached_origin_main"] == SOURCE_COMMIT
        and source["live_origin_main"] == SOURCE_COMMIT
        and source["worktree_count"] == 1
        and source["worktree_clean"] is True,
        "receipt_source_equality",
    )
    reuse = receipt["runtime_reuse_key"]
    require(
        reuse["godot_source_commit"] == GODOT_COMMIT
        and reuse["combined_patch_raw_sha256"] == PATCH_SHA
        and reuse["engine_build_reused"] is True
        and reuse["campaign_result_reused"] is False
        and reuse["physical_evidence_reused"] is False,
        "receipt_runtime_reuse",
    )
    stages = receipt["stages"]
    require([stage["name"] for stage in stages] == EXPECTED_STAGE_NAMES, "stage_order")
    require([stage["index"] for stage in stages] == [1, 2, 3, 4, 5], "stage_indexes")
    require(
        round(sum(float(stage["duration_s"]) for stage in stages), 6)
        == closure["zero_world_qualification"]["total_stage_duration_s"],
        "stage_duration_sum",
    )
    attempt = load_json(RUN_ROOT / "attempt.json", "attempt")
    require(
        attempt["status"] == "consumed_before_first_stage"
        and attempt["source_commit"] == SOURCE_COMMIT
        and attempt["zero_world_attempt_count"] == 1
        and attempt["world_attempt_count"] == 0
        and attempt["world_build_count"] == 0
        and attempt["solver_step_count"] == 0
        and attempt["same_source_rerun_allowed"] is False,
        "attempt_semantics",
    )
    worker = receipt["worker"]["receipt"]
    require(
        worker["ok"] is True
        and worker["execution_nonce"]
        == closure["zero_world_qualification"]["execution_nonce"]
        and worker["engine_freeze_matches"] is True
        and worker["fixture_description_matches"] is True
        and worker["invalid_rid_refused"] is True
        and worker["template_shape_matches"] is True
        and worker["template_identity_matches"] is True
        and worker["template_byte_passthrough"] is True
        and worker["synthetic_embedded_physics_step_count"] == 1
        and worker["synthetic_embedded_retained_sample_count"] == 4
        and worker["synthetic_envelope_is_physical_observation"] is False
        and worker["world_attempt_count"] == 0
        and worker["world_build_count"] == 0
        and worker["solver_step_count"] == 0,
        "worker_receipt",
    )
    evaluation = load_json(RUN_ROOT / "synthetic-evaluation.json", "evaluation")
    require(
        evaluation["ok"] is True
        and evaluation["evidence_kind"] == "synthetic_zero_world"
        and evaluation["execution_valid"] is True
        and evaluation["summary"]["cell_count"] == 4
        and evaluation["summary"]["retained_sample_count"] == 4
        and evaluation["summary"]["motor_enabled_braking_witness_count"] == 2
        and evaluation["summary"]["motor_disabled_zero_witness_count"] == 2
        and evaluation["summary"]["native_braking_mechanism_activation_observed"] is False
        and evaluation["numerical_accuracy_accepted"] is False
        and evaluation["instrumented_profile_promoted"] is False
        and evaluation["release_authority"] is False,
        "synthetic_evaluation",
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
            "corrected_activation_route_source_qualified": True,
            "exact_runtime_reuse_key_passed": True,
            "physical_characterization_executed": False,
            "braking_mechanism_activated": False,
            "numerical_accuracy_accepted": False,
            "instrumented_profile_promoted": False,
            "stock_godot_profile_promoted": False,
            "recovery_world_opened": False,
            "prone_to_standing_world_opened": False,
            "q_sdk_r24_satisfied": False,
            "physical_authorization": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "receipt_claims",
    )
    cas_references = walk_cas(receipt)
    require(len(cas_references) == 14, "embedded_cas_reference_count")
    verified: set[str] = set()
    for path, cas in cas_references:
        verify_cas(cas, f"embedded_cas:{path}")
        verified.add(cas["sha256"])
    require(len(verified) == 11, "embedded_unique_cas_digest_count")
    receipt_cas = {
        "schema_version": "sporespore_content_addressed_artifact_receipt_v1",
        "sha256": closure["zero_world_qualification"]["receipt_raw_sha256"],
        "byte_length": closure["zero_world_qualification"]["receipt_byte_length"],
        "payload_path": closure["zero_world_qualification"]["receipt_cas_payload_path"],
        "manifest_path": closure["zero_world_qualification"]["receipt_cas_manifest_path"],
    }
    verify_cas(receipt_cas, "receipt_cas")
    return receipt, len(cas_references), len(verified)


def mutation_cases() -> list[tuple[str, Any]]:
    return [
        ("schema_version", "mutated"),
        ("closure_id", "QSDK-R24D12-ZW1-MUTATED"),
        ("question_class", "finite_decision"),
        ("status", "failed"),
        ("result_class", "physical_characterization"),
        ("source.commit", "0" * 40),
        ("source.tree_git_oid", "0" * 40),
        ("source.clean_pushed_before_qualification", False),
        ("source.preregistration.raw_sha256", "sha256:" + "1" * 64),
        ("source.validation_manifest.source_binding_count", 14),
        ("predecessor_authority.result_rewritten_or_rethresholded", True),
        ("source_diagnosis.raw_sha256", "sha256:" + "2" * 64),
        ("source_diagnosis.physical_mechanism_activation_proved_by_source_alone", True),
        ("runtime_reuse.combined_patch_raw_sha256", "sha256:" + "3" * 64),
        ("runtime_reuse.console_binary_raw_sha256", "sha256:" + "4" * 64),
        ("runtime_reuse.engine_build_reused", False),
        ("runtime_reuse.campaign_result_reused", True),
        ("zero_world_qualification.receipt_raw_sha256", "sha256:" + "5" * 64),
        ("zero_world_qualification.stage_count", 4),
        ("zero_world_qualification.same_source_zero_world_rerun_allowed", True),
        ("zero_world_qualification.world_attempt_count", 1),
        ("zero_world_worker.invalid_rid_refused", False),
        ("zero_world_worker.synthetic_envelope_is_physical_observation", True),
        ("zero_world_evaluation.cell_count", 3),
        ("zero_world_evaluation.native_braking_mechanism_activation_observed", True),
        ("zero_world_evaluation.numerical_accuracy_accepted", True),
        ("retention.run_file_count", 18),
        ("retention.run_unique_content_digest_count", 14),
        ("retention.receipt_embedded_cas_reference_count", 13),
        ("statistical_claim_boundary.empirical_acceptance_threshold_count", 1),
        ("immutability.same_source_zero_world_rerun_forbidden", False),
        ("immutability.campaign_result_reuse_authority", True),
        ("next_boundary.physical_execution_authorized", True),
        ("next_boundary.canonical_prone_to_standing_world_authorized", True),
        ("audit_contract.minimum_semantic_mutation_rejection_count", 29),
        ("claims.braking_mechanism_activated", True),
        ("claims.prone_to_standing_world_opened", True),
        ("claims.release_authority", True),
    ]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--allow-prospective-uncommitted", action="store_true")
    args = parser.parse_args()

    require(REPO_ROOT.is_dir(), "repo_missing")
    require(RUN_ROOT.is_dir(), "run_root_missing")
    require(git("rev-parse", "--show-toplevel").replace("\\", "/") == REPO_ROOT.as_posix(), "repo_root")
    require(git("remote", "get-url", "origin") == EXPECTED_REMOTE, "remote")
    require(git("show", "-s", "--format=%T", SOURCE_COMMIT) == SOURCE_TREE, "source_tree")

    closure = load_json(REPO_ROOT / CLOSURE_RELATIVE, "closure")
    audit_sha = sha256_bytes((REPO_ROOT / AUDIT_RELATIVE).read_bytes())
    require(semantic_vector(closure, audit_sha), "closure_semantic_vector")
    bindings = validate_source_bindings(closure)
    inventory = validate_inventory(closure)
    _, cas_count, unique_cas_count = validate_receipt(closure)

    attempts = []
    for directory in RUN_ROOT.parent.iterdir():
        attempt_path = directory / "attempt.json"
        if not directory.is_dir() or not attempt_path.is_file():
            continue
        attempt = load_json(attempt_path, f"attempt_population:{directory.name}")
        if attempt.get("source_commit") == SOURCE_COMMIT:
            attempts.append(directory.name)
    require(attempts == [RUN_ID], "same_source_zero_world_attempt_population")

    rejected = 0
    for path, value in mutation_cases():
        candidate = copy.deepcopy(closure)
        set_nested(candidate, path, value)
        if not semantic_vector(candidate, audit_sha):
            rejected += 1
    require(rejected == len(mutation_cases()), "semantic_mutation_controls")
    require(
        rejected >= closure["audit_contract"]["minimum_semantic_mutation_rejection_count"],
        "minimum_mutations",
    )

    if not args.allow_prospective_uncommitted:
        require(git("status", "--short") == "", "dirty_worktree")
        for relative in (CLOSURE_RELATIVE, AUDIT_RELATIVE):
            current = (REPO_ROOT / relative).read_bytes()
            committed = git("show", f"HEAD:{relative.as_posix()}", binary=True)
            require(committed == current, f"committed_current_file:{relative.as_posix()}")

    print(
        "QSDK_R24D12_BRAKING_MECHANISM_ZERO_WORLD_POSITIVE_CLOSURE_PASS "
        f"mutations={rejected} source_bindings={len(bindings)} "
        f"run_files={len(inventory)} unique_digests=15 "
        f"cas_references={cas_count} unique_cas={unique_cas_count} "
        "worlds=0 builds=0 solver_steps=0 physical_authority=false"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditFailure as exc:
        print(str(exc))
        raise SystemExit(1) from exc
