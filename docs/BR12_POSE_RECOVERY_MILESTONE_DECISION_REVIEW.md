# BR12 Pose and Recovery-Feasibility Milestone Decision Review

- **Recommendation:** Accept at the exact certified BR12.0-BR12.3 scopes
- **Integrity cell:** BR12.4 remains integrity-only
- **Certification:** `br12_20260723T211754Z_0ace3791`
- **Certified source:** `0ace37912babd34bfc42e24414582e3bf53cb0c8`
- **Decision owner:** Cole
- **Date:** 2026-07-23

## Recommendation

Accept `BR12_POSE_AND_RECOVERY_FEASIBILITY` only as observer/planner truth:

- deterministic classification of the declared labeled-box canonical poses;
- explicit `unknown` for ambiguous, conflicting, invalid, nonfinite, or
  insufficient pose evidence;
- semantic anatomy-role matching for one exact recovery profile;
- named infeasibility for missing anatomy; and
- conservative static torque, power, structural, friction, and reach
  feasibility screening before actuation.

This is useful and sufficiently evidenced, but it is deliberately smaller
than a get-up milestone. The certification contains no recovery controller,
actuator command, wrench, joint target, contact creation, external assistance,
physical body rise, or stance handoff. A feasible report is not dynamic
execution evidence.

If accepted, the formal ladder advances from **12/18 (66.7%)** to **13/18
(72.2%)**. The decision itself admits no encyclopedia entry and grants no
repair, automatic-application, or creature-guidance authority.

## Authorization

Cole gave standing bounded authority in the direct conversation:

> continue the pipeline. i defer to your judgement on what should be accepted.
> assume i accept whatever it is that you recommend and keep going

Cole then instructed the agent to continue as far as possible without
stopping for reports and to defer undecided design choices behind explicit
boundaries when possible. The recommended decision uses that authority only
for this exact certified result.

## Exact evidence

| Field | Value |
|---|---|
| Campaign | `BR12_POSE_RECOVERY_PROMOTION_CAMPAIGN_V1` |
| Campaign SHA-256 | `sha256:10127cad5f1a180a871d0bd7c8ea992dd3cb22fa2056e1f1a4efeb00d17b8da0` |
| Source inventory SHA-256 | `sha256:f82f6c1941d0a43c8e86d220e9800c70a3229be1c2a36c9a3b7f3737f8378040` |
| Source files | 418 |
| BR1 inventory SHA-256 | `sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e` |
| Engine | `4.7.stable.mono.official.5b4e0cb0f` |
| Engine SHA-256 | `sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4` |
| Programs | 5/5 |
| Fresh-process bundles | 10/10 |
| Unique target processes | 10 |
| Assertions | 150/150 |
| Milestone assertions | 122 |
| Integrity assertions | 28 |
| Report SHA-256 | `sha256:8c9179471685a3278950c7dd5648fcf0551901996a68ed702b3261e57bf23bda` |
| Report bytes | 24,846 |
| Receipt SHA-256 | `sha256:0c5767c79bbffe400e9640c3c221961fef5116926ad02821ab13eb067691fc07` |
| Receipt key | `sha256:89d6e582f28664e93d12085c164cdf8fe40a76b5bfb2e382c9666279cd953a20` |

Report locator:

```text
LabEvidence/BR12/br12_20260723T211754Z_0ace3791/br12_certification_report.json
```

Detached receipt locator:

```text
LabTrust/v1/br12_certification_reports_v1/receipts/bacef86ef15701f795b7926c5cef95d0261e438f4233460c57ef6047268c0c5b.json
```

## Verbatim certification claim boundary

> This campaign can certify only the exact source-pinned BR12.0 semantic
> body-region contact-role registry and labeled-box basis-oracle scope; BR12.1
> deterministic profile-specific canonical-pose classifier scope; BR12.2
> semantic anatomy-role recovery-profile matching scope; and BR12.3
> conservative static torque, power, structural, friction, and reach
> feasibility scope. BR12.4 is integrity-only containment and cannot
> substitute for a milestone program. The BR12 claim boundary is verbatim:
> BR12 is observer/planner truth only. It classifies only declared labeled-box
> canonical poses, preserves ambiguous or invalid evidence as unknown, names
> missing anatomy, and reports whether one exact profile passes preregistered
> static inequalities before actuation. A feasible report is not dynamic
> execution evidence. No BR12 program contains a recovery controller, emits an
> actuator command, wrench, or joint target, creates or maintains contact,
> applies external assistance, raises a body, hands off to stance, repairs a
> creature, or guides one automatically. It establishes no physical
> self-righting or getting up, free-3D standing or bracing, generalized
> recovery, gait, or walking.

## Exact program interpretation

### BR12.0 — body-region roles and labeled-box oracle

Accept the strict semantic role registry and authored basis oracle at their
exact configuration. Ventral contact may be temporary recovery support but is
not steady stance. Invalid or nonfinite role/basis evidence fails closed.

### BR12.1 — pose classifier

Accept deterministic classification of only upright, prone, supine,
left-side, and right-side poses under the exact profile. Conflicting,
ambiguous, incomplete, invalid, or nonfinite evidence remains `unknown`.

### BR12.2 — recovery-profile role match

Accept semantic anatomy-role addressing, the one exact prone planning
profile, and named missing-role failures. No hardcoded limb-index convention
or controller authority is admitted.

### BR12.3 — static recovery feasibility

Accept the conservative torque, power, structural, friction, and reach
screens as preregistered planning gates. Accept named rejection of
underpowered, overloaded, slipping, unreachable, and anatomically incomplete
phases before actuation. Do not interpret `feasible` as evidence that the
dynamic maneuver can succeed.

### BR12.4 — integrity only

Retain BR12.4 as containment evidence. It cannot add a physical capability or
replace BR12.0, BR12.1, BR12.2, or BR12.3.

## Explicit exclusions

Acceptance does not establish:

- physical self-righting or getting up;
- dynamic recovery execution or stance handoff;
- controller, actuator, wrench, or joint-target authority;
- contact creation, contact maintenance, or external assistance;
- arbitrary morphology, terrain, pose-profile, or threshold transfer;
- free-3D standing, bracing, recovery, or unconstrained balance;
- measured per-contact, per-body, per-foot, or per-toe load allocation;
- gait, candidate walking, or walking;
- creature repair or automatic creature guidance;
- an encyclopedia admission; or
- BR13 constrained-get-up acceptance.

## Decision effect

The recommended append-only decision should:

- accept only BR12.0 through BR12.3;
- keep BR12.4 integrity-only;
- advance the formal ladder to **13/18 (72.2%)**;
- admit zero knowledge entries;
- authorize zero repair or automatic creature guidance; and
- leave BR13's morphology, starting pose, material scaffold, controller,
  dynamic phase sequence, and stance handoff as separately evidenced choices.
