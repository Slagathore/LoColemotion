class_name PhysicsDescriptor
extends Resource

## Mesh-accurate measurement of one authored part at a given dial state — the source of
## truth for that part's physics. The evaluator consumes it in CharacteristicsEvaluator._fold
## (the authored "Lane B" branch): total_volume, surface_metabolic, metabolic_volume, mass,
## center_of_mass and bounding_radius override the analytic per-part values; everything
## downstream (debt, balance, probe) runs unchanged on those numbers.
##
## No `evaluator_proxy`, no back-derived density: mass is carried directly. A descriptor is a
## pure function of dials (fit at export to the real integrated geometry), so SAME-BINARY
## holds for the analytic stages.

@export var total_volume:         float
@export var metabolic_volume:     float                      # metabolically-active tissue only
@export var total_surface_area:   float
@export var surface_metabolic:    float                      # SA toward the "hungry skin" SA:V term
@export var enclosed_void_volume: float                      # Σ cavity volumes
@export var center_of_mass:       Vector3
@export var bounds:               AABB
@export var bounding_radius:      float
@export var mass:                 float
@export var tissue_breakdown:     Array[TissueSample] = []
@export var inertia_tensor:       PackedFloat64Array = []    # deferred (Problem 2)
