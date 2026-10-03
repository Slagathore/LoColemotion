"""Audit retained QSDK-R24D22 evidence; evaluator replay is opt-in."""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    canonical_bytes,
    exact,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_current_git_identity,
    verify_current_raw_bindings,
    verify_frozen_manifest,
    verify_retained_commit,
)


CLOSURE_PATH = ROOT / "sdk/recovery/r24d22_engine_neutral_recovery_morphology_closure_v1.json"
SOURCE_COMMIT = "2789f13de7a0f5ba83fe17f919bbc57c2d784080"


def audit(replay_evaluator: bool) -> None:
    closure = load(CLOSURE_PATH)
    exact(
        closure["schema_version"],
        "sporespore_qsdk_r24d22_engine_neutral_recovery_morphology_closure_v1",
        "SCHEMA",
    )
    exact(closure["gate_id"], "QSDK-R24D22", "GATE")
    exact(closure["question_class"], "development", "QUESTION_CLASS")
    exact(
        closure["ledger_scope"],
        {
            "subsystem": "recovery",
            "engine_scope": "engine_neutral_core",
            "authority_mode": "zero_world_development_closure",
            "question_class": "development",
        },
        "LEDGER_SCOPE",
    )
    exact(closure["source_commit"], SOURCE_COMMIT, "SOURCE_COMMIT")
    verify_retained_commit(ROOT, SOURCE_COMMIT, closure["source_parent_commit"])

    artifact_commit = closure["retained_artifact_commit"]
    git(ROOT, "cat-file", "-e", f"{artifact_commit}^{{commit}}")
    exact(
        git(ROOT, "show", "-s", "--format=%P", artifact_commit),
        closure["retained_artifact_parent_commit"],
        "ARTIFACT_PARENT",
    )
    descendant = git(ROOT, "rev-parse", "HEAD")
    assert isinstance(descendant, str)
    git(ROOT, "merge-base", "--is-ancestor", artifact_commit, descendant)

    support_relative = closure["audit_support_path"]
    support_raw = source_bytes(ROOT, artifact_commit, support_relative)
    exact(
        git(ROOT, "rev-parse", f"{artifact_commit}:{support_relative}"),
        closure["audit_support_git_blob_oid"],
        "AUDIT_SUPPORT_OID",
    )
    exact(len(support_raw), closure["audit_support_git_blob_byte_length"], "AUDIT_SUPPORT_LENGTH")
    exact(sha256(support_raw), closure["audit_support_git_blob_raw_sha256"], "AUDIT_SUPPORT_HASH")
    exact(
        git(ROOT, "rev-parse", f"HEAD:{support_relative}"),
        closure["audit_support_git_blob_oid"],
        "CURRENT_AUDIT_SUPPORT_OID",
    )

    contract_raw = source_bytes(ROOT, SOURCE_COMMIT, closure["contract_path"])
    evaluator_raw = source_bytes(ROOT, SOURCE_COMMIT, closure["evaluator_path"])
    source_audit_raw = source_bytes(ROOT, SOURCE_COMMIT, closure["source_audit_path"])
    exact(sha256(contract_raw), closure["contract_raw_sha256"], "CONTRACT_HASH")
    exact(sha256(evaluator_raw), closure["evaluator_raw_sha256"], "EVALUATOR_HASH")
    exact(sha256(source_audit_raw), closure["source_audit_raw_sha256"], "SOURCE_AUDIT_HASH")
    contract = loads(contract_raw)
    exact(contract["question_class"], "development", "CONTRACT_CLASS")
    exact(contract["physical_question_declared"], False, "CONTRACT_PHYSICAL")
    exact(contract["decision_rule"]["feasibility_threshold_m"], 0.0, "THRESHOLD")
    require(bool(contract["decision_rule"]["threshold_provenance"].strip()), "PROVENANCE")
    require(bool(contract["decision_rule"]["threshold_adequacy"].strip()), "ADEQUACY")
    exact(contract["decision_rule"]["new_margin_count"], 0, "MARGINS")
    exact(contract["decision_rule"]["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")

    manifest = verify_frozen_manifest(
        ROOT,
        SOURCE_COMMIT,
        contract["source_inventory"],
        closure["frozen_source_manifest"],
    )
    manifest_paths = {entry["path"] for entry in manifest}
    for binding in contract["implementation_source_bindings"]:
        require(binding["path"] in manifest_paths, f"BOUND_PATH:{binding['path']}")
        require(binding["byte_length"] > 0, f"BOUND_LENGTH:{binding['path']}")
        require(
            isinstance(binding["raw_sha256"], str)
            and binding["raw_sha256"].startswith("sha256:")
            and len(binding["raw_sha256"]) == 71,
            f"BOUND_HASH_SHAPE:{binding['path']}",
        )

    decision_relative = closure["decision_path"]
    decision_raw = source_bytes(ROOT, artifact_commit, decision_relative)
    exact(
        git(ROOT, "rev-parse", f"{artifact_commit}:{decision_relative}"),
        closure["decision_git_blob_oid"],
        "DECISION_OID",
    )
    exact(len(decision_raw), closure["decision_git_blob_byte_length"], "DECISION_RAW_LENGTH")
    exact(sha256(decision_raw), closure["decision_git_blob_raw_sha256"], "DECISION_RAW_HASH")
    exact(
        git(ROOT, "rev-parse", f"HEAD:{decision_relative}"),
        closure["decision_git_blob_oid"],
        "CURRENT_DECISION_OID",
    )
    decision = loads(decision_raw)
    decision_canonical = canonical_bytes(decision)
    exact(len(decision_canonical), closure["decision_canonical_byte_length"], "DECISION_LENGTH")
    exact(sha256(decision_canonical), closure["decision_canonical_sha256"], "DECISION_HASH")
    exact(decision["gate_id"], "QSDK-R24D22", "DECISION_GATE")
    exact(decision["question_class"], "development", "DECISION_CLASS")
    exact(decision["support_status"], "supported_exact", "SUPPORT")
    exact(decision["feasibility_threshold_m"], 0.0, "DECISION_THRESHOLD")
    exact(decision["minimum_limb_ground_clearance_m"], 0.01625237411795359, "CLEARANCE")
    exact(decision["mutation_control_count"], 8, "MUTATION_COUNT")
    exact(decision["mutation_controls_passed"], 8, "MUTATIONS_PASSED")
    population = contract["evidence_population"]
    for key in (
        "recovery_descriptor_sha256",
        "base_descriptor_sha256",
        "base_morphology_spec_sha256",
        "recovery_morphology_spec_sha256",
    ):
        exact(decision[key], population[key], f"IDENTITY_{key.upper()}")
    require(all(item["passed"] is True for item in decision["mutation_controls"]), "MUTATION_FAILURE")
    exact(len(decision["ordered_limb_geometry"]), 4, "LIMB_COUNT")
    require(all(item["folds_outward_from_torso"] for item in decision["ordered_limb_geometry"]), "OUTWARD")
    require(all(item["ground_nonpenetrating"] for item in decision["ordered_limb_geometry"]), "NONPENETRATION")

    zero_counts = (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    )
    for key in zero_counts:
        exact(decision[key], 0, f"DECISION_{key.upper()}")
        exact(closure["qualification"][key], 0, f"QUALIFICATION_{key.upper()}")
    for key in (
        "physical_acceptance_authority",
        "prone_to_standing_claimed",
        "recovery_behavior_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "release_authority",
    ):
        exact(decision[key], False, f"DECISION_{key.upper()}")

    summary = closure["decision_summary"]
    exact(summary["support_status"], decision["support_status"], "SUMMARY_SUPPORT")
    exact(summary["minimum_limb_ground_clearance_m"], decision["minimum_limb_ground_clearance_m"], "SUMMARY_CLEARANCE")
    exact(summary["mutation_controls_passed"], decision["mutation_controls_passed"], "SUMMARY_MUTATIONS")
    exact(closure["sdk_status"]["sdk1_completed_steps"], 11, "SDK1_SCORE")
    exact(closure["sdk_status"]["full_program_completed_steps"], 11, "PROGRAM_SCORE")
    exact(closure["next_boundary"]["gate_id"], "QSDK-R24D23", "NEXT_GATE")
    exact(closure["next_boundary"]["question_class"], "development", "NEXT_CLASS")
    exact(closure["next_boundary"]["held_out_cells_remain_sealed"], True, "NEXT_HELDOUT")
    exact(closure["claim_boundary"]["finite_geometry_decision_observed"], True, "CLAIM_DECISION")
    for key in (
        "native_model_construction_proven",
        "native_initializer_proven",
        "controller_physical_viability_proven",
        "physical_question_opened",
        "prone_to_standing_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(closure["claim_boundary"][key], False, f"CLAIM_{key.upper()}")

    qualification = closure["qualification"]
    exact(qualification["targeted_rust_tests_passed"], 5, "RUST_TESTS")
    exact(qualification["python_ctypes_required_tests_passed"], 1, "CTYPES_TESTS")
    exact(qualification["versioning_tests_passed"], 6, "VERSIONING_TESTS")
    exact(qualification["official_evaluator_invocation_count"], 1, "OFFICIAL_INVOCATIONS")
    exact(qualification["retention_capture_replay_count"], 1, "CAPTURE_REPLAYS")
    exact(qualification["retention_capture_replay_exactly_equal"], True, "CAPTURE_EQUAL")
    exact(len(closure["integration_observations"]), 3, "INTEGRATION_OBSERVATIONS")
    require(all(not item["scientific_result_consumed"] for item in closure["integration_observations"]), "INTEGRATION_CONSUMED")

    if replay_evaluator:
        verify_current_git_identity(ROOT, SOURCE_COMMIT, contract["source_inventory"])
        verify_current_raw_bindings(ROOT, contract["implementation_source_bindings"])
        library = ROOT / qualification["core_library_path"]
        require(library.is_file(), "REPLAY_LIBRARY_MISSING")
        library_raw = library.read_bytes()
        exact(len(library_raw), qualification["core_library_byte_length"], "REPLAY_LIBRARY_LENGTH")
        exact(sha256(library_raw), qualification["core_library_raw_sha256"], "REPLAY_LIBRARY_HASH")
        process = subprocess.run(
            [sys.executable, str(ROOT / closure["evaluator_path"]), "--core-library", str(library)],
            cwd=ROOT,
            check=True,
            capture_output=True,
        )
        exact(len(process.stdout), qualification["official_stdout_byte_length"], "REPLAY_STDOUT_LENGTH")
        exact(sha256(process.stdout), qualification["official_stdout_raw_sha256"], "REPLAY_STDOUT_HASH")
        exact(loads(process.stdout), decision, "EVALUATOR_REPLAY")

    print(
        "QSDK_R24D22_RECOVERY_MORPHOLOGY_CLOSURE_PASS "
        f"support=supported_exact clearance_m={decision['minimum_limb_ground_clearance_m']} "
        f"mutations=8/8 models=0 worlds=0 solver_steps=0 replay={replay_evaluator} "
        "next=QSDK-R24D23"
    )


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--replay-evaluator", action="store_true")
    return value


if __name__ == "__main__":
    try:
        audit(parser().parse_args().replay_evaluator)
    except (ClosureAuditError, OSError, KeyError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D22_RECOVERY_MORPHOLOGY_CLOSURE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
