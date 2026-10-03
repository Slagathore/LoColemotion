# BR3B L3 certification operator

`scripts/run_br3b_l3_certification.ps1` is the promotion-grade operator for
`BR3B_L3_BASIC_LOADED_FOOT_TRUTH`.

It runs the exact three-program campaign twice:

| Cell | Program | Assertions per replicate |
|---|---|---:|
| L3.0 | centered loaded-pad normal transmission | 14 |
| L3.1 | loaded-pad shear breakaway | 13 |
| L3.2 | loaded-pad rocking edge | 16 |

The complete campaign therefore requires:

- 3 programs;
- 2 fresh target-process replicates per program;
- 6 production-attested evidence capsules; and
- 86 passing assertions.

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
pwsh -File .\scripts\run_br3b_l3_certification.ps1 -PreflightOnly
```

Expected terminal state:

```text
BR3B preflight=pass non_promotable=true programs=3 ...
```

Preflight runs no physics and creates no evidence or decision.

## Full campaign

From the repository root:

```powershell
pwsh -File .\scripts\run_br3b_l3_certification.ps1
```

On success, the operator prints:

- the certification ID;
- the exact report path and SHA-256;
- the detached report-receipt path and SHA-256;
- 3/3 program, 6/6 bundle, and 86/86 assertion accounting; and
- `milestone_decision=required`.

Evidence is written outside the repository under:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR3B\<certification-id>\
```

The detached report receipt is written to the production trust store under the
BR3B-specific report domain.

## Non-effects

The operator never:

- creates or edits a milestone decision;
- admits encyclopedia knowledge;
- enables repair or automatic creature guidance;
- establishes per-foot load allocation;
- establishes an articulated load-bearing limb; or
- claims standing, bracing, recovery, gait, or walking.

Those boundaries are validated again when the detached report is verified.
