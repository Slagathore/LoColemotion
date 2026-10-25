"""Two-core public handoff and numerical recovery, with independent row certificates."""
import argparse
import copy
from contextlib import ExitStack
from pathlib import Path
from unittest.mock import patch
from collections import Counter
import mujoco
import audit_refined_fallback_component_v2 as parent
from hierarchical_force_policy_v6 import make_profile,parameters,solver_settings
from hierarchical_hold_control_v6 import HierarchicalHoldController,terminal_error
from hierarchical_native_row_audit_v6 import verify_row
from dynamic_response_diagnostic_metrics import configured_model
from support_reach_geometry import ReachModel
from hold_horizon_task import controller_contract,frozen_model,declaration as hold_declaration
from audit_gpu_batch_execution import read_jsonl,same_bits
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_refined_fallback_component_v2 import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require,bridge

CONTRACT=HERE/"hierarchical_public_v6.json"
PARENT_RESULT=HERE/"refined_fallback_component_result_v2.json"
PARENT_SHA="090adeaffc13f96110449e824d1e24d721fbc09d9cbfdeea7f347009d29665cc"
SOURCES=("hierarchical_force_policy_v6.py","hierarchical_hold_control_v6.py",
    "test_hierarchical_force_policy_v6.py","hierarchical_native_row_audit_v6.py",
    "test_hierarchical_row_audit_v6.py","audit_hierarchical_public_v6.py","run_hierarchical_public_v6.py")
GATES=(*parent.GATES,("public-policy-v6","test_hierarchical_force_policy_v6",17),
    ("public-row-v6","test_hierarchical_row_audit_v6",16))
CONTROLS=sum(k for _,_,k in GATES)
DENIALS=tuple(k for k in parent.DENIALS if k!="public_controller_integration_verified")
EVIDENCE=ROOT.parent/"SporeSpore_Evidence"

def cases():
    nominal=read(parent.prior.task.PARENT_CLOSURE)["attempt_id"]
    return [dict(attempt_id=parent.prior.ATTEMPT,trial_id=parent.TRIAL,commands=90,kind="weak_recovery"),
        dict(attempt_id=nominal,trial_id="reach_hold_nominal_train_001",commands=62,kind="nominal_handoff")]

def expected_contract():
    return dict(schema_version="locolemotion_hierarchical_public_contract_v6",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="public_controller_retained_reconstruction",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},parent_result_sha256=PARENT_SHA,
        input_cases=[dict(case,input_bindings={n:sha(EVIDENCE/case["attempt_id"]/"physical"/case["trial_id"]/n)
            for n in parent.INPUTS}) for case in cases()],
        parameters=parameters(),solver_settings=solver_settings(),controls_required=CONTROLS,
        core_builds=2,public_hosts_per_reader=4,public_commands_per_reader=304,
        unchanged_prefix_commands_per_host=60,post_handoff_commands_per_reader=64,
        recovered_public_commands_per_reader=2,complete_reader_invocations=2,
        original_applied_hierarchical_commands_preserved_per_weak_host=29,
        weak_allocations_match_verified_component=True,independent_selected_equations_and_certificates=True,
        primary_refinement_independently_reconstructed=True,refused_original_equations_reconstructed=True,
        conditioned_secondary_duals_independently_reconstructed=True,
        production_entrypoints=dict(provider="hierarchical_force_policy_v6.py:Policy",
            host="hierarchical_hold_control_v6.py:HierarchicalHoldController",
            solver="refined_fallback_contact_component.py:compute",resolver="resolve_adaptation_v1",
            reader="hierarchical_native_row_audit_v6.py:verify_row"),
        public_observations_are_retained=True,
        native_successor_launch_authorized=False,output_rounding=False,replay_tolerances_changed=False,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Public6 exact contract");return c

def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Public6 completed component identity")
    result=read(PARENT_RESULT);folder=evidence/result["attempt_id"]
    receipt=read(folder/"receipt.json");declared=read(folder/"declaration.json");c=parent.declaration()
    for key,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
            ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(result[key]==sha(folder/name),"Public6 component artifact")
    a=read(folder/"audit.json")
    require(receipt["ok"] is True and receipt["component_accepted"] is True and receipt["controls_passed"]==72
        and receipt["contract"]==declared["contract"]==c and receipt["source_runtime_unchanged"] is True
        and a["ok"] is True and a["states"]==148 and a["accepted_states"]==140 and a["component_accepted"] is True
        and same_bits(a,read(folder/"reconstruction.json")) and sha(folder/"audit.json")==sha(folder/"reconstruction.json")
        and all(a[k] is False for k in parent.DENIALS),"Public6 complete component scope")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in parent.GATES:verify_tests(folder/(name+"-controls"),count)
    parent.verify_parent(evidence,core,baseline)
    parent.prior.task.retained.header(read(parent.prior.task.PARENT_CLOSURE),evidence)
    return {(x["trial_id"],x["command"]):x["result"] for x in a["rows"]}

def audit(evidence,core_path,baseline_path,capture):
    c=declaration();component=verify_parent(evidence,core_path,baseline_path);reports=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Public6 opens no worlds")))
        for case in cases():
            folder=evidence/case["attempt_id"]/"physical"/case["trial_id"]
            originals=list(read_jsonl(folder/"controller.jsonl"))[:case["commands"]]
            require(len(originals)==case["commands"],"Public6 full retained population")
            compiled=read(folder/"compiled.json");profile=make_profile(compiled,read(folder/"inputs.json"))
            dynamics,_=configured_model((folder/"model.xml").read_text(),profile);reach=ReachModel(profile["morphology_spec"])
            outputs=[];certificates=[]
            for core_index,core_file in enumerate((core_path,baseline_path)):
                core=bridge.LocomotionCore(core_file);model=frozen_model(core)
                host=HierarchicalHoldController(core,compiled,controller_contract(hold_declaration(),model),model,case["trial_id"],profile)
                rows=[];checks=[]
                try:
                    for step,old in enumerate(originals):
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        rows.append(row);require(terminal_error(row) is None,"Public6 terminal controller refusal")
                        checked=verify_row(row,old,rows[-2] if step else None,profile,dynamics,reach,host.force_policy.height)
                        if checked is not None:
                            checks.append(checked);allocation=row["force_reference"]["decision"]["allocation"]
                            if case["kind"]=="weak_recovery":
                                expected=component[(case["trial_id"],step)]
                                require(same_bits({k:allocation[k] for k in expected},expected),"Public6 exact verified component join")
                                if step<89:
                                    require(same_bits(row["resolution"]["ordered_commands"],old["resolution"]["ordered_commands"])
                                        and same_bits(row["native_targets"],old["native_targets"]),"Public6 unchanged native commands")
                                else:require(allocation["fallback_attempted"] is True and allocation["solver_route"]=="refined_primary",
                                    "Public6 actual terminal recovery branch")
                finally:
                    host.close()
                    write_new(capture/(case["trial_id"]+"-core"+str(core_index)+".json"),
                        dict(case=case,profile=profile,core_sha256=sha(core_file),rows=rows,
                            checks=checks,controller_closed=host.closed,worlds_opened=0))
                require(len(rows)==case["commands"] and host.closed,"Public6 complete lifecycle")
                outputs.append(rows);certificates.append(checks)
            require(same_bits(outputs[0],outputs[1]) and same_bits(certificates[0],certificates[1]),"Public6 bitwise two-core replay")
            routes=Counter(x["solver_route"] for x in certificates[0])
            reports.append(dict(case=case,profile=profile,core_sha256s=[sha(core_path),sha(baseline_path)],
                commands_per_core=case["commands"],unchanged_prefix_commands=60,
                hierarchical_commands_per_core=case["commands"]-60,solver_routes_per_core=dict(routes),
                cores_bitwise_identical=True,checks=certificates[0],rows=outputs[0]))
    require(sum(r["commands_per_core"]*2 for r in reports)==304
        and sum(r["solver_routes_per_core"].get("refined_primary",0)*2 for r in reports)==2,
        "Public6 complete public recovery population")
    return dict(schema_version="locolemotion_hierarchical_public_audit_v6",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        component_accepted=True,public_controller_integration_verified=True,
        public_hosts=4,public_commands=304,hierarchical_commands=64,recovered_public_commands=2,
        reports=reports,nominal_public_handoff_verified=True,independent_row_certificates_verified=True,
        synthetic=True,worlds_opened=0,solver_steps=0,**{k:False for k in DENIALS})

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();capture=args.output.parent/(args.output.stem+"-capture");capture.mkdir()
    value=audit(EVIDENCE,args.core,args.baseline_core,capture);write_new(args.output,value)
    print({k:value[k] for k in ("ok","public_hosts","public_commands","recovered_public_commands")})
    return 0
if __name__=="__main__":raise SystemExit(main())
