# LoColemotion Evidence Archive

- **Archive date:** 2026-07-28
- **Status:** verified, non-destructive preservation complete
- **Repository head after recovery:** `659ec980803bcdae204830739f4e178b9a5abdb9`
- **Remote branch:** `origin/main`

## Durable evidence root

All 1,523 top-level LoColemotion roots in `C:\tmp` present during the recovery
were copied without deleting the originals to:

```text
<evidence-root>\temp-roots-2026-07-28
```

The relative path beneath `C:\tmp` is preserved. For example:

```text
<temporary-root>\sporespore_sdk_godot_jolt_c2_c5\20260728T025851327\transcript.log
```

maps to:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_sdk_godot_jolt_c2_c5\20260728T025851327\transcript.log
```

Historical evidence citations in the active documentation were mechanically
remapped to this durable root. The one remaining documentation reference that
combines the temporary root with a LoColemotion output name is an intentional
`-LogRoot` command for a future scratch run, not retained evidence.

## Preservation receipt

The full receipt is retained at:

```text
<evidence-root>\temp-roots-2026-07-28\PRESERVATION_RECEIPT.json
```

Receipt SHA-256:

```text
38ed73c8d32007257a930adf6629e5d27547e56aae42b03347e86ab6225220b1
```

Verified inventory:

| Check | Source | Durable copy |
|---|---:|---:|
| top-level roots | 1,523 | 1,523 |
| files | 141,950 | 141,950 |
| bytes | 7,640,133,106 | 7,640,133,106 |
| Robocopy failures | 0 | 0 |
| `report.json` / `transcript.log` files hashed | 3,639 | 3,639 |
| critical hash mismatches | 0 | 0 |

The receipt's final `verified` value is `true`. This is a preservation
certificate, not a scientific promotion receipt: it proves byte preservation
for the declared inventory and critical-file hash set, not that every archived
development run passed its experiment.

## Post-snapshot delta archive

The original snapshot covered all 1,523 `sporespore*` roots present on
2026-07-28. A 2026-07-30 comparison found 23 additional roots created after
that snapshot. They were copied non-destructively to:

```text
<evidence-root>\temp-roots-delta-2026-07-30
```

The verified receipt is:

```text
<evidence-root>\temp-roots-delta-2026-07-30\PRESERVATION_RECEIPT_V2.json
```

Receipt SHA-256:

```text
e9c8fdd13601178abfe2ef54455a5ff80dd3a04b6b3468c22b76d65b6e71ad1e
```

Verified delta inventory:

| Check | Source | Durable copy |
|---|---:|---:|
| top-level roots | 23 | 23 |
| files | 63 | 63 |
| bytes | 6,378,665 | 6,378,665 |
| all-file SHA-256 checks | 63 | 63 |
| hash mismatches | 0 | 0 |
| Robocopy failures | 0 | 0 |
| junctions recorded without traversal | 24 | 24 |

The junctions point back to an already archived GP5 source tree. Their exact
relative paths, link types, and targets are retained in the V2 receipt; the
copy intentionally did not traverse them and duplicate that source tree.
All `C:\tmp` originals remain present.

The first generated delta receipt,
`PRESERVATION_RECEIPT.json`, is intentionally retained with
`verified=false`, SHA-256
`46dc184b35c1a0a0374d6e67912293cfbb5425f73a9a97631efe9a8d5ac98b4f`.
It used PowerShell `Measure-Object -Property` against ordered dictionaries,
which produced a false zero-byte aggregate. No copied file or hash was wrong.
V2 replaced that aggregation with explicit checked Int64 accumulation,
retained the failed receipt and its hash, rehashed every file, and is the only
valid delta preservation receipt.

## Stale-checkout recovery

Before the CodeStuff checkout was fast-forwarded, all 16 dirty or untracked
files were copied and hashed under:

```text
<evidence-root>\base-dirty-recovery-2026-07-28
```

Its receipt is
`PRESERVATION_RECEIPT.json`, SHA-256
`7155eb3d7298826847d0363da9a89020fd5dae071e6e8577434e63bd2b09efcd`.
The development-only controller/probe work was also committed and pushed
without merging it into current research authority:

```text
branch: recovery/pre-gq-local-20260728
commit: 67faafaccd773aadc097d467f368b7cfcf5d32fc
```

The separately appearing malformed local `.gitignore` edit was preserved as
`.gitignore.post-recovery-race` in the same recovery directory and as
`stash@{0}` at recovery time. Its SHA-256 is
`97c02688851b632949b3d802291826b83e49b599862efec6e7501895e2c6ae97`.
The clean, superseding PDF-ignore policy is commit
`659ec980803bcdae204830739f4e178b9a5abdb9`.

On 2026-08-02, the two remaining local stash objects were converted to named
archive branches, pushed to `origin`, and verified at their exact object IDs
before the redundant local stash references were removed:

| Historical state | Durable archive branch | Exact object |
|---|---|---|
| malformed PDF-ignore attempt | `archive/stashes/20260802/malformed-pdf-ignore-ce5afc1` | `ce5afc1ab4dc460330966103aae5b276372ac04a` |
| rejected abductor experiment | `archive/stashes/20260802/rejected-abductor-experiment-bc75944` | `bc75944b676a239e20357d03684b5980642af880` |

The rejected abductor experiment remains historical negative development work;
the archive branch does not merge it into `main` or grant it scientific or SDK
authority. The same consolidation push published all 19 preserved
`archive/external-worktrees/20260731/*` refs to `origin` without rewriting or
merging them.

The final sibling-checkout audit on 2026-08-02 found one additional unique
dirty state in `SporeSpore - Copy`, based on `6021d87`. Its complete working
tree—including the staged M25-M30-era source and tests, two already-missing local reference-asset files, and one untracked generated test UID—was committed
without editing it and pushed as:

| Historical state | Durable archive branch | Exact commit |
|---|---|---|
| legacy `SporeSpore - Copy` working tree | `archive/external-worktrees/20260802/SporeSpore_copy_6021d87_dirty` | `7af2d935aaf7f22aa925b1bcd3c2f162fc9ca918` |

The archived tree contains no unrelated-repository references, is now clean,
and is not merged into current `main`. The four remaining top-level LoColemotion Git
checkouts under `C:\tmp` were clean and their exact heads were already
reachable from `main` and the published 20260731 archive refs; their test
outputs and caches were therefore not duplicated into source history.

## Research PDFs

The three paper copies remain outside Git at the paths and SHA-256 digests
recorded in
[`research/LOCOMOTION_RESEARCH_SOURCES.md`](research/LOCOMOTION_RESEARCH_SOURCES.md).
Exact root-level ignore rules keep the working tree clean without erasing the
local sources or treating publisher PDFs as repository source.

## BW25Y retained infrastructure-invalid physical attempt

The consumed BW25Y yaw-development evidence is retained directly under the
durable project evidence root, not under `C:\tmp`:

```text
<evidence-root>\balanced-wave-bw25y-yaw-development-14c1c34
```

The tree contains `227` files and `3,664,652` bytes. Its canonical digest
(`sha256_utf8_sorted_relative_path_tab_bytes_tab_raw_sha256_lf_v1`) is:

```text
8d28c9ddef2335954edfc59d4d586bca1c40f77792afcfbe012d198421c8eff8
```

Key retained artifacts are:

| Artifact | SHA-256 |
|---|---|
| `attempt.json` | `0af3926a08de665c694a6a0a8f6d10a025899b55d9440eaa6e8ba2e89e16fd9d` |
| `raw-result.json` | `0e6e4117498e49b3139556d8f9c3f6d6a604b3ab72401865f622495628f37cc6` |
| `posthoc-execution-diagnostic.json` | `a8adf91b5094ad086d97768526b3581eae79e84e4513a776f6b83ee3facf66b0` |

The tree retains 28 cell directories, 56 raw receipts, 56 transcripts, 56
stderr logs, and 56 isolated Godot logs. It intentionally contains no final
receipt, `evaluation.json`, `completion.json`, or `report.json`: the actual
worker receipt constructor failed its schema before any cell could cross the
frozen final-composition boundary. The repository closure and audit bind this
absence as an incomplete infrastructure-invalid result. Do not add posthoc
scores to this tree or treat its raw physical streams as a controller
comparison.

## Retained invalid full-conformance attestation A1

The first clean-pushed full-Godot attestation publication is retained at:

```text
<evidence-root>\full-godot-conformance-3a52c764-20260802T133643Z\attestation.json
```

| Field | Retained value |
|---|---|
| source commit | `3a52c764adfcf494cf9d2b13ca9d0fa4a6b41a35` |
| attestation SHA-256 | `6c638a8e0dca553063add361d0c1630c78fcbf2d2d54e9c5f9cba6fe6026d9c0` |
| full-suite process | exit `0` |
| recorded duration | `844.6916806 s` |
| independent verification | `FULL_GODOT_CONFORMANCE` failure |
| classification | infrastructure-invalid, no physical or scientific authority |

The timestamp verifier lost fractional seconds after PowerShell deserialized
the JSON ISO strings as `System.DateTime`, causing the duration to recompute as
`845 s`. The file must not be overwritten or treated as a valid attestation.
Because it consumed no one-shot physical campaign, selector, or scientific
identity, a corrected source commit may publish a distinct attestation at a
new durable path after passing the serialized JSON round-trip canary.

The repository closure is
[`../sdk/locomotion_full_conformance_attestation_v1_closure.json`](../sdk/locomotion_full_conformance_attestation_v1_closure.json),
audited by
[`../tests/test_locomotion_full_conformance_attestation_v1_closure.ps1`](../tests/test_locomotion_full_conformance_attestation_v1_closure.ps1).
It pins the bytes, source/tree and four historical Git blobs, reproduces the
exact verifier failure, and keeps every scientific and physical claim false.

## Full-Godot conformance V2 positive infrastructure commissioning

```text
<evidence-root>\full-godot-conformance-v2-0513be82-20260802T140317Z\attestation.json
```

| Field | Retained value |
|---|---|
| source commit | `0513be82370604e958c2ff1e563e444b70746b72` |
| source tree | `612f9a2532758904a53a6668de6858fcaa5c9fda` |
| schema | `sporespore_full_godot_conformance_attestation_v2` |
| bytes | `3562` |
| SHA-256 | `e4f9386964c213ff686e151357ae9e8928391ca5a5ad35fb60851db42aeae910` |
| duration | `855.3993872 s` |
| postpublication verifier | passed, no failure codes |
| one-shot physical campaigns | `0` |
| physical/scientific authority | `false` |

The successful receipt is frozen by
[`../sdk/locomotion_full_conformance_attestation_v2_closure.json`](../sdk/locomotion_full_conformance_attestation_v2_closure.json),
audited by
[`../tests/test_locomotion_full_conformance_attestation_v2_closure.ps1`](../tests/test_locomotion_full_conformance_attestation_v2_closure.ps1).
The closure and audit SHA-256 values are
`984f9b5e9869d179e252b00ba467919481ace939f949e770ea04308e1322d9df`
and
`ff6eec84398020f1503ea8a729cc27932429e6b2d94665927ca12287baf7cc69`.
The audit reconstructs the historical V2 verifier and four bound Git blobs,
revalidates the immutable external file, and preserves all scientific claims
as false. It is evidence that the outer safeguard works for the exact closed
source/host tuple; it is not walking or release evidence and cannot qualify a
later commit.

## BW28Y full-Godot qualification and retained physical result

The exact clean-pushed BW28Y source `77b4ca34fc2d8c3271fcfa364a817b02d7eb81ed`
passed full Godot-including V2 conformance before any BW28Y world opened. Its
durable qualification is:

```text
<evidence-root>\full-godot-conformance-v2-77b4ca34-20260802T190515Z\attestation.json
```

The attestation is `3,561` bytes with SHA-256
`0ed780d926228097fccdf71edf369f213a844bdd89e31b09509e0736af08f6cd`.
It binds source tree `b9e3053b6140fe0feb191b548c20b1afbadc5cd3`, records the
canonical terminal conformance marker, and keeps every physical and scientific
claim false. The nearby `20260802T190417Z` lock-refusal directory contained no
attestation and was removed during closure cleanup; it is not evidence.

The one physical BW28Y attempt is retained at:

```text
<evidence-root>\balanced-wave-bw28y-yaw-development-77b4ca3
```

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `attempt.json` | `7,098` | `584a85a267669a8d3ff0fdd17bd8e779a48bddc708bd73200b555ad0beede177` |
| `raw-result.json` | `370,408` | `a178dce3218f8f7254c590aa1602b7cfd26af6d3dd5a645eb4a063cb965ece2c` |
| `evaluation.json` | `9,206` | `3bc76ea47eb765a1c0adbf04f27bf462fdba74382afb194710439e9fb3a808f1` |
| `report.json` | `50,345` | `a7371506a0d295a02b67daea2cdc3fd959e80ed1157b40cd3ccfecfccba7e85b` |
| `completion.json` | `972` | `280909598da9a1637be23c232da043e155167e7e35b9b98e7d418d9a418e0d74` |

The complete tree contains `145` files and `2,826,641` bytes. Its canonical
tree SHA-256 is
`c98fed56a9597f1c250f50279663a1e471ef325f44ab72678a6d2ad77188cbf1`.
Attempt `7a44427e656244358f8f774333eb2af5` completed all `28` primary
workers with no replacement and produced the frozen valid `NONE` selection.
This directory is immutable finite development evidence, not turning,
material-robustness, population, cross-engine, or release evidence.

## MuJoCo VH2 consumed implementation-invalid closure

The only permitted physical process for clean pushed source
`d6c38c5f11e389fe0f2f1356f2eb1918403e46e6` is retained at:

```text
<evidence-root>\c6-mujoco-velocity-only-stability-vh2-d6c38c5
```

The six-file tree contains `16,372` bytes and has canonical SHA-256
`df1442e91946da3149362cd3100022f6e4caa413fad5b51b7bc6d021a7d041c8`.
Attempt `8a8da8024c6743e7958977373895b9e6` constructed one model but failed
at the first frozen `data.qM` access before `mj_step`, before any completed
cell, and before report serialization. The closure is therefore an immutable
implementation-invalid process record, not a scientific positive, a valid
scientific negative, locomotion, or walking evidence.

The exact closure manifest is
[`../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.json`](../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.json),
and its executable audit is
[`../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.ps1`](../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.ps1).
Their SHA-256 values are
`ac0207f33a66c06e13e24b4f4149922c3bd25aa2db11229ab2184f32801ccc7c`
and
`39db42801a6f192a7318a60b0976ccb3283cbea37e59d8561073d4a52019ceca`.
The audit also proves that the old physical supervisor refuses a rerun before
it reads an attestation or constructs a model.

## MuJoCo VH3 complete but temporal-instrumentation-invalid closure

Clean pushed source
`57e97f2f08636ef42b38511e11650e89b674dfaf` first passed a real
Godot-including qualification retained at:

```text
<evidence-root>\full-godot-conformance-v2-57e97f2-20260803T030216Z\attestation.json
```

That attestation is `3,562` bytes, has SHA-256
`ffabcc0f9d3289528c83cafb8acf1f439416c377b410af051fd255e14752de0e`,
and records `1321.565198 s` of passing conformance with no one-shot physical
campaign and every scientific claim false. A prior qualification attempt was
blocked by a visible workbench process holding the final Godot adapter DLL; it
published no attestation and consumed no VH3 identity.

VH3 attempt `dfac87f7d55144e781c8fcef5a97f168` then completed all `24`
worlds and retained all `43,200` trace records at:

```text
<evidence-root>\c6-mujoco-velocity-only-stability-vh3-57e97f2
```

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `attempt.json` | `4,939` | `41d8bb2326956f83894627ee5530bf7d515b9d46d51e0a6128d79f13894726d6` |
| `completion.json` | `1,239` | `189bb826d1c2a15a514263a82d4ebefaa48d67df1de84045191b69fb1df5ecb2` |
| `preflight.json` | `5,055` | `9c364e48e87b0fbdf31412a05786ba4590c0eb4ebce30249756605da2c54443e` |
| `report.json` | `11,361,222` | `7710a3fd4b6ccc6836ab152f5827ce12a5d967d7a169b7597b5a521f38507b4f` |
| `stderr.log` | `0` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `stdout.log` | `5,332,424` | `bebf4afcb3b5d818954163499202343a4fc6ef0869e2ec5c9e5bb5fc147427ff` |

The exact six-file tree contains `16,704,879` bytes and has canonical SHA-256
`61b30ea907da38c052ef4543ac102188ee7f78691e0386938b98bf1a35519e73`.
The frozen report printed `22/24`, but its during-step force and impulse
measurement was invalid: it copied post-step state, called `mj_forward`, and
recorded the newly recomputed force as though it had been applied during the
already completed step.

The zero-world temporal diagnostic is retained separately so the original
physical tree remains unchanged:

```text
<evidence-root>\c6-mujoco-velocity-only-stability-vh3-posthoc-57e97f2\temporal-measurement-diagnostic.json
```

It is `18,123` bytes with SHA-256
`c5264b57c41e8606f520012acfbf9c1741a664fd60c3b59af31d39ec83da1706`.
The deterministic audit reconstructs `114` completed-step saturation events
versus `90` retained post-state events, exactly one omitted event per cell, and
a maximum capped momentum discrepancy of about `3.47e-18 N m s`. That is
development evidence only: it makes the frozen `22/24` result
uninterpretable, but it cannot retroactively turn VH3 into `24/24`.

The immutable closure manifest is
[`../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json`](../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json)
with SHA-256
`06a85f029ba05e9fa45ee4499304e38bbb79c9c598dac60361390bc7d4b77217`.
Its executable zero-world audit is
[`../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.ps1`](../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.ps1)
with SHA-256
`58ee615736cc6c53b1f515fce6cc1e995d8d5523168b1feaec36fd2c9cd19bb8`.
VH3 is closed consumed and temporal-instrumentation-invalid with neither a
scientific positive nor a scientific negative, no walking, and no release
authority.

## 2026-08-03: MuJoCo VH4 positive host characterization

The distinct temporally corrected VH4 source was frozen and pushed as
`2722c2b1220c91993c1c8263769bd834e2b51c27`. Its exact full-Godot V2
attestation is:

```text
<evidence-root>\full-godot-conformance-v2-2722c2b-20260803T045802Z\attestation.json
SHA-256 8e609e03c79baaefedb776f606fe1b194580fb61d29b7fe4c2e7f49718a433f1
```

The one-shot physical evidence root is:

```text
<evidence-root>\c6-mujoco-velocity-only-stability-vh4-2722c2b
report SHA-256 f6b5657f14a922aed59e82bc5c6ff4d2e53b2b2a70737eeea4ec94d6a8f53f3d
tree SHA-256 8d1e5e0e96080d7aff6d485bb91189bcd6c515a4ec6ad4d1c4ea6f56d23418c2
```

All 24 exact cells and 43,200 temporal traces passed. The result observed 114
saturated substeps, preserved 40--43 temporal force witnesses per cell, passed
both momentum relations, and had zero integrity mismatches or violations. The
closure manifest is
[`../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json`](../sdk/mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json),
SHA-256
`faf6aabe9d5bb36a410a4447416c63697666640b458bae49ee1662aa045e4cb9`.
This is exact-finite host authority, not selected-policy locomotion, walking,
cross-engine equivalence, or release authority.

## 2026-08-03: MuJoCo VH5 positive s169 per-actuator host characterization

The distinct four-class VH5 source was frozen and pushed as
`d11d8ef10a82e11eef78b6a51cd74193bce37e0e`. Its exact full-Godot V2
attestation is:

```text
<evidence-root>\full-godot-conformance-v2-d11d8ef-20260803T075257Z\attestation.json
SHA-256 be4c78648c4df86fc93c0f1e936485c78494243852725fe8c1a2c0c44ab7df9b
```

The one-shot physical evidence root is:

```text
<evidence-root>\c6-mujoco-s169-force-limit-vh5-d11d8ef
```

| Artifact | Bytes | SHA-256 |
|---|---:|---|
| `attempt.json` | `7,656` | `78bebd90aa069f63232f1d3e8c53b2099f689162e55ab1a93b27fccacebf449f` |
| `completion.json` | `1,246` | `57671390d45431109056d26a4c2e919c77a99e0a803653a4679836c9dfbe4d3d` |
| `preflight.json` | `7,179` | `f32cb11d94e54bafa798b8818fbe0186aa8448f5c6275cbcbb5d51c36ceffb2b` |
| `report.json` | `73,215,845` | `305b3b462ec463278eedd526d28f32abdde3d0eaff919a3d52b179f6590deb96` |
| `stderr.log` | `0` | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| `stdout.log` | `37,681,424` | `5659bc8737af5ecea137ed4a9bc7dcbcd1ed3ee6e1fa4274627d457c5aa03418` |

The exact six-file tree contains `110,913,350` bytes and has canonical SHA-256
`c96149581e4db495796beda412afd87d1f9f0d740c262f07d10d393839856422`.
Attempt `e081a0c170394bee980dfdf827fd2816` completed all `96/96` cells,
`48/48` mirrored pairs, and `172,800/172,800` traces. It retained `470`
saturated internal steps, `36..43` temporal-force witnesses per cell, and zero
integrity violations. The immutable closure manifest is
[`../sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json`](../sdk/mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json),
SHA-256
`fbb8441fb8a3907c56155db777de00ce8b6e2f293ef67e77a2a30d2eeeb0f34f`.
This is exact-finite four-class host authority, not selected-policy multibody
locomotion, walking, cross-engine equivalence, robustness, or release authority.

## R23D14 failed pre-attestation conformance receipt

The first full-Godot V2 attestation attempt for R23D14 authority source
`9d92668c477bdfae5fc259ecac4e9315072b5fae` failed closed in the first
conformance stage. It published no attestation and opened no R23D14 world.

```text
<evidence-root>\conformance-runs\20260811T074554Z-9d92668c-9823c950922f4ea09de779dcbc52fe30\receipt.json
SHA-256 a7aec4dc8e17ed057699b27b27181c36a00918df2b548390839afd34df70d433

<evidence-root>\conformance-runs\20260811T074554Z-9d92668c-9823c950922f4ea09de779dcbc52fe30\stages\01-authority_and_historical_closures.json
SHA-256 1d7220a35c55bef5c96a8e81e82a93bdf611871c96b742f0f5bb1c23f29b6df0
```

The run lasted `54.3651383 s`. CEP1 correctly listed `100` audits, while the
partial CAD1/CDK1 registry still declared `95`; reconciliation refused. This is
retained infrastructure-negative evidence. It did not consume the R23D14
one-shot matrix identity or establish any physics or locomotion result.

The clean corrected-source retry reached the frozen CAP1 verifier and failed
because that historical 95-audit test read the live 100-audit CEP1 inventory.

```text
<evidence-root>\conformance-runs\20260811T075320Z-33cb7155-9dba0a11e01242099252e362c6c9b04d\receipt.json
SHA-256 16651dd451e7a61521a7082e06702548080502dae1855df7beca486bdbe7452d

<evidence-root>\conformance-runs\20260811T075320Z-33cb7155-9dba0a11e01242099252e362c6c9b04d\stages\01-authority_and_historical_closures.json
SHA-256 aa1241b8e0a9dceb3108ef6ae875b2d5eb2a150a19c6ac8133d71f04776bbed7
```

That run lasted `135.5095475 s`. It also published no attestation and consumed
no R23D14 world or one-shot identity. The verifier successor reads CAP1's exact
inventory from source `8262f853d5dc5d59d7ba50f1991eaacc9608c3c4`, Git blob
`a1722392dfa2b63fb37bfe3ac961c75f3059fc6e`, and separately proves the frozen
path set remains present in live CEP1.

The next clean retry passed both preceding repairs, then failed closed in the
workbench audit because four mutable-current proof entries still named the
predecessor release-contract and support-matrix digests.

```text
<evidence-root>\conformance-runs\20260811T080536Z-0c2c403a-da1fdacd191e4d6a82caf6a4f1bb0e51\receipt.json
SHA-256 fe7d3aa8d48ee16f943eed4465ec0259a0c1be9c20a94db1501840eac70ad6b8

<evidence-root>\conformance-runs\20260811T080536Z-0c2c403a-da1fdacd191e4d6a82caf6a4f1bb0e51\stages\01-authority_and_historical_closures.json
SHA-256 af0a8d19bf89978fabe60f9b90ca71555c790b8d6ae60f998960cac8ef54a718
```

That run lasted `200.4066013 s`. It published no attestation and consumed no
R23D14 model, world, or one-shot identity. The prospective repair advances
only the four current release-authority proof pairs after the incident is
recorded in the final release and support bytes.

## R23D14 consumed direct-matrix evidence

The sole R23D14 attempt is retained at
`<evidence-root>\qsdk-r23d14-3ead7ec5-20260811T091644Z`.
Its `54` files total `54,172,007` bytes under canonical tree SHA-256
`4853c96858ac26e7862b722367d3ec14dede378ae532c9fd1801d084f0a82282`.
Every attempt file, the source-exact attestation, the production-authorization
canary log, and the continuous supervisor log has a verified production CAS
object. The repository closure and executable rehash audit are
[`../sdk/turning/r23d14_physical_closure_v1.json`](../sdk/turning/r23d14_physical_closure_v1.json)
and [`../tests/test_qsdk_r23d14_closure.ps1`](../tests/test_qsdk_r23d14_closure.ps1).
The identity is consumed and may not be rerun, repaired, or selectively
replaced.

## Retention rule

Do not delete any durable evidence or recovery directory until there is a
second independent backup and its receipt has been verified. Temp originals
may be cleaned only after every documentation citation resolves through the
durable mapping and the second backup is confirmed.
