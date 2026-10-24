"""Rebuild the dense fit and independently check every overlapping case."""
import argparse
from itertools import islice
import json
import re
from pathlib import Path

import command_resolution_repertoire as fit

ROOT,HERE,sha,read,require = fit.ROOT,fit.HERE,fit.sha,fit.read,fit.require
RECORD=HERE/"command_resolution_repertoire_closure_v1.json"
TESTED=["sdk/adaptation_provider/retrieval/feedback_dense_v1.py",
    "sdk/adaptation_provider/retrieval/feedback_dense_contract_v1.json",
    "sdk/discovery/command_resolution_repertoire.py","sdk/discovery/command_resolution_repertoire_v1.json",
    "sdk/discovery/test_command_resolution_repertoire.py"]


def independent_cases(result,evidence_root):
    parent=read(fit.PARENT)["result"]
    original={e["episode_id"]:e for e in parent["corpus"]["episodes"]}
    cases={e["episode_id"]:[] for e in result["model"]["ordered_episode_ledger"]}
    for case in result["model"]["ordered_cases"]:cases[case["episode_id"]].append(case)
    plan=fit.learner.contract();actions=[a["action_id"] for a in plan["actions"]]
    verified=0
    for source in result["source_bindings"]:
        old=original[source["original_episode_id"]];values=cases[source["derived_episode_id"]]
        if old["outcome"] != "positive":
            require(values == [],"Independent failed case exclusion")
            continue
        path=evidence_root/parent["parent_attempt_id"] /"physical"/source["trial_id"]/"controller.jsonl"
        require(sha(path) == source["controller_sha256"],"Independent dense stream binding")
        rows=list(fit.read_jsonl(path));positions=[r["request"]["state"]["base_pose_world"]["position_m"] for r in rows]
        terminal=old["windows"][-1]["end_position_xz_m"]
        require(len(values) == 1411 and [c["case_id"] for c in values]
            == [source["derived_episode_id"]+"_"+str(i) for i in range(1411)],"Independent dense case population")
        for step,case in enumerate(values):
            request=rows[step]["resolution_request"]["provider_request"];state=request["state"]
            q=state["base_pose_world"]["orientation_xyzw"];x,y,z,w=[q[k] for k in "xyzw"]
            v=state["base_twist_world"]["linear_velocity_m_s"]
            memory={r["limb_id"]:r["gait_step"] for r in request["controller_context"]["controller_memory"]["ordered_limb_memory"]}
            cue=dict(vector=[positions[step]["y"],2*(x*y-z*w),2*(y*z+x*w),v["x"],v["z"],state["base_twist_world"]["angular_velocity_rad_s"]["y"]],
                phase=[memory[leg]%360//30 for leg in plan["ordered_limb_ids"]],
                contact_mask=sum(2**i for i,c in enumerate(state["ordered_contact_observations"]) if c["bears_support"]))
            end=terminal if step+30 == 1440 else [positions[step+30]["x"],positions[step+30]["z"]]
            quality=-abs((end[0]-positions[step]["x"])/.25-.2)-.25*abs((end[1]-positions[step]["z"])/.25)
            require(case["cue"] == cue and case["quality_m_s"] == quality
                and case["action_index"] == actions.index(old["action_id"]),"Independent dense cue/outcome/action join")
            verified += 1
    require(verified == result["case_count"] == 21165,"Independent total case denominator")
    return verified


def verify_record(path,evidence_root,core,baseline):
    record=read(path)
    require(record["schema_version"] == "locolemotion_command_resolution_repertoire_closure_v1"
        and record["status"] == "complete_command_resolution_feedback_fit"
        and record["ledger_scope"] == fit.declaration()["ledger_scope"]
        and record["parent_fit_sha256"] == fit.PARENT_SHA and record["reader_sha256"] == sha(Path(__file__))
        and record["worlds_opened"] == 0 and record["source_trials"] == 32 and record["fitted_episodes"] == 24
        and record["cases"] == 21165 and record["overlapping_cases_are_independent_trials"] is False
        and record["context_estimator_refitted"] is False and record["runtime_selection_implemented"] is False
        and record["adaptation_benefit"] is False and record["qualification_or_release_authority"] is False,"Dense closure scope/identity")
    root=evidence_root.resolve(strict=True);attempt=(root/record["attempt_id"]).resolve(strict=True)
    require(attempt.parent == root,"Dense closure attempt path")
    paths=[]
    for item in record["artifacts"]:
        target=(root/item["evidence_relative_path"]).resolve(strict=True)
        require(target.is_relative_to(attempt) and target.is_file() and target.stat().st_size == item["byte_length"]
            and sha(target) == item["sha256"],"Dense closure retained artifact changed")
        paths.append(target)
    require(len(paths) == len(set(paths)) == record["artifact_count"]
        and set(paths) == {p.resolve() for p in attempt.rglob("*") if p.is_file()},"Dense closure artifact inventory")
    require(set(record["tested_sources"]) == set(TESTED),"Dense closure tested source inventory")
    for name,digest in record["tested_sources"].items():
        require(sha(ROOT/name) == digest and sha(attempt/"tested-source"/name) == digest,"Dense closure tested source changed")
    log=(attempt/"tests/stderr.log").read_text()
    require(re.findall(r"(?m)^Ran ([0-9]+) tests? in ",log) == ["7"] and log.rstrip().endswith("OK"),"Dense closure controls incomplete")
    receipt,declared=read(attempt/"receipt.json"),read(attempt/"declaration.json")
    require(receipt["ok"] is True and receipt["worlds_opened"] == declared["worlds_opened"] == 0
        and receipt["source_commit"] == declared["source_commit"] == record["source_commit"]
        and receipt["binding"] == declared["binding"] and declared["expected_tests"] == 7
        and receipt["tested_sources"] == declared["tested_sources"] == record["tested_sources"]
        and declared["contract"] == fit.declaration(),"Dense closure execution binding")
    result=read(attempt/"tested-command-resolution-analysis.json")
    require(result == record["result"] and sha(attempt/"tested-command-resolution-analysis.json") == receipt["analysis_sha256"],"Dense closure retained result changed")
    verified=independent_cases(result,evidence_root)
    require(fit.run(evidence_root,core,baseline) == result,"Dense closure rebuilt fit differs")
    require(result["model_sha256"] == receipt["model_sha256"],"Dense closure model digest")
    return dict(ok=True,worlds_opened=0,source_trials=32,fitted_episodes=24,eligible_episodes=15,negative_episodes=9,
        cases=verified,model_sha256=result["model_sha256"],artifact_count=len(paths),
        first_response_supported_groups=sum(bool(g["supported_action_indices"]) for g in result["first_response_support"]),
        query_denominator=8,overlapping_cases_are_independent_trials=False,runtime_selection_implemented=False,
        adaptation_benefit=False,qualification_or_release_authority=False)


if __name__ == "__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--record",type=Path,default=RECORD)
    p.add_argument("--evidence-root",type=Path,default=ROOT.parent/"SporeSpore_Evidence")
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    a=p.parse_args();print(json.dumps(verify_record(a.record,a.evidence_root,a.core,a.baseline_core),indent=2))
