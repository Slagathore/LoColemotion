"""Independent certificates, priority preservation and held-target reconstruction."""
import copy
import numpy as np
import generic_proximal_contact_component as hierarchy
import conditioned_contact_component as coordinates
import switching_contact_component as switching
import contact_priority_component as constraints
import hierarchical_least_squares_qp as least
import actuation_recovery_mechanics as m
import dynamic_inverse_dynamics_v2 as dynamic
from dynamic_qp_solver_v2 import certificate,problem_digest
from floating_dynamics_oracle_math import canonical_state
from support_reach_geometry import support_reference
from hierarchical_force_policy_v8 import HANDOFF,plain
from audit_gpu_batch_execution import same_bits
from causal_force_control import terminal_error
from contact_force_observer_task import require

from hierarchical_native_row_audit_v7 import close,solution,verify_stage,verify_refinement,verify_original_refusal
import hierarchical_native_row_audit_v7 as previous_reader
from scaled_primary_solution_audit import verify_primary,initial_record

def verify_secondary(qp,record,settings):
    r=record["reduced"];f=qp["full"];red=qp["reduced"]
    require(r["backend"]=="ProxQP 0.7.2 generic dense PrimalDualLDLT" and r["settings"]==settings["secondary"]
        and r["initial_guess"]=="NO_INITIAL_GUESS" and type(r["accepted"]) is bool
        and r["problem_sha256"]==problem_digest(red["P"],red["q"],red["A"],red["lower"],red["upper"]),
        "Scaled reader secondary solver binding")
    if r["status"]=="solved":
        cert=certificate(red["P"],red["q"],red["A"],red["lower"],red["upper"],r["x"],r["y"])
        require(r["certificate"]==cert and r["accepted"] is cert["accepted"],"Scaled reader secondary reduced certificate")
    else:require(r["accepted"] is False and all(r[k] is None for k in ("x","y","certificate")),"Scaled reader secondary solver refusal")
    expected=dict(reduced=r,accepted=False,full_x=None,full_y=None,full_certificate=None,
        full_problem_sha256=problem_digest(f["P"],f["q"],f["A"],f["lower"],f["upper"]),
        **{k:qp[k] for k in ("support_rank","support_singular_values","rank_tolerance","conditioning",
            "maximum_nullspace_equality_error","maximum_origin_equality_error")})
    if r["accepted"]:
        x=qp["transform"] @ np.asarray(r["x"])+qp["offset"];eq=qp["equality_indices"];remaining=qp["remaining_indices"]
        gradient=f["P"] @ x+f["q"]+f["A"][remaining].T @ np.asarray(r["y"])
        dual,_,rank,_=np.linalg.lstsq(f["A"][eq].T,-gradient,rcond=None)
        y=np.zeros(len(f["lower"]));y[remaining]=r["y"];y[eq]=dual
        cert=certificate(f["P"],f["q"],f["A"],f["lower"],f["upper"],x,y)
        expected.update(accepted=cert["accepted"],full_x=x,full_y=y,full_certificate=cert,equality_dual_rank=int(rank))
    require(same_bits(plain(expected),plain(record)),"Scaled reader secondary full reconstruction")


def verify_attempts(base,value,settings,scaled):
    attempts=value["attempts"];patterns=set();prior=None;count=0
    require(1<=len(attempts)<=16,"Scaled reader outer attempt bound")
    for attempt in attempts:
        pattern=np.asarray(attempt["pattern"]);kind=attempt["kind"];record=attempt["result"]
        patterns.add(tuple(pattern.reshape(-1).tolist()))
        if kind.startswith(("priority_strict:","priority_proposal_only:")):
            qp=coordinates.priority_problem(base,pattern,kind.startswith("priority_strict:"))
            if scaled:count+=verify_primary(qp,record,settings)
            else:
                initial_record(qp,record["initial_primary"],settings["priority"])
                verify_refinement(qp,solution(record),settings,proximal_primary=True);count+=1
            prior=(record,pattern) if kind.startswith("priority_strict:") else None
        else:
            require(kind.startswith("secondary_scaled_primary:" if scaled else "secondary_proximal_primary:")
                and prior is not None and prior[0]["accepted"] is True and np.array_equal(prior[1],pattern),
                "Scaled reader secondary order and pattern")
            qp=coordinates.build_secondary(base,pattern,solution(prior[0]));verify_secondary(qp,record,settings);count+=1
            if not value["accepted"]:require(record["accepted"] is False,"Scaled reader previous secondary refusal")
        require(same_bits(plain(switching.document(qp,record,kind)),attempt),"Scaled reader all attempt equations")
    require(type(value["patterns_tried"]) is int and value["patterns_tried"]==len(patterns)<=8,
        "Scaled reader complete pattern population")
    return count


def verify_predecessors(base,allocation,settings):
    old=allocation["scaling_previous_refusal"]
    require(old["accepted"] is False and old["status"]=="bounded hierarchical search refused"
        and old["solver_route"]=="proximal_primary_refused" and old["primary_backend_fallback_attempted"] is True
        and old["prediction"] is None and old["selected"] is None and old["fallback_attempted"] is True
        and same_bits(old["original_refusal"],allocation["original_refusal"])
        and same_bits(old["previous_refusal"],allocation["previous_refusal"]),
        "Scaled reader complete three-route refusal")
    refined=old["previous_refusal"];original=old["original_refusal"]
    require(refined["solver_route"]=="refined_primary_refused" and refined["fallback_attempted"] is True
        and same_bits(refined["original_refusal"],original),"Scaled reader predecessor refusal join")
    verify_original_refusal(base,original,settings["previous"]["original"])
    verify_original_refusal(base,refined,settings["previous"]["refined"],refined=True)
    first_count=len(original["attempts"])+len(refined["attempts"])
    require(type(refined["total_qp_solves"]) is int and refined["total_qp_solves"]==first_count<=32,
        "Scaled reader first two routes work")
    count=first_count+verify_attempts(base,old,settings["alternate"],False)
    require(type(old["total_qp_solves"]) is int and count==old["total_qp_solves"]<=48,"Scaled reader third route work")
    return count


def verify_row(row,original,previous,profile,model,reach,nominal):
    if original["outer_step"]<HANDOFF:
        return previous_reader.verify_row(row,original,previous,profile,model,reach,nominal)
    allocation=row["force_reference"]["decision"]["allocation"]
    flag=allocation["scaled_primary_fallback_attempted"]
    require(type(flag) is bool,"Scaled reader route flag type")
    if not flag:
        require(allocation["scaling_previous_refusal"] is None,"Scaled reader no invented fourth predecessor")
        inherited=dict(profile,solver_settings=profile["solver_settings"]["previous"])
        result=previous_reader.verify_row(row,original,previous,inherited,model,reach,nominal)
        return dict(result,scaled_primary_fallback_attempted=False)
    return verify_scaled_row(row,original,previous,profile,model,reach,nominal)

def verify_scaled_row(row,original,previous,profile,model,reach,nominal):
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
    route=allocation["solver_route"];recovered=True;proximal_primary=True
    require(route=="scaled_primary" and allocation["fallback_attempted"] is True
        and allocation["primary_backend_fallback_attempted"] is True
        and allocation["scaled_primary_fallback_attempted"] is True,"Scaled reader fourth selected route")
    settings=profile["solver_settings"]["alternate"]
    previous_count=verify_predecessors(base,allocation,profile["solver_settings"]["previous"])
    selected_count=verify_attempts(base,allocation,settings,True)
    verify_primary(first,primary,settings)
    primary_cert=verify_stage(first,primary,True,settings,proximal_primary=True)
    second=coordinates.build_secondary(base,pattern,primary)
    secondary_cert=verify_stage(second,secondary,False,settings)
    count=previous_count+selected_count
    require(type(allocation["total_qp_solves"]) is int and count==allocation["total_qp_solves"]<=112
        and selected_count<=64,"Scaled reader actual total work")
    index=allocation["selected_attempt"];attempts=allocation["attempts"]
    require(type(index) is int and index==len(attempts)-1 and index>=1,"Hierarchy selected attempt order")
    for qp,result,attempt,kind in ((first,primary,attempts[index-1],"priority_strict:"),
            (second,secondary,attempts[index],"secondary_scaled_primary:")):
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
    return dict(scaled_primary_fallback_attempted=True,solver_route=route,fallback_attempted=recovered,primary_backend_fallback_attempted=proximal_primary,total_qp_solves=count,maximum_equation_residual=float(np.max(np.abs(residual))),
        maximum_bound_violation=max(primary_cert["maximum_bound_violation"],secondary_cert["maximum_bound_violation"]),
        maximum_stationarity_error=max(primary_cert["maximum_stationarity_error"],secondary_cert["maximum_stationarity_error"]),
        maximum_complementarity_error=max(primary_cert["maximum_complementarity_error"],secondary_cert["maximum_complementarity_error"]),
        priority_preservation_error=prediction["maximum_priority_preservation_error"],
        transferred_priority_error=prediction["maximum_transferred_priority_error"],
        held_acceleration_error=prediction["maximum_errors"]["acceleration"],
        iterations=primary["initial_primary"]["reduced"]["iterations"]+sum(x["solver"]["iterations"] for x in primary["scaled_corrections"])+secondary["reduced"]["iterations"],active_contacts=len(active))
