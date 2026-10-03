# M1–M6 Implementation Bootstrap (Editor → Trustworthy Live Sim)

> **Companion to `docs/GAME_BOOTSTRAP.md`.** That doc is the strategic *map* of M1–M10.
> This one is the **executable plan for M1–M6**: verified signatures, real file paths,
> what is built-from-scratch vs edited, the difficulties I actually expect, and the
> test-as-you-build commitment. Every signature below was confirmed by reading the file
> named — but **re-confirm before you code** (the repo is the source of truth; signatures
> drift).

## Two corrections to the strategic doc (found by reading the code)

1. **`creature_frames.gd` is ALREADY extracted.** GAME_BOOTSTRAP says M4 is "finally when
   `creature_frames.gd` gets extracted." It already exists (it was extracted during the
   editor's gizmo phase): `scripts/creature/creature_frames.gd` exposes
   `CreatureFrames.child_world(parent_world, socket) -> Transform3D`,
   `accumulated_scale(parent_scale, gene_scale)`, `dims_for(defn, scale)`,
   `com_world(world, defn, scale)`. **M4 reuses it; nothing to extract.**
2. **Physics is NOT on Jolt yet.** `project.godot` has no physics-engine setting → it runs
   on **Godot Physics**. M4's first task is enabling Jolt (see M4).

## Standing surface this all builds on (verified)

| API | File | Signature (confirmed) |
|---|---|---|
| Evaluator | `scripts/core/CharacteristicsEvaluator.gd` | `evaluate(root) -> Dictionary` keys incl. `cog,total_mass,balance,speed{value,drivers},debt,weak_points,probe,reconciliation,status`; `fold_graph(root,xform) -> {parts:[ResolvedPart],...}` |
| Probe (M5) | same | constants `F_BASE=0.30, CPG_AMPLITUDE=0.6, PROBE_FREQ=60, GOLDEN, MUSCLE_BASELINE_CAP=2.0, MUSCLE_TORQUE_K=60.0`; `_probe_once` drive: `f=F_BASE*sqrt(GRAVITY/br)`, `target=rest+amp*CPG_AMPLITUDE*sin(phase_t)`, RoM clamp, torque cap; `reconcile()->{stability_class,locomotion_stable,message}` |
| Snapshot | `scripts/core/genome_snapshot.gd` | `GenomeSnapshot.deep_copy(root)->PartGene` (de-aliases every `PartGene` + mutable sub-resource; keeps shared-immutable `PartDefinition` by reference; has a visited guard that skips repeated/cyclic genes), `validate_unique(root)->{ok,error}` |
| Frame law | `scripts/creature/creature_frames.gd` | `CreatureFrames.child_world / accumulated_scale / dims_for / com_world` |
| IO | `scripts/editor/creature_io.gd` | `CreatureIO.save(card,path)->Error`, `load(path)->CreatureCard`, `scan(dir,builtins)->Array[Dictionary]{name,path,card,builtin}` |
| Card | `scripts/editor/creature_card.gd` | `CreatureCard{display_name, root, schema_version, notes}` |
| Catalog | `scripts/editor/part_catalog.gd` | `PartCatalog.built_in_cards()` (clone source for "add part") |
| Scheduler | `scripts/core/score_scheduler.gd` | `ScoreScheduler.request/take_pending/accept/run_pending_blocking` (the WorkerThreadPool happens-before pattern) |
| Genome | `scripts/core/part_gene.gd` | `PartGene{definition,descriptor,tags,socket,scale,children,joint,gait,part_id,socket_id,dial_values}` |

**New directory:** M2–M6 live in **`scripts/sim/`** (does not exist yet — create it).

## Invariants carried through all six (from GAME_BOOTSTRAP §Cross-cutting)
- **I2 evaluator authority:** analytic numbers come only from `evaluate()`; measured-from-sim
  numbers are a *separate labeled channel*. Never blend.
- **I3 snapshot isolation:** mutation/evolution/"load into sim" operate on
  `GenomeSnapshot.deep_copy` and pass `validate_unique` before use.
- **I4 determinism:** every stochastic system takes an explicit `int` seed and a local
  `RandomNumberGenerator`; never the global RNG. "Replay this lineage" must be exact.
- **I5 parallelism:** population eval reuses the F5 `ScoreScheduler`/`WorkerThreadPool`
  pattern (evaluate on workers, accept on main, drop stale).

## Test/commit discipline (non-negotiable)
- Current suite: **11 files, 172 tests, all green.** Keep it green at every commit.
- Each milestone's new logic **adds its own headless test** to `tests/` (the existing
  `extends SceneTree` + `_check` pattern — copy `tests/test_genome_snapshot.gd`).
- After adding any `class_name`, run the headless re-register pass before tests:
  `godot --headless --path . --editor --quit` (then run the suite).
- **Commit at every green**, descriptive message. M5 is the only milestone I'd split into
  two commits (the risky core refactor, then the new code).

---

# M1 — Creature Library & Persistence Hardening

**Goal:** creatures become durable, *versioned* assets with a browser; loads are validated
and migrated, never half-parsed.

**Build vs edit**
| File | New/Edit | What |
|---|---|---|
| `scripts/editor/creature_io.gd` | **EDIT** | add a `schema_version` gate + migration call to `load()` (today it deep-copies regardless of version) |
| `scripts/editor/creature_migrations.gd` | **NEW** | `const CURRENT := 1`; `{version: Callable(card)->card}` chain; `migrate(card)->card` |
| `scripts/editor/creature_library.gd` | **NEW** | in-memory corpus over `CreatureIO.scan`: `all()/by_name()/add(card)/remove(path)/refresh()`, `changed` signal; lazy-loads non-builtin cards via `CreatureIO.load(path)` |
| `scenes/editor/library_panel.tscn` + `scripts/editor/library_panel.gd` | **NEW** | browser: select→`open_card`, delete-with-confirm, duplicate, rename |
| `scripts/editor/bench.gd` | **EDIT (small)** | wire `library_panel.open_card` → load into the existing `EditSession` |
| `tests/test_creature_library.gd` | **NEW** | + extend `tests/test_creature_io.gd` |

**How.** Keep **embedded save** (the editor's ruling). The new safety is the version gate:
`load()` reads `card.schema_version`; `> CURRENT` → reject (push_error, return null, no
crash); `< CURRENT` → run the migration chain to CURRENT; `== CURRENT` → proceed.
Default `CreatureIO.load()` should stay **strict**: validate the migrated root before
isolating it, then return a `GenomeSnapshot.deep_copy(card.root)` only after validation
passes. This keeps app-authored assets loud and deterministic: malformed topology is rejected,
not silently normalized.

If foreign/hand-authored `.tres` import becomes a product requirement, add an explicit import
path (`load_import_repaired(path)` or a clearly named mode), not hidden behavior in normal
`load()`. That import path may de-alias shared mutable sub-resources (`SocketDef`, `JointDef`,
`GaitDef`, `PhysicsDescriptor`) by copying before the final validation pass. It must still
reject reused/cyclic `PartGene` instances: `deep_copy`'s visited guard skips repeats, which
would truncate the topology rather than repair it.

**Difficulties / issues**
- **Strict vs repair is a product decision, not a hidden implementation detail.** App-produced
  assets should remain strict because `save()` already validates and de-aliases before writing.
  Foreign import can be lenient for mutable sub-resource aliases, but must never treat
  repeated/cyclic `PartGene` truncation as repair.
- **`deep_copy` already has a visited guard.** Do not spend M1 rebuilding that. The remaining
  hardening is policy and tests: validate-before-copy for strict load; explicit repair-only
  behavior for import load if you choose to support it.
- **Migration correctness:** each step must be idempotent and tested against a *real*
  old-version fixture `.tres`, not a synthetic one.
- **Thumbnails** on the main thread will hitch a big library — generate lazily/off-thread or
  cache to disk (defer the off-thread part; lazy is enough for M1).

**Tests (commit-gated)** — `tests/test_creature_library.gd` (+ extend `test_creature_io.gd`):
- round-trip ~20 hand-authored creatures `save→scan→load`, each deep-equal to source
  (reuse `test_genome_snapshot.gd`'s `_struct_eq`) and `validate_unique` ok;
- a `schema_version > CURRENT` card is rejected (load→null, no crash); a `< CURRENT` fixture
  migrates to CURRENT and equals the expected tree;
- strict load rejects a raw `.tres` with a reused `PartGene` or shared mutable sub-resource;
  if an explicit import-repair path is added, it de-aliases shared mutable sub-resources while
  still rejecting reused/cyclic `PartGene`;
- library `add/remove/refresh` reflect `scan`; delete removes the file; rename moves it.
- **Commit:** `M1: versioned/migrating persistence + creature library + browser`.

---

# M2 — Genome Mutation Operators

**Goal:** seeded, guard-railed mutation + crossover on the `PartGene` tree. Pure data — no
physics, no UI. This is the raw material for M3.

**Build vs edit** — **purely additive** (no edits to existing code):
| File | New/Edit | What |
|---|---|---|
| `scripts/sim/genome_mutator.gd` | **NEW** | `class_name GenomeMutator`; inner `Config`; `static mutate(parent,cfg,rng)->PartGene`; `static crossover(a,b,cfg,rng)->PartGene` |
| `tests/test_genome_mutator.gd` | **NEW** | determinism, validity, clamps, evaluator fuzz |

**How.** Every operator: `deep_copy(parent)` first (I3) → apply ops using **only the passed
`rng`** (I4) → clamp → `validate_unique` → identity-fallback `deep_copy(parent)` on failure.
Operator set (start cheap/high-yield):
- **param jitter** — Gaussian (`rng.randfn`) on `scale`, `socket.parent_attachment` pose,
  `joint.{amplitude,rest_angle,angle_min,angle_max}`, `dial_values`.
- **topology** — add a child (clone a `PartCatalog` template with **FRESH sub-resources**),
  remove a sub-tree, duplicate a sub-tree onto a new socket.
- **gait** — perturb `gait.assignments[socket_id]` phases. Do not spend a mutation draw on
  `GaitDef.pattern` by itself yet: the current probe reads only `assignments`, so a pattern-only
  change has zero fitness effect and only adds lineage noise. If you add pattern re-rolls,
  rewrite `assignments` to that pattern's canonical phase set in the same operation.
- **clamps** — `scale > 0`; RoM stays `amax >= amin` (or disabled); gait phases are stored as
  cycle fractions and wrap with `wrapf(phase, 0.0, 1.0)`, not radians.

**Difficulties / issues**
- **Add-part aliasing:** cloning a catalog template must create a fresh `PartGene` and fresh
  mutable sub-resources. Shared `PartDefinition` is allowed and expected: it is immutable
  catalog data and `validate_unique` intentionally exempts it. Use `GenomeSnapshot.deep_copy`
  on the template subtree before grafting; that preserves shared `PartDefinition` correctly.
- **Where to attach / which socket:** "add a child" needs a parent gene *and* a `SocketDef`.
  Synthesize one with `CreatureFrames.spine_socket(parent, id, z_fraction, side, hinge_axis)`
  (already exists) or a default socket — don't hand-build transforms.
- **Crossover chimeras:** sub-tree swap is powerful but illegal-prone; gate behind
  `validate_unique`, keep the rate low at first.
- **Unbounded drift** → degenerate giants/specks the probe scores absurdly. Clamp *early*,
  every op, every commit.
- **Determinism:** local `rng` only; same seed → byte-identical offspring (the headline test).

**Tests (commit-gated)** — `tests/test_genome_mutator.gd`:
- same seed → byte-identical offspring (deep-equal via `_struct_eq`); different seed → differs;
- every operator's output passes `validate_unique`;
- clamps hold across 1000 mutants (no `scale<=0`, no inverted RoM, phases in range);
- **fuzz:** `evaluate()` runs on 1000 random mutants with no NaN / no crash (doubles as an
  evaluator fuzz test).
- **Commit:** `M2: seeded genome mutation + crossover operators`.

---

# M3 — Evolution Engine (analytic fitness)

**Goal:** population → select → mutate loop scored by the existing probe, parallel, with
lineage. The first genuinely compelling demo (a population learning to "walk"), and the
stress-test that surfaces probe exploits (→ M6's backlog).

**Build vs edit**
| File | New/Edit | What |
|---|---|---|
| `scripts/sim/evolution_engine.gd` | **NEW** | `class_name EvolutionEngine`; inner `FitnessSpec`(Resource: `speed_w,debt_w,require_stable,score(eval)->float`); `step(pop,spec,cfg)->Array`; `_evaluate_population(pop)->PackedFloat32Array` (WorkerThreadPool) |
| `scripts/sim/lineage.gd` | **NEW** | parent→child edges + per-gen best fitness (replayable history) |
| `scripts/sim/run_evolution.gd` | **NEW** | `extends SceneTree` headless entry: sweep generations, dump champion as a `CreatureCard` into `data/creatures/` (M1) |
| `tests/test_evolution_engine.gd` | **NEW** | determinism, improvement, parallel==serial |

**How.** Simple generational GA: elitism + tournament selection + `GenomeMutator.mutate`
(crossover optional/low-rate). Fitness is a weighted scalar over `evaluate()` outputs
(`speed.value` reward, `balance.stable` gate, `debt.debt_total` penalty) — **make weights
data** (`FitnessSpec` resource) so M7 challenges reweight. Parallel eval reuses the I5
pattern: `evaluate()` is static + pure → dispatch a generation across
`WorkerThreadPool.add_task`, `wait_for_task_completion`, collect (exactly what
`ScoreScheduler.run_pending_blocking` already does — copy it). Pass workers **deep_copies**,
never live pop members (I3/I5).

**Difficulties / issues**
- **Determinism (I4):** global RNG or thread-order-dependent accumulation breaks replay.
  Local `rng`; **sort by a stable key before any reduction**. A canonical genome signature is
  useful for lineage, dedupe, and replay logs, but do **not** make fitness memoization a v1
  dependency: `evaluate()` is cheap, and a bad signature/cache key would silently return the
  wrong fitness.
- **Cold-start stability gates:** a hard `require_stable` gate on a mostly-unstable gen-0
  population can flatten fitness to ~0 everywhere, leaving no selection gradient. Prefer a
  graded stability penalty early, then harden into a gate once the population has enough
  upright candidates for selection to work.
- **Probe exploits:** the population *will* converge on a cheese strategy that games the
  probe. **Record it — it is M6's calibration to-do list.** Do not pre-engineer novelty
  pressure; add it only if collapse kills the demo.
- **Thread-safety of `evaluate()`:** it allocates `RefCounted` `ResolvedPart`s (thread-local,
  fine) and reads an immutable snapshot — safe *iff* each worker gets its own deep_copy.
- **The proxy caveat:** champions are "good *by the probe*," not measured-good. That gap is
  the entire reason M4–M6 exist; don't paper over it here.

**Tests (commit-gated)** — `tests/test_evolution_engine.gd`:
- fixed-seed sprint `FitnessSpec` → best-seen-so-far fitness is non-decreasing because elitism
  is guaranteed, reproducibly (same seed → identical lineage);
- a saved champion re-loads (M1) and re-scores **identically**;
- a 200-creature generation evaluated across workers yields **identical** results to
  single-threaded (determinism across thread count). Record/print timing as a diagnostic, but
  do not fail the test on wall-clock speed.
- **Commit:** `M3: analytic-fitness evolution engine + lineage + headless runner`.

---

# M4 — Articulated Runtime (live physics body)

**Goal:** genome → `RigidBody3D` parts + hinge joints (Jolt), placed by the shared frame law.
The biggest technical unknown; de-risk it as an isolated headless spike.

**Build vs edit**
| File | New/Edit | What |
|---|---|---|
| `project.godot` | **EDIT (first)** | enable Jolt: `[physics] 3d/physics_engine="Jolt Physics"` — **confirm the exact value string** in this 4.7-mono build (Jolt is a built-in module since 4.4) |
| `scripts/sim/creature_body.gd` | **NEW** | `class_name CreatureBody extends Node3D`; `static build(root, root_xform)->CreatureBody`; `part_bodies()->Array` (fold-order aligned, for M5); `measure()->Dictionary` (CoM/contacts, for M6) |
| `tests/test_creature_body.gd` | **NEW** | headless physics test |

**How.** Do M4 in two gates.

**M4.0 one-box physics proof:** before building `CreatureBody`, create a headless test scene
with one `RigidBody3D` box above a static floor, step fixed ticks, and assert it falls,
contacts/settles, and produces no NaN/explosion. This proves Jolt enablement and the headless
physics stepping pattern before the genome body code exists.

**M4.1 creature construction:** `fold_graph(root)` gives placement. Per `ResolvedPart` in the
first implementation: a `RigidBody3D` + a `CollisionShape3D`
(`BoxShape3D/SphereShape3D/CylinderShape3D/CapsuleShape3D`) sized from `p.dims`,
`transform = p.xform` (the frame law, via `CreatureFrames`), and **`mass = p.mass`** from
`fold_graph`. Do not recompute `density * volume(dims)` here: descriptor-backed parts carry
their own integrated mass, and recomputing would drift from `evaluate()["total_mass"]` (I2).
Per socket: `HingeJoint3D` about the world-space `hinge_axis` if non-zero, else a fixed joint
(`Generic6DOFJoint3D` with all axes locked). `hinge_axis_2` is **reserved/undriven — do not
wire a 2nd DoF (D1 LOCKED).** Disable collision between directly-jointed neighbors
(`add_collision_exception_with` or layer/mask). Spawn a hair above ground and step N fixed
ticks to settle before any control.

Treat one-body-per-part as the first construction model, not necessarily the final runtime
topology. Before serious M5 tuning, consider fusing rigid sub-chains (`hinge_axis == ZERO`)
into compound bodies and creating real hinges only at actual articulation points. If that
fusion lands, the permanent invariant becomes mass-sum parity + hinge-count-at-articulations,
not body-count parity with `fold_graph`.

**Difficulties / issues**
- **Jolt enablement + headless physics:** confirm the setting works in 4.7-mono *and* that
  physics steps headless. This also **changes the test pattern** — M4+ tests must *step the
  physics server* (a manual fixed-step loop or a minimal scene), not just call pure functions
  like every test so far. De-risk this on day one.
- **Self-collision explosion** (the #1 ragdoll bug): jointed neighbors overlap at the socket;
  without exceptions the solver explodes on frame 1.
- **Mass mismatch** sim vs oracle → use `ResolvedPart.mass` exactly. Primitive parts already
  encode `density*volume`; descriptor-backed parts do not.
- **Hinge-axis frame:** `hinge_axis` is in the socket's frame; transform it to world for
  `HingeJoint3D` or the joint spins about the wrong axis.
- **Scale (I1):** size lives in the collision shape's dims, **never** `Node3D.scale`.
- **Solver cost** for high part counts → a perf budget (M10), not now.

**Tests (commit-gated)** — `tests/test_creature_body.gd` (headless, steps physics):
- M4.0: one box falls, contacts/settles on a static floor, and does not NaN/explode under
  headless fixed-step physics;
- M4.1 first construction gate: body part count == `fold_graph` part count only while using
  the one-body-per-part model; live total mass == `evaluate()["total_mass"]` within tolerance
  (the I2 consistency check);
- initial acceptance is construction + mass parity + N ticks no-NaN/no-explosion. Stable-stands
  and unstable-topples are a second gate after the basic physics body is proven;
- no NaN / no explosion on spawn.
- **Commit:** `M4: articulated physics body (Jolt) from genome`.

---

# M5 — CPG Locomotion Controller

**Goal:** drive the hinges with the **same** CPG model the probe scores, so the live motion
is comparable to the analytic verdict (which M6 then measures).

**Build vs edit**
| File | New/Edit | What |
|---|---|---|
| `scripts/core/CharacteristicsEvaluator.gd` | **EDIT (high-risk)** | extract the per-joint CPG target math out of `_probe_once` into shared static helpers (`cpg_frequency(body_radius)`, phase resolution, `cpg_target(...)` with RoM clamp, and torque-cap calculation). **Must stay byte-identical** (the 49 golden tests are the guard). |
| `scripts/sim/cpg_controller.gd` | **NEW** | `class_name CpgController`; `bind(body, root)`; `tick(t, delta)` (per driven hinge: shared `cpg_target(...)` → motor/PD, torque-capped) |
| `tests/test_cpg_controller.gd` | **NEW** | tracking, translation, controller-off |

**How.** Drive law (literal transcription of `_probe_once`, now *shared* so they can never
drift): `freq = F_BASE*sqrt(GRAVITY/br)`;
`phase_val = fmod(gait.assignments[socket_id] * TAU + phase_perturb, TAU)` when assigned;
golden-angle fallback `phase_val = fmod(float(j) * GOLDEN + phase_perturb, TAU)` when
unassigned; `phase_t = TAU * freq * t + phase_val`; `target = rest_angle + amplitude *
CPG_AMPLITUDE * sin(phase_t)`; target clamped to `[angle_min, angle_max]` when RoM is enabled;
torque capped by the E3 muscle ceiling (`MUSCLE_BASELINE_CAP + MUSCLE_TORQUE_K *
_subtree_muscle_frac`). M5a must preserve the literal float operation order from `_probe_once`
-- including `fmod(..., TAU)` -- because mathematically equivalent reductions can shift the
last bits of `sin()` and break byte-identical golden results. Actuation: start with
`HingeJoint3D` angular **motor** (target velocity toward the desired angle); upgrade to PD
torque only if you need finer control. Drive from **`_physics_process`** at the fixed tick.

The shared helper guarantees the **commanded target angle** matches between probe and
controller. It must not try to share the probe's point-mass locomotion loop (`stance`,
surrogate thrust, fake friction, explicit-Euler integration). Live motion uses Jolt contact and
will legitimately differ; M6 measures that difference.

**Difficulties / issues**
- **The evaluator refactor is the single riskiest edit in M1–M6** — you're touching the
  hardened 1400-line core. Extract *pure math only*, no behavior change; the 49 golden tests
  must stay byte-identical. Do this as its **own commit** before writing the controller.
- **Drift between controller and probe** → the shared helper is the whole point; never copy
  the target-angle formula into the controller, and do not "simplify" the helper into textbook
  math during M5a. `fmod(..., TAU)`, cast points like `float(j)`, and operation order are part
  of the byte-identical contract.
- **Motor gains too high** → solver fights itself (jitter/explode); tune.
- **Ignoring the torque ceiling** → weak creatures move like strong ones, defeating the muscle
  model.
- **Probe is a point-mass surrogate; the live body has ground contact/friction the probe
  ignores** → the visible gait *will* differ from the probe's prediction. **That is expected
  and is exactly what M6 measures — do not force agreement here.**

**Tests (commit-gated)** — `tests/test_cpg_controller.gd` + the golden suite:
- the extracted helper leaves the **49 golden tests byte-identical** (the refactor guard);
- direct helper tests assert assigned phases use cycle fractions (`assignment * TAU`) and
  unassigned joints use the golden-angle fallback;
- a probe-strong-walker **translates forward** under CPG drive over a fixed horizon;
- killing the controller → it stops/collapses;
- driven joint angles track the commanded sinusoid within tolerance.
- **Commits (two):** `M5a: extract shared CPG helper (probe byte-identical)`, then
  `M5b: CPG locomotion controller drives the live body`.

---

# M6 — Measured Fitness & Reconciliation

**Goal:** prove (or correct) that the cheap analytic oracle predicts reality. Fills the
hybrid's verify-layer and the *measured* side of `reconciliation`. This is the milestone that
answers the project's central question: **is the probe a trustworthy fitness function?**

**Build vs edit** — additive (no evaluator edit; the analytic `reconciliation` stays):
| File | New/Edit | What |
|---|---|---|
| `scripts/sim/sim_rollout.gd` | **NEW** | `class_name SimRollout`; `static run(root, horizon_s, seed)->Dictionary` — build `CreatureBody`, settle, drive with `CpgController`, integrate fixed ticks, return **MEASURED** `{distance,stability,energy,fell,...}` |
| `scripts/sim/reconcile.gd` | **NEW** | given `evaluate(root)` + `SimRollout.run(root)` → per-metric deltas + aggregate fidelity (MEASURED vs ANALYTIC, labeled separate — I2) |
| `tests/test_sim_rollout.gd`, `tests/test_reconcile.gd` | **NEW** | reproducibility, correlation, channel separation |

**How.** Measured = run the live sim headless for a fixed horizon and record forward
**distance**, CoM-path **stability**, **energy** (torque integral), **fall time** — the
ground-truth analogues of `speed.value` / `balance` / `debt`. Reconcile = per-metric error,
exposed as a **separate labeled channel**; never overwrite analytic numbers (I2). Optional
*calibration* (valuable, defer): fit the probe's free constants (`CPG_AMPLITUDE`, torque
coefficients) to minimize measured-vs-analytic error across a corpus — but that edits tuned
constants, so it's gated behind a golden re-tune (a deliberate, separate effort).

**Difficulties / issues**
- **The headline risk:** measured ranking may *not* correlate with analytic ranking. If so,
  **that is the finding**, not a bug — it's the calibration backlog, and it's the moment the
  "analytic-primary hybrid" bet is actually tested.
- **Don't treat measured as "more correct"** and silently replace analytic (I2 — different
  channels with different trust).
- **Solver determinism:** fix the tick rate, seed any variation; Jolt is same-binary
  deterministic but pin substeps so a rollout replays.
- **Apples-to-oranges:** measured *distance* vs analytic *speed* — normalize by horizon.
- **Cost:** a live rollout is seconds/creature — it **cannot** run at population scale. M6 is a
  verify-the-champion layer; **analytic stays primary** as M3's fitness.

**Tests (commit-gated)** — `tests/test_sim_rollout.gd`, `tests/test_reconcile.gd`:
- `SimRollout.run` is reproducible for a fixed seed (bit-identical, or within a stated tol);
- across a small corpus, a diagnostic script prints Spearman/Kendall correlation between
  measured ranking and analytic ranking. The first M6 test should record the number as a
  baseline, not fail on a guessed threshold. Pin a threshold only after the baseline corpus
  exists and the expected fidelity is known;
- the reconciliation channel is structurally separate from analytic stats.
- **Commit:** `M6: headless sim rollout + measured-vs-analytic reconciliation`.

---

## Sequencing & the four risks to watch

```
M1 Library --+--> M3 Evolution (early payoff) --(champions)--> [M7+ game]
M2 Mutation -+        ^ fitness = probe
M4 Body --> M5 CPG --> M6 Reconcile  (make the live layer trustworthy)
```
- **M1 + M2 are independent and sim-free — build them in parallel.**
- **M3** ships the first wow as soon as M1+M2 land (the probe already exists).
- **M4** is the big spike — start it the moment M3 is rolling; don't wait for M3 to finish.
- **M4.0 is the first blocker by urgency** even though probe-as-proxy is the biggest eventual
  product/science risk. Prove headless Jolt before investing heavily in live-body logic.
- **M5 → M6** turn "it moves" into "the oracle is trustworthy."

**The four risks, ranked:**
1. **Probe-as-proxy (M3→M6).** The project's central scientific bet. M3 finds the exploits;
   M6 tells you if the oracle is trustworthy. Everything downstream rides on M6's correlation
   number.
2. **The M5 evaluator refactor.** The only edit that touches the hardened core; the 49 golden
   tests are the seatbelt. Separate commit, byte-identical, no behavior change.
3. **Jolt + headless physics (M4).** New test pattern (stepping the physics server). De-risk on
   day one — a body that won't even spawn-and-stand blocks M5/M6.
4. **Determinism discipline (I4) everywhere.** Local RNG, stable-key sorts, fixed ticks.
   "Replay this lineage exactly" is the bar; a single global-RNG call silently breaks it.

## What's new vs edited, at a glance
- **New dir:** `scripts/sim/` (genome_mutator, evolution_engine, lineage, run_evolution,
  creature_body, cpg_controller, sim_rollout, reconcile).
- **New editor files:** creature_library, creature_migrations, library_panel.
- **Edits to existing, hardened code (do carefully):** `creature_io.gd` (version gate),
  `project.godot` (Jolt), `CharacteristicsEvaluator.gd` (M5 shared CPG helper — golden-guarded),
  `bench.gd` (wire the library panel).
- **Reused as-is (confirmed):** `CreatureFrames` (frame law, already extracted),
  `GenomeSnapshot`, `ScoreScheduler`, `evaluate`/`fold_graph`, `PartCatalog`, `CreatureIO`.
