"""Pure zero-world compiler for MuJoCo-Warp semantic-ceiling provenance."""

from __future__ import annotations

import copy
import hashlib
import json
import math
import subprocess
from collections.abc import Iterable, Mapping, Sequence
from pathlib import Path
from typing import Any

from .mujoco_warp_equivalence_calibration import (
    ALLOWED_SEMANTIC_SOURCES,
    REQUIRED_METRICS,
    canonical_sha256,
    file_sha256,
)


CONTRACT_PATH = Path(__file__).with_name(
    "mujoco_warp_semantic_ceiling_readiness_contract_v1.json"
)
REPO_ROOT = CONTRACT_PATH.parents[2]

CONTRACT_SCHEMA = "sporespore_mujoco_warp_semantic_ceiling_readiness_contract_v1"
RECORD_SCHEMA = "sporespore_mujoco_warp_semantic_ceiling_provenance_record_v1"
INVENTORY_SCHEMA = "sporespore_mujoco_warp_semantic_ceiling_inventory_v1"
BOUND_SOURCE_ASSERTION_SCHEMA = (
    "sporespore_mujoco_warp_semantic_ceiling_source_assertion_v1"
)

EXPECTED_UNITS = {
    "one_step_state_linf_normalized": "normalized_ratio",
    "one_step_actuator_linf_normalized": "normalized_ratio",
    "bounded_horizon_pose_velocity_rms_normalized": "normalized_ratio",
    "bounded_horizon_energy_relative_error": "relative_ratio",
    "contact_event_time_error_steps": "step",
}
EXPECTED_CELLS = (
    "mjsc0_contract_and_predecessor_boundary",
    "mjsc1_current_incomplete_inventory",
    "mjsc2_positive_fixture_compilation",
    "mjsc3_content_binding_controls",
    "mjsc4_chronology_and_outcome_controls",
    "mjsc5_unit_scope_and_invariance_controls",
    "mjsc6_mutation_controls",
    "mjsc7_authority_boundary",
)
EXPECTED_EXPLICIT_NON_SOURCES = (
    "mjcal_synthetic_fixture_margins",
    "engine_specific_configured_readback_comparison_tolerance",
    "historical_locomotion_acceptance_threshold",
)

_RECORD_FIELDS = (
    "schema_version",
    "record_id",
    "metric_id",
    "semantic_ceiling",
    "unit",
    "semantic_source",
    "source_binding",
    "chronology",
    "downstream_invariance",
    "scope",
    "fixture_only",
    "ceiling_freeze_authority",
)
_SOURCE_BINDING_FIELDS = (
    "path",
    "raw_sha256",
    "byte_length",
    "locator",
    "source_commit",
)
_CHRONOLOGY_FIELDS = (
    "source_precedes_calibration_outcomes",
    "calibration_outcome_used",
    "heldout_outcome_used",
    "historical_physics_outcome_used",
    "synthetic_fixture_used",
)
_INVARIANCE_FIELDS = (
    "consumer_id",
    "decision_or_label_id",
    "preserved_below_ceiling",
    "verification_method",
    "adequacy_argument",
    "metric_coverage_complete",
)
_SCOPE_FIELDS = (
    "topology_buckets",
    "contact_regimes",
    "material_profiles",
    "horizon_steps",
    "broader_population_claim",
)
_BOUND_SOURCE_ASSERTION_FIELDS = (
    "schema_version",
    "metric_id",
    "unit",
    "semantic_ceiling",
    "semantic_source",
)


class SemanticCeilingReadinessError(ValueError):
    """Semantic-ceiling provenance failed closed."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise SemanticCeilingReadinessError(f"{code}:{detail}")


def _require_fields(value: dict[str, Any], expected: Iterable[str], code: str) -> None:
    expected_set = set(expected)
    actual_set = set(value)
    _require(
        actual_set == expected_set,
        code,
        {
            "missing": sorted(expected_set - actual_set),
            "extra": sorted(actual_set - expected_set),
        },
    )


def _nonempty_string(value: object, code: str) -> str:
    _require(isinstance(value, str) and value.strip() != "", code, value)
    return value


def _positive_number(value: object, code: str) -> float:
    _require(
        isinstance(value, (int, float)) and not isinstance(value, bool),
        code,
        "not_numeric",
    )
    numeric = float(value)
    _require(math.isfinite(numeric) and numeric > 0.0, code, value)
    return numeric


def _positive_int(value: object, code: str) -> int:
    _require(
        isinstance(value, int) and not isinstance(value, bool) and value > 0,
        code,
        value,
    )
    return value


def _sha256_text(value: object, code: str) -> str:
    _require(isinstance(value, str), code, "not_string")
    _require(
        len(value) == 71
        and value.startswith("sha256:")
        and all(character in "0123456789abcdef" for character in value[7:]),
        code,
        value,
    )
    return value


def _commit_text(value: object, code: str) -> str:
    _require(isinstance(value, str), code, "not_string")
    _require(
        len(value) == 40
        and all(character in "0123456789abcdef" for character in value),
        code,
        value,
    )
    return value


def _string_list(value: object, code: str) -> list[str]:
    _require(isinstance(value, list) and len(value) > 0, code, "not_nonempty_list")
    result = [_nonempty_string(item, code) for item in value]
    _require(len(result) == len(set(result)), code, "duplicate")
    return result


def _safe_repo_relative_path(value: object) -> str:
    path = _nonempty_string(value, "MJSC_SOURCE_PATH")
    candidate = Path(path)
    _require(not candidate.is_absolute(), "MJSC_SOURCE_PATH_ABSOLUTE", path)
    _require(".." not in candidate.parts, "MJSC_SOURCE_PATH_ESCAPE", path)
    _require(path.replace("\\", "/") == path, "MJSC_SOURCE_PATH_SEPARATOR", path)
    _require(path.startswith("sdk/"), "MJSC_SOURCE_PATH_PREFIX", path)
    return path


def _strict_json_bytes(source_bytes: bytes, path: str) -> object:
    def unique_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
        value: dict[str, object] = {}
        for key, item in pairs:
            _require(key not in value, "MJSC_SOURCE_JSON_DUPLICATE_KEY", key)
            value[key] = item
        return value

    def reject_constant(value: str) -> object:
        raise SemanticCeilingReadinessError(
            f"MJSC_SOURCE_JSON_NONFINITE_CONSTANT:{value}"
        )

    try:
        return json.loads(
            source_bytes.decode("utf-8"),
            object_pairs_hook=unique_object,
            parse_constant=reject_constant,
        )
    except SemanticCeilingReadinessError:
        raise
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SemanticCeilingReadinessError(
            f"MJSC_SOURCE_JSON:{path}:{type(error).__name__}"
        ) from error


def _decode_json_pointer_token(token: str) -> str:
    decoded: list[str] = []
    index = 0
    while index < len(token):
        character = token[index]
        if character != "~":
            decoded.append(character)
            index += 1
            continue
        _require(
            index + 1 < len(token) and token[index + 1] in ("0", "1"),
            "MJSC_SOURCE_LOCATOR_ESCAPE",
            token,
        )
        decoded.append("~" if token[index + 1] == "0" else "/")
        index += 2
    return "".join(decoded)


def _resolve_json_pointer(document: object, locator: str) -> object:
    prefix = "json-pointer:"
    _require(
        locator.startswith(prefix + "/"),
        "MJSC_SOURCE_LOCATOR_FORMAT",
        locator,
    )
    current = document
    for raw_token in locator[len(prefix) + 1 :].split("/"):
        token = _decode_json_pointer_token(raw_token)
        if isinstance(current, dict):
            _require(token in current, "MJSC_SOURCE_LOCATOR_RESOLUTION", locator)
            current = current[token]
        elif isinstance(current, list):
            _require(
                token.isdecimal() and str(int(token)) == token,
                "MJSC_SOURCE_LOCATOR_INDEX",
                token,
            )
            index = int(token)
            _require(
                0 <= index < len(current),
                "MJSC_SOURCE_LOCATOR_RESOLUTION",
                locator,
            )
            current = current[index]
        else:
            _require(False, "MJSC_SOURCE_LOCATOR_RESOLUTION", locator)
    return current


def load_readiness_contract() -> dict[str, Any]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    _require(
        contract.get("schema_version") == CONTRACT_SCHEMA,
        "MJSC_CONTRACT_SCHEMA",
    )
    _require(
        contract.get("status")
        == "zero_world_source_only_all_production_semantic_ceilings_unresolved",
        "MJSC_CONTRACT_STATUS",
    )
    _require(contract.get("question_class") == "development", "MJSC_QUESTION")

    predecessor = contract["predecessor_boundary"]
    for path_key, hash_key in (
        ("calibration_contract_path", "calibration_contract_raw_sha256"),
        ("calibration_compiler_path", "calibration_compiler_raw_sha256"),
        (
            "calibration_validation_manifest_path",
            "calibration_validation_manifest_raw_sha256",
        ),
    ):
        relative = _safe_repo_relative_path(predecessor[path_key])
        path = (REPO_ROOT / relative).resolve()
        _require(
            path.is_relative_to(REPO_ROOT.resolve()),
            "MJSC_PREDECESSOR_ESCAPE",
            relative,
        )
        _require(path.is_file(), "MJSC_PREDECESSOR_MISSING", relative)
        _require(
            file_sha256(path) == predecessor[hash_key],
            "MJSC_PREDECESSOR_DIGEST",
            relative,
        )
    _require(
        predecessor["calibration_report_is_fixture_only"]
        and not predecessor["fixture_semantic_values_have_production_authority"]
        and not predecessor["production_plan_exists"]
        and not predecessor["production_margins_frozen"]
        and not predecessor["physical_calibration_series_open"]
        and not predecessor["heldout_qualification_series_open"],
        "MJSC_PREDECESSOR_AUTHORITY",
    )

    readiness = contract["required_metric_readiness"]
    _require(
        [entry["metric_id"] for entry in readiness] == list(REQUIRED_METRICS),
        "MJSC_METRIC_ORDER",
    )
    _require(
        {entry["metric_id"]: entry["unit"] for entry in readiness} == EXPECTED_UNITS,
        "MJSC_METRIC_UNITS",
    )
    for entry in readiness:
        _require(
            entry["status"] == "unresolved_no_accepted_production_source",
            "MJSC_METRIC_CURRENT_STATUS",
            entry["metric_id"],
        )
        _nonempty_string(entry["unresolved_reason"], "MJSC_UNRESOLVED_REASON")
        allowed = tuple(entry["allowed_semantic_sources"])
        _require(
            len(allowed) > 0
            and len(allowed) == len(set(allowed))
            and all(source in ALLOWED_SEMANTIC_SOURCES for source in allowed),
            "MJSC_ALLOWED_SOURCE",
            entry["metric_id"],
        )

    current = contract["current_inventory"]
    _require(
        current["accepted_production_source_count"] == 0
        and current["required_metric_count"] == len(REQUIRED_METRICS)
        and current["unresolved_metric_count"] == len(REQUIRED_METRICS)
        and not current["production_semantic_ceiling_sources_complete"]
        and not current["production_plan_exists"]
        and not current["production_margins_frozen"]
        and not current["calibration_authorized"],
        "MJSC_CURRENT_INVENTORY",
    )
    _require(
        contract["provenance_record_contract"]["schema_version"] == RECORD_SCHEMA,
        "MJSC_PROVENANCE_RECORD_SCHEMA",
    )
    _require(
        tuple(item["source_class"] for item in contract["explicit_non_sources"])
        == EXPECTED_EXPLICIT_NON_SOURCES
        and all(
            item["disposition"].startswith("rejected")
            for item in contract["explicit_non_sources"]
        ),
        "MJSC_EXPLICIT_NON_SOURCES",
    )
    source = contract["source_conformance"]
    _require(
        source["fixture_only_positive_path"]
        and tuple(source["required_cells"]) == EXPECTED_CELLS
        and source["minimum_mutation_control_count"] == 25
        and source["model_construction_count"] == 0
        and source["step_invocation_count"] == 0
        and source["world_attempt_count"] == 0
        and source["world_build_count"] == 0
        and not source["physics_state_modified"],
        "MJSC_ZERO_WORLD_BOUNDARY",
    )
    _require(
        all(not bool(value) for value in contract["claims"].values()),
        "MJSC_CONTRACT_CLAIM",
    )
    return contract


def _validate_source_binding(
    value: dict[str, Any],
    source_bytes_by_path: Mapping[str, bytes],
    *,
    fixture_only: bool,
    metric_id: str,
    unit: str,
    semantic_ceiling: float,
    semantic_source: str,
) -> dict[str, Any]:
    _require_fields(value, _SOURCE_BINDING_FIELDS, "MJSC_SOURCE_BINDING_FIELDS")
    path = _safe_repo_relative_path(value["path"])
    raw_sha256 = _sha256_text(value["raw_sha256"], "MJSC_SOURCE_SHA256")
    byte_length = _positive_int(value["byte_length"], "MJSC_SOURCE_BYTE_LENGTH")
    locator = _nonempty_string(value["locator"], "MJSC_SOURCE_LOCATOR")
    source_commit = _commit_text(value["source_commit"], "MJSC_SOURCE_COMMIT")
    _require(path.endswith(".json"), "MJSC_SOURCE_DOCUMENT_SUFFIX", path)
    if fixture_only:
        _require(path in source_bytes_by_path, "MJSC_SOURCE_BYTES_MISSING", path)
        source_bytes = source_bytes_by_path[path]
    else:
        result = subprocess.run(
            ["git", "-C", str(REPO_ROOT), "show", f"{source_commit}:{path}"],
            check=False,
            capture_output=True,
        )
        _require(result.returncode == 0, "MJSC_SOURCE_GIT_BLOB", path)
        source_bytes = result.stdout
        for lineage_ref in ("HEAD", "origin/main"):
            lineage = subprocess.run(
                [
                    "git",
                    "-C",
                    str(REPO_ROOT),
                    "merge-base",
                    "--is-ancestor",
                    source_commit,
                    lineage_ref,
                ],
                check=False,
                capture_output=True,
            )
            _require(
                lineage.returncode == 0,
                "MJSC_SOURCE_COMMIT_LINEAGE",
                lineage_ref,
            )
    _require(isinstance(source_bytes, bytes), "MJSC_SOURCE_BYTES_TYPE", path)
    _require(len(source_bytes) == byte_length, "MJSC_SOURCE_BYTES_LENGTH", path)
    actual = "sha256:" + hashlib.sha256(source_bytes).hexdigest()
    _require(actual == raw_sha256, "MJSC_SOURCE_BYTES_DIGEST", path)
    assertion = _resolve_json_pointer(
        _strict_json_bytes(source_bytes, path),
        locator,
    )
    _require(isinstance(assertion, dict), "MJSC_SOURCE_ASSERTION_TYPE", path)
    _require_fields(
        assertion,
        _BOUND_SOURCE_ASSERTION_FIELDS,
        "MJSC_SOURCE_ASSERTION_FIELDS",
    )
    _require(
        assertion["schema_version"] == BOUND_SOURCE_ASSERTION_SCHEMA
        and assertion["metric_id"] == metric_id
        and assertion["unit"] == unit
        and assertion["semantic_source"] == semantic_source,
        "MJSC_SOURCE_BOUND_IDENTITY",
        path,
    )
    bound_ceiling = _positive_number(
        assertion["semantic_ceiling"],
        "MJSC_SOURCE_BOUND_CEILING",
    )
    _require(
        bound_ceiling == semantic_ceiling,
        "MJSC_SOURCE_BOUND_VALUE",
        path,
    )
    return {
        "path": path,
        "raw_sha256": raw_sha256,
        "byte_length": byte_length,
        "locator": locator,
        "source_commit": source_commit,
    }


def _validate_scope(value: dict[str, Any]) -> dict[str, Any]:
    _require_fields(value, _SCOPE_FIELDS, "MJSC_SCOPE_FIELDS")
    horizons = value["horizon_steps"]
    _require(
        isinstance(horizons, list) and len(horizons) > 0,
        "MJSC_SCOPE_HORIZONS",
    )
    horizon_steps = [_positive_int(item, "MJSC_SCOPE_HORIZON") for item in horizons]
    _require(
        len(horizon_steps) == len(set(horizon_steps)),
        "MJSC_SCOPE_HORIZON_DUPLICATE",
    )
    _require(
        value["broader_population_claim"] is False,
        "MJSC_SCOPE_BROAD_CLAIM",
    )
    return {
        "topology_buckets": _string_list(
            value["topology_buckets"], "MJSC_SCOPE_TOPOLOGY"
        ),
        "contact_regimes": _string_list(value["contact_regimes"], "MJSC_SCOPE_CONTACT"),
        "material_profiles": _string_list(
            value["material_profiles"], "MJSC_SCOPE_MATERIAL"
        ),
        "horizon_steps": horizon_steps,
        "broader_population_claim": False,
    }


def _validate_record(
    record: dict[str, Any],
    source_bytes_by_path: Mapping[str, bytes],
    *,
    fixture_only: bool,
    contract: dict[str, Any],
) -> dict[str, Any]:
    _require(isinstance(record, dict), "MJSC_RECORD_TYPE", type(record).__name__)
    _require_fields(record, _RECORD_FIELDS, "MJSC_RECORD_FIELDS")
    _require(record["schema_version"] == RECORD_SCHEMA, "MJSC_RECORD_SCHEMA")
    record_id = _nonempty_string(record["record_id"], "MJSC_RECORD_ID")
    metric_id = _nonempty_string(record["metric_id"], "MJSC_RECORD_METRIC")
    _require(metric_id in REQUIRED_METRICS, "MJSC_RECORD_METRIC", metric_id)
    _require(
        record["unit"] == EXPECTED_UNITS[metric_id],
        "MJSC_RECORD_UNIT",
        metric_id,
    )
    metric_contract = next(
        entry
        for entry in contract["required_metric_readiness"]
        if entry["metric_id"] == metric_id
    )
    semantic_source = _nonempty_string(
        record["semantic_source"], "MJSC_RECORD_SEMANTIC_SOURCE"
    )
    _require(
        semantic_source in metric_contract["allowed_semantic_sources"],
        "MJSC_RECORD_SEMANTIC_SOURCE",
        {"metric": metric_id, "source": semantic_source},
    )
    ceiling = _positive_number(record["semantic_ceiling"], "MJSC_RECORD_CEILING")
    if EXPECTED_UNITS[metric_id] == "step":
        _require(ceiling.is_integer(), "MJSC_RECORD_DISCRETE_CEILING", ceiling)
    _require(record["fixture_only"] is fixture_only, "MJSC_RECORD_FIXTURE_ROLE")
    _require(
        record["ceiling_freeze_authority"] is False,
        "MJSC_RECORD_FREEZE_AUTHORITY",
    )

    chronology = record["chronology"]
    _require(isinstance(chronology, dict), "MJSC_CHRONOLOGY_TYPE")
    _require_fields(chronology, _CHRONOLOGY_FIELDS, "MJSC_CHRONOLOGY_FIELDS")
    _require(
        chronology["source_precedes_calibration_outcomes"] is True,
        "MJSC_CHRONOLOGY_PRECEDENCE",
    )
    for field in (
        "calibration_outcome_used",
        "heldout_outcome_used",
        "historical_physics_outcome_used",
    ):
        _require(chronology[field] is False, "MJSC_OUTCOME_SOURCE", field)
    _require(
        chronology["synthetic_fixture_used"] is fixture_only,
        "MJSC_FIXTURE_SOURCE_ROLE",
    )

    invariance = record["downstream_invariance"]
    _require(isinstance(invariance, dict), "MJSC_INVARIANCE_TYPE")
    _require_fields(invariance, _INVARIANCE_FIELDS, "MJSC_INVARIANCE_FIELDS")
    consumer_id = _nonempty_string(
        invariance["consumer_id"], "MJSC_INVARIANCE_CONSUMER"
    )
    decision_id = _nonempty_string(
        invariance["decision_or_label_id"], "MJSC_INVARIANCE_DECISION"
    )
    method = _nonempty_string(
        invariance["verification_method"], "MJSC_INVARIANCE_METHOD"
    )
    adequacy_argument = _nonempty_string(
        invariance["adequacy_argument"], "MJSC_INVARIANCE_ADEQUACY"
    )
    _require(
        invariance["preserved_below_ceiling"] is True,
        "MJSC_INVARIANCE_PRESERVATION",
    )
    _require(
        invariance["metric_coverage_complete"] is True,
        "MJSC_INVARIANCE_COVERAGE",
    )

    scope = _validate_scope(record["scope"])
    source_binding = _validate_source_binding(
        record["source_binding"],
        source_bytes_by_path,
        fixture_only=fixture_only,
        metric_id=metric_id,
        unit=EXPECTED_UNITS[metric_id],
        semantic_ceiling=ceiling,
        semantic_source=semantic_source,
    )
    return {
        "schema_version": RECORD_SCHEMA,
        "record_id": record_id,
        "metric_id": metric_id,
        "semantic_ceiling": ceiling,
        "unit": EXPECTED_UNITS[metric_id],
        "semantic_source": semantic_source,
        "source_binding": source_binding,
        "chronology": copy.deepcopy(chronology),
        "downstream_invariance": {
            "consumer_id": consumer_id,
            "decision_or_label_id": decision_id,
            "preserved_below_ceiling": True,
            "verification_method": method,
            "adequacy_argument": adequacy_argument,
            "metric_coverage_complete": True,
        },
        "scope": scope,
        "fixture_only": fixture_only,
        "ceiling_freeze_authority": False,
    }


def compile_semantic_ceiling_inventory(
    *,
    inventory_id: str,
    records: Sequence[dict[str, Any]],
    source_bytes_by_path: Mapping[str, bytes],
    fixture_only: bool,
) -> dict[str, Any]:
    """Validate exact provenance and retain unresolved metrics explicitly."""

    contract = load_readiness_contract()
    inventory_name = _nonempty_string(inventory_id, "MJSC_INVENTORY_ID")
    _require(isinstance(fixture_only, bool), "MJSC_INVENTORY_FIXTURE_ROLE")
    _require(
        isinstance(records, Sequence) and not isinstance(records, (str, bytes)),
        "MJSC_RECORDS_TYPE",
    )
    validated = [
        _validate_record(
            record,
            source_bytes_by_path,
            fixture_only=fixture_only,
            contract=contract,
        )
        for record in records
    ]
    record_ids = [record["record_id"] for record in validated]
    metric_ids = [record["metric_id"] for record in validated]
    _require(len(record_ids) == len(set(record_ids)), "MJSC_RECORD_ID_DUPLICATE")
    _require(len(metric_ids) == len(set(metric_ids)), "MJSC_METRIC_DUPLICATE")
    referenced_paths = {record["source_binding"]["path"] for record in validated}
    if fixture_only:
        _require(
            set(source_bytes_by_path) == referenced_paths,
            "MJSC_FIXTURE_SOURCE_SET",
        )
    else:
        _require(
            len(source_bytes_by_path) == 0,
            "MJSC_PRODUCTION_EXTERNAL_SOURCE_BYTES_FORBIDDEN",
        )

    order = {metric_id: index for index, metric_id in enumerate(REQUIRED_METRICS)}
    validated.sort(key=lambda record: order[record["metric_id"]])
    by_metric = {record["metric_id"]: record for record in validated}
    metric_readiness: list[dict[str, Any]] = []
    for metric_contract in contract["required_metric_readiness"]:
        metric_id = metric_contract["metric_id"]
        if metric_id in by_metric:
            record = by_metric[metric_id]
            metric_readiness.append(
                {
                    "metric_id": metric_id,
                    "unit": metric_contract["unit"],
                    "status": (
                        "fixture_source_compiler_accepted"
                        if fixture_only
                        else "production_semantic_source_accepted"
                    ),
                    "record_id": record["record_id"],
                    "unresolved_reason": None,
                }
            )
        else:
            metric_readiness.append(
                {
                    "metric_id": metric_id,
                    "unit": metric_contract["unit"],
                    "status": "unresolved_no_accepted_production_source",
                    "record_id": None,
                    "unresolved_reason": metric_contract["unresolved_reason"],
                }
            )

    accepted_count = len(validated)
    unresolved_count = len(REQUIRED_METRICS) - accepted_count
    compiler_fixture_complete = fixture_only and unresolved_count == 0
    production_complete = not fixture_only and unresolved_count == 0
    inventory: dict[str, Any] = {
        "schema_version": INVENTORY_SCHEMA,
        "inventory_id": inventory_name,
        "contract_id": contract["contract_id"],
        "contract_raw_sha256": file_sha256(CONTRACT_PATH),
        "question_class": "development",
        "fixture_only": fixture_only,
        "records": validated,
        "metric_readiness": metric_readiness,
        "required_metric_count": len(REQUIRED_METRICS),
        "accepted_source_count": accepted_count,
        "unresolved_metric_count": unresolved_count,
        "compiler_fixture_complete": compiler_fixture_complete,
        "production_semantic_ceiling_sources_complete": production_complete,
        "production_plan_exists": False,
        "production_margins_frozen": False,
        "calibration_authorized": False,
        "heldout_qualification_authorized": False,
        "supported_physics_subset_qualified": False,
        "training_plane_authorized": False,
        "training_data_authority": False,
        "model_construction_count": 0,
        "step_invocation_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "physics_state_modified": False,
        "scientific_result": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }
    inventory["inventory_sha256"] = canonical_sha256(inventory)
    return inventory


def compile_current_unresolved_inventory() -> dict[str, Any]:
    contract = load_readiness_contract()
    return compile_semantic_ceiling_inventory(
        inventory_id=contract["current_inventory"]["inventory_id"],
        records=[],
        source_bytes_by_path={},
        fixture_only=False,
    )
