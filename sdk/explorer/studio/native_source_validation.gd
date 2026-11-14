extends RefCounted
## Pure validator loading, oracle controls and observed backend selection.
const VERSION := "sporespore_finite_source_validation_v1"
const Checks := preload("res://sdk/explorer/studio/test_native_source_validation.gd")

static func initialize(collection: Script, policy: String) -> Dictionary:
	if policy not in ["original","native"]:
		return {"ok":false,"failure":"validation policy"}
	var loaded := GDExtensionManager.load_extension("res://sdk/explorer/studio/native_validation/validator.gdextension")
	if loaded != GDExtensionManager.LOAD_STATUS_OK:
		return {"ok":false,"failure":"validator load","status":loaded}
	var helper: Object = ClassDB.instantiate("SporeFiniteSourceValidator")
	if not is_instance_valid(helper) or helper.validation_version() != VERSION:
		return {"ok":false,"failure":"validator identity"}
	# The full inherited route preflight follows these pure grammar controls.
	var controls := Checks.run(collection,helper,[{},{},{},{}])
	if not controls.ok or controls.checks != 2424:
		return {"ok":false,"failure":"validator oracle","controls":controls}
	collection.studio_native_validator = helper
	for enabled in [false,true]:
		collection.studio_native_validation_enabled = enabled
		reset_counts(collection)
		if not collection._json_source_v1({"valid":[1,2.5]},0,false) or collection._json_source_v1({"invalid":INF},0,false):
			return {"ok":false,"failure":"validator dispatch result"}
		if collection.studio_original_validation_calls != (0 if enabled else 2) or collection.studio_compiled_validation_calls != (2 if enabled else 0):
			return {"ok":false,"failure":"validator dispatch counter"}
	collection.studio_native_validation_enabled = policy == "native"
	reset_counts(collection)
	return {"ok":true,"version":VERSION,"policy":policy,"oracle_controls":controls,
		"dispatch_controls":{"ok":true,"checks":4},"preworld_verified":true}

static func reset_counts(collection: Script) -> void:
	collection.studio_original_validation_calls = 0
	collection.studio_compiled_validation_calls = 0

static func summary(collection: Script, initialization: Dictionary) -> Dictionary:
	var result := initialization.duplicate(true)
	result["original_calls"] = collection.studio_original_validation_calls
	result["compiled_calls"] = collection.studio_compiled_validation_calls
	result["additional_controller_calls"] = 0
	result["additional_physics_reads"] = 0
	result["additional_solver_steps"] = 0
	result["physical_acceptance_authority"] = false
	result["release_authority"] = false
	return result
