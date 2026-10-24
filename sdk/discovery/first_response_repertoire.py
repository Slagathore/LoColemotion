"""Fit development context and feedback cases from the complete closed campaign.

No world is constructed. Negative trials remain in the ledger; a condition
estimate and stored successful cases do not establish useful control selection.
"""
import argparse
import copy
import json
from itertools import islice
from pathlib import Path

import first_response_v1 as estimator
from adaptation_provider.retrieval import feedback_flat_v1 as learner
from audit_cpu_phase_release_closure import verify_record, read, ROOT, sha, require, bridge
from audit_gpu_batch_execution import read_jsonl, same_bits

HERE = Path(__file__).resolve().parent
PARENT = HERE / "cpu_phase_release_closure_v1.json"
PARENT_SHA = "df78a08932a8d3ba262190c3ce8c55ba07bced79979985cb9fa17c4dd586983b"
CONTRACT = HERE / "first_response_repertoire_v1.json"
IMMEDIATE_ROLES = ["baseline", "vertical_immediate", "phase_immediate"]


def expected_declaration():
    return dict(schema_version="locolemotion_first_response_repertoire_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
            authority_mode="development_training", question_class="development"),
        parent_closure=dict(path="sdk/discovery/cpu_phase_release_closure_v1.json", sha256=PARENT_SHA),
        analysis="retrospective_authorized_training_only", decision_step=1,
        duration_s=1/120., feature_count=16, feature_schema=estimator.SCHEMA,
        choice_basis="Earliest causal response: one issued command and two observed joint positions. Fixed before fitting; no window sweep.",
        training_groups=8, matching_baseline_prefixes_per_group=2,
        labels=estimator.LABELS, training_start_ids=estimator.STARTS,
        classifier="unscaled nearest centroid; no feature search or confidence fitting",
        internal_validation="four folds, hold both conditions of one training start out together",
        controls=["constant nominal prediction", "synthetic reversal of condition associations"],
        source_trial_count=32, fitted_episode_count=24, immediate_roles=IMMEDIATE_ROLES,
        excluded_role="phase_after_16", exclusion_reason="composite action does not label a single immediate controller",
        retrieval_contract="sdk/adaptation_provider/retrieval/feedback_contract_v1.json",
        condition_default_rule="Rank complete four-start eligible controllers by mean whole-episode quality, then action index; no default when none is complete.",
        previous_confirmation_fitting=False, reserved_calibration_exposed=False, reserved_evaluation_exposed=False,
        worlds_opened=0, action_mapping=None, learned_control_selection=False, adaptation_benefit=False,
        population_inference=False, qualification_or_release_authority=False)


def declaration():
    value = read(CONTRACT)
    require(value == expected_declaration() and sha(PARENT) == PARENT_SHA, "First response declaration/parent")
    plan = learner.contract()
    require([(g["condition_id"], g["start_id"], g["partition"]) for g in plan["groups"]]
        == [(label, start, "train") for label in estimator.LABELS for start in estimator.STARTS]
        and [a["candidate_index"] for a in plan["actions"]] == [0, 3, 4]
        and plan["training_episode_outer_steps"] == 1440, "Feedback training split/actions")
    return value


def joined_feature(rows, core):
    """Rejoin the sole input action to its actual original resolver receipt."""
    require(len(rows) == 2 and [r["outer_step"] for r in rows] == [0, 1], "First response raw chronology")
    request = rows[1]["resolution_request"]["provider_request"]
    entries = request["history"]["ordered_entries"]
    require(len(entries) == 1, "First response raw history count")
    entry, row = entries[0], rows[0]
    original, receipt = row["resolution_request"]["provider_request"], row["resolution"]
    require(entry["semantic_step"] == 0
        and entry["state"] == original["state"] == row["request"]["state"]
        and entry["command"] == original["command"] == row["request"]["command"]
        and entry["deterministic_baseline"] == original["deterministic_baseline"]
        and request["state"] == rows[1]["request"]["state"]
        and entry["provider_status"] == receipt["provider_status"] == "no_proposal"
        and entry["adaptation_applied"] is receipt["adaptation_applied"] is False,
        "First response raw state/action/status join")
    require(entry["request_sha256"] == receipt["request_sha256"]
        and entry["resolution_receipt_sha256"] == learner.digest(core, receipt)
        and entry["ordered_applied_corrections"] == [dict(actuator_id=r["actuator_id"],
            canonical_velocity_delta_rad_s=r["applied_correction_rad_s"]) for r in receipt["ordered_commands"]],
        "First response original receipt join")
    require(same_bits(estimator.history.final_velocities(entry),
        [r["final_canonical_target_velocity_rad_s"] for r in receipt["ordered_commands"]]),
        "First response final issued action join")
    return estimator.features(request)


def extract(attempt, parent, core):
    """Use only after complete parent verification; keep both fresh prefixes."""
    groups = []
    for condition in estimator.LABELS:
        for start in estimator.STARTS:
            trials = [t for t in parent["finite_outcomes"]["trials"] if t["condition_id"] == condition
                and t["start_id"] == start and t["role"] in ["baseline", "phase_after_16"]]
            require([t["role"] for t in trials] == ["baseline", "phase_after_16"], "First response fresh-role group")
            features, sources = [], []
            for trial in trials:
                path = attempt/"physical"/trial["trial_id"]/"controller.jsonl"
                features.append(joined_feature(list(islice(read_jsonl(path), 2)), core))
                sources.append(dict(trial_id=trial["trial_id"], controller_sha256=sha(path),
                    original_whole_episode_outcome=trial["outcome"], original_failure_code=trial["failure_code"]))
            require(same_bits(features[0], features[1]), "First response matching fresh prefixes differ")
            groups.append(dict(group_id=condition+"_"+start, condition_id=condition, start_id=start,
                partition="training", matching_fresh_prefixes=2, features=features[0], sources=sources))
    estimator.validate_groups(groups, complete=True)
    return groups


def corpus_from_verified_trials(trials):
    """Keep all 32 source outcomes, including eight excluded composite episodes."""
    plan = learner.contract()
    expected = [(g["group_id"], role) for g in plan["groups"] for role in [*IMMEDIATE_ROLES, "phase_after_16"]]
    require([(t["group_id"], t["role"]) for t in trials] == expected, "Feedback complete source population")
    episodes, ledger = [], []
    for trial in trials:
        require(trial["partition"] == "training" and len(trial["episodes"]) == 1, "Feedback source split/episode")
        episode = trial["episodes"][0]
        require(episode["group_id"] == trial["group_id"] and episode["synthetic"] is False
            and episode["outcome"] in ["positive", "negative"], "Feedback source episode identity")
        include = trial["role"] in IMMEDIATE_ROLES
        if include:
            action = plan["actions"][IMMEDIATE_ROLES.index(trial["role"])]
            require(episode["action_id"] == action["action_id"]
                and trial["candidate_indices"] == [action["candidate_index"]], "Feedback source action label")
            episodes.append(copy.deepcopy(episode))
        ledger.append(dict(trial_id=trial["trial_id"], group_id=trial["group_id"], role=trial["role"],
            episode_id=episode["episode_id"], outcome=episode["outcome"], failure_code=episode["failure_code"],
            raw_episode_sha256=episode["raw_episode_sha256"], included_in_single_action_fit=include,
            exclusion_reason=None if include else "composite delayed action"))
    return episodes, ledger


def complete_defaults(episodes):
    """A complete controller is a data-derived option, not privileged runtime truth."""
    plan = learner.contract()
    result = []
    for label in estimator.LABELS:
        group_ids = [g["group_id"] for g in plan["groups"] if g["condition_id"] == label]
        ranked, coverage = [], []
        for index, action in enumerate(plan["actions"]):
            rows = [e for e in episodes if e["group_id"] in group_ids and e["action_id"] == action["action_id"]]
            require(len(rows) == 4 and {e["group_id"] for e in rows} == set(group_ids), "Feedback default complete denominator")
            positives = [e for e in rows if e["outcome"] == "positive"]
            complete = len(positives) == 4
            quality = sum(e["metrics"]["quality_m_s"] for e in positives)/4 if complete else None
            coverage.append(dict(action_index=index, eligible=len(positives), denominator=4, complete=complete, mean_quality_m_s=quality))
            if complete: ranked.append((quality, index))
        ranked.sort(key=lambda pair: (-pair[0], pair[1]))
        result.append(dict(condition_id=label, coverage=coverage,
            default_action_index=ranked[0][1] if ranked else None, control_authority=False))
    return result


def run(evidence_root, core_path, baseline_path):
    contract = declaration()
    parent = verify_record(PARENT, evidence_root, core_path, baseline_path)
    record = read(PARENT)
    require(parent["ok"] is True and parent["training_data_authority"] is True
        and parent["finite_outcomes"]["denominator"] == 32, "Feedback complete training authority")
    attempt = evidence_root/record["attempt_id"]
    core = bridge.LocomotionCore(baseline_path)
    groups = extract(attempt, parent, core)
    observed = read(attempt/"independent-audit.json")
    episodes, ledger = corpus_from_verified_trials(observed["trials"])
    corpus = dict(source_parent_sha256=PARENT_SHA, source_ledger=ledger, episodes=episodes)
    model = learner.fit(core, episodes, frozen_corpus_id="phase_release_immediate_feedback_v1",
        frozen_corpus_sha256=learner.digest(core, corpus),
        source_receipt_sha256="sha256:"+record["receipt_sha256"], synthetic=False)
    return dict(schema_version="locolemotion_first_response_repertoire_result_v1", ok=True,
        ledger_scope=contract["ledger_scope"], contract=contract, contract_sha256=sha(CONTRACT),
        estimator_sha256=sha(HERE/"first_response_v1.py"), reader_sha256=sha(Path(__file__)),
        retrieval_contract_sha256=sha(learner.CONTRACT), retrieval_algorithm_sha256=sha(ROOT/"sdk/adaptation_provider/retrieval/learner.py"),
        parent_closure_sha256=PARENT_SHA, parent_source_commit=record["source_commit"],
        parent_attempt_id=record["attempt_id"], parent_artifacts_verified=parent["artifact_count"],
        parent_native_outcomes={k:parent["finite_outcomes"][k] for k in ["eligible", "negative", "denominator"]},
        groups=groups, evaluation=estimator.evaluate(groups), corpus=corpus,
        model=model.document(), model_sha256=model.sha256, complete_condition_defaults=complete_defaults(episodes),
        worlds_opened=0, runtime_selection_implemented=False, adaptation_benefit=False,
        qualification_or_release_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-root", type=Path, default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core", type=Path, required=True)
    parser.add_argument("--baseline-core", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    require(args.output.resolve().is_relative_to(args.evidence_root.resolve()) and not args.output.exists(), "Fresh durable output required")
    result = run(args.evidence_root, args.core, args.baseline_core)
    with args.output.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(result, stream, indent=2, allow_nan=False); stream.write("\n")
    print(json.dumps(dict(ok=True, worlds_opened=0, internal_correct=result["evaluation"]["correct"],
        denominator=8, fitted_cases=len(result["model"]["ordered_cases"]), result_sha256=sha(args.output))))
