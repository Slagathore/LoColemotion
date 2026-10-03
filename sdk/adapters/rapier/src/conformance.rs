// This module is an exact-byte R23D62 dependency and remains LF-stable.
use rapier3d::prelude::*;
use serde_json::{Value, json};

use crate::{
    ADAPTER_ID, RAPIER_DT_S, active_configuration::new_active_world, capability_manifest,
    capability_manifest_sha256,
};

fn configured_world(gravity: Vector) -> PhysicsWorld {
    new_active_world(gravity)
}

fn check(condition: bool, failure_code: &str) -> Result<(), String> {
    condition
        .then_some(())
        .ok_or_else(|| failure_code.to_owned())
}

fn finite_vector(value: Vector) -> bool {
    value.x.is_finite() && value.y.is_finite() && value.z.is_finite()
}

fn c2_kinematic_fixture() -> Result<Value, String> {
    let mut world = configured_world(Vector::ZERO);
    let expected_translation = Vector::new(1.25, 2.5, -3.75);
    let expected_linear_velocity = Vector::new(0.125, -0.25, 0.5);
    let observed_body = world.insert_body(
        RigidBodyBuilder::dynamic()
            .translation(expected_translation)
            .linvel(expected_linear_velocity)
            .angvel(Vector::new(0.25, -0.5, 0.75))
            .additional_mass(1.0),
    );
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let child = world.insert_body(
        RigidBodyBuilder::dynamic()
            .translation(Vector::new(0.0, -0.5, 0.0))
            .additional_mass(1.0),
    );
    let anchor1 = Vector::new(0.0, -0.25, 0.0);
    let anchor2 = Vector::new(0.0, 0.25, 0.0);
    let limits = [-0.6, 0.8];
    let joint = world.insert_impulse_joint(
        parent,
        child,
        RevoluteJointBuilder::new(Vector::X)
            .local_anchor1(anchor1)
            .local_anchor2(anchor2)
            .limits(limits),
    );

    let observed = &world.bodies[observed_body];
    check(
        (observed.translation() - expected_translation).length() <= 1.0e-6,
        "RAPIER_C2_TRANSLATION_MAPPING_MISMATCH",
    )?;
    check(
        (observed.linvel() - expected_linear_velocity).length() <= 1.0e-6,
        "RAPIER_C2_LINEAR_VELOCITY_MAPPING_MISMATCH",
    )?;
    check(
        finite_vector(observed.angvel()),
        "RAPIER_C2_ANGULAR_VELOCITY_NONFINITE",
    )?;

    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "RAPIER_C2_REVOLUTE_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "RAPIER_C2_REVOLUTE_TYPE_MISMATCH".to_owned())?;
    check(
        (revolute.local_anchor1() - anchor1).length() <= 1.0e-6
            && (revolute.local_anchor2() - anchor2).length() <= 1.0e-6,
        "RAPIER_C2_JOINT_ANCHOR_MAPPING_MISMATCH",
    )?;
    let observed_limits = revolute
        .limits()
        .ok_or_else(|| "RAPIER_C2_JOINT_LIMIT_MISSING".to_owned())?;
    check(
        (observed_limits.min - limits[0]).abs() <= 1.0e-6
            && (observed_limits.max - limits[1]).abs() <= 1.0e-6,
        "RAPIER_C2_JOINT_LIMIT_MAPPING_MISMATCH",
    )?;

    let parent_anchor_world = world.bodies[parent]
        .position()
        .transform_point(revolute.local_anchor1());
    let child_anchor_world = world.bodies[child]
        .position()
        .transform_point(revolute.local_anchor2());
    let anchor_error_m = (parent_anchor_world - child_anchor_world).length();
    check(anchor_error_m <= 1.0e-6, "RAPIER_C2_INITIAL_ANCHOR_ERROR")?;

    Ok(json!({
        "ok": true,
        "cell": "c2_kinematic",
        "body_pose_twist_roundtrip_error": {
            "translation_m": (observed.translation() - expected_translation).length(),
            "linear_velocity_m_s": (observed.linvel() - expected_linear_velocity).length(),
        },
        "joint": {
            "kind": "revolute",
            "axis": [1.0, 0.0, 0.0],
            "limits_rad": limits,
            "initial_anchor_error_m": anchor_error_m,
        },
        "coordinate_mapping": "identity_x_forward_y_up_z_right",
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

fn c3_passive_dynamics_fixture() -> Result<Value, String> {
    let gravity_y = -9.8;
    let mut fall_world = configured_world(Vector::new(0.0, gravity_y, 0.0));
    let initial_height_m = 10.0;
    let falling = fall_world.insert_body(
        RigidBodyBuilder::dynamic()
            .translation(Vector::new(0.0, initial_height_m, 0.0))
            .additional_mass(1.0),
    );
    for _ in 0..120 {
        fall_world.step();
    }
    let fall_body = &fall_world.bodies[falling];
    let final_vertical_velocity_m_s = fall_body.linvel().y;
    let final_height_m = fall_body.translation().y;
    let expected_velocity_m_s = gravity_y;
    let elapsed_s = 120.0 * RAPIER_DT_S;
    let expected_ballistic_height_m = initial_height_m + 0.5 * gravity_y * elapsed_s * elapsed_s;
    check(
        (final_vertical_velocity_m_s - expected_velocity_m_s).abs() <= 2.0e-4,
        "RAPIER_C3_FREE_FALL_VELOCITY_MISMATCH",
    )?;
    if (final_height_m - expected_ballistic_height_m).abs() > 5.0e-3 {
        return Err(format!(
            "RAPIER_C3_FREE_FALL_POSITION_MISMATCH: observed={final_height_m:.9}, \
             expected_ballistic={expected_ballistic_height_m:.9}"
        ));
    }

    let mut damping_world = configured_world(Vector::ZERO);
    let damped = damping_world.insert_body(
        RigidBodyBuilder::dynamic()
            .linvel(Vector::new(1.0, 0.0, 0.0))
            .linear_damping(1.0)
            .additional_mass(1.0),
    );
    for _ in 0..120 {
        damping_world.step();
    }
    let final_damped_speed_m_s = damping_world.bodies[damped].linvel().length();
    check(
        final_damped_speed_m_s > 0.0 && final_damped_speed_m_s < 0.5,
        "RAPIER_C3_DAMPING_RESPONSE_INVALID",
    )?;

    Ok(json!({
        "ok": true,
        "cell": "c3_passive_dynamics",
        "free_fall": {
            "steps": 120,
            "duration_s": 120.0 * RAPIER_DT_S,
            "gravity_y_m_s2": gravity_y,
            "final_height_m": final_height_m,
            "expected_ballistic_height_m": expected_ballistic_height_m,
            "absolute_ballistic_height_error_m":
                (final_height_m - expected_ballistic_height_m).abs(),
            "final_vertical_velocity_m_s": final_vertical_velocity_m_s,
        },
        "linear_damping": {
            "coefficient_per_s": 1.0,
            "initial_speed_m_s": 1.0,
            "final_speed_m_s": final_damped_speed_m_s,
        },
        "world_build_count": 2,
        "physical_acceptance_authority": false,
    }))
}

fn maximum_impulse_to_motor_max_force(maximum_impulse_nms: f64, dt_s: f64) -> Result<f32, String> {
    check(
        maximum_impulse_nms.is_finite() && maximum_impulse_nms >= 0.0,
        "RAPIER_C4_MAXIMUM_IMPULSE_INVALID",
    )?;
    check(dt_s.is_finite() && dt_s > 0.0, "RAPIER_C4_TIMESTEP_INVALID")?;
    let force = maximum_impulse_nms / dt_s;
    check(
        force.is_finite() && force <= f32::MAX as f64,
        "RAPIER_C4_MAXIMUM_FORCE_UNREPRESENTABLE",
    )?;
    Ok(force as f32)
}

fn c4_actuator_fixture() -> Result<Value, String> {
    let maximum_impulse_nms = 0.25;
    let maximum_motor_force_nm =
        maximum_impulse_to_motor_max_force(maximum_impulse_nms, RAPIER_DT_S as f64)?;
    let target_position_rad = 0.4;
    let target_velocity_rad_s = 0.0;
    let stiffness = 40.0;
    let damping = 10.0;

    let mut world = configured_world(Vector::ZERO);
    let parent = world.insert_body(RigidBodyBuilder::fixed());
    let (child, _child_collider) = world.insert(
        RigidBodyBuilder::dynamic().additional_mass(1.0),
        ColliderBuilder::cuboid(0.2, 0.2, 0.2),
    );
    let joint = world.insert_impulse_joint(
        parent,
        child,
        RevoluteJointBuilder::new(Vector::X)
            .motor(
                target_position_rad,
                target_velocity_rad_s,
                stiffness,
                damping,
            )
            .motor_model(MotorModel::ForceBased)
            .motor_max_force(maximum_motor_force_nm),
    );

    let mut maximum_observed_motor_impulse_nms = 0.0_f32;
    for _ in 0..240 {
        world.step();
        let revolute = world
            .impulse_joints
            .get(joint)
            .ok_or_else(|| "RAPIER_C4_REVOLUTE_JOINT_MISSING".to_owned())?
            .data
            .as_revolute()
            .ok_or_else(|| "RAPIER_C4_REVOLUTE_TYPE_MISMATCH".to_owned())?;
        let motor = revolute
            .motor()
            .ok_or_else(|| "RAPIER_C4_MOTOR_MISSING".to_owned())?;
        check(
            motor.model == MotorModel::ForceBased,
            "RAPIER_C4_MOTOR_MODEL_MISMATCH",
        )?;
        maximum_observed_motor_impulse_nms =
            maximum_observed_motor_impulse_nms.max(motor.impulse.abs());
        check(
            motor.impulse.abs() <= maximum_impulse_nms as f32 + 1.0e-6,
            "RAPIER_C4_PER_STEP_IMPULSE_LIMIT_EXCEEDED",
        )?;
    }
    let revolute = world
        .impulse_joints
        .get(joint)
        .ok_or_else(|| "RAPIER_C4_REVOLUTE_JOINT_MISSING".to_owned())?
        .data
        .as_revolute()
        .ok_or_else(|| "RAPIER_C4_REVOLUTE_TYPE_MISMATCH".to_owned())?;
    let final_angle_rad = revolute.angle(
        &world.bodies[parent].position().rotation,
        &world.bodies[child].position().rotation,
    );
    let motor = revolute
        .motor()
        .ok_or_else(|| "RAPIER_C4_MOTOR_MISSING".to_owned())?;
    check(
        motor.model == MotorModel::ForceBased
            && (motor.max_force - maximum_motor_force_nm).abs() <= 1.0e-6,
        "RAPIER_C4_MOTOR_FORCE_MAPPING_MISMATCH",
    )?;
    if (final_angle_rad - target_position_rad).abs() > 0.02 {
        return Err(format!(
            "RAPIER_C4_POSITION_MOTOR_TRACKING_MISMATCH: observed={final_angle_rad:.9}, \
             target={target_position_rad:.9}, max_impulse={maximum_observed_motor_impulse_nms:.9}"
        ));
    }

    Ok(json!({
        "ok": true,
        "cell": "c4_actuator",
        "motor_model": "rapier_revolute_position_velocity_force_based",
        "motor_model_readback": "ForceBased",
        "target_position_rad": target_position_rad,
        "target_velocity_rad_s": target_velocity_rad_s,
        "final_position_rad": final_angle_rad,
        "maximum_impulse_nms": maximum_impulse_nms,
        "mapped_maximum_motor_force_nm": maximum_motor_force_nm,
        "maximum_observed_motor_impulse_nms": maximum_observed_motor_impulse_nms,
        "mapping_rule": "max_force_nm = maximum_impulse_nms / dt_s",
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

fn c5_contact_fixture() -> Result<Value, String> {
    let authored_ground_friction = 0.6;
    let authored_body_friction = 0.4;
    let authored_ground_restitution = 0.1;
    let authored_body_restitution = 0.2;

    let mut world = configured_world(Vector::new(0.0, -9.8, 0.0));
    let (_ground_body, ground_collider) = world.insert(
        RigidBodyBuilder::fixed().translation(Vector::new(0.0, -0.1, 0.0)),
        ColliderBuilder::cuboid(5.0, 0.1, 5.0)
            .friction(authored_ground_friction)
            .friction_combine_rule(CoefficientCombineRule::Min)
            .restitution(authored_ground_restitution)
            .restitution_combine_rule(CoefficientCombineRule::Min),
    );
    let (body_handle, body_collider) = world.insert(
        RigidBodyBuilder::dynamic()
            .translation(Vector::new(0.0, 0.49, 0.0))
            .additional_mass(1.0),
        ColliderBuilder::ball(0.5)
            .friction(authored_body_friction)
            .friction_combine_rule(CoefficientCombineRule::Min)
            .restitution(authored_body_restitution)
            .restitution_combine_rule(CoefficientCombineRule::Min),
    );
    for _ in 0..8 {
        world.step();
    }
    let pair = world
        .contact_pair(ground_collider, body_collider)
        .ok_or_else(|| "RAPIER_C5_CONTACT_PAIR_MISSING".to_owned())?;
    check(
        pair.has_any_active_contact(),
        "RAPIER_C5_CONTACT_NOT_ACTIVE",
    )?;
    let manifold = pair
        .manifolds
        .iter()
        .find(|manifold| !manifold.data.solver_contacts.is_empty())
        .ok_or_else(|| "RAPIER_C5_SOLVER_MANIFOLD_MISSING".to_owned())?;
    let solver_contact = manifold
        .data
        .solver_contacts
        .first()
        .ok_or_else(|| "RAPIER_C5_SOLVER_CONTACT_MISSING".to_owned())?;
    check(
        finite_vector(solver_contact.point) && finite_vector(manifold.data.normal),
        "RAPIER_C5_CONTACT_GEOMETRY_NONFINITE",
    )?;
    check(
        (manifold.data.normal.length() - 1.0).abs() <= 1.0e-5,
        "RAPIER_C5_CONTACT_NORMAL_NOT_UNIT",
    )?;
    check(
        (solver_contact.friction - authored_body_friction).abs() <= 1.0e-6,
        "RAPIER_C5_EFFECTIVE_FRICTION_MISMATCH",
    )?;
    check(
        (solver_contact.restitution - authored_ground_restitution).abs() <= 1.0e-6,
        "RAPIER_C5_EFFECTIVE_RESTITUTION_MISMATCH",
    )?;
    let body_velocity_at_contact =
        world.bodies[body_handle].velocity_at_point(solver_contact.point);
    check(
        finite_vector(body_velocity_at_contact),
        "RAPIER_C5_RELATIVE_VELOCITY_NONFINITE",
    )?;
    let raw_pair_impulse_nms = pair.total_impulse_magnitude();
    check(
        raw_pair_impulse_nms.is_finite() && raw_pair_impulse_nms > 0.0,
        "RAPIER_C5_RAW_IMPULSE_UNAVAILABLE",
    )?;

    Ok(json!({
        "ok": true,
        "cell": "c5_contact",
        "contact": {
            "presence": true,
            "point_world_m": [
                solver_contact.point.x,
                solver_contact.point.y,
                solver_contact.point.z,
            ],
            "normal_world_unit": [
                manifold.data.normal.x,
                manifold.data.normal.y,
                manifold.data.normal.z,
            ],
            "body_velocity_at_contact_world_m_s": [
                body_velocity_at_contact.x,
                body_velocity_at_contact.y,
                body_velocity_at_contact.z,
            ],
            "raw_pair_impulse_nms": raw_pair_impulse_nms,
            "raw_impulse_is_not_per_foot_load": true,
            "normal_load_n": Value::Null,
        },
        "material": {
            "ground_authored_friction": authored_ground_friction,
            "body_authored_friction": authored_body_friction,
            "combine_rule": "min",
            "effective_solver_friction": solver_contact.friction,
            "ground_authored_restitution": authored_ground_restitution,
            "body_authored_restitution": authored_body_restitution,
            "effective_solver_restitution": solver_contact.restitution,
            "breakaway_characterized": false,
            "steady_slide_characterized": false,
        },
        "contact_identity": {
            "scope": "per_step_collider_pair_and_manifold_contact_id",
            "persistent_semantic_contact_identity": false,
        },
        "world_build_count": 1,
        "physical_acceptance_authority": false,
    }))
}

pub fn run_c2_c5_conformance() -> Result<Value, String> {
    let c2 = c2_kinematic_fixture()?;
    let c3 = c3_passive_dynamics_fixture()?;
    let c4 = c4_actuator_fixture()?;
    let c5 = c5_contact_fixture()?;
    Ok(json!({
        "schema_version": "sporespore_rapier_c2_c5_conformance_report_v1",
        "ok": true,
        "adapter_id": ADAPTER_ID,
        "adapter_manifest": capability_manifest(),
        "adapter_manifest_sha256": capability_manifest_sha256(),
        "rapier_version": rapier3d::VERSION,
        "cells": [c2, c3, c4, c5],
        "passed_cells": 4,
        "failed_cells": 0,
        "controller_policy_authority": false,
        "physical_acceptance_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn invalid_impulse_force_mappings_fail_closed() {
        assert!(maximum_impulse_to_motor_max_force(f64::NAN, 1.0 / 120.0).is_err());
        assert!(maximum_impulse_to_motor_max_force(-1.0, 1.0 / 120.0).is_err());
        assert!(maximum_impulse_to_motor_max_force(1.0, 0.0).is_err());
        assert!(maximum_impulse_to_motor_max_force(1.0, f64::NAN).is_err());
    }

    #[test]
    fn exact_per_step_impulse_mapping_uses_the_pinned_timestep() {
        let force = maximum_impulse_to_motor_max_force(0.25, RAPIER_DT_S as f64).unwrap();
        assert!((force * RAPIER_DT_S - 0.25).abs() <= 1.0e-7);
    }
}
