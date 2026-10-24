"""Fresh fixed-artifact comparison after an explicitly retrospective training selection."""
import copy
from pathlib import Path

import residual_training_task as base
import residual_selection as selection
from residual_training_task import (ROOT,HERE,FLAGS,sha,require,provider,bridge,read,
    initial_arrays,controller_contract,zero_policy,untrained_model)
from gpu_measurement_probe import write_new

CONTRACT=HERE/"residual_selection_v1.json"
SOURCES=("residual_selection.py","residual_selection_task.py","residual_selection_native.py",
    "audit_residual_selection.py","run_residual_selection.py","test_residual_selection.py")
GATES=(*base.GATES,("residual-selection","test_residual_selection",26),
    ("training-closure","test_residual_training_closure",8))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3


def expected_declaration():
    old=base.expected_declaration()
    fields=("core_sha256","baseline_core_sha256","runtime","provider_definition","model_xml_sha256",
        "descriptor_sha256","policy_id","stability_policy_id","phase_mode","internal_steps_per_outer",
        "timestep_s","controller_dt_s","warmup_outer_steps","initial_values","cpu_warning_count",
        "naconmax","naconmax_per_world","njmax","selection","source_host","conditions","condition_model_sha256",
        "training_starts","reserved_starts","excluded_confirmation_starts","reward","official_quality",
        "nominal_quality_loss_margin_m_s","maximum_trace_bytes_per_trial")
    return dict({k:copy.deepcopy(old[k]) for k in fields},
        schema_version="locolemotion_residual_selection_comparison_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="frozen_selected_artifact_development_comparison",question_class="development"),
        lane="comparison",seed=104240601,outer_steps=1440,horizon_s=12.,
        groups=old["lanes"]["pilot"]["groups"],comparison_roles=["baseline","disabled","selected"],
        planned_cpu_worlds=24,planned_gpu_worlds=0,calibration_worlds=0,evaluation_worlds=0,
        training_data_scope="none_frozen_development_comparison",official_quality_enabled=True,
        selection_record_path=selection.FIT.relative_to(ROOT).as_posix(),selection_record_sha256=sha(selection.FIT),
        selected_model_path=selection.MODEL.relative_to(ROOT).as_posix(),selected_model_sha256="sha256:"+sha(selection.MODEL),
        predecessor_closure_sha256=selection.PARENT_SHA,selection_is_retrospective=True,
        preserve_weights_and_normalizer=True,comparison_data_may_fit=False,
        finite_screen="All eight selected episodes eligible; no nominal quality loss against fresh baseline at any start; disabled raw traces exactly equal baseline. Development screen only.",
        minimum_free_storage_bytes=20*2**30,maximum_worker_wall_seconds=3600,maximum_reader_wall_seconds=3600,
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        provider_controls=2,containment_controls=1,complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        coverage=["complete eight-candidate/64-trial training-only selection with explicit retrospective status",
            "exact selected artifact transfer into the unchanged native run_trial production loop",
            "fresh baseline/disabled/selected roles, full 12-second native state/force capture",
            "independent baseline-core decision replay and complete fixed-denominator comparison"],
        not_covered=["unopened calibration/evaluation starts","calibrated confidence or withdrawal",
            "Tier 3 memory benefit","other morphologies or engines","multi-seed robustness","qualification or release"],
        controller_selection_authority=False,adaptation_benefit_established=False,tier3_benefit_established=False,
        **{k:False for k in FLAGS})


def declaration(lane="comparison"):
    value=read(CONTRACT)
    require(lane=="comparison" and value==expected_declaration(),"Residual selection declaration/source bindings")
    return value


def stages(c):
    require(c["lane"]=="comparison","Residual selection stage scope")
    return ["comparison"]


def trial_plans(c,stage="comparison"):
    require(stage=="comparison" and c["lane"]=="comparison","Residual selection comparison stage")
    plans=[]
    for group in c["groups"]:
        condition,start=group.split("_train_");start="train_"+start
        require(condition in ("left_075","nominal") and start in dict(base.STARTS),"Residual selected group boundary")
        for role in c["comparison_roles"]:
            require(role in ("baseline","disabled","selected"),"Residual selected comparison role")
            plans.append(dict(trial_id="comparison_"+role+"_"+group,stage=stage,group_id=group,
                condition_id=condition,start_id=start,role=role,direction=None,sign=None,
                model_key="baseline" if role=="baseline" else "selected",partition="development_comparison",
                mode="absent" if role=="baseline" else ("disabled" if role=="disabled" else "frozen"),
                seed=c["seed"],nworld=1,arm="scalar_direct",training_data_authority=False,
                initial_native_lateral_velocity_m_s=dict(base.STARTS)[start]))
    return plans


def all_plans(c):
    plans=trial_plans(c)
    require(len(plans)==c["planned_cpu_worlds"]==24 and len({p["trial_id"] for p in plans})==24,
        "Residual selection complete fresh population")
    return plans


def stage_claim(folder,c,core):
    require(folder.name=="comparison","Residual selection fixed stage")
    fit,model=selection.verify_fit(core);attempt=folder.parent.parent
    baseline=provider.FrozenModel.load(core,untrained_model(zero_policy(),"selected_baseline"))
    models=dict(baseline=baseline,selected=model)
    claim=dict(schema_version="locolemotion_residual_selection_stage_v1",stage="comparison",lane=c["lane"],
        source_commit=read(attempt/"declaration.json")["source_commit"],contract_sha256=sha(CONTRACT),
        declaration_sha256=sha(attempt/"declaration.json"),gate_receipt_sha256=sha(attempt/"gate-receipt.json"),
        consumed_sha256=sha(attempt/"consumed.json"),selection_record_sha256=sha(selection.FIT),
        selected_candidate_id=fit["decision"]["selected_candidate_id"],
        models={k:v.sha256 for k,v in models.items()},trials=all_plans(c),
        planned_cpu_worlds=24,planned_gpu_worlds=0,training_data_scope=c["training_data_scope"])
    return claim,None,models


def prepare_stage(folder,c,core):
    folder.mkdir();claim,_,models=stage_claim(folder,c,core);(folder/"models").mkdir()
    for key,model in models.items():
        with (folder/"models"/(key+".json")).open("x",encoding="utf-8",newline="\n") as stream:
            stream.write(model.serialized)
    write_new(folder/"stage.json",claim)
    return load_stage(folder,c,core)


def load_stage(folder,c,core):
    expected,_,models=stage_claim(folder,c,core)
    require(read(folder/"stage.json")==expected,"Residual selected stage claim")
    require(not (folder/"batch.json").exists() and not (folder/"update.json").exists(),"Residual comparison cannot fit")
    for key,model in models.items():
        path=folder/"models"/(key+".json")
        require("sha256:"+sha(path)==model.sha256 and read(path)==model.document(),"Residual selected staged model")
    return expected,None,models


def score(controls,trace,c,*,training):
    require(training is False,"Residual comparison cannot fit")
    return base.score(controls,trace,c,training=False)


def assess_comparison(trials,c):
    plans=all_plans(c)
    require(len(trials)==len(plans) and all(all(r.get(k)==v for k,v in p.items())
        for r,p in zip(trials,plans,strict=True)),"Residual selected comparison population")
    require(all(r["observations"] is None and r["comparison_data_used_for_training"] is False for r in trials),
        "Residual comparison cannot fit")
    result=dict(fixed_selected_artifact=True,groups=[],finite_development_screen_passed=False,
        tier2_qualified=False,tier3_benefit_established=False,release_authority=False)
    for group in c["groups"]:
        roles={r["role"]:r for r in trials if r["group_id"]==group}
        baseline,disabled,selected=[roles[r] for r in ("baseline","disabled","selected")]
        require(baseline["raw_hashes"]["trace"]==disabled["raw_hashes"]["trace"],
            "Residual disabled changed baseline trace")
        require(baseline["official_quality_m_s"]==disabled["official_quality_m_s"]
            and baseline["diagnostic_eligible"]==disabled["diagnostic_eligible"]
            and baseline["nonzero_correction_commands"]==disabled["nonzero_correction_commands"]==0,
            "Residual disabled baseline outcome")
        q,bq=selected["official_quality_m_s"],baseline["official_quality_m_s"]
        require(all((r["official_quality_m_s"] is not None) is r["diagnostic_eligible"] for r in roles.values()),
            "Residual selected failed quality")
        result["groups"].append(dict(group_id=group,selected_eligible=selected["diagnostic_eligible"],
            selected_quality_m_s=q,baseline_eligible=baseline["diagnostic_eligible"],baseline_quality_m_s=bq,
            disabled_trace_identical=True,quality_change_m_s=q-bq if q is not None and bq is not None else None,
            nominal_preserved=(q is not None and bq is not None and q>=bq) if group.startswith("nominal_") else None))
    result["finite_development_screen_passed"]=all(g["selected_eligible"] for g in result["groups"]) and all(
        g["nominal_preserved"] is True for g in result["groups"] if g["group_id"].startswith("nominal_"))
    return result


def validate_launch_records(folder,c,source):
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    folder=folder.resolve(strict=True);attempt=folder.parent.parent.parent
    require(folder.name=="physical" and folder.parent.name=="comparison" and folder.parent.parent.name=="stages"
        and attempt.parent==evidence and attempt.name.startswith("sdk2-residual-selection-"),
        "Residual selection durable output boundary")
    owner=read(attempt/"declaration.json");gate=read(attempt/"gate-receipt.json")
    counts={n:k for n,_,k in GATES};counts.update(provider=2,containment=1)
    require(owner["contract"]==c and owner["source_commit"]==source and owner["synthetic"] is False,
        "Residual selection owner freeze")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["safety_controls"]==counts
        and sum(counts.values())==c["complete_safety_control_count"]
        and gate["declaration_sha256"]==sha(attempt/"declaration.json")
        and gate["preflight"]["ok"] is True and gate["preflight"]["world_build_count"]==0
        and gate["preflight"]["solver_steps"]==0,"Residual selection complete zero-world gate")
    require(read(attempt/"consumed.json")==dict(attempt_id=attempt.name,source_commit=source,lane=c["lane"],
        contract_sha256=sha(CONTRACT),declaration_sha256=sha(attempt/"declaration.json"),
        gate_receipt_sha256=sha(attempt/"gate-receipt.json"),trials=all_plans(c)),"Residual selection consumed claim")
    return owner
