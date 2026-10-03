# ADR-016: Portable stability before multi-engine locomotion

- **Status:** accepted and implemented through BW2 successor selection;
  material, disturbance, and cross-engine C6 gates remain open
- **Date:** 2026-07-28
- **Decision scope:** successor ordering and semantic prerequisites; no new
  physical claim

## Context

The Rust core and Godot/Jolt adapter now pass their declared C0-C5
capabilities, physical shadow, bounded authority handoff, and full native
authority commissioning. Formal C6 rejected at selection. Its one
prospectively constrained C6R successor passed selection and rejected on cold
held-out R1 despite zero native command mismatches or authority failures.

At decision time, the live-code
[post-C6 audit](../SDK_POST_C6_AUDIT_2026-07-28.md) established this snapshot:

- the generated walker and SDK have never varied locomotion friction;
- the Rust controller has no support-margin, centroidal, roll/pitch, or balance
  feedback;
- the repository has only the Godot adapter; and
- Candidate 35 is a high-capacity, failure-shaped legacy policy whose finite
  successes do not establish continuous morphology coverage.

The existing GDScript mechanics laboratory contains useful support-margin,
dynamic-support, and centroidal-allocation primitives, but they are not
connected to the generated walker or Rust runtime.

Subsequent implementation closed the literal capability gaps in that
snapshot. The portable Rust core now contains the support/stability mechanics;
Godot/Jolt emits the required observations and applies bounded physical
influence; Rapier/Parry and MuJoCo join Godot/Jolt as declared C0-C5 hosts;
and branch-free BW2-C is selected while Candidate 35 remains sealed. These
changes do not establish balance recovery, material robustness, second- or
third-engine locomotion, or cross-engine C6.

## Decision

### 1. Seal Candidate 35 as a legacy oracle

Candidate 35 remains supported for:

- exact pure-controller golden vectors;
- C ABI regression;
- Godot/Jolt C0-C5 regression;
- replay of the retained C6/C6R negative results; and
- comparison against a successor.

No new morphology branch, threshold, gain ramp, heldout repair, or claim may
be added to Candidate 35. A new controller receives a new policy, runtime,
memory, ABI capability, and campaign identity.

### 2. Add Locomotion Semantics v2 before a new physical controller

The next semantic version must provide the portable core enough declared
state to calculate stability rather than infer it from a host:

- ordered body poses and twists for whole-system COM and momentum
  reconstruction;
- contact point, normal, relative velocity, presence/bearing quality, material
  identity, and provenance;
- gravity-plane support-hull construction independent of semantic token order;
- signed static and velocity-aware dynamic support margins;
- base roll/pitch and angular-rate feedback;
- bounded stability corrections with explicit feasibility, saturation, slew,
  fallback, and receipts; and
- a portable output contract that never asks the adapter to invent controller
  policy.

Missing body/contact observations remain unavailable, never measured zero.
Raw contact impulses remain non-additive unless a separately certified
aggregation contract exists.

### 3. Port mechanics before tuning locomotion

Rust golden vectors must first match the pure GDScript behavior of:

- `spatial_support_margin_observer.gd`;
- `spatial_dynamic_support_observer.gd`; and
- `spatial_centroidal_support_controller.gd`.

The port must preserve their nonclaims. A command is not a load measurement.
An analytic feasibility pass is not proof that a host actuator realizes the
command. Physical integration begins only after the pure port, exact boundary
tests, and adapter capabilities are frozen.

### 4. Use friction as the first fresh nuisance axis

The next physical successor is not allowed to begin by adding another
morphology branch. It must first expose material behavior through a canonical
request and an adapter-specific characterization receipt.

Equivalent authored friction numbers are not assumed to mean equivalent
breakaway or steady sliding across engines. Each adapter must characterize the
realized effective behavior on isolated fixtures. The locomotion campaign then
freezes a physical interval or discrete strata in those characterized units
before opening its fresh bodies.

### 5. Implement engines in this order

1. **Rapier/Parry** is the second host. It is a Rust workspace adapter using
   `rapier3d` and the existing portable core.
2. **MuJoCo** is the third host. It uses the same checked-in C ABI from a
   project-local Python 3.11 environment installed from the official
   `mujoco` wheel.
3. Godot/Jolt remains the first host and independent GDScript oracle.

Rapier and MuJoCo independently clear C0-C5. Neither may enter locomotion
because the other passed, and installing a dependency is not conformance.

Implementation status as of source
`61937f46c37c831a6e2a9d5c7da781929bc6382f`: Rapier `0.34.0` with Parry `0.29.0`
now clears its currently declared C0-C5 slice at source
`4ce6a47c6410cc7977d49b807b6af280fc0e6b83`. The retained report is
`<evidence-root>\rapier-c2-c5-4ce6a47\report.json`
(SHA-256
`35982b3e29ade9ffb98c877b304316aea6718d0fe0a4a60062b2e47754b93057`).
C6, normal-load semantics, breakaway/steady-slide characterization, and
physical acceptance remain explicitly false.

MuJoCo `3.11.0` now clears its currently declared C0-C5 slice at source
`4578a568844554965efdf4598fbb9c4e7b8f0389`. The project-local Python 3.11
adapter loads the same release Rust C ABI used by the standalone Python smoke
suite. Its retained report is
`<evidence-root>\mujoco-c0-c5-4578a56\report.json`
(SHA-256
`ca8d74cd056a735208977f05d96cfd1c08dc13bd7279682af7c8f73ce02bf03d`).
The report preserves MuJoCo's explicit-Euler, Z-up, force-servo, contact-force,
and friction-vector provenance. C6, raw contact impulse, persistent semantic
contact identity, breakaway/steady-slide characterization, restitution
coefficient, controller-policy authority, and physical acceptance remain
false.

Implementation sources:

- [Rapier Rust user guide](https://rapier.rs/docs/user_guides/rust/getting_started)
- [Rapier 0.34.0 API](https://docs.rs/rapier3d/0.34.0/rapier3d/)
- [Parry 0.29.0 API](https://docs.rs/parry3d/0.29.0/parry3d/)
- [Official MuJoCo Python bindings](https://mujoco.readthedocs.io/en/stable/python.html)

### 6. Run cross-engine C6 only on the stability successor

No second-engine C6 campaign will attempt to rescue Candidate 35. After the
portable stability successor passes a fresh Godot/Jolt baseline and material
campaign, cross-engine C6 freezes:

- the exact same core build and policy identity;
- per-adapter capability and characterization receipts;
- shared semantic input/output assertions;
- strict no-cheat, structure, contact-progression, and safety booleans; and
- engine-appropriate behavioral envelopes fixed before the first complete
  run.

Cross-engine success does not require bit-identical trajectories, contact
manifolds, or raw impulses.

### 7. Separate finite coverage from continuous proof

The SDK may claim total **static compilation** over a closed descriptor box
when exhaustive schema/boundary/property checks justify it.

A finite physical sample may claim only its declared coverage resolution. A
continuous full-volume physical claim additionally requires a cell-wise
certificate: every point belongs to a certified cell whose measured stability
and structural margins exceed a prospectively bounded local variation
envelope. Cells without such a bound remain unproven and are subdivided or
classified out of coverage.

Counterexamples remain in an immutable ledger. They may motivate a new
candidate, but may not be patched under the campaign that discovered them.

## Consequences

### Benefits

- The next controller attacks the physical sensitivity exposed by C6R rather
  than fitting its two failed IDs.
- Support and balance semantics become portable before adapters multiply.
- Friction becomes an independent challenge axis rather than another
  morphology-conditioned branch input.
- Rapier exposes Rust-host assumptions cheaply; MuJoCo then provides a
  materially different contact/actuator model.
- Continuous-domain language receives a falsifiable certificate requirement.

### Costs

- State and contact schemas require a versioned expansion.
- Godot/Jolt must expose ordered body state and qualified contact geometry to
  the new core.
- Centroidal/task-space commands require host actuator characterization and
  may expose capabilities some adapters cannot support.
- The path to a passing cross-engine C6 is longer than copying Candidate 35
  into a second simulator.

### Explicit nonclaims

This ADR and its implementation do not establish:

- a passing balance controller;
- friction-robust locomotion;
- Rapier or MuJoCo locomotion or C6 acceptance;
- continuous physical morphology coverage;
- arbitrary quadruped locomotion;
- multi-leg, running, bipedal, or rough-terrain capability; or
- a completed engine-neutral SDK.

Those remain implementation and evidence gates in the
[Engine-Neutral Locomotion SDK Bootstrap](../ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).

The first concrete non-Candidate-35 successor is governed by
[ADR-017](ADR-017_PORTABLE_BALANCED_WAVE_SUCCESSOR.md). Its branch-free
profile, separate policy/runtime/memory identity, and development/validation/
cold evidence split were frozen only after the retained P5M.3-R1 material
campaign rejected.
