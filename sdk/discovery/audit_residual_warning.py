"""Independent retained-data reader and alternate numerical solver; zero worlds."""
import argparse
import copy
import json
from pathlib import Path
import numpy as np

import residual_warning_fit as fit
import residual_warning_data as data
from adaptation_provider.warning import residual_v1 as warning
from gpu_measurement_probe import write_new

require,read,sha=fit.require,fit.read,fit.sha


def verify_model(value,expected):
    actual=warning.FrozenWarning.load(value)
    require(actual.sha256==expected.sha256,"Warning retained model/threshold/provenance")
    return actual


def alternate_solution(rows,episodes,summary):
    """Use weighted augmented least squares, independently of normal equations."""
    starts={e["trial_id"]:e["start_id"] for e in episodes}
    results=[]
    for held_out in (*data.STARTS,None):
        active=[r for r in rows if r["category"] in ("positive","negative")
            and (held_out is None or starts[r["trial_id"]]!=held_out)]
        counts={}
        for r in active:counts[r["trial_id"]]=counts.get(r["trial_id"],0)+1
        x=np.array([[1.,*r["x"]] for r in active],dtype=np.float64)
        y=np.array([float(r["category"]=="positive") for r in active])
        weights=np.array([1./counts[r["trial_id"]] for r in active])
        for label in (0,1):
            index=y==label;weights[index]/=2.*weights[index].sum()
        root=np.sqrt(weights)
        penalty=np.eye(x.shape[1])*np.sqrt(fit.RIDGE);penalty[0,0]=0.
        result=np.linalg.lstsq(np.vstack((root[:,None]*x,penalty)),
            np.concatenate((root*y,np.zeros(x.shape[1]))),rcond=None)[0]
        record=summary["full_fit"] if held_out is None else next(
            r for r in summary["folds"] if r["held_out_start_id"]==held_out)
        difference=float(np.max(np.abs(result-np.array(record["weights"]))))
        require(difference<=1e-9 and record["training_trial_ids"]==sorted(counts)
            and len(counts)==(64 if held_out is None else 48)
            and all(starts[k]!=held_out for k in counts),"Warning independent grouped numerical fit")
        results.append(dict(held_out_start_id=held_out,fit_episodes=len(counts),fit_rows=len(active),
            maximum_weight_difference=difference))
    return results


def negative_controls(manifest,summary,models,predictions):
    controls=[]
    def rejects(name,call):
        try:call()
        except (ValueError,TypeError,KeyError):
            controls.append(name);return
        raise ValueError("Warning corruption accepted: "+name)
    changed=copy.deepcopy(manifest);changed["training_trial_count"]-=1
    rejects("missing_training_episode",lambda:require(changed==manifest,"Warning complete source manifest"))
    changed=copy.deepcopy(manifest);changed["training_bindings"][next(iter(changed["training_bindings"]))]="0"*64
    rejects("altered_original_raw_binding",lambda:require(changed==manifest,"Warning original source bindings"))
    changed=copy.deepcopy(summary);changed["physical_acceptance_authority"]=True
    rejects("promoted_physical_authority",lambda:require(changed==summary,"Warning fit authority"))
    changed=copy.deepcopy(summary);changed["folds"][0]["training_trial_ids"][0]="excluded_confirmation"
    rejects("crossed_partition_or_fold",lambda:require(changed==summary,"Warning grouped fitting population"))
    changed=models[None].document();changed["weights"][0]+=.01
    rejects("changed_weights",lambda:verify_model(changed,models[None]))
    changed=models[None].document();changed["entry_threshold"]+=.01;changed["exit_threshold"]=changed["entry_threshold"]-.05
    rejects("changed_threshold",lambda:verify_model(changed,models[None]))
    changed=models[data.STARTS[0]].document();changed["training"]["training_trial_count"]=64
    rejects("fold_claims_full_training",lambda:verify_model(changed,models[data.STARTS[0]]))
    changed=dict(predictions[0]);changed["withdraw_requested"]=not changed["withdraw_requested"]
    rejects("changed_shadow_decision",lambda:require(changed==predictions[0],"Warning causal prediction reconstruction"))
    require(len(controls)==8,"Warning reader corruption denominator")
    return controls


def audit(folder):
    fit.recipe()
    require(folder.is_dir(),"Warning fit evidence directory")
    expected_names={"data.jsonl","data-manifest.json","fit.json","crossfit-predictions.jsonl",
        "full-fit-predictions.jsonl","model-full.json",*("model-"+k+".json" for k in data.STARTS)}
    require({p.name for p in folder.iterdir()}==expected_names,"Warning complete retained fit artifacts")
    rows,manifest=data.extract(progress=lambda v:print(json.dumps(v),flush=True))
    require(read(folder/"data-manifest.json")==manifest
        and "sha256:"+sha(folder/"data.jsonl")==manifest["dataset_sha256"],
        "Warning reopened raw-derived data identity")
    # Parse stored rows as well: a checksum without a valid decoder is not enough.
    stored=list(data.lines(folder/"data.jsonl"))
    require(stored==rows,"Warning complete stored rows")
    models,summary,oof,full=fit.fit_population(rows,manifest)
    require(read(folder/"fit.json")==summary,"Warning full fit/threshold/diagnostic reconstruction")
    for key,model in models.items():verify_model(read(folder/("model-"+(key or "full")+".json")),model)
    for filename,predictions in (("crossfit-predictions.jsonl",oof),("full-fit-predictions.jsonl",full)):
        require(data.dataset_digest(predictions)=="sha256:"+sha(folder/filename),
            "Warning complete shadow prediction bytes")
    alternate=alternate_solution(rows,manifest["episodes"],summary)
    controls=negative_controls(manifest,summary,models,full)
    return dict(schema_version="locolemotion_residual_warning_audit_v1",ledger_scope=fit.SCOPE,ok=True,
        reader_world_build_count=0,reader_solver_steps=0,training_episodes_reopened=64,
        controller_rows_reopened=92160,internal_rows_reopened=460800,
        dataset_sha256=manifest["dataset_sha256"],fit_sha256=sha(folder/"fit.json"),
        final_model_sha256=models[None].sha256,alternate_solver=alternate,
        corruption_controls_passed=controls,
        artifacts={p.name:sha(p) for p in sorted(folder.iterdir())},
        source_reconstruction="all training controller, trace and timing hashes; first violations; causal features; row labels",
        controller_replay_repeated=False,comparison_trials_used=0,reserved_starts_opened=0,
        physical_acceptance_authority=False,tier2_complete=False,tier3_complete=False,release_authority=False)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--folder",type=Path,required=True);parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args();result=audit(args.folder);write_new(args.output,result)
    print(json.dumps(dict(ok=True,training_episodes_reopened=64,reader_world_build_count=0,
        corruption_controls_passed=len(result["corruption_controls_passed"]))),flush=True)


if __name__=="__main__":main()
