"""Cold replay of actual serialized worker-hook records; synthetic inputs only.

Every invocation keeps original producer/reader stdout, stderr and replay input
in a fresh durable zero-world test directory. Never launches a physical worker.
"""
import copy
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))
sys.path.insert(0, str(ROOT / "sdk/conformance"))
sys.path.insert(0, str(ROOT / "sdk/python"))
from test_development_recovery_smoke import native, runtime
from qsdk_r10f_l15_collection_retention import parse_json
from sporespore_locomotion import LocomotionCore
import development_passive_entry_profile as entry


def marker(run, prefix):
    rows = [parse_json(line[len(prefix):]) for line in run.stdout.decode().splitlines()
            if line.startswith(prefix)]
    if b"ERROR:" in run.stdout + run.stderr or len(rows) != 1:
        raise AssertionError((run.returncode, run.stdout[-5000:], run.stderr))
    if run.returncode:
        value = rows[0]
        raise AssertionError((run.returncode, value.get("failure"), value.get("full_report_fixture"),
                              value.get("baseline_fixture"), value.get("application_sources", {}).get("checks")))
    return rows[0]


class PassiveEntryReplay(unittest.TestCase):
    producer_script = 'res://tests/test_development_passive_entry_replay_fixture.gd'
    producer_marker = 'DEVELOPMENT_PASSIVE_ENTRY_REPLAY_FIXTURE '
    reader_script = 'res://sdk/trace_analysis/development_passive_entry_replay.gd'
    reader_marker = 'DEVELOPMENT_PASSIVE_ENTRY_REPLAY '
    core_path = 'sdk/target/development-passive-entry-v1/debug/sporespore_godot_adapter.dll'
    root_prefix = 'development-passive-entry-replay-'
    canonical_count = 2
    segment_count = 5
    report_count = 276
    baseline_report_count = 276
    negative_count = 25

    @classmethod
    def _run_retained(cls, script, arguments, name, timeout):
        command = [runtime.IMAGES['godot_engine']['path'], '--headless', '--path', str(ROOT),
                   '--script', script, *arguments]
        source = entry._source_snapshot()
        (cls.root / (name + '.source_snapshot.json')).write_text(json.dumps(source, indent=2) + '\n', encoding='utf-8')
        environment = {key: value for key, value in os.environ.items()
                       if not key.startswith('SPORESPORE_GODOT_RECOVERY_')}
        started = time.monotonic()
        timed_out = False
        exit_code = None
        try:
            with (cls.root / (name + '.stdout.txt')).open('xb') as stdout, (cls.root / (name + '.stderr.txt')).open('xb') as stderr:
                result = subprocess.run(command, cwd=ROOT, stdout=stdout, stderr=stderr, timeout=timeout,
                                        creationflags=subprocess.CREATE_NO_WINDOW, env=environment)
                exit_code = result.returncode
        except subprocess.TimeoutExpired:
            timed_out = True
        finally:
            execution = dict(command=command, returncode=exit_code, timed_out=timed_out,
                timeout_seconds=timeout, elapsed_seconds=time.monotonic() - started,
                source_unchanged=entry.packet.same(source, entry._source_snapshot()),
                world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
            (cls.root / (name + '.execution.json')).write_text(json.dumps(execution, indent=2) + '\n', encoding='utf-8')
        if timed_out or not execution['source_unchanged']:
            raise AssertionError(execution)
        return subprocess.CompletedProcess(command, exit_code,
            (cls.root / (name + '.stdout.txt')).read_bytes(), (cls.root / (name + '.stderr.txt')).read_bytes())

    @classmethod
    def extra_negative_cases(cls, original):
        return []

    @classmethod
    def setUpClass(cls):
        cls.root = ROOT.parent / "SporeSpore_Evidence" / (cls.root_prefix + uuid.uuid4().hex)
        cls.root.mkdir()
        print('ENTRY_REPLAY_TEST_ROOT', cls.root, flush=True)
        producer = cls._run_retained(cls.producer_script, [], 'producer', 90)
        exported = marker(producer, cls.producer_marker)
        if exported["ok"] is not True or exported["synthetic_native_observations_only"] is not True:
            raise AssertionError({key: value for key, value in exported.items() if "input" not in key})
        cls.application_sources = exported["application_sources"]
        cls.input = exported["input"]
        cases = [{"case_id": "actual_worker_segment", "input": cls.input}]
        cls.full_report = exported["full_report_input"]
        cases.append({"case_id": "complete_report_from_zero", "input": cls.full_report})
        cases.append({"case_id": "baseline_report_from_zero", "input": exported["baseline_report_input"]})
        cls.positive_cases = {"actual_worker_segment", "cutoff_while_waiting", "cutoff_at_handoff", "complete_report_from_zero", "baseline_report_from_zero"}
        for name, length, entry_count in [("cutoff_while_waiting", 2, 1), ("cutoff_at_handoff", 3, 2)]:
            changed = copy.deepcopy(cls.input)
            retained = changed["retention"]
            retained["orchestrator_transitions"] = retained["orchestrator_transitions"][:length]
            retained["entry_packets"] = retained["entry_packets"][:entry_count]
            retained["canonical_packets"] = []
            retained["first_recovery_owned_application"] = {}
            if 'post_kick_controller_context' in retained:
                retained['post_kick_controller_context'] = {}
            changed["final_state"] = retained["orchestrator_transitions"][-1]["advance"]["state_after"]
            cases.append({"case_id": name, "input": changed})
        mutations = {
            "missing_entry": lambda x: x["retention"]["entry_packets"].pop(0),
            "missing_canonical": lambda x: x["retention"]["canonical_packets"].pop(0),
            "extra_canonical": lambda x: x["retention"]["canonical_packets"].append(copy.deepcopy(x["retention"]["canonical_packets"][-1])),
            "extra_entry": lambda x: x["retention"]["entry_packets"].append(copy.deepcopy(x["retention"]["entry_packets"][-1])),
            "rewritten_request": lambda x: x["retention"]["entry_packets"][0]["entry_call"]["request"].update(utf8_text="{}"),
            "rewritten_response": lambda x: x["retention"]["entry_packets"][1]["entry_call"]["response"].update(utf8_text="{}"),
            "transplanted_memory": lambda x: x["retention"]["canonical_packets"][1]["collection_transport"]["source_links"].update(source_memory=copy.deepcopy(x["retention"]["canonical_packets"][0]["collection_transport"]["source_links"]["source_memory"])),
            "changed_source_bytes": lambda x: x["retention"]["canonical_packets"][0]["collection_transport"]["source_links"]["bound_observation"].update(raw_sha256="sha256:" + "0" * 64),
            "repeated_initialization": lambda x: x["retention"]["entry_packets"][0]["entry_receipt"].update(canonical_initialization_count=1),
            "wrong_first_owner": lambda x: x["retention"].update(first_recovery_owned_application=copy.deepcopy(x["retention"]["entry_packets"][0]["source_application"])),
            "wrong_runtime": lambda x: x["retention"]["runtime_binding"]["runtime"].update(raw_sha256="sha256:" + "0" * 64),
            "energy_reset_permission": lambda x: x["retention"].update(energy_epoch_reset_permitted_at_handoff=True),
            "missing_transition": lambda x: x["retention"]["orchestrator_transitions"].pop(1),
            "crossed_final_state": lambda x: x["final_state"].update(canonical_start_global_step=511),
        }
        for name, mutate in mutations.items():
            changed = copy.deepcopy(cls.input)
            mutate(changed)
            cases.append({"case_id": name, "input": changed})
        report_mutations = {
            "report_missing_prefix": lambda r: r["passive_entry"]["orchestrator_transitions"].pop(0),
            "report_changed_configuration": lambda r: r["configuration"].update(crossed=True),
            "report_changed_trace_hash": lambda r: r["retained_arm"]["trace_rows"][-1].update(application_intent_sha256="sha256:" + "0" * 64),
            "report_wrong_step_count": lambda r: r.update(solver_step_count=r["solver_step_count"] + 1),
            "report_changed_classification": lambda r: r["retained_arm"]["trace_rows"][-1]["recovery_classification"].update(entry_prone_gate=False),
        }
        for name, mutate in report_mutations.items():
            changed = copy.deepcopy(cls.full_report)
            mutate(changed["report"])
            cases.append({"case_id": name, "input": changed})
        core = LocomotionCore(ROOT / cls.core_path)
        # Exercise the real reader with crossed native execution records. Fresh
        # hashes must not hide a receipt from another command or solver step.
        for name in ('intent_hash_as_execution', 'missing_native_execution', 'crossed_native_command',
                     'crossed_native_step', 'crossed_native_impulses'):
            changed = copy.deepcopy(cls.input)
            entry_packet = changed['retention']['entry_packets'][0]
            bound = entry_packet['bound_observations']
            components = bound['source_component_receipts']['rotation_aware_source_component_receipts']
            native_receipt = components['application_receipt']
            if name == 'missing_native_execution':
                del components['application_receipt']
            elif name == 'intent_hash_as_execution':
                for version in ('observation_v2', 'observation_v3'):
                    bound[version]['applied_actuation']['adapter_receipt_sha256'] = core.canonicalize_json(entry_packet['source_application'])['sha256']
            else:
                if name == 'crossed_native_command':
                    native_receipt['command_id'] += '_crossed'
                elif name == 'crossed_native_step':
                    native_receipt['semantic_step'] += 1
                else:
                    native_receipt['ordered_applied_impulses'][0]['applied_angular_impulse_nms'] = 0.125
                digest = core.canonicalize_json(native_receipt)['sha256']
                components['application_receipt_sha256'] = digest
                for version in ('observation_v2', 'observation_v3'):
                    bound[version]['applied_actuation']['adapter_receipt_sha256'] = digest
            cases.append({'case_id': name, 'input': changed})
        changed = copy.deepcopy(cls.input)
        event = changed["retention"]["orchestrator_transitions"][1]["event"]
        event.update(passive_entry_status="prone_handoff", canonical_initialization_count=1, prone_sample=True)
        payload = {key: value for key, value in event.items() if key != "payload_sha256"}
        event["payload_sha256"] = core.canonicalize_json(payload)["sha256"]
        cases.append({"case_id": "forged_prone_event_with_fresh_hash", "input": changed})
        cases.extend(cls.extra_negative_cases(cls.input))
        cls.negative_cases = {case["case_id"] for case in cases} - cls.positive_cases
        batch = {"schema_version": "sporespore_development_passive_entry_replay_test_batch_v1", "cases": cases}
        raw = json.dumps(batch, separators=(",", ":"), ensure_ascii=False, allow_nan=False).encode()
        path = cls.root / "reader_input.json"
        path.write_bytes(raw)
        reader = cls._run_retained(cls.reader_script, ['--', str(path)], 'reader', 150)
        cls.result = marker(reader, cls.reader_marker)
        cls.results = {row["case_id"]: row["replay"] for row in cls.result["cases"]}
        print("PASSIVE_ENTRY_REPLAY_TEST_ROOT", cls.root)
        print(json.dumps({"input_raw_sha256": cls.result["input_raw_sha256"],
                          "cases": {key: {"ok": row["ok"], "failure_code": row.get("failure_code", "")}
                                    for key, row in cls.results.items()}}))

    def test_cold_actual_worker_replay(self):
        result = self.results["actual_worker_segment"]
        self.assertIs(result["ok"], True, result)
        self.assertEqual(2, result["entry_observation_count"])
        self.assertEqual(self.canonical_count, result["canonical_observation_count"])
        self.assertEqual(1, result["canonical_initialization_count"])
        self.assertEqual(self.segment_count, result["transition_count"])
        self.assertEqual(0, result["world_build_count"])
        self.assertEqual(0, result["solver_step_count"])

    def test_valid_diagnostic_cutoffs_do_not_invent_completion(self):
        for name in self.positive_cases:
            result = self.results[name]
            self.assertIs(result["ok"], True, (name, result))
            self.assertIs(result["complete_route_proven"], False)
            self.assertIs(result["physical_acceptance_authority"], False)
        self.assertEqual(0, self.results["cutoff_while_waiting"]["canonical_initialization_count"])
        self.assertEqual(1, self.results["cutoff_at_handoff"]["canonical_initialization_count"])
        self.assertEqual(0, self.results["cutoff_at_handoff"]["canonical_observation_count"])

    def test_all_corrupted_records_are_refused(self):
        self.assertEqual(self.negative_count, len(self.negative_cases))
        for name in self.negative_cases:
            self.assertIs(self.results[name]["ok"], False, (name, self.results[name]))
        self.assertEqual("PASSIVE_ENTRY_REPLAY_ENTRY_EVENT_NOT_FROM_RECEIPT",
                         self.results["forged_prone_event_with_fresh_hash"]["failure_code"])
        expected = dict(intent_hash_as_execution='APPLICATION_OBSERVATION_BINDING',
                        missing_native_execution='NATIVE_APPLICATION_SOURCE_MISSING',
                        crossed_native_command='APPLICATION_OBSERVATION_COMMAND:command_id',
                        crossed_native_step='NATIVE_APPLICATION_STEP_OR_IMPULSES',
                        crossed_native_impulses='NATIVE_APPLICATION_STEP_OR_IMPULSES')
        for name, code in expected.items():
            self.assertEqual('PASSIVE_ENTRY_REPLAY_' + code, self.results[name]['failure_code'])

    def test_full_report_reconstructs_fresh_initial_state(self):
        result = self.results["complete_report_from_zero"]
        self.assertIs(result["ok"], True, result)
        self.assertEqual(0, result["initial_global_semantic_step"])
        self.assertEqual(self.report_count, result["transition_count"])
        self.assertEqual(1, result["canonical_initialization_count"])
        self.assertEqual(self.results["actual_worker_segment"]["final_state_sha256"], result["final_state_sha256"])

    def test_reader_is_bound_to_original_input_and_denies_physics_claims(self):
        raw = (self.root / "reader_input.json").read_bytes()
        self.assertEqual("sha256:" + hashlib.sha256(raw).hexdigest(), self.result["input_raw_sha256"])
        self.assertIs(self.result["physical_acceptance_authority"], False)
        self.assertIs(self.result["release_authority"], False)
        self.assertEqual(0, self.result["world_build_count"])
        self.assertEqual(0, self.result["native_physics_read_count"])

    def test_baseline_never_initializes_post_kick_recovery(self):
        result = self.results["baseline_report_from_zero"]
        self.assertIs(result["ok"], True, result)
        self.assertEqual(0, result["initial_global_semantic_step"])
        self.assertEqual(self.baseline_report_count, result["transition_count"])
        self.assertEqual(0, result["entry_observation_count"])
        self.assertEqual(0, result["canonical_observation_count"])
        self.assertEqual(0, result["canonical_initialization_count"])

    def test_actual_active_and_disabled_command_producers(self):
        self.assertIs(self.application_sources["ok"], True, self.application_sources)
        self.assertEqual(8, len(self.application_sources["checks"]))
        self.assertTrue(all(self.application_sources["checks"].values()))


if __name__ == "__main__":
    unittest.main()
