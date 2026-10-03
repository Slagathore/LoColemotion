# ADR-009: BR8 early loss-of-viability detection evidence boundary

- **Status:** Accepted for implementation
- **Date:** 2026-07-23
- **Scope:** Promotion-grade evidence for BR8.0–BR8.4

## Context

BR7 established scaffold-constrained planar height/pitch stance and a
fail-closed response after support loss. BR8 asks a narrower prerequisite to
physical bracing: can the system recognize that the declared planar support
state is becoming nonviable early enough to distinguish an actionable warning
from a late observation?

That question is about sensing, timing, and supervision. Executing an
existing-contact brace is BR9. Creating a new catch contact is BR10. BR8 must
not manufacture either result.

The material out-of-plane guide remains present in the live fixtures. It makes
the detector experiment reproducible and prevents the result from being
called free 3D standing or balance.

## Decision

BR8 uses five ordered programs:

1. BR8.0 establishes static-margin, support-count, and impact-deadline
   oracles.
2. BR8.1 establishes the linear-capture margin, boundary clock, mirrored loss
   direction, actionable early warning, and delayed `REACTION_TOO_LATE`
   negative control.
3. BR8.2 establishes immediate escalation plus one-state-at-a-time release
   after a complete safe dwell.
4. BR8.3 runs the live passive central-impulse, slowly-tilting-platform, and
   disappearing-right-support matrix.
5. BR8.4 is integrity-only containment and cannot substitute for BR8.0–BR8.3.

The live matrix contains no active brace controller, step controller, foot
pin, root rescue, guide motor, or guide spring. Detector and supervisor output
is evidence only.

The unpowered `Generic6DOFJoint3D` guide:

- releases sagittal X/Y translation;
- releases pitch about Z;
- locks out-of-plane Z translation;
- locks roll and yaw; and
- enables no motor or spring.

## Promotion claim

The four milestone programs may establish only:

- exact classifications for the declared static/capture margins and timing
  thresholds;
- immediate escalation with bounded hysteretic release;
- the physical causal channel for the central-impulse warning;
- warning before measured static exhaustion in the slow-tilt fixture; and
- immediate observation of the declared support-set removal.

BR8.4 may prove only that hidden assistance, observer-to-controller
relabelling, contract mutation, wrong causal channels, late observations, and
broadened claims fail closed.

## Explicit exclusions

Certification and acceptance cannot establish:

- an executed existing-contact brace;
- a catch step or new support contact;
- free 3D standing or unconstrained balance;
- an absent, negligible, or measured out-of-plane scaffold reaction;
- fall arrest;
- self-righting or getting up;
- gait or walking;
- morphology, terrain, complex-foot, or endurance generalization;
- accepted encyclopedia knowledge; or
- automatic creature guidance.

## Consequences

BR8 can advance the bounded evidence ladder only after a complete clean
campaign and a separate evidence-bound decision. Observation knowledge, if
later admitted, must remain separate from guidance and preserve the material
scaffold and observer-only boundary.

BR9 is the first rung that may test an actual existing-contact brace. It must
consume BR8 evidence without allowing detector output to bypass the normal
command, feasibility, ledger, executor, and receipt path.
