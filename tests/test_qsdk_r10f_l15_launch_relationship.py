"""Real owned host processes plus independent PowerShell/Python consumers.

These are component fixtures, not scientific child identities, worlds, a
qualified R10F route or evidence that the still-unintegrated final callers pass.
"""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "sdk/conformance"))
import qsdk_r10f_l15_launch_relationship as consumer

PWSH = Path("C:/Program Files/PowerShell/7/pwsh.exe")
PYTHON = Path("C:/Program Files/Python311/python.exe")
RUNNER = ROOT / "tests/test_qsdk_r10f_l15_launch_relationship.ps1"


def powershell(mode: str, fixture: dict, evidence: Path | None = None) -> dict:
    result = subprocess.run(
        [
            str(PWSH),
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(RUNNER),
            "-Mode",
            mode,
        ],
        input=json.dumps(fixture, separators=(",", ":")),
        text=True,
        capture_output=True,
        cwd=ROOT,
        timeout=60,
        check=False,
    )
    if evidence is not None:
        (evidence/'live.stdout.log').write_text(result.stdout, encoding='utf-8')
        (evidence/'live.stderr.log').write_text(result.stderr, encoding='utf-8')
        (evidence/'live-execution.json').write_text(json.dumps(dict(exit_code=result.returncode,
            world_build_count=0,solver_step_count=0))+'\n', encoding='utf-8')
    result.check_returncode()
    if result.stderr:
        raise AssertionError(result.stderr)
    return json.loads(result.stdout)


def case_from_run(item: dict) -> dict:
    run = item["run"]
    return {
        "name": item["kind"],
        "receipt": run["r10f_l15_launch_relationship"],
        "context": item["context"],
        "root_process_id": run["process_id"],
        "worker_process_id": run["worker_process_id"],
        "started_utc": run["started_utc"],
        "ready_receipt": run["termination_ready_receipt"],
    }


def python_accepts(case: dict) -> bool:
    try:
        consumer.validate_receipt(
            case["receipt"],
            expected_context=case["context"],
            root_process_id=case["root_process_id"],
            worker_process_id=case["worker_process_id"],
            started_utc=case["started_utc"],
            expected_ready_receipt=case["ready_receipt"],
        )
        return True
    except (ValueError, KeyError, TypeError, OverflowError):
        return False


def reseal(case: dict, change) -> dict:
    value = copy.deepcopy(case)
    payload = json.loads(value["receipt"]["payload_json"])
    change(payload)
    text = json.dumps(payload, separators=(",", ":"), ensure_ascii=False)
    value["receipt"]["payload_json"] = text
    value["receipt"]["payload_byte_length"] = len(text.encode("utf-8"))
    value["receipt"]["payload_raw_sha256"] = (
        "sha256:" + hashlib.sha256(text.encode("utf-8")).hexdigest()
    )
    return value


class LaunchRelationshipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        import development_passive_entry_profile as entry
        cls.snapshot = staticmethod(entry._source_snapshot)
        cls.out = ROOT.parent/'SporeSpore_Evidence'/('l15-owned-process-identity-'+uuid.uuid4().hex)
        cls.out.mkdir()
        print('L15_OWNED_PROCESS_IDENTITY_EVIDENCE '+str(cls.out), flush=True)
        cls.before = cls.snapshot()
        (cls.out/'source_before.json').write_text(json.dumps(cls.before)+'\n', encoding='utf-8')
        raw = PYTHON.read_bytes()
        image = {
            "path": PYTHON.as_posix(),
            "byte_length": len(raw),
            "raw_sha256": "sha256:" + hashlib.sha256(raw).hexdigest(),
        }
        context = {
            "schema_version": "sporespore_qsdk_r10f_l15_launch_context_v1",
            "parent_attempt_id": "a" * 32,
            "child_attempt_id": "b" * 32,
            "role": "matched_no_kick_continuation",
            "source_commit": "d" * 40,
            "authority_sha256": "sha256:" + "e" * 64,
            "termination_nonce": "c" * 32,
            "ready_marker_prefix": "QSDK_R10F_L15_NONPHYSICS_FIXTURE_READY ",
            "root_image": image,
            "worker_image": copy.deepcopy(image),
        }
        cls.live = powershell("Live", {"context": context}, cls.out)
        (cls.out/"live.json").write_text(json.dumps(cls.live)+"\n", encoding="utf-8")
        cls.self_case = case_from_run(cls.live["runs"][0])
        cls.descendant = case_from_run(cls.live["runs"][1])

    @classmethod
    def tearDownClass(cls):
        after = cls.snapshot()
        (cls.out/'source_after.json').write_text(json.dumps(after)+'\n', encoding='utf-8')
        if cls.before != after:
            raise AssertionError('L15_OWNED_PROCESS_TEST_SOURCE_DRIFT')

    def test_actual_launcher_and_two_independent_consumers(self):
        for item in self.live["runs"]:
            with self.subTest(item["kind"]):
                run = item["run"]
                self.assertEqual("", item["validation_error"], run)
                self.assertEqual(0, run["exit_code"], run)
                self.assertIs(run["termination_protocol_valid"], True)
                self.assertIs(run["supervisor_terminated"], True)
                self.assertIs(run["timed_out"], False)
                self.assertEqual("", run["stderr"])
                self.assertTrue(python_accepts(case_from_run(item)))
                self.assertEqual(
                    item["kind"] == "self",
                    run["process_id"] == run["worker_process_id"],
                )
        for field in (
            "model_construction_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            self.assertEqual(0, self.live[field])

    def test_legacy_default_path_keeps_legacy_shape(self):
        self.assertIs(self.live["legacy_contains_l15_field"], False)
        self.assertEqual(0, self.live["legacy_run"]["exit_code"])
        self.assertIs(self.live["legacy_run"]["termination_protocol_valid"], True)

    def test_owned_processes_are_joined(self):
        identities = []
        for run in [item['run'] for item in self.live['runs']] + [self.live['legacy_run']]:
            rows = [json.loads(line.split(' ',1)[1]) for line in run['stdout'].splitlines()
                    if line.startswith('QSDK_R10F_L15_NONPHYSICS_IDENTITY ')]
            self.assertEqual({run['process_id'],run['worker_process_id']}, {r['pid'] for r in rows})
            self.assertEqual(len(rows),len({r['pid'] for r in rows}))
            for row in rows:
                self.assertIs(type(row['pid']),int)
                self.assertIs(type(row['creation_filetime']),int)
                self.assertGreater(row['creation_filetime'],0)
            identities.extend(rows)
        (self.out/'owned-identities.json').write_text(json.dumps(identities)+'\n',encoding='utf-8')
        # Query only retained identities, and fail only for the same live process.
        # The live-self control proves liveness refusal; a crossed birth time
        # proves that an unrelated incarnation of a PID cannot be called owned.
        command = r"""
$ErrorActionPreference='Stop'
function Assert-OwnedHelpersExited($Identities) {
    foreach ($identity in $Identities) {
        try { $owned = [Diagnostics.Process]::GetProcessById([int]$identity.pid) }
        catch [ArgumentException] { continue }
        try {
            if (-not $owned.HasExited -and $owned.StartTime.ToUniversalTime().ToFileTimeUtc() -eq $identity.creation_filetime) {
                throw ('OWNED_HELPER_STILL_RUNNING:' + $identity.pid)
            }
        } finally { $owned.Dispose() }
    }
}
$ids=[Console]::In.ReadToEnd() | ConvertFrom-Json -AsHashtable
Assert-OwnedHelpersExited $ids
$current=[Diagnostics.Process]::GetCurrentProcess()
try {
    $birth=$current.StartTime.ToUniversalTime().ToFileTimeUtc()
    $liveRefused=$false
    try { Assert-OwnedHelpersExited @(@{pid=$PID;creation_filetime=$birth}) }
    catch { if ($_.Exception.Message -cne ('OWNED_HELPER_STILL_RUNNING:'+$PID)) { throw }; $liveRefused=$true }
    if (-not $liveRefused) { throw 'LIVE_OWNED_PROCESS_ACCEPTED' }
    Assert-OwnedHelpersExited @(@{pid=$PID;creation_filetime=($birth+1)})
    @{owned_identities_joined=$true;owned_count=$ids.Count;live_identity_refused=$liveRefused;crossed_creation_identity_ignored=$true;world_build_count=0}|ConvertTo-Json -Compress
} finally { $current.Dispose() }
"""
        result = subprocess.run([str(PWSH),'-NoProfile','-NonInteractive','-Command',command],
            input=json.dumps(identities),cwd=ROOT,capture_output=True,text=True,timeout=15)
        (self.out/'joined.stdout.log').write_text(result.stdout,encoding='utf-8')
        (self.out/'joined.stderr.log').write_text(result.stderr,encoding='utf-8')
        (self.out/'joined-execution.json').write_text(json.dumps(dict(exit_code=result.returncode))+'\n',encoding='utf-8')
        self.assertEqual(0,result.returncode,result.stderr)
        self.assertEqual('',result.stderr)
        observed=json.loads(result.stdout)
        self.assertTrue(observed['owned_identities_joined'] and observed['live_identity_refused'])
        self.assertTrue(observed['crossed_creation_identity_ignored'])
        self.assertEqual(len(identities),observed['owned_count'])

    def test_both_consumers_refuse_corruptions_even_with_resealed_payload(self):
        mutations = [
            ("array_relationship", lambda p: p.update(relationship=["descendant"])),
            ("wrong_relationship", lambda p: p.update(relationship="self")),
            ("missing_chain", lambda p: p.update(process_chain=[])),
            (
                "truncated_chain",
                lambda p: p.update(process_chain=p["process_chain"][:-1]),
            ),
            (
                "duplicate_chain",
                lambda p: p["process_chain"].insert(
                    0, copy.deepcopy(p["process_chain"][0])
                ),
            ),
            ("over_depth", lambda p: p.update(process_chain=p["process_chain"] * 18)),
            (
                "unrelated_parent",
                lambda p: p["process_chain"][0].update(parent_process_id=1),
            ),
            ("wrong_root", lambda p: p.update(root_process_id=1)),
            ("wrong_worker", lambda p: p.update(worker_process_id=1)),
            ("bool_pid", lambda p: p["process_chain"][0].update(process_id=True)),
            ("fractional_pid", lambda p: p["process_chain"][0].update(process_id=1.5)),
            ("zero_pid", lambda p: p["process_chain"][0].update(process_id=0)),
            (
                "negative_parent",
                lambda p: p["process_chain"][0].update(parent_process_id=-1),
            ),
            (
                "wrong_node_path",
                lambda p: p["process_chain"][0].update(
                    executable_path="C:/unrelated.exe"
                ),
            ),
            (
                "missing_image",
                lambda p: p["process_chain"][0].update(executable_path=""),
            ),
            (
                "unreadable_time",
                lambda p: p["process_chain"][0].update(created_utc="unknown"),
            ),
            (
                "old_reused_pid",
                lambda p: p["process_chain"][0].update(
                    created_utc="2000-01-01T00:00:00.0000000Z"
                ),
            ),
            (
                "future_birth",
                lambda p: p["process_chain"][0].update(
                    created_utc="2999-01-01T00:00:00.0000000Z"
                ),
            ),
            (
                "wrong_started",
                lambda p: p.update(started_utc="2000-01-01T00:00:00.0000000Z"),
            ),
            (
                "wrong_context_nonce",
                lambda p: p["context"].update(termination_nonce="f" * 32),
            ),
            (
                "wrong_context_source",
                lambda p: p["context"].update(source_commit="f" * 40),
            ),
            (
                "wrong_context_authority",
                lambda p: p["context"].update(authority_sha256="sha256:" + "f" * 64),
            ),
            (
                "wrong_context_child",
                lambda p: p["context"].update(child_attempt_id="f" * 32),
            ),
            (
                "wrong_runtime_digest",
                lambda p: p["context"]["worker_image"].update(
                    raw_sha256="sha256:" + "f" * 64
                ),
            ),
            (
                "wrong_ready_nonce",
                lambda p: p["ready_receipt"].update(termination_nonce="f" * 32),
            ),
            (
                "wrong_ready_line",
                lambda p: p.update(ready_line=p["ready_line"] + " invalid"),
            ),
        ]
        cases = []
        for name, change in mutations:
            value = reseal(self.descendant, change)
            value["name"] = name
            cases.append(value)
        for name, path, replacement in (
            (
                "array_receipt_schema",
                ("receipt", "schema_version"),
                ["sporespore_qsdk_r10f_launch_relationship_receipt_v1"],
            ),
            (
                "promoted_scope",
                ("receipt", "ledger_scope", "question_class"),
                "finite decision",
            ),
            ("missing_receipt", ("receipt",), None),
            ("wrong_digest", ("receipt", "payload_raw_sha256"), "sha256:" + "0" * 64),
            ("wrong_length", ("receipt", "payload_byte_length"), 1),
            ("bool_length", ("receipt", "payload_byte_length"), True),
            ("promoted_receipt", ("receipt", "physical_acceptance_authority"), True),
            ("wrong_enclosing_nonce", ("context", "termination_nonce"), "f" * 32),
            ("wrong_enclosing_worker", ("worker_process_id",), 1),
            ("bool_enclosing_worker", ("worker_process_id",), True),
            ("wrong_enclosing_ready", ("ready_receipt", "requested_exit_code"), 1),
        ):
            value = copy.deepcopy(self.descendant)
            value["name"] = name
            target = value
            for key in path[:-1]:
                target = target[key]
            target[path[-1]] = replacement
            cases.append(value)
        results = powershell("Validate", {"cases": cases})["results"]
        self.assertEqual(len(cases), len(results))
        for value, result in zip(cases, results):
            with self.subTest(value["name"]):
                self.assertEqual(value["name"], result["name"])
                self.assertIs(result["accepted"], False, result)
                self.assertFalse(python_accepts(value))

    def test_consumer_preserves_submicrosecond_time_order(self):
        value = reseal(
            self.descendant,
            lambda p: (
                p.update(
                    started_utc="2026-01-01T00:00:00.0000000Z",
                    observed_utc="2026-01-01T00:00:01.0000000Z",
                ),
                p["process_chain"][0].update(
                    created_utc="2026-01-01T00:00:00.1234567Z"
                ),
                p["process_chain"][-1].update(
                    created_utc="2026-01-01T00:00:00.1234568Z"
                ),
            ),
        )
        value["started_utc"] = "2026-01-01T00:00:00.0000000Z"
        value["name"] = "parent_one_tick_newer"
        self.assertFalse(python_accepts(value))
        self.assertIs(
            powershell("Validate", {"cases": [value]})["results"][0]["accepted"], False
        )

    def test_actual_producer_refuses_dead_or_invalid_process_identity(self):
        base = copy.deepcopy(self.descendant)
        base["ready_line"] = json.loads(base["receipt"]["payload_json"])["ready_line"]
        cases = []
        for name, key, replacement in (
            (
                "owned_process_already_dead",
                "worker_process_id",
                base["worker_process_id"],
            ),
            ("zero_root", "root_process_id", 0),
            ("boolean_worker", "worker_process_id", True),
            ("fractional_worker", "worker_process_id", 1.5),
            ("out_of_range_worker", "worker_process_id", 2**31),
        ):
            case = copy.deepcopy(base)
            case["name"] = name
            case[key] = replacement
            cases.append(case)
        results = powershell("ProducerReject", {"cases": cases})["results"]
        self.assertEqual(5, len(results))
        for result in results:
            self.assertIs(result["accepted"], False, result)
            self.assertIn("QSDK_R10F_L15_LAUNCH_", result["failure"])
        self.assertIn("PROCESS_UNAVAILABLE", results[0]["failure"])

    def test_exact_depth_boundary_and_duplicate_json_key(self):
        def sixteen_edges(payload):
            # Explicit synthetic chain, never a replacement for observed ancestry.
            template = payload["process_chain"][0]
            nodes = [copy.deepcopy(template) for _ in range(17)]
            identifiers = (
                [self.descendant["worker_process_id"]]
                + list(range(1000001, 1000016))
                + [self.descendant["root_process_id"]]
            )
            for index, node in enumerate(nodes):
                node["process_id"] = identifiers[index]
                node["parent_process_id"] = identifiers[index + 1] if index < 16 else 0
            payload["process_chain"] = nodes

        boundary = reseal(self.descendant, sixteen_edges)
        boundary["name"] = "synthetic_sixteen_edge_boundary"
        self.assertTrue(python_accepts(boundary))
        self.assertIs(
            powershell("Validate", {"cases": [boundary]})["results"][0]["accepted"],
            True,
        )
        duplicate = copy.deepcopy(self.descendant)
        duplicate["name"] = "duplicate_payload_key"
        old = duplicate["receipt"]["payload_json"]
        # Correct byte hash cannot make a JSON object with duplicate keys valid.
        new = '{"relationship":"descendant",' + old[1:]
        duplicate["receipt"]["payload_json"] = new
        duplicate["receipt"]["payload_byte_length"] = len(new.encode("utf-8"))
        duplicate["receipt"]["payload_raw_sha256"] = (
            "sha256:" + hashlib.sha256(new.encode("utf-8")).hexdigest()
        )
        self.assertFalse(python_accepts(duplicate))
        self.assertIs(
            powershell("Validate", {"cases": [duplicate]})["results"][0]["accepted"],
            False,
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
