# legacy/: archived, not the current architecture

**Everything under this folder is dead to Godot.** The empty `.gdignore` file next to
this README makes the engine skip the entire `legacy/` tree: no script class
registration, no imports, nothing shows in the FileSystem dock. It exists only as a
human-readable reference in git history.

## What's here: `spline_model/` (the abandoned "Model A")

The original creature approach: a **spline backbone** (`CreatureSpine`: a chain of
vertebrae with radii) wrapped in a **lofted swept-tube skin** (`BodyMeshBuilder`), with
a live demo (`spine_demo.tscn` / `spine_demo.gd`). This is what the old `docs/DESIGN.md`
milestones M1 to M6 were built around.

It was **superseded on 2026-06-25** by the socket-assembly part-graph architecture (see
the rewritten `docs/DESIGN.md`). The decisive reason: the `CharacteristicsEvaluator`,
the most heavily worked, tested, and hardened asset in the project, operates on a
`PartGene` socket tree, which a spline plus skin body cannot produce. Rather than
translate between two incompatible creature models forever, the spline model was
retired and the part graph made canonical.

| Model A (here, archived) | Model B (current) |
|---|---|
| spline of vertebrae + radii | `PartGene` tree joined by `SocketDef` transforms |
| lofted swept-tube skin | per-part meshes assembled by the frame law |
| parts raycast-snapped to body surface | parts attached to named parent sockets |
| auto-rig `Skeleton3D` + foot IK gait | rigid/hinge joints + CPG/PD gait (probe-promoted) |

## Why keep it instead of deleting it

1. **The loft math is good and reusable.** When the worm-y / slime body look comes back
   as a stretch goal, `BodyMeshBuilder`'s swept-tube generator is a solid starting point
   for skinning *over* a part graph (or for a dedicated soft-body part type). Don't
   rewrite from memory, lift it from here.
2. **Reference for the orbit-cam + live-rebuild demo loop** in `spine_demo.gd`.

## How to revive (if you ever need to run it)

1. Delete `legacy/.gdignore`.
2. Reopen the Godot project so it re-imports and re-registers class names.
3. Run `legacy/spline_model/spine_demo.tscn` (its script path was already fixed to point
   at the new location).
4. When done, restore `legacy/.gdignore` so it goes back to being invisible.

> Heads-up: reviving re-registers the global class names `CreatureSpine` and
> `BodyMeshBuilder`. Those names are not used by Model B, so there's no collision, but
> keep them out of the live tree unless you're actively referencing the archived demo.
