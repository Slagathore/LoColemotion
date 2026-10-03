"""Audit the compact R24D54 launcher-repair and cold-equivalence closure."""

from __future__ import annotations

from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
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
    verify_boolean_partition,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
    verify_retained_commit,
    verify_retained_file_tree,
    verify_retained_json,
    verify_source_binding,
    verify_source_receipt_manifest,
)

CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d54_rapier_integration_authority_routing_repair_closure_v1.json"
)
BASE_SOURCE = "0249b288da59b7eab9420a43f3a976f1078f2e16"
REPAIR_SOURCE = "1547afa0cc4a71bec9a477e7f866e45774bc1e47"
RUNNER_RELATIVE = "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"
DEVELOPMENT_CHECKS = {
    "fresh_registry_archive_patched_and_bound",
    "successor_patch_sequence_applied_and_bound",
    "source_contract_audit_passed",
    "stock_adapter_check_passed",
    "workspace_zero_world_test_recovery_observation_v3",
    "isolated_patched_rapier_and_adapter_check_passed",
    "expected_compile_refusal_parallel",
    "expected_compile_refusal_simd_stable",
    "contract_declared_preflight_expectations_passed",
    "production_preflight_passed",
    "source_manifest_bound",
    "worktree_unchanged",
    "source_commit_unchanged",
}


def routing_mutations(source: str) -> dict[str, str]:
    return {
        "unguarded_ghost_validation": source.replace(
            'if ($null -ne $ghostAuthority) {', "if ($true) {", 1
        ),
        "inverted_ghost_guard": source.replace(
            'if ($null -ne $ghostAuthority) {',
            'if ($null -eq $ghostAuthority) {',
            1,
        ),
        "missing_integration_fallback": source.replace(
            'Assert-R24D48 ($null -ne $developmentIntegrationAuthority) (',
            'Assert-R24D48 $true (',
            1,
        ),
        "expanded_repair_exclusion": source.replace(
            "$exclusions.Count -eq 1", "$exclusions.Count -eq 2", 1
        ),
        "missing_repair_scope_refusal": source.replace(
            '"STAGE_AUTHORITY_REPAIR_SCOPE"',
            '"STAGE_AUTHORITY_REPAIR_SCOPE_REMOVED"',
            1,
        ),
    }


def audit() -> None:
    closure = load(CLOSURE)
    exact(
        (
            closure["schema_version"],
            closure["gate_id"],
            closure["stage_id"],
            closure["closure_status"],
            closure["question_class"],
        ),
        (
            "sporespore_qsdk_r24d54_rapier_integration_authority_"
            "routing_repair_closure_v1",
            "QSDK-R24D54",
            "R24D54-L1",
            "closed_complete_zero_world_integration_authority_routing_"
            "repair_qualified",
            "development_launch_authority_repair",
        ),
        "CLOSURE_IDENTITY",
    )
    for key in (
        "physical_question_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(closure[key], False, f"DECLARATION_{key.upper()}")

    base = closure["base_qualification"]
    exact(base["source_commit"], BASE_SOURCE, "BASE_SOURCE")
    base_path = ROOT / base["closure_path"]
    exact(sha256(base_path.read_bytes()), base["closure_raw_sha256"], "BASE_CLOSURE")
    base_closure = load(base_path)
    exact(
        (
            base_closure["source"]["commit"],
            base_closure["closure_status"],
            base_closure["qualification"]["runtime_binding_sha256"],
        ),
        (
            BASE_SOURCE,
            "closed_complete_zero_world_v3_recovery_behavior_route_"
            "qualified_paired_development_authorized",
            base["runtime_binding_sha256"],
        ),
        "BASE_AUTHORITY",
    )
    exact(
        (base["same_identity_official_requalification_permitted"],
         base["official_qualification_reexecuted"]),
        (False, False),
        "BASE_NOT_REEXECUTED",
    )

    repair = closure["repair_source"]
    verify_retained_commit(ROOT, REPAIR_SOURCE, repair["parent_commit"])
    exact(
        (repair["commit"], repair["tree"], repair["subject"]),
        (
            REPAIR_SOURCE,
            git(ROOT, "show", "-s", "--format=%T", REPAIR_SOURCE),
            "[recovery/rapier] Repair R54 authority routing",
        ),
        "REPAIR_SOURCE",
    )
    for binding in (repair["runner"], repair["declaration"], repair["source_test"]):
        verify_source_binding(ROOT, REPAIR_SOURCE, binding)
    declaration = loads(
        verify_source_binding(ROOT, REPAIR_SOURCE, repair["declaration"])
    )
    contract = load(
        ROOT / "sdk/recovery/r24d54_rapier_recovery_energy_v3_behavior_contract_v1.json"
    )
    code_paths = contract["physical_runner"]["qualification_source_code_paths"]
    exact(len(code_paths), 23, "QUALIFIED_SOURCE_COUNT")
    changed_text = git(
        ROOT,
        "diff",
        "--name-only",
        BASE_SOURCE,
        REPAIR_SOURCE,
        "--",
        *code_paths,
    )
    assert isinstance(changed_text, str)
    exact(changed_text.splitlines(), [RUNNER_RELATIVE], "REPAIR_CHANGED_PATHS")
    exact(
        closure["authority_only_qualified_path_exclusions"],
        [RUNNER_RELATIVE],
        "AUTHORITY_EXCLUSIONS",
    )
    exact(
        closure["qualified_unchanged_source_paths"],
        [path for path in code_paths if path != RUNNER_RELATIVE],
        "UNCHANGED_PATHS",
    )
    exact(
        declaration["prospective_closure"]["qualified_unchanged_source_paths"],
        closure["qualified_unchanged_source_paths"],
        "DECLARED_UNCHANGED_PATHS",
    )

    failure = closure["observed_launcher_failure"]
    verify_exact_paths(
        failure,
        {
            "source_commit": "e26d40ab00540b59e7e801db82ed2cfc456d5e54",
            "failure_boundary": "before_operation_lock_and_before_evidence_root_creation",
            "operation_lock_acquired": False,
            "evidence_root_created": False,
            "physical_attempt_record_created": False,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "physical_attempt_consumed": False,
            "behavior_result_observed": False,
        },
        "FAILURE",
    )
    exact(
        failure,
        {
            key: value
            for key, value in declaration["observed_failure"].items()
            if key != "invocation_mode" and key != "cause"
        },
        "FAILURE_DECLARATION_PRESERVED",
    )

    cold = closure["cold_equivalence"]
    cold_root = Path(cold["evidence_root"])
    verify_retained_file_tree(cold_root, cold["retained_tree"])
    attempt_claim = cold["attempt"]
    receipt_claim = cold["receipt"]
    attempt = verify_retained_json(
        cold_root / attempt_claim["path"],
        attempt_claim["byte_length"],
        attempt_claim["raw_sha256"],
        attempt_claim["canonical_byte_length"],
        attempt_claim["canonical_sha256"],
    )
    receipt = verify_retained_json(
        cold_root / receipt_claim["path"],
        receipt_claim["byte_length"],
        receipt_claim["raw_sha256"],
        receipt_claim["canonical_byte_length"],
        receipt_claim["canonical_sha256"],
    )
    matching = []
    for directory in cold_root.parent.glob(
        "qsdk-r24d54-rapier-recovery-energy-v3-qualification-development-*"
    ):
        candidate = directory / "development_attempt.json"
        if candidate.is_file():
            value = load(candidate)
            if value.get("source_commit") == REPAIR_SOURCE:
                matching.append(directory)
    exact(len(matching), cold["development_attempt_count_for_repair_source"], "ATTEMPTS")
    exact(matching, [cold_root], "ATTEMPT_IDENTITY")

    for value, prefix in ((attempt, "ATTEMPT"), (receipt, "RECEIPT")):
        exact(value["gate_id"], "QSDK-R24D54", f"{prefix}_GATE")
        exact(value["mode"], "development", f"{prefix}_MODE")
        exact(value["source_commit"], REPAIR_SOURCE, f"{prefix}_SOURCE")
        exact(value["upstream_commit"], REPAIR_SOURCE, f"{prefix}_UPSTREAM")
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
        ):
            exact(value[key], 0, f"{prefix}_{key.upper()}")
        exact(value["physics_state_modified"], False, f"{prefix}_PHYSICS")
        exact(value["physical_question_opened"], False, f"{prefix}_QUESTION")
        exact(value["physical_acceptance_authority"], False, f"{prefix}_ACCEPTANCE")
        exact(value["release_authority"], False, f"{prefix}_RELEASE")
    exact(attempt["worktree_clean_at_start"], True, "ATTEMPT_CLEAN")
    exact(attempt["operation_lock"]["acquired"], True, "ATTEMPT_LOCK")
    exact(receipt["ok"], True, "RECEIPT_OK")
    exact(receipt["operation_lock_released"], True, "LOCK_RELEASED")
    exact(receipt["held_out_cell_access_count"], 0, "HELDOUT_ACCESS")
    exact(receipt["held_out_selector_invocation_count"], 0, "HELDOUT_SELECTOR")
    exact(set(receipt["checks"]), DEVELOPMENT_CHECKS, "DEVELOPMENT_CHECKS")
    exact(set(receipt["checks"].values()), {True}, "DEVELOPMENT_CHECK_RESULTS")

    manifest = receipt["source_manifest"]
    exact(len(manifest), cold["source_manifest_entry_count"], "SOURCE_COUNT")
    exact([item["path"] for item in manifest], contract["source_inventory"], "SOURCE_ORDER")
    encoded_manifest = canonical_bytes(manifest)
    exact(len(encoded_manifest), cold["source_manifest_canonical_byte_length"], "SOURCE_LENGTH")
    exact(sha256(encoded_manifest), cold["source_manifest_canonical_sha256"], "SOURCE_HASH")
    verify_source_receipt_manifest(
        ROOT, REPAIR_SOURCE, manifest, cold["source_manifest_raw_representation"]
    )

    official_root = Path(base["official_evidence_root"])
    official_receipt = load(official_root / base["official_receipt_path"])
    official_raw = (official_root / base["official_receipt_path"]).read_bytes()
    exact(
        (len(official_raw), sha256(official_raw)),
        (base["official_receipt_byte_length"], base["official_receipt_raw_sha256"]),
        "OFFICIAL_RECEIPT",
    )
    exact(
        set(official_receipt["checks"]) - set(receipt["checks"]),
        {cold["official_mode_only_check"]},
        "MODE_SPECIFIC_CHECK",
    )
    exact(set(receipt["checks"]) - set(official_receipt["checks"]), set(), "DEV_ONLY_CHECK")
    exact(
        (
            len(receipt["checks"]),
            len(set(receipt["checks"]) & set(official_receipt["checks"])),
            len(official_receipt["checks"]),
            cold["composite_declared_outer_check_count"],
        ),
        (13, 13, 14, 14),
        "CHECK_COUNTS",
    )
    exact(receipt["production_preflight"], official_receipt["production_preflight"], "PREFLIGHT_EQUIVALENCE")
    preflight = canonical_bytes(receipt["production_preflight"])
    exact((len(preflight), sha256(preflight)),
          (cold["preflight_canonical_byte_length"], cold["preflight_canonical_sha256"]),
          "PREFLIGHT_HASH")
    exact(receipt["production_preflight"]["check_count"], 15, "PREFLIGHT_COUNT")
    exact(receipt["production_preflight"]["checks_passed"], 15, "PREFLIGHT_PASSED")
    exact(receipt["production_preflight"]["runtime_binding_sha256"],
          cold["runtime_binding_sha256"], "RUNTIME_BINDING")
    for key, code in (
        ("toolchain", "TOOLCHAIN"),
        ("registry_archive", "REGISTRY"),
        ("patch_raw_sha256", "BASE_PATCH"),
        ("successor_patch_sequence", "SUCCESSOR_PATCH"),
        ("successor_patched_dependency_files", "SUCCESSOR_FILES"),
        ("isolated_harness_cargo_lock", "CARGO_LOCK"),
    ):
        exact(receipt[key], official_receipt[key], f"COLD_{code}")
    live = cold["closure_live_remote_verification"]
    exact(
        (live["head_commit"], live["origin_main_commit"],
         live["live_remote_main_commit"], live["worktree_clean"]),
        (REPAIR_SOURCE, REPAIR_SOURCE, REPAIR_SOURCE, True),
        "CLOSURE_LIVE_EQUALITY",
    )

    immutable_test = source_bytes(ROOT, REPAIR_SOURCE, repair["source_test"]["path"])
    namespace: dict[str, object] = {
        "__name__": "r24d54_immutable_source_test",
        "__file__": str(ROOT / repair["source_test"]["path"]),
    }
    exec(compile(immutable_test, str(repair["source_test"]["path"]), "exec"), namespace)
    verify_routing_source = namespace["verify_routing_source"]
    audit_error = namespace["AuditError"]
    runner_source = source_bytes(ROOT, REPAIR_SOURCE, RUNNER_RELATIVE).decode("utf-8")
    verify_routing_source(runner_source)  # type: ignore[operator]
    mutations = routing_mutations(runner_source)
    exact(len(mutations), 5, "MUTATION_COUNT")
    for mutation_id, mutation in mutations.items():
        rejected = False
        try:
            verify_routing_source(mutation)  # type: ignore[operator]
        except audit_error:  # type: ignore[misc]
            rejected = True
        require(rejected, f"MUTATION_ACCEPTED:{mutation_id}")

    verify_exact_paths(
        cold,
        {
            "development_receipt_check_count": 13,
            "shared_official_check_count": 13,
            "official_mode_only_check": "live_remote_unchanged",
            "composite_declared_outer_check_count": 14,
            "preflight_check_count": 15,
            "source_test_control_count": 8,
            "source_test_controls_passed": 8,
            "source_test_mutation_rejection_count": 5,
            "source_test_mutations_rejected": 5,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physics_state_modified": False,
            "physical_question_opened": False,
            "operation_lock_released": True,
        },
        "COLD_COUNTS",
    )
    verify_boolean_partition(
        closure["decision"],
        (
            "observed_launcher_failure_pre_physics",
            "single_changed_qualified_path_proven",
            "twenty_two_qualified_paths_unchanged",
            "repair_source_committed_pushed_live_equal",
            "all_eight_source_controls_passed",
            "all_five_routing_mutations_rejected",
            "full_cold_equivalence_development_qualification_passed",
            "mode_specific_outer_check_difference_preserved",
            "complete_shared_outer_checks_exact_to_official",
            "production_preflight_exact_to_official",
            "runtime_dependency_toolchain_and_lock_exact_to_official",
            "integration_authority_routing_qualified",
            "launcher_repair_authority",
            "r24d54_paired_physical_attempt_remains_unconsumed",
            "r24d54_paired_development_authorized",
        ),
        (
            "physical_attempt_consumed",
            "new_physical_ghost_required",
            "additional_physical_canary_required",
            "new_physical_observation_made",
            "controller_or_behavior_changed",
            "threshold_or_margin_changed",
            "retained_r49_result_recomputed_or_reclassified",
            "prone_to_standing_claimed",
            "repeatability_rate_claimed",
            "population_claimed",
            "held_out_validation_claimed",
            "cross_engine_recovery_claimed",
            "sdk1_milestone_advanced",
            "physical_acceptance_authority",
            "release_authority",
        ),
        "DECISION",
    )
    exact(closure["decision"]["maximum_physical_steps_authorized"], 2400, "PHYSICAL_MAX")
    exact(
        closure["sdk_status"],
        {
            "sdk1_milestone_advanced": False,
            "sdk1_completed_steps": 11,
            "sdk1_total_steps": 20,
            "full_program_completed_steps": 11,
            "full_program_total_steps": 25,
        },
        "SDK_STATUS",
    )

    relative = CLOSURE.relative_to(ROOT).as_posix()
    publication = git(ROOT, "log", "-1", "--diff-filter=A", "--format=%H", "--", relative)
    assert isinstance(publication, str)
    revision = publication or None
    raw = CLOSURE.read_bytes() if revision is None else source_bytes(ROOT, revision, relative)
    live_expectations = {
        **closure["live_gate_expectations"],
        "r24d54_launcher_routing_repair_closure_raw_sha256": sha256(raw),
    }
    verify_legacy_live_gate_paths(
        ROOT,
        closure["live_authority_paths"],
        "QSDK-R24D45",
        live_expectations,
        revision=revision,
    )
    print(
        "QSDK_R24D54_RAPIER_INTEGRATION_AUTHORITY_ROUTING_REPAIR_CLOSURE_PASS "
        "changed_paths=1 unchanged_paths=22 controls=8/8 mutations=5/5 "
        "cold_shared_checks=13/13 composite_checks=14/14 preflight=15/15 "
        "tree_files=151 models=0 worlds=0 solver_steps=0 physical=false "
        "authorized=2x1200 sdk1=11/20 next=QSDK-R24D54"
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
            "QSDK_R24D54_RAPIER_INTEGRATION_AUTHORITY_ROUTING_REPAIR_"
            f"CLOSURE_FAIL {error}",
            file=sys.stderr,
        )
        raise SystemExit(1) from error
