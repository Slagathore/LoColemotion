"""Episode-balanced ridge warning fit on complete retained training data."""
import argparse
import collections
import json
from pathlib import Path
import numpy as np

import residual_warning_data as data
import residual_warning_metrics as metrics
from adaptation_provider.warning import residual_v1 as warning
from gpu_measurement_probe import write_new

ROOT,HERE=data.ROOT,data.HERE
read,sha,require=data.read,data.sha,data.require
CONTRACT=HERE/"residual_warning_v1.json"
SOURCES=("residual_warning_data.py","residual_warning_metrics.py","residual_warning_fit.py",
    "test_residual_warning.py","audit_residual_warning.py","run_residual_warning.py")
RIDGE=.001
SCOPE=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
    authority_mode="retrospective_shadow_warning_development",question_class="development")


def expected_recipe():
    return dict(schema_version="locolemotion_residual_warning_recipe_v1",ledger_scope=SCOPE,
        definition_sha256=sha(warning.CONTRACT),source_closure_sha256=data.selection.PARENT_SHA,
        pilot_attempt_id=data.selection.PILOT,pilot_receipt_sha256=data.selection.PILOT_RECEIPT_SHA,
        source_bindings={name:sha(HERE/name) for name in SOURCES},
        training_trial_count=64,eligible_episodes=15,failed_episodes=49,
        complete_controller_rows=92160,complete_internal_rows=460800,
        starts=list(data.STARTS),conditions=["left_075","nominal"],
        row_priority=list(data.CATEGORIES),first_failure="original physical predicate or safe-no-actuation",
        positive="5*step < first_failure_internal_step <= 5*(step+30)",
        already_failed="first_failure_internal_step <= 5*step",
        unsupported="feature unavailable; retain reason; never invent vector or fit row",
        right_censored="no observed failure within next30 and step+30 > 1440",
        negative="supported, not already failed, full next30 observed and no failure",
        feature_input="fixed mechanically scaled current feature plus seven causal derived values",
        fit=dict(objective="sum(weight*(intercept+x@beta-label)^2)+lambda*sum(beta^2)",
            ridge=RIDGE,intercept_penalized=False,
            weights="1/episode_fit_rows, then normalize each class to mass 0.5",
            algorithm="float64 normal equations; solve; infinity residual <= 1e-10",
            threads=1,versions=dict(numpy=np.__version__)),
        crossfit=dict(folds=4,unit="same start across both body conditions and all eight policies",
            held_out_start_ids=list(data.STARTS),fold_training_episodes=48,fold_diagnostic_episodes=16,
            row_random_split=False,exposed_training_data_only=True),
        threshold="minimum, over failed episodes having supported positive rows, of their maximum crossfit score in that window",
        threshold_data="same crossfit rows; alarm metrics at selected threshold are tuning diagnostics",
        unsupported_warning=True,hysteresis_exit_offset=.05,reentry_commands=30,
        final_model="refit same recipe on all training rows; report full-fit alarms separately",
        comparison_trials_used=0,route_trials_used=0,reserved_starts_opened=0,
        excluded_confirmation_trials_used=0,physical_launch_authority=False,
        automatic_withdrawal_authority=False,calibrated_probability=False,
        probabilistic_risk_guarantee=False,safe_backup_established=False,
        tier2_complete=False,tier3_complete=False,release_authority=False)


def recipe():
    value=read(CONTRACT);require(value==expected_recipe(),"Warning recipe/source/runtime bindings")
    return value


def regression(vectors,targets,identities):
    require(len(vectors)==len(targets)==len(identities)>0 and set(targets)=={0,1}
        and all(type(v) is int for v in targets)
        and all(isinstance(k,str) and k for k in identities),"Warning regression population/classes")
    count=collections.Counter(identities)
    base=np.array([1./count[k] for k in identities],dtype=np.float64)
    y=np.asarray(targets,dtype=np.float64);x=np.asarray(vectors,dtype=np.float64)
    require(x.ndim==2 and x.shape[0]==len(y) and np.isfinite(x).all(),"Warning finite design matrix")
    weights=base.copy()
    for value in (0,1):
        mask=y==value;weights[mask]*=.5/base[mask].sum()
    design=np.column_stack((np.ones(len(y)),x))
    penalty=np.eye(design.shape[1],dtype=np.float64)*RIDGE;penalty[0,0]=0.
    normal=design.T@(weights[:,None]*design)+penalty
    rhs=design.T@(weights*y)
    beta=np.linalg.solve(normal,rhs)
    residual=float(np.max(np.abs(normal@beta-rhs)))
    require(np.isfinite(beta).all() and residual<=1e-10,"Warning numerical solution residual")
    return beta.tolist(),dict(fit_rows=len(y),fit_episodes=len(count),positive_rows=int(y.sum()),
        negative_rows=int(len(y)-y.sum()),normal_equation_infinity_residual=residual,
        weighted_squared_loss=float(np.sum(weights*(design@beta-y)**2)),
        ridge_penalty=float(RIDGE*np.sum(beta[1:]**2)),
        class_weight_mass=[float(weights[y==v].sum()) for v in (0,1)])


def model_document(weights,threshold,data_sha,held_out=None):
    return dict(schema_version="locolemotion_residual_warning_model_v1",definition=warning.definition(),
        weights=weights,entry_threshold=threshold,exit_threshold=threshold-warning.HYSTERESIS,
        training=dict(kind="retrospective_grouped_training_fold" if held_out else "retrospective_complete_training_population",data_sha256=data_sha,
            recipe_sha256="sha256:"+sha(CONTRACT),training_trial_count=48 if held_out else 64,held_out_start_id=held_out,
            comparison_trials_used=0,reserved_starts_opened=0))


def fit_population(rows,manifest):
    recipe()
    blocks=data.split_episodes(rows,manifest["episodes"])
    require(len(blocks)==64 and data.dataset_digest(rows)==manifest["dataset_sha256"],
        "Warning fit complete training identity")
    by_id={e["trial_id"]:e for e,_ in blocks}
    fitted={}
    for omitted in (*data.STARTS,None):
        fitrows=[r for r in rows if r["category"] in ("positive","negative")
            and (omitted is None or by_id[r["trial_id"]]["start_id"]!=omitted)]
        weights,info=regression([r["x"] for r in fitrows],
            [int(r["category"]=="positive") for r in fitrows],[r["trial_id"] for r in fitrows])
        train_ids=sorted({r["trial_id"] for r in fitrows})
        require(len(train_ids)==(64 if omitted is None else 48),"Warning grouped fit denominator")
        fitted[omitted]=dict(weights=weights,diagnostics=info,training_trial_ids=train_ids)
    oof=[warning.score(fitted[by_id[r["trial_id"]]["start_id"]]["weights"],r["x"])
        if r["x"] is not None else None for r in rows]
    threshold,limits,without=metrics.threshold_limits(rows,manifest["episodes"],oof)
    models={k:warning.FrozenWarning.load(model_document(fitted[k]["weights"],threshold,manifest["dataset_sha256"],k))
        for k in fitted}
    fold_predictions,fold_metrics=metrics.evaluate(rows,manifest["episodes"],{k:models[k] for k in data.STARTS})
    full_predictions,full_metrics=metrics.evaluate(rows,manifest["episodes"],{k:models[None] for k in data.STARTS})
    summary=dict(schema_version="locolemotion_residual_warning_fit_v1",ledger_scope=SCOPE,
        recipe_sha256=sha(CONTRACT),dataset_sha256=manifest["dataset_sha256"],training_trial_count=64,
        row_categories=manifest["row_categories"],threshold=threshold,
        threshold_limits=limits,failed_episodes_without_supported_threshold_opportunity=without,
        folds=[dict(held_out_start_id=k,model_sha256=models[k].sha256,**fitted[k]) for k in data.STARTS],
        full_fit=dict(model_sha256=models[None].sha256,**fitted[None]),
        crossfit_tuned_threshold_diagnostics=fold_metrics,full_fit_diagnostics=full_metrics,
        interpretation="shadow scores only; threshold tuned on crossfit data; no independent alarm validation",
        automatic_withdrawal_authority=False,physical_acceptance_authority=False,
        comparison_trials_used=0,route_trials_used=0,reserved_starts_opened=0,
        calibrated_probability=False,probabilistic_risk_guarantee=False,safe_backup_established=False,
        tier2_complete=False,tier3_complete=False,release_authority=False)
    return models,summary,fold_predictions,full_predictions


def write_lines(path,rows):
    with Path(path).open("x",encoding="utf-8",newline="\n") as stream:
        for row in rows:stream.write(warning.encode_json(row)+"\n")


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("--output",type=Path,required=True)
    args=parser.parse_args();folder=args.output
    require(folder.is_dir() and not any(folder.iterdir()),"Warning fresh fit directory")
    recipe()
    rows,manifest=data.extract(progress=lambda v:print(json.dumps(v),flush=True))
    write_lines(folder/"data.jsonl",rows);write_new(folder/"data-manifest.json",manifest)
    require("sha256:"+sha(folder/"data.jsonl")==manifest["dataset_sha256"],"Warning retained data bytes")
    models,summary,oof,full=fit_population(rows,manifest)
    for key,model in models.items():
        write_new(folder/("model-"+(key or "full")+".json"),model.document())
    write_lines(folder/"crossfit-predictions.jsonl",oof);write_lines(folder/"full-fit-predictions.jsonl",full)
    write_new(folder/"fit.json",summary)
    print(json.dumps(dict(ok=True,training_trials=64,worlds_opened=0,
        crossfit=summary["crossfit_tuned_threshold_diagnostics"]["failures_warned_in_target_window"],
        full_fit=summary["full_fit_diagnostics"]["failures_warned_in_target_window"],
        selected_warning_episodes=summary["full_fit_diagnostics"]["selected_episodes_with_any_warning"])),flush=True)
    return 0


if __name__=="__main__":raise SystemExit(main())
