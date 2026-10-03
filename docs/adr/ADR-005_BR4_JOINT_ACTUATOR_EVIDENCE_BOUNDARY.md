# ADR-005: BR4 joint-actuator evidence boundary

**Status:** Accepted

**Date:** 2026-07-23

**Deciders:** Cole and the LoColemotion maintainers

**Milestone status:** the architecture was accepted here first; the exact
L2.0-L2.7 scientific scopes were later accepted separately by
`BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1`. This ADR itself still grants no
scientific claim, knowledge admission, or guidance permission.

## Context

Accepted BR3A evidence establishes bounded contact-engine observations but
does not establish an articulated limb, actuator, load-bearing joint,
controller, or recovery behavior. BR4 must establish joint and actuator truth
without silently borrowing:

- Godot's built-in hinge motor;
- a fixed root when the claim requires a free root;
- contact or gravity in an unloaded cell;
- a local or constraint impulse mislabeled as motor strength;
- direct body mutation outside the accepted command/executor seam;
- automatic guidance permission from experimental evidence.

The L2 ladder contains deliberately different fixtures: fixed scaffolds,
free-floating rotors, a gravity-loaded link, finite actuator envelopes, hard
limits, a two-joint chain, and observer-only anchor perturbations. Their
results need one common evidence architecture without pretending their claim
scopes are interchangeable.

## Decision

BR4 experiments use five separate layers:

```text
strict experiment contract
        |
        v
live LabJointState observation
        |
        v
pure controller/component resolution
        |
        v
LabJointActuator paired operation plan
        |
        v
BR1 CommandLedger -> ActuationExecutor -> detached per-call receipts
        |
        v
post-step fixture-specific analyzer and claim boundary
```

The following rules are architectural invariants:

1. `LabJointState` is the authoritative angle/rate/anchor/axis observer.
2. Controllers are pure resolvers. They cannot hold body references or mutate
   physics.
3. Active joint torque is decomposed into named components before actuator
   limits are applied.
4. Every active joint command plans equal-and-opposite parent/child world
   torques.
5. Physics mutation occurs only after the command ledger seals the payload.
6. Each planned operation produces a hash-linked execution receipt.
7. Fixed roots are explicit fixture scaffolds and cannot support a free-root
   claim.
8. Free-root evidence must retain whole-system momentum and center-of-mass
   accounting and must reject assistance operations.
9. Hard-limit reactions are constraint reactions, not active or passive
   strength.
10. Invalid anchor geometry makes dependent channels unavailable; it is never
    repaired or replaced by zero.
11. Experimental L2 results remain outside accepted knowledge and guidance
    until a separate BR4 promotion, certification, decision, and admission
    sequence completes.

## Options considered

### Use Godot's built-in hinge motor

Rejected. It would collapse requested torque, internal solver motor behavior,
capacity limits, and reaction classification into an engine-owned mechanism
that does not cross the project's command/receipt boundary.

### Apply controller torques directly to bodies

Rejected. Direct mutation would make the controller both decider and executor,
remove the immutable command identity, and make missed/doubled applications
difficult to distinguish from controller behavior.

### Use only fixed-base fixtures

Rejected. Fixed fixtures are valuable for passive period and gravity-hold
oracles, but they can hide a root reaction. L2.1, L2.2, L2.4, L2.5, and the
free L2.6 variant therefore retain free-floating momentum checks.

### Use only free-root fixtures

Rejected. The passive pendulum and horizontal gravity hold need a deliberately
known scaffold to isolate one-joint period and static load equations. The
scaffold is acceptable only when the result names it.

### Treat all solver impulses as actuator evidence

Rejected. L2.5 shows a large hard-limit impulse with zero active torque,
passive torque, and commands. Constraint reactions must remain a separate
classification.

### Promote each cell as soon as its focused test passes

Rejected. Focused commissioning is implementation evidence. BR4 acceptance
requires one complete clean source closure, replicated campaign,
certification report, detached receipt, reconciliation, and bounded decision.

## Consequences

Positive consequences:

- controller math, actuator capacity, command identity, executor behavior, and
  physics response can fail independently and visibly;
- fixed-root and free-root claims cannot be silently conflated;
- multi-joint commands retain exact parent/child reaction accounting;
- limit and anchor failures have machine-readable, non-strength signatures;
- future morphology-specific controllers can reuse the same low-level seam
  without inheriting experimental acceptance.

Costs and limitations:

- live experiments produce more records and receipts;
- fixture code must explicitly construct and observe body/joint frames;
- a fixed-scaffold result cannot be generalized to a free-root creature;
- L2 establishes joint-actuator truth only. It does not establish foot load,
  contact allocation, support, balance, bracing, recovery, or locomotion.

## Follow-up actions

1. Freeze the complete L2.0-L2.7 implementation checkpoint.
2. Define a BR4-specific campaign, capsule, report, receipt, and decision
   family without modifying BR1 or accepted BR3A contracts.
3. Execute the full declared campaign twice from one clean commit.
4. Reconcile all program roles and non-claims before recommending acceptance.
5. Keep knowledge admission observation-only if BR4 is accepted.
6. Keep automatic guidance disabled until later accepted contact-bearing and
   support milestones provide the missing causal bridge.
