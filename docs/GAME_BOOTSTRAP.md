# LoColemotion Game Bootstrap -- M1..M10 (Editor -> Playable)

> **For:** an implementing agent, executing in the LoColemotion repo with Godot 4.7 (mono) available.
> **Goal:** carry LoColemotion from "you can author a creature in the editor" to "you
> can breed, simulate, and play creatures in a real game loop," without ever giving
> the UI or the game a second source of physics truth.
> **Read first:** `docs/DESIGN.md`, `docs/TIER1_BOOTSTRAP.md` (genome foundation),
> `docs/EDITOR_BOOTSTRAP.md` (the editor spine), `docs/foundry/F2_RESOLVED.md`,
> `docs/PROBLEM2_GAIT_HANDOFF.md` (the analytic gait/joint model).
>
> **Discipline (non-negotiable, learned the hard way):** this is a forward design.
> Before writing a line for any milestone, **open the real files and confirm the
> signatures** named in its "Depends on" block. Do not invent methods, fields, or
> return shapes. The repo is the source of truth; this document is the map.
> Also: **commit at every green**, and keep any autonomous loop read-only or in its
> own worktree -- uncommitted work next to an autonomous writer is how work dies.
>
> **Later research direction (2026-07-27):** this M1-M10 document is not the
> authoritative ledger for the later BR14A physical-locomotion program. The
> long-term extraction target is the
> [Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md),
> informed by the exact sources and adoption decisions in the
> [Locomotion Research Sources and Adoption Ledger](research/LOCOMOTION_RESEARCH_SOURCES.md).
> Those later documents do not retroactively expand the M1-M10 acceptance scope.

---

## The arc (what these ten milestones build, in one breath)

Creatures become durable assets (M1), gain the ability to *change* (M2), and start
*evolving* against the analytic oracle that already exists (M3). Then they get a
real body: an articulated physics ragdoll (M4) driven by the same gait model the
oracle scores (M5), measured against ground truth so the cheap oracle becomes
trustworthy (M6). Then the world they act in (M7), the loop the player drives (M8),
the conflict that gives it stakes (M9), and the content + production layer that
makes it a product (M10).

---

## THE load-bearing decision: analytic oracle vs live simulation

Everything downstream forks on this, so decide it explicitly and once.

You already have a sophisticated **analytic** locomotion model: the
`CharacteristicsEvaluator` probe estimates speed/stability/debt from physics-derived
quantities (lever arms, sub-tree inertia, CPG-driven joint torque, per-joint
amplitude/rest/RoM, gait phase, muscle-torque ceilings) **without simulating
anything**. The alternative is a **live** articulated physics sim (Godot Jolt) that
actually moves the creature and measures the result.

| | Analytic oracle (have it) | Live articulated sim (M4-M6) |
|---|---|---|
| Speed | microseconds; thousands/sec | seconds of wall-clock per rollout |
| Determinism | exact, seedable | jittery; solver-dependent |
| Scales to evolution | yes (the whole point) | no, not at population scale |
| Fidelity | a proxy; can be gamed | ground truth; emergent |
| Headless | trivially | yes but heavy |

**Ruling: hybrid, and the analytic oracle stays primary.** The probe is the cheap
fitness function that powers evolution at population scale (M3). The live sim is the
**high-fidelity show-and-verify layer**: it makes a champion watchable/playable (M4-M5)
and provides ground truth to **calibrate the oracle** (M6, which fills the
evaluator's existing `reconciliation` slot). Never silently blend the two: analytic
numbers come from `evaluate()`; measured numbers are a separate, clearly-labeled
channel. The day they disagree, that disagreement is *data* (M6), not a bug to paper over.

**The one alternative worth weighing:** build the live sim (M4) *before* evolution
(M3) if you fear the analytic probe is an unfaithful optimization target -- better to
prove the physics works before investing in evolving against a proxy. The cost is a
harder, slower first lift and a delayed payoff. **Recommendation: analytic-first.**
The probe already exists and is tested, so evolution is nearly free and immediately
answers "is this genome space even interesting/evolvable?" -- and it surfaces the
probe's exploitable optima early, which is exactly what M6 then needs to fix.

---

## Cross-cutting invariants (carry these through all ten)

- **I1 -- Frame law.** `child_world = parent_world * socket.parent_attachment *
  socket.child_anchor`; scale accumulates separately, never baked into a basis. M4
  (physics joints) is the **second** non-`fold_graph` consumer the prior bootstraps
  predicted -- this is finally when `scripts/creature/creature_frames.gd` gets
  extracted, with one shared `world_of(parent_world, socket)` that `_fold`, the
  assembler, the editor gizmo preview, and the physics builder ALL call.
- **I2 -- Evaluator authority.** Analytic stats come only from `evaluate()` /
  `scheduler.current()`. Measured-from-sim stats live in their own struct and are
  labeled "measured." No widget or system recomputes physics by hand.
- **I3 -- Snapshot isolation.** Mutation, crossover, evolution, and "load creature
  into sim" all operate on `GenomeSnapshot.deep_copy` and pass
  `validate_unique` before use. A shared sub-resource across genes is always illegal.
- **I4 -- Determinism.** Every stochastic system (mutation, evolution, any sim
  variation) takes an explicit integer seed and uses a local `RandomNumberGenerator`,
  never the global RNG. "Replay this lineage" must be exact.
- **I5 -- Parallelism pattern.** Population-scale evaluation reuses the F5
  `ScoreScheduler` / `WorkerThreadPool` pattern (evaluate on workers, accept on the
  main thread, drop stale generations). Evolution is the heavy consumer of this.

---

## The ten milestones (quick reference)

1. **Creature Library & Persistence Hardening** -- durable `CreatureCard` save/load,
   a browser, validation, schema versioning. Creatures become real assets.
2. **Genome Mutation Operators** -- seeded, guard-railed mutation + crossover on the
   `PartGene` tree. Sim-independent; the raw material for evolution.
3. **Evolution Engine (analytic fitness)** -- population/select/mutate loop scored by
   the existing probe, parallelized, with lineage. Cheapest compelling demo; stress-tests
   the oracle as an optimization target.
4. **Articulated Runtime (live physics body)** -- genome -> RigidBody3D parts + hinge
   joints (Jolt), placed by the shared frame law. The bridge to watchable/playable.
5. **CPG Locomotion Controller** -- drive the hinges with the same CPG model the probe
   scores (JointDef amplitude/rest/RoM, GaitDef phase, E3 torque ceiling).
6. **Measured Fitness & Reconciliation** -- headless rollouts measuring real
   distance/stability/energy; compare to the analytic verdict; calibrate the oracle.
7. **Environment, Terrain & Challenges** -- the world creatures act in, plus a library
   of challenge definitions (sprint, rough terrain, gap, climb).
8. **Core Game Loop & First Playable Mode** -- design/breed -> challenge -> result ->
   progression. First mode + the sandbox-vs-competitive fork.
9. **Conflict / Interaction Systems (vitals & damage)** -- turn the latent
   attack/heart/brain tags + weak_points/debt into a real vitals/damage model.
10. **Content Pipeline & Production Polish** -- authored meshes, descriptor authoring,
    catalog expansion, save migration, perf budgets, UX, 2-DoF joint re-entry.

---

# M1 -- Creature Library & Persistence Hardening

**Why now:** every later system (evolution, sim, challenges) consumes a *corpus* of
creatures. They must round-trip to disk losslessly and survive schema changes, or
everything downstream sits on sand.

**Depends on:** the editor's P1 data layer (`CreatureCard`, `PartCatalog`,
`CreatureIO`) and `GenomeSnapshot.validate_unique`. Confirm `CreatureCard`'s fields
and `CreatureIO.save/load/scan` signatures as built.

**Key decisions:**
- *Embedded vs catalog-resolved save* -- you ruled embedded for the editor. Keep it,
  but now add a **`schema_version`** gate: `CreatureIO.load` must reject or migrate a
  card whose version it does not understand, never silently load a half-parsed tree.
- *Library scope* -- one flat `data/creatures/` folder is fine to start; add tags/folders
  only when the corpus is big enough to need them (do not pre-build a taxonomy).

**Files & sketch:**
- `scripts/editor/creature_library.gd` -- scans `CreatureIO.scan`, holds cards in
  memory, exposes `all()`, `by_name()`, `add(card)`, `remove(path)`; emits `changed`.
- `scenes/editor/library_panel.tscn` + script -- thumbnail/list browser: select ->
  open in editor; delete with confirm; duplicate; rename.
- Migration: `scripts/editor/creature_migrations.gd` -- a dict of
  `version -> func(card) -> card`. `CreatureIO.load` runs the chain up to current.
- **On every load:** `GenomeSnapshot.validate_unique(card.root)`; if not ok, clone to
  fix aliasing (a hand-edited `.tres` is untrusted input) and warn.

**Acceptance:** round-trip 20 hand-authored creatures save->scan->load, each deep-equal
to source and `validate_unique` ok; an old-`schema_version` file migrates (or is
cleanly rejected) without crashing; deleting/renaming in the browser reflects on disk.

**Pitfalls:** a `.tres` that aliases a sub-resource (saved before the editor's guard)
must be repaired on load, not trusted; thumbnails generated on the main thread will
hitch a big library -- generate lazily/off-thread or cache to disk.

---

# M2 -- Genome Mutation Operators

**Why now:** evolution (M3) is just "mutate + select" in a loop. Build the mutation
half first, in isolation, fully tested -- it is pure data, no physics, no UI.

**Depends on:** `PartGene` (fields: `definition, descriptor, tags, socket, scale,
children, joint, gait, part_id, socket_id, dial_values`), `PartCatalog` (clone source
for "add part"), `GenomeSnapshot.deep_copy` / `validate_unique`, `JointDef`,
`GaitDef`, `SocketDef` (incl. `hinge_axis`). Confirm each field exists as named.

**Key decisions:**
- *Operator set* -- start with the cheap, high-yield ones:
  - **parameter jitter:** perturb `scale`, `socket.parent_attachment` pose,
    `joint.amplitude/rest_angle/angle_min/angle_max`, `dial_values` by Gaussian noise.
  - **topology:** add a child part (clone a `PartCatalog` template with FRESH
    sub-resources), remove a sub-tree, duplicate a sub-tree onto a new socket.
  - **gait:** perturb `gait.assignments[socket_id]` phases; occasionally re-roll `pattern`.
  - **mirror/symmetry** (optional early): reflect a sub-tree across an axis.
- *Crossover* -- sub-tree swap between two parents at a compatible socket. Powerful but
  prone to chimeras; gate it behind validity checks and keep its rate low at first.
- *Bounds* -- every numeric mutation clamps to sane ranges (scale > 0; RoM stays
  `amax >= amin` or disabled; phases wrap `[0, TAU)`). An out-of-range gene is a slow
  poison.

**Files & sketch:**
```
class_name GenomeMutator
extends RefCounted

class Config:
    var seed: int = 0
    var jitter_sigma := 0.15
    var p_add := 0.10
    var p_remove := 0.08
    var p_dup := 0.05
    var p_crossover := 0.05
    # ...rates per operator

# Returns a NEW, validated genome. Never mutates `parent` in place.
static func mutate(parent: PartGene, cfg: Config, rng: RandomNumberGenerator) -> PartGene:
    var child := GenomeSnapshot.deep_copy(parent)    # I3
    # apply operators using `rng` only (I4)...
    # then guard:
    var chk := GenomeSnapshot.validate_unique(child)
    if not chk["ok"]:
        return GenomeSnapshot.deep_copy(parent)       # reject: identity fallback
    return child
```
- `static func crossover(a, b, cfg, rng) -> PartGene` -- sub-tree graft, deep-copied,
  validated; identity-fallback to `a` on illegal result.
- A **cycle/alias guard** is mandatory on add/dup/crossover (the classic re-parent bug:
  appending a sub-tree without deep-copying it).

**Acceptance (`tests/test_genome_mutator.gd`):** same seed -> byte-identical offspring
(I4); every operator's output passes `validate_unique`; clamps hold (no `scale <= 0`,
no inverted RoM, phases wrapped); `evaluate()` runs without error on 1000 random
mutants (no NaN, no crash) -- this doubles as a fuzz test of the evaluator.

**Pitfalls:** mutating the live tree instead of a copy (I3); using the global RNG and
losing reproducibility (I4); an "add part" that shares one `PartDefinition` across
parts -- clone the template's sub-resources; unbounded drift producing degenerate
giants/specks that the probe scores absurdly (clamp early).

---

# M3 -- Evolution Engine (analytic fitness)

**Why now:** with mutation (M2) and the existing probe, evolution is almost free and
is the fastest path to something genuinely compelling -- watch a population learn to
"walk" by the oracle's verdict. It also stress-tests the oracle: degenerate optima
(creatures that game the probe) surface here and become M6's calibration targets.

**Depends on:** `GenomeMutator` (M2), `CharacteristicsEvaluator.evaluate` (fitness
source -- keys `speed.value`, `balance`, `debt`, `probe`, `status`, etc.),
`GenomeSnapshot.deep_copy`, and the F5 `ScoreScheduler` / `WorkerThreadPool` pattern
for parallel evaluation (I5).

**Key decisions:**
- *Fitness function* -- a weighted scalar over `evaluate()` outputs (e.g.
  `speed.value` reward, `balance.stable` gate, `debt` penalty, mass/efficiency terms).
  Make the weights data (`FitnessSpec` resource) so challenges (M7) can define their own.
- *Algorithm* -- start with a simple generational GA (elitism + tournament selection +
  mutation; crossover optional). Add novelty/diversity pressure only if the population
  collapses to one cheese strategy (it will -- note it, do not pre-engineer it).
- *Parallelism* -- evaluate a generation across `WorkerThreadPool` tasks
  (`evaluate()` is static and pure -> trivially parallel). This is the same happens-before
  pattern `ScoreScheduler.run_pending_blocking` already uses; reuse it.

**Files & sketch:**
```
class_name EvolutionEngine
extends RefCounted

class FitnessSpec:        # data-driven so challenges can reweight
    var speed_w := 1.0
    var debt_w := 0.5
    var require_stable := true
    func score(eval: Dictionary) -> float: ...

# One generation: evaluate (parallel) -> select -> reproduce. Deterministic in seed.
func step(pop: Array, spec: FitnessSpec, cfg: GenomeMutator.Config) -> Array: ...
func _evaluate_population(pop: Array) -> PackedFloat32Array:   # WorkerThreadPool (I5)
    ...
```
- `scripts/sim/lineage.gd` -- record parent->child edges + per-gen best fitness, so a
  run is replayable and inspectable (feeds an evolution-history UI later).
- A headless **`run_evolution.gd`** entry (SceneTree script) to sweep generations and
  dump the champion as a `CreatureCard` into the library (M1).

**Acceptance:** a flat-ground sprint `FitnessSpec` produces monotonically improving
best-fitness over generations on a fixed seed, reproducibly; a champion saved to the
library opens in the editor and re-scores identically; evaluating a 200-creature
generation across workers beats single-threaded wall-clock and yields identical results.

**Pitfalls:** non-determinism creeping in via global RNG or thread-order-dependent
accumulation (sort by a stable key before reducing); the population converging on a
probe exploit (record it -- it is the M6 to-do list); evaluating the same genome
repeatedly without caching when fitness is deterministic (memoize by a genome hash).

---

# M4 -- Articulated Runtime (live physics body)

**Why now:** this is the biggest technical unknown and the gateway to "watch/play."
De-risk it as an isolated, headless-testable spike before any game mode leans on it.

**Depends on:** the **extracted** `creature_frames.gd` (I1), `fold_graph` (for initial
world poses, `dims`, `com_world`, `world_aabb`), `PartGene`/`SocketDef`
(`hinge_axis`, `hinge_axis_2` is reserved/undriven -- 1-DoF only, per D1 LOCKED),
`PartDefinition.density` (for mass), and Godot Jolt (confirm it is the active 3D
physics engine in `project.godot`).

**Key decisions:**
- *Body topology* -- one `RigidBody3D` per part; one `Joint3D` per socket. Where
  `socket.hinge_axis == ZERO`, use a fixed/welded joint (rigid); where non-zero, a
  `HingeJoint3D` about the oriented axis. **Mass from physics, not eyeballing:** set each
  body's mass = `definition.density * volume(dims)` so the live body matches the
  analytic mass `evaluate()` reports (I2 consistency).
- *Placement* -- initial transforms come straight from the shared frame law (the SAME
  `world_of` the assembler uses), so the live body spawns exactly where the editor
  preview showed it. This is the second frame-law consumer that justifies the extraction.
- *Self-collision* -- disable collision between directly-jointed neighbors (they overlap
  at the socket) or the solver explodes on frame 1. Layer/mask or per-pair exceptions.
- *Spawn settling* -- drop the creature a hair above ground and let it settle a few
  fixed ticks before any control input, so initial interpenetration relaxes.

**Files & sketch:**
```
class_name CreatureBody
extends Node3D
## Live articulated body built from a genome. Mirrors the assembler's placement
## (shared creature_frames), but with RigidBody3D + Joint3D instead of MeshInstance3D.

static func build(root: PartGene, root_xform := Transform3D.IDENTITY) -> CreatureBody:
    # fold = CharacteristicsEvaluator.fold_graph(root, root_xform)
    # per ResolvedPart: RigidBody3D, collision shape from part_type+dims,
    #   mass = density * volume, transform = p.xform (frame law)
    # per socket: HingeJoint3D on hinge_axis (or fixed if ZERO), neighbor collision off
    ...
func part_bodies() -> Array          # index-aligned to fold_graph order, for the controller (M5)
func measure() -> Dictionary         # CoM, contacts, etc., for M6
```

**Acceptance (headless physics test):** a built body **stands** -- after N settle ticks
its CoM stays within the support polygon for a creature the probe calls `balance.stable`,
and visibly topples for one it calls unstable (picture agrees with the analytic verdict);
no NaN/explosion on spawn; body part count == `fold_graph` part count; live total mass ==
`evaluate()["total_mass"]` within tolerance (the I2 consistency check).

**Pitfalls:** baking scale into a body's basis (I1 -- size lives in the collision shape's
dims, never node scale); neighbor self-collision blowing up the solver; mismatched
mass between sim and oracle (compute both from `density*volume`); hinge axis defined in
the wrong frame (it is the socket's, transform it correctly); forgetting `hinge_axis_2`
is reserved -- do NOT wire a second DoF (D1 LOCKED).

---

# M5 -- CPG Locomotion Controller

**Why now:** a body that just stands is a ragdoll. To move -- and to be *comparable to
the analytic verdict* -- it must be driven by the same central pattern generator the
probe models.

**Depends on:** M4 `CreatureBody`; the probe's gait model in `CharacteristicsEvaluator`
(confirm the real constants/fields: `CPG_AMPLITUDE`, per-joint `amplitude/rest_angle/
angle_min/angle_max` from `JointDef`, gait phase from `GaitDef.assignments[socket_id]`,
the E3 muscle-torque ceiling and `_subtree_muscle_frac`). The controller must read the
SAME parameters the probe reads, or M6's comparison is meaningless.

**Key decisions:**
- *Drive law* -- per hinge, target angle =
  `rest_angle + amplitude * CPG_AMPLITUDE * sin(2*PI*freq*t + phase)`, clamped to
  `[angle_min, angle_max]` when RoM is enabled, with applied torque capped by the E3
  muscle ceiling. This is a literal transcription of the probe's `_probe_once` math --
  keep them in lockstep (ideally share a helper so they can never drift).
- *Actuation* -- angular motor on `HingeJoint3D` (target velocity toward the desired
  angle) or PD torque. Pick one; PD gives finer control but needs tuning.
- *Phase source* -- `GaitDef.assignments` keyed by `socket_id`; fall back to the golden
  default phase (the same fallback the probe uses) for unassigned joints.

**Files & sketch:**
```
class_name CpgController
extends RefCounted
## Drives a CreatureBody's hinges from the genome's JointDef/GaitDef, using the SAME
## law the analytic probe scores. freq + global phase are the only free runtime params.

func bind(body: CreatureBody, root: PartGene) -> void: ...
func tick(t: float, delta: float) -> void:   # call from _physics_process
    # for each driven hinge: target = rest + amp*CPG_AMPLITUDE*sin(2pi*freq*t + phase)
    # clamp to RoM; apply via motor/PD, torque-capped by the E3 ceiling
    ...
```

**Acceptance:** a creature the probe rates a strong walker actually translates forward
under CPG drive in the live sim; killing the controller -> it stops/collapses; the
driven joint angles track the commanded sinusoid within tolerance; the SAME
`JointDef`/`GaitDef` numbers produce visibly the gait the probe assumed.

**Pitfalls:** controller math drifting from the probe math (share the helper); motor
gains so high the solver fights itself (jitter/explode); ignoring the torque ceiling so
weak creatures move like strong ones (defeats the muscle model); per-frame instead of
per-physics-tick driving (use `_physics_process`).

---

# M6 -- Measured Fitness & Reconciliation

**Why now:** M3 evolves against the *analytic* oracle. M6 proves (or corrects) that the
oracle predicts *reality*. This is the milestone that earns the "hybrid" decision and
fills the `reconciliation` slot `evaluate()` already returns.

**Depends on:** M4 + M5 (a body that moves), `evaluate()`'s analytic outputs, and the
`reconciliation` key in the evaluate return shape (confirm what it currently holds).

**Key decisions:**
- *What "measured" means* -- run the live sim headless for a fixed horizon and record:
  forward distance, CoM path stability, energy/torque integral, fall time. These are the
  ground-truth analogues of `speed.value`, `balance`, and `debt`.
- *Reconciliation* -- compute per-metric error (measured vs analytic) and expose it as a
  labeled, separate channel (I2). Do **not** overwrite analytic numbers with measured
  ones; surface the delta. A large systematic delta is a probe-calibration task.
- *Calibration loop* (optional but valuable) -- fit the probe's free constants
  (`CPG_AMPLITUDE`, torque coefficients) to minimize measured-vs-analytic error across a
  corpus, so evolution (M3) optimizes something physically meaningful.

**Files & sketch:**
```
class_name SimRollout
extends RefCounted
## Headless, deterministic live-sim rollout. Returns MEASURED metrics only.
static func run(root: PartGene, horizon_s: float, seed: int) -> Dictionary:
    # build CreatureBody, settle, drive with CpgController, integrate, measure
    # -> {distance, stability, energy, fell:bool, ...}   (MEASURED channel)
```
- `scripts/sim/reconcile.gd` -- given `evaluate(root)` and `SimRollout.run(root)`,
  return per-metric deltas + an aggregate fidelity score.

**Acceptance:** for a fixed seed, `SimRollout.run` is reproducible; across a corpus the
measured ranking correlates with the analytic ranking (Spearman/Kendall above a stated
threshold) -- if it does not, that is the headline finding and the calibration backlog;
the reconciliation channel is visibly separate from analytic stats in any UI that shows both.

**Pitfalls:** treating measured numbers as "more correct" and quietly replacing analytic
ones (I2 -- they are different channels); a non-deterministic solver making rollouts
unreproducible (fix the tick rate, seed any variation); comparing apples to oranges
(measured distance vs analytic speed -- normalize by horizon).

---

# M7 -- Environment, Terrain & Challenges

**Why now:** measured fitness (M6) and gameplay (M8) both need a *world*. A flat plane
is enough to start; the value is the **challenge abstraction**, not the art.

**Depends on:** M4 (bodies act in the world), M6 (`SimRollout` runs inside a challenge),
M3 (`FitnessSpec` -- a challenge defines its own).

**Key decisions:**
- *Challenge as data* -- a `ChallengeDef` resource: terrain ref, start/finish, time limit,
  the `FitnessSpec` to score with, and success criteria. Levels become content, not code.
- *Terrain tiers* -- flat sprint (baseline), rough/noisy ground, a gap to clear, a slope
  to climb. Each isolates a locomotion capability and gives evolution something to chew on.
- *Determinism* -- terrain generation is seeded (I4) so a challenge is identical across runs.

**Files & sketch:**
```
class_name ChallengeDef
extends Resource
@export var display_name: String
@export var terrain: PackedScene          # or a seeded generator id
@export var time_limit_s: float = 20.0
@export var fitness: Resource             # EvolutionEngine.FitnessSpec
@export var success: Resource             # criteria (reach finish, survive, distance>=X)
```
- `scripts/sim/challenge_runner.gd` -- spawn terrain + a `CreatureBody`, drive with
  `CpgController`, evaluate against `success`/`fitness`. Used headless (evolution) AND
  live (the player watching).

**Acceptance:** the same `ChallengeDef` run headless and run live produce the same
verdict for the same seed; a champion evolved on "flat sprint" measurably underperforms
on "rough terrain" (challenges discriminate); adding a challenge is a new resource, no code.

**Pitfalls:** hard-coding the flat plane so challenges cannot vary; terrain colliders that
let the solver tunnel at speed (use continuous CD or thicker colliders); coupling the
runner to the editor (it must run headless for evolution).

---

# M8 -- Core Game Loop & First Playable Mode

**Why now:** the engine exists (author, breed, simulate, challenge). M8 is where it
becomes a *game* -- a loop the player drives with stakes and progression.

**Depends on:** M1 (library), M3 (breeding), M4-M5 (watchable bodies), M7 (challenges).

**Key decisions -- the genre fork (resolve against `docs/DESIGN.md`):**
- **Sandbox / optimizer** -- the player breeds and tunes creatures to beat a gauntlet of
  challenges; progression = unlocking parts/dials/harder gauntlets. Lowest risk; leans
  entirely on M1-M7; ships soonest. *Recommended first mode.*
- **Competitive / arena** -- creatures face *each other* (race or fight); progression =
  ladder/tournament. Higher fidelity demand, needs M9 for fights. More compelling, more risk.
- These are not exclusive: ship the sandbox gauntlet first, layer arena on top.

**First playable (recommended): the Locomotion Gauntlet.**
Design or breed a creature -> enter it in an ordered set of `ChallengeDef`s -> watch it
run live (M4/M5) -> pass/fail + a score -> earn currency/unlocks -> iterate. Every piece
already exists by M7; this mode is mostly UI + a progression spine.

**Files & sketch:**
- `scripts/game/game_state.gd` (autoload) -- player's creature roster, currency, unlocked
  parts/challenges, run history. Persisted like the library (M1 patterns).
- `scenes/game/` -- main menu, gauntlet map, run/spectate scene, results.
- `scripts/game/progression.gd` -- reward curve, unlock gates (data-driven).

**Acceptance:** a player can take a creature from the editor/library, run a gauntlet
live, get a result, spend a reward to unlock something, and that state persists across
restart; the loop is closed (design -> run -> reward -> better design).

**Pitfalls:** building the loop before the fork is decided (you will rework UI) -- pin the
mode against DESIGN.md first; progression numbers hard-coded (make them data); a "watch"
scene that re-derives physics differently from the headless runner (share `ChallengeRunner`).

---

# M9 -- Conflict / Interaction Systems (vitals & damage)

**Why now (and IF):** the genome already carries the latent vocabulary of conflict --
`tags` like `attack`/`heart`/`brain`, plus `weak_points` and `debt` from `evaluate()`.
If DESIGN.md's vision includes creatures *fighting* or *surviving* threats, this turns
that latent data into mechanics. If the vision is pure locomotion-sandbox, M9 is deferred
or dropped. **Confirm the intent before building.**

**Depends on:** M4 (bodies that can contact/strike), the evaluator's `weak_points` and
`debt` (structural failure points), and the `attack/heart/brain` tag semantics
(confirm how the evaluator currently treats them -- trait scoring vs. functional role).

**Key decisions:**
- *Vitals* -- parts tagged `heart`/`brain` are vital; destroying/disabling them
  incapacitates the creature. Map them to functional state, not just trait bonuses.
- *Damage* -- `attack`-tagged parts deal damage on contact; `debt`/`weak_points`
  define where a creature structurally fails under load/impact. Reuse the analytic
  structural model rather than inventing a parallel HP system.
- *Incapacitation* -- a clear, readable lose condition (vital destroyed, or fell and
  cannot recover within T). Drives arena outcomes (M8 competitive).

**Files & sketch:**
- `scripts/sim/vitals.gd` -- maps tagged parts to vital state on a `CreatureBody`;
  raises `incapacitated` when a vital is lost.
- `scripts/sim/combat.gd` -- contact -> damage resolution using attack tags +
  `weak_points`; integrates with `ChallengeRunner` for arena challenges.

**Acceptance:** a creature whose `heart` part is destroyed becomes incapacitated and
loses; an `attack`-heavy creature defeats a defenseless one in an arena challenge;
damage concentrates at the `weak_points` the evaluator already identifies (mechanics
agree with the analytic structural model, I2).

**Pitfalls:** inventing a second HP/structure model that contradicts `debt`/`weak_points`
(reuse the analytic one); unreadable deaths (telegraph vital loss); combat that only works
live and not in headless evaluation (keep it runnable in the sim rollout).

---

# M10 -- Content Pipeline & Production Polish

**Why now:** by M9 the systems exist; M10 makes it a *product* and is partly ongoing
from M1. Bundle the deferred "real art / real content / real robustness" work here.

**Depends on:** the `PartMeshProvider` seam (deferred art slot), `PhysicsDescriptor`
(authored measured physics; `null` = primitive today), `PartCatalog`, save versioning (M1).

**Scope (each can ship independently):**
- **Authored part meshes** -- replace primitive `PartMeshProvider` output with real
  meshes (the Geometry-Nodes / authored-mesh seam the bootstraps deferred). The evaluator
  still scores from analytic `dims`, so meshes can be visual-only first.
- **Descriptor authoring** -- a UI/flow to author `PhysicsDescriptor` for non-primitive
  parts (measured volume/SA/CoM/mass), so authored parts get accurate physics. This is
  the F2 "Lane B" the haircut already supports.
- **Catalog expansion** -- more part types, dials, presets; `PartCatalog` as real content.
- **Save migration & versioning** -- robust `schema_version` chains (M1) as the genome
  format evolves; never strand a player's creatures.
- **Performance budgets** -- evolution throughput, live-sim part-count ceilings, library
  thumbnail caching; profile and set limits.
- **UX & onboarding** -- first-run tutorial, editor affordances, accessibility.
- **2-DoF joint re-entry** -- the D1-LOCKED `hinge_axis_2` work, *only* when a creature
  whose core identity demands a true second axis appears; route through a Foundry pass
  (a 2nd drive angle, a phase relation, a lateral-thrust probe term, and a HARD L4 proof
  that `hinge_axis_2 == ZERO` stays byte-identical to the 1-DoF path).

**Acceptance:** per-item -- authored meshes render with analytic scoring unchanged;
authored descriptors flow through the F2 haircut correctly; an old save migrates forward;
a stated perf budget is met and enforced in a test.

**Pitfalls:** letting authored meshes silently change analytic results (I2 -- analytic
scoring stays `dims`-based); a save-format change with no migration (data loss); building
2-DoF before a creature actually needs it (D1 LOCKED -- do not free-hand it).

---

## Sequencing summary

```
M1 Library ---------+--> M3 Evolution --(champions)--+
                    |        ^                         |
M2 Mutation --------+        | fitness                 v
                             |                    M8 Game Loop --> M9 Conflict
M4 Body --> M5 CPG --> M6 Reconcile --> M7 World ---^                 |
   (de-risk early)        (trust oracle)                              v
                                                              M10 Content/Polish (ongoing)
```

- **M1 + M2** can be built in parallel (both sim-independent).
- **M3** needs M1+M2 and the existing probe -- ship it for the early payoff.
- **M4** is the big spike; start it as soon as M3 is rolling (do not wait).
- **M5->M6** make the live layer trustworthy; **M7->M8** make it a game; **M9** adds
  stakes (vision-dependent); **M10** is the long tail.

## Global non-goals / explicitly later

- Networked/multiplayer arena (single-player loop first).
- ML-based controllers are not required for M1-M10. Later BR14A work may add a
  bounded learned residual, specialist-to-student distillation, or an optional
  morphology-conditioned world model only after deterministic locomotion
  semantics, coverage receipts, and cross-engine conformance exist.
- A second physics DoF before a creature demands it (D1 LOCKED).
- Catalog-resolved load as the default save path (embedded stays primary until a shared
  part-def library is a real need).
- Pretty art before the loop is fun (M10 art is visual-only over an unchanged analytic core).

## Post-M10 locomotion platform direction

The game remains the first consumer, but the locomotion work should not be
permanently welded to one game engine. The planned boundary is:

```text
SporeSpore/Godot -> Godot/Jolt adapter -> engine-neutral locomotion core
                                      -> canonical actuation and receipts
```

The same core must later run through a materially different physics adapter
before "engine-neutral" becomes a verified claim. The game bootstrap continues
to own playable-loop sequencing; the SDK bootstrap owns portable morphology,
controller, adapter, learned-layer, conformance, and evidence semantics.
