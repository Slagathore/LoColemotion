"""Preserve the passed L14 qualification and test its actual next reader.

Retained files are never rewritten. The reader controls use an explicitly
virtual qualification directory; they cannot consume an official identity.
"""

from __future__ import annotations

import ast
import copy
import hashlib
import json
from pathlib import Path
from typing import Any, Mapping
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "sdk/qsdk_r10f_l14_qualified_source_retirement_v1.json"
BYTE_LENGTH = 6403
SHA256 = "sha256:958d57dbe0ca490a3e07b32d1442ba429ceeb6857637e7a8da97e935b1b48a69"
SOURCE = "8a05eddb32e6f3837dbad866f3ecde652fbb6f4a"
FIELD = "branch_completeness_addendum_sha256"
WRONG_FIELD = "branch_completeness_addendum_raw_sha256"
ZERO_COUNTERS = (
    "model_construction_count",
    "world_attempt_count",
    "world_build_count",
    "scene_tree_insertion_count",
    "native_readback_count",
    "solver_step_count",
)
DENIED_FLAGS = (
    "physics_state_modified",
    "physical_execution_authorized",
    "physical_acceptance_authority",
    "release_authority",
)


def require(condition: bool, code: str) -> None:
    if not condition:
        raise ValueError(code)


def zero_receipt(mode: str) -> dict[str, Any]:
    return {
        "gate_id": "QSDK-R10F",
        "repair_id": "QSDK-R10F-L14",
        "ok": True,
        "ledger_scope": {
            "subsystem": "recovery",
            "engine_scope": "godot_jolt",
            "authority_mode": mode,
            "question_class": "development",
        },
        **dict.fromkeys(ZERO_COUNTERS, 0),
        **dict.fromkeys(DENIED_FLAGS, False),
    }


def audit_retirement() -> dict[str, Any]:
    import qsdk_r10f_authority_materializer as materializer

    raw = PATH.read_bytes()
    require(
        len(raw) == BYTE_LENGTH and materializer.sha256_bytes(raw) == SHA256,
        "L14_RETIREMENT_IDENTITY",
    )
    record = json.loads(raw)
    require(
        record["source_commit"] == SOURCE
        and record["qualification_still_passed"] is True,
        "L14_RETIREMENT_SOURCE",
    )
    evidence = record["retained_evidence"]
    evidence_root = Path(evidence["root"])
    require(
        sorted(p.name for p in evidence_root.iterdir() if p.is_file())
        == sorted(Path(item["path"]).name for item in evidence["files"]),
        "L14_RETIREMENT_FILE_POPULATION",
    )
    for expected in evidence["files"]:
        require(
            materializer.file_identity(Path(expected["path"])) == expected,
            "L14_RETIREMENT_RETAINED_BYTES",
        )
    require(
        evidence["file_count"] == 6 and evidence["total_byte_length"] == 95_755,
        "L14_RETIREMENT_FILE_COUNTS",
    )
    sources = {}
    for binding in record["frozen_sources"]:
        path = binding["path"]
        source = materializer.run(["git", "show", SOURCE + ":" + path]).stdout
        require(
            materializer.git("rev-parse", SOURCE + ":" + path)
            == binding["git_blob_oid"]
            and len(source.encode("utf-8")) == binding["byte_length"]
            and materializer.sha256_bytes(source.encode("utf-8"))
            == binding["raw_sha256"],
            "L14_RETIREMENT_FROZEN_SOURCE:" + path,
        )
        sources[path] = source
    implementation = materializer.read_json(
        evidence_root / "implementation_audit.json", "RETIRED_IMPLEMENTATION"
    )
    completion = materializer.read_json(
        evidence_root / "qualification_completion.json", "RETIRED_COMPLETION"
    )
    require(
        implementation["status"] == "passed_complete_zero_world_implementation"
        and completion["official_zero_world_qualification_passed"] is True
        and implementation[FIELD] == record["observed_refusal"]["actual_digest"]
        and WRONG_FIELD not in implementation,
        "L14_RETIREMENT_PASSED_SOURCE",
    )
    # Re-execute the exact frozen reader predicate, not a hand-transcribed
    # substitute. Other retained prerequisites remain content-addressed above.
    # Do not require a later installation to still be the historical runtime.
    consumer_path = "sdk/conformance/qsdk_r10f_authority_materializer.py"
    frozen = sources[consumer_path]
    namespace = {
        "__name__": "_l14_retired_predicate_only",
        "__file__": str(ROOT / consumer_path),
    }
    exec(compile(frozen, "<retired-l14-materializer>", "exec"), namespace)
    nodes = [
        node
        for node in ast.walk(ast.parse(frozen))
        if isinstance(node, ast.Call)
        and isinstance(node.func, ast.Name)
        and node.func.id == "require"
        and len(node.args) == 2
        and isinstance(node.args[1], ast.Constant)
        and node.args[1].value == "QUALIFICATION_IMPLEMENTATION_FIELDS"
    ]
    require(len(nodes) == 1, "L14_RETIREMENT_FROZEN_PREDICATE_COUNT")
    policy = json.loads(sources["sdk/qsdk_r10f_dependency_manifest_v18.json"])["policy"]
    local = {
        "implementation": implementation,
        "implementation_source": implementation["source"],
        "source_commit": SOURCE,
        "source": {"tree": record["source_tree_git_oid"]},
        "source_policy": {
            "count": policy["expected_qualified_source_count"],
            "digest": policy["expected_qualified_source_path_sha256"],
        },
    }
    expression = ast.Expression(nodes[0].args[0])
    require(
        eval(
            compile(expression, "<retired-reader-predicate>", "eval"), namespace, local
        )
        is False,
        "L14_RETIREMENT_EXACT_REFUSAL_NOT_REPRODUCED",
    )
    corrected = copy.deepcopy(expression)
    substitutions = 0
    for node in ast.walk(corrected):
        if isinstance(node, ast.Constant) and node.value == WRONG_FIELD:
            node.value = FIELD
            substitutions += 1
    require(substitutions == 1, "L14_RETIREMENT_NOT_ONE_FIELD")
    code = compile(corrected, "<diagnostic-only-one-field-substitution>", "eval")
    require(eval(code, namespace, local) is True, "L14_RETIREMENT_ONE_FIELD_DIAGNOSIS")
    rejected = 0
    for value in (None, False, 0, "", "sha256:" + "0" * 64, "remove"):
        changed = copy.deepcopy(implementation)
        changed[WRONG_FIELD] = implementation[FIELD]  # A legacy alias cannot rescue it.
        if value == "remove":
            del changed[FIELD]
        else:
            changed[FIELD] = value
        require(
            eval(code, namespace, {**local, "implementation": changed}) is False,
            "L14_RETIREMENT_CORRUPTION_ACCEPTED",
        )
        rejected += 1
    return {
        **zero_receipt("retained_qualification_reader_refusal_audit"),
        "schema_version": "sporespore_qsdk_r10f_l14_qualified_source_retirement_audit_v1",
        "retirement_raw_sha256": SHA256,
        "retired_source_commit": SOURCE,
        "retained_file_count": 6,
        "retained_total_byte_length": 95_755,
        "frozen_source_count": 4,
        "qualification_preserved_passing": True,
        "frozen_original_reader_predicate_refusal_reproduced": True,
        "one_field_diagnostic_predicate_positive_count": 1,
        "mutation_rejection_count": rejected,
        "old_qualification_adopted": False,
    }


def audit_reader_contract(receipt: Mapping[str, Any]) -> dict[str, Any]:
    """Feed this producer's actual receipt into the whole production reader.

    Only source-authority flags and virtual enclosing files are projected. This
    function never writes a qualification, alters the caller, or mints authority.
    """
    import qsdk_r10f_authority_materializer as materializer

    original_receipt = copy.deepcopy(dict(receipt))
    source = {
        "commit": receipt["source"]["source_commit"],
        "tree": receipt["source"]["source_tree"],
    }
    root = materializer.qualification_directory(source["commit"]).resolve()
    retired_root = materializer.qualification_directory(SOURCE)
    template_attempt = materializer.read_json(
        retired_root / "qualification_attempt.json", "TEMPLATE_ATTEMPT"
    )
    template_completion = materializer.read_json(
        retired_root / "qualification_completion.json", "TEMPLATE_COMPLETION"
    )
    positive = copy.deepcopy(dict(receipt))
    for field in (
        "official_qualification",
        "source_clean",
        "source_origin_main_equal",
        "source_live_main_equal",
    ):
        positive["source"][field] = True
    cases = [("actual_producer_receipt", positive, True)]
    for label, key, value in (
        ("missing_addendum", FIELD, None),
        ("wrong_addendum", FIELD, "sha256:" + "0" * 64),
        ("legacy_alias_only", FIELD, "remove"),
        ("source_not_clean", "source", {**positive["source"], "source_clean": False}),
        (
            "wrong_source_population",
            "qualified_source_path_count",
            positive["qualified_source_path_count"] + 1,
        ),
        (
            "wrong_manifest_path_set",
            "qualified_source_path_sha256",
            "sha256:" + "0" * 64,
        ),
        ("physical_authority", "physical_execution_authorized", True),
    ):
        changed = copy.deepcopy(positive)
        if label == "legacy_alias_only":
            changed[WRONG_FIELD] = changed.pop(FIELD)
        else:
            changed[key] = value
        cases.append((label, changed, False))
    accepted = 0
    rejected = 0
    real_read = Path.read_text
    real_file_identity = materializer.file_identity
    real_is_file, real_is_dir, real_exists = Path.is_file, Path.is_dir, Path.exists
    for label, implementation, should_accept in cases:
        attempt, completion = copy.deepcopy(template_attempt), copy.deepcopy(
            template_completion
        )
        for document in (attempt, completion):
            document["source_commit"] = source["commit"]
            document["qualified_source_path_count"] = receipt[
                "qualified_source_path_count"
            ]
            document["qualified_source_path_sha256"] = receipt[
                "qualified_source_path_sha256"
            ]
            document["dependency_manifest_raw_sha256"] = receipt[
                "dependency_manifest_raw_sha256"
            ]
            document["l14_exact_runtime_images"] = receipt["runtime_identity"][
                "l14_exact_runtime_images"
            ]
            document["synthetic_qualification_directory_fixture_only"] = True
        completion["source_tree"] = source["tree"]

        def encode(value):
            return (
                json.dumps(value, sort_keys=True, separators=(",", ":")) + "\n"
            ).encode("utf-8")

        files = {
            root / "qualification_attempt.json": encode(attempt),
            root / "implementation_audit.json": encode(implementation),
            root / "runtime_identity.json": encode(implementation["runtime_identity"]),
            root / "qualification_stdout.log": b"EXPLICIT SYNTHETIC READER FIXTURE\n",
            root / "qualification_stderr.log": b"",
        }

        def identity(path, *, relative_to=None):
            resolved = path.resolve()
            if resolved not in files:
                return real_file_identity(path, relative_to=relative_to)
            data = files[resolved]
            return {
                "path": resolved.as_posix(),
                "byte_length": len(data),
                "raw_sha256": "sha256:" + hashlib.sha256(data).hexdigest(),
            }

        for key, name in (
            ("qualification_attempt", "qualification_attempt.json"),
            ("implementation_audit", "implementation_audit.json"),
            ("runtime_identity", "runtime_identity.json"),
            ("qualification_stdout", "qualification_stdout.log"),
            ("qualification_stderr", "qualification_stderr.log"),
        ):
            completion[key] = identity(root / name)
        files[root / "qualification_completion.json"] = encode(completion)

        def read(path, *args, **kwargs):
            return (
                files[path.resolve()].decode("utf-8")
                if path.resolve() in files
                else real_read(path, *args, **kwargs)
            )

        # Only the virtual filesystem and already-separately-tested current
        # image reopening are substituted. All actual directory-reader logic,
        # JSON parsing, semantic predicates and binding comparisons execute.
        with mock.patch.object(Path, "read_text", read), mock.patch.object(
            Path, "is_file", lambda p: True if p.resolve() in files else real_is_file(p)
        ), mock.patch.object(
            Path, "is_dir", lambda p: True if p.resolve() == root else real_is_dir(p)
        ), mock.patch.object(
            Path,
            "exists",
            lambda p: (
                False
                if p.resolve() == root / "qualification_failure.json"
                else real_exists(p)
            ),
        ), mock.patch.object(
            materializer, "file_identity", identity
        ), mock.patch.object(
            materializer.l14_runtime,
            "bind_runtime",
            return_value=materializer.l14_runtime.expected_binding(),
        ):
            failure = None
            try:
                result = materializer.validate_qualification(root, source)
            except materializer.MaterializationFailure as exc:
                failure = str(exc)
            if should_accept:
                require(failure is None, "L14_READER_POSITIVE:" + str(failure))
                require(
                    result["runtime_binding"]
                    == identity(root / "runtime_identity.json"),
                    "L14_READER_RUNTIME_BINDING",
                )
                accepted += 1
            else:
                require(
                    failure == "QUALIFICATION_IMPLEMENTATION_FIELDS",
                    "L14_READER_CORRUPTION:" + label + ":" + str(failure),
                )
                rejected += 1
    require(dict(receipt) == original_receipt, "L14_READER_CHANGED_PRODUCER")
    require(accepted == 1 and rejected == 7, "L14_READER_CONTROL_COUNTS")
    return {
        **zero_receipt("actual_producer_to_complete_qualification_reader_control"),
        "schema_version": "sporespore_qsdk_r10f_l14_qualification_reader_contract_v1",
        "validation_source": "actual_materializer_complete_qualification_directory_reader",
        "positive_control_count": accepted,
        "mutation_rejection_count": rejected,
        "actual_producer_receipt_consumed": True,
        "actual_receipt_source_flags_preserved": True,
        "virtual_qualification_directory_only": True,
        "current_runtime_read_substituted_only_in_fixture": True,
        "official_or_physical_identity_created": False,
    }
