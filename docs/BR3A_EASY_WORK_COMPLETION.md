# BR3A easy-work completion and handback

- **Date:** 2026-07-22
- **Work order:** `docs/BR3A_EASY_WORK_HANDOFF.md` (kept unchanged below its
  status banner)
- **Result:** all five bounded tasks complete; zero forbidden-list items
  touched; the five promotion blockers, the pinned commissioning status, and
  the BR1 report-v2 family are byte-identical to commit `dbf0f82`.

This document is the handback for the hard promotion stream. It says exactly
what was built, where, and what it does and does not claim.

## 1. What was completed

| Handoff task | Status | Primary artifacts |
| --- | --- | --- |
| 1. L1.8 contact-discretization pack | done, 28/28 assertions | `scripts/lab/rigs/discretized_pad_rig.gd`, `scripts/lab/mechanics/contact_discretization_analyzer.gd`, `tests/test_experimental_l1_8_contact_discretization.gd` |
| 2. Development-only knowledge drafts | done, 8 drafts | `data/lab/knowledge/drafts/br3a/*.development.json`, `data/lab/schemas/br3a_development_observation_v1.schema.json` |
| 3. Documentation cleanup | done | bootstrap doc L1.8 checkpoint and table rows, research-program status and ladder row (anchors in section 5) |
| 4. Read-only status CLI | done, live-proven | `scripts/lab/br3a_status_cli.gd` |
| 5. Negation/adversarial tests | done, 15/15 assertions | `tests/test_experimental_br3a_knowledge_draft_guard.gd` plus adversarial cases inside the L1.8 test |

## 2. The one genuinely new physical finding (L1.8)

The pack reused the L1.4 pad (one free rigid 2 kg body, 0.30 x 0.20 m
footprint) and tiled its collision geometry into 1/4/16/64/100 equal-area box
elements on the same single body. Measured at 60 Hz on real Jolt:

| Elements | Raw predicted sum | Reconstructed load | Ratio |
| ---: | ---: | ---: | ---: |
| 1 | 19.6490 N | 19.6000 N | 1.0025 |
| 4 | 78.3803 N | 19.6000 N | 3.9990 |
| 16 | 219.7367 N | 19.6000 N | 11.2111 |

The physically transmitted support is mg = 19.6 N at every count, and
whole-system momentum reconstruction reports exactly that, while the summed
raw predicted contact impulses inflate roughly with manifold count and each
individual element manifold sums to about the full pad weight. Conclusion,
now pinned by the analyzer and test: **summing raw predicted impulses across
multiple same-body shape-pair manifolds is not an additive load partition and
is not the external support load.** This extends the L1.6/L1.7
transmission-blindness family and matters directly for any future multi-shape
foot, heel/toe split, or toe pads.

Second structural result: under the frozen `full_contacts_v2` 256-point
policy, the a-priori four-points-per-element declaration makes 64-element
(264 demanded) and 100-element (408 demanded) enumeration refuse with
`DERIVED_CONTACT_CAP_EXCEEDS_POLICY` instead of silently truncating. Those
counts ran contacts-disabled (`full_state_v1`) as honest reconstruction-only
cells, which also balanced mg within measurement error. Enumerating more than
16 equal-area elements therefore requires a future observation-policy
decision; do not raise the 256 ceiling casually, it is part of the frozen
profile identity.

Everything else measured: CoP stayed within 3.5 mm of the projected COM at
every enumerated count, chatter and element-presence churn were exactly zero,
peak cap utilization was 4/16/64 points under caps 12/24/72, and wall-clock
tick cost is recorded per cell as a diagnostic and deliberately not gated.
The analyzer forbids interpolation, forbids actuator framing, and lists
`additive_per_element_load_partition_from_raw_impulse` plus the usual
locomotion items under `does_not_establish`.

## 3. New and changed files

New:

- `scripts/lab/rigs/discretized_pad_rig.gd` - `discretized_pad_v1` fixture;
  refusal of body tuning, unknown parameters, actuator framing, and unknown
  element counts; a-priori capacity declaration and policy refusal surface.
- `scripts/lab/mechanics/contact_discretization_analyzer.gd` - digest-bound
  exact-cell contract with three evidence classes (`measured_contact`,
  `policy_refused`, `reconstruction_only`), preregistered raw-sum ratio
  brackets (0.95-1.05, 3.5-4.5, 9.0-13.0), and fail-closed validation of
  forged classes, unmeasured counts, and unknown config fields.
- `tests/test_experimental_l1_8_contact_discretization.gd` - 28 assertions,
  five run cells plus two refusal cells, adversarial analyzer cases.
- `data/lab/schemas/br3a_development_observation_v1.schema.json` - strict
  draft schema; `additionalProperties: false`; pins
  `claim_status_ceiling: development_observation`, `admissible_now: false`,
  all five blockers, `promotion_grade_bundle_exists: false`, and
  advisory-only repair rules.
- `data/lab/knowledge/drafts/br3a/` - eight drafts (L1.1-L1.8) plus a README
  stating the hard limits. Draft entry ids end in `.draft_v1`.
- `tests/test_experimental_br3a_knowledge_draft_guard.gd` - 15 assertions of
  containment: schema negations, `verify_entry` rejection, `load_entries`
  fail-closed, empty `repair_candidates`, `propose_from_bundle` refusal,
  zero admitted BR3A entries, and registry blockers re-verified.
- `scripts/lab/br3a_status_cli.gd` - read-only renderer over
  `LabBr3aCommissioningRegistry.inspect_current()`; `--json` mode; exit 0
  valid, 3 registry refusal, 4 bad arguments; live-proven in all three paths.
- `docs/BR3A_EASY_WORK_COMPLETION.md` - this document.

Changed:

- `scripts/lab/rig_factory.gd` - registers `discretized_pad_v1` only.
- `.gitattributes` - LF pinning extended to the new draft schema and drafts.
- `docs/BR3A_EASY_WORK_HANDOFF.md` - status banner added at the top; the
  original work order is unchanged below it.
- `docs/BRACING_RECOVERY_IMPLEMENTATION_BOOTSTRAP.md` and
  `docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md` - anchors in section 5.

## 4. What was deliberately not touched

Verbatim from the forbidden list, all confirmed untouched:

- `BR1_required_lab_tests_v2.json`, every report-v2 schema, attestation
  domain, receipt, legacy snapshot, and accepted milestone decision;
- the eight pinned experimental test sources for L1.1-L1.7 and the pinned
  `BR3A_L1_commissioning_status_v1.json` and its schema (their SHA-256 pins
  still verify; the registry and readiness test still pass 13/13);
- no experimental test was renamed to `test_lab_*`; the released pattern
  still discovers exactly 62 programs;
- no BR3A bundle/report/attestation family was designed or published;
- no decision record was created; no `accepted`, `refuted`, or `retired`
  BR3A entry was admitted; automatic creature repair still cannot consume
  any of this;
- the L1.7 contact-stack brackets were not generalized to joints, and no
  foot, limb, brace, stand, recovery, gait, or walk is claimed anywhere in
  the new code, drafts, or docs.

The five promotion blockers remain open, 5/5, and the next hard stream in
`docs/BR3A_EASY_WORK_HANDOFF.md` is unchanged and still the required path.

## 5. Anchors for the next session

Bootstrap (`docs/BRACING_RECOVERY_IMPLEMENTATION_BOOTSTRAP.md`):

- line 6841: new L1.8 row in the experimental evidence table;
- line 6842: new draft-guard row in the same table;
- line 6858: pinned status boundary (unchanged, still authoritative);
- line 6875: the five promotion blockers (unchanged);
- line 7513: `#### L1.8 contact discretization and the bounded easy-work
  pass - 2026-07-22` (the full checkpoint written by this pass);
- line 7524: L1.8 fixture and evidence classes;
- line 7552: the multi-manifold raw-sum finding with the measured table;
- line 7595: drafts and containment guard;
- line 7619: read-only status CLI;
- line 7635: experimental-domain accounting after this checkpoint.

Research program (`docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md`):

- line 113: current-state paragraph now covering L1.8, drafts, guard, CLI;
- line 1075: L1 ladder row for L1.8 updated with the measured outcome.

Registry internals worth knowing before the promotion stream:
`scripts/lab/br3a_commissioning_registry.gd` line 36 pins the eight
experimental sources by SHA-256 and line 46 pins the blocker list; neither
was modified, and neither enumerates the tests directory, so the two new
`test_experimental_*` files do not and must not enter those pins until the
promotion-grade family exists.

## 6. Regression evidence for this pass

Run on 2026-07-22 from this worktree, one isolated Godot process per test:

| Domain | Pattern | Programs | Assertions | Failures/timeouts | Unexpected engine errors |
| --- | --- | ---: | ---: | ---: | ---: |
| Immutable released regression | `test_lab_*.gd` | 62/62 | 1,118/1,118 | 0 | 0 |
| Experimental commissioning + separate work | `test_experimental_*.gd` | 11/11 | 209/209 | 0 | 0 |

Reports:

- `<evidence-root>\temp-roots-2026-07-28\sporespore_br3a_experimental_full2\20260722T204922374\report.json`
- `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_easywork\20260722T205330029\report.json`

The experimental 209 decomposes as 153 pinned L1.1-L1.7 assertions plus 13
pinned readiness assertions plus 28 L1.8 assertions plus 15 draft-guard
assertions. The pinned status file intentionally still accounts only for the
153+13; L1.8 and the guard are separate nonblocking work and enter no pinned
inventory. Do not combine the released and experimental numbers into one
certification claim.

The released suite retains its one intentional expected engine-error fixture,
which the runner classifies as expected; unexpected engine errors were zero
in both domains. These are development regressions from the current worktree,
not a production BR3A certification.

## 7. Where the hard stream picks up

Unchanged from the handoff: design the promotion-grade L1 bundle family, the
BR3A certification report family, and the detached BR3A attestation domain;
run one clean fresh-process source-pinned campaign with repeats and
readbacks; reconcile it without cherry-picking; only then prepare the
explicit bounded milestone decision for Cole. The drafts in
`data/lab/knowledge/drafts/br3a/` are authoring inputs for that stream; they
must be re-authored as `knowledge_entry.v1` against promotion-grade bundles,
never relabeled.
