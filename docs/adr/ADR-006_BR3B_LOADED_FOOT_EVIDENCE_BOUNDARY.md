# ADR-006: BR3B loaded-foot evidence boundary

- **Status:** Accepted for implementation
- **Date:** 2026-07-23
- **Scope:** Promotion-grade evidence for BR3B L3.0-L3.2

## Context

BR3A established bounded engine/contact truth and BR4 established bounded
joint-actuator truth. BR3B must establish the simpler intermediate question:
whether one declared pad transmits centered normal load, reaches a loaded shear
breakaway, and exposes an edge-rocking transition before an articulated leg
depends on those mechanisms.

The research plan called L3.0 a pad on a vertical carriage. A literal mechanical
carriage would add a guide reaction. That reaction could prevent translation,
resist rotation, or supply an unmeasured moment, making the loaded-pad result
look stronger than the free contact actually is.

## Decision

The BR3B fixture uses a force-controlled carriage boundary:

1. one free `RigidBody3D` pad;
2. one declared world-frame force applied once per physics tick through
   `RigidBody3D.apply_force`;
3. a centered application point for L3.0 and L3.1;
4. a declared horizontal application offset for L3.2; and
5. no physical rail, pin, translation lock, rotation lock, damping, built-in
   motor, custom integrator, or balancing moment.

For L3.2, the only authored moment is `r × F`. The analytic static resultant is

```text
x_cop = F_external * x_application / (m * g + F_external)
```

Whole-system momentum reconstruction is the normal-load authority. Raw Jolt
predicted contact impulses and their impulse-weighted center of pressure remain
bounded diagnostic cross-checks. They are not generalized into a continuous
contact wrench or per-foot allocator.

BR3B receives its own campaign, capsule/metrics schemas, exact source
inventory, final report schema, and detached report-attestation domain. BR4 or
BR1 receipts cannot authenticate the BR3B report.

## Promotion claim

The promotable scope is limited to the exact L3.0-L3.2 source-pinned programs:

- centered normal-load transmission for the declared unary pad and load grid;
- loaded shear breakaway for the declared pad/material/load schedule, checked
  against accepted L1 friction truth; and
- predicted contact-pressure edge migration and the declared loaded rocking
  bracket, including its mirrored repeat.

## Explicit exclusions

Certification and acceptance cannot establish:

- a general contact wrench or continuous foot-force sensor;
- per-contact, per-foot, or per-toe load allocation;
- an articulated load-bearing limb, foot, or creature;
- standing, bracing, fall arrest, self-righting, or getting up;
- gait or walking;
- terrain robustness, complex-foot superiority, or endurance;
- accepted encyclopedia knowledge; or
- automatic creature guidance.

## Consequences

The force boundary cannot hide a guide reaction, but it is still a laboratory
load source rather than a creature body. BR3B can unlock construction of the
contact-bearing articulated-limb experiment; it cannot substitute for that
experiment.

Any later distributed or multi-shape foot must preserve L1.8's non-additivity
constraint: summing raw predicted impulses across same-body shapes is not a
valid foot-load measurement.
