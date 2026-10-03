# BR6A L4 milestone decision review

- **Review status:** bounded acceptance recommended
- **Candidate milestone:** `BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT`
- **Candidate decision ID:** `BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT_DECISION_V1`
- **Certification ID:** `br6a_20260723T121533Z_c0e72549`
- **Certified source:** `c0e725496c5daf6b55bab38b1485920e1d993ff8`
- **Knowledge admitted by this decision:** none
- **Automatic creature guidance authorized:** no

## Recommendation

Accept `BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT` at only the exact L4.0, L4.1, and
L4.3 source-pinned program scopes and the verbatim certification boundary
below.

The evidence is sufficient for the declared rigid-strut rail oracle,
one-hinge static holding-torque curve, and two-link vertical-rail support,
crouch/rise, declared disturbance recovery, and infeasibility controls. The
rail reaction is both explicit and material. This is therefore evidence of
articulated rail-constrained vertical support, not free-root standing or
balance.

If accepted, the formal ladder becomes **7 of 18 milestones accepted (38.9%)**.
That is a controlled single-leg support milestone, not “38.9% walking.”

## Delegated decision authority

Cole gave the direct instruction:

> continue the pipeline. i defer to your judgement on what should be accepted.
> assume i accept whatever it is that you recommend and keep going

Cole then instructed the pipeline to continue as far as possible without
stopping for reports, stated trust in the recommendation, and asked that
undecided design choices be built around where possible.

This review applies that authority only to the bounded recommendation above.
It does not treat delegation as permission to remove the rail boundary, admit
knowledge, authorize guidance, allocate per-foot load, or manufacture standing
or locomotion evidence.

## Exact certified evidence

| Field | Exact value |
|---|---|
| Certification | `br6a_20260723T121533Z_c0e72549` |
| Certification contract | `BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT` |
| Campaign | `BR6A_L4_PROMOTION_CAMPAIGN_V1` |
| Source commit | `c0e725496c5daf6b55bab38b1485920e1d993ff8` |
| Campaign SHA-256 | `sha256:3f79a2c2a90970286dfb3424745c29ff1a57d324079544174fa1aa88ffd0bfd6` |
| Source-inventory SHA-256 | `sha256:6a6d946683fd08a3f36d94e3b32d1052312b37d0d6bdb02e1ab7eb3b19933cd7` |
| Report SHA-256 | `sha256:431a98cbf727d09885378ad094efae105468c47b41c5df536b13e18c5855e42e` |
| Detached receipt SHA-256 | `sha256:1f86dca2a62b10e7a215b9b8791692061eddb65dcdfed8c7a560f83659d4fba5` |
| Report receipt domain | `sporespore.lab.br6a_certification_report_attestation.v1` |
| Report | `%LOCALAPPDATA%\SporeSpore\LabEvidence\BR6A\br6a_20260723T121533Z_c0e72549\br6a_certification_report.json` |
| Receipt | `%LOCALAPPDATA%\SporeSpore\LabTrust\v1\br6a_certification_reports_v1\receipts\cd5412306ffe29a0a79bc0f3114ef967883c82cd6ade958dece3f8a009215334.json` |

The campaign retained two fresh target-process runs for every program:

| Cell | Exact scope | Assertions per replicate | Certified assertions |
|---|---|---:|---:|
| L4.0 | Declared rigid strut on an explicit motorless and springless vertical rail, with freefall and ordinary floor-support cells | 12 | 24 |
| L4.1 | Declared one-hinge rail strut at `0`, `15`, `30`, and `45` degrees plus the matched `30`-degree zero-torque control | 12 | 24 |
| L4.3 | Declared two-link rail leg under static support, crouch/rise, downward impulse, rail-reaction, saturation, and infeasibility cells | 16 | 32 |
| **Total** | **3 programs, 6 retained bundles** | **40** | **80** |

Final accounting:

- Programs: 3 / 3.
- Bundles and production receipts: 6 / 6.
- Assertions: 80 / 80.
- Fresh target-process invocations: 6.
- Unique target PIDs: 6.
- PID recycle events: 0.
- Supplementary or integrity substitutions: 0.
- Final bundle, receipt, metrics, and source-inventory readback: 6 / 6.

## Verbatim certification claim boundary

> This campaign can certify only the exact L4.0 rigid-strut rail oracle, L4.1
> hinged-strut static load curve, and L4.3 two-link vertical-carriage support
> program scopes named by the source-pinned programs. The Generic6DOF vertical
> rail is an explicit material scaffold whose vertical axis is unlocked and
> whose observed reaction is retained; ordinary distal floor contact, paired
> finite joint torque, aggregate external-load reconstruction, crouch/rise
> work, the declared downward impulse, and exact infeasibility controls retain
> their fixture, geometry, mass, timestep, solver, controller, and actuator
> scopes. It establishes rail-constrained articulated vertical support only,
> not general per-foot allocation, free-root standing or balance, bracing,
> fall arrest, getting up, gait, walking, accepted knowledge, or automatic
> creature guidance.

## What acceptance means

Acceptance means only:

1. The declared rigid strut free-falls at gravity when the floor is absent and
   reconstructs the exact `29.4 N` support load through ordinary distal floor
   contact when supported on the explicit vertical rail.
2. The declared one-hinge rail strut matches the analytic static holding
   torques at `0`, `15`, `30`, and `45` degrees under reconstructed `29.4 N`
   support, while the matched `30`-degree zero-torque control fails to hold.
3. The declared two-link rail leg carries aggregate weight through ordinary
   distal contact without a foot pin, built-in joint motor, passive tissue, or
   root-rescue force.
4. That exact leg performs the declared bounded crouch/rise, retains measured
   joint work and potential-energy gain, and recovers from the declared
   downward carriage impulse.
5. The rail's tangential reaction is retained as a material scaffold load.
6. The controller reports saturation with anti-windup and refuses the exact
   unreachable-height and insufficient-actuator controls.

## What acceptance does not mean

The following remain false:

- The omitted L4.2 free-space tracking cell is certified by BR6A.
- A general contact wrench or per-contact, per-foot, or per-toe load allocator
  exists.
- The rail reaction is negligible, absent, or transferable to an unconstrained
  root.
- Free-root standing, balance, or rail-independent support has been proved.
- Terrain robustness, morphology generality, complex-foot superiority, or
  endurance is established.
- Bracing, fall arrest, self-righting, getting up, gait, candidate walking, or
  walking has been demonstrated.
- Any encyclopedia entry is admitted by this decision.
- Automatic creature repair or movement guidance is authorized.

## Options considered

### Option A — accept the bounded milestone (recommended)

Pros:

- The complete clean campaign passed with two fresh-process replicates per
  program and no omitted or cherry-picked result.
- Six evidence capsules and the final report independently reverify under
  production trust.
- Freefall, analytic torque, support-load, energy, disturbance, saturation,
  and infeasibility controls distinguish the result from a contact-presence
  demo.
- The rail constraint and its material reaction are preserved in the report
  rather than hidden as fixture assistance.
- The report schema makes free-root standing, balance, per-foot allocation,
  and locomotion claims unrepresentable.
- Acceptance unlocks honest construction of the next support-control rung.

Costs and limits:

- The result covers the certified geometry, masses, load and height schedule,
  impulse, timestep, solver, controller, actuator ceiling, engine, and source.
- Only aggregate external support load is reconstructed.
- The rail removes lateral root translation and all root rotation; later
  milestones must restore and control those degrees of freedom explicitly.
- Knowledge admission and any guidance authority remain separate operations.

### Option B — defer

Deferral would keep the formal ladder at 6/18 while requesting more
rail-supported evidence. There is no failed replicate, unresolved campaign
discrepancy, hidden scaffold reaction, or untested control inside the exact
claim that justifies that delay. Wider geometry, free-root support, terrain,
and multi-contact allocation belong to later milestones.

### Option C — reject

Rejection would be appropriate if report bytes, receipt authentication, source
inventory, process isolation, replicate reconciliation, analytic controls, or
claim containment failed. None did. Rejecting the exact rail-support
observations would discard valid bounded evidence without identifying a
contradiction.

## Required decision effects

The append-only decision should:

1. bind Cole's delegated authority to this exact review commit and byte hash;
2. bind the certification, source, campaign, report, receipt, inventory, and
   complete 3-program/6-bundle/80-assertion accounting;
3. accept only the three exact program scopes and verbatim campaign boundary;
4. preserve the material rail reaction and every non-claim above;
5. admit zero knowledge entries;
6. authorize no automatic creature guidance; and
7. leave free-root standing, balance, bracing, recovery, gait, and walking as
   separately provable milestones.
