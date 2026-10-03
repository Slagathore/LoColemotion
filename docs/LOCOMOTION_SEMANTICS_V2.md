# Locomotion Semantics v2: Portable Stability

- **Status:** pure-core and Godot/Jolt live mapping shadow complete; host
  response and physical authority pending
- **Version:** `sporespore_locomotion_semantics_v2`
- **Portable implementation:** [`sdk/core/src/stability.rs`](../sdk/core/src/stability.rs)
- **Frozen predecessor:** [Locomotion Semantics v1](LOCOMOTION_SEMANTICS_V1.md)
- **Successor decision:** [ADR-016](adr/ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md)
- **Shared GDScript/Rust oracle:**
  [`sdk/conformance/golden/stability_v2_gdscript_oracle_v1.json`](../sdk/conformance/golden/stability_v2_gdscript_oracle_v1.json)

## Purpose and authority

Semantics v2 adds the portable state and pure mechanics needed to observe
whole-system support and bound a future stability contribution. It versions
rather than mutates v1. Candidate 35, its v1 state, runtime, C ABI, and golden
vectors remain frozen.

The implemented v2 slice establishes pure calculations only:

```text
ordered body/contact state
  -> geometric support observation
  -> bounded centroidal contact command
  -> portable endpoint-force/J-transpose map
  -> bounded contribution receipt

  != host contact qualification
  != characterized actuator response
  != actuator application
  != balance recovery
  != walking
  != physical acceptance
```

No v2 output currently owns an actuator or writes a physics world.

## Source oracles

The portable calculations are checked against the existing pure GDScript
mechanics:

| Semantics | GDScript oracle | Oracle source commit |
| --- | --- | --- |
| static COM/support margin | `scripts/lab/mechanics/spatial_support_margin_observer.gd` | `78ad74bed7c45fa4e2747957cfea56a9f04c0150` |
| dynamic COM/capture margin | `scripts/lab/mechanics/spatial_dynamic_support_observer.gd` | `776d1ea62a2f7337d2c70985de7cec5a879b4759` |
| centroidal contact command | `scripts/lab/mechanics/spatial_centroidal_support_controller.gd` | `325ccbae15d56a430ae4f859d83e5cef047f7def` |

The shared JSON vector is executed independently by:

- `tests/test_sdk_stability_v2_golden_vectors.gd`; and
- the Rust tests in `sdk/core/src/stability.rs`.

Run `sdk/run_stability_v2_conformance.ps1` for the focused gate. From a clean
committed worktree, pass `-Output C:\path\to\evidence\report.json` to retain a
machine-readable receipt binding the source, semantics, shared vector, test,
and Godot executable identities to the exact `15/15` Rust and `23/23` Godot
results.

The JSON freezes separate numeric boundaries:

- Rust binary64 absolute tolerance: `1e-12`;
- Godot binary32 vector tolerance: `1e-6`; and
- Godot binary32 force tolerance: `1e-5 N`.

Those are conformance boundaries for the pure oracle, not physical trajectory
tolerances.

## StabilityStateV2

Schema: `sporespore_stability_state_v2`.

The state contains:

- an exact semantic step;
- body poses and twists in compiled morphology order;
- contact observations in semantic contact order;
- gravity in world coordinates;
- a support-plane forward hint; and
- the exact adapter capability-manifest digest.

Each body state contains a semantic `body_id`, world pose, and world
linear/angular twist. The core obtains mass and body-local COM from the
compiled `MorphologySpec`; an adapter cannot replace those static properties.
For each body:

```text
r_com_world = R(q_body) * r_com_local
x_com_world = x_body + r_com_world
v_com_world = v_body + omega_body cross r_com_world
```

Whole-system position and velocity are mass-weighted from those reconstructed
body COM states.

The body-state list must match `ordered_body_ids` exactly. Missing, duplicate,
extra, or reordered body states fail closed.

## Qualified support contacts

Each support contact can carry:

- presence;
- separately qualified bearing;
- world contact point and unit normal;
- world surface-relative velocity;
- material identity;
- adapter identity; and
- one or more raw engine contact identities.

A contact enters the support set only when:

```text
presence == true
bears_support == true
point is available
unit normal is available
at least one engine contact identity is retained
```

Presence alone never becomes bearing. An absent contact cannot bear support.
Unavailable optional geometry remains unavailable rather than zero. Duplicate
semantic or engine contact IDs fail closed.

Normal force is not required to construct the support hull. No raw impulse is
summed into per-foot load.

## Gravity-aligned support geometry

The core normalizes `-gravity` as support up. It projects the supplied forward
hint into the gravity plane and derives the lateral axis from
`forward cross up`. A zero gravity vector or forward vector parallel to
gravity fails closed.

Qualified contact points are projected into this plane. The core then:

1. sorts projected points geometrically;
2. removes exact duplicates;
3. constructs the convex hull with the monotone-chain algorithm;
4. retains point and segment support as explicit zero-area states; and
5. calculates polygon centroid and signed edge distance from geometric hull
   order.

Semantic token order never defines polygon winding. Interior or concave input
enumeration cannot create a concave support polygon or change the margin.

The observation reports:

- whole-system mass, COM, and COM velocity;
- gravity-aligned support frame and mean support-plane height;
- support hull vertices, dimension, kind, and centroid;
- signed COM margin;
- linearized capture point and signed capture margin;
- minimum of static and capture margins;
- qualified and rejected contact counts; and
- explicit model and authority nonclaims.

For a point or segment, margin is the negative Euclidean distance to that
zero-area set. A point exactly on a segment has zero margin; the core does not
invent a polygon or discard the semantic tick.

## Linearized capture observation

For COM height `h > 0` and gravity magnitude `g`:

```text
omega_0 = sqrt(g / h)
x_capture = x_com + v_com_horizontal / omega_0
```

This is a linearized controller-state signal. The receipt always states:

- `linearized_capture_model_only = true`;
- `articulated_capture_guarantee_available = false`;
- `per_foot_measured_load_allocation_available = false`;
- `contact_presence_is_bearing_measurement = false`;
- `physics_state_modified = false`; and
- `physical_acceptance_authority = false`.

## CentroidalSupportRequestV2

Schema: `sporespore_centroidal_support_request_v2`.

The request supplies measured whole-system COM state, target COM, torso
roll/pitch and rates, bounded gains, a declared supported-weight fraction,
normal-force bounds, a characterized adapter friction coefficient, and at
least three ordinary support contacts.

The pure controller:

1. applies bounded COM position/velocity feedback in the gravity plane;
2. applies bounded vertical support correction;
3. applies bounded roll/pitch attitude-rate correction;
4. allocates normal commands with the minimum-norm solution to total normal
   force plus roll/pitch moment constraints;
5. iteratively redistributes tangent command in proportion to positive normal
   command;
6. checks normal bounds, friction reserve, force residual, moment residual,
   and contact-geometry rank; and
7. emits one ordered contact command and one opposing endpoint task-force
   delta per requested support contact.

The coefficient is named `characterized_friction_coefficient` deliberately.
It must come from an adapter material characterization; an authored Godot,
Rapier, or MuJoCo number is not assumed equivalent across engines.

Per-contact normal and tangent values are commands, never measurements.
Endpoint task-force deltas are not joint torques and are not applied. The
centroidal receipt keeps `actuator_mapping_available = false` because that
operation itself performs no mapping. A caller may pass a feasible receipt to
the separately versioned portable mapping operation below.

## EndpointForceJointMapRequestV2

Schemas:

- `sporespore_endpoint_force_joint_map_request_v2`; and
- `sporespore_endpoint_force_joint_map_receipt_v2`.

For every actuator in exact compiled order, the request supplies the semantic
support contact, joint anchor, directed unit joint axis, and endpoint position
in canonical world coordinates. The mapper verifies that the actuator's
compiled joint and the contact site belong to exactly the same declared limb,
then computes:

```text
r_i = endpoint_world - joint_anchor_world
J_i = joint_axis_world cross r_i
tau_i = dot(J_i, endpoint_task_force_command_world)
```

The result is a generalized torque command in N m about the declared positive
joint axis. It is portable virtual-work arithmetic—not a measured torque,
engine motor target, impulse, position, velocity, or physical action.

The mapping fails closed on an infeasible centroidal command; stale semantic
step; inconsistent upstream authority/nonclaim fields; missing, extra,
duplicate, or reordered identities; wrong-limb actuator/contact association;
nonunit axis outside `1e-9`; or nonfinite geometry, force, Jacobian, or torque.
The receipt always keeps measured torque, characterized actuator response,
adapter actuation, physics mutation, and physical acceptance false.

The mapping is exposed through the Rust API, stable C ABI, Python binding, and
Godot GDExtension. Its analytic Jacobian and torque are independently checked
by the shared GDScript golden oracle. Host-specific conversion from generalized
torque to Godot/Jolt, Rapier, or MuJoCo actuation remains outside this
operation.

## StabilityInfluenceRequestV2

Schema: `sporespore_stability_influence_request_v2`.

This contract bounds a later per-actuator stability contribution before it can
be combined with a base controller. It requires exact compiled actuator order
and freezes:

- maximum absolute position contribution;
- maximum absolute velocity contribution;
- maximum per-step position slew;
- maximum per-step velocity slew;
- prior semantic step and prior applied contribution; and
- one of `available`, `observation_unavailable`, or `upstream_infeasible`.

For `available`, every requested position and velocity contribution must be
finite. The limiter first clamps magnitude, then clamps change from the
previous applied contribution.

For unavailable or infeasible upstream state, requested numeric values must be
absent. The limiter immediately returns exact ordered zero contributions.
Fallback deliberately bypasses slew so stale corrective authority cannot
linger after observation loss or an infeasible allocation.

The receipt records every requested and applied value, magnitude saturation,
slew limiting, fallback, and the following nonclaims:

- corrections are bounded contributions, not complete actuation;
- no adapter actuation was applied;
- no physics state was modified; and
- no physical acceptance authority was granted.

## Current boundary and next gate

Godot/Jolt source commit
`c0b130ea24ca82a443b678a3ef7d362ded2d7199` now provides live ordered
body/contact emission into `StabilityStateV2` and compares the native observer
against the independent GDScript observer on every step of an already-opened
Candidate 35 evidence gait. The clean report is
`<evidence-root>\godot-jolt-stability-shadow-c0b130e\report.json`
(SHA-256
`4f48b8e7a4c46452ba5c67006bb8e13e43a0a6ba25eba09e30c421a42b7acf74`).
It records `1,514/1,514` available observations, zero mismatches, and no
stability actuation or authority.

The v2 implementation now provides the pure portable
endpoint-force/Jacobian-to-joint mapping described above. The clean source is
`f399edec4372701e374e0366d5d027d0e607863c`; its focused `15/15` Rust and
`23/23` independent GDScript receipt is retained at
`<evidence-root>\stability-v2-joint-map-f399ede\report.json`
(SHA-256
`2cf29aede42db40e233c54d486ad5ebda619cc01f02fc630c26ec327a67bec0a`).

Godot/Jolt source
`e85cc2fb8b500ced389d8ccc74671671b60cf190` now supplies the live
same-world mapping shadow. Its retained clean-source report is
`<evidence-root>\godot-jolt-joint-mapping-shadow-e85cc2f\report.json`
(SHA-256
`2aa5047762a0cbbb7562422682987eb2993da4f21f1540fe0637003bd7d77371`).
The `20/20` result records `821` available exact-order maps and `6,568`
independent actuator comparisons with zero mismatch; partial support and
centroidal infeasibility remain typed outcomes. The live request has zero
corrective gains and applies no actuator command.

Godot/Jolt implementation source
`c816ab36e4b696d8e8073fac88e6570242909609` then passed the preregistered
isolated motor-response characterization `16/16`. Its retained report is
`<evidence-root>\godot-jolt-motor-response-c816ab3\report.json`
(SHA-256
`aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729`).
Publication source
`3b54b3f975298c08f00aacb6d1423f7d2897ecd4` pins canonical-to-host sign
`-1`, the conservative coefficient
`0.24999998477941607 rad/s per N m`, uncertainty
`3.0654117577633144e-8`, and the exact
`0.2805286655276139 N m`/`0.075 rad/s` validity envelope in manifest v5.
The conversion is pure, fail-closed, and is not applied by the walker. Its
clean same-world shadow passed `20/20`; the retained report is
`<evidence-root>\godot-jolt-motor-profile-shadow-3b54b3f\report.json`
(SHA-256
`1aa0f5e20fea276373a8db0c6c22c137de506970057f375f6f70dd07c76d8a5b`).

The current implementation still does not provide:

- gains or influence limits authorized for a physical controller;
- a versioned partial-support mapping contract for three-contact stance;
- a fresh friction locomotion campaign;
- Rapier or MuJoCo stability shadow;
- cross-engine C6; or
- a balance, locomotion, or completed-SDK claim.

The exact legacy Godot/Jolt material pair now has isolated breakaway
characterization and supplies `controller_mu = 1.0`; this is host provenance,
not locomotion material robustness. The separate partial-support v3 mapper is
now implemented and evidenced at source
`8d1c5364d945102387b1763f3d0c17a1db86c059`; it extends rather than mutates
this document. The atomic v2 mapper remains unchanged: if a swing limb has no
endpoint force, the whole exact-order v2 map is typed unavailable. P5I.3B-R1
has passed its bounded contribution shadow; the next gate is separately
authorized P5I.3C opened-body influence. Actuator authority remains forbidden until correction
signs/gains, magnitude and slew limits, fallback, challenge cells, and receipt
paths pass their separate prospective tests.
The ordered commissioning contract is
[Godot/Jolt Stability-Influence Commissioning Bootstrap](SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md).
