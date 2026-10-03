# Foundry-Design Brief — Part Schema: Geometry Descriptor, Tissue/Cavity, Sockets & Metadata

> **Type:** input artifact for a **Foundry-Design** run (no compilable output;
> rubric + consistency-lint + triple blind judge).
> **Status:** queued behind Tier 1 (now landed). The Tier-1 primitive provider is
> this design's placeholder; its existence shapes the migration path.
> **One-sentence question:** *How is a LoColemotion part authored (Blender +
> runtime-parametric Geometry Nodes), stored, and consumed (Godot editor +
> `CharacteristicsEvaluator`) so that arbitrary, dial-morphable, weird-on-purpose
> parts get correct geometry AND correct biological interpretation — without
> breaking the evaluator's tuned, deterministic contract, and without boxing out
> the abilities, actuation, and soft-body systems that come later?*

This is the one genuinely open, high-blast-radius design fork. Everything binds to
it: editor palette, save/load, the gait, and every future part and ability.

---

## Framing: this is ONE of THREE problems — keep them separate

A creature part touches three independent systems. Conflating them is how the
design stays mushy. **This brief is Problem 1 only**, plus the plumbing (sockets,
metadata, catalog) — with mandatory hooks so Problems 2 and 3 stay possible.

1. **Measurement (THIS BRIEF).** Correct mass / volume / surface / CoG / inertia
   *and* the right biological reading of a shape (a spike is armor, not hungry
   skin; a shell is hollow). Drives balance, debt, traits, strength.
2. **Actuation (separate brief, next).** Whether the locomotion probe can discover
   how a weird body moves — leg-gait, but also roll, pump, telescopic, undulation,
   wind-glide. Needs an actuator vocabulary **and** a probe that can simulate those
   motions. Out of scope here; this brief only must not preclude it.
3. **Abilities/effects (gameplay layer, much later).** Venom, fire breath, web
   shot, slime emission, disguise, glow; attacks with power/potency/effects. The
   evaluator must **never** know what fire breath does. Out of scope here; this
   brief only must carry the data.

Deferred to their own submodule entirely: **soft-body** (a different body
representation) and **pose-state** (turtle-retract, wing-fold — rides on
actuation). This brief must leave the door open for both, not design them.

---

## Ground truth the debate must hold (from the repo)

**The evaluator is the customer, and it is already fixed and tested.**
`scripts/core/CharacteristicsEvaluator.gd` consumes (now standalone Resources):

```
PartDefinition : part_type(StringName), density(float kg/unit³),
                 extents(Vector3 half-extents @scale 1), centroid_offset(Vector3)
SocketDef      : parent_attachment(Transform3D), child_anchor(Transform3D),
                 hinge_axis(Vector3; ZERO=rigid, else 1-DoF hinge)
PartGene       : definition, tags[StringName], socket, scale(Vector3), children[PartGene]
```

Hard truths that constrain every proposal:

1. The evaluator computes mass/volume/SA/CoG/radius **analytically** from
   `part_type` + scaled `dims`. It does not read the display mesh. An arbitrary GN
   mesh is invisible to it today.
2. It is **tuned and golden-tested** (`tests/test_characteristics_evaluator.gd`;
   `HEART_*`/`TIP_*` knobs pinned by those tests) and documented **SAME-BINARY**
   deterministic (no transcendental cross-platform guarantee).
3. The **frame law** is sacred and shared:
   `child_world = parent_world · socket.parent_attachment · socket.child_anchor`,
   with `scale` accumulated **separately** (never baked into the transform).
4. **Fork D is DECIDED — runtime-parametric ("live dials").** Part parameters live
   in the genome; the mesh morphs at runtime as the player drags dials. Blender
   does not run at runtime, so something in Godot turns dials → mesh. Whatever
   feeds the evaluator must regenerate from the **same dials**, every drag, and
   stay deterministic + cheap.

**Current state:** parts are the four analytic primitives; `PartMeshProvider` maps
`part_type`+`dims` → a Godot primitive. So the schema must let primitives and
authored parts **coexist** — the editor works before any authored part exists.

---

## The decision space (what the debate must settle)

### Fork A — The physics descriptor + tissue/cavity model (the centerpiece)

The old framing ("primitive proxy vs mesh integration") was a false binary. The
real design is: **the generator emits a small, deterministic _physics descriptor_
alongside the mesh, every time the dials move, informed by per-region tissue
tags.** The evaluator consumes the descriptor, never the triangles.

```
PhysicsDescriptor (regenerated from the dials, in lockstep with the mesh):
  volume                  # true, from the generated solid
  metabolic_volume        # volume of metabolically-active tissue only
  surface_metabolic       # SA that counts toward the SA:V "hungry skin" term
  cog                     # true center of mass
  inertia_tensor?         # for the probe (actuation brief may need it)
  bounds / radius
  tissue_breakdown        # per-class mass + volume
```

Why this is the synthesis: it is **mesh-accurate** (integrated from real generated
geometry), **cheap under live dials** (a function of the dials, like the dumb proxy
was, but rich), and **deterministic** (computed parametrically / in fixed order).
The proxy-vs-mesh fight dissolves into "**how rich is the descriptor, and who
computes it**."

**Tissue is two orthogonal axes, not one tag** (the antlers-vs-lungs distinction):

- **Axis 1 — material of the solid:** `metabolic` | `structural` | `inert`
  (inert = armor/spike/antler: full mass, zero metabolic demand, excluded from the
  hungry-skin SA term).
- **Axis 2 — function of enclosed empty space:** `none` | `respiratory` |
  `buoyancy` | … (a lung = thin `metabolic` wall + `respiratory` cavity; a shell =
  `structural` wall + `none` cavity).

Author tissue **per mesh region**, reusing the Blender **material slot** you're
already assigning for looks — near-zero extra authoring. A spike tip can be `inert`
while its base is `metabolic`.

Open questions for the debate:
- Descriptor richness — minimum viable field set vs full inertia tensor now.
- Who computes it and how it stays deterministic across the dial range.
- The two-axis tissue model: is "void as a cavity function" right, or do you need
  finer structure? Default tissue for unpainted regions?
- **Category-change edge case:** a part whose form changes *category* across the
  dial range (a smooth blob that sprouts discrete spikes), where one descriptor
  function has to branch. How is that authored without becoming a special case?
- How do the Tier-1 primitives map in — do they emit trivial descriptors, or stay
  a parallel built-in path?

### Fork B — Socket authoring + storage
A part exposes **named attachment sockets** (frame + hinge axis + mirror flag) for
children, and its own anchor for attaching to a parent. Authored as Blender
empties baked into the glTF? GN named attributes? A sidecar? Naming/orientation
convention (`+Z out, +Y up`, mirror-pair naming)? Low-stakes plumbing, but pick a
convention and a single source of truth.

### Fork C — Metadata home + source of truth
Now must hold: tissue tags, descriptor params / dial definitions, density, `tags`,
stable ID — **and the extensible ability payload (see hooks)**. `.tres` per part?
glTF `extras`? Sidecar JSON? One catalog Resource? Who wins on conflict? The one
trap: don't create two sources of truth that silently drift (see Fork F).

### Fork D — Runtime mesh-generation mechanism (decided: runtime-parametric)
Bake-time-only is **out**. Open: the mechanism that turns dials → mesh (+ descriptor)
at runtime:
- **M1 — reimplement** the generator in GDScript / compute (most control, most
  work, owns determinism).
- **M2 — morph targets** baked from Blender, interpolated at runtime (cheap,
  GPU-friendly, limited expressiveness).
- **M3 — runtime generation graph** (GN logic baked into a Godot-evaluable
  resource).
Tightly coupled to Fork A: the descriptor regenerates from the same dials, the
same way.

### Fork E — Catalog / discovery
How the editor enumerates available parts + their sockets + their dials to build
the palette (directory scan vs explicit catalog Resource vs import plugin).

### Fork F — Round-trip / provenance / versioning
Regenerating or editing a part must not orphan saved genomes. Stable part IDs (not
file paths), versioning, and what happens to a saved `PartGene` when a part's
dials/sockets/extents change.

---

## Forward-compat hooks (MANDATORY — this is how deferral stays safe)

A proposal that fails either of these is **out**, because it silently kills a
later system:

- **H1 — `part_type` / the descriptor stays OPEN.** No closed "exactly box/sphere/
  cylinder/capsule forever" assumption baked into the schema. A future `soft` /
  `metaball` part type, emitting its own descriptor, must slot in without editing
  the contract. (Soft-body lives here later.)
- **H2 — metadata carries an extensible, evaluator-ignored payload.** A part must
  hold an open `abilities: [{type, params}]`-style block (potency scaling off the
  same dials — bigger venom gland → more potency) that the evaluator reads past.
  This is the single forward hook for **all of Problem 3** (venom, fire, webs,
  disguise, glow, attacks) and for later pose/actuator data. Cheap to require now,
  ruinous to retrofit.

---

## Hard constraints (violate any → out)

1. **Evaluator contract preserved, or a clean adapter defined.** No silent edits to
   tuned math. If a proposal feeds the evaluator a descriptor, it must map cleanly
   onto what the evaluator reads, or own re-tuning + re-greening the golden tests
   + restating the determinism guarantee.
2. **Primitives and authored parts coexist.** Editor works with Tier-1 primitives
   before any authored part exists; authored parts are additive.
3. **Frame-law compatible.** Sockets express as `parent_attachment` / `child_anchor`
   Transform3Ds + `hinge_axis`; scale stays out of the transform.
4. **Determinism + live-dial cost.** Descriptor regeneration is deterministic and
   cheap enough to run every dial-drag. Default to no dependency beyond Godot 4.x +
   GDScript; justify any addition.
5. **Solo-dev ergonomics.** Authoring a new part (mesh + dials + tissue + sockets +
   metadata) is a short, repeatable Blender→Godot loop. State the step count.
6. **Genomes are `.tres` `PartGene` trees referencing parts by stable ID**, not path.
7. **H1 + H2** (forward-compat hooks above).

---

## Candidate directions (strawmen to attack — NOT prescriptions)

- **C1 — "Descriptor + sidecar `.tres`."** Display `.glb` (cosmetic) + a `.tres`
  `PartResource` holding dials, tissue map, the descriptor generator reference,
  sockets, stable ID, and the ability payload. Catalog = directory of
  `PartResource`s. *Bet: Godot-native, inspector-authorable; pays in Blender→Godot
  round-trip.*
- **C2 — "glTF-native, metadata-in-extras."** Sockets as empties, tissue as material
  slots, dials + descriptor hints + ability payload in `extras`; a Godot import
  plugin lifts it all. Single source of truth = the Blender file. *Bet: kills
  round-trip friction; pays in import-plugin complexity.*
- **Mechanism sub-candidates for Fork D:** M1 (reimplement) / M2 (morph targets) /
  M3 (runtime graph) — attack each on determinism, cost, expressiveness.

The debate may synthesize, reject, or invent past these.

---

## Rubric (judge scores on these — weight in brackets)

1. **Evaluator-contract integrity [22]** — descriptor maps cleanly to what the
   evaluator reads; preserves tuning + SAME-BINARY determinism, or owns the cost.
2. **Biological-interpretation correctness [15]** — the tissue/cavity model gets
   spikes/antlers/shells/lungs right (inert isn't taxed as hungry skin; hollow
   isn't filled solid).
3. **Authoring ergonomics [15]** — concrete step count + friction for "make one new
   dial-morphable, tissue-tagged part," Blender → in-editor palette.
4. **Forward-compat (H1 + H2) [15]** — soft-body and abilities/actuation are
   additive, not a repaint. Verified against the wishlist (venom, fire, webs,
   disguise, lamia, wings, slime).
5. **Round-trip / provenance robustness [12]** — regenerate without orphaning saved
   genomes; stable IDs; sane versioning.
6. **Live-dial runtime cost [11]** — descriptor + mesh regen per drag; palette load;
   save/load; memory.
7. **Reversibility / minimalism [10]** — least machinery that satisfies the above;
   how cheaply changed later.

A proposal that nails ergonomics but fails 1, 2, or 4 loses. Surface every place a
candidate trades a top-weight criterion for a low one.

---

## Required deliverable

1. **A decision on Forks A–F**, each with the tradeoff that justified it, and the
   chosen Fork-D mechanism (M1/M2/M3).
2. **The schema, written field-by-field** — the part Resource(s)/format, the
   `PhysicsDescriptor` shape, the two-axis tissue/cavity representation, socket
   representation, stable-ID/versioning, the ability-payload block, and exactly how
   the descriptor maps onto the evaluator's `PartDefinition`-equivalent inputs.
3. **One fully worked part, end to end — a parametric leg.** Blender authoring (the
   dials, tissue material slots, socket empties) → runtime mechanism (M1/M2/M3) →
   the dials → {mesh, descriptor} at two dial settings (short and long) → the exact
   numbers the evaluator receives at each → how it appears in the palette and
   assembles via the frame law. Plus one **weird** part to prove H2: a venom spine
   (inert tissue + a populated, evaluator-ignored ability payload).
4. **Migration note** — how the Tier-1 `PartMeshProvider` primitives fold in.
5. **Symmetry/mirror handling** — how mirror-paired sockets are marked and resolved.

---

## Non-goals (out of scope for this debate)

- The actuator vocabulary + probe physics fidelity (Problem 2 — **next brief**).
- Ability *behavior* (Problem 3 — gameplay layer; this brief only carries the data).
- Soft-body representation and pose-state (deferred submodule; H1 keeps them open).
- Editor UI/UX layout (Tier 2). Implementing any of it (this run produces a design).

---

## Definition of done

- A chosen, written schema covering A–F, scored against the rubric, with the
  dissent recorded (why the runner-up lost — especially descriptor richness and the
  Fork-D mechanism).
- The worked leg closes Blender → disk → Godot → evaluator → palette at two dial
  settings; the venom spine proves the H2 ability payload.
- Ends with the Foundry-Design handoff prompt: **"Write the Tier-2-prep bootstrap
  to implement this schema?"**

---

## Method note

Run as **Foundry-Design** (rubric + consistency-lint + triple blind judge;
fix-or-fallback, no aborts). Roster guidance, by review stage:
- **Ideation / divergence:** a high-temp wildcard pass to spread
  candidates past C1/C2 and the M1/M2/M3 mechanisms; widen before narrowing.
- **Red-team / precision critique:** aim the critique pass at criterion
  1 (does the descriptor actually feed the evaluator valid data?), criterion 2 (does
  the tissue model survive the spike/shell/lung cases?), and criterion 4 (run the
  wishlist through it). Those are where schemas rot.
- **Judge / consolidation:** score strictly on the weighted rubric,
  blind to authorship.
- Surface any dropped/failed pass; never let a silent drop pass as quorum.
