# ADR-004: BR3A certification-backed knowledge admission

**Status:** Accepted

**Date:** 2026-07-23

**Deciders:** Cole and the LoColemotion maintainers

## Context

Cole authorized the pipeline to continue and delegated acceptance judgment,
provided that recommendations remain evidence-backed. The bounded milestone
decision `BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1` accepts the exact L1.0-L1.7
program scopes in certification `br3a_20260723T050201Z_109cc664`. It explicitly
admits no encyclopedia entry and authorizes no automatic creature guidance;
knowledge admission is a separate downstream operation.

The existing `sporespore.lab.knowledge_entry.v1` contract consumes BR1-style
run bundles. Those bundles contain a `summary.json` that carries hypothesis,
metric, and promotion state. BR3A deliberately uses a different evidence
family: each fresh-process capsule contains `capsule.json`, `metrics.json`,
`harness_report.json`, and a source inventory, while the two replicates are
reconciled by one detached, production-attested certification report. A BR3A
capsule does not contain `summary.json` and cannot truthfully pass through the
BR1 admission adapter.

The accepted BR3A decision also requires automatic guidance to remain disabled
until separately admitted knowledge and later accepted support milestones both
exist. The v1 query contract ordinarily marks repair rules from any accepted
entry as automatically applicable, so copying BR3A draft repair rules into v1
would cross that boundary prematurely.

## Decision

Create a separate
`sporespore.lab.br3a_knowledge_entry.v1` contract and admission path.

The contract will:

- leave `sporespore.lab.knowledge_entry.v1` and the existing L0 entry
  byte-compatible;
- bind every BR3A entry to the accepted milestone decision, exact certification
  report and receipt bytes, exact program IDs and claim scopes, and both
  production-attested capsule replicates for every cited program;
- distinguish accepted milestone observations from an accepted supplementary
  instrumentation constraint;
- admit no knowledge-guard or registry-integrity entry;
- make `minimal_repair_rules` structurally empty;
- pin `automatic_creature_guidance_allowed` and
  `automatic_application_allowed` to `false`; and
- require both a later accepted support milestone and a separate guidance
  decision before any consumer policy can change.

Nine entries are recommended:

1. one aggregate L1.0 contact-observer foundation entry;
2. one entry for each accepted L1.1-L1.7 cell; and
3. one L1.8 supplementary instrumentation-constraint entry.

L1.8 is not reclassified as a milestone cell. Its entry records only the
supplementary non-additivity and observation-cap constraints already named by
the report and decision.

The existing query dispatcher may verify and list these accepted observations,
but they produce no repair candidate because their repair-rule arrays are
empty. This preserves the distinction between accepted empirical truth and
permission to guide a creature.

## Options considered

### Option A: Treat BR3A capsules as BR1 run bundles

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Low |
| Provenance accuracy | Unacceptable |
| Compatibility | Superficially high |
| Auditability | Poor |

**Pros**

- Reuses the existing v1 CLI and schema.
- Requires little code.

**Cons**

- BR3A capsules have no `summary.json`.
- Inventing the missing summary semantics would misstate the evidence family.
- The v1 automatic-repair rule would prematurely authorize guidance.

### Option B: Add `summary.json` to the certified BR3A capsules

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Medium |
| Provenance accuracy | Unacceptable |
| Evidence immutability | Broken |
| Auditability | Poor |

**Pros**

- Could make the old bundle validator accept a familiar shape.

**Cons**

- Mutates detached, hash-indexed, already accepted evidence.
- Invalidates checksums, receipts, report reconciliation, and the decision.
- Turns an adapter problem into evidence tampering.

### Option C: Broaden knowledge-entry v1 into a union

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Medium |
| BR1 compatibility | Risky |
| Future flexibility | High |
| Trust-surface size | High |

**Pros**

- Keeps one schema name.
- Could support more evidence families later.

**Cons**

- Changes the validation surface used by the admitted L0 entry.
- Introduces many irrelevant optional fields.
- Conflates fundamentally different BR1 and BR3A provenance.

### Option D: Add a BR3A-specific knowledge contract

| Dimension | Assessment |
| --- | --- |
| Implementation effort | Medium-high |
| Provenance accuracy | Excellent |
| BR1 compatibility | Excellent |
| Guidance containment | Excellent |

**Pros**

- Matches the actual report-plus-replicates trust chain.
- Leaves accepted v1 knowledge semantics untouched.
- Makes automatic guidance structurally impossible at this stage.
- Preserves L1.8's supplementary classification.

**Cons**

- Adds a schema, verifier, admission manifest, and CLI.
- The query boundary must dispatch two versioned entry families.

## Trade-off analysis

Option D is the only option that preserves both evidence identity and the
accepted guidance boundary. The added code is justified because knowledge is a
long-lived consumer interface: a convenient but false adapter would be harder
to correct after controller code began depending on it.

The BR3A report's strongest verifier compares capsule source bytes with the
current checkout. Repository evolution after certification makes that check
historical by design. Knowledge verification therefore uses the append-only
decision as the accepted source-identity witness, rechecks the exact report and
receipt hashes named by that decision, and independently verifies every cited
capsule's generic production receipt and artifact checksums. It does not claim
that the current checkout is still certified commit `109cc664`.

## Consequences

What becomes easier:

- admitting exact BR3A observations without faking BR1 summaries;
- auditing which programs support each reusable claim;
- preserving a hard boundary between accepted truth and creature guidance;
- verifying that L1.8 remains supplementary.

What becomes harder:

- changing any admitted claim or evidence mapping in place;
- deleting the external certification evidence while retaining live query
  verification;
- enabling repair rules without a new schema/policy and explicit later
  decision.

What must be revisited:

- a common multi-family knowledge envelope only after another evidence family
  demonstrates genuinely shared fields;
- repair-rule authoring after an accepted support milestone;
- automatic guidance through its own explicit decision and adversarial tests.

## Action items

1. [x] Add the strict BR3A knowledge-entry and admission-manifest schemas.
2. [x] Add a report/decision/capsule-backed verifier and append-only writer.
3. [x] Add a fixed batch admission CLI with a dry-run mode.
4. [x] Re-author nine exact observation/constraint entries in one manifest.
5. [x] Add adversarial provenance, classification, and guidance tests.
6. [x] Commit the admission machinery before writing any entry.
7. [x] Run the clean admission operation and verify all installed entries.
8. [x] Keep automatic guidance disabled and BR4/L2 unclaimed.
