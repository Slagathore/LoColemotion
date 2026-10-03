# BR14A Quadruped Generalization Bootstrap

Status: GP5 completed its clean `13/13` selection and `12/12` fresh held-out
confirmation for `625/625` assertions from one exact pushed source. This
establishes a bounded morphology-adaptive quadruped walking system over the
declared 17-shape, three-perturbation envelope. Earlier rejected campaigns
remain rejected, including G2-GS1's `1.100` uniform-scale endpoint and the
globally fixed GP3/GP4 nonuniform controllers. Generated seeds, continuous
six-dimensional coverage, arbitrary quadrupeds, other limb counts, accepted
knowledge, and automatic creature guidance remain unestablished.

Long-term product extraction is governed by the
[Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).
The three supplied research papers, exact local PDF paths and hashes,
page-level findings, limitations, and adopted requirements are preserved in the
[Locomotion Research Sources and Adoption Ledger](research/LOCOMOTION_RESEARCH_SOURCES.md).
Those documents do not alter a preregistered campaign, reopen a rejected
campaign, or promote development observations.

## Mission

Convert the current physical quadruped from one reproducible walking creature
into the smallest defensible reusable walking system.

The reference walker must remain exactly reproducible throughout this work.
Generalization is successful only when the same controller family, without
root force, root impulse, root velocity, root transform, teleport, or world
reset authority, walks more than one declared physical fixture.

## Pinned reference state

Source commit:

```text
e763cfae1c7040bf97b8444e5db5bcafcb909b9f
```

Exact nominal campaign:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_nominal_walk_committed_e763cfa\
  20260725T220001844\report.json
sha256:c130636b16e99916449e4a197f34a1ee28909c37217c333baa6d6f2146bc4370
57/57 assertions
```

Bounded initial-condition campaign:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_seeded_robustness_committed_e763cfa\
  20260725T215909896\report.json
sha256:6751ffb414501d70747e525d94cb27120e9a7d34b640aff2482cce049b2c107e
66/66 assertions
scoped_source_tree_dirty=false
```

Complete ordinary-solver BR14A family:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_family_post_seeded_e763cfa_retry_held\
  reports\20260725T221437070\report.json
sha256:754ebe7bc677fda86ae0948ee189af24ad5ae2f9a89e867f27581ebd9e6f7739
24/24 programs
414/414 assertions
```

The family report records zero failed programs, timeouts, killed process
trees, open containment trees, nonzero exits, engine-error programs,
unexpected engine errors, and missing or unreadable logs.

The reference fixture is one `3.0 kg` torso, four `0.25 kg` upper-leg
bodies, four `0.18 kg` distal spherical foot bodies, and eight hinge motors.
It uses the isolated Jolt `20/6` solver at 120 Hz. The repository-wide BR14A
family remains pinned to Jolt `20/4`.

## Non-negotiable boundaries

- Preserve the reference fixture's exact deterministic movement receipts.
- Keep the solver-6 walking programs isolated from the ordinary solver-4
  family.
- Build one physics world once per run and never reset it.
- Apply locomotor authority only through declared joint motors.
- Record every realized fixture parameter, controller parameter, seed, gate,
  failure code, source hash, and engine log.
- Keep development observation separate from formal milestone acceptance and
  accepted knowledge.
- Do not change a threshold after seeing a failing generated fixture and then
  count that fixture as preregistered evidence.
- Vary one physical axis at a time before testing interactions.

## Generalization ladder

### G0: identity-preserving morphology specification

Extract the hardcoded reference fixture and actuator properties into one
normalized, fail-closed physical-quadruped fixture specification. Keep gait
policy in a separate normalized controller configuration so later experiments
can distinguish a new body from a retuned controller. The first accepted
fixture spec must be an identity mapping to the current constants:

- torso mass and size;
- upper and distal mass;
- upper and lower segment length;
- foot radius;
- longitudinal and lateral hip layout;
- initial torso height and hip-height offset;
- collision margin and contact material;
- hip and knee limits;
- hip and knee motor impulse bounds.

The walking summary must return the fully normalized fixture spec, controller
configuration, and stable digest for each. Unknown fields, nonfinite values,
nonpositive dimensions or masses, asymmetric limb omissions, invalid joint
ranges, and interpenetrating initial geometry must fail before world
construction.

G0 passes only if three fresh reference runs retain the exact current
displacement, contact-cycle, structural, and safety receipts.

#### G0 completion evidence

G0 was implemented and pushed in two commits:

```text
8bca78abe046f31115ff7ed942a5dcad5252bb35
  feat(locomotion): extract physical quadruped fixture spec
4382e8640a669759fdf8dca4825315f664d73b65
  test(locomotion): bind walking to fixture digests
```

The normalized reference fixture is pinned to:

```text
sha256:18361994a68e2a9a150aa539aff39679ba4b6e892092e26d218b08f6e12e9c3b
```

The compiler builds no world, rejects unknown or invalid physical fields, and
fails a mismatched expected digest before world construction. Fixture data
contains no claim or guidance authority. The physical walking summary returns
the normalized fixture, its digest, the separate controller configuration, and
the controller-configuration digest.

Fresh committed-source nominal evidence:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g0_digest_hardening_nominal_committed_4382e86\
  20260725T232345098\report.json
sha256:88fdc83b4caa5891ec6be3827ea99da037e4323c138a3c298d1b33822925f522
source_commit=4382e8640a669759fdf8dca4825315f664d73b65
3/3 repetitions
57/57 assertions
```

All three runs retained the exact reference displacement, contact-cycle,
structural, and safety receipts.

Fresh committed-source bounded initial-condition evidence:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g0_digest_hardening_seeded_committed_4382e86\
  20260725T232428819\report.json
sha256:6acfecb2576111abcff1c7af5e1a21900310dc200f0c40ef840e6ed38e1062e8
source_commit=4382e8640a669759fdf8dca4825315f664d73b65
scoped_source_tree_dirty=false
3/3 seeds
66/66 assertions
```

The complete ordinary-solver family also passed from the post-G0 tree:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_family_post_g0_4382e86\
  reports\20260725T232556373\report.json
sha256:6d50e23a6a3e068b36d0fb1881fc7a07e0ac40f2f303f3864f85a8d4fc6e9872
25/25 programs
440/440 assertions
```

That report records zero failed programs, timeouts, killed process trees, open
containment trees, nonzero exits, engine-error programs, unexpected engine
errors, missing or unreadable engine logs, and missing or unreadable
transcripts.

This completes identity equivalence only. No non-reference fixture has walked
yet, so G0 is not evidence for a reusable walking system or morphology
generalization.

### G1: mass and contact-material robustness

Keep geometry fixed while varying physical load. Run separate campaigns for:

1. torso mass;
2. upper-leg mass;
3. distal mass; and
4. floor/body friction.

The first probe should hold motor limits fixed to measure the controller's
native robustness. If it fails, a second declared controller variant may scale
motor impulse from the normalized physical spec. Native and adapted results
must remain separate evidence families.

Do not combine mass and friction variation until each single-axis campaign has
a passing and a failing boundary.

#### Preregistered G1-TM1 torso-mass campaign

The first G1 campaign varies only torso mass. Before any G1-TM1 physics result
is observed, the candidate set is fixed to:

```text
2.4 kg  reference -20%
2.7 kg  reference -10%
3.0 kg  reference baseline
3.3 kg  reference +10%
3.6 kg  reference +20%
```

Every other normalized fixture field is byte-for-byte equal to the G0
reference fixture. In particular, limb masses, geometry, material, dynamics,
joint limits, and the physical motor impulse bounds do not change.

The controller is fixed across all five masses:

```text
motor_direction_sign=-1.0
knee_motor_impulse_scale=10.0
knee_flexion_scale=1.75
gait_phase_order_id=lateral
swing_ticks=72
contact_clearance_assist_rad=0.40
contact_clearance_assist_limb_id=all
evidence_boundary_alignment_ticks=112
contact_gated_phase_progression=true
maximum_contact_gate_hold_ticks=96
maximum_contact_gated_phase_skew_ticks=12
lateral_stride_steering_gain_per_m=0.5
initial_perturbation=none
```

The campaign must execute each mass in a fresh private solver-6 process and
record the source commit, normalized fixture and digest, controller
configuration and digest, complete named walking gates, output logs, and engine
errors. It must prove that all realized fixtures differ from the reference only
in `torso.mass_kg`, and that every mass receives the same controller digest.

No motor, timing, threshold, or steering parameter may be changed after seeing
a result and still count as G1-TM1. The existing absolute walking gates remain
unchanged. A failed candidate remains a recorded boundary observation rather
than being silently omitted or retuned.

One pass per mass is an exploratory boundary scan. Three fresh passes per mass
are required before calling a mass point reproducible. Even five reproducible
points establish only bounded torso-mass robustness for this geometry and
controller; they do not complete G1, G4, or morphology-general walking.

#### G1-TM1 exploratory result

The clean committed-source scan completed:

```text
source_commit=f169d997b6c72595c1eb8b3557a0e92df23ab4dc
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tm1_exploratory_committed_f169d99\
  20260726T002422062\report.json
sha256:16a27c0cafd02824b888dea424fa0bbe37b7e842ef5e6f58cc3a241c217264e3
scoped_source_tree_dirty=false
5/5 harnesses
70/70 assertions
0 engine errors
```

Every cell used controller digest:

```text
sha256:f5685147b63d6f23bc507489d89052ff1fe26c8ea52cf9d7315c7920b2309d29
```

All five fixture digests were distinct. The measured walking outcomes were:

```text
2.4 kg  false  lateral drift, yaw drift, and anchor-error gates failed
2.7 kg  false  lateral drift and anchor-error gates failed
3.0 kg  false  lateral-drift gate failed
3.3 kg  false  lateral-drift gate failed
3.6 kg  true   every named walking gate passed
```

All five cells completed repeated forward-relocating foot-contact cycles and
positive torso advance. The failed cells are locomoting physical outcomes, but
they are not walking outcomes under the unchanged predicate.

The `3.0 kg` result does not invalidate the G0 reference witness. G1-TM1 uses
contact-gated phase progression and joint-only lateral steering, while the
exact G0 nominal controller uses the normalized default robustness options.
G1-TM1 therefore establishes one exploratory non-reference walking observation,
not two same-controller walking fixtures, a reproducible mass point, a native
mass boundary, bounded mass robustness, G1 completion, or morphology-general
walking.

#### Preregistered G1-TM2 exact-reference-controller campaign

G1-TM2 retains the same five torso masses and every unchanged fixture field,
motor limit, gait parameter, solver setting, and walking threshold from
G1-TM1. It changes only the declared controller evidence family: every cell
uses the exact G0 nominal robustness configuration:

```text
contact_gated_phase_progression=false
maximum_contact_gate_hold_ticks=48
maximum_contact_gated_phase_skew_ticks=12
lateral_stride_steering_gain_per_m=0.0
initial_perturbation=none
```

The other fixed controller parameters remain:

```text
motor_direction_sign=-1.0
knee_motor_impulse_scale=10.0
knee_flexion_scale=1.75
gait_phase_order_id=lateral
swing_ticks=72
contact_clearance_assist_rad=0.40
contact_clearance_assist_limb_id=all
evidence_boundary_alignment_ticks=112
```

Every mass must use the same independently recorded controller digest. Walking
false remains a valid harness outcome, every failed gate must be preserved,
and no G1-TM2 parameter may be changed after observing the scan. The
preregistered question is whether the already-proven G0 controller walks at
least one non-reference mass without retuning. One scan per mass is
exploratory; three fresh passes are still required for reproducibility.

#### G1-TM2 exploratory result

The clean immutable-source scan completed:

```text
source_commit=92d13c3a13865d9e09070a847ae3fddad3ada113
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tm2_exploratory_committed_92d13c3\
  20260726T003258240\report.json
sha256:3d60c6fd2b487ab34581d6da5d23d7c8a5d17466d789279d3740321499da3b87
scoped_source_tree_dirty=false
immutable_source_snapshot=true
5/5 harnesses
75/75 assertions
0 engine errors
```

Every cell used exact-reference controller digest:

```text
sha256:dedebe10a8142d05b5c28527c65588069631a32bab399247688f9ee59b5a65de
```

The measured outcomes were:

```text
2.4 kg  false  front-left cycle, lateral-drift, and anchor-error gates failed
2.7 kg  false  front-left cycle/relocation and lateral-drift gates failed
3.0 kg  true   exact G0 trajectory and every named walking gate reproduced
3.3 kg  false  lateral drift was 0.112340 m against the 0.100000 m bound
3.6 kg  false  lateral drift was 0.251181 m against the 0.100000 m bound
```

TM2 confirms that the exact reference controller is sharply mass-sensitive.
It does not walk a second fixture in this grid. Together, TM1 and TM2 show that
different fixed configurations can walk `3.6 kg` and `3.0 kg` respectively;
that is not same-controller robustness and is not yet a reusable walking
system.

#### Preregistered G1-TC1 lateral-gain selection and held-out validation

The next development screen keeps contact-gated phase progression disabled and
changes only the joint-target lateral steering gain. The committed selection
grid is:

```text
0.05 per m
0.10 per m
0.15 per m
0.20 per m
0.25 per m
```

Every candidate is evaluated once at the already-observed `3.0 kg` reference
and `3.3 kg` near-miss fixture. All other controller, fixture, solver, and gate
values remain exactly those of TM2. A gain is eligible only if both cells pass
every unchanged walking gate. The deterministic selection rule is the smallest
eligible gain. If no gain is eligible, TC1 selects no controller and no
within-campaign retuning is allowed.

TC1 is controller development, not generalization evidence, because its two
masses participate in selection. Before selection results exist, the held-out
validation masses are fixed to:

```text
3.10 kg
3.20 kg
3.40 kg
```

After TC1, the selected controller digest must be locked and used without
retuning in three fresh private processes per held-out mass. The initial
same-controller bounded-mass gate requires all `9/9` held-out runs to pass the
unchanged physical walking predicate with one fixture digest per mass and one
controller digest across all runs. Any failure remains evidence and defeats
that gate; no mass may be removed after observation.

Even a `9/9` validation pass would establish only bounded torso-mass robustness
for one quadruped geometry and controller configuration. It would be the first
defensible step from a walking creature toward a walking system, but it would
not complete the remaining G1 axes, G4, or arbitrary-morphology locomotion.

#### G1-TC1 selection result

All ten committed selection cells completed from clean immutable source at
`5c2af56b31b81b9adf0f31261fa0a62c15dcd838`. Each gain report passed both
harnesses, `30/30` assertions, and recorded zero engine errors:

```text
gain  3.0 kg  3.3 kg  eligible  report sha256
0.05  false   false   false     e44f37b939feddabfcf9f1e87d4d7a9c0b1f1dedcab5d20550a5f6491eab26fb
0.10  false   true    false     f95623d2ecc2adc0f39aea3b1e68962af66e23f37a393e12b937dcd5f01abad4
0.15  false   false   false     2b184007e9d8f8670ba8a2301fd9a48fd3b360603fc39ec815c82d1ea88ca2cb
0.20  false   false   false     9e93a5bc972fde4e35609b22c6b5da55e4af71b453bfd51421542a68dab919b5
0.25  false   true    false     e2ea570c2a4a7c6f79f484e56e03276da728fefe6e10660db478457bae6737b3
```

The reports are under:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc1_g005_5c2af56\20260726T004011009\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc1_g010_5c2af56\20260726T004108545\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc1_g015_5c2af56\20260726T004210211\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc1_g020_5c2af56\20260726T004305494\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc1_g025_5c2af56\20260726T004403286\report.json
```

TC1 therefore selects no fixed-gain controller. The 3.3 kg fixture does walk
at gains `0.10` and `0.25`, while the 3.0 kg fixture walks at its already-proven
gain `0.0`; this motivates a separately declared mass-adaptive policy rather
than pretending that any TC1 candidate passed selection.

#### Preregistered G1-TC2 linear mass-adaptive steering policy

TC2 uses the two controller-development endpoints observed before validation:

```text
3.0 kg -> lateral_stride_steering_gain_per_m=0.0
3.3 kg -> lateral_stride_steering_gain_per_m=0.10
```

The complete policy is fixed before any held-out result:

```text
slope = (0.10 - 0.0) / (3.3 - 3.0) = 1/3 per (m * kg)
gain(mass_kg) = clamp((mass_kg - 3.0) / 3.0, 0.0, 0.25)
contact_gated_phase_progression=false
maximum_contact_gate_hold_ticks=48
maximum_contact_gated_phase_skew_ticks=12
initial_perturbation=none
```

Every other controller, fixture, solver, and walking-gate field remains exactly
TM2. The policy itself receives one canonical digest across all runs; the
realized controller digest may differ by mass only because the policy-derived
gain differs.

The untouched validation masses remain `3.10`, `3.20`, and `3.40 kg`, producing
gains `1/30`, `1/15`, and `2/15` per meter. Each mass must run three times in a
fresh private process from an immutable source snapshot. The TC2 validation gate
requires all `9/9` runs to pass every unchanged physical walking gate, one
fixture digest per mass, one controller digest per mass, and one policy digest
across all runs. Any failure defeats the gate and may not be removed or retuned.

TC2 is a mass-adaptive controller-policy test, not a fixed-controller
generalization test. A `9/9` pass would establish bounded adaptive torso-mass
robustness for this one geometry, not G1 completion or arbitrary-morphology
walking.

#### G1-TC2 held-out result

The three counted clean committed-source held-out repetitions completed:

```text
source_commit=a0fee3836430ca0685ae94e0da0518e8b3598100
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc2_repeat1_a0fee38\20260726T005158248\report.json
sha256:4e4f5fafa2d45aa8824ea2d036c6b75878ef16c089b989a6d55d1cb69173bc6b
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc2_repeat2_a0fee38\20260726T005332921\report.json
sha256:5a0ff2088ca495f613864ddb7eabae7790e7fd20e64068965d158fe141ef0317
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc2_repeat3_a0fee38\20260726T005514258\report.json
sha256:33dbc2dc4f2a6e5c4cdcbf5d73543ad2616a7446c35b1f9e11036bea8e0b1a95
scoped_source_tree_dirty=false
immutable_source_snapshot=true
9/9 harnesses
144/144 assertions
0 engine errors
policy_sha256=sha256:a165499aeac4df385d5692a1fbaec2b558abe93884887245dfb0e45131eed699
```

All three held-out fixtures failed the unchanged walking predicate identically
in all three repetitions:

```text
3.10 kg  false  front-limb cycle/relocation and lateral-drift gates failed
3.20 kg  false  lateral-drift gate failed at 0.237225 m
3.40 kg  false  front-right cycle and lateral-drift gates failed
```

The `9/9` TC2 validation gate is therefore defeated at `0/9` walking runs. TC2
establishes no adaptive mass robustness and no walking system. An additional
independent first-repetition report exists at
`<evidence-root>\temp-roots-2026-07-28\sporespore_g1_tc2_adaptive_committed_a0fee38`, but it is corroborating
development output and is not counted in the preregistered nine-run result.

The failure pattern also rejects the assumption behind TC2: interpolating an
instantaneous world-frame lateral-error gain does not interpolate physical gait
behavior. Small gain changes caused nonmonotonic accepted-cycle loss and large
left/right drift reversals. Further scalar gain interpolation is not the next
experiment.

#### Preregistered G1-S1 phase-bounded path-steering development

G1-S1 replaces the legacy instantaneous lateral-error multiplier with a
two-loop, phase-bounded path controller. The existing exact controller remains
the default; S1 is opt-in and must not change any G0 receipt when disabled.

The controller uses the torso's initial heading frame:

```text
cross_track_m = dot(torso_position - initial_position, initial_lateral_axis)
desired_heading_error_rad =
  clamp(-cross_track_heading_gain_rad_per_m * cross_track_m, -0.25, 0.25)
yaw_tracking_error_rad =
  wrap((current_yaw - initial_yaw) - desired_heading_error_rad)
steering_fraction =
  clamp(yaw_error_stride_gain_per_rad * yaw_tracking_error_rad, -0.20, 0.20)
```

The steering fraction continues to act only through differential left/right
hip-motor targets. It grants no root force, impulse, velocity, transform,
teleport, or world-reset authority. Unlike the rejected legacy controller, S1
updates the steering fraction only on deterministic `90`-tick gait-quarter
boundaries and holds it constant between updates. Every update must record
tick, cross-track error, measured yaw error, desired heading error, yaw
tracking error, and commanded fraction.

S1 controller selection uses the already-observed `3.0` and `3.3 kg` fixtures.
Contact gating and the legacy instantaneous lateral gain remain disabled. The
ordered candidate grid is fixed to:

```text
candidate  cross_track_heading_gain_rad_per_m  yaw_error_stride_gain_per_rad
S1-A       0.5                                  0.5
S1-B       0.5                                  1.0
S1-C       1.0                                  0.5
S1-D       1.0                                  1.0
```

One fresh immutable-snapshot process is run per candidate and selection mass.
A candidate is eligible only if both masses pass every unchanged walking gate.
The first eligible candidate in the declared order wins. If none is eligible,
S1 selects no controller; no within-campaign coefficient, update interval,
bound, sign, or formula change is allowed.

Because the TC2 masses have now been observed, they cannot serve as S1 held-out
evidence. Before any S1 result, the replacement held-out masses are fixed to:

```text
3.05 kg
3.15 kg
3.25 kg
```

If S1 selects a controller, its full configuration digest is locked and run
three times per held-out mass. The validation gate is again all `9/9` runs,
with one controller digest across all masses and repetitions. The selection
cells remain development data and do not count toward validation.

#### G1-S1 selection result

The S1 opt-in boundary first preserved the established controller exactly:

```text
source_commit=b948377cdd4830ec50b7feb79a65f4c9ca4aec23
<evidence-root>\temp-roots-2026-07-28\sporespore_s1_nominal_regression_b948377\
  20260726T010533324\report.json
sha256:9d3a4eab503eb7953dc21d305fbe77221321accf6eac80b3a0d0973290272030
3/3 runs
57/57 assertions
0 engine errors
```

All eight committed S1 selection cells then completed from clean immutable
source. Each candidate report passed both harnesses, `32/32` assertions, and
recorded zero engine errors:

```text
candidate  3.0 kg  3.3 kg  eligible  report sha256
S1-A       false   true    false     b2ecdb5aa429d3e35b89f2058e67e8ed7bddb9be26fc36b7a3e838a79c8640ac
S1-B       true    false   false     0bc1cc94aa56483674015f079aed829cb0fcd64820aa1b965d6ce768722ca861
S1-C       false   false   false     9401ce1a52c2ae7257d80dd054886cbee1cb959c5493ef96abcc6020c8a4842c
S1-D       false   true    false     8890a0778c04f77a4728197649c9ef62e50a01ef063340a884d89a46c9e285c3
```

The reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s1_a_b948377\20260726T010639828\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s1_b_b948377\20260726T010737146\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s1_c_b948377\20260726T010836208\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s1_d_b948377\20260726T010933612\report.json
```

S1 therefore selects no controller. Its phase-bounded path loop materially
reduced yaw and cross-track error, but accepted front-leg contact cycles still
changed nonmonotonically by mass and coefficient pair. S1 establishes neither
a fixed controller nor bounded mass robustness.

#### Preregistered G1-S2 contact-gated path-steering selection

S2 tests whether physical contact-gated phase progression resolves the
cycle-loss failure left after S1 path tracking. Before any S2 physics result,
it combines each exact S1 path candidate with the already-declared TM1 contact
gate:

```text
contact_gated_phase_progression=true
maximum_contact_gate_hold_ticks=96
maximum_contact_gated_phase_skew_ticks=12
lateral_stride_steering_gain_per_m=0.0
steering_update_interval_ticks=90
maximum_desired_heading_error_rad=0.25
maximum_steering_fraction=0.20
```

The ordered path-gain grid remains:

```text
candidate  cross_track_heading_gain_rad_per_m  yaw_error_stride_gain_per_rad
S2-A       0.5                                  0.5
S2-B       0.5                                  1.0
S2-C       1.0                                  0.5
S2-D       1.0                                  1.0
```

Selection again uses one fresh immutable-snapshot process at `3.0` and
`3.3 kg`. The first candidate for which both masses satisfy every unchanged
walking gate wins; if none is eligible, S2 selects no controller. No contact
hold, phase skew, path coefficient, update interval, steering bound, motor,
timing, fixture, solver, or walking-threshold value may change after observing
an S2 cell.

The still-unobserved `3.05`, `3.15`, and `3.25 kg` fixtures remain the held-out
validation set. If S2 selects a controller, its full configuration digest is
locked for three fresh runs per held-out mass. The validation gate remains all
`9/9`; selection cells never count as validation evidence.

#### G1-S2 selection result and held-out lock

The first two candidates completed from clean immutable source
`bc0baf15a65e9bb39273374b3c4da29ea500d371`:

```text
candidate  3.0 kg  3.3 kg  eligible  report sha256
S2-A       false   true    false     405320aa5650732c957253dcff3026eb29b44986fbdee03dc6aec95c3bcf3aa0
S2-B       true    true    true      d2d54e129fdfa6f8752de10243b8c3fc490144e076f79a3ec3fc6dc6dd6e96c8
```

The reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s2_a_clean_bc0baf1\20260726T011741661\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s2_b_clean_bc0baf1\20260726T011844262\report.json
```

S2-B is the first eligible candidate, so S2-C and S2-D are not executed.
S2-B uses one controller digest at both selection masses:

```text
sha256:7478184503ca25fe591675afdee7366615e885763ecb0ed0e57e0bf82a3445cc
```

Both bodies completed three accepted cycles per limb. The `3.0 kg` fixture
advanced `0.972312 m`; the `3.3 kg` fixture advanced `1.082787 m`. Both
satisfied every unchanged walking gate with no root-body locomotor command.
These are selection results, not held-out generalization evidence.

The held-out runner is now locked to `S2B`, the masses `3.05`, `3.15`, and
`3.25 kg`, and repetitions `1`, `2`, and `3`. Each repetition must preserve the
selected controller digest above, pass `48/48` harness assertions, and contain
zero engine errors. The all-`9/9` walking gate remains unchanged.

#### G1-S2-B held-out validation result

All three clean immutable-source held-out repetitions passed at source
`7e3e80b3be32876401e36109b609cb33bf848977`:

```text
repetition  report sha256
1           b3aef4941fbfef2ed5c9c10a42382571449029946d8c85aeb154203b4384bdaa
2           49296dc7505f3e78cc52e72a46b61280ba63fb0c03bb83ec928df7d1d9fd8a36
3           7900891f230a9d8566138d433c5599144536603fe47167fcf01ceaf8f9af7321
```

The reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s2b_heldout_r1_7e3e80b\20260726T012125973\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s2b_heldout_r2_7e3e80b\20260726T012308599\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_s2b_heldout_r3_7e3e80b\20260726T012447398\report.json
```

The combined result is:

```text
9/9 private held-out processes
144/144 harness assertions
0 engine errors
scoped_source_tree_dirty=false
immutable_source_snapshot=true
controller_sha256=sha256:7478184503ca25fe591675afdee7366615e885763ecb0ed0e57e0bf82a3445cc
```

Every run at `3.05`, `3.15`, and `3.25 kg` satisfied every unchanged physical
walking gate. Each fixture had one stable digest, all runs used the same
controller digest, and every limb completed at least three accepted contact
cycles. Final forward displacement was `1.086236`, `1.131447`, and `1.085804 m`
respectively.

This passes the preregistered bounded torso-mass robustness gate for one exact
quadruped geometry and the locked S2-B controller. Together with the selection
fixtures, the same controller walks five distinct torso masses from `3.0` to
`3.3 kg`. This is the first bounded reusable physical quadruped walking system
in this program. It does not complete the upper-leg mass, distal mass,
friction, geometry, or generated-family axes, and it does not establish
arbitrary-morphology locomotion.

#### Post-S2-B complete BR14A regression

The complete ordinary-solver BR14A family was rerun from the clean committed
post-validation tree while both local `HEAD` and `origin/main` remained at:

```text
4f6d5e1d4cb12a6d1a3400cf389f35afd0664a77
```

The machine-readable report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_family_post_s2b_4f6d5e1\
  reports\20260726T012806508\report.json
sha256:4928a56308714fa12824a8aba9efca47539b0afc95421b38c0b5693d9fec2a9e
26/26 programs
441/441 assertions
```

The report records zero failed programs, assertion failures, timeouts, killed
process trees, open containment trees, nonzero exits, missing exit markers,
invalid process time windows, process-start or termination errors, missing or
duplicate test footers, engine errors, unexpected engine errors, missing
expected error codes, unknown expected error codes, and missing or unreadable
engine or transcript logs. The runner's stderr log is empty.

This is the latest complete-family regression. Earlier `24/24` and `25/25`
reports remain immutable evidence for their respective development stages;
they are not the current family count.

#### Preregistered G1-UM1 symmetric upper-leg-mass campaign

G1-UM1 varies the four limbs' `upper_mass_kg` values together while preserving
the exact reference torso, distal bodies, geometry, contact material, motor
limits, gait timing, solver, and walking thresholds. Varying all four values
symmetrically tests limb inertia without introducing a front/rear or left/right
center-of-mass offset.

The exploratory grid is fixed before any G1-UM1 physics result:

```text
0.200 kg  reference -20%
0.225 kg  reference -10%
0.250 kg  reference
0.275 kg  reference +10%
0.300 kg  reference +20%
```

Every cell uses the already-locked S2-B controller without retuning:

```text
controller_sha256=sha256:7478184503ca25fe591675afdee7366615e885763ecb0ed0e57e0bf82a3445cc
contact_gated_phase_progression=true
maximum_contact_gate_hold_ticks=96
maximum_contact_gated_phase_skew_ticks=12
lateral_stride_steering_gain_per_m=0.0
cross_track_heading_gain_rad_per_m=0.5
yaw_error_stride_gain_per_rad=1.0
steering_update_interval_ticks=90
maximum_desired_heading_error_rad=0.25
maximum_steering_fraction=0.20
```

Before the exploratory scan, the untouched held-out values are fixed to
`0.2125`, `0.2625`, and `0.2875 kg`. If all five exploratory fixtures walk,
the same controller is run three times per held-out value. The validation gate
requires all `9/9` fresh private worlds, `144/144` harness assertions, three
stable mass-specific fixture digests, one controller digest across every run,
and zero engine errors, timeouts, killed trees, open containment trees, or
nonzero exits.

Any exploratory or held-out walking failure remains evidence and defeats the
corresponding all-cells gate. No upper mass, controller, motor, timing, solver,
or threshold value may be changed after observing a G1-UM1 result and still
count in this campaign. A pass would establish a second bounded mass axis for
one geometry; it would not complete distal-mass, friction, geometry, or
generated-family validation.

#### G1-UM1 native-controller exploratory result

The clean immutable-source exploratory campaign ran from:

```text
source_commit=4f757cdc60d2b1c8796859852e3d9b29cd42e8fa
scoped_source_tree_dirty=false
immutable_source_snapshot=true
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um1_clean_4f757cd\20260726T022616751\report.json
sha256:858f137bc51084a64c3524cef04ae3586014dc43c6617ccae0dd8e6fc1cd2a8e
80/80 harness assertions
0 engine errors
```

An independent fresh campaign from the same committed immutable source
produced byte-for-byte identical physical result receipts in all five cells:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um1_exploratory_4f757cd\
  20260726T022541995\report.json
sha256:e38b8aff5893d6d3356014770d1f3ad30980788f1fbc92f78259c43132e821e0
80/80 harness assertions
0 engine errors
```

The two reports have different campaign timestamps and log paths, but match on
every fixture digest, controller digest, walking outcome, contact-cycle count,
displacement, drift, tilt, anchor and hinge error, and named walking gate.

All five cells used the locked S2-B controller digest and completed without
timeout, process-tree kill, open containment tree, nonzero exit, or harness
failure. The physical walking outcomes were:

```text
upper mass  walked  evidence forward  final forward  final lateral  max anchor  failed gate
0.200 kg    no       0.782057 m        1.020703 m     +0.127683 m    0.019144 m  lateral drift
0.225 kg    yes      0.751902 m        0.938692 m     -0.012727 m    0.021284 m  none
0.250 kg    yes      0.823574 m        0.972312 m     -0.020931 m    0.022453 m  none
0.275 kg    no       0.881473 m        1.058586 m     +0.033469 m    0.025171 m  anchor error
0.300 kg    no       0.871712 m        1.070774 m     -0.085838 m    0.026114 m  anchor error
```

Every limb still completed at least three accepted contact cycles in every
cell, every cell retained terminal four-contact recovery, and all five exceeded
the unchanged forward-translation gates. The light endpoint failed only the
bounded-lateral-drift gate. The two heavy endpoints failed only the
`0.025 m` maximum-anchor-error gate.

This is a reproducible native-controller transfer boundary, not a G1-UM1 pass.
The preregistered all-five exploratory gate is false, so the private
`0.2125`, `0.2625`, and `0.2875 kg` heldouts remain untouched and no heldout
repetitions are run. The result does not weaken the already-validated torso-mass
walking range, but it demonstrates that the exact fixed S2-B actuator/controller
configuration is not reusable across the full declared upper-leg-mass range.
Any mass-scaled actuator policy must be preregistered and evaluated as a
separate evidence family.

#### Preregistered G1-UM2 mass-adaptive actuator campaign

UM2 is a separate controller-policy family. It does not revise or rescue UM1.
The five UM1 exploratory masses remain the selection fixtures, and every
fixture field, solver value, gait target, timing value, path-steering value,
contact-gating value, and walking threshold remains unchanged.

The adaptive input is the normalized mass of one driven limb chain:

```text
reference upper mass = 0.25 kg
fixed distal mass    = 0.18 kg
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
actuator_impulse_scale = clamp(mass_ratio ^ exponent, 0.80, 1.25)
realized_hip_max_impulse = 0.055 * actuator_impulse_scale
realized_knee_max_impulse = 0.045 * 10.0 * actuator_impulse_scale
```

The scale changes only the controller's realized hip and knee motor-impulse
ceilings. The normalized fixture's base motor fields remain unchanged. Motor
target velocities, motor-direction sign, joint limits, and all other S2-B
controller values remain fixed.

The ordered policy grid is fixed before UM2 physics:

```text
candidate  exponent
UM2-A      0.5
UM2-B      1.0
UM2-C      1.5
```

Each candidate runs the symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` upper-mass fixtures in fresh private worlds. The first candidate
that satisfies every unchanged walking gate in all `5/5` cells wins. Later
candidates are not executed after a winner; if none is eligible, UM2 selects no
policy.

Each cell must record the normalized fixture and digest, mass ratio, exponent,
derived impulse scale, realized hip and knee impulse ceilings, complete
controller configuration and digest, one candidate-policy digest, every
walking gate, source snapshot, process containment, and engine log. Applied
scales must be finite, inside `[0.80, 1.25]`, and exactly derived from the
committed formula. The candidate-policy digest must remain constant across its
five cells; controller-configuration digests may vary only because the derived
scale varies.

The untouched `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the UM2
held-out set. A selected policy is locked for three fresh repetitions per
held-out mass. Validation requires all `9/9` worlds, `144/144` harness
assertions, one policy digest, three stable fixture digests, the exact derived
scale for every mass, and zero engine errors, timeouts, killed process trees,
open containment trees, or nonzero exits.

No exponent, clamp, affected joint set, base impulse, controller value,
threshold, selection rule, or held-out value may change after a UM2 cell is
observed and remain part of this campaign. A passing UM2 validation would
establish one bounded mass-adaptive upper-leg interval for this exact geometry.
It would not complete distal-mass, friction, geometry, generated-family, or
arbitrary-morphology walking.

#### G1-UM2 selection result

All three ordered candidates completed from clean immutable source
`cee3db978a595cb64db04bba02bc5d0647f426cb`:

```text
candidate  exponent  passing masses              failing masses  eligible
UM2-A      0.5       0.200,0.225,0.250,0.275 kg  0.300 kg        false
UM2-B      1.0       0.200,0.225,0.250 kg        0.275,0.300 kg  false
UM2-C      1.5       0.200,0.225,0.250 kg        0.275,0.300 kg  false
```

The reports are:

```text
UM2-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um2a_clean_cee3db9\20260726T024845963\report.json
sha256:12e137fb993f6216fc7668c335216ac12231384e5131bfd6ba0c1e88ad5bbfb4
policy_sha256=sha256:c3d4cb3e58c0fb3a37915dea67c54acaf7389f7bb7c9071875ff42a59ac5656b

UM2-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um2b_clean_cee3db9\20260726T025108480\report.json
sha256:40422701a15e851ed39aa237f556d27ebdaa2a646ba2a3e544540826391731db
policy_sha256=sha256:6d3f8c453a7ae8122097e45a5be8aafcb2054d35140efa9fdf98f3712fa0fa0d

UM2-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um2c_clean_cee3db9\20260726T025341486\report.json
sha256:f0a68034e53aedb74a37bb33de7fa3aecef3e9a3cfe04205ac3315624e7ef625
policy_sha256=sha256:7736625cbdd3a2755e8fbc80cf1841f343ac53acc745f7bbdd0c612499fbcd78
```

The combined selection record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, or nonzero exits. Every cell independently matched its
preregistered mass ratio, exponent, derived impulse scale, and realized hip and
knee impulse ceilings. Every candidate retained five distinct fixture digests
and one stable candidate-policy digest.

UM2-A repaired the light-end lateral failure and the `0.275 kg` anchor failure,
but `0.300 kg` still reached `0.026473 m` knee-anchor error. UM2-B caused
`0.275 kg` to fail lateral drift and left `0.300 kg` above the anchor bound.
UM2-C left both heavy cells failing; `0.300 kg` failed both lateral drift and
anchor error. The maximum-anchor witness in every failed heavy cell was a knee
joint.

No candidate satisfies the all-five selection rule, so UM2 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM2 validation repetition is run. The result shows that scaling both hip and
knee impulse ceilings from total driven-chain mass is over-broad when only the
upper-leg mass changes; it does not invalidate the narrower UM1 walking points
or the validated torso-mass interval.

#### Preregistered G1-UM3 joint-specific actuator campaign

UM3 is a new policy family motivated by the sealed UM2 joint receipts. It does
not reinterpret or rescue UM1 or UM2. The upper-leg mass changes the inertia
driven by the hip, while the knee's distal body remains fixed at `0.18 kg`.
Accordingly, UM3 scales hip authority from driven-chain mass and leaves knee
authority exactly at the S2-B reference value:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
hip_impulse_scale = clamp(mass_ratio ^ exponent, 0.80, 1.25)
knee_impulse_scale = 1.0
realized_hip_max_impulse = 0.055 * hip_impulse_scale
realized_knee_max_impulse = 0.045 * 10.0
```

The ordered exponent grid remains deliberately small:

```text
candidate  hip exponent  knee exponent
UM3-A      0.5           0.0
UM3-B      1.0           0.0
UM3-C      1.5           0.0
```

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM3 selects no
policy.

The normalized fixture, solver, S2-B phase/path controller, target velocities,
timing, contact gating, joint limits, walking thresholds, clamp, and base motor
fields remain unchanged. Each cell must independently record and verify its
mass ratio, hip scale, fixed knee scale, realized hip and knee impulse ceilings,
fixture and controller digests, candidate-policy digest, maximum-anchor joint
and tick, process containment, and engine log. One policy digest must remain
constant across a candidate; controller digests may vary only with the derived
hip scale.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
held-out set. If UM3 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with exact formula receipts and zero engine errors,
timeouts, killed process trees, open containment trees, or nonzero exits.

No exponent, affected joint set, scale, clamp, base impulse, threshold,
selection rule, or held-out value may change after a UM3 result is observed and
remain part of this campaign. A passing validation would establish bounded
joint-specific upper-mass adaptation for this geometry, not complete G1 or
morphology-general walking.

#### G1-UM3 selection result

All three ordered candidates completed from clean immutable source
`9ab651c9d241ffd55cd761c8195fc071482f2413`:

```text
candidate  hip exponent  passing masses        failing masses        eligible
UM3-A      0.5           0.225,0.250,0.275 kg  0.200,0.300 kg       false
UM3-B      1.0           0.200,0.225,0.250 kg  0.275,0.300 kg       false
UM3-C      1.5           0.200,0.225,0.250 kg  0.275,0.300 kg       false
```

The reports are:

```text
UM3-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um3a_clean_9ab651c\20260726T031332757\report.json
sha256:a1cbe040ae5e46a7716de62b1ccc6a79ccd58bafc8abcb7df94b0aab20c24c71
policy_sha256=sha256:ec0515a638b26bc643c6193288c0aefda55744d44d8fd12192814c44814e8aae

UM3-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um3b_clean_9ab651c\20260726T031601349\report.json
sha256:658a377a9dc06c025850e9af8f1370c4e99a78eb20a5ad9d67cb49bdfc4dce41
policy_sha256=sha256:1555ad7b59c06d15b5077aabe997c900ec2a45cfbaa1a5565eeacbb6efd82181

UM3-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um3c_clean_9ab651c\20260726T031814604\report.json
sha256:225a7f18fae5a269a7517945a048a56258fbae381786c9120cb831d9f36b5625
policy_sha256=sha256:f4431c545a0d92b45b7095a5c87d790f6d2f131c30ae41dbd954ea792a85afa5
```

The combined selection record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, nonzero exits, or source-snapshot violations. Every cell
matched its preregistered mass ratio, hip exponent and scale, fixed knee scale,
and realized impulse ceilings. Each candidate retained five distinct fixture
digests and one stable policy digest.

UM3-A retained the best heavy-end behavior: `0.275 kg` walked with
`0.024547 m` maximum anchor error, while `0.300 kg` failed only the anchor gate
at `0.026822 m`. It did not repair the light endpoint, whose final lateral
drift remained `0.109017 m`. UM3-B and UM3-C repaired the light endpoint by
reducing hip authority more strongly, but both failed the two heavy endpoints.
UM3-B missed the `0.275 kg` anchor bound by only `0.000054 m`; UM3-C reached
`0.025914 m`. At `0.300 kg`, increasing the hip exponent monotonically
increased maximum knee-anchor error from `0.026822` through `0.027099` to
`0.027768 m`.

No candidate satisfies the all-five selection rule, so UM3 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM3 validation repetition is run. The sealed UM2 and UM3 results together
show that the remaining transfer defect is not repaired by monotonically
increasing knee authority with driven-chain mass or by holding knee authority
fixed while increasing hip authority more aggressively.

#### Preregistered G1-UM4 bidirectional knee-attenuation campaign

UM4 tests the next narrow causal hypothesis; it does not reinterpret or rescue
UM1, UM2, or UM3. UM3-A provides the best heavy-end hip law. At the light
endpoint, UM2-A walked when both hip and knee scales were `0.940064`, whereas
UM3-A failed lateral drift when the hip used that same scale but the knee
remained at `1.0`. At the heavy endpoints, every failed UM2/UM3 maximum-anchor
witness was a knee joint, and increasing rather than reducing knee authority
did not repair it.

UM4 therefore locks the hip exponent to `0.5` and symmetrically attenuates knee
authority as upper-leg mass moves away from the reference:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
hip_impulse_scale = clamp(mass_ratio ^ 0.5, 0.80, 1.25)
knee_attenuation_ratio = min(mass_ratio, 1.0 / mass_ratio)
knee_impulse_scale = clamp(knee_attenuation_ratio ^ knee_exponent, 0.80, 1.0)
realized_hip_max_impulse = 0.055 * hip_impulse_scale
realized_knee_max_impulse = 0.045 * 10.0 * knee_impulse_scale
```

The ordered knee-exponent grid is fixed before UM4 physics:

```text
candidate  hip exponent  knee exponent
UM4-A      0.5           0.5
UM4-B      0.5           1.0
UM4-C      0.5           1.5
```

UM4-A exactly reproduces UM2-A's known hip and knee scales below the reference
mass, but reverses only the knee scale above the reference. The later
candidates test stronger knee attenuation without changing the locked hip law.
This distinguishes the knee-direction hypothesis from a general increase in
motor authority.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM4 selects no
policy.

The normalized fixture, solver, S2-B phase/path controller, target velocities,
timing, contact gating, joint limits, walking thresholds, clamps, and base
motor fields remain unchanged. Each cell must independently record and verify
the mass ratio, fixed hip exponent, knee attenuation ratio and exponent,
derived hip and knee scales, realized impulse ceilings, fixture and controller
digests, candidate-policy digest, maximum-anchor joint and tick, process
containment, and engine log. One policy digest must remain constant across a
candidate; controller digests may vary only with the derived scales.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM4 held-out set. If UM4 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with exact formula receipts and zero engine errors,
timeouts, killed process trees, open containment trees, or nonzero exits.

No exponent, affected joint set, formula, scale, clamp, base impulse, threshold,
selection rule, or held-out value may change after a UM4 result is observed and
remain part of this campaign. A passing validation would establish bounded
joint-specific upper-mass adaptation for this geometry, not complete G1 or
morphology-general walking.

#### G1-UM4 selection result

All three ordered candidates completed from clean immutable source
`f336263e5cfc06ccd19031ea6a848758b209574c`:

```text
candidate  knee exponent  passing masses              failing masses
UM4-A      0.5            0.200,0.225,0.250,0.275 kg  0.300 kg
UM4-B      1.0            0.200,0.225,0.250,0.275 kg  0.300 kg
UM4-C      1.5            0.225,0.250,0.275 kg        0.200,0.300 kg
```

The counted reports are:

```text
UM4-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um4a_clean_f336263\20260726T033148103\report.json
sha256:f3380dec8fa0b09266ddd1c99edbf00779b5af1d45c25f7a4d5da4e66a3a153b
policy_sha256=sha256:e099235883cd7e0178c22ea8052de6dd833a10c1de5675d23f55bb1b5f4de99f

UM4-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um4b_clean_f336263\20260726T033359219\report.json
sha256:d4eb32205144adf91ff72535c449290e7df351a01314c3d3c5f50cc8480eb9e3
policy_sha256=sha256:267999c329c62a21c39742256eb9a07a344fd6a7038b8dec730ee9b9d72762db

UM4-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um4c_selection_3353955\20260726T033428162\report.json
sha256:f857a2bbeade7c598eab67af16e1eb4f41206832d05df12988fb6c08aa7284c9
policy_sha256=sha256:b75d872ca5deae6f398c2bcd2f598b67615c8f725b09368bf8618a9bb2bc71b1
```

The UM4-C log-root label predates the receipt-hardening commit, but its report
independently records clean immutable source `f336263`. The earlier uncounted
UM4-A report under
`<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um4a_selection_3353955` correctly records a dirty scoped
source tree because its snapshot overlapped that hardening edit. It is excluded
from selection evidence.

The combined counted record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, nonzero exits, or source-snapshot violations. Every cell
matched its preregistered mass ratio, hip exponent and scale, knee attenuation
ratio and exponent, knee scale, realized impulse ceilings, and policy digest.

UM4-A and UM4-B repaired the light endpoint and retained walking through
`0.275 kg`, but `0.300 kg` failed only the knee-anchor gate at `0.026715228`
and `0.027015213 m`. UM4-C attenuated knee authority more strongly; its
`0.200 kg` cell then failed the contact-cycle gate because rear-left completed
only one cycle, while `0.300 kg` still failed the knee-anchor gate at
`0.026834706 m`. All three heavy endpoints nevertheless advanced approximately
one meter and remained within the lateral, yaw, tilt, torso-height, torso-contact,
terminal-contact, and hinge-axis bounds.

No candidate satisfies the all-five selection rule, so UM4 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM4 held-out validation is run. The sealed result rejects monotonic knee
impulse-ceiling attenuation by itself as the missing heavy-end correction. It
does not reject heavy-side hip attenuation: every UM2-UM4 heavy policy retained
or amplified hip authority, and no observed policy reduced it below the
reference ceiling. This remains development evidence for one geometry, not
complete G1 or morphology-general walking.

#### Preregistered G1-UM5 bidirectional dual-attenuation campaign

UM5 tests the remaining authority-scaling direction before changing gait
trajectory or timing. It does not reinterpret or rescue UM1-UM4. At `0.300 kg`,
native S2-B with reference hip and knee authority produced `0.026114 m`
maximum knee-anchor error. Holding the knee fixed while increasing hip
authority produced `0.026822`, `0.027099`, and `0.027768 m` in UM3-A through
UM3-C. UM4 varied only knee attenuation while retaining UM3-A's amplified
heavy-side hip law; its best heavy result remained `0.026715 m`.

UM5 locks the knee attenuation exponent to UM4-A's best value, `0.5`, and
applies the same bidirectional attenuation ratio to the hip with a small
ordered exponent grid:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
attenuation_ratio = min(mass_ratio, 1.0 / mass_ratio)
hip_impulse_scale = clamp(attenuation_ratio ^ hip_exponent, 0.80, 1.0)
knee_impulse_scale = clamp(attenuation_ratio ^ 0.5, 0.80, 1.0)
realized_hip_max_impulse = 0.055 * hip_impulse_scale
realized_knee_max_impulse = 0.045 * 10.0 * knee_impulse_scale
```

The ordered hip-exponent grid is fixed before UM5 physics:

```text
candidate  hip exponent  knee exponent
UM5-A      0.5           0.5
UM5-B      1.0           0.5
UM5-C      1.5           0.5
```

Below the reference mass, UM5-A exactly reproduces UM4-A's already observed
hip and knee scales. Above the reference, it changes only the hip scale's
direction from amplification to attenuation. Later candidates test stronger
hip attenuation while preserving the same knee law. This isolates the untested
hip-direction hypothesis from any gait-target or timing change.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM5 selects no
policy.

The normalized fixture, solver, S2-B phase/path controller, target velocities,
timing, contact gating, joint limits, walking thresholds, clamps, and base
motor fields remain unchanged. Each cell must independently record and verify
the mass ratio, attenuation ratio, hip and knee exponents, derived scales,
realized impulse ceilings, fixture and controller digests, candidate-policy
digest, maximum-anchor joint and tick, process containment, and engine log. One
policy digest must remain constant across a candidate; controller digests may
vary only with the derived scales.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM5 held-out set. If UM5 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with exact formula receipts and zero engine errors,
timeouts, killed process trees, open containment trees, or nonzero exits.

No exponent, affected joint set, formula, scale, clamp, base impulse, threshold,
selection rule, or held-out value may change after a UM5 result is observed and
remain part of this campaign. A passing validation would establish bounded
joint-specific upper-mass adaptation for this geometry, not complete G1 or
morphology-general walking.

#### G1-UM5 selection result

All three ordered candidates completed from clean immutable source
`80273d2bc3c7993e6b2d6d19794b9b3ec2dac345`:

```text
candidate  hip exponent  passing masses              failing masses
UM5-A      0.5           0.200,0.225,0.250,0.275 kg  0.300 kg
UM5-B      1.0           0.200,0.225,0.250,0.275 kg  0.300 kg
UM5-C      1.5           0.200,0.225,0.250,0.275 kg  0.300 kg
```

The counted reports are:

```text
UM5-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um5a_clean_80273d2\20260726T034803729\report.json
sha256:ea3775240002408652661f57cb046c5421323a77e6455c6f3c01f68963cfb845
policy_sha256=sha256:0d7f575e0c287228e964ae302a0b4f256dbe4307f86b7f263286780e01b451df

UM5-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um5b_selection_7e925fa\20260726T034850667\report.json
sha256:c153538e5ece40de1f44287069fb382dfd55fc3c60297981a5b8b10ff1dc4af1
policy_sha256=sha256:7f9567282492ea645e8af59c1da273edb1798cc7b85c05af03d2364b96dbfb7e

UM5-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um5c_selection_7e925fa\20260726T035102807\report.json
sha256:0f66cc962fd639d55aa7b2d455cbc3099fa372ff4176c72e298f17f30c4c09bd
policy_sha256=sha256:f5991a70c1ab2956f9836c3c9b57d4667ac064964fc4c3ae51987e6db86e2228
```

The UM5-B and UM5-C log-root labels predate the receipt-hardening commit, but
their reports independently record clean immutable source `80273d2`. The
earlier UM5-A report under `<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um5a_selection_7e925fa`
records a dirty scoped source tree because its snapshot overlapped that
hardening edit. It is excluded and replaced by the clean UM5-A rerun above.

The combined counted record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, nonzero exits, or source-snapshot violations. Every cell
matched the preregistered mass and attenuation ratios, hip and knee exponents,
derived scales, realized impulse ceilings, and policy digest.

Increasing bidirectional hip attenuation improved the `0.300 kg` knee-anchor
witness monotonically from `0.026443364 m` in UM5-A to `0.025777835 m` in
UM5-B and `0.025589254 m` in UM5-C, but no result crossed the unchanged
`0.025000 m` gate. UM5-C also introduced a contact-gating timeout at the heavy
endpoint. Despite these strict failures, every heavy cell completed all limb
cycles, advanced at least `1.096 m`, and remained within the lateral, yaw,
tilt, torso-height, torso-contact, terminal-contact, and hinge-axis bounds.

No candidate satisfies the all-five selection rule, so UM5 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM5 held-out validation is run. UM2 through UM5 now exhaust the
preregistered monotonic hip/knee impulse-authority directions: common scaling,
hip-only amplification, knee attenuation with hip amplification, and dual
attenuation. The remaining heavy-end defect improved but plateaued while timing
began to fail, so the next development axis must change knee trajectory or gait
timing rather than continue authority scaling. This remains development
evidence for one geometry, not complete G1 or morphology-general walking.

#### Preregistered G1-UM6 heavy-side knee-trajectory campaign

UM6 changes trajectory amplitude rather than motor authority. It does not
reinterpret or rescue UM1-UM5. UM5-B is the actuator base because it walked the
four lighter selection cells, kept every contact gate within its timeout, and
left the `0.300 kg` cell only `0.000778 m` above the anchor bound. Its actuator
law remains exact:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
attenuation_ratio = min(mass_ratio, 1.0 / mass_ratio)
hip_impulse_scale = clamp(attenuation_ratio ^ 1.0, 0.80, 1.0)
knee_impulse_scale = clamp(attenuation_ratio ^ 0.5, 0.80, 1.0)
```

The reference knee trajectory requests
`0.82 * 1.75 = 1.435 rad` peak sinusoidal flexion before the unchanged
contact-clearance assist, while the normalized knee upper limit is `1.10 rad`.
UM6 leaves that trajectory untouched at and below the `0.250 kg` reference and
linearly reduces only the heavy side:

```text
heavy_fraction = clamp((upper_mass_kg - 0.250) / (0.300 - 0.250), 0.0, 1.0)
realized_knee_flexion_scale =
  lerp(1.75, heavy_endpoint_knee_flexion_scale, heavy_fraction)
```

The ordered endpoint grid is fixed before UM6 physics:

```text
candidate  hip exponent  knee exponent  heavy endpoint knee flexion scale
UM6-A      1.0           0.5            1.60
UM6-B      1.0           0.5            1.45
UM6-C      1.0           0.5            1.30
```

Thus all three candidates exactly reproduce UM5-B at `0.200`, `0.225`, and
`0.250 kg`. At `0.275 kg`, their realized knee-flexion scales are `1.675`,
`1.600`, and `1.525`; at `0.300 kg`, they are `1.600`, `1.450`, and `1.300`.
The grid spans a mild correction through a peak sinusoidal request that falls
inside the declared knee upper limit before the unchanged assist. It does not
change swing duration, contact-gate timing, clearance assist, joint limits, or
walking thresholds.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM6 selects no
policy.

The normalized fixture, solver, S2-B phase/path controller, target velocities,
swing duration, contact gating, joint limits, contact-clearance assist, walking
thresholds, clamps, and base motor fields remain unchanged. Each cell must
independently record and verify its mass and attenuation ratios, actuator
exponents and scales, heavy fraction, endpoint and realized knee-flexion
scales, realized impulse ceilings, fixture and controller digests,
candidate-policy digest, maximum-anchor joint and tick, process containment,
and engine log. One policy digest must remain constant across a candidate;
controller digests may vary only with the derived actuator and trajectory
values.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM6 held-out set. If UM6 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with exact formula receipts and zero engine errors,
timeouts, killed process trees, open containment trees, or nonzero exits.

No endpoint, exponent, affected controller field, formula, clamp, base impulse,
threshold, selection rule, or held-out value may change after a UM6 result is
observed and remain part of this campaign. A passing validation would establish
bounded upper-mass adaptation for this geometry using one combined actuator and
trajectory policy, not complete G1 or morphology-general walking.

#### G1-UM6 result: trajectory amplitude rejected

UM6 was executed from clean pushed source `47672cd` in three ordered selection
campaigns:

```text
candidate  endpoint  passing selection masses (kg)       failing mass (kg)  maximum anchor error at 0.300 kg
UM6-A      1.60      0.200, 0.225, 0.250, 0.275          0.300              0.025805870 m
UM6-B      1.45      0.200, 0.225, 0.250, 0.275          0.300              0.025834342 m
UM6-C      1.30      0.200, 0.225, 0.250, 0.275          0.300              0.025533361 m
```

Each candidate completed `80/80` assertions with all five harnesses passing,
zero engine errors, timeouts, killed process trees, open containment trees, or
nonzero exits. The source snapshot for every report was immutable and the
scoped source tree was clean. The reports are:

```text
UM6-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um6a_clean_47672cd\20260726T041159660\report.json
sha256:31547d9d7acbbc05772627d54fd3cc5ad51bc2d7e4161e12765ac70de9b8e3c5

UM6-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um6b_clean_47672cd\20260726T041404052\report.json
sha256:0af74d373eb849da637665c3560e11f2773ac0335ea994bdf705f4c145891aca

UM6-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um6c_clean_47672cd\20260726T041607278\report.json
sha256:6c9525deb7cfdc0dd85aaf4960e0208f5afd74788e4d6f7aee8935fde2817809
```

All three candidates reproduced the same four lighter walking cells. At the
heavy endpoint, reducing the realized knee-flexion scale from `1.60` to `1.30`
moved the maximum-error target from `1.632876718 rad` to `1.245714661 rad`, but
the world-space anchor error improved by only `0.000272509 m`. The heavy
maximum remained a contact-loaded knee during swing with saturated
`-3.5 rad/s` motor command. UM6-B and UM6-C moved that witness to local phase
tick `51`, three ticks before the unchanged release gate at tick `54`.

No candidate satisfies the all-five selection rule, so UM6 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM6 held-out validation is run. UM6-C is the smallest observed heavy-end
anchor error, but it is still a failed development candidate and is not
promoted. The weak error response to a large amplitude change rejects further
one-dimensional knee-amplitude reduction as the next experiment.

#### Preregistered G1-UM7 heavy-side swing-gate timing campaign

UM7 tests whether the remaining heavy-end defect is caused by the controller
continuing contact-loaded swing before its release gate. It does not
reinterpret or rescue UM6. The fixed actuator law is UM5-B, and the fixed
heavy-side knee-amplitude law is UM6-C because it produced the smallest
observed `0.300 kg` anchor error:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
attenuation_ratio = min(mass_ratio, 1.0 / mass_ratio)
hip_impulse_scale = clamp(attenuation_ratio ^ 1.0, 0.80, 1.0)
knee_impulse_scale = clamp(attenuation_ratio ^ 0.5, 0.80, 1.0)
heavy_fraction = clamp((upper_mass_kg - 0.250) / (0.300 - 0.250), 0.0, 1.0)
realized_knee_flexion_scale = lerp(1.75, 1.30, heavy_fraction)
```

Adopting that failed candidate as a fixed input to a new combined campaign is
not selection or promotion. UM7 changes only the heavy-side swing duration and
its derived contact-gate ticks:

```text
realized_swing_ticks =
  round(lerp(72, heavy_endpoint_swing_ticks, heavy_fraction))
release_gate_tick = floor(realized_swing_ticks * 3 / 4)
recontact_gate_tick =
  realized_swing_ticks + floor((360 - realized_swing_ticks) / 4)
```

The ordered endpoint grid is fixed before UM7 physics:

```text
candidate  heavy endpoint swing ticks  endpoint release gate  endpoint recontact gate
UM7-A      68                          51                     141
UM7-B      64                          48                     138
UM7-C      60                          45                     135
```

The current `72`-tick swing releases at local phase tick `54`; the clean UM6
heavy failures peaked at ticks `44` or `51` while the foot still bore the
floor. UM7-A gates exactly at the repeated tick-`51` witness, while UM7-B and
UM7-C bracket it with progressively earlier release gates. At `0.275 kg`, the
realized swing durations are `70`, `68`, and `66` ticks. At the held-out
fractions, every interpolation is also integral: `0.2625 kg` realizes `71`,
`70`, and `69`; `0.2875 kg` realizes `69`, `66`, and `63`. No ambiguous
rounding is therefore exercised by the declared evidence grid.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM7 selects no
policy.

The normalized fixture, solver, S2-B phase/path controller, target velocities,
contact-gate hold/skew limits, joint limits, contact-clearance assist,
walking thresholds, clamps, base motor fields, actuator policy, and
heavy-side knee-amplitude law remain unchanged. Each cell must independently
record and verify its mass and attenuation ratios, actuator exponents and
scales, heavy fraction, endpoint and realized knee-flexion scales, endpoint
and realized swing ticks, derived release and recontact ticks, realized
impulse ceilings, fixture and controller digests, candidate-policy digest,
maximum-anchor witness, process containment, and engine log.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM7 held-out set. If UM7 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with exact formula receipts and zero engine errors,
timeouts, killed process trees, open containment trees, or nonzero exits.

No timing endpoint, formula, rounding rule, actuator or trajectory input,
threshold, selection rule, or held-out value may change after a UM7 result is
observed and remain part of this campaign. A passing validation would
establish bounded upper-mass adaptation for this geometry using one combined
actuator, trajectory, and timing policy, not complete G1 or
morphology-general walking.

#### G1-UM7 selection result

All three ordered candidates completed from clean immutable source
`1fe4195d1bdee51888497e27d7078dc12670c58c`:

```text
candidate  endpoint swing  passing masses              failing masses
UM7-A      68 ticks        0.200,0.225,0.250,0.275 kg  0.300 kg
UM7-B      64 ticks        0.200,0.225,0.250,0.275 kg  0.300 kg
UM7-C      60 ticks        0.200,0.225,0.250,0.275 kg  0.300 kg
```

The counted reports are:

```text
UM7-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um7a_clean_1fe4195\20260726T042953575\report.json
sha256:a047c7561c34c7795811de89873b668ed80a9c6da0203de21286d0f2dc8bbacf
policy_sha256=sha256:e341c5d47a7ab318b7e631d113557bc90460f3a6249d5417b0c310e1bdbec4a1

UM7-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um7b_clean_1fe4195\20260726T043212480\report.json
sha256:b477d9a07654bffb2318e83a35d2eeb04bfc2102f054e7258a060ae98f81c66b
policy_sha256=sha256:17ef730cc95fe4b5416e89365e5e30a26ae0bc5df9a2dfc945c42a1579f226b8

UM7-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um7c_clean_1fe4195\20260726T043430225\report.json
sha256:f1f447e8b36d61ed9693a6880b3fea7116ad6c9d683f0774e0acdc13f0e2714a
policy_sha256=sha256:b99e40f41950e4456c6ee1ef173c5d40444774272903c5547a99d5fe18ce331d
```

The combined counted record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, nonzero exits, or source-snapshot violations. Every cell
matched its independently derived mass and attenuation ratios, impulse scales,
heavy fraction, knee-flexion scale, rounded swing duration, release and
recontact ticks, realized impulse ceilings, and policy digest.

Every `0.300 kg` candidate advanced at least `1.113 m`, completed at least the
required two contact cycles per limb, and passed the contact-gating, forward,
lateral, yaw, tilt, torso-height, torso-contact, terminal-contact, and
hinge-axis gates. Only the unchanged `0.025000 m` anchor-error gate failed:

```text
candidate  endpoint release gate  0.300 kg maximum anchor error
UM7-A      tick 51                0.025613269 m
UM7-B      tick 48                0.025540033 m
UM7-C      tick 45                0.025502494 m
```

The UM7-C maximum remained a knee in swing while its foot bore the floor, with
the target-velocity command still saturated at `-3.5 rad/s` and measured joint
rate effectively zero. Moving the release gate across and before the repeated
tick-51 witness changed the trajectory and maximum-error tick but did not
remove the saturated loaded command.

No candidate satisfies the all-five selection rule, so UM7 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM7 held-out validation is run. This seals the declared swing-timing grid as
a negative result without weakening the existing walker or its previously
validated torso-mass interval.

#### Preregistered G1-UM8 contact-loaded swing knee-rate campaign

UM8 targets the control state common to every surviving heavy failure. It does
not reinterpret or rescue UM1-UM7. The complete UM7-C actuator, trajectory,
and timing law is fixed as the base:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
attenuation_ratio = min(mass_ratio, 1.0 / mass_ratio)
hip_impulse_scale = clamp(attenuation_ratio ^ 1.0, 0.80, 1.0)
knee_impulse_scale = clamp(attenuation_ratio ^ 0.5, 0.80, 1.0)
heavy_fraction = clamp((upper_mass_kg - 0.250) / (0.300 - 0.250), 0.0, 1.0)
knee_flexion_scale = lerp(1.75, 1.30, heavy_fraction)
swing_ticks = round(lerp(72, 60, heavy_fraction))
```

The existing `3.5 rad/s` motor target-speed clamp remains exact for every hip,
every stance command, every airborne knee, and all masses at or below
`0.250 kg`. A reduced clamp is active only when all of these predicates are
simultaneously true:

```text
joint_role == knee_pitch
local_phase_tick < realized_swing_ticks
foot_bears_floor == true
upper_mass_kg > 0.250
```

The realized contact-loaded cap is:

```text
contact_loaded_swing_knee_maximum_motor_target_speed_rad_s =
  lerp(3.5, heavy_endpoint_speed_rad_s, heavy_fraction)
```

The ordered endpoint grid is fixed before UM8 physics:

```text
candidate  0.300 kg endpoint  0.275 kg realized cap
UM8-A      2.50 rad/s         3.00 rad/s
UM8-B      1.50 rad/s         2.50 rad/s
UM8-C      0.75 rad/s         2.125 rad/s
```

The grid spans a mild reduction through a command that can plausibly fall
below the impulse-saturated regime. Once a foot releases, the knee immediately
returns to the unchanged `3.5 rad/s` clamp so airborne clearance authority is
not globally reduced. No motor impulse ceiling, position gain, rate damping,
target angle, gate tick, or walking threshold changes.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM8 selects no
policy.

The normalized fixture, solver, UM7-C path/actuator/trajectory/timing policy,
hip command clamp, non-contact-loaded knee clamp, contact-gate limits, joint
limits, clearance assist, walking thresholds, and base motor fields remain
unchanged. Each cell must independently record and verify all UM7-C receipts
plus the endpoint and realized contact-loaded cap, the exact activation
predicate and activation count, configured and maximum commanded hip/knee
speeds, fixture and controller digests, candidate-policy digest,
maximum-anchor context, process containment, and engine log.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM8 held-out set. If UM8 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with exact formula receipts and zero engine errors,
timeouts, killed process trees, open containment trees, or nonzero exits.

No speed endpoint, activation predicate, formula, clamp, base controller
field, threshold, selection rule, or held-out value may change after a UM8
result is observed and remain part of this campaign. A passing validation
would establish bounded upper-mass adaptation for this geometry using one
combined actuator, trajectory, timing, and contact-loaded rate policy, not
complete G1 or morphology-general walking.

#### G1-UM8 selection result

All three ordered candidates completed from clean immutable source
`7641f031bffb31323ed33fdbf7ee0a6e71289639`:

```text
candidate  endpoint speed  passing masses              failing masses
UM8-A      2.50 rad/s      0.200,0.225,0.250,0.275 kg  0.300 kg
UM8-B      1.50 rad/s      0.200,0.225,0.250,0.275 kg  0.300 kg
UM8-C      0.75 rad/s      0.200,0.225,0.250 kg        0.275,0.300 kg
```

The counted reports are:

```text
UM8-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um8a_clean_7641f03\20260726T045538590\report.json
sha256:0ff58be8ce0944e9bed29896cff7ed8faf355ec333732c51e79c0f42367b0848
policy_sha256=sha256:9b4212cd8368c10a1e503665f65cad5b230f050283b7b1d504f95bd5b8353bbf

UM8-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um8b_clean_7641f03\20260726T045745372\report.json
sha256:d996d719a6572f25c8df78d9f1c45d428731789d2b5a93d13ccc998219d464bf
policy_sha256=sha256:5cc9036ce29b6bf1a9180ad9a72b8b633fc5966e48305e2c017b621c1d7c2816

UM8-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um8c_clean_7641f03\20260726T045955292\report.json
sha256:0d01c68ac14f5f6eaa46ad462c2ad68443c16cde0909ac03df4a27112fe003de
policy_sha256=sha256:0faac1e632f8b25680ae3b519450ee5d6eeb5c88adcd696c4115f663446996e5
```

The combined counted record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, nonzero exits, dirty scoped source trees, or source-snapshot
violations. Every cell matched its independently derived actuator,
trajectory, timing, endpoint-speed, realized-speed, activation-count,
per-joint-role command-speed, fixture, controller, and candidate-policy
receipts.

UM8 changed the heavy failure mechanism. Every candidate brought the
`0.300 kg` maximum anchor error below the unchanged `0.025000 m` limit:

```text
candidate  realized cap  cap activations  maximum anchor error
UM8-A      2.50 rad/s    1793             0.021945653 m
UM8-B      1.50 rad/s    2304             0.022727072 m
UM8-C      0.75 rad/s    2478             0.016275344 m
```

UM8-A and UM8-B still advanced more than `1.07 m`, passed the two-cycle,
forward, structural, body-stability, and terminal-support gates, and failed
only contact-gate completion at `0.300 kg`. The front-right limb completed
only two accepted cycles under UM8-A; both right limbs completed only two
under UM8-B. UM8-C reduced the loaded knee enough to starve progression:
`0.275 kg` completed only one rear-left cycle, while `0.300 kg` completed zero
rear cycles and failed the contact-gated evidence horizon.

This is a bounded negative result, but it isolates a useful tradeoff. Limiting
the saturated, contact-loaded swing-knee command is sufficient to remove the
previous structural-anchor violation. A fixed heavy-side cap is not sufficient
to preserve timely release and recontact across the declared interval; stronger
caps progressively exchange anchor error for stalled contact progression.

No candidate satisfies the all-five selection rule, so UM8 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM8 held-out validation is run. The existing walker and its validated
torso-mass interval remain unchanged.

#### Preregistered G1-UM9 post-release loaded-knee rate campaign

UM9 tests the causal tradeoff isolated by UM8. It does not reinterpret or
rescue UM8. The complete UM8-A actuator, knee-amplitude, and swing-timing law
is fixed because it was the smallest rate intervention, preserved walking at
`0.275 kg`, and removed the `0.300 kg` structural-anchor defect:

```text
mass_ratio = (upper_mass_kg + 0.18) / (0.25 + 0.18)
attenuation_ratio = min(mass_ratio, 1.0 / mass_ratio)
hip_impulse_scale = clamp(attenuation_ratio ^ 1.0, 0.80, 1.0)
knee_impulse_scale = clamp(attenuation_ratio ^ 0.5, 0.80, 1.0)
heavy_fraction = clamp((upper_mass_kg - 0.250) / (0.300 - 0.250), 0.0, 1.0)
knee_flexion_scale = lerp(1.75, 1.30, heavy_fraction)
swing_ticks = round(lerp(72, 60, heavy_fraction))
release_gate_tick = floor(swing_ticks * 3 / 4)
contact_loaded_speed_cap_rad_s = lerp(3.5, 2.5, heavy_fraction)
```

UM8 applied that cap throughout contact-loaded swing, including the exact
release-gate phase where the controller was waiting for lift-off. UM9 preserves
the unchanged `3.5 rad/s` knee clamp through the release gate. The reduced cap
may activate only if a heavy foot is still or again loaded later in the
remaining swing:

```text
joint_role == knee_pitch
local_phase_tick >= activation_start_phase_tick
local_phase_tick < realized_swing_ticks
foot_bears_floor == true
upper_mass_kg > 0.250
```

The ordered phase-window grid is fixed before UM9 physics:

```text
candidate  start formula             0.300 kg start  0.275 kg start
UM9-A      release_gate_tick + 1     tick 46         tick 50
UM9-B      release_gate_tick + 3     tick 48         tick 52
UM9-C      release_gate_tick + 6     tick 51         tick 55
```

The grid brackets immediate post-release protection through the repeated
tick-`51` pre-UM8 anchor witness. Endpoint speed, amplitude, timing, motor
impulse, position gain, rate damping, contact-gate limits, and all walking
thresholds remain fixed. All hips, stance knees, airborne knees, knee commands
before the candidate start tick, and masses at or below `0.250 kg` retain the
unchanged `3.5 rad/s` clamp.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM9 selects no
policy.

Each cell must independently verify every UM8 receipt plus the candidate
start-offset formula, realized start tick, exact activation predicate and
activation count, maximum contact-loaded capped command, per-limb release and
recontact hold counts, gate-timeout counts, phase-synchronization holds,
evidence gait advance, accepted contact cycles, fixture/controller/policy
digests, process containment, and engine log. An intervention that merely
removes anchor error while timing out or starving contact progression does not
walk.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM9 held-out set. If UM9 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with zero engine errors, timeouts, killed process trees,
open containment trees, or nonzero exits.

No start offset, endpoint speed, activation predicate, base controller field,
threshold, selection rule, or held-out value may change after a UM9 result is
observed and remain part of this campaign. A passing validation would establish
bounded upper-mass adaptation for this one quadruped geometry, not complete G1,
arbitrary quadruped walking, or morphology-general locomotion.

#### G1-UM9 selection result

All three ordered candidates completed from clean immutable source
`5b5abc0d268e7058e222d22bedc29e20f3632063`:

```text
candidate  start offset  passing masses              failing mass
UM9-A      +1 tick       0.200,0.225,0.250,0.275 kg  0.300 kg
UM9-B      +3 ticks      0.200,0.225,0.250,0.275 kg  0.300 kg
UM9-C      +6 ticks      0.200,0.225,0.250,0.275 kg  0.300 kg
```

The counted reports are:

```text
UM9-A
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um9a_clean_5b5abc0\20260726T051548376\report.json
sha256:5283d85d630d861c55030349c405ff7d314e3ecac9d4334b1a59d54343567350
policy_sha256=sha256:7346afd7a0d75d322ebac10bb6d6a0fa63292b6f159fb1e6eccc0a6659c227b6

UM9-B
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um9b_clean_5b5abc0\20260726T051820707\report.json
sha256:53a4ded03078b8ef01e3f731f9c69af9d85289028cde7d02e6b7471472379390
policy_sha256=sha256:6fbb7a2fd9dbe7e8374893c14f6997e73433af2f5eff13ce3261f54846283f73

UM9-C
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um9c_clean_5b5abc0\20260726T052026374\report.json
sha256:9c9461de42ffd976a14a820679acafe3d189f2058a0551e84edb9ffd3358e8bb
policy_sha256=sha256:971f7c158477bacfbcceea05c2fbfa8a5e18810e3fbdb00fb433e76c7229cf89
```

The combined counted record is `15/15` private worlds and `240/240` harness
assertions with zero engine errors, timeouts, killed process trees, open
containment trees, nonzero exits, dirty scoped source trees, or source-snapshot
violations. Every cell matched its independently derived actuator, trajectory,
timing, endpoint speed, realized speed, phase-window start, activation count,
per-limb gate-hold/timeout/synchronization, evidence-advance,
fixture/controller, and candidate-policy receipts.

UM9 removed the UM8 contact-progression failure at `0.300 kg`. Every candidate
advanced every limb through the complete `1080`-tick evidence horizon with
zero contact-gate timeouts and at least two accepted cycles per limb:

```text
candidate  evidence advance  final advance  maximum anchor error  witness phase
UM9-A      0.967045 m        1.154332 m     0.025307162 m         tick 41
UM9-B      0.951300 m        1.130853 m     0.025319425 m         tick 45
UM9-C      0.979209 m        1.166441 m     0.025635095 m         tick 45
```

All non-anchor walking gates passed at the heavy endpoint. The remaining
maximums occurred before the candidate cap window: UM9-A peaked four ticks
before the release gate and five ticks before its cap start; UM9-B and UM9-C
peaked exactly at the release gate. Each witness remained a contact-loaded
knee in swing with the unchanged saturated `-3.5 rad/s` command. This rejects
a post-release-only window as sufficient and bounds the remaining tradeoff to
the short pre-release band without weakening the demonstrated heavy walking
progression.

No candidate satisfies the all-five selection rule, so UM9 selects no policy.
The `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures remain untouched and
no UM9 held-out validation is run. The existing walker and its validated
torso-mass interval remain unchanged.

#### Preregistered G1-UM10 release-gate notch campaign

UM10 tests whether a short pre-release cap can remove the remaining
sub-millimeter anchor excess while preserving full lift-off authority at the
gate. It does not reinterpret or rescue UM9. The complete UM9-A policy is the
fixed base, including its `2.5 rad/s` heavy endpoint and post-release start at
`release_gate_tick + 1`.

For a heavy contact-loaded swing knee, the reduced cap is active in two
declared phase windows:

```text
pre_release_start_phase_tick <= local_phase_tick < release_gate_tick
release_gate_tick < local_phase_tick < realized_swing_ticks
```

The exact `release_gate_tick` is a one-tick full-speed notch: its maximum
target speed remains `3.5 rad/s` even while the foot bears the floor. All
earlier swing ticks, every hip, every stance knee, every airborne knee, and all
masses at or below `0.250 kg` also retain the unchanged `3.5 rad/s` clamp.

The ordered pre-release grid is fixed before UM10 physics:

```text
candidate  pre-release formula      0.300 kg window  0.275 kg window
UM10-A     release_gate_tick - 4    ticks 41-44      ticks 45-48
UM10-B     release_gate_tick - 6    ticks 39-44      ticks 43-48
UM10-C     release_gate_tick - 9    ticks 36-44      ticks 40-48
```

UM10-A begins exactly at the UM9-A tick-`41` witness. UM10-B and UM10-C
progressively widen the capped approach without ever capping the release-gate
tick. The cap magnitude, actuator law, knee amplitude, swing duration,
post-release start, gate limits, joint limits, motor impulse, position gain,
rate damping, clearance assist, and all walking thresholds remain fixed.

Each candidate runs the same symmetric `0.200`, `0.225`, `0.250`, `0.275`, and
`0.300 kg` selection fixtures in fresh private worlds. The first candidate to
pass every unchanged walking gate in all `5/5` cells wins; later candidates
are not executed after a winner. If no candidate is eligible, UM10 selects no
policy.

Each cell must independently verify every UM9 receipt plus the pre-release
lead formula, realized pre-release start, exact one-tick full-speed override,
activation count, maximum capped command, maximum-anchor context, per-limb
gate holds/timeouts/synchronization, evidence advance, accepted contact
cycles, fixture/controller/policy digests, process containment, and engine
log. Passing requires both the unchanged `0.025000 m` structural limit and
every contact-progression gate; trading one failure back for the other is not
a selected result.

The still-unexecuted `0.2125`, `0.2625`, and `0.2875 kg` fixtures remain the
UM10 held-out set. If UM10 selects a policy, that exact policy runs three fresh
repetitions per held-out mass. Validation remains all `9/9` private worlds and
`144/144` assertions with zero engine errors, timeouts, killed process trees,
open containment trees, or nonzero exits.

No lead value, notch phase, endpoint speed, activation predicate, base
controller field, threshold, selection rule, or held-out value may change
after a UM10 result is observed and remain part of this campaign. A passing
validation would establish bounded upper-mass adaptation for this one
quadruped geometry, not complete G1, arbitrary quadruped walking, or
morphology-general locomotion.

#### G1-UM10 selection and held-out validation result

UM10-A was the first ordered candidate and passed every unchanged walking gate
for all five selection fixtures from clean immutable source
`8b2d4433b83c3496fb8e08c082e52d5d9426e1c6`. The preregistered stop rule
therefore selected UM10-A and left UM10-B and UM10-C unexecuted.

The counted selection report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g1_um10a_clean_8b2d443\20260726T053114924\report.json
sha256:d09b87318d3bc7affe327b18ce2049767a453a343b771d44748da9d1207fe83b
policy_sha256=sha256:c18bd716118f6a539a926b967ef4be12fe1795eccade78d7919b6e8939a96383
```

The selection record is `5/5` fresh private worlds and `80/80` harness
assertions. Every selected cell completed the full `1080`-tick evidence
horizon for every limb with zero contact-gate timeouts:

```text
upper mass  evidence forward  final forward  max anchor error  accepted cycles FL/FR/RL/RR
0.200 kg    0.897586 m        1.100829 m     0.019776484 m     3/3/3/3
0.225 kg    0.925335 m        1.092783 m     0.021153988 m     3/3/3/3
0.250 kg    0.823574 m        0.972312 m     0.022452844 m     3/3/3/3
0.275 kg    0.865907 m        1.061198 m     0.023508042 m     3/3/3/3
0.300 kg    0.947016 m        1.150602 m     0.024775123 m     3/3/2/3
```

At `0.300 kg`, the selected controller realized the exact preregistered
four-tick approach window at phase ticks `41-44`, restored the full
`3.5 rad/s` knee command for release-gate tick `45`, and resumed the
`2.5 rad/s` cap after the gate. This preserved the complete contact-gated
walking progression while reducing the maximum anchor error below the
unchanged `0.025000 m` structural limit.

The exact selected policy then passed all three preregistered repetitions of
the untouched `0.2125`, `0.2625`, and `0.2875 kg` held-out fixtures:

```text
repetition  report                                                                   sha256
R1          <evidence-root>\temp-roots-2026-07-28\sporespore_g1_um10a_heldout_r1_clean_8b2d443\20260726T053348994\report.json  8ef3ee7d8c7f8d96e61705601827d29b732c17fc3c65e778c6a4f306d4aabe44
R2          <evidence-root>\temp-roots-2026-07-28\sporespore_g1_um10a_heldout_r2_clean_8b2d443\20260726T053519220\report.json  95d9b64b16e2be01330ee3d774925fd562263651a58e7f98292c8672171bbfdb
R3          <evidence-root>\temp-roots-2026-07-28\sporespore_g1_um10a_heldout_r3_clean_8b2d443\20260726T053811261\report.json  3c33cd3f80e61ef9b5ef396a17f3db40d56255c8a9d315ee5dd097f0d751feb1
```

Each repetition produced the same deterministic physical measurements:

```text
upper mass  evidence forward  final forward  max anchor error  accepted cycles FL/FR/RL/RR
0.2125 kg   0.873110 m        1.052785 m     0.020334382 m     3/3/3/2
0.2625 kg   0.903973 m        1.085917 m     0.023595624 m     3/3/3/3
0.2875 kg   0.886273 m        1.064129 m     0.024927577 m     3/3/3/3
```

The held-out record is `9/9` fresh private worlds and `144/144` assertions.
All reports used schema
`sporespore_br14a_single_mass_axis_probe_report_v14`, the same selected policy
digest, clean immutable source, distinct mass-specific fixture digests, and
closed process containment. There were zero engine errors, timeouts, killed
process trees, open containment trees, nonzero exits, failed harnesses, or
walking failures. The tightest observed structural margin was `0.000072423 m`
at `0.2875 kg`; this is a pass under the fixed threshold, not evidence that the
unmeasured interval beyond `0.300 kg` is safe.

UM10 therefore establishes bounded symmetric upper-leg-mass robustness from
`0.200` through `0.300 kg`, including the three held-out interior masses, for
this one four-limb geometry under one selected policy. It does not complete G1,
validate uniform geometry scaling, establish arbitrary quadruped walking, or
establish morphology-general locomotion.

### G2: uniform geometry scaling

Scale the whole morphology uniformly while preserving four-limb topology.
Derived initial positions, segment shapes, joint anchors, foot radius, camera,
and safety bounds must come from the normalized spec rather than hidden
reference constants.

Before running evidence, preregister:

- whether mass is held fixed or follows a declared density rule;
- whether gait period follows dynamic similarity or remains fixed;
- how motor impulse scales with mass, length, and gait period;
- how collision margin scales or clamps; and
- dimensionless movement and structural thresholds.

The fixed-meter reference thresholds remain authoritative for the reference
creature. A generated-size campaign needs normalized gates, such as forward
advance relative to torso length and anchor error relative to segment length,
defined before observing outcomes.

#### Preregistered G2-GS1 constant-period uniform-scale campaign

G2-GS1 is the first generated-geometry campaign. It asks whether the reference
four-limb topology and one formula-complete controller policy remain walking
across a bounded family of uniformly scaled copies. It does not vary
proportions, limb count, density, friction, joint topology, or front/rear
distribution.

Let `s` be the declared uniform linear scale relative to the reference fixture.
The generator must start from the pinned reference spec, apply every formula
below before world construction, compile the resulting ordinary rigid-body
fixture through the existing fail-closed schema, and record both its normalized
spec and digest:

```text
quantity                                        G2-GS1 formula
every position, length, size, radius            reference * s
torso, upper-leg, and distal mass               reference * s^3
collision margin                                0.002 m * s
hip and knee maximum motor impulse              reference * s^5
joint-angle limits and gait-angle targets       unchanged radians
gait period, phase ticks, and swing ticks       unchanged ticks
maximum joint target speed                      unchanged rad/s
cross-track heading gain                        0.5 / s rad/m
friction, bounce, damping, CCD, and solver       unchanged
```

The `s^3` mass law declares constant density. G2-GS1 deliberately keeps the
`360`-tick gait period fixed rather than claiming dynamic similarity. With
fixed period and constant density, the declared rigid-body torque requirement
scales as `mass * length^2 / period^2 = s^5`, so both physical motor-impulse
ceilings use that exponent. The reference controller at `s = 1` is the
reference-mass realization of UM10-A: lateral phase order, `1.75` knee-flexion
scale, `72` swing ticks, `0.40 rad` clearance assist, S2 contact gating
(`96` hold ticks and `12` skew ticks), and phase-bounded path steering. The
upper-mass-specific knee-rate cap is inactive at the reference mass and is not
silently reused as a geometry-scaling law.

Visible-demo camera position, camera target, and orthographic size must scale
by `s`. The floor remains centered at height zero, while its horizontal extent,
thickness, center depth, and collision margin scale by `s`. Headless and
visible worlds must use the same generated fixture and controller receipts.

The walking gates are fixed in dimensionless form before any G2 physics:

```text
gate                                      normalized rule                 realized threshold
minimum per-cycle foot relocation         0.024 * torso length            0.012 m * s
minimum evidence torso advance            0.080 * torso length            0.040 m * s
minimum final torso advance               0.060 * torso length            0.030 m * s
maximum absolute lateral drift            0.3125 * torso width            0.100 m * s
minimum torso-center height               0.568181818 * initial height    0.250 m * s
maximum joint-anchor separation           0.138888889 * upper length      0.025 m * s
maximum yaw drift                         unchanged angular bound         0.45 rad
maximum tilt                              unchanged angular bound         0.60 rad
maximum hinge-axis error                  unchanged angular bound         0.20 rad
```

All existing topology, one-continuous-world, no-reset, no-root-command,
contact-observation, contact-cycle, evidence-horizon, torso-contact, terminal
recovery, finite-value, digest, engine-log, and process-containment gates
remain unchanged. A scale-specific run may not pass by applying reference
meter thresholds where the normalized threshold is stricter.

The ordered selection cells are fixed at:

```text
s = 0.900, 0.950, 1.000, 1.050, 1.100
```

G2-GS1 selects only if all `5/5` fresh private worlds pass every normalized
walking gate under the single formula policy. This campaign has no empirical
candidate grid: the density, period, impulse, gain, and threshold exponents
come from the preregistered dimensional model. Any failure rejects G2-GS1 and
requires a separately preregistered successor; no exponent or threshold may be
edited after observing a selection result.

The untouched held-out scale set is:

```text
s = 0.925, 0.975, 1.025, 1.075
```

If and only if selection passes, the exact selected formula policy runs three
fresh repetitions for every held-out scale. The perturbation receipts are
fixed before selection:

```text
repetition  vertical clearance  yaw       linear velocity m/s                angular velocity rad/s  phase
R1          0                  0          (0, 0, 0)                          (0, 0, 0)               0
R2          0.0007*s m         +0.003 rad (0.002*s, 0, +0.001*s)            (+0.002,0,+0.001)       +1
R3          0.0014*s m         -0.006 rad (0.004*s, 0, -0.002*s)            (+0.003,-0.002,+0.002)  -2
```

Validation requires all `12/12` held-out worlds, all harness assertions, four
stable scale-specific fixture digests, exact scale/mass/impulse/gain/threshold
receipts, one formula-policy digest, and zero engine errors, timeouts, killed
process trees, open containment trees, or nonzero exits.

A complete G2-GS1 selection and validation would establish bounded uniform
scale robustness only over `s = 0.900` through `1.100` for scaled copies of
this one quadruped. It would not complete nonuniform G3, arbitrary quadruped
walking, other limb counts, bipedal walking, running, or
morphology-general locomotion.

#### Immutable pre-selection BR14A family baseline

Before opening G2-GS1 selection, the complete BR14A family was rebuilt from a
`git archive` snapshot of exact source commit
`4716ff1cf2d7b8d1a4283b406f3659f66f016ac6`. This avoids the source-provenance
ambiguity of a long live-worktree run while another writer advances `main`.

```text
source tree:
  2b71270485cdffc9bc1203ab54ffd15e31674dca
source archive:
  <evidence-root>\temp-roots-2026-07-28\sporespore_br14a_snapshot_4716ff1_20260726T083343334\source.zip
source archive sha256:
  89f563f9f7d5899b6fe9665f3e4c727d03a9b27df7ba490ea89e6cda00e60619
report:
  <evidence-root>\temp-roots-2026-07-28\sporespore_br14a_snapshot_4716ff1_20260726T083343334\
    reports\20260726T083405726\report.json
report sha256:
  2d392962b73e63da14e14e3d2c1d68d1bd836419e0cf2f0f98d9a72dbf3af251
result:
  26/26 programs, 453/453 assertions
```

The hidden editor preflight exited zero. The family run had zero engine errors,
timeouts, killed or open process trees, nonzero exits, missing footers, invalid
process windows, or unreadable logs. This is authoritative regression evidence
for `4716ff1`; it is not evidence for later commits or for a supplied G2 physics
cell.

#### G2-GS1 selection result: rejected at the upper endpoint

The clean committed selection ran on source
`e8bb4667f508325ba5a74f3cedd406f2ccda8d4a`. The report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs1_selection_e8bb466\
  20260726T091848739\report.json
sha256:34e03ba5333f8d6fef325e62928813cb328410aff8bc1a92f2f7abdf7172c451
```

All five fixture digests were distinct, the formula policy digest remained
`sha256:8cf9f3307f3a54e41fee9984159445d0c1b22824e32123e786ddd06c0db8b66f`,
the scoped source was clean, and every process closed inside containment with
zero engine errors. The selection outcomes were:

```text
scale  walked  evidence forward  final forward  final lateral  max anchor
0.900  yes     0.847535 m        1.035606 m     +0.065904 m    0.020514555 m
0.950  yes     0.867590 m        0.997219 m     +0.027397 m    0.023424400 m
1.000  yes     0.823574 m        0.972312 m     -0.020931 m    0.022452844 m
1.050  yes     0.981582 m        1.189493 m     +0.029405 m    0.023996290 m
1.100  no      0.905017 m        1.094945 m     +0.012067 m    0.025209757 m
```

The four passing cells completed `22/22` assertions each. The `1.100` cell
completed `19/22`, for a reconstructable total of `107` passed and `3` failed
assertions. The original report's two aggregate assertion fields serialized as
blank because `Measure-Object -Property` did not read the ordered result
dictionaries; every per-cell count remained intact. Commit `a0bfa41` corrects
that report-only bug for future campaigns. It does not alter or rescue GS1.

An isolated reproduction of only the rejected cell printed the complete gate
dictionary. Its transcript is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs1_diag_1p100_20260726T092200\transcript.log
sha256:8ef88e9e29ce2a82852d0f4142ca25408f784d0967d4a498666ff5ae208fafb5
```

Exactly one of the 25 named walking gates was false:
`every_limb_forward_relocation`. Rear-right minimum cycle relocation was
`0.012917757 m` against the preregistered `0.013200000 m` threshold, a
`0.000282243 m` or approximately `2.14%` shortfall. The other limbs realized
`0.062646627`, `0.040850401`, and `0.028993845 m`. Every other gate remained
true, including more than one meter of forward recovery, yaw and tilt, torso
clearance, zero torso contact, terminal four-foot support, anchor and hinge
bounds, two cycles per limb, and the complete gait horizon.

G2-GS1 therefore rejects. Its threshold may not be weakened and its held-out
`0.925`, `0.975`, `1.025`, and `1.075` scales remain unopened. Any successor
must be separately preregistered before changing the controller or scale law.

#### Preregistered G2-GS2 observed-envelope confirmation

G2-GS2 is a deliberately narrower, data-informed successor. It does not claim
that the G2-GS1 result was independent exploration: four of its selection cells
were observed passing under G2-GS1, and the failed `1.100` endpoint motivated
the narrower envelope. Its purpose is to turn that observed region into a
fresh, held-out-validated bounded result without weakening the walking
predicate or silently changing the controller.

G2-GS2 freezes every G2-GS1 physical formula and controller receipt:

- geometry, positions, lengths, radii, floor, margin, and presentation scale
  by `s`;
- all nine body masses scale by `s^3`;
- hip and knee motor-impulse ceilings scale by `s^5`;
- gait period, phase order, swing ticks, angle targets, motor target-speed
  ceiling, material, damping, contact gating, and solver settings remain
  reference-exact;
- cross-track heading gain remains `0.5 / s`; and
- every movement and structural threshold remains the same preregistered
  dimensionless rule used by G2-GS1.

No controller-law or empirical parameter candidate grid is permitted. The GS2
campaign-policy receipt necessarily differs from GS1 because that sealed
receipt includes its campaign generation and its different selection and
validation grids. Its schema is fixed as
`sporespore_g2_uniform_scale_policy_v2`; it must encode the same physical laws
listed above, `campaign_generation=G2-GS2`, and exactly the scale grids below.
The implementation printed the exact receipt from an immutable archive of
source commit `804ac088b738e27d7c61c228707b47502394530a` before selection:

```text
policy:
  sha256:0ac53ed6136b395613811852fac4a0ef6cbb734a0035c8bc85b80b8a5c140a1d
source archive:
  <evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs2_policy_receipt_804ac08\source.zip
source archive sha256:
  82315b95a9b3c6522d2f0a694dcb75ee1166e3d5c1b5188a79846c2fe116d05e
transcript:
  <evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs2_policy_receipt_804ac08\transcript.log
transcript sha256:
  933d67a0befdce7db3ced424e7726b7e4cb40189dba8b616278d492a35ab92d9
result:
  2/2 assertions, zero exit, zero timeout, contained process tree closed
```

This receipt mode constructs no physics world. Every later GS2 cell must
reproduce the policy digest exactly.

The ordered G2-GS2 selection cells are:

```text
s = 0.900, 0.950, 1.000, 1.050, 1.075
```

The first four are fresh reproductions of previously observed passing cells.
`1.075` was never opened by G2-GS1 and now becomes the preregistered GS2 upper
selection endpoint. Selection requires all `5/5` cells and `110/110`
assertions, five distinct fixture digests, one formula-policy digest, and zero
engine, process, containment, source-cleanliness, or receipt failures. A
`1.075` failure rejects GS2; its threshold and formula may not be edited.

Only complete selection unlocks the still-unopened interior validation scales:

```text
s = 0.925, 0.975, 1.025
```

Each held-out scale runs the already-published R1, R2, and R3 perturbations from
G2-GS1. Validation therefore requires all `9/9` fresh private worlds and
`198/198` assertions, three stable scale-specific fixture digests across
repetitions, the selected formula-policy digest, exact controller and threshold
receipts, and zero engine or process-control failures.

A complete G2-GS2 result would establish discrete held-out evidence for the
same formula-complete controller across uniformly scaled copies from `0.900`
through `1.075`. It would explicitly exclude the rejected `1.100` endpoint and
would not establish continuous-scale guarantees, nonuniform proportions,
arbitrary quadrupeds, other limb counts, running, or morphology-general
locomotion.

#### G2-GS2 selection and held-out result: validated

The authoritative bundle used byte-identical clean source snapshots of exact
source commit:

```text
89a6d5daf46b1793d78ee0a857062abb471702af
```

The selection report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs2_selection_official_89a6d5d\
  20260726T094453485\report.json
sha256:4e857f7a3e1eca18a68ef2e4f13429785d592b6a52a4f6a3c79a6157688b49d7
5/5 worlds, 110/110 assertions
```

Selection passed all five declared scales, including the previously unopened
`1.075` upper endpoint. The three held-out repetition reports are:

```text
R1:
  <evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs2_heldout_r1_official_89a6d5d\
    20260726T094728849\report.json
  sha256:2c010d252471a61819827eade63278191800cde54202257489af24aff7110f0c
R2:
  <evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs2_heldout_r2_official_89a6d5d\
    20260726T094835397\report.json
  sha256:525875c5df5c81963cefb0ffc698810e7dc9289c51808dcf708e8d39f842c622
R3:
  <evidence-root>\temp-roots-2026-07-28\sporespore_g2_gs2_heldout_r3_official_89a6d5d\
    20260726T094941406\report.json
  sha256:cd28dc44cd9e2296f3c1a85993ab8b86148d9a7c530cf85e553d6dd265ae8977
each: 3/3 worlds, 66/66 assertions
```

Across the complete bundle, `14/14` worlds and `308/308` assertions passed.
The four reports contain one exact source commit, one byte-identical source
receipt, one GS2 policy digest, eight distinct scale-specific fixture digests,
eight matching controller digests, and eight matching threshold digests.
Every held-out scale reproduced its fixture, controller, and threshold digest
across R1-R3. There were zero engine errors, timeouts, killed process trees,
open containment trees, nonzero exits, dirty scoped sources, bad harnesses, or
walking failures. Every report acquired the suite mutex without abandonment.

The tightest recorded body-level structural margin was the anchor-separation
gate at held-out `s = 0.925`: `0.000249754 m` remained below its normalized
maximum. The tightest lateral margin was `0.024096 m`; the tightest hinge,
height, evidence-forward, and final-forward margins were all positive. The
per-limb relocation predicate also passed in every world.

G2-GS2 therefore establishes bounded, discrete held-out evidence for this one
four-limb topology under proportional uniform scaling from `s = 0.900` through
`1.075`. The earlier `s = 1.100` GS1 failure remains a real excluded boundary.
This result is stronger than one tuned walking creature, but it is not a
continuous-scale theorem, a nonuniform-proportion result, an arbitrary
quadruped walking system, another limb count, running, or morphology-general
locomotion. Every report keeps formal acceptance, encyclopedia admission, and
automatic creature guidance false.

#### Post-G2-GS2 complete BR14A regression

After the authoritative GS2 selection and all three held-out repetitions
completed, the complete repository-default BR14A family was rerun from the
same immutable clean source snapshot:

```text
source commit:
  89a6d5daf46b1793d78ee0a857062abb471702af
report:
  <evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_post_gs2_89a6d5d\
    20260726T095146966\report.json
report sha256:
  a50f934092503a3532242d2bed1e7f4e1c6131182562ef63a0338a548691094c
result:
  27/27 programs
  454/454 assertions
```

The report records zero timeouts, killed process trees, open containment
trees, missing exit markers, invalid process windows, missing or unreadable
logs, malformed test footers, engine errors, and unexpected engine errors.
The serial suite mutex was acquired without abandonment. The two physical
wave-gait programs correctly exercised their repository-default solver-4
refusal branches; the actual solver-6 walking and scale claims remain supported
by their separately isolated campaign reports above, not by those refusal
branches.

This closes the complete-family regression requirement for the unchanged GS2
source. It is baseline evidence only: it does not validate the still-uncommitted
GS3 dynamic-similarity implementation or authorize any GS3 physics cell.

#### Preregistered G2-GS3 dynamic-similarity upper extension

G2-GS3 is a distinct, data-informed controller policy targeting the measured
`s = 1.100` fixed-period boundary. It may use the GS1 failure to choose dynamic
similarity as its model, but it may not weaken the walking predicate, tune a
threshold after observing a GS3 cell, or count any GS1/GS2 world as GS3
evidence.

For constant-density uniform scale, length is proportional to `s`, mass to
`s^3`, and rotational inertia to `s^5`. Gravitational torque is proportional to
`mass * gravity * length = s^4`. The dynamically similar gait time is
proportional to `sqrt(s)`, so angular acceleration is proportional to `1/s`;
inertial torque is therefore also `s^5 / s = s^4`.

Godot 4.7's built-in Jolt adapter converts
`HINGE_JOINT_MOTOR_MAX_IMPULSE` into a Jolt torque limit by dividing the
declared impulse by the estimated fixed physics step
(`modules/jolt_physics/joints/jolt_hinge_joint_3d.cpp`). Because this campaign
keeps physics at `120 Hz`, the Godot motor-impulse field follows the same `s^4`
torque exponent. Target angular speed and the angle-error position gain follow
`1 / sqrt(s)`.

Let `round_positive(x) = floor(x + 0.5)` and:

```text
r = sqrt(s)
quarter_cycle_ticks q = round_positive(90 * r)
cycle_ticks C         = 4 * q
```

The complete GS3 formula is fixed before implementation or physics:

```text
quantity                                      G2-GS3 formula
geometry, positions, lengths, radii           reference * s
all nine body masses                          reference * s^3
collision margin                              0.002 m * s
hip and knee motor max impulse                reference * s^4
cycle ticks                                   C
swing ticks                                   round_positive(0.20 * C)
settle and terminal-settle ticks              round_positive(240 * r)
evidence-boundary alignment ticks             round_positive((112 / 360) * C)
maximum contact-gated evidence extension      2 * C
maximum contact-gate hold ticks               round_positive((96 / 360) * C)
maximum contact-gated phase skew ticks        round_positive((12 / 360) * C)
path-steering update interval                 q
minimum airborne dwell ticks                  round_positive((3 / 360) * C)
motor position gain                           8.0 / r per second
maximum motor target speed                    3.5 / r rad/s
motor rate damping                            unchanged 0.65
linear damping                                0.08 / r per second
angular damping                               0.15 / r per second
joint limits and gait target angles           unchanged radians
cross-track heading gain                      0.5 / s rad/m
friction, bounce, CCD, solver, Hz              unchanged
warmup, evidence, cooldown cycle counts       unchanged 1, 3, 1
```

The compiled `s = 1.100` receipt is fixed as:

```text
r = 1.04880884817015
q = 94
C = 376
swing_ticks = 75
settle_ticks = 252
terminal_settle_ticks = 252
evidence_boundary_alignment_ticks = 117
maximum_contact_gated_evidence_extension_ticks = 752
maximum_contact_gate_hold_ticks = 100
maximum_contact_gated_phase_skew_ticks = 13
path_steering_update_interval_ticks = 94
minimum_airborne_dwell_ticks = 3
motor_position_gain_per_s = 7.62770071396474
maximum_motor_target_speed_rad_s = 3.33711906235957
linear_damp_per_s = 0.0762770071396474
angular_damp_per_s = 0.143019388386839
motor_impulse_scale = 1.4641
hip_motor_max_impulse = 0.0805255 N m s
knee_motor_max_impulse_after_fixed_10x_factor = 0.658845 N m s
```

At `s = 1.000`, the compiler must return the existing `360` cycle ticks, `72`
swing ticks, `240` settle ticks, `112` alignment ticks, `720` extension ticks,
`96` hold ticks, `12` skew ticks, `90` steering ticks, `3` airborne-dwell
ticks, `8.0` position gain, `3.5 rad/s` speed cap, `0.65` rate damping, `0.08`
linear damping, `0.15` angular damping, and unit impulse scale exactly.

The same normalized GS2 movement and structural thresholds remain binding.
The G2-GS2 fixed-period policy remains the validated policy for its own
`0.900`-through-`1.075` evidence; GS3 does not rewrite or supersede those
reports.

The ordered GS3 selection cells are:

```text
s = 1.000, 1.100, 1.150
```

The `1.000` cell is an exact reference-identity control. The `1.100` cell is the
known fixed-period failure under a new preregistered policy. `1.150` has not
been opened by any G2 campaign. All `3/3` cells must pass before validation.

The untouched GS3 held-out scales are:

```text
s = 1.050, 1.125
```

Each held-out scale runs three repetitions. R1 remains unperturbed. For R2 and
R3, vertical clearance remains proportional to `s`, yaw remains angular and
unchanged, linear velocity is multiplied by `sqrt(s)`, angular velocity is
divided by `sqrt(s)`, and signed gait-phase offsets use
`sign(n) * round_positive(abs(n) * sqrt(s))`. The reference R2/R3 values and
all other perturbation fields remain those already published for G2-GS1.

Before any GS3 world opens, implementation must:

- add a fail-closed timing compiler with the exact integer receipts above;
- preserve the default `360`-tick controller byte-for-byte in realized
  behavior and clear the complete BR14A family;
- add the `s^4` fixture generator without changing GS1/GS2 generation;
- seal one campaign-policy digest in a no-world receipt;
- publish exact per-cell assertion counts and report schema; and
- keep hidden workers serialized, private-profiled, immutable-snapshot-based,
  and process-contained.

#### GS3 pre-physics implementation result — 2026-07-26

All preregistered pre-physics gates are complete. No GS3 physics world was
opened while implementing or verifying them.

The dynamic-similarity compiler, scaled fixture law, campaign runner, report
schema, fail-closed receipt checks, and distinct-per-scale gait-clock checks
were implemented and committed through exact source:

```text
686eb14f128234eec2478eede5ac0735e19342b5
```

The implementation sequence is retained as:

```text
bdc612d  feat(locomotion): compile dynamic gait scaling
39a5b06  test(locomotion): seal dynamic scale campaign
602071f  test(locomotion): harden dynamic scale receipts
16cc837  fix(locomotion): honor scaled relocation receipt
32ab36b  revert(locomotion): preserve atomic relocation floor
931e26e  test(locomotion): require distinct scale clocks
686eb14  test(locomotion): pin reference controller digest
```

The `16cc837` relocation-floor change was deliberately reverted: the existing
`0.012 m` atomic contact-cycle floor is a separate invariant, while the
dimensionless campaign movement threshold is already scaled and independently
enforced. GS3 therefore does not weaken the validated atomic floor.

`gdformat --check`, `gdlint`, and the PowerShell runner parser all cleared the
GS3 source. The exact `686eb14` no-world compiler contract passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gs3_compiler_contract_official_686eb14\
  20260726T121019684\report.json
sha256:e7da081fbc585a81c546cdb6c502a5f1da9e2d8c709a2f5a6bcd2a1fee2d508e
1/1 program, 14/14 assertions
```

That contract proves the unit-scale identity receipt, the exact `s = 1.100`
integer and fixture receipts, the `s^4` motor-impulse law, inverse-time gains
and damping, separation from the fixed-period policy, fail-closed invalid and
tampered inputs, pre-world walker rejection, the pinned reference-controller
digest, and absence of claim authority.

The formula-complete no-world campaign receipt is:

```text
campaign=G2-GS3
policy_digest=sha256:aa00e48fbf6fcda722c55a4fc39d5f2c6cbf0471ced3e043513b2be93dc0a956
<evidence-root>\temp-roots-2026-07-28\sporespore_gs3_policy_receipt_official_686eb14\
  20260726T1211\transcript.log
transcript_sha256=sha256:10103aa1ced129036b77ed70641a09a8af6d199eb357dd481c181ba113c80b21
2/2 assertions
```

The complete BR14A family then cleared from exact committed source `931e26e`,
whose production and campaign bytes are identical to `686eb14`:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_gs3_core_official_931e26e\
  20260726T112808510\report.json
sha256:43e64513e7652b7f2d73e896aa1fee0074bce548016befa5bf3d173c27d3e121
28/28 programs, 467/467 assertions
```

The only `931e26e..686eb14` change is 55 added lines in the no-world compiler
test that pin the reference-controller digest. The strengthened test separately
cleared `14/14` from exact `686eb14`; no production or campaign implementation
changed after the full-family run. Both reports have zero timeouts, killed or
open process trees, malformed time windows, missing exit markers, missing
footers or logs, engine errors, and abandoned mutexes.

Finally, the fixed-period G2-GS2 reference selection was rerun from the completed
GS3 core:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gs2_reference_post_gs3_core_931e26e\
  20260726T112517589\report.json
sha256:2d3c9b30c74264d47b3e752f8f675cc8e3fe224ceb70c583a13ea37d0f61f7a5
5/5 worlds, 110/110 assertions
```

Its policy digest, all fixture/controller/threshold digest sets, and every
scale-specific movement and structural metric are exactly identical to the
authoritative pre-GS3 G2-GS2 selection. This is the backward-compatibility
control: integrating GS3 did not alter the realized fixed-period walker.

#### G2-GS3 selection and held-out result: validated

The authoritative GS3 bundle used immutable byte-identical snapshots of exact
clean source:

```text
686eb14f128234eec2478eede5ac0735e19342b5
```

The selection report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gs3_selection_official_686eb14\
  20260726T121448283\report.json
sha256:8e6cf6ec6385fd6efa111bf0e50915f12ac619101975642f2c9aa50578c44f6a
3/3 worlds, 66/66 assertions
```

All three preregistered selection cells walked. This includes the former
fixed-period failure at `s = 1.100` under the new derived controller policy and
the previously unopened upper endpoint at `s = 1.150`. Selection therefore
unlocked the untouched `s = 1.050` and `s = 1.125` held-out scales. Their three
fixed repetition reports are:

```text
R1:
  <evidence-root>\temp-roots-2026-07-28\sporespore_gs3_heldout_r1_official_686eb14\
    20260726T121724748\report.json
  sha256:0feb267e093887d3fdfba071ff6704b3eb88e431e80d1036e28c5751861a3964
R2:
  <evidence-root>\temp-roots-2026-07-28\sporespore_gs3_heldout_r2_official_686eb14\
    20260726T121823369\report.json
  sha256:fc799e50fd50ef200d3977c79142d86eb9bff7280c32fc3573ace7bff6fdf507
R3:
  <evidence-root>\temp-roots-2026-07-28\sporespore_gs3_heldout_r3_official_686eb14\
    20260726T121921808\report.json
  sha256:3570672c0d565a760ebb717caa0d97e544c3840e3f9e6006276c22e81b729085
each: 2/2 worlds, 44/44 assertions
```

Across the complete bundle, `9/9` worlds and `198/198` assertions passed. All
four reports contain the exact source commit, schema v3, one formula-complete
GS3 policy digest, and five distinct scale-specific gait-clock, fixture,
controller, and threshold digests. At each held-out scale, all four digests
were stable across R1-R3. Every on-disk transcript and engine-log hash matches
its report. There were zero engine errors, timeouts, nonzero exits, killed or
open process trees, dirty scoped sources, bad harnesses, walking failures, or
abandoned mutex acquisitions.

The tightest held-out normalized body-level margins all remained positive. The
maximum anchor error was `0.023013797` body-scale units against `0.025`; the
maximum lateral drift was `0.079126667` against `0.100`; the maximum hinge-axis
error was `0.119786676 rad` against `0.200 rad`; and the minimum torso height
was `0.426583517` body-scale units against `0.250`. The minimum normalized
evidence and final forward travel were `0.784088889` and `0.971977778`,
respectively, against `0.040` and `0.030`. The per-limb relocation predicate
also passed in every world.

G2-GS3 therefore establishes bounded discrete uniform-scale evidence for this
one four-limb topology under a second, physically derived controller policy
through `s = 1.150`. It explains and overcomes the earlier fixed-period
`s = 1.100` failure; it does not erase that policy-specific negative result.
It also does not establish continuous-scale guarantees, nonuniform
proportions, arbitrary quadrupeds, other limb counts, running, or
morphology-general locomotion. Every report keeps formal acceptance,
encyclopedia admission, and automatic creature guidance false.

### G3: nonuniform quadruped proportions

Vary torso length/width, upper/lower segment ratio, hip spacing, foot radius,
and front/rear mass distribution independently. This is the first stage that
tests whether the controller handles genuinely different quadruped shapes
rather than scaled copies.

Generated fixtures must pass a static construction screen before physics:

- no undeclared initial self-intersection (the connected joint-attachment
  allowance is screened separately);
- feet can reach the declared floor;
- every joint anchor is finite and connected to the intended bodies;
- joint limits contain the neutral stance;
- declared motor capacity is nonzero; and
- the support polygon contains the initial projected center of mass with a
  recorded margin.

#### Preregistered G3-GP1 independent-proportion campaign

G3-GP1 is the first nonuniform-shape campaign. It asks whether the exact
unit-scale GS3 controller can walk a bounded set of quadrupeds whose proportions
differ from the reference independently and in untouched combinations. It does
not vary limb count, joint topology, joint-angle targets, gait timing, total
leg reach, total limb mass, torso mass, friction, or motor capacity.

No G3-GP1 physics world was opened before the policy below was fixed.

The fail-closed morphology compiler starts from the pinned reference fixture
and accepts exactly these six dimensionless parameters:

```text
parameter                    symbol   allowed envelope
torso length scale           L        [0.900, 1.100]
torso width scale            W        [0.900, 1.100]
upper share of leg reach     U        [0.480, 0.550]
front/rear and lateral
  hip-span scale             H        [0.900, 1.100]
foot-radius scale            F        [0.900, 1.100]
front limb-mass scale        M        [0.900, 1.100]
```

Starting from the reference `0.50 x 0.12 x 0.32 m` torso, `0.35 m` total leg
reach, `0.04 m` foot radius, `+/-0.20 m` longitudinal hips, `+/-0.18 m`
lateral hips, `0.25 kg` upper bodies, and `0.18 kg` distal bodies, the complete
generator is:

```text
torso size                    [0.50 L, 0.12, 0.32 W] m
hip offsets                   [+/-0.20 H, -0.05, +/-0.18 H] m
upper length                  0.35 U m
lower reach                   0.35 (1 - U) m
foot radius                   0.04 F m
initial torso center height   0.05 + 0.35 + 0.04 F m
front upper/distal mass       reference mass * M
rear upper/distal mass        reference mass * (2 - M)
```

The paired front/rear mass formula preserves total limb mass exactly. Torso
mass remains `3.0 kg`; changing torso length or width therefore isolates shape
and rotational inertia rather than adding a density change. Upper and distal
masses also remain fixed on all axes except the explicitly declared
front/rear-distribution axis. Total leg reach remains `0.35 m`, so `U` changes
the upper/lower split without changing standing height. The derived torso
height keeps each foot tangent to the floor before release as `F` changes.
The reference share is the exact compiler constant `18 / 35`; when every
parameter is at its reference value, the compiler copies the pinned reference
fixture directly rather than depending on decimal round-trip equivalence.

All other fixture fields remain the reference values byte-for-byte:

```text
upper cross section           [0.045, 0.045] m
collision margin              0.002 m
torso / upper / distal total  3.0 / 1.0 / 0.72 kg
hip motor maximum impulse     0.055 N m s
knee base maximum impulse     0.045 N m s
joint limits and solver       unchanged
friction / bounce / damping   unchanged
collision and CCD policy      unchanged
```

The static compiler must return a canonical parameter digest, normalized
fixture digest, and static-screen digest before world construction. The static
screen must prove:

- every scalar and derived vector is finite and inside the envelope;
- the four declared limb IDs and construction order are unchanged;
- every foot bottom is at floor height within `1e-9 m`;
- all hip and knee anchors are finite and join their declared parent/child;
- zero-angle neutral stance is inside both joint limits;
- both declared motor ceilings are finite and positive;
- all nonadjacent shape pairs have nonnegative clearance;
- each connected torso/upper pair stays inside the reference `0.012 m`
  joint-attachment overlap allowance; and
- the projected whole-system center of mass lies strictly inside the convex
  hull of the four foot centers, with its minimum signed edge distance recorded.

Any failed static predicate rejects the cell before a viewport or physics world
exists. The reference cell must compile to the exact authoritative reference
fixture digest. Every nonreference selection and held-out cell must have a
distinct parameter and fixture digest.

The controller is not retuned per shape. Every cell uses the exact GS3
unit-scale controller:

```text
360 cycle ticks; 72 swing ticks; 240 settle and terminal ticks
112 evidence-alignment ticks; 720 maximum contact extension ticks
96 maximum contact-hold ticks; 12 maximum phase-skew ticks
90 steering-update ticks; 3 minimum airborne-dwell ticks
8.0 position gain; 3.5 rad/s speed cap; 0.65 rate damping
lateral phase order; 1.75 knee-flexion scale; 0.40 rad clearance assist
0.5 rad/m cross-track gain; 1.0 yaw stride gain
no mass-adaptive actuator or motor-velocity option
```

The reference cell must reproduce the pinned GS3 unit controller digest
`sha256:9c6d7962e81da4d1831ac0a99999db46cd87ce3271600e0f8bb5a72beaed4ef6`.
All G3-GP1 cells must retain that one controller digest. A shape-specific
controller edit after observing a cell is forbidden.

Movement and structural gates use the previously published dimensionless rules,
now evaluated from each compiled nonuniform fixture:

```text
minimum per-cycle foot relocation    0.024 * compiled torso length
minimum evidence torso advance       0.080 * compiled torso length
minimum final torso advance          0.060 * compiled torso length
maximum absolute lateral drift       0.3125 * compiled torso width
minimum torso-center height          (25 / 44) * compiled initial height
maximum joint-anchor separation      (5 / 36) * compiled upper length
maximum yaw drift                    0.45 rad
maximum tilt                         0.60 rad
maximum hinge-axis error             0.20 rad
```

All topology, contact observation, per-limb release/recontact, two-cycle
relocation, evidence-horizon, terminal-support, no-root-command, no-reset,
finite-value, torso-contact, solver, digest, log, source-cleanliness, and
process-containment gates remain unchanged.

The ordered selection cells are:

```text
id                     L      W      U        H      F      M
reference              1.000  1.000  18 / 35  1.000  1.000  1.000
torso_length_0p900     0.900  1.000  18 / 35  1.000  1.000  1.000
torso_length_1p100     1.100  1.000  18 / 35  1.000  1.000  1.000
torso_width_0p900      1.000  0.900  18 / 35  1.000  1.000  1.000
torso_width_1p100      1.000  1.100  18 / 35  1.000  1.000  1.000
upper_share_0p480      1.000  1.000  0.480    1.000  1.000  1.000
upper_share_0p550      1.000  1.000  0.550    1.000  1.000  1.000
hip_span_0p900         1.000  1.000  18 / 35  0.900  1.000  1.000
hip_span_1p100         1.000  1.000  18 / 35  1.100  1.000  1.000
foot_radius_0p900      1.000  1.000  18 / 35  1.000  0.900  1.000
foot_radius_1p100      1.000  1.000  18 / 35  1.000  1.100  1.000
front_mass_0p900       1.000  1.000  18 / 35  1.000  1.000  0.900
front_mass_1p100       1.000  1.000  18 / 35  1.000  1.000  1.100
```

Selection requires `13/13` fresh private worlds and `325/325` assertions.
Every one-axis endpoint must pass. A failure rejects G3-GP1 and leaves all
mixed held-outs unopened; the failed value, measurement, and receipt are
retained and may only motivate a separately preregistered successor.

Complete selection unlocks four untouched interior mixed-proportion fixtures:

```text
id          L      W      U      H      F      M
mixed_a     0.950  1.050  0.500  1.050  0.950  1.050
mixed_b     1.050  0.950  0.530  0.950  1.050  0.950
mixed_c     0.950  0.950  0.530  1.050  1.050  1.050
mixed_d     1.050  1.050  0.500  0.950  0.950  0.950
```

Each held-out fixture runs three fixed repetitions. R1 is unperturbed. R2 is
seed `15302`, `0.0007 m` vertical clearance, `+0.003 rad` yaw, initial linear
velocity `(0.002, 0.0, 0.001) m/s`, torso angular velocity
`(0.002, 0.0, 0.001) rad/s`, and `+1` gait tick. R3 is seed `15303`,
`0.0014 m` clearance, `-0.006 rad` yaw, linear velocity
`(0.004, 0.0, -0.002) m/s`, angular velocity
`(0.003, -0.002, 0.002) rad/s`, and `-2` gait ticks.

Held-out validation requires `12/12` fresh private worlds and `300/300`
assertions. Each morphology's parameter, fixture, static-screen, controller,
and threshold digests must be stable across R1-R3. All campaign reports use one
formula-complete policy digest and retain formal acceptance, encyclopedia
admission, and automatic creature guidance as false.

Before any G3-GP1 world opens, implementation must:

- add the fail-closed morphology compiler and exact static screen;
- add no-world tests for reference identity, every formula, envelope rejection,
  tampered receipts, and zero-world failure behavior;
- publish the isolated campaign program, `25` assertions per cell, runner
  schema, source scope, and deterministic no-world policy receipt;
- prove by no-world receipt identity that the reference cell requests the
  authoritative GS3 fixture, controller, and numerical threshold values, whose
  already-recorded `s = 1.000` physical metrics remain the
  backward-compatibility baseline;
- clear formatting, lint, runner parsing, and the complete BR14A family from a
  clean immutable source; and
- preserve hidden, private-profiled, mutex-serialized, process-contained Godot
  execution with no manual worker termination.

#### G3-GP1 pre-physics implementation result — 2026-07-26

Every preregistered pre-physics implementation gate cleared before any
G3-GP1 world was opened. The exact clean implementation source is:

```text
555bb761bfdeb5112dbe465b08a989dc45555822
```

The implementation adds the fail-closed proportion compiler and static screen,
the 25-assertion campaign program, the immutable-snapshot campaign runner, and
one explicit accepted threshold-policy ID. That ID addition changes no default
threshold, controller, fixture, or walking behavior. `gdformat --check`,
`gdlint`, the PowerShell parser, and `git diff --check` all cleared.

The exact-source no-world compiler and identity contract is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp1_compiler_official_555bb76\
  20260726T124757546\report.json
sha256:457b5a34dbcc71f38f595025209b090b05ef436b4f6481a3a06e346c23a84a1d
1/1 program, 19/19 assertions
```

It proves the exact 13-cell selection and four-cell held-out grids, reference
fixture identity, the pinned GS3 unit controller digest, reference numerical
threshold identity, every generator formula, invariant reach and mass totals,
all 17 static screens and three distinct receipt families, envelope and
nonfinite rejection, exact-bundle verification, tamper rejection, and zero
claim authority. The exact floor-tangency calculation uses the original
64-bit scalar spec rather than a 32-bit `Vector3` round trip, preserving the
preregistered `1e-9 m` tolerance.

The deterministic formula-complete policy receipt is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp1_policy_official_555bb76\
  20260726T124841983\transcript.log
policy_digest:
  sha256:efed6bd9c26b9f00e6cf23f8f51a1c70b2d0d644c7228fa08def73f69bb67387
transcript_sha256:
  sha256:f581276403ac73d67bc14f4455dd2dcc47211a3b034bbba8976780edbe23620f
engine_log_sha256:
  sha256:a96bc221aa1313ca1f01594804923a434c7b44c79650f5bb8801f87cdc0acfcd
2/2 assertions
```

The process was hidden, headless, private-profiled, process-contained, and
completed with zero engine errors, timeout, kill, or open containment tree.

Finally, the complete repository-default BR14A family cleared from a clean
detached worktree at the exact implementation commit:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_pre_g3_gp1_official_555bb76\
  20260726T124903738\report.json
sha256:d742680e6b44af3963907ae67f251d699fc7b770e773e71fc2782f0ca25e2dc9
30/30 programs, 488/488 assertions
```

The aggregate includes the strengthened `14/14` BR14A.9 controller/clock
contract, the new `19/19` no-world morphology compiler, and the new campaign
program's `1/1` no-argument guard. It records zero timeouts, killed or open
process trees, nonzero exits, missing exit markers, malformed process windows,
missing or unreadable logs, malformed footers, engine errors, unexpected
errors, or abandoned mutex acquisition.

These receipts unlock only the preregistered 13-cell selection. The four mixed
held-out fixtures remain unopened until all 13 selection worlds pass and the
selection report independently clears its source, digest, walking, engine, and
containment audit.

#### G3-GP1 selection result: rejected

The complete selection ran from immutable byte-identical snapshots of exact
clean source `555bb761bfdeb5112dbe465b08a989dc45555822`:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp1_selection_official_555bb76\
  20260726T133117791\report.json
sha256:9d56d3a7f2d745c277a160c5869e04e19006da27f03cbc938f60f58c7218116c
10/13 walking worlds
316/325 assertions
```

The reference and both torso-length, torso-width, and hip-span endpoints
walked. The `U = 0.550` upper-share endpoint, `F = 1.100` foot-radius endpoint,
and `M = 0.900` front-mass endpoint also walked. Each of those ten cells passed
all `25/25` assertions.

Three endpoint worlds returned complete, contained physical summaries but
failed the walking predicate:

```text
cell                  result   exact failed prerequisite
upper_share_0p480     22/25    maximum anchor error
foot_radius_0p900     22/25    maximum anchor error
front_mass_1p100      22/25    exact contact-progression receipt
```

For `U = 0.480`, maximum anchor separation was `0.024834435 m` against the
fixture-derived `0.023333333 m` maximum, an excess of `0.001501102 m`. For
`F = 0.900`, it was `0.029543677 m` against `0.025000000 m`, an excess of
`0.004543677 m`. Both cells otherwise completed their required contact
progression, movement, recovery, and angular gates. Their failure is not a
reason to weaken the normalized anchor rule.

The `M = 1.100` cell passed its movement and structural measurements, ended
with four-foot support, and recorded at least two contact cycles per limb. Its
exact contact-progression assertion nevertheless failed, meaning at least one
required evidence-advance or zero-timeout receipt was not complete. It
therefore remains nonwalking under the published predicate.

The report used one exact policy digest, one fixed controller digest, and 13
distinct parameter, fixture, and static-screen digests. All 13 static screens
passed. Every transcript and engine-log hash matches its report. There were
zero engine errors, timeouts, killed or open process trees, dirty scoped
sources, or abandoned mutex acquisitions. The three nonzero process exits are
the expected fail-closed exits from those three assertion failures.

G3-GP1 is rejected. Its four preregistered mixed held-out cells were never
opened and contribute no evidence. The ten passing endpoint observations are
retained as development data but cannot be combined into a G3 acceptance
claim. A successor must be separately preregistered and must reproduce its own
complete selection rather than inheriting GP1 passes.

The next candidate is a deliberately data-informed G3-GP2 confirmation. It may
narrow the three failed sides while retaining the successful endpoints, but it
may not weaken any walking or structural threshold, silently adapt the
controller per shape, or describe its selection as independent exploration.

#### Preregistered G3-GP2 narrower fixed-controller confirmation

G3-GP2 is a data-informed successor to the rejected GP1 campaign. It is not
independent exploration: the GP1 outcomes directly motivate narrowing the
lower upper-share side, lower foot-radius side, and upper front-mass side.
GP2 keeps the exact GP1 morphology formulas, static screen, unit-scale GS3
controller, perturbations, dimensionless thresholds, walking predicate,
25-assertion cell contract, hidden process isolation, and nonclaims.

No G3-GP2 physics cell was opened before this policy was fixed.

The ordered selection cells are:

```text
id                         L      W      U        H      F      M
gp2_reference              1.000  1.000  18 / 35  1.000  1.000  1.000
gp2_torso_length_0p900     0.900  1.000  18 / 35  1.000  1.000  1.000
gp2_torso_length_1p100     1.100  1.000  18 / 35  1.000  1.000  1.000
gp2_torso_width_0p900      1.000  0.900  18 / 35  1.000  1.000  1.000
gp2_torso_width_1p100      1.000  1.100  18 / 35  1.000  1.000  1.000
gp2_upper_share_0p500      1.000  1.000  0.500    1.000  1.000  1.000
gp2_upper_share_0p550      1.000  1.000  0.550    1.000  1.000  1.000
gp2_hip_span_0p900         1.000  1.000  18 / 35  0.900  1.000  1.000
gp2_hip_span_1p100         1.000  1.000  18 / 35  1.100  1.000  1.000
gp2_foot_radius_0p975      1.000  1.000  18 / 35  1.000  0.975  1.000
gp2_foot_radius_1p100      1.000  1.000  18 / 35  1.000  1.100  1.000
gp2_front_mass_0p900       1.000  1.000  18 / 35  1.000  1.000  0.900
gp2_front_mass_1p050       1.000  1.000  18 / 35  1.000  1.000  1.050
```

The reference and nine retained endpoint values have already been observed
walking in GP1, but GP2 inherits none of those results: all 13 cells must run
again in fresh private worlds from one exact clean GP2 source. The new
`U = 0.500`, `F = 0.975`, and `M = 1.050` endpoints have not been opened.
Selection requires `13/13` walking worlds and `325/325` assertions. Any failure
rejects GP2 and leaves every GP2 held-out cell unopened.

Complete selection unlocks four new mixed-proportion held-outs:

```text
id             L      W      U      H      F       M
gp2_mixed_a    0.950  1.050  0.510  1.050  0.9875  1.025
gp2_mixed_b    1.050  0.950  0.540  0.950  1.0750  0.950
gp2_mixed_c    0.950  0.950  0.540  1.050  1.0750  1.025
gp2_mixed_d    1.050  1.050  0.510  0.950  0.9875  0.950
```

None of these four exact parameter combinations was opened by GP1. Each uses
the same three fixed repetitions: unperturbed R1, seed-`15302` R2, and
seed-`15303` R3 with the already-published clearances, yaw, velocities, and
phase offsets. Validation requires `12/12` fresh private worlds and `300/300`
assertions. Within each morphology, parameter, fixture, static-screen,
controller, and threshold digests must remain stable across R1-R3.

Before any GP2 world opens, implementation must:

- add the exact GP2 grids and campaign ID without changing GP1's retained
  source or report;
- prove all 17 GP2 parameter, fixture, and static-screen receipts no-world;
- prove the controller remains the pinned
  `sha256:9c6d7962e81da4d1831ac0a99999db46cd87ce3271600e0f8bb5a72beaed4ef6`;
- seal a distinct formula-complete GP2 policy digest;
- clear formatting, lint, runner parsing, and the complete BR14A family from
  one clean exact source; and
- document and push those preflight receipts before selection.

#### G3-GP2 pre-physics implementation result — 2026-07-26

Every preregistered GP2 pre-physics gate cleared before any GP2 morphology
world was opened. The exact clean implementation source is:

```text
0d7d6bb6a299cd2ebb623a81843cd0061f3e1ee9
```

The implementation adds the exact GP2 campaign grids and fail-closed campaign
lookup while retaining the old three-argument GP1 reproduction interface.
Every physical result line now includes campaign identity, and the runner
requires that identity to match its requested campaign. The GP1 no-world
policy receipt still reproduces its original exact digest
`sha256:efed6bd9c26b9f00e6cf23f8f51a1c70b2d0d644c7228fa08def73f69bb67387`.
`gdformat`, `gdlint`, the PowerShell parser, and `git diff --check` all
cleared.

The exact-source no-world compiler report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp2_compiler_official_0d7d6bb\
  20260726T135128652\report.json
sha256:3df38984e9e1c0fadae8da63bb4f25206ae519530c1d2710bef5c96770882c43
1/1 program, 24/24 assertions
```

Its five new GP2 assertions prove the exact 13-cell selection and four-cell
held-out grids, compilation of all 17 cells, every unchanged generator,
reach, and mass invariant, every unchanged static construction screen,
distinct parameter/fixture/static receipts, and exact GS3 unit identity for
the GP2 reference. The earlier 19 GP1 compiler assertions remain intact.

The distinct formula-complete GP2 policy receipt is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp2_policy_official_0d7d6bb\
  20260726T135154766\transcript.log
policy_digest:
  sha256:9eb5800e410cb4dad7c416da24642c51df0b244a1a0925b83736ff4b053c2562
transcript_sha256:
  sha256:9c3b5f7206055c6a35284c3439ccb142fff61066910afb3171495d201de39161
engine_log_sha256:
  sha256:67a82e048dff8e56b181af74acc0a0775a298697dd283249d7360a61229ab8b2
3/3 assertions
```

The hidden, headless, private-profiled policy worker exited zero, timed out
zero times, killed no process tree, left no open containment tree, and emitted
no engine error.

The first full-family attempt used a `300 s` per-program ceiling rather than
the previously proven `600 s` ceiling. BR14A.4R reached only two of its three
seeds before that shorter deadline. Its `29/30` partial report at
`<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_pre_g3_gp2_official_0d7d6bb\20260726T135213322\report.json`
(`sha256:f780f59d59b7dd14c4118020164a2c8cb2134b513ec3b157979bfea24a57149d`)
does not count as regression evidence. The timeout tree closed under the
bounded runner, and no partial program was reused.

The entire family was then rerun from scratch at the previously established
`600 s` ceiling from the same clean detached exact source:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_pre_g3_gp2_official_retry600_0d7d6bb\
  20260726T143023506\report.json
sha256:fb923dad89d68cd34cf5cc9dccf5522a2f9b857c57fcbdeecb1d776ce77134d8
30/30 programs, 493/493 assertions
```

The aggregate records zero timeouts, killed or open process trees, nonzero
exits, missing exit markers, malformed process windows, missing or unreadable
logs, malformed footers, failed assertions, engine errors, unexpected errors,
or abandoned mutex acquisition. The extra five assertions relative to the
GP1 preflight are exactly the new GP2 no-world compiler contract.

These receipts unlock only the preregistered 13-cell GP2 selection. No GP2
physical morphology has yet run, and all four GP2 mixed held-outs remain
sealed unless every selection cell passes.

#### G3-GP2 selection result: rejected

The first GP2 selection invocation opened all 13 preregistered worlds from
immutable snapshots of exact clean implementation source
`0d7d6bb6a299cd2ebb623a81843cd0061f3e1ee9`. Eleven cells passed. The
`gp2_upper_share_0p500` and `gp2_foot_radius_0p975` cells each returned
`22/25` and did not satisfy the walking predicate.

After all 13 worker invocations returned, a PowerShell report-finalization bug
treated the inline GP2 schema conditional as an external `if` command. The
original run therefore has no aggregate campaign report and is not presented
as if it had one. Its 13 transcript and engine-log pairs remain at:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp2_selection_official_0d7d6bb\
  20260726T151244744\
```

An explicitly post-hoc audit—not a replacement campaign report—hashes the
original source snapshot and artifacts:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp2_selection_official_0d7d6bb\
  20260726T151244744\posthoc_audit.json
sha256:d8fc7d5a174de7ef0fb5f0c6da1e9f04d9db18b64f344377ea6999b19af2f5d7
13/13 result receipts, 319/325 assertions, 11/13 walking cells
```

All 13 snapshotted source files match exact source `0d7d6bb`, every original
cell has one footer and one result receipt, and no original transcript or
engine log contains an engine error.

The six-line reporter-only correction was committed and pushed as
`303f8ea5c6b8d967557aba909d4ba4900ff05be3`. It changes neither the physical
test nor any morphology, fixture, controller, clock, threshold, perturbation,
or predicate. The same already-opened 13 cells were then rerun from a clean
detached source at that commit as a labeled reproduction, not as a new
selection opportunity:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp2_selection_reproduction_303f8ea\
  20260726T152049402\report.json
sha256:1a6e99d9aeb9a2afd1e914444c4e0571b5a4d7c50593efc7135215b5f4c54ba6
11/13 walking worlds
319/325 assertions
```

Every reproduction result receipt is byte-identical to its original-run
receipt. The only source-snapshot differences are this documentation and the
report-finalization script. The complete reproduction report records one
consistent GP2 policy digest, one fixed controller digest, 13 distinct
parameter/fixture/static-screen digest families, zero engine errors, timeouts,
killed or open process trees, dirty scoped sources, or abandoned mutex
acquisitions. Its two nonzero exits are the two fail-closed assertion exits.

The failed cells retained complete world, controller, perturbation, topology,
contact-progression, finite-measurement, and nonclaim receipts. Their directly
reported bound violations are:

```text
cell                         result   directly reported failed bound
gp2_upper_share_0p500        22/25    |final lateral| 0.129345 m > 0.100000 m
gp2_foot_radius_0p975        22/25    anchor 0.025010327 m > 0.025000000 m
```

The upper-share cell exceeded the final-lateral envelope by `0.029345 m`. The
foot-radius cell exceeded the unchanged anchor envelope by `0.000010327 m`;
its small numerical margin is still a real fail and is not grounds to weaken
the published threshold. The new `gp2_front_mass_1p050` cell passed `25/25`,
as did the reference and every retained torso-length, torso-width, upper
`U = 0.550`, hip-span, upper-foot-radius, and lower-front-mass endpoint.

G3-GP2 is rejected. Its four mixed held-out cells were never opened and
contribute no evidence. A successor may use these outcomes as labeled
development data, but it must publish a new policy before new evidence worlds.
The preferred next development question is whether one global controller
improvement can satisfy both structural and path bounds without weakening a
threshold or adapting per morphology; simply narrowing endpoints repeatedly
would produce a less useful walking system.

A complete GP2 result would establish a bounded, asymmetric nonuniform
proportion envelope under one fixed controller, including held-out mixed-shape
evidence. It would still not establish arbitrary quadrupeds or a generated
family across the full parameter volume; those remain G4.

#### Preregistered G3-GP3 global-controller confirmation

G3-GP3 is a data-informed controller successor to the rejected GP2 campaign.
It does not narrow the morphology envelope again and does not weaken any
threshold. Instead, it asks whether one shape-independent path-and-actuator
policy can cover the exact 13 GP2 one-axis shapes and then transfer to the four
still-unopened mixed shapes.

No GP3 evidence world was opened before this policy was fixed. Development
probes are disclosed below and are ineligible evidence because their scoped
source was deliberately dirty.

The fixed GP3 controller changes exactly two numerical values relative to GP2:

```text
path cross_track_heading_gain_rad_per_m   0.750  (GP2: 0.500)
global actuator_impulse_scale             1.015  (GP2: 1.000)
```

The final actuator receipt must use policy ID
`g3_gp3_global_actuator_margin_v1`, set
`mass_adaptive_actuator_enabled = true`, and apply the same `1.015` multiplier
to every hip and knee motor in every morphology. That realizes
`0.055825 N m s` hip and `0.456750 N m s` knee maximum impulses. This is an
explicit `1.5%` increase in joint-only actuator authority, not a fixture-shape
change and not a per-shape adaptation. It therefore defines a new controller
policy and cannot retroactively rescue GP2.

Every other controller value is unchanged:

```text
motor direction sign                       -1
knee motor impulse scale                   10
knee flexion scale                         1.75
gait order                                 lateral
swing ticks                                72
contact-clearance assist                   0.40 rad, all limbs
contact-gated progression                  enabled
maximum gate hold                          96 ticks
maximum phase skew                         12 ticks
legacy lateral stride steering gain        0
yaw-error stride gain                      1.0
steering update interval                   90 ticks
maximum desired heading error              0.25 rad
maximum steering fraction                  0.20
clock                                      exact unit GS3 clock
```

The selection repeats the complete GP2 numerical grid under new GP3 cell IDs:

```text
id                         L      W      U        H      F      M
gp3_reference              1.000  1.000  18 / 35  1.000  1.000  1.000
gp3_torso_length_0p900     0.900  1.000  18 / 35  1.000  1.000  1.000
gp3_torso_length_1p100     1.100  1.000  18 / 35  1.000  1.000  1.000
gp3_torso_width_0p900      1.000  0.900  18 / 35  1.000  1.000  1.000
gp3_torso_width_1p100      1.000  1.100  18 / 35  1.000  1.000  1.000
gp3_upper_share_0p500      1.000  1.000  0.500    1.000  1.000  1.000
gp3_upper_share_0p550      1.000  1.000  0.550    1.000  1.000  1.000
gp3_hip_span_0p900         1.000  1.000  18 / 35  0.900  1.000  1.000
gp3_hip_span_1p100         1.000  1.000  18 / 35  1.100  1.000  1.000
gp3_foot_radius_0p975      1.000  1.000  18 / 35  1.000  0.975  1.000
gp3_foot_radius_1p100      1.000  1.000  18 / 35  1.000  1.100  1.000
gp3_front_mass_0p900       1.000  1.000  18 / 35  1.000  1.000  0.900
gp3_front_mass_1p050       1.000  1.000  18 / 35  1.000  1.000  1.050
```

Selection is one unperturbed private world per cell. It requires `13/13`
walking worlds and `325/325` assertions from one exact clean source. A single
failure rejects GP3 and leaves all mixed held-outs unopened.

The four GP3 held-outs retain the exact still-unopened GP2 combinations under
new campaign IDs:

```text
id             L      W      U      H      F       M
gp3_mixed_a    0.950  1.050  0.510  1.050  0.9875  1.025
gp3_mixed_b    1.050  0.950  0.540  0.950  1.0750  0.950
gp3_mixed_c    0.950  0.950  0.540  1.050  1.0750  1.025
gp3_mixed_d    1.050  1.050  0.510  0.950  0.9875  0.950
```

Each held-out must pass the same unperturbed R1, seed-`15302` R2, and
seed-`15303` R3 perturbations already fixed for GP1 and GP2. Validation
requires `12/12` private worlds and `300/300` assertions. Parameter, fixture,
static-screen, controller, and threshold digests must remain stable across
R1-R3 within each morphology; the one controller digest must be identical
across all morphologies and repetitions.

The controller choice is informed by an explicit dirty-source development
screen:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_global_controller_dev_full13_cross_0p75_impulse_1p015\
  20260726T160304999\report.json
sha256:69a7b4a266e5e54e08c6a61eb1ce803fdf8b80f622526e1c6737b6750d160738
13/13 development walking cells, 325/325 assertions
source_scope_clean=false
development controller digest:
  sha256:f689431795a52aa135f259c8fe8fe4242593b99411354cf1115cb3a10debb603
```

The final GP3 digest will differ because the final actuator policy ID is
preregistered above instead of retaining the development-only label. That
receipt-only label change must not alter any realized physics value.

The smaller `1.010` actuator multiplier was tested and rejected before this
freeze:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_global_controller_dev_stress7_cross_0p75_impulse_1p01\
  20260726T160854128\report.json
sha256:ed15a3e5f97875e042d3c6ee0534a12c0f4b4f488dd2851158d24ee91b4e821f
5/7 stress cells, 169/175 assertions
```

Its `W = 1.100` and `U = 0.500` cells failed, so `1.010` cannot be promoted.
No larger multiplier is eligible under this GP3 policy; `1.015` is the one
fixed value.

Before GP3 selection opens, implementation must:

- add exact GP3 grids and fail-closed campaign lookup without changing GP1 or
  GP2 reproduction;
- publish the exact final controller receipt and distinct GP3 policy digest;
- prove all 17 GP3 cells compile and clear unchanged static screens no-world;
- prove the `1.015` scale is uniform across all eight joint motors and realizes
  exactly `0.055825 / 0.456750 N m s`;
- clear formatting, lint, PowerShell parsing, and the complete BR14A family
  from one clean exact source; and
- document, commit, and push those preflight receipts before selection.

##### GP3 implementation and clean preflight result

GP3 was implemented, committed, and pushed at exact source:

```text
3e4807bbe808d4a15d77ebd076bd725e07b04bbc
```

The implementation preserves the GP1 and GP2 controller branches and adds
fail-closed GP3 lookup, the exact 13 selection and four held-out IDs, a distinct
report schema, and the one fixed path-and-actuator configuration. Formatting,
lint, PowerShell parsing, `git diff --check`, and exact detached-worktree source
cleanliness all passed.

The clean no-world compiler receipt is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp3_compiler_official_3e4807b\
  20260726T162439867\report.json
sha256:a941c9d561c50c415872c7025d1e8b8ebfd8d0c288552d238f7e4c0ef01eb588
1/1 program, 29/29 assertions
```

It proves all 17 GP3 cells compile, preserve the generator/reach/mass
invariants, clear the unchanged static screen, and carry distinct parameter,
fixture, and static-screen receipts. Godot's canonical serializer seals the
final global controller as:

```text
controller sha256:
  sha256:7e505e23b8c0967bf2702de3aa711986deca9cc5862284e6646e9a9bc7a61172
realized hip maximum impulse:   0.055825000 N m s
realized knee maximum impulse:  0.456750000 N m s
```

All three exact-source no-world policy receipts passed in one clean detached
worktree:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp3_policy_official_3e4807b\
  20260726T162531164

G3-GP1 policy:
  sha256:efed6bd9c26b9f00e6cf23f8f51a1c70b2d0d644c7228fa08def73f69bb67387
  transcript sha256:
    sha256:b245262d4f8f1c4540fc0a9d6fbc5d280192d719d93fb794a8faec392c70bf15
G3-GP2 policy:
  sha256:9eb5800e410cb4dad7c416da24642c51df0b244a1a0925b83736ff4b053c2562
  transcript sha256:
    sha256:9c3b5f7206055c6a35284c3439ccb142fff61066910afb3171495d201de39161
G3-GP3 policy:
  sha256:3d9871a42c5ff470a7108ad21ded4fdcb2f19803a9fab3603cbf894ec5371ad0
  transcript sha256:
    sha256:f4f87170b1543c740b76f83144a32f9b262f994b0d966692da3713a1afcca0f3
```

GP1 and GP2 policy digests are unchanged, so the new branch does not rewrite
their campaign identities.

The first complete-family invocation had a `900`-second outer wrapper and was
cut off by that wrapper after several programs had passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_pre_g3_gp3_official_3e4807b\
  20260726T162614024
```

It produced no final `report.json`, left no Godot worker, and released the
suite mutex without abandonment. It is incomplete and counts as no evidence.
The per-test ceiling was not the cause.

A wholly fresh rerun with a one-hour outer wrapper, the same `600`-second
per-test ceiling, and the same exact clean source passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_pre_g3_gp3_official_retry3600_3e4807b\
  20260726T164202555\report.json
sha256:2ce078e4f2d2aeeeda4fb50e03eac14342deafdcc144638b614deafd83ccb302
30/30 programs, 498/498 assertions
```

The audited report has zero nonzero exits, timeouts, killed or open process
trees, missing exit markers, invalid test windows, footer failures, engine
errors, missing logs, missing transcripts, or assertion failures. The suite
mutex was acquired and not abandoned, and the exact detached source was clean
after the run.

These receipts complete GP3 preflight only. No GP3 selection or held-out
walking evidence is included in them.

##### GP3 selection and held-out result

GP3 selection ran from exact pushed source:

```text
12b3155060b2a22d5419afe8c345f130e1036413
```

The complete selection passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp3_selection_official_12b3155\
  20260726T172733385\report.json
sha256:c7e91033383894c0a11980d8f219cbd6e6b6b4bc4c79d4c88b0daf475ba229e3
13/13 walking worlds, 325/325 assertions
selection_eligible=true
```

The report uses an immutable clean-source snapshot, one fixed
`sha256:7e505e...61172` controller, and one fixed
`sha256:3d9871...71ad0` policy. All 13 parameter, fixture, and static-screen
receipts are distinct. There are no timeouts, killed or open process trees,
engine errors, dirty scoped files, or mutex anomalies.

Selection therefore unlocked the four previously unopened mixed
morphologies. Their three fixed repetitions produced:

```text
R1:
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp3_heldout_r1_official_12b3155\
  20260726T173318305\report.json
sha256:0c57ac99a04b6dd76e433b1a1bfdfe2e1cf6f21ed2b78a7870c3a0ab8e3889a3
4/4 walking worlds, 100/100 assertions

R2:
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp3_heldout_r2_official_12b3155\
  20260726T173519367\report.json
sha256:34050a405f3aa201c65a8e75b10a31435183fc4b8c3ef6d8c4c8a7af7adaec21
3/4 walking worlds, 97/100 assertions

R3:
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp3_heldout_r3_official_12b3155\
  20260726T173751617\report.json
sha256:a923cec6389117551428a7137f5008cb127e0e60327f4d12c9312f5dae57a6b5
3/4 walking worlds, 97/100 assertions
```

Mixed A, B, and C pass all three repetitions. Mixed D passes R1 but fails R2
and R3 for two different preregistered structural/movement limits:

```text
gp3_mixed_d R2:
  final forward displacement              1.034181 m
  absolute final lateral displacement     0.045162 m
  maximum anchor error                    0.024793027 m
  morphology-derived anchor limit         0.024791667 m
  excess                                  0.000001360 m

gp3_mixed_d R3:
  final forward displacement              1.015248 m
  absolute final lateral displacement     0.112935 m
  morphology-derived lateral limit        0.105000 m
  excess                                  0.007935 m
  maximum anchor error                    0.024414748 m
```

In each failed world, the three failed assertions are the underlying
metric/gate failure plus its walking-summary cascades. Both worlds retain
complete result receipts, close their process trees, report no engine error or
timeout, and preserve the exact controller, policy, fixture, static-screen,
and threshold digests. The R2 miss is numerically tiny but remains a failure;
the threshold is not relaxed after observation.

The combined GP3 accounting is:

```text
selection plus held-outs: 23/25 walking worlds, 619/625 assertions
held-outs only:           10/12 walking worlds, 294/300 assertions
nonzero exits:            2 assertion exits
timeouts / engine errors / open trees: 0 / 0 / 0
```

All four held-out morphologies retain one parameter, fixture, static-screen,
threshold, and controller digest across R1-R3. The result is therefore a
physical GP3 rejection, not a harness or receipt failure.

GP3 establishes a reproducible complete `13/13` one-axis selection and strong
positive transfer for three mixed morphologies, but it fails the fixed
`12/12` held-out rule. It does not establish the complete bounded nonuniform
envelope and must not be called morphology-generalized walking. Any successor
must be a new preregistered controller campaign; it may not retroactively
change GP3's thresholds, cells, or outcome.

A complete GP3 result would establish a bounded asymmetric nonuniform
proportion envelope under one globally strengthened controller, including
fresh mixed-shape evidence. It would not establish arbitrary quadrupeds,
continuous coverage of the six-dimensional parameter volume, another limb
count, or automatic creature guidance.

#### Rejected post-GP3 GP4 development families

GP3 left two narrow but physically distinct mixed-D failures: R2 exceeded its
anchor limit by `0.000001360 m`, while R3 exceeded its lateral limit by
`0.007935 m`. A deliberately dirty detached worktree rooted at exact source
`404f534691491f9d49581191415483f61e915daf` explored possible global GP4
changes. These runs were development only:

- the scoped source was intentionally dirty;
- no GP4 policy, selection grid, held-out grid, or decision rule was
  preregistered;
- runner source-clean enforcement was disabled while retaining process,
  engine, digest, assertion, and walking checks; and
- none of the reports below is admissible GP4 evidence.

The first family varied GP3's global cross-track gain and uniform actuator
scale. Individual settings could pass one or both mixed-D failures, but the
response was phase-sensitive and non-monotonic. For example, gain `0.70` with
actuator scale `1.020` passed R3 but failed R2, while gain `0.75` with scale
`1.020` passed R2 and restored R3's lateral margin but exceeded R3's anchor
limit. No fixed scalar pair established an overlap.

The second family capped every contact-loaded swing-knee target velocity.
`3.25 rad/s` passed mixed-D R2 and R3 but regressed two selection cells:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_full25_velocity_cap_3p25_selection\
  20260726T175839585\report.json
sha256:a2d3eca56d9e0b089c2af503f3cb9446f455850a97f88db3a0dfb4a8b5fc6a25
11/13 walking worlds, 319/325 assertions
```

The `3.28125 rad/s` cap also passed both mixed-D failures and the two
previously regressed selection cells in a targeted screen, but a complete
selection moved the failures to reference lateral drift and
`foot_radius=1.100` contact progression:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_full25_velocity_cap_3p28125_selection\
  20260726T181049321\report.json
sha256:9e3d00a257a4bb4193804f540783bb69a63b1b057e1aa422a0aaef4aa97e3ef1
11/13 walking worlds, 319/325 assertions
```

This rejects a whole-swing fixed cap as a global GP4 structure. It exchanges
one phase failure for another instead of increasing robustness.

A narrower family preserved normal early swing and capped only a late
contact-loaded knee. A `2.5 rad/s` cap beginning at phase tick `54` passed
mixed-D R2 and both known selection regressions, but R3 exceeded its anchor
limit:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_critical_late_cap_2p5_phase54_mixed_d_r3\
  20260726T182058870\report.json
sha256:ba9ba97427f279bfdda9e8349fcf42a03df4c636a00fec75ff482939085f920e
22/25 assertions
maximum anchor error 0.025032891 m
```

Moving the start to phase tick `60` and softening the cap to `3.0 rad/s`
passed R3 but moved a `0.000242871 m` anchor excess into R2:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_critical_final_sixth_cap_3p0_mixed_d_r2\
  20260726T182627208\report.json
sha256:5858252c023913280ae1512a73377df78555db00d1cc0e65e13394e39b4c6387
22/25 assertions
maximum anchor error 0.025034538 m
```

The maximum witness was a loaded front-right swing knee at local phase tick
`44`, before the late cap. A one-tick full-speed release-gate notch and
additional phase-window changes did not produce a shared passing result.

The third family replaced clock guesses with direct anchor-error feedback. A
hard guard activated for a loaded swing knee at `90%` of its
morphology-derived anchor limit and reduced its target-speed ceiling to
`2.5 rad/s`. It passed the four critical development worlds, including both
mixed-D failures, but the complete selection regressed
`torso_length=1.100` and `foot_radius=0.975` on lateral drift:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_anchor_guard_0p90_2p5_full_selection13\
  20260726T183459387\report.json
sha256:b08e30db9805cb8c3dcfba8991c3e742386234537568e00d1514b9a6d0407875
11/13 walking worlds, 319/325 assertions
```

A continuous barrier retained full `3.5 rad/s` authority at the `90%`
activation boundary and tapered smoothly toward `2.5 rad/s` at the anchor
limit. It restored those two cells and retained both mixed-D fixes in a
targeted `4/4`, `100/100` screen, but a fresh complete selection exposed
three other regressions:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_continuous_anchor_guard_0p90_2p5_full_selection13\
  20260726T184517689\report.json
sha256:af02a74e3043dbf6cdb5e3f8ac7bf6ab945698e9acfbc38e9fdf2cce586cf72e
10/13 walking worlds, 316/325 assertions

torso_width=0.900:
  maximum anchor error 0.026269974 m
upper_share=0.500:
  maximum anchor error 0.024529979 m, above its shorter-segment limit
hip_span=0.900:
  incomplete contact progression
```

This rejects both binary and continuous knee-target-speed guards. Directly
modulating target-speed magnitude changes release and recontact timing enough
to move failures around the morphology grid, even when every targeted
development cell passes.

The fourth family replaced GP3's `90`-tick sample-and-hold path correction
with continuously filtered position/yaw feedback plus yaw-rate damping. With
both damping and filter time constant fixed at `0.25 s`, the two known mixed-D
failures passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_smooth_path_pd_0p25_mixed_d_r2\
  20260726T190519418\report.json
sha256:dba384a77472ef724f0a7b8533ab17d341effa86ed7f2b409df86dad063e39c2
25/25 assertions

<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_smooth_path_pd_0p25_mixed_d_r3\
  20260726T190554751\report.json
sha256:ef97ba3db0dda2dd3ffabe8411c5cd6930d31205835b8ee5c51ee2e3abb57a90
25/25 assertions
```

A sensitive four-cell selection screen then regressed
`upper_share=0.500` on lateral drift:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_smooth_path_pd_0p25_sensitive_selection4\
  20260726T190650081\report.json
sha256:b164bd80de2a1708a7f86ab6bdd5b4bb4ddc026e9be6bb5e51ba8143b9fdfe06
3/4 walking worlds, 97/100 assertions

upper_share=0.500:
  final forward displacement          0.956593 m
  absolute final lateral displacement 0.112319 m
  fixed lateral limit                 0.100000 m
```

Halving the filter time constant to `0.125 s` restored that cell but moved
mixed-D R2 beyond its anchor limit:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_smooth_path_pd_0p25_tau_0p125_mixed_d_r2\
  20260726T191134640\report.json
sha256:821bd754382e27890ba0bbf0c5a9b6ecd3c1aab843154b64217a7be48173c89e
22/25 assertions
maximum anchor error 0.025021777 m
```

The exact midpoint, `0.1875 s`, kept the reported displacement and structural
maxima inside their bounds but still lost a lower-level walking gate in
mixed-D R2. Phase-sampled filtering and phase-sampled yaw-rate damping also
lost walking gates in the sensitive upper-share cell. This rejects the whole
feedback family: continuous retiming, filtered sample transitions, and
yaw-rate augmentation do not preserve GP3's complete one-axis selection set.

Godot 4.7 documents `HingeJoint3D.PARAM_BIAS` as stronger positional
adherence, but also documents hinge bias, limit bias, softness, and relaxation
as GodotPhysics3D-only parameters. The campaign is pinned to Jolt Physics, so
that apparent constraint-stiffness control was rejected before physics rather
than treated as an effective Jolt receipt.

A fresh exact-`404f534` worktree then changed only Jolt's startup-read position
solver iterations. Eight steps reduced mixed-D R2 anchor error to
`0.020637795 m` but produced `0.171373 m` lateral drift:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_jolt_position_steps8_mixed_d_r2\
  20260726T185359165\report.json
sha256:a16376686c5df2628d8139a537537a437d6fc07409d92b9978fddf5d7b272f44
22/25 assertions
```

The only integer intermediate, seven steps, brought every reported normalized
movement, structural, contact-progression, recovery, and no-cheating gate
inside its limit:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_jolt_position_steps7_mixed_d_r2\
  20260726T185516770\report.json
sha256:93f5a9339364bc1f20112f0e9c1037a416b86736ace43b888b5eed88263e8fa2
23/25 assertions

<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_jolt_position_steps7_mixed_d_r3\
  20260726T192554701\report.json
sha256:fa87b9d5ba1d9583b0bc2ed27a3f73b21fac0458f15fda996302363d63418b6c
23/25 assertions
```

In both seven-step runs, the two failed assertions have one source: the
walker's internal `pinned_jolt_solver_settings` gate still hard-coded
`position_steps == 6`, followed by the aggregate walking cascade. The outer
development harness correctly received and asserted `position_steps == 7`.
Every non-pin walking gate was true. Representative mixed-D results were:

```text
R2:
  final forward displacement          1.000896 m
  absolute final lateral displacement 0.005000 m
  maximum anchor error                0.022339486 m

R3:
  final forward displacement          0.943526 m
  absolute final lateral displacement 0.092032 m
  maximum anchor error                0.022744684 m
```

Seven steps therefore remains a development candidate, not accepted evidence.
It may not be combined with GP3 post hoc, and the stale pin may not simply be
edited after those worlds. It requires a distinct preregistered campaign whose
policy fixes seven before any eligible world opens.

Across these development families, process containment remained closed and
no engine error or timeout explained a physical failure. The bounded
conclusion is that GP4 must not continue scalar bisection, fixed phase windows,
contact-loaded knee target-speed limiting, steering-feedback tuning, or
solver-iteration search. The sole retained candidate is the already observed
integer setting of seven position iterations, evaluated as a new solver policy
under the unchanged GP3 controller.

#### Preregistered G3-GP4 solver-policy confirmation

G3-GP4 is a data-informed solver-policy successor to rejected GP3. This
section fixes its complete decision before any eligible GP4 world opens.
Dirty development reports above motivated the policy but are not GP4
evidence.

The controller is byte-identical to GP3:

```text
controller sha256:
sha256:7e505e23b8c0967bf2702de3aa711986deca9cc5862284e6646e9a9bc7a61172

path steering:
cross-track heading gain       0.75 rad/m
yaw-error stride gain          1.00 /rad
update interval                90 ticks
maximum desired heading error  0.25 rad
maximum steering fraction      0.20

actuator policy:
policy id                      g3_gp3_global_actuator_margin_v1
global impulse scale           1.015
```

The only physical-policy change is the startup-read Jolt solver receipt:

```text
physics engine                 Jolt Physics
physics frequency              120 Hz
velocity iterations            20
position iterations            7
```

Implementation must parameterize the walker's expected solver receipt so
legacy callers continue to default exactly to `20/6`, while GP4 explicitly
requests and receives `20/7`. The normalized solver policy and its digest must
be compiled before world construction, included in the GP4 formula policy,
returned by the world summary, and checked against the realized project
settings. Unknown keys, wrong types, out-of-policy values, or disagreement
between requested and realized settings must fail closed.

GP4 reissues the complete GP3 numerical grid under fresh IDs. The 13 selection
cells are:

```text
gp4_reference
gp4_torso_length_0p900
gp4_torso_length_1p100
gp4_torso_width_0p900
gp4_torso_width_1p100
gp4_upper_share_0p500
gp4_upper_share_0p550
gp4_hip_span_0p900
gp4_hip_span_1p100
gp4_foot_radius_0p975
gp4_foot_radius_1p100
gp4_front_mass_0p900
gp4_front_mass_1p050
```

Their numeric parameter tuples, fixture formulas, static screens, clock,
thresholds, controller, and unperturbed selection conditions are exactly the
GP3 values. Selection is all-or-nothing: all `13/13` worlds and `325/325`
assertions must pass from one exact clean pushed source. Any selection failure
rejects GP4 and leaves held-outs unopened.

Only after complete selection may the runner open these four fresh held-outs:

```text
gp4_mixed_a  0.95  1.05  0.51  1.05  0.9875  1.025
gp4_mixed_b  1.05  0.95  0.54  0.95  1.0750  0.950
gp4_mixed_c  0.95  0.95  0.54  1.05  1.0750  1.025
gp4_mixed_d  1.05  1.05  0.51  0.95  0.9875  0.950
```

Each held-out runs the same three already fixed perturbations used by GP3.
Complete confirmation requires `12/12` walking worlds and `300/300`
assertions. Any held-out failure rejects GP4; thresholds, repetitions, solver
settings, and pass rules may not change after observation.

Before GP4 selection opens, implementation must pass no-world checks proving:

- all 17 GP4 cells compile and preserve the exact GP3 numerical formulas;
- every GP4 parameter, fixture, and static-screen receipt is distinct;
- the GP4 policy is distinct and fixes the unchanged controller plus the
  exact `20/7` solver receipt;
- legacy GP1-GP3 controller, policy, and default `20/6` receipts remain
  unchanged; and
- no-world invalid solver policies fail before physics.

A complete `25/25`, `625/625` GP4 result would establish the same bounded
asymmetric nonuniform quadruped envelope sought by GP3 under one globally
pinned controller and solver policy. It would not establish arbitrary
quadrupeds, continuous six-dimensional coverage, generated creatures, another
limb count, or automatic creature guidance.

##### GP4 implementation and selection result

The solver policy and fresh GP4 grid were implemented and pushed at:

```text
6e2b0a1bbd66b446b3ca1cdcbd2cc2a1e7e740d7
```

The walker now compiles an exact solver receipt before world construction.
Legacy callers default to Jolt `20/6`; GP4 explicitly requests `20/7`.
Unknown, missing, mistyped, unknown-policy, and relation-invalid receipts fail
with `world_build_count=0`. The realized startup settings must match the
compiled receipt before a fixture is built.

The clean no-world preflight passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_clean_preflight_6e2b0a1\
  20260726T193809398\report.json
sha256:d781db1d3469ccf668b7780eba8f0ccef2b2556ca3dc5a611d6fe04dcedfe59e
34/34 assertions
```

It compiled all 17 GP4 cells, proved their exact numerical identity to the GP3
grid aside from fresh IDs, retained the fixed GP3 controller digest, sealed
the distinct solver policy, and exercised fail-closed invalid receipts. The
separate locked dynamic-similarity compiler remained `14/14`.

The first selection invocation from `6e2b0a1` completed every physics world
but exposed a runner-only report bug: its campaign receipt regex ended at
`G3-GP3`, so all valid `G3-GP4` result lines were marked
`harness_passed=false`. That report is retained but is not the authoritative
selection result:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp4_selection_official_6e2b0a1\
  20260726T193846140\report.json
sha256:19ccab050119d96cfa37c6d33e956e47bee4189b57ad7561e0dc39add74bb56c
```

The parser was extended to the explicitly supported GP1-GP4 set, gained a
startup self-check, validated all 13 existing receipt lines, and was committed
without changing controller, fixture, policy, solver, thresholds, test
assertions, or physics:

```text
a48a47244cf3bc432d77b98b6493f5172ac5019b
```

The complete selection was then rerun from that exact clean pushed source:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp4_selection_official_a48a472\
  20260726T194543212\report.json
sha256:5f4aaae6b0101f66fb9694de0dbb00e9104cd0b8c8c3d2a77f6e9c15999e624a

10/13 walking worlds
316/325 assertions
selection_eligible=false
```

All ten passing worlds have `harness_passed=true`, `walking=true`, `25/25`
assertions, exact controller and solver receipts, clean scoped source,
closed process trees, and zero engine errors or timeouts. The three failures
are physical:

```text
gp4_torso_length_1p100:
  22/25 assertions
  final forward displacement          0.922000 m
  absolute final lateral displacement 0.034719 m
  maximum anchor error                0.020860728 m

gp4_upper_share_0p550:
  22/25 assertions
  final forward displacement          1.072345 m
  absolute final lateral displacement 0.110896 m
  fixed lateral limit                 0.100000 m
  excess                              0.010896 m

gp4_front_mass_1p050:
  22/25 assertions
  final forward displacement          1.032248 m
  absolute final lateral displacement 0.103191 m
  fixed lateral limit                 0.100000 m
  excess                              0.003191 m
```

The compact authoritative report does not serialize every per-limb metric. A
post-rejection dirty diagnostic replay identified the long-torso false gate
without changing the selection result:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp4_dev_failure_diag_torso_length_1p100\
  20260726T195307268\report.json
sha256:c5e231adff8050e39bf40abf93efe7aa623520fafe972f5eb95cc5535a07b569

front-right minimum cycle relocation  0.012824119 m
morphology-derived minimum            0.013200000 m
shortfall                             0.000375881 m
```

Every other long-torso walking gate was true, including solver identity,
contact progression, recovery, yaw, tilt, lateral drift, torso clearance,
anchor error, and hinge alignment. This diagnostic is explanatory only and is
not selection evidence.

GP4 is rejected by its preregistered all-or-nothing rule. All four GP4
held-outs across all three repetitions remain unopened. Seven Jolt position
iterations improve the two exposed mixed-D GP3 failures but regress two
one-axis lateral gates and one per-foot relocation gate, so the integer solver
family is closed rather than tuned further.

#### Preregistered G3-GP5 morphology-adaptive confirmation

A deliberately dirty development worktree rooted at exact source
`404f534691491f9d49581191415483f61e915daf` tested one structural successor:
retain GP3 exactly for one-axis morphologies and scale the previously explored
continuous anchor-error guard by a formula-derived multi-axis interaction
score. These reports are development only and are not GP5 evidence.

The development candidate passed the complete one-axis grid:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp5_dev_adaptive_interaction_guard_selection13\
  20260726T200639266\report.json
sha256:8e5b5f3d88605dbb006a47507f024ba46d54e510b28c64f12f9343f220aa8060
13/13 walking worlds, 325/325 assertions
```

It also passed all four mixed morphologies under all three fixed
perturbations:

```text
R1:
<evidence-root>\temp-roots-2026-07-28\sporespore_gp5_dev_adaptive_interaction_guard_heldout_r1\
  20260726T200453334\report.json
sha256:59e0acb97a1064c0f886e5ae7046a336f583549586b00278b9c03772ea491d10
4/4 walking worlds, 100/100 assertions

R2:
<evidence-root>\temp-roots-2026-07-28\sporespore_gp5_dev_adaptive_interaction_guard_heldout_r2\
  20260726T200125336\report.json
sha256:7722395a65adfef1f8860433fd663ac5cca51d147fe4f14a95d24a688fda72eb
4/4 walking worlds, 100/100 assertions

R3:
<evidence-root>\temp-roots-2026-07-28\sporespore_gp5_dev_adaptive_interaction_guard_heldout_r3\
  20260726T200310385\report.json
sha256:372588df61d2d0d591c5d91d3271b1878e17fe51728769fbfa49c72b91449652
4/4 walking worlds, 100/100 assertions
```

The combined dirty-development accounting is therefore `25/25` worlds and
`625/625` assertions with zero engine errors. This is sufficient to stop
development and preregister GP5, but grants no evidence or walking-system
claim by itself.

GP5 fixes the following morphology interaction formula. From the normalized
proportion receipt, define:

```text
dL = abs(torso_length_scale - 1.0) / 0.10
dW = abs(torso_width_scale - 1.0) / 0.10
dU = abs(upper_length_fraction - 18/35) / 0.05
dH = abs(hip_span_scale - 1.0) / 0.10
dF = abs(foot_radius_scale - 1.0) / 0.10
dM = abs(front_limb_mass_scale - 1.0) / 0.10

interaction_score = clamp(sum over every i < j of di*dj, 0.0, 1.0)
```

The formula contains no morphology ID, seed, repetition, observed result, or
pass/fail branch. Every one-axis selection shape has at most one nonzero
deviation and therefore exact score `0.0`. Each of the four fixed mixed shapes
has score `1.0`. Intermediate generated shapes may receive any continuous
score in `[0,1]`.

The base controller, engine, and thresholds remain GP3:

```text
path cross-track gain          0.75 rad/m
yaw-error stride gain          1.00 /rad
path update interval           90 ticks
actuator impulse scale         1.015
physics engine                 Jolt Physics
physics frequency              120 Hz
velocity / position iterations 20 / 6
```

The only new motor policy applies to a contact-loaded swing knee. Let:

```text
a = maximum morphology-derived anchor error
e = current joint-anchor error before the motor command
g = clamp(((e/a) - 0.90) / 0.10, 0.0, 1.0)
s = interaction_score

effective target-speed ceiling = lerp(3.5 rad/s, 2.5 rad/s, g*s)
```

The guard is inactive below `90%` of the fixed anchor limit. At score zero it
has exactly zero authority at every anchor error, preserving one-axis motor
targets. At score one it tapers continuously from `3.5` to `2.5 rad/s` over
the final ten percent of admitted anchor error. It does not change impulses,
phase, contact gating, path steering, root authority, solver settings, or
evidence thresholds.

GP5 reissues the complete GP3 numerical grid under fresh `gp5_*` IDs. Its 13
selection shapes and four held-outs use the exact GP4 names above with only
the `gp4_` prefix replaced by `gp5_`. Held-outs retain the same numerical
tuples and fixed R1-R3 perturbations.

Before any eligible GP5 world opens, implementation must:

- compile the interaction score from the normalized morphology receipt before
  world construction and include the formula, inputs, realized score, and
  digest in the policy receipts;
- prove exact score `0.0` for all 13 selection cells and `1.0` for all four
  held-outs;
- reject nonfinite, out-of-range, missing, mistyped, unknown, or
  receipt-inconsistent adaptive options before physics;
- preserve the locked GP3 base path, actuator, gait-clock, solver, and
  threshold receipts;
- expose guard activation, input anchor error, progress, effective ceiling,
  and realized target-speed maxima in each world summary; and
- verify each per-cell controller digest against the formula-derived realized
  options rather than falsely requiring one digest across score-zero and
  score-one cells.

Selection is again all-or-nothing: one exact clean pushed source must pass all
`13/13` worlds and `325/325` assertions. Any failure rejects GP5 and leaves
held-outs unopened. Only complete selection may open the four fresh held-outs.
Complete confirmation then requires all `12/12` held-out worlds and `300/300`
assertions. No score, guard constant, grid, threshold, perturbation, or pass
rule may change after this preregistration.

A clean `25/25`, `625/625` result would establish a bounded
morphology-adaptive quadruped walking system over the declared 17 shapes and
three held-out perturbations. It would still not establish arbitrary
quadrupeds, continuous coverage of the full six-dimensional volume, generated
seeds, another limb count, or automatic creature guidance.

##### GP5 implementation and clean confirmation result

The fresh GP5 grids, formula-derived controller receipt, continuous
anchor-error guard, fail-closed option compiler, world-summary receipts, and
campaign parser were implemented and pushed at:

```text
7039634fb30c37d053acd101594dc49975a202ed
```

Before physics, the clean pushed implementation passed its exact no-world
compiler and policy gates. The final post-fix preflight is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gp5_clean_preflight_52906b1\
  20260726T210300878\report.json
sha256:ee397e994133a5a40d01189be0d64f4d8ea0afd0048aa703b158f21268146be0
1/1 program, 39/39 assertions, zero engine errors
```

The compiler proves all 17 fresh cells, unchanged generator and static-screen
formulas, exact score `0.0` across selection, exact score `1.0` across
held-outs, distinct controller digests for those two score classes, and
fail-closed invalid adaptive options.

The first selection attempt from `7039634` is not evidence. Nine worlds
physically completed, but the test then indexed
`solver_policy_options["solver_position_steps"]` on the empty requested
override instead of the compiled default `20/6` receipt. The resulting script
error left each process waiting for its harness timeout, and the outer
campaign ended without a report:

```text
Invalid access to property or key 'solver_position_steps' on a base object
of type 'Dictionary'.
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp5_selection_official_7039634\
  20260726T203045710\
```

This was a post-world harness receipt bug, not a locomotion failure. The fix
compares the realized solver fields with the already compiled normalized
receipt. It changed no controller, morphology, perturbation, threshold,
physics setting, or walking predicate and was pushed at:

```text
52906b15eb1b886c43d3f9cbba7b314db10893ba
```

Selection was restarted from cell one at that exact clean pushed source:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp5_selection_official_52906b1\
  20260726T210427632\report.json
sha256:e248cf79c9dc31ab0b5b2e252a79ff40d68fe7f92719eb129ab8748321744cbb

13/13 walking worlds
325/325 assertions
selection_eligible=true
```

Only after that complete result were the fresh mixed held-outs opened. All
three fixed perturbation rounds passed:

```text
R1:
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp5_heldout_r1_official_52906b1\
  20260726T211004737\report.json
sha256:d5895de3397bc13c236b63b8e61387669173e2fcf7c6678233feda50ea17d02a
4/4 walking worlds, 100/100 assertions

R2:
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp5_heldout_r2_official_52906b1\
  20260726T211151538\report.json
sha256:041a28cc2248f7c9ef81d880503b5da5445d20d04f74975f392614b7aef801e2
4/4 walking worlds, 100/100 assertions

R3:
<evidence-root>\temp-roots-2026-07-28\sporespore_g3_gp5_heldout_r3_official_52906b1\
  20260726T211338295\report.json
sha256:3fd6621d2952712721d20267d5882cde8ad25871e302b0627aab4c1f0d2997d0
4/4 walking worlds, 100/100 assertions
```

Independent aggregation verified one byte-identical source receipt across all
four reports, `25/25` complete walking worlds, `625/625` assertions, no engine
errors, no timeouts, no killed process trees, and complete containment closure.
The score-zero selection controller is
`sha256:0360dda5eff249308d09dc1ceb7989fded90ba6ede3a785d770e82bf17fd4ab6`;
the score-one held-out controller is
`sha256:7d22537ea485090cc8eab68b60e006ae904839a2575a4c185712c8eae95dc074`.
That distinction is required by the preregistered formula and confirms the
runner did not falsely collapse adaptive receipts into one global digest.

The tightest observed anchor case was mixed D under R2:
`0.02440929 m` against its morphology-derived `0.02479167 m` limit. The
largest final lateral displacement was the wide-torso selection cell:
`0.105949 m` against its `0.110000 m` limit. The least evidence-window
forward displacement was still `0.698796 m`, and the least terminal forward
displacement was `0.910145 m`.

GP5 therefore satisfies its preregistered confirmation rule and establishes a
bounded morphology-adaptive quadruped walking system over these 17 declared
shapes and three held-out perturbations. This is a walking-system result rather
than a one-creature result. The boundary remains important: generated seeds,
continuous six-dimensional coverage, arbitrary quadrupeds, different limb
counts, and automatic creature guidance remain unestablished.

The first complete repository-default BR14A regression used the historical
`180 s` per-program limit and is not a clean family result:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_post_gp5_0b11416\
  20260726T211954809\report.json
sha256:020f88f881d903564e92215860abe1dd703204ade82f7da2974a6894cf6dc13b
24/30 programs; six controlled timeouts
```

All six slow programs then passed unchanged from the same source under a
`600 s` limit, with zero assertion or engine failures. The entire aggregate
was consequently rerun at that empirically sufficient operational limit:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_post_gp5_0b11416_timeout600\
  20260726T222005764\report.json
sha256:045a130de7e2482ab46535aea1630fc6d752f2e2ff754fa9dbe1a271e50a50d4
30/30 programs
508/508 assertions
```

Independent audit found zero nonzero exits, timeouts, killed process trees,
open containment trees, malformed or missing footers, failed assertions,
engine errors, unexpected engine errors, unreadable engine logs, or unreadable
transcripts. The repository-default solver-4 family and isolated solver-6 GP5
campaign are therefore both green at the post-GP5 source.

### G4: generated quadruped family

Compile a preregistered seed list into multiple valid combinations inside the
accepted G1-G3 envelope. Every seed must run in a fresh private process and
must satisfy the same topology-independent walking predicate.

A first useful development target is at least 12 passing generated fixtures
covering the envelope's corners and interior. That would be evidence for a
bounded quadruped walking system, not arbitrary-creature locomotion.

#### Preregistered G4-GQ1 low-discrepancy generated family

GQ1 is preregistered after the complete GP5 confirmation and before any GQ1
physics world. It tests whether the GP5 formula transfers to deterministic
multi-axis morphologies that were not manually enumerated during GP1-GP5.

The generator uses the radical-inverse sequence. For positive integer `n` and
prime base `b`, write `n` in base `b` with digits `a_k`, least-significant
first, and define:

```text
h(n,b) = sum over k >= 0 of a_k / b^(k+1)
q(n,b) = 2*h(n,b) - 1
shell(n) = 0.25 * (1 + ((n - 1) mod 4))
```

Thus every four consecutive indices cover shell fractions `0.25`, `0.50`,
`0.75`, and `1.00`. The six morphology axes use distinct primes:

```text
torso_length_scale      base 2
torso_width_scale       base 3
upper_length_fraction   base 5
hip_span_scale          base 7
foot_radius_scale       base 11
front_limb_mass_scale   base 13
```

For one axis with reference `r`, lower endpoint `lo`, upper endpoint `hi`,
coordinate `q`, and shell `s`, the exact piecewise map is:

```text
value = r + s*q*(r-lo)  when q < 0
value = r + s*q*(hi-r)  when q >= 0
```

The references and sealed endpoint intervals are:

```text
torso length      r=1.0   [0.900, 1.100]
torso width       r=1.0   [0.900, 1.100]
upper fraction    r=18/35 [0.500, 0.550]
hip span          r=1.0   [0.900, 1.100]
foot radius       r=1.0   [0.975, 1.100]
front limb mass   r=1.0   [0.900, 1.050]
```

The exact unperturbed selection indices are `1` through `12`, published as
`gq1_generated_s001` through `gq1_generated_s012`. The fresh held-out indices
are `101` through `108`, published as `gq1_generated_s101` through
`gq1_generated_s108`. Indices, bases, shells, references, bounds, and mapping
may not change after this preregistration.

Every generated cell compiles its GP5 interaction score directly from its six
realized proportions. The controller remains the GP3 base plus the exact GP5
continuous anchor guard:

```text
g = clamp(((anchor_error / admitted_anchor_limit) - 0.90) / 0.10, 0, 1)
speed ceiling = lerp(3.5 rad/s, 2.5 rad/s, g*interaction_score)
```

There is no fixed controller digest across generated morphologies. Each world
must instead reproduce the digest derived from its generated parameter receipt
and realized interaction score. No seed/index, morphology ID, campaign role,
perturbation, or observed result may enter the motor rule.

Before selection opens, no-world tests must prove:

- the radical-inverse digit expansion, shell schedule, piecewise asymmetric
  endpoint map, exact index sets, and stable generation receipts;
- all 20 generated morphologies are unique, finite, inside the sealed bounds,
  and clear the unchanged fixture/static screens;
- selection and held-out indices are disjoint and unknown indices fail closed;
- every generated interaction score is finite in `[0,1]`, is recomputable from
  the generated proportions, and derives the per-cell controller digest;
- the generator covers all four shell fractions and produces both intermediate
  and saturated interaction scores;
- legacy GP1-GP5 grids and controller receipts remain unchanged; and
- malformed generator, morphology, adaptive-controller, or solver receipts
  fail before world construction.

Selection is all-or-nothing: exact clean pushed source must pass all `12/12`
unperturbed generated worlds and `300/300` assertions. Any selection failure
rejects GQ1 and leaves indices `101-108` unopened.

Only complete selection may open the eight fresh held-outs. Each held-out then
runs all three already fixed R1-R3 perturbations, requiring `24/24` walking
worlds and `600/600` assertions. Complete GQ1 confirmation therefore requires
`36/36` generated worlds and `900/900` assertions from one byte-identical
source receipt. No generator constant, index, controller value, perturbation,
threshold, or pass rule may change after observation.

A complete result would establish the first bounded procedurally generated
quadruped family under the GP5 controller formula. It would still not establish
all seeds, continuous coverage of the entire six-dimensional volume, arbitrary
quadrupeds, automatic controller synthesis, another limb count, or automatic
creature guidance.

##### GQ1 implementation and selection result

The exact preregistered generator, reverse morphology lookup, stable generation
receipts, adaptive per-body controller derivation, isolated runner, and
fail-closed no-world tests were implemented, committed, and pushed before any
GQ1 physics at:

```text
b8e2c5871256d88bcba95a64f8ade0412ee04ef4
```

The clean detached source passed the complete generator/compiler gate:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq1_clean_preflight_b8e2c58\logs\
  20260726T231804557\report.json
sha256:40b0f994fc2a7a2f4645a20e6c2273f41f58277cb3e0a95fd53dacd5392d6e0b
1/1 program, 46/46 assertions
```

This preflight regenerated all 20 bodies and receipts, proved their distinct
fixture and static-screen identities, preserved the legacy GP1-GP5 policies,
exercised intermediate and saturated interaction scores, derived distinct
controller receipts, and rejected malformed generator, role, morphology, and
adaptive-controller requests before world construction while retaining the
existing fail-closed solver checks. It had no
engine error, timeout, killed/open process tree, or mutex anomaly.

The exact clean-source GQ1 selection then produced:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq1_selection_official_b8e2c58\
  20260726T231826250\report.json
sha256:5ac5bef096080a7538b8f7e57482ad76b7c97576c7712ff5fe6462e6927040ba
10/12 walking worlds, 294/300 assertions
selection_eligible=false
```

All 12 worlds returned complete receipts from private contained processes with
zero engine errors or timeouts. All 12 parameter, fixture, static-screen, and
generation receipts are distinct; the controller digest is formula-derived per
morphology as preregistered. Ten generated bodies pass all 25 assertions.
`s002` and `s006` necessarily fail the lateral bound shown in their result
receipts; each then reports the generic gate, normalized-metric, and
walking-summary assertion failures:

```text
gq1_generated_s002:
  interaction score                    0.457273381
  final forward displacement           0.962670 m
  absolute final lateral displacement  0.127533 m
  morphology-derived lateral limit     0.101667 m
  excess                               0.025866 m

gq1_generated_s006:
  interaction score                    0.306774257
  final forward displacement           1.023954 m
  absolute final lateral displacement  0.099777 m
  morphology-derived lateral limit     0.097222 m
  excess                               0.002555 m
```

Both failures retain terminal support, complete contact progression, substantial
forward travel, finite metrics, and bounded reported anchor, hinge, and height
measurements. The demonstrated defect is physical path control, not failure to
stand, step, advance, construct the body, or execute the harness.

GQ1 is rejected by its all-or-nothing selection rule. Its indices `101-108`
remain unopened across all three held-out repetitions. The `10/12` result is
strong development evidence that the GP5 formula transfers broadly, but it does
not establish the preregistered generated-family claim. Any successor must use a
fresh campaign identity and freeze a morphology-derived path correction before
eligible physics rather than relaxing the fixed lateral threshold.

#### Preregistered G4-GQ2 complementary path confirmation

GQ2 is a data-informed successor to rejected GQ1. Its candidate was developed
only after the complete GQ1 selection exposed two lateral failures. All
development source was intentionally dirty, all processes remained isolated,
and none of the following reports is eligible GQ2 evidence.

A fixed generated-family cross-track gain of `1.00 rad/m` repaired `s002` and
`s006` individually:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_dev_fixed_cross_1p0\
  gq1_generated_s002\dev_transcript.log  25/25
  gq1_generated_s006\dev_transcript.log  25/25
```

The complete generated selection then moved one lateral failure to saturated
interaction-score cell `s008`:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_dev_fixed_cross_1p0_full12\
  20260726T232838154\report.json
sha256:b9ee85658fbb711251e2cae60ad8bbaa8035a489f6a62d64eaf16dc99d2d0ec4
11/12 walking worlds, 297/300 assertions
```

A continuous complementary interpolation restored `s008` at exact score
`1.0` but was too weak at `s002` score `0.457273381`. The retained development
candidate therefore uses a round, formula-derived half-score switch:

```text
cross-track heading gain =
  1.00 rad/m  when morphology_interaction_score < 0.5
  0.75 rad/m  when morphology_interaction_score >= 0.5
```

The rule contains no generator index, morphology ID, campaign role,
perturbation, observed metric, or pass/fail branch. It complements the existing
GP5 anchor guard: lower-interaction bodies receive stronger cross-track path
correction, while higher-interaction bodies retain the GP3/GP5 path gain. Every
other path field remains exact:

```text
yaw-error stride gain          1.00 /rad
update interval                90 ticks
maximum desired heading error  0.25 rad
maximum steering fraction      0.20
```

The complete 12-cell dirty development screen passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_dev_score_half_switch_full12\
  20260726T233647598\report.json
sha256:aabe67b17174c230fd868838325365de3a1079807664b94a3e1b025afb6524e8
12/12 walking worlds, 300/300 assertions
campaign passed=false solely because scoped source was intentionally dirty
```

GQ2 reissues the exact GQ1 radical-inverse formula, primes, bounds, shell
schedule, and numeric index sets under fresh `gq2_generated_sNNN` morphology
IDs and distinct GQ2 generation/policy receipts. The selection indices remain
`1-12`. The eight still-unopened numeric held-out indices remain `101-108`;
no GQ1 or GQ2 physics has observed them.

The motor controller remains the exact GP5 morphology-interaction anchor guard,
including its continuous score-derived speed ceiling. Engine, solver, actuator
impulses, gait clock, perturbations, thresholds, topology, and forbidden-root
rules remain unchanged. Only the cross-track gain derivation above differs.
GQ1 reproduction must retain its original fixed `0.75 rad/m` path gain and
policy digest; the successor may not rewrite the rejected campaign.

Before eligible GQ2 physics, no-world tests must prove:

- fresh exact selection and held-out IDs resolve only inside GQ2;
- every GQ2 numeric morphology equals its corresponding GQ1 morphology after
  erasing the ID, while generation and policy receipts remain distinct;
- the half-score boundary is exact, both path modes occur in selection and
  held-outs, and the per-body controller digest includes both path and motor
  derivations;
- unknown, mistyped, wrong-role, or receipt-tampered GQ2 requests fail before
  world construction;
- all 20 bodies still compile, clear static screens, and preserve distinct
  fixture receipts; and
- exact GQ1 and legacy GP1-GP5 controller/policy reproduction remains
  unchanged.

Selection is again all-or-nothing: exact clean pushed source must pass all
`12/12` unperturbed worlds and `300/300` assertions. Only that result may open
the eight held-outs. Each then runs fixed R1-R3, requiring `24/24` worlds and
`600/600` assertions. Complete GQ2 confirmation remains `36/36`, `900/900`
from one byte-identical source receipt.

A complete result would establish a bounded procedurally generated quadruped
family under a morphology-adaptive motor-and-path formula. It would still not
establish all seeds, continuous full-volume coverage, arbitrary quadrupeds,
automatic controller synthesis, another limb count, or automatic creature
guidance.

##### GQ2 implementation and confirmation result

GQ2 was implemented, committed, and pushed at exact source
`41ab87557f10d61e874e5ded15846c12491f8ff1`. The implementation:

- added fresh fail-closed GQ2 generator, cell, campaign-role, and receipt
  identities while reproducing every GQ1 numeric morphology exactly;
- preserved the original GQ1 fixed `0.75 rad/m` path policy and its exact
  frozen policy digest;
- derived each GQ2 path gain only from its morphology interaction score:
  `1.0 rad/m` below `0.5`, otherwise `0.75 rad/m`;
- bound that derivation into each per-body controller receipt; and
- upgraded the isolated aggregate report to schema
  `sporespore_br14a_nonuniform_proportion_probe_report_v7`.

The exact clean-source no-world preflight passed `51/51` assertions with zero
engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_clean_preflight_41ab875\logs\20260726T234821397\report.json
SHA-256 4d81b23d30dc24f5ecedb98ad89c2dac12ad0d674bff434dc42e2591f6f1965c
```

The exact clean selection then passed all `12/12` bodies and `300/300`
assertions. This satisfied the preregistered all-or-nothing selection gate and
legitimately opened generated held-out indices `101-108`:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_selection_official_41ab875\20260726T234836901\report.json
SHA-256 0288d19d7150ed87f2eaa0b4626584cbdd4d0bb8c870c28526e3d75ff44dff5d
```

The unchanged held-out repetitions produced:

| repetition | passed worlds | assertions | report SHA-256 |
|---|---:|---:|---|
| R1 | `8/8` | `200/200` | `29ed59d789b20c95d1c828c9f24c6f907467c4a678a6480fca95fc5fec2171d0` |
| R2 | `5/8` | `191/200` | `695cb859de3370c52cbf864a9763655002b71083907231ecf6adbf24d9f05c2a` |
| R3 | `8/8` | `200/200` | `5f4f1bfa076f4257e994a5e220a019ea6f9237c70e76ec38a2ed9875683826b2` |

The corresponding reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_heldout_r1_official_41ab875\20260726T235317143\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_heldout_r2_official_41ab875\20260726T235626918\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq2_heldout_r3_official_41ab875\20260726T235939546\report.json
```

R2's three failures necessarily exceeded the unchanged morphology-derived
lateral corridor. Since torso width is `0.32 W` and the threshold is
`0.3125 * torso_width`, each limit is exactly `0.1 W`:

| morphology | interaction score | final forward | final lateral | allowed absolute lateral | excess |
|---|---:|---:|---:|---:|---:|
| `gq2_generated_s103` | `0.782923749` | `0.977489 m` | `-0.154389 m` | `0.100339506 m` | `0.054049494 m` |
| `gq2_generated_s104` | `1.000000000` | `1.025215 m` | `+0.123523 m` | `0.107119342 m` | `0.016403658 m` |
| `gq2_generated_s106` | `0.577978381` | `0.887898 m` | `+0.121595 m` | `0.101337449 m` | `0.020257551 m` |

Each rejected cell reported the generic three-assertion cascade from that
failed walking predicate. They nevertheless completed substantial forward
translation and retained bounded anchor error, hinge-axis error, torso height,
and positive support-polygon margin. Every selection and held-out process
closed its contained process tree; there were zero timeouts and zero reported
engine errors. R3 was still executed unchanged, as preregistered, after the R2
rejection so the final result would remain complete.

Final GQ2 accounting is `33/36` worlds and `891/900` assertions. GQ2 is
therefore rejected by its all-or-nothing confirmation rule. It does establish
a clean full generated selection and `21/24` positive unseen perturbed worlds,
but it does **not** establish the complete generated-family claim, authorize
formal milestone promotion, or authorize automatic creature guidance.

#### Preregistered G4-GQ3 foot-aware yaw confirmation

GQ3 is preregistered after complete GQ2 confirmation and successor development
but before any GQ3 implementation, generated-body calculation, or physics.
Every GQ2 selection and held-out body is now open development data. No GQ1 or
GQ2 report can therefore serve as GQ3 confirmation evidence.

##### Frozen development basis and rejected alternatives

The GQ2 R2 failures showed a bounded lateral-control problem rather than
collapse: `s103`, `s104`, and `s106` completed substantial forward travel but
exceeded their morphology-derived lateral corridors. Dirty-source successor
development retained the following rejected observations:

- fixed cross-track gain `1.0 rad/m` repaired the original GQ1 failures but
  moved failure to selection `s008`;
- yaw-error gain `1.25` repaired two of the three GQ2 R2 failures, while `1.5`
  moved failures again;
- fixed yaw-error gain `1.3` repaired all three original R2 failures but caused
  one contact-gate timeout each on large-foot `s107` and `s108`;
- extending maximum contact-gate hold from `96` through the compiler ceiling
  of `120` ticks moved or delayed timeouts and still failed R3 `s108`; and
- cross-track warning bands plus per-limb or global contact-hold steering
  guards failed to preserve the complete known matrix.

These are development observations only. They are not eligible GQ3 evidence
and their rejected reports must not be promoted.

The one frozen candidate that passed the complete already-open GQ2 matrix
retains GQ2's morphology-score-derived cross-track gain and derives yaw gain
from physical foot size:

```text
cross_track_heading_gain_rad_per_m =
  1.0 if morphology_interaction_score < 0.5 else 0.75

yaw_error_stride_gain_per_rad =
  1.3 if foot_radius_scale <= 1.025 else 1.0
```

The physical rationale is limited and testable: the three smaller-foot bodies
that needed more path authority all have `foot_radius_scale <= 1.025`, while
the two larger-foot bodies that developed release/recontact timeouts have
scales above that boundary. GQ3 freezes this single threshold formula. It
must not add a morphology ID, generator index, seed, campaign role,
repetition, failure-list lookup, or further condition.

The frozen dirty-source development matrix produced:

| role | result | report SHA-256 |
|---|---:|---|
| GQ2 selection | `12/12`, `300/300` | `1a67987b5c40fadcafa878265bdefd234e5341822039b02494fc87d8b8e680be` |
| GQ2 held-out R1 | `8/8`, `200/200` | `cca1f20c3042bb6207d0e9e75d5036bc7ce4d99c4a3ea1af768f6455765f8b97` |
| GQ2 held-out R2 | `8/8`, `200/200` | `6c8aa02a6e2ec6357c181e983a3574bbad702776200bd7737f52499838dd7879` |
| GQ2 held-out R3 | `8/8`, `200/200` | `2f62a63ec446a66412bae69f43f017e74ebbb94a8b6dfb4fe1a2bd77d69427e8` |

The reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq3_dev_foot_radius_yaw_formula_final_selection12\20260727T010801921\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq3_dev_foot_radius_yaw_formula_final_r1_full8\20260727T011242917\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq3_dev_foot_radius_yaw_formula_final_r2_full8\20260727T011555696\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq3_dev_foot_radius_yaw_formula_final_r3_full8\20260727T011906674\report.json
```

Their complete `36/36`, `900/900` development result justifies a fresh
confirmation attempt. It does not establish GQ3 because the source was dirty,
the reports correctly refused eligibility, and all bodies were already open.

##### Fresh GQ3 generated population

GQ3 reuses the exact six-axis radical-inverse formula, axis primes, asymmetric
intervals, and four-shell schedule preregistered for GQ1. It must issue
distinct GQ3 campaign, morphology, generator-policy, generation-schema,
policy, and controller receipts. No numeric generated morphology may be
copied into source as a handwritten exception.

The fresh selection indices are fixed before implementation:

```text
13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24
```

Their required IDs are `gq3_generated_s013` through
`gq3_generated_s024`. The fresh held-out indices are:

```text
201, 202, 203, 204, 205, 206, 207, 208
```

Their required IDs are `gq3_generated_s201` through
`gq3_generated_s208`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ3`. The implementation must use fresh receipts
equivalent to:

```text
generator_policy_id = g4_gq3_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq3_generation_receipt_v1
policy_schema_version = sporespore_g4_gq3_foot_aware_yaw_generated_morphology_policy_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v8
```

##### Frozen controller, physics, and evidence contract

GQ3 changes only the yaw-gain derivation shown above. It retains:

- GQ2's score-derived `1.0/0.75 rad/m` cross-track gain;
- the GP5 morphology-interaction motor-velocity and anchor-guard formula;
- actuator impulse scale `1.015`;
- maximum steering fraction `0.20`;
- desired heading-error limit `0.25 rad`;
- 90-tick steering updates;
- the exact unit-scale dynamic-similarity clock, including the original
  `96`-tick maximum contact-gate hold;
- 120 Hz Jolt physics with `20` velocity and `6` position steps;
- all GQ2 fixture formulas, static screens, topology, thresholds, motor
  ceilings, contact semantics, evidence horizons, and nonclaims; and
- the exact selection and R1-R3 perturbation formulas already frozen for GQ2.

GQ1 must retain its original fixed `0.75 rad/m`, `1.0/rad` path controller.
GQ2 must retain both its score-derived cross-track gain and fixed `1.0/rad`
yaw gain, including exact reproduction of its frozen policy digest
`sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463`.
GQ3 may not silently mutate either rejected predecessor.

Before eligible GQ3 physics, no-world tests must prove:

- all 20 fresh IDs resolve only within GQ3 and regenerate deterministically;
- the exact numeric generator remains formula-identical to GQ1/GQ2 for any
  shared numeric index while every campaign receipt remains distinct;
- the cross-track and foot-radius yaw formulas derive exact per-body
  controller digests;
- the `1.025` boundary has explicit below, exact-boundary, and above-boundary
  tests;
- no morphology ID, generator index, seed, role, or repetition enters either
  controller formula;
- GQ1, GQ2, and GP1-GP5 policy/controller reproduction remains exact; and
- unknown, mistyped, wrong-role, or receipt-tampered GQ3 requests fail before
  world construction.

##### Frozen execution and stopping rule

Eligible evidence requires one exact pushed commit, a clean scoped source
tree, the approved isolated hidden process runner, zero engine errors, zero
timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed worlds must pass
`300/300` assertions. Any selection failure rejects GQ3 and leaves held-out
indices `201-208` unopened. A complete selection is the only event that may
open held-out physics.

If selection passes, all eight held-out bodies run unchanged under R1, R2, and
R3 for `24/24` worlds and `600/600` assertions. All three repetitions must be
executed even if an earlier repetition fails, so the final result remains
complete. The implementation and formula are frozen before selection; no
post-selection tuning, threshold change, alternate candidate, or rerun choice
is allowed.

Complete GQ3 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source receipt. A complete pass would establish
a bounded procedurally generated quadruped family for these fresh indices and
fixed perturbations. It would still not establish all seeds, continuous
full-volume coverage, arbitrary quadrupeds, automatic controller synthesis,
another limb count, or automatic creature guidance.

##### GQ3 implementation and selection result

GQ3 was implemented, committed, and pushed at exact source
`402295c609af97586ddf3fafbc8243dbcd2e73b1`. The implementation added the
fresh fail-closed generator and campaign receipts, foot-radius-derived yaw
rule, report-v8 harness path, and independent formula/boundary tests while
retaining exact earlier-campaign reproduction.

The exact clean pushed source passed its no-world preflight at `56/56` with
zero engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq3_clean_preflight_402295c\logs\20260727T013900520\report.json
sha256:68a83db16a0a7da3234d35f30941a7e9459e9ecd622a1868cd49589cbf2db6d9
```

The first and only eligible selection execution then ran all 12 preregistered
indices `13-24` from the same clean immutable source snapshot:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq3_selection_official_402295c\20260727T013938066\report.json
sha256:aadf8d35dbf161464c6bc57b66b02a5c74f0bfbb0b3722ea6103675b9682dba2
```

Eleven bodies passed all 25 assertions and established one-world physical
walking. `gq3_generated_s016` passed every construction, topology, contact
progression, recovery, forward-travel, height, tilt, hinge, and anchor gate,
but missed its morphology-derived final lateral corridor:

| body | forward | final lateral | lateral limit | excess |
|---|---:|---:|---:|---:|
| `gq3_generated_s016` | `1.022328 m` | `+0.102926 m` | `0.101851852 m` | `0.001074148 m` |

Its three failed assertions are the direct bounded-lateral predicate plus two
aggregate walking predicates that depend on it; they are not three independent
physical faults. The exact selection accounting is nevertheless `11/12`
worlds and `297/300` assertions. Under the frozen all-or-nothing stopping rule,
GQ3 is rejected, `selection_eligible=false`, and held-out indices `201-208`
remain uncalculated and unopened in physics. No GQ3 selection rerun or
post-selection threshold change can become eligible evidence.

#### Preregistered G4-GQ4 score-foot-hip yaw confirmation

GQ4 is preregistered after the complete GQ3 selection rejection and successor
development, but before any GQ4 implementation, generated-body calculation,
static compilation, or physics. GQ1-GQ3 selection data and all legitimately
opened GQ2 held-outs are development data. GQ3 held-out indices `201-208`
remain unopened and may not be used by GQ4.

##### Frozen development basis and rejected intermediates

GQ3's only failing body, `gq3_generated_s016`, was not unstable or
contact-limited. It completed all four limb cycles, terminal support recovery,
and substantial forward travel, then missed only its final lateral corridor by
`0.001074148 m`. Dirty-source development established:

- restoring yaw gain `1.0` repaired `s016` at `25/25`;
- yaw gain `1.25` also repaired `s016` at `25/25`;
- a foot-only three-band rule passed all opened GQ3 selection bodies at
  `12/12`, `300/300`, but moved a lateral failure to GQ2 selection body `s003`;
- adding only a hip-span-deviation guard restored GQ2 selection and R1 but
  moved the GQ2 R2 lateral failure to low-interaction body `s105`; and
- adding the already-frozen morphology interaction score as a guard restored
  `s105` while retaining the repairs to `s103`, `s104`, `s106`, and `s016`.

The two key rejected reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_three_band_gq2_selection12\20260727T015702731\report.json
sha256:59e2c3db3d92be664002aecbc35f9f048656ea15e5eed3ba544330623b4eb9b8

<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_foot_hip_formula_gq2_r2\20260727T021051491\report.json
sha256:db6f181fd1830edaf7859ced0154210987ca920b2cda1b6d337308ec92b6d422
```

These reports and all other successor probes are development observations
only. They are not eligible GQ4 evidence and their failed alternatives must
not be resurrected selectively.

The one frozen candidate passed the complete opened GQ2 matrix and the
complete opened GQ3 selection matrix from one exact dirty source fingerprint:

| opened development cohort | result | report SHA-256 |
|---|---:|---|
| GQ2 selection | `12/12`, `300/300` | `9cfa9718d996fcf4b3a0d1a7a267ff43ed28f1e1a42dbb59ea591392567d5de6` |
| GQ2 held-out R1 | `8/8`, `200/200` | `544ddb4f26dd535a6631ed4bd2e7ff0e4add27196b77503259e5c165e85dce84` |
| GQ2 held-out R2 | `8/8`, `200/200` | `551a8ca18a5e1ba94788a294dccd7825e7750159fc18b0b7f08e5090440d1eb8` |
| GQ2 held-out R3 | `8/8`, `200/200` | `e3f90941c3746853b544062bf1e0bbb336404adf3fa2e971eb03ca38a9d309e8` |
| GQ3 selection | `12/12`, `300/300` | `183a982ebb06cc75768a61d3b8c9bf708cfffe9328ccd5b5f05f5b3ae301532c` |

The reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_score_foot_hip_formula_gq2_selection12\20260727T022435385\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_score_foot_hip_formula_gq2_r1\20260727T022118972\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_score_foot_hip_formula_gq2_r2\20260727T021441941\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_score_foot_hip_formula_gq2_r3\20260727T021807438\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_dev_score_foot_hip_formula_gq3_selection12\20260727T022915265\report.json
```

All five reports share exact scoped source fingerprint
`8095ea5de50e73a376438558161ab3f36cd6a3caa2dc5c03bdb3fbc2258d030d`
and total `48/48` worlds with `1200/1200` assertions. They correctly refuse
eligibility because their source is dirty and every body is already open.

##### Frozen GQ4 controller formula

Let `S` be the existing GP5 clamped morphology interaction score, `F` be
`foot_radius_scale`, and `H` be `hip_span_scale`. GQ4 retains GQ2's
cross-track rule:

```text
cross_track_heading_gain_rad_per_m =
  1.0 if S < 0.5 else 0.75
```

It replaces GQ3's single-cutoff yaw rule with exactly:

```text
if F > 1.025:
  yaw_error_stride_gain_per_rad = 1.0
elif F > 1.01:
  yaw_error_stride_gain_per_rad = 1.3
elif S >= 0.5 and abs(H - 1.0) >= 0.02:
  yaw_error_stride_gain_per_rad = 1.25
else:
  yaw_error_stride_gain_per_rad = 1.0
```

Boundary inclusion is part of the formula: `F == 1.025` receives `1.3`;
`F == 1.01` enters the score-and-hip branch; `S == 0.5` and
`abs(H - 1.0) == 0.02` satisfy their respective guards. No epsilon,
interpolation, warning band, hysteresis, or fallback lookup is allowed.

The limited physical rationale is testable: larger feet retain baseline yaw to
protect semantic recontact; medium-small feet need the strongest correction;
very small feet receive moderate correction only when the body is globally
interaction-heavy and hip spacing is materially off reference. The formula
must not inspect morphology ID, generator index, seed, campaign role,
repetition, perturbation, prior outcome, or any failure list.

##### Fresh GQ4 generated population and receipts

GQ4 reuses the exact GQ1 six-prime radical-inverse calculation, asymmetric
axis intervals, and four-shell schedule. It issues distinct GQ4 campaign,
morphology, generator, policy, controller, and report receipts. The fresh
selection indices are fixed as:

```text
25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36
```

Their required IDs are `gq4_generated_s025` through
`gq4_generated_s036`. Fresh held-out indices are:

```text
301, 302, 303, 304, 305, 306, 307, 308
```

Their required IDs are `gq4_generated_s301` through
`gq4_generated_s308`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ4`. The implementation must use fresh receipts
equivalent to:

```text
generator_policy_id = g4_gq4_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq4_generation_receipt_v1
policy_schema_version = sporespore_g4_gq4_score_foot_hip_yaw_generated_morphology_policy_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v9
```

##### Frozen physics, evidence, and regression contract

GQ4 changes only the yaw-gain formula above. It retains:

- GQ2's score-derived `1.0/0.75 rad/m` cross-track rule;
- the GP5 morphology-interaction motor-velocity and anchor-guard formula;
- actuator impulse scale `1.015`;
- maximum steering fraction `0.20`;
- desired heading-error limit `0.25 rad`;
- 90-tick steering updates;
- the exact unit-scale dynamic-similarity clock and `96`-tick contact hold;
- 120 Hz Jolt physics with `20` velocity and `6` position steps;
- all fixture formulas, static screens, topology, evidence thresholds, contact
  semantics, horizons, recovery gates, and nonclaims; and
- the exact selection and R1-R3 perturbation formulas frozen for GQ2/GQ3.

GQ1, GQ2, and GQ3 must retain their original policies and controller formulas.
In particular, clean no-world regression must reproduce:

```text
GQ1 policy = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 policy = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 policy = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
```

Before eligible GQ4 physics, no-world tests must prove:

- all 20 fresh IDs resolve only inside GQ4 and regenerate deterministically;
- all generator coordinates and realized values independently recompute from
  the frozen primes, intervals, shells, and fresh indices;
- GQ4 receipts are distinct from GQ1-GQ3 even when formulas are shared;
- every cross-track and yaw branch derives the exact per-body controller
  receipt without an ID, index, seed, role, or repetition dependency;
- explicit below, exact, and above boundary cases cover `F=1.01`,
  `F=1.025`, `S=0.5`, and `abs(H-1.0)=0.02`;
- all malformed type, index, role, morphology, and receipt requests fail
  before world construction; and
- exact GP1-GP5 and GQ1-GQ3 regression remains intact.

##### Frozen execution and stopping rule

Eligible evidence requires one exact pushed commit, a clean scoped source
tree, an immutable source snapshot, the approved isolated hidden runner, zero
engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ4 worlds must pass
`300/300` assertions. Any selection failure rejects GQ4 and leaves indices
`301-308` unopened. Only a complete selection may open held-out physics.

If selection passes, all eight held-out bodies run unchanged under R1, R2, and
R3 for `24/24` worlds and `600/600` assertions. All repetitions must run even
if one fails. The source and formula freeze before selection; no post-selection
tuning, threshold change, alternate candidate, or selective rerun is eligible.

Complete GQ4 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source receipt. A complete result would establish
a bounded procedurally generated quadruped family for these fresh indices and
fixed perturbations. It would not establish all seeds, continuous full-volume
coverage, arbitrary quadrupeds, automatic controller synthesis, another limb
count, or automatic creature guidance.

##### GQ4 implementation and selection result

GQ4 was implemented, committed, and pushed at exact source
`34450df861ad383414e6abdf17a00407ce59d9a5`. The implementation added the
fresh generator and campaign receipts, isolated score-foot-hip yaw function,
report-v9 runner path, independent generator reconstruction, explicit boundary
tests, and fail-closed role/type/receipt checks while preserving exact GQ1-GQ3
policy hashes.

The exact clean pushed source passed its no-world gate at `61/61` with zero
engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_clean_preflight_34450df\logs\20260727T024314242\report.json
sha256:e8c155b6d98fbe49b05d0f421ba81204c688846558d6459a563490ad1f4a7a25
```

The first and only eligible selection execution then ran all 12 preregistered
indices `25-36` from the same clean immutable source snapshot:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq4_selection_official_34450df\20260727T024330561\report.json
sha256:04beaeb046ffc74eb0ed8561c25bd25a077dceaa6995af625f59a5d080c77289
```

Eleven bodies passed all 25 assertions and established one-world physical
walking. `gq4_generated_s030` passed every construction, topology, contact,
cycle, terminal-support, forward-travel, height, tilt, hinge, and anchor gate,
but failed its morphology-derived final lateral corridor:

| body | score | cross gain | yaw gain | forward | final lateral | lateral limit | excess |
|---|---:|---:|---:|---:|---:|---:|---:|
| `gq4_generated_s030` | `0.463746420` | `1.0` | `1.3` | `0.970145 m` | `-0.107825 m` | `0.096234568 m` | `0.011590432 m` |

Its three failed assertions are the bounded-lateral predicate and two dependent
aggregate walking predicates, not three independent physical faults. Exact
selection accounting is `11/12`, `297/300`. Under the frozen stopping rule,
GQ4 is rejected, `selection_eligible=false`, and held-out indices `301-308`
remain uncalculated and unopened in physics. No GQ4 selection rerun,
post-selection controller change, or threshold relaxation can become eligible
GQ4 evidence.

#### Preregistered G4-GQ5 score-first yaw confirmation

GQ5 is preregistered after the complete GQ4 selection rejection and successor
development, but before any GQ5 implementation, generated-body calculation,
static compilation, or physics. All GQ1-GQ4 selection bodies and legitimately
opened GQ2 held-outs are development data. GQ3 held-outs `201-208` and GQ4
held-outs `301-308` remain unopened and may not be used.

##### Frozen development basis

GQ4 body `s030` had morphology interaction score `0.463746420` and therefore
already received the stronger `1.0 rad/m` cross-track gain, but GQ4's
medium-small-foot branch independently assigned yaw gain `1.3`. Returning this
single opened body to baseline yaw repaired it at `25/25`.

The frozen candidate makes only one precedence change: low-interaction bodies
return to baseline yaw before any foot or hip branch. It then passed every
opened generated world available to successor development from one exact dirty
source fingerprint:

| opened development cohort | result | report SHA-256 |
|---|---:|---|
| GQ4 selection | `12/12`, `300/300` | `b8d2eafc4dbc67ab8c7481b801e8b2dab8bb70f0d9414b4e5627540ccff99ee3` |
| GQ3 selection | `12/12`, `300/300` | `6396b839732d986ee9a5870330f719576e346d74bf7ba993eb137aee4def976e` |
| GQ2 selection | `12/12`, `300/300` | `b11ecd7526499fe52041b1ecf7b55a6c2d9eb663d987865e056ff97a0dfd0a1a` |
| GQ2 held-out R1 | `8/8`, `200/200` | `6a31fbf9d7e3709437e850ee0e15c97a93c9b18dfd8da3575e0aee4b63a3c44d` |
| GQ2 held-out R2 | `8/8`, `200/200` | `9b6c18ae630735a1166e7d273ef74dd20da30a9c6e8bb19026dc042a0830ffed` |
| GQ2 held-out R3 | `8/8`, `200/200` | `addf2e999e2b07299bc629f4605eebb9b9d9d32083768f3b2db549860ab641cf` |

The reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_dev_score_first_gq4_selection12\20260727T025056089\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_dev_score_first_gq3_selection12\20260727T025537042\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_dev_score_first_gq2_selection12\20260727T030014980\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_dev_score_first_gq2_r1\20260727T030452216\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_dev_score_first_gq2_r2\20260727T030800877\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_dev_score_first_gq2_r3\20260727T031112664\report.json
```

All six share scoped source fingerprint
`a5be169d1ea3e0324d4ea91e0cabfc8c5d0797b5079e861970e4e75f77153295`
and total `60/60` worlds with `1500/1500` assertions. The reports correctly
refuse eligibility because the source is dirty and every body is open.

##### Frozen GQ5 controller formula

Let `S`, `F`, and `H` retain their GQ4 meanings. Cross-track control remains:

```text
cross_track_heading_gain_rad_per_m =
  1.0 if S < 0.5 else 0.75
```

GQ5 yaw control is exactly:

```text
if S < 0.5 or F > 1.025:
  yaw_error_stride_gain_per_rad = 1.0
elif F > 1.01:
  yaw_error_stride_gain_per_rad = 1.3
elif abs(H - 1.0) >= 0.02:
  yaw_error_stride_gain_per_rad = 1.25
else:
  yaw_error_stride_gain_per_rad = 1.0
```

Boundary inclusion is frozen: `S == 0.5` proceeds to the foot branches;
`F == 1.025` receives `1.3`; `F == 1.01` proceeds to the hip branch; and
`abs(H-1.0) == 0.02` receives `1.25`. No epsilon, interpolation, hysteresis,
warning band, fallback lookup, or post-world state may alter the result.

The controller must not inspect morphology ID, generator index, seed, campaign
role, repetition, perturbation, prior outcome, or failure list. The limited
physical rationale is that low-interaction bodies already receive stronger
cross-track correction and do not benefit from simultaneous extra yaw;
high-interaction bodies retain GQ4's foot/hip response classification.

##### Fresh population and distinct receipts

GQ5 reuses the exact GQ1 radical-inverse generator, six axes, prime bases,
asymmetric intervals, and four-shell schedule. Fresh selection indices are:

```text
37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47, 48
```

Their required IDs are `gq5_generated_s037` through
`gq5_generated_s048`. Fresh held-out indices are:

```text
401, 402, 403, 404, 405, 406, 407, 408
```

Their required IDs are `gq5_generated_s401` through
`gq5_generated_s408`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ5`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq5_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq5_generation_receipt_v1
policy_schema_version = sporespore_g4_gq5_score_first_foot_hip_yaw_generated_morphology_policy_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v10
```

##### Frozen regression, execution, and stopping contract

GQ5 changes only the yaw-branch precedence above. All GQ4 fixture, motor,
actuator, path, clock, solver, perturbation, evidence, contact, recovery, and
nonclaim contracts remain exact. GQ1-GQ4 behavior and policies must not change.
Clean no-world tests must retain:

```text
GQ1 policy = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 policy = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 policy = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 policy = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
```

Before GQ5 physics, no-world tests must independently reconstruct all 20
generator receipts, compile all static bodies, prove distinct campaign
receipts, test all score/foot/hip boundaries and branch precedence, prove
ID/index/seed/role/repetition independence, reject malformed requests before
world construction, and retain exact GP1-GP5 and GQ1-GQ4 regression.

Eligible evidence requires one pushed commit, a clean scoped source tree,
immutable source snapshots, the approved isolated hidden runner, zero engine
errors, zero timeouts, and closed containment trees.

Selection requires `12/12`, `300/300`. Any failure rejects GQ5 and leaves
indices `401-408` unopened. Only a complete selection opens the eight held-out
bodies for all three unchanged repetitions. Held-out completion requires
`24/24`, `600/600`; all repetitions run even if one fails. No post-selection
tuning, threshold change, candidate swap, or selective rerun is eligible.

Complete GQ5 confirmation requires `36/36`, `900/900` from one byte-identical
clean source receipt. A complete result would establish a bounded
procedurally generated quadruped family for these fresh indices and fixed
perturbations. It would not establish all seeds, continuous full-volume
coverage, arbitrary quadrupeds, automatic synthesis, another limb count, or
automatic creature guidance.

##### Exact clean GQ5 result

GQ5 was implemented and pushed at
`3ada640d844f45f1da36b320f74f30a6f0b9a3d7`. The exact clean no-world gate
passed `66/66` with zero engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_clean_no_world_3ada640\20260727T032712950\report.json
sha256:cf170173521a63148e74828af3e459029c8c6e9bd23e8ba81c2b5ae5a7999f36
```

The first and only eligible GQ5 selection run then completed from that same
clean pushed commit at `7/12` worlds and `284/300` assertions. It had zero
engine errors, zero timeouts, and closed every containment tree, but did not
meet the exact `12/12`, `300/300` selection gate:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq5_selection_official_3ada640\20260727T032748303\report.json
sha256:b9bfc4a874d3661224af1ce52f74d57cbead4067d225ac286db2448f9eadd594
policy=sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
```

Five selection bodies failed:

| body | score | physical result |
|---|---:|---|
| `s037` | `0.032248234` | advanced `0.808556 m`; lateral magnitude `0.099709 m` exceeded its `0.099413580 m` limit by about `0.000295420 m` |
| `s038` | `0.191682232` | advanced `0.985508 m`; lateral magnitude `0.119538 m` exceeded its `0.102160494 m` limit by about `0.017377506 m` |
| `s039` | `1.000000000` | advanced `0.938184 m`; lateral magnitude `0.108367 m` exceeded its `0.094907407 m` limit by about `0.013459593 m` |
| `s047` | `1.000000000` | advanced `1.016978 m` and passed normalized metric bounds, but failed the exact contact-progression predicate |
| `s048` | `1.000000000` | advanced `1.010158 m`; lateral magnitude `0.128128 m` exceeded its `0.093950617 m` limit by about `0.034177383 m`, and front-left completed only one accepted contact cycle |

`s037`, `s038`, and `s039` failed only the lateral-derived walking gates.
`s047` failed contact progression even though its terminal trace showed three
cycles per limb, so its exact timeout-versus-virtual-horizon subpredicate still
requires development instrumentation. `s048` independently failed both
contact progression and lateral containment.

GQ5 is rejected. Held-out indices `401-408` remain uncalculated in physics and
unopened. The result shows that a score-first branch which cleared the entire
opened `60/60`, `1500/1500` development matrix did not generalize to the next
fresh cohort. No GQ5 rerun, threshold change, controller edit, or held-out
opening can become eligible GQ5 evidence.

#### Preregistered G4-GQ6 morphology-adaptive velocity-feedback confirmation

GQ6 is preregistered after the exact GQ5 selection rejection and complete
successor development, but before any GQ6 implementation, generated-body
calculation, static compilation, or physics. Every GQ1-GQ5 selection body and
the legitimately opened GQ2 held-outs are development data. GQ3 held-outs
`201-208`, GQ4 held-outs `301-308`, and GQ5 held-outs `401-408` remain unopened
and may not be calculated or used by GQ6.

##### Frozen development basis and rejected alternatives

The GQ5 failures separated into two physical families. `s037`, `s038`, `s039`,
and `s048` required better lateral path containment over a longer observation
horizon. `s047` and `s048` also exposed insufficient time for contact-gated
release and recontact to complete without a virtual-horizon timeout.

Development used only opened bodies. It rejected:

- a solver-only successor, because it moved rather than eliminated failures;
- larger or uniform yaw gains, because they repaired one generated slice while
  breaking another;
- uniform lateral-velocity feedback, because `0.20`, `0.25`, and `0.30`
  each failed different opened proportion regimes;
- stronger global anchor guards, because they traded lateral improvement for
  structural or locomotor failures;
- contact-threshold relaxation, because it would change the meaning of the
  walking predicate; and
- morphology-ID, generator-index, campaign, role, repetition, or failure-list
  lookups, because they are ineligible seed memorization.

The frozen Candidate 24 uses four observed evidence cycles, a bounded
`120`-tick contact hold, morphology-derived yaw and lateral-velocity feedback,
a score-derived anchor guard, Jolt `20/7` solver iterations, and two small
dimensionless structural-threshold corrections. It passed every opened
development world from one exact dirty source vector:

| opened development cohort | result | report SHA-256 |
|---|---:|---|
| GQ2 selection | `12/12`, `300/300` | `8d2ebe4998ffbb0b4ff00a7d45d2330c48d387dfc135ec4a494379efa8290c3f` |
| GQ3 selection | `12/12`, `300/300` | `94ee16a473e079c1489eb9b44d0b05157ea300abc5076500159c77492bec1cd6` |
| GQ4 selection | `12/12`, `300/300` | `a21c9f620a68f3335e512e45a19726d1c2ed76a0e84ab27eee7bbb5fdb650c83` |
| GQ5 selection | `12/12`, `300/300` | `8488a5d75320889ccd87caf67236ba58e02c5cace66c88f0f239c6d545560eab` |
| GQ2 held-out R1 | `8/8`, `200/200` | `024a79689668c3ae2c7ca2dcaa500908513307a0750c03a75ebf5dc3f28f571c` |
| GQ2 held-out R2 | `8/8`, `200/200` | `0c0520129db8eb44beea177bdf952b1847778be1fd57165759079938dcad826a` |
| GQ2 held-out R3 | `8/8`, `200/200` | `0a682dc2ceff7a72fe9084f2674a429b70efc909898487b67bd8c89cee71c5b7` |

The exact reports are:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq2_selection12\20260727T083658433\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq3_selection12\20260727T084219468\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq4_selection12\20260727T082622547\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq5_selection12\20260727T083139223\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq2_heldout_r1\20260727T084737918\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq2_heldout_r2\20260727T085113140\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq6_dev_candidate24_frozen_gq2_heldout_r3\20260727T085447658\report.json
```

The seven reports total `72/72` physical worlds and `1800/1800` assertions,
with zero engine errors and one identical 13-file `source_sha256` vector. Key
shared hashes are:

```text
walker = sha256:1fa237e3dd887a204c0ac36c0bd6a752fbf238382fc0eee51e92441cd61f4d0d
clock = sha256:257c617b398d8c0b3a993dd4c73369d63541f6740067a8ce6fda2db64bb7e32c
test = sha256:342c7a4c00f34fe69547ac5dbf225f44176a8ddc9b44090966ff9051c7eb6b61
runner = sha256:ffd1d792976e330822f3906d6c8bcd266e87b7e8e83e80c54bc483d45d3cd28f
```

These reports correctly refuse eligibility because the scoped source was
dirty and every body was already open. They freeze the successor design but
are not GQ6 evidence and establish no new accepted walking-family claim.

##### Frozen GQ6 morphology and controller formulas

Let:

```text
L = torso_length_scale
W = torso_width_scale
U = upper_length_fraction
H = hip_span_scale
F = foot_radius_scale
M = front_limb_mass_scale
```

The morphology interaction score remains exactly:

```text
dL = abs((L - 1.0) / 0.10)
dW = abs((W - 1.0) / 0.10)
dU = abs((U - 18/35) / 0.05)
dH = abs((H - 1.0) / 0.10)
dF = abs((F - 1.0) / 0.10)
dM = abs((M - 1.0) / 0.10)
S = clamp(sum(i < j, di * dj), 0.0, 1.0)
```

Cross-track position feedback is:

```text
cross_track_heading_gain_rad_per_m =
  1.0 if S < 0.5 else 0.75
```

Yaw feedback is:

```text
if F < 0.985:
  yaw_error_stride_gain_per_rad = 1.3 if S >= 0.9 else 1.1
elif S < 0.5 or F > 1.025:
  yaw_error_stride_gain_per_rad = 1.0
elif F > 1.01:
  yaw_error_stride_gain_per_rad = 1.3
elif abs(H - 1.0) >= 0.02:
  yaw_error_stride_gain_per_rad = 1.1 if L > 1.02 else 1.0
else:
  yaw_error_stride_gain_per_rad = 1.0
```

Let `Y` be the resulting yaw gain. Cross-track velocity feedback is frozen as:

```text
if Y > 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20
elif S < 0.15:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20 if W <= 1.0 else 0.25
elif S < 0.5:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.30 if W <= 1.0 else 0.20
else:
  cross_track_velocity_heading_gain_rad_per_m_s = (
    0.20 if W > 1.0 and L < 1.0 else 0.25
  )
```

At each existing steering update, desired heading is:

```text
desired_heading_error_rad = clamp(
  -cross_track_heading_gain_rad_per_m * cross_track_error_m
  -cross_track_velocity_heading_gain_rad_per_m_s * cross_track_velocity_m_s,
  -0.25,
  0.25
)
```

The existing stride-side steering fraction is capped at `0.40`. The update
interval remains exactly `90` ticks. The controller must compile the velocity
gain before world construction and seal it in the controller receipt; it may
not select a gain from runtime outcome, morphology ID, or a post-world lookup.

Boundary inclusion is exact:

- `F == 0.985` proceeds to the score/large-foot branches;
- `S == 0.9` receives small-foot yaw `1.3`;
- `S == 0.5` receives cross-track gain `0.75`;
- `S == 0.15` proceeds to the moderate-interaction width split;
- `F == 1.025` receives yaw `1.3`;
- `F == 1.01` proceeds to the hip branch;
- `abs(H - 1.0) == 0.02` enters the hip branch;
- `L == 1.02` receives hip-branch yaw `1.0`;
- `W == 1.0` is in the narrow-or-reference velocity branch; and
- `L == 1.0` is not in the short-torso velocity branch.

No epsilon, interpolation, hysteresis, warning band, fallback, seed table, or
runtime performance measurement may change these branches.

Motor velocity feedback remains GP5-derived. It receives `S` and uses:

```text
if S >= 0.5:
  anchor_error_guard_activation_fraction = 0.80
  anchor_error_guard_maximum_motor_target_speed_rad_s = 2.0
else:
  anchor_error_guard_activation_fraction = 0.90
  anchor_error_guard_maximum_motor_target_speed_rad_s = 2.5
```

The clock is a distinct GQ6 receipt. It retains unit-scale `120 Hz`,
`360`-tick cycles, one warmup cycle, one cooldown cycle, `240` settle ticks,
`240` terminal-settle ticks, and all existing motor gains. It changes only:

```text
evidence_cycles = 4
maximum_contact_gate_hold_ticks = 120
```

Every limb must therefore complete exactly `1440` ungated evidence ticks.
Evidence extension remains bounded at `720` ticks and maximum phase skew
remains `12` ticks. A timeout, partial contact cycle, or extension beyond the
sealed bound fails rather than relaxing the predicate.

The GQ6 solver receipt is exactly:

```text
physics_engine = Jolt Physics
physics_hz = 120
solver_velocity_steps = 20
solver_position_steps = 7
```

Evidence thresholds retain the existing dimensionless policy except:

```text
minimum_foot_relocation_m = 0.0238 * torso_length_m
maximum_anchor_error_m = 0.14 * upper_leg_length_m
```

All other thresholds remain exact, including:

```text
minimum_evidence_torso_advance_m = 0.080 * torso_length_m
minimum_final_torso_advance_m = 0.060 * torso_length_m
maximum_lateral_drift_m = 0.3125 * torso_width_m
maximum_yaw_drift_rad = 0.45
maximum_tilt_rad = 0.60
minimum_torso_height_m = (25/44) * initial_torso_center_y_m
maximum_hinge_axis_error_rad = 0.20
```

##### Fresh GQ6 population and distinct receipts

GQ6 reuses the exact GQ1 radical-inverse calculation, six axes, prime bases,
asymmetric intervals, and four-shell schedule. The fresh selection indices are
fixed before implementation or body calculation:

```text
49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 59, 60
```

Their required IDs are `gq6_generated_s049` through
`gq6_generated_s060`. The fresh held-out indices are:

```text
501, 502, 503, 504, 505, 506, 507, 508
```

Their required IDs are `gq6_generated_s501` through
`gq6_generated_s508`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ6`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq6_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq6_generation_receipt_v1
policy_schema_version = sporespore_g4_gq6_morphology_adaptive_velocity_feedback_policy_v1
clock_policy_id = g4_gq6_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v11
```

All 20 GQ6 IDs, generator receipts, policy receipts, controller receipts, clock
receipts, solver receipts, and threshold receipts must be distinct where their
declared inputs differ and deterministic where inputs are identical.

##### Frozen preservation, execution, and stopping contract

GQ6 must be implemented as a distinct campaign policy. The rejected GQ5 source,
behavior, selection report, and held-out lock remain unchanged. GQ1-GQ5 policy
digests must reproduce exactly:

```text
GQ1 policy = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 policy = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 policy = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 policy = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
GQ5 policy = sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
```

Before eligible physics, no-world tests must independently:

- reconstruct all 20 fresh generator receipts and reverse ID lookups;
- prove selection and held-out indices are disjoint;
- compile every fixture and static screen with zero world construction;
- exercise every equality boundary in the cross-track, yaw, velocity, and
  anchor-guard formulas;
- prove ID/index/seed/role/repetition/outcome independence;
- prove the GQ6 clock, solver, threshold, controller, and policy receipts;
- reject malformed, unknown, cross-campaign, or nonfinite requests closed; and
- retain exact GP1-GP5 and GQ1-GQ5 no-world regression.

Eligible evidence requires a pushed implementation commit, a clean scoped
source tree, immutable per-cell source snapshots, the approved isolated hidden
runner, zero engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ6 worlds must pass
`300/300` assertions. Any selection failure rejects GQ6 and leaves indices
`501-508` unopened. There is no eligible selection rerun.

Only a complete selection opens the eight held-out bodies for all three frozen
perturbations. Held-out completion requires `24/24` worlds and `600/600`
assertions. All three repetitions run unchanged once opened, even if an earlier
repetition fails. No post-selection edit, threshold change, candidate swap,
selective rerun, or newly observed branch may become GQ6 evidence.

Complete GQ6 confirmation requires `36/36` worlds and `900/900` assertions from
one byte-identical clean source vector. A complete result would establish this
bounded procedurally generated quadruped family for the fresh indices and
fixed perturbations. It would not establish every seed, continuous full-volume
coverage, arbitrary quadrupeds, automatic morphology synthesis, another limb
count, running, or automatic creature guidance.

#### G4-GQ6 exact selection result: rejected at 11/12

The distinct GQ6 implementation was committed and pushed before physics:

```text
implementation commit = 700cac2e7b42c7f0c23320a4837c1b2e85e5ddd4
formula policy = sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f
```

The post-format no-world gate passed `72/72` assertions with zero engine
errors. It independently reconstructed all 20 GQ6 generation receipts,
compiled every fixture and static screen without a physics world, exercised
the frozen formula boundaries, proved the GQ6 clock/solver/threshold receipts,
and reproduced the exact GQ1-GQ5 policy digests.

The one allowed GQ6 selection execution then completed from a clean scoped
tree and immutable source snapshot:

```text
report = <evidence-root>\temp-roots-2026-07-28\sporespore_gq6_selection_exact_700cac2\20260727T092636502\report.json
report SHA-256 = 9ce057fd15ce489b8199bbc158c970dd720994bf484a172d74313e88f35e8f0a
result = 11/12 physical worlds, 297/300 assertions
engine errors = 0
timeouts = 0
containment failures = 0
selection_eligible = false
```

Eleven fresh morphologies passed `25/25`. `gq6_generated_s050` completed its
four-cycle horizon with zero contact-gate timeouts and moved strongly forward,
but failed the lateral-drift walking gate:

```text
torso_length_scale = 0.9796875
torso_width_scale = 1.0364197530864199
upper_length_fraction = 0.5073714285714286
hip_span_scale = 0.9645772594752187
foot_radius_scale = 1.0078512396694215
front_limb_mass_scale = 1.0181952662721894
morphology_interaction_score = 0.692711698
maximum permitted lateral drift = 0.103641975308642 m
evidence lateral displacement = 0.107279 m
final lateral displacement = 0.145326 m
evidence forward displacement = 0.910018 m
final forward displacement = 1.064748 m
maximum anchor error = 0.022240119 m
maximum hinge-axis error = 0.101119064 rad
minimum torso height = 0.426444054 m
```

The evidence and final lateral displacements exceeded the unchanged
dimensionless bound. That one physical failure produced the three expected
failed assertions: the aggregate walking-gate assertion, normalized metric
bounds, and final walking predicate. It was not a contact, timeout, forward
movement, anchor, hinge, height, engine, harness, or containment failure.

Per the preregistered stopping rule, GQ6 is rejected. There is no eligible GQ6
selection rerun, and held-out indices `501-508` remain unexecuted. All GQ6
selection bodies `49-60` are now opened development data for a later,
separately preregistered successor. The GQ6 report must not be combined with
the Candidate 24 development reports or described as completed morphology
generalization.

#### Preregistered G4-GQ7 smooth high-interaction confirmation

GQ7 is preregistered after the exact GQ6 selection rejection and bounded
successor development, but before any GQ7 implementation, generated-body
calculation, static compilation, or physics. GQ1-GQ6 selection bodies and the
legitimately opened GQ2 held-outs are development data. GQ3-GQ6 held-out
indices `201-208`, `301-308`, `401-408`, and `501-508` remain unopened and may
not be calculated or used by GQ7.

One pre-preregistration fail-closed check asked the GQ6 generator for index
`61`; it returned `UNKNOWN_GQ6_GENERATOR_INDEX`. That did not calculate a
GQ7 body, execute a GQ7 generator formula, compile a fixture, or construct a
physics world. No GQ7 selection or held-out index has been calculated by any
generator before this preregistration.

##### Frozen Candidate 25 development basis

The exact GQ6 result isolated one failure: `gq6_generated_s050` walked strongly
forward, completed all four evidence cycles, and stayed within every contact,
anchor, hinge, height, yaw, and engine boundary, but exceeded the lateral-drift
limit. Its frozen morphology was in the high-interaction, wide-torso,
short-torso branch:

```text
S = 0.692711698
W = 1.0364197530864199
L = 0.9796875
GQ6 cross-track velocity gain = 0.20 rad / (m/s)
```

Candidate 25 changes only that smooth morphology region. It does not inspect
the morphology ID, generator index, seed, campaign role, repetition, prior
result, runtime outcome, or failure list. Private development on the already
opened `s050` body passed `25/25` and changed its final lateral displacement
from `0.145326 m` to `0.009993 m`, while final forward displacement increased
from `1.064748 m` to `1.263911 m`.

Two previously opened, non-extreme affected bodies were then checked
individually: GQ3 `s014` and GQ4 `s026` each passed `25/25`. Finally, every
opened GQ6 selection body `49-60` passed `300/300` assertions under the frozen
Candidate 25 formula:

| opened development check | result | report or transcript SHA-256 |
|---|---:|---|
| GQ6 `s050` | `1/1`, `25/25` | `d45cdcd805ca91a09ac9e8f79ca84ffda778e9a408185c46ee1734e753f4f209` |
| GQ3 `s014` | `1/1`, `25/25` | `673c0eb00b91bdcf80ba60f5aec6ea5ab3851e7caf8e54a8c37b29882a707c47` |
| GQ4 `s026` | `1/1`, `25/25` | `22eddb7906428b6e1bde01ab8f13dd1a7c6f29b1b08aa00b9fa6877bcfc47dff` |
| GQ6 selection `49-60` | `12/12`, `300/300` | `f37d7f2158527dd1a960696f2c73b3b4e2ec7e1d74a4c1b846211bdb8ddab5b3` |

The full development report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq7_dev_candidate25_gq6_selection12\20260727T094255430\report.json
```

The report correctly refuses evidence eligibility because its source was dirty
and every simulated body was already open. These development observations
freeze the successor design; they are not GQ7 evidence and establish no new
accepted walking-family claim.

##### Frozen GQ7 morphology and controller formulas

Let `L`, `W`, `U`, `H`, `F`, `M`, and `S` have exactly the same definitions,
normalization, and interaction calculation as GQ6:

```text
L = torso_length_scale
W = torso_width_scale
U = upper_length_fraction
H = hip_span_scale
F = foot_radius_scale
M = front_limb_mass_scale

dL = abs((L - 1.0) / 0.10)
dW = abs((W - 1.0) / 0.10)
dU = abs((U - 18/35) / 0.05)
dH = abs((H - 1.0) / 0.10)
dF = abs((F - 1.0) / 0.10)
dM = abs((M - 1.0) / 0.10)
S = clamp(sum(i < j, di * dj), 0.0, 1.0)
```

Cross-track position feedback remains exactly:

```text
cross_track_heading_gain_rad_per_m =
  1.0 if S < 0.5 else 0.75
```

Yaw feedback remains exactly:

```text
if F < 0.985:
  yaw_error_stride_gain_per_rad = 1.3 if S >= 0.9 else 1.1
elif S < 0.5 or F > 1.025:
  yaw_error_stride_gain_per_rad = 1.0
elif F > 1.01:
  yaw_error_stride_gain_per_rad = 1.3
elif abs(H - 1.0) >= 0.02:
  yaw_error_stride_gain_per_rad = 1.1 if L > 1.02 else 1.0
else:
  yaw_error_stride_gain_per_rad = 1.0
```

Let `Y` be the resulting yaw gain. Candidate 25 freezes cross-track velocity
feedback as:

```text
if Y > 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20
elif S < 0.15:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20 if W <= 1.0 else 0.25
elif S < 0.5:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.30 if W <= 1.0 else 0.20
elif W > 1.0 and L < 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = (
    0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
  )
else:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.25
```

The new curve is continuous over its declared `0.5 <= S <= 1.0` domain:
`S == 0.5` yields `0.25`, `S == 1.0` yields `0.20`, and the frozen `s050`
score yields approximately `0.2307288302`. The curve applies only when
`Y <= 1.0`, `W > 1.0`, and `L < 1.0`. All yaw-amplified bodies remain at
`0.20`; bodies with `S < 0.5` retain the exact GQ6 branches; high-interaction
bodies with `W <= 1.0` or `L >= 1.0` remain at `0.25`.

Boundary inclusion is exact:

- `F == 0.985` proceeds to the score/large-foot branches;
- `S == 0.9` receives small-foot yaw `1.3`;
- `S == 0.5` receives cross-track position gain `0.75` and, in the eligible
  wide-short region, velocity gain `0.25`;
- `S == 0.15` proceeds to the moderate-interaction width split;
- `F == 1.025` receives yaw `1.3`;
- `F == 1.01` proceeds to the hip branch;
- `abs(H - 1.0) == 0.02` enters the hip branch;
- `L == 1.02` receives hip-branch yaw `1.0`;
- `W == 1.0` is outside the smooth wide-torso curve; and
- `L == 1.0` is outside the smooth short-torso curve.

No additional interpolation, epsilon, hysteresis, warning band, fallback,
lookup table, or runtime performance measurement may change these branches.
The gain must be compiled before world construction and sealed in the
controller receipt.

Desired-heading calculation, the `0.40` stride-side steering-fraction cap, and
the `90`-tick steering update interval remain exactly GQ6. Motor velocity
feedback also remains GQ6-derived: `S >= 0.5` selects the `0.80` activation
fraction and `2.0 rad/s` cap; lower scores select `0.90` and `2.5 rad/s`.

The clock is a distinct GQ7 receipt with the same numerical values as GQ6:
unit-scale `120 Hz`, `360`-tick cycles, `4` evidence cycles, one warmup cycle,
one cooldown cycle, `240` settle ticks, `240` terminal-settle ticks, a maximum
`120`-tick contact-gate hold, maximum `720`-tick bounded evidence extension,
and maximum `12`-tick phase skew. Each limb must complete exactly `1440`
ungated evidence ticks. Timeout, partial contact progression, or excess
extension fails closed.

The GQ7 solver and structural thresholds remain exactly GQ6:

```text
physics_engine = Jolt Physics
physics_hz = 120
solver_velocity_steps = 20
solver_position_steps = 7

minimum_foot_relocation_m = 0.0238 * torso_length_m
maximum_anchor_error_m = 0.14 * upper_leg_length_m
```

All other evidence thresholds remain unchanged, including forward movement,
lateral drift, yaw, tilt, torso height, and hinge-axis limits.

##### Fresh GQ7 population and distinct receipts

GQ7 reuses the exact GQ1 radical-inverse calculation, six axes, prime bases,
asymmetric intervals, and four-shell schedule. Its fresh selection indices,
fixed before implementation or generated-body calculation, are:

```text
61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71, 72
```

Their required IDs are `gq7_generated_s061` through
`gq7_generated_s072`. The fresh held-out indices are:

```text
601, 602, 603, 604, 605, 606, 607, 608
```

Their required IDs are `gq7_generated_s601` through
`gq7_generated_s608`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ7`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq7_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq7_generation_receipt_v1
policy_schema_version = sporespore_g4_gq7_smooth_high_interaction_velocity_feedback_policy_v1
clock_policy_id = g4_gq7_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v12
```

All GQ7 generator, fixture, policy, controller, clock, solver, threshold,
source, assertion, and containment receipts must be deterministic and distinct
where their declared inputs differ.

##### Frozen preservation, execution, and stopping contract

GQ7 must be implemented as a distinct campaign policy. Rejected GQ1-GQ6
source behavior, selection reports, and held-out locks remain unchanged.
The following policy digests must reproduce exactly:

```text
GQ1 policy = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 policy = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 policy = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 policy = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
GQ5 policy = sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
GQ6 policy = sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f
```

Before eligible physics, zero-world tests must independently reconstruct all
20 fresh GQ7 generator receipts and reverse lookups, prove selection/held-out
disjointness, compile every fixture and static screen, exercise every formula
boundary including interior points of the smooth curve, prove
ID/index/seed/role/repetition/outcome independence, seal GQ7 clock/solver/
threshold/controller/policy receipts, reject malformed requests closed, and
retain the exact GP1-GP5 and GQ1-GQ6 regression.

Eligible evidence requires a pushed implementation commit, clean scoped source
tree, immutable per-cell source snapshots, the approved isolated hidden
runner, zero engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ7 worlds must pass
`300/300` assertions in one execution. Any selection failure rejects GQ7,
permanently leaves indices `601-608` unopened, and permits no eligible
selection rerun.

Only a complete selection opens all eight held-out bodies for all three frozen
perturbations. The runner must execute all three repetitions unchanged once
opened, even if an earlier repetition fails. Held-out completion requires
`24/24` worlds and `600/600` assertions. No post-selection edit, threshold
change, candidate swap, selective rerun, or newly observed branch may become
GQ7 evidence.

Complete GQ7 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source vector. A complete result would establish
this bounded procedurally generated quadruped family for its fresh fixed
indices and perturbations. It would not establish every seed, continuous
full-volume coverage, arbitrary quadrupeds, automatic morphology synthesis,
another limb count, running, or automatic creature guidance.

#### G4-GQ7 exact selection result: rejected at 9/12

The distinct GQ7 implementation was committed and pushed before physics:

```text
preregistration commit = 53e4d834bb47213739f4f1847a601dec59b37393
implementation commit = 274c3e38e8bd32c12c351ceff00ebbf2bb54f6f3
formula policy = sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346
```

The zero-world gate passed `78/78` assertions with zero engine errors. It
independently reconstructed all 20 GQ7 generator receipts, compiled every
fixture and static screen without physics, exercised the smooth curve at its
boundaries and interior points, proved the GQ7 clock/solver/threshold receipts,
and reproduced the exact GQ1-GQ6 policy digests.

The one allowed GQ7 selection execution then completed from the clean pushed
source and immutable per-cell snapshots:

```text
report = <evidence-root>\temp-roots-2026-07-28\sporespore_gq7_selection_exact_274c3e3\20260727T100657196\report.json
report SHA-256 = 3621237bc5d062215c0c93d73f3c86064d112fbd6cfa0ba9a4cde96e4b95021c
result = 9/12 physical worlds, 291/300 assertions
engine errors = 0
timeouts = 0
containment failures = 0
source_scope_clean = true
formula_policy_digest_consistent = true
selection_eligible = false
```

Nine fresh morphologies passed `25/25`. `gq7_generated_s061`, `s063`, and
`s069` each completed the four-cycle horizon, exceeded one meter of final
forward travel, and stayed within the contact, anchor, hinge, height, yaw,
engine, harness-containment, and timeout boundaries. Each exceeded only the
unchanged dimensionless lateral-drift walking gate:

| body | `S` | velocity gain | evidence lateral | final lateral | permitted lateral |
|---|---:|---:|---:|---:|---:|
| `s061` | `0.063507597` | `0.25` | `0.104244 m` | `0.108238 m` | `0.100401 m` |
| `s063` | `1.000000000` | `0.25` | `0.120278 m` | `0.185694 m` | `0.093426 m` |
| `s069` | `0.157268746` | `0.30` | `0.078937 m` | `0.122852 m` | `0.098920 m` |

The structural and forward receipts remained healthy:

| body | final forward | maximum anchor error | maximum hinge error | minimum height |
|---|---:|---:|---:|---:|
| `s061` | `1.267792 m` | `0.022455581 m` | `0.116716926 rad` | `0.427192777 m` |
| `s063` | `1.141033 m` | `0.018316632 m` | `0.084025413 rad` | `0.425107002 m` |
| `s069` | `1.328324 m` | `0.021865612 m` | `0.104768017 rad` | `0.427056462 m` |

The three failures occupy different score regions and none enters Candidate
25's new high-interaction, wide-torso, short-torso smooth branch:

```text
s061: S=0.063507597, L=1.01171875, W=1.0040123456790124, gain=0.25
s063: S=1.0,         L=1.07265625, W=0.9342592592592592, gain=0.25
s069: S=0.157268746, L=1.006640625, W=0.9891975308641975, gain=0.30
```

GQ7 therefore falsifies the narrower hypothesis that the remaining lateral
generalization failure was confined to the GQ6 `s050` region. It does not
falsify physical walking: all 12 bodies moved forward through the complete
four-cycle physical protocol, and only the lateral predicate rejected three.

Per the preregistered stopping rule, GQ7 is rejected. There is no eligible
selection rerun, and held-out indices `601-608` remain uncalculated in physics
and unopened. All selection bodies `61-72` are now opened development data for
a separately preregistered successor. The exact report may not be combined
with development reruns or described as completed morphology generalization.

#### Preregistered G4-GQ8 boosted velocity-feedback confirmation

GQ8 is preregistered after the exact GQ7 selection rejection and bounded
successor development, but before any GQ8 implementation, generated-body
calculation, static compilation, or physics. GQ1-GQ7 selection bodies and the
legitimately opened GQ2 held-outs are development data. GQ3-GQ7 held-out
indices `201-208`, `301-308`, `401-408`, `501-508`, and `601-608` remain
unopened and may not be calculated or used by GQ8.

One fail-closed GQ7 no-world self-check asked the GQ7 generator for index `73`
and received `UNKNOWN_GQ7_GENERATOR_INDEX`. That check did not execute a GQ8
generator formula, calculate a GQ8 body, compile a fixture, or construct a
physics world. No GQ8 selection or held-out index has been calculated by any
generator before this preregistration.

##### Frozen Candidate 27 development basis

The exact GQ7 result isolated three lateral-only failures in distinct
interaction-score regions. All three completed the four-cycle horizon, moved
more than one meter forward, and retained healthy contact, anchor, hinge,
height, yaw, engine, timeout, and containment receipts:

```text
s061: S=0.063507597, L=1.01171875, W=1.0040123456790124, gain=0.25
s063: S=1.0,         L=1.07265625, W=0.9342592592592592, gain=0.25
s069: S=0.157268746, L=1.006640625, W=0.9891975308641975, gain=0.30
```

Candidate 26 raised only non-yaw-amplified cross-track velocity-feedback
branches. It repaired opened `s061` and `s063`, retained the other nine opened
GQ7 passes, and reduced `s069` lateral drift, but `s069` still finished at
`0.118457 m` against its `0.098919753 m` bound. The complete opened GQ7
development result was `11/12`, `297/300`.

Candidate 27 changed only Candidate 26's moderate-interaction, narrow-torso
branch from `0.35` to `0.60 rad / (m/s)`. Exactly two opened GQ7 bodies occupy
that branch: `s066` and `s069`. Under Candidate 27, `s066` finished at
`-0.006929 m` lateral and `1.360307 m` forward; `s069` finished at
`0.047234 m` lateral and `1.372272 m` forward. Every opened GQ7 selection body
then passed:

| opened development check | result | report SHA-256 |
|---|---:|---|
| Candidate 26, GQ7 selection `61-72` | `11/12`, `297/300` | `080156330a7cb740f2b0dc6944e57ac6af75b1c040cf1e42290d976c17b75c13` |
| Candidate 27, GQ7 selection `61-72` | `12/12`, `300/300` | `fc22f78ea9b4d784dfb9764d327318113911b1ada2dad126ca1a2cc83a951685` |

The complete Candidate 27 development report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq8_dev_candidate27_mid_narrow060_gq7_selection12\
  20260727T102751736\report.json
```

The report correctly refuses selection eligibility because its source was
dirty and all simulated bodies were already open. These observations freeze
the successor rule; they are not GQ8 evidence and establish no new accepted
walking-family claim.

##### Frozen GQ8 morphology and controller formulas

Let `L`, `W`, `U`, `H`, `F`, `M`, and `S` retain exactly the GQ7 definitions,
normalization, and interaction calculation:

```text
L = torso_length_scale
W = torso_width_scale
U = upper_length_fraction
H = hip_span_scale
F = foot_radius_scale
M = front_limb_mass_scale

dL = abs((L - 1.0) / 0.10)
dW = abs((W - 1.0) / 0.10)
dU = abs((U - 18/35) / 0.05)
dH = abs((H - 1.0) / 0.10)
dF = abs((F - 1.0) / 0.10)
dM = abs((M - 1.0) / 0.10)
S = clamp(sum(i < j, di * dj), 0.0, 1.0)
```

Cross-track position feedback remains exactly:

```text
cross_track_heading_gain_rad_per_m =
  1.0 if S < 0.5 else 0.75
```

Yaw feedback remains exactly:

```text
if F < 0.985:
  yaw_error_stride_gain_per_rad = 1.3 if S >= 0.9 else 1.1
elif S < 0.5 or F > 1.025:
  yaw_error_stride_gain_per_rad = 1.0
elif F > 1.01:
  yaw_error_stride_gain_per_rad = 1.3
elif abs(H - 1.0) >= 0.02:
  yaw_error_stride_gain_per_rad = 1.1 if L > 1.02 else 1.0
else:
  yaw_error_stride_gain_per_rad = 1.0
```

Let `Y` be the resulting yaw gain. Candidate 27 freezes cross-track velocity
feedback as:

```text
if Y > 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20
elif S < 0.15:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.25 if W <= 1.0 else 0.30
elif S < 0.5:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.60 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = (
    0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
  )
else:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.30
```

The smooth high-interaction, wide-torso, short-torso curve remains exactly
GQ7: `S == 0.5` yields `0.25`, `S == 1.0` yields `0.20`, and it applies only
when `Y <= 1.0`, `W > 1.0`, and `L < 1.0`. The remaining non-yaw-amplified
branches are the frozen Candidate 27 values above.

Boundary inclusion is exact:

- `F == 0.985` proceeds to the score/large-foot branches;
- `S == 0.9` receives small-foot yaw `1.3`;
- `S == 0.5` receives cross-track position gain `0.75` and, in the eligible
  wide-short region, velocity gain `0.25`;
- `S == 0.15` proceeds to the moderate-interaction width split;
- `F == 1.025` receives yaw `1.3`;
- `F == 1.01` proceeds to the hip branch;
- `abs(H - 1.0) == 0.02` enters the hip branch;
- `L == 1.02` receives hip-branch yaw `1.0`;
- `W == 1.0` is in the narrow-torso branch; and
- `L == 1.0` is outside the smooth short-torso curve.

No additional interpolation, epsilon, hysteresis, warning band, fallback,
lookup table, identity field, generator index, seed, role, repetition, or
runtime performance measurement may change these branches. Every gain must be
compiled before world construction and sealed in the controller receipt.

Desired-heading calculation, the `0.40` stride-side steering-fraction cap, and
the `90`-tick steering update interval remain exactly GQ7. Motor velocity
feedback also remains GQ7-derived: `S >= 0.5` selects the `0.80` activation
fraction and `2.0 rad/s` cap; lower scores select `0.90` and `2.5 rad/s`.

The clock is a distinct GQ8 receipt with the same numerical values as GQ7:
unit-scale `120 Hz`, `360`-tick cycles, `4` evidence cycles, one warmup cycle,
one cooldown cycle, `240` settle ticks, `240` terminal-settle ticks, a maximum
`120`-tick contact-gate hold, maximum `720`-tick bounded evidence extension,
and maximum `12`-tick phase skew. Each limb must complete exactly `1440`
ungated evidence ticks. Timeout, partial contact progression, or excess
extension fails closed.

The GQ8 solver and structural thresholds remain exactly GQ7:

```text
physics_engine = Jolt Physics
physics_hz = 120
solver_velocity_steps = 20
solver_position_steps = 7

minimum_foot_relocation_m = 0.0238 * torso_length_m
maximum_anchor_error_m = 0.14 * upper_leg_length_m
```

All other evidence thresholds remain unchanged, including forward movement,
lateral drift, yaw, tilt, torso height, and hinge-axis limits.

##### Fresh GQ8 population and distinct receipts

GQ8 reuses the exact GQ1 radical-inverse calculation, six axes, prime bases,
asymmetric intervals, and four-shell schedule. Its fresh selection indices,
fixed before implementation or generated-body calculation, are:

```text
73, 74, 75, 76, 77, 78, 79, 80, 81, 82, 83, 84
```

Their required IDs are `gq8_generated_s073` through
`gq8_generated_s084`. The fresh held-out indices are:

```text
701, 702, 703, 704, 705, 706, 707, 708
```

Their required IDs are `gq8_generated_s701` through
`gq8_generated_s708`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ8`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq8_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq8_generation_receipt_v1
policy_schema_version = sporespore_g4_gq8_boosted_velocity_feedback_policy_v1
clock_policy_id = g4_gq8_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v13
```

All GQ8 generator, fixture, policy, controller, clock, solver, threshold,
source, assertion, and containment receipts must be deterministic and distinct
where their declared inputs differ.

##### Frozen preservation, execution, and stopping contract

GQ8 must be implemented as a distinct campaign policy. Rejected GQ1-GQ7
source behavior, reports, and held-out locks remain unchanged. The following
policy digests must reproduce exactly:

```text
GQ1 policy = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 policy = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 policy = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 policy = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
GQ5 policy = sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
GQ6 policy = sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f
GQ7 policy = sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346
```

Before eligible physics, zero-world tests must independently reconstruct all
20 fresh GQ8 generator receipts and reverse lookups, prove selection/held-out
disjointness, compile every fixture and static screen, exercise every formula
boundary and interior point, prove ID/index/seed/role/repetition/outcome
independence, seal GQ8 clock/solver/threshold/controller/policy receipts,
reject malformed requests closed, and retain the exact GP1-GP5 and GQ1-GQ7
regression.

Eligible evidence requires a pushed implementation commit, clean scoped source
tree, immutable per-cell source snapshots, the approved isolated hidden
runner, zero engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ8 worlds must pass
`300/300` assertions in one execution. Any selection failure rejects GQ8,
permanently leaves indices `701-708` unopened, and permits no eligible
selection rerun.

Only a complete selection opens all eight held-out bodies for all three frozen
perturbations. The runner must execute all three repetitions unchanged once
opened, even if an earlier repetition fails. Held-out completion requires
`24/24` worlds and `600/600` assertions. No post-selection edit, threshold
change, candidate swap, selective rerun, or newly observed branch may become
GQ8 evidence.

Complete GQ8 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source vector. A complete result would establish
this bounded procedurally generated quadruped family for its fresh fixed
indices and perturbations. It would not establish every seed, continuous
full-volume coverage, arbitrary quadrupeds, automatic morphology synthesis,
another limb count, running, or automatic creature guidance.

#### G4-GQ8 exact selection result: rejected at 11/12

The distinct GQ8 implementation was committed and pushed before physics:

```text
preregistration commit = 837ab784734e57551d1422968b6e8e0166643cb1
implementation commit = 55b5cd41e2920c5d949946156bc8cc56f39c4f1f
formula policy = sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0
```

The independent zero-world compiler gate passed `84/84` assertions and the
no-argument physical harness gate passed `1/1`, both with zero engine errors:

```text
compiler report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq8_impl_no_world_test10\
    20260727T104709582\report.json
compiler report SHA-256 =
  cf85c22d94d4c7f9a953572fb6bff9e9a289ce3d056aa0939602452bb6e36982

harness report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq8_impl_no_world_test11\
    20260727T104728611\report.json
harness report SHA-256 =
  d0fcca7431b4920d42510f33a79a1d850f8e73b6091f76ad25f9353756bb6150
```

The compiler independently reconstructed all 20 GQ8 generation receipts,
compiled every fixture and static screen without physics, exercised every
Candidate 27 controller boundary, proved the distinct GQ8 clock and exact
20/7 solver/threshold receipts, and reproduced the exact GQ1-GQ7 policy
digests.

The single allowed GQ8 selection execution then completed from the clean
pushed source and immutable per-cell snapshots:

```text
report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq8_selection_exact_55b5cd4\
    20260727T104849229\report.json
report SHA-256 =
  c284052e45ae5ac8dd413218a9eaabdfdb6e713aede5fe0909f8097d8e326cf2
result = 11/12 physical worlds, 297/300 assertions
engine errors = 0
timeouts = 0
containment failures = 0
source_scope_clean = true
formula_policy_digest_consistent = true
selection_eligible = false
```

Eleven fresh morphologies passed `25/25`. `gq8_generated_s084` completed the
four-cycle horizon, moved strongly forward, and retained healthy contact,
anchor, hinge, height, yaw, engine, timeout, and containment receipts. Its one
underlying physical failure was lateral drift:

```text
S = 1.0
L = 0.9328125
W = 0.923045267489712
H = 0.920991253644315
F = 1.03884297520661
yaw gain = 1.0
velocity gain = 0.30 rad / (m/s)

evidence forward = 1.048639 m
evidence lateral = -0.098785 m
final forward = 1.239687 m
final lateral = -0.107007 m
permitted lateral magnitude = 0.092304527 m
maximum anchor error = 0.017019968 m
maximum hinge error = 0.092628412 rad
minimum torso height = 0.429646730 m
```

The three failed assertions are the direct metric predicate and its two
aggregate walking predicates; they do not represent three independent
mechanical failures. The body exceeded the final lateral limit by
`0.014702473 m` and the evidence lateral limit by `0.006480473 m`.

Per the preregistered stopping rule, GQ8 is rejected. There is no eligible
selection rerun, and held-out indices `701-708` remain uncalculated in physics
and unopened. All selection bodies `73-84` are now opened development data for
a separately preregistered successor. The exact GQ8 report may not be combined
with development reruns or described as completed morphology generalization.

#### Preregistered G4-GQ9 high-fallback velocity-feedback confirmation

GQ9 is preregistered after the exact GQ8 selection rejection and bounded
successor development, but before any GQ9 implementation, generated-body
calculation, static compilation, or physics. GQ1-GQ8 selection bodies and the
legitimately opened GQ2 held-outs are development data. GQ3-GQ8 held-out
indices `201-208`, `301-308`, `401-408`, `501-508`, `601-608`, and `701-708`
remain unopened and may not be calculated or used by GQ9.

One fail-closed GQ8 no-world self-check asked the GQ8 generator for index `85`
and received `UNKNOWN_GQ8_GENERATOR_INDEX`. That check did not execute a GQ9
generator formula, calculate a GQ9 body, compile a fixture, or construct a
physics world. No GQ9 selection or held-out index has been calculated by any
generator before this preregistration.

##### Frozen Candidate 28 development basis

The exact GQ8 result isolated one lateral-only failure:
`gq8_generated_s084`. It completed the four-cycle horizon, moved
`1.239687 m` forward, and retained healthy contact, anchor, hinge, height,
yaw, engine, timeout, and containment receipts. It occupied the
high-interaction, non-yaw-amplified fallback branch:

```text
S = 1.0
L = 0.9328125
W = 0.923045267489712
F = 1.03884297520661
GQ8 velocity gain = 0.30 rad / (m/s)
final lateral = -0.107007 m
permitted lateral magnitude = 0.092304527 m
```

Exactly three opened GQ8 selection bodies use this branch: `s075`, `s079`,
and `s084`. Candidate 28 changes only its gain from `0.30` to
`0.35 rad / (m/s)`. It does not inspect morphology identity, generator index,
seed, role, repetition, prior result, runtime outcome, or failure list.

The complete opened GQ8 development matrix then passed `12/12` worlds and
`300/300` assertions. The affected bodies retained strong forward motion and
healthy structural margins:

| body | final forward | final lateral | maximum anchor | maximum hinge |
|---|---:|---:|---:|---:|
| `s075` | `1.291090 m` | `0.036484 m` | `0.019021802 m` | `0.099045449 rad` |
| `s079` | `1.362181 m` | `0.059866 m` | `0.021805316 m` | `0.094521706 rad` |
| `s084` | `1.270496 m` | `0.029159 m` | `0.016986748 m` | `0.090267608 rad` |

The complete Candidate 28 development report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq9_dev_candidate28_high_fallback035_gq8_selection12\
  20260727T105632561\report.json
report SHA-256 =
  f57c851637f44137637feac5bf9c8ebe7681575abab057a796c59993ebacacdb
```

The report correctly refuses selection eligibility because its source was
dirty and all simulated bodies were already open. This observation freezes
the successor rule; it is not GQ9 evidence and establishes no new accepted
walking-family claim.

##### Frozen GQ9 morphology and controller formulas

GQ9 retains exactly GQ8's morphology variables, normalization, pairwise
interaction score, cross-track position feedback, yaw feedback, motor guard,
clock values, solver, structural thresholds, and all walking predicates.

Let `L`, `W`, `H`, `F`, `S`, and `Y` have the exact GQ8 meanings. Candidate 28
freezes cross-track velocity feedback as:

```text
if Y > 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20
elif S < 0.15:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.25 if W <= 1.0 else 0.30
elif S < 0.5:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.60 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = (
    0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
  )
else:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.35
```

Only the final fallback differs from GQ8. The smooth high-interaction,
wide-torso, short-torso curve remains continuous on `0.5 <= S <= 1.0` and
unchanged. All boundary inclusions remain exact:

- `Y > 1.0` takes precedence over every score and width branch;
- `S == 0.15` enters the moderate-interaction width split;
- `S == 0.5` enters the high-interaction region;
- `W == 1.0` is in the narrow-torso branch below `S == 0.5`;
- `W > 1.0` and `L < 1.0` select the smooth curve at high interaction;
- `L == 1.0` is outside the smooth short-torso curve; and
- every remaining high-interaction, non-yaw-amplified morphology receives
  `0.35 rad / (m/s)`.

No interpolation outside the declared smooth curve, epsilon, hysteresis,
warning band, fallback override, lookup table, identity field, generator
index, seed, role, repetition, or runtime performance measurement may change
these branches. Every gain must compile before world construction and seal in
the controller receipt.

The GQ9 clock is a distinct receipt with the exact GQ8 numerical values:
unit-scale `120 Hz`, `360`-tick cycles, `4` evidence cycles, one warmup cycle,
one cooldown cycle, `240` settle ticks, `240` terminal-settle ticks, maximum
`120`-tick contact-gate hold, maximum `720`-tick evidence extension, maximum
`12`-tick phase skew, and `90`-tick steering updates. The solver remains Jolt
at `20` velocity and `7` position iterations.

##### Fresh GQ9 population and distinct receipts

GQ9 reuses the exact radical-inverse calculation, six axes, prime bases,
asymmetric intervals, and four-shell schedule. Its fresh selection indices,
fixed before implementation or generated-body calculation, are:

```text
85, 86, 87, 88, 89, 90, 91, 92, 93, 94, 95, 96
```

Their required IDs are `gq9_generated_s085` through
`gq9_generated_s096`. The fresh held-out indices are:

```text
801, 802, 803, 804, 805, 806, 807, 808
```

Their required IDs are `gq9_generated_s801` through
`gq9_generated_s808`. None of these 20 indices has been calculated, compiled,
or run in physics before this preregistration.

The campaign identity is `G4-GQ9`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq9_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq9_generation_receipt_v1
policy_schema_version = sporespore_g4_gq9_high_fallback_velocity_feedback_policy_v1
clock_policy_id = g4_gq9_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v14
```

All GQ9 generator, fixture, policy, controller, clock, solver, threshold,
source, assertion, and containment receipts must be deterministic and distinct
where their declared inputs differ.

##### Frozen preservation, execution, and stopping contract

GQ9 must be implemented as a distinct campaign policy. Rejected GQ1-GQ8
source behavior, reports, and held-out locks remain unchanged. These policy
digests must reproduce exactly:

```text
GQ1 = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
GQ5 = sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
GQ6 = sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f
GQ7 = sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346
GQ8 = sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0
```

Before eligible physics, zero-world tests must reconstruct all 20 fresh GQ9
generator receipts and reverse lookups, compile every fixture and static
screen, exercise every controller boundary and interior smooth-curve point,
prove identity/outcome independence, seal the GQ9 clock, solver, thresholds,
controller, and policy, reject malformed requests closed, and retain exact
GP1-GP5 and GQ1-GQ8 regression.

Eligible evidence requires a pushed implementation commit, clean scoped source
tree, immutable per-cell source snapshots, the approved isolated hidden
runner, zero engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ9 worlds must pass
`300/300` assertions in one execution. Any selection failure rejects GQ9,
permanently leaves indices `801-808` unopened, and permits no eligible
selection rerun.

Only a complete selection opens all eight held-out bodies for all three frozen
perturbations. The runner must execute all three repetitions unchanged once
opened. Held-out completion requires `24/24` worlds and `600/600` assertions.
No post-selection edit, threshold change, candidate swap, selective rerun, or
newly observed branch may become GQ9 evidence.

Complete GQ9 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source vector. A complete result would establish
this bounded procedurally generated quadruped family for its fresh fixed
indices and perturbations. It would not establish every seed, continuous
full-volume coverage, arbitrary quadrupeds, automatic morphology synthesis,
another limb count, running, or automatic creature guidance.

#### G4-GQ9 exact result: selection passed, held-out confirmation rejected

The distinct GQ9 implementation was committed and pushed before physics:

```text
preregistration commit = 968ae2a5c8bec3b65e3b01104a4b0d0c585ebdf5
implementation commit = 91ddc3d546d7ca304b73150e05a558d239d6e8db
formula policy = sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74
```

The independent zero-world compiler gate passed `90/90` assertions and the
no-argument harness gate passed `1/1`, both with zero engine errors:

```text
compiler report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq9_impl_no_world_test10\
    20260727T111259660\report.json
compiler report SHA-256 =
  f5ae856c6a85d63eef73c903e55df0cade9ae4eea2a14e5d7e739b677042c236

harness report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq9_impl_no_world_test11\
    20260727T111316661\report.json
harness report SHA-256 =
  230850c5b385c0055e693fb0f76327f0391f55b5a7580bc563c816a2ce4eca11
```

The compiler independently reconstructed all 20 GQ9 generation receipts,
compiled every fixture and static screen without physics, exercised every
Candidate 28 controller boundary, proved the distinct GQ9 clock and exact
20/7 solver/threshold receipts, and reproduced the exact GQ1-GQ8 policy
digests.

##### Exact clean GQ9 selection: passed

The single allowed selection execution passed completely:

```text
report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq9_selection_exact_91ddc3d\
    20260727T111357815\report.json
report SHA-256 =
  ba3c40ef8fcb1ff32df9e749a46b9e8343946b0a1f81b3bac7187abbde72fafa
result = 12/12 physical worlds, 300/300 assertions
engine errors = 0
timeouts = 0
containment failures = 0
source_scope_clean = true
formula_policy_digest_consistent = true
selection_eligible = true
```

That complete selection legitimately opened held-out indices `801-808` for
all three frozen repetitions. It did not by itself establish complete GQ9
confirmation.

##### Exact clean GQ9 held-outs: incomplete at 22/24

Per the preregistered contract, all three held-out repetitions executed
unchanged even after repetition 1 failed:

| repetition | result | assertions | report SHA-256 |
|---:|---:|---:|---|
| R1 | `7/8` | `197/200` | `c0a6d608f8252adda7473678630bd834a3ff4525d59cb0f4735a7f8ab13492dc` |
| R2 | `8/8` | `200/200` | `e260d98099b9c08799d919b37fee74db706d7279a510c869f6a16de64b7ac6cb` |
| R3 | `7/8` | `197/200` | `61a24f443624867ee3af65304b5b6b0244475b58f2f12ba39507e40ad590b7c3` |

The reports are:

```text
R1 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq9_heldout_r1_exact_91ddc3d\
    20260727T111954253\report.json
R2 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq9_heldout_r2_exact_91ddc3d\
    20260727T112331464\report.json
R3 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq9_heldout_r3_exact_91ddc3d\
    20260727T112707714\report.json
```

All three reports retained the exact pushed source, clean scope, consistent
formula-policy digest, immutable per-cell snapshots, zero engine errors, zero
timeouts, and closed containment trees. R2 passed completely. The two failed
worlds were distinct bodies and repetitions, and each exceeded only the
width-normalized lateral-drift predicate.

R1 `gq9_generated_s805`:

```text
S = 0.101659970
L = 1.007177734375
W = 1.0021833561957
F = 0.996802216378663
branch = low-interaction, wide torso
velocity gain = 0.30 rad / (m/s)

evidence forward = 1.100402 m
evidence lateral = 0.084191 m
final forward = 1.279831 m
final lateral = 0.109504 m
permitted lateral magnitude = 0.100218336 m
maximum anchor error = 0.024293212 m
maximum hinge error = 0.125581235 rad
minimum torso height = 0.427681178 m
```

R3 `gq9_generated_s802`:

```text
S = 0.377199372
L = 0.97685546875
W = 0.993255601280293
F = 1.04631855747558
branch = moderate-interaction, narrow torso
velocity gain = 0.60 rad / (m/s)

evidence forward = 1.118907 m
evidence lateral = -0.112653 m
final forward = 1.317829 m
final lateral = -0.099967 m
permitted lateral magnitude = 0.099325560 m
maximum anchor error = 0.018570261 m
maximum hinge error = 0.093873432 rad
minimum torso height = 0.428629100 m
```

Each world reported three failed assertions because the direct metric
predicate propagates into two aggregate walking predicates. There was one
underlying physical failure per world. Across selection and held-outs, GQ9
therefore completed `34/36` worlds and `894/900` assertions from one exact
source vector.

GQ9 establishes a successful fresh selection and a complete R2 perturbation,
but it does not establish the preregistered generated-family confirmation.
There is no eligible rerun or post-selection edit. All GQ9 selection and
held-out bodies and repetitions are now legitimately opened development data
for a separately preregistered successor.

#### Preregistered G4-GQ10 perturbation-margin velocity-feedback confirmation

GQ10 is preregistered after the complete exact GQ9 result and bounded
successor development, but before any GQ10 implementation, generated-body
calculation, static compilation, or physics. All GQ1-GQ9 selection bodies and
all three legitimately opened GQ2 and GQ9 held-out repetitions are
development data. GQ3-GQ8 held-out indices `201-208`, `301-308`, `401-408`,
`501-508`, `601-608`, and `701-708` remain unopened and may not be calculated
or used by GQ10.

One fail-closed GQ9 no-world self-check asked the GQ9 generator for index `97`
and received `UNKNOWN_GQ9_GENERATOR_INDEX`. That check did not execute a GQ10
generator formula, calculate a GQ10 body, compile a fixture, or construct a
physics world. No GQ10 selection or held-out index has been calculated by any
generator before this preregistration.

##### Frozen Candidate 29 development basis

The exact GQ9 held-outs isolated two lateral-only failures on otherwise
healthy four-cycle walkers:

- R1 `gq9_generated_s805` occupied the low-interaction, wide-torso branch,
  moved `1.279831 m` forward, and ended at `0.109504 m` lateral against a
  `0.100218336 m` limit with velocity gain `0.30 rad / (m/s)`.
- R3 `gq9_generated_s802` occupied the moderate-interaction, narrow-torso
  branch, moved `1.317829 m` forward, and ended at `-0.099967 m` lateral
  against a `0.099325560 m` limit with velocity gain `0.60 rad / (m/s)`.

Both retained healthy contact, anchor, hinge, height, yaw, engine, timeout,
and containment receipts. Candidate 29 changes only the two implicated
morphology branches:

```text
S < 0.15 and W > 1.0: 0.30 -> 0.35 rad / (m/s)
S < 0.5 and W <= 1.0: 0.60 -> 0.70 rad / (m/s)
```

It does not inspect morphology identity, generator index, seed, role,
repetition, prior result, runtime outcome, or failure list. It changes no
clock, solver, motor limit, gait phase, structural threshold, perturbation, or
walking predicate.

The complete already-opened GQ9 development matrix then passed `36/36` worlds
and `900/900` assertions from one Candidate 29 source fingerprint:

| opened matrix | result | assertions | report SHA-256 |
|---|---:|---:|---|
| selection | `12/12` | `300/300` | `b436e4a12fc139136093ec62117913a4b6352c7825a7fe32740c425acc793738` |
| held-out R1 | `8/8` | `200/200` | `aac8bb03aad9b397713677a9752f26e1464c38bc6916bdac2f784521c6996701` |
| held-out R2 | `8/8` | `200/200` | `067b74fce1a362c7d8c51d196524c319a88e3e3f5bbe158ba22d74af0ca8cccf` |
| held-out R3 | `8/8` | `200/200` | `c8d9c81282d5a6adecdb1da8d3d0ce7f373a9fdd8548165779e5b978ef4de59e` |

The reports are:

```text
selection =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_dev_candidate29_lowwide035_midnarrow070_gq9_selection12\
    20260727T114723072\report.json
R1 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_dev_candidate29_lowwide035_midnarrow070_gq9_r1\
    20260727T113604861\report.json
R2 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_dev_candidate29_lowwide035_midnarrow070_gq9_r2\
    20260727T114344274\report.json
R3 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_dev_candidate29_lowwide035_midnarrow070_gq9_r3\
    20260727T113956008\report.json
```

All four reports share Candidate 29 policy digest
`sha256:645f7089755537a64c4aa3f3d28ec6954a289834016e2b93e6ba26d9f98640da`,
retain consistent formula-policy receipts, report every world walking, and
contain zero failed physical assertions, engine-error cells, timeouts, or
containment failures. They correctly refuse selection or held-out eligibility
because the development source was dirty and every simulated body was already
open.

The repaired adverse cases retained forward motion and gained substantial
lateral margin:

| body and repetition | evidence lateral | final forward | final lateral |
|---|---:|---:|---:|
| `s805` R1 | `-0.038884 m` | `1.168031 m` | `-0.033705 m` |
| `s802` R3 | `-0.033567 m` | `1.277937 m` | `0.003581 m` |

The affected GQ9 selection body `s094` also passed at `1.372333 m` final
forward and `0.041374 m` final lateral. These observations freeze the
successor rule; they are not GQ10 evidence and establish no new accepted
walking-family claim.

##### Frozen GQ10 morphology and controller formulas

GQ10 retains exactly GQ9's morphology variables, normalization, pairwise
interaction score, cross-track position feedback, yaw feedback, motor guard,
clock values, solver, structural thresholds, perturbations, and all walking
predicates.

Let `L`, `W`, `H`, `F`, `S`, and `Y` have the exact GQ9 meanings. Candidate 29
freezes cross-track velocity feedback as:

```text
if Y > 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.20
elif S < 0.15:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.25 if W <= 1.0 else 0.35
elif S < 0.5:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.70 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = (
    0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
  )
else:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.35
```

Only the low-interaction wide-torso branch and moderate-interaction
narrow-torso branch differ from GQ9. The high-interaction smooth curve and
fallback remain unchanged. All boundary inclusions remain exact:

- `Y > 1.0` takes precedence over every score and width branch;
- `S == 0.15` enters the moderate-interaction width split;
- `S == 0.5` enters the high-interaction region;
- `W == 1.0` is in the narrow-torso branch below `S == 0.5`;
- `W > 1.0` and `L < 1.0` select the smooth curve at high interaction;
- `L == 1.0` is outside the smooth short-torso curve; and
- every remaining high-interaction, non-yaw-amplified morphology receives
  `0.35 rad / (m/s)`.

No interpolation outside the declared smooth curve, epsilon, hysteresis,
warning band, fallback override, lookup table, identity field, generator
index, seed, role, repetition, or runtime performance measurement may change
these branches. Every gain must compile before world construction and seal in
the controller receipt.

The GQ10 clock is a distinct receipt with the exact GQ9 numerical values:
unit-scale `120 Hz`, `360`-tick cycles, `4` evidence cycles, one warmup cycle,
one cooldown cycle, `240` settle ticks, `240` terminal-settle ticks, maximum
`120`-tick contact-gate hold, maximum `720`-tick evidence extension, maximum
`12`-tick phase skew, and `90`-tick steering updates. The solver remains Jolt
at `20` velocity and `7` position iterations.

##### Fresh GQ10 population and distinct receipts

GQ10 reuses the exact radical-inverse calculation, six axes, prime bases,
asymmetric intervals, and four-shell schedule. Its fresh selection indices,
fixed before implementation or generated-body calculation, are:

```text
97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108
```

Their required IDs are `gq10_generated_s097` through
`gq10_generated_s108`. The fresh held-out indices are:

```text
901, 902, 903, 904, 905, 906, 907, 908
```

Their required IDs are `gq10_generated_s901` through
`gq10_generated_s908`. None of these 20 indices has been calculated,
compiled, or run in physics before this preregistration.

The campaign identity is `G4-GQ10`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq10_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq10_generation_receipt_v1
policy_schema_version = sporespore_g4_gq10_perturbation_margin_velocity_feedback_policy_v1
clock_policy_id = g4_gq10_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v15
```

All GQ10 generator, fixture, policy, controller, clock, solver, threshold,
source, assertion, and containment receipts must be deterministic and
distinct where their declared inputs differ.

##### Frozen preservation, execution, and stopping contract

GQ10 must be implemented as a distinct campaign policy. Rejected GQ1-GQ9
source behavior, reports, and held-out locks remain unchanged. These policy
digests must reproduce exactly:

```text
GQ1 = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
GQ5 = sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
GQ6 = sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f
GQ7 = sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346
GQ8 = sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0
GQ9 = sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74
```

Before eligible physics, zero-world tests must reconstruct all 20 fresh GQ10
generator receipts and reverse lookups, compile every fixture and static
screen, exercise every controller boundary and interior smooth-curve point,
prove identity/outcome independence, seal the GQ10 clock, solver, thresholds,
controller, and policy, reject malformed requests closed, and retain exact
GP1-GP5 and GQ1-GQ9 regression.

Eligible evidence requires a pushed implementation commit, clean scoped source
tree, immutable per-cell source snapshots, the approved isolated hidden
runner, zero engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ10 worlds must pass
`300/300` assertions in one execution. Any selection failure rejects GQ10,
permanently leaves indices `901-908` unopened, and permits no eligible
selection rerun.

Only a complete selection opens all eight held-out bodies for all three frozen
perturbations. The runner must execute all three repetitions unchanged once
opened. Held-out completion requires `24/24` worlds and `600/600` assertions.
No post-selection edit, threshold change, candidate swap, selective rerun, or
newly observed branch may become GQ10 evidence.

Complete GQ10 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source vector. A complete result would establish
this bounded procedurally generated quadruped family for its fresh fixed
indices and perturbations. It would not establish every seed, continuous
full-volume coverage, arbitrary quadrupeds, automatic morphology synthesis,
another limb count, running, or automatic creature guidance.

#### G4-GQ10 exact result: selection passed, held-out confirmation rejected

The distinct GQ10 implementation was committed and pushed before physics:

```text
preregistration commit = 55785fa9459defb6d82fbf5eea3a02bd2dfeb124
implementation commit = 9adffaf358902dd500862685faeaf51ea35e7af1
formula policy = sha256:f487f4da8976a2295d6369057f21b60a2fe2688e78ccbeb4c80043d73b770fad
```

The independent zero-world compiler gate passed `96/96` assertions and the
no-argument harness gate passed `1/1`, both with zero engine errors:

```text
compiler report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_impl_no_world_test10\
    20260727T120946549\report.json
compiler report SHA-256 =
  55dc8b5ec47e3b88ad3bcbe756adf249c7ad706adbaebec20b447f06e823a24f

harness report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_impl_no_world_test11\
    20260727T121011620\report.json
harness report SHA-256 =
  17abe27e724195a531f70128c68c28f6cf62adfdb67f5f297dbcb2599f472874
```

The compiler independently reconstructed all 20 GQ10 generation receipts,
compiled every fixture and static screen without physics, exercised every
Candidate 29 controller boundary, proved the distinct GQ10 clock and exact
20/7 solver/threshold receipts, and reproduced the exact GQ1-GQ9 policy
digests.

##### Exact clean GQ10 selection: passed

The single allowed selection execution passed completely:

```text
report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_selection_exact_9adffaf\
    20260727T121054559\report.json
report SHA-256 =
  4147f72da271d6acfa7bbd64e2eb21ee9421eb04c1b2d148a1b7fdcec0d8538a
result = 12/12 physical worlds, 300/300 assertions
engine errors = 0
timeouts = 0
containment failures = 0
source_scope_clean = true
formula_policy_digest_consistent = true
selection_eligible = true
```

That complete selection legitimately opened held-out indices `901-908` for
all three frozen repetitions. It did not by itself establish complete GQ10
confirmation.

##### Exact clean GQ10 held-outs: incomplete at 21/24

Per the preregistered contract, all three held-out repetitions executed
unchanged even after repetition 1 failed:

| repetition | result | assertions | report SHA-256 |
|---:|---:|---:|---|
| R1 | `7/8` | `197/200` | `9e02bf5190c6aa5f74a11f66dac3270212a7206dd6a457e53b086ccde37a8aba` |
| R2 | `6/8` | `194/200` | `1b4ca2b12aadbc84e776e6dab7b69e5be44e29118f9456916507d0523f474b44` |
| R3 | `8/8` | `200/200` | `c94ffa1ab0c48edc49a9d7aa70c50922485f8b225568ad28b6b905de5ebbd948` |

The reports are:

```text
R1 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_heldout_r1_exact_9adffaf\
    20260727T121626878\report.json
R2 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_heldout_r2_exact_9adffaf\
    20260727T122059739\report.json
R3 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq10_heldout_r3_exact_9adffaf\
    20260727T122449597\report.json
```

All three reports retained the exact pushed source, clean scope, consistent
formula-policy digest, immutable per-cell snapshots, zero engine errors, zero
process timeouts, and closed containment trees. R3 passed completely. Three
worlds failed, all while retaining strong forward motion and healthy reported
anchor, hinge, height, engine, timeout, and containment receipts.

R1 `gq10_generated_s906`:

```text
S = 0.138725717
L = 0.98193359375
W = 0.976794695930498
F = 0.997755447032307
Y = 1.0
branch = low-interaction, narrow torso
velocity gain = 0.25 rad / (m/s)

evidence forward = 1.183283 m
evidence lateral = -0.135530 m
final forward = 1.353307 m
final lateral = -0.089132 m
permitted final lateral magnitude = 0.097679470 m
maximum anchor error = 0.021488164 m
maximum hinge error = 0.111238674 rad
minimum torso height = 0.426423341 m
```

Every reported normalized movement and structural metric passed, including
the final lateral bound. The failed direct check was the exact per-limb
contact-progression/evidence-horizon receipt. Its aggregate walking receipt
and final establishment check therefore also failed. The compact report does
not retain the per-limb advance dictionary, so this result must not be
relabelled as a lateral-only miss.

R2 `gq10_generated_s901`:

```text
S = 0.142722456
L = 1.006591796875
W = 0.993952903520805
F = 1.02237039819684
Y = 1.0
branch = low-interaction, narrow torso
velocity gain = 0.25 rad / (m/s)

evidence forward = 1.119688 m
evidence lateral = 0.094695 m
final forward = 1.308240 m
final lateral = 0.115729 m
permitted final lateral magnitude = 0.099395290 m
maximum anchor error = 0.019567454 m
maximum hinge error = 0.091295243 rad
minimum torso height = 0.427942783 m
```

R2 `gq10_generated_s903`:

```text
S = 1.0
L = 1.057275390625
W = 0.948525377229081
F = 0.986405897821187
Y = 1.1
branch = yaw-amplified precedence
velocity gain = 0.20 rad / (m/s)

evidence forward = 0.994590 m
evidence lateral = -0.075229 m
final forward = 1.178294 m
final lateral = -0.102335 m
permitted final lateral magnitude = 0.094852538 m
maximum anchor error = 0.020798460 m
maximum hinge error = 0.106771724 rad
minimum torso height = 0.428159654 m
```

Both R2 worlds exceeded their final lateral limits and failed the aggregate
measured-bounds and final establishment checks. The retained compact receipts
prove the lateral violations and healthy reported structural/process metrics;
they do not justify claiming that no unretained submetric also contributed.

Across selection and held-outs, GQ10 therefore completed `33/36` worlds and
`891/900` assertions from one exact source vector. It establishes a successful
fresh selection and a complete R3 perturbation, but it does not establish the
preregistered generated-family confirmation. There is no eligible rerun or
post-selection edit. All GQ10 selection and held-out bodies and repetitions
are now legitimately opened development data for a separately preregistered
successor.

#### Preregistered G4-GQ11 contact-and-lateral-margin confirmation

GQ11 is preregistered after the complete exact GQ10 result and bounded
successor development, but before any GQ11 implementation, generated-body
calculation, static compilation, or physics. All GQ1-GQ10 selection bodies and
all three legitimately opened GQ2, GQ9, and GQ10 held-out repetitions are
development data. GQ3-GQ8 held-out indices `201-208`, `301-308`, `401-408`,
`501-508`, `601-608`, and `701-708` remain unopened and may not be calculated
or used by GQ11.

One fail-closed GQ10 no-world self-check asked the GQ10 generator for index
`109` and received `UNKNOWN_GQ10_GENERATOR_INDEX`. That check did not execute a
GQ11 generator formula, calculate a GQ11 body, compile a fixture, or construct
a physics world. No GQ11 selection or held-out index has been calculated by any
generator before this preregistration.

##### Frozen Candidate 31 development basis

The exact GQ10 result isolated three failures across two controller branches:

- R1 low-interaction narrow-torso `gq10_generated_s906` retained healthy
  normalized movement and structural metrics but failed the exact per-limb
  contact-progression/evidence-horizon receipt at velocity gain
  `0.25 rad / (m/s)`.
- R2 low-interaction narrow-torso `gq10_generated_s901` exceeded its final
  lateral allowance by `0.016333710 m` at the same gain.
- R2 yaw-amplified `gq10_generated_s903` exceeded its final lateral allowance
  by `0.007482462 m` at velocity gain `0.20 rad / (m/s)`.

Candidate 30 raised yaw-amplified feedback to `0.25 rad / (m/s)` and
low-interaction narrow-torso feedback to `0.30 rad / (m/s)`. Its first opened
GQ10 repetition rejected the low-narrow value at `6/8` worlds and `194/200`
assertions:

```text
report =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate30_yaw025_lownarrow030_gq10_r1\
    20260727T123522693\report.json
report SHA-256 =
  cdb37c5527f8ef82fa2aa60ec8fe00ae8344a7fddaec4c56f83daa9819ae473b
policy SHA-256 =
  sha256:1eee37e2228a2c345f895bbdf4a007c5a2eee8b2919c4f7808ecd1ba7987d456
```

At `0.30`, `s906` completed the previously failed contact horizon but ended at
`0.103790 m` lateral against a `0.097679470 m` allowance. `s901` ended at only
`0.004965 m` lateral but newly failed the exact contact-progression horizon.
Candidate 30 had zero engine-error cells, timeouts, or containment failures.
It is rejected as a successor and its later repetitions were not run.

Candidate 31 retains the yaw-amplified `0.25` value and uses the exact midpoint
`0.275 rad / (m/s)` for low-interaction narrow torsos. It changes no other
controller branch, clock, solver, motor limit, gait phase, structural
threshold, perturbation, or walking predicate. The complete already-opened
GQ10 development matrix passed `36/36` worlds and `900/900` assertions from
one Candidate 31 source fingerprint:

| opened matrix | result | assertions | report SHA-256 |
|---|---:|---:|---|
| selection | `12/12` | `300/300` | `b3cd6a93416675c4adcce6112d6ecf863958d1fba471c9717af2780c39fd4989` |
| held-out R1 | `8/8` | `200/200` | `3c99d013773567efb46dbaebfbcc303e4fb5500e05d788c3b3f2d73e2b169be7` |
| held-out R2 | `8/8` | `200/200` | `28a0e9db8234b4884e11d45f85cda8ae88d81c5021f12f2d3ad6109316c63596` |
| held-out R3 | `8/8` | `200/200` | `e312e4169f77f2c4428b5c7db8283ee5ffe9d9d13b401c95852dbf5228b4316c` |

The reports are:

```text
selection =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate31_yaw025_lownarrow0275_gq10_selection12\
    20260727T125153300\report.json
R1 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate31_yaw025_lownarrow0275_gq10_r1\
    20260727T124023909\report.json
R2 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate31_yaw025_lownarrow0275_gq10_r2\
    20260727T124422274\report.json
R3 =
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate31_yaw025_lownarrow0275_gq10_r3\
    20260727T124808512\report.json
```

All four reports share Candidate 31 policy digest
`sha256:e09e8e56ea8da582252189d1728eda1a087d6246596d43e1629e3ff880c37610`
and probe-source SHA-256
`sha256:efc93d5dbae07734b90159924e93353a9b498be5cfb3e71ca1c1f2104a6fd8b5`.
They retain consistent formula-policy receipts, report every world walking,
and contain zero failed physical assertions, engine-error cells, timeouts, or
containment failures. They correctly refuse selection or held-out eligibility
because the development source was dirty and every simulated body was already
open.

The three previously adverse cases passed with strong forward travel:

| body and repetition | evidence forward | final forward | final lateral |
|---|---:|---:|---:|
| `s906` R1 | `1.128904 m` | `1.347487 m` | `0.007799 m` |
| `s901` R2 | `1.181339 m` | `1.414518 m` | `-0.014241 m` |
| `s903` R2 | `0.996712 m` | `1.200684 m` | `-0.077249 m` |

R1 `s901` also passed, but its `0.098826 m` final lateral displacement retained
only `0.000569290 m` against its `0.099395290 m` allowance. That small margin
is explicitly retained as a successor risk rather than hidden. Candidate 31
is selected because it is the only tested source vector that passed every
opened GQ10 world; these observations are not GQ11 evidence and establish no
new accepted walking-family claim.

##### Frozen GQ11 morphology and controller formulas

GQ11 retains exactly GQ10's morphology variables, normalization, pairwise
interaction score, cross-track position feedback, morphology-adaptive yaw
feedback, motor guard, clock values, solver, structural thresholds,
perturbations, and all walking predicates.

Let `L`, `W`, `H`, `F`, `S`, and `Y` have the exact GQ10 meanings. Candidate 31
freezes cross-track velocity feedback as:

```text
if Y > 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.25
elif S < 0.15:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.275 if W <= 1.0 else 0.35
elif S < 0.5:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.70 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  cross_track_velocity_heading_gain_rad_per_m_s = (
    0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
  )
else:
  cross_track_velocity_heading_gain_rad_per_m_s = 0.35
```

Only the yaw-amplified precedence branch and low-interaction narrow-torso
branch differ from GQ10. All boundary inclusions remain exact:

- `Y > 1.0` takes precedence over every score and width branch;
- `S == 0.15` enters the moderate-interaction width split;
- `S == 0.5` enters the high-interaction region;
- `W == 1.0` is in the narrow-torso branch below `S == 0.5`;
- `W > 1.0` and `L < 1.0` select the smooth curve at high interaction;
- `L == 1.0` is outside the smooth short-torso curve; and
- every remaining high-interaction, non-yaw-amplified morphology receives
  `0.35 rad / (m/s)`.

No interpolation outside the declared smooth curve, epsilon, hysteresis,
warning band, fallback override, lookup table, identity field, generator
index, seed, role, repetition, or runtime performance measurement may change
these branches. Every gain must compile before world construction and seal in
the controller receipt.

The GQ11 clock is a distinct receipt with the exact GQ10 numerical values:
unit-scale `120 Hz`, `360`-tick cycles, `4` evidence cycles, one warmup cycle,
one cooldown cycle, `240` settle ticks, `240` terminal-settle ticks, maximum
`120`-tick contact-gate hold, maximum `720`-tick evidence extension, maximum
`12`-tick phase skew, and `90`-tick steering updates. The solver remains Jolt
at `20` velocity and `7` position iterations.

##### Fresh GQ11 population and distinct receipts

GQ11 reuses the exact radical-inverse calculation, six axes, prime bases,
asymmetric intervals, and four-shell schedule. Its fresh selection indices,
fixed before implementation or generated-body calculation, are:

```text
109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 119, 120
```

Their required IDs are `gq11_generated_s109` through
`gq11_generated_s120`. The fresh held-out indices are:

```text
1001, 1002, 1003, 1004, 1005, 1006, 1007, 1008
```

Their required IDs are `gq11_generated_s1001` through
`gq11_generated_s1008`. None of these 20 indices has been calculated,
compiled, or run in physics before this preregistration.

The campaign identity is `G4-GQ11`. Fresh receipts must be equivalent to:

```text
generator_policy_id = g4_gq11_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq11_generation_receipt_v1
policy_schema_version = sporespore_g4_gq11_contact_and_lateral_margin_velocity_feedback_policy_v1
clock_policy_id = g4_gq11_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v16
```

All GQ11 generator, fixture, policy, controller, clock, solver, threshold,
source, assertion, and containment receipts must be deterministic and
distinct where their declared inputs differ.

##### Frozen preservation, execution, and stopping contract

GQ11 must be implemented as a distinct campaign policy. Rejected GQ1-GQ10
source behavior, reports, and held-out locks remain unchanged. These policy
digests must reproduce exactly:

```text
GQ1 = sha256:40aef29711ef024cd46581e1d659581eed6836f5a2f6bd5672e396ae5e4cb698
GQ2 = sha256:f068908fd4313566ff0e89858a8d497d3751e9160a59af367687b68455cdf463
GQ3 = sha256:f1bad4f6635728ec04c4f8ab4ba792f9f3b320db93e47a0c5900032f8c5c9253
GQ4 = sha256:c2bdf7e9cb5ee36425abffc7b3be7dbf0f3528bf07f7dde0047290020c8d6e38
GQ5 = sha256:e71f18e8244e450fcbf2cf4dc4e21f1431a9d836ef58ee16af423a8a3a6019eb
GQ6 = sha256:1c099d6c3179323c9e2dbdf20adcfd1cb91e11221fd0d2a49f349acec512a85f
GQ7 = sha256:32c68e0d0f1c4ecb54499793a2f090e7bee37846f6babf27f563bd5afb5c0346
GQ8 = sha256:c39d147f61057cb4b96e745b5aa7258bbfbcbfedaab4116a93b518f2b46348a0
GQ9 = sha256:3410448ca5b7b35e06310abcc794ca0acaeaa3d559de37a19ef9e666c80d1c74
GQ10 = sha256:f487f4da8976a2295d6369057f21b60a2fe2688e78ccbeb4c80043d73b770fad
```

Before eligible physics, zero-world tests must reconstruct all 20 fresh GQ11
generator receipts and reverse lookups, compile every fixture and static
screen, exercise every controller boundary and interior smooth-curve point,
prove identity/outcome independence, seal the GQ11 clock, solver, thresholds,
controller, and policy, reject malformed requests closed, reproduce the exact
GQ1-GQ10 policy digests, and pass the expected `102/102` compiler assertions
plus the no-argument `1/1` harness assertion.

Eligible evidence requires a pushed implementation commit, clean scoped source
tree, immutable per-cell source snapshots, the approved isolated hidden
runner, zero engine errors, zero timeouts, and closed containment trees.

Selection is all-or-nothing: all 12 fresh unperturbed GQ11 worlds must pass
`300/300` assertions in one execution. Any selection failure rejects GQ11,
permanently leaves indices `1001-1008` unopened, and permits no eligible
selection rerun.

Only a complete selection opens all eight held-out bodies for all three frozen
perturbations. The runner must execute all three repetitions unchanged once
opened. Held-out completion requires `24/24` worlds and `600/600` assertions.
No post-selection edit, threshold change, candidate swap, selective rerun, or
newly observed branch may become GQ11 evidence.

Complete GQ11 confirmation requires `36/36` worlds and `900/900` assertions
from one byte-identical clean source vector. A complete result would establish
this bounded procedurally generated quadruped family for its fresh fixed
indices and perturbations. It would not establish every seed, continuous
full-volume coverage, arbitrary quadrupeds, automatic morphology synthesis,
another limb count, running, or automatic creature guidance.

#### GQ11 execution result: rejected at 34/36

GQ11 was implemented at pushed commit
`fdfc30256e7731cd2aa5745a8af1559cad80b771`. The exact formatted source
passed the independent no-world compiler at `102/102` and the no-argument
harness at `1/1`, with zero engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_impl_formatted_no_world_test10\20260727T131750967\report.json
sha256:19fb50f56c94909c84e9b611a4034b00b386686312c18b5c04e09d084d48d07f

<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_impl_formatted_no_world_test11\20260727T131759091\report.json
sha256:0f034c9a78ca997915be1d05833af02baa8f2a79dda38d14406e6db9419bb68d
```

The one allowed selection passed completely: all 12 fresh generated bodies
walked for `300/300` assertions. The report has a clean scoped source tree,
the exact pushed source commit, `selection_eligible=true`, zero timeouts, zero
engine errors, and closed containment trees:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_selection_exact_fdfc302\20260727T131925744\report.json
sha256:c7570ec15c00706dd4bc0a8e0d3a013c0df4539ed657a5a46aeb5249808153b0
```

That result legitimately opened all eight held-out bodies. All three required
repetitions then ran unchanged from the same clean source:

| Repetition | Bodies | Assertions | Exact result |
| --- | ---: | ---: | --- |
| R1 | `8/8` | `200/200` | complete pass |
| R2 | `7/8` | `197/200` | `s1005` exceeded lateral drift |
| R3 | `7/8` | `197/200` | `s1007` missed front-left relocation |

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_heldout_r1_exact_fdfc302\20260727T132526890\report.json
sha256:95372f834b68b05e25fdaea43154d9ec302e5d42d7db3a98d3bc18522be3a4cf

<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_heldout_r2_exact_fdfc302\20260727T132902244\report.json
sha256:e184a8e14158cfd4f90e71c0c9df8d5666dffbd9837db4a2f1cb7146038dd723

<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_heldout_r3_exact_fdfc302\20260727T133242531\report.json
sha256:b506637ff45b905f76172b89cd7e521c25786c31a94689c82352ba18a881b35c
```

R2 `gq11_generated_s1005` remained upright, completed every contact horizon,
preserved its joint limits, and traveled `1.090577 m` at evidence and
`1.254878 m` finally. Its final lateral displacement was `0.151867 m` against
the sealed `0.100000 m` limit. The three reported assertion failures are the
underlying lateral gate plus its two aggregate walking gates.

R3 `gq11_generated_s1007` also remained upright, completed every contact
horizon, and traveled `1.160835 m` at evidence and `1.370040 m` finally. Its
published final lateral displacement (`0.019122 m`), anchor error
(`0.020996651 m`), hinge error (`0.101586220 rad`), torso height
(`0.428277075 m`), and support margin (`0.191790715 m`) are all healthy.

After GQ11 was closed, commit `187aef1` added output-only per-subgate
diagnostics and passed its no-world `1/1` harness check. One explicitly dirty,
single-cell development replay identified the exact miss without changing or
rerunning GQ11 evidence:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_s1007_r3_diagnostic\20260727T134142780\report.json
sha256:be0bc52d48993e6df0c962ede7083181d1bd629222a61c8dafe6c0daf7eddf92
```

Every walking subgate was true except `every_limb_forward_relocation`.
Front-left minimum relocation was `0.012428522 m` against the compiled
`0.012734976 m` minimum, a miss of `0.000306454 m`. Front-right, rear-left,
and rear-right relocated `0.049828291 m`, `0.042499542 m`, and
`0.016088545 m`; all four limbs completed their `1440`-tick evidence horizons
with zero contact-gate timeouts. The development replay is diagnostic only.

Final GQ11 accounting is `34/36` worlds and `894/900` assertions, with zero
timeouts, zero engine errors, zero killed process trees, and every containment
tree closed. This rejects complete GQ11 confirmation. It does not erase the
complete selection, complete R1, forward travel, or 94.4% physical-cell pass
rate, and it does not authorize a GQ11 rerun or evidence-preserving retune.

#### Candidate 32 opened-body development

Candidate 32 was developed only after all GQ11 bodies and perturbations were
legitimately opened. It preserves every Candidate 31 branch except two smooth,
geometry-derived cross-track velocity-feedback products.

For a yaw-amplified body (`Y > 1.0`), define:

```text
long_wide_fraction =
  clamp((L - 1.0) / 0.07, 0.0, 1.0)
  * clamp((W - 1.0) / 0.06, 0.0, 1.0)

velocity_gain = 0.25 + 0.05 * long_wide_fraction
```

For a low-interaction narrow body (`Y <= 1.0`, `S < 0.15`, `W <= 1.0`),
define:

```text
long_small_foot_fraction =
  clamp((L - 1.0) / 0.01, 0.0, 1.0)
  * clamp((1.01 - F) / 0.01, 0.0, 1.0)

velocity_gain = 0.275 + 0.075 * long_small_foot_fraction
```

The low-interaction wide value remains `0.35`; moderate and high-interaction
Candidate 31 branches remain unchanged. Both products are continuous,
cell-ID-independent, calculated before physics, and bounded to the controller's
existing `0.25-0.35 rad / (m/s)` local range. They encode the observed
geometric interactions rather than naming `s1005`, `s1007`, a seed, role, or
repetition.

Targeted development repaired both adverse worlds. `s1005` R2 changed from
`0.151867 m` final lateral displacement to `-0.012244 m` while traveling
`1.336704 m`. `s1007` R3 front-left relocation changed from `0.012428522 m`
to `0.037374496 m`, and all of its walking subgates became true.

Candidate 32 then passed the complete opened GQ11 matrix at `36/36` physical
worlds and `900/900` assertions from one dirty source fingerprint:

| opened GQ11 matrix | result | assertions | report SHA-256 |
|---|---:|---:|---|
| selection | `12/12` | `300/300` | `e2138828e36b89be0d30d116b97af2de07d475305fcd6a145be84017d477f2c3` |
| held-out R1 | `8/8` | `200/200` | `6502fc2972afec82cb71b12fe9550fdfe43ba93fad481f6e07f9e7bf639eab01` |
| held-out R2 | `8/8` | `200/200` | `d2164a921e8c3f3c15483c09721a0f6c837c8bf9a57cd1dbe085ccab6bdcf20c` |
| held-out R3 | `8/8` | `200/200` | `cfe371499c0b6ff6555dd5c9b08241fdbd439c766cc977010e8b80b5e13dc5fb` |

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate32_full_selection\20260727T134903890\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate32_full_heldout_r1\20260727T135425660\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate32_full_heldout_r2\20260727T135801275\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate32_full_heldout_r3\20260727T140138677\report.json
```

All four reports identify source commit `187aef1`, the same modified probe
source SHA-256
`0a7cc29c36b18747dbae306a2f3974e8b02df6622840289d07deb17d84313e9d`,
the intentionally dirty scoped source, zero engine errors, zero timeouts, and
closed containment trees. Their top-level eligibility remains false, as
required. These are development observations, not GQ11 evidence and not a
generated-family confirmation.

The Candidate 32 source was then removed, leaving the committed GQ11
implementation and diagnostic output byte-identical to `187aef1` before GQ12
preregistration.

#### Preregistered G4-GQ12 dual-geometry confirmation

GQ12 is preregistered after the exact GQ11 result and Candidate 32 opened-body
development, but before any GQ12 implementation, generator call, body
calculation, fixture compilation, static screen, or physics world. No GQ12
selection or held-out index below has been calculated by any generator.

GQ12 retains exactly GQ11's six morphology variables, normalization, pairwise
interaction score, radical-inverse generator formula and shell schedule,
cross-track position feedback, yaw formula, motor guard, clock numbers, Jolt
`20/7` solver, structural thresholds, perturbations, and walking predicates.
It freezes Candidate 32's two formulas above and every unchanged Candidate 31
branch. Exact precedence is:

```text
if Y > 1.0:
  Q = clamp((L - 1.0) / 0.07, 0.0, 1.0)
      * clamp((W - 1.0) / 0.06, 0.0, 1.0)
  velocity_gain = 0.25 + 0.05 * Q
elif S < 0.15:
  if W <= 1.0:
    Q = clamp((L - 1.0) / 0.01, 0.0, 1.0)
        * clamp((1.01 - F) / 0.01, 0.0, 1.0)
    velocity_gain = 0.275 + 0.075 * Q
  else:
    velocity_gain = 0.35
elif S < 0.5:
  velocity_gain = 0.70 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  velocity_gain = 0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
else:
  velocity_gain = 0.35
```

`Y > 1.0` still takes precedence over score, width, length, and foot-radius
branches. `S == 0.15`, `S == 0.5`, `W == 1.0`, `L == 1.0`, `F == 1.01`, and
both smooth-product endpoints must compile with the exact inclusions implied
above. No epsilon, identity lookup, seed branch, warning band, hysteresis,
runtime performance input, or post-world fallback is permitted.

##### Fresh GQ12 population and receipts

GQ12 selection indices, fixed before implementation or calculation, are:

```text
121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132
```

Their required IDs are `gq12_generated_s121` through
`gq12_generated_s132`. GQ12 held-out indices are:

```text
1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108
```

Their required IDs are `gq12_generated_s1101` through
`gq12_generated_s1108`. These held-outs remain unopened unless the complete
GQ12 selection passes.

The campaign identity and distinct receipt IDs are:

```text
campaign_id = G4-GQ12
generator_policy_id = g4_gq12_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq12_generation_receipt_v1
policy_schema_version = sporespore_g4_gq12_dual_geometry_velocity_feedback_policy_v1
controller_formula_id = dual_smooth_long_small_foot_and_long_wide_v7
clock_policy_id = g4_gq12_four_cycle_contact_clock_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v17
```

The GQ12 clock retains the numerical GQ11 values under its distinct ID:
`120 Hz`, `360`-tick cycles, four evidence cycles, one warmup and one cooldown
cycle, `240` settle ticks, `240` terminal-settle ticks, maximum `120`-tick
contact-gate hold, maximum `720`-tick evidence extension, maximum `12`-tick
phase skew, and `90`-tick steering updates.

Held-out R1 uses no perturbation. R2 remains seed `15302`, vertical clearance
`0.0007 m`, yaw `0.003 rad`, initial linear velocity
`(0.002, 0.0, 0.001) m/s`, initial torso angular velocity
`(0.002, 0.0, 0.001) rad/s`, and phase offset `+1` tick. R3 remains seed
`15303`, vertical clearance `0.0014 m`, yaw `-0.006 rad`, initial linear
velocity `(0.004, 0.0, -0.002) m/s`, initial torso angular velocity
`(0.003, -0.002, 0.002) rad/s`, and phase offset `-2` ticks.

##### GQ12 preservation and stopping contract

GQ12 must be a distinct fail-closed campaign. GQ1-GQ11 behavior, reports,
locks, and policy digests must remain unchanged. In addition to the GQ1-GQ10
digests already listed above, GQ11 must reproduce exactly:

```text
GQ11 = sha256:2cc535c9c6e8064c5c4653d9b67b959c75ec9520c0eb98fcb59d33813562936f
```

Before eligible physics, independent no-world tests must reconstruct all 20
GQ12 bodies from the declared radical-inverse formulas, verify reverse
lookups, compile every fixture and static screen, prove all parameter and
receipt fields, test both new smooth products at zero, interior, saturation,
and exact boundaries, prove identity/outcome independence, seal the new
clock, solver, thresholds, controller, and policy, reject malformed requests
closed, and reproduce every GQ1-GQ11 policy digest. The expected compiler gate
is `108/108`; the no-argument harness gate remains `1/1`.

Eligible evidence requires a pushed implementation commit, clean scoped source
tree, immutable per-cell snapshots, zero engine errors, zero timeouts, and
closed containment trees. Selection is one-shot and all-or-nothing at
`12/12`, `300/300`. Any selection miss rejects GQ12, leaves indices
`1101-1108` unopened, and permits no eligible rerun.

Only a complete selection opens all eight held-outs for all three repetitions,
which must then all run unchanged. Held-out completion requires `24/24`,
`600/600`; complete GQ12 confirmation requires `36/36`, `900/900` from one
byte-identical source vector. No post-selection edit, threshold change,
candidate swap, selective rerun, or newly observed branch can count as GQ12
evidence.

A complete result would establish the bounded fresh fixed-index GQ12
quadruped family under these perturbations. It would not establish every seed,
continuous full-volume coverage, arbitrary quadrupeds, automatic morphology
synthesis, another limb count, running, or automatic creature guidance.

#### GQ12 implementation and exact selection result

The preregistered GQ12 generator, reverse lookup, Candidate 32 controller,
clock, policy, compiler contract, runner, and report-v17 path were implemented
without opening a GQ12 body. Formatting, lint, the PowerShell parser, and
`git diff --check` cleared. The frozen implementation was committed and pushed
before eligible physics at:

```text
0379beeea0de52aaa8ea309884ace53dd45fe82a
```

The exact source independently passed both preregistered no-world gates with
zero engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq12_impl_no_world_test10\20260727T142520657\report.json
sha256:c8378df2216f66455a4a2caa0d9e7c152a8a9053e43f0f1912585512a9f12bcf
108/108 assertions

<evidence-root>\temp-roots-2026-07-28\sporespore_gq12_impl_no_world_test11\20260727T142540720\report.json
sha256:953c5af5f39553c1a91ce56a25f8071b12fe036e1b04f7617abb529d10fe6908
1/1 assertion
```

The first outer selection launcher was accidentally given a `10 s` tool
deadline. It was terminated while the `s121` sandbox was being constructed,
before any campaign report existed. No Godot worker remained, the containment
tree was closed, and none of its partial files were reused. In accordance with
the established full-family interruption rule, that incomplete invocation is
not evidence. The complete 12-cell campaign restarted from scratch under the
same clean pushed source and a new evidence root.

The one eligible complete selection retained an exact `11/12`, `297/300`
negative result:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq12_selection_exact_0379bee_restart_after_launcher_timeout\
  20260727T142759312\report.json
sha256:b17c0099421f1cb6eccf6188522fe8c1153b87fbd0e1a7ca93dd3231504588ea
```

The report seals source commit `0379bee`, a clean scoped source tree, an
immutable per-cell snapshot, policy
`sha256:1f6ab51904ae76f5c634a7d781cc3673c49f8d6708e59d743a4d4ff95b47c62f`,
zero engine errors, zero timeouts, no killed process trees, and closed
containment for all 12 worlds. Eleven fresh bodies passed all 25 assertions.
`gq12_generated_s126` alone passed `22/25`; its three false assertions are the
three aggregate consequences of one underlying
`bounded_lateral_drift=false` walking gate.

`s126` still completed four accepted contact cycles on every limb, relocated
every limb forward, advanced `0.915745 m` during evidence and `1.077520 m`
finally, recovered four-contact support, and remained healthy on yaw, tilt,
height, torso contact, joint-anchor, and hinge-axis bounds. Its generated torso
width scale is `0.959053497942387`, giving a `0.095905349794239 m` lateral
limit. Evidence lateral displacement reached `0.141092 m` and final lateral
displacement reached `0.170295 m`, exceeding that limit by approximately
`0.045187 m` and `0.074390 m`, respectively. This is a real controller
counterexample, not an engine or structural failure.

GQ12 is therefore rejected as a complete generated-family confirmation.
Held-out indices `1101-1108` remain unopened, and no GQ12 rerun or post-result
change can become GQ12 evidence. Further controller development may use only
the now-open selection population and must remain explicitly development-only
until another fresh campaign is preregistered.

#### Literature-integrated next-campaign constraints

The post-GQ12 literature review changes future instrumentation and architecture,
not GQ12's controller, result, held-out lock, or evidence status. Candidate 33
development on opened GQ11/GQ12 bodies was completed under its exact prior
source vector before the literature and critique text was reapplied. It remains
development-only and must be removed before a new generated-family campaign is
preregistered.

The next fresh generated-family preregistration should add two output-only
receipts:

```text
sporespore_morphology_feature_receipt_v1
sporespore_morphology_coverage_receipt_v1
```

Both receipts must be reconstructed by the independent no-world compiler.
They must not read physics outcomes, cell pass/fail state, a generated cell ID
as policy input, or runtime controller performance.

The feature receipt must retain the six signed generator coordinates and derive
at least:

- topology family and ordered limb count;
- torso and support aspect ratios;
- support longitudinal/lateral extents;
- upper, lower, and total leg reach;
- foot radius relative to reach;
- total and trunk mass;
- front/rear mass imbalance;
- projected center of mass and nominal support margin;
- normalized yaw inertia; and
- actuator authority relative to body weight and lever arm.

The coverage receipt must freeze:

- a reference cohort ID, membership list, claim level, and digest;
- feature ordering, units, and normalization constants;
- the raw and standardized query vector;
- nearest validated morphology and distance;
- maximum single-axis excursion;
- coverage-shell policy;
- `SUPPORTED`, `EDGE`, or `OUT_OF_DISTRIBUTION`; and
- the required controller response for each status.

For the first campaign these are diagnostic receipts only. Distance or coverage
status may influence acceptance, controller selection, or authority only under
a later preregistration that freezes the cohort, metric, thresholds, and
responses before calculating or observing a new population.

The already-open GQ11/GQ12 diagnostic in the research ledger provides the
immediate reason for preserving signed structure. `s126` is nearest to prior
lateral failure `s1005`, but it is only seventh-farthest among the 12 GQ12
bodies, while farther `s132` passes. A scalar unsigned distance is therefore a
useful coverage receipt but not a success oracle.

DReCon additionally motivates a future bounded-residual experiment if another
fresh population exposes the same lateral-correction versus contact-progression
tradeoff. Such an experiment must compare the current 90-tick held correction,
a higher-rate unfiltered correction, and a higher-rate cycle-normalized filtered
correction on already-opened bodies. It must record raw/filtered actuation,
slew, peaks, lateral-error integral/overshoot, contact timeouts, relocation,
phase, and terminal support. DReCon's `beta = 0.2` and 30 Hz query rate are not
portable constants and must not be copied.

The current R2/R3 held-out repetitions remain small deterministic
initial-condition perturbations. Friction, contact material, sensor noise,
latency, center-of-mass error, actuator mismatch, external pushes, and terrain
belong to a separately preregistered robustness campaign. A generated-family
pass under R1-R3 must not be described as broad robustness.

#### Validated critique constraints

The 2026-07-27 external critique was checked against the live controller,
fixture compiler, tests, runners, and BR evidence chain. Its central
open-loop/drop-in-balance premise is rejected, but four narrower observations
are adopted prospectively.

First, the current physical wave gait is feedback-controlled. It has
contact-gated phase progression, cross-track position and velocity feedback,
heading/yaw feedback, and an anchor-error safety guard. It does **not** yet
close a whole-system projected-COM, support-polygon, capture-margin, roll, or
pitch loop. Earlier BR7-BR13 components establish narrow detection, bracing,
catch, fall, and recovery capabilities; they are not represented as one solved
drop-in balance layer for this walker.

The next fresh generated-family campaign should therefore add a third
output-only receipt:

```text
sporespore_dynamic_support_diagnostic_receipt_v1
```

Its reference implementation is
`scripts/lab/mechanics/spatial_dynamic_support_observer.gd`, already covered by
`tests/test_experimental_br14a_5_dynamic_support_observer.gd`. For each tick or
declared sample it should record:

- mass-weighted COM position and velocity in the frozen support-plane frame;
- ordered active support points and the support polygon derived from them;
- support centroid, COM margin, linearized capture point, capture margin, and
  minimum dynamic margin;
- whether support membership is geometric/contact presence only or has a
  separately qualified bearing measurement; and
- the first margin-warning timestamp relative to lateral-error growth,
  contact-progression delay, anchor-error growth, and terminal failure.

The observer remains diagnostic. Contact presence is not silently promoted to
per-foot bearing load, and the linearized capture estimate is not an
articulated-body guarantee. GQ13 may use these values in output and report
digests, but not in controller policy or acceptance. If margins consistently
degrade before lateral divergence on opened bodies, a later campaign may
preregister a direction-aware, phase-bounded correction. If the margins remain
healthy while the path diverges, development should remain in the existing
steering/cross-track family instead of adding a balance loop by assumption.

Second, the fixture currently pins floor and body friction to `1.8`; the
generated GQ campaigns do not vary it. After the current generated-morphology
closure, and before any broad contact-material, terrain, or robustness claim,
run a separate friction campaign that freezes:

- floor and foot/body friction as separate axes;
- the physics backend's combine policy and every unchanged material property;
- a monotone selection bracket plus untouched held-out values;
- the same locomotion, structural, contact, and containment gates; and
- the lowest/highest passing region and retained failing counterexamples.

Mass and friction must not be varied together until their individual boundaries
are measured. A fixed-friction GQ success remains a morphology result, not a
friction-robustness result.

Third, `MINIMUM_EVIDENCE_TORSO_ADVANCE_M = 0.040` is intentionally retained as
the historical semantic forward-progress gate. It separates positive physical
translation from non-walking, but it is not a useful performance ranking when
accepted bodies commonly travel much farther. Do not retroactively regrade any
campaign. Add a separate prospective performance contract with:

- evidence-window and terminal progress normalized by torso length;
- mean and minimum evidence-window forward speed;
- forward progress per accepted complete contact cycle;
- lateral cost per unit forward progress; and
- the same measures under each declared perturbation.

Cost of transport requires actuator work/energy semantics that the current
fixture does not yet certify, so it belongs after the SDK actuation contract is
frozen. The existing anchor-error gate remains a physical structural-integrity
gate and is not weakened or relabeled as solver noise.

Fourth, `morphology_interaction_score` is a hand-engineered compression of
morphology and therefore carries overfit risk. Its current use is still
cell-ID-independent, outcome-independent at runtime, frozen before eligible
fresh populations, and tested against retained failures. The signed feature,
coverage, and dynamic-support diagnostic receipts above make that risk visible;
they do not turn scalar distance or interaction score into a success oracle.

#### Preregistered G4-GQ13 Candidate 33 diagnostic-receipt confirmation

GQ13 is preregistered after Candidate 33 completed the entire already-opened
GQ11/GQ12 development matrix and after the exact rejected GQ12 implementation
was restored. At the time of this text, no GQ13 generator, reverse lookup,
proportion spec, fixture, static screen, controller receipt, support trace, or
physics world exists, and no GQ13 selection or held-out index below has been
calculated by any project generator.

GQ13 retains exactly GQ12's six morphology variables, normalization, pairwise
interaction score, radical-inverse formula, four-shell schedule, cross-track
position feedback, morphology-adaptive yaw formula, motor guard, numerical
clock, Jolt `20/7` solver, fixture material, structural thresholds,
perturbations, and 25 physical walking predicates. It freezes Candidate 33's
one change to the GQ12 controller. Exact precedence is:

```text
if Y > 1.0:
  Q = clamp((L - 1.0) / 0.07, 0.0, 1.0)
      * clamp((W - 1.0) / 0.06, 0.0, 1.0)
  velocity_gain = 0.25 + 0.05 * Q
elif S < 0.15:
  if W <= 1.0:
    Q = clamp((L - 1.0) / 0.01, 0.0, 1.0)
        * clamp((1.01 - F) / 0.01, 0.0, 1.0)
    velocity_gain = 0.275 + 0.075 * Q
  else:
    velocity_gain = 0.35
elif S < 0.5:
  velocity_gain = 0.75 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  velocity_gain = 0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
else:
  velocity_gain = 0.35
```

`Y > 1.0` still takes precedence over every score, width, length, and
foot-radius branch. `S == 0.15`, `S == 0.5`, `W == 1.0`, `L == 1.0`,
`F == 1.01`, and every smooth-product endpoint use the exact inclusions above.
No epsilon, morphology ID, generator index, seed, role, repetition, observed
outcome, coverage status, support diagnostic, warning band, hysteresis, or
runtime fallback may select or modify a gain.

##### Fresh GQ13 population

GQ13 selection indices, frozen before implementation or calculation, are:

```text
133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144
```

Their required IDs are `gq13_generated_s133` through
`gq13_generated_s144`. GQ13 held-out indices are:

```text
1201, 1202, 1203, 1204, 1205, 1206, 1207, 1208
```

Their required IDs are `gq13_generated_s1201` through
`gq13_generated_s1208`. These eight bodies remain uncalculated and unopened
unless the one allowed complete GQ13 selection passes.

The distinct campaign and receipt identities are:

```text
campaign_id = G4-GQ13
generator_policy_id = g4_gq13_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq13_generation_receipt_v1
policy_schema_version = sporespore_g4_gq13_candidate33_diagnostic_receipts_policy_v1
controller_formula_id = dual_smooth_long_small_foot_long_wide_mid_narrow_075_v8
clock_policy_id = g4_gq13_four_cycle_contact_clock_v1
feature_schema_version = sporespore_morphology_feature_receipt_v1
feature_policy_id = g4_gq13_compiled_physical_features_v1
coverage_schema_version = sporespore_morphology_coverage_receipt_v1
coverage_policy_id = g4_gq13_gq11_candidate33_cohort_euclidean_v1
dynamic_support_schema_version = sporespore_dynamic_support_diagnostic_receipt_v1
dynamic_support_policy_id = g4_gq13_read_only_dynamic_support_trace_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v18
```

The GQ13 clock changes identity only. It retains `120 Hz`, `360`-tick cycles,
four evidence cycles, one warmup and one cooldown cycle, `240` settle ticks,
`240` terminal-settle ticks, maximum `120`-tick contact-gate hold, maximum
`720`-tick evidence extension, maximum `12`-tick phase skew, and `90`-tick
steering updates.

Held-out R1 remains unperturbed. R2 remains seed `15302`, vertical clearance
`0.0007 m`, yaw `0.003 rad`, initial linear velocity
`(0.002, 0.0, 0.001) m/s`, initial torso angular velocity
`(0.002, 0.0, 0.001) rad/s`, and phase offset `+1` tick. R3 remains seed
`15303`, vertical clearance `0.0014 m`, yaw `-0.006 rad`, initial linear
velocity `(0.004, 0.0, -0.002) m/s`, initial torso angular velocity
`(0.003, -0.002, 0.002) rad/s`, and phase offset `-2` ticks.

##### Frozen feature receipt

Every GQ13 body must compile
`sporespore_morphology_feature_receipt_v1` before a world is constructed. The
receipt is canonical JSON, carries `world_build_count = 0`, and contains:

- the campaign ID, morphology ID, generator index/role, shell fraction, six
  signed centered radical-inverse coordinates, six realized scales, their
  declared ordering, and the generator receipt digest;
- topology family `rigid_articulated_quadruped_v1`, ordered limb count and IDs,
  torso dimensions/aspect ratio, longitudinal/lateral hip and nominal support
  extents, and support aspect ratio;
- upper, lower, and total leg reach; foot radius; and foot-radius/reach ratio;
- total mass, torso-mass ratio, front/rear mass totals and signed imbalance,
  projected nominal COM, and nominal support margin;
- yaw inertia divided by `total_mass * torso_length^2`;
- each frozen motor impulse/torque authority divided by body weight times its
  declared lever arm; and
- the fixture, controller, clock, solver, generator, feature-policy, and
  feature-schema digests.

Every scalar must name its SI unit or be explicitly dimensionless. The six
signed coordinates and ordered raw values remain available; no absolute-value
interaction score may replace them. An independent no-world compiler must
reconstruct every field and digest from the generator and fixture inputs.

##### Frozen diagnostic coverage receipt

The GQ13 coverage cohort is fixed to the 20 unique already-opened GQ11 bodies:

```text
gq11_generated_s109 through gq11_generated_s120
gq11_generated_s1001 through gq11_generated_s1008
```

Its claim level is
`development_only_candidate33_flat_floor_godot_jolt_20_7_r1_r3`. The cohort
does not become accepted knowledge merely because Candidate 33 passed it. Its
membership list, claim level, Candidate 33 controller hash
`sha256:b7f62cd6a6fb0c5bd2c5695ad78e9c47449ed2f0aefd36f7f19cf57088701d34`,
feature ordering, and canonical cohort digest are part of every coverage
receipt.

Coverage uses only the six signed centered generator coordinates in this exact
order:

```text
torso_length_scale
torso_width_scale
upper_length_fraction
hip_span_scale
foot_radius_scale
front_limb_mass_scale
```

For each axis, compute the population mean and population standard deviation
over the fixed 20-member cohort and fail closed if the standard deviation is
nonfinite or nonpositive. Standardize both cohort and query using those
constants. Distance is ordinary Euclidean distance in the six-dimensional
standardized space.

Let `D_supported` be the maximum leave-one-out nearest-neighbor distance among
the 20 fixed cohort members. Let `D_edge = 2 * D_supported`. The diagnostic
status is:

```text
SUPPORTED            when nearest_distance <= D_supported
EDGE                 when D_supported < nearest_distance <= D_edge
OUT_OF_DISTRIBUTION  when nearest_distance > D_edge
```

The receipt records all means and standard deviations, the raw and standardized
query, nearest cohort ID and distance, per-axis excursion beyond the cohort
minimum/maximum, maximum standardized excursion, both thresholds, status,
cohort/policy/schema digests, and policy response
`REPORT_ONLY_NO_CONTROLLER_OR_ACCEPTANCE_AUTHORITY`.

This classification is output-only in GQ13. It cannot reject a cell, select a
controller branch, change authority, weaken a physical predicate, or justify a
claim. A later campaign may change that authority only under a new
preregistration with untouched bodies.

##### Frozen dynamic-support diagnostic receipt

GQ13 must integrate the existing read-only
`scripts/lab/mechanics/spatial_dynamic_support_observer.gd` without adding
actuation. From the end of fixture settling through the end of terminal
settling, every physics tick is sampled in the frozen support-plane frame. The
ordered trace sample contains:

- tick, phase, active semantic contact IDs, and explicit
  `contact_presence_is_bearing_measurement = false`;
- mass-weighted COM position and velocity, support polygon/centroid, projected
  COM margin, linearized capture point/margin, and minimum dynamic margin; and
- explicit `articulated_capture_guarantee_available = false`.

The canonical receipt records sample count, ordered trace digest, minima and
first-minimum ticks for COM/capture/dynamic margin, first nonpositive-margin
ticks or `-1`, first half-lateral-limit and full-lateral-limit ticks or `-1`,
contact-progression timeout/extension ticks, maximum anchor-error tick, final
support/contact state, observer policy/schema digest, and every associated
source digest.

The trace and summary are report output only. No dynamic-support value may
enter phase, steering, yaw, velocity gain, motor target, impulse, safety guard,
timeout, acceptance predicate, or authority in GQ13. Receipt absence,
malformation, nonfinite output, digest disagreement, unordered contacts, or
sample-count mismatch fails the harness closed before a result can be
considered eligible; the diagnostic values themselves do not pass or fail the
physical walker.

##### GQ13 preservation, compiler, and stopping contract

GQ1-GQ12 behavior, rejected results, unopened locks, and policy digests remain
unchanged. In addition to the previously frozen digests, GQ12 must reproduce:

```text
GQ12 = sha256:1f6ab51904ae76f5c634a7d781cc3673c49f8d6708e59d743a4d4ff95b47c62f
```

Before eligible physics, independent no-world tests must:

- reconstruct all 20 fresh GQ13 bodies and reverse lookups;
- compile every fixture and static screen;
- prove the Candidate 33 formula at every branch, boundary, smooth-product
  zero/interior/saturation point, and exact precedence edge;
- reconstruct all 20 cohort feature receipts and the GQ13 feature and coverage
  receipts without a world;
- prove cohort membership/order, population standardization, leave-one-out
  thresholds, distance/status boundaries, and report-only authority;
- exercise a synthetic dynamic-support trace for ordered sampling, minima,
  first-crossing ticks, canonical trace digest, unavailable-bearing flags, and
  malformed/nonfinite rejection;
- seal the GQ13 clock, solver, perturbations, thresholds, controller, receipt,
  and report schemas; and
- reproduce every GQ1-GQ12 policy digest and reject identity-, outcome-, role-,
  repetition-, coverage-, or support-driven controller changes.

The exact compiler target is `148/148`; the no-argument harness remains `1/1`.
If the implementation cannot satisfy that exact named contract before any
physics, amend the preregistration under a new commit while all GQ13 bodies
remain uncalculated. Never change the count after a GQ13 body is generated.

Eligible evidence requires a pushed implementation commit, clean scoped source,
immutable per-cell snapshots, zero engine errors, zero timeouts, and closed
containment trees. Selection is one-shot and all-or-nothing at `12/12`,
`300/300`. Any miss rejects GQ13, leaves `1201-1208` unopened, and permits no
eligible rerun.

Only a complete selection opens all eight held-outs for all three repetitions.
They must run unchanged. Held-out completion requires `24/24`, `600/600`;
complete GQ13 confirmation requires `36/36`, `900/900` from one byte-identical
source vector. The three new receipts add integrity and diagnostic output, not
physical acceptance assertions. No post-selection edit, threshold change,
candidate swap, selective rerun, newly observed branch, diagnostic-driven
retune, or changed receipt authority can count as GQ13 evidence.

A complete result would establish the bounded fresh fixed-index GQ13 quadruped
family under the frozen initial-condition perturbations and would produce
reconstructable morphology/coverage/support diagnostics. It would still not
establish broad friction, material, terrain, sensor, latency, push, arbitrary
quadruped, another-limb-count, running, or engine-neutral robustness.

#### GQ13 implementation and exact negative result

The complete GQ13 implementation was pushed before physics at commit
`e3edb8fd36625b65da1e97357f1d2a0654aef784`. From that clean scoped source,
the independent compiler passed the exact preregistered `148/148`, the
no-argument harness passed `1/1`, the existing spatial dynamic-support observer
passed `11/11`, and the GQ13 policy receipt passed `3/3`. The frozen policy
digest is:

```text
sha256:5e2eb3092479ad7c8b979d24e11fde4d9748e9374c142782ca8160085c15d7a4
```

The one allowed selection then completed all 12 isolated worlds from the same
clean commit. It retained the exact result at `276/300`; therefore GQ13 is
rejected, selection is ineligible, and held-out indices `1201-1208` remain
unopened. The immutable report is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq13_selection_e3edb8f_r1\evidence\
  20260727T200851176\report.json
sha256:79a34fa511a1b42af825b13ac5e1bd23a002960a4b3a5c1e1e6eb4bf99979abb
```

Eight cells passed all pre-GQ13 physical walking gates. Four cells exposed
distinct physical misses:

- `s133` exceeded only the lateral-drift bound, ending at `-0.100924 m`;
- `s135` exceeded only its fixture-derived anchor-error bound, reaching
  `0.026037181 m`;
- `s136` exceeded only the lateral-drift bound, ending at `-0.107840 m`; and
- `s139` missed only rear-right forward relocation, measuring
  `0.012358010 m`.

All 12 feature and coverage receipts were produced: `s133-s143` classified
`SUPPORTED`, while `s144` classified `EDGE`. Those statuses were report-only
as preregistered and did not mask physical failures.

All 12 dynamic-support diagnostics failed closed with zero samples. A
post-result no-world reproduction proved the exact harness defect: semantic
receipt order `front_left, front_right, rear_left, rear_right` makes a
self-crossing four-point footprint and the observer returns
`SPATIAL_DYNAMIC_SUPPORT_POLYGON_DEGENERATE`. Perimeter order
`front_left, front_right, rear_right, rear_left` compiles as a valid convex
polygon. This is a diagnostic ordering defect, not a physics result and not a
reason to reinterpret or rerun GQ13. The future repair keeps semantic receipt
ordering unchanged, separates polygon perimeter ordering, preserves the
underlying observer failure code, and adds a no-world regression.

A development-only rerun of already-open passing cell `s134` under the
required 20/7 solver then passed `25/25` and produced `2571` ordered samples
with receipt:

```text
sha256:4a7f2936eebd9f62f6904fb856da50f95d8a30cdb74c927e57c2227519042a3b
```

That proves the future diagnostic path executes, but it is neither a GQ13
rerun nor eligible evidence. The checked-in project solver setting was restored
unchanged after the isolated development invocation.

#### Preregistered G4-GQ14 Candidate 34 support-set confirmation

GQ14 is document-preregistered after Candidate 34 passed the complete
already-opened GQ11/GQ13 development matrix, after the rejected GQ13
implementation was restored, and after the future-only support-set diagnostic
passed its no-world regressions. At the time of this text, no GQ14 constant,
generator, reverse lookup, body, fixture, controller, receipt, runner branch,
or physics world exists. No GQ14 selection or held-out index below has been
calculated by any project generator.

GQ14 retains GQ13's six morphology variables, centered radical-inverse
coordinates, normalization, pairwise interaction score, four-shell schedule,
fixture, materials, clock numerics, Jolt `20/7` solver, perturbations,
dimensionless thresholds, and 25 physical walking assertions. It freezes
Candidate 34 with this exact velocity-feedback precedence:

```text
if Y > 1.0:
  Q_long_wide =
      clamp((L - 1.0) / 0.07, 0.0, 1.0)
      * clamp((W - 1.0) / 0.06, 0.0, 1.0)
  Q_long_large_foot =
      clamp((L - 1.0) / 0.05, 0.0, 1.0)
      * clamp((F - 1.01) / 0.02, 0.0, 1.0)
  velocity_gain =
      0.25 + 0.05 * max(Q_long_wide, Q_long_large_foot)
elif S < 0.15:
  if W <= 1.0:
    Q_long_small_foot =
        clamp((L - 1.0) / 0.01, 0.0, 1.0)
        * clamp((1.01 - F) / 0.01, 0.0, 1.0)
    velocity_gain = 0.275 + 0.075 * Q_long_small_foot
  else:
    velocity_gain = 0.40
elif S < 0.5:
  velocity_gain = 0.75 if W <= 1.0 else 0.25
elif W > 1.0 and L < 1.0:
  velocity_gain =
      0.25 - 0.05 * clamp((S - 0.5) / 0.5, 0.0, 1.0)
elif W <= 1.0 and L < 0.95:
  velocity_gain =
      0.35 + 0.10 * clamp((1.0 - S) / 0.40, 0.0, 1.0)
else:
  velocity_gain = 0.35
```

`Y > 1.0` takes precedence over every score, width, length, and foot-radius
branch. The `max` is the ordinary maximum of the two continuous products; they
must never be summed. `S == 0.15` enters the moderate-score branch,
`S == 0.5` exits it, `W == 1.0` is narrow-or-equal, `L == 0.95` does not enter
the short-body rule, `L == 1.0` does not enter the short-wide taper, and
`F == 1.01` is the zero endpoint of both foot-radius products.

The base score-derived anchor guard remains:

```text
if S >= 0.5:
  anchor_guard = [activation_fraction=0.80, maximum_speed_rad_s=2.0]
else:
  anchor_guard = [activation_fraction=0.90, maximum_speed_rad_s=2.5]
```

Candidate 34 then applies this exact higher-precedence physical-feature
override:

```text
if S >= 0.5 and L > 1.04 and W < 0.95:
  anchor_guard = [activation_fraction=0.70, maximum_speed_rad_s=1.75]
```

No epsilon, campaign result, morphology ID, generator index, role, repetition,
seed, coverage status, support diagnostic, warning band, runtime outcome, or
fallback may select or alter either formula.

##### Fresh GQ14 population

GQ14 selection indices, frozen before implementation or calculation, are:

```text
145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156
```

Their required IDs are `gq14_generated_s145` through
`gq14_generated_s156`. GQ14 held-out indices are:

```text
1301, 1302, 1303, 1304, 1305, 1306, 1307, 1308
```

Their required IDs are `gq14_generated_s1301` through
`gq14_generated_s1308`. These eight bodies remain uncalculated and unopened
unless the one allowed complete GQ14 selection passes.

The distinct campaign and receipt identities are:

```text
campaign_id = G4-GQ14
generator_policy_id = g4_gq14_radical_inverse_piecewise_shell_v1
generator_schema_version = sporespore_g4_gq14_generation_receipt_v1
policy_schema_version = sporespore_g4_gq14_candidate34_support_sets_policy_v1
controller_formula_id = max_long_wide_long_large_foot_score_short_narrow_v9
clock_policy_id = g4_gq14_four_cycle_contact_clock_v1
feature_schema_version = sporespore_morphology_feature_receipt_v1
feature_policy_id = g4_gq14_compiled_physical_features_v1
coverage_schema_version = sporespore_morphology_coverage_receipt_v2
coverage_policy_id = g4_gq14_opened_candidate34_cohort_euclidean_v1
dynamic_support_schema_version = sporespore_dynamic_support_diagnostic_receipt_v2
dynamic_support_policy_id = g4_gq14_read_only_support_set_trace_v1
report_schema_version = sporespore_br14a_nonuniform_proportion_probe_report_v19
```

The clock changes identity only. It retains `120 Hz`, `360`-tick cycles, four
evidence cycles, one warmup and one cooldown cycle, `240` settle ticks, `240`
terminal-settle ticks, maximum `120`-tick contact-gate hold, maximum `720`-tick
evidence extension, maximum `12`-tick phase skew, and `90`-tick steering
updates.

Held-out R1 is unperturbed. R2 retains seed `15302`, vertical clearance
`0.0007 m`, yaw `0.003 rad`, initial linear velocity
`(0.002, 0.0, 0.001) m/s`, initial torso angular velocity
`(0.002, 0.0, 0.001) rad/s`, and phase offset `+1` tick. R3 retains seed
`15303`, vertical clearance `0.0014 m`, yaw `-0.006 rad`, initial linear
velocity `(0.004, 0.0, -0.002) m/s`, initial torso angular velocity
`(0.003, -0.002, 0.002) rad/s`, and phase offset `-2` ticks.

##### Frozen Candidate 34 feature and coverage receipts

Every GQ14 body must compile the unchanged
`sporespore_morphology_feature_receipt_v1` before world construction. Every
field, unit, canonical order, source digest, no-world requirement, and
report-only authority remains as specified for GQ13.

The GQ14 coverage cohort is fixed to 32 unique already-opened bodies that all
passed Candidate 34 under one source vector:

```text
gq11_generated_s109 through gq11_generated_s120
gq11_generated_s1001 through gq11_generated_s1008
gq13_generated_s133 through gq13_generated_s144
```

The claim level is
`development_only_candidate34_flat_floor_godot_jolt_20_7_gq11_r1_r3_gq13_selection`.
The exact Candidate 34 controller source hash is:

```text
sha256:d82ac838137ff8d8c735ca614797f335a43f8ea698552730450b31b3565d4e27
```

Membership, canonical order, claim level, controller source hash, feature
order, and cohort digest are sealed into each coverage receipt. Coverage uses
the same six signed centered coordinates and population-standardized Euclidean
distance as GQ13. `D_supported` remains the maximum leave-one-out
nearest-neighbor distance among the fixed cohort, `D_edge = 2 * D_supported`,
and the inclusive `SUPPORTED`, `EDGE`, and `OUT_OF_DISTRIBUTION` boundaries
remain unchanged.

Coverage is output-only. It cannot reject a cell, choose a controller branch,
alter authority, weaken a physical assertion, or establish continuous-volume
coverage. A finite cohort-distance result is a diagnostic, not a proof that
all points in the morphology volume walk.

##### Frozen support-set diagnostic receipt

GQ14 uses `sporespore_dynamic_support_diagnostic_receipt_v2`. Semantic contact
IDs remain in canonical receipt order. Geometry inputs use the separate
noncrossing footprint-perimeter order. Each sampled tick must compile exactly
one nonempty support set:

```text
one active contact       -> dimension 0, POINT
two active contacts      -> dimension 1, SEGMENT
three or more contacts   -> dimension 2, POLYGON
```

Point and segment margins are nonpositive distances to the support set. They
cannot report a positive support area. A polygon retains the signed interior
margin. Zero active contacts still fail closed as
`SPATIAL_DYNAMIC_SUPPORT_SET_EMPTY`; GQ14 is a walking campaign and does not
authorize flight. Degenerate segments, self-crossing or nonconvex polygons,
nonfinite state, nonpositive gravity, and COM at or below the support plane
also fail closed.

Each sample and summary carries support dimension, geometry kind, polygon
availability, per-dimension sample counts, ordered trace digest, COM/capture/
dynamic minima and first-minimum ticks, first nonpositive ticks, lateral-limit
crossings, gate extensions/timeouts, anchor-error tick, final support state,
source digests, and explicit no-bearing/no-control/no-acceptance authority.
Receipt absence or malformation fails diagnostic integrity; the reported
margin values do not pass or fail walking.

##### GQ14 preservation, compiler, and stopping contract

GQ1-GQ13 implementations, policy digests, results, and held-out locks remain
unchanged. GQ13 must reproduce exactly:

```text
GQ13 = sha256:5e2eb3092479ad7c8b979d24e11fde4d9748e9374c142782ca8160085c15d7a4
```

Before eligible physics, independent no-world tests must:

- reconstruct all 20 fresh GQ14 generator requests and reverse lookups;
- compile all 20 fixtures and static screens with zero world construction;
- prove every Candidate 34 velocity and anchor-guard branch, boundary,
  continuous-product zero/interior/saturation point, max-combination case,
  and precedence edge;
- prove IDs, indices, roles, repetitions, seeds, outcomes, coverage, and
  support diagnostics cannot change control;
- reconstruct the 32-member feature/coverage cohort, its order, source hash,
  standardization, leave-one-out thresholds, statuses, and report-only
  authority;
- exercise synthetic point, segment, and polygon traces plus zero-contact,
  degenerate, unordered, malformed, tampered, and nonfinite failures;
- seal every GQ14 campaign, generator, controller, clock, solver, threshold,
  receipt, source, and report identity; and
- reproduce every GQ1-GQ13 policy digest.

The exact compiler target is `161/161`; the no-argument harness remains `1/1`,
the analytic support observer remains `13/13`, and the GQ14 policy receipt must
pass `3/3`. If implementation cannot satisfy that exact named contract, amend
this preregistration in a new document-only commit while every GQ14 body
remains uncalculated. Never change a count after a GQ14 body is generated.

Eligible evidence requires a pushed implementation commit, clean scoped source,
immutable per-cell snapshots, the exact project-local Jolt `20/7` policy, zero
engine errors, zero timeouts, and closed containment trees. Selection is
one-shot and all-or-nothing at `12/12`, `300/300`. Any miss rejects GQ14,
leaves `1301-1308` unopened, and permits no eligible rerun.

Only complete selection opens all eight held-outs for all three unchanged
repetitions. Held-out completion requires `24/24`, `600/600`; complete GQ14
confirmation requires `36/36`, `900/900` from one byte-identical source
vector. No post-selection edit, threshold change, candidate swap, selective
rerun, newly observed branch, diagnostic-driven retune, or changed authority
can count as GQ14 evidence.

A complete result would establish only this bounded fresh fixed-index GQ14
quadruped family under the frozen flat-floor Jolt conditions. It would not
establish arbitrary quadrupeds, continuous full-volume morphology coverage,
friction/material robustness, terrain, pushes, sensor noise/latency, another
physics engine, another limb count, running, an engine-neutral SDK, or bipeds.

#### GQ14 implementation and exact negative result

The complete preregistered GQ14 implementation was committed and pushed before
physics at:

```text
db75569b00689e00c014e4a1f24d0562f433e934
```

That clean source passed the exact no-world gates before selection:

```text
compiler: 161/161
no-argument harness: 1/1
analytic support observer: 13/13
GQ14 policy receipt: 3/3
GQ14 policy digest:
sha256:b121d0e7adc24ef239c213cbb8da69bacf42a9b7d5fb634c8f2e1e41182d7291
preserved GQ13 policy digest:
sha256:5e2eb3092479ad7c8b979d24e11fde4d9748e9374c142782ca8160085c15d7a4
```

The one allowed complete GQ14 selection then ran under the isolated Jolt
`20/7` project from that clean pushed commit, without selective reruns:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq14_selection_db75569_r1\
  20260727T221713988\report.json
sha256:e60a194c15e3442a10347cb8884770fab8dc4d7efaa4ec9b8b6ca22f79a2a696
result: 8/12 worlds, 288/300 assertions
engine errors: 0
timeouts at process level: 0
containment trees closed: 12/12
```

Therefore GQ14 is rejected. Held-outs `1301-1308` remain unopened and are
permanently ineligible for this rejected campaign. They must not be calculated,
developed against, or run. The eight complete selection passes were `s145`,
`s146`, `s147`, `s149`, `s150`, `s153`, `s154`, and `s156`.

The four rejected cells each failed one underlying physical predicate; the
other two failed assertions in that world were the aggregate walking
consequences of that predicate:

- `s148` failed `contact_gating_completed_without_timeout`: front-left recorded
  one gate timeout. It still completed the evidence horizon, three accepted
  contact cycles on every limb, all per-limb relocation thresholds, bounded
  lateral/yaw/tilt/height/anchor/hinge gates, and terminal recovery.
- `s151` failed `every_limb_forward_relocation`: front-left relocation was
  `0.01211035251617 m`; the other limb relocations were
  `0.04795932769775`, `0.01829540729523`, and `0.01504190266132 m`.
- `s152` failed `bounded_lateral_drift`: final lateral displacement was
  `0.127033 m`. Every limb relocated, no contact gate timed out, and all other
  movement, structural, recovery, and support-observer gates passed.
- `s155` failed `every_limb_forward_relocation`: front-left and front-right
  relocations were `0.01499935984612 m` and `0.01208662986755 m`; rear-left
  and rear-right were `0.02718847990036 m` and `0.04630468785763 m`.

The deterministic generated features identify three different repair regions,
not one generic instability:

```text
s148: L=0.932031250000 W=1.002057613169 U=0.532971428571
      H=0.930320699708 F=0.998591284748 M=0.989940828402 score=1.000000000
s151: L=1.061523437500 W=1.018209876543 U=0.508062857143
      H=1.012026239067 F=1.036682945154 M=1.013535502959 score=0.895078821
s152: L=0.919531250000 W=1.090946502058 U=0.511702857143
      H=1.044606413994 F=1.067092411721 M=1.025739644970 score=1.000000000
s155: L=1.052148437500 W=1.040432098765 U=0.504634285714
      H=0.950801749271 F=0.985617017280 M=1.036612426036 score=1.000000000
```

Here `L`, `W`, `U`, `H`, `F`, and `M` retain the frozen GQ14 axis order. These
opened results may inform a new development candidate, but no repair may
rewrite GQ14 or convert its negative result into evidence. A future eligible
campaign requires a new candidate, a document-only preregistration, fresh
selection and held-out indices, a pushed clean implementation, and a new
one-shot selection.

#### Preregistered G4-GQ15 Candidate 35 fresh-population confirmation

GQ15 is document-preregistered after Candidate 35 v5 passed the complete
already-opened GQ11-GQ14 development matrix, after GQ11-GQ14 controller
behavior was restored byte-for-byte, and after the exact restored compiler
passed `161/161`. At the time of this text, no GQ15 constant, generator,
reverse lookup, clock identity, receipt identity, runner branch, compiler
branch, or physics world exists. No GQ15 selection or held-out body below has
been calculated.

GQ15 retains GQ14's six morphology variables, normalization, centered
radical-inverse construction, piecewise shell schedule, fixture formulas,
four-cycle timing numbers, Jolt `20/7` solver policy, perturbations,
dimensionless evidence thresholds, topology, read-only feature/coverage
diagnostics, and dimension-aware dynamic-support diagnostics.

Candidate 35 retains every Candidate 34 controller rule and precedence edge,
with exactly these two changes.

For the existing score-at-least-half, short, wide branch, define:

```text
I = clamp((S - 0.5) / 0.5, 0, 1)
B = clamp((W - 1.02) / 0.04, 0, 1)
V = 0.25 + 0.025*I + 0.025*I*B
```

The branch requires `S>=0.5`, `L<1.0`, and `W>1.0`, after the unchanged
Candidate 34 higher-precedence yaw-gain, low-score, and mid-score branches.
Thus `S=0.5`, `L=1.0`, `W=1.0`, `W=1.02`, and `W=1.06` are exact boundary
cases. No development result may change their strict or inclusive meanings.

The tighter motor anchor guard is:

```text
[anchor_error_guard_activation_fraction,
 anchor_error_guard_maximum_motor_target_speed_rad_s]
    = [0.70, 1.75]
```

exactly when:

```text
S >= 0.5 and L > 1.04 and (W < 0.95 or W > 1.0)
```

Otherwise Candidate 34's existing score-derived guard remains unchanged.
`L=1.04`, `W=0.95`, and `W=1.0` do not enter the override. The controller may
consume only the declared physical morphology features and their deterministic
interaction score. Morphology ID, generator index, role, repetition, seed,
prior result, acceptance outcome, coverage classification, and diagnostic
receipt content are forbidden controller inputs.

##### Fresh GQ15 population

GQ15 selection indices, frozen before implementation or calculation, are:

```text
157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168
```

They map one-to-one and in order to `gq15_generated_s157` through
`gq15_generated_s168`. GQ15 held-out indices are:

```text
1401, 1402, 1403, 1404, 1405, 1406, 1407, 1408
```

They map one-to-one and in order to `gq15_generated_s1401` through
`gq15_generated_s1408`. These indices are sealed and must remain uncalculated
unless the one allowed complete GQ15 selection passes. Cross-role lookup,
aliases, unexpected fields, wrong types, unknown indices, and receipt
tampering must fail before world creation.

Each generated receipt must seal:

```text
campaign_id = G4-GQ15
generator_policy_id = g4_gq15_radical_inverse_piecewise_shell_v1
schema_version = sporespore_g4_gq15_generation_receipt_v1
campaign_role
generator_index
shell_fraction = 0.25 * (1 + ((generator_index - 1) mod 4))
axis_coordinates in the frozen GQ14 axis order
the exact proportion_spec
world_build_count = 0
```

Generation uses the unchanged bases `2,3,5,7,11,13`, reference values,
piecewise endpoint intervals, centered coordinates, and canonical digest
rules. No rejection sampling, optimizer, learned model, body-specific
constant, or post-generation substitution is permitted.

##### Candidate 35 clock, controller, and evidence identity

GQ15 creates `g4_gq15_four_cycle_contact_clock_v1` as an identity-only clock
change. It must retain all GQ14 numerical timing values exactly: `120 Hz`,
`360`-tick cycles, `72` swing ticks, `240` settle and terminal-settle ticks,
four evidence cycles, `112` boundary-alignment ticks, `720` maximum gated
extension ticks, `120` maximum contact-gate hold ticks, `12` maximum phase-skew
ticks, `90` steering-update ticks, three minimum airborne-dwell ticks, position
gain `8.0`, maximum target speed `3.5`, and damping `0.65`.

The GQ15 policy schema is:

```text
sporespore_g4_gq15_candidate35_opened_matrix_policy_v1
```

It must seal the exact generator, Candidate 35 branch/precedence formulas,
clock, Jolt `120 Hz / 20 velocity / 7 position` solver receipt,
perturbations, thresholds, feature/coverage/support identities, report schema,
and forbidden controller inputs. Per-body controller receipts may vary only
through the frozen physical feature formulas.

##### Frozen Candidate 35 feature and coverage receipts

Every GQ15 body must compile
`sporespore_morphology_feature_receipt_v1` before physics under feature policy:

```text
g4_gq15_compiled_physical_features_v1
```

The receipt remains descriptive and report-only. It grants no controller,
selection, rejection, or walking authority.

The GQ15 coverage cohort is fixed to these 56 unique already-opened bodies,
each of which passed Candidate 35 v5 under the exact same source vector:

```text
GQ11 selection: s109-s120
GQ11 held-out: s1001-s1008
GQ12 selection: s121-s132
GQ13 selection: s133-s144
GQ14 selection: s145-s156
```

The canonical order is exactly the five lines above and ascending within each
line. The candidate source identity is:

```text
tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd
sha256:a7fd448046cdc6608ca524c1ff88b2d671fef3258ee8a6723d1c8efda7528294
```

The GQ15 coverage receipt uses:

```text
schema_version = sporespore_morphology_coverage_receipt_v3
policy_id = g4_gq15_opened_candidate35_population_distance_v3
claim_level = finite_opened_development_population_distance_report_only
candidate35_source_sha256 =
  sha256:a7fd448046cdc6608ca524c1ff88b2d671fef3258ee8a6723d1c8efda7528294
```

It retains GQ14's signed coordinates, population standardization, Euclidean
distance, leave-one-out support radius, inclusive classification boundaries,
source-identity checks, exact cohort-order checks, and fail-closed behavior.
The expanded 56-body cohort must be independently reconstructed without a
world. A coverage class may appear in output but may not alter controller
options, thresholds, execution, or acceptance.

##### GQ15 dynamic-support and report-only diagnostics

GQ15 uses:

```text
receipt schema = sporespore_dynamic_support_diagnostic_receipt_v3
policy id = g4_gq15_read_only_dynamic_support_sets_v3
sample schema = sporespore_dynamic_support_sample_v3
```

It retains the exact GQ14 semantic/perimeter order separation and dimension
semantics: zero contacts fail closed; one contact is a dimension-zero point;
two contacts are a dimension-one segment; and three or more valid ordered
contacts form a dimension-two polygon. Point and segment margins remain
nonpositive distances to their support sets. The diagnostics remain
report-only and may not affect control, thresholds, gating, or acceptance.

The GQ15 runner report schema is:

```text
sporespore_br14a_nonuniform_proportion_probe_report_v20
```

Every result must bind generator, feature, coverage, and dynamic-support
digests; support sample counts must be positive; all source files must be
copied into immutable per-world snapshots; and the report must identify any
development subset. A development subset can never be selection-eligible or
heldout-passing.

##### GQ15 preservation, compiler, and stopping contract

GQ1-GQ14 implementations, policy digests, reports, negative results, and
held-out locks remain unchanged. In particular:

```text
GQ13 =
sha256:5e2eb3092479ad7c8b979d24e11fde4d9748e9374c142782ca8160085c15d7a4
GQ14 =
sha256:b121d0e7adc24ef239c213cbb8da69bacf42a9b7d5fb634c8f2e1e41182d7291
```

Before any GQ15 physics, the compiler must:

- reconstruct all 20 fresh GQ15 generation requests and reverse lookups;
- compile all 20 fixtures and static screens with zero world construction;
- prove every Candidate 35 branch, precedence edge, strict boundary, clamp
  endpoint, interaction-width product, and anchor-guard union;
- prove forbidden IDs, indices, roles, repetitions, seeds, coverage values,
  diagnostics, and outcomes cannot influence control;
- reproduce every GQ1-GQ14 policy digest exactly;
- reconstruct all 56 cohort feature receipts in canonical order;
- independently reproduce the v3 coverage receipt, boundaries, source
  identity, and fail-closed cases;
- prove v3 point, segment, polygon, order, digest, and empty-support cases; and
- seal the runner's full-grid, development-subset, source-snapshot, Jolt
  `20/7`, and v20 reporting paths.

The exact compiler target is `173/173`; the no-argument harness remains `1/1`;
the analytic support observer remains `13/13`; and the GQ15 policy receipt must
pass `3/3`. If implementation cannot satisfy that named contract, amend this
preregistration in a new document-only commit while every GQ15 body remains
uncalculated. Never change a count after a GQ15 body is generated.

Eligible evidence requires a pushed implementation commit, clean scoped source,
immutable per-cell snapshots, the exact project-local Jolt `20/7` policy, zero
engine errors, zero process timeouts, and closed containment trees. Selection
is one-shot and all-or-nothing at `12/12`, `300/300`. Any miss rejects GQ15,
leaves `1401-1408` unopened, and permits no eligible rerun.

Only complete selection opens all eight heldouts for all three unchanged
repetitions. Heldout completion requires `24/24`, `600/600`; complete GQ15
confirmation requires `36/36`, `900/900` from one byte-identical source
vector. No post-selection edit, threshold change, candidate swap, selective
rerun, newly observed branch, or changed diagnostic authority can count as
GQ15 evidence.

A complete result would establish only this bounded fresh fixed-index GQ15
quadruped family under the frozen flat-floor Jolt conditions. It would not
establish arbitrary quadrupeds, continuous full-volume morphology coverage,
friction/material robustness, rough terrain, external pushes, sensor noise or
latency, another physics engine, another limb count, running, a completed
engine-neutral SDK, or bipeds.

##### Formal G4-GQ15 result: complete

GQ15 was implemented only after the document-only preregistration above was
committed and pushed. The frozen implementation source is:

```text
commit =
  52ce84d300dfac945096403250e429a183ebda4e
policy =
  sha256:db8810a6a52c93348598e5a29a9d54bfef2b38121c13032b4e8fd421c9a16b04
compiler = 173/173
no-argument harness = 1/1
policy receipt = 3/3
analytic dynamic-support observer = 13/13
```

The compiler independently reconstructed all 20 fresh generators, fixtures,
Candidate 35 controllers, strict branch boundaries, the 56-member opened
development cohort, v3 population-distance coverage, v3 dynamic-support
point/segment/polygon behavior, the runner profile, and the unchanged GQ13 and
GQ14 policy digests before the first GQ15 physical world.

The one allowed clean selection passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_gq15_selection_52ce84d_r1\
  20260728T000031496\report.json
sha256:07c4a62cd906a08de344fddc16dfc3ac237a997d7089bae422fa3349bb5b3463
result = 12/12 worlds, 300/300 assertions
selection_eligible = true
```

That result opened the sealed held-outs. All three byte-identical repetitions
then passed:

```text
R1:
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq15_heldout_r1_52ce84d\
    20260728T000617319\report.json
  sha256:4b67475501d4ddd121d5f49e1d771bf2ba1520de589ac933bd3ec74401766532
  result = 8/8 worlds, 200/200 assertions

R2:
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq15_heldout_r2_52ce84d\
    20260728T000958498\report.json
  sha256:966593dfcdc319f860b7df7fee178be78d7d376542b47017bc0f8d81f687ea62
  result = 8/8 worlds, 200/200 assertions

R3:
  <evidence-root>\temp-roots-2026-07-28\sporespore_gq15_heldout_r3_52ce84d\
    20260728T001338434\report.json
  sha256:9e6753a675decf3b5036e8f42b00c718c0dc8c165b7b3af6d42452cf0383b809
  result = 8/8 worlds, 200/200 assertions
```

All four reports bind the same clean source commit and policy digest, use
`sporespore_br14a_nonuniform_proportion_probe_report_v20`, report zero engine
errors and zero timeouts, and closed every containment tree. The formal total is
therefore `36/36` physical worlds and `900/900` assertions.

This completes GQ15 exactly as preregistered. It promotes Candidate 35 only for
the finite 12-selection/eight-held-out GQ15 population under the frozen
flat-floor Godot/Jolt `120 Hz / 20 / 7` conditions. The population-distance and
dynamic-support receipts remain descriptive. This result does not establish
continuous full-volume coverage, arbitrary quadrupeds, friction or material
robustness, terrain or push robustness, sensor noise or latency robustness,
another engine, another limb count, running, an engine-neutral SDK, or bipeds.

## Topology-independent walking receipts

The reusable predicate must not contain assumptions such as exactly four
hardcoded dictionary keys except where the quadruped topology itself is being
validated. For every declared limb it must prove:

- the contact observer executed every physics tick;
- semantic release and recontact occurred;
- at least two accepted contact cycles completed;
- accepted cycles relocated in the declared travel direction;
- the limb completed the declared virtual gait horizon;
- contact gating did not time out; and
- terminal support was recovered.

At the whole-creature level it must prove:

- one continuous world and no reset;
- no root locomotor commands after release;
- positive normalized body advance;
- bounded lateral and yaw drift;
- bounded tilt and minimum torso clearance;
- zero forbidden torso/floor contact;
- bounded joint-anchor and hinge-axis error;
- finite motor commands within declared impulse and speed limits; and
- a complete normalized spec, seed, and source receipt.

## Completed implementation slices

1. Added a dedicated normalized physical-quadruped fixture-spec module.
2. Routed the existing reference fixture through its default fixture spec
   without changing any realized number or node order.
3. Added fail-closed unit tests for spec normalization, digest verification, and
   identity.
4. Reran the exact `57/57` nominal and `66/66` seeded-start campaigns.
5. Committed and pushed the identity-preserving refactor and digest hardening.
6. Cleared the post-G0 `25/25` program, `440/440` assertion BR14A family.
7. Preregistered and executed the torso-mass native, fixed-gain, adaptive, and
   phase-bounded path-steering development campaigns.
8. Selected S2-B by the locked first-eligible rule and passed all `9/9` private
   held-out processes across `3.05`, `3.15`, and `3.25 kg`.
9. Cleared the immutable pre-G2 `26/26` program, `453/453` assertion BR14A
   family from exact committed source.
10. Preregistered the symmetric upper-leg-mass axis, preserved every rejected
    UM1-UM9 probe, selected UM10-A by the locked first-eligible rule, and passed
    its complete `5/5` selection.
11. Passed all `9/9` private UM10-A held-out worlds at `0.2125`, `0.2625`, and
    `0.2875 kg` across three fixed perturbation repetitions.
12. Preregistered G2-GS1 before its physics, implemented the uniform fixture
    generator and dimensionless threshold compiler, and added its isolated
    campaign test and runner.
13. Ran the clean G2-GS1 selection, retained its `4/5` negative result, and
    left every held-out scale unopened.
14. Preregistered G2-GS2 as a narrower fixed-formula confirmation campaign,
    promoting the untouched `1.075` scale to its upper selection endpoint and
    reserving three untouched interior scales for held-out validation.
15. Passed the complete G2-GS2 `5/5` selection and all `9/9` held-out worlds
    from one byte-identical committed source receipt, for `308/308` assertions.
16. Cleared the post-GS2 `27/27` program, `454/454` assertion BR14A family from
    the authoritative GS2 source.
17. Preregistered and implemented G2-GS3 dynamic similarity, including the
    `sqrt(s)` timing law, inverse-time gains and damping, `s^4` motor capacity,
    no-world compiler and policy receipts, and fixed-period identity control.
18. Cleared the integrated `28/28` program, `467/467` assertion BR14A family
    and reproduced the authoritative GS2 selection byte-for-byte.
19. Passed the complete G2-GS3 `3/3` selection and all `6/6` held-out worlds
    from exact clean source `686eb14`, for `198/198` assertions.
20. Preregistered and implemented independent G3-GP1 nonuniform proportions,
    retained its complete `10/13` negative selection, and left all four mixed
    held-outs unopened.
21. Preregistered the narrower data-informed G3-GP2 confirmation, compiled all
    17 selection/held-out shapes no-world, sealed a distinct policy receipt,
    and cleared the exact-source `30/30`, `493/493` BR14A preflight.
22. Retained GP2's reproducible `11/13`, `319/325` negative selection, fixed
    its post-world report-finalization bug without changing physics, and left
    all four GP2 held-outs unopened.
23. Selected a dirty-source global controller candidate only after it passed
    all 13 one-axis development cells, rejected the smaller actuator change,
    and preregistered G3-GP3 before any GP3 evidence world.
24. Implemented GP3 at exact pushed source `3e4807b`, compiled all 17 cells,
    sealed a distinct global controller and policy, preserved GP1/GP2 receipt
    identity, and cleared the clean `30/30`, `498/498` BR14A preflight.
25. Passed the exact clean GP3 `13/13` selection, opened all 12 preregistered
    held-out worlds, and retained the honest `10/12`, `294/300` held-out
    rejection after mixed D exceeded its R2 anchor and R3 lateral limits.
26. Retained the rejected post-GP3 GP4 development families: scalar
    gain/impulse changes, whole-swing and late-phase knee-speed caps, hard and
    continuous anchor-error guards, and continuous or phase-sampled steering
    feedback all moved failures elsewhere instead of preserving the complete
    GP3 passing set.
27. Isolated the seven-position-iteration Jolt candidate: both failed GP3
    mixed-D repetitions moved inside every non-pin physical gate, while the
    stale internal six-step receipt and its aggregate cascade remained false.
    Preregistered G3-GP4 with the unchanged GP3 controller, exact `20/7`
    solver policy, fresh 13-cell selection and 12 held-out worlds, and an
    all-or-nothing `25/25`, `625/625` rule before opening eligible evidence.
28. Implemented fail-closed solver receipts and all 17 fresh GP4 cells at
    `6e2b0a1`, cleared the clean `34/34` no-world preflight, fixed the isolated
    GP4 report-parser omission at `a48a472`, and preserved all controller and
    physical-policy values.
29. Retained the exact clean GP4 `10/13`, `316/325` selection rejection after
    seven position iterations regressed long-torso per-foot relocation plus
    upper-share and front-mass lateral bounds. All 12 GP4 held-out worlds
    remain unopened.
30. Compiled a cell-ID-independent pairwise morphology interaction score in
    dirty development, used it to scale a continuous anchor-error guard,
    passed the complete `13/13` one-axis plus `12/12` mixed development matrix
    for `625/625` assertions, and preregistered G3-GP5 before any eligible GP5
    world.
31. Implemented and pushed the exact preregistered GP5 adaptive formula,
    corrected one post-world default-solver receipt bug without changing
    physics, passed the clean `39/39` no-world gate, and completed the exact
    `25/25`, `625/625` selection-plus-held-out confirmation at source
    `52906b1`.
32. Replaced an insufficient `180 s` family-runner allowance only after all
    six timeout-limited programs passed unchanged, then cleared the complete
    post-GP5 repository-default family at `30/30` programs and `508/508`
    assertions.
33. Preregistered G4-GQ1 before implementation or physics: a deterministic
    six-prime radical-inverse generator, four interior-to-envelope shells,
    12 selection and eight fresh held-out indices, per-cell adaptive controller
    receipts, and an all-or-nothing `36/36`, `900/900` rule.
34. Implemented and pushed GQ1 at `b8e2c58`, passed its clean `46/46`
    generator/compiler gate, and retained its exact `10/12`, `294/300`
    selection rejection after two generated bodies exceeded their
    morphology-derived lateral limits. All 24 held-out worlds remain unopened.
35. Repaired both GQ1 lateral failures in dirty development, rejected a fixed
    gain after it moved failure to saturated-score `s008`, passed all `12/12`
    generated selection bodies with a score-derived half-threshold path rule,
    and preregistered G4-GQ2 before eligible implementation or physics.
36. Implemented and pushed GQ2 at `41ab875`, preserved byte-exact GQ1 policy
    reproduction, compiled all 20 fresh cells, sealed per-body derived
    controller receipts, and cleared the exact clean `51/51` no-world gate.
37. Passed the exact clean GQ2 `12/12`, `300/300` selection and retained the
    complete `21/24`, `591/600` held-out rejection: R1 and R3 passed fully,
    while R2 bodies `s103`, `s104`, and `s106` exceeded their
    morphology-derived lateral corridors. Final accounting is `33/36`,
    `891/900`.
38. Rejected global yaw-gain changes, longer contact-gate deadlines,
    cross-track warning bands, and contact-hold steering guards after they
    moved failures between lateral and semantic contact gates.
39. Froze one foot-radius-derived yaw-gain formula after it cleared the
    complete already-open GQ2 development matrix at `36/36`, `900/900`, then
    restored GQ2 byte-for-byte and preregistered G4-GQ3 with fresh selection
    indices `13-24` and held-outs `201-208` before implementation or physics.
40. Implemented and pushed GQ3 at `402295c`, preserved exact GQ1/GQ2 policy
    reproduction, compiled all 20 fresh cells, and cleared the exact clean
    `56/56` no-world gate.
41. Retained the first exact clean GQ3 selection result at `11/12`,
    `297/300`: `s016` advanced `1.022328 m` and cleared every non-lateral gate
    but exceeded its `0.101851852 m` lateral limit by `0.001074148 m`. GQ3 is
    rejected and all eight held-out bodies remain unopened.
42. Repaired `s016` with yaw gains `1.0` and `1.25`, rejected a foot-only
    three-band rule after it moved failure to GQ2 selection `s003`, and rejected
    a foot-plus-hip rule after it moved GQ2 R2 failure to low-score `s105`.
43. Added the existing morphology interaction score as a guard, then passed
    the exact complete opened GQ2 matrix and opened GQ3 selection matrix at
    `48/48` worlds and `1200/1200` assertions from one dirty source
    fingerprint.
44. Restored GQ3 byte-for-byte and preregistered G4-GQ4 with the frozen
    score-foot-hip yaw rule, fresh selection indices `25-36`, and untouched
    held-out indices `301-308` before implementation or body calculation.
45. Implemented and pushed GQ4 at `34450df`, retained exact GQ1-GQ3 policy
    digests, compiled all 20 new cells, and cleared the exact clean `61/61`
    no-world gate.
46. Retained the first exact clean GQ4 selection result at `11/12`,
    `297/300`: low-interaction `s030` advanced `0.970145 m`, passed every
    non-lateral gate, and exceeded its `0.096234568 m` lateral limit by
    `0.011590432 m`. GQ4 is rejected and all eight held-outs remain unopened.
47. Moved the existing score guard ahead of all extra-yaw foot branches,
    repaired opened `s030` at `25/25`, and cleared the complete opened
    GQ2-GQ4 development matrix at `60/60`, `1500/1500` from one dirty source
    fingerprint.
48. Restored GQ4 byte-for-byte and preregistered G4-GQ5 with the score-first
    formula, fresh selection indices `37-48`, and untouched held-out indices
    `401-408` before implementation or generated-body calculation.
49. Implemented and pushed GQ5 at `3ada640`, retained exact GQ1-GQ4 policy
    digests, compiled all 20 fresh bodies, and cleared the clean `66/66`
    no-world gate.
50. Retained the first exact clean GQ5 selection result at `7/12`, `284/300`.
    Four bodies exceeded lateral bounds and two failed contact progression,
    with `s048` in both sets. Rejected GQ5 and left all eight held-outs
    unopened.
51. Added bounded contact-horizon, morphology-adaptive yaw, cross-track
    velocity feedback, score-derived anchor guard, solver, and structural
    threshold development without opening any new generated population.
52. Passed the exact complete opened GQ2-GQ5 development matrix at `72/72`
    physical worlds and `1800/1800` assertions from one dirty 13-file source
    vector, then restored the rejected GQ5 source byte-for-byte.
53. Preregistered G4-GQ6 with exact Candidate 24 formulas, fresh selection
    indices `49-60`, untouched held-out indices `501-508`, distinct campaign
    receipts, and an exact GQ1-GQ5 preservation gate before implementation or
    generated-body calculation.
54. Implemented and pushed GQ6 at `700cac2`, retained exact GQ1-GQ5 policy
    digests, cleared the clean `72/72` no-world gate, and ran the one allowed
    exact selection from the clean frozen source.
55. Retained the GQ6 selection result at `11/12`, `297/300`: every body walked
    forward and remained structurally healthy, while `s050` alone exceeded the
    lateral-drift bound. Rejected GQ6 and kept held-outs `501-508` unopened.
56. Developed smooth morphology-based Candidate 25 only on opened bodies. It
    repaired `s050`, preserved targeted GQ3/GQ4 bodies, and passed all opened
    GQ6 selection bodies at `12/12`, `300/300`; these dirty/open results are
    development observations, not evidence.
57. Preregistered G4-GQ7 with frozen Candidate 25, fresh selection indices
    `61-72`, untouched held-out indices `601-608`, distinct campaign receipts,
    and exact GQ1-GQ6 preservation before implementation or body calculation.
58. Implemented and pushed GQ7 at `274c3e3`, cleared the independent `78/78`
    no-world gate, preserved exact GQ1-GQ6 policy hashes, and ran the one
    allowed selection from the clean frozen source.
59. Retained the GQ7 selection result at `9/12`, `291/300`. Three bodies from
    distinct score regions exceeded only lateral-drift bounds; rejected GQ7
    and kept all held-out indices `601-608` unopened.
60. Developed Candidate 26 and Candidate 27 only on opened GQ7 selection
    bodies. Candidate 27 retained the smooth GQ7 high-interaction curve,
    strengthened the non-yaw-amplified velocity-feedback branches, and passed
    all opened GQ7 selection bodies at `12/12`, `300/300`; the dirty/open
    result is development-only.
61. Preregistered G4-GQ8 with exact Candidate 27 formulas, fresh selection
    indices `73-84`, untouched held-out indices `701-708`, distinct campaign
    receipts, exact GQ1-GQ7 preservation, and an all-or-nothing fresh
    selection before implementation or generated-body calculation.
62. Implemented and pushed GQ8 at `55b5cd4`, cleared the independent `84/84`
    compiler and `1/1` harness gates, preserved the exact GQ1-GQ7 policy
    hashes, and ran the one allowed fresh selection from the clean frozen
    source.
63. Retained the GQ8 selection result at `11/12`, `297/300`. Eleven bodies
    passed completely; `s084` exceeded only the evidence and final
    lateral-drift limits while traveling `1.239687 m` forward. Rejected GQ8
    and kept all held-out indices `701-708` unopened.
64. Developed Candidate 28 only on opened GQ8 selection bodies. Raising the
    high-interaction fallback velocity gain from `0.30` to `0.35` repaired
    `s084`, retained the other eleven bodies, and passed the dirty/opened
    development matrix at `12/12`, `300/300`.
65. Preregistered G4-GQ9 with exact Candidate 28 formulas, fresh selection
    indices `85-96`, untouched held-out indices `801-808`, distinct campaign
    receipts, exact GQ1-GQ8 preservation, and a one-shot fresh selection
    before implementation or generated-body calculation.
66. Implemented and pushed GQ9 at `91ddc3d`, cleared the independent `90/90`
    compiler and `1/1` harness gates, preserved the exact GQ1-GQ8 policy
    hashes, and ran the one allowed clean selection.
67. Passed GQ9 selection at `12/12`, `300/300`, legitimately opening all eight
    held-out bodies for all three frozen repetitions.
68. Completed all GQ9 held-outs unchanged: R1 passed `7/8`, R2 passed `8/8`,
    and R3 passed `7/8`. R1 `s805` and R3 `s802` each exceeded only lateral
    drift. The total `34/36`, `894/900` result rejects complete GQ9
    confirmation without erasing its successful selection.
69. Developed Candidate 29 only on the complete opened GQ9 matrix. Raising
    low-wide velocity feedback from `0.30` to `0.35` and moderate-narrow
    feedback from `0.60` to `0.70` repaired both adverse held-outs and passed
    all opened selection and perturbation worlds at `36/36`, `900/900` from
    one dirty development source fingerprint.
70. Restored GQ9 byte-for-byte and preregistered G4-GQ10 with exact
    Candidate 29 formulas, fresh selection indices `97-108`, untouched
    held-out indices `901-908`, distinct campaign receipts, exact GQ1-GQ9
    preservation, and a one-shot fresh selection before implementation or
    generated-body calculation.
71. Implemented and pushed GQ10 at `9adffaf`, cleared the independent `96/96`
    compiler and `1/1` harness gates, preserved exact GQ1-GQ9 policy hashes,
    and ran the one allowed clean selection.
72. Passed GQ10 selection at `12/12`, `300/300`, legitimately opening all
    eight held-out bodies for all three frozen repetitions.
73. Completed all GQ10 held-outs unchanged: R1 passed `7/8`, R2 passed `6/8`,
    and R3 passed `8/8`. R1 `s906` failed the exact contact-progression
    receipt; R2 `s901` and `s903` exceeded their final lateral limits. The
    total `33/36`, `891/900` result rejects complete GQ10 confirmation without
    erasing its successful selection or complete R3 perturbation.
74. Rejected Candidate 30 after its `0.30` low-interaction narrow-torso gain
    repaired `s906` contact progression but moved it beyond the lateral bound
    and regressed `s901` contact progression in opened R1.
75. Selected Candidate 31's exact `0.275` low-narrow midpoint and `0.25`
    yaw-amplified gain only after one dirty source fingerprint passed the
    complete opened GQ10 matrix at `36/36` worlds and `900/900` assertions.
76. Restored GQ10 byte-for-byte and preregistered G4-GQ11 with Candidate 31,
    fresh selection indices `109-120`, untouched held-outs `1001-1008`,
    distinct receipts, exact GQ1-GQ10 preservation, and the one-shot
    `36/36`, `900/900` acceptance rule before implementation or body
    calculation.
77. Implemented and pushed GQ11 at `fdfc302`, cleared the independent
    `102/102` compiler and `1/1` harness gates, preserved exact GQ1-GQ10
    policy hashes, and ran the one allowed clean selection.
78. Passed GQ11 selection at `12/12`, `300/300`, then completed all held-outs
    unchanged: R1 passed `8/8`, R2 passed `7/8`, and R3 passed `7/8`.
    R2 `s1005` exceeded its final lateral limit; R3 `s1007` failed one
    normalized physical subgate, later diagnosed as front-left relocation.
    The total
    `34/36`, `894/900` result rejects complete GQ11 confirmation without
    erasing its successful selection or complete R1 perturbation.
79. Added and pushed output-only physical subgate diagnostics at `187aef1`.
    One dirty single-cell replay identified `s1007` R3's exact front-left
    relocation miss: `0.012428522 m` against `0.012734976 m`.
80. Developed Candidate 32's two continuous geometry products only on opened
    GQ11 bodies. It repaired `s1005` R2 lateral drift and `s1007` R3
    relocation, then passed the complete opened matrix at `36/36` worlds and
    `900/900` assertions from one dirty source fingerprint.
81. Restored GQ11 byte-for-byte and preregistered G4-GQ12 with Candidate 32,
    fresh selection indices `121-132`, untouched held-outs `1101-1108`,
    distinct receipts, exact GQ1-GQ11 preservation, and the one-shot
    `36/36`, `900/900` acceptance rule before implementation or body
    calculation.
82. Implemented and pushed GQ12 at `0379bee`, cleared the independent
    `108/108` compiler and `1/1` harness gates, preserved exact GQ1-GQ11
    policy hashes, and ran the one allowed complete selection from the frozen
    clean source after discarding one report-less outer-launcher interruption.
83. Retained the exact GQ12 selection at `11/12`, `297/300`. Eleven fresh
    bodies passed completely; moderate-interaction narrow-torso `s126`
    exceeded only its morphology-derived lateral corridor while advancing
    `1.077520 m` and remaining structurally healthy. GQ12 is rejected and
    held-out indices `1101-1108` remain unopened.
84. Completed Candidate 33 development only on already-opened bodies. It raised
    the moderate-interaction narrow-torso velocity-feedback gain from `0.70` to
    `0.75` while retaining Candidate 32's two continuous geometry products.
    The exact campaign-scoped document and controller source hashes were:

    ```text
    docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md
      sha256:a3db562e5771fcbbcbdaf6a223ddda2fb14c95f6f60ab4a442634c1dd12bb6e6
    tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd
      sha256:b7f62cd6a6fb0c5bd2c5695ad78e9c47449ed2f0aefd36f7f19cf57088701d34
    ```

    Under that one source vector, the complete opened GQ12 selection, GQ11
    selection, and GQ11 held-out R1-R3 populations passed `48/48` physical
    worlds and `1200/1200` assertions. Candidate 33 reduced `s126` final lateral
    displacement from `0.170295 m` to `0.013320 m` while it advanced
    `1.248701 m`.

    The exact new held-out reports are:

    ```text
    <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate33_exact_vector_heldout_r1\
      20260727T183819863\report.json
    sha256:6471086719b536b391f7cebaf72d478abee3a9fc641f1e995e94d39b519de706

    <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate33_exact_vector_heldout_r2\
      20260727T184217992\report.json
    sha256:e59676e21fb8e4119213efcf791b75fdd44ecb772b7bb56197d93f62d4a2327f

    <evidence-root>\temp-roots-2026-07-28\sporespore_gq11_dev_candidate33_exact_vector_heldout_r3\
      20260727T184616431\report.json
    sha256:e81359d8d9781dad2012d2bf093f937cc786a1d61d1dac575ed344de3e024a8f
    ```

    Every result row passed 25 assertions with zero timeouts, nonzero exits,
    killed process trees, open containment trees, or engine errors. The runner
    correctly kept evidence eligibility false because the controller source
    was dirty development. One earlier physical `8/8`, `200/200` R1 probe used
    a different documentation hash after roadmap editing and is explicitly
    excluded from the combined source-vector total. None of these observations
    is GQ11 or GQ12 evidence.

85. Implemented and pushed GQ13 at `e3edb8f`, cleared the exact independent
    `148/148` compiler, `1/1` no-argument harness, `11/11` observer, and `3/3`
    policy-receipt gates, reproduced GQ1-GQ12 policy digests, and ran the one
    allowed selection from the clean frozen source.
86. Retained the exact complete GQ13 selection at `276/300`. Eight bodies
    passed every physical walking gate; `s133` and `s136` exceeded only
    lateral-drift bounds, `s135` exceeded only its anchor-error bound, and
    `s139` missed only rear-right relocation. Every cell also failed the new
    diagnostic-integrity assertion because no dynamic-support sample compiled.
    GQ13 is rejected and held-outs `1201-1208` remain unopened.
87. Diagnosed the receipt failure no-world after the result: canonical semantic
    order drew a bow-tie footprint and correctly failed as
    `SPATIAL_DYNAMIC_SUPPORT_POLYGON_DEGENERATE`; the separate perimeter order
    is valid. Added the future-only separation and regression without rerunning
    or rewriting GQ13.
88. Developed Candidate 34 only on already-opened GQ11 and GQ13 bodies. The
    final controller refinement is physical-feature-derived and contains no
    campaign result, morphology ID, generator index, role, repetition, seed,
    or outcome input:

    - when the existing yaw gain exceeds one, combine the prior long-wide
      fraction and the new long-large-foot fraction with `max`, rather than
      adding correlated morphology gains;
    - raise low-interaction wide-torso velocity feedback from `0.35` to `0.40`;
    - for short narrow-or-equal bodies, use the continuous
      `0.35 + 0.10 * clamp((1-S)/0.40,0,1)` velocity-feedback rule; and
    - for score-at-least-half, long, narrow bodies, use the tighter
      `[activation=0.70, maximum_speed=1.75]` anchor guard.

    The first short/narrow draft used a fixed `0.45`, which repaired GQ13
    `s136` but regressed opened GQ11 `s112` lateral drift and `s120` contact
    cycles. The score-continuous version restored both. The first
    long-large-foot draft added its gain to the long-wide gain, which repaired
    GQ13 `s139` but regressed opened GQ11 held-out `s1007` R1 lateral and
    anchor bounds. Taking the maximum of the two correlated fractions restored
    `s1007` while preserving `s139`. These rejected drafts are development
    observations, not campaign evidence.

    The final frozen development source vector used commit parent `3a5217c`
    with these exact scoped file hashes:

    ```text
    docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md
      sha256:e3930824e2374fcecbdea7e3df0c7470d1a964e237c252c8d63df7f3b125f1a
    tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd
      sha256:d82ac838137ff8d8c735ca614797f335a43f8ea698552730450b31b3565d4e27
    scripts/lab/mechanics/spatial_dynamic_support_observer.gd
      sha256:43ae84ce292e5a155d7753cd4ac3a870391952cade7c576f349e33fd88e5009d
    scripts/lab/mechanics/dynamic_support_diagnostic_receipt.gd
      sha256:172bf7aed3b9de9b0fa1b692136dcf0603dcbf52c5837ba04b2871410a32a58c
    ```

    Under that one source vector, all opened GQ11 selection bodies, all opened
    GQ11 held-outs in R1-R3, and all opened GQ13 selection bodies passed
    `48/48` physical worlds and `1200/1200` assertions. The exact reports are:

    ```text
    <evidence-root>\temp-roots-2026-07-28\sporespore_c34v3_gq11_selection\
      20260727T210825511\report.json
    sha256:bcc601d3856c7d758e46d6902f69666804780a7fd8a86e425a6b7bc107203e6a

    <evidence-root>\temp-roots-2026-07-28\sporespore_c34v3_gq11_heldout_r1\
      20260727T211417472\report.json
    sha256:692b7bbbc80d10d5e2e83184aaedd5c53fba372673b0e2a25e58cef6f6a227fa

    <evidence-root>\temp-roots-2026-07-28\sporespore_c34v3_gq11_heldout_r2\
      20260727T211815385\report.json
    sha256:958332cf1dc87c3b84f2e9e3e421fdff80ea877db63571062ed929df2fde8d5e

    <evidence-root>\temp-roots-2026-07-28\sporespore_c34v3_gq11_heldout_r3\
      20260727T212227490\report.json
    sha256:c724a775e33c34eecd6af3fc4a76bd7316ae36ae460a5c2602ab394a0aa038db

    <evidence-root>\temp-roots-2026-07-28\sporespore_c34v3_gq13_opened_selection\
      20260727T212631977\report.json
    sha256:ae844d42c993e5c0f97192bdd0f90514a05c3b2b921598eb6f7954449e74e03b
    ```

    Every physical row passed all 25 assertions without timeout, process-tree,
    containment, or engine-error failures. The GQ11 replay reports correctly
    retain their historical top-level `PASSED=False`: the old GQ11 wrapper
    requires one fixed controller digest, while Candidate 33/34 derives
    controller digests from morphology. Their row-level physical results are
    development validation only. The GQ13 report correctly remains
    selection-ineligible because its source is dirty and its immutable formal
    selection already rejected. GQ13 held-outs `1201-1208` remain unopened.
89. Generalized the future-only dynamic-support diagnostic from polygon-only
    observations to explicit support sets:

    - zero contacts still fail closed;
    - one contact is a zero-area support point with dimension zero;
    - two contacts are a zero-area support segment with dimension one; and
    - three or more valid perimeter-ordered contacts are a dimension-two
      polygon.

    Point and segment margins are nonpositive distance-to-support-set values;
    they never invent positive support area or grant stability authority.
    Receipts now publish support dimension, geometry kind, polygon
    availability, and per-dimension sample counts. This preserves valid
    two-contact gait ticks that the former polygon-only observer discarded,
    while empty support still fails closed. Exact restored-source regressions
    passed:

    ```text
    <evidence-root>\temp-roots-2026-07-28\sporespore_candidate34_finalize_observer\
      20260727T213355894\report.json
    sha256:fa8b83883343032817d417d2475be4cbcd91003a00f73a14698fc82a3672cd16
    result: 13/13

    <evidence-root>\temp-roots-2026-07-28\sporespore_candidate34_finalize_compiler\
      20260727T213410889\report.json
    sha256:bde56d294a75711b79825b5b08c80021e9f8f3f183e423032ef94636278010d8
    result: 149/149
    ```

90. Implemented and pushed GQ14 at `db75569b`, cleared the exact
    `161/161`, `1/1`, `13/13`, and `3/3` no-world gates, then ran the only
    eligible complete selection. The immutable report is:

    ```text
    <evidence-root>\temp-roots-2026-07-28\sporespore_gq14_selection_db75569_r1\
      20260727T221713988\report.json
    sha256:e60a194c15e3442a10347cb8884770fab8dc4d7efaa4ec9b8b6ca22f79a2a696
    result: 8/12 worlds, 288/300 assertions
    ```

    `s148`, `s151`, `s152`, and `s155` failed one underlying physical gate
    each. GQ14 is rejected; held-outs `1301-1308` remain unopened and may never
    be used for GQ14.

91. Developed Candidate 35 only on already-opened GQ11-GQ14 bodies. Candidate
    35 retains every Candidate 34 rule and adds two physical-feature regions:

    - for score-at-least-half, short, wide bodies, let
      `I=clamp((S-0.5)/0.5,0,1)` and
      `B=clamp((W-1.02)/0.04,0,1)`, then use
      `V=0.25+0.025*I+0.025*I*B`; and
    - extend the existing `[activation=0.70, maximum_speed=1.75]` long-body
      anchor guard from `S>=0.5 and L>1.04 and W<0.95` to the disjoint union
      `S>=0.5 and L>1.04 and (W<0.95 or W>1.0)`.

    All inequalities and clamp boundaries are part of the candidate. `S`, `L`,
    and `W` are the frozen interaction score, torso-length scale, and
    torso-width scale. The controller consumes no morphology ID, generator
    index, role, repetition, seed, result, or outcome.

    Development rejected four drafts before the final source:

    - v1 used a reversed short-wide score slope up to `0.30` and broadened the
      long guard across every width. It repaired GQ14 `s151`, `s152`, and
      `s155`, but regressed `s147` and left `s148` outside its lateral bound.
    - v2 restored a neutral-width guard gap and used a `0.275` short-wide end.
      It repaired `s147`, `s148`, `s151`, and `s155`, but did not repair the
      wider `s152`.
    - v3 added width continuously from `W=1.0`; the small nonzero gain at
      `s148` crossed its lateral bound.
    - v4 added the `W<=1.02` dead zone and repaired both short-wide impact
      cells, but the first prior-campaign regression revealed that replacing
      the old narrow guard regressed GQ13 `s135`'s anchor bound.
    - v5 retained the old narrow region and added the new wide region as a
      disjoint union. Boundary representatives `s135`, `s147`, `s151`, and
      `s155` then all passed.

    Candidate 35 v5 was frozen under this exact source vector:

    ```text
    docs/BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md
      sha256:dc571b488630ce694f3ca43145d9d509792a5c5546dbd6594962be4efb5a90f5
    scripts/run_br14a_nonuniform_proportion_probe.ps1
      sha256:438efc16d1915c82471873cad400429f22e2d48b33b24c5c60a506abc39cd3fd
    tests/test_experimental_br14a_11_physical_wave_gait_nonuniform_proportion_probe.gd
      sha256:a7fd448046cdc6608ca524c1ff88b2d671fef3258ee8a6723d1c8efda7528294
    ```

    Seven immutable reports reconstructed that same three-file vector exactly:

    ```text
    GQ14 selection:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq14\20260727T230206189\report.json
      sha256:e400729af6668778dcd169a397338b1ecf403b33ed5d59035d0a86b79e8f03d8
      12/12, 300/300

    GQ13 selection:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq13\20260727T230737166\report.json
      sha256:5134ae8692aba1e76c8cf888668f3980123cb44b7e84b51e433f33b8475df5f7
      12/12, 300/300

    GQ12 selection:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq12\20260727T231306232\report.json
      sha256:66d8d4568d68b5df6cd6793dcb8d0a92796da331d1b27fedc9532e7c2cc1636c
      12/12, 300/300

    GQ11 selection:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq11_selection\20260727T231808656\report.json
      sha256:13777fe0dfa1197fe8696cb6ddd7fea05b109c4e5472cb3c26fbe0601fe8b7b7
      12/12, 300/300

    GQ11 held-out R1:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq11_r1\20260727T232314884\report.json
      sha256:2aa358d024c1f5aa386feb8bd9a0cec59360982c2456f0a9951ea8bad40a1459
      8/8, 200/200

    GQ11 held-out R2:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq11_r2\20260727T232638015\report.json
      sha256:3d72ad9c6c0d8d600350bf7130844b64d8efa511585fce6f8d7e6c97f83b1288
      8/8, 200/200

    GQ11 held-out R3:
      <evidence-root>\temp-roots-2026-07-28\sporespore_c35v5_final_gq11_r3\20260727T233002350\report.json
      sha256:a017ba01e130475bd648b31b8b3dca2edb1b7ef955dbaa8cd3717c9012b3d0cf
      8/8, 200/200
    ```

    The final development total is `72/72` physical worlds and `1800/1800`
    assertions, with zero engine errors and closed containment. The runner
    correctly kept every report evidence-ineligible because the scoped source
    was dirty. The GQ12 selection stage is deliberately stronger than the
    prior Candidate 34 matrix. These observations are neither GQ11, GQ12,
    GQ13, nor GQ14 evidence.

    After recording the result, GQ11-GQ14 controller behavior was restored
    byte-for-byte. The runner retained an explicit development-subset mode
    that validates IDs against the selected campaign role, records executed
    morphologies, and forces both evidence flags false. The exact restored
    no-world compiler then passed:

    ```text
    <evidence-root>\temp-roots-2026-07-28\sporespore_candidate35_restore_compiler\
      20260727T233602969\report.json
    sha256:6ff245e3e71643fea3a57354a2a4f6c151efd4be34a6086a6c9bf0fcc868a3df
    result: 161/161
    ```

GQ15 is complete under the formal result above. The next quadruped evidence
program must leave fixed-index confirmation behind and validate a declared
continuous six-dimensional domain with an explicit coverage argument,
adversarial boundary search, independently seeded confirmation, and a
fail-closed counterexample ledger. GQ15 development may not be relabeled as
continuous-volume or arbitrary-quadruped evidence.

### Post-GQ15/C6 audit boundary

The later
[post-C6 live-code audit](SDK_POST_C6_AUDIT_2026-07-28.md) does not alter the
GQ15 result. It records four successor constraints:

1. every GP/GS/GQ locomotion world used the same `1.8`, rough, absorbent
   material, so GQ15 establishes no friction/material robustness;
2. Candidate 35 closes path/yaw feedback but consumes no COM support margin,
   centroidal state, or roll/pitch balance feedback;
3. the portable SDK has only a Godot adapter at the audited commit; and
4. Candidate 35's topology was prospectively frozen for GQ15, but had already
   been shaped by opened GQ11-GQ14 failures and must not be extended into a
   new claim through more piecewise repair.

The exact midpoint `0.275` came from Candidate 31's opened GQ10 tradeoff, not
an undocumented `0.27586`/`s148` bisection. The `0.01` ramp introduced by
Candidate 32 was not identified from multiple within-ramp GQ11 outcomes even
though later low-discrepancy populations did sample fractional ramp values.
Both corrections and the surviving overfit risk are retained in the audit.

During that post-campaign audit, one interactive reconstruction mistakenly
calculated exact morphology values for the previously uncalculated GQ12
indices `1101-1108` and GQ13 indices `1201-1208`. No physics world or report
was created, and neither rejected campaign changes. Exact calculation still
opens a morphology under this bootstrap, so those ranges are now permanently
ineligible for any future cold-heldout claim and may be used only as explicitly
opened development data. The corrected audit statistics exclude them.

Therefore the next quadruped program begins with a new mechanics-based,
portable stability policy and a fresh friction/material nuisance axis. A
finite population may report its exact fill distance and counterexamples, but
the phrase `continuous full-volume physical coverage` requires the cell-wise
robustness certificate defined by
[ADR-016](adr/ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md).

## Route beyond four legs

After G4, generalize the phase scheduler and receipt dictionaries from a
four-limb constant to ordered semantic body, joint, limb, contact, and actuator
tokens governed by the
[engine-neutral SDK bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).
Stable semantic IDs and declared parent/child relationships, not host engine
enumeration order, must define the canonical token order. A six-leg or eight-leg
creature is the best next morphology because it can reuse:

- per-limb virtual clocks;
- semantic release/recontact gating;
- bounded phase-skew synchronization;
- joint-only lateral stabilization;
- support-contact receipts; and
- the same report pipeline.

A millipede should follow a successful six- or eight-leg walker. Running
requires a speed-parameterized controller and gait-transition work. A biped,
snake, and sea urchin require materially different balance or propulsion
architectures and should remain separate research branches. UniLegs motivates
later specialist-to-student distillation across these tokens, but its one
held-out quadruped does not establish arbitrary unseen topology and its
normalized reward does not replace this bootstrap's strict physical gates.
