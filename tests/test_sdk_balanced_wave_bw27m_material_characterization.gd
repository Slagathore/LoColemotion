extends "res://tests/test_sdk_godot_jolt_friction_ladder_characterization.gd"

## BW27M-only physical worker over the accepted friction-ladder implementation.
##
## The inherited worker and all historical campaign modes remain byte-exact.
## This successor supplies only its distinct fixture, values, receipt identity,
## and 10-world/19-gate cardinality. Direct invocation without the explicit
## physical token fails before the inherited worker can insert a world.

const Bw27mRigScript := preload("res://scripts/lab/rigs/sdk_bw27m_friction_ladder_sled_rig.gd")

const BW27M_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw27m_" + "material_characterization_receipt_v1"
)
const BW27M_RECEIPT_PREFIX := "BALANCED_WAVE_BW27M_" + "MATERIAL_CHARACTERIZATION_RECEIPT "
const BW27M_AUTHORIZATION_PREFLIGHT_PREFIX := (
	"BW27M_MATERIAL_CHARACTERIZATION_" + "AUTHORIZATION_PREFLIGHT "
)
const BW27M_ATTEMPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw27m_" + "material_characterization_attempt_v1"
)
const BW27M_CAMPAIGN_ID := "BW27M-BW25Y-FRESH-MATERIAL-CHARACTERIZATION"
const BW27M_GATE_ID := "BW27M"
const BW27M_AUTHORIZATION_PATH_ENV := "SPORESPORE_BW27M_ATTEMPT"
const BW27M_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW27M_TOKEN"
const BW27M_POSITIVE_FRICTION_VALUES := [0.62, 0.74, 0.86]
const BW27M_EXPECTED_WORLD_COUNT := 10
const BW27M_EXPECTED_GATE_COUNT := 19


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var authorization_exact := _physical_authorization_exact()
	if arguments.size() == 1 and String(arguments[0]) == "--authorization-preflight":
		print(
			BW27M_AUTHORIZATION_PREFLIGHT_PREFIX,
			(
				JSON
				. stringify(
					{
						"schema_version":
						(
							"sporespore_balanced_wave_bw27m_material_characterization_"
							+ "authorization_preflight_v1"
						),
						"campaign_id": BW27M_CAMPAIGN_ID,
						"gate_id": BW27M_GATE_ID,
						"authorization_exact": authorization_exact,
						"world_build_count": 0,
						"scene_tree_insertion_count": 0,
						"physics_state_modified": false,
						"characterization_outcome_exposed": false,
						"physical_acceptance_authority": false,
					},
					"",
					true,
					true,
				)
			),
		)
		quit(0 if authorization_exact else 2)
		return
	if arguments.size() != 1 or String(arguments[0]) != "--run-physical" or not authorization_exact:
		push_error("BW27M_PHYSICAL_AUTHORIZATION_REQUIRED: use the frozen one-shot supervisor")
		quit(2)
		return
	_bw3_mode = false
	_bw3r_mode = false
	_bw4_mode = false
	_bw5v_mode = false
	_bw5c_mode = false
	# Retain the inherited exact-characterization claim semantics. Dynamic
	# methods below replace every BW20F identity/cardinality surface.
	_bw20f_mode = true
	_preflight_only = false
	call_deferred("_run")


func _build_rig(clock, profile: Dictionary, friction: float) -> Dictionary:
	return Bw27mRigScript.build(clock, profile, friction)


func _positive_friction_values() -> Array:
	return BW27M_POSITIVE_FRICTION_VALUES.duplicate()


func _authored_friction_values() -> Array:
	return Bw27mRigScript.BW27M_AUTHORED_FRICTION_VALUES.duplicate()


func _fixture_id() -> String:
	return Bw27mRigScript.BW27M_FIXTURE_ID


func _receipt_schema_version() -> String:
	return BW27M_RECEIPT_SCHEMA_VERSION


func _receipt_prefix() -> String:
	return BW27M_RECEIPT_PREFIX


func _expected_world_count() -> int:
	return BW27M_EXPECTED_WORLD_COUNT


func _expected_gate_count() -> int:
	return BW27M_EXPECTED_GATE_COUNT


func _campaign_label() -> String:
	return "BW27M fresh finite Godot/Jolt material characterization"


func _is_lower_hex(value: String, expected_length: int) -> bool:
	if value.length() != expected_length:
		return false
	for codepoint in value.to_ascii_buffer():
		var is_digit := codepoint >= 48 and codepoint <= 57
		var is_lower_hex_letter := codepoint >= 97 and codepoint <= 102
		if not is_digit and not is_lower_hex_letter:
			return false
	return true


func _physical_authorization_exact() -> bool:
	var attempt_path := OS.get_environment(BW27M_AUTHORIZATION_PATH_ENV)
	var authorization_token := OS.get_environment(BW27M_AUTHORIZATION_TOKEN_ENV)
	if (
		attempt_path.is_empty()
		or authorization_token.is_empty()
		or not FileAccess.file_exists(attempt_path)
		or attempt_path.replace("/", "\\").begins_with("C:\\tmp\\")
	):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(attempt_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var attempt: Dictionary = parsed
	var attestation_path := String(attempt.get("full_conformance_attestation_path", ""))
	var attestation_sha256 := String(attempt.get("full_conformance_attestation_sha256", ""))
	var operation_lock: Dictionary = attempt.get("operation_lock", {})
	return (
		String(attempt.get("schema_version", "")) == BW27M_ATTEMPT_SCHEMA_VERSION
		and String(attempt.get("campaign_id", "")) == BW27M_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == BW27M_GATE_ID
		and String(attempt.get("authorization_token", "")) == authorization_token
		and _is_lower_hex(String(attempt.get("source_commit", "")), 40)
		and String(attempt.get("attestation_source_commit", ""))
		== String(attempt.get("source_commit", ""))
		and not attestation_path.is_empty()
		and not attestation_path.replace("/", "\\").begins_with("C:\\tmp\\")
		and _is_lower_hex(attestation_sha256, 64)
		and String(operation_lock.get("schema_version", ""))
		== "sporespore_locomotion_operation_lock_receipt_v1"
		and bool(operation_lock.get("acquired", false))
		and String(operation_lock.get("role", "")) == "physical"
		and String(operation_lock.get("mutex_name", ""))
		== "Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1"
		and not bool(operation_lock.get("abandoned_owner_recovered", true))
		and int(operation_lock.get("owner_process_id", 0)) > 0
		and int(operation_lock.get("owner_session_id", -1)) >= 0
		and not String(operation_lock.get("acquired_utc", "")).is_empty()
		and not bool(operation_lock.get("test_only", true))
		and not bool(operation_lock.get("physical_acceptance_authority", true))
		and bool(attempt.get("source_worktree_clean", false))
		and bool(attempt.get("source_matches_live_github_main", false))
		and bool(attempt.get("complete_synthetic_production_gate_passed", false))
		and bool(attempt.get("zero_world_fixture_preflight_passed", false))
		and bool(
			(
				attempt
				. get(
					"physical_process_launch_reserved_identity_consumed",
					false,
				)
			)
		)
		and not bool(attempt.get("same_identity_rerun_allowed", true))
		and int(attempt.get("expected_world_count", -1)) == BW27M_EXPECTED_WORLD_COUNT
		and int(attempt.get("expected_gate_count", -1)) == BW27M_EXPECTED_GATE_COUNT
	)
