"""Run MJSC0-MJSC7 pure zero-world semantic-ceiling conformance."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import subprocess
from pathlib import Path
from typing import Any, Callable

from .mujoco_warp_equivalence_calibration import REQUIRED_METRICS, canonical_json_bytes
from .mujoco_warp_semantic_ceiling_readiness import (
    BOUND_SOURCE_ASSERTION_SCHEMA,
    CONTRACT_PATH,
    EXPECTED_UNITS,
    RECORD_SCHEMA,
    SemanticCeilingReadinessError,
    compile_current_unresolved_inventory,
    compile_semantic_ceiling_inventory,
    file_sha256,
    load_readiness_contract,
)


SDK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = SDK_ROOT.parent
REPORT_SCHEMA = "sporespore_mujoco_warp_semantic_ceiling_conformance_report_v1"


class SemanticCeilingConformanceFailure(RuntimeError):
    """MJSC0-MJSC7 conformance failed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise SemanticCeilingConformanceFailure(f"{code}:{detail}")


def _git(*arguments: str) -> tuple[bool, str]:
    result = subprocess.run(
        ["git", "-C", str(REPO_ROOT), *arguments],
        check=False,
        capture_output=True,
        text=True,
        encoding="utf-8",
    )
    return result.returncode == 0, result.stdout.strip()


def _source_receipt() -> dict[str, Any]:
    head_ok, head = _git("rev-parse", "HEAD")
    origin_ok, origin = _git("rev-parse", "origin/main")
    status_ok, status = _git("status", "--porcelain=v1", "--untracked-files=all")
    return {
        "commit": head if head_ok else None,
        "origin_main": origin if origin_ok else None,
        "clean": status_ok and status == "",
        "matches_origin_main": head_ok and origin_ok and head == origin,
        "status_entries": status.splitlines() if status else [],
    }


def _fixture_source(
    metric_id: str,
    semantic_source: str,
    semantic_ceiling: float,
) -> tuple[str, bytes]:
    path = f"sdk/adaptation_provider/fixtures/{metric_id}.json"
    payload = canonical_json_bytes(
        {
            "fixture_only": True,
            "metric_id": metric_id,
            "preservation_check": "synthetic_compiler_canary",
            "ceiling_assertion": {
                "schema_version": BOUND_SOURCE_ASSERTION_SCHEMA,
                "metric_id": metric_id,
                "unit": EXPECTED_UNITS[metric_id],
                "semantic_ceiling": semantic_ceiling,
                "semantic_source": semantic_source,
            },
        }
    )
    return path, payload


def semantic_ceiling_fixture() -> tuple[list[dict[str, Any]], dict[str, bytes]]:
    sources = (
        "canonical_state_or_action_normalization_resolution",
        "canonical_state_or_action_normalization_resolution",
        "downstream_training_label_stability",
        "safety_gate_guard_band",
        "contact_event_label_tolerance",
    )
    ceilings = (0.001, 0.002, 0.003, 0.004, 1.0)
    records: list[dict[str, Any]] = []
    source_bytes: dict[str, bytes] = {}
    for metric_id, source, ceiling in zip(
        REQUIRED_METRICS, sources, ceilings, strict=True
    ):
        path, payload = _fixture_source(metric_id, source, ceiling)
        source_bytes[path] = payload
        records.append(
            {
                "schema_version": RECORD_SCHEMA,
                "record_id": f"mjsc_fixture_{metric_id}",
                "metric_id": metric_id,
                "semantic_ceiling": ceiling,
                "unit": EXPECTED_UNITS[metric_id],
                "semantic_source": source,
                "source_binding": {
                    "path": path,
                    "raw_sha256": "sha256:" + hashlib.sha256(payload).hexdigest(),
                    "byte_length": len(payload),
                    "locator": "json-pointer:/ceiling_assertion",
                    "source_commit": "f" * 40,
                },
                "chronology": {
                    "source_precedes_calibration_outcomes": True,
                    "calibration_outcome_used": False,
                    "heldout_outcome_used": False,
                    "historical_physics_outcome_used": False,
                    "synthetic_fixture_used": True,
                },
                "downstream_invariance": {
                    "consumer_id": f"fixture_consumer_{metric_id}",
                    "decision_or_label_id": f"fixture_decision_{metric_id}",
                    "preserved_below_ceiling": True,
                    "verification_method": (
                        "Synthetic exhaustive boundary canary for compiler behavior only."
                    ),
                    "adequacy_argument": (
                        "The fixture exhaustively binds its one synthetic metric, unit, "
                        "value, source class, and bounded canary scope; it supplies no "
                        "production adequacy claim."
                    ),
                    "metric_coverage_complete": True,
                },
                "scope": {
                    "topology_buckets": ["fixture_s169_bucket"],
                    "contact_regimes": ["fixture_contact"],
                    "material_profiles": ["fixture_material"],
                    "horizon_steps": [1, 60],
                    "broader_population_claim": False,
                },
                "fixture_only": True,
                "ceiling_freeze_authority": False,
            }
        )
    return records, source_bytes


def _expect_error(callback: Callable[[], object], expected_prefix: str) -> bool:
    try:
        callback()
    except SemanticCeilingReadinessError as error:
        return str(error).startswith(expected_prefix)
    return False


def _compile_fixture(
    records: list[dict[str, Any]],
    sources: dict[str, bytes],
    *,
    fixture_only: bool = True,
) -> dict[str, Any]:
    return compile_semantic_ceiling_inventory(
        inventory_id="mjsc_positive_fixture_not_production",
        records=records,
        source_bytes_by_path=sources,
        fixture_only=fixture_only,
    )


def run_semantic_ceiling_conformance() -> dict[str, Any]:
    contract = load_readiness_contract()
    current = compile_current_unresolved_inventory()
    records, sources = semantic_ceiling_fixture()
    fixture = _compile_fixture(records, sources)

    mutations: dict[str, bool] = {}

    def mutated_record(
        callback: Callable[[dict[str, Any]], None]
    ) -> list[dict[str, Any]]:
        candidate = copy.deepcopy(records)
        callback(candidate[0])
        return candidate

    mutations["unknown_field"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(lambda record: record.__setitem__("unexpected", True)),
            sources,
        ),
        "MJSC_RECORD_FIELDS:",
    )
    duplicate = copy.deepcopy(records)
    duplicate_sources = dict(sources)
    duplicate[1]["metric_id"] = duplicate[0]["metric_id"]
    duplicate[1]["unit"] = duplicate[0]["unit"]
    duplicate_path = duplicate[1]["source_binding"]["path"]
    duplicate_document = json.loads(duplicate_sources[duplicate_path])
    duplicate_document["ceiling_assertion"]["metric_id"] = duplicate[0]["metric_id"]
    duplicate_document["ceiling_assertion"]["unit"] = duplicate[0]["unit"]
    duplicate_payload = canonical_json_bytes(duplicate_document)
    duplicate_sources[duplicate_path] = duplicate_payload
    duplicate[1]["source_binding"]["raw_sha256"] = (
        "sha256:" + hashlib.sha256(duplicate_payload).hexdigest()
    )
    duplicate[1]["source_binding"]["byte_length"] = len(duplicate_payload)
    mutations["duplicate_metric"] = _expect_error(
        lambda: _compile_fixture(duplicate, duplicate_sources),
        "MJSC_METRIC_DUPLICATE:",
    )
    mutations["disallowed_semantic_source"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record.__setitem__(
                    "semantic_source", "contact_event_label_tolerance"
                )
            ),
            sources,
        ),
        "MJSC_RECORD_SEMANTIC_SOURCE:",
    )
    mutations["wrong_unit"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(lambda record: record.__setitem__("unit", "step")),
            sources,
        ),
        "MJSC_RECORD_UNIT:",
    )
    mutations["nonfinite_ceiling"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record.__setitem__("semantic_ceiling", float("nan"))
            ),
            sources,
        ),
        "MJSC_RECORD_CEILING:",
    )
    mutations["nonpositive_ceiling"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(lambda record: record.__setitem__("semantic_ceiling", 0.0)),
            sources,
        ),
        "MJSC_RECORD_CEILING:",
    )
    fractional_discrete = copy.deepcopy(records)
    fractional_discrete[-1]["semantic_ceiling"] = 0.5
    mutations["fractional_discrete_ceiling"] = _expect_error(
        lambda: _compile_fixture(fractional_discrete, sources),
        "MJSC_RECORD_DISCRETE_CEILING:",
    )
    mutations["source_digest_mutation"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["source_binding"].__setitem__(
                    "raw_sha256", "sha256:" + "0" * 64
                )
            ),
            sources,
        ),
        "MJSC_SOURCE_BYTES_DIGEST:",
    )
    mutations["source_length_mutation"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["source_binding"].__setitem__(
                    "byte_length", record["source_binding"]["byte_length"] + 1
                )
            ),
            sources,
        ),
        "MJSC_SOURCE_BYTES_LENGTH:",
    )
    mutations["source_path_escape"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["source_binding"].__setitem__(
                    "path", "../fixture.json"
                )
            ),
            sources,
        ),
        "MJSC_SOURCE_PATH_ESCAPE:",
    )
    mutations["source_bytes_missing"] = _expect_error(
        lambda: _compile_fixture(records, {}),
        "MJSC_SOURCE_BYTES_MISSING:",
    )
    mutations["source_locator_mutation"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["source_binding"].__setitem__(
                    "locator", "json-pointer:/missing"
                )
            ),
            sources,
        ),
        "MJSC_SOURCE_LOCATOR_RESOLUTION:",
    )
    bound_value_records = copy.deepcopy(records)
    bound_value_sources = dict(sources)
    bound_value_path = bound_value_records[0]["source_binding"]["path"]
    bound_value_document = json.loads(bound_value_sources[bound_value_path])
    bound_value_document["ceiling_assertion"]["semantic_ceiling"] += 0.25
    bound_value_payload = canonical_json_bytes(bound_value_document)
    bound_value_sources[bound_value_path] = bound_value_payload
    bound_value_records[0]["source_binding"]["raw_sha256"] = (
        "sha256:" + hashlib.sha256(bound_value_payload).hexdigest()
    )
    bound_value_records[0]["source_binding"]["byte_length"] = len(bound_value_payload)
    mutations["source_bound_value_mutation"] = _expect_error(
        lambda: _compile_fixture(bound_value_records, bound_value_sources),
        "MJSC_SOURCE_BOUND_VALUE:",
    )
    production_records = copy.deepcopy(records)
    for production_record in production_records:
        production_record["fixture_only"] = False
        production_record["chronology"]["synthetic_fixture_used"] = False
        production_record["source_binding"]["source_commit"] = "0" * 40
    mutations["unavailable_production_git_blob"] = _expect_error(
        lambda: _compile_fixture(production_records, {}, fixture_only=False),
        "MJSC_SOURCE_GIT_BLOB:",
    )
    mutations["postoutcome_source"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["chronology"].__setitem__(
                    "source_precedes_calibration_outcomes", False
                )
            ),
            sources,
        ),
        "MJSC_CHRONOLOGY_PRECEDENCE:",
    )
    mutations["calibration_outcome_source"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["chronology"].__setitem__(
                    "calibration_outcome_used", True
                )
            ),
            sources,
        ),
        "MJSC_OUTCOME_SOURCE:",
    )
    mutations["heldout_outcome_source"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["chronology"].__setitem__(
                    "heldout_outcome_used", True
                )
            ),
            sources,
        ),
        "MJSC_OUTCOME_SOURCE:",
    )
    mutations["historical_physics_outcome_source"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["chronology"].__setitem__(
                    "historical_physics_outcome_used", True
                )
            ),
            sources,
        ),
        "MJSC_OUTCOME_SOURCE:",
    )
    mutations["fixture_role_mismatch"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["chronology"].__setitem__(
                    "synthetic_fixture_used", False
                )
            ),
            sources,
        ),
        "MJSC_FIXTURE_SOURCE_ROLE:",
    )
    mutations["fixture_leak_to_production"] = _expect_error(
        lambda: _compile_fixture(records, sources, fixture_only=False),
        "MJSC_RECORD_FIXTURE_ROLE:",
    )
    mutations["broad_population_claim"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["scope"].__setitem__(
                    "broader_population_claim", True
                )
            ),
            sources,
        ),
        "MJSC_SCOPE_BROAD_CLAIM:",
    )
    mutations["missing_invariance"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["downstream_invariance"].__setitem__(
                    "preserved_below_ceiling", False
                )
            ),
            sources,
        ),
        "MJSC_INVARIANCE_PRESERVATION:",
    )
    mutations["missing_adequacy_argument"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["downstream_invariance"].__setitem__(
                    "adequacy_argument", ""
                )
            ),
            sources,
        ),
        "MJSC_INVARIANCE_ADEQUACY:",
    )
    mutations["metric_coverage_incomplete"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record["downstream_invariance"].__setitem__(
                    "metric_coverage_complete", False
                )
            ),
            sources,
        ),
        "MJSC_INVARIANCE_COVERAGE:",
    )
    mutations["freeze_authority_injection"] = _expect_error(
        lambda: _compile_fixture(
            mutated_record(
                lambda record: record.__setitem__("ceiling_freeze_authority", True)
            ),
            sources,
        ),
        "MJSC_RECORD_FREEZE_AUTHORITY:",
    )
    _require(
        len(mutations)
        == contract["source_conformance"]["minimum_mutation_control_count"]
        and all(mutations.values()),
        "MJSC_MUTATION_CONTROL",
        mutations,
    )

    cells = [
        {
            "cell_id": "mjsc0_contract_and_predecessor_boundary",
            "passed": True,
            "contract_id": contract["contract_id"],
            "contract_raw_sha256": file_sha256(CONTRACT_PATH),
            "predecessor_contract_raw_sha256": contract["predecessor_boundary"][
                "calibration_contract_raw_sha256"
            ],
            "production_plan_exists": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc1_current_incomplete_inventory",
            "passed": True,
            "accepted_source_count": current["accepted_source_count"],
            "unresolved_metric_count": current["unresolved_metric_count"],
            "all_unresolved_reasons_retained": all(
                item["unresolved_reason"] for item in current["metric_readiness"]
            ),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc2_positive_fixture_compilation",
            "passed": True,
            "fixture_accepted_source_count": fixture["accepted_source_count"],
            "compiler_fixture_complete": fixture["compiler_fixture_complete"],
            "production_semantic_ceiling_sources_complete": fixture[
                "production_semantic_ceiling_sources_complete"
            ],
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc3_content_binding_controls",
            "passed": all(
                mutations[name]
                for name in (
                    "source_digest_mutation",
                    "source_length_mutation",
                    "source_path_escape",
                    "source_bytes_missing",
                    "source_locator_mutation",
                    "source_bound_value_mutation",
                    "unavailable_production_git_blob",
                )
            ),
            "rejected_control_count": 7,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc4_chronology_and_outcome_controls",
            "passed": all(
                mutations[name]
                for name in (
                    "postoutcome_source",
                    "calibration_outcome_source",
                    "heldout_outcome_source",
                    "historical_physics_outcome_source",
                    "fixture_role_mismatch",
                    "fixture_leak_to_production",
                )
            ),
            "rejected_control_count": 6,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc5_unit_scope_and_invariance_controls",
            "passed": all(
                mutations[name]
                for name in (
                    "wrong_unit",
                    "nonfinite_ceiling",
                    "nonpositive_ceiling",
                    "fractional_discrete_ceiling",
                    "disallowed_semantic_source",
                    "broad_population_claim",
                    "missing_invariance",
                    "missing_adequacy_argument",
                    "metric_coverage_incomplete",
                )
            ),
            "rejected_control_count": 9,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc6_mutation_controls",
            "passed": True,
            "mutation_control_count": len(mutations),
            "rejected_mutations": dict(sorted(mutations.items())),
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
        {
            "cell_id": "mjsc7_authority_boundary",
            "passed": True,
            "current_inventory_incomplete": True,
            "production_plan_frozen": False,
            "production_margins_frozen": False,
            "calibration_authorized": False,
            "heldout_qualification_authorized": False,
            "supported_physics_subset_qualified": False,
            "training_plane_authorized": False,
            "scientific_result": False,
            "release_authority": False,
            "world_build_count": 0,
            "physical_acceptance_authority": False,
        },
    ]
    _require(len(cells) == 8 and all(cell["passed"] for cell in cells), "MJSC_CELLS")
    return {
        "schema_version": REPORT_SCHEMA,
        "ok": True,
        "contract_id": contract["contract_id"],
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "source": _source_receipt(),
        "cells": cells,
        "passed_cells": 8,
        "failed_cells": 0,
        "mutation_control_count": len(mutations),
        "required_metric_count": len(REQUIRED_METRICS),
        "accepted_production_source_count": current["accepted_source_count"],
        "unresolved_metric_count": current["unresolved_metric_count"],
        "all_unresolved_reasons_retained": all(
            item["unresolved_reason"] for item in current["metric_readiness"]
        ),
        "positive_fixture_accepted_source_count": fixture["accepted_source_count"],
        "fixture_only": True,
        "production_semantic_ceiling_sources_complete": False,
        "production_plan_frozen": False,
        "calibration_executed": False,
        "production_margins_frozen": False,
        "heldout_execution_authorized": False,
        "supported_physics_subset_qualified": False,
        "training_data_authority": False,
        "training_plane_authorized": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def _retain_report(report: dict[str, Any], path: Path) -> None:
    resolved = path.resolve()
    _require(resolved.name == "report.json", "MJSC_OUTPUT_NAME", resolved)
    resolved.parent.mkdir(parents=True, exist_ok=True)
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL
    descriptor = os.open(resolved, flags)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(canonical_json_bytes(report))
            stream.write(b"\n")
    except BaseException:
        resolved.unlink(missing_ok=True)
        raise


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path)
    arguments = parser.parse_args()
    report = run_semantic_ceiling_conformance()
    if arguments.output is not None:
        _retain_report(report, arguments.output)
    print(json.dumps(report, sort_keys=True, allow_nan=False))


if __name__ == "__main__":
    main()
