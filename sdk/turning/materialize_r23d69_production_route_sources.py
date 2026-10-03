#!/usr/bin/env python3
"""Materialize the narrow R23D69 production-route successor sources.

The frozen R23D68 sources are exact inputs.  This tool applies the R23D69
identity projection and only the four preregistered integration repairs.  It
does not import a physics library, construct a model, or open a world.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]

INPUTS: dict[str, tuple[Path, str]] = {
    "supervisor": (
        ROOT / "sdk" / "run_qsdk_r23d68_supervisor.ps1",
        "ef3f6449ef6d6a57c6e06c64386b3b44f8ea15126574780204f18601c2b862ee",
    ),
    "godot_worker": (
        ROOT / "tests" / "test_sdk_qsdk_r23d68_godot_jolt_worker.gd",
        "4051e4a5ea2713958b5dc2687a4be6011129793fbb1a58a31070229b7f3709b0",
    ),
    "runtime": (
        ROOT / "sdk" / "turning" / "r23d68_production_route_runtime.py",
        "5fc42ae0edb600b6d5470e6182eaf9bc50dc5e70873a5364587da98f8cea0457",
    ),
    "evaluator": (
        ROOT
        / "sdk"
        / "turning"
        / "r23d68_production_route_three_engine_turning_evaluator.py",
        "712659214a1169c304fa77833fe53f7a6916b0cdf95e9c9c48473832bf314f67",
    ),
    "rapier": (
        ROOT / "sdk" / "adapters" / "rapier" / "src" / "qsdk_r23d68_turning_route.rs",
        "d5928c7939fb133f5426a6ef4047ddabfcf97a5fc9583f265c39ed0375cdab99",
    ),
    "rapier_binary": (
        ROOT
        / "sdk"
        / "adapters"
        / "rapier"
        / "src"
        / "bin"
        / "qsdk_r23d68_turning_route.rs",
        "8219d0c02f3ac427c72d402fd4b1a2b86c2182243f6e6cf68ff90198c75744f8",
    ),
    "mujoco": (
        ROOT
        / "sdk"
        / "adapters"
        / "mujoco"
        / "sporespore_mujoco_adapter"
        / "qsdk_r23d68_turning_route.py",
        "41ec60e8d7df461547437f587df9bab752b51cce99869c1d56b61a4a2dfea65c",
    ),
    "zero_world": (
        ROOT / "sdk" / "run_qsdk_r23d68_zero_world.ps1",
        "0b26a2b2d2f607e32be2470f17fa17b1114ca34bc79f9d6d6ee1b512ecfcacdf",
    ),
    "zero_world_audit": (
        ROOT / "tests" / "test_qsdk_r23d68_zero_world.ps1",
        "2a6ab6597138c26a5798e699fc70c9077654f4903765dc4fed0caaafea901c95",
    ),
    "evaluator_audit": (
        ROOT / "tests" / "test_qsdk_r23d68_evaluator.ps1",
        "027475bb8125ea63df4601dc228e9451cbabdacda1cd334284e0b085d080de0e",
    ),
    "implementation_materializer": (
        ROOT / "sdk" / "turning" / "materialize_r23d68_implementation.py",
        "364bc368446932bcbb0c16c2deade0501758383aa97011f10e27113c941eaf3c",
    ),
    "role_gate": (
        ROOT / "tests" / "test_qsdk_r23d68_campaign_roles.ps1",
        "f2966120985b28e62221514b64400d47799c10dedfa784d6b29c3e7c6b85e1ea",
    ),
    "attestation_materializer": (
        ROOT
        / "sdk"
        / "turning"
        / "materialize_r23d68_campaign_attestation_manifest.py",
        "36f3ffb13d5ca8386159f4ef5f1f32d38f54da63265ac2e2e3ee63ef6510995e",
    ),
}


class MaterializationError(RuntimeError):
    """The exact successor projection could not be composed."""


def _read_exact(key: str) -> str:
    path, expected = INPUTS[key]
    raw = path.read_bytes()
    observed = hashlib.sha256(raw).hexdigest()
    if observed != expected:
        raise MaterializationError(f"R23D69_SOURCE_DRIFT:{key}:{observed}")
    return raw.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D69_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:96]!r}"
        )
    return text.replace(old, new)


def _replace_section(text: str, start: str, end: str, replacement: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(f"R23D69_SECTION_START_INVALID:{start!r}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(f"R23D69_SECTION_END_INVALID:{end!r}")
    return text[:start_index] + replacement + text[end_index:]


def _project_identity(text: str) -> str:
    replacements = (
        (
            "QSDK-R23D68-PRODUCTION-PATH-CONFORMANCE-REPAIRED-",
            "QSDK-R23D69-COMPLETE-PRODUCTION-ROW-CONFORMANCE-REPAIRED-",
        ),
        (
            "r23d68_production_path_conformance_repaired_",
            "r23d69_complete_production_row_conformance_repaired_",
        ),
        (
            "production_path_conformance_repaired_three_engine_turning_validation",
            "complete_production_row_conformance_repaired_three_engine_turning_validation",
        ),
        ("compact_production_path_ghosts", "compact_production_row_ghosts"),
        ("production_path_ghosts", "complete_production_rows"),
        ("compact_trace_boundary_ghost", "compact_complete_production_row_ghost"),
        ("compact_process_projection_ghost", "compact_failure_projection_ghost"),
        ("compact production-path ghosts", "compact complete-production-row ghosts"),
        ("R23D68", "R23D69"),
        ("r23d68", "r23d69"),
        ("23_185", "23_187"),
        ("23185", "23187"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _rustfmt(text: str) -> str:
    result = subprocess.run(
        ["rustfmt", "--edition", "2024", "--emit", "stdout"],
        input=text,
        capture_output=True,
        check=False,
        encoding="utf-8",
    )
    if result.returncode != 0:
        raise MaterializationError("R23D69_RUSTFMT_FAILED:" + result.stderr.strip())
    return result.stdout.replace("\r\n", "\n")


def _supervisor() -> str:
    return _project_identity(_read_exact("supervisor"))


def _godot_worker() -> str:
    text = _project_identity(_read_exact("godot_worker"))
    text = text.replace(
        "r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json",
        "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
    )
    text = _replace_exact(
        text,
        '\ttrace_options["post_schedule_segment_id"] = "reference_continuation"\n',
        '\ttrace_options["post_schedule_segment_id"] = "reference_continuation"\n'
        '\ttrace_options["actuator_phase_observation_schema_version"] = (\n'
        '\t\tR23D69WaveGaitScript.SDK_GODOT_ACTUATOR_PHASE_OBSERVATION_SCHEMA\n'
        '\t)\n',
    )
    helper = '''static func _r23d69_project_complete_trace_row(
    source_row: Dictionary,
    semantic_step: int,
    cell: Dictionary,
) -> Dictionary:
    if int(source_row.get("semantic_step", -1)) != semantic_step:
        return _r23d69_failure("QSDK_R23D69_GJT_TRACE_STEP_INVALID")
    var row := source_row.duplicate(true)
    row["schema_version"] = R23D69_TRACE_ROW_SCHEMA
    row["campaign_id"] = R23D69_CAMPAIGN_ID
    row["gate_id"] = R23D69_GATE_ID
    row["stage_id"] = R23D69_STAGE_ID
    row["engine_id"] = R23D69_ENGINE_ID
    row["cell_id"] = String(cell["cell_id"])
    row["campaign_seed"] = R23D69_CAMPAIGN_SEED
    row["trace_step"] = semantic_step
    var observation := R23D69WaveGaitScript.validate_sdk_actuator_phase_observation(row)
    if not bool(observation.get("ok", false)):
        return _r23d69_failure(
            "QSDK_R23D69_GJT_ACTUATOR_PHASE_OBSERVATION_INVALID",
            observation,
        )
    return {
        "ok": true,
        "failure_code": "",
        "row": row,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }


'''
    helper = "\n".join(
        ("\t" * ((len(line) - len(line.lstrip(" "))) // 4)) + line.lstrip(" ")
        for line in helper.split("\n")
    )
    text = _replace_exact(
        text,
        "static func _r23d69_retain_trace(\n",
        helper + "static func _r23d69_retain_trace(\n",
    )
    old_projection = '''		var row: Dictionary = (rows[semantic_step] as Dictionary).duplicate(true)
		if int(row.get("semantic_step", -1)) != semantic_step:
			return _r23d69_failure("QSDK_R23D69_GJT_TRACE_STEP_INVALID")
		row["schema_version"] = R23D69_TRACE_ROW_SCHEMA
		row["campaign_id"] = R23D69_CAMPAIGN_ID
		row["gate_id"] = R23D69_GATE_ID
		row["stage_id"] = R23D69_STAGE_ID
		row["engine_id"] = R23D69_ENGINE_ID
		row["cell_id"] = String(cell["cell_id"])
		row["campaign_seed"] = R23D69_CAMPAIGN_SEED
		projected.append(row)'''
    new_projection = '''		var projection := _r23d69_project_complete_trace_row(
			rows[semantic_step] as Dictionary,
			semantic_step,
			cell,
		)
		if not bool(projection.get("ok", false)):
			return projection
		projected.append(projection["row"])'''
    text = _replace_exact(text, old_projection, new_projection)
    return text


def _runtime() -> str:
    text = _project_identity(_read_exact("runtime"))
    text = _replace_exact(
        text,
        '''INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.0008934948709793389,
    "fixture_yaw_rad": 0.0008208486251533031,
    "initial_linear_velocity_world_m_s": [
        -0.00023072096519172192,
        0.0,
        0.0011376081965863705,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.0007750610820949078,
        0.0017721238546073437,
        0.00013627856969833374,
    ],
    "gait_phase_offset_ticks": 0,
}''',
        '''INITIAL_PERTURBATION = {
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
}''',
    )
    text = text.replace(
        "r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json",
        "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
    )
    text = text.replace(
        "sha256:35debb172d4f4156b1ecc2363979e981a5216907f23ab7f478ff7c32d799e472",
        "sha256:6d538c8678951c92bce81e32ba29d076148ad640653d7a3164ad2388614a10b7",
    )
    text = _replace_exact(
        text,
        'distinction.get("fresh_seed_identity_occurrence_count_at_declaration_parent")',
        'distinction.get("first_candidate_token_occurrence_count_at_declaration_parent")',
    )
    conformance = '''    observed = value.get("observed_predecessor_integration_population", {})
    items = observed.get("items", [])
    _require(
        observed.get("complete_population_required") is True
        and observed.get("sampling_used") is False
        and observed.get("population_size") == 4
        and isinstance(items, list)
        and [item.get("failure_id") for item in items]
        == [
            "godot_actuator_phase_observation_missing",
            "rapier_post_schedule_segment_relabel",
            "mujoco_non_native_boolean_strict_json_failure",
            "mujoco_outer_failure_projection_lost_inner_counts",
        ]
        and observed.get("conformance_margin") == 0
        and observed.get("physical_world_count") == 0,
        "OBSERVED_INTEGRATION_POPULATION_INVALID",
    )
    ghost = value.get("compact_development_ghosts", {})
    _require(
        ghost.get("representative_semantic_steps")
        == [599, 600, 1799, 1800, 2399, 2400, 2991]
        and ghost.get("engine_count") == 3
        and ghost.get("representative_complete_row_count") == 21
        and ghost.get("failure_projection_case_count") == 2
        and ghost.get("inner_failure_receipt_preservation_required") is True
        and ghost.get("model_construction_count") == 0
        and ghost.get("world_attempt_count") == 0
        and ghost.get("world_build_count") == 0
        and ghost.get("physical_acceptance_authority") is False,
        "COMPACT_COMPLETE_ROW_GHOST_CONTRACT_INVALID",
    )
'''
    text = _replace_section(
        text,
        '    conformance = value.get("production_path_conformance_contract", {})',
        "\n\n\ndef load_declaration",
        conformance,
    )
    return text


def _evaluator() -> str:
    return _project_identity(_read_exact("evaluator"))


def _rapier() -> str:
    text = _project_identity(_read_exact("rapier"))
    text = text.replace(
        "r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json",
        "r23d68_production_path_conformance_repaired_three_engine_turning_preregistration_v1.json",
    )
    text = _replace_exact(
        text,
        "    R23D69_TRACE_TRANSPORT_ID, run_r23d69_rapier_kernel_preflight, run_r23d69_rapier_physical_core,\n",
        "    R23D69_TRACE_ROW_SCHEMA, R23D69_TRACE_TRANSPORT_ID,\n"
        "    r23d69_project_production_trace_row,\n"
        "    run_r23d69_rapier_kernel_preflight, run_r23d69_rapier_physical_core,\n",
    )
    ghost = '''pub fn run_qsdk_r23d69_rapier_complete_row_ghost() -> Result<Value, String> {
    let steps = [599_u64, 600, 1799, 1800, 2399, 2400, 2991];
    let expected = [
        "reference_warmup",
        "commanded_turn",
        "commanded_turn",
        "reference_recovery",
        "reference_recovery",
        "reference_continuation",
        "reference_continuation",
    ];
    let cell_id = exact_cell_id("reference_zero");
    let mut rows = Vec::new();
    for (semantic_step, expected_segment) in steps.into_iter().zip(expected) {
        let row = r23d69_project_production_trace_row(
            json!({"segment_id": "after_declared_schedule", "oracle_passed": true}),
            semantic_step,
            &cell_id,
        )?;
        if row["schema_version"] != R23D69_TRACE_ROW_SCHEMA
            || row["campaign_id"] != R23D69_CAMPAIGN_ID
            || row["gate_id"] != R23D69_GATE_ID
            || row["stage_id"] != R23D69_STAGE_ID
            || row["cell_id"] != cell_id
            || row["engine_id"] != "rapier_parry"
            || row["campaign_seed"] != R23D69_CAMPAIGN_SEED
            || row["semantic_step"] != semantic_step
            || row["trace_step"] != semantic_step
            || row["segment_id"] != expected_segment
        {
            return Err(format!("QSDK_R23D69_RAP_COMPLETE_ROW_INVALID:{semantic_step}"));
        }
        serde_json::to_string(&row)
            .map_err(|error| format!("QSDK_R23D69_RAP_STRICT_JSON_FAILED:{error}"))?;
        rows.push(row);
    }
    Ok(json!({
        "schema_version": "sporespore_qsdk_r23d69_rapier_complete_row_ghost_v1",
        "ok": true,
        "representative_complete_row_count": rows.len(),
        "representative_semantic_steps": steps,
        "same_projection_as_physical_route": true,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physical_acceptance_authority": false,
    }))
}

'''
    text = _replace_exact(text, "#[cfg(test)]\nmod tests {", ghost + "#[cfg(test)]\nmod tests {")
    text = _replace_exact(
        text,
        "    use super::*;\n",
        "    use super::*;\n\n"
        "    #[test]\n"
        "    fn compact_complete_rows_use_the_physical_projection() {\n"
        "        let receipt = run_qsdk_r23d69_rapier_complete_row_ghost().unwrap();\n"
        "        assert_eq!(receipt[\"representative_complete_row_count\"], 7);\n"
        "        assert_eq!(receipt[\"world_build_count\"], 0);\n"
        "    }\n",
    )
    return _rustfmt(text)


def _rapier_binary() -> str:
    return _rustfmt(_project_identity(_read_exact("rapier_binary")))


def _mujoco() -> str:
    text = _project_identity(_read_exact("mujoco"))
    helper = '''def _project_failure_terminal(
    error: BaseException,
    arguments: argparse.Namespace,
) -> dict[str, Any]:
    if isinstance(error, production._core.R23D3MujocoError):
        if isinstance(error.terminal_receipt, dict):
            terminal = copy.deepcopy(error.terminal_receipt)
        else:
            terminal = _failure_terminal(error.code, arguments)
        inner_failure_code = str(terminal.get("failure_code", error.code))
        terminal["failure_code"] = (
            f"QSDK_R23D69_MJC_WORKER_FAILURE:{type(error).__name__}:"
            f"{inner_failure_code}"
        )
        terminal.setdefault("model_construction_count", error.world_build_count)
        terminal.setdefault("world_attempt_count", error.world_attempt_count)
        terminal.setdefault("world_build_count", error.world_build_count)
    else:
        terminal = _failure_terminal(
            f"QSDK_R23D69_MJC_WORKER_FAILURE:{type(error).__name__}:{error}",
            arguments,
        )
    arm_offsets = dict(design.ARMS)
    selected = design.cell(ENGINE_ID, arguments.arm) if arguments.arm in arm_offsets else None
    terminal.update(
        schema_version=FAILURE_SCHEMA,
        campaign_id=CAMPAIGN_ID,
        gate_id=GATE_ID,
        question_class="finite_decision",
        stage_id=arguments.stage,
        cell_id=selected.cell_id if selected is not None else None,
        engine_id=ENGINE_ID,
        campaign_seed=arguments.campaign_seed,
        profile_id=arguments.profile,
        host_mapping_id=HOST_MAPPING_ID,
        arm_id=arguments.arm,
        turn_heading_offset_rad=arm_offsets.get(arguments.arm),
        source_commit=arguments.source_commit,
        claims=copy.deepcopy(FALSE_CLAIMS),
        physical_acceptance_authority=False,
    )
    terminal.setdefault("failure_stage", "before_world")
    terminal.setdefault("model_construction_count", 0)
    terminal.setdefault("world_attempt_count", 0)
    terminal.setdefault("world_build_count", 0)
    json.dumps(terminal, allow_nan=False)
    return terminal


'''
    text = _replace_exact(text, "def main(argv: Sequence[str] | None = None) -> int:\n", helper + "def main(argv: Sequence[str] | None = None) -> int:\n")
    replacement = '''    except (
        production.R23D65MujocoRouteError,
        production._core.R23D3MujocoError,
        design.DeclarationError,
        KeyError,
        OSError,
        TypeError,
        ValueError,
    ) as error:
        value = _project_failure_terminal(error, arguments)
        print(
            "QSDK_R23D69_MUJOCO_FAILURE "
            + json.dumps(value, allow_nan=False, separators=(",", ":"), sort_keys=True)
        )
        return 1
'''
    text = _replace_section(
        text,
        "    except (\n        production.R23D65MujocoRouteError,",
        "\n\n\nif __name__ == \"__main__\":",
        replacement,
    )
    return text


def _zero_world() -> str:
    return _project_identity(_read_exact("zero_world"))


def _zero_world_audit() -> str:
    return _project_identity(_read_exact("zero_world_audit"))


def _evaluator_audit() -> str:
    return _project_identity(_read_exact("evaluator_audit"))


def _implementation_materializer() -> str:
    text = _project_identity(_read_exact("implementation_materializer"))
    text = text.replace(
        '    "tests/test_sdk_qsdk_r23d69_trace_boundary_ghost.gd",\n',
        '    "tests/test_sdk_qsdk_r23d69_complete_row_ghost.gd",\n'
        '    "tests/test_qsdk_r23d69_mujoco_complete_row_ghost.py",\n',
    )
    text = _replace_exact(
        text,
        '            "compact_complete_production_row_ghost_count": 1,\n'
        '            "compact_failure_projection_ghost_count": 1,\n',
        '            "compact_complete_production_row_ghost_count": 3,\n'
        '            "representative_complete_row_count": 21,\n'
        '            "compact_failure_projection_ghost_count": 2,\n',
    )
    return text


def _role_gate() -> str:
    return _replace_exact(
        _project_identity(_read_exact("role_gate")),
        "-eq 212",
        "-eq 214",
        count=3,
    )


def _attestation_materializer() -> str:
    text = _project_identity(_read_exact("attestation_materializer"))
    return _replace_exact(
        text,
        'and len(value["dependency_digests"]) == 212',
        'and len(value["dependency_digests"]) == 214',
    )


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk" / "run_qsdk_r23d69_supervisor.ps1", _supervisor),
    (ROOT / "tests" / "test_sdk_qsdk_r23d69_godot_jolt_worker.gd", _godot_worker),
    (ROOT / "sdk" / "turning" / "r23d69_production_route_runtime.py", _runtime),
    (
        ROOT / "sdk" / "turning" / "r23d69_production_route_three_engine_turning_evaluator.py",
        _evaluator,
    ),
    (ROOT / "sdk" / "adapters" / "rapier" / "src" / "qsdk_r23d69_turning_route.rs", _rapier),
    (
        ROOT / "sdk" / "adapters" / "rapier" / "src" / "bin" / "qsdk_r23d69_turning_route.rs",
        _rapier_binary,
    ),
    (
        ROOT
        / "sdk"
        / "adapters"
        / "mujoco"
        / "sporespore_mujoco_adapter"
        / "qsdk_r23d69_turning_route.py",
        _mujoco,
    ),
    (ROOT / "sdk" / "run_qsdk_r23d69_zero_world.ps1", _zero_world),
    (ROOT / "tests" / "test_qsdk_r23d69_zero_world.ps1", _zero_world_audit),
    (ROOT / "tests" / "test_qsdk_r23d69_evaluator.ps1", _evaluator_audit),
    (ROOT / "sdk" / "turning" / "materialize_r23d69_implementation.py", _implementation_materializer),
    (ROOT / "tests" / "test_qsdk_r23d69_campaign_roles.ps1", _role_gate),
    (
        ROOT / "sdk" / "turning" / "materialize_r23d69_campaign_attestation_manifest.py",
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
            path.write_bytes(raw)
        elif not path.is_file() or path.read_bytes() != raw:
            raise MaterializationError(f"R23D69_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D69 production route sources {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
