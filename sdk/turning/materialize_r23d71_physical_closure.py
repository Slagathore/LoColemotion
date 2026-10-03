#!/usr/bin/env python3
"""Materialize and audit the immutable R23D71 physical closure.

R23D71 consumed all nine native worlds on fresh seed 23191.  Every worker
completed its 2,992-step horizon and retained a CAS trace.  The frozen result
is nevertheless invalid: all three MuJoCo success payloads omitted the
required ``question_class`` identity and were retained by the supervisor as
transport failures; the six Godot/Jolt and Rapier reports reached the frozen
evaluator but their trace artifact receipts did not carry its complete
transport metadata contract.  The same evaluator also observed the independent
Rapier forward-displacement gate failure in all three Rapier cells.

This closure preserves those exact observations.  It never repairs the
consumed evidence, re-evaluates a trace, changes a threshold, or promotes the
campaign to a turning result.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any, Iterable, Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
STATE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"
EVIDENCE_ROOT = (
    STATE_ROOT
    / "qsdk-r23d71-physical-20260826T055614Z-f82e3454-lca1-python"
)
QUALIFICATION_ROOT = (
    STATE_ROOT
    / "qsdk-r23d71-qualification-20260826T054807Z-f82e3454-lca1-python"
)
FAILED_QUALIFICATION_ROOT = (
    STATE_ROOT
    / "qsdk-r23d71-qualification-20260826T054220Z-3e433d35-lca1-python"
)
ARTIFACT_ROOT = STATE_ROOT / "artifacts" / "sha256"
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d71_success_terminal_projection_repaired_three_engine_turning_"
    "validation_closure_v1.json"
)
AUDIT_PATH = REPO_ROOT / "tests" / "test_qsdk_r23d71_physical_closure.ps1"
RELEASE_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_release_contract.json"
SUPPORT_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_support_matrix.json"

SOURCE_COMMIT = "f82e3454dd8cfa53a7efced948c9ba130a0e2cda"
SOURCE_TREE = "e35098f839f6dcdc6af2a0620bfd8335b7735381"
INITIAL_QUALIFICATION_SOURCE = "3e433d359753abc89abdf1418fd6bbfa9f4a9acf"
CAMPAIGN_ID = (
    "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-"
    "THREE-ENGINE-TURNING-VALIDATION"
)
GATE_ID = "QSDK-R23D71"
ATTEMPT_ID = "63729f4ecfbc414688b6a8b2251707e9"
CLOSED_STATUS = (
    "closed_consumed_invalid_complete_after_nine_native_worlds_"
    "transport_contract_and_rapier_forward_gate_failures"
)
CLASSIFICATION = "invalid_or_incomplete_exact_seed_23191_three_engine_portable_turning"
CLOSURE_RELATIVE = (
    "sdk/turning/r23d71_success_terminal_projection_repaired_three_engine_"
    "turning_validation_closure_v1.json"
)
AUDIT_RELATIVE = "tests/test_qsdk_r23d71_physical_closure.ps1"
MUJOCO_TRANSPORT_FAILURE = (
    "R23D71_SUPERVISOR_TERMINAL_CAPTURE:QSDK-R23D71: "
    "worker terminal identity missing: question_class"
)
TRACE_FAILURE = "R23D65_TRACE_ARTIFACT_IDENTITY"
RAPIER_FORWARD_FAILURE = "R23D34_FORWARD_DISPLACEMENT"
MINIMUM_FORWARD_DISPLACEMENT_M = 0.030123046875
ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CELL_IDS = [
    f"r23d71__{engine}__s23191__{arm}"
    for engine in ENGINES
    for arm in ARMS
]

SOURCE_BLOBS = {
    "sdk/run_qsdk_r23d71_supervisor.ps1": "a206961f62dc756f0e9a825238cf72fcbb73852d",
    "sdk/locomotion_terminal_execution_projection.ps1": (
        "502317e88272dd928ff8bc6096e852f7b18dcc6a"
    ),
    "tests/test_sdk_qsdk_r23d71_godot_jolt_worker.gd": (
        "886a761947ce29367e21845837a3101c4227d293"
    ),
    "sdk/adapters/rapier/src/qsdk_r23d71_turning_route.rs": (
        "51e2a6a5ad0a714bf051193732cdecc89769e164"
    ),
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d71_turning_route.py": (
        "c2a6e390511f456d8ae991014f9791750b59787d"
    ),
    "sdk/turning/r23d71_production_route_three_engine_turning_evaluator.py": (
        "f7d0f8c78facdddc0ac471d6293725fbbcede4cd"
    ),
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py": (
        "ba5d48ce0a2673e258c4302035be3f5c8d2dbccd"
    ),
    "sdk/turning/r23d71_receipt_contract.py": (
        "16235764f3fc8656bf1fc3d8663cbbecfddb2c36"
    ),
    "sdk/turning/r23d71_production_route_runtime.py": (
        "aaf989585d48e74aa63116d7f1edd3a5ab7be901"
    ),
    "sdk/turning/r23d71_production_route_three_engine_turning_implementation_v1.json": (
        "6da1e05443f9a501a1da9578495a2e854133f412"
    ),
    "sdk/turning/r23d71_success_terminal_projection_repaired_three_engine_turning_preregistration_v1.json": (
        "0a0c4c233b1e6aeb13ee7f001d4ab1334feec7b4"
    ),
}

EXPECTED_PHYSICAL_POPULATION = {
    "complete_file_population_count": 72,
    "complete_file_population_byte_count": 677221819,
    "retained_unique_digest_count": 54,
    "cas_backed_file_count": 63,
    "non_cas_file_count": 9,
    "non_cas_relative_paths": [
        "pending-traces/r23d71__godot_jolt__s23191__negative_heading.rows.json",
        "pending-traces/r23d71__godot_jolt__s23191__positive_heading.rows.json",
        "pending-traces/r23d71__godot_jolt__s23191__reference_zero.rows.json",
        "pending-traces/success_terminal_projection_repaired_three_engine_turning_validation__r23d71__mujoco__s23191__negative_heading.rows.json",
        "pending-traces/success_terminal_projection_repaired_three_engine_turning_validation__r23d71__mujoco__s23191__positive_heading.rows.json",
        "pending-traces/success_terminal_projection_repaired_three_engine_turning_validation__r23d71__mujoco__s23191__reference_zero.rows.json",
        "pending-traces/success_terminal_projection_repaired_three_engine_turning_validation__r23d71__rapier_parry__s23191__negative_heading.rows.json",
        "pending-traces/success_terminal_projection_repaired_three_engine_turning_validation__r23d71__rapier_parry__s23191__positive_heading.rows.json",
        "pending-traces/success_terminal_projection_repaired_three_engine_turning_validation__r23d71__rapier_parry__s23191__reference_zero.rows.json",
    ],
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": (
        "relative_path_unicode_codepoint_ascending"
    ),
    "canonical_population_manifest_byte_length": 10443,
    "canonical_population_manifest_sha256": (
        "sha256:28f122f0ed80f1aa50e0ef9ff8b76105d339dd35d186ddbb0f66b03f72f653c7"
    ),
}

EXPECTED_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 50,
    "complete_file_population_byte_count": 499566,
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": (
        "relative_path_unicode_codepoint_ascending"
    ),
    "canonical_population_manifest_byte_length": 5842,
    "canonical_population_manifest_sha256": (
        "sha256:8b8e636ae4ba4d72413f59b4fbb134625ac32dcd59dc8969252b56e886a183f9"
    ),
}

EXPECTED_FAILED_QUALIFICATION_POPULATION = {
    "complete_file_population_count": 13,
    "complete_file_population_byte_count": 12782,
    "canonical_population_manifest_format": (
        "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
    ),
    "canonical_population_manifest_sort_order": (
        "relative_path_unicode_codepoint_ascending"
    ),
    "canonical_population_manifest_byte_length": 1482,
    "canonical_population_manifest_sha256": (
        "sha256:e470ae6478a91f3929f72d81e483daf4b6c917f4183f16a76e03a2e2b4ba735a"
    ),
}

PRIMARY_BINDINGS = {
    "physical-freeze.json": (
        328586,
        "b632e98b67bc651bf893ad4aa0e72820ec606bff62d652e76c65a6ec28b5eb58",
    ),
    "attempt-authorization.json": (
        163457,
        "4b069d6f934903cfc30bd676a92fb2b7c3660008b259e1f5bc2a3a1f4f3a5bb4",
    ),
    "authorization-preflight.json": (
        26021,
        "041486a66d1af1380a79582186db4cb11c987098d70a738eca9a44cbc800cc9d",
    ),
    "terminal-paths.json": (
        1435,
        "47b2c2b82244187096c328f587833f944cc046522c7c714dfdd9532765a13d60",
    ),
    "complete-evaluation.json": (
        8928,
        "79488bb02b79bec619b0583c0857bed0e6f408032674a7c4c4f3a6f85aa82e8b",
    ),
    "report.json": (
        44343,
        "f4e6cc9606cec4086e6d1ee1cd25358c8c0fff967c19d0f8c8e5ce00e293fe52",
    ),
    "completion.json": (
        2952,
        "9e83ccd320bd6cc5e3436ad654bc8e12efaab542165d180e8148def7b4887d11",
    ),
}

TERMINAL_BINDINGS = {
    "r23d71__godot_jolt__s23191__negative_heading": (
        74600,
        "49b6e06d155be429086c7013805c25388f145c6923be0396a9e6906123b07c49",
    ),
    "r23d71__godot_jolt__s23191__positive_heading": (
        74448,
        "546aa827bb50e2f7abf0b3ea62c64651da7f6a15f6062856c56f40cade9fcab1",
    ),
    "r23d71__godot_jolt__s23191__reference_zero": (
        74502,
        "43c1e015d7bd652268c0435264c87db7cf3bb76b34c8b26320e895716efd1192",
    ),
    "r23d71__mujoco__s23191__negative_heading": (
        30582,
        "b41b589aaa2480862b90692f2d16d704eaff4e55c9fb67748e393bacac4fd2a5",
    ),
    "r23d71__mujoco__s23191__positive_heading": (
        30580,
        "bb33f96255627dfb325d66aca7a03f98c97446c081bf4bf7ee014c72e6bbc409",
    ),
    "r23d71__mujoco__s23191__reference_zero": (
        30570,
        "b3a0aeed7fac5bc08b8ed3f710295442f446acd0f81f8d5a62e6a2f5905db6b7",
    ),
    "r23d71__rapier_parry__s23191__negative_heading": (
        27949,
        "057e64111be29f2cc91be560d6725f23b839ef051fc98c7594cecd832efd5a62",
    ),
    "r23d71__rapier_parry__s23191__positive_heading": (
        27950,
        "5490dd68e7e07c5599cc913b6b5845f0ecd9a6f3f8666500cbd32c7fdd249dc2",
    ),
    "r23d71__rapier_parry__s23191__reference_zero": (
        27942,
        "51af78fba064f90996aff9d6b73133cb116246aba48736ad18fb5c43ef86a77c",
    ),
}

TRACE_BINDINGS = {
    "r23d71__godot_jolt__s23191__negative_heading": (
        35028255,
        "2341ea0f5121510764cc7036affa1b68e9b7d3bb743481795099bdb17cc18d05",
    ),
    "r23d71__godot_jolt__s23191__positive_heading": (
        35006792,
        "388e4edb60e3f389c7f006e301b2d80e257bea26cd9d53e267abb9903ac77b78",
    ),
    "r23d71__godot_jolt__s23191__reference_zero": (
        34993132,
        "261711270dbe297f44021d939edf0eb8e6e74cb4623ffe6e3b6ff8a08f8dd315",
    ),
    "r23d71__mujoco__s23191__negative_heading": (
        32976222,
        "a003e571bfb5e341c541caf0479ea2a8590272697a36c5454438971d2fae5de1",
    ),
    "r23d71__mujoco__s23191__positive_heading": (
        32973461,
        "0cc2e5ee3355604b30bf31018b98a93f630e664487acd5bd94f8f2d1c142b843",
    ),
    "r23d71__mujoco__s23191__reference_zero": (
        32968603,
        "5bc78ba480c058651eb2bc224854cc8ed902ee7571b9d440d1c411b02989d3fd",
    ),
    "r23d71__rapier_parry__s23191__negative_heading": (
        44677656,
        "9bdebce27643cf182ba02e6afd2e66db6afdf93cf8c671ee9fbcba06dfb2ce4d",
    ),
    "r23d71__rapier_parry__s23191__positive_heading": (
        44669075,
        "8bb79ab1a5ab12582e546decb6d535b111313986c8484c2d8c6e861951dcf982",
    ),
    "r23d71__rapier_parry__s23191__reference_zero": (
        44700407,
        "02f578c443b8e88d95f939e671b945387892fc65c7eeed983bba35c03a69130e",
    ),
}

QUALIFICATION_BINDINGS = {
    "attestation.json": (
        153853,
        "28cc2e1686559ad485f757f32d6bbef7b100b20a5ed33f4d09a033d922a81d4b",
    ),
    "adoption.json": (
        3302,
        "e6b6a1411989a6bbb33c86ea4c9fe15acf494323e59182c2b84bd6ed5fb8e422",
    ),
}
FAILED_QUALIFICATION_BINDING = (
    640,
    "7753eff85b45d136d66a66e7ba20f38cdc8b44f62ec623362cead57c700b5143",
)


class ClosureError(RuntimeError):
    """Fail-closed R23D71 closure error."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ClosureError(message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def binding(path: Path) -> dict[str, Any]:
    return {
        "path": path.resolve().as_posix(),
        "raw_sha256": f"sha256:{sha256(path)}",
        "byte_length": path.stat().st_size,
    }


def verify_file(path: Path, expected: tuple[int, str]) -> None:
    require(path.is_file(), f"missing retained file: {path}")
    require(path.stat().st_size == expected[0], f"byte length drift: {path}")
    require(sha256(path) == expected[1], f"digest drift: {path}")


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def canonical_json(value: Any) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def git(*arguments: str) -> str:
    process = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
        text=True,
    )
    require(process.returncode == 0, f"git failed: {' '.join(arguments)}")
    return process.stdout.strip()


def source_text(relative: str) -> str:
    process = subprocess.run(
        ["git", "show", f"{SOURCE_COMMIT}:{relative}"],
        cwd=REPO_ROOT,
        check=False,
        capture_output=True,
    )
    require(process.returncode == 0, f"pinned source unavailable: {relative}")
    return process.stdout.decode("utf-8")


def population_identity(root: Path, *, cas_check: bool) -> dict[str, Any]:
    files = sorted(path for path in root.rglob("*") if path.is_file())
    lines: list[str] = []
    digests: set[str] = set()
    non_cas: list[str] = []
    total_bytes = 0
    for path in files:
        relative = path.relative_to(root).as_posix()
        raw = sha256(path)
        size = path.stat().st_size
        lines.append(f"{relative}\t{size}\tsha256:{raw}\n")
        digests.add(raw)
        total_bytes += size
        if cas_check:
            payload = ARTIFACT_ROOT / raw / "payload.bin"
            if (
                not payload.is_file()
                or payload.stat().st_size != size
                or sha256(payload) != raw
            ):
                non_cas.append(relative)
    manifest = "".join(lines).encode("utf-8")
    value: dict[str, Any] = {
        "complete_file_population_count": len(files),
        "complete_file_population_byte_count": total_bytes,
    }
    if cas_check:
        value.update(
            retained_unique_digest_count=len(digests),
            cas_backed_file_count=len(files) - len(non_cas),
            non_cas_file_count=len(non_cas),
            non_cas_relative_paths=non_cas,
        )
    value.update(
        canonical_population_manifest_format=(
            "relative_path<TAB>byte_length<TAB>sha256:<lowercase_hex><LF>"
        ),
        canonical_population_manifest_sort_order=(
            "relative_path_unicode_codepoint_ascending"
        ),
        canonical_population_manifest_byte_length=len(manifest),
        canonical_population_manifest_sha256=(
            "sha256:" + hashlib.sha256(manifest).hexdigest()
        ),
    )
    return value


def false_claims(value: Any) -> bool:
    return isinstance(value, dict) and all(item is False for item in value.values())


def verify_source_identity() -> None:
    require(git("rev-parse", "--show-toplevel") == REPO_ROOT.as_posix(), "wrong repository")
    require(
        git("remote", "get-url", "origin")
        == "https://github.com/Slagathore/sporespore.git",
        "wrong origin",
    )
    require(git("rev-parse", f"{SOURCE_COMMIT}^{{tree}}") == SOURCE_TREE, "source tree drift")
    for relative, object_id in SOURCE_BLOBS.items():
        require(
            git("rev-parse", f"{SOURCE_COMMIT}:{relative}") == object_id,
            f"pinned source blob drift: {relative}",
        )

    mujoco = source_text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d71_turning_route.py"
    )
    success = mujoco[
        mujoco.index("def _normalize_success_terminal") : mujoco.index(
            "def _project_failure_terminal"
        )
    ]
    require(
        "schema_version=REPORT_SCHEMA" in success
        and "question_class=" not in success,
        "observed MuJoCo success identity omission changed",
    )
    evaluator = source_text(
        "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py"
    )
    require(
        'artifact.get("trace_transport_id") != TRACE_TRANSPORT_ID' in evaluator
        and 'artifact.get("trace_transport_engine_id") != item.engine_id' in evaluator
        and 'artifact.get("canonical_ndjson") is not True' in evaluator
        and 'artifact.get("full_precision") is not True' in evaluator,
        "frozen trace artifact identity contract changed",
    )


def verify_qualifications() -> dict[str, Any]:
    require(
        population_identity(FAILED_QUALIFICATION_ROOT, cas_check=False)
        == EXPECTED_FAILED_QUALIFICATION_POPULATION,
        "failed qualification population changed",
    )
    failed_path = FAILED_QUALIFICATION_ROOT / "failure.json"
    verify_file(failed_path, FAILED_QUALIFICATION_BINDING)
    failed = load_json(failed_path)
    require(
        failed.get("campaign_id") == CAMPAIGN_ID
        and failed.get("source_commit") == INITIAL_QUALIFICATION_SOURCE
        and failed.get("campaign_local_qualification_passed") is False
        and failed.get("physical_launch_prerequisite_satisfied") is False,
        "failed qualification changed",
    )

    require(
        population_identity(QUALIFICATION_ROOT, cas_check=False)
        == EXPECTED_QUALIFICATION_POPULATION,
        "adopted qualification population changed",
    )
    for relative, expected in QUALIFICATION_BINDINGS.items():
        verify_file(QUALIFICATION_ROOT / relative, expected)
    attestation = load_json(QUALIFICATION_ROOT / "attestation.json")
    adoption = load_json(QUALIFICATION_ROOT / "adoption.json")
    require(
        attestation.get("campaign_id") == CAMPAIGN_ID
        and attestation.get("source", {}).get("commit") == SOURCE_COMMIT
        and attestation.get("executed_gate_count") == 16
        and attestation.get("all_gates_executed") is True
        and attestation.get("runtime", {}).get("python", {}).get("executable_path")
        == r"C:\Program Files\Python311\python.exe"
        and attestation.get("claims", {}).get("turning_acceptance") is False,
        "passing qualification changed",
    )
    require(
        adoption.get("campaign_id") == CAMPAIGN_ID
        and adoption.get("source_commit") == SOURCE_COMMIT
        and adoption.get("executed_gate_count") == 16
        and adoption.get("physical_launch_prerequisite_satisfied") is True
        and adoption.get("physical_acceptance_authority") is False
        and adoption.get("release_authority") is False,
        "qualification adoption changed",
    )
    return {
        "initial_provenance_negative": {
            "root": FAILED_QUALIFICATION_ROOT.resolve().as_posix(),
            "population_identity": EXPECTED_FAILED_QUALIFICATION_POPULATION,
            "failure": binding(failed_path),
            "passed_gate_count": 3,
            "failed_gate_id": "CAK1-EVIDENCE-PROVENANCE",
            "physical_world_count": 0,
            "finite_identity_consumed": False,
            "reusable": False,
        },
        "passing_adopted_qualification": {
            "root": QUALIFICATION_ROOT.resolve().as_posix(),
            "population_identity": EXPECTED_QUALIFICATION_POPULATION,
            "attestation": binding(QUALIFICATION_ROOT / "attestation.json"),
            "adoption": binding(QUALIFICATION_ROOT / "adoption.json"),
            "gate_pass_count": 16,
            "adopted_for_physical_launch": True,
            "physical_launch_prerequisite_satisfied": True,
            "turning_acceptance": False,
            "physical_acceptance_authority": False,
        },
    }


def _terminal_path(cell_id: str) -> Path:
    return EVIDENCE_ROOT / "cells" / cell_id / "terminal.json"


def _trace_path(cell_id: str) -> Path:
    return EVIDENCE_ROOT / "traces" / f"{cell_id}.ndjson"


def _worker_report(terminal: Mapping[str, Any]) -> Mapping[str, Any]:
    observed = terminal.get("observed_worker_terminal")
    return observed if isinstance(observed, Mapping) else terminal


def build_closure() -> dict[str, Any]:
    verify_source_identity()
    qualifications = verify_qualifications()
    require(EVIDENCE_ROOT.is_dir(), "physical evidence root is missing")
    require(
        population_identity(EVIDENCE_ROOT, cas_check=True)
        == EXPECTED_PHYSICAL_POPULATION,
        "physical evidence population changed",
    )
    for relative, expected in PRIMARY_BINDINGS.items():
        verify_file(EVIDENCE_ROOT / relative, expected)
    for cell_id, expected in TERMINAL_BINDINGS.items():
        verify_file(_terminal_path(cell_id), expected)
    for cell_id, expected in TRACE_BINDINGS.items():
        verify_file(_trace_path(cell_id), expected)

    freeze = load_json(EVIDENCE_ROOT / "physical-freeze.json")
    authorization = load_json(EVIDENCE_ROOT / "attempt-authorization.json")
    preflight = load_json(EVIDENCE_ROOT / "authorization-preflight.json")
    terminal_paths = load_json(EVIDENCE_ROOT / "terminal-paths.json")
    evaluation = load_json(EVIDENCE_ROOT / "complete-evaluation.json")
    report = load_json(EVIDENCE_ROOT / "report.json")
    completion = load_json(EVIDENCE_ROOT / "completion.json")
    require(
        freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("question_class") == "finite_decision"
        and freeze.get("source_commit") == SOURCE_COMMIT
        and freeze.get("source_tree_git_oid") == SOURCE_TREE
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_cell_ids") == CELL_IDS
        and len(freeze.get("implementation_dependency_digests", {})) == 222
        and len(freeze.get("source_bindings", [])) == 222
        and freeze.get("complete_zero_world_gate_passed") is True
        and freeze.get("clean_pushed_zero_world_qualification_adopted") is True
        and freeze.get("physical_execution_authorized") is True
        and freeze.get("physical_acceptance_authority") is False,
        "physical freeze changed",
    )
    require(
        authorization.get("campaign_id") == CAMPAIGN_ID
        and authorization.get("attempt_id") == ATTEMPT_ID
        and Path(authorization.get("attempt_root", "")).resolve()
        == EVIDENCE_ROOT.resolve()
        and authorization.get("ordered_cell_ids") == CELL_IDS
        and authorization.get("one_shot_attempt_unconsumed") is True
        and authorization.get("replacement_or_selective_rerun_permitted") is not True
        and authorization.get("physical_execution_authorized") is True,
        "attempt authorization changed",
    )
    require(
        preflight.get("receipt_count") == 9
        and preflight.get("pass_count") == 9
        and preflight.get("complete_matrix_passed") is True
        and preflight.get("model_construction_count") == 0
        and preflight.get("world_attempt_count") == 0
        and preflight.get("world_build_count") == 0,
        "authorization preflight changed",
    )
    require(
        isinstance(terminal_paths, list)
        and len(terminal_paths) == 9
        and [Path(path).parent.name for path in terminal_paths]
        == [TERMINAL_BINDINGS[cell_id][1] for cell_id in CELL_IDS]
        and all(Path(path).is_file() for path in terminal_paths),
        "terminal manifest changed",
    )

    expected_failures = {
        **{
            f"r23d71__godot_jolt__s23191__{arm}": [TRACE_FAILURE]
            for arm in ARMS
        },
        **{
            f"r23d71__rapier_parry__s23191__{arm}": [
                RAPIER_FORWARD_FAILURE,
                TRACE_FAILURE,
            ]
            for arm in ARMS
        },
        **{
            f"r23d71__mujoco__s23191__{arm}": [MUJOCO_TRANSPORT_FAILURE]
            for arm in ARMS
        },
    }
    cell_evaluations = evaluation.get("cell_evaluations")
    require(
        isinstance(cell_evaluations, list)
        and len(cell_evaluations) == 9
        and [item.get("cell_id") for item in cell_evaluations] == CELL_IDS,
        "complete evaluator cell population changed",
    )
    for item in cell_evaluations:
        cell_id = item.get("cell_id")
        require(
            item.get("world_attempt_count") == 1
            and item.get("world_build_count") == 1
            and item.get("execution_valid") is False
            and item.get("common_physical_gate_passed") is False
            and item.get("failed_gate_ids") == expected_failures[cell_id],
            f"frozen evaluator outcome changed: {cell_id}",
        )
    require(
        evaluation.get("classification") == CLASSIFICATION
        and evaluation.get("fresh_held_out_seed_consumed") is True
        and evaluation.get("turning_gate_invoked") is True
        and evaluation.get("all_declared_cells_executed_or_retained_as_failures") is True
        and evaluation.get("all_cells_run_regardless_of_intermediate_outcome") is True
        and evaluation.get("finite_decision", {}).get("matrix_execution_valid") is False
        and evaluation.get("finite_decision", {}).get("finite_three_engine_turning_positive")
        is False
        and false_claims(evaluation.get("claims")),
        "complete evaluation changed",
    )
    require(
        report.get("result_classification") == CLASSIFICATION
        and len(report.get("ordered_cells", [])) == 9
        and report.get("world_build_count_exact") is True
        and report.get("world_build_count_lower_bound") == 9
        and report.get("world_build_count_upper_bound") == 9,
        "campaign report changed",
    )
    require(
        completion.get("campaign_id") == CAMPAIGN_ID
        and completion.get("attempt_id") == ATTEMPT_ID
        and completion.get("status") == CLASSIFICATION
        and completion.get("source_commit") == SOURCE_COMMIT
        and completion.get("cell_count") == 9
        and completion.get("world_count") == 9
        and completion.get("world_count_exact") is True
        and completion.get("one_shot_attempt_consumed") is True
        and completion.get("replacement_or_selective_rerun_permitted") is False
        and completion.get("finite_three_engine_turning_positive") is False,
        "completion changed",
    )

    terminal_projection: list[dict[str, Any]] = []
    rapier_observations: list[dict[str, Any]] = []
    for cell_id in CELL_IDS:
        engine = cell_id.split("__")[1]
        arm = cell_id.rsplit("__", 1)[1]
        terminal = load_json(_terminal_path(cell_id))
        worker = _worker_report(terminal)
        execution = worker.get("execution", {})
        require(
            worker.get("schema_version")
            == "sporespore_qsdk_r23d71_engine_cell_report_v1"
            and worker.get("campaign_id") == CAMPAIGN_ID
            and worker.get("gate_id") == GATE_ID
            and worker.get("cell_id") == cell_id
            and worker.get("source_commit") == SOURCE_COMMIT
            and execution.get("world_attempt_count") == 1
            and execution.get("world_build_count") == 1
            and execution.get("controller_semantic_step_count") == 2992
            and worker.get("trace_summary", {}).get("row_count") == 2992
            and false_claims(worker.get("claims")),
            f"worker report changed: {cell_id}",
        )
        if engine == "mujoco":
            require(
                terminal.get("schema_version")
                == "sporespore_qsdk_r23d71_worker_failure_v1"
                and terminal.get("failure_stage") == "supervisor_transport"
                and terminal.get("failure_code") == MUJOCO_TRANSPORT_FAILURE
                and terminal.get("world_attempt_count") == 1
                and terminal.get("world_build_count") == 1
                and terminal.get("observed_worker_terminal_preserved") is True
                and "question_class" not in worker,
                f"MuJoCo transport failure changed: {cell_id}",
            )
        else:
            require(
                terminal.get("schema_version")
                == "sporespore_qsdk_r23d71_engine_cell_report_v1"
                and terminal.get("question_class") == "finite_decision",
                f"success terminal identity changed: {cell_id}",
            )

        artifact = worker.get("trace_artifact", {})
        summary = worker.get("trace_summary", {})
        trace_path = _trace_path(cell_id)
        expected_trace = TRACE_BINDINGS[cell_id]
        require(
            artifact.get("sha256") == f"sha256:{expected_trace[1]}"
            and artifact.get("byte_length") == expected_trace[0]
            and summary.get("raw_sha256") == artifact.get("sha256")
            and summary.get("byte_length") == artifact.get("byte_length")
            and trace_path.read_bytes().endswith(b"\n")
            and trace_path.read_bytes().count(b"\n") == 2992,
            f"trace identity changed: {cell_id}",
        )
        required_transport_fields = {
            "trace_transport_id",
            "trace_transport_engine_id",
            "canonical_ndjson",
            "full_precision",
        }
        missing = sorted(required_transport_fields - set(artifact))
        require(missing, f"trace artifact unexpectedly satisfies frozen evaluator: {cell_id}")
        terminal_projection.append(
            {
                "cell_id": cell_id,
                "engine_id": engine,
                "arm_id": arm,
                "terminal_entry_kind": (
                    "supervisor_transport_failure_with_preserved_worker_report"
                    if engine == "mujoco"
                    else "worker_report"
                ),
                "complete_native_horizon_observed": True,
                "retained_trace": binding(trace_path),
                "trace_artifact_missing_evaluator_transport_fields": missing,
                "question_class_present": "question_class" in worker,
                "execution_valid_under_frozen_evaluator": False,
                "measurements_preserved_without_reinterpretation": True,
            }
        )
        if engine == "rapier_parry":
            measurements = worker.get("measurements", {})
            displacement = measurements.get("final_forward_displacement_m")
            require(
                isinstance(displacement, (int, float))
                and displacement < MINIMUM_FORWARD_DISPLACEMENT_M,
                f"Rapier forward observation changed: {cell_id}",
            )
            rapier_observations.append(
                {
                    "cell_id": cell_id,
                    "arm_id": arm,
                    "final_forward_displacement_m": displacement,
                    "frozen_minimum_final_forward_displacement_m": (
                        MINIMUM_FORWARD_DISPLACEMENT_M
                    ),
                    "frozen_failed_gate_id": RAPIER_FORWARD_FAILURE,
                    "independent_of_trace_receipt_failure": True,
                }
            )

    return {
        "schema_version": "sporespore_qsdk_r23d71_physical_closure_v1",
        "status": CLOSED_STATUS,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "question_class": "finite_decision",
        "maintenance_question_class": "development_diagnosis",
        "source_commit": SOURCE_COMMIT,
        "source_tree_git_oid": SOURCE_TREE,
        "source_blob_bindings": SOURCE_BLOBS,
        "qualifications": qualifications,
        "attempt": {
            "attempt_root": EVIDENCE_ROOT.resolve().as_posix(),
            "attempt_id": ATTEMPT_ID,
            "primary_evidence": {
                relative: binding(EVIDENCE_ROOT / relative)
                for relative in PRIMARY_BINDINGS
            },
            "population_identity": EXPECTED_PHYSICAL_POPULATION,
            "authorization_receipt_count": 9,
            "authorization_pass_count": 9,
            "declared_cell_count": 9,
            "world_attempt_count": 9,
            "world_build_count": 9,
            "complete_native_horizon_count": 9,
            "retained_trace_count": 9,
            "retained_trace_row_count": 2992 * 9,
            "worker_report_count": 9,
            "supervisor_success_terminal_count": 6,
            "supervisor_failure_terminal_count": 3,
            "execution_valid_cell_count": 0,
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
        },
        "observed_cells": terminal_projection,
        "integration_findings": {
            "trace_artifact_transport_contract": {
                "frozen_evaluator_failure_code": TRACE_FAILURE,
                "directly_evaluated_failure_cell_count": 6,
                "latent_preserved_mujoco_worker_report_count": 3,
                "complete_worker_report_population_affected": 9,
                "trace_bytes_missing": False,
                "trace_row_count_per_cell": 2992,
                "physics_failure": False,
                "threshold_or_selector_failure": False,
            },
            "mujoco_success_terminal_identity": {
                "failure_code": MUJOCO_TRANSPORT_FAILURE,
                "affected_cell_count": 3,
                "missing_field": "question_class",
                "observed_worker_reports_preserved": True,
                "complete_native_horizons_observed": 3,
                "physics_failure": False,
            },
        },
        "rapier_physical_observations": {
            "frozen_gate_failure_cell_count": 3,
            "frozen_gate_id": RAPIER_FORWARD_FAILURE,
            "frozen_minimum_final_forward_displacement_m": (
                MINIMUM_FORWARD_DISPLACEMENT_M
            ),
            "ordered_observations": rapier_observations,
            "physical_gate_failure_observed": True,
            "campaign_level_valid_negative_available": False,
            "threshold_changed": False,
            "interpretation_changed": False,
        },
        "official_result": {
            "classification": CLASSIFICATION,
            "matrix_execution_valid": False,
            "finite_three_engine_turning_positive": False,
            "turning_gate_invoked": True,
            "valid_turning_result_available": False,
            "cross_engine_equivalence_test_invoked": False,
            "historical_result_reinterpreted": False,
            "threshold_selector_evaluator_result_or_interpretation_change_count": 0,
            "closure_physical_world_count": 0,
            "release_score_before": "10/25",
            "release_score_after": "10/25",
        },
        "claims": {
            "campaign_closed": True,
            "retained_attempt_evidence_complete": True,
            "campaign_identity_consumed": True,
            "complete_nine_cell_population_observed": True,
            "nine_complete_native_horizons_observed": True,
            "nine_complete_traces_retained": True,
            "historical_result_reinterpreted": False,
            "finite_three_engine_turning": False,
            "portable_basic_turning": False,
            "q_sdk_r23_satisfied": False,
            "cross_engine_equivalence": False,
            "prone_to_standing": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        },
    }


def walk_dicts(value: Any) -> Iterable[dict[str, Any]]:
    if isinstance(value, dict):
        yield value
        for child in value.values():
            yield from walk_dicts(child)
    elif isinstance(value, list):
        for child in value:
            yield from walk_dicts(child)


def verify_live_authorities(closure_sha: str, audit_sha: str) -> None:
    for path in (RELEASE_PATH, SUPPORT_PATH):
        value = load_json(path)
        matches = [
            item
            for item in walk_dicts(value)
            if item.get("campaign_id") == CAMPAIGN_ID and item.get("gate_id") == GATE_ID
        ]
        require(len(matches) == 1, f"R71 authority population changed: {path}")
        item = matches[0]
        lifecycle = item.get("current_lifecycle", {})
        require(
            item.get("status") == CLOSED_STATUS
            and item.get("current_lifecycle_status") == CLOSED_STATUS
            and item.get("qualification_passed") is True
            and item.get("campaign_attestation_adopted") is True
            and item.get("physical_execution_authorized") is True
            and item.get("physical_campaign_opened") is True
            and item.get("fresh_seed_occurrence_count") == 1
            and item.get("world_attempt_count") == 9
            and item.get("world_build_count") == 9
            and item.get("finite_three_engine_turning") is False
            and item.get("q_sdk_r23_satisfied") is False
            and item.get("physical_acceptance_authority") is False
            and item.get("release_authorized") is False
            and lifecycle.get("closure_path") == CLOSURE_RELATIVE
            and lifecycle.get("closure_raw_sha256") == f"sha256:{closure_sha}"
            and lifecycle.get("closure_audit_path") == AUDIT_RELATIVE
            and lifecycle.get("closure_audit_raw_sha256") == f"sha256:{audit_sha}"
            and lifecycle.get("attempt_id") == ATTEMPT_ID
            and lifecycle.get("complete_native_horizon_count") == 9
            and lifecycle.get("retained_trace_count") == 9
            and lifecycle.get("execution_valid_cell_count") == 0,
            f"R71 live lifecycle projection changed: {path}",
        )
    for path in (
        REPO_ROOT / "docs" / "README.md",
        REPO_ROOT / "docs" / "ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        REPO_ROOT / "docs" / "SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        REPO_ROOT / "docs" / "LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
        REPO_ROOT / "docs" / "LOCOMOTION_ARCHITECTURE.md",
    ):
        text = path.read_text(encoding="utf-8")
        require(
            "R23D71" in text
            and "question_class" in text
            and "R23D65_TRACE_ARTIFACT_IDENTITY" in text
            and "R23D34_FORWARD_DISPLACEMENT" in text
            and "10/25" in text,
            f"R71 live documentation projection changed: {path}",
        )


def materialize() -> None:
    closure = build_closure()
    CLOSURE_PATH.write_text(canonical_json(closure), encoding="utf-8")
    print(
        "[turning/3e] MATERIALIZED R23D71 immutable physical closure: "
        "qualification=16/16 adoption=True authorization=9/9 worlds=9 "
        "horizons=9 traces=9 evaluator_valid=0 turning=False "
        "QSDK-R23=False score=10/25"
    )


def audit() -> None:
    expected = build_closure()
    require(CLOSURE_PATH.is_file(), "R23D71 closure is missing")
    actual = load_json(CLOSURE_PATH)
    require(actual == expected, "R23D71 closure claim vector changed")
    verify_live_authorities(sha256(CLOSURE_PATH), sha256(AUDIT_PATH))
    mutations = [
        ("status", "passing"),
        ("attempt.same_identity_rerun_allowed", True),
        ("attempt.world_build_count", 8),
        ("integration_findings.mujoco_success_terminal_identity.physics_failure", True),
        ("rapier_physical_observations.threshold_changed", True),
        ("claims.finite_three_engine_turning", True),
    ]
    for dotted, replacement in mutations:
        changed = json.loads(json.dumps(actual))
        target = changed
        parts = dotted.split(".")
        for part in parts[:-1]:
            target = target[part]
        target[parts[-1]] = replacement
        require(changed != expected, f"mutation was accepted: {dotted}")
    print(
        "[turning/3e] PASS R23D71 immutable physical closure: "
        "qualification=16/16 adoption=True authorization=9/9 worlds=9 "
        "horizons=9 traces=9 evaluator_valid=0 mutations=6 turning=False "
        "QSDK-R23=False score=10/25"
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--audit", action="store_true")
    arguments = parser.parse_args()
    if arguments.audit:
        audit()
    else:
        materialize()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
