# BR13 Canonical Get-Up Certification Operator

## Purpose

This operator certifies only the source-pinned BR13 constrained planar
canonical get-up campaign. It does not make the milestone decision, admit an
encyclopedia entry, authorize creature repair or guidance, remove the material
sagittal guide, generalize to another morphology, or establish a step, gait,
or walking.

The source contract is:

```text
data/lab/campaigns/BR13_canonical_get_up_promotion_campaign_v1.json
```

The campaign owns five programs, two fresh-process replicates per program,
ten production-attested evidence capsules, one complete certification report,
and one detached report receipt.

## Evidence roles

| Role | Cells | Programs | Assertions per replicate | Assertions across two replicates |
|---|---|---:|---:|---:|
| Milestone | BR13.0, BR13.2, BR13.4 | 3 | 57 | 114 |
| Supplementary | none | 0 | 0 | 0 |
| Integrity | BR13.1, BR13.3 | 2 | 33 | 66 |
| Total | BR13.0-BR13.4 | 5 | 90 | 180 |

BR13.0 pins the symmetry-collapsed quadruped profile, semantic prone and
stance observations, successful phase order, material guide disclosure,
three-seed set, and matched-control requirement.

BR13.2 pins the work and reserve preflight and the actuator, mechanical,
contact-dissipation, guide-work, and energy-residual accounting boundary.

BR13.4 is the physical milestone cell. It runs seeds `13001`, `13002`, and
`13003` as active/zero-command pairs in live Godot/Jolt worlds. Every active
world must complete the exact prone-to-stance sequence with at least `0.35 m`
whole-system COM rise, finite digest-bound paired torque, complete execution
receipts, an exclusive recovery-to-stance handoff, closed energy accounting,
and the declared guide bounds. Every control must remain prone with zero
commands and work.

BR13.1 and BR13.3 remain integrity-only. They prove timeout, revocation,
forbidden-contact, scaffold, claim, anatomy, seed, and guidance failures close
the boundary; they cannot substitute for physical success.

## Prerequisites

Use PowerShell 7.5 or later from the repository root:

```powershell
cd <repo>
```

The worktree must be completely clean and committed. The operator refuses to
start or finish across dirty or changed source.

The expected engine is:

```text
<godot-dir>\Godot_v4.7-stable_mono_win64.exe
```

It must identify as:

```text
4.7.stable.mono.official.5b4e0cb0f
```

The production attestation root must already have an active key created by
the repository's attestation initializer. The root and detached receipts live
outside the repository and outside the evidence directory.

## Preflight

Run the non-evidentiary preflight first:

```powershell
.\scripts\run_br13_canonical_get_up_certification.ps1 -PreflightOnly
```

Preflight verifies:

- clean committed source;
- exact campaign and schema;
- exact five-program order, roles, tests, and assertion counts;
- frozen BR1 report-v2 inventory hash and count;
- complete declared source-inventory closure;
- engine path, version, and SHA-256 identity; and
- production attestation-root availability.

Preflight creates no certification report, evidence capsule, decision, or
knowledge entry.

## Certification

Run:

```powershell
.\scripts\run_br13_canonical_get_up_certification.ps1
```

The operator:

1. records one clean commit and exact sorted source-byte inventory;
2. launches each declared program twice through the containment host into a
   fresh Godot target process;
3. retains every declared run without cherry-picking;
4. copies raw harness report, engine log, and transcript into a new capsule;
5. records ordered assertion labels, non-assertion observation lines, target
   process identity, and run window;
6. builds and production-attests ten complete evidence bundles;
7. reconciles both replicas for each program;
8. reopens and verifies every bundle, receipt, metric file, source inventory,
   artifact hash, and process witness;
9. writes `br13_certification_report.json`; and
10. authenticates that immutable report in the separate detached BR13 report
    domain.

The live BR13.4 replicas are expected to dominate runtime because each
replicate runs three active worlds and three same-state controls.

## Required successful accounting

```text
programs: 5/5
replicates: 2 per program
bundles: 10/10
assertions: 180/180
milestone assertions: 114/114
integrity assertions: 66/66
unexpected engine errors: 0
complete-campaign readback: true
```

PID reuse is allowed only after a completed non-overlapping target-process
invocation and must be recorded. A recycled numeric PID is not treated as
proof that a process was reused.

## Outputs

The console prints:

- certification ID;
- source commit and campaign identity;
- report path and SHA-256;
- detached receipt path and SHA-256;
- total, milestone, and integrity accounting; and
- the explicit statement that a milestone decision remains separate.

The report and capsule tree are written under the operator-created session
directory in the system temporary evidence area. The detached receipt remains
under the production trust root, not inside that evidence tree.

## Acceptance boundary

A successful certification recommends acceptance of exactly:

```text
constrained_planar_get_up
```

for the exact guided, symmetry-collapsed, fixed-morphology fixture.

It does not establish:

- free-3D or unscaffolded recovery;
- independent left/right control of four limbs;
- morphology, actuator, terrain, foot, endurance, or physics-setting
  transfer;
- absence or general measurement of guide reaction;
- per-contact, per-body, per-foot, per-toe, or center-of-pressure load
  allocation;
- general standing, balance, bracing, or fall arrest;
- a step, weight-transfer maneuver, gait, candidate walking, or walking;
- an accepted encyclopedia entry, repair rule, or automatic creature
  guidance.

Certification alone changes none of those states. A separate milestone
decision must cite the exact certification report and detached receipt.
