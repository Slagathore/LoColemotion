class_name PartResource
extends Resource

## The sidecar master record for one authored part (Fork C: single source of truth). The .glb
## is cosmetic + shape keys + socket seeds; THIS is what the palette and the genome reference.
## The evaluator never reads this directly — it reads the PartGene the loader produces from it.

@export var id:           StringName                                       # stable genome ref (L5)
@export var version:      int = 1
@export var display_name: String
@export var source_blend: String                                           # provenance only
@export var mesh_path:    String

@export var generator_type: StringName = &"primitive"                      # open registry (H1)
@export var generator:      DescriptorGenerator

@export var dials:          Array[DialDef] = []
@export var tissue_map:     Dictionary[StringName, TissueRegionDef] = {}   # material slot → tissue
@export var sockets:        Dictionary[StringName, SocketDef] = {}         # socket id → socket
@export var joints:         Dictionary[StringName, JointDef] = {}          # Fork B3: socket id -> joint (loader stamps gene.joint)
@export var tags:           Array[StringName] = []
@export var abilities:      Array[AbilityPayload] = []
@export var actuator_hints: Array[ActuatorHint] = []
@export var dial_migration: Dictionary[StringName, StringName] = {}


## Resolve dials → a PhysicsDescriptor via this part's generator.
func make_descriptor(dial_values: Dictionary) -> PhysicsDescriptor:
	if generator == null:
		push_error("PartResource %s has no generator" % id)
		return null
	return generator.evaluate(dial_values)
