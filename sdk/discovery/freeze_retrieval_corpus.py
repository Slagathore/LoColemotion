"""Freeze independently audited native training data and register an immutable candidate.

This is an offline, create-only development fitting step. The existing Tier 2
architecture still requires all three native qualification engines for promotion.
"""
import argparse
import json
from pathlib import Path
import sys

from gpu_repertoire import ROOT, declaration, trial_plan
from gpu_quadruped_model import sha
from gpu_measurement_probe import write_new
from portable_search_control import bridge
from adaptation_provider.retrieval import learner
from adaptation_provider import tier2_architecture as tier2


def assemble(core, episodes, raw_bindings, *, source_receipt_sha256, synthetic):
    """Pure record/model construction; native provenance is checked by freeze()."""
    plan = learner.contract()
    groups = {g["group_id"]: g for g in plan["groups"] if g["partition"] == "train"}
    actions = [a["action_id"] for a in plan["actions"]]
    require = learner.require
    require(len(episodes) == len(raw_bindings) == 36, "Complete training episode bindings")
    tier2_episodes = []
    for episode, raw in zip(episodes, raw_bindings, strict=True):
        require(episode["group_id"] in groups and raw["group_id"] == episode["group_id"]
            and raw["seed"] == groups[episode["group_id"]]["seed"]
            and type(raw["cell"]) is int and 0 <= raw["cell"] < len(actions)
            and actions[raw["cell"]] == episode["action_id"]
            and raw["descriptor_sha256"] == plan["descriptor_sha256"]
            and raw["expected_outer_rows"] == 480 and raw["expected_internal_rows"] == 2400
            and learner.digest(core, raw) == episode["raw_episode_sha256"]
            and episode["synthetic"] is synthetic, "Crossed raw episode binding or split")
        for value in raw["hashes"].values():
            require(isinstance(value, str) and len(value) == 64 and all(c in "0123456789abcdef" for c in value), "Raw stream digest")
        require(set(raw["hashes"]) == {"controller", "trace", "timing"}, "Raw stream population")
        record = dict(schema_version="sporespore_tier2_episode_v1", episode_id=episode["episode_id"],
            provider_request_sha256=raw["provider_request_sha256"], provider_response_sha256=raw["provider_response_sha256"],
            resolution_receipt_sha256=raw["resolution_receipt_sha256"], morphology_descriptor_sha256=raw["descriptor_sha256"],
            task_id="s169_clocked_walk_forward_020", environment_id="mujoco_warp_flat_mu095_"+episode["group_id"],
            seed=raw["seed"], group_id=episode["group_id"], action_id=episode["action_id"],
            outcome="success" if episode["outcome"] == "positive" else "failure", failure_code=episode["failure_code"],
            outcome_scope="declared_development_episode_eligibility_only", measured_outcome=episode["metrics"],
            raw_episode_sha256=episode["raw_episode_sha256"], feature_and_outcome_sha256=learner.digest(core, episode),
            synthetic=synthetic, candidate_only=True, physical_acceptance_authority=False)
        tier2.validate_episode(record)
        tier2_episodes.append(record)
    # This new development lineage begins empty; no installed encyclopedia is
    # rewritten or treated as having adopted the candidate chapter.
    parent = dict(schema_version="locolemotion_retrieval_development_genesis_v1", encyclopedia_id="s169_retrieval_development_genesis_v1",
        ordered_adopted_chapters=[], candidate_only=True, physical_acceptance_authority=False, release_authority=False)
    chapter = tier2.compile_candidate_chapter(core, lesson_family_id="s169_bounded_bilateral_repertoire_v1",
        parent_encyclopedia_id=parent["encyclopedia_id"], parent_encyclopedia_sha256=learner.digest(core, parent), episodes=tier2_episodes)
    corpus = tier2.freeze_corpus(core, candidate_chapters=[chapter],
        prospective_split_plan_id="retrieval_split_"+learner.digest(core, plan)[7:])
    model = learner.fit(core, episodes, frozen_corpus_id=corpus["corpus_id"],
        frozen_corpus_sha256=learner.digest(core, corpus), source_receipt_sha256=source_receipt_sha256, synthetic=synthetic)
    registration = tier2.register_model_candidate(core, corpus=corpus, model_architecture_id="s169_bounded_retrieval_v1",
        model_artifact_sha256=model.sha256)
    return dict(training_episodes=episodes, raw_episode_bindings=raw_bindings, tier2_episodes=tier2_episodes,
        development_genesis=parent, candidate_chapter=chapter, frozen_corpus=corpus,
        fitted_model=model.document(), model_candidate=registration)


def freeze(attempt, core_path):
    require = learner.require
    evidence = (ROOT.parent / "SporeSpore_Evidence").resolve(strict=True)
    attempt = attempt.resolve(strict=True)
    require(attempt.parent == evidence and attempt.name.startswith("sdk2-gpu-repertoire-"), "Native evidence root")
    c = declaration()
    require(sha(core_path) == c["core_sha256"], "Fitting core binding")
    receipt = json.loads((attempt / "receipt.json").read_text(encoding="utf-8"))
    require(receipt["ok"] is True and receipt["physical_started"] is True and receipt["zero_world_gate_passed"] is True
            and receipt["synthetic"] is False and receipt["contract"] == c
            and receipt["training_data_authority"] is True
            and receipt["physical_acceptance_authority"] is False and receipt["release_authority"] is False,
            "Native campaign is not eligible for development fitting")
    audit = json.loads((attempt / "independent-audit.json").read_text(encoding="utf-8"))
    require(audit == receipt["audit"] and audit["ok"] is True and audit["synthetic"] is False
            and audit["controller_rows"] == 17280 and audit["internal_rows"] == 86400
            and audit["constructed_gpu_worlds"] == 36 and audit["reader_world_build_count"] == 0
            and audit["calibration_worlds"] == audit["evaluation_worlds"] == 0, "Full independent native reader required")
    declared = json.loads((attempt / "declaration.json").read_text())
    require(declared["binding"] == receipt["binding"] and declared["source_commit"] == receipt["source_commit"], "Source identity changed")
    # The launcher already performed full scalar/native replay. Rehash those
    # exact bytes here instead of repeating unchanged controller computation.
    for name, digest in receipt["binding"]["source"].items():
        source = (ROOT / name).resolve(strict=True)
        require(source.is_relative_to(ROOT) and sha(source) == digest, "Fitting source drift")
    for name, digest in receipt["binding"]["runtime"].items():
        require(sha(Path(name)) == digest, "Fitting runtime drift")
    worker = json.loads((attempt / "physical/worker-result.json").read_text())
    require(worker["ok"] is True and len(worker["trials"]) == 4, "Incomplete native worker")
    episodes, raw = [], []
    for plan, observed, result in zip(trial_plan(c), audit["trials"], worker["trials"], strict=True):
        require(all(observed[k] == value and result[k] == value for k,value in plan.items()), "Crossed training group")
        folder = attempt / "physical" / plan["trial_id"]
        require(json.loads((folder/"result.json").read_text()) == result, "Native result index changed")
        for name in ["controller", "trace", "timing"]:
            require(sha(folder/(name+".jsonl")) == result["hashes"][name], "Native raw stream changed")
        require(all(r["hashes"] == result["hashes"] for r in observed["raw_bindings"]), "Audited raw binding changed")
        episodes.extend(observed["episodes"])
        raw.extend(observed["raw_bindings"])
    core = bridge.LocomotionCore(core_path)
    records = assemble(core, episodes, raw, source_receipt_sha256="sha256:"+sha(attempt/"receipt.json"), synthetic=False)
    destination = attempt / "fitted"
    destination.mkdir()  # A consumed fitting identity cannot be overwritten.
    for name, value in records.items():
        write_new(destination/(name+".json"),value)
    binding = dict(schema_version="locolemotion_native_retrieval_fit_receipt_v1", ledger_scope=c["ledger_scope"],
        source_commit=receipt["source_commit"], attempt_id=attempt.name, synthetic=False, world_build_count=0,
        native_training_worlds=36, raw_receipt_sha256=sha(attempt/"receipt.json"), independent_audit_sha256=sha(attempt/"independent-audit.json"),
        artifacts={p.name:sha(p) for p in destination.iterdir()}, fitted_model_sha256=learner.digest(core,records["fitted_model"]),
        eligible_episodes=audit["eligible_episodes"], retained_negative_episodes=audit["retained_negative_episodes"],
        fitted_cases=len(records["fitted_model"]["ordered_cases"]), occupied_archive_cells=len(records["fitted_model"]["ordered_elites"]),
        calibration_worlds=0,evaluation_worlds=0,physical_acceptance_authority=False,release_authority=False,
        provider_promotion_authority=False,base_model_immutable=True)
    write_new(destination/"fit-receipt.json",binding)
    return binding


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("attempt",type=Path)
    p.add_argument("--core",type=Path,required=True)
    a=p.parse_args()
    print(json.dumps(freeze(a.attempt,a.core.resolve(strict=True)),indent=2))
