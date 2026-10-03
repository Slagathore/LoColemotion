"""Executable Tier 2 candidate-chapter and successor-promotion architecture."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Iterable, Mapping

try:
    from sporespore_locomotion import LocomotionCore
except ImportError:
    from python.sporespore_locomotion import LocomotionCore


ARCHITECTURE_PATH = Path(__file__).resolve().with_name(
    "tier2_architecture_v1.json"
)
REQUIRED_QUALIFICATION_ENGINES = {
    "godot_jolt",
    "rapier_parry",
    "mujoco_cpu",
}


class Tier2ArchitectureError(ValueError):
    """A Tier 2 record violated an append-only or authority boundary."""


def _require(condition: bool, code: str, detail: str = "") -> None:
    if not condition:
        raise Tier2ArchitectureError(f"{code}:{detail}")


def _require_sha256(value: object, code: str) -> None:
    _require(
        isinstance(value, str)
        and value.startswith("sha256:")
        and len(value) == 71
        and all(character in "0123456789abcdef" for character in value[7:]),
        code,
        str(value),
    )


def load_tier2_architecture() -> dict[str, Any]:
    architecture = json.loads(ARCHITECTURE_PATH.read_text(encoding="utf-8"))
    _require(
        architecture.get("schema_version")
        == "sporespore_tier2_adaptation_architecture_v1",
        "TIER2_ARCHITECTURE_SCHEMA",
    )
    _require(
        architecture.get("physical_acceptance_authority") is False,
        "TIER2_ARCHITECTURE_AUTHORITY",
    )
    return architecture


def canonical_sha256(core: LocomotionCore, value: Mapping[str, Any]) -> str:
    return core.canonicalize_json(value)["sha256"]


def validate_episode(episode: Mapping[str, Any]) -> None:
    _require(
        episode.get("schema_version") == "sporespore_tier2_episode_v1",
        "TIER2_EPISODE_SCHEMA",
    )
    for field in (
        "episode_id",
        "provider_request_sha256",
        "provider_response_sha256",
        "resolution_receipt_sha256",
        "morphology_descriptor_sha256",
        "task_id",
        "environment_id",
        "outcome",
    ):
        _require(bool(episode.get(field)), "TIER2_EPISODE_FIELD", field)
    for field in (
        "provider_request_sha256",
        "provider_response_sha256",
        "resolution_receipt_sha256",
        "morphology_descriptor_sha256",
    ):
        _require_sha256(episode.get(field), "TIER2_EPISODE_DIGEST")
    _require(
        episode.get("outcome") in {"success", "failure"},
        "TIER2_EPISODE_OUTCOME",
    )
    _require(
        episode.get("outcome") == "failure"
        or episode.get("failure_code") is None,
        "TIER2_SUCCESS_HAS_FAILURE_CODE",
    )
    _require(
        episode.get("outcome") == "success"
        or bool(episode.get("failure_code")),
        "TIER2_FAILURE_MISSING_CODE",
    )
    _require(episode.get("candidate_only") is True, "TIER2_NOT_CANDIDATE")
    _require(
        episode.get("physical_acceptance_authority") is False,
        "TIER2_EPISODE_AUTHORITY",
    )


def compile_candidate_chapter(
    core: LocomotionCore,
    *,
    lesson_family_id: str,
    parent_encyclopedia_id: str,
    parent_encyclopedia_sha256: str,
    episodes: Iterable[Mapping[str, Any]],
) -> dict[str, Any]:
    retained = [dict(episode) for episode in episodes]
    _require(bool(retained), "TIER2_CHAPTER_EMPTY")
    _require_sha256(
        parent_encyclopedia_sha256, "TIER2_PARENT_ENCYCLOPEDIA_DIGEST"
    )
    for episode in retained:
        validate_episode(episode)
    episode_digests = [canonical_sha256(core, episode) for episode in retained]
    _require(
        len(episode_digests) == len(set(episode_digests)),
        "TIER2_DUPLICATE_EPISODE",
    )
    identity_source = {
        "lesson_family_id": lesson_family_id,
        "parent_encyclopedia_sha256": parent_encyclopedia_sha256,
        "ordered_episode_sha256": episode_digests,
    }
    identity = canonical_sha256(core, identity_source).removeprefix("sha256:")
    return {
        "schema_version": "sporespore_tier2_candidate_chapter_v1",
        "candidate_chapter_id": f"candidate_chapter_{identity[:20]}",
        "lesson_family_id": lesson_family_id,
        "parent_encyclopedia_id": parent_encyclopedia_id,
        "parent_encyclopedia_sha256": parent_encyclopedia_sha256,
        "ordered_episode_sha256": episode_digests,
        "success_count": sum(
            episode["outcome"] == "success" for episode in retained
        ),
        "counterexample_count": sum(
            episode["outcome"] == "failure" for episode in retained
        ),
        "append_only": True,
        "candidate_only": True,
        "parent_rewritten": False,
        "deployed_provider_mutated": False,
        "encyclopedia_promotion_authority": False,
        "physical_acceptance_authority": False,
    }


def validate_candidate_chapter(chapter: Mapping[str, Any]) -> None:
    _require(
        chapter.get("schema_version")
        == "sporespore_tier2_candidate_chapter_v1",
        "TIER2_CHAPTER_SCHEMA",
    )
    _require(bool(chapter.get("ordered_episode_sha256")), "TIER2_CHAPTER_EMPTY")
    _require(chapter.get("append_only") is True, "TIER2_CHAPTER_MUTABLE")
    _require(chapter.get("candidate_only") is True, "TIER2_CHAPTER_PROMOTED")
    _require(chapter.get("parent_rewritten") is False, "TIER2_PARENT_REWRITE")
    _require(
        chapter.get("deployed_provider_mutated") is False,
        "TIER2_PROVIDER_MUTATION",
    )
    _require(
        chapter.get("encyclopedia_promotion_authority") is False,
        "TIER2_CHAPTER_SELF_PROMOTION",
    )
    _require(
        chapter.get("physical_acceptance_authority") is False,
        "TIER2_CHAPTER_AUTHORITY",
    )


def freeze_corpus(
    core: LocomotionCore,
    *,
    candidate_chapters: Iterable[Mapping[str, Any]],
    prospective_split_plan_id: str,
) -> dict[str, Any]:
    chapters = [dict(chapter) for chapter in candidate_chapters]
    _require(bool(chapters), "TIER2_CORPUS_EMPTY")
    for chapter in chapters:
        validate_candidate_chapter(chapter)
    chapter_digests = [canonical_sha256(core, chapter) for chapter in chapters]
    _require(
        len(chapter_digests) == len(set(chapter_digests)),
        "TIER2_DUPLICATE_CHAPTER",
    )
    identity_source = {
        "prospective_split_plan_id": prospective_split_plan_id,
        "ordered_candidate_chapter_sha256": chapter_digests,
    }
    identity = canonical_sha256(core, identity_source).removeprefix("sha256:")
    return {
        "schema_version": "sporespore_tier2_frozen_corpus_v1",
        "corpus_id": f"tier2_corpus_{identity[:20]}",
        "prospective_split_plan_id": prospective_split_plan_id,
        "ordered_candidate_chapter_sha256": chapter_digests,
        "immutable_after_freeze": True,
        "observed_results_may_change_split": False,
        "training_artifact_has_physical_authority": False,
        "physical_acceptance_authority": False,
    }


def register_model_candidate(
    core: LocomotionCore,
    *,
    corpus: Mapping[str, Any],
    model_architecture_id: str,
    model_artifact_sha256: str,
) -> dict[str, Any]:
    _require(
        corpus.get("schema_version") == "sporespore_tier2_frozen_corpus_v1",
        "TIER2_MODEL_CORPUS_SCHEMA",
    )
    _require(
        corpus.get("immutable_after_freeze") is True,
        "TIER2_MODEL_CORPUS_MUTABLE",
    )
    _require(
        corpus.get("training_artifact_has_physical_authority") is False
        and corpus.get("physical_acceptance_authority") is False,
        "TIER2_MODEL_CORPUS_AUTHORITY",
    )
    _require_sha256(model_artifact_sha256, "TIER2_MODEL_ARTIFACT_DIGEST")
    corpus_sha256 = canonical_sha256(core, corpus)
    identity_source = {
        "corpus_sha256": corpus_sha256,
        "model_architecture_id": model_architecture_id,
        "model_artifact_sha256": model_artifact_sha256,
    }
    identity = canonical_sha256(core, identity_source).removeprefix("sha256:")
    return {
        "schema_version": "sporespore_tier2_model_candidate_v1",
        "model_candidate_id": f"tier2_model_{identity[:20]}",
        "model_architecture_id": model_architecture_id,
        "model_artifact_sha256": model_artifact_sha256,
        "frozen_corpus_id": corpus["corpus_id"],
        "frozen_corpus_sha256": corpus_sha256,
        "base_model_immutable": True,
        "online_weight_mutation_permitted": False,
        "deterministic_baseline_fallback_required": True,
        "candidate_only": True,
        "physical_acceptance_authority": False,
    }


def promote_successor_release(
    core: LocomotionCore,
    *,
    candidate_chapter: Mapping[str, Any],
    corpus: Mapping[str, Any],
    model_candidate: Mapping[str, Any],
    qualifications: Iterable[Mapping[str, Any]],
) -> dict[str, Any]:
    validate_candidate_chapter(candidate_chapter)
    chapter_sha256 = canonical_sha256(core, candidate_chapter)
    _require(
        chapter_sha256 in corpus.get("ordered_candidate_chapter_sha256", []),
        "TIER2_PROMOTION_CHAPTER_NOT_IN_CORPUS",
    )
    _require(
        model_candidate.get("schema_version")
        == "sporespore_tier2_model_candidate_v1",
        "TIER2_PROMOTION_MODEL_SCHEMA",
    )
    _require(
        model_candidate.get("frozen_corpus_sha256")
        == canonical_sha256(core, corpus),
        "TIER2_PROMOTION_MODEL_CORPUS_MISMATCH",
    )
    _require(
        model_candidate.get("base_model_immutable") is True
        and model_candidate.get("online_weight_mutation_permitted") is False
        and model_candidate.get("deterministic_baseline_fallback_required")
        is True
        and model_candidate.get("candidate_only") is True
        and model_candidate.get("physical_acceptance_authority") is False,
        "TIER2_PROMOTION_MODEL_AUTHORITY",
    )
    retained = [dict(qualification) for qualification in qualifications]
    engines = {item.get("engine_id") for item in retained}
    _require(
        engines == REQUIRED_QUALIFICATION_ENGINES
        and len(retained) == len(REQUIRED_QUALIFICATION_ENGINES),
        "TIER2_PROMOTION_ENGINE_SET",
        ",".join(sorted(str(engine) for engine in engines)),
    )
    for qualification in retained:
        _require(
            qualification.get("schema_version")
            == "sporespore_tier2_engine_qualification_v1",
            "TIER2_QUALIFICATION_SCHEMA",
        )
        _require(
            qualification.get("prospective_contract_frozen") is True,
            "TIER2_QUALIFICATION_NOT_PROSPECTIVE",
        )
        _require(
            qualification.get("accepted") is True,
            "TIER2_QUALIFICATION_NOT_ACCEPTED",
            str(qualification.get("engine_id")),
        )
        _require_sha256(
            qualification.get("evidence_sha256"),
            "TIER2_QUALIFICATION_EVIDENCE",
        )
        _require(
            qualification.get("training_plane") is False,
            "TIER2_TRAINING_PLANE_PROMOTION",
        )
        _require(
            qualification.get("physical_acceptance_authority") is False,
            "TIER2_QUALIFICATION_RECORD_AUTHORITY",
        )
    qualification_digests = [
        canonical_sha256(core, qualification) for qualification in retained
    ]
    identity_source = {
        "candidate_chapter_sha256": chapter_sha256,
        "model_candidate_sha256": canonical_sha256(core, model_candidate),
        "qualification_sha256": qualification_digests,
    }
    identity = canonical_sha256(core, identity_source).removeprefix("sha256:")
    return {
        "schema_version": "sporespore_tier2_promotion_receipt_v1",
        "promotion_id": f"tier2_promotion_{identity[:20]}",
        "predecessor_encyclopedia_id": candidate_chapter[
            "parent_encyclopedia_id"
        ],
        "predecessor_encyclopedia_sha256": candidate_chapter[
            "parent_encyclopedia_sha256"
        ],
        "successor_encyclopedia_id": f"behavior_encyclopedia_{identity[:20]}",
        "successor_provider_id": f"adaptation_provider_{identity[:20]}",
        "candidate_chapter_sha256": chapter_sha256,
        "model_candidate_sha256": canonical_sha256(core, model_candidate),
        "ordered_qualification_sha256": qualification_digests,
        "required_engine_set_complete": True,
        "predecessor_rewritten": False,
        "deployed_provider_mutated_in_place": False,
        "successor_identity_new": True,
        "architecture_fixture_only": any(
            qualification.get("architecture_fixture_only") is True
            for qualification in retained
        ),
        "physical_acceptance_authority": False,
    }
