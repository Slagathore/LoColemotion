# LoColemotion Design Doc

A living design doc for the LoColemotion creature sandbox: a from-scratch,
full-3D creature editor and creature-phase prototype built solo in **Godot 4.x**. This is the strategy + roadmap; it
evolves as we build.

> Status: **M0 complete** and **Tier 1 complete**. The primitive editor bench is
> now available at `scenes/editor/bench.tscn` and is the main scene. It includes
> embedded creature cards, primitive catalog, save/load, live evaluator stats,
> undo/redo, shape/socket/joint/gait editing, topology edits, 3D click-select,
> spine-snap, and a frame-law-backed drag preview. Architecture:
> **socket-assembly part graph ("Model B")** — locked 2026-06-25.

---

## Architecture decision (read this first)

The project briefly carried **two incompatible creature models**. As of
2026-06-25, one is canonical and the other is archived. If you only read one
section, read this one.

- **Model A — spline + skin (ARCHIVED → `legacy/spline_model/`).** A spline
  backbone of vertebrae with radii, wrapped in a lofted swept-tube mesh, with
  glTF parts raycast-snapped onto the body surface and an auto-rigged
  `Skeleton3D` + IK gait. The old M1–M6 roadmap was built on this. It is now
  dead to the engine (the `legacy/` folder is `.gdignore`d).

- **Model B — socket-assembly part graph (CANONICAL).** A creature is a **tree
  of parts**. Each part is a primitive/mesh with authored physical properties;
  parts connect to **named sockets** on their parent via rigid or hinge joints.
  The genome *is* that tree. The `CharacteristicsEvaluator` already operates on
  exactly this representation.

**Why B won:** the `CharacteristicsEvaluator` — the most heavily-worked, tested,
and hardened asset in the repo — consumes a `PartGene` socket tree and produces
the full stat line (mass, CoG, structural debt, traits, intelligence, strength)
plus a deterministic locomotion verdict. A spline+skin body cannot produce a
`PartGene` tree, so Model A would have required a permanent translation layer
between the thing the player builds and the thing the engine evaluates. Making
the part graph canonical deletes that whole class of impedance mismatch and puts
the evaluator at the center where it belongs.

**What we give up (and reclaim later):** Model B builds articulated, rigid-ish
creatures (think jointed assemblies), not gooey organic worms.
The "worm-y / slime" aesthetic is a **deferred stretch goal** — reintroduced as a
*skinning pass over the part graph* (or a dedicated soft body part type) reusing
the archived `BodyMeshBuilder` loft math. It is explicitly out of scope for the
vertical slice.

---

## The long-term game (honest scope)

The long-term idea is five games in one, at increasing scale: **Cell** (2D-ish microbe) →
**Creature** (build a 3D creature, walk a planet) → **Tribal** (RTS-lite) →
**Civilization** (city-builder) → **Space** (procedural galaxy).

The two legendary, technically-hard pillars:

- The **procedural creature editor** — assemble arbitrary parts; the game
  evaluates and animates whatever you build. This is the defining engineering
  challenge, and what we de-risk first.
- **Procedural everything** — planets, streamed content. Deferred.

**Scope discipline:** build the **Creature** phase first because it contains the
hardest, most defining tech. Phase-1 goal is a **playable vertical slice**:
assemble a creature from parts in an editor, see its stats update live, press
play, and watch it walk a small 3D world.

---

## Core data model: the genome is a part graph

The genome is a `PartGene` tree. The authored genome types are standalone
`Resource`s so they can be authored, saved (`.tres`), and shared.

```
PartGene
├── definition : PartDefinition   # shape + physical properties (authored, sacred)
├── tags       : Array[StringName] # spine|locomotor|attack|heart|brain|
│                                  #   ground_contact|graft|lung
├── socket     : SocketDef         # how this part attaches to its parent (null on root)
├── scale      : Vector3           # per-axis, > 0
└── children   : Array[PartGene]

PartDefinition
├── part_type      : StringName    # &"box"|&"sphere"|&"cylinder"|&"capsule" (extensible)
├── density        : float         # kg/unit³
├── extents        : Vector3       # half-extents at scale 1.0
└── centroid_offset: Vector3       # part CoM in local frame

SocketDef
├── parent_attachment : Transform3D # pose of the socket on the parent
├── child_anchor      : Transform3D # the child's own anchor frame
└── hinge_axis        : Vector3     # ZERO = rigid; non-zero = hinge (1 DoF)
```

### The frame law (single source of truth)

Every part's world transform is derived from its parent's by one rule:

```
child_world = parent_world · parent_attachment · child_anchor
```

(with per-axis `scale` accumulated down the chain). This is the **load-bearing
invariant of the entire project**. It now lives in
`scripts/creature/creature_frames.gd`; the evaluator fold, assembler consumers,
spine snap, and drag preview all use the same frame-law helpers.

`ResolvedPart` and `WeakPoint` are **engine-owned derived data** (not authored,
not Resources) — the folded, world-space result the evaluator computes from the
genome.

---

## The stats core: `CharacteristicsEvaluator` (done + tested)

`scripts/core/CharacteristicsEvaluator.gd` is the heart of the game's "feel". It
is a **pure-analytic morphology evaluator plus a deterministic locomotion
probe** — already assembled, patched, tuned, and covered by
`tests/test_characteristics_evaluator.gd`. Treat it as the spec for what a
creature "is".

It computes, as closed-form functions of the resolved part graph:

- **Mass, volume, surface area, center of gravity** (internal faces subtracted
  before SA:V is read).
- **Structural debt** — perfusion (hearts within reach), metabolic supply vs.
  demand, surface-area-to-volume health, lung oxygen. Produces `WeakPoint`s
  (`starved`, `no_heart`, `graft`).
- **Traits** — emergent labels (e.g. `overextended`, `glass_cannon`, `flyer`)
  from debt/strength/balance inputs.
- **Intelligence & strength** scores.

Plus a **deterministic gait surrogate** (the "probe"): a self-contained CPG/PD
loop over the rigid/hinge joints, no live physics step. It is the ground truth
for *locomotion*; the analytic stages are authoritative for everything else.
Disagreement between the two is reported, never hidden.

> **Reproducibility caveat (already in the header):** the probe is **SAME-BINARY**
> reproducible only. Transcendental math is not bit-identical across platforms,
> so the locomotion verdict is **not** cross-machine authoritative for ranked
> play. Don't build leaderboards on it without a fixed-point or replay-checked
> path.

**Tuning knobs that are pinned by tests** (change deliberately): `HEART_REACH_K`,
`HEART_CAP_K`, `TIP_WARN_ANGLE`, the probe gate constants. The golden tests exist
so these can be re-tuned without silently breaking invariants.

---

## Part production pipeline

Parts are `PartDefinition`s. How their *meshes* get made has two tiers:

1. **Primitive fallback (Tier 1, now).** `part_mesh_provider.gd` maps each
   `part_type` to a Godot primitive (`BoxMesh`/`SphereMesh`/`CylinderMesh`/
   `CapsuleMesh`) sized from `extents`. This unblocks the assembler and editor
   **without any Blender dependency** — you can build, see, and evaluate
   creatures out of blocks immediately.

2. **Parametric Geometry-Nodes parts (later, the real pipeline).** Author parts
   in **Blender with Geometry Nodes** as parametric generators, export glTF with
   **socket + metadata** baked in, and feed a parts catalog the editor reads.
   This is the genuinely hard, high-blast-radius design problem (see "Where the
   hard problems are"), because the **socket/metadata schema** is what every
   downstream system depends on. The primitive provider is deliberately a clean
   seam so this can land later without churning the assembler.

---

## The editor (Tier 2)

Socket-attach, not surface-snap:

- The palette lists parts from the catalog.
- The player selects a **parent socket**; the chosen part attaches there and
  snaps into place **via the frame law** (so the preview is exactly what the
  evaluator will score).
- **Symmetry** toggle mirrors attachments across the sagittal plane (on by default).
- The evaluator runs **live** on every edit; stats + `WeakPoint` markers update
  in real time. The editor is, in effect, a visual front-end for the genome the
  evaluator already understands.
- **Save/load:** serialize the `PartGene` tree to `data/creatures/*.tres`.

---

## Animation (Tier 3)

Promote the probe, don't reinvent it. The evaluator's deterministic CPG/PD gait
surrogate already knows how to drive the rigid/hinge joints of an arbitrary part
graph. Tier 3 lifts that from an internal scoring loop into a **visible,
physics-or-kinematic gait** on the assembled creature:

- Reuse the CPG phase spread + PD targets the probe computes.
- Drive the real hinge joints of the assembled node tree.
- Start with the morphologies the probe already passes (so the verdict and the
  visible motion agree by construction), then widen.

This is the Model-B analogue of "auto-rig + IK gait", and — like in the old doc —
it is **~70% of the remaining technical risk**.

---

## Tech foundation: Godot 4.x mapping (Model B)

- **`Node3D` tree** — the assembled creature is a tree of `Node3D`s, one per
  part, each holding a **`MeshInstance3D`**. Parent/child structure mirrors the
  `PartGene` tree; local transforms come from the frame law.
- **Primitive meshes** (`BoxMesh`, `SphereMesh`, `CylinderMesh`, `CapsuleMesh`)
  for the fallback parts; **glTF import** for authored parts later.
- **Joints / physics** — rigid attachments are baked transforms; hinges become
  1-DoF joints for the gait (`Generic6DOFJoint3D`/`HingeJoint3D` or a kinematic
  equivalent — decided at Tier 3).
- **`CharacterBody3D` + `CollisionShape3D`** — drives walking the world (creature
  phase slice).
- **`Resource` / `.tres`** — the genome and the parts catalog are Resources;
  this is why Tier 1 promotes the contract out of inner classes.
- **GUT** (Godot Unit Test) — pure-logic tests; the evaluator suite is the model
  to follow.

> Curve3D / lofting / skeleton-skinning are **not** part of the primary path
> anymore. They live in `legacy/` and return only if/when the soft-body stretch
> goal does.

---

## Repo structure

```
sporespore/
├── README.md
├── project.godot
├── assets/
│   ├── parts/                 # authored glTF parts + metadata (later pipeline)
│   ├── materials/
│   └── env/
├── scenes/
│   ├── creature/              # runtime creature + smoke/assembly scenes
│   ├── editor/                # creature editor scene + UI (Tier 2)
│   └── world/                 # walkable test level
├── scripts/
│   ├── core/                  # genome Resources, frame law, evaluator (the spec)
│   ├── creature/              # assembler, part mesh provider, gait (Tier 3)
│   └── editor/                # placement, palette, symmetry, save/load (Tier 2)
├── data/
│   └── creatures/             # saved genomes (.tres)
├── tests/                     # GUT tests (evaluator suite lives here)
├── docs/
│   ├── DESIGN.md              # this file
│   ├── TIER1_BOOTSTRAP.md     # the executable Tier-1 plan
│   └── EVALUATOR_PATCH.md     # provenance of the evaluator fixes/tuning
└── legacy/                    # ARCHIVED Model A (.gdignore'd, see its README)
    └── spline_model/
```

---

## Milestone roadmap (phase-1 vertical slice)

Re-cut around Model B. Tackled in order; each is a few sessions.

- **M0 — Repo + skeleton + evaluator.** ✅ Project wired; the
  `CharacteristicsEvaluator` + golden tests landed; architecture fork resolved
  in favor of the part graph; Model A archived.

- **Tier 1 — Genome foundation.** *(in progress — see `docs/TIER1_BOOTSTRAP.md`)*
  1. Promote `PartDefinition`/`SocketDef`/`PartGene` to standalone `Resource`s;
     refactor the evaluator to consume them; evaluator test is the acceptance
     gate.
  2. Extract the **frame law** into one shared module.
  3. **Assembler:** walk a genome → a `Node3D`/`MeshInstance3D` tree placed by
     the frame law (the visual twin of `fold_graph`).
  4. **Part mesh provider:** primitive meshes from `part_type` + `extents`.
  - **Done when:** a smoke scene assembles a known genome, you can see the parts
    in the right poses, and the on-screen CoG matches the evaluator's reported
    CoG.

- **Tier 2 — Editor.** Primitive editor bench is usable: socket/frame placement,
  live evaluation, save/load, inspector fields, topology edits, click-select, and
  spine-snap. Remaining polish: symmetry/mirror tooling, richer gizmo affordances,
  catalog-authored part import, and UX cleanup.

- **Tier 3 — Gait.** Promote the probe's CPG/PD into a visible gait on the
  assembled, jointed creature. **Done when:** a creature you assembled walks, and
  the visible motion agrees with the probe's verdict.

- **Creature-phase slice.** `CharacterBody3D` movement, a small test world,
  camera, "eat a food blob". **Done when:** assemble → press play → walk it
  around eating.

**Out of scope for the slice:** the soft-body / worm-slime skin, the Blender
Geometry-Nodes part pipeline (primitives suffice), Cell phase, Tribal/Civ/Space,
procedural planets, multiplayer sharing.

---

## Where the hard problems are (and what deserves a Foundry debate)

Most of the upcoming work is mechanical single-session engineering. Two problems
are genuinely open-ended and high-blast-radius — those are where a multi-agent
Foundry/Foundry-Design pass earns its cost:

1. **The socket / metadata schema + parametric part-generation pipeline.** Not in
   Tier 1 as scoped (the primitive provider is a placeholder), but it's the next
   real fork: how sockets are authored on Geometry-Nodes output, where metadata
   lives (`.tres` vs glTF extras vs sidecar), how the catalog is read, LOD,
   round-trip. Everything downstream depends on it; getting it wrong is
   expensive. **Foundry-Design candidate** — settle the schema before building.

2. **Procedural gait (Tier 3).** Promoting the probe to a robust, visible gait
   across arbitrary morphologies — the dominant remaining risk. **Foundry
   candidate** (with golden tests, once there's a sim to check).

Tier 1 itself does **not** warrant a Foundry: contract→Resources is a deterministic
refactor, the frame law is one extracted function, the assembler mirrors existing
`fold_graph` logic, and the primitive provider is trivial. Spend the debate
budget on (1) soon and (2) later.

---

## Verification

- Run from the editor (F5) or headless: `godot --path .`. Each tier has a **scene
  you launch** (gamedev is verified by playing the scene) plus **GUT tests** for
  pure logic. The evaluator suite is the standard to match.
- Commit at each green tier with a descriptive message.

---

## Open decisions (not blockers)

1. **License** — currently all-rights-reserved / unlicensed until chosen.
2. **Hinge implementation at Tier 3** — physics joints vs kinematic pose-driving
   for the gait. Decide with the gait work.
3. **Metadata home for authored parts** — `.tres` vs glTF extras vs sidecar JSON.
   Part of the schema Foundry (problem 1 above).
4. **Soft-body return** — if/when the worm-slime look comes back, skinning pass
   over the part graph vs dedicated soft part type (reuse `legacy/` loft math).

---

## Notes / history

- **2026-06-25** — Resolved a two-architecture fork. Made the socket-assembly
  part graph canonical; archived the spline+skin model to `legacy/spline_model/`
  (`.gdignore`d). Rewrote this doc from the old M1–M6 spline roadmap to the
  tiered Model-B roadmap above. The `CharacteristicsEvaluator` and its golden
  tests predate this and carry over unchanged.
