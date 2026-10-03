# Asset Pipeline

Authored meshes are visual-only overlays **by default**. Analytic scoring always uses
`PartDefinition.extents`/descriptors (I7: the display skin never feeds scoring).

**M45 — meshes can now drive physics collision.** When a creature is built with
`CreatureBody.BuildParams.use_authored_colliders = true`, any part with a registered
authored mesh gets a convex hull (`PartMeshProvider.collider_for_mesh`) as its collision
shape instead of the primitive box/capsule — with a box fallback if the hull is degenerate,
so a bad mesh can never produce a no-collision part. The default stays off, so existing
rollouts/goldens keep the primitive shapes unchanged.

Third-party reference assets are never committed or shipped. If a clean authored mesh is available, register it by stable
`part_id` through `PartMeshProvider.register_authored(part_id, path)`.

For `.glb`/`.gltf` files, the provider imports them at RUNTIME via
`PartMeshProvider.mesh_from_gltf` (GLTFDocument — no editor import step required), so the
pipeline works for assets outside the project import database. `.import`-pipeline PackedScenes
still work too: instantiate, find the first `MeshInstance3D`, extract its mesh, fall back to
primitives if none is found.
