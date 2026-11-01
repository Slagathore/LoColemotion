"""Finite arithmetic, denominator, forbidden-execution, and tamper controls."""
import copy
import hashlib
import io
import json
import os
from pathlib import Path
from types import SimpleNamespace
import unittest
import uuid

import mujoco
import numpy as np

from audit_contact_sequence_authority_v1 import Capture, bounded_rows
from contact_sequence_authority_diagnostic_v1 import (
    FEET, JOINT_LIMIT_KIND, control_packet, forecast_cases, forecast_diagnostic,
    forecast_limit_forces, future_input_drift, matched_first_interval, motor_state,
    native_limit_forces, native_summary, population_summary, retained_only,
)
from contact_sequence_authority_task_v1 import (
    FLAGS, PARENT, PARENT_AUDIT, PARENT_RECEIPT, PARENT_SOURCE, TRIALS,
    population, validate_parent_documents,
)
from run_contact_sequence_authority_v1 import validate_status
from test_sequence_authority_v1 import add_contact, fixture


def control():
    names = [name + "_motor" for name in fixture()[3]["joint_ids"]]
    baseline = [dict(actuator_id=name, combined_canonical_target_velocity_rad_s=0.,
                     maximum_target_speed_rad_s=3.5) for name in names]
    limits = [dict(actuator_id=name, maximum_absolute_correction_rad_s=3.5,
                   maximum_slew_per_step_rad_s=.08, previous_applied_correction_rad_s=0.) for name in names]
    sites = [dict(contact_site_id=name.removesuffix("_distal") + "_foot",
                  presence=False, bears_support=False, normal_load_n=None) for name in FEET]
    return dict(outer_step=0, request=dict(state=dict(ordered_contact_observations=sites)),
                resolution_request=dict(provider_request=dict(
                    deterministic_baseline=dict(ordered_commands=baseline),
                    safety_envelope=dict(ordered_actuator_limits=limits))),
                resolution=dict(ordered_commands=[dict(actuator_id=name, applied_correction_rad_s=0.) for name in names]),
                native_targets=[0.] * 8,
                native_observation=dict(qpos=[0., 0., .45, 1., 0., 0., 0.] + [0.] * 8,
                                        qvel=[0.] * 14, time_s=0.))


def raw_motor(packet, velocity=0., force=0.):
    return dict(before_qvel=[0.] * 6 + [velocity] * 8, ctrl=list(packet["target"]),
                actuator_force_nm=[force] * 8)


def selection(refined=False, contact=False):
    best = dict(option=dict(index=0, knots=[[0.] * 8] * 4),
                result=dict(eligible=False, valid_intervals=65, rejection_reasons=["joint_position_margin"]))
    original = dict(best=best, evaluations=[copy.deepcopy(best)], evaluated_candidates=1)
    seed = original
    if refined:
        best2 = copy.deepcopy(best); best2["option"]["index"] = 2
        seed = dict(original=original, best=best2, evaluated_candidates=317,
                    refinement=dict(evaluations=[copy.deepcopy(best2) for _ in range(316)],
                                    result=dict(best=copy.deepcopy(best2), evaluated_candidates=316)))
    if not contact:
        return seed
    best3 = copy.deepcopy(best); best3["option"]["index"] = 3
    return dict(seed_selection=seed, best=best3, evaluated_candidates=seed["evaluated_candidates"] + 102,
                contact_search=dict(evaluations=[copy.deepcopy(best3) for _ in range(102)],
                                    result=dict(best=copy.deepcopy(best3), evaluated_candidates=102)))


def future_inputs():
    start = dict(command=60, baseline=[0.] * 8, speeds=[3.5] * 8)
    packets = {command: dict(command=command, baseline=[.5 * (command - 60)] * 8,
                             speeds=[3.5] * 8, target=[.3] * 8, transferred=command != 62)
               for command in range(60, 63)}
    intervals = [dict(offset=index, target=[.1] * 8) for index in range(3)]
    return start, intervals, packets


def matched_fixture():
    _, _, result, spec = fixture()
    native = {301 + index: dict(command=60, target=[0.] * 8,
                                qpos=list(row["qpos"]), qvel=list(row["qvel"]),
                                distal_normal_force_n=[0.] * 4, distal_geometric_contact=[False] * 4)
              for index, row in enumerate(result["rows"][0]["forecast"]["rows"])}
    return result, native, spec


def parent_documents():
    trials = [dict(trial_id=TRIALS[0], controller_rows=1440, internal_rows=7200),
              dict(trial_id=TRIALS[1], controller_rows=91, internal_rows=450,
                   terminal_refusal=dict(command=90, transferred=False))]
    owner = dict(source_commit=PARENT_SOURCE, source_status=[], binding={})
    receipt = dict(ok=True, source_runtime_unchanged=True, source_commit=PARENT_SOURCE,
                   binding={}, safety_controls=dict(all=1615), constructed_cpu_worlds=2, constructed_gpu_worlds=0,
                   **{name: False for name in FLAGS})
    audit = dict(ok=True, execution_complete=False, controller_rows=1531, internal_rows=7650,
                 contact_rows=7650, reader_world_build_count=0, reader_solver_steps=0,
                 constructed_cpu_worlds=2, constructed_gpu_worlds=0, trials=copy.deepcopy(trials))
    closure = dict(attempt_id=PARENT, receipt_sha256=PARENT_RECEIPT, audit_sha256=PARENT_AUDIT,
                   reconstruction_sha256=PARENT_AUDIT, controls_passed=1615, execution_complete=False,
                   trials=copy.deepcopy(trials), **{name: False for name in FLAGS})
    return receipt, owner, audit, closure


class ContactAuthorityControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.output = Path(os.environ["EXPLORER_TEST_OUTPUT"])
        cls.output.mkdir(parents=True, exist_ok=True)

    def folder(self):
        path = self.output / uuid.uuid4().hex; path.mkdir(); return path

    def test_01_public_packet_identity_and_null_loads(self):
        row = control(); before = copy.deepcopy(row); packet = control_packet(row)
        self.assertEqual(row, before)
        self.assertEqual(packet["command"], 0)
        self.assertEqual(packet["prepared_support"], [False] * 4)

    def test_02_crossed_public_actuator_refused(self):
        row = control(); row["resolution"]["ordered_commands"][0]["actuator_id"] = "other"
        with self.assertRaises(ValueError): control_packet(row)

    def test_03_measured_load_in_controller_packet_refused(self):
        row = control(); row["request"]["state"]["ordered_contact_observations"][0]["normal_load_n"] = 1.
        with self.assertRaises(ValueError): control_packet(row)

    def test_04_nonfinite_public_target_refused(self):
        row = control(); row["native_targets"][0] = float("nan")
        with self.assertRaises(ValueError): control_packet(row)

    def test_05_unsaturated_fixed_state_motor_range(self):
        packet = control_packet(control()); spec = fixture()[3]
        result = motor_state(packet, raw_motor(packet), spec, 1e-12)
        self.assertEqual(result["reachable_lower_torque_nm"], [-.08] * 8)
        self.assertEqual(result["reachable_upper_torque_nm"], [.08] * 8)
        self.assertFalse(result["local_ranges_are_counterfactual_trajectories"])

    def test_06_maximum_braking_can_have_no_local_torque_variation(self):
        packet = control_packet(control()); spec = fixture(cap=.5)[3]
        result = motor_state(packet, raw_motor(packet, velocity=1., force=-.5), spec, 1e-12)
        self.assertEqual(result["lower_cap_positive_velocity"], [True] * 8)
        self.assertEqual(result["unchanged_torque"], [True] * 8)

    def test_07_changed_applied_native_target_refused(self):
        packet = control_packet(control()); raw = raw_motor(packet); raw["ctrl"][0] = .01
        with self.assertRaises(ValueError): motor_state(packet, raw, fixture()[3], 1e-12)

    def test_08_changed_native_motor_force_refused(self):
        packet = control_packet(control())
        with self.assertRaises(ValueError): motor_state(packet, raw_motor(packet, force=.01), fixture()[3], 1e-12)

    def test_09_outside_public_slew_correction_refused(self):
        packet = control_packet(control()); packet["correction"][0] = .2
        with self.assertRaises(ValueError): motor_state(packet, raw_motor(packet), fixture()[3], 1e-12)

    def test_10_native_limit_joins_transmission_id_not_force_position(self):
        sample = dict(nefc=3, efc_type=[7, JOINT_LIMIT_KIND, 7], efc_id=[0, 5, 0], efc_force=[2., 4., 0.])
        names = fixture()[3]["joint_ids"]
        self.assertEqual(native_limit_forces(sample, list(range(1, 9)), names), {names[4]: 4.})

    def test_11_unknown_or_duplicate_native_joint_limit_refused(self):
        for ids in ([9], [1, 1]):
            sample = dict(nefc=len(ids), efc_type=[JOINT_LIMIT_KIND] * len(ids), efc_id=ids, efc_force=[1.] * len(ids))
            with self.assertRaises(ValueError): native_limit_forces(sample, list(range(1, 9)), fixture()[3]["joint_ids"])

    def test_12_missing_or_nonfinite_native_constraint_refused(self):
        for forces in ([], [float("nan")]):
            sample = dict(nefc=1, efc_type=[JOINT_LIMIT_KIND], efc_id=[1], efc_force=forces)
            with self.assertRaises(ValueError): native_limit_forces(sample, list(range(1, 9)), fixture()[3]["joint_ids"])

    def test_13_forecast_limit_and_contact_force_blocks_remain_distinct(self):
        _, _, result, spec = fixture(); row = result["rows"][0]["forecast"]["rows"][0]
        add_contact(row, 7.); row["before_qpos"][7] = .8
        row["prediction"]["constraints"].insert(0, dict(kind="joint_limit", joint_id=spec["joint_ids"][0]))
        row["prediction"]["solution"]["force"].insert(0, 4.)
        self.assertEqual(forecast_limit_forces(row, spec), {spec["joint_ids"][0]: 4.})

    def test_14_missing_forecast_force_block_refused(self):
        _, _, result, spec = fixture(); row = result["rows"][0]["forecast"]["rows"][0]
        add_contact(row, 7.); row["prediction"]["solution"]["force"].pop()
        with self.assertRaises(ValueError): forecast_limit_forces(row, spec)

    def test_15_complete_forecast_diagnostic_preserves_input_and_distal_identity(self):
        value, knots, result, spec = fixture()
        add_contact(result["rows"][0]["forecast"]["rows"][0], 0.)
        before = copy.deepcopy((value, knots, result, spec))
        metric = SimpleNamespace(clearance=lambda q: [.01, .02, .03, .04])
        diagnostic = forecast_diagnostic(value, dict(option=dict(knots=knots), result=result), spec, metric)
        self.assertEqual(before, (value, knots, result, spec))
        self.assertEqual(diagnostic["predicted_steps"], 330)
        self.assertEqual(diagnostic["distal_geometric_contact_steps"], [1, 0, 0, 0])
        self.assertEqual(diagnostic["distal_positive_normal_force_steps"], [0] * 4)
        self.assertEqual(diagnostic["trace"][0]["distal_clearance_before_m"], [.01, .02, .03, .04])

    def test_16_warm_best_is_counted_once(self):
        cases, populations = forecast_cases(selection())
        self.assertEqual([name for name, _ in cases], ["original"])
        self.assertEqual(sum(len(rows) for _, rows in populations), 1)

    def test_17_nested_stage_bests_are_counted_without_selected_aliases(self):
        cases, populations = forecast_cases(selection(refined=True, contact=True))
        self.assertEqual([name for name, _ in cases], ["original", "refined", "contact"])
        self.assertEqual(sum(len(rows) for _, rows in populations), 419)

    def test_18_missing_search_candidate_refused(self):
        value = selection(contact=True); value["contact_search"]["evaluations"].pop()
        with self.assertRaises(ValueError): forecast_cases(value)

    def test_19_changed_selected_best_alias_refused(self):
        value = selection(contact=True); value["best"]["option"]["index"] = 27
        with self.assertRaises(ValueError): forecast_cases(value)

    def test_20_rejection_counts_preserve_overlapping_reasons(self):
        record = dict(result=dict(eligible=False, valid_intervals=65, rejection_reasons=["tilt", "joint_position_margin"]))
        summary = population_summary([("original", [record])])[0]
        self.assertEqual(summary["evaluated"], 1)
        self.assertEqual(summary["rejection_reason_counts"], {"joint_position_margin": 1, "tilt": 1})
        self.assertTrue(summary["rejection_counts_may_overlap"])

    def test_21_false_candidate_eligibility_refused(self):
        record = dict(result=dict(eligible=True, valid_intervals=65, rejection_reasons=[]))
        with self.assertRaises(ValueError): population_summary([("original", [record])])

    def test_22_future_input_drift_never_promotes_a_counterfactual(self):
        start, intervals, packets = future_inputs(); before = copy.deepcopy((start, intervals, packets))
        result = future_input_drift(start, intervals, packets)
        self.assertEqual(before, (start, intervals, packets))
        self.assertEqual(result["compared_future_prepared_commands"], 2)
        self.assertEqual(result["maximum_absolute_baseline_difference_rad_s"], [1.] * 8)
        self.assertIsNone(result["rows"][1]["target_difference_rad_s"])
        self.assertFalse(result["counterfactual_future_baseline_truth"])
        self.assertFalse(result["forecast_error_attributable_to_held_baseline_measured"])

    def test_23_changed_future_clock_or_initial_baseline_refused(self):
        for mutation in (lambda s, i, p: i[1].__setitem__("offset", 9),
                         lambda s, i, p: p[60]["baseline"].__setitem__(0, .1),
                         lambda s, i, p: p[61].__setitem__("command", 62)):
            parts = future_inputs(); mutation(*parts)
            with self.assertRaises(ValueError): future_input_drift(*parts)

    def test_24_matched_native_comparison_covers_exactly_five_steps(self):
        result, native, spec = matched_fixture()
        native[301]["distal_normal_force_n"][1] = 2.
        native[301]["distal_geometric_contact"][1] = True
        summary = matched_first_interval(60, result, native, spec)
        self.assertEqual(summary["compared_native_steps"], 5)
        self.assertEqual(summary["maximum_distal_normal_force_error_n"], [0., 2., 0., 0.])
        self.assertEqual(summary["distal_contact_presence_mismatch_steps"], [0, 1, 0, 0])
        self.assertFalse(summary["later_forecasts_native_validated"])

    def test_25_changed_target_or_missing_matched_native_step_refused(self):
        for mutation in (lambda n: n[301]["target"].__setitem__(0, .01), lambda n: n.pop(305)):
            result, native, spec = matched_fixture(); mutation(native)
            with self.assertRaises(ValueError): matched_first_interval(60, result, native, spec)

    def test_26_stream_identity_includes_every_raw_byte_and_row(self):
        path = self.folder() / "input.jsonl"; data = b'{"command":0}\n{"command":1}\n'; path.write_bytes(data)
        binding = dict(byte_length=len(data), sha256=hashlib.sha256(data).hexdigest())
        rows = list(bounded_rows(path, binding, 100))
        self.assertEqual([row[3]["command"] for row in rows], [0, 1])
        self.assertEqual(sum(row[2] for row in rows), len(data))

    def test_27_tampered_truncated_or_oversized_stream_refused(self):
        for data, digest, maximum in ((b'{}\n', "0" * 64, 100), (b'{}', None, 100), (b'{"long":1}\n', None, 3)):
            path = self.folder() / "input.jsonl"; path.write_bytes(data)
            binding = dict(byte_length=len(data), sha256=digest or hashlib.sha256(data).hexdigest())
            with self.assertRaises(ValueError): list(bounded_rows(path, binding, maximum))

    def test_28_capture_limits_and_single_use_files(self):
        capture = Capture(self.folder(), dict(maximum_capture_row_bytes=50, maximum_capture_bytes=50))
        capture.write("one.json", {})
        with self.assertRaises(FileExistsError): capture.write("one.json", {})
        with self.assertRaises(ValueError): capture.append(io.BytesIO(), dict(large="x" * 60))
        self.assertEqual(capture.rows, 1)

    def test_29_artifact_omission_duplicate_or_extra_refused(self):
        row = dict(path="file.json", sha256="a" * 64, byte_length=1)
        population([row], [copy.deepcopy(row)])
        for actual in ([], [row, row], [row, dict(row, path="extra.json")], [dict(row, path="../escape")]):
            with self.assertRaises(ValueError): population([row], actual)

    def test_30_unexplained_or_unstaged_source_refused(self):
        validate_status([])
        validate_status(["A  sdk/discovery/contact_sequence_authority_task_v1.py"])
        for status in ([" M sdk/discovery/contact_sequence_authority_task_v1.py"], ["M  README.md"], ["?? unrelated.py"]):
            with self.assertRaises(ValueError): validate_status(status)

    def test_31_native_xml_forecast_and_solver_entrypoints_are_disabled(self):
        import xml.etree.ElementTree as ET
        import predictive_sequence_v1
        solve = np.linalg.solve
        with retained_only():
            for call in (lambda: mujoco.MjModel(), lambda: ET.fromstring("<x/>"),
                         lambda: predictive_sequence_v1.evaluate(None, None, None, 66),
                         lambda: np.linalg.solve([[1.]], [1.])):
                with self.assertRaises(AssertionError): call()
        self.assertIs(np.linalg.solve, solve)

    def test_32_failed_parent_false_population_or_authority_refused(self):
        validate_parent_documents(*parent_documents())
        for mutation in (lambda r, o, a, c: r.__setitem__("ok", False),
                         lambda r, o, a, c: r.__setitem__("constructed_cpu_worlds", 4),
                         lambda r, o, a, c: a.__setitem__("execution_complete", True),
                         lambda r, o, a, c: c.__setitem__("training_data_authority", True)):
            parts = parent_documents(); mutation(*parts)
            with self.assertRaises(ValueError): validate_parent_documents(*parts)

    def test_33_native_geometry_and_positive_load_keep_distinct_denominators(self):
        motor = dict(lower_cap=[False] * 8, upper_cap=[False] * 8, unchanged_torque=[False] * 8,
                     lower_cap_positive_velocity=[False] * 8, maximum_motor_error_nm=0.)
        rows = [dict(step=i + 1, distal_geometric_contact=[True] * 4, distal_normal_force_n=[load] * 4,
                     distal_clearance_before_m=[-.001] * 4, motor=motor, joint_limit_constraint_force={})
                for i, load in enumerate((0., -1e-12, 2.))]
        result = native_summary(rows, fixture()[3])
        self.assertEqual(result["internal_steps"], 3)
        self.assertEqual(result["distal_geometric_contact_steps"], [3] * 4)
        self.assertEqual(result["distal_positive_normal_force_steps"], [1] * 4)
        self.assertFalse(result["positive_normal_force_is_support_qualification"])

    def test_34_missing_duplicate_or_reordered_native_summary_refused(self):
        for rows in ([], [dict(step=1), dict(step=1)], [dict(step=1), dict(step=3)], [dict(step=2), dict(step=1)]):
            with self.assertRaises(ValueError): native_summary(rows, fixture()[3])


if __name__ == "__main__":
    unittest.main()
