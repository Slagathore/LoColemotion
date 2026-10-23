"""Rejoin authorized native training prefixes and test an earlier context label.

This retrospective development diagnostic opens no physics worlds. It cannot
promote the failed 64-command repertoire or authorize any controller choice.
"""
import argparse
import json
from itertools import islice
from pathlib import Path

import early_context_v1 as estimator
from audit_cpu_context_repertoire_closure import verify_record, read, ROOT, sha, require
from audit_gpu_batch_execution import read_jsonl, same_bits

HERE = Path(__file__).resolve().parent
PARENT = HERE / "cpu_context_repertoire_closure_v1.json"
PARENT_SHA = "2319c59193e479b40da845d80cb0af95988ab70432cd7280d1681f9959983af4"
CONTRACT = HERE / "early_context_feasibility_v1.json"


def expected_declaration():
    return dict(schema_version="locolemotion_early_context_feasibility_v1",
        ledger_scope=dict(subsystem="adaptation", engine_scope="mujoco_cpu",
            authority_mode="development_training_diagnostic", question_class="development"),
        parent_closure=dict(path="sdk/discovery/cpu_context_repertoire_closure_v1.json", sha256=PARENT_SHA),
        analysis="retrospective_authorized_training_prefixes_only", decision_step=16,
        duration_s=16/120., feature_count=16, feature_schema=estimator.SCHEMA,
        choice_basis="One quarter of the previous 64-command prefix, fixed before this diagnostic; no window sweep.",
        training_groups=8, matching_fresh_roles_per_group=3,
        labels=estimator.LABELS, training_start_ids=estimator.STARTS,
        classifier="unscaled nearest centroid; no feature search or threshold fitting",
        internal_validation="four folds, hold both condition groups at one training start out together",
        controls=["constant nominal prediction", "synthetic reversal of condition associations"],
        previous_confirmation_fitting=False, reserved_calibration_exposed=False, reserved_evaluation_exposed=False,
        worlds_opened=0, action_mapping=None, learned_control_selection=False, adaptation_benefit=False,
        population_inference=False, qualification_or_release_authority=False)


def declaration():
    value = read(CONTRACT)
    require(value == expected_declaration() and sha(PARENT) == PARENT_SHA, "Early context declaration/parent")
    return value


def extract(attempt, parent):
    """Call only after complete parent closure verification, including receipt joins."""
    trials = parent["finite_outcomes"]["trials"]
    groups = []
    for condition in estimator.LABELS:
        for start in estimator.STARTS:
            selected = [t for t in trials if t["condition_id"] == condition and t["start_id"] == start]
            require(len(selected) == 3 and [t["action_index"] for t in selected] == [0,1,2],
                    "Early context complete fresh-role group")
            features, sources = [], []
            for trial in selected:
                path = attempt/"physical"/trial["trial_id"]/"controller.jsonl"
                rows = list(islice(read_jsonl(path), estimator.STEPS+1))
                require(len(rows) == estimator.STEPS+1 and all(row["outer_step"] == i for i,row in enumerate(rows)),
                        "Early context raw prefix chronology")
                request = rows[-1]["resolution_request"]["provider_request"]
                entries = request["history"]["ordered_entries"]
                require(len(entries) == estimator.STEPS, "Early context raw history count")
                for entry,row in zip(entries,rows[:-1],strict=True):
                    receipt = row["resolution"]
                    require(entry["state"] == row["request"]["state"]
                            and entry["command"] == row["request"]["command"]
                            and entry["request_sha256"] == receipt["request_sha256"]
                            and entry["provider_status"] == receipt["provider_status"] == "no_proposal"
                            and entry["adaptation_applied"] is receipt["adaptation_applied"] is False,
                            "Early context raw resolved history join")
                    velocities = estimator.history.final_velocities(entry)
                    require(same_bits(velocities,[c["final_canonical_target_velocity_rad_s"] for c in receipt["ordered_commands"]]),
                            "Early context actual issued action join")
                features.append(estimator.features(request))
                sources.append(dict(trial_id=trial["trial_id"], controller_sha256=sha(path),
                    original_whole_episode_outcome=trial["outcome"], original_failure_code=trial["failure_code"]))
            require(all(same_bits(features[0],f) for f in features[1:]), "Early context shared prefix differs")
            groups.append(dict(group_id=condition+"_"+start,condition_id=condition,start_id=start,
                partition="training",matching_fresh_prefixes=3,features=features[0],sources=sources))
    estimator.validate_groups(groups, complete=True)
    return groups


def run(evidence_root, core, baseline):
    contract = declaration()
    parent = verify_record(PARENT, evidence_root, core, baseline)
    record = read(PARENT)
    require(parent["ok"] is True and parent["training_data_authority"] is True
            and parent["finite_outcomes"]["eligible"] == parent["finite_outcomes"]["negative"] == 12,
            "Early context verified complete training authority")
    groups = extract(evidence_root/record["attempt_id"],parent)
    evaluation = estimator.evaluate(groups)
    return dict(schema_version="locolemotion_early_context_feasibility_result_v1",ok=True,
        ledger_scope=contract["ledger_scope"], contract=contract, contract_sha256=sha(CONTRACT),
        estimator_sha256=sha(HERE/"early_context_v1.py"), reader_sha256=sha(Path(__file__)),
        parent_closure_sha256=PARENT_SHA, parent_source_commit=record["source_commit"],
        parent_attempt_id=record["attempt_id"], parent_artifacts_verified=parent["artifact_count"],
        parent_native_outcomes=dict(eligible=12,negative=12,denominator=24),
        groups=groups, evaluation=evaluation, worlds_opened=0,
        training_data_scope="development_condition_estimation_only",
        qualification_or_release_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    parser.add_argument("--core",type=Path,required=True)
    parser.add_argument("--baseline-core",type=Path,required=True)
    parser.add_argument("--output",type=Path,required=True)
    args = parser.parse_args()
    require(args.output.resolve().is_relative_to(args.evidence_root.resolve()), "Diagnostic output outside durable evidence")
    require(not args.output.exists(), "Diagnostic output is single use")
    result = run(args.evidence_root,args.core,args.baseline_core)
    with args.output.open("x",encoding="utf-8",newline="\n") as stream:
        json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")
    print(json.dumps(dict(ok=True,worlds_opened=0,groups=len(result["groups"]),
        internal_correct=result["evaluation"]["correct"],denominator=8,
        constant_nominal_correct=result["evaluation"]["constant_nominal_correct"],
        swapped_association_correct=result["evaluation"]["swapped_association_correct"],
        result_sha256=sha(args.output))))
