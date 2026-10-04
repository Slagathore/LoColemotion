# What the evidence says

**SDK1 completed 20/20 bounded milestones on 2026-10-03.** The original
[clean-source receipt](receipts/sdk1-clean-readiness.json) reports zero missing,
contradicted or invalid SDK1 proofs. It also records the broader program at
19/25 and leaves publication and full-program release authority false.

That distinction matters. This page is an entry point into retained evidence,
not a replacement for its declarations, evaluators or dependency closure.

## Ten places to start

| ID | Record | What to look for |
| --- | --- | --- |
| `sdk1` | [Milestone receipt](receipts/sdk1-clean-readiness.json) | All twenty dispositions, clean source identity and deferred gates |
| `package` | [Package closure](../sdk/release/sdk1_package_acceptance_closure_v1.json) | Two identical source packages, external consumption, 83 exports and corruption controls |
| `turning` | [R23D78](../sdk/turning/r23d78_production_route_three_engine_turning_validation_closure_v1.json) | Nine declared cells; exact seed 23199; three engines |
| `recovery` | [R10DH adoption](../sdk/recovery/r10dh_release_gate_adoption_v2.json) | Six held-out Godot/Jolt cells and the narrow earned scope |
| `recovery-negative` | [Recovery Panel C](../sdk/discovery/recovery_panel_c_closure_v1.json) | Four valid worlds, two positive and two negative cells, zero positive pairs |
| `recovery-invalid` | [Original R10DH production attempt](../sdk/recovery/r10dh_production_ghost_closure_v1.json) | Worker completion followed by an independent reader refusal |
| `qualification` | [R10DH v2 qualification](../sdk/recovery/r10dh_development_qualification_v2.json) | Exact source/dependency key, stages and receipts before physics |
| `qualification-refusal` | [Panel E entry in the support matrix](../sdk/release/quadruped_support_matrix.json) | `recovery_prone_neighborhood_panel_e_gate_refusal`: zero worlds, zero steps, retired unopened cells |
| `explorer` | [Explorer closure](../sdk/explorer/showcase_closure_v1.json) | Isolated interface validation and the origin of the browser replay |
| `measurement` | [MuJoCo VH4](../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json) | Completed-step force observation; read alongside the [integration comparison](../sdk/docs/ENGINE_INTEGRATION_COMPARISON.md) |

## What is available

| Layer | Contents | Availability |
| --- | --- | --- |
| This repository | Source records, a ten-record index, five original receipts totaling about 25 KB, and an 8.1 MB derived pose replay | Included |
| A larger curated proof pack | Selected raw traces, manifests and their dependency closure | Not published; storage and distribution still need to be chosen |
| Full research archive | Roughly 517 GB by the owner's estimate; historical runs, failures, traces and runtime/package records | External; not a clone or onboarding requirement |

The machine-readable [index](EVIDENCE_INDEX.json) gives each selected local file
its SHA-256 and byte count. Retained receipts and replay data use exact raw bytes.
Selected exported SDK source files have Git LF content and historical Windows
CRLF checkouts; the index lists both exact byte identities explicitly. This recognizes
a checkout encoding, not a newly qualified scientific dependency. The integration
prose uses LF-normalized text so Windows and Unix checkouts agree.
External entries preserve archive-relative locations,
hashes, sizes and pointers into their source records. `download_url: null` means
the bytes are not downloadable here. The selected artifacts do not form the full
transitive dependency closure of a campaign.

The five included receipts are byte-for-byte copies. Historical machine paths
inside them remain unchanged. The initial source export and this publication
curation have [separate provenance records](PUBLICATION_PROVENANCE.json).

## Check the bytes

Python 3.11+, from the repository root:

```powershell
python sdk/publication/evidence.py list
python sdk/publication/evidence.py show recovery-negative
python sdk/publication/evidence.py verify
```

A successful verification checks local sizes/hashes and selected bindings and
scope fields. It explicitly reports how many external artifacts were **not**
checked. It does not rerun experiments, independently reproduce SDK1, authenticate
private Git history or authorize new physics.

If you already have the archive, check just the indexed external files:

```powershell
python sdk/publication/evidence.py verify --archive-root 'C:/your/evidence-archive'
```

This never scans or downloads the full archive. Hash agreement establishes byte
identity against the checked-in records, not independent experimental truth.

## How to expand the public proof pack

Use a versioned manifest with a stable artifact URL, SHA-256, byte length, original
campaign/source identity, dependency list, result class and exact supported claim.
Keep raw evidence separate from viewing projections. Include a positive, a valid
negative and an invalid/refused case. Record unavailable dependencies explicitly.

Publish outside Git, then add exact artifact URLs to a new index revision after
checking downloads and hashes from a clean environment. Never replace a consumed
run or rewrite a failed record to simplify the presentation. The current index
does not implement fetching and does not promise that the full archive is public.

## Historical source copies

The [retained package-adoption source](sources/package_adoption_at_snapshot.py)
is an exact copy from the initial public snapshot, `c3643d35`. The index binds
its SHA-256 and records its original Git blob. Active tooling now expects the
LoColemotion repository; the consumed package evidence still refers to the
earlier source. Publication checks read this copy and never execute it.
