"""Retain the v3 reader's empty-contact serialization refusal."""
from pathlib import Path
from dynamic_control_failure import ROOT,read,sha,require,validate_bindings,verify_population,inventory,verify_tests
from audit_gpu_batch_execution import read_jsonl
from floating_base_dynamics import FloatingDynamics
from support_reach_geometry import ReachModel
import audit_dynamic_control_component_v3 as original
import dynamic_control_component_task_v3 as task

ATTEMPT="sdk2-dynamic-control-component-v3-f93d99033bb64f04a7570d65d3a972a9"
RECEIPT_SHA="2321492d2faadad76063eb7f7a8dc8965ea6d48a9c2f1678fb5c40d4c48df5e9"


def fixture():
    folder=task.EVIDENCE/ATTEMPT;identity=task.TRIALS[0][0]
    rows=list(read_jsonl(folder/("audit/"+identity+"-core-0.jsonl")))
    row=rows[-1]["controller"];previous=rows[-2]["controller"]
    profile=read(folder/("audit/"+identity+"-profile.json"))
    old=list(read_jsonl(task.EVIDENCE/task.ORIGINAL/"physical"/identity/"controller.jsonl"))[160]
    model=FloatingDynamics(profile["morphology_spec"],profile["parameters"]["joint_inertia_kg_m2"])
    reach=ReachModel(profile["morphology_spec"])
    nominal=float(model.tree.kinematics([0.,profile["reference_root_height_m"],0.],[0.,0.,0.,1.],[0.]*8)["whole_body_com"][1])
    return row,old,previous,profile,model,reach,nominal


def verify_failure():
    folder=task.EVIDENCE/ATTEMPT;r=read(folder/"receipt.json")
    require(sha(folder/"receipt.json")==RECEIPT_SHA and r["ok"] is False and r["controls_passed"]==107
        and r["worlds_opened"]==r["solver_steps"]==0 and not (folder/"audit.json").exists()
        and not (folder/"reconstruction.json").exists(),"Dynamic consumed empty-force reader failure")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(read(folder/"declaration.json")["binding"])
    for name,_,count in task.GATES:verify_tests(folder/(name+"-controls"),count)
    row,old,previous,profile,model,reach,nominal=fixture()
    require(row["request"]["state"]["semantic_step"]==160
        and row["force_reference"]["decision"]["allocation"]["active_contacts"]==[]
        and row["force_reference"]["decision"]["allocation"]["forces"]==[]
        and row["force_reference"]["terminal_error"] is None,"Dynamic solved no-support state")
    try:original.verify_row(row,old,previous,profile,model,reach,nominal)
    except ValueError as exc:require(str(exc)=="Dynamic reader solution forces","Dynamic exact empty-array refusal")
    else:raise ValueError("Dynamic empty-array refusal was not reproduced")
    return dict(attempt_id=ATTEMPT,receipt_sha256=RECEIPT_SHA,ok=False,controls_passed=107,
        original_stream_rows=[161,160],complete_readers=0,command=160,controller_solved=True,
        active_contacts=0,refusal_reproduced=True,message="Dynamic reader solution forces",
        world_build_count=0,solver_steps=0)
