# Post-C6 SDK Audit: Friction, Stability, Adapters, and Candidate 35

- **Status:** live-code audit complete; prospective roadmap input
- **Audited source:** `a4fde2f01658b80d52caf8ca7304a280a2384e4c`
- **Current accepted remediation through:** `03f36ec58be6c10fdd451db9c278142d54a5f5d0`
- **Date:** 2026-07-28
- **Scope:** the generated quadruped walker, portable SDK, retained C6/C6R
  evidence, and the four claims supplied after C6
- **Decision authority:** this audit may constrain a successor; it may not
  rewrite GQ15, C6, or C6R

## Executive decision

The four claims contain three important blockers and several material
overstatements.

| Claim | Live-code verdict | Consequence |
| --- | --- | --- |
| Generated walking never varied friction | **True for GP/GS/GQ and SDK locomotion; false project-wide** | A fresh friction/material axis is required before any robustness or completed-SDK claim. Existing friction fixtures characterize contact behavior but do not establish locomotion robustness. |
| The portable controller has no balance feedback | **True** | Port the commissioned support observers/allocator semantics into an engine-neutral stability layer and connect them to the authority-bearing controller before another cross-engine locomotion campaign. |
| There is only one physical adapter | **True** | Add Rapier as the second host and MuJoCo as the third, independently clearing C0-C5 before locomotion. |
| Candidate 35 is finer than the data that produced it and GQ15 never froze its topology | **Mixed** | The overfit risk is real and C6R exposed long-horizon brittleness. The claimed regular 25%-spaced lattice, `0.27586` provenance, and absence of a topology freeze are not supported by the repository. Candidate 35 must be retained as a legacy oracle rather than extended through more failure-shaped branches. |

The table is a verdict on the audited snapshot. It is not silently rewritten
as implementation proceeds. The one-adapter finding was addressed after the
audit by Rapier source commit
`4ce6a47c6410cc7977d49b807b6af280fc0e6b83`: its retained C2-C5 report passes
`4/4` cells at
`<evidence-root>\rapier-c2-c5-4ce6a47\report.json`
(SHA-256
`35982b3e29ade9ffb98c877b304316aea6718d0fe0a4a60062b2e47754b93057`).
MuJoCo source commit
`4578a568844554965efdf4598fbb9c4e7b8f0389` subsequently added the third
C0-C5 host. Its retained `5/5`-cell report is
`<evidence-root>\mujoco-c0-c5-4578a56\report.json`
(SHA-256
`ca8d74cd056a735208977f05d96cfd1c08dc13bd7279682af7c8f73ce02bf03d`).
These adapter results address the audited adapter-count blocker at C0-C5.
They do not address portable balance, locomotion friction robustness,
cross-engine C6, or SDK completion.

### Current resolution after BW2 selection

The snapshot verdicts above remain part of the audit trail, but they are not
the current repository state. At source
`61937f46c37c831a6e2a9d5c7da781929bc6382f`:

- **friction is no longer a frozen axis:** BW2-A/B/C executed `69` retained
  material worlds over authored friction values `0.00`, `0.20`, `0.40`,
  `0.60`, `0.80`, `1.00`, and `1.80`; however, selected BW2-C retained one
  eligible nonzero-friction treatment nonwalk, so material robustness remains
  unaccepted;
- **portable balance machinery and a Godot/Jolt authority connection now
  exist:** whole-system support observation, centroidal allocation,
  full/partial joint mapping, bounded influence, and selected balanced-wave
  physical authority are implemented; balance improvement, recovery, and
  cross-engine authority remain unproven;
- **three adapters exist and clear their declared C0-C5 slices:** Godot/Jolt,
  Rapier/Parry, and MuJoCo; Rapier and MuJoCo C6, controller-policy authority,
  material/actuator characterization, and physical locomotion acceptance
  remain false; and
- **Candidate 35 is no longer the successor path:** it is sealed as a legacy
  oracle, while selected BW2-C has no morphology branch surfaces. The
  failure-shaped-policy concern remains a valid limitation on Candidate 35
  evidence, but it is not a reason to add another Candidate 35 branch.

The fail-closed BW2 selection report covers `87/87` development worlds and
selects BW2-C with first-five score vector `0,1,0,0,1`:

```text
<evidence-root>\balanced-wave-bw2-selection-4c42c2d\report.json
sha256:f307a8e51054a98a75fb580a54299f030700a11d22d1801196ff2719fe85d4ea
```

This resolves the literal “no friction,” “no balance code,” “one adapter,” and
“Candidate 35 must remain production authority” premises. It does not resolve
the scientific gates they were trying to protect. Before a future
cross-engine C6 can open, BW3/BW4 material evidence, Godot/Jolt
terrain/push/observation-fault evidence, and per-host Rapier/MuJoCo material,
actuator, and selected-policy authority receipts must exist under
prospectively frozen gates.

The independent BW3 material ladder then accepted `19/19` gates over `10/10`
worlds at source `60df802344884dde466d104513e279b7a89de1cd`; its report is
`<evidence-root>\balanced-wave-bw3-material-characterization-60df802\report.json`
(SHA-256
`94d3d9b6b2dc9086c4e21840540d8faf8d2fb7f64d915bc809d8969e9accd2e7`).
Source `03f36ec58be6c10fdd451db9c278142d54a5f5d0` published the resulting three
immutable Godot/Jolt profiles; their zero-world `22/22` report is
`<evidence-root>\balanced-wave-bw3-material-profiles-03f36ec\report.json`
(SHA-256
`1f829a4ece0b5a7256de7ae22e04fa866f88c372459a49356ffcde5f5e368934`).
This strengthens the friction provenance materially, but still grants no gait
or robustness claim. The separate prospective locomotion-validation identity,
profiles, seeds, 12 ordered worlds, 22 gates, prerequisite paths/hashes, and
nonclaims are frozen in `sdk/balanced_wave_bw3_validation_manifest.json`.

That first validation ran from source
`81acb534fd4564074d13d6cc0dd802e39e4484a6` and rejected at `21/22` gates,
despite zero execution-integrity failures, `9/9` nonzero-influence treatments,
`3/3` controls, and `3/3` causal pairs. The sole behavioral counterexample was
`validation_mu070_s17002_treatment`, which ended at `0.1356338263 m` lateral
displacement against the unchanged `0.10 m` bound. Its retained `12/12`-world
report is
`<evidence-root>\balanced-wave-bw3-validation-81acb53\report.json`
(SHA-256
`e3f590c090b3d352b0e2385e0342db98032cb478d136dc811ddeb524c972c9d1`).
This result confirms the audit's substantive generalization concern: the new
friction axis produced a real, previously unseen failure even under the
branch-free successor. It does not rehabilitate Candidate 35 or justify a
material/seed branch. A new policy identity must repeat BW2 before receiving
another BW3 campaign.

Portable-stability source commit
`d4b83f1b3e0579f479f15dcc8b210af558750b5e` subsequently addressed the
audit's missing *pure core machinery* with ordered body/contact state,
whole-system COM reconstruction, gravity-aligned support geometry, linearized
capture observation, bounded centroidal commands, and a fail-zero bounded
influence contract. Its clean-commit `11/11` Rust and `20/20` Godot report is
retained at
`<evidence-root>\stability-v2-d4b83f1\report.json`
(SHA-256
`aea4ecf15d5bccca049d66f666ae4d55c0517ffdbf899d4bee65f399fc526642`).
That resolves only the zero-machinery finding in the audited SDK snapshot.
Godot/Jolt source commit
`c0b130ea24ca82a443b678a3ef7d362ded2d7199` subsequently exposed all three
v2 operations through the C ABI, Python binding, and GDExtension and added
live ordered body/contact emission. Its clean-commit same-world report is
retained at
`<evidence-root>\godot-jolt-stability-shadow-c0b130e\report.json`
(SHA-256
`4f48b8e7a4c46452ba5c67006bb8e13e43a0a6ba25eba09e30c421a42b7acf74`).
It passes `16/16` gates with `1,514/1,514` observations available and zero
native/GDScript observer mismatches.

That closes the adapter-emission and observation-shadow prerequisites, not
the balance finding itself. Portable source
`f399edec4372701e374e0366d5d027d0e607863c` subsequently added the
engine-neutral endpoint-force/Jacobian-to-generalized-joint-torque map. Its
clean `15/15` Rust and `23/23` GDScript receipt is
`<evidence-root>\stability-v2-joint-map-f399ede\report.json`
(SHA-256
`2cf29aede42db40e233c54d486ad5ebda619cc01f02fc630c26ec327a67bec0a`).

That map is pure virtual-work arithmetic. Godot/Jolt source
`e85cc2fb8b500ced389d8ccc74671671b60cf190` subsequently connected live
ordered state to the zero-gain centroidal allocator and the real portable
mapper in shadow. Its retained clean-source report is
`<evidence-root>\godot-jolt-joint-mapping-shadow-e85cc2f\report.json`
(SHA-256
`2aa5047762a0cbbb7562422682987eb2993da4f21f1540fe0637003bd7d77371`).
It passes `20/20` gates with `1,514` mapping attempts, `821` available
full-support maps, `6,568` independently compared actuator commands, and zero
mismatches. The other `693` attempts are all typed unavailable or infeasible,
not silently dropped.

This live map intentionally uses exact-zero corrective gains and applies no
actuator contribution.

P5I.2 was then frozen in preregistration source
`ca75e62a4ac432485344d205de514dc35bb50f90`, implemented and pushed at
`c816ab36e4b696d8e8073fac88e6570242909609`, and opened once. Its first and
only eligible isolated response run passed `16/16` over three independent
`43`-cell worlds. The report is retained at
`<evidence-root>\godot-jolt-motor-response-c816ab3\report.json`
(SHA-256
`aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729`).
It establishes canonical-to-host sign `-1` and a conservative in-envelope
proposal coefficient of
`0.24999998477941607 rad/s per N m`, with uncertainty
`3.0654117577633144e-8`.

Publication source
`3b54b3f975298c08f00aacb6d1423f7d2897ecd4` pins that profile in the
Godot/Jolt adapter manifest and exposes only a pure fail-closed conversion.
The clean same-world regression passed `20/20` with zero mapping or command
mismatches; its report is retained at
`<evidence-root>\godot-jolt-motor-profile-shadow-3b54b3f\report.json`
(SHA-256
`1aa0f5e20fea276373a8db0c6c22c137de506970057f375f6f70dd07c76d8a5b`).

That source-pinned profile was not yet called by the walker. Subsequent
P5I.3A and P5I.3B-R1 sources completed the partial-support map and full live
contribution shadow. P5I.3C-R2 source
`df6c9e55e2e8eaf9433eba83f70d6031ca186592` then passed its first and only
eligible paired opened-body result at `24/24`. Its retained report is
`<evidence-root>\godot-jolt-stability-physical-influence-r2-df6c9e5\report.json`
(SHA-256
`d0971317d174f7bb5aef4cbea1f79c462182a0cd3e4ce59c83980ef6a7cb305b`).
The treatment made exactly `12,112/12,112` bounded overlay writes and ended
`0.12983563542366028 m` from the no-overlay control while retaining every
frozen walking and safety allowance. That closes the audited physical
connection blocker for this already-opened Godot/Jolt quadruped. It does not
demonstrate balance improvement or recovery, locomotion friction robustness,
fresh-morphology generalization, cross-engine locomotion, or SDK completion.

The friction/material successor then added seven immutable Godot/Jolt material
profiles and opened the frozen `23`-world P5M.3 matrix. Its first result at
`8badd0a57384a2aa8f2b8ca9231e81cff871715f` rejected because of two adapter
boundary defects; that result is retained and was not rewritten. The
prospectively amended R1 source
`ac52b5cb7af46a419c5f661025929a8577b37cd0` repaired those defects and completed
all `23/23` worlds, but the aggregate still rejected at `28/32`: `11/12`
primary treatments, `3/4` matched controls, `4/4` paired causal gates, `6/6`
lower-friction diagnostics, and `1/1` zero-friction safety controls.

The durable R1 report is
`<evidence-root>\godot-jolt-material-robustness-r1-ac52b5c\report.json`
(SHA-256
`7c58a73df1187076087e1c2f47536030b8a1e9536b157ea8d6b7818f9bf6a0ef`).
This resolves the old *friction never varies in locomotion code* observation
but not the material-robustness blocker: the first cold campaign is now a
complete negative result. Its failed `mu=0.80`, seed-`16003` treatment and
`mu=0.60`, seed-`16001` control may not be deleted, replaced, or converted
into a pass by changing a threshold.

These findings do **not** require or authorize another C6 or C6R repair. Both
campaigns are complete negative results under their frozen rules. They do
block broader claims and change the prerequisites for the next locomotion
candidate.

## Finding 1: locomotion friction is frozen

The active quadruped fixture freezes one material:

- `scripts/lab/gait/physical_quadruped_fixture_spec.gd:95-100` declares
  `friction = 1.8`, `rough = true`, `bounce = 0.0`, and `absorbent = true`;
- `tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd:4380-4387`
  requires the generated fixture material to equal the reference material
  exactly;
- `tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd:4299-4318`
  varies placement, yaw, initial linear/angular velocity, and gait phase, but
  has no material field; and
- `sdk/core/src/quadruped.rs:369-373` independently hardcodes the SDK contact
  material coefficient to `1.8`.

Therefore no GP, GS, GQ, Godot/Jolt SDK shadow, native-authority, C6, or C6R
walking world is evidence for friction or material robustness.

The stronger claim that the repository never varies friction is false:

- `tests/test_experimental_l1_1_friction_breakaway.gd` compares `0.0` and
  finite friction and brackets breakaway under a force ramp;
- `tests/test_experimental_l1_2_incline_threshold.gd` exercises an incline
  threshold;
- `tests/test_experimental_br7_1_planar_friction_cone.gd` tests planar
  friction feasibility; and
- `tests/test_experimental_br14a_5_centroidal_support_controller.gd:163-170`
  verifies that a friction-exceeding centroidal command is marked infeasible.

Those are contact-truth, analytic-feasibility, or isolated-fixture results.
They do not close the locomotion robustness gap.

After this audit, source
`d3d5cd1eb47d5fa9dc06106759cce4b01d4c3bd4` prospectively characterized the
exact legacy `1.8`, both-rough material at the SDK's pinned Godot/Jolt
`120 Hz, 20/7` configuration. Its retained report is
`<evidence-root>\godot-jolt-legacy-material-d3d5cd1\report.json`
(SHA-256
`f673eceb7e67a395943ebf7e00927a031d221a60eef371b1505b4a680db8a795`).
Three isolated worlds held through `70 N`, first slid at `72 N`, and yielded
the capped controller input `mu = 1.0`; a frictionless A/B world slid at
`20 N`.

That result supplies exact-host controller provenance only. It does not vary
friction in a gait and therefore does not resolve this finding's locomotion
robustness requirement.

## Finding 2: stability machinery exists but is disconnected from the walker

A live search of `sdk/core/src/*.rs` finds no
`support_margin`, `centroidal`, `balance`, `tilt`, `capture_point`,
`center_of_pressure`, or equivalent runtime controller machinery. The five
`center_of_mass` references are local morphology fields or validation:

- `sdk/core/src/schema.rs:92`
- `sdk/core/src/schema.rs:263-264`
- `sdk/core/src/quadruped.rs:191`
- `sdk/core/src/quadruped.rs:243`

The current runtime in `sdk/core/src/runtime.rs` closes lateral path and yaw
feedback, schedules the four-limb wave, gates phase on contact, and applies
joint position/velocity commands. It does not reconstruct whole-system center
of mass, construct a support hull, compute signed support margin, close
roll/pitch feedback, or allocate a centroidal correction.

The Godot walker is in the same state:

- `scripts/lab/gait/physical_wave_gait_quadruped.gd:21-25` imports the dynamic
  support observer and receipt compiler;
- `scripts/lab/gait/physical_wave_gait_quadruped.gd:1266-1361` samples them
  into a diagnostic trace;
- `scripts/lab/gait/physical_wave_gait_quadruped.gd:1239-1240` measures torso
  tilt; and
- `scripts/lab/gait/physical_wave_gait_quadruped.gd:1478-1485` uses drift,
  yaw, tilt, and height only as post-run gates.

No result from those observers modifies the gait command.

Portable candidates do exist in the mechanics laboratory:

- `scripts/lab/mechanics/spatial_support_margin_observer.gd`
- `scripts/lab/mechanics/spatial_dynamic_support_observer.gd`
- `scripts/lab/mechanics/spatial_centroidal_support_controller.gd`
- `tests/test_experimental_br14a_5_support_margin_observer.gd`
- `tests/test_experimental_br14a_5_dynamic_support_observer.gd`
- `tests/test_experimental_br14a_5_centroidal_support_controller.gd`

`scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd:3054-3164`
actually evaluates the allocator and maps its task-force increments through a
joint-torque path in the dedicated mechanics rig. It is not connected to the
generated walker or Rust runtime.

The phrase "certified support stack" is too strong.
`docs/BR14A_SPATIAL_CONTROLLABILITY_BOOTSTRAP.md:367-472` records commissioned
observers and a rejected protective-contact candidate; its own remaining-cell
table says formal promotion remains open. The accurate conclusion is:
portable-quality support primitives exist and have analytic/fixture coverage,
but the authority-bearing locomotion controller does not consume them.

## Finding 3: only the Godot adapter exists

At the audited commit:

```text
sdk/adapters/
  godot/
```

`sdk/Cargo.toml` contains only:

```toml
members = ["core", "adapters/godot"]
```

No SDK Cargo manifest or lockfile contains `rapier`, `parry`, `nalgebra`,
`mujoco`, or `bullet`. This claim is exactly true at `a4fde2f`.

The prospective order is now:

1. Rapier/Parry through a Rust adapter and the existing Rust toolchain;
2. MuJoCo through the same C ABI and a project-local Python 3.11 environment;
3. any later game-engine or hardware adapter only after the first two expose
   and repair portability assumptions in the semantic contract.

An installed package is not a certified adapter. Each host must independently
clear its declared C0-C5 capabilities before any C6 locomotion run.

## Finding 4: Candidate 35 has real overfit risk, but the supplied proof is mixed

### The branch complexity is real

`sdk/core/src/controller.rs:32-125` contains a piecewise policy over interaction
score `S`, torso length `L`, torso width `W`, foot radius `F`, and hip span
`H`. It includes strict thresholds at `F = 0.985`, `1.01`, and `1.025`,
`abs(H - 1) = 0.02`, several score regions, and ramps as narrow as `0.01`.

That is a high-capacity hand-authored hypothesis relative to the finite
physical cohort. Candidate 35 was developed on already-opened GQ11-GQ14
failures. Its GQ15 success is valid finite fresh-population evidence, not
continuous-volume or arbitrary-quadruped proof.

### The generator is not a regular 25%-spaced per-axis lattice

`scripts/lab/gait/physical_quadruped_proportion_spec.gd:610-634` and
`:1650-1692` define:

```text
shell_fraction = 0.25 * (1 + ((index - 1) mod 4))
centered_coordinate = 2 * radical_inverse(index, axis_prime) - 1
value = reference + shell_fraction * centered_coordinate * endpoint_distance
```

The six axes use different prime bases `2, 3, 5, 7, 11, 13` at
`scripts/lab/gait/physical_quadruped_proportion_spec.gd:106-113`. The shell
radius repeats at `25/50/75/100%`, but the per-axis coordinates are
low-discrepancy radical-inverse values inside those shells. There is no
regular `0.025` scale lattice.

Reconstructing the exact generator for the 56 unique morphologies legitimately
available while Candidate 35 was developed gives:

| Axis | Observed range | Largest adjacent one-axis gap |
| --- | ---: | ---: |
| `L` | `0.900781250000` to `1.073828125000` | `0.026953125000` |
| `W` | `0.910242341107` to `1.090946502058` | `0.018415637860` |
| `H` | `0.909329446064` to `1.088921282799` | `0.019169096210` |
| `F` | `0.975450788881` to `1.098347107438` | `0.031254695718` |
| `S` | `0.022140046888` to `1.000000000000` | `0.096807628047` |

The 72 development worlds recorded in the Candidate 35 history include three
repetitions of the same eight GQ11 heldout morphologies; they are 72 worlds,
not 72 unique bodies.

Around the two `0.01` ramp axes, the 56-body population contains 11 `L`
samples in `[1.0, 1.01]` and 4 `F` samples in `[1.0, 1.01]`. The complete
GQ15 population contains 3 and 2 respectively. The interval is therefore not
mathematically unresolvable by this generator.

### The origin cohort did not identify the narrow ramp

The important criticism survives a more exact test. Candidate 32 introduced:

```text
Q = clamp((L - 1) / 0.01, 0, 1)
    * clamp((1.01 - F) / 0.01, 0, 1)
V = 0.275 + 0.075 * Q
```

In the 20-body GQ11 cohort used to develop that formula, exactly one body
entered the low-score, narrow-torso branch:

```text
s1005
L = 1.010888671875
F = 0.998680503381
S = 0.081565640994
Q = 1.0
```

Thus the selected `0.01` width was not identified from multiple outcomes
inside that ramp. Later legitimately opened development included two
fractional-`Q`
bodies, and fresh GQ15 included two:

```text
s121   Q = 0.585937500000
s145   Q = 0.175781250000
s165   Q = 0.722656250000
s1401  Q = 0.598144531250
```

Those later successes test the interpolation points, but do not retroactively
turn the original width into a data-resolved trend.

### GQ15 did freeze branch topology

The assertion that preregistration never froze branch topology is false for
GQ15:

- `docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md:8395-8446` freezes the
  exact Candidate 35 changes, retained Candidate 34 precedence, strict
  boundary inclusions, forbidden inputs, and fresh indices before generation;
- `docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md:8488-8512` requires the
  exact branch/precedence formulas in the campaign identity; and
- `docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md:9184-9223` openly records
  the four rejected Candidate 35 drafts and their failure-shaped development.

The scientifically accurate criticism is not "topology was unfrozen during
GQ15." It is "the topology frozen for GQ15 had already been shaped by a long
opened-body development history."

### The claimed `0.27586`/s148 provenance is unsupported

The repository contains no `0.27586` value. The documented origin of `0.275`
is Candidate 31:

- `docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md:7025-7105` records the
  GQ10 tradeoff at `0.25` and `0.30`;
- Candidate 31 selected the exact midpoint `0.275`; and
- the candidate then passed the complete already-opened GQ10 matrix at
  `36/36`, `900/900`.

Candidate 35 later inherited that value. `s148` participated in development
of Candidate 35's short-wide and motor-guard additions, not a five-significant-
figure bisection that created `0.275`.

This correction does not make `0.275` universal. It remains a development-
selected constant whose portability must be tested, not assumed.

### Audit contamination note

The first interactive reconstruction used to check the reviewer's lattice
claim mistakenly included GQ12 indices `1101-1108` and GQ13 indices
`1201-1208`. Those ranges had remained uncalculated after their campaigns
rejected at selection. The command constructed exact morphology values in
console only; it did not call the project generator, write a report, construct
a physics world, or inspect a physical outcome.

Under this repository's stricter rule, independent exact calculation still
opens the morphology. All values from that mistaken calculation were
discarded and are absent from the statistics above, which were recomputed from
only GQ11 selection/heldouts plus GQ12, GQ13, and GQ14 selection.

The contamination does not change either historical rejection and grants no
new evidence. It permanently removes `1101-1108` and `1201-1208` from any
future claim of cold heldout status. They may be used only as explicitly
opened development data under a new prospective campaign.

## What C6/C6R add to this audit

Candidate 35's long-horizon sensitivity is no longer hypothetical.

- Original C6 report:
  `<evidence-root>\formal-sdk-c6-55a7598\campaign\20260728T040930002\selection\20260728T040931467\report.json`
  (`sha256:3087d75946e37730847809175c09147acddd78cff4a45fd4d47b3121a53315b3`)
  rejected selection at `10/12`, `382/396`.
- C6R selection report:
  `<evidence-root>\formal-sdk-c6r-041289c\campaign\20260728T042931085\selection\20260728T042932260\report.json`
  (`sha256:bf0b95b01384ef580d87b35ec66cddb2471b08353150ccf76f6dc9d893541db8`)
  passed `12/12`, `396/396`.
- C6R cold held-out R1 report:
  `<evidence-root>\formal-sdk-c6r-041289c\campaign\20260728T042931085\heldout-r1\20260728T043504915\report.json`
  (`sha256:ab3c91fa3ca941feb8abc5d2e9959492f500fabbbdcb3c7eae527f5a06a55d3a`)
  rejected at `6/8`, `254/264`.

C6R applied `171,296/171,296` native commands with zero parity mismatches,
safe-no-actuation events, or authority disables. Yet `s1404` and `s1408`
failed physical walking gates. Command parity at approximately `1e-8` did not
imply long-horizon trajectory robustness.

That result is evidence against further Candidate 35 heldout-specific repair.
It supports a mechanics-based feedback successor and behavioral cross-engine
envelopes rather than bit-identical trajectory expectations.

## Prospective controls required by this audit

Before a new locomotion candidate may support cross-engine, robustness,
continuous-domain, or arbitrary-quadruped claims:

1. preserve Candidate 35 as a legacy conformance oracle; do not add another
   morphology-conditioned branch to it;
2. add engine-neutral ordered body-state and support-contact geometry so the
   core can reconstruct whole-system COM and a gravity-plane support hull;
3. port support-margin, dynamic-support, and bounded centroidal/stability
   feedback semantics into Rust with golden vectors against the existing
   GDScript mechanics modules;
4. connect the stability correction to the authority-bearing controller under
   explicit saturation, slew, feasibility, fallback, and receipt rules;
5. characterize canonical material requests by measured effective contact
   behavior per adapter before treating equal authored coefficients as equal
   physics;
6. make friction/material the first fresh nuisance axis, with no
   post-outcome threshold or topology changes;
7. separate continuous-domain compilation from physical coverage: a finite
   cohort is not full-volume proof;
8. use independently seeded low-discrepancy coverage, exact branch/boundary
   cells, and adaptive counterexample search; and
9. require a cell-wise robustness certificate before using the phrase
   "continuous full-volume physical coverage."

At remediation source `df6c9e5`, controls 2 through 4 are implemented and
evidence-backed, including a versioned partial-support joint map that preserves
exact zero authority on inactive-contact limbs and P5I.3C-R2 bounded physical
influence at `24/24`. Rapier and MuJoCo also remove the adapter-count blocker
at C0-C5. Control 5 now has a completed cold Godot/Jolt locomotion matrix, but
that matrix rejected, so it remains a blocker rather than an accepted
robustness range. Control 6 was obeyed: no Candidate 35 branch or topology was
changed after the material outcome. Controls 7 through 9 remain prospective.
This is why none of the audit findings requires reopening the rejected
Candidate 35 C6/C6R campaigns, while a non-Candidate-35 controller successor,
material robustness, continuous coverage, and cross-engine locomotion still
block completed-SDK claims.

The governing successor design is
[ADR-016](adr/ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md) and the
revised
[Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).
The fresh friction ladder, adapter material-profile contract, and cold
locomotion matrix are prospectively frozen in the
[Godot/Jolt Friction and Material-Robustness Bootstrap](SDK_GODOT_JOLT_FRICTION_MATERIAL_ROBUSTNESS_BOOTSTRAP.md).
The external paper inventory, local PDF paths, hashes, and allowed adoption
boundaries remain in
[Locomotion Research Sources and Adoption Ledger](research/LOCOMOTION_RESEARCH_SOURCES.md).

## Re-check after the first BW3 result

The four newer audit claims do not justify reopening C6, but they do sharpen
the prerequisites for the next cross-engine C6:

1. A legacy fixture still contains authored friction `1.8`; the inference
   that friction has never varied is false. P5M.3-R1 exercised authored
   `0.0`, `0.2`, `0.4`, `0.6`, `0.8`, `1.0`, and `1.8`; old BW3 independently
   characterized and exercised `0.3`, `0.7`, and `1.2`. BW3R then used
   previously unopened `0.25`, `0.55`, and `1.10` with seeds
   `17501`-`17503`; its first clean-source result passed `22/22` gates across
   `12/12` worlds. The stronger point remains true: BW3R is development
   validation, not the preregistered BW4 cold material acceptance, and
   Rapier/MuJoCo have no selected-policy material authority. Those remain C6
   blockers.
2. The assertion that `sdk/core/src/*.rs` contains no support-margin,
   centroidal, or stability machinery is false. `sdk/core/src/stability.rs`
   owns gravity-aligned support observation, support margins, bounded
   centroidal commands, endpoint-force-to-joint mapping, and the bounded
   influence limiter. The meaningful open gate is physical composition and
   recovery on every claimed host: a pure semantic function or Godot-only
   overlay is not cross-engine balance evidence.
3. The assertion that only one adapter exists is false.
   `sdk/adapters/godot`, `sdk/adapters/rapier`, and `sdk/adapters/mujoco`
   exist; Rapier is pinned in Cargo and MuJoCo is pinned in the project-local
   Python environment. The meaningful open gate is still correct:
   Rapier/MuJoCo are C0-C5 only and cannot support cross-engine C6 until they
   implement characterized materials, actuator response, selected-controller
   authority, and retained locomotion campaigns.
4. The narrow Candidate 35 branch concern remains scientifically material
   even though several quoted details were wrong. Candidate 35 stays a sealed
   legacy oracle. The new
   `sdk/balanced_wave_bw2r_preregistration.json` family has zero branch
   surfaces and changes one global factor only. It must repeat the complete
   BW2 ladder plus the entire opened BW3 cohort. Its selected BW2R-C policy has
   now passed the separate, prospectively frozen BW3R cohort at `9/9`
   treatments, `3/3` controls, and `3/3` pairs. The still-unopened BW4 values
   and seeds remain the cold check against development-cohort shaping.

Therefore these findings must be resolved before claiming cross-engine C6,
but not all are missing code. The current interlock is:

```text
BW2R selection
  -> BW3R independent material validation (passed)
  -> BW4 cold material acceptance
  -> Godot terrain/push/sensor campaigns
  -> Rapier material + actuator + selected-policy authority
  -> MuJoCo material + actuator + selected-policy authority
  -> cross-engine C6
```

No adapter count, dependency install, no-world parity test, or single-host
walking result may bypass that order.

## Re-check after the first BW4 result and BW4R freeze

The complete BW4 result makes the current answer sharper:

1. **Friction/material is a real pre-C6 blocker, but it is not frozen.** The
   first BW4 source retained all `17/17` worlds and zero infrastructure
   failures, yet rejected at `27/28` because one `mu=1.40` treatment failed
   lateral drift. That is stronger evidence than the audit's file-count claim:
   friction has been varied in locomotion, and the selected controller did not
   clear the cold cohort. The exact report is
   `<evidence-root>\balanced-wave-bw4-validation-83c6142\report.json`
   with SHA-256
   `539f0a724470723b445ea3ade443d8125e9934593b456a64898843d33938d550`.
2. **Portable stability exists and is physically connected in Godot/Jolt.**
   The open blocker is no longer missing code; it is proven behavior under the
   required nuisance axes and equivalent authority on Rapier/MuJoCo. BW4R
   addresses one observed regulation cadence weakness without claiming balance
   recovery.
3. **Three adapters exist, but only Godot/Jolt has selected-policy physical
   authority.** Rapier and MuJoCo C0-C5 conformance does not satisfy C6. Both
   still need characterized materials, actuator response, portable-controller
   authority, and retained locomotion.
4. **The Candidate 35 topology critique remains valid evidence against further
   branch repair.** Candidate 35 is sealed. BW4R-A/B inherit the branch-free
   BW2R-C profile and change only a global feedback cadence plus one optional
   global slew limit. Both must complete the same `58` opened-development
   worlds; no candidate can be selected before all `116` complete.

One additional live-code defect was found during this re-check: the historical
walking gate called world X/Z “forward/lateral” even though frozen fixtures can
have nonzero yaw. The rejected BW4 result remains exactly what it was—a
world-Z proxy result. Before any BW4R physics outcome, future receipts and
gates were corrected to project displacement onto frozen initial task-frame
axes. The `0.10 m` lateral threshold was not changed.

The current interlock is therefore:

```text
BW4R complete 116-world development selection
  -> new disjoint Godot/Jolt material characterization
  -> new independent Godot/Jolt validation
  -> new disjoint Godot/Jolt cold material acceptance
  -> fresh morphology + terrain + push + sensor campaigns
  -> Rapier material + actuator + same-policy authority
  -> MuJoCo material + actuator + same-policy authority
  -> cross-engine C6
```

The first, second, and fourth audit claims do not require restoring missing
files before BW4R development; their literal premises are already obsolete.
Their scientific cores remain mandatory C6 gates. The third claim is also
literally obsolete, but its physical-authority requirement remains mandatory.

## Re-check after the complete BW4R result

The preregistered BW4R development campaign is complete at source
`b538bea3656600fcd56f94cb62a8391a0a932bb0`. The compiler verified both
`58`-world candidate matrices and all `116/116` worlds, then rejected the
candidate family because neither branch-free per-step feedback policy had zero
opened-BW4 treatment nonwalks. The retained report is:

```text
<evidence-root>\balanced-wave-bw4r-selection-b538bea\report.json
sha256:23bc6f88c46cbed8b848efd9b2663757fd2f33c5c2f9d260e69e4ddc35d6718b
```

This resolves the audit question unambiguously:

1. **Friction/material must be resolved before C6.** It is not a missing test
   axis—the project has now exercised many authored-friction values—but the
   selected portable-policy line has failed the frozen cold BW4 gate and both
   prospective recovery variants failed the opened BW4 replay. C6 remains
   blocked on behavior, not on adding one more literal friction field.
2. **Balance machinery does not need to be recreated before C6.** Portable
   support, centroidal, mapping, limiting, and Godot/Jolt physical composition
   already exist. The failed per-step feedback family shows that the remaining
   problem is controller behavior across the required nuisance axes and
   equivalent characterized authority in Rapier and MuJoCo.
3. **Adapters do not need to be recreated before C6.** Godot/Jolt, Rapier, and
   MuJoCo adapters exist and pass their declared C0-C5 contracts. Rapier and
   MuJoCo still require material/actuator characterization, selected portable
   controller authority, and physical locomotion evidence before cross-engine
   C6.
4. **Candidate 35 must not be repaired before C6.** The branch-topology and
   lattice critique remains valid. Candidate 35 stays sealed, and the failed
   BW4R result is not permission to add another failure-shaped condition. The
   next controller identity must be globally defined, branch-free over
   friction/material/morphology/seed/outcome, and frozen with a complete
   selection rule before another physics world.

The current ordered interlock is now:

```text
new branch-free successor preregistration
  -> complete opened-development selection
  -> new disjoint Godot/Jolt characterization and validation
  -> new cold Godot/Jolt material acceptance
  -> fresh morphology + terrain + push + sensor campaigns
  -> Rapier material + actuator + same-policy physical authority
  -> MuJoCo material + actuator + same-policy physical authority
  -> cross-engine C6
```

The unused validation and cold reservations in
`sdk/balanced_wave_bw4r_preregistration.json` remain unopened and cannot be
repurposed as development data for the next candidate family.

## Re-check after the BW5R preregistration freeze

The four claims do not require stopping to restore missing friction, balance,
or adapter source before BW5R development. Their scientifically valid parts
remain hard pre-C6 gates:

1. **Friction/material behavior must pass before C6.** The literal “zero
   friction campaigns” count is obsolete, but the selected-policy line and
   both BW4R successors failed frozen friction/material locomotion cells.
   BW5R must clear the complete opened replay, then new disjoint independent
   validation and cold material partitions.
2. **Portable balance machinery exists, but balance behavior remains
   unproven.** BW5R uses the existing support/centroidal/mapping path and adds
   mechanism receipts for raw and filtered steering, update cadence,
   saturation/slew, cumulative cross-track error, overshoot, contact timeouts,
   phase, support, and limb relocation. Those diagnostics do not authorize a
   recovery claim.
3. **Three adapters exist, but cross-engine physical authority does not.**
   Godot/Jolt, Rapier/Parry, and MuJoCo have declared C0-C5 surfaces. Rapier
   and MuJoCo still need material/actuator characterization, same-policy
   physical command authority, and retained locomotion before cross-engine C6.
4. **Candidate 35 remains sealed.** BW5R has no Candidate 35 call and no
   friction/material/morphology/seed/cohort/outcome branch. Its three
   factor-of-two filter time constants and complete selection topology are
   frozen before any BW5R world.

The mechanism is explicitly linked to
`<repo>\DReCon.pdf`, SHA-256
`aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54`,
DOI `10.1145/3355089.3356536`, pages 5–7. The project adopts the
deterministic-reference plus recursively filtered bounded-correction pattern,
not DReCon's learned policy, query rate, numeric coefficient, humanoid
constants, or claims.

The current ordered interlock is:

```text
BW5R complete 174-world development selection
  -> commit the selected implementation
  -> new disjoint Godot/Jolt characterization and validation
  -> new disjoint cold Godot/Jolt material acceptance
  -> fresh morphology + nuisance + terrain + push + sensor campaigns
  -> Rapier material + actuator + same-policy physical authority
  -> MuJoCo material + actuator + same-policy physical authority
  -> cross-engine C6
```

Thus, yes: the behavioral friction/balance findings and engine-physical
authority must resolve before C6 can finish. No: the current source-freeze
should not be interrupted to re-add code that already exists, rerun a rejected
identity, or mutate the preregistered family after seeing outcomes.

## Re-check after complete BW5R development selection

BW5R completed from clean pushed source
`d17b77afefddb19ae401f3f8f2e8b3b7708a02e6`. The compiler verified all
`174/174` worlds, all `15` input reports, every recorded input/source hash,
zero early stopping, and zero infrastructure/integrity failures. The retained
report is:

```text
<evidence-root>\balanced-wave-bw5r-selection-d17b77a\report.json
sha256:d2819d1bca45592fe54f1fc22cd2ad19d64fb3cd9eafd8ad848601338f8b50fc
```

The result further sharpens the four findings:

1. **Friction/material is still a behavioral pre-C6 blocker.** BW5R-B is the
   valid development winner, but it retained two opened nonzero-material
   nonwalks, both at authored friction `0.80`. Selection is not robustness.
   The new `{0.05, 0.65, 1.30}` validation partition and later
   `{0.12, 0.48, 0.95, 1.50}` cold partition remain mandatory.
2. **The portable balance path is physically active and now instrumented.**
   Every BW5R step recorded raw/filtered correction, filter application,
   saturation/slew, and cross-track diagnostics. The result still makes no
   physical balance-recovery claim; terrain, push, and observation-fault
   campaigns remain unopened.
3. **Adapter count remains the wrong completion metric.** BW5R-B has only
   Godot/Jolt development authority. Rapier and MuJoCo still require their own
   material/actuator characterization and same-policy physical locomotion.
4. **The Candidate 35 repair path remains closed.** BW5R-B was selected
   without a morphology, friction, material, seed, cohort, failed-cell, or
   outcome branch. The decisive comparison was prospective and complete, not
   a branch fitted after reading the failure list.

The current interlock is:

```text
commit BW5R-B selected-policy binding
  -> characterize new Godot/Jolt validation materials
  -> BW5R-B independent validation
  -> characterize and run the disjoint cold material partition
  -> fresh morphology + nuisance + terrain + push + sensor campaigns
  -> Rapier material + actuator + BW5R-B physical authority
  -> MuJoCo material + actuator + BW5R-B physical authority
  -> cross-engine C6
```

Therefore the answer remains: the scientifically valid friction/balance and
physical-engine portions must resolve before C6 finishes. No missing adapter
tree or missing portable support stack needs to be recreated first.

## BW5V source freeze before independent material characterization

The current pipeline has not responded to the audit by mutating Candidate 35
or by adding an outcome-shaped BW5R branch. Instead, BW5V freezes the
pre-BW5R reserved axis that the audit correctly identified as an important
unbiased check:

```text
selected policy: BW5R-B
validation values: 0.05, 0.65, 1.30
validation seeds: 19501, 19502, 19503
cold values still unopened: 0.12, 0.48, 0.95, 1.50
cold seeds still unopened: 20001, 20002, 20003
```

The machine-readable contract is
`sdk/balanced_wave_bw5v_preregistration.json`; the source-bound runner is
`sdk/run_balanced_wave_bw5v_material_characterization.ps1`. Its current
`6/6` result is a zero-world preflight, not empirical friction or locomotion
evidence. The first physical characterization remains the next action after
commit/push, and material robustness remains a hard pre-C6 blocker.

That first characterization has now completed from clean pushed source
`2a5eb94dca81a8c638e31a0d7c9692c270b44ca6`: `10/10` worlds and `19/19`
gates, retained at
`<evidence-root>\balanced-wave-bw5v-material-characterization-2a5eb94\report.json`
with SHA-256
`a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84`.
That resolves the adapter-characterization prerequisite for these three
values; it does not resolve the audit's behavioral friction claim. The
independent locomotion matrix and later cold matrix remain mandatory.

The adapter profiles have since been published from clean pushed source
`e76477be61d90829dab0eb70a89505d521e7f8a5`. The retained zero-world
publication is:

```text
<evidence-root>\balanced-wave-bw5v-material-profiles-e76477b\report.json
sha256:2430c1a77d7007c13c3a5262e19fba7693154ba40ea61aa3d1cf601844a2a37c
```

`sdk/balanced_wave_bw5v_validation_manifest.json` now freezes the independent
locomotion matrix, and `sdk/run_balanced_wave_bw5v_validation.ps1
-PreflightOnly` passes without building a world. Its `12` cells and `22`
all-or-nothing gates are therefore the current boundary. This is the
prospective, branch-free test relevant to the audit; its result has not been
used to alter BW5R-B.

The blocking interpretation is unchanged:

- the literal claims that friction is untouched, portable balance code is
  absent, and only one adapter exists are stale;
- behavioral material robustness, physical recovery on nuisance axes, and
  same-policy Rapier/MuJoCo locomotion remain hard pre-C6 requirements; and
- Candidate 35 remains sealed and cannot contribute another repaired policy
  identity or heldout-shaped branch.

## Re-check after the complete BW5V independent-validation result

The first eligible result completed from clean pushed source
`7d8b046f752974b8d9498db91b0d46ae99ac1729` and is retained at:

```text
<evidence-root>\balanced-wave-bw5v-validation-7d8b046\report.json
sha256:a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee
```

It passed `22/22` gates across `12/12` worlds: `9/9` treatments, `3/3`
matched controls, `3/3` causal pairs, and zero integrity failures. This result
materially updates the audit:

1. **Friction is not frozen and the requested unbiased axis now has a
   prospective pass.** BW5R-B has no friction condition, yet passed all nine
   treatments spanning authored values `0.05`, `0.65`, and `1.30`. The later
   `{0.12, 0.48, 0.95, 1.50}` cold partition remains the hard pre-C6 material
   gate; discrete validation is not continuous or arbitrary-material proof.
2. **Portable balance machinery is present and physically influential, but
   recovery remains unproven.** All nine treatments applied nonzero bounded
   stability influence. Flat-terrain walking under small initial
   perturbations is not a push, rough-terrain, or sensor-fault recovery test.
3. **There are three adapter trees, but only Godot/Jolt has this physical
   policy result.** Rapier and MuJoCo remain C0-C5 until they receive
   characterized materials, actuator commissioning, and the same frozen
   BW5R-B locomotion authority.
4. **The Candidate 35 critique remains valid and contained.** Candidate 35
   stays an immutable regression oracle. BW5R-B is branch-free, was selected
   prospectively, and passed this previously unopened friction cohort without
   a post-result topology change.

Therefore none of the literal source-count claims require emergency repair.
The cold material result, physical nuisance/recovery campaigns, and two
additional engines are still genuine blockers before C6 can be called
complete.

## BW5C response to the remaining friction finding

The next action is no longer another GQ/BW development generation. BW5C opens
the axis that was reserved before the accepted BW5V result:

```text
friction: 0.12, 0.48, 0.95, 1.50
seeds:    20001, 20002, 20003
```

The source freeze is
[`sdk/balanced_wave_bw5c_preregistration.json`](../sdk/balanced_wave_bw5c_preregistration.json).
It cites the accepted prerequisite at
`<evidence-root>\balanced-wave-bw5v-validation-7d8b046\report.json`
with SHA-256
`a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee`,
and pins both prior reservation documents by SHA-256. This directly answers
the audit's request for a cold axis absent from the branch topology without
modifying Candidate 35 or adding a friction branch to BW5R-B.

The no-world command is:

```powershell
.\sdk\run_balanced_wave_bw5c_material_characterization.ps1 -PreflightOnly
```

The characterization contract is `13` worlds and `23` gates. Its only
authorized output is conservative adapter-profile data. The later cold
locomotion contract remains separate and all-or-nothing at `17` worlds and
`28` gates. Therefore BW5C is the correct mitigation for finding 1, but its
source freeze or characterization alone does not resolve material robustness.
The balance-recovery, Rapier/MuJoCo physical-policy, nuisance, and fresh
morphology findings remain independent pre-C6 gates.

BW5C characterization has since passed `23/23` over `13/13` worlds. The
durable, recovery-explicit report is:

```text
<evidence-root>\balanced-wave-bw5c-material-characterization-dca2618\report.json
sha256:067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143
```

No physics rerun occurred after the command-host packaging interruption. The
complete receipt is in the retained `engine.log`; the short outer transcript
is retained and labeled partial. The resulting adapter coefficients are
`0.10`, `0.45`, `0.94`, and `1.00`, and all four immutable profiles pass the
expanded `36/36` zero-world publication gate. This resolves cold material
*characterization*, not the audit's behavioral robustness claim. The
separately frozen `17`-world/`28`-gate locomotion outcome remains the deciding
friction gate.

That profile publication is retained from source `677e97e` at:

```text
<evidence-root>\balanced-wave-bw5c-material-profiles-677e97e\report.json
sha256:381132c430140ec4b70a1cff65d7099974bf1b6eefa59bafa523c1b287076c97
```

The deciding behavioral gate is now source-frozen in
`sdk/balanced_wave_bw5c_validation_manifest.json` and executable as
`sdk/run_balanced_wave_bw5c_validation.ps1 -PreflightOnly`. Its preflight
passes with zero worlds and exact bindings for BW5R-B, all prerequisite
reports, all four cold profiles, three reserved seeds, `17` cells, and `28`
gates. Therefore the audit's friction finding is no longer a missing-source
or missing-test-design issue; it remains a hard C6 blocker only because the
first frozen physical outcome has not yet run.

## Re-check after the complete BW5C cold result

The frozen result has now run once from clean pushed source
`dac405df52abfda12f5633022e6814b02f561a3e` and is retained at:

```text
<evidence-root>\balanced-wave-bw5c-validation-dac405d\report.json
sha256:6648c1473c97d2b7229ba0decd8881ca2d8f06e68ca9737d7255120dab2653da
```

It passed `28/28` gates over `17/17` worlds: `12/12` treatments, `4/4`
controls, `4/4` causal pairs, and the zero-friction zero-write safety cell,
with zero integrity failures. The audit's behavioral-friction criticism is
therefore resolved for the explicitly bounded Godot/Jolt scope. It would be
an overclaim to convert this into continuous-friction, arbitrary-material,
other-morphology, or cross-engine evidence.

The remaining hard pre-C6 blockers are physical recovery/nuisance campaigns,
fresh physical morphology coverage, and same-policy physical authority in
Rapier and MuJoCo. The literal source-count claims remain stale; the Candidate
35 critique remains historically valid but contained because Candidate 35 was
not the policy under BW5V or BW5C.

## Current-source Rapier and MuJoCo environment refresh

The two non-Godot adapter slices were re-executed after BW5C from clean source
`a2cf1a052b3685a64ca784035f595d2844fefbaf`, without changing controller or
adapter code:

```text
<evidence-root>\rapier-c2-c5-a2cf1a0-refresh\report.json
sha256:e9f66bdbe96b920d0e12f7541658c2c17af575be4e504ba3475f266e06937fc1

<evidence-root>\mujoco-c0-c5-a2cf1a0-refresh\report.json
sha256:a4f6aa753387918aa3e1bc42cbc24998da427fcf68e1b15b6bbffa6fa83b3be4
```

Rapier passes `4/4` C2-C5 cells with the checked-in `rapier3d = "0.34.0"`
dependency; Parry `0.29.0` and nalgebra are resolved transitively. The ignored
MuJoCo Python 3.11 environment was absent and was safely recreated from
`sdk/adapters/mujoco/requirements-lock.txt`; MuJoCo `3.11.0`, NumPy `2.4.6`,
a real model load, and all `5/5` C0-C5 cells pass. This repairs local execution
readiness and refreshes the evidence on the selected-policy-era source. It
does not grant either host C6, controller-policy authority, material/actuator
commissioning, or physical-acceptance authority.

The exact C6 interpretation is therefore:

1. the audit's literal frozen-friction claim is resolved for bounded,
   prospectively frozen Godot/Jolt values by BW5C, while continuous/arbitrary
   materials and per-host Rapier/MuJoCo commissioning remain open;
2. the portable balance-source claim is false, although real rough-terrain,
   push, and observation-fault recovery evidence is still required;
3. the one-adapter claim is false, although Rapier and MuJoCo remain C0-C5
   hosts rather than same-policy physical C6 hosts; and
4. Candidate 35 must remain sealed. Its historical overfit concern does not
   require a repair because active policy BW5R-B is branch-free and produced
   the independent BW5V and cold BW5C results without topology edits.

## BW6N response to the remaining physical-recovery finding

The next real pre-C6 blocker is now a source-frozen test rather than a prose
placeholder. The contract is
`sdk/balanced_wave_bw6n_validation_manifest.json`; the runner is
`sdk/run_balanced_wave_bw6n_validation.ps1`.

BW6N holds BW5R-B, the reference morphology, characterized `0.95` material,
solver, clock, and fresh seeds `{21001, 21002, 21003}` fixed. It pairs three
active-policy baselines with three rough-height-strip worlds, three
single-lateral-impulse worlds, and three deterministic observation-noise
worlds. Its challenge compiler is fail-closed, the external impulse has a
separate non-controller receipt, and sensor noise reaches both portable
base/joint state and stability body/support observations without modifying
physics.

The zero-world preflight passes the ordered `12`-world/`24`-gate contract, and
the separate pure challenge contract passes `9/9`. Those are implementation
and source-freeze results only. No BW6N locomotion outcome has been opened, so
rough-terrain robustness, external-push recovery, sensor-noise robustness, and
physical balance recovery remain false until the first complete clean-pushed
run. Fresh morphology and per-host Rapier/MuJoCo material, actuator, and
same-policy physical authority remain separate blockers after BW6N.

## Re-check after the complete BW6N result

The first complete run from clean pushed source
`e44a7e2fabf7547aaba778a94c0f3eaa64b1920e` is retained at:

```text
<evidence-root>\balanced-wave-bw6n-validation-e44a7e2\report.json
sha256:8fe82a73b4bd8bae9789932fda47af2104b6204a4594a62c44998019ca949442
```

It completed `12/12` worlds but was rejected at `16/24` gates. Walking totals
were baseline `2/3`, rough `1/3`, push `2/3`, and sensor noise `2/3`.
Infrastructure and challenge realization were exact: `3/3` rough geometries,
`3/3` measurable single pushes, `3/3` full `1,514`-step dual-path sensor
faults, and `12/12` nonzero bounded stability-influence worlds.

The failure pattern matters. Baseline, push, and sensor-noise `s21003` each
failed only `evidence_four_contact_stance`, so neither push nor sensor noise
can be blamed for that shared miss. Rough terrain added real behavioral
failures: `s21001` failed bounded lateral drift and two contact cycles per
limb, while `s21002` timed out contact gating. Rough `s21003` passed.

The audit answer before cross-engine C6 is now:

1. The literal frozen-friction claim remains disproven by accepted BW5C, but
   Rapier and MuJoCo still need their own material and selected-policy physical
   authority.
2. Portable balance machinery exists and was physically active in all BW6N
   worlds, but recovery and nuisance robustness remain unaccepted because
   BW6N failed.
3. Three adapters exist and pass C0-C5; Rapier/MuJoCo C6 remains unfinished.
4. Candidate 35 remains sealed. A prospective successor must separately fix
   evidence-start acquisition and the branch-free rough-terrain mechanisms,
   not repair Candidate 35 or edit a BW6N threshold.

Therefore yes: the behavioral portions of findings 1 through 3 must be
resolved before cross-engine C6 can finish. The literal source-count claims
and the proposal to repair Candidate 35 do not need action. Fresh physical
morphology coverage also remains an independent pre-C6 blocker.

## Post-BW6N causal diagnostic refinement

The complete opened-world diagnostic is retained at:

```text
<evidence-root>\balanced-wave-bw6n-opened-diagnostic-6189535\report.json
sha256:fc370752d51ae1b1571cf9179fc483132b008ee859fc814494dbafbf0529569c
source:61895351550003dadfcab24f0b08bf49ae9f293d
```

It has `6/6` completed execution-integrity receipts and explicitly carries
zero acceptance authority. A separate first-run classifier mistake is
retained rather than erased at
`<evidence-root>\balanced-wave-bw6n-opened-diagnostic-9d944e1\classification.json`
(SHA-256
`4258152b6d95f72ca69e5abebf7310e8b717ebedef018b295faed45bd86a63c9`).
The two physical replays were exact on all diagnostic fields used below.

The shared `s21003` failure is now identified as a measurement-boundary
problem: the `front_right` contact returned two ticks after nominal evidence
start, with zero gate timeouts, completed gait horizons, and terminal
four-contact stance. This removes “fix baseline balance” from the controller
worklist, but it adds a pre-C6 evidence-protocol requirement: prospectively
define and test a bounded, fail-closed evidence-start acquisition window.

The two rough failures do require controller work before C6:

- `s21002` exhausted the `120`-tick `await_release` hold on both front limbs
  while they remained bearing; and
- `s21001` combined `384` steering-saturation steps, `0.100246 m` terminal
  lateral displacement, and three rear-right recontacts whose forward
  relocation stayed below `0.015 m`.

No timeout or walking threshold may be relaxed. The next branch-free
development family must target release/unweighting and saturated
path/foothold progression, then pass disjoint prospective seeds. This
refinement does not change the audit verdict: bounded Godot/Jolt friction is
already real, portable balance code and three adapters already exist, but
fresh morphology, accepted nuisance behavior, and same-policy physical
Rapier/MuJoCo authority remain pre-C6 blockers. Candidate 35 remains sealed.

## Re-check after complete BW7D family closure

The four audit claims were re-run against current source after BW7D completed.
Their literal premises and their scientific consequences must not be
conflated:

1. **Friction:** the generated reference fixture still defaults to authored
   friction `1.8`, so the historical GQ/GS/GP cohort itself remains
   single-material. The current repository nevertheless contains multiple
   prospectively frozen locomotion material campaigns, including accepted
   bounded BW5C evidence over `0.12`, `0.48`, `0.95`, and `1.5`. Thus “friction
   never varies” is false current-source inventory, while continuous,
   arbitrary, and cross-host friction robustness remain unaccepted.
2. **Balance:** `sdk/core/src/stability.rs` now implements and
   `sdk/core/src/lib.rs` exports whole-system support observation, capture and
   support margins, centroidal allocation, endpoint-to-joint mapping, and
   bounded stability influence. The Godot/Jolt walker physically applied
   nonzero portable stability influence in all 48 BW7D worlds. Thus “the SDK
   has zero balance machinery” is false. Accepted physical recovery and the
   same connection in Rapier/MuJoCo remain open.
3. **Adapters:** `sdk/adapters/` contains `godot`, `rapier`, and `mujoco`.
   Rapier pins `rapier3d = "0.34.0"`; MuJoCo pins the Python 3.11 wheel stack
   with `mujoco==3.11.0`. Their retained C0-C5 refresh reports remain valid.
   Thus “one adapter” is false, but both additional hosts still lack material,
   actuator, same-policy stability/locomotion, and C6 physical authority.
4. **Candidate 35:** its narrow failure-shaped branch structure remains a
   valid reason not to generalize GQ15 beyond its finite cohort. The claim
   that the generator is a regular 25%-spaced lattice remains inaccurate, and
   GQ15 did freeze the then-current branch topology. No repair is required:
   Candidate 35 is a sealed legacy oracle. BW7D instead froze four empty
   morphology branch-surface sets before any world.

BW7D did not earn promotion. Experiment source
`0da1b70fc47e4ba877a3a7dc8016653d381c0b9e` completed all 48 worlds. A, B,
and D were integrity-complete but ineligible; C had two typed integrity
failures. The authoritative negative closure is:

```text
<evidence-root>\balanced-wave-bw7d-family-closure-0da1b70-27ea2cc\report.json
sha256:a5664b16a01974d60bdc8b1f062ef17c262d63ea736d5417d3aefc069cf46bbe
```

The complete evidence ledger is
`sdk/balanced_wave_bw7d_closure_manifest.json`. It records
`selection_performed=false`, `family_selected=false`, and no selection
authority. The reserved validation and unbiased-friction outcomes were not
opened.

Therefore, before the *future cross-engine C6 interlocked by this bootstrap*
can finish:

- a new branch-free portable policy must earn development selection and
  independent validation;
- cold friction/material evidence and the frozen
  terrain/push/noise/latency/fresh-morphology gates must pass;
- Rapier and MuJoCo must commission material, actuator, observation,
  stability, and the same selected policy under physical authority; and
- cross-engine tolerances must be frozen before the first complete C6 run.

No Candidate 35 repair and no new adapter-count fix is needed. The remaining
work is behavioral evidence and host commissioning, not restoring source code
that already exists.

## Audit-constrained BW8U freeze and negative closure

The next branch-free identity was implemented and prospectively frozen in
`sdk/balanced_wave_bw8u_preregistration.json` before any BW8U physics world
was opened. This was the direct response to BW7D-D's retained release-timeout
diagnosis, not a reinterpretation of the four audit verdicts.

BW8U is a complete `2 x 2` of two globally defined analytic target modes at
the existing loaded phase-54 release gate: existing knee swing apex on/off and
existing hip swing apex on/off. All four arms inherit BW7D-D's other fields
exactly and expose zero morphology branch surfaces. The mechanism adds no
free fitted number, threshold, material condition, morphology feature,
seed condition, or failed-cell exception. A typed v3 step receipt names the
enabled modes and ordered limbs on which each override actually activates.

The zero-world native contract passes `17/17`, all four candidate preflights
pass, and the frozen identities are:

- canonical preregistration:
  `sha256:51b3af71af5ad933eaaee9767383f38d8b1cdfe00a9845754b7e36370fbc3793`;
- raw preregistration:
  `f6cdfca3c8956deb4a48ac22d8d8507a373923aa60e3d59f51d40f72554f61a5`;
- opened development seeds: `21001`-`21003`;
- fresh development seeds: `24001`-`24003`;
- sealed independent-validation seeds: `22501`-`22503`; and
- sealed unbiased-friction values/seeds:
  `{0.09, 0.37, 0.76, 1.18}` / `23001`-`23003`.

Source `a8f3887cb164a7b6b4b65682a021a48f025b5a1c` subsequently
completed all `48/48` development worlds. A and B retained three non-walks
and `11` release timeouts apiece, with one post-fall stability-overlay
integrity failure apiece. C and D completed with intact execution evidence
but regressed to `11/12` non-walks and `35` timeouts apiece. The selector
therefore chose nothing and rejected the family. The authoritative report is
`<evidence-root>\balanced-wave-bw8u-family-closure-a8f3887\report.json`,
SHA-256
`fb89fe9cc4467b8484d4bee4cc5fe4cd5e21efc77ad748c1594dc11a0bd9a040`;
the exact candidate ledger is
[`../sdk/balanced_wave_bw8u_closure_manifest.json`](../sdk/balanced_wave_bw8u_closure_manifest.json).

The branch-free freeze requirement was satisfied, but the mechanism
hypothesis failed. It does not resolve the audit's behavioral pre-C6 gates.
BW8U's independent validation and cold-friction reservations remain unopened
and cannot be used to repair it. A new selected identity, independent
validation, a cold friction axis, fresh morphology and nuisance acceptance,
and same-policy physical Rapier/MuJoCo commissioning remain mandatory before
cross-engine C6.

## BW9L response to the valid balance and overfit concerns

The literal inventory claims remain obsolete: current source has varied
friction locomotion campaigns, portable balance machinery, and three declared
C0-C5 adapters. The behavioral core of the audit remains binding before C6:
the selected policy still needs prospective physical recovery and nuisance
evidence, cold friction evidence, and equivalent physical authority in Rapier
and MuJoCo. Candidate 35's fine failure-shaped topology remains unsuitable as
a basis for broad quadruped claims.

BW9L addresses the next Godot/Jolt balance mechanism without modifying
Candidate 35 or adding another morphology rule. The frozen preregistration is
[`../sdk/balanced_wave_bw9l_preregistration.json`](../sdk/balanced_wave_bw9l_preregistration.json),
canonical SHA-256
`b0b708bc6bcfd5475606b4014295f204a9b9d64846eb60d362b355184a5e2767`.
It is a complete branch-free `2 x 2` that holds BW5R-B fixed and independently
tests preferred normal-force redistribution and a remaining-support-centroid
lateral target. Both are derived from the existing scheduler, morphology, and
qualified-contact state; neither uses friction, material, seed, cohort,
failed-cell, or observed-outcome conditioning.

The portable Rust endpoint now creates the full centroidal request and command,
not merely a Godot-side correction. It is exposed through the C ABI, Python,
Godot GDExtension, and authority adapter. Typed execution summaries bind the
stability-policy identity, receipt count and hashes, active scheduler steps,
normal-force-preference steps, remaining-centroid steps, empty morphology
branch surface, and the explicit absence of per-foot measured-load evidence.

The `5/5` native no-world contract and all four 12-world preflights pass. No
BW9L physics world has yet opened. The next legal action is to commit and push
this frozen source, run all `48/48` development worlds without early stopping,
and compile selection only afterward. Seeds `22501`-`22503` and the cold
friction values `{0.09, 0.37, 0.76, 1.18}` at seeds `23001`-`23003` remain
unopened and cannot influence development.

The three research inputs remain bound by local path and digest in the BW9L
freeze and by interpretation in
[`research/LOCOMOTION_RESEARCH_SOURCES.md`](research/LOCOMOTION_RESEARCH_SOURCES.md):
`DReCon.pdf`, `2604.08780v1.pdf`, and `2507.22653v2.pdf`. Their architecture
ideas informed the separation of deterministic gait, explicit morphology and
contact inputs, and host-neutral ordered limb/contact semantics; no paper
numeric constant or empirical claim was imported.

## BW9L retained negative result

BW9L completed the entire `48/48` source-frozen factorial from pushed commit
`f4d25081132d5e6cdecf2ca0c4a55e657a9e92d4`, then failed closed. Every
candidate retained twelve worlds but had twelve integrity failures and only
`8/22` aggregate gates because the portable planner did not emit a typed
receipt on every partial or rank-deficient support step. The frozen selector
refused the incomplete A input and performed no selection.

This is relevant to the audit in two distinct ways:

1. It confirms that portable balance code and real physical influence exist;
   B, C, and D accumulated `8,531`, `8,807`, and `8,620` live factor steps.
   The source-inventory claim remains false.
2. It also confirms that “balance code exists” is much weaker than
   “engine-neutral balance is complete.” A host-neutral planner must fail zero
   with a typed receipt under partial, rank-deficient, and infeasible support,
   and the present v1 endpoint does not.

Raw walking observations were A `7/12`, B `7/12`, C `10/12`, D `5/12`;
release timeouts were `15`, `32`, `8`, and `22`. These counts cannot be
ranked because execution integrity failed in every world. C is a useful
directional observation only, not evidence of balance improvement.

The new negative-only compiler is
[`../sdk/compile_balanced_wave_bw9l_negative_closure.ps1`](../sdk/compile_balanced_wave_bw9l_negative_closure.ps1).
It binds the exact four report hashes and contains no selection path. BW9L is
closed, its reserved validation and cold-friction cohorts remain unopened, and
the pre-C6 stability blocker is now precisely a typed fail-zero continuity
requirement plus a later fresh physical validation—not missing balance source
code.

The authoritative closure is retained at
`<evidence-root>\balanced-wave-bw9l-family-closure-f4d2508\report.json`,
SHA-256
`4d0faa6c5d755b1ff3e32937a38d09a9f6197c52cfe9f90636e5c1933f6d40f1`.
The source-controlled index is
[`../sdk/balanced_wave_bw9l_closure_manifest.json`](../sdk/balanced_wave_bw9l_closure_manifest.json).

## Audit follow-up: BW10F fixes the receipt defect, not the behavioral gates

Pushed implementation
`b59f00018a55df5f7e5468a53c2cbda354ce9d0a` adds
`ss_plan_scheduled_load_transfer_v2_json` and four new BW10F identities while
leaving the rejected BW9L v1 family immutable. Partial, rank-deficient, and
centroidally infeasible support now produce typed, hashable, morphology-
ordered safe-zero receipts instead of missing planner receipts. The portable
implementation and transports are linked from
[`SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md`](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md).

The live no-world evidence is `78` core tests, `12/12` Python tests,
`41/41` Godot C0/C1 checks, `5/5` BW9L backward-compatibility checks, and
`6/6` BW10F checks. No BW10F physics world has opened.

Audit verdict after this implementation:

1. The literal “no balance machinery” and “one adapter” claims remain false.
2. The BW9L integrity defect is fixed under a new schema and identity.
3. The substantive pre-C6 concerns remain open: a fresh physical successor
   must be prospectively frozen and independently validated; friction must be
   tested cold on an axis absent from controller conditions; fresh morphology,
   rough terrain, pushes, and observation noise/latency must pass; and Rapier
   and MuJoCo must apply the same selected portable policy with real physical
   authority.
4. Candidate 35 remains sealed and unsuitable as the hypothesis surface for
   broad quadruped claims. BW10F adds no Candidate 35 branch and does not
   rehabilitate its fitted thresholds.

Research inputs remain the exact repository-root files
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf), and
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), with adopted and rejected
boundaries in
[`research/LOCOMOTION_RESEARCH_SOURCES.md`](research/LOCOMOTION_RESEARCH_SOURCES.md).
Their SHA-256 values remain
`aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54`,
`ae0ecb7fa7b16659b6a9ae5561176fa5c4d76788528b2ba8fc4bc533792824ae`,
and
`6734394082dac95355277f477f01ea9e0ee90cb03e28cc20508632f7d11ddb31`.
