extends RefCounted
## Explicit finite-campaign context. Empty state grants no world or route change.
const PREFIX := "r10dh_declared_finite_prefix_v1"
const ENV := "SPORESPORE_R10DH_DECLARATION"
const PYTHON := "C:/Program Files/Python311/python.exe"
static var declaration: Dictionary = {}
static var runtime_identity: Dictionary = {}
static var consumed := false
static var permit := false

static func selected() -> bool:
	return not declaration.is_empty()

static func initialize(path: String, qualification_only: bool = false) -> bool:
	if selected() or not FileAccess.file_exists(path): return false
	var output: Array = []
	var args := PackedStringArray(["-B", "-X", "utf8", ProjectSettings.globalize_path("res://sdk/conformance/r10dh_campaign.py"), "verify-cell", path])
	if qualification_only: args.append("--qualification-only")
	var code := OS.execute(PYTHON, args, output, true, false)
	if code != 0 or output.size() != 1:
		print("R10DH_BINDING_REFUSED ", output)
		return false
	var verified: Variant = JSON.parse_string(output[0])
	if not verified is Dictionary or verified.get("ok") != true: return false
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary: return false
	if "sha256:" + FileAccess.get_sha256(path) != verified.declaration_sha256: return false
	declaration = value
	permit = not qualification_only
	return true

static func take_world_permission() -> bool:
	if not selected() or not permit or consumed: return false
	# The helper durably consumes the fresh identity at the actual world boundary.
	var output: Array = []
	var code := OS.execute(PYTHON, PackedStringArray(["-B", "-X", "utf8", ProjectSettings.globalize_path("res://sdk/conformance/r10dh_campaign.py"),
		"claim", OS.get_environment(ENV), "--worker-pid", str(OS.get_process_id())]), output, true, false)
	if code != 0: return false
	consumed = true
	return true

static func prefix_steps(seed_value: int) -> Dictionary:
	if not selected() or seed_value != int(declaration.seed): return {}
	var phase := int(declaration.r10dh_campaign.seed.prefix_phase)
	return {"front_left": phase, "front_right": phase, "rear_left": phase, "rear_right": phase}

static func select_runtime(profile: Script) -> bool:
	if not selected(): return false
	var console: Dictionary = declaration.runtime.images.godot_console
	var engine: Dictionary = declaration.runtime.images.godot_engine
	var value: Dictionary = profile._runtime_identity_for_profile_v1(profile.ROTATION_AWARE_COMPLETE_ENERGY_INSTRUMENTED_PROFILE_ID,
		String(console.raw_sha256).trim_prefix("sha256:"), int(console.byte_length),
		String(engine.raw_sha256).trim_prefix("sha256:"), int(engine.byte_length), true)
	if value.get("exact_binary_pair_match") != true or value.get("complete_energy_profile_selected") != true: return false
	if value.console_binary.path != console.path or value.engine_binary.path != engine.path: return false
	value["finite_campaign_only"] = true
	value["physical_acceptance_authority"] = false
	value["release_authority"] = false
	runtime_identity = value
	return true

static func install_walking_behavior() -> bool:
	if not selected(): return false
	# Historical bytes remain immutable. The new manifest binds this exact behavior
	# and current source separately; it never pretends old source pins still match.
	var startup: Script = load("res://sdk/adapters/godot/gdscript/development_recovery_walking_startup_v1.gd")
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(startup.R10AP_CONTRACT_PATH))
	if not value is Dictionary or value.get("warmup_steps") != 72 or value.get("first_full_amplitude_local_step") != 73: return false
	if value.get("maximum_amplitude") != 1.1 / (0.82 * 1.75 + 0.4): return false
	startup.r10ap_contract = value
	return true
