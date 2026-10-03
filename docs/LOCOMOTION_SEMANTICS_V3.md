# Locomotion Semantics v3 — Partial-Support Joint Mapping

- **Status:** P5I.3A, live P5I.3B-R1, and physical P5I.3C-R2 complete
- **Recorded:** 2026-07-28
- **Extends:** [Locomotion Semantics v2](LOCOMOTION_SEMANTICS_V2.md)
- **Commissioning gate:** [Godot/Jolt Stability-Influence Commissioning Bootstrap](SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md)

## Purpose

Version 2 deliberately made endpoint-force mapping atomic over the complete
compiled actuator order. That contract is retained unchanged. It is valuable
when every actuator's declared contact site has a feasible centroidal endpoint
command, but it is typed unavailable during ordinary three-contact stance
because the swing limb has no endpoint-force command.

Version 3 adds a separate partial-support operation. It does not omit the swing
limb, invent an endpoint force, reuse a stale force, or relax actuator order.
It returns one explicit command for every compiled actuator:

```text
active support contact:
  tau_i = dot(axis_i cross (endpoint_i - anchor_i), endpoint_force_i)

inactive contact:
  endpoint_force_i = exact zero
  tau_i = exact zero
```

The exact-zero inactive command is a current-step absence of stability
authority. It is not a measured zero torque, a contact measurement, or a
request to disable the base controller.

## Versioned schemas and operation

The portable request schema is:

```text
sporespore_endpoint_force_joint_map_request_v3
```

The portable receipt schema is:

```text
sporespore_endpoint_force_joint_map_receipt_v3
```

The C-ABI envelope schema is:

```text
sporespore_map_endpoint_force_to_joint_request_v3
```

The public operation is:

```c
ss_map_endpoint_force_to_joint_v3_json
```

The checked-in C header, Python binding, and Godot GDExtension must expose that
exact operation. The v2 operation and all v2 schemas remain available and
unchanged.

## Request

`EndpointForceJointMapRequestV3` contains:

- `schema_version`;
- one `semantic_step`;
- one already-computed feasible
  `sporespore_centroidal_support_command_v2`; and
- `ordered_actuator_kinematics` in exact compiled actuator order.

Each kinematics entry retains the v2 fields:

- `actuator_id`;
- the actuator's declared `contact_site_id`;
- `joint_anchor_world_m`;
- directed unit `joint_axis_world_unit`; and
- `endpoint_world_m`.

The centroidal command is the only endpoint-force source. Contact activity is
derived only from its ordered support-contact commands; the caller cannot pass
a second active-contact mask or hidden force.

## Per-actuator receipt

Every compiled actuator produces one
`GeneralizedJointTorqueCommandV3`, in exact compiled order, with:

- `actuator_id`;
- `contact_site_id`;
- `mapping_mode`, exactly one of:
  - `support_command`;
  - `inactive_contact_zero`;
- `active_support_contact`;
- `linear_jacobian_column_world_m`;
- `endpoint_task_force_command_world_n`;
- `generalized_torque_command_nm`;
- `inactive_contact_forced_zero`; and
- `command_not_measurement`.

For `support_command`:

- `active_support_contact = true`;
- `inactive_contact_forced_zero = false`;
- the endpoint force is copied from the same-ID centroidal contact command;
  and
- the Jacobian and generalized torque use the unchanged v2 virtual-work
  formula.

For `inactive_contact_zero`:

- `active_support_contact = false`;
- `inactive_contact_forced_zero = true`;
- endpoint force is exactly `(0, 0, 0) N`;
- generalized torque is exactly `0 N m`; and
- the current finite kinematics are still validated and the Jacobian is still
  emitted, so an inactive limb cannot hide invalid or reordered geometry.

## Aggregate receipt

`EndpointForceJointMapReceiptV3` contains:

- `schema_version`;
- `semantic_step`;
- `ordered_active_support_contact_ids`, copied exactly from the centroidal
  command order;
- `ordered_generalized_joint_torque_commands`;
- `active_actuator_count`;
- `inactive_actuator_count`;
- `endpoint_force_map_available = true`;
- `partial_support_mapping_available = true`;
- `inactive_contact_commands_forced_zero = true`;
- `measured_joint_torque_available = false`;
- `actuator_response_characterized = false`;
- `adapter_actuation_applied = false`;
- `physics_state_modified = false`; and
- `physical_acceptance_authority = false`.

`active_actuator_count + inactive_actuator_count` must equal the exact compiled
actuator count. A full-support request is valid and has zero inactive
actuators; a partial-support request must retain at least one inactive
actuator. The receipt does not claim that the adapter can realize a mapped
torque.

## Fail-closed rules

The v3 operation returns no receipt if any of the following occurs:

- request, centroidal-command, or semantic-step version/order mismatch;
- infeasible centroidal command;
- inconsistent centroidal nonclaims;
- empty, duplicate, invalid, or nonfinite centroidal contact command;
- an active contact ID is not a declared compiled contact site;
- an active contact ID is not associated with at least one compiled actuator;
- actuator count, order, or identity differs from the compiled morphology;
- an actuator or joint does not resolve to exactly one declared limb;
- the kinematics contact is not declared on that same limb;
- the same compiled contact site is declared by multiple limbs;
- axis, anchor, endpoint, force, Jacobian, or torque is nonfinite;
- a joint axis differs from unit length by more than `1e-9`;
- an inactive command is not exact zero; or
- any measurement, response, actuation, physics, or acceptance nonclaim is
  inconsistent.

No partially built command vector may escape on failure.

## P5I.3A frozen verification

Implementation must be committed and pushed before the first live
Godot/Jolt v3 mapping shadow is observed. The pure implementation must first
pass:

1. a full-support equivalence test against every numeric v2 command;
2. a three-contact test that maps six quadruped actuators and emits exact zero
   for the two swing-limb actuators;
3. active-force sign reversal and common-translation invariance while inactive
   commands remain exact zero;
4. order, identity, association, active-contact, version, infeasible-command,
   nonunit-axis, and nonfinite rejection tests;
5. real C-ABI and Python dynamic-library round trips; and
6. a `12/12` independent GDScript oracle suite that does not import Rust
   numeric results.

The dedicated retained report must pin:

- source commit and clean-worktree status;
- this semantics file, Rust source, C header, Python binding, Godot binding,
  test, runner, fixture, and Godot executable hashes;
- exact Rust, GDScript, native-boundary, and Python counts;
- full- and partial-support per-actuator receipts;
- exact inactive zero checks;
- every malformed-input failure code; and
- all response, actuation, physics, recovery, locomotion, robustness, and
  acceptance claims false.

Any miss rejects P5I.3A at that source. Threshold, schema, fixture, or
expected-count changes after observation require a new prospective amendment
and source identity.

## P5I.3A result

Implementation source
`8d1c5364d945102387b1763f3d0c17a1db86c059` adds the separate v3 Rust
operation, public C ABI, Python binding, Godot GDExtension method, independent
GDScript oracle, native boundary coverage, and dedicated retained-report
runner. The v2 operation, request, receipt, tests, and numeric output remain
available and unchanged.

The clean, pushed-source report is retained at
`<evidence-root>\stability-v3-subset-map-8d1c536\report.json`
(SHA-256
`0de2d43dda1698a1e716aae8f0fd693c0211c25f5cc617c5f7d2135510bcc8a9`).
Its adjacent transcript has SHA-256
`2e50bbc62da0375953159523aebb4370d1bb3e0654aad8485d0bf07d78c07286`.
The report records clean source equal to `origin/main` and passes:

- focused Rust `5/5`;
- independent GDScript `12/12`;
- native Godot boundary `27/27`; and
- Python real-DLL ABI `10/10`.

The retained partial-support receipt has eight exact-order outputs: six
`support_command` actuators and two front-right
`inactive_contact_zero` actuators. Both inactive endpoint forces and
generalized torques are exact zero. The full-support v3 result is numerically
equivalent to v2, active torques match the independent GDScript virtual-work
calculation, common translation is invariant, and an unknown active contact
fails with typed `REFERENCE_INVALID`. All response, actuation, physics,
recovery, locomotion, robustness, cross-engine, acceptance, and completed-SDK
claims remain false.

The exact live P5I.3B counts, profile conversion, influence bounds, independent
comparisons, report schema, and stopping rule are prospectively frozen in the
commissioning bootstrap. They do not alter the pure v3 contract.

The first live source was rejected because valid partial-support v3 torques
exceeded the previously characterized adapter profile input envelope. R1 keeps
those raw torques unchanged as v3 evidence and prospectively bounds only the
adapter-specific profile input. This does not alter the v3 map or its exact-zero
inactive-contact semantics.

Clean source `38ff4b3ee7ee548efaf2df7e76ba7e13d2ab9a86` subsequently passed
P5I.3B-R1 `28/28`. Its retained report is
`<evidence-root>\godot-jolt-stability-contribution-shadow-38ff4b3\report.json`
with SHA-256
`0fb641f3aa8bf4a7e2aa3c8da64a35355c88f348aef2216519bc69f076044826`.
The result proves the exact-order partial-support contribution can be observed,
profile-bounded, and independently reconstructed with no actuation. It does not
prove physical balance influence.

P5I.3C-R2 source
`df6c9e55e2e8eaf9433eba83f70d6031ca186592` subsequently passed the frozen
paired motor-only overlay gates at `24/24`. Its retained report is
`<evidence-root>\godot-jolt-stability-physical-influence-r2-df6c9e5\report.json`
(SHA-256
`d0971317d174f7bb5aef4cbea1f79c462182a0cd3e4ce59c83980ef6a7cb305b`).
That result permits a narrow physical-influence claim for the already-opened
Godot/Jolt reference quadruped. It does not alter this pure v3 mapping contract
or promote the v3 map itself into an engine realization, recovery, robustness,
fresh-morphology, or cross-engine result.

## Claim boundary

Passing P5I.3A permits only:

- a portable, exact-order, partial-support virtual-work map exists;
- active support limbs receive current feasible endpoint-force commands; and
- inactive-contact limbs receive explicit current-step zero stability
  commands.

It does not permit:

- a claim that any adapter realized the torque;
- a claim that balance feedback changed a motor or body;
- a claim of balance recovery or improved locomotion;
- a claim of friction, terrain, push, latency, or morphology robustness;
- cross-engine C6; or
- completed-SDK status.
