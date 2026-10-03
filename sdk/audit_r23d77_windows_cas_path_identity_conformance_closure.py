"""Executable audit for the immutable R23D77 development closure."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
from typing import Any, Mapping


ROOT = Path(__file__).resolve().parent
REPO_ROOT = ROOT.parent
TURNING_ROOT = ROOT / "turning"
sys.path.insert(0, str(TURNING_ROOT))

import materialize_r23d77_windows_cas_path_identity_conformance_closure as materializer  # noqa: E402


CLOSURE_PATH = (
    TURNING_ROOT / "r23d77_windows_cas_path_identity_conformance_closure_v1.json"
)


class R23D77AuditError(RuntimeError):
    """The closure or a mutation is not classified exactly."""


def _require(condition: bool, code: str) -> None:
    if not condition:
        raise R23D77AuditError(code)


def validate_closure(closure: Mapping[str, Any]) -> None:
    _require(
        closure.get("schema_version")
        == "sporespore_qsdk_r23d77_windows_cas_path_identity_conformance_closure_v1",
        "SCHEMA",
    )
    _require(
        closure.get("status")
        == "closed_positive_complete_zero_world_retained_receipt_conformance",
        "STATUS",
    )
    _require(closure.get("question_class") == "development", "QUESTION_CLASS")
    source = closure.get("source_authority")
    _require(isinstance(source, Mapping), "SOURCE")
    _require(source.get("source_commit") == materializer.SOURCE_COMMIT, "SOURCE_COMMIT")
    _require(source.get("source_tree_git_oid") == materializer.SOURCE_TREE, "SOURCE_TREE")
    _require(source.get("source_was_clean_pushed_and_live_equal") is True, "SOURCE_PUSH")
    bindings = source.get("source_bindings")
    _require(isinstance(bindings, list) and len(bindings) == 8, "SOURCE_BINDINGS")
    retained = closure.get("retained_result")
    _require(isinstance(retained, Mapping), "RETAINED_RESULT")
    result = retained.get("result")
    _require(isinstance(result, Mapping), "RESULT_BINDING")
    _require(result.get("raw_sha256") == materializer.RESULT_SHA256, "RESULT_SHA")
    _require(result.get("byte_length") == materializer.RESULT_BYTE_LENGTH, "RESULT_BYTES")
    lineage = closure.get("immutable_lineage")
    _require(isinstance(lineage, Mapping), "LINEAGE")
    _require(lineage.get("r23d76_historical_result_reinterpreted") is False, "REWRITE")
    _require(lineage.get("r23d76_campaign_and_seed_consumed") is True, "CONSUMED")
    _require(
        lineage.get("r23d76_same_identity_or_selective_rerun_allowed") is False,
        "RERUN",
    )
    _require(lineage.get("first_r23d77_pre_receipt_failure_preserved") is True, "FAILURE")
    observed = closure.get("observed_conformance")
    _require(isinstance(observed, Mapping), "OBSERVED")
    for field, expected in {
        "complete_rapier_receipt_population_count": 3,
        "extended_receipt_acceptance_count": 3,
        "ordinary_receipt_acceptance_count": 3,
        "complete_frozen_byte_verifier_replay_count": 6,
        "negative_control_count": 12,
        "negative_control_rejection_count": 12,
        "trace_payload_byte_count_reverified": 133631444,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "behavior_measurement_invocation_count": 0,
    }.items():
        _require(observed.get(field) == expected, f"OBSERVED:{field}")
    cells = observed.get("cells")
    _require(isinstance(cells, list) and len(cells) == 3, "CELLS")
    for cell, expected in zip(cells, materializer.EXPECTED_CELLS, strict=True):
        _require(isinstance(cell, Mapping), "CELL")
        _require(cell.get("cell_id") == expected["cell_id"], "CELL_ID")
        _require(cell.get("trace_sha256") == expected["trace_sha256"], "TRACE_SHA")
        _require(cell.get("frozen_failure_codes") == [materializer.PATH_FAILURE], "OLD_FAIL")
        _require(cell.get("successor_failure_codes") == [], "NEW_FAIL")
        _require(cell.get("ordinary_spelling_failure_codes") == [], "ORDINARY_FAIL")
        _require(cell.get("payload_same_existing_file") is True, "PAYLOAD_IDENTITY")
        _require(cell.get("manifest_same_existing_file") is True, "MANIFEST_IDENTITY")
        controls = cell.get("negative_controls")
        _require(isinstance(controls, Mapping) and len(controls) == 4, "CONTROLS")
        _require(
            all(
                failures == [materializer.FILE_IDENTITY_FAILURE]
                for failures in controls.values()
            ),
            "CONTROL_FAILURES",
        )
    interpretation = closure.get("interpretation")
    _require(isinstance(interpretation, Mapping), "INTERPRETATION")
    _require(
        interpretation.get(
            "windows_cas_existing_file_identity_seam_closed_for_future_successors"
        )
        is True,
        "SEAM",
    )
    _require(interpretation.get("r23d76_reclassified") is False, "RECLASSIFICATION")
    _require(interpretation.get("finite_turning_evidence_created") is False, "TURNING")
    _require(interpretation.get("fresh_finite_decision_still_required") is True, "NEXT")
    claims = closure.get("claims")
    _require(isinstance(claims, Mapping), "CLAIMS")
    _require(claims.get("r23d77_path_identity_seam_closed") is True, "SEAM_CLAIM")
    for false_claim in (
        "r23d76_reclassified",
        "rapier_turning",
        "finite_three_engine_turning",
        "portable_basic_turning",
        "q_sdk_r23_satisfied",
        "cross_engine_equivalence",
        "population_robustness",
        "prone_to_standing",
        "physical_acceptance_authority",
        "release_authority",
    ):
        _require(claims.get(false_claim) is False, f"FALSE_CLAIM:{false_claim}")


def _mutation_controls(closure: Mapping[str, Any]) -> int:
    mutations: list[tuple[str, Any]] = [
        ("status", "closed_positive_turning"),
        ("question_class", "finite_decision"),
        ("source_authority.source_commit", "0" * 40),
        ("retained_result.result.raw_sha256", "sha256:" + ("0" * 64)),
        ("immutable_lineage.r23d76_historical_result_reinterpreted", True),
        ("observed_conformance.complete_rapier_receipt_population_count", 2),
        ("observed_conformance.negative_control_rejection_count", 11),
        ("observed_conformance.world_build_count", 1),
        ("observed_conformance.cells.0.successor_failure_codes", ["unexpected"]),
        ("observed_conformance.cells.1.payload_same_existing_file", False),
        ("interpretation.finite_turning_evidence_created", True),
        ("claims.q_sdk_r23_satisfied", True),
        ("claims.rapier_turning", True),
        ("claims.release_authority", True),
    ]
    rejected = 0
    for dotted_path, value in mutations:
        mutated = copy.deepcopy(dict(closure))
        parts = dotted_path.split(".")
        target: Any = mutated
        for part in parts[:-1]:
            target = target[int(part)] if isinstance(target, list) else target[part]
        final = parts[-1]
        if isinstance(target, list):
            target[int(final)] = value
        else:
            target[final] = value
        try:
            validate_closure(mutated)
        except R23D77AuditError:
            rejected += 1
    _require(rejected == len(mutations), "MUTATION_ACCEPTED")
    return rejected


def main() -> int:
    try:
        closure = json.loads(CLOSURE_PATH.read_text(encoding="utf-8"))
        _require(closure == materializer.build_closure(), "MATERIALIZATION_DRIFT")
        validate_closure(closure)
        mutations = _mutation_controls(closure)
        print(
            "QSDK_R23D77_CLOSURE_AUDIT_PASS "
            f"receipts=3 negatives=12 mutations={mutations} worlds=0"
        )
        return 0
    except (
        OSError,
        UnicodeError,
        json.JSONDecodeError,
        materializer.R23D77ClosureError,
        R23D77AuditError,
    ) as error:
        print(f"QSDK_R23D77_CLOSURE_AUDIT_FAIL {error}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
