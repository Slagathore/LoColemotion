extends SceneTree

const L0RunnerScript := preload("res://scripts/lab/l0_runner.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0.3 observer A/B calibration ===")
	var runner = L0RunnerScript.new()
	var result: Dictionary = await runner.run_observer_ab(self, 60)
	_check(bool(result.get("finite", false)),
			"both observer runs produced finite evidence")
	_check(String(result.get("adapter_id", ""))
			== "rigid_body_integrate_forces_v1",
			"comparison pins the exact direct-state adapter")
	_check(String(result.get("minimal_profile_id", ""))
			== "minimal_state_v1"
			and String(result.get("full_profile_id", ""))
			== "full_state_v1",
			"comparison pins both versioned observer profiles")
	_check(not bool(result.get("minimal_contacts_enabled", true))
			and not bool(result.get("full_contacts_enabled", true)),
			"minimal/full state profiles both keep contact capture disabled")
	_check(int(result.get("full_channel_count", 0))
			> int(result.get("minimal_channel_count", 0))
			and String(result.get("full_channel_set_sha256", ""))
				!= String(result.get("minimal_channel_set_sha256", "")),
			"A/B changes a versioned, hashed observer channel set")
	_check(int((result.get("full", {}) as Dictionary).get(
			"observer_projected_channel_count", 0))
			> int((result.get("minimal", {}) as Dictionary).get(
			"observer_projected_channel_count", 0)),
			"full observation executes a strictly larger measured projection")
	_check(
		bool((result["minimal"] as Dictionary).get(
			"observer_contract_satisfied", false))
		and bool((result["full"] as Dictionary).get(
			"observer_contract_satisfied", false))
		and bool((result["contact"] as Dictionary).get(
			"observer_contract_satisfied", false)),
		"every advertised channel has an explicit measured or derived provider")
	_check(int(result.get("compared_frame_count", 0)) == 61,
			"observer profiles compare every corresponding frame")
	_check(bool(result.get("structural_identity", false)),
			"observer profiles preserve callback and epoch structure")
	_check(float(result.get("max_position_delta_m", INF)) <= 2.0e-5,
			"expanded observation stays inside the position perturbation envelope")
	_check(float(result.get("max_velocity_delta_m_s", INF)) <= 1.0e-6,
			"expanded observation stays inside the velocity perturbation envelope")
	_check(String(result.get("contact_profile_id", ""))
			== "full_contacts_v1"
			and bool(result.get(
				"contact_profile_contacts_enabled", false))
			and int(result.get("contact_profile_cap_per_body", 0)) == 32,
			"contact parity pins the exact enabled profile and cap")
	_check(int(result.get("contact_compared_frame_count", 0)) == 61
			and bool(result.get("contact_structural_identity", false)),
			"contact observation preserves every callback/epoch pair")
	_check(float(result.get(
			"max_contact_profile_position_delta_m", INF)) <= 2.0e-5
			and float(result.get(
				"max_contact_profile_velocity_delta_m_s", INF)) <= 1.0e-6,
			"contact observation passes its measured perturbation envelope")
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)
