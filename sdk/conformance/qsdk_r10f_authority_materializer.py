#!/usr/bin/env python3
"""Materialize and audit the two-commit QSDK-R10F physical authority graph."""

from __future__ import annotations

import argparse
import base64
import copy
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import time
from typing import Any, Iterable, Mapping


ROOT = Path(__file__).resolve().parents[2]
if str(Path(__file__).resolve().parent) not in sys.path:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
import qsdk_r10f_l14_authority_contract as l14_authority
import qsdk_r10f_l14_qualification_components as l14_components
import qsdk_r10f_l14_runtime_binding as l14_runtime

EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EVIDENCE_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence")
DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json"
)
REPAIR_DESIGN_PATH = (
    ROOT
    / "sdk/qsdk_r10f_l14_terminal_boundary_successor_design_v1.json"
)
BRANCH_COMPLETENESS_ADDENDUM_PATH = l14_authority.addendum_audit.PATH
EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256 = l14_authority.addendum_audit.SHA256
# This permission remains historical L13 authority, not the current L14 design.
HISTORICAL_ADAPTER_PERMISSION_PATH = (
    ROOT / "sdk/qsdk_r10f_l13_walking_ledger_transport_projection_successor_design_v1.json"
)
HISTORICAL_ADAPTER_PERMISSION_SHA256 = (
    "sha256:ce85d54e7a8cc12304015f5551d4f7874ad783613cd7feb566fc63cb10b20ce9"
)
PREDECESSOR_REPAIR_DESIGN_PATH = (
    ROOT / "sdk/qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1.json"
)
MANIFEST_PATH = ROOT / "sdk/qsdk_r10f_dependency_manifest_v19.json"
DEPENDENCY_AUDIT_PATH = ROOT / "sdk/conformance/qsdk_r10f_dependency_closure.py"
SUPERVISOR_REFUSAL_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json"
)
PREDECESSOR_PHYSICAL_CLOSURE_PATH = (
    ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v14.json"
)
STAGE_RELATIVE = (
    "sdk/qsdk_r10f_development_route_ghost_" "zero_world_qualification_closure_v15.json"
)
AUTHORITY_RELATIVE = (
    "sdk/qsdk_r10f_development_route_ghost_execution_authority_v15.json"
)
WORKER_RESOURCE = "res://tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd"
EXPECTED_DESIGN_SHA256 = (
    "sha256:696cc5ee80002e39968d27c6f21fa97f9309b7f08d3caad2961699ceb7184dfa"
)
EXPECTED_REPAIR_DESIGN_BYTES = l14_authority.design_audit.DESIGN_BYTES
EXPECTED_REPAIR_DESIGN_SHA256 = l14_authority.design_audit.DESIGN_SHA256
SEED = 40200
SEED_SHA256 = "sha256:efa3c38b428cc5f2daa6b156a8e3e35769623c7c23af6f9079b1d27c66e190fa"
CAMPAIGN_ID = "QSDK-R10F-CONTINUOUS-S169-KICK-PASSIVE-FALL-RECOVERY-RESUME"
REPAIR_ID = l14_authority.REPAIR_ID
EXPECTED_SUPERVISOR_REFUSAL_BYTES = 6_486
EXPECTED_SUPERVISOR_REFUSAL_SHA256 = (
    "sha256:93e60e8fe747a8ba7a5b6a1621175ce4bf877f537a2a5d03d01ff9e186e1140f"
)
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES = l14_authority.PREDECESSOR_BYTES
EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256 = l14_authority.PREDECESSOR_SHA256
STAGE_SCHEMA = (
    "sporespore_qsdk_r10f_development_route_ghost_"
    "zero_world_qualification_closure_v15"
)
AUTHORITY_SCHEMA = (
    "sporespore_qsdk_r10f_development_route_ghost_execution_authority_v15"
)
ATTEMPT_SCHEMA = "sporespore_qsdk_r10f_zero_world_qualification_attempt_v1"
COMPLETION_SCHEMA = "sporespore_qsdk_r10f_zero_world_qualification_completion_v1"
IMPLEMENTATION_SCHEMA = "sporespore_qsdk_r10f_zero_world_implementation_audit_v1"
DEPENDENCY_MARKER = "QSDK_R10F_DEPENDENCY_CLOSURE_PASS "
SELF_TEST_MARKER = "QSDK_R10F_AUTHORITY_MATERIALIZER_SELF_TEST_PASS "
MATERIALIZED_MARKER = "QSDK_R10F_AUTHORITY_MATERIALIZED "
GRAPH_MARKER = "QSDK_R10F_COMMITTED_AUTHORITY_GRAPH_PASS "
L15_OUTPUT_MARKER = "QSDK_R10F_L15_QUALIFICATION_OUTPUT_PASS "
L15_STAGE_RELATIVE = "sdk/qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v16.json"
L15_AUTHORITY_RELATIVE = "sdk/qsdk_r10f_development_route_ghost_execution_authority_v16.json"
L15_STAGE_SCHEMA = "sporespore_qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v16"
L15_AUTHORITY_SCHEMA = "sporespore_qsdk_r10f_development_route_ghost_execution_authority_v16"
L15_PREDECESSOR_PATH = ROOT / "sdk/qsdk_r10f_development_route_ghost_physical_closure_v15.json"
L15_PREDECESSOR_BYTES = 19388
L15_PREDECESSOR_SHA256 = "sha256:f1384ecef9a846b0e0058a2535be11ba0d58a760dfe969020c20ae8efb9b3f11"


class MaterializationFailure(RuntimeError):
    """A prospective R10F authority boundary was not exact."""


def require(condition: bool, code: str) -> None:
    if not condition:
        raise MaterializationFailure(code)


def sha256_bytes(value: bytes) -> str:
    return "sha256:" + hashlib.sha256(value).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return "sha256:" + digest.hexdigest()


def is_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and re.fullmatch(r"sha256:[0-9a-f]{64}", value) is not None
    )


def is_commit(value: Any) -> bool:
    return isinstance(value, str) and re.fullmatch(r"[0-9a-f]{40}", value) is not None


def exact_int(value: Any, expected: int) -> bool:
    return isinstance(value, int) and not isinstance(value, bool) and value == expected


def read_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise MaterializationFailure(f"{label}_UNREADABLE:{exc}") from exc
    require(isinstance(value, dict), f"{label}_NOT_OBJECT")
    return value


def run(arguments: Iterable[str | Path]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        tuple(str(value) for value in arguments),
        cwd=ROOT,
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
    )


def git(*arguments: str) -> str:
    result = run(("git", *arguments))
    require(
        result.returncode == 0,
        f"GIT_FAILED:{' '.join(arguments)}:{(result.stdout + result.stderr)[-2000:]}",
    )
    return result.stdout.strip()


def parse_marker(stdout: str, marker: str, label: str) -> dict[str, Any]:
    matches = [
        line[len(marker) :] for line in stdout.splitlines() if line.startswith(marker)
    ]
    require(len(matches) == 1, f"{label}_MARKER_COUNT")
    try:
        value = json.loads(matches[0])
    except json.JSONDecodeError as exc:
        raise MaterializationFailure(f"{label}_MARKER_JSON:{exc}") from exc
    require(isinstance(value, dict), f"{label}_MARKER_NOT_OBJECT")
    return value


def file_identity(path: Path, *, relative_to: Path | None = None) -> dict[str, Any]:
    resolved = path.resolve()
    display = (
        resolved.relative_to(relative_to.resolve()).as_posix()
        if relative_to is not None
        else resolved.as_posix()
    )
    return {
        "path": display,
        "byte_length": resolved.stat().st_size,
        "raw_sha256": sha256_file(resolved),
    }


def verify_binding(binding: Any, path: Path, code: str) -> None:
    require(isinstance(binding, dict), f"{code}_NOT_OBJECT")
    expected = file_identity(path)
    require(
        binding.get("path") == expected["path"]
        and binding.get("byte_length") == expected["byte_length"]
        and binding.get("raw_sha256") == expected["raw_sha256"],
        f"{code}_IDENTITY",
    )


def write_new_json(path: Path, value: Mapping[str, Any]) -> None:
    require(not path.exists(), f"OUTPUT_ALREADY_EXISTS:{path}")
    path.parent.mkdir(parents=True, exist_ok=True)
    encoded = (json.dumps(value, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    try:
        with path.open("xb") as stream:
            stream.write(encoded)
            stream.flush()
    except FileExistsError as exc:
        raise MaterializationFailure(f"OUTPUT_ALREADY_EXISTS:{path}") from exc


def ledger_scope(authority_mode: str) -> dict[str, str]:
    return {
        "subsystem": "recovery",
        "engine_scope": "godot_jolt",
        "authority_mode": authority_mode,
        "question_class": "development",
    }


def require_zero_world(value: Mapping[str, Any], code: str) -> None:
    for counter in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "scene_tree_insertion_count",
        "native_readback_count",
        "solver_step_count",
    ):
        require(exact_int(value.get(counter), 0), f"{code}_{counter.upper()}")
    require(value.get("physics_state_modified") is False, f"{code}_PHYSICS_STATE")
    require(
        value.get("physical_acceptance_authority") is False,
        f"{code}_PHYSICAL_ACCEPTANCE",
    )
    require(value.get("release_authority") is False, f"{code}_RELEASE_AUTHORITY")


def live_source_identity() -> dict[str, Any]:
    root = Path(git("rev-parse", "--show-toplevel")).resolve()
    remote = git("remote", "get-url", "origin")
    branch = git("branch", "--show-current")
    status = git("status", "--porcelain=v1", "--untracked-files=all")
    head = git("rev-parse", "HEAD")
    tree = git("rev-parse", "HEAD^{tree}")
    origin = git("rev-parse", "origin/main")
    live_fields = git("ls-remote", "origin", "refs/heads/main").split()
    require(
        root == ROOT.resolve() == EXPECTED_ROOT.resolve()
        and remote == EXPECTED_REMOTE
        and branch == "main"
        and status == ""
        and head == origin
        and live_fields == [head, "refs/heads/main"],
        "CLEAN_PUSHED_LIVE_MAIN_REQUIRED",
    )
    return {
        "commit": head,
        "tree": tree,
        "branch": branch,
        "remote": remote,
        "origin_main_commit": origin,
        "live_main_commit": live_fields[0],
        "clean": True,
    }


def dependency_receipt(*, require_l15_sources: bool = False) -> dict[str, Any]:
    require(type(require_l15_sources) is bool, "DEPENDENCY_L15_MODE_KIND")
    if require_l15_sources:
        import qsdk_r10f_zero_world_implementation as implementation

        # Reuse the actual complete child-output reader and its independent
        # source reopening. In this component function the flag requests Git
        # membership only; it does not execute an official qualification.
        try:
            return implementation.audit_dependency(
                official_qualification=True, require_l15_sources=True
            )
        except (implementation.AuditFailure, OSError) as exc:
            raise MaterializationFailure(f"L15_DEPENDENCY_RECEIPT:{exc}") from exc
    result = run((sys.executable, "-B", DEPENDENCY_AUDIT_PATH, "--require-tracked"))
    require(
        result.returncode == 0,
        f"DEPENDENCY_AUDIT_PROCESS:{(result.stdout + result.stderr)[-3000:]}",
    )
    receipt = parse_marker(result.stdout, DEPENDENCY_MARKER, "DEPENDENCY")
    require(receipt.get("ok") is True, "DEPENDENCY_NOT_OK")
    require(receipt.get("qualification_finalized") is True, "DEPENDENCY_UNFINALIZED")
    require(receipt.get("all_qualified_paths_tracked") is True, "DEPENDENCY_UNTRACKED")
    require(
        exact_int(receipt.get("mutation_rejection_count"), 4), "DEPENDENCY_MUTATIONS"
    )
    require_zero_world(receipt, "DEPENDENCY")
    return receipt


def manifest_binding(
    *, require_l15_sources: bool = False
) -> tuple[dict[str, Any], dict[str, Any]]:
    require(type(require_l15_sources) is bool, "MANIFEST_L15_MODE_KIND")
    if require_l15_sources:
        import qsdk_r10f_dependency_closure as dependency
        import qsdk_r10f_l15_collection_retention as packet

        receipt = dependency_receipt(require_l15_sources=True)
        # Bind the exact bytes consumed here to the complete dependency result;
        # selecting v20 never changes this module's v19/v15 writer defaults.
        try:
            raw = dependency.L15_MANIFEST_PATH.read_bytes()
        except OSError as exc:
            raise MaterializationFailure(f"L15_MANIFEST_REOPEN:{exc}") from exc
        require(
            packet.same(len(raw), receipt["manifest_byte_length"])
            and sha256_bytes(raw) == receipt["manifest_raw_sha256"],
            "L15_MANIFEST_REOPEN_BINDING",
        )
        manifest = packet.parse_json(raw.decode("utf-8"))
        policy = manifest["policy"]
        require(
            packet.same(
                policy["expected_qualified_source_count"],
                receipt["qualified_source_path_count"],
            )
            and packet.same(
                policy["expected_qualified_source_path_sha256"],
                receipt["qualified_source_path_sha256"],
            ),
            "L15_MANIFEST_REOPEN_POPULATION",
        )
        return manifest, {
            "count": policy["expected_qualified_source_count"],
            "digest": policy["expected_qualified_source_path_sha256"],
        }
    manifest = read_json(MANIFEST_PATH, "MANIFEST")
    policy = manifest.get("policy")
    require(isinstance(policy, dict), "MANIFEST_POLICY")
    count = policy.get("expected_qualified_source_count")
    digest = policy.get("expected_qualified_source_path_sha256")
    require(
        manifest.get("schema_version") == "sporespore_qsdk_r10f_dependency_manifest_v19"
        and manifest.get("repair_id") == REPAIR_ID
        and manifest.get("status")
        == "prospective_complete_transitive_source_closure_zero_world"
        and isinstance(count, int)
        and not isinstance(count, bool)
        and count > 0
        and is_sha256(digest),
        "MANIFEST_UNFINALIZED",
    )
    return manifest, {"count": count, "digest": digest}


def validate_l15_qualification_inputs(
    value: Any, source_commit: str, *, require_committed_source: bool,
    checkout_commit: str | None = None,
) -> dict[str, Any]:
    """Reopen complete inputs independently of an offered qualification record.

    This read-only entry point neither changes the legacy writer selectors nor
    authenticates a completed qualification directory or a worker expectation.
    """
    import qsdk_r10f_dependency_closure as dependency
    import qsdk_r10f_l15_source_binding as l15_source

    try:
        expected = l15_source.bind_qualification_inputs(
            source_commit, require_committed_source=require_committed_source,
            checkout_commit=checkout_commit,
        )
        l15_source.validate_qualification_inputs(value, expected=expected)
    except (ValueError, OSError, dependency.ClosureFailure) as exc:
        raise MaterializationFailure(f"L15_QUALIFICATION_INPUTS:{exc}") from exc
    return expected


def validate_l15_qualification_native_result(value: Any) -> dict[str, Any]:
    """Read the full native result before deriving its prepared-context binding.

    This does not establish official origin. The enclosing directory must still
    verify source/runtime inputs, process results, completion and file bindings.
    """
    import qsdk_r10f_zero_world_implementation as implementation

    try:
        proof = implementation.validate_godot_receipt(value, require_l15_context=True)
    except implementation.AuditFailure as exc:
        raise MaterializationFailure(f"L15_QUALIFICATION_NATIVE_RESULT:{exc}") from exc
    require(type(proof) is dict, "L15_QUALIFICATION_NATIVE_CONTEXT_MISSING")
    return proof


def validate_l15_qualification_worker_parse(value: Any) -> None:
    """Read the whole emitted syntax-check output, not merely hash-shaped fields."""
    import qsdk_r10f_zero_world_implementation as implementation

    try:
        implementation.validate_l15_worker_parse_receipt(value)
    except implementation.AuditFailure as exc:
        raise MaterializationFailure(f"L15_QUALIFICATION_WORKER_PARSE:{exc}") from exc


def validate_l15_qualification_candidate_record(
    value: Any, *, expected_source_records: Any
) -> dict[str, Any]:
    """Read the entire candidate against independently reopened source records.

    This pure seam supports corruption controls without rerunning any component.
    Only the enclosing function below supplies production source expectations.
    Passing this reader proves neither official origin nor a physical route.
    """
    import qsdk_r10f_zero_world_implementation as implementation
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_component_rollup as components
    import qsdk_r10f_l15_source_binding as source_binding

    try:
        header = implementation.l15_qualification_candidate_header()
        packet.exact_keys(
            value,
            set(header)
            | {
                "source_records",
                "static_source_receipt",
                "dependency_receipt",
                "zero_world_receipt",
                "worker_parse_receipt",
                "l14_component_qualification",
                "l15_component_qualification",
                "prepared_context_integrity",
            },
            "QUALIFICATION_CANDIDATE",
        )
        require(
            packet.same({key: value[key] for key in header}, header),
            "L15_CANDIDATE_HEADER",
        )
        packet.exact_keys(
            expected_source_records,
            implementation.l15_qualification_source_record_names(),
            "CANDIDATE_EXPECTED_SOURCE_RECORDS",
        )
        inputs = expected_source_records["qualification_inputs"]
        source_binding.validate_qualification_inputs(inputs, expected=inputs)
        require(
            inputs["committed_source_required"] is False
            and expected_source_records["source"]["official_qualification"] is False,
            "L15_CANDIDATE_IS_NOT_OFFICIAL",
        )
        require(
            packet.same(value["source_records"], expected_source_records),
            "L15_CANDIDATE_COMPLETE_SOURCE_RECORDS",
        )
        require(
            packet.same(
                value["dependency_receipt"], inputs["complete_dependency_receipt"]
            ),
            "L15_CANDIDATE_COMPLETE_DEPENDENCY",
        )
        path_count = len(implementation.GDSCRIPT_PATHS)
        require(
            packet.same(
                value["static_source_receipt"],
                {
                    "unittest_case_count": 44,
                    "gdformat_path_count": path_count,
                    "gdlint_path_count": path_count,
                    "gdformat_stdout": f"{path_count} files would be left unchanged",
                    "gdlint_stdout": "Success: no problems found",
                },
            ),
            "L15_CANDIDATE_COMPLETE_STATIC_SOURCE",
        )
        context = validate_l15_qualification_native_result(value["zero_world_receipt"])
        require(
            packet.same(value["prepared_context_integrity"], context),
            "L15_CANDIDATE_CONTEXT_PROOF",
        )
        validate_l15_qualification_worker_parse(value["worker_parse_receipt"])
        l14_components.validate_receipt(value["l14_component_qualification"])
        by_path = {
            record["path"]: record for record in inputs["qualified_source_bindings"]
        }
        # Reuse the complete input key's exact checkout bytes, never the offered
        # component rollup's own source list as an expected population.
        rollup_sources = [
            {key: by_path[path][key] for key in ("path", "byte_length", "raw_sha256")}
            for path in components.SOURCE_PATHS
        ]
        components.validate_receipt(
            value["l15_component_qualification"],
            expected_source_bindings=rollup_sources,
        )
        require(
            packet.same(
                value["l15_component_qualification"]["runtime_binding"],
                inputs["runtime_binding"],
            )
            and packet.same(
                expected_source_records["runtime_identity"]["l14_exact_runtime_images"],
                inputs["runtime_binding"],
            ),
            "L15_CANDIDATE_RUNTIME_COPIES",
        )
        require(
            packet.same(
                expected_source_records["root_design_audit"]["l15_root_source_binding"],
                inputs["root_source_binding"],
            )
            and packet.same(
                expected_source_records["source_authority_preflight_receipt"][
                    "l15_root_source_binding"
                ],
                inputs["root_source_binding"],
            ),
            "L15_CANDIDATE_ROOT_SOURCE_COPIES",
        )
        return context
    except (
        ValueError,
        KeyError,
        TypeError,
        RecursionError,
        implementation.AuditFailure,
    ) as exc:
        raise MaterializationFailure(
            f"L15_QUALIFICATION_CANDIDATE_RECORD:{exc}"
        ) from exc


def validate_l15_qualification_candidate_output(
    stdout: Any, stderr: Any, exit_code: Any, *, expected_source_records: Any
) -> tuple[dict[str, Any], bytes]:
    """Consume original process bytes and the whole result; never reopen or run.

    The separate expected records belong to the enclosing source reader. A pass
    marker, valid JSON or internally consistent hashes cannot replace them.
    The returned JSON bytes are the exact marker payload, not a reserialization.
    """
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_zero_world_implementation as implementation

    try:
        require(type(stdout) is bytes and type(stderr) is bytes, "L15_OUTPUT_BYTES")
        require(exact_int(exit_code, 0), "L15_OUTPUT_PROCESS_EXIT")
        text, errors = stdout.decode("utf-8", errors="strict"), stderr.decode(
            "utf-8", errors="strict"
        )
        marker = implementation.L15_CANDIDATE_MARKER
        # Split only transport newlines, never other Unicode separators which
        # could occur inside a JSON string. Preserve the exact payload bytes.
        lines = text.split("\n")
        matches = [
            line.removesuffix("\r")[len(marker) :]
            for line in lines
            if line.startswith(marker)
        ]
        require(len(matches) == 1, "L15_OUTPUT_MARKER_COUNT")
        for line in [
            *(line for line in lines if not line.startswith(marker)),
            *errors.split("\n"),
        ]:
            require(
                not line.startswith(
                    (
                        "ERROR:",
                        "SCRIPT ERROR:",
                        "Traceback (most recent call last):",
                        "QSDK_R10F_ZERO_WORLD_IMPLEMENTATION_FAIL ",
                        implementation.PASS_MARKER,
                    )
                ),
                "L15_OUTPUT_CONTRADICTORY_DIAGNOSTIC",
            )
        raw_json = matches[0].encode("utf-8", errors="strict")
        candidate = packet.parse_json(matches[0])
        validate_l15_qualification_candidate_record(
            candidate, expected_source_records=expected_source_records
        )
        return candidate, raw_json
    except (ValueError, RecursionError) as exc:
        raise MaterializationFailure(f"L15_OUTPUT_INVALID:{exc}") from exc


def read_l15_qualification_candidate_output(raw_request: Any) -> dict[str, Any]:
    """Actual wrapper bridge: strict input, fresh complete source read, no writes.

    Base64 is only an exact byte transport over the wrapper's stdin pipe. No
    worker observations or caller-supplied expected records establish origin.
    This bridge has no official mode and allocates no qualification directory.
    """
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_collection_context as context
    import qsdk_r10f_zero_world_implementation as implementation

    try:
        require(type(raw_request) is bytes, "L15_OUTPUT_REQUEST_BYTES")
        request = packet.parse_json(raw_request.decode("utf-8", errors="strict"))
        packet.exact_keys(
            request,
            {"source_commit", "exit_code", "stdout_base64", "stderr_base64"},
            "OUTPUT_REQUEST",
        )
        source_commit = request["source_commit"]
        require(
            type(source_commit) is str and is_commit(source_commit),
            "L15_OUTPUT_SOURCE_COMMIT",
        )
        require(exact_int(request["exit_code"], 0), "L15_OUTPUT_PROCESS_EXIT")
        streams = []
        for name in ("stdout_base64", "stderr_base64"):
            require(type(request[name]) is str, "L15_OUTPUT_BASE64_KIND")
            raw = base64.b64decode(request[name].encode("ascii"), validate=True)
            raw.decode("utf-8", errors="strict")
            require(
                base64.b64encode(raw).decode("ascii") == request[name],
                "L15_OUTPUT_BASE64_CANONICAL",
            )
            streams.append(raw)
        expected = implementation.audit_l15_qualification_source_records(
            implementation.DEFAULT_GODOT, source_commit
        )
        candidate, raw_json = validate_l15_qualification_candidate_output(
            streams[0],
            streams[1],
            request["exit_code"],
            expected_source_records=expected,
        )
        runtime_text = json.dumps(
            candidate["source_records"]["runtime_identity"],
            sort_keys=True,
            separators=(",", ":"),
            allow_nan=False,
        )
        candidate_text = raw_json.decode("utf-8")
        return {
            "schema_version": "sporespore_qsdk_r10f_l15_qualification_output_reader_v1",
            "gate_id": "QSDK-R10F",
            "repair_id": "QSDK-R10F-L15",
            "ledger_scope": ledger_scope(
                "development_zero_world_qualification_output_reader"
            ),
            "ok": True,
            "source_commit": source_commit,
            "source_binding_sha256": expected["qualification_inputs"][
                "qualified_source_binding_sha256"
            ],
            "complete_candidate_validated": True,
            "complete_source_records_independently_reopened": True,
            "candidate_json": {
                "utf8_text": candidate_text,
                **context.raw_binding(candidate_text),
            },
            "runtime_identity_json": {
                "utf8_text": runtime_text,
                **context.raw_binding(runtime_text),
            },
            "prepared_context_snapshot": candidate["zero_world_receipt"][
                "l15_prepared_collection_context"
            ],
            "official_source_origin_authenticated": False,
            "qualification_or_physical_identity_created": False,
            "qualification_directory_validated": False,
            "physical_execution_authorized": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
            "physics_state_modified": False,
            **dict.fromkeys(
                (*implementation.ZERO_COUNTERS, "scene_tree_insertion_count"), 0
            ),
        }
    except (ValueError, RecursionError, implementation.AuditFailure) as exc:
        raise MaterializationFailure(f"L15_OUTPUT_REQUEST_INVALID:{exc}") from exc


L15_CAPTURE_FILES = (
    "qualification_attempt.json",
    "qualification_stdout.log",
    "qualification_stderr.log",
    "implementation_audit.json",
    "runtime_identity.json",
    "qualification_completion.json",
)


def l15_capture_header(phase: str, *, official: bool = False) -> dict[str, Any]:
    """Separate file-format contracts; serializing either allocates nothing."""
    import qsdk_r10f_zero_world_implementation as implementation

    require(phase in ("attempt", "completion", "reader"), "L15_CAPTURE_PHASE")
    require(type(official) is bool, "L15_CAPTURE_MODE_KIND")
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_"
        + ("official_qualification_" if official else "development_capture_")
        + phase
        + "_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L15",
        "ledger_scope": ledger_scope(
            "official_zero_world_qualification"
            if official
            else "development_zero_world_six_file_capture"
        ),
        "capture_phase": phase,
        "official_source_origin_authenticated": official,
        "qualification_or_physical_identity_created": official,
        "official_qualification_passed": official and phase != "attempt",
        **(
            {
                "maximum_official_qualification_attempt_count_for_source": 1,
                "same_identity_rerun_permitted": False,
            }
            if official
            else {}
        ),
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
        "physics_state_modified": False,
        **dict.fromkeys(
            (*implementation.ZERO_COUNTERS, "scene_tree_insertion_count"), 0
        ),
    }


def l15_capture_json(value: Any) -> bytes:
    return (
        json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False) + "\n"
    ).encode("utf-8")


def prepare_l15_candidate_capture(
    *, source_records: Any, official_origin: Any = None
) -> bytes:
    """Prepare actual source-bound attempt bytes BEFORE the candidate CLI runs.

    This serializer writes no file and allocates no identity. Official callers
    must independently establish the origin and retain the attempt before
    execution; the candidate itself remains development-class. Its production
    caller must retain these exact bytes before starting the process; completion
    cannot manufacture or change this earlier record from returned output.
    """
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_source_binding as binding
    import qsdk_r10f_zero_world_implementation as implementation

    packet.exact_keys(
        source_records,
        implementation.l15_qualification_source_record_names(),
        "CAPTURE_SOURCE_RECORDS",
    )
    inputs = source_records["qualification_inputs"]
    packet.exact_keys(inputs, binding.QUALIFICATION_INPUT_FIELDS, "CAPTURE_INPUTS")
    require(
        inputs["committed_source_required"] is False, "L15_CAPTURE_DEVELOPMENT_INPUTS"
    )
    if official_origin is not None:
        validate_l15_official_origin(official_origin, source_records=source_records)
    return l15_capture_json(
        {
            **l15_capture_header("attempt", official=official_origin is not None),
            "prepared_at_unix_ns": time.time_ns(),
            "source_inputs": inputs,
            **(
                {"official_origin": official_origin}
                if official_origin is not None
                else {}
            ),
        }
    )


def l15_capture_file_binding(name: str, raw: bytes) -> dict[str, Any]:
    require(
        name in L15_CAPTURE_FILES and type(raw) is bytes,
        "L15_CAPTURE_FILE_BINDING_INPUT",
    )
    return {"path": name, "byte_length": len(raw), "raw_sha256": sha256_bytes(raw)}


def validate_l15_candidate_capture_files(
    files: Any, *, expected_source_records: Any, official_origin: Any = None
) -> dict[str, Any]:
    """Validate all six original files, including their complete captured result.

    No filesystem, process, runtime image or source reopening occurs here.
    Candidate source flags stay unchanged. The official directory reader must
    supply its independently reopened origin, never one copied from these files.
    """
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_zero_world_implementation as implementation

    try:
        official = official_origin is not None
        if official:
            validate_l15_official_origin(
                official_origin, source_records=expected_source_records
            )
        packet.exact_keys(files, set(L15_CAPTURE_FILES), "CAPTURE_FILES")
        require(
            all(type(raw) is bytes for raw in files.values()),
            "L15_CAPTURE_ORIGINAL_BYTES",
        )
        packet.exact_keys(
            expected_source_records,
            implementation.l15_qualification_source_record_names(),
            "CAPTURE_EXPECTED_SOURCE_RECORDS",
        )
        attempt = packet.parse_json(
            files[L15_CAPTURE_FILES[0]].decode("utf-8", errors="strict")
        )
        completion = packet.parse_json(
            files[L15_CAPTURE_FILES[5]].decode("utf-8", errors="strict")
        )
        for value, phase, additional in (
            (
                attempt,
                "attempt",
                {"prepared_at_unix_ns", "source_inputs"}
                | ({"official_origin"} if official else set()),
            ),
            (
                completion,
                "completion",
                {
                    "prepared_at_unix_ns",
                    "completed_at_unix_ns",
                    "implementation_exit_code",
                    "source_binding_sha256",
                    "files",
                },
            ),
        ):
            header = l15_capture_header(phase, official=official)
            packet.exact_keys(
                value, set(header) | additional, "CAPTURE_" + phase.upper()
            )
            require(
                packet.same({key: value[key] for key in header}, header),
                "L15_CAPTURE_HEADER:" + phase,
            )
        if official:
            require(
                packet.same(attempt["official_origin"], official_origin),
                "L15_CAPTURE_OFFICIAL_ORIGIN",
            )
        prepared = attempt["prepared_at_unix_ns"]
        completed = completion["completed_at_unix_ns"]
        require(type(prepared) is int and prepared > 0, "L15_CAPTURE_PREPARED_TIME")
        require(
            type(completed) is int and completed >= prepared,
            "L15_CAPTURE_COMPLETED_TIME",
        )
        require(
            packet.same(completion["prepared_at_unix_ns"], prepared),
            "L15_CAPTURE_PREPARED_TIME_COPY",
        )
        require(
            packet.same(
                attempt["source_inputs"],
                expected_source_records["qualification_inputs"],
            ),
            "L15_CAPTURE_PRE_EXECUTION_SOURCE_INPUTS",
        )
        require(
            packet.same(
                completion["source_binding_sha256"],
                attempt["source_inputs"]["qualified_source_binding_sha256"],
            ),
            "L15_CAPTURE_SOURCE_KEY",
        )
        require(
            packet.same(
                completion["files"],
                [
                    l15_capture_file_binding(name, files[name])
                    for name in L15_CAPTURE_FILES[:5]
                ],
            ),
            "L15_CAPTURE_ALL_FIVE_FILE_BINDINGS",
        )
        candidate, original_json = validate_l15_qualification_candidate_output(
            files["qualification_stdout.log"],
            files["qualification_stderr.log"],
            completion["implementation_exit_code"],
            expected_source_records=expected_source_records,
        )
        require(
            files["implementation_audit.json"] == original_json,
            "L15_CAPTURE_IMPLEMENTATION_ORIGINAL_BYTES",
        )
        runtime = packet.parse_json(
            files["runtime_identity.json"].decode("utf-8", errors="strict")
        )
        require(
            packet.same(runtime, candidate["source_records"]["runtime_identity"]),
            "L15_CAPTURE_COMPLETE_RUNTIME_COPY",
        )
        return {
            **l15_capture_header("reader", official=official),
            "ok": True,
            "complete_file_count": 6,
            "complete_files": [
                l15_capture_file_binding(name, files[name])
                for name in L15_CAPTURE_FILES
            ],
            "original_candidate_source_flags_preserved": True,
            "prepared_context_snapshot": candidate["zero_world_receipt"][
                "l15_prepared_collection_context"
            ],
        }
    except (ValueError, KeyError, TypeError, RecursionError) as exc:
        raise MaterializationFailure(f"L15_CAPTURE_INVALID:{exc}") from exc


def complete_l15_candidate_capture(
    attempt_bytes: Any,
    stdout: Any,
    stderr: Any,
    exit_code: Any,
    *,
    expected_source_records: Any,
    official_origin: Any = None,
) -> dict[str, bytes]:
    """Assemble the actual output files, binding the unchanged earlier attempt.

    Completion is returned only after the entire six-file reader accepts the
    result. This pure producer writes no files. Only the official lifecycle may
    supply an independently authenticated official origin.
    """
    import qsdk_r10f_l15_collection_retention as packet

    try:
        require(type(attempt_bytes) is bytes, "L15_CAPTURE_ATTEMPT_BYTES")
        attempt = packet.parse_json(attempt_bytes.decode("utf-8", errors="strict"))
        candidate, raw_json = validate_l15_qualification_candidate_output(
            stdout, stderr, exit_code, expected_source_records=expected_source_records
        )
        files = {
            "qualification_attempt.json": attempt_bytes,
            "qualification_stdout.log": stdout,
            "qualification_stderr.log": stderr,
            "implementation_audit.json": raw_json,
            "runtime_identity.json": l15_capture_json(
                candidate["source_records"]["runtime_identity"]
            ),
        }
        files["qualification_completion.json"] = l15_capture_json(
            {
                **l15_capture_header(
                    "completion", official=official_origin is not None
                ),
                "prepared_at_unix_ns": attempt["prepared_at_unix_ns"],
                "completed_at_unix_ns": time.time_ns(),
                "implementation_exit_code": exit_code,
                "source_binding_sha256": expected_source_records[
                    "qualification_inputs"
                ]["qualified_source_binding_sha256"],
                "files": [
                    l15_capture_file_binding(name, files[name])
                    for name in L15_CAPTURE_FILES[:5]
                ],
            }
        )
        validate_l15_candidate_capture_files(
            files,
            expected_source_records=expected_source_records,
            official_origin=official_origin,
        )
        return files
    except (ValueError, KeyError, TypeError, RecursionError) as exc:
        raise MaterializationFailure(f"L15_CAPTURE_ASSEMBLY_INVALID:{exc}") from exc


def l15_candidate_capture_directory(source_inputs: Any) -> Path:
    """A separate development location, never an official qualification identity."""
    digest = source_inputs["qualified_source_binding_sha256"]
    source_commit = source_inputs["source_commit"]
    require(
        type(digest) is str and is_sha256(digest), "L15_CAPTURE_DIRECTORY_SOURCE_KEY"
    )
    require(
        type(source_commit) is str and is_commit(source_commit),
        "L15_CAPTURE_DIRECTORY_SOURCE_COMMIT",
    )
    return EVIDENCE_ROOT / (
        "qsdk-r10f-l15-development-capture-" + source_commit[:12] + "-" + digest[7:23]
    )


def validate_l15_official_origin(origin: Any, *, source_records: Any) -> None:
    """Check the entire independent origin against the unchanged candidate inputs.

    This is a pure comparison seam, not authentication by itself. Production
    callers below obtain the expected value from live Git and committed bytes.
    """
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_source_binding as binding

    packet.exact_keys(
        origin, {"source", "qualification_inputs", "operation_lock"}, "OFFICIAL_ORIGIN"
    )
    lock = origin["operation_lock"]
    fixed_lock = {
        "schema_version": "sporespore_locomotion_operation_lock_receipt_v1",
        "acquired": True,
        "role": "qualification",
        "mutex_name": "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1",
        "abandoned_owner_recovered": False,
        "test_only": False,
        "physical_acceptance_authority": False,
    }
    packet.exact_keys(
        lock,
        set(fixed_lock)
        | {"created_new", "owner_process_id", "owner_session_id", "acquired_utc"},
        "OFFICIAL_OPERATION_LOCK",
    )
    require(
        packet.same({key: lock[key] for key in fixed_lock}, fixed_lock)
        and type(lock["created_new"]) is bool
        and type(lock["owner_process_id"]) is int
        and lock["owner_process_id"] > 0
        and type(lock["owner_session_id"]) is int
        and lock["owner_session_id"] >= 0
        and type(lock["acquired_utc"]) is str
        and bool(lock["acquired_utc"]),
        "L15_OFFICIAL_OPERATION_LOCK",
    )
    inputs = origin["qualification_inputs"]
    packet.exact_keys(inputs, binding.QUALIFICATION_INPUT_FIELDS, "OFFICIAL_INPUTS")
    candidate_inputs = source_records["qualification_inputs"]
    require(
        inputs["committed_source_required"] is True
        and inputs["all_source_git_projections_equal_commit"] is True
        and inputs["changed_or_uncommitted_source_paths"] == []
        and inputs["complete_dependency_receipt"]["tracked_source_required"] is True
        and inputs["complete_dependency_receipt"]["all_qualified_paths_tracked"]
        is True,
        "L15_OFFICIAL_COMMITTED_INPUTS",
    )
    # Only checking mode differs: every actual source, runtime and dependency
    # byte stays identical. Never alter flags in the retained candidate record.
    projection = copy.deepcopy(inputs)
    projection["committed_source_required"] = False
    projection["complete_dependency_receipt"]["tracked_source_required"] = False
    require(packet.same(projection, candidate_inputs), "L15_OFFICIAL_INPUT_PROJECTION")
    source = origin["source"]
    expected = {
        "source_commit": inputs["source_commit"],
        "source_tree": inputs["source_tree"],
        "source_branch": "main",
        "source_clean": True,
        "source_origin_main_equal": True,
        "source_live_main_equal": True,
        "source_live_main_commit": inputs["source_commit"],
        "official_qualification": True,
    }
    require(packet.same(source, expected), "L15_OFFICIAL_CLEAN_PUSHED_SOURCE")
    expected.update(
        source_live_main_equal=False,
        source_live_main_commit="",
        official_qualification=False,
    )
    require(
        packet.same(source_records["source"], expected),
        "L15_OFFICIAL_CANDIDATE_SOURCE",
    )


def reopen_l15_official_origin(
    source_records: Any, *, retained_operation_lock: Any = None
) -> dict[str, Any]:
    """Reopen the original source, with live-owner or historical-receipt semantics.

    Prepare/complete require the live wrapper parent. A completed-directory
    reader preserves the original lock receipt without requiring its owner to
    stay alive forever; it independently rechecks the clean pushed source.
    """
    import os
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_source_binding as binding
    import qsdk_r10f_zero_world_implementation as implementation

    def inspect_origin_source():
        if retained_operation_lock is None:
            return implementation.inspect_source(official_qualification=True)
        identity = live_source_identity()
        return {
            "source_commit": identity["commit"], "source_tree": identity["tree"],
            "source_branch": identity["branch"], "source_clean": True,
            "source_origin_main_equal": True, "source_live_main_equal": True,
            "source_live_main_commit": identity["live_main_commit"],
            "official_qualification": True,
        }

    source = inspect_origin_source()
    origin = {
        "source": source,
        "qualification_inputs": binding.bind_qualification_inputs(
            source["source_commit"], require_committed_source=True
        ),
        "operation_lock": retained_operation_lock if retained_operation_lock is not None else packet.parse_json(
            os.environ.get("SPORESPORE_QSDK_R10F_QUALIFICATION_OWNER_JSON", "")
        ),
    }
    validate_l15_official_origin(origin, source_records=source_records)
    if retained_operation_lock is None:
        require(
            origin["operation_lock"]["owner_process_id"] == os.getppid(),
            "L15_OFFICIAL_WRAPPER_PARENT",
        )
    require(
        source == inspect_origin_source(),
        "L15_OFFICIAL_SOURCE_DRIFT",
    )
    return origin


def l15_official_qualification_directory(source_commit: str) -> Path:
    require(is_commit(source_commit), "L15_OFFICIAL_SOURCE_COMMIT")
    return EVIDENCE_ROOT / (
        "qsdk-r10f-l15-zero-world-qualification-" + source_commit[:12]
    )


def write_l15_capture_bytes(path: Path, raw: bytes) -> None:
    """Create once; preserve even incomplete or failed qualification outputs."""
    import os

    with path.open("xb") as stream:
        stream.write(raw)
        stream.flush()
        os.fsync(stream.fileno())


def prepare_l15_official_qualification(source_commit: str) -> dict[str, Any]:
    import qsdk_r10f_zero_world_implementation as implementation

    path = l15_official_qualification_directory(source_commit)
    require(not path.exists(), "L15_QUALIFICATION_IDENTITY_ALREADY_CONSUMED")
    records = implementation.audit_l15_qualification_source_records(
        implementation.DEFAULT_GODOT, source_commit
    )
    origin = reopen_l15_official_origin(records)
    raw = prepare_l15_candidate_capture(source_records=records, official_origin=origin)
    # Exclusive creation, after source checks and before the candidate starts.
    # Even a write failure leaves the directory consumed; it is never removed.
    path.mkdir()
    write_l15_capture_bytes(path / L15_CAPTURE_FILES[0], raw)
    return {
        **l15_capture_header("attempt", official=True),
        "ok": True,
        "source_commit": source_commit,
        "output_root": path.as_posix(),
        "attempt": l15_capture_file_binding(L15_CAPTURE_FILES[0], raw),
    }


def read_l15_capture_population(path: Path, names: tuple[str, ...]) -> dict[str, bytes]:
    require(path.is_dir() and not path.is_symlink(), "L15_QUALIFICATION_DIRECTORY_KIND")
    entries = list(path.iterdir())
    require(
        {entry.name for entry in entries} == set(names)
        and len(entries) == len(names)
        and all(entry.is_file() and not entry.is_symlink() for entry in entries),
        "L15_QUALIFICATION_DIRECTORY_POPULATION",
    )
    return {name: (path / name).read_bytes() for name in names}


def complete_l15_official_qualification(
    source_commit: str, exit_code: int
) -> dict[str, Any]:
    import qsdk_r10f_zero_world_implementation as implementation

    path = l15_official_qualification_directory(source_commit)
    original = read_l15_capture_population(path, L15_CAPTURE_FILES[:3])
    records = implementation.audit_l15_qualification_source_records(
        implementation.DEFAULT_GODOT, source_commit
    )
    origin = reopen_l15_official_origin(records)
    files = complete_l15_candidate_capture(
        original[L15_CAPTURE_FILES[0]],
        original[L15_CAPTURE_FILES[1]],
        original[L15_CAPTURE_FILES[2]],
        exit_code,
        expected_source_records=records,
        official_origin=origin,
    )
    require(
        original == read_l15_capture_population(path, L15_CAPTURE_FILES[:3]),
        "L15_QUALIFICATION_OUTPUT_DRIFT",
    )
    # Completion is last. A failure midway retains the incomplete population.
    for name in L15_CAPTURE_FILES[3:]:
        write_l15_capture_bytes(path / name, files[name])
    retained = read_l15_capture_population(path, L15_CAPTURE_FILES)
    require(retained == files, "L15_QUALIFICATION_RETAINED_BYTE_DRIFT")
    proof = validate_l15_candidate_capture_files(
        retained, expected_source_records=records, official_origin=origin
    )
    return {**proof, "source_commit": source_commit, "output_root": path.as_posix()}


def read_l15_official_qualification(source_commit: str) -> dict[str, Any]:
    """Reopen the complete official population from its original source checkout.

    This deliberately requires the original source HEAD. Later freeze/authority
    checkouts use read_l15_qualified_graph_checkpoint and its complete input key.
    """
    import qsdk_r10f_zero_world_implementation as implementation
    import qsdk_r10f_l15_collection_retention as packet

    path = l15_official_qualification_directory(source_commit)
    files = read_l15_capture_population(path, L15_CAPTURE_FILES)
    records = implementation.audit_l15_qualification_source_records(
        implementation.DEFAULT_GODOT, source_commit, qualification_capture=True
    )
    attempt = packet.parse_json(files[L15_CAPTURE_FILES[0]].decode("utf-8"))
    origin = reopen_l15_official_origin(
        records, retained_operation_lock=attempt["official_origin"]["operation_lock"]
    )
    proof = validate_l15_candidate_capture_files(
        files, expected_source_records=records, official_origin=origin
    )
    require(
        files == read_l15_capture_population(path, L15_CAPTURE_FILES),
        "L15_QUALIFICATION_DIRECTORY_CHANGED_DURING_READ",
    )
    return {**proof, "source_commit": source_commit, "output_root": path.as_posix()}


def l15_checkpoint_from_reader(proof: Any, source_commit: str) -> dict[str, Any]:
    """Derive the future consumers' expectation from the validated native capture."""
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_collection_context as context
    import qsdk_r10f_physical_closure as closer

    header = {
        **l15_capture_header("reader", official=True), "ok": True,
        "complete_file_count": 6, "original_candidate_source_flags_preserved": True,
        "source_commit": source_commit,
        "output_root": l15_official_qualification_directory(source_commit).as_posix(),
    }
    packet.exact_keys(proof, set(header) | {"complete_files", "prepared_context_snapshot"},
                      "QUALIFICATION_CHECKPOINT_READER")
    require(packet.same({key: proof[key] for key in header}, header),
            "L15_CHECKPOINT_OFFICIAL_READER_REQUIRED")
    require(type(proof["complete_files"]) is list and len(proof["complete_files"]) == 6,
            "L15_CHECKPOINT_COMPLETE_FILES")
    for name, identity in zip(L15_CAPTURE_FILES, proof["complete_files"]):
        packet.exact_keys(identity, {"path", "byte_length", "raw_sha256"}, "CHECKPOINT_FILE")
        require(identity["path"] == name and type(identity["byte_length"]) is int
                and identity["byte_length"] >= 0 and is_sha256(identity["raw_sha256"]),
                "L15_CHECKPOINT_FILE_IDENTITY")
    snapshot = proof["prepared_context_snapshot"]
    text = packet.verify_bytes(snapshot).decode("utf-8")
    context.validate_capture(text, expected_raw_binding={
        key: snapshot[key] for key in ("utf8_byte_length", "raw_sha256")
    }, canonical_sha256=closer.canonical_sha256_v1)
    capture = packet.parse_json(text)
    identity = packet.parse_json(packet.verify_bytes(capture["expected_identity"]).decode("utf-8"))
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_qualification_checkpoint_v1",
        "gate_id": "QSDK-R10F", "repair_id": "QSDK-R10F-L15",
        "ledger_scope": ledger_scope("qualified_source_context_checkpoint"),
        "source_commit": source_commit,
        "qualification_reader": proof,
        "l15_prepared_context_expectation": {
            "raw_capture_binding": {key: snapshot[key] for key in ("utf8_byte_length", "raw_sha256")},
            "collection_identity": identity,
        },
        "qualification_rerun": False,
        "physical_execution_authorized": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def create_l15_qualification_checkpoint(source_commit: str) -> dict[str, Any]:
    """Read the complete official population before the source-only freeze write.

    The caller embeds this returned checkpoint in the one permitted v16 freeze
    artifact. No checkpoint or physical identity is written by this function.
    """
    return l15_checkpoint_from_reader(read_l15_official_qualification(source_commit), source_commit)


def read_l15_qualified_graph_checkpoint(
    source_commit: str, *, checkout_commit: str
) -> dict[str, Any]:
    """Reuse an exact qualification after only the declared authority-only commits.

    The immutable freeze binds all six original files and the full reader
    result. Reopen the complete implementation/runtime input key and all six
    files; never substitute a new candidate or rerun qualification here. This
    checks qualification reuse only, not the physical declaration/authority.
    """
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_source_binding as binding

    graph = binding.qualified_checkout_context(source_commit, checkout_commit=checkout_commit)
    require(graph["phase"] in ("freeze", "authority"), "L15_CHECKPOINT_GRAPH_PHASE")
    stage_path = ROOT / binding.QUALIFIED_GRAPH_PATHS[0]
    stage = packet.parse_json(stage_path.read_bytes().decode("utf-8"))
    require(
        stage.get("schema_version") == "sporespore_qsdk_r10f_development_route_ghost_zero_world_qualification_closure_v16"
        and stage.get("repair_id") == "QSDK-R10F-L15"
        and stage.get("source_commit") == source_commit,
        "L15_CHECKPOINT_STAGE_IDENTITY",
    )
    checkpoint = stage["l15_qualification_checkpoint"]
    path = l15_official_qualification_directory(source_commit)
    files = read_l15_capture_population(path, L15_CAPTURE_FILES)
    proof = checkpoint["qualification_reader"]
    require(packet.same(proof["complete_files"], [
        l15_capture_file_binding(name, files[name]) for name in L15_CAPTURE_FILES
    ]), "L15_CHECKPOINT_IMMUTABLE_FILE_POPULATION")
    attempt = packet.parse_json(files[L15_CAPTURE_FILES[0]].decode("utf-8"))
    origin = attempt["official_origin"]
    validate_l15_qualification_inputs(
        origin["qualification_inputs"], source_commit, require_committed_source=True,
        checkout_commit=checkout_commit,
    )
    # These complete source records were independently read at the original
    # source checkpoint. Their exact containing bytes are now bound by the
    # committed freeze; only the complete input key is reopened in this phase.
    candidate = packet.parse_json(files["implementation_audit.json"].decode("utf-8"))
    expected_proof = validate_l15_candidate_capture_files(
        files, expected_source_records=candidate["source_records"], official_origin=origin
    )
    expected_proof.update(source_commit=source_commit, output_root=path.as_posix())
    require(packet.same(proof, expected_proof), "L15_CHECKPOINT_COMPLETE_READER")
    require(packet.same(checkpoint, l15_checkpoint_from_reader(expected_proof, source_commit)),
            "L15_CHECKPOINT_COMPLETE_CONTEXT")
    require(files == read_l15_capture_population(path, L15_CAPTURE_FILES),
            "L15_CHECKPOINT_EVIDENCE_DRIFT")
    require(packet.same(graph, binding.qualified_checkout_context(source_commit, checkout_commit=checkout_commit)),
            "L15_CHECKPOINT_CHECKOUT_DRIFT")
    return {
        "checkpoint": checkpoint, "checkout_context": graph,
        "complete_input_key_revalidated": True, "qualification_rerun": False,
        "physical_execution_authorized": False,
    }


def read_l15_candidate_capture_directory(
    path: Path, source_commit: str
) -> dict[str, Any]:
    """Reopen the exact six-file population and all live source records read-only.

    An extra failure file, incomplete directory, nested entry or symlink refuses.
    No directory is created here, and even a valid capture remains development.
    """
    import qsdk_r10f_zero_world_implementation as implementation

    require(
        type(source_commit) is str and is_commit(source_commit),
        "L15_CAPTURE_DIRECTORY_COMMIT",
    )
    try:
        expected = implementation.audit_l15_qualification_source_records(
            implementation.DEFAULT_GODOT, source_commit
        )
        require(
            path.resolve()
            == l15_candidate_capture_directory(
                expected["qualification_inputs"]
            ).resolve(),
            "L15_CAPTURE_DIRECTORY_EXACT_PATH",
        )
        require(path.is_dir() and not path.is_symlink(), "L15_CAPTURE_DIRECTORY_KIND")
        entries = list(path.iterdir())
        require(
            len(entries) == 6
            and {entry.name for entry in entries} == set(L15_CAPTURE_FILES),
            "L15_CAPTURE_DIRECTORY_POPULATION",
        )
        require(
            all(entry.is_file() and not entry.is_symlink() for entry in entries),
            "L15_CAPTURE_DIRECTORY_REGULAR_FILES",
        )
        files = {name: (path / name).read_bytes() for name in L15_CAPTURE_FILES}
        proof = validate_l15_candidate_capture_files(
            files, expected_source_records=expected
        )
        require(
            files == {name: (path / name).read_bytes() for name in L15_CAPTURE_FILES},
            "L15_CAPTURE_DIRECTORY_CHANGED_DURING_READ",
        )
        validate_l15_qualification_inputs(
            expected["qualification_inputs"],
            source_commit,
            require_committed_source=False,
        )
        return proof
    except (
        ValueError,
        KeyError,
        TypeError,
        OSError,
        implementation.AuditFailure,
    ) as exc:
        raise MaterializationFailure(f"L15_CAPTURE_DIRECTORY_INVALID:{exc}") from exc


def validate_l15_qualification_candidate(
    value: Any, source_commit: str
) -> dict[str, Any]:
    """Reopen actual complete source expectations before reading the candidate.

    No qualification directory or official identity is created or accepted here.
    Returned records are the independent reread, for pure downstream controls.
    """
    import qsdk_r10f_zero_world_implementation as implementation

    require(
        type(source_commit) is str and is_commit(source_commit),
        "L15_CANDIDATE_SOURCE_KIND",
    )
    require(type(value) is dict, "L15_CANDIDATE_RECORD_KIND")
    try:
        expected = implementation.audit_l15_qualification_source_records(
            Path(l14_runtime.IMAGES["godot_console"]["path"]), source_commit
        )
        validate_l15_qualification_candidate_record(
            value, expected_source_records=expected
        )
    except (ValueError, OSError, implementation.AuditFailure) as exc:
        raise MaterializationFailure(
            f"L15_QUALIFICATION_CANDIDATE_SOURCE:{exc}"
        ) from exc
    return expected


def validate_l13_historical_adapter_binding(
    authority: Mapping[str, Any],
    successor_binding: Mapping[str, Any],
    historical_raw: bytes,
    historical_tree_blob: str,
    current_raw_blob: str,
    qualified_source_blob: str,
) -> None:
    """Preserve the old adapter identity without declaring it current source."""
    require(
        authority.get("path") == "scripts/lab/gait/sdk_godot_jolt_adapter.gd"
        and authority.get("git_blob_oid") == "ef793ede82d63ee266ee815f2b0dd19866ef9596"
        and authority.get("byte_length") == 331_602
        and authority.get("raw_sha256")
        == "sha256:10679c11476f9b83cd23205580313caba9b348e1bee2bb8473189f8f05f61e63"
        and successor_binding.get("role")
        == "observed_l12_shared_walking_adapter_source"
        and successor_binding.get("path") == authority["path"]
        and successor_binding.get("git_blob_oid") == authority["git_blob_oid"]
        and successor_binding.get("checkout_byte_length") == authority["byte_length"]
        and successor_binding.get("checkout_raw_sha256") == authority["raw_sha256"]
        and len(historical_raw) == authority["byte_length"]
        and "sha256:" + hashlib.sha256(historical_raw).hexdigest()
        == authority["raw_sha256"]
        and historical_tree_blob == authority["git_blob_oid"]
        and is_commit(current_raw_blob)
        and current_raw_blob == qualified_source_blob
        and current_raw_blob != historical_tree_blob,
        "ROOT_DESIGN_L13_HISTORICAL_ADAPTER_BINDING",
    )


def design_binding(
    source_commit: str, *, require_l15_sources: bool = False
) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    require(type(require_l15_sources) is bool, "DESIGN_L15_MODE_KIND")
    design = read_json(DESIGN_PATH, "DESIGN")
    require(sha256_file(DESIGN_PATH) == EXPECTED_DESIGN_SHA256, "DESIGN_SHA256")
    require(
        design.get("schema_version")
        == "sporespore_qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1"
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("decision", {}).get("q_sdk_r10f_physical_execution_authorized")
        is False,
        "DESIGN_FIELDS",
    )
    authorities = design.get("bound_authorities")
    require(isinstance(authorities, list) and bool(authorities), "DESIGN_AUTHORITIES")
    require(
        design.get("authored_parent_commit")
        == "21a1019bc170c2f09125896df6b3e0934b217812"
        and sha256_file(HISTORICAL_ADAPTER_PERMISSION_PATH)
        == HISTORICAL_ADAPTER_PERMISSION_SHA256,
        "DESIGN_HISTORICAL_PARENT_AND_SUCCESSOR",
    )
    repair = read_json(HISTORICAL_ADAPTER_PERMISSION_PATH, "DESIGN_L13_SUCCESSOR")
    l14_authority.source_binding(HISTORICAL_ADAPTER_PERMISSION_PATH, source_commit)
    adapter_bindings = [
        entry
        for entry in repair["bound_authorities"]
        if entry.get("role") == "observed_l12_shared_walking_adapter_source"
    ]
    require(len(adapter_bindings) == 1, "DESIGN_L13_ADAPTER_BINDING_COUNT")
    l15_sources: dict[str, Any] = {}
    if require_l15_sources:
        import qsdk_r10f_l15_source_binding as l15_source_binding

        try:
            handoff = l15_source_binding.bind_root_sources(source_commit, design)
        except ValueError as exc:
            raise MaterializationFailure(
                "DESIGN_L15_SOURCE_HANDOFF:" + str(exc)
            ) from exc
        l15_sources = {
            pair["historical_root_authority"]["path"]: pair
            for pair in handoff["source_pairs"]
        }
    verified: list[dict[str, Any]] = []
    historical_adapter_count = 0
    for index, authority in enumerate(authorities):
        require(isinstance(authority, dict), f"DESIGN_AUTHORITY_{index}_OBJECT")
        relative = authority.get("path")
        require(
            isinstance(relative, str) and relative, f"DESIGN_AUTHORITY_{index}_PATH"
        )
        path = (ROOT / relative).resolve()
        require(path.is_file(), f"DESIGN_AUTHORITY_{index}_MISSING")
        if relative in l15_sources:
            # The old authority is still returned unchanged. The opt-in helper
            # separately checked its frozen bytes and exact successor source.
            require(
                authority == l15_sources[relative]["historical_root_authority"],
                f"DESIGN_AUTHORITY_{index}_L15_HISTORICAL_BINDING",
            )
            verified.append(dict(authority))
            continue
        if relative == "scripts/lab/gait/sdk_godot_jolt_adapter.gd":
            historical = subprocess.run(
                ["git", "cat-file", "blob", str(authority["git_blob_oid"])],
                cwd=ROOT,
                capture_output=True,
                check=False,
                timeout=30,
            )
            require(historical.returncode == 0, "DESIGN_HISTORICAL_ADAPTER_BLOB_READ")
            validate_l13_historical_adapter_binding(
                authority,
                adapter_bindings[0],
                historical.stdout,
                git("rev-parse", f"{design['authored_parent_commit']}:{relative}"),
                git("hash-object", "--no-filters", "--", relative),
                git("rev-parse", f"{source_commit}:{relative}"),
            )
            historical_adapter_count += 1
            verified.append(dict(authority))
            continue
        require(
            authority.get("byte_length") == path.stat().st_size
            and authority.get("raw_sha256") == sha256_file(path)
            and authority.get("git_blob_oid")
            == git("rev-parse", f"{source_commit}:{relative}"),
            f"DESIGN_AUTHORITY_{index}_IDENTITY",
        )
        verified.append(dict(authority))
    require(historical_adapter_count == 1, "DESIGN_HISTORICAL_ADAPTER_COUNT")
    return design, verified


def _l8_repair_design_binding_retired(source_commit: str) -> dict[str, Any]:
    design = read_json(REPAIR_DESIGN_PATH, "REPAIR_DESIGN")
    predecessor = design.get("predecessor_design")
    consumed = design.get("consumed_l7_physical_closure")
    diagnosis = design.get("retained_diagnosis")
    change = design.get("controlled_change")
    envelope = design.get("bounded_execution_envelope")
    sequence = design.get("forward_authority_sequence")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES
        and sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256
        and design.get("schema_version")
        == "sporespore_qsdk_r10f_l8_integer_valued_native_step_domain_successor_design_v1"
        and design.get("status") == "prospective_zero_world_implementation_authorized"
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("campaign_role") == "development_route_ghost"
        and design.get("question_class") == "development"
        and isinstance(predecessor, dict)
        and predecessor.get("path")
        == PREDECESSOR_REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
        and predecessor.get("byte_length")
        == PREDECESSOR_REPAIR_DESIGN_PATH.stat().st_size
        and predecessor.get("raw_sha256")
        == "sha256:1f1288acb506c39347e33ca6c6f0c86749caaf955f83dce71836cd8100f98c3b"
        and predecessor.get("repair_id") == "QSDK-R10F-L7"
        and predecessor.get("superseded") is False
        and isinstance(consumed, dict)
        and consumed.get("path")
        == PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
        and consumed.get("byte_length")
        == PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        and consumed.get("raw_sha256") == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and consumed.get("attempt_id") == "0485211cfa1049e6bdee374b406d0c32"
        and consumed.get("solver_step_count") == 2
        and consumed.get("global_lockstep_solver_frame_count") == 1
        and consumed.get("same_identity_rerun_permitted") is False
        and isinstance(diagnosis, dict)
        and diagnosis.get("recovery_memory_last_semantic_step_runtime_kind")
        == "binary64"
        and diagnosis.get("disposition_recovery_step_global_semantic_step_runtime_kind")
        == "integer"
        and diagnosis.get("numeric_values_equal") is True
        and diagnosis.get("independent_retained_receipt_validation_passed") is True
        and diagnosis.get("l7_validator_rejected_integer_valued_binary64") is True
        and isinstance(change, dict)
        and change.get("mechanism") == "integer_valued_native_step_domain_validation_v1"
        and change.get("source_field") == "recovery_memory.last_semantic_step"
        and exact_int(change.get("minimum_accepted_step"), 1)
        and exact_int(change.get("maximum_accepted_step"), 3842)
        and change.get("preserve_original_source_number_kind_in_receipt") is True
        and change.get("physical_closure_must_independently_validate_number_kind")
        is True
        and all(
            change.get(key) is False
            for key in (
                "cast_or_rewrite_source_measurement_permitted",
                "canonical_digest_policy_changed",
                "other_discrete_fields_relaxed",
                "fractional_step_permitted",
                "nonfinite_step_permitted",
                "boolean_step_permitted",
                "string_step_permitted",
                "null_step_permitted",
                "out_of_domain_step_permitted",
                "mismatched_integer_valued_step_permitted",
                "outcome_derived_step_correction_permitted",
            )
        )
        and isinstance(envelope, dict)
        and exact_int(envelope.get("maximum_development_campaign_attempt_count"), 1)
        and exact_int(envelope.get("maximum_world_count"), 2)
        and exact_int(envelope.get("maximum_solver_steps_per_arm"), 3842)
        and exact_int(envelope.get("maximum_total_solver_steps"), 7684)
        and exact_int(envelope.get("solver_budget_delta_from_l7"), 0)
        and envelope.get("same_identity_rerun_permitted") is False
        and isinstance(sequence, dict)
        and sequence.get("physical_execution_authorized_by_design") is False
        and isinstance(claim, dict)
        and claim.get("zero_world_implementation_authorized") is True
        and claim.get("physical_execution_authorized") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and claim.get("sdk1_m07_satisfied") is False
        and isinstance(decision, dict)
        and decision.get("selected_repair_id") == REPAIR_ID,
        "REPAIR_DESIGN_FIELDS",
    )
    relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(REPAIR_DESIGN_PATH)),
        "REPAIR_DESIGN_SOURCE_BLOB",
    )
    binding = file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": design["status"],
            "repair_id": REPAIR_ID,
            "positive_control_count": 6,
            "negative_control_count": 16,
            "minimum_accepted_step": 1,
            "maximum_accepted_step": 3842,
            "maximum_solver_steps_per_arm": 3842,
            "maximum_total_solver_steps": 7684,
            "source_number_kind_preserved": True,
            "physical_execution_authorized_by_design": False,
        }
    )
    return binding


def _l12_repair_design_binding_retired(source_commit: str) -> dict[str, Any]:
    """Retained L12 binding; superseded by the active L13 binding below."""
    design = read_json(REPAIR_DESIGN_PATH, "L12_REPAIR_DESIGN")
    authorities_value = design.get("bound_authorities")
    change = design.get("controlled_change")
    frozen = design.get("frozen_behavioral_terms")
    population = design.get("prospective_development_population")
    positives = design.get("required_positive_zero_world_controls")
    negatives = design.get("required_negative_zero_world_controls")
    claim = design.get("claim_boundary")
    decision = design.get("decision")
    require(
        REPAIR_DESIGN_PATH.stat().st_size == EXPECTED_REPAIR_DESIGN_BYTES
        and sha256_file(REPAIR_DESIGN_PATH) == EXPECTED_REPAIR_DESIGN_SHA256
        and design.get("schema_version")
        == "sporespore_qsdk_r10f_l12_walking_actuation_handoff_successor_design_v1"
        and design.get("status")
        == (
            "prospective_zero_world_successor_design_complete_"
            "implementation_authorized_physics_blocked"
        )
        and design.get("gate_id") == "QSDK-R10F"
        and design.get("repair_id") == REPAIR_ID
        and design.get("parent_repair_id") == "QSDK-R10F-L11"
        and design.get("design_id")
        == "QSDK-R10F-L12-WALKING-ACTUATION-OWNERSHIP-HANDOFF"
        and isinstance(authorities_value, list)
        and len(authorities_value) == 8
        and isinstance(change, dict)
        and change.get("change_class")
        == "r10f_walking_actuation_ownership_handoff_and_existing_host_cap_binding_only"
        and change.get("mechanism") == "walking_actuation_ownership_handoff_v1"
        and change.get("covered_evaluation_segments")
        == ["walking_prefix", "matched_continuation", "walking_resume"]
        and exact_int(change.get("motor_enable_write_count_per_fresh_session"), 8)
        and exact_int(change.get("zero_target_write_count_per_fresh_session"), 8)
        and exact_int(change.get("handoff_solver_step_count"), 0)
        and change.get("existing_complete_override_interface_used") is True
        and change.get("extra_solver_step_inserted") is False
        and change.get("release_step_changed") is False
        and change.get("release_motors_disabled_invariant_changed") is False
        and change.get("shared_adapter_enable_behavior_changed") is False
        and change.get("shared_adapter_cap_resolution_behavior_changed") is False
        and change.get("published_actuator_profile_changed") is False
        and change.get("selected_host_cap_changed_from_r69") is False
        and change.get("new_tolerance_or_margin_added") is False
        and change.get("raw_measurement_clamped") is False
        and change.get("threshold_changed") is False
        and change.get("controller_changed") is False
        and change.get("selected_policy_changed") is False
        and change.get("outcome_derived_correction") is False
        and isinstance(frozen, dict)
        and frozen.get("ordered_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and frozen.get("one_arm_per_child_process") is True
        and frozen.get("one_world_per_child_process") is True
        and exact_int(frozen.get("maximum_child_process_count"), 2)
        and exact_int(frozen.get("maximum_world_count_per_child"), 1)
        and exact_int(frozen.get("maximum_total_world_count"), 2)
        and exact_int(frozen.get("maximum_solver_steps_per_child"), 3842)
        and exact_int(frozen.get("maximum_total_solver_steps"), 7684)
        and frozen.get("force_aware_recovery") is False
        and isinstance(population, dict)
        and exact_int(population.get("maximum_campaign_attempt_count"), 1)
        and exact_int(population.get("maximum_child_process_count"), 2)
        and exact_int(population.get("maximum_total_world_build_count"), 2)
        and exact_int(population.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(population.get("maximum_total_solver_step_count"), 7684)
        and population.get("both_child_reports_required_for_any_pair_outcome") is True
        and population.get(
            "any_invalid_or_incomplete_child_forces_no_behavioral_conclusion"
        )
        is True
        and isinstance(positives, list)
        and len(positives) == len(set(positives)) == 13
        and isinstance(negatives, list)
        and len(negatives) == len(set(negatives)) == 19
        and isinstance(claim, dict)
        and claim.get("zero_world_implementation_authorized") is True
        and claim.get("physical_execution_authorized") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(decision, dict)
        and decision.get("selected_repair_id") == REPAIR_ID
        and decision.get("selected_successor_kind")
        == (
            "r10f_walking_actuation_ownership_handoff_"
            "with_qualified_host_cap_binding"
        ),
        "L12_REPAIR_DESIGN_FIELDS",
    )
    authorities = {
        value.get("role"): value
        for value in authorities_value
        if isinstance(value, dict) and isinstance(value.get("role"), str)
    }
    require(
        set(authorities)
        == {
            "consumed_l11_physical_closure",
            "l11_release_owner_projection_design",
            "qualified_r69_host_cap_projection_contract",
            "qualified_r69_zero_world_projection_population",
            "observed_l11_worker_source",
            "observed_l11_locomotion_facade_source",
            "observed_l11_shared_walking_adapter_source",
            "observed_l11_recovery_world_host_cap_source",
        },
        "L12_REPAIR_DESIGN_BOUND_AUTHORITY_SET",
    )
    for role, path in (
        ("consumed_l11_physical_closure", PREDECESSOR_PHYSICAL_CLOSURE_PATH),
        ("l11_release_owner_projection_design", PREDECESSOR_REPAIR_DESIGN_PATH),
        (
            "qualified_r69_host_cap_projection_contract",
            ROOT
            / "sdk/recovery/r24d69_godot_native_effective_impulse_limit_contract_v1.json",
        ),
        (
            "qualified_r69_zero_world_projection_population",
            ROOT
            / (
                "sdk/recovery/r24d69_godot_native_effective_impulse_limit_"
                "zero_world_qualification_closure_v1.json"
            ),
        ),
    ):
        declared = authorities[role]
        require(
            declared.get("path") == path.relative_to(ROOT).as_posix()
            and declared.get("byte_length") == path.stat().st_size
            and declared.get("raw_sha256") == sha256_file(path)
            and declared.get("git_blob_oid") == git("hash-object", str(path)),
            f"L12_REPAIR_DESIGN_{role.upper()}_IDENTITY",
        )
    historical = {
        "observed_l11_worker_source": (
            "tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd",
            "5c13fb1c50b1aa24d0e63456c6dd6bdacce86015",
        ),
        "observed_l11_locomotion_facade_source": (
            "sdk/adapters/godot/gdscript/"
            "qsdk_r10f_recovery_native_locomotion_facade_v1.gd",
            "2615ba0921675fecaeff0f9d59c7cf392a8b3e13",
        ),
        "observed_l11_shared_walking_adapter_source": (
            "scripts/lab/gait/sdk_godot_jolt_adapter.gd",
            "ef793ede82d63ee266ee815f2b0dd19866ef9596",
        ),
        "observed_l11_recovery_world_host_cap_source": (
            "sdk/adapters/godot/gdscript/recovery_native_world_v1.gd",
            "c418010d7dd22baf00af8ad6f4cd9f0b870957f0",
        ),
    }
    for role, (relative, expected_blob) in historical.items():
        declared = authorities[role]
        historical_commit = "02f7b554a29ed80ad55d9d21930f23a267c07273"
        require(
            declared.get("path") == relative
            and declared.get("source_commit") == historical_commit
            and declared.get("git_blob_oid") == expected_blob
            and git("rev-parse", f"{historical_commit}:{relative}") == expected_blob,
            f"L12_REPAIR_DESIGN_{role.upper()}_HISTORICAL_IDENTITY",
        )
    relative = REPAIR_DESIGN_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(REPAIR_DESIGN_PATH)),
        "L12_REPAIR_DESIGN_SOURCE_BLOB",
    )
    binding = file_identity(REPAIR_DESIGN_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": design["status"],
            "repair_id": REPAIR_ID,
            "change_class": (
                "r10f_walking_actuation_ownership_handoff_"
                "and_existing_host_cap_binding_only"
            ),
            "bound_authority_count": 8,
            "positive_control_count": 13,
            "mutation_rejection_count": 19,
            "walking_actuation_handoff_positive_control_count": 5,
            "walking_actuation_handoff_mutation_rejection_count": 22,
            "qualified_r69_projection_count": 8,
            "maximum_child_process_count": 2,
            "maximum_world_count_per_child": 1,
            "maximum_total_world_count": 2,
            "maximum_solver_steps_per_child": 3842,
            "maximum_total_solver_steps": 7684,
            "existing_complete_override_interface_used": True,
            "shared_adapter_enable_behavior_changed": False,
            "published_actuator_profile_changed": False,
            "extra_solver_step_inserted": False,
            "l11_release_receipt_preserved": True,
            "physical_execution_authorized_by_design": False,
        }
    )
    return binding


def repair_design_binding(source_commit: str) -> dict[str, Any]:
    """Use the same independently pinned base design as the closer/supervisor."""
    try:
        return l14_authority.repair_design_binding(source_commit)
    except ValueError as exc:
        raise MaterializationFailure(str(exc)) from exc


def branch_completeness_addendum_binding(source_commit: str) -> dict[str, Any]:
    try:
        return l14_authority.branch_completeness_addendum_binding(source_commit)
    except ValueError as exc:
        raise MaterializationFailure(str(exc)) from exc


def supervisor_refusal_binding(source_commit: str) -> dict[str, Any]:
    refusal = read_json(SUPERVISOR_REFUSAL_PATH, "SUPERVISOR_REFUSAL")
    boundary = refusal.get("execution_boundary")
    successor = refusal.get("successor_policy")
    claim = refusal.get("claim_boundary")
    source = refusal.get("source")
    authority_bindings = refusal.get("authority_bindings")
    require(
        SUPERVISOR_REFUSAL_PATH.stat().st_size == EXPECTED_SUPERVISOR_REFUSAL_BYTES
        and sha256_file(SUPERVISOR_REFUSAL_PATH) == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and refusal.get("schema_version")
        == "sporespore_qsdk_r10f_physical_supervisor_refusal_v2"
        and refusal.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and refusal.get("gate_id") == "QSDK-R10F"
        and refusal.get("repair_id") == "QSDK-R10F-L2"
        and refusal.get("campaign_role") == "development_route_ghost"
        and isinstance(source, dict)
        and source.get("source_commit") == "04a4b4aa68a7b466db6bc975fdec9295e7c280f8"
        and source.get("qualification_commit")
        == "e211187d08de8a57f57221fe8cf83250c5b331e0"
        and source.get("authorization_commit")
        == "fc3187f918c953b156b3036811709ef95227fc6c"
        and isinstance(boundary, dict)
        and exact_int(boundary.get("physical_supervisor_invocation_count"), 1)
        and exact_int(boundary.get("operation_lock_acquisition_count"), 1)
        and exact_int(boundary.get("operation_lock_explicit_release_count"), 1)
        and boundary.get("durable_evidence_directory_created") is False
        and exact_int(boundary.get("model_construction_count"), 0)
        and exact_int(boundary.get("world_attempt_count"), 0)
        and exact_int(boundary.get("world_build_count"), 0)
        and exact_int(boundary.get("native_readback_count"), 0)
        and exact_int(boundary.get("solver_step_count"), 0)
        and boundary.get("physics_state_modified") is False
        and boundary.get("physical_attempt_identity_consumed") is False
        and isinstance(successor, dict)
        and successor.get("repeat_failed_supervisor_invocation") is False
        and successor.get("old_stage_freeze_reusable") is False
        and successor.get("old_execution_authority_reusable") is False
        and successor.get("new_clean_pushed_source_required") is True
        and successor.get("new_official_zero_world_qualification_required") is True
        and successor.get("new_stage_freeze_required") is True
        and successor.get("new_execution_authority_required") is True
        and isinstance(claim, dict)
        and claim.get("continuous_passive_fall_recovery_claimed") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False
        and isinstance(authority_bindings, dict)
        and isinstance(authority_bindings.get("predecessor_supervisor_refusal"), dict)
        and authority_bindings["predecessor_supervisor_refusal"].get("raw_sha256")
        == "sha256:27528d78b217278700f5d1860046a2e5f7fc1e2324cef1a0239ffbd7859391e0"
        and authority_bindings.get("authorized_output_root_absent_after_refusal")
        is True,
        "SUPERVISOR_REFUSAL_FIELDS",
    )
    for commit_key, tree_key in (
        ("source_commit", "source_tree_git_oid"),
        ("qualification_commit", "qualification_tree_git_oid"),
        ("authorization_commit", "authorization_tree_git_oid"),
    ):
        require(
            git("rev-parse", f"{source[commit_key]}^{{tree}}") == source[tree_key],
            f"SUPERVISOR_REFUSAL_{commit_key.upper()}_TREE",
        )
    relative = SUPERVISOR_REFUSAL_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(SUPERVISOR_REFUSAL_PATH)),
        "SUPERVISOR_REFUSAL_SOURCE_BLOB",
    )
    output_root = Path(str(authority_bindings.get("authorized_output_root", "")))
    require(not output_root.exists(), "SUPERSEDED_PHYSICAL_OUTPUT_ROOT_EXISTS")
    binding = file_identity(SUPERVISOR_REFUSAL_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": refusal["status"],
            "repair_id": "QSDK-R10F-L2",
            "physical_attempt_identity_consumed": False,
            "world_attempt_count": 0,
            "world_build_count": 0,
            "solver_step_count": 0,
        }
    )
    return binding


def _l7_predecessor_physical_closure_binding_retired(
    source_commit: str,
) -> dict[str, Any]:
    closure = read_json(PREDECESSOR_PHYSICAL_CLOSURE_PATH, "PHYSICAL_CLOSURE")
    bindings = closure.get("evidence_bindings")
    dispositions = closure.get("precondition_terminal_dispositions")
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v8"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L7"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "a07514ce2ce14c870811c86f55b6c775be4789db"
        and closure.get("stage_commit") == "db5d56cbaa4869920c5b38f2f0352da4b1630cda"
        and closure.get("authority_commit")
        == "898c6ff2146bf8e19367b196a0a1d309c3d39bfa"
        and closure.get("closure_audit_commit")
        == "63911dacda99c31dc67e7fbd7a4b2826b21e2483"
        and closure.get("attempt_id") == "0485211cfa1049e6bdee374b406d0c32"
        and closure.get("failure_code")
        == "QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 2)
        and exact_int(closure.get("world_build_count"), 2)
        and exact_int(closure.get("solver_step_count"), 2)
        and isinstance(dispositions, dict)
        and dispositions.get("validation_class")
        == "disposition_builder_number_kind_rejection"
        and dispositions.get("inner_failure_code")
        == "QSDK_R10F_L7_DISPOSITION_BUILD_INVALID"
        and dispositions.get("memory_last_semantic_step_json_kind") == "binary64"
        and dispositions.get("receipt_global_semantic_step_json_kind") == "integer"
        and dispositions.get("numeric_values_equal") is True
        and dispositions.get("independent_receipt_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    for key in (
        "supervisor_result",
        "attempt_identity",
        "worker_stdout",
        "worker_stderr",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l7_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    ):
        declared = bindings.get(key)
        require(isinstance(declared, dict), f"PREDECESSOR_BINDING_{key.upper()}")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        expected = file_identity(
            actual_path,
            relative_to=None if declared_path.is_absolute() else ROOT,
        )
        require(
            declared.get("path") == expected["path"]
            and declared.get("byte_length") == expected["byte_length"]
            and declared.get("raw_sha256") == expected["raw_sha256"],
            f"PREDECESSOR_BINDING_{key.upper()}_IDENTITY",
        )
    relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
        "PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
    )
    binding = file_identity(PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": closure["status"],
            "repair_id": "QSDK-R10F-L7",
            "classification": closure["classification"],
            "attempt_id": closure["attempt_id"],
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "world_attempt_count": 2,
            "world_build_count": 2,
            "solver_step_count": 2,
            "scientific_outcome": "none",
            "number_kind_diagnosis_independently_validated": True,
        }
    )
    return binding


def _l11_predecessor_physical_closure_binding_retired(
    source_commit: str,
) -> dict[str, Any]:
    """Retained L11 binding; superseded by the active L12 binding below."""
    closure = read_json(PREDECESSOR_PHYSICAL_CLOSURE_PATH, "L11_PHYSICAL_CLOSURE")
    process = closure.get("process_isolation")
    dispositions = closure.get("precondition_terminal_dispositions")
    bindings = closure.get("evidence_bindings")
    require(
        PREDECESSOR_PHYSICAL_CLOSURE_PATH.stat().st_size
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_BYTES
        and sha256_file(PREDECESSOR_PHYSICAL_CLOSURE_PATH)
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and closure.get("schema_version")
        == "sporespore_qsdk_r10f_development_route_ghost_physical_closure_v12"
        and closure.get("status")
        == "closed_consumed_invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("gate_id") == "QSDK-R10F"
        and closure.get("repair_id") == "QSDK-R10F-L11"
        and closure.get("campaign_role") == "development_route_ghost"
        and closure.get("question_class") == "development"
        and closure.get("classification")
        == "invalid_or_incomplete_no_behavioral_conclusion"
        and closure.get("source_commit") == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and closure.get("stage_commit") == "487584fc851bf6825e7c7de919e6c777fa71215b"
        and closure.get("authority_commit")
        == "f0fb74e29d1064ade3d817933d7835ca4927998c"
        and closure.get("closure_audit_commit")
        == "02f7b554a29ed80ad55d9d21930f23a267c07273"
        and closure.get("attempt_id") == "977175976c09461c9fac94dd23e6ab21"
        and closure.get("failure_code")
        == "QSDK_R10F_L9_PROCESS_POPULATION_VALIDATION_FAILED"
        and closure.get("physical_identity_consumed") is True
        and closure.get("same_identity_rerun_permitted") is False
        and closure.get("route_execution_valid") is False
        and closure.get("evidence_valid") is False
        and closure.get("measurement_complete") is False
        and closure.get("outcome_complete") is False
        and closure.get("behavior_passed") is False
        and closure.get("scientific_outcome") == "none"
        and exact_int(closure.get("campaign_attempt_count"), 1)
        and exact_int(closure.get("observed_child_process_count"), 1)
        and exact_int(closure.get("model_construction_attempt_count"), 1)
        and exact_int(closure.get("model_construction_count"), 1)
        and exact_int(closure.get("world_attempt_count"), 1)
        and exact_int(closure.get("world_build_count"), 1)
        and exact_int(closure.get("solver_step_count"), 241)
        and isinstance(process, dict)
        and process.get("ordered_declared_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and exact_int(process.get("declared_child_count"), 2)
        and exact_int(process.get("observed_child_count"), 1)
        and process.get("distinct_child_process_ids") is False
        and process.get("child_process_lifetimes_overlap") is None
        and process.get("child_retry_or_replacement_used") is False
        and closure.get("topology_validation_errors") == ["declared_child_missing"]
        and closure.get("child_validation_errors")
        == {
            "matched_no_kick_continuation": (
                "L9_matched_no_kick_continuation_REPORT_FIELDS"
            )
        }
        and isinstance(dispositions, dict)
        and dispositions.get("disposition_by_arm") == {}
        and dispositions.get("precondition_negative_roles") == []
        and dispositions.get("independent_population_validation_performed") is True
        and dispositions.get("summary_boolean_only") is False
        and closure.get("event_triggered_passive_recovery_observed") is False
        and closure.get("continuous_same_body_recovery_resume_observed") is False
        and closure.get("force_aware_recovery") is False
        and closure.get("sdk1_m07_satisfied") is False
        and closure.get("physical_acceptance_authority") is False
        and closure.get("release_authority") is False
        and isinstance(bindings, dict),
        "L11_PREDECESSOR_PHYSICAL_CLOSURE_FIELDS",
    )
    expected_binding_keys = {
        "supervisor_result",
        "attempt_identity",
        "child_process_artifacts",
        "execution_authority",
        "stage_freeze",
        "r10f_design",
        "l11_repair_design",
        "superseded_physical_supervisor_refusal",
        "consumed_predecessor_physical_closure",
    }
    require(set(bindings) == expected_binding_keys, "L11_PREDECESSOR_BINDING_SET")

    def verify_declared_binding(declared: Any, code: str) -> None:
        require(isinstance(declared, dict), f"{code}_NOT_OBJECT")
        declared_path = Path(str(declared.get("path", "")))
        actual_path = (
            declared_path if declared_path.is_absolute() else ROOT / declared_path
        )
        expected = file_identity(
            actual_path,
            relative_to=None if declared_path.is_absolute() else ROOT,
        )
        require(
            declared.get("path") == expected["path"]
            and declared.get("byte_length") == expected["byte_length"]
            and declared.get("raw_sha256") == expected["raw_sha256"],
            f"{code}_IDENTITY",
        )

    for key in sorted(expected_binding_keys - {"child_process_artifacts"}):
        verify_declared_binding(bindings[key], f"L11_PREDECESSOR_{key.upper()}")
    child_artifacts = bindings["child_process_artifacts"]
    require(
        isinstance(child_artifacts, dict)
        and set(child_artifacts) == {"matched_no_kick_continuation"},
        "L11_PREDECESSOR_CHILD_ARTIFACT_SET",
    )
    baseline_artifacts = child_artifacts["matched_no_kick_continuation"]
    require(
        isinstance(baseline_artifacts, dict)
        and set(baseline_artifacts)
        == {
            "child_attempt_identity",
            "worker_stdout",
            "worker_stderr",
            "termination_receipt",
            "engine_health",
            "child_envelope",
            "worker_report",
        },
        "L11_PREDECESSOR_BASELINE_ARTIFACT_SET",
    )
    for key, declared in baseline_artifacts.items():
        verify_declared_binding(declared, f"L11_PREDECESSOR_CHILD_{key.upper()}")
    relative = PREDECESSOR_PHYSICAL_CLOSURE_PATH.relative_to(ROOT).as_posix()
    require(
        git("rev-parse", f"{source_commit}:{relative}")
        == git("hash-object", str(PREDECESSOR_PHYSICAL_CLOSURE_PATH)),
        "L11_PREDECESSOR_PHYSICAL_CLOSURE_SOURCE_BLOB",
    )
    binding = file_identity(PREDECESSOR_PHYSICAL_CLOSURE_PATH, relative_to=ROOT)
    binding.update(
        {
            "status": closure["status"],
            "repair_id": "QSDK-R10F-L11",
            "classification": closure["classification"],
            "attempt_id": closure["attempt_id"],
            "physical_identity_consumed": True,
            "same_identity_rerun_permitted": False,
            "observed_child_process_count": 1,
            "world_attempt_count": 1,
            "world_build_count": 1,
            "solver_step_count": 241,
            "scientific_outcome": "none",
            "l11_release_step_completed": True,
            "walking_handoff_failure_retained": True,
        }
    )
    return binding


def predecessor_physical_closure_binding(source_commit: str) -> dict[str, Any]:
    """Preserve the consumed L13 result; no old identity becomes executable."""
    try:
        return l14_authority.predecessor_physical_closure_binding(source_commit)
    except ValueError as exc:
        raise MaterializationFailure(str(exc)) from exc


def validate_current_l14_authorities(stage: Mapping[str, Any], source_commit: str) -> None:
    """Reopen all three source-bound records at every materialization boundary."""
    actual = {
        "repair_design": repair_design_binding(source_commit),
        "branch_completeness_addendum": branch_completeness_addendum_binding(source_commit),
        "consumed_predecessor_physical_closure": predecessor_physical_closure_binding(source_commit),
    }
    selected = {key: stage.get(key) for key in actual}
    require(
        l14_authority.design_audit.exact(selected, actual),
        "CURRENT_L14_AUTHORITY_BINDINGS",
    )


def qualification_directory(source_commit: str) -> Path:
    return EVIDENCE_ROOT / (
        "qsdk-r10f-development-route-ghost-zero-world-qualification-"
        + source_commit[:12]
    )


def validate_qualification(path: Path, source: Mapping[str, Any]) -> dict[str, Any]:
    source_commit = str(source["commit"])
    expected = qualification_directory(source_commit).resolve()
    require(path.resolve() == expected, "QUALIFICATION_DIRECTORY_NOT_EXACT")
    require(path.is_dir(), "QUALIFICATION_DIRECTORY_MISSING")
    require(not (path / "qualification_failure.json").exists(), "QUALIFICATION_FAILED")
    attempt_path = path / "qualification_attempt.json"
    implementation_path = path / "implementation_audit.json"
    runtime_path = path / "runtime_identity.json"
    stdout_path = path / "qualification_stdout.log"
    stderr_path = path / "qualification_stderr.log"
    completion_path = path / "qualification_completion.json"
    for required in (
        attempt_path,
        implementation_path,
        runtime_path,
        stdout_path,
        stderr_path,
        completion_path,
    ):
        require(required.is_file(), f"QUALIFICATION_FILE_MISSING:{required.name}")
    attempt = read_json(attempt_path, "QUALIFICATION_ATTEMPT")
    implementation = read_json(implementation_path, "IMPLEMENTATION")
    completion = read_json(completion_path, "QUALIFICATION_COMPLETION")
    runtime = read_json(runtime_path, "QUALIFICATION_RUNTIME")
    try:
        exact_runtime = l14_runtime.qualification_copies(attempt, implementation, completion, runtime)
    except (ValueError, OSError) as exc:
        raise MaterializationFailure(f"QUALIFICATION_L14_RUNTIME:{exc}") from exc
    _, source_policy = manifest_binding()
    require(
        attempt.get("schema_version") == ATTEMPT_SCHEMA
        and attempt.get("status")
        == "started_consumed_official_zero_world_qualification"
        and attempt.get("gate_id") == "QSDK-R10F"
        and attempt.get("repair_id") == REPAIR_ID
        and attempt.get("campaign_role") == "development_route_ghost"
        and attempt.get("source_commit") == source_commit
        and attempt.get("qualified_source_path_count") == source_policy["count"]
        and attempt.get("qualified_source_path_sha256") == source_policy["digest"]
        and attempt.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and attempt.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and attempt.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and attempt.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and attempt.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and attempt.get("same_identity_rerun_permitted") is False
        and attempt.get("physical_execution_authorized") is False,
        "QUALIFICATION_ATTEMPT_FIELDS",
    )
    require_zero_world(attempt, "QUALIFICATION_ATTEMPT")
    implementation_source = implementation.get("source")
    root_design_audit = implementation.get("root_design_audit")
    require(
        isinstance(root_design_audit, dict)
        and root_design_audit.get("schema_version")
        == "sporespore_qsdk_r10f_continuous_passive_recovery_successor_design_audit_v1"
        and root_design_audit.get("gate_id") == "QSDK-R10F"
        and root_design_audit.get("design_raw_sha256") == EXPECTED_DESIGN_SHA256
        and root_design_audit.get("bound_authority_source_mode")
        == "authored_parent_historical_replay_with_explicit_l13_successor_drift"
        and exact_int(root_design_audit.get("current_disk_drift_path_count"), 1)
        and root_design_audit.get("current_disk_drift_paths")
        == ["scripts/lab/gait/sdk_godot_jolt_adapter.gd"]
        and root_design_audit.get("successor_authorization_repair_id")
        == "QSDK-R10F-L13"
        and root_design_audit.get("active_repair_id") == REPAIR_ID,
        "QUALIFICATION_ROOT_DESIGN_AUDIT_FIELDS",
    )
    require_zero_world(root_design_audit, "QUALIFICATION_ROOT_DESIGN_AUDIT")
    require(
        exact_int(root_design_audit.get("scene_tree_insertion_count"), 0)
        and root_design_audit.get("scene_tree_counter_source")
        == "successor_zero_world_projection_after_complete_historical_validation",
        "QUALIFICATION_ROOT_DESIGN_EXPLICIT_SCENE_COUNTER",
    )
    qualification_failure = implementation.get(
        "predecessor_qualification_failure_audit", {}
    )
    receipt_contract = implementation.get("qualification_receipt_contract_audit", {})
    require(
        implementation.get("predecessor_qualification_failure_closure_raw_sha256")
        == "sha256:3aed8ce62bc18369f5698e78174e7fb85a36e8595d8d43196af4dad6a86db5a1"
        and qualification_failure.get("source_commit")
        == "8de3a28f4a9cbbb9249fefd28d61eba420c011df"
        and exact_int(qualification_failure.get("retained_file_count"), 4)
        and exact_int(qualification_failure.get("retained_total_byte_length"), 28_659)
        and receipt_contract.get("validation_source")
        == "actual_wrapper_ast_five_pure_functions"
        and receipt_contract.get("exact_retained_failure_rejected") is True
        and exact_int(receipt_contract.get("positive_control_count"), 1)
        and exact_int(receipt_contract.get("mutation_rejection_count"), 335)
        and exact_int(receipt_contract.get("preserved_historical_corruption_count"), 86)
        and exact_int(receipt_contract.get("l14_component_corruption_count"), 176)
        and exact_int(receipt_contract.get("l14_authority_metadata_corruption_count"), 6)
        and exact_int(receipt_contract.get("l14_runtime_corruption_count"), 67),
        "QUALIFICATION_FAILURE_PRESERVATION_AND_RECEIPT_CONTRACT",
    )
    require_zero_world(qualification_failure, "QUALIFICATION_PREDECESSOR_FAILURE")
    require_zero_world(receipt_contract, "QUALIFICATION_RECEIPT_CONTRACT")
    try:
        l14_components.validate_receipt(implementation.get("l14_component_qualification"))
    except ValueError as exc:
        raise MaterializationFailure(f"QUALIFICATION_L14_COMPONENTS:{exc}") from exc
    source_preflight = implementation.get("source_authority_preflight_receipt", {})
    require(
        source_preflight.get("schema_version")
        == "sporespore_qsdk_r10f_source_authority_preflight_audit_v1"
        and source_preflight.get("retirement_closure_raw_sha256")
        == "sha256:2e6089be8512c3da2c9227ab30e3235c9088dd1c417e744edcd9f4d3a5f55430"
        and source_preflight.get("exact_historical_materializer_refusal_reproduced")
        is True
        and source_preflight.get("historical_root_authorities_preserved_unchanged")
        is True
        and source_preflight.get("current_adapter_bound_to_exact_successor_source")
        is True
        and exact_int(
            source_preflight.get("production_source_binding_function_count"), 7
        )
        and exact_int(source_preflight.get("historical_root_authority_count"), 15),
        "QUALIFICATION_PRODUCTION_SOURCE_AUTHORITY_PREFLIGHT",
    )
    require_zero_world(source_preflight, "QUALIFICATION_SOURCE_AUTHORITY_PREFLIGHT")
    require(
        implementation.get("schema_version") == IMPLEMENTATION_SCHEMA
        and implementation.get("status") == "passed_complete_zero_world_implementation"
        and implementation.get("ok") is True
        and implementation.get("repair_id") == REPAIR_ID
        and isinstance(implementation_source, dict)
        and implementation_source.get("official_qualification") is True
        and implementation_source.get("source_commit") == source_commit
        and implementation_source.get("source_tree") == source.get("tree")
        and implementation_source.get("source_clean") is True
        and implementation_source.get("source_origin_main_equal") is True
        and implementation_source.get("source_live_main_equal") is True
        and implementation.get("qualified_source_path_count") == source_policy["count"]
        and implementation.get("qualified_source_path_sha256")
        == source_policy["digest"]
        and implementation.get("design_raw_sha256") == EXPECTED_DESIGN_SHA256
        and implementation.get("repair_design_raw_sha256")
        == EXPECTED_REPAIR_DESIGN_SHA256
        and implementation.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and implementation.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and implementation.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and exact_int(implementation.get("positive_case_count"), 24)
        and exact_int(implementation.get("forced_failure_case_count"), 237)
        and implementation.get("physical_execution_authorized") is False,
        "QUALIFICATION_IMPLEMENTATION_FIELDS",
    )
    require_zero_world(implementation, "QUALIFICATION_IMPLEMENTATION")
    require(
        completion.get("schema_version") == COMPLETION_SCHEMA
        and completion.get("status")
        == "closed_passing_official_zero_world_qualification"
        and completion.get("gate_id") == "QSDK-R10F"
        and completion.get("repair_id") == REPAIR_ID
        and completion.get("campaign_role") == "development_route_ghost"
        and completion.get("source_commit") == source_commit
        and completion.get("source_tree") == source.get("tree")
        and completion.get("qualified_source_path_count") == source_policy["count"]
        and completion.get("qualified_source_path_sha256") == source_policy["digest"]
        and completion.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and completion.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and completion.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and completion.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and completion.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and completion.get("official_zero_world_qualification_passed") is True
        and completion.get("physical_execution_authorized_by_qualification") is False
        and completion.get("same_identity_rerun_permitted") is False,
        "QUALIFICATION_COMPLETION_FIELDS",
    )
    require_zero_world(completion, "QUALIFICATION_COMPLETION")
    for key, bound_path in (
        ("qualification_attempt", attempt_path),
        ("implementation_audit", implementation_path),
        ("runtime_identity", runtime_path),
        ("qualification_stdout", stdout_path),
        ("qualification_stderr", stderr_path),
    ):
        verify_binding(completion.get(key), bound_path, f"QUALIFICATION_{key.upper()}")
    return {
        "completion": completion,
        "completion_binding": file_identity(completion_path),
        "runtime_binding": file_identity(runtime_path),
        "l14_exact_runtime_images": exact_runtime,
        "l14_component_qualification": implementation["l14_component_qualification"],
    }


def build_stage(
    source_commit: str,
    source_policy: Mapping[str, Any],
    qualification: Mapping[str, Any],
    authorities: list[dict[str, Any]],
    repair_design: Mapping[str, Any],
    supervisor_refusal: Mapping[str, Any],
    predecessor_physical_closure: Mapping[str, Any],
    branch_completeness_addendum: Mapping[str, Any],
) -> dict[str, Any]:
    try:
        l14_components.validate_receipt(qualification.get("l14_component_qualification"))
        l14_runtime.validate_binding(qualification.get("l14_exact_runtime_images"))
    except ValueError as exc:
        raise MaterializationFailure(f"STAGE_L14_QUALIFICATION_INPUT:{exc}") from exc
    return {
        "schema_version": STAGE_SCHEMA,
        "status": "closed_passing_official_zero_world_qualification",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "campaign_id": CAMPAIGN_ID,
        "campaign_role": "development_route_ghost",
        "question_class": "development",
        "ledger_scope": ledger_scope("official_zero_world_qualification"),
        "source_commit": source_commit,
        "qualification_parent_commit": source_commit,
        "qualified_source_path_count": source_policy["count"],
        "qualified_source_path_sha256": source_policy["digest"],
        "dependency_manifest_raw_sha256": sha256_file(MANIFEST_PATH),
        "r10f_design_sha256": EXPECTED_DESIGN_SHA256,
        "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "branch_completeness_addendum_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "repair_design": dict(repair_design),
        "branch_completeness_addendum": dict(branch_completeness_addendum),
        "worker_resource_path": WORKER_RESOURCE,
        "seed": SEED,
        "seed_sha256": SEED_SHA256,
        "ordered_child_roles": [
            "matched_no_kick_continuation",
            "kick_passive_recovery_resume",
        ],
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_world_count": 2,
        "maximum_solver_step_count_per_child": 3842,
        "maximum_solver_step_count": 7684,
        "maximum_campaign_attempt_count": 1,
        "child_processes_overlap_in_wall_clock_time": False,
        "child_retry_permitted": False,
        "child_replacement_permitted": False,
        "official_zero_world_qualification_passed": True,
        "physical_execution_authorized_by_freeze": False,
        "qualification_completion": dict(qualification["completion_binding"]),
        "qualified_runtime_identity": dict(qualification["runtime_binding"]),
        "l14_exact_runtime_images": copy.deepcopy(qualification["l14_exact_runtime_images"]),
        "l14_component_qualification": copy.deepcopy(qualification["l14_component_qualification"]),
        "preserved_bound_authorities": authorities,
        "superseded_physical_supervisor_refusal": dict(supervisor_refusal),
        "consumed_predecessor_physical_closure": dict(predecessor_physical_closure),
        "claim_boundary": {
            "event_triggered_passive_recovery_observed": False,
            "force_aware_recovery": False,
            "r10f_behavior_observed": False,
            "same_identity_rerun_permitted": False,
            "process_isolation_qualified_zero_world": True,
            "nullable_terminal_failure_code_projection_qualified_zero_world": True,
            "precondition_release_owner_source_projection_qualified_zero_world": True,
            "walking_actuation_handoff_qualified_zero_world": True,
            "walking_native_preparse_transport_verification_qualified_zero_world": True,
            "walking_binary32_host_target_projection_qualified_zero_world": True,
            "walking_ledger_v2_named_predicates_qualified_zero_world": True,
            "walking_failed_step_source_retention_qualified_zero_world": True,
            "walking_ledger_l13_positive_control_count": 15,
            "walking_ledger_l13_mutation_rejection_count": 16,
            "walking_ledger_failure_retention_positive_control_count": 1,
            "walking_ledger_failure_retention_mutation_rejection_count": 15,
            "production_shaped_walking_fixture_count": 3,
            "detached_hinge_parameter_container_count": 24,
            "qualified_r69_host_cap_projection_count": 8,
            "shared_adapter_enable_behavior_changed": False,
            "published_actuator_profile_changed": False,
            "walking_handoff_extra_solver_step_count": 0,
            "threshold_or_controller_changed": False,
            "sdk1_m07_satisfied": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_stage(
    value: Mapping[str, Any], source_commit: str, source_policy: Mapping[str, Any]
) -> None:
    try:
        l14_components.validate_receipt(value.get("l14_component_qualification"))
        l14_runtime.validate_binding(value.get("l14_exact_runtime_images"))
    except ValueError as exc:
        raise MaterializationFailure(f"STAGE_L14_COMPONENTS:{exc}") from exc
    require(
        value.get("schema_version") == STAGE_SCHEMA
        and value.get("status") == "closed_passing_official_zero_world_qualification"
        and value.get("gate_id") == "QSDK-R10F"
        and value.get("repair_id") == REPAIR_ID
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("campaign_role") == "development_route_ghost"
        and value.get("question_class") == "development"
        and value.get("ledger_scope")
        == ledger_scope("official_zero_world_qualification")
        and value.get("source_commit") == source_commit
        and value.get("qualification_parent_commit") == source_commit
        and value.get("qualified_source_path_count") == source_policy["count"]
        and value.get("qualified_source_path_sha256") == source_policy["digest"]
        and value.get("dependency_manifest_raw_sha256") == sha256_file(MANIFEST_PATH)
        and value.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and value.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and value.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and value.get("worker_resource_path") == WORKER_RESOURCE
        and exact_int(value.get("seed"), SEED)
        and value.get("seed_sha256") == SEED_SHA256
        and value.get("ordered_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and exact_int(value.get("maximum_child_process_count"), 2)
        and exact_int(value.get("maximum_world_count_per_child"), 1)
        and exact_int(value.get("maximum_world_count"), 2)
        and exact_int(value.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(value.get("maximum_solver_step_count"), 7684)
        and exact_int(value.get("maximum_campaign_attempt_count"), 1)
        and value.get("child_processes_overlap_in_wall_clock_time") is False
        and value.get("child_retry_permitted") is False
        and value.get("child_replacement_permitted") is False
        and value.get("official_zero_world_qualification_passed") is True
        and value.get("physical_execution_authorized_by_freeze") is False
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        "STAGE_FIELDS",
    )
    claim = value.get("claim_boundary")
    require(
        isinstance(claim, dict)
        and claim.get("event_triggered_passive_recovery_observed") is False
        and claim.get("force_aware_recovery") is False
        and claim.get("r10f_behavior_observed") is False
        and claim.get("same_identity_rerun_permitted") is False
        and claim.get("process_isolation_qualified_zero_world") is True
        and claim.get("nullable_terminal_failure_code_projection_qualified_zero_world")
        is True
        and claim.get(
            "precondition_release_owner_source_projection_qualified_zero_world"
        )
        is True
        and claim.get("walking_actuation_handoff_qualified_zero_world") is True
        and claim.get(
            "walking_native_preparse_transport_verification_qualified_zero_world"
        )
        is True
        and claim.get("walking_binary32_host_target_projection_qualified_zero_world")
        is True
        and claim.get("walking_ledger_v2_named_predicates_qualified_zero_world") is True
        and claim.get("walking_failed_step_source_retention_qualified_zero_world")
        is True
        and exact_int(claim.get("walking_ledger_l13_positive_control_count"), 15)
        and exact_int(claim.get("walking_ledger_l13_mutation_rejection_count"), 16)
        and exact_int(
            claim.get("walking_ledger_failure_retention_positive_control_count"), 1
        )
        and exact_int(
            claim.get("walking_ledger_failure_retention_mutation_rejection_count"),
            15,
        )
        and exact_int(claim.get("production_shaped_walking_fixture_count"), 3)
        and exact_int(claim.get("detached_hinge_parameter_container_count"), 24)
        and exact_int(claim.get("qualified_r69_host_cap_projection_count"), 8)
        and claim.get("shared_adapter_enable_behavior_changed") is False
        and claim.get("published_actuator_profile_changed") is False
        and exact_int(claim.get("walking_handoff_extra_solver_step_count"), 0)
        and claim.get("threshold_or_controller_changed") is False
        and claim.get("sdk1_m07_satisfied") is False
        and claim.get("physical_acceptance_authority") is False
        and claim.get("release_authority") is False,
        "STAGE_CLAIM_BOUNDARY",
    )
    supervisor_refusal = value.get("superseded_physical_supervisor_refusal")
    repair_design = value.get("repair_design")
    predecessor_physical_closure = value.get("consumed_predecessor_physical_closure")
    require(
        isinstance(value.get("qualification_completion"), dict)
        and isinstance(value.get("qualified_runtime_identity"), dict)
        and isinstance(value.get("preserved_bound_authorities"), list)
        and bool(value.get("preserved_bound_authorities")),
        "STAGE_BINDINGS",
    )
    require(
        isinstance(supervisor_refusal, dict)
        and supervisor_refusal.get("raw_sha256") == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and supervisor_refusal.get("status")
        == "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed"
        and supervisor_refusal.get("repair_id") == "QSDK-R10F-L2"
        and supervisor_refusal.get("physical_attempt_identity_consumed") is False
        and exact_int(supervisor_refusal.get("world_attempt_count"), 0)
        and exact_int(supervisor_refusal.get("world_build_count"), 0)
        and exact_int(supervisor_refusal.get("solver_step_count"), 0),
        "STAGE_SUPERVISOR_REFUSAL_BINDING",
    )
    require(
        l14_authority.repair_binding_valid(repair_design),
        "STAGE_REPAIR_DESIGN_BINDING",
    )
    require(
        l14_authority.addendum_binding_valid(value.get("branch_completeness_addendum")),
        "STAGE_BRANCH_COMPLETENESS_ADDENDUM_BINDING",
    )
    require(
        l14_authority.predecessor_binding_valid(predecessor_physical_closure),
        "STAGE_PREDECESSOR_PHYSICAL_CLOSURE_BINDING",
    )


def build_authority(
    stage_commit: str,
    stage_sha256: str,
    source_commit: str,
    source_policy: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "schema_version": AUTHORITY_SCHEMA,
        "l14_component_qualification": l14_components.expected_receipt(),
        "l14_exact_runtime_images": l14_runtime.expected_binding(),
        "status": "authorized_single_use_unconsumed",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "campaign_id": CAMPAIGN_ID,
        "campaign_role": "development_route_ghost",
        "question_class": "development",
        "ledger_scope": ledger_scope("single_use_physical_execution_authority"),
        "authorization_commit_derived_from_current_head": True,
        "authorization_parent_commit": stage_commit,
        "qualification_parent_commit": source_commit,
        "source_commit": source_commit,
        "zero_world_qualification_closure_path": STAGE_RELATIVE,
        "zero_world_qualification_closure_sha256": stage_sha256,
        "dependency_manifest_raw_sha256": sha256_file(MANIFEST_PATH),
        "r10f_design_sha256": EXPECTED_DESIGN_SHA256,
        "repair_design_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "branch_completeness_addendum_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "superseded_physical_supervisor_refusal_sha256": (
            EXPECTED_SUPERVISOR_REFUSAL_SHA256
        ),
        "consumed_predecessor_physical_closure_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "worker_resource_path": WORKER_RESOURCE,
        "seed": SEED,
        "seed_sha256": SEED_SHA256,
        "qualified_source_path_count": source_policy["count"],
        "qualified_source_path_sha256": source_policy["digest"],
        "ordered_child_roles": [
            "matched_no_kick_continuation",
            "kick_passive_recovery_resume",
        ],
        "maximum_child_process_count": 2,
        "maximum_world_count_per_child": 1,
        "maximum_world_count": 2,
        "maximum_solver_step_count_per_child": 3842,
        "maximum_solver_step_count": 7684,
        "maximum_campaign_attempt_count": 1,
        "child_processes_overlap_in_wall_clock_time": False,
        "child_retry_permitted": False,
        "child_replacement_permitted": False,
        "zero_world_qualification_passed": True,
        "physical_execution_authorized": True,
        "physical_identity_consumed": False,
        "same_identity_rerun_permitted": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_authority(
    value: Mapping[str, Any],
    stage_commit: str,
    stage_sha256: str,
    source_commit: str,
    source_policy: Mapping[str, Any],
) -> None:
    try:
        l14_components.validate_receipt(value.get("l14_component_qualification"))
        l14_runtime.validate_binding(value.get("l14_exact_runtime_images"))
    except ValueError as exc:
        raise MaterializationFailure(f"AUTHORITY_L14_COMPONENTS:{exc}") from exc
    require(
        value.get("schema_version") == AUTHORITY_SCHEMA
        and value.get("status") == "authorized_single_use_unconsumed"
        and value.get("gate_id") == "QSDK-R10F"
        and value.get("repair_id") == REPAIR_ID
        and value.get("campaign_id") == CAMPAIGN_ID
        and value.get("campaign_role") == "development_route_ghost"
        and value.get("question_class") == "development"
        and value.get("ledger_scope")
        == ledger_scope("single_use_physical_execution_authority")
        and value.get("authorization_commit_derived_from_current_head") is True
        and value.get("authorization_parent_commit") == stage_commit
        and value.get("qualification_parent_commit") == source_commit
        and value.get("source_commit") == source_commit
        and value.get("zero_world_qualification_closure_path") == STAGE_RELATIVE
        and value.get("zero_world_qualification_closure_sha256") == stage_sha256
        and value.get("dependency_manifest_raw_sha256") == sha256_file(MANIFEST_PATH)
        and value.get("r10f_design_sha256") == EXPECTED_DESIGN_SHA256
        and value.get("repair_design_sha256") == EXPECTED_REPAIR_DESIGN_SHA256
        and value.get("branch_completeness_addendum_sha256")
        == EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256
        and value.get("superseded_physical_supervisor_refusal_sha256")
        == EXPECTED_SUPERVISOR_REFUSAL_SHA256
        and value.get("consumed_predecessor_physical_closure_sha256")
        == EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        and value.get("worker_resource_path") == WORKER_RESOURCE
        and exact_int(value.get("seed"), SEED)
        and value.get("seed_sha256") == SEED_SHA256
        and value.get("qualified_source_path_count") == source_policy["count"]
        and value.get("qualified_source_path_sha256") == source_policy["digest"]
        and value.get("ordered_child_roles")
        == ["matched_no_kick_continuation", "kick_passive_recovery_resume"]
        and exact_int(value.get("maximum_child_process_count"), 2)
        and exact_int(value.get("maximum_world_count_per_child"), 1)
        and exact_int(value.get("maximum_world_count"), 2)
        and exact_int(value.get("maximum_solver_step_count_per_child"), 3842)
        and exact_int(value.get("maximum_solver_step_count"), 7684)
        and exact_int(value.get("maximum_campaign_attempt_count"), 1)
        and value.get("child_processes_overlap_in_wall_clock_time") is False
        and value.get("child_retry_permitted") is False
        and value.get("child_replacement_permitted") is False
        and value.get("zero_world_qualification_passed") is True
        and value.get("physical_execution_authorized") is True
        and value.get("physical_identity_consumed") is False
        and value.get("same_identity_rerun_permitted") is False
        and value.get("physical_acceptance_authority") is False
        and value.get("release_authority") is False,
        "AUTHORITY_FIELDS",
    )


def l15_development_declaration() -> dict[str, Any]:
    """The existing bounded route, declared only after official qualification.

    This describes the first L15 development attempt, not the later smoke lane.
    No seed, horizon or authorization is allocated by calling this serializer.
    """
    return {
        "schema_version": "sporespore_qsdk_r10f_l15_bounded_route_declaration_v1",
        "ledger_scope": ledger_scope("prospective_bounded_development_route"),
        "question": "Can the corrected production pipeline retain and evaluate a complete valid paired result?",
        "seed": SEED,
        "seed_role": "previously_exposed_development_only",
        "ordered_child_roles": ["matched_no_kick_continuation", "kick_passive_recovery_resume"],
        "maximum_world_count": 2,
        "maximum_solver_steps_per_child": 3842,
        "maximum_total_solver_steps": 7684,
        "child_timeout_seconds": 3600,
        "coverage_reason": (
            "The paired production evaluator requires a fresh no-kick child and a fresh active child. "
            "Keep the existing bounded schedule so the attempt can reach late recovery, resumed walking, "
            "normal finalization and paired publication, rather than terminating before those interfaces. "
            "The horizons are ceilings; an earlier valid terminal outcome may close a child."
        ),
        "baseline_cached": False,
        "physics_inputs_thresholds_and_controller_changed": False,
        "behavioral_success_required_for_route_validity": False,
        "invalid_or_incomplete_is_a_valid_route": False,
        "same_identity_rerun_permitted": False,
        "held_out_seeds_accessed": False,
        "physical_execution_authorized_by_declaration": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def l15_stage_materials(source_commit: str, checkpoint: Any) -> dict[str, Any]:
    """Reopen exact qualified files and immutable designs for the v16 writer."""
    import qsdk_r10f_l15_collection_retention as packet
    import qsdk_r10f_l15_launch_ownership_publication_successor_design as design

    path = l15_official_qualification_directory(source_commit)
    files = read_l15_capture_population(path, L15_CAPTURE_FILES)
    require(packet.same(checkpoint["qualification_reader"]["complete_files"], [
        l15_capture_file_binding(name, files[name]) for name in L15_CAPTURE_FILES
    ]), "L15_STAGE_QUALIFICATION_FILES")
    candidate = packet.parse_json(files["implementation_audit.json"].decode("utf-8"))
    runtime = packet.parse_json(files["runtime_identity.json"].decode("utf-8"))
    design_raw = design.DESIGN.read_bytes()
    require(len(design_raw) == design.DESIGN_BYTES and sha256_bytes(design_raw) == design.DESIGN_SHA,
            "L15_STAGE_SEALED_DESIGN")
    predecessor_raw = L15_PREDECESSOR_PATH.read_bytes()
    require(len(predecessor_raw) == L15_PREDECESSOR_BYTES
            and sha256_bytes(predecessor_raw) == L15_PREDECESSOR_SHA256,
            "L15_STAGE_SEALED_PREDECESSOR")
    for artifact in (design.DESIGN, L15_PREDECESSOR_PATH):
        l14_authority.source_binding(artifact, source_commit)
    _, authorities = design_binding(source_commit, require_l15_sources=True)
    return {
        "checkpoint": checkpoint,
        "source_inputs": candidate["source_records"]["qualification_inputs"],
        "qualification": {
            "completion_binding": file_identity(path / "qualification_completion.json"),
            "runtime_binding": file_identity(path / "runtime_identity.json"),
            "l14_exact_runtime_images": runtime["l14_exact_runtime_images"],
            "l14_component_qualification": candidate["l14_component_qualification"],
        },
        "preserved_authorities": authorities,
        "legacy_bindings": l14_authority.authority_bindings(source_commit),
        "supervisor_refusal": supervisor_refusal_binding(source_commit),
        "repair_design": {
            **file_identity(design.DESIGN, relative_to=ROOT),
            "document": packet.parse_json(design_raw.decode("utf-8")),
        },
        "predecessor": {
            **file_identity(L15_PREDECESSOR_PATH, relative_to=ROOT),
            "document": packet.parse_json(predecessor_raw.decode("utf-8")),
        },
    }


def build_l15_stage(source_commit: str, materials: Mapping[str, Any]) -> dict[str, Any]:
    """Compose the L15 node without changing the legacy constructor or records."""
    inputs, legacy = materials["source_inputs"], materials["legacy_bindings"]
    policy = {"count": inputs["qualified_source_path_count"],
              "digest": inputs["qualified_source_path_sha256"]}
    stage = build_stage(
        source_commit, policy, materials["qualification"], materials["preserved_authorities"],
        legacy["repair_design"], materials["supervisor_refusal"],
        legacy["consumed_predecessor_physical_closure"], legacy["branch_completeness_addendum"],
    )
    stage.update({
        "schema_version": L15_STAGE_SCHEMA,
        "repair_id": "QSDK-R10F-L15",
        "dependency_manifest_raw_sha256": inputs["dependency_manifest"]["raw_sha256"],
        "repair_design_sha256": materials["repair_design"]["raw_sha256"],
        "repair_design": copy.deepcopy(materials["repair_design"]),
        "consumed_predecessor_physical_closure": copy.deepcopy(materials["predecessor"]),
        "l14_preserved_authority_bindings": copy.deepcopy(legacy),
        "l15_qualification_checkpoint": copy.deepcopy(materials["checkpoint"]),
        "l15_development_declaration": l15_development_declaration(),
    })
    return stage


def validate_l15_stage(value: Any, source_commit: str, materials: Any) -> None:
    import qsdk_r10f_l15_collection_retention as packet

    require(packet.same(value, build_l15_stage(source_commit, materials)), "L15_COMPLETE_STAGE")


def build_l15_authority(stage_commit: str, stage_sha256: str, stage: Any) -> dict[str, Any]:
    authority = build_authority(stage_commit, stage_sha256, stage["source_commit"], {
        "count": stage["qualified_source_path_count"], "digest": stage["qualified_source_path_sha256"]
    })
    authority.update({
        "schema_version": L15_AUTHORITY_SCHEMA,
        "repair_id": "QSDK-R10F-L15",
        "zero_world_qualification_closure_path": L15_STAGE_RELATIVE,
        "dependency_manifest_raw_sha256": stage["dependency_manifest_raw_sha256"],
        "repair_design_sha256": stage["repair_design_sha256"],
        "consumed_predecessor_physical_closure_sha256": stage["consumed_predecessor_physical_closure"]["raw_sha256"],
        "l14_component_qualification": copy.deepcopy(stage["l14_component_qualification"]),
        "l14_exact_runtime_images": copy.deepcopy(stage["l14_exact_runtime_images"]),
    })
    return authority


def validate_l15_authority(value: Any, stage_commit: str, stage_sha256: str, stage: Any) -> None:
    import qsdk_r10f_l15_collection_retention as packet

    require(packet.same(value, build_l15_authority(stage_commit, stage_sha256, stage)),
            "L15_COMPLETE_AUTHORITY")


def materialize_l15_stage(source_commit: str) -> dict[str, Any]:
    identity = live_source_identity()
    require(source_commit == identity["commit"], "L15_STAGE_SOURCE_NOT_HEAD")
    checkpoint = create_l15_qualification_checkpoint(source_commit)
    materials = l15_stage_materials(source_commit, checkpoint)
    stage = build_l15_stage(source_commit, materials)
    validate_l15_stage(stage, source_commit, materials)
    require(identity == live_source_identity(), "L15_STAGE_SOURCE_DRIFT")
    output = ROOT / L15_STAGE_RELATIVE
    write_new_json(output, stage)
    return {"mode": "l15-stage-freeze", "output_identity": file_identity(output, relative_to=ROOT),
            "source_commit": source_commit, "physical_execution_authorized": False}


def materialize_l15_authority(source_commit: str) -> dict[str, Any]:
    identity = live_source_identity()
    reused = read_l15_qualified_graph_checkpoint(source_commit, checkout_commit=identity["commit"])
    require(reused["checkout_context"]["phase"] == "freeze", "L15_AUTHORITY_REQUIRES_FREEZE_HEAD")
    stage_path = ROOT / L15_STAGE_RELATIVE
    stage = read_json(stage_path, "L15_STAGE")
    validate_l15_stage(stage, source_commit, l15_stage_materials(source_commit, reused["checkpoint"]))
    authority = build_l15_authority(identity["commit"], sha256_file(stage_path), stage)
    validate_l15_authority(authority, identity["commit"], sha256_file(stage_path), stage)
    require(identity == live_source_identity(), "L15_AUTHORITY_SOURCE_DRIFT")
    output = ROOT / L15_AUTHORITY_RELATIVE
    write_new_json(output, authority)
    return {"mode": "l15-execution-authority", "output_identity": file_identity(output, relative_to=ROOT),
            "source_commit": source_commit, "physical_execution_authorized_after_authority_only_commit": True}


def l15_committed_graph_binding() -> dict[str, Any]:
    """Shared actual graph reader for the supervisor and independent closer."""
    identity = live_source_identity()
    authority_path, stage_path = ROOT / L15_AUTHORITY_RELATIVE, ROOT / L15_STAGE_RELATIVE
    authority, stage = read_json(authority_path, "L15_AUTHORITY"), read_json(stage_path, "L15_STAGE")
    source_commit = authority.get("source_commit", "")
    reused = read_l15_qualified_graph_checkpoint(source_commit, checkout_commit=identity["commit"])
    graph = reused["checkout_context"]
    require(graph["phase"] == "authority", "L15_GRAPH_REQUIRES_AUTHORITY_HEAD")
    materials = l15_stage_materials(source_commit, reused["checkpoint"])
    validate_l15_stage(stage, source_commit, materials)
    validate_l15_authority(authority, graph["graph_artifacts"][0]["commit"], sha256_file(stage_path), stage)
    require(identity == live_source_identity(), "L15_GRAPH_SOURCE_DRIFT")
    return {
        "authority": authority, "authority_sha256": sha256_file(authority_path),
        "authority_path": authority_path.as_posix(), "freeze": stage,
        "freeze_sha256": sha256_file(stage_path),
        "l14_exact_runtime_images": stage["l14_exact_runtime_images"],
        "superseded_physical_supervisor_refusal": materials["supervisor_refusal"],
        "superseded_physical_supervisor_refusal_sha256": EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "consumed_predecessor_physical_closure": materials["predecessor"]["document"],
        "consumed_predecessor_physical_closure_sha256": L15_PREDECESSOR_SHA256,
        "repair_design": materials["repair_design"]["document"],
        "repair_design_sha256": materials["repair_design"]["raw_sha256"],
        "branch_completeness_addendum": stage["branch_completeness_addendum"],
        "branch_completeness_addendum_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "l15_prepared_context_expectation": reused["checkpoint"]["l15_prepared_context_expectation"],
    }


def materialize_stage(arguments: argparse.Namespace) -> dict[str, Any]:
    source = live_source_identity()
    source_commit = str(source["commit"])
    require(
        not arguments.source_commit or arguments.source_commit == source_commit,
        "SOURCE_COMMIT_ARGUMENT",
    )
    dependency = dependency_receipt()
    _, source_policy = manifest_binding()
    require(
        dependency.get("qualified_source_path_count") == source_policy["count"]
        and dependency.get("qualified_source_path_sha256") == source_policy["digest"],
        "DEPENDENCY_MANIFEST_BINDING",
    )
    qualification = validate_qualification(
        arguments.qualification_dir.resolve(), source
    )
    _, authorities = design_binding(source_commit)
    repair_design = repair_design_binding(source_commit)
    branch_completeness_addendum = branch_completeness_addendum_binding(source_commit)
    refusal = supervisor_refusal_binding(source_commit)
    predecessor_physical_closure = predecessor_physical_closure_binding(source_commit)
    stage = build_stage(
        source_commit,
        source_policy,
        qualification,
        authorities,
        repair_design,
        refusal,
        predecessor_physical_closure,
        branch_completeness_addendum,
    )
    validate_stage(stage, source_commit, source_policy)
    validate_current_l14_authorities(stage, source_commit)
    output = ROOT / STAGE_RELATIVE
    write_new_json(output, stage)
    return {
        "mode": "stage-freeze",
        "repair_id": REPAIR_ID,
        "output_identity": file_identity(output, relative_to=ROOT),
        "source_commit": source_commit,
        "physical_execution_authorized": False,
    }


def materialize_authority(arguments: argparse.Namespace) -> dict[str, Any]:
    identity = live_source_identity()
    stage_commit = str(identity["commit"])
    require(
        git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            stage_commit,
        ).splitlines()
        == [STAGE_RELATIVE],
        "STAGE_COMMIT_NOT_SINGLE_PATH",
    )
    stage_path = ROOT / STAGE_RELATIVE
    stage = read_json(stage_path, "STAGE")
    source_commit = str(stage.get("source_commit", ""))
    require(is_commit(source_commit), "STAGE_SOURCE_COMMIT")
    require(git("rev-parse", "HEAD^") == source_commit, "STAGE_PARENT_NOT_SOURCE")
    require(
        not arguments.source_commit or arguments.source_commit == source_commit,
        "SOURCE_COMMIT_ARGUMENT",
    )
    dependency = dependency_receipt()
    _, source_policy = manifest_binding()
    require(
        dependency.get("qualified_source_path_count") == source_policy["count"]
        and dependency.get("qualified_source_path_sha256") == source_policy["digest"],
        "DEPENDENCY_MANIFEST_BINDING",
    )
    validate_stage(stage, source_commit, source_policy)
    validate_current_l14_authorities(stage, source_commit)
    require(
        stage.get("superseded_physical_supervisor_refusal")
        == supervisor_refusal_binding(source_commit),
        "STAGE_CURRENT_SUPERVISOR_REFUSAL_BINDING",
    )
    require(
        stage.get("consumed_predecessor_physical_closure")
        == predecessor_physical_closure_binding(source_commit),
        "STAGE_CURRENT_PREDECESSOR_PHYSICAL_CLOSURE_BINDING",
    )
    stage_sha = sha256_file(stage_path)
    retained_runtime = l14_runtime.read_retained_runtime(
        stage.get("qualified_runtime_identity"), source_commit
    )
    l14_runtime.verify_qualified_binding(
        retained_runtime["l14_exact_runtime_images"],
        Path(l14_runtime.IMAGES["godot_console"]["path"]),
    )
    authority = build_authority(stage_commit, stage_sha, source_commit, source_policy)
    validate_authority(authority, stage_commit, stage_sha, source_commit, source_policy)
    output = ROOT / AUTHORITY_RELATIVE
    write_new_json(output, authority)
    return {
        "mode": "execution-authority",
        "repair_id": REPAIR_ID,
        "output_identity": file_identity(output, relative_to=ROOT),
        "source_commit": source_commit,
        "authorization_parent_commit": stage_commit,
        "physical_execution_authorized_after_authority_only_commit": True,
    }


def committed_graph_check() -> dict[str, Any]:
    identity = live_source_identity()
    authority_commit = str(identity["commit"])
    authority_path = ROOT / AUTHORITY_RELATIVE
    stage_path = ROOT / STAGE_RELATIVE
    authority = read_json(authority_path, "AUTHORITY")
    stage = read_json(stage_path, "STAGE")
    source_commit = str(authority.get("source_commit", ""))
    stage_commit = str(authority.get("authorization_parent_commit", ""))
    require(is_commit(source_commit) and is_commit(stage_commit), "GRAPH_COMMITS")
    require(git("rev-parse", "HEAD^") == stage_commit, "AUTHORITY_PARENT_NOT_STAGE")
    require(
        git("rev-parse", "HEAD^^") == source_commit, "AUTHORITY_GRANDPARENT_NOT_SOURCE"
    )
    require(
        git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            stage_commit,
        ).splitlines()
        == [STAGE_RELATIVE],
        "STAGE_COMMIT_NOT_SINGLE_PATH",
    )
    require(
        git(
            "diff-tree",
            "--no-commit-id",
            "--name-only",
            "--no-renames",
            "-r",
            authority_commit,
        ).splitlines()
        == [AUTHORITY_RELATIVE],
        "AUTHORITY_COMMIT_NOT_SINGLE_PATH",
    )
    require(
        sorted(git("diff", "--name-only", source_commit, authority_commit).splitlines())
        == sorted([STAGE_RELATIVE, AUTHORITY_RELATIVE]),
        "GRAPH_CHANGED_PATHS",
    )
    dependency = dependency_receipt()
    _, source_policy = manifest_binding()
    validate_stage(stage, source_commit, source_policy)
    validate_current_l14_authorities(stage, source_commit)
    require(
        stage.get("superseded_physical_supervisor_refusal")
        == supervisor_refusal_binding(source_commit),
        "GRAPH_CURRENT_SUPERVISOR_REFUSAL_BINDING",
    )
    require(
        stage.get("consumed_predecessor_physical_closure")
        == predecessor_physical_closure_binding(source_commit),
        "GRAPH_CURRENT_PREDECESSOR_PHYSICAL_CLOSURE_BINDING",
    )
    validate_authority(
        authority,
        stage_commit,
        sha256_file(stage_path),
        source_commit,
        source_policy,
    )
    authority_sha = sha256_file(authority_path)
    retained_runtime = l14_runtime.read_retained_runtime(
        stage.get("qualified_runtime_identity"), source_commit
    )
    l14_runtime.verify_qualified_binding(
        retained_runtime["l14_exact_runtime_images"],
        Path(l14_runtime.IMAGES["godot_console"]["path"]),
    )
    output_root = EVIDENCE_ROOT / (
        "qsdk-r10f-development-route-ghost-" + authority_sha[7:23]
    )
    require(not output_root.exists(), "PHYSICAL_IDENTITY_ALREADY_CONSUMED")
    return {
        "schema_version": "sporespore_qsdk_r10f_committed_authority_graph_check_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": ledger_scope("committed_graph_zero_world_check"),
        "ok": True,
        "source_commit": source_commit,
        "stage_commit": stage_commit,
        "authority_commit": authority_commit,
        "stage_freeze_raw_sha256": sha256_file(stage_path),
        "execution_authority_raw_sha256": authority_sha,
        "repair_design_raw_sha256": EXPECTED_REPAIR_DESIGN_SHA256,
        "branch_completeness_addendum_raw_sha256": EXPECTED_BRANCH_COMPLETENESS_ADDENDUM_SHA256,
        "superseded_physical_supervisor_refusal_raw_sha256": (
            EXPECTED_SUPERVISOR_REFUSAL_SHA256
        ),
        "consumed_predecessor_physical_closure_raw_sha256": (
            EXPECTED_PREDECESSOR_PHYSICAL_CLOSURE_SHA256
        ),
        "qualified_source_path_count": dependency["qualified_source_path_count"],
        "qualified_source_path_sha256": dependency["qualified_source_path_sha256"],
        "physical_output_root": output_root.as_posix(),
        "physical_identity_consumed": False,
        "physical_execution_authorized_by_committed_graph": True,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def self_test() -> dict[str, Any]:
    source = "1" * 40
    stage_commit = "2" * 40
    stage_sha = "sha256:" + "3" * 64
    policy = {"count": 77, "digest": "sha256:" + "4" * 64}
    qualification = {
        "l14_component_qualification": l14_components.expected_receipt(),
        "l14_exact_runtime_images": l14_runtime.expected_binding(),
        "completion_binding": {
            "path": "C:/synthetic/qualification_completion.json",
            "byte_length": 1,
            "raw_sha256": "sha256:" + "5" * 64,
        },
        "runtime_binding": {
            "path": "C:/synthetic/runtime_identity.json",
            "byte_length": 1,
            "raw_sha256": "sha256:" + "6" * 64,
        },
    }
    authorities = [
        {
            "role": "synthetic_preserved_authority",
            "path": "sdk/synthetic.json",
            "git_blob_oid": "7" * 40,
            "byte_length": 1,
            "raw_sha256": "sha256:" + "8" * 64,
        }
    ]
    refusal = {
        "path": "sdk/synthetic_refusal.json",
        "byte_length": EXPECTED_SUPERVISOR_REFUSAL_BYTES,
        "raw_sha256": EXPECTED_SUPERVISOR_REFUSAL_SHA256,
        "status": "closed_infrastructure_invalid_pre_physics_output_identity_unconsumed",
        "repair_id": "QSDK-R10F-L2",
        "physical_attempt_identity_consumed": False,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
    }
    # These are exact immutable authority projections, not simulated evidence.
    repair_design = l14_authority.expected_repair_binding()
    predecessor_physical_closure = l14_authority.expected_predecessor_binding()
    branch_completeness_addendum = l14_authority.expected_addendum_binding()
    stage = build_stage(
        source,
        policy,
        qualification,
        authorities,
        repair_design,
        refusal,
        predecessor_physical_closure,
        branch_completeness_addendum,
    )
    validate_stage(stage, source, policy)
    authority = build_authority(stage_commit, stage_sha, source, policy)
    validate_authority(authority, stage_commit, stage_sha, source, policy)
    rejected = 0
    for target, key, changed in (
        ("stage", "source_commit", "9" * 40),
        ("stage", "physical_execution_authorized_by_freeze", True),
        ("stage", "official_zero_world_qualification_passed", False),
        ("stage", "maximum_world_count", 3),
        ("stage", "maximum_child_process_count", 3),
        ("stage", "maximum_world_count_per_child", 2),
        (
            "stage",
            "ordered_child_roles",
            ["kick_passive_recovery_resume", "matched_no_kick_continuation"],
        ),
        ("stage", "child_processes_overlap_in_wall_clock_time", True),
        ("stage", "child_retry_permitted", True),
        ("stage", "child_replacement_permitted", True),
        ("stage", "preserved_bound_authorities", []),
        ("stage", "repair_design", {}),
        ("stage", "branch_completeness_addendum", {}),
        ("stage", "branch_completeness_addendum_sha256", EXPECTED_REPAIR_DESIGN_SHA256),
        ("stage", "repair_id", "QSDK-R10F"),
        ("stage", "superseded_physical_supervisor_refusal", {}),
        ("stage", "consumed_predecessor_physical_closure", {}),
        ("authority", "authorization_parent_commit", "9" * 40),
        ("authority", "physical_execution_authorized", False),
        ("authority", "physical_identity_consumed", True),
        ("authority", "same_identity_rerun_permitted", True),
        ("authority", "maximum_campaign_attempt_count", 2),
        ("authority", "maximum_child_process_count", 3),
        ("authority", "maximum_world_count_per_child", 2),
        (
            "authority",
            "ordered_child_roles",
            ["kick_passive_recovery_resume", "matched_no_kick_continuation"],
        ),
        ("authority", "child_processes_overlap_in_wall_clock_time", True),
        ("authority", "child_retry_permitted", True),
        ("authority", "child_replacement_permitted", True),
        ("authority", "repair_id", "QSDK-R10F"),
        ("authority", "repair_design_sha256", "sha256:" + "9" * 64),
        ("authority", "branch_completeness_addendum_sha256", EXPECTED_REPAIR_DESIGN_SHA256),
        (
            "authority",
            "superseded_physical_supervisor_refusal_sha256",
            "sha256:" + "9" * 64,
        ),
        (
            "authority",
            "consumed_predecessor_physical_closure_sha256",
            "sha256:" + "9" * 64,
        ),
    ):
        mutation = json.loads(json.dumps(stage if target == "stage" else authority))
        mutation[key] = changed
        try:
            if target == "stage":
                validate_stage(mutation, source, policy)
            else:
                validate_authority(mutation, stage_commit, stage_sha, source, policy)
        except MaterializationFailure:
            rejected += 1
    require(rejected == 33, "SELF_TEST_LEGACY_MUTATION_REJECTIONS")
    component_cases = [None, *[case["receipt"] for case in l14_components.receipt_corruptions()]]
    for original, validator in (
        (stage, lambda changed: validate_stage(changed, source, policy)),
        (authority, lambda changed: validate_authority(changed, stage_commit, stage_sha, source, policy)),
    ):
        for corrupted in component_cases:
            changed = copy.deepcopy(original)
            if corrupted is None:
                changed.pop("l14_component_qualification")
            else:
                changed["l14_component_qualification"] = corrupted
            try:
                validator(changed)
            except MaterializationFailure:
                rejected += 1
            else:
                raise MaterializationFailure("SELF_TEST_L14_COMPONENT_ACCEPTED")
    require(rejected == 33 + 2 * len(component_cases), "SELF_TEST_COMPONENT_REJECTIONS")
    runtime_cases = [None, *[case["binding"] for case in l14_runtime.binding_corruptions()]]
    for original, validator in (
        (stage, lambda changed: validate_stage(changed, source, policy)),
        (authority, lambda changed: validate_authority(changed, stage_commit, stage_sha, source, policy)),
    ):
        for corrupted in runtime_cases:
            changed = copy.deepcopy(original)
            if corrupted is None:
                changed.pop("l14_exact_runtime_images")
            else:
                changed["l14_exact_runtime_images"] = corrupted
            try:
                validator(changed)
            except MaterializationFailure:
                rejected += 1
            else:
                raise MaterializationFailure("SELF_TEST_L14_RUNTIME_ACCEPTED")
    require(rejected == 33 + 2 * (len(component_cases) + len(runtime_cases)), "SELF_TEST_MUTATION_REJECTIONS")
    return {
        "schema_version": "sporespore_qsdk_r10f_authority_materializer_self_test_v1",
        "gate_id": "QSDK-R10F",
        "repair_id": REPAIR_ID,
        "ledger_scope": ledger_scope("zero_world_authority_materializer_self_test"),
        "ok": True,
        "stage_valid_control_count": 1,
        "authority_valid_control_count": 1,
        "mutation_rejection_count": rejected,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "scene_tree_insertion_count": 0,
        "native_readback_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("self-test")
    subparsers.add_parser("read-l15-candidate-output")
    for command in ("stage-l15", "authority-l15"):
        selected = subparsers.add_parser(command)
        selected.add_argument("--source-commit", required=True)
    subparsers.add_parser("graph-check-l15")
    for command in (
        "prepare-l15-qualification",
        "complete-l15-qualification",
        "read-l15-qualification",
    ):
        qualification_parser = subparsers.add_parser(command)
        qualification_parser.add_argument("--source-commit", required=True)
        if command == "complete-l15-qualification":
            qualification_parser.add_argument("--exit-code", required=True, type=int)
    stage_parser = subparsers.add_parser("stage")
    stage_parser.add_argument("--qualification-dir", required=True, type=Path)
    stage_parser.add_argument("--source-commit", default="")
    authority_parser = subparsers.add_parser("authority")
    authority_parser.add_argument("--source-commit", default="")
    subparsers.add_parser("graph-check")
    arguments = parser.parse_args()
    try:
        if arguments.command == "self-test":
            receipt = self_test()
            marker = SELF_TEST_MARKER
        elif arguments.command == "read-l15-candidate-output":
            receipt = read_l15_qualification_candidate_output(sys.stdin.buffer.read())
            marker = L15_OUTPUT_MARKER
        elif arguments.command == "stage-l15":
            receipt = materialize_l15_stage(arguments.source_commit)
            marker = MATERIALIZED_MARKER
        elif arguments.command == "authority-l15":
            receipt = materialize_l15_authority(arguments.source_commit)
            marker = MATERIALIZED_MARKER
        elif arguments.command == "graph-check-l15":
            receipt = l15_committed_graph_binding()
            marker = "QSDK_R10F_L15_COMMITTED_GRAPH_BINDING "
        elif arguments.command == "prepare-l15-qualification":
            receipt = prepare_l15_official_qualification(arguments.source_commit)
            marker = "QSDK_R10F_L15_QUALIFICATION_PREPARED "
        elif arguments.command == "complete-l15-qualification":
            receipt = complete_l15_official_qualification(
                arguments.source_commit, arguments.exit_code
            )
            marker = "QSDK_R10F_L15_QUALIFICATION_COMPLETE "
        elif arguments.command == "read-l15-qualification":
            receipt = read_l15_official_qualification(arguments.source_commit)
            marker = "QSDK_R10F_L15_QUALIFICATION_DIRECTORY_PASS "
        elif arguments.command == "stage":
            receipt = materialize_stage(arguments)
            marker = MATERIALIZED_MARKER
        elif arguments.command == "authority":
            receipt = materialize_authority(arguments)
            marker = MATERIALIZED_MARKER
        else:
            receipt = committed_graph_check()
            marker = GRAPH_MARKER
    except (MaterializationFailure, OSError) as exc:
        print(f"QSDK_R10F_AUTHORITY_MATERIALIZER_FAIL {exc}", file=sys.stderr)
        return 1
    print(marker + json.dumps(receipt, sort_keys=True, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
