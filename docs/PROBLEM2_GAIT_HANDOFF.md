# LoColemotion -- Problem 2 (Joint & Gait Authoring) -- Handoff

Generated 2026-06-26 at the end of the gait-build session. Read this first. It is
self-contained: orientation, exact current schema, what landed, known gotchas, the 5-sprint
roadmap, the next 3 steps in detail, the Foundry-Design questions with hard deadlines, and the
decisions still owed by Cole.

> Update: the S1 loader gap called out below has since landed. `GenomeLoader.resolve()`
> now stamps sockets, `JointDef`s, and root `GaitDef`; `test_genome_loader.gd`
> proves the through-loader path. The B-IF surface-area seam has also been resolved
> by `docs/foundry/F2_RESOLVED.md` and `test_internal_face_authority.gd`.

---

## 0. Orientation (machine / paths / how to run)

- Dev: Cole, solo, Windows.
- Repo: <repo>
- Godot binary (mono console): <godot-dir>/Godot_v4.7-stable_mono_win64_console.exe
- Run the test suite (exit 0 = all pass):
  & "<godot binary>" --headless --path "<repo>" --script "res://tests/test_characteristics_evaluator.gd" 2>&1
  The trailing 2>&1 is required to capture the printerr FAIL lines. ObjectDB-leak warnings at
  exit are normal headless noise, not failures.

Core pieces:
- scripts/core/CharacteristicsEvaluator.gd -- pure-analytic morphology evaluator + a
  deterministic locomotion PROBE. RefCounted, all-static, ~1377 lines. The probe is ground truth
  for locomotion; the analytic stages are authoritative for mass/CoG/debt/traits/strength.
- tests/test_characteristics_evaluator.gd -- extends SceneTree, RELATIONAL/invariant tests
  (scale-invariance is the keystone). Currently 49 checks, all green.
- THE FRAME LAW (load-bearing invariant, never violated):
  child_world = parent_world * parent_attachment * child_anchor; scale is accumulated SEPARATELY
  and never baked into the transform.
- "L4" in this doc = scale-invariance / default-equivalence: adding a feature must not change an
  un-authored creature's numbers, and stats must stay identical under uniform scale.

---

## 1. What landed this session (Problem 2 = Joint & Gait authoring)

Locked fork set (Cole chose all): A1.5, B3, C2, D2, E3, F1.

| Fork | Decision | Implemented as |
|---|---|---|
| B3 | per-joint JointDef keyed by socket.id | scripts/core/parts/joint_def.gd; PartGene.joint; ResolvedPart.joint; PartResource.joints |
| C2 | creature-level GaitDef | scripts/core/parts/gait_def.gd; PartGene.gait; threaded evaluate -> run_probe -> _probe_once |
| D2 | rest + [min,max] RoM clamp (radians) | drive-loop clampf; disabled when angle_max <= angle_min |
| E3 | strength from &"muscle"-tagged mass | presence-toggle; tau_cap = (MUSCLE_BASELINE_CAP + MUSCLE_TORQUE_K * subtree_muscle_frac) * i_sub; helper _subtree_muscle_frac |
| A1.5 | optional 2nd hinge axis | SocketDef.hinge_axis_2 (field/door only; probe does NOT drive it yet) |
| F1 | reuse _subtree_inertia; don't fill descriptor.inertia_tensor | (no new inertia code) |

PHASE COLLISION RESOLVED: B3 and C2 both listed phase. Resolved by concern -- phase lives ONLY
in GaitDef.assignments (coordination); amplitude/rest/RoM live ONLY in JointDef (local).
Single-sourced. Drive per joint:
target = jointdef.rest_angle + jointdef.amplitude * CPG_AMPLITUDE * sin(phase_t + gaitdef.assignments[socket_id])
then D2 clamp to [angle_min, angle_max], then E3 clamp the PD torque to +/- tau_cap.

L4 PROVEN two ways: (a) code-level -- an un-authored leg uses the literal original golden-angle
phase expression, amp=1/rest=0, clamp off, tau_cap=INF -> byte-identical; (b) a test asserts
probe distance byte-identical at 1e-9, and all 8 original goldens stayed green.

TEST RESULT: 49 passed, 0 failed.

Files touched: created parts/joint_def.gd, parts/gait_def.gd; edited socket_def.gd,
part_gene.gd, parts/part_resource.gd, CharacteristicsEvaluator.gd,
tests/test_characteristics_evaluator.gd. Backups of the 5 edited files live at
<repo>/.bak_gait_20260626-011551/.


---

## 2. Exact current schema (so the next thread need not re-read source)

JointDef  (scripts/core/parts/joint_def.gd)  -- per-joint, null = engine default
  amplitude:  float = 1.0    # multiplier on CPG_AMPLITUDE
  rest_angle: float = 0.0    # radians
  angle_min:  float = 0.0    # radians
  angle_max:  float = 0.0    # radians; angle_max <= angle_min DISABLES the clamp

GaitDef  (scripts/core/parts/gait_def.gd)  -- creature-level, lives on ROOT PartGene, null = default
  pattern:     StringName = &"trot"                 # open registry (H1)
  assignments: Dictionary[StringName, float] = {}   # socket.id -> phase as CYCLE FRACTION [0,1)
                                                    # 0.0 in-phase, 0.5 antiphase; absent id -> golden default

SocketDef  (+1 field): hinge_axis_2: Vector3 = ZERO   # A1.5 door; NOT driven by the probe yet
PartGene   (+2 fields): joint: JointDef ; gait: GaitDef
PartResource (+1 field): joints: Dictionary[StringName, JointDef] = {}   # socket.id -> joint (loader stamps gene.joint)
ResolvedPart (+1 field): joint: JointDef                                  # persisted in _fold

CharacteristicsEvaluator constants added:
  MUSCLE_BASELINE_CAP := 2.0     # torque-per-inertia floor in the muscle regime
  MUSCLE_TORQUE_K := 60.0        # torque-per-inertia per unit subtree muscle-mass fraction
New static func: _subtree_muscle_frac(parts, root_idx) -> float   # dimensionless mass ratio, 0.0 if no muscle

Probe data flow: evaluate() reads root.gait -> run_probe(..., gait) -> _probe_once(..., gait).
In _probe_once: a creature-wide has_muscle flag (any &"muscle" tag) gates the torque clamp; each
leg resolves phase (authored cycle-fraction*TAU, else golden), amp/rest/amin/amax (from p.joint),
and tau_cap (INF unless has_muscle). Drive loop applies amp+rest, D2 clamp, E3 tau clamp.

---

## 3. Known findings & gotchas (read before touching the probe)

- PROBE DISTANCE IS NOT SCALE-INVARIANT (pre-existing, not a regression). Measured this session:
  legacy quad d/body_radius drift s1->s2 = 1.0e-2; authored = 7.3e-3 (authoring drifts LESS).
  Cause: the probe integrates a FIXED wall-clock window (PROBE_DRIVE_S seconds) with per-step
  friction (vx *= 0.98) while gait frequency is Froude-scaled (f ~ 1/sqrt(R)) -> bigger creatures
  complete fewer cycles per window. The scale-invariant CONTRACT is the VERDICT (+ balance margin
  / tip angle), which the harness asserts. Do NOT assert raw distance scale-invariance.
- The test surrogate quads return verdict no_translation at both scales (d/br ~ 0.01 << pass gate
  2.0). That is expected -- the harness only asserts verdict VALIDITY, not "passed".
- MUSCLE_BASELINE_CAP / MUSCLE_TORQUE_K are PLAYTEST KNOBS with no goldens. Correctness rides on
  the presence-toggle (INF cap when no muscle = exact L4); these only shape feel in the muscle
  regime. Tune freely; do not treat as load-bearing.
- hinge_axis_2 is authored-but-undriven. Setting it does nothing until 2-DoF probe dynamics exist.
- LOADER STAMP MISSING: PartResource.joints -> child gene.joint is NOT wired in the .tres loader.
  Tests build PartGene trees directly, so the probe path is proven, but authored .tres parts will
  not carry joints/gait until the loader stamps them (mirror how sockets[socket_id] -> gene.socket).
- tissue_map (on PartResource) is still declared but READ BY NOTHING. No &"muscle" tag exists in
  any shipped content yet -- E3 only fires on test/authored creatures that add the tag.
- BITE B-IF: for authored parts, adjust_internal_faces() computes the shared-face haircut from the
  bounding SKELETON dims (defn.extents), not the descriptor, so a descriptor's surface area is not
  perfectly authoritative for non-inert authored parts. This is the seam Sprint 3 must resolve.


---

## 4. Roadmap -- next 5 big sprints (PROPOSED; Cole steers priority)

S1. ROUND-TRIP & 2-DoF CALL. Wire the loader so PartResource.joints/gait reach the evaluator from
    authored .tres (not just hand-built test genes). Decide hinge_axis_2: drive 2-DoF or leave the
    door shut. Outcome: gait authoring is real end-to-end. Small, unblocks everything downstream.

S2. FOUNDRY-DESIGN SCHEMA: PRIMITIVE PROXY vs MESH INTEGRATION. The known big debate. Settle which
    source is canonical for each derived physic (mass/volume/SA/CoM/inertia) when a part has BOTH a
    definition skeleton AND a descriptor AND a mesh, and fix the B-IF internal-face seam. This is
    THE next architectural fork; route through Foundry.

S3. STRENGTH MODEL MATURATION. Turn E3 from presence-toggle + bare tag into a real strength model:
    decide tag-based vs tissue_map-backed (per-region contractile tissue), pin provisional goldens,
    wire the forced-evolution multiplier on the derived cap. Depends on S2's physics-authority call.

S4. PROBE FIDELITY / DISTANCE-AS-STAT. IF the game needs scale-invariant absolute travel distance,
    re-architect the probe to a FIXED-CYCLE-COUNT window (not fixed seconds) and re-baseline goldens.
    ELSE formally declare verdict-only the contract and close this out. Gate is the S4 question below.

S5. AUTHORING SURFACE + LIVE-SIM HANDOFF. The editor/assembler that builds genomes (sockets/joints/
    gaits) on the same frame law with .tres round-trip and a palette; then hook evaluator verdicts +
    stats into the actual in-game creature (the real physics body the probe was a surrogate for).

---

## 5. The next 3 big steps -- detail

STEP 1 -- Loader round-trip for joints + gait (S1 core).
  Goal: an authored creature loaded from .tres carries its JointDefs and GaitDef into evaluate().
  Where: the loader that turns PartResource sidecars into the PartGene tree (find it via search for
    "make_descriptor" / where SocketDef sockets[socket_id] -> gene.socket is resolved -- joints
    mirror that exactly). GaitDef is creature-level: it must be authored on / loaded onto the ROOT
    gene (root.gait). Confirm where the root genome is assembled.
  Acceptance: a relational test that builds a creature THROUGH the loader (not _gene helpers) and
    confirms gene.joint / root.gait are populated and the probe consumes them (verdict differs from
    a no-gait control). Keep all 49 existing checks green.
  Risk: low. Additive. The probe + schema already handle null gracefully (L4).

STEP 2 -- hinge_axis_2 decision, then act (S1 tail; needs Cole, see D1).
  If "leave door shut": add a one-line guard/warning if a non-zero hinge_axis_2 is authored, so it
    is not a silent no-op trap, and document it as H1. Done.
  If "drive 2-DoF": this is Foundry-Q3 -- do NOT free-hand the dynamics. The probe is a 1-DoF scalar
    hinge today (theta/omega, foot_v = -lever*omega). A 2-DoF model needs a second angle, a phase
    relation to the primary, a lateral thrust contribution, and must stay deterministic + L4 (ZERO
    second axis -> byte-identical to 1-DoF). Spec it through Foundry first.

STEP 3 -- Begin Foundry-Design schema fork (S2 kickoff).
  Produce the Foundry brief for "physics authority": enumerate, per derived quantity, the candidate
  sources (analytic-from-skeleton vs descriptor vs mesh-integrated) with bites, and the L4 / frame-law
  constraints each must satisfy. The deliverable of Step 3 is the DECIDED schema, not code. Code lands
  in a follow-up once the fork is locked (same pattern as Problem 2 this session).

---

## 6. Foundry-Design questions (complex code) + HARD DEADLINES

Q1 (PHYSICS AUTHORITY) -- When a part has definition-skeleton + descriptor + mesh, which is canonical
   for mass / volume / surface_area / center_of_mass / inertia? Today descriptor overrides analytic
   per-part in _fold, BUT adjust_internal_faces haircuts SA from the skeleton (bite B-IF), so SA is a
   hybrid. MUST be answered BEFORE S2/S3 code -- it IS S2's core question.

Q2 (TISSUE MODEL) -- Does the matured strength model consume tissue_map (per-region contractile
   tissue) or stay tag-based (&"muscle")? tissue_map is currently dead schema. MUST be answered
   BEFORE S3 (strength maturation) starts.

Q3 (2-DoF DYNAMICS) -- If hinge_axis_2 is driven, what is the deterministic, L4-safe 2-DoF probe
   model? MUST be answered BEFORE writing any hinge_axis_2 dynamics (i.e. before Step 2 if Cole picks
   "drive it"). Deferrable to H1 if Cole picks "door shut".

Q4 (DISTANCE-AS-STAT) -- Does the game need scale-invariant absolute travel distance, or is verdict +
   dimensionless ratios enough? MUST be answered BEFORE S4 -- it decides whether S4 exists at all.

Q5 (GAIT SWITCHING / POSE STATES) -- GaitDef.pattern is an open registry with room for pose-states &
   gait-switching, but the SWITCHING mechanic (when/how a creature changes gait, who drives it,
   blending) is unspecified. Answer BEFORE any gameplay gait-switching feature (post-S5, no near-term
   deadline, but capture requirements when S5 scope is set).

---

## 7. Decisions still owed by Cole (smaller; confirm/choose)

D1. hinge_axis_2: drive 2-DoF now (-> Foundry Q3) or leave as reserved door? GATES S1 scope / Step 2.
D2. MUSCLE_BASELINE_CAP=2.0 / MUSCLE_TORQUE_K=60.0: leave until playtest, or pin provisional goldens
    now to lock the muscle-regime shape? (Recommend: leave; no goldens exist to anchor them.)
D3. CONFIRM the phase-collision resolution is locked: phase in GaitDef, amplitude/rest/RoM in JointDef.
    The alternative (amplitude coordinated per-gait, moved into assignments as a struct) was the open
    veto. Silence = locked.
D4. Loader timing: wire PartResource.joints -> gene.joint now (S1/Step 1) or defer until the editor
    (S5) exists? (Recommend: now -- it is small and makes Problem 2 real.)
D5. GaitDef home: stays on the root PartGene (current), or migrates to a dedicated creature/genome
    wrapper resource if/when one is introduced? (No action unless a wrapper appears; flag for S5.)

---

## 8. How this build was placed (method + safety net)

This session had NO surgical file-editor tool -- edits were applied via a Python REPL on the dev machine using
a verified helper (assert exact single match, then write UTF-8 newline=
). New files written
whole. Backups of all 5 edited files at <repo>/.bak_gait_20260626-011551/. If the next thread has
proper edit tools, prefer those. To diff against pre-Problem-2 state, compare against
that .bak dir. The throwaway diagnostic tests/diag_scale.gd was created to measure the distance
drift in section 3 and then DELETED -- do not look for it.
