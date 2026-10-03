# Godot/Jolt Legacy Material Characterization Bootstrap

- **Status:** complete; isolated operational characterization retained
- **Recorded:** 2026-07-28
- **Parent:** [Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md)
- **Consumer:** [Godot/Jolt Stability-Influence Commissioning Bootstrap](SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md)
- **Pinned predecessor:** `9de56f13e39a180740d1d40801fe8dcb1aa87357`
- **Godot reference:** [PhysicsMaterial 4.7 class reference](https://docs.godotengine.org/en/4.7/classes/class_physicsmaterial.html)

## Decision and boundary

Before P5I.1 supplies a friction coefficient to the centroidal controller,
characterize the exact legacy Candidate 35 contact material in an isolated
Godot/Jolt sled.

The reference gait authors both contacting materials as:

```text
friction = 1.8
rough = true
bounce = 0.0
absorbent = true
```

Godot 4.7 documents `PhysicsMaterial.friction` in `[0,1]`. It also documents
that when both colliding materials are `rough`, the higher authored friction
is selected. Candidate 35's equal `1.8` pair is therefore outside the
documented coefficient range even though the engine accepts the value.

This campaign measures an operational static-to-sliding bracket for the exact
pinned engine, material, timestep, solver, mass, geometry, and force schedule.
It does not turn `1.8` into a portable Coulomb coefficient or a supported SDK
input.

## Frozen engine and fixture

- executable:
  `<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe`;
- Godot version: `4.7.stable.mono.official.5b4e0cb0f`;
- executable SHA-256:
  `c5fc2d0bb24826a6757fa1e6bf2991effb294859c7dd03d09a122ef217484896`;
- physics engine: `Jolt Physics`;
- physics frequency: `120 Hz`;
- Jolt velocity/position steps: `20/7`;
- rigid sled: `4.0 kg`, `0.8 x 0.2 x 0.6 m`;
- static floor: `200 x 1 x 8 m`, preventing the post-breakaway portion of the
  frozen force schedule from leaving the observed surface;
- gravity: `9.8 m/s^2` downward;
- sled and floor material: the exact four legacy fields above;
- damping: replace mode with linear and angular damping `0`;
- rotation: unlocked;
- sleeping: disabled;
- force: `RigidBody3D.apply_central_force` in world `+X`, once per physics
  tick, through the center of mass;
- no rail, transform write, velocity write, custom integrator, impulse,
  hidden stabilizer, or gait controller.

The source must read the realized material values back from both bodies and
fail if they differ from the frozen fields.

## Frozen schedule and observations

Run three independent worlds. Each world settles for `180` ticks, then
executes these strictly increasing `60`-tick force stages:

```text
0, 20, 40, 50, 55, 60, 65, 68, 70, 72, 75, 80, 90, 110 N
```

Analyze the final `30` ticks of every stage. Every analyzed tick must retain
one complete semantic sled/floor contact patch with unsaturated raw-contact
capacity and finite post-step kinematics.

Classify a stage as:

- `HELD` only when maximum post-step slip speed is at most `0.01 m/s` and
  tangential displacement is at most `0.003 m`;
- `SLIDING` only when maximum post-step slip speed is at least `0.05 m/s` and
  tangential displacement is at least `0.01 m`; or
- `AMBIGUOUS` otherwise.

One separate frictionless world uses the same fixture with only
`friction = 0.0` changed on both surfaces. It applies `20 N` after the same
settle and must classify as `SLIDING`. Every high-friction replicate must
classify its `20 N` stage as `HELD`.

## Frozen acceptance and coefficient rule

Each high-friction replicate must:

1. complete every scheduled stage and analyzed contact sample;
2. detect an ordered last-`HELD` to first-`SLIDING` bracket;
3. have no later `HELD` stage after sliding begins;
4. place the bracket inside `[40,110] N`;
5. have bracket width at most `12 N`;
6. have ordered applied-force/mean-normal-load ratio endpoints, with lower
   endpoint at least `0.50` and upper endpoint at most `3.00`;
7. keep maximum sled tilt below `5 degrees` through the first sliding stage;
   and
8. retain zero hidden constraint, damping, transform-write, velocity-write,
   impulse, actuation, locomotion, or physical-acceptance authority.

If all three pass, derive the Godot/Jolt controller friction lower bound as:

```text
minimum_lower_ratio = min(replicate lower ratio)
controller_mu = min(1.0, floor(100 * minimum_lower_ratio) / 100)
```

`controller_mu` must be at least `0.50`. The `1.0` cap is mandatory because
Godot documents that as the maximum material-friction value. This is a
conservative input for a zero-actuation mapping shadow on the exact legacy
world, not a cross-material, cross-engine, or locomotion-robustness
certificate.

## Evidence contract

The runner must retain:

- source commit and clean-worktree state;
- exact Godot executable path, version, and SHA-256;
- project physics and solver settings;
- fixture/test/runner SHA-256 values;
- every raw stage summary and classified bracket;
- the three lower/upper ratios and derived `controller_mu`;
- frictionless A/B result;
- transcript path and SHA-256; and
- explicit false flags for actuator mapping application, balance recovery,
  walking, friction/material locomotion robustness, cross-engine authority,
  physical acceptance, and SDK completion.

P5I.1 may consume `controller_mu` only after a clean-source retained report
passes this contract. No source may call the material campaign a gait,
walking, broad friction robustness, or validation of arbitrary materials.

## Result

Source commit
`d3d5cd1eb47d5fa9dc06106759cce4b01d4c3bd4` passed the frozen gate with
`11/11` assertions. The clean report is retained at
`<evidence-root>\godot-jolt-legacy-material-d3d5cd1\report.json`
(SHA-256
`f673eceb7e67a395943ebf7e00927a031d221a60eef371b1505b4a680db8a795`).
Its retained transcript SHA-256 is
`f375c35e747c04d1c2f88ac5e6910237a0f2799acd72b37075733e2c26dc30e4`;
its engine-log SHA-256 is
`f55d7638036cac67a76465814d4a590d233a57479e7546764cc0ef736e2a1728`.

The frictionless control slid at `20 N`. All three independent legacy worlds
held through `70 N` and first slid at `72 N`; their operational ratio brackets
were identically
`[1.7843903657805014, 1.8339202783221458]`. Every analyzed contact sample was
complete and the first sliding stages remained untilted. The frozen derivation
therefore yields:

```text
minimum_lower_ratio = 1.7843903657805014
controller_mu = min(1.0, floor(100 * minimum_lower_ratio) / 100) = 1.0
```

This closes only P5I.1's exact Godot/Jolt material-provenance interlock. The
report explicitly keeps walking, material locomotion robustness, cross-engine
authority, balance recovery, physical acceptance, and SDK completion false.
