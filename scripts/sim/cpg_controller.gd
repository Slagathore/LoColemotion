class_name CpgController
extends Node

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")
const JointModelScript := preload("res://scripts/sim/joint_model.gd")
const JointKinematicsScript := preload("res://scripts/sim/joint_kinematics.gd")
const DriveIntentScript := preload("res://scripts/sim/drive_intent.gd")
const KinematicSkeletonScript := preload("res://scripts/sim/kinematic_skeleton.gd")
const GaitPlannerScript := preload("res://scripts/sim/gait_planner.gd")
const LegTrackerScript := preload("res://scripts/sim/leg_tracker.gd")

# M60 reference-tracking leg control (docs/LOCOMOTION_ARCHITECTURE.md). A honest legged walker drives
# its legs by tracking a GaitPlanner foot trajectory with Jacobian-transpose joint torque instead of
# the independent-sinusoid drive — the coordination the CPG couldn't hold (planted foot stays down and
# sweeps back to propel; swing foot lifts). Task-space PD; torque still clamped to each joint's tau_cap.
const LEG_TASK_K := 900.0      # foot position gain (N/m). Softer than before + heavier damping (below):
const LEG_TASK_D := 90.0       # a too-stiff foot PD at 60 Hz rings at ~8 Hz (the vibration); this damps it
const LEG_PROPEL_SCALE := 0.4  # backward stance-foot force, the propulsion for LATERAL scuttlers (crab)
                               # that have no fore-aft hip lean. Fore-aft walkers (quad) use the hip
                               # rest_angle lean instead (a foot force there fought the lean and inverted
                               # travel), so this is gated on _leg_lateral below.
const LEG_EXTENSOR := 0.9      # KNEE stance extensor tone (× cap per rad from the extended rest angle)
# The HIP gets a barely-there FIXED stance tone: any hold at rest_angle is a BRAKE on the body vaulting
# over its planted feet — measured: a 0.9×cap hip pin was the whole reason the honest quad only crept
# (3 stance legs braking, 1 driving), and even 0.15 ate ~40% of the stroke at walking torques.
const LEG_EXTENSOR_HIP := 0.05
# Sagittal walkers instead give the stance hip a MOVING joint-space reference derived from the sweep
# target: full gravity-bearing stiffness with zero braking, because the reference travels with the
# power stroke. (A fixed hold was either a brake at high tone or a butt-sag at low tone — a sagittal
# pitch hip carries real gravity moments the Z-leg's near-vertical hip axes never saw.)
const LEG_STANCE_KQ := 0.6     # stance-hip PD stiffness toward the sweep reference (× cap per rad)
const GAIT_LEAD := 0.5        # legacy shadow-pacing lead (cycles); used only when dbg_lead >= 0 re-arms
                              # the clamp. The hard distance-chained clamp DEADLOCKED the gait (cycling
                              # needed travel, travel needed cycling) — the clock now free-runs and the
                              # anti-blowup safety is the bounded body-frame target error + force caps.
# Joint-space SWING drive (sagittal-leg walkers): at the quad's rest pose the leg Jacobian maps vertical
# foot force to ~ZERO torque (axis×r is pure fore-aft for hip AND knee), so a task-space force literally
# cannot LIFT the foot — swing clearance is a second-order knee fold the Jᵀ tracker can't see. Swing legs
# are therefore driven with explicit per-joint reference angles (hip sweeps the step, distal joints fold
# for clearance, extend to land) — the "reference joint angles" the architecture doc always intended.
const LEG_SWING_KQ := 1.2      # swing PD stiffness (× tau_cap per rad toward the reference angle)
const LEG_SWING_KD := 0.15     # swing PD damping
const LEG_FOLD_SIGN := -1.0    # distal fold direction: negative = foot trails (folds back/up) mid-swing
const GAIT_RAMP_T := 1.2       # soft start (s): the metronome's rate ramps 0 → freq over this window,
                               # so the plan asks for a gentle first stride instead of yanking the body
                               # to full walk speed from standstill (which pitched it straight over)
# HONEST HEADING HOLD: the splayed hip axes are ~24° from vertical, so every stride carries a yaw
# component that only cancels under perfectly symmetric strokes — measured, the walker curved 1.5-2.6
# rad off heading in 10 s (walking fine, scoring nothing). Differential fore-aft stroke through the
# FEET (left side pushes, right side brakes — a tank turn) holds the spawn heading; ground-reaction
# honest, no root torque.
const LEG_YAW_DAMP := 0.28     # stance-target fore-aft shift (m) per rad/s of yaw rate — strong, so
                               # yaw is killed while it is still a rate (before heading error grows)
const LEG_YAW_HOLD := 0.45     # heading-error feedback (equivalent rad/s per rad of error) — gentle,
                               # a big error term saturates the steer and eats the propulsion stroke
const LEG_SUPPORT_CAP := 0.85 # max per-foot support downforce, as a fraction of body weight (anti-jam)
const LEG_FORCE_CAP := 3.0    # hard clamp on total per-foot commanded force / body weight (anti-blowup)
# SIMBICON balance feedback (Yin/Loken/van de Panne 2007): the swing-foot target isn't just the shadow
# pose — it's shifted by the CoM state so the foot lands where the body is FALLING and catches it. d =
# horizontal CoM offset from the support (stance feet); v = CoM velocity. Falling forward/sideways → the
# swing foot reaches that way. This is the balance layer the open-loop pose-copy lacked (it jittered/fell
# because it had no notion of "am I balanced" — see the friend's force-balance diagnosis).
const SIMBICON_CD := 0.35      # swing-foot shift per metre of CoM-offset-from-support (position feedback)
const SIMBICON_CV := 0.12      # swing-foot shift per m/s of CoM velocity (velocity feedback)
# ...scaled per creature by _simbicon_scale: a NARROW stance (quad) over-steers at high gain (veers), a
# WIDE splayed stance (spider/scorpion) needs more authority to catch a wide-base tip. Derived from leg
# count as a stance-width proxy at bind.
const REPLAY_KP := 1.0        # PD stiffness (× tau_cap per rad) nudging a joint toward its baked clip angle
const REPLAY_KD := 0.08       # PD damping when replaying a baked MotionClip
# Replay keeps a fraction of the live TASK-SPACE torque (support + foot-placement + balance) alongside the
# baked feed-forward: pure joint-angle playback throws away the ground-contact stabilization that produced
# the walk (the body sags and drifts backward), so the clip supplies the *shape* while task-space keeps the
# CoM up and moving. 0 = pure clip playback, 1 = pure live tracking (clip ignored). Tuned near 0.5.
const REPLAY_SUPPORT_BLEND := 0.5
static var dbg_rkp := 100.0    # sweep overrides (>=100 -> use the constants above)
static var dbg_rblend := 100.0
static var dbg_duty := -1.0     # >0 overrides the gait duty (stance fraction); for crawl-stability sweeps
static var dbg_comshift := -1.0 # >=0 overrides the weight-shift strength; for static-crawl sweeps
static var dbg_sweep := -1.0    # stance POWER-STROKE blend for sweeps: <0 = default (1.0, full body-frame
                                # sweep — the propulsion); 0 = legacy world-locked plant hold (no drive);
                                # in-between blends plant-lock → sweep.
static var dbg_ext := -1.0      # >=0 overrides the stance extensor tone (hip AND knee) for sweeps
static var dbg_lead := -1.0     # >=0 re-arms the legacy shadow-pacing clamp at this lead (cycles);
                                # <0 = default free-running clock (the clamp deadlocked the gait)
static var dbg_step := -1.0     # >0 overrides the planner step_length (m) for sweeps
static var dbg_freq := -1.0     # >0 overrides the planner stride frequency (Hz) for sweeps
static var dbg_taskk := -1.0    # >0 overrides the task-PD gain MULTIPLIER (replaces gain_scale in
                                # k = LEG_TASK_K × mult; quad_v2's gait gain_scale=20 silently makes
                                # the "softened" 900 N/m foot PD an 18,000 N/m one)
const SIMBICON_MAX := 0.4     # cap the LATERAL balance shift as a fraction of leg reach — a big lateral
                               # shift over-reaches the swing foot into a leg-cross/jam (solver teleport).
const SIMBICON_MAX_FWD := 0.75 # the FORE-AFT shift can reach much further (no leg-cross risk along the
                               # travel axis) — a walker catching forward speed needs to land the foot
                               # well ahead (capture point); the old shared 0.4 cap saturated the catch.
const LEG_RIGHT_RATE := 0.45  # leg-righting pitch/roll RATE gain: press feet against the body's tilt
                               # VELOCITY too, catching a fall while the tilt is still small — the pure
                               # tilt term only acts once the body already leans (and a big tilt gain
                               # steals the hind feet's normal force → traction stall).
# (Removed: STEP_TRIGGER / SWING_TIME / STEP_AHEAD — dead constants from a never-wired proprioceptive
# step-trigger design; the free-running metronome + contact-gated bearing carries that role today.)

## Live CPG controller. It shares target-angle math with the analytic probe and
## applies real torques to the CreatureBody rigid bodies.

var _body: Node3D
var _root_gene: PartGene
var _drives: Array[Dictionary] = []
var _frequency := 0.0
var _energy := 0.0
var _last_commands: Array[Dictionary] = []
var _params: Params
var _root_body: RigidBody3D
var _total_mass := 1.0
var _body_radius := 1.0
var _traction_drive_count := 1
var _target_root_y := INF
var _assist_traction_impulse := 0.0
var _assist_posture_impulse := 0.0
var _spring_energy_stored := 0.0
var _spring_energy_released := 0.0
var _spring_return_work := 0.0       # M36: positive work returned by the elastic on rebound
var _tendon_energy_stored := 0.0     # M47: biarticular tendon PE stored across the coupled pair
var _tendon_energy_released := 0.0   # M47: tendon energy returned (<= stored, Principle 14)
var _foot_slip := 0.0                # M37: accumulated per-foot horizontal stance slip (m)
var _foot_slip_samples := 0          # M37: ticks with at least one foot grounded
var _overstress := {}                # M9C: per-joint consecutive-tick overstress counter
var _joint_overlays := {}             # part_index -> DriveIntent; consumed by normal PD torque
# M60 reference-tracking leg plan (honest legged walkers only). Built at bind from the shared
# KinematicSkeleton; drives leg joints via GaitPlanner + LegTracker instead of the sinusoid.
var _gait_planner = null             # GaitPlanner (foot trajectory), null when not a legged walker
var _legs: Array = []                # [{leg_i, foot_body, joints:[{child,parent,axis,cap,...}]}]
var _use_leg_tracker := false
var _part_bodies: Array = []         # index-aligned live bodies, for distal-subtree CoM (gravity-comp)
var _leg_support_scale := 1.4        # stance weight-bearing downforce as a fraction of weight/leg
var _ground_y := INF                 # world height the planted feet rest at (captured on first tick)
var _leg_lateral := false            # lateral scuttle (crab): the foot plan sweeps along body X, not Z
var _uses_hip_lean := false          # a fore-aft hip rest_angle lean propels (quad); else the propel force
var _swing_joint_pd := false         # sagittal legs: swing driven by per-joint reference angles (see consts)
var _swing_kq := LEG_SWING_KQ        # swing PD stiffness, authorable via GaitDef.swing_kq_scale
var _swing_kd := LEG_SWING_KD        # swing PD damping, authorable via GaitDef.swing_kd_scale
var _ext_knee := LEG_EXTENSOR        # knee strut tone, authorable via GaitDef.extensor_scale
var _stance_kq := LEG_STANCE_KQ      # stance-hip sweep-hold stiffness, via GaitDef.stance_kq_scale
var _walk_heading := Vector3.ZERO    # world heading captured at first walk tick (heading-hold reference)
var _simbicon_scale := 1.0           # per-creature SIMBICON gain multiplier (from stance width / leg count)
var _leg_right := 0.0                # leg-based ROLL/PITCH righting gain — on for WIDE stances (splayed)
var _com_shift_k := 0.0              # weight-shift strength (× body weight): pull CoM over the support feet
static var dbg_cd := -1.0            # >=0 overrides SIMBICON_CD (sweep tuning)
static var dbg_cv := -1.0            # >=0 overrides SIMBICON_CV (sweep tuning)
static var dbg_right := 999.0        # <100 overrides the leg-righting gain (sweep tuning, incl. sign)
# KINESTHETIC capture/replay (the AI-drive training mode): while capturing, the controller records each
# leg joint's angle + applied torque per gait-phase bin; that bakes into a MotionClip which can then be
# REPLAYED (each joint driven toward its recorded angle + recorded torque feed-forward, capped by muscle).
var _capturing := false
var _cap_bins := 24
var _cap_asum := {}                  # part_index -> PackedFloat32Array(bins): angle sums
var _cap_tsum := {}                  # part_index -> PackedFloat32Array(bins): torque sums
var _cap_cnt := {}                   # part_index -> PackedInt32Array(bins): sample counts
var _replay_clip = null              # MotionClip while replaying, else null
var _last_joint_tau := {}            # part_index -> last applied torque (N·m): the live "tension sensor"
var _gait_fwd := 0.0                 # accumulated forward distance the body has ACTUALLY travelled (m)
var _prev_body_pos := Vector3.INF    # body origin last tick, for the forward-progress delta
var _ref_phase := 0.0                # paced reference phase (cycles): shadows the physics, never racing

const TEAR_TICKS := 6                # ticks above tear_omega before a joint actually tears


class Params:
	var gain_scale := 1.0
	var frequency_scale := 1.0
	var torque_scale := 1.0
	var phase_perturb := 0.0
	var damping_scale := 1.0
	var amplitude_scale := 1.0   # scales joint swing range; bigger = more foot clearance
	var traction_scale := 0.0    # phase/contact-gated ground-reaction assist
	var posture_scale := 0.0     # root upright stabilizer for simplified balance
	var turn_rate := 0.0         # desired yaw rate (rad/s); steers the body so traction curves the path
	var tear_omega := 0.0        # M9C: if >0, a joint sustaining |rel angular vel| above this tears (opt-in)
	var locomotion_mode: StringName = &"walk"  # walk | hop | lateral
	var lateral_sign := 1.0
	var hop_lift_scale := 1.0
	# M60 honest locomotion (Cole's no-cheats goal). When true: NO forward central-force shove and NO
	# anti-gravity lift — the legs support the body (stance foot-press) and propel via real friction.
	# Default false keeps the legacy assisted path so un-migrated creatures + their tests are
	# unchanged; creatures are migrated to honest one at a time, after which the legacy path is removed.
	var honest := false


func bind(body: Node3D, root: PartGene, params: Params = null) -> void:
	_body = body
	_root_gene = root
	_params = params if params != null else Params.new()
	if params == null and root != null and root.gait != null:
		_params.amplitude_scale = root.gait.amplitude_scale
		_params.frequency_scale = root.gait.frequency_scale
		_params.gain_scale = root.gait.gain_scale
		_params.traction_scale = root.gait.traction_scale
		_params.posture_scale = root.gait.posture_scale
		_params.turn_rate = root.gait.turn_rate
		# M44: an authored locomotion_mode wins; else infer from the pattern string (legacy).
		if root.gait.locomotion_mode != &"":
			_params.locomotion_mode = root.gait.locomotion_mode
		else:
			var pat := String(root.gait.pattern)
			if pat.contains("hop") or pat.contains("pogo") or pat.contains("pronk"):
				_params.locomotion_mode = &"hop"
			elif pat.contains("side") or pat.contains("scuttle"):
				_params.locomotion_mode = &"lateral"
	_drives.clear()
	_last_commands.clear()
	_energy = 0.0
	_root_body = null
	_total_mass = 1.0
	_body_radius = 1.0
	_traction_drive_count = 1
	_target_root_y = INF
	_assist_traction_impulse = 0.0
	_assist_posture_impulse = 0.0
	_spring_energy_stored = 0.0
	_spring_energy_released = 0.0
	_spring_return_work = 0.0
	_tendon_energy_stored = 0.0
	_tendon_energy_released = 0.0
	_foot_slip = 0.0
	_foot_slip_samples = 0
	_overstress.clear()
	_joint_overlays.clear()
	_gait_planner = null
	_legs.clear()
	_use_leg_tracker = false
	_part_bodies = []
	_ground_y = INF
	_gait_fwd = 0.0
	_prev_body_pos = Vector3.INF
	_ref_phase = 0.0
	_leg_lateral = false
	_uses_hip_lean = false
	_swing_joint_pd = false
	_leg_right = 0.0
	_walk_heading = Vector3.ZERO
	if body == null or root == null or not body.has_method("part_bodies"):
		return
	var fold := CE.fold_graph(root, Transform3D.IDENTITY)
	var parts: Array = fold["parts"]
	var eval := CE.evaluate(root)
	_total_mass = maxf(float(eval["total_mass"]), 0.001)
	_body_radius = maxf(float(eval["body_radius"]), 0.001)
	_frequency = CE.cpg_frequency(float(eval["body_radius"])) * _params.frequency_scale
	var bodies: Array = body.call("part_bodies")
	if not bodies.is_empty():
		_root_body = bodies[0] as RigidBody3D
	var drive_meta: Array = body.call("drive_joints") if body.has_method("drive_joints") else []
	var meta_by_index := {}
	for m in drive_meta:
		meta_by_index[int(m["part_index"])] = m
	var all_ground_contacts := _ground_contacts_for(parts, bodies, 0)
	var joint_i := 0
	var gait: GaitDef = root.gait
	var traction_count := 0
	for p in parts:
		if not p.tags.has(&"locomotor") or p.hinge_axis.length() < CE.EPS:
			continue
		if int(p.index) < 0 or int(p.index) >= bodies.size():
			continue
		var child := bodies[int(p.index)] as RigidBody3D
		var parent := bodies[int(p.parent)] as RigidBody3D if int(p.parent) >= 0 and int(p.parent) < bodies.size() else null
		var meta: Dictionary = meta_by_index.get(int(p.index), {})
		if child == null or parent == null or meta.is_empty():
			continue
		var amp := 1.0
		var rest := 0.0
		var amin := 0.0
		var amax := 0.0
		if p.joint != null:
			amp = p.joint.amplitude
			rest = p.joint.rest_angle
			amin = p.joint.angle_min
			amax = p.joint.angle_max
		var inertia := JointModelScript.subtree_inertia(parts, int(p.index),
				float(eval["total_mass"]), float(eval["body_radius"]))
		var muscle_frac := JointModelScript.subtree_muscle_frac(parts, int(p.index))
		var tau_cap := CE.cpg_torque_cap(false, muscle_frac, inertia)
		var contacts := _ground_contacts_for(parts, bodies, int(p.index))
		if p.spring != null and contacts.is_empty():
			contacts = all_ground_contacts
		var parent_part = parts[int(p.parent)] if int(p.parent) >= 0 and int(p.parent) < parts.size() else null
		var traction_enabled: bool = parent_part == null or not parent_part.tags.has(&"locomotor")
		if traction_enabled and not contacts.is_empty():
			traction_count += 1
		_drives.append({
			"index": int(p.index),
			"child": child,
			"parent": parent,
			"axis": meta["axis_world"],
			"axis_parent_local": meta["axis_parent_local"],
			"rest_rel": meta["rest_rel"],
			"phase": CE.cpg_phase(gait, p.socket, joint_i, _params.phase_perturb),
			"amp": amp * _params.amplitude_scale,
			"rest": rest,
			"amin": amin,
			"amax": amax,
			"inertia": inertia,
			"kp": CE.KP_BASE * inertia * _params.gain_scale,
			"kd": CE.KD_BASE * inertia * _params.damping_scale,
			"tau_cap": tau_cap * _params.torque_scale,
			"contacts": contacts,
			"traction_enabled": traction_enabled,
			"spring": p.spring,
			"spring_stored": 0.0,
			# M36: spring neutral at full extension, so a crouch (theta below rest) LOADS it (catapult).
			# M60 stance-spring: a leg tagged &"stance_spring" rests at its joint rest_angle (a braced
			# BENT stance) instead, so the spring HOLDS the leg up under the body weight without
			# launching it — the support a walker needs (the catapult rest braces but also launches,
			# wrong for stance). Jumpers (frog/hopper, untagged) keep the full-extension catapult rest.
			"spring_rest": (rest if p.tags.has(&"stance_spring") \
					else (amax if amax > amin else (rest + 0.6))),
			# M39: contact-subset limbs (pogo/radial) fire on REAL contact, not phase.
			"contact_subset": p.tags.has(&"pogo") or p.tags.has(&"radial"),
			# M47: biarticular tendon coupling (resolved to a partner drive after the loop).
			"tendon": p.tendon,
			"part_id": p.part_id,
			"tendon_partner": -1,
			"_theta": 0.0,
			"_omega": 0.0,
		})
		joint_i += 1
	_traction_drive_count = maxi(traction_count, 1)
	# Honest single-leg pogo (monopod): a light linear damp on every body bleeds the resonant vertical
	# pump-up (the settle->run rebound that otherwise over-launches the one-legged body) into a steady
	# in-place bounce. This is passive internal/air friction (a physical drag), not a locomotion assist —
	# it removes energy, never adds forward/vertical thrust. Scoped to the &"monopod" root so multi-leg
	# hoppers (e.g. the frog, which MUST get a real flight phase) are untouched.
	if _is_monopod():
		for rb in bodies:
			if rb is RigidBody3D:
				(rb as RigidBody3D).linear_damp = 2.2
				(rb as RigidBody3D).angular_damp = 1.0
	_soften_long_spine_chains(parts)
	_resolve_tendon_partners()
	_build_leg_plan(parts, bodies)


# M47/§C lever 1: long open SPINE chains (serpent/centipede) blow up under full PD drive — and the
# doc's soft-limit-param plan is a no-op on Jolt. The engine-agnostic, HONEST lever is less drive:
# scale kp/kd + the muscle torque cap down by how many driven spine segments there are. Tag-based on
# &"spine", so parallel-leg walkers (whose driven parts aren't spine) are untouched (I6-friendly).
func _soften_long_spine_chains(parts: Array) -> void:
	var spine_drives := 0
	for d in _drives:
		var idx := int(d["index"])
		if idx >= 0 and idx < parts.size() and parts[idx].tags.has(&"spine"):
			spine_drives += 1
	if spine_drives <= 6:
		return
	var soft := clampf(6.0 / float(spine_drives), 0.4, 1.0)
	for d in _drives:
		d["kp"] = float(d["kp"]) * soft
		d["kd"] = float(d["kd"]) * soft
		d["tau_cap"] = float(d["tau_cap"]) * soft


# M60: build the reference-tracking leg plan from the shared KinematicSkeleton. Only honest legged
# walkers opt in — the plan drives their leg joints via GaitPlanner+LegTracker (below), everything else
# keeps the sinusoid drive. The gate is precise: honest tag + walk/trot mode + at least one foot, which
# today is only quad_v2 (a WIP not in the suite), so no existing creature or test is perturbed.
func _build_leg_plan(parts: Array, bodies: Array) -> void:
	_part_bodies = bodies
	if not _is_honest():
		return
	# Gate on the creature's DESIGNED gait mode from the gene, not _params.locomotion_mode — a rollout
	# that passes a default Params (mode defaults to &"walk") would otherwise wrongly engage the tracker
	# on a jumper/undulator whose own gait never set a mode. Only a gait explicitly authored walk/trot
	# opts in (today: quad_v2). Frog/hopper (mode unset or hop) and everything else keep their drive.
	var gait_mode: StringName = &""
	if _root_gene != null and _root_gene.gait != null:
		gait_mode = _root_gene.gait.locomotion_mode
	# M60 lateral walk (crab): a &"side_scuttle"/&"lateral" gait opts the SAME reference-tracking leg
	# tracker in, but the foot sweep runs along the body's local X (sideways) instead of -Z (fore-aft),
	# so the honest friction stroke carries the body SIDEWAYS — a real crab scuttle.
	var lateral_walk := (gait_mode == &"side_scuttle" or gait_mode == &"lateral")
	if not (gait_mode == &"walk" or gait_mode == &"trot" or lateral_walk):
		return
	var ks = KinematicSkeletonScript.from_fold({"parts": parts, "warnings": []})
	var feet := ks.feet()
	if feet.is_empty():
		return
	# Skip body-UNDULATORS (serpent/centipede) even when they have feet + walk mode — they propel by the
	# anisotropic belly chain, and the leg tracker would fight that thrust. Only true legged walkers,
	# whose feet actually carry the body, opt in.
	for p in parts:
		if p.tags.has(&"anisotropic_ventral") or p.tags.has(&"undulate"):
			return
	var drive_by_index := {}
	for i in _drives.size():
		drive_by_index[int(_drives[i]["index"])] = i
	var gp = GaitPlannerScript.new()
	# Scale the step to the LEG, not the body: the foot-rest depth (|rest.y|) is the leg length. Keep
	# steps SHORT so the stance leg stays near-straight — the body-weight line then passes close to the
	# knee (tiny knee moment), which matters because the knee tau_cap is far below the hip's.
	var leg_len := maxf(absf(ks.foot_rest_local(feet[0]).y), 0.05)
	var freq := clampf(0.9 * _params.frequency_scale, 0.4, 1.6)
	if dbg_freq > 0.0:
		freq = dbg_freq
	var step_len := clampf(0.26 * leg_len, 0.04, 0.30) * clampf(_params.amplitude_scale, 0.5, 1.5)
	# Authored stride override (GaitDef.step_len, 0 = derived). The derived 0.26·leg_len is conservative:
	# for the quad it caps the walk at freq×step_len ≈ 1.9 m / 10 s — BELOW the 3 m credible-walk bar, so
	# no amount of balance/duty tuning could ever pass. Creatures that need a real stride author it.
	if _root_gene != null and _root_gene.gait != null and _root_gene.gait.step_len > 0.0:
		step_len = _root_gene.gait.step_len
	if dbg_step > 0.0:
		step_len = dbg_step
	var step_h := clampf(0.32 * leg_len, 0.05, 0.25)
	# Authored swing lift (GaitDef.step_h, 0 = derived). The derived 0.32·leg_len lift is unreachable
	# inside a brisk swing window — feet landed late, support collapsed. Flat ground wants a few cm.
	if _root_gene != null and _root_gene.gait != null and _root_gene.gait.step_h > 0.0:
		step_h = _root_gene.gait.step_h
	# High duty (many feet down at once) keeps the per-leg load low — a trot that lifts diagonal pairs
	# doubles the load on the two stance legs, saturating a weak knee and tilting the body.
	# Lateral scuttlers sweep the feet along body-local +X (sideways); fore-aft walkers along -Z (the
	# metric's Vector3.FORWARD). The trot phase pattern must be authored so the creature's intrinsic
	# travel matches this — propel/swing then reinforce it (misaligned, the belly drags).
	var plan_fwd := Vector3(1.0, 0.0, 0.0) if lateral_walk else Vector3(0.0, 0.0, -1.0)
	# Duty from the authored gait (0 -> engine default 0.75); dbg_duty overrides for sweeps. A high duty
	# (honest wide quad) keeps >=3 feet down so the support stays a polygon, not a diagonal line.
	var gait_duty := 0.0
	if _root_gene != null and _root_gene.gait != null:
		gait_duty = float(_root_gene.gait.duty)
	var duty_frac: float = dbg_duty if dbg_duty > 0.0 else (gait_duty if gait_duty > 0.0 else 0.75)
	gp.configure(freq, step_len, step_h, duty_frac, plan_fwd)
	# Authored swing-PD + stance-strut scales (GaitDef, 1.0 = the constants unchanged) — the
	# torque laws that actually step and hold the leg, opened up so GaitOptimizer can search
	# them (they were untunable constants before; the strut being fixed is why the first
	# search settled for a nose-down crouch instead of stiffening the folding front knees).
	_swing_kq = LEG_SWING_KQ
	_swing_kd = LEG_SWING_KD
	_ext_knee = LEG_EXTENSOR
	_stance_kq = LEG_STANCE_KQ
	if _root_gene != null and _root_gene.gait != null:
		_swing_kq = LEG_SWING_KQ * clampf(_root_gene.gait.swing_kq_scale, 0.1, 4.0)
		_swing_kd = LEG_SWING_KD * clampf(_root_gene.gait.swing_kd_scale, 0.1, 4.0)
		_ext_knee = LEG_EXTENSOR * clampf(_root_gene.gait.extensor_scale, 0.1, 4.0)
		_stance_kq = LEG_STANCE_KQ * clampf(_root_gene.gait.stance_kq_scale, 0.1, 4.0)
	var leg_i := 0
	for fi in feet:
		var chain := ks.chain_to_foot(fi)
		var joint_list: Array = []
		var hip_phase := 0.0
		var got_phase := false
		for pidx in chain:
			if not drive_by_index.has(pidx):
				continue
			var di := int(drive_by_index[pidx])
			var d := _drives[di]
			d["leg_tracked"] = true            # main loop skips the sinusoid drive for this joint
			if not got_phase:
				hip_phase = float(d["phase"]) / TAU
				got_phase = true
			var rr: Basis = d["rest_rel"]
			var axis_pl: Vector3 = d["axis_parent_local"]
			# The hinge ANCHOR in child-local coords: the fold law hangs the child by its proximal end
			# (child_anchor = (0,-half_len,0)), so the anchor sits at -child_anchor.origin from the child's
			# centre. Jᵀ/gravity-comp used the child CENTRE as the pivot before — under-delivering hip
			# torque by ~32% and knee by ~46% on the quad (r was measured from the wrong point).
			var anchor_cl := Vector3.ZERO
			var p_res = parts[pidx] if pidx >= 0 and pidx < parts.size() else null
			if p_res != null and p_res.socket != null:
				anchor_cl = -p_res.socket.child_anchor.origin
			joint_list.append({
				"child": d["child"],
				"parent": d["parent"],
				"axis_parent_local": axis_pl,
				# hinge_angle's delta quaternion lives in the CHILD-REST frame; dotting it against the
				# parent-frame axis compressed every measured angle by the socket basis' axis-alignment
				# (0.414× on the quad's splayed thighs — rest_angle −0.12 really held −0.29). Precompute
				# the axis in the child-rest frame so the tracker reads TRUE hinge angles.
				"axis_child_rest": (rr.inverse() * axis_pl).normalized(),
				"anchor_child_local": anchor_cl,
				"is_hip": joint_list.is_empty(),   # first chain joint = the hip (fore-aft sweep joint)
				"axis_world0": Vector3(d["axis"]),  # build-pose world hinge axis (sagittal detection)
				"rest_rel": rr,
				# extended-stance angle (extensor-tone target / standing brace pose).
				"rest_angle": float(d["rest"]),
				"tau_cap": float(d["tau_cap"]),
				"subtree_indices": ks.subtree_indices(pidx),
				"subtree_mass": ks.subtree_mass(pidx),
			})
		if joint_list.is_empty():
			continue
		var foot_body: RigidBody3D = bodies[fi] if fi >= 0 and fi < bodies.size() else null
		gp.add_leg(fi, ks.foot_rest_local(fi), hip_phase)
		# Per leg: the gait clock (phase offset) decides WHEN it lifts (a quad trots — diagonal pairs a
		# half-cycle apart); plant_pos is the world-locked stance foot, captured when the foot touches down.
		_legs.append({
			"leg_i": leg_i, "foot_body": foot_body, "joints": joint_list,
			"rest_local": ks.foot_rest_local(fi), "plant_pos": null,
			# Per-leg gait FSM init (sagittal walkers): all legs start in stance, staggered through the
			# stroke by their authored phase offsets so the first liftoffs come in gait order.
			"st": &"stance", "sp": clampf(hip_phase / maxf(duty_frac, 0.05), 0.0, 0.99),
		})
		leg_i += 1
	if _legs.is_empty():
		return
	_leg_lateral = lateral_walk
	# A fore-aft walker propels one of two ways: (a) a hip rest_angle LEAN (quad — the stance legs angle
	# back and the body vaults over them), or (b) the backward PROPEL foot force. A leg tracker that
	# world-locks the stance foot has NO swept-target propulsion (the old sweep was it), so a leg with a
	# ~flat hip (spider/daddy-longlegs/scorpion) gets no drive unless we turn the propel force back on.
	# Detect the lean from the hip (first) joint's rest_angle; if none, the creature uses the propel force.
	_uses_hip_lean = false
	for lg in _legs:
		var jl: Array = lg["joints"]
		if not jl.is_empty() and absf(float(jl[0]["rest_angle"])) > 0.08:
			_uses_hip_lean = true
			break
	# Sagittal-plane legs (fore-aft walkers): swing needs JOINT-SPACE references — their Jacobian maps
	# vertical foot force to ~zero torque at rest, so the task force cannot lift a foot (measured:
	# plants=0 forever). Lateral scuttlers / Y-hip splayed walkers CAN lift through task space (their
	# lift hinge sees vertical), so they keep the task-space swing. Detect sagittal hips GEOMETRICALLY
	# (hip hinge axis mostly along the cross-track direction = a pitch hinge that sweeps fore-aft) —
	# the old proxy (a hip rest_angle lean) broke the moment the lean stopped being the propulsion.
	var lat_dir := plan_fwd.cross(Vector3.UP).normalized()
	var sagittal_hips := false
	for lg in _legs:
		var jl0: Array = lg["joints"]
		if not jl0.is_empty():
			sagittal_hips = absf(Vector3(jl0[0]["axis_world0"]).normalized().dot(lat_dir)) > 0.7
		break
	_swing_joint_pd = sagittal_hips and not _leg_lateral
	# More legs ⇒ wider/splayed base ⇒ SIMBICON needs more authority to catch a wide tip; a 4-leg quad
	# with a narrow stance over-steers at that gain. Scale by leg count (2→0.8 … 8→1.6).
	_simbicon_scale = clampf(float(_legs.size()) / 4.0, 0.8, 1.3)
	# Leg-based righting is the complement to SIMBICON: SIMBICON catches a TRANSLATIONAL fall (CoM off the
	# support) but is blind to the body TILTING while its CoM stays over the support centre — that needs
	# differential vertical foot force. Its axis math is general (axis_r = up×UP handles PITCH as well as
	# roll — for a nose-down tilt the front feet press harder and the ground reaction lifts the nose).
	# ON, bounded, for sagittal fore-aft walkers: with the stance power stroke restored, propulsion
	# pitches the body nose-down and NOTHING else in the honest path opposes pitch (posture torque is off,
	# SIMBICON only shifts swing targets). Splayed/lateral walkers keep it off (their wide-stance
	# auto-gain over-forced into a teleport in earlier sweeps); dbg_right still overrides for tuning.
	_leg_right = 0.35 if _swing_joint_pd else 0.0
	_com_shift_k = 0.0
	if _root_gene != null and _root_gene.gait != null:
		_com_shift_k = maxf(0.0, float(_root_gene.gait.weight_shift))
	_gait_planner = gp
	_use_leg_tracker = true
	# If this creature has a baked kinesthetic clip, REPLAY it (drive joints toward the recorded angles +
	# feed-forward torque) instead of the live reference tracker.
	if _root_gene != null and _root_gene.gait != null and _root_gene.gait.motion_clip != null:
		_replay_clip = _root_gene.gait.motion_clip


func tick(t: float, delta: float) -> void:
	_last_commands.clear()
	_assist_posture_impulse += _apply_posture_stabilizer() * delta
	_apply_steering()
	if _use_leg_tracker:
		_apply_leg_tracking(t, delta)
	if _params != null and _params.locomotion_mode == &"roll":
		_apply_roll(delta)   # M60: rolling controller for a curlable body
	var to_tear: Array = []
	for d in _drives:
		if bool(d.get("leg_tracked", false)):
			continue   # M60: driven by the reference-tracking leg pass, not the sinusoid
		var child: RigidBody3D = d["child"]
		var parent: RigidBody3D = d["parent"]
		var axis: Vector3 = d["axis"]
		var parent_w := 0.0 if parent == null else parent.angular_velocity.dot(axis)
		var omega := child.angular_velocity.dot(axis) - parent_w
		# M9C: a joint slamming past tear_omega for TEAR_TICKS consecutive ticks tears off.
		if _params.tear_omega > 0.0:
			var oi := int(d["index"])
			if absf(omega) > _params.tear_omega:
				_overstress[oi] = int(_overstress.get(oi, 0)) + 1
				if int(_overstress[oi]) >= TEAR_TICKS:
					to_tear.append(d)
					continue
			else:
				_overstress[oi] = 0
		var phase_t := CE.cpg_phase_t(_frequency, t, float(d["phase"]))
		var base_target := CE.cpg_target_from_phase_t(float(d["rest"]), float(d["amp"]),
				phase_t, float(d["amin"]), float(d["amax"]))
		var target := _overlay_target(int(d["index"]), base_target)
		var theta := JointKinematicsScript.hinge_angle(parent.global_basis, child.global_basis,
				d["rest_rel"], d["axis_parent_local"])
		var tau := float(d["kp"]) * (target - theta) - float(d["kd"]) * omega
		tau = clampf(tau, -float(d["tau_cap"]), float(d["tau_cap"]))
		if is_finite(tau):
			child.apply_torque(axis * tau)
			if parent != null:
				parent.apply_torque(axis * -tau)
		_energy += absf(tau * omega) * delta
		var traction := _apply_stance_traction(d, phase_t, parent)
		_assist_traction_impulse += traction * delta
		var spring := _apply_spring_drive(d, theta, omega, delta)
		_apply_contact_subset_drive(d, omega, delta)
		d["_theta"] = theta        # M47: stash joint state for the post-loop tendon coupling pass
		d["_omega"] = omega
		_last_commands.append({
			"index": int(d["index"]),
			"target": target,
			"base_target": base_target,
			"theta": theta,
			"phase_t": phase_t,
			"tau": tau,
			"omega": omega,
			"traction": traction,
			"spring_stored": float(spring.get("stored", 0.0)),
			"spring_released": float(spring.get("released", 0.0)),
			"overlay": _joint_overlays.has(int(d["index"])),
		})
	_apply_tendon_coupling(delta)
	_accumulate_foot_slip(delta)
	_decay_overlays()
	for d in to_tear:
		_drives.erase(d)
		_overstress.erase(int(d["index"]))
		if _body != null and _body.has_method("tear_joint"):
			_body.call("tear_joint", int(d["index"]), "overstress")


# Steering assist: a PD on the root's yaw angular velocity toward turn_rate. The
# body turns, so the heading-aligned stance traction curves the path. Off when
# turn_rate ~ 0 (straight gait unchanged).
func _apply_steering() -> void:
	if _root_body == null or absf(_params.turn_rate) < 0.0001:
		return
	var up := Vector3.UP
	var yaw_vel := _root_body.angular_velocity.dot(up)
	var inertia_yaw := maxf(_total_mass * _body_radius * _body_radius, 0.001)
	var torque := up * (_params.turn_rate - yaw_vel) * inertia_yaw * 4.0
	if torque.is_finite():
		_root_body.apply_torque(torque)


func set_turn_rate(r: float) -> void:
	if _params != null:
		_params.turn_rate = r


# M60 reference-tracking leg pass. Each leg pulls its real foot toward the GaitPlanner target with
# Jacobian-transpose joint torque (+ gravity-comp feed-forward), all clamped to tau_cap. During stance a
# downward bias makes the leg bear its share of body weight (honest support via the same joint torque,
# NOT a central lift). Propulsion is emergent: the stance foot presses down+back, grips, and the reaction
# carries the body forward; the swing foot lifts and returns. No foot is pinned, no body is shoved.
# wants_settle_tick / settle_tick: a legged walker holds a STANDING pose while the sim settles it, the
# way a real animal doesn't go limp when set down. Without this the unbraced legs fold to belly during
# the settle ticks (the controller isn't driven then) and the walk starts from an unrecoverable heap.
func wants_settle_tick() -> bool:
	# Leg-tracked walkers hold a standing pose; the single-leg pogo (monopod) also needs to settle BRACED —
	# left limp it topples during the settle ticks before its drive ever engages.
	return _use_leg_tracker or _is_monopod()


func _is_monopod() -> bool:
	return _root_gene != null and _root_gene.tags.has(&"monopod")


func settle_tick(delta: float) -> void:
	if _use_leg_tracker:
		_apply_posture_stabilizer()   # honest upright balance — legs with only a fore-aft hinge can't
		_apply_leg_tracking(0.0, delta, true)   # resist roll, so the body needs the righting torque too
	elif _is_monopod():
		# Honest hop settle: hold the leg joints at their rest pose (a braced stand) + the upright
		# balance torque, so the pogo lands on its foot instead of folding to a heap. Pure joint PD +
		# root righting torque — no central-force cheat.
		_apply_posture_stabilizer()
		for d in _drives:
			var child: RigidBody3D = d["child"]
			var parent: RigidBody3D = d["parent"]
			if child == null or parent == null:
				continue
			var axis: Vector3 = d["axis"]
			var parent_w := parent.angular_velocity.dot(axis)
			var omega := child.angular_velocity.dot(axis) - parent_w
			var theta := JointKinematicsScript.hinge_angle(parent.global_basis, child.global_basis,
					d["rest_rel"], d["axis_parent_local"])
			var tau := float(d["kp"]) * (float(d["rest"]) - theta) - float(d["kd"]) * omega
			tau = clampf(tau, -float(d["tau_cap"]), float(d["tau_cap"]))
			if is_finite(tau):
				child.apply_torque(axis * tau)
				parent.apply_torque(axis * -tau)


func _apply_leg_tracking(t: float, delta: float, standing := false) -> void:
	if _gait_planner == null or _root_body == null:
		return
	var body_x := _root_body.global_transform
	var plan_fwd: Vector3 = body_x.basis * _gait_planner.forward_local   # gait heading in world
	plan_fwd.y = 0.0
	plan_fwd = plan_fwd.normalized() if plan_fwd.length() > 0.001 else Vector3(0, 0, -1)
	var k := LEG_TASK_K * (dbg_taskk if dbg_taskk > 0.0 else maxf(_params.gain_scale, 0.1))
	var damp := LEG_TASK_D * maxf(_params.damping_scale, 0.1)
	var max_force := 2.5 * _total_mass * CE.GRAVITY
	if not standing and _walk_heading == Vector3.ZERO and plan_fwd.length() > 0.5:
		_walk_heading = plan_fwd   # heading-hold reference: the heading the walk started with
	if not standing and _ground_y == INF:   # capture ground once, feet planted after the settle-stand
		var gy := INF
		for leg0 in _legs:
			var fb := leg0["foot_body"] as RigidBody3D
			if fb != null:
				gy = minf(gy, fb.global_position.y)
		_ground_y = gy if is_finite(gy) else 0.0
	# TIMING is metronomic (the gait clock with per-leg phase offsets, so the feet ALWAYS cycle and the
	# creature can't deadlock waiting to be pushed); POSITION during stance is world-locked (below). That
	# split is the fix: the clock decides WHEN each foot lifts, physics decides HOW FAR the body got.
	var duty: float = _gait_planner.duty
	var step_len: float = _gait_planner.step_length
	var step_h: float = _gait_planner.step_height
	var ground := _ground_y if _ground_y != INF else 0.0
	# THE GAIT CLOCK free-runs. The old "shadow pacing" hard clamp (_ref_phase ≤ travelled/step_len +
	# GAIT_LEAD) chained cycling to forward travel while propulsion (the stance sweep) needs cycling —
	# a chicken-and-egg that DEADLOCKED the walk: measured, the quad stood perfectly still forever, all
	# four legs frozen mid-stance with their sweep forces cancelling. The anti-blowup role the clamp
	# played is covered by structure now: stance/swing targets are BODY-FRAME (they cannot run away from
	# a stalled body — the error is bounded by ~step_len per cycle) and the force side is capped
	# (max_force 2.5×W, LEG_FORCE_CAP, per-foot support cap). dbg_lead >= 0 re-arms the clamp for A/B.
	var t_eff := t
	if not standing:
		if not _prev_body_pos.is_finite():
			_prev_body_pos = body_x.origin
		var d_fwd := (body_x.origin - _prev_body_pos).dot(plan_fwd)
		_prev_body_pos = body_x.origin
		_gait_fwd += maxf(d_fwd, 0.0)                       # forward progress (metrics + optional clamp)
		var freq: float = _gait_planner.frequency           # the gait's stride rate
		# Soft start: rate ramps linearly 0 → freq over GAIT_RAMP_T, then holds (phase continuous).
		var metro_phase: float = freq * (t * t / (2.0 * GAIT_RAMP_T)) if t < GAIT_RAMP_T \
				else freq * (t - GAIT_RAMP_T * 0.5)
		_ref_phase = metro_phase
		if dbg_lead >= 0.0:
			var phys_phase := _gait_fwd / maxf(step_len, 0.02)
			_ref_phase = minf(metro_phase, phys_phase + dbg_lead)
		t_eff = _ref_phase / maxf(freq, 0.01)
	# Support share = full body weight / the number of feet ACTUALLY BEARING right now — a foot the clock
	# calls "stance" but which is still dangling in the air carries nothing, so counting it (or the naive
	# n·duty) over-divides the support and sinks the body. Only feet within contact_eps of the ground plane
	# bear. (This is link #3, contact-triggered: the plan says WHEN to try, the ground says WHO actually
	# carries.)
	var bearing_count := 0
	var swing_count := 0                  # legs currently in their swing state (FSM path)
	var support_sum := Vector3.ZERO       # sum of bearing-foot positions -> support-polygon centre
	for lg in _legs:
		var fb0 := lg["foot_body"] as RigidBody3D
		if fb0 == null:
			continue
		# Use the hysteresis-latched grounded state (set in the per-leg loop) so this count matches who
		# actually bears — a fresh per-tick threshold check here would re-introduce the chatter.
		var lg_stance := true
		if _swing_joint_pd:
			lg_stance = StringName(lg.get("st", &"stance")) == &"stance"
			if not lg_stance:
				swing_count += 1
		else:
			lg_stance = _gait_planner.phase_of(int(lg["leg_i"]), t_eff) < duty
		if standing or (lg_stance and bool(lg.get("grounded", false))):
			bearing_count += 1
			support_sum += fb0.global_position
	var weight_share := (_total_mass * CE.GRAVITY) / maxf(float(bearing_count), 1.0)
	# SIMBICON balance vector (world, horizontal): where the swing feet must reach to catch the fall.
	# d = CoM offset from the support centre, v = CoM velocity. A pose-tracker with no such term just
	# tracks angles and topples; this is the "am I balanced?" feedback layered on the open-loop copy.
	var balance := Vector3.ZERO
	# WEIGHT SHIFT (static-crawl balance): a horizontal force, applied THROUGH the bearing feet, that pulls
	# the CoM toward the centroid of the feet currently on the ground. As each foot lifts for its step, that
	# centroid moves to the remaining feet and the CoM follows — so the CoM stays inside the support
	# triangle instead of hanging over the diagonal edge (the reason a symmetric quad tips when it steps).
	# Honest: the feet push the ground, the reaction shifts the body; no reaction-less root force.
	var com_shift := Vector3.ZERO
	if not standing and bearing_count > 0:
		var com := Vector3.ZERO
		for pb in _part_bodies:
			var rb := pb as RigidBody3D
			if rb != null:
				com += rb.global_position * rb.mass
		com /= maxf(_total_mass, 0.001)
		var support := support_sum / float(bearing_count)
		var d_off := com - support; d_off.y = 0.0                # CoM ahead/beside the support
		var v_com := _root_body.linear_velocity; v_com.y = 0.0   # CoM velocity (root as proxy)
		var reach := absf(_legs[0]["rest_local"].y) if not _legs.is_empty() else 0.5
		var cd: float = (dbg_cd if dbg_cd >= 0.0 else SIMBICON_CD) * _simbicon_scale
		var cv: float = (dbg_cv if dbg_cv >= 0.0 else SIMBICON_CV) * _simbicon_scale
		balance = d_off * cd + v_com * cv
		# Cap the two axes separately: lateral over-reach crosses the legs (solver jam) so it stays
		# tight; the FORE-AFT catch must reach further — a shared cap saturated it exactly when a
		# forward-accelerating walker needed to land the foot ahead (capture point).
		var bal_fwd := clampf(balance.dot(plan_fwd), -SIMBICON_MAX_FWD * reach, SIMBICON_MAX_FWD * reach)
		var bal_lat := (balance - plan_fwd * balance.dot(plan_fwd)).limit_length(SIMBICON_MAX * reach)
		balance = plan_fwd * bal_fwd + bal_lat
		var shift_k: float = dbg_comshift if dbg_comshift >= 0.0 else _com_shift_k
		if shift_k > 0.0:
			# LATERAL ONLY: center the CoM side-to-side over the support (kills the roll-tip when a foot
			# lifts) but leave the FORE-AFT axis to the propulsion — a full toward-centroid pull would fight
			# forward travel (as the body advances, the shift yanks it back onto the planted feet). Project
			# the correction onto the cross-track axis (perpendicular to the gait heading).
			var lat := plan_fwd.cross(Vector3.UP)
			if lat.length() > 1.0e-4:
				lat = lat.normalized()
				var lat_err := d_off.dot(lat) + v_com.dot(lat) * 0.20
				com_shift = lat * (-clampf(lat_err, -0.5, 0.5) * shift_k * _total_mass * CE.GRAVITY / 0.5)

	# YAW-FLATTENED body frame for every leg target: heading (plan_fwd) + cross-track (lat_w) +
	# translation ONLY. Foot targets must NEVER rotate with body PITCH/ROLL — a full-body-frame
	# target chases the tilt (body noses up → targets swing forward → task force drags the feet
	# forward → support leads the CoM → more tilt), a measured positive-feedback loop that slammed
	# the sagittal quad's hips to their stops during SETTLE.
	var lat_w := plan_fwd.cross(Vector3.UP).normalized()
	var fwd_local: Vector3 = _gait_planner.forward_local
	var lat_local := fwd_local.cross(Vector3.UP).normalized()
	for leg in _legs:
		var foot_body := leg["foot_body"] as RigidBody3D
		if foot_body == null:
			continue
		var li := int(leg["leg_i"])
		var rest_local: Vector3 = leg["rest_local"]
		var neutral_world: Vector3 = body_x.origin \
				+ plan_fwd * rest_local.dot(fwd_local) + lat_w * rest_local.dot(lat_local)
		neutral_world.y = ground
		var p_foot := foot_body.global_position
		var v_foot := foot_body.linear_velocity
		var phase: float = _gait_planner.phase_of(li, t_eff)
		# ANCHORED-FOOT (metronomic timing, world-locked stance position): STANCE holds the foot where it
		# planted (world-fixed) while the body rolls over it — that dissolves the reference↔physics desync
		# (#2), because the target no longer sweeps at an ASSUMED speed; it just stays put and the physics
		# body advances as far as the propulsion actually carries it. SWING arcs the foot to a fresh plant
		# AHEAD, timed by the clock.
		var leg_len := maxf(absf(rest_local.y), 0.05)
		var contact_eps := maxf(0.05, 0.14 * leg_len)
		# HYSTERESIS on ground contact: a single threshold makes `grounded` (and with it the support /
		# propel / world-lock forces) flip on/off every tick when a foot hovers at the line — an ~8 Hz
		# limit cycle, the "vibration". Use a dead-band: become grounded below contact_eps, but stay
		# grounded until the foot rises clearly past 1.7× that. State can't chatter inside the band.
		var h := p_foot.y - ground
		var was_grounded := bool(leg.get("grounded", false))
		var grounded := h < (contact_eps * 1.25) if was_grounded else h < contact_eps
		leg["grounded"] = grounded
		var in_stance: bool
		var s_prog := 0.0        # stance progress 0→1 (power stroke)
		var w_swing := 0.0       # swing progress 0→1
		if _swing_joint_pd and not standing:
			# PER-LEG CONTACT-ANCHORED GAIT FSM (sagittal walkers). The shared metronome mapped fixed
			# phase offsets onto every leg regardless of where it actually was — legs were told to swing
			# while they were the last support (hip wound to the ROM stop), told to bear while still in
			# the air, and the whole gait fell into limping attractors. Here each leg runs its OWN
			# stance→swing cycle: the stroke starts at ITS touchdown, liftoff happens only when the body
			# can afford it (enough other feet bearing, one swing at a time — the authored offsets only
			# stagger the START), and landing ends the swing the moment the foot actually touches.
			# This is the "phase advanced on contact" check the SIMBICON diagnosis called for.
			var st: StringName = leg.get("st", &"stance")
			var sp := float(leg.get("sp", 0.0))
			var cyc := maxf(float(_gait_planner.frequency), 0.01)
			if st == &"stance":
				# Soft-start: the stroke rate ramps in so the plan doesn't yank the body from standstill.
				sp += delta * (cyc / maxf(duty, 0.05)) * clampf(t / GAIT_RAMP_T, 0.0, 1.0)
				# OVER-EXTENSION liftoff (the STEP_TRIGGER semantic, finally wired): when the body has
				# advanced so far over this planted foot that it trails well past the stroke, the hip is
				# winding toward its ROM stop — the leg becomes a rigid pole-vault pivot and the body
				# noses over it (the measured face-plant at ~3 s). Such a leg LIFTS NOW, jumping the
				# one-swing-at-a-time queue, as long as it isn't the last real support.
				var foot_behind := (neutral_world - p_foot).dot(plan_fwd)
				var over_ext := grounded and foot_behind > 0.8 * step_len and bearing_count >= 3
				if sp >= 1.0 or over_ext:
					sp = minf(sp, 1.0)   # stroke done: keep supporting until liftoff is allowed
					var others_ok := bearing_count >= maxi(_legs.size() - 1, 1)
					if (not grounded) or over_ext or (others_ok and swing_count == 0):
						st = &"swing"
						sp = 0.0
			else:
				sp += delta * cyc / maxf(1.0 - duty, 0.05)
				# CONTACT-TRIGGERED landing: an ACTUAL touch (tight threshold — NOT the sticky bearing
				# latch, which doesn't release below ~1.25×contact_eps and would end every swing at
				# half-arc with the foot barely moved) near the END of the arc ends the swing; the
				# timeout ends it regardless (the reach-down plant PD then finds the floor). The gate
				# is LATE (0.8) on purpose: ending the swing at the first mid-arc skim planted every
				# foot barely ahead of neutral, so the support polygon fell ~5 cm behind the CoM per
				# stride and the body nosed over on a timer (~2.5 s). A brief toe-scuff before the
				# gate opens is physical; a chronically short step is a fall.
				var touched := h < maxf(0.035, 0.5 * contact_eps)
				if sp >= 1.0 or (touched and sp > 0.8):
					st = &"stance"
					sp = 0.0
			leg["st"] = st
			leg["sp"] = sp
			in_stance = st == &"stance"
			s_prog = sp
			w_swing = sp if st == &"swing" else 0.0
			# Synthetic cycle phase for capture/replay compatibility.
			phase = s_prog * duty if in_stance else duty + w_swing * (1.0 - duty)
		else:
			in_stance = standing or phase < duty
			s_prog = phase / maxf(duty, 1.0e-6)
			w_swing = _gait_planner.swing_progress(li, t_eff)
		# BEARING = stance AND the foot is actually on the ground. Only a bearing foot world-locks,
		# carries weight, and propels. A "stance" foot still in the air just reaches DOWN to plant (no
		# phantom mid-air support, which was pitching the body nose-down and lifting the hind feet).
		var bearing := standing or (in_stance and grounded)
		var p_des: Vector3
		leg["_mode"] = &"standing"
		leg["_swing_w"] = 0.0
		if standing:
			# Settle-stand: WORLD-LOCK the feet where they are (an animal set down holds its feet,
			# not a body-relative pose — a body-frame hold chases any tilt into a topple). The flat
			# anchor scalars are captured too so the first walk stroke continues from this plant.
			if not (leg.get("plant_pos") is Vector3):
				leg["plant_pos"] = Vector3(p_foot.x, ground, p_foot.z)
				var rel0: Vector3 = (leg["plant_pos"] as Vector3) - body_x.origin
				leg["plant_a"] = rel0.dot(plan_fwd)
				leg["plant_b"] = rel0.dot(lat_w)
				leg["plant_s"] = minf(float(leg.get("sp", 0.0)), 1.0)
			p_des = leg["plant_pos"]
		elif bearing:
			leg["_mode"] = &"bearing"
			var s_now := s_prog
			if not (leg.get("plant_pos") is Vector3):
				# Capture the touchdown HORIZONTALLY at GROUND level (locking the raw y latched hind
				# feet in the air), plus its offsets in the YAW-FLATTENED body frame and the stance
				# progress — the anchor the power stroke sweeps from.
				leg["plant_pos"] = Vector3(p_foot.x, ground, p_foot.z)
				var rel: Vector3 = (leg["plant_pos"] as Vector3) - body_x.origin
				leg["plant_a"] = rel.dot(plan_fwd)
				leg["plant_b"] = rel.dot(lat_w)
				leg["plant_s"] = minf(s_now, 1.0)
			# POWER STROKE: the stance target starts AT the actual touchdown point and sweeps BACKWARD
			# in the BODY frame as stance progresses — the reference-tracking propulsion (8edda65) the
			# world-lock (81e2148) deleted (eca2311: "the world-lock stance replaced the OLD swept foot
			# target, which was the propulsion"). Body-frame + plant-anchored = self-regulating with no
			# startup mismatch: at plan speed the target stays put on the planted foot (zero force); a
			# LAGGING body's target falls behind the foot → backward foot push → forward friction
			# reaction, bounded by ~step_len per cycle — a stalled body is pushed, never exploded.
			var s0 := float(leg.get("plant_s", 0.0))
			# Cap the sweep at stroke end: a guard-held leg (clock past its stance window) keeps
			# SUPPORTING at its end-of-stroke offset instead of winding on toward the hip's ROM stop.
			# Anchor reconstructed in the YAW-FLATTENED frame (translation + heading only).
			var a0 := float(leg.get("plant_a", (Vector3(leg["plant_pos"]) - body_x.origin).dot(plan_fwd)))
			var b0 := float(leg.get("plant_b", (Vector3(leg["plant_pos"]) - body_x.origin).dot(lat_w)))
			var sweep_target: Vector3 = body_x.origin + plan_fwd * a0 + lat_w * b0 \
					- plan_fwd * (step_len * (minf(s_now, 1.0) - s0))
			if _swing_joint_pd and _walk_heading != Vector3.ZERO:
				# HEADING HOLD (see consts): shift this side's stroke fore/aft against yaw rate +
				# heading error — left/right feet push/brake differentially, a ground-reaction turn.
				var yaw_rate: float = _root_body.angular_velocity.y
				var yaw_err := atan2(_walk_heading.cross(plan_fwd).y, _walk_heading.dot(plan_fwd))
				var steer := clampf(LEG_YAW_DAMP * (yaw_rate + LEG_YAW_HOLD * yaw_err), -0.06, 0.06)
				sweep_target += plan_fwd * (steer * signf(rest_local.x))
			sweep_target.y = ground
			var sw := dbg_sweep if dbg_sweep >= 0.0 else 1.0
			p_des = (leg["plant_pos"] as Vector3).lerp(sweep_target, clampf(sw, 0.0, 1.0))
		elif in_stance:
			leg["_mode"] = &"reach_down"
			leg["plant_pos"] = null                # clock says stance but foot dangles: reach down to plant
			p_des = neutral_world                  # straight down under the hip, at ground level
		else:
			leg["_mode"] = &"swing"
			leg["plant_pos"] = null
			var w := w_swing   # 0→1 across swing
			leg["_swing_w"] = w
			p_des = neutral_world + plan_fwd * (step_len * (w - 0.5))   # behind → ahead
			# SIMBICON: as the foot nears its plant, shift it toward the CoM's fall (balance feedback), so it
			# lands where it CATCHES the body instead of at a fixed spot — the difference between a
			# pose-tracker that topples and a controller that stays up. Eased in by swing progress w.
			p_des += balance * w
			p_des.y = ground + step_h * sin(PI * w)                     # lift in an arc
		var force := LegTrackerScript.task_force(p_des, p_foot, v_foot, k, damp, max_force)
		if bearing:
			# Cap the per-foot support: weight_share = weight/bearing_count, so a tippy many-legger that
			# drops to ONE grounded foot would otherwise press 1.4× its whole weight through that single
			# (often thin) foot — the foot jams into the floor and the solver ejects it (a teleport blow-up,
			# e.g. the scorpion). Cap it so no foot over-presses: past the cap the body just sinks/falls
			# honestly instead of exploding.
			# SAGITTAL rigs SKIP the press: on a zigzag leg a commanded down-force is NOT null-space —
			# through Jᵀ it torques the knee, which shoves the foot down-BACKWARD, i.e. ~0.5 g of
			# spurious forward thrust (measured: instant launch + back-flip). Their weight flows
			# through the strut via the extensor / stance PD; the press is a splayed-walker device.
			if not _swing_joint_pd:
				var support_f: float = minf(weight_share * _leg_support_scale,
						LEG_SUPPORT_CAP * _total_mass * CE.GRAVITY)
				force += Vector3.DOWN * support_f
			# WEIGHT SHIFT: share the CoM-centering force across the bearing feet (honest — the feet push the
			# ground, the reaction moves the body over the support triangle before the next foot lifts).
			if not standing and bearing_count > 0:
				force += com_shift / float(bearing_count)
			if not standing and not _uses_hip_lean and not _swing_joint_pd:
				# No hip lean and no stance sweep ⇒ the backward propel foot force IS the propulsion
				# (crab lateral scuttle, and the Y-hip splayed walkers). Sagittal sweep walkers skip it —
				# the power stroke already drives them, and stacking the open-loop force overdrives.
				force += -plan_fwd * weight_share * LEG_PROPEL_SCALE
			var rk: float = dbg_right if dbg_right < 100.0 else _leg_right
			if not standing and rk != 0.0:
				# HONEST leg-based righting: instead of a free root torque, press bearing feet down/up
				# asymmetrically so the ground reaction rights the body. A foot's vertical force makes a
				# torque r×ŷ about the CoM; project onto the tilt-correction axis (up×UP) → feet on the
				# body's DOWN side push harder DOWN (more support) to lift it. Net vertical ≈ 0 over a
				# symmetric stance; the torque reacts through the ground, not from nowhere.
				# A tilt-RATE term (the body's horizontal angular velocity) catches a fall while the
				# tilt is still small — the pure tilt term acts late, and cranking it instead starves
				# the hind feet's normal force (measured: upright forever but zero traction).
				var up_b := body_x.basis.y
				var w_h: Vector3 = _root_body.angular_velocity
				w_h.y = 0.0
				# up×UP = −θ·(fall axis) while ω = +θ̇·(fall axis): the rate term SUBTRACTS to point
				# the same way as the tilt correction when the body is falling further.
				var axis_r := up_b.cross(Vector3.UP) - w_h * LEG_RIGHT_RATE   # tilt + tilt-rate (world)
				var r := p_foot - body_x.origin
				var eff := (-r.z * axis_r.x + r.x * axis_r.z)  # (r×ŷ)·axis_r
				force += Vector3.DOWN * (rk * weight_share * eff)
		# Hard safety clamp on the TOTAL commanded foot force: task PD + support + propel + righting can
		# stack past task_force's own limit, and an unbounded foot force jams a foot through the floor →
		# solver ejection (teleport). Bound it to a small multiple of body weight so a bad frame degrades
		# to a stumble, never an explosion.
		force = force.limit_length(LEG_FORCE_CAP * _total_mass * CE.GRAVITY)
		if not force.is_finite():
			continue
		for j in leg["joints"]:
			var child := j["child"] as RigidBody3D
			var parent := j["parent"] as RigidBody3D
			if child == null:
				continue
			var axis_local: Vector3 = j["axis_parent_local"]
			var axis := (parent.global_basis * axis_local) if parent != null else axis_local
			if axis.length() < 1.0e-5:
				continue
			axis = axis.normalized()
			var cap := float(j["tau_cap"])
			var pidx := int(child.get_meta("part_index", -1))
			# Current joint angle + rate (needed by capture, replay, the extensor, and the swing PD).
			# The angle axis must be in the CHILD-REST frame (where the delta quaternion lives) — the
			# parent-frame axis compressed splayed-socket angles to a fraction of their true value.
			var th := 0.0
			var om := 0.0
			if parent != null:
				th = JointKinematicsScript.hinge_angle(parent.global_basis,
						child.global_basis, j["rest_rel"],
						Vector3(j.get("axis_child_rest", axis_local)))
				om = child.angular_velocity.dot(axis) - parent.angular_velocity.dot(axis)
			# Pivot = the live HINGE ANCHOR (the child's proximal end), not the child's centre — Jᵀ and
			# gravity-comp measured r from the wrong point before, under-delivering every leg torque.
			var pivot := child.global_transform * Vector3(j.get("anchor_child_local", Vector3.ZERO))
			var com: Vector3 = LegTrackerScript.subtree_com_world(
					_part_bodies, j["subtree_indices"], pivot)
			var tau_task := LegTrackerScript.joint_task_torque(axis, pivot, p_foot, force)
			var tau_grav := LegTrackerScript.joint_gravity_torque(
					axis, pivot, com, float(j["subtree_mass"]))
			var is_hip := bool(j.get("is_hip", false))
			var arm_vec := axis.cross(p_foot - pivot)   # live Jacobian column (m of foot motion per rad)
			# Extensor tone (stance only): the KNEE holds near its extended rest so the leg stays a
			# near-straight strut under load. The HIP of a sagittal walker instead tracks a MOVING
			# joint-space reference derived from the sweep target — gravity-bearing stiffness with no
			# braking (a fixed hip hold was either a brake at high tone or a butt-sag at low tone).
			var tau_ext := 0.0
			if bearing and parent != null:
				if _swing_joint_pd and is_hip:
					# Stance-hip PD toward the sweep-consistent angle, derived from the live Jacobian.
					# KNOWN DEBT: under a deep fold the live fg shrinks and this reference follows the
					# collapse (the hold softens into the measured rear-low posture). An angle-anchored
					# variant (capture θ+fg at plant, offset by sweep distance) held angles rigidly but
					# went UNDERDAMPED through the body modes and bounced the settle airborne — the
					# next iteration needs a stand-first controller with matched damping, not a
					# stiffer reference. See LOCOMOTION_ARCHITECTURE.md addendum.
					var fg := arm_vec.dot(plan_fwd)
					if absf(fg) > 0.05:
						var kq := dbg_ext if dbg_ext >= 0.0 else _stance_kq
						var ref_st := clampf((p_des - neutral_world).dot(plan_fwd) / fg, -0.9, 0.9)
						tau_ext = cap * (kq * (ref_st - th) - 0.10 * om)
				else:
					var ext := _ext_knee
					if is_hip:
						ext = dbg_ext if dbg_ext >= 0.0 else LEG_EXTENSOR_HIP
					# Damping scales with the tone (the raw 0.12·om term was an unconditional brake on
					# the body vaulting over its planted feet — on 3-4 stance legs at once).
					var ext_damp := 0.12 * ext / LEG_EXTENSOR
					tau_ext = cap * (ext * (float(j["rest_angle"]) - th) - ext_damp * om)
			var tau_live := clampf(tau_task + tau_grav + tau_ext, -cap, cap)
			var jp_mode: StringName = leg.get("_mode", &"")
			if _swing_joint_pd and parent != null \
					and (jp_mode == &"swing" or jp_mode == &"reach_down"):
				# JOINT-SPACE SWING + PLANT (sagittal legs): explicit reference angles — the hip sweeps
				# the step (fore-aft), distal joints FOLD for ground clearance and extend to land.
				# Task-space forces cannot do either here: at the rest pose this leg's Jacobian maps
				# vertical foot force to ~zero torque (lift/plant are second-order folds Jᵀ can't see) —
				# measured plants=0 on swing, and reach-down legs HUNG folded forever (no extensor when
				# not bearing, gravity-comp actively holding the leg up) while the body lost support.
				var wsw := float(leg.get("_swing_w", 0.0))
				var ref := float(j["rest_angle"])
				if is_hip:
					# Desired fore-aft foot offset from NEUTRAL (behind → ahead across the swing;
					# straight-down when re-planting) + the SIMBICON fore-aft catch, converted to a hip
					# angle via the live Jacobian column. θ = 0 is the BUILD pose (foot at neutral), so
					# the reference is des_fwd/gain from zero — not from the stance brace rest_angle.
					var fwd_gain := arm_vec.dot(plan_fwd)   # m of foot advance per +rad
					var des_fwd := 0.0
					if jp_mode == &"swing":
						des_fwd = (wsw - 0.5) * step_len + balance.dot(plan_fwd) * wsw
					if absf(fwd_gain) > 0.05:
						# Clamp the hip arc: about this rig's tilted hip axis a big reference doesn't
						# look like a step, it PADDLES the whole leg out sideways (and destabilizes).
						ref = clampf(des_fwd / fwd_gain, -0.5, 0.5)
				elif jp_mode == &"swing":
					# Fold by the angle whose chord shortens the limb enough for step_h of clearance,
					# in whichever direction actually RAISES the foot: a sagittal zigzag leg lifts
					# first-order through the knee (arm_vec.y ≠ 0), so fold toward +lift; a degenerate
					# straight leg (arm_vec.y ≈ 0, lift is second-order) falls back to the trail fold.
					var dist := (p_foot - pivot).length()
					var fold := acos(clampf(1.0 - step_h / maxf(dist, 0.05), -1.0, 1.0))
					var fold_dir := LEG_FOLD_SIGN if absf(arm_vec.y) < 0.02 else signf(arm_vec.y)
					ref += fold_dir * fold * sin(PI * wsw)
				# (reach_down: distal ref stays at rest_angle = the extended strut → the leg re-extends
				# straight down under the hip and the foot finds the ground.)
				var tau_sw := cap * (_swing_kq * (ref - th) - _swing_kd * om)
				tau_live = clampf(tau_sw + tau_grav, -cap, cap)
			var tau := tau_live
			if _replay_clip != null and pidx >= 0 and _replay_clip.has_joint(pidx):
				# KINESTHETIC REPLAY: recorded torque as feed-forward (what walking needed at this phase) +
				# a gentle PD nudge toward the recorded angle, BLENDED with the live task-space torque so the
				# body stays supported and balanced. Pure playback (blend 0) sags & drifts; blend supplies
				# ground-contact stabilization the phase-indexed table can't. All clamped to the muscle cap.
				var target: float = _replay_clip.angle_at(pidx, phase)
				var ff: float = _replay_clip.torque_at(pidx, phase)
				var rkp: float = dbg_rkp if dbg_rkp < 100.0 else REPLAY_KP
				var rblend: float = dbg_rblend if dbg_rblend < 100.0 else REPLAY_SUPPORT_BLEND
				var tau_clip := clampf(ff + cap * (rkp * (target - th) - REPLAY_KD * om), -cap, cap)
				tau = clampf(lerpf(tau_clip, tau_live, rblend), -cap, cap)
			if not is_finite(tau):
				continue
			child.apply_torque(axis * tau)
			if parent != null:
				parent.apply_torque(axis * -tau)
			if pidx >= 0:
				_last_joint_tau[pidx] = tau        # live tension sensor
				if _capturing:
					_record_capture(pidx, phase, th, tau)
			var parent_w := 0.0 if parent == null else parent.angular_velocity.dot(axis)
			var omega := child.angular_velocity.dot(axis) - parent_w
			_energy += absf(tau * omega) * delta
			# The honesty instruments read _last_commands (theta_span / max_omega feed the
			# anti-"ride the assist" rigid check in sim_rollout). Leg-tracked joints skip
			# the sinusoid loop that appends there, so a WALKING quad measured theta_span=0
			# and was flagged "rigid (no leg motion)" forever — credible_walk was
			# unreachable for every reference-tracked creature. The same blind spot hid
			# these joints from force_xray and the kinesthetic tools.
			_last_commands.append({
				"index": pidx,
				"target": th,
				"base_target": th,
				"theta": th,
				"phase_t": phase,
				"tau": tau,
				"omega": omega,
				"traction": 0.0,
				"spring_stored": 0.0,
				"spring_released": 0.0,
				"overlay": false,
			})


# --- Kinesthetic capture / replay (the AI-drive training mode) ---------------------------------------

# Begin recording the demonstrated walk: each leg joint's angle + applied torque, binned by gait phase.
func start_capture(bins := 24) -> void:
	_capturing = true
	_cap_bins = maxi(bins, 4)
	_cap_asum.clear(); _cap_tsum.clear(); _cap_cnt.clear()


func _record_capture(pidx: int, phase: float, angle: float, tau: float) -> void:
	var b := int(wrapf(phase, 0.0, 1.0) * float(_cap_bins)) % _cap_bins
	if not _cap_asum.has(pidx):
		var za := PackedFloat32Array(); za.resize(_cap_bins)
		var zt := PackedFloat32Array(); zt.resize(_cap_bins)
		var zc := PackedInt32Array(); zc.resize(_cap_bins)
		_cap_asum[pidx] = za; _cap_tsum[pidx] = zt; _cap_cnt[pidx] = zc
	var a: PackedFloat32Array = _cap_asum[pidx]; a[b] += angle; _cap_asum[pidx] = a
	var t: PackedFloat32Array = _cap_tsum[pidx]; t[b] += tau; _cap_tsum[pidx] = t
	var c: PackedInt32Array = _cap_cnt[pidx]; c[b] += 1; _cap_cnt[pidx] = c


# Stop recording and bake what was captured into a MotionClip (empty phase bins filled with the joint's
# cycle mean, so the curve is complete even if some phases got few samples).
func finish_capture():
	_capturing = false
	var clip = load("res://scripts/sim/motion_clip.gd").new()
	clip.bins = _cap_bins
	clip.frequency = float(_gait_planner.frequency) if _gait_planner != null else 1.0
	for pidx in _cap_asum.keys():
		var cnt: PackedInt32Array = _cap_cnt[pidx]
		var asum: PackedFloat32Array = _cap_asum[pidx]
		var tsum: PackedFloat32Array = _cap_tsum[pidx]
		var mean_a := 0.0; var mean_t := 0.0; var filled := 0
		for b in _cap_bins:
			if cnt[b] > 0:
				mean_a += asum[b] / float(cnt[b]); mean_t += tsum[b] / float(cnt[b]); filled += 1
		if filled > 0:
			mean_a /= float(filled); mean_t /= float(filled)
		var acurve := PackedFloat32Array(); acurve.resize(_cap_bins)
		var tcurve := PackedFloat32Array(); tcurve.resize(_cap_bins)
		for b in _cap_bins:
			if cnt[b] > 0:
				acurve[b] = asum[b] / float(cnt[b]); tcurve[b] = tsum[b] / float(cnt[b])
			else:
				acurve[b] = mean_a; tcurve[b] = mean_t
		clip.joint_indices.append(pidx)
		clip.angles.append(acurve)
		clip.torques.append(tcurve)
	return clip


# Drive by a baked MotionClip instead of the reference tracker (pass null for live tracking).
func set_replay_clip(clip) -> void:
	_replay_clip = clip


# True while a baked kinesthetic clip is driving the legs (vs the live reference tracker).
func is_replaying() -> bool:
	return _replay_clip != null


# Live "tension sensor": part_index -> last applied joint torque (N·m). What the AI is doing right now.
func joint_tensions() -> Dictionary:
	return _last_joint_tau.duplicate()


# M60 rolling controller: pump angular momentum about the body's lateral axis so a curlable body
# (ball/tortoise) rolls forward — ground friction converts the spin into translation. A PD toward a
# target roll rate ("pumping" the spin up and holding it); honest (no central translation cheat).
# Gated by mode == &"roll"; credibility is judged by SimRollout's roll gate (distance, finite floor).
func _apply_roll(delta: float) -> void:
	if _root_body == null:
		return
	# -right axis: the top of the body rolls toward forward (-Z), so the body advances forward.
	var axis := -_root_body.global_basis.x.normalized()
	if axis.is_zero_approx():
		axis = Vector3.LEFT
	# Moderate target rate + gain: too much torque spins the body in place (slip kills traction),
	# so we pump toward a roll rate the ground can actually convert into translation.
	var target := 8.0 * maxf(_params.amplitude_scale, 0.3) * maxf(_params.frequency_scale, 0.3)
	var cur := _root_body.angular_velocity.dot(axis)
	var inertia := maxf(_total_mass * _body_radius * _body_radius, 0.001)
	var torque := axis * clampf(target - cur, -target, target) * inertia * 1.6
	if torque.is_finite():
		_root_body.apply_torque(torque)
		_energy += absf(torque.dot(axis) * cur) * delta


func set_joint_target_overlay(part_index: int, target_angle: float,
		weight := 1.0, ttl_ticks := 3, source := &"unknown") -> void:
	_joint_overlays[part_index] = DriveIntentScript.make(part_index, target_angle,
			weight, ttl_ticks, source)


func clear_joint_target_overlay(part_index := -1) -> void:
	if part_index < 0:
		_joint_overlays.clear()
	else:
		_joint_overlays.erase(part_index)


func overlay_count() -> int:
	return _joint_overlays.size()


func drive_count() -> int:
	return _drives.size()


func spring_drive_count() -> int:
	var count := 0
	for d in _drives:
		var s: SpringDef = d.get("spring", null)
		if s != null and s.enabled:
			count += 1
	return count


# M39: how many limbs fire on real contact (pogo/radial). >0 => a measured-only creature.
func contact_subset_drive_count() -> int:
	var count := 0
	for d in _drives:
		if bool(d.get("contact_subset", false)):
			count += 1
	return count


func locomotion_mode() -> StringName:
	return _params.locomotion_mode if _params != null else &"walk"


func total_energy() -> float:
	return _energy


func assist_metrics(forward_m := 0.0) -> Dictionary:
	var traction := maxf(_assist_traction_impulse, 0.0)
	var posture := maxf(_assist_posture_impulse, 0.0)
	var assist_work := traction + posture
	var joint_work := maxf(_energy, 0.0)
	var total_work := joint_work + assist_work
	var weight := maxf(_total_mass * CE.GRAVITY, 0.000001)
	return {
		"traction_impulse": traction,
		"posture_impulse": posture,
		"assist_work": assist_work,
		"assist_per_meter": assist_work / (weight * maxf(absf(forward_m), 0.10)),
		"assist_ratio": assist_work / maxf(total_work, 0.000001),
		# M37: stance feet should plant (pivot), not slide. A creature that leans and
		# skids on ground reaction keeps its "stance" foot moving with the body, so its
		# slid distance approaches its forward distance. assist_ratio can't see this.
		"mean_foot_slip": maxf(_foot_slip, 0.0),
		"slip_ratio": maxf(_foot_slip, 0.0) / maxf(absf(forward_m), 0.10),
	}


func spring_metrics() -> Dictionary:
	return {
		"spring_energy_stored": maxf(_spring_energy_stored, 0.0),
		"spring_energy_released": maxf(_spring_energy_released, 0.0),
		"spring_return_work": maxf(_spring_return_work, 0.0),   # M36: feeds the economy reward
	}


func last_commands() -> Array[Dictionary]:
	return _last_commands.duplicate()


# M51 Toybox (FUN-1) — Force X-ray data: per-joint torque vectors (world axis × tau) at the child
# body, for the viewport honesty overlay. The OVERLAY draw is play-tested; this is the data feed.
func force_xray() -> Array[Dictionary]:
	var axis_by_index := {}
	var child_by_index := {}
	for d in _drives:
		axis_by_index[int(d["index"])] = d["axis"]
		child_by_index[int(d["index"])] = d["child"]
	var out: Array[Dictionary] = []
	for cmd in _last_commands:
		var idx := int(cmd.get("index", -1))
		if not axis_by_index.has(idx):
			continue
		var rb := child_by_index[idx] as RigidBody3D
		out.append({
			"index": idx,
			"at": Vector3.ZERO if rb == null else rb.global_position,
			"torque": (axis_by_index[idx] as Vector3) * float(cmd.get("tau", 0.0)),
		})
	return out


func _overlay_target(part_index: int, base_target: float) -> float:
	if not _joint_overlays.has(part_index):
		return base_target
	var intent = _joint_overlays[part_index]
	if intent == null:
		return base_target
	return lerpf(base_target, intent.target_angle, clampf(intent.weight, 0.0, 1.0))


func _decay_overlays() -> void:
	var expired: Array = []
	for k in _joint_overlays.keys():
		var intent = _joint_overlays[k]
		if intent == null:
			expired.append(k)
			continue
		intent.ttl_ticks -= 1
		if intent.ttl_ticks <= 0:
			expired.append(k)
	for k in expired:
		_joint_overlays.erase(k)


func _ground_contacts_for(parts: Array, bodies: Array, root_idx: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var stack := [root_idx]
	var seen := {}
	while not stack.is_empty():
		var idx: int = stack.pop_back()
		if seen.has(idx) or idx < 0 or idx >= parts.size():
			continue
		seen[idx] = true
		var p = parts[idx]
		if p.tags.has(&"ground_contact") and idx < bodies.size():
			var rb := bodies[idx] as RigidBody3D
			if rb != null:
				out.append({
					"body": rb,
					"half_height": maxf(float(p.dims.y) * 0.5, 0.001),
				})
		for c in parts:
			if int(c.parent) == idx and not seen.has(int(c.index)):
				stack.append(int(c.index))
	return out


func _apply_stance_traction(d: Dictionary, phase_t: float, parent: RigidBody3D) -> float:
	# M59 honesty: the stance-traction central force models a LEGGED foot pushing off the ground. It
	# is NOT physical for body-driven modes (undulation/roll/fly/pogo), where propulsion must come
	# from the body itself (anisotropic belly friction for a snake). Gating it here means an undulator
	# can never be shoved forward by the assist, even if a gait optimizer cranks traction_scale.
	if _params.locomotion_mode in [&"undulation", &"undulate", &"roll", &"fly", &"glide",
			&"pogo", &"radial"]:
		return 0.0
	if _params.traction_scale <= 0.0 or not bool(d.get("traction_enabled", false)):
		return 0.0
	var contacts: Array = d.get("contacts", [])
	if contacts.is_empty():
		return 0.0
	if _is_honest():
		return _apply_honest_leg_drive(d, phase_t, contacts)
	# LEGACY assisted path (the central-force SHOVE — a cheat). Kept only for creatures not yet
	# migrated to honest locomotion; removed as each is migrated.
	var stance := maxf(0.0, -cos(phase_t))
	if stance <= 0.02:
		return 0.0
	var heading := _traction_heading()
	var total_force := 0.0
	for c in contacts:
		var foot := c.get("body") as RigidBody3D
		if foot == null:
			continue
		var foot_bottom := foot.global_position.y - float(c.get("half_height", 0.0))
		var contact := clampf((0.10 - foot_bottom) / 0.12, 0.0, 1.0)
		if contact <= 0.0:
			continue
		var force := _total_mass * CE.GRAVITY * _params.traction_scale * stance * contact \
				/ maxf(float(_traction_drive_count), 1.0)
		if not is_finite(force) or force <= 0.0:
			continue
		if _root_body != null:
			_root_body.apply_central_force(heading * force)
			if _params.locomotion_mode == &"hop":
				_root_body.apply_central_force(Vector3.UP * force * _params.hop_lift_scale)
		elif parent != null:
			parent.apply_central_force(heading * force)
			if _params.locomotion_mode == &"hop":
				parent.apply_central_force(Vector3.UP * force * _params.hop_lift_scale)
		total_force += force
	return total_force


# Honest flag: a creature opts into no-cheat locomotion via the &"honest" root tag (so it is honest
# everywhere — editor, rollout, tests — with no Params plumbing), or the optimizer/tests force it via
# Params.honest for an honest search.
func _is_honest() -> bool:
	return _params.honest or (_root_gene != null and _root_gene.tags.has(&"honest"))


# M60 HONEST leg drive (no forward shove anywhere). A real leg does two honest things at the FOOT:
# during STANCE it presses DOWN on the ground (Newton's 3rd: ground pushes the body UP -> support +
# a bigger normal force -> more friction grip); during SWING it lifts the foot for clearance. Forward
# travel is PURE FRICTION — the joint torque sweeps the planted leg back, the gripped foot can't
# slide, so the body advances.
func _apply_honest_leg_drive(d: Dictionary, phase_t: float, contacts: Array) -> float:
	var stance := maxf(0.0, -cos(phase_t))
	var swing := maxf(0.0, cos(phase_t))
	var total_force := 0.0
	for c in contacts:
		var foot := c.get("body") as RigidBody3D
		if foot == null:
			continue
		var foot_bottom := foot.global_position.y - float(c.get("half_height", 0.0))
		var contact := clampf((0.12 - foot_bottom) / 0.14, 0.0, 1.0)
		if contact <= 0.0:
			continue
		var unit := _total_mass * CE.GRAVITY * _params.traction_scale \
				/ maxf(float(_traction_drive_count), 1.0)
		if not is_finite(unit) or unit <= 0.0:
			continue
		if stance > 0.02:
			var press := unit * stance * contact
			if _params.locomotion_mode == &"hop":
				press *= (1.0 + _params.hop_lift_scale)
			foot.apply_central_force(Vector3.DOWN * press)
			total_force += press
		if swing > 0.02:
			foot.apply_central_force(Vector3.UP * unit * swing * contact * 0.9)
	return total_force


# M36 honest passive spring: a torsional Hooke element across the SAME hinge the muscle
# drives. Stores energy on deflection off the relaxed (extended) pose; returns it on
# rebound scaled by efficiency (can't return more than stored). Contact-gated. NO central
# force on the root — the energy is delivered as joint torque against the ground (I3/§17).
func _apply_spring_drive(d: Dictionary, theta: float, omega: float, delta: float) -> Dictionary:
	var spring: SpringDef = d.get("spring", null)
	if spring == null or not spring.enabled:
		return {"stored": 0.0, "released": 0.0}
	var contacts: Array = d.get("contacts", [])
	var gate := 0.0 if contacts.is_empty() else _spring_contact_gate(contacts)
	if gate <= 0.0:
		d["spring_stored"] = 0.0                              # airborne: returned at takeoff
		return {"stored": 0.0, "released": 0.0}
	var k := maxf(spring.stiffness, 0.0)
	var c := clampf(spring.damping, 0.0, 0.95)
	var eff := clampf(spring.efficiency, 0.0, 1.0)
	var rest_s := float(d.get("spring_rest", 0.0))
	var deflect := theta - rest_s
	var tau_spring := (-k * deflect - c * k * omega) * gate
	var returning := (deflect * omega) < 0.0                  # moving back toward relaxed pose
	if returning:
		tau_spring *= eff                                     # conservativeness (Principle 14)
	var cap := float(d.get("tau_cap", 0.0))
	tau_spring = clampf(tau_spring, -cap, cap)
	var child: RigidBody3D = d["child"]
	var parent: RigidBody3D = d["parent"]
	var axis: Vector3 = d["axis"]
	if is_finite(tau_spring):
		child.apply_torque(axis * tau_spring)
		if parent != null:
			parent.apply_torque(axis * -tau_spring)
	var pe := 0.5 * k * deflect * deflect * gate
	var prev := float(d.get("spring_stored", 0.0))
	var stored := 0.0
	var released := 0.0
	if pe > prev:
		stored = pe - prev
		_spring_energy_stored += stored
	elif pe < prev:
		released = (prev - pe) * eff
		_spring_energy_released += released
		_spring_return_work += absf(tau_spring * omega) * delta
	d["spring_stored"] = pe
	return {"stored": stored, "released": released}


# M39 contact-subset actuation (pogo / urchin). Probe-BLIND (Principle 16): only the limbs
# whose foot is in REAL contact fire, each as a capped joint torque that drives the foot into
# the ground (-contact_normal projected onto the hinge). NO central force on the root — the
# thrust is joint torque against the ground (I3/§17). Net translation for a radial body emerges
# from the gait's per-spike phase offsets making contact (and thus firing) asymmetric. This is
# MEASURED-ONLY: the phase-stance probe cannot see real contact, so these modes are scored by
# the live sim and excluded from the probe correlation harness.
func _apply_contact_subset_drive(d: Dictionary, omega: float, delta: float) -> float:
	if not bool(d.get("contact_subset", false)):
		return 0.0
	var cap := float(d.get("tau_cap", 0.0))
	if cap <= 0.0:
		return 0.0
	var child: RigidBody3D = d["child"]
	var axis: Vector3 = d["axis"]
	if child == null:
		return 0.0
	var best := 0.0
	var foot: RigidBody3D = null
	for c in d.get("contacts", []):
		var fb := c.get("body") as RigidBody3D
		if fb == null:
			continue
		var foot_bottom := fb.global_position.y - float(c.get("half_height", 0.0))
		var g := clampf((0.08 - foot_bottom) / 0.10, 0.0, 1.0)   # near-binary real-contact gate
		if g > best:
			best = g
			foot = fb
	if best <= 0.0 or foot == null:
		return 0.0
	var normal := Vector3.UP                                     # flat-ground contact normal
	var r := foot.global_position - child.global_position
	if r.length() < 0.001:
		return 0.0
	# Torque sign that accelerates the foot along -normal (into the ground): the foot moves
	# along (axis x r) for a +unit torque, so pick the sign whose motion opposes the normal.
	var tau_sign := signf((axis.cross(r)).dot(-normal))
	if tau_sign == 0.0:
		return 0.0
	# M60 DIRECTIONAL pogo (Cole's urchin spec): fire the in-contact prong(s) whose outward direction
	# most OPPOSES the heading — the back prong pushes down+back, and the reaction drives the body toward
	# the heading (forward). A prong pointing along the heading (front) fires only a little (base bounce),
	# so the radial symmetry is broken into net travel instead of bouncing in place. Uses the real
	# contact set (which prongs touch) the sensors expose.
	var dir_weight := 1.0
	if _root_body != null and (_params.locomotion_mode == &"pogo"
			or _params.locomotion_mode == &"radial"):
		var out := foot.global_position - _root_body.global_position
		out.y = 0.0
		if out.length() > 0.01:
			var opp := clampf(-out.normalized().dot(_forward_heading()), 0.0, 1.0)
			dir_weight = 0.15 + 0.85 * opp   # behind prong (opp~1) fires hard; front prong just bounces
	var tau := tau_sign * cap * best * dir_weight
	if not is_finite(tau):
		return 0.0
	child.apply_torque(axis * tau)
	var parent: RigidBody3D = d["parent"]
	if parent != null:
		parent.apply_torque(axis * -tau)
	var work := absf(tau * omega) * delta                        # honest joint-work accounting
	_energy += work
	return work


# M47: resolve each tendon's partner (by part_id) to a drive position, once at bind time.
func _resolve_tendon_partners() -> void:
	var by_id := {}
	for i in _drives.size():
		var pid: StringName = _drives[i].get("part_id", &"")
		if pid != &"":
			by_id[pid] = i
	for d in _drives:
		var t: TendonDef = d.get("tendon", null)
		if t != null and t.enabled and t.partner_part_id != &"" and by_id.has(t.partner_part_id):
			d["tendon_partner"] = int(by_id[t.partner_part_id])


# M47 biarticular tendon: a torsional spring on the angular DIFFERENCE of a coupled joint pair.
# When one joint flexes it pulls the other (equal-and-opposite about each joint's own axis),
# transferring stored elastic energy across the stride. Conservative: PE = 0.5·k·diff², and
# released is capped by efficiency, so released ≤ stored (Principle 14). NO central force.
func _apply_tendon_coupling(_delta: float) -> void:
	var seen := {}
	for i in _drives.size():
		var d := _drives[i]
		var t: TendonDef = d.get("tendon", null)
		if t == null or not t.enabled:
			continue
		var pi := int(d.get("tendon_partner", -1))
		if pi < 0 or pi == i or pi >= _drives.size():
			continue
		var key := Vector2i(mini(i, pi), maxi(i, pi))
		if seen.has(key):
			continue
		seen[key] = true
		var p := _drives[pi]
		var k := maxf(t.stiffness, 0.0)
		var eff := clampf(t.efficiency, 0.0, 1.0)
		var diff := (float(d["_theta"]) - float(d["rest"])) \
				- (float(p["_theta"]) - float(p["rest"])) - t.rest_offset
		var cap := minf(float(d["tau_cap"]), float(p["tau_cap"]))
		var tau_c := clampf(-k * diff, -cap, cap)
		if is_finite(tau_c):
			var dc: RigidBody3D = d["child"]
			var dp: RigidBody3D = d["parent"]
			var pc: RigidBody3D = p["child"]
			var pp: RigidBody3D = p["parent"]
			dc.apply_torque((d["axis"] as Vector3) * tau_c)
			if dp != null:
				dp.apply_torque((d["axis"] as Vector3) * -tau_c)
			pc.apply_torque((p["axis"] as Vector3) * -tau_c)
			if pp != null:
				pp.apply_torque((p["axis"] as Vector3) * tau_c)
		var pe := 0.5 * k * diff * diff
		var prev := float(d.get("_tendon_pe", 0.0))
		if pe > prev:
			_tendon_energy_stored += pe - prev
		elif pe < prev:
			_tendon_energy_released += (prev - pe) * eff
		d["_tendon_pe"] = pe


func tendon_metrics() -> Dictionary:
	return {
		"tendon_energy_stored": maxf(_tendon_energy_stored, 0.0),
		"tendon_energy_released": maxf(_tendon_energy_released, 0.0),
	}


# M47: the largest muscle-derived joint torque ceiling across drives (muscle raises it).
func max_tau_cap() -> float:
	var best := 0.0
	for d in _drives:
		best = maxf(best, float(d.get("tau_cap", 0.0)))
	return best


func _spring_contact_gate(contacts: Array) -> float:
	var best := 0.0
	for c in contacts:
		var foot := c.get("body") as RigidBody3D
		if foot == null:
			continue
		var foot_bottom := foot.global_position.y - float(c.get("half_height", 0.0))
		# Springs begin storing energy as the foot nears the floor, not only after
		# hard overlap/contact. The wider band matters for simplified headless limbs
		# whose collision solver may hover slightly above y=0 between frames.
		best = maxf(best, clampf((0.35 - foot_bottom) / 0.45, 0.0, 1.0))
	return best


func _traction_heading() -> Vector3:
	if _params != null and _params.locomotion_mode == &"lateral":
		return _right_heading() * (1.0 if _params.lateral_sign >= 0.0 else -1.0)
	return _forward_heading()


func _forward_heading() -> Vector3:
	var heading := Vector3.FORWARD
	if _root_body != null:
		heading = _root_body.global_basis * Vector3.FORWARD
	heading.y = 0.0
	if heading.length() < 0.001:
		return Vector3.FORWARD
	return heading.normalized()


func _right_heading() -> Vector3:
	var fwd := _forward_heading()
	var right := Vector3(fwd.z, 0.0, -fwd.x)
	if right.length() < 0.001:
		return Vector3.RIGHT
	return right.normalized()


func _apply_posture_stabilizer() -> float:
	if _params.posture_scale <= 0.0 or _root_body == null:
		return 0.0
	if _target_root_y == INF:
		_target_root_y = _root_body.global_position.y
	var up := _root_body.global_basis.y.normalized()
	if up.is_zero_approx():
		return 0.0
	# M60 honesty: posture is now BALANCE ONLY — an upright righting torque (an active vestibular/
	# muscle-tone reflex). The old anti-gravity LIFT central force (which held the body up for free,
	# regardless of whether the legs supported it) is REMOVED — the legs now bear the weight via the
	# honest stance foot-press. No reaction-less vertical force is added.
	var correction_axis := up.cross(Vector3.UP)
	var torque := correction_axis * (_total_mass * CE.GRAVITY * _params.posture_scale)
	var damping := _root_body.angular_velocity * (_total_mass * _params.posture_scale * 1.5)
	# Flyer heading-hold: a wing-flapper has no ground contact to resist yaw, so a tiny left/right beat
	# imbalance integrates into a slow spin (the "excess yaw/spin" a horizontal tail can't damp). For
	# fly/glide only, add an HONEST yaw-rate damper about the world-up axis — a vestibular/tail reflex
	# that resists TURNING (angular damping, no translation), the airborne analogue of the stance
	# heading-hold a walker gets from friction. Gated on mode so no other creature is touched.
	if _params.locomotion_mode == &"fly" or _params.locomotion_mode == &"glide":
		var yaw_rate := _root_body.angular_velocity.dot(Vector3.UP)
		damping += Vector3.UP * (yaw_rate * _total_mass * _body_radius * _body_radius * 10.0)
	_root_body.apply_torque(torque - damping)
	var force_equiv := (torque - damping).length() / maxf(_body_radius, 0.001)
	# Honest creatures get balance ONLY (the upright torque) — the legs bear the weight via the
	# stance foot-press. Legacy creatures still get the anti-gravity LIFT central force (the cheat),
	# removed as each is migrated to honest.
	if _is_honest():
		return force_equiv
	var contact := _stance_contact_factor()
	if contact <= 0.0:
		return force_equiv
	var height_error := maxf(_target_root_y - _root_body.global_position.y, 0.0)
	var accel := CE.GRAVITY * 0.65 * _params.posture_scale * contact \
			+ 18.0 * _params.posture_scale * height_error \
			- 3.5 * _params.posture_scale * _root_body.linear_velocity.y
	var max_lift_accel := CE.GRAVITY * maxf(2.0, 0.9 + _params.posture_scale)
	accel = clampf(accel, 0.0, max_lift_accel)
	var lift_force := _total_mass * accel
	_root_body.apply_central_force(Vector3.UP * lift_force)
	return force_equiv + lift_force


func _stance_contact_factor() -> float:
	var best := 0.0
	for d in _drives:
		if not bool(d.get("traction_enabled", false)):
			continue
		var contacts: Array = d.get("contacts", [])
		for c in contacts:
			var foot := c.get("body") as RigidBody3D
			if foot == null:
				continue
			var foot_bottom := foot.global_position.y - float(c.get("half_height", 0.0))
			best = maxf(best, clampf((0.10 - foot_bottom) / 0.12, 0.0, 1.0))
	return best


# M37: per-tick stance slip. For every distinct grounded foot, add its horizontal
# speed*dt to the running mean. A planted (pivoting) foot contributes ~0; a skater's
# foot rides forward with the body. Deduped by instance id so a foot shared across
# several drive subtrees is only counted once per tick.
func _accumulate_foot_slip(delta: float) -> void:
	var sum_speed := 0.0
	var n := 0
	var seen := {}
	for d in _drives:
		for c in d.get("contacts", []):
			var foot := c.get("body") as RigidBody3D
			if foot == null or seen.has(foot.get_instance_id()):
				continue
			var foot_bottom := foot.global_position.y - float(c.get("half_height", 0.0))
			if clampf((0.10 - foot_bottom) / 0.12, 0.0, 1.0) <= 0.0:
				continue
			seen[foot.get_instance_id()] = true
			var v := foot.linear_velocity
			v.y = 0.0
			sum_speed += v.length()
			n += 1
	if n > 0:
		_foot_slip += (sum_speed / float(n)) * delta
		_foot_slip_samples += 1
