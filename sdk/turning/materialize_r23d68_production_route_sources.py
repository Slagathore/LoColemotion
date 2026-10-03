#!/usr/bin/env python3
"""Materialize the large R23D68 production entry points deterministically.

R23D68 inherits the frozen R23D67 production route and changes only campaign
identity, its prospective seed, and the two declared integration seams.  This
tool makes that narrow relationship executable: it verifies the exact R23D67
source bytes, performs the identity projection, applies the two seam repairs,
and either writes or checks the resulting R23D68 sources.

The materializer performs source transformation only.  It does not import a
physics library, construct a model, or open a world.
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]

SUPERVISOR_SOURCE = ROOT / "sdk" / "run_qsdk_r23d67_supervisor.ps1"
SUPERVISOR_OUTPUT = ROOT / "sdk" / "run_qsdk_r23d68_supervisor.ps1"
SUPERVISOR_SOURCE_SHA256 = (
    "ce525d797820e03c8c6fa7e83e6ef41ba54740336ce60e9073e1a988287f6f6f"
)

GODOT_WORKER_SOURCE = (
    ROOT / "tests" / "test_sdk_qsdk_r23d67_godot_jolt_worker.gd"
)
GODOT_WORKER_OUTPUT = (
    ROOT / "tests" / "test_sdk_qsdk_r23d68_godot_jolt_worker.gd"
)
GODOT_WORKER_SOURCE_SHA256 = (
    "d124016f3cc05f091ffc4c00271e79c092b8b4e00c5971e85c30e12f64a00cc3"
)

RUNTIME_SOURCE = ROOT / "sdk" / "turning" / "r23d67_production_route_runtime.py"
RUNTIME_OUTPUT = ROOT / "sdk" / "turning" / "r23d68_production_route_runtime.py"
RUNTIME_SOURCE_SHA256 = (
    "35c114bffb228e2501d9b750629e504f4c093da3e9a346fe1290ffc2f449a0f5"
)

EVALUATOR_SOURCE = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d67_production_route_three_engine_turning_evaluator.py"
)
EVALUATOR_OUTPUT = (
    ROOT
    / "sdk"
    / "turning"
    / "r23d68_production_route_three_engine_turning_evaluator.py"
)
EVALUATOR_SOURCE_SHA256 = (
    "c1fff37c804569bc4f79dd6292be5366886d30fcc9c73f938e6e6ab21e190a5f"
)

RAPIER_SOURCE = (
    ROOT / "sdk" / "adapters" / "rapier" / "src" / "qsdk_r23d67_turning_route.rs"
)
RAPIER_OUTPUT = (
    ROOT / "sdk" / "adapters" / "rapier" / "src" / "qsdk_r23d68_turning_route.rs"
)
RAPIER_SOURCE_SHA256 = (
    "3096a7f123dc16a8750349a5cc5ca387fd9e8a2269ecacb6cc449309517ed116"
)

RAPIER_BINARY_SOURCE = (
    ROOT
    / "sdk"
    / "adapters"
    / "rapier"
    / "src"
    / "bin"
    / "qsdk_r23d67_turning_route.rs"
)
RAPIER_BINARY_OUTPUT = (
    ROOT
    / "sdk"
    / "adapters"
    / "rapier"
    / "src"
    / "bin"
    / "qsdk_r23d68_turning_route.rs"
)
RAPIER_BINARY_SOURCE_SHA256 = (
    "dc53da5b28f10dd8dd8d2627ea2761a40261fbf3ada081486595df01aa81fc25"
)

MUJOCO_SOURCE = (
    ROOT
    / "sdk"
    / "adapters"
    / "mujoco"
    / "sporespore_mujoco_adapter"
    / "qsdk_r23d67_turning_route.py"
)
MUJOCO_OUTPUT = (
    ROOT
    / "sdk"
    / "adapters"
    / "mujoco"
    / "sporespore_mujoco_adapter"
    / "qsdk_r23d68_turning_route.py"
)
MUJOCO_SOURCE_SHA256 = (
    "5592864cea92ecfa95a6b9d314e9d124037a5a31a1116e688ae8b2833c5a917c"
)

ZERO_WORLD_SOURCE = ROOT / "sdk" / "run_qsdk_r23d67_zero_world.ps1"
ZERO_WORLD_OUTPUT = ROOT / "sdk" / "run_qsdk_r23d68_zero_world.ps1"
ZERO_WORLD_SOURCE_SHA256 = (
    "f422e96bdfa05a60f7cb98ab9e876d544b4ef7e37e0f16cd94567dfcb9ceeeec"
)

ZERO_WORLD_AUDIT_SOURCE = ROOT / "tests" / "test_qsdk_r23d67_zero_world.ps1"
ZERO_WORLD_AUDIT_OUTPUT = ROOT / "tests" / "test_qsdk_r23d68_zero_world.ps1"
ZERO_WORLD_AUDIT_SOURCE_SHA256 = (
    "8f11adf9bb58beeb7edc2bf6ccd5bc128dd6c83f87acd0a440bf92477a5e356e"
)

EVALUATOR_AUDIT_SOURCE = ROOT / "tests" / "test_qsdk_r23d67_evaluator.ps1"
EVALUATOR_AUDIT_OUTPUT = ROOT / "tests" / "test_qsdk_r23d68_evaluator.ps1"
EVALUATOR_AUDIT_SOURCE_SHA256 = (
    "a43448ab9674bdf0b5f9ae87bf2126116e10cf2134fec3465ba8777047de9237"
)

IMPLEMENTATION_MATERIALIZER_SOURCE = (
    ROOT / "sdk" / "turning" / "materialize_r23d67_implementation.py"
)
IMPLEMENTATION_MATERIALIZER_OUTPUT = (
    ROOT / "sdk" / "turning" / "materialize_r23d68_implementation.py"
)
IMPLEMENTATION_MATERIALIZER_SOURCE_SHA256 = (
    "91b0bbb1a67b33a9f09c676806803bf6b58e76f318bf7af0a21ff1e10c3daed9"
)

ROLE_GATE_SOURCE = ROOT / "tests" / "test_qsdk_r23d67_campaign_roles.ps1"
ROLE_GATE_OUTPUT = ROOT / "tests" / "test_qsdk_r23d68_campaign_roles.ps1"
ROLE_GATE_SOURCE_SHA256 = (
    "63dc46eec7c52e0892ae9ddcaf9267ab31d18ff4bc648be01f31e41ba843ac3a"
)

ATTESTATION_MATERIALIZER_SOURCE = (
    ROOT
    / "sdk"
    / "turning"
    / "materialize_r23d67_campaign_attestation_manifest.py"
)
ATTESTATION_MATERIALIZER_OUTPUT = (
    ROOT
    / "sdk"
    / "turning"
    / "materialize_r23d68_campaign_attestation_manifest.py"
)
ATTESTATION_MATERIALIZER_SOURCE_SHA256 = (
    "151a69be901e2cae5a3904dbcf6ab7f8ddc52228b387b6f293e0703d3e76e2ad"
)


class MaterializationError(RuntimeError):
    """The exact successor projection could not be constructed."""


def _sha256(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _read_exact(path: Path, expected_sha256: str) -> str:
    raw = path.read_bytes()
    observed = _sha256(raw)
    if observed != expected_sha256:
        raise MaterializationError(
            f"R23D68_SOURCE_DRIFT:{path.relative_to(ROOT).as_posix()}:"
            f"{observed}"
        )
    return raw.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D68_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:80]!r}"
        )
    return text.replace(old, new)


def _project_identity(text: str) -> str:
    replacements = (
        (
            "QSDK-R23D67-AUTHORIZATION-SCHEMA-REPAIRED-",
            "QSDK-R23D68-PRODUCTION-PATH-CONFORMANCE-REPAIRED-",
        ),
        (
            "r23d67_authorization_schema_repaired_",
            "r23d68_production_path_conformance_repaired_",
        ),
        (
            "authorization_schema_repaired_three_engine_turning_validation",
            "production_path_conformance_repaired_three_engine_turning_validation",
        ),
        ("R23D67", "R23D68"),
        ("r23d67", "r23d68"),
        ("23_181", "23_185"),
        ("23181", "23185"),
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
        raise MaterializationError(
            "R23D68_RUSTFMT_FAILED:" + result.stderr.strip()
        )
    return result.stdout.replace("\r\n", "\n")


def _supervisor() -> str:
    text = _project_identity(
        _read_exact(SUPERVISOR_SOURCE, SUPERVISOR_SOURCE_SHA256)
    )
    text = _replace_exact(
        text,
        '. (Join-Path $sdkRoot "locomotion_terminal_execution_projection.ps1")\n'
        '. (Join-Path $sdkRoot "three_engine_authorization_receipt.ps1")',
        '. (Join-Path $sdkRoot "locomotion_terminal_execution_projection.ps1")\n'
        '. (Join-Path $sdkRoot "process_result_projection.ps1")\n'
        '. (Join-Path $sdkRoot "three_engine_authorization_receipt.ps1")',
    )
    old_projection = '''    $godotProcess = $EngineId -ceq "godot_jolt"
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        process = [ordered]@{
            exit_code = [int]$process.exit_code
            host_exit_code = if ($godotProcess -and $process.Contains("host_exit_code")) {
                [int]$process.host_exit_code
            } else { [int]$process.exit_code }
            timed_out = [bool]$process.timed_out
            supervisor_terminated = if ($godotProcess -and $process.Contains("supervisor_terminated")) {
                [bool]$process.supervisor_terminated
            } else { $false }
            termination_protocol_valid = if ($godotProcess -and $process.Contains("termination_protocol_valid")) {
                [bool]$process.termination_protocol_valid
            } else { -not $godotProcess }
            started_utc = [string]$process.started_utc
            completed_utc = [string]$process.completed_utc
            stdout_cas = $streamCas.stdout
            stderr_cas = $streamCas.stderr
        }
'''
    new_projection = '''    $godotProcess = $EngineId -ceq "godot_jolt"
    $processProjection = Get-SporeSporeProcessExecutionProjection `
        -ProcessResult $process -GodotProcess $godotProcess
    return [ordered]@{
        cell_id = $cellId
        engine_id = $EngineId
        campaign_seed = $campaignSeed
        profile_id = $profileId
        arm_id = $ArmId
        turn_heading_offset_rad = [double]$armOffsets[$ArmId]
        process = [ordered]@{
            exit_code = [int]$processProjection.exit_code
            host_exit_code = [int]$processProjection.host_exit_code
            timed_out = [bool]$processProjection.timed_out
            supervisor_terminated = [bool]$processProjection.supervisor_terminated
            termination_protocol_valid = [bool]$processProjection.termination_protocol_valid
            started_utc = [string]$processProjection.started_utc
            completed_utc = [string]$processProjection.completed_utc
            stdout_cas = $streamCas.stdout
            stderr_cas = $streamCas.stderr
        }
'''
    text = _replace_exact(text, old_projection, new_projection)
    if '.Contains("host_exit_code")' in text:
        raise MaterializationError("R23D68_SUPERVISOR_LEGACY_PROCESS_PROJECTION_REMAINS")
    return text


def _godot_worker() -> str:
    text = _project_identity(
        _read_exact(GODOT_WORKER_SOURCE, GODOT_WORKER_SOURCE_SHA256)
    )
    text = _replace_exact(
        text,
        'const R23D68_INHERITED_BEHAVIOR_PATH := "res://sdk/turning/'
        'r23d66_production_route_three_engine_turning_validation_'
        'preregistration_v1.json"\n',
        'const R23D68_INHERITED_BEHAVIOR_PATH := "res://sdk/turning/'
        'r23d66_production_route_three_engine_turning_validation_'
        'preregistration_v1.json"\n'
        'const R23D68_IMMEDIATE_BASE_PATH := "res://sdk/turning/'
        'r23d67_authorization_schema_repaired_three_engine_turning_'
        'preregistration_v1.json"\n',
    )
    text = _replace_exact(
        text,
        '"prospective_declaration_complete_implementation_and_complete_"\n'
        '\t\t\t\t+ "authorization_ghost_pending_physical_not_authorized"',
        '"prospective_declaration_complete_compact_production_path_ghosts_"\n'
        '\t\t\t\t+ "and_implementation_pending_physical_not_authorized"',
    )
    text = _replace_exact(
        text,
        '\t\tand not bool(declaration.get("claims", {}).get("physical_campaign_opened", true))\n',
        '\t\tand not bool(declaration.get("claims", {}).get("physical_campaign_opened", true))\n'
        '\t\tand (\n'
        '\t\t\tString(declaration.get("inherited_behavior_contract", {}).get("immediate_base_path", ""))\n'
        '\t\t\t== R23D68_IMMEDIATE_BASE_PATH.trim_prefix("res://")\n'
        '\t\t)\n'
        '\t\tand (\n'
        '\t\t\tString(declaration.get("inherited_behavior_contract", {}).get("immediate_base_raw_sha256", ""))\n'
        '\t\t\t== R23D68BaseWorkerScript._raw_file_sha256(R23D68_IMMEDIATE_BASE_PATH)\n'
        '\t\t)\n',
    )
    text = _replace_exact(
        text,
        'String(declaration.get("inherited_behavior_contract", {}).get("base_raw_sha256", ""))',
        'String(declaration.get("inherited_behavior_contract", {}).get("root_base_raw_sha256", ""))',
    )
    text = _replace_exact(
        text,
        '\ttrace_options["trace_row_schema_version"] = R23D48_TRACE_ROW_SCHEMA\n'
        '\tvar trace_result := R23D68WaveGaitScript.compile_sdk_physical_trace_options(trace_options)',
        '\ttrace_options["trace_row_schema_version"] = R23D48_TRACE_ROW_SCHEMA\n'
        '\ttrace_options["post_schedule_segment_id"] = "reference_continuation"\n'
        '\tvar trace_result := R23D68WaveGaitScript.compile_sdk_physical_trace_options(trace_options)',
    )
    return text


def _runtime() -> str:
    text = _project_identity(_read_exact(RUNTIME_SOURCE, RUNTIME_SOURCE_SHA256))
    text = _replace_exact(
        text,
        '    "prospective_declaration_complete_implementation_and_complete_"\n'
        '    "authorization_ghost_pending_physical_not_authorized"',
        '    "prospective_declaration_complete_compact_production_path_ghosts_"\n'
        '    "and_implementation_pending_physical_not_authorized"',
    )
    old_perturbation = '''INITIAL_PERTURBATION = {
    "campaign_seed": CAMPAIGN_SEED,
    "fixture_vertical_clearance_m": 0.00023330721887759864,
    "fixture_yaw_rad": -0.0005075503140687943,
    "initial_linear_velocity_world_m_s": [
        -0.003907699137926102,
        0.0,
        0.0004415358416736126,
    ],
    "initial_torso_angular_velocity_world_rad_s": [
        0.0012565504293888807,
        0.002035621553659439,
        0.00043795653618872166,
    ],
    "gait_phase_offset_ticks": 3,
}'''
    new_perturbation = '''INITIAL_PERTURBATION = {
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
}'''
    text = _replace_exact(text, old_perturbation, new_perturbation)
    old_inheritance = '''    inherited = value.get("inherited_behavior_contract", {})
    _require(
        inherited.get("base_path")
        == "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json",
        "BASE_PATH_INVALID",
    )
    _require(
        inherited.get("base_raw_sha256")
        == "sha256:d625d911c6f582a1bccd5bf6b8fd019e93befd7893dc0e6ededbd5870c32571a",
        "BASE_DIGEST_INVALID",
    )
    _require(
        raw_sha256(base.DECLARATION_PATH) == inherited.get("base_raw_sha256"),
        "LIVE_BASE_DIGEST_INVALID",
    )'''
    new_inheritance = '''    inherited = value.get("inherited_behavior_contract", {})
    immediate_base_path = (
        REPO_ROOT
        / "sdk"
        / "turning"
        / "r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json"
    )
    _require(
        inherited.get("immediate_base_path")
        == "sdk/turning/r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json",
        "IMMEDIATE_BASE_PATH_INVALID",
    )
    _require(
        inherited.get("immediate_base_raw_sha256")
        == "sha256:35debb172d4f4156b1ecc2363979e981a5216907f23ab7f478ff7c32d799e472",
        "IMMEDIATE_BASE_DIGEST_INVALID",
    )
    _require(
        raw_sha256(immediate_base_path) == inherited.get("immediate_base_raw_sha256"),
        "LIVE_IMMEDIATE_BASE_DIGEST_INVALID",
    )
    _require(
        inherited.get("root_base_path")
        == "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json",
        "ROOT_BASE_PATH_INVALID",
    )
    _require(
        inherited.get("root_base_raw_sha256")
        == "sha256:d625d911c6f582a1bccd5bf6b8fd019e93befd7893dc0e6ededbd5870c32571a",
        "ROOT_BASE_DIGEST_INVALID",
    )
    _require(
        raw_sha256(base.DECLARATION_PATH) == inherited.get("root_base_raw_sha256"),
        "LIVE_ROOT_BASE_DIGEST_INVALID",
    )'''
    text = _replace_exact(text, old_inheritance, new_inheritance)
    old_repair = '''    repair = value.get("authorization_schema_repair", {})
    _require(
        repair.get("complete_producer_population_size") == 3
        and repair.get("positive_producer_count") == 3
        and repair.get("negative_control_count") == 117
        and repair.get("required_common_positive_field") == "ok"
        and repair.get("required_common_positive_type") == "boolean"
        and repair.get("required_common_positive_value") is True
        and repair.get("physical_execution_count") == 0,
        "AUTHORIZATION_REPAIR_INVALID",
    )'''
    new_repair = '''    conformance = value.get("production_path_conformance_contract", {})
    trace_repair = conformance.get("trace_vocabulary_repair", {})
    process_repair = conformance.get("process_projection_repair", {})
    _require(
        trace_repair.get("predecessor_producer_segment_id")
        == "after_declared_schedule"
        and trace_repair.get("frozen_evaluator_segment_id")
        == "reference_continuation"
        and trace_repair.get("required_successor_production_segment_id")
        == "reference_continuation"
        and trace_repair.get("affected_first_semantic_step") == 2400
        and trace_repair.get("affected_last_semantic_step") == 2991
        and trace_repair.get("affected_row_count") == 592,
        "TRACE_CONFORMANCE_REPAIR_INVALID",
    )
    _require(
        process_repair.get("observed_actual_process_type")
        == "System.Management.Automation.PSCustomObject"
        and process_repair.get("observed_invalid_method") == "Contains"
        and process_repair.get("required_property_population")
        == [
            "host_exit_code",
            "supervisor_terminated",
            "termination_protocol_valid",
        ]
        and process_repair.get("supported_shape_population")
        == [
            "System.Collections.IDictionary",
            "System.Management.Automation.PSCustomObject",
        ],
        "PROCESS_CONFORMANCE_REPAIR_INVALID",
    )
    _require(
        conformance.get("conformance_margin") == 0
        and conformance.get("complete_population_required") is True
        and conformance.get("sampling_used") is False
        and conformance.get("physical_world_count") == 0,
        "PRODUCTION_PATH_CONFORMANCE_INVALID",
    )'''
    text = _replace_exact(text, old_repair, new_repair)
    text = _replace_exact(
        text,
        '        "inherited_behavior_contract_raw_sha256": raw_sha256(base.DECLARATION_PATH),',
        '        "root_behavior_contract_raw_sha256": raw_sha256(base.DECLARATION_PATH),\n'
        '        "immediate_base_contract_raw_sha256": raw_sha256(\n'
        '            REPO_ROOT\n'
        '            / "sdk"\n'
        '            / "turning"\n'
        '            / "r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json"\n'
        '        ),',
    )
    return text


def _evaluator() -> str:
    return _project_identity(
        _read_exact(EVALUATOR_SOURCE, EVALUATOR_SOURCE_SHA256)
    )


def _rapier() -> str:
    text = _project_identity(_read_exact(RAPIER_SOURCE, RAPIER_SOURCE_SHA256))
    text = _replace_exact(
        text,
        'const INHERITED_BEHAVIOR_PATH: &str =\n'
        '    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json";',
        'const INHERITED_BEHAVIOR_PATH: &str =\n'
        '    "sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json";\n'
        'const IMMEDIATE_BASE_RAW: &str = include_str!(\n'
        '    "../../../turning/r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json"\n'
        ');\n'
        'const IMMEDIATE_BASE_PATH: &str =\n'
        '    "sdk/turning/r23d67_authorization_schema_repaired_three_engine_turning_preregistration_v1.json";',
    )
    text = _replace_exact(
        text,
        '        && declaration["inherited_behavior_contract"]["base_path"] == INHERITED_BEHAVIOR_PATH\n'
        '        && declaration["inherited_behavior_contract"]["base_raw_sha256"]\n'
        '            == raw_sha256(&inherited_raw)',
        '        && declaration["inherited_behavior_contract"]["immediate_base_path"]\n'
        '            == IMMEDIATE_BASE_PATH\n'
        '        && declaration["inherited_behavior_contract"]["immediate_base_raw_sha256"]\n'
        '            == raw_sha256(IMMEDIATE_BASE_RAW.as_bytes())\n'
        '        && declaration["inherited_behavior_contract"]["root_base_path"]\n'
        '            == INHERITED_BEHAVIOR_PATH\n'
        '        && declaration["inherited_behavior_contract"]["root_base_raw_sha256"]\n'
        '            == raw_sha256(&inherited_raw)',
    )
    return _rustfmt(text)


def _rapier_binary() -> str:
    return _rustfmt(
        _project_identity(
            _read_exact(RAPIER_BINARY_SOURCE, RAPIER_BINARY_SOURCE_SHA256)
        )
    )


def _mujoco() -> str:
    return _project_identity(_read_exact(MUJOCO_SOURCE, MUJOCO_SOURCE_SHA256))


def _zero_world() -> str:
    text = _project_identity(
        _read_exact(ZERO_WORLD_SOURCE, ZERO_WORLD_SOURCE_SHA256)
    )
    text = _replace_exact(
        text,
        '$materializer = Join-Path $turningRoot "materialize_r23d68_implementation.py"\n',
        '$materializer = Join-Path $turningRoot "materialize_r23d68_implementation.py"\n'
        '$sourceMaterializer = Join-Path $turningRoot (\n'
        '    "materialize_r23d68_production_route_sources.py"\n'
        ')\n',
    )
    text = _replace_exact(
        text,
        '$evaluatorGate = Join-Path $repoRoot "tests\\test_qsdk_r23d68_evaluator.ps1"\n',
        '$evaluatorGate = Join-Path $repoRoot "tests\\test_qsdk_r23d68_evaluator.ps1"\n'
        '$productionGhostGate = Join-Path $repoRoot (\n'
        '    "tests\\test_qsdk_r23d68_production_path_ghosts.ps1"\n'
        ')\n',
    )
    text = _replace_exact(
        text,
        '    $evaluatorGate,\n    $operationLockGate,',
        '    $evaluatorGate,\n    $productionGhostGate,\n    $operationLockGate,',
    )
    text = _replace_exact(
        text,
        '# Fast route and authorization checks intentionally run first. The full-volume\n'
        '# evaluator is a qualification cost, not a development loop or a way to find\n'
        '# ordinary worker-integration mistakes.\n',
        '# The compact production-path ghosts run before the full-volume evaluator.\n'
        '# They prove both repaired code seams execute without claiming behavior.\n'
        '$null = Invoke-R23D68PowerShellGate $productionGhostGate (\n'
        '    "[turning/3e] PASS R23D68 compact production-path ghosts"\n'
        ')\n\n'
        '# Full-volume evaluation remains qualification work, not a development loop.\n',
    )
    text = _replace_exact(
        text,
        '"[turning/3e] PASS R23D68 finite-decision declaration"',
        '"[turning/3e] PASS R23D68 prospective declaration"',
    )
    text = _replace_exact(
        text,
        '    $materializer,\n    $implementationPath,',
        '    $materializer,\n    $sourceMaterializer,\n    $implementationPath,',
    )
    text = _replace_exact(
        text,
        '$materialization = Invoke-R23D68Process -FileName $pythonHost -Arguments @(\n'
        '    $materializer, "check"\n'
        ') -WorkingDirectory $repoRoot',
        '$sourceMaterialization = Invoke-R23D68Process -FileName $pythonHost -Arguments @(\n'
        '    $sourceMaterializer, "check"\n'
        ') -WorkingDirectory $repoRoot\n'
        'Assert-R23D68ZeroWorld (\n'
        '    [int]$sourceMaterialization.exit_code -eq 0 -and\n'
        '    [string]$sourceMaterialization.text -cmatch\n'
        '        "R23D68 production route sources check"\n'
        ') "production-route source materialization drifted: $($sourceMaterialization.text)"\n\n'
        '$materialization = Invoke-R23D68Process -FileName $pythonHost -Arguments @(\n'
        '    $materializer, "check"\n'
        ') -WorkingDirectory $repoRoot',
    )
    text = _replace_exact(
        text,
        '    common_authorization_receipt_contract_gate_passed = $true\n'
        '    full_matrix_and_schedule_evaluator_preflight_passed = $true',
        '    production_route_source_materialization_passed = $true\n'
        '    common_authorization_receipt_contract_gate_passed = $true\n'
        '    compact_trace_boundary_ghost_passed = $true\n'
        '    compact_process_projection_ghost_passed = $true\n'
        '    compact_ghost_model_construction_count = 0\n'
        '    compact_ghost_world_attempt_count = 0\n'
        '    compact_ghost_world_build_count = 0\n'
        '    full_matrix_and_schedule_evaluator_preflight_passed = $true',
    )
    return text


def _zero_world_audit() -> str:
    text = _project_identity(
        _read_exact(ZERO_WORLD_AUDIT_SOURCE, ZERO_WORLD_AUDIT_SOURCE_SHA256)
    )
    text = _replace_exact(
        text,
        '    [bool]$receipt.common_authorization_receipt_contract_gate_passed -and\n'
        '    [int]$receipt.evaluator_outcome_control_count -eq 4 -and',
        '    [bool]$receipt.production_route_source_materialization_passed -and\n'
        '    [bool]$receipt.common_authorization_receipt_contract_gate_passed -and\n'
        '    [bool]$receipt.compact_trace_boundary_ghost_passed -and\n'
        '    [bool]$receipt.compact_process_projection_ghost_passed -and\n'
        '    [int]$receipt.compact_ghost_model_construction_count -eq 0 -and\n'
        '    [int]$receipt.compact_ghost_world_attempt_count -eq 0 -and\n'
        '    [int]$receipt.compact_ghost_world_build_count -eq 0 -and\n'
        '    [int]$receipt.evaluator_outcome_control_count -eq 4 -and',
    )
    text = _replace_exact(
        text,
        '"workers=3 authorization_ghost=9/9 missing_ok=3/3 " +',
        '"ghosts=2/2 workers=3 authorization_ghost=9/9 missing_ok=3/3 " +',
    )
    return text


def _evaluator_audit() -> str:
    return _project_identity(
        _read_exact(EVALUATOR_AUDIT_SOURCE, EVALUATOR_AUDIT_SOURCE_SHA256)
    )


def _implementation_materializer() -> str:
    text = _project_identity(
        _read_exact(
            IMPLEMENTATION_MATERIALIZER_SOURCE,
            IMPLEMENTATION_MATERIALIZER_SOURCE_SHA256,
        )
    )
    text = _replace_exact(
        text,
        '    "sdk/turning/materialize_r23d68_implementation.py",\n',
        '    "sdk/turning/materialize_r23d68_implementation.py",\n'
        '    "sdk/turning/materialize_r23d68_production_route_sources.py",\n'
        '    "sdk/process_result_projection.ps1",\n'
        '    "tests/test_qsdk_r23d68_production_path_ghosts.ps1",\n'
        '    "tests/test_sdk_qsdk_r23d68_trace_boundary_ghost.gd",\n',
    )
    text = _replace_exact(
        text,
        '            "full_volume_evaluator_outcome_control_count": 4,\n'
        '            "passed": True,',
        '            "full_volume_evaluator_outcome_control_count": 4,\n'
        '            "compact_trace_boundary_ghost_count": 1,\n'
        '            "compact_process_projection_ghost_count": 1,\n'
        '            "compact_ghost_model_construction_count": 0,\n'
        '            "compact_ghost_world_attempt_count": 0,\n'
        '            "compact_ghost_world_build_count": 0,\n'
        '            "passed": True,',
    )
    text = _replace_exact(
        text,
        '            "complete_authorization_ghost_passed": True,\n'
        '            "all_three_positive_worker_receipts_pass_common_validator": True,',
        '            "complete_authorization_ghost_passed": True,\n'
        '            "compact_production_path_ghosts_passed": True,\n'
        '            "trace_vocabulary_conforms_with_zero_margin": True,\n'
        '            "process_projection_conforms_for_complete_declared_shape_population": True,\n'
        '            "all_three_positive_worker_receipts_pass_common_validator": True,',
    )
    return text


def _role_gate() -> str:
    text = _project_identity(_read_exact(ROLE_GATE_SOURCE, ROLE_GATE_SOURCE_SHA256))
    return _replace_exact(text, "206", "212", count=3)


def _attestation_materializer() -> str:
    text = _project_identity(
        _read_exact(
            ATTESTATION_MATERIALIZER_SOURCE,
            ATTESTATION_MATERIALIZER_SOURCE_SHA256,
        )
    )
    return _replace_exact(text, "206", "212")


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (SUPERVISOR_OUTPUT, _supervisor),
    (GODOT_WORKER_OUTPUT, _godot_worker),
    (RUNTIME_OUTPUT, _runtime),
    (EVALUATOR_OUTPUT, _evaluator),
    (RAPIER_OUTPUT, _rapier),
    (RAPIER_BINARY_OUTPUT, _rapier_binary),
    (MUJOCO_OUTPUT, _mujoco),
    (ZERO_WORLD_OUTPUT, _zero_world),
    (ZERO_WORLD_AUDIT_OUTPUT, _zero_world_audit),
    (EVALUATOR_AUDIT_OUTPUT, _evaluator_audit),
    (IMPLEMENTATION_MATERIALIZER_OUTPUT, _implementation_materializer),
    (ROLE_GATE_OUTPUT, _role_gate),
    (ATTESTATION_MATERIALIZER_OUTPUT, _attestation_materializer),
)


def _arguments(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=("write", "check"))
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _arguments(sys.argv[1:] if argv is None else argv)
    results: list[str] = []
    for path, compose in OUTPUTS:
        raw = compose().encode("utf-8")
        relative = path.relative_to(ROOT).as_posix()
        if arguments.command == "write":
            path.write_bytes(raw)
        elif not path.is_file() or path.read_bytes() != raw:
            raise MaterializationError(f"R23D68_OUTPUT_DRIFT:{relative}")
        results.append(f"{relative}=sha256:{_sha256(raw)}")
    print(
        "[turning/3e] R23D68 production route sources "
        + arguments.command
        + ": "
        + " ".join(results)
        + " models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
