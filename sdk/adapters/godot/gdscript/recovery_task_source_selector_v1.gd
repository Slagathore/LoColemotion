extends RefCounted

## Resolve the task before measurement or hashing. Old calls retain the exact
## partial/canonical selector result. Competing producer tags fail closed.
const Partial := preload("res://sdk/adapters/godot/gdscript/r10k_partial_task_source_v1.gd")
const Upright := preload("res://sdk/adapters/godot/gdscript/r10q_upright_task_source_v1.gd")

const DirectUpright := preload("res://sdk/adapters/godot/gdscript/r10r_upright_task_source_v1.gd")
const DirectPartial := preload("res://sdk/adapters/godot/gdscript/r10y_partial_task_source_v1.gd")
const GeometryPartial := preload("res://sdk/adapters/godot/gdscript/r10z_partial_task_source_v1.gd")

const LoadSeekingPartial := preload("res://sdk/adapters/godot/gdscript/r10aa_partial_task_source_v1.gd")

const DownwardRisePartial := preload("res://sdk/adapters/godot/gdscript/r10ab_partial_task_source_v1.gd")

const ConcurrentLoadRisePartial := preload("res://sdk/adapters/godot/gdscript/r10ai_partial_task_source_v1.gd")

const HipRecenterPartial := preload("res://sdk/adapters/godot/gdscript/r10aj_partial_task_source_v1.gd")

const SupportAnchoredPartial := preload("res://sdk/adapters/godot/gdscript/r10am_partial_task_source_v1.gd")

const ProgressiveHeadroomPartial := preload("res://sdk/adapters/godot/gdscript/r10ap_partial_task_source_v1.gd")

const NativeReferencePartial := preload("res://sdk/adapters/godot/gdscript/r10de_partial_task_source_v1.gd")

static func select_v1(sdk: Object, model: Dictionary, application: Dictionary, semantic_step: int) -> Dictionary:
	if model.has(NativeReferencePartial.KEY) or application.has(NativeReferencePartial.KEY):
		return NativeReferencePartial.select_v1(sdk, model, application, semantic_step)
	if model.has(ProgressiveHeadroomPartial.KEY) or application.has(ProgressiveHeadroomPartial.KEY):
		return ProgressiveHeadroomPartial.select_v1(sdk, model, application, semantic_step)
	if model.has(SupportAnchoredPartial.KEY) or application.has(SupportAnchoredPartial.KEY):
		return SupportAnchoredPartial.select_v1(sdk, model, application, semantic_step)
	if model.has(HipRecenterPartial.KEY) or application.has(HipRecenterPartial.KEY):
		return HipRecenterPartial.select_v1(sdk, model, application, semantic_step)
	if model.has(ConcurrentLoadRisePartial.KEY) or application.has(ConcurrentLoadRisePartial.KEY):
		return ConcurrentLoadRisePartial.select_v1(sdk, model, application, semantic_step)
	if model.has(DownwardRisePartial.KEY) or application.has(DownwardRisePartial.KEY):
		return DownwardRisePartial.select_v1(sdk, model, application, semantic_step)
	if model.has(LoadSeekingPartial.KEY) or application.has(LoadSeekingPartial.KEY):
		return LoadSeekingPartial.select_v1(sdk, model, application, semantic_step)
	if model.has(GeometryPartial.KEY) or application.has(GeometryPartial.KEY):
		return GeometryPartial.select_v1(sdk, model, application, semantic_step)
	if model.has(DirectPartial.KEY) or application.has(DirectPartial.KEY):
		return DirectPartial.select_v1(sdk, model, application, semantic_step)
	if model.has(DirectUpright.KEY) or application.has(DirectUpright.KEY):
		return DirectUpright.select_v1(sdk, model, application, semantic_step)
	if model.has(Upright.KEY) or application.has(Upright.KEY):
		return Upright.select_v1(sdk, model, application, semantic_step)
	return Partial.select_v1(sdk, model, application, semantic_step)
