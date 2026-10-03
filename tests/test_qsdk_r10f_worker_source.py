from __future__ import annotations

import hashlib
import copy
import json
from pathlib import Path
import re
import subprocess
import unittest


ROOT = Path(__file__).resolve().parents[1]
WORKER_PATH = ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
ZERO_WORLD_PATH = (
    ROOT / "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_zero_world.gd"
)
ORCHESTRATOR_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/"
    "qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd"
)
PRECONDITION_PAIR_BARRIER_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_precondition_pair_barrier_v1.gd"
)
PRECONDITION_TERMINAL_DISPOSITION_PATH = (
    ROOT
    / "sdk/adapters/godot/gdscript/qsdk_r10f_precondition_terminal_disposition_v1.gd"
)
FACADE_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/"
    "qsdk_r10f_recovery_native_locomotion_facade_v1.gd"
)
EVALUATOR_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_walking_segment_evaluator_v1.gd"
)
EPOCH_TRANSPORT_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_boundary_transport_v1.gd"
)
EPOCH_STAGING_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_discrete_staging_route_v1.gd"
)
ENERGY_INITIALIZER_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_energy_initializer_v1.gd"
)
NATIVE_EPOCH_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/recovery_epoch_native_measurement_route_v1.gd"
)
NATIVE_WORLD_PATH = ROOT / "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd"
SHARED_ADAPTER_PATH = ROOT / "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
IMPULSE_PAIR_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/qsdk_r10f_native_impulse_pair_receipt_v1.gd"
)
PROCESS_ISOLATED_CHILD_CONTRACT_PATH = (
    ROOT / "sdk/adapters/godot/gdscript/"
    "qsdk_r10f_process_isolated_child_contract_v1.gd"
)
PROCESS_ISOLATED_PAIR_EVALUATOR_PATH = (
    ROOT / "sdk/qsdk_r10f_process_isolated_pair_evaluator.ps1"
)
L9_REPAIR_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_l9_process_isolated_matched_arm_successor_design_v1.json"
)
L9_REPAIR_DESIGN_SHA256 = (
    "0fc68c2f895afa52a3835d55c0508bc5490b1af98c5da3761eb774aed702f41e"
)
L10_REPAIR_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1.json"
)
L10_REPAIR_DESIGN_SHA256 = (
    "2d186f41fcb73427ef7021a1050e4175791784212bfb9c219d712595370a4817"
)
L11_REPAIR_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10f_l11_precondition_release_owner_source_successor_design_v1.json"
)
L11_REPAIR_DESIGN_SHA256 = (
    "31027c3ea6fed3085a8486bd3d5e4cab318cd23cdc939d49375c81f8b78fa812"
)
L12_REPAIR_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1.json"
)
L12_REPAIR_DESIGN_SHA256 = (
    "d10684da1566d9a0e4684ff1b13c3ddbc583d44b23088fc2485731c89a0a6de8"
)
L13_REPAIR_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json"
)
L13_REPAIR_DESIGN_SHA256 = (
    "ce85d54e7a8cc12304015f5551d4f7874ad783613cd7feb566fc63cb10b20ce9"
)
RECOVERY_CORE_PATH = ROOT / "sdk/core/src/recovery.rs"
GODOT_NATIVE_ADAPTER_PATH = ROOT / "sdk/adapters/godot/src/lib.rs"
L10_PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v10.json"
)
L10_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = (
    "7a5b61ec898b9c5b2891911101d34c3cefe7a6c5657a7c6abdea45e6b4299464"
)
L11_PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v11.json"
)
L11_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = (
    "56cce9da3c85a8b8187f0e1f9f8986fe004d587db262ef0ec11687ff37c7462e"
)
L12_PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v12.json"
)
L12_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = (
    "6eaa7be76c56c8167ecf72c070a233a54aad31c13aa2df6b3c7d71de7447ef30"
)
L13_PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v13.json"
)
L13_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = (
    "b3ca434ee589d283077d1d4e20d3681a3368e07af1824c5926151c20d1f30e21"
)
L11_MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v12.json"
MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v19.json"
SUPERVISOR_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json"
)
SUPERVISOR_REFUSAL_SHA256 = (
    "93e60e8fe747a8ba7a5b6a1621175ce4bf877f537a2a5d03d01ff9e186e1140f"
)
PREDECESSOR_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v1.json"
)
PREDECESSOR_REFUSAL_SHA256 = (
    "27528d78b217278700f5d1860046a2e5f7fc1e2324cef1a0239ffbd7859391e0"
)
PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v9.json"
)
PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = (
    "29ef1f7c2db408a2fd09f378e057648825eac2c1e856932dd2ed259829bdadde"
)
SUPERVISOR_PATH = ROOT / "sdk/run_qsdk_r10f_continuous_passive_recovery.ps1"
QUALIFICATION_PATH = ROOT / "sdk/qsdk_r10f_zero_world_qualification.ps1"
IMPLEMENTATION_AUDIT_PATH = (
    ROOT / "sdk/conformance/qsdk_r10f_zero_world_implementation.py"
)
MATERIALIZER_PATH = ROOT / "sdk/conformance/qsdk_r10f_authority_materializer.py"
PHYSICAL_CLOSURE_PATH = ROOT / "sdk/conformance/qsdk_r10f_physical_closure.py"


def function(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^(?:static )?func {re.escape(name)}\(.*?(?=^(?:static )?func |\Z)",
        source,
    )
    if match is None:
        raise AssertionError(f"missing function: {name}")
    return match.group(0)


def powershell_function(source: str, name: str) -> str:
    match = re.search(
        rf"(?ms)^function {re.escape(name)} \{{.*?(?=^function |\Z)", source
    )
    if match is None:
        raise AssertionError(f"missing PowerShell function: {name}")
    return match.group(0)


def python_function(source: str, name: str) -> str:
    match = re.search(rf"(?ms)^def {re.escape(name)}\(.*?(?=^def |\Z)", source)
    if match is None:
        raise AssertionError(f"missing Python function: {name}")
    return match.group(0)


class R10fWorkerSourceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.worker = WORKER_PATH.read_text(encoding="utf-8")
        cls.zero_world = ZERO_WORLD_PATH.read_text(encoding="utf-8")
        cls.orchestrator = ORCHESTRATOR_PATH.read_text(encoding="utf-8")
        cls.precondition_pair_barrier = PRECONDITION_PAIR_BARRIER_PATH.read_text(
            encoding="utf-8"
        )
        cls.precondition_terminal_disposition = (
            PRECONDITION_TERMINAL_DISPOSITION_PATH.read_text(encoding="utf-8")
        )
        cls.facade = FACADE_PATH.read_text(encoding="utf-8")
        cls.evaluator = EVALUATOR_PATH.read_text(encoding="utf-8")
        cls.epoch_transport = EPOCH_TRANSPORT_PATH.read_text(encoding="utf-8")
        cls.epoch_staging = EPOCH_STAGING_PATH.read_text(encoding="utf-8")
        cls.energy_initializer = ENERGY_INITIALIZER_PATH.read_text(encoding="utf-8")
        cls.native_epoch = NATIVE_EPOCH_PATH.read_text(encoding="utf-8")
        cls.native_world = NATIVE_WORLD_PATH.read_text(encoding="utf-8")
        cls.shared_adapter = SHARED_ADAPTER_PATH.read_text(encoding="utf-8")
        cls.impulse_pair = IMPULSE_PAIR_PATH.read_text(encoding="utf-8")
        cls.process_isolated_child_contract = (
            PROCESS_ISOLATED_CHILD_CONTRACT_PATH.read_text(encoding="utf-8")
        )
        cls.process_isolated_pair_evaluator = (
            PROCESS_ISOLATED_PAIR_EVALUATOR_PATH.read_text(encoding="utf-8")
        )
        cls.l9_repair_design = json.loads(
            L9_REPAIR_DESIGN_PATH.read_text(encoding="utf-8")
        )
        cls.l10_repair_design = json.loads(
            L10_REPAIR_DESIGN_PATH.read_text(encoding="utf-8")
        )
        cls.l11_repair_design = json.loads(
            L11_REPAIR_DESIGN_PATH.read_text(encoding="utf-8")
        )
        cls.l12_repair_design = json.loads(
            L12_REPAIR_DESIGN_PATH.read_text(encoding="utf-8")
        )
        cls.l13_repair_design = json.loads(
            L13_REPAIR_DESIGN_PATH.read_text(encoding="utf-8")
        )
        cls.recovery_core = RECOVERY_CORE_PATH.read_text(encoding="utf-8")
        cls.godot_native_adapter = GODOT_NATIVE_ADAPTER_PATH.read_text(encoding="utf-8")
        cls.supervisor = SUPERVISOR_PATH.read_text(encoding="utf-8")
        cls.qualification = QUALIFICATION_PATH.read_text(encoding="utf-8")
        cls.implementation_audit = IMPLEMENTATION_AUDIT_PATH.read_text(encoding="utf-8")
        cls.materializer = MATERIALIZER_PATH.read_text(encoding="utf-8")
        cls.physical_closure = PHYSICAL_CLOSURE_PATH.read_text(encoding="utf-8")

    def test_l9_worker_builds_one_authorized_world_while_physics_is_inactive(
        self,
    ) -> None:
        run = function(self.worker, "_run")
        self.assertLess(
            run.index("PhysicsServer3D.set_active(false)"), run.index("_build_arm_v1")
        )
        self.assertEqual(run.count("_build_arm_v1("), 1)
        self.assertIn("await _build_arm_v1(_authorized_arm_id)", run)
        self.assertIn("_arms.size() != 1 or not _arms.has(_authorized_arm_id)", run)
        self.assertNotIn("for arm_id_value in ARM_ORDER", run)
        self.assertNotIn("PhysicsServer3D.set_active(true)", run)
        frame = function(self.worker, "_on_physics_frame")
        self.assertEqual(frame.count("PhysicsServer3D.set_active(true)"), 1)
        self.assertEqual(frame.count("_process_completed_arm_step_v1("), 1)
        self.assertIn(
            "_process_completed_arm_step_v1(_authorized_arm_id, active_step, false)",
            frame,
        )
        self.assertIn("_finalize_process_isolated_child_result_v1()", frame)
        self.assertIn("_plan_next_process_isolated_frame_v1(active_step)", frame)
        self.assertNotIn("_plan_next_lockstep_frame_v1", frame)
        self.assertLess(
            frame.index("PhysicsServer3D.set_active(true)"),
            frame.index("_observed_global_solver_frames += 1"),
        )

    def test_kick_is_one_frozen_external_intervention(self) -> None:
        schedule = function(self.worker, "_schedule_process_isolated_interaction_v1")
        self.assertEqual(schedule.count(".apply_central_impulse("), 1)
        self.assertIn("EnergyInitializer.KICK_IMPULSE_MAGNITUDE_N_S", schedule)
        self.assertIn(
            "if _authorized_arm_id == EnergyInitializer.ACTIVE_ARM_ID", schedule
        )
        self.assertIn('arm["external_kick_application_count"] = 1', schedule)
        self.assertEqual(schedule.count('["external_kick_application_count"] = 1'), 1)
        self.assertIn(
            '"external_kick_application_count": 0',
            function(self.worker, "_build_arm_v1"),
        )
        self.assertLess(
            schedule.index("configure_all_motors_v1("),
            schedule.index(".apply_central_impulse("),
        )

    def test_worker_never_rewrites_body_state_or_rebuilds_population(self) -> None:
        forbidden = (
            ".global_transform =",
            ".transform =",
            ".linear_velocity =",
            ".angular_velocity =",
            "body_set_state(",
            "body_set_transform(",
            "free_rid(",
        )
        for token in forbidden:
            self.assertNotIn(token, self.worker)
        self.assertIn('"body_population_rebuild_count": 0', self.worker)
        self.assertIn('"body_transform_write_count": 0', self.worker)
        self.assertIn('"body_velocity_write_count": 0', self.worker)
        self.assertIn('"solver_reset_count": 0', self.worker)

    def test_l9_child_terminal_finalizes_before_any_next_frame_plan(self) -> None:
        frame = function(self.worker, "_on_physics_frame")
        processed = frame.index("_process_completed_arm_step_v1(")
        terminal = frame.index('if bool(arm["terminal"]):')
        finalize = frame.index("_finalize_process_isolated_child_result_v1()")
        plan = frame.index("_plan_next_process_isolated_frame_v1(active_step)")
        self.assertLess(processed, terminal)
        self.assertLess(terminal, finalize)
        self.assertLess(finalize, plan)

        process_step = function(self.worker, "_process_completed_arm_step_v1")
        self.assertIn(
            'arm["terminal"] = next_phase in '
            "[Orchestrator.PHASE_COMPLETE, Orchestrator.PHASE_FAILED]",
            process_step,
        )
        precondition_advance = function(self.orchestrator, "_advance_precondition_v1")
        self.assertIn(
            'elif terminal_phase in ["failed", "refused"]:', precondition_advance
        )
        self.assertIn('state["phase"] = PHASE_FAILED', precondition_advance)
        planner = function(self.worker, "_plan_next_process_isolated_frame_v1")
        self.assertIn("QSDK_R10F_L9_CHILD_PRECONDITION_NEGATIVE_NOT_TERMINAL", planner)

    def test_valid_behavioral_failure_is_not_infrastructure_abort(self) -> None:
        finalize = function(self.worker, "_finalize_process_isolated_child_result_v1")
        projection = function(self.worker, "_process_isolated_arm_result_projection_v1")
        self.assertIn('role_outcome = "behavior_negative"', finalize)
        self.assertIn('"scientific_outcome": "none"', finalize)
        self.assertIn('"measurement_complete": true', finalize)
        self.assertIn('"ok": true', projection)
        self.assertIn(
            '"status": "valid_complete_process_isolated_child_development"', finalize
        )
        self.assertIn(
            '_schedule_exit_v1(0, "valid_complete_process_isolated_child_development")',
            finalize,
        )
        self.assertIn(
            "var release_receipt_valid := complete_precondition and "
            "release_boundary_valid",
            projection,
        )
        self.assertIn(
            '"precondition_release_receipt_valid": release_receipt_valid',
            projection,
        )
        evaluator = powershell_function(
            self.process_isolated_pair_evaluator, "Invoke-QsdkR10fL9PairEvaluator"
        )
        self.assertIn(
            'scientific_outcome = if ($behaviorPassed) { "positive" } else { "negative" }',
            evaluator,
        )
        self.assertIn('"valid_complete_behavior_negative_development"', evaluator)
        abort = function(self.worker, "_abort")
        self.assertIn('"status": "invalid_or_incomplete_behavior_development"', abort)
        self.assertIn(
            '_schedule_exit_v1(1, "invalid_or_incomplete_behavior_development")', abort
        )

    def test_campaign_binding_is_exact_and_fails_before_world_creation(self) -> None:
        run = function(self.worker, "_run")
        self.assertLess(
            run.index("_load_campaign_binding_v1()"), run.index("_build_arm_v1")
        )
        binding = function(self.worker, "_load_campaign_binding_v1")
        seed_binding = binding
        if "_authorized_seed_binding_v1(" in binding:
            # The campaign successor extracts the historical default predicate
            # so the candidate can add its authority-bound population guard.
            # Keep the original default seed/label/digest checks load-bearing.
            self.assertIn(
                "or not _authorized_seed_binding_v1(configured_seed, configured_seed_label, configured_seed_sha)",
                binding,
            )
            seed_binding = function(self.worker, "_authorized_seed_binding_v1")
            for predicate in (
                "seed_text.is_valid_int()", "seed_text.to_int() == DEVELOPMENT_SEED",
                "label == DEVELOPMENT_SEED_LABEL", "digest == DEVELOPMENT_SEED_SHA256",
            ):
                self.assertIn(predicate, seed_binding)
        for token in (
            "GATE_ID",
            "GATE_TOKEN",
            "RAW_SCHEMA",
            "WORK_ID",
            "DEVELOPMENT_SEED",
            "DEVELOPMENT_SEED_LABEL",
            "DEVELOPMENT_SEED_SHA256",
            "ACTUATOR_MODE",
            "RECOVERY_CONTROLLER_ID",
            "ENERGY_ROUTE_ID",
        ):
            self.assertIn(token, seed_binding if token.startswith("DEVELOPMENT_SEED") else binding)
        self.assertIn('supervised != "1"', binding)
        self.assertIn("_is_lower_hex_v1(source_commit, 40)", binding)
        self.assertIn("_is_lower_hex_v1(attempt_id, 32)", binding)
        build = function(self.worker, "_build_arm_v1")
        self.assertIn("initial_bootstrap_application_validation_v1(", build)
        self.assertNotIn("behavior_application_receipt_valid_v4", build)
        self.assertIn(
            '"initial_application": initial_application.duplicate(true)', build
        )
        self.assertIn(
            '"initial_application_validation": initial_application_validation.duplicate(true)',
            build,
        )
        bootstrap_consumer = function(
            self.worker, "initial_bootstrap_application_validation_v1"
        )
        for token in (
            "sporespore_qsdk_r24d57_godot_application_intent_v1",
            "RouteScript.R144_COMPLETE_ENERGY_ROUTE_ID",
            "RouteScript.R152_ROUTE_AWARE_APPLICATION_PROVENANCE_PROFILE_ID",
            '"active_application_validator_applicable": false',
        ):
            self.assertIn(token, bootstrap_consumer)

    def test_orchestrator_is_passive_event_triggered_and_bounded(self) -> None:
        for constant in (
            "MAXIMUM_PRECONDITION_RECOVERY_STEPS := 1200",
            "WALKING_PREFIX_STEPS := 720",
            "MAXIMUM_CONFIRM_PRONE_STEPS := 60",
            "REQUIRED_CONSECUTIVE_PRONE_SAMPLES := 12",
            "MAXIMUM_POST_KICK_RECOVERY_EPOCH_STEPS := 1200",
            "WALKING_RESUME_STEPS := 720",
            "MAXIMUM_PRECONDITION_PAIR_WAIT_STEPS := 1199",
            "PRECONDITION_PAIR_RELEASE_STEPS := 1",
            "MAXIMUM_ACTIVE_ARM_SOLVER_STEPS := 3842",
        ):
            self.assertIn(constant, self.orchestrator)
        self.assertIn('"event_triggered_passive_recovery": true', self.orchestrator)
        self.assertIn('"force_aware_recovery": false', self.orchestrator)
        event_valid = function(self.orchestrator, "event_valid_v1")
        self.assertIn(
            'terminal_phase not in ["", "complete", "failed", "refused"]', event_valid
        )
        self.assertIn("terminal_reason.is_empty()", event_valid)

    def test_l6_pair_barrier_is_pure_source_bound_and_bounded(self) -> None:
        barrier = self.precondition_pair_barrier
        for token in (
            'const REPAIR_ID := "QSDK-R10F-L6"',
            "MAXIMUM_PRECONDITION_GLOBAL_FRAMES_BEFORE_RELEASE := 1200",
            "MAXIMUM_RELEASE_GLOBAL_STEP := 1201",
            'const ACTION_RECOVERY := "continue_recovery"',
            'const ACTION_WAIT := "no_actuation_wait"',
            'const ACTION_RELEASE := "no_actuation_release"',
            '"source_measurement": true',
            '"outcome_derived_readiness": false',
            '"world_pause_or_step_skip_permitted": false',
            '"motors_enabled_for_wait_or_release_permitted": false',
        ):
            self.assertIn(token, barrier)
        for function_name in (
            "build_terminal_source_v1",
            "observe_terminal_v1",
            "plan_next_frame_v1",
            "complete_planned_action_v1",
            "terminal_source_valid_v1",
            "state_valid_v1",
            "zero_world_contract_v1",
        ):
            self.assertIn(f"func {function_name}(", barrier)
        for forbidden in (
            "Node.new",
            "RigidBody3D.new",
            "World3D.new",
            "PhysicsServer3D",
            "physics_frame",
            "apply_central_impulse",
        ):
            self.assertNotIn(forbidden, barrier)
        controls = function(barrier, "zero_world_contract_v1")
        self.assertEqual(controls.count("_run_zero_world_scenario_v1("), 4)
        self.assertIn('"positive_sequence_control_count": positive_count', controls)
        self.assertIn(
            '"mutation_rejection_count": int(controls.get("rejection_count", -1))',
            controls,
        )
        self.assertIn('"model_construction_count": 0', controls)
        self.assertIn('"world_attempt_count": 0', controls)
        self.assertIn('"native_readback_count": 0', controls)
        self.assertIn('"solver_step_count": 0', controls)

    def test_l6_worker_applies_retains_and_revalidates_pair_barrier(self) -> None:
        plan = function(self.worker, "_plan_next_lockstep_frame_v1")
        apply_barrier = function(
            self.worker, "_apply_precondition_pair_barrier_application_v1"
        )
        retain = function(self.worker, "_retain_compact_step_v1")
        retained_validator = function(
            self.worker,
            "precondition_pair_barrier_application_retained_valid_v1",
        )
        arm_result = function(self.worker, "_arm_result_projection_v1")
        finalize = function(self.worker, "_finalize_valid_result_v1")
        evaluate = function(self.worker, "_evaluate_route_result_v1")
        abort = function(self.worker, "_abort")

        self.assertIn("PreconditionPairBarrier", plan)
        self.assertIn(". plan_next_frame_v1(", plan)
        self.assertIn("_apply_precondition_pair_barrier_application_v1", plan)
        self.assertIn(". configure_all_motors_v1(", apply_barrier)
        self.assertIn("\n\t\t\tfalse,", apply_barrier)
        self.assertIn("motor_population_readback_v1", apply_barrier)
        self.assertIn("no_actuation_ledger_application_intent_v1", apply_barrier)
        self.assertIn(
            'arm["precondition_pair_barrier_application_projections"]',
            apply_barrier,
        )
        self.assertIn('"precondition_pair_application_live_valid"', retain)
        self.assertIn('"precondition_pair_application_matches_pending_intent"', retain)
        for token in (
            "PreconditionPairBarrier.PLAN_KEYS",
            'pair_plan.get("payload_sha256"',
            'ledger.get("owner_source_receipt") != pair_plan',
            "motor_enabled_count",
            "zero_target_velocity_count",
            "ordered_motor_readbacks",
            "_payload_sha256_static_v1(sdk, application)",
        ):
            self.assertIn(token, retained_validator)
        for token in (
            ". terminal_source_valid_v1(",
            "precondition_pair_barrier_application_retained_valid_v1",
            "pair_release_application_count == 1",
            '"precondition_pair_barrier_retention_valid"',
            '"precondition_terminal_source"',
            '"precondition_pair_barrier_application_projections"',
        ):
            self.assertIn(token, arm_result)
        self.assertIn("_precondition_pair_final_state_valid_v1()", finalize)
        self.assertIn('"precondition_pair_barrier_state"', finalize)
        self.assertIn(
            '"precondition_pair_barrier_released_from_two_source_terminals"',
            evaluate,
        )
        self.assertIn('"precondition_pair_barrier_state"', abort)
        self.assertIn('"precondition_pair_barrier_evidence_by_arm"', abort)

    def test_l7_terminal_disposition_authority_is_pure_exact_and_control_complete(
        self,
    ) -> None:
        disposition = self.precondition_terminal_disposition
        for token in (
            'const REPAIR_ID := "QSDK-R10F-L7"',
            'const FAILURE_CODE := "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED"',
            'const DISPOSITION_COMPLETE := "complete_source_retained"',
            'const DISPOSITION_FAILED := "failed_source_retained"',
            'const DISPOSITION_REFUSED := "refused_source_retained"',
            'const DISPOSITION_NONTERMINAL := "nonterminal_last_completed_state_retained"',
            "const BUILD_INPUT_KEYS := [",
            "const DISPOSITION_KEYS := [",
            "const ABORT_POPULATION_KEYS := [",
        ):
            self.assertIn(token, disposition)
        for function_name in (
            "build_disposition_v1",
            "disposition_valid_v1",
            "build_abort_population_v1",
            "abort_population_valid_v1",
            "independent_closure_projection_valid_v1",
            "zero_world_contract_v1",
        ):
            self.assertIn(f"func {function_name}(", disposition)
        for forbidden in (
            "Node.new",
            "RigidBody3D.new",
            "World3D.new",
            "PhysicsServer3D",
            "physics_frame",
            "apply_central_impulse",
        ):
            self.assertNotIn(forbidden, disposition)

        controls = function(disposition, "zero_world_contract_v1")
        for positive_name in (
            "successful_complete_precondition_terminal_still_becomes_arm_local_barrier_source",
            "active_failed_precondition_terminal_retained_and_route_stops_without_peer_terminal",
            "baseline_failed_precondition_terminal_retained_and_route_stops_without_peer_terminal",
            "refused_precondition_terminal_retained_and_route_stops_without_peer_terminal",
            "nonterminal_peer_last_completed_state_retained_on_precondition_abort",
            "both_complete_sources_still_reach_common_no_actuation_release",
        ):
            self.assertIn(positive_name, controls)
        negative_controls = function(disposition, "_negative_controls_v1")
        for negative_name in (
            "missing_failing_arm_disposition_refused",
            "missing_nonterminal_peer_disposition_refused",
            "wrong_arm_or_model_identity_refused",
            "wrong_terminal_global_step_refused",
            "unknown_terminal_disposition_refused",
            "failed_disposition_without_failure_code_refused",
            "complete_disposition_with_failure_code_refused",
            "copied_recovery_receipt_digest_refused",
            "stale_recovery_memory_refused",
            "classification_digest_mismatch_refused",
            "pair_state_digest_mismatch_refused",
            "pair_readiness_disagrees_with_complete_source_refused",
            "outcome_derived_terminal_correction_refused",
            "generic_terminal_frame_lockstep_failure_label_refused_during_precondition",
            "post_failure_additional_solver_step_refused",
            "summary_boolean_without_independent_closure_validation_refused",
        ):
            self.assertIn(negative_name, negative_controls)
        self.assertIn("controls.size() == 16", negative_controls)
        self.assertIn('"maximum_solver_steps_per_arm": 3842', controls)
        self.assertIn('"maximum_total_solver_steps": 7684', controls)
        self.assertIn('"world_attempt_count": 0', controls)
        self.assertIn('"solver_step_count": 0', controls)

    def test_l8_integer_valued_native_step_domain_is_exact_and_source_preserving(
        self,
    ) -> None:
        disposition = self.precondition_terminal_disposition
        for token in (
            'const SUCCESSOR_REPAIR_ID := "QSDK-R10F-L8"',
            "const MINIMUM_NATIVE_STEP := 1",
            "const MAXIMUM_NATIVE_STEP := 3842",
            "integer_valued_native_step_valid_v1(",
            "integer_valued_native_step_zero_world_v1(",
        ):
            self.assertIn(token, disposition)
        validator = function(disposition, "integer_valued_native_step_valid_v1")
        for token in (
            "typeof(value) == TYPE_INT",
            "typeof(value) != TYPE_FLOAT",
            "is_finite(numeric)",
            "numeric == floor(numeric)",
            "int(numeric) == expected_step",
        ):
            self.assertIn(token, validator)
        self.assertIn("expected_step < MINIMUM_NATIVE_STEP", validator)
        self.assertIn("expected_step > MAXIMUM_NATIVE_STEP", validator)

        disposition_validator = function(disposition, "disposition_valid_v1")
        self.assertIn("integer_valued_native_step_valid_v1(", disposition_validator)
        self.assertIn(
            'typeof((step_memory_value as Dictionary).get("last_semantic_step"))',
            disposition_validator,
        )
        self.assertIn(
            '!= typeof(memory.get("last_semantic_step"))', disposition_validator
        )
        controls = function(disposition, "integer_valued_native_step_zero_world_v1")
        for positive_name in (
            "exact_integer_memory_step_still_accepted",
            "exact_integer_valued_binary64_memory_step_accepted",
            "native_shaped_first_step_binary64_disposition_builds",
            "original_binary64_source_kind_retained_without_rewrite",
            "integer_and_binary64_forms_bind_the_same_expected_step",
        ):
            self.assertIn(positive_name, controls)
        for negative_name in (
            "fractional_binary64_step_refused",
            "nan_step_refused",
            "positive_infinity_step_refused",
            "negative_infinity_step_refused",
            "zero_step_refused",
            "negative_step_refused",
            "step_above_declared_route_domain_refused",
            "integer_valued_binary64_not_equal_to_expected_step_refused",
            "boolean_step_refused",
            "string_step_refused",
            "null_step_refused",
            "missing_step_refused",
            "source_number_rewrite_refused",
            "nested_receipt_or_memory_digest_mismatch_refused",
            "outcome_derived_step_correction_refused",
        ):
            self.assertIn(negative_name, controls)
        self.assertIn("positive_controls.size() == 5", controls)
        self.assertIn("negative_controls.size() == 15", controls)
        self.assertIn(
            "var source_rewrite := binary64_receipt.duplicate(true)", controls
        )
        self.assertIn('source_rewrite["recovery_memory_sha256"]', controls)
        self.assertIn('"world_attempt_count": 0', controls)
        self.assertIn('"solver_step_count": 0', controls)

        closure_validator = python_function(
            self.physical_closure, "integer_valued_native_step_matches"
        )
        for token in (
            "bounded_int(expected_step, 1, 3842)",
            "type(value) is not type(source_value)",
            "value != source_value",
            "isinstance(value, int) and not isinstance(value, bool)",
            "isinstance(value, float)",
            "math.isfinite(value)",
            "value.is_integer()",
            "1.0 <= value <= 3842.0",
            "int(value) == expected_step",
        ):
            self.assertIn(token, closure_validator)
        closure_disposition = python_function(
            self.physical_closure, "validate_terminal_disposition"
        )
        self.assertIn("integer_valued_native_step_matches(", closure_disposition)
        self.assertIn("DISPOSITION_REPAIR_ID", closure_disposition)

        qualification_validator = python_function(
            self.materializer, "validate_qualification"
        )
        self.assertIn(
            'exact_int(implementation.get("positive_case_count"), 24)',
            qualification_validator,
        )
        self.assertIn(
            'exact_int(implementation.get("forced_failure_case_count"), 237)',
            qualification_validator,
        )

    def test_l9_child_receipt_contract_is_pure_scope_closed_and_control_complete(
        self,
    ) -> None:
        contract = self.process_isolated_child_contract
        for token in (
            'const REPAIR_ID := "QSDK-R10F-L9"',
            'const DISPOSITION_COMPLETE := "complete_source_retained"',
            'const DISPOSITION_FAILED := "failed_source_retained"',
            'const DISPOSITION_REFUSED := "refused_source_retained"',
            "static func build_precondition_terminal_receipt_v1(",
            "static func precondition_terminal_receipt_valid_v1(",
            "static func build_precondition_release_receipt_v1(",
            "static func precondition_release_receipt_valid_v1(",
            "static func build_interaction_source_v1(",
            "static func interaction_source_valid_v1(",
            "static func zero_world_contract_v1(",
        ):
            self.assertIn(token, contract)
        for forbidden in (
            "Node.new",
            "RigidBody3D.new",
            "World3D.new",
            "PhysicsServer3D",
            "physics_frame",
            "apply_central_impulse",
        ):
            self.assertNotIn(forbidden, contract)
        controls = function(contract, "zero_world_contract_v1")
        for token in (
            "positive_controls.size() == 8",
            "negative_controls.size() == 31",
            '"failed_or_refused_precondition_is_valid_diagnostic_evidence": true',
            '"failed_or_refused_precondition_crosses_release_boundary": false',
            '"world_attempt_count": 0',
            '"solver_step_count": 0',
            '"physics_state_modified": false',
        ):
            self.assertIn(token, controls)

    def test_l10_nullable_terminal_failure_projection_is_exact_and_complete(
        self,
    ) -> None:
        design_raw = L10_REPAIR_DESIGN_PATH.read_bytes()
        self.assertEqual(len(design_raw), 16553)
        self.assertEqual(
            hashlib.sha256(design_raw).hexdigest(), L10_REPAIR_DESIGN_SHA256
        )
        self.assertEqual(self.l10_repair_design["repair_id"], "QSDK-R10F-L10")
        self.assertEqual(self.l10_repair_design["parent_repair_id"], "QSDK-R10F-L9")
        self.assertEqual(
            self.l10_repair_design["controlled_change"]["source_domain"],
            ["null", "nonempty String"],
        )
        self.assertFalse(
            self.l10_repair_design["controlled_change"][
                "generic_string_conversion_permitted"
            ]
        )
        predecessor_raw = L10_PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_bytes()
        self.assertEqual(len(predecessor_raw), 8646)
        self.assertEqual(
            hashlib.sha256(predecessor_raw).hexdigest(),
            L10_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )

        contract = self.process_isolated_child_contract
        self.assertIn('const REPAIR_ID := "QSDK-R10F-L9"', contract)
        self.assertIn(
            'const NULLABLE_TERMINAL_FAILURE_REPAIR_ID := "QSDK-R10F-L10"',
            contract,
        )
        self.assertIn('const SUCCESSOR_REPAIR_ID := "QSDK-R10F-L11"', contract)
        projection = function(contract, "nullable_terminal_failure_code_projection_v1")
        for token in (
            'recovery_memory.has("phase")',
            'recovery_memory.has("terminal_failure_code")',
            "typeof(terminal_phase) != TYPE_STRING",
            'terminal_phase == "complete"',
            "not source_is_null",
            'terminal_phase == "failed" or terminal_phase == "refused"',
            "typeof(terminal_failure_source) != TYPE_STRING",
            "terminal_failure_source.is_empty()",
            "projected_failure_code = terminal_failure_source",
            '"generic_string_conversion_used": false',
            '"source_mutated": false',
        ):
            self.assertIn(token, projection)
        self.assertNotIn("String(", projection)
        builder = function(contract, "build_precondition_terminal_receipt_v1")
        validator = function(contract, "precondition_terminal_receipt_valid_v1")
        self.assertIn(
            "nullable_terminal_failure_code_projection_v1(recovery_memory)", builder
        )
        self.assertIn("nullable_terminal_failure_code_projection_v1(memory)", validator)

        controls = function(contract, "nullable_terminal_failure_code_zero_world_v1")
        for control_name in self.l10_repair_design[
            "required_positive_zero_world_controls"
        ][:-1]:
            self.assertIn(control_name, controls)
        for control_name in self.l10_repair_design[
            "required_negative_zero_world_controls"
        ][:-1]:
            self.assertIn(control_name, controls)
        self.assertIn("positive_controls.size() == 6", controls)
        self.assertIn("negative_controls.size() == 16", controls)

        worker_controls = function(self.worker, "zero_world_contract_v9")
        self.assertIn(
            "all_existing_l9_process_isolated_child_positive_controls_still_pass",
            worker_controls,
        )
        self.assertIn(
            "all_existing_l9_process_isolated_child_negative_controls_still_pass",
            worker_controls,
        )
        self.assertIn(
            'result["nullable_terminal_failure_code_positive_control_count"]',
            worker_controls,
        )
        self.assertIn(
            'result["nullable_terminal_failure_code_mutation_rejection_count"]',
            worker_controls,
        )

        self.assertIn("pub terminal_failure_code: Option<String>", self.recovery_core)
        self.assertIn(") != memory.terminal_failure_code.is_some()", self.recovery_core)
        self.assertIn(
            '$script:QsdkR10fL9RepairId = "QSDK-R10F-L14"',
            self.process_isolated_pair_evaluator,
        )
        self.assertIn(
            '$script:QsdkR10fL11ReleaseRepairId = "QSDK-R10F-L11"',
            self.process_isolated_pair_evaluator,
        )
        self.assertIn(
            '$script:QsdkR10fL9ChildContractRepairId = "QSDK-R10F-L9"',
            self.process_isolated_pair_evaluator,
        )
        closer_projection = python_function(
            self.physical_closure, "nullable_terminal_failure_code_matches"
        )
        self.assertIn("source_value is not None", closer_projection)
        self.assertIn("type(source_value) is not str", closer_projection)
        self.assertIn("projected_failure_code != source_value", closer_projection)

    def test_l11_release_owner_source_projection_is_narrow_digest_bound_and_complete(
        self,
    ) -> None:
        design_raw = L11_REPAIR_DESIGN_PATH.read_bytes()
        self.assertEqual(len(design_raw), 17978)
        self.assertEqual(
            hashlib.sha256(design_raw).hexdigest(), L11_REPAIR_DESIGN_SHA256
        )
        design = self.l11_repair_design
        self.assertEqual(design["repair_id"], "QSDK-R10F-L11")
        self.assertEqual(design["parent_repair_id"], "QSDK-R10F-L10")
        change = design["controlled_change"]
        self.assertEqual(
            change["change_class"],
            "precondition_release_no_actuation_owner_source_representation_only",
        )
        self.assertTrue(change["full_terminal_receipt_retained_without_mutation"])
        self.assertTrue(change["full_recovery_step_receipt_retained_without_mutation"])
        self.assertFalse(change["broad_no_actuation_outcome_guard_changed"])
        self.assertTrue(change["release_receipt_schema_advanced_to_l11"])
        self.assertFalse(change["terminal_receipt_schema_changed"])
        self.assertFalse(change["interaction_source_schema_changed"])

        predecessor_raw = L11_PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_bytes()
        self.assertEqual(len(predecessor_raw), 8651)
        self.assertEqual(
            hashlib.sha256(predecessor_raw).hexdigest(),
            L11_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )
        predecessor = json.loads(predecessor_raw)
        self.assertEqual(predecessor["repair_id"], "QSDK-R10F-L10")
        self.assertTrue(predecessor["physical_identity_consumed"])
        self.assertFalse(predecessor["same_identity_rerun_permitted"])
        self.assertEqual(predecessor["world_attempt_count"], 1)
        self.assertEqual(predecessor["world_build_count"], 1)
        self.assertEqual(predecessor["solver_step_count"], 240)

        contract = self.process_isolated_child_contract
        self.assertIn('const SUCCESSOR_REPAIR_ID := "QSDK-R10F-L11"', contract)
        self.assertIn(
            '"sporespore_qsdk_r10f_l11_process_isolated_precondition_release_receipt_v1"',
            contract,
        )
        self.assertIn(
            '"sporespore_qsdk_r10f_l11_precondition_release_owner_source_projection_v1"',
            contract,
        )
        projection = function(
            contract, "precondition_release_owner_source_projection_v1"
        )
        validator = function(
            contract, "precondition_release_owner_source_projection_valid_v1"
        )
        for token in (
            "precondition_terminal_receipt_valid_v1",
            "DISPOSITION_COMPLETE",
            '"precondition_terminal_receipt_sha256"',
            '"recovery_memory_sha256"',
            '"recovery_step_receipt_sha256"',
            '"outcome_derived_correction": false',
            '"physical_acceptance_authority": false',
            '"release_authority": false',
        ):
            self.assertIn(token, projection)
        for token in (
            "_keys_exact_v1(source, RELEASE_OWNER_SOURCE_KEYS)",
            "completed_step + 1",
            'source.get("precondition_terminal_receipt_sha256", "")',
            'source.get("recovery_memory_sha256", "")',
            'source.get("recovery_step_receipt_sha256", "")',
            "_payload_sha256_v1(sdk, source)",
        ):
            self.assertIn(token, validator)
        for forbidden in (
            '"physical_result"',
            '"stable_stance_gate"',
            '"energy_balance_residual_j"',
            '"actuator_work_j"',
        ):
            self.assertNotIn(forbidden, projection)

        release_validator = function(contract, "precondition_release_receipt_valid_v1")
        self.assertIn(
            "precondition_release_owner_source_projection_v1(sdk, terminal)",
            release_validator,
        )
        self.assertIn(
            'ledger.get("owner_source_receipt") != release_owner_source',
            release_validator,
        )
        controls = function(contract, "precondition_release_owner_source_zero_world_v1")
        self.assertIn("positive_controls.size() == 8", controls)
        self.assertIn("negative_controls.size() == 22", controls)
        self.assertIn("raw_runtime_shaped_recovery_step_refused", controls)
        self.assertIn("foreign_release_owner_source_refused", controls)

        worker_controls = function(self.worker, "zero_world_contract_v10")
        self.assertIn(
            "precondition_release_owner_source_positive_control_count",
            worker_controls,
        )
        self.assertIn(
            "precondition_release_owner_source_mutation_rejection_count",
            worker_controls,
        )
        self.assertIn("== 8", worker_controls)
        self.assertIn("== 22", worker_controls)
        self.assertIn("broad_no_actuation_outcome_guard_changed", worker_controls)

        pair_owner_validator = powershell_function(
            self.process_isolated_pair_evaluator,
            "Test-QsdkR10fL11ReleaseOwnerSource",
        )
        self.assertIn("QsdkR10fL11ReleaseOwnerSourceSchema", pair_owner_validator)
        self.assertIn("precondition_terminal_receipt_sha256", pair_owner_validator)
        self.assertIn("recovery_memory_sha256", pair_owner_validator)
        self.assertIn("recovery_step_receipt_sha256", pair_owner_validator)
        self.assertIn(
            "Test-QsdkR10fL9Sha256 $Source.payload_sha256", pair_owner_validator
        )
        self.assertIn(
            "release_owner_digest_mismatch_refused",
            self.process_isolated_pair_evaluator,
        )

        closer_projection = python_function(
            self.physical_closure, "l11_release_owner_source_projection"
        )
        self.assertIn("precondition_terminal_receipt_sha256", closer_projection)
        self.assertIn("recovery_memory_sha256", closer_projection)
        self.assertIn("recovery_step_receipt_sha256", closer_projection)
        self.assertIn('"source_measurement": True', closer_projection)
        self.assertIn('"outcome_derived_correction": False', closer_projection)
        self.assertIn(
            '"release_owner_source_mutation_rejection_count"',
            self.physical_closure,
        )

        self.assertIn("def audit_repair_design(", self.implementation_audit)
        self.assertIn("def repair_design_binding(", self.materializer)
        self.assertIn("function Get-L11RepairDesign {", self.supervisor)
        manifest = json.loads(L11_MANIFEST_PATH.read_text(encoding="utf-8"))
        self.assertEqual(
            manifest["schema_version"],
            "sporespore_qsdk_r10f_dependency_manifest_v12",
        )
        self.assertEqual(manifest["repair_id"], "QSDK-R10F-L11")
        self.assertEqual(
            manifest["claim_boundary"][
                "precondition_release_owner_source_positive_control_count"
            ],
            9,
        )
        self.assertEqual(
            manifest["claim_boundary"][
                "precondition_release_owner_source_mutation_rejection_count"
            ],
            23,
        )

    def test_l12_walking_handoff_is_precommand_exact_r69_bound_and_session_local(
        self,
    ) -> None:
        design_raw = L12_REPAIR_DESIGN_PATH.read_bytes()
        self.assertEqual(len(design_raw), 26010)
        self.assertEqual(
            hashlib.sha256(design_raw).hexdigest(), L12_REPAIR_DESIGN_SHA256
        )
        design = self.l12_repair_design
        self.assertEqual(design["repair_id"], "QSDK-R10F-L12")
        self.assertEqual(design["parent_repair_id"], "QSDK-R10F-L11")
        change = design["controlled_change"]
        self.assertEqual(
            change["change_class"],
            "r10f_walking_actuation_ownership_handoff_and_existing_host_cap_binding_only",
        )
        self.assertEqual(
            change["covered_evaluation_segments"],
            ["walking_prefix", "matched_continuation", "walking_resume"],
        )
        self.assertFalse(change["extra_solver_step_inserted"])
        self.assertFalse(change["release_step_changed"])
        self.assertFalse(change["shared_adapter_enable_behavior_changed"])
        self.assertFalse(change["published_actuator_profile_changed"])
        self.assertFalse(change["new_tolerance_or_margin_added"])
        self.assertFalse(change["outcome_derived_correction"])

        predecessor_raw = L12_PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_bytes()
        self.assertEqual(len(predecessor_raw), 8654)
        self.assertEqual(
            hashlib.sha256(predecessor_raw).hexdigest(),
            L12_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )
        predecessor = json.loads(predecessor_raw)
        self.assertEqual(predecessor["repair_id"], "QSDK-R10F-L11")
        self.assertTrue(predecessor["physical_identity_consumed"])
        self.assertFalse(predecessor["same_identity_rerun_permitted"])
        self.assertEqual(predecessor["world_attempt_count"], 1)
        self.assertEqual(predecessor["world_build_count"], 1)
        self.assertEqual(predecessor["solver_step_count"], 241)

        self.assertIn('const REPAIR_ID := "QSDK-R10F-L14"', self.worker)
        self.assertIn(
            'const WORK_ID := "QSDK-R10F-L14-GODOT-JOLT-PROCESS-ISOLATED-CHILD-DEVELOPMENT"',
            self.worker,
        )
        cap_binding = function(self.facade, "walking_host_cap_projection_binding_v1")
        self.assertRegex(
            cap_binding,
            r"RecoveryWorld\s*\.\s*native_effective_impulse_limit_projection_v1\(",
        )
        for token in (
            "RecoveryWorld.ORDERED_PUBLISHED_CAPS_NMS",
            '"configured_host_maximum_impulse_nms"',
            '"next_native_effective_limit_above_published"',
            '"configured_to_next_binary32_ulp_distance"',
            '"empirical_margin_added"',
            '"raw_measurement_clamped"',
        ):
            self.assertIn(token, cap_binding)

        handoff = function(self.facade, "begin_walking_actuation_handoff_v1")
        projection_index = handoff.index("walking_host_cap_projection_binding_v1(sdk)")
        enable_index = handoff.index("configure_all_motors_v1(true")
        readback_index = handoff.index("motor_population_readback_v1(")
        receipt_index = handoff.index("walking_actuation_handoff_receipt_v1(")
        cache_index = handoff.index("_walking_actuation_handoff_receipt =")
        self.assertLess(projection_index, enable_index)
        self.assertLess(enable_index, readback_index)
        self.assertLess(readback_index, receipt_index)
        self.assertLess(receipt_index, cache_index)
        self.assertIn("global_semantic_step != _global_start_step + 1", handoff)
        self.assertNotIn("physics_frame", handoff)
        self.assertNotIn("step(", handoff)

        worker_start = function(self.worker, "_start_walking_session_v1")
        self.assertLess(
            worker_start.index("start_walking_session_v1("),
            worker_start.index("begin_walking_actuation_handoff_v1("),
        )
        self.assertLess(
            worker_start.index("begin_walking_actuation_handoff_v1("),
            worker_start.index("_apply_next_walking_step_v1("),
        )
        self.assertIn('arm["walking_actuation_handoff_receipts"]', worker_start)
        self.assertIn(
            '"walking_actuation_handoff_receipt": handoff.duplicate(true)', worker_start
        )

        apply_step = function(self.facade, "sample_step_apply_v1")
        self.assertIn(". apply_authority(", apply_step)
        self.assertIn("_authorized_host_cap_by_actuator_id", apply_step)
        self.assertIn("walking_actuation_handoff_receipt_valid_v1(", apply_step)
        shared_apply = function(self.shared_adapter, "apply_authority")
        self.assertNotIn("motor_flag", shared_apply)
        self.assertNotIn("configure_all_motors", shared_apply)

        fixture = function(self.zero_world, "_walking_ledger_fixture_v1")
        self.assertIn("walking_host_cap_projection_binding_v1(sdk)", fixture)
        self.assertIn('cap_binding["selected_host_cap_by_actuator_id"]', fixture)
        self.assertIn("walking_actuation_handoff_receipt_v1(", fixture)
        self.assertNotIn("0.75", fixture)
        worker_controls = function(self.worker, "zero_world_contract_v11")
        self.assertIn(
            "walking_actuation_handoff_positive_control_count", worker_controls
        )
        self.assertIn(
            "walking_actuation_handoff_mutation_rejection_count", worker_controls
        )
        self.assertIn("qualified_r69_projection_count", worker_controls)
        self.assertIn("== 4", worker_controls)
        self.assertIn("== 21", worker_controls)
        self.assertIn(
            'result["walking_handoff_extra_solver_step_count"] = 0', worker_controls
        )
        closer_handoff = python_function(
            self.physical_closure, "validate_l12_walking_handoff"
        )
        for token in (
            "set(receipt) == WALKING_HANDOFF_KEYS",
            "l12_expected_host_cap_projection(index)",
            'receipt.get("motor_configuration_receipt_sha256")',
            'receipt.get("precommand_motor_population_readback_sha256")',
            'receipt.get("payload_sha256") == l12_payload_sha256_v1(receipt)',
        ):
            self.assertIn(token, closer_handoff)
        closer_population = python_function(
            self.physical_closure, "validate_l12_walking_handoff_population"
        )
        self.assertIn("int(handoff_step) == int(release_step) + 1", closer_population)
        self.assertIn("session_id not in observed_session_ids", closer_population)
        self.assertIn("extra_solver_step_count", closer_population)

    def test_l13_walking_ledger_verifies_native_transport_and_exact_host_projection(
        self,
    ) -> None:
        design_raw = L13_REPAIR_DESIGN_PATH.read_bytes()
        self.assertEqual(len(design_raw), 27267)
        self.assertEqual(
            hashlib.sha256(design_raw).hexdigest(), L13_REPAIR_DESIGN_SHA256
        )
        design = self.l13_repair_design
        self.assertEqual(design["repair_id"], "QSDK-R10F-L13")
        self.assertEqual(design["parent_repair_id"], "QSDK-R10F-L12")
        self.assertEqual(
            design["controlled_change"]["change_class"],
            "walking_ledger_transport_verification_host_target_projection_and_failure_retention_only",
        )
        self.assertEqual(len(design["required_positive_zero_world_controls"]), 15)
        self.assertEqual(len(design["required_negative_zero_world_controls"]), 16)
        self.assertFalse(design["frozen_behavioral_terms"]["force_aware_recovery"])
        self.assertFalse(design["frozen_behavioral_terms"]["force_aware_bracing"])

        native = self.godot_native_adapter
        for token in (
            "fn balanced_wave_native_step_transport_verification_json(",
            "fn verify_balanced_wave_native_step_transport(",
            "let envelope: Value = serde_json::from_str(raw_response)",
            "digest_json(&controller_receipt)",
            "Sha256::digest(raw_response.as_bytes())",
            '"floating_point_measurement_field_count": 0',
            "assert_json_has_no_floating_numbers(&receipt)",
            "native_step_transport_verification_refuses_identity_and_digest_mutations",
        ):
            self.assertIn(token, native)

        transport = function(
            self.shared_adapter,
            "_call_balanced_wave_session_step_with_transport_verification",
        )
        raw_call_index = transport.index('"balanced_wave_policy_session_step_json"')
        verification_call_index = transport.index(
            '"balanced_wave_native_step_transport_verification_json"'
        )
        raw_parse_index = transport.index("JSON.parse_string(raw_response)")
        self.assertLess(raw_call_index, verification_call_index)
        self.assertLess(verification_call_index, raw_parse_index)
        self.assertIn("native_step_transport_verification_receipt_valid_v1(", transport)

        adapter_step = function(self.shared_adapter, "step")
        self.assertIn(
            "require_native_step_transport_verification: bool = false", adapter_step
        )
        self.assertIn(
            "_call_balanced_wave_session_step_with_transport_verification(",
            adapter_step,
        )
        adapter_finish = function(
            self.shared_adapter, "_finish_balanced_wave_shadow_step"
        )
        self.assertIn('result["native_step_transport_verification"]', adapter_finish)

        facade_step = function(self.facade, "sample_step_apply_v1")
        self.assertIn(". step(", facade_step)
        self.assertIn("walking_ledger_application_intent_v2(", facade_step)
        self.assertIn('"native_step_transport_verification"', facade_step)
        self.assertIn('"host_target_projection_receipt"', facade_step)

        projection = function(self.facade, "walking_host_target_projection_receipt_v1")
        validator = function(
            self.facade, "walking_host_target_projection_receipt_valid_v1"
        )
        for token in (
            "float(PackedFloat32Array([controller_target])[0])",
            '"controller_binary64_target_velocity_rad_s"',
            '"expected_binary32_host_target_velocity_rad_s"',
            '"application_motor_target_velocity_readback_rad_s"',
            '"population_motor_target_velocity_readback_rad_s"',
            '"r69_host_cap_exact"',
            '"empirical_margin_added": false',
            '"tolerance_added": false',
            '"controller_command_rounded_before_write": false',
            '"solver_input_changed": false',
        ):
            self.assertIn(token, projection)
        for token in (
            'row.get("application_motor_target_velocity_readback_rad_s", NAN)',
            'row.get("population_motor_target_velocity_readback_rad_s", NAN)',
            "!= expected_host_target",
            'row.get("application_population_readbacks_equal_exactly", false)',
            "authorized_host_cap > published_cap",
            "_keys_exact_v1(row, WALKING_HOST_TARGET_PROJECTION_ROW_KEYS)",
        ):
            self.assertIn(token, validator)
        self.assertNotIn("is_equal_approx", projection)
        self.assertNotIn("is_equal_approx", validator)

        ledger = function(self.facade, "walking_ledger_application_intent_v2")
        self.assertIn(
            "native_step_transport_verification_receipt_valid_v1(",
            ledger,
        )
        self.assertIn(
            '"controller_step_receipt_digest_authority": "native_preparse_transport_verification"',
            ledger,
        )
        self.assertIn('"post_parse_controller_receipt_rehash_used": false', ledger)
        self.assertNotIn("_sha256_v1(sdk, controller_receipt)", ledger)
        for source_name in (
            "portable_step_receipt",
            "native_step_transport_verification",
            "controller_step_receipt",
            "authority_application_receipt",
            "motor_population_readback",
            "walking_actuation_handoff_receipt",
            "host_target_projection_receipt",
            "walking_ledger_predicate_receipt",
        ):
            self.assertIn(f'"{source_name}"', ledger)
        self.assertIn('"failed_predicate_ids"', ledger)
        self.assertIn('"generic_failure_without_predicate_detail": false', ledger)

        fixture = function(self.zero_world, "_walking_ledger_production_fixture_v2")
        for token in (
            "AdapterScript.new()",
            "HingeJoint3D.new()",
            "begin_walking_actuation_handoff_v1(",
            ". step(",
            ". apply_authority(",
            "motor_population_readback_v1(",
            "walking_ledger_application_intent_v2(",
            '"body_construction_count": 0',
            '"world_build_count": 0',
            '"solver_step_count": 0',
        ):
            self.assertIn(token, fixture)
        for forbidden in (
            "add_child(",
            "await physics_frame",
            "build_native_world_v1(",
        ):
            self.assertNotIn(forbidden, fixture)

        controls = function(self.zero_world, "_walking_ledger_l13_controls_v1")
        negative_controls = function(
            self.zero_world, "_walking_ledger_l13_negative_controls_v1"
        )
        for control_name in design["required_positive_zero_world_controls"]:
            self.assertIn(control_name, controls)
        for control_name in design["required_negative_zero_world_controls"]:
            self.assertIn(control_name, negative_controls)
        self.assertIn("positive_controls.size() == 15", controls)
        self.assertIn(
            'int(negative_controls.get("rejection_count", -1)) == 16', controls
        )

        worker_apply = function(self.worker, "_apply_next_walking_step_v1")
        self.assertIn(
            'arm["last_walking_step_failure"] = step.duplicate(true)', worker_apply
        )
        partial = function(self.worker, "partial_arm_failure_retention_projection_v1")
        self.assertIn('"active_walking_session"', partial)
        self.assertIn('"last_walking_step_failure"', partial)
        worker_controls = function(self.worker, "zero_world_contract_v12")
        self.assertIn("zero_world_contract_v11(sdk, context)", worker_controls)
        self.assertIn(
            "walking_ledger_failure_retention_positive_control_count", worker_controls
        )
        self.assertIn(
            "walking_ledger_failure_retention_mutation_rejection_count", worker_controls
        )
        self.assertIn("== 1", worker_controls)
        self.assertIn("== 15", worker_controls)

        for validator_name in (
            "validate_l13_native_transport_verification",
            "validate_l13_host_target_projection",
            "validate_l13_walking_ledger_predicates",
            "validate_l13_partial_walking_failure_report",
        ):
            self.assertIn(f"def {validator_name}(", self.physical_closure)
        retained_failure = python_function(
            self.physical_closure, "validate_l13_partial_walking_failure_report"
        )
        for token in (
            "set(failure) == failure_keys",
            'failure.get("failed_predicate_ids")',
            'failure.get("generic_failure_without_predicate_detail") is False',
            'exact_int(failure.get("solver_step_count"), 0)',
            '"walking_ledger_failure_retention_valid": True',
            '"retained_source_count": len(required_sources)',
        ):
            self.assertIn(token, retained_failure)
        self.assertIn(
            '"sporespore_qsdk_r10f_l13_physical_closure_self_test_v1"',
            self.physical_closure,
        )
        self.assertIn(
            "retention_rejections == len(retention_mutations) == 15",
            self.physical_closure,
        )

        root_design_audit = python_function(self.implementation_audit, "audit_design")
        for token in (
            'expected_drift_path = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"',
            'entry.get("role") == "observed_l12_shared_walking_adapter_source"',
            "current_disk_drift_paths == [expected_drift_path]",
            "module.load_bound_authorities = load_historical_bound_authorities",
            "authored_parent_historical_replay_with_explicit_l13_successor_drift",
        ):
            self.assertIn(token, root_design_audit)
        self.assertIn(
            'module.sha256_bytes(current_raw) == entry["raw_sha256"]',
            root_design_audit,
        )
        self.assertIn(
            'module.sha256_bytes(historical_raw) == entry["raw_sha256"]',
            root_design_audit,
        )
        implementation_audit = python_function(self.implementation_audit, "audit")
        self.assertIn('"root_design_audit": design', implementation_audit)
        qualification_validator = python_function(
            self.materializer, "validate_qualification"
        )
        self.assertIn(
            'root_design_audit.get("current_disk_drift_paths")',
            qualification_validator,
        )
        self.assertIn(
            '"QUALIFICATION_ROOT_DESIGN_AUDIT_FIELDS"',
            qualification_validator,
        )
        self.assertIn(
            "Assert-ZeroWorldReceipt $receipt.root_design_audit",
            self.qualification,
        )

    def test_l9_pair_evaluator_is_pure_and_executes_all_zero_world_controls(
        self,
    ) -> None:
        evaluator = self.process_isolated_pair_evaluator
        for token in (
            "function Get-QsdkR10fL9ChildValidation {",
            "function Invoke-QsdkR10fL9PairEvaluator {",
            "function Invoke-QsdkR10fL9ProcessPopulationEvaluation {",
            "function Invoke-QsdkR10fL9PairEvaluatorZeroWorld {",
            "$script:QsdkR10fL9MaximumChildSolverSteps = 3842",
            "$script:QsdkR10fL9MaximumTotalSolverSteps = 7684",
            "global_steps_retained_as_separate_sources",
            "trace_truncation_used_for_pair_alignment = $false",
            "matched_no_kick_delta_subtracted = $true",
            "process_lifetimes_overlap = $false",
        ):
            self.assertIn(token, evaluator)
        for forbidden in (
            "Start-Process",
            "Invoke-SporeSporeGodotReceiptTerminatedProcess",
            "PhysicsServer3D",
            "apply_central_impulse",
        ):
            self.assertNotIn(forbidden, evaluator)

        script_path = str(PROCESS_ISOLATED_PAIR_EVALUATOR_PATH).replace("'", "''")
        command = (
            f". '{script_path}'; "
            "Invoke-QsdkR10fL9PairEvaluatorZeroWorld | "
            "ConvertTo-Json -Compress -Depth 100"
        )
        result = subprocess.run(
            ("pwsh", "-NoLogo", "-NoProfile", "-Command", command),
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt = json.loads(result.stdout.strip())
        self.assertTrue(receipt["ok"])
        self.assertEqual(receipt["positive_control_count"], 3)
        self.assertEqual(receipt["mutation_rejection_count"], 35)
        self.assertTrue(all(receipt["positive_controls"].values()))
        self.assertTrue(all(receipt["mutation_controls"].values()))
        for field in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_readback_count",
            "solver_step_count",
        ):
            self.assertEqual(receipt[field], 0)
        self.assertFalse(receipt["physics_state_modified"])
        self.assertFalse(receipt["physical_acceptance_authority"])
        self.assertFalse(receipt["release_authority"])

    def test_historical_l7_pair_abort_is_preserved_but_l9_entry_bypasses_it(
        self,
    ) -> None:
        plan = function(self.worker, "_plan_next_lockstep_frame_v1")
        self.assertLess(
            plan.index("_refresh_precondition_terminal_dispositions_v1(global_step)"),
            plan.index("if active_terminal or baseline_terminal"),
        )
        self.assertIn(". build_abort_population_v1(", plan)
        self.assertIn("PreconditionTerminalDisposition.FAILURE_CODE", plan)

        frame = function(self.worker, "_on_physics_frame")
        self.assertNotIn("_plan_next_lockstep_frame_v1", frame)
        self.assertNotIn(
            "planned_failure == PreconditionTerminalDisposition.FAILURE_CODE", frame
        )
        self.assertIn("_plan_next_process_isolated_frame_v1(active_step)", frame)
        self.assertLess(
            frame.index('if bool(arm["terminal"]):'),
            frame.index("_plan_next_process_isolated_frame_v1(active_step)"),
        )
        abort = function(self.worker, "_abort")
        for token in (
            '"precondition_terminal_disposition_by_arm"',
            '"precondition_terminal_disposition_pair_state"',
            '"precondition_terminal_abort_population"',
            ". abort_population_valid_v1(",
        ):
            self.assertIn(token, abort)

        for function_name in (
            "validate_terminal_disposition",
            "validate_terminal_disposition_population",
            "validate_invalid_disposition_raw",
        ):
            self.assertIn(f"def {function_name}(", self.physical_closure)
        for token in (
            "canonical_sha256_v1(memory)",
            "canonical_sha256_v1(step)",
            "canonical_sha256_v1(classification)",
            "payload_sha256_v1(receipt)",
            "payload_sha256_v1(population)",
            "all(completed[arm] is True for arm in ARM_IDS)",
            "all(is_sha256(applications[arm]) for arm in ARM_IDS)",
            '"L7_VALID_DISPOSITION_RELEASE_ORDER"',
            '"L7_INVALID_RAW_DETAIL_BINDING"',
            'exact_int(raw.get("explicit_worker_extra_native_readback_count"), 0)',
            'exact_int(termination.get("exit_code"), 1)',
            "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED",
            'require(report_rejected == 55, "SELF_TEST_REPORT_MUTATION_REJECTIONS")',
            'require(rejected == 70, "SELF_TEST_MUTATION_REJECTIONS")',
        ):
            self.assertIn(token, self.physical_closure)

    def test_facade_uses_recovery_nodes_and_fresh_walking_sessions(self) -> None:
        binding = function(self.facade, "_build_live_binding_v1")
        self.assertIn('model.get("body_nodes")', binding)
        self.assertIn('model.get("joint_nodes")', binding)
        for forbidden in ("RigidBody3D.new", "PinJoint3D.new", "StaticBody3D.new"):
            self.assertNotIn(forbidden, self.facade)
        start = function(self.facade, "start_walking_session_v1")
        self.assertIn("SdkAdapterScript.new()", start)
        self.assertIn(". start(", start)
        self.assertIn("task_frame_reanchored_in_controller_memory", start)
        finish = function(self.facade, "finish_walking_session_v1")
        self.assertIn("_adapter.shutdown()", finish)

    def test_walking_evaluator_owns_fixed_thresholds_and_accepts_no_overrides(
        self,
    ) -> None:
        for constant in (
            "FIXED_SEGMENT_STEP_COUNT := 720",
            "MINIMUM_FOOT_RELOCATION_M := 0.012",
            "MINIMUM_FORWARD_ADVANCE_M := 0.02",
            "MAXIMUM_ABSOLUTE_LATERAL_DRIFT_M := 0.25",
            "MAXIMUM_ANCHOR_ERROR_M := 0.025",
        ):
            self.assertIn(constant, self.evaluator)
        evaluate = function(self.evaluator, "evaluate_segment_v1")
        self.assertIn("not _keys_exact_v1(evidence, INPUT_KEYS)", evaluate)
        self.assertIn('"behavior_passed": false_receipts.is_empty()', evaluate)
        self.assertIn('"threshold_override_input_count": 0', evaluate)
        self.assertNotIn("acceptance_threshold", self.evaluator)

    def test_epoch_transport_keeps_global_sequence_and_derives_local_offset(
        self,
    ) -> None:
        advance = function(self.epoch_transport, "advance_epoch_transport_v1")
        self.assertIn("current_global_step", advance)
        self.assertIn("cached_global_step + 1", advance)
        self.assertIn("epoch_local_step", advance)
        self.assertIn("current_global_step - epoch_start_global_step", advance)
        self.assertIn("QSDK_R10F_EPOCH_DUPLICATE_GLOBAL_BOUNDARY", self.epoch_transport)
        self.assertIn("QSDK_R10F_EPOCH_STALE_GLOBAL_BOUNDARY", self.epoch_transport)
        self.assertIn("QSDK_R10F_EPOCH_SKIPPED_GLOBAL_BOUNDARY", self.epoch_transport)
        self.assertIn(
            '"global_sequence_rewrite_permitted": false', self.epoch_transport
        )

    def test_epoch_energy_starts_after_kick_from_live_measurement(self) -> None:
        initialize = function(self.energy_initializer, "initialize_energy_epoch_v1")
        self.assertIn("current_mechanical_energy_j", initialize)
        self.assertIn(
            '"kick_work_included_in_recovery_epoch_ledger": false', initialize
        )
        self.assertIn(
            '"canonical_world_start_pose_reconstruction_used": false', initialize
        )
        self.assertIn('"recovery_local_discrete_staging_event_count": 0', initialize)
        self.assertIn(
            "retained_r162_source_extracted_without_remeasurement", self.native_epoch
        )
        self.assertIn(
            '"global_counters_mutated_by_local_projection": false', self.native_epoch
        )
        self.assertIn('"global_counters_mutated": false', self.epoch_staging)

    def test_impulse_receipt_reuses_r10e_math_without_fixed_step_copy(self) -> None:
        self.assertIn("R10eScalarValidator", self.impulse_pair)
        self.assertIn('"r10e_scalar_tolerance_math_reused": true', self.impulse_pair)
        self.assertIn(
            '"r10e_fixed_step_900_copied_into_r10f": false', self.impulse_pair
        )
        self.assertIn('"matched_no_kick_delta_subtracted": true', self.impulse_pair)
        self.assertNotIn("completed_effect_global_step == 900", self.impulse_pair)

    def test_zero_world_gate_has_no_physical_entrypoint(self) -> None:
        evaluate = function(self.zero_world, "_evaluate_v1")
        for token in (
            "PhysicsServer3D",
            "await physics_frame",
            "apply_central_impulse",
            "RigidBody3D.new",
            "build_native_world_v1(",
        ):
            self.assertNotIn(token, evaluate)
        self.assertIn("PhysicalWorker.zero_world_contract_v12(sdk, context)", evaluate)
        self.assertIn("WalkingEvaluator.evaluate_segment_v1", self.zero_world)
        self.assertIn('"initial_bootstrap_mutation_rejection_count"', evaluate)
        self.assertIn('"joint_geometry_mutation_rejection_count"', evaluate)
        self.assertIn('"collection_solver_counter_mutation_rejection_count"', evaluate)
        self.assertIn('"precondition_pair_required_mutation_rejection_count"', evaluate)
        self.assertIn(
            '"precondition_terminal_disposition_mutation_rejection_count"', evaluate
        )
        self.assertIn(
            '"integer_valued_native_step_domain_mutation_rejection_count"', evaluate
        )
        self.assertIn('"process_isolated_child_positive_case_count"', evaluate)
        self.assertIn('"process_isolated_child_mutation_rejection_count"', evaluate)
        self.assertIn(
            '"nullable_terminal_failure_code_positive_control_count"', evaluate
        )
        self.assertIn(
            '"nullable_terminal_failure_code_mutation_rejection_count"', evaluate
        )
        self.assertIn(
            '"precondition_release_owner_source_positive_control_count"', evaluate
        )
        self.assertIn(
            '"precondition_release_owner_source_mutation_rejection_count"', evaluate
        )
        self.assertIn('"walking_actuation_handoff_positive_control_count"', evaluate)
        self.assertIn('"walking_actuation_handoff_mutation_rejection_count"', evaluate)
        self.assertIn('"qualified_r69_projection_count"', evaluate)
        self.assertIn('"detached_command_surface_node_count"', evaluate)
        self.assertIn('"detached_geometry_body_node_count"', evaluate)
        self.assertIn('"detached_geometry_joint_node_count"', evaluate)
        self.assertIn('"world_attempt_count": 0', evaluate)
        self.assertIn('"solver_step_count": 0', evaluate)

    def test_compact_geometry_consumes_exact_recovery_source_shape(self) -> None:
        producer_match = re.search(
            r"(?ms)joint_states\[joint_id\] = \{(.*?)^\s*\}", self.native_world
        )
        self.assertIsNotNone(producer_match)
        producer = producer_match.group(1)
        for key in (
            '"joint_id"',
            '"parent"',
            '"child"',
            '"joint"',
            '"anchor_parent_local"',
            '"anchor_child_local"',
            '"axis_parent_local"',
        ):
            self.assertIn(key, producer)
        self.assertNotIn('"axis_child_local"', producer)

        geometry = function(self.worker, "_joint_geometry_summary_v2")
        self.assertIn('observation_state.get("ordered_joint_observations")', geometry)
        self.assertIn('row.get("anchor_error_m")', geometry)
        self.assertIn('!= "sporespore_state_frame_v1"', geometry)
        self.assertIn("typeof(row_joint_id_value) != TYPE_STRING", geometry)
        self.assertIn("typeof(anchor_error_value) != TYPE_FLOAT", geometry)
        self.assertIn("typeof(anchor_validity_value) != TYPE_BOOL", geometry)
        self.assertIn("child_basis * shared_axis_local", geometry)
        self.assertIn("shared_axis_local != Vector3.BACK", geometry)
        self.assertNotIn('state.get("axis_child_local")', geometry)
        self.assertNotIn("child_axis_value", geometry)
        self.assertIn('"axis_child_local_required": false', geometry)
        self.assertIn('"axis_child_local_consumed": false', geometry)
        self.assertIn('"outcome_derived_correction": false', geometry)
        self.assertIn("_joint_geometry_failure_v2(", geometry)

        retain = function(self.worker, "_retain_compact_step_v1")
        self.assertIn('_joint_geometry_summary_v2(arm["model"], observation)', retain)

    def test_geometry_source_shape_control_is_detached_and_mutation_complete(
        self,
    ) -> None:
        control = function(self.worker, "_joint_geometry_zero_world_controls_v1")
        fixture = function(self.worker, "_joint_geometry_source_shape_fixture_v1")
        self.assertIn("RigidBody3D.new()", fixture)
        self.assertIn("HingeJoint3D.new()", fixture)
        self.assertNotIn("add_child", fixture)
        self.assertNotIn("PhysicsServer3D", fixture)
        self.assertIn('"axis_parent_local": Vector3.BACK', fixture)
        self.assertNotIn('"axis_child_local"', fixture)
        self.assertEqual(control.count("mutations.append("), 16)
        self.assertIn('"exact_producer_shape_without_child_axis_accepted"', control)
        self.assertIn('"scene_tree_insertion_count": 0', control)
        self.assertIn('"world_attempt_count": 0', control)
        self.assertIn('"solver_step_count": 0', control)

        contract = function(self.worker, "zero_world_contract_v3")
        self.assertIn("zero_world_contract_v2(sdk, context)", contract)
        self.assertIn("_joint_geometry_zero_world_controls_v1", contract)
        self.assertIn('"joint_geometry_mutation_rejection_count"', contract)

    def test_collection_solver_counter_preserves_cumulative_source_and_counts_delta(
        self,
    ) -> None:
        collect = function(self.worker, "_collect_arm_completed_step_v1")
        projection_call = collect.index(
            "_collection_solver_counter_projection_v1(collection, global_step)"
        )
        aggregate = collect.index(
            '_total_solver_step_count += int(solver_counter["completed_step_delta"])'
        )
        self.assertLess(projection_call, aggregate)
        self.assertNotIn(
            '_total_solver_step_count += int(collection.get("solver_step_count", 0))',
            collect,
        )
        self.assertNotIn('int(collection.get("solver_step_count", -1)) != 1', collect)

        projection = function(self.worker, "_collection_solver_counter_projection_v1")
        for token in (
            "NativeEpochRoute.COLLECTION_SCHEMA",
            "typeof(collection_global_step_value) != TYPE_INT",
            "typeof(collection_counter_value) != TYPE_INT",
            "int(collection_counter_value) != expected_global_step",
            "typeof(retained_global_counter_value) != TYPE_INT",
            "int(retained_global_counter_value) != int(collection_counter_value)",
            '"completed_step_delta": 1',
            '"source_measurement": true',
            '"outcome_derived_correction": false',
        ):
            self.assertIn(token, projection)

        retain = function(self.worker, "_retain_compact_step_v1")
        self.assertIn('collection["worker_solver_counter_projection_v1"]', retain)
        self.assertIn('"collector_cumulative_solver_step_exact"', retain)
        self.assertIn('"accepted_collection_step_delta_exact"', retain)
        self.assertIn('"collector_counter_outcome_correction_zero"', retain)

    def test_collection_solver_counter_controls_cover_two_steps_and_wrong_shapes(
        self,
    ) -> None:
        fixture = function(self.worker, "_solver_counter_collection_fixture_v1")
        controls = function(
            self.worker, "_collection_solver_counter_zero_world_controls_v1"
        )
        self.assertIn('"solver_step_count": global_step', fixture)
        self.assertIn('"global_result": {"solver_step_count": global_step}', fixture)
        self.assertEqual(len(re.findall(r"\bmutations\s*\.\s*append\(", controls)), 16)
        self.assertIn("_solver_counter_collection_fixture_v1(1)", controls)
        self.assertIn("_solver_counter_collection_fixture_v1(2)", controls)
        self.assertIn('"consecutive_positive_projection_count": 2', controls)
        self.assertIn('"accepted_completed_step_delta_sum"', controls)
        self.assertIn('"terminal_cumulative_solver_step_count"', controls)
        self.assertIn('"world_attempt_count": 0', controls)
        self.assertIn('"solver_step_count": 0', controls)

        contract = function(self.worker, "zero_world_contract_v4")
        self.assertIn("zero_world_contract_v3(sdk, context)", contract)
        self.assertIn("_collection_solver_counter_zero_world_controls_v1", contract)
        self.assertIn('"collection_solver_counter_mutation_rejection_count"', contract)

    def test_supervisor_requires_explicit_physical_switch_before_side_effects(
        self,
    ) -> None:
        physical = powershell_function(self.supervisor, "Invoke-Physical")
        switch = physical.index(
            'Assert-R10f $RunPhysical "PHYSICAL_MODE_REQUIRES_RUNPHYSICAL"'
        )
        for later in (
            "Get-SourceBoundary -RequireLiveCleanMain",
            "Get-PhysicalAuthority -Path $AuthorizationPath",
            "New-Item -ItemType Directory",
            "Write-JsonCreateNew",
            "Invoke-L9ChildProcess",
        ):
            self.assertLess(switch, physical.index(later))
        self.assertNotIn("Invoke-SporeSporeGodotReceiptTerminatedProcess", physical)

    def test_supervisor_consumes_parent_and_child_identities_before_first_start(
        self,
    ) -> None:
        physical = powershell_function(self.supervisor, "Invoke-Physical")
        create_directory = physical.index("New-Item -ItemType Directory")
        consume_identity = physical.index(
            "$script:PhysicalAttemptIdentityConsumed = $true"
        )
        parent_identity = physical.index(
            "Write-JsonCreateNew (Join-Path $script:PhysicalAttemptRoot "
            '"attempt_identity.json")'
        )
        child_identity = physical.index('"child_attempt_identity.json"')
        worker_start = physical.index("Invoke-L9ChildProcess")
        self.assertLess(create_directory, consume_identity)
        self.assertLess(consume_identity, parent_identity)
        self.assertLess(parent_identity, child_identity)
        self.assertLess(child_identity, worker_start)
        self.assertEqual(physical.count("Invoke-L9ChildProcess"), 2)
        self.assertIn(
            'status = "physical_identity_and_ordered_children_consumed_before_first_child_start"',
            physical,
        )
        self.assertIn("maximum_campaign_attempt_count = 1", physical)
        self.assertIn("maximum_child_process_count = 2", physical)
        self.assertIn("child_retry_permitted = $false", physical)
        self.assertIn("child_replacement_permitted = $false", physical)
        self.assertIn("same_identity_rerun_permitted = $false", physical)

    def test_supervisor_launches_fresh_children_serially_and_pairs_only_after_both(
        self,
    ) -> None:
        physical = powershell_function(self.supervisor, "Invoke-Physical")
        baseline = physical.index("$baseline = Invoke-L9ChildProcess")
        baseline_validation = physical.index(
            "$baselineValidation = Get-L9ChildLaunchValidation"
        )
        invalid_stop = physical.index("if (-not [bool]$baselineValidation.ok)")
        active = physical.index("$active = Invoke-L9ChildProcess")
        final_pair = physical.index(
            "$population = Invoke-QsdkR10fL9ProcessPopulationEvaluation", active
        )
        self.assertLess(baseline, baseline_validation)
        self.assertLess(baseline_validation, invalid_stop)
        self.assertLess(invalid_stop, active)
        self.assertLess(active, final_pair)
        self.assertIn(
            "-ChildEnvelopes ([object[]]$script:ObservedChildEnvelopes.ToArray())",
            physical[final_pair:],
        )
        self.assertNotIn("Start-Job", physical)
        self.assertNotIn("ForEach-Object -Parallel", physical)

    def test_supervisor_requires_exact_two_commit_authority_graph(self) -> None:
        authority = powershell_function(self.supervisor, "Get-PhysicalAuthority")
        for token in (
            'Invoke-GitText @("rev-parse", "HEAD^")',
            'Invoke-GitText @("rev-parse", "HEAD^^")',
            '"AUTHORITY_COMMIT_GRAPH_INVALID"',
            '"AUTHORITY_GRAPH_CHANGED_PATHS_INVALID"',
            "$script:ExpectedAuthorityRelativePath",
            "$script:ExpectedFreezeRelativePath",
        ):
            self.assertIn(token, authority)
        self.assertIn(
            "$headGrandparent -ceq [string]$authority.source_commit", authority
        )
        self.assertIn(
            "$changed = @(ConvertFrom-R10fGitPathText -Text $changedText)", authority
        )
        self.assertNotIn('-AllowEmpty -split "`r?`n"', authority)
        self.assertIn("Test-R10fExactOrdinalPathSet", authority)
        self.assertNotIn("Sort-Object", authority)
        self.assertNotIn('-join "`n"', authority)

    def test_authority_graph_path_projection_executes_exact_supervisor_function(
        self,
    ) -> None:
        projection_function = powershell_function(
            self.supervisor, "ConvertFrom-R10fGitPathText"
        )
        set_function = powershell_function(
            self.supervisor, "Test-R10fExactOrdinalPathSet"
        )
        command = (
            projection_function
            + set_function
            + r"""
$ErrorActionPreference = 'Stop'
$positive = @(ConvertFrom-R10fGitPathText -Text "sdk/a.json`r`nsdk/b.json`n")
$empty = @(ConvertFrom-R10fGitPathText -Text '')
if (
    $positive.Count -ne 2 -or
    [string]$positive[0] -cne 'sdk/a.json' -or
    [string]$positive[1] -cne 'sdk/b.json' -or
    $empty.Count -ne 0
) { throw 'PROJECTION_CONTROL_FAILED' }
$expected = @('sdk/a.json', 'sdk/b.json')
if (-not (Test-R10fExactOrdinalPathSet -Actual $expected -Expected $expected)) {
    throw 'PATH_SET_EQUAL_FAILED'
}
if (-not (Test-R10fExactOrdinalPathSet -Actual @('sdk/b.json', 'sdk/a.json') -Expected $expected)) {
    throw 'PATH_SET_REORDERED_FAILED'
}
if (Test-R10fExactOrdinalPathSet -Actual @('sdk/a.json') -Expected $expected) {
    throw 'PATH_SET_MISSING_ACCEPTED'
}
if (Test-R10fExactOrdinalPathSet -Actual @('sdk/a.json', 'sdk/a.json') -Expected $expected) {
    throw 'PATH_SET_DUPLICATE_ACCEPTED'
}
if (Test-R10fExactOrdinalPathSet -Actual @('sdk/a.json', 'sdk/b.json', 'sdk/c.json') -Expected $expected) {
    throw 'PATH_SET_EXTRA_ACCEPTED'
}
'QSDK_R10F_AUTHORITY_GRAPH_PATH_PROJECTION_ZERO_WORLD_PASS'
"""
        )
        result = subprocess.run(
            (
                "pwsh",
                "-NoLogo",
                "-NoProfile",
                "-Command",
                command,
            ),
            cwd=ROOT,
            check=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(
            "QSDK_R10F_AUTHORITY_GRAPH_PATH_PROJECTION_ZERO_WORLD_PASS",
            result.stdout,
        )

    def test_l9_binds_consumed_l8_closure_and_keeps_earlier_refusals_retired(
        self,
    ) -> None:
        raw = SUPERVISOR_REFUSAL_PATH.read_bytes()
        self.assertEqual(len(raw), 6486)
        self.assertEqual(hashlib.sha256(raw).hexdigest(), SUPERVISOR_REFUSAL_SHA256)
        refusal = json.loads(raw)
        self.assertEqual(refusal["repair_id"], "QSDK-R10F-L2")
        self.assertEqual(
            refusal["status"],
            "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed",
        )
        self.assertFalse(
            refusal["execution_boundary"]["physical_attempt_identity_consumed"]
        )
        self.assertEqual(refusal["execution_boundary"]["world_attempt_count"], 0)
        self.assertEqual(refusal["execution_boundary"]["solver_step_count"], 0)
        self.assertFalse(
            refusal["successor_policy"]["old_execution_authority_reusable"]
        )
        predecessor_raw = PREDECESSOR_REFUSAL_PATH.read_bytes()
        self.assertEqual(len(predecessor_raw), 6012)
        self.assertEqual(
            hashlib.sha256(predecessor_raw).hexdigest(), PREDECESSOR_REFUSAL_SHA256
        )
        self.assertEqual(
            refusal["authority_bindings"]["predecessor_supervisor_refusal"][
                "raw_sha256"
            ],
            "sha256:" + PREDECESSOR_REFUSAL_SHA256,
        )
        physical_closure_raw = PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_bytes()
        self.assertEqual(len(physical_closure_raw), 6317)
        self.assertEqual(
            hashlib.sha256(physical_closure_raw).hexdigest(),
            PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )
        physical_closure = json.loads(physical_closure_raw)
        self.assertEqual(physical_closure["repair_id"], "QSDK-R10F-L8")
        self.assertEqual(
            physical_closure["classification"],
            "invalid_or_incomplete_no_behavioral_conclusion",
        )
        self.assertTrue(physical_closure["physical_identity_consumed"])
        self.assertFalse(physical_closure["same_identity_rerun_permitted"])
        self.assertEqual(physical_closure["world_attempt_count"], 2)
        self.assertEqual(physical_closure["world_build_count"], 2)
        self.assertEqual(physical_closure["solver_step_count"], 600)
        self.assertEqual(
            physical_closure["failure_code"],
            "QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED",
        )
        self.assertEqual(
            physical_closure["precondition_terminal_dispositions"][
                "disposition_by_arm"
            ]["matched_no_kick_continuation"],
            "complete_source_retained",
        )
        self.assertEqual(
            physical_closure["precondition_terminal_dispositions"][
                "disposition_by_arm"
            ],
            {
                "matched_no_kick_continuation": "complete_source_retained",
                "kick_passive_recovery_resume": "failed_source_retained",
            },
        )
        self.assertEqual(
            physical_closure["precondition_terminal_dispositions"]["failing_arm_ids"],
            ["kick_passive_recovery_resume"],
        )
        self.assertEqual(
            physical_closure["evidence_bindings"][
                "consumed_predecessor_physical_closure"
            ]["raw_sha256"],
            "sha256:15cf3bdd5485405613726be8c800c5e46f4178a818ae89b947efc992e3094aba",
        )
        l13_predecessor_raw = L13_PREDECESSOR_PHYSICAL_CLOSURE_PATH.read_bytes()
        self.assertEqual(len(l13_predecessor_raw), 9084)
        self.assertEqual(
            hashlib.sha256(l13_predecessor_raw).hexdigest(),
            L13_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )
        l13_predecessor = json.loads(l13_predecessor_raw)
        self.assertEqual(l13_predecessor["repair_id"], "QSDK-R10F-L12")
        self.assertEqual(
            l13_predecessor["consumed_predecessor_physical_closure_sha256"],
            "sha256:" + L12_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )
        self.assertEqual(
            l13_predecessor["evidence_bindings"][
                "consumed_predecessor_physical_closure"
            ]["raw_sha256"],
            "sha256:" + L12_PREDECESSOR_PHYSICAL_CLOSURE_SHA256,
        )
        design_raw = L9_REPAIR_DESIGN_PATH.read_bytes()
        self.assertEqual(len(design_raw), 19530)
        self.assertEqual(
            hashlib.sha256(design_raw).hexdigest(), L9_REPAIR_DESIGN_SHA256
        )
        self.assertEqual(self.l9_repair_design["repair_id"], "QSDK-R10F-L9")
        population = self.l9_repair_design["prospective_development_population"]
        self.assertEqual(population["maximum_child_process_count"], 2)
        self.assertEqual(population["maximum_world_build_count_per_child"], 1)
        self.assertEqual(population["maximum_total_solver_step_count"], 7684)
        for source in (
            self.supervisor,
            self.qualification,
            self.materializer,
            self.physical_closure,
            self.implementation_audit,
        ):
            self.assertIn("93e60e8fe747a8ba", source)
        for source in (
            self.supervisor,
            self.implementation_audit,
        ):
            self.assertIn("d10684da1566d9a0", source)
        # The supervisor still reopens the complete L11 and L12 repair designs,
        # including their exact earlier authority chain. Narrower L13 auditors
        # bind that history through the immutable L13 design and L12 closure.
        self.assertIn("31027c3ea6fed308", self.supervisor)
        self.assertIn("2d186f41fcb73427", self.supervisor)
        for source in (
            self.supervisor,
            self.physical_closure,
            self.implementation_audit,
        ):
            self.assertIn("QSDK-R10F-L9", source)
        # Active L14 callers bind the consumed L13 record through the shared
        # contract. The exact earlier records above remain historical evidence.
        self.assertIn("REPAIR_ID = l14_authority.REPAIR_ID", self.materializer)
        self.assertIn(
            "l14_authority.predecessor_physical_closure_binding",
            self.implementation_audit,
        )
        self.assertIn("l14_authority.repair_design_binding", self.materializer)
        self.assertIn("01f40035e6cbae846", self.qualification)
        self.assertIn("1df9bd1896deb239", self.qualification)
        self.assertIn("ef04ca607078dbd6", self.qualification)

    def test_supervisor_uses_termination_protocol_and_scrubs_binding_environment(
        self,
    ) -> None:
        child = powershell_function(self.supervisor, "Invoke-L9ChildProcess")
        self.assertIn(
            '. (Join-Path $PSScriptRoot "godot_receipt_terminated_process.ps1")',
            self.supervisor,
        )
        for token in (
            "-ReadyMarkerPrefix $script:ReadyMarker",
            "-ExpectedNonce ([string]$Descriptor.termination_nonce)",
            "$scrubEnvironmentNames = @($script:EnvironmentNames)",
            "-ScrubEnvironmentNames $scrubEnvironmentNames",
            "Get-QsdkR10fL15ContextArguments $Binding",
            "Get-QsdkR10fL15ContextEnvironment $expectedContext.ExpectedL15ContextBinding",
            "$scrubEnvironmentNames += $entry.Key",
            "Get-SporeSporeGodotEngineHealthProjection",
            "SPORESPORE_GODOT_RECOVERY_PARENT_ATTEMPT_ID",
            "SPORESPORE_GODOT_RECOVERY_CHILD_ROLE",
        ):
            self.assertIn(token, child)
        self.assertNotIn("$script:EnvironmentNames +=", child)
        self.assertLess(
            child.index("Get-QsdkR10fL15ContextEnvironment"),
            child.index("$run = Invoke-SporeSporeGodotReceiptTerminatedProcess"),
        )

    def test_supervisor_never_claims_zero_after_a_consumed_attempt_is_uncertain(
        self,
    ) -> None:
        self.assertIn(
            "$script:PhysicalAttemptIdentityConsumed = $true", self.supervisor
        )
        catch = self.supervisor[
            self.supervisor.index("} catch {\n    $supervisorError") :
        ]
        self.assertIn("$postAttemptUnknown", catch)
        self.assertIn("$refusalLedgerAuthorityMode = if ($postAttemptUnknown)", catch)
        self.assertIn(
            "ledger_scope = Get-R10fLedgerScope $refusalLedgerAuthorityMode",
            catch,
        )
        self.assertNotIn("ledger_scope = Get-R10fLedgerScope (", catch)
        self.assertIn(
            "Get-L9ObservedCounterProjection -ChildEnvelopes $observedChildren", catch
        )
        self.assertIn(
            "count_fields_known = [bool]$observedCounts.core_count_fields_known", catch
        )
        self.assertIn(
            "model_construction_count = $observedCounts.model_construction_count", catch
        )
        self.assertIn(
            "physics_state_modified = $observedCounts.physics_state_modified", catch
        )
        counter_projection = powershell_function(
            self.supervisor, "Get-L9ObservedCounterProjection"
        )
        self.assertIn("$known = $ChildEnvelopes.Count -gt 0", counter_projection)
        self.assertIn(
            "$values[$outputName] = if ($known) { $total } else { -1 }",
            counter_projection,
        )
        self.assertIn('"terminal_supervisor_failure.json"', catch)
        self.assertIn(
            "def validate_l9_terminal_supervisor_failure(", self.physical_closure
        )
        self.assertIn(
            '== "sporespore_qsdk_r10f_supervisor_refusal_v1"',
            self.physical_closure,
        )
        self.assertIn(
            'observed_document.get("physical_attempt_identity_consumed") is True',
            self.physical_closure,
        )
        self.assertIn(
            "normalized_report, outcome = validate_l9_terminal_supervisor_failure(",
            self.physical_closure,
        )

    def test_machine_readable_campaign_records_expose_ledger_scope(self) -> None:
        for gd_function in (
            function(self.worker, "_finalize_valid_result_v1"),
            function(self.worker, "_abort"),
        ):
            self.assertIn('"ledger_scope":', gd_function)
            self.assertIn('"question_class": "development"', gd_function)
        for source in (
            self.supervisor,
            self.qualification,
            self.materializer,
            self.physical_closure,
        ):
            self.assertIn("ledger_scope", source)
            self.assertIn("question_class", source)

    def test_qualification_wrapper_has_no_physical_entrypoint(self) -> None:
        for forbidden in (
            "RunPhysical",
            'ValidateSet("Preflight", "Physical")',
            "Invoke-SporeSporeGodotReceiptTerminatedProcess",
            "apply_central_impulse",
            "physical_execution_authorized = $true",
        ):
            self.assertNotIn(forbidden, self.qualification)
        self.assertIn(
            '"--official-qualification"',
            self.qualification,
        )
        self.assertIn("physical_execution_authorized = $false", self.qualification)

    def test_qualification_consumes_durable_identity_before_audit(self) -> None:
        create_root = self.qualification.index(
            "$null = [IO.Directory]::CreateDirectory($qualificationRoot)"
        )
        consume = self.qualification.index("Write-JsonCreateNew $attemptPath $attempt")
        audit = self.qualification.index("$execution = Invoke-CapturedProcess")
        self.assertLess(create_root, consume)
        self.assertLess(consume, audit)
        self.assertIn("FileMode]::CreateNew", self.qualification)
        self.assertIn("same_identity_rerun_permitted = $false", self.qualification)
        self.assertNotIn("Remove-Item", self.qualification)

    def test_future_authority_tools_have_zero_world_self_tests(self) -> None:
        for source, marker in (
            (
                self.materializer,
                "QSDK_R10F_AUTHORITY_MATERIALIZER_SELF_TEST_PASS",
            ),
            (
                self.physical_closure,
                "QSDK_R10F_PHYSICAL_CLOSURE_SELF_TEST_PASS",
            ),
        ):
            self.assertIn(marker, source)
            self.assertIn('subparsers.add_parser("self-test")', source)
            self.assertIn('"model_construction_count": 0', source)
            self.assertIn('"solver_step_count": 0', source)
        self.assertIn("qsdk_r10f_authority_materializer.py", self.implementation_audit)
        self.assertIn("qsdk_r10f_physical_closure.py", self.implementation_audit)
        counter_invariant = python_function(
            self.physical_closure, "validate_solver_counter_invariant"
        )
        for token in (
            '"sporespore_qsdk_r10f_collection_solver_counter_projection_v1"',
            'projection.get("cumulative_solver_step_count")',
            'projection.get("retained_global_cumulative_solver_step_count")',
            'projection.get("completed_step_delta"), 1',
            'projection.get("outcome_derived_correction") is False',
            'predicates.get("collector_global_counter_binding_exact") is True',
        ):
            self.assertIn(token, counter_invariant)
        arm_validator = python_function(
            self.physical_closure, "validate_l9_child_report"
        )
        for token in (
            "validate_solver_counter_invariant(",
            "validate_l9_terminal_receipt(",
            "validate_l9_release_receipt(",
            "validate_l12_walking_handoff_population(",
            "validate_l9_interaction_source(",
            'arm.get("trace_sha256") == canonical_sha256_v1(trace)',
            'report.get("configuration_sha256") == canonical_sha256_v1(configuration)',
        ):
            self.assertIn(token, arm_validator)
        self.assertIn(
            "rejected == len(mutation_specs) == 39",
            self.physical_closure,
        )
        self.assertIn(
            "semantic_release_rejections == len(semantic_release_mutations) == 4",
            self.physical_closure,
        )
        self.assertIn(
            '"release_owner_source_mutation_rejection_count"',
            self.physical_closure,
        )
        self.assertIn(
            '"walking_actuation_handoff_mutation_rejection_count"',
            self.physical_closure,
        )
        pair_validator = python_function(
            self.physical_closure, "validate_l9_pair_from_children"
        )
        for token in (
            '"valid_complete_precondition_diagnostic_no_r10f_behavioral_outcome"',
            "vector_close(active_forward, baseline_forward, VECTOR_ALLOWANCE)",
            "paired_magnitude >= NATIVE_EFFECT_FLOOR_M_S",
            '"matched_no_kick_delta_subtracted": True',
        ):
            self.assertIn(token, pair_validator)
        artifact_validator = python_function(
            self.physical_closure, "validate_l9_child_artifact_files"
        )
        for token in (
            '"child_attempt_identity.json"',
            '"worker.stdout.txt"',
            '"termination_receipt.json"',
            '"engine_health.json"',
            '"child_envelope.json"',
            "project_l9_engine_health(stderr)",
            'logged_raw == envelope.get("report")',
        ):
            self.assertIn(token, artifact_validator)

    def test_qualification_wrapper_consumes_complete_nested_receipts(self) -> None:
        from sdk.conformance import (
            qsdk_r10f_zero_world_implementation as implementation,
        )

        failure = implementation.audit_predecessor_qualification_failure()
        self.assertEqual(failure["retained_file_count"], 4)
        closure = json.loads(
            implementation.QUALIFICATION_FAILURE_CLOSURE_PATH.read_text()
        )
        historical = implementation.parse_marker(
            (
                Path(closure["retained_evidence"]["root"]) / "qualification_stdout.log"
            ).read_text(),
            implementation.PASS_MARKER,
            "UNIT_RETAINED_QUALIFICATION_FAILURE",
        )
        self.assertNotIn("scene_tree_insertion_count", historical["root_design_audit"])
        # This is an in-memory reporting fixture, not a rewritten old receipt.
        historical["root_design_audit"]["scene_tree_insertion_count"] = 0
        historical["root_design_audit"][
            "scene_tree_counter_source"
        ] = "successor_zero_world_projection_after_complete_historical_validation"
        historical["predecessor_qualification_failure_closure_raw_sha256"] = (
            implementation.EXPECTED_QUALIFICATION_FAILURE_CLOSURE_SHA256
        )
        historical["predecessor_qualification_failure_audit"] = failure
        # Project the new authority/coverage envelope only in this declared
        # synthetic consumer fixture. Never write or promote the retained report.
        historical["repair_id"] = implementation.REPAIR_ID
        historical["repair_design_raw_sha256"] = (
            implementation.EXPECTED_REPAIR_DESIGN_SHA256
        )
        historical["branch_completeness_addendum_sha256"] = (
            implementation.EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        )
        historical["consumed_predecessor_physical_closure_sha256"] = (
            implementation.EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        )
        historical["root_design_audit"][
            "successor_authorization_repair_id"
        ] = "QSDK-R10F-L13"
        historical["root_design_audit"]["active_repair_id"] = implementation.REPAIR_ID
        historical["l14_component_qualification"] = (
            implementation.l14_components.expected_receipt()
        )
        historical["runtime_identity"]["l14_exact_runtime_images"] = (
            implementation.l14_runtime.historical_expected_binding()
        )
        # This fixture audits the fixed v1 wrapper and its 67 v1 runtime
        # corruptions. Keep that synthetic generation coherent after host
        # succession; current-image reopening and stale qualification refusal
        # have their own real-interface tests. No retained bytes are changed.
        from unittest import mock
        with mock.patch.object(
            implementation.l14_runtime, "expected_binding",
            implementation.l14_runtime.historical_expected_binding,
        ):
            proof = implementation.audit_qualification_receipt_contract(historical)
        self.assertEqual(proof["positive_control_count"], 1)
        self.assertEqual(proof["mutation_rejection_count"], 335)
        self.assertEqual(proof["preserved_historical_corruption_count"], 86)
        self.assertEqual(proof["l14_component_corruption_count"], 176)
        self.assertEqual(proof["l14_runtime_corruption_count"], 67)
        self.assertTrue(proof["exact_retained_failure_rejected"])
        self.assertEqual(proof["solver_step_count"], 0)

    def test_passed_l14_qualification_retirement_and_actual_directory_reader(self):
        from sdk.conformance import qsdk_r10f_authority_materializer as materializer
        from sdk.conformance import qsdk_r10f_l14_qualification_pipeline as pipeline

        retirement = pipeline.audit_retirement()
        self.assertTrue(retirement["qualification_preserved_passing"])
        self.assertTrue(retirement["frozen_original_reader_predicate_refusal_reproduced"])
        self.assertEqual(retirement["retained_file_count"], 6)
        self.assertEqual(retirement["retained_total_byte_length"], 95_755)
        self.assertEqual(retirement["mutation_rejection_count"], 6)
        receipt = materializer.read_json(
            materializer.qualification_directory(pipeline.SOURCE) / "implementation_audit.json",
            "RETIRED_READER_FIXTURE",
        )
        # This standalone fixture projects only today's manifest envelope in
        # memory. The complete audit separately feeds its newly produced real
        # receipt into the same whole-directory reader before it can pass.
        _, policy = materializer.manifest_binding()
        receipt["qualified_source_path_count"] = policy["count"]
        receipt["qualified_source_path_sha256"] = policy["digest"]
        receipt["dependency_manifest_raw_sha256"] = materializer.sha256_file(materializer.MANIFEST_PATH)
        # The complete-directory fixture already substitutes image reopening.
        # Make its substituted image population match this retained v1 receipt,
        # instead of mixing the current v2 host into a historical positive.
        from unittest import mock
        with mock.patch.object(
            materializer.l14_runtime, "expected_binding",
            materializer.l14_runtime.historical_expected_binding,
        ):
            proof = pipeline.audit_reader_contract(receipt)
        self.assertEqual(proof["positive_control_count"], 1)
        self.assertEqual(proof["mutation_rejection_count"], 7)
        self.assertTrue(proof["actual_receipt_source_flags_preserved"])
        self.assertFalse(proof["official_or_physical_identity_created"])

    def test_root_design_freeze_binding_preserves_history_and_exact_successor(
        self,
    ) -> None:
        from sdk.conformance import qsdk_r10f_authority_materializer as materializer
        from sdk.conformance import (
            qsdk_r10f_zero_world_implementation as implementation,
        )

        proof = implementation.audit_source_authority_preflight(
            require_l15_sources=True
        )
        self.assertTrue(proof["exact_historical_materializer_refusal_reproduced"])
        self.assertEqual(proof["production_source_binding_function_count"], 8)
        self.assertEqual(proof["historical_root_authority_count"], 15)
        self.assertEqual(proof["retired_qualification_retained_byte_length"], 63609)
        self.assertEqual(proof["l15_root_source_binding"]["source_pair_count"], 2)
        self.assertFalse(proof["whole_route_qualified"])
        self.assertFalse(proof["physical_family_selector_changed"])
        self.assertEqual(
            proof["schema_version"],
            "sporespore_qsdk_r10f_l15_source_authority_preflight_audit_v1",
        )
        # The new mode cannot quietly authorize the legacy L14 source family.
        with self.assertRaisesRegex(
            materializer.MaterializationFailure, "DESIGN_AUTHORITY_7_IDENTITY"
        ):
            materializer.design_binding(materializer.git("rev-parse", "HEAD"))
        root_design = json.loads(materializer.DESIGN_PATH.read_text())
        repair_design = json.loads(
            materializer.HISTORICAL_ADAPTER_PERMISSION_PATH.read_text()
        )
        adapter_path = "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
        authority = next(
            entry
            for entry in root_design["bound_authorities"]
            if entry["path"] == adapter_path
        )
        successor = next(
            entry
            for entry in repair_design["bound_authorities"]
            if entry["role"] == "observed_l12_shared_walking_adapter_source"
        )
        historical_raw = subprocess.run(
            ["git", "cat-file", "blob", authority["git_blob_oid"]],
            cwd=ROOT,
            check=True,
            capture_output=True,
        ).stdout
        source_blob = materializer.git("rev-parse", f"HEAD:{adapter_path}")
        valid = [
            authority,
            successor,
            historical_raw,
            authority["git_blob_oid"],
            source_blob,
            source_blob,
        ]
        materializer.validate_l13_historical_adapter_binding(*valid)
        for index, key, changed in (
            (0, "path", "scripts/unrelated.gd"),
            (0, "raw_sha256", "sha256:" + "0" * 64),
            (0, "git_blob_oid", "0" * 40),
            (1, "role", "unrelated_authority"),
            (1, "checkout_byte_length", 0),
            (2, None, historical_raw[:-1]),
            (3, None, "0" * 40),
            (4, None, "0" * 40),
            (5, None, "0" * 40),
        ):
            mutated = copy.deepcopy(valid)
            if key is None:
                mutated[index] = changed
            else:
                mutated[index][key] = changed
            with self.assertRaises(materializer.MaterializationFailure):
                materializer.validate_l13_historical_adapter_binding(*mutated)
        unchanged_adapter = copy.deepcopy(valid)
        unchanged_adapter[4] = unchanged_adapter[5] = authority["git_blob_oid"]
        with self.assertRaises(materializer.MaterializationFailure):
            materializer.validate_l13_historical_adapter_binding(*unchanged_adapter)

    def test_dependency_manifest_is_unfinalized_or_exactly_finalized(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        policy = manifest["policy"]
        count = policy["expected_qualified_source_count"]
        digest = policy["expected_qualified_source_path_sha256"]
        self.assertEqual(
            manifest["schema_version"],
            "sporespore_qsdk_r10f_dependency_manifest_v19",
        )
        self.assertEqual(manifest["repair_id"], "QSDK-R10F-L14")
        self.assertEqual(
            manifest["status"],
            "prospective_complete_transitive_source_closure_zero_world",
        )
        self.assertEqual(count, 176)
        self.assertEqual(
            digest,
            "sha256:9e933f030936d2cd21b5605afd83af342f875d84178f99f6df38b9395cde429a",
        )
        self.assertIn(
            "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json",
            policy["process_and_audit_paths"],
        )
        self.assertIn(
            "sdk/qsdk_r10f_development_route_ghost_physical_closure_v13.json",
            policy["process_and_audit_paths"],
        )
        self.assertEqual(
            policy["prospective_runtime_authority_paths"],
            [
                "sdk/qsdk_r10f_development_route_ghost_execution_authority_v15.json",
                "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v15.json",
            ],
        )


if __name__ == "__main__":
    unittest.main()
