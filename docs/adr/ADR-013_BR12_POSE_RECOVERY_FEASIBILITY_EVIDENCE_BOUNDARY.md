# ADR-013: BR12 Pose and Recovery-Feasibility Evidence Boundary

- **Status:** Adopted for promotion-family construction
- **Date:** 2026-07-23
- **Decision owner:** Cole
- **Milestone:** `BR12_POSE_AND_RECOVERY_FEASIBILITY`

## Context

BR12 sits between the accepted BR11 controlled-fall observation and any BR13
physical get-up attempt. It must answer two planning questions without
silently becoming a recovery controller:

1. Which declared canonical pose does the labeled body occupy?
2. Does one exact semantic-role recovery profile pass conservative static
   feasibility checks before actuation?

The implementation contains no physics command path. A feasible report does
not show that the proposed maneuver can be executed dynamically.

## Decision

BR12 receives its own source-pinned promotion campaign, evidence metrics,
capsule, source-inventory, certification-report, and detached report-receipt
schemas. The fixed campaign runs five programs twice in fresh Godot target
processes:

| Role | Programs | Assertions per replicate | Two replicates |
|---|---:|---:|---:|
| Milestone: BR12.0-BR12.3 | 4 | 61 | 122 |
| Integrity: BR12.4 | 1 | 14 | 28 |
| Total | 5 | 75 | 150 |

The certifiable positive scope is limited to:

- strict semantic body-region contact roles and a labeled-box basis oracle;
- deterministic profile-specific upright, prone, supine, left-side, and
  right-side classification;
- explicit `unknown` results for ambiguity, invalidity, or insufficient
  evidence;
- semantic anatomy-role recovery-profile matching with named missing roles;
  and
- conservative static torque, power, structural, friction, and reach
  feasibility screening.

BR12.4 is integrity-only. It can reject weakened or broadened evidence but
cannot substitute for BR12.0 through BR12.3.

## Hard boundary

The schemas make all of the following false or unavailable:

- a recovery controller or actuator authority;
- command, wrench, or joint-target output;
- contact creation or maintenance;
- external assistance;
- physical self-righting, raising the body, or stance handoff;
- treating static feasibility as dynamic execution proof;
- automatic creature repair or guidance;
- free-3D or morphology-general recovery;
- getting up, gait, or walking; and
- automatic encyclopedia admission or BR13 acceptance.

Certification, bounded human decision, observation-only knowledge admission,
future controller implementation, physical execution, and creature guidance
remain separate transitions.

## Consequence for BR13

BR13 must choose and preregister one canonical morphology, one starting pose,
one material scaffold, one dynamic phase sequence, and one stance-handoff
gate. It may consume BR12's data structures as observer/planner inputs only
after BR12 is accepted. It cannot cite BR12 feasibility as proof that the
physical get-up succeeds.
