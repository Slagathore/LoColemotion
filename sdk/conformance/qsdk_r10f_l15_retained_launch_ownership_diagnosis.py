"""Reopen L14 evidence and reproduce only named frozen-source boundaries.

The observed physical result stays invalid. PID aliases exist only in isolated
predicate controls. The rejected native request is not reconstructed here.
No historical closer is imported through potentially changed dependencies.
"""

from __future__ import annotations

import ast
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
SOURCE = "fd2e2c7d9d115c00ee6eb97c5540e8b3aec48d8e"
CLOSURE_COMMIT = "18ed7e54807c845ad66138b601df337751c20b7b"
DATA = ROOT / "sdk/qsdk_r10f_l15_retained_launch_ownership_diagnosis_v1.json"
DATA_BYTES = 15925
DATA_SHA = "sha256:bad6069b8701274cc36606946947c4940aef2dcd80bb129c1df787fa60bc11af"
CLOSURE = ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v15.json"
CLOSURE_SHA = "sha256:f1384ecef9a846b0e0058a2535be11ba0d58a760dfe969020c20ae8efb9b3f11"
EVIDENCE = (
    ROOT.parent
    / "SporeSpore_Evidence/qsdk-r10f-development-route-ghost-a66bbba5d4213f9f"
)
TERMINAL_SHA = "sha256:106213c069fc39c294f736dc7b838cf56e7b3f6f9abc4d83239c3e408db4f151"
SOURCE_PATHS = (
    "sdk/run_qsdk_r10f_continuous_passive_recovery.ps1",
    "sdk/qsdk_r10f_process_isolated_pair_evaluator.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/conformance/qsdk_r10f_physical_closure.py",
    "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
    "sdk/adapters/godot/gdscript/qsdk_r10f_recovery_native_locomotion_facade_v1.gd",
    "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
    "sdk/core/src/recovery.rs",
)
ZERO_FIELDS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_physics_read_count",
    "solver_step_count",
)
FALSE_FIELDS = (
    "physics_state_modified",
    "old_result_reclassified",
    "same_identity_rerun_permitted",
    "physical_execution_authorized",
    "sdk1_m07_satisfied",
    "force_aware_recovery",
    "physical_acceptance_authority",
    "release_authority",
)


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def git(*arguments: str) -> bytes:
    return subprocess.check_output(["git", *arguments], cwd=ROOT)


def sha(raw: bytes) -> str:
    return "sha256:" + hashlib.sha256(raw).hexdigest()


def same(left: object, right: object) -> bool:
    """Preserve JSON number/bool distinctions that Python equality collapses."""
    return json.dumps(left, sort_keys=True, allow_nan=False) == json.dumps(
        right, sort_keys=True, allow_nan=False
    )


def bound_json(path: Path, length: int, digest: str) -> dict:
    raw = path.read_bytes()
    require(len(raw) == length and sha(raw) == digest, "CONTENT_ADDRESS:" + str(path))
    value = json.loads(raw)
    require(type(value) is dict, "JSON_OBJECT:" + str(path))
    return value


def evidence_bindings(value: object, result: dict[str, dict]) -> None:
    if isinstance(value, dict):
        if {"path", "byte_length", "raw_sha256"}.issubset(value):
            candidate = Path(value["path"])
            if candidate.is_absolute() and candidate.resolve().is_relative_to(
                EVIDENCE.resolve()
            ):
                relative = (
                    candidate.resolve().relative_to(EVIDENCE.resolve()).as_posix()
                )
                item = {
                    "path": relative,
                    "byte_length": value["byte_length"],
                    "raw_sha256": value["raw_sha256"],
                }
                require(
                    relative not in result or result[relative] == item,
                    "BINDING_CONFLICT",
                )
                result[relative] = item
        for child in value.values():
            evidence_bindings(child, result)
    elif isinstance(value, list):
        for child in value:
            evidence_bindings(child, result)


def frozen_python_pid_predicate(source_text: str, baseline: dict) -> tuple[bool, bool]:
    tree = ast.parse(source_text)
    function = next(
        node
        for node in tree.body
        if isinstance(node, ast.FunctionDef)
        and node.name == "validate_l9_child_envelope"
    )
    calls = [
        node
        for node in ast.walk(function)
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "require"
        and len(node.args) == 2
        and isinstance(node.args[1], ast.JoinedStr)
        and any(
            isinstance(part, ast.Constant) and part.value == "_VALID_CHILD_LAUNCH"
            for part in node.args[1].values
        )
    ]
    require(len(calls) == 1, "FROZEN_PYTHON_PID_PREDICATE")
    expression = ast.fix_missing_locations(ast.Expression(body=calls[0].args[0]))
    code = compile(expression, "<frozen L14 launch predicate>", "eval")
    original = eval(code, {"__builtins__": {}, "envelope": baseline})
    fixture = copy.deepcopy(baseline)
    fixture["process_id"] = fixture["worker_process_id"]
    aliased = eval(code, {"__builtins__": {}, "envelope": fixture})
    require(original is False and aliased is True, "PYTHON_PID_REPRODUCTION")
    return original, aliased


def collect_context() -> dict:
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), "ROOT")
    require(
        Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
        == ROOT.resolve(),
        "GIT_ROOT",
    )
    require(
        git("remote", "get-url", "origin").decode().strip()
        == "https://github.com/Slagathore/sporespore.git",
        "REMOTE",
    )
    closure = bound_json(CLOSURE, 19388, CLOSURE_SHA)
    require(
        git("rev-parse", CLOSURE_COMMIT + ":" + CLOSURE.relative_to(ROOT).as_posix())
        .decode()
        .strip()
        == git("hash-object", str(CLOSURE)).decode().strip(),
        "CLOSURE_GIT_BINDING",
    )
    require(
        closure["classification"] == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure["sdk1_m07_satisfied"] is False,
        "CLOSURE_DISPOSITION",
    )
    inventory: dict[str, dict] = {}
    evidence_bindings(closure["evidence_bindings"], inventory)
    require(len(inventory) == 16, "PRIMARY_CLOSURE_POPULATION")
    inventory["terminal_supervisor_failure.json"] = {
        "path": "terminal_supervisor_failure.json",
        "byte_length": 27813689,
        "raw_sha256": TERMINAL_SHA,
    }
    actual_names = {
        path.relative_to(EVIDENCE).as_posix()
        for path in EVIDENCE.rglob("*")
        if path.is_file()
    }
    require(actual_names == set(inventory), "RETAINED_POPULATION_SET")
    verified_reports = {}
    for relative, binding in inventory.items():
        raw = (EVIDENCE / relative).read_bytes()
        require(
            len(raw) == binding["byte_length"] and sha(raw) == binding["raw_sha256"],
            "RETAINED_FILE:" + relative,
        )
        if relative in {"supervisor_result.json", "terminal_supervisor_failure.json"}:
            verified_reports[relative] = raw
    require(
        sum(item["byte_length"] for item in inventory.values()) == 143907759,
        "RETAINED_BYTES",
    )

    sources, source_bindings = {}, []
    for relative in SOURCE_PATHS:
        raw = git("show", SOURCE + ":" + relative)
        sources[relative] = raw.decode("utf-8")
        source_bindings.append(
            {
                "path": relative,
                "source_commit": SOURCE,
                "git_blob": git("rev-parse", SOURCE + ":" + relative).decode().strip(),
                "byte_length": len(raw),
                "raw_sha256": sha(raw),
            }
        )
    report = json.loads(verified_reports["supervisor_result.json"])
    terminal = json.loads(verified_reports["terminal_supervisor_failure.json"])
    baseline, active_envelope = report["child_envelopes"]
    active = active_envelope["report"]
    pid = frozen_python_pid_predicate(sources[SOURCE_PATHS[3]], baseline)
    variants = re.search(
        r"pub enum RecoveryControllerOwnerV1\s*\{([^}]+)\}", sources[SOURCE_PATHS[7]]
    )
    require(variants is not None, "FROZEN_OWNER_ENUM")
    owners = [
        item.strip().lower() for item in variants.group(1).split(",") if item.strip()
    ]
    require(owners == ["none", "recovery", "stance"], "OWNER_ENUM_DOMAIN")
    require(
        'or controller_owner not in ["none", "recovery_v6"]'
        in sources[SOURCE_PATHS[5]],
        "FROZEN_OWNER_PRODUCER",
    )
    require(
        '"controller_owner": controller_owner' in sources[SOURCE_PATHS[5]],
        "FROZEN_APPLICATION_OWNER",
    )
    require(
        '"owner": String(application_intent["controller_owner"])'
        in sources[SOURCE_PATHS[6]],
        "FROZEN_COLLECTOR_OWNER_COPY",
    )
    require(
        "Test-SporeSporeProcessIsSelfOrDescendant" in sources[SOURCE_PATHS[2]]
        and "-not $processBindingValid" in sources[SOURCE_PATHS[2]],
        "FROZEN_LAUNCHER_RELATION_GUARD",
    )
    require(
        "unknown variant `recovery_v6`"
        in active["detail"]["advance"]["detail"]["detail"],
        "RETAINED_NATIVE_OWNER_REFUSAL",
    )

    # Only these host images execute in this diagnostic; no Godot is launched.
    hosts = closure["l14_exact_runtime_images"]["images"]
    require(
        Path(sys.executable).resolve()
        == Path(hosts["python_helper"]["path"]).resolve(),
        "DIAGNOSTIC_PYTHON_PATH",
    )
    for name in ("python_helper", "powershell_host"):
        binding = hosts[name]
        raw = Path(binding["path"]).read_bytes()
        require(
            len(raw) == binding["byte_length"] and sha(raw) == binding["raw_sha256"],
            "DIAGNOSTIC_HOST:" + name,
        )
    replay = subprocess.run(
        [
            hosts["powershell_host"]["path"],
            "-NoLogo",
            "-NoProfile",
            "-NonInteractive",
            "-File",
            str(ROOT / "sdk/conformance/qsdk_r10f_l15_retained_boundary_replay.ps1"),
        ],
        input=json.dumps(
            {
                "evidence_root": str(EVIDENCE),
                "supervisor_source": sources[SOURCE_PATHS[0]],
                "pair_source": sources[SOURCE_PATHS[1]],
                "report_bindings": {
                    name: inventory[name]
                    for name in (
                        "supervisor_result.json",
                        "terminal_supervisor_failure.json",
                    )
                },
            }
        ),
        capture_output=True,
        text=True,
        cwd=ROOT,
        timeout=45,
    )
    require(
        replay.returncode == 0 and not replay.stderr,
        "POWERSHELL_REPLAY:" + replay.stderr[:1000],
    )
    powershell = json.loads(replay.stdout)
    return {
        "closure": closure,
        "inventory": inventory,
        "sources": source_bindings,
        "report": report,
        "terminal": terminal,
        "active": active,
        "pid": pid,
        "owners": owners,
        "powershell": powershell,
    }


def validate_record(record: dict, context: dict) -> None:
    require(
        record["schema_version"]
        == "sporespore_qsdk_r10f_l15_retained_launch_ownership_diagnosis_v1"
        and record["gate_id"] == "QSDK-R10F"
        and record["repair_id"] == "QSDK-R10F-L15",
        "SCHEMA",
    )
    require(
        record["status"]
        == "closed_zero_world_retained_source_diagnosis_no_physical_authority",
        "STATUS",
    )
    require(
        record["ledger_scope"]
        == {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": "zero_world_retained_data_and_frozen_source_diagnosis",
            "question_class": "development",
        },
        "SCOPE",
    )
    require(
        record["source_commit"] == SOURCE
        and same(record["frozen_sources"], context["sources"]),
        "SOURCE_BINDINGS",
    )
    require(
        record["predecessor_closure"]
        == {
            "path": CLOSURE.relative_to(ROOT).as_posix(),
            "byte_length": 19388,
            "raw_sha256": CLOSURE_SHA,
            "closure_commit": CLOSURE_COMMIT,
        },
        "PREDECESSOR",
    )
    population = record["retained_population"]
    require(
        Path(population["root"]).resolve() == EVIDENCE.resolve()
        and type(population["file_count"]) is int
        and population["file_count"] == 17
        and type(population["byte_length"]) is int
        and population["byte_length"] == 143907759,
        "POPULATION",
    )
    require(
        len(population["files"]) == 17
        and same(
            {item["path"]: item for item in population["files"]}, context["inventory"]
        ),
        "POPULATION_BINDINGS",
    )
    for key in ZERO_FIELDS:
        require(type(record[key]) is int and record[key] == 0, "ZERO:" + key)
    for key in FALSE_FIELDS:
        require(record[key] is False, "FALSE:" + key)
    observed = record["observed_attempt"]
    closed = context["closure"]
    for key in (
        "classification",
        "child_validation_errors",
        "world_build_count",
        "solver_step_count",
        "explicit_worker_extra_native_readback_count",
    ):
        require(same(observed[key], closed[key]), "OBSERVED:" + key)
    require(
        observed["parent_attempt_id"] == closed["attempt_id"]
        and observed["physical_wall_seconds"] == 3923.0628147,
        "OBSERVED_ID_OR_RECORDED_CLOCK",
    )
    active = context["active"]
    require(
        all(
            type(observed[key]) is int
            for key in (
                "active_solver_steps",
                "active_retained_trace_rows",
                "native_kick_count",
            )
        ),
        "ACTIVE_COUNTER_KIND",
    )
    require(
        observed["active_solver_steps"] == active["solver_step_count"] == 963
        and observed["active_retained_trace_rows"]
        == len(active["partial_arm"]["trace_rows"])
        == 963
        and observed["native_kick_count"]
        == active["external_kick_application_count"]
        == 1,
        "ACTIVE_COUNTS",
    )
    launch = record["launch_identity_diagnosis"]
    require(
        same(
            launch["process_ids"],
            [
                {
                    "role": item["role"],
                    "launcher": item["process_id"],
                    "worker": item["worker_process_id"],
                    "termination_protocol_valid": item["termination_protocol_valid"],
                }
                for item in context["report"]["child_envelopes"]
            ],
        ),
        "PROCESS_IDS",
    )
    require(
        launch["python_frozen_launch_predicate"]["original"] is context["pid"][0]
        and launch["python_frozen_launch_predicate"]["same_pid_fixture"]
        is context["pid"][1],
        "PYTHON_PID",
    )
    ps = context["powershell"]
    pair = launch["powershell_frozen_pair_predicate"]
    require(
        pair["frozen_pair_predicate"] == ps["frozen_pair_predicate"]
        and same(pair["results"], ps["pid_results"])
        and type(pair["actual_envelope_count"]) is int
        and pair["actual_envelope_count"] == 2
        and pair["whole_child_acceptance_inferred_from_one_predicate"] is False
        and pair["old_report_altered"] is False,
        "POWERSHELL_PID",
    )
    owner = record["ownership_diagnosis"]
    require(
        same(owner["rust_owner_values"], context["owners"])
        and owner["rejected_owner"] == "recovery_v6"
        and owner["collector_copies_application_owner_without_alias"] is True
        and same(owner["retained_native_refusal"], active["detail"])
        and owner["full_rejected_request_reconstruction_established"] is False,
        "OWNER_SCOPE",
    )
    publication = record["supervisor_output_diagnosis"]["reproduction"]
    mapping = {
        "actual_publication_tail": "publication_tail",
        "actual_caller_condition": "caller_condition",
        "mixed_output_count": "mixed_output_count",
        "mixed_output_types": "mixed_output_types",
        "reproduced_failure": "reproduced_failure",
        "return_only_output_count": "return_only_output_count",
        "return_only_reaches_expected_invalid_exit_condition": "return_only_invalid_exit_condition",
    }
    require(
        all(same(publication[key], ps[value]) for key, value in mapping.items())
        and publication["exact_retained_failure_reproduced"] is True
        and publication["old_report_ok_remains_false"] is True
        and ps["reproduced_failure"] == context["terminal"]["failure_code"]
        and publication["frozen_source_commit"] == SOURCE,
        "PUBLICATION_REPRODUCTION",
    )
    for part in (pair, publication):
        for key in (
            "model_construction_count",
            "world_build_count",
            "native_physics_read_count",
            "solver_step_count",
        ):
            require(
                type(part[key]) is int and part[key] == 0, "REPRODUCTION_ZERO:" + key
            )
        require(
            part["physical_acceptance_authority"] is False
            and part["release_authority"] is False,
            "REPRODUCTION_AUTHORITY",
        )
    require(
        type(publication["filesystem_writes"]) is int
        and publication["filesystem_writes"] == 0,
        "PUBLICATION_FILESYSTEM_WRITES",
    )
    require(
        ps["complete_supervisor_or_file_writer_invoked"] is False
        and ps["whole_child_acceptance_inferred"] is False
        and ps["historical_data_modified"] is False,
        "REPLAY_SCOPE",
    )


def main() -> int:
    record = bound_json(DATA, DATA_BYTES, DATA_SHA)
    context = collect_context()
    validate_record(record, context)
    mutations = [
        ((key,), True if key in FALSE_FIELDS else 1)
        for key in (*ZERO_FIELDS, *FALSE_FIELDS)
    ]
    mutations += [
        (("source_commit",), "0" * 40),
        (("status",), "physical_execution_authorized"),
    ]
    mutations += [
        (("predecessor_closure", "raw_sha256"), "sha256:" + "0" * 64),
        (("retained_population", "file_count"), 16),
        (("retained_population", "files", 0, "raw_sha256"), "sha256:" + "0" * 64),
        (("frozen_sources", 0, "raw_sha256"), "sha256:" + "0" * 64),
        (("observed_attempt", "classification"), "valid_complete_behavior_positive"),
        (("observed_attempt", "world_build_count"), 0),
        (("observed_attempt", "active_solver_steps"), 962),
        (("observed_attempt", "native_kick_count"), True),
        (("launch_identity_diagnosis", "process_ids", 0, "worker"), 0),
        (
            ("launch_identity_diagnosis", "python_frozen_launch_predicate", "original"),
            True,
        ),
        (
            (
                "launch_identity_diagnosis",
                "python_frozen_launch_predicate",
                "same_pid_fixture",
            ),
            False,
        ),
        (
            (
                "launch_identity_diagnosis",
                "powershell_frozen_pair_predicate",
                "results",
                0,
                "original_predicate",
            ),
            True,
        ),
        (
            (
                "launch_identity_diagnosis",
                "powershell_frozen_pair_predicate",
                "whole_child_acceptance_inferred_from_one_predicate",
            ),
            True,
        ),
        (
            ("ownership_diagnosis", "rust_owner_values"),
            ["none", "recovery", "stance", "recovery_v6"],
        ),
        (("ownership_diagnosis", "rejected_owner"), "recovery"),
        (
            ("ownership_diagnosis", "collector_copies_application_owner_without_alias"),
            False,
        ),
        (
            ("ownership_diagnosis", "full_rejected_request_reconstruction_established"),
            True,
        ),
        (("ownership_diagnosis", "retained_native_refusal", "ok"), True),
        (("supervisor_output_diagnosis", "reproduction", "mixed_output_count"), 1),
        (
            ("supervisor_output_diagnosis", "reproduction", "reproduced_failure"),
            "different failure",
        ),
        (
            ("supervisor_output_diagnosis", "reproduction", "frozen_source_commit"),
            "0" * 40,
        ),
        (
            ("supervisor_output_diagnosis", "reproduction", "model_construction_count"),
            1,
        ),
        (("supervisor_output_diagnosis", "reproduction", "filesystem_writes"), 1),
    ]
    rejected = 0
    for path, replacement in mutations:
        changed = copy.deepcopy(record)
        target = changed
        for key in path[:-1]:
            target = target[key]
        target[path[-1]] = replacement
        try:
            validate_record(changed, context)
        except (ValueError, KeyError, TypeError):
            rejected += 1
        else:
            raise ValueError("MUTATION_ACCEPTED:" + str(path))
    # Fail closed if a concurrent change touched the sealed diagnosis mid-audit.
    bound_json(DATA, DATA_BYTES, DATA_SHA)
    receipt = {
        "schema_version": "sporespore_qsdk_r10f_l15_retained_diagnosis_audit_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": record["ledger_scope"],
        "ok": True,
        "diagnosis_raw_sha256": sha(DATA.read_bytes()),
        "retained_file_count": 17,
        "retained_byte_length": 143907759,
        "frozen_source_count": 8,
        "frozen_python_pid_predicate_replayed": True,
        "frozen_powershell_pid_predicate_count": 2,
        "frozen_powershell_publication_tail_replayed": True,
        "complete_rejected_native_request_replayed": False,
        "physical_wall_clock_recomputed_from_retained_files": False,
        "mutation_rejection_count": rejected,
        **{key: 0 for key in ZERO_FIELDS},
        **{key: False for key in FALSE_FIELDS},
    }
    print(
        "QSDK_R10F_L15_RETAINED_DIAGNOSIS_AUDIT_PASS "
        + json.dumps(receipt, separators=(",", ":"), sort_keys=True)
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        subprocess.SubprocessError,
    ) as exc:
        print(
            "QSDK_R10F_L15_RETAINED_DIAGNOSIS_AUDIT_FAIL " + str(exc), file=sys.stderr
        )
        raise SystemExit(1)
