extends RefCounted
## Prospective R10R identities; actual ramp and hold laws remain their native policies.
const ID := "r10r_v55_upright_recovery_route_v1"
const POLICY := "sporespore_balanced_wave_recovery_initialized_zero_brake_v1"
const ENTRY := "r10r_v55_joint_bounded_contact_gated_v1"
const START := "r10r_v55_front_left_first_post_interaction_v1"
const ENTRY_ALIAS := "r10r_joint_pose_entry_v1"
const HOLD_ALIAS := "r10r_v50_zero_amplitude_hold_v1"
const PATH := "res://sdk/recovery/r10r_v55_walking_route_contract_v2.json"
const TASK_PATH := "res://sdk/recovery/r10r_upright_finite_cycle_contract_v2.json"
const ENTRY_PATH := "res://sdk/recovery/r10r_joint_pose_entry_policy_contract_v2.json"
const HOLD_PATH := "res://sdk/recovery/r10r_v50_hold_policy_contract_v2.json"
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
static var task: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TASK_PATH))
static var entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENTRY_PATH))
static var hold_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOLD_PATH))

static func native_identity_consistent_v1() -> bool:
	var composition: Dictionary = task.get("controller_composition", {})
	return (composition.get("native_runtime_sha256") == contract.get("runtime_sha256")
		and composition.get("post_interaction_walking") == POLICY and contract.get("policy_id") == POLICY)

static func path_for_v1(id: String) -> String:
	return PATH if id == ID else ENTRY_PATH if id == ENTRY_ALIAS else HOLD_PATH if id == HOLD_ALIAS else ""

static func contract_for_v1(id: String) -> Dictionary:
	return contract if id == ID else entry_contract if id == ENTRY_ALIAS else hold_contract if id == HOLD_ALIAS else {}

static func alias_binding_v1(id: String, segment: String) -> Dictionary:
	var fixed := contract_for_v1(id)
	if id not in [ENTRY_ALIAS, HOLD_ALIAS] or fixed.get("selection_id") != id or segment not in fixed.get("allowed_segment_ids", []):
		return {}
	var policy := "sporespore_balanced_wave_joint_pose_entry_v1" if id == ENTRY_ALIAS else "sporespore_balanced_wave_recovery_startup_reference_velocity_v1"
	if fixed.get("policy_id") != policy or fixed.get("physical_acceptance_authority") != false or fixed.get("release_authority") != false:
		return {}
	for key in ["native_component_record", "runtime_binding"]:
		if "sha256:" + FileAccess.get_sha256("res://" + fixed[key]) != fixed[key + "_sha256"]:
			return {}
	return {"policy_id": policy, "policy_digest": "sha256:" + FileAccess.get_sha256(path_for_v1(id)), "development": true}

const PREFIX_PROFILE := "r10r_declared_development_prefix_phase_v1"

static func prefix_selection_v1(seed_value: int, profile: String) -> Dictionary:
	if profile != PREFIX_PROFILE: return {}
	var phase: int = {40946: 246, 40945: 245, 40941: 241, 40943: 243}.get(seed_value, -1)
	if phase < 0: return {}
	return {"schema_version": "sporespore_r10r_prefix_phase_selection_v1", "profile_id": profile,
		"seed": seed_value, "prefix_phase": phase,
		"source_design_sha256": task.design_record.sha256,
		"physical_acceptance_authority": false, "release_authority": false}

static func prefix_gait_steps_v1(seed_value: int, profile: String) -> Dictionary:
	var selected := prefix_selection_v1(seed_value, profile)
	if selected.is_empty(): return {}
	return {"front_left": selected.prefix_phase, "front_right": selected.prefix_phase,
		"rear_left": selected.prefix_phase, "rear_right": selected.prefix_phase}
