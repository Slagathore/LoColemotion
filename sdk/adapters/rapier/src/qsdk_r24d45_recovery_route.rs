//! Prospective exact-S169 Rapier prone-to-standing development route.
//!
//! The pure functions in this module own the R24D45 morphology binding,
//! canonical prone pose plan, and recovery-command-to-public-profile mapping.
//! The same functions are consumed by the native worker; the qualification
//! entry point deliberately stops before constructing any Rapier object.

use std::collections::{BTreeMap, HashMap};

use rapier3d::prelude::*;
use serde_json::{Value, json};
use sporespore_locomotion_core::protocol::{
    ACTUATION_FRAME_VERSION, ContactObservation, ContactProvenance, ContactQuality,
    ControllerStepReceipt,
};
use sporespore_locomotion_core::schema::{ActuatorMode, CollisionShape, Vec3};
use sporespore_locomotion_core::{
    CANONICAL_PRONE_TO_STANDING_TASK_ID, CanonicalVelocityActuationFrameV1,
    CanonicalVelocityResidualV1, CompiledQuadruped, EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID,
    EXACT_S169_RECOVERY_CONTROLLER_ID, EXACT_S169_STANCE_CONTROLLER_ID,
    LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN, PORTABLE_RECOVERY_SEMANTICS_ID,
    R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID, R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
    RECOVERY_CONTROL_COMMAND_V1_VERSION, RECOVERY_CONTROL_RECEIPT_V1_VERSION,
    RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION, RECOVERY_EVALUATION_REQUEST_V2_VERSION,
    RECOVERY_INITIALIZE_REQUEST_V2_VERSION, RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION,
    RECOVERY_OBSERVATION_V1_VERSION, RECOVERY_OUTER_STEP_DURATION_S,
    RECOVERY_STEP_REQUEST_V2_VERSION, RECOVERY_TRACE_V1_VERSION, RecoveryAppliedActuationReceiptV1,
    RecoveryAppliedActuatorImpulseV1, RecoveryArmKindV1, RecoveryBodyClearanceObservationV1,
    RecoveryCenterOfMassObservationV1, RecoveryControlCommandV1, RecoveryControlReceiptV1,
    RecoveryControllerOwnerV1, RecoveryControllerOwnershipReceiptV1, RecoveryEnergyBalanceLedgerV1,
    RecoveryEngineStepIdentityV1, RecoveryEvaluationReceiptV1, RecoveryEvaluationRequestV2,
    RecoveryEvaluationVerdictV1, RecoveryExternalInterventionLedgerV1,
    RecoveryFootBearingObservationV1, RecoveryInitializeRequestV2, RecoveryMorphologyContextV1,
    RecoveryMorphologyDescriptorV1, RecoveryMorphologyReceiptV1, RecoveryMorphologySupportStatusV1,
    RecoveryNativeEngineV1, RecoveryObservationSourceKindV1, RecoveryObservationV1,
    RecoveryPhaseV1, RecoveryStepRequestV2, RecoverySupervisorMemoryV1, RecoverySupportStatusV1,
    RecoveryTraceV1, VelocityOnlyHostMappingReceiptV1, VelocityOnlyHostProfileV1,
    canonicalize_and_compose_legacy_velocity_v1, compile_bounded_quadruped,
    compile_recovery_morphology_v1, digest_json, digest_serializable, evaluate_recovery_trace_v2,
    initialize_recovery_v2, map_canonical_velocity_to_host_v1, r23d60_selected_s169_descriptor,
    recovery_development_profile_v1, step_recovery_v2,
};

use crate::actuator_cap_profile::{
    RapierPublicActuatorCapBindingV1, resolve_production_public_profile_binding_v1,
};
use crate::bw19v_composition::BW19V_AUTHORED_FRICTION;
use crate::locomotion::{
    HostRobot, build_bw19v_velocity_only_v4_robot_with_public_profile,
    compile_public_profile_actuator_force_plan_v1,
};
use crate::recovery_capability::{RAPIER_RECOVERY_ADAPTER_ID, rapier_recovery_capability_v1};
use crate::recovery_runtime::{
    collect_rapier_native_recovery_observation_v2, plan_rapier_recovery_control_v2,
    plan_rapier_recovery_stance_control_v2, rapier_recovery_collection_request_v2,
};
use crate::velocity_only_live_integration::{
    VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD, update_velocity_only_motor_v1,
    velocity_only_small_step_impulse_limit_v1,
};

const CONTRACT_RAW: &str =
    include_str!("../../../recovery/r24d45_rapier_native_recovery_port_contract_v1.json");
const GATE_ID: &str = "QSDK-R24D45";
const ROUTE_ID: &str = "sporespore_qsdk_r24d45_rapier_native_recovery_route_v1";
const QUALIFICATION_SCHEMA: &str =
    "sporespore_qsdk_r24d45_rapier_native_recovery_route_qualification_v1";
const CELL_ID: &str = "r24d45_rapier_development_nominal";
const CELL_SEED: u32 = 260_226_999;
const OUTER_DT_S: f64 = 1.0 / 120.0;
const BODY_COUNT: usize = 9;
const ACTUATOR_COUNT: usize = 8;
const CONTACT_CLASSIFICATION_TOLERANCE_M: f64 = 1.0e-6;
const INITIALIZER_READBACK_TOLERANCE: f64 = 2.5e-6;
const NATIVE_STEP_SCHEMA: &str = "sporespore_rapier_recovery_native_step_receipt_v1";
const APPLICATION_SCHEMA: &str = "sporespore_rapier_recovery_application_receipt_v1";
const CONTACT_CLASSIFICATION_RULE_ID: &str = "rapier_distal_capsule_lower_cap_contact_v1";
const NONFOOT_CLASSIFICATION_RULE_ID: &str =
    "rapier_collider_surface_excluding_distal_lower_cap_v1";
const RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256: &str =
    "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

#[derive(Clone, Debug, PartialEq)]
pub(crate) struct RapierRecoveryBodyPoseV1 {
    pub(crate) body_id: String,
    pub(crate) translation_m: [f64; 3],
    pub(crate) rotation_about_z_rad: f64,
}

#[derive(Clone, Debug, PartialEq)]
pub(crate) struct RapierRecoveryPronePosePlanV1 {
    pub(crate) ordered_body_poses: Vec<RapierRecoveryBodyPoseV1>,
    pub(crate) ordered_joint_positions_rad: Vec<f64>,
    pub(crate) manifest: Value,
    pub(crate) manifest_sha256: String,
}

pub(crate) struct RapierRecoveryBoundaryV1 {
    pub(crate) compiled: CompiledQuadruped,
    pub(crate) recovery_receipt: RecoveryMorphologyReceiptV1,
    pub(crate) morphology_context: RecoveryMorphologyContextV1,
    pub(crate) public_profile_binding: RapierPublicActuatorCapBindingV1,
}

pub(crate) struct RapierRecoveryMappedActuationV1 {
    pub(crate) actuation: sporespore_locomotion_core::ActuationFrame,
    pub(crate) canonical: CanonicalVelocityActuationFrameV1,
    pub(crate) host_mapping: VelocityOnlyHostMappingReceiptV1,
}

pub(crate) struct RapierRecoveryWorldV1 {
    pub(crate) robot: HostRobot,
    pub(crate) task_origin: Vector,
    pub(crate) initial_mechanical_energy_j: f64,
    pub(crate) cumulative_actuator_work_j: f64,
    pub(crate) host_step_count: u64,
}

pub(crate) struct RapierRecoveryApplicationV1 {
    application: Value,
    application_sha256: String,
    command_id: String,
    command_sha256: String,
    zero_command: bool,
    ordered_applied_impulses: Vec<RecoveryAppliedActuatorImpulseV1>,
    step_actuator_work_j: f64,
}

struct RapierRecoveryContactMeasurementsV1 {
    foot_impulses_ns: BTreeMap<String, f64>,
    foot_contact_ids: BTreeMap<String, Vec<String>>,
    nonfoot_impulses_ns: BTreeMap<String, f64>,
    nonfoot_contact_ids: BTreeMap<String, Vec<String>>,
    minimum_nonfoot_clearance_m: BTreeMap<String, f64>,
    torso_ventral_contact: bool,
}

pub(crate) struct RapierRecoveryNativeStepV1 {
    pub(crate) observation: RecoveryObservationV1,
    pub(crate) observation_sha256: String,
    pub(crate) invariant_receipt: Value,
}

pub(crate) struct RapierRecoveryStepContextV1<'a> {
    pub(crate) arm: RecoveryArmKindV1,
    pub(crate) phase: RecoveryPhaseV1,
    pub(crate) semantic_step: u64,
    pub(crate) previous_observation_sha256: Option<&'a str>,
    pub(crate) runtime_qualification_sha256: &'a str,
}

struct RapierRecoveryArmRunV1 {
    trace: RecoveryTraceV1,
    arm_result: Value,
}

fn finite(value: f64, code: &str) -> Result<f64, String> {
    if value.is_finite() {
        Ok(value)
    } else {
        Err(code.to_owned())
    }
}

fn add(left: [f64; 3], right: [f64; 3]) -> [f64; 3] {
    [left[0] + right[0], left[1] + right[1], left[2] + right[2]]
}

fn sub(left: [f64; 3], right: [f64; 3]) -> [f64; 3] {
    [left[0] - right[0], left[1] - right[1], left[2] - right[2]]
}

fn rotate_z(vector: sporespore_locomotion_core::schema::Vec3, angle: f64) -> [f64; 3] {
    let (sin, cos) = angle.sin_cos();
    [
        cos * vector.x - sin * vector.y,
        sin * vector.x + cos * vector.y,
        vector.z,
    ]
}

fn canonical_vec3(value: Vector) -> Vec3 {
    Vec3 {
        x: value.x as f64,
        y: value.y as f64,
        z: value.z as f64,
    }
}

fn sha256_value(value: &Value, code: &str) -> Result<String, String> {
    digest_json(value).map_err(|error| format!("{code}:{error}"))
}

fn validate_contract() -> Result<Value, String> {
    let contract: Value = serde_json::from_str(CONTRACT_RAW)
        .map_err(|error| format!("QSDK_R24D45_CONTRACT_PARSE:{error}"))?;
    if contract["gate_id"] != GATE_ID
        || contract["question_class"] != "development"
        || contract["scope"]["engine"] != "rapier_parry_native"
        || contract["development_cohort"]["cell_count"] != 1
        || contract["development_cohort"]["cells"][0]["cell_id"] != CELL_ID
        || contract["development_cohort"]["cells"][0]["seed"] != CELL_SEED
        || contract["held_out_seal"]["r17_held_out_access_count"] != 0
        || contract["held_out_seal"]["r17_held_out_selector_invocation_count"] != 0
        || contract["held_out_seal"]["r17_held_out_cells_remain_sealed"] != true
        || contract["threshold_and_margin_provenance"]["r24d45_threshold_change_count"] != 0
        || contract["prospective_physical_budget"]["maximum_outer_steps_per_arm"] != 1200
        || contract["prospective_physical_budget"]["maximum_native_solver_steps_per_outer_step"]
            != 1
    {
        return Err("QSDK_R24D45_CONTRACT_IDENTITY_INVALID".to_owned());
    }
    Ok(contract)
}

pub(crate) fn compile_r24d45_recovery_boundary_v1() -> Result<RapierRecoveryBoundaryV1, String> {
    let base_descriptor = r23d60_selected_s169_descriptor();
    let mut compiled =
        compile_bounded_quadruped(base_descriptor.clone()).map_err(|error| error.to_string())?;
    let recovery_receipt = compile_recovery_morphology_v1(
        RecoveryMorphologyDescriptorV1::exact_s169_reference(base_descriptor),
    )
    .map_err(|error| error.to_string())?;
    if recovery_receipt.support_status != RecoveryMorphologySupportStatusV1::SupportedExact
        || recovery_receipt.refusal_reason.is_some()
        || !recovery_receipt.prone_geometry.feasible
        || recovery_receipt.model_construction_count != 0
        || recovery_receipt.world_attempt_count != 0
        || recovery_receipt.world_build_count != 0
        || recovery_receipt.solver_step_count != 0
        || recovery_receipt.physics_state_modified
        || recovery_receipt.physical_acceptance_authority
        || recovery_receipt.release_authority
    {
        return Err("QSDK_R24D45_RECOVERY_MORPHOLOGY_INVALID".to_owned());
    }
    if recovery_receipt.base_descriptor_sha256 != compiled.descriptor_sha256
        || recovery_receipt.base_morphology_spec_sha256
            != compiled.morphology.morphology_spec_sha256
    {
        return Err("QSDK_R24D45_BASE_MORPHOLOGY_IDENTITY_INVALID".to_owned());
    }
    let morphology_context = RecoveryMorphologyContextV1 {
        schema_version: RECOVERY_MORPHOLOGY_CONTEXT_V1_VERSION.to_owned(),
        recovery_morphology_id: recovery_receipt.recovery_morphology_id.clone(),
        recovery_descriptor: recovery_receipt.descriptor.clone(),
        recovery_descriptor_sha256: recovery_receipt.descriptor_sha256.clone(),
        base_descriptor_sha256: recovery_receipt.base_descriptor_sha256.clone(),
        base_morphology_spec_sha256: recovery_receipt.base_morphology_spec_sha256.clone(),
        recovery_morphology_spec_sha256: recovery_receipt.recovery_morphology_spec_sha256.clone(),
    };
    compiled.morphology = recovery_receipt.morphology.clone();
    let public_profile_binding = resolve_production_public_profile_binding_v1()?;
    let force_plan =
        compile_public_profile_actuator_force_plan_v1(&compiled, &public_profile_binding)?;
    if !force_plan.public_profile_bound || force_plan.ordered_entries.len() != ACTUATOR_COUNT {
        return Err("QSDK_R24D45_PUBLIC_PROFILE_FORCE_PLAN_INVALID".to_owned());
    }
    Ok(RapierRecoveryBoundaryV1 {
        compiled,
        recovery_receipt,
        morphology_context,
        public_profile_binding,
    })
}

fn joint_angle_for_limb(
    semantic_role: &str,
    knee: bool,
    descriptor: &RecoveryMorphologyDescriptorV1,
) -> Result<f64, String> {
    match (semantic_role, knee) {
        ("front_left" | "front_right", false) => {
            Ok(descriptor.canonical_prone_pose.front_hip_angle_rad)
        }
        ("front_left" | "front_right", true) => {
            Ok(descriptor.canonical_prone_pose.front_knee_angle_rad)
        }
        ("rear_left" | "rear_right", false) => {
            Ok(descriptor.canonical_prone_pose.rear_hip_angle_rad)
        }
        ("rear_left" | "rear_right", true) => {
            Ok(descriptor.canonical_prone_pose.rear_knee_angle_rad)
        }
        _ => Err(format!(
            "QSDK_R24D45_PRONE_LIMB_ROLE_INVALID:{semantic_role}"
        )),
    }
}

pub(crate) fn plan_r24d45_canonical_prone_pose_v1(
    boundary: &RapierRecoveryBoundaryV1,
) -> Result<RapierRecoveryPronePosePlanV1, String> {
    let spec = &boundary.compiled.morphology.morphology_spec;
    if spec.bodies.len() != BODY_COUNT
        || spec.joints.len() != ACTUATOR_COUNT
        || spec.limbs.len() != 4
    {
        return Err("QSDK_R24D45_PRONE_TOPOLOGY_INVALID".to_owned());
    }
    let torso_half_height_m = boundary.compiled.geometry.torso_size_m.y / 2.0;
    let mut positions = HashMap::<String, [f64; 3]>::new();
    let mut rotations = HashMap::<String, f64>::new();
    positions.insert("torso".to_owned(), [0.0, torso_half_height_m, 0.0]);
    rotations.insert("torso".to_owned(), 0.0);

    let mut joint_angles = HashMap::<String, f64>::new();
    for limb in &spec.limbs {
        if limb.ordered_joint_ids.len() != 2 {
            return Err(format!("QSDK_R24D45_PRONE_LIMB_SHAPE:{}", limb.limb_id));
        }
        joint_angles.insert(
            limb.ordered_joint_ids[0].clone(),
            joint_angle_for_limb(
                &limb.semantic_role,
                false,
                &boundary.recovery_receipt.descriptor,
            )?,
        );
        joint_angles.insert(
            limb.ordered_joint_ids[1].clone(),
            joint_angle_for_limb(
                &limb.semantic_role,
                true,
                &boundary.recovery_receipt.descriptor,
            )?,
        );
    }

    for joint in &spec.joints {
        let parent_position = *positions.get(&joint.parent_body_id).ok_or_else(|| {
            format!(
                "QSDK_R24D45_PRONE_PARENT_POSITION_MISSING:{}",
                joint.parent_body_id
            )
        })?;
        let parent_rotation = *rotations.get(&joint.parent_body_id).ok_or_else(|| {
            format!(
                "QSDK_R24D45_PRONE_PARENT_ROTATION_MISSING:{}",
                joint.parent_body_id
            )
        })?;
        let joint_angle = *joint_angles
            .get(&joint.joint_id)
            .ok_or_else(|| format!("QSDK_R24D45_PRONE_JOINT_ANGLE_MISSING:{}", joint.joint_id))?;
        if joint_angle < joint.lower_limit_rad || joint_angle > joint.upper_limit_rad {
            return Err(format!("QSDK_R24D45_PRONE_JOINT_LIMIT:{}", joint.joint_id));
        }
        let child_rotation = parent_rotation + joint_angle;
        let child_position = sub(
            add(
                parent_position,
                rotate_z(joint.anchor_parent_m, parent_rotation),
            ),
            rotate_z(joint.anchor_child_m, child_rotation),
        );
        positions.insert(joint.child_body_id.clone(), child_position);
        rotations.insert(joint.child_body_id.clone(), child_rotation);
    }

    let ordered_body_poses = boundary
        .compiled
        .morphology
        .ordered_body_ids
        .iter()
        .map(|body_id| {
            Ok(RapierRecoveryBodyPoseV1 {
                body_id: body_id.clone(),
                translation_m: *positions
                    .get(body_id)
                    .ok_or_else(|| format!("QSDK_R24D45_PRONE_BODY_POSITION_MISSING:{body_id}"))?,
                rotation_about_z_rad: *rotations
                    .get(body_id)
                    .ok_or_else(|| format!("QSDK_R24D45_PRONE_BODY_ROTATION_MISSING:{body_id}"))?,
            })
        })
        .collect::<Result<Vec<_>, String>>()?;
    let ordered_joint_positions_rad = boundary
        .compiled
        .morphology
        .ordered_joint_ids
        .iter()
        .map(|joint_id| {
            joint_angles
                .get(joint_id)
                .copied()
                .ok_or_else(|| format!("QSDK_R24D45_PRONE_ORDERED_JOINT_MISSING:{joint_id}"))
        })
        .collect::<Result<Vec<_>, String>>()?;
    let ordered_pose_json = ordered_body_poses
        .iter()
        .map(|pose| {
            json!({
                "body_id": pose.body_id,
                "translation_m": pose.translation_m,
                "rotation_about_z_rad": pose.rotation_about_z_rad,
                "linear_velocity_m_s": [0.0, 0.0, 0.0],
                "angular_velocity_rad_s": [0.0, 0.0, 0.0],
            })
        })
        .collect::<Vec<_>>();
    let manifest = json!({
        "schema_version": "sporespore_rapier_recovery_initializer_manifest_v1",
        "route_id": ROUTE_ID,
        "initializer_id": "exact_s169_ventral_prone_nominal_v1",
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "recovery_morphology_id": boundary.recovery_receipt.recovery_morphology_id,
        "recovery_descriptor_sha256": boundary.recovery_receipt.descriptor_sha256,
        "recovery_morphology_spec_sha256":
            boundary.recovery_receipt.recovery_morphology_spec_sha256,
        "reference_pose_rule_id":
            boundary.recovery_receipt.prone_geometry.reference_pose_rule_id,
        "ordered_body_poses": ordered_pose_json,
        "ordered_joint_ids": boundary.compiled.morphology.ordered_joint_ids,
        "ordered_joint_positions_rad": ordered_joint_positions_rad,
        "torso_roll_rad": 0.0,
        "direct_body_initialization_write_count": BODY_COUNT,
        "writes_completed_before_first_solver_step": true,
        "post_initialization_root_pose_write_count": 0,
        "post_initialization_root_velocity_write_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    });
    let manifest_sha256 = digest_json(&manifest).map_err(|error| error.to_string())?;
    Ok(RapierRecoveryPronePosePlanV1 {
        ordered_body_poses,
        ordered_joint_positions_rad,
        manifest,
        manifest_sha256,
    })
}

fn mechanical_energy_j(
    robot: &HostRobot,
    boundary: &RapierRecoveryBoundaryV1,
) -> Result<f64, String> {
    let mut total = 0.0_f64;
    for body_id in &boundary.compiled.morphology.ordered_body_ids {
        let handle = robot
            .bodies
            .get(body_id)
            .ok_or_else(|| format!("QSDK_R24D45_ENERGY_BODY_HANDLE_MISSING:{body_id}"))?;
        let body = &robot.world.bodies[*handle];
        let energy = body.kinetic_energy() as f64
            + body.gravitational_potential_energy(
                robot.world.integration_parameters.dt,
                robot.world.gravity,
            ) as f64;
        total += finite(energy, "QSDK_R24D45_MECHANICAL_ENERGY_NONFINITE")?;
    }
    finite(total, "QSDK_R24D45_TOTAL_MECHANICAL_ENERGY_NONFINITE")
}

fn joint_velocity_rad_s(robot: &HostRobot, joint_id: &str) -> Result<f64, String> {
    let handle = robot
        .joints
        .get(joint_id)
        .ok_or_else(|| format!("QSDK_R24D45_JOINT_VELOCITY_HANDLE_MISSING:{joint_id}"))?;
    let joint = robot
        .world
        .impulse_joints
        .get(*handle)
        .ok_or_else(|| format!("QSDK_R24D45_JOINT_VELOCITY_JOINT_MISSING:{joint_id}"))?;
    let parent = &robot.world.bodies[joint.body1()];
    let child = &robot.world.bodies[joint.body2()];
    let axis = parent.rotation() * Vector::Z;
    finite(
        (child.angvel() - parent.angvel()).dot(axis) as f64,
        "QSDK_R24D45_JOINT_VELOCITY_NONFINITE",
    )
}

fn whole_system_center_of_mass(
    robot: &HostRobot,
    boundary: &RapierRecoveryBoundaryV1,
) -> Result<RecoveryCenterOfMassObservationV1, String> {
    let mut total_mass = 0.0_f64;
    let mut weighted_position = Vector::ZERO;
    let mut weighted_velocity = Vector::ZERO;
    for body_id in &boundary.compiled.morphology.ordered_body_ids {
        let handle = robot
            .bodies
            .get(body_id)
            .ok_or_else(|| format!("QSDK_R24D45_COM_BODY_HANDLE_MISSING:{body_id}"))?;
        let body = &robot.world.bodies[*handle];
        let mass = body.mass();
        if !mass.is_finite() || mass <= 0.0 {
            return Err(format!("QSDK_R24D45_COM_BODY_MASS_INVALID:{body_id}"));
        }
        total_mass += mass as f64;
        weighted_position += body.center_of_mass() * mass;
        weighted_velocity += body.linvel() * mass;
    }
    if !total_mass.is_finite() || total_mass <= 0.0 {
        return Err("QSDK_R24D45_COM_TOTAL_MASS_INVALID".to_owned());
    }
    let position = weighted_position / total_mass as f32;
    let velocity = weighted_velocity / total_mass as f32;
    if !position.x.is_finite()
        || !position.y.is_finite()
        || !position.z.is_finite()
        || !velocity.x.is_finite()
        || !velocity.y.is_finite()
        || !velocity.z.is_finite()
    {
        return Err("QSDK_R24D45_COM_READBACK_NONFINITE".to_owned());
    }
    Ok(RecoveryCenterOfMassObservationV1 {
        position_world_m: canonical_vec3(position),
        linear_velocity_world_m_s: canonical_vec3(velocity),
        source_measurement: true,
    })
}

pub(crate) fn build_r24d45_recovery_world_v1(
    boundary: &RapierRecoveryBoundaryV1,
    pose: &RapierRecoveryPronePosePlanV1,
) -> Result<RapierRecoveryWorldV1, String> {
    let mut robot = build_bw19v_velocity_only_v4_robot_with_public_profile(
        &boundary.compiled,
        BW19V_AUTHORED_FRICTION,
        &boundary.public_profile_binding,
    )?;
    if robot.solver_step_count != 0
        || robot.bodies.len() != BODY_COUNT
        || robot.joints.len() != ACTUATOR_COUNT
        || robot.colliders.len() != BODY_COUNT
    {
        return Err("QSDK_R24D45_WORLD_CONSTRUCTION_INVALID".to_owned());
    }
    for planned in &pose.ordered_body_poses {
        let handle = robot
            .bodies
            .get(&planned.body_id)
            .ok_or_else(|| format!("QSDK_R24D45_INITIALIZER_BODY_MISSING:{}", planned.body_id))?;
        let body = &mut robot.world.bodies[*handle];
        body.set_translation(
            Vector::new(
                planned.translation_m[0] as f32,
                planned.translation_m[1] as f32,
                planned.translation_m[2] as f32,
            ),
            true,
        );
        body.set_rotation(
            Rotation::from_rotation_z(planned.rotation_about_z_rad as f32),
            true,
        );
        body.set_linvel(Vector::ZERO, true);
        body.set_angvel(Vector::ZERO, true);
        body.reset_forces(true);
        body.reset_torques(true);
    }
    robot
        .world
        .bodies
        .propagate_modified_body_positions_to_colliders(&mut robot.world.colliders);

    for planned in &pose.ordered_body_poses {
        let body = &robot.world.bodies[robot.bodies[&planned.body_id]];
        let expected_translation = Vector::new(
            planned.translation_m[0] as f32,
            planned.translation_m[1] as f32,
            planned.translation_m[2] as f32,
        );
        let expected_rotation = Rotation::from_rotation_z(planned.rotation_about_z_rad as f32);
        let actual_rotation = body.rotation();
        let direct_rotation_error = ((actual_rotation.x - expected_rotation.x).powi(2)
            + (actual_rotation.y - expected_rotation.y).powi(2)
            + (actual_rotation.z - expected_rotation.z).powi(2)
            + (actual_rotation.w - expected_rotation.w).powi(2))
        .sqrt() as f64;
        let negated_rotation_error = ((actual_rotation.x + expected_rotation.x).powi(2)
            + (actual_rotation.y + expected_rotation.y).powi(2)
            + (actual_rotation.z + expected_rotation.z).powi(2)
            + (actual_rotation.w + expected_rotation.w).powi(2))
        .sqrt() as f64;
        if (body.translation() - expected_translation).length() as f64
            > INITIALIZER_READBACK_TOLERANCE
            || direct_rotation_error.min(negated_rotation_error) > INITIALIZER_READBACK_TOLERANCE
            || body.linvel().length() as f64 > INITIALIZER_READBACK_TOLERANCE
            || body.angvel().length() as f64 > INITIALIZER_READBACK_TOLERANCE
        {
            return Err(format!(
                "QSDK_R24D45_INITIALIZER_BODY_READBACK_MISMATCH:{}",
                planned.body_id
            ));
        }
    }
    for (index, joint_id) in boundary
        .compiled
        .morphology
        .ordered_joint_ids
        .iter()
        .enumerate()
    {
        let readback = robot.joint_angle(joint_id)?;
        if (readback - pose.ordered_joint_positions_rad[index]).abs()
            > INITIALIZER_READBACK_TOLERANCE
        {
            return Err(format!(
                "QSDK_R24D45_INITIALIZER_JOINT_READBACK_MISMATCH:{joint_id}"
            ));
        }
    }
    let task_origin = robot.world.bodies[robot.bodies["torso"]].translation();
    let initial_mechanical_energy_j = mechanical_energy_j(&robot, boundary)?;
    Ok(RapierRecoveryWorldV1 {
        robot,
        task_origin,
        initial_mechanical_energy_j,
        cumulative_actuator_work_j: 0.0,
        host_step_count: 0,
    })
}

fn distal_nonfoot_clearance_m(
    robot: &HostRobot,
    body_id: &str,
    contact_site: &sporespore_locomotion_core::schema::ContactSiteSpec,
    collision: &CollisionShape,
) -> Result<f64, String> {
    let CollisionShape::Capsule { radius_m, length_m } = collision else {
        return Err(format!("QSDK_R24D45_DISTAL_SHAPE_INVALID:{body_id}"));
    };
    let body = &robot.world.bodies[robot.bodies[body_id]];
    let lower_center = body.position().transform_point(Vector::new(
        contact_site.local_center_m.x as f32,
        contact_site.local_center_m.y as f32,
        contact_site.local_center_m.z as f32,
    ));
    let axis_world = body.rotation() * Vector::Y;
    let upper_center = lower_center + axis_world * *length_m as f32;
    let axis_y = axis_world.y as f64;
    let radial_vertical = *radius_m * (1.0 - axis_y * axis_y).max(0.0).sqrt();
    let lower_seam_y = lower_center.y as f64 - radial_vertical;
    let upper_cap_y = upper_center.y as f64 - *radius_m;
    finite(
        lower_seam_y.min(upper_cap_y),
        "QSDK_R24D45_DISTAL_NONFOOT_CLEARANCE_NONFINITE",
    )
}

fn measure_r24d45_contacts_v1(
    robot: &HostRobot,
    boundary: &RapierRecoveryBoundaryV1,
    semantic_step: u64,
) -> Result<RapierRecoveryContactMeasurementsV1, String> {
    let spec = &boundary.compiled.morphology.morphology_spec;
    let mut foot_impulses_ns = boundary
        .compiled
        .morphology
        .ordered_contact_site_ids
        .iter()
        .map(|id| (id.clone(), 0.0))
        .collect::<BTreeMap<_, _>>();
    let mut foot_contact_ids = boundary
        .compiled
        .morphology
        .ordered_contact_site_ids
        .iter()
        .map(|id| (id.clone(), Vec::new()))
        .collect::<BTreeMap<_, _>>();
    let mut nonfoot_impulses_ns = boundary
        .compiled
        .morphology
        .ordered_body_ids
        .iter()
        .map(|id| (id.clone(), 0.0))
        .collect::<BTreeMap<_, _>>();
    let mut nonfoot_contact_ids = boundary
        .compiled
        .morphology
        .ordered_body_ids
        .iter()
        .map(|id| (id.clone(), Vec::new()))
        .collect::<BTreeMap<_, _>>();
    let mut minimum_nonfoot_clearance_m = BTreeMap::new();
    let mut torso_ventral_contact = false;
    let torso_half_height_m = boundary.compiled.geometry.torso_size_m.y / 2.0;

    for body_spec in &spec.bodies {
        let body_id = &body_spec.body_id;
        let collider_handle = robot.colliders[body_id];
        let collider = &robot.world.colliders[collider_handle];
        let distal_site = spec
            .contact_sites
            .iter()
            .find(|site| site.body_id == *body_id);
        let clearance = if let Some(site) = distal_site {
            distal_nonfoot_clearance_m(robot, body_id, site, &body_spec.collision)?
        } else {
            collider.compute_aabb().mins.y as f64
        };
        minimum_nonfoot_clearance_m.insert(body_id.clone(), clearance);

        let Some(pair) = robot
            .world
            .contact_pair(collider_handle, robot.ground_collider)
        else {
            continue;
        };
        for (manifold_index, manifold) in pair.manifolds.iter().enumerate() {
            for (point_index, point) in manifold.points.iter().enumerate() {
                let impulse = point.data.impulse.abs() as f64;
                if !impulse.is_finite() {
                    return Err(format!("QSDK_R24D45_CONTACT_IMPULSE_NONFINITE:{body_id}"));
                }
                // A geometric overlap with no solver impulse is valid clearance
                // information, but it is not promoted into an ordinary unilateral
                // contact identity.
                if impulse == 0.0 {
                    continue;
                }
                let local_point = if pair.collider1 == collider_handle
                    && pair.collider2 == robot.ground_collider
                {
                    point.local_p1
                } else if pair.collider2 == collider_handle
                    && pair.collider1 == robot.ground_collider
                {
                    point.local_p2
                } else {
                    return Err(format!(
                        "QSDK_R24D45_CONTACT_PAIR_IDENTITY_INVALID:{body_id}"
                    ));
                };
                let contact_id = format!(
                    "rapier_ground_step_{semantic_step}_{body_id}_{manifold_index}_{point_index}"
                );
                let classified_as_foot = distal_site.is_some_and(|site| {
                    local_point.y as f64
                        <= site.local_center_m.y + CONTACT_CLASSIFICATION_TOLERANCE_M
                });
                if classified_as_foot {
                    let site = distal_site.expect("classified distal contact site");
                    *foot_impulses_ns
                        .get_mut(&site.contact_site_id)
                        .expect("ordered foot impulse") += impulse;
                    foot_contact_ids
                        .get_mut(&site.contact_site_id)
                        .expect("ordered foot ids")
                        .push(contact_id);
                } else {
                    *nonfoot_impulses_ns
                        .get_mut(body_id)
                        .expect("ordered nonfoot impulse") += impulse;
                    nonfoot_contact_ids
                        .get_mut(body_id)
                        .expect("ordered nonfoot ids")
                        .push(contact_id);
                    if body_id == "torso"
                        && local_point.y as f64
                            <= -torso_half_height_m + CONTACT_CLASSIFICATION_TOLERANCE_M
                    {
                        torso_ventral_contact = true;
                    }
                }
            }
        }
    }
    Ok(RapierRecoveryContactMeasurementsV1 {
        foot_impulses_ns,
        foot_contact_ids,
        nonfoot_impulses_ns,
        nonfoot_contact_ids,
        minimum_nonfoot_clearance_m,
        torso_ventral_contact,
    })
}

pub(crate) fn arm_id(arm: RecoveryArmKindV1) -> &'static str {
    match arm {
        RecoveryArmKindV1::CandidateCommand => "candidate_command",
        RecoveryArmKindV1::MatchedZeroCommand => "matched_zero_command",
    }
}

fn controller_ownership_v1(
    arm: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
) -> RecoveryControllerOwnershipReceiptV1 {
    if arm == RecoveryArmKindV1::MatchedZeroCommand {
        return RecoveryControllerOwnershipReceiptV1 {
            owner: RecoveryControllerOwnerV1::None,
            recovery_controller_id: None,
            stance_controller_id: None,
            handoff_event_count: 0,
            fallback_controller_active: false,
            source_measurement: true,
        };
    }
    match phase {
        RecoveryPhaseV1::ConfirmProne
        | RecoveryPhaseV1::EstablishDistalSupport
        | RecoveryPhaseV1::RaiseBody => RecoveryControllerOwnershipReceiptV1 {
            owner: RecoveryControllerOwnerV1::Recovery,
            recovery_controller_id: Some(EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned()),
            stance_controller_id: None,
            handoff_event_count: 0,
            fallback_controller_active: false,
            source_measurement: true,
        },
        RecoveryPhaseV1::StanceHandoff
        | RecoveryPhaseV1::StanceDwell
        | RecoveryPhaseV1::Complete => RecoveryControllerOwnershipReceiptV1 {
            owner: RecoveryControllerOwnerV1::Stance,
            recovery_controller_id: None,
            stance_controller_id: Some(EXACT_S169_STANCE_CONTROLLER_ID.to_owned()),
            handoff_event_count: 1,
            fallback_controller_active: false,
            source_measurement: true,
        },
        RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused => {
            RecoveryControllerOwnershipReceiptV1 {
                owner: RecoveryControllerOwnerV1::None,
                recovery_controller_id: None,
                stance_controller_id: None,
                handoff_event_count: 0,
                fallback_controller_active: false,
                source_measurement: true,
            }
        }
    }
}

pub(crate) fn apply_and_step_r24d45_recovery_v1(
    world: &mut RapierRecoveryWorldV1,
    boundary: &RapierRecoveryBoundaryV1,
    arm: RecoveryArmKindV1,
    phase: RecoveryPhaseV1,
    semantic_step: u64,
    control: Option<&RecoveryControlReceiptV1>,
) -> Result<RapierRecoveryApplicationV1, String> {
    if semantic_step != world.host_step_count.saturating_add(1)
        || world.robot.solver_step_count != world.host_step_count
    {
        return Err("QSDK_R24D45_APPLICATION_STEP_IDENTITY_INVALID".to_owned());
    }
    let ordered_joint_velocities_before = boundary
        .compiled
        .morphology
        .ordered_joint_ids
        .iter()
        .map(|joint_id| joint_velocity_rad_s(&world.robot, joint_id))
        .collect::<Result<Vec<_>, _>>()?;
    let active_control =
        control.is_some_and(|value| !value.no_actuation_requested && !value.matched_zero_command);
    if arm == RecoveryArmKindV1::CandidateCommand
        && !active_control
        && !matches!(phase, RecoveryPhaseV1::ConfirmProne)
    {
        return Err("QSDK_R24D45_CANDIDATE_ACTIVE_CONTROL_MISSING".to_owned());
    }

    let mut ordered_pre_step_readbacks = Vec::with_capacity(ACTUATOR_COUNT);
    let (command_id, command_sha256, native_load_bearing_application_count) = if active_control {
        let control = control.expect("active recovery control");
        if control.semantic_step.saturating_add(1) != semantic_step || control.phase != phase {
            return Err("QSDK_R24D45_CONTROL_STEP_OR_PHASE_MISMATCH".to_owned());
        }
        let ordered_positions = boundary
            .compiled
            .morphology
            .ordered_joint_ids
            .iter()
            .map(|joint_id| world.robot.joint_angle(joint_id))
            .collect::<Result<Vec<_>, _>>()?;
        let mapped = map_r24d45_recovery_control_to_public_profile_v1(
            boundary,
            control,
            &ordered_positions,
        )?;
        for ((source, host), profile) in mapped
            .actuation
            .ordered_commands
            .iter()
            .zip(&mapped.host_mapping.ordered_commands)
            .zip(&boundary.public_profile_binding.ordered_mappings)
        {
            if source.actuator_id != host.actuator_id
                || source.actuator_id != profile.actuator_id
                || host.native_target_position_rad.is_some()
                || host.host_clamped
                || host.valid_through_step != control.semantic_step
            {
                return Err(format!(
                    "QSDK_R24D45_APPLICATION_MAPPING_INVALID:{}",
                    host.actuator_id
                ));
            }
            let joint_id = world
                .robot
                .actuator_joints
                .get(&host.actuator_id)
                .ok_or_else(|| {
                    format!(
                        "QSDK_R24D45_APPLICATION_ACTUATOR_MISSING:{}",
                        host.actuator_id
                    )
                })?;
            if joint_id != &profile.joint_id {
                return Err(format!(
                    "QSDK_R24D45_APPLICATION_PROFILE_JOINT_MISMATCH:{}",
                    host.actuator_id
                ));
            }
            let maximum_force = world.robot.actuator_maximum_force[&host.actuator_id];
            if maximum_force != profile.rapier_maximum_force_nm_f32 {
                return Err(format!(
                    "QSDK_R24D45_APPLICATION_PROFILE_FORCE_MISMATCH:{}",
                    host.actuator_id
                ));
            }
            let joint = world
                .robot
                .world
                .impulse_joints
                .get_mut(world.robot.joints[joint_id], true)
                .ok_or_else(|| "QSDK_R24D45_APPLICATION_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "QSDK_R24D45_APPLICATION_REVOLUTE_MISSING".to_owned())?;
            let readback = update_velocity_only_motor_v1(
                revolute,
                host.host_target_velocity_rad_s as f32,
                maximum_force,
            )?;
            let target_error =
                (readback.target_velocity_rad_s as f64 - host.host_target_velocity_rad_s).abs();
            let outer_impulse_readback = readback.maximum_force_nm as f64 * OUTER_DT_S;
            let outer_impulse_error =
                (outer_impulse_readback - profile.portable_maximum_outer_step_impulse_nms).abs();
            if target_error > 2.5e-7 || outer_impulse_error > 5.0e-7 {
                return Err(format!(
                    "QSDK_R24D45_APPLICATION_READBACK_MISMATCH:{}",
                    host.actuator_id
                ));
            }
            ordered_pre_step_readbacks.push(json!({
                "actuator_id": host.actuator_id,
                "joint_id": joint_id,
                "host_target_velocity_rad_s": host.host_target_velocity_rad_s,
                "motor_target_velocity_readback_rad_s": readback.target_velocity_rad_s,
                "motor_model": "ForceBased",
                "native_position_stiffness": 0.0,
                "damping_nm_s_per_rad": readback.damping_nm_s_per_rad,
                "maximum_force_nm": readback.maximum_force_nm,
                "declared_maximum_outer_step_impulse_nms":
                    profile.portable_maximum_outer_step_impulse_nms,
                "outer_step_impulse_readback_nms": outer_impulse_readback,
                "target_readback_error_rad_s": target_error,
                "outer_step_impulse_readback_error_nms": outer_impulse_error,
                "readback_matches": true,
            }));
        }
        (
            mapped.actuation.receipt.command_id,
            control
                .command_sha256
                .clone()
                .ok_or_else(|| "QSDK_R24D45_ACTIVE_COMMAND_SHA_MISSING".to_owned())?,
            ACTUATOR_COUNT,
        )
    } else {
        if let Some(control) = control
            && (control.semantic_step.saturating_add(1) != semantic_step
                || control.phase != phase
                || control.support_status != RecoverySupportStatusV1::SupportedExact
                || control.refusal_reason.is_some()
                || !control.no_actuation_requested
                || !control.ordered_commands.is_empty()
                || control.engine_identity_input_count != 0
                || control.engine_specific_policy_branch_count != 0)
        {
            return Err("QSDK_R24D45_NO_AUTHORITY_CONTROL_INVALID".to_owned());
        }
        let controller_receipt_sha256 = control
            .map(digest_serializable)
            .transpose()
            .map_err(|error| error.to_string())?;
        let marker = json!({
            "schema_version": "sporespore_rapier_recovery_no_authority_command_v1",
            "route_id": ROUTE_ID,
            "arm_kind": arm_id(arm),
            "phase": phase.phase_id(),
            "semantic_step": semantic_step,
            "controller_receipt_sha256": controller_receipt_sha256,
            "maximum_force_nm": 0.0,
        });
        let command_id = if arm == RecoveryArmKindV1::MatchedZeroCommand {
            format!("r24d45_matched_zero_step_{semantic_step}")
        } else {
            format!("r24d45_candidate_confirm_no_actuation_step_{semantic_step}")
        };
        for ((actuator, joint_id), current_velocity) in boundary
            .compiled
            .morphology
            .morphology_spec
            .actuators
            .iter()
            .zip(&boundary.compiled.morphology.ordered_joint_ids)
            .zip(&ordered_joint_velocities_before)
        {
            if actuator.joint_id != *joint_id {
                return Err("QSDK_R24D45_NO_AUTHORITY_ORDER_INVALID".to_owned());
            }
            let joint = world
                .robot
                .world
                .impulse_joints
                .get_mut(world.robot.joints[joint_id], true)
                .ok_or_else(|| "QSDK_R24D45_NO_AUTHORITY_JOINT_MISSING".to_owned())?;
            let revolute = joint
                .data
                .as_revolute_mut()
                .ok_or_else(|| "QSDK_R24D45_NO_AUTHORITY_REVOLUTE_MISSING".to_owned())?;
            revolute
                .set_motor_velocity(
                    *current_velocity as f32,
                    VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD,
                )
                .set_motor_model(MotorModel::ForceBased)
                .set_motor_max_force(0.0);
            let motor = revolute
                .motor()
                .ok_or_else(|| "QSDK_R24D45_NO_AUTHORITY_MOTOR_MISSING".to_owned())?;
            if motor.model != MotorModel::ForceBased
                || motor.target_vel != *current_velocity as f32
                || motor.stiffness != 0.0
                || motor.damping != VELOCITY_ONLY_MOTOR_DAMPING_NM_S_PER_RAD
                || motor.max_force != 0.0
            {
                return Err(format!(
                    "QSDK_R24D45_NO_AUTHORITY_READBACK_MISMATCH:{}",
                    actuator.actuator_id
                ));
            }
            ordered_pre_step_readbacks.push(json!({
                "actuator_id": actuator.actuator_id,
                "joint_id": joint_id,
                "host_target_velocity_rad_s": current_velocity,
                "motor_target_velocity_readback_rad_s": motor.target_vel,
                "motor_model": "ForceBased",
                "native_position_stiffness": motor.stiffness,
                "damping_nm_s_per_rad": motor.damping,
                "maximum_force_nm": motor.max_force,
                "declared_maximum_outer_step_impulse_nms": 0.0,
                "outer_step_impulse_readback_nms": 0.0,
                "target_readback_error_rad_s":
                    (motor.target_vel as f64 - *current_velocity).abs(),
                "outer_step_impulse_readback_error_nms": 0.0,
                "readback_matches": true,
            }));
        }
        let command_sha256 = control
            .and_then(|value| value.command_sha256.clone())
            .unwrap_or(sha256_value(
                &marker,
                "QSDK_R24D45_NO_AUTHORITY_COMMAND_SHA",
            )?);
        (command_id, command_sha256, 0)
    };

    let solver_step_before = world.robot.solver_step_count;
    let host_step_before = world.host_step_count;
    world.robot.world.step();
    world.robot.solver_step_count = world.robot.solver_step_count.saturating_add(1);
    world.host_step_count = world.host_step_count.saturating_add(1);
    if world.robot.solver_step_count != solver_step_before.saturating_add(1)
        || world.host_step_count != host_step_before.saturating_add(1)
    {
        return Err("QSDK_R24D45_NATIVE_STEP_COUNT_INVALID".to_owned());
    }

    let ordered_joint_velocities_after = boundary
        .compiled
        .morphology
        .ordered_joint_ids
        .iter()
        .map(|joint_id| joint_velocity_rad_s(&world.robot, joint_id))
        .collect::<Result<Vec<_>, _>>()?;
    let mut ordered_applied_impulses = Vec::with_capacity(ACTUATOR_COUNT);
    let mut ordered_post_step_readbacks = Vec::with_capacity(ACTUATOR_COUNT);
    let mut step_actuator_work_j = 0.0_f64;
    for (index, actuator) in boundary
        .compiled
        .morphology
        .morphology_spec
        .actuators
        .iter()
        .enumerate()
    {
        let joint_id = &actuator.joint_id;
        let motor = world
            .robot
            .world
            .impulse_joints
            .get(world.robot.joints[joint_id])
            .and_then(|joint| joint.data.as_revolute())
            .and_then(|joint| joint.motor())
            .ok_or_else(|| format!("QSDK_R24D45_POST_STEP_MOTOR_MISSING:{joint_id}"))?;
        let signed_impulse_nms = finite(
            motor.impulse as f64,
            "QSDK_R24D45_POST_STEP_MOTOR_IMPULSE_NONFINITE",
        )?;
        let maximum_force = world.robot.actuator_maximum_force[&actuator.actuator_id];
        let maximum_small_step_impulse =
            velocity_only_small_step_impulse_limit_v1(maximum_force) as f64;
        if active_control {
            if signed_impulse_nms.abs() > maximum_small_step_impulse + 1.0e-6 {
                return Err(format!(
                    "QSDK_R24D45_POST_STEP_MOTOR_IMPULSE_CAP_EXCEEDED:{}",
                    actuator.actuator_id
                ));
            }
        } else if signed_impulse_nms != 0.0 || motor.max_force != 0.0 {
            return Err(format!(
                "QSDK_R24D45_NO_AUTHORITY_NONZERO_IMPULSE:{}",
                actuator.actuator_id
            ));
        }
        let centered_velocity_rad_s =
            0.5 * (ordered_joint_velocities_before[index] + ordered_joint_velocities_after[index]);
        let actuator_work_j = signed_impulse_nms * centered_velocity_rad_s;
        step_actuator_work_j +=
            finite(actuator_work_j, "QSDK_R24D45_STEP_ACTUATOR_WORK_NONFINITE")?;
        ordered_applied_impulses.push(RecoveryAppliedActuatorImpulseV1 {
            actuator_id: actuator.actuator_id.clone(),
            applied_angular_impulse_nms: signed_impulse_nms,
            host_clamped: false,
        });
        ordered_post_step_readbacks.push(json!({
            "actuator_id": actuator.actuator_id,
            "joint_id": joint_id,
            "signed_motor_impulse_nms": signed_impulse_nms,
            "maximum_solver_small_step_impulse_nms": maximum_small_step_impulse,
            "joint_velocity_before_rad_s": ordered_joint_velocities_before[index],
            "joint_velocity_after_rad_s": ordered_joint_velocities_after[index],
            "centered_joint_velocity_rad_s": centered_velocity_rad_s,
            "actuator_work_j": actuator_work_j,
            "impulse_within_cap": true,
        }));
    }
    step_actuator_work_j = finite(
        step_actuator_work_j,
        "QSDK_R24D45_TOTAL_STEP_ACTUATOR_WORK_NONFINITE",
    )?;
    let application = json!({
        "schema_version": APPLICATION_SCHEMA,
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": arm_id(arm),
        "phase": phase.phase_id(),
        "semantic_step": semantic_step,
        "command_id": command_id,
        "command_sha256": command_sha256,
        "actuator_profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "actuator_profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "zero_command": arm == RecoveryArmKindV1::MatchedZeroCommand,
        "native_motor_configuration_count": ACTUATOR_COUNT,
        "native_load_bearing_application_count": native_load_bearing_application_count,
        "ordered_pre_step_readbacks": ordered_pre_step_readbacks,
        "ordered_post_step_readbacks": ordered_post_step_readbacks,
        "ordered_applied_impulses": ordered_applied_impulses,
        "actuator_work_rule_id":
            "rapier_signed_motor_impulse_times_centered_relative_joint_velocity_v1",
        "step_actuator_work_j": step_actuator_work_j,
        "external_impulse_application_count": 0,
        "engine_specific_policy_branch_count": 0,
        "host_step_before": host_step_before,
        "host_step_after": world.host_step_count,
        "solver_step_before": solver_step_before,
        "solver_step_after": world.robot.solver_step_count,
    });
    let application_sha256 = sha256_value(&application, "QSDK_R24D45_APPLICATION_RECEIPT_SHA")?;
    Ok(RapierRecoveryApplicationV1 {
        application,
        application_sha256,
        command_id,
        command_sha256,
        zero_command: arm == RecoveryArmKindV1::MatchedZeroCommand,
        ordered_applied_impulses,
        step_actuator_work_j,
    })
}

fn valid_sha256(value: &str) -> bool {
    value.len() == 71
        && value.starts_with("sha256:")
        && value[7..].bytes().all(|byte| byte.is_ascii_hexdigit())
}

pub(crate) fn collect_r24d45_native_step_v1(
    world: &mut RapierRecoveryWorldV1,
    boundary: &RapierRecoveryBoundaryV1,
    application: RapierRecoveryApplicationV1,
    context: RapierRecoveryStepContextV1<'_>,
) -> Result<RapierRecoveryNativeStepV1, String> {
    let RapierRecoveryStepContextV1 {
        arm,
        phase,
        semantic_step,
        previous_observation_sha256,
        runtime_qualification_sha256,
    } = context;
    if semantic_step != world.host_step_count
        || semantic_step != world.robot.solver_step_count
        || application.zero_command != (arm == RecoveryArmKindV1::MatchedZeroCommand)
        || !valid_sha256(runtime_qualification_sha256)
        || previous_observation_sha256.is_some_and(|value| !valid_sha256(value))
    {
        return Err("QSDK_R24D45_COLLECTION_STEP_IDENTITY_INVALID".to_owned());
    }
    let capability_sha256 =
        digest_serializable(&rapier_recovery_capability_v1()).map_err(|error| error.to_string())?;
    let contacts = measure_r24d45_contacts_v1(&world.robot, boundary, semantic_step)?;
    let center_of_mass = whole_system_center_of_mass(&world.robot, boundary)?;
    let mut state =
        world
            .robot
            .state_frame(&boundary.compiled, semantic_step, world.task_origin)?;
    state.adapter_capability_sha256 = capability_sha256.clone();
    state.ordered_contact_observations = boundary
        .compiled
        .morphology
        .morphology_spec
        .contact_sites
        .iter()
        .map(|site| {
            let engine_contact_ids = contacts.foot_contact_ids[&site.contact_site_id].clone();
            let impulse = contacts.foot_impulses_ns[&site.contact_site_id];
            let present = !engine_contact_ids.is_empty();
            ContactObservation {
                contact_site_id: site.contact_site_id.clone(),
                presence: Some(present),
                bears_support: Some(present && site.can_support && impulse > 0.0),
                normal_load_n: None,
                provenance: ContactProvenance {
                    adapter_id: RAPIER_RECOVERY_ADAPTER_ID.to_owned(),
                    engine_contact_ids,
                    aggregation_rule_id: CONTACT_CLASSIFICATION_RULE_ID.to_owned(),
                    quality: ContactQuality::QualifiedBearing,
                    impulse_source_profile_id: None,
                    impulse_source_kind: None,
                },
            }
        })
        .collect();
    let ordered_foot_bearing_observations = boundary
        .compiled
        .morphology
        .morphology_spec
        .contact_sites
        .iter()
        .map(|site| RecoveryFootBearingObservationV1 {
            contact_site_id: site.contact_site_id.clone(),
            bearing_normal_impulse_ns: contacts.foot_impulses_ns[&site.contact_site_id],
            ordinary_unilateral_contact: !contacts.foot_contact_ids[&site.contact_site_id]
                .is_empty(),
            source_measurement: true,
        })
        .collect::<Vec<_>>();
    let ordered_body_clearance_observations = boundary
        .compiled
        .morphology
        .ordered_body_ids
        .iter()
        .map(|body_id| {
            let engine_contact_ids = contacts.nonfoot_contact_ids[body_id].clone();
            RecoveryBodyClearanceObservationV1 {
                adapter_id: RAPIER_RECOVERY_ADAPTER_ID.to_owned(),
                body_id: body_id.clone(),
                nonfoot_contact_present: !engine_contact_ids.is_empty(),
                ventral_surface_contact: body_id == "torso" && contacts.torso_ventral_contact,
                accumulated_nonfoot_normal_impulse_ns: contacts.nonfoot_impulses_ns[body_id],
                minimum_nonfoot_clearance_m: contacts.minimum_nonfoot_clearance_m[body_id],
                engine_contact_ids,
                classification_rule_id: NONFOOT_CLASSIFICATION_RULE_ID.to_owned(),
                foot_site_contacts_excluded: true,
                source_measurement: true,
            }
        })
        .collect::<Vec<_>>();
    let external_interventions = RecoveryExternalInterventionLedgerV1::default();
    let controller_ownership = controller_ownership_v1(arm, phase);
    world.cumulative_actuator_work_j = finite(
        world.cumulative_actuator_work_j + application.step_actuator_work_j,
        "QSDK_R24D45_CUMULATIVE_ACTUATOR_WORK_NONFINITE",
    )?;
    let energy_balance = RecoveryEnergyBalanceLedgerV1 {
        initial_mechanical_energy_j: world.initial_mechanical_energy_j,
        current_mechanical_energy_j: mechanical_energy_j(&world.robot, boundary)?,
        cumulative_applied_actuator_work_j: world.cumulative_actuator_work_j,
        cumulative_external_work_j: 0.0,
        // Rapier exposes the mechanical state and applied motor impulse but
        // not a complete per-step dissipative partition. Preserve the unclosed
        // residual instead of deriving a flattering dissipation value from it.
        cumulative_dissipated_energy_j: 0.0,
        source_measurement: true,
    };
    let applied_actuation = RecoveryAppliedActuationReceiptV1 {
        adapter_id: RAPIER_RECOVERY_ADAPTER_ID.to_owned(),
        adapter_receipt_sha256: application.application_sha256.clone(),
        source_semantic_step: semantic_step,
        command_id: application.command_id.clone(),
        command_sha256: application.command_sha256.clone(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        actuator_profile_sha256: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256.to_owned(),
        zero_command: application.zero_command,
        ordered_applied_impulses: application.ordered_applied_impulses.clone(),
        source_measurement: true,
    };
    let state_value = serde_json::to_value(&state)
        .map_err(|error| format!("QSDK_R24D45_STATE_SERIALIZE:{error}"))?;
    let contact_value = json!({
        "ordered_foot_bearing_observations": ordered_foot_bearing_observations,
        "ordered_body_clearance_observations": ordered_body_clearance_observations,
    });
    let energy_value = serde_json::to_value(energy_balance)
        .map_err(|error| format!("QSDK_R24D45_ENERGY_SERIALIZE:{error}"))?;
    let previous_value = previous_observation_sha256
        .map(|value| Value::String(value.to_owned()))
        .unwrap_or(Value::Null);
    let source_trace = json!({
        "schema_version": "sporespore_rapier_recovery_source_trace_v1",
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": arm_id(arm),
        "phase": phase.phase_id(),
        "semantic_step": semantic_step,
        "runtime_qualification_sha256": runtime_qualification_sha256,
        "previous_observation_sha256": previous_value,
        "application_sha256": application.application_sha256,
        "state_sha256": sha256_value(&state_value, "QSDK_R24D45_STATE_SHA")?,
        "contact_measurements_sha256":
            sha256_value(&contact_value, "QSDK_R24D45_CONTACT_SHA")?,
        "energy_balance_sha256": sha256_value(&energy_value, "QSDK_R24D45_ENERGY_SHA")?,
        "host_step_before": semantic_step - 1,
        "host_step_after": semantic_step,
        "solver_step_before": semantic_step - 1,
        "solver_step_after": semantic_step,
        "native_solver_step_count": 1,
        "external_intervention_count": 0,
        "engine_specific_policy_branch_count": 0,
    });
    let source_trace_sha256 = sha256_value(&source_trace, "QSDK_R24D45_SOURCE_TRACE_SHA")?;
    let observation = RecoveryObservationV1 {
        schema_version: RECOVERY_OBSERVATION_V1_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        semantic_step,
        outer_step_duration_s: RECOVERY_OUTER_STEP_DURATION_S,
        state,
        center_of_mass,
        ordered_foot_bearing_observations,
        ordered_body_clearance_observations,
        applied_actuation,
        external_interventions,
        controller_ownership,
        energy_balance,
        engine_step_identity: RecoveryEngineStepIdentityV1 {
            schema_version: RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION.to_owned(),
            source_kind: RecoveryObservationSourceKindV1::NativePostStep,
            adapter_id: RAPIER_RECOVERY_ADAPTER_ID.to_owned(),
            engine: RecoveryNativeEngineV1::RapierParryNative,
            capability_sha256,
            source_trace_sha256: source_trace_sha256.clone(),
            semantic_step,
            host_step_before: semantic_step - 1,
            host_step_after: semantic_step,
            native_solver_substep_count: 1,
            post_step_observation: true,
            engine_identity_exposed_to_policy: false,
        },
    };
    let observation_value = serde_json::to_value(&observation)
        .map_err(|error| format!("QSDK_R24D45_OBSERVATION_SERIALIZE:{error}"))?;
    let observation_sha256 = sha256_value(&observation_value, "QSDK_R24D45_OBSERVATION_SHA")?;
    let invariant_receipt = json!({
        "schema_version": NATIVE_STEP_SCHEMA,
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": arm_id(arm),
        "phase": phase.phase_id(),
        "semantic_step": semantic_step,
        "previous_observation_sha256": previous_value,
        "application": application.application,
        "application_sha256": application.application_sha256,
        "source_trace": source_trace,
        "source_trace_sha256": source_trace_sha256,
        "observation": observation_value,
        "observation_sha256": observation_sha256,
        "host_step_before": semantic_step - 1,
        "host_step_after": semantic_step,
        "solver_step_before": semantic_step - 1,
        "solver_step_after": semantic_step,
        "native_solver_step_count": 1,
        "external_intervention_count": 0,
        "engine_specific_policy_branch_count": 0,
        "world_build_count_for_arm": 1,
        "physical_acceptance_authority": false,
        "prone_to_standing_claimed": false,
        "release_authority": false,
    });
    Ok(RapierRecoveryNativeStepV1 {
        observation,
        observation_sha256,
        invariant_receipt,
    })
}

pub(crate) fn validate_r24d45_in_run_step_v1(
    receipt: &Value,
    expected_previous_observation_sha256: Option<&str>,
) -> Result<(), String> {
    let semantic_step = receipt["semantic_step"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_SEMANTIC_STEP_INVALID".to_owned())?;
    let host_before = receipt["host_step_before"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_HOST_BEFORE_INVALID".to_owned())?;
    let host_after = receipt["host_step_after"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_HOST_AFTER_INVALID".to_owned())?;
    let solver_before = receipt["solver_step_before"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_SOLVER_BEFORE_INVALID".to_owned())?;
    let solver_after = receipt["solver_step_after"]
        .as_u64()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_SOLVER_AFTER_INVALID".to_owned())?;
    let arm = receipt["arm_kind"]
        .as_str()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_ARM_INVALID".to_owned())?;
    let phase = receipt["phase"]
        .as_str()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_PHASE_INVALID".to_owned())?;
    let previous_expected = expected_previous_observation_sha256
        .map(|value| Value::String(value.to_owned()))
        .unwrap_or(Value::Null);
    if receipt["schema_version"] != NATIVE_STEP_SCHEMA
        || receipt["route_id"] != ROUTE_ID
        || receipt["cell_id"] != CELL_ID
        || receipt["seed"] != CELL_SEED
        || !matches!(arm, "candidate_command" | "matched_zero_command")
        || !matches!(
            phase,
            "confirm_prone"
                | "establish_distal_support"
                | "raise_body"
                | "stance_handoff"
                | "stance_dwell"
        )
        || semantic_step == 0
        || host_before.saturating_add(1) != host_after
        || solver_before.saturating_add(1) != solver_after
        || semantic_step != host_after
        || semantic_step != solver_after
        || receipt["native_solver_step_count"] != 1
        || receipt["world_build_count_for_arm"] != 1
        || receipt["external_intervention_count"] != 0
        || receipt["engine_specific_policy_branch_count"] != 0
        || receipt["previous_observation_sha256"] != previous_expected
        || receipt["physical_acceptance_authority"] != false
        || receipt["prone_to_standing_claimed"] != false
        || receipt["release_authority"] != false
    {
        return Err("QSDK_R24D45_INVARIANT_HEADER_INVALID".to_owned());
    }

    let application = &receipt["application"];
    let application_sha256 = receipt["application_sha256"]
        .as_str()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_APPLICATION_SHA_INVALID".to_owned())?;
    if !valid_sha256(application_sha256)
        || sha256_value(application, "QSDK_R24D45_INVARIANT_APPLICATION_REHASH")?
            != application_sha256
        || application["schema_version"] != APPLICATION_SCHEMA
        || application["route_id"] != ROUTE_ID
        || application["cell_id"] != CELL_ID
        || application["arm_kind"] != arm
        || application["phase"] != phase
        || application["semantic_step"] != semantic_step
        || application["host_step_before"] != host_before
        || application["host_step_after"] != host_after
        || application["solver_step_before"] != solver_before
        || application["solver_step_after"] != solver_after
        || application["native_motor_configuration_count"] != ACTUATOR_COUNT
        || application["ordered_pre_step_readbacks"]
            .as_array()
            .is_none_or(|values| values.len() != ACTUATOR_COUNT)
        || application["ordered_post_step_readbacks"]
            .as_array()
            .is_none_or(|values| values.len() != ACTUATOR_COUNT)
        || application["ordered_applied_impulses"]
            .as_array()
            .is_none_or(|values| values.len() != ACTUATOR_COUNT)
        || application["external_impulse_application_count"] != 0
        || application["engine_specific_policy_branch_count"] != 0
        || application["actuator_profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || application["actuator_profile_sha256"]
            != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        || application["zero_command"] != (arm == "matched_zero_command")
        || arm == "matched_zero_command"
            && application["native_load_bearing_application_count"] != 0
        || arm == "candidate_command"
            && phase != "confirm_prone"
            && application["native_load_bearing_application_count"] != ACTUATOR_COUNT
    {
        return Err("QSDK_R24D45_INVARIANT_APPLICATION_INVALID".to_owned());
    }

    let source_trace = &receipt["source_trace"];
    let source_trace_sha256 = receipt["source_trace_sha256"]
        .as_str()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_SOURCE_TRACE_SHA_INVALID".to_owned())?;
    if !valid_sha256(source_trace_sha256)
        || sha256_value(source_trace, "QSDK_R24D45_INVARIANT_SOURCE_TRACE_REHASH")?
            != source_trace_sha256
        || source_trace["schema_version"] != "sporespore_rapier_recovery_source_trace_v1"
        || source_trace["route_id"] != ROUTE_ID
        || source_trace["cell_id"] != CELL_ID
        || source_trace["arm_kind"] != arm
        || source_trace["phase"] != phase
        || source_trace["semantic_step"] != semantic_step
        || source_trace["application_sha256"] != application_sha256
        || source_trace["previous_observation_sha256"] != previous_expected
        || source_trace["host_step_before"] != host_before
        || source_trace["host_step_after"] != host_after
        || source_trace["solver_step_before"] != solver_before
        || source_trace["solver_step_after"] != solver_after
        || source_trace["native_solver_step_count"] != 1
        || source_trace["external_intervention_count"] != 0
        || source_trace["engine_specific_policy_branch_count"] != 0
        || source_trace["runtime_qualification_sha256"]
            .as_str()
            .is_none_or(|value| !valid_sha256(value))
    {
        return Err("QSDK_R24D45_INVARIANT_SOURCE_TRACE_INVALID".to_owned());
    }

    let observation = &receipt["observation"];
    let observation_sha256 = receipt["observation_sha256"]
        .as_str()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_OBSERVATION_SHA_INVALID".to_owned())?;
    let contact_component = json!({
        "ordered_foot_bearing_observations":
            observation["ordered_foot_bearing_observations"],
        "ordered_body_clearance_observations":
            observation["ordered_body_clearance_observations"],
    });
    let external_total = observation["external_interventions"]
        .as_object()
        .ok_or_else(|| "QSDK_R24D45_INVARIANT_INTERVENTION_LEDGER_INVALID".to_owned())?
        .values()
        .try_fold(0_u64, |total, value| {
            value
                .as_u64()
                .map(|count| total.saturating_add(count))
                .ok_or_else(|| "QSDK_R24D45_INVARIANT_INTERVENTION_COUNT_INVALID".to_owned())
        })?;
    let expected_owner = if arm == "matched_zero_command" {
        "none"
    } else if matches!(phase, "stance_handoff" | "stance_dwell") {
        "stance"
    } else {
        "recovery"
    };
    if !valid_sha256(observation_sha256)
        || sha256_value(observation, "QSDK_R24D45_INVARIANT_OBSERVATION_REHASH")?
            != observation_sha256
        || observation["schema_version"] != RECOVERY_OBSERVATION_V1_VERSION
        || observation["task_id"] != CANONICAL_PRONE_TO_STANDING_TASK_ID
        || observation["semantics_id"] != PORTABLE_RECOVERY_SEMANTICS_ID
        || observation["actuator_profile_id"] != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || observation["semantic_step"] != semantic_step
        || observation["outer_step_duration_s"] != RECOVERY_OUTER_STEP_DURATION_S
        || observation["state"]["semantic_step"] != semantic_step
        || observation["state"]["adapter_capability_sha256"]
            != observation["engine_step_identity"]["capability_sha256"]
        || observation["state"]["ordered_joint_observations"]
            .as_array()
            .is_none_or(|values| values.len() != ACTUATOR_COUNT)
        || observation["state"]["ordered_contact_observations"]
            .as_array()
            .is_none_or(|values| values.len() != 4)
        || observation["ordered_foot_bearing_observations"]
            .as_array()
            .is_none_or(|values| values.len() != 4)
        || observation["ordered_body_clearance_observations"]
            .as_array()
            .is_none_or(|values| values.len() != BODY_COUNT)
        || observation["applied_actuation"]["adapter_id"] != RAPIER_RECOVERY_ADAPTER_ID
        || observation["applied_actuation"]["adapter_receipt_sha256"] != application_sha256
        || observation["applied_actuation"]["source_semantic_step"] != semantic_step
        || observation["applied_actuation"]["zero_command"] != (arm == "matched_zero_command")
        || observation["applied_actuation"]["ordered_applied_impulses"]
            .as_array()
            .is_none_or(|values| values.len() != ACTUATOR_COUNT)
        || external_total != 0
        || observation["controller_ownership"]["owner"] != expected_owner
        || observation["controller_ownership"]["fallback_controller_active"] != false
        || observation["energy_balance"]["source_measurement"] != true
        || observation["engine_step_identity"]["schema_version"]
            != RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION
        || observation["engine_step_identity"]["source_kind"] != "native_post_step"
        || observation["engine_step_identity"]["adapter_id"] != RAPIER_RECOVERY_ADAPTER_ID
        || observation["engine_step_identity"]["engine"] != "rapier_parry_native"
        || observation["engine_step_identity"]["source_trace_sha256"] != source_trace_sha256
        || observation["engine_step_identity"]["semantic_step"] != semantic_step
        || observation["engine_step_identity"]["host_step_before"] != host_before
        || observation["engine_step_identity"]["host_step_after"] != host_after
        || observation["engine_step_identity"]["native_solver_substep_count"] != 1
        || observation["engine_step_identity"]["post_step_observation"] != true
        || observation["engine_step_identity"]["engine_identity_exposed_to_policy"] != false
        || source_trace["state_sha256"]
            != sha256_value(&observation["state"], "QSDK_R24D45_INVARIANT_STATE_REHASH")?
        || source_trace["contact_measurements_sha256"]
            != sha256_value(&contact_component, "QSDK_R24D45_INVARIANT_CONTACT_REHASH")?
        || source_trace["energy_balance_sha256"]
            != sha256_value(
                &observation["energy_balance"],
                "QSDK_R24D45_INVARIANT_ENERGY_REHASH",
            )?
    {
        return Err("QSDK_R24D45_INVARIANT_OBSERVATION_INVALID".to_owned());
    }
    Ok(())
}

fn zero_residuals(
    actuation: &sporespore_locomotion_core::ActuationFrame,
) -> Vec<CanonicalVelocityResidualV1> {
    actuation
        .ordered_commands
        .iter()
        .map(|command| CanonicalVelocityResidualV1 {
            schema_version: sporespore_locomotion_core::CANONICAL_VELOCITY_RESIDUAL_V1_VERSION
                .to_owned(),
            actuator_id: command.actuator_id.clone(),
            canonical_velocity_delta_rad_s: 0.0,
            command_not_measurement: true,
            physical_acceptance_authority: false,
        })
        .collect()
}

pub(crate) fn map_r24d45_recovery_control_to_public_profile_v1(
    boundary: &RapierRecoveryBoundaryV1,
    control: &RecoveryControlReceiptV1,
    ordered_joint_positions_rad: &[f64],
) -> Result<RapierRecoveryMappedActuationV1, String> {
    if control.schema_version != RECOVERY_CONTROL_RECEIPT_V1_VERSION
        || control.support_status != RecoverySupportStatusV1::SupportedExact
        || control.refusal_reason.is_some()
        || control.matched_zero_command
        || control.no_actuation_requested
        || control.ordered_commands.len() != ACTUATOR_COUNT
        || control.command_sha256.as_deref()
            != Some(
                digest_serializable(&control.ordered_commands)
                    .map_err(|error| error.to_string())?
                    .as_str(),
            )
        || !control.controller_implemented
        || !control.deterministic
        || control.engine_identity_input_count != 0
        || control.engine_specific_policy_branch_count != 0
        || control.fallback_controller_active
        || control.model_construction_count != 0
        || control.world_attempt_count != 0
        || control.world_build_count != 0
        || control.solver_step_count != 0
        || control.physics_state_modified
        || control.physical_acceptance_authority
        || control.release_authority
        || ordered_joint_positions_rad.len() != ACTUATOR_COUNT
    {
        return Err("QSDK_R24D45_CONTROL_HEADER_INVALID".to_owned());
    }
    let owner_valid = match control.owner {
        RecoveryControllerOwnerV1::Recovery => {
            control.controller_id == EXACT_S169_RECOVERY_CONTROLLER_ID
                && control.recovery_controller_active
                && !control.stance_handoff_requested
        }
        RecoveryControllerOwnerV1::Stance => {
            control.controller_id == EXACT_S169_STANCE_CONTROLLER_ID
                && !control.recovery_controller_active
        }
        RecoveryControllerOwnerV1::None => false,
    };
    if !owner_valid {
        return Err("QSDK_R24D45_CONTROL_OWNERSHIP_INVALID".to_owned());
    }

    let mut ordered_commands = Vec::with_capacity(ACTUATOR_COUNT);
    for (index, ((command, actuator), profile)) in control
        .ordered_commands
        .iter()
        .zip(&boundary.compiled.morphology.morphology_spec.actuators)
        .zip(&boundary.public_profile_binding.ordered_mappings)
        .enumerate()
    {
        let current = finite(
            ordered_joint_positions_rad[index],
            "QSDK_R24D45_CURRENT_JOINT_POSITION_NONFINITE",
        )?;
        if command.schema_version != RECOVERY_CONTROL_COMMAND_V1_VERSION
            || command.actuator_id != actuator.actuator_id
            || command.joint_id != actuator.joint_id
            || command.actuator_id != profile.actuator_id
            || command.joint_id != profile.joint_id
            || command.mode != ActuatorMode::PositionVelocity
            || !command.target_position_rad.is_finite()
            || !command.target_velocity_rad_s.is_finite()
            || command.target_velocity_rad_s != 0.0
            || !command.maximum_target_speed_rad_s.is_finite()
            || command.maximum_target_speed_rad_s <= 0.0
            || command.maximum_outer_step_impulse_nms
                != profile.portable_maximum_outer_step_impulse_nms
            || command.target_position_rad < actuator.minimum_target_position_rad
            || command.target_position_rad > actuator.maximum_target_position_rad
        {
            return Err(format!("QSDK_R24D45_CONTROL_COMMAND_INVALID:{index}"));
        }
        let requested_canonical_velocity = (command.target_position_rad - current) / OUTER_DT_S;
        let canonical_velocity = requested_canonical_velocity.clamp(
            -command.maximum_target_speed_rad_s,
            command.maximum_target_speed_rad_s,
        );
        ordered_commands.push(sporespore_locomotion_core::ActuatorCommand {
            actuator_id: command.actuator_id.clone(),
            mode: command.mode,
            requested_target_position_rad: command.target_position_rad,
            clamped_target_position_rad: command.target_position_rad,
            target_velocity_rad_s: canonical_velocity
                / LEGACY_GODOT_HOST_TO_CANONICAL_VELOCITY_SIGN,
            maximum_target_speed_rad_s: command.maximum_target_speed_rad_s,
            position_saturated: false,
            velocity_saturated: canonical_velocity != requested_canonical_velocity,
            slew_limited: false,
            residual_contribution_rad_s: 0.0,
            safety_contribution_rad_s: 0.0,
            valid_through_step: control.semantic_step,
        });
    }
    let receipt = ControllerStepReceipt {
        schema_version: "sporespore_controller_step_receipt_v8".to_owned(),
        policy_id: control.controller_id.clone(),
        semantic_step: control.semantic_step,
        command_id: format!("r24d45_recovery_step_{}", control.semantic_step),
        morphology_spec_sha256: boundary.compiled.morphology.morphology_spec_sha256.clone(),
        adapter_capability_sha256: digest_serializable(&rapier_recovery_capability_v1())
            .map_err(|error| error.to_string())?,
        steering_feedback_updated: false,
        requested_steering_fraction: 0.0,
        previous_steering_fraction: 0.0,
        held_steering_fraction: 0.0,
        applied_steering_delta: 0.0,
        steering_saturated: false,
        steering_slew_limited: false,
        steering_filter_alpha_per_step: None,
        steering_filter_time_constant_cycle_fraction: None,
        cross_track_error_m: 0.0,
        cross_track_velocity_m_s: 0.0,
        measured_yaw_error_rad: 0.0,
        desired_heading_error_rad: 0.0,
        yaw_tracking_error_rad: 0.0,
        steering_authority_guard: None,
        release_gate_unweighting: None,
        forward_velocity_foot_placement: None,
        // This historical canonical route does not use the newer support-plane policy.
        recovery_support_plane: None,
        controller_error: None,
        world_build_count: 0,
        physical_acceptance_authority: false,
    };
    let receipt_sha256 = digest_serializable(&receipt).map_err(|error| error.to_string())?;
    let actuation = sporespore_locomotion_core::ActuationFrame {
        schema_version: ACTUATION_FRAME_VERSION.to_owned(),
        semantic_step: control.semantic_step,
        ordered_commands,
        safe_no_actuation: false,
        failure_codes: Vec::new(),
        receipt,
        receipt_sha256,
        world_build_count: 0,
        physical_acceptance_authority: false,
    };
    let canonical = canonicalize_and_compose_legacy_velocity_v1(
        &boundary.compiled.morphology,
        &actuation,
        &zero_residuals(&actuation),
    )
    .map_err(|error| format!("QSDK_R24D45_CANONICAL_MAPPING:{error}"))?;
    let host_mapping = map_canonical_velocity_to_host_v1(
        &boundary.compiled.morphology,
        &canonical,
        &VelocityOnlyHostProfileV1::rapier_force_based_velocity_only_target(),
    )
    .map_err(|error| format!("QSDK_R24D45_HOST_MAPPING:{error}"))?;
    if host_mapping.ordered_commands.len() != ACTUATOR_COUNT
        || host_mapping
            .ordered_commands
            .iter()
            .zip(&canonical.ordered_commands)
            .any(|(host, portable)| {
                host.actuator_id != portable.actuator_id
                    || host.host_target_velocity_rad_s
                        != portable.combined_canonical_target_velocity_rad_s
                    || host.native_target_position_rad.is_some()
                    || host.host_clamped
            })
    {
        return Err("QSDK_R24D45_HOST_MAPPING_READBACK_INVALID".to_owned());
    }
    Ok(RapierRecoveryMappedActuationV1 {
        actuation,
        canonical,
        host_mapping,
    })
}

fn active_control_fixture(
    boundary: &RapierRecoveryBoundaryV1,
) -> Result<RecoveryControlReceiptV1, String> {
    let profile = recovery_development_profile_v1();
    let ordered_commands = profile
        .establish_distal_support_pose
        .ordered_target_positions_rad
        .iter()
        .zip(&boundary.compiled.morphology.morphology_spec.actuators)
        .zip(&boundary.public_profile_binding.ordered_mappings)
        .map(|((target, actuator), cap)| RecoveryControlCommandV1 {
            schema_version: RECOVERY_CONTROL_COMMAND_V1_VERSION.to_owned(),
            actuator_id: actuator.actuator_id.clone(),
            joint_id: actuator.joint_id.clone(),
            mode: ActuatorMode::PositionVelocity,
            target_position_rad: *target,
            target_velocity_rad_s: 0.0,
            maximum_target_speed_rad_s: profile
                .establish_distal_support_pose
                .maximum_target_speed_rad_s,
            maximum_outer_step_impulse_nms: cap.portable_maximum_outer_step_impulse_nms,
        })
        .collect::<Vec<_>>();
    let command_sha256 =
        digest_serializable(&ordered_commands).map_err(|error| error.to_string())?;
    Ok(RecoveryControlReceiptV1 {
        schema_version: RECOVERY_CONTROL_RECEIPT_V1_VERSION.to_owned(),
        support_status: RecoverySupportStatusV1::SupportedExact,
        refusal_reason: None,
        controller_id: EXACT_S169_RECOVERY_CONTROLLER_ID.to_owned(),
        controller_profile_sha256: digest_serializable(&profile)
            .map_err(|error| error.to_string())?,
        observation_sha256: Some(
            "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa".to_owned(),
        ),
        semantic_step: 12,
        phase: RecoveryPhaseV1::EstablishDistalSupport,
        phase_step: 0,
        owner: RecoveryControllerOwnerV1::Recovery,
        recovery_controller_active: true,
        stance_handoff_requested: false,
        matched_zero_command: false,
        no_actuation_requested: false,
        ordered_commands,
        command_sha256: Some(command_sha256),
        controller_implemented: true,
        deterministic: true,
        engine_identity_input_count: 0,
        engine_specific_policy_branch_count: 0,
        fallback_controller_active: false,
        model_construction_count: 0,
        world_attempt_count: 0,
        world_build_count: 0,
        solver_step_count: 0,
        physics_state_modified: false,
        prone_to_standing_claimed: false,
        physical_acceptance_authority: false,
        release_authority: false,
    })
}

fn mapping_mutation_controls(
    boundary: &RapierRecoveryBoundaryV1,
    positions: &[f64],
) -> Result<Vec<Value>, String> {
    let fixture = active_control_fixture(boundary)?;
    let mut results = Vec::new();
    let mut record = |mutation_id: &str, rejected: bool| -> Result<(), String> {
        results.push(json!({"mutation_id": mutation_id, "rejected": rejected}));
        if rejected {
            Ok(())
        } else {
            Err(format!(
                "QSDK_R24D45_MAPPING_MUTATION_ACCEPTED:{mutation_id}"
            ))
        }
    };

    let mut value = fixture.clone();
    value.ordered_commands.swap(0, 1);
    record(
        "swapped_command_order",
        map_r24d45_recovery_control_to_public_profile_v1(boundary, &value, positions).is_err(),
    )?;

    let mut value = fixture.clone();
    value.ordered_commands[0].maximum_outer_step_impulse_nms *= 1.01;
    value.command_sha256 =
        Some(digest_serializable(&value.ordered_commands).map_err(|error| error.to_string())?);
    record(
        "inflated_portable_impulse_cap",
        map_r24d45_recovery_control_to_public_profile_v1(boundary, &value, positions).is_err(),
    )?;

    let mut value = fixture.clone();
    value.owner = RecoveryControllerOwnerV1::None;
    record(
        "missing_controller_owner",
        map_r24d45_recovery_control_to_public_profile_v1(boundary, &value, positions).is_err(),
    )?;

    let mut value = fixture.clone();
    value.matched_zero_command = true;
    record(
        "matched_zero_seizes_active_mapping",
        map_r24d45_recovery_control_to_public_profile_v1(boundary, &value, positions).is_err(),
    )?;

    let mut value = fixture.clone();
    value.engine_specific_policy_branch_count = 1;
    record(
        "engine_specific_policy_branch",
        map_r24d45_recovery_control_to_public_profile_v1(boundary, &value, positions).is_err(),
    )?;

    let mut bad_positions = positions.to_vec();
    bad_positions[0] = f64::NAN;
    record(
        "nonfinite_joint_position",
        map_r24d45_recovery_control_to_public_profile_v1(boundary, &fixture, &bad_positions)
            .is_err(),
    )?;
    Ok(results)
}

fn invariant_fixture(boundary: &RapierRecoveryBoundaryV1) -> Result<Value, String> {
    let semantic_step = 1_u64;
    let application = json!({
        "schema_version": APPLICATION_SCHEMA,
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": "candidate_command",
        "phase": "confirm_prone",
        "semantic_step": semantic_step,
        "command_id": "r24d45_zero_world_invariant_fixture",
        "command_sha256": RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256,
        "actuator_profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "actuator_profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "zero_command": false,
        "native_motor_configuration_count": ACTUATOR_COUNT,
        "native_load_bearing_application_count": 0,
        "ordered_pre_step_readbacks": vec![json!({"fixture": true}); ACTUATOR_COUNT],
        "ordered_post_step_readbacks": vec![json!({"fixture": true}); ACTUATOR_COUNT],
        "ordered_applied_impulses": boundary
            .compiled
            .morphology
            .ordered_actuator_ids
            .iter()
            .map(|actuator_id| json!({
                "actuator_id": actuator_id,
                "applied_angular_impulse_nms": 0.0,
                "host_clamped": false,
            }))
            .collect::<Vec<_>>(),
        "actuator_work_rule_id":
            "rapier_signed_motor_impulse_times_centered_relative_joint_velocity_v1",
        "step_actuator_work_j": 0.0,
        "external_impulse_application_count": 0,
        "engine_specific_policy_branch_count": 0,
        "host_step_before": 0,
        "host_step_after": 1,
        "solver_step_before": 0,
        "solver_step_after": 1,
    });
    let application_sha256 = sha256_value(
        &application,
        "QSDK_R24D45_INVARIANT_FIXTURE_APPLICATION_SHA",
    )?;
    let state = json!({
        "schema_version": "sporespore_state_frame_v1",
        "semantic_step": semantic_step,
        "adapter_capability_sha256": RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256,
        "ordered_joint_observations": vec![json!({"fixture": true}); ACTUATOR_COUNT],
        "ordered_contact_observations": vec![json!({"fixture": true}); 4],
    });
    let ordered_foot = boundary
        .compiled
        .morphology
        .ordered_contact_site_ids
        .iter()
        .map(|contact_site_id| json!({"contact_site_id": contact_site_id, "fixture": true}))
        .collect::<Vec<_>>();
    let ordered_body = boundary
        .compiled
        .morphology
        .ordered_body_ids
        .iter()
        .map(|body_id| json!({"body_id": body_id, "fixture": true}))
        .collect::<Vec<_>>();
    let contact_component = json!({
        "ordered_foot_bearing_observations": ordered_foot,
        "ordered_body_clearance_observations": ordered_body,
    });
    let energy = json!({
        "initial_mechanical_energy_j": 1.0,
        "current_mechanical_energy_j": 1.0,
        "cumulative_applied_actuator_work_j": 0.0,
        "cumulative_external_work_j": 0.0,
        "cumulative_dissipated_energy_j": 0.0,
        "source_measurement": true,
    });
    let source_trace = json!({
        "schema_version": "sporespore_rapier_recovery_source_trace_v1",
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": "candidate_command",
        "phase": "confirm_prone",
        "semantic_step": semantic_step,
        "runtime_qualification_sha256": RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256,
        "previous_observation_sha256": Value::Null,
        "application_sha256": application_sha256,
        "state_sha256": sha256_value(&state, "QSDK_R24D45_INVARIANT_FIXTURE_STATE_SHA")?,
        "contact_measurements_sha256":
            sha256_value(&contact_component, "QSDK_R24D45_INVARIANT_FIXTURE_CONTACT_SHA")?,
        "energy_balance_sha256":
            sha256_value(&energy, "QSDK_R24D45_INVARIANT_FIXTURE_ENERGY_SHA")?,
        "host_step_before": 0,
        "host_step_after": 1,
        "solver_step_before": 0,
        "solver_step_after": 1,
        "native_solver_step_count": 1,
        "external_intervention_count": 0,
        "engine_specific_policy_branch_count": 0,
    });
    let source_trace_sha256 =
        sha256_value(&source_trace, "QSDK_R24D45_INVARIANT_FIXTURE_TRACE_SHA")?;
    let observation = json!({
        "schema_version": RECOVERY_OBSERVATION_V1_VERSION,
        "task_id": CANONICAL_PRONE_TO_STANDING_TASK_ID,
        "semantics_id": PORTABLE_RECOVERY_SEMANTICS_ID,
        "actuator_profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "semantic_step": semantic_step,
        "outer_step_duration_s": RECOVERY_OUTER_STEP_DURATION_S,
        "state": state,
        "center_of_mass": {"fixture": true},
        "ordered_foot_bearing_observations": ordered_foot,
        "ordered_body_clearance_observations": ordered_body,
        "applied_actuation": {
            "adapter_id": RAPIER_RECOVERY_ADAPTER_ID,
            "adapter_receipt_sha256": application_sha256,
            "source_semantic_step": semantic_step,
            "command_id": "r24d45_zero_world_invariant_fixture",
            "command_sha256": RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256,
            "actuator_profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
            "actuator_profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
            "zero_command": false,
            "ordered_applied_impulses": application["ordered_applied_impulses"],
            "source_measurement": true,
        },
        "external_interventions": serde_json::to_value(
            RecoveryExternalInterventionLedgerV1::default()
        ).map_err(|error| format!("QSDK_R24D45_INVARIANT_FIXTURE_LEDGER:{error}"))?,
        "controller_ownership": {
            "owner": "recovery",
            "recovery_controller_id": EXACT_S169_RECOVERY_CONTROLLER_ID,
            "stance_controller_id": Value::Null,
            "handoff_event_count": 0,
            "fallback_controller_active": false,
            "source_measurement": true,
        },
        "energy_balance": energy,
        "engine_step_identity": {
            "schema_version": RECOVERY_ENGINE_STEP_IDENTITY_V1_VERSION,
            "source_kind": "native_post_step",
            "adapter_id": RAPIER_RECOVERY_ADAPTER_ID,
            "engine": "rapier_parry_native",
            "capability_sha256": RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256,
            "source_trace_sha256": source_trace_sha256,
            "semantic_step": semantic_step,
            "host_step_before": 0,
            "host_step_after": 1,
            "native_solver_substep_count": 1,
            "post_step_observation": true,
            "engine_identity_exposed_to_policy": false,
        },
    });
    let observation_sha256 = sha256_value(
        &observation,
        "QSDK_R24D45_INVARIANT_FIXTURE_OBSERVATION_SHA",
    )?;
    Ok(json!({
        "schema_version": NATIVE_STEP_SCHEMA,
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": "candidate_command",
        "phase": "confirm_prone",
        "semantic_step": semantic_step,
        "previous_observation_sha256": Value::Null,
        "application": application,
        "application_sha256": application_sha256,
        "source_trace": source_trace,
        "source_trace_sha256": source_trace_sha256,
        "observation": observation,
        "observation_sha256": observation_sha256,
        "host_step_before": 0,
        "host_step_after": 1,
        "solver_step_before": 0,
        "solver_step_after": 1,
        "native_solver_step_count": 1,
        "external_intervention_count": 0,
        "engine_specific_policy_branch_count": 0,
        "world_build_count_for_arm": 1,
        "physical_acceptance_authority": false,
        "prone_to_standing_claimed": false,
        "release_authority": false,
    }))
}

fn invariant_mutation_controls(boundary: &RapierRecoveryBoundaryV1) -> Result<Vec<Value>, String> {
    let fixture = invariant_fixture(boundary)?;
    validate_r24d45_in_run_step_v1(&fixture, None)?;
    let mut results = Vec::new();
    let mut record = |mutation_id: &str, rejected: bool| -> Result<(), String> {
        results.push(json!({"mutation_id": mutation_id, "rejected": rejected}));
        if rejected {
            Ok(())
        } else {
            Err(format!(
                "QSDK_R24D45_INVARIANT_MUTATION_ACCEPTED:{mutation_id}"
            ))
        }
    };

    let mut value = fixture.clone();
    value["application"]["command_id"] = json!("mutated_command");
    record(
        "application_digest_mismatch",
        validate_r24d45_in_run_step_v1(&value, None).is_err(),
    )?;

    let mut value = fixture.clone();
    value["host_step_after"] = json!(2);
    record(
        "host_step_jump",
        validate_r24d45_in_run_step_v1(&value, None).is_err(),
    )?;

    let mut value = fixture.clone();
    value["native_solver_step_count"] = json!(2);
    record(
        "multiple_native_solver_steps",
        validate_r24d45_in_run_step_v1(&value, None).is_err(),
    )?;

    let mut value = fixture.clone();
    value["observation"]["external_interventions"]["root_impulse_application_count"] = json!(1);
    value["observation_sha256"] = json!(sha256_value(
        &value["observation"],
        "QSDK_R24D45_MUTATED_OBSERVATION_SHA",
    )?);
    record(
        "nonzero_external_intervention",
        validate_r24d45_in_run_step_v1(&value, None).is_err(),
    )?;

    let mut value = fixture.clone();
    value["previous_observation_sha256"] = json!(RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256);
    record(
        "broken_previous_observation_chain",
        validate_r24d45_in_run_step_v1(&value, None).is_err(),
    )?;

    let mut value = fixture.clone();
    value["observation"]["engine_step_identity"]["engine_identity_exposed_to_policy"] = json!(true);
    value["observation_sha256"] = json!(sha256_value(
        &value["observation"],
        "QSDK_R24D45_MUTATED_ENGINE_OBSERVATION_SHA",
    )?);
    record(
        "engine_identity_exposed_to_policy",
        validate_r24d45_in_run_step_v1(&value, None).is_err(),
    )?;
    Ok(results)
}

fn initial_observation_sha256(observation: &RecoveryObservationV1) -> Result<String, String> {
    sha256_value(
        &json!({
            "base_pose_world": observation.state.base_pose_world,
            "base_twist_world": observation.state.base_twist_world,
            "ordered_joint_observations": observation.state.ordered_joint_observations,
            "ordered_contact_observations": observation.state.ordered_contact_observations,
            "gravity_world_m_s2": observation.state.gravity_world_m_s2,
            "task_frame": observation.state.task_frame,
            "center_of_mass": observation.center_of_mass,
            "ordered_foot_bearing_observations":
                observation.ordered_foot_bearing_observations,
            "ordered_body_clearance_observations":
                observation.ordered_body_clearance_observations,
            "energy_initial_mechanical_j":
                observation.energy_balance.initial_mechanical_energy_j,
            "energy_current_mechanical_j":
                observation.energy_balance.current_mechanical_energy_j,
        }),
        "QSDK_R24D45_INITIAL_OBSERVATION_SHA",
    )
}

pub(crate) fn initialize_arm_memory_v1(
    boundary: &RapierRecoveryBoundaryV1,
    arm: RecoveryArmKindV1,
) -> Result<RecoverySupervisorMemoryV1, String> {
    let receipt = initialize_recovery_v2(RecoveryInitializeRequestV2 {
        schema_version: RECOVERY_INITIALIZE_REQUEST_V2_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        morphology_context: boundary.morphology_context.clone(),
        adapter_capability: rapier_recovery_capability_v1(),
        arm_kind: arm,
    })
    .map_err(|error| error.to_string())?;
    if receipt.support_status != RecoverySupportStatusV1::SupportedExact
        || receipt.refusal_reason.is_some()
        || !receipt.controller_implemented
        || !receipt.physical_threshold_authority
        || receipt.physical_question_opened
        || receipt.model_construction_count != 0
        || receipt.world_attempt_count != 0
        || receipt.world_build_count != 0
        || receipt.solver_step_count != 0
        || receipt.physics_state_modified
        || receipt.prone_to_standing_claimed
        || receipt.physical_acceptance_authority
        || receipt.release_authority
    {
        return Err("QSDK_R24D45_PORTABLE_INITIALIZATION_INVALID".to_owned());
    }
    receipt
        .memory
        .ok_or_else(|| "QSDK_R24D45_PORTABLE_INITIAL_MEMORY_MISSING".to_owned())
}

fn run_r24d45_arm_v1(
    boundary: &RapierRecoveryBoundaryV1,
    pose: &RapierRecoveryPronePosePlanV1,
    arm: RecoveryArmKindV1,
    maximum_outer_steps: u64,
    runtime_qualification_sha256: &str,
) -> Result<RapierRecoveryArmRunV1, String> {
    if maximum_outer_steps == 0
        || maximum_outer_steps > 1200
        || !valid_sha256(runtime_qualification_sha256)
    {
        return Err("QSDK_R24D45_ARM_BUDGET_OR_RUNTIME_INVALID".to_owned());
    }
    let mut memory = initialize_arm_memory_v1(boundary, arm)?;
    let mut world = build_r24d45_recovery_world_v1(boundary, pose)?;
    let mut control = None::<RecoveryControlReceiptV1>;
    let mut observations = Vec::new();
    let mut invariant_receipts = Vec::new();
    let mut collector_receipts = Vec::new();
    let mut portable_step_receipts = Vec::new();
    let mut planned_control_receipts = Vec::new();
    let mut previous_observation_sha256 = None::<String>;

    for semantic_step in 1..=maximum_outer_steps {
        let phase = memory.phase;
        if matches!(
            phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        ) {
            break;
        }
        let application = apply_and_step_r24d45_recovery_v1(
            &mut world,
            boundary,
            arm,
            phase,
            semantic_step,
            control.as_ref(),
        )?;
        let native = collect_r24d45_native_step_v1(
            &mut world,
            boundary,
            application,
            RapierRecoveryStepContextV1 {
                arm,
                phase,
                semantic_step,
                previous_observation_sha256: previous_observation_sha256.as_deref(),
                runtime_qualification_sha256,
            },
        )?;
        validate_r24d45_in_run_step_v1(
            &native.invariant_receipt,
            previous_observation_sha256.as_deref(),
        )?;
        let collection = rapier_recovery_collection_request_v2(
            native.observation.clone(),
            boundary.morphology_context.clone(),
            runtime_qualification_sha256,
            arm,
            phase,
        )?;
        let collected = collect_rapier_native_recovery_observation_v2(collection.clone())?;
        if collected.support_status != RecoverySupportStatusV1::SupportedExact
            || collected.refusal_reason.is_some()
            || collected.observation_sha256.as_deref() != Some(native.observation_sha256.as_str())
            || !collected.supplied_native_post_step_observation_validated
            // The Rapier adapter collected the native observation above. The
            // engine-neutral collector only validates that supplied sample and
            // must remain a zero-world, zero-step authority of its own.
            || collected.native_runtime_observation_collection_executed
            || collected.engine_identity_exposed_to_controller
            || collected.prone_to_standing_claimed
            || collected.physical_acceptance_authority
            || collected.release_authority
        {
            return Err(format!(
                "QSDK_R24D45_NATIVE_COLLECTION_INVALID:{}:{semantic_step}:status={:?}:refusal={:?}:sha_match={}:validated={}:core_runtime_executed={}:engine_exposed={}",
                arm_id(arm),
                collected.support_status,
                collected.refusal_reason,
                collected.observation_sha256.as_deref() == Some(native.observation_sha256.as_str()),
                collected.supplied_native_post_step_observation_validated,
                collected.native_runtime_observation_collection_executed,
                collected.engine_identity_exposed_to_controller,
            ));
        }
        let stepped = step_recovery_v2(RecoveryStepRequestV2 {
            schema_version: RECOVERY_STEP_REQUEST_V2_VERSION.to_owned(),
            descriptor: r23d60_selected_s169_descriptor(),
            morphology_context: boundary.morphology_context.clone(),
            adapter_capability: rapier_recovery_capability_v1(),
            memory,
            observation: native.observation.clone(),
        })
        .map_err(|error| error.to_string())?;
        if stepped.support_status != RecoverySupportStatusV1::SupportedExact
            || stepped.refusal_reason.is_some()
            || stepped.observation_sha256.as_deref() != Some(native.observation_sha256.as_str())
            || !stepped.post_step_observation_only
            || stepped.phase_skip_permitted
            || !stepped.controller_implemented
            || !stepped.physical_threshold_authority
            || stepped.world_build_count != 0
            || stepped.solver_step_count != 0
            || stepped.physics_state_modified
            || stepped.physical_acceptance_authority
            || stepped.release_authority
        {
            return Err(format!(
                "QSDK_R24D45_PORTABLE_STEP_INVALID:{}:{semantic_step}",
                arm_id(arm)
            ));
        }

        previous_observation_sha256 = Some(native.observation_sha256.clone());
        observations.push(native.observation);
        invariant_receipts.push(native.invariant_receipt);
        collector_receipts.push(
            serde_json::to_value(&collected)
                .map_err(|error| format!("QSDK_R24D45_COLLECTOR_SERIALIZE:{error}"))?,
        );
        portable_step_receipts.push(
            serde_json::to_value(&stepped)
                .map_err(|error| format!("QSDK_R24D45_STEP_SERIALIZE:{error}"))?,
        );
        memory = stepped
            .memory
            .clone()
            .ok_or_else(|| "QSDK_R24D45_PORTABLE_STEP_MEMORY_MISSING".to_owned())?;
        if matches!(
            memory.phase,
            RecoveryPhaseV1::Complete | RecoveryPhaseV1::Failed | RecoveryPhaseV1::Refused
        ) {
            break;
        }
        control = if matches!(
            memory.phase,
            RecoveryPhaseV1::StanceHandoff | RecoveryPhaseV1::StanceDwell
        ) {
            if arm != RecoveryArmKindV1::CandidateCommand {
                return Err("QSDK_R24D45_MATCHED_ZERO_REACHED_STANCE_OWNER".to_owned());
            }
            Some(plan_rapier_recovery_stance_control_v2(
                collection,
                stepped.clone(),
            )?)
        } else {
            let mut next_collection = collection;
            next_collection.phase = memory.phase;
            Some(plan_rapier_recovery_control_v2(
                next_collection,
                memory.phase_steps_observed,
            )?)
        };
        let next_control = control
            .as_ref()
            .ok_or_else(|| "QSDK_R24D45_PLANNED_CONTROL_MISSING".to_owned())?;
        if next_control.support_status != RecoverySupportStatusV1::SupportedExact
            || next_control.refusal_reason.is_some()
            || !next_control.controller_implemented
            || !next_control.deterministic
            || next_control.engine_identity_input_count != 0
            || next_control.engine_specific_policy_branch_count != 0
            || next_control.fallback_controller_active
            || next_control.physics_state_modified
            || next_control.physical_acceptance_authority
            || next_control.release_authority
        {
            return Err(format!(
                "QSDK_R24D45_CONTROL_PLAN_INVALID:{}:{semantic_step}",
                arm_id(arm)
            ));
        }
        planned_control_receipts.push(
            serde_json::to_value(next_control)
                .map_err(|error| format!("QSDK_R24D45_CONTROL_SERIALIZE:{error}"))?,
        );
    }
    if observations.is_empty() {
        return Err("QSDK_R24D45_EMPTY_ARM_TRACE".to_owned());
    }
    let declared_initial_state_sha256 = initial_observation_sha256(&observations[0])?;
    let trace = RecoveryTraceV1 {
        schema_version: RECOVERY_TRACE_V1_VERSION.to_owned(),
        arm_kind: arm,
        declared_initial_state_sha256: declared_initial_state_sha256.clone(),
        observations,
    };
    let arm_result = json!({
        "schema_version": "sporespore_qsdk_r24d45_rapier_recovery_arm_result_v1",
        "route_id": ROUTE_ID,
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "arm_kind": arm_id(arm),
        "initializer_manifest": pose.manifest,
        "initializer_manifest_sha256": pose.manifest_sha256,
        "declared_initial_state_sha256": declared_initial_state_sha256,
        "trace": trace,
        "invariant_receipts": invariant_receipts,
        "collector_receipts": collector_receipts,
        "portable_step_receipts": portable_step_receipts,
        "planned_control_receipts": planned_control_receipts,
        "final_phase": memory.phase,
        "terminal_failure_code": memory.terminal_failure_code,
        "outer_step_count": trace.observations.len(),
        "native_solver_step_count": world.robot.solver_step_count,
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "post_initialization_intervention_count": 0,
        "physics_state_modified": true,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    });
    Ok(RapierRecoveryArmRunV1 { trace, arm_result })
}

fn evaluate_r24d45_paired_traces_v1(
    boundary: &RapierRecoveryBoundaryV1,
    candidate: RecoveryTraceV1,
    matched_zero: RecoveryTraceV1,
) -> Result<RecoveryEvaluationReceiptV1, String> {
    evaluate_recovery_trace_v2(RecoveryEvaluationRequestV2 {
        schema_version: RECOVERY_EVALUATION_REQUEST_V2_VERSION.to_owned(),
        task_id: CANONICAL_PRONE_TO_STANDING_TASK_ID.to_owned(),
        semantics_id: PORTABLE_RECOVERY_SEMANTICS_ID.to_owned(),
        actuator_profile_id: R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID.to_owned(),
        threshold_profile_id: EXACT_S169_DEVELOPMENT_THRESHOLD_PROFILE_ID.to_owned(),
        descriptor: r23d60_selected_s169_descriptor(),
        morphology_context: boundary.morphology_context.clone(),
        adapter_capability: rapier_recovery_capability_v1(),
        candidate_trace: candidate,
        matched_zero_command_trace: matched_zero,
    })
    .map_err(|error| error.to_string())
}

fn r24d45_ghost_arm_summary_v1(run: &RapierRecoveryArmRunV1) -> Result<Value, String> {
    let first = run
        .trace
        .observations
        .first()
        .ok_or_else(|| "QSDK_R24D45_GHOST_FIRST_OBSERVATION_MISSING".to_owned())?;
    let last = run
        .trace
        .observations
        .last()
        .ok_or_else(|| "QSDK_R24D45_GHOST_LAST_OBSERVATION_MISSING".to_owned())?;
    Ok(json!({
        "arm_kind": run.arm_result["arm_kind"],
        "declared_initial_state_sha256": run.trace.declared_initial_state_sha256,
        "trace_sha256": digest_serializable(&run.trace).map_err(|error| error.to_string())?,
        "first_observation_sha256":
            digest_serializable(first).map_err(|error| error.to_string())?,
        "last_observation_sha256":
            digest_serializable(last).map_err(|error| error.to_string())?,
        "outer_step_count": run.trace.observations.len(),
        "native_solver_step_count": run.arm_result["native_solver_step_count"],
        "in_run_invariant_receipt_count": run.arm_result["invariant_receipts"]
            .as_array()
            .map_or(0, Vec::len),
        "collector_receipt_count": run.arm_result["collector_receipts"]
            .as_array()
            .map_or(0, Vec::len),
        "portable_step_receipt_count": run.arm_result["portable_step_receipts"]
            .as_array()
            .map_or(0, Vec::len),
        "planned_control_receipt_count": run.arm_result["planned_control_receipts"]
            .as_array()
            .map_or(0, Vec::len),
        "final_phase": run.arm_result["final_phase"],
        "terminal_failure_code": run.arm_result["terminal_failure_code"],
        "model_construction_count": 1,
        "world_attempt_count": 1,
        "world_build_count": 1,
        "post_initialization_intervention_count": 0,
    }))
}

/// Bounded construction ghost: exactly two native outer steps per arm. It
/// catches construction, routing, collection, and immediate stepping defects;
/// its result is never evidence for the R24D45 physical question.
pub fn run_qsdk_r24d45_rapier_recovery_ghost() -> Result<Value, String> {
    let qualification = run_qsdk_r24d45_rapier_recovery_route_qualification()?;
    let runtime_qualification_sha256 = sha256_value(
        &qualification,
        "QSDK_R24D45_GHOST_RUNTIME_QUALIFICATION_SHA",
    )?;
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let candidate = run_r24d45_arm_v1(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        2,
        &runtime_qualification_sha256,
    )?;
    let matched_zero = run_r24d45_arm_v1(
        &boundary,
        &pose,
        RecoveryArmKindV1::MatchedZeroCommand,
        2,
        &runtime_qualification_sha256,
    )?;
    if candidate.trace.declared_initial_state_sha256
        != matched_zero.trace.declared_initial_state_sha256
    {
        return Err("QSDK_R24D45_GHOST_INITIAL_STATE_MISMATCH".to_owned());
    }
    let candidate_summary = r24d45_ghost_arm_summary_v1(&candidate)?;
    let matched_zero_summary = r24d45_ghost_arm_summary_v1(&matched_zero)?;
    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d45_rapier_recovery_ghost_v1",
        "ok": true,
        "gate_id": GATE_ID,
        "route_id": ROUTE_ID,
        "question_class": "diagnostic_pre_freeze_ghost",
        "runtime_qualification_sha256": runtime_qualification_sha256,
        "candidate": candidate_summary,
        "matched_zero_command": matched_zero_summary,
        "maximum_outer_steps_per_arm": 2,
        "maximum_total_outer_steps": 4,
        "actual_total_outer_steps":
            candidate.trace.observations.len() + matched_zero.trace.observations.len(),
        "official_evidence": false,
        "behavior_success_required": false,
        "result_may_satisfy_r24d45": false,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

/// Execute the sole prospectively declared paired Rapier development attempt.
/// The outer launcher must independently prove a clean, pushed source and bind
/// the retained official qualification receipt to `runtime_qualification_sha256`.
pub fn run_qsdk_r24d45_rapier_recovery_development_attempt(
    runtime_qualification_sha256: &str,
) -> Result<Value, String> {
    if !valid_sha256(runtime_qualification_sha256) {
        return Err("QSDK_R24D45_DEVELOPMENT_QUALIFICATION_SHA_INVALID".to_owned());
    }
    let qualification = run_qsdk_r24d45_rapier_recovery_route_qualification()?;
    let expected_qualification_sha256 =
        sha256_value(&qualification, "QSDK_R24D45_DEVELOPMENT_QUALIFICATION_SHA")?;
    if runtime_qualification_sha256 != expected_qualification_sha256 {
        return Err(format!(
            "QSDK_R24D45_DEVELOPMENT_QUALIFICATION_SHA_MISMATCH:expected={expected_qualification_sha256}:observed={runtime_qualification_sha256}"
        ));
    }

    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let candidate = run_r24d45_arm_v1(
        &boundary,
        &pose,
        RecoveryArmKindV1::CandidateCommand,
        1200,
        runtime_qualification_sha256,
    )?;
    let matched_zero = run_r24d45_arm_v1(
        &boundary,
        &pose,
        RecoveryArmKindV1::MatchedZeroCommand,
        1200,
        runtime_qualification_sha256,
    )?;
    if candidate.trace.declared_initial_state_sha256
        != matched_zero.trace.declared_initial_state_sha256
    {
        return Err("QSDK_R24D45_DEVELOPMENT_INITIAL_STATE_MISMATCH".to_owned());
    }

    let candidate_trace_sha256 =
        digest_serializable(&candidate.trace).map_err(|error| error.to_string())?;
    let matched_zero_trace_sha256 =
        digest_serializable(&matched_zero.trace).map_err(|error| error.to_string())?;
    let candidate_outer_steps = candidate.trace.observations.len();
    let matched_zero_outer_steps = matched_zero.trace.observations.len();
    let actual_total_outer_steps = candidate_outer_steps + matched_zero_outer_steps;
    if candidate_outer_steps > 1200
        || matched_zero_outer_steps > 1200
        || actual_total_outer_steps > 2400
        || candidate.arm_result["native_solver_step_count"].as_u64()
            != Some(candidate_outer_steps as u64)
        || matched_zero.arm_result["native_solver_step_count"].as_u64()
            != Some(matched_zero_outer_steps as u64)
    {
        return Err("QSDK_R24D45_DEVELOPMENT_PHYSICAL_BUDGET_INVALID".to_owned());
    }

    let evaluation = evaluate_r24d45_paired_traces_v1(
        &boundary,
        candidate.trace.clone(),
        matched_zero.trace.clone(),
    )?;
    if evaluation.model_construction_count != 0
        || evaluation.world_attempt_count != 0
        || evaluation.world_build_count != 0
        || evaluation.solver_step_count != 0
        || evaluation.physics_state_modified
        || evaluation.physical_acceptance_authority
        || evaluation.release_authority
    {
        return Err("QSDK_R24D45_DEVELOPMENT_EVALUATOR_AUTHORITY_INVALID".to_owned());
    }
    let evaluation_sha256 = digest_serializable(&evaluation).map_err(|error| error.to_string())?;
    let result_classification = match evaluation.verdict {
        RecoveryEvaluationVerdictV1::PhysicalDevelopmentPassed => {
            "valid_complete_positive_exact_nominal_rapier_development"
        }
        RecoveryEvaluationVerdictV1::PhysicalDevelopmentFailed => {
            "valid_complete_negative_exact_nominal_rapier_development"
        }
        RecoveryEvaluationVerdictV1::PhysicalDevelopmentIncomplete => {
            "valid_incomplete_exact_nominal_rapier_development"
        }
        RecoveryEvaluationVerdictV1::Refused => {
            "invalid_or_refused_exact_nominal_rapier_development"
        }
        RecoveryEvaluationVerdictV1::SyntheticCanaryPassed
        | RecoveryEvaluationVerdictV1::SyntheticCanaryFailed => {
            "invalid_synthetic_verdict_for_native_rapier_development"
        }
    };

    Ok(json!({
        "schema_version": "sporespore_qsdk_r24d45_rapier_recovery_development_result_v1",
        "ok": true,
        "gate_id": GATE_ID,
        "route_id": ROUTE_ID,
        "question_class": "development",
        "cell_id": CELL_ID,
        "seed": CELL_SEED,
        "runtime_qualification_sha256": runtime_qualification_sha256,
        "result_classification": result_classification,
        "candidate_trace_sha256": candidate_trace_sha256,
        "matched_zero_trace_sha256": matched_zero_trace_sha256,
        "evaluation_sha256": evaluation_sha256,
        "candidate": candidate.arm_result,
        "matched_zero_command": matched_zero.arm_result,
        "evaluation": evaluation,
        "maximum_outer_steps_per_arm": 1200,
        "maximum_total_outer_steps": 2400,
        "actual_total_outer_steps": actual_total_outer_steps,
        "maximum_native_solver_steps_per_outer_step": 1,
        "actual_total_native_solver_steps": actual_total_outer_steps,
        "model_construction_count": 2,
        "world_attempt_count": 2,
        "world_build_count": 2,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "held_out_cells_remain_sealed": true,
        "threshold_change_count": 0,
        "outer_clean_pushed_source_attestation_required": true,
        "official_qualification_receipt_binding_required": true,
        "result_may_satisfy_r24d45": true,
        "prone_to_standing_claimed": evaluation.prone_to_standing_claimed,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

/// Qualify the complete typed dependency path without constructing or
/// stepping a Rapier world. The physical worker consumes these exact pure
/// helpers after a clean prospective freeze.
pub fn run_qsdk_r24d45_rapier_recovery_route_qualification() -> Result<Value, String> {
    let contract = validate_contract()?;
    let boundary = compile_r24d45_recovery_boundary_v1()?;
    let pose = plan_r24d45_canonical_prone_pose_v1(&boundary)?;
    let control = active_control_fixture(&boundary)?;
    let mapping = map_r24d45_recovery_control_to_public_profile_v1(
        &boundary,
        &control,
        &pose.ordered_joint_positions_rad,
    )?;
    let mapping_mutations =
        mapping_mutation_controls(&boundary, &pose.ordered_joint_positions_rad)?;
    let invariant_mutations = invariant_mutation_controls(&boundary)?;
    let capability_sha256 =
        digest_serializable(&rapier_recovery_capability_v1()).map_err(|error| error.to_string())?;
    let morphology_context_sha256 =
        digest_serializable(&boundary.morphology_context).map_err(|error| error.to_string())?;
    let profile = recovery_development_profile_v1();
    if profile.task_id != CANONICAL_PRONE_TO_STANDING_TASK_ID
        || profile.semantics_id != PORTABLE_RECOVERY_SEMANTICS_ID
        || profile.actuator_profile_id != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID
        || profile.actuator_profile_sha256 != R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256
        || profile.thresholds.total_timeout_steps != 1200
        || profile.thresholds.stance_dwell_steps != 60
        || profile.physical_execution_authorized
        || profile.physical_acceptance_authority
        || profile.release_authority
    {
        return Err("QSDK_R24D45_FROZEN_PROFILE_INVALID".to_owned());
    }
    Ok(json!({
        "schema_version": QUALIFICATION_SCHEMA,
        "ok": true,
        "gate_id": GATE_ID,
        "route_id": ROUTE_ID,
        "question_class": "non_physical_native_dependency_route_qualification",
        "physical_question_class": contract["question_class"],
        "cell_id": CELL_ID,
        "cell_seed": CELL_SEED,
        "held_out_cell_access_count": 0,
        "held_out_selector_invocation_count": 0,
        "held_out_cells_remain_sealed": true,
        "recovery_morphology_id": boundary.recovery_receipt.recovery_morphology_id,
        "recovery_morphology_spec_sha256":
            boundary.recovery_receipt.recovery_morphology_spec_sha256,
        "morphology_context_sha256": morphology_context_sha256,
        "initializer_manifest": pose.manifest,
        "initializer_manifest_sha256": pose.manifest_sha256,
        "initializer_body_count": pose.ordered_body_poses.len(),
        "initializer_joint_count": pose.ordered_joint_positions_rad.len(),
        "capability_sha256": capability_sha256,
        "actuator_profile_id": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_ID,
        "actuator_profile_sha256": R23D60_SELECTED_S169_ACTUATOR_CAP_PROFILE_SHA256,
        "mapped_actuation_sha256": digest_serializable(&mapping.actuation)
            .map_err(|error| error.to_string())?,
        "canonical_actuation_sha256": digest_serializable(&mapping.canonical)
            .map_err(|error| error.to_string())?,
        "host_mapping_sha256": digest_serializable(&mapping.host_mapping)
            .map_err(|error| error.to_string())?,
        "mapped_command_count": mapping.host_mapping.ordered_commands.len(),
        "mapping_mutation_rejection_count": mapping_mutations.len(),
        "mapping_mutation_results": mapping_mutations,
        "in_run_invariant_mutation_rejection_count": invariant_mutations.len(),
        "in_run_invariant_mutation_results": invariant_mutations,
        "total_mutation_rejection_count":
            mapping_mutations.len() + invariant_mutations.len(),
        "native_initializer_source_present": true,
        "native_observation_collector_source_present": true,
        "native_actuation_application_source_present": true,
        "in_run_invariant_validator_source_present": true,
        "forced_failure_invariant_control_present": true,
        "zero_world_qualification_complete": true,
        "rigid_body_set_construction_count": 0,
        "collider_set_construction_count": 0,
        "physics_pipeline_construction_count": 0,
        "model_construction_count": 0,
        "world_attempt_count": 0,
        "world_build_count": 0,
        "solver_step_count": 0,
        "physics_state_modified": false,
        "physical_execution_authorized": false,
        "prone_to_standing_claimed": false,
        "physical_acceptance_authority": false,
        "release_authority": false,
    }))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn exact_recovery_dependency_route_stays_zero_world() {
        let receipt = run_qsdk_r24d45_rapier_recovery_route_qualification().unwrap();
        assert_eq!(receipt["ok"], true);
        assert_eq!(receipt["initializer_body_count"], BODY_COUNT);
        assert_eq!(receipt["initializer_joint_count"], ACTUATOR_COUNT);
        assert_eq!(receipt["mapped_command_count"], ACTUATOR_COUNT);
        assert_eq!(receipt["mapping_mutation_rejection_count"], 6);
        assert_eq!(receipt["in_run_invariant_mutation_rejection_count"], 6);
        assert_eq!(receipt["total_mutation_rejection_count"], 12);
        assert_eq!(receipt["world_build_count"], 0);
        assert_eq!(receipt["solver_step_count"], 0);
        assert_eq!(receipt["zero_world_qualification_complete"], true);
        assert_eq!(receipt["physical_execution_authorized"], false);
        assert_eq!(receipt["prone_to_standing_claimed"], false);
    }

    #[test]
    fn development_entrypoint_rejects_wrong_qualification_digest_before_world() {
        let error = run_qsdk_r24d45_rapier_recovery_development_attempt(
            RUNTIME_QUALIFICATION_PLACEHOLDER_SHA256,
        )
        .unwrap_err();
        assert!(error.starts_with("QSDK_R24D45_DEVELOPMENT_QUALIFICATION_SHA_MISMATCH:"));
    }
}
