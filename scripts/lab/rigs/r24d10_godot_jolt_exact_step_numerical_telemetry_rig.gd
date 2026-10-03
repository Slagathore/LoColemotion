class_name R24D10GodotJoltExactStepNumericalTelemetryRig
extends RefCounted

## QSDK-R24D10 keeps the complete R24D9 nine-cell fixture unchanged.
##
## Only the worker's step schedule changes. Delegating every construction and
## observation operation to the immutable, content-addressed R24D9 rig makes
## that boundary executable and prevents an accidental geometry or cell change
## from being disguised as the scheduling repair.

const R24D9Rig := preload(
	"res://scripts/lab/rigs/r24d9_godot_jolt_one_hinge_numerical_telemetry_rig.gd"
)

const FIXTURE_ID := "QSDK.R24D10.godot_jolt_exact_step_numerical_telemetry.v1"
const CHILD_MASS_KG := R24D9Rig.CHILD_MASS_KG
const CHILD_INERTIA_KG_M2 := R24D9Rig.CHILD_INERTIA_KG_M2
const CANONICAL_AXIS_PARENT_LOCAL := R24D9Rig.CANONICAL_AXIS_PARENT_LOCAL
const MAXIMUM_PHYSICS_STEP_COUNT := R24D9Rig.MAXIMUM_PHYSICS_STEP_COUNT
const RETAINED_SAMPLE_COUNT := R24D9Rig.RETAINED_SAMPLE_COUNT
const CELL_SPECS := R24D9Rig.CELL_SPECS


static func describe() -> Dictionary:
	var description := R24D9Rig.describe()
	description["fixture_id"] = FIXTURE_ID
	return description


static func declared_cell_specs() -> Array[Dictionary]:
	return R24D9Rig.declared_cell_specs()


static func build() -> Dictionary:
	return R24D9Rig.build()


static func activate(cell: Dictionary) -> int:
	return R24D9Rig.activate(cell)


static func force_declared_sleep(cell: Dictionary) -> void:
	R24D9Rig.force_declared_sleep(cell)


static func canonical_axis_world(cell: Dictionary) -> Vector3:
	return R24D9Rig.canonical_axis_world(cell)


static func canonical_rate_rad_s(cell: Dictionary) -> float:
	return R24D9Rig.canonical_rate_rad_s(cell)


static func inverse_inertia_axis_kg_inv_m2(cell: Dictionary) -> float:
	return R24D9Rig.inverse_inertia_axis_kg_inv_m2(cell)


static func parameter_readback(cell: Dictionary) -> Dictionary:
	return R24D9Rig.parameter_readback(cell)
