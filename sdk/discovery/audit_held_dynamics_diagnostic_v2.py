"""Bind complete retained inputs and publish finite force-accounting diagnostics."""
import argparse
from contextlib import ExitStack
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
from held_dynamics_diagnostic_v2 import diagnose,TERMS
from audit_hierarchical_native_failure_v4 import ROOT,HERE,ATTEMPT,RECEIPT_SHA,read,sha,require
from audit_gpu_batch_execution import read_jsonl
from audit_residual_training_closure import verify_population
from run_hierarchical_native_v6 import inventory
from gpu_measurement_probe import write_new

CONTRACT=HERE/"held_dynamics_diagnostic_v2.json"
SOURCES=("held_dynamics_diagnostic_v2.py","audit_held_dynamics_diagnostic_v2.py",
    "test_held_dynamics_diagnostic_v2.py","run_held_dynamics_diagnostic_v2.py")
CONTROLS=18
GATES=(("diagnostic","test_held_dynamics_diagnostic_v2",CONTROLS),)
CLOSURE="sdk2-hierarchical-native-failure-v4-controls-1663602da54642d792033af93cba5f65"
CLOSURE_SHA="ab146eb6843144db31d0049a40077bc057aba711d4537460b94d7a6a6828bf48"
PREDECESSOR="sdk2-held-dynamics-diagnostic-v1-c4bf2e282a704a37b49c1b220fc16400"
PREDECESSOR_SHA="65b6ecebb19a801c8b8b48159cb608c0c6c6e48cd1e302a9357d7fcc1707f868"
CLOSURE_RESULT=HERE/"hierarchical_native_failure_result_v4.json"
RESULT_SHA="7336e104bf3b4df484dffeddadaf8f1870847dd6f162ebe363d003553fab0e65"


def expected_contract():
    return dict(schema_version="locolemotion_held_dynamics_diagnostic_contract_v2",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_trajectory_force_accounting",question_class="development"),
        original_attempt=ATTEMPT,original_receipt_sha256=RECEIPT_SHA,
        predecessor_attempt=PREDECESSOR,predecessor_receipt_sha256=PREDECESSOR_SHA,
        closure_attempt=CLOSURE,closure_receipt_sha256=CLOSURE_SHA,closure_result_sha256=RESULT_SHA,
        consumed_controller_commands=list(range(60,119)),internal_steps=295,joint_comparisons=2360,
        controls_required=CONTROLS,force_balance_absolute_tolerance=1e-8,
        trajectory_identity_absolute_tolerance=1e-10,
        coordinate_system="native generalized coordinates; planned vectors mapped at command start",
        contributions=list(TERMS),native_integrator="MuJoCo 3.11 implicitfast; zero passive damping; direct velocity motors",
        question="Which measured force and coefficient terms account for the frozen held prediction error?",
        interpretation="additive accounting on observed trajectory, not independent interventions or causal fractions",
        future_measured_forces_used_by_controller=False,margin_or_limit_changed=False,
        worlds_opened=0,solver_steps=0,training_data_authority=False,disturbance_bound_established=False,
        tier2_qualified=False,tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False,
        source_bindings={name:sha(HERE/name) for name in SOURCES})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Diagnostic exact prospective contract");return c


def summarize(value):
    rows=value["rows"];joints=value["ordered_joints"]
    values=np.array([r["joint_position_error_rad"] for r in rows])
    i,j=np.unravel_index(np.abs(values).argmax(),values.shape)
    def witness(index,joint):
        r=rows[index]
        return dict(command=r["command"],internal_step=r["internal_step"],joint_id=joints[joint],
            actual_position_rad=r["actual_joint_position"][joint],predicted_position_rad=r["predicted_joint_position"][joint],
            error_rad=r["joint_position_error_rad"][joint],
            contributions_rad={name:r["position_contributions_rad"][name][joint] for name in TERMS})
    stats={}
    for name in TERMS:
        a=np.array([r["position_contributions_rad"][name] for r in rows])
        stats[name]=dict(maximum_absolute_rad=float(np.max(np.abs(a))),rms_rad=float(np.sqrt(np.mean(a*a))))
    return dict(maximum_absolute_position_error_rad=float(np.max(np.abs(values))),
        position_error_rms_rad=float(np.sqrt(np.mean(values*values))),
        maximum_error_witness=witness(int(i),int(j)),terminal_hip_witness=witness(294,joints.index("rear_left_hip")),
        full_population_position_contribution_statistics=stats,
        steps_with_changed_motor_derivative=sum(r["actual_motor_derivative"]!=r["planned_motor_derivative"] for r in rows),
        steps_with_nonzero_joint_limit_force=sum(any(x!=0 for x in r["joint_limit_generalized_force"]) for r in rows))


def audit(evidence):
    contract=declaration();original=evidence/ATTEMPT;closure=evidence/CLOSURE
    failed=evidence/PREDECESSOR
    require(sha(failed/"receipt.json")==PREDECESSOR_SHA,"Diagnostic retained predecessor identity")
    previous=read(failed/"receipt.json");verify_population(previous["artifacts"],inventory(failed))
    require(previous["ok"] is False and previous["controls_passed"]==16
        and previous["worlds_opened"]==previous["solver_steps"]==0
        and not (failed/"audit.json").exists() and not (failed/"reconstruction.json").exists()
        and "KeyError: 'controller_context'" in (failed/"audit-reader/stderr.log").read_text(),
        "Diagnostic predecessor missing public trace field")
    require(sha(original/"receipt.json")==RECEIPT_SHA and sha(closure/"receipt.json")==CLOSURE_SHA
        and sha(CLOSURE_RESULT)==RESULT_SHA,"Diagnostic immutable parent identities")
    original_receipt=read(original/"receipt.json");receipt=read(closure/"receipt.json")
    verify_population(original_receipt["artifacts"],inventory(original))
    verify_population(receipt["artifacts"],inventory(closure))
    require(receipt["ok"] is True and receipt["controls_passed"]==24
        and sha(closure/"audit.json")==sha(closure/"reconstruction.json")==receipt["audit_sha256"]==receipt["reconstruction_sha256"],
        "Diagnostic verified complete parent reconstruction")
    folder=original/"physical/hierarchy_hold_left_075_train_001"
    controls=list(read_jsonl(folder/"controller.jsonl"));trace=list(read_jsonl(folder/"trace.jsonl"))
    contacts=list(read_jsonl(folder/"contact-force.jsonl"));profile=read(folder/"force-profile.json")
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Diagnostic opens no world")))
        value=diagnose(controls,trace,contacts,profile,(folder/"model.xml").read_text(encoding="utf-8"))
    return dict(schema_version="locolemotion_held_dynamics_diagnostic_audit_v2",ok=True,
        ledger_scope=contract["ledger_scope"],contract_sha256=sha(CONTRACT),
        original_receipt_sha256=RECEIPT_SHA,closure_receipt_sha256=CLOSURE_SHA,
        inputs={name:sha(folder/name) for name in ("controller.jsonl","trace.jsonl","contact-force.jsonl","force-profile.json","model.xml")},
        summary=summarize(value),**value)


if __name__=="__main__":
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--core",type=Path,required=True);p.add_argument("--baseline-core",type=Path,required=True)
    p.add_argument("--output",type=Path,required=True);args=p.parse_args()
    write_new(args.output,audit(ROOT.parent/"SporeSpore_Evidence"))
    print(json.dumps(dict(ok=True,output=str(args.output))))
