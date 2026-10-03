# Godot/Jolt Stability-Influence Commissioning Bootstrap

- **Status:** P5I.0 through P5I.3C complete; first P5I.3B source rejected;
  P5I.3B-R1 passed; P5I.3C and P5I.3C-R1 rejected; P5I.3C-R2 passed
- **Recorded:** 2026-07-28
- **Parent:** [Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md)
- **Semantics:** [Locomotion Semantics v2](LOCOMOTION_SEMANTICS_V2.md)
- **Partial-support extension:** [Locomotion Semantics v3](LOCOMOTION_SEMANTICS_V3.md)
- **Material interlock:** [Godot/Jolt Legacy Material Characterization Bootstrap](SDK_GODOT_JOLT_MATERIAL_CHARACTERIZATION_BOOTSTRAP.md)
- **Predecessor source:** `c0b130ea24ca82a443b678a3ef7d362ded2d7199`
- **Predecessor evidence:**
  `<evidence-root>\godot-jolt-stability-shadow-c0b130e\report.json`
  (`sha256:4f48b8e7a4c46452ba5c67006bb8e13e43a0a6ba25eba09e30c421a42b7acf74`)

## Decision

Commission physical stability influence as four ordered gates:

1. portable endpoint-force to generalized-joint-torque mapping;
2. live same-world mapping shadow against an independent GDScript oracle;
3. isolated Godot/Jolt motor-response sign and gain characterization; and
4. bounded contribution shadow, then separately authorized opened-body
   actuation.

No later gate may be inferred from an earlier one. In particular:

```text
J-transpose arithmetic
  != a characterized motor response
  != a bounded motor contribution
  != applied balance feedback
  != balance recovery
  != locomotion robustness
```

Candidate 35 remains immutable. These gates may observe an already-opened
Candidate 35 world, but they may not add a morphology branch or reinterpret
the rejected C6/C6R campaigns.

## Why the mapping is split

The portable mechanics command supplies an endpoint task-force delta. For a
revolute joint, the engine-neutral virtual-work map is:

```text
r_i = endpoint_world - joint_anchor_world
J_i = joint_axis_world x r_i
tau_i = dot(J_i, endpoint_force_world)
```

`tau_i` is a generalized joint-torque command in N m about the declared
positive joint axis. It is not a measured motor torque, measured contact load,
target position, target velocity, engine impulse, or proof that the host can
realize it.

Godot/Jolt currently realizes Candidate 35 with a target-velocity hinge motor
and a per-step impulse cap. Rapier and MuJoCo use different actuator
semantics. Therefore torque-to-target-velocity conversion is adapter
characterization, not portable `J-transpose` arithmetic.

## P5I.0 — portable `J-transpose` contract

### Frozen input

Schema:
`sporespore_endpoint_force_joint_map_request_v2`.

The request contains:

- one semantic step;
- one already-computed feasible
  `sporespore_centroidal_support_command_v2`;
- exact compiled actuator order; and
- for each actuator:
  - actuator ID;
  - support contact-site ID;
  - joint anchor in canonical world metres;
  - directed unit joint axis in canonical world coordinates; and
  - endpoint position in canonical world metres.

The centroidal command is the sole endpoint-force source. The mapper may not
accept a second hidden force value. An actuator/contact association is valid
only when the compiled morphology places that actuator's joint and the
contact site in the same declared limb.

### Frozen output

Schema:
`sporespore_endpoint_force_joint_map_receipt_v2`.

For each actuator, in exact compiled actuator order, the receipt contains:

- actuator ID and contact-site ID;
- linear Jacobian column in metres;
- copied endpoint task-force command in newtons;
- generalized torque command in N m; and
- `command_not_measurement = true`.

The receipt must also keep these false:

- `measured_joint_torque_available`;
- `actuator_response_characterized`;
- `adapter_actuation_applied`;
- `physics_state_modified`; and
- `physical_acceptance_authority`.

### Fail-closed boundaries

The call fails before returning any command if:

- schema or semantic step differs;
- the centroidal command is infeasible;
- actuator cardinality, order, or identity differs from the compiled
  morphology;
- an actuator does not resolve to its compiled joint;
- contact identity is absent, duplicated, or not on the same declared limb;
- an axis is nonfinite, zero, or differs from unit length by more than
  `1e-9`;
- an anchor, endpoint, force, Jacobian column, or torque is nonfinite; or
- any upstream command/authority nonclaim is inconsistent.

### Frozen pure tests

The Rust and C-ABI tests must cover:

- an analytic one-joint case;
- translation invariance of anchor and endpoint;
- force-sign reversal;
- multiple joints mapped to one endpoint in compiled order;
- reordered/missing/duplicate actuator rejection;
- wrong-limb contact rejection;
- infeasible upstream-command rejection;
- nonunit-axis rejection; and
- nonfinite geometry rejection.

The C header, Python binding, and Godot GDExtension must expose the same
strict JSON operation. A checked-in GDScript golden oracle must compare the
analytic Jacobian column and torque without importing the Rust result.

Exit: pure exact-order mapping passes all Rust, C ABI, Python, and GDScript
tests without constructing a physics world.

### P5I.0 result

Source commit
`f399edec4372701e374e0366d5d027d0e607863c` implements the frozen
`J-transpose` contract in `sdk/core/src/stability.rs`, exposes it through
`sdk/include/sporespore_locomotion.h`, the Python binding, and the Godot
GDExtension, and adds the independent shared GDScript oracle.

The clean-source receipt is retained at
`<evidence-root>\stability-v2-joint-map-f399ede\report.json`
(SHA-256
`2cf29aede42db40e233c54d486ad5ebda619cc01f02fc630c26ec327a67bec0a`).
It passes `15/15` focused Rust tests and `23/23` GDScript oracle checks. The
complete source regression also passes Rust core `46/46`, Rust Godot boundary
`2/2`, Rapier `5/5`, Candidate 35 GDScript `105/105`, native Godot boundary
`24/24`, and Python real-DLL ABI `9/9`, plus warnings-as-errors Clippy and the
offline release builds.

The receipt sets `portable_endpoint_force_joint_map_v2 = true` while keeping
actuator-response characterization, adapter actuation, physics mutation,
balance recovery, locomotion, material robustness, cross-engine C6, physical
acceptance, and SDK completion false. P5I.1 cannot inherit any of those
claims.

## P5I.1 — live full-gait mapping shadow

P5I.1 may use only the already-opened reference Candidate 35 world used by the
predecessor stability shadow. It does not open a new morphology or campaign.
The material interlock is now satisfied by source
`d3d5cd1eb47d5fa9dc06106759cce4b01d4c3bd4` and retained report
`<evidence-root>\godot-jolt-legacy-material-d3d5cd1\report.json`
(SHA-256
`f673eceb7e67a395943ebf7e00927a031d221a60eef371b1505b4a680db8a795`).
P5I.1 must use its derived `controller_mu = 1.0`; the authored `1.8` is not
admissible as a controller coefficient.

### Frozen P5I.1 centroidal request

For each live stability observation:

- use qualified support contacts in compiled semantic contact order;
- set the target COM exactly equal to the observed COM;
- set torso roll, pitch, and both rates to exact zero;
- set all horizontal, vertical, roll, pitch, and rate gains to exact zero;
- set all maximum horizontal, vertical-correction, and roll/pitch-moment
  limits to exact zero;
- set declared supported-weight fraction to `1.0`;
- set characterized friction coefficient to `1.0`;
- set minimum normal force to `0`;
- set maximum per-contact normal force to
  `whole_system_mass_kg * |gravity|`;
- set nominal support count to `4`;
- set feasibility tolerance to `1e-5`; and
- set every preferred normal force to `0`.

This is a live weight-support allocation and `J-transpose` mapping shadow, not
balance feedback. It deliberately introduces no tuned corrective gain before
host response is characterized.

The v2 mapper is atomic over exact compiled actuator order. A three-contact
centroidal command lacks an endpoint-force command for the swing limb, so its
mapping call must fail closed with the typed missing-contact reference and
count as unavailable. A mapping is available only when every compiled
actuator's declared limb contact appears in the feasible centroidal command.
An available sample must map all eight actuators, compare all eight against
the independent GDScript formula, and contain at least one absolute
generalized torque above `1e-6 N m`.

On every step where at least three qualified support contacts make the
centroidal command feasible:

1. use live v2 whole-system state;
2. form the frozen centroidal request;
3. call the native centroidal command;
4. emit live joint anchors, directed axes, and semantic endpoint positions;
5. call the portable `J-transpose` mapper; and
6. compare every generalized torque with an independent GDScript
   `dot(axis cross lever, force)` calculation.

The comparison tolerance is `5e-5 N m`, matching the already-frozen Godot
binary32 boundary scale. Missing support, rank-deficient geometry, or
infeasible upstream commands are explicit unavailable/infeasible samples;
they are not mismatches and they produce no actuator contribution.

Required retained receipt fields:

- attempted, available, unavailable, infeasible, and mismatch counts;
- maximum absolute torque error;
- maximum absolute commanded generalized torque;
- exact actuator comparison count;
- failure-code set;
- source, adapter-manifest, test, transcript, and report hashes; and
- all actuation/physics/recovery/acceptance flags false.

Exit: one clean-source full-gait shadow has at least one available mapping,
zero mismatches, no untyped loss, a nonzero mapped torque, and no physics
mutation.

### P5I.1 result

Source commit
`e85cc2fb8b500ced389d8ccc74671671b60cf190` implements the frozen live
mapping shadow in the Godot/Jolt adapter manifest v4. On every eligible
Candidate 35 step it constructs the zero-gain weight-support request from
live qualified contacts using the characterized `controller_mu = 1.0`, emits
live anchors, directed axes, and endpoints, calls the real GDExtension
`map_endpoint_force_to_joint_v2_json` operation, and compares every available
generalized torque with the independent GDScript virtual-work formula.

The clean-source report is retained at
`<evidence-root>\godot-jolt-joint-mapping-shadow-e85cc2f\report.json`
(SHA-256
`2aa5047762a0cbbb7562422682987eb2993da4f21f1540fe0637003bd7d77371`).
Its retained `transcript.log` has SHA-256
`4c97605af33e8323a2e1d8574a987ec092bf0652c4ce5be5c61b68ccd1f6a5ab`.
The run passes `20/20` gates and records:

- `1,514` live observations and mapping attempts;
- `821` available exact-order, eight-actuator maps;
- `627` typed unavailable maps when the v2 atomic request lacks a swing-limb
  endpoint command;
- `66` typed centroidal infeasibilities;
- `6,568` independently compared actuator commands;
- zero mapping mismatches and no failure codes;
- maximum absolute commanded generalized torque
  `0.2805286655276139 N m`; and
- maximum absolute mapping error
  `2.7783076367304815e-8 N m`, below the frozen `5e-5 N m` tolerance.

The same run retains Candidate 35's walking gates and command shadow parity
without changing Candidate 35 or applying a stability command. Every
actuation, physics-mutation, actuator-response, balance-recovery, material
robustness, and physical-acceptance flag remains false. This closes P5I.1
only.

## P5I.2 — isolated host response characterization

P5I.0 and P5I.1 had passed before this gate was opened. The exact fixture,
stimuli, fit, derived coefficient, evidence fields, and stopping rule below
were frozen in source
`ca75e62a4ac432485344d205de514dc35bb50f90` before implementation source
`c816ab36e4b696d8e8073fac88e6570242909609` was committed and pushed and
before the first P5I.2 result was observed.

Godot 4.7 documents the `HingeJoint3D` motor as a target angular velocity in
radians per second plus a maximum motor impulse:

- [HingeJoint3D class](https://docs.godotengine.org/en/4.7/classes/class_hingejoint3d.html)
- [PhysicsServer3D hinge parameters](https://docs.godotengine.org/en/4.7/classes/class_physicsserver3d.html#enum-physicsserver3d-hingejointparam)
- [RigidBody3D angular velocity](https://docs.godotengine.org/en/4.7/classes/class_rigidbody3d.html)

Those host parameters are not a generalized-torque interface. P5I.2 therefore
characterizes a bounded local conversion for this exact Godot/Jolt adapter; it
does not change the portable virtual-work contract.

### Frozen P5I.2 fixture

Run exactly three repetitions. Each repetition constructs a fresh isolated
world with:

- Godot `4.7`, Jolt Physics, `120 Hz`, `20` velocity steps, and `7` position
  steps;
- one frozen parent and one `1.0 kg` dynamic child per stimulus cell;
- child custom inertia
  `(0.05, 0.05, 0.05) kg m^2`, zero gravity, zero linear/angular damping,
  sleeping disabled, and collision layer/mask zero;
- a center-of-mass `HingeJoint3D` with no lever arm, canonical directed axis
  `Vector3.BACK`, limits disabled, and motor enabled;
- no contact, force, torque, impulse, gait, controller, or transform/velocity
  write after the initial body activation; and
- canonical measured rate
  `(child.angular_velocity - parent.angular_velocity) dot axis_world`.

Every cell is a separate joint/body pair. A repetition may advance its cells
in one isolated world because collision is disabled and no pair shares a
body. The test must fail if mass, custom inertia, anchor, axis, damping,
gravity, collision, limit, motor, target-velocity, or maximum-impulse
properties do not round-trip within `1e-7` absolute error (`1e-9` for an
impulse below `1e-4 N m s`).

### Frozen P5I.2 stimuli

The directional hypothesis frozen before observation is:

```text
host_target_velocity_rad_s = -canonical_target_velocity_rad_s
```

The following cells run in all three independent worlds:

1. **Zero control:** canonical target `0`, maximum impulse
   `0.055 N m s`, held for `12` ticks.
2. **Local signed response:** canonical targets
   `[-0.075, -0.050, -0.025, -0.010, -0.0025,
     +0.0025, +0.010, +0.025, +0.050, +0.075] rad/s`,
   each at maximum impulses `0.045` and `0.055 N m s`, held for `12` ticks.
3. **Impulse-cap response:** canonical targets `-1.0` and `+1.0 rad/s` at
   maximum impulses
   `[0.00005, 0.0005, 0.005, 0.045, 0.055] N m s`, held for `4` ticks.
4. **Cap-saturation response:** canonical targets
   `[-2.0, -1.0, -0.5, -0.25, +0.25, +0.5, +1.0, +2.0] rad/s`
   at maximum impulse `0.0005 N m s`, held for one tick.
5. **Reversal response:** canonical `+0.075 rad/s` for `12` ticks followed by
   `-0.075 rad/s` for `12` ticks, and the sign-reversed sequence, at both
   `0.045` and `0.055 N m s`.

Record canonical rate after every physics tick. Record the first-tick angular
acceleration as `120 * rate_tick_1`, time to first reach `90%` of the target,
maximum magnitude, reversal zero-crossing tick, realized host parameter
values, and inferred child angular impulse
`0.05 * abs(rate_tick_1 - rate_tick_0)`.

### Frozen P5I.2 fit and acceptance

For the local signed-response cells, let `x` be canonical target rate and `y`
be measured canonical rate at tick `12`. Fit one zero-intercept gain across
all signs, both legacy hip/knee impulse caps, and all repetitions:

```text
g = sum(x*y) / sum(x*x)
```

The result passes only if all of the following hold:

- every nonzero local cell has the sign of `x`;
- both `+/-0.0025 rad/s` cells reach at least `50%` of requested magnitude,
  bounding the observed deadband above by `0.0025 rad/s`;
- `0.95 <= g <= 1.05`;
- maximum local fit residual is at most `0.002 rad/s`;
- maximum same-cell inter-repetition spread is at most `0.001 rad/s`;
- maximum signed-pair asymmetry `abs(y_positive + y_negative)` is at most
  `0.002 rad/s`;
- every local cell reaches `90%` magnitude within `4` ticks without exceeding
  `1.10 * abs(x) + 0.001 rad/s`;
- first-tick impulse-cap response is nondecreasing across the five caps for
  each sign, with each of the first four strictly weaker than its successor
  by at least `0.0001 rad/s`;
- at cap `0.0005 N m s`, the first-tick magnitude across target magnitudes
  `0.25` through `2.0 rad/s` differs by no more than `0.001 rad/s` per sign;
- every reversal crosses zero within `4` ticks after the switch and reaches
  `90%` of the opposite target within `8` ticks, without exceeding the same
  overshoot bound; and
- no nonfinite value, untyped loss, engine error, or fixture mutation occurs.

Derive the local fit uncertainty prospectively as:

```text
u = max(
  abs(g - 1),
  maximum_fit_residual / 0.025,
  maximum_repetition_spread / 0.025,
  maximum_signed_pair_asymmetry / 0.025
)
k_nominal = min(0.25, 0.25 / g)
k_conservative = k_nominal * (1 - u)
```

The characterization is accepted only when `u <= 0.10`,
`0.20 <= k_conservative <= 0.25 rad/s per N m`, and

```text
k_conservative * 0.2805286655276139 N m <= 0.075 rad/s
```

where `0.2805286655276139 N m` is the maximum live generalized command opened
by the completed P5I.1 shadow. The published adapter coefficient is exactly
`k_conservative`; `u`, `g`, the nominal value, and the tested torque/velocity
envelope remain explicit in its profile. Nothing may round the coefficient
up, hide the uncertainty, or extrapolate beyond that envelope.

### Frozen P5I.2 evidence and stopping rule

The exact machine receipt schema is
`sporespore_godot_jolt_motor_response_receipt_v1`; the retained report schema
is `sporespore_godot_jolt_motor_response_report_v1`. The harness must pass
exactly `16/16` named gates covering engine pins, malformed-fixture rejection,
three independent repetitions, parameter round trips, zero response, sign,
deadband, fit gain, fit residual/asymmetry, repetition spread, response time,
impulse ordering, cap saturation, reversal, coefficient derivation, and all
nonclaims.

The implementation must be committed and pushed before the first P5I.2
fixture is run. Eligible retained evidence requires a clean source commit,
source/bootstrap/test/rig/runner hashes, Godot executable hash and version,
transcript and engine-log hashes, complete per-cell time series, exact fit
intermediates, zero engine errors, and all locomotion/balance/acceptance
authorities false.

Any miss rejects P5I.2 at that source. There is no selective repetition,
coefficient substitution, threshold relaxation, or gait use. A later attempt
requires a new prospectively amended gate and version.

This isolated gate determines:

- the sign from canonical positive generalized torque to Jolt motor target
  velocity;
- the bounded early angular-acceleration/velocity response at the pinned
  `120 Hz`, `20/7` solver configuration;
- interaction with the declared per-step impulse cap;
- deadband, saturation, and reversal behavior; and
- a conservative torque-to-velocity contribution coefficient and uncertainty
  envelope.

Exit: the Godot/Jolt manifest can truthfully replace
`actuator_mapping = unavailable` with a source-pinned characterized mapping
for the declared hinge motor only.

### P5I.2 result

The first and only eligible clean-source run at implementation commit
`c816ab36e4b696d8e8073fac88e6570242909609` passed all `16/16` frozen gates.
Its complete three-world, `43`-cell-per-world report is retained at
`<evidence-root>\godot-jolt-motor-response-c816ab3\report.json`
(SHA-256
`aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729`).
The adjacent transcript and engine log have SHA-256
`6dc63796f5cea4f6fca1b922e7cf5c7c137dd9a8b08f13b67c57a6578fd7a9ac`
and
`273105c6bf2d03cea4230bcba7c6945b098bacc52ed0df7a89cf2225b82463dd`,
respectively; the engine-error count is zero.

The accepted characterization is:

- canonical-positive target to host target-velocity sign: `-1`;
- zero-intercept local gain: `1.00000003022822`;
- maximum local fit residual:
  `7.663529394408286e-10 rad/s`;
- maximum same-cell repetition spread: `0 rad/s`;
- maximum signed-pair asymmetry: `0 rad/s`;
- derived uncertainty fraction:
  `3.0654117577633144e-8`;
- nominal coefficient:
  `0.24999999244294524 rad/s per N m`;
- published conservative coefficient:
  `0.24999998477941607 rad/s per N m`; and
- maximum proposed velocity at the P5I.1 torque envelope:
  `0.07013216211209337 rad/s`, within the tested `0.075 rad/s` local
  envelope.

Publication source
`3b54b3f975298c08f00aacb6d1423f7d2897ecd4` pins that exact profile in the
Godot/Jolt adapter manifest v5 and adds the pure fail-closed
`characterized_host_velocity_delta_for_generalized_torque` conversion. It
rejects nonfinite values and magnitudes outside the characterized
`0.2805286655276139 N m` envelope, reverses the host sign explicitly, and
does not apply the returned proposal to a motor.

The clean publication-source SDK regression passed Rust core `46/46`, Rust
Godot boundary `2/2`, Rapier `5/5`, Candidate 35 GDScript `105/105`,
stability GDScript `23/23`, native Godot `24/24`, and Python real-DLL ABI
`9/9`, plus warnings-as-errors Clippy, tests, docs, and offline release
builds. The separate Godot/Jolt C2-C5 physical adapter regression passed
`20/20`; its durable transcript is
`<evidence-root>\godot-jolt-c2-c5-profile-regression-3b54b3f\transcript.log`
(SHA-256
`4a64ed783d119e3db8d6622a3474cab839b09f5035e85a1cdfb4c112cea20e0f`).

The same publication source passed the full already-opened Candidate 35
same-world shadow `20/20`. Its retained report and transcript are:

- `<evidence-root>\godot-jolt-motor-profile-shadow-3b54b3f\report.json`
  (SHA-256
  `1aa0f5e20fea276373a8db0c6c22c137de506970057f375f6f70dd07c76d8a5b`);
- `<evidence-root>\godot-jolt-motor-profile-shadow-3b54b3f\transcript.log`
  (SHA-256
  `4f022c1cc719507c0e2f999cac3d203b4488f5014265c64649471ced09c760d7`).

That regression preserved `1,514` typed mapping attempts, `6,568` independent
generalized-torque comparisons, `12,112` Candidate 35 command comparisons,
zero mismatches, and zero stability actuation, host response, balance
recovery, or physical-acceptance authority. This closes P5I.2 only.

## P5I.3 — bounded contribution and authority

P5I.3 is split so pure mapping, live shadow transport, bounded contribution,
and physical authority cannot be inferred from one another.

### P5I.3A — versioned partial-support map

The atomic v2 map remains immutable. Implement the separate v3 operation
frozen in
[Locomotion Semantics v3](LOCOMOTION_SEMANTICS_V3.md). It must retain every
compiled actuator in order, apply unchanged virtual-work mapping to actuators
whose declared contact is in the feasible centroidal command, and emit an
explicit exact-zero stability command for every inactive-contact actuator.

The pure v3 source, public C header, Python binding, Godot GDExtension,
independent GDScript oracle, dedicated report runner, and malformed-input
surface must pass before any live v3 shadow result is opened. In particular,
the three-contact quadruped fixture must map six support actuators and return
two exact-zero swing-limb commands; full support must remain numerically
equivalent to v2.

The implementation commit must be pushed before the first live Candidate 35
v3 shadow. A miss rejects P5I.3A at that source.

#### P5I.3A result

Source commit
`8d1c5364d945102387b1763f3d0c17a1db86c059` implements the separate
partial-support v3 operation across Rust, the C ABI, Python, and the Godot
GDExtension without changing v2. Its retained clean-source report is
`<evidence-root>\stability-v3-subset-map-8d1c536\report.json`
(SHA-256
`0de2d43dda1698a1e716aae8f0fd693c0211c25f5cc617c5f7d2135510bcc8a9`);
the adjacent transcript has SHA-256
`2e50bbc62da0375953159523aebb4370d1bb3e0654aad8485d0bf07d78c07286`.

The clean pushed-source gates pass Rust `5/5`, independent GDScript `12/12`,
native Godot `27/27`, and Python real-DLL ABI `10/10`. The three-contact
fixture retains all eight ordered actuators, maps six support actuators, and
emits exact-zero endpoint force and generalized torque for both swing-limb
actuators. Full support is numerically equivalent to v2; translation,
independent virtual-work, typed malformed-input, and authority-nonclaim checks
all pass. This closes P5I.3A only. No live physics world was constructed by
the gate.

### P5I.3B — live partial-support and contribution shadow

This section prospectively freezes the first P5I.3B result. Implementation may
begin only after the amendment commit is pushed. The implementation commit must
also be pushed before constructing the first live P5I.3B world. A miss rejects
that source revision; thresholds, counts, or topology must not be changed
against the observed failure.

P5I.3B replays the exact already-opened Candidate 35 one-world evidence segment.
It introduces no new morphology, no Candidate 35 policy edit, no motor write,
and no physics mutation. For each of the retained `1,514` evidence steps it:

1. records the unchanged live v2 stability state and observer receipt;
2. invokes the unchanged P5I.1 zero-gain controller with
   `controller_mu = 1.0` to request weight-support centroidal force;
3. retains the v2 endpoint-force-to-joint result as a comparison only;
4. when the centroidal request is feasible, invokes the P5I.3A v3 mapper over
   all eight exact-order actuators and the current active-contact subset;
5. converts all eight v3 generalized-torque commands to canonical velocity
   proposals with the conservative P5I.2 coefficient
   `0.24999998477941607 rad/s/Nm`;
6. passes all eight proposals through
   `sporespore_stability_influence_request_v2`; and
7. records the proposed canonical contribution, bounded canonical
   contribution, and characterized host delta. The characterized host sign is
   exactly `-1`, so `host_delta = -applied_canonical_velocity`.

The prospective influence limits are:

- maximum absolute position contribution: `0 rad`;
- maximum position slew: `0 rad/step`;
- maximum absolute canonical velocity contribution: `0.075 rad/s`;
- maximum canonical velocity slew: `0.010 rad/s/step`;
- requested position on an available command: exactly `0 rad`; and
- prior state: the previous semantic step plus all eight prior bounded
  canonical actuator receipts, carried in exact actuator order except for the
  typed inactive-contact hard-zero rule below.

An inactive-contact v3 command must have exact-zero endpoint force, generalized
torque, proposed velocity, bounded canonical velocity, and host delta. A typed
`inactive_contact_zero` mapping therefore replaces that actuator's prior
position and velocity contribution with exact zero before invoking the
stateful influence boundary. This per-actuator safety mask bypasses slew only
on the transition to inactive contact; it is separately counted and
independently reconstructed. When the contact becomes active again,
contribution slew resumes from zero. A typed centroidal infeasible result
instead invokes the influence boundary with
`availability = upstream_infeasible`, eight ordered null requests, and the
prior receipts. The required fallback is an immediate exact zero for every
actuator; this fail-zero transition bypasses the normal slew limit. Observation
loss, untyped failure, mapping failure, nonfinite data, stale semantic step,
order mismatch, manifest/profile mismatch, or any motor/physics mutation
rejects the source.

The following counts are derived prospectively from the retained P5I.1 segment
and are exact acceptance values:

- observations and attempts: `1,514`;
- full-support attempts: `821`;
- partial-support attempts: `627`;
- v3 available attempts: `1,448`;
- typed upstream-infeasible attempts: `66`;
- unavailable or untyped attempts: `0`;
- ordered v3 commands: `11,584` (`1,448 * 8`);
- active-support commands: `10,330` (`821 * 8 + 627 * 6`);
- inactive-contact commands: `1,254` (`627 * 2`);
- influence outputs: `12,112` (`1,514 * 8`); and
- typed fallback-zero outputs: `528` (`66 * 8`).

The retained v2 comparison must remain `821` available, `627` unavailable, and
`66` infeasible attempts. This is deliberate: v3 closes the typed
partial-support mapping gap without rewriting the v2 historical comparator.

The first result is accepted only if all `28/28` frozen gates pass:

1. the exact counts above match;
2. all unchanged Candidate 35 evidence gates pass;
3. all `12,112` shadow outputs preserve zero motor and physics mutations;
4. full-support v3 generalized torque agrees with v2 within `5e-5 Nm`;
5. each active-support v3 torque agrees with an independent GDScript
   virtual-work calculation within `5e-5 Nm`;
6. every inactive endpoint force, torque, requested velocity, bounded velocity,
   and host delta is bit-exact zero;
7. maximum absolute generalized torque is at most
   `0.2805286655276139 Nm`;
8. maximum absolute proposed velocity is at most
   `0.07013216211209337 rad/s`;
9. maximum absolute bounded canonical velocity and host delta are each at most
   `0.075 rad/s`;
10. at least one active command is nonzero and at least one active command is
    slew-limited;
11. no command reaches the magnitude limit;
12. every typed infeasible output is an immediate exact zero; and
13. an independent GDScript reconstruction of the stateful limiter has zero
    order/availability mismatches and numerical error at most `5e-8`.

The report must use schema
`sporespore_godot_jolt_stability_contribution_shadow_report_v1`, identify the
exact P5I.2 profile and implementation source, record all frozen thresholds and
counts, and keep actuation, physical influence, balance recovery, locomotion,
robustness, cross-engine, acceptance, and completed-SDK claims false.

#### First P5I.3B result — rejected

Implementation source
`6472c6f0b45b3e4dc444e9b7afc3c86fc395fb7a` produced its first and only
live result at `25/28`. The exact attempt, support, command, influence-output,
infeasible-fallback, Candidate 35, inactive-zero, and limiter-reconstruction
gates matched. The source was rejected because partial-support load
redistribution produced raw v3 generalized torques up to
`1.398691142269526 Nm`, outside the P5I.2 characterized profile ceiling of
`0.2805286655276139 Nm`. The adapter failed those conversions closed and
recorded `2,217` contribution mismatches. No motor or physics mutation occurred.

The rejection evidence is retained outside the temporary tree:

- report:
  `<evidence-root>\godot-jolt-stability-contribution-shadow-6472c6f-rejected\report.json`
- report SHA-256:
  `2c4e54a4b7d91b6a3874797eadfdf9e326d7233c5f06422786d62960c069cf9b`
- transcript:
  `<evidence-root>\godot-jolt-stability-contribution-shadow-6472c6f-rejected\transcript.log`
- transcript SHA-256:
  `591772e4a1db23faa8f30043a41295ef31de5965d02b7f45a791d5dc6b1a426c`

This is not a failed limiter, v3 map, walking run, or fail-zero result. It is a
failed assumption that every partial-support raw torque would remain inside the
isolated P5I.2 motor-response characterization envelope. The rejected source
must never be rerun or promoted.

#### P5I.3B-R1 prospective amendment

R1 changes one adapter rule before its implementation or first live result:

1. retain the raw v3 generalized torque unchanged for the independent
   virtual-work comparison and report;
2. compute `profile_input_torque_nm` by clamping that raw command to
   `[-0.2805286655276139, +0.2805286655276139] Nm`;
3. record an exact `profile_input_clamped` flag and aggregate count;
4. apply the unchanged P5I.2 conservative coefficient only to the bounded
   profile input; and
5. pass that proposal through the unchanged P5I.3B influence limits and typed
   inactive/infeasible fail-zero rules.

The rule uses the pre-existing characterized profile boundary; it does not fit
a new threshold to the observed `1.398691142269526 Nm` maximum. R1 must record
at least one exercised profile-input clamp, zero profile-conversion failures,
maximum absolute profile input at most `0.2805286655276139 Nm`, and maximum
proposal at most `0.07013216211209337 rad/s`. The rejected raw maximum remains
descriptive and has no acceptance ceiling other than finiteness and independent
v3 virtual-work agreement.

All other prospective counts, `28/28` gates, tolerances, limits, topology,
stopping rules, report schema, and nonclaims above remain unchanged. R1
implementation must be committed and pushed before its one permitted first
live result. Any R1 miss rejects that new source.

#### P5I.3B-R1 result — passed

Clean pushed implementation source
`38ff4b3ee7ee548efaf2df7e76ba7e13d2ab9a86` passed its first live result
`28/28`. The retained evidence is:

- report:
  `<evidence-root>\godot-jolt-stability-contribution-shadow-38ff4b3\report.json`
- report SHA-256:
  `0fb641f3aa8bf4a7e2aa3c8da64a35355c88f348aef2216519bc69f076044826`
- transcript:
  `<evidence-root>\godot-jolt-stability-contribution-shadow-38ff4b3\transcript.log`
- transcript SHA-256:
  `7cec0ee1063f2aa3de3955c2cbb1c8470f8ece7a10cee327ef7a6a9b226d1c30`

The source-clean report records the exact `1,514` attempts, `821`
full-support results, `627` partial-support results, `1,448` available v3
maps, `66` typed upstream-infeasible results, `11,584` ordered v3 commands,
`10,330` active commands, `1,254` inactive exact-zero commands, `12,112`
influence outputs, and `528` fallback zeros. All v3/v2 and independent
virtual-work comparisons pass. The raw descriptive v3 maximum is
`1.398691142269526 Nm`; `2,217` profile inputs are explicitly clamped to the
pre-existing `0.2805286655276139 Nm` P5I.2 limit, with zero conversion
failures. Maximum proposal, bounded contribution, and host delta are each
`0.07013216211209337 rad/s`; the maximum independent limiter reconstruction
error is `9.98821251402271e-18`.

Candidate 35's unchanged walking and command-parity gates remain green. All
adapter actuation, physics mutation, physical balance recovery, locomotion
robustness, cross-engine, acceptance, and completed-SDK flags remain false.
This closes the live contribution shadow only; it does not authorize P5I.3C.

### P5I.3C — separately authorized opened-body influence

P5I.3B-R1 permits this prospective amendment. P5I.3C assigns:

- policy identity: `p5i3c_support_centroid_tilt_feedback_v1`;
- runtime identity:
  `sporespore_godot_jolt_stability_overlay_runtime_v1`; and
- memory identity: `sporespore_stability_overlay_memory_v1`.

Candidate 35 remains the unchanged gait base and legacy conformance oracle. It
does not own the stability policy, gains, limiter state, or overlay authority.
P5I.3C remains an already-opened-body commissioning result and cannot repair,
reselect, or promote Candidate 35.

#### Frozen feedback law

For every live stability observation in the exact Candidate 35 evidence window:

1. retain the observed center-of-mass forward coordinate and height;
2. target only the lateral coordinate of the observed support centroid;
3. pass the true whole-system center-of-mass velocity unchanged;
4. derive torso roll and pitch from body up relative to the gravity-aligned
   support forward/lateral frame;
5. derive roll and pitch rates by projecting true torso angular velocity onto
   those axes; and
6. invoke the existing portable centroidal controller with:

   - horizontal position gain: `5.0 N/m`;
   - horizontal velocity gain: `0.1 Ns/m`;
   - maximum horizontal force: `0.75 N`;
   - vertical position/velocity gains and correction limit: exact zero;
   - roll and pitch position gains: `0.5 Nm/rad`;
   - roll and pitch velocity gains: `0.05 Nms/rad`;
   - maximum absolute roll/pitch moment: `0.10 Nm`;
   - supported weight fraction: `1.0`;
   - controller friction coefficient: `1.0`; and
   - the unchanged P5I.3B-R1 map, profile-input clamp, influence limits,
     inactive hard-zero, and infeasible fallback.

The lateral-only target prevents the position term from chasing the support
centroid forward through a walking cycle. The small velocity term remains
isotropic because that is the portable v2 contract. These gains are frozen
from dimensional/mechanical scale before a physical P5I.3C result; they are not
fit to a treatment outcome.

#### Frozen authority rule

The treatment retains the unchanged legacy base motor command. For each
exact-order actuator it adds the P5I.3B-R1 characterized host contribution to
that base target, clamps the combined target to the base command's existing
per-joint speed limit, writes only
`HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY`, and reads the parameter back. It
never changes a motor impulse limit, body transform, body velocity, force,
impulse, contact, phase, gait target, or Candidate 35 memory.

Typed inactive and upstream-infeasible contributions are exact zero. A missing,
stale, reordered, nonfinite, uncharacterized, or failed receipt disables the
whole eight-actuator overlay for that step and restores the already-computed
base targets. Host saturation is permitted only at the pre-existing base speed
limit and must be counted. Maximum requested and effective overlay magnitude
remain `0.075 rad/s`; readback error must be at most `2e-8 rad/s`.

#### Frozen paired experiment

The first result runs exactly two sequential, independently constructed
Candidate 35 worlds under the same clean pushed implementation:

1. **control:** compute the new feedback policy and all portable receipts, but
   apply no stability overlay; and
2. **treatment:** compute the identical policy and apply the bounded overlay
   during the exact `1,514`-step evidence window.

Both cells use the same reference morphology, initial state, GQ15 clock,
Candidate 35 base, Godot 4.7, Jolt, `120 Hz`, and `20/7` solver. There is no
external perturbation, material change, sensor fault, morphology change, or
new gait selection. The result is accepted only at `24/24`:

1. the frozen clock compiles;
2. control constructs exactly one world;
3. treatment constructs exactly one world;
4. both cells report identical pinned configuration identities;
5. control retains all Candidate 35 walking gates;
6. treatment retains all Candidate 35 walking gates;
7. control records exactly `1,514` feedback-shadow steps;
8. treatment records exactly `1,514` feedback-overlay steps;
9. both cells record at least `1,000` available contribution steps, zero
   unavailable/untyped outcomes, and at least one nonzero feedback request;
10. control records zero SDK motor writes;
11. treatment records exactly `12,112` ordered SDK overlay motor writes;
12. treatment records at least one nonzero effective overlay;
13. requested and effective overlays remain within `0.075 rad/s`;
14. every combined target respects its existing base speed limit and readback
    error is at most `2e-8 rad/s`;
15. inactive and infeasible fail-zero mismatches remain zero;
16. mapping, profile conversion, order, and limiter mismatches remain zero;
17. both cells retain zero direct torso/body force, impulse, velocity, or
    transform writes;
18. paired initial torso position and orientation agree within `1e-9`;
19. treatment and control terminal torso positions differ by at least
    `1e-5 m`, establishing a causal physical effect;
20. treatment maximum tilt is no more than control plus `0.02 rad`;
21. treatment absolute final lateral drift is no more than control plus
    `0.05 m`;
22. treatment final forward advance is no less than control minus `0.10 m`;
23. treatment maximum anchor error is no more than control plus `0.005 m` and
    maximum hinge-axis error is no more than control plus `0.02 rad`; and
24. the report, policy/runtime/memory identities, authority counters, and all
    physical-influence versus recovery/robustness nonclaims are exact.

The report schema is
`sporespore_godot_jolt_stability_physical_influence_report_v1`. Implementation
must be committed and pushed before the first paired result. A miss rejects
that source; no threshold, gain, topology, or cell may be edited against the
observed outcome.

#### First P5I.3C result — rejected

Clean pushed implementation source
`a8ac24870bb7c8d72d9e0c7a2e5e3bd1c1fd7a95` produced its first and only
paired result at `19/24`. The control completed `1,514` shadow steps and
retained Candidate 35 walking. The treatment produced a nonzero physical
effect (`0.130792528390884 m` terminal torso-position separation), but it is
not accepted:

- `959` treatment steps failed the frozen motor-parameter readback check and
  restored all eight legacy base commands;
- only `554` treatment steps and `4,432` overlay motor writes were accepted;
- the treatment's contact-gated evidence horizon ended after `1,513` adapter
  steps rather than the frozen `1,514`; and
- the SDK overlay walking receipt consequently remained false.

The failure is retained at:

- report:
  `<evidence-root>\godot-jolt-stability-physical-influence-a8ac248-rejected\report.json`
- report SHA-256:
  `7fb5d48e1eae21f342aa9050bfdd201b046188a5d8b15b0451ab73fc1b811270`
- transcript:
  `<evidence-root>\godot-jolt-stability-physical-influence-a8ac248-rejected\transcript.log`
- transcript SHA-256:
  `5398371a6aea4caea95fb423287321960b59e2975dd4d48ea7f915c05cc39f48`

The source must not be rerun or promoted. The result does not establish
physical stability influence even though it observed a terminal difference,
because its frozen authority and exposure gates failed.

#### P5I.3C-R1 prospective amendment

R1 changes two host-boundary rules before its implementation or first result.
It does not change the feedback gains, portable controller, map, motor-response
profile, contribution limiter, Candidate 35 base, paired cells, physical
thresholds, `24/24` stopping rule, or nonclaims.

First, Godot/Jolt stores the hinge motor parameter at the host `real_t`
boundary. R1 must form the expected host command explicitly:

1. round the already-computed legacy base target to IEEE-754 binary32 with a
   `PackedFloat32Array` round trip;
2. add the unchanged characterized binary64 host contribution;
3. clamp to the unchanged host-representable base speed limit;
4. round the combined command to binary32 before calling
   `HingeJoint3D.set_param`; and
5. compare `get_param` with that exact host-representable command.

The readback tolerance remains exactly `2e-8 rad/s`; it is not widened against
the rejected result. R1 separately records the absolute binary64-to-host
command quantization error, which must be at most `1.2e-7 rad/s` for the
existing `3.5 rad/s` command envelope. Requested and realized effective
overlay deltas must remain at most `0.075 rad/s`. Failures still restore all
eight host-representable legacy base commands atomically.

Second, feedback must not be allowed to choose its own experimental exposure
by changing contact timing. Both cells therefore use an adapter exposure clock
of exactly `1,514` consecutive steps beginning at the unchanged Candidate 35
evidence start. This clock controls only SDK observation and overlay writes; it
does not change Candidate 35's gait amplitude, contact-gated phase,
walking-evidence termination, cooldown, or acceptance thresholds. The
treatment must count exactly `1,514 * 8 = 12,112` legacy base motor writes in
that exposure and exactly `12,112` successful SDK overlay writes. The walker
must report the ordinary Candidate 35 walking gates separately from this fixed
paired-exposure receipt.

The R1 runner must retain both passing and rejected reports before returning
its process status. The implementation commit must be pushed before the one
permitted R1 paired result. Any R1 miss rejects that new source; there is no
selective cell rerun, readback-tolerance widening, step-count relaxation, or
post-result gain change.

#### P5I.3C-R1 result — rejected

Clean pushed implementation source
`80f7acd1aacd4e397a1501a7d050a7c826985f93` produced its first and only
paired result at `21/24`. R1 resolved both defects it was authorized to
change:

- control and treatment each recorded exactly `1,514` adapter steps;
- treatment recorded exactly `12,112` legacy base motor writes;
- treatment motor readback error was exact zero;
- maximum explicit host-command quantization error was
  `1.1894214768659594e-7 rad/s`, within the frozen `1.2e-7` bound; and
- requested and effective overlay magnitudes remained below `0.075 rad/s`.

The source remains rejected because `90` treatment steps failed an
observation-only Candidate 35 dynamic-parity comparator before overlay
application. This caused `126` comparator mismatches, `90` whole-step legacy
restorations, and only `11,392` accepted SDK overlay writes. The mismatches had
zero phase error and zero speed-limit error. Their maxima were
`3.17537e-9 rad` target position, `2.540297e-8 rad/s` target velocity, and
`1.058457e-8` held steering. Candidate 35's authoritative legacy base still
passed every ordinary physical walking, geometry, contact, and body-write
gate; the failed walking receipt was the separate SDK-overlay authority gate.

The retained R1 evidence is:

- report:
  `<evidence-root>\godot-jolt-stability-physical-influence-r1-80f7acd\report.json`
- report SHA-256:
  `33c9784f76880304ffd30112daf1efeb0452e9b1f334c9959e9dc0638ae2d239`
- transcript:
  `<evidence-root>\godot-jolt-stability-physical-influence-r1-80f7acd\transcript.log`
- transcript SHA-256:
  `350fbef82969f67efc9f61a9d59a4c2a520280d54212e94b67da141d82ceedf7`

R1 must not be rerun or promoted.

#### P5I.3C-R2 prospective amendment

R2 changes one authority dependency before implementation or a first R2
result. It does not widen the Candidate 35 comparison tolerance and does not
change any feedback, map, profile, limiter, host-quantization, exposure,
walking, geometry, or paired-effect gate.

In `stability_contribution_overlay` scope, the authoritative base motor command
is the unchanged legacy Candidate 35 command that has already been written and
recorded for that exact step. The native Rust Candidate 35 output is an
observation-only conformance diagnostic; it is never used to form the base or
combined motor target. R2 therefore separates:

- `candidate35_shadow_parity_ok`, which retains the existing `2e-8`
  comparator, exact mismatch counts, and maxima without physical authority;
  from
- `stability_overlay_runtime_ok`, which alone authorizes the bounded overlay
  after requiring a successful native transport, no safe-no-actuation result,
  exact stability-contribution semantic step and actuator order, zero
  stability mapping/profile/limiter/fail-zero mismatches, valid legacy base
  contexts, bounded host commands, and successful motor readback.

Only the typed `ADAPTER_DYNAMIC_PARITY_MISMATCH` result may be decoupled in
overlay scope. Native transport failure, safe-no-actuation, missing output,
stale contribution, mapping or order failure, nonfinite value, failed
characterization, limiter failure, base-context failure, host-bound failure,
or readback failure still restores all eight legacy base commands and rejects
the step.

The control must retain zero Candidate 35 mismatches under the unchanged
comparator. The treatment must retain the mismatch count and maxima
descriptively, with exact zero phase and speed-limit error; they are not
silently rounded or relabeled as parity. The `24/24` physical gate remains
unchanged: both ordinary Candidate 35 walking results must pass, both fixed
exposures must be `1,514` steps, treatment must have `12,112` successful
overlay writes, and every existing influence, paired-geometry, and nonclaim
check remains in force.

The R2 implementation commit must be pushed before its one permitted paired
result. The pass-or-reject runner remains mandatory. Any R2 miss rejects that
source without a selective cell rerun, comparator-tolerance edit, or gain
change.

#### P5I.3C-R2 result — passed

Clean pushed implementation source
`df6c9e55e2e8eaf9433eba83f70d6031ca186592` passed its first and only R2
paired result at `24/24`. The retained evidence is:

- report:
  `<evidence-root>\godot-jolt-stability-physical-influence-r2-df6c9e5\report.json`
- report SHA-256:
  `d0971317d174f7bb5aef4cbea1f79c462182a0cd3e4ce59c83980ef6a7cb305b`
- transcript:
  `<evidence-root>\godot-jolt-stability-physical-influence-r2-df6c9e5\transcript.log`
- transcript SHA-256:
  `70f7e728c078ff2809dec0d2112ff51384a6883f2e2c36c70c4a3ad47809c48b`

Both cells constructed one independent world, used identical pinned
configuration identities, retained Candidate 35's ordinary walking gates, and
recorded exactly `1,514` SDK steps. The control wrote no SDK motor command.
The treatment recorded exactly `12,112` legacy base commands and `12,112`
successful overlay motor writes, including `9,724` nonzero effective
applications and `430` base-speed-limit saturations. Overlay failures,
combined-speed-limit violations, motor readback error, stability mapping
mismatches, profile conversion failures, inactive/fallback mismatches, and
limiter mismatches were all zero. Maximum host-command quantization error was
`1.1894214768659594e-7 rad/s`, within the frozen `1.2e-7` bound.

The paired terminal torso positions differed by
`0.12983563542366028 m`. Treatment maximum tilt equaled the control maximum
(`0.1410518211585256 rad`), absolute final lateral drift was lower
(`0.019407594576478004 m` versus `0.05119657143950462 m`), and forward
advance remained within the preregistered allowance
(`1.3680222034454346 m` versus `1.2590619325637817 m`). Maximum anchor error
was lower than control; maximum hinge-axis error was
`0.10417529504014372 rad`, within the paired `+0.02 rad` allowance.

The unchanged treatment-only Candidate 35 shadow diagnostic still records
`126` mismatches at the old `2e-8` comparator, with maximum position,
velocity, and steering errors of `3.1753718265914443e-9 rad`,
`2.540297461967045e-8 rad/s`, and `1.0584572773808532e-8`; phase and
speed-limit error remain exact zero. Those values are retained as non-authority
diagnostics and are not called parity.

This closes P5I.3C with the narrow physical-influence claim only. The receipt
keeps balance improvement, balance recovery, locomotion robustness,
friction/material robustness, rough-terrain robustness, external-push
recovery, sensor-fault robustness, cross-engine locomotion, fresh-morphology
validation, physical acceptance, and completed-SDK claims false.

Exit: this newly identified stability policy passes opened-body physical
influence commissioning. Passing permits the narrow claim that portable
balance feedback physically influenced an already-opened Godot/Jolt
quadruped without breaking its existing walking gates. It does not establish
balance recovery, improved balance, fresh morphology, friction/material,
perturbation, cross-engine locomotion, or a completed SDK.

## Claim boundary

With all four commissioning gates passed, the repository may say:

- portable support and centroidal semantics exist;
- Godot/Jolt emits and shadows live stability state;
- the portable endpoint-force joint map agrees with an independent live
  Godot/Jolt oracle; and
- the pinned Godot/Jolt hinge motor has a source- and report-pinned local
  generalized-torque-to-target-velocity proposal within its characterized
  envelope; and
- the bounded portable stability policy physically influenced the
  already-opened reference Godot/Jolt quadruped without breaking its existing
  walking gates.

It may not say:

- balance recovery is demonstrated;
- balance improvement is demonstrated;
- Candidate 35 was repaired;
- friction/material robustness exists;
- cross-engine locomotion exists; or
- the engine-neutral SDK is complete.
