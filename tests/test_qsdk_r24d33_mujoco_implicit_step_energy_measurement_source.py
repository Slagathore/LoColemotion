"""Compact source audit for the QSDK-R24D33 zero-world measurement design."""

from __future__ import annotations

import inspect
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
SDK_ROOT = ROOT / "sdk"
for path in (SDK_ROOT / "python", SDK_ROOT / "adapters/mujoco", ROOT):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    exact,
    load,
    require,
    sha256,
)
from sporespore_mujoco_adapter import implicit_step_energy as measurement  # noqa: E402
from sporespore_mujoco_adapter import (  # noqa: E402
    qsdk_r24d33_implicit_step_energy_measurement_worker as worker,
)


PARENT = "8b57a946cbaea0382f24c606524ab00b1b41d1f4"
CONTRACT_PATH = (
    SDK_ROOT / "recovery/r24d33_mujoco_implicit_step_energy_measurement_contract_v1.json"
)
R32_CONTRACT_PATH = SDK_ROOT / "recovery/r24d32_corrected_energy_progression_contract_v1.json"
R32_CLOSURE_PATH = SDK_ROOT / "recovery/r24d32_corrected_energy_progression_physical_closure_v1.json"
R32_DIAGNOSIS_PATH = SDK_ROOT / "recovery/r24d32_implicit_step_energy_diagnosis_v1.json"
NEW_PATHS = [
    "sdk/recovery/r24d33_mujoco_implicit_step_energy_measurement_contract_v1.json",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/implicit_step_energy.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r24d33_implicit_step_energy_measurement_worker.py",
    "tests/test_qsdk_r24d33_mujoco_implicit_step_energy_measurement_source.py",
    "sdk/run_qsdk_r24d33_implicit_step_energy_measurement_zero_world.ps1",
]
HISTORICAL_DIGEST_PATHS = [
    "sdk/recovery/r24d32_corrected_energy_progression_physical_closure_v1.json",
    "sdk/recovery/r24d32_implicit_step_energy_diagnosis_v1.json",
]


def _absent_at_parent(relative: str) -> bool:
    return subprocess.run(
        ["git", "cat-file", "-e", f"{PARENT}:{relative}"],
        cwd=ROOT,
        check=False,
        capture_output=True,
    ).returncode != 0


def audit() -> None:
    contract = load(CONTRACT_PATH)
    predecessor = load(R32_CONTRACT_PATH)
    closure = load(R32_CLOSURE_PATH)
    diagnosis = load(R32_DIAGNOSIS_PATH)
    worker.load_contract_v1(CONTRACT_PATH)

    exact(contract["schema_version"], worker.CONTRACT_SCHEMA, "SCHEMA")
    exact(contract["gate_id"], worker.GATE_ID, "GATE")
    exact(contract["campaign_id"], worker.CAMPAIGN_ID, "CAMPAIGN")
    exact(contract["declaration_parent_commit"], PARENT, "PARENT")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    for key in (
        "physical_question_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ):
        exact(contract[key], False, f"DECLARATION_{key.upper()}")

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D32", "LINEAGE_GATE")
    exact(lineage["predecessor_source_commit"], worker.R24D32_SOURCE, "LINEAGE_SOURCE")
    exact(lineage["predecessor_closure_raw_sha256"], sha256(R32_CLOSURE_PATH.read_bytes()), "CLOSURE_HASH")
    exact(lineage["retained_diagnosis_raw_sha256"], sha256(R32_DIAGNOSIS_PATH.read_bytes()), "DIAGNOSIS_HASH")
    exact(lineage["predecessor_result"], closure["closure_status"], "LINEAGE_RESULT")
    exact(diagnosis["next_boundary"]["gate_id"], worker.GATE_ID, "DIAGNOSIS_NEXT")
    for key in (
        "predecessor_result_rewritten",
        "predecessor_threshold_rewritten",
        "predecessor_evaluator_rewritten",
        "predecessor_interpretation_rewritten",
        "predecessor_may_rerun",
        "predecessor_may_requalify",
        "historical_closure_audits_reexecuted_in_this_critical_path",
    ):
        exact(lineage[key], False, f"LINEAGE_{key.upper()}")

    sources = contract["primary_source_basis"]
    exact(len(sources), 3, "PRIMARY_SOURCE_COUNT")
    require(all("mujoco" in item["source"] for item in sources), "PRIMARY_SOURCE_AUTHORITY")
    exact(contract["frozen_supported_subset"]["engine_version"], "3.11.0", "ENGINE_VERSION")
    exact(contract["frozen_supported_subset"]["integrator"], "implicitfast", "INTEGRATOR")
    exact(contract["measurement_design"]["profile_id"], measurement.PROFILE_ID, "PROFILE")
    exact(contract["measurement_design"]["mechanical_energy_change_used_as_input"], False, "NO_ENERGY_INPUT")
    exact(contract["measurement_design"]["balance_residual_used_as_input"], False, "NO_RESIDUAL_INPUT")

    expected_inventory = predecessor["source_inventory"] + HISTORICAL_DIGEST_PATHS + NEW_PATHS
    exact(contract["source_inventory"], expected_inventory, "SOURCE_INVENTORY")
    exact(len(contract["source_inventory"]), 104, "SOURCE_COUNT")
    exact(len(set(contract["source_inventory"])), 104, "SOURCE_UNIQUE")
    require(all((ROOT / item).is_file() for item in contract["source_inventory"]), "SOURCE_EXISTS")
    require(all(_absent_at_parent(item) for item in NEW_PATHS), "NEW_PATH_ABSENT_AT_PARENT")
    require(
        subprocess.run(
            ["git", "diff", "--quiet", PARENT, "--", *expected_inventory[:-len(NEW_PATHS)]],
            cwd=ROOT,
            check=False,
        ).returncode
        == 0,
        "EXISTING_SOURCE_DRIFT",
    )

    controls, details = worker._zero_world_controls()
    exact(list(controls), contract["complete_zero_world_gate"]["required_controls"], "CONTROLS")
    require(all(controls.values()), "CONTROL_FAILURE")
    exact(details["profile_id"], measurement.PROFILE_ID, "DETAIL_PROFILE")
    source = inspect.getsource(measurement.measure_implicit_step_energy_work_v3)
    require("import mujoco" not in inspect.getsource(measurement), "MUJOCO_IMPORT")
    require("balance_residual" not in source and "mechanical_energy" not in source, "TAUTOLOGY_SURFACE")
    exact(contract["complete_zero_world_gate"]["model_construction_count"], 0, "MODELS")
    exact(contract["complete_zero_world_gate"]["world_build_count"], 0, "WORLDS")
    exact(contract["complete_zero_world_gate"]["solver_step_count"], 0, "STEPS")
    exact(contract["qualification_and_closure"]["physical_execution_permitted"], False, "PHYSICS")
    print(
        "QSDK_R24D33_MUJOCO_IMPLICIT_STEP_ENERGY_MEASUREMENT_SOURCE_PASS "
        "controls=12/12 sources=104 historical_audits_reexecuted=0 worlds=0 solver_steps=0"
    )


if __name__ == "__main__":
    audit()
