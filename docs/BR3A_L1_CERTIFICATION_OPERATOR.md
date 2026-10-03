# BR3A L1 certification operator

This document is the exact operator path for producing the promotion-grade
BR3A L1 evidence family. The resulting certification report is evidence for a
later human milestone decision. It is not itself an acceptance decision, an
encyclopedia admission, a creature-guidance authorization, or locomotion
proof.

The first complete passing campaign is
`br3a_20260723T050201Z_109cc664` at certified source `109cc664`. Its evidence
identity and Cole's later bounded acceptance are recorded in
`docs/BR3A_L1_MILESTONE_DECISION_REVIEW.md` and append-only decision
`BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1`.

## What the campaign certifies

The campaign runs 19 declared programs twice, in 38 fresh Godot target-process
invocations:

| Evidence role | Programs | Assertions per replicate | Assertions across two replicates |
|---|---:|---:|---:|
| L1.0-L1.7 milestone evidence | 16 | 236 | 472 |
| L1.8 plus the draft guard | 2 | 43 | 86 |
| Commissioning-registry integrity | 1 | 13 | 26 |
| Total | 19 | 292 | 584 |

Every invocation produces a sealed evidence capsule with the exact harness
report, engine log, transcript, structured assertion/observation record,
source inventory, checksums, and detached generic publication receipt. The
final report independently re-reads all 38 capsules and receives a separate,
domain-bound detached BR3A report receipt.

L1.8 is supplementary. It constrains instrumentation: raw predicted impulses
from several same-body manifolds are not additive external load. Whole-system
momentum reconstruction is authoritative only for the closed measured system;
the campaign establishes no per-foot or per-contact allocation method.

## Prerequisites

Use PowerShell 7.5 or newer in the repository root. The operator requires the
strict string-preserving JSON date mode introduced in PowerShell 7.5:

```powershell
cd <repo>
```

The operator pins this exact engine binary and SHA-256 identity:

```text
<godot-dir>\Godot_v4.7-stable_mono_win64.exe
sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4
```

Do not substitute `Godot_v4.7-stable_mono_win64_console.exe`. On Windows that
small console launcher starts the separate runtime executable, so the launched
PID/hash and `OS.get_executable_path()` do not identify the same process. The
campaign launches the real runtime directly; its contained target PID, live
executable path, and pinned executable bytes are therefore one identity.

The full campaign requires:

1. all campaign source and documentation changes committed;
2. no tracked, staged, modified, deleted, or untracked repository files;
3. the frozen 62-test BR1 report-v2 inventory still matching
   `sha256:f22a43c3125d2a87c3f4b154af40d5e99a2a9dd1da35e159825e79635357605e`;
4. the existing production lab trust root initialized under
   `%LOCALAPPDATA%\SporeSpore\LabTrust\v1`; and
5. enough time for 38 physics/test invocations plus capsule and report
   attestation.

The campaign fails closed if the source tree changes at any point. It never
stashes, resets, deletes, or rewrites repository work.

## Safe preflight

Run this before committing or starting physics:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\run_br3a_l1_certification.ps1 -PreflightOnly
```

Expected success begins with:

```text
BR3A preflight=pass non_promotable=true programs=19 ...
```

Preflight validates the campaign contract, live source-closure construction,
BR1 inventory pin, and Godot binary. It deliberately permits a dirty worktree
so it can be used during development. It runs no physics, creates no evidence
bundle or receipt, and cannot promote anything.

## Full campaign

First verify the source is committed and clean:

```powershell
git status --short --branch
```

The status output must contain only the branch line, with no file entries.
Then run:

```powershell
pwsh -NoLogo -NoProfile -File .\scripts\run_br3a_l1_certification.ps1
```

On success, the operator prints:

- `programs=19/19`;
- `bundles=38/38`;
- `assertions=584/584`;
- the number of fresh target-process invocations and any recorded Windows PID
  recycle events;
- the absolute final report path and SHA-256;
- the detached report-receipt path and SHA-256; and
- `milestone_decision=required accepted_knowledge=0 automatic_guidance=false`.

Windows may reuse a numeric PID after a process exits. The campaign therefore
proves 38 fresh invocations with start/end windows. Reused PIDs are permitted
only when the prior invocation is complete, the windows do not overlap, and
the recycle event is counted in the final report.

## Artifact locations

Evidence is written outside the Git repository:

```text
%LOCALAPPDATA%\SporeSpore\LabEvidence\BR3A\<certification_id>\
```

The directory contains:

```text
source_inventory.json
raw\
bundles\
attestation_logs\
br3a_certification_report.json
```

Generic per-bundle receipts and the final BR3A report receipt remain detached
under the production trust root:

```text
%LOCALAPPDATA%\SporeSpore\LabTrust\v1\receipts\
%LOCALAPPDATA%\SporeSpore\LabTrust\v1\br3a_certification_reports_v1\receipts\
```

Receipts are append-only. The operator never overwrites an existing receipt or
certification directory.

## Independent report verification

Use the exact report path and certification ID printed by the successful run:

```powershell
& '<godot-dir>\Godot_v4.7-stable_mono_win64.exe' `
  --headless `
  --path '<repo>' `
  --script res://scripts/lab/br3a_certification_report_attestation_cli.gd `
  -- `
  --mode verify `
  --report '<absolute-report-path>' `
  --certification-id '<certification-id>' `
  --require-promotion
```

A successful verification returns a JSON result prefixed with
`BR3A_REPORT_ATTESTATION result=` and includes `ok: true`,
`trust_mode: production`, the exact report digest, and the receipt digest.

The verifier independently checks:

- the live campaign, BR1 inventory, engine executable, and repository paths;
- the exact complete source closure and every current source byte;
- all 38 generic bundle receipts and their sealed artifact indexes;
- manifest, capsule, metrics, harness, engine-log, transcript, and source
  inventory cross-hashes;
- assertion labels and non-assertion observation lines re-extracted from each
  raw transcript;
- process identities, invocation windows, PID recycling, and full role/count
  accounting; and
- the no-locomotion, no-allocation, no-acceptance claim boundary.

## Failure behavior

Any failed, timed-out, incomplete, dirty-source, missing-artifact,
hash-mismatch, receipt, reconciliation, or process-containment condition stops
the campaign. If a certification directory was already reserved, the operator
writes `br3a_certification_failure.json` inside it and retains all completed
raw evidence and receipts for forensic review. It does not select a better
replicate or silently resume into the same certification identity.

After fixing code, commit the change and start a new complete campaign. A
partially completed campaign cannot be promoted.

## Human decision boundary

Even a fully passing, detached, production-trusted report leaves these states
unchanged until Cole reviews an explicit milestone-decision candidate. Cole
subsequently accepted the bounded L1.0-L1.7 milestone, and the decision
deliberately left every state below unchanged:

```text
BR3A accepted knowledge entries: 0
Automatic creature guidance: false
Standing: false
Bracing: false
Fall arrest: false
Getting up: false
Walking: false
```

Do not rename experimental tests, mutate BR1 report-v2, admit development
drafts, or make controller/repair code consume BR3A conclusions as part of the
campaign operation.
