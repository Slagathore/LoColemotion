from __future__ import annotations

import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
SUPERVISOR_PATH = (
    REPO_ROOT / "sdk/turning/three_engine_turning_route_supervisor.py"
)
SPEC = importlib.util.spec_from_file_location(
    "three_engine_turning_route_supervisor", SUPERVISOR_PATH
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("turning route supervisor import failed")
supervisor = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = supervisor
SPEC.loader.exec_module(supervisor)


class ThreeEngineTurningRouteSupervisorTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        target = REPO_ROOT / "sdk/target"
        target.mkdir(parents=True, exist_ok=True)
        self._temporary = tempfile.TemporaryDirectory(
            prefix="turning-route-supervisor-test-", dir=target
        )
        self.root = Path(self._temporary.name)
        self.source_commit = "1" * 40
        self.source = {
            "repo_root": str(REPO_ROOT.resolve()),
            "origin_url": supervisor.EXPECTED_REMOTE,
            "branch": "main",
            "source_commit": self.source_commit,
            "origin_main_commit": self.source_commit,
            "live_github_main_commit": self.source_commit,
            "source_tree": "2" * 40,
            "source_worktree_clean": True,
            "local_remote_live_equal": True,
        }

    def tearDown(self) -> None:
        self._temporary.cleanup()

    def _runtime(self) -> supervisor.RuntimePaths:
        applications = {}
        for name in (
            "python.exe",
            "mujoco-python.exe",
            "godot.exe",
            "pwsh.exe",
            "cargo.exe",
            "turning_three_engine_route.exe",
        ):
            path = self.root / name
            path.write_bytes(name.encode("ascii"))
            applications[name] = path
        return supervisor.RuntimePaths(
            python_host=applications["python.exe"],
            mujoco_python=applications["mujoco-python.exe"],
            godot=applications["godot.exe"],
            powershell=applications["pwsh.exe"],
            cargo=applications["cargo.exe"],
            rapier_binary=applications["turning_three_engine_route.exe"],
        )

    @staticmethod
    def _process(name: str, *, exit_code: int, stdout: str) -> dict[str, object]:
        return {
            "name": name,
            "command": [name],
            "cwd": str(REPO_ROOT),
            "exit_code": exit_code,
            "timed_out": False,
            "stdout": stdout,
            "stderr": "",
            "started_utc": "2026-08-25T00:00:00Z",
            "completed_utc": "2026-08-25T00:00:01Z",
        }

    def test_complete_gate_calls_only_zero_world_and_bypass_refusal_routes(self) -> None:
        runtime = self._runtime()
        specs = {
            spec.engine_id: spec
            for spec in supervisor._worker_specs(runtime, self.source_commit)
        }
        observed_names: list[str] = []

        def fake_runner(**kwargs: object) -> dict[str, object]:
            name = str(kwargs["name"])
            observed_names.append(name)
            environment = kwargs["environment"]
            self.assertIsInstance(environment, dict)
            self.assertFalse(
                any(
                    str(key).startswith(supervisor.ROUTE_ENV_PREFIX)
                    for key in environment
                )
            )
            if name == "rapier_build":
                return self._process(name, exit_code=0, stdout="")
            if name == "evaluator_preflight":
                value = {
                    "schema_version": (
                        "sporespore_three_engine_turning_success_transport_"
                        "evaluator_preflight_v2"
                    ),
                    "route_id": supervisor.ROUTE_ID,
                    "ledger_scope": supervisor.LEDGER_SCOPE,
                    "contract_raw_sha256": supervisor._sha256_file(
                        supervisor.CONTRACT_PATH
                    ),
                    "terminal_positive_control_count": 3,
                    "terminal_negative_control_count": 6,
                    "artifact_negative_control_count": 8,
                    "negative_control_count": 14,
                    "negative_controls_rejected": [
                        "missing_engine",
                        "success_root_count",
                        "source_commit",
                        "execution_count",
                        "question_class_missing",
                        "question_class_wrong",
                    ],
                    "artifact_negative_controls_rejected": [
                        "trace_transport_id_missing",
                        "trace_transport_id_wrong",
                        "trace_transport_engine_id_missing",
                        "trace_transport_engine_id_wrong",
                        "canonical_ndjson_missing",
                        "canonical_ndjson_false",
                        "full_precision_missing",
                        "full_precision_false",
                    ],
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_behavior_thresholds_applied": False,
                    "physical_acceptance_authority": False,
                }
                return self._process(
                    name,
                    exit_code=0,
                    stdout=(
                        "SPORESPORE_TURNING_ROUTE_EVALUATOR_PREFLIGHT "
                        + json.dumps(value)
                    ),
                )
            engine_id = next(
                engine
                for engine in supervisor.ENGINE_IDS
                if name.startswith(engine)
            )
            spec = specs[engine_id]
            if name.endswith("_preflight"):
                negative_control_count = 3 if engine_id == "godot_jolt" else 2
                value = {
                    "schema_version": spec.preflight_schema,
                    "ok": True,
                    "failure_code": "",
                    "route_id": supervisor.ROUTE_ID,
                    "ledger_scope": supervisor.LEDGER_SCOPE,
                    "engine_id": engine_id,
                    "cell_id": spec.cell_id,
                    "campaign_seed": supervisor.DEVELOPMENT_SEED,
                    "controller_step_count": 2,
                    "nonzero_turn_command_compiled": True,
                    "public_profile_route_compiled": True,
                    "negative_control_count": negative_control_count,
                    "negative_controls_rejected": negative_control_count,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_execution_authorized": False,
                    "physical_behavior_thresholds_applied": False,
                    "physical_acceptance_authority": False,
                }
                if engine_id == "godot_jolt":
                    value["integral_json_artifact_length_projection_checked"] = True
                if engine_id == "rapier_parry":
                    value["success_trace_retention_question_class_checked"] = True
                return self._process(
                    name,
                    exit_code=0,
                    stdout=spec.preflight_marker + json.dumps(value),
                )
            value = {
                "schema_version": supervisor.WORKER_FAILURE_SCHEMA,
                "route_id": supervisor.ROUTE_ID,
                "engine_id": engine_id,
                "cell_id": spec.cell_id,
                "campaign_seed": supervisor.DEVELOPMENT_SEED,
                "source_commit": self.source_commit,
                "failure_code": "PHYSICAL_AUTHORIZATION_REQUIRED",
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "physical_behavior_thresholds_applied": False,
                "claims": {"release_authorized": False},
                "physical_acceptance_authority": False,
            }
            return self._process(
                name,
                exit_code=1,
                stdout=spec.terminal_marker + json.dumps(value),
            )

        with mock.patch.object(supervisor, "_dependency_artifacts", return_value=[]):
            result = supervisor.run_complete_zero_world_gate(
                runtime, process_runner=fake_runner
            )

        self.assertTrue(result["complete_zero_world_gate_passed"])
        self.assertEqual(result["process_count"], 8)
        self.assertEqual(result["embedded_negative_control_count"], 21)
        self.assertEqual(result["total_negative_control_count"], 24)
        self.assertEqual(result["world_build_count"], 0)
        self.assertEqual(
            observed_names,
            [
                "rapier_build",
                "evaluator_preflight",
                "godot_jolt_preflight",
                "rapier_parry_preflight",
                "mujoco_preflight",
                "godot_jolt_authorization_negative",
                "rapier_parry_authorization_negative",
                "mujoco_authorization_negative",
            ],
        )

    def test_freeze_and_attempt_are_exact_append_only_documents(self) -> None:
        attempt_root = self.root / "attempt"
        attempt_root.mkdir()
        zero_artifact = {
            "path": str(self.root / "zero.json"),
            "sha256": "sha256:" + ("3" * 64),
            "byte_length": 1,
        }
        freeze = supervisor._freeze_document(self.source, zero_artifact)
        self.assertTrue(freeze["complete_zero_world_gate_passed"])
        self.assertTrue(freeze["physical_execution_authorized"])
        self.assertEqual(freeze["declared_world_count"], 3)
        self.assertEqual(freeze["ordered_cell_ids"], list(supervisor.ORDERED_CELL_IDS))
        self.assertTrue(all(value is False for value in freeze["claims"].values()))
        freeze_path = attempt_root / "physical-freeze.json"
        freeze_artifact = supervisor._write_new_json(freeze_path, freeze)
        attempt = supervisor._attempt_document(
            source_commit=self.source_commit,
            freeze_raw_sha256=freeze_artifact["sha256"],
            token="4" * 32,
            attempt_id="5" * 32,
            attempt_root=attempt_root,
        )
        self.assertEqual(attempt["freeze_raw_sha256"], freeze_artifact["sha256"])
        self.assertTrue(attempt["single_use_supervisor_authorization"])
        self.assertTrue(attempt["one_shot_attempt_unconsumed"])
        supervisor._write_new_json(attempt_root / "attempt-authorization.json", attempt)
        with self.assertRaisesRegex(
            supervisor.RouteSupervisorError, "REFUSES_OVERWRITE"
        ):
            supervisor._write_new_json(freeze_path, freeze)

    def test_attempt_rejects_noncanonical_identity(self) -> None:
        attempt_root = self.root / "attempt"
        attempt_root.mkdir()
        with self.assertRaisesRegex(
            supervisor.RouteSupervisorError, "ATTEMPT_IDENTITY_INVALID"
        ):
            supervisor._attempt_document(
                source_commit=self.source_commit,
                freeze_raw_sha256="sha256:" + ("3" * 63),
                token="4" * 32,
                attempt_id="5" * 32,
                attempt_root=attempt_root,
            )

    def test_terminal_count_ownership_is_schema_specific(self) -> None:
        runtime = self._runtime()
        spec = supervisor._worker_specs(runtime, self.source_commit)[0]
        common = {
            "route_id": supervisor.ROUTE_ID,
            "ledger_scope": supervisor.LEDGER_SCOPE,
            "question_class": "development",
            "engine_id": spec.engine_id,
            "cell_id": spec.cell_id,
            "campaign_seed": supervisor.DEVELOPMENT_SEED,
            "source_commit": self.source_commit,
            "physical_behavior_thresholds_applied": False,
            "physical_acceptance_authority": False,
        }
        success = {
            **common,
            "schema_version": supervisor.CELL_REPORT_SCHEMA,
            "execution": {
                "world_attempt_count": 1,
                "world_build_count": 1,
                "controller_semantic_step_count": 2,
            },
        }
        self.assertTrue(
            supervisor._validate_physical_terminal(spec, success, self.source_commit)
        )
        success["world_build_count"] = 1
        with self.assertRaisesRegex(
            supervisor.RouteSupervisorError, "SUCCESS_ROOT_COUNTS_FORBIDDEN"
        ):
            supervisor._validate_physical_terminal(spec, success, self.source_commit)

        failure = {
            **common,
            "schema_version": supervisor.WORKER_FAILURE_SCHEMA,
            "model_construction_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
        }
        self.assertFalse(
            supervisor._validate_physical_terminal(spec, failure, self.source_commit)
        )
        del failure["world_attempt_count"]
        with self.assertRaisesRegex(
            supervisor.RouteSupervisorError, "FAILURE_COUNTS_INVALID"
        ):
            supervisor._validate_physical_terminal(spec, failure, self.source_commit)

    def test_marker_parser_requires_exactly_one_object(self) -> None:
        marker = "ROUTE_MARKER "
        self.assertEqual(
            supervisor._marker_json("noise\nROUTE_MARKER {\"ok\":true}\n", marker),
            {"ok": True},
        )
        with self.assertRaisesRegex(supervisor.RouteSupervisorError, "MARKER_COUNT"):
            supervisor._marker_json(
                "ROUTE_MARKER {}\nROUTE_MARKER {}\n", marker
            )
        with self.assertRaisesRegex(supervisor.RouteSupervisorError, "MARKER_JSON"):
            supervisor._marker_json("ROUTE_MARKER not-json\n", marker)

    def test_godot_ready_receipt_is_nonce_process_and_exit_bound(self) -> None:
        receipt = {
            "schema_version": "sporespore_godot_supervised_termination_ready_v1",
            "termination_protocol_id": "godot_4_7_gdscript_shutdown_containment_v1",
            "termination_nonce": "6" * 32,
            "process_id": 200,
            "requested_exit_code": 0,
            "worker_receipt_emitted": True,
            "drained_process_frame_count": 2,
            "physics_evidence_authority": False,
        }
        with mock.patch.object(
            supervisor, "_process_is_self_or_descendant", return_value=True
        ):
            supervisor._validate_godot_ready_receipt(
                receipt, nonce="6" * 32, process_id=100
            )
            receipt["requested_exit_code"] = False
            with self.assertRaisesRegex(
                supervisor.RouteSupervisorError, "GODOT_READY_BINDING_INVALID"
            ):
                supervisor._validate_godot_ready_receipt(
                    receipt, nonce="6" * 32, process_id=100
                )

    def test_zero_world_counts_reject_json_booleans(self) -> None:
        value = {
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        }
        supervisor._validate_zero_counts(value, "control")
        value["world_build_count"] = False
        with self.assertRaisesRegex(
            supervisor.RouteSupervisorError, "ZERO_WORLD_COUNT_INVALID"
        ):
            supervisor._validate_zero_counts(value, "control")

    def test_exact_source_state_requires_clean_local_origin_and_live_equality(self) -> None:
        mapping = {
            ("rev-parse", "--show-toplevel"): str(REPO_ROOT.resolve()),
            ("remote", "get-url", "origin"): supervisor.EXPECTED_REMOTE,
            ("branch", "--show-current"): "main",
            ("status", "--porcelain=v1", "--untracked-files=all"): "",
            ("rev-parse", "HEAD"): self.source_commit,
            ("rev-parse", "origin/main"): self.source_commit,
            ("rev-parse", "HEAD^{tree}"): "2" * 40,
            ("ls-remote", "origin", "refs/heads/main"): (
                self.source_commit + "\trefs/heads/main"
            ),
        }

        def fake_git(arguments: tuple[str, ...]) -> str:
            return mapping[arguments]

        with mock.patch.object(supervisor, "_git", side_effect=fake_git):
            result = supervisor.verify_exact_source_state()
        self.assertTrue(result["local_remote_live_equal"])
        self.assertTrue(result["source_worktree_clean"])

        mapping[("status", "--porcelain=v1", "--untracked-files=all")] = "?? drift"
        with mock.patch.object(supervisor, "_git", side_effect=fake_git):
            with self.assertRaisesRegex(
                supervisor.RouteSupervisorError, "SOURCE_STATE_INVALID"
            ):
                supervisor.verify_exact_source_state()

    def test_authorization_receipt_must_bind_exact_attempt_root(self) -> None:
        runtime = self._runtime()
        spec = supervisor._worker_specs(runtime, self.source_commit)[1]
        attempt_root = self.root / "attempt"
        attempt_root.mkdir()
        receipt = {
            "schema_version": spec.authorization_schema,
            "ok": True,
            "failure_code": "",
            "route_id": supervisor.ROUTE_ID,
            "ledger_scope": supervisor.LEDGER_SCOPE,
            "engine_id": spec.engine_id,
            "cell_id": spec.cell_id,
            "attempt_root": str(attempt_root),
            "authorization_passed": True,
            "returned_before_model": True,
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
        supervisor._validate_authorization_receipt(spec, receipt, attempt_root)
        receipt["attempt_root"] = "\\\\?\\" + str(attempt_root)
        supervisor._validate_authorization_receipt(spec, receipt, attempt_root)
        receipt["attempt_root"] = str(self.root)
        with self.assertRaisesRegex(
            supervisor.RouteSupervisorError, "AUTHORIZATION_PREFLIGHT_INVALID"
        ):
            supervisor._validate_authorization_receipt(spec, receipt, attempt_root)


if __name__ == "__main__":
    unittest.main()
