class_name TendonDef
extends Resource

## M47 — biarticular tendon: a conservative coupling BETWEEN two joints (e.g. knee↔ankle), the
## thing a single-joint Hooke spring (M36) can't do. Modeled as a torsional spring on the angular
## DIFFERENCE of the two joints: when one flexes it pulls the other, transferring stored elastic
## energy across the stride. Conservative by construction (Hookean PE, efficiency ≤ 1) — released
## can never exceed stored (Principle 14).

@export var enabled: bool = true
@export var partner_part_id: StringName = &""   # the OTHER joint this tendon couples to (by part_id)
@export var stiffness: float = 120.0            # coupling k_c (N·m/rad) on the joint-angle difference
@export var efficiency: float = 0.85            # return cap: released ≤ efficiency · stored
@export var rest_offset: float = 0.0            # neutral angular difference (rad) between the pair
