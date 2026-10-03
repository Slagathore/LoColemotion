#!/usr/bin/env python3
"""Materialize and audit the immutable R23D74 physical closure.

R23D74 consumed its single authorized nine-cell finite decision.  All nine
native worlds completed their 2,992-step horizons.  Godot/Jolt and
Rapier/Parry retained six success terminals and six CAS traces.  MuJoCo
retained three complete raw traces but failed while publishing them because
the inherited evaluator rebound the old support-loss-conditioned startup
semantics over the newly produced unconditional-ramp rows.

This closure binds the exact retained populations and pinned source.  It does
not rerun a world, re-evaluate turning, alter a threshold, or repair the
consumed campaign in place.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
from typing import Any, Iterable, Iterator, Mapping


REPO_ROOT = Path(__file__).resolve().parents[2]
STATE_ROOT = REPO_ROOT.parent / "SporeSpore_Evidence"
ARTIFACT_ROOT = STATE_ROOT / "artifacts" / "sha256"
PHYSICAL_ROOT = (
    STATE_ROOT
    / "qsdk-r23d74-physical-20260826T113149Z-32b9db7f-lca1-system-python"
)
QUALIFICATION_ROOTS = {
    "nested_lock_negative": (
        STATE_ROOT
        / "qsdk-r23d74-qualification-20260826T104208Z-1dc534e0-lca1-python"
    ),
    "inventory_negative": (
        STATE_ROOT
        / "qsdk-r23d74-qualification-20260826T110747Z-fb8cbb9d-lca1-python"
    ),
    "passing_nonadoptable_runtime": (
        STATE_ROOT
        / "qsdk-r23d74-qualification-20260826T111132Z-32b9db7f-lca1-python"
    ),
    "passing_adopted_runtime": (
        STATE_ROOT
        / "qsdk-r23d74-qualification-20260826T112343Z-32b9db7f-lca1-system-python"
    ),
}
CLOSURE_PATH = (
    REPO_ROOT
    / "sdk"
    / "turning"
    / "r23d74_production_route_three_engine_turning_validation_closure_v1.json"
)
AUDIT_PATH = REPO_ROOT / "tests" / "test_qsdk_r23d74_physical_closure.ps1"
RELEASE_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_release_contract.json"
SUPPORT_PATH = REPO_ROOT / "sdk" / "release" / "quadruped_support_matrix.json"

SOURCE_COMMIT = "32b9db7f67c15f72181a5e5ac8a412e5f7a51a57"
SOURCE_TREE = "939d356e6ca8e94361f8d4ff8cafaee75865f07d"
CAMPAIGN_ID = "QSDK-R23D74-FRESH-FINITE-THREE-ENGINE-TURNING-DECISION"
GATE_ID = "QSDK-R23D74"
ATTEMPT_ID = "9dbe54d9cc8241b0bf40da3b4b28b541"
CLOSED_STATUS = (
    "closed_consumed_invalid_or_incomplete_first_attempt_"
    "mujoco_startup_trace_evaluator_binding_mismatch"
)
CLASSIFICATION = (
    "invalid_or_incomplete_exact_seed_23193_three_engine_portable_turning"
)
CLOSURE_RELATIVE = (
    "sdk/turning/"
    "r23d74_production_route_three_engine_turning_validation_closure_v1.json"
)
MATERIALIZER_RELATIVE = "sdk/turning/materialize_r23d74_physical_closure.py"
AUDIT_RELATIVE = "tests/test_qsdk_r23d74_physical_closure.ps1"
ACTUAL_STARTUP_ID = "canonical_velocity_smoothstep_one_gait_cycle_v1"
EVALUATOR_STARTUP_ID = "support_loss_latched_smoothstep_one_cycle_v1"
MUJOCO_FAILURE_FRAGMENT = (
    "QSDK_R23D74_MJC_WORKER_FAILURE:R23D3MujocoError:"
    "QSDK_R23D74_MJC_TRACE_RETENTION_FAILED:1:QSDK_R23D74_EVALUATOR_FAILURE "
    "R23D34EvaluationError:R23D34_TRACE_INVALID:"
)
COMPLETE_EVALUATOR_FAILURE = (
    "QSDK_R23D74_EVALUATOR_FAILURE R23D65EvaluationError:"
    "QSDK_R23D74_SUCCESS_TERMINAL_CONTRACT_INVALID:"
    "mujoco:reference_zero:TRACE_ARTIFACT,"
    "mujoco:positive_heading:TRACE_ARTIFACT,"
    "mujoco:negative_heading:TRACE_ARTIFACT"
)

ENGINES = ("godot_jolt", "rapier_parry", "mujoco")
ARMS = ("reference_zero", "positive_heading", "negative_heading")
CELL_IDS = [
    f"r23d74__{engine}__s23193__{arm}"
    for engine in ENGINES
    for arm in ARMS
]

SOURCE_BLOBS = {
    "sdk/run_qsdk_r23d74_supervisor.ps1": "fb4f40c2bfea538f5bc72252068145fc603be9ac",
    "tests/test_sdk_qsdk_r23d74_godot_jolt_worker.gd": (
        "9ca51c6667b0717c8f0c9c1c1b2e7246b4c1faf1"
    ),
    "sdk/adapters/rapier/src/qsdk_r23d74_turning_route.rs": (
        "5837a2ee310046b0d908931041271b077464c98d"
    ),
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d74_turning_route.py": (
        "92f8c9b95fd548c4fd3c93da0769de755b1b2417"
    ),
    "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py": (
        "d03242208ec6d3ee620e9cc12abeff84b3c7b777"
    ),
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py": (
        "ba5d48ce0a2673e258c4302035be3f5c8d2dbccd"
    ),
    "sdk/turning/r23d58_godot_cap_source_factorial_evaluator.py": (
        "049e72d49f403dc07fff09e5b1cb632710133138"
    ),
    "sdk/turning/r23d74_receipt_contract.py": (
        "53638dc5fcdc73019fa435c4508f3bc783d5fdcc"
    ),
    "sdk/turning/r23d74_production_route_runtime.py": (
        "f01a0777d1c68cba79d3db9e27b9a808266b7d40"
    ),
    "sdk/turning/r23d74_production_route_three_engine_turning_implementation_v1.json": (
        "c7ae61c5e0b59998ddf028d4ebfff7e3342938b9"
    ),
    "sdk/turning/r23d74_fresh_finite_three_engine_turning_decision_v1.json": (
        "969208b2c9252d960a002ce49c98d399af5e2c62"
    ),
    "sdk/turning/r23d74_campaign_attestation_manifest_v1.json": (
        "7f1e26c0363cabe5d7e4405535ca0ef3749ae634"
    ),
    "sdk/turning/r23d73_mujoco_selected_profile_positive_turn_development_closure_v1.json": (
        "4c52afc03bc285abc0ba4a2208ca233956f28222"
    ),
    "sdk/turning/r23d65_selected_profile_three_engine_turning_validation.py": (
        "16a2204e2798f366cf97105c2911d6eb47b14e41"
    ),
    "sdk/turning/r23d38_mujoco_startup_ramp_stabilization.py": (
        "b5c0cd4f37c47c0d48f6c9559ecaca7c4264f140"
    ),
    "sdk/turning/r23d45_support_loss_conditioned_startup.py": (
        "34757a55630bf43ce1ca006697863f44c45db388"
    ),
}

EXPECTED_POPULATIONS = {
    "nested_lock_negative": {
        "complete_file_population_count": 40,
        "complete_file_population_byte_count": 332457,
        "canonical_population_manifest_byte_length": 4731,
        "canonical_population_manifest_sha256": (
            "sha256:101567ff4e1d985ceec5fdecf9534088baf039905d868d7694e8c9623be6158e"
        ),
    },
    "inventory_negative": {
        "complete_file_population_count": 13,
        "complete_file_population_byte_count": 12756,
        "canonical_population_manifest_byte_length": 1482,
        "canonical_population_manifest_sha256": (
            "sha256:43f1975c8b57966b9aa8ba150bf858c3447a2149659b1cac9bce8c5fa1b8a2be"
        ),
    },
    "passing_nonadoptable_runtime": {
        "complete_file_population_count": 49,
        "complete_file_population_byte_count": 498720,
        "canonical_population_manifest_byte_length": 5751,
        "canonical_population_manifest_sha256": (
            "sha256:f192424eb9a400a4bd8faeea34568b03ae27030f9523165b1115e5d3e9bbd548"
        ),
    },
    "passing_adopted_runtime": {
        "complete_file_population_count": 50,
        "complete_file_population_byte_count": 502494,
        "canonical_population_manifest_byte_length": 5842,
        "canonical_population_manifest_sha256": (
            "sha256:4514cff8962f75092b6793571c0631f7de96bfda93fc09879276e5bcb75c0e95"
        ),
    },
    "physical": {
        "complete_file_population_count": 67,
        "complete_file_population_byte_count": 575683495,
        "retained_unique_digest_count": 49,
        "cas_backed_file_count": 58,
        "non_cas_file_count": 9,
        "non_cas_relative_paths": [
            "pending-traces/fresh_finite_three_engine_turning_decision__r23d74__mujoco__s23193__negative_heading.rows.json",
            "pending-traces/fresh_finite_three_engine_turning_decision__r23d74__mujoco__s23193__positive_heading.rows.json",
            "pending-traces/fresh_finite_three_engine_turning_decision__r23d74__mujoco__s23193__reference_zero.rows.json",
            "pending-traces/fresh_finite_three_engine_turning_decision__r23d74__rapier_parry__s23193__negative_heading.rows.json",
            "pending-traces/fresh_finite_three_engine_turning_decision__r23d74__rapier_parry__s23193__positive_heading.rows.json",
            "pending-traces/fresh_finite_three_engine_turning_decision__r23d74__rapier_parry__s23193__reference_zero.rows.json",
            "pending-traces/r23d74__godot_jolt__s23193__negative_heading.rows.json",
            "pending-traces/r23d74__godot_jolt__s23193__positive_heading.rows.json",
            "pending-traces/r23d74__godot_jolt__s23193__reference_zero.rows.json",
        ],
        "canonical_population_manifest_byte_length": 9681,
        "canonical_population_manifest_sha256": (
            "sha256:b2f86f47e922e20598c48d5317b2fef56425387f7b0c88ff954775b393f18821"
        ),
    },
}

EXPECTED_QUALIFICATION_BINDINGS = {
    "nested_lock_negative": {
        "failure.json": (616, "6cd8b59f00db5078e0b2d4e89f44464013baa161536ed4934a44119cf8a86049"),
    },
    "inventory_negative": {
        "failure.json": (614, "44683a21adcb14fda5c304a5d3464cfd93899b142f1daef41e8751ea14f3520e"),
    },
    "passing_nonadoptable_runtime": {
        "attestation.json": (156359, "d11a19deb2789590027329fb19207d97632c26f610fb0120c5d034a2e61416d3"),
    },
    "passing_adopted_runtime": {
        "attestation.json": (156633, "a73062c1d5eebbbfa4af83d928b188a0a3f1ce748869f86010601ce6b65e7325"),
        "adoption.json": (3283, "3122fc1bf611ea3da524dd117e2a7fd0752c133749057dbf4aaf1472fdf307a3"),
    },
}

EXPECTED_OBSERVATIONS = {
    "r23d74__godot_jolt__s23193__reference_zero": (
        -0.13947192615840276,
        1.0847830772399902,
    ),
    "r23d74__godot_jolt__s23193__positive_heading": (
        0.31371096838137635,
        1.1414549350738525,
    ),
    "r23d74__godot_jolt__s23193__negative_heading": (
        -0.26442951992109176,
        1.070874810218811,
    ),
    "r23d74__rapier_parry__s23193__reference_zero": (
        0.0050301311246485625,
        1.5137791633605957,
    ),
    "r23d74__rapier_parry__s23193__positive_heading": (
        0.021690360183334256,
        1.4997891187667847,
    ),
    "r23d74__rapier_parry__s23193__negative_heading": (
        0.00010139506438067158,
        1.4947550296783447,
    ),
}


class ClosureError(RuntimeError):
    """Fail-closed R23D74 closure error."""


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
    files = sorted(
        (path for path in root.rglob("*") if path.is_file()),
        key=lambda path: path.relative_to(root).as_posix(),
    )
    lines: list[str] = []
    digests: set[str] = set()
    non_cas: list[str] = []
    verified_cas: set[str] = set()
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
            valid = payload.is_file() and payload.stat().st_size == size
            if valid and raw not in verified_cas:
                valid = sha256(payload) == raw
                if valid:
                    verified_cas.add(raw)
            if not valid:
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

    route = source_text(
        "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d74_turning_route.py"
    )
    runtime = source_text("sdk/turning/r23d74_production_route_runtime.py")
    base = source_text(
        "sdk/turning/r23d65_selected_profile_three_engine_turning_validation.py"
    )
    inherited = source_text(
        "sdk/turning/r23d65_selected_profile_three_engine_turning_validation_evaluator.py"
    )
    evaluator = source_text(
        "sdk/turning/r23d74_production_route_three_engine_turning_evaluator.py"
    )
    support_loss = source_text(
        "sdk/turning/r23d45_support_loss_conditioned_startup.py"
    )
    require(
        "scale = ramp_design.startup_velocity_scale(semantic_step)" in route
        and '"startup_transform_id": design.MUJOCO_STARTUP_RAMP_ID' in route
        and '"startup_policy": "unconditional_one_cycle"' in route
        and f'MUJOCO_STARTUP_RAMP_ID = "{ACTUAL_STARTUP_ID}"' in runtime,
        "pinned MuJoCo producer startup binding changed",
    )
    require(
        "STARTUP_TRANSFORM_ID = base.STARTUP_TRANSFORM_ID" in runtime
        and f'STARTUP_TRANSFORM_ID = "{EVALUATOR_STARTUP_ID}"' in base
        and (
            "design.SupportLossConditionedStartup = "
            "r60_design.SupportLossConditionedStartup"
        ) in inherited
        and "design.STARTUP_RAMP_ID = design.STARTUP_TRANSFORM_ID" in inherited
        and "receipt = inherited.retain_trace(**kwargs)" in evaluator
        and "_configure_inherited_evaluator()" in evaluator,
        "pinned evaluator startup binding changed",
    )
    require(
        "if self.trigger_step is None:" in support_loss
        and "scale = 1.0" in support_loss
        and '"startup_ramp_active": self.trigger_step is not None and scale < 1.0' in support_loss,
        "support-loss expected-row semantics changed",
    )


def verify_qualifications() -> dict[str, Any]:
    for name, root in QUALIFICATION_ROOTS.items():
        require(root.is_dir(), f"qualification root missing: {name}")
        require(
            population_identity(root, cas_check=False) == EXPECTED_POPULATIONS[name],
            f"qualification population changed: {name}",
        )
        for relative, expected in EXPECTED_QUALIFICATION_BINDINGS[name].items():
            verify_file(root / relative, expected)

    first = load_json(QUALIFICATION_ROOTS["nested_lock_negative"] / "failure.json")
    second = load_json(QUALIFICATION_ROOTS["inventory_negative"] / "failure.json")
    venv = load_json(
        QUALIFICATION_ROOTS["passing_nonadoptable_runtime"] / "attestation.json"
    )
    adopted = load_json(
        QUALIFICATION_ROOTS["passing_adopted_runtime"] / "attestation.json"
    )
    adoption = load_json(
        QUALIFICATION_ROOTS["passing_adopted_runtime"] / "adoption.json"
    )
    require(
        first.get("campaign_id") == CAMPAIGN_ID
        and first.get("source_commit") == "1dc534e0c6189932585d1ab8a2741dd013932042"
        and "R23D74-COMPLETE-ZERO-WORLD exit=1" in first.get("message", "")
        and first.get("campaign_local_qualification_passed") is False
        and first.get("physical_launch_prerequisite_satisfied") is False,
        "nested-lock qualification negative changed",
    )
    require(
        second.get("campaign_id") == CAMPAIGN_ID
        and second.get("source_commit") == "fb8cbb9df2c2fe3e7714e40888a967a0379f41ff"
        and "CAK1-EVIDENCE-PROVENANCE exit=1" in second.get("message", "")
        and second.get("campaign_local_qualification_passed") is False
        and second.get("physical_launch_prerequisite_satisfied") is False,
        "inventory qualification negative changed",
    )
    for value, executable, executable_sha in (
        (
            venv,
            str(REPO_ROOT / "sdk" / "adapters" / "mujoco" / ".venv" / "Scripts" / "python.exe"),
            "sha256:21bb438c0d4a6f1f164b9a646f6ee000340185e5871180aec06db8d3f07c0082",
        ),
        (
            adopted,
            r"C:\Program Files\Python311\python.exe",
            "sha256:5f7b89a612c9b8af1d6456cdfcd1dbe5ca630849e79aebced9bee9a6694952ec",
        ),
    ):
        require(
            value.get("campaign_id") == CAMPAIGN_ID
            and value.get("source", {}).get("commit") == SOURCE_COMMIT
            and value.get("executed_gate_count") == 16
            and value.get("all_gates_executed") is True
            and value.get("runtime", {}).get("python", {}).get("executable_path")
            == executable
            and value.get("runtime", {}).get("python", {}).get("executable_sha256")
            == executable_sha
            and value.get("claims", {}).get("turning_acceptance") is False,
            f"passing qualification changed: {executable}",
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
        "nested_operation_lock_negative": {
            "root": QUALIFICATION_ROOTS["nested_lock_negative"].resolve().as_posix(),
            "population_identity": EXPECTED_POPULATIONS["nested_lock_negative"],
            "failure": binding(
                QUALIFICATION_ROOTS["nested_lock_negative"] / "failure.json"
            ),
            "passed_gate_count": 12,
            "failed_gate_id": "R23D74-COMPLETE-ZERO-WORLD",
            "physical_world_count": 0,
            "reusable": False,
        },
        "closure_inventory_negative": {
            "root": QUALIFICATION_ROOTS["inventory_negative"].resolve().as_posix(),
            "population_identity": EXPECTED_POPULATIONS["inventory_negative"],
            "failure": binding(
                QUALIFICATION_ROOTS["inventory_negative"] / "failure.json"
            ),
            "passed_gate_count": 3,
            "failed_gate_id": "CAK1-EVIDENCE-PROVENANCE",
            "physical_world_count": 0,
            "reusable": False,
        },
        "passing_nonadoptable_runtime": {
            "root": QUALIFICATION_ROOTS[
                "passing_nonadoptable_runtime"
            ].resolve().as_posix(),
            "population_identity": EXPECTED_POPULATIONS[
                "passing_nonadoptable_runtime"
            ],
            "attestation": binding(
                QUALIFICATION_ROOTS["passing_nonadoptable_runtime"]
                / "attestation.json"
            ),
            "gate_pass_count": 16,
            "adoption_attempt_refused_for_runtime_identity_mismatch": True,
            "physical_world_count": 0,
            "reusable_for_physical_launch": False,
        },
        "passing_adopted_runtime": {
            "root": QUALIFICATION_ROOTS["passing_adopted_runtime"].resolve().as_posix(),
            "population_identity": EXPECTED_POPULATIONS["passing_adopted_runtime"],
            "attestation": binding(
                QUALIFICATION_ROOTS["passing_adopted_runtime"] / "attestation.json"
            ),
            "adoption": binding(
                QUALIFICATION_ROOTS["passing_adopted_runtime"] / "adoption.json"
            ),
            "gate_pass_count": 16,
            "adopted_for_physical_launch": True,
            "physical_launch_prerequisite_satisfied": True,
            "turning_acceptance": False,
            "physical_acceptance_authority": False,
        },
    }


def terminal_path(cell_id: str) -> Path:
    return PHYSICAL_ROOT / "cells" / cell_id / "terminal.json"


def pending_trace_path(cell_id: str) -> Path:
    engine = cell_id.split("__")[1]
    prefix = "" if engine == "godot_jolt" else "fresh_finite_three_engine_turning_decision__"
    return PHYSICAL_ROOT / "pending-traces" / f"{prefix}{cell_id}.rows.json"


def iter_json_array(path: Path) -> Iterator[Any]:
    text = path.read_text(encoding="utf-8")
    decoder = json.JSONDecoder()
    index = 0
    while index < len(text) and text[index].isspace():
        index += 1
    require(index < len(text) and text[index] == "[", f"not a JSON array: {path}")
    index += 1
    while True:
        while index < len(text) and text[index].isspace():
            index += 1
        require(index < len(text), f"unterminated JSON array: {path}")
        if text[index] == "]":
            index += 1
            break
        value, index = decoder.raw_decode(text, index)
        yield value
        while index < len(text) and text[index].isspace():
            index += 1
        require(index < len(text), f"unterminated JSON array item: {path}")
        if text[index] == ",":
            index += 1
            continue
        require(text[index] == "]", f"invalid JSON array separator: {path}")
        index += 1
        break
    require(text[index:].strip() == "", f"trailing JSON content: {path}")


def verify_mujoco_trace(cell_id: str) -> dict[str, Any]:
    path = pending_trace_path(cell_id)
    active_count = 0
    zero_count = 0
    unity_count = 0
    samples: dict[str, dict[str, Any]] = {}
    count = 0
    for index, row in enumerate(iter_json_array(path)):
        require(isinstance(row, Mapping), f"MuJoCo row is not an object: {cell_id}:{index}")
        require(
            row.get("schema_version") == "sporespore_qsdk_r23d74_turning_trace_row_v1"
            and row.get("cell_id") == cell_id
            and row.get("campaign_seed") == 23193
            and row.get("semantic_step") == index
            and row.get("startup_ramp_id") == ACTUAL_STARTUP_ID
            and row.get("startup_transform_id") == ACTUAL_STARTUP_ID
            and row.get("startup_policy") == "unconditional_one_cycle",
            f"MuJoCo row identity changed: {cell_id}:{index}",
        )
        scale = row.get("startup_velocity_scale")
        require(type(scale) is float, f"MuJoCo startup scale changed: {cell_id}:{index}")
        active_count += int(row.get("startup_ramp_active") is True)
        zero_count += int(scale == 0.0)
        unity_count += int(scale == 1.0)
        if index in (0, 1, 359, 360, 2991):
            samples[str(index)] = {
                "startup_velocity_scale": scale,
                "startup_ramp_active": row.get("startup_ramp_active"),
                "observed_support_count": row.get("observed_support_count"),
            }
        count += 1
    require(
        count == 2992
        and active_count == 359
        and zero_count == 1
        and unity_count == 2633
        and samples["0"]["startup_velocity_scale"] == 0.0
        and samples["0"]["startup_ramp_active"] is True
        and samples["359"]["startup_velocity_scale"] == 1.0
        and samples["360"]["startup_velocity_scale"] == 1.0
        and samples["2991"]["startup_ramp_active"] is False,
        f"MuJoCo complete-horizon startup observations changed: {cell_id}",
    )
    return {
        "retained_raw_trace": binding(path),
        "row_count": count,
        "semantic_step_minimum": 0,
        "semantic_step_maximum": 2991,
        "startup_ramp_id": ACTUAL_STARTUP_ID,
        "startup_policy": "unconditional_one_cycle",
        "startup_ramp_active_step_count": active_count,
        "startup_ramp_exact_zero_scale_step_count": zero_count,
        "startup_ramp_exact_unity_scale_step_count": unity_count,
        "sampled_rows": samples,
    }


def build_closure() -> dict[str, Any]:
    verify_source_identity()
    qualifications = verify_qualifications()
    require(PHYSICAL_ROOT.is_dir(), "physical evidence root is missing")
    require(
        population_identity(PHYSICAL_ROOT, cas_check=True)
        == EXPECTED_POPULATIONS["physical"],
        "physical evidence population changed",
    )

    freeze = load_json(PHYSICAL_ROOT / "physical-freeze.json")
    authorization = load_json(PHYSICAL_ROOT / "attempt-authorization.json")
    preflight = load_json(PHYSICAL_ROOT / "authorization-preflight.json")
    terminal_paths = load_json(PHYSICAL_ROOT / "terminal-paths.json")
    completion = load_json(PHYSICAL_ROOT / "completion.json")
    evaluator_stderr = (
        PHYSICAL_ROOT / "complete-evaluation-process" / "stderr.txt"
    ).read_text(encoding="utf-8").strip()

    require(
        freeze.get("campaign_id") == CAMPAIGN_ID
        and freeze.get("gate_id") == GATE_ID
        and freeze.get("question_class") == "finite_decision"
        and freeze.get("source_commit") == SOURCE_COMMIT
        and freeze.get("source_tree_git_oid") == SOURCE_TREE
        and freeze.get("declared_world_count") == 9
        and freeze.get("ordered_cell_ids") == CELL_IDS
        and len(freeze.get("implementation_dependency_digests", {})) == 229
        and len(freeze.get("source_bindings", [])) == 229
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
        == PHYSICAL_ROOT.resolve()
        and authorization.get("ordered_cell_ids") == CELL_IDS
        and authorization.get("one_shot_attempt_unconsumed") is True
        and authorization.get("physical_execution_authorized") is True,
        "attempt authorization changed",
    )
    require(
        preflight.get("receipt_count") == 9
        and preflight.get("pass_count") == 9
        and preflight.get("complete_matrix_passed") is True
        and [item.get("cell_id") for item in preflight.get("ordered_receipts", [])]
        == CELL_IDS
        and preflight.get("model_construction_count") == 0
        and preflight.get("world_attempt_count") == 0
        and preflight.get("world_build_count") == 0,
        "authorization preflight changed",
    )
    require(
        completion.get("campaign_id") == CAMPAIGN_ID
        and completion.get("attempt_id") == ATTEMPT_ID
        and completion.get("source_commit") == SOURCE_COMMIT
        and completion.get("status") == "invalid_or_incomplete_first_attempt"
        and completion.get("retained_cell_count") == 9
        and completion.get("one_shot_attempt_consumed") is True
        and completion.get("replacement_or_selective_rerun_permitted") is False
        and COMPLETE_EVALUATOR_FAILURE in completion.get("failure_message", "")
        and completion.get("physical_acceptance_authority") is False
        and evaluator_stderr == COMPLETE_EVALUATOR_FAILURE,
        "completion or complete-evaluator failure changed",
    )
    require(
        not (PHYSICAL_ROOT / "complete-evaluation.json").exists()
        and not (PHYSICAL_ROOT / "report.json").exists(),
        "campaign unexpectedly acquired a complete evaluator result",
    )
    require(
        isinstance(terminal_paths, list) and len(terminal_paths) == 9,
        "terminal path population changed",
    )

    observed_cells: list[dict[str, Any]] = []
    descriptive_observations: list[dict[str, Any]] = []
    mujoco_startup_observations: list[dict[str, Any]] = []
    for index, cell_id in enumerate(CELL_IDS):
        engine = cell_id.split("__")[1]
        arm = cell_id.rsplit("__", 1)[1]
        local_terminal_path = terminal_path(cell_id)
        terminal = load_json(local_terminal_path)
        retained_terminal_path = Path(terminal_paths[index])
        require(
            retained_terminal_path.is_file()
            and retained_terminal_path.parent.name == sha256(local_terminal_path)
            and retained_terminal_path.stat().st_size == local_terminal_path.stat().st_size
            and sha256(retained_terminal_path) == sha256(local_terminal_path),
            f"terminal CAS identity changed: {cell_id}",
        )
        require(
            terminal.get("campaign_id") == CAMPAIGN_ID
            and terminal.get("gate_id") == GATE_ID
            and terminal.get("question_class") == "finite_decision"
            and terminal.get("source_commit") == SOURCE_COMMIT
            and terminal.get("cell_id") == cell_id
            and terminal.get("engine_id") == engine
            and terminal.get("arm_id") == arm
            and false_claims(terminal.get("claims")),
            f"terminal identity changed: {cell_id}",
        )

        entry: dict[str, Any] = {
            "cell_id": cell_id,
            "engine_id": engine,
            "arm_id": arm,
            "terminal": binding(local_terminal_path),
            "terminal_cas_payload": binding(retained_terminal_path),
            "complete_native_horizon_observed": True,
            "official_finite_decision_cell_result_available": False,
        }
        if engine == "mujoco":
            require(
                terminal.get("schema_version")
                == "sporespore_qsdk_r23d74_worker_failure_v1"
                and terminal.get("failure_stage") == "settlement_complete"
                and terminal.get("failure_code", "").startswith(MUJOCO_FAILURE_FRAGMENT)
                and all(
                    f"R23D58_STARTUP_TRANSFORM_INVALID:{step}" in terminal.get("failure_code", "")
                    for step in range(8)
                )
                and terminal.get("model_construction_count") == 1
                and terminal.get("world_attempt_count") == 1
                and terminal.get("world_build_count") == 1
                and terminal.get("trace_artifact") is None,
                f"MuJoCo worker failure changed: {cell_id}",
            )
            trace_observation = verify_mujoco_trace(cell_id)
            mujoco_startup_observations.append(
                {"cell_id": cell_id, "arm_id": arm, **trace_observation}
            )
            entry.update(
                terminal_kind="worker_failure_during_trace_retention",
                model_construction_count=1,
                world_attempt_count=1,
                world_build_count=1,
                retained_trace=trace_observation["retained_raw_trace"],
                retained_trace_row_count=2992,
                trace_cas_publication_completed=False,
            )
        else:
            require(
                terminal.get("schema_version")
                == "sporespore_qsdk_r23d74_engine_cell_report_v1",
                f"success terminal schema changed: {cell_id}",
            )
            execution = terminal.get("execution", {})
            summary = terminal.get("trace_summary", {})
            artifact = terminal.get("trace_artifact", {})
            measurements = terminal.get("measurements", {})
            expected_yaw, expected_forward = EXPECTED_OBSERVATIONS[cell_id]
            trace_path = PHYSICAL_ROOT / "traces" / f"{cell_id}.ndjson"
            trace_payload = Path(artifact.get("payload_path", ""))
            with trace_path.open("rb") as stream:
                trace_row_count = sum(1 for _line in stream)
            require(
                execution.get("world_attempt_count") == 1
                and execution.get("world_build_count") == 1
                and execution.get("controller_semantic_step_count") == 2992
                and summary.get("row_count") == 2992
                and artifact.get("sha256") == f"sha256:{sha256(trace_path)}"
                and artifact.get("byte_length") == trace_path.stat().st_size
                and trace_payload.is_file()
                and trace_payload.stat().st_size == trace_path.stat().st_size
                and sha256(trace_payload) == sha256(trace_path)
                and trace_row_count == 2992
                and measurements.get("controller_semantic_step_count") == 2992
                and measurements.get("torso_ground_contact_step_count") == 0
                and measurements.get("controller_error_count") == 0
                and measurements.get("turn_phase_yaw_delta_rad") == expected_yaw
                and measurements.get("final_forward_displacement_m") == expected_forward,
                f"success terminal observation changed: {cell_id}",
            )
            observation = {
                "cell_id": cell_id,
                "engine_id": engine,
                "arm_id": arm,
                "turn_phase_yaw_delta_rad": expected_yaw,
                "final_forward_displacement_m": expected_forward,
                "torso_ground_contact_step_count": 0,
                "controller_semantic_step_count": 2992,
                "interpretation": "descriptive_only_campaign_invalid_or_incomplete",
                "official_turning_pass_or_fail_assigned": False,
            }
            descriptive_observations.append(observation)
            entry.update(
                terminal_kind="native_success_terminal",
                world_attempt_count=1,
                world_build_count=1,
                retained_trace=binding(trace_path),
                retained_trace_cas_payload=binding(trace_payload),
                retained_trace_row_count=trace_row_count,
                trace_cas_publication_completed=True,
            )
        observed_cells.append(entry)

    primary_names = (
        "physical-freeze.json",
        "attempt-authorization.json",
        "authorization-preflight.json",
        "terminal-paths.json",
        "completion.json",
        "complete-evaluation-process/stderr.txt",
    )
    return {
        "schema_version": "sporespore_qsdk_r23d74_physical_closure_v1",
        "status": CLOSED_STATUS,
        "campaign_id": CAMPAIGN_ID,
        "gate_id": GATE_ID,
        "release_gate_id": "QSDK-R23",
        "ledger_scope": {
            "subsystem": "turning",
            "engine_scope": "3e",
            "authority_mode": "official_physical_closure",
            "question_class": "finite_decision",
        },
        "physical_question_class": "finite_decision",
        "maintenance_question_class": "development_diagnosis",
        "source": {
            "commit": SOURCE_COMMIT,
            "tree_git_oid": SOURCE_TREE,
            "pinned_source_blob_oids": SOURCE_BLOBS,
        },
        "qualifications": qualifications,
        "attempt": {
            "root": PHYSICAL_ROOT.resolve().as_posix(),
            "attempt_id": ATTEMPT_ID,
            "completed_utc": completion["completed_utc"],
            "primary_evidence": {
                relative: binding(PHYSICAL_ROOT / relative)
                for relative in primary_names
            },
            "population_identity": EXPECTED_POPULATIONS["physical"],
            "authorization_receipt_count": 9,
            "authorization_pass_count": 9,
            "declared_cell_count": 9,
            "world_attempt_count": 9,
            "world_build_count": 9,
            "complete_native_horizon_count": 9,
            "retained_trace_count": 9,
            "retained_trace_row_count": 2992 * 9,
            "cas_trace_count": 6,
            "raw_pending_trace_count": 9,
            "supervisor_success_terminal_count": 6,
            "supervisor_failure_terminal_count": 3,
            "complete_evaluator_accepted_cell_count": 0,
            "campaign_identity_consumed": True,
            "same_identity_rerun_allowed": False,
            "replacement_or_selective_rerun_allowed": False,
        },
        "observed_cells": observed_cells,
        "mujoco_startup_trace_observations": mujoco_startup_observations,
        "godot_and_rapier_descriptive_observations": descriptive_observations,
        "integration_finding": {
            "finding_id": "r23d74_mujoco_startup_trace_evaluator_binding_mismatch_v1",
            "affected_engine": "mujoco",
            "affected_cell_count": 3,
            "producer_startup_transform_id": ACTUAL_STARTUP_ID,
            "producer_startup_policy": "unconditional_one_cycle",
            "evaluator_rebound_startup_transform_id": EVALUATOR_STARTUP_ID,
            "evaluator_rebound_startup_policy": "support_loss_conditioned",
            "step_zero_producer_scale": 0.0,
            "step_zero_producer_active": True,
            "step_zero_evaluator_expected_scale_under_full_support": 1.0,
            "step_zero_evaluator_expected_active_under_full_support": False,
            "worker_failure_code": "R23D58_STARTUP_TRANSFORM_INVALID",
            "complete_evaluator_failure": COMPLETE_EVALUATOR_FAILURE,
            "native_trace_conformance_covered_by_prior_synthetic_zero_world_rows": False,
            "deterministic_integration_invalidity": True,
            "physics_failure_established": False,
            "threshold_or_selector_failure_established": False,
            "turning_positive_or_valid_negative_established": False,
        },
        "official_result": {
            "classification": CLASSIFICATION,
            "complete_finite_evaluator_completed": False,
            "matrix_execution_valid": False,
            "finite_three_engine_turning_positive": False,
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
            "retained_physical_population_exact": True,
            "campaign_identity_consumed": True,
            "complete_nine_cell_native_population_observed": True,
            "nine_complete_native_horizons_observed": True,
            "nine_complete_raw_traces_retained": True,
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


def verify_live_authorities(closure_sha: str, materializer_sha: str, audit_sha: str) -> None:
    expected_pointer = (
        "r23d74_closed_consumed_invalid_or_incomplete_"
        "mujoco_startup_trace_evaluator_binding_mismatch"
    )
    for path in (RELEASE_PATH, SUPPORT_PATH):
        value = load_json(path)
        matches = [
            item
            for item in walk_dicts(value)
            if item.get("campaign_id") == CAMPAIGN_ID and item.get("gate_id") == GATE_ID
        ]
        require(len(matches) == 1, f"R23D74 authority population changed: {path}")
        item = matches[0]
        lifecycle = item.get("current_lifecycle", {})
        require(
            item.get("status") == CLOSED_STATUS
            and item.get("current_lifecycle_status") == CLOSED_STATUS
            and item.get("implementation_dependency_count") == 229
            and item.get("qualification_passed") is True
            and item.get("campaign_attestation_adopted") is True
            and item.get("physical_execution_authorized") is True
            and item.get("physical_campaign_opened") is True
            and item.get("world_attempt_count") == 9
            and item.get("world_build_count") == 9
            and item.get("finite_three_engine_turning") is False
            and item.get("q_sdk_r23_satisfied") is False
            and item.get("release_score_after") == "10/25"
            and item.get("physical_acceptance_authority") is False
            and item.get("release_authorized") is False
            and lifecycle.get("closure_path") == CLOSURE_RELATIVE
            and lifecycle.get("closure_raw_sha256") == f"sha256:{closure_sha}"
            and lifecycle.get("closure_materializer_path") == MATERIALIZER_RELATIVE
            and lifecycle.get("closure_materializer_raw_sha256")
            == f"sha256:{materializer_sha}"
            and lifecycle.get("closure_audit_path") == AUDIT_RELATIVE
            and lifecycle.get("closure_audit_raw_sha256") == f"sha256:{audit_sha}"
            and lifecycle.get("attempt_id") == ATTEMPT_ID
            and lifecycle.get("classification") == CLASSIFICATION
            and lifecycle.get("complete_native_horizon_count") == 9
            and lifecycle.get("retained_trace_count") == 9
            and lifecycle.get("supervisor_success_terminal_count") == 6
            and lifecycle.get("supervisor_failure_terminal_count") == 3
            and lifecycle.get("complete_evaluator_accepted_cell_count") == 0,
            f"R23D74 live lifecycle projection changed: {path}",
        )
        pointers = [
            child.get("current_prospective_successor_status")
            for child in walk_dicts(value)
            if isinstance(child.get("current_prospective_successor_status"), str)
            and child.get("current_prospective_successor_status", "").startswith("r23d74_")
        ]
        require(pointers == [expected_pointer], f"R23D74 current pointer changed: {path}")

    for path in (
        REPO_ROOT / "docs" / "README.md",
        REPO_ROOT / "docs" / "ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        REPO_ROOT / "docs" / "SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        REPO_ROOT / "docs" / "LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md",
        REPO_ROOT / "docs" / "LOCOMOTION_ARCHITECTURE.md",
    ):
        text = path.read_text(encoding="utf-8")
        require(
            "R23D74" in text
            and "finite decision" in text
            and "R23D58_STARTUP_TRANSFORM_INVALID" in text
            and ACTUAL_STARTUP_ID in text
            and EVALUATOR_STARTUP_ID in text
            and "10/25" in text,
            f"R23D74 live documentation projection changed: {path}",
        )


def materialize() -> None:
    closure = build_closure()
    CLOSURE_PATH.write_text(canonical_json(closure), encoding="utf-8")
    print(
        "[turning/3e] MATERIALIZED R23D74 immutable physical closure: "
        "qualification=16/16 adoption=True authorization=9/9 worlds=9 "
        "horizons=9 traces=9 success_terminals=6 failure_terminals=3 "
        "evaluator_valid=0 turning=False QSDK-R23=False score=10/25"
    )


def audit() -> None:
    expected = build_closure()
    require(CLOSURE_PATH.is_file(), "R23D74 closure is missing")
    actual = load_json(CLOSURE_PATH)
    require(actual == expected, "R23D74 closure claim vector changed")
    verify_live_authorities(
        sha256(CLOSURE_PATH), sha256(Path(__file__)), sha256(AUDIT_PATH)
    )
    mutations = [
        ("status", "passing"),
        ("attempt.same_identity_rerun_allowed", True),
        ("attempt.world_build_count", 8),
        ("integration_finding.deterministic_integration_invalidity", False),
        ("official_result.matrix_execution_valid", True),
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
        "[turning/3e] PASS R23D74 immutable physical closure: "
        "qualification=16/16 adoption=True authorization=9/9 worlds=9 "
        "horizons=9 traces=9 success_terminals=6 failure_terminals=3 "
        "evaluator_valid=0 mutations=6 turning=False QSDK-R23=False score=10/25"
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
