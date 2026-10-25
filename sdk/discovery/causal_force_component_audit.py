"""Zero-world controller integration over retained observations, not a rollout.

After handoff the alternative resolved commands never generated these states.
This checks software chronology and two-core reconstruction only; it cannot
score recovery, predict motion, or supply training/qualification evidence.
"""
import argparse
import copy
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
from unittest.mock import patch
import mujoco
import numpy as np
import audit_contact_force_observer_closure as parent
from audit_gpu_batch_execution import read_jsonl
from contact_force_observer_task import ROOT,HERE,read,sha,require,bridge,controller_contract,frozen_model,declaration as old_declaration
from causal_force_control import ForceController,terminal_error
from causal_force_policy import make_profile,HANDOFF
from gpu_measurement_probe import write_new

CONTRACT=HERE/"causal_force_component_v1.json"
SOURCES=("causal_force_allocator.py","causal_force_policy.py","causal_force_control.py",
    "test_causal_force_allocator.py","test_causal_force_policy.py",
    "causal_force_component_audit.py","run_causal_force_component.py")
GATES=(("mechanics","test_actuation_recovery_mechanics",25),
       ("allocator","test_causal_force_allocator",17),("policy","test_causal_force_policy",16))
CONTROLS=sum(n for _,_,n in GATES)
TRIALS=("observer_on_left_075_train_001","observer_on_nominal_train_001")


def expected_contract():
    return dict(schema_version="locolemotion_causal_force_component_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="synthetic_controller_integration",question_class="development"),
        parent_closure_sha256=sha(parent.CLOSURE),trials=list(TRIALS),commands_per_trial=120,
        handoff_command=HANDOFF,prefix_commands=120,force_commands=120,core_reconstructions=2,
        implementation_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_mechanics_sha256=sha(HERE/"actuation_recovery_mechanics.py"),
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],controls_required=CONTROLS,
        observation_source="retained_original_trajectory",
        alternative_actions_generated_observations=False,synthetic=True,
        purpose="host chronology, bounded commands and two-core reconstruction only",
        world_build_count=0,solver_steps=0,physical_launch_authority=False,
        capability_estimated=False,dynamic_feasibility_established=False,held_interval_force_guaranteed=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False,equivalence_authority=False)


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Force component exact declaration")
    return c


def audit(evidence,core_path,baseline_path):
    c=declaration();closure=read(parent.CLOSURE)
    verified=parent.verify_record(parent.CLOSURE,evidence,core_path,baseline_path)
    attempt=parent.header(closure,evidence);trials=[];rows=[]
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Force integration opens no world")))
        for identity in TRIALS:
            folder=attempt/"physical"/identity
            compiled=read(folder/"compiled.json");inputs=read(folder/"inputs.json")
            original=list(read_jsonl(folder/"controller.jsonl"))
            require(len(original)==120,"Force complete original observations")
            profile=make_profile(compiled,inputs);reconstructed=[]
            for core_path_actual in (core_path,baseline_path):
                core=bridge.LocomotionCore(core_path_actual);model=frozen_model(core)
                host=ForceController(core,compiled,controller_contract(old_declaration(),model),
                    model,"synthetic_integration_"+identity,profile)
                population=[]
                try:
                    for step,old in enumerate(original):
                        require(old["outer_step"]==old["request"]["state"]["semantic_step"]==step,"Force source clock")
                        row=host.step(copy.deepcopy(old["request"]["state"]),copy.deepcopy(old["stability"]),copy.deepcopy(old["kinematics"]))
                        require(terminal_error(row) is None,"Force synthetic host provider failure")
                        require(all(r["normal_load_n"] is None for r in row["request"]["state"]["ordered_contact_observations"]),
                            "Force no relabeled controller load")
                        if step<HANDOFF:
                            require(all(row[k]==old[k] for k in ("output","composition","native_targets")),
                                "Force unchanged challenge prefix")
                        else:
                            detail=row["force_reference"]["decision"]
                            require(row["resolution"]["provider_status"]=="applied"
                                and row["native_targets"]==detail["projection"]["target"],"Force public resolver projection")
                        population.append(row)
                finally:host.close()
                require(host.session.closed,"Force core session closure")
                reconstructed.append(population)
            require(reconstructed[0]==reconstructed[1],"Force full two-core controller reconstruction")
            chosen=reconstructed[0]
            candidate=[r["force_reference"]["decision"] for r in chosen[HANDOFF:]]
            trials.append(dict(trial_id=identity,observation_sha256=sha(folder/"controller.jsonl"),
                profile=profile,commands=120,prefix_commands_identical=HANDOFF,force_commands=60,
                every_row_reconstructed_with_other_core=True,
                contact_counts=sorted(set(len(r["active_contacts"]) for r in candidate)),
                maximum_projected_gradient_norm=max(r["allocation"]["projected_gradient_norm"] for r in candidate),
                maximum_wrench_error_norm=max(float(np.linalg.norm(r["allocation"]["wrench_error"])) for r in candidate),
                maximum_torque_interval_violation_norm=max(float(np.linalg.norm(r["allocation"]["torque_interval_violation"])) for r in candidate),
                recovery_effectiveness_measured=False))
            rows.extend(dict(trial_id=identity,synthetic=True,alternative_actions_generated_observations=False,controller=r) for r in chosen)
    return dict(schema_version="locolemotion_causal_force_component_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),synthetic=True,
        parent_closure_sha256=sha(parent.CLOSURE),parent_reconstruction_verified=verified["ok"],
        parent_reconstruction_sha256=hashlib.sha256(json.dumps(verified,sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",trials=trials,rows=rows,
        commands=240,prefix_commands_identical=120,force_commands=120,core_reconstructions=2,
        world_build_count=0,solver_steps=0,physical_launch_authority=False,
        alternative_actions_generated_observations=False,capability_estimated=False,
        dynamic_feasibility_established=False,held_interval_force_guaranteed=False,
        recovery_benefit_established=False,tier2_qualified=False,tier3_benefit_established=False,
        physical_acceptance_authority=False,training_data_authority=False,release_authority=False,equivalence_authority=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();result=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,result)
    print(json.dumps(dict(ok=True,commands=result["commands"],world_build_count=0,solver_steps=0)))
    return 0


if __name__=="__main__":raise SystemExit(main())
