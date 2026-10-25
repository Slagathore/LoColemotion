"""Reconstruct portable inertia/bias identities on retained pre-fall states."""
import argparse,hashlib,itertools,json
from pathlib import Path
from contextlib import ExitStack
from unittest.mock import patch
import numpy as np
import mujoco
import posture_tracking_diagnostic as parent
from floating_base_dynamics import FloatingDynamics
from floating_base_dynamics_checks import verify_state
from floating_base_dynamics_inputs import native_parameters,verify_native_state
from actuation_recovery_mechanics import xyz
from force_recovery_diagnostic_metrics import robot_wrenches
from audit_gpu_batch_execution import read_jsonl
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_posture_tracking_diagnostic import inventory
from run_residual_native import verify_tests
from gpu_measurement_probe import write_new
from contact_force_observer_task import ROOT,HERE,read,sha,require

CONTRACT=HERE/"floating_base_dynamics_v1.json"
PARENT_RESULT=HERE/"posture_tracking_diagnostic_result_v1.json"
PARENT_SHA="2b3062878937d00f068d557e4e49062b4f2c3c5a7e4390e5904795c8e0191663"
SOURCES=("floating_base_dynamics.py","floating_base_dynamics_checks.py","floating_base_dynamics_inputs.py",
    "test_floating_base_dynamics.py","test_floating_base_dynamics_inputs.py",
    "floating_base_dynamics_audit.py","run_floating_base_dynamics.py")
GATES=(("mechanics","test_actuation_recovery_mechanics",25),
    ("dynamics","test_floating_base_dynamics",22),("inputs","test_floating_base_dynamics_inputs",9))
CONTROLS=56
TRIALS=("reach_hold_left_075_train_001","posture_hold_left_075_train_001")
NATIVE_ATTEMPT="sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"
DENIALS=tuple(dict.fromkeys((*parent.DENIALS,"native_dynamics_equivalence_established",
    "native_mass_matrix_readback_verified","native_bias_readback_verified","controller_changed",
    "base_is_actuated","held_contact_guaranteed")))


def expected_contract():
    return dict(schema_version="locolemotion_floating_base_dynamics_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="retained_floating_base_dynamics_component",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        inherited_bindings={n:sha(HERE/n) for n in ("actuation_recovery_mechanics.py",
            "contact_posture_reference.py","force_recovery_diagnostic_metrics.py")},
        parent_result_path=PARENT_RESULT.relative_to(ROOT).as_posix(),parent_result_sha256=PARENT_SHA,
        native_attempt=NATIVE_ATTEMPT,trials=list(TRIALS),commands_start=60,commands_end_exclusive=126,
        frames=132,generalized_dimensions=14,bodies_per_frame=9,body_observations=1188,
        configured_joint_inertia_kg_m2=[.01]*8,configured_passive_damping_nms_per_rad=[0.]*8,
        controls_required=CONTROLS,safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        generalized_order="root world linear; root world angular; ordered revolute joints",
        generalized_force_units=["N"]*3+["N m"]*11,
        generalized_acceleration_units=["m/s^2"]*3+["rad/s^2"]*11,
        synthetic_test_acceleration=np.linspace(-.2,.3,14).tolist(),
        exact_absolute_tolerance=1e-9,exact_relative_tolerance=1e-9,
        derivative_step=1e-6,derivative_absolute_tolerance=2e-7,derivative_relative_tolerance=2e-7,
        checks=["analytic inertia and recursive Newton-Euler columns","affine acceleration identity",
            "kinetic energy and power","potential gradient and original gravity","external virtual work",
            "finite-difference body velocity and bias acceleration","native body geometry and COM-based spatial velocities",
            "explicit native joint inertia and damping","positive energy form in declared SI coordinates"],
        original_contact_wrenches_used_only_for_virtual_work_validation=True,
        diagnostic_window_selected_after_outcomes=True,complete_parent_reconstruction_required=True,
        mass_matrix_has_mixed_units=True,native_spatial_velocity_origin="subtree_com of body_rootid 1",
        scope="diagonal COM-frame rigid-body inertias; revolute tree; explicit diagonal joint inertia; linear damping",
        exclusions=["joint-limit force prediction","contact generation and compliance","friction prediction",
            "motor dynamics beyond declared joint inertia","native mass/bias readback","control/optimization","physical recovery"],
        world_build_count=0,solver_steps=0,**{k:False for k in DENIALS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Dynamics exact component declaration");return c


def verify_parent(evidence,core,baseline):
    require(sha(PARENT_RESULT)==PARENT_SHA,"Dynamics parent result bytes")
    result=read(PARENT_RESULT);name=result["attempt_id"]
    require(Path(name).name==name and name.startswith("sdk2-posture-tracking-diagnostic-"),"Dynamics parent attempt boundary")
    folder=evidence/name;r=read(folder/"receipt.json");declared=read(folder/"declaration.json")
    require(result["receipt_sha256"]==sha(folder/"receipt.json")
        and result["declaration_sha256"]==r["declaration_sha256"]==sha(folder/"declaration.json")
        and r["ok"] is True and r["source_runtime_unchanged"] is True
        and r["controls_passed"]==result["controls_passed"]==34
        and r["worlds_opened"]==r["solver_steps"]==0
        and r["contract"]==declared["contract"]==parent.declaration()
        and len(declared["binding"]["source"])==r["source_binding_count"]==705
        and len(declared["binding"]["runtime"])==r["runtime_binding_count"]==1359
        and all(result[k] is False for k in parent.DENIALS),"Dynamics parent owner/authority")
    verify_population(r["artifacts"],inventory(folder));validate_bindings(declared["binding"])
    for name,_,count in parent.GATES:verify_tests(folder/(name+"-controls"),count)
    old=read(folder/"audit.json")
    require(old==read(folder/"reconstruction.json") and old["trials"]==result["trials"]
        and sha(folder/"audit.json")==r["audit_sha256"]==result["audit_sha256"]
        and sha(folder/"reconstruction.json")==r["reconstruction_sha256"]==result["reconstruction_sha256"],
        "Dynamics parent complete readers")
    current=parent.audit(evidence,core,baseline)
    require(current==old,"Dynamics complete parent reconstruction")
    return current


def audit(evidence,core,baseline):
    c=declaration();parent_value=verify_parent(evidence,core,baseline)
    require([t["trial_id"] for t in parent_value["trials"]]==list(TRIALS),"Dynamics exact retained population")
    rows=[];trials=[];attempt=evidence/NATIVE_ATTEMPT
    with ExitStack() as guards:
        for name in ("MjModel","MjData","mj_step","mj_step1","mj_step2","mj_forward"):
            guards.enter_context(patch.object(mujoco,name,side_effect=AssertionError("Dynamics component opens no worlds")))
        for identity in TRIALS:
            folder=attempt/"physical"/identity;profile=read(folder/"force-profile.json");spec=profile["morphology_spec"]
            parameters=native_parameters((folder/"model.xml").read_text(),spec)
            require(parameters["joint_inertia_kg_m2"]==c["configured_joint_inertia_kg_m2"]
                and parameters["passive_damping_nms_per_rad"]==c["configured_passive_damping_nms_per_rad"],
                "Dynamics configured native coefficients")
            model=FloatingDynamics(spec,parameters["joint_inertia_kg_m2"])
            controls=list(itertools.islice(read_jsonl(folder/"controller.jsonl"),60,126))
            samples=list(itertools.islice(read_jsonl(folder/"contact-force.jsonl"),300,630))
            require(len(controls)==66 and len(samples)==330,"Dynamics retained window population")
            errors={};native_errors={};eigenvalues=[];energies=[]
            for i,row in enumerate(controls):
                step=60+i;state=row["request"]["state"];pose=state["base_pose_world"];sample=samples[5*i]
                observation=row["native_observation"]
                require(row["outer_step"]==state["semantic_step"]==step
                    and sample["step"]==5*step+1 and sample["before_qpos"]==observation["qpos"]
                    and sample["before_qvel"]==observation["qvel"]
                    and sample["prepared_time_s"]==observation["time_s"],"Dynamics original force/state join")
                position=xyz(pose["position_m"]);orientation=[pose["orientation_xyzw"][k] for k in "xyzw"]
                joints=[j["position_rad"] for j in state["ordered_joint_observations"]]
                velocity=np.r_[xyz(state["base_twist_world"]["linear_velocity_m_s"]),
                    xyz(state["base_twist_world"]["angular_velocity_rad_s"]),
                    [j["velocity_rad_s"] for j in state["ordered_joint_observations"]]]
                gravity=xyz(state["gravity_world_m_s2"]);wrenches=robot_wrenches(sample)
                frame=model.tree.kinematics(position,orientation,joints)
                native=verify_native_state(model,frame,velocity,observation)
                check=verify_state(model,position,orientation,joints,velocity,c["synthetic_test_acceleration"],
                    gravity,wrenches,c["derivative_step"])
                for key,value in check["maximum_errors"].items():errors[key]=max(errors.get(key,0.),value)
                for key,value in native.items():native_errors[key]=max(native_errors.get(key,0.),value)
                eigenvalues.append(check["numerical_inertia_eigenvalue_min_in_declared_si_coordinates"])
                energies.append(check["kinetic_energy_j"])
                rows.append(dict(trial_id=identity,command=step,prepared_time_s=observation["time_s"],
                    native_geometry_velocity_errors=native,checks=parent.plain(check),
                    mass_matrix=model.mass_matrix(frame).tolist()))
            trials.append(dict(trial_id=identity,frames=66,body_observations=594,parameters=parameters,
                model_xml_sha256=sha(folder/"model.xml"),profile_sha256=sha(folder/"force-profile.json"),
                maximum_identity_errors=errors,maximum_native_geometry_velocity_errors=native_errors,
                minimum_numerical_inertia_eigenvalue_in_declared_si_coordinates=min(eigenvalues),
                kinetic_energy_range_j=[min(energies),max(energies)]))
    require(len(rows)==132,"Dynamics final retained population")
    return dict(schema_version="locolemotion_floating_base_dynamics_audit_v1",ok=True,
        ledger_scope=c["ledger_scope"],contract_sha256=sha(CONTRACT),parent_result_sha256=PARENT_SHA,
        parent_reconstruction_verified=True,parent_reconstruction_sha256=hashlib.sha256(json.dumps(parent_value,
            sort_keys=True,separators=(",",":"),allow_nan=False).encode()).hexdigest(),
        parent_reconstruction_hash_basis="sorted_compact_json_utf8",frames=132,body_observations=1188,
        generalized_dimensions=14,rows=rows,trials=trials,world_build_count=0,solver_steps=0,
        **{k:False for k in DENIALS})


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument("--core",type=Path,required=True)
    p.add_argument("--baseline-core",type=Path,required=True);p.add_argument("--output",type=Path,required=True)
    args=p.parse_args();r=audit(ROOT.parent/"SporeSpore_Evidence",args.core,args.baseline_core)
    write_new(args.output,r);print(json.dumps(dict(ok=True,frames=132,world_build_count=0,solver_steps=0)))
    return 0
if __name__=="__main__":raise SystemExit(main())
