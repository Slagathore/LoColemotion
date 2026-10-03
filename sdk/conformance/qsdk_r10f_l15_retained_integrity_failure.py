"""Close L15's observed retention failure, without accepting or repairing it.

This is a post-exposure, zero-world failure recorder. It replays only the exact
historical JSON comparison functions, not the complete physical acceptance gate.
No existing source, evidence, threshold, or interpretation is rewritten.
"""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
SOURCE = "e666f35dd599e480c5419272c26c22adf553877b"
FREEZE = "16a2b989a8d38f45a2649528c29b4aebf164fe8b"
AUTHORITY = "e4263c83048b49ea18130a2d1436e62355022c67"
EVIDENCE = ROOT.parent / "SporeSpore_Evidence/qsdk-r10f-development-route-ghost-3fad9af720017466"
OUTPUT = ROOT / "sdk/qsdk_r10f_l15_retained_integrity_failure_closure_v1.json"
RETENTION = "sdk/conformance/qsdk_r10f_l15_collection_retention.py"
CLOSER = "sdk/conformance/qsdk_r10f_physical_closure.py"
SUPERVISOR = "sdk/run_qsdk_r10f_continuous_passive_recovery.ps1"
RAW_MARKER = "QSDK_R10F_CONTINUOUS_PASSIVE_RECOVERY_RAW "
ERROR = "L9_CHILD_RAW_MARKER_BINDING"
OBSERVED_STATUS = "valid_complete_behavior_negative_development"
ROLES = ("01-matched_no_kick_continuation", "02-kick_passive_recovery_resume")
# Exact observed population, independent of the report's self-description.
POPULATION = """
2590 fc35749e6b55cd76cce09787971b1ed906a92ec7005b48f58878d65ad84c89d4 attempt_identity.json
889 ec36ab86ed27362bee623e86f2edd0698f283a7d8aa12b1a3452cd19b2ed1df0 children/01-matched_no_kick_continuation/child_attempt_identity.json
19654560 cdc865ad9fd90ecb882d17a3cdcfd1aa0adfa54413b240f3fdd647cecc14634b children/01-matched_no_kick_continuation/child_envelope.json
629 2dd0d0dcd4e47244ff1434e49834720e6fe97cc839120700d4e2f96abd2c53fb children/01-matched_no_kick_continuation/engine_health.json
14853211 1cda20490f7deb722ff68b3b6b47820cc4cf07faf5759034720cea67c2d0aa57 children/01-matched_no_kick_continuation/termination_receipt.json
18851402 89dfa36e6274cce687e7ede1478e0bee3cbd59aae967704684c115eb5a6fe5b1 children/01-matched_no_kick_continuation/worker_report.json
0 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 children/01-matched_no_kick_continuation/worker.stderr.txt
14063066 0e04ab296666a7a478e727270e53743383400f9ebbc3f110007f388a815b5751 children/01-matched_no_kick_continuation/worker.stdout.txt
889 4c923382f87f92288d59f2cd08af92b724661bfd81ea57d28ddfd3ce96ab2a40 children/02-kick_passive_recovery_resume/child_attempt_identity.json
8581120 0b42fb95b936462c40b490d3e111ab6eda91837a86baf046200d85ac6f54db80 children/02-kick_passive_recovery_resume/child_envelope.json
629 2dd0d0dcd4e47244ff1434e49834720e6fe97cc839120700d4e2f96abd2c53fb children/02-kick_passive_recovery_resume/engine_health.json
6525544 a9522ef2e23138666894f8069ba5007695bdc21c80ddd2c0bf53c77ce4f6f564 children/02-kick_passive_recovery_resume/termination_receipt.json
8229647 4641618becfadfa2822a6f43b1e7082d59289dd12f36662c2bde3f8a4ad64aff children/02-kick_passive_recovery_resume/worker_report.json
0 e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855 children/02-kick_passive_recovery_resume/worker.stderr.txt
6163237 52c8987b3576b0134aa07d26a5355a9ef73996b2f00fb50a12dd887130440ff7 children/02-kick_passive_recovery_resume/worker.stdout.txt
30530615 580eca8a7d0b8263dd7f4ca0f6dacdb4fa2d126793fd38e6591efa4a70c71629 supervisor_result.json
"""


def require(condition, code):
    if not condition:
        raise ValueError(code)


def sha(raw):
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT)


def inventory():
    return [dict(path=path, byte_length=int(length), raw_sha256="sha256:" + digest)
            for length, digest, path in (line.split() for line in POPULATION.splitlines() if line)]


def verify_population(root, bindings):
    actual = {path.relative_to(root).as_posix() for path in root.rglob("*") if path.is_file()}
    require(actual == {item["path"] for item in bindings}, "POPULATION_SET")
    for item in bindings:
        path = root / item["path"]
        require(path.resolve().is_relative_to(root.resolve()), "EVIDENCE_PATH_ESCAPE")
        raw = path.read_bytes()
        require(len(raw) == item["byte_length"] and sha(raw) == item["raw_sha256"],
                "RETAINED_FILE:" + item["path"])


def frozen_functions(raw):
    """Replay exact historical predicates; never import a later working copy."""
    names = {"require", "same", "finite_json", "parse_json"}
    selected = [node for node in ast.parse(raw).body
                if isinstance(node, ast.FunctionDef) and node.name in names]
    require({node.name for node in selected} == names, "FROZEN_FUNCTION_SET")
    namespace = {"json": json, "math": math}
    exec(compile(ast.Module(body=selected, type_ignores=[]), RETENTION, "exec"), namespace)
    return namespace


def differences(left, right, same, path="$"):
    if same(left, right):
        return []
    if type(left) is dict and type(right) is dict and left.keys() == right.keys():
        return [entry for key in left for entry in differences(left[key], right[key], same, path + "." + key)]
    if type(left) is list and type(right) is list and len(left) == len(right):
        return [entry for i, (a, b) in enumerate(zip(left, right))
                for entry in differences(a, b, same, path + "[" + str(i) + "]")]
    result = dict(path=path, original_kind=type(left).__name__, retained_kind=type(right).__name__,
                  original_repr=repr(left), retained_repr=repr(right))
    if type(left) is float and type(right) is float:
        result.update(original_binary64_hex=left.hex(), retained_binary64_hex=right.hex(),
                      representable_step_distance=abs(struct.unpack(">Q", struct.pack(">d", left))[0]
                                                     - struct.unpack(">Q", struct.pack(">d", right))[0]))
    return [result]


def collect():
    require(git("rev-parse", "--show-toplevel").decode().strip() == ROOT.as_posix(), "ROOT")
    require(git("remote", "get-url", "origin").decode().strip()
            == "https://github.com/Slagathore/sporespore.git", "REMOTE")
    require(git("rev-parse", FREEZE + "^").decode().strip() == SOURCE, "FREEZE_PARENT")
    require(git("rev-parse", AUTHORITY + "^").decode().strip() == FREEZE, "AUTHORITY_PARENT")
    bindings = inventory()
    verify_population(EVIDENCE, bindings)
    historical = {path: git("show", SOURCE + ":" + path) for path in (RETENTION, CLOSER, SUPERVISOR)}
    functions = frozen_functions(historical[RETENTION])
    same, parse = functions["same"], functions["parse_json"]
    require(ERROR.encode() in historical[CLOSER], "FROZEN_REFUSAL_CODE")
    report = parse((EVIDENCE / "supervisor_result.json").read_text(encoding="utf-8"))
    require(report["status"] == OBSERVED_STATUS and report["behavior_passed"] is False,
            "OBSERVED_SUPERVISOR_STATUS")
    require(report["source_commit"] == SOURCE and report["repair_id"] == "QSDK-R10F-L15", "SOURCE_IDENTITY")
    comparisons, child_counts, child_times = [], [], []
    for index, role in enumerate(ROLES):
        child = EVIDENCE / "children" / role
        lines = [line[len(RAW_MARKER):] for line in (child / "worker.stdout.txt").read_text(
            encoding="utf-8").splitlines() if line.startswith(RAW_MARKER)]
        require(len(lines) == 1, "RAW_MARKER_COUNT")
        original = parse(lines[0])
        envelope = parse((child / "child_envelope.json").read_text(encoding="utf-8"))
        require(same(envelope, report["child_envelopes"][index]), "SUPERVISOR_ENVELOPE_BINDING")
        saved = parse((child / "worker_report.json").read_text(encoding="utf-8"))
        for label, value in (("envelope.report", envelope["report"]), ("worker_report.json", saved)):
            delta = differences(original, value, same)
            require(len(delta) == (0 if index == 0 else 2), "OBSERVED_MISMATCH_COUNT")
            if delta:
                require(all(item.get("representable_step_distance") == 1
                            and item["original_repr"] == "2.9802322387695312e-08"
                            and item["retained_repr"] == "2.980232238769531e-08"
                            for item in delta), "OBSERVED_MISMATCH_VALUES")
            comparisons.append(dict(role=role, target=label, exact_equal=not delta, differences=delta))
        child_counts.append(original["solver_step_count"])
        child_times.append(dict(role=role, started_utc=envelope["started_utc"],
                                completed_utc=envelope["completed_utc"], exit_code=envelope["exit_code"]))
    require(child_counts == [2882, 1022] and report["solver_step_count"] == sum(child_counts), "OBSERVED_STEPS")
    terminal = report["process_population_evaluation"]["child_validations"][1]["no_resume_terminal"]
    require(terminal["terminal_reason"] == "phase_timeout:confirm_prone", "OBSERVED_TERMINAL")
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_retained_integrity_failure_closure_v1",
        "status": "closed_consumed_physical_attempt_independent_integrity_refusal",
        "gate_id": "QSDK-R10F", "repair_id": "QSDK-R10F-L15",
        "ledger_scope": dict(subsystem="recovery", engine_scope="godot_jolt",
                             authority_mode="post_exposure_retained_integrity_failure_closure", question_class="development"),
        "classification": "invalid_or_incomplete_no_behavioral_conclusion",
        "source_commit": SOURCE, "freeze_commit": FREEZE, "authority_commit": AUTHORITY,
        "authority_sha256": report["authority_sha256"], "attempt_id": report["attempt_id"],
        "retained_evidence": dict(root=EVIDENCE.as_posix(), file_count=len(bindings),
                                  total_byte_length=sum(item["byte_length"] for item in bindings), files=bindings),
        "historical_reader_sources": [dict(path=path, source_commit=SOURCE,
                                            byte_length=len(raw), raw_sha256=sha(raw)) for path, raw in historical.items()],
        "observed_official_audit": dict(command="python -B sdk/conformance/qsdk_r10f_physical_closure.py --l15 audit-report --report "
                                               + (EVIDENCE / "supervisor_result.json").as_posix(),
                                        exit_code=1, failure_code=ERROR,
                                        invocation_at_clean_authority_head=True),
        "frozen_predicate_replay": dict(functions=["require", "same", "finite_json", "parse_json"],
                                         complete_official_gate_replayed_by_this_audit=False, comparisons=comparisons),
        "supervisor_reported_diagnostics_not_accepted_behavior": dict(
            status=report["status"], behavior_passed=report["behavior_passed"],
            terminal_reason=terminal["terminal_reason"], terminal_passive_step=terminal["terminal_recovery_epoch_local_step"],
            resume_step_count=terminal["walking_resume_step_count"], child_solver_steps=child_counts,
            worlds=report["world_build_count"], solver_steps=report["solver_step_count"],
            extra_native_readbacks=report["explicit_worker_extra_native_readback_count"],
            child_lifetimes=child_times, evaluator_invocation_count=report["evaluator_invocation_count"]),
        "diagnosis": "Host JSON reserialization changes two copies of one terminal binary64 measurement; exact retained-source identity fails.",
        "root_cause_probe": dict(original_json='{"value":2.9802322387695312e-08}',
                                 powershell_decoded_binary64_bits="3E60000000000000",
                                 powershell_serialized_json='{"value":2.980232238769531E-08}',
                                 method="Pinned PowerShell ConvertFrom-Json -AsHashtable then ConvertTo-Json -Compress"),
        "integrity_failure_reproduced": True, "physical_attempt_consumed": True,
        "independent_physical_report_audit_passed": False, "valid_physical_route_established": False,
        "behavioral_conclusion_authorized": False, "supervisor_result_rewritten": False,
        "retained_values_replaced": False, "numerical_tolerance_added": False,
        "same_identity_rerun_permitted": False, "physical_execution_authorized": False,
        "sdk1_m07_satisfied": False, "sdk1_score": "14/20", "full_program_score": "14/25",
        "r173_three_engine_prone_to_standing_preserved": True,
        "physical_acceptance_authority": False, "release_authority": False,
        "closure_work_counters": dict(model_construction_count=0, world_build_count=0,
                                      native_physics_read_count=0, solver_step_count=0, physics_state_modified=False),
        "next_work": "Approved fast development loop and real-interface smoke; no L15 retry or acceptance promotion.",
    }


def validate_record(record, expected):
    require(json.dumps(record, sort_keys=True, allow_nan=False)
            == json.dumps(expected, sort_keys=True, allow_nan=False), "CLOSURE_RECORD_MISMATCH")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--describe", action="store_true", help="Print computed closure without writing files")
    args = parser.parse_args()
    try:
        expected = collect()
        if args.describe:
            print(json.dumps(expected, indent=2, allow_nan=False))
        else:
            validate_record(json.loads(OUTPUT.read_text(encoding="utf-8")), expected)
            print("QSDK_R10F_L15_INTEGRITY_FAILURE_CLOSURE_PASS " + json.dumps({
                "integrity_failure_reproduced": True, "retained_files": 16,
                "retained_bytes": 127458028, "official_report_audit_passed": False,
                "worlds_created_by_audit": 0, "solver_steps_by_audit": 0,
                "physical_execution_authorized": False, "release_authority": False}))
    except (ValueError, OSError, subprocess.CalledProcessError) as exc:
        print("QSDK_R10F_L15_INTEGRITY_FAILURE_CLOSURE_FAIL " + str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
