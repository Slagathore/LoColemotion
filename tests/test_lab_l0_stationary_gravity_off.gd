extends SceneTree

const L0RunnerScript := preload("res://scripts/lab/l0_runner.gd")
const SchemaValidatorScript := preload(
	"res://scripts/lab/schema_validator.gd")
const ObserverProfileScript := preload(
	"res://scripts/lab/observer_profile.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Lab L0.0 stationary gravity-off calibration ===")
	var runner = L0RunnerScript.new()
	var contact_profile: Dictionary = ObserverProfileScript.resolve(
		&"full_contacts_v1")
	var result: Dictionary = await runner.run_stationary(
		self, 60, contact_profile)
	_check(String(result.get("physics_backend", "")) == "Jolt Physics",
			"fixture ran in the configured Jolt backend")
	_check(int(result.get("sample_count", 0)) == 61,
			"61 direct-state samples cover 60 explicit intervals")
	_check(int(result.get("direct_state_callback_count", 0)) >= 61,
			"RigidBody3D integration callback observed every requested epoch")
	_check(int(result.get("untagged_callback_count", -1)) == 0,
			"no callback was silently assigned to an adjacent epoch")
	_check(bool(result.get("coherent_frame_identity", false)),
			"frame, physics-step, epoch, and callback phases remain coherent")
	_check(float(result.get("max_position_error_m", INF)) <= 1.0e-7,
			"gravity-off stationary body acquires no invented translation")
	_check(float(result.get("max_velocity_error_m_s", INF)) <= 1.0e-7,
			"gravity-off stationary body acquires no invented velocity")
	_check(float(result.get("max_kinetic_energy_j", INF)) <= 1.0e-12,
			"stationary fixture acquires no invented kinetic energy")
	_check(int(result.get("total_contact_count", -1)) == 0,
			"isolated body reports no invented contact")
	_check(bool(result.get("observer_contacts_enabled", false))
			and int(result.get("observer_contact_cap_per_body", 0)) == 32,
			"zero-contact claim comes from enabled, capacity-pinned observation")
	_check(bool(result.get("finite", false)),
			"all recorded stationary evidence is finite")
	var first_frame: Dictionary = result["frames"][0]
	var whole_body: Dictionary = first_frame.get("whole_body", {})
	_check(
		is_equal_approx(float(whole_body.get("total_mass_kg", NAN)), 2.0)
			and _length(whole_body.get(
				"linear_momentum_world_n_s", [])) <= 1.0e-12,
		"frame derives whole-body mass and momentum from the same capture epoch")
	_check(
		whole_body.get("angular_momentum_about_com_world_n_m_s") == null
			and whole_body.get("availability", {}).has(
				"/angular_momentum_about_com_world_n_m_s"),
		"uncertified angular momentum remains explicit null with availability")
	_check(
		bool(result.get("observer_contract_satisfied", false)),
		"every advertised observer channel has a measured or derived provider")
	var recorded_frame: Dictionary = (
		first_frame as Dictionary).duplicate(true)
	recorded_frame["schema"] = "sporespore.lab.frame.v1"
	recorded_frame["run_id"] = "l0-stationary-test"
	var schema_result := SchemaValidatorScript.validate_named(
		"frame_v1", recorded_frame)
	_check(bool(schema_result.get("ok", false)),
			"recorded frame satisfies the strict frame_v1 evidence schema")
	if not bool(schema_result.get("ok", false)):
		printerr(SchemaValidatorScript.format_errors(schema_result))
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _length(value: Variant) -> float:
	if value is Array and value.size() == 3:
		return Vector3(
			float(value[0]),
			float(value[1]),
			float(value[2])).length()
	return INF
