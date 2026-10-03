extends SceneTree
## Checks editor discovery and explicit candidate loading without creating a scene.
## Run with the patched editor, --headless --script <this file>, and optionally
## -- <candidate .gdextension path>. Each selection requires a fresh process.

const DEFAULT_EXTENSION := "res://sdk/adapters/godot/sporespore_locomotion.gdextension"
const SDK_CLASS := "SporeLocomotionSdk"


func _initialize() -> void:
	var initial := GDExtensionManager.get_loaded_extensions()
	if initial.size() != 1 or initial[0] != DEFAULT_EXTENSION:
		_fail("EDITOR_EXTENSION_DISCOVERY: expected only the default SDK, got %s" % [initial])
		return
	# Stock Godot can list the internal class without exposing our patched API.
	if not ClassDB.class_exists("JoltPhysicsServer3D") or not ClassDB.class_has_method("JoltPhysicsServer3D", "hinge_joint_get_motor_telemetry"):
		_fail("EDITOR_TELEMETRY_ENGINE: patched Jolt binding is unavailable")
		return
	var selected := DEFAULT_EXTENSION
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		_fail("EDITOR_EXTENSION_ARGUMENTS: at most one candidate is allowed")
		return
	if args.size() == 1:
		selected = args[0]
		# No SDK instance exists at this boundary, matching the real worker.
		if GDExtensionManager.unload_extension(DEFAULT_EXTENSION) != GDExtensionManager.LOAD_STATUS_OK:
			_fail("EDITOR_EXTENSION_UNLOAD: default SDK could not unload")
			return
		if GDExtensionManager.load_extension(selected) != GDExtensionManager.LOAD_STATUS_OK:
			_fail("EDITOR_EXTENSION_EXPLICIT_LOAD: ignored candidate could not load")
			return
	var loaded := GDExtensionManager.get_loaded_extensions()
	if loaded.size() != 1 or loaded[0] != selected or not ClassDB.class_exists(SDK_CLASS):
		_fail("EDITOR_EXTENSION_SELECTION: selected SDK is not the sole registered extension")
		return
	for method in ["version", "balanced_wave_policy_step_json", "balanced_wave_native_step_transport_verification_json"]:
		if not ClassDB.class_has_method(SDK_CLASS, method):
			_fail("EDITOR_EXTENSION_METHOD: missing %s" % method)
			return
	# A version query exercises the actual selected DLL without a controller/world.
	var sdk: RefCounted = ClassDB.instantiate(SDK_CLASS)
	var version: String = sdk.call("version")
	print("SDK_EDITOR_EXTENSION_ISOLATION_PASS ", JSON.stringify({
		"extension": selected,
		"initial_extension_count": initial.size(),
		"selected_extension_count": loaded.size(),
		"sdk_version": version,
		"patched_jolt_binding_available": true,
		"simulation_started": false,
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
