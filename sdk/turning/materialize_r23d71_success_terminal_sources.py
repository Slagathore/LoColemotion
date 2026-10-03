#!/usr/bin/env python3
"""Materialize the narrow R23D71 native success-terminal successor sources.

The clean, pushed R23D71 declaration commit is the sole source parent. This
tool projects the immutable R23D70 production routes to the fresh campaign
identity and seed, then applies only the declared success-terminal correction:
successful terminals retain the canonical nested ``execution`` object and
remove inherited root execution counters. Failure-terminal semantics remain
unchanged. The tool imports no physics library and opens no world.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "2fc1a850ae7edcf14af3181abb849c281f1c806e"


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
            f"R23D71_SOURCE_UNREADABLE:{relative}:"
            + process.stderr.decode(errors="replace")
        )
    return process.stdout.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D71_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:120]!r}"
        )
    return text.replace(old, new)


def _section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(f"R23D71_SECTION_START_INVALID:{start!r}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(f"R23D71_SECTION_END_INVALID:{end!r}")
    return text[start_index:end_index]


def _replace_section(text: str, start: str, end: str, replacement: str) -> str:
    return text.replace(_section(text, start, end), replacement, 1)


def _identity(text: str) -> str:
    replacements = (
        (
            "QSDK-R23D70-TRACE-RETENTION-RECEIPT-CONTRACT-REPAIRED-",
            "QSDK-R23D71-SUCCESS-TERMINAL-PROJECTION-REPAIRED-",
        ),
        (
            "r23d70_trace_retention_receipt_contract_repaired_",
            "r23d71_success_terminal_projection_repaired_",
        ),
        (
            "trace_retention_receipt_contract_repaired_three_engine_turning_validation",
            "success_terminal_projection_repaired_three_engine_turning_validation",
        ),
        ("R23D70", "R23D71"),
        ("r23d70", "r23d71"),
        ("23_189", "23_191"),
        ("23189", "23191"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _fixture(text: str) -> str:
    replacements = (
        ("0.0005549218039959669", "0.0002604132751002908"),
        ("0.0006206459365785122", "-0.0049262382090091705"),
        ("-0.0018250634893774986", "0.002370542846620083"),
        ("0.00038583390414714813", "0.0037111244164407253"),
        ("0.00040361820720136166", "-0.0003552224952727556"),
        ("0.0013131443411111832", "-0.0022123241797089577"),
        ("-0.00012799398973584175", "0.00008024764247238636"),
        ("0.000_554_921_803_995_966_9", "0.000_260_413_275_100_290_8"),
        ("0.000_620_645_936_578_512_2", "-0.004_926_238_209_009_170_5"),
        ("-0.001_825_063_489_377_498_6", "0.002_370_542_846_620_083"),
        ("0.000_385_833_904_147_148_13", "0.003_711_124_416_440_725_3"),
        ("0.000_403_618_207_201_361_66", "-0.000_355_222_495_272_755_6"),
        ("0.001_313_144_341_111_183_2", "-0.002_212_324_179_708_957_7"),
        ("-0.000_127_993_989_735_841_75", "0.000_080_247_642_472_386_36"),
        ('"gait_phase_offset_ticks": 3', '"gait_phase_offset_ticks": -1'),
        ("gait_phase_offset_ticks: 3", "gait_phase_offset_ticks: -1"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _common(text: str) -> str:
    text = _fixture(_identity(text))
    text = text.replace(
        "prospective_declaration_complete_minimal_receipt_contract_ghost_"
        '"\n    "and_implementation_pending_physical_not_authorized"',
        "prospective_declaration_complete_compact_success_terminal_projection_"
        '"\n    "ghost_and_implementation_pending_physical_not_authorized"',
    )
    text = text.replace(
        "prospective_declaration_complete_minimal_receipt_contract_ghost_"
        '"\n\t\t\t\t+ "and_implementation_pending_physical_not_authorized"',
        "prospective_declaration_complete_compact_success_terminal_projection_"
        '"\n\t\t\t\t+ "ghost_and_implementation_pending_physical_not_authorized"',
    )
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
        raise MaterializationError("R23D71_RUSTFMT_FAILED:" + process.stderr.strip())
    return process.stdout.replace("\r\n", "\n")


def _runtime() -> str:
    text = _common(_source("sdk/turning/r23d70_production_route_runtime.py"))
    text = text.replace(
        "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json",
    )
    text = text.replace(
        "sha256:ac82482b473bba827977eac9d3ef4dbdf0617cfd2c7d96b4ca65c83b04381192",
        "sha256:622ad55225d3735aefb8babddf263e16c748decd1a8cf533f4753e8fac7cc6d1",
    )
    conformance = '''    observed = value.get("observed_predecessor_integration_population", {})
    items = observed.get("items", [])
    _require(
        observed.get("complete_observed_population_required") is True
        and observed.get("sampling_used") is False
        and observed.get("population_size") == 1
        and isinstance(items, list)
        and [item.get("failure_id") for item in items]
        == ["success_terminal_nested_execution_plus_stale_root_execution_counts"]
        and items[0].get("observed_engine_count") == 1
        and items[0].get("observed_cell_count") == 1
        and items[0].get("unobserved_engine_count") == 2
        and items[0].get("unopened_cell_count") == 8
        and observed.get("conformance_margin") == 0
        and observed.get("physical_world_count") == 0,
        "OBSERVED_INTEGRATION_POPULATION_INVALID",
    )
    contract = value.get("success_terminal_projection_contract", {})
    producers = contract.get("producer_population", [])
    forbidden = contract.get("forbidden_success_root_count_keys", [])
    _require(
        contract.get("producer_population_size") == 3
        and contract.get("producer_population_complete") is True
        and [item.get("engine_id") for item in producers]
        == ["godot_jolt", "rapier_parry", "mujoco"]
        and contract.get("shared_projector_semantic_change_allowed") is False
        and contract.get("success_execution_world_attempt_count") == 1
        and contract.get("success_execution_world_build_count") == 1
        and contract.get("success_root_model_construction_count_forbidden") is True
        and forbidden
        == [
            "world_attempt_count",
            "world_build_count",
            "world_build_count_exact",
            "world_build_count_lower_bound",
            "world_build_count_upper_bound",
        ],
        "SUCCESS_TERMINAL_PROJECTION_CONTRACT_INVALID",
    )
    ghost = value.get("compact_success_terminal_projection_ghost", {})
    _require(
        ghost.get("native_success_producer_count") == 3
        and ghost.get("shared_projector_count") == 1
        and ghost.get("complete_contract_surface_count") == 4
        and ghost.get("positive_projection_decision_count") == 3
        and ghost.get("negative_root_count_mutation_count") == 5
        and ghost.get("negative_projection_decision_count") == 15
        and ghost.get("full_seeded_world_required") is False
        and ghost.get("behavioral_success_prediction_allowed") is False
        and ghost.get("model_construction_count") == 0
        and ghost.get("world_attempt_count") == 0
        and ghost.get("world_build_count") == 0
        and ghost.get("physical_acceptance_authority") is False,
        "COMPACT_SUCCESS_TERMINAL_GHOST_INVALID",
    )
'''
    return _replace_section(
        text,
        '    observed = value.get("observed_predecessor_integration_population", {})',
        "\n\n\ndef load_declaration",
        conformance,
    )


def _evaluator() -> str:
    return _common(
        _source("sdk/turning/r23d70_production_route_three_engine_turning_evaluator.py")
    )


def _receipt_python() -> str:
    return _common(_source("sdk/turning/r23d70_receipt_contract.py"))


def _receipt_godot() -> str:
    return _common(_source("sdk/turning/r23d70_receipt_contract.gd"))


def _receipt_rust() -> str:
    return _rustfmt(
        _common(
            _source("sdk/adapters/rapier/src/qsdk_r23d70_receipt_contract.rs")
        )
    )


def _godot_worker() -> str:
    text = _common(_source("tests/test_sdk_qsdk_r23d70_godot_jolt_worker.gd"))
    text = text.replace(
        "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json",
    )
    cleanup = '''\tif success:
\t\tfor root_key in [
\t\t\t"model_construction_count",
\t\t\t"world_attempt_count",
\t\t\t"world_build_count",
\t\t\t"world_build_count_exact",
\t\t\t"world_build_count_lower_bound",
\t\t\t"world_build_count_upper_bound",
\t\t]:
\t\t\tresult.erase(root_key)
'''
    return _replace_exact(
        text,
        '\tresult["physical_acceptance_authority"] = false\n\tif result.has("failure_code"):\n',
        '\tresult["physical_acceptance_authority"] = false\n' + cleanup + '\tif result.has("failure_code"):\n',
    )


def _mujoco() -> str:
    text = _common(
        _source(
            "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
            "qsdk_r23d70_turning_route.py"
        )
    )
    normalizer = '''def _normalize_success_terminal(
    value: Mapping[str, Any],
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    """Apply the exact R23D71 production success identity and one count shape."""

    terminal = copy.deepcopy(dict(value))
    terminal.update(
        schema_version=REPORT_SCHEMA,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        stage_id=STAGE_ID,
        source_commit=arguments.source_commit,
        claims=copy.deepcopy(FALSE_CLAIMS),
        physical_acceptance_authority=False,
    )
    for root_key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "world_build_count_exact",
        "world_build_count_lower_bound",
        "world_build_count_upper_bound",
    ):
        terminal.pop(root_key, None)
    json.dumps(terminal, allow_nan=False)
    return terminal


'''
    text = _replace_exact(
        text,
        "def _project_failure_terminal(\n",
        normalizer + "def _project_failure_terminal(\n",
    )
    return _replace_section(
        text,
        "            value.update(\n                schema_version=REPORT_SCHEMA,\n",
        '            marker = "QSDK_R23D71_MUJOCO_TERMINAL "',
        "            value = _normalize_success_terminal(value, arguments)\n",
    )


def _rapier_route() -> str:
    text = _common(
        _source("sdk/adapters/rapier/src/qsdk_r23d70_turning_route.rs")
    )
    text = text.replace(
        "r23d69_complete_production_row_conformance_repaired_three_engine_turning_preregistration_v1.json",
        "r23d70_trace_retention_receipt_contract_repaired_three_engine_turning_preregistration_v1.json",
    )
    cleanup = '''    if report {
        for root_key in [
            "model_construction_count",
            "world_attempt_count",
            "world_build_count",
            "world_build_count_exact",
            "world_build_count_lower_bound",
            "world_build_count_upper_bound",
        ] {
            object.remove(root_key);
        }
    }
'''
    text = _replace_exact(text, "    if !report {\n", cleanup + "    if !report {\n")
    ghost = '''pub fn run_qsdk_r23d71_success_terminal_projection_ghost() -> Result<Value, String> {
    let terminal = normalize_terminal(
        json!({
            "schema_version": "sporespore_qsdk_r23d70_engine_cell_report_v1",
            "execution": {
                "world_attempt_count": 1,
                "world_build_count": 1,
            },
            "model_construction_count": 0,
            "world_attempt_count": 0,
            "world_build_count": 0,
        }),
        "reference_zero",
        "1111111111111111111111111111111111111111",
        true,
    );
    if terminal["schema_version"] != REPORT_SCHEMA
        || terminal["execution"]["world_attempt_count"] != 1
        || terminal["execution"]["world_build_count"] != 1
        || terminal.get("model_construction_count").is_some()
        || terminal.get("world_attempt_count").is_some()
        || terminal.get("world_build_count").is_some()
    {
        return Err("QSDK_R23D71_RAPIER_SUCCESS_TERMINAL_GHOST_INVALID".to_owned());
    }
    Ok(terminal)
}

'''
    text = _replace_exact(
        text,
        "pub fn run_qsdk_r23d71_rapier_complete_row_ghost() -> Result<Value, String> {\n",
        ghost + "pub fn run_qsdk_r23d71_rapier_complete_row_ghost() -> Result<Value, String> {\n",
    )
    test = '''    #[test]
    fn r23d71_success_terminal_projection_ghost() {
        let terminal = run_qsdk_r23d71_success_terminal_projection_ghost().unwrap();
        println!(
            "QSDK_R23D71_RAPIER_SUCCESS_TERMINAL_GHOST {}",
            serde_json::to_string(&terminal).unwrap()
        );
    }

'''
    text = _replace_exact(
        text,
        "    #[test]\n    fn compact_complete_rows_use_the_physical_projection() {\n",
        test + "    #[test]\n    fn compact_complete_rows_use_the_physical_projection() {\n",
    )
    return _rustfmt(text)


def _rapier_binary() -> str:
    return _rustfmt(
        _common(
            _source("sdk/adapters/rapier/src/bin/qsdk_r23d70_turning_route.rs")
        )
    )


def _shared_rapier() -> str:
    text = _source(
        "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    )
    constants = _fixture(
        _identity(
            _section(
                text,
                "pub const R23D70_CAMPAIGN_ID",
                "pub(crate) const TURNING_ROUTE_ID",
            )
        )
    )
    row_projection = _identity(
        _section(
            text,
            "pub(crate) fn r23d70_project_production_trace_row",
            "fn r23d68_retain_trace",
        )
    )
    retention = _identity(
        _section(text, "fn r23d70_retain_trace", "fn turning_route_retain_trace")
    )
    core = _fixture(
        _identity(
            _section(
                text,
                "pub(crate) fn run_r23d70_rapier_physical_core",
                "fn run_r23d27_rapier_physical_world",
            )
        )
    )
    core = _replace_exact(
        core,
        "        || !plan.r23d71_route\n",
        "        || plan.r23d70_route\n        || !plan.r23d71_route\n",
    )
    plan = _identity(
        _section(
            text,
            "    const R23D70_ROUTE: Self = Self {",
            "\n\n    fn total_trace_steps",
        )
    )
    plan = _replace_exact(
        plan,
        "        r23d71_route: true,\n",
        "        r23d70_route: false,\n        r23d71_route: true,\n",
    )

    text = _replace_exact(
        text,
        "pub(crate) const TURNING_ROUTE_ID",
        constants + "pub(crate) const TURNING_ROUTE_ID",
    )
    text = _replace_exact(
        text,
        "    r23d70_route: bool,\n",
        "    r23d70_route: bool,\n    r23d71_route: bool,\n",
    )
    text = _replace_exact(
        text,
        "        r23d70_route: false,\n",
        "        r23d70_route: false,\n        r23d71_route: false,\n",
        count=6,
    )
    text = _replace_exact(
        text,
        "        r23d70_route: true,\n",
        "        r23d70_route: true,\n        r23d71_route: false,\n",
    )
    text = _replace_exact(
        text,
        "\n\n    fn total_trace_steps",
        "\n\n" + plan + "\n\n    fn total_trace_steps",
    )
    text = text.replace(
        "        || plan.r23d70_route\n",
        "        || plan.r23d70_route\n        || plan.r23d71_route\n",
    )
    text = _replace_exact(
        text,
        "        || !plan.r23d70_route\n",
        "        || plan.r23d71_route\n        || !plan.r23d70_route\n",
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
        '''        } else if execution_plan.r23d70_route {
            r23d70_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
        '''        } else if execution_plan.r23d70_route {
            r23d70_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d71_route {
            r23d71_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
    )
    text = _replace_exact(
        text,
        '''    } else if execution_plan.r23d70_route {
        r23d70_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
        '''    } else if execution_plan.r23d70_route {
        r23d70_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d71_route {
        r23d71_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
    )
    return _rustfmt(text)


def _rapier_lib() -> str:
    text = _source("sdk/adapters/rapier/src/lib.rs")
    text = _replace_exact(
        text,
        "mod qsdk_r23d70_turning_route;\n",
        "mod qsdk_r23d70_turning_route;\n"
        "mod qsdk_r23d71_receipt_contract;\n"
        "mod qsdk_r23d71_turning_route;\n",
    )
    source_constants = _section(
        text,
        "pub use qsdk_r23d3_phase_balanced::r23d27_physical::{\n"
        "    R23D70_CAMPAIGN_ID",
        "pub use qsdk_r23d3_phase_balanced::r23d27_physical::{\n"
        "    run_qsdk_r23d27_rapier_authorization_preflight_impl",
    )
    constants = _identity(source_constants)
    text = _replace_exact(
        text,
        source_constants,
        source_constants + constants,
    )
    export = _identity(
        _section(
            text,
            "pub use qsdk_r23d70_turning_route::{",
            "pub use recovery_capability::{",
        )
    )
    export = _replace_exact(
        export,
        "    run_qsdk_r23d71_rapier_physical, run_qsdk_r23d71_rapier_preflight,\n",
        "    run_qsdk_r23d71_rapier_physical, run_qsdk_r23d71_rapier_preflight,\n"
        "    run_qsdk_r23d71_success_terminal_projection_ghost,\n",
    )
    text = _replace_exact(
        text,
        "pub use recovery_capability::{",
        export + "pub use recovery_capability::{",
    )
    return _rustfmt(text)


def _supervisor() -> str:
    text = _common(_source("sdk/run_qsdk_r23d70_supervisor.ps1"))
    observed_terminal = r'''function Assert-R23D71ObservedTerminal(
    $Terminal,
    [string]$EngineId,
    [string]$ArmId,
    [string]$SourceCommit
) {
    Assert-R23D71 ($Terminal -is [Collections.IDictionary]) (
        "worker terminal is not a JSON object"
    )
    $cellId = "r23d71__${EngineId}__s${campaignSeed}__${ArmId}"
    $expected = [ordered]@{
        campaign_id = $campaignId
        gate_id = $gateId
        question_class = "finite_decision"
        stage_id = $stageId
        cell_id = $cellId
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        host_mapping_id = [string]$hostMappingIds[$EngineId]
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        source_commit = $SourceCommit
    }
    foreach ($entry in $expected.GetEnumerator()) {
        $name = [string]$entry.Key
        Assert-R23D71 ($Terminal.Contains($name)) "worker terminal identity missing: $name"
        $matches = if ($name -ceq "campaign_seed") {
            [int]$Terminal[$name] -eq [int]$entry.Value
        } elseif ($name -ceq "turn_heading_offset_rad") {
            [double]$Terminal[$name] -eq [double]$entry.Value
        } else {
            [string]$Terminal[$name] -ceq [string]$entry.Value
        }
        Assert-R23D71 $matches "worker terminal identity mismatch: $name"
    }

    $schema = [string]$Terminal.schema_version
    $isSuccess = @($terminalSuccessSchemas | Where-Object {
        [string]$_ -ceq $schema
    }).Count -eq 1
    $isFailure = @($terminalFailureSchemas | Where-Object {
        [string]$_ -ceq $schema
    }).Count -eq 1
    Assert-R23D71 ($isSuccess -ne $isFailure) (
        "worker terminal success/failure schema identity changed"
    )
    Assert-R23D71 (
        $Terminal.Contains("physical_acceptance_authority") -and
        -not [bool]$Terminal.physical_acceptance_authority
    ) "worker terminal authority changed"

    $projection = Get-SporeSporeTerminalExecutionProjection `
        -Terminal $Terminal `
        -SuccessSchemas $terminalSuccessSchemas `
        -FailureSchemas $terminalFailureSchemas
    if ($isSuccess) {
        Assert-R23D71 (
            -not $Terminal.Contains("model_construction_count") -and
            [string]$projection.projection_source -ceq "execution" -and
            [int]$projection.world_attempt_count -eq 1 -and
            [int]$projection.world_build_count -eq 1 -and
            [bool]$projection.world_build_count_exact
        ) "successful worker terminal execution projection changed"
    } else {
        Assert-R23D71 (
            $Terminal.Contains("model_construction_count") -and
            [int]$Terminal.model_construction_count -ge 0 -and
            [string]$projection.projection_source -ceq "terminal_root_failure"
        ) "failure worker terminal execution projection changed"
    }
}
'''
    text = _replace_section(
        text,
        "function Assert-R23D71ObservedTerminal(",
        "\nfunction Get-R23D71WorkerEnvironment(",
        observed_terminal + "\n",
    )

    count_recovery = r'''        $observedAttemptCount = 1
        $observedBuildCount = 1
        $observedCountsExact = $false
        $lowerBound = 0
        $upperBound = 1
        if ($observedTerminal -is [Collections.IDictionary]) {
            try {
                $observedProjection = Get-SporeSporeTerminalExecutionProjection `
                    -Terminal $observedTerminal `
                    -SuccessSchemas $terminalSuccessSchemas `
                    -FailureSchemas $terminalFailureSchemas
                $observedAttemptCount = [int]$observedProjection.world_attempt_count
                $observedBuildCount = [int]$observedProjection.world_build_count
                $observedCountsExact = [bool]$observedProjection.world_build_count_exact
                $lowerBound = [int]$observedProjection.world_build_count_lower_bound
                $upperBound = [int]$observedProjection.world_build_count_upper_bound
            } catch {
                # Preserve the observed terminal below. The conservative 0..1
                # bounds remain authoritative when its execution shape is invalid.
            }
        }
'''
    text = _replace_section(
        text,
        "        $observedAttemptCount = 1\n",
        "        $terminal = Get-R23D71TerminalFailure `\n",
        count_recovery,
    )
    text = _replace_exact(
        text,
        "            -WorldBuildCountUpperBound 1\n",
        "            -WorldBuildCountUpperBound $upperBound\n",
    )

    terminal_controls = r'''    $successTerminalControlCount = 0
    $failureTerminalControlCount = 0
    foreach ($engineId in $engineOrder) {
        $successTerminal = [ordered]@{
            schema_version = "sporespore_qsdk_r23d71_engine_cell_report_v1"
            campaign_id = $campaignId
            gate_id = $gateId
            question_class = "finite_decision"
            stage_id = $stageId
            cell_id = "r23d71__${engineId}__s${campaignSeed}__reference_zero"
            engine_id = $engineId
            campaign_seed = $campaignSeed
            profile_id = $profileId
            host_mapping_id = [string]$hostMappingIds[$engineId]
            arm_id = "reference_zero"
            turn_heading_offset_rad = 0.0
            source_commit = ("1" * 40)
            execution = [ordered]@{
                world_attempt_count = 1
                world_build_count = 1
            }
            physical_acceptance_authority = $false
        }
        Assert-R23D71ObservedTerminal `
            $successTerminal $engineId "reference_zero" ("1" * 40)
        $successProjection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $successTerminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
        Assert-R23D71 (
            [string]$successProjection.projection_source -ceq "execution" -and
            [int]$successProjection.world_attempt_count -eq 1 -and
            [int]$successProjection.world_build_count -eq 1 -and
            [bool]$successProjection.world_build_count_exact
        ) "supervisor success-terminal control changed: $engineId"
        $successTerminalControlCount += 1

        $failureTerminal = Get-R23D71TerminalFailure `
            -EngineId $engineId -ArmId "reference_zero" `
            -SourceCommit ("1" * 40) -Code "R23D71_ROLE_PREFLIGHT_CONTROL"
        Assert-R23D71ObservedTerminal `
            $failureTerminal $engineId "reference_zero" ("1" * 40)
        $failureProjection = Get-SporeSporeTerminalExecutionProjection `
            -Terminal $failureTerminal -SuccessSchemas $terminalSuccessSchemas `
            -FailureSchemas $terminalFailureSchemas
        Assert-R23D71 (
            [string]$failureProjection.projection_source -ceq "terminal_root_failure" -and
            [int]$failureProjection.world_attempt_count -eq 0 -and
            [int]$failureProjection.world_build_count -eq 0 -and
            [bool]$failureProjection.world_build_count_exact
        ) "supervisor failure-terminal control changed: $engineId"
        $failureTerminalControlCount += 1
    }
    $terminalControlCount = $successTerminalControlCount + $failureTerminalControlCount
'''
    text = _replace_section(
        text,
        "    $terminalControlCount = 0\n",
        "    $cleanGitSourceBindingsChecked = $false\n",
        terminal_controls,
    )
    text = _replace_exact(
        text,
        "        terminal_transport_control_count = $terminalControlCount\n",
        "        terminal_transport_control_count = $terminalControlCount\n"
        "        success_terminal_transport_control_count = $successTerminalControlCount\n"
        "        failure_terminal_transport_control_count = $failureTerminalControlCount\n",
    )
    return text


def _plain(relative: str) -> str:
    return _common(_source(relative))


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk/turning/r23d71_production_route_runtime.py", _runtime),
    (
        ROOT / "sdk/turning/r23d71_production_route_three_engine_turning_evaluator.py",
        _evaluator,
    ),
    (ROOT / "sdk/turning/r23d71_receipt_contract.py", _receipt_python),
    (ROOT / "sdk/turning/r23d71_receipt_contract.gd", _receipt_godot),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d71_receipt_contract.rs",
        _receipt_rust,
    ),
    (ROOT / "tests/test_sdk_qsdk_r23d71_godot_jolt_worker.gd", _godot_worker),
    (
        ROOT / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d71_turning_route.py",
        _mujoco,
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
        _shared_rapier,
    ),
    (ROOT / "sdk/adapters/rapier/src/qsdk_r23d71_turning_route.rs", _rapier_route),
    (
        ROOT / "sdk/adapters/rapier/src/bin/qsdk_r23d71_turning_route.rs",
        _rapier_binary,
    ),
    (ROOT / "sdk/adapters/rapier/src/lib.rs", _rapier_lib),
    (
        ROOT / "sdk/run_qsdk_r23d71_supervisor.ps1",
        _supervisor,
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
            raise MaterializationError(f"R23D71_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D71 success-terminal sources {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
