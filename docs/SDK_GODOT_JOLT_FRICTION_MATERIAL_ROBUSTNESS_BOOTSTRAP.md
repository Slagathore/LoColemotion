# Godot/Jolt Friction and Material-Robustness Bootstrap

- **Status:** the legacy P5M ladder is closed; BW2R-C passed independent BW3R
  validation, but its first complete `17`-world BW4 cold locomotion matrix
  rejected at `27/28`; the complete `116`-world BW4R-A/B branch-free
  development family is retained and rejected; the complete `174`-world
  BW5R-A/B/C filtered-feedback comparison selected BW5R-B for new validation
- **Recorded:** 2026-07-28
- **Parent:** [Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md)
- **Predecessor:** [Godot/Jolt Stability-Influence Commissioning Bootstrap](SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md)
- **Legacy characterization:** [Godot/Jolt Legacy Material Characterization Bootstrap](SDK_GODOT_JOLT_MATERIAL_CHARACTERIZATION_BOOTSTRAP.md)
- **Audit:** [Post-C6 SDK Audit](SDK_POST_C6_AUDIT_2026-07-28.md)
- **Research ledger:** [Locomotion Research Sources and Adoption Ledger](research/LOCOMOTION_RESEARCH_SOURCES.md)
- **Preregistration source:** `45f255d1cba8a3114b4c3569df7cbb56f0f6cdc3`

## Decision

Make friction the first cold nuisance axis after P5I.3C-R2. The campaign is
ordered:

1. P5M.1 measures Godot/Jolt breakaway behavior over a frozen authored-friction
   ladder;
2. P5M.2 publishes versioned adapter material profiles from those measurements;
3. P5M.3 runs the unchanged Candidate 35 base plus unchanged P5I.3C-R2
   stability overlay over a fresh, source-frozen locomotion matrix; and
4. P5M.4 classifies only the exact tested material cohort and fail-safe
   boundary.

No locomotion result may be opened before P5M.1 evidence is retained and
P5M.2 profiles are committed. No observed P5M result may add a Candidate 35
branch, change a P5I.3C gain or bound, remove a cell, alter a perturbation seed,
or choose a new acceptance threshold.

## Why authored friction alone is insufficient

The reference fixture currently authors the same Godot `PhysicsMaterial` on
the floor and articulated bodies:

```text
friction = 1.8
rough = true
bounce = 0.0
absorbent = true
```

The legacy isolated sled established an operational controller coefficient of
`1.0` for that exact material pair at Godot/Jolt `120 Hz, 20/7`. It did not
establish a mapping for other authored values. The live adapter therefore
correctly treats `1.0` as source-pinned provenance, but that value cannot be
silently reused after the physical fixture changes.

The engine-neutral centroidal request already accepts a characterized friction
coefficient. P5M adds the missing adapter-side provenance record. It does not
put Godot material-combine rules in the portable core.

## External-source boundary

The three supplied papers remain retrievable by exact path and hash in the
[research ledger](research/LOCOMOTION_RESEARCH_SOURCES.md):

- `C:\Users\Cole\CodeStuff\games\SporeSpore\DReCon.pdf`
  (`aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54`);
- `C:\Users\Cole\CodeStuff\games\SporeSpore\2604.08780v1.pdf`
  (`ae0ecb7fa7b16659b6a9ae5561176fa5c4d76788528b2ba8fc4bc533792824ae`);
  and
- `C:\Users\Cole\CodeStuff\games\SporeSpore\2507.22653v2.pdf`
  (`6734394082dac95355277f477f01ea9e0ee90cb03e28cc20508632f7d11ddb31`).

DReCon supports a deterministic base plus bounded correction architecture.
QWM supports separating immutable morphology from runtime state and stating a
distribution boundary. UniLegs supports ordered variable-topology semantics.
None supplies a valid SporeSpore friction interval, Godot/Jolt material rule,
breakaway threshold, or robustness gate. Every number below is therefore a
SporeSpore preregistration choice, not a paper result.

## Frozen source and policy interlocks

P5M begins after:

- P5I.3C-R2 implementation source
  `df6c9e55e2e8eaf9433eba83f70d6031ca186592`;
- P5I.3C-R2 report
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-stability-physical-influence-r2-df6c9e5\report.json`;
- report SHA-256
  `d0971317d174f7bb5aef4cbea1f79c462182a0cd3e4ce59c83980ef6a7cb305b`;
- legacy material source
  `d3d5cd1eb47d5fa9dc06106759cce4b01d4c3bd4`;
- legacy material report
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-legacy-material-d3d5cd1\report.json`;
  and
- legacy report SHA-256
  `f673eceb7e67a395943ebf7e00927a031d221a60eef371b1505b4a680db8a795`.

The following identities remain byte-for-byte fixed through P5M.3:

- Candidate 35 base policy and its complete branch topology;
- `p5i3c_support_centroid_tilt_feedback_v1`;
- `sporespore_godot_jolt_stability_overlay_runtime_v1`;
- `sporespore_stability_overlay_memory_v1`;
- the `0.075 rad/s` absolute contribution bound;
- the `0.010 rad/s/step` contribution slew bound;
- the P5I.2 torque-to-host-velocity profile;
- the GQ15 gait clock;
- the Godot/Jolt `120 Hz, 20 velocity-step, 7 position-step` solver policy;
- reference morphology and actuator limits; and
- all ordinary physical walking and no-cheat gates.

The friction/material value may enter only:

1. the physical fixture material;
2. a source-pinned adapter material profile; and
3. the existing portable centroidal feasibility calculation.

It may not enter Candidate 35, gait timing, motor limits, steering, a new
threshold branch, morphology selection, or evidence thresholds.

## P5M.1 — isolated friction ladder

### Frozen physical fixture

P5M.1 reuses the accepted isolated sled geometry, contact observer,
post-step slip classification, and gravity/load reconstruction. Every cell:

- builds one new world;
- uses Godot `4.7.stable.mono` with Jolt;
- runs at `120 Hz`, velocity steps `20`, position steps `7`;
- uses the same floor and sled geometry, mass, collision margin, damping, and
  contact-observer profile;
- authors the same material on sled and floor;
- fixes `rough = true`, `bounce = 0.0`, and `absorbent = true`;
- settles for `180` ticks;
- applies force through the sled center of mass with
  `RigidBody3D.apply_central_force` once per tick;
- runs each force stage for `60` ticks; and
- classifies only the final `30` ticks of each completed stage.

There is no gait, joint, actuator, stability policy, torso command, hidden
rail, transform write, or velocity write.

### Frozen authored axis

The ordered authored-friction cells are:

```text
0.00, 0.20, 0.40, 0.60, 0.80, 1.00, 1.80
```

`0.00` is a negative control. Each positive value receives three independently
constructed worlds. Values `0.20` through `1.00` lie inside Godot's documented
property range. `1.80` is the retained legacy out-of-documentation value and is
never treated as portable merely because Godot accepts it.

### Frozen force schedule and stopping rule

For every positive cell, the ordered force schedule is:

```text
0 N through 80 N inclusive in 2 N increments, then 90 N, 100 N, 110 N
```

A replicate stops after the first two consecutive completed stages classified
`SLIDING`. This is an outcome-independent algorithm frozen before any P5M.1
world is opened. It prevents a low-friction sled from accelerating through
irrelevant later stages while still retaining a first-sliding and repeated-
sliding observation.

The `0.00` control uses `2 N` after settling and must classify `SLIDING`.

The unchanged classification thresholds are:

- `HELD`: maximum slip speed at most `0.01 m/s` and tangential displacement
  at most `0.003 m`;
- `SLIDING`: maximum slip speed at least `0.05 m/s` and tangential displacement
  at least `0.01 m`; and
- otherwise `AMBIGUOUS`.

### Frozen per-replicate acceptance

Each positive replicate must:

1. preserve complete, finite, unsaturated contact observation at every
   analyzed sample;
2. retain exactly one canonical contact patch;
3. contain at least one completed positive-force `HELD` stage;
4. contain two consecutive completed `SLIDING` stages;
5. bracket first breakaway between the last `HELD` force and first `SLIDING`
   force;
6. keep the bracket width at most `2 N`;
7. keep sled tilt below `5 degrees` through the first two sliding stages;
8. keep measured mean normal load positive and finite;
9. report finite lower and upper empirical static ratios; and
10. preserve zero gait, actuation, and direct physics-state mutation claims.

Across the three replicates for one authored value:

- maximum first-sliding-force spread is at most `2 N`;
- maximum lower-bracket-force spread is at most `2 N`; and
- the minimum lower empirical ratio owns the conservative coefficient.

Across increasing positive authored values, neither the minimum lower
breakaway force nor the minimum lower empirical ratio may decrease by more than
one `2 N` force-ladder cell or `0.05` ratio respectively. This is an
operational monotonicity check, not an assertion that authored friction equals
effective friction.

### Frozen coefficient derivation

For each positive authored value:

```text
minimum_lower_ratio =
    min(replicate empirical_static_ratio_lower)

controller_mu =
    min(1.0, floor(100 * minimum_lower_ratio) / 100)
```

The result must be finite and positive. For `0.00`, `controller_mu` is exactly
zero and has negative-control status. The cap at `1.0` preserves the documented
Godot maximum used by the legacy characterization; it does not claim that Jolt
internally clamps the `1.80` material.

### P5M.1 stopping rule

The first source-clean complete ladder is the only eligible P5M.1 result. Any
failed cell rejects that source. No selective replicate rerun, force insertion,
threshold edit, value removal, or coefficient-rule edit is allowed after
opening the result.

The retained report schema is:

```text
sporespore_godot_jolt_friction_ladder_report_v1
```

It must retain the complete receipt, source hashes, Godot executable hash and
version, engine log, transcript, every stage summary, coefficient derivation,
and all negative claims.

### First P5M.1 result — rejected

Clean pushed implementation source
`58c64d470b0e749dc12f9da65b665ac3f2d5bbf9` produced its first and only
eligible complete ladder at `23/31`. The rejected evidence is retained at:

- report:
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-friction-ladder-58c64d4\report.json`;
- report SHA-256:
  `0b6fa2f1f306ecda9e0b1740f40b97eaf7e36e779dcf1e2779254667c650f009`;
- transcript SHA-256:
  `bb64d63951a3f222716a0f74553a6046d46986831409e3ad70a880f4988cd303`;
  and
- engine-log SHA-256:
  `0be0b36a876c9c66435d27c7803b893386b15f8a1defb0e0826e4030f1be536d`.

The frictionless control passed. All three replicates at `0.60`, `0.80`,
`1.00`, and `1.80` passed with exact repeatability and operational brackets
`22-24 N`, `30-32 N`, `38-40 N`, and `70-72 N`. The corresponding conservative
coefficient diagnostics were `0.56`, `0.76`, `0.96`, and `1.00`.

The only eight failed gates were the three replicates and aggregate cell gate
at each of `0.20` and `0.40`:

```text
authored 0.20:
  6 N HELD, 8 N AMBIGUOUS, 10 N SLIDING
  operational bracket 6-10 N

authored 0.40:
  14 N HELD, 16 N AMBIGUOUS, 18 N SLIDING
  operational bracket 14-18 N
```

All analyzed samples were complete, finite, unsaturated, single-patch
observations; every repeat was exact. The rejection is a force-lattice
resolution failure: one legitimate ambiguous `2 N` cell makes the
last-HELD-to-first-SLIDING bracket `4 N`, exceeding the frozen `2 N` maximum.
It is not permission to relabel an ambiguous stage, widen the accepted
bracket, omit the low cells, or publish the rejected diagnostic coefficients.

Source `58c64d4` must never be rerun or promoted.

### P5M.1-R1 prospective resolution amendment

P5M.1-R1 changes only force-lattice resolution. It preserves:

- all seven authored-friction values;
- three complete independent replicates at every positive value;
- the exact sled, engine, solver, material flags, settling, stage duration, and
  analysis window;
- the exact HELD, SLIDING, and AMBIGUOUS classification thresholds;
- the requirement for a positive-force HELD stage and two consecutive
  completed SLIDING stages;
- the `2 N` maximum operational bracket width;
- the `2 N` replicate-spread bounds;
- the monotonicity bounds;
- coefficient derivation and `1.0` cap;
- all `31` acceptance gates and negative claims; and
- the complete-ladder, no-selective-rerun stopping rule.

The positive-cell force schedule becomes:

```text
0 N through 80 N inclusive in 1 N increments, then 90 N, 100 N, 110 N
```

The `0.00` control remains exactly `2 N`. With the same classification
thresholds, one intermediate ambiguous `1 N` cell can now produce a
last-HELD-to-first-SLIDING bracket of at most `2 N`. This increases measurement
resolution; it does not relax acceptance.

R1 must use new receipt/report identities:

```text
sporespore_godot_jolt_friction_ladder_r1_receipt_v1
sporespore_godot_jolt_friction_ladder_r1_report_v1
```

The first clean, pushed, complete R1 `19`-world ladder is its only eligible
result. Every positive cell and replicate reruns. Any R1 miss rejects that
source without a selective rerun, further lattice edit, threshold edit,
coefficient edit, or cell removal.

### P5M.1-R1 result — passed

Clean pushed source
`559aa323f3a07179cc074f1749abc94c78ceafb3` passed its first and only
eligible full R1 ladder at `31/31`. The retained evidence is:

- report:
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-friction-ladder-r1-559aa32\report.json`;
- report SHA-256:
  `66555991eb7ef004725a458d86cdc8a8b0011447a266f056ddf1b33c9c776eed`;
- transcript SHA-256:
  `3e36633c33c7bf6b53a6df6a1273acbcf338878eb902346783c9f83a31cfa5e7`;
  and
- engine-log SHA-256:
  `bac022af8bfb614aff4d6cd53e416143bff704c7f57ebc41f70b7069b6619dc9`.

All `19` worlds completed. The zero-friction control slid under `2 N`. Every
positive replicate was exact within its cell, every operational bracket was at
most `2 N`, and the cross-cell monotonicity gate passed:

| Authored friction | Three replicate brackets | Minimum lower ratio | Conservative controller coefficient |
| --- | --- | ---: | ---: |
| `0.20` | `7-9 N` | `0.178432416069519` | `0.17` |
| `0.40` | `15-17 N` | `0.382421187990019` | `0.38` |
| `0.60` | `23-24 N` | `0.586461846703393` | `0.58` |
| `0.80` | `31-32 N` | `0.790486780424924` | `0.79` |
| `1.00` | `39-40 N` | `0.994542505667106` | `0.99` |
| `1.80` | `70-71 N` | `1.78439054471982` | `1.00` |

This result closes isolated Godot/Jolt friction-ladder characterization only.
It does not establish locomotion, robustness, a continuous friction interval,
cross-engine equivalence, or SDK completion.

## P5M.2 — adapter material profile

After P5M.1 passes, publish one immutable profile per authored cell:

```text
sporespore_adapter_material_profile_v1
```

The checked-in ordered profile table is prospectively fixed from the accepted
P5M.1-R1 report:

| Profile ID | Authored friction | Characterized coefficient | Role |
| --- | ---: | ---: | --- |
| `godot_jolt_p5m1r1_mu000_v1` | `0.00` | `0.00` | fail-safe negative control |
| `godot_jolt_p5m1r1_mu020_v1` | `0.20` | `0.17` | lower diagnostic |
| `godot_jolt_p5m1r1_mu040_v1` | `0.40` | `0.38` | lower diagnostic |
| `godot_jolt_p5m1r1_mu060_v1` | `0.60` | `0.58` | primary |
| `godot_jolt_p5m1r1_mu080_v1` | `0.80` | `0.79` | primary |
| `godot_jolt_p5m1r1_mu100_v1` | `1.00` | `0.99` | primary |
| `godot_jolt_p5m1r1_mu180_v1` | `1.80` | `1.00` | primary legacy-authored cell |

The pre-P5M legacy profile remains separately identifiable as
`godot_jolt_legacy_mu180_d3d5cd1_v1`. It preserves historical P5I
configuration identity and the same `1.00` controller coefficient, but it is
not a substitute for the P5M.1-R1 profile in the cold material campaign.

Required fields are:

- `profile_id`;
- `adapter_id`;
- physics engine and exact solver configuration;
- authored body material;
- authored ground material;
- declared material-combine rule;
- measured breakaway bracket per replicate;
- conservative `characterized_friction_coefficient`;
- characterization source commit;
- characterization report path and SHA-256;
- whether the authored value lies outside the host's documented range;
- `cross_engine_equivalent = false`;
- `locomotion_robustness = false`; and
- `completed_sdk = false`.

The Godot adapter must fail closed before constructing or actuating a world
when:

- the profile schema or ID is unknown;
- the profile's authored material differs from the compiled fixture material;
- its engine or solver identity differs from the realized host;
- its source/report identity differs from the checked-in table;
- its coefficient is nonfinite or negative; or
- the adapter would fall back to the legacy `1.0` coefficient for a nonlegacy
  material.

The portable core receives only the characterized coefficient and declared
provenance fields already owned by the centroidal request. Godot's
`rough`/`absorbent` flags and combine rule remain adapter provenance.

P5M.2 requires pure/profile tests and one zero-actuation Godot construction
test per profile before P5M.3 may open.

### P5M.2 implementation and prospective acceptance gate

The implementation is:

- immutable profile table and validator:
  `scripts/lab/gait/sdk_godot_jolt_material_profiles.gd`;
- fail-closed host selection:
  `scripts/lab/gait/physical_wave_gait_quadruped.gd`;
- adapter revalidation, selected-coefficient use, and manifest v10 publication:
  `scripts/lab/gait/sdk_godot_jolt_adapter.gd`;
- zero-world conformance:
  `tests/test_sdk_godot_jolt_material_profiles.gd`; and
- isolated evidence runner:
  `sdk/run_godot_jolt_material_profile_conformance.ps1`.

The test resolves all eight independently identifiable profiles, constructs
their exact Godot `PhysicsMaterial` resources, starts nine adapter instances
(eight explicit and one legacy-default compatibility instance), and verifies
the selected record and canonical digest in each adapter manifest. It performs
zero gait samples, emits zero commands, applies zero actuation, and constructs
zero physics worlds. Unknown IDs, fixture mismatch, solver mismatch, and
tampered resolved records must all fail closed.

The prospective receipt is:

```text
sporespore_godot_jolt_material_profile_receipt_v1
19/19 gates
8/8 immutable profiles
9/9 adapter starts
0 physics worlds
0 gait samples
0 commands
```

The first clean, pushed P5M.2 run retained by the runner is the only acceptance
result. Dirty-worktree development runs are parser and implementation checks,
not acceptance evidence. P5M.3 remains closed until the clean report is
retained and its exact path and digests are recorded here.

### P5M.2 result — passed

Clean pushed source
`3d7e5d9e7e4092014fb84f57b1ef19acd7397cff` passed the first eligible
P5M.2 run at `19/19`. The retained evidence is:

- report:
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-material-profiles-3d7e5d9\report.json`;
- report SHA-256:
  `31892f82d188c0d43726c78ab829e3b1a3925b011748fb5a9621ca0fb6740a6d`;
- transcript SHA-256:
  `a0493ff5ea612407e08f302d3b70ac85f5a0901ea3c4bc12e00886a71c50522d`;
  and
- engine-log SHA-256:
  `8d2dd8c9b8a3235745e508af1a57a97da3906a9ee008f4837ce98bc5b70f38e1`.

The report records a clean source equal to `origin/main`, all eight immutable
profiles, nine successful adapter starts, zero physics worlds, zero gait
samples, zero commands, zero actuation, and every preregistered negative claim.
P5M.2 is closed. It does not itself establish locomotion or robustness.

## P5M.3 — cold locomotion matrix

### Frozen controller and body

P5M.3 uses:

- the reference quadruped descriptor and physical fixture;
- the unchanged Candidate 35 base;
- the unchanged P5I.3C-R2 stability policy, runtime, and memory;
- stability-contribution overlay authority only;
- no direct body-state write;
- no change to gait, steering, motor, solver, threshold, or evidence policy;
  and
- the P5M.2 profile matching that cell.

### Frozen perturbation seeds

The unused campaign seeds are:

```text
16001, 16002, 16003
```

Each is compiled by the existing
`compile_seeded_initial_perturbation` function before the world is created.
No seed may be replaced after its result is observed.

### Frozen material cells

The primary discrete robustness cohort is:

```text
0.60, 0.80, 1.00, 1.80
```

All four authored values run all three seeds: `12` primary treatment worlds.
Seed `16001` additionally receives a material-matched no-overlay shadow
control for each primary value: `4` paired controls.

The lower-bound diagnostic cohort is:

```text
0.20, 0.40
```

Both values run all three treatment seeds: `6` diagnostic worlds. These cells
do not weaken the primary acceptance rule. They may join a separately named
extended discrete cohort only if all six pass every treatment gate without a
post-result change.

The `0.00` profile runs seed `16001` as a fail-safe negative control. It is
never a robustness member. It passes its safety role only if the adapter
retains valid provenance, no direct body write, bounded/fail-zero contribution
behavior, and no false walking or robustness claim.

Total frozen P5M.3 worlds: `23`.

The implementation additionally freezes their construction order:

1. for each primary material in `0.60, 0.80, 1.00, 1.80`, treatment seed
   `16001`, its matched shadow control, then treatment seeds `16002` and
   `16003`;
2. diagnostic material `0.20` at all three seeds, then `0.40` at all three
   seeds; and
3. zero-friction treatment seed `16001`.

The exact ordered cell IDs are emitted by the zero-world preflight and retained
unchanged by the full receipt.

### Frozen treatment gates

Every primary treatment world must:

1. construct exactly one world from the requested fixture;
2. match the exact P5M.2 material profile and report identity;
3. retain the exact compiled perturbation seed receipt;
4. complete exactly `1,514` fixed SDK exposure steps;
5. write exactly `12,112` ordered base commands and `12,112` bounded overlay
   commands;
6. apply at least one nonzero effective stability contribution;
7. keep overlay requests and effective deltas inside `0.075 rad/s`;
8. keep contribution slew inside `0.010 rad/s/step`;
9. keep combined target speed inside the frozen base limit;
10. keep motor readback error at most `2e-8 rad/s`;
11. keep host binary32 quantization error at most `1.2e-7 rad/s`;
12. retain zero mapping, order, limiter, profile-conversion, inactive-zero,
    infeasible-fallback, and overlay-application failures;
13. retain zero direct torso or body-state writes;
14. pass every ordinary Candidate 35 physical walking gate;
15. preserve finite contact, support, joint, and material receipts; and
16. keep improvement, recovery, terrain, push, sensor, morphology,
    cross-engine, physical-acceptance, and completed-SDK claims false.

Each of the four paired seed-`16001` cells must start from matching transforms,
velocities, gait phase, material, controller, thresholds, and solver identity.
It must show terminal torso-position separation of at least `1e-5 m` between
shadow control and overlay treatment. This retains causal influence over the
tested material cohort; it is not an improvement gate.

The primary result passes only at `12/12` treatment worlds, `4/4` matched
controls, and every frozen gate. Cell averaging is forbidden.

### P5M.3 implementation and zero-world preflight

The prospective harness and runner are:

- `tests/test_sdk_godot_jolt_material_robustness.gd`; and
- `sdk/run_godot_jolt_material_robustness.ps1`.

The walker change is confined to
`scripts/lab/gait/physical_wave_gait_quadruped.gd`: fixed P5I.3C exposure now
initializes native gait memory with the already-active seeded phase offset and
uses that same offset in every legacy/native parity comparison. It does not
change Candidate 35, the gait clock, feedback gains, contribution limits,
walking thresholds, or any fixture other than the requested contact material.

The zero-world preflight is invoked with:

```powershell
pwsh -NoProfile -File .\sdk\run_godot_jolt_material_robustness.ps1 `
  -PreflightOnly
```

It verifies, without opening an outcome:

- exactly `23` ordered cells: `12` primary treatments, `4` matched controls,
  `6` diagnostics, and `1` zero-friction control;
- exact profile/fixture pairs for all seven P5M.1-R1 materials;
- exact immutable profile and characterization-report identities;
- exact seed receipts for `16001`, `16002`, and `16003`;
- seeded phase offsets `0`, `+2`, and `-1` through both initial-memory and
  ongoing parity paths;
- both shadow and overlay material-profile option schemas; and
- the unchanged GQ15 clock and Godot/Jolt `120 Hz, 20/7` policy.

The preflight receipt is
`sporespore_godot_jolt_material_robustness_preflight_receipt_v1`. It records
zero worlds, zero actuation, and `locomotion_outcome_exposed = false`.

The first full clean receipt is
`sporespore_godot_jolt_material_robustness_receipt_v1` with `32` aggregate
gates. The runner refuses full mode without a durable `report.json` output,
refuses dirty or non-`origin/main` sources before opening any outcome, rechecks
the same source afterward, and refuses to overwrite evidence. A full-run crash,
missing receipt, or malformed receipt is retained as a rejected partial result
with the raw transcript and engine log rather than discarded.
Lower diagnostics are always retained and classified but do not weaken or
reject the primary cohort solely for missing a walking gate. They join the
extended discrete cohort only at `6/6`.

### P5M.3 stopping rule

The first source-clean complete `23`-world matrix is the only eligible P5M.3
result. Any primary miss rejects that source. A diagnostic miss cannot be
hidden, replaced, or used to narrow the already-frozen primary cohort. There
are no selective cell reruns or post-result threshold edits.

### P5M.3 first result — rejected and retained

Clean pushed source
`8badd0a57384a2aa8f2b8ca9231e81cff871715f` completed all `23/23`
frozen worlds and was rejected at `5/32` aggregate gates. The retained
evidence is:

- report:
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-material-robustness-8badd0a\report.json`;
- report SHA-256:
  `2786cf0865657ac8f62976e836d3d99cbdc0934ab139edceb6d5537ac4e4cec4`;
- transcript SHA-256:
  `1c4801fb03221a5d2bbbd3d5bb8030f882ea3ff06162ba02c31a9062ae782e45`;
  and
- engine-log SHA-256:
  `ab027f901398a54fc6f136e367f4f105b9b9147209292545d11bc173ea426ffb`.

The source and post-run worktree were clean and equal to `origin/main`.
The receipt records `0/12` primary treatments, `1/4` controls, `0/4`
paired-causal gates, `0/6` classified diagnostics, and `0/1` zero-friction
safety gates.

This rejection exposed two adapter-boundary defects:

1. all `19` treatment worlds failed closed with
   `ADAPTER_NATIVE_SAFE_NO_ACTUATION:FRAME_INVALID`. The seeded, nonzero
   fixture yaw crosses Godot's `real_t` vector boundary before the task-frame
   axes reach the binary64 core. The observed normalized lateral-axis
   squared-norm errors are above the core's strict `1e-9` unit-vector
   tolerance. The adapter already provides binary64 scalar renormalization
   for other portable unit vectors but did not use it for the task frame.
2. ten worlds observed a total of `110` steps with two qualified support
   contacts. The contribution bridge returned
   `CONTRIBUTION_SUPPORT_COUNT_INELIGIBLE:2` as an execution failure instead
   of using the core's typed `observation_unavailable` path to apply an
   immediate ordered zero fallback.

The retained matrix also exposed a gate defect. The one nominally passing
shadow control did not establish a valid Candidate 35 execution: the control
gate accepted zero mismatches without requiring the adapter summary to be
`ok`, the safe-no-actuation count to be zero, or all `12,112` commands to
have been compared. That control result is therefore vacuous and authorizes
no claim.

No material value, seed, controller branch, feedback gain, limiter, walking
threshold, or cohort boundary was changed after this result. P5M.3 remains
open and no material-robustness claim is authorized.

### P5M.3-R1 prospective amendment

This amendment is frozen before implementation and before another outcome is
opened. It addresses only the two adapter-boundary defects and the vacuous
control gate exposed by the complete `8badd0a` matrix.

The R1 implementation must:

1. serialize the already-normalized Godot task-frame forward and lateral axes
   through the adapter's existing binary64 scalar-renormalization helper
   before they enter the strict portable core;
2. leave the core's `1e-9` unit-vector tolerance unchanged;
3. classify fewer than three qualified support contacts as the typed
   `observation_unavailable` stability-influence state;
4. pass that state through the existing portable influence limiter so all
   eight ordered actuator contributions become exact zero immediately,
   bypassing slew from any preceding nonzero contribution;
5. retain the unavailable observation as a completed, typed mapping sample
   rather than silently omitting it from the sample partition; and
6. preserve zero direct body-state writes and motor-target-velocity-only
   authority.

R1 may change no Candidate 35 formula or branch, gait phase, feedback gain,
contribution magnitude or slew bound, controller/material coefficient,
fixture, material profile, seed, solver setting, walking threshold, cohort
boundary, cell order, or causal-separation threshold.

The R1 common execution gate must additionally prove:

- `safe_no_actuation_count == 0`;
- all `12,112` Candidate 35 actuator commands were actually compared;
- the adapter started without a typed failure;
- every one of the `1,514` contribution samples belongs to exactly one of
  `available`, `upstream_infeasible`, or `observation_unavailable`;
- all three contribution states emit eight ordered bounded outputs, for
  `12,112` total outputs;
- the exact-zero fallback count is
  `8 * (upstream_infeasible_count + unavailable_count)`; and
- mismatch, limiter, profile-conversion, inactive-zero, untyped, and
  application-failure counts remain zero.

A shadow control must additionally require the whole adapter summary to be
`ok`, zero Candidate 35 mismatches, and zero native writes. A treatment may
retain only the already-declared dynamic Candidate 35 parity divergence caused
after the bounded overlay physically changes its world; it may not retain a
safe-no-actuation, transport, frame, schema, order, or start failure.

The R1 receipt schemas are:

```text
sporespore_godot_jolt_material_robustness_r1_preflight_receipt_v1
sporespore_godot_jolt_material_robustness_r1_receipt_v1
sporespore_godot_jolt_material_robustness_r1_report_v1
```

The zero-world preflight must exercise all three seeded nonzero-yaw task
frames through the binary64 unit-vector serializer and prove unit length and
orthogonality at the core tolerance. It must also prove an unavailable
contribution produces eight exact-zero outputs with fallback and
slew-bypass receipts.

After implementation and ordinary regression, R1 must rerun the complete
unchanged ordered `23`-world matrix from a new clean source equal to
`origin/main`. The first such complete R1 matrix is retained whether accepted
or rejected. There are no selective reruns.

### P5M.3-R1 result — rejected and retained

Clean pushed source
`ac52b5cb7af46a419c5f661025929a8577b37cd0` completed all `23/23`
unchanged R1 worlds. The durable report is:

- report:
  `C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\godot-jolt-material-robustness-r1-ac52b5c\report.json`;
- report SHA-256:
  `7c58a73df1187076087e1c2f47536030b8a1e9536b157ea8d6b7818f9bf6a0ef`;
- transcript SHA-256:
  `e7ac296d4f72b270249f850a1a9ddf009c06c907470219edbb5500712a41740d`;
  and
- engine-log SHA-256:
  `493c7efeb849a4cbc43764dce3f7ead24befdb04f9de982de2b4b0a8de98ef4f`.

The report records a clean source equal to `origin/main`, `28/32` aggregate
gates, `11/12` primary treatments, `3/4` matched controls, `4/4` paired causal
separations, `6/6` lower-friction diagnostics, and `1/1` zero-friction safety
controls. The exact primary cohort is therefore rejected. The passing
diagnostic and safety partitions remain observations inside a rejected
aggregate; they do not independently authorize a material-robustness claim.

R1 repaired both adapter-boundary defects from the first matrix. All `23`
worlds:

- started the adapter without a typed start failure;
- compared all `12,112` Candidate 35 actuator commands;
- retained zero safe-no-actuation starts;
- partitioned every contribution observation;
- emitted all `12,112` ordered bounded influence outputs;
- retained exact-zero typed fallbacks;
- retained zero mapping, limiter, profile-conversion, inactive-zero, untyped,
  and overlay-application failures; and
- retained zero direct body-state writes.

Two independent preregistered gates still failed:

1. `primary_mu060_s16001_control` physically walked but accumulated `308`
   dynamic Candidate 35 parity mismatches beginning at semantic step `540`.
   Its configuration identity and paired initial pose were exact, all `12,112`
   commands were compared, and its safe-no-actuation count was zero. The
   strengthened control rule correctly rejected it rather than accepting a
   vacuous parity result.
2. `primary_mu080_s16003_treatment` retained common SDK execution integrity,
   completed `1,514` steps, and ended with `1.1579968929290771 m` forward
   displacement, `0.03708778694272041 m` lateral displacement, maximum tilt
   `0.109424134014366 rad`, maximum anchor error
   `0.0201901141554117 m`, and maximum hinge-axis error
   `0.0879834032607998 rad`. It failed only the frozen
   `evidence_four_contact_stance` walking receipt. That miss remains a real
   primary-cell rejection under the prospective contract.

The four paired treatment/control terminal separations were
`0.08523132652044296`, `0.10668525099754333`,
`0.055721465498209`, and `0.1490952968597412 m`; all exceeded the frozen
causal-influence floor. This establishes physical influence over those exact
pairs, not balance improvement, recovery, or robustness.

No material, seed, Candidate 35 branch, controller gain, contribution bound,
walking threshold, or cohort membership changed after the result. The R1
matrix may not be selectively rerun or converted into a pass by removing the
failed cells. P5M.3 is a complete negative result for this Candidate
35-plus-P5I.3C-R2 controller.

## P5M.4 claim boundary

If P5M.1 through P5M.3 pass, the repository may claim only:

- Godot/Jolt material profiles bind authored values to source-pinned measured
  breakaway behavior;
- the unchanged bounded stability-overlay walker passed the exact discrete
  primary material cohort
  `{0.60, 0.80, 1.00, 1.80}` under seeds
  `{16001, 16002, 16003}`; and
- the zero-friction cell exercised the declared fail-safe boundary.

If every `0.20` and `0.40` diagnostic world also passes, the repository may
add those exact values to an explicitly named extended discrete cohort.

It may not claim:

- a continuous friction interval;
- arbitrary materials, combine rules, restitution, compliance, adhesion, or
  anisotropy;
- equivalent behavior in Rapier, MuJoCo, or another host;
- rough-terrain robustness;
- external-push recovery;
- sensor-noise or latency robustness;
- balance improvement or recovery;
- fresh-morphology robustness;
- Candidate 35 generality;
- physical full-volume coverage; or
- a completed engine-neutral SDK.

## Ordered next action

Do not patch Candidate 35, edit the P5M.3/R1 thresholds, or reopen either
retained matrix. Reconcile the post-C6 audit against the current source and
freeze a new controller-successor contract whose acceptance does not depend on
adding another failure-shaped Candidate 35 branch. That successor must use
separate development and cold partitions, retain friction/material as an
independent nuisance axis, and clear a newly preregistered Godot/Jolt material
campaign before Rapier or MuJoCo cross-engine C6 is opened.

That successor is now the branch-free BW2R-C policy recorded in
`docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md`. Its independent BW3R
validation passed before BW4 opened. The first BW4 cold characterization also
passed `23/23` gates across `13/13` worlds from source
`4de55aa4521afa9ed2cd596199d809a0781b8ba2`; its retained source of truth is:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw4-material-characterization-4de55aa\report.json
sha256:f4a7291849d53540f31d58f40be97f26f01ad9cb76a2e2ae6fedabd56e0925c3
```

That report is characterization, not locomotion acceptance. Its four immutable
profiles were subsequently published from clean pushed source
`d58dfdabb2b634b061f40fb8556ad6b60e2e87d0`:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw4-material-profiles-d58dfda\report.json
sha256:61ecbc8bb853dd6abace6f5d4f356c79f3b9cfab304bec47b6daf1f9476292e6
```

The publication passed `29/29` zero-world gates over all `18` immutable
profiles and `19` adapter starts. Only an accepted `17`-world BW4 locomotion
matrix may establish bounded, discrete Godot/Jolt material robustness for
those exact values; profile publication still cannot establish continuous
friction coverage, arbitrary material robustness, or cross-engine C6.

That locomotion matrix is now frozen in
`sdk/balanced_wave_bw4_validation_manifest.json` and executable through
`sdk/run_balanced_wave_bw4_validation.ps1`. Its zero-world preflight passed.
The `0.00` safety cell is shadow-only and requires zero SDK-native motor writes;
the positive cohort remains exactly `{0.15, 0.50, 0.90, 1.40}` under seeds
`{18001, 18002, 18003}`. The first complete clean pushed result is final for
its source identity whether it passes or fails.

The first complete result was retained from source
`83c61423296030a336f5acc9d82a236866cf2003`:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw4-validation-83c6142\report.json
sha256:539f0a724470723b445ea3ade443d8125e9934593b456a64898843d33938d550
```

It was rejected at `27/28`: all `17` worlds were retained, all four controls,
all four causal pairs, and the zero-write safety control passed, but only
`11/12` positive treatments passed ordinary walking. The sole miss was
`validation_mu140_s18001_treatment`, whose legacy world-Z lateral proxy
reached `-0.146095871925354 m` against the frozen `0.10 m` ceiling. No
material-robustness claim follows, and this matrix may not be selectively
rerun or weakened.

The successor contract is now
`sdk/balanced_wave_bw4r_preregistration.json`. BW4R-A/B change only the
portable feedback update cadence and an optional global per-step steering slew;
they add no friction/material/morphology/seed branches. Before their first
physics world, the future gate was corrected from the historical world-X/Z
proxy to explicit frozen task-frame projection while retaining the same
`0.10 m` ceiling. Each candidate must run the identical `58`-world opened
development matrix, including all `17` BW4 cells; no early stop or failed-cell
replacement is permitted.

The exact runner/compiler pair is:

```powershell
.\sdk\run_balanced_wave_bw4r_development.ps1
.\sdk\compile_balanced_wave_bw4r_selection.ps1
```

All reports go under
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence`. Even a selected candidate
must still pass separately characterized, disjoint validation and cold
friction partitions before any discrete material-robustness claim. Continuous
friction, arbitrary materials, and cross-engine C6 remain blocked.

The complete BW4R comparison ran from source
`b538bea3656600fcd56f94cb62a8391a0a932bb0`. The source-bound compiler
verified all `116/116` worlds, ten input reports, two complete `58`-world
candidates, and zero execution/integrity failures. It rejected the whole
candidate family because both candidates had positive-treatment nonwalks in
the opened BW4 replay:

- BW4R-A: `3/12` opened-BW4 treatment nonwalks and `8` nonwalks across all
  opened nonzero-material treatment partitions;
- BW4R-B: `1/12` opened-BW4 treatment nonwalk and `10` nonwalks across all
  opened nonzero-material treatment partitions.

The retained selector is:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw4r-selection-b538bea\report.json
sha256:23bc6f88c46cbed8b848efd9b2663757fd2f33c5c2f9d260e69e4ddc35d6718b
```

The result grants no development-selection authority and leaves walking,
material robustness, continuous friction coverage, physical balance recovery,
cross-engine C6, and completed-SDK claims false. The reserved validation
values/seeds and later cold values/seeds remain unopened. Another physical
campaign requires a new prospectively frozen, branch-free policy identity;
neither rejected source may be rerun or weakened.

That new identity is now frozen as BW5R in
`sdk/balanced_wave_bw5r_preregistration.json`. It applies one global
cycle-normalized first-order low-pass filter to the already bounded per-step
feedback request. BW5R-A/B/C use `1/32`, `1/16`, and `1/8` cycle time
constants respectively; all other controller and host-profile fields remain
inherited from BW2R-C. Friction, material profile, morphology, seed, cohort,
failed cell, and outcome are forbidden as filter conditions.

The design is sourced to DReCon's deterministic-reference plus bounded,
recursively filtered correction pattern:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore\DReCon.pdf
sha256:aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54
DOI:10.1145/3355089.3356536
relevant pages:5-7
```

No paper-specific numeric coefficient, learned policy, or empirical result is
imported. The preregistration binds all three policy/profile digests, every
filter diagnostic, a complete `174`-world opened-development comparison, and
new disjoint validation/cold reservations before world one. Until that
complete selection and the later disjoint partitions pass, discrete material
robustness, continuous friction coverage, physical balance recovery, and
cross-engine C6 remain blocked.

The complete source-bound comparison ran from
`d17b77afefddb19ae401f3f8f2e8b3b7708a02e6` and retained all `174/174`
worlds, all `15` reports, and zero infrastructure/integrity failures:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5r-selection-d17b77a\report.json
sha256:d2819d1bca45592fe54f1fc22cd2ad19d64fb3cd9eafd8ad848601338f8b50fc
```

BW5R-A and BW5R-B each cleared all `12/12` opened-BW4 positive treatments;
BW5R-C cleared `11/12` and was ineligible. BW5R-B won the next
preregistered metric with two opened nonzero-material treatment nonwalks,
versus A's three. It is now the development-selected policy:

```text
BW5R-B
sporespore_balanced_wave_bw5r_b_v1
sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f
```

That selection is not a material-robustness result. The selected candidate's
two nonwalks were both authored-friction `0.80` opened-development cells.
BW5R-B must now face the separately characterized and previously unopened
validation values `{0.05, 0.65, 1.30}` under seeds
`{19501, 19502, 19503}`. Only after independent validation passes may the
reserved cold values `{0.12, 0.48, 0.95, 1.50}` and seeds
`{20001, 20002, 20003}` open.

BW5V now freezes that next material boundary in
`sdk/balanced_wave_bw5v_preregistration.json`. Its no-world preflight passes
`6/6` and verifies the exact BW5R-B policy/profile binding, the complete
selector at
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5r-selection-d17b77a\report.json`
(SHA-256
`d2819d1bca45592fe54f1fc22cd2ad19d64fb3cd9eafd8ad848601338f8b50fc`),
all four isolated sled fixtures, validation seeds `19501`-`19503`, and the
unopened cold reservation. It builds no world and opens no physical outcome:

```powershell
.\sdk\run_balanced_wave_bw5v_material_characterization.ps1 -PreflightOnly
```

After this source identity is committed and pushed, the first retained
characterization owns exactly `10` worlds and `19` gates: three replicates at
each of `0.05`, `0.65`, and `1.30`, plus one zero-friction control. Its only
permitted downstream effect is publication of immutable Godot/Jolt adapter
profiles before a separate validation-manifest freeze. Characterization alone
does not establish friction/material locomotion robustness.

The first eligible characterization completed from clean pushed source
`2a5eb94dca81a8c638e31a0d7c9692c270b44ca6` at `10/10` worlds and
`19/19` gates:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5v-material-characterization-2a5eb94\report.json
sha256:a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84
```

Its prospectively frozen floor-to-two-decimal derivation yields controller
coefficients `0.05`, `0.63`, and `1.00` for authored values `0.05`, `0.65`,
and `1.30`. The three immutable adapter-profile records bind that report and
pass the expanded `32/32`, `21`-profile, zero-world conformance gate. This
remains adapter characterization; no locomotion result or robustness claim has
opened.

The eligible profile publication is retained at:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5v-material-profiles-e76477b\report.json
sha256:2430c1a77d7007c13c3a5262e19fba7693154ba40ea61aa3d1cf601844a2a37c
source:e76477be61d90829dab0eb70a89505d521e7f8a5
```

The separate locomotion contract is now frozen in
`sdk/balanced_wave_bw5v_validation_manifest.json` and executed through
`sdk/run_balanced_wave_bw5v_validation.ps1`. Its no-world check is:

```powershell
.\sdk\run_balanced_wave_bw5v_validation.ps1 -PreflightOnly
```

It validates the exact `12`-world order, `9` treatments, `3` matched controls,
`3` causal pairs, `22`-gate all-or-nothing contract, policy/profile/evidence
hashes, and unopened cold reservation while building zero worlds. The first
complete source-clean result is final for that source identity whether it
passes or rejects. The later cold partition remains mandatory before any
discrete material-robustness claim.

The first eligible complete result passed from source
`7d8b046f752974b8d9498db91b0d46ae99ac1729`:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5v-validation-7d8b046\report.json
sha256:a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee
```

It completed `12/12` worlds and passed `22/22` gates, all `9/9` treatment
walking gates, all `3/3` control shadow gates, all `3/3` identity-matched
causal pairs, and zero execution/integrity failures. This is accepted
independent development validation for `{0.05, 0.65, 1.30}` only. It does not
convert those cells into cold evidence or authorize interpolation,
continuous-friction coverage, arbitrary-material robustness, balance
recovery, or cross-engine C6.

## BW5C cold material characterization

The accepted BW5V report is now the immutable prerequisite for the distinct
BW5C cold partition:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5v-validation-7d8b046\report.json
sha256:a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee
```

[`sdk/balanced_wave_bw5c_preregistration.json`](../sdk/balanced_wave_bw5c_preregistration.json)
preserves the two earlier reservation hashes and opens only friction
`{0.12, 0.48, 0.95, 1.50}` with later locomotion seeds
`{20001, 20002, 20003}`. The isolated sled fixture is
`SDK.BW5C.godot_jolt_material_sled.v1`. Its frozen characterization is
`13` worlds and `23` gates; the later, separately frozen locomotion campaign
is `17` worlds and `28` gates.

The source-only, zero-world check is:

```powershell
.\sdk\run_balanced_wave_bw5c_material_characterization.ps1 -PreflightOnly
```

It must pass `6/6` with five exact fixture receipts, zero world builds, zero
SceneTree insertions, and no opened physical outcome. A full run is permitted
only after the implementation and preregistration are committed, pushed, and
identical to `origin/main`. The first full report for that source identity is
final whether it passes or rejects; selective replicate reruns and
post-result gate changes are forbidden.

Characterization is an adapter measurement, not locomotion evidence. Even a
`23/23` result only permits immutable material-profile publication. The cold
material claim remains false until the later `12` treatments, `4` matched
controls, `4` causal pairs, and zero-friction zero-write control all satisfy
the frozen `28/28` contract.

The first complete characterization has now passed `23/23` gates across
`13/13` worlds from physics source
`dca2618bd1cb42768235bc69711eb3dab6b2379a`:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5c-material-characterization-dca2618\report.json
sha256:067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143
```

The command host interrupted only outer packaging after Godot started. The
original Godot process finished all worlds and emitted one complete receipt
to `engine.log`; no physics rerun occurred. The report records physics source
`dca2618`, packaging/finalizer source `2dc17b5`, the complete engine-log hash,
and the partial command-host transcript hash separately.

The frozen floor-to-two-decimal derivation produced coefficients `0.10`,
`0.45`, `0.94`, and `1.00`. The immutable BW5C profiles are now present in
[`scripts/lab/gait/sdk_godot_jolt_material_profiles.gd`](../scripts/lab/gait/sdk_godot_jolt_material_profiles.gd),
and their zero-world conformance passes `36/36` over `25` total profiles.
This still does not open or pass cold locomotion.

The retained profile-publication report is:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5c-material-profiles-677e97e\report.json
sha256:381132c430140ec4b70a1cff65d7099974bf1b6eefa59bafa523c1b287076c97
source:677e97e140e2408fe56612896d794cc13aae1c64
```

The separate locomotion freeze is now explicit in
[`sdk/balanced_wave_bw5c_validation_manifest.json`](../sdk/balanced_wave_bw5c_validation_manifest.json)
and executable through
[`sdk/run_balanced_wave_bw5c_validation.ps1`](../sdk/run_balanced_wave_bw5c_validation.ps1):

```powershell
.\sdk\run_balanced_wave_bw5c_validation.ps1 -PreflightOnly
```

Its zero-world preflight binds the exact `17` cells and `28` gates and passes
without exposing locomotion outcomes. The full one-shot result, not this
preflight, decides bounded discrete cold material robustness for BW5R-B on
Godot/Jolt.

That deciding one-shot result passed from clean pushed source
`dac405df52abfda12f5633022e6814b02f561a3e`:

```text
C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\balanced-wave-bw5c-validation-dac405d\report.json
sha256:6648c1473c97d2b7229ba0decd8881ca2d8f06e68ca9737d7255120dab2653da
```

The complete outcome is `28/28` gates and `17/17` worlds: all `12/12`
treatments passed ordinary walking gates with nonzero stability influence,
all `4/4` material-matched controls passed shadow gates, all `4/4`
identity-matched causal pairs retained nonzero terminal separation, and the
zero-friction control retained zero native motor writes and no walking claim.
There were zero execution/integrity failures.

The accepted scope is bounded and discrete: BW5R-B, Godot/Jolt, the reference
fixture, the pinned `120 Hz` and `20/7` solver settings, friction
`{0.12, 0.48, 0.95, 1.50}`, and seeds `{20001, 20002, 20003}`. This report
does not claim continuous friction, arbitrary materials, other morphologies,
recovery, nuisance robustness, or another physics engine.
