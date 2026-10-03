"""Compact audit of the retained zero-world QSDK-R24D37 closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    exact_bools,
    git,
    load,
    loads,
    require,
    sha256,
    source_bytes,
    verify_exact_retained_inventory,
    verify_retained_commit,
    verify_source_binding,
    verify_zero_world_qualification_closure,
)


CLOSURE_PATH = (
    ROOT
    / "sdk/recovery/r24d37_engine_neutral_signed_exchange_ledger_qualification_closure_v1.json"
)
SOURCE = "f6063a33097b6c0a6f83b3d43313daf7f06a93aa"
GATE = "QSDK-R24D37"
SCHEMA = (
    "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_"
    "qualification_closure_v1"
)
STATUS = (
    "closed_complete_zero_world_engine_neutral_signed_exchange_ledger_"
    "qualified_no_physical_question"
)
EXPECTED_CHECKS = (
    "core_dynamic_library_rebuilt",
    "core_targeted_tests_passed",
    "godot_adapter_binding_check_passed",
    "python_binding_smoke_passed",
    "versioning_conformance_passed",
    "source_contract_audit_passed",
    "production_preflight_passed",
    "worktree_unchanged",
)


def audit() -> None:
    closure = load(CLOSURE_PATH)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (SCHEMA, GATE, STATUS, "development"),
        "CLOSURE_IDENTITY",
    )
    exact_bools(
        closure,
        (
            "physical_question_declared",
            "superiority_question_declared",
            "equivalence_or_non_inferiority_question_declared",
            "population_inference_declared",
        ),
        False,
        "DECLARATION",
    )

    source = closure["source"]
    verify_retained_commit(ROOT, SOURCE, source["parent_commit"])
    exact(
        (
            source["commit"],
            source["tree"],
            source["subject"],
        ),
        (
            SOURCE,
            git(ROOT, "show", "-s", "--format=%T", SOURCE),
            "[recovery/core] Freeze R24D37 signed-exchange ledger",
        ),
        "SOURCE_IDENTITY",
    )
    for binding_name in (
        "core_ledger",
        "public_ffi",
        "source_audit",
        "shared_runner",
    ):
        verify_source_binding(ROOT, SOURCE, source[binding_name])
    contract = loads(verify_source_binding(ROOT, SOURCE, source["contract"]))
    exact(
        (
            contract["gate_id"],
            contract["status"],
            contract["physical_question_declared"],
            contract["ledger_v2_semantics"]["schema_version"],
            contract["complete_zero_world_gate"]["required_control_count"],
            contract["source_inventory_strategy"]["source_inventory_count"],
        ),
        (
            GATE,
            "prospective_engine_neutral_signed_exchange_ledger_source_zero_world_"
            "development_passed_physics_blocked_pending_qualification",
            False,
            "sporespore_recovery_energy_balance_ledger_v2",
            9,
            23,
        ),
        "CONTRACT_IDENTITY",
    )

    predecessor = closure["predecessor"]
    predecessor_path = ROOT / predecessor["closure_path"]
    predecessor_closure = load(predecessor_path)
    exact(
        (
            sha256(predecessor_path.read_bytes()),
            predecessor_closure["closure_status"],
        ),
        (
            predecessor["closure_raw_sha256"],
            predecessor["historical_result"],
        ),
        "PREDECESSOR",
    )
    exact_bools(
        predecessor,
        (
            "historical_result_rewritten",
            "historical_threshold_rewritten",
            "historical_evaluator_rewritten",
            "historical_interpretation_rewritten",
            "same_identity_rerun_permitted",
            "same_identity_requalification_permitted",
        ),
        False,
        "PREDECESSOR",
    )

    qualification = closure["qualification"]
    _attempt, receipt, preflight = verify_zero_world_qualification_closure(
        root=ROOT,
        closure=closure,
        gate_id=GATE,
        source_commit=SOURCE,
        attempt_schema=(
            "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_"
            "zero_world_attempt_v1"
        ),
        receipt_schema=(
            "sporespore_qsdk_r24d37_engine_neutral_signed_exchange_ledger_"
            "zero_world_receipt_v1"
        ),
        qualification_directory_prefix="qsdk-r24d37-qualification-",
        contract_inventory=contract["source_inventory"],
        expected_checks=EXPECTED_CHECKS,
        source_manifest_raw_representation=qualification[
            "source_manifest_raw_representation"
        ],
    )
    verify_exact_retained_inventory(
        Path(qualification["evidence_root"]),
        qualification["retained_artifacts"],
    )
    exact(receipt["contract_path"], source["contract"]["path"], "RECEIPT_CONTRACT")
    exact(
        receipt["contract_raw_sha256"],
        source["contract"]["raw_sha256"],
        "RECEIPT_CONTRACT_HASH",
    )
    exact(
        (
            preflight["control_count"],
            preflight["controls_passed"],
            preflight["positive_and_negative_constraint_refusal_count"],
            preflight["ledger_sha256"],
            preflight["ordered_source_values_sha256"],
        ),
        (
            9,
            9,
            2,
            "sha256:b70d6cfce260019514272b92e314349791c40f886f22f7aed2e9eff578768cb8",
            "sha256:cce654be436444753d4fa791d36113ba3e55083fa13c65cf3dc0e1b5b61901a8",
        ),
        "PREFLIGHT_RESULT",
    )
    exact(
        set(preflight["controls"]),
        set(contract["complete_zero_world_gate"]["required_controls"]),
        "PREFLIGHT_CONTROL_SET",
    )
    require(all(preflight["controls"].values()), "PREFLIGHT_CONTROL_FAILURE")

    raw_mismatches = []
    for entry in receipt["source_manifest"]:
        raw = source_bytes(ROOT, SOURCE, entry["path"])
        if len(raw) != entry["byte_length"] or sha256(raw) != entry["raw_sha256"]:
            raw_mismatches.append(
                {
                    "path": entry["path"],
                    "observed_checkout_byte_length": entry["byte_length"],
                    "observed_checkout_raw_sha256": entry["raw_sha256"],
                    "canonical_git_blob_byte_length": len(raw),
                    "canonical_git_blob_raw_sha256": sha256(raw),
                }
            )
    representation = qualification["source_manifest_representation_evidence"]
    exact(
        (
            representation["git_blob_oid_match_count"],
            representation["git_blob_raw_byte_match_count"],
            representation["checkout_only_entry_count"],
        ),
        (23, 22, 1),
        "SOURCE_REPRESENTATION_COUNTS",
    )
    declared_checkout_only = representation["checkout_only_entries"]
    exact(len(raw_mismatches), 1, "SOURCE_REPRESENTATION_OBSERVED_COUNT")
    exact(len(declared_checkout_only), 1, "SOURCE_REPRESENTATION_ENTRY_COUNT")
    for key, value in raw_mismatches[0].items():
        exact(declared_checkout_only[0][key], value, f"SOURCE_REPRESENTATION_{key}")
    exact(
        [item["path"] for item in raw_mismatches],
        ["sdk/python/test_ctypes_smoke.py"],
        "SOURCE_REPRESENTATION_PATHS",
    )
    exact(
        declared_checkout_only[0]["python_source_semantics_changed"],
        False,
        "SOURCE_REPRESENTATION_SEMANTICS",
    )

    decision = closure["decision"]
    exact_bools(
        decision,
        (
            "ordered_aggregation_qualified",
            "repeated_semantic_steps_supported",
            "signed_external_work_retained",
            "both_constraint_exchange_signs_retained",
            "passive_dissipation_nonnegative",
            "source_population_content_addressed",
            "ledger_content_addressed",
            "v1_to_v2_complete_domain_numeric_values_lossless",
            "v2_to_v1_nonzero_constraint_exchange_refused",
            "v2_to_v1_nonzero_external_work_refused",
            "public_header_bound",
            "python_binding_bound",
            "godot_binding_bound",
            "finite_cumulative_overflow_refused",
            "inexact_json_integer_identity_refused",
            "r24d37_closed_without_physics",
        ),
        True,
        "DECISION_POSITIVE",
    )
    exact_bools(
        decision,
        (
            "evaluator_applies_threshold",
            "evaluator_returns_physical_result",
            "v1_schema_or_validation_changed",
            "implicit_migration_used",
            "controller_changed",
            "native_physics_changed",
            "morphology_changed",
            "initializer_changed",
            "native_route_changed",
            "portable_observation_changed",
            "r24d37_physical_execution_permitted",
        ),
        False,
        "DECISION_NEGATIVE",
    )
    exact(
        (
            decision["new_behavior_threshold_count"],
            decision["new_empirical_threshold_count"],
            decision["new_margin_count"],
            decision["physical_cohort_count"],
            decision["held_out_cohort_count"],
            decision["population_claim_count"],
            closure["sdk_status"]["sdk1_completed_steps"],
            closure["sdk_status"]["full_program_completed_steps"],
        ),
        (0, 0, 0, 0, 0, 0, 11, 11),
        "DECISION_LIMITS",
    )

    next_boundary = closure["next_boundary"]
    exact(
        (
            next_boundary["gate_id"],
            next_boundary["question_class"],
            next_boundary["maximum_physical_steps_authorized"],
        ),
        ("QSDK-R24D38", "development", 0),
        "NEXT_BOUNDARY",
    )
    exact_bools(
        next_boundary,
        (
            "physical_question_declared",
            "behavior_question_declared",
            "full_seeded_ghost_required",
            "additional_physical_canary_required",
            "r24d38_physical_execution_authorized",
            "r24d37_may_be_requalified",
            "r24d36_may_be_requalified",
            "prone_to_standing_claimed",
            "physical_acceptance_authority",
            "release_authority",
        ),
        False,
        "NEXT_BOUNDARY",
    )
    positive_claims = {
        "official_zero_world_qualification_passed",
        "engine_neutral_ledger_v2_schema_qualified",
        "ordered_aggregation_qualified",
        "evaluator_algebra_qualified",
        "explicit_v1_migration_and_refusal_qualified",
        "public_abi_and_host_bindings_qualified",
        "both_constraint_exchange_signs_retained_and_refused_on_lossy_downgrade",
        "r24d37_closed_without_physics",
    }
    for key, value in closure["claim_boundary"].items():
        exact(value, key in positive_claims, f"CLAIM_{key.upper()}")

    evidence_root = Path(qualification["evidence_root"])
    source_audit_log = (evidence_root / "source_audit.log").read_text(encoding="utf-8")
    core_test_log = (evidence_root / "cargo_targeted_tests.log").read_text(
        encoding="utf-8"
    )
    require(
        "QSDK_R24D37_ENGINE_NEUTRAL_SIGNED_EXCHANGE_LEDGER_SOURCE_PASS"
        in source_audit_log
        and "9 passed; 0 failed" in core_test_log,
        "RETAINED_LOG_MARKERS",
    )
    print(
        "QSDK_R24D37_ENGINE_NEUTRAL_SIGNED_EXCHANGE_LEDGER_QUALIFICATION_"
        "CLOSURE_PASS sources=23 controls=9/9 core_tests=9/9 models=0 worlds=0 "
        "solver_steps=0 physical=false sdk1=11/20 next=QSDK-R24D38"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError,
        OSError,
        KeyError,
        TypeError,
        ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D37_ENGINE_NEUTRAL_SIGNED_EXCHANGE_LEDGER_QUALIFICATION_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
