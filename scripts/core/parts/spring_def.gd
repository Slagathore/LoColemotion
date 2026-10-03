class_name SpringDef
extends Resource

## Per-part elastic anatomy. This is stored on the limb/foot segment that behaves
## like a tendon/spring, then resolved into runtime drive metadata by the evaluator.

# M36: the spring is now an honest torsional Hooke element across the muscle's own hinge
# (cpg_controller._apply_spring_drive). The fields below are REUSED, not changed (zero
# snapshot churn): stiffness -> torsional k, damping -> c, efficiency -> return cap.
@export var enabled: bool = true
@export var stiffness: float = 180.0           # torsional k (N·m/rad) — stored energy 0.5·k·θ²
@export var damping: float = 0.20              # c, deflection-rate damping fraction [0, 0.95]
@export var efficiency: float = 0.65           # return cap: released work <= efficiency·stored

# --- DEPRECATED (M36): runtime-inert. Still serialized for back-compat / round-trip, but the
# honest joint-torque spring no longer reads them. Safe to drop in a future snapshot rev. ---
@export var max_compression: float = 0.18      # [deprecated] metres of virtual compression
@export var release_threshold: float = 0.20    # [deprecated] release gate in CPG phase terms
@export var axis: Vector3 = Vector3.UP         # [deprecated] world-biased release axis
