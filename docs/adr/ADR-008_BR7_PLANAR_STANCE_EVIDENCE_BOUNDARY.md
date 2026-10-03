# ADR-008: BR7 planar-stance evidence boundary

- **Status:** Accepted for implementation
- **Date:** 2026-07-23
- **Scope:** Promotion-grade evidence for BR7.0–BR7.4

## Context

BR6A established articulated vertical support on a carriage that locked every
root degree of freedom except vertical translation. BR7 asks the next causal
question: can ordinary contacts and finite joint actuators regulate height and
pitch after releasing sagittal root translation and pitch?

The remaining out-of-plane guide makes that question experimentally bounded.
It also prevents the result from being called free 3D standing. The evidence
family must retain both facts.

## Decision

BR7 uses five ordered programs:

1. BR7.0 solves exact two-contact vertical-force and pitch-moment allocation.
2. BR7.1 applies unilateral and Coulomb-friction feasibility.
3. BR7.2 computes static/capture support segments and one fail-closed
   support-loss transition.
4. BR7.3 runs the live two-leg planar fixture, the declared positive pitch
   impulse, and the declared right-support removal.
5. BR7.4 is integrity-only containment and cannot substitute for BR7.0–BR7.3.

The live fixture contains one root, four articulated links, four passive
hinges, four finite paired joint actuators, and two ordinary distal contacts.
It forbids built-in motors, joint limits, passive tissues, foot pins, and
controller-applied root rescue.

The unpowered `Generic6DOFJoint3D` guide:

- releases sagittal X/Y translation;
- releases pitch about Z;
- locks out-of-plane Z translation;
- locks roll and yaw; and
- enables no motor or spring.

Whole-system linear momentum is the aggregate vertical-support authority.
Whole-system angular momentum is the aggregate external pitch-wrench
authority. Neither measurement allocates load to an individual foot.
Allocator command shares remain commands, not sensors.

## Promotion claim

The four milestone programs may establish only:

- exact feasible two-contact planar allocation and exact rejection of
  infeasible unilateral or friction requests;
- the declared static/capture support-segment arithmetic;
- one reasoned fail-closed transition after declared support loss; and
- scaffold-constrained planar height/pitch stance, recovery from the declared
  positive pitch impulse, and response to the declared support removal in the
  exact live fixture.

BR7.4 may prove only that hidden assistance, false measurement, contract
mutation, missing support-loss evidence, and broadened claims fail closed.

## Explicit exclusions

Certification and acceptance cannot establish:

- measured per-contact, per-foot, or per-toe load allocation;
- free 3D standing or unconstrained balance;
- an absent, negligible, or measured out-of-plane scaffold reaction;
- bracing or fall arrest;
- self-righting or getting up;
- gait or walking;
- morphology, terrain, complex-foot, or endurance generalization;
- accepted encyclopedia knowledge; or
- automatic creature guidance.

## Consequences

BR7 can advance the bounded evidence ladder only after a complete clean
campaign and a separate evidence-bound decision. Observation knowledge, if
later admitted, must remain separate from guidance and must preserve the
scaffold and aggregate-only measurement limitations.

The next 3D experiment must release and control the remaining root degrees of
freedom without silently treating the guide as irrelevant. A future per-foot
controller also requires a separately validated measurement contract; BR7's
allocator does not supply one.
