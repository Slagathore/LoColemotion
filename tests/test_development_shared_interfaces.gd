extends SceneTree

const Contract := preload("res://sdk/adapters/godot/gdscript/recovery_interface_contract_v1.gd")
const Owner := preload("res://sdk/adapters/godot/gdscript/qsdk_r10f_l15_canonical_ownership_v1.gd")


func _initialize() -> void:
	print(
		"RECOVERY_SHARED_INTERFACE_CONSTANTS ",
		(
			JSON
			. stringify(
				{
					"canonical_owners": Contract.CANONICAL_OWNERS,
					"no_actuation_mapping": Owner.Contract.NO_ACTUATION_MAPPING,
					"recovery_controller_id": Owner.RECOVERY_CONTROLLER_ID,
					"world_count": 0,
					"solver_step_count": 0,
					"physical_acceptance_authority": false,
					"release_authority": false,
				}
			)
		)
	)
	quit(0)
