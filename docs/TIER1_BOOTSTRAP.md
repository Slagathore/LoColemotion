# Tier 1 Bootstrap — Genome Foundation (Model B)

> **For:** an implementing agent, executing in the LoColemotion repo with Godot available.
> **Goal of Tier 1:** turn the `CharacteristicsEvaluator`'s private contract into
> the project's real, authorable genome, and stand up the minimum needed to
> **see** a creature that the evaluator can **score** — out of primitive blocks,
> with zero Blender dependency.
> **Architecture context:** read `docs/DESIGN.md` first. The socket-assembly part
> graph is canonical; the spline model is archived in `legacy/`.

---

## How to run this bootstrap

- Execute the steps **in order**. Each step is one focused, committable change.
- The **acceptance gate for the whole tier is the evaluator's golden test**, which
  must stay green throughout:
  ```
  godot --headless --script res://tests/test_characteristics_evaluator.gd
  ```
  Exit code 0 = all pass. Run it after **every** step, not just at the end.
- **Discovery first.** Before editing, open and read:
  - `scripts/core/CharacteristicsEvaluator.gd` — the contract (inner classes
    `PartDefinition`, `SocketDef`, `PartGene`, `ResolvedPart`, `WeakPoint`),
    `fold_graph`, `_fold`, and the `evaluate` return shape.
  - `tests/test_characteristics_evaluator.gd` — note it references the contract as
    `CE.PartDefinition` / `CE.SocketDef` / `CE.PartGene` via
    `const CE := preload(...)`. This is the refactor surface for Step 1.
- **Do not touch** `legacy/` (it is `.gdignore`d) or the evaluator's analytic/probe
  math. Tier 1 changes *types and consumers*, not formulas.

---

## The frame law (the load-bearing invariant)

Copied from `_fold` — every downstream system must agree with this exactly:

```gdscript
# rigid world transform of a part:
var xform := parent_xform
if gene.socket != null:
    xform = parent_xform * gene.socket.parent_attachment * gene.socket.child_anchor

# accumulated per-axis scale (floored), tracked SEPARATELY from xform:
var scale := parent_scale * gene.scale            # NOT baked into xform
var dims  := defn.extents * 2.0 * scale           # full scaled box dims
var com_local := defn.centroid_offset * scale
var com_world := xform * com_local
```

**Critical:** `scale` is **never** put into `xform`'s basis. `xform` is a rigid
(rotation+translation) transform; size lives only in `dims`. A child composes on
the parent's **scaleless** `xform`, so scale does **not** propagate down the
transform — it accumulates as a separate vector. Any code that bakes `scale` into
a node's basis will diverge from the evaluator. The Tier-1 assembler avoids this
entirely by reading `ResolvedPart.xform` and `ResolvedPart.dims` straight out of
`fold_graph` (below), rather than re-deriving them.

---

## Step 1 — Promote the contract to standalone `Resource`s

**Why:** the genome types are inner classes of the evaluator, so nothing else can
author them, save them to `.tres`, or share them. Lift the three **authored**
types to global Resources. Leave the two **derived** types (`ResolvedPart`,
`WeakPoint`) as engine-owned inner classes — they're computed, never serialized.

### 1a. Create three files in `scripts/core/`

`part_definition.gd`
```gdscript
class_name PartDefinition
extends Resource

@export var part_type: StringName = &"box"   # box|sphere|cylinder|capsule (extensible)
@export var density: float = 1000.0          # kg/unit³ — authored, sacred
@export var extents: Vector3 = Vector3.ONE   # half-extents at scale 1.0
@export var centroid_offset: Vector3 = Vector3.ZERO
```

`socket_def.gd`
```gdscript
class_name SocketDef
extends Resource

@export var parent_attachment: Transform3D = Transform3D.IDENTITY  # pose on parent
@export var child_anchor: Transform3D = Transform3D.IDENTITY       # child-local frame
@export var hinge_axis: Vector3 = Vector3.ZERO                     # ZERO = rigid
```

`part_gene.gd`
```gdscript
class_name PartGene
extends Resource

@export var definition: PartDefinition
@export var tags: Array[StringName] = []
@export var socket: SocketDef                # null on root
@export var scale: Vector3 = Vector3.ONE     # per-axis, > 0
@export var children: Array[PartGene] = []   # self-referential is fine with class_name
```

### 1b. Refactor `CharacteristicsEvaluator.gd`

- **Delete** the three inner class blocks `class PartDefinition`, `class SocketDef`,
  `class PartGene`. Keep `class ResolvedPart` and `class WeakPoint`.
- Every bare reference inside the evaluator (`PartGene`, `PartDefinition`,
  `SocketDef` — in `evaluate`'s signature, `_fold`, etc.) now resolves to the new
  **global** classes. Names are identical, so the bodies shouldn't need edits —
  but **read every hit** to confirm none relied on inner-class scoping.

### 1c. Update `tests/test_characteristics_evaluator.gd`

- Replace `CE.PartDefinition` → `PartDefinition`, `CE.SocketDef` → `SocketDef`,
  `CE.PartGene` → `PartGene` (the `_def` / `_socket` / `_gene` / `_make_quad`
  helpers). Keep `CE.evaluate` and `CE.fold_graph` (those are static methods that
  stay on the evaluator).

### 1d. Atomicity + acceptance

- **This is one atomic change.** The evaluator's `evaluate(root: PartGene, …)` and
  the test's `PartGene.new()` must reference the *same* type. Do 1a–1c together;
  a half-done promotion won't compile.
- **Gate:** the golden test passes (exit 0), identical pass count to before.

---

## Step 2 — Part mesh provider (primitive fallback)

**Why:** unblock "see the creature" without any authored art. This is a clean
seam the Geometry-Nodes pipeline replaces later (see DESIGN.md → "Where the hard
problems are").

`scripts/creature/part_mesh_provider.gd`
```gdscript
class_name PartMeshProvider
extends RefCounted

## Maps a part_type + full scaled dims (ResolvedPart.dims) to a display Mesh.
## Visual approximation only — the evaluator computes volume/SA from dims itself,
## so the mesh need not be volumetrically exact, just representative.
static func mesh_for(part_type: StringName, dims: Vector3) -> Mesh:
    match part_type:
        &"box":
            var b := BoxMesh.new(); b.size = dims; return b
        &"sphere":
            var s := SphereMesh.new()
            s.radius = maxf(dims.x, dims.z) * 0.5
            s.height = dims.y
            return s
        &"cylinder":
            var c := CylinderMesh.new()
            var r := maxf(dims.x, dims.z) * 0.5
            c.top_radius = r; c.bottom_radius = r; c.height = dims.y
            return c
        &"capsule":
            var cap := CapsuleMesh.new()
            cap.radius = maxf(dims.x, dims.z) * 0.5
            cap.height = maxf(dims.y, cap.radius * 2.0)  # Godot height includes the caps
            return cap
        _:
            var fb := BoxMesh.new(); fb.size = dims; return fb
```

- **Acceptance:** trivial check (a few asserts or a print) that each `part_type`
  returns the expected mesh class with the expected primary dimensions. The
  capsule height/radius coupling is the one fiddly case — eyeball it in the smoke
  scene.

---

## Step 3 — Assembler (consumes `fold_graph`)

**Why this design:** `fold_graph` already produces, per part, the exact world
`xform` and `dims` the evaluator scores. Building the visual from that output —
instead of re-walking the gene tree — makes divergence **impossible** and inherits
the evaluator's cycle/null guards for free.

`scripts/creature/creature_assembler.gd`
```gdscript
class_name CreatureAssembler
extends RefCounted

const CE := preload("res://scripts/core/CharacteristicsEvaluator.gd")

## Build a flat, display-only Node3D of MeshInstance3D parts placed at their
## resolved WORLD transforms. Flat (not articulated) is intentional for Tier 1 —
## you can't animate yet, and the articulated hinge hierarchy is a Tier 3 concern.
static func build(root: PartGene, root_xform: Transform3D = Transform3D.IDENTITY,
        mat: Material = null) -> Node3D:
    var container := Node3D.new()
    container.name = "AssembledCreature"
    var fold := CE.fold_graph(root, root_xform)
    for p in fold["parts"]:
        var mi := MeshInstance3D.new()
        mi.mesh = PartMeshProvider.mesh_for(p.definition.part_type, p.dims)
        mi.transform = p.xform                 # rigid world transform; scale is in the mesh
        if mat != null:
            mi.material_override = mat
        container.add_child(mi)
    return container
```

- **Do not** set `mi.scale` from `p.scale` — size is already in `p.dims` via the
  mesh. Scaling the node would double-apply and diverge from the frame law.
- **Acceptance:** assemble a known genome (reuse the test's quad builder shape);
  `container.get_child_count()` equals `fold["parts"].size()`; a small debug
  sphere placed at `evaluate(root)["cog"]` sits visually inside the body.

---

## Step 4 — Smoke scene (manual F5 verify)

`scenes/creature/assembly_smoke.tscn` + `scripts/creature/assembly_smoke.gd`
(build the scene in code, keep the `.tscn` trivial — mirror the pattern the
archived `legacy/spline_model/spine_demo.gd` used for orbit cam + lighting + UI).

It should:
- Build a hardcoded test genome (a quadruped is a good first subject).
- Add `CreatureAssembler.build(root)` to the tree.
- Place a small marker at the evaluator's reported `cog`.
- Overlay a few `evaluate()` stats (mass, body_radius, balance.stable,
  probe.verdict, debt_total).
- Orbit camera (drag) + zoom (wheel).

- **Acceptance:** F5 shows a recognizable blocky quadruped; the CoG marker is
  centered/low for the good build; flip the legs forward (front-loaded) and the
  overlay's `balance.stable` should go false — i.e., the picture and the stats
  agree.

---

## Consolidated pitfalls

1. **Half-done promotion won't compile** — Step 1 is atomic (classes + evaluator +
   test together).
2. **`StringName` `@export`** authors fine in Godot 4.3+; if your editor build
   chokes, fall back to `String` and compare with `StringName()` casts. Verify the
   tag literals (`&"heart"` etc.) still match after any change.
3. **Self-referential `Array[PartGene]` export** is legal; but a genome **cycle**
   (editor bug) can't be saved to `.tres` — that's a Tier-2 save/load guard, and
   `fold_graph` already guards evaluation. Don't add cycles in test fixtures you
   intend to serialize.
4. **Scale divergence** — the single biggest risk. Never bake `p.scale` into a
   node basis; size the **mesh** to `p.dims`. The assembler avoids this by reading
   `fold_graph` output directly.
5. **Re-walking the gene tree** in the assembler (instead of using `fold_graph`)
   reintroduces cycle/null handling you'd have to mirror exactly. Don't, in Tier 1.
6. **`.godot` cache staleness** after the file moves/additions — reopen the Godot
   editor once so it re-imports and re-registers the new `class_name`s before
   running the headless test.

---

## Non-goals / explicitly deferred

- **Standalone frame-law module** — *not needed yet.* `fold_graph` is the single
  source of the frame law, and the assembler consumes it. Extract a shared
  `creature_frames.gd` only when a **second** caller appears that can't use
  `fold_graph` output — i.e., the **editor's live placement preview (Tier 2)** and
  the **articulated hinge hierarchy (Tier 3)**. (Premature extraction now just
  adds an abstraction with one user.)
- **Articulated / hinge hierarchy** — Tier 3 (gait). Tier 1 assembly is a flat
  display bag on purpose.
- **Editor UI, symmetry, save/load** — Tier 2.
- **Geometry-Nodes parts + socket/metadata schema** — later, and it's the one
  piece worth a **Foundry-Design** pass before building (open-ended, high
  blast-radius). The primitive provider is its placeholder.

---

## Tier-1 done checklist  — COMPLETE (2026-06-25)

- [x] `PartDefinition` / `SocketDef` / `PartGene` are standalone `Resource`s with
      `class_name`; evaluator and test reference the globals.
- [x] Evaluator golden test green (exit 0), same pass count as before the refactor (38/38).
- [x] `PartMeshProvider.mesh_for` returns sized primitives for all four types.
- [x] `CreatureAssembler.build` returns a Node3D whose child count == resolved part
      count (7 for the quad), parts at correct world poses, no node-scale double-application.
- [x] Smoke scene logic verified headless: child count, CoG-inside-bounds, and
      front-loading flips `balance.stable` to false; scene `_ready` boots without error.
      *(Visual eyeball — "blocky quadruped" — is the one manual F5 confirmation left to Cole.)*
- [x] Headless editor pass re-registered the new `class_name`s; no missing-class or
      import errors in the log.
