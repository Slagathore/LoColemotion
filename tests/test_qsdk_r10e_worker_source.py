from __future__ import annotations

import json
import re
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKER_PATH = (
    ROOT / "tests/test_sdk_qsdk_r10e_observer_minimized_upright_push_recovery_worker.gd"
)
MANIFEST_PATH = ROOT / "sdk/qsdk_r10e_dependency_manifest_v4.json"
SUPERVISOR_PATH = (
    ROOT / "sdk/run_qsdk_r10e_observer_minimized_upright_push_recovery.ps1"
)
QUALIFICATION_PATH = ROOT / "sdk/qsdk_r10e_zero_world_qualification.ps1"
IMPLEMENTATION_PATH = ROOT / "sdk/conformance/qsdk_r10e_zero_world_implementation.py"
MATERIALIZER_PATH = ROOT / "sdk/conformance/qsdk_r10e_authority_materializer.py"
PHYSICAL_CLOSURE_PATH = ROOT / "sdk/conformance/qsdk_r10e_physical_closure.py"
DEPENDENCY_PATH = ROOT / "sdk/conformance/qsdk_r10e_dependency_closure.py"
RECOVERY_PATH = (
    ROOT / "scripts/lab/gait/qsdk_r10e_observer_minimized_upright_push_recovery.gd"
)
QUALIFICATION_FAILURE_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_development_route_ghost_"
    "zero_world_qualification_failure_closure_v1.json"
)
SUPERVISOR_REFUSAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json"
)
L2_HELD_OUT_FAILURE_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json"
)


def _function(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^(?:static )?func {re.escape(name)}\(.*?(?=^(?:static )?func |\Z)",
        source,
    )
    if match is None:
        raise AssertionError(f"missing function: {name}")
    return match.group(0)


class R10eWorkerSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.source = WORKER_PATH.read_text(encoding="utf-8")

    def test_physical_mode_is_guarded_before_any_world_entrypoint(self) -> None:
        physical = _function(self.source, "_physical")
        authorization = physical.index("_physical_authorization_receipt(")
        refusal = physical.index('if not bool(authorization.get("ok", false))')
        world = physical.index("_run_cell(")
        self.assertLess(authorization, refusal)
        self.assertLess(refusal, world)
        self.assertEqual(physical.count("_run_cell("), 1)

        gate = _function(self.source, "_physical_authorization_receipt")
        qualification_guard = gate.index(
            "QUALIFIED_SOURCE_PATH_COUNT <= 0 or QUALIFIED_SOURCE_PATH_SHA256.is_empty()"
        )
        attempt_environment = gate.index("OS.get_environment(ATTEMPT_PATH_ENV)")
        self.assertLess(qualification_guard, attempt_environment)
        self.assertIn("QSDK_R10E_IMPLEMENTATION_QUALIFICATION_NOT_FINALIZED", gate)
        self.assertIn("QSDK_R10E_PHYSICAL_AUTHORIZATION_REQUIRED", gate)
        self.assertIn("QSDK_R10E_HISTORICAL_DEVELOPMENT_ROUTE_RERUN_FORBIDDEN", gate)

    def test_zero_world_entrypoints_request_no_physical_run(self) -> None:
        contract = _function(self.source, "_contract_receipt")
        preflight = _function(self.source, "_entrypoint_preflight")
        pair = _function(self.source, "_pair_evaluate_files")
        self.assertNotIn(
            "_run_cell(RecoveryScript.GENERATOR_INDEX, seed, false)", contract
        )
        self.assertIn(
            "_run_cell(RecoveryScript.GENERATOR_INDEX, seed, true)", preflight
        )
        self.assertNotIn("await tree.physics_frame", contract + preflight + pair)
        self.assertNotIn("apply_central_impulse", contract + preflight + pair)
        for source in (contract, preflight):
            self.assertIn('"world_build_count": 0', source)
            self.assertIn('"physical_acceptance_authority": false', source)
        self.assertIn('result["world_build_count"] = 0', pair)
        self.assertIn('result["physical_acceptance_authority"] = false', pair)

    def test_future_authority_records_are_content_and_commit_bound(self) -> None:
        authorization = _function(self.source, "_physical_authorization_receipt")
        authority = _function(self.source, "_execution_authority_is_exact")
        freeze = _function(self.source, "_stage_freeze_is_exact")
        required_tokens = (
            "stage_freeze_sha256",
            "execution_authority_sha256",
            "FileAccess.get_sha256(freeze_path)",
            "FileAccess.get_sha256(authority_path)",
            "authorization_parent_commit",
            "qualification_parent_commit",
            "authorized_single_use_unconsumed",
            "physical_identity_consumed",
            "same_identity_rerun_permitted",
            "maximum_campaign_attempt_count",
            "maximum_world_count",
            "ordered_cell_ids",
            "QSDK-R10E-L3",
            "superseded_physical_supervisor_refusal",
            "l2_held_out_failure_closure_sha256",
        )
        combined = authorization + authority + freeze
        for token in required_tokens:
            self.assertIn(token, combined)
        self.assertNotIn('String(authority.get("authorization_commit", ""))', authority)

    def test_authority_paths_are_exact_repository_ordinals(self) -> None:
        authorization = _function(self.source, "_physical_authorization_receipt")
        self.assertIn("_stage_freeze_resource_path_for_role", authorization)
        self.assertIn("_execution_authority_resource_path_for_role", authorization)
        self.assertIn(
            "_normalized_path(freeze_path) != expected_freeze_path", authorization
        )
        self.assertIn(
            "_normalized_path(authority_path) != expected_authority_path", authorization
        )

        stage_paths = _function(self.source, "_stage_freeze_resource_path_for_role")
        authority_paths = _function(
            self.source, "_execution_authority_resource_path_for_role"
        )
        for role in ("development_route_ghost", "held_out_finite_decision"):
            self.assertIn(role, stage_paths)
            self.assertIn(role, authority_paths)
        self.assertIn(
            "res://sdk/qsdk_r10e_development_route_ghost_zero_world_qualification_closure_v2.json",
            stage_paths,
        )
        self.assertIn(
            "res://sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v3.json",
            authority_paths,
        )

    def test_all_new_campaign_receipts_expose_ledger_scope(self) -> None:
        for name in (
            "_contract_receipt",
            "_entrypoint_preflight",
            "_physical_receipt",
            "_pair_evaluate_files",
            "_authorization_failure",
            "_worker_failure",
        ):
            self.assertIn('"ledger_scope"', _function(self.source, name), name)

        ledger = _function(self.source, "_ledger_scope")
        for field in (
            '"subsystem": "recovery"',
            '"engine_scope": "godot_jolt"',
            '"authority_mode": authority_mode',
            '"question_class": _question_class_for_role(campaign_role)',
        ):
            self.assertIn(field, ledger)

    def test_bound_predecessors_are_byte_and_digest_exact(self) -> None:
        expected = {
            "R10E_DESIGN": (
                40110,
                "791dbf01b8720ca0851b5ec4f722ff421baeb9ca277399974db6338aec03e81a",
            ),
            "R10D_DEVELOPMENT_CLOSURE": (
                11227,
                "dbbdeb257a260a64c730459880d8d4d66682ec94b65ec8f3beaeb4c38a3cdcc9",
            ),
            "R10D_HELD_OUT_CLOSURE": (
                16158,
                "4a96145b54161a166e735bfd884e497772774d0f9e1e11ae8db6b8fa557c4ed2",
            ),
            "R05E_PHYSICAL_CLOSURE": (
                49049,
                "dac4ac8790cd74d89da0286c36aaf541fbfe7011d2bea66077b941363d47b33e",
            ),
            "PHYSICAL_SUPERVISOR_REFUSAL": (
                5728,
                "831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0",
            ),
            "L2_HELD_OUT_FAILURE_CLOSURE": (
                14311,
                "29942c4f666d3cc7d88388945bb450d6d64f01a6757f72f7a38e149b5d351211",
            ),
        }
        for prefix, (byte_length, digest) in expected.items():
            self.assertIn(f"const {prefix}_BYTES := {byte_length}", self.source)
            self.assertRegex(
                self.source,
                rf'const {prefix}_SHA256 := (?:\(\s*)?"sha256:{digest}"',
            )

    def test_role_population_is_exact_and_separate(self) -> None:
        seeds = _function(self.source, "_seeds_for_role")
        self.assertIn("RecoveryScript.DEVELOPMENT_GHOST_SEEDS.duplicate()", seeds)
        self.assertIn("RecoveryScript.HELD_OUT_SEEDS.duplicate()", seeds)
        ordering = _function(self.source, "_ordered_cell_ids_for_role")
        self.assertLess(ordering.index("for seed"), ordering.index("for arm"))
        self.assertIn("RecoveryScript.cell_id", ordering)

    def test_json_numeric_seed_arrays_receive_strict_validation(self) -> None:
        support = _function(self.source, "_bound_historical_records_are_exact")
        integer_array = _function(self.source, "_exact_integer_array")
        self.assertIn("_exact_integer_array(", support)
        self.assertIn("TYPE_INT", integer_array)
        self.assertIn("TYPE_FLOAT", integer_array)
        self.assertIn("is_finite", integer_array)

    def test_qualification_binding_is_well_formed_or_deliberately_unfinalized(
        self,
    ) -> None:
        count_match = re.search(
            r"^const QUALIFIED_SOURCE_PATH_COUNT := (\d+)$", self.source, re.M
        )
        digest_match = re.search(
            r'^const QUALIFIED_SOURCE_PATH_SHA256 := (?:\(\s*)?"([^"]*)"',
            self.source,
            re.M,
        )
        self.assertIsNotNone(count_match)
        self.assertIsNotNone(digest_match)
        count = int(count_match.group(1))
        digest = digest_match.group(1)
        if count == 0:
            self.assertEqual(digest, "")
        else:
            self.assertGreater(count, 0)
            self.assertRegex(digest, r"^sha256:[0-9a-f]{64}$")

    def test_final_source_binding_is_identical_in_every_independent_guard(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        policy = manifest["policy"]
        count = policy["expected_qualified_source_count"]
        digest = policy["expected_qualified_source_path_sha256"]
        self.assertEqual(count, 91)
        self.assertEqual(
            digest,
            "sha256:348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67",
        )
        expected_tokens = {
            MATERIALIZER_PATH: (f"EXPECTED_SOURCE_COUNT = {count}", digest),
            PHYSICAL_CLOSURE_PATH: (f"EXPECTED_SOURCE_COUNT = {count}", digest),
            IMPLEMENTATION_PATH: (f"EXPECTED_SOURCE_COUNT = {count}", digest),
            SUPERVISOR_PATH: (f"$script:ExpectedSourceCount = {count}", digest),
            QUALIFICATION_PATH: (
                f"$script:QualifiedSourcePathCount = {count}",
                digest,
            ),
            WORKER_PATH: (f"const QUALIFIED_SOURCE_PATH_COUNT := {count}", digest),
        }
        for path, tokens in expected_tokens.items():
            text = path.read_text(encoding="utf-8")
            for token in tokens:
                self.assertIn(token, text, f"{path}: {token}")
        self.assertEqual(
            manifest["schema_version"], "sporespore_qsdk_r10e_dependency_manifest_v4"
        )
        self.assertEqual(manifest["repair_id"], "QSDK-R10E-L3")
        self.assertIn(
            QUALIFICATION_FAILURE_CLOSURE_PATH.relative_to(ROOT).as_posix(),
            policy["process_and_audit_paths"],
        )
        for historical_path in (
            SUPERVISOR_REFUSAL_CLOSURE_PATH,
            L2_HELD_OUT_FAILURE_CLOSURE_PATH,
            ROOT / "sdk/qsdk_r10e_development_route_ghost_execution_authority_v1.json",
            ROOT
            / "sdk/qsdk_r10e_development_route_ghost_zero_world_qualification_closure_v1.json",
        ):
            self.assertIn(
                historical_path.relative_to(ROOT).as_posix(),
                policy["process_and_audit_paths"],
            )
        recovery = RECOVERY_PATH.read_text(encoding="utf-8")
        self.assertIn("var common_execution_integrity: bool = (", recovery)
        self.assertIn("var exact: bool = (", self.source)
        self.assertIn("var exact_attempt: bool = (", self.source)

    def test_future_runtime_authorities_are_explicitly_excluded_from_source(
        self,
    ) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        authorities = manifest["policy"]["prospective_runtime_authority_paths"]
        self.assertEqual(
            authorities,
            [
                "sdk/qsdk_r10e_development_route_ghost_execution_authority_v2.json",
                "sdk/qsdk_r10e_development_route_ghost_zero_world_qualification_closure_v2.json",
                "sdk/qsdk_r10e_held_out_finite_decision_execution_authority_v3.json",
                "sdk/qsdk_r10e_held_out_finite_decision_zero_world_qualification_closure_v3.json",
            ],
        )
        dependency = DEPENDENCY_PATH.read_text(encoding="utf-8")
        self.assertIn("excluded_runtime_authorities", dependency)
        self.assertIn("PROSPECTIVE_AUTHORITY_LITERAL_SET", dependency)
        self.assertIn("PROSPECTIVE_AUTHORITY_MISCLASSIFIED_AS_SOURCE", dependency)
        for path in authorities:
            self.assertIn(f'"res://{path}"', self.source)

    def test_official_qualification_wrapper_cannot_select_physical_mode(self) -> None:
        source = QUALIFICATION_PATH.read_text(encoding="utf-8")
        self.assertNotIn('"-Mode", "Physical"', source)
        self.assertNotIn("-AuthorizePhysical", source)
        self.assertIn('"--official-qualification"', source)
        self.assertIn("Enter-SporeSporeLocomotionOperationLock", source)
        self.assertIn("Exit-SporeSporeLocomotionOperationLock", source)
        self.assertIn('status = "closed_failed_identity_consumed"', source)
        self.assertIn("same_identity_rerun_permitted = $false", source)
        self.assertGreaterEqual(
            source.count("physical_execution_authorized = $false"), 3
        )

    def test_physical_supervisor_is_single_attempt_and_fail_closed(self) -> None:
        source = SUPERVISOR_PATH.read_text(encoding="utf-8")
        start = source.index("function Invoke-SupervisorPhysical {")
        end = source.index("\ntry {", start)
        body = source[start:end]
        self.assertEqual(body.count("$worldAttemptCount += 1"), 1)
        self.assertIn("if (-not (Test-ValidCellProjection $cell))", body)
        self.assertIn("break", body)
        self.assertIn("maximum_campaign_attempt_count = 1", body)
        self.assertIn("same_identity_rerun_permitted = $false", body)
        self.assertIn("PHYSICAL_IDENTITY_CONSUMED_AFTER_LOCK", body)
        self.assertNotRegex(body, r"(?i)\bretry\b")

    def test_implementation_audit_cross_checks_direct_and_supervisor_receipts(
        self,
    ) -> None:
        source = IMPLEMENTATION_PATH.read_text(encoding="utf-8")
        for code in (
            "SOURCE_RECEIPT_DIVERGENCE",
            "DEFERRED_TRACE_RECEIPT_DIVERGENCE",
            "SCALAR_RECEIPT_DIVERGENCE",
            "WORKER_CONTRACT_RECEIPT_DIVERGENCE",
            "PREFLIGHT_RECEIPT_DIVERGENCE",
            "DEPENDENCY_RECEIPT_DIVERGENCE",
            "BYPASS_RECEIPT_DIVERGENCE",
            "HISTORICAL_DEVELOPMENT_BYPASS_RECEIPT_DIVERGENCE",
        ):
            self.assertIn(code, source)
        self.assertIn("if arguments.official_qualification", source)
        self.assertIn("OFFICIAL_QUALIFICATION_REQUIRES_CLEAN_LIVE_MAIN", source)
        self.assertNotIn("shell=True", source)

    def test_runtime_identity_schema_matches_future_authority_check(self) -> None:
        implementation = IMPLEMENTATION_PATH.read_text(encoding="utf-8")
        qualification = QUALIFICATION_PATH.read_text(encoding="utf-8")
        supervisor = SUPERVISOR_PATH.read_text(encoding="utf-8")
        materializer = MATERIALIZER_PATH.read_text(encoding="utf-8")
        closure = PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8")
        self.assertIn('"godot_console": executable_identity', implementation)
        self.assertIn('"python_version": python_version', implementation)
        self.assertIn('"powershell_version": powershell_version', implementation)
        self.assertIn("$runtime.godot_console.raw_sha256", qualification)
        self.assertNotIn("$runtime.godot.raw_sha256", qualification)
        self.assertIn("$Recorded.godot_console.raw_sha256", supervisor)
        self.assertIn("$Recorded.python_version", supervisor)
        self.assertIn("$Recorded.powershell_version", supervisor)
        self.assertIn('runtime.get("godot_console")', materializer)
        self.assertIn('implementation.get("runtime_identity") == runtime', materializer)
        self.assertIn('implementation.get("runtime_identity_sha256")', materializer)
        self.assertIn("QUALIFICATION_DIRECTORY_IDENTITY", materializer)
        self.assertIn('attempt.get("campaign_role") == role', materializer)
        self.assertIn('completion.get("campaign_role") == role', materializer)
        self.assertIn("QUALIFICATION_COMPLETION_PATH", supervisor)
        self.assertIn("QUALIFICATION_RUNTIME_PATH", supervisor)
        self.assertIn("runtime_identity_byte_length = [int64]", supervisor)
        self.assertIn("def validate_runtime_identity(", closure)
        self.assertIn("validate_runtime_identity(report, runtime, spec)", closure)
        self.assertIn("def validate_committed_authority_chain(", closure)
        self.assertIn(
            "validate_committed_authority_chain(report, runtime, spec)", closure
        )
        self.assertIn("COMMITTED_AUTHORITY_PARENT_CHAIN", closure)
        self.assertIn("COMMITTED_AUTHORITY_ORDINAL_PATHS", closure)
        self.assertIn("REPORT_RUNTIME_FILE_BINDING", closure)
        self.assertIn("REPORT_RUNTIME_TOOL_IDENTITY", closure)

    def test_physical_closure_authenticates_exit_codes_and_pair_logs(self) -> None:
        supervisor = SUPERVISOR_PATH.read_text(encoding="utf-8")
        closure = PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8")
        pair_projection = supervisor[
            supervisor.index("function Convert-PairProjection {") : supervisor.index(
                "function Test-ValidPairProjection {"
            )
        ]
        self.assertIn("stdout_binding = Get-FileBinding", pair_projection)
        self.assertIn("stderr_binding = Get-FileBinding", pair_projection)
        self.assertIn('type(cell.get("process_exit_code")) is int', closure)
        self.assertIn('type(pair.get("process_exit_code")) is int', closure)
        self.assertIn('"PAIR_STDOUT"', closure)
        self.assertIn('"PAIR_STDERR"', closure)
        self.assertIn("EXPECTED_EVIDENCE_ROOT", closure)
        self.assertIn('output_root / "terminal_report.json"', closure)
        self.assertIn("CELL_RECEIPT_PROJECTION", closure)
        self.assertIn("PAIR_RECEIPT_PROJECTION", closure)
        self.assertIn("STDOUT_RECEIPT_DIVERGENCE", closure)
        self.assertIn("evidence_tree_inventory", closure)
        self.assertIn('"retained_tree": retained_tree', closure)
        self.assertIn('"runtime_identity": dict(report["runtime_identity"])', closure)
        self.assertIn(
            'receipt.get("baseline_behavior_passed") is baseline_behavior', closure
        )
        self.assertIn('receipt.get("push_behavior_passed") is push_behavior', closure)
        self.assertIn("MINIMUM_NATIVE_EFFECT_M_S", closure)
        self.assertIn("campaign_start_binding = Get-FileBinding", supervisor)


if __name__ == "__main__":
    unittest.main()
