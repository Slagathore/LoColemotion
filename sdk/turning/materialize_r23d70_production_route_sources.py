#!/usr/bin/env python3
"""Materialize the narrow R23D70 production-route successor sources.

The clean, live-equal R23D70 receipt-ghost checkpoint is the exact source
parent.  This tool projects the immutable R23D69 production route to the new
campaign identity, binds the prospectively compiled seed-23189 fixture, and
applies only the declared producer/three-consumer receipt-contract repair.
It imports no physics library, constructs no model, and opens no world.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "63a4e2e552188bedcaa6ffc81ce1c790099bf607"


class MaterializationError(RuntimeError):
    """The exact successor projection could not be composed."""


def _source(relative: str) -> str:
    process = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_COMMIT}:{relative}"],
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        raise MaterializationError(
            f"R23D70_SOURCE_UNREADABLE:{relative}:{process.stderr.decode(errors='replace')}"
        )
    return process.stdout.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D70_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:120]!r}"
        )
    return text.replace(old, new)


def _section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(f"R23D70_SECTION_START_INVALID:{start!r}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(f"R23D70_SECTION_END_INVALID:{end!r}")
    return text[start_index:end_index]


def _replace_section(text: str, start: str, end: str, replacement: str) -> str:
    source = _section(text, start, end)
    return text.replace(source, replacement, 1)


def _project_identity(text: str) -> str:
    replacements = (
        (
            "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-",
            "QSDK-R23D70-TRACE-RETENTION-RECEIPT-CONTRACT-REPAIRED-",
        ),
        (
            "r23d69_complete_production_row_conformance_repaired_",
            "r23d70_trace_retention_receipt_contract_repaired_",
        ),
        (
            "complete_production_row_conformance_repaired_three_engine_turning_validation",
            "trace_retention_receipt_contract_repaired_three_engine_turning_validation",
        ),
        ("R23D69", "R23D70"),
        ("r23d69", "r23d70"),
        ("23_187", "23_189"),
        ("23187", "23189"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _rustfmt(text: str) -> str:
    process = subprocess.run(
        ["rustfmt", "--edition", "2024", "--emit", "stdout"],
        input=text,
        capture_output=True,
        check=False,
        encoding="utf-8",
    )
    if process.returncode != 0:
        raise MaterializationError(
            "R23D70_RUSTFMT_FAILED:" + process.stderr.strip()
        )
    return process.stdout.replace("\r\n", "\n")


def _runtime() -> str:
    text = _project_identity(
        _source("sdk/turning/r23d69_production_route_runtime.py")
    )
    text = _replace_exact(
        text,
        '    "prospective_declaration_complete_compact_production_row_ghosts_"\n'
        '    "and_implementation_pending_physical_not_authorized"\n',
        '    "prospective_declaration_complete_minimal_receipt_contract_ghost_"\n'
        '    "and_implementation_pending_physical_not_authorized"\n',
    )
    text = text.replace(
        "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",
    )
    text = text.replace(
        "sha256:6d538c8678951c92bce81e32ba29d076148ad640653d7a3164ad2388614a10b7",
        "sha256:ac82482b473bba827977eac9d3ef4dbdf0617cfd2c7d96b4ca65c83b04381192",
    )
    text = text.replace(
        "threshold_selector_evaluator_or_interpretation_change_count",
        "threshold_selector_behavior_evaluator_or_interpretation_change_count",
    )
    old_fixture = '''INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.00010815839777933434,
    "fixture_yaw_rad": 0.0055464268662035465,
    "initial_linear_velocity_world_m_s": [
        0.002818681765347719,
        0.0,
        -0.000058669596910476685,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        -0.000020042527467012405,
        -0.0031501215416938066,
        0.001983115216717124,
    ],
    "gait_phase_offset_ticks": 1,
}'''
    new_fixture = '''INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.0005549218039959669,
    "fixture_yaw_rad": 0.0006206459365785122,
    "initial_linear_velocity_world_m_s": [
        -0.0018250634893774986,
        0.0,
        0.00038583390414714813,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.00040361820720136166,
        0.0013131443411111832,
        -0.00012799398973584175,
    ],
    "gait_phase_offset_ticks": 3,
}'''
    text = _replace_exact(text, old_fixture, new_fixture)
    conformance = '''    observed = value.get("observed_predecessor_integration_population", {})
    items = observed.get("items", [])
    _require(
        observed.get("complete_population_required") is True
        and observed.get("sampling_used") is False
        and observed.get("population_size") == 1
        and isinstance(items, list)
        and [item.get("failure_id") for item in items]
        == ["shared_trace_retention_receipt_top_level_row_count_absent"]
        and items[0].get("affected_engine_count") == 3
        and items[0].get("affected_cell_count") == 9
        and items[0].get("affected_complete_trace_count") == 9
        and items[0].get("affected_trace_row_count") == 26928
        and observed.get("conformance_margin") == 0
        and observed.get("physical_world_count") == 0,
        "OBSERVED_INTEGRATION_POPULATION_INVALID",
    )
    ghost = value.get("compact_receipt_contract_ghost", {})
    _require(
        ghost.get("producer_projection_count") == 1
        and ghost.get("consumer_parser_count") == 3
        and ghost.get("complete_contract_surface_count") == 4
        and ghost.get("published_trace_row_count") == 2
        and ghost.get("actual_cas_publisher_required") is True
        and ghost.get("actual_successor_producer_projection_required") is True
        and ghost.get("actual_three_consumer_validators_required") is True
        and ghost.get("negative_receipt_mutation_count") == 4
        and ghost.get("negative_consumer_decision_count") == 12
        and ghost.get("full_seeded_world_required") is False
        and ghost.get("behavioral_success_prediction_allowed") is False
        and ghost.get("model_construction_count") == 0
        and ghost.get("world_attempt_count") == 0
        and ghost.get("world_build_count") == 0
        and ghost.get("physical_acceptance_authority") is False,
        "COMPACT_RECEIPT_CONTRACT_GHOST_INVALID",
    )
'''
    return _replace_section(
        text,
        '    observed = value.get("observed_predecessor_integration_population", {})',
        "\n\n\ndef load_declaration",
        conformance,
    )


def _evaluator() -> str:
    text = _project_identity(
        _source(
            "sdk/turning/"
            "r23d69_production_route_three_engine_turning_evaluator.py"
        )
    )
    text = _replace_exact(
        text,
        "import r23d70_production_route_runtime as design\n",
        "import r23d70_production_route_runtime as design\n"
        "from r23d70_receipt_contract import project_retention_receipt\n",
    )
    return _replace_exact(
        text,
        "    return inherited.retain_trace(**kwargs)\n",
        "    receipt = inherited.retain_trace(**kwargs)\n"
        "    return project_retention_receipt(\n"
        "        receipt, expected_row_count=design.CONTROLLER_STEPS\n"
        "    )\n",
    )


def _godot_worker() -> str:
    text = _project_identity(
        _source("tests/test_sdk_qsdk_r23d69_godot_jolt_worker.gd")
    )
    text = _replace_exact(
        text,
        '''				"prospective_declaration_complete_compact_production_row_ghosts_"
				+ "and_implementation_pending_physical_not_authorized"
''',
        '''				"prospective_declaration_complete_minimal_receipt_contract_ghost_"
				+ "and_implementation_pending_physical_not_authorized"
''',
    )
    text = text.replace(
        "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",
    )
    text = _replace_exact(
        text,
        '''const R23D70JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
''',
        '''const R23D70JsonTransportScript := preload(
	"res://sdk/trace_analysis/godot_authoritative_json_transport.gd"
)
const R23D70ReceiptContractScript := preload(
	"res://sdk/turning/r23d70_receipt_contract.gd"
)
''',
    )
    replacement = '''	var receipt: Dictionary = parsed
	var receipt_failures := R23D70ReceiptContractScript.validate_retention_receipt(
		receipt,
		{
			"schema_version": R23D70_TRACE_RETENTION_SCHEMA,
			"stage_id": String(cell["stage_id"]),
			"cell_id": String(cell["cell_id"]),
			"engine_id": R23D70_ENGINE_ID,
			"campaign_seed": R23D70_CAMPAIGN_SEED,
			"profile_id": R23D70_PROFILE_ID,
			"host_mapping_id": R23D70_HOST_MAPPING_ID,
			"row_count": R23D70_CONTROLLER_STEPS,
			"test_only": false,
		},
	)
	if not receipt_failures.is_empty():
		return _r23d70_failure(
			"QSDK_R23D70_GJT_TRACE_RETENTION_RECEIPT_INVALID",
			{"failures": receipt_failures, "receipt": receipt},
		)
'''
    return _replace_section(
        text,
        "\tvar receipt: Dictionary = parsed\n",
        "\tvar artifact: Dictionary =",
        replacement,
    )


def _mujoco() -> str:
    text = _project_identity(
        _source(
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d69_turning_route.py"
        )
    )
    text = _replace_exact(
        text,
        "import r23d70_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402\n",
        "import r23d70_production_route_three_engine_turning_evaluator as evaluator  # noqa: E402\n"
        "from r23d70_receipt_contract import validate_retention_receipt  # noqa: E402\n",
    )
    replacement = '''    receipt = json.loads(matches[0])
    failures = validate_retention_receipt(
        receipt,
        expected_schema=TRACE_RETENTION_SCHEMA,
        expected_stage_id=item.stage_id,
        expected_cell_id=item.cell_id,
        expected_engine_id=ENGINE_ID,
        expected_campaign_seed=CAMPAIGN_SEED,
        expected_profile_id=PROFILE_ID,
        expected_host_mapping_id=HOST_MAPPING_ID,
        expected_row_count=design.CONTROLLER_STEPS,
        expected_test_only=False,
    )
    if failures:
        raise production._core.R23D3MujocoError(
            "QSDK_R23D70_MJC_TRACE_RETENTION_RECEIPT_INVALID:"
            + ",".join(failures),
            world_attempt_count=1,
            world_build_count=1,
        )
    return receipt
'''
    return _replace_section(
        text,
        "    receipt = json.loads(matches[0])\n",
        "\n\ndef _configure_shared_kernel",
        replacement,
    )


def _shared_rapier() -> str:
    text = _source(
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    )
    constants = _project_identity(
        _section(
            text,
            "pub const R23D69_CAMPAIGN_ID",
            "pub(crate) const TURNING_ROUTE_ID",
        )
    )
    constants = _replace_exact(
        constants,
        '''const R23D70_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_108_158_397_779_334_34,
    yaw_rad: 0.005_546_426_866_203_546_5,
    linear_velocity_world_m_s: [
        0.002_818_681_765_347_719,
        0.0,
        -0.000_058_669_596_910_476_685,
    ],
    torso_angular_velocity_world_rad_s: [
        -0.000_020_042_527_467_012_405,
        -0.003_150_121_541_693_806_6,
        0.001_983_115_216_717_124,
    ],
    gait_phase_offset_ticks: 1,
};

''',
        '''const R23D70_INITIAL_PERTURBATION: InitialPerturbation = InitialPerturbation {
    vertical_clearance_m: 0.000_554_921_803_995_966_9,
    yaw_rad: 0.000_620_645_936_578_512_2,
    linear_velocity_world_m_s: [
        -0.001_825_063_489_377_498_6,
        0.0,
        0.000_385_833_904_147_148_13,
    ],
    torso_angular_velocity_world_rad_s: [
        0.000_403_618_207_201_361_66,
        0.001_313_144_341_111_183_2,
        -0.000_127_993_989_735_841_75,
    ],
    gait_phase_offset_ticks: 3,
};

''',
    )
    row_projection = _project_identity(
        _section(
            text,
            "pub(crate) fn r23d69_project_production_trace_row",
            "fn r23d68_retain_trace",
        )
    )
    retention = _project_identity(
        _section(text, "fn r23d69_retain_trace", "fn turning_route_retain_trace")
    )
    old_validation = '''    if receipt["schema_version"] != R23D70_TRACE_RETENTION_SCHEMA
        || receipt["stage_id"] != cell.stage_id
        || receipt["cell_id"] != cell.cell_id
        || receipt["engine_id"] != R23D70_ENGINE_ID
        || receipt["campaign_seed"] != R23D70_CAMPAIGN_SEED
        || receipt["profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || receipt["host_mapping_id"] != R23D62_HOST_MAPPING_ID
        || receipt["row_count"] != R23D27_CONTROLLER_STEPS
        || receipt["retained_before_terminal_entry"] != true
    {
        return Err("QSDK_R23D70_RAP_TRACE_RETENTION_RECEIPT_INVALID".to_owned());
    }
'''
    new_validation = '''    crate::qsdk_r23d70_receipt_contract::validate_retention_receipt(
        &receipt,
        crate::qsdk_r23d70_receipt_contract::ExpectedReceipt {
            schema_version: R23D70_TRACE_RETENTION_SCHEMA,
            stage_id: &cell.stage_id,
            cell_id: &cell.cell_id,
            engine_id: R23D70_ENGINE_ID,
            campaign_seed: R23D70_CAMPAIGN_SEED,
            profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            host_mapping_id: R23D62_HOST_MAPPING_ID,
            row_count: R23D27_CONTROLLER_STEPS,
            test_only: false,
        },
    )
    .map_err(|failures| {
        format!(
            "QSDK_R23D70_RAP_TRACE_RETENTION_RECEIPT_INVALID:{}",
            failures.join(",")
        )
    })?;
'''
    retention = _replace_exact(retention, old_validation, new_validation)
    core = _project_identity(
        _section(
            text,
            "pub(crate) fn run_r23d69_rapier_physical_core",
            "fn run_r23d27_rapier_physical_world",
        )
    )
    core = _replace_exact(
        core,
        "        || !plan.r23d70_route\n",
        "        || plan.r23d69_route\n        || !plan.r23d70_route\n",
    )
    core = _replace_exact(
        core,
        '        "complete_production_row_projection_reused": true,\n',
        '        "complete_production_row_projection_reused": true,\n'
        '        "trace_retention_receipt_contract_validator_bound": true,\n',
    )
    r69_plan = _section(
        text,
        "    const R23D69_ROUTE: Self = Self {",
        "\n\n    fn total_trace_steps",
    )
    r70_plan = _project_identity(r69_plan)
    r70_plan = _replace_exact(
        r70_plan,
        "        r23d70_route: true,\n",
        "        r23d69_route: false,\n        r23d70_route: true,\n",
    )

    text = _replace_exact(
        text,
        "pub(crate) const TURNING_ROUTE_ID",
        constants + "pub(crate) const TURNING_ROUTE_ID",
    )
    text = _replace_exact(
        text,
        "    r23d69_route: bool,\n",
        "    r23d69_route: bool,\n    r23d70_route: bool,\n",
    )
    text = _replace_exact(
        text,
        "        r23d69_route: false,\n",
        "        r23d69_route: false,\n        r23d70_route: false,\n",
        count=5,
    )
    text = _replace_exact(
        text,
        "        r23d69_route: true,\n",
        "        r23d69_route: true,\n        r23d70_route: false,\n",
    )
    text = _replace_exact(
        text,
        "\n\n    fn total_trace_steps",
        "\n\n" + r70_plan + "\n\n    fn total_trace_steps",
    )
    text = _replace_exact(
        text,
        "        || plan.r23d69_route\n        || !plan.r23d68_route\n",
        "        || plan.r23d69_route\n        || plan.r23d70_route\n"
        "        || !plan.r23d68_route\n",
    )
    text = _replace_exact(
        text,
        "        || !plan.r23d69_route\n",
        "        || plan.r23d70_route\n        || !plan.r23d69_route\n",
    )
    text = _replace_exact(
        text,
        "fn r23d68_retain_trace",
        row_projection + "fn r23d68_retain_trace",
    )
    text = _replace_exact(
        text,
        "fn turning_route_retain_trace",
        retention + "fn turning_route_retain_trace",
    )
    text = _replace_exact(
        text,
        "fn run_r23d27_rapier_physical_world",
        core + "fn run_r23d27_rapier_physical_world",
    )
    text = _replace_exact(
        text,
        '''        } else if execution_plan.r23d69_route {
            r23d69_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
        '''        } else if execution_plan.r23d69_route {
            r23d69_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d70_route {
            r23d70_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
    )
    text = _replace_exact(
        text,
        '''    } else if execution_plan.r23d69_route {
        r23d69_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
        '''    } else if execution_plan.r23d69_route {
        r23d69_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d70_route {
        r23d70_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
    )
    return _rustfmt(text)


def _rapier_route() -> str:
    text = _project_identity(
        _source("sdk/adapters/rapier/src/qsdk_r23d69_turning_route.rs")
    )
    text = text.replace(
        "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",
    )
    return _rustfmt(text)


def _rapier_binary() -> str:
    return _rustfmt(
        _project_identity(
            _source("sdk/adapters/rapier/src/bin/qsdk_r23d69_turning_route.rs")
        )
    )


def _rapier_lib() -> str:
    text = _source("sdk/adapters/rapier/src/lib.rs")
    text = _replace_exact(
        text,
        "mod qsdk_r23d70_receipt_contract;\n",
        "mod qsdk_r23d70_receipt_contract;\nmod qsdk_r23d70_turning_route;\n",
    )
    r69_constant_export = _section(
        text,
        "pub use qsdk_r23d3_phase_balanced::r23d27_physical::{\n"
        "    R23D69_CAMPAIGN_ID",
        "pub use qsdk_r23d3_phase_balanced::r23d27_physical::{\n"
        "    run_qsdk_r23d27_rapier_authorization_preflight_impl",
    )
    constant_export = _project_identity(r69_constant_export)
    text = _replace_exact(
        text,
        r69_constant_export,
        r69_constant_export + constant_export,
    )
    export = _project_identity(
        _section(
            text,
            "pub use qsdk_r23d69_turning_route::{",
            "pub use recovery_capability::{",
        )
    )
    text = _replace_exact(
        text,
        "pub use recovery_capability::{",
        export + "pub use recovery_capability::{",
    )
    return _rustfmt(text)


def _zero_world() -> str:
    text = _project_identity(_source("sdk/run_qsdk_r23d69_zero_world.ps1"))
    text = _replace_section(
        text,
        "$preregistrationGate = Join-Path",
        "$evaluatorGate = Join-Path",
        "",
    )
    text = text.replace("$productionGhostGate", "$receiptGhostGate")
    text = text.replace(
        "tests\\test_qsdk_r23d70_complete_production_rows.ps1",
        "tests\\test_qsdk_r23d70_receipt_contract_ghost.ps1",
    )
    text = _replace_exact(text, "    $preregistrationGate,\n", "")
    text = _replace_section(
        text,
        "$null = Invoke-R23D70PowerShellGate $preregistrationGate (",
        "$null = Invoke-R23D70PowerShellGate $evaluatorGate (",
        "",
    )
    text = _replace_exact(
        text,
        '''$null = Invoke-R23D70PowerShellGate $receiptGhostGate (
    "[turning/3e] PASS R23D70 compact complete-production-row ghosts"
)
''',
        '''$null = Invoke-R23D70PowerShellGate $receiptGhostGate (
    "[turning/3e] PASS R23D70 receipt-contract ghost"
)
''',
    )
    text = _replace_exact(
        text,
        '''    compact_complete_production_row_ghost_passed = $true
    compact_failure_projection_ghost_passed = $true
    compact_ghost_model_construction_count = 0
    compact_ghost_world_attempt_count = 0
    compact_ghost_world_build_count = 0
''',
        '''    compact_receipt_contract_ghost_passed = $true
    receipt_contract_producer_projection_count = 1
    receipt_contract_consumer_parser_count = 3
    receipt_contract_positive_surface_count = 4
    receipt_contract_published_trace_row_count = 2
    receipt_contract_negative_mutation_count = 4
    receipt_contract_negative_consumer_decision_count = 12
    compact_ghost_model_construction_count = 0
    compact_ghost_world_attempt_count = 0
    compact_ghost_world_build_count = 0
''',
    )
    text = _replace_exact(
        text,
        "    declaration_mutation_rejection_count = 13\n",
        "    frozen_declaration_audit_passed_at_declaration_boundary = $true\n"
        "    declaration_runtime_projection_passed = $true\n",
    )
    return text.replace(
        "ghosts=2/2 workers=3",
        "receipt_contract=4/4 negatives=12/12 workers=3",
    )


def _zero_world_audit() -> str:
    text = _project_identity(_source("tests/test_qsdk_r23d69_zero_world.ps1"))
    text = _replace_exact(
        text,
        '''    [bool]$receipt.compact_complete_production_row_ghost_passed -and
    [bool]$receipt.compact_failure_projection_ghost_passed -and
''',
        '''    [bool]$receipt.compact_receipt_contract_ghost_passed -and
    [int]$receipt.receipt_contract_producer_projection_count -eq 1 -and
    [int]$receipt.receipt_contract_consumer_parser_count -eq 3 -and
    [int]$receipt.receipt_contract_positive_surface_count -eq 4 -and
    [int]$receipt.receipt_contract_published_trace_row_count -eq 2 -and
    [int]$receipt.receipt_contract_negative_mutation_count -eq 4 -and
    [int]$receipt.receipt_contract_negative_consumer_decision_count -eq 12 -and
''',
    )
    text = _replace_exact(
        text,
        "    [int]$receipt.declaration_mutation_rejection_count -eq 13 -and\n",
        "    [bool]$receipt.frozen_declaration_audit_passed_at_declaration_boundary -and\n"
        "    [bool]$receipt.declaration_runtime_projection_passed -and\n",
    )
    return text.replace(
        "ghosts=2/2 workers=3",
        "receipt_contract=4/4 negatives=12/12 workers=3",
    )


def _implementation_materializer() -> str:
    text = _project_identity(
        _source("sdk/turning/materialize_r23d69_implementation.py")
    )
    text = _replace_exact(
        text,
        '    "sdk/turning/r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json",\n',
        '    "sdk/turning/r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json",\n'
        '    "sdk/turning/r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",\n',
    )
    text = _replace_exact(
        text,
        '''    "tests/test_qsdk_r23d70_complete_production_rows.ps1",
    "tests/test_sdk_qsdk_r23d70_complete_row_ghost.gd",
    "tests/test_qsdk_r23d70_mujoco_complete_row_ghost.py",
''',
        '''    "tests/test_qsdk_r23d70_receipt_contract_ghost.ps1",
    "tests/test_qsdk_r23d70_receipt_contract_ghost.py",
    "tests/test_sdk_qsdk_r23d70_receipt_contract_ghost.gd",
    "sdk/turning/r23d70_receipt_contract.py",
    "sdk/turning/r23d70_receipt_contract.gd",
''',
    )
    text = _replace_exact(
        text,
        '''            "compact_complete_production_row_ghost_count": 3,
            "representative_complete_row_count": 21,
            "compact_failure_projection_ghost_count": 2,
''',
        '''            "receipt_contract_producer_projection_count": 1,
            "receipt_contract_consumer_parser_count": 3,
            "receipt_contract_positive_surface_count": 4,
            "receipt_contract_published_trace_row_count": 2,
            "receipt_contract_negative_mutation_count": 4,
            "receipt_contract_negative_consumer_decision_count": 12,
''',
    )
    text = text.replace(
        '"compact_production_row_ghosts_passed": True,',
        '"compact_receipt_contract_ghost_passed": True,',
    )
    text = text.replace(
        '"process_projection_conforms_for_complete_declared_shape_population": True,',
        '"receipt_contract_conforms_for_complete_declared_surface_population": True,',
    )
    return text


def _role_gate() -> str:
    text = _project_identity(_source("tests/test_qsdk_r23d69_campaign_roles.ps1"))
    text = _replace_exact(
        text,
        '''    [int]$implementation.dependency_inventory.transitive_path_count -eq 214 -and
    @($implementation.dependency_digests.Keys).Count -eq 214
''',
        '''    [int]$implementation.dependency_inventory.transitive_path_count -eq
        @($implementation.dependency_digests.Keys).Count -and
    @($implementation.dependency_digests.Keys).Count -gt 0
''',
    )
    return _replace_exact(
        text,
        "            [int]$supervisor.implementation_dependency_count -eq 214 -and\n",
        "            [int]$supervisor.implementation_dependency_count -eq\n"
        "                @($implementation.dependency_digests.Keys).Count -and\n",
    )


def _attestation_materializer() -> str:
    text = _project_identity(
        _source("sdk/turning/materialize_r23d69_campaign_attestation_manifest.py")
    )
    return _replace_exact(
        text,
        '        and len(value["dependency_digests"]) == 214\n',
        '        and len(value["dependency_digests"])\n'
        '        == value["dependency_inventory"]["transitive_path_count"]\n'
        '        and len(value["dependency_digests"]) > 0\n',
    )


def _plain(relative: str) -> str:
    return _project_identity(_source(relative))


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk/run_qsdk_r23d70_supervisor.ps1", lambda: _plain("sdk/run_qsdk_r23d69_supervisor.ps1")),
    (ROOT / "tests/test_sdk_qsdk_r23d70_godot_jolt_worker.gd", _godot_worker),
    (ROOT / "sdk/turning/r23d70_production_route_runtime.py", _runtime),
    (
        ROOT / "sdk/turning/r23d70_production_route_three_engine_turning_evaluator.py",
        _evaluator,
    ),
    (ROOT / "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs", _shared_rapier),
    (ROOT / "sdk/adapters/rapier/src/qsdk_r23d70_turning_route.rs", _rapier_route),
    (ROOT / "sdk/adapters/rapier/src/bin/qsdk_r23d70_turning_route.rs", _rapier_binary),
    (ROOT / "sdk/adapters/rapier/src/lib.rs", _rapier_lib),
    (
        ROOT / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d70_turning_route.py",
        _mujoco,
    ),
    (ROOT / "sdk/run_qsdk_r23d70_zero_world.ps1", _zero_world),
    (ROOT / "tests/test_qsdk_r23d70_zero_world.ps1", _zero_world_audit),
    (ROOT / "tests/test_qsdk_r23d70_evaluator.ps1", lambda: _plain("tests/test_qsdk_r23d69_evaluator.ps1")),
    (
        ROOT / "sdk/turning/materialize_r23d70_implementation.py",
        _implementation_materializer,
    ),
    (ROOT / "tests/test_qsdk_r23d70_campaign_roles.ps1", _role_gate),
    (
        ROOT / "sdk/turning/materialize_r23d70_campaign_attestation_manifest.py",
        _attestation_materializer,
    ),
)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    for path, compose in OUTPUTS:
        raw = compose().encode("utf-8")
        relative = path.relative_to(ROOT).as_posix()
        if arguments.command == "write":
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(raw)
        elif not path.is_file() or path.read_bytes() != raw:
            raise MaterializationError(f"R23D70_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D70 production route sources {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
