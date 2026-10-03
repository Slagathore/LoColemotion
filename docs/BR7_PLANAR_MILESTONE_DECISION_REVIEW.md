# BR7 planar milestone decision review

- **Review status:** bounded acceptance recommended
- **Candidate milestone:** `BR7_PLANAR_MULTI_CONTACT_STANCE`
- **Candidate decision ID:** `BR7_PLANAR_MULTI_CONTACT_STANCE_DECISION_V1`
- **Certification ID:** `br7_20260723T134427Z_91a160b9`
- **Certified source:** `91a160b99dce9e7d9c33424c8bdde4b7bd1e3c4d`
- **Knowledge admitted by this decision:** none
- **Automatic creature guidance authorized:** no

## Recommendation

Accept `BR7_PLANAR_MULTI_CONTACT_STANCE` at only the exact BR7.0–BR7.3
source-pinned program scopes and the verbatim certification boundary below.
Retain BR7.4 as integrity-only containment; do not count it as a physical
capability.

The evidence is sufficient for exact two-contact planar wrench allocation,
unilateral/friction rejection, support-segment and support-loss supervision,
and scaffold-constrained planar height/pitch stance in the declared live
two-leg fixture. It is not sufficient for measured per-foot allocation, free
3D standing, or unconstrained balance.

If accepted, the formal ladder becomes **8 of 18 milestones accepted
(44.4%)**. That is a bounded stance-control milestone, not “44.4% walking.”

## Delegated decision authority

Cole instructed:

> continue the pipeline. i defer to your judgement on what should be accepted.
> assume i accept whatever it is that you recommend and keep going

Cole then directed the pipeline to continue as far as possible without
stopping for reports and to build around undecided design choices where
possible. This review applies that authority only to the bounded
recommendation above. It does not use delegation to erase the scaffold, invent
a load sensor, admit knowledge, authorize guidance, or manufacture standing
or locomotion evidence.

## Exact certified evidence

| Field | Exact value |
|---|---|
| Certification | `br7_20260723T134427Z_91a160b9` |
| Certification contract | `BR7_PLANAR_MULTI_CONTACT_STANCE` |
| Campaign | `BR7_PLANAR_PROMOTION_CAMPAIGN_V1` |
| Source commit | `91a160b99dce9e7d9c33424c8bdde4b7bd1e3c4d` |
| Campaign SHA-256 | `sha256:83868168d51f2d0f30f98305d024571e5c6fd02809b4fbd8f2bd4af74cb26cf5` |
| Source-inventory SHA-256 | `sha256:d37c28fc98caa552d6f6bf639d33ce3934403df4ca97046e4d708df1d39147a0` |
| Report SHA-256 | `sha256:2cf0eed0bd1a27ff3c4f93fab384e0813834143ac4fe0dc2f67cb5b0f7d2087f` |
| Report bytes | `23,941` |
| Detached receipt SHA-256 | `sha256:5e89081ca74e5bfc85205a8265a10a80469927e129bd3352e6422d9177b20257` |
| Report receipt domain | `sporespore.lab.br7_certification_report_attestation.v1` |
| Report | `%LOCALAPPDATA%\SporeSpore\LabEvidence\BR7\br7_20260723T134427Z_91a160b9\br7_certification_report.json` |
| Receipt | `%LOCALAPPDATA%\SporeSpore\LabTrust\v1\br7_certification_reports_v1\receipts\d1a14c5e72ff6046632a7b0ae283c7c92d107f59286e3bb1cc7eaf7429f88511.json` |

The campaign retained two fresh target-process runs for every program:

| Cell | Role | Assertions per replicate | Certified assertions |
|---|---|---:|---:|
| BR7.0 | milestone | 9 | 18 |
| BR7.1 | milestone | 8 | 16 |
| BR7.2 | milestone | 10 | 20 |
| BR7.3 | milestone | 13 | 26 |
| BR7.4 | integrity only | 12 | 24 |
| **Total** | **5 programs, 10 retained bundles** | **52** | **104** |

Final accounting:

- Programs: 5 / 5.
- Bundles and production receipts: 10 / 10.
- Milestone assertions: 80 / 80.
- Integrity assertions: 24 / 24.
- Total assertions: 104 / 104.
- Fresh target-process invocations: 10.
- Unique target PIDs: 10.
- PID recycle events: 0.
- Final bundle, receipt, metrics, and source-inventory readback: 10 / 10.

## Verbatim certification claim boundary

> This campaign can certify only the exact BR7.0 two-contact planar
> allocation, BR7.1 friction and unilateral rejection, BR7.2 support/capture
> segment and support-loss supervision, and BR7.3 live two-leg planar stance
> program scopes named by the source-pinned programs; BR7.4 is integrity-only
> containment and cannot substitute for a milestone program. The unpowered
> Generic6DOF out-of-plane guide is an explicit material scaffold: sagittal
> X/Y translation and pitch are released while out-of-plane translation,
> roll, and yaw remain locked, and all guide motors and springs remain off.
> Two ordinary distal contacts, four paired finite joint actuators, strict
> non-clamping allocation, whole-system aggregate support and pitch-wrench
> reconstruction, the declared positive pitch impulse, and the declared
> right-support removal retain their exact fixture, geometry, mass, timestep,
> solver, controller, and actuator scopes. Commanded left/right contact shares
> are not measured per-foot loads. This establishes scaffold-constrained
> planar height/pitch stance and support-loss detection only, not free 3D
> standing, unconstrained balance, per-foot measured load allocation, bracing,
> fall arrest, getting up, gait, walking, accepted knowledge, or automatic
> creature guidance.

## What acceptance means

Acceptance means only:

1. BR7.0 exactly realizes the declared feasible two-contact vertical force
   and pitch moment and rejects a request that requires pulling contact.
2. BR7.1 exactly enforces the declared unilateral and Coulomb-friction
   feasibility boundaries, including one-support and no-support cases.
3. BR7.2 computes the declared static/capture support segment and emits one
   reasoned, force-free, fail-closed transition after support loss.
4. BR7.3 regulates height and pitch through two ordinary distal contacts and
   four paired finite joint actuators in the exact scaffold-constrained
   fixture.
5. The exact fixture reconstructs aggregate support and pitch wrench,
   recovers from the declared positive pitch impulse, and stops after the
   declared support removal becomes infeasible.
6. BR7.4 proves only that hidden assistance, false measurement, missing
   support-loss evidence, contract mutation, and broadened claims fail closed.

## What acceptance does not mean

The following remain false:

- Allocator commands are per-contact or per-foot measurements.
- A per-contact, per-foot, or per-toe load sensor or allocator exists.
- The out-of-plane guide reaction is absent, negligible, or measured.
- Free 3D standing or unconstrained balance has been proved.
- Terrain robustness, morphology generality, complex-foot superiority, or
  endurance is established.
- Bracing, fall arrest, self-righting, getting up, gait, candidate walking, or
  walking has been demonstrated.
- Any encyclopedia entry is admitted by this decision.
- Automatic creature repair or movement guidance is authorized.

## Options considered

### Option A — accept the bounded milestone (recommended)

Pros:

- The complete clean campaign passed with two fresh-process replicates for
  every program and no cherry-picking.
- Ten capsules and the final report independently reverify under production
  trust.
- Arithmetic, live physics, sign-controlled disturbance, support removal, and
  adversarial containment are all represented.
- The report preserves the guide and aggregate-only measurement boundary.
- The schema makes free 3D standing, measured per-foot allocation, and
  locomotion claims unrepresentable.

Costs and limits:

- The result remains bounded to the certified fixture, geometry, masses,
  timestep, solver, controller gains, actuator ceilings, engine, and source.
- Out-of-plane translation, roll, and yaw remain locked.
- Aggregate momentum reconstruction does not identify individual foot loads.
- Knowledge admission and guidance authority remain separate operations.

### Option B — defer

Deferral would keep the formal ladder at 7/18 while requesting more evidence
inside the same scaffold-constrained claim. There is no failed replicate,
unreconciled program, hidden assistance, or untested declared control that
justifies that delay. Free 3D stance and per-foot measurement are separate
future milestones.

### Option C — reject

Rejection would be appropriate if report bytes, detached authentication,
source inventory, process isolation, replicate reconciliation, live
disturbance/support-loss behavior, or claim containment failed. None did.

## Required decision effects

The append-only decision should:

1. bind Cole's delegated authority to this exact review commit and byte hash;
2. bind the certification, source, campaign, report, receipt, inventory, and
   complete 5-program/10-bundle/104-assertion accounting;
3. accept only BR7.0–BR7.3 and the verbatim campaign boundary;
4. retain BR7.4 as integrity-only evidence;
5. preserve the guide and aggregate-only measurement limitations;
6. admit zero knowledge entries and authorize no automatic guidance; and
7. leave free 3D standing, bracing, recovery, gait, and walking separately
   provable.
