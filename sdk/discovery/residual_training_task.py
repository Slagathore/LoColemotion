"""Prospective native ARS populations, lossless checkpoints and censored scoring.

The execution fixture and pilot are separate lanes. The pilot always starts
with zero weights and identity normalization, never with fixture observations.
"""
import copy
import json
import math
from pathlib import Path

from adaptation_provider.retrieval import learner
from body_height_diagnostic import physical_violation
from gpu_measurement_probe import write_new
from residual_native_task import (ROOT,HERE,FLAGS,sha,require,provider,bridge,
    initial_arrays,controller_contract,expected_declaration as native_definition,
    GATES as NATIVE_GATES)

ars=provider.ars
CONTRACT=HERE/"residual_training_v1.json"
SOURCES=("residual_training_task.py","residual_training.py","audit_residual_training.py",
         "run_residual_training.py","test_residual_training.py")
GATES=(*NATIVE_GATES[:-1],("residual-training","test_residual_training",26),
       ("native-closure","test_residual_native_closure",6))
EXPECTED_CONTROLS=sum(count for _,_,count in GATES)+3
STARTS=(("train_001",.001),("train_003",.003),("train_004",.004),("train_006",.006))


def read(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def document(value):
    return json.loads(json.dumps(value,allow_nan=False))


def expected_declaration():
    base=native_definition()
    common={k:copy.deepcopy(base[k]) for k in ("core_sha256","baseline_core_sha256","runtime",
        "provider_definition","model_xml_sha256","descriptor_sha256","policy_id","stability_policy_id",
        "phase_mode","internal_steps_per_outer","timestep_s","controller_dt_s","warmup_outer_steps",
        "initial_values","cpu_warning_count","naconmax","naconmax_per_world","njmax","selection","source_host")}
    return dict(common,schema_version="locolemotion_residual_native_training_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="bounded_development_training",question_class="development"),
        conditions=[dict(condition_id="left_075",side="left",effectiveness=.75),
                    dict(condition_id="nominal",side="none",effectiveness=1.)],
        condition_model_sha256=dict(left_075="f9de96b1954cdc76864cdddc90a43a18a828aee326d3916d00891b8c7c034069",
            nominal=base["condition_model_sha256"]["nominal"]),
        training_starts=[dict(id=k,lateral_velocity_m_s=v) for k,v in STARTS],
        reserved_starts=[.0015,.0045,.0025,.0055],excluded_confirmation_starts=[.002,.005],
        lanes=dict(route=dict(seed=104240401,outer_steps=120,horizon_s=1.,iterations=1,directions=1,
                groups=["left_075_train_001"],comparison_roles=["trained"],planned_cpu_worlds=3,
                training_data_scope="development_execution_fixture_only",official_quality_enabled=False),
            pilot=dict(seed=104240501,outer_steps=1440,horizon_s=12.,iterations=2,directions=2,
                groups=[condition+"_"+start for condition in ("left_075","nominal") for start,_ in STARTS],
                comparison_roles=["baseline","disabled","trained"],planned_cpu_worlds=88,
                training_data_scope="bounded_eight_group_development_training",official_quality_enabled=True)),
        optimizer=dict(noise_scale=.02,step_size=.01,variance_floor=1e-8,output_limit_rad_s=3.5,
            selected_directions="all",initial_weights="zeros",initial_normalizer="identity_count_zero",
            perturbations="stored_lossless_antithetic_gaussian",seed_rule="lane_seed_plus_iteration",
            normalizer_population="every available mechanically supported feature row from every complete training rollout",
            missing_features="retain unsupported reasons and counts; never invent observations",
            comparison_data_may_fit=False,route_data_may_initialize_pilot=False,
            final_checkpoint="fixed final iteration; no comparison-based checkpoint selection"),
        reward=dict(desired_forward_velocity_m_s=.2,lateral_error_weight=.25,error_scale_m_s=.4,
            per_step="-min(1,(abs(native_vx-.2)+.25*abs(native_vy))/.4)",
            failure_value=-1.,failure_rule="first physical violation or safe-no-actuation command and every remaining internal sample",
            denominator="complete fixed internal horizon",survival_bonus=0.,range=[-1.,0.],
            invalid_rollout="reject complete update; retain attempt and remaining unopened population"),
        official_quality=dict(contract_path=learner.CONTRACT.relative_to(ROOT).as_posix(),
            contract_sha256=sha(learner.CONTRACT),window_commands=30,desired_forward_velocity_m_s=.2,
            lateral_error_weight=.25,failed_episode_quality=None,route_quality=None),
        finite_screen="All eight trained episodes eligible; no nominal quality loss against fresh baseline at any start; disabled raw traces exactly equal baseline. Development screen only.",
        nominal_quality_loss_margin_m_s=0.,planned_gpu_worlds=0,calibration_worlds=0,evaluation_worlds=0,
        maximum_trace_bytes_per_trial=256*2**20,minimum_free_storage_bytes=80*2**30,
        maximum_worker_wall_seconds=3600,maximum_reader_wall_seconds=3600,
        safety_controls=[dict(name=n,module=m,count=c) for n,m,c in GATES],
        provider_controls=2,containment_controls=1,complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={name:sha(HERE/name) for name in SOURCES},
        coverage=["fresh contained CPU worlds, full native state and force capture, independent baseline-core replay",
            "complete paired search populations and fixed horizons, including ordinary negative outcomes",
            "raw-derived reward and feature moments, verified immutable update before next-stage use",
            "fresh final baseline/disabled/trained comparison at every declared pilot group"],
        not_covered=["reserved calibration or evaluation","calibrated recovery confidence","Tier 3 memory benefit",
            "other morphologies, terrain or engines","multi-seed robustness","qualification or release"],
        controller_selection_authority=False,adaptation_benefit_established=False,tier3_benefit_established=False,
        **{k:k=="training_data_authority" for k in FLAGS})


def declaration(lane):
    value=read(CONTRACT)
    require(value==expected_declaration(),"Residual training declaration/source bindings")
    require(lane in value["lanes"],"Residual training lane")
    return dict(value,**value["lanes"][lane],lane=lane)


def zero_policy():
    return ars.Policy(tuple((0.,)*provider.features.DIMENSION for _ in range(8)),
        ars.Moments.empty(provider.features.DIMENSION),(3.5,)*8,1e-8)


def untrained_model(policy,lane):
    return provider.artifact(policy,dict(corpus_id="residual_"+lane+"_initial_v1",
        kind="untrained_development_probe",source_record_sha256=None,training_data_authority=False))


def trained_model(policy,lane,update_sha):
    return provider.artifact(policy,dict(corpus_id="residual_"+lane+"_training_v1",
        kind="development_training_checkpoint",source_record_sha256="sha256:"+update_sha,
        training_data_authority=True))


def ars_plan(c,iteration):
    require(type(iteration) is int and 0<=iteration<c["iterations"],"Residual training iteration")
    return ars.Plan(iteration,c["seed"]+iteration,tuple(c["groups"]),c["directions"],c["directions"],
        c["optimizer"]["noise_scale"],c["optimizer"]["step_size"])


def stages(c):
    return [f"iteration_{i:02d}" for i in range(c["iterations"])]+["comparison"]


def trial_plans(c,stage):
    require(stage in stages(c),"Residual training stage")
    if stage=="comparison":
        combinations=[(None,None,g,r) for g in c["groups"] for r in c["comparison_roles"]]
    else:
        combinations=[(d,s,g,"search") for d in range(c["directions"]) for s in (1,-1) for g in c["groups"]]
    plans=[]
    for direction,sign,group,role in combinations:
        condition,start=group.split("_train_");start="train_"+start
        require(condition in ("left_075","nominal") and start in dict(STARTS),"Residual training group boundary")
        key=f"d{direction:02d}_"+("plus" if sign==1 else "minus") if role=="search" else role
        model_key=key if role=="search" else ("baseline" if role=="baseline" else "trained")
        plans.append(dict(trial_id=stage+"_"+key+"_"+group,stage=stage,group_id=group,
            condition_id=condition,start_id=start,role=role,direction=direction,sign=sign,model_key=model_key,
            partition="training" if role=="search" else "development_comparison",
            mode="absent" if role=="baseline" else ("disabled" if role=="disabled" else "frozen"),
            seed=c["seed"],nworld=1,arm="scalar_direct",training_data_authority=role=="search",
            initial_native_lateral_velocity_m_s=dict(STARTS)[start]))
    return plans


def all_plans(c):
    value=[p for stage in stages(c) for p in trial_plans(c,stage)]
    require(len(value)==c["planned_cpu_worlds"] and len({p["trial_id"] for p in value})==len(value),
        "Residual prospective world population")
    return value


def batch_document(batch):
    return document(dict(policy=batch.policy.document(),plan=batch.plan.__dict__,
        perturbations=batch.perturbations,batch_sha256=batch.sha256))


def load_batch(value,c,iteration,policy):
    expected=ars.ask(policy,ars_plan(c,iteration))
    require(value==batch_document(expected),"Residual stored perturbation/parent batch")
    return expected


def moments_document(moments):
    moments.validate()
    return document(moments.__dict__)


def load_moments(value):
    require(set(value)=={"count","mean","m2"},"Residual moment artifact")
    result=ars.Moments(value["count"],tuple(value["mean"]),tuple(value["m2"]))
    result.validate()
    return result


def score(controls,trace,c,*,training):
    """Consume already validated native rows; keep reward separate from quality."""
    count=c["outer_steps"];total=count*5
    require(len(controls)==count and len(trace)==total,"Residual score full horizon")
    failure=None;rewards=[];moments=ars.Moments.empty(provider.features.DIMENSION);unsupported={}
    for index,row in enumerate(trace):
        require(row["step"]==index+1,"Residual score internal order")
        control=controls[index//5]
        if failure is None:
            failure=physical_violation(row,c["selection"])
            if control["output"]["actuation"]["safe_no_actuation"]:
                codes=["safe_no_actuation"]+(failure["failure_codes"] if failure else [])
                failure=dict(internal_step=index+1,time_s=row["time_s"],failure_codes=codes)
        r=c["reward"]
        value=r["failure_value"] if failure else -min(1.,(abs(row["qvel"][0]-r["desired_forward_velocity_m_s"])
            +r["lateral_error_weight"]*abs(row["qvel"][1]))/r["error_scale_m_s"])
        require(ars.finite(value) and -1.<=value<=0.,"Residual reward range")
        rewards.append(value)
    if training:
        for control in controls:
            decision=control["residual"]["decision"]
            require(isinstance(decision,dict),"Residual training feature decision")
            feature=decision["features"]
            if feature is None:
                reason=decision["reason"]
                require(isinstance(reason,str) and reason.startswith("unsupported_observation:"),"Residual missing feature reason")
                unsupported[reason]=unsupported.get(reason,0)+1
            else:
                moments=moments.add([feature["values"]],partition="training")
        require(moments.count>0 and moments.count+sum(unsupported.values())==count,"Residual feature denominator")
    windows=[]
    if c["official_quality_enabled"] and failure is None:
        lp=learner.contract();size=c["official_quality"]["window_commands"]
        require(count%size==0 and lp["decision_window_steps"]==size
            and lp["desired_forward_velocity_m_s"]==.2 and lp["lateral_error_weight"]==.25,"Residual official window contract")
        for start in range(0,count,size):
            stop=start+size
            position=controls[start]["request"]["state"]["base_pose_world"]["position_m"]
            a=[position["x"],position["z"]]
            if stop==count:
                end=bridge._mujoco_to_canonical(trace[-1]["qpos"][:3]);b=[float(end[0]),float(end[2])]
            else:
                end=controls[stop]["request"]["state"]["base_pose_world"]["position_m"];b=[end["x"],end["z"]]
            windows.append(dict(start_step=start,start_position_xz_m=a,end_position_xz_m=b,
                quality_m_s=learner.quality(a,b,size*c["controller_dt_s"],lp)))
    return dict(training_reward=math.fsum(rewards)/total,reward_denominator=total,
        reward_samples_sha256=ars.digest(rewards),first_reward_failure=failure,
        failure_padded_samples=0 if failure is None else total-failure["internal_step"]+1,
        observations=moments_document(moments) if training else None,
        supported_feature_rows=moments.count if training else None,unsupported_feature_rows=unsupported if training else None,
        official_quality_m_s=sum(w["quality_m_s"] for w in windows)/len(windows) if windows else None,
        official_windows=windows,comparison_data_used_for_training=False)


def update_from_audit(batch,audit,c,stage):
    plans=trial_plans(c,stage);trials=audit["trials"]
    require(stage!="comparison" and audit["ok"] is True and audit["synthetic"] is False
        and audit["stage"]==stage and audit["training_data_scope"]==c["training_data_scope"]
        and len(plans)==len(trials),"Residual audited training population")
    rollouts=[]
    for plan,row in zip(plans,trials,strict=True):
        require(all(row.get(k)==v for k,v in plan.items()) and row["partition"]=="training"
            and row["reward_denominator"]==c["outer_steps"]*5,"Residual update trial/denominator")
        policy=batch.candidate(plan["direction"],plan["sign"])
        require(row["policy_sha256"]==policy.sha256 and -1.<=row["training_reward"]<=0.,"Residual update policy/reward")
        rollouts.append(ars.Rollout(batch.sha256,policy.sha256,plan["direction"],plan["sign"],plan["group_id"],
            plan["partition"],plan["trial_id"],row["training_reward"],load_moments(row["observations"])))
    return ars.tell(batch,rollouts)


def stage_inputs(folder,c,core):
    """Derive an entire stage from the frozen program and verified parent only."""
    stage=folder.name
    require(stage in stages(c),"Residual stage identity")
    index=c["iterations"] if stage=="comparison" else int(stage.split("_")[1])
    previous=None
    if index:
        prior=folder.parent/f"iteration_{index-1:02d}"
        verify_update(prior,c,core,require_verification=True)
        parent=provider.FrozenModel.load(core,read(prior/"next-model.json"))
        previous=sha(prior/"verified-update.json")
    else:
        parent=provider.FrozenModel.load(core,untrained_model(zero_policy(),c["lane"]))
    if stage=="comparison":
        models={"trained":parent}
        if "baseline" in c["comparison_roles"]:
            models["baseline"]=provider.FrozenModel.load(core,untrained_model(zero_policy(),c["lane"]))
        batch=None
    else:
        batch=ars.ask(parent.policy,ars_plan(c,index));models={}
        for direction in range(c["directions"]):
            for sign in (1,-1):
                key=f"d{direction:02d}_"+("plus" if sign==1 else "minus")
                models[key]=provider.FrozenModel.load(core,provider.artifact(batch.candidate(direction,sign),
                    parent.document()["corpus"]))
    return batch,models,parent.sha256,previous


def stage_claim(folder,c,core):
    attempt=folder.parent.parent
    batch,models,parent,previous=stage_inputs(folder,c,core)
    plans=trial_plans(c,folder.name)
    claim=dict(schema_version="locolemotion_residual_training_stage_v1",stage=folder.name,lane=c["lane"],
        source_commit=read(attempt/"declaration.json")["source_commit"],
        contract_sha256=sha(CONTRACT),declaration_sha256=sha(attempt/"declaration.json"),
        gate_receipt_sha256=sha(attempt/"gate-receipt.json"),consumed_sha256=sha(attempt/"consumed.json"),
        parent_model_sha256=parent,previous_verified_update_sha256=previous,
        batch_sha256=batch.sha256 if batch else None,
        models={key:value.sha256 for key,value in models.items()},trials=plans,
        planned_cpu_worlds=len(plans),planned_gpu_worlds=0,training_data_scope=c["training_data_scope"])
    return claim,batch,models


def prepare_stage(folder,c,core):
    folder.mkdir()
    claim,batch,models=stage_claim(folder,c,core)
    (folder/"models").mkdir()
    for key,model in models.items():
        with (folder/"models"/(key+".json")).open("x",encoding="utf-8",newline="\n") as stream:
            stream.write(model.serialized)
    if batch:write_new(folder/"batch.json",batch_document(batch))
    write_new(folder/"stage.json",claim)
    return load_stage(folder,c,core)


def load_stage(folder,c,core):
    expected,batch,models=stage_claim(folder,c,core)
    require(read(folder/"stage.json")==expected,"Residual stage claim/model lineage")
    for key,model in models.items():
        path=folder/"models"/(key+".json")
        require("sha256:"+sha(path)==model.sha256 and read(path)==model.document(),"Residual staged immutable model")
    if batch:
        load_batch(read(folder/"batch.json"),c,batch.plan.iteration,batch.policy)
    else:
        require(not (folder/"batch.json").exists(),"Residual comparison has no training batch")
    return expected,batch,models


def updated_artifacts(folder,c,core):
    claim,batch,_=load_stage(folder,c,core)
    require(batch is not None,"Residual comparison cannot update")
    audit=read(folder/"audit.json")
    require(audit["stage_claim_sha256"]==sha(folder/"stage.json")
        and audit["source_commit"]==claim["source_commit"] and audit["reader_world_build_count"]==0
        and audit["reader_solver_steps"]==0,"Residual update audited stage binding")
    policy,update=update_from_audit(batch,audit,c,folder.name)
    record=document(dict(schema_version="locolemotion_residual_training_update_record_v1",
        lane=c["lane"],training_data_scope=c["training_data_scope"],source_commit=claim["source_commit"],
        stage=folder.name,stage_claim_sha256=sha(folder/"stage.json"),audit_sha256=sha(folder/"audit.json"),
        batch_file_sha256=sha(folder/"batch.json"),update=update,synthetic=False,
        **{k:k=="training_data_authority" for k in FLAGS}))
    return policy,record


def write_update(folder,c,core):
    policy,record=updated_artifacts(folder,c,core)
    write_new(folder/"update.json",record)
    model=provider.FrozenModel.load(core,trained_model(policy,c["lane"],sha(folder/"update.json")))
    with (folder/"next-model.json").open("x",encoding="utf-8",newline="\n") as stream:stream.write(model.serialized)


def verify_update(folder,c,core,*,require_verification=False):
    policy,record=updated_artifacts(folder,c,core)
    require(read(folder/"update.json")==record,"Residual optimizer update reconstruction")
    model=provider.FrozenModel.load(core,trained_model(policy,c["lane"],sha(folder/"update.json")))
    require(read(folder/"next-model.json")==model.document()
        and "sha256:"+sha(folder/"next-model.json")==model.sha256,"Residual next checkpoint reconstruction")
    result=dict(ok=True,stage=folder.name,lane=c["lane"],update_sha256=sha(folder/"update.json"),
        model_sha256=model.sha256,policy_sha256=policy.sha256,audit_sha256=sha(folder/"audit.json"),
        normalizer_sample_count=policy.moments.count,world_build_count=0,solver_steps=0,
        physical_acceptance_authority=False,release_authority=False)
    if require_verification:
        require(read(folder/"verified-update.json")==result,"Residual missing/crossed independent update verification")
    return result


def validate_launch_records(folder,c,source):
    """Require a complete zero-world gate and a fresh prospective stage claim."""
    evidence=(ROOT.parent/"SporeSpore_Evidence").resolve(strict=True)
    folder=folder.resolve(strict=True);attempt=folder.parent.parent.parent
    require(folder.name=="physical" and folder.parent.parent.name=="stages" and attempt.parent==evidence
        and attempt.name.startswith("sdk2-residual-training-"),"Residual training durable output boundary")
    owner=read(attempt/"declaration.json");gate=read(attempt/"gate-receipt.json")
    counts={name:count for name,_,count in GATES};counts.update(provider=2,containment=1)
    require(owner["contract"]==c and owner["source_commit"]==source and owner["synthetic"] is False,
        "Residual training owner freeze")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["safety_controls"]==counts
        and sum(counts.values())==c["complete_safety_control_count"]
        and gate["declaration_sha256"]==sha(attempt/"declaration.json")
        and gate["preflight"]["ok"] is True and gate["preflight"]["world_build_count"]==0
        and gate["preflight"]["solver_steps"]==0,"Residual training complete zero-world gate")
    require(read(attempt/"consumed.json")==dict(attempt_id=attempt.name,source_commit=source,lane=c["lane"],
        contract_sha256=sha(CONTRACT),declaration_sha256=sha(attempt/"declaration.json"),
        gate_receipt_sha256=sha(attempt/"gate-receipt.json"),trials=all_plans(c)),"Residual training consumed claim")
    return owner


def assess_comparison(trials,c):
    plans=trial_plans(c,"comparison")
    require(len(trials)==len(plans) and all(all(row.get(k)==v for k,v in plan.items())
        for row,plan in zip(trials,plans,strict=True)),"Residual final comparison population")
    require(all(row["observations"] is None and row["comparison_data_used_for_training"] is False for row in trials),
        "Residual comparison cannot fit")
    result=dict(fixed_final_checkpoint=True,groups=[],finite_development_screen_passed=False,
        tier2_qualified=False,tier3_benefit_established=False,release_authority=False)
    for group in c["groups"]:
        roles={r["role"]:r for r in trials if r["group_id"]==group}
        trained=roles["trained"];entry=dict(group_id=group,trained_eligible=trained["diagnostic_eligible"],
            trained_quality_m_s=trained["official_quality_m_s"])
        if c["lane"]=="pilot":
            baseline,disabled=roles["baseline"],roles["disabled"]
            require(baseline["raw_hashes"]["trace"]==disabled["raw_hashes"]["trace"],"Residual disabled changed baseline trace")
            require(baseline["official_quality_m_s"]==disabled["official_quality_m_s"]
                and baseline["nonzero_correction_commands"]==disabled["nonzero_correction_commands"]==0,
                "Residual disabled baseline outcome")
            q,bq=trained["official_quality_m_s"],baseline["official_quality_m_s"]
            entry.update(baseline_eligible=baseline["diagnostic_eligible"],baseline_quality_m_s=bq,
                disabled_trace_identical=True,quality_change_m_s=q-bq if q is not None and bq is not None else None,
                nominal_preserved=(q is not None and bq is not None and q>=bq) if group.startswith("nominal_") else None)
        result["groups"].append(entry)
    if c["lane"]=="pilot":
        result["finite_development_screen_passed"]=all(r["trained_eligible"] for r in result["groups"]) and all(
            r["nominal_preserved"] is True for r in result["groups"] if r["group_id"].startswith("nominal_"))
    return result
