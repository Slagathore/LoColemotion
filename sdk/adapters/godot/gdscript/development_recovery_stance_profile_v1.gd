extends RefCounted

## This same file is compiled into Rust; no hand-copied controller mapping.
const PATH := "res://sdk/core/contracts/recovery_candidate_stance_profiles_v1.json"
const SUCCESSOR_PATH := "res://sdk/core/contracts/recovery_candidate_stance_profiles_v2.json"
const DAMPED_PATH := "res://sdk/core/contracts/recovery_candidate_stance_profiles_v3.json"
const WORLD_VERTICAL_PATH := "res://sdk/core/contracts/recovery_candidate_stance_profiles_v4.json"
const DAMPED_NEUTRAL_PATH := "res://sdk/core/contracts/recovery_candidate_stance_profiles_v5.json"
const RAMPED_NEUTRAL_PATH := "res://sdk/core/contracts/recovery_candidate_stance_profiles_v6.json"
static var _contract: Dictionary = _load_contract_v1()

static func _load_contract_v1() -> Dictionary:
	var base: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	var successor: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SUCCESSOR_PATH))
	base["profiles"].append_array(successor["profiles"])
	var damped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DAMPED_PATH))
	base["profiles"].append_array(damped["profiles"])
	var world_vertical: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WORLD_VERTICAL_PATH))
	base["profiles"].append_array(world_vertical["profiles"])
	var neutral: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DAMPED_NEUTRAL_PATH))
	base["profiles"].append_array(neutral["profiles"])
	var ramped: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RAMPED_NEUTRAL_PATH))
	base["profiles"].append_array(ramped["profiles"])
	return base

static func profile_for_recovery_v1(id: String) -> Dictionary:
	# V21 and V22 native compositions explicitly delegate their stance mapping to
	# V20. Preserve the requested recovery identity in the returned profile.
	if id in ["sporespore_exact_s169_partial_direct_neutral_controller_v21",
		"sporespore_exact_s169_partial_pose_geometry_controller_v22",
		"sporespore_exact_s169_partial_load_seeking_controller_v23",
		"sporespore_exact_s169_partial_downward_rise_controller_v24",
		"sporespore_exact_s169_partial_concurrent_load_rise_controller_v25",
		"sporespore_exact_s169_partial_hip_recenter_controller_v26",
		"sporespore_exact_s169_partial_support_anchored_controller_v27",
		"sporespore_exact_s169_partial_progressive_headroom_controller_v28",
		"sporespore_exact_s169_partial_native_reference_controller_v29"]:
		var inherited := profile_for_recovery_v1("sporespore_exact_s169_prone_to_standing_controller_v20")
		inherited["recovery_controller_id"] = id
		return inherited
	for profile in _contract["profiles"]:
		if profile["recovery_controller_id"] == id:
			return profile.duplicate(true)
	return {}

static func for_recovery_v1(id: String) -> String:
	if id in ["sporespore_exact_s169_partial_direct_neutral_controller_v21",
		"sporespore_exact_s169_partial_pose_geometry_controller_v22",
		"sporespore_exact_s169_partial_load_seeking_controller_v23",
		"sporespore_exact_s169_partial_downward_rise_controller_v24",
		"sporespore_exact_s169_partial_concurrent_load_rise_controller_v25",
		"sporespore_exact_s169_partial_hip_recenter_controller_v26",
		"sporespore_exact_s169_partial_support_anchored_controller_v27",
		"sporespore_exact_s169_partial_progressive_headroom_controller_v28",
		"sporespore_exact_s169_partial_native_reference_controller_v29"]:
		return for_recovery_v1("sporespore_exact_s169_prone_to_standing_controller_v20")
	for profile in _contract["profiles"]:
		if profile["recovery_controller_id"] == id:
			return profile["controller_id"]
	return _contract["default_controller_id"]

static func registered_v1(id: String) -> bool:
	if id == _contract["default_controller_id"]:
		return true
	for profile in _contract["profiles"]:
		if profile["controller_id"] == id:
			return true
	return false
