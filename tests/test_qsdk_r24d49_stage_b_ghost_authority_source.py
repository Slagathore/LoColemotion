"""Zero-world source gate for the R24D49-B ghost-authority repair."""

from __future__ import annotations

from copy import deepcopy
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from sdk.conformance.content_addressed_zero_world_closure import (  # noqa: E402
    ClosureAuditError,
    exact,
    git,
    load,
    require,
    require_ordered_markers,
    sha256,
    source_bytes,
    verify_exact_paths,
    verify_legacy_live_gate_paths,
)


AUTHORITY_PATH = ROOT / (
    "sdk/recovery/r24d49_stage_b_ghost_authority_contract_v1.json"
)
QUALIFICATION_CONTRACT_PATH = ROOT / (
    "sdk/recovery/r24d49_rapier_runtime_binding_contract_v1.json"
)
SHARED_RUNNER_PATH = ROOT / "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1"
WRAPPER_PATH = ROOT / "sdk/run_qsdk_r24d49_rapier_recovery_energy_v2.ps1"
GATE = "QSDK-R24D49"
RUNTIME_BINDING = (
    "sha256:946d9f1dda22658c989b59daf7f75b32d82586009288baca0207b8ca8c01ea28"
)


def _repository_text_sha(path: Path) -> str:
    value = path.read_text(encoding="utf-8").replace("\r\n", "\n")
    return sha256(value.encode("utf-8"))


def _valid_authority(value: dict[str, object]) -> bool:
    try:
        ghost = value["ghost_authority"]
        qualification = value["qualification_dependency"]
        expected_paths = [
            path
            for path in load(QUALIFICATION_CONTRACT_PATH)["physical_runner"][
                "qualification_source_code_paths"
            ]
            if path not in value["authority_only_qualified_path_exclusions"]
        ]
        closure_path = ROOT / str(ghost["closure_path"])
        closure = load(closure_path)
        receipt_path = (
            Path(closure["physical_attempt"]["evidence_root"])
            / closure["physical_attempt"]["receipt"]["path"]
        )
        return (
            _repository_text_sha(closure_path) == ghost["closure_raw_sha256"]
            and sha256(receipt_path.read_bytes()) == ghost["receipt_raw_sha256"]
            and qualification["runtime_binding_sha256"] == RUNTIME_BINDING
            and value["qualified_unchanged_source_paths"] == expected_paths
        )
    except (KeyError, OSError, TypeError):
        return False


def audit() -> None:
    authority = load(AUTHORITY_PATH)
    qualification_contract = load(QUALIFICATION_CONTRACT_PATH)
    verify_exact_paths(authority, {
        "schema_version": (
            "sporespore_qsdk_r24d49_stage_b_ghost_authority_contract_v1"
        ),
        "gate_id": GATE,
        "stage_id": "R24D49-B",
        "question_class": "development_launch_authority_repair",
        "physical_question_declared": True,
        "superiority_question_declared": False,
        "equivalence_or_non_inferiority_question_declared": False,
        "population_inference_declared": False,
        "observed_pre_world_rejection.source_commit": (
            "d079da0b3fd6049e12ee8b509819680887d55045"
        ),
        "observed_pre_world_rejection.error": (
            "QSDK_R24D48_PHYSICAL:PASSING_SAME_SOURCE_GHOST_COUNT:0"
        ),
        "observed_pre_world_rejection.operation_lock_entered": False,
        "observed_pre_world_rejection.physical_attempt_record_created": False,
        "observed_pre_world_rejection.evidence_directory_created": False,
        "observed_pre_world_rejection.model_construction_count": 0,
        "observed_pre_world_rejection.world_attempt_count": 0,
        "observed_pre_world_rejection.world_build_count": 0,
        "observed_pre_world_rejection.solver_step_count": 0,
        "observed_pre_world_rejection.outer_step_count": 0,
        "observed_pre_world_rejection.paired_development_attempt_consumed": False,
        "qualification_dependency.runtime_binding_sha256": RUNTIME_BINDING,
        "qualification_dependency.may_be_requalified": False,
        "ghost_authority.source_commit": (
            "686cf0ab5ff41c20504118e202b2329b264830f2"
        ),
        "ghost_authority.actual_total_outer_steps": 4,
        "ghost_authority.integration_ghost_passed": True,
        "ghost_authority.same_identity_ghost_rerun_permitted": False,
        "zero_world_source_gate.required_check_count": 12,
        "zero_world_source_gate.required_mutation_rejection_count": 4,
        "zero_world_source_gate.maximum_physical_steps_authorized_by_source_gate": 0,
        "zero_world_source_gate.model_construction_count": 0,
        "zero_world_source_gate.world_attempt_count": 0,
        "zero_world_source_gate.world_build_count": 0,
        "zero_world_source_gate.solver_step_count": 0,
        "zero_world_source_gate.physics_state_modified": False,
        "paired_development.maximum_attempt_count": 1,
        "paired_development.maximum_outer_steps_per_arm": 1200,
        "paired_development.maximum_total_outer_steps": 2400,
        "paired_development.result_may_establish_population_or_release_claim": False,
    }, "AUTHORITY")

    exclusions = authority["authority_only_qualified_path_exclusions"]
    exact(exclusions, [
        "sdk/run_qsdk_r24d48_rapier_recovery_energy_v2.ps1",
        "sdk/run_qsdk_r24d49_rapier_recovery_energy_v2.ps1",
    ], "AUTHORITY_ONLY_EXCLUSIONS")
    expected_paths = [
        path
        for path in qualification_contract["physical_runner"][
            "qualification_source_code_paths"
        ]
        if path not in exclusions
    ]
    exact(authority["qualified_unchanged_source_paths"], expected_paths,
          "QUALIFIED_SOURCE_POPULATION")
    for predecessor in (
        authority["qualification_dependency"]["source_commit"],
        authority["ghost_authority"]["source_commit"],
    ):
        process = subprocess.run(
            ["git", "diff", "--quiet", predecessor, "HEAD", "--", *expected_paths],
            cwd=ROOT,
            check=False,
        )
        exact(process.returncode, 0, f"PHYSICAL_SOURCE_DRIFT:{predecessor}")

    qualification_closure = load(
        ROOT / authority["qualification_dependency"]["closure_path"]
    )
    exact(
        _repository_text_sha(
            ROOT / authority["qualification_dependency"]["closure_path"]
        ),
        authority["qualification_dependency"]["closure_raw_sha256"],
        "QUALIFICATION_CLOSURE_HASH",
    )
    verify_exact_paths(qualification_closure, {
        "source.commit": authority["qualification_dependency"]["source_commit"],
        "qualification.runtime_binding_sha256": RUNTIME_BINDING,
        "qualification.isolated_harness_cargo_lock.raw_sha256": (
            authority["qualification_dependency"]["cargo_lock_sha256"]
        ),
        "decision.official_zero_world_qualification_passed": True,
    }, "QUALIFICATION")

    ghost_claim = authority["ghost_authority"]
    ghost_path = ROOT / ghost_claim["closure_path"]
    ghost = load(ghost_path)
    exact(_repository_text_sha(ghost_path), ghost_claim["closure_raw_sha256"],
          "GHOST_CLOSURE_HASH")
    verify_exact_paths(ghost, {
        "source.commit": ghost_claim["source_commit"],
        "closure_status": ghost_claim["closure_status"],
        "physical_attempt.evidence_root": ghost_claim["evidence_root"].replace("/", "\\"),
        "physical_attempt.receipt.raw_sha256": ghost_claim["receipt_raw_sha256"],
        "physical_attempt.result.raw_sha256": ghost_claim["result_raw_sha256"],
        "physical_attempt.environment_sha256": ghost_claim["environment_sha256"],
        "physical_attempt.actual_total_outer_steps": 4,
        "decision.integration_ghost_passed": True,
        "decision.paired_development_authorized": True,
        "claim_boundary.prone_to_standing_claimed": False,
    }, "GHOST")
    evidence_root = Path(ghost["physical_attempt"]["evidence_root"])
    for artifact, raw_field in (("receipt", "receipt_raw_sha256"),
                                ("result", "result_raw_sha256")):
        path = evidence_root / ghost["physical_attempt"][artifact]["path"]
        exact(sha256(path.read_bytes()), ghost_claim[raw_field],
              f"GHOST_{artifact.upper()}")

    require(_valid_authority(authority), "POSITIVE_AUTHORITY")
    mutations = []
    for mutation_id, update in (
        ("wrong_ghost_closure_digest", lambda value: value["ghost_authority"].update(
            {"closure_raw_sha256": "sha256:" + "0" * 64}
        )),
        ("wrong_ghost_receipt_digest", lambda value: value["ghost_authority"].update(
            {"receipt_raw_sha256": "sha256:" + "0" * 64}
        )),
        ("wrong_runtime_binding", lambda value: value["qualification_dependency"].update(
            {"runtime_binding_sha256": "sha256:" + "0" * 64}
        )),
        ("missing_qualified_source_path", lambda value: value[
            "qualified_unchanged_source_paths"
        ].pop()),
    ):
        mutated = deepcopy(authority)
        update(mutated)
        mutations.append((mutation_id, not _valid_authority(mutated)))
    exact([name for name, _ in mutations],
          authority["zero_world_source_gate"]["mutation_ids"], "MUTATION_IDS")
    require(all(rejected for _, rejected in mutations), "MUTATION_REJECTIONS")

    runner = SHARED_RUNNER_PATH.read_text(encoding="utf-8")
    require_ordered_markers(runner, (
        "$stageAuthoritySupplied",
        "STAGE_AUTHORITY_CONTRACT",
        "STAGE_AUTHORITY_SOURCE_POPULATION",
        "STAGE_AUTHORITY_GHOST_CLOSURE",
        "STAGE_AUTHORITY_PHYSICAL_CODE_DRIFT",
        "STAGE_AUTHORITY_GHOST_RECEIPT_IDENTITY",
        "Enter-SporeSporeLocomotionOperationLock",
        "physical_attempt.json",
    ), "RUNNER_PRE_WORLD_ORDER")
    wrapper = WRAPPER_PATH.read_text(encoding="utf-8")
    contract_sha = _repository_text_sha(AUTHORITY_PATH)
    require_ordered_markers(wrapper, (
        'if ($Mode -ceq "Development")',
        authority["zero_world_source_gate"]["audit_path"].replace(
            "tests/test_qsdk_r24d49_stage_b_ghost_authority_source.py",
            "sdk/recovery/r24d49_stage_b_ghost_authority_contract_v1.json",
        ),
        contract_sha,
        "& $shared @forward",
    ), "WRAPPER_AUTHORITY_BINDING")

    checks = {
        "contract_identity": True,
        "pre_world_rejection_preserved": True,
        "qualification_closure_bound": True,
        "runtime_binding_and_cargo_lock_bound": True,
        "ghost_closure_bound": True,
        "ghost_receipt_bound": True,
        "ghost_result_bound": True,
        "environment_bound": True,
        "qualified_source_population_exact": True,
        "qualified_physical_source_unchanged": True,
        "runner_refuses_before_operation_lock": True,
        "wrapper_content_addresses_authority": True,
    }
    exact((len(checks), sum(checks.values())), (12, 12), "CHECKS")
    verify_exact_paths(authority["claim_boundary"], {
        "historical_ghost_rewritten": False,
        "historical_threshold_changed": False,
        "historical_selector_changed": False,
        "historical_evaluator_changed": False,
        "controller_changed": False,
        "morphology_changed": False,
        "initializer_changed": False,
        "additional_physical_canary_required": False,
        "paired_development_attempt_consumed": False,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }, "CLAIM")

    audit_relative = Path(__file__).relative_to(ROOT).as_posix()
    publication_commits = git(
        ROOT,
        "log",
        "--diff-filter=A",
        "--format=%H",
        "--",
        audit_relative,
    ).splitlines()
    exact(len(publication_commits), 1, "PUBLICATION_COUNT")
    publication = publication_commits[0]
    exact(
        publication,
        "5b00ad16943e552f851ef31c4032bb6140362b15",
        "PUBLICATION_COMMIT",
    )

    live = {
        "r24d49_stage_b_ghost_authority_contract_path": (
            AUTHORITY_PATH.relative_to(ROOT).as_posix()
        ),
        "r24d49_stage_b_ghost_authority_contract_raw_sha256": (
            sha256(source_bytes(
                ROOT,
                publication,
                AUTHORITY_PATH.relative_to(ROOT).as_posix(),
            ))
        ),
        "r24d49_stage_b_ghost_authority_source_audit_path": (
            audit_relative
        ),
        "r24d49_stage_b_ghost_authority_source_audit_raw_sha256": (
            sha256(source_bytes(ROOT, publication, audit_relative))
        ),
        "r24d49_stage_b_pre_world_rejection_preserved": True,
        "r24d49_stage_b_pre_world_rejection_consumed_physical_attempt": False,
        "r24d49_stage_b_qualified_physical_source_unchanged": True,
        "r24d49_stage_b_ghost_authority_zero_world_source_gate_passed": True,
        "r24d49_stage_b_authorized": True,
        "r24d49_paired_development_attempt_consumed": False,
        "physical_execution_authorized": True,
        "prone_to_standing_claimed": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    verify_legacy_live_gate_paths(
        ROOT,
        ["sdk/release/quadruped_release_contract.json",
         "sdk/release/quadruped_support_matrix.json"],
        "QSDK-R24D45",
        live,
        revision=publication,
    )
    print(
        "QSDK_R24D49_STAGE_B_GHOST_AUTHORITY_SOURCE_PASS "
        "checks=12/12 mutations=4 physical=false models=0 worlds=0 "
        "solver_steps=0 development_attempt_consumed=false"
    )


if __name__ == "__main__":
    try:
        audit()
    except (
        ClosureAuditError, OSError, KeyError, IndexError, TypeError, ValueError,
        subprocess.SubprocessError,
    ) as error:
        print(
            "QSDK_R24D49_STAGE_B_GHOST_AUTHORITY_SOURCE_FAIL "
            f"{error}", file=sys.stderr,
        )
        raise SystemExit(1) from error
