class_name JointDef
extends Resource

## Per-joint actuation envelope (Fork B3). Authored per locomotor part; resolved onto the
## PartGene the evaluator reads. null = engine default (amplitude x1, rest 0, no RoM clamp),
## so an un-authored creature drives EXACTLY as before (L4 default-equivalence).
##
## PHASE DELIBERATELY LIVES IN GaitDef, NOT here. Phase is a creature-level COORDINATION
## property (meaningless for one joint alone); amplitude / rest / range are LOCAL joint
## properties. Splitting them keeps phase single-sourced (no R7 two-homes-for-phase).

@export var amplitude:  float = 1.0    # multiplier on CPG_AMPLITUDE; 1.0 = engine default throw
@export var rest_angle: float = 0.0    # neutral hinge angle, radians (scale-free, Fork D2)
@export var angle_min:  float = 0.0    # RoM clamp lower bound, radians
@export var angle_max:  float = 0.0    # RoM clamp upper bound, radians
                                       # angle_max <= angle_min DISABLES the clamp (default 0/0)
