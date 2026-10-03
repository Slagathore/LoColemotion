# BR3A bounded easy-work handoff

> Status 2026-07-22: every task in the easy-work list below was completed
> without touching the forbidden list. See
> `docs/BR3A_EASY_WORK_COMPLETION.md` for what was built, the new L1.8
> finding, exact file/line anchors, and the state handed back for the hard
> promotion stream. This document is kept unchanged below as the original
> work order.

## Current truth

All planned `L1.0-L1.7` implementation cells exist. L1.0 contributes 83
released-suite commissioning assertions; the eight L1.1-L1.7 experimental test
files contribute 153 assertions. The separate commissioning-readiness test
contributes 13 more assertions. None of this is a BR3A acceptance decision,
accepted encyclopedia evidence, a load-bearing limb, bracing, standing,
recovery, or walking.

The authoritative machine boundary is:

```text
data/lab/campaigns/BR3A_L1_commissioning_status_v1.json
data/lab/schemas/br3a_commissioning_status_v1.schema.json
scripts/lab/br3a_commissioning_registry.gd
tests/test_experimental_br3a_commissioning_status.gd
```

Run it from PowerShell at the repository root:

```powershell
.\scripts\run_lab_tests.ps1 `
  -Pattern 'test_experimental_br3a_commissioning_status.gd' `
  -LogRoot 'C:\tmp\sporespore_br3a_status' `
  -TestTimeoutSeconds 60
```

Expected result: 13 passed, 0 failed, 0 unexpected engine errors.

The final development checkpoint also ran the two complete domains separately:

```text
test_lab_*.gd          62/62 programs, 1,118/1,118 assertions
test_experimental_*.gd  9/9 programs,   166/166 assertions
```

Both reported zero failures, zero timeouts, and zero unexpected engine errors.
Do not combine them into one certification number.

## Work suitable for the other LLM

These tasks are bounded, mechanical, and unable to broaden an accepted claim
when the guards below are respected:

1. Draft the **separate L1.8 contact-discretization commissioning fixture** for
   exactly `1/4/16/64/100` equal-area contact elements. Keep it named
   `test_experimental_*`; measure load sharing, chatter, cost, contact-cap
   utilization, and divergence. Do not call one rigid pad's multiple solver
   points independent actuators.
2. Create **development-only knowledge draft JSON files** for L1.1-L1.7 from
   the equations and measured scopes in the main bootstrap. Use
   `development_observation` language, keep `minimal_repair_rules` advisory,
   and do not run admission because promotion-grade bundles do not exist.
3. Improve tables, local file-line anchors, diagrams, and cross-links in the
   two governing locomotion documents without changing numeric claims.
4. Add read-only CLI output that renders the commissioning status and five
   blockers for a human. It may call `LabBr3aCommissioningRegistry`; it may not
   manufacture readiness or write decisions.
5. Add unit negations around malformed knowledge drafts or L1.8 fixture
   configuration, provided those tests remain outside BR1 report-v2.

## Work the other LLM must not perform

The following are trust-critical architecture, not easy cleanup:

- do not edit `BR1_required_lab_tests_v2.json` or any report-v2 schema,
  attestation domain, receipt, legacy snapshot, or accepted milestone decision;
- do not rename experimental tests to `test_lab_*`;
- do not design or publish the BR3A production bundle/report/attestation family
  without a dedicated high-rigor review;
- do not create a BR3A decision record or add one to the allowlisted registry;
- do not admit `accepted`, `refuted`, or `retired` BR3A knowledge entries;
- do not enable automatic creature repair from development observations;
- do not generalize the L1.7 contact-stack `16:1-32:1` top-heavy bracket to
  joints or arbitrary creatures; and
- do not claim a foot, limb, brace, stand, recovery, gait, or walk exists.

## The next hard stream

Promotion requires a new BR3A-specific family—not “BR1 report-v3” and not a
larger BR1 inventory:

```text
L1 experiment specs/runners
  -> immutable per-cell bundles and metric artifacts
  -> detached bundle receipts
  -> fresh-process repeats and readbacks
  -> sporespore.lab.br3a_certification_report.v1
  -> separate BR3A report-attestation HMAC domain
  -> clean source-pinned production campaign
  -> promotion-grade knowledge entries
  -> Cole's explicit bounded BR3A milestone decision
```

Every step must preserve the negative findings: callback contact velocity is
pre-constraint in the calibrated fixtures; predicted contact impulse is not an
exact continuous force; local raw floor impulse is transmission-blind in the
coupled stacks; contact presence does not prove stable load transmission; and
unmeasured timestep, solver, or mass-ratio cells cannot be interpolated.
