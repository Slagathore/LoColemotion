# ADR-007: BR6A rail-leg evidence boundary

- **Status:** Accepted for implementation
- **Date:** 2026-07-23
- **Scope:** Promotion-grade evidence for BR6A L4.0, L4.1, and L4.3

## Context

BR3A established bounded engine/contact truth, BR4 established bounded
joint-actuator truth, and BR3B established bounded loaded-pad truth. BR6A asks
the next causal question: can an articulated limb carry aggregate weight,
crouch, rise, and reject a vertical disturbance when balance is deliberately
removed?

A vertical rail is useful because it removes lateral balance from the first
support experiment. It is also a material scaffold. Hiding or minimizing that
fact would turn a valid constrained-support result into a false standing
claim.

## Decision

BR6A uses three source-pinned fixtures:

1. L4.0: one rigid strut on an explicit vertical rail, paired with a no-floor
   freefall control;
2. L4.1: one hinged strut with an ordinary frictionless distal contact,
   analytic feedforward torque, separately tagged joint stabilization, and a
   zero-torque negative control; and
3. L4.3: a two-link leg on the same class of vertical carriage, with a strict
   body wrench, V1 vertical load allocator, exact force-to-joint map, finite
   paired actuators, crouch/rise schedule, and one declared downward impulse.

The rail is a `Generic6DOFJoint3D` with:

- vertical translation unlocked;
- X/Z translation locked;
- all rotation locked; and
- every rail motor and spring disabled.

Its reaction is observed and reported. It is never called negligible or
equated with free-root support.

The foot is one ordinary distal sphere. It is neither pinned nor teleported.
Built-in hinge motors, joint limits, passive tissues, and controller-applied
root rescue are forbidden. Whole-system momentum reconstruction is the
aggregate external-load authority and does not allocate load among contacts or
future feet.

## Promotion claim

The promotable scope is limited to:

- L4.0 freefall honesty and rigid floor-supported load under the exact rail
  fixture;
- L4.1 the exact static holding-torque curve at `0°`, `15°`, `30°`, and `45°`
  plus the matched zero-torque control; and
- L4.3 aggregate static support, bounded crouch/rise with measured actuator
  work and potential-energy gain, recovery from the declared downward
  carriage impulse, visible rail reaction, unreachable-height refusal, and
  insufficient-actuator refusal.

This is articulated, contact-bearing, rail-constrained vertical support. That
positive capability may be represented in the BR6A report; broader capability
may not.

## Explicit exclusions

Certification and acceptance cannot establish:

- general per-contact, per-foot, or per-toe load allocation;
- free-root standing or balance;
- rail-independent support or negligible scaffold reaction;
- bracing or fall arrest;
- self-righting or getting up;
- gait or walking;
- morphology, terrain, complex-foot, or endurance generalization;
- accepted encyclopedia knowledge; or
- automatic creature guidance.

## Consequences

BR6A can unlock the next planar multi-contact stance experiments after clean
certification and explicit acceptance. It cannot authorize a creature
controller, standing label, or walking research by itself.

Any later multi-foot system must add a real allocation method; aggregate
momentum reconstruction cannot identify which foot carried which share.
