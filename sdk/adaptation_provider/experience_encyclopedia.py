"""Deterministic online characterization and append-only experience storage.

This module is a zero-world SDK utility. It summarizes already-canonical
observations; it never samples a native engine or decides a locomotion result.
The store retains candidate experience records in content-addressed objects
and a create-only, parent-bound journal. Promotion remains a separate Tier 2
operation.
"""

from __future__ import annotations

import json
import math
import os
import re
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from sporespore_locomotion import LocomotionCore
except ImportError:
    from python.sporespore_locomotion import LocomotionCore


CONTRACT_PATH = Path(__file__).resolve().with_name(
    "experience_encyclopedia_contract_v1.json"
)
CHARACTERIZATION_REQUEST_SCHEMA = (
    "sporespore_online_characterization_request_v1"
)
CHARACTERIZATION_SAMPLE_SCHEMA = "sporespore_online_characterization_sample_v1"
CHARACTERIZATION_RECEIPT_SCHEMA = (
    "sporespore_online_characterization_receipt_v1"
)
EXPERIENCE_ENTRY_SCHEMA = "sporespore_adaptation_experience_entry_v1"
APPEND_EVENT_SCHEMA = "sporespore_adaptation_experience_append_event_v1"
STORE_RECEIPT_SCHEMA = "sporespore_adaptation_experience_store_receipt_v1"
MAX_SAMPLE_COUNT = 4096
RESULT_CLASSES = {"positive", "negative", "rejected", "invalid", "incomplete"}
SUPPORT_STATUSES = {"supported", "edge", "out_of_distribution"}
_EVENT_NAME = re.compile(r"^(?P<sequence>[0-9]{20})-(?P<digest>[0-9a-f]{64})\.json$")


class ExperienceEncyclopediaError(ValueError):
    """A characterization or append-only storage boundary was violated."""


def _require(condition: bool, code: str, detail: object = "") -> None:
    if not condition:
        raise ExperienceEncyclopediaError(f"{code}:{detail}")


def _require_exact_fields(
    value: Mapping[str, Any], expected: set[str], code: str
) -> None:
    actual = set(value)
    _require(actual == expected, code, sorted(actual ^ expected))


def _require_identifier(value: object, code: str) -> None:
    _require(
        isinstance(value, str)
        and 0 < len(value) <= 128
        and all(character.isalnum() or character in "._:-" for character in value),
        code,
        value,
    )


def _require_sha256(value: object, code: str) -> None:
    _require(
        isinstance(value, str)
        and value.startswith("sha256:")
        and len(value) == 71
        and all(character in "0123456789abcdef" for character in value[7:]),
        code,
        value,
    )


def _require_finite(value: object, code: str, *, minimum: float | None = None) -> None:
    _require(
        isinstance(value, (int, float))
        and not isinstance(value, bool)
        and math.isfinite(float(value)),
        code,
        value,
    )
    if minimum is not None:
        _require(float(value) >= minimum, code, value)


def _require_integer(
    value: object,
    code: str,
    *,
    minimum: int = 0,
    maximum: int | None = None,
) -> None:
    _require(isinstance(value, int) and not isinstance(value, bool), code, value)
    _require(value >= minimum, code, value)
    if maximum is not None:
        _require(value <= maximum, code, value)


def canonical_sha256(core: LocomotionCore, value: Mapping[str, Any]) -> str:
    """Return the portable core's canonical JSON SHA-256 for a mapping."""

    return core.canonicalize_json(dict(value))["sha256"]


def load_experience_encyclopedia_contract() -> dict[str, Any]:
    contract = json.loads(CONTRACT_PATH.read_text(encoding="utf-8"))
    _require(
        contract.get("schema_version")
        == "sporespore_adaptation_experience_encyclopedia_contract_v1",
        "EXPERIENCE_CONTRACT_SCHEMA",
    )
    _require(
        contract.get("world_build_count") == 0
        and contract.get("physics_state_modified") is False
        and contract.get("physical_acceptance_authority") is False,
        "EXPERIENCE_CONTRACT_AUTHORITY",
    )
    return contract


_REQUEST_FIELDS = {
    "schema_version",
    "session_id",
    "morphology_descriptor_sha256",
    "provider_id",
    "model_id",
    "corpus_sha256",
    "task_id",
    "environment_id",
    "support_status",
    "seed",
    "support_contact_capacity",
    "ordered_samples",
    "candidate_only",
    "physical_acceptance_authority",
}
_SAMPLE_FIELDS = {
    "schema_version",
    "step_index",
    "time_seconds",
    "requested_forward_velocity_m_s",
    "observed_forward_velocity_m_s",
    "torso_height_m",
    "torso_tilt_rad",
    "qualified_contact_count",
    "fallback_active",
    "provider_influence_applied",
}


def validate_characterization_request(request: Mapping[str, Any]) -> None:
    _require_exact_fields(request, _REQUEST_FIELDS, "CHARACTERIZATION_REQUEST_FIELDS")
    _require(
        request.get("schema_version") == CHARACTERIZATION_REQUEST_SCHEMA,
        "CHARACTERIZATION_REQUEST_SCHEMA",
    )
    for field in ("session_id", "provider_id", "model_id", "task_id", "environment_id"):
        _require_identifier(request.get(field), "CHARACTERIZATION_IDENTIFIER")
    for field in ("morphology_descriptor_sha256", "corpus_sha256"):
        _require_sha256(request.get(field), "CHARACTERIZATION_DIGEST")
    _require(
        request.get("support_status") in SUPPORT_STATUSES,
        "CHARACTERIZATION_SUPPORT_STATUS",
        request.get("support_status"),
    )
    _require_integer(request.get("seed"), "CHARACTERIZATION_SEED")
    capacity = request.get("support_contact_capacity")
    _require_integer(
        capacity,
        "CHARACTERIZATION_CONTACT_CAPACITY",
        minimum=1,
        maximum=256,
    )
    _require(request.get("candidate_only") is True, "CHARACTERIZATION_NOT_CANDIDATE")
    _require(
        request.get("physical_acceptance_authority") is False,
        "CHARACTERIZATION_REQUEST_AUTHORITY",
    )
    samples = request.get("ordered_samples")
    _require(isinstance(samples, list), "CHARACTERIZATION_SAMPLES_TYPE")
    _require(
        2 <= len(samples) <= MAX_SAMPLE_COUNT,
        "CHARACTERIZATION_SAMPLE_COUNT",
        len(samples),
    )
    previous_step: int | None = None
    previous_time: float | None = None
    for ordinal, sample in enumerate(samples):
        _require(isinstance(sample, Mapping), "CHARACTERIZATION_SAMPLE_TYPE", ordinal)
        _require_exact_fields(
            sample, _SAMPLE_FIELDS, "CHARACTERIZATION_SAMPLE_FIELDS"
        )
        _require(
            sample.get("schema_version") == CHARACTERIZATION_SAMPLE_SCHEMA,
            "CHARACTERIZATION_SAMPLE_SCHEMA",
            ordinal,
        )
        step = sample.get("step_index")
        _require_integer(step, "CHARACTERIZATION_STEP", minimum=0)
        time_seconds = sample.get("time_seconds")
        _require_finite(time_seconds, "CHARACTERIZATION_TIME", minimum=0.0)
        for field in (
            "requested_forward_velocity_m_s",
            "observed_forward_velocity_m_s",
            "torso_height_m",
            "torso_tilt_rad",
        ):
            _require_finite(sample.get(field), "CHARACTERIZATION_NUMERIC")
        _require(float(sample["torso_height_m"]) >= 0.0, "CHARACTERIZATION_HEIGHT")
        contacts = sample.get("qualified_contact_count")
        _require_integer(
            contacts,
            "CHARACTERIZATION_CONTACT_COUNT",
            minimum=0,
            maximum=capacity,
        )
        for field in ("fallback_active", "provider_influence_applied"):
            _require(type(sample.get(field)) is bool, "CHARACTERIZATION_BOOLEAN", field)
        if previous_step is not None:
            _require(step > previous_step, "CHARACTERIZATION_STEP_ORDER", ordinal)
            _require(
                float(time_seconds) > previous_time,
                "CHARACTERIZATION_TIME_ORDER",
                ordinal,
            )
        previous_step = step
        previous_time = float(time_seconds)


def characterize_online_window(
    core: LocomotionCore, request: Mapping[str, Any]
) -> dict[str, Any]:
    """Compile a threshold-free deterministic summary of canonical samples."""

    validate_characterization_request(request)
    samples = request["ordered_samples"]
    capacity = int(request["support_contact_capacity"])
    count = len(samples)
    request_sha256 = canonical_sha256(core, request)
    sample_digests = [canonical_sha256(core, sample) for sample in samples]
    velocity_errors = [
        abs(
            float(sample["requested_forward_velocity_m_s"])
            - float(sample["observed_forward_velocity_m_s"])
        )
        for sample in samples
    ]
    contact_fractions = [
        int(sample["qualified_contact_count"]) / capacity for sample in samples
    ]
    identity = request_sha256.removeprefix("sha256:")
    return {
        "schema_version": CHARACTERIZATION_RECEIPT_SCHEMA,
        "characterization_id": f"online_characterization_{identity[:20]}",
        "question_class": "development",
        "request_sha256": request_sha256,
        "session_id": request["session_id"],
        "morphology_descriptor_sha256": request["morphology_descriptor_sha256"],
        "provider_id": request["provider_id"],
        "model_id": request["model_id"],
        "corpus_sha256": request["corpus_sha256"],
        "task_id": request["task_id"],
        "environment_id": request["environment_id"],
        "support_status": request["support_status"],
        "seed": request["seed"],
        "sample_count": count,
        "first_step_index": samples[0]["step_index"],
        "last_step_index": samples[-1]["step_index"],
        "duration_seconds": float(samples[-1]["time_seconds"])
        - float(samples[0]["time_seconds"]),
        "ordered_sample_sha256": sample_digests,
        "mean_absolute_forward_velocity_error_m_s": math.fsum(velocity_errors)
        / count,
        "maximum_absolute_torso_tilt_rad": max(
            abs(float(sample["torso_tilt_rad"])) for sample in samples
        ),
        "minimum_torso_height_m": min(
            float(sample["torso_height_m"]) for sample in samples
        ),
        "mean_qualified_contact_fraction": math.fsum(contact_fractions) / count,
        "fallback_fraction": math.fsum(
            1.0 if sample["fallback_active"] else 0.0 for sample in samples
        )
        / count,
        "provider_influence_fraction": math.fsum(
            1.0 if sample["provider_influence_applied"] else 0.0
            for sample in samples
        )
        / count,
        "thresholds_applied": False,
        "outcome_classified": False,
        "population_inference": False,
        "candidate_only": True,
        "training_data_authority": False,
        "encyclopedia_promotion_authority": False,
        "scientific_result": False,
        "world_build_count": 0,
        "physics_state_modified": False,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_characterization_receipt(receipt: Mapping[str, Any]) -> None:
    _require_exact_fields(
        receipt,
        {
            "schema_version",
            "characterization_id",
            "question_class",
            "request_sha256",
            "session_id",
            "morphology_descriptor_sha256",
            "provider_id",
            "model_id",
            "corpus_sha256",
            "task_id",
            "environment_id",
            "support_status",
            "seed",
            "sample_count",
            "first_step_index",
            "last_step_index",
            "duration_seconds",
            "ordered_sample_sha256",
            "mean_absolute_forward_velocity_error_m_s",
            "maximum_absolute_torso_tilt_rad",
            "minimum_torso_height_m",
            "mean_qualified_contact_fraction",
            "fallback_fraction",
            "provider_influence_fraction",
            "thresholds_applied",
            "outcome_classified",
            "population_inference",
            "candidate_only",
            "training_data_authority",
            "encyclopedia_promotion_authority",
            "scientific_result",
            "world_build_count",
            "physics_state_modified",
            "physical_acceptance_authority",
            "release_authority",
        },
        "CHARACTERIZATION_RECEIPT_FIELDS",
    )
    _require(
        receipt.get("schema_version") == CHARACTERIZATION_RECEIPT_SCHEMA,
        "CHARACTERIZATION_RECEIPT_SCHEMA",
    )
    _require_sha256(receipt.get("request_sha256"), "CHARACTERIZATION_RECEIPT_DIGEST")
    ordered = receipt.get("ordered_sample_sha256")
    _require(
        isinstance(ordered, list)
        and len(ordered) >= 2
        and receipt.get("sample_count") == len(ordered),
        "CHARACTERIZATION_RECEIPT_SAMPLES",
    )
    for digest in ordered:
        _require_sha256(digest, "CHARACTERIZATION_RECEIPT_SAMPLE_DIGEST")
    _require(
        receipt.get("thresholds_applied") is False
        and receipt.get("outcome_classified") is False
        and receipt.get("population_inference") is False
        and receipt.get("candidate_only") is True
        and receipt.get("training_data_authority") is False
        and receipt.get("encyclopedia_promotion_authority") is False
        and receipt.get("scientific_result") is False
        and receipt.get("world_build_count") == 0
        and receipt.get("physics_state_modified") is False
        and receipt.get("physical_acceptance_authority") is False
        and receipt.get("release_authority") is False,
        "CHARACTERIZATION_RECEIPT_AUTHORITY",
    )
    for field in (
        "duration_seconds",
        "mean_absolute_forward_velocity_error_m_s",
        "maximum_absolute_torso_tilt_rad",
        "minimum_torso_height_m",
        "mean_qualified_contact_fraction",
        "fallback_fraction",
        "provider_influence_fraction",
    ):
        _require_finite(
            receipt.get(field),
            "CHARACTERIZATION_RECEIPT_NUMERIC",
            minimum=0.0,
        )


def _validate_candidate_experience(candidate: Mapping[str, Any]) -> None:
    _require_exact_fields(
        candidate,
        {
            "schema_version",
            "candidate_event_id",
            "lesson_family_id",
            "candidate_only",
            "encyclopedia_promotion_authority",
            "physical_acceptance_authority",
        },
        "EXPERIENCE_CANDIDATE_FIELDS",
    )
    _require(
        candidate.get("schema_version")
        == "sporespore_adaptation_candidate_experience_v1",
        "EXPERIENCE_CANDIDATE_SCHEMA",
    )
    _require_identifier(candidate.get("candidate_event_id"), "EXPERIENCE_EVENT_ID")
    _require_identifier(candidate.get("lesson_family_id"), "EXPERIENCE_LESSON_ID")
    _require(
        candidate.get("candidate_only") is True
        and candidate.get("encyclopedia_promotion_authority") is False
        and candidate.get("physical_acceptance_authority") is False,
        "EXPERIENCE_CANDIDATE_AUTHORITY",
    )


def build_experience_entry(
    core: LocomotionCore,
    *,
    candidate_experience: Mapping[str, Any],
    characterization: Mapping[str, Any],
    provider_request_sha256: str,
    provider_response_sha256: str,
    resolution_receipt_sha256: str,
    result_class: str,
    reason_code: str | None,
) -> dict[str, Any]:
    """Bind a provider candidate event to a measured, explicitly classified record."""

    _validate_candidate_experience(candidate_experience)
    validate_characterization_receipt(characterization)
    for digest in (
        provider_request_sha256,
        provider_response_sha256,
        resolution_receipt_sha256,
    ):
        _require_sha256(digest, "EXPERIENCE_BINDING_DIGEST")
    _require(result_class in RESULT_CLASSES, "EXPERIENCE_RESULT_CLASS", result_class)
    if result_class == "positive":
        _require(reason_code is None, "EXPERIENCE_POSITIVE_REASON", reason_code)
    else:
        _require_identifier(reason_code, "EXPERIENCE_REASON_REQUIRED")
    candidate_sha256 = canonical_sha256(core, candidate_experience)
    characterization_sha256 = canonical_sha256(core, characterization)
    identity_source = {
        "candidate_experience_sha256": candidate_sha256,
        "characterization_sha256": characterization_sha256,
        "provider_request_sha256": provider_request_sha256,
        "provider_response_sha256": provider_response_sha256,
        "resolution_receipt_sha256": resolution_receipt_sha256,
        "result_class": result_class,
        "reason_code": reason_code,
    }
    identity = canonical_sha256(core, identity_source).removeprefix("sha256:")
    return {
        "schema_version": EXPERIENCE_ENTRY_SCHEMA,
        "experience_id": f"adaptation_experience_{identity[:20]}",
        "candidate_event_id": candidate_experience["candidate_event_id"],
        "lesson_family_id": candidate_experience["lesson_family_id"],
        "candidate_experience": dict(candidate_experience),
        "candidate_experience_sha256": candidate_sha256,
        "characterization_id": characterization["characterization_id"],
        "characterization": dict(characterization),
        "characterization_sha256": characterization_sha256,
        "provider_request_sha256": provider_request_sha256,
        "provider_response_sha256": provider_response_sha256,
        "resolution_receipt_sha256": resolution_receipt_sha256,
        "morphology_descriptor_sha256": characterization[
            "morphology_descriptor_sha256"
        ],
        "result_class": result_class,
        "reason_code": reason_code,
        "candidate_only": True,
        "training_data_authority": False,
        "encyclopedia_promotion_authority": False,
        "scientific_result": False,
        "world_build_count": 0,
        "physical_acceptance_authority": False,
        "release_authority": False,
    }


def validate_experience_entry(
    core: LocomotionCore, entry: Mapping[str, Any]
) -> None:
    _require_exact_fields(
        entry,
        {
            "schema_version",
            "experience_id",
            "candidate_event_id",
            "lesson_family_id",
            "candidate_experience",
            "candidate_experience_sha256",
            "characterization_id",
            "characterization",
            "characterization_sha256",
            "provider_request_sha256",
            "provider_response_sha256",
            "resolution_receipt_sha256",
            "morphology_descriptor_sha256",
            "result_class",
            "reason_code",
            "candidate_only",
            "training_data_authority",
            "encyclopedia_promotion_authority",
            "scientific_result",
            "world_build_count",
            "physical_acceptance_authority",
            "release_authority",
        },
        "EXPERIENCE_ENTRY_FIELDS",
    )
    candidate = entry.get("candidate_experience")
    characterization = entry.get("characterization")
    _require(isinstance(candidate, Mapping), "EXPERIENCE_ENTRY_CANDIDATE_TYPE")
    _require(
        isinstance(characterization, Mapping),
        "EXPERIENCE_ENTRY_CHARACTERIZATION_TYPE",
    )
    _validate_candidate_experience(candidate)
    validate_characterization_receipt(characterization)
    _require(
        entry.get("schema_version") == EXPERIENCE_ENTRY_SCHEMA,
        "EXPERIENCE_ENTRY_SCHEMA",
    )
    for field in (
        "experience_id",
        "candidate_event_id",
        "lesson_family_id",
        "characterization_id",
    ):
        _require_identifier(entry.get(field), "EXPERIENCE_ENTRY_IDENTIFIER")
    for field in (
        "candidate_experience_sha256",
        "characterization_sha256",
        "provider_request_sha256",
        "provider_response_sha256",
        "resolution_receipt_sha256",
        "morphology_descriptor_sha256",
    ):
        _require_sha256(entry.get(field), "EXPERIENCE_ENTRY_DIGEST")
    _require(
        canonical_sha256(core, candidate)
        == entry.get("candidate_experience_sha256"),
        "EXPERIENCE_ENTRY_CANDIDATE_DIGEST",
    )
    _require(
        canonical_sha256(core, characterization)
        == entry.get("characterization_sha256"),
        "EXPERIENCE_ENTRY_CHARACTERIZATION_DIGEST",
    )
    _require(
        candidate.get("candidate_event_id") == entry.get("candidate_event_id")
        and candidate.get("lesson_family_id") == entry.get("lesson_family_id")
        and characterization.get("characterization_id")
        == entry.get("characterization_id")
        and characterization.get("morphology_descriptor_sha256")
        == entry.get("morphology_descriptor_sha256"),
        "EXPERIENCE_ENTRY_EMBEDDED_IDENTITY",
    )
    result_class = entry.get("result_class")
    _require(result_class in RESULT_CLASSES, "EXPERIENCE_ENTRY_RESULT")
    if result_class == "positive":
        _require(entry.get("reason_code") is None, "EXPERIENCE_ENTRY_POSITIVE_REASON")
    else:
        _require_identifier(entry.get("reason_code"), "EXPERIENCE_ENTRY_REASON")
    _require(
        entry.get("candidate_only") is True
        and entry.get("training_data_authority") is False
        and entry.get("encyclopedia_promotion_authority") is False
        and entry.get("scientific_result") is False
        and entry.get("world_build_count") == 0
        and entry.get("physical_acceptance_authority") is False
        and entry.get("release_authority") is False,
        "EXPERIENCE_ENTRY_AUTHORITY",
    )


def _json_bytes(value: Mapping[str, Any]) -> bytes:
    return (
        json.dumps(
            dict(value),
            sort_keys=True,
            separators=(",", ":"),
            ensure_ascii=False,
            allow_nan=False,
        )
        + "\n"
    ).encode("utf-8")


def _write_create_only(path: Path, payload: bytes, code: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with path.open("xb") as stream:
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
    except FileExistsError as error:
        raise ExperienceEncyclopediaError(f"{code}:{path}") from error


class AppendOnlyExperienceEncyclopedia:
    """A create-only candidate-experience object store and hash-chain journal."""

    def __init__(self, core: LocomotionCore, root: str | os.PathLike[str]) -> None:
        self.core = core
        self.root = Path(root).resolve()
        self.objects_root = self.root / "objects" / "sha256"
        self.events_root = self.root / "events"
        self.lock_path = self.root / ".append.lock"

    def _events(self) -> list[tuple[int, str, Path]]:
        if not self.events_root.exists():
            return []
        _require(self.events_root.is_dir(), "EXPERIENCE_EVENTS_NOT_DIRECTORY")
        parsed: list[tuple[int, str, Path]] = []
        for path in self.events_root.iterdir():
            _require(path.is_file(), "EXPERIENCE_EVENT_NOT_FILE", path)
            match = _EVENT_NAME.fullmatch(path.name)
            _require(match is not None, "EXPERIENCE_EVENT_NAME", path.name)
            parsed.append(
                (int(match.group("sequence")), match.group("digest"), path)
            )
        return sorted(parsed)

    def validate(self, *, allow_active_lock: bool = False) -> dict[str, Any]:
        if self.root.exists():
            _require(self.root.is_dir(), "EXPERIENCE_ROOT_NOT_DIRECTORY")
            allowed = {"objects", "events"}
            if allow_active_lock:
                allowed.add(".append.lock")
            _require(
                {path.name for path in self.root.iterdir()} <= allowed,
                "EXPERIENCE_ROOT_CONTENTS",
            )
        _require(
            allow_active_lock or not self.lock_path.exists(),
            "EXPERIENCE_STORE_WRITER_ACTIVE",
        )
        previous_sha256: str | None = None
        experience_digests: list[str] = []
        event_digests: list[str] = []
        result_counts = {result: 0 for result in sorted(RESULT_CLASSES)}
        for ordinal, (sequence, name_digest, path) in enumerate(
            self._events(), start=1
        ):
            _require(sequence == ordinal, "EXPERIENCE_EVENT_SEQUENCE", sequence)
            try:
                event = json.loads(path.read_text(encoding="utf-8"))
            except (OSError, UnicodeError, json.JSONDecodeError) as error:
                raise ExperienceEncyclopediaError(
                    f"EXPERIENCE_EVENT_INVALID:{path}"
                ) from error
            _require(
                event.get("schema_version") == APPEND_EVENT_SCHEMA,
                "EXPERIENCE_EVENT_SCHEMA",
            )
            _require_exact_fields(
                event,
                {
                    "schema_version",
                    "sequence",
                    "previous_event_sha256",
                    "experience_sha256",
                    "characterization_sha256",
                    "result_class",
                    "candidate_only",
                    "training_data_authority",
                    "encyclopedia_promotion_authority",
                    "scientific_result",
                    "physical_acceptance_authority",
                    "release_authority",
                },
                "EXPERIENCE_EVENT_FIELDS",
            )
            _require(event.get("sequence") == sequence, "EXPERIENCE_EVENT_ORDINAL")
            _require(
                event.get("previous_event_sha256") == previous_sha256,
                "EXPERIENCE_EVENT_PARENT",
            )
            event_sha256 = canonical_sha256(self.core, event)
            _require(
                event_sha256.removeprefix("sha256:") == name_digest,
                "EXPERIENCE_EVENT_DIGEST",
            )
            experience_sha256 = event.get("experience_sha256")
            _require_sha256(experience_sha256, "EXPERIENCE_EVENT_EXPERIENCE_DIGEST")
            _require(
                experience_sha256 not in experience_digests,
                "EXPERIENCE_DUPLICATE_EVENT",
            )
            object_path = (
                self.objects_root
                / experience_sha256.removeprefix("sha256:")
                / "payload.json"
            )
            _require(object_path.is_file(), "EXPERIENCE_OBJECT_MISSING", object_path)
            try:
                entry = json.loads(object_path.read_text(encoding="utf-8"))
            except (OSError, UnicodeError, json.JSONDecodeError) as error:
                raise ExperienceEncyclopediaError(
                    f"EXPERIENCE_OBJECT_INVALID:{object_path}"
                ) from error
            validate_experience_entry(self.core, entry)
            _require(
                canonical_sha256(self.core, entry) == experience_sha256,
                "EXPERIENCE_OBJECT_DIGEST",
            )
            _require(
                event.get("characterization_sha256")
                == entry["characterization_sha256"],
                "EXPERIENCE_EVENT_CHARACTERIZATION",
            )
            _require(
                event.get("result_class") == entry["result_class"],
                "EXPERIENCE_EVENT_RESULT",
            )
            _require(
                event.get("candidate_only") is True
                and event.get("training_data_authority") is False
                and event.get("encyclopedia_promotion_authority") is False
                and event.get("scientific_result") is False
                and event.get("physical_acceptance_authority") is False
                and event.get("release_authority") is False,
                "EXPERIENCE_EVENT_AUTHORITY",
            )
            experience_digests.append(experience_sha256)
            event_digests.append(event_sha256)
            result_counts[entry["result_class"]] += 1
            previous_sha256 = event_sha256
        object_digests: set[str] = set()
        if self.objects_root.exists():
            _require(
                self.objects_root.is_dir(), "EXPERIENCE_OBJECTS_NOT_DIRECTORY"
            )
            for directory in self.objects_root.iterdir():
                _require(
                    directory.is_dir()
                    and len(directory.name) == 64
                    and all(
                        character in "0123456789abcdef"
                        for character in directory.name
                    ),
                    "EXPERIENCE_OBJECT_DIRECTORY",
                    directory,
                )
                _require(
                    {path.name for path in directory.iterdir()} == {"payload.json"},
                    "EXPERIENCE_OBJECT_CONTENTS",
                    directory,
                )
                object_digests.add(f"sha256:{directory.name}")
        orphan_digests = sorted(object_digests - set(experience_digests))
        return {
            "schema_version": STORE_RECEIPT_SCHEMA,
            "complete": len(orphan_digests) == 0,
            "event_count": len(event_digests),
            "object_count": len(object_digests),
            "orphan_object_count": len(orphan_digests),
            "orphan_object_sha256": orphan_digests,
            "tail_event_sha256": previous_sha256,
            "ordered_event_sha256": event_digests,
            "ordered_experience_sha256": experience_digests,
            "result_counts": result_counts,
            "append_only": True,
            "candidate_only": True,
            "training_data_authority": False,
            "encyclopedia_promotion_authority": False,
            "scientific_result": False,
            "world_build_count": 0,
            "physics_state_modified": False,
            "physical_acceptance_authority": False,
            "release_authority": False,
        }

    def append(
        self,
        experience: Mapping[str, Any],
        *,
        expected_tail_sha256: str | None,
    ) -> dict[str, Any]:
        validate_experience_entry(self.core, experience)
        self.root.mkdir(parents=True, exist_ok=True)
        _write_create_only(
            self.lock_path,
            _json_bytes({"schema_version": "sporespore_append_lock_v1"}),
            "EXPERIENCE_STORE_WRITER_ACTIVE",
        )
        try:
            before = self.validate(allow_active_lock=True)
            _require(before["complete"] is True, "EXPERIENCE_STORE_INCOMPLETE")
            _require(
                before["tail_event_sha256"] == expected_tail_sha256,
                "EXPERIENCE_STALE_PARENT",
            )
            experience_sha256 = canonical_sha256(self.core, experience)
            _require(
                experience_sha256 not in before["ordered_experience_sha256"],
                "EXPERIENCE_DUPLICATE_APPEND",
            )
            object_path = (
                self.objects_root
                / experience_sha256.removeprefix("sha256:")
                / "payload.json"
            )
            _write_create_only(
                object_path,
                _json_bytes(experience),
                "EXPERIENCE_OBJECT_ALREADY_EXISTS",
            )
            sequence = before["event_count"] + 1
            event = {
                "schema_version": APPEND_EVENT_SCHEMA,
                "sequence": sequence,
                "previous_event_sha256": expected_tail_sha256,
                "experience_sha256": experience_sha256,
                "characterization_sha256": experience[
                    "characterization_sha256"
                ],
                "result_class": experience["result_class"],
                "candidate_only": True,
                "training_data_authority": False,
                "encyclopedia_promotion_authority": False,
                "scientific_result": False,
                "physical_acceptance_authority": False,
                "release_authority": False,
            }
            event_sha256 = canonical_sha256(self.core, event)
            event_path = self.events_root / (
                f"{sequence:020d}-"
                f"{event_sha256.removeprefix('sha256:')}.json"
            )
            _write_create_only(
                event_path,
                _json_bytes(event),
                "EXPERIENCE_EVENT_ALREADY_EXISTS",
            )
            after = self.validate(allow_active_lock=True)
            _require(after["complete"] is True, "EXPERIENCE_APPEND_INCOMPLETE")
            _require(
                after["tail_event_sha256"] == event_sha256,
                "EXPERIENCE_APPEND_TAIL",
            )
            return after
        finally:
            try:
                self.lock_path.unlink()
            except FileNotFoundError:
                pass
