class_name AnalyticDescriptorGenerator
extends DescriptorGenerator

## Closed-form generator for Tier-1 primitives and idealized shapes. It delegates to the
## evaluator's OWN geometry routines, so a primitive's descriptor equals the analytic
## numbers by identity — never a second copy of the shape math (BITE NOTE B1).

@export var primitive_type: StringName = &"box"
@export var density:        float = 1050.0
@export var extents:        Vector3 = Vector3.ONE        # half-extents at the base dial state


func _init(p_type := &"box", p_density := 1050.0, p_extents := Vector3.ONE) -> void:
	primitive_type = p_type
	density = p_density
	extents = p_extents


func evaluate(dials: Dictionary) -> PhysicsDescriptor:
	var s: float = float(dials.get(&"scale", 1.0))
	var dims := extents * 2.0 * s                          # evaluator convention: dims = extents*2*scale
	var d := PhysicsDescriptor.new()
	d.total_volume       = CharacteristicsEvaluator.shape_volume(primitive_type, dims)
	d.total_surface_area = CharacteristicsEvaluator.shape_surface(primitive_type, dims)
	d.metabolic_volume   = d.total_volume                 # default tissue all-metabolic
	d.surface_metabolic  = d.total_surface_area
	d.mass               = d.total_volume * density
	d.center_of_mass     = Vector3.ZERO
	var he := extents * s
	d.bounds             = AABB(-he, he * 2.0)
	d.bounding_radius    = he.length()
	return d
