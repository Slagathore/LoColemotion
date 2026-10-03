# BR6A L4 certification operator

`scripts/run_br6a_l4_certification.ps1` is the promotion-grade operator for
`BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT`.

It runs the exact three-program campaign twice:

| Cell | Program | Assertions per replicate |
|---|---|---:|
| L4.0 | rigid-strut vertical-rail oracle | 12 |
| L4.1 | hinged-strut static load curve | 12 |
| L4.3 | two-link rail support, crouch/rise, and impulse recovery | 16 |

The complete campaign therefore requires:

- 3 programs;
- 2 fresh target-process replicates per program;
- 6 production-attested evidence capsules; and
- 80 passing assertions.

## Preconditions

Run from PowerShell 7.5 or newer. The repository must be clean and committed.
The operator pins:

- the exact campaign bytes;
- the complete declared source inventory;
- the immutable 62-test BR1 inventory;
- the Godot 4.7 executable version and SHA-256; and
- every program's ordered assertion labels across both replicates.

## Preflight

From the repository root:

```powershell
pwsh -File .\scripts\run_br6a_l4_certification.ps1 -PreflightOnly
```

Expected terminal state:

```text
BR6A preflight=pass non_promotable=true programs=3 ...
```

Preflight runs no physics and creates no evidence or decision.

## Full campaign

From the repository root:

```powershell
pwsh -File .\scripts\run_br6a_l4_certification.ps1
```

On success, the operator prints:

- the certification ID;
- the exact report path and SHA-256;
- the detached report-receipt path and SHA-256;
- 3/3 program, 6/6 bundle, and 80/80 assertion accounting; and
- `milestone_decision=required`.

Evidence is written outside the repository under:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR6A\<certification-id>\
```

The detached report receipt is written to the production trust store under the
BR6A-specific report domain.

## Certified boundary

The report can establish only the exact source-pinned, rail-constrained
articulated vertical-support observations. The `Generic6DOFJoint3D` rail is
material and remains explicit:

- Y translation is free;
- X/Z translation and all rotation are constrained;
- every rail motor and spring is disabled; and
- observed rail reaction is retained rather than dismissed.

Ordinary distal contact, paired finite joint commands, whole-system external
load reconstruction, rise work, and the declared disturbance remain part of
the evidence.

## Non-effects

The operator never:

- creates or edits a milestone decision;
- admits encyclopedia knowledge;
- enables repair or automatic creature guidance;
- establishes per-contact or per-foot load allocation;
- establishes free-root standing or balance;
- claims negligible scaffold dependence; or
- claims bracing, fall arrest, getting up, gait, or walking.

Those boundaries are validated again when the detached report is verified.
