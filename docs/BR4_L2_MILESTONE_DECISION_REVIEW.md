# BR4 L2 milestone decision review

- **Review status:** bounded acceptance recommended in the pinned review commit and now accepted by the separate append-only decision
- **Candidate milestone:** `BR4_L2_JOINT_ACTUATOR_TRUTH`
- **Candidate decision ID:** `BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1`
- **Certification ID:** `br4_20260723T090118Z_1760c2cf`
- **Certified source:** `1760c2cfdfd4cf6fd5b482d090588a680515d1db`
- **Knowledge admitted by this decision:** none
- **Automatic creature guidance authorized:** no

## Recommendation

Accept `BR4_L2_JOINT_ACTUATOR_TRUTH` at only the exact L2.0-L2.7
program scopes and the verbatim certification boundary reproduced below.

The evidence is sufficient for the fixture-bounded joint and actuator
observations. It is not evidence of a contact-bearing or load-bearing limb,
and it does not cross any standing, bracing, recovery, gait, or walking
boundary.

The recommendation is now implemented by append-only decision
`BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1`, SHA-256
`sha256:19dc2da4b372d3e50549eb9586b08ae796c6045897190ab4b60b8af4a72421a2`.
The decision pins the original review bytes at commit `3588f92`; this
post-decision note does not rewrite the context that was reviewed.

If accepted, the formal ladder becomes **5 of 18 milestones accepted
(27.8%)**. That percentage records acceptance of another prerequisite truth
layer; it does not mean that locomotion is 27.8% demonstrated.

## Delegated decision authority

Cole gave this direct instruction:

> continue the pipeline. i defer to your judgement on what should be accepted.
> assume i accept whatever it is that you recommend and keep going

The later instruction to continue as far as possible and the statement
“you know i trust in your recommendations” reinforce the same authority. This
review applies that authority only to the bounded recommendation above. It
does not treat delegation as permission to widen claims, admit knowledge,
authorize guidance, or manufacture evidence.

## Exact certified evidence

| Field | Exact value |
|---|---|
| Certification | `br4_20260723T090118Z_1760c2cf` |
| Certification contract | `BR4_L2_JOINT_ACTUATOR_TRUTH` |
| Campaign | `BR4_L2_PROMOTION_CAMPAIGN_V1` |
| Source commit | `1760c2cfdfd4cf6fd5b482d090588a680515d1db` |
| Campaign SHA-256 | `sha256:c5a8c97bd5bb3b58e79412f742d44eb266ef6e8f6eb6d83ad25eab15d49af417` |
| Source-inventory SHA-256 | `sha256:a7780e98f0801894d474bb0af02ab78499c4768d8e13fd1c75a66b588c0fcec3` |
| Report SHA-256 | `sha256:c21e209a37a94cc24072a135c33689b6511965ae9c14c8a56ca1d0b4d253dc33` |
| Detached receipt SHA-256 | `sha256:d652b1ab1484110c00ce8769f361033a3e6e58632dcac71cd8b11d11f760f34c` |
| Report receipt domain | `sporespore.lab.br4_certification_report_attestation.v1` |
| Report | `%LOCALAPPDATA%\SporeSpore\LabEvidence\BR4\br4_20260723T090118Z_1760c2cf\br4_certification_report.json` |
| Receipt | `%LOCALAPPDATA%\SporeSpore\LabTrust\v1\br4_certification_reports_v1\receipts\24706133a89b48611af23b2fb4f2cc2ee45063d008a5e841c8edf9687306004a.json` |

The campaign retained two fresh target-process runs for every program:

| Cell | Program scope | Assertions per replicate | Certified assertions |
|---|---|---:|---:|
| L2.0 | Passive pendulum period, energy, sign, geometry, and declared damping control | 24 | 48 |
| L2.1 | Free-hinge equal-and-opposite torque pulse, receipts, and angular-momentum behavior | 24 | 48 |
| L2.2 | Unloaded mirrored PD step response, decomposition, settling, and momentum behavior | 19 | 38 |
| L2.3 | Fixed-scaffold gravity compensation at 0%, 80%, 100%, and 120% | 14 | 28 |
| L2.4 | Exact finite torque-speed-power envelope points and limiting causes | 12 | 24 |
| L2.5 | Mirrored hard-limit constraint reaction and disabled-limit control | 12 | 24 |
| L2.6 | Fixed/free-root two-link chain response, paired receipts, and no root assistance | 14 | 28 |
| L2.7 | Anchor-error tolerance grid and fail-closed joint-observer behavior | 12 | 24 |
| **Total** | **8 programs, 16 retained bundles** | **131** | **262** |

Final campaign accounting:

- Programs: 8 / 8.
- Bundles: 16 / 16.
- Assertions: 262 / 262.
- Fresh target-process invocations: 16.
- Unique target PIDs: 16.
- PID recycle events: 0.
- Supplementary or integrity programs smuggled into the milestone: 0.
- Final bundle, receipt, metrics, and source-inventory readback: 16 / 16.

## Verbatim certification claim boundary

> This campaign can certify only the exact L2.0-L2.7 joint-actuator
> observations named by the source-pinned programs. Fixed scaffolds, free
> roots, actuator envelopes, hard-limit reactions, two-joint behavior, and
> anchor-observer failures retain their declared fixture scopes. It
> establishes no contact-bearing articulated limb, per-foot or per-contact
> load allocation, standing, bracing, fall arrest, getting up, gait, walking,
> accepted knowledge, or automatic creature guidance.

## What acceptance means

Acceptance means these exact observations may be treated as accepted
prerequisite mechanics knowledge:

1. The declared passive hinge fixture behaves consistently with its analytic
   pendulum oracle and explicit damping comparison.
2. A free parent-child hinge can receive a deterministic equal-and-opposite
   torque pair without root-only assistance.
3. The declared PD resolver and finite actuator produce the measured
   contact-free responses at the certified targets and operating points.
4. The fixed-scaffold gravity-hold cells reproduce the declared compensation
   signs and magnitudes.
5. A hard joint boundary produces a constraint reaction, not an observation
   of muscle or actuator strength.
6. The declared two-link chain retains paired actuation receipts and
   free-root momentum behavior.
7. Anchor geometry outside the declared tolerance suppresses dependent joint
   channels and commands instead of fabricating valid state.

## What acceptance does not mean

The following remain false:

- A contact-bearing articulated limb, foot, or creature has been proved.
- A per-contact, per-foot, or per-toe load has been allocated.
- A fixed scaffold demonstrates free-creature support.
- A hard-limit impulse measures usable muscle strength.
- The sampled actuator points establish continuous endurance, fatigue, or
  thermal capacity.
- Standing, bracing, fall arrest, self-righting, getting up, gait, candidate
  walking, or walking has been demonstrated.
- Any encyclopedia entry is admitted by the decision itself.
- Automatic creature repair or movement guidance is authorized.

## Options considered

### Option A — accept the bounded milestone (recommended)

Pros:

- The complete clean campaign passed with two fresh-process replicates per
  program and no omitted or cherry-picked run.
- The exact report is authenticated in a BR4-specific detached receipt domain.
- The report schema and independent verifier make root assistance, built-in
  motor authority, hard-limit strength, contact-bearing limbs, and walking
  claims unrepresentable.
- Acceptance unlocks honest use of the L2 joint/actuator prerequisites in
  later support experiments without pretending those experiments already
  passed.

Costs and limits:

- Every accepted observation remains fixture-bounded.
- A later contact-bearing limb can still fail due to geometry, mass ratio,
  contact allocation, support control, actuator capacity, or solver behavior.
- Knowledge admission remains a separate append-only operation.
- Creature guidance remains forbidden until later accepted support milestones
  justify it.

### Option B — defer

Deferral would preserve the current four accepted milestones while requesting
more evidence. No specific unresolved discrepancy, failed replicate, or
unclosed campaign gate currently justifies that delay. Additional contact and
support tests belong to later milestones rather than to the exact L2
joint-actuator truth claim.

### Option C — reject

Rejection would be appropriate if a report, receipt, source inventory,
replicate, claim boundary, or decision authority failed verification. None did.
Rejecting the exact fixture observations would therefore discard valid
evidence without identifying a contradictory result.

## Required decision effects

The append-only decision should:

1. Bind Cole’s delegated authority to this exact review commit and byte hash.
2. Bind the exact certification, source commit, report, receipt, campaign,
   inventory, program, bundle, assertion, and process counts.
3. Accept only the eight program claim scopes and the verbatim campaign
   boundary.
4. Preserve every non-claim listed above.
5. Admit zero knowledge entries.
6. Authorize no automatic creature guidance.
7. Leave contact-bearing support, standing, bracing, recovery, gait, and
   walking as separately provable future milestones.

## Recorded outcome

The recommended bounded acceptance was recorded as
`BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1`, with decision SHA-256
`sha256:19dc2da4b372d3e50549eb9586b08ae796c6045897190ab4b60b8af4a72421a2`.
The decision admits zero knowledge entries and authorizes no automatic
creature guidance.

Post-decision verification passed:

- dedicated decision contract: 24 / 24 assertions;
- complete experimental suite: 24 / 24 programs, 467 / 467 assertions;
- immutable released suite: 62 / 62 programs, 1,118 / 1,118 assertions;
- failures, timeouts, and unexpected engine errors: 0.

The original review bytes remain pinned at commit
`3588f92b5fe0e56e4c07aa114491ab4544c0988b` with SHA-256
`sha256:f82f25c51086cfb8f286cf8e98513a3d123b1c57c0221d86665a994e1e8d6fb8`.
This outcome section documents the later append-only decision and does not
alter the review bytes that authorized it.
