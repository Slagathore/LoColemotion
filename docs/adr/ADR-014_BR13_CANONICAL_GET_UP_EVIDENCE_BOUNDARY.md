# ADR-014: BR13 Constrained Canonical Get-Up Evidence Boundary

- **Status:** Adopted
- **Date:** 2026-07-23
- **Decision owners:** SporeSpore mechanics laboratory

## Context

BR12 can classify exact canonical poses and reject statically infeasible
recovery plans, but it contains no dynamic body rise, controller handoff, or
physical self-righting evidence. BR13 must cross that boundary without
quietly claiming free-3D recovery or walking.

The easiest defensible physical reference is one fixed, symmetry-collapsed
quadruped in a sagittal laboratory scaffold. Each front or rear rigid strut
represents a mirrored limb pair. A material guide locks out-of-plane
translation, roll, and yaw while leaving sagittal translation and root pitch
free. This choice deliberately postpones independent four-limb control and
free-3D balance.

## Decision

BR13 uses an isolated promotion and certification family whose maximum
positive claim is:

```text
constrained_planar_get_up
```

The milestone evidence consists of:

- BR13.0 exact profile, semantic prone/transition/stance observation, and
  successful phase order;
- BR13.2 static work/reserve preflight and explicit energy/guide accounting;
  and
- BR13.4 digest-bound, three-seed paired live Godot/Jolt recovery.

BR13.1 timeout/revocation behavior and BR13.3 adversarial containment are
integrity evidence. They are required campaign members but cannot substitute
for a physical milestone program.

Every BR13.4 active seed must:

- begin in observed semantic ventral-contact prone;
- use ordinary unilateral floor contacts;
- use finite digest-bound paired hinge torque through the command ledger,
  executor, and execution-receipt path;
- establish front-pair and rear-pair distal support;
- raise measured whole-system center of mass by at least `0.35 m`;
- close transition-integrated actuator and mechanical-energy accounting;
- keep residual-inferred guide impulse/work and out-of-plane motion inside
  the declared bounds;
- hand exclusively from recovery control to stance control; and
- complete the declared stable stance dwell.

Each seed has one same-state zero-command control that must remain prone with
zero commands and zero actuator work.

## Trust topology

The campaign requires:

- clean committed source;
- an exact sorted inventory of every declared source byte;
- two fresh target-process replicas for each of five programs;
- all ten runs retained without cherry-picking;
- one production-attested evidence capsule per run;
- ordered assertion-label and raw-transcript reconciliation;
- complete independent final readback;
- one BR13 certification report; and
- one detached HMAC receipt in a BR13-specific report domain.

The bundle publication receipt and the final report receipt remain distinct
domains. Test-root receipts cannot promote. Certification cannot create a
milestone decision or knowledge entry.

## Energy instrumentation

Actuator work is integrated across each physics transition using the average
of the before/after relative joint rates under the applied torque. A
pre-transition-only rate materially undercounts work performed during rapid
joint acceleration. The campaign rejects an unclosed ledger; it does not
weaken the energy gate to accommodate instrumentation loss.

Contact dissipation and guide work remain explicitly residual-inferred.
Passing this boundary does not create a generalized per-contact force sensor.

## Explicit exclusions

The BR13 report schema makes the following unrepresentable as positive
results:

- free-3D, unscaffolded, or morphology-generalized recovery;
- independent left/right control of four articulated limbs;
- an absent, negligible, or generally measured scaffold reaction;
- morphology, actuator, terrain, foot, endurance, or physics-setting
  transfer;
- per-contact, per-body, per-foot, per-toe, or center-of-pressure load
  allocation;
- general standing, balance, bracing, fall arrest, or recovery outside the
  exact terminal dwell;
- a step, weight-transfer maneuver, gait, candidate walking, or walking; and
- creature repair, accepted knowledge, or automatic creature guidance.

## Consequences

A passing certification can support a bounded BR13 milestone decision. It
does not itself accept the milestone.

After bounded acceptance, the next capability step is not automatically
walking. Free-3D canonical recovery and morphology expansion still require
their own evidence. Locomotion later requires explicit load transfer,
unloading and advancing a support, touchdown, and repeated stable steps.
