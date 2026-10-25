"""Reconstruct hold commands on retained states; no alternative trajectory."""
import argparse
import copy
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import audit_causal_force_closure as parent
from audit_gpu_batch_execution import read_jsonl,same_bits
from causal_force_native_task import ROOT,HERE,read,sha,require,bridge,controller_contract,frozen_model,declaration as native_declaration
from causal_force_control import ForceController,terminal_error
from causal_force_policy import make_profile,HANDOFF
from recovery_hold_control import HoldForceController
from recovery_hold_composition import hold_motion_command
from gpu_measurement_probe import write_new

CONTRACT=HERE/"recovery_hold_component_v1.json"
DIAGNOSIS=HERE/"force_recovery_diagnostic_result_v1.json"
SOURCES=("recovery_hold_composition.py","recovery_hold_control.py","test_recovery_hold.py",
    "recovery_hold_component_audit.py","run_recovery_hold_component.py")
GATES=(("hold","test_recovery_hold",10),)
CONTROLS=10
TRIALS=("force_reference_left_075_train_001","force_reference_nominal_train_001")
INHERITED=("sdk/discovery/causal_force_control.py","sdk/discovery/causal_force_policy.py",
    "sdk/discovery/causal_force_allocator.py","sdk/discovery/actuation_recovery_mechanics.py",
    "sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py")
DENIALS=("alternative_actions_generated_observations","physical_launch_authority","total_target_slew_guaranteed",
    "capability_estimated","dynamic_feasibility_established","held_interval_force_guaranteed",
    "recovery_benefit_established","tier2_qualified","tier3_benefit_established","physical_acceptance_authority",
    "training_data_authority","release_authority","equivalence_authority")


def expected_contract():
    return dict(schema_version="locolemotion_recovery_hold_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="synthetic_controller_integration",question_class="development"),
        parent_closure_sha256=sha(parent.CLOSURE),diagnosis_sha256=sha(DIAGNOSIS),
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_source_bindings={n:sha(ROOT/n) for n in INHERITED},
        trials=list(TRIALS),roles=["force_walk","force_hold"],commands_per_role_per_trial=120,
        handoff_command=HANDOFF,hold_motion_command="hold, zero planar velocity, zero gait amplitude; clocked phase continues",
        support_composition="same actual command amplitude; other ABI operations and bounds unchanged",
        unchanged="force profile, configured capabilities, limits, prefix and actual resolved command history",
        baseline_transition="retain baseline, correction and total target changes separately; no total target slew promise",
        observation_source="retained force-walk native trajectories",synthetic=True,
        controls_required=CONTROLS,safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        core_reconstructions=2,commands=480,hold_commands=120,unchanged_hold_prefix_commands=120,
        world_build_count=0,solver_steps=0,**{k:False for k in DENIALS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Hold component exact declaration/source bindings");return c


def transition(previous,current):
    def vector(row,key):return np.array([x[key] for x in row["resolution"]["ordered_commands"]])
    keys=dict(baseline="baseline_canonical_target_velocity_rad_s",correction="applied_correction_rad_s",target="final_canonical_target_velocity_rad_s")
    return {name+"_delta_rad_s":(vector(current,key)-vector(previous,key)).tolist() for name,key in keys.items()}


def audit(evidence,core_path,baseline_path):
    c=declaration();verified=parent.verify_record(parent.CLOSURE,evidence,core_path,baseline_path)
    attempt=parent.header(read(parent.CLOSURE),evidence);trials=[];rows=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Hold component opens no world")))
        for identity in TRIALS:
            folder=attempt/"physical"/identity;original=list(read_jsonl(folder/"controller.jsonl"))
            require(len(original)==120,"Hold complete original observations")
            compiled=read(folder/"compiled.json");profile=make_profile(compiled,read(folder/"inputs.json"))
            reconstructed=[]
            for core_file in (core_path,baseline_path):
                core=bridge.LocomotionCore(core_file);model=frozen_model(core);roles={}
                for role,host_type in (("force_walk",ForceController),("force_hold",HoldForceController)):
                    host=host_type(core,compiled,controller_contract(native_declaration(),model),model,identity,profile)
                    population=[]
                    try:
                        for step,old in enumerate(original):
                            require(old["outer_step"]==old["request"]["state"]["semantic_step"]==step,"Hold original clock")
                            row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                            require(terminal_error(row) is None,"Hold host terminal refusal")
                            if role=="force_walk" or step<HANDOFF:
                                require(all(same_bits(value,old[key]) for key,value in row.items()),"Hold original walk/prefix reconstruction")
                            else:
                                request=row["resolution_request"]["provider_request"]
                                require(row["request"]["command"]==request["command"]==hold_motion_command(step,"clocked"),"Hold coherent motion command")
                                require(row["request"]["memory"]==population[-1]["output"]["next_memory"],"Hold baseline memory continuity")
                                require(len(request["history"]["ordered_entries"])==1 and request["history"]["ordered_entries"][0]["semantic_step"]==step-1,"Hold actual history clock")
                                require(not row["output"]["actuation"]["safe_no_actuation"],"Hold baseline safe-no-actuation")
                                for old_command,command,limit in zip(population[-1]["resolution"]["ordered_commands"],row["resolution"]["ordered_commands"],request["safety_envelope"]["ordered_actuator_limits"],strict=True):
                                    previous=old_command["applied_correction_rad_s"]
                                    require(limit["maximum_absolute_correction_rad_s"]==3.5 and limit["maximum_slew_per_step_rad_s"]==.08
                                        and limit["previous_applied_correction_rad_s"]==previous
                                        and abs(command["applied_correction_rad_s"]-previous)<=.08+1e-12
                                        and abs(command["applied_correction_rad_s"])<=3.5
                                        and abs(command["final_canonical_target_velocity_rad_s"])<=3.5,"Hold actual correction/target bounds")
                            require(all(x["normal_load_n"] is None for x in row["request"]["state"]["ordered_contact_observations"]),"Hold no relabeled current-solve load")
                            population.append(row)
                    finally:host.close()
                    require(host.closed and len(population)==120,"Hold complete closed host")
                    roles[role]=population
                reconstructed.append(roles)
            require(same_bits(reconstructed[0],reconstructed[1]),"Hold every row other-core reconstruction")
            selected=reconstructed[0];hold=selected["force_hold"];walk=selected["force_walk"]
            require(same_bits(hold[:HANDOFF],walk[:HANDOFF]),"Hold exact paired controller prefix")
            changes=[transition(hold[i-1],hold[i]) for i in range(HANDOFF,120)]
            trials.append(dict(trial_id=identity,observation_sha256=sha(folder/"controller.jsonl"),profile_sha256=sha(folder/"force-profile.json"),
                roles=["force_walk","force_hold"],commands=240,hold_commands=60,unchanged_hold_prefix_commands=60,
                every_row_reconstructed_with_other_core=True,handoff=changes[0],
                maximum_post_handoff_absolute_delta_rad_s={key:max(abs(x) for value in changes for x in value[key]) for key in changes[0]},
                maximum_post_handoff_absolute_target_rad_s=max(abs(x) for r in hold[60:] for x in r["native_targets"]),
                alternative_trajectory_simulated=False,recovery_effectiveness_measured=False))
            rows.extend(dict(trial_id=identity,role=role,synthetic=True,alternative_actions_generated_observations=False,controller=row)
                for role in c["roles"] for row in selected[role])
    return dict(schema_version="locolemotion_recovery_hold_component_audit_v1",ok=True,ledger_scope=c["ledger_scope"],
        contract_sha256=sha(CONTRACT),parent_closure_sha256=sha(parent.CLOSURE),diagnosis_sha256=sha(DIAGNOSIS),
        parent_reconstruction_verified=verified["ok"],
        parent_reconstruction_sha256=hashlib.sha256(json.dumps(verified,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",synthetic=True,trials=trials,rows=rows,
        commands=480,hold_commands=120,unchanged_hold_prefix_commands=120,core_reconstructions=2,
        world_build_count=0,solver_steps=0,**{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,result);print(json.dumps(dict(ok=True,commands=result["commands"],world_build_count=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
