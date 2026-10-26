"""Bounded candidate selection using causal held-command forecasts.

This is a configured, untrained development selector. Every candidate starts
from the same state; predictions never become observations or training data.
"""
import math
import time
import numpy as np
from actuation_recovery_mechanics import array,require,command_envelope,resolve_correction
from held_contact_rollout import HeldContactRollout,C,STEPS,H
from contact_priority_component import parameters as guard_parameters
from dynamic_inverse_dynamics_v2 import parameters as task_parameters
from posture_factorial_diagnostic import physical_violation

SEED=20261025
RANDOM_CANDIDATES=16
CANDIDATES=34
SELECTION=dict(minimum_height_m=.25,maximum_tilt_rad=.6,maximum_torso_contact_steps=0)
FIELDS={"qpos","qvel","baseline","previous_correction","nominal_correction","target_com","reference_joints","command"}


def packet(control):
    """Extract only causal inputs; the prior policy supplies the nominal proposal."""
    request=control["resolution_request"]["provider_request"]
    baseline=request["deterministic_baseline"]["ordered_commands"]
    limits=request["safety_envelope"]["ordered_actuator_limits"]
    mapping=control["composition"]["host_mapping"];decision=control["force_reference"]["decision"]
    require(mapping["engine_id"]=="mujoco" and mapping["canonical_to_host_velocity_sign"]==1.
        and [r["actuator_id"] for r in baseline]==[r["actuator_id"] for r in limits]
        ==[r["actuator_id"] for r in control["resolution"]["ordered_commands"]],"Selection native actuator order")
    require(not request["deterministic_baseline"]["safe_no_actuation"]
        and all(r["maximum_target_speed_rad_s"]==3.5 for r in baseline)
        and all(r["maximum_absolute_correction_rad_s"]==3.5
            and r["maximum_slew_per_step_rad_s"]==.08 for r in limits),"Selection unchanged public envelope")
    o=control["native_observation"]
    result=dict(qpos=list(o["qpos"]),qvel=list(o["qvel"]),
        baseline=[r["combined_canonical_target_velocity_rad_s"] for r in baseline],
        previous_correction=[r["previous_applied_correction_rad_s"] for r in limits],
        nominal_correction=[r["applied_correction_rad_s"] for r in control["resolution"]["ordered_commands"]],
        target_com=list(decision["target_com"]),
        reference_joints=list(decision["support_reference"]["reference_joint_positions_rad"]),
        command=control["outer_step"])
    envelope,nominal=validate(result)
    require(np.array_equal(resolve_correction(envelope,nominal)[1],control["native_targets"]),
        "Selection original nominal target identity")
    return result


def validate(value):
    require(set(value)==FIELDS,"Selection causal fields only")
    require(type(value["command"]) is int and 60<=value["command"]<1440,"Selection command clock")
    q=array(value["qpos"],(15,),"Selection position");array(value["qvel"],(14,),"Selection velocity")
    require(abs(np.linalg.norm(q[3:7])-1.)<1e-10,"Selection unit quaternion")
    array(value["target_com"],(3,),"Selection COM reference")
    array(value["reference_joints"],(8,),"Selection joint reference")
    envelope=command_envelope(value["baseline"],[3.5]*8,value["previous_correction"],[3.5]*8,[.08]*8)
    nominal=array(value["nominal_correction"],(8,),"Selection nominal correction")
    require(np.all(nominal>=envelope["lower_correction"]-1e-12)
        and np.all(nominal<=envelope["upper_correction"]+1e-12),"Selection nominal outside envelope")
    return envelope,nominal


def candidates(value):
    envelope,nominal=validate(value)
    lower=envelope["lower_correction"];upper=envelope["upper_correction"]
    proposals=[("nominal",nominal),("midpoint",.5*(lower+upper))]
    for j in range(8):
        for label,bound in (("lower",lower),("upper",upper)):
            p=nominal.copy();p[j]=bound[j];proposals.append((f"joint_{j}_{label}",p))
    rng=np.random.default_rng(SEED+value["command"])
    proposals.extend((f"sample_{i}",nominal+rng.normal(0.,.08,8)) for i in range(RANDOM_CANDIDATES))
    output=[]
    for index,(name,p) in enumerate(proposals):
        correction,target=resolve_correction(envelope,p)
        output.append(dict(index=index,name=name,correction=correction.tolist(),target=target.tolist()))
    require(len(output)==CANDIDATES,"Selection bounded candidate population")
    return output


def guard(forecast,limits):
    """Retain the inherited planning margin, speed cap and physical predicate."""
    if not forecast["accepted"]:return ["numerical_refusal"]
    require(len(forecast["rows"])==STEPS and forecast["completed_steps"]==STEPS,"Selection complete forecast")
    p=guard_parameters();margin=p["joint_position_margin_rad"];tolerance=2e-6
    reasons=set()
    for row in forecast["rows"]:
        q=array(row["qpos"],(15,),"Selection forecast position");v=array(row["qvel"],(14,),"Selection forecast velocity")
        if np.any(q[7:]<limits[:,0]+margin-tolerance) or np.any(q[7:]>limits[:,1]-margin+tolerance):
            reasons.add("joint_position_margin")
        if np.any(np.abs(v[6:])>p["joint_speed_planning_cap_rad_s"]+tolerance):reasons.add("joint_speed_cap")
        event=physical_violation(dict(row,time_s=(row["step"]+1)*H),SELECTION)
        if event:reasons.update(event["failure_codes"])
    return sorted(reasons)


class PredictiveSelector:
    def __init__(self,profile,xml):
        self.rollout=HeldContactRollout(profile,xml)
        self.model=self.rollout.contact_model.model
        self.limits=self.rollout.contact_model.limits
        self.p=task_parameters()

    def cost(self,forecast,value):
        """Quadratic pose/velocity/effort cost with existing task gains/weights.

        This is a new ranking objective, not the predecessor hierarchy's
        optimization certificate or a physical acceptance threshold.
        """
        p=self.p;terms=dict(com=0.,orientation=0.,joint_posture=0.,effort=0.)
        for row in forecast["rows"]:
            q=np.array(row["qpos"]);v=np.array(row["qvel"])
            quat=np.r_[C @ q[4:7],q[3]]
            frame=self.model.tree.kinematics(C @ q[:3],quat,q[7:])
            rotation=frame["rotations"][0]
            canonical_velocity=np.r_[C @ v[:3],rotation @ C @ v[3:6],v[6:]]
            motion=self.model.motion(frame,canonical_velocity,np.zeros(14))
            com_velocity=np.average(motion["com_velocity"],axis=0,weights=self.model.tree.mass)
            error=frame["whole_body_com"]-np.array(value["target_com"])
            terms["com"]+=p["com_weight"]*(np.dot(p["com_kp_per_s2"],error*error)+com_velocity @ com_velocity)
            quat=quat if quat[3]>=0 else -quat
            norm=np.linalg.norm(quat[:3]);angle=quat[:3]*(2.*np.arctan2(norm,quat[3])/norm) if norm>1e-12 else 2.*quat[:3]
            terms["orientation"]+=p["orientation_weight"]*(np.dot(p["orientation_kp_per_s2"],angle*angle)
                +canonical_velocity[3:6] @ canonical_velocity[3:6])
            error=q[7:]-np.array(value["reference_joints"])
            terms["joint_posture"]+=p["joint_weight"]*(p["joint_kp_per_s2"]*(error @ error)+v[6:] @ v[6:])
            effort=np.array(row["prediction"]["actuator_force"])
            terms["effort"]+=p["torque_regularization"]*(effort @ effort)
        terms={k:float(v/STEPS) for k,v in terms.items()};total=sum(terms.values())
        require(math.isfinite(total) and total>=0,"Selection finite nonnegative objective")
        return dict(total=total,terms=terms)

    def select(self,value,timing=None):
        options=candidates(value);q=np.array(value["qpos"])
        require(np.all(q[7:]>=self.limits[:,0]) and np.all(q[7:]<=self.limits[:,1]),
            "Selection native joint limit already active")
        rows=[]
        for option in options:
            started=time.perf_counter()
            forecast=self.rollout.predict(dict(qpos=value["qpos"],qvel=value["qvel"],target_velocity=option["target"]))
            predicted=time.perf_counter();reasons=guard(forecast,self.limits)
            objective=self.cost(forecast,value) if forecast["accepted"] else None
            if timing is not None:
                timing.append(dict(command=value["command"],candidate=option["index"],
                    prediction_s=predicted-started,evaluation_s=time.perf_counter()-started))
            rows.append(dict(option,forecast=forecast,rejection_reasons=reasons,
                eligible=not reasons,objective=objective))
        eligible=[r for r in rows if r["eligible"]]
        selected=min(eligible,key=lambda r:(r["objective"]["total"],r["index"])) if eligible else None
        return dict(accepted=selected is not None,command=value["command"],candidates=rows,
            selected_index=None if selected is None else selected["index"],
            selected_correction=None if selected is None else selected["correction"],
            selected_target=None if selected is None else selected["target"],
            reason="minimum_cost_eligible_candidate" if selected else "no_eligible_candidate",
            finite_candidate_set_only=True,global_optimum_established=False,
            native_observations_generated=False,trained=False,tier2_qualified=False,
            tier3_benefit_established=False,physical_acceptance_authority=False,release_authority=False)
