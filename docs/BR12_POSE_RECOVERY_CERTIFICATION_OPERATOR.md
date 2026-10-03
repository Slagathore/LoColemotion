# BR12 Pose and Recovery-Feasibility Certification Operator

This operator builds the promotion-grade BR12 evidence family. It never
creates a milestone decision, admits encyclopedia knowledge, executes a
recovery controller, or authorizes creature guidance.

## Prerequisites

- Windows PowerShell 7.5 or newer.
- The exact pinned Godot 4.7 Mono executable:
  `<godot-dir>\Godot_v4.7-stable_mono_win64.exe`.
- An initialized production lab-attestation key.
- A clean committed repository.
- The unchanged 62-test BR1 v2 inventory.

The operator refuses a dirty tree, a changed source byte, a different engine
hash or version, an incomplete campaign, a failed assertion, a reused
overlapping target process, a missing bundle, a failed receipt, or a changed
tree at final report time.

## Non-promotable preflight

From the repository root in PowerShell:

```powershell
& .\scripts\run_br12_pose_recovery_certification.ps1 `
  -PreflightOnly `
  -Godot "<godot-dir>\Godot_v4.7-stable_mono_win64.exe"
```

Preflight validates the engine, campaign schema, BR1 inventory guard, and
complete source closure. It runs no physics, writes no evidence bundle or
report, and creates no decision.

## Promotion campaign

After committing all BR12 promotion-family files and confirming a clean tree:

```powershell
& .\scripts\run_br12_pose_recovery_certification.ps1 `
  -Godot "<godot-dir>\Godot_v4.7-stable_mono_win64.exe"
```

Expected terminal accounting:

```text
BR12 certification=pass
BR12 programs=5/5 bundles=10/10 assertions=150/150
BR12 milestone=BR12.0,BR12.1,BR12.2,BR12.3 assertions=122/122 supplementary=0/0 integrity=28/28
BR12 milestone_decision=required accepted_knowledge=0 automatic_guidance=false
```

The evidence root is:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR12\<certification_id>\
```

The final report is:

```text
br12_certification_report.json
```

Its detached production receipt is stored under the BR12-specific report
attestation domain:

```text
%LOCALAPPDATA%\SporeSpore\LabTrust\v1\br12_certification_reports_v1\receipts\
```

## Required review after a pass

Before any milestone decision:

1. Independently verify the final report and detached receipt.
2. Confirm all ten declared bundles remain present and valid.
3. Confirm the report binds the exact clean source commit and campaign.
4. Confirm BR12.4 remains integrity-only.
5. Copy the report's claim boundary verbatim into the decision review.
6. Preserve every negative capability field, especially the absence of
   controller, actuation, contact creation, physical recovery, stance handoff,
   repair, guidance, getting up, gait, and walking.

Any later observation-only knowledge admission must be separately authorized,
must bind the accepted decision and all certified evidence, and must use empty
repair-rule arrays.
