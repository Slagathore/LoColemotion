#!/usr/bin/env python3
"""Materialize the exact additive R23D78 native campaign bindings.

The clean-pushed R23D78 declaration commit is the immutable source parent.
This tool projects the already exercised R23D76 production routes to the fresh
R23D78 identity and fixture, binds the R23D77 existing-file CAS verifier, and
adds one Rapier route alongside (never over) the frozen R23D76 route.  It
imports no physics library and opens no model or world.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import subprocess
import sys
from typing import Callable, Sequence


ROOT = Path(__file__).resolve().parents[2]
SOURCE_COMMIT = "2e09180dc99bd99934a9073ff30bee347121367c"


class MaterializationError(RuntimeError):
    """The exact R23D78 source projection could not be composed."""


def _source(relative: str) -> str:
    process = subprocess.run(
        ["git", "-C", str(ROOT), "show", f"{SOURCE_COMMIT}:{relative}"],
        capture_output=True,
        check=False,
    )
    if process.returncode != 0:
        raise MaterializationError(
            f"R23D78_SOURCE_UNREADABLE:{relative}:"
            + process.stderr.decode(errors="replace")
        )
    return process.stdout.decode("utf-8").replace("\r\n", "\n")


def _replace_exact(text: str, old: str, new: str, count: int = 1) -> str:
    observed = text.count(old)
    if observed != count:
        raise MaterializationError(
            f"R23D78_ANCHOR_COUNT_INVALID:{observed}:{count}:{old[:160]!r}"
        )
    return text.replace(old, new)


def _section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    if start_index < 0 or text.find(start, start_index + 1) >= 0:
        raise MaterializationError(f"R23D78_SECTION_START_INVALID:{start!r}")
    end_index = text.find(end, start_index)
    if end_index < 0:
        raise MaterializationError(f"R23D78_SECTION_END_INVALID:{end!r}")
    return text[start_index:end_index]


def _identity(text: str) -> str:
    replacements = (
        ("R23D76", "R23D78"),
        ("r23d76", "r23d78"),
        ("23_197", "23_199"),
        ("23197", "23199"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _fixture(text: str) -> str:
    replacements = (
        ("0.0008048271993175149", "0.0006791275809518993"),
        ("0.006968908477574587", "-0.002407998312264681"),
        ("0.0011139935813844204", "-0.0031933500431478024"),
        ("0.0009957263246178627", "0.00213700532913208"),
        ("0.001996839651837945", "0.0016587497666478157"),
        ("0.0015670480206608772", "0.0028402376919984818"),
        ("0.0010064903181046247", "-0.0017453068867325783"),
        ("0.000_804_827_199_317_514_9", "0.000_679_127_580_951_899_3"),
        ("0.006_968_908_477_574_587", "-0.002_407_998_312_264_681"),
        ("0.001_113_993_581_384_420_4", "-0.003_193_350_043_147_802_4"),
        ("0.000_995_726_324_617_862_7", "0.002_137_005_329_132_08"),
        ("0.001_996_839_651_837_945", "0.001_658_749_766_647_815_7"),
        ("0.001_567_048_020_660_877_2", "0.002_840_237_691_998_481_8"),
        ("0.001_006_490_318_104_624_7", "-0.001_745_306_886_732_578_3"),
        ('"gait_phase_offset_ticks": -3', '"gait_phase_offset_ticks": 3'),
        ("gait_phase_offset_ticks: -3", "gait_phase_offset_ticks: 3"),
    )
    for old, new in replacements:
        text = text.replace(old, new)
    return text


def _common(relative: str) -> str:
    return _fixture(_identity(_source(relative)))


def _status_projection(text: str) -> str:
    return text.replace(
        "bounded_native_smoke_pending_physical_not_authorized",
        "physical_not_authorized",
    )


def _rustfmt(text: str) -> str:
    process = subprocess.run(
        ["rustfmt", "--edition", "2024", "--emit", "stdout"],
        input=text,
        capture_output=True,
        check=False,
        encoding="utf-8",
    )
    if process.returncode != 0:
        raise MaterializationError("R23D78_RUSTFMT_FAILED:" + process.stderr.strip())
    return process.stdout.replace("\r\n", "\n")


def _runtime() -> str:
    text = _common("sdk/turning/r23d76_production_route_runtime.py")
    text = _replace_exact(
        text,
        '''        and change.get("engine_aware_native_startup_evaluator_binding") is True
        and change.get("new_campaign_transport_identities") is True,
''',
        '''        and change.get("engine_aware_native_startup_evaluator_binding_changed") is False
        and change.get("r23d77_existing_file_identity_verifier_binding") is True
        and change.get("new_campaign_transport_identities") is True,
''',
    )
    text = _replace_exact(
        text,
        '''        "r23d74_closure_replay_required",
        "r23d75_conformance_closure_replay_required",
''',
        '''        "r23d76_closure_replay_required",
        "r23d77_conformance_closure_replay_required",
        "r23d77_existing_file_identity_mutation_controls_required",
''',
    )
    text = _replace_exact(
        text,
        '''        smoke.get("required_before_qualification") is True
        and smoke.get("engine_count") == 3
        and smoke.get("maximum_world_count") == 3
        and smoke.get("maximum_solver_step_count_per_world") == 2
        and smoke.get("uses_held_out_seed_23199") is False
''',
        '''        smoke.get("required_before_qualification") is False
        and smoke.get("engine_count") == 3
        and smoke.get("maximum_world_count") == 0
        and smoke.get("maximum_solver_step_count_per_world") == 0
        and smoke.get("uses_held_out_seed_23199") is False
        and smoke.get("r23d76_complete_native_horizon_count_used_for_route_adequacy")
        == 9
        and smoke.get("r23d76_reused_as_r23d78_finite_result") is False
''',
    )
    text = _replace_exact(
        text,
        '''        and claims.get("native_smoke_passed") is False
        and claims.get("physical_campaign_opened") is False
''',
        '''        and claims.get("native_smoke_passed") is False
        and claims.get("new_native_smoke_required") is False
        and claims.get("r23d76_native_route_coverage_used_only_for_smoke_adequacy")
        is True
        and claims.get("physical_campaign_opened") is False
''',
    )
    return text


def _evaluator() -> str:
    text = _common(
        "sdk/turning/r23d76_production_route_three_engine_turning_evaluator.py"
    )
    text = _replace_exact(
        text,
        '''import r23d75_native_startup_trace_evaluator_conformance as startup_binding
import r23d78_production_route_runtime as design
from r23d78_receipt_contract import project_retention_receipt
''',
        '''import r23d75_native_startup_trace_evaluator_conformance as startup_binding
import r23d78_production_route_runtime as design
from r23d77_windows_cas_file_identity import verify_with_existing_file_identity
from r23d78_receipt_contract import project_retention_receipt
''',
    )
    text = _replace_exact(
        text,
        '''_R23D78_CELL_BY_ID = design.cell_by_id
_R23D78_EXPECTED_SEGMENT_COUNTS = design.expected_segment_counts


def _configure_inherited_evaluator() -> None:
''',
        '''_R23D78_CELL_BY_ID = design.cell_by_id
_R23D78_EXPECTED_SEGMENT_COUNTS = design.expected_segment_counts
_FROZEN_R23D65_CAS_BINDING_FAILURES = inherited._cas_binding_failures


def _r23d78_cas_binding_failures(
    entry: Mapping[str, Any],
    *,
    authority_repo_root: Path | None = None,
) -> list[str]:
    """Apply only the R23D77-closed existing-file identity successor seam."""

    root = inherited.REPO_ROOT if authority_repo_root is None else authority_repo_root
    return verify_with_existing_file_identity(
        entry,
        authority_repo_root=root,
        frozen_verifier=_FROZEN_R23D65_CAS_BINDING_FAILURES,
    )


def _configure_inherited_evaluator() -> None:
''',
    )
    text = _replace_exact(
        text,
        '''    inherited.load_declaration = design.load_declaration
    accepted.validate_trace = _ACCEPTED_VALIDATE_TRACE
''',
        '''    inherited.load_declaration = design.load_declaration
    inherited._cas_binding_failures = _r23d78_cas_binding_failures
    accepted.validate_trace = _ACCEPTED_VALIDATE_TRACE
''',
    )
    text = _replace_exact(
        text,
        '''        complete_outcome_controls=controls,
        engine_aware_startup_binding={
''',
        '''        complete_outcome_controls=controls,
        cas_path_identity_binding={
            "contract_id": "QSDK-R23D77-WINDOWS-CAS-PATH-IDENTITY",
            "repairable_frozen_failure_code": "R23D65_TRACE_ARTIFACT_CAS_PATH",
            "successor_failure_code": "R23D77_TRACE_ARTIFACT_CAS_FILE_IDENTITY",
            "payload_and_manifest_same_existing_file_required": True,
            "complete_frozen_verifier_replay_required": True,
        },
        engine_aware_startup_binding={
''',
    )
    return text


def _rapier_kernel() -> str:
    relative = "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs"
    text = _source(relative)

    constants = _fixture(
        _identity(
            _section(
                text,
                "pub const R23D76_CAMPAIGN_ID: &str =",
                "pub(crate) const TURNING_ROUTE_ID: &str =",
            )
        )
    )
    text = _replace_exact(
        text,
        "pub(crate) const TURNING_ROUTE_ID: &str =",
        constants + "pub(crate) const TURNING_ROUTE_ID: &str =",
    )

    trace = _fixture(
        _identity(
            _section(
                text,
                "pub(crate) fn r23d76_project_production_trace_row(",
                "fn r23d68_retain_trace(",
            )
        )
    )
    text = _replace_exact(
        text, "fn r23d68_retain_trace(\n", trace + "fn r23d68_retain_trace(\n"
    )

    retention = _fixture(
        _identity(
            _section(
                text,
                "fn r23d76_retain_trace(",
                "fn turning_route_retain_trace(",
            )
        )
    )
    text = _replace_exact(
        text,
        "fn turning_route_retain_trace(\n",
        retention + "fn turning_route_retain_trace(\n",
    )

    core = _fixture(
        _identity(
            _section(
                text,
                "pub(crate) fn run_r23d76_rapier_physical_core(",
                "fn run_r23d27_rapier_physical_world(",
            )
        )
    )
    core = _replace_exact(
        core,
        "        || plan.r23d74_route\n        || !plan.r23d78_route\n",
        "        || plan.r23d74_route\n        || plan.r23d76_route\n        || !plan.r23d78_route\n",
    )
    text = _replace_exact(
        text,
        "fn run_r23d27_rapier_physical_world(\n",
        core + "fn run_r23d27_rapier_physical_world(\n",
    )

    plan = _fixture(
        _identity(
            _section(
                text,
                "    const R23D76_ROUTE: Self = Self {\n",
                "    const fn with_evidence_window_measurement_origin",
            )
        )
    )
    plan = _replace_exact(
        plan,
        "        r23d78_route: true,\n",
        "        r23d76_route: false,\n        r23d78_route: true,\n",
    )
    text = _replace_exact(
        text,
        "    const fn with_evidence_window_measurement_origin",
        plan + "    const fn with_evidence_window_measurement_origin",
    )

    text = _replace_exact(
        text,
        "    r23d76_route: bool,\n",
        "    r23d76_route: bool,\n    r23d78_route: bool,\n",
    )
    text = text.replace(
        "        r23d76_route: false,\n",
        "        r23d76_route: false,\n        r23d78_route: false,\n",
    )
    text = _replace_exact(
        text,
        "        r23d76_route: true,\n",
        "        r23d76_route: true,\n        r23d78_route: false,\n",
    )
    text = _replace_exact(
        text,
        "        r23d76_route: false,\n        r23d78_route: false,\n        r23d78_route: true,\n",
        "        r23d76_route: false,\n        r23d78_route: true,\n",
    )
    text = text.replace(
        "        || plan.r23d76_route\n",
        "        || plan.r23d76_route\n        || plan.r23d78_route\n",
    )
    text = _replace_exact(
        text,
        '''        || plan.r23d76_route
        || plan.r23d78_route
        || !plan.r23d78_route
''',
        '''        || plan.r23d76_route
        || !plan.r23d78_route
''',
    )
    text = _replace_exact(
        text,
        '''        } else if execution_plan.r23d76_route {
            r23d76_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
        '''        } else if execution_plan.r23d76_route {
            r23d76_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else if execution_plan.r23d78_route {
            r23d78_trace_row(trace_row, semantic_step, &cell).map_err(&settled_failure)?
        } else {
''',
    )
    text = _replace_exact(
        text,
        '''    } else if execution_plan.r23d76_route {
        r23d76_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
        '''    } else if execution_plan.r23d76_route {
        r23d76_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else if execution_plan.r23d78_route {
        r23d78_retain_trace(&cell, &trace_rows, &attempt_root).map_err(&settled_failure)?
    } else {
''',
    )
    return _rustfmt(text)


def _rapier_lib() -> str:
    text = _source("sdk/adapters/rapier/src/lib.rs")
    text = _replace_exact(
        text,
        "mod qsdk_r23d76_turning_route;\n",
        "mod qsdk_r23d76_turning_route;\nmod qsdk_r23d78_receipt_contract;\nmod qsdk_r23d78_turning_route;\n",
    )
    text = _replace_exact(
        text,
        '''pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D76_CAMPAIGN_ID, R23D76_CAMPAIGN_SEED, R23D76_GATE_ID, R23D76_STAGE_ID,
};
''',
        '''pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D76_CAMPAIGN_ID, R23D76_CAMPAIGN_SEED, R23D76_GATE_ID, R23D76_STAGE_ID,
};
pub use qsdk_r23d3_phase_balanced::r23d27_physical::{
    R23D78_CAMPAIGN_ID, R23D78_CAMPAIGN_SEED, R23D78_GATE_ID, R23D78_STAGE_ID,
};
''',
    )
    text = _replace_exact(
        text,
        '''pub use qsdk_r23d76_turning_route::{
    run_qsdk_r23d76_rapier_authorization_preflight, run_qsdk_r23d76_rapier_complete_row_ghost,
    run_qsdk_r23d76_rapier_physical, run_qsdk_r23d76_rapier_preflight,
    run_qsdk_r23d76_success_terminal_projection_ghost,
};
''',
        '''pub use qsdk_r23d76_turning_route::{
    run_qsdk_r23d76_rapier_authorization_preflight, run_qsdk_r23d76_rapier_complete_row_ghost,
    run_qsdk_r23d76_rapier_physical, run_qsdk_r23d76_rapier_preflight,
    run_qsdk_r23d76_success_terminal_projection_ghost,
};
pub use qsdk_r23d78_turning_route::{
    run_qsdk_r23d78_rapier_authorization_preflight, run_qsdk_r23d78_rapier_complete_row_ghost,
    run_qsdk_r23d78_rapier_physical, run_qsdk_r23d78_rapier_preflight,
    run_qsdk_r23d78_success_terminal_projection_ghost,
};
''',
    )
    return _rustfmt(text)


def _plain(relative: str) -> str:
    return _common(relative)


OUTPUTS: tuple[tuple[Path, Callable[[], str]], ...] = (
    (ROOT / "sdk/turning/r23d78_production_route_runtime.py", _runtime),
    (
        ROOT / "sdk/turning/r23d78_production_route_three_engine_turning_evaluator.py",
        _evaluator,
    ),
    (
        ROOT / "sdk/turning/r23d78_receipt_contract.py",
        lambda: _plain("sdk/turning/r23d76_receipt_contract.py"),
    ),
    (
        ROOT / "sdk/turning/r23d78_receipt_contract.gd",
        lambda: _plain("sdk/turning/r23d76_receipt_contract.gd"),
    ),
    (
        ROOT / "tests/test_sdk_qsdk_r23d78_godot_jolt_worker.gd",
        lambda: _status_projection(
            _plain("tests/test_sdk_qsdk_r23d76_godot_jolt_worker.gd")
        ),
    ),
    (
        ROOT
        / "sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d78_turning_route.py",
        lambda: _status_projection(
            _plain(
                "sdk/adapters/mujoco/sporespore_mujoco_adapter/"
                "qsdk_r23d76_turning_route.py"
            )
        ),
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d78_receipt_contract.rs",
        lambda: _rustfmt(
            _plain("sdk/adapters/rapier/src/qsdk_r23d76_receipt_contract.rs")
        ),
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d78_turning_route.rs",
        lambda: _rustfmt(
            _status_projection(
                _plain("sdk/adapters/rapier/src/qsdk_r23d76_turning_route.rs")
            )
        ),
    ),
    (
        ROOT / "sdk/adapters/rapier/src/bin/qsdk_r23d78_turning_route.rs",
        lambda: _rustfmt(
            _plain("sdk/adapters/rapier/src/bin/qsdk_r23d76_turning_route.rs")
        ),
    ),
    (
        ROOT / "sdk/adapters/rapier/src/qsdk_r23d3_phase_balanced/r23d27_physical.rs",
        _rapier_kernel,
    ),
    (ROOT / "sdk/adapters/rapier/src/lib.rs", _rapier_lib),
    (
        ROOT / "sdk/run_qsdk_r23d78_supervisor.ps1",
        lambda: _status_projection(_plain("sdk/run_qsdk_r23d76_supervisor.ps1")),
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
            raise MaterializationError(f"R23D78_OUTPUT_DRIFT:{relative}")
    print(
        f"[turning/3e] R23D78 native bindings {arguments.command}: "
        f"outputs={len(OUTPUTS)} models=0 worlds=0"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
