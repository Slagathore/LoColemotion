# Editor Bootstrap -- T1 Test-Bench + T2 Primitives Editor

> **For:** an implementing agent, executing in the LoColemotion repo with Godot 4.7 available.
> **Goal:** stand up the in-game creature editor in two tiers on top of the
> finished genome foundation -- **T1** a read-only inspector/test-bench, **T2** a
> full primitives editor (shape/socket/joint/gait edits, undo, save/load, 3D
> select, gizmos) -- without ever giving the UI a second source of physics truth.
> **Read first:** `docs/DESIGN.md` (architecture), `docs/TIER1_BOOTSTRAP.md`
> (the genome foundation this builds on), `docs/foundry/F2_RESOLVED.md` (surface
> authority), `docs/PROBLEM2_GAIT_HANDOFF.md` (joint/gait semantics).

## Naming (read this once so the tier numbers do not collide)

`TIER1_BOOTSTRAP.md` already shipped "Tier 1 = the genome foundation" (PartGene as
real Resources, PartMeshProvider, CreatureAssembler, smoke scene -- COMPLETE).
**T1/T2 in THIS doc are the EDITOR tiers, layered on that foundation.** They are
not a renumber of the genome tier. When this doc says "T1" it means the
test-bench; "T2" means the editor.

## How to run this bootstrap

- Execute phases **P0..P6 in order**. Each phase is one focused, committable unit.
- **Acceptance gate for every phase:** the entire test suite stays green. Run all
  seven suites after each phase, not just at the end:
  ```
  foreach t in (test_characteristics_evaluator test_descriptor_evaluator
                test_genome_loader test_genome_snapshot test_internal_face_authority
                test_score_scheduler test_tier_d_metabolic_demand):
      godot --headless --path . --script res://tests/$t.gd     # exit 0 = pass
  ```
  Phases that add logic add their OWN headless test to this list (P0, P1).
- **After adding any `class_name` script**, reopen Godot once headless to
  re-register globals before running tests, or the parser throws
  "Could not find type X":
  ```
  godot --headless --editor --path . --quit-after 30
  ```
- **Discovery first.** The editor is a CONSUMER of finished systems. Before
  writing a line, read the real signatures in the API reference below and confirm
  them against the files. Do not invent methods.

---

## The load-bearing invariants (the spine)

The editor has exactly **one** way to change a genome. Everything else is a view.
Four invariants make that safe; violating any one reintroduces the whole class of
bugs F2/F4/F5 were built to kill.

### I1. Frame law (from `_fold`; full statement in TIER1_BOOTSTRAP.md)
`child_world = parent_world * socket.parent_attachment * socket.child_anchor`.
Scale accumulates as a SEPARATE vector and is **never** baked into a Transform3D
basis; size lives in `dims`, the mesh carries it. The editor's live placement
preview (P6) is the first consumer that cannot read `fold_graph` output directly
-- that, and only that, is when `creature_frames.gd` gets extracted.

### I2. Surface/physics authority (F2)
**The UI never computes a physical quantity.** Mass, volume, surface area, CoG,
balance, speed, debt, probe verdict -- all of it comes from one call to
`CharacteristicsEvaluator.evaluate(root)` (routed through the F5 scheduler so the
UI reads `scheduler.current()`). The overlay/inspector are pure renderers of that
dict. No widget recomputes SA, re-derives mass from density, or second-guesses the
probe. If a number is on screen, it came from `evaluate()`.

### I3. Snapshot + uniqueness (F4)
Every structural edit operates on a **fresh** `GenomeSnapshot.deep_copy(root)`,
never the live tree. Undo/redo install a fresh deep_copy too -- an undo frame and
the live tree must never alias, or editing "the present" silently rewrites "the
past." Before any edit is accepted, `GenomeSnapshot.validate_unique(next)` must
return `{"ok": true}`; a shared SocketDef/JointDef/GaitDef/PhysicsDescriptor or a
shared PartGene instance is rejected with its error surfaced to the user.

### I4. Debounced re-score (F5)
Edits do not score inline. They call `scheduler.request(root)` (cheap, returns a
generation int). A pump (P2: `_process`; later optionally a thread) drains pending
work and `accept(gen, result)`s it; stale generations are dropped. The UI shows
`scheduler.current()`. This keeps a slider-drag at 60fps from running 60 full
evaluations and from ever painting a result older than the latest edit.

### The commit pipeline (the ONE mutation path)
Every edit -- a slider nudge, a part add, a gizmo drag release -- goes through this
and nothing else:

```
func apply_edit(mutator: Callable) -> bool:
    var next := GenomeSnapshot.deep_copy(_root)        # I3: never touch the live tree
    mutator.call(next)                                 # caller mutates the COPY in place
    var chk := GenomeSnapshot.validate_unique(next)    # I3: structural legality
    if not chk["ok"]:
        edit_rejected.emit(chk["error"]); return false # reject, keep _root intact
    _root = next
    _history.push(_root)                               # F4 GenomeHistory: record new committed state
    _scheduler.request(_root)                          # I4: debounced re-score
    genome_changed.emit(_root)                         # I2: views rebuild from _root + current()
    return true
```

Undo = pop a frame, install `deep_copy(prev)`, `request()`, emit. Redo symmetric.
This function is P0. Build and test it headless BEFORE any UI exists.

---

## API reference (real signatures -- confirm, do not invent)

**`CharacteristicsEvaluator`** (`scripts/core/CharacteristicsEvaluator.gd`, static)
- `evaluate(root: PartGene) -> Dictionary` keys: `cog`, `total_mass`,
  `total_volume`, `total_sa_exposed`, `balance`, `speed`(`{value,drivers}`),
  `debt`, `weak_points`, `traits`, `probe`, `reconciliation`, `status`.
- `fold_graph(root, root_xform) -> {parts:[ResolvedPart], ...}` -- placement source
  for the assembler. ResolvedPart carries `xform`, `dims`, `com_world`, `joint`, etc.

**`GenomeSnapshot`** (`scripts/core/genome_snapshot.gd`, static) -- F4
- `deep_copy(root: PartGene) -> PartGene` -- independent clone; copies
  socket/joint/gait/descriptor as unique sub-resources.
- `validate_unique(root: PartGene) -> {"ok": bool, "error": String}`.

**`ScoreScheduler`** (`scripts/core/score_scheduler.gd`, instance) -- F5
- `request(root) -> int` (generation), `has_pending() -> bool`,
  `take_pending() -> Dictionary`, `accept(gen, result) -> bool`,
  `current() -> Dictionary`, `generation() -> int`, `applied_generation() -> int`,
  `run_pending_blocking() -> Dictionary` (synchronous drain -- use in tests/headless).

**`GenomeLoader`** (`scripts/creature/genome_loader.gd`, static)
- `resolve(root, parts_by_id: Dictionary, gait: GaitDef = null, warn := true) -> PartGene`
  -- stamps `socket`/`joint` onto genes from a catalog keyed by id. Round-trip path.
- `validate(root) -> PackedStringArray` -- non-fatal warnings.

**`CreatureAssembler`** (`scripts/creature/creature_assembler.gd`)
- `build(root, root_xform := IDENTITY, mat := null) -> Node3D` -- flat display bag
  of MeshInstance3D at resolved world transforms. Size in mesh, never node scale.

**Authorable fields the editor edits**
- `PartGene`: `definition`, `descriptor`(null=primitive), `tags`, `socket`,
  `scale`, `children`, `joint`, `gait`(root only), `part_id`, `socket_id`, `dial_values`.
- `PartDefinition`: `part_type`, `density`, `extents`, `centroid_offset`.
- `SocketDef`: `parent_attachment`, `child_anchor`, `hinge_axis`, `hinge_axis_2`(reserved).
- `JointDef`: `amplitude`, `rest_angle`, `angle_min`, `angle_max`.
- `GaitDef`: `pattern`, `assignments`(Dictionary[socket_id -> phase float]).

---

## P0 -- The spine (`EditSession` + `GenomeHistory`) + headless test

**Why first:** this is the entire architecture in two RefCounted classes. It is
fully testable with zero UI, so it gets locked and proven before a single Control
node exists. Every later phase only adds mutators and views around it.

**Files:** `scripts/editor/edit_session.gd`, `tests/test_edit_session.gd`.
**Reuse, do NOT reimplement:** `GenomeHistory` already exists from F4 at
`scripts/core/genome_history.gd` -- a snapshot stack whose top-of-`_undo` IS the
current state, and which already owns the deep_copy isolation contract:
`reset(root)`, `push(root)` (call AFTER an edit), `undo() -> PartGene`,
`redo() -> PartGene` (each hands back a FRESH isolated copy, or null), `can_undo()`,
`can_redo()`, `depth()`. EditSession just drives it -- it is NOT a new class. (This
collision was caught the hard way once already: do not add a second `class_name
GenomeHistory`.)

`EditSession` -- owns the live root, the history, the scheduler; exposes
`apply_edit`, `undo`, `redo`, `pump`. See the commit-pipeline sketch above for
`apply_edit`. `undo`/`redo` install `deep_copy(prev)` (never the raw history
object), then `request()` + emit. `pump()` drains F5:
```
func pump_blocking() -> void:                       # test/headless path
    if _scheduler.has_pending():
        var r := _scheduler.run_pending_blocking()  # evaluates the freshest gen
        if not r.is_empty(): score_changed.emit(_scheduler.current())
```
(For P2 the live UI pump uses `take_pending()` -> `evaluate()` -> `accept(gen,res)`
in `_process`; confirm `take_pending()`'s dict keys against the source.)

**Acceptance (`tests/test_edit_session.gd`, add to the suite):**
- edit then `undo()` yields a tree deep-equal to the pre-edit tree (reuse the
  snapshot test's deep-equal helper);
- the live root is NOT the same instance as any history frame (`get_instance_id`
  differs) -- proves no aliasing;
- `redo()` after `undo()` restores the edited tree exactly;
- an edit that aliases a sub-resource (deliberately share one SocketDef across two
  genes in the mutator) is REJECTED and leaves `_root` untouched;
- after N rapid `apply_edit`s, `pump_blocking()` applies a score whose generation
  equals the latest (no stale verdict). Gate: this test + all six existing green.

---

## P1 -- Data layer: `CreatureCard`, `PartCatalog`, save/load, folder-scan

**Why:** both tiers need to load creatures and (T2) save them. Two new Resources
plus a tiny IO helper. `data/creatures/` exists (empty but for `.gitkeep`).

**Decision -- embedded save vs catalog-resolved load (pro/con):**
- **Embedded** (`CreatureCard.root` holds the full PartGene tree with definitions
  as sub-resources): load needs no catalog, round-trip is trivial, files are
  self-contained. Con: a later edit to a "canonical" part def does not propagate to
  saved cards; files are larger.
- **Catalog-resolved** (cards store `part_id`/`socket_id` keys; `GenomeLoader.resolve`
  re-stamps definitions/sockets from `PartCatalog` on load): small files, central
  part defs propagate. Con: load depends on the catalog being present and correct;
  a missing id is a load-time failure.
- **Ruling for T1/T2: embedded save.** It is the simplest correct thing and removes
  a load-time dependency while the editor is unstable. `PartCatalog` still exists --
  as the **add-part palette** (P4) and the `parts_by_id` source the loader path can
  use later. Revisit catalog-resolved load only when a shared part-def library is a
  real need (Foundry pass, not now).

**Files:** `scripts/editor/creature_card.gd`, `scripts/editor/part_catalog.gd`,
`scripts/editor/creature_io.gd`, `tests/test_creature_io.gd`.
```
class_name CreatureCard
extends Resource
@export var display_name: String = "Untitled"
@export var root: PartGene                       # embedded full tree
@export var schema_version: int = 1              # bump on breaking genome changes
@export var notes: String = ""
```
- `PartCatalog`: returns built-in `PartGene` templates (one per primitive
  part_type at sane default density/extents) keyed by `part_id`. This is the
  palette; it is also a valid `parts_by_id` dict for `GenomeLoader.resolve`.
- `CreatureIO`: `save(card, path)` via `ResourceSaver.save`; `load(path) -> CreatureCard`;
  `scan(dir := "res://data/creatures") -> Array[Dictionary]` returning
  `{name, path}` for every `*.tres` (built-ins surfaced as in-memory cards with no path).
- **On load, ALWAYS run** `GenomeSnapshot.validate_unique(card.root)` and reject/clone
  if a hand-edited `.tres` aliased a sub-resource.

**Acceptance (`tests/test_creature_io.gd`):** build a known genome -> wrap in a
card -> save -> load -> the loaded root is deep-equal to the original and
`validate_unique` is ok; `scan()` finds the saved file; a saved-then-mutated card
does not change the on-disk original (copy isolation). Gate: full suite green.

---

## P2 -- T1 Test-Bench (read-only + live knobs)

**Why:** first pixels. Proves the spine end-to-end through the cheapest mutators
(scale, dial values) -- no structural editing yet -- with the real assembler and a
live score overlay. Even "read-only" tweaks go through `EditSession`, so the bench
is already exercising undo + F5.

**Files:** `scenes/editor/bench.tscn`, `scripts/editor/bench.gd` (reuse the orbit
cam + lighting pattern from `assembly_smoke.gd`).

Layout: left = card list (from `CreatureIO.scan` + built-ins); center = 3D viewport
with `CreatureAssembler.build(session.root())` and a CoG marker at
`current()["cog"]`; right = score overlay (mass, body_radius, `balance.stable`,
`speed.value`, `probe.verdict`, `debt` total) bound to `score_changed`; bottom =
live knobs (per-axis root/part scale sliders, dial values).

Wiring:
- selecting a card -> `session = EditSession.new(card.root, ScoreScheduler.new())`,
  rebuild viewport on `genome_changed`, repaint overlay on `score_changed`.
- a knob drag -> `session.apply_edit(func(r): r.scale = new_scale)` (or a part
  reached by index). The slider fires many edits; F5 debounces; overlay never lags
  behind the latest.
- `_process(_dt)`: `session.pump()` (the live `take_pending`/`evaluate`/`accept` form).
- rebuild = free the old assembled Node3D, add a fresh `CreatureAssembler.build`.
  Do NOT mutate mesh instances in place; rebuild from `root()` (I2: view is derived).

**Acceptance (manual F5 + a headless smoke for the wiring):** select the built-in
quad -> blocky creature + live stats; drag a scale knob -> creature resizes, mass
and balance update within a frame or two, no stutter; `Ctrl+Z` reverts the knob.
A headless `bench` smoke (build session, apply a scale edit, pump, assert overlay
source values changed and undo restored them) guards the non-visual wiring.

---

## P3 -- T2 structural editing + undo (list-select first)

**Why list-select before 3D-click:** decouples the editing model from picking.
You can edit every field through a tree list with zero raycast/gizmo code, which
means the hard part (mutating the genome safely) is proven before the fiddly part
(viewport interaction). 3D select (P5) and gizmos (P6) become pure input layers
that just set the same "selected part" the list already drives.

**Files:** `scripts/editor/part_inspector.gd` (+ scene), extend `bench.gd` into the
editor shell, undo/redo UI actions.

Selection model: a single `selected_index: int` into `fold_graph(root)["parts"]`
order (stable for a given tree). The inspector binds to `root` reached by that
index and edits via `apply_edit`:
- **shape:** `part_type` (option button -> rebuild mesh), `extents` (Vector3),
  `density`. Each emits one `apply_edit`.
- **socket:** `parent_attachment`/`child_anchor` (Transform3D via position+euler
  fields for now), `hinge_axis`.
- **joint:** `amplitude`, `rest_angle`, `angle_min`, `angle_max` (null JointDef =
  engine default; the inspector offers an "add joint" that sets a JointDef).
- **gait (root gene only):** `pattern`, `assignments[socket_id] -> phase`.
- undo/redo bound to Ctrl+Z / Ctrl+Shift+Z, enabled from `can_undo/can_redo`.

**Edge cases to honor:** editing a Transform3D through euler fields must round-trip
without gimbal surprises (store the raw Transform3D, expose euler as a view);
clearing a JointDef back to null is a valid edit (returns to golden defaults);
gait `assignments` keys must be live `socket_id`s (validate against the tree, drop
orphans on commit).

**Acceptance:** change a part's type/scale/density via the list -> picture and
score update; add a JointDef and raise `amplitude` -> `probe`/`speed` shift; set a
gait `pattern`/phase -> probe verdict changes; undo/redo walks the exact history;
the F4 uniqueness guard rejects any edit that would alias a sub-resource. Full suite green.

---

## P4 -- Add / remove / re-parent parts

**Why now:** structural topology edits are the highest-risk mutators (cycles,
aliasing, orphaned sockets). Doing them after the inspector means the commit
pipeline + uniqueness guard already exist to catch mistakes.

**Mutators (all via `apply_edit`, all on the deep-copied `next`):**
- **add:** clone a `PartCatalog` template (fresh sub-resources!) and append to the
  selected part's `children`; assign a unique `part_id`/`socket_id`.
- **remove:** drop a subtree from its parent's `children`.
- **re-parent:** detach a subtree, attach under a new parent; recompute nothing --
  `fold_graph` re-derives placement.

**The cycle/alias guard is non-negotiable here.** After the mutator,
`validate_unique` catches a shared PartGene instance (the classic re-parent bug
where you append without deep-copying the moved subtree). Add-from-catalog must
clone the template, or every "box" shares one PartDefinition and the guard fires --
which is the guard doing its job, but clone up front.

**Acceptance:** add a leg -> resolved part count +1, score reflects the new mass;
remove it -> back to the prior tree (and `undo` of an add equals a remove); a
re-parent that accidentally aliases is rejected with a clear message; you cannot
build a cycle. Full suite green.

---

## P5 -- 3D click-select

**Why an input layer, not a feature:** it only needs to map a viewport click to an
existing `selected_index`. The inspector already does the rest.

**Approach:** give each assembled MeshInstance3D a metadata `part_index` at build
time; raycast from camera through the cursor (`PhysicsRayQueryParameters3D` against
StaticBody/Area colliders sized to each part, or `camera.project_ray_*` + manual
AABB test against `fold_graph` world AABBs -- the latter needs no physics bodies and
matches the evaluator's boxes exactly). On hit, set `selected_index`, highlight
(material override or outline), and the inspector rebinds.

**Acceptance:** clicking a block selects it (inspector binds, highlight shows);
selection matches what the list shows; clicking empty space deselects. No score or
genome change (selection is not an edit -- it must NOT go through `apply_edit`).

---

## P6 -- Drag gizmos (LAST) + extract `creature_frames.gd`

**Why last, and why it triggers the extraction:** a gizmo needs a LIVE placement
preview while dragging -- the part must follow the cursor before the edit commits.
That preview cannot read `fold_graph` output (the edit has not happened yet), so it
is the **second frame-law consumer** TIER1_BOOTSTRAP predicted. Extract the frame
law into `scripts/creature/creature_frames.gd` now (a pure
`world_of(parent_world, socket) -> Transform3D` + scale accumulation), have BOTH
`_fold` and the gizmo preview call it, and add a test pinning preview == assembler
for the same socket. One source, two callers -- the exact condition for extraction.

**Approach:** translate/rotate gizmo on the selected part's `socket`
(`parent_attachment`). During drag, recompute that part's world via
`creature_frames` and move only its preview mesh (cheap, no full rebuild, no
edit). On release, ONE `apply_edit(func(r): <set socket pose>)` -> one undo frame,
one re-score. Snap-to-grid and symmetry mirror are optional polish on top.

**Acceptance:** drag a part -> it tracks the cursor per the frame law; the dragged
preview position equals a full `CreatureAssembler.build` of the post-edit tree
(the extraction test); release commits exactly one history entry and one score
update; mid-drag motion produces NO history spam and NO score churn.

---

## Consolidated pitfalls

1. **A second physics source (I2 violation).** Any widget that computes mass/SA/CoG
   itself will drift from `evaluate()`. Render the dict; never recompute.
2. **Aliasing the live tree into history (I3).** `apply_edit` and `undo`/`redo` must
   install `deep_copy`s. The cheapest correctness test is the `get_instance_id`
   inequality assert in P0 -- keep it.
3. **Inline scoring (I4 violation).** Calling `evaluate()` directly from a slider
   `value_changed` re-runs the full model per pixel. Always go through
   `scheduler.request` + the pump.
4. **Node-scale double-application.** Same trap as TIER1: size lives in the mesh
   (`p.dims`), never in `MeshInstance3D.scale`. Rebuild from `root()`, do not poke meshes.
5. **Add-from-catalog without cloning** shares one PartDefinition across parts ->
   `validate_unique` rejects. Clone the template's sub-resources on add.
6. **Editing during a pending score.** The pump must drop stale generations
   (`accept` returns false) so a slow evaluation from edit N never overwrites the
   verdict for edit N+3. Trust the F5 generation contract; do not cache results yourself.
7. **`.godot` class-cache staleness** after new `class_name` files (EditSession,
   CreatureCard, etc.) -- run the headless `--editor --quit-after 30` pass before tests.
8. **Selection treated as an edit (P5).** Click-select must not call `apply_edit`,
   or every click spams history and re-scores.

---

## Non-goals / explicitly deferred

- **Catalog-resolved load / shared part-def library** -- embedded save is the T1/T2
  ruling; revisit under a Foundry pass only when a real shared library is needed.
- **Articulated/animated preview** -- the bench shows the flat display bag; live
  gait animation is a separate (Tier 3) concern. The probe verdict is the editor's
  proxy for "does it move well."
- **Geometry-Nodes / authored meshes** -- primitives only; `PartMeshProvider` stays
  the seam. Descriptor (authored physics) editing is read-only in T2 (you can view
  a descriptor part's numbers, but authoring measured physics is out of scope here).
- **Symmetry/mirror tooling, snap, multi-select, copy/paste** -- polish on top of P6.
- **2-DoF joints** -- `hinge_axis_2` stays reserved/undriven (D1 LOCKED). No UI for it.

---

## Done checklists

**P0 -- spine**
- [x] `GenomeHistory` + `EditSession` exist; `apply_edit` is the only mutation path.
- [x] `tests/test_edit_session.gd` green: undo deep-equal, no aliasing, redo,
      reject-on-alias, no-stale-score.

**P1 -- data**
- [x] `CreatureCard`/`PartCatalog`/`CreatureIO`; embedded save round-trips deep-equal.
- [x] `validate_unique` run on load; `scan()` lists built-ins + saved cards.

**P2 -- T1 bench**
- [x] Card list + viewport + live overlay; knobs edit through `EditSession`.
- [x] Manual F5 path opens `scenes/editor/bench.tscn`; headless wiring smoke green.

**P3 -- T2 inspector**
- [x] Shape/socket/joint/gait edits via list-select, each one `apply_edit`; undo/redo UI.
- [x] Gait/joint edits flow into the evaluator; uniqueness guard rejects aliasing.

**P4 -- topology**
- [x] Add/remove/re-parent via catalog clones; cycle + alias guarded; undo of add == remove.

**P5 -- 3D select**
- [x] Click maps to `selected_index`; selection is NOT an edit.

**P6 -- gizmos**
- [x] `creature_frames.gd` extracted; `_fold` + gizmo preview share it (preview==assembler test).
- [x] Shift-drag previews live, release commits one socket edit + one re-score.
