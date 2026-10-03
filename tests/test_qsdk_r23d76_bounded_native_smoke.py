from __future__ import annotations

import copy
import importlib.util
import json
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


REPO_ROOT = Path(__file__).resolve().parents[1]
SUPERVISOR_PATH = REPO_ROOT / "sdk/turning/r23d76_bounded_native_smoke.py"
SPEC = importlib.util.spec_from_file_location(
    "r23d76_bounded_native_smoke", SUPERVISOR_PATH
)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("R23D76 bounded native smoke import failed")
smoke = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = smoke
SPEC.loader.exec_module(smoke)


class _FakeMutex:
    def __init__(self, role: str) -> None:
        self.role = role

    def __enter__(self) -> dict[str, object]:
        return {
            "schema_version": "unit_test_operation_lock_v1",
            "role": self.role,
            "acquired": True,
            "physical_acceptance_authority": False,
        }

    def __exit__(self, *_arguments: object) -> None:
        return None


class R23D76BoundedNativeSmokeTests(unittest.TestCase):
    maxDiff = None

    def setUp(self) -> None:
        target = REPO_ROOT / "sdk/target"
        target.mkdir(parents=True, exist_ok=True)
        self._temporary = tempfile.TemporaryDirectory(
            prefix="r23d76-bounded-smoke-test-", dir=target
        )
        self.root = Path(self._temporary.name)
        self.source_commit = "1" * 40
        self.source = {
            "repo_root": str(REPO_ROOT.resolve()),
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
        applications: dict[str, Path] = {}
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
        return smoke.delegate.RuntimePaths(
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
            "started_utc": "2026-08-26T00:00:00Z",
            "completed_utc": "2026-08-26T00:00:01Z",
        }

    def test_preflight_proves_complete_zero_world_reuse_without_opening_world(self) -> None:
        receipt = smoke.preflight()

        self.assertTrue(
            receipt["complete_zero_world_gate_reuse_source_dependencies_exact"]
        )
        self.assertTrue(receipt["delegate_cold_reuse_runtime_check_pending"])
        self.assertEqual(
            receipt["parent_authorities"]["r23d76_dependency_count"], 222
        )
        self.assertEqual(receipt["separate_native_preflight_process_count"], 0)
        self.assertEqual(receipt["separate_authorization_canary_process_count"], 0)
        self.assertEqual(receipt["aggregate_behavior_evaluator_process_count"], 0)
        self.assertEqual(receipt["full_seeded_ghost_process_count"], 0)
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physical_execution_authorized"])
        self.assertFalse(receipt["physical_acceptance_authority"])

    def test_declaration_mutations_fail_closed(self) -> None:
        mutations = (
            (
                "status",
                lambda value: value.__setitem__("status", "complete"),
            ),
            (
                "question_class",
                lambda value: value["ledger_scope"].__setitem__(
                    "question_class", "finite_decision"
                ),
            ),
            (
                "held_out_seed",
                lambda value: value["bounded_population"].__setitem__(
                    "development_seed", 23197
                ),
            ),
            (
                "engine_population",
                lambda value: value["bounded_population"].__setitem__(
                    "ordered_engine_ids", ["godot_jolt", "rapier_parry"]
                ),
            ),
            (
                "world_count",
                lambda value: value["bounded_population"].__setitem__(
                    "maximum_world_count", 4
                ),
            ),
            (
                "step_count",
                lambda value: value["bounded_population"].__setitem__(
                    "maximum_solver_step_count_per_engine", 3
                ),
            ),
            (
                "history_reinterpreted",
                lambda value: value["native_delegate"].__setitem__(
                    "historical_result_reinterpreted", True
                ),
            ),
            (
                "extra_preflight",
                lambda value: value["execution_protocol"].__setitem__(
                    "separate_native_preflight_process_count", 1
                ),
            ),
            (
                "aggregate_evaluator",
                lambda value: value["execution_protocol"].__setitem__(
                    "aggregate_behavior_evaluator_process_count", 1
                ),
            ),
            (
                "campaign_authority",
                lambda value: value["execution_protocol"].__setitem__(
                    "held_out_finite_campaign_execution_authorized", True
                ),
            ),
            (
                "behavior_threshold",
                lambda value: value["adequacy"].__setitem__(
                    "behavior_threshold", 0.1
                ),
            ),
            (
                "finite_evidence",
                lambda value: value["interpretation"].__setitem__(
                    "finite_evidence", True
                ),
            ),
            (
                "claim",
                lambda value: value["claims"].__setitem__(
                    "portable_basic_turning", True
                ),
            ),
        )
        for name, mutate in mutations:
            with self.subTest(name=name):
                candidate = copy.deepcopy(smoke.CONTRACT)
                mutate(candidate)
                with self.assertRaises(smoke.BoundedSmokeError):
                    smoke.validate_contract(candidate)

    def test_runner_uses_only_build_and_three_workers_and_retains_physics_failure(
        self,
    ) -> None:
        runtime = self._runtime()
        specs = {
            spec.engine_id: spec
            for spec in smoke.delegate._worker_specs(runtime, self.source_commit)
        }
        observed_names: list[str] = []

        def fake_runner(**kwargs: object) -> dict[str, object]:
            name = str(kwargs["name"])
            observed_names.append(name)
            if name == "rapier_build":
                return self._process(name, exit_code=0, stdout="")
            engine_id = next(engine for engine in smoke.ENGINE_IDS if name.startswith(engine))
            spec = specs[engine_id]
            if engine_id == "rapier_parry":
                terminal = {
                    "schema_version": smoke.delegate.WORKER_FAILURE_SCHEMA,
                    "route_id": smoke.delegate.ROUTE_ID,
                    "ledger_scope": smoke.delegate.LEDGER_SCOPE,
                    "question_class": "development",
                    "engine_id": engine_id,
                    "cell_id": spec.cell_id,
                    "campaign_seed": smoke.DEVELOPMENT_SEED,
                    "source_commit": self.source_commit,
                    "failure_code": "UNIT_TEST_PHYSICS_FAILURE_AFTER_WORLD_BUILD",
                    "model_construction_count": 1,
                    "world_attempt_count": 1,
                    "world_build_count": 1,
                    "physical_behavior_thresholds_applied": False,
                    "physical_acceptance_authority": False,
                }
                exit_code = 1
            else:
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
                exit_code = 0
            return self._process(
                name,
                exit_code=exit_code,
                stdout=spec.terminal_marker + json.dumps(terminal),
            )

        cold_reuse = {
            "schema_version": "unit_test_cold_reuse_v1",
            "complete_cold_gate_passed": True,
            "complete_dependency_toolchain_environment_key_exact": True,
            "physical_acceptance_authority": False,
        }
        source_preflight = {
            "schema_version": "unit_test_source_preflight_v1",
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
            "physical_acceptance_authority": False,
        }
        with (
            mock.patch.object(smoke, "DEFAULT_EVIDENCE_ROOT", self.root),
            mock.patch.object(smoke, "preflight", return_value=source_preflight),
            mock.patch.object(
                smoke, "_prove_delegate_cold_reuse", return_value=cold_reuse
            ),
            mock.patch.object(smoke.delegate, "_dependency_artifacts", return_value=[]),
            mock.patch.object(
                smoke.delegate,
                "verify_exact_source_state",
                return_value=self.source,
            ),
            mock.patch.object(smoke.delegate, "LocomotionOperationMutex", _FakeMutex),
        ):
            result = smoke.run_bounded_native_smoke(
                runtime,
                process_runner=fake_runner,
            )

        self.assertEqual(
            observed_names,
            [
                "rapier_build",
                "godot_jolt_bounded_native_smoke",
                "rapier_parry_bounded_native_smoke",
                "mujoco_bounded_native_smoke",
            ],
        )
        self.assertTrue(result["bounded_native_smoke_passed"])
        self.assertEqual(result["physical_worker_process_count"], 3)
        self.assertEqual(result["world_attempt_count"], 3)
        self.assertEqual(result["world_build_count"], 3)
        self.assertEqual(result["worker_success_terminal_count"], 2)
        self.assertEqual(result["worker_failure_terminal_count"], 1)
        self.assertIsNone(result["exact_observed_solver_step_count"])
        self.assertFalse(result["behavior_outcome_evaluated"])
        self.assertEqual(result["aggregate_behavior_evaluator_process_count"], 0)
        self.assertFalse(result["claims"]["physical_campaign_opened"])
        self.assertFalse(result["claims"]["finite_three_engine_turning"])
        self.assertFalse(result["physical_acceptance_authority"])


if __name__ == "__main__":
    unittest.main()
