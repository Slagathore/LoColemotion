#!/usr/bin/env python3
"""Zero-world source, reuse-key, and mutation audit for QSDK-R24D12."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


EXPECTED_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore")
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
EXPECTED_GODOT_ROOT = Path(r"C:\Users\Cole\CodeStuff\dependencies\godot-sporespore-4.7")
EXPECTED_GODOT_REMOTE = "https://github.com/godotengine/godot.git"
EXPECTED_GODOT_COMMIT = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"
EXPECTED_PATCH_SHA = "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"
EXPECTED_BODY_SHA = "36842eb8765e1a4abe9eb2fbb20d85ab14b653c7333bd043beb2c6cab5392408"
EXPECTED_BODY_BLOB = "1b563c74fc31a37f1bdb6113548aaaa63871243e"
EXPECTED_CONSOLE_SHA = "ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"
EXPECTED_ENGINE_SHA = "2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"
EXPECTED_PATCHED_PATHS = sorted(
    [
        "modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp",
        "modules/jolt_physics/joints/jolt_hinge_joint_3d.h",
        "modules/jolt_physics/joints/jolt_joint_3d.h",
        "modules/jolt_physics/jolt_physics_server_3d.cpp",
        "modules/jolt_physics/jolt_physics_server_3d.h",
        "modules/jolt_physics/register_types.cpp",
        "modules/jolt_physics/spaces/jolt_space_3d.cpp",
        "modules/jolt_physics/spaces/jolt_space_3d.h",
        "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.cpp",
        "thirdparty/jolt_physics/Jolt/Physics/Constraints/HingeConstraint.h",
    ]
)
DECLARATION = "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1.json"
MANIFEST = "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_validation_manifest.json"
EVALUATOR = "sdk/recovery/r24d12_godot_jolt_braking_mechanism_activation_evaluator.py"
RIG = "scripts/lab/rigs/r24d12_godot_jolt_braking_mechanism_activation_rig.gd"
WORKER = "tests/test_sdk_qsdk_r24d12_godot_jolt_braking_mechanism_activation_worker.gd"
RUNNER = "sdk/run_qsdk_r24d12_braking_mechanism_activation_zero_world_gate.ps1"
AUDIT = "tests/test_qsdk_r24d12_godot_jolt_braking_mechanism_activation_freeze.py"
EXPECTED_BINDING_PATHS = [
    ".gitattributes",
    "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch",
    "sdk/recovery/r24d10_godot_jolt_exact_step_numerical_telemetry_zero_world_positive_closure_v1.json",
    "sdk/recovery/r24d11_godot_jolt_instrumented_profile_promotion_decision_v1.json",
    "scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd",
    "tests/test_sdk_qsdk_r24d9_godot_jolt_one_hinge_numerical_telemetry_worker.gd",
    DECLARATION,
    EVALUATOR,
    RIG,
    WORKER,
    RUNNER,
    AUDIT,
    "sdk/locomotion_operation_lock.ps1",
    "sdk/godot_receipt_terminated_process.ps1",
    "sdk/content_addressed_artifact_store.ps1",
]


class AuditError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def run(command: list[str], *, cwd: Path, check: bool = True) -> subprocess.CompletedProcess[bytes]:
    result = subprocess.run(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if check and result.returncode != 0:
        raise AuditError(f"COMMAND_FAILED:{' '.join(command)}:{result.stdout.decode(errors='replace')}")
    return result


def git(root: Path, *arguments: str) -> str:
    return run(["git", "-C", str(root), *arguments], cwd=root).stdout.decode().strip()


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    require(type(value) is dict, f"JSON_NOT_OBJECT:{path}")
    return value


def exact(value: Any, expected: Any, code: str) -> None:
    require(value == expected and type(value) is type(expected), code)


def validate_repository(root: Path, require_committed: bool) -> str:
    exact(Path(git(root, "rev-parse", "--show-toplevel")).resolve(), EXPECTED_ROOT.resolve(), "REPO_ROOT")
    exact(git(root, "remote", "get-url", "origin"), EXPECTED_REMOTE, "REPO_REMOTE")
    exact(git(root, "branch", "--show-current"), "main", "REPO_BRANCH")
    head = git(root, "rev-parse", "HEAD")
    if require_committed:
        exact(git(root, "status", "--short"), "", "REPO_DIRTY")
        exact(git(root, "rev-parse", "@{upstream}"), head, "REPO_UPSTREAM")
        exact(git(root, "rev-parse", "refs/remotes/origin/main"), head, "REPO_CACHED_REMOTE")
    worktrees = [line for line in git(root, "worktree", "list", "--porcelain").splitlines() if line.startswith("worktree ")]
    exact(len(worktrees), 1, "REPO_WORKTREE_COUNT")
    return head


def validate_declaration(root: Path) -> None:
    declaration = load_json(root / DECLARATION)
    exact(
        declaration.get("schema_version"),
        "sporespore_qsdk_r24d12_godot_jolt_braking_mechanism_activation_preregistration_v1",
        "DECLARATION_SCHEMA",
    )
    exact(declaration.get("gate_id"), "QSDK-R24D12", "DECLARATION_GATE")
    exact(declaration.get("question_class"), "development", "DECLARATION_QUESTION")
    exact(
        declaration.get("status"),
        "prospective_minimal_braking_mechanism_source_implemented_zero_world_qualification_pending",
        "DECLARATION_STATUS",
    )
    predecessor = declaration["predecessor_decision"]
    exact(predecessor["gate_id"], "QSDK-R24D11", "DECLARATION_PARENT_GATE")
    exact(predecessor["publication_commit"], "324620ee4f228e856a898dff1be96fe4351b8ff0", "DECLARATION_PARENT_COMMIT")
    exact(predecessor["result_rewritten_or_rethresholded"], False, "DECLARATION_PARENT_REWRITE")
    diagnosis = declaration["source_diagnosis"]
    exact(diagnosis["godot_source_commit"], EXPECTED_GODOT_COMMIT, "DECLARATION_DIAGNOSIS_COMMIT")
    exact(diagnosis["raw_sha256"], f"sha256:{EXPECTED_BODY_SHA}", "DECLARATION_DIAGNOSIS_SHA")
    exact(diagnosis["byte_length"], 38707, "DECLARATION_DIAGNOSIS_BYTES")
    exact(diagnosis["git_blob_oid"], EXPECTED_BODY_BLOB, "DECLARATION_DIAGNOSIS_BLOB")
    exact(diagnosis["physical_mechanism_activation_proved_by_source_alone"], False, "DECLARATION_DIAGNOSIS_CLAIM")
    correction = declaration["prospective_correction"]
    exact(correction["activation_route_id"], "godot_jolt_unfreeze_then_public_angular_velocity_write_v1", "DECLARATION_ROUTE")
    exact(correction["angular_velocity_write_count"], 4, "DECLARATION_WRITES")
    exact(correction["physics_server_state_write_count"], 0, "DECLARATION_SERVER_WRITES")
    fixture = declaration["fixture_freeze"]
    exact(fixture["cell_ids_in_order"], ["brake_positive", "brake_negative", "disabled_positive", "disabled_negative"], "DECLARATION_CELLS")
    exact(fixture["isolated_cell_count"], 4, "DECLARATION_CELL_COUNT")
    exact(fixture["maximum_physics_step_count"], 1, "DECLARATION_STEP_COUNT")
    exact(fixture["retained_sample_count"], 4, "DECLARATION_SAMPLE_COUNT")
    adequacy = declaration["adequacy"]
    for field in (
        "empirical_acceptance_threshold_count",
        "superiority_margin_count",
        "equivalence_or_non_inferiority_margin_count",
        "held_out_validation_cohort_count",
        "population_claim_count",
    ):
        exact(adequacy[field], 0, f"DECLARATION_{field.upper()}")
    boundary = declaration["execution_boundary"]
    exact(boundary["complete_zero_world_gate_required"], True, "DECLARATION_ZERO_WORLD_REQUIRED")
    exact(boundary["zero_object_production_route_preflight_required"], True, "DECLARATION_ZERO_OBJECT_REQUIRED")
    exact(boundary["shortened_physics_ghost_required"], False, "DECLARATION_GHOST")
    exact(boundary["physical_execution_authorized_now"], False, "DECLARATION_PHYSICAL_AUTHORITY")
    for field in ("world_attempt_count", "world_build_count", "solver_step_count"):
        exact(boundary[field], 0, f"DECLARATION_{field.upper()}")
    for field, value in declaration["claims"].items():
        if field in (
            "prospective_development_question_declared",
            "source_diagnosis_recorded",
            "corrected_activation_route_implemented",
            "complete_zero_world_gate_source_implemented",
        ):
            exact(value, True, f"DECLARATION_CLAIM_{field}")
        else:
            exact(value, False, f"DECLARATION_CLAIM_{field}")


def validate_godot_source(root: Path) -> tuple[Path, Path]:
    exact(Path(git(root, "rev-parse", "--show-toplevel")).resolve(), EXPECTED_GODOT_ROOT.resolve(), "GODOT_ROOT")
    exact(git(root, "remote", "get-url", "origin"), EXPECTED_GODOT_REMOTE, "GODOT_REMOTE")
    exact(git(root, "rev-parse", "HEAD"), EXPECTED_GODOT_COMMIT, "GODOT_COMMIT")
    status_output = run(
        ["git", "-C", str(root), "status", "--short"],
        cwd=root,
    ).stdout.decode()
    status_paths = sorted(
        line[3:].replace("\\", "/") for line in status_output.splitlines()
    )
    exact(status_paths, EXPECTED_PATCHED_PATHS, "GODOT_PATCHED_PATHS")
    patch_path = EXPECTED_ROOT / "sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch"
    exact(sha256(patch_path), EXPECTED_PATCH_SHA, "GODOT_PATCH_SHA")
    diff = run(["git", "-C", str(root), "diff", "--no-ext-diff"], cwd=root).stdout.replace(b"\r\n", b"\n")
    patch = patch_path.read_bytes().replace(b"\r\n", b"\n").rstrip(b"\n") + b"\n"
    exact(diff, patch, "GODOT_PATCH_IDENTITY")
    body_path = root / "modules/jolt_physics/objects/jolt_body_3d.cpp"
    exact(sha256(body_path), EXPECTED_BODY_SHA, "GODOT_BODY_SHA")
    exact(git(root, "hash-object", "modules/jolt_physics/objects/jolt_body_3d.cpp"), EXPECTED_BODY_BLOB, "GODOT_BODY_BLOB")
    body_text = body_path.read_text(encoding="utf-8")
    require(body_text.index("angular_surface_velocity = p_velocity;") < body_text.index("angular_surface_velocity = Vector3();"), "GODOT_BODY_CONTROL_FLOW")
    console = root / "bin/godot.windows.editor.dev.x86_64.console.exe"
    engine = root / "bin/godot.windows.editor.dev.x86_64.exe"
    exact(sha256(console), EXPECTED_CONSOLE_SHA, "GODOT_CONSOLE_SHA")
    exact(console.stat().st_size, 293376, "GODOT_CONSOLE_BYTES")
    exact(sha256(engine), EXPECTED_ENGINE_SHA, "GODOT_ENGINE_SHA")
    exact(engine.stat().st_size, 188829184, "GODOT_ENGINE_BYTES")
    return console, engine


def runner_semantics(text: str) -> bool:
    required = [
        'Enter-SporeSporeLocomotionOperationLock -Role "conformance"',
        '"ls-remote", "--heads", "origin", "refs/heads/main"',
        '"same_source_zero_world_attempt_already_consumed:',
        'status = "consumed_before_first_stage"',
        'name = "r24d12_freeze_and_mutation_audit"',
        'name = "r24d10_cold_baseline_and_exact_runtime_reuse_key"',
        '"--mode=zero_world_preflight"',
        '[int]$workerReceipt.world_attempt_count -eq 0',
        '[int]$workerReceipt.solver_step_count -eq 0',
        'campaign_result_reused = $false',
        'physical_authorization = $false',
        'QSDK_R24D12_BRAKING_MECHANISM_ZERO_WORLD_GATE',
    ]
    if not all(marker in text for marker in required):
        return False
    ordered = [
        'name = "r24d12_freeze_and_mutation_audit"',
        'name = "r24d10_cold_baseline_and_exact_runtime_reuse_key"',
        'name = "evaluator_shaped_zero_world_template"',
        'name = "custom_runtime_zero_object_worker"',
        'name = "independent_synthetic_evaluation"',
        'QSDK_R24D12_BRAKING_MECHANISM_ZERO_WORLD_GATE',
    ]
    offsets = [text.find(marker) for marker in ordered]
    return (
        all(offset >= 0 for offset in offsets)
        and offsets == sorted(offsets)
        and "[switch]$RunPhysical" not in text
        and '"--mode=physical"' not in text
        and "SCons" not in text
    )


def runtime_reuse_semantics(text: str) -> bool:
    markers = [
        '$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"',
        '$expectedPatchHash = "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"',
        '$expectedBodySourceHash = "36842eb8765e1a4abe9eb2fbb20d85ab14b653c7333bd043beb2c6cab5392408"',
        '$expectedConsoleHash = "ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"',
        '$expectedEngineHash = "2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"',
        '[double]$baseline.runtime.independent_cold_build_duration_s -gt 0.0',
        'campaign_result_reused = $false',
        'physical_evidence_reused = $false',
    ]
    return all(marker in text for marker in markers) and "SCons" not in text


def source_semantics(rig: str, worker: str) -> bool:
    rig_required = [
        'const MAXIMUM_PHYSICS_STEP_COUNT := 1',
        'const RETAINED_SAMPLE_COUNT := 4',
        '"brake_positive"',
        '"brake_negative"',
        '"disabled_positive"',
        '"disabled_negative"',
        'static func activate_unfreeze_then_write(cell: Dictionary)',
        'child.freeze = false',
        'child.angular_velocity = canonical_axis_world(cell) * declared_rate',
        'PhysicsServer3D.body_get_state(',
        '"physics_server_state_write_count": 0',
    ]
    worker_required = [
        '"--mode=zero_world_preflight"' if False else 'mode == "zero_world_preflight"',
        'PhysicsServer3D.set_active(false)',
        'R24D12Rig.activate_unfreeze_then_write(cell)',
        'physics_frame.connect(_r24d12_on_physics_frame)',
        'PhysicsServer3D.set_active(true)',
        'JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(joint.get_rid())',
        'PhysicsServer3D.set_active(false)',
        'if token != 1:',
        '"physics_server_disabled_before_step_two": true',
        '"world_attempt_count": 0',
        '"solver_step_count": 0',
    ]
    if not all(marker in rig for marker in rig_required):
        return False
    if not all(marker in worker for marker in worker_required):
        return False
    return (
        rig.index("child.freeze = false")
        < rig.index("child.angular_velocity = canonical_axis_world(cell) * declared_rate")
        < rig.index("PhysicsServer3D.body_get_state(")
        and worker.index("PhysicsServer3D.set_active(false)")
        < worker.index("R24D12Rig.build()")
        < worker.index("R24D12Rig.activate_unfreeze_then_write(cell)")
        < worker.index("physics_frame.connect(_r24d12_on_physics_frame)")
    )


def validate_source_mutations(root: Path) -> tuple[int, int]:
    runner = (root / RUNNER).read_text(encoding="utf-8").replace("\r\n", "\n")
    rig = (root / RIG).read_text(encoding="utf-8").replace("\r\n", "\n")
    worker = (root / WORKER).read_text(encoding="utf-8").replace("\r\n", "\n")
    require(runner_semantics(runner), "RUNNER_SEMANTICS")
    require(runtime_reuse_semantics(runner), "RUNTIME_REUSE_SEMANTICS")
    require(source_semantics(rig, worker), "SOURCE_SEMANTICS")
    runner_markers = [
        'Enter-SporeSporeLocomotionOperationLock -Role "conformance"',
        '"ls-remote", "--heads", "origin", "refs/heads/main"',
        '"same_source_zero_world_attempt_already_consumed:',
        'status = "consumed_before_first_stage"',
        'name = "r24d12_freeze_and_mutation_audit"',
        'name = "r24d10_cold_baseline_and_exact_runtime_reuse_key"',
        '"--mode=zero_world_preflight"',
        'campaign_result_reused = $false',
        'physical_authorization = $false',
        'QSDK_R24D12_BRAKING_MECHANISM_ZERO_WORLD_GATE',
    ]
    source_markers = [
        'const MAXIMUM_PHYSICS_STEP_COUNT := 1',
        'const RETAINED_SAMPLE_COUNT := 4',
        'child.freeze = false',
        'child.angular_velocity = canonical_axis_world(cell) * declared_rate',
        'PhysicsServer3D.body_get_state(',
        'R24D12Rig.activate_unfreeze_then_write(cell)',
        'physics_frame.connect(_r24d12_on_physics_frame)',
        'if token != 1:',
    ]
    rejected = 0
    for marker in runner_markers:
        mutated = runner.replace(marker, "R24D12_MUTATED_MARKER")
        require(not runner_semantics(mutated), f"RUNNER_MUTATION_ACCEPTED:{marker}")
        rejected += 1
    for marker in source_markers:
        if marker in rig:
            mutated_rig = rig.replace(marker, "R24D12_MUTATED_MARKER", 1)
            mutated_worker = worker
        else:
            mutated_rig = rig
            mutated_worker = worker.replace(marker, "R24D12_MUTATED_MARKER", 1)
        require(not source_semantics(mutated_rig, mutated_worker), f"SOURCE_MUTATION_ACCEPTED:{marker}")
        rejected += 1
    reuse_markers = [
        '$expectedGodotCommit = "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88"',
        '$expectedPatchHash = "9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c"',
        '$expectedBodySourceHash = "36842eb8765e1a4abe9eb2fbb20d85ab14b653c7333bd043beb2c6cab5392408"',
        '$expectedConsoleHash = "ff655a567d31f51628d5b21742a0618e53f9fbf8a94937dd07d9882a0739872f"',
        '$expectedEngineHash = "2d68ed7ae53704ffb532cd5633241c74d599d69e3bf1968de0ef261553030ffb"',
        '[double]$baseline.runtime.independent_cold_build_duration_s -gt 0.0',
        'campaign_result_reused = $false',
        'physical_evidence_reused = $false',
    ]
    reuse_rejected = 0
    for marker in reuse_markers:
        mutated = runner.replace(marker, "R24D12_MUTATED_REUSE_MARKER")
        require(not runtime_reuse_semantics(mutated), f"RUNTIME_REUSE_MUTATION_ACCEPTED:{marker}")
        reuse_rejected += 1
    return rejected, reuse_rejected


def validate_manifest(root: Path, head: str, require_committed: bool) -> int:
    manifest = load_json(root / MANIFEST)
    exact(
        manifest.get("schema_version"),
        "sporespore_qsdk_r24d12_godot_jolt_braking_mechanism_activation_validation_manifest_v1",
        "MANIFEST_SCHEMA",
    )
    exact(manifest.get("gate_id"), "QSDK-R24D12", "MANIFEST_GATE")
    exact(manifest.get("question_class"), "development", "MANIFEST_QUESTION")
    exact(
        manifest.get("status"),
        "prospective_minimal_source_bytes_bound_zero_world_qualification_pending",
        "MANIFEST_STATUS",
    )
    exact(manifest.get("includes_self"), False, "MANIFEST_INCLUDES_SELF")
    exact(manifest.get("source_binding_count"), len(EXPECTED_BINDING_PATHS), "MANIFEST_BINDING_COUNT")
    bindings = manifest.get("source_bindings")
    require(type(bindings) is list and len(bindings) == len(EXPECTED_BINDING_PATHS), "MANIFEST_BINDINGS")
    exact([binding["path"] for binding in bindings], EXPECTED_BINDING_PATHS, "MANIFEST_BINDING_ORDER")
    for binding in bindings:
        relative = binding["path"]
        path = root / relative
        require(path.is_file(), f"MANIFEST_PATH_MISSING:{relative}")
        exact(binding["raw_sha256"], f"sha256:{sha256(path)}", f"MANIFEST_SHA:{relative}")
        exact(binding["byte_length"], path.stat().st_size, f"MANIFEST_BYTES:{relative}")
        working_blob = git(root, "hash-object", relative)
        exact(binding["git_blob_oid"], working_blob, f"MANIFEST_BLOB:{relative}")
        if require_committed:
            exact(git(root, "rev-parse", f"{head}:{relative}"), working_blob, f"MANIFEST_COMMITTED_BLOB:{relative}")
    for field in ("official_zero_world_qualification_count", "world_attempt_count", "world_build_count", "solver_step_count"):
        exact(manifest.get(field), 0, f"MANIFEST_{field.upper()}")
    for field in (
        "complete_zero_world_gate_passed",
        "physical_authorization",
        "physical_characterization_executed",
        "braking_mechanism_activated",
        "numerical_accuracy_accepted",
        "instrumented_profile_promoted",
        "stock_godot_profile_promoted",
        "recovery_world_opened",
        "prone_to_standing_world_opened",
        "q_sdk_r24_satisfied",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(manifest.get(field), False, f"MANIFEST_{field.upper()}")
    return len(bindings)


def validate_parsers_and_evaluator(root: Path, console: Path) -> tuple[int, int]:
    py_compile = run([sys.executable, "-m", "py_compile", str(root / EVALUATOR)], cwd=root)
    exact(py_compile.returncode, 0, "EVALUATOR_COMPILE")
    self_test = run([sys.executable, str(root / EVALUATOR), "--self-test"], cwd=root)
    output = self_test.stdout.decode(errors="replace")
    require("QSDK_R24D12_EVALUATOR_SELF_TEST_PASS invalid_mutations=25 accepted_adverse_outcomes=4 worlds=0 builds=0 solver_steps=0" in output, "EVALUATOR_SELF_TEST")
    gdscript = run(
        [
            str(console),
            "--headless",
            "--path",
            str(root),
            "--check-only",
            "--script",
            "res://" + WORKER,
        ],
        cwd=root,
    )
    gdscript_output = gdscript.stdout.decode(errors="replace")
    require("SCRIPT ERROR" not in gdscript_output and "ERROR:" not in gdscript_output, "GDSCRIPT_PARSE")
    runner_path = str(root / RUNNER).replace("'", "''")
    command = (
        f"$p='{runner_path}'; $t=$null; $e=$null; "
        "[void][Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e); "
        "if($e.Count -gt 0){$e | Out-String | Write-Error; exit 1}"
    )
    run(["pwsh", "-NoLogo", "-NoProfile", "-Command", command], cwd=root)
    return 25, 4


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--require-committed", action="store_true")
    parser.add_argument("--godot-source-root", type=Path, default=EXPECTED_GODOT_ROOT)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    exact(root.resolve(), EXPECTED_ROOT.resolve(), "SCRIPT_ROOT")
    godot_root = args.godot_source_root.resolve()
    exact(godot_root, EXPECTED_GODOT_ROOT.resolve(), "GODOT_ARGUMENT_ROOT")
    head = validate_repository(root, args.require_committed)
    validate_declaration(root)
    console, _ = validate_godot_source(godot_root)
    source_mutations, reuse_mutations = validate_source_mutations(root)
    invalid_mutations, adverse = validate_parsers_and_evaluator(root, console)
    bindings = validate_manifest(root, head, args.require_committed)
    print(
        "QSDK_R24D12_BRAKING_MECHANISM_FREEZE_AUDIT_PASS "
        f"bindings={bindings} source_mutations={source_mutations} "
        f"evaluator_invalid_mutations={invalid_mutations} "
        f"accepted_adverse_outcomes={adverse} runtime_reuse_mutations={reuse_mutations} "
        "worlds=0 builds=0 solver_steps=0 physical_authority=false"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AuditError as error:
        print(f"QSDK_R24D12_BRAKING_MECHANISM_FREEZE_AUDIT_FAIL code={error}")
        raise SystemExit(1)
