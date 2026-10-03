# Locomotion Semantics v4 — Canonical Velocity Actuation

- **Status:** implemented zero-world semantic successor; host integration and
  physical characterization pending
- **Recorded:** 2026-07-31
- **Extends without rewriting:** [Locomotion Semantics v1](LOCOMOTION_SEMANTICS_V1.md),
  [v2](LOCOMOTION_SEMANTICS_V2.md), and
  [v3](LOCOMOTION_SEMANTICS_V3.md)
- **Source diagnosis:**
  [`../sdk/rapier_c6_bw19v_actuation_semantics_diagnostic.json`](../sdk/rapier_c6_bw19v_actuation_semantics_diagnostic.json)
- **Machine-readable profile:**
  [`../sdk/canonical_velocity_actuation_profile_v1.json`](../sdk/canonical_velocity_actuation_profile_v1.json)

## Purpose and boundary

The v1 actuation frame transports requested/clamped joint position and target
velocity, but it does not state whether both fields are independent native
servo terms. The retained Godot/Jolt realization used target velocity only.
The former Rapier selected-policy realization supplied both fields to a native
ForceBased position-plus-velocity motor. ASD1 established that the portable
velocity already contains complete position-error and measured-rate feedback,
contains the Godot host sign, and was combined with a canonical Rapier
stability residual before Rapier added a second position loop.

Version 4 adds a separate, versioned semantic profile. It does not rename or
mutate any v1-v3 schema or frozen output. Its load-bearing command is one
complete closed-loop **canonical target velocity**. Requested and clamped
position remain explicit provenance and bounds evidence; an adapter using this
profile may not apply them as an additional native position spring.

The current implementation is pure Rust and builds zero physics worlds. It
proves command-space meaning, ordering, legacy Godot command preservation, and
fail-closed validation. It does not yet change either live engine adapter,
extend the public C ABI, characterize a Rapier velocity servo, or authorize a
physical or release claim.

## Versioned identities

The canonical frame schema is:

```text
sporespore_canonical_velocity_actuation_frame_v1
```

The ordered stability-residual schema is:

```text
sporespore_canonical_velocity_residual_v1
```

The host-profile and mapping-receipt schemas are:

```text
sporespore_velocity_only_host_profile_v1
sporespore_velocity_only_host_mapping_receipt_v1
```

The semantic profile is:

```text
sporespore_complete_closed_loop_canonical_velocity_v1
```

The initial host-profile identities are:

```text
godot_jolt_velocity_only_equivalence_v1
rapier_force_based_velocity_only_v1
```

These identities are prospective semantic surfaces. They are not additions to
the public adapter-authoring contract or ABI until a later versioned boundary
explicitly promotes them.

## Canonicalization bridge

The frozen selected portable runtime still emits the retained Godot-oriented
v1 target. Version 4 deliberately wraps that immutable output rather than
flipping the predecessor constant in place:

```text
portable canonical velocity
    = legacy Godot host target velocity * -1
```

Every canonical command retains:

- exact actuator identity and compiled actuator order;
- source policy and actuation-receipt identity;
- requested and clamped position as provenance/bounds only;
- the original legacy host target velocity;
- portable canonical target velocity;
- separately labeled portable residual and safety contributions;
- the new canonical stability-residual contribution;
- unclamped and clamped combined canonical velocity;
- the inherited maximum target speed and validity horizon; and
- saturation, safe-frame, failure, world-count, and authority facts.

This bridge is a migration mechanism, not permission to keep host-specific
signs inside future portable controllers. A future native-v4 controller may
emit canonical velocity directly under a new explicit source identity.

## Canonical composition and one host conversion

For each actuator in exact compiled order:

```text
portable_canonical = legacy_host_velocity * -1
unbounded_canonical = portable_canonical + stability_canonical_delta
combined_canonical = clamp(unbounded_canonical, -maximum_speed, +maximum_speed)
host_velocity = combined_canonical * adapter_owned_sign
```

The stability residual is a command, not a measurement or physical-response
receipt. It must be finite, current, non-authoritative, and in the same exact
actuator order. Base and residual compose before one host conversion and one
final speed clamp. Applying host conversion to only one contribution, adding
the residual after conversion, or treating position as another load-bearing
servo term violates this profile.

## Position ownership

The only permitted v4 position role is:

```text
provenance_and_bounds_only
```

Each mapped host command therefore has:

```text
native_target_position_rad = null
independent_native_position_feedback_applied = false
native_position_stiffness = 0
```

This does not claim that position planning is irrelevant. The portable
controller uses position error to synthesize its complete closed-loop velocity,
and the frame retains the requested/clamped position so an audit can reproduce
that decision. It prevents the host from silently closing a second position
loop around the already-closed portable law.

## Host profiles

### Godot/Jolt equivalence target

The Godot/Jolt adapter-owned canonical-to-host velocity sign is `-1`. With
exact-zero new stability residual, canonicalization followed by host mapping
must reproduce every frozen legacy target-velocity bit and must emit no native
position target. The focused zero-world Rust test proves this for the real
BW15F-B controller frame at semantic step `0` without mutating the source
frame. `serde_json` float-roundtrip parsing is enabled so serialized receipts
also retain exact finite `f64` values.

This is command-equivalence evidence in the portable implementation. The live
Godot adapter has not yet been changed to consume the v4 frame, so this result
does not add new Godot physical evidence or supersede the existing captured
Godot/Jolt behavior.

### Rapier ForceBased velocity-only target

The Rapier adapter-owned canonical-to-host velocity sign is `+1`. The target
native profile is ForceBased velocity-only actuation with position stiffness
exactly `0`. The zero-world implementation proves that base and residual are
combined in canonical space before that `+1` mapping and emits no native
position target.

It does **not** establish a suitable Rapier damping coefficient, force limit,
impulse response, convergence window, solver precision, or physical
equivalence. Those remain the subject of a distinct, prospectively frozen host
characterization before the profile may be used for locomotion acceptance.

## Fail-closed rules

No canonical frame or host receipt may escape if any of these is true:

- schema, semantic-profile, source-convention, policy, or digest identity is
  invalid;
- command/residual count, actuator identity, or order differs from the
  compiled morphology;
- any command, contribution, sign, bound, or position is nonfinite;
- a stability residual is mislabeled as measurement or claims physical
  authority;
- a safe-no-actuation source receives a nonzero residual or yields nonzero
  authority;
- clamped position or combined velocity exceeds the declared bounds;
- the adapter-owned sign is not exactly `-1` or `+1`;
- a host profile applies native position feedback or nonzero position
  stiffness;
- the mapping emits a native position target, changes command order, reclamps
  an already canonical command, or changes its validity horizon; or
- any world build, physics mutation, host-response characterization, or
  physical-acceptance authority is inflated into this zero-world receipt.

Validation also reconstructs canonical, unbounded, clamped, saturation, and
host-mapped values from their declared inputs. JSON serialization/deserialization
must preserve the complete receipt exactly.

## Implemented zero-world verification

[`../sdk/core/src/canonical_actuation.rs`](../sdk/core/src/canonical_actuation.rs)
implements the typed frames, profiles, conversions, receipts, and validators.
Four focused Rust tests currently establish:

1. exact legacy Godot host-command equivalence for all eight ordered actuators,
   no source-frame mutation, no native position target, exact JSON round trip,
   and zero physical authority;
2. Rapier `+1` mapping only after canonical base-plus-residual composition,
   with the old mixed-space formula distinguished on all `5/5` nonzero legacy
   commands at the frozen semantic step;
3. rejection of reordered or nonfinite residuals, command/measurement
   confusion, non-unit host signs, duplicated native position feedback,
   nonzero stiffness, and world/authority inflation; and
4. rejection of nonzero residual authority in a safe-no-actuation frame.

The executable declaration audit is
[`../tests/test_actuation_semantics_v4.ps1`](../tests/test_actuation_semantics_v4.ps1).
It runs the focused Rust proof, validates the machine-readable declaration,
checks that the predecessor runtime sign remains unchanged, and exercises
independent declaration-level negative controls. The normal SDK conformance
pipeline invokes the audit.

## Claims and next gate

This boundary establishes an implemented and tested zero-world command-space
successor. It grants no live-adapter integration, actuator-response
characterization, physical C6, walking, cross-engine physical equivalence,
arbitrary-quadruped or continuous morphology coverage, robustness, release
authority, or completed-SDK authority. The existing release contract and
support matrix remain unchanged.

Before another Rapier world, a distinct prospective characterization must pin:

- the exact v4 profile and source identity;
- ForceBased builder and mutable-joint velocity-only readbacks;
- zero position stiffness and the selected damping/force configuration;
- signed position/velocity controls across multiple declared loads or lever
  arms;
- per-step force/impulse limits and host precision;
- a perfect synthetic full-gate acceptance witness;
- semantic, limit, order, sign, model, world-count, and claim-inflation
  canaries; and
- the rule that the first physical result is host characterization, not
  locomotion acceptance.

A successful characterization would still require a distinct paired
early-horizon mechanism screen and fresh selected-policy validation before any
Rapier locomotion or cross-engine claim.
