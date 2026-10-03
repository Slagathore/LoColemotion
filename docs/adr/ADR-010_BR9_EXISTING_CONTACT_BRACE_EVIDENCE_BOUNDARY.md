# ADR-010: BR9 Existing-Contact Brace Evidence Boundary

- **Status:** Accepted for implementation
- **Date:** 2026-07-23
- **Decision owner:** Cole


## Context

BR8 can detect loss of viability but is observer-only. BR9 is the first rung
that executes an active brace. That makes an evidence-boundary error unusually
dangerous: a successful guided planar fixture could be mislabeled as general
bracing, a commanded left/right load split could be mislabeled as measured
per-foot load, or a contact-changing intervention could be hidden inside an
"existing-contact" result.

BR9 commissioning separates five concerns:

1. controller arithmetic and stable-dwell handoff;
2. fail-closed feasibility;
3. command mapping, finite actuation, execution, and receipts;
4. a paired physical no-brace/control comparison; and
5. adversarial claim and assistance containment.

## Decision

BR9 owns a promotion family distinct from BR7 and BR8:

- campaign:
  `sporespore.lab.br9_existing_contact_brace_promotion_campaign.v1`;
- metrics:
  `sporespore.lab.br9_existing_contact_brace_evidence_metrics.v1`;
- capsule:
  `sporespore.lab.br9_existing_contact_brace_evidence_capsule.v1`;
- final report:
  `sporespore.lab.br9_certification_report.v1`; and
- detached report receipt:
  `sporespore.lab.br9_certification_report_attestation.v1`.

The campaign fixes four milestone programs, BR9.0 through BR9.3, and one
integrity-only program, BR9.4. Every program runs twice in a fresh target
process. The complete campaign therefore requires:

- 5 programs;
- 10 production-attested capsules;
- 78 milestone assertions;
- 42 integrity assertions; and
- 120 assertions total.

No best-run selection is allowed. Both raw transcripts remain retained and
the final report must reconcile every declared program and replicate.

## Positive capability boundary

The family may certify only scaffold-constrained planar existing-contact
pitch arrest in the exact paired fixture.

The material conditions are:

- the unpowered Generic6DOF guide releases sagittal X/Y translation and pitch;
- out-of-plane translation, roll, and yaw remain locked;
- four hinges remain passive;
- two ordinary distal contacts are already bearing before the impulse;
- the active brace begins only on the first post-impulse observation;
- the no-brace control receives the same declared impulse;
- contact shares remain commands rather than measurements;
- actuation occurs only through finite paired joint torques;
- every applied operation reconciles through the command ledger and receipts;
  and
- aggregate external pitch moment is checked by whole-system momentum balance.

The physical acceptance requires the active world to reduce both
angular-momentum area and pitch excursion against the paired no-brace control
while retaining both original contacts and satisfying every rate, residual,
actuator, and handoff boundary.

## Explicit non-claims

BR9 cannot establish:

- a new-contact catch step;
- per-contact, per-foot, per-pad, or per-toe measured load allocation;
- a negligible or measured out-of-plane guide reaction;
- free-3D bracing, standing, or unconstrained balance;
- generality to another articulated limb or morphology;
- fall arrest;
- self-righting or getting up;
- gait or walking;
- creature repair;
- accepted encyclopedia knowledge; or
- automatic creature guidance.

BR9.4 can reject weakened evidence but cannot substitute for any physical
milestone program.

## Consequences

The clean certification operator may create and authenticate evidence, but it
has no milestone-acceptance or knowledge-admission switch. A complete clean
campaign remains a machine result until a separate append-only decision is
prepared and applied under Cole's authority.

Any later knowledge admission must be another append-only operation with
empty automatic repair rules and no guidance permission unless separately
authorized by a future consumer and guidance decision.
