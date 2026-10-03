extends "res://tests/test_sdk_godot_jolt_friction_ladder_characterization.gd"

## BW22M-only physical worker over the accepted friction-ladder implementation.
##
## The inherited worker and all historical campaign modes remain byte-exact.
## This successor supplies only its distinct fixture, values, receipt identity,
## and 10-world/19-gate cardinality. Direct invocation without the explicit
## physical token fails before the inherited worker can insert a world.

const Bw22mRigScript := preload("res://scripts/lab/rigs/sdk_bw22m_friction_ladder_sled_rig.gd")

const BW22M_RECEIPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw22m_" + "material_characterization_receipt_v1"
)
const BW22M_RECEIPT_PREFIX := "BALANCED_WAVE_BW22M_" + "MATERIAL_CHARACTERIZATION_RECEIPT "
const BW22M_AUTHORIZATION_PREFLIGHT_PREFIX := (
	"BW22M_MATERIAL_CHARACTERIZATION_" + "AUTHORIZATION_PREFLIGHT "
)
const BW22M_ATTEMPT_SCHEMA_VERSION := (
	"sporespore_balanced_wave_bw22m_" + "material_characterization_attempt_v1"
)
const BW22M_CAMPAIGN_ID := "BW22M-BW21L-FRESH-MATERIAL-CHARACTERIZATION"
const BW22M_GATE_ID := "BW22M"
const BW22M_AUTHORIZATION_PATH_ENV := "SPORESPORE_BW22M_ATTEMPT"
const BW22M_AUTHORIZATION_TOKEN_ENV := "SPORESPORE_BW22M_TOKEN"
const BW22M_POSITIVE_FRICTION_VALUES := [0.57, 0.69, 0.81]
const BW22M_EXPECTED_WORLD_COUNT := 10
const BW22M_EXPECTED_GATE_COUNT := 19


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	var authorization_exact := _physical_authorization_exact()
	if arguments.size() == 1 and String(arguments[0]) == "--authorization-preflight":
		print(
			BW22M_AUTHORIZATION_PREFLIGHT_PREFIX,
			(
				JSON
				. stringify(
					{
						"schema_version":
						(
							"sporespore_balanced_wave_bw22m_material_characterization_"
							+ "authorization_preflight_v1"
						),
						"campaign_id": BW22M_CAMPAIGN_ID,
						"gate_id": BW22M_GATE_ID,
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
		push_error("BW22M_PHYSICAL_AUTHORIZATION_REQUIRED: use the frozen one-shot supervisor")
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
	return Bw22mRigScript.build(clock, profile, friction)


func _positive_friction_values() -> Array:
	return BW22M_POSITIVE_FRICTION_VALUES.duplicate()


func _authored_friction_values() -> Array:
	return Bw22mRigScript.BW22M_AUTHORED_FRICTION_VALUES.duplicate()


func _fixture_id() -> String:
	return Bw22mRigScript.BW22M_FIXTURE_ID


func _receipt_schema_version() -> String:
	return BW22M_RECEIPT_SCHEMA_VERSION


func _receipt_prefix() -> String:
	return BW22M_RECEIPT_PREFIX


func _expected_world_count() -> int:
	return BW22M_EXPECTED_WORLD_COUNT


func _expected_gate_count() -> int:
	return BW22M_EXPECTED_GATE_COUNT


func _campaign_label() -> String:
	return "BW22M fresh finite Godot/Jolt material characterization"


func _physical_authorization_exact() -> bool:
	var attempt_path := OS.get_environment(BW22M_AUTHORIZATION_PATH_ENV)
	var authorization_token := OS.get_environment(BW22M_AUTHORIZATION_TOKEN_ENV)
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
	return (
		String(attempt.get("schema_version", "")) == BW22M_ATTEMPT_SCHEMA_VERSION
		and String(attempt.get("campaign_id", "")) == BW22M_CAMPAIGN_ID
		and String(attempt.get("gate_id", "")) == BW22M_GATE_ID
		and String(attempt.get("authorization_token", "")) == authorization_token
		and String(attempt.get("source_commit", "")).length() == 40
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
		and int(attempt.get("expected_world_count", -1)) == BW22M_EXPECTED_WORLD_COUNT
		and int(attempt.get("expected_gate_count", -1)) == BW22M_EXPECTED_GATE_COUNT
	)
