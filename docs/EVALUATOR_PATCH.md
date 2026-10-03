# CharacteristicsEvaluator — assembly patch

> **STATUS: APPLIED** (2026-06-25). All six fixes are live in
> `scripts/core/CharacteristicsEvaluator.gd`; `_neighbors` deleted. TUNING-1/2
> decided: `HEART_CAP_K = 8.0`, `HEART_REACH_K = 3.0`, `MAX_HEART_REACH = 3.0`.
> Verified with `godot --headless --check-only` (clean) and the golden harness
> `tests/test_characteristics_evaluator.gd` (**38/38**).
>
> The top-heavy-tower case was resolved by Cole's call: a centered tower is
> *truthfully* horizontally stable (`balance_margin` is horizontal-only by design),
> so the verdict was NOT changed. Instead `compute_balance` now emits a `tip_risk`
> flag + player warning when a stable build has < `TIP_WARN_ANGLE` (~17°) of tilt
> headroom; the test asserts the warning fires. Kept as provenance.

Fixes found auditing the assembled design pass v6 evaluator. Apply in order. Every
function below is a **complete drop-in replacement** unless marked "insert"/"edit".
Compile-check with `godot --headless --check-only` (or your script check) after.

Coupled set (BLOCKING): #1 phase no-op, #2 trait inputs, #3 perfusion tree-pass,
#6 legless-stable reconcile. Plus #4 header claim, #5 balance drivers.

Two NON-CODE findings need a tuning decision from Cole — see bottom (TUNING-1/2).

---

## #1 — seed=0 makes the 3× median probe a no-op

Add a constant (constants block):
```gdscript
const PHASE_PROBES := [0.0, 0.61803, 1.23607]   # always-distinct golden phase offsets
```
Edit `run_probe`, replace the perturb line inside the `for k in 3:` loop:
```gdscript
		var perturb := PHASE_PROBES[k] + float(seed) * 0.01
```
Now the three runs differ even when `seed == 0`, so the phase-luck robustness actually works.

---

## #2 — trait engine can't see debt/strength/stability (3 traits never fire)

Edit the call in `evaluate()`:
```gdscript
	var ti := compute_traits_intelligence(parts, total_volume, debt, mp, balance)
```
Replace `compute_traits_intelligence` with:
```gdscript
static func compute_traits_intelligence(parts: Array, total_volume: float,
		debt: Dictionary, mp: Dictionary, balance: Dictionary) -> Dictionary:
	var traits: Array[StringName] = []
	var locomotors := 0
	var ground := 0
	var hearts := 0
	var brains := 0
	var lungs := 0
	var grafts := 0
	var spine_len := 0.0

	for p in parts:
		if p.tags.has(&"locomotor"): locomotors += 1
		if p.tags.has(&"ground_contact"): ground += 1
		if p.tags.has(&"heart"): hearts += 1
		if p.tags.has(&"brain"): brains += 1
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

	# Stat-dependent traits (were impossible without these inputs).
	var debt_total := float(debt.get("debt_total", 0.0))
	if debt_total > 0.5:
		traits.append(&"overextended")
	if float(mp.get("strength", 0.0)) > 0.6 and debt_total > 0.5:
		traits.append(&"glass_cannon")
	if ground == 0 and locomotors >= 2:
		traits.append(&"flyer")   # content gap: probe under-scores it (see reconcile)

	return {"traits": traits, "intelligence": intelligence}
```

---

## #3 — perfusion: replace ratio-ordered "Dijkstra" with an exact tree pass

After the cycle guard the graph is a tree, so each heart→node path is unique. This
is exact, order-independent, and removes the dead frontier/stale-skip logic. It also
fixes the graft-hop **double-count** (old code counted a hop if *either* endpoint was
a graft). `_perfuse`'s signature and return shape are unchanged, so `compute_debt`
needs no edits. **Delete the now-unused `_neighbors` function.**

```gdscript
# Exact multi-source perfusion over the part TREE. For each node we keep the heart
# whose path minimises the reach-adjusted overextension ratio dist/eff_reach. Graft
# hops are counted once per graft node on the path (heart→g1→g2→eye gives the eye 2).
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
```

---

## #6 — legless-but-stable build is wrongly labelled "unstable"

A statue (stable margin, no actuated legs) currently runs the probe, gets
`no_translation`, and reconciles to `unstable` ("legs can't drive this mass"). It is
stable; it just doesn't walk. Add a `no_gait` short-circuit.

Insert at the **top of `run_probe`**, before the `for k in 3:` loop:
```gdscript
	var has_gait := false
	for p in parts:
		if p.tags.has(&"locomotor") and p.hinge_axis.length() >= EPS:
			has_gait = true
			break
	if not has_gait:
		return {"passed": false, "verdict": &"no_gait", "distance": 0.0,
				"max_separation": 0.0, "mode": &"no_gait", "ticks": 0}
```
Replace `reconcile` with:
```gdscript
static func reconcile(balance: Dictionary, probe: Dictionary) -> Dictionary:
	var analytic_stable := bool(balance.get("stable", false)) and float(balance.get("balance_margin", -1.0)) > 0.0
	var verdict = probe.get("verdict", &"failed")
	var probe_passed := bool(probe.get("passed", false))

	# No actuated legs: locomotion is simply "none" — don't let it imply instability.
	if verdict == &"no_gait":
		if analytic_stable:
			return {"stability_class": &"stable", "locomotion_stable": false,
				"message": "Statically stable, but it has no actuated legs — it stands, it doesn't walk."}
		return {"stability_class": &"unstable", "locomotion_stable": false,
			"message": "No actuated legs and not statically stable — it can neither stand nor walk."}

	var stability_class: StringName = &"unstable"
	var locomotion_stable := false
	var message := ""
	if analytic_stable and probe_passed:
		stability_class = &"stable"; locomotion_stable = true
		message = "Balanced on paper and it moved under its own gait — confirmed stable."
	elif analytic_stable and not probe_passed:
		stability_class = &"unstable"
		message = "Looks balanced statically, but the gait probe %s — the legs likely can't drive this mass." % _probe_word(verdict)
	elif (not analytic_stable) and probe_passed:
		stability_class = &"dynamic_only"; locomotion_stable = true
		message = "Statically unstable, but the probe held it upright while moving — dynamically stable like a runner; it falls if it stops."
	else:
		message = "Unstable on paper and the probe confirmed it (%s)." % _probe_word(verdict)
	return {"stability_class": stability_class, "locomotion_stable": locomotion_stable, "message": message}
```
Add a case to `_probe_word`:
```gdscript
		&"no_gait":
			return "found no actuated legs"
```

---

## #4 — overstated reproducibility claim (header docstring)

The probe is RNG-free and fixed-step, but uses sin/cos/sqrt/pow/atan2 — libm
transcendentals are **not** bit-identical across CPUs/compilers. Replace the header line:
```
## so it is cross-machine reproducible). The probe is ground truth for locomotion;
```
with:
```
## so it is SAME-BINARY reproducible (transcendental math is not bit-identical across
## platforms — do not treat the locomotion verdict as cross-machine authoritative for
## ranked play). The probe is ground truth for locomotion;
```

---

## #5 — restore human-readable balance drivers (Foundry explainability mandate)

Replace `compute_balance` (adds a `drivers` array; computes offsets once):
```gdscript
static func compute_balance(parts: Array, cog: Vector3, body_radius: float) -> Dictionary:
	var br := maxf(body_radius, MIN_SIZE)
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
	var fore_aft := (cog_proj.y - centroid.y) / br
	var left_right := (cog_proj.x - centroid.x) / br

	var drivers: Array[String] = []
	if not inside:
		drivers.append("CoG is outside the support polygon — it tips")
	elif margin < 0.15:
		drivers.append("narrow stance: only %.2f body-radii of margin" % margin)
	else:
		drivers.append("stable stance: %.2f body-radii of margin" % margin)
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
		"drivers": drivers,
		"reason": "",
	}
```
And add `"drivers": [reason],` to the dictionary returned by `_no_support`.

---

## TUNING decisions for Cole (not bugs — integration seams that need a number)

**TUNING-1 — metabolic supply/demand is mis-scaled; debt floors high for every creature.**
`supply = (Σ heart_volume)/√count`, `demand = total_volume`, so `supply/demand ≈ heart_fraction`,
which is always small → `metabolic_debt ≈ 1 − heart_fraction` stays ~0.5–1.0 even with a
huge heart. The design pass's `HEART_CAP_K` (capacity per unit heart volume) was dropped during
assembly. Restore it so a sane heart fraction (~5–10% of body) yields supply≈demand:
```gdscript
const HEART_CAP_K := 8.0   # tune: a heart supplies ~8× its own volume of tissue
# in compute_debt: cap_sum += HEART_CAP_K * h.volume
```
Calibrate `HEART_CAP_K` against the heart-spam test (it must still hold that 10 tiny hearts
score worse than 1 big one, which √count already guarantees).

**TUNING-2 — heart reach is harsh; normal hearts can't perfuse a normal body.**
`reach = HEART_REACH_K · vol^(1/3) / body_radius` means a heart must be ~60% of the body's
linear size to reach 1 body-radius. Either raise `HEART_REACH_K` (try 3.0–4.0) or raise
`MAX_HEART_REACH`, then re-run the golden tests. This is a playtest knob the gist already
flagged as "needs playtest"; just pick a value and pin it with a test.
