# BR8 brace-detection certification operator

`scripts/run_br8_brace_detection_certification.ps1` is the promotion-grade
operator for `BR8_EARLY_LOSS_OF_VIABILITY_DETECTION`.

It executes this fixed five-program campaign twice:

| Cell | Evidence role | Program | Assertions per replicate |
|---|---|---|---:|
| BR8.0 | milestone | static margin, support count, and impact deadline | 10 |
| BR8.1 | milestone | capture margin, boundary clock, mirroring, and delayed negative control | 8 |
| BR8.2 | milestone | immediate escalation and hysteretic release | 9 |
| BR8.3 | milestone | live passive impulse, tilt, and disappearing-support matrix | 13 |
| BR8.4 | integrity | digest, assistance, causal-channel, timing, and claim containment | 18 |

The complete campaign requires:

- 5 programs and 10 fresh target-process invocations;
- 10 production-attested evidence capsules;
- 80 milestone assertions across two replicates;
- 36 integrity assertions across two replicates; and
- 116 total passing assertions.

BR8.4 cannot replace a milestone program. It is retained so a report cannot
hide the guide, relabel an observer as a controller, alter causal reasons,
accept detection at rather than before static exhaustion, or broaden the
result into successful bracing or locomotion.

## Preconditions

Run the operator from PowerShell 7.5 or newer with a clean, committed
repository. It pins:

- the exact campaign bytes and source commit;
- the complete declared source inventory;
- the immutable 62-test BR1 inventory;
- the Godot 4.7 executable version and SHA-256;
- each raw engine log and transcript; and
- the ordered assertion labels across both replicates.

## Preflight

From the repository root:

```powershell
pwsh -File .\scripts\run_br8_brace_detection_certification.ps1 -PreflightOnly
```

Expected terminal state:

```text
BR8 preflight=pass non_promotable=true programs=5 ...
```

Preflight runs no physics, writes no evidence, and creates no decision.

## Full campaign

From the repository root:

```powershell
pwsh -File .\scripts\run_br8_brace_detection_certification.ps1
```

On success, the operator prints:

- the certification ID;
- the exact report path and SHA-256;
- the detached report-receipt path and SHA-256;
- 5/5 program, 10/10 bundle, and 116/116 assertion accounting; and
- `milestone_decision=required`.

Evidence is written outside the repository under:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR8\<certification-id>\
```

The detached report receipt is stored under the BR8-specific report domain.
The report is not itself a milestone decision.

## Certified boundary

The report can establish only the exact BR8.0–BR8.3 source-pinned program
scopes:

- exact static and linear-capture margin classifications;
- decomposed boundary and impact clocks;
- immediate `STAND`, `PRECARIOUS`, and `BRACE` escalation with hysteretic
  one-state-at-a-time release;
- a delayed `REACTION_TOO_LATE` negative control;
- capture-driven warning after one central horizontal impulse;
- warning before static exhaustion on one slowly tilting platform; and
- same-tick classification after one declared right-support removal.

Every live world retains the material `Generic6DOFJoint3D` guide:

- sagittal X/Y translation and pitch are released;
- out-of-plane translation, roll, and yaw are locked; and
- every guide motor and spring is disabled.

Detector and supervisor results are observations. They are not force, torque,
brace, step, foot-pin, root-rescue, creature-edit, or guidance commands.

## Non-effects

The operator never:

- creates or edits a milestone decision;
- admits encyclopedia knowledge;
- enables repair or automatic creature guidance;
- executes an existing-contact brace;
- creates a catch step or new support contact;
- establishes absent, negligible, or measured out-of-plane guide reaction;
- establishes free 3D standing or unconstrained balance; or
- claims fall arrest, getting up, gait, or walking.

The detached verifier rechecks these boundaries against the exact campaign,
source inventory, every capsule, and the final report.
