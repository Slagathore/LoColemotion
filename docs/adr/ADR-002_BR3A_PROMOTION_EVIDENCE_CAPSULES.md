# ADR-002: BR3A promotion evidence capsules

**Status:** Proposed

**Date:** 2026-07-22

**Deciders:** Cole and the LoColemotion maintainers

**Implementation result:** complete at certified source `109cc664`; campaign
`br3a_20260723T050201Z_109cc664` and its detached report receipt pass.
Architectural and milestone acceptance remain pending Cole's review in
`docs/BR3A_L1_MILESTONE_DECISION_REVIEW.md`.

## Context

BR3A L1.0-L1.7 has complete commissioning coverage, and L1.8 adds a
supplementary contact-discretization result. The existing programs are real
Godot/Jolt experiments, but they are test programs rather than BR1 trace-run
specifications. Their current reports prove that assertions passed and retain
the engine and transcript logs; they do not by themselves provide a sealed
source inventory, immutable per-run metrics capsule, checksums bundle,
production receipt, complete replicated campaign, certification report, or
milestone decision.

The promotion stream must preserve two boundaries:

1. BR1 report-v2 and its pinned 62-test inventory remain unchanged.
2. BR3A may certify only the named contact-engine observations. It cannot
   promote standing, bracing, recovery, walking, articulated load bearing, or
   per-foot allocation of reconstructed load.

L1.8 adds an instrumentation constraint: raw predicted impulses from multiple
same-body shape-pair manifolds are not additive external-support load. A future
per-foot contract must use a validated system momentum balance or another
independently established allocation method.

## Decision

Create a BR3A-specific evidence-capsule and certification family around the
existing source-pinned test programs.

Each program replicate runs in a fresh Godot OS process and produces one
capsule containing:

- the exact harness report, engine log, and transcript;
- a strict metrics record containing every ordered assertion label and all
  non-assertion observation lines;
- the target and containment-host process identities;
- the clean Git commit and an exact byte inventory of the complete declared
  source closure;
- a strict BR3A capsule manifest plus the generic lab manifest;
- SHA-256 checksums covering every capsule artifact; and
- the existing generic production publication receipt stored outside the
  evidence directory.

On Windows the campaign launches the full Godot runtime executable directly,
not the small `*_console.exe` launcher. This keeps the contained target PID,
the live `OS.get_executable_path()` witness, and the pinned executable digest
bound to the same process that executes physics.

The campaign runs every declared program twice. Reconciliation requires exact
agreement in source identity, expected assertion count, ordered assertion
labels, and pass/fail classification. Raw transcripts remain sealed even when
floating observations or wall-clock diagnostics differ; those differences are
reported rather than erased or cherry-picked.

The final report receives a new detached domain-separated HMAC receipt:

`sporespore.lab.br3a_certification_report_attestation.v1`

The report attester independently re-reads all capsule indexes, checksums,
production receipts, metrics, source inventories, and process identities
before signing the exact final report bytes. The report contains no acceptance
decision. It can make the milestone ready for Cole's review, but only a later
append-only `milestone_decision` can accept or reject it.

L1.0-L1.7 form the milestone evidence set. L1.8 and the knowledge-draft guard
are supplementary constraints. The commissioning-registry test is an
integrity gate. These roles are counted separately in the report.

## Options considered

### Option A: Treat the existing aggregate test report as certification

| Dimension | Assessment |
|---|---|
| Implementation effort | Low |
| Source provenance | Medium-low |
| Per-run auditability | Low |
| Fresh-process proof | Partial |
| Cherry-pick resistance | Low |

**Pros**

- Reuses the current test runner without new artifacts.
- Produces a result quickly.

**Cons**

- One aggregate report is not a bundle family.
- It has no per-run source inventory or detached receipt.
- It does not reconcile fresh repeats program by program.
- Numeric observations remain mixed into untyped console output.

### Option B: Port every L1 fixture into the BR1 trace-bundle pipeline

| Dimension | Assessment |
|---|---|
| Implementation effort | Very high |
| Source provenance | Very high |
| Per-run auditability | Very high |
| Semantic fit | Mixed |
| Risk to BR1 | Medium-high |

**Pros**

- Reuses trace replay and existing run-bundle validation.
- Gives frame-level physics records for every experiment.

**Cons**

- Requires rewriting already commissioned experiments before promotion.
- L1.5 and L1.6 intentionally vary engine/world lifecycle settings that do not
  fit one ordinary ExperimentSpec/run shape.
- A large port could change the measured fixtures while appearing to improve
  only provenance.
- It invites broadening or revising the frozen BR1 family.

### Option C: Source-pinned BR3A evidence capsules

| Dimension | Assessment |
|---|---|
| Implementation effort | Medium-high |
| Source provenance | High |
| Per-run auditability | High |
| Semantic fit | High |
| Risk to BR1 | Low |

**Pros**

- Certifies the exact commissioned programs without silently replacing them.
- Keeps BR1 byte and inventory boundaries untouched.
- Gives every run an external receipt, exact source closure, raw logs, and
  structured assertion/observation evidence.
- Represents non-identical numeric repeats honestly while still reconciling
  the complete campaign.

**Cons**

- Does not retroactively create frame-level trace replay for experiments that
  were not authored as trace runs.
- Requires a new validator, report schema, and report-attestation domain.
- The source closure is intentionally broad, so unrelated lab-core edits can
  force a new campaign.

## Trade-off analysis

Option C retains the scientific identity of the commissioned fixtures while
closing the promotion gaps that matter: clean source, process isolation,
complete repeats, immutable evidence, production receipts, independent
readback, and claim-sized reporting. Option B remains available if a later
milestone requires frame-by-frame replay of a particular L1 mechanism. It is
not a prerequisite for honestly certifying what the present programs did.

The deliberate cost is a second bundle family. That cost is preferable to
calling console test output a BR1 run bundle or changing BR1's established
meaning. Both families share only the generic publication receipt primitive;
their manifests, metrics, campaign reports, and report-attestation domains
remain distinct.

## Consequences

What becomes easier:

- auditing exactly which source bytes and OS process produced each L1 result;
- detecting missing, duplicated, substituted, or selectively omitted runs;
- distinguishing milestone, supplementary, and integrity evidence;
- carrying L1.8's multi-manifold warning into every later load contract;
- preparing a bounded human milestone decision without manufacturing one.

What becomes harder:

- changing any declared lab-core source without rerunning the campaign;
- presenting only the most favorable replicate;
- treating a passing BR3A report as accepted knowledge;
- using a raw local contact-impulse sum as foot load.

What must be revisited:

- frame-level trace promotion for any L1 result later consumed as a dynamic
  controller invariant;
- a validated multi-contact load-allocation method before per-foot or per-toe
  claims;
- a new milestone-decision evidence-basis schema capable of naming BR3A
  reports without weakening the existing BR1 decision record.

## Action items

1. [x] Define strict campaign, capsule, metrics, source-inventory, report, and
   report-receipt schemas.
2. [x] Add target-process identity to the shared process-runner witness.
3. [x] Implement capsule construction, generic bundle attestation, and final
   readback.
4. [x] Implement the independent BR3A report attester and CLI.
5. [x] Add adversarial schema, bundle, receipt, omission, and claim-boundary
   tests.
6. [x] Commit the implementation and execute the complete clean campaign.
7. [x] Reconcile all replicates and verify the detached final report receipt.
8. [x] Prepare, but do not self-approve, the milestone decision for Cole.
