# Creature parts

Blender-authored creature parts (eyes, mouths, feet, hands, wings, spikes),
exported as glTF **`.glb`** into category subfolders, e.g.:

```
assets/parts/mouths/beak_01.glb
assets/parts/feet/clawfoot_01.glb
assets/parts/eyes/stalk_eye_01.glb
```

## Modeling convention (so parts snap consistently)

- **Origin = attach point.** Place the part's object origin exactly where it
  should touch the body surface.
- **+Z faces "out".** The part should point along its local +Z away from the
  body; in-engine we align +Z to the surface normal at the placement point.
- **Up is +Y.** Keep a consistent up so symmetry mirroring behaves.
- **Low-ish poly.** Parts get instanced many times.
- Apply transforms in Blender before export (Ctrl+A, then All Transforms).

## Metadata

Each part gets a sidecar Godot Resource (`.tres`) describing category, socket
type, cost, and gameplay stats (bite, speed, etc.). The editor reads a parts
catalog resource to populate the palette. See M2/M6 in
[../../docs/DESIGN.md](../../docs/DESIGN.md).
