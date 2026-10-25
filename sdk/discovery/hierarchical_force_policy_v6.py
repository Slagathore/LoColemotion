"""Configured contact-first hierarchy through the unchanged public resolver.

Support error is minimized before posture under hard motor and joint bounds.
The frozen hold model does not certify native contact persistence or recovery.
"""
import copy
import hashlib
import json
import importlib.metadata as metadata
from pathlib import Path
import numpy as np
import actuation_recovery_mechanics as m
from floating_base_dynamics import FloatingDynamics
import dynamic_inverse_dynamics_v2 as dynamic
import refined_fallback_contact_component as hierarchy
import contact_priority_component as constraints
from refined_fallback_contact_component import solver_settings
from support_reach_geometry import ReachModel,reference_parameters,support_reference

PROVIDER="configured_hierarchical_recovery_v6"
VERSION="contact_first_hierarchy_v6"
CONTEXT="locolemotion_hierarchical_context_v6"
HANDOFF=60
CORPUS=dict(schema_version="locolemotion_untrained_force_origin_v1",trained=False,training_corpus=None)


def digest(core,value):return core.canonicalize_json(value)["sha256"]


def plain(value):
    if isinstance(value,np.ndarray):return value.tolist()
    if isinstance(value,np.generic):return value.item()
    if isinstance(value,dict):return {k:plain(v) for k,v in value.items()}
    if isinstance(value,(tuple,list)):return [plain(v) for v in value]
    return value


DYNAMICS_EVIDENCE_SHA="e042080786791f93611e353f719cd3c8cff701b1a15be4ceddb3dc35fbf8b247"
SOLVER_RUNTIME={"numpy":"2.4.6","scipy":"1.17.1","osqp":"1.1.3","proxsuite":"0.7.2","cmeel":"0.61.0"}


def parameters():
    return dict(reference_joint_positions_rad=[0.]*8,joint_inertia_kg_m2=[.01]*8,
        maximum_absolute_correction_rad_s=3.5,maximum_slew_per_command_rad_s=.08,
        dynamic=dynamic.parameters(),hierarchy=hierarchy.parameters())


def make_profile(compiled,inputs):
    spec=copy.deepcopy(compiled["morphology"]["morphology_spec"])
    return dict(schema_version="locolemotion_hierarchical_force_profile_v6",parameters=parameters(),reference_parameters=reference_parameters(),
        solver_runtime=SOLVER_RUNTIME,solver_settings=solver_settings(),native_readback_sha256=DYNAMICS_EVIDENCE_SHA,
        morphology_spec=spec,descriptor=copy.deepcopy(compiled["descriptor"]),
        ordered_actuators=copy.deepcopy(inputs["ordered_actuators"]),
        velocity_gains=copy.deepcopy(inputs["velocity_gains"]),force_ranges=copy.deepcopy(inputs["force_ranges"]),
        reference_root_height_m=inputs["initial_qpos"][2],handoff_command=HANDOFF,
        source_bindings={name:hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
            for name in ("hierarchical_force_policy_v6.py","refined_fallback_contact_component.py","refined_primary_contact_component.py","primary_active_refinement.py","conditioned_contact_component.py","hierarchical_nullspace_component.py","generic_proximal_contact_component.py","generic_proximal_qp_solver.py","proxqp_dependencies_v1.json","generic_proxqp_backend.py","hierarchical_contact_component.py","hierarchical_least_squares_qp.py",
                "switching_contact_component.py","contact_priority_component.py","dynamic_inverse_dynamics_v2.py","dynamic_qp_solver_v2.py",
                "floating_base_dynamics.py","actuation_recovery_mechanics.py","support_reach_geometry.py")},
        capability_source="configured_reference_not_estimated",trained=False,
        held_interval_force_guaranteed=False,dynamic_feasibility_established=False,
        physical_acceptance_authority=False,tier2_qualified=False,tier3_benefit_established=False)


def contact_packet(state,stability):
    m.require(state["semantic_step"]==stability["semantic_step"]
        and state["gravity_world_m_s2"]==stability["gravity_world_m_s2"],"Force canonical clock/gravity join")
    fields=("contact_site_id","presence","bears_support","point_world_m","normal_world_unit")
    rows=[{k:copy.deepcopy(r[k]) for k in fields} for r in stability["ordered_support_contacts"]]
    m.require([(r["contact_site_id"],r["presence"],r["bears_support"]) for r in rows]
        ==[(r["contact_site_id"],r["presence"],r["bears_support"]) for r in state["ordered_contact_observations"]],
        "Force canonical contact join")
    return dict(schema_version="locolemotion_prepared_contact_packet_v1",semantic_step=state["semantic_step"],
        sample_time_s=state["sample_time_s"],ordered_contacts=rows)


class HierarchyRefusal(ValueError):
    def __init__(self,decision):
        super().__init__("Hierarchical support control refused")
        self.decision=plain(decision)


class Policy:
    def __init__(self,core,profile):
        self.core=core;self.profile=copy.deepcopy(profile);profile=self.profile;self.p=profile["parameters"]
        m.require(profile["schema_version"]=="locolemotion_hierarchical_force_profile_v6"
            and self.p==parameters() and profile["reference_parameters"]==reference_parameters() and profile["handoff_command"]==HANDOFF
            and profile["capability_source"]=="configured_reference_not_estimated"
            and all(profile[k] is False for k in ("trained","held_interval_force_guaranteed",
                "dynamic_feasibility_established","physical_acceptance_authority","tier2_qualified","tier3_benefit_established")),
            "Force immutable profile/authority")
        m.require(profile["source_bindings"]=={name:hashlib.sha256(Path(__file__).with_name(name).read_bytes()).hexdigest()
            for name in ("hierarchical_force_policy_v6.py","refined_fallback_contact_component.py","refined_primary_contact_component.py","primary_active_refinement.py","conditioned_contact_component.py","hierarchical_nullspace_component.py","generic_proximal_contact_component.py","generic_proximal_qp_solver.py","proxqp_dependencies_v1.json","generic_proxqp_backend.py","hierarchical_contact_component.py","hierarchical_least_squares_qp.py",
                "switching_contact_component.py","contact_priority_component.py","dynamic_inverse_dynamics_v2.py","dynamic_qp_solver_v2.py",
                "floating_base_dynamics.py","actuation_recovery_mechanics.py","support_reach_geometry.py")},
            "Force exact implementation bindings")
        m.require(profile["solver_runtime"]==SOLVER_RUNTIME=={k:metadata.version(k) for k in SOLVER_RUNTIME}
            and profile["solver_settings"]==solver_settings() and profile["native_readback_sha256"]==DYNAMICS_EVIDENCE_SHA
            and hashlib.sha256(Path(__file__).with_name("floating_dynamics_readback_result_v1.json").read_bytes()).hexdigest()==DYNAMICS_EVIDENCE_SHA,
            "Dynamic verified model/solver runtime")
        self.reach=ReachModel(profile["morphology_spec"]);self.tree=self.reach.tree
        self.dynamics=FloatingDynamics(profile["morphology_spec"],self.p["joint_inertia_kg_m2"])
        self.actuators=profile["ordered_actuators"]
        m.require(self.tree.n==8 and self.actuators==[a["actuator_id"] for a in self.tree.spec["actuators"]]
            and self.tree.joint_ids==[a["joint_id"] for a in self.tree.spec["actuators"]],"Force ordered actuator/joint model")
        self.gains=m.array(profile["velocity_gains"],(8,),"Force configured gains")
        self.ranges=m.array(profile["force_ranges"],(8,2),"Force configured ranges")
        self.joint_ranges=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in self.tree.spec["joints"]])
        m.motor_torque([0.]*8,[0.]*8,self.gains,self.ranges)
        self.sites={s["contact_site_id"]:s["body_id"] for s in self.tree.spec["contact_sites"]}
        root_height=m.array([profile["reference_root_height_m"]],(1,),"Force reference height")[0]
        m.require(root_height>0,"Force positive reference height")
        self.height=float(self.tree.kinematics([0.,root_height,0.],[0.,0.,0.,1.],
            self.p["reference_joint_positions_rad"])["whole_body_com"][1])
        self.sha=digest(core,profile);self.model_id="configured_hierarchy_"+self.sha[-24:]

    def memory(self,episode):
        m.require(isinstance(episode,str) and episode,"Force episode identity")
        opaque=dict(schema_version="locolemotion_hierarchical_force_memory_v6",episode_id=episode,
            model_sha256=self.sha,last_step=HANDOFF-1,target_com=None,previous_forces={},previous_binding=None)
        return dict(schema_version="sporespore_adaptation_provider_memory_v1",provider_id=PROVIDER,
            reset_epoch=0,sequence=0,opaque_state=opaque,opaque_state_sha256=digest(self.core,opaque),weights_mutated=False)

    def bind(self,request,stability,memory,episode):
        value=copy.deepcopy(request);step=value["state"]["semantic_step"]
        value.update(request_id="force_"+episode+"_"+str(step),provider_id=PROVIDER,
            expected_provider_version=VERSION,expected_model_id=self.model_id,expected_model_sha256=self.sha,
            expected_training_corpus_id="untrained_configured_force_reference",
            expected_training_corpus_sha256=digest(self.core,CORPUS),provider_memory=copy.deepcopy(memory))
        old=value["controller_context"]
        context=dict(schema_version=CONTEXT,baseline_next_memory=old["controller_memory"],profile_sha256=self.sha,
            contact_packet=contact_packet(value["state"],stability))
        old.update(controller_memory_schema_version=CONTEXT,controller_memory=context,
            controller_memory_sha256=digest(self.core,context))
        return value

    def respond(self,request):
        core=self.core;p=self.p;state=request["state"];step=state["semantic_step"]
        memory=copy.deepcopy(request["provider_memory"]);opaque=memory["opaque_state"]
        m.require(request["descriptor"]==self.profile["descriptor"]
            and request["provider_id"]==memory["provider_id"]==PROVIDER
            and request["expected_provider_version"]==VERSION and request["expected_model_id"]==self.model_id
            and request["expected_model_sha256"]==opaque["model_sha256"]==self.sha
            and request["expected_training_corpus_id"]=="untrained_configured_force_reference"
            and request["expected_training_corpus_sha256"]==digest(core,CORPUS)
            and memory["opaque_state_sha256"]==digest(core,opaque) and memory["weights_mutated"] is False
            and memory["reset_epoch"]==0 and type(step) is int and HANDOFF<=step<1440
            and type(memory["sequence"]) is int and memory["sequence"]==step-HANDOFF
            and opaque["last_step"]==step-1 and request["request_id"]=="force_"+opaque["episode_id"]+"_"+str(step),
            "Force model/memory/episode/clock")
        entries=request["history"]["ordered_entries"]
        m.require(len(entries)==1 and entries[0]["semantic_step"]==step-1,"Force real preceding history")
        if step>HANDOFF:
            m.require(opaque["previous_binding"]==entries[0]["request_sha256"],"Force previous resolved request")
        else:m.require(opaque["previous_binding"] is None and opaque["target_com"] is None
            and opaque["previous_forces"]=={},"Force fresh handoff memory")
        context=request["controller_context"]
        host=context["controller_memory"];packet=host["contact_packet"]
        m.require(context["controller_memory_schema_version"]==host["schema_version"]==CONTEXT
            and context["controller_memory_sha256"]==digest(core,host) and host["profile_sha256"]==self.sha
            and packet["schema_version"]=="locolemotion_prepared_contact_packet_v1"
            and packet["semantic_step"]==step and packet["sample_time_s"]==state["sample_time_s"],
            "Force bound canonical contact context")
        contacts=packet["ordered_contacts"]
        m.require([r["contact_site_id"] for r in contacts]==list(self.sites)
            and all(type(r["presence"]) is bool and type(r["bears_support"]) is bool
                and (not r["bears_support"] or r["presence"]) for r in contacts)
            and [(r["contact_site_id"],r["presence"],r["bears_support"]) for r in contacts]
            ==[(r["contact_site_id"],r["presence"],r["bears_support"]) for r in state["ordered_contact_observations"]],
            "Force current contact population")
        joints=state["ordered_joint_observations"]
        m.require([r["joint_id"] for r in joints]==self.tree.joint_ids
            and all(r["validity"]["position"] is True and r["validity"]["velocity"] is True for r in joints),
            "Force joint observation order/validity")
        q=m.array([r["position_rad"] for r in joints],(8,),"Force position")
        qd=m.array([r["velocity_rad_s"] for r in joints],(8,),"Force velocity")
        pose=state["base_pose_world"];position=m.xyz(pose["position_m"])
        quaternion=m.array([pose["orientation_xyzw"][k] for k in "xyzw"],(4,),"Force orientation")
        frame=self.tree.kinematics(position,quaternion,q);com=frame["whole_body_com"]
        velocity=m.xyz(state["base_twist_world"]["linear_velocity_m_s"])
        angular=m.xyz(state["base_twist_world"]["angular_velocity_rad_s"])
        gravity=m.xyz(state["gravity_world_m_s2"])
        m.require(np.array_equal(gravity,[0.,-9.8,0.]),"Force declared flat gravity domain")
        body_velocities=[]
        for name,center in zip(self.tree.body_ids,frame["centers"],strict=True):
            jac,_=self.tree.jacobian(frame,name,center)
            body_velocities.append(velocity+np.cross(angular,center-position)+jac @ qd)
        com_velocity=np.average(body_velocities,axis=0,weights=self.tree.mass)
        target=np.array([com[0],self.height,com[2]]) if step==HANDOFF else m.array(opaque["target_com"],(3,),"Force target")
        reaches=self.reach.evaluate(position,quaternion,q)
        reference=support_reference(reaches,{r["contact_site_id"]:r["presence"] and r["bears_support"] for r in contacts},
            float(position[1]),float(com[1]),self.height,float(target[1]),self.profile["reference_parameters"])
        target[1]=reference["target_com_height_m"]
        generalized_velocity=np.r_[velocity,angular,qd]
        items,active=dynamic.tasks(self.dynamics,frame,generalized_velocity,quaternion,contacts,target,
            np.array(reference["reference_joint_positions_rad"])-q,p["dynamic"])
        baseline=request["deterministic_baseline"]["ordered_commands"]
        limits=request["safety_envelope"]["ordered_actuator_limits"]
        m.require([r["actuator_id"] for r in baseline]==[r["actuator_id"] for r in limits]==self.actuators
            and all(r["maximum_absolute_correction_rad_s"]==p["maximum_absolute_correction_rad_s"]
                and r["maximum_slew_per_step_rad_s"]==p["maximum_slew_per_command_rad_s"] for r in limits)
            and [r["previous_applied_correction_rad_s"] for r in limits]
                ==[r["canonical_velocity_delta_rad_s"] for r in entries[0]["ordered_applied_corrections"]],
            "Force immutable limits and actual preceding corrections")
        envelope=m.command_envelope([r["combined_canonical_target_velocity_rad_s"] for r in baseline],
            [r["maximum_target_speed_rad_s"] for r in baseline],
            [r["previous_applied_correction_rad_s"] for r in limits],
            [r["maximum_absolute_correction_rad_s"] for r in limits],[r["maximum_slew_per_step_rad_s"] for r in limits])
        base=constraints.build(self.dynamics,frame,generalized_velocity,gravity,q,self.joint_ranges,
            items,active,envelope,self.gains,self.ranges,"combined")
        result=hierarchy.compute(base)
        if not result["accepted"]:
            raise HierarchyRefusal(dict(step=step,profile_sha256=self.sha,request_sha256=digest(core,request),
                allocation=result,active_contacts=[r["contact_site_id"] for r in active],target_com=target,
                support_reference=reference,physical_acceptance_authority=False))
        prediction=result["prediction"];target_velocity=prediction["target"]
        correction,transferred=m.resolve_correction(envelope,prediction["correction"])
        m.require(np.max(np.abs(transferred-target_velocity))<=1e-12,"Hierarchy exact held-target transfer")
        torque=m.motor_torque(transferred,qd,self.gains,self.ranges);lower,upper=m.torque_envelope(envelope,qd,self.gains,self.ranges)
        projected=dict(proposal=correction,target=transferred,requested_torque=torque,predicted_torque=torque,
            lower_torque=lower,upper_torque=upper,torque_error=np.zeros(8),
            scope="original selected held velocity target",held_interval_force_guaranteed=False)
        acc=prediction["predicted_steps"][0]["acceleration"];forces=prediction["predicted_forces"]
        damping=np.where(prediction["pattern"][0]==0,self.gains,0.)
        residual=(base["mass"]+np.diag(np.r_[np.zeros(6),damping])/600.) @ acc
        residual+=base["bias"]-base["passive"]-base["contact"].T @ forces.reshape(-1)-base["selector"] @ torque
        m.require(np.max(np.abs(residual))<=4e-6,"Hierarchy transferred implicit equations")
        result.update(requested_torque=torque,forces=forces,acceleration=acc,
            transferred_dynamics_residual=residual,dynamic_feasibility_established=False)
        request_sha=digest(core,request)
        opaque.update(last_step=step,target_com=target.tolist(),
            previous_forces={r["contact_site_id"]:f.tolist() for r,f in zip(active,result["forces"],strict=True)},
            previous_binding=request_sha)
        memory.update(sequence=step-HANDOFF+1,opaque_state_sha256=digest(core,opaque))
        no_actuation=request["deterministic_baseline"]["safe_no_actuation"]
        response=dict(schema_version="sporespore_adaptation_provider_response_v1",request_id=request["request_id"],
            request_sha256=request_sha,status="no_proposal" if no_actuation else "applied",confidence=1.,support_distance=0.,
            ordered_corrections=[] if no_actuation else [dict(actuator_id=a,canonical_velocity_delta_rad_s=float(v))
                for a,v in zip(self.actuators,projected["proposal"],strict=True)],next_memory=memory,
            provenance=dict(provider_id=PROVIDER,provider_version=VERSION,model_id=self.model_id,model_sha256=self.sha,
                training_corpus_id=request["expected_training_corpus_id"],training_corpus_sha256=request["expected_training_corpus_sha256"],
                seed=request["seed"],engine_specific_logic_used=False,direct_world_access_used=False,weights_mutated=False,
                physical_acceptance_authority=False),candidate_experience=None,
            diagnostics=["untrained configured-capability reference; confidence is permission, not probability",
                "contact-first hierarchy within selected saturation pattern; nonzero support error and frozen hold assumptions remain explicit"],physical_acceptance_authority=False)
        return response,plain(dict(step=step,profile_sha256=self.sha,target_com=target,com=com,com_velocity=com_velocity,
            active_contacts=[r["contact_site_id"] for r in active],allocation=result,projection=projected,
            support_reach=reaches,support_reference=reference,projection_applies_to_transfer=not no_actuation,
            current_solve_force_consumed=False,capability_estimated=False,reentry_permitted=False))
