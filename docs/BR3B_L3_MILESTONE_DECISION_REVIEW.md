# BR3B L3 milestone decision review

- **Review status:** bounded acceptance recommended
- **Candidate milestone:** `BR3B_L3_BASIC_LOADED_FOOT_TRUTH`
- **Candidate decision ID:** `BR3B_L3_BASIC_LOADED_FOOT_TRUTH_DECISION_V1`
- **Certification ID:** `br3b_20260723T103240Z_f5f54a58`
- **Certified source:** `f5f54a58abae57089b37ab39fdb8b76a2c157219`
- **Knowledge admitted by this decision:** none
- **Automatic creature guidance authorized:** no

## Recommendation

Accept `BR3B_L3_BASIC_LOADED_FOOT_TRUTH` at only the exact L3.0-L3.2
source-pinned program scopes and the verbatim certification boundary below.

The evidence is sufficient for the declared free unary pad's centered normal
load, loaded shear-breakaway, predicted contact-pressure migration, and
rocking-edge observations. It is not evidence of an articulated load-bearing
limb and does not cross any standing, bracing, recovery, gait, or walking
boundary.

If accepted, the formal ladder becomes **6 of 18 milestones accepted (33.3%)**.
That is prerequisite-gate completion, not “one-third of walking.”

## Delegated decision authority

Cole gave the direct instruction:

> continue the pipeline. i defer to your judgement on what should be accepted.
> assume i accept whatever it is that you recommend and keep going

Cole then instructed the pipeline to continue as far as possible without
stopping for reports, stated trust in the recommendation, and asked that
undecided design choices be built around where possible.

This review applies that authority only to the bounded recommendation above.
It does not treat delegation as permission to widen claims, admit knowledge,
authorize guidance, or manufacture evidence.

## Exact certified evidence

| Field | Exact value |
|---|---|
| Certification | `br3b_20260723T103240Z_f5f54a58` |
| Certification contract | `BR3B_L3_BASIC_LOADED_FOOT_TRUTH` |
| Campaign | `BR3B_L3_PROMOTION_CAMPAIGN_V1` |
| Source commit | `f5f54a58abae57089b37ab39fdb8b76a2c157219` |
| Campaign SHA-256 | `sha256:5409d646a33aa01a81e635c022362bb52bff5be98b98cf993acf077def3c210c` |
| Source-inventory SHA-256 | `sha256:11ddc05761ab144b05015b1b413817f849fe21990513408e15c0708a7e3a633b` |
| Report SHA-256 | `sha256:b3e1a014cf041a8a6ab4569b363c161081dd078ef620323c67076463a0e80986` |
| Detached receipt SHA-256 | `sha256:08cd88607fd461ef32739fc9a367d4cffca5719ef6a44aa4c01c7b7f2022447c` |
| Report receipt domain | `sporespore.lab.br3b_certification_report_attestation.v1` |
| Report | `%LOCALAPPDATA%\SporeSpore\LabEvidence\BR3B\br3b_20260723T103240Z_f5f54a58\br3b_certification_report.json` |
| Receipt | `%LOCALAPPDATA%\SporeSpore\LabTrust\v1\br3b_certification_reports_v1\receipts\3b957e2f47e5855e1b36304336641ca82a4b7084fad409de4f1bec94a6c63a02.json` |

The campaign retained two fresh target-process runs for every program:

| Cell | Exact scope | Assertions per replicate | Certified assertions |
|---|---|---:|---:|
| L3.0 | Free unary pad under the centered `0`, `20`, `40`, and `80 N` external normal-load cells | 14 | 28 |
| L3.1 | Free unary pad under `40 N` external normal load and the exact shear schedule, retaining the accepted L1 friction bracket | 13 | 26 |
| L3.2 | Free unary pad under the exact off-center load schedule, analytic rocking bracket, and mirrored repeat | 16 | 32 |
| **Total** | **3 programs, 6 retained bundles** | **43** | **86** |

Final accounting:

- Programs: 3 / 3.
- Bundles and production receipts: 6 / 6.
- Assertions: 86 / 86.
- Fresh target-process invocations: 6.
- Unique target PIDs: 6.
- PID recycle events: 0.
- Supplementary or integrity substitutions: 0.
- Final bundle, receipt, metrics, and source-inventory readback: 6 / 6.

## Verbatim certification claim boundary

> This campaign can certify only the exact L3.0-L3.2 free unary loaded-pad
> observations named by the source-pinned programs. The force-controlled
> carriage is an explicit apply_force boundary and not a rail; centered normal
> loading, loaded shear breakaway, predicted contact-pressure edge migration,
> and rocking retain their declared fixture, load, geometry, material,
> timestep, and solver scopes. It establishes no general contact wrench,
> per-contact or per-foot load allocation, articulated load-bearing limb,
> standing, bracing, fall arrest, getting up, gait, walking, accepted
> knowledge, or automatic creature guidance.

## What acceptance means

Acceptance means only:

1. The declared free unary pad's whole-system momentum reconstruction matches
   the exact centered normal-load grid.
2. Under the declared `59.6 N` normal support, the pad holds `34 N` shear and
   slides at `36 N`, keeping the breakaway ratio inside accepted L1 truth.
3. The declared off-center force moves predicted contact pressure toward the
   edge, remains stable at `0.21 m`, and rocks at `0.24 m` around the analytic
   `0.2235 m` threshold.
4. The negative `-0.24 m` repeat rocks toward the mirrored edge.
5. The force-controlled carriage is only `RigidBody3D.apply_force`; it supplies
   no physical rail, pin, lock, damping, motor, or balancing moment.

## What acceptance does not mean

The following remain false:

- A general contact wrench or continuous foot-force sensor exists.
- A per-contact, per-foot, or per-toe load is allocated.
- An articulated load-bearing limb, foot, or creature has been proved.
- A laboratory force source demonstrates support produced by a creature body.
- Terrain robustness, complex-foot superiority, or endurance is established.
- Standing, bracing, fall arrest, self-righting, getting up, gait, candidate
  walking, or walking has been demonstrated.
- Any encyclopedia entry is admitted by this decision.
- Automatic creature repair or movement guidance is authorized.

## Options considered

### Option A — accept the bounded milestone (recommended)

Pros:

- The complete clean campaign passed with two fresh-process replicates per
  program and no omitted or cherry-picked result.
- Six evidence capsules and the final report independently reverify under
  production trust.
- The nearest stable/unstable rocking pair brackets the analytic edge and has
  a mirrored repeat.
- The shear result is checked against already accepted L1 friction truth.
- The report schema makes guide reactions, general wrench claims, per-foot
  allocation, articulated support, and locomotion claims unrepresentable.
- Acceptance unlocks honest construction of contact-bearing BR6A.

Costs and limits:

- The result covers one pad, one mass and geometry, exact load/material grids,
  one timestep, and the certified engine/solver source.
- Raw predicted impulses remain diagnostic and cannot be summed into a general
  load allocator.
- An articulated limb may still fail through geometry, mass ratio, joint
  capacity, control, contact allocation, or root dynamics.
- Knowledge admission and any guidance authority remain separate operations.

### Option B — defer

Deferral would keep the formal ladder at 5/18 while requesting more unary-pad
evidence. There is no failed replicate, unresolved campaign discrepancy, or
unbracketed exact claim that justifies that delay. Broader pads, terrain, and
articulated support belong to later milestones.

### Option C — reject

Rejection would be appropriate if report bytes, receipt authentication, source
inventory, process isolation, replicate reconciliation, or claim containment
failed. None did. Rejecting the exact fixture observations would discard valid
bounded evidence without identifying a contradiction.

## Required decision effects

The append-only decision should:

1. bind Cole's delegated authority to this exact review commit and byte hash;
2. bind the certification, source, campaign, report, receipt, inventory, and
   complete 3-program/6-bundle/86-assertion accounting;
3. accept only the three exact program scopes and verbatim campaign boundary;
4. preserve every non-claim above;
5. admit zero knowledge entries;
6. authorize no automatic creature guidance; and
7. leave articulated support, standing, bracing, recovery, gait, and walking
   as separately provable milestones.
