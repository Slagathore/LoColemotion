# BR7 planar-stance certification operator

`scripts/run_br7_planar_certification.ps1` is the promotion-grade operator for
`BR7_PLANAR_MULTI_CONTACT_STANCE`.

It executes this fixed five-program campaign twice:

| Cell | Evidence role | Program | Assertions per replicate |
|---|---|---|---:|
| BR7.0 | milestone | two-contact vertical-force and pitch-moment allocation | 9 |
| BR7.1 | milestone | unilateral and Coulomb-friction feasibility | 8 |
| BR7.2 | milestone | support/capture segment and support-loss supervision | 10 |
| BR7.3 | milestone | live two-leg planar stance and support removal | 13 |
| BR7.4 | integrity | digest, assistance, measurement, and claim containment | 12 |

The complete campaign requires:

- 5 programs and 10 fresh target-process invocations;
- 10 production-attested evidence capsules;
- 80 milestone assertions across two replicates;
- 24 integrity assertions across two replicates; and
- 104 total passing assertions.

BR7.4 cannot replace a milestone program. It is retained so a report cannot
hide the guide, invent a measured per-foot channel, omit the support-loss
event, or broaden the result into standing or locomotion.

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
pwsh -File .\scripts\run_br7_planar_certification.ps1 -PreflightOnly
```

Expected terminal state:

```text
BR7 preflight=pass non_promotable=true programs=5 ...
```

Preflight runs no physics, writes no evidence, and creates no decision.

## Full campaign

From the repository root:

```powershell
pwsh -File .\scripts\run_br7_planar_certification.ps1
```

On success, the operator prints:

- the certification ID;
- the exact report path and SHA-256;
- the detached report-receipt path and SHA-256;
- 5/5 program, 10/10 bundle, and 104/104 assertion accounting; and
- `milestone_decision=required`.

Evidence is written outside the repository under:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR7\<certification-id>\
```

The detached report receipt is stored under the BR7-specific report domain.
The report is not itself a milestone decision.

## Certified boundary

The report can establish only the exact BR7.0–BR7.3 source-pinned program
scopes. The live result is scaffold-constrained planar height/pitch stance and
support-loss detection.

The `Generic6DOFJoint3D` guide is material and remains explicit:

- sagittal X/Y translation and pitch are released;
- out-of-plane translation, roll, and yaw are locked; and
- every guide motor and spring is disabled.

The fixture uses two ordinary distal contacts and four paired finite joint
actuators. Aggregate vertical support and pitch wrench come from whole-system
momentum reconstruction. The allocator's left/right command shares are not
measured per-foot loads.

## Non-effects

The operator never:

- creates or edits a milestone decision;
- admits encyclopedia knowledge;
- enables repair or automatic creature guidance;
- establishes measured per-contact, per-foot, or per-toe load allocation;
- establishes absent, negligible, or measured out-of-plane guide reaction;
- establishes free 3D standing or unconstrained balance; or
- claims bracing, fall arrest, getting up, gait, or walking.

The detached verifier rechecks these boundaries against the exact campaign,
source inventory, every capsule, and the final report.
