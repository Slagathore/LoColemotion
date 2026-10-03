"""Prospective zero-world source audit for QSDK-R24D22."""

from __future__ import annotations

import argparse
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys
from typing import Any, Sequence


REPO_ROOT = Path(__file__).resolve().parents[1]
EXPECTED_REPO_ROOT = Path(r"C:\Users\Cole\CodeStuff\games\SporeSpore").resolve()
EXPECTED_REMOTE = "https://github.com/Slagathore/sporespore.git"
IMPLEMENTATION_COMMIT = "16172e78692b4f66d0a37b5ec1e99b8ada13972c"
CONTRACT_RELATIVE = Path(
    "sdk/recovery/r24d22_engine_neutral_recovery_morphology_contract_v1.json"
)
EVALUATOR_RELATIVE = Path(
    "sdk/recovery/r24d22_engine_neutral_recovery_morphology.py"
)
PREDECESSOR_RELATIVE = Path(
    "sdk/recovery/r24d21_exact_s169_prone_geometry_feasibility_closure_v1.json"
)
PREDECESSOR_RAW_SHA256 = (
    "sha256:ba13b2c74fe98a7e2acb5eb349aeedc7ac1a4df5091a9c72ebe842a370d5f7a0"
)

IMPLEMENTATION_SOURCE_BINDINGS = [
    {
        "path": "sdk/core/src/recovery_morphology.rs",
        "byte_length": 24992,
        "raw_sha256": "sha256:9782f1956f381393b4e557dcf12fc283c3d5770af7bc4e000333771c262752e8",
    },
    {
        "path": "sdk/core/src/quadruped.rs",
        "byte_length": 17838,
        "raw_sha256": "sha256:0ad27c0c2a7658516d71ceb98fa54af42609088c0b211489c7b076367bb1265d",
    },
    {
        "path": "sdk/core/src/ffi.rs",
        "byte_length": 94209,
        "raw_sha256": "sha256:093dc6a825f7f6219a2b4d1e3f6d7740b7a424329c4809ccfc37ebfa0ce7c400",
    },
    {
        "path": "sdk/core/src/lib.rs",
        "byte_length": 13778,
        "raw_sha256": "sha256:02496cdc145e08b658bf4123797810f6d330b79c48f29da83b55c638178186ab",
    },
    {
        "path": "sdk/include/sporespore_locomotion.h",
        "byte_length": 9209,
        "raw_sha256": "sha256:86593382027885a7ceedc4ec410357e4041eedf77a70c283bb19dcce948b5b3e",
    },
    {
        "path": "sdk/python/__init__.py",
        "byte_length": 711,
        "raw_sha256": "sha256:ad0d062ff105b22468b9ae1e68e9dcf58051706718a9c2af6913aa5e79623043",
    },
    {
        "path": "sdk/python/sporespore_locomotion.py",
        "byte_length": 27293,
        "raw_sha256": "sha256:088cc0722ca640cc69ca8d6ddb119d2f6851374d098429e443ab154dc03e73b3",
    },
    {
        "path": "sdk/python/test_ctypes_smoke.py",
        "byte_length": 58373,
        "raw_sha256": "sha256:699ad27633916db7832538e998947b3e56c0c0fb2ce301c35f853c186aa233a9",
    },
    {
        "path": "sdk/versioning/c_abi_manifest_v1.json",
        "byte_length": 9733,
        "raw_sha256": "sha256:fda098b015ba31c217433bea917e64b8f70fb8552f9630b6877c67fcea0c8082",
    },
    {
        "path": "sdk/versioning/schema_registry_v1.json",
        "byte_length": 8411,
        "raw_sha256": "sha256:e95e3a5f6814adeed7846b3304f575e15eed9662161a8abba26b731584665527",
    },
    {
        "path": "sdk/versioning/test_conformance.py",
        "byte_length": 8639,
        "raw_sha256": "sha256:a5d6d8cb3d1953bcc3e6bc661df4808f5a84e01d0f6ecbff51f64b20fe9433ca",
    },
]

EXPECTED_INVENTORY = [
    *(entry["path"] for entry in IMPLEMENTATION_SOURCE_BINDINGS),
    PREDECESSOR_RELATIVE.as_posix(),
    EVALUATOR_RELATIVE.as_posix(),
    CONTRACT_RELATIVE.as_posix(),
    "tests/test_qsdk_r24d22_engine_neutral_recovery_morphology_source.py",
]

EXPECTED_MUTATIONS = [
    ("legacy_joint_geometry_typed_refusal", "unsupported_prone_geometry_infeasible"),
    ("inward_fold_typed_refusal", "unsupported_prone_geometry_infeasible"),
    ("exact_ground_boundary_accepted", "supported_exact_with_zero_minimum_limb_clearance"),
    (
        "two_binary64_steps_below_ground_boundary_refused",
        "unsupported_prone_geometry_infeasible",
    ),
    ("pose_outside_joint_limit_rejected", "SCHEMA_INVALID"),
    ("hip_anchor_outside_torso_rejected", "SCHEMA_INVALID"),
    ("base_and_recovery_identity_collision_rejected", "IDENTITY_INVALID"),
    ("unknown_top_level_field_rejected", "SCHEMA_INVALID"),
]


class AuditError(RuntimeError):
    pass


def require(condition: bool, code: str) -> None:
    if not condition:
        raise AuditError(code)


def exact(actual: object, expected: object, code: str) -> None:
    require(actual == expected, f"{code}:expected={expected!r}:actual={actual!r}")


def _reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    value: dict[str, Any] = {}
    for key, item in pairs:
        require(key not in value, f"DUPLICATE_KEY:{key}")
        value[key] = item
    return value


def load(relative: Path) -> dict[str, Any]:
    value = json.loads(
        (REPO_ROOT / relative).read_text(encoding="utf-8"),
        object_pairs_hook=_reject_duplicates,
    )
    require(isinstance(value, dict), f"JSON_ROOT:{relative.as_posix()}")
    assert isinstance(value, dict)
    return value


def raw_sha256(relative: Path) -> str:
    return "sha256:" + hashlib.sha256((REPO_ROOT / relative).read_bytes()).hexdigest()


def git(*arguments: str) -> str:
    result = subprocess.run(
        ["git", *arguments],
        cwd=REPO_ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return result.stdout.rstrip()


def audit_repository(require_committed_source: bool) -> None:
    exact(REPO_ROOT.resolve(), EXPECTED_REPO_ROOT, "REPO_ROOT")
    exact(Path(git("rev-parse", "--show-toplevel")).resolve(), EXPECTED_REPO_ROOT, "GIT_ROOT")
    exact(git("remote", "get-url", "origin"), EXPECTED_REMOTE, "REMOTE")
    exact(git("branch", "--show-current"), "main", "BRANCH")

    if require_committed_source:
        exact(git("status", "--porcelain"), "", "WORKTREE_NOT_CLEAN")
        head = git("rev-parse", "HEAD")
        exact(git("rev-parse", "HEAD^"), IMPLEMENTATION_COMMIT, "FREEZE_PARENT")
        exact(git("rev-parse", "@{upstream}"), head, "UPSTREAM_HEAD")
        remote_line = git("ls-remote", "--heads", "origin", "refs/heads/main")
        exact(remote_line.split()[0], head, "LIVE_REMOTE_HEAD")
        return

    exact(git("rev-parse", "HEAD"), IMPLEMENTATION_COMMIT, "PROSPECTIVE_PARENT")
    allowed = {
        " M docs/README.md",
        " M docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md",
        " M docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md",
        f"?? {CONTRACT_RELATIVE.as_posix()}",
        f"?? {EVALUATOR_RELATIVE.as_posix()}",
        "?? tests/test_qsdk_r24d22_engine_neutral_recovery_morphology_source.py",
    }
    observed = set(git("status", "--porcelain").splitlines())
    require(observed <= allowed, f"UNEXPECTED_PROSPECTIVE_DIRT:{sorted(observed - allowed)}")
    require(
        {
            f"?? {CONTRACT_RELATIVE.as_posix()}",
            f"?? {EVALUATOR_RELATIVE.as_posix()}",
            "?? tests/test_qsdk_r24d22_engine_neutral_recovery_morphology_source.py",
        }
        <= observed,
        "PROSPECTIVE_SOURCE_MISSING",
    )


def audit_contract() -> dict[str, Any]:
    contract = load(CONTRACT_RELATIVE)
    predecessor = load(PREDECESSOR_RELATIVE)
    exact(raw_sha256(PREDECESSOR_RELATIVE), PREDECESSOR_RAW_SHA256, "PREDECESSOR_HASH")

    exact(
        contract["schema_version"],
        "sporespore_qsdk_r24d22_engine_neutral_recovery_morphology_contract_v1",
        "SCHEMA",
    )
    exact(contract["gate_id"], "QSDK-R24D22", "GATE")
    exact(contract["declaration_parent_commit"], IMPLEMENTATION_COMMIT, "PARENT")
    exact(contract["status"], "prospective_zero_world_development_declared", "STATUS")
    exact(contract["question_class"], "development", "QUESTION_CLASS")
    for key in (
        "physical_question_declared",
        "superiority_question_declared",
        "equivalence_or_non_inferiority_question_declared",
    ):
        exact(contract[key], False, f"QUESTION_{key.upper()}")

    lineage = contract["lineage"]
    exact(lineage["predecessor_gate_id"], "QSDK-R24D21", "PREDECESSOR_GATE")
    exact(lineage["predecessor_closure_raw_sha256"], PREDECESSOR_RAW_SHA256, "LINEAGE_HASH")
    exact(lineage["predecessor_result_rewritten"], False, "LINEAGE_REWRITE")
    exact(lineage["predecessor_rerun"], False, "LINEAGE_RERUN")
    exact(predecessor["next_boundary"]["gate_id"], "QSDK-R24D22", "AUTHORIZED_NEXT")
    exact(predecessor["next_boundary"]["question_class"], "development", "AUTHORIZED_CLASS")
    exact(
        predecessor["next_boundary"]["physical_world_permitted_before_zero_world_geometry_feasibility"],
        False,
        "AUTHORIZED_ZERO_WORLD_FIRST",
    )

    implementation = contract["implementation_boundary"]
    exact(implementation["implementation_commit"], IMPLEMENTATION_COMMIT, "IMPLEMENTATION_COMMIT")
    exact(
        implementation["public_descriptor_schema"],
        "sporespore_recovery_morphology_descriptor_v1",
        "DESCRIPTOR_SCHEMA",
    )
    exact(
        implementation["public_receipt_schema"],
        "sporespore_recovery_morphology_receipt_v1",
        "RECEIPT_SCHEMA",
    )
    exact(
        implementation["public_prone_geometry_schema"],
        "sporespore_recovery_prone_geometry_receipt_v1",
        "GEOMETRY_SCHEMA",
    )
    exact(
        implementation["c_abi_symbol"],
        "ss_compile_recovery_morphology_v1_json",
        "C_ABI_SYMBOL",
    )
    exact(implementation["valid_but_unsupported_is_successful_typed_refusal"], True, "TYPED_REFUSAL")
    exact(implementation["malformed_input_is_core_error"], True, "MALFORMED_ERROR")
    exact(implementation["host_model_construction_implemented"], False, "HOST_MODEL")
    exact(implementation["adapter_mapping_implemented"], False, "ADAPTER_MAPPING")

    exact(contract["implementation_source_bindings"], IMPLEMENTATION_SOURCE_BINDINGS, "SOURCE_BINDINGS")
    for binding in IMPLEMENTATION_SOURCE_BINDINGS:
        relative = Path(binding["path"])
        source = REPO_ROOT / relative
        require(source.is_file(), f"BOUND_SOURCE_MISSING:{relative.as_posix()}")
        exact(source.stat().st_size, binding["byte_length"], f"BOUND_SIZE:{relative.as_posix()}")
        exact(raw_sha256(relative), binding["raw_sha256"], f"BOUND_HASH:{relative.as_posix()}")

    population = contract["evidence_population"]
    exact(population["kind"], "finite_exact_reference_plus_declared_negative_controls", "POPULATION_KIND")
    exact(population["positive_descriptor_count"], 1, "POPULATION_COUNT")
    exact(population["recovery_morphology_id"], "qsdk_r24_recovery_s169_v1", "RECOVERY_ID")
    exact(
        population["recovery_descriptor_sha256"],
        "sha256:431a9c8001931e751bb2f1f2750c31650dd2d994575a736c53adbef1b27a71f6",
        "RECOVERY_DESCRIPTOR_HASH",
    )
    exact(
        population["base_descriptor_sha256"],
        "sha256:ae7a0872b8b15dfb294c388931899cf82822293417d125dd72ee2a5a847e09e0",
        "BASE_DESCRIPTOR_HASH",
    )
    exact(
        population["base_morphology_spec_sha256"],
        "sha256:30893a75e8362dcab69f0fb46b0560cacbe5d5c034cb0152e67eb520ff35f45e",
        "BASE_MORPHOLOGY_HASH",
    )
    exact(
        population["recovery_morphology_spec_sha256"],
        "sha256:926551af3a72eb1fd1f3b71bfb103587a0b906a116775551a2463792e2c160f9",
        "RECOVERY_MORPHOLOGY_HASH",
    )
    exact(
        population["joint_authority"],
        {
            "hip_anchor_parent_y_m": 0.0,
            "hip_limit_magnitude_rad": 1.6,
            "knee_limit_magnitude_rad": 1.1,
        },
        "JOINT_AUTHORITY",
    )
    exact(
        population["canonical_prone_pose"],
        {
            "front_hip_angle_rad": 1.55,
            "front_knee_angle_rad": 1.1,
            "rear_hip_angle_rad": -1.55,
            "rear_knee_angle_rad": -1.1,
        },
        "PRONE_POSE",
    )
    for key in (
        "arbitrary_morphology_recovery_claimed",
        "continuous_morphology_recovery_claimed",
        "population_inference_claimed",
    ):
        exact(population[key], False, f"POPULATION_{key.upper()}")

    rule = contract["decision_rule"]
    exact(rule["feasibility_threshold_m"], 0.0, "THRESHOLD")
    require(bool(rule["threshold_provenance"].strip()), "THRESHOLD_PROVENANCE")
    require(bool(rule["threshold_adequacy"].strip()), "THRESHOLD_ADEQUACY")
    require(bool(rule["outward_fold_rule"].strip()), "OUTWARD_RULE")
    require(bool(rule["positive_rule"].strip()), "POSITIVE_RULE")
    require(bool(rule["typed_refusal_rule"].strip()), "REFUSAL_RULE")
    require(bool(rule["malformed_rule"].strip()), "MALFORMED_RULE")
    exact(rule["new_threshold_count"], 1, "THRESHOLD_COUNT")
    exact(rule["new_margin_count"], 0, "MARGIN_COUNT")
    exact(rule["post_outcome_rethresholding_permitted"], False, "RETHRESHOLD")

    exact(
        [(item["mutation_id"], item["expected"]) for item in contract["mutation_controls"]],
        EXPECTED_MUTATIONS,
        "MUTATION_CONTROLS",
    )

    execution = contract["execution_contract"]
    exact(execution["evaluator_path"], EVALUATOR_RELATIVE.as_posix(), "EVALUATOR_PATH")
    exact(
        execution["source_audit_path"],
        "tests/test_qsdk_r24d22_engine_neutral_recovery_morphology_source.py",
        "AUDIT_PATH",
    )
    exact(execution["engine_import_permitted"], False, "ENGINE_IMPORT")
    for key in (
        "model_construction_count",
        "world_attempt_count",
        "world_build_count",
        "solver_step_count",
        "held_out_cell_access_count",
        "held_out_selector_invocation_count",
    ):
        exact(execution[key], 0, f"EXECUTION_{key.upper()}")
    exact(execution["physics_state_modified"], False, "EXECUTION_PHYSICS")

    exact(contract["source_inventory"], EXPECTED_INVENTORY, "SOURCE_INVENTORY")
    for item in EXPECTED_INVENTORY:
        require((REPO_ROOT / item).is_file(), f"SOURCE_MISSING:{item}")

    claim = contract["claim_boundary"]
    exact(claim["engine_neutral_recovery_morphology_surface_implemented"], True, "IMPLEMENTED")
    exact(claim["legacy_s169_identity_preserved"], True, "LEGACY_PRESERVED")
    for key in (
        "exact_prone_geometry_result_observed",
        "typed_refusal_controls_observed",
        "native_initializer_implemented",
        "controller_compatibility_proven",
        "physical_question_opened",
        "controller_physical_viability_proven",
        "prone_to_standing_claimed",
        "held_out_validation_claimed",
        "cross_engine_recovery_claimed",
        "cross_engine_equivalence_claimed",
        "sdk1_milestone_advanced",
        "physical_acceptance_authority",
        "release_authority",
    ):
        exact(claim[key], False, f"CLAIM_{key.upper()}")
    return contract


def require_markers(relative: Path, markers: Sequence[str]) -> str:
    source = (REPO_ROOT / relative).read_text(encoding="utf-8")
    missing = [marker for marker in markers if marker not in source]
    require(not missing, f"SOURCE_MARKERS:{relative.as_posix()}:{missing}")
    return source


def audit_implementation_sources() -> None:
    recovery_source = require_markers(
        Path("sdk/core/src/recovery_morphology.rs"),
        (
            '"sporespore_recovery_morphology_descriptor_v1"',
            '"sporespore_recovery_morphology_receipt_v1"',
            '"sporespore_recovery_prone_geometry_receipt_v1"',
            '"qsdk_r24_recovery_s169_v1"',
            "pub struct RecoveryJointAuthorityV1",
            "pub struct RecoveryCanonicalPronePoseV1",
            "pub struct RecoveryMorphologyDescriptorV1",
            "pub enum RecoveryMorphologySupportStatusV1",
            "SupportedExact",
            "UnsupportedProneGeometryInfeasible",
            "pub fn compile_recovery_morphology_v1(",
            "fn legacy_s169_compiler_identity_remains_exact()",
            "legacy_base_descriptor_preserved: true",
            "legacy_base_morphology_spec_preserved: true",
            "world_build_count: 0",
            "physics_state_modified: false",
            "physical_acceptance_authority: false",
            "release_authority: false",
        ),
    )
    for forbidden in ("use mujoco", "use rapier", "use godot", "mujoco::", "rapier::", "godot::"):
        require(forbidden not in recovery_source.lower(), f"ENGINE_IMPORT:{forbidden}")

    require_markers(
        Path("sdk/core/src/quadruped.rs"),
        (
            "pub(crate) struct QuadrupedJointAuthority",
            "const LEGACY_JOINT_AUTHORITY",
            "pub(crate) fn morphology_spec_with_joint_authority(",
            "morphology_spec_with_joint_authority(geometry, LEGACY_JOINT_AUTHORITY)",
        ),
    )
    require_markers(
        Path("sdk/core/src/ffi.rs"),
        (
            "pub unsafe extern \"C\" fn ss_compile_recovery_morphology_v1_json(",
            "compile_recovery_morphology_v1",
        ),
    )
    require_markers(
        Path("sdk/include/sporespore_locomotion.h"),
        ("SS_API ss_status ss_compile_recovery_morphology_v1_json(",),
    )
    require_markers(
        Path("sdk/python/sporespore_locomotion.py"),
        (
            '"ss_compile_recovery_morphology_v1_json"',
            "def compile_recovery_morphology_v1(",
            "def r24d22_recovery_s169_morphology(",
        ),
    )
    require_markers(
        Path("sdk/python/test_ctypes_smoke.py"),
        (
            "self.core.compile_recovery_morphology_v1(descriptor)",
            'self.assertEqual(receipt["support_status"], "supported_exact")',
            '"unsupported_prone_geometry_infeasible"',
        ),
    )

    manifest = load(Path("sdk/versioning/c_abi_manifest_v1.json"))
    symbols = manifest["symbols"]
    exact(len(symbols), 36, "ABI_SYMBOL_COUNT")
    names = [entry["name"] for entry in symbols]
    exact(len(names), len(set(names)), "ABI_SYMBOL_UNIQUENESS")
    recovery_symbols = [
        entry for entry in symbols if entry["name"] == "ss_compile_recovery_morphology_v1_json"
    ]
    exact(len(recovery_symbols), 1, "ABI_RECOVERY_SYMBOL_COUNT")
    exact(
        recovery_symbols[0],
        {
            "name": "ss_compile_recovery_morphology_v1_json",
            "signature_class": "json_input_buffer_v1",
            "since": "0.1.0",
            "status": "active",
            "input_schema": "sporespore_recovery_morphology_descriptor_v1",
        },
        "ABI_RECOVERY_SYMBOL",
    )

    registry = load(Path("sdk/versioning/schema_registry_v1.json"))
    schemas = registry["schemas"]
    exact(len(schemas), 52, "SCHEMA_COUNT")
    schema_ids = [entry["schema_id"] for entry in schemas]
    exact(len(schema_ids), len(set(schema_ids)), "SCHEMA_UNIQUENESS")
    require(
        {
            "sporespore_recovery_morphology_descriptor_v1",
            "sporespore_recovery_morphology_receipt_v1",
            "sporespore_recovery_prone_geometry_receipt_v1",
        }
        <= set(schema_ids),
        "RECOVERY_SCHEMAS_MISSING",
    )
    require_markers(
        Path("sdk/versioning/test_conformance.py"),
        (
            "self.assertEqual(len(manifest_symbols), 36)",
            '"ss_compile_recovery_morphology_v1_json"',
        ),
    )


def audit_evaluator() -> None:
    evaluator = require_markers(
        EVALUATOR_RELATIVE,
        (
            'SCHEMA_VERSION = (\n    "sporespore_qsdk_r24d22_engine_neutral_recovery_morphology_decision_v1"',
            "def evaluate(core: LocomotionCore) -> dict[str, Any]:",
            "core.compile_recovery_morphology_v1(descriptor)",
            'exact(exact_receipt["support_status"], "supported_exact", "EXACT_SUPPORT")',
            '"legacy_joint_geometry_typed_refusal"',
            '"inward_fold_typed_refusal"',
            '"exact_ground_boundary_accepted"',
            '"two_binary64_steps_below_ground_boundary_refused"',
            '"pose_outside_joint_limit_rejected"',
            '"hip_anchor_outside_torso_rejected"',
            '"base_and_recovery_identity_collision_rejected"',
            '"unknown_top_level_field_rejected"',
            '"model_construction_count": 0',
            '"world_build_count": 0',
            '"solver_step_count": 0',
            '"held_out_cell_access_count": 0',
            '"prone_to_standing_claimed": False',
            '"release_authority": False',
        ),
    )
    ast.parse(evaluator)
    compile(evaluator, str(REPO_ROOT / EVALUATOR_RELATIVE), "exec")
    lowered = evaluator.lower()
    for forbidden in ("import mujoco", "import rapier", "import godot", "mujoco.", "rapier.", "godot."):
        require(forbidden not in lowered, f"EVALUATOR_ENGINE_IMPORT:{forbidden}")


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(description=__doc__)
    value.add_argument("--require-committed-source", action="store_true")
    return value


def main(argv: Sequence[str] | None = None) -> int:
    arguments = parser().parse_args(argv)
    audit_repository(arguments.require_committed_source)
    audit_contract()
    audit_implementation_sources()
    audit_evaluator()
    print(
        "QSDK_R24D22_RECOVERY_MORPHOLOGY_SOURCE_PASS question=development "
        "population=1 mutations=8 threshold_m=0 margins=0 engines=0 models=0 "
        "worlds=0 solver_steps=0 heldout_access=0 outcome_observed=False"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as error:
        print(f"QSDK_R24D22_RECOVERY_MORPHOLOGY_SOURCE_FAIL {error}", file=sys.stderr)
        raise SystemExit(1) from error
