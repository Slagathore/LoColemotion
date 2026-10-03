class_name LabRigFactory
extends RefCounted

const StationaryBodyRigScript := preload(
	"res://scripts/lab/rigs/stationary_body_rig.gd")
const FreeFallRigScript := preload(
	"res://scripts/lab/rigs/free_fall_rig.gd")
const BallisticRigScript := preload(
	"res://scripts/lab/rigs/ballistic_rig.gd")
const BoxDropContactRigScript := preload(
	"res://scripts/lab/rigs/box_drop_contact_rig.gd")
const FrictionSledRigScript := preload(
	"res://scripts/lab/rigs/friction_sled_rig.gd")
const InclineBlockRigScript := preload(
	"res://scripts/lab/rigs/incline_block_rig.gd")
const TippingPrismRigScript := preload(
	"res://scripts/lab/rigs/tipping_prism_rig.gd")
const FootPressRigScript := preload(
	"res://scripts/lab/rigs/foot_press_rig.gd")
const SolverStackRigScript := preload(
	"res://scripts/lab/rigs/solver_stack_rig.gd")
const MassRatioStackRigScript := preload(
	"res://scripts/lab/rigs/mass_ratio_stack_rig.gd")
const DiscretizedPadRigScript := preload(
	"res://scripts/lab/rigs/discretized_pad_rig.gd")
const LoadedPadRigScript := preload(
	"res://scripts/lab/rigs/loaded_pad_rig.gd")


static func build(
		fixture_id: StringName,
		capture_clock: RefCounted,
		observer_profile: Dictionary,
		body_parameters: Dictionary = {},
		fixture_parameters: Dictionary = {}) -> Dictionary:
	match String(fixture_id):
		"stationary_body_v1":
			return StationaryBodyRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"free_fall_body_v1":
			return FreeFallRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"ballistic_body_v1":
			return BallisticRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"box_drop_contact_v1":
			return BoxDropContactRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"friction_sled_v1":
			return FrictionSledRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"incline_block_v1":
			return InclineBlockRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"tipping_prism_v1":
			return TippingPrismRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"foot_press_v1":
			return FootPressRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"solver_stack_v1":
			return SolverStackRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"mass_ratio_stack_v1":
			return MassRatioStackRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"discretized_pad_v1":
			return DiscretizedPadRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		"loaded_pad_v1":
			return LoadedPadRigScript.build(
				capture_clock,
				observer_profile,
				body_parameters,
				fixture_parameters)
		_:
			return {
				"ok": false,
				"configuration_valid": false,
				"fixture_id": String(fixture_id),
				"configuration_errors": [{
					"code": "UNKNOWN_FIXTURE_ID",
					"path": "/fixture_id",
					"message": "No registered lab rig for %s"
						% String(fixture_id),
				}],
			}
