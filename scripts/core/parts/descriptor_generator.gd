class_name DescriptorGenerator
extends Resource

## Open interface (H1): a part's generator turns dial values into a PhysicsDescriptor.
## New shape families (soft, metaball, …) implement evaluate() with no evaluator edit.

func evaluate(_dials: Dictionary) -> PhysicsDescriptor:
	push_error("DescriptorGenerator.evaluate is abstract — use a concrete subclass")
	return null
