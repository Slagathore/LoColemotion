# ADR-003: BR3A milestone-decision contract

**Status:** Accepted

**Date:** 2026-07-23

**Deciders:** Cole and the LoColemotion maintainers

## Context

The promotion-grade BR3A campaign
`br3a_20260723T050201Z_109cc664` passed and its detached production report
receipt independently re-verified. The report is eligible to support a human
decision, but it contains no decision and cannot admit knowledge or authorize
creature guidance.

The existing `sporespore.lab.milestone_decision.v1` schema is intentionally
BR1-shaped. Its evidence basis requires a BR1 certification ID, BR1 report and
receipt schemas, test-artifact counts, replay counts, and replicate-comparison
counts. It is byte-pinned by the already accepted BR2.1 decision. Broadening
that schema into a union would change the accepted BR2.1 trust surface.

The earlier `BR3A_L1_commissioning_status_v1.json` is also an immutable
historical snapshot. It correctly records the five blockers that existed
before the promotion family and campaign were built. Rewriting it after the
fact would erase the distinction between commissioning and certification.

Cole first instructed the implementation to continue, then supplied an
explicit bounded acceptance naming certification
`br3a_20260723T050201Z_109cc664`, the exact report and receipt hashes, the
L1.0-L1.7 scope, L1.8's supplementary role, and every required knowledge,
guidance, allocation, articulation, support, recovery, gait, and walking
exclusion. The reviewed context is
`docs/BR3A_L1_MILESTONE_DECISION_REVIEW.md` at commit
`aeaa883198dc08e0fcdf85078312cd40db9d6655`.

## Decision

Create a separate, strict
`sporespore.lab.br3a_milestone_decision.v1` contract for the first BR3A
decision.

The decision must bind:

- Cole's explicit bounded acceptance and the reviewed Option A context;
- the exact review document bytes and Git commit that supplied the context;
- the exact certification, campaign, report, receipt, source inventory, engine,
  and BR1 inventory identities;
- all milestone, supplementary, and integrity accounting;
- the exact accepted L1.0-L1.7 contracts and fixture-bounded capabilities;
- L1.8 and the knowledge guard only as supplementary constraints;
- every report exclusion and still-open downstream milestone; and
- zero knowledge admission and zero automatic-guidance side effects.

The existing milestone registry becomes a multi-contract allowlist. It keeps
the BR2.1 v1 schema and decision pins byte-identical, dispatches BR3A candidates
to the new semantic contract, and exposes both accepted milestone IDs.

The commissioning status file is not edited. Its registry exposes both:

1. the byte-pinned historical snapshot and its five then-open blockers; and
2. the current formal state derived from the append-only decision registry.

The read-only status CLI renders that distinction explicitly.

## Options considered

### Option A: Broaden `milestone_decision.v1`

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Low |
| BR2.1 compatibility | Poor |
| Evidence-family precision | Medium |
| Auditability | Medium |

**Pros**

- One schema path and one validator.
- Minimal new code.

**Cons**

- Changes the schema hash trusted by an already accepted BR2.1 record.
- Invites a loose BR1/BR3A union with many irrelevant optional fields.
- Makes it harder to prove that BR2.1 semantics did not drift.

### Option B: Create a generic milestone-decision v2 union

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Medium-high |
| BR2.1 compatibility | Good |
| Evidence-family precision | Medium-high |
| Future flexibility | High |

**Pros**

- Could dispatch many future report families through one discriminator.
- Leaves v1 untouched.

**Cons**

- Designs abstractions for evidence families that do not yet exist.
- A growing union becomes another broad trust surface.
- BR3A still needs exact family-specific semantic checks outside the schema.

### Option C: Add a BR3A-specific decision contract

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Medium |
| BR2.1 compatibility | Excellent |
| Evidence-family precision | Excellent |
| Future flexibility | Bounded but sufficient |

**Pros**

- Leaves every accepted BR2.1 byte and semantic check unchanged.
- Uses names and accounting that match the actual BR3A report.
- Can make knowledge and guidance side effects structurally false.
- Keeps the registry as the small common append-only boundary.

**Cons**

- Adds one schema and one semantic contract.
- A later evidence family may require another versioned contract.

## Trade-off analysis

Option C is intentionally less abstract. The decision boundary is
security-sensitive and low-volume; exactness is more valuable than reducing
the number of schemas. The common registry still provides one lookup surface,
while each evidence family owns only the fields it can actually prove.

The main historical-verification trade-off is explicit. The BR3A report
attester's strongest mode rebuilds the live source closure, so normal repository
evolution after the decision will no longer make the current checkout identical
to certified commit `109cc664`. The append-only decision therefore stores the
exact report/receipt/source identities and the fact that production attestation
was re-verified immediately before the source evolved. It does not falsely
claim that future source bytes remain identical to the certified source.

## Consequences

What becomes easier:

- auditing exactly what Cole accepted and which conversation context he
  answered;
- proving that BR3A acceptance did not modify BR2.1;
- reconciling an immutable commissioning snapshot with current formal state;
- blocking accidental knowledge admission or guidance authorization;
- moving to BR4/L2 without calling BR3A locomotion.

What becomes harder:

- altering an accepted BR3A decision in place;
- presenting a current checkout as the old certified source;
- broadening the milestone without a superseding decision and new evidence.

What must be revisited:

- a generic decision envelope only if several future evidence families develop
  genuinely identical fields;
- frame-level trace promotion before a dynamic controller treats a BR3A result
  as an invariant;
- per-foot load allocation before any foot/toe consumer exists;
- separate knowledge admission after the decision, never as a decision side
  effect.

## Action items

1. [x] Add the strict BR3A decision schema and semantic validator.
2. [x] Add the append-only decision file and exact registry pins.
3. [x] Reconcile the historical commissioning registry and CLI.
4. [x] Add adversarial decision, authorization, evidence, exclusion, knowledge,
   and registry tests.
5. [x] Run targeted and complete released/experimental regressions.
6. [x] Update ladder accounting to 4/18 while retaining every locomotion zero.
7. [x] Keep knowledge admission and automatic guidance as separate later work.
