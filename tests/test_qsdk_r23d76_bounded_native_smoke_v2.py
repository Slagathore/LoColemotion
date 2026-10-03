from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
SUPERVISOR_PATH = ROOT / "sdk/turning/r23d76_bounded_native_smoke_v2.py"
SPEC = importlib.util.spec_from_file_location("r23d76_bounded_native_smoke_v2", SUPERVISOR_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("R23D76 bounded native smoke v2 import failed")
smoke = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = smoke
SPEC.loader.exec_module(smoke)


class _Mutex:
    def __init__(self, role: str) -> None:
        self.role = role

    def __enter__(self) -> dict[str, object]:
        return {"role": self.role, "acquired": True, "physical_acceptance_authority": False}

    def __exit__(self, *_arguments: object) -> None:
        return None


class R23D76BoundedNativeSmokeV2Tests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        target = ROOT / "sdk/target"
        target.mkdir(parents=True, exist_ok=True)
        self._temporary = tempfile.TemporaryDirectory(
            prefix="r23d76-smoke-v2-test-", dir=target
        )
        self.root = Path(self._temporary.name)
        self.source_commit = "1" * 40
        self.source = {
            "repo_root": str(ROOT.resolve()),
            "origin_url": smoke.delegate.EXPECTED_REMOTE,
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

    def _runtime(self) -> object:
        paths: dict[str, Path] = {}
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
            paths[name] = path
        return smoke.delegate.RuntimePaths(
            python_host=paths["python.exe"],
            mujoco_python=paths["mujoco-python.exe"],
            godot=paths["godot.exe"],
            powershell=paths["pwsh.exe"],
            cargo=paths["cargo.exe"],
            rapier_binary=paths["turning_three_engine_route.exe"],
        )

    @staticmethod
    def _process(name: str, exit_code: int, stdout: str) -> dict[str, object]:
        return {
            "name": name,
            "command": [name],
            "cwd": str(ROOT),
            "exit_code": exit_code,
            "timed_out": False,
            "stdout": stdout,
            "stderr": "",
            "started_utc": "2026-08-26T00:00:00Z",
            "completed_utc": "2026-08-26T00:00:01Z",
        }

    def test_source_preflight_preserves_v1_and_all_r23d76_dependencies(self) -> None:
        receipt = smoke.preflight()
        self.assertTrue(receipt["v1_closure_audit_receipt"]["passed"])
        self.assertEqual(receipt["r23d76_dependency_count"], 222)
        self.assertTrue(receipt["precise_runtime_invalidation_check_pending"])
        self.assertEqual(receipt["focused_invalidated_artifact_preflight_process_count"], 0)
        self.assertEqual(receipt["redundant_native_preflight_process_count"], 0)
        self.assertEqual(receipt["physical_worker_process_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])

    def test_contract_mutations_fail_closed(self) -> None:
        mutations = (
            lambda value: value.__setitem__("status", "complete"),
            lambda value: value["predecessor"].__setitem__(
                "historical_result_reinterpreted", True
            ),
            lambda value: value["precise_invalidation"].__setitem__(
                "permitted_invalidated_artifact_count", 2
            ),
            lambda value: value["precise_invalidation"].__setitem__(
                "focused_zero_world_preflight_process_count", 0
            ),
            lambda value: value["bounded_population"].__setitem__(
                "development_seed", 23197
            ),
            lambda value: value["bounded_population"].__setitem__(
                "maximum_solver_step_count_per_engine", 3
            ),
            lambda value: value["execution_protocol"].__setitem__(
                "redundant_native_preflight_process_count", 1
            ),
            lambda value: value["execution_protocol"].__setitem__(
                "held_out_finite_campaign_execution_authorized", True
            ),
            lambda value: value["adequacy"].__setitem__("behavior_threshold", 0.1),
            lambda value: value["claims"].__setitem__("portable_basic_turning", True),
        )
        for index, mutate in enumerate(mutations):
            with self.subTest(index=index):
                candidate = copy.deepcopy(smoke.CONTRACT)
                mutate(candidate)
                with self.assertRaises(smoke.SmokeV2Error):
                    smoke.validate_contract(candidate)

    def test_runner_adds_only_focused_rapier_preflight_before_three_workers(self) -> None:
        runtime = self._runtime()
        specs = {
            spec.engine_id: spec
            for spec in smoke.delegate._worker_specs(runtime, self.source_commit)
        }
        names: list[str] = []

        def runner(**kwargs: object) -> dict[str, object]:
            name = str(kwargs["name"])
            names.append(name)
            if name == "rapier_build":
                return self._process(name, 0, "")
            if name == "rapier_invalidated_binary_preflight":
                spec = specs["rapier_parry"]
                receipt = {
                    "schema_version": spec.preflight_schema,
                    "ok": True,
                    "failure_code": "",
                    "route_id": smoke.delegate.ROUTE_ID,
                    "ledger_scope": smoke.delegate.LEDGER_SCOPE,
                    "engine_id": spec.engine_id,
                    "cell_id": spec.cell_id,
                    "campaign_seed": smoke.DEVELOPMENT_SEED,
                    "controller_step_count": 2,
                    "nonzero_turn_command_compiled": True,
                    "public_profile_route_compiled": True,
                    "negative_control_count": 2,
                    "negative_controls_rejected": 2,
                    "model_construction_count": 0,
                    "world_attempt_count": 0,
                    "world_build_count": 0,
                    "physical_execution_authorized": False,
                    "physical_behavior_thresholds_applied": False,
                    "physical_acceptance_authority": False,
                    "success_trace_retention_question_class_checked": True,
                }
                return self._process(name, 0, spec.preflight_marker + json.dumps(receipt))
            engine_id = next(engine for engine in smoke.ENGINE_IDS if name.startswith(engine))
            spec = specs[engine_id]
            terminal = {
                "schema_version": smoke.delegate.CELL_REPORT_SCHEMA,
                "route_id": smoke.delegate.ROUTE_ID,
                "ledger_scope": smoke.delegate.LEDGER_SCOPE,
                "question_class": "development",
                "engine_id": engine_id,
                "cell_id": spec.cell_id,
                "campaign_seed": smoke.DEVELOPMENT_SEED,
                "source_commit": self.source_commit,
                "execution": {
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                    "controller_semantic_step_count": 2,
                },
                "physical_behavior_thresholds_applied": False,
                "physical_acceptance_authority": False,
            }
            return self._process(name, 0, spec.terminal_marker + json.dumps(terminal))

        source_preflight = {
            "schema_version": "unit_test_source_preflight_v1",
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        }
        precise_proof = {
            "schema_version": "unit_test_precise_invalidation_v1",
            "exact_reuse_artifact_count": 14,
            "invalidated_artifact_count": 1,
            "physical_acceptance_authority": False,
        }
        with (
            mock.patch.object(smoke, "DEFAULT_EVIDENCE_ROOT", self.root),
            mock.patch.object(smoke, "preflight", return_value=source_preflight),
            mock.patch.object(
                smoke, "_precise_invalidation_proof", return_value=precise_proof
            ),
            mock.patch.object(smoke.delegate, "_dependency_artifacts", return_value=[]),
            mock.patch.object(
                smoke.delegate, "verify_exact_source_state", return_value=self.source
            ),
            mock.patch.object(smoke.delegate, "LocomotionOperationMutex", _Mutex),
        ):
            result = smoke.run(runtime, process_runner=runner)

        self.assertEqual(
            names,
            [
                "rapier_build",
                "rapier_invalidated_binary_preflight",
                "godot_jolt_bounded_native_smoke_v2",
                "rapier_parry_bounded_native_smoke_v2",
                "mujoco_bounded_native_smoke_v2",
            ],
        )
        self.assertTrue(result["bounded_native_smoke_passed"])
        self.assertEqual(result["focused_invalidated_artifact_preflight_process_count"], 1)
        self.assertEqual(result["redundant_native_preflight_process_count"], 0)
        self.assertEqual(result["physical_worker_process_count"], 3)
        self.assertEqual(result["world_attempt_count"], 3)
        self.assertEqual(result["world_build_count"], 3)
        self.assertEqual(result["exact_observed_solver_step_count"], 6)
        self.assertFalse(result["behavior_outcome_evaluated"])
        self.assertFalse(result["claims"]["physical_campaign_opened"])
        self.assertFalse(result["claims"]["finite_three_engine_turning"])


if __name__ == "__main__":
    unittest.main()
