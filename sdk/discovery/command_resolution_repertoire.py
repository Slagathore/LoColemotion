"""Rebuild a distinct dense casebook from the complete retained trajectories."""
import argparse
import copy
from dataclasses import replace
import json
from pathlib import Path

from adaptation_provider.retrieval import feedback_dense_v1 as learner
from audit_first_response_repertoire import verify_record, RECORD as PARENT, ROOT, sha, read, require
from audit_gpu_batch_execution import read_jsonl
from portable_search_control import bridge

HERE = Path(__file__).resolve().parent
CONTRACT = HERE/"command_resolution_repertoire_v1.json"
PARENT_SHA = "dcd829f123b0ec15aa383049ebed5ba2b8d1bc0fc3854109b880d2435f6aefec"


def expected_declaration():
    return dict(schema_version="locolemotion_command_resolution_repertoire_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",authority_mode="development_training",question_class="development"),
        parent_closure=dict(path="sdk/discovery/first_response_repertoire_closure_v1.json",sha256=PARENT_SHA),
        reason="The sparse casebook has no exact phase/contact support after the first baseline command in all four weakened training starts.",
        failed_provider_controls="sdk2-conditioned-provider-controls-5bcd04ae2724479f8e244242e97de37b",
        retained_diagnosis="sdk2-conditioned-provider-diagnostic-03b2ea566ebc4338a378ee0664cb2481",
        training_window_stride_steps=1,outcome_horizon_commands=30,phase_bin_commands=30,
        episode_commands=1440,windows_per_eligible_episode=1411,
        choice_basis="Use every command with a complete unchanged 30-command outcome horizon; no stride/window search.",
        exact_contact_matching_preserved=True,state_support_distance_preserved=1.5,
        source_trials=32,fitted_immediate_episodes=24,eligible_episodes=15,negative_episodes=9,
        excluded_composite_episodes=8,expected_case_count=21165,
        whole_episode_quality="retain original 48 nonoverlapping-window mean for complete-controller defaults",
        overlapping_examples_are_independent_trials=False,context_estimator_refitted=False,
        previous_confirmation_fitting=False,reserved_calibration_exposed=False,reserved_evaluation_exposed=False,
        worlds_opened=0,runtime_selection_implemented=False,adaptation_benefit=False,qualification_or_release_authority=False)


def declaration():
    value=read(CONTRACT)
    require(value == expected_declaration() and sha(PARENT) == PARENT_SHA,"Command-resolution declaration/parent")
    plan=learner.contract()
    require(plan["training_window_stride_steps"] == 1 and plan["decision_window_steps"] == plan["phase_bin_steps"] == 30
        and plan["maximum_support_distance"] == 1.5,"Command-resolution unchanged support/horizon")
    return value


def expand_episode(original, rows, plan):
    """The physical eligibility and whole-episode score are inherited unchanged."""
    episode=copy.deepcopy(original)
    episode["episode_id"] += "_command_resolution_v1"
    if original["outcome"] != "positive":
        require(original["windows"] == [] and original["metrics"]["quality_m_s"] is None,"Failed source windows/quality")
        require(rows is None,"Failed episodes must not supply positive cases")
        return episode
    count=plan["training_episode_outer_steps"]
    require(len(rows) == count and [r["outer_step"] for r in rows] == list(range(count)),"Dense source chronology")
    require([w["start_step"] for w in original["windows"]] == list(range(0,count,30)),"Original whole-episode window population")
    positions=[];cues=[]
    for row in rows:
        request=row["resolution_request"]["provider_request"]
        require(request["state"] == row["request"]["state"] and request["command"] == row["request"]["command"]
            and request["deterministic_baseline"] == row["composition"]["canonical_actuation"]
            and request["controller_context"]["controller_memory"] == row["output"]["next_memory"],"Dense canonical source join")
        position=request["state"]["base_pose_world"]["position_m"]
        positions.append([position["x"],position["z"]]);cues.append(learner.cue(request,plan))
    # The terminal native position is already independently verified by the
    # parent closure and retained in its final complete outcome window.
    positions.append(original["windows"][-1]["end_position_xz_m"])
    windows=[]
    for step in range(count-plan["decision_window_steps"]+1):
        end=step+plan["decision_window_steps"]
        windows.append(dict(start_step=step,cue=cues[step],start_position_xz_m=positions[step],
            end_position_xz_m=positions[end],quality_m_s=learner.quality(positions[step],positions[end],30*plan["controller_dt_s"],plan)))
    require(all(windows[w["start_step"]] == w for w in original["windows"]),"Dense fit changed an original sparse window")
    episode["windows"]=windows
    return episode


def corpus(result, evidence_root):
    attempt=evidence_root/result["parent_attempt_id"]
    ledger=result["corpus"]["source_ledger"]
    sources={r["episode_id"]:r for r in ledger if r["included_in_single_action_fit"]}
    require(len(ledger) == 32 and len(sources) == 24,"Dense complete source ledger")
    plan=learner.contract();episodes=[];bindings=[]
    for original in result["corpus"]["episodes"]:
        source=sources[original["episode_id"]]
        path=attempt/"physical"/source["trial_id"]/"controller.jsonl"
        raw=read(path.with_name("result.json"))
        digest=sha(path)
        require(digest == raw["hashes"]["controller"],"Dense controller stream changed")
        rows=list(read_jsonl(path)) if original["outcome"] == "positive" else None
        episodes.append(expand_episode(original,rows,plan))
        bindings.append(dict(trial_id=source["trial_id"],original_episode_id=original["episode_id"],
            derived_episode_id=episodes[-1]["episode_id"],controller_sha256=digest,
            raw_episode_sha256=original["raw_episode_sha256"],outcome=original["outcome"]))
    return dict(source_fit_sha256=PARENT_SHA,source_ledger=ledger,source_bindings=bindings,episodes=episodes)


def first_response_support(core, model, parent, evidence_root):
    """Coverage diagnostic on exposed queries, not new episodes or runtime proof."""
    plan=model.plan();doc=model.document()
    groups={g["group_id"]:g["condition_id"] for g in plan["groups"]}
    episodes={e["episode_id"]:groups[e["group_id"]] for e in doc["ordered_episode_ledger"]}
    cases={c["case_id"]:episodes[c["episode_id"]] for c in doc["ordered_cases"]}
    output=[]
    for group in parent["groups"]:
        path=evidence_root/parent["parent_attempt_id"] /"physical"/group["sources"][0]["trial_id"]/"controller.jsonl"
        with path.open(encoding="utf-8") as stream:
            next(stream);row=json.loads(next(stream))
        query=learner.cue(row["resolution_request"]["provider_request"],plan)
        filtered=replace(model,cases=tuple(r for r in model.cases if cases[r[-1]] == group["condition_id"]))
        predictions=filtered.predictions(query)
        output.append(dict(group_id=group["group_id"],condition_id=group["condition_id"],
            exposed_condition_label_used_for_diagnostic=True,query=query,
            predictions=[dict(action_index=a,**p) for a,p in sorted(predictions.items())],
            supported_action_indices=sorted(predictions)))
    return output


def run(evidence_root, core_path, baseline_path):
    contract=declaration()
    verified=verify_record(PARENT,evidence_root,core_path,baseline_path)
    require(verified["ok"] is True and verified["worlds_opened"] == 0,"Dense parent fitting proof")
    parent=read(PARENT)["result"]
    core=bridge.LocomotionCore(baseline_path)
    data=corpus(parent,evidence_root)
    corpus_sha=learner.digest(core,data)
    source_record=read(HERE/"cpu_phase_release_closure_v1.json")
    model=learner.fit(core,data["episodes"],frozen_corpus_id="phase_release_command_resolution_feedback_v1",
        frozen_corpus_sha256=corpus_sha,source_receipt_sha256="sha256:"+source_record["receipt_sha256"],synthetic=False)
    require(len(model.cases) == contract["expected_case_count"],"Dense case population")
    return dict(schema_version="locolemotion_command_resolution_repertoire_result_v1",ok=True,
        ledger_scope=contract["ledger_scope"],contract=contract,contract_sha256=sha(CONTRACT),
        reader_sha256=sha(Path(__file__)),fitter_sha256=sha(ROOT/"sdk/adaptation_provider/retrieval/feedback_dense_v1.py"),
        fitting_contract_sha256=sha(learner.CONTRACT),parent_fit_sha256=PARENT_SHA,
        parent_attempt_id=parent["parent_attempt_id"],parent_artifacts_verified=verified["parent_artifacts_verified"],
        source_ledger=data["source_ledger"],source_bindings=data["source_bindings"],corpus_sha256=corpus_sha,
        groups=parent["groups"],evaluation=parent["evaluation"],complete_condition_defaults=parent["complete_condition_defaults"],
        model=model.document(),model_sha256=model.sha256,case_count=len(model.cases),
        first_response_support=first_response_support(core,model,parent,evidence_root),
        worlds_opened=0,context_estimator_refitted=False,overlapping_cases_are_independent_trials=False,
        runtime_selection_implemented=False,adaptation_benefit=False,qualification_or_release_authority=False)


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True)
    a=p.parse_args()
    require(a.output.resolve().is_relative_to(a.evidence_root.resolve()) and not a.output.exists(),"Fresh durable dense output")
    result=run(a.evidence_root,a.core,a.baseline_core)
    with a.output.open("x",encoding="utf-8",newline="\n") as stream:json.dump(result,stream,indent=2,allow_nan=False);stream.write("\n")
    print(json.dumps(dict(ok=True,worlds_opened=0,cases=result["case_count"],model_sha256=result["model_sha256"],
        first_response_supported_groups=sum(bool(g["supported_action_indices"]) for g in result["first_response_support"]),denominator=8)))
