class_name SampledDescriptorGenerator
extends DescriptorGenerator

## M2+P general case: at export, a tool integrates the REAL generated geometry over a grid of
## dial values and stores the resulting PhysicsDescriptors. At runtime we multilinearly
## interpolate — O(2^#dials), independent of triangle count.
##
## Flatten convention: axis 0 varies fastest (row-major over `dial_axes`):
##   index = i0 + i1*shape[0] + i2*shape[0]*shape[1] + …

@export var dial_axes:  Array[StringName] = []           # dials sampled, in grid order
@export var axis_min:   PackedFloat32Array = []          # per-axis sampled range lo
@export var axis_max:   PackedFloat32Array = []          # per-axis sampled range hi
@export var grid_shape: PackedInt32Array = []            # samples per axis (>= 2 each)
@export var samples:    Array[PhysicsDescriptor] = []    # flattened grid


func evaluate(dials: Dictionary) -> PhysicsDescriptor:
	var n := dial_axes.size()
	if not _grid_valid(n):
		return null
	var base := PackedInt32Array(); base.resize(n)
	var frac := PackedFloat32Array(); frac.resize(n)
	for a in n:
		var size: int = grid_shape[a]
		var lo: float = axis_min[a]
		var hi: float = axis_max[a]
		var v: float = float(dials.get(dial_axes[a], lo))
		var t := 0.0
		if hi > lo:
			t = clampf((v - lo) / (hi - lo), 0.0, 1.0) * float(size - 1)
		base[a] = clampi(int(floor(t)), 0, maxi(size - 2, 0))
		frac[a] = t - float(base[a])
	var acc := PhysicsDescriptor.new()
	var corners := 1 << n
	for c in corners:
		var w := 1.0
		var idx := 0
		var stride := 1
		for a in n:
			var bit := (c >> a) & 1
			var size: int = grid_shape[a]
			var ia := clampi(base[a] + bit, 0, size - 1)
			w *= (frac[a] if bit == 1 else (1.0 - frac[a]))
			idx += ia * stride
			stride *= size
		if w > 0.0:
			_accumulate(acc, samples[idx], w)
	return acc


func _grid_valid(n: int) -> bool:
	if n == 0 or samples.is_empty():
		push_error("SampledDescriptorGenerator: empty grid")
		return false
	if axis_min.size() != n or axis_max.size() != n or grid_shape.size() != n:
		push_error("SampledDescriptorGenerator: axis arrays must match dial_axes")
		return false
	var expected := 1
	for size in grid_shape:
		if size < 2:
			push_error("SampledDescriptorGenerator: every grid axis needs at least two samples")
			return false
		expected *= size
	if samples.size() != expected:
		push_error("SampledDescriptorGenerator: sample count %d != expected grid count %d" % [samples.size(), expected])
		return false
	for s in samples:
		if s == null:
			push_error("SampledDescriptorGenerator: sample grid contains null descriptor")
			return false
	return true


static func _accumulate(acc: PhysicsDescriptor, s: PhysicsDescriptor, w: float) -> void:
	acc.total_volume         += s.total_volume * w
	acc.metabolic_volume     += s.metabolic_volume * w
	acc.total_surface_area   += s.total_surface_area * w
	acc.surface_metabolic    += s.surface_metabolic * w
	acc.enclosed_void_volume += s.enclosed_void_volume * w
	acc.mass                 += s.mass * w
	acc.bounding_radius      += s.bounding_radius * w
	acc.center_of_mass       += s.center_of_mass * w
