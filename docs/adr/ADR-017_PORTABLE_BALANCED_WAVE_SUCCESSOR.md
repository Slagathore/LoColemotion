# ADR-017: Portable balanced-wave successor

- **Status:** BW2R-C selected and independently validated; first BW4 cold
  result rejected; the complete `116`-world BW4R-A/B family is rejected; the
  branch-free `174`-world BW5R-A/B/C filtered-feedback comparison selected
  BW5R-B for new independent validation
- **Date:** 2026-07-28
- **Decision scope:** the first non-Candidate-35 locomotion controller
- **Predecessor:** [ADR-016](ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md)
- **Evidence plan:**
  [Portable Balanced-Wave Successor Bootstrap](../SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)

## Context

Candidate 35 is an immutable legacy oracle. Its Godot/Jolt C6 selection
rejected, its constrained C6R successor rejected on cold held-outs, and its
P5I.3C-R2 stability overlay passed bounded physical-influence commissioning
without establishing recovery or robustness.

The first cold friction/material campaign then completed all `23/23` frozen
worlds at source `ac52b5cb7af46a419c5f661025929a8577b37cd0`. Its R1 result
rejected at `28/32` aggregate gates:

- `11/12` primary treatments;
- `3/4` matched controls;
- `4/4` paired causal-influence gates;
- `6/6` lower-friction diagnostics; and
- `1/1` zero-friction safety controls.

That result is retained at
`<evidence-root>\godot-jolt-material-robustness-r1-ac52b5c\report.json`
(SHA-256
`7c58a73df1187076087e1c2f47536030b8a1e9536b157ea8d6b7818f9bf6a0ef`).
It may inform a new controller but may not be converted into fresh acceptance
evidence.

The current portable core already owns:

- canonical morphology, state, command, actuation, and receipt schemas;
- deterministic lateral-wave phase scheduling and contact gates;
- whole-system center-of-mass and support-hull observation;
- static and linearized dynamic support margins;
- bounded centroidal command generation;
- full- and partial-support endpoint-force-to-joint maps;
- characterized canonical-torque to host-velocity conversion; and
- magnitude, slew, inactive-contact, infeasible, and unavailable fail-zero
  influence semantics.

The missing piece is a separately identified base controller that does not
select gains through Candidate 35's failure-shaped morphology branches.

## Decision

### 1. Create a new policy, runtime, and memory identity

The successor identifiers are:

```text
policy_id  = sporespore_balanced_wave_v1
profile    = sporespore_balanced_wave_profile_v1
runtime    = sporespore_balanced_wave_runtime_v1
memory     = sporespore_balanced_wave_memory_v1
receipt    = sporespore_balanced_wave_step_receipt_v1
```

Candidate 35 types, golden vectors, C ABI operations, and replay behavior remain
unchanged. The new policy is additive. It must not masquerade as Candidate 35
through an alias or by rewriting a policy identifier in an existing receipt.

### 2. Use a branch-free, dimensionally motivated base profile

For bounded quadruped descriptor torso-length scale `L`, the first profile is:

```text
cross_track_heading_gain_rad_per_m         = 1.0 / L
yaw_error_stride_gain_per_rad              = 1.0
cross_track_velocity_heading_gain_rad_per_m_s
                                             = 0.30 * sqrt(L)
contact_loaded_swing_knee_activation_step  = 0
contact_loaded_swing_knee_max_speed_rad_s  = 3.25
anchor_guard_activation_fraction           = 0.85
anchor_guard_max_speed_rad_s               = 2.25
```

`L` is already constrained by the canonical descriptor domain, so the formulas
need no interior clamp or threshold. The profile:

- contains no `S`, `F`, `W`, `H`, morphology ID, campaign role, sample index,
  prior outcome, or coverage-status selector;
- is continuous throughout the declared descriptor domain;
- uses no branch narrower than the generator or any opened cohort;
- keeps foot, hip, width, mass, and upper/lower proportions in the physical
  morphology and live feedback path rather than using them as manually
  selected gain regions; and
- records every compiled value in a canonical profile receipt.

These constants are frozen before implementation and before a balanced-wave
physics outcome is opened. A later candidate may change them only under a new
policy identity and new development/validation split.

### 3. Make the anchor guard independent of the legacy interaction score

Candidate 35 blends its anchor-error guard by
`morphology_interaction_score`; the reference body therefore receives zero
guard blend. Balanced-wave v1 uses the normalized anchor-error progress
directly:

```text
guard_progress =
  clamp(
    (anchor_error / maximum_anchor_error - 0.85) / (1.0 - 0.85),
    0,
    1
  )

guard_speed_limit =
  lerp(3.5 rad/s, 2.25 rad/s, guard_progress)
```

The guard remains restricted to the existing contact-loaded swing-knee
condition. It may reduce a target-speed limit; it may not command a body,
transform, velocity, force, or impulse.

### 4. Preserve the proven stability path

Balanced-wave v1 composes:

1. the new deterministic base wave;
2. the already-frozen portable stability observation and centroidal command;
3. the versioned partial-support joint map;
4. the characterized per-host torque-to-velocity profile; and
5. the P5I.3C magnitude, slew, saturation, unavailable, infeasible, and
   inactive-contact rules.

The first implementation does not add a learned residual. DReCon's
reference-plus-bounded-correction structure is adopted only as an architecture
pattern; its network, cadence, filter, gains, and humanoid constants are not
copied. The exact local PDF identity remains in the
[research source ledger](../research/LOCOMOTION_RESEARCH_SOURCES.md).

### 5. Keep one portable authority path

The Rust runtime is the sole balanced-wave policy implementation used for
physical authority. GDScript may independently calculate no-world golden
vectors and validate serialization, but a second hand-maintained full
balanced-wave controller is not an acceptance authority.

This removes Candidate 35's live legacy/native dynamic-parity gate from the new
controller. It does not remove:

- exact schema, order, finite-value, time, and capability checks;
- pure golden-vector checks;
- state/command/actuation receipt hashes;
- safe ordered-zero output on invalid input;
- adapter readback and host-quantization checks; or
- physical walking and robustness gates.

### 6. Separate development, validation, and cold acceptance

The opened P5M.3/R1 worlds are a **development-only replay set** for the new
controller. Passing them proves only that the implementation is ready to face
new evidence.

The balanced-wave evidence program uses:

- pure/no-world and opened-world development;
- a prospectively frozen validation campaign with new seeds and material
  values;
- one allowed candidate selection before cold acceptance; and
- a separate cold campaign whose material values, seeds, morphology indices,
  gates, and stopping rule are frozen before its first world.

No validation or cold failure is removed by averaging. No failed cell may be
replaced. A candidate changed after validation receives a new identity and
cannot reuse that validation as cold evidence.

### 7. Block cross-engine C6 until the nuisance ladder passes

Rapier and MuJoCo remain certified only through their declared C0-C5 slices.
Balanced-wave cross-engine C6 may open only after the exact policy build:

1. passes pure and Godot/Jolt authority commissioning;
2. passes the new Godot/Jolt material validation and cold campaigns;
3. passes frozen rough-terrain, push, and observation-fault campaigns on
   Godot/Jolt; and
4. has per-host material and actuator characterization receipts for Rapier and
   MuJoCo.

The engines may use different physical envelopes, but all shared semantic,
order, no-cheat, safety, and contact-progression booleans remain exact.

## Implementation outcome through BW2

BW2 implemented three prospectively identified branch-free candidates and ran
their reference, opened-material, and opened-counterexample development
cohorts. The fail-closed compiler verified all nine retained reports covering
`87/87` worlds and produced these first-five score vectors:

```text
BW2-A  0, 5, 0, 1, 6
BW2-B  0, 2, 0, 0, 2
BW2-C  0, 1, 0, 0, 1
```

BW2-C uniquely wins on the second metric and is frozen as
`sporespore_balanced_wave_bw2_c_v1`, candidate digest
`sha256:367e944b33384d8685d746dca0a864cfa33ca013846636236512641456d51ad3`.
The selection report is:

```text
<evidence-root>\balanced-wave-bw2-selection-4c42c2d\report.json
sha256:f307a8e51054a98a75fb580a54299f030700a11d22d1801196ff2719fe85d4ea
```

This is a development selection, not material acceptance. Selected BW2-C
still retained one eligible nonzero-friction treatment nonwalk. BW3 validation
and BW4 cold acceptance remain mandatory, and the cross-engine C6 interlock in
this ADR remains in force.

## Implementation outcome through BW2R

The first BW3 validation completed all `12/12` worlds but rejected at `21/22`
gates because `validation_mu070_s17002_treatment` exceeded the frozen lateral
drift bound. That result was retained and reclassified as opened development
evidence for a prospectively frozen branch-free recovery family.

BW2R-A/B/C changed only the global yaw-error stride gain to `1.1`, `1.2`, and
`1.3`. Each candidate ran the same `41`-world development matrix. The
fail-closed compiler verified all `123/123` worlds and selected BW2R-C under
the preregistered lexicographic rule. The report is:

```text
<evidence-root>\balanced-wave-bw2r-selection-924aa44\report.json
sha256:038e30c3a044ae5b01a0e6d440de6a12931bc7a1fae534c4eb86570784e92ea0
```

BW2R-C is policy `sporespore_balanced_wave_bw2r_c_v1`, digest
`sha256:709aacc898e62a0c1902a04a201006f5501934562cabec4b68c1613811ae0ad0`.
It remains branch-free. It is a development winner, not material,
generalization, recovery, or cross-engine acceptance.

## Implementation outcome through complete BW4R development

BW2R-C subsequently passed its separate BW3R validation at `22/22` gates over
`12/12` worlds. Its first complete BW4 cold result then retained `17/17`
worlds but rejected at `27/28`: `11/12` positive treatments, all four
controls, all four matched pairs, and the zero-friction safety control passed.
The sole nonwalk was `validation_mu140_s18001_treatment`, which exceeded the
unchanged `0.10 m` legacy world-Z lateral bound. The report is:

```text
<evidence-root>\balanced-wave-bw4-validation-83c6142\report.json
sha256:539f0a724470723b445ea3ade443d8125e9934593b456a64898843d33938d550
```

That result closes the BW2R-C source identity without material acceptance. It
also exposed a controller cadence issue: the state-feedback steering request
was recomputed once every `90` semantic steps and held between samples.

BW4R-A and BW4R-B therefore inherit every BW2R-C gait/gain/material/morphology
field and differ only in prospective, global feedback timing:

- BW4R-A recomputes and directly applies the already-bounded request every
  semantic step.
- BW4R-B does the same but limits each steering-fraction change to `0.80/90`.

Both policies are branch-free over friction, material, morphology, seed,
cohort, and outcome. Before their first physics world, future receipts and
gates were also corrected to use frozen task-frame forward/lateral projections
instead of the historical world-X/Z proxy; the lateral threshold remains
`0.10 m`.

The preregistration requires `58` worlds per candidate and forbids early
stopping. Only the complete `116`-world compiler result can select a candidate,
and zero opened-BW4 positive-treatment nonwalks is mandatory. Selection is
development authority only; disjoint independent validation and cold material
acceptance still precede terrain, push, sensor, engine, or C6 work.

The complete comparison ran from clean, pushed source
`b538bea3656600fcd56f94cb62a8391a0a932bb0`. All `116/116` worlds completed
with zero execution/integrity failures. BW4R-A had three opened-BW4 treatment
nonwalks; BW4R-B had one. Because neither met the mandatory zero-nonwalk
eligibility rule, the compiler rejected the complete candidate family and
selected no policy:

```text
<evidence-root>\balanced-wave-bw4r-selection-b538bea\report.json
sha256:23bc6f88c46cbed8b848efd9b2663757fd2f33c5c2f9d260e69e4ddc35d6718b
```

This negative is consistent with the ADR: the branch-free candidates were
allowed to perform worse, and failure does not authorize restoring Candidate
35 branches. A later successor requires a new global mechanism, policy
identity, digest, and prospectively frozen complete comparison before another
physics world. The unused BW4R validation/cold reservations remain unopened.

## BW5R decision before physical execution

BW5R adopts the higher-rate filtered-correction experiment shape that the
[research source ledger](../research/LOCOMOTION_RESEARCH_SOURCES.md) recorded
before the BW4R outcomes. Its source is:

```text
<repo>\DReCon.pdf
sha256:aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54
DOI:10.1145/3355089.3356536
relevant pages:5-7
```

Only DReCon's deterministic-reference plus bounded, recursively filtered
correction pattern is adopted. Its learned policy, query rate, numeric `beta`,
humanoid constants, and empirical conclusions are not portable constants or
LoColemotion evidence.

Each BW5R candidate inherits every BW2R-C gait, morphology, material,
stability, actuator, mapping, and limiter field. All update feedback every
semantic step, then apply:

```text
filtered[n] =
  filtered[n-1] + alpha * (bounded_raw[n] - filtered[n-1])

alpha =
  1 - exp(-1 / (time_constant_cycle_fraction * 360))
```

BW5R-A, BW5R-B, and BW5R-C respectively freeze time constants of `1/32`,
`1/16`, and `1/8` gait cycle. These factor-of-two arms are global. They contain
no friction, material, morphology, seed, cohort, failed-cell, or outcome
condition, and every `branch_surfaces` list is empty.

The exact contract is
[`../../sdk/balanced_wave_bw5r_preregistration.json`](../../sdk/balanced_wave_bw5r_preregistration.json).
It binds all candidate/profile digests, the v2 per-step mechanism receipt,
complete `58`-world replay per candidate, `174/174`-world all-candidate
requirement, no-early-stop rule, unchanged `0.10 m` task-frame lateral gate,
zero-opened-BW4-treatment-nonwalk eligibility rule, and disjoint future
validation/cold reservations.

A selected candidate receives development authority only. Its implementation
must be committed before the new validation values `{0.05, 0.65, 1.30}` and
seeds `{19501, 19502, 19503}` can be characterized or opened. Cold values
`{0.12, 0.48, 0.95, 1.50}` and seeds `{20001, 20002, 20003}` remain hidden
until after validation.

## Complete BW5R development outcome

Clean pushed source `d17b77afefddb19ae401f3f8f2e8b3b7708a02e6`
completed all `174/174` worlds and all `15` reports with zero
infrastructure/integrity failures. The retained selector is:

```text
<evidence-root>\balanced-wave-bw5r-selection-d17b77a\report.json
sha256:d2819d1bca45592fe54f1fc22cd2ad19d64fb3cd9eafd8ad848601338f8b50fc
```

BW5R-A and BW5R-B both met the mandatory zero-opened-BW4-treatment-nonwalk
gate. BW5R-C had one opened-BW4 treatment nonwalk and was ineligible. The next
metric was therefore decisive: A had three and B had two nonwalks across all
opened nonzero-material treatment partitions. The compiler selected BW5R-B,
policy `sporespore_balanced_wave_bw5r_b_v1`, digest
`sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f`.

The selected policy retains the global `1/16`-cycle filter, empty branch
surfaces, and every frozen parent field. Selection grants development
authority only. New independent material characterization/validation and the
separate cold partition remain mandatory before terrain, push, sensor,
cross-engine, or C6 work.

## BW5V validation boundary

The selected implementation was committed at
`142392fe62ab3549b215946fa2a3b0537e5409d4` before the independent material
partition opened. `sdk/balanced_wave_bw5v_preregistration.json` now binds the
previously reserved values `{0.05, 0.65, 1.30}`, seeds
`{19501, 19502, 19503}`, exact selected policy/profile digests, and the
complete BW5R selector hash. Its `6/6` preflight constructs no physics world.

The next permitted observation is a source-clean, pushed, immutable
`10`-world isolated characterization. Only after a successful result and
source-bound profile publication may a separate `12`-world independent
locomotion manifest open. The cold reservation
`{0.12, 0.48, 0.95, 1.50}` / `{20001, 20002, 20003}` remains unopened.

The first characterization completed `10/10` worlds and `19/19` gates at
source `2a5eb94dca81a8c638e31a0d7c9692c270b44ca6`; its report SHA-256 is
`a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84`.
It authorizes only three Godot/Jolt profile coefficients: `0.05`, `0.63`,
and `1.00`. The result does not change the selected portable policy and does
not establish locomotion robustness.

The zero-world publication is retained from clean pushed source
`e76477be61d90829dab0eb70a89505d521e7f8a5`:

```text
<evidence-root>\balanced-wave-bw5v-material-profiles-e76477b\report.json
sha256:2430c1a77d7007c13c3a5262e19fba7693154ba40ea61aa3d1cf601844a2a37c
```

The next observation is governed by
[`../../sdk/balanced_wave_bw5v_validation_manifest.json`](../../sdk/balanced_wave_bw5v_validation_manifest.json)
and
[`../../sdk/run_balanced_wave_bw5v_validation.ps1`](../../sdk/run_balanced_wave_bw5v_validation.ps1).
Its zero-world preflight binds `12` cells, `22` gates, all prerequisite hashes,
and the still-unopened cold reservation. It grants no result authority by
itself. The first complete result from its clean pushed source is final for
that source identity and cannot be repaired or selectively rerun.

That first result has now passed from source
`7d8b046f752974b8d9498db91b0d46ae99ac1729`:

```text
<evidence-root>\balanced-wave-bw5v-validation-7d8b046\report.json
sha256:a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee
```

The complete outcome is `22/22` gates, `12/12` worlds, `9/9` treatments,
`3/3` matched controls, `3/3` causal pairs, and zero integrity failures.
BW5R-B receives independent development-validation authority for those exact
Godot/Jolt profiles only. The ADR still requires the disjoint cold material
partition before nuisance or cross-engine commissioning; no policy, branch,
gate, or threshold changes are authorized by this pass.

## Consequences

### Benefits

- The next controller is not another Candidate 35 branch.
- Morphology influences geometry, dynamics, normalization, and feedback
  continuously rather than selecting narrow hand-authored regions.
- Reference-body structural protection no longer disappears because its
  interaction score is zero.
- The same policy identity can be commissioned across all three hosts.
- Opened material failures become development input without being relabeled as
  acceptance evidence.

### Costs and risks

- The runtime needs a new versioned path rather than a one-line profile swap.
- A branch-free policy may perform worse than Candidate 35 on some opened
  morphologies; that is an admissible result, not permission to restore hidden
  branches.
- The first cold campaign can still reject. A negative result narrows the
  support matrix and motivates a new policy identity.
- This decision does not yet generalize the quadruped phase scheduler to
  arbitrary limb topology.

## Explicit nonclaims

This ADR does not establish:

- walking by balanced-wave v1;
- material, terrain, push, latency, or sensor-fault robustness;
- balance improvement or recovery;
- arbitrary-quadruped or continuous-volume coverage;
- Rapier or MuJoCo locomotion;
- multi-leg, running, or biped capability; or
- a completed engine-neutral SDK.

## BW5C cold-partition addendum

The accepted BW5V independent-validation result is retained at
`<evidence-root>\balanced-wave-bw5v-validation-7d8b046\report.json`
with SHA-256
`a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee`.
It authorizes opening, but does not itself pass, the previously reserved cold
partition.

[`../../sdk/balanced_wave_bw5c_preregistration.json`](../../sdk/balanced_wave_bw5c_preregistration.json)
freezes that partition at friction `{0.12, 0.48, 0.95, 1.50}` and seeds
`{20001, 20002, 20003}` while preserving the selected BW5R-B policy and its
empty branch-surface set. The material-instrument phase is `13` worlds and
`23` gates. Its zero-world entry point is:

```powershell
.\sdk\run_balanced_wave_bw5c_material_characterization.ps1 -PreflightOnly
```

After a passing characterization and immutable profile publication, a
separate manifest must freeze the `17`-world, `28`-gate cold locomotion
matrix. No change to the selected policy, selected profile, branch topology,
material/morphology/seed routing, or acceptance thresholds is authorized
between these phases. A negative first result remains evidence and requires a
new preregistered policy identity rather than repair of BW5C.

The first characterization result passed `23/23` gates over `13/13` worlds
from physics source `dca2618bd1cb42768235bc69711eb3dab6b2379a` and is
retained at
`<evidence-root>\balanced-wave-bw5c-material-characterization-dca2618\report.json`
with SHA-256
`067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143`.
Its recovery metadata records that Godot completed once, the outer command
host did not package the result, and finalizer source `2dc17b5` retained the
one complete engine-log receipt without rerunning physics.

The published controller coefficients are `0.10`, `0.45`, `0.94`, and
`1.00`; all four adapter profiles pass the `36/36`, `25`-profile, zero-world
gate. The ADR's cold locomotion requirement remains unchanged.

The publication is retained from clean pushed source `677e97e` at
`<evidence-root>\balanced-wave-bw5c-material-profiles-677e97e\report.json`
with SHA-256
`381132c430140ec4b70a1cff65d7099974bf1b6eefa59bafa523c1b287076c97`.

[`../../sdk/balanced_wave_bw5c_validation_manifest.json`](../../sdk/balanced_wave_bw5c_validation_manifest.json)
now implements the required separate freeze, and
[`../../sdk/run_balanced_wave_bw5c_validation.ps1`](../../sdk/run_balanced_wave_bw5c_validation.ps1)
provides its source-bound execution. The zero-world preflight passes against
the exact `17`-world/`28`-gate contract. This decision record still grants no
cold acceptance from the preflight; the first complete clean-pushed physical
result remains final for its source identity.

That first result passed from source
`dac405df52abfda12f5633022e6814b02f561a3e` and is retained at
`<evidence-root>\balanced-wave-bw5c-validation-dac405d\report.json`
with SHA-256
`6648c1473c97d2b7229ba0decd8881ca2d8f06e68ca9737d7255120dab2653da`.
It completed the exact `28/28` gate, `17/17` world contract with all
treatments, controls, causal pairs, and the zero-friction safety cell passing.

The decision now authorizes walking and bounded discrete material robustness
only inside that report's Godot/Jolt scope. The ADR continues to withhold
continuous or arbitrary material coverage, physical recovery, nuisance
robustness, fresh morphology, other-engine locomotion, cross-engine C6, and
completed-SDK authority.

## BW6N nuisance-ladder addendum

The next ADR-ordered interlock is now source-frozen in
[`../../sdk/balanced_wave_bw6n_validation_manifest.json`](../../sdk/balanced_wave_bw6n_validation_manifest.json).
BW6N changes no controller parameter or policy identity. It holds BW5R-B, the
reference fixture, `godot_jolt_bw5c_mu095_v1`, the GQ15 clock, the Godot/Jolt
solver policy, and fresh seeds `{21001, 21002, 21003}` constant.

The `12` ordered worlds comprise three active-policy baselines and three worlds
each for rough geometry, one task-lateral external impulse, and deterministic
additive observation noise. The rough profile is an explicit `64`-tile height
strip. The push is applied once at SDK step `540`, is separately receipted,
and is not controller authority. The sensor profile perturbs base/joint state
and stability body/support observations at the adapter boundary without
writing physics state.

[`../../sdk/run_balanced_wave_bw6n_validation.ps1`](../../sdk/run_balanced_wave_bw6n_validation.ps1)
passes the zero-world preflight. The separate zero-world challenge contract
passes `9/9`. These checks freeze implementation and reject unknown fields,
nominally rough flat geometry, non-lateral hidden push components, and
out-of-envelope sensor amplitudes. They expose no locomotion outcome.

The first full clean-pushed run is all-or-nothing at `24/24` gates and
`12/12` worlds. It cannot grant more than bounded Godot/Jolt rough-terrain,
push-recovery, sensor-noise, and physical-recovery evidence for those exact
profiles. Arbitrary/continuous terrain, arbitrary pushes or faults, sensor
latency, combined challenges, fresh morphology, cross-engine C6, and
completed-SDK authority remain false regardless of the outcome.

### BW6N physical decision

The first complete run from source
`e44a7e2fabf7547aaba778a94c0f3eaa64b1920e` is final and rejected. Its retained
report is:

```text
<evidence-root>\balanced-wave-bw6n-validation-e44a7e2\report.json
sha256:8fe82a73b4bd8bae9789932fda47af2104b6204a4594a62c44998019ca949442
```

The campaign completed `12/12` worlds and passed `16/24` gates. Per-axis
ordinary-walking totals were baseline `2/3`, rough `1/3`, push `2/3`, and
sensor noise `2/3`. All challenge-realization gates and all `12` stability
influence gates passed. The repeated `s21003` miss on
`evidence_four_contact_stance` in baseline, push, and sensor cells is a common
baseline weakness. Rough `s21001` and `s21002` add separate terrain failures.

Decision: do not edit BW6N thresholds, profiles, or results. Do not promote its
successful individual cells into axis acceptance. Keep every nuisance and
physical-recovery claim false. Any successor must receive a new source freeze
and disjoint physical identity, and must treat the evidence-start protocol plus
rough-terrain gait completion as observed development problems rather than
retroactively relaxing BW6N.

### Opened-world causal addendum

The behavior-neutral replay runner
[`../../sdk/run_balanced_wave_bw6n_opened_diagnostic.ps1`](../../sdk/run_balanced_wave_bw6n_opened_diagnostic.ps1)
completed the already-opened baseline and rough cells from clean pushed source
`61895351550003dadfcab24f0b08bf49ae9f293d`. Its non-acceptance report is:

```text
<evidence-root>\balanced-wave-bw6n-opened-diagnostic-6189535\report.json
sha256:fc370752d51ae1b1571cf9179fc483132b008ee859fc814494dbafbf0529569c
```

The `s21003` result narrows the prior phrase “baseline weakness.” Only
`front_right` was non-bearing at nominal evidence start, all four feet bore
support two ticks later, no contact gate timed out, all four limbs completed
the evidence horizon, and terminal four-contact recovery passed. This is an
evidence-start acquisition defect under the preregistered phase jitter. It
does not reverse BW6N, and its observed two-tick delay may not be copied as a
fitted successor bound.

The rough failures remain behavioral. Rough `s21002` timed out `await_release`
on the two front limbs at ticks `1471` and `1779` while they remained bearing.
Rough `s21001` had no timeout, but three `rear_right` recontacts failed the
unchanged `0.015 m` forward-relocation rule and lateral displacement reached
`0.100246 m` with `384` steering-saturation steps. The successor may change
neither timeout nor walking thresholds. Its development family must keep an
empty branch surface and test portable, morphology-normalized
release/unweighting and path/foothold-progression mechanisms, followed by a
disjoint cold partition.
