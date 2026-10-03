extends SceneTree

## QSDK-R24D7 dual-mode worker.
##
## `zero_world_preflight` proves the instrumented binding, frozen fixture, and
## complete evaluator-shaped Godot serialization envelope without constructing
## a body, joint, space, or world. `physical` is reachable only through the
## clean-pushed supervisor's exact nonce/source handshake and constructs the
## single declared development world.

const RigScript := preload(
	"res://scripts/lab/rigs/r24d7_godot_jolt_one_hinge_telemetry_rig.gd"
)

const RAW_SCHEMA := "sporespore_qsdk_r24d7_godot_jolt_one_hinge_raw_report_v1"
const TELEMETRY_SCHEMA := "sporespore.godot_jolt_hinge_motor_telemetry.v1"
const CLASS_NAME := &"JoltPhysicsServer3D"
const METHOD_NAME := &"hinge_joint_get_motor_telemetry"
const TERMINATION_PROTOCOL_ID := "godot_4_7_gdscript_shutdown_containment_v1"
const SUPERVISED_TERMINATION_ENV := "SPORESPORE_R24D7_SUPERVISED_TERMINATION"
const TERMINATION_NONCE_ENV := "SPORESPORE_R24D7_TERMINATION_NONCE"
const EXECUTION_NONCE_ENV := "SPORESPORE_R24D7_EXECUTION_NONCE"
const SOURCE_COMMIT_ENV := "SPORESPORE_R24D7_SOURCE_COMMIT"
const ZERO_WORLD_TEMPLATE_PATH := "res://zero_world_template.json"
const INTEGRAL_VARIANT_SCHEMA_PATH := "res://integral_variant_schema.json"
const INTEGRAL_VARIANT_SCHEMA_ID := "QSDK-R24D7-INTEGRAL-VARIANT-SCHEMA-V1"
const EXPECTED_INTEGRAL_PATH_FAMILY_COUNT := 21
const EXPECTED_INTEGRAL_OCCURRENCE_COUNT := 313
const EXPECTED_PREDECESSOR_STRICT_OCCURRENCE_COUNT := 234
const EXIT_DRAIN_PROCESS_FRAME_COUNT := 2
const EXPECTED_CELL_IDS := [
	"drive_positive",
	"drive_negative",
	"brake_positive",
	"brake_negative",
	"disabled_positive",
	"disabled_negative",
	"limit_positive",
	"limit_negative",
	"sleep_stale",
]

var _exit_scheduled := false
var _pending_exit_code := 1
var _pending_receipt_kind := ""
var _pending_exit_process_frames := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arguments := _parse_user_arguments(OS.get_cmdline_user_args())
	var mode := String(arguments.get("mode", ""))
	if mode != "zero_world_preflight" and mode != "physical":
		_emit_authorization_failure("R24D7_MODE_INVALID")
		return
	var nonce := String(arguments.get("nonce", ""))
	var source_commit := String(arguments.get("source_commit", ""))
	if (
		nonce.length() != 32
		or source_commit.length() != 40
		or OS.get_environment(EXECUTION_NONCE_ENV) != nonce
		or OS.get_environment(SOURCE_COMMIT_ENV) != source_commit
	):
		_emit_authorization_failure("R24D7_AUTHORIZATION_HANDSHAKE_INVALID")
		return
	if mode == "zero_world_preflight":
		_run_zero_world_preflight(source_commit, nonce)
		return
	await _run_physical(source_commit, nonce)


func _run_zero_world_preflight(source_commit: String, nonce: String) -> void:
	var description: Dictionary = RigScript.describe()
	var engine := _engine_receipt()
	var class_registered := bool(engine["telemetry_class_registered"])
	var method_registered := bool(engine["telemetry_method_registered"])
	var invalid_rid_refused := false
	if class_registered and method_registered:
		invalid_rid_refused = (
			JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
		)
	var cell_ids: Array = description.get("cell_ids_in_order", [])
	var engine_freeze_matches := _engine_receipt_is_frozen(engine)
	var fixture_description_gates := _fixture_description_gate_receipt(description)
	var fixture_description_matches := _fixture_description_is_frozen(description)
	var template_value: Variant = _load_zero_world_template()
	var template_loaded := template_value is Dictionary
	var template_matches_declared_fixture := false
	var integral_schema_load_receipt := _load_integral_variant_schema()
	var integral_schema_loaded := bool(integral_schema_load_receipt.get("ok", false))
	var integral_normalization_receipt := _empty_integral_normalization_receipt()
	var report: Dictionary = {}
	if template_loaded:
		report = (template_value as Dictionary).duplicate(true)
		template_matches_declared_fixture = _template_matches_declared_fixture(
			report,
			description,
		)
		if template_matches_declared_fixture:
			integral_normalization_receipt = _restore_integral_variant_schema(
				report,
				integral_schema_load_receipt.get("schema", {}),
				String(integral_schema_load_receipt.get("raw_sha256", "")),
				int(integral_schema_load_receipt.get("byte_length", 0)),
			)
		if bool(integral_normalization_receipt.get("ok", false)):
			_apply_zero_world_runtime_projection(
				report,
				source_commit,
				nonce,
				engine,
				description,
				invalid_rid_refused,
			)
	var default_precision_envelope := ""
	var full_precision_envelope := ""
	if bool(integral_normalization_receipt.get("ok", false)):
		default_precision_envelope = JSON.stringify(report, "", true, false)
		full_precision_envelope = JSON.stringify(report, "", true, true)
	var envelopes_nonempty_and_distinct := (
		not default_precision_envelope.is_empty()
		and not full_precision_envelope.is_empty()
		and default_precision_envelope != full_precision_envelope
	)
	var active_physics_object_count := float(
		Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	)
	var active_physics_object_count_is_zero := active_physics_object_count == 0.0
	var ok := (
		engine_freeze_matches
		and class_registered
		and method_registered
		and invalid_rid_refused
		and fixture_description_matches
		and template_loaded
		and template_matches_declared_fixture
		and integral_schema_loaded
		and bool(integral_normalization_receipt.get("ok", false))
		and envelopes_nonempty_and_distinct
		and active_physics_object_count_is_zero
	)
	var real_t_projection_receipt := {
		"child_inertia_component_kg_m2": RigScript.CHILD_INERTIA_KG_M2.x,
		"maximum_impulse_0_002_nms": _as_real_t(0.002),
		"maximum_impulse_0_01_nms": _as_real_t(0.01),
		"lower_limit_negative_0_02_rad": _as_real_t(-0.02),
		"upper_limit_positive_0_02_rad": _as_real_t(0.02),
	}
	var receipt := {
		"ok": ok,
		"schema_version":
		"sporespore_qsdk_r24d7_godot_jolt_one_hinge_worker_preflight_v1",
		"fixture_id": String(description.get("fixture_id", "")),
		"cell_count": int(description.get("cell_count", -1)),
		"cell_ids_in_order": cell_ids,
		"engine": engine,
		"telemetry_class_registered": class_registered,
		"telemetry_method_registered": method_registered,
		"invalid_rid_refused": invalid_rid_refused,
		"engine_freeze_matches": engine_freeze_matches,
		"fixture_description_matches": fixture_description_matches,
		"fixture_description_gates": fixture_description_gates,
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"zero_world_template_loaded": template_loaded,
		"zero_world_template_matches_declared_fixture":
		template_matches_declared_fixture,
		"integral_variant_schema_loaded": integral_schema_loaded,
		"integral_variant_schema": integral_normalization_receipt,
		"serialized_envelope":
		{
			"serializer_call_count": 2,
			"default_precision_sort_keys": true,
			"default_precision_full_precision": false,
			"full_precision_sort_keys": true,
			"full_precision_full_precision": true,
			"envelopes_nonempty_and_distinct":
			envelopes_nonempty_and_distinct,
			"default_precision_raw_sha256":
			"sha256:" + default_precision_envelope.sha256_text(),
			"default_precision_byte_length":
			default_precision_envelope.to_utf8_buffer().size(),
			"full_precision_raw_sha256":
			"sha256:" + full_precision_envelope.sha256_text(),
			"full_precision_byte_length":
			full_precision_envelope.to_utf8_buffer().size(),
			"synthetic_embedded_declared_world_attempt_count": 1,
			"synthetic_embedded_declared_world_build_count": 1,
			"synthetic_embedded_declared_physics_step_count": 20,
			"synthetic_embedded_declared_retained_sample_count": 68,
			"synthetic_envelope_is_physical_observation": false,
			"real_t_projection_receipt": real_t_projection_receipt,
		},
		"active_physics_object_count": active_physics_object_count,
		"active_physics_object_count_is_zero": active_physics_object_count_is_zero,
		"telemetry_schema": TELEMETRY_SCHEMA,
		"physical_characterization_executed": false,
		"world_attempt_count": 0,
		"world_build_count": 0,
		"solver_step_count": 0,
		"physical_acceptance_authority": false,
		"release_authority": false,
	}
	if not default_precision_envelope.is_empty():
		print(
			"QSDK_R24D7_ZERO_WORLD_DEFAULT_PRECISION_ENVELOPE ",
			default_precision_envelope,
		)
	if not full_precision_envelope.is_empty():
		print(
			"QSDK_R24D7_ZERO_WORLD_FULL_PRECISION_ENVELOPE ",
			full_precision_envelope,
		)
	print(
		"QSDK_R24D7_WORKER_ZERO_WORLD ",
		JSON.stringify(receipt, "", true, true),
	)
	_schedule_quit(0 if ok else 1, "zero_world_preflight")


func _load_zero_world_template() -> Variant:
	if not FileAccess.file_exists(ZERO_WORLD_TEMPLATE_PATH):
		return null
	var file := FileAccess.open(ZERO_WORLD_TEMPLATE_PATH, FileAccess.READ)
	if file == null:
		return null
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return null
	return parser.data


func _load_integral_variant_schema() -> Dictionary:
	var receipt := {
		"ok": false,
		"schema": {},
		"raw_sha256": "",
		"byte_length": 0,
	}
	if not FileAccess.file_exists(INTEGRAL_VARIANT_SCHEMA_PATH):
		return receipt
	var file := FileAccess.open(INTEGRAL_VARIANT_SCHEMA_PATH, FileAccess.READ)
	if file == null:
		return receipt
	var raw_text := file.get_as_text()
	var parser := JSON.new()
	if parser.parse(raw_text) != OK or not parser.data is Dictionary:
		return receipt
	receipt["ok"] = true
	receipt["schema"] = parser.data
	receipt["raw_sha256"] = "sha256:" + raw_text.sha256_text()
	receipt["byte_length"] = raw_text.to_utf8_buffer().size()
	return receipt


func _empty_integral_normalization_receipt() -> Dictionary:
	return {
		"ok": false,
		"schema_id": "",
		"schema_raw_sha256": "",
		"schema_byte_length": 0,
		"declared_path_family_count": 0,
		"declared_occurrence_count": 0,
		"predecessor_strict_occurrence_count": 0,
		"processed_path_family_count": 0,
		"pre_normalization_float_occurrence_count": 0,
		"pre_normalization_non_float_occurrence_count": 0,
		"normalized_occurrence_count": 0,
		"post_normalization_integer_occurrence_count": 0,
		"post_normalization_non_integer_occurrence_count": 0,
		"missing_occurrence_count": 0,
		"count_mismatch_family_count": 0,
		"unexpected_family_count": 0,
		"numeric_value_change_count": 0,
		"family_receipts": [],
	}


func _restore_integral_variant_schema(
	report: Dictionary,
	schema_value: Variant,
	schema_raw_sha256: String,
	schema_byte_length: int,
) -> Dictionary:
	var receipt := _empty_integral_normalization_receipt()
	receipt["schema_raw_sha256"] = schema_raw_sha256
	receipt["schema_byte_length"] = schema_byte_length
	if not schema_value is Dictionary:
		return receipt
	var schema: Dictionary = schema_value
	receipt["schema_id"] = String(schema.get("schema_id", ""))
	var finite_counts_value: Variant = schema.get("finite_counts", null)
	var families_value: Variant = schema.get("path_families", null)
	if not finite_counts_value is Dictionary or not families_value is Array:
		return receipt
	var finite_counts: Dictionary = finite_counts_value
	var families: Array = families_value
	receipt["declared_path_family_count"] = int(
		finite_counts.get("path_family_count", -1)
	)
	receipt["declared_occurrence_count"] = int(
		finite_counts.get("concrete_occurrence_count", -1)
	)
	receipt["predecessor_strict_occurrence_count"] = int(
		finite_counts.get("predecessor_strict_occurrence_count", -1)
	)
	if (
		String(schema.get("schema_version", ""))
		!= "sporespore_qsdk_r24d7_integral_variant_schema_v1"
		or String(schema.get("schema_id", "")) != INTEGRAL_VARIANT_SCHEMA_ID
		or String(schema.get("gate_id", "")) != "QSDK-R24D7"
		or families.size() != EXPECTED_INTEGRAL_PATH_FAMILY_COUNT
		or int(receipt["declared_path_family_count"])
		!= EXPECTED_INTEGRAL_PATH_FAMILY_COUNT
		or int(receipt["declared_occurrence_count"])
		!= EXPECTED_INTEGRAL_OCCURRENCE_COUNT
		or int(receipt["predecessor_strict_occurrence_count"])
		!= EXPECTED_PREDECESSOR_STRICT_OCCURRENCE_COUNT
		or int(finite_counts.get("r24d7_strict_occurrence_count", -1))
		!= EXPECTED_INTEGRAL_OCCURRENCE_COUNT
	):
		return receipt
	var family_ids := {}
	var declared_occurrence_sum := 0
	var predecessor_strict_occurrence_sum := 0
	for family_value in families:
		if not family_value is Dictionary:
			receipt["unexpected_family_count"] = int(
				receipt["unexpected_family_count"]
			) + 1
			continue
		var family: Dictionary = family_value
		var family_id := String(family.get("family_id", ""))
		var scope := String(family.get("scope", ""))
		var field := String(family.get("field", ""))
		var expected_count := int(family.get("expected_occurrence_count", -1))
		var known_scope := scope in [
			"fixture",
			"cell",
			"cell_parameter_readback",
			"sample",
			"sample_telemetry",
			"execution",
		]
		if (
			family_id.is_empty()
			or family_ids.has(family_id)
			or field.is_empty()
			or not known_scope
			or expected_count <= 0
			or not bool(family.get("r24d7_strict_evaluator_integer", false))
		):
			receipt["unexpected_family_count"] = int(
				receipt["unexpected_family_count"]
			) + 1
			continue
		family_ids[family_id] = true
		declared_occurrence_sum += expected_count
		if bool(family.get("predecessor_strict_evaluator_integer", false)):
			predecessor_strict_occurrence_sum += expected_count
		var containers := _integral_scope_containers(report, scope)
		var family_receipt := {
			"family_id": family_id,
			"scope": scope,
			"field": field,
			"expected_occurrence_count": expected_count,
			"observed_container_count": containers.size(),
			"pre_float_count": 0,
			"pre_non_float_count": 0,
			"normalized_count": 0,
			"post_integer_count": 0,
			"post_non_integer_count": 0,
			"missing_count": 0,
			"numeric_value_change_count": 0,
		}
		if containers.size() != expected_count:
			receipt["count_mismatch_family_count"] = int(
				receipt["count_mismatch_family_count"]
			) + 1
		for container_value in containers:
			if not container_value is Dictionary:
				family_receipt["missing_count"] = int(
					family_receipt["missing_count"]
				) + 1
				continue
			var container: Dictionary = container_value
			if not container.has(field):
				family_receipt["missing_count"] = int(
					family_receipt["missing_count"]
				) + 1
				continue
			var original: Variant = container[field]
			if typeof(original) == TYPE_FLOAT:
				family_receipt["pre_float_count"] = int(
					family_receipt["pre_float_count"]
				) + 1
			else:
				family_receipt["pre_non_float_count"] = int(
					family_receipt["pre_non_float_count"]
				) + 1
				continue
			var original_float := float(original)
			if (
				not is_finite(original_float)
				or floor(original_float) != original_float
				or float(int(original_float)) != original_float
			):
				family_receipt["numeric_value_change_count"] = int(
					family_receipt["numeric_value_change_count"]
				) + 1
				continue
			container[field] = int(original_float)
			family_receipt["normalized_count"] = int(
				family_receipt["normalized_count"]
			) + 1
			if typeof(container[field]) == TYPE_INT:
				family_receipt["post_integer_count"] = int(
					family_receipt["post_integer_count"]
				) + 1
			else:
				family_receipt["post_non_integer_count"] = int(
					family_receipt["post_non_integer_count"]
				) + 1
		for key in [
			"pre_float_count",
			"pre_non_float_count",
			"normalized_count",
			"post_integer_count",
			"post_non_integer_count",
			"missing_count",
			"numeric_value_change_count",
		]:
			var receipt_key: String = String({
				"pre_float_count": "pre_normalization_float_occurrence_count",
				"pre_non_float_count": "pre_normalization_non_float_occurrence_count",
				"normalized_count": "normalized_occurrence_count",
				"post_integer_count": "post_normalization_integer_occurrence_count",
				"post_non_integer_count": "post_normalization_non_integer_occurrence_count",
				"missing_count": "missing_occurrence_count",
				"numeric_value_change_count": "numeric_value_change_count",
			}[key])
			receipt[receipt_key] = int(receipt[receipt_key]) + int(
				family_receipt[key]
			)
		(receipt["family_receipts"] as Array).append(family_receipt)
		receipt["processed_path_family_count"] = int(
			receipt["processed_path_family_count"]
		) + 1
	receipt["ok"] = (
		declared_occurrence_sum == EXPECTED_INTEGRAL_OCCURRENCE_COUNT
		and predecessor_strict_occurrence_sum
		== EXPECTED_PREDECESSOR_STRICT_OCCURRENCE_COUNT
		and int(receipt["processed_path_family_count"])
		== EXPECTED_INTEGRAL_PATH_FAMILY_COUNT
		and int(receipt["pre_normalization_float_occurrence_count"])
		== EXPECTED_INTEGRAL_OCCURRENCE_COUNT
		and int(receipt["pre_normalization_non_float_occurrence_count"]) == 0
		and int(receipt["normalized_occurrence_count"])
		== EXPECTED_INTEGRAL_OCCURRENCE_COUNT
		and int(receipt["post_normalization_integer_occurrence_count"])
		== EXPECTED_INTEGRAL_OCCURRENCE_COUNT
		and int(receipt["post_normalization_non_integer_occurrence_count"]) == 0
		and int(receipt["missing_occurrence_count"]) == 0
		and int(receipt["count_mismatch_family_count"]) == 0
		and int(receipt["unexpected_family_count"]) == 0
		and int(receipt["numeric_value_change_count"]) == 0
	)
	return receipt


func _integral_scope_containers(report: Dictionary, scope: String) -> Array:
	if scope == "fixture":
		return [report.get("fixture", {})]
	if scope == "execution":
		return [report.get("execution", {})]
	var cells_value: Variant = report.get("cells", [])
	if not cells_value is Array:
		return []
	var containers := []
	for cell_value in cells_value:
		if not cell_value is Dictionary:
			return []
		var cell: Dictionary = cell_value
		if scope == "cell":
			containers.append(cell)
		elif scope == "cell_parameter_readback":
			containers.append(cell.get("parameter_readback", {}))
		elif scope == "sample" or scope == "sample_telemetry":
			var samples_value: Variant = cell.get("samples", [])
			if not samples_value is Array:
				return []
			for sample_value in samples_value:
				if not sample_value is Dictionary:
					return []
				var sample: Dictionary = sample_value
				if scope == "sample":
					containers.append(sample)
				else:
					containers.append(sample.get("telemetry", {}))
	return containers


func _template_matches_declared_fixture(
	report: Dictionary,
	description: Dictionary,
) -> bool:
	if (
		String(report.get("schema_version", "")) != RAW_SCHEMA
		or String(report.get("gate_id", "")) != "QSDK-R24D7"
		or String(report.get("question_class", "")) != "development"
		or not report.get("fixture") is Dictionary
		or not report.get("refusals") is Dictionary
		or not report.get("cells") is Array
		or not report.get("execution") is Dictionary
		or not report.get("claims") is Dictionary
	):
		return false
	var fixture: Dictionary = report["fixture"]
	if (
		String(fixture.get("fixture_id", "")) != RigScript.FIXTURE_ID
		or int(fixture.get("cell_count", -1)) != 9
		or float(fixture.get("child_mass_kg", -1.0)) != RigScript.CHILD_MASS_KG
		or description.get("cell_ids_in_order", []) != EXPECTED_CELL_IDS
	):
		return false
	var cells: Array = report["cells"]
	var specs: Array[Dictionary] = RigScript.declared_cell_specs()
	if cells.size() != specs.size() or cells.size() != EXPECTED_CELL_IDS.size():
		return false
	for index in range(cells.size()):
		if not cells[index] is Dictionary:
			return false
		var cell: Dictionary = cells[index]
		var spec: Dictionary = specs[index]
		if (
			String(cell.get("cell_id", "")) != EXPECTED_CELL_IDS[index]
			or String(cell.get("family", "")) != String(spec["family"])
			or bool(cell.get("motor_enabled", false)) != bool(spec["motor_enabled"])
			or float(cell.get("canonical_target_velocity_rad_s", 999.0))
			!= float(spec["canonical_target_velocity_rad_s"])
			or float(cell.get("initial_canonical_rate_rad_s", 999.0))
			!= float(spec["initial_canonical_rate_rad_s"])
			or float(cell.get("public_maximum_motor_impulse_nms", -1.0))
			!= float(spec["public_maximum_motor_impulse_nms"])
			or bool(cell.get("joint_limits_enabled", false))
			!= bool(spec["joint_limits_enabled"])
			or float(cell.get("lower_limit_rad", 999.0))
			!= float(spec["lower_limit_rad"])
			or float(cell.get("upper_limit_rad", 999.0))
			!= float(spec["upper_limit_rad"])
			or int(cell.get("retained_step_count", -1))
			!= int(spec["retained_step_count"])
			or not cell.get("parameter_readback") is Dictionary
			or not cell.get("samples") is Array
			or (cell["samples"] as Array).size()
			!= int(spec["retained_step_count"])
		):
			return false
	var execution: Dictionary = report["execution"]
	return (
		int(execution.get("world_attempt_count", -1)) == 1
		and int(execution.get("world_build_count", -1)) == 1
		and int(execution.get("physics_step_count", -1)) == 20
		and int(execution.get("retained_sample_count", -1)) == 68
	)


func _apply_zero_world_runtime_projection(
	report: Dictionary,
	source_commit: String,
	nonce: String,
	engine: Dictionary,
	description: Dictionary,
	invalid_rid_refused: bool,
) -> void:
	report["source_commit"] = source_commit
	report["execution_nonce"] = nonce
	report["engine"] = engine.duplicate(true)
	var fixture: Dictionary = report["fixture"]
	fixture["fixture_id"] = RigScript.FIXTURE_ID
	fixture["cell_count"] = 9
	fixture["child_mass_kg"] = RigScript.CHILD_MASS_KG
	fixture["child_inertia_diagonal_kg_m2"] = _vector(
		RigScript.CHILD_INERTIA_KG_M2
	)
	fixture["hinge_axis_parent_local"] = description[
		"hinge_axis_parent_local"
	]
	var pre_tree_refusals := {}
	for cell_id in EXPECTED_CELL_IDS:
		pre_tree_refusals[cell_id] = true
	report["refusals"] = {
		"invalid_rid_refused": invalid_rid_refused,
		"not_in_tree_joint_read_refused_by_cell": pre_tree_refusals,
	}
	var specs: Array[Dictionary] = RigScript.declared_cell_specs()
	var cells: Array = report["cells"]
	for index in range(cells.size()):
		var cell: Dictionary = cells[index]
		var spec: Dictionary = specs[index]
		var real_t_inertia := _vector(RigScript.CHILD_INERTIA_KG_M2)
		var real_t_target := _as_real_t(
			-float(spec["canonical_target_velocity_rad_s"])
		)
		var real_t_max_impulse := _as_real_t(
			float(spec["public_maximum_motor_impulse_nms"])
		)
		var real_t_lower_limit := _as_real_t(float(spec["lower_limit_rad"]))
		var real_t_upper_limit := _as_real_t(float(spec["upper_limit_rad"]))
		var parameters: Dictionary = cell["parameter_readback"]
		parameters["child_inertia_diagonal_kg_m2"] = real_t_inertia
		parameters["host_target_velocity_rad_s"] = real_t_target
		parameters["public_maximum_motor_impulse_nms"] = real_t_max_impulse
		parameters["lower_limit_rad"] = real_t_lower_limit
		parameters["upper_limit_rad"] = real_t_upper_limit
		var samples: Array = cell["samples"]
		for sample_value in samples:
			var sample: Dictionary = sample_value
			sample["host_target_velocity_readback_rad_s"] = real_t_target
			sample["joint_limit_lower_readback_rad"] = real_t_lower_limit
			sample["joint_limit_upper_readback_rad"] = real_t_upper_limit


func _as_real_t(value: float) -> float:
	# Vector3 components use the exact real_t precision compiled into this
	# runtime. The frozen binary must project through single precision.
	return Vector3(value, 0.0, 0.0).x


func _run_physical(source_commit: String, nonce: String) -> void:
	var engine := _engine_receipt()
	if not _engine_receipt_is_frozen(engine):
		_emit_physical_failure("R24D7_ENGINE_OR_SOLVER_FREEZE_DRIFT", 0, 0)
		return
	var description: Dictionary = RigScript.describe()
	if not _fixture_description_is_frozen(description):
		_emit_physical_failure("R24D7_FIXTURE_DECLARATION_DRIFT", 0, 0)
		return
	var invalid_rid_refused := (
		JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(RID()) == null
	)
	var rig: Dictionary = RigScript.build()
	if not bool(rig.get("ok", false)):
		_emit_physical_failure(
			"R24D7_FIXTURE_BUILD_FAILED",
			int(rig.get("world_attempt_count", 1)),
			int(rig.get("world_build_count", 0)),
		)
		return
	var viewport: SubViewport = rig["viewport"]
	var cells: Array = rig["cells"]
	root.add_child(viewport)

	var initial_velocity_write_count := 0
	var retained_by_id := {}
	var integrated_angle_by_id := {}
	var prior_probe_by_id := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		initial_velocity_write_count += RigScript.activate(cell)
		var cell_id := String(cell["cell_id"])
		retained_by_id[cell_id] = []
		integrated_angle_by_id[cell_id] = 0.0
		prior_probe_by_id[cell_id] = RigScript.stepping_probe_counts(cell)

	var parameter_readbacks := {}
	for cell_value in cells:
		var cell: Dictionary = cell_value
		parameter_readbacks[String(cell["cell_id"])] = (
			RigScript.parameter_readback(cell)
		)

	var sleep_input_write_count := 0
	for step_index in range(1, RigScript.MAXIMUM_PHYSICS_STEP_COUNT + 1):
		var pre_rate_by_id := {}
		for cell_value in cells:
			var cell: Dictionary = cell_value
			pre_rate_by_id[String(cell["cell_id"])] = (
				RigScript.canonical_rate_rad_s(cell)
			)
		await physics_frame
		for cell_value in cells:
			var cell: Dictionary = cell_value
			var cell_id := String(cell["cell_id"])
			if step_index > int(cell["retained_step_count"]):
				continue
			var child: RigidBody3D = cell["child"]
			var joint: HingeJoint3D = cell["joint"]
			var pre_rate := float(pre_rate_by_id[cell_id])
			var post_rate := RigScript.canonical_rate_rad_s(cell)
			var telemetry_value: Variant = (
				JoltPhysicsServer3D.hinge_joint_get_motor_telemetry(
					joint.get_rid()
				)
			)
			var telemetry: Variant = null
			var solver_step_s := 1.0 / 120.0
			if telemetry_value is Dictionary:
				telemetry = (telemetry_value as Dictionary).duplicate(true)
				solver_step_s = float(
					(telemetry as Dictionary).get("solver_step_s", solver_step_s)
				)
			var integrated_angle := float(integrated_angle_by_id[cell_id])
			integrated_angle += 0.5 * (pre_rate + post_rate) * solver_step_s
			integrated_angle_by_id[cell_id] = integrated_angle
			var probe := RigScript.stepping_probe_counts(cell)
			var prior_probe: Dictionary = prior_probe_by_id[cell_id]
			var step_probe_attempts := (
				int(probe["attempt_count"]) - int(prior_probe["attempt_count"])
			)
			var step_probe_refusals := (
				int(probe["refusal_count"]) - int(prior_probe["refusal_count"])
			)
			prior_probe_by_id[cell_id] = probe
			(retained_by_id[cell_id] as Array).append(
				{
					"step_index": step_index,
					"pre_canonical_relative_rate_rad_s": pre_rate,
					"post_canonical_relative_rate_rad_s": post_rate,
					"inverse_inertia_axis_kg_inv_m2":
					RigScript.inverse_inertia_axis_kg_inv_m2(cell),
					"integrated_canonical_angle_rad": integrated_angle,
					"host_target_velocity_readback_rad_s": joint.get_param(
						HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY
					),
					"joint_limit_lower_readback_rad": joint.get_param(
						HingeJoint3D.PARAM_LIMIT_LOWER
					),
					"joint_limit_upper_readback_rad": joint.get_param(
						HingeJoint3D.PARAM_LIMIT_UPPER
					),
					"telemetry": telemetry,
					"stepping_read_attempt_count": step_probe_attempts,
					"stepping_read_refusal_count": step_probe_refusals,
					"child_sleeping": child.sleeping,
				}
			)
		if step_index == 1:
			for cell_value in cells:
				var cell: Dictionary = cell_value
				if String(cell["cell_id"]) == "sleep_stale":
					RigScript.force_declared_sleep(cell)
					sleep_input_write_count += 1
					break

	var raw_cells: Array[Dictionary] = []
	var retained_sample_count := 0
	for cell_value in cells:
		var cell: Dictionary = cell_value
		var cell_id := String(cell["cell_id"])
		var samples: Array = retained_by_id[cell_id]
		retained_sample_count += samples.size()
		raw_cells.append(
			{
				"cell_id": cell_id,
				"family": String(cell["family"]),
				"motor_enabled": bool(cell["motor_enabled"]),
				"canonical_target_velocity_rad_s":
				float(cell["canonical_target_velocity_rad_s"]),
				"initial_canonical_rate_rad_s":
				float(cell["initial_canonical_rate_rad_s"]),
				"public_maximum_motor_impulse_nms":
				float(cell["public_maximum_motor_impulse_nms"]),
				"joint_limits_enabled": bool(cell["joint_limits_enabled"]),
				"lower_limit_rad": float(cell["lower_limit_rad"]),
				"upper_limit_rad": float(cell["upper_limit_rad"]),
				"retained_step_count": int(cell["retained_step_count"]),
				"pre_tree_read_refused": bool(cell["pre_tree_read_refused"]),
				"parameter_readback": parameter_readbacks[cell_id],
				"samples": samples,
			}
		)

	var report := {
		"schema_version": RAW_SCHEMA,
		"gate_id": "QSDK-R24D7",
		"question_class": "development",
		"source_commit": source_commit,
		"execution_nonce": nonce,
		"engine": engine,
		"fixture":
		{
			"fixture_id": RigScript.FIXTURE_ID,
			"cell_count": raw_cells.size(),
			"child_mass_kg": RigScript.CHILD_MASS_KG,
			"child_inertia_diagonal_kg_m2":
			_vector(RigScript.CHILD_INERTIA_KG_M2),
			"hinge_axis_parent_local":
			_vector(RigScript.CANONICAL_AXIS_PARENT_LOCAL),
			"gravity_scale": 0.0,
			"linear_damping": 0.0,
			"angular_damping": 0.0,
			"collision_layer": 0,
			"collision_mask": 0,
			"contact_count": 0,
		},
		"refusals":
		{
			"invalid_rid_refused": invalid_rid_refused,
			"not_in_tree_joint_read_refused_by_cell": rig["pre_tree_refusals"],
		},
		"cells": raw_cells,
		"execution":
		{
			"world_attempt_count": int(rig["world_attempt_count"]),
			"world_build_count": int(rig["world_build_count"]),
			"physics_step_count": RigScript.MAXIMUM_PHYSICS_STEP_COUNT,
			"retained_sample_count": retained_sample_count,
			"direct_force_write_count": 0,
			"direct_torque_write_count": 0,
			"direct_impulse_write_count": 0,
			"post_activation_transform_write_count": 0,
			"pre_activation_initial_angular_velocity_write_count":
			initial_velocity_write_count,
			"declared_sleep_input_write_count": sleep_input_write_count,
			"outcome_dependent_early_stop_count": 0,
		},
		"claims":
		{
			"descriptive_development_characterization_only": true,
			"instrumented_profile_promoted": false,
			"stock_godot_profile_promoted": false,
			"recovery_claimed": false,
			"prone_to_standing_claimed": false,
			"turning_claim_changed": false,
			"cross_engine_equivalence_claimed": false,
			"physical_acceptance_authority": false,
			"release_authority": false,
		},
	}
	print(
		"QSDK_R24D7_PHYSICAL_RAW_REPORT ",
		JSON.stringify(report, "", true, true),
	)
	viewport.queue_free()
	_schedule_quit(0, "physical_raw_report")


func _engine_receipt() -> Dictionary:
	var separate_thread := bool(
		ProjectSettings.get_setting("physics/3d/run_on_separate_thread", false)
	)
	return {
		"physics_engine": String(
			ProjectSettings.get_setting("physics/3d/physics_engine", "")
		),
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"solver_velocity_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/velocity_steps",
				-1,
			)
		),
		"solver_position_steps": int(
			ProjectSettings.get_setting(
				"physics/jolt_physics_3d/simulation/position_steps",
				-1,
			)
		),
		"thread_model": "separate" if separate_thread else "single_safe",
		"telemetry_class_registered": ClassDB.class_exists(CLASS_NAME),
		"telemetry_method_registered": ClassDB.class_has_method(
			CLASS_NAME,
			METHOD_NAME,
		),
	}


func _engine_receipt_is_frozen(engine: Dictionary) -> bool:
	return (
		String(engine.get("physics_engine", "")) == "Jolt Physics"
		and int(engine.get("physics_ticks_per_second", -1)) == 120
		and int(engine.get("solver_velocity_steps", -1)) == 20
		and int(engine.get("solver_position_steps", -1)) == 7
		and String(engine.get("thread_model", "")) == "single_safe"
		and bool(engine.get("telemetry_class_registered", false))
		and bool(engine.get("telemetry_method_registered", false))
	)


func _fixture_description_is_frozen(description: Dictionary) -> bool:
	var gates := _fixture_description_gate_receipt(description)
	for gate_value: Variant in gates.values():
		if not bool(gate_value):
			return false
	return true


func _fixture_description_gate_receipt(description: Dictionary) -> Dictionary:
	var cell_ids: Array = description.get("cell_ids_in_order", [])
	var inertia: Array = description.get("child_inertia_diagonal_kg_m2", [])
	var axis: Array = description.get("hinge_axis_parent_local", [])
	return {
		"fixture_id_matches": (
			String(description.get("fixture_id", "")) == RigScript.FIXTURE_ID
		),
		"cell_count_matches": int(description.get("cell_count", -1)) == 9,
		"cell_ids_match": cell_ids == EXPECTED_CELL_IDS,
		"child_mass_matches": (
			float(description.get("child_mass_kg", -1.0)) == 1.0
		),
		# Compare the two values produced from the frozen rig constant. A Vector3
		# component uses Godot's real_t representation, so comparing it with a
		# newly parsed Variant float literal would test representation conversion
		# rather than fixture identity.
		"child_inertia_matches": (
			inertia == _vector(RigScript.CHILD_INERTIA_KG_M2)
		),
		"hinge_axis_matches": axis == [0.0, 0.0, 1.0],
		"maximum_physics_step_count_matches": (
			int(description.get("maximum_physics_step_count", -1)) == 20
		),
		"world_attempt_count_is_zero": (
			int(description.get("world_attempt_count", -1)) == 0
		),
		"world_build_count_is_zero": (
			int(description.get("world_build_count", -1)) == 0
		),
		"solver_step_count_is_zero": (
			int(description.get("solver_step_count", -1)) == 0
		),
	}


func _emit_authorization_failure(code: String) -> void:
	print(
		"QSDK_R24D7_WORKER_FAILURE ",
		JSON.stringify(
			{
				"ok": false,
				"failure_code": code,
				"world_attempt_count": 0,
				"world_build_count": 0,
				"solver_step_count": 0,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	_schedule_quit(1, "authorization_failure")


func _emit_physical_failure(
	code: String,
	world_attempt_count: int,
	world_build_count: int,
) -> void:
	print(
		"QSDK_R24D7_WORKER_FAILURE ",
		JSON.stringify(
			{
				"ok": false,
				"failure_code": code,
				"world_attempt_count": world_attempt_count,
				"world_build_count": world_build_count,
				"solver_step_count": 0,
				"physical_acceptance_authority": false,
				"release_authority": false,
			},
			"",
			true,
			true,
		),
	)
	_schedule_quit(1, "physical_failure")


func _schedule_quit(exit_code: int, receipt_kind: String) -> void:
	if _exit_scheduled:
		push_error("QSDK-R24D7 duplicate orderly-exit schedule")
		return
	_exit_scheduled = true
	_pending_exit_code = exit_code
	_pending_receipt_kind = receipt_kind
	_pending_exit_process_frames = EXIT_DRAIN_PROCESS_FRAME_COUNT
	process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)


func _orderly_exit_process_frame() -> void:
	_pending_exit_process_frames -= 1
	if _pending_exit_process_frames > 0:
		process_frame.connect(_orderly_exit_process_frame, CONNECT_ONE_SHOT)
		return
	if OS.get_environment(SUPERVISED_TERMINATION_ENV) == "1":
		var nonce := OS.get_environment(TERMINATION_NONCE_ENV)
		if nonce.is_empty():
			quit(1)
			return
		print(
			"QSDK_R24D7_GODOT_SUPERVISOR_TERMINATION_READY ",
			JSON.stringify(
				{
					"schema_version":
					"sporespore_godot_supervised_termination_ready_v1",
					"termination_protocol_id": TERMINATION_PROTOCOL_ID,
					"termination_nonce": nonce,
					"process_id": OS.get_process_id(),
					"requested_exit_code": _pending_exit_code,
					"worker_receipt_kind": _pending_receipt_kind,
					"worker_receipt_emitted": true,
					"drained_process_frame_count":
					EXIT_DRAIN_PROCESS_FRAME_COUNT,
					"physics_evidence_authority": false,
				},
				"",
				true,
				true,
			),
		)
		return
	quit(_pending_exit_code)


func _parse_user_arguments(arguments: PackedStringArray) -> Dictionary:
	var parsed := {}
	for argument in arguments:
		var separator := argument.find("=")
		if not argument.begins_with("--") or separator <= 2:
			continue
		parsed[argument.substr(2, separator - 2)] = argument.substr(separator + 1)
	return parsed


func _vector(value: Vector3) -> Array[float]:
	return [value.x, value.y, value.z]
