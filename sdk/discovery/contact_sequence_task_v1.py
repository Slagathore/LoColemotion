"""Prospective stance-clearance search on four exposed native states."""
import hashlib
import json
import sequence_authority_task_v1 as prior
from sequence_constraint_repair_task_v1 import INPUT
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
ROOT,HERE,EVIDENCE,TRIAL=prior.ROOT,prior.HERE,prior.EVIDENCE,prior.TRIAL
read,sha,require=prior.read,prior.sha,prior.require
DLL,DLL_SHA=prior.DLL,prior.DLL_SHA
PARENT="sdk2-sequence-authority-v1-05915981119b44f48931d133e4699125"
PARENT_SHA="359a409ca0e1d0c36e1d8085c07ce9d33c5c8c6773607c7ff98d9a2aef42ef11"
CLOSURE_RESULT=HERE/"sequence_authority_result_v1.json"
RESULT_SHA="bd359f7b9f4371a78d281e9f96b9f04b113a0f5a2323c986cecd4ae7b87c1bd5"
CONTRACT=HERE/"contact_sequence_v1.json"
SOURCES=("predictive_contact_sequence_v1.py","contact_sequence_checks_v1.py","contact_sequence_task_v1.py",
    "audit_contact_sequence_v1.py","test_contact_sequence_v1.py","run_contact_sequence_v1.py")
GATES=(("contact-sequence","test_contact_sequence_v1",25),("sequence","test_predictive_sequence_v1",24),
    ("held-contact","test_held_contact_rollout",22),("constraint-rank","test_sequence_constraint_repair_v1",34))
CONTROLS=sum(n for _,_,n in GATES)
CASES=[{"command":60,"row_sha256":"cdcdbcc87c5ce4d1b6fec07bba5c1ed5727aad14758fca744cdaa4414590e65f","accepted":True,"valid_intervals":66,"evaluations":102},{"command":70,"row_sha256":"7405210f0b4a9f05239d4806c70f57d68b550188fa495582c5bea9f715077470","accepted":True,"valid_intervals":66,"evaluations":103},{"command":80,"row_sha256":"371e3985218454af25a6c98b845761c3a29dd3d7f2db6b83dbdaf6b945f6ad34","accepted":True,"valid_intervals":66,"evaluations":103},{"command":86,"row_sha256":"a52c1795bd42813c16f421825295d48b93fe32a03e7a6e8affe0a11162ffc8a3","accepted":False,"valid_intervals":65,"evaluations":419}]


def expected_contract():
    return dict(schema_version="locolemotion_contact_sequence_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_exposed_state_stance_clearance_search",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        input_bindings={p.name:sha(p) for p in (INPUT,TRIAL/"force-profile.json",TRIAL/"model.xml")},
        cases=CASES,maximum_input_row_bytes=1024*2**20,
        seed="Exact best control points from the full retained native-v4 decision at each state, including the refused refinement at86",
        proposal_family="Existing34 proposals per round: incumbent, zero correction, zero target, velocity brake,16 whole-joint boundary choices and14 normal samples",
        rounds=3,candidates_per_round=34,new_evaluations_per_case=102,new_evaluations_per_reader=408,
        random_seed=20261026,random_sigma=.8,horizon_intervals=66,
        ranking=["eligible","longest valid prefix","finite forecast before numerical refusal",
            "normalized guard violation","mean squared positive distal capsule clearance in square meters","inherited task cost"],
        contact_metric="Four ordered distal capsules; minimum endpoint world height minus radius at every completed predicted post-state; average squared positive height over feet and states",
        contact_metric_does_not_prove_loaded_support=True,contact_metric_tolerance=dict(relative=1e-12,absolute=1e-12),
        changed_ranking=True,earlier_accepted_decisions_may_change=True,
        guards_changed=False,actuator_caps_changed=False,future_baseline="current baseline held constant, explicitly approximate",
        retained_incumbent_reproduction="first freshly evaluated candidate must match the full retained seed forecast exactly",
        result_interpretation="Report all four outcomes and metric changes;86 is a declared stress probe. Earlier eligibility is protected by the incumbent; no native or superiority claim follows.",
        reference="original Python reconstructs both each retained seed and each new winner; all candidates receive independent guard, objective, proposal and scalar geometry checks",
        controls_required=CONTROLS,maximum_control_wall_seconds=900,maximum_reader_wall_seconds=10800,
        minimum_free_storage_bytes=64*2**30,maximum_capture_bytes=4*2**30,maximum_capture_row_bytes=64*2**20,
        runtime_native_api_forbidden=True,runtime_xml_parsing_forbidden=True,
        future_observations_used=False,future_recorded_actions_used=False,
        worlds_opened=0,solver_steps=0,trained=False,actual_native_transfer_verified=False,
        recovery_benefit_established=False,training_data_authority=False,tier2_qualified=False,
        tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,
        real_time_qualified=False,global_infeasibility_established=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Contact exact prospective contract");return c


def parent():
    folder=EVIDENCE/PARENT;r=read(folder/"receipt.json");a=read(folder/"audit.json")
    require(sha(folder/"receipt.json")==PARENT_SHA and sha(CLOSURE_RESULT)==RESULT_SHA
        and r["ok"] is True and r["source_runtime_unchanged"] is True and r["controls_passed"]==20
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
        "Contact complete diagnostic predecessor")
    verify_population(r["artifacts"],inventory(folder))
    require(a["total_retained_predicted_steps"]==2630 and len(a["cases"])==8
        and a["new_forecasts"]==a["worlds_opened"]==a["solver_steps"]==0,"Contact finite diagnostic scope")
    return prior.parent()


def inputs(c):
    expected={x["command"]:x for x in c["cases"]};previous=None;seen=[];count=0;digest=hashlib.sha256()
    with INPUT.open("rb") as stream:
        while True:
            raw=stream.readline(c["maximum_input_row_bytes"]+1)
            if not raw:break
            require(raw.endswith(b"\n") and len(raw)<=c["maximum_input_row_bytes"],"Contact complete bounded input")
            digest.update(raw);row=json.loads(raw);require(row["outer_step"]==count,"Contact input clock")
            if count in expected:
                require(hashlib.sha256(raw[:-1]).hexdigest()==expected[count]["row_sha256"],"Contact exact selected row")
                require(previous is not None and previous["outer_step"]==count-1,"Contact adjacent input history")
                seen.append(count);yield previous,row,expected[count]
            previous=dict(outer_step=count,resolution=row.get("resolution"));count+=1
    require(count==87 and seen==list(expected) and digest.hexdigest()==c["input_bindings"]["controller.jsonl"],
        "Contact complete bound native stream")
