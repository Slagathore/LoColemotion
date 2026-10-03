extends SceneTree
## Pure calls to the production angle helper; no bodies, motors or physics steps.
const World := preload("res://sdk/adapters/godot/gdscript/recovery_native_world_v1.gd")
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or FileAccess.file_exists(args[1]):
		quit(1)
		return
	var payload: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	if not (payload is Dictionary) or payload.get("schema_version") != "sporespore_r10db_native_angle_inputs_v1":
		quit(2)
		return
	var checks := _controls()
	if checks.values().has(false):
		quit(3)
		return
	var rows: Array = []
	for value: Variant in payload.poses:
		var pose: Dictionary = value
		var bases: Array[Basis] = []
		for columns: Array in pose.basis_columns:
			bases.append(Basis(_vector(columns[0]), _vector(columns[1]), _vector(columns[2])))
		if bases.size() != 9:
			quit(4)
			return
		var angles: Array[float] = []
		for leg in range(4):
			angles.append(World._signed_relative_angle_z(bases[0], bases[1 + 2 * leg]))
			angles.append(World._signed_relative_angle_z(bases[1 + 2 * leg], bases[2 + 2 * leg]))
		rows.append({"index": pose.index, "native_joint_positions_rad": angles})
	var result := {"schema_version": "sporespore_r10db_native_angle_outputs_v1",
		"checks": checks, "poses": rows, "world_build_count": 0, "solver_step_count": 0,
		"motor_commands_applied": 0, "physical_acceptance_authority": false, "release_authority": false}
	var stream := FileAccess.open(args[1], FileAccess.WRITE)
	if stream == null:
		quit(5)
		return
	stream.store_string(Transport.stringify(result) + "\n")
	stream.close()
	print("R10DB_NATIVE_ANGLES ", rows.size())
	quit(0)

func _vector(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2]))

func _controls() -> Dictionary:
	var positive := Basis(Vector3.BACK, 0.3)
	var negative := Basis(Vector3.BACK, -0.3)
	var common := Basis(Vector3(0.2, 0.5, -0.3).normalized(), 0.8)
	var off_axis := Basis(Vector3.RIGHT, 0.2) * positive
	var a := World._signed_relative_angle_z(Basis.IDENTITY, off_axis)
	return {
		"identity": World._signed_relative_angle_z(Basis.IDENTITY, Basis.IDENTITY) == 0.0,
		"positive_z": abs(World._signed_relative_angle_z(Basis.IDENTITY, positive) - 0.3) < 1e-6,
		"negative_z": abs(World._signed_relative_angle_z(Basis.IDENTITY, negative) + 0.3) < 1e-6,
		"common_rotation_positive": abs(World._signed_relative_angle_z(common, common * positive) - 0.3) < 1e-6,
		"common_rotation_negative": abs(World._signed_relative_angle_z(common, common * negative) + 0.3) < 1e-6,
		"off_axis_not_planar_angle": a > 0.31,
		"off_axis_common_rotation": abs(World._signed_relative_angle_z(common, common * off_axis) - a) < 1e-6,
		"opposite_off_axis_sign": World._signed_relative_angle_z(Basis.IDENTITY, Basis(Vector3.RIGHT, 0.2) * negative) < -0.31,
	}
