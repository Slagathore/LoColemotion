"""Prospective finite constraint-repair task bound to the consumed native refusal."""
import hashlib
import json
from pathlib import Path
from audit_prepared_predictive_model import ROOT,HERE,DLL,DLL_SHA,read,sha,require
from audit_predictive_sequence_public_v4 import GATES as PARENT_GATES
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from predictive_sequence_local_search_v1 import SCALES,CANDIDATES,SEED,SAMPLES

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
PARENT="sdk2-predictive-sequence-native-v4-a2e10bd6cfb14867991d0943d3ebc5b9"
PARENT_SHA="0c074685d2f4852c5fa44844e9b4c1807cce159ac66bcb0f18d84122bcea6525"
CLOSURE_RESULT=HERE/"predictive_sequence_native_result_v4.json"
RESULT_SHA="abfab2180d3d92957023202caa3afdfb0068d2341fae1a5f7828a62a3d0e6f2d"
TRIAL=EVIDENCE/PARENT/"physical/predictive_hold_left_075_train_001"
INPUT=TRIAL/"controller.jsonl"
CONTRACT=HERE/"sequence_constraint_repair_v1.json"
SOURCES=("predictive_sequence_constraint_repair_v1.py","sequence_constraint_repair_checks_v1.py",
    "sequence_constraint_repair_task_v1.py","audit_sequence_constraint_repair_v1.py",
    "test_sequence_constraint_repair_v1.py","run_sequence_constraint_repair_v1.py")
GATES=(("constraint-repair","test_sequence_constraint_repair_v1",34),*PARENT_GATES)
CONTROLS=sum(n for _,_,n in GATES)
COMMANDS=(81,83,84,85,86)


def sha(path):
    with path.open("rb") as stream:return hashlib.file_digest(stream,"sha256").hexdigest()


def expected_contract():
    return dict(schema_version="locolemotion_sequence_constraint_repair_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="finite_retained_native_constraint_repair",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_attempt=PARENT,parent_receipt_sha256=PARENT_SHA,parent_result_sha256=RESULT_SHA,
        input_bindings={n:sha(TRIAL/n) for n in ("controller.jsonl","force-profile.json","model.xml")},
        commands=list(COMMANDS),new_search_command=86,horizon=66,
        initial_seed="original rejected best knots, before the consumed 316-candidate refinement",
        regression="rerank all retained candidates at commands 81,83,84,85; verify all guard/cost/projection fields and unchanged round winners; do not regenerate forecasts",
        parent_replay="exact hash-bound native closure and independent readers; no claim of rerunning the original searches",
        successor_search="four rounds; same incumbent, 64 coordinates, 14 random perturbations and clipping",
        perturbation_scales=list(SCALES),candidates_per_round=CANDIDATES,maximum_new_evaluations=4*CANDIDATES,
        retained_regression_evaluations=4*4*CANDIDATES,random_seed=SEED,
        ranking=["eligible first","longest admissible prefix","complete finite predictor before numerical refusal",
            "mean summed normalized violation in first rejected interval","original task objective","first candidate in ties"],
        normalization=dict(joint_position="full joint range",joint_speed_rad_s=3.5,height_m=.25,tilt_rad=.6,
            torso_contact="binary per internal step; any torso contact is one",
            comparison_tolerance=2e-6,interval_internal_steps=5,
            numerical_refusal="severity unavailable; never zero-feasible",
            unevaluated_future="not scored; longest admissible prefix remains a prior ordering key"),
        first_command_permission="none; retained-state diagnostic only",
        controls_required=CONTROLS,maximum_control_wall_seconds=600,maximum_reader_wall_seconds=7200,
        minimum_free_storage_bytes=64*2**30,maximum_capture_bytes=4*2**30,
        maximum_capture_row_bytes=1024*2**20,maximum_input_row_bytes=1024*2**20,
        reference="original Python reconstructs old rejected best and new best at 86; scalar independent violation accounting; all new candidate guards/costs/projection verified",
        runtime_native_api_forbidden=True,runtime_xml_parsing_forbidden=True,
        future_observations_used=False,future_recorded_actions_used=False,
        changed_horizon=False,changed_guard=False,worlds_opened=0,solver_steps=0,
        actual_native_transfer_verified=False,trained=False,training_data_authority=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,release_authority=False,real_time_qualified=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Repair exact prospective contract");return c


def parent():
    folder=EVIDENCE/PARENT;r=read(folder/"receipt.json");a=read(folder/"audit.json");result=read(CLOSURE_RESULT)
    require(sha(folder/"receipt.json")==PARENT_SHA and sha(CLOSURE_RESULT)==RESULT_SHA
        and r["ok"] is True and r["source_runtime_unchanged"] is True
        and sum(r["safety_controls"].values())==1407
        and sha(folder/"audit.json")==sha(folder/"reconstruction.json")==r["audit_sha256"],
        "Repair complete native parent")
    verify_population(r["artifacts"],inventory(folder))
    require(a["constructed_cpu_worlds"]==2 and a["execution_complete"] is False
        and a["controller_rows"]==1527 and a["internal_rows"]==7630,"Repair finite native parent population")
    require(result["readers_byte_identical"] and result["complete_reader_invocations"]==2
        and result["receipt_sha256"]==PARENT_SHA and result["refusal_preceded_transfer"] is True,
        "Repair parent closure authority")
    return result


def inputs(c,closure):
    """Stream exact adjacent history, retaining no more than one large decision."""
    expected={x["command"]:x for x in closure["refinement_population"]["cases"]}
    require(tuple(expected)==COMMANDS,"Repair exposed case population")
    previous=None;count=0;seen=[];digest=hashlib.sha256()
    with INPUT.open("rb") as stream:
        while True:
            raw=stream.readline(c["maximum_input_row_bytes"]+1)
            if not raw:break
            require(len(raw)<=c["maximum_input_row_bytes"] and raw.endswith(b"\n"),"Repair complete bounded input row")
            digest.update(raw);row=json.loads(raw)
            require(row["outer_step"]==count,"Repair input clock")
            if count in expected:
                require(hashlib.sha256(raw[:-1]).hexdigest()==expected[count]["row_sha256"],
                    "Repair exact exposed row digest")
                require(previous is not None and previous["outer_step"]==count-1,"Repair adjacent actual history")
                seen.append(count);yield previous,row,expected[count]
            previous=dict(outer_step=count,resolution=row["resolution"])
            count+=1;del raw,row
    require(count==87 and tuple(seen)==COMMANDS
        and digest.hexdigest()==c["input_bindings"]["controller.jsonl"],"Repair complete original input stream")
