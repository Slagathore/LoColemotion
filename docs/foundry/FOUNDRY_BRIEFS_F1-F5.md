# Foundry briefs — F1–F5 (complex slices that should not be one-shot)

Framer-ready specs. ONE coherent slice per run. Acceptance criteria are written so the framer can
turn them into runnable golden checks. Each names the stack as a hard constraint. `RISK` = the
specific failure mode that makes this a Foundry item, not a direct task.

SEND ORDER: **F2 first** (gates S2/S3 and conditionally F1). **F4 + F5 next** (gate T2 quality).
**F1** only if F2 makes the mesh canonical for some quantity. **F3 is PARKED** — run only if D1
reopens 2-DoF (currently door-shut).

Locked decisions feeding this work: S1·1 = parallel loader-driven scene, keep the old one.
S2·1/S2·2 = Foundry (F2). S2·3 = detailed tissue map, defaults bundled with attachments (candidate
F6). T1 = in-game screen / built-ins + folder scan / live knobs. T2 = creature-card save /
list-select (3D-click later) / gizmo placement (built last) / shape+joints+gait / undo from day
one / debounced re-score.

---

## F1 — Mesh-derived mass properties (volume / CoM / inertia)
CONDITIONAL: only if F2 makes the mesh canonical for any quantity.

DELIVERABLE: A deterministic GDScript primitive that computes {volume, center_of_mass,
inertia_tensor} from an arbitrary triangle mesh (PackedVector3Array of triangles) via
signed-tetrahedron / divergence-theorem integration, plus a defined contract for malformed input.
Output is shaped to fill PhysicsDescriptor.inertia_tensor (currently empty).

CONSTRAINTS:
- Godot 4.7 stable mono, GDScript. Pure function: no RNG, no wall-clock, no frame/thread-order dependence.
- Results in the part LOCAL frame; scale is NEVER baked into a Transform3D (frame law / L3). Outputs
  normalize cleanly so dimensionless ratios are scale-invariant.
- Summation order is fixed and specified; no parallel reduction that reorders floating-point adds.
- States whether it REPLACES or FEEDS the existing in-probe _subtree_inertia path (R6 cost).

ACCEPTANCE (must be true and demonstrable):
- Closed-form: unit box, sphere, cylinder meshes return volume/CoM/inertia matching analytic formulas within 1e-6 relative.
- Scale-invariance (L4): same mesh scaled x2 yields dimensionless inertia ratios (I / (m*r^2)) identical to 1e-9; no scale leaks in.
- Robustness: inverted winding, a zero-area degenerate triangle, and a non-watertight hole each yield a DEFINED, documented result (never NaN/crash) with a flagged warning.
- Determinism: same mesh twice -> bit-identical output.

SCOPE: the measurement primitive + its input contract only. OUT: which quantities use it (F2), mesh import/LOD, authoring.

RISK: "compiles, passes a happy-path test, subtly wrong." Correctness rides on winding handling,
degenerate/non-watertight robustness, and deterministic FP summation holding L4 across scales —
none of which a single pass reliably proves.

---

## F2 — Physics authority + shared-face seam (S2·1 + S2·2) — THE big one

DELIVERABLE: A decided physics-authority schema. For each derived quantity — mass, volume,
surface_area, center_of_mass, inertia — name the SINGLE canonical source (analytic-from-skeleton |
authored descriptor | mesh-integrated) and the precedence rule when a part has more than one, AND
the rule that makes the shared-face surface-area haircut (adjust_internal_faces) operate on the
SAME source as the surface_area it trims. Resolves today's hybrid: descriptor overrides analytic
per-part in _fold, but the SA haircut is computed from skeleton extents.

CONSTRAINTS:
- Godot 4.7 mono; existing _fold / adjust_internal_faces / PhysicsDescriptor structures.
- Frame law, L3 scale-invariance, L4 default-equivalence are sacred and non-negotiable.
- EXACTLY one source per quantity. A second source of truth for any quantity = automatic loss (R7).
- Primitive-only creatures score byte-identical to today (L4).

ACCEPTANCE (must be true and demonstrable):
- A 5-row table (one per quantity) -> canonical source + precedence rule when multiple present, each justified.
- SA-source == haircut-source, shown on a worked 2-part touching example with the trimmed surface area computed numerically from the canonical source.
- L4 numeric proof: existing primitive goldens (quad, tower, heart-spam, ...) yield byte-identical mass / SA / CoM / inertia / verdict under the new rule.
- Seam red-team: an explicit "no quantity has two sources" audit + one named scenario where a naive fix would re-introduce a hybrid seam, shown prevented.

SCOPE: the authority decision + haircut alignment. OUT: mesh-integration math (F1), tissue/strength (S2·3 / F6), 2-DoF (F3).

RISK: a SYSTEM-correctness problem. A per-quantity-sensible answer can globally re-create a hybrid
seam (today's bug, relocated). A single pass optimizes the local change and won't reliably catch
the re-introduced second source.


---

## F3 — 2-DoF joint dynamics (PARKED — only if D1 reopens)

DELIVERABLE: A deterministic, scale-invariant 2-DoF hinge actuation model for the probe (when
hinge_axis_2 is driven), expressed as a proper rotation inside the frame law, PLUS the
code-structure contract guaranteeing byte-identical output to the 1-DoF path when hinge_axis_2 == ZERO.

CONSTRAINTS:
- Godot 4.7 mono; existing 1-DoF probe (theta/omega, foot_v = -lever*omega), CPG, PD gains
  proportional to _subtree_inertia, Froude-scaled frequency.
- L1 (every actuated DoF = proper rotation det=+1; scale never injected), L3 (determinism +
  scale-invariance), L6 (open actuator registry — slots in without editing the probe contract).
- HARD: the zero-second-axis path executes the LITERALLY UNCHANGED 1-DoF expression behind a guard
  — NOT a generalized 2-DoF formula evaluated at zero (FP operation order would differ).

ACCEPTANCE (must be true and demonstrable):
- L4 byte-identity: hinge_axis_2 == ZERO -> probe distance + verdict bit-identical to the current 1-DoF result on every existing golden.
- Worked example: a 2-DoF hip at two phase settings emits the exact resulting child_world (or hinge angles -> transform) numerically; det(R) = +1 verified.
- Scale-invariance: the 2-DoF creature at x2 scale -> identical verdict + dimensionless stats.
- Determinism: two runs bit-identical. Second axis yields a defined lateral-thrust contribution with a stated phase relation to the primary.

SCOPE: the 2-DoF probe model + zero-guard structure. OUT: 2nd-axis authoring UI, ball/3-DoF, contact dynamics.

RISK: "algebraically equivalent at zero" != "bit-identical at zero." A generalized formula passes
an eyeball check and FAILS L4 because FP add/mul order changes the bits. The guard STRUCTURE, not
just the math, is the deliverable.

---

## F4 — Undo/redo snapshot strategy for a shared-sub-object genome

DELIVERABLE: The snapshot/restore strategy for editor undo/redo over a PartGene genome tree,
correct under the genome's real object-sharing model (can one SocketDef / JointDef / PartGene
instance be referenced by multiple parents?), PLUS a ruling on whether the editor should ENFORCE
sub-object uniqueness to make the question moot.

CONSTRAINTS:
- Godot 4.7 mono; genome = PartGene Resource tree (children: Array[PartGene]), proven to
  deep-serialize and reload byte-identical.
- Restore reproduces a byte-identical evaluate() result.
- Defines behavior for a shared sub-object: deep-copy (splits the shared link) vs shallow (aliases
  mutated state) — choose and justify, OR enforce uniqueness with an author-time rejection.

ACCEPTANCE (must be true and demonstrable):
- snapshot -> mutate -> restore -> evaluate() byte-identical to pre-mutation (1e-9 / exact) on a multi-part creature.
- Shared-sub-object case: if sharing is allowed, a test shows "edit one applies everywhere" survives snapshot/restore; if uniqueness is enforced, sharing is rejected at author time with a clear error.
- redo after undo reproduces the post-edit state byte-identical.
- Snapshot cost stated as O(genome size).

SCOPE: the snapshot contract + sharing rule. OUT: undo-stack UI plumbing (a direct task, once the contract is fixed), command coalescing/merging.

RISK: a single-part test passes with naive deep-copy; the bug only surfaces with shared sub-objects
(deep-copy silently breaks edit-once-everywhere; shallow corrupts on restore). Invisible in the
obvious test.

---

## F5 — Live re-score concurrency contract

DELIVERABLE: The concurrency contract for live, debounced re-evaluation: how worker-thread
evaluate() / run_probe runs against a genome being actively edited so that (a) no stale result
overwrites a newer one and (b) the genome is never read by the probe while the main thread mutates it.

CONSTRAINTS:
- Godot 4.7 mono; evaluate() / run_probe on a worker thread, edits on the main thread, ~200ms
  debounce (reduces but does not remove overlap).
- The pure determinism of each evaluate() is preserved — this is a scheduling/ownership contract,
  not a change to the function.
- Main-thread-only genome mutation; the probe receives an IMMUTABLE snapshot taken at dispatch.

ACCEPTANCE (must be true and demonstrable):
- Generation/cancellation: a result tagged with an older genome generation is dropped, never displayed (test: dispatch eval A, edit, dispatch eval B, force A to finish last -> UI shows B).
- No data race: mutating the live genome mid-eval cannot affect the in-flight result (test: mutate during a stalled eval -> result equals the dispatch snapshot, not the mutation).
- Debounce: N rapid edits within the window -> exactly one (latest) eval dispatched.
- Clean lifecycle: worker completes or cancels without deadlock or leak (stated).

SCOPE: the scheduling / snapshot / cancellation contract. OUT: panel wiring, progress UI, the debounce timer itself (a direct task, once the contract is set).

RISK: "works in every test, races in the hand." Naive call-and-await passes tests; under real fast
editing a stale result lands last, or the probe reads a genome mid-mutation -> nondeterministic
output or crash.
