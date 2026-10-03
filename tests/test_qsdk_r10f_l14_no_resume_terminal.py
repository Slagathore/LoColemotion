"""Seven actual orchestrator branches cross the actual child-data consumer.

Everything below is labeled synthetic source data, not a physical run. The
orchestrator traverses every phase event. Existing native memory shapes are
used only as type-preserving fixture templates, never as new physical results.
"""

from __future__ import annotations

import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_physical_closure as closer
import qsdk_r10f_l14_no_resume_terminal as proof
import qsdk_r10f_l14_child_source_bridge as bridge

GODOT = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r24d157-godot-jolt-rotation-integration-energy-v6\development-cold-build-ed4ec00a\godot.windows.editor.dev.x86_64.console.exe"
)
RETAINED = Path(
    r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\qsdk-r10f-development-route-ghost-30427ba7f22cd306\children\01-matched_no_kick_continuation\worker_report.json"
)
RETAINED_SHA = "1038e6df65338b15de7a83b10456633f6ccf9b8778942f3135ae1f2ff52a7aa6"
MARKER = "QSDK_R10F_L14_NO_RESUME_TERMINAL_ZERO_WORLD "


def identity(report):
    return {
        "expected_role": report["arm_id"],
        "expected_parent_attempt_id": report["parent_attempt_id"],
        "expected_child_attempt_id": report["child_attempt_id"],
        "expected_source_commit": report["source_commit"],
        "expected_authority_sha256": report["authorization_sha256"],
        "expected_worker_process_id": report["process_id"],
    }


def refresh_trace(report):
    arm = report["arm_result"]
    arm["trace_sha256"] = closer.canonical_sha256_v1(arm["trace"])


def refresh_transition(report):
    arm = report["arm_result"]
    transition = arm["terminal_orchestrator_transition"]
    before, event, advance = (
        transition[k] for k in ("state_before", "event", "advance_receipt")
    )
    before["payload_sha256"] = closer.payload_sha256_v1(before)
    event["payload_sha256"] = closer.payload_sha256_v1(event)
    after = advance["state_after"]
    after["payload_sha256"] = closer.payload_sha256_v1(after)
    advance.update(
        state_before_sha256=before["payload_sha256"],
        event_sha256=event["payload_sha256"],
        state_after_sha256=after["payload_sha256"],
    )
    arm["final_orchestrator_state"] = copy.deepcopy(after)


class NoResumeTerminal(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        started = time.perf_counter()
        cls.base_supervisor = closer.l9_synthetic_supervisor("behavior_positive")
        cls.base = cls.base_supervisor["child_envelopes"][1]["report"]
        run = subprocess.run(
            [
                str(Path(os.environ.get("SPORESPORE_L14_GODOT_EXECUTABLE", GODOT))),
                "--headless",
                "--path",
                str(ROOT),
                "--script",
                "res://tests/test_sdk_qsdk_r10f_l14_no_resume_terminal_zero_world.gd",
                "--",
                "--configuration-sha256=" + cls.base["configuration_sha256"],
            ],
            cwd=ROOT,
            text=True,
            encoding="utf-8",
            capture_output=True,
            timeout=300,
        )
        if run.returncode or "ERROR:" in run.stdout + run.stderr:
            raise AssertionError(
                "L14_GDSCRIPT_NO_RESUME_FAILED:" + run.stderr + run.stdout[:3000]
            )
        found = [
            line[len(MARKER) :]
            for line in run.stdout.splitlines()
            if line.startswith(MARKER)
        ]
        assert len(found) == 1, "ONE_SOURCE_FIXTURE_RECEIPT_REQUIRED"
        cls.receipt = json.loads(found[0])
        assert cls.receipt["ok"] is True, cls.receipt
        assert cls.receipt["source_only_terminal_branch_count"] == 7
        original = RETAINED.read_bytes()
        assert hashlib.sha256(original).hexdigest() == RETAINED_SHA
        cls.native_template = json.loads(original)["arm_result"][
            "recovery_step_receipts"
        ][-1]
        cls.reports = {
            case["case_id"]: cls.make_report(case) for case in cls.receipt["cases"]
        }
        assert hashlib.sha256(RETAINED.read_bytes()).hexdigest() == RETAINED_SHA
        print(
            "L14_ACTUAL_ORCHESTRATOR_AND_RETENTION_PASS branches=7 zero_world=true elapsed_s="
            + str(round(time.perf_counter() - started, 3)),
            flush=True,
        )

    @classmethod
    def make_report(cls, case):
        report = copy.deepcopy(cls.base)
        arm = report["arm_result"]
        transition = copy.deepcopy(case["terminal_orchestrator_transition"])
        event = transition["event"]
        after = transition["advance_receipt"]["state_after"]
        count = after["total_completed_solver_step_count"]
        epoch = after["epoch_start_global_step"]
        rows, invariants = closer.l9_synthetic_solver_receipts(
            report["arm_id"], arm["body_population_instance_sha256"], count
        )
        for index, row in enumerate(rows, 1):
            row.update(
                schema_version="sporespore_qsdk_r10f_compact_native_trace_row_v1",
                arm_id=report["arm_id"],
                orchestrator_phase=(
                    proof.PRECONDITION if index < 3 else proof.INTERACTION
                ),
                recovery_epoch_local_step=None if index < epoch else index - epoch,
                walking_segment_id="",
                walking_session_id="",
                walking_session_local_step=0,
            )
        rows[2 : epoch - 1] = copy.deepcopy(cls.receipt["prefix"]["rows"])
        recovery_steps = [
            copy.deepcopy(
                report["precondition_terminal_receipt"]["recovery_step_receipt"]
            )
        ]
        for observed in case["source_phase_observations"]:
            global_step = observed["global_semantic_step"]
            last = global_step == count
            row = rows[global_step - 1]
            source_phase = observed["source_phase"]
            prior_phase = (
                "confirm_prone"
                if source_phase == proof.CONFIRM
                else "establish_distal_support"
            )
            native_step = copy.deepcopy(cls.native_template)
            memory = native_step["memory"]
            terminal_phase = event["recovery_controller_terminal_phase"] if last else ""
            memory.update(
                phase=terminal_phase or prior_phase,
                terminal_failure_code=(
                    event["recovery_controller_terminal_reason"]
                    if last and terminal_phase in {"failed", "refused"}
                    else None
                ),
                last_semantic_step=float(global_step),
                start_semantic_step=float(epoch + 1),
                total_steps_observed=float(global_step - epoch),
            )
            classification = native_step["classification"]
            classification.update(
                stable_stance_gate=last and event["stable_four_foot_stance"],
                entry_prone_gate=observed["prone_sample"],
            )
            native_step.update(
                next_phase=memory["phase"],
                prior_phase=prior_phase,
                prone_to_standing_claimed=False,
            )
            row.update(
                orchestrator_phase=source_phase,
                application_phase=prior_phase,
                control_owner="recovery_v6",
                no_actuation_requested=True,
                recovery_classification=copy.deepcopy(classification),
            )
            if last:
                sources = case["terminal_recovery_observation_sources"]
                row["application_intent_sha256"] = event["application_intent_sha256"]
                row["observation_sha256"] = closer.canonical_sha256_v1(
                    sources["global_observation"]
                )
                native_step["observation_sha256"] = closer.canonical_sha256_v1(
                    sources["bound_recovery_observations"]["observation_v3"]
                )
            recovery_steps.append(native_step)
        interaction_source = copy.deepcopy(
            cls.receipt["interaction_source_build"]["source"]
        )
        report.update(
            role_outcome="behavior_negative",
            reached_walking_resume=False,
            reached_post_kick_recovery=after["post_kick_recovery_step_count"] > 0,
            solver_step_count=count,
            global_solver_frame_count=count,
            in_run_invariant_receipt_count=count,
            event_triggered_passive_recovery_observed=False,
            recovery_success_observed=False,
            interaction_source=interaction_source,
            interaction_source_sha256=interaction_source["payload_sha256"],
        )
        arm.update(
            walking_sessions=[copy.deepcopy(cls.receipt["prefix"]["session"])],
            walking_actuation_handoff_receipts=arm[
                "walking_actuation_handoff_receipts"
            ][:1],
            interaction_source=copy.deepcopy(interaction_source),
            interaction_receipt=copy.deepcopy(cls.receipt["interaction_receipt"]),
            outer_step_count=count,
            native_solver_step_count=count,
            in_run_invariant_receipt_count=count,
            in_run_invariant_receipts=invariants,
            recovery_step_receipts=recovery_steps,
            final_recovery_memory=copy.deepcopy(recovery_steps[-1]["memory"]),
            final_orchestrator_state=copy.deepcopy(after),
            final_phase="failed",
            terminal_reason=after["terminal_reason"],
            terminal_orchestrator_transition=transition,
            terminal_recovery_observation_sources=copy.deepcopy(
                case["terminal_recovery_observation_sources"]
            ),
        )
        arm["trace"]["rows"] = rows
        refresh_trace(report)
        return report

    def check(self, report):
        return closer.validate_l9_child_report(report, **identity(report))

    def refused(self, report):
        with self.assertRaises(closer.ClosureFailure):
            self.check(report)

    def powershell_consumer(self, request, mode="Child"):
        run = subprocess.run(
            [
                "pwsh",
                "-NoProfile",
                "-File",
                str(ROOT / "tests/test_qsdk_r10f_l14_pair_source_bridge.ps1"),
                "-Mode",
                mode,
            ],
            cwd=ROOT,
            input=json.dumps(request, separators=(",", ":")),
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=180,
        )
        self.assertEqual(run.returncode, 0, run.stderr + run.stdout[:3000])
        self.assertEqual(run.stderr, "")
        marker = "QSDK_R10F_L14_PAIR_SOURCE_BRIDGE_ZERO_WORLD "
        lines = [
            line[len(marker) :]
            for line in run.stdout.splitlines()
            if line.startswith(marker)
        ]
        self.assertEqual(len(lines), 1, run.stdout[:3000])
        receipt = json.loads(lines[0])
        self.assertFalse(receipt["source_object_changed"])
        self.assertFalse(receipt["physical_execution_authorized"])
        for key in (
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "scene_tree_insertion_count",
            "native_readback_count",
            "solver_step_count",
        ):
            self.assertIs(type(receipt[key]), int)
            self.assertEqual(receipt[key], 0)
        return receipt["result"]

    def test_actual_powershell_child_consumer_accepts_all_seven_source_proven_branches(
        self,
    ):
        for name, report in self.reports.items():
            with self.subTest(branch=name):
                request = {
                    "schema_version": bridge.REQUEST_SCHEMA,
                    "report": report,
                    "expected_identity": identity(report),
                }
                result = self.powershell_consumer(request)
                self.assertTrue(result["ok"], result)
                self.assertEqual(result["walking_actuation_handoff_count"], 1)
                self.assertTrue(
                    proof.same_source_value(
                        result["no_resume_terminal"],
                        self.check(report)["no_resume_terminal"],
                    )
                )

    def population_request(self, report):
        envelopes = copy.deepcopy(self.base_supervisor["child_envelopes"])
        envelopes[1]["report"] = copy.deepcopy(report)
        return {
            "child_envelopes": envelopes,
            "expected_parent_attempt_id": self.base_supervisor["attempt_id"],
            "expected_source_commit": self.base_supervisor["source_commit"],
            "expected_authority_sha256": self.base_supervisor["authority_sha256"],
        }

    def supervisor_from_population(self, request, population):
        """Declare a source fixture using the actual pair result and counters."""
        supervisor = copy.deepcopy(self.base_supervisor)
        supervisor["child_envelopes"] = copy.deepcopy(request["child_envelopes"])
        supervisor["process_population_evaluation"] = copy.deepcopy(population)
        for key in (
            "ok",
            "status",
            "evidence_valid",
            "measurement_complete",
            "route_execution_valid",
            "outcome_complete",
            "behavior_passed",
            "scientific_outcome",
            "failure_code",
            "evaluator_invocation_count",
        ):
            supervisor[key] = population[key]
        counts = closer.l9_observed_counter_projection(supervisor["child_envelopes"])
        for key in (
            "model_construction_attempt_count",
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "solver_step_count",
            "explicit_worker_extra_native_readback_count",
            "physics_state_modified",
        ):
            supervisor[key] = counts[key]
        supervisor["observed_completed_child_count_fields_known"] = counts["core_known"]
        supervisor["observed_count_field_known"] = counts["known"]
        supervisor["event_triggered_passive_recovery_observed"] = population[
            "behavior_passed"
        ]
        supervisor["continuous_same_body_recovery_resume_observed"] = population[
            "behavior_passed"
        ]
        return supervisor

    def build_declared_closure_fixture(self, supervisor, outcome):
        # Only the future on-disk Git authority graph is a declared fixture.
        # Actual report validation and closure construction run. No prospective
        # file is written, and this object is not retained as physical evidence.
        offered = copy.deepcopy(outcome)
        offered["authority"] = {
            "synthetic_zero_world_graph_fixture": True,
            "l14_component_qualification": closer.l14_components.expected_receipt(),
            "l14_exact_runtime_images": closer.l14_runtime.expected_binding(),
        }
        offered["evidence_bindings"] = {}
        graph = {
            "stage_commit": "a" * 40,
            "authority_commit": "b" * 40,
            "closure_audit_commit": "c" * 40,
        }
        with mock.patch.object(
            closer, "validate_l9_live_authority_graph", return_value=graph
        ):
            return closer.build_l9_closure(
                ROOT / "synthetic_no_file_created_supervisor_result.json",
                supervisor,
                offered,
            )

    def test_actual_powershell_population_keeps_all_seven_complete_negatives(self):
        for name, report in self.reports.items():
            with self.subTest(branch=name):
                request = self.population_request(report)
                result = self.powershell_consumer(request, "Population")
                self.assertTrue(result["ok"], result)
                self.assertTrue(result["evidence_valid"])
                self.assertTrue(result["route_execution_valid"])
                self.assertTrue(result["outcome_complete"])
                self.assertFalse(result["behavior_passed"])
                self.assertEqual(result["scientific_outcome"], "negative")
                self.assertEqual(result["evaluator_invocation_count"], 1)
                self.assertEqual(
                    [
                        child["walking_actuation_handoff_count"]
                        for child in result["child_validations"]
                    ],
                    [2, 1],
                )
                children = [
                    closer.validate_l9_child_envelope(
                        envelope,
                        descriptor,
                        parent_attempt_id=request["expected_parent_attempt_id"],
                        source_commit=request["expected_source_commit"],
                        authority_sha256=request["expected_authority_sha256"],
                        verify_files=False,
                    )
                    for envelope, descriptor in zip(
                        request["child_envelopes"],
                        self.base_supervisor["ordered_child_manifest"],
                    )
                ]
                expected_pair = closer.validate_l9_pair_from_children(
                    children[0]["child"], children[1]["child"]
                )
                arguments = {
                    "source_commit": request["expected_source_commit"],
                    "authority_sha256": request["expected_authority_sha256"],
                    "parent_attempt_id": request["expected_parent_attempt_id"],
                }
                closer.validate_l9_population_projection(
                    result, children, expected_pair, **arguments
                )
                supervisor = self.supervisor_from_population(request, result)
                outcome = closer.validate_l9_report(
                    supervisor, report_path=None, verify_files=False
                )
                summary = self.build_declared_closure_fixture(supervisor, outcome)
                self.assertEqual(
                    summary["schema_version"],
                    "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v15",
                )
                self.assertEqual(summary["walking_actuation_handoff_receipt_count"], 3)
                self.assertEqual(
                    summary[
                        "walking_actuation_handoff_expected_count_for_complete_route"
                    ],
                    3,
                )
                self.assertTrue(summary["walking_actuation_handoff_observed"])
                self.assertTrue(summary["source_proven_no_resume_negative_observed"])
                self.assertFalse(summary["behavior_passed"])
                self.assertFalse(
                    summary["continuous_same_body_recovery_resume_observed"]
                )
                self.assertFalse(summary["event_triggered_passive_recovery_observed"])
                self.assertFalse(summary["distinct_held_out_successor_may_be_declared"])
                self.assertFalse(summary["sdk1_m07_satisfied"])
                self.assertFalse(summary["physical_acceptance_authority"])
                self.assertFalse(summary["release_authority"])
                self.assertEqual(
                    summary["branch_completeness_addendum_sha256"],
                    closer.EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
                )
                for defect in (
                    "missing_peer",
                    "wrong_segment",
                    "floating_count",
                    "extra_step",
                    "invented_success",
                ):
                    changed_outcome = copy.deepcopy(outcome)
                    if defect == "missing_peer":
                        changed_outcome["child_projections"].pop(closer.BASELINE_ARM)
                    elif defect == "invented_success":
                        changed_outcome["behavior_passed"] = True
                    else:
                        handoffs = changed_outcome["child_projections"][
                            closer.ACTIVE_ARM
                        ]["walking_actuation_handoffs"]
                        if defect == "wrong_segment":
                            handoffs["ordered_evaluation_segments"] = ["walking_resume"]
                        elif defect == "floating_count":
                            handoffs["handoff_count"] = 1.0
                        else:
                            handoffs["extra_solver_step_count"] = 1
                    with self.assertRaises(closer.ClosureFailure):
                        closer.l14_handoff_closure_projection(changed_outcome)
                for mutation in (
                    "missing_proof",
                    "floating_clock",
                    "invented_success",
                    "wrong_handoff_count",
                ):
                    changed = copy.deepcopy(result)
                    active = changed["child_validations"][1]
                    if mutation == "missing_proof":
                        active.pop("no_resume_terminal")
                    elif mutation == "floating_clock":
                        active["no_resume_terminal"][
                            "terminal_global_semantic_step"
                        ] = float(
                            active["no_resume_terminal"][
                                "terminal_global_semantic_step"
                            ]
                        )
                    elif mutation == "invented_success":
                        active["no_resume_terminal"]["recovery_success_observed"] = True
                    else:
                        active["walking_actuation_handoff_count"] = 2
                    with self.assertRaisesRegex(
                        closer.ClosureFailure, "POPULATION_CHILD_VALIDATIONS"
                    ):
                        closer.validate_l9_population_projection(
                            changed, children, expected_pair, **arguments
                        )
        for case in ("behavior_positive", "behavior_negative", "precondition_negative"):
            supervisor = closer.l9_synthetic_supervisor(case)
            outcome = closer.validate_l9_report(
                supervisor, report_path=None, verify_files=False
            )
            summary = self.build_declared_closure_fixture(supervisor, outcome)
            self.assertFalse(summary["source_proven_no_resume_negative_observed"])
            expected = None if case == "precondition_negative" else 4
            self.assertEqual(
                summary["walking_actuation_handoff_expected_count_for_complete_route"],
                expected,
            )
            self.assertEqual(
                summary["walking_actuation_handoff_observed"], expected is not None
            )

    def test_actual_powershell_child_refuses_damaged_proof_and_extra_resume_bypass(
        self,
    ):
        for mutation in (
            "missing_transition",
            "missing_observations",
            "floating_host_clock",
            "incomplete_prefix",
            "extra_session_claimed_resumed",
            "infrastructure_refusal",
            "fabricated_positive",
        ):
            with self.subTest(mutation=mutation):
                report = copy.deepcopy(self.reports["recovery_failed"])
                arm = report["arm_result"]
                if mutation == "missing_transition":
                    arm.pop("terminal_orchestrator_transition")
                elif mutation == "missing_observations":
                    arm.pop("terminal_recovery_observation_sources")
                elif mutation == "floating_host_clock":
                    event = arm["terminal_orchestrator_transition"]["event"]
                    event["global_semantic_step"] = float(event["global_semantic_step"])
                    refresh_transition(report)
                elif mutation == "incomplete_prefix":
                    arm["walking_sessions"][0]["step_receipt_sha256s"].pop()
                elif mutation == "extra_session_claimed_resumed":
                    arm["walking_sessions"].append(
                        copy.deepcopy(self.base["arm_result"]["walking_sessions"][1])
                    )
                    arm["walking_actuation_handoff_receipts"].append(
                        copy.deepcopy(
                            self.base["arm_result"][
                                "walking_actuation_handoff_receipts"
                            ][1]
                        )
                    )
                    report["reached_walking_resume"] = True
                elif mutation == "infrastructure_refusal":
                    arm["recovery_step_receipts"][-1]["support_status"] = "refused"
                else:
                    report["role_outcome"] = "behavior_positive"
                request = {
                    "schema_version": bridge.REQUEST_SCHEMA,
                    "report": report,
                    "expected_identity": identity(report),
                }
                result = self.powershell_consumer(request)
                self.assertFalse(result["ok"])
                self.assertTrue(
                    any(
                        error.startswith("CHILD_L14_NO_RESUME_SOURCE_INVALID:")
                        for error in result["validation_errors"]
                    ),
                    result,
                )
                self.assertEqual(result["no_resume_terminal"], {})

    def test_actual_powershell_population_refuses_unhealthy_or_missing_peer(self):
        report = self.reports["recovery_refused"]
        for field, replacement in (
            ("engine_health_passed", False),
            ("raw_marker_valid", False),
            ("termination_protocol_valid", False),
            ("exit_code", 1),
            ("child_retry_count", 1),
            ("child_replacement_count", 1),
            ("missing_peer", None),
        ):
            with self.subTest(field=field):
                request = self.population_request(report)
                if field == "missing_peer":
                    request["child_envelopes"].pop(0)
                else:
                    request["child_envelopes"][1][field] = replacement
                result = self.powershell_consumer(request, "Population")
                self.assertFalse(result["ok"])
                self.assertFalse(result["route_execution_valid"])
                self.assertFalse(result["behavior_passed"])
                self.assertEqual(result["scientific_outcome"], "none")
                self.assertEqual(result["evaluator_invocation_count"], 0)

    def test_child_bridge_requires_the_complete_request_identity_and_no_resume_proof(
        self,
    ):
        report = self.reports["confirm_failed"]
        request = {
            "schema_version": bridge.REQUEST_SCHEMA,
            "report": copy.deepcopy(report),
            "expected_identity": identity(report),
        }
        result = bridge.validate_request(request)
        self.assertTrue(result["whole_child_source_validation_passed"])
        self.assertTrue(result["process_health_and_peer_validation_still_required"])
        for key in request:
            changed = copy.deepcopy(request)
            changed.pop(key)
            with self.assertRaises(closer.ClosureFailure):
                bridge.validate_request(changed)
        for key in request["expected_identity"]:
            changed = copy.deepcopy(request)
            changed["expected_identity"].pop(key)
            with self.assertRaises(closer.ClosureFailure):
                bridge.validate_request(changed)
        changed = copy.deepcopy(request)
        changed["expected_identity"]["expected_worker_process_id"] = float(
            report["process_id"]
        )
        with self.assertRaises(closer.ClosureFailure):
            bridge.validate_request(changed)
        changed = copy.deepcopy(request)
        changed["report"] = copy.deepcopy(self.base)
        changed["expected_identity"] = identity(self.base)
        with self.assertRaisesRegex(closer.ClosureFailure, "NO_RESUME_PROOF_REQUIRED"):
            bridge.validate_request(changed)

    def test_seven_actual_terminal_branches_cross_complete_child_consumer(self):
        for name, report in self.reports.items():
            with self.subTest(branch=name):
                original = copy.deepcopy(report)
                result = self.check(report)
                self.assertTrue(proof.same_source_value(original, report))
                self.assertEqual(result["walking"]["session_count"], 1)
                self.assertEqual(
                    result["walking_actuation_handoffs"]["handoff_count"], 1
                )
                self.assertTrue(
                    result["no_resume_terminal"]["source_proven_no_resume_negative"]
                )
                self.assertFalse(
                    result["no_resume_terminal"]["recovery_success_observed"]
                )
                self.assertFalse(result["physical_acceptance_authority"])
        for key in proof.PURE_ZERO_KEYS | {"scene_tree_insertion_count"}:
            self.assertIs(type(self.receipt[key]), int)
            self.assertEqual(self.receipt[key], 0)

    def test_every_transition_state_event_and_advance_field_is_required(self):
        base = self.reports["recovery_failed"]
        for group in ("state_before", "event", "advance_receipt"):
            for key in base["arm_result"]["terminal_orchestrator_transition"][group]:
                with self.subTest(group=group, field=key):
                    candidate = copy.deepcopy(base)
                    del candidate["arm_result"]["terminal_orchestrator_transition"][
                        group
                    ][key]
                    self.refused(candidate)
        for key in (
            "terminal_orchestrator_transition",
            "terminal_recovery_observation_sources",
            "final_recovery_memory",
            "final_orchestrator_state",
            "recovery_step_receipts",
        ):
            candidate = copy.deepcopy(base)
            del candidate["arm_result"][key]
            self.refused(candidate)

    def test_rehashed_state_event_and_advance_corruption_is_rejected(self):
        mutations = (
            ("state_before", "attempt_id", "crossed-child"),
            ("state_before", "frozen_configuration_sha256", "sha256:" + "a" * 64),
            ("state_before", "body_population_instance_sha256", "sha256:" + "a" * 64),
            ("state_before", "phase", proof.PREFIX),
            ("state_before", "terminal_outcome", "complete"),
            ("state_before", "walking_resume_step_count", 1),
            ("state_before", "resume_or_continuation_session_id", "hidden-resume"),
            ("event", "global_semantic_step", 738),
            ("event", "recovery_epoch_local_step", 14),
            ("event", "recovery_controller_terminal_phase", "complete"),
            ("event", "recovery_controller_terminal_reason", "different-failure"),
            ("event", "source_phase", proof.CONFIRM),
            ("event", "source_measurement", False),
            ("event", "force_aware_recovery", True),
            ("event", "physical_acceptance_authority", True),
            ("event", "walking_session_id", "hidden-resume"),
            ("advance_receipt", "next_phase", "complete"),
            ("advance_receipt", "ok", False),
            ("advance_receipt", "input_state_mutated", True),
        )
        for group, key, value in mutations:
            with self.subTest(group=group, field=key):
                candidate = copy.deepcopy(self.reports["recovery_failed"])
                candidate["arm_result"]["terminal_orchestrator_transition"][group][
                    key
                ] = value
                refresh_transition(candidate)
                self.refused(candidate)

    def test_host_counters_never_accept_float_boolean_or_fraction(self):
        base = self.reports["recovery_failed"]
        groups = (
            (
                "state_before",
                proof.COUNTER_KEYS
                | proof.ZERO_STATE_KEYS
                | {"epoch_start_global_step"},
            ),
            ("event", proof.EVENT_COUNTER_KEYS | proof.ZERO_STATE_KEYS),
            ("advance_receipt", proof.PURE_ZERO_KEYS | {"global_semantic_step"}),
        )
        for group, keys in groups:
            for key in keys:
                original = base["arm_result"]["terminal_orchestrator_transition"][
                    group
                ][key]
                for value in (float(original), False, original + 0.5):
                    with self.subTest(group=group, field=key, replacement=value):
                        candidate = copy.deepcopy(base)
                        candidate["arm_result"]["terminal_orchestrator_transition"][
                            group
                        ][key] = value
                        refresh_transition(candidate)
                        self.refused(candidate)

    def test_native_memory_clock_and_source_number_kind_remain_exact(self):
        base = self.reports["recovery_failed"]
        for value, source in ((736.0, 736.0), (736, 736)):
            candidate = copy.deepcopy(base)
            candidate["arm_result"]["final_recovery_memory"][
                "last_semantic_step"
            ] = value
            candidate["arm_result"]["recovery_step_receipts"][-1]["memory"][
                "last_semantic_step"
            ] = source
            self.check(candidate)
        for value, source in (
            (736, 736.0),
            (736.0, 736),
            (True, True),
            (736.5, 736.5),
            (13.0, 13.0),
        ):
            candidate = copy.deepcopy(base)
            candidate["arm_result"]["final_recovery_memory"][
                "last_semantic_step"
            ] = value
            candidate["arm_result"]["recovery_step_receipts"][-1]["memory"][
                "last_semantic_step"
            ] = source
            self.refused(candidate)
        for key, value in (
            ("start_semantic_step", 1.0),
            ("total_steps_observed", 736.0),
        ):
            candidate = copy.deepcopy(base)
            candidate["arm_result"]["final_recovery_memory"][key] = value
            candidate["arm_result"]["recovery_step_receipts"][-1]["memory"][key] = value
            self.refused(candidate)

    def test_missing_resume_cannot_forge_a_positive_or_hide_resume_sources(self):
        base = self.reports["recovery_failed"]
        for key, value in (
            ("role_outcome", "behavior_positive"),
            ("reached_walking_resume", True),
            ("reached_interaction", False),
            ("reached_post_kick_recovery", False),
        ):
            candidate = copy.deepcopy(base)
            candidate[key] = value
            self.refused(candidate)
        for key, value in (
            ("walking_segment_id", "walking_resume"),
            ("walking_session_id", "hidden-resume"),
            ("walking_session_local_step", 1),
        ):
            candidate = copy.deepcopy(base)
            candidate["arm_result"]["trace"]["rows"][-2][key] = value
            refresh_trace(candidate)
            self.refused(candidate)
        for defect in (
            "stray_handoff",
            "missing_handoff",
            "wrong_handoff_order",
            "incomplete_prefix",
            "changed_threshold",
            "false_terminal_success",
            "nonterminal_final_state",
            "missing_interaction",
        ):
            with self.subTest(defect=defect):
                candidate = copy.deepcopy(base)
                arm = candidate["arm_result"]
                if defect == "stray_handoff":
                    arm["walking_actuation_handoff_receipts"].append(
                        copy.deepcopy(arm["walking_actuation_handoff_receipts"][0])
                    )
                elif defect == "missing_handoff":
                    arm["walking_actuation_handoff_receipts"] = []
                elif defect == "wrong_handoff_order":
                    arm["walking_actuation_handoff_receipts"][0][
                        "global_semantic_step"
                    ] = 4
                elif defect in {"incomplete_prefix", "changed_threshold"}:
                    evaluation = arm["walking_sessions"][0]["evaluation"]
                    if defect == "incomplete_prefix":
                        evaluation["trace_row_count"] = 719
                    else:
                        evaluation["fixed_thresholds"][
                            "minimum_forward_advance_m"
                        ] = 0.0
                    evaluation["payload_sha256"] = closer.canonical_sha256_v1(
                        dict(evaluation, payload_sha256="")
                    )
                elif defect in {"false_terminal_success", "nonterminal_final_state"}:
                    arm["terminal_orchestrator_transition"]["advance_receipt"][
                        "state_after"
                    ]["phase"] = (
                        "complete"
                        if defect == "false_terminal_success"
                        else proof.RECOVERY
                    )
                    refresh_transition(candidate)
                else:
                    arm["interaction_receipt"] = {}
                self.refused(candidate)

    def test_observation_sources_are_linked_without_equating_distinct_hashes(self):
        base = self.reports["recovery_failed"]
        arm = base["arm_result"]
        self.assertNotEqual(
            arm["trace"]["rows"][-1]["observation_sha256"],
            arm["recovery_step_receipts"][-1]["observation_sha256"],
        )
        for defect in (
            "global_in_place_of_epoch",
            "epoch_in_place_of_global",
            "missing_bound",
            "wrong_base",
            "wrong_event_application",
            "wrong_epoch_clock",
            "classification_copy",
            "memory_copy",
            "initializer_copy",
            "stale_event_digest",
            "stale_before_digest",
            "stale_after_digest",
        ):
            with self.subTest(defect=defect):
                candidate = copy.deepcopy(base)
                arm = candidate["arm_result"]
                sources = arm["terminal_recovery_observation_sources"]
                if defect == "global_in_place_of_epoch":
                    arm["recovery_step_receipts"][-1]["observation_sha256"] = (
                        closer.canonical_sha256_v1(sources["global_observation"])
                    )
                elif defect == "epoch_in_place_of_global":
                    arm["trace"]["rows"][-1]["observation_sha256"] = (
                        closer.canonical_sha256_v1(
                            sources["bound_recovery_observations"]["observation_v3"]
                        )
                    )
                elif defect == "missing_bound":
                    sources.pop("bound_recovery_observations")
                elif defect == "wrong_base":
                    sources["bound_recovery_observations"]["observation_v3"][
                        "semantic_step"
                    ] += 1
                elif defect == "wrong_event_application":
                    sources["application_intent"]["semantic_step"] += 1
                elif defect == "wrong_epoch_clock":
                    sources["bound_recovery_observations"]["epoch_source_binding"][
                        "epoch_local_step"
                    ] += 1
                elif defect == "classification_copy":
                    arm["trace"]["rows"][-1]["recovery_classification"][
                        "entry_prone_gate"
                    ] = True
                elif defect == "memory_copy":
                    arm["final_recovery_memory"]["phase"] = "refused"
                elif defect == "initializer_copy":
                    sources["bound_recovery_observations"]["source_component_receipts"][
                        "epoch_initializer"
                    ]["epoch_start_global_step"] += 1
                elif defect == "stale_event_digest":
                    arm["terminal_orchestrator_transition"]["event"][
                        "payload_sha256"
                    ] = ("sha256:" + "0" * 64)
                elif defect == "stale_before_digest":
                    arm["terminal_orchestrator_transition"]["state_before"][
                        "payload_sha256"
                    ] = ("sha256:" + "0" * 64)
                else:
                    arm["terminal_orchestrator_transition"]["advance_receipt"][
                        "state_after_sha256"
                    ] = ("sha256:" + "0" * 64)
                refresh_trace(candidate)
                self.refused(candidate)

    def test_existing_two_session_and_precondition_populations_remain_exact(self):
        for outcome in ("positive", "behavior_negative", "precondition_negative"):
            for role in closer.ARM_ORDER:
                report = closer.l9_synthetic_child_report(
                    role,
                    "1" * 32,
                    "2" * 32,
                    "3" * 40,
                    "sha256:" + "4" * 64,
                    1234,
                    outcome=outcome,
                )
                result = self.check(report)
                self.assertEqual(
                    result["walking"]["session_count"],
                    0 if outcome == "precondition_negative" else 2,
                )
                self.assertEqual(result["no_resume_terminal"], {})
                if outcome != "precondition_negative":
                    report["arm_result"]["walking_sessions"].pop()
                    report["arm_result"]["walking_actuation_handoff_receipts"].pop()
                    self.refused(report)

    def test_extra_resume_session_cannot_bypass_failed_terminal_proof(self):
        for claimed_resume in (False, True):
            candidate = copy.deepcopy(self.reports["recovery_failed"])
            candidate["reached_walking_resume"] = claimed_resume
            arm = candidate["arm_result"]
            arm["walking_sessions"].append(
                copy.deepcopy(self.base["arm_result"]["walking_sessions"][1])
            )
            arm["walking_actuation_handoff_receipts"].append(
                copy.deepcopy(
                    self.base["arm_result"]["walking_actuation_handoff_receipts"][1]
                )
            )
            self.refused(candidate)

    def test_prefix_completion_and_shutdown_cannot_be_replaced_by_a_green_evaluation(
        self,
    ):
        for defect in (
            "empty_completion",
            "missing_summary",
            "missing_shutdown",
            "wrong_step_count",
            "boolean_step_count",
            "shutdown_not_completed",
            "boolean_destroy_count",
            "missing_step_hash",
        ):
            with self.subTest(defect=defect):
                candidate = copy.deepcopy(self.reports["recovery_failed"])
                prefix = candidate["arm_result"]["walking_sessions"][0]
                completion = prefix["completion_receipt"]
                if defect == "empty_completion":
                    completion.clear()
                elif defect == "missing_summary":
                    completion.pop("adapter_summary")
                elif defect == "missing_shutdown":
                    completion.pop("adapter_shutdown_receipt")
                elif defect in {"wrong_step_count", "boolean_step_count"}:
                    completion["adapter_summary"]["step_count"] = (
                        719 if defect == "wrong_step_count" else True
                    )
                elif defect == "shutdown_not_completed":
                    completion["adapter_shutdown_receipt"][
                        "explicit_shutdown_completed"
                    ] = False
                elif defect == "boolean_destroy_count":
                    completion["adapter_shutdown_receipt"][
                        "native_controller_session_destroy_count"
                    ] = True
                else:
                    prefix["step_receipt_sha256s"].pop()
                self.refused(candidate)
        candidate = copy.deepcopy(self.reports["recovery_failed"])
        completion = candidate["arm_result"]["walking_sessions"][0][
            "completion_receipt"
        ]
        completion["adapter_summary"]["step_count"] = 720.0
        completion["adapter_shutdown_receipt"][
            "native_controller_session_destroy_count"
        ] = 1.0
        unchanged = copy.deepcopy(candidate)
        self.check(candidate)
        self.assertTrue(proof.same_source_value(candidate, unchanged))

    def test_available_application_source_hashes_are_recomputed_after_outer_rehash(
        self,
    ):
        for source_key in ("owner_source_receipt", "motor_population_readback"):
            candidate = copy.deepcopy(self.reports["recovery_failed"])
            arm = candidate["arm_result"]
            application = arm["terminal_recovery_observation_sources"][
                "application_intent"
            ]
            application[source_key + "_sha256"] = "sha256:" + "0" * 64
            digest = closer.canonical_sha256_v1(application)
            arm["terminal_orchestrator_transition"]["event"][
                "application_intent_sha256"
            ] = digest
            arm["trace"]["rows"][-1]["application_intent_sha256"] = digest
            refresh_transition(candidate)
            refresh_trace(candidate)
            self.refused(candidate)

    def test_infrastructure_refused_or_partial_recovery_step_remains_invalid(self):
        for key, value in (
            ("support_status", "refused"),
            ("refusal_reason", "invalid_observation"),
            ("post_step_observation_only", False),
            ("phase_skip_permitted", True),
            ("controller_implemented", False),
            ("synthetic_canary_semantics_executed", True),
        ):
            candidate = copy.deepcopy(self.reports["recovery_refused"])
            candidate["arm_result"]["recovery_step_receipts"][-1][key] = value
            self.refused(candidate)

    def test_failed_child_health_or_missing_peer_cannot_become_route_acceptance(self):
        supervisor = copy.deepcopy(self.base_supervisor)
        envelope = supervisor["child_envelopes"][1]
        descriptor = supervisor["ordered_child_manifest"][1]
        for name, report in self.reports.items():
            envelope["report"] = copy.deepcopy(report)
            for field, value in (
                ("engine_health_passed", False),
                ("raw_marker_valid", False),
                ("termination_protocol_valid", False),
                ("exit_code", 1),
            ):
                candidate = copy.deepcopy(envelope)
                candidate[field] = value
                with self.subTest(branch=name, field=field):
                    result = closer.validate_l9_child_envelope(
                        candidate,
                        descriptor,
                        parent_attempt_id=supervisor["attempt_id"],
                        source_commit=supervisor["source_commit"],
                        authority_sha256=supervisor["authority_sha256"],
                        verify_files=False,
                    )
                    self.assertIsNone(result["child"])
                    self.assertIn(
                        "VALID_CHILD_LAUNCH", result["child_validation_error"]
                    )
            missing = closer.l9_synthetic_population(
                [copy.deepcopy(envelope)],
                supervisor["attempt_id"],
                supervisor["source_commit"],
                supervisor["authority_sha256"],
            )
            self.assertFalse(missing["ok"])
            self.assertFalse(missing["route_execution_valid"])
            self.assertFalse(missing["behavior_passed"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
