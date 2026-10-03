class_name GaitDef
extends Resource

## Creature-level gait coordination (Fork C2). Authored on the ROOT PartGene; threaded into the
## probe by CharacteristicsEvaluator.evaluate. null = engine default (deterministic golden-angle
## phase spread), so an un-authored creature drives EXACTLY as before (L4 default-equivalence).
##
## pattern is an OPEN StringName registry (H1 door): trot | bound | pace | gallop | custom...
## assignments maps SocketDef.id -> phase as a CYCLE FRACTION in [0,1): 0.0 = in-phase,
## 0.5 = antiphase. Diagonal trot = { hip_FL:0.0, hip_FR:0.5, hip_BL:0.5, hip_BR:0.0 }.
##
## Pose-states and gait-switching get their home here later; today the probe reads only
## assignments. A socket id absent from assignments falls back to the golden-angle default for
## that joint, so partial authoring is legal.

@export var pattern:     StringName = &"trot"
@export var assignments: Dictionary[StringName, float] = {}

## Tuned CPG drive scales (filled by GaitOptimizer). 1.0 = engine default, so an
## un-tuned creature behaves exactly as before. The live controller reads these as
## its baseline Params unless the caller overrides them.
@export var amplitude_scale: float = 1.0
@export var frequency_scale: float = 1.0
@export var gain_scale:      float = 1.0
@export var turn_rate:       float = 0.0   # steady yaw rate (rad/s); 0 = straight
@export var tear_omega:      float = 0.0   # M55: joint-tear angular-speed threshold; 0 = no tearing
@export var traction_scale:  float = 0.0
@export var posture_scale:   float = 0.0

## Stance fraction of the gait cycle (>0.5 keeps >1 foot down). Higher = more feet planted at once = more
## statically stable (a crawl), lower = more airborne (a trot/run). 0 keeps the engine default (0.75). The
## honest wide-stance quad uses a HIGH duty so >=3 feet stay down (a support triangle) — that's how a
## fore-aft-hinge quad stays upright with NO reaction-less balance torque.
@export var duty: float = 0.0

## Weight-shift strength (× body weight): a horizontal force through the bearing feet that pulls the CoM
## over the feet currently on the ground, so a static-crawl quad keeps its CoM inside the shrinking support
## triangle as each foot lifts. 0 = off (engine default) so existing creatures are unchanged. The honest
## wide-stance quad uses it to WALK without tipping (fore-aft hinges can't shift weight sideways alone).
@export var weight_shift: float = 0.0

## Authored stride length (m) for the reference-tracking leg planner. 0 = derived (0.26 × leg length —
## conservative; for the quad that caps the walk below the 3 m credible bar no matter the tuning). The
## walk speed ceiling is frequency × step_len, so a creature that must cover ground authors its stride.
@export var step_len: float = 0.0

## Authored swing foot-lift height (m). 0 = derived (0.32 × leg length — far too high for a brisk
## cadence: arcing the foot 15 cm up and down inside a 0.17 s swing window is kinematically impossible,
## so feet landed late, support collapsed, and the body fell to its knees). Flat ground needs 3-5 cm.
@export var step_h: float = 0.0

## Swing-phase joint-PD scales (× the engine's LEG_SWING_KQ/KD constants; 1.0 = unchanged).
## The swing PD is the torque law that actually steps a sagittal walker's leg — before these
## fields it was a pair of hardcoded constants no tuner could reach, so GaitOptimizer searched
## a space that never touched how the leg swings. Stiffer tracks the arc tighter (risks
## overshoot/chatter at 60 Hz); softer lags the arc (feet land late, support collapses).
@export var swing_kq_scale: float = 1.0
@export var swing_kd_scale: float = 1.0

## Stance-strut scales (× LEG_EXTENSOR for the knee strut tone, × LEG_STANCE_KQ for the
## stance-hip sweep hold; 1.0 = unchanged). The strut is what keeps a stance leg a column
## under the body's weight share — with it hardcoded, the 2026-07-03 search couldn't trade
## "stiffer front strut" against anything and instead optimized a nose-down crouch around
## the folding front knees (the stand gate measures the FRONT feet carrying the bigger
## share on this body). Damping stays proportional to tone (the anti-brake ratio).
@export var extensor_scale: float = 1.0
@export var stance_kq_scale: float = 1.0

## M44: authored locomotion mode (walk | hop | lateral | …). "" = infer from `pattern` (legacy
## behaviour), so an un-authored creature drives exactly as before. The live controller prefers
## this over the pattern-string inference when set.
@export var locomotion_mode: StringName = &""

## A baked KINESTHETIC recording (MotionClip): joint angle+torque trajectories captured from a real
## demonstrated walk. When set, the live controller REPLAYS it (each joint driven toward its recorded
## angle + recorded torque feed-forward, capped by muscle) instead of the reference tracker. null = live
## tracking. This is the AI-drive training mode's output — "record what walking needs, reproduce it".
@export var motion_clip: Resource = null
