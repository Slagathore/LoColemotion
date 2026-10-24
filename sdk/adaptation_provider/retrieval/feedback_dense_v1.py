"""Distinct command-resolution case fitting with the same 30-command horizon.

Overlapping windows are correlated examples, not additional physical trials.
The original sparse fitter and every observed result remain unchanged.
"""
import copy
import importlib.util
import sys
from pathlib import Path

_directory = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(__name__+"_base", _directory/"learner.py")
_runtime = importlib.util.module_from_spec(_spec)
sys.modules[_spec.name] = _runtime
_spec.loader.exec_module(_runtime)
_runtime.CONTRACT = _directory/"feedback_dense_contract_v1.json"
CONTRACT = _runtime.CONTRACT
require, finite, digest = _runtime.require, _runtime.finite, _runtime.digest
quality, validate_cue, archive_index = _runtime.quality, _runtime.validate_cue, _runtime.archive_index
FrozenModel, cue = _runtime.FrozenModel, _runtime.cue
empty_memory = _runtime.empty_memory


def contract():
    value = _runtime.contract()
    require(value["training_window_stride_steps"] == 1 and value["training_episode_outer_steps"] == 1440,
        "Command-resolution fitting stride/horizon")
    return value


def fit(core, episodes, *, frozen_corpus_id, frozen_corpus_sha256, source_receipt_sha256, synthetic):
    """Fit only declared training groups; retain every rejected/failed identity.

    Native callers must first verify the source campaign and raw-episode joins.
    This pure fitting function verifies its data shape and split membership; its
    result remains an unpromoted model candidate even with a native source.
    """
    plan = contract()
    require(type(synthetic) is bool and bool(frozen_corpus_id), "Corpus identity")
    for value in [frozen_corpus_sha256, source_receipt_sha256]:
        require(isinstance(value, str) and len(value) == 71 and value.startswith("sha256:")
                and all(c in "0123456789abcdef" for c in value[7:]), "Corpus/source digest")
    train_groups = {r["group_id"] for r in plan["groups"] if r["partition"] == "train"}
    actions = [row["action_id"] for row in plan["actions"]]
    cases, ledger, elites = [], [], {}
    identities = set()
    pairs = set()
    for episode in episodes:
        require(set(episode) == {"episode_id", "group_id", "action_id", "outcome", "failure_code",
                "raw_episode_sha256", "synthetic", "metrics", "windows"}, "Episode fields")
        require(episode["group_id"] in train_groups and episode["action_id"] in actions
                and episode["synthetic"] is synthetic, "Split leakage or crossed episode identity")
        identity = episode["episode_id"]
        pair = (episode["group_id"], episode["action_id"])
        require(isinstance(identity, str) and identity and identity not in identities and pair not in pairs,
                "Duplicate episode/group-action")
        identities.add(identity)
        pairs.add(pair)
        require(episode["outcome"] in ["positive", "negative", "rejected", "invalid", "incomplete"], "Episode outcome")
        require((episode["failure_code"] is None) == (episode["outcome"] == "positive"), "Failure classification")
        raw = episode["raw_episode_sha256"]
        require(isinstance(raw, str) and len(raw) == 71 and raw.startswith("sha256:")
                and all(c in "0123456789abcdef" for c in raw[7:]), "Raw episode digest")
        ledger.append(dict(episode_id=identity, group_id=episode["group_id"], action_id=episode["action_id"],
            outcome=episode["outcome"], failure_code=episode["failure_code"], episode_sha256=digest(core, episode),
            raw_episode_sha256=raw))
        if episode["outcome"] != "positive":
            # Failed/invalid trials remain visible, but cannot supply positive cases.
            continue
        require(set(episode["metrics"]) == {"mean_height_m", "lateral_displacement_m", "quality_m_s"}
                and all(finite(v) for v in episode["metrics"].values())
                and episode["metrics"]["quality_m_s"] <= 0., "Episode metrics")
        starts = []
        for window in episode["windows"]:
            require(set(window) == {"start_step", "cue", "start_position_xz_m", "end_position_xz_m", "quality_m_s"}, "Window fields")
            step = window["start_step"]
            require(type(step) is int and step >= 0 and step % plan["training_window_stride_steps"] == 0
                    and step + plan["decision_window_steps"] <= plan["training_episode_outer_steps"], "Window step")
            validate_cue(window["cue"])
            expected = quality(window["start_position_xz_m"], window["end_position_xz_m"],
                               plan["decision_window_steps"] * plan["controller_dt_s"], plan)
            require(window["quality_m_s"] == expected, "Window outcome does not match positions")
            starts.append(step)
            cases.append(dict(case_id=identity + "_" + str(step), episode_id=identity,
                action_index=actions.index(episode["action_id"]), cue=copy.deepcopy(window["cue"]), quality_m_s=expected))
        require(starts == list(range(0, plan["training_episode_outer_steps"]-plan["decision_window_steps"]+1, plan["training_window_stride_steps"])), "Missing/reordered training window")
        index = archive_index(episode["metrics"], plan)
        if index is not None:
            key = tuple(index)
            entry = dict(niche=index, episode_id=identity, action_id=episode["action_id"], quality_m_s=episode["metrics"]["quality_m_s"])
            previous = elites.get(key)
            if previous is None or (-entry["quality_m_s"], identity) < (-previous["quality_m_s"], previous["episode_id"]):
                elites[key] = entry
    require(pairs == {(group, action) for group in train_groups for action in actions}, "Incomplete training trial ledger")
    require(cases and any(row["action_index"] == 0 for row in cases), "No eligible baseline cases")
    document = dict(schema_version="locolemotion_fitted_retrieval_model_v1", contract_sha256=digest(core, plan),
        synthetic=synthetic, fitted=True, frozen_corpus_id=frozen_corpus_id, frozen_corpus_sha256=frozen_corpus_sha256,
        source_receipt_sha256=source_receipt_sha256, ordered_episode_ledger=ledger,
        ordered_elites=[elites[key] for key in sorted(elites)], ordered_cases=cases,
        base_model_immutable=True, physical_acceptance_authority=False, release_authority=False)
    return FrozenModel.load(core, document)


