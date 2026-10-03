# BR9 Existing-Contact Brace Certification Operator

## Purpose

This runbook executes the promotion-grade BR9 campaign. It creates evidence
for the exact scaffold-constrained existing-contact pitch-arrest claim. It
does not create a milestone decision, admit knowledge, authorize guidance, or
claim free-3D bracing.

## Fixed campaign

The operator consumes:

```text
data/lab/campaigns/BR9_existing_contact_brace_promotion_campaign_v1.json
```

The campaign contains:

| Role | Programs | Assertions per replicate | Two-replicate assertions |
|---|---:|---:|---:|
| Milestone: BR9.0–BR9.3 | 4 | 39 | 78 |
| Integrity: BR9.4 | 1 | 21 | 42 |
| Total | 5 | 60 | 120 |

It requires two fresh target processes for every program, ten retained
production-attested capsules, complete readback, and one separately
authenticated final report.

## Prerequisites

Use PowerShell 7.5 or newer from the repository root:

```powershell
cd <repo>
```

The repository must be clean. The local production trust root under
`%LOCALAPPDATA%\SporeSpore\LabTrust` must already contain the active
32-byte HMAC key initialized by the existing lab-attestation operator.

The exact Godot executable is:

```text
<godot-dir>\Godot_v4.7-stable_mono_win64.exe
```

Its required build identity and SHA-256 are hard-coded in the operator.

## Preflight

Run:

```powershell
pwsh -NoProfile -File .\scripts\run_br9_existing_contact_brace_certification.ps1 -PreflightOnly
```

Expected terminal marker:

```text
BR9 preflight=pass
```

Preflight checks the clean commit, campaign contract, exact source closure,
unchanged BR1 62-test inventory, Godot identity, production trust readiness,
and operator dependencies. It creates no campaign evidence.

## Certification

Run:

```powershell
pwsh -NoProfile -File .\scripts\run_br9_existing_contact_brace_certification.ps1
```

Expected terminal marker:

```text
BR9 certification=pass
```

The operator prints:

- the certification ID;
- the clean source commit;
- 5/5 programs and 10/10 bundles;
- 120/120 assertions;
- 78/78 milestone assertions;
- 42/42 integrity assertions;
- the final report path and SHA-256; and
- the detached report-receipt path and SHA-256.

Evidence is installed outside the repository under:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR9\<certification_id>\
```

The final report is:

```text
br9_certification_report.json
```

## Failure behavior

The operator fails closed when:

- the worktree is dirty;
- the commit changes during the campaign;
- the BR1 inventory changes;
- any declared source byte changes;
- any program, replicate, assertion, or raw artifact is missing;
- target-process containment is incomplete;
- a bundle lacks a valid production receipt;
- replicate assertion labels do not match exactly;
- report capability constraints are weakened; or
- the detached report cannot be authenticated.

Failed work remains outside the repository and cannot create a decision.

## Interpretation

A passing campaign is eligible for a separate bounded milestone decision. It
is not acceptance by itself.

The strongest allowed interpretation is:

> In the exact BR7-derived sagittal scaffold, the declared active controller
> begins on the first post-impulse observation and uses only already-bearing
> contacts and finite paired joint actuation to reduce pitch momentum and
> excursion relative to the paired no-brace control.

It is not evidence for a catch step, free-3D bracing, general standing, fall
arrest, getting up, gait, walking, per-foot measured load, creature repair, or
automatic guidance.
