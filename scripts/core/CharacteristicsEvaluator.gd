class_name CharacteristicsEvaluator
extends RefCounted

const JointModelScript := preload("res://scripts/sim/joint_model.gd")

## Characteristics Evaluation Engine — design pass v6.
##
## A pure-analytic morphology evaluator plus a deterministic locomotion probe.
## Everything analytic is a closed-form function of the resolved part graph; the
## probe is a self-contained, deterministic gait surrogate (no live physics step,
## so it is SAME-BINARY reproducible (transcendental math is not bit-identical across
## platforms — do not treat the locomotion verdict as cross-machine authoritative for
## ranked play). The probe is ground truth for locomotion;
## the analytic stages are authoritative for mass, CoG, debt, traits, intelligence
## and strength. Disagreement between the two is reported, never hidden.
##
## Provenance of each subsystem is noted at its section header. Every field read
## downstream is declared on ResolvedPart; no function is left as a stub.


# =============================================================================
# Authored contract (sacred; never mutated)
# =============================================================================

# PartDefinition / SocketDef / PartGene were promoted to standalone global Resources
# in Tier 1 (scripts/core/part_definition.gd, socket_def.gd, part_gene.gd) so the genome
# can be authored, saved as .tres, and shared. The bare names used throughout this file
# resolve to those globals — identical fields, so no body changes were needed.

# Derived (engine-owned). Every field read downstream is declared here.
class ResolvedPart:
	var index: int
	var parent: int                      # -1 for root
	var depth: int
	var definition: PartDefinition       # held so shape/probe code can read part_type
	var scale: Vector3                   # accumulated per-axis scale
	var tags: Dictionary                 # StringName -> true (insertion-ordered)
	var xform: Transform3D
	var com_local: Vector3               # centroid_offset * scale (probe custom CoM)
	var com_world: Vector3               # xform * com_local (exact)
	var dims: Vector3                    # full scaled extents (2 * extents * scale)
	var mass: float                      # density * volume, floored to MIN_MASS only
	var volume: float
	var metabolic_volume: float          # volume that counts as metabolic demand (Lane B / Tier D)
	var surface_area: float              # per-part SA (internal faces subtracted in place)
	var radius: float                    # bounding-sphere radius
	var bone_cost: int                   # 1, or 2 if graft
	var socket: SocketDef                # persisted: probe needs no gene back-ref
	var hinge_axis: Vector3              # persisted from socket; ZERO = rigid
	var joint: JointDef                  # Fork B3: per-joint actuation envelope (null = engine default)
	var spring: SpringDef                # M34: per-part elastic anatomy (null = no spring behavior)
	var weapon: WeaponDef                # M35: per-part combat anatomy (null = unarmed contact)
	var tendon: TendonDef                # M47: biarticular coupling to a partner joint (null = none)
	var part_id: StringName              # M45: stable id, for authored-mesh / collider lookup
	var world_aabb: AABB                 # 8-corner world box (_world_box)
	var has_descriptor: bool = false     # F2: Lane B active -> surface_area is descriptor-sourced (gates haircut mode)
	var muscle_amount: float = 1.0       # authoring dial; multiplies local muscle mass contribution


class WeakPoint:
	var part_index: int
	var location: Vector3
	var severity: float                  # [0,1], overextension-primary
	var kind: StringName                 # &"starved" | &"no_heart" | &"no_brain" | &"no_lung" | &"graft"
	var radius: float
	var cause: String


# =============================================================================
# Constants (single source of truth)
# =============================================================================

const MIN_SIZE := 1.0e-3                 # smallest meaningful length; anti-div0 only
const MIN_MASS := 1.0e-3                 # authored-mass floor; anti-div0 only
const EPS := 1.0e-6
const UNREACHABLE := 1.0e9               # finite "not reached" sentinel for Dijkstra

const GROUND_BAND := 0.15                # fraction of body_radius: contact-height tolerance

# debt
const HEART_REACH_K := 3.0               # TUNING-2 (Cole): was 1.6 — a heart ~33% of body linear
										 # size now perfuses ~1 body-radius (playtest knob, pinned by tests)
const MAX_HEART_REACH := 3.0
const HEART_CAP_K := 8.0                 # TUNING-1 (Cole): a heart supplies ~8x its own volume of
										 # tissue; restores supply≈demand at a sane (~5-10%) heart fraction
const GRAFT_REACH_BONUS := 0.5           # body-radii of reach per cumulative graft hop
const MAX_GRAFT_REACH := 4.0
const LUNG_OXY_K := 0.5                  # fractional supply boost per unit lung-vol fraction
const SAV_HEALTHY := 3.0                 # dimensionless SA:V*R of a sphere ≈ 3
const SAV_SPAN := 6.0
const W_METAB := 0.4
const W_SAV := 0.25
const W_PERF := 0.35
const SEV_FLOOR_FRAC := 0.7              # severity floor at 2× reach, mass-independent (finding #6)
const GRAFT_BASE_SEV := 0.4

# scores
const TIP_REF := 0.6                     # radians; stability-headroom reference
const COG_REF := 1.5                     # CoG height (body-radii) where the speed penalty saturates
const TIP_WARN_ANGLE := 0.30             # rad (~17°): a stable build with less tilt-headroom than this
										 # is truthfully stable but top-heavy — warn the player it's tippy

# probe (deterministic gait surrogate)
const GRAVITY := 9.81
const F_BASE := 0.30                     # dimensionless Froude gait-frequency base
const KP_BASE := 20.0                    # 1/s² — PD stiffness per unit subtree inertia
const KD_BASE := 4.0                     # 1/s  — PD damping per unit subtree inertia
const CPG_AMPLITUDE := 0.6               # radians
const PROBE_FREQ := 60.0                 # Hz fixed step
const PROBE_SETTLE_S := 0.5
const PROBE_DRIVE_S := 10.0
const PROBE_PASS_DIST := 2.0             # × body_radius (scale-relative gate, not literal metres)
const PROBE_MAX_SEPARATION := 0.05       # reported joint-separation proxy
const JOLT_MASS_RATIO := 100.0           # probe-only stabilisation clamp (reported)
const GOLDEN := 2.399963229728653        # golden angle (rad) — CPG phase spread, no RNG
const PHASE_PROBES: Array[float] = [0.0, 0.61803, 1.23607]   # always-distinct golden phase offsets (fix #1)

# Fork E3 - muscle-derived joint strength (playtest knobs; NO goldens yet, pinned later like HEART_*).
# Always finite: even zero-muscle creatures have connective/passive drive limits, and local muscle
# monotonically raises a joint's cap instead of switching the whole creature from INF to capped.
const MUSCLE_BASELINE_CAP := 120.0   # torque-per-inertia default for passive/connective tissue
const MUSCLE_TORQUE_K := 240.0       # torque-per-inertia gained per unit subtree muscle-mass fraction
const MUSCLE_METAB_K := 0.5          # M9B: metabolic demand surcharge per unit whole-body muscle-mass fraction
									 # (scale-invariant ratio; non-muscle bodies add nothing -> Tier-D pin safe)


# =============================================================================
# Public entry point
# =============================================================================

static func evaluate(root: PartGene, root_xform: Transform3D = Transform3D.IDENTITY,
		seed: int = 0, bone_budget: int = 64) -> Dictionary:
	var fold := fold_graph(root, root_xform)
	var gait: GaitDef = (root.gait if root != null else null)   # Fork C2: creature-level gait -> probe
	var parts: Array = fold["parts"]
	var warnings: Array = fold["warnings"]

	var pre := precheck(fold)
	if not pre["ok"]:
		return _sentinel(pre["reason"], warnings, bone_budget)

	# Internal-face SA subtraction (line 25098 §4.5) — done before SA:V is read.
	adjust_internal_faces(parts)

	var total_volume := 0.0
	var total_mass := 0.0
	var total_sa := 0.0
	var bone_cost_total := 0
	for p in parts:
		total_volume += p.volume
		total_mass += p.mass
		total_sa += p.surface_area
		bone_cost_total += p.bone_cost

	# BITE NOTE B-BR (inert still shapes the body): total_volume sums EVERY part's volume,
	# including authored inert parts (and even with the optional Tier D metabolic-demand split,
	# inert volume stays here). body_radius is the SOLE spatial normaliser for SA:V, balance
	# margin, perfusion reach and the probe's pass distance — so "inert = zero metabolic demand"
	# is true for the DEMAND term only; an inert spike still enlarges the body everything else is
	# normalised against. Defensible (the spike is physically there) — just don't chase a "why did
	# adding an inert spike change my reach" ghost: this line is the answer.
	var body_radius := maxf(pow(total_volume, 1.0 / 3.0), MIN_SIZE)   # sole spatial normaliser

	var cogd := compute_cog(parts)
	var cog: Vector3 = cogd["cog"]
	var balance := compute_balance(parts, cog, body_radius)
	var stand := compute_stand_feasibility(parts, cog, body_radius, total_mass)
	var mp := compute_movement_and_power(parts, cog, body_radius, balance)
	var debt := compute_debt(parts, body_radius, total_mass, total_volume, total_sa)
	var alive := bool(debt.get("alive", true))
	if not alive:
		mp = _dead_movement(debt)
	var ti := compute_traits_intelligence(parts, total_volume, debt, mp, balance)

	var over_budget := bone_cost_total > bone_budget
	var probe: Dictionary
	if not alive:
		probe = {"passed": false, "verdict": &"dead", "distance": 0.0,
				"max_separation": 0.0, "mode": &"skipped", "ticks": 0}
	elif over_budget:
		probe = {"passed": false, "verdict": &"skipped", "distance": 0.0,
				"max_separation": 0.0, "mode": &"skipped", "ticks": 0}
	else:
		probe = run_probe(parts, cog, body_radius, total_mass, balance, seed, gait)

	var rec := reconcile(balance, probe)

	return {
		"cog": cog,
		"total_mass": total_mass,
		"total_volume": total_volume,
		"total_sa_exposed": total_sa,
		"body_radius": body_radius,
		"balance": balance,
		"stand": stand,
		"speed": {"value": mp["speed"], "drivers": mp["speed_drivers"]},
		"agility": {"value": mp["agility"], "drivers": mp["agility_drivers"]},
		"strength": {"value": mp["strength"], "drivers": mp["strength_drivers"]},
		"intelligence": {"value": ti["intelligence"], "drivers": {}},
		"debt": debt,
		"weak_points": debt["weak_points"],
		"traits": ti["traits"],
		"probe": probe,
		"reconciliation": rec,
		"status": {
			"ok": true,
			"alive": alive,
			"fatal_reasons": debt.get("fatal_reasons", []),
			"over_budget": over_budget,
			"bone_cost_total": bone_cost_total,
			"bone_budget": bone_budget,
			"reason": ("over bone budget" if over_budget else ""),
		},
		"warnings": warnings,
	}


static func _dead_movement(debt: Dictionary) -> Dictionary:
	var reasons: Array = debt.get("fatal_reasons", [])
	var why := "dead"
	if not reasons.is_empty():
		why = "dead: %s" % ", ".join(reasons)
	return {
		"speed": 0.0,
		"speed_drivers": {"fatal": why},
		"agility": 0.0,
		"agility_drivers": {"fatal": why},
		"strength": 0.0,
		"strength_drivers": {"fatal": why},
	}


static func _sentinel(reason: String, warnings: Array, bone_budget: int) -> Dictionary:
	return {
		"cog": Vector3.ZERO,
		"total_mass": MIN_MASS,
		"total_volume": 0.0,
		"total_sa_exposed": 0.0,
		"body_radius": MIN_SIZE,
		"balance": _no_support(reason),
		"speed": {"value": 0.0, "drivers": {}},
		"agility": {"value": 0.0, "drivers": {}},
		"strength": {"value": 0.0, "drivers": {}},
		"intelligence": {"value": 0.0, "drivers": {}},
		"debt": {
			"debt_total": 1.0, "metabolic_debt": 1.0, "sav_debt": 1.0, "perfusion_debt": 1.0,
			"supply": 0.0, "demand": 0.0, "heart_count": 0, "brain_count": 0, "lung_count": 0,
			"alive": false, "fatal_reasons": [reason], "aggregate_capacity": 0.0,
			"weak_points": [], "drivers": [reason],
		},
		"weak_points": [],
		"traits": [],
		"probe": {"passed": false, "verdict": &"skipped", "distance": 0.0,
				"max_separation": 0.0, "mode": &"skipped", "ticks": 0},
		"reconciliation": {"stability_class": &"unstable", "locomotion_stable": false,
				"message": "Degenerate creature: %s" % reason},
		"status": {"ok": false, "alive": false, "fatal_reasons": [reason],
				"over_budget": false, "bone_cost_total": 0,
				"bone_budget": bone_budget, "reason": reason},
		"warnings": warnings,
	}


# =============================================================================
# 1. Assembly — cycle guard, accumulated scale, persisted fields
#    (v6 clean fold + 8-corner _world_box)
# =============================================================================

static func fold_graph(root: PartGene, root_xform: Transform3D) -> Dictionary:
	var parts: Array = []
	var warnings: Array = []
	var visited := {}
	var cyclic := [false]
	if root != null:
		_fold(root, root_xform, Vector3.ONE, -1, 0, parts, visited, warnings, cyclic)
	else:
		warnings.append("null root gene")
	return {"parts": parts, "warnings": warnings, "cycle_detected": cyclic[0]}


static func _fold(gene: PartGene, parent_xform: Transform3D, parent_scale: Vector3,
		parent_idx: int, depth: int, out: Array, visited: Dictionary,
		warnings: Array, cyclic: Array) -> void:
	if gene == null:
		return
	if visited.has(gene):
		cyclic[0] = true
		warnings.append("cycle or reused node skipped at depth %d" % depth)
		return
	visited[gene] = true

	var xform := parent_xform
	if gene.socket != null:
		xform = CreatureFrames.child_world(xform, gene.socket)

	var scale := CreatureFrames.accumulated_scale(parent_scale, gene.scale)

	var defn: PartDefinition = gene.definition
	var p := ResolvedPart.new()
	p.index = out.size()
	p.parent = parent_idx
	p.depth = depth
	p.definition = defn
	p.scale = scale
	p.socket = gene.socket
	p.hinge_axis = (gene.socket.hinge_axis if gene.socket != null else Vector3.ZERO)
	p.joint = gene.joint                                # Fork B3: per-joint actuation envelope (null = default)
	p.spring = gene.spring                              # M34: resolved spring anatomy for runtime/measured metrics
	p.weapon = gene.weapon                              # M35: resolved weapon anatomy for combat contact
	p.tendon = gene.tendon                              # M47: resolved biarticular tendon coupling
	p.part_id = gene.part_id                            # M45: for authored-mesh / collider lookup
	p.tags = {}
	for t in gene.tags:
		p.tags[t] = true
	p.muscle_amount = maxf(float(gene.dial_values.get(&"muscle_amount", 1.0)), 0.0)
	p.xform = xform
	p.com_local = CreatureFrames.com_local(defn, scale) # exact CoM offset (finding #8)
	p.com_world = xform * p.com_local
	p.dims = CreatureFrames.dims_for(defn, scale)
	p.volume = maxf(_shape_volume(defn.part_type, p.dims), EPS)
	p.surface_area = maxf(_shape_surface(defn.part_type, p.dims), EPS)
	p.radius = maxf(0.5 * p.dims.length(), MIN_SIZE)
	p.mass = maxf(defn.density * p.volume, MIN_MASS)    # SACRED: floor only
	p.metabolic_volume = p.volume                       # all-metabolic default

	# --- Authored "Lane B": measured physics overrides analytic geometry. ---
	# `definition` still supplies part_type/extents for footprint/world-box/inertia/mesh; the
	# descriptor supplies the integrated mass/volume/SA/CoG the stats actually read. No tuned
	# constant changes — only which numbers populate this ResolvedPart.
	#
	# BITE NOTE B-IF (internal-face haircut) — RESOLVED by F2: adjust_internal_faces() removes a
	# buried-face estimate. For authored parts the skeleton shared-face MAGNITUDE is no longer
	# subtracted from descriptor SA; instead a dimensionless coverage fraction (a skeleton/skeleton
	# ratio that leaks no magnitude) of the canonical descriptor SA is removed. Descriptor SA is now
	# authoritative for magnitude; placement geometry only decides what FRACTION is buried. Inert
	# parts (SA≈0) are unaffected either way. See _apply_internal_face_haircut.
	if gene.descriptor != null:
		var d := gene.descriptor
		p.has_descriptor = true                                       # F2: SA below is descriptor-sourced
		var vscale := absf(scale.x * scale.y * scale.z)               # volume scales by |det|
		var sscale := pow(maxf(vscale, EPS), 2.0 / 3.0)              # isotropic SA approximation
		var max_axis := maxf(absf(scale.x), maxf(absf(scale.y), absf(scale.z)))
		p.volume           = maxf(d.total_volume * vscale, EPS)
		p.metabolic_volume = maxf(d.metabolic_volume * vscale, 0.0)  # inert ⇒ 0 demand (read by Tier D)
		p.surface_area     = maxf(d.surface_metabolic * sscale, 0.0) # inert ⇒ 0 ⇒ no hungry-skin SA
		p.mass             = maxf(d.mass * vscale, MIN_MASS)
		p.com_local        = d.center_of_mass * scale
		p.com_world        = xform * p.com_local
		if d.bounding_radius > 0.0:
			p.radius = maxf(d.bounding_radius * max_axis, MIN_SIZE)

	p.world_aabb = _world_box(xform, defn.extents, scale)
	p.bone_cost = 2 if p.tags.has(&"graft") else 1
	out.append(p)

	for child in gene.children:
		_fold(child, xform, scale, p.index, depth + 1, out, visited, warnings, cyclic)


# =============================================================================
# 2. Degenerate-path guards (explicit enumeration — finding #3)
# =============================================================================

static func precheck(fold: Dictionary) -> Dictionary:
	var parts: Array = fold["parts"]
	if parts.is_empty():
		return {"ok": false, "reason": "empty creature"}
	var total_v := 0.0
	var total_m := 0.0
	for p in parts:
		if not (is_finite(p.com_world.x) and is_finite(p.com_world.y) and is_finite(p.com_world.z)):
			return {"ok": false, "reason": "non-finite part transform at index %d" % p.index}
		if not is_finite(p.mass) or p.mass <= 0.0:
			return {"ok": false, "reason": "non-positive mass at index %d" % p.index}
		if not is_finite(p.volume) or p.volume <= 0.0:
			return {"ok": false, "reason": "non-positive volume at index %d" % p.index}
		if p.index != 0 and (p.parent < 0 or p.parent >= parts.size()):
			return {"ok": false, "reason": "disconnected part at index %d" % p.index}
		total_v += p.volume
		total_m += p.mass
	if total_v <= EPS or total_m <= MIN_MASS:
		return {"ok": false, "reason": "degenerate total volume/mass"}
	return {"ok": true, "reason": "", "total_volume": total_v, "total_mass": total_m}


# =============================================================================
# 3. Shape utilities (v6 §4; sphere SA = Knud-Thomsen one-liner)
# =============================================================================

# Public aliases (BITE NOTE B1): descriptor generators delegate to the evaluator's OWN
# geometry math so a primitive's descriptor equals the analytic numbers by identity, never a
# second copy of the shape formulas. Thin wrappers — the private routines below are unchanged.
static func shape_volume(part_type: StringName, dims: Vector3) -> float:
	return _shape_volume(part_type, dims)


static func shape_surface(part_type: StringName, dims: Vector3) -> float:
	return _shape_surface(part_type, dims)


static func _shape_volume(part_type: StringName, dims: Vector3) -> float:
	var hx := dims.x * 0.5
	var hy := dims.y * 0.5
	var hz := dims.z * 0.5
	match part_type:
		&"box":
			return dims.x * dims.y * dims.z
		&"sphere":
			return (4.0 / 3.0) * PI * hx * hy * hz
		&"cylinder":
			var rc := (dims.x + dims.z) * 0.25
			return PI * rc * rc * dims.y
		&"capsule":
			var rc := (dims.x + dims.z) * 0.25
			var h := maxf(dims.y - 2.0 * rc, 0.0)
			return PI * rc * rc * h + (4.0 / 3.0) * PI * rc * rc * rc
	return dims.x * dims.y * dims.z


static func _shape_surface(part_type: StringName, dims: Vector3) -> float:
	var hx := dims.x * 0.5
	var hy := dims.y * 0.5
	var hz := dims.z * 0.5
	match part_type:
		&"box":
			return 2.0 * (dims.x * dims.y + dims.x * dims.z + dims.y * dims.z)
		&"sphere":
			return 4.0 * PI * pow((pow(hx * hy, 1.6075) + pow(hx * hz, 1.6075) + pow(hy * hz, 1.6075)) / 3.0, 1.0 / 1.6075)
		&"cylinder":
			var rc := (dims.x + dims.z) * 0.25
			return 2.0 * PI * rc * (rc + dims.y)
		&"capsule":
			var rc := (dims.x + dims.z) * 0.25
			var h := maxf(dims.y - 2.0 * rc, 0.0)
			return 2.0 * PI * rc * (h + 2.0 * rc)
	return 2.0 * (dims.x * dims.y + dims.x * dims.z + dims.y * dims.z)


static func _shape_inertia(part_type: StringName, dims: Vector3, mass: float) -> Vector3:
	return JointModelScript.shape_inertia(part_type, dims, mass)


static func _shape_inertia_legacy(part_type: StringName, dims: Vector3, mass: float) -> Vector3:
	# Diagonal of the inertia tensor in the local frame (Ixx, Iyy, Izz).
	match part_type:
		&"box":
			var wx := dims.x
			var wy := dims.y
			var wz := dims.z
			return Vector3(
				mass / 12.0 * (wy * wy + wz * wz),
				mass / 12.0 * (wx * wx + wz * wz),
				mass / 12.0 * (wx * wx + wy * wy))
		&"sphere":
			var a := dims.x * 0.5
			var b := dims.y * 0.5
			var c := dims.z * 0.5
			return Vector3(
				mass / 5.0 * (b * b + c * c),
				mass / 5.0 * (a * a + c * c),
				mass / 5.0 * (a * a + b * b))
		&"cylinder", &"capsule":
			var rr := (dims.x + dims.z) * 0.25
			var hh := dims.y
			return Vector3(
				mass / 12.0 * (3.0 * rr * rr + hh * hh),
				mass / 2.0 * rr * rr,
				mass / 12.0 * (3.0 * rr * rr + hh * hh))
	return Vector3.ONE * mass


static func _world_box(xform: Transform3D, half_extents: Vector3, scale: Vector3) -> AABB:
	# Transform all 8 corners so a rotated part yields a correct world box (v6).
	var half := half_extents * scale
	var corners := [
		xform * Vector3(-half.x, -half.y, -half.z),
		xform * Vector3( half.x, -half.y, -half.z),
		xform * Vector3(-half.x,  half.y, -half.z),
		xform * Vector3( half.x,  half.y, -half.z),
		xform * Vector3(-half.x, -half.y,  half.z),
		xform * Vector3( half.x, -half.y,  half.z),
		xform * Vector3(-half.x,  half.y,  half.z),
		xform * Vector3( half.x,  half.y,  half.z),
	]
	var aabb := AABB(corners[0], Vector3.ZERO)
	for i in range(1, 8):
		aabb = aabb.expand(corners[i])
	return aabb


# =============================================================================
# 4. CoG — exact, mass-weighted (per-part com_world)
# =============================================================================

static func compute_cog(parts: Array) -> Dictionary:
	var m := 0.0
	var w := Vector3.ZERO
	for p in parts:
		m += p.mass
		w += p.com_world * p.mass
	m = maxf(m, MIN_MASS)
	var cog := w / m
	var ok := is_finite(cog.x) and is_finite(cog.y) and is_finite(cog.z)
	return {"cog": (cog if ok else Vector3.ZERO), "mass": m, "ok": ok}


# =============================================================================
# 5. Balance — support polygon from real footprints
#    (round-1 hull / robust point-in-poly / margin helpers,
#     fed by a clean bottom-face footprint sampler — no -e.y typo)
# =============================================================================

# Real transformed footprint points (NOT axis-aligned AABB corners). Rotated parts
# produce a correctly rotated footprint. Box -> 4 oriented bottom corners;
# cylinder -> 8 rim samples; capsule -> bottom contact line; sphere -> contact point.
static func _footprint_samples(p) -> Array:
	var e: Vector3 = p.dims * 0.5
	match p.definition.part_type:
		&"box":
			return [
				p.xform * Vector3(-e.x, -e.y, -e.z),
				p.xform * Vector3( e.x, -e.y, -e.z),
				p.xform * Vector3(-e.x, -e.y,  e.z),
				p.xform * Vector3( e.x, -e.y,  e.z),
			]
		&"cylinder":
			var out: Array = []
			for i in 8:
				var a := i * PI / 4.0
				out.append(p.xform * Vector3(cos(a) * e.x, -e.y, sin(a) * e.z))
			return out
		&"capsule":
			return [
				p.xform * Vector3(0.0, -e.y, -e.z),
				p.xform * Vector3(0.0, -e.y,  e.z),
				p.xform * Vector3(0.0, -e.y,  0.0),
			]
		&"sphere":
			return [p.xform * Vector3(0.0, -e.y, 0.0)]
	return []


static func compute_balance(parts: Array, cog: Vector3, body_radius: float) -> Dictionary:
	var br := maxf(body_radius, MIN_SIZE)

	# Collect real footprint points from ground_contact parts.
	var contacts: Array = []
	var lowest := INF
	for p in parts:
		if not p.tags.has(&"ground_contact"):
			continue
		for pt in _footprint_samples(p):
			lowest = minf(lowest, pt.y)
			contacts.append(pt)
	if contacts.is_empty():
		return _no_support("no ground_contact parts")

	# Ground-band filter: only contacts within GROUND_BAND·R of the lowest bear load.
	var band := lowest + GROUND_BAND * br
	var pts: Array[Vector2] = []
	var excluded := 0
	for c in contacts:
		if c.y > band:
			excluded += 1
			continue
		pts.append(Vector2(c.x, c.z))
	if pts.is_empty():
		return _no_support("all contact points elevated above ground band")

	var hull := _convex_hull_2d(pts)
	var area_ratio := _polygon_area_2d(hull) / (br * br)

	var cog_proj := Vector2(cog.x, cog.z)
	var centroid := _polygon_centroid_2d(hull)
	var inside := _is_point_in_convex_polygon(cog_proj, hull)
	var min_dist := _min_distance_to_polygon_edges(cog_proj, hull)
	if not is_finite(min_dist):
		min_dist = 0.0

	var margin := (min_dist / br) if inside else (-min_dist / br)
	var cog_height := maxf(cog.y - lowest, MIN_SIZE)
	var tip_angle := (atan2(min_dist, cog_height) if inside else 0.0)
	var stable := inside and min_dist > EPS and hull.size() >= 3
	var fore_aft := (cog_proj.y - centroid.y) / br             # +z = front-loaded
	var left_right := (cog_proj.x - centroid.x) / br
	# Truthfully stable but top-heavy: large horizontal margin, little tilt headroom.
	var tip_risk := stable and tip_angle < TIP_WARN_ANGLE

	# Human-readable explainability (Foundry mandate, fix #5).
	var drivers: Array[String] = []
	if not inside:
		drivers.append("CoG is outside the support polygon — it tips")
	elif margin < 0.15:
		drivers.append("narrow stance: only %.2f body-radii of margin" % margin)
	else:
		drivers.append("stable stance: %.2f body-radii of margin" % margin)
	if tip_risk:
		drivers.append("top-heavy: likely to tip over (only %.0f deg of tilt headroom)" % rad_to_deg(tip_angle))
	if absf(fore_aft) > 0.25:
		drivers.append("CoG %s of centre (fore-aft %.2f R)" % ["forward" if fore_aft > 0.0 else "behind", fore_aft])
	if absf(left_right) > 0.25:
		drivers.append("CoG %s of centre (left-right %.2f R)" % ["right" if left_right > 0.0 else "left", left_right])
	if excluded > 0:
		drivers.append("%d contact(s) excluded — above ground band" % excluded)

	return {
		"stable": stable,
		"balance_margin": margin,
		"tip_angle": tip_angle,
		"support_area": area_ratio,
		"cog_offset_fore_aft": fore_aft,
		"cog_offset_left_right": left_right,
		"support_centroid": centroid,
		"n_support": hull.size(),
		"excluded_contacts": excluded,
		"tip_risk": tip_risk,
		"drivers": drivers,
		"reason": "",
	}


# =============================================================================
# 5b. Stand feasibility — the static joint-torque gate (2026-07-03)
# =============================================================================
# compute_balance above answers "is the CoM over the feet" (pure geometry).
# This answers the other half of standing: can the leg MUSCLES hold the body
# there? A stance joint fights the moment of the ground-reaction force at its
# foot — the body's weight share × the horizontal lever from joint to foot —
# NOT the weight of its own distal segments. That distal load is the SWING
# gravity-comp quantity, and it is smallest exactly where the stance load is
# biggest (the knee: tiny shin+foot subtree, whole-body share). The 92 kg quad
# collapsed on exactly this: an ~89 N·m inertia-limited knee cap under a
# body-share moment it could never hold. This gate rejects that build at
# assembly time instead of discovering it in a rollout.
#
# Foot loads are NOT split equally: we solve the minimum-norm vertical force
# distribution (force balance + both horizontal moment balances — exact for 3
# contacts, least-squares for 4+; the stiff-body-on-springs answer), so a
# rear-heavy body correctly loads its hind legs harder. A foot whose solution
# goes negative (it would have to PULL) unloads and the solve repeats.
#
# Besides the all-feet stand, every leave-one-out support set is checked and
# reported as gait_* — the mid-step answer to "can it stand": a crawl lifts one
# foot at a time, and on a square stance the lifted foot's diagonal partner
# picks up roughly DOUBLE its standing share. Contacts are footprint centroids
# (point contacts): a 2-contact support cannot balance both moment axes
# statically, so bipeds/monopods report needs_weight_shift rather than a fake
# margin — they need ankle-torque area or dynamic balance, which this static
# screen deliberately does not model.
#
# Feasibility is judged like an engineer sizes a beam: against the WORST
# expected load case (the mid-step leave-one-out, not the easy all-feet stand)
# and with STAND_SAFETY reserve on top — a joint at 95% of its cap standing
# still has nothing left for the dynamic transients of an actual step. Each
# margin row also reports the subtree muscle fraction that WOULD cover its
# design load (muscle_frac_needed) and whether that is reachable under the
# muscle-authoring ceiling — the "calibrate the pieces to the load" data the
# assembler needs to size muscles instead of guessing.

const STAND_GRAVITY := 9.8
# Engineering reserve: capacity must exceed the design load by 20%.
const STAND_SAFETY := 1.2
# subtree_muscle_frac clamps at 4.0 (joint_model.gd) — past this, more muscle
# authoring is a NO-OP and only geometry/mass changes can raise the cap.
const STAND_MUSCLE_FRAC_MAX := 4.0


static func compute_stand_feasibility(parts: Array, cog: Vector3, body_radius: float,
		total_mass: float) -> Dictionary:
	var br := maxf(body_radius, MIN_SIZE)
	var weight := maxf(total_mass, MIN_SIZE) * STAND_GRAVITY

	# Bearing feet: ground_contact parts within the ground band (same filter as
	# compute_balance), each reduced to its footprint centroid.
	var lowest := INF
	for p in parts:
		if not p.tags.has(&"ground_contact"):
			continue
		for pt in _footprint_samples(p):
			lowest = minf(lowest, pt.y)
	var feet: Array = []
	for p in parts:
		if not p.tags.has(&"ground_contact"):
			continue
		var samples := _footprint_samples(p)
		if samples.is_empty():
			continue
		var lo := INF
		var centroid := Vector3.ZERO
		for pt in samples:
			lo = minf(lo, pt.y)
			centroid += pt
		if lo > lowest + GROUND_BAND * br:
			continue                              # elevated contact: bears no load
		feet.append({"part": p, "contact": centroid / float(samples.size())})
	if feet.is_empty():
		return _no_stand("no bearing ground_contact parts")

	# Per-foot joint chains (foot → root), hinged locomotor joints only. Anchor
	# and world axis follow the live rig's conventions exactly
	# (creature_body._joint_axis_world / cpg_controller._build_leg_plan), so the
	# gate measures the same joints the controller will drive.
	var chains: Array = []
	for f in feet:
		var chain: Array = []
		var idx: int = int(f["part"].index)
		while idx >= 0:
			var jp = parts[idx]
			var pidx := int(jp.parent)
			if pidx >= 0 and jp.socket != null and jp.hinge_axis.length() >= EPS \
					and jp.tags.has(&"locomotor"):
				var anchor: Vector3 = jp.xform * (-jp.socket.child_anchor.origin)
				var axis_w: Vector3 = ((parts[pidx].xform * jp.socket.parent_attachment).basis
						* jp.hinge_axis.normalized()).normalized()
				var i_sub := _subtree_inertia(parts, idx, total_mass, br)
				var cap := cpg_torque_cap(false, _subtree_muscle_frac(parts, idx), i_sub)
				chain.append({"part": jp, "anchor": anchor, "axis": axis_w, "cap": cap,
						"inertia": i_sub, "subtree": _stand_subtree(parts, idx)})
			idx = pidx
		chains.append(chain)

	# Scenarios: the all-feet stand, then each leave-one-out (the crawl mid-step).
	var all_r := _stand_scenario(parts, feet, chains, -1, cog, weight)
	var gait_worst := all_r
	var gait_lifted: StringName = &""
	var gait_shift := bool(all_r["needs_weight_shift"])
	if feet.size() > 1:
		gait_worst = {}
		gait_shift = false
		for k in feet.size():
			var r := _stand_scenario(parts, feet, chains, k, cog, weight)
			gait_shift = gait_shift or bool(r["needs_weight_shift"])
			if gait_worst.is_empty() \
					or float(r["worst_margin"]) > float(gait_worst["worst_margin"]):
				gait_worst = r
				gait_lifted = _stand_label(feet[k]["part"])

	return {
		"stand_feasible": float(all_r["worst_margin"]) * STAND_SAFETY < 1.0
				and not bool(all_r["needs_weight_shift"]),
		"worst_margin": all_r["worst_margin"],
		"worst_joint": all_r["worst_joint"],
		"margins": all_r["margins"],
		"foot_loads": all_r["loads"],
		"needs_weight_shift": all_r["needs_weight_shift"],
		"gait_feasible": float(gait_worst["worst_margin"]) * STAND_SAFETY < 1.0,
		"gait_worst_margin": gait_worst["worst_margin"],
		"gait_worst_joint": gait_worst["worst_joint"],
		"gait_worst_lifted": gait_lifted,
		"gait_worst_loads": gait_worst["loads"],
		"gait_worst_margins": gait_worst["margins"],
		"gait_needs_weight_shift": gait_shift,
		"n_feet": feet.size(),
		"safety": STAND_SAFETY,
		"reason": "",
	}


static func _no_stand(reason: String) -> Dictionary:
	return {"stand_feasible": false, "worst_margin": INF, "worst_joint": &"",
			"margins": [], "foot_loads": [], "needs_weight_shift": false,
			"gait_feasible": false, "gait_worst_margin": INF, "gait_worst_joint": &"",
			"gait_worst_lifted": &"", "gait_worst_loads": [], "gait_worst_margins": [],
			"gait_needs_weight_shift": false, "n_feet": 0,
			"safety": STAND_SAFETY, "reason": reason}


static func _stand_label(p) -> StringName:
	if p.socket != null and String(p.socket.id) != "":
		return p.socket.id
	return StringName("part_%d" % int(p.index))


# Distal subtree part indices (the segments hanging below a joint) — their
# weight moments partially offset the GRF moment at that joint.
static func _stand_subtree(parts: Array, root_idx: int) -> Array:
	var out: Array = []
	var stack := [root_idx]
	var seen := {}
	while not stack.is_empty():
		var u: int = stack.pop_back()
		if seen.has(u) or u < 0 or u >= parts.size():
			continue
		seen[u] = true
		out.append(u)
		for c in parts:
			if int(c.parent) == u and not seen.has(int(c.index)):
				stack.append(int(c.index))
	return out


# Minimum-norm vertical force distribution over contact points (XZ plane):
# F_i = a + b·x_i + c·z_i subject to ΣF = W, ΣF·x = W·cx, ΣF·z = W·cz.
# Exact for 3 non-collinear contacts; least-squares for 4+. Empty return =
# singular (fewer than 3 effective contacts): statics alone cannot hold both
# moment axes on point contacts.
static func _stand_force_distribution(pts: Array, w: float, cx: float, cz: float) -> Array:
	var n := pts.size()
	if n < 1:
		return []
	var s1 := float(n)
	var sx := 0.0
	var sz := 0.0
	var sxx := 0.0
	var sxz := 0.0
	var szz := 0.0
	for q in pts:
		sx += q.x
		sz += q.y
		sxx += q.x * q.x
		sxz += q.x * q.y
		szz += q.y * q.y
	var m := Basis(Vector3(s1, sx, sz), Vector3(sx, sxx, sxz), Vector3(sz, sxz, szz))
	if absf(m.determinant()) < 1.0e-9:
		return []
	var lam := m.inverse() * Vector3(w, w * cx, w * cz)
	var out: Array = []
	for q in pts:
		out.append(lam.x + lam.y * q.x + lam.z * q.y)
	return out


# One support scenario: `lifted` (index into feet, -1 = none) is airborne.
# Solves the foot-load distribution, then the torque margin at every hinged
# joint. GRF moments accumulate per foot routed through a joint (branched legs
# sum correctly); the distal weight moment enters once per joint.
static func _stand_scenario(parts: Array, feet: Array, chains: Array, lifted: int,
		cog: Vector3, weight: float) -> Dictionary:
	var active: Array = []
	for i in feet.size():
		if i != lifted:
			active.append(i)
	var loads := {}
	var needs_shift := false
	while true:
		var pts: Array = []
		for i in active:
			var c: Vector3 = feet[i]["contact"]
			pts.append(Vector2(c.x, c.z))
		var sol := _stand_force_distribution(pts, weight, cog.x, cog.z)
		if sol.is_empty():
			needs_shift = true
			var per := weight / maxf(float(active.size()), 1.0)
			for i in active:
				loads[i] = per          # equal-split estimate; statics can't pin it
			break
		var worst_i := -1
		var worst_f := -1.0e-4 * weight
		for i in sol.size():
			if float(sol[i]) < worst_f:
				worst_f = float(sol[i])
				worst_i = i
		if worst_i < 0:
			for i in active.size():
				loads[active[i]] = maxf(float(sol[i]), 0.0)
			break
		active.remove_at(worst_i)       # that foot would have to PULL: it unloads
		if active.size() < 3:
			needs_shift = true
			var per2 := weight / maxf(float(active.size()), 1.0)
			for i in active:
				loads[i] = per2
			break
	# Aggregate moments per joint.
	var joints := {}
	for fi in feet.size():
		var load := float(loads.get(fi, 0.0))
		var contact: Vector3 = feet[fi]["contact"]
		for j in chains[fi]:
			var key := int(j["part"].index)
			if not joints.has(key):
				var anchor0: Vector3 = j["anchor"]
				var m0 := Vector3.ZERO
				for q in j["subtree"]:
					var qp = parts[q]
					m0 += (qp.com_world - anchor0).cross(
							Vector3.DOWN * (qp.mass * STAND_GRAVITY))
				joints[key] = {"rec": j, "moment": m0}
			var jr: Dictionary = joints[key]
			jr["moment"] = (jr["moment"] as Vector3) \
					+ (contact - (j["anchor"] as Vector3)).cross(Vector3.UP * load)
	var margins: Array = []
	var worst := 0.0
	var worst_j: StringName = &""
	for key in joints:
		var jr: Dictionary = joints[key]
		var rec: Dictionary = jr["rec"]
		var tau := absf((rec["axis"] as Vector3).dot(jr["moment"] as Vector3))
		var cap := maxf(float(rec["cap"]), EPS)
		var margin := tau / cap
		# Calibration data: the subtree muscle fraction that would carry this
		# joint's DESIGN load (load × safety reserve), inverted from
		# cpg_torque_cap's formula — and whether the muscle-frac clamp allows it.
		var frac_needed := maxf((tau * STAND_SAFETY / maxf(float(rec["inertia"]), EPS)
				- MUSCLE_BASELINE_CAP) / MUSCLE_TORQUE_K, 0.0)
		margins.append({"part": int(rec["part"].index), "socket": _stand_label(rec["part"]),
				"tau": tau, "cap": cap, "margin": margin,
				"muscle_frac_needed": frac_needed,
				"muscle_achievable": frac_needed <= STAND_MUSCLE_FRAC_MAX})
		if margin > worst:
			worst = margin
			worst_j = _stand_label(rec["part"])
	var out_loads: Array = []
	for fi in feet.size():
		out_loads.append({"part": int(feet[fi]["part"].index),
				"foot": _stand_label(feet[fi]["part"]),
				"load": float(loads.get(fi, 0.0))})
	return {"worst_margin": worst, "worst_joint": worst_j, "margins": margins,
			"loads": out_loads, "needs_weight_shift": needs_shift}


static func _no_support(reason: String = "no support") -> Dictionary:
	return {
		"stable": false,
		"balance_margin": -1.0,
		"tip_angle": 0.0,
		"support_area": 0.0,
		"cog_offset_fore_aft": 0.0,
		"cog_offset_left_right": 0.0,
		"support_centroid": Vector2.ZERO,
		"n_support": 0,
		"excluded_contacts": 0,
		"tip_risk": false,
		"drivers": [reason],
		"reason": reason,
	}


# --- 2D geometry helpers (round 1) -------------------------------

static func _cross_2d(o: Vector2, a: Vector2, b: Vector2) -> float:
	return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)


static func _convex_hull_2d(points: Array[Vector2]) -> Array[Vector2]:
	if points.size() <= 2:
		return points.duplicate()

	var sorted_pts: Array[Vector2] = points.duplicate()
	sorted_pts.sort_custom(func(a: Vector2, b: Vector2) -> bool:
		if a.x != b.x:
			return a.x < b.x
		return a.y < b.y)

	var n := sorted_pts.size()

	var lower: Array[Vector2] = []
	for p in sorted_pts:
		while lower.size() >= 2 and _cross_2d(lower[lower.size() - 2], lower[lower.size() - 1], p) <= 0.0:
			lower.pop_back()
		lower.append(p)

	var upper: Array[Vector2] = []
	for i in range(n - 1, -1, -1):
		var p := sorted_pts[i]
		while upper.size() >= 2 and _cross_2d(upper[upper.size() - 2], upper[upper.size() - 1], p) <= 0.0:
			upper.pop_back()
		upper.append(p)

	var hull: Array[Vector2] = []
	for i in range(lower.size() - 1):
		hull.append(lower[i])
	for i in range(upper.size() - 1):
		hull.append(upper[i])
	return hull


static func _polygon_area_2d(poly: Array[Vector2]) -> float:
	if poly.size() < 3:
		return 0.0
	var area := 0.0
	var n := poly.size()
	for i in n:
		var j := (i + 1) % n
		area += poly[i].x * poly[j].y
		area -= poly[j].x * poly[i].y
	return absf(area) * 0.5


static func _polygon_centroid_2d(poly: Array[Vector2]) -> Vector2:
	if poly.is_empty():
		return Vector2.ZERO
	if poly.size() < 3:
		var sum := Vector2.ZERO
		for p in poly:
			sum += p
		return sum / float(poly.size())

	var cx := 0.0
	var cy := 0.0
	var area := 0.0
	var n := poly.size()
	for i in n:
		var j := (i + 1) % n
		var cr := poly[i].x * poly[j].y - poly[j].x * poly[i].y
		cx += (poly[i].x + poly[j].x) * cr
		cy += (poly[i].y + poly[j].y) * cr
		area += cr
	area *= 0.5
	if absf(area) < EPS:
		var sum2 := Vector2.ZERO
		for p in poly:
			sum2 += p
		return sum2 / float(poly.size())
	cx /= (6.0 * area)
	cy /= (6.0 * area)
	return Vector2(cx, cy)


# Robust convex test (cross-product sign consistency; handles degenerate hulls).
static func _is_point_in_convex_polygon(point: Vector2, poly: Array[Vector2]) -> bool:
	if poly.size() < 3:
		if poly.size() == 2:
			return _dist_point_to_segment_2d(point, poly[0], poly[1]) < EPS
		if poly.size() == 1:
			return (point - poly[0]).length() < EPS
		return false
	var n := poly.size()
	var prev_sign := 0.0
	for i in n:
		var j := (i + 1) % n
		var cr := _cross_2d(poly[i], poly[j], point)
		if absf(cr) < EPS:
			continue
		var s := signf(cr)
		if prev_sign == 0.0:
			prev_sign = s
		elif s != prev_sign:
			return false
	return true


static func _min_distance_to_polygon_edges(point: Vector2, poly: Array[Vector2]) -> float:
	if poly.is_empty():
		return INF
	if poly.size() == 1:
		return (point - poly[0]).length()
	var min_dist := INF
	var n := poly.size()
	for i in n:
		var j := (i + 1) % n
		var d := _dist_point_to_segment_2d(point, poly[i], poly[j])
		min_dist = minf(min_dist, d)
	return min_dist


static func _dist_point_to_segment_2d(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ab_len_sq := ab.dot(ab)
	if ab_len_sq < EPS:
		return (p - a).length()
	var t := clampf((p - a).dot(ab) / ab_len_sq, 0.0, 1.0)
	var proj := a + ab * t
	return (p - proj).length()


# =============================================================================
# 6. Internal-face SA correction (line 25098 §4.5) — subtract buried sockets
# =============================================================================

static func adjust_internal_faces(parts: Array) -> void:
	# For each parent-child pair, estimate the buried shared face (skeleton geometry — a PLACEMENT
	# fact, not a surface measurement) and remove it from both parts' surface area. Removes the
	# internal-face over-count that otherwise favours monolithic blobs over modular builds.
	#
	# F2 physics-authority fix (the B-IF seam): `shared` is a skeleton-sourced ABSOLUTE area. A
	# PRIMITIVE part's surface_area is itself analytic-from-skeleton, so subtracting `shared`
	# literally is single-source AND byte-identical to pre-F2 (every primitive golden untouched, L4).
	# A DESCRIPTOR part's surface_area is descriptor-sourced; subtracting a skeleton MAGNITUDE from it
	# is the hybrid seam. See _apply_internal_face_haircut for the fraction-based descriptor path.
	for p in parts:
		if p.parent < 0:
			continue
		var parent = parts[p.parent]
		var sa_child := minf(minf(p.dims.x * p.dims.z, p.dims.x * p.dims.y), p.dims.y * p.dims.z)
		var sa_parent := minf(minf(parent.dims.x * parent.dims.z, parent.dims.x * parent.dims.y),
				parent.dims.y * parent.dims.z)
		var shared := minf(sa_child, sa_parent) * 0.5
		_apply_internal_face_haircut(p, shared)
		_apply_internal_face_haircut(parent, shared)


# Remove a buried-face estimate from ONE part's surface area, sourced per F2 physics authority.
static func _apply_internal_face_haircut(part: ResolvedPart, shared: float) -> void:
	if part.has_descriptor:
		# Descriptor-backed: remove a dimensionless COVERAGE FRACTION of the canonical descriptor SA.
		# `ref` is the part's OWN skeleton reference area; f = shared/ref is a skeleton/skeleton ratio
		# (scale-invariant, leaks no magnitude), so the amount removed is descriptor-sourced. The clamp
		# bounds buried coverage to [0,1] (can't bury more than the whole part; a high-SA fin keeps its
		# surface even with a covered mount because f tracks the skeleton footprint, not the mesh SA).
		var ref := _shape_surface(part.definition.part_type, part.dims)
		var f := clampf(shared / maxf(ref, EPS), 0.0, 1.0)
		part.surface_area = maxf(part.surface_area * (1.0 - f), EPS)
	else:
		# Primitive: surface_area IS analytic-from-skeleton, so the literal subtraction is single-source
		# and byte-identical to pre-F2. DO NOT change this branch — it is the L4 default-equivalence path.
		part.surface_area = maxf(part.surface_area - shared, EPS)


# =============================================================================
# 7. Biological debt
#    - metabolic supply: aggregate_capacity = Σ heart_volume / √count
#    - geometric perfusion: multi-source Dijkstra (harden v6) with cumulative
#      graft-hop reach; overextension-primary severity, MAX_HEART_REACH cap
#    - SA:V uses the internal-face-corrected surface area
# =============================================================================

static func compute_debt(parts: Array, body_radius: float, _total_mass: float,
		total_volume: float, total_sa: float) -> Dictionary:
	var br := maxf(body_radius, MIN_SIZE)
	var n := parts.size()

	# Tier D: metabolic demand (and the SA:V denominator) read the metabolic-volume SUBSET, so
	# authored inert tissue (metabolic_volume = 0) carries full mass but ZERO metabolic demand.
	# For primitive / all-metabolic parts metabolic_volume == volume, so this equals total_volume
	# and every existing golden stays green. This is an owned L1-(b) re-tune of the demand INPUT —
	# no tuned constant (HEART_*/SAV_*/W_*) changes. (Inert volume still feeds total_volume →
	# body_radius; see BITE NOTE B-BR.)
	var total_metabolic_volume := 0.0
	for p in parts:
		total_metabolic_volume += p.metabolic_volume
	var metabolic_demand := maxf(total_metabolic_volume, EPS)

	var hearts: Array = []
	var lung_vol := 0.0
	var lung_count := 0
	var brain_count := 0
	var has_no_heart_perk := false
	var has_no_brain_perk := false
	var has_no_lung_perk := false
	var graft_indices := {}
	for p in parts:
		if p.tags.has(&"heart"):
			hearts.append(p)
		if p.tags.has(&"lung"):
			lung_vol += p.volume
			lung_count += 1
		if p.tags.has(&"brain"):
			brain_count += 1
		has_no_heart_perk = has_no_heart_perk or p.tags.has(&"diffuse_circulation") or p.tags.has(&"no_heart_required")
		has_no_brain_perk = has_no_brain_perk or p.tags.has(&"decentralized_neural") or p.tags.has(&"no_brain_required")
		has_no_lung_perk = has_no_lung_perk or p.tags.has(&"anaerobic") or p.tags.has(&"no_lung_required")
		if p.tags.has(&"graft"):
			graft_indices[p.index] = true
	var heart_count := hearts.size()
	var fatal_reasons: Array[String] = []
	if heart_count == 0 and not has_no_heart_perk:
		fatal_reasons.append("missing heart")
	if brain_count == 0 and not has_no_brain_perk:
		fatal_reasons.append("missing brain")
	if lung_count == 0 and not has_no_lung_perk:
		fatal_reasons.append("missing lung")

	# Metabolic supply with HONEST diminishing returns: aggregate / √count.
	var cap_sum := 0.0
	for h in hearts:
		cap_sum += HEART_CAP_K * h.volume
	var aggregate_capacity := 0.0
	if heart_count > 0:
		aggregate_capacity = cap_sum / sqrt(float(heart_count))
	var supply := aggregate_capacity * (1.0 + LUNG_OXY_K * (lung_vol / maxf(total_volume, EPS)))
	# M9B: muscle is metabolically expensive. Raise demand by the whole-body muscle
	# MASS FRACTION (a ratio -> scale-invariant; non-muscle parts add nothing, so the
	# Tier-D inert-spike pin is unaffected).
	var muscle_mass := 0.0
	var mass_sum := 0.0
	for p in parts:
		mass_sum += p.mass
		if p.tags.has(&"muscle"):
			muscle_mass += p.mass
	var muscle_frac := muscle_mass / maxf(mass_sum, MIN_MASS)
	var demand := metabolic_demand * (1.0 + MUSCLE_METAB_K * muscle_frac)   # Tier D base * muscle surcharge
	var metabolic_debt := clampf(1.0 - supply / demand, 0.0, 1.0)   # zero hearts -> 1.0

	# SA:V debt (dimensionless via *br); surface_area already internal-face corrected.
	var sav := (total_sa / metabolic_demand) * br                   # Tier D: was total_volume denominator
	var sav_debt := clampf((sav - SAV_HEALTHY) / SAV_SPAN, 0.0, 1.0)

	# Per-heart reach: cube-root of volume, capped at MAX_HEART_REACH.
	var reach := {}
	for h in hearts:
		var r := HEART_REACH_K * pow(maxf(h.volume, EPS), 1.0 / 3.0) / br
		reach[h.index] = clampf(r, MIN_SIZE, MAX_HEART_REACH)

	# Geometric perfusion: multi-source Dijkstra carrying source reach + graft hops.
	var dij := _perfuse(parts, hearts, reach, br, graft_indices)
	var dist = dij["dist"]
	var src = dij["src"]
	var hops = dij["hops"]

	var max_part_mass := MIN_MASS
	for p in parts:
		max_part_mass = maxf(max_part_mass, p.mass)

	var weak_points: Array = []
	for reason in fatal_reasons:
		var wp := WeakPoint.new()
		wp.part_index = 0
		wp.location = parts[0].com_world if not parts.is_empty() else Vector3.ZERO
		wp.severity = 1.0
		wp.kind = &"no_heart" if reason == "missing heart" else (&"no_brain" if reason == "missing brain" else &"no_lung")
		wp.radius = br
		wp.cause = "dead: %s" % reason
		weak_points.append(wp)
	var over_sum := 0.0
	for i in n:
		var p = parts[i]
		var eff_reach := clampf(src[i] + hops[i] * GRAFT_REACH_BONUS, MIN_SIZE, MAX_GRAFT_REACH)
		var over := 0.0
		if dist[i] >= UNREACHABLE:
			over = 2.0                                  # never reached: maximal
		else:
			over = dist[i] / eff_reach - 1.0            # = 1.0 at exactly 2× reach
		over_sum += clampf(over, 0.0, 1.0)
		if over > 0.05:
			var sat := clampf(over, 0.0, 1.0)
			var mass_frac: float = p.mass / max_part_mass
			# Overextension-primary: floor reached at 2× reach REGARDLESS of mass.
			var sev := clampf(SEV_FLOOR_FRAC * sat + (1.0 - SEV_FLOOR_FRAC) * sat * mass_frac, 0.0, 1.0)
			if over >= 1.0:
				sev = maxf(sev, SEV_FLOOR_FRAC)
			var wp := WeakPoint.new()
			wp.part_index = i
			wp.location = p.com_world
			wp.severity = sev
			wp.kind = (&"no_heart" if heart_count == 0 else &"starved")
			wp.radius = p.radius
			wp.cause = "perfusion %.2f body-radii past reach %.2f" % [dist[i], eff_reach]
			weak_points.append(wp)

	# Graft payment: each graft is itself a weak point (the price you pay).
	for p in parts:
		if not p.tags.has(&"graft"):
			continue
		var denom := maxf(src[p.index] + hops[p.index] * GRAFT_REACH_BONUS, MIN_SIZE)
		var downstream := clampf(dist[p.index] / denom - 1.0, 0.0, 1.0)
		var wp := WeakPoint.new()
		wp.part_index = p.index
		wp.location = p.com_world
		wp.severity = clampf(GRAFT_BASE_SEV + 0.3 * downstream, 0.0, 1.0)
		wp.kind = &"graft"
		wp.radius = p.radius
		wp.cause = "graft relay (bone cost x2): fragile patch extending circulation"
		weak_points.append(wp)

	var perfusion_debt := clampf(over_sum / maxf(float(n), 1.0), 0.0, 1.0)
	var debt_total := clampf(W_METAB * metabolic_debt + W_SAV * sav_debt + W_PERF * perfusion_debt, 0.0, 1.0)
	if not fatal_reasons.is_empty():
		debt_total = 1.0

	var drivers := [
		"%d heart(s), %d brain(s), %d lung(s), supply/demand %.2f" % [heart_count, brain_count, lung_count, supply / maxf(demand, EPS)],
		"SA:V %.2f (healthy ~%.1f)" % [sav, SAV_HEALTHY],
		"%d weak point(s)" % weak_points.size(),
	]
	if not fatal_reasons.is_empty():
		drivers.push_front("dead: %s" % ", ".join(fatal_reasons))

	return {
		"debt_total": debt_total,
		"metabolic_debt": metabolic_debt,
		"sav_debt": sav_debt,
		"perfusion_debt": perfusion_debt,
		"supply": supply,
		"demand": demand,
		"heart_count": heart_count,
		"brain_count": brain_count,
		"lung_count": lung_count,
		"alive": fatal_reasons.is_empty(),
		"fatal_reasons": fatal_reasons,
		"aggregate_capacity": aggregate_capacity,
		"weak_points": weak_points,
		"drivers": drivers,
	}


# Exact multi-source perfusion over the part TREE. After the cycle guard the graph is a
# tree, so each heart→node path is unique. One BFS per heart; commit where it improves the
# reach-adjusted overextension ratio dist/eff_reach. Graft hops are counted ONCE per graft
# node on the path (heart→g1→g2→eye gives the eye 2). Signature/return shape unchanged, so
# compute_debt needs no edits. (fix #3 — replaces the ratio-ordered "Dijkstra".)
static func _perfuse(parts: Array, hearts: Array, reach: Dictionary, br: float,
		graft_indices: Dictionary) -> Dictionary:
	var n := parts.size()
	var dist := PackedFloat32Array(); dist.resize(n)
	var src := PackedFloat32Array(); src.resize(n)
	var hops := PackedInt32Array(); hops.resize(n)
	var best_ratio := PackedFloat32Array(); best_ratio.resize(n)
	for i in n:
		dist[i] = UNREACHABLE
		src[i] = 0.0
		hops[i] = 0
		best_ratio[i] = INF
	if hearts.is_empty():
		return {"dist": dist, "src": src, "hops": hops}

	# Undirected tree adjacency, built once.
	var adj: Array = []
	adj.resize(n)
	for i in n:
		adj[i] = []
	for p in parts:
		if p.parent >= 0:
			adj[p.index].append(p.parent)
			adj[p.parent].append(p.index)

	# One BFS per heart; commit where it improves the overextension ratio.
	for h in hearts:
		var h_reach: float = reach[h.index]
		var d_local := PackedFloat32Array(); d_local.resize(n)
		var hop_local := PackedInt32Array(); hop_local.resize(n)
		var seen := PackedByteArray(); seen.resize(n)
		for i in n:
			d_local[i] = UNREACHABLE
			hop_local[i] = 0
			seen[i] = 0
		d_local[h.index] = 0.0
		hop_local[h.index] = (1 if graft_indices.has(h.index) else 0)
		seen[h.index] = 1
		var queue: Array = [h.index]
		var head := 0
		while head < queue.size():
			var u: int = queue[head]
			head += 1
			for v in adj[u]:
				if seen[v] == 1:
					continue
				seen[v] = 1
				var w: float = parts[u].com_world.distance_to(parts[v].com_world) / br
				if not is_finite(w):
					w = 1.0
				d_local[v] = d_local[u] + w
				hop_local[v] = hop_local[u] + (1 if graft_indices.has(v) else 0)
				queue.append(v)
		for i in n:
			if d_local[i] >= UNREACHABLE:
				continue
			var eff := clampf(h_reach + hop_local[i] * GRAFT_REACH_BONUS, MIN_SIZE, MAX_GRAFT_REACH)
			var ratio := d_local[i] / eff
			if ratio < best_ratio[i] - EPS:
				best_ratio[i] = ratio
				dist[i] = d_local[i]
				src[i] = h_reach
				hops[i] = hop_local[i]
	return {"dist": dist, "src": src, "hops": hops}


# =============================================================================
# 8. Speed / Agility / Strength (v6 dimensionless formulas)
#    loco_frac, spread, iso, stab_gate, cog_low; speed normalised by √loco_count.
# =============================================================================

static func compute_movement_and_power(parts: Array, cog: Vector3, body_radius: float,
		balance: Dictionary) -> Dictionary:
	var locomotors: Array = []
	var attacks: Array = []
	var total_volume := 0.0
	var total_mass := 0.0
	for p in parts:
		total_volume += p.volume
		total_mass += p.mass
		if p.tags.has(&"locomotor"):
			locomotors.append(p)
		if p.tags.has(&"attack"):
			attacks.append(p)

	var br := maxf(body_radius, MIN_SIZE)
	var cog_xz := Vector2(cog.x, cog.z)
	var cog_height := maxf(cog.y, 0.0) / br
	var cog_low := clampf(1.0 - cog_height / COG_REF, 0.0, 1.0)

	var loco_centroid := Vector2.ZERO
	var loco_vol := 0.0
	for p in locomotors:
		var xz := Vector2(p.com_world.x, p.com_world.z)
		loco_centroid += xz * p.volume
		loco_vol += p.volume
	if loco_vol > EPS:
		loco_centroid /= loco_vol

	var iso := 1.0
	var spread := 0.0
	if locomotors.size() >= 2:
		var cxx := 0.0
		var czz := 0.0
		var cxz := 0.0
		for p in locomotors:
			var d := Vector2(p.com_world.x, p.com_world.z) - loco_centroid
			cxx += d.x * d.x * p.volume
			czz += d.y * d.y * p.volume
			cxz += d.x * d.y * p.volume
		cxx /= loco_vol
		czz /= loco_vol
		cxz /= loco_vol
		var trace := cxx + czz
		var det := cxx * czz - cxz * cxz
		var disc := sqrt(maxf(trace * trace * 0.25 - det, 0.0))
		var ev1 := trace * 0.5 + disc
		var ev2 := trace * 0.5 - disc
		iso = clampf(sqrt(maxf(ev2, EPS) / maxf(ev1, EPS)), 0.0, 1.0)

		var mean_dist := 0.0
		for p in locomotors:
			mean_dist += Vector2(p.com_world.x, p.com_world.z).distance_to(cog_xz) * p.volume
		mean_dist /= loco_vol
		spread = clampf(mean_dist / br, 0.0, 1.0)

	var stab_gate := 0.0
	if bool(balance.get("stable", false)):
		stab_gate = clampf(float(balance.get("tip_angle", 0.0)) / TIP_REF, 0.0, 1.0)

	var loco_count := locomotors.size()
	var loco_frac := clampf(loco_vol / maxf(total_volume, EPS), 0.0, 1.0)
	# Leg-spam fix (gist line 18494): locomotor COUNT gets diminishing returns the
	# same way hearts do, so a swarm of tiny legs cannot inflate the speed score.
	var loco_frac_norm := loco_frac / sqrt(maxf(float(loco_count), 1.0))

	var speed := 0.0
	if loco_count >= 2:
		speed = clampf(0.30 * loco_frac_norm + 0.20 * spread + 0.15 * stab_gate
				+ 0.15 * iso + 0.20 * cog_low, 0.0, 1.0)

	var rot_inertia := 0.0
	for p in parts:
		var r := Vector2(p.com_world.x, p.com_world.z).distance_to(cog_xz)
		rot_inertia += p.mass * r * r
	rot_inertia = clampf(rot_inertia / maxf(total_mass * br * br, EPS), 0.0, 1.0)

	var agility := 0.0
	if loco_count >= 2:
		agility = clampf(0.25 * iso + 0.20 * spread + 0.20 * stab_gate
				+ 0.20 * cog_low + 0.15 * (1.0 - rot_inertia), 0.0, 1.0)

	var strength := 0.0
	var budget := 0.0
	var max_lever := 0.0
	if not attacks.is_empty():
		var attack_vol := 0.0
		for a in attacks:
			attack_vol += a.volume
			var lever: float = a.com_world.distance_to(cog) / br
			max_lever = maxf(max_lever, lever)
		budget = (attack_vol + loco_vol) / maxf(total_volume, EPS)
		strength = clampf(budget / maxf(1.0 + max_lever, EPS), 0.0, 1.0)

	return {
		"speed": speed,
		"speed_drivers": {
			"loco_frac": loco_frac, "loco_frac_norm": loco_frac_norm, "spread": spread,
			"stab_gate": stab_gate, "iso": iso, "cog_low": cog_low,
		},
		"agility": agility,
		"agility_drivers": {
			"iso": iso, "spread": spread, "stab_gate": stab_gate,
			"cog_low": cog_low, "rot_inertia": rot_inertia,
		},
		"strength": strength,
		"strength_drivers": {"budget": budget, "max_lever": max_lever},
	}


static func compute_traits_intelligence(parts: Array, total_volume: float,
		debt: Dictionary, mp: Dictionary, _balance: Dictionary) -> Dictionary:
	var traits: Array[StringName] = []
	var locomotors := 0
	var ground := 0
	var hearts := 0
	var lungs := 0
	var grafts := 0
	var spine_len := 0.0

	for p in parts:
		if p.tags.has(&"locomotor"): locomotors += 1
		if p.tags.has(&"ground_contact"): ground += 1
		if p.tags.has(&"heart"): hearts += 1
		if p.tags.has(&"lung"): lungs += 1
		if p.tags.has(&"graft"): grafts += 1
		if p.tags.has(&"spine"): spine_len += p.dims.z

	if locomotors == 2 and ground == 2:
		traits.append(&"biped")
	elif locomotors == 4:
		traits.append(&"quadruped")
	elif locomotors >= 6:
		traits.append(&"multi_legged")
	if spine_len > 0.0 and locomotors == 0:
		traits.append(&"serpentine")

	var brain_vol := 0.0
	for p in parts:
		if p.tags.has(&"brain"):
			brain_vol += p.volume
	var intelligence := clampf((brain_vol / maxf(total_volume, EPS)) / 0.05, 0.0, 1.0)
	if intelligence > 0.0:
		traits.append(&"neural")
	if lungs > 0 and hearts > 0:
		traits.append(&"aerobic")
	if grafts > 0:
		traits.append(&"chimera")

	# Stat-dependent traits (were impossible without these inputs). (fix #2)
	var debt_total := float(debt.get("debt_total", 0.0))
	if debt_total > 0.5:
		traits.append(&"overextended")
	if float(mp.get("strength", 0.0)) > 0.6 and debt_total > 0.5:
		traits.append(&"glass_cannon")
	if ground == 0 and locomotors >= 2:
		traits.append(&"flyer")   # content gap: probe under-scores it (see reconcile)

	return {"traits": traits, "intelligence": intelligence}


# =============================================================================
# 9. Probe — deterministic articulated-gait surrogate
#    custom CoM + explicit inertia; scale-invariant PD gains ∝ I_subtree;
#    Froude frequency f = F_BASE·√(g/R); 3× median verdict over perturbed GOLDEN;
#    pass gate distance ≥ PROBE_PASS_DIST · body_radius (scale-relative).
# =============================================================================

static func run_probe(parts: Array, cog: Vector3, body_radius: float, total_mass: float,
		balance: Dictionary, seed: int, gait: GaitDef = null) -> Dictionary:
	# No actuated legs at all → locomotion is simply "none". Skip the gait probe; otherwise
	# a stable statue reports no_translation and gets wrongly implied unstable. (fix #6)
	var has_gait := false
	for p in parts:
		if p.tags.has(&"locomotor") and p.hinge_axis.length() >= EPS:
			has_gait = true
			break
	if not has_gait:
		return {"passed": false, "verdict": &"no_gait", "distance": 0.0,
				"max_separation": 0.0, "mode": &"no_gait", "ticks": 0}

	# 3× median verdict over GOLDEN perturbed by seed (gist line 10328): robust to
	# CPG phase luck while staying fully deterministic.
	var results: Array = []
	for k in 3:
		var perturb := PHASE_PROBES[k] + float(seed) * 0.01
		results.append(_probe_once(parts, cog, body_radius, total_mass, balance, perturb, gait))

	var rank := {&"exploded": 0, &"tipped": 1, &"no_translation": 2, &"passed": 3}
	results.sort_custom(func(a, b): return int(rank[a["verdict"]]) < int(rank[b["verdict"]]))
	var med = results[1]

	var dists := [
		float(results[0]["distance"]),
		float(results[1]["distance"]),
		float(results[2]["distance"]),
	]
	dists.sort()

	return {
		"passed": med["verdict"] == &"passed",
		"verdict": med["verdict"],
		"distance": dists[1],
		"max_separation": med["max_separation"],
		"mode": med["verdict"],
		"ticks": med["ticks"],
	}


static func cpg_frequency(body_radius: float) -> float:
	var br := maxf(body_radius, MIN_SIZE)
	return F_BASE * sqrt(GRAVITY / br)


static func cpg_phase(gait: GaitDef, socket: SocketDef, joint_index: int,
		phase_perturb: float) -> float:
	if gait != null and socket != null and gait.assignments.has(socket.id):
		return fmod(gait.assignments[socket.id] * TAU + phase_perturb, TAU)
	return fmod(float(joint_index) * GOLDEN + phase_perturb, TAU)


static func cpg_phase_t(freq: float, t: float, phase: float) -> float:
	return TAU * freq * t + phase


static func cpg_target_from_phase_t(rest: float, amp: float, phase_t: float,
		amin: float, amax: float) -> float:
	var target := rest + amp * CPG_AMPLITUDE * sin(phase_t)
	if amax > amin:
		target = clampf(target, amin, amax)
	return target


static func cpg_torque_cap(_has_muscle: bool, muscle_frac: float, inertia: float) -> float:
	return (MUSCLE_BASELINE_CAP + MUSCLE_TORQUE_K * maxf(muscle_frac, 0.0)) * maxf(inertia, MIN_SIZE)


static func _probe_once(parts: Array, cog: Vector3, body_radius: float, total_mass: float,
		balance: Dictionary, phase_perturb: float, gait: GaitDef = null) -> Dictionary:
	var br := maxf(body_radius, MIN_SIZE)
	var f := cpg_frequency(body_radius)                 # Froude-scaled gait frequency
	var dt := 1.0 / PROBE_FREQ

	# Build the actuated locomotor hinges. Scale-invariant PD gains: Kp,Kd ∝ I_subtree
	# so geometrically similar creatures share the same dimensionless response.
	var legs: Array = []
	var j := 0
	for p in parts:
		if not p.tags.has(&"locomotor"):
			continue
		if p.hinge_axis.length() < EPS:
			continue                                     # rigid socket: not actuated
		var i_sub := _subtree_inertia(parts, p.index, total_mass, br)
		var lever := Vector2(p.com_world.x - cog.x, p.com_world.z - cog.z).length()
		# Fork C2: authored phase (cycle fraction -> rad) overrides golden-angle default; absent => default.
		var phase_val := cpg_phase(gait, p.socket, j, phase_perturb)
		# Fork B3: per-joint amplitude / rest / RoM (null JointDef => engine defaults; clamp disabled).
		var amp := 1.0
		var rest := 0.0
		var amin := 0.0
		var amax := 0.0
		if p.joint != null:
			amp = p.joint.amplitude
			rest = p.joint.rest_angle
			amin = p.joint.angle_min
			amax = p.joint.angle_max
		# Fork E3: always-finite muscle-derived torque ceiling.
		var tau_cap := cpg_torque_cap(false, _subtree_muscle_frac(parts, p.index), i_sub)
		legs.append({
			"lever": maxf(lever, MIN_SIZE),
			"phase": phase_val,
			"amp": amp,
			"rest": rest,
			"amin": amin,
			"amax": amax,
			"tau_cap": tau_cap,
			"theta": 0.0,
			"omega": 0.0,
			"kp": KP_BASE * i_sub,
			"kd": KD_BASE * i_sub,
			"inertia": i_sub,
			# M36-3: honest torsional spring, mirrored into the probe so analytic<->live parity
			# holds (Principle 15). The probe's only contact signal is the phase-stance proxy.
			"spring_k": (p.spring.stiffness if p.spring != null and p.spring.enabled else 0.0),
			"spring_damp": (p.spring.damping if p.spring != null and p.spring.enabled else 0.0),
			"spring_rest": (amax if amax > amin else (rest + 0.6)),
		})
		j += 1

	# Static tip headroom (from the analytic balance) gates dynamic tip-over.
	var tip_head := 0.0
	if bool(balance.get("stable", false)):
		tip_head = tan(clampf(float(balance.get("tip_angle", 0.0)), 0.0, 1.4))

	# Drive: explicit-Euler integration of each hinge under PD control toward the CPG
	# target; net forward thrust comes from stance-phase feet pushing backward.
	var vx := 0.0
	var x := 0.0
	var t := PROBE_SETTLE_S            # settle window contributes no actuation
	var steps := int(PROBE_DRIVE_S * PROBE_FREQ)
	var max_lat := 0.0
	var max_sep := 0.0
	for s in steps:
		t += dt
		var thrust := 0.0
		var lat := 0.0
		for leg in legs:
			var phase_t: float = cpg_phase_t(f, t, float(leg["phase"]))
			var target := cpg_target_from_phase_t(float(leg["rest"]), float(leg["amp"]),
					phase_t, float(leg["amin"]), float(leg["amax"]))   # Fork B3 amp + rest + D2 clamp
			var tau := float(leg["kp"]) * (target - float(leg["theta"])) - float(leg["kd"]) * float(leg["omega"])
			tau = clampf(tau, -float(leg["tau_cap"]), float(leg["tau_cap"]))   # Fork E3 finite muscle ceiling
			# M36-3: add the honest spring torque, gated by the phase-stance proxy (the probe's
			# only contact signal, Principle 16). Approximate for hop but correct in sign/order.
			var k_s := float(leg["spring_k"])
			if k_s > 0.0 and sin(phase_t) < 0.0:
				var defl := float(leg["theta"]) - float(leg["spring_rest"])
				var tau_s := -k_s * defl - float(leg["spring_damp"]) * k_s * float(leg["omega"])
				tau = clampf(tau + tau_s, -float(leg["tau_cap"]), float(leg["tau_cap"]))
			var alpha := tau / maxf(float(leg["inertia"]), EPS)
			leg["omega"] = float(leg["omega"]) + alpha * dt
			leg["theta"] = float(leg["theta"]) + float(leg["omega"]) * dt
			var foot_v := -float(leg["lever"]) * float(leg["omega"])
			var stance := 1.0 if sin(phase_t) < 0.0 else 0.25
			thrust += foot_v * stance
			lat += absf(foot_v) * 0.5
			max_sep = maxf(max_sep, absf(float(leg["theta"])) * float(leg["lever"]) * 0.02)
		var accel := thrust / maxf(total_mass, MIN_MASS)
		vx += accel * dt
		vx *= 0.98                                       # ground friction / damping
		x += vx * dt
		max_lat = maxf(max_lat, lat / maxf(total_mass, MIN_MASS))
		if not (is_finite(x) and is_finite(vx)):
			return {"verdict": &"exploded", "distance": 0.0, "max_separation": INF, "ticks": s}

	var distance := absf(x)
	var lat_limit := GRAVITY * (tip_head if tip_head > EPS else 0.05)

	var verdict: StringName = &"passed"
	if max_lat > lat_limit:
		verdict = &"tipped"
	elif distance < PROBE_PASS_DIST * br:
		verdict = &"no_translation"

	return {"verdict": verdict, "distance": distance, "max_separation": max_sep, "ticks": steps}


# Mass-weighted second moment of the subtree below (and including) root_idx, about the
# joint origin: Σ(I_own + m·r²). Uses explicit per-part shape inertia. Falls back to
# total_mass·R² when degenerate.
static func _subtree_inertia(parts: Array, root_idx: int, total_mass: float, br: float) -> float:
	return JointModelScript.subtree_inertia(parts, root_idx, total_mass, br)


# Fork E3: fraction of a joint subtree mass that is &"muscle"-tagged. Dimensionless (a mass ratio),
# so it is scale-invariant; mirrors the _subtree_inertia walk. 0.0 when no muscle in the subtree.
static func _subtree_muscle_frac(parts: Array, root_idx: int) -> float:
	return JointModelScript.subtree_muscle_frac(parts, root_idx)


# =============================================================================
# 10. Reconciliation — three-state, honest disagreement
# =============================================================================

static func reconcile(balance: Dictionary, probe: Dictionary) -> Dictionary:
	var analytic_stable := bool(balance.get("stable", false)) and float(balance.get("balance_margin", -1.0)) > 0.0
	var verdict = probe.get("verdict", &"failed")
	var probe_passed := bool(probe.get("passed", false))
	if verdict == &"dead":
		return {"stability_class": &"dead", "locomotion_stable": false,
			"message": "Dead creature: missing vital organs. Check biological debt for heart/brain/lung requirements."}
	# Top-heavy warning rides along on the player-facing message (Cole's call: warn, don't
	# overrule the verdict — the build IS horizontally stable, it's just tippy).
	var tip := "  Heads-up: top-heavy — likely to tip over under a nudge." if bool(balance.get("tip_risk", false)) else ""

	# No actuated legs: locomotion is simply "none" — don't let it imply instability. (fix #6)
	if verdict == &"no_gait":
		if analytic_stable:
			return {"stability_class": &"stable", "locomotion_stable": false,
				"message": "Statically stable, but it has no actuated legs — it stands, it doesn't walk." + tip}
		return {"stability_class": &"unstable", "locomotion_stable": false,
			"message": "No actuated legs and not statically stable — it can neither stand nor walk."}

	var stability_class: StringName = &"unstable"
	var locomotion_stable := false
	var message := ""

	if analytic_stable and probe_passed:
		stability_class = &"stable"
		locomotion_stable = true
		message = "Balanced on paper and it moved under its own gait — confirmed stable."
	elif analytic_stable and not probe_passed:
		stability_class = &"unstable"
		locomotion_stable = false
		message = "Looks balanced statically, but the gait probe %s — the legs likely can't drive this mass." \
				% _probe_word(verdict)
	elif (not analytic_stable) and probe_passed:
		stability_class = &"dynamic_only"
		locomotion_stable = true
		message = "Statically unstable, but the probe held it upright while moving — dynamically stable like a runner; it falls if it stops."
	else:
		stability_class = &"unstable"
		locomotion_stable = false
		message = "Unstable on paper and the probe confirmed it (%s)." \
				% _probe_word(verdict)

	return {"stability_class": stability_class, "locomotion_stable": locomotion_stable, "message": message + tip}


static func _probe_word(verdict) -> String:
	match verdict:
		&"tipped":
			return "tipped it over"
		&"no_translation":
			return "couldn't move it"
		&"exploded":
			return "blew it apart at a joint"
		&"skipped":
			return "was skipped (over bone budget)"
		&"no_gait":
			return "found no actuated legs"
	return "failed"
