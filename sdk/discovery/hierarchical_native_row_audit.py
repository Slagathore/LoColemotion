"""Independent certificates, priority preservation and held-target reconstruction."""
import copy
import numpy as np
import generic_proximal_contact_component as hierarchy
import switching_contact_component as switching
import contact_priority_component as constraints
import hierarchical_least_squares_qp as least
import actuation_recovery_mechanics as m
import dynamic_inverse_dynamics_v2 as dynamic
from dynamic_qp_solver_v2 import certificate,problem_digest
from floating_dynamics_oracle_math import canonical_state
from support_reach_geometry import support_reference
from hierarchical_force_policy_v5 import HANDOFF,plain
from audit_gpu_batch_execution import same_bits
from causal_force_control import terminal_error
from contact_force_observer_task import require

def close(a,b,label,tolerance=1e-11):
    a=np.asarray(a);b=np.asarray(b)
    require(a.shape==b.shape and np.isfinite(a).all() and np.isfinite(b).all()
        and np.max(np.abs(a-b),initial=0.)<=tolerance,"Hierarchy reader "+label)

def solution(value):
    value=copy.deepcopy(value)
    for key in ("full_x","full_y"):value[key]=np.asarray(value[key],dtype=float)
    for key in ("x","y"):value["reduced"][key]=np.asarray(value["reduced"][key],dtype=float)
    return value

def verify_stage(qp,record,priority,profile):
    full=qp["full"];red=qp["reduced"];r=record["reduced"]
    require(record["accepted"] is True and r["accepted"] is True and r["status"]=="solved",
        "Hierarchy independently solved stages")
    expected_backend="OSQP builtin CPU" if priority else "ProxQP 0.7.2 generic dense PrimalDualLDLT"
    require(r["backend"]==expected_backend and r["settings"]==profile["solver_settings"]["priority" if priority else "secondary"],
        "Hierarchy pinned backend and tolerances")
    if not priority:require(r["initial_guess"]=="NO_INITIAL_GUESS","Hierarchy fresh secondary")
    require(r["problem_sha256"]==problem_digest(red["P"],red["q"],red["A"],red["lower"],red["upper"])
        and record["full_problem_sha256"]==problem_digest(full["P"],full["q"],full["A"],full["lower"],full["upper"]),
        "Hierarchy independent problem identities")
    if priority:
        reduced=least.certificate(qp["reduced_task_matrix"],qp["reduced_task_target"],red["A"],red["lower"],red["upper"],r["x"],r["y"])
        cert=least.certificate(qp["task_matrix"],qp["task_target"],full["A"],full["lower"],full["upper"],record["full_x"],record["full_y"])
    else:
        reduced=certificate(red["P"],red["q"],red["A"],red["lower"],red["upper"],r["x"],r["y"])
        cert=certificate(full["P"],full["q"],full["A"],full["lower"],full["upper"],record["full_x"],record["full_y"])
    require(reduced==r["certificate"] and reduced["accepted"] and cert==record["full_certificate"] and cert["accepted"],
        "Hierarchy independent reduced and original certificates")
    close(qp["transform"] @ r["x"]+qp["offset"],record["full_x"],"original primal reconstruction",0.)
    n=qp["base"]["n"];gradient=full["P"] @ record["full_x"]+full["q"]+full["A"][n:].T @ r["y"]
    y=np.r_[np.linalg.solve(full["A"][:n,:n].T,-gradient[:n]),r["y"]]
    close(y,record["full_y"],"original dual reconstruction",0.)
    return cert

def verify_row(row,original,previous,profile,model,reach,nominal):
    step=original["outer_step"]
    require(row["request"]["state"]==original["request"]["state"] and row["stability"]==original["stability"]
        and row["kinematics"]==original["kinematics"],"Dynamic original observations unchanged")
    if step<HANDOFF:
        require(all(same_bits(v,original[k]) for k,v in row.items()),"Dynamic unchanged prefix")
        return None
    require(terminal_error(row) is None,"Dynamic successful command")
    request=row["resolution_request"]["provider_request"];d=row["force_reference"]["decision"];allocation=d["allocation"]
    position,quaternion,joints,velocity,gravity=canonical_state(row)
    frame=model.tree.kinematics(position,quaternion,joints);com=frame["whole_body_com"]
    contacts=request["controller_context"]["controller_memory"]["contact_packet"]["ordered_contacts"]
    opaque=request["provider_memory"]["opaque_state"]
    target=np.array([com[0],nominal,com[2]]) if step==HANDOFF else np.array(opaque["target_com"])
    before_height=float(target[1]);reaches=reach.evaluate(position,quaternion,joints)
    reference=support_reference(reaches,{r["contact_site_id"]:r["presence"] and r["bears_support"] for r in contacts},
        float(position[1]),float(com[1]),nominal,before_height,profile["reference_parameters"])
    target[1]=reference["target_com_height_m"]
    require(reference==d["support_reference"] and reaches==d["support_reach"]
        and nominal-.10-1e-12<=target[1]<=before_height+1e-12
        and before_height-target[1]<=.20/120.+1e-12,"Dynamic reference reconstruction/rate")
    close(target,d["target_com"],"target");close(com,d["com"],"COM")
    items,active=dynamic.tasks(model,frame,velocity,quaternion,contacts,target,
        np.array(reference["reference_joint_positions_rad"])-joints,profile["parameters"]["dynamic"])
    baseline=request["deterministic_baseline"]["ordered_commands"];limits=request["safety_envelope"]["ordered_actuator_limits"]
    require(not request["deterministic_baseline"]["safe_no_actuation"] and d["projection_applies_to_transfer"] is True,
        "Dynamic active transfer domain")
    require(row["request"]["memory"]==previous["output"]["next_memory"],"Dynamic baseline memory continuity")
    require(request["history"]["ordered_entries"][-1]["semantic_step"]==step-1,"Dynamic history clock")
    for before,command,limit in zip(previous["resolution"]["ordered_commands"],row["resolution"]["ordered_commands"],limits,strict=True):
        prior=before["applied_correction_rad_s"]
        require(limit["previous_applied_correction_rad_s"]==prior and limit["maximum_absolute_correction_rad_s"]==3.5
            and limit["maximum_slew_per_step_rad_s"]==.08 and abs(command["applied_correction_rad_s"]-prior)<=.08+1e-12
            and abs(command["applied_correction_rad_s"])<=3.5 and abs(command["final_canonical_target_velocity_rad_s"])<=3.5,
            "Dynamic actual resolved bounds/history")
    envelope=m.command_envelope([r["combined_canonical_target_velocity_rad_s"] for r in baseline],
        [r["maximum_target_speed_rad_s"] for r in baseline],[r["previous_applied_correction_rad_s"] for r in limits],
        [r["maximum_absolute_correction_rad_s"] for r in limits],[r["maximum_slew_per_step_rad_s"] for r in limits])
    base=constraints.build(model,frame,velocity,gravity,joints,
        np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in model.tree.spec["joints"]]),
        items,active,envelope,profile["velocity_gains"],profile["force_ranges"],"combined")
    require(not base["domain_refusal"] and allocation["accepted"] is True,"Hierarchy accepted model domain")
    pattern=np.asarray(allocation["prediction"]["pattern"])
    first=hierarchy.priority_problem(base,pattern)
    primary=solution(allocation["primary"]);secondary=solution(allocation["selected"])
    primary_cert=verify_stage(first,primary,True,profile)
    second=switching.build(hierarchy.freeze_contact(base,primary["full_x"]),pattern,True)
    secondary_cert=verify_stage(second,secondary,False,profile)
    index=allocation["selected_attempt"];attempts=allocation["attempts"]
    require(type(index) is int and index==len(attempts)-1 and index>=1,"Hierarchy selected attempt order")
    for qp,result,attempt,kind in ((first,primary,attempts[index-1],"priority_strict:"),
            (second,secondary,attempts[index],"secondary_proximal:")):
        require(attempt["kind"].startswith(kind)
            and same_bits(plain(switching.document(qp,result,attempt["kind"])),attempt),
            "Hierarchy selected equations and attempts join")
    prediction=hierarchy.verify(first,primary,second,secondary)
    require(same_bits(plain(prediction),allocation["prediction"]),"Hierarchy complete independent five-step prediction")
    require(d["active_contacts"]==[r["contact_site_id"] for r in active],"Hierarchy supporting population")
    targets=np.array([r["final_canonical_target_velocity_rad_s"] for r in row["resolution"]["ordered_commands"]])
    close(targets,d["projection"]["target"],"public resolver target",0.)
    close(targets,prediction["target"],"selected held target",1e-12)
    actual=m.motor_torque(targets,velocity[6:],profile["velocity_gains"],profile["force_ranges"])
    close(actual,allocation["requested_torque"],"actual prepared torque",0.)
    forces=prediction["predicted_forces"];acc=prediction["predicted_steps"][0]["acceleration"]
    close(forces,np.asarray(allocation["forces"]).reshape(len(active),3),"selected contact forces",0.)
    close(acc,allocation["acceleration"],"selected initial acceleration",0.)
    for fx,fy,fz in forces:
        require(-2e-6<=fy<=70.+2e-6 and max(abs(fx),abs(fz))<=.95/np.sqrt(2.)*fy+2e-6,"Hierarchy independent force bounds")
    wrenches=[dict(body_id=r["body_id"],point=r["point"],force=f,torque=np.zeros(3)) for r,f in zip(active,forces,strict=True)]
    # Recursive inverse dynamics checks the implicit motor equation independently
    # of the affine QP construction; all five clipped motor steps were checked above.
    damping=np.where(pattern[0]==0,profile["velocity_gains"],0.)
    residual=model.inverse_dynamics(frame,velocity,acc,gravity)-model.passive_force(velocity)
    residual-=model.generalized_wrenches(frame,wrenches)+np.r_[np.zeros(6),actual]
    residual+=np.r_[np.zeros(6),damping*acc[6:]]/600.
    require(np.max(np.abs(residual))<=4e-6,"Hierarchy independent implicit transferred equations")
    close(residual,allocation["transferred_dynamics_residual"],"reported implicit equations")
    require(allocation["dynamic_feasibility_established"] is False
        and prediction["model_only"] is True and prediction["nonzero_contact_error_is_permitted"] is True
        and prediction["exact_requested_contact_target_established"] is False
        and prediction["physical_acceptance_authority"] is False and prediction["contact_persistence_established"] is False
        and d["current_solve_force_consumed"] is False and d["capability_estimated"] is False
        and d["reentry_permitted"] is False,"Hierarchy bounded authority")
    return dict(maximum_equation_residual=float(np.max(np.abs(residual))),
        maximum_bound_violation=max(primary_cert["maximum_bound_violation"],secondary_cert["maximum_bound_violation"]),
        maximum_stationarity_error=max(primary_cert["maximum_stationarity_error"],secondary_cert["maximum_stationarity_error"]),
        maximum_complementarity_error=max(primary_cert["maximum_complementarity_error"],secondary_cert["maximum_complementarity_error"]),
        priority_preservation_error=prediction["maximum_priority_preservation_error"],
        transferred_priority_error=prediction["maximum_transferred_priority_error"],
        held_acceleration_error=prediction["maximum_errors"]["acceleration"],
        iterations=primary["reduced"]["iterations"]+secondary["reduced"]["iterations"],active_contacts=len(active))
