extends RefCounted
## Prospective R10L identities; actual ramp and hold laws remain their native policies.
const ID := "r10l_v52_partial_fall_recovery_route_v1"
const POLICY := "sporespore_balanced_wave_recovery_extended_support_transfer_v1"
const ENTRY := "r10l_v52_joint_bounded_contact_gated_v1"
const START := "r10l_v52_front_left_first_post_interaction_v1"
const ENTRY_ALIAS := "r10l_joint_pose_entry_v1"
const HOLD_ALIAS := "r10l_v50_zero_amplitude_hold_v1"
const PATH := "res://sdk/recovery/r10l_v52_walking_route_contract_v1.json"
const TASK_PATH := "res://sdk/recovery/r10l_extended_support_transfer_finite_cycle_contract_v1.json"
const ENTRY_PATH := "res://sdk/recovery/r10l_joint_pose_entry_policy_contract_v1.json"
const HOLD_PATH := "res://sdk/recovery/r10l_v50_hold_policy_contract_v1.json"
static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
static var task: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TASK_PATH))
static var entry_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ENTRY_PATH))
static var hold_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HOLD_PATH))

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

const PREFIX_PROFILE := "r10l_declared_development_prefix_phase_v1"

static func prefix_selection_v1(seed_value: int, profile: String) -> Dictionary:
	if profile != PREFIX_PROFILE: return {}
	var phase := 241 if seed_value == 40441 else 243 if seed_value == 40443 else -1
	if phase < 0: return {}
	return {"schema_version": "sporespore_r10l_prefix_phase_selection_v1", "profile_id": profile,
		"seed": seed_value, "prefix_phase": phase,
		"source_design_sha256": task.design_record.sha256,
		"physical_acceptance_authority": false, "release_authority": false}

static func prefix_gait_steps_v1(seed_value: int, profile: String) -> Dictionary:
	var selected := prefix_selection_v1(seed_value, profile)
	if selected.is_empty(): return {}
	return {"front_left": selected.prefix_phase, "front_right": selected.prefix_phase,
		"rear_left": selected.prefix_phase, "rear_right": selected.prefix_phase}
