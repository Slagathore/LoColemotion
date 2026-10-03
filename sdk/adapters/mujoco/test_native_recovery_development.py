from __future__ import annotations

import json
import math
from pathlib import Path
import struct
import sys
from tempfile import TemporaryDirectory
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import xml.etree.ElementTree as ET

import numpy as np


ADAPTER_ROOT = Path(__file__).resolve().parent
SDK_ROOT = ADAPTER_ROOT.parents[1]
SDK_PYTHON = SDK_ROOT / "python"
for path in (ADAPTER_ROOT, SDK_PYTHON):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sporespore_locomotion import LocomotionCore  # noqa: E402
from sporespore_mujoco_adapter import bounded_recovery_route_smoke as bounded_smoke  # noqa: E402
from sporespore_mujoco_adapter import energy_work_projection as energy_projection  # noqa: E402
from sporespore_mujoco_adapter import implicit_step_energy_trace as energy_trace  # noqa: E402
from sporespore_mujoco_adapter import native_recovery_development as route  # noqa: E402
from sporespore_mujoco_adapter import sparse_actuator_moment as sparse_moment  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d18_recovery_development_worker as worker,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d19_recovery_development_worker as worker19,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d20_recovery_development_worker as worker20,
)
from sporespore_mujoco_adapter import recovery_morphology_route as recovery_route  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    recovery_observation_v2_morphology_route as morphology_observation_route,
)
from sporespore_mujoco_adapter import recovery_context_qualification  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d23_recovery_morphology_worker as worker23,
)
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d24_recovery_context_observer_worker as worker24,
)


CORE_LIBRARY = SDK_ROOT / "target" / "debug" / "sporespore_locomotion_core.dll"
CONTRACT_PATH = (
    SDK_ROOT / "recovery" / "r24d18_mujoco_native_recovery_development_contract_v1.json"
)
CONTRACT19_PATH = (
    SDK_ROOT / "recovery" / "r24d19_public_profile_validator_successor_contract_v1.json"
)
CONTRACT20_PATH = (
    SDK_ROOT
    / "recovery"
    / "r24d20_production_timestep_identity_successor_contract_v1.json"
)
CONTRACT23_PATH = (
    SDK_ROOT
    / "recovery"
    / "r24d23_mujoco_recovery_morphology_route_contract_v1.json"
)
CONTRACT24_PATH = (
    SDK_ROOT
    / "recovery"
    / "r24d24_recovery_context_contact_observer_contract_v1.json"
)


def public_profile_fixture(
    timestep_s: float,
) -> tuple[object, dict[str, object], dict[str, int]]:
    """Build a model-shaped zero-world fixture without constructing MuJoCo state."""

    class FakeOption:
        timestep = timestep_s
        integrator = int(route.mujoco.mjtIntegrator.mjINT_IMPLICITFAST)

    class FakeModel:
        nu = len(route.ORDERED_ACTUATOR_IDS)
        njnt = len(route.ORDERED_JOINT_IDS) + 1
        nbody = 10
        opt = FakeOption()
        actuator_gainprm = np.zeros((len(route.ORDERED_ACTUATOR_IDS), 10))
        actuator_biasprm = np.zeros((len(route.ORDERED_ACTUATOR_IDS), 10))
        actuator_forcelimited = np.ones(
            len(route.ORDERED_ACTUATOR_IDS),
            dtype=bool,
        )
        actuator_forcerange = np.asarray(
            [
                [-cap / route.OUTER_DT_S, cap / route.OUTER_DT_S]
                for cap in route.ORDERED_CAPS_NMS
            ],
            dtype=np.float64,
        )

    FakeModel.actuator_gainprm[:, 0] = route.VELOCITY_GAIN_NM_S_PER_RAD
    FakeModel.actuator_biasprm[:, 2] = -route.VELOCITY_GAIN_NM_S_PER_RAD
    actuator_ids = {
        actuator_id: index
        for index, actuator_id in enumerate(route.ORDERED_ACTUATOR_IDS)
    }
    binding: dict[str, object] = {
        "ok": True,
        "profile_id": route.PUBLIC_ACTUATOR_PROFILE_ID,
        "completed_before_first_solver_step": True,
        "solver_step_count_at_binding": 0,
        "all_readbacks_match": True,
        "ordered_bindings": [
            {
                "profile_actuator_id": actuator_id,
                "trace_actuator_id": actuator_id,
                "joint_id": joint_id,
                "declared_maximum_outer_step_impulse_nms": cap,
                "readback_matches": True,
            }
            for actuator_id, joint_id, cap in zip(
                route.ORDERED_ACTUATOR_IDS,
                route.ORDERED_JOINT_IDS,
                route.ORDERED_CAPS_NMS,
                strict=True,
            )
        ],
    }
    return FakeModel(), binding, actuator_ids


class MujocoNativeRecoveryDevelopmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.core = LocomotionCore(CORE_LIBRARY)

    def test_zero_world_preflight_crosses_real_route_without_constructing_world(self) -> None:
        with patch.object(
            route,
            "MujocoNativeRecoveryWorld",
            wraps=route.MujocoNativeRecoveryWorld,
        ) as guarded_world:
            receipt = route.run_zero_world_preflight(self.core)

        guarded_world.assert_not_called()
        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["engine"], "mujoco_native")
        self.assertEqual(receipt["engine_version"], "3.11.0")
        self.assertEqual(
            receipt["threshold_profile_id"],
            route.PHYSICAL_THRESHOLD_PROFILE_ID,
        )
        self.assertTrue(receipt["production_constructor_callable"])
        self.assertTrue(receipt["production_step_callable"])
        self.assertTrue(receipt["production_finalize_callable"])
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["physical_question_opened"])
        self.assertFalse(receipt["prone_to_standing_claimed"])

    def test_energy_work_v2_uses_independent_native_force_terms(self) -> None:
        measured = route.measure_native_energy_work_v2(
            timestep_s=0.1,
            actuator_force=[1.0],
            actuator_velocity=[2.0],
            generalized_velocity=[2.0, -1.0],
            generalized_actuator_force=[3.0, 4.0],
            generalized_constraint_force=[-2.0, 1.0],
            generalized_damper_force=[-1.0, 0.0],
            generalized_fluid_force=[0.0, 0.5],
            generalized_adhesion_force=[0.0, 0.0],
        )

        self.assertAlmostEqual(measured.actuator_work_j, 0.2)
        self.assertAlmostEqual(measured.generalized_actuator_work_j, 0.2)
        self.assertAlmostEqual(measured.constraint_work_j, -0.5)
        self.assertAlmostEqual(measured.damper_work_j, -0.2)
        self.assertAlmostEqual(measured.fluid_work_j, -0.05)
        self.assertEqual(measured.adhesion_work_j, 0.0)
        self.assertAlmostEqual(measured.dissipated_energy_j, 0.75)

    def test_energy_work_v2_rejects_actuator_crosscheck_and_shape_mutations(self) -> None:
        common = {
            "timestep_s": 0.1,
            "actuator_force": [1.0],
            "actuator_velocity": [2.0],
            "generalized_velocity": [2.0, -1.0],
            "generalized_actuator_force": [3.0, 4.0],
            "generalized_constraint_force": [-2.0, 1.0],
            "generalized_damper_force": [-1.0, 0.0],
            "generalized_fluid_force": [0.0, 0.5],
            "generalized_adhesion_force": [0.0, 0.0],
        }
        mismatched = dict(common)
        mismatched["generalized_actuator_force"] = [0.0, 0.0]
        with self.assertRaisesRegex(
            route.NativeRecoveryRouteError,
            "QSDK_R24D31_ACTUATOR_WORK_CROSSCHECK_FAILED",
        ):
            route.measure_native_energy_work_v2(**mismatched)

        malformed = dict(common)
        malformed["generalized_constraint_force"] = [1.0]
        with self.assertRaisesRegex(
            route.NativeRecoveryRouteError,
            "QSDK_R24D31_QFRC_CONSTRAINT_SHAPE_MISMATCH",
        ):
            route.measure_native_energy_work_v2(**malformed)

    def test_implicit_step_v3_samples_before_one_genuine_implicit_advance(self) -> None:
        calls: list[str] = []
        public_sparse2dense = route.mujoco.mju_sparse2dense
        model = SimpleNamespace(
            nout=1,
            nv=1,
            nJmom=1,
            opt=SimpleNamespace(
                integrator=int(route.mujoco.mjtIntegrator.mjINT_IMPLICITFAST),
                timestep=0.1,
                enableflags=0,
            )
        )
        data = SimpleNamespace(
            ctrl=np.asarray([1.0], dtype=np.float64),
            qvel=np.asarray([0.0], dtype=np.float64),
            time=0.0,
            actuator_velocity=np.asarray([0.0], dtype=np.float64),
            actuator_force=np.asarray([0.0], dtype=np.float64),
            actuator_moment=np.asarray([1.0], dtype=np.float64),
            moment_rownnz=np.asarray([1], dtype=np.int32),
            moment_rowadr=np.asarray([0], dtype=np.int32),
            moment_colind=np.asarray([0], dtype=np.int32),
            qfrc_actuator=np.asarray([0.0], dtype=np.float64),
            qfrc_constraint=np.asarray([0.0], dtype=np.float64),
            qfrc_damper=np.asarray([0.0], dtype=np.float64),
            qfrc_fluid=np.asarray([0.0], dtype=np.float64),
            qfrc_adhesion=np.asarray([0.0], dtype=np.float64),
            flg_rnepost=1,
        )

        def fwd_actuation(_model: object, state: object) -> None:
            calls.append("mj_fwdActuation")
            state.actuator_velocity[:] = state.qvel
            state.actuator_force[:] = 10.0
            state.qfrc_actuator[:] = 10.0

        def record(name: str):
            def inner(_model: object, _data: object) -> None:
                calls.append(name)

            return inner

        def implicit(_model: object, state: object) -> None:
            calls.append("mj_implicit")
            state.qvel[:] = 1.0 / 3.0
            state.time += 0.1
            # Prove the receipt owns pre-integration copies rather than live views.
            state.actuator_force[:] = 999.0
            state.qfrc_actuator[:] = 999.0

        def sparse2dense(*arguments: object) -> None:
            calls.append("mju_sparse2dense")
            public_sparse2dense(*arguments)

        with (
            patch.object(route.mujoco, "mj_fwdActuation", side_effect=fwd_actuation),
            patch.object(
                route.mujoco,
                "mj_fwdAcceleration",
                side_effect=record("mj_fwdAcceleration"),
            ),
            patch.object(
                route.mujoco,
                "mj_fwdConstraint",
                side_effect=record("mj_fwdConstraint"),
            ),
            patch.object(
                route.mujoco,
                "mj_sensorAcc",
                side_effect=record("mj_sensorAcc"),
            ),
            patch.object(
                route.mujoco,
                "mj_checkAcc",
                side_effect=record("mj_checkAcc"),
            ),
            patch.object(
                route.mujoco,
                "mju_sparse2dense",
                side_effect=sparse2dense,
            ),
            patch.object(route.mujoco, "mj_implicit", side_effect=implicit),
            patch.object(route.mujoco, "mj_step2") as forbidden_step2,
        ):
            measured = route.advance_implicitfast_after_control_v3(
                model=model,
                data=data,
                target_actuator_velocity_rad_s=[1.0],
                velocity_gain_nm_s_per_rad=[10.0],
                force_range_lower_nm=[-100.0],
                force_range_upper_nm=[100.0],
            )

        self.assertEqual(
            calls,
            [
                "mj_fwdActuation",
                "mj_fwdAcceleration",
                "mj_fwdConstraint",
                "mj_sensorAcc",
                "mj_checkAcc",
                "mju_sparse2dense",
                "mj_implicit",
            ],
        )
        forbidden_step2.assert_not_called()
        self.assertEqual(measured.reported_pre_actuator_force_nm, (10.0,))
        self.assertEqual(measured.reported_pre_generalized_actuator_force, (10.0,))
        self.assertEqual(measured.pre_generalized_velocity, (0.0,))
        self.assertEqual(measured.post_generalized_velocity, (1.0 / 3.0,))
        self.assertEqual(measured.historical_v2.actuator_work_j, 0.0)
        self.assertAlmostEqual(
            measured.implicit_v3.effective_centered_actuator_work_j,
            (1.0 / 3.0) ** 2,
        )
        receipt = measured.receipt_v1(3)
        self.assertEqual(receipt["native_substep"], 3)
        self.assertEqual(receipt["native_timestep_s"], 0.1)
        self.assertEqual(receipt["reported_pre_actuator_force_nm"], [10.0])
        self.assertEqual(
            receipt["implicit_v3"]["energy_ledger_profile_id"],
            route.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
        )
        sparse_receipt = measured.receipt_v2(3)
        self.assertEqual(
            sparse_receipt["schema_version"],
            route.SPARSE_MOMENT_IMPLICIT_SUBSTEP_RECEIPT_SCHEMA,
        )
        self.assertEqual(
            sparse_receipt["actuator_moment_expansion_profile_id"],
            sparse_moment.PROFILE_ID,
        )
        self.assertEqual(
            sparse_receipt["actuator_moment_expansion"]["dense_actuator_moment"],
            [[1.0]],
        )
        projected_receipt = measured.receipt_v3(3)
        self.assertEqual(
            projected_receipt["schema_version"],
            route.SIGNED_WORK_PREPROJECTION_SUBSTEP_RECEIPT_SCHEMA,
        )
        self.assertEqual(
            projected_receipt["energy_work_preprojection_profile_id"],
            energy_projection.PROFILE_ID,
        )
        for projection_name in (
            "historical_v2_energy_preprojection",
            "portable_v3_energy_preprojection",
        ):
            projection = projected_receipt[projection_name]
            self.assertEqual(
                projection["portable_v1_projection"]["support_status"],
                "supported_exact",
            )
            self.assertEqual(
                projection["portable_v1_projection"][
                    "dissipated_energy_increment_j"
                ],
                0.0,
            )

    def test_signed_work_preprojection_retains_sign_and_refuses_portable_v1(
        self,
    ) -> None:
        positive = energy_projection.classify_energy_work_for_portable_v1(
            constraint_work_j=0.25,
            damper_work_j=0.0,
            fluid_work_j=0.0,
            adhesion_work_j=0.0,
        ).receipt_v1()
        negative = energy_projection.classify_energy_work_for_portable_v1(
            constraint_work_j=-0.5,
            damper_work_j=0.0,
            fluid_work_j=0.0,
            adhesion_work_j=0.0,
        ).receipt_v1()
        passive = energy_projection.classify_energy_work_for_portable_v1(
            constraint_work_j=0.0,
            damper_work_j=-0.125,
            fluid_work_j=0.0,
            adhesion_work_j=0.0,
        ).receipt_v1()

        self.assertEqual(
            positive["source_terms"]["signed_constraint_work_j"],
            0.25,
        )
        self.assertEqual(
            negative["source_terms"]["signed_constraint_work_j"],
            -0.5,
        )
        for receipt in (positive, negative):
            self.assertEqual(
                receipt["portable_v1_projection"]["support_status"],
                "unsupported_capability",
            )
            self.assertEqual(
                receipt["portable_v1_projection"]["refusal_reason"],
                energy_projection.SIGNED_CONSTRAINT_REFUSAL,
            )
            self.assertIsNone(
                receipt["portable_v1_projection"][
                    "dissipated_energy_increment_j"
                ]
            )
            self.assertFalse(receipt["absolute_value_applied"])
            self.assertFalse(receipt["negative_value_clamped"])
        self.assertEqual(
            passive["source_terms"]["signed_damper_work_j"],
            -0.125,
        )
        self.assertEqual(
            passive["portable_v1_projection"]["refusal_reason"],
            energy_projection.PASSIVE_WORK_REFUSAL,
        )

        summary = energy_projection.summarize_energy_work_preprojections_v1(
            [positive, negative]
        )
        self.assertEqual(
            summary["source_term_sums"]["signed_constraint_work_j"],
            -0.25,
        )
        self.assertEqual(
            [item["index"] for item in summary["refused_substeps"]],
            [0, 1],
        )
        mutated = json.loads(json.dumps(positive))
        mutated["portable_v1_projection"]["refusal_reason"] = None
        with self.assertRaisesRegex(
            energy_projection.EnergyWorkProjectionError,
            "QSDK_R24D36_PREPROJECTION_RECEIPT_MUTATED",
        ):
            energy_projection.validate_energy_work_preprojection_receipt_v1(
                mutated
            )

        controls, _details = (
            energy_projection.energy_work_projection_zero_world_controls_v1()
        )
        self.assertEqual(len(controls), 6)
        self.assertTrue(all(controls.values()))

    def test_sparse_actuator_moment_expansion_and_mutations_are_zero_world(self) -> None:
        common = {
            "values": [2.0, -1.0, 4.0, 3.0],
            "rownnz": [1, 2, 1],
            "rowadr": [0, 1, 3],
            "colind": [0, 1, 4, 3],
            "nout": 3,
            "nv": 5,
            "nJmom": 4,
        }
        expanded = sparse_moment.expand_sparse_actuator_moment_v1(**common)
        self.assertEqual(
            expanded.dense,
            (
                (2.0, 0.0, 0.0, 0.0, 0.0),
                (0.0, -1.0, 0.0, 0.0, 4.0),
                (0.0, 0.0, 0.0, 3.0, 0.0),
            ),
        )
        self.assertEqual(
            sparse_moment.validate_sparse_actuator_moment_receipt_v1(
                expanded.receipt_v1()
            ),
            expanded,
        )
        malformed_receipt = expanded.receipt_v1()
        malformed_receipt["dense_actuator_moment"] = [["not-a-number"]]
        with self.assertRaisesRegex(
            sparse_moment.SparseActuatorMomentError,
            "QSDK_R24D35_RECEIPT_MALFORMED",
        ):
            sparse_moment.validate_sparse_actuator_moment_receipt_v1(
                malformed_receipt
            )
        mutations = (
            ({"values": [2.0]}, "QSDK_R24D35_SPARSE_VALUE_COUNT"),
            ({"rownnz": [1, 1, 1]}, "QSDK_R24D35_ROWNNZ_TOTAL"),
            ({"rowadr": [0, 2, 3]}, "QSDK_R24D35_ROWADR_NOT_PACKED"),
            ({"colind": [0, 1, 5, 3]}, "QSDK_R24D35_COLIND_RANGE"),
            ({"values": [2.0, math.nan, 4.0, 3.0]}, "QSDK_R24D35_SPARSE_VALUE_NONFINITE"),
        )
        for mutation, code in mutations:
            with self.subTest(code=code):
                arguments = dict(common)
                arguments.update(mutation)
                with self.assertRaisesRegex(
                    sparse_moment.SparseActuatorMomentError,
                    code,
                ):
                    sparse_moment.expand_sparse_actuator_moment_v1(**arguments)

        def corrupt(dense: np.ndarray, *_args: object) -> None:
            dense[:] = 1.0

        with self.assertRaisesRegex(
            sparse_moment.SparseActuatorMomentError,
            "QSDK_R24D35_INDEPENDENT_DENSE_MISMATCH",
        ):
            sparse_moment.expand_sparse_actuator_moment_v1(
                **common,
                sparse2dense=corrupt,
            )
        controls, _details = (
            sparse_moment.sparse_actuator_moment_zero_world_controls_v1()
        )
        self.assertTrue(all(controls.values()))

    def test_sparse_expansion_receipt_replays_through_retained_trace(self) -> None:
        trace = energy_trace.synthetic_sparse_actuator_moment_trace_v1()
        validated = energy_trace.validate_implicit_step_energy_trace_v1(
            trace,
            expected_route_id=route.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID,
            expected_native_receipt_schema=(
                route.SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
            ),
            require_sparse_actuator_moment_expansion=True,
        )
        self.assertEqual(validated["validated_native_substep_count"], 10)
        self.assertEqual(
            validated["sparse_actuator_moment_expansion_receipt_count"],
            10,
        )

        trace["candidate"]["native_receipts"][0]["native_step"][
            "implicit_substep_energy_receipts"
        ][0]["actuator_moment_expansion"]["dense_actuator_moment"] = [[2.0]]
        with self.assertRaisesRegex(
            energy_trace.ImplicitStepEnergyTraceError,
            "QSDK_R24D35_SPARSE_EXPANSION_RECEIPT_INVALID",
        ):
            energy_trace.validate_implicit_step_energy_trace_v1(
                trace,
                expected_route_id=route.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID,
                expected_native_receipt_schema=(
                    route.SPARSE_MOMENT_IMPLICIT_STEP_NATIVE_RECEIPT_SCHEMA
                ),
                require_sparse_actuator_moment_expansion=True,
            )

    def test_bounded_smoke_publisher_is_zero_world_and_qualification_gated(self) -> None:
        source_commit = "a" * 40
        contract = {
            "source_inventory": [],
            "selected_development_cell": {"cell_id": "development"},
            "ghost_horizon": {"outer_steps_per_arm": 2},
            "bounded_native_code_path_smoke": {
                "maximum_model_construction_count": 2,
                "maximum_world_attempt_count": 2,
                "maximum_world_build_count": 2,
                "maximum_total_outer_steps": 4,
                "maximum_total_native_solver_steps": 20,
            },
        }
        result = {
            "model_construction_count": 2,
            "world_attempt_count": 2,
            "world_build_count": 2,
            "outer_step_count": 4,
            "native_solver_step_count": 20,
        }
        invariants = {
            "validated_outer_step_count": 4,
            "validated_native_substep_count": 20,
        }
        source_state = {
            "head_commit": source_commit,
            "worktree_clean": True,
            "source_manifest_canonical_sha256": "sha256:" + "b" * 64,
        }
        schemas = bounded_smoke.SmokeSchemasV1("result_v1", "summary_v1", "manifest_v1")
        exact_route = object()
        route_factory_cores: list[LocomotionCore] = []

        def route_factory(core: LocomotionCore) -> object:
            route_factory_cores.append(core)
            return exact_route

        with TemporaryDirectory() as temporary:
            root = Path(temporary)
            contract_path = root / "contract.json"
            qualification_path = root / "qualification.json"
            lock_path = root / "lock.json"
            contract_path.write_text("{}\n", encoding="utf-8")
            qualification = {
                "schema_version": "qualification_v1",
                "gate_id": "GATE",
                "mode": "qualification",
                "ok": True,
                "source_commit": source_commit,
                "model_construction_count": 0,
                "world_attempt_count": 0,
                "world_build_count": 0,
                "solver_step_count": 0,
                "physics_state_modified": False,
            }
            qualification_path.write_text(json.dumps(qualification), encoding="utf-8")
            lock_path.write_text(
                json.dumps({"acquired": True, "role": "physical", "test_only": False}),
                encoding="utf-8",
            )
            with (
                patch.object(
                    bounded_smoke.source_inventory,
                    "_source_state",
                    return_value=source_state,
                ),
                patch.object(
                    bounded_smoke.runtime,
                    "run_paired_development",
                    return_value=result,
                ) as run,
            ):
                completion = bounded_smoke.run_and_publish_v1(
                    core_library=CORE_LIBRARY,
                    contract_path=contract_path,
                    contract=contract,
                    output_directory=root,
                    source_commit=source_commit,
                    qualification_receipt_path=qualification_path,
                    operation_lock_receipt_path=lock_path,
                    gate_id="GATE",
                    campaign_id="CAMPAIGN",
                    qualification_receipt_schema="qualification_v1",
                    schemas=schemas,
                    world_type=route.MujocoSparseMomentImplicitStepRecoveryWorld,
                    trace_validator=lambda _value: invariants,
                    route_factory=route_factory,
                )
            self.assertTrue(completion["ok"])
            self.assertEqual(run.call_args.kwargs["horizon_steps"], 2)
            self.assertIs(run.call_args.kwargs["route"], exact_route)
            self.assertEqual(len(route_factory_cores), 1)
            self.assertIs(route_factory_cores[0], run.call_args.args[0])
            self.assertTrue((root / "smoke_result.json").is_file())
            self.assertTrue((root / "smoke_summary.json").is_file())
            self.assertTrue((root / "manifest.json").is_file())

            qualification["ok"] = False
            bad_path = root / "bad_qualification.json"
            bad_path.write_text(json.dumps(qualification), encoding="utf-8")
            with (
                patch.object(bounded_smoke.runtime, "run_paired_development") as forbidden,
                self.assertRaisesRegex(
                    bounded_smoke.BoundedRecoveryRouteSmokeError,
                    "QUALIFICATION_RECEIPT_INVALID",
                ),
            ):
                bounded_smoke.run_and_publish_v1(
                    core_library=CORE_LIBRARY,
                    contract_path=contract_path,
                    contract=contract,
                    output_directory=root,
                    source_commit=source_commit,
                    qualification_receipt_path=bad_path,
                    operation_lock_receipt_path=lock_path,
                    gate_id="GATE",
                    campaign_id="CAMPAIGN",
                    qualification_receipt_schema="qualification_v1",
                    schemas=schemas,
                    world_type=route.MujocoSparseMomentImplicitStepRecoveryWorld,
                    trace_validator=lambda _value: invariants,
                )
            forbidden.assert_not_called()

    def test_observation_v2_recovery_morphology_conjunction_is_zero_world(self) -> None:
        with patch.object(recovery_route.mujoco.MjModel, "from_xml_string") as model:
            exact_route = recovery_route.compile_recovery_morphology_model_route(
                self.core
            )
            receipt = morphology_observation_route.validate_recovery_observation_v2_morphology_conjunction_v1(
                self.core,
                exact_route,
                morphology_observation_route.MujocoRecoveryMorphologyObservationV2World,
            )
            base_route = route.compile_public_profile_model_route(self.core)
            with self.assertRaisesRegex(
                morphology_observation_route.RecoveryObservationV2MorphologyRouteError,
                "QSDK_R24D41_RECOVERY_MORPHOLOGY_ROUTE_REQUIRED",
            ):
                morphology_observation_route.validate_recovery_observation_v2_morphology_conjunction_v1(
                    self.core,
                    base_route,
                    morphology_observation_route.MujocoRecoveryMorphologyObservationV2World,
                )
            with self.assertRaisesRegex(
                morphology_observation_route.RecoveryObservationV2MorphologyRouteError,
                "QSDK_R24D41_COMPOSITE_WORLD_REQUIRED",
            ):
                morphology_observation_route.validate_recovery_observation_v2_morphology_conjunction_v1(
                    self.core,
                    exact_route,
                    route.MujocoObservationV2RecoveryWorld,
                )

        model.assert_not_called()
        self.assertTrue(receipt["ok"])
        self.assertEqual(
            receipt["compiled_receipt_schema"],
            "sporespore_recovery_morphology_receipt_v1",
        )
        self.assertEqual(
            receipt["native_source_route_id"],
            route.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        )
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)

    def test_implicit_step_v3_preflight_is_zero_world_and_route_is_distinct(self) -> None:
        with patch.object(route.mujoco.MjModel, "from_xml_string") as constructor:
            receipt = route.run_implicit_step_energy_zero_world_preflight(self.core)

        constructor.assert_not_called()
        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["route_id"], route.IMPLICIT_STEP_ROUTE_ID)
        self.assertEqual(
            receipt["energy_ledger_profile_id"],
            route.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
        )
        self.assertEqual(
            route.MujocoImplicitStepRecoveryWorld.energy_ledger_profile_id,
            route.IMPLICIT_STEP_ENERGY_LEDGER_PROFILE_ID,
        )
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_attempt_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)
        self.assertFalse(receipt["physics_state_modified"])

        with patch.object(route.mujoco.MjModel, "from_xml_string") as constructor:
            sparse_receipt = route.run_sparse_actuator_moment_zero_world_preflight(
                self.core
            )
        constructor.assert_not_called()
        self.assertEqual(
            sparse_receipt["route_id"],
            route.SPARSE_MOMENT_IMPLICIT_STEP_ROUTE_ID,
        )
        self.assertEqual(
            sparse_receipt["actuator_moment_expansion_profile_id"],
            sparse_moment.PROFILE_ID,
        )
        self.assertEqual(sparse_receipt["model_construction_count"], 0)
        self.assertEqual(sparse_receipt["world_attempt_count"], 0)
        self.assertEqual(sparse_receipt["solver_step_count"], 0)

        with patch.object(route.mujoco.MjModel, "from_xml_string") as constructor:
            signed_receipt = (
                route.run_signed_work_preprojection_zero_world_preflight(
                    self.core
                )
            )
        constructor.assert_not_called()
        self.assertEqual(
            signed_receipt["route_id"],
            route.SIGNED_WORK_PREPROJECTION_ROUTE_ID,
        )
        self.assertEqual(
            signed_receipt["energy_work_preprojection_profile_id"],
            energy_projection.PROFILE_ID,
        )
        self.assertEqual(
            sum(signed_receipt["energy_work_preprojection_controls"].values()),
            6,
        )
        self.assertTrue(signed_receipt["typed_preprojection_refusal_callable"])
        self.assertFalse(
            signed_receipt["portable_v1_signed_constraint_channel_present"]
        )
        self.assertEqual(signed_receipt["model_construction_count"], 0)
        self.assertEqual(signed_receipt["world_attempt_count"], 0)
        self.assertEqual(signed_receipt["solver_step_count"], 0)
        self.assertFalse(signed_receipt["physical_question_opened"])

    def test_binary64_receipt_is_explicit_little_endian(self) -> None:
        value = -17.25
        self.assertEqual(route._binary64_hex(value), struct.pack("<d", value).hex())

    def test_bootstrap_and_controller_ownership_are_paired_and_fail_closed(self) -> None:
        candidate = route._bootstrap_control(
            self.core,
            "candidate_command",
            "confirm_prone",
        )
        matched_zero = route._bootstrap_control(
            self.core,
            "matched_zero_command",
            "confirm_prone",
        )

        self.assertTrue(candidate["no_actuation_requested"])
        self.assertEqual(candidate["ordered_commands"], [])
        self.assertFalse(candidate["matched_zero_command"])
        self.assertTrue(matched_zero["no_actuation_requested"])
        self.assertEqual(matched_zero["ordered_commands"], [])
        self.assertTrue(matched_zero["matched_zero_command"])
        self.assertEqual(
            route._controller_owner("candidate_command", "confirm_prone")["owner"],
            "recovery",
        )
        self.assertEqual(
            route._controller_owner("matched_zero_command", "raise_body")["owner"],
            "none",
        )
        self.assertEqual(
            route._controller_owner("candidate_command", "stance_handoff")["owner"],
            "stance",
        )

    def test_physical_entry_rejects_non_development_before_model_construction(self) -> None:
        cell = {
            "question_class": "held_out_validation",
            "cell_id": "heldout_mujoco_nominal",
        }
        with patch.object(route, "compile_public_profile_model_route") as compile_route:
            with self.assertRaisesRegex(
                route.NativeRecoveryRouteError,
                "QSDK_R24D18_NONDEVELOPMENT_CELL",
            ):
                route.run_paired_development(self.core, cell=cell, horizon_steps=14)
        compile_route.assert_not_called()

    def test_physical_entry_rejects_unbounded_horizon_before_model_construction(self) -> None:
        cell = {
            "question_class": "development",
            "cell_id": "development_nominal",
        }
        with patch.object(route, "compile_public_profile_model_route") as compile_route:
            with self.assertRaisesRegex(
                route.NativeRecoveryRouteError,
                "QSDK_R24D18_HORIZON",
            ):
                route.run_paired_development(self.core, cell=cell, horizon_steps=1201)
        compile_route.assert_not_called()

    def test_native_collection_acceptance_helper_returns_exact_positive(self) -> None:
        collected = {
            "support_status": "supported_exact",
            "refusal_reason": None,
            "supplied_native_post_step_observation_validated": True,
        }
        returned = route.require_supported_native_collection_v1(
            collected,
            refusal_context={"semantic_step": 7},
        )
        self.assertIs(returned, collected)

    def test_native_collection_refusal_preserves_exact_context(self) -> None:
        collected = {
            "schema_version": "sporespore_recovery_native_collection_receipt_v1",
            "support_status": "invalid_observation",
            "refusal_reason": "energy_balance_invalid",
            "supplied_native_post_step_observation_validated": False,
            "observation": None,
            "solver_step_count": 0,
        }
        context = {
            "schema_version": "sporespore_mujoco_recovery_arm_partial_state_v1",
            "arm_kind": "candidate_command",
            "semantic_step": 19,
            "phase": "establish_distal_support",
            "current_observation": {"semantic_step": 19},
            "current_native_receipt": {"solver_step_count": 100},
            "accepted_prefix": {"observations": [{"semantic_step": 18}]},
            "execution_counts": {
                "model_construction_count": 1,
                "world_attempt_count": 1,
                "world_build_count": 1,
                "native_outer_steps_completed": 20,
                "portable_steps_accepted": 19,
                "native_solver_step_count": 100,
                "physics_state_modified": True,
            },
        }
        with self.assertRaises(route.NativeRecoveryCollectionRefusal) as caught:
            route.require_supported_native_collection_v1(
                collected,
                refusal_context=context,
            )
        error = caught.exception
        self.assertIsInstance(error, route.NativeRecoveryRouteError)
        self.assertEqual(str(error), "QSDK_R24D18_NATIVE_COLLECTION_REFUSED")
        diagnostic = error.diagnostic
        self.assertEqual(diagnostic["collector_receipt"], collected)
        self.assertEqual(
            diagnostic["collector_support_status"],
            "invalid_observation",
        )
        self.assertEqual(
            diagnostic["collector_refusal_reason"],
            "energy_balance_invalid",
        )
        self.assertEqual(diagnostic["refusal_context"], context)
        json.dumps(diagnostic, allow_nan=False, sort_keys=True)

    def test_worker_binds_only_the_predeclared_nominal_development_cell(self) -> None:
        contract = worker.load_contract_v1(CONTRACT_PATH)
        cell = contract["selected_development_cell"]

        self.assertEqual(cell["question_class"], "development")
        self.assertEqual(cell["cell_id"], worker.EXPECTED_CELL_ID)
        self.assertEqual(cell["seed"], worker.EXPECTED_SEED)
        self.assertEqual(cell["random_draw_count"], 0)
        self.assertEqual(
            contract["held_out_seal"]["held_out_selector_invocation_count"],
            0,
        )

    def test_compact_projection_requires_real_candidate_command_coverage(self) -> None:
        def arm(active_count: int) -> dict[str, object]:
            return {
                "final_phase": "establish_distal_support",
                "observations": [{} for _ in range(worker.EXPECTED_HORIZON_STEPS)],
                "native_receipts": [
                    {
                        "application": {
                            "no_actuation_requested": index >= active_count,
                        }
                    }
                    for index in range(worker.EXPECTED_HORIZON_STEPS)
                ],
            }

        full = {
            "candidate": arm(2),
            "matched_zero_command": arm(0),
            "evaluation": {
                "physical_development_trace_valid": True,
                "verdict": "physical_development_incomplete",
                "physical_result": False,
            },
            "initializer_identity_matched": True,
            "model_construction_count": worker.EXPECTED_PAIRED_ARM_COUNT,
            "world_attempt_count": worker.EXPECTED_PAIRED_ARM_COUNT,
            "world_build_count": worker.EXPECTED_PAIRED_ARM_COUNT,
            "outer_step_count": worker.EXPECTED_TOTAL_OUTER_STEPS,
            "native_solver_step_count": worker.EXPECTED_TOTAL_NATIVE_SOLVER_STEPS,
            "prone_to_standing_claimed": False,
        }
        passing = worker.compact_projection_v1(full)
        self.assertTrue(passing["route_coverage_passed"])
        self.assertEqual(passing["candidate_active_command_outer_step_count"], 2)

        full["route_id"] = worker19.EXPECTED_ROUTE_ID
        # Exercise the consumed worker against its own frozen route identity;
        # the live module now correctly exports the distinct R24D20 successor.
        with patch.object(worker19, "ROUTE_ID", worker19.EXPECTED_ROUTE_ID):
            successor = worker19.compact_projection_v2(full)
        self.assertTrue(successor["route_coverage_passed"])
        self.assertEqual(successor["gate_id"], "QSDK-R24D19")
        self.assertTrue(successor["public_profile_validator_successor"])

        full["route_id"] = route.ROUTE_ID
        timestep_successor = worker20.compact_projection_v3(full)
        self.assertTrue(timestep_successor["route_coverage_passed"])
        self.assertEqual(timestep_successor["gate_id"], "QSDK-R24D20")
        self.assertTrue(
            timestep_successor["production_timestep_identity_successor"]
        )

        full["candidate"] = arm(0)
        missing_command = worker.compact_projection_v1(full)
        self.assertFalse(missing_command["route_coverage_passed"])
        self.assertFalse(
            missing_command["checks"]["candidate_active_command_covered"]
        )

    def test_public_profile_validator_accepts_exact_caps_and_rejects_mutation(self) -> None:
        model, binding, actuator_ids = public_profile_fixture(
            route.OUTER_DT_S / route.NATIVE_SUBSTEPS_PER_OUTER_STEP
        )

        accepted = route.validate_public_profile_model_identity_v2(
            model,
            binding,
            actuator_ids,
        )
        self.assertTrue(accepted["ok"])
        self.assertEqual(
            accepted["validated_actuator_count"],
            len(route.ORDERED_ACTUATOR_IDS),
        )
        self.assertFalse(accepted["base_morphology_force_caps_consulted"])

        mutated, _, _ = public_profile_fixture(
            route.OUTER_DT_S / route.NATIVE_SUBSTEPS_PER_OUTER_STEP
        )
        mutated.actuator_forcerange = mutated.actuator_forcerange.copy()
        mutated.actuator_forcerange[1] = [-1.0, 1.0]
        with self.assertRaisesRegex(
            route.NativeRecoveryRouteError,
            "QSDK_R24D19_PUBLIC_ACTUATOR_CONFIGURATION:1",
        ):
            route.validate_public_profile_model_identity_v2(
                mutated,
                binding,
                actuator_ids,
            )

    def test_r24d20_validator_binds_production_xml_and_rejects_adjacent_ulp(self) -> None:
        production_timestep = route.base.INTERNAL_DT_S
        model, binding, actuator_ids = public_profile_fixture(production_timestep)
        with patch.object(route.mujoco.MjModel, "from_xml_string") as constructor:
            compiled_route = route.compile_public_profile_model_route(self.core)
        constructor.assert_not_called()
        xml_root = ET.fromstring(compiled_route.model_xml)
        option = xml_root.find("option")
        self.assertIsNotNone(option)
        assert option is not None
        self.assertEqual(option.attrib["timestep"], f"{production_timestep:.17g}")
        self.assertEqual(float(option.attrib["timestep"]), production_timestep)

        accepted = route.validate_public_profile_model_identity_v3(
            model,
            binding,
            actuator_ids,
        )
        self.assertTrue(accepted["ok"])
        self.assertEqual(
            accepted["timestep_authority"],
            "selected_policy_development.INTERNAL_DT_S",
        )
        self.assertEqual(accepted["production_timestep_s"], production_timestep)

        adjacent_lower = math.nextafter(production_timestep, 0.0)
        self.assertNotEqual(adjacent_lower, production_timestep)
        mutated, _, _ = public_profile_fixture(adjacent_lower)
        with self.assertRaisesRegex(
            route.NativeRecoveryRouteError,
            "QSDK_R24D20_MODEL_TIMESTEP_MISMATCH",
        ):
            route.validate_public_profile_model_identity_v3(
                mutated,
                binding,
                actuator_ids,
            )

    def test_r24d19_worker_binds_the_same_selector_as_a_distinct_successor(self) -> None:
        contract = worker19.load_contract_v1(CONTRACT19_PATH)

        self.assertEqual(contract["gate_id"], "QSDK-R24D19")
        self.assertEqual(
            contract["lineage"]["predecessor_gate_id"],
            "QSDK-R24D18",
        )
        self.assertFalse(contract["controlled_change"]["thresholds_changed"])
        self.assertFalse(contract["controlled_change"]["selector_changed"])
        self.assertFalse(contract["controlled_change"]["evaluator_changed"])
        self.assertEqual(
            contract["selected_development_cell"]["seed"],
            worker.EXPECTED_SEED,
        )
        self.assertEqual(
            contract["ghost_horizon"]["outer_steps_per_arm"],
            worker.EXPECTED_HORIZON_STEPS,
        )

    def test_r24d20_worker_binds_the_same_selector_as_a_distinct_successor(self) -> None:
        contract = worker20.load_contract_v1(CONTRACT20_PATH)

        self.assertEqual(contract["gate_id"], "QSDK-R24D20")
        self.assertEqual(
            contract["lineage"]["predecessor_gate_id"],
            "QSDK-R24D19",
        )
        self.assertFalse(contract["controlled_change"]["comparison_relaxed"])
        self.assertFalse(contract["controlled_change"]["thresholds_changed"])
        self.assertFalse(contract["controlled_change"]["selector_changed"])
        self.assertFalse(contract["controlled_change"]["evaluator_changed"])
        self.assertEqual(
            contract["selected_development_cell"]["seed"],
            worker.EXPECTED_SEED,
        )
        self.assertEqual(
            contract["ghost_horizon"]["outer_steps_per_arm"],
            worker.EXPECTED_HORIZON_STEPS,
        )

    def test_r24d23_maps_all_recovery_joints_without_constructing_model(self) -> None:
        class ForbiddenMjModel:
            @staticmethod
            def from_xml_string(*_args: object, **_kwargs: object) -> object:
                raise AssertionError("zero-world route constructed MjModel")

        with patch.object(recovery_route.mujoco, "MjModel", ForbiddenMjModel):
            receipt = recovery_route.run_zero_world_preflight(self.core)

        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["negative_controls_passed"], 4)
        self.assertEqual(
            receipt["morphology_mapping"]["ordered_joint_mapping_count"],
            8,
        )
        self.assertEqual(receipt["model_construction_count"], 0)
        self.assertEqual(receipt["world_build_count"], 0)
        self.assertEqual(receipt["solver_step_count"], 0)

    def test_r24d24_qualifies_v2_context_and_contact_observer_zero_world(self) -> None:
        class ForbiddenMjModel:
            @staticmethod
            def from_xml_string(*_args: object, **_kwargs: object) -> object:
                raise AssertionError("R24D24 zero-world gate constructed MjModel")

        with patch.object(recovery_route.mujoco, "MjModel", ForbiddenMjModel):
            receipt = recovery_context_qualification.run_zero_world_preflight(
                self.core
            )

        self.assertTrue(receipt["ok"])
        self.assertTrue(receipt["v1_request_shape_unchanged"])
        self.assertTrue(receipt["v1_unknown_context_field_rejected"])
        self.assertFalse(receipt["v1_recovery_pose_joint_limits_respected"])
        self.assertTrue(receipt["v2_recovery_pose_joint_limits_respected"])
        self.assertEqual(receipt["v2_public_entrypoint_count"], 5)
        self.assertEqual(
            receipt["contact_observer"]["controls_passed"],
            receipt["contact_observer"]["control_count"],
        )
        for field in (
            "model_construction_count",
            "data_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "held_out_cell_access_count",
            "held_out_selector_invocation_count",
        ):
            self.assertEqual(receipt[field], 0)
        self.assertFalse(receipt["physical_question_opened"])
        self.assertFalse(receipt["prone_to_standing_claimed"])
        self.assertFalse(receipt["release_authority"])

    def test_r24d24_worker_freezes_the_two_step_development_decision(self) -> None:
        contract = worker24.load_contract_v1(CONTRACT24_PATH)

        self.assertEqual(contract["gate_id"], "QSDK-R24D24")
        self.assertEqual(contract["lineage"]["predecessor_gate_id"], "QSDK-R24D23")
        self.assertEqual(
            contract["selected_development_cell"]["seed"],
            worker24.EXPECTED_SEED,
        )
        self.assertEqual(contract["ghost_horizon"]["outer_steps_per_arm"], 2)
        self.assertFalse(contract["ghost_horizon"]["full_horizon_ghost_required"])
        self.assertFalse(contract["controlled_change"]["controller_changed"])
        self.assertFalse(contract["controlled_change"]["behavior_thresholds_changed"])
        self.assertFalse(contract["controlled_change"]["held_out_selector_changed"])

    def test_r24d24_projection_separates_execution_from_physical_result(self) -> None:
        context = {
            "recovery_morphology_spec_sha256": (
                recovery_route.EXPECTED_RECOVERY_MORPHOLOGY_SHA256
            )
        }
        request_trace = {
            "initialize_request_schema": "sporespore_recovery_initialize_request_v2",
            "collection_request_schemas": [
                "sporespore_recovery_native_collection_request_v2"
            ]
            * 2,
            "step_request_schemas": ["sporespore_recovery_step_request_v2"] * 2,
            "control_request_schemas": [
                "sporespore_recovery_control_request_v2"
            ]
            * 2,
        }
        arm = {
            "portable_recovery_context_bound": True,
            "portable_recovery_morphology_context": context,
            "portable_request_trace": request_trace,
            "observations": [
                {
                    "ordered_body_clearance_observations": [
                        {
                            "body_id": "torso",
                            "classification_rule_id": (
                                worker24.EXPECTED_OBSERVER_RULE_ID
                            ),
                        }
                    ]
                }
                for _ in range(2)
            ],
            "portable_step_receipts": [
                {
                    "classification": {
                        "joint_limits_respected": True,
                        "torso_ventral_contact": True,
                        "pose_class": "ventral_prone",
                    },
                    "memory": {"prone_confirm_steps_observed": count},
                }
                for count in (1, 2)
            ],
        }

        positive = worker24._arm_decision_projection(arm)
        self.assertTrue(all(positive["execution_checks"].values()))
        self.assertTrue(all(positive["target_checks"].values()))

        arm["portable_step_receipts"][1]["classification"][
            "torso_ventral_contact"
        ] = False
        negative = worker24._arm_decision_projection(arm)
        self.assertTrue(all(negative["execution_checks"].values()))
        self.assertFalse(all(negative["target_checks"].values()))

    def test_r24d23_prone_initializer_is_sourced_from_public_receipt(self) -> None:
        model_route = recovery_route.compile_recovery_morphology_model_route(
            self.core
        )
        mappings = model_route.morphology_mapping_receipt[
            "ordered_joint_mappings"
        ]
        self.assertEqual(
            [item["canonical_prone_position_rad"] for item in mappings],
            [1.55, 1.10, 1.55, 1.10, -1.55, -1.10, -1.55, -1.10],
        )
        self.assertEqual(
            model_route.compiled["recovery_morphology_spec_sha256"],
            recovery_route.EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        )

    def test_r24d23_worker_binds_the_two_step_development_route(self) -> None:
        contract = worker23.load_contract_v1(CONTRACT23_PATH)

        self.assertEqual(contract["gate_id"], "QSDK-R24D23")
        self.assertEqual(contract["lineage"]["predecessor_gate_id"], "QSDK-R24D22")
        self.assertEqual(
            contract["selected_development_cell"]["seed"],
            worker23.EXPECTED_SEED,
        )
        self.assertEqual(
            contract["ghost_horizon"]["outer_steps_per_arm"],
            2,
        )
        self.assertFalse(contract["ghost_horizon"]["full_horizon_ghost_required"])
        self.assertFalse(contract["controlled_change"]["controller_changed"])

    def test_recovery_context_uses_v2_while_legacy_initialization_stays_exact(self) -> None:
        capability = route.mujoco_recovery_capability_v1()
        legacy = route._physical_initialization_request(
            "candidate_command",
            capability,
        )
        self.assertEqual(
            legacy["schema_version"],
            "sporespore_recovery_initialize_request_v1",
        )
        self.assertNotIn("morphology_context", legacy)

        model_route = recovery_route.compile_recovery_morphology_model_route(self.core)
        context = route._portable_morphology_context(model_route)
        self.assertIsNotNone(context)
        assert context is not None
        request_v2 = route._physical_initialization_request_v2(
            "candidate_command",
            capability,
            context,
        )
        self.assertEqual(
            request_v2["schema_version"],
            "sporespore_recovery_initialize_request_v2",
        )
        self.assertEqual(
            request_v2["morphology_context"]["recovery_descriptor_sha256"],
            model_route.compiled["descriptor_sha256"],
        )
        self.assertEqual(
            request_v2["morphology_context"]["recovery_morphology_spec_sha256"],
            recovery_route.EXPECTED_RECOVERY_MORPHOLOGY_SHA256,
        )
        request_v2.pop("schema_version")
        request_v2.pop("morphology_context")
        legacy_without_schema = dict(legacy)
        legacy_without_schema.pop("schema_version")
        self.assertEqual(request_v2, legacy_without_schema)

    def test_contact_observer_reconstructs_the_named_geom_surface(self) -> None:
        world = object.__new__(route.MujocoNativeRecoveryWorld)
        world.compiled = {"geometry": {"torso_size_m": {"y": 0.12}}}
        world._body_local_canonical = lambda _body, point: np.asarray(
            point,
            dtype=np.float64,
        )
        contact = SimpleNamespace(
            pos=np.asarray([0.0, -0.055, 0.0], dtype=np.float64),
            frame=np.asarray(
                [[0.0, 1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, 1.0]],
                dtype=np.float64,
            ),
            dist=-0.010,
            geom1=10,
            geom2=20,
        )

        legacy_midpoint = np.asarray(contact.pos, dtype=np.float64)
        self.assertFalse(
            world._is_torso_ventral_contact(legacy_midpoint)
        )
        torso_surface = world._contact_surface_point_for_body_geom(contact, 20)
        np.testing.assert_array_equal(
            torso_surface,
            np.asarray([0.0, -0.060, 0.0], dtype=np.float64),
        )
        self.assertTrue(world._is_torso_ventral_contact(torso_surface))

        reverse = SimpleNamespace(
            pos=np.asarray([0.0, -0.055, 0.0], dtype=np.float64),
            frame=np.asarray(
                [[0.0, -1.0, 0.0], [1.0, 0.0, 0.0], [0.0, 0.0, -1.0]],
                dtype=np.float64,
            ),
            dist=-0.010,
            geom1=20,
            geom2=10,
        )
        np.testing.assert_array_equal(
            world._contact_surface_point_for_body_geom(reverse, 20),
            torso_surface,
        )

        with self.assertRaisesRegex(
            route.NativeRecoveryRouteError,
            "QSDK_R24_NATIVE_CONTACT_GEOMETRY_NONFINITE",
        ):
            invalid = SimpleNamespace(**vars(contact))
            invalid.dist = math.nan
            world._contact_surface_point_for_body_geom(invalid, 20)
        with self.assertRaisesRegex(
            route.NativeRecoveryRouteError,
            "QSDK_R24_NATIVE_CONTACT_GEOM_IDENTITY",
        ):
            world._contact_surface_point_for_body_geom(contact, 30)

        self.assertEqual(
            route.MujocoNativeRecoveryWorld.nonfoot_classification_rule_id,
            route.NONFOOT_CLASSIFICATION_RULE_ID,
        )
        self.assertEqual(
            recovery_route.MujocoRecoveryMorphologyWorld.nonfoot_classification_rule_id,
            "mujoco_contact_midpoint_normal_distance_reconstructed_torso_surface_v1",
        )


if __name__ == "__main__":
    unittest.main()
