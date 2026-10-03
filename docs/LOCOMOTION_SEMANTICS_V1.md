# Locomotion Semantics v1

- **Status:** frozen extraction contract
- **Version:** `sporespore_locomotion_semantics_v1`
- **Frozen from:** GQ15 Candidate 35, commit
  `52ce84d300dfac945096403250e429a183ebda4e`
- **Portable implementation:** `sdk/core`
- **First adapter oracle:** Godot 4.7 / Jolt, `120 Hz`, `20/7`
- **Architecture:** [Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md)
- **Versioned stability extension:** [Locomotion Semantics v2](LOCOMOTION_SEMANTICS_V2.md)

## Purpose and authority

This document freezes the engine-free meaning of the current deterministic
locomotion system. It is the bridge between the GDScript laboratory oracle and
the portable core. It does not promote the GQ15 result beyond its finite
flat-floor Godot/Jolt scope.

Pure-core conformance and physical locomotion evidence are different:

```text
schema/controller parity
  != adapter conformance
  != physical observation
  != held-out confirmation
  != universal morphology guarantee
```

## Global conventions

All canonical records use:

- SI units: metres, seconds, kilograms, radians, newtons, and newton-seconds;
- right-handed coordinates;
- `+X` forward, `+Y` up, and `+Z` right;
- unit quaternions stored as `[x,y,z,w]`;
- finite IEEE-754 binary64 values;
- monotonic nonnegative integer step indices;
- spec-defined semantic ordering, never host enumeration order;
- UTF-8 identifiers matching `[a-z][a-z0-9_]*`;
- exact allowed-field validation;
- canonical JSON with lexicographically ordered object keys; and
- lowercase `sha256:` digests over the canonical UTF-8 bytes.

NaN, infinity, duplicate IDs, unknown fields, unresolved references, invalid
ordering, unsupported capability requests, and missing required observations
fail closed.

Base orientation is expressed in the canonical body frame: local `+X` is
forward, local `+Y` is up, and local `+Z` is right. Projected heading is
`atan2(forward_world_z, forward_world_x)`, so positive heading turns toward
canonical `+Z` right. This heading sign is distinct from the right-hand-rule
rotation sign about world `+Y`. An adapter must rotate host-local body axes
into this canonical body frame before emitting the quaternion. For Godot's
local `-Z` forward and local `+X` right convention, the equivalent conversion
maps canonical local `+X`, `+Y`, and `+Z` to host local `-Z`, `+Y`, and `+X`.

The canonical protocol and portable core remain IEEE-754 binary64. An adapter
may have a lower-precision host geometry boundary, but it must name that
precision and hash a preregistered mapping tolerance into its adapter manifest.
That host-specific tolerance does not weaken C0/C1 pure-core conformance. The
Godot 4.7 standard build uses binary32 `real_t` vector and basis components; its
Candidate 35 physical-shadow comparator is frozen at `2e-8`, with tighter
signal gates of `2.5e-9 rad` target position, `2e-8 rad/s` target velocity,
`1e-8` steering fraction, exact integer phase, and `1e-9 rad/s` speed limit.
The longer full post-settle native-authority campaign is separately frozen at
`4e-8`, with signal-specific ceilings of `5e-9 rad` target position,
`4e-8 rad/s` target velocity, `2e-8` steering fraction, exact integer phase,
and `1e-12 rad/s` speed-limit conversion error. The larger aggregate ceiling
does not replace those tighter per-signal gates.

## Static contracts

### MorphologySpec

Schema: `sporespore_morphology_spec_v1`.

The spec contains ordered records for bodies, joints, limbs, actuators, and
contact sites. IDs and all cross-references are stable semantic identities.
The first core supports rigid bodies, revolute joints, and position/velocity
motor targets. Unsupported semantics return a typed capability error.

A compiled morphology proves structural validity only. It grants no controller,
adapter, walking, or product authority.

### Bounded quadruped descriptor

Schema: `sporespore_bounded_quadruped_descriptor_v1`.

The GQ15-compatible continuous descriptor is:

| Axis | Symbol | Closed domain |
|---|---:|---:|
| torso length scale | `L` | `[0.90, 1.10]` |
| torso width scale | `W` | `[0.90, 1.10]` |
| upper-leg reach fraction | `U` | `[0.48, 0.55]` |
| hip-span scale | `H` | `[0.90, 1.10]` |
| foot-radius scale | `F` | `[0.90, 1.10]` |
| front-limb mass scale | `M` | `[0.90, 1.10]` |

Any finite point in that box can be compiled; the caller supplies an arbitrary
valid semantic ID. Compilation is not a physical walking guarantee.

Exact fixture formulas are:

```text
torso_size = [0.50*L, 0.12, 0.32*W] m
front/rear hip x = +/-0.20*H m
left/right hip z = -/+0.18*H m
upper_length = 0.35*U m
lower_length = 0.35*(1-U) m
foot_radius = 0.04*F m
initial_torso_center_y = 0.40 + 0.04*F m
front limb mass multiplier = M
rear limb mass multiplier = 2-M
```

The descriptor compiler derives the generic `MorphologySpec`; adapters may not
substitute body-specific constants.

### Feature and coverage receipts

Features retain the signed six-axis vector and derived geometric, mass,
support, inertia, contact-size, and actuator-authority features.

Coverage is conditional on all of:

```text
controller + topology + task + environment class + adapter + engine manifest
```

The core distinguishes:

- `SUPPORTED`: inside a certified policy domain;
- `EDGE`: inside the declared compiler domain but outside the certified inner
  policy domain or on a frozen boundary;
- `OUT_OF_DISTRIBUTION`: outside the declared policy domain; and
- `INVALID`: the morphology did not compile.

Coverage never changes controller gains or physical acceptance unless a
separately versioned policy explicitly grants that authority.

### Continuous-domain certificate

Schema: `sporespore_continuous_domain_certificate_v1`.

The certificate covers the complete closed six-dimensional compiler box, not
only sampled points. It contains:

- exact axis intervals;
- interval-propagated fixture extrema;
- mass, reach, radius, support, and actuator preconditions;
- every controller branch surface and strict/inclusive side;
- continuity/discontinuity classification for each output;
- an adaptive cell cover with a declared maximum radius;
- counterexamples and unresolved cells;
- the physical sample/held-out evidence bound to the cover; and
- an explicit claim level.

Analytic interval success can establish continuous compiler/controller
coverage. Finite physical samples cannot by themselves establish walking at
every point because contact dynamics are hybrid and can be discontinuous. A
physical full-volume claim additionally requires every adaptive cell to have a
frozen robustness margin larger than its declared model/adapter variation
bound, or a sound reachability proof. Unresolved cells prevent that claim.

## Dynamic contracts

### StateFrame

Schema: `sporespore_state_frame_v1`.

Required fields:

- step index and sample time;
- base pose and linear/angular twist;
- ordered joint position and velocity observations;
- ordered contact observations with availability and provenance;
- previous applied canonical actuation;
- gravity and task frame;
- adapter capability digest; and
- validity masks for optional values.

Frames are immutable inputs. Missing data is never converted to a confident
zero.

### ContactObservation

Schema: `sporespore_contact_observation_v1`.

Contact presence, qualified bearing, and measured/estimated load are distinct
capabilities. Raw multi-shape impulses retain backend provenance and are not
silently summed into per-foot load.

The Godot/Jolt adapter currently declares one semantic shape per contact site.
For that supported model it reports qualified presence/bearing and retains
host-observer point, normal, relative velocity, raw impulse, local/collider
shape indices, and a stable per-step engine-contact identity. These raw samples
are diagnostic host observations, not portable normal-load measurements.
Normal load therefore remains unavailable/null, friction is manifest-only, and
multi-shape contact sites fail outside the declared capability instead of being
silently aggregated.

### MotionCommand

Schema: `sporespore_motion_command_v2`.

It declares desired planar velocity, heading or yaw rate, gait family, speed
class, phase-progression mode, validity horizon, and authority class. The
phase-progression mode is one of:

- `clocked`: advance every unfinished limb once per valid semantic step; or
- `contact_gated`: apply the frozen release/recontact, dwell, timeout,
  per-limb evidence-horizon, and phase-skew rules.

The first valid command initializes memory without a hidden advance.
`clocked -> contact_gated` advances the prior clock once before the first gated
command. `contact_gated -> clocked` performs the final per-limb gated update
while preserving each limb's evidence limit, then clears those limits for
subsequent clocked cooldown commands. This prevents either replaying the final
evidence command or advancing a completed limb beyond its frozen horizon.

An absent or expired command enters the explicit neutral/hold policy.

### ActuationFrame

Schema: `sporespore_actuation_frame_v1`.

Exactly one command exists per ordered actuator. Each command records requested
and clamped target, mode, saturation, slew, residual contribution, safety
contribution, and valid-through step.

No core command can target root pose, root velocity, teleport, world reset, or
a hidden body impulse.

## Candidate 35 reference controller

### Morphology interaction score

For signed normalized absolute deviations `d[0..5]` from the reference:

```text
S = clamp(sum(i<j, abs(d[i])*abs(d[j])), 0, 1)
```

The signed feature vector remains available; `S` is not a sufficient
morphology description.

### Clock

Policy: `g4_gq15_four_cycle_contact_clock_v1`.

```text
physics rate                       120 Hz
cycle                              360 steps
swing                               72 steps
settle                             240 steps
terminal settle                    240 steps
evidence cycles                      4
boundary alignment                 112 steps
max evidence extension             720 steps
max contact-gate hold              120 steps
max phase skew                      12 steps
steering update interval            90 steps
minimum airborne dwell               3 steps
position gain                        8.0 /s
maximum target speed                 3.5 rad/s
rate damping                         0.65
```

The generic scheduler applies the same semantics over an ordered limb array.
The quadruped lateral order is a topology profile, not a hardcoded core limit.

Candidate 35 runtime memory uses
`sporespore_candidate35_memory_v2`. It records the last semantic step,
previous phase-progression mode, held steering fraction, and ordered per-limb
gait step, evidence limit, gate dwell/hold counters, timeout count, and
phase-synchronization hold count. It is explicit caller-owned state; the pure
core does not retain a hidden controller clock.

### Candidate 35 formulas

Candidate 35 retains Candidate 34. Its added short-wide branch is evaluated
after the existing `Y>1`, low-score, and mid-score branches:

```text
if S >= 0.5 and L < 1.0 and W > 1.0:
    I = clamp((S-0.5)/0.5, 0, 1)
    B = clamp((W-1.02)/0.04, 0, 1)
    cross_track_velocity_gain = 0.25 + 0.025*I + 0.025*I*B
```

The strong anchor guard is:

```text
[activation_fraction, maximum_target_speed] = [0.70, 1.75]
if S >= 0.5 and L > 1.04 and (W < 0.95 or W > 1.0)
```

Otherwise the score guard is `[0.80,2.0]` for `S>=0.5` and `[0.90,2.5]`
below it. Every equality above is part of the contract.

Morphology ID, array index, role, repetition, random seed, coverage class,
diagnostic value, prior outcome, and acceptance state are forbidden controller
inputs.

## Adapter scheduling

An adapter must:

1. sample one immutable state at its declared pre-step phase;
2. call the core at most once for that semantic step;
3. apply only the returned ordered actuator commands;
4. record host clamps and conversion error;
5. advance physics under its declared substep policy;
6. capture contacts without inventing unavailable values; and
7. bind engine, solver, material, timing, and source manifests to the receipt.

Adapter sampling phase, missed-deadline response, contact quality, actuator
model, and coordinate conversion are conformance data.

## Failure codes and safe response

Failure families are:

```text
SCHEMA_*
NONFINITE_*
IDENTITY_*
REFERENCE_*
TOPOLOGY_*
CAPABILITY_*
FRAME_*
ORDER_*
TIME_*
CONTACT_*
COVERAGE_*
ACTUATION_*
DIGEST_*
ADAPTER_*
INTERNAL_*
```

A failed `compile` returns no compiled handle. A failed `create_controller`
returns no controller. A failed `step` returns an explicit no-actuation frame
and typed receipt; adapters must disable or follow the declared hold/decay
policy.

## Conformance and claim matrix

| Layer | What can be claimed |
|---|---|
| C0 schema | records validate and digest identically |
| C1 pure control | golden inputs produce matching canonical outputs |
| C2 kinematics | semantic frames/topology round-trip |
| C3 passive dynamics | unactuated host behavior is characterized |
| C4 actuators | host command conversion and limits are bounded |
| C5 contacts | observation capability and provenance are characterized |
| C6 locomotion | the named host physically passes the frozen gait gates |

No lower layer implies a higher one. No one-morphology C6 result implies
continuous physical morphology coverage.

## Frozen extraction gates

The first portable core may replace no GDScript authority until:

1. all C0/C1 Rust tests pass without Godot installed;
2. checked-in golden vectors reproduce the GDScript oracle;
3. the public C header has ABI layout/ownership tests;
4. arbitrary valid semantic IDs and token enumeration order are tested;
5. quadruped descriptor boundary, interior, and malformed cases pass;
6. Candidate 35 branch/equality vectors match exactly;
7. the generic scheduler passes 2-, 4-, 6-, 8-, and 32-limb tests;
8. every no-authority and OOD response is receipt-bound; and
9. the Godot/Jolt adapter completes its frozen parity campaign.

All nine extraction gates are complete for the bounded Candidate 35
development path. The native Godot/Jolt adapter has additionally completed one
full post-settle authority run in which the SDK applied all eight motor
commands through warm-up, gated evidence, cooldown, and terminal settling.
The adapter's dedicated C2-C5 campaign separately passes `20/20` checks for its
declared supported kinematic, passive-dynamics, actuator, and contact
capabilities. Neither result replaces formal C6 selection/held-out
confirmation, generated-family reproduction, or continuous physical
morphology evidence.
