"""Configured predictor from explicit canonical model data and observations.

Adapter-specific parsing is outside this module. The declared soft-contact law
is a finite configured approximation, not an engine-equivalence guarantee.
The inherited numerical routines use a fixed z-up computational basis; that
basis is independent of any engine identity in the caller's descriptor.
"""
import copy
import json
import numpy as np
from actuation_recovery_mechanics import array,xyz,require,quaternion_rotation
from floating_base_dynamics import FloatingDynamics
from held_dynamics_diagnostic_v2 import state
from held_contact_rollout import HeldContactRollout,C
from predictive_numeric_backend import Kernels,KernelDynamics,KernelContactPredictor
from predictive_command_selection_v2 import PredictiveSelector
from dynamic_inverse_dynamics_v2 import parameters as task_parameters

SCHEMA="locolemotion_prepared_predictive_model_v1"
FRAME="right_handed_x_forward_y_up_z_right_si_v1"


def law():
    # Every supported coefficient/convention is explicit. A different law needs
    # a distinct implementation and prospective validation, not silent defaults.
    return dict(step_seconds=1/600.,held_steps=5,gravity_world_m_s2=[0.,-9.8,0.],
        surface_friction=.95,impedance_minimum=.9,impedance_maximum=.95,
        impedance_width_m=.001,impedance_midpoint=.5,impedance_power=2,
        reference_time_s=.02,damping_ratio=1.,contact_margin_m=0.,
        maximum_contacts=32,maximum_box_contacts=4,maximum_target_speed_rad_s=3.5,
        inverse_weight="constant_reference_pose_diagonal_and_mean_point_trace",
        force_problem="strictly_convex_acceleration_regularization_circular_cones",
        motor_derivative="implicit_unsaturated_velocity_gain",
        integration="semi_implicit_translation_hinge_body_local_quaternion",
        geometry="ground_plane_origin_centered_box_symmetric_capsules")


def validate_model(value):
    require(set(value)=={"schema_version","coordinate_frame_id","law","morphology_spec",
        "joint_inertia_kg_m2","velocity_gains","force_ranges","reference_position_m",
        "ordered_geometry"},"Prepared model fields")
    require(value["schema_version"]==SCHEMA and value["coordinate_frame_id"]==FRAME,
        "Prepared model frame/schema")
    require(json.dumps(value["law"],sort_keys=True,allow_nan=False)==
        json.dumps(law(),sort_keys=True,allow_nan=False),"Prepared explicit supported law")
    model=FloatingDynamics(value["morphology_spec"],value["joint_inertia_kg_m2"])
    require(model.n==8 and np.all(model.damping==0),"Prepared eight-joint zero passive damping")
    gains=array(value["velocity_gains"],(8,),"Prepared gains")
    ranges=array(value["force_ranges"],(8,2),"Prepared motor bounds")
    require(np.all(gains>0) and np.all(ranges[:,0]<0) and np.all(ranges[:,1]>0),
        "Prepared motor domain")
    reference=array(value["reference_position_m"],(3,),"Prepared reference root")
    require(reference[1]>0,"Prepared positive reference height")
    geometry=value["ordered_geometry"]
    require(isinstance(geometry,list) and len(geometry)==9
        and [g["body_id"] for g in geometry]==model.tree.body_ids,"Prepared geometry body order")
    for i,g in enumerate(geometry):
        if i==0:
            require(set(g)=={"body_id","kind","halfsize_m"} and g["kind"]=="box",
                "Prepared root box fields")
            require(np.all(array(g["halfsize_m"],(3,),"Prepared halfsize")>0),"Prepared positive halfsize")
        else:
            require(set(g)=={"body_id","kind","radius_m","endpoints_local_m"} and g["kind"]=="capsule",
                "Prepared limb capsule fields")
            radius=array([g["radius_m"]],(1,),"Prepared radius")[0]
            ends=array(g["endpoints_local_m"],(2,3),"Prepared endpoints")
            require(radius>0 and np.all(ends[:,[0,2]]==0) and ends[0,1]>0
                and ends[1,1]==-ends[0,1],"Prepared symmetric local y capsule")
    return model


class PreparedContact(KernelContactPredictor):
    def __init__(self,prepared,kernels):
        model=validate_model(prepared)
        self.kernels=kernels
        self.gains=np.array(prepared["velocity_gains"])
        self.ranges=np.array(prepared["force_ranges"])
        self.limits=np.array([[j["lower_limit_rad"],j["upper_limit_rad"]] for j in model.tree.joints])
        self.body_names=["world"]+model.tree.body_ids
        self.geom_bodies=self.body_names.copy()
        # These weights are calculated from the declared model's reference
        # pose. They are not current or future measured simulator forces.
        q=np.r_[C.T @ prepared["reference_position_m"],1.,0.,0.,0.,np.zeros(8)]
        zero=state(model,q,np.zeros(14));inverse=np.linalg.inv(zero["mass"])
        self.dof_weight=np.diag(inverse)[6:]
        self.body_weight={"world":0.}
        for i,body in enumerate(model.tree.body_ids):
            jac=model.jacobians(zero["frame"],body,zero["frame"]["centers"][i])[0] @ zero["t"].T
            self.body_weight[body]=float(np.trace(jac @ inverse @ jac.T)/3.)
        self.model=KernelDynamics(prepared["morphology_spec"],prepared["joint_inertia_kg_m2"],kernels)


class PreparedRollout(HeldContactRollout):
    def __init__(self,prepared,kernels):
        self.contact_model=PreparedContact(prepared,kernels);self.model=self.contact_model.model
        self.geometry=[]
        for i,g in enumerate(prepared["ordered_geometry"]):
            shape=dict(kind=g["kind"],geom_id=i+1,body_id=g["body_id"])
            if g["kind"]=="box":shape["size"]=np.abs(C.T @ g["halfsize_m"])
            else:shape.update(radius=g["radius_m"],endpoints=np.array(g["endpoints_local_m"]) @ C)
            self.geometry.append(shape)


def canonical_packet(observation,commands,joint_ids):
    """Use canonical public state only; reject missing validity and clock joins."""
    require(set(commands)=={"baseline","speeds","previous_correction","nominal_correction",
        "target_com","reference_joints","command"},"Prepared command fields")
    step=commands["command"]
    require(type(step) is int and type(observation["semantic_step"]) is int
        and step==observation["semantic_step"],"Prepared observation clock")
    require(type(observation["sample_time_s"]) in (int,float)
        and abs(observation["sample_time_s"]-step/120.)<=1e-10,"Prepared observation time")
    require(np.array_equal(xyz(observation["gravity_world_m_s2"]),[0.,-9.8,0.]),
        "Prepared observation gravity")
    joints=observation["ordered_joint_observations"]
    require([j["joint_id"] for j in joints]==joint_ids and all(
        j["validity"]["position"] is True and j["validity"]["velocity"] is True for j in joints),
        "Prepared ordered valid joints")
    pose=observation["base_pose_world"];position=xyz(pose["position_m"])
    orientation=pose["orientation_xyzw"]
    require(set(orientation)==set("xyzw"),"Prepared quaternion fields")
    quat=array([orientation[k] for k in "xyzw"],(4,),"Prepared quaternion")
    rotation=quaternion_rotation(quat);twist=observation["base_twist_world"]
    q=np.r_[C.T @ position,quat[3],C.T @ quat[:3],[j["position_rad"] for j in joints]]
    v=np.r_[C.T @ xyz(twist["linear_velocity_m_s"]),
        C.T @ rotation.T @ xyz(twist["angular_velocity_rad_s"]),[j["velocity_rad_s"] for j in joints]]
    return dict(copy.deepcopy(commands),qpos=q.tolist(),qvel=v.tolist())


class PreparedSelector(PredictiveSelector):
    def __init__(self,prepared,path,digest):
        self.prepared=copy.deepcopy(prepared)
        validate_model(self.prepared)
        self.kernels=Kernels(path,digest);self.rollout=PreparedRollout(self.prepared,self.kernels)
        self.model=self.rollout.contact_model.model;self.limits=self.rollout.contact_model.limits
        self.p=task_parameters()

    def select_canonical(self,observation,commands):
        value=canonical_packet(observation,commands,self.model.tree.joint_ids)
        return self.select(value)
