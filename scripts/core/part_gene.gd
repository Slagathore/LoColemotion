class_name PartGene
extends Resource

## A node in the creature genome: one part plus how it hangs off its parent and what hangs
## off it. The genome IS this tree. CharacteristicsEvaluator.fold_graph walks it into
## world-space ResolvedParts; the assembler and (later) editor read the same frame law so the
## picture always matches the stats.
##
## Primitive parts carry `definition` (analytic shape) and leave `descriptor` null.
## Authored parts ALSO carry `definition` (a bounding shape skeleton: part_type + extents drive
## footprint / world-box / inertia / mesh) AND a `descriptor` whose measured physics override
## the analytic per-part numbers in _fold (the authored "Lane B" path).

@export var definition:  PartDefinition                  # analytic shape + density (sacred input)
@export var descriptor:  PhysicsDescriptor               # authored measured physics (null = primitive)
@export var tags:        Array[StringName] = []          # spine|locomotor|attack|heart|brain|ground_contact|graft|lung
@export var socket:      SocketDef                       # RESOLVED snapshot the evaluator reads (null on root)
@export var scale:       Vector3 = Vector3.ONE           # per-axis, > 0 (mirror sign allowed on authored parts)
@export var children:    Array[PartGene] = []            # self-referential is legal with class_name
@export var joint:       JointDef                            # Fork B3: per-joint actuation envelope (null = engine default)
@export var gait:        GaitDef                             # Fork C2: creature-level gait, ROOT gene only (null = golden default)
@export var spring:      SpringDef                           # M34: per-part elastic anatomy (null = no stored/released spring energy)
@export var weapon:      WeaponDef                           # M35: per-part combat anatomy (null = unarmed body contact)
@export var tendon:      TendonDef                           # M47: biarticular coupling to a partner joint (null = none)
@export var attach_points: Array[AttachPoint] = []           # M50: user-placed nubs (authored anchors)

# --- Round-trip / provenance keys: the loader reads these; the evaluator ignores them. ---
@export var part_id:     StringName                          # stable part ID, not a path (L5/L6)
@export var dial_values: Dictionary[StringName, float] = {}  # absolute dial values
@export var socket_id:   StringName                          # stable socket id on the parent; resolves → socket
