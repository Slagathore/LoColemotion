from __future__ import annotations

from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError, exact, exact_bools, find_external_source_root, load,
    require, require_ordered_markers, sha256, verify_exact_paths,
    verify_legacy_live_gate_paths,
)


CONTRACT = ROOT / "sdk/recovery/r24d46_rapier_exact_solver_work_observer_contract_v1.json"
CLOSURE = ROOT / (
    "sdk/recovery/"
    "r24d46_rapier_exact_solver_work_observer_qualification_closure_v1.json"
)


def audit() -> None:
    contract = load(CONTRACT)
    verify_exact_paths(contract, {
        "schema_version": "sporespore_qsdk_r24d46_rapier_exact_solver_work_observer_contract_v1",
        "gate_id": "QSDK-R24D46", "question_class": "development",
        "authored_parent_commit": "756cb70e9b30afa57aa952bd3bde3e6f30a572f0",
        "physical_question_declared": False,
        "complete_zero_world_gate.must_pass_before_physics": True,
        "complete_zero_world_gate.world_build_count": 0,
        "complete_zero_world_gate.solver_step_count": 0,
        "complete_zero_world_gate.maximum_physical_steps_authorized": 0,
    }, "IDENTITY")
    exact_bools(contract, (
        "physical_question_declared", "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
        "population_inference_declared",
    ), False, "DECLARATION")
    exact_bools(contract["predecessor"], (
        "same_identity_rerun_permitted", "same_identity_requalification_permitted",
        "historical_result_rewritten", "historical_threshold_rewritten",
        "historical_evaluator_rewritten", "historical_interpretation_rewritten",
        "r24d45_reclassified",
    ), False, "PREDECESSOR")
    subprocess.run([
        "git", "diff", "--quiet", contract["authored_parent_commit"], "--",
        contract["predecessor"]["closure_path"], contract["predecessor"]["diagnosis_path"],
    ], cwd=ROOT, check=True)

    dependency = contract["pinned_dependency"]
    patch_path = ROOT / dependency["patch_path"]
    patch_raw = patch_path.read_bytes()
    exact((len(patch_raw), sha256(patch_raw)),
          (dependency["patch_byte_length"], dependency["patch_raw_sha256"]), "PATCH")
    upstream_bindings = [{
        "path": item["path"], "byte_length": item["upstream_byte_length"],
        "raw_sha256": item["upstream_raw_sha256"],
    } for item in dependency["upstream_and_patched_files"]]
    upstream = find_external_source_root(
        Path.home() / ".cargo/registry/src",
        dependency["installed_source_root_suffix"], upstream_bindings,
    )
    subprocess.run(["git", "apply", "--check", str(patch_path)], cwd=upstream, check=True)
    lock = (ROOT / "sdk/Cargo.lock").read_text(encoding="utf-8")
    require_ordered_markers(lock, (
        'name = "rapier3d"', f'version = "{dependency["version"]}"',
        f'source = "{dependency["registry_source"]}"',
        f'checksum = "{dependency["cargo_registry_checksum"]}"',
    ), "LOCK")

    patch_source = patch_raw.decode("utf-8")
    for marker in (
        'sporespore-motor-work-telemetry = []',
        "pub struct JointMotorWorkTelemetry", "pub generalized_impulse: Real",
        "pub supplied_work: Real", "pub absorbed_work: Real", "pub net_work: Real",
        "pub application_count: u32", "pub small_step_count: u32",
        'feature = "sporespore-motor-work-telemetry",\n+    feature = "simd-is-enabled"',
        "compile_error!(", "sporespore_motor_work.clear();",
        "sequence.saturating_add(1)", "JointMotorWorkTelemetry {",
    ):
        require(marker in patch_source, f"PATCH_MARKER:{marker}")
    velocity = patch_source[patch_source.index("solve_with_sporespore_motor_work("):
                            patch_source.index("pub fn writeback_impulses", patch_source.index(
                                "solve_with_sporespore_motor_work("))]
    require_ordered_markers(velocity, (
        "relative_velocity_before", "constraint_impulse_before", "self.solve_generic(",
        "relative_velocity_after", "constraint_delta_impulse",
        "generalized_impulse = -constraint_delta_impulse",
        "(relative_velocity_before + relative_velocity_after)", "* 0.5",
    ), "APPLICATION_SEAM")

    cargo = (ROOT / "sdk/adapters/rapier/Cargo.toml").read_text(encoding="utf-8")
    module = (ROOT / "sdk/adapters/rapier/src/qsdk_r24d46_motor_work_observer.rs").read_text(
        encoding="utf-8")
    library = (ROOT / "sdk/adapters/rapier/src/lib.rs").read_text(encoding="utf-8")
    require('sporespore-rapier-motor-work = []' in cargo, "ADAPTER_FEATURE")
    for source, marker in ((library, '#[cfg(feature = "sporespore-rapier-motor-work")]'),
                           (module, "motor.sporespore_solver_work"),
                           (module, "2.0 * gamma_n + epsilon"),
                           (module, "QSDK_R24D46_WORK_PARTITION_INVALID"),
                           (module, '"mutation_rejection_count": mutation_rejections.len()')):
        require(marker in source, f"ADAPTER_MARKER:{marker}")
    require("PhysicsWorld" not in module and "world.step" not in module, "ZERO_WORLD_SOURCE")
    runner = (ROOT / contract["qualification_runner"]["script_path"]).read_text(
        encoding="utf-8")
    require_ordered_markers(runner, (
        "registry_archive_file_name", '"-xf", $registryArchive',
        '"core.autocrlf=false"', '"apply", "--check", $patchPath',
        '"apply", $patchPath', "PATCHED_DEPENDENCY_BINDING",
        "[patch.crates-io]", "$env:CARGO_TARGET_DIR",
        '"check", "--locked", "--offline"',
        '"run", "--locked", "--offline"', "PREFLIGHT_RECEIPT",
        "$checks.worktree_unchanged = $true",
    ), "QUALIFICATION_RUNNER")
    require(
        "world.step" not in runner
        and "run_qsdk_r24d45_rapier_recovery_development_attempt" not in runner
        and '"physical"' not in runner,
        "RUNNER_PHYSICAL_PATH",
    )
    exact(len(contract["source_inventory"]), len(set(contract["source_inventory"])),
          "SOURCE_INVENTORY")
    require(all((ROOT / path).is_file() for path in contract["source_inventory"]),
            "SOURCE_INVENTORY_MISSING")
    live_paths = contract["live_authority_paths"]
    live_expectations = contract["live_gate_expectations"]
    live_revision = None
    if CLOSURE.is_file():
        closure = load(CLOSURE)
        live_revision = closure["source"]["commit"]
    verify_legacy_live_gate_paths(
        ROOT, live_paths, "QSDK-R24D45", live_expectations,
        revision=live_revision,
    )
    claim = contract["claim_boundary"]
    require(claim.pop("exact_active_scalar_rapier_motor_observer_implemented_in_source") is True,
            "IMPLEMENTED_CLAIM")
    require(claim.pop("held_out_cells_remain_sealed") is True and not any(claim.values()),
            "CLAIM_INFLATION")
    print(
        "QSDK_R24D46_RAPIER_EXACT_SOLVER_WORK_SOURCE_PASS "
        "worlds=0 solver_steps=0 applications=128 simd=false energy_partition=false physics=false"
    )


if __name__ == "__main__":
    try:
        audit()
    except (ClosureAuditError, OSError, KeyError, ValueError, subprocess.SubprocessError) as error:
        print(f"QSDK_R24D46_RAPIER_EXACT_SOLVER_WORK_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
