# Locomotion encyclopedia

This encyclopedia records what LoColemotion has actually learned from sealed
experiments. It does not preserve historical walking claims, visual
impressions, or tuning folklore.

The current claim boundary remains deliberately narrow. Accepted milestones
now cover the evidence system, bounded articulated observation, exact
engine/contact truth, joint-actuator truth, basic loaded-pad truth,
rail-constrained vertical support, scaffold-constrained planar stance, and
observer-only early loss-of-viability detection. They do **not** establish
free 3D standing, an executed brace, fall arrest, getting up, gait, or
walking.

The governing architecture and its alternatives are recorded in
[ADR-001](../adr/ADR-001_EVIDENCE_FIRST_LOCOMOTION_RESEARCH_PIPELINE.md).
The catalog now holds exactly 32 accepted observation-only entries: one L0
baseline, nine BR3A observations/constraints, three BR3B observations, eight
BR4 observations, three BR6A observations, four BR7 observations, and four
BR8 observations. Every current `minimal_repair_rules` array is empty, and
every family-specific guidance policy denies automatic application and
automatic creature guidance. Legacy gait and walking tests are regression
coverage only and are never eligible evidence for an encyclopedia claim.

The first human protocol card is
[L0.0 stationary gravity-off](l0/stationary_gravity_off.md), now backed by
that accepted machine entry. A protocol and a draft define what a result
would mean; only an admitted entry is evidence that the result occurred.

## Two linked representations

Every finding has two forms:

- a machine-readable, append-only entry under
  `data/lab/knowledge/entries/`; and
- a human explanation under this directory.

The machine entry pins the exact run, expanded experiment, manifest, summary,
and checksum hashes. A canonical admission digest also binds the authored
claim and repair text, so an in-place edit is detectable. The human entry
explains mechanism, equations, applicability, failure boundaries, parameter
effects, and the smallest safe repair.

## Claim statuses

| Status | Meaning | May drive automatic creature repair? |
|---|---|---|
| `development_observation` | Structurally valid evidence from a non-promotable context, including a dirty source tree | No |
| `accepted` | Independently valid, promotable evidence satisfying the current replication and source gates | Only with a separately authorized non-empty repair rule; none currently exist |
| `refuted` | Later evidence contradicted the claim | No |
| `retired` | Superseded or no longer applicable under the current engine/contract version | No |

An accepted entry is never edited in place. A correction appends a new entry
and lists the old entry ID in `supersedes`. Refuting or retiring accepted
guidance requires promotion-grade evidence too; a dirty development run cannot
silently disable a rule used by automatic repair.

An `accepted` entry requires a completed bundle whose independent validator
reports `can_promote == true`. In practical terms, that means clean source
identity, parent-owned fresh-process execution, sealed configuration and
artifacts, successful replay/metric validation, and whatever replication
matrix the experiment requires. A passing physical result from a dirty tree or
direct in-process run may be recorded only as a
`development_observation`.

## Operator procedure

The preferred operator path is the fail-closed bootstrap wrapper. Use
**PowerShell 7** (`pwsh`), not legacy Windows PowerShell 5.1, from the
repository root:

```powershell
Set-Location "<repo>"
.\scripts\run_locomotion_bootstrap.ps1
```

In one sequential pipeline, the wrapper runs the hardened lab suite, launches
canonical L0.0 through the parent-owned fresh-process path, independently
audits the final bundle and its checksums, and performs a trace-only replay
with `simulation_steps=0`. It writes the operator transcripts, engine logs,
run bundle, and `bootstrap_report.json` beneath a timestamped directory under
`$env:TEMP\sporespore_locomotion_bootstrap`.

The default command validates evidence but admits no encyclopedia entry. To
request the optional L0.0 development observation, use the real
preregistered machine draft:

```powershell
.\scripts\run_locomotion_bootstrap.ps1 `
  -Seed 4242 `
  -KnowledgeDraft "res://data/lab/knowledge/drafts/L0_0_stationary_gravity_off.development.json"
```

This admission variant is intentionally narrow. It succeeds only for a dirty,
non-promotable development bundle whose L0.0 physical, configuration, bundle,
checksum, and replay checks have passed. It always requests
`development_observation`, generates a new append-only output name when none
is supplied, and refuses to downgrade promotion-grade evidence. Neither
wrapper form establishes standing, bracing, fall arrest, getting up, gait, or
walking.

The 2026-07-19 dirty-tree checkpoint passed all 39 scripts and 632 assertions,
published and independently validated a 61-frame canonical L0.0 development
bundle, and replayed its 61 frames and one event with `simulation_steps=0`.
Its source-state gate failed solely on `DIRTY_WORKTREE`, exactly as required.

Formal BR1 certification then passed on 2026-07-21 through
`scripts/run_br1_certification.ps1` (session `br1_20260721T002052Z_40077d42`,
commit `2f74821`): the pinned 45-test suite, all 7 clean canonical cells
twice in fresh processes, production HMAC receipts for every bundle,
independent validation, zero-physics replay, same-seed replicate comparison,
a final readback sweep, and a detached attested report. Its terminal marker,
`BR1 certification=pass`, is the clean certification signal that
distinguishes it from a development checkpoint, and the first `accepted`
entry was admitted from its L0.0 evidence.

### Manual component procedure

Use these commands to diagnose one stage or understand the wrapper's parts;
they are not a substitute for the complete preferred flow. Define the Godot
executable first:

```powershell
$godot = "<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe"
```

Run every lab test sequentially. Do not parallelize physics tests:

```powershell
.\scripts\run_lab_tests.ps1 `
  -Godot $godot `
  -Pattern "test_lab_*.gd" `
  -LogRoot (Join-Path $env:TEMP "sporespore_lab_tests")
```

The command must return exit code `0`, and its final `report.json` must show
zero failed tests.

Then produce evidence with the canonical parent launcher:

```powershell
& $godot --headless --path . `
  --log-file "$env:TEMP\sporespore_l0_parent.log" `
  --script "res://scripts/lab/launch_lab.gd" -- `
  --experiment-spec "res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres" `
  --seed 42 `
  --observer "full_contacts_v1" `
  --output-root "$env:TEMP\sporespore_lab"

$labExitCode = $LASTEXITCODE
Write-Host "Lab exit code: $labExitCode"
```

The canonical launcher reserves a unique `.partial` directory, spawns a fresh
Godot child, lets the child prepare but not publish candidate evidence, waits
for child termination, validates the candidate, creates the checksum set, and
performs the final atomic rename. Only the parent can produce the completed
bundle path printed as `LAB artifacts=<path>`.

Interpret the result at claim-sized scope:

- Exit `0` means evidence validity, this experiment's physical gate, and its
  promotion gate passed. It does not mean the body stood or walked.
- Exit `2` means the physical or promotion gate did not pass. A dirty source
  tree should be expected to end here even if the narrow physical hypothesis
  passed.
- Exit `3` means evidence/finalization invalidity. Do not admit the result.
- Exit `4` means invalid invocation or configuration.
- Exit `5` means a controlled abort. Diagnose the retained `.partial`
  artifacts; do not rename or hand-publish them.

Replay the completed bundle without executing physics:

```powershell
$bundle = "$env:TEMP\sporespore_lab\<completed-run-id>"

& $godot --headless --path . `
  --log-file "$env:TEMP\sporespore_l0_replay.log" `
  --script "res://scripts/lab/launch_lab.gd" -- `
  --experiment-spec "res://data/lab/experiments/L0_4_trace_playback_v1.tres" `
  --replay-bundle $bundle

if ($LASTEXITCODE -ne 0) {
  throw "Trace-only replay failed with exit code $LASTEXITCODE"
}
```

The successful line must include
`LAB replay=pass simulation_steps=0`. The direct
`scripts/lab/run_lab.gd` entry point is useful for development diagnostics but
does not satisfy fresh-process promotion requirements.

After the L0.0 bundle has been validated and replayed, use its preregistered
draft at
`data/lab/knowledge/drafts/L0_0_stationary_gravity_off.development.json`.
Use `knowledge_draft.template.json` only when preregistering a different
experiment, replace every placeholder before the run, and keep the claim no
broader than that experiment. To record a structurally valid but
non-promotable L0.0 bundle manually:

```powershell
$runId = Split-Path -Leaf $bundle

& $godot --headless --path . `
  --log-file "$env:TEMP\sporespore_knowledge_admission.log" `
  --script "res://scripts/lab/admit_knowledge.gd" -- `
  --bundle $bundle `
  --draft "res://data/lab/knowledge/drafts/L0_0_stationary_gravity_off.development.json" `
  --output "res://data/lab/knowledge/entries/l0_stationary.seed-4242.$runId.json" `
  --status "development_observation"

if ($LASTEXITCODE -ne 0) {
  throw "Knowledge admission was blocked with exit code $LASTEXITCODE"
}
```

The output filename must be a new flat JSON file directly under `entries/`;
the writer refuses overwrite. Do not change `--status` to `accepted` merely
because an L0 metric looks good. The admission path revalidates the bundle and
will accept that status only when the referenced evidence is promotion-grade.
The catalog's first entry was created through exactly this command on
2026-07-21, with `--status accepted`, from the certified BR1 campaign's
L0.0 replicate-1 bundle.

## Required questions for every entry

1. What exact claim does the evidence support?
2. Which fixture, engine boundary, observer, and parameter range produced it?
3. Which quantities were measured, which were derived, and which were
   unavailable?
4. What physical mechanism explains the result?
5. What must remain true for the result to generalize?
6. What does the evidence explicitly **not** establish?
7. What is the smallest creature change suggested by the result?
8. Which identity-bearing creature features does that change preserve?

## Retrieval and repair rules

Knowledge queries return accepted entries by default. Development observations
require explicit opt-in and remain labeled. A repair candidate produced from a
development observation always has
`automatic_application_allowed = false`.

The query path reopens the referenced bundle, validates it, and compares the
entry's run, experiment, expanded-spec, manifest, summary, checksum, and metric
provenance before returning a usable rule. Candidate generation repeats that
check instead of trusting a caller-provided `claim_status`. If any catalog
entry is malformed or the append-only supersession graph is ambiguous, the
catalog returns no usable candidates until the integrity problem is fixed.

The intended repair loop is:

```text
reported symptom
  -> find accepted entries matching the morphology and failure signature
  -> rank the smallest applicable changes
  -> preserve authored identity constraints
  -> run the relevant atomic and integration experiments
  -> keep, reject, or refine the change from new evidence
```

This is how experiments become useful to the full creature authoring
experience without forcing every creature into one biped or quadruped gait
template.

For the exact launcher exit-code table, bundle inspection checklist, and
current verification boundary, see the
[BR1/L0 section of the repository README](../../README.md#br1l0-locomotion-evidence-lab).
