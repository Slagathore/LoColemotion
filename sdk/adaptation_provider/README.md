# Optional adaptation provider

This directory is the public, engine-neutral learned-adaptation boundary for
SDK `0.1.0`. A provider is optional at runtime. The deterministic controller
still produces the complete baseline command, and the portable core—not the
provider or host adapter—decides whether a proposal is valid and how much of
it can be applied.

The normative machine-readable files are:

- [`provider_contract_v1.json`](provider_contract_v1.json), the QSDK-R21
  provider/request/fallback/authority contract;
- [`tier2_architecture_v1.json`](tier2_architecture_v1.json), the QSDK-R22
  episode, candidate-chapter, frozen-corpus, model-candidate, qualification,
  and successor-promotion contract; and
- [`experience_encyclopedia_contract_v1.json`](experience_encyclopedia_contract_v1.json),
  the deterministic online-characterization and append-only candidate-
  experience contract;
- [`mujoco_warp_supported_subset_contract_v1.json`](mujoco_warp_supported_subset_contract_v1.json),
  the version-pinned zero-world runtime and candidate-feature boundary; and
- [`mujoco_warp_equivalence_calibration_contract_v1.json`](mujoco_warp_equivalence_calibration_contract_v1.json),
  the repeatability, numerical-sensitivity, margin-provenance, and held-out
  adequacy protocol whose production physics plan remains absent; and
- [`mujoco_warp_semantic_ceiling_readiness_contract_v1.json`](mujoco_warp_semantic_ceiling_readiness_contract_v1.json),
  the pre-calibration provenance gate that currently retains all five required
  production semantic ceilings as unresolved; and
- [`mujoco_warp_metric_semantics_contract_v1.json`](mujoco_warp_metric_semantics_contract_v1.json),
  the fixture-only executable formula grammar whose five production metric
  definitions all remain unresolved; and
- [`mujoco_warp_observable_projection_contract_v1.json`](mujoco_warp_observable_projection_contract_v1.json),
  the fixture-only raw CPU-MuJoCo/MuJoCo-Warp observable projection grammar
  whose first required production topology binding remains unresolved.

Accepted clean pushed-source evidence for the provider contract and Tier 2
architecture is indexed by
[`adaptation_provider_validation_manifest.json`](adaptation_provider_validation_manifest.json)
and
[`tier2_architecture_validation_manifest.json`](tier2_architecture_validation_manifest.json).
The deterministic characterization and candidate-experience layer is
separately bound by
[`experience_encyclopedia_validation_manifest.json`](experience_encyclopedia_validation_manifest.json).
The MuJoCo-Warp semantic-ceiling source gate is separately bound by
[`mujoco_warp_semantic_ceiling_readiness_validation_manifest.json`](mujoco_warp_semantic_ceiling_readiness_validation_manifest.json).
The first two point to immutable reports from exact source `211cb78`; the
experience manifest points to the `8/8` report from exact clean pushed source
`ac20bcd`. Together they close their stated source-development requirements
without claiming a trained provider, promoted encyclopedia, or physical
qualification.

The evidence-binding source `34992ff` subsequently passed the complete
canonical no-Godot cold route. Its retained receipt SHA-256 is
`665e4ea1361d79131245ebd0a90f82ba07967aa18ade9fcb20a42306e2d3c145`.
That is a source-integration observation only: the declared Godot stage was
skipped, the dependency key is incomplete, cache/reuse is disabled, and no
training, promotion, physical, or release authority follows.

The implementation is exposed as Rust `resolve_adaptation_v1`, C
`ss_resolve_adaptation_v1_json`, and Python
`LocomotionCore.resolve_adaptation_v1`. All three resolve the same strict
`sporespore_adaptation_resolution_request_v1` record.

## Runtime flow

1. The ordinary portable controller emits a complete canonical velocity
   baseline.
2. The host constructs a versioned provider request containing the bounded
   descriptor, canonical state and command, baseline, bounded recent canonical
   history, versioned controller context, request-pinned model/corpus identity,
   provider memory plus its verified digest, safety envelope, and seed.
3. If installed, a provider returns a response bound to the request ID and
   canonical request SHA-256. Its only load-bearing proposal is an exact-order
   canonical velocity delta vector.
4. The core checks response identity, order, finiteness, confidence, support
   distance, provenance, memory transition, and forbidden-authority flags.
5. For an accepted `applied` response, the core applies the declared absolute
   correction limit, per-step slew limit, and original actuator-speed limit,
   in that order.
6. The adapter mechanically maps the resulting canonical command to its host
   convention. The provider never emits engine-native commands.

An absent, malformed, stale, refused, unsupported, uncertain, resetting,
low-confidence, or out-of-support provider returns a successful resolution
receipt whose final actuator velocities are bit-exact with the deterministic
baseline. An invalid host request remains a typed core error; provider
optionality is not permission to accept an invalid state or safety envelope.

The provider cannot build or inspect a native world through this interface,
mutate physics, override a safety limit, update its deployed weights, promote
an encyclopedia chapter, or grant physical acceptance. Provider memory is an
identity-bound, bounded JSON value with a verified digest, explicit sequence,
and reset epoch. A response from a provider/model/corpus identity other than
the one pinned by the request falls back rather than gaining influence.

## Deterministic online characterization

[`experience_encyclopedia.py`](experience_encyclopedia.py) accepts only an
ordered, finite, canonical observation window. It validates exact fields,
strictly increasing step/time identity, declared support-contact capacity,
provider/model/corpus pins, descriptor digest, task, environment, support/OOD
status, and seed. It deterministically derives duration, forward-velocity
tracking error, maximum absolute torso tilt, minimum torso height, qualified-
contact fraction, fallback fraction, and provider-influence fraction.

Those values are characterization features, not acceptance criteria. The
compiler applies no threshold, chooses no result, makes no population claim,
and never samples or mutates a native world. A separate caller must retain the
raw episode and explicitly classify its finite result as `positive`,
`negative`, `rejected`, `invalid`, or `incomplete` under the authority that
owns that question.

`AppendOnlyExperienceEncyclopedia` retains each classified candidate record,
including the exact candidate event and characterization receipt, as a
canonical self-contained content-addressed object and appends a create-only event bound
to the exact predecessor event digest. Duplicate experiences, stale parents,
unknown fields, nonfinite/reordered samples, altered objects/events, and
continued appends after an incomplete orphan object all fail closed. An
incomplete orphan remains visible in the store receipt; the library does not
delete or silently repair it. The store is a candidate-experience ledger, not
a promoted behavior encyclopedia or training corpus.

## Learning from responses

A provider response may carry
`sporespore_adaptation_candidate_experience_v1`. That record is deliberately
candidate-only. The executable Tier 2 path in
[`tier2_architecture.py`](tier2_architecture.py) converts retained successful
and failed episode receipts into an append-only candidate chapter, freezes a
prospective corpus, registers a new immutable model candidate, and refuses
promotion until ordinary CPU MuJoCo, Rapier/Parry, and Godot/Jolt all supply
accepted prospective qualification records. Promotion creates a new
encyclopedia and provider identity; it never rewrites the deployed predecessor.

MuJoCo Warp can generate training candidates at high throughput, but its
training-plane result cannot satisfy the three-engine promotion requirement.
The conformance negative control proves that refusal. The current conformance
uses architecture-only synthetic qualification shapes; it does not claim a
trained provider or completed physical qualification.

The prospective supported-subset boundary is machine-readable in
[`mujoco_warp_supported_subset_contract_v1.json`](mujoco_warp_supported_subset_contract_v1.json).
Its zero-world preflight pins MuJoCo/MuJoCo Warp `3.11.0`, Warp `1.16.0`, the
required batched API signatures, and a CUDA device while constructing and
stepping zero models. The future CPU-MuJoCo/MuJoCo-Warp physics question is
classified as equivalence/non-inferiority but remains sealed until a distinct
calibration cohort justifies and freezes margins and held-out adequacy.

Run the local runtime probe with:

```powershell
.\sdk\adapters\mujoco\.venv\Scripts\python.exe -m pip install `
  -r .\sdk\adapters\mujoco\requirements-mujoco-warp-lock.txt
.\sdk\adaptation_provider\run_mujoco_warp_supported_subset_preflight.ps1 `
  -RequireRuntime
```

Passing that probe establishes installation only. It does not qualify the
SporeSpore physics subset, authorize corpus generation/training, or supply a
native-MuJoCo, cross-engine, scientific, physical, or release result.
The exact clean pushed runtime report from source `a318bdf` is retained at
`SporeSpore_Evidence/mujoco-warp-subset-preflight-a318bdf/report.json`, SHA-256
`e4cef6b17d0124e8eccc21490de6384fb2dfc68ff150fca953f86298e123254d`,
and bound by
[`mujoco_warp_supported_subset_validation_manifest.json`](mujoco_warp_supported_subset_validation_manifest.json).

Exact clean pushed evidence-binding source `42faa71` subsequently passed the
complete canonical no-Godot cold route in `1124.725705 s`. The retained
receipt is
`SporeSpore_Evidence/conformance-runs/20260814T203430Z-42faa71e-f4718333e4b742ed95662425e6319676/receipt.json`,
SHA-256
`a9a475da5a1576cf6b01f0ffd0ab6dae7a5ae9168f2f09bead9b2918054eddd3`.
Both the source preflight and retained-evidence audit terminal markers appear
in its CAS-bound log. The declared Godot stage was skipped, the dependency key
is incomplete, and cache/reuse is disabled. This is source-integration
evidence only; subset qualification, corpus generation, training, scientific,
physical, equivalence, and release authority remain false.

## MuJoCo Warp calibration protocol

The next zero-world source layer is
[`mujoco_warp_equivalence_calibration_contract_v1.json`](mujoco_warp_equivalence_calibration_contract_v1.json)
and its pure compiler. It classifies the eventual calibration as development
work and the later CPU-MuJoCo/MuJoCo-Warp supported-subset decision as
equivalence/non-inferiority work. A production plan must bind exact topology,
contact, material, horizon, descriptor, state, control, seed, batch-capacity,
runtime, graph, and numeric-dtype identities before calibration opens.

The adequacy rule requires at least `59` unique calibration condition groups
and `59` disjoint held-out groups for a declared exchangeable generator. This
is the distribution-free `95%` content / `95%` confidence maximum-order-
statistic requirement; repeated runtime executions and sensitivity arms do not
inflate the independent condition count. Every metric and exact failure is
aggregated into one condition-level pass before the later zero-failure bound,
so metric-wise multiplicity cannot inflate the claim.

Each continuous or discrete margin needs an independently justified semantic
ceiling chosen before calibration outcomes. The calibration may show that a
margin is resolvable; it may not widen the ceiling. CPU and Warp each require
three fresh-process repeats, Warp must exercise single-world plus declared
first/last batch placement, and sensitivity uses the adjacent representable
input values in the observed effective dtype. Calibration and held-out IDs and
seeds must be disjoint, and neither training nor outcome-exposed conditions
may enter held-out validation.

MJCAL0-MJCAL7 exercise that compiler with synthetic fixture records only. The
positive and negative calibration projections remain distinct, and `15`
under-adequacy, overlap, partition, leakage, margin, repeatability,
sensitivity, incomplete, and nonfinite mutations fail closed. No production
plan, margin, cohort, physics result, or training authority is created.

Exact clean pushed source `daca13321288ba27e5c619509c554bf2126e362e`
passed those finite checks. Its create-only report is retained at
`SporeSpore_Evidence/mujoco-warp-equivalence-calibration-daca133/report.json`,
4,882 bytes with
`sha256:d45b7e3499775e846f8b77d36bf06a265fbf2238fd9cb2e71125888ed910b3d0`,
and is bound by
[`mujoco_warp_equivalence_calibration_validation_manifest.json`](mujoco_warp_equivalence_calibration_validation_manifest.json).
The executable audit rehashes the five frozen source blobs and report, confirms
8/8 cells, all 15 mutation refusals, the 59/59 fixture minima, and zero models,
steps, attempts, and worlds. It grants no production-plan, semantic-ceiling,
margin, held-out, physics-subset, throughput, training, equivalence,
scientific, physical-acceptance, or release authority.

Evidence-binding source `368f915880f27483672d0815f7e2c853ce0acccb`
subsequently passed the complete canonical no-Godot cold route in
`994.0961292 s`. Its retained 17,336-byte receipt is
`SporeSpore_Evidence/conformance-runs/20260814T212642Z-368f9158-b9feb7f4253b4f8284756623dcc0908b/receipt.json`,
`sha256:8081b65e74cfa613acfad9ecc34a03214b3582514482dc1181be8200aa715bdf`.
The post-run audit rehashed the receipt, every stage receipt, and the full log
against their CAS payloads/manifests; seven stages passed, the declared Godot
stage was skipped, and the MJCAL source/evidence terminals each occur once.
The dependency key remains incomplete and `observed_not_transitive`; cache
lookup, result reuse, reuse authority, physical campaign, scientific result,
physical acceptance, and release authority remain false.

## MuJoCo Warp semantic-ceiling readiness

The next development-only zero-world layer is
[`mujoco_warp_semantic_ceiling_readiness_contract_v1.json`](mujoco_warp_semantic_ceiling_readiness_contract_v1.json).
It does not copy the synthetic MJCAL fixture values into production. Instead,
it requires each future ceiling to bind one exact metric, unit, value, and
semantic-source class through a strict JSON pointer into hashed repository
bytes on the live main lineage; chronology independent of calibration/held-out/
historical physics outcomes; a named downstream consumer and preserved
decision; an explicit adequacy argument; and topology/contact/material/horizon
scope without a broader population claim.

The current inventory deliberately contains zero accepted production sources
and five unresolved metrics. MJSC0-MJSC7 retain those five reasons, prove a
separate fixture-only positive compiler path, and reject 25 content, path,
locator, value, chronology, outcome-leakage, fixture-leakage, unit, finiteness,
discrete-step, source-class, scope, invariance, adequacy, duplicate, and
authority mutations. Engine-specific
configured-readback tolerances, synthetic MJCAL values, and historical
locomotion thresholds are not silently promoted. No semantic ceiling, plan,
margin, calibration, held-out cohort, physics subset, training plane,
scientific result, physical acceptance, or release authority is created.

Exact clean-pushed source `faaf057ad6379ba66ec1a4425f479082f28cb1b6`
produced the retained 3,926-byte report at
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\mujoco-warp-semantic-ceiling-readiness-faaf057\report.json`
with SHA-256
`8102f0cbc8153f724d408ea4fc0393dfdb226b4a70c8521fb9e7b45b6be4b3fe`.
The validation manifest and executable audit rehash the five source Git blobs,
the report, all eight cells, all 25 refusals, the `0/5` incomplete production
inventory, and every false-authority and zero-world field. This accepts only
the development source gate.

Evidence-binding source `dd553b6e669c8875eaff71fb0d35c59d65c5c329`
subsequently passed the complete canonical no-Godot cold route. Its measured
duration was `1147.5648811` seconds, and its 17,339-byte receipt is
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\conformance-runs\20260814T222617Z-dd553b6e-5108da71f3fe495c976a89e5d7f6a987\receipt.json`
with SHA-256
`67b6eedcb9aed2a2b2c16d8290c1452d4d2f8256c65f14d9f554c26d6487cfe9`.
All eight stage receipts and CAS bindings reverified, with seven passed and the
declared Godot stage skipped; the source and retained-evidence MJSC terminals
each occur exactly once. The dependency key remains incomplete and non-
transitive, cache lookup/reuse remains disabled, release remains blocked at
`10/25`, and no semantic-ceiling, physical, scientific, or release authority
follows.

## MuJoCo Warp metric-semantics readiness

[`mujoco_warp_metric_semantics_contract_v1.json`](mujoco_warp_metric_semantics_contract_v1.json)
is the distinct development-only zero-world successor to the MJCAL/MJSC source
layers. It makes all five metric formulas executable without promoting their
synthetic values or inventing production component registries, normalization
scales, energy floors, contact populations, horizons, or ceilings.

The fixture suite binds ordered scalar, shortest-arc periodic, and
sign-invariant normalized-quaternion components; provenance and explicit
adequacy for every scale/floor/population choice; exact one-step and inclusive
bounded-horizon populations; CPU-reference energy denominators; and
one-based, contiguous, exact-count contact identities. Suite, input traces,
and evaluation are independently content-addressed. A declared exact failure
or contact identity/count mismatch returns no metric vector.

MJMS0-MJMS7 pass `8/8` cells with `52` controls. The positive route computes
five fixture metrics but remains fixture-only. The current production
inventory is zero definitions and five unresolved definitions; all calibration,
held-out, subset, training, scientific, physical-acceptance, and release
authorities remain false. A clean-pushed report and independent retained-
evidence audit were required; their accepted source-only closure is below.

The first clean-pushed retention attempt at source `6ccc6c9` created
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\mujoco-warp-metric-semantics-6ccc6c9\report.json`
(6,037 bytes,
`sha256:f3bed691726530d98dbf5d0a6c73918a885bae5cd30b7c309233c5e42ff0def0`).
The report itself records `8/8`, 52 controls, a clean matching source, and
zero worlds. The wrapper subsequently failed on PowerShell
`.Properties.Count` before terminal acceptance, so this immutable attempt is
classified invalid/incomplete and grants no retained-source status.

Verifier-only source `ba3ba521a8570c623ce26c06fb0c4148ac2e0a27`
arrays the property collection before counting
and refuses an output path before writing unless the canonical root, expected
remote, branch, HEAD, local `origin/main`, live remote branch, and worktree cleanliness
are exact. It changes no metric semantics or result.

That exact source produced the accepted 6,037-byte report at
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\mujoco-warp-metric-semantics-ba3ba52\report.json`,
`sha256:d3d8e68fa904e1712642e0767b93b3f4c9395c36da3a46660aee123937d7a7e9`.
[`mujoco_warp_metric_semantics_validation_manifest.json`](mujoco_warp_metric_semantics_validation_manifest.json)
and the executable retained-evidence audit rehash all five source blobs, both
retained attempts, the prior failing runner, every cell/control and fixture
content address, predecessor identities, zero-world counters, and false
authorities. This is accepted source conformance only; the production
definition inventory remains `0/5`.

Binding source `424992016f3f770930025ceed00c8a0f15a53707` then passed
complete cold canonical no-Godot conformance in `1079.366288 s`. Its
17,338-byte receipt is
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\conformance-runs\20260814T232917Z-42499201-65bcbf37b4ab476986a55ae64064355d\receipt.json`,
`sha256:18bf77deb0006f40153582162d4fc7efe8732740b3f5895709fef5e1ae721a98`.
The independent audit rehashed the receipt, 33,912-byte log, all eight stage
receipts and CAS objects, and six runner bindings. Seven stages passed, the
declared Godot stage was skipped, and MJMS source/evidence markers each occur
once. Dependency coverage remains incomplete and non-transitive; cache/reuse,
physics, subset, training, scientific, physical-acceptance, and release
authority remain false.

## MuJoCo Warp native-observable projection readiness

[`mujoco_warp_observable_projection_contract_v1.json`](mujoco_warp_observable_projection_contract_v1.json)
is the development-only zero-world successor to MJMS. It projects exact native-
shaped CPU-MuJoCo and MuJoCo-Warp snapshots into the MJMS trace schema without
constructing a model, invoking a physics step, or installing a production
binding.

The contract binds `qpos`, `qvel`, `actuator_force`, potential-plus-kinetic
energy, constrained contacts, CPU/Warp array shapes, observed effective dtypes,
exact native-slot coverage, `wxyz` quaternion order, CPU and Warp capture
points, Warp world filtering, unordered geom pairs, left-censored baseline
contact, transition and occurrence identity, and exact overflow/unmapped-
contact failure. MJOP0-MJOP7 pass `8/8` cells and `48` controls. The positive
fixture yields five MJMS metrics and four contact events per role; `24`
structural mutations retain their exact refusal codes.

Those are fixture compiler canaries, not native physics observations. The
required first production bucket, `bounded_quadruped_gq15`, remains `0/1`
bound and `1/1` unresolved. Production native-observable binding, metric
definitions (`0/5`), semantic ceilings (`0/5`), the calibration plan, margins,
held-out cohort, supported subset, training plane, equivalence, scientific,
physical-acceptance, and release authority remain false.

Exact clean-pushed source `c163524c95b4c0dddf6624d1a42825daa4259ab6`
produced the retained 9,494-byte report at
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\mujoco-warp-observable-projection-c163524\report.json`,
`sha256:3afc83d3a49630371386e89b099e9ca832b9e61457c5fc20d38f9bd121afebe2`.
[`mujoco_warp_observable_projection_validation_manifest.json`](mujoco_warp_observable_projection_validation_manifest.json)
and
[`../../tests/test_mujoco_warp_observable_projection_validation.ps1`](../../tests/test_mujoco_warp_observable_projection_validation.ps1)
independently bind and rehash the five frozen source blobs, the accepted report,
the MJMS predecessor contract/compiler/manifest/report/cold receipt, all cells,
controls, refusal-code pairs, fixture content addresses, zero execution counts,
the `0/1` topology inventory, and false authorities.

Binding source `4813229f6b839e38dc42892b37b0a371ff33d767` then passed
complete cold canonical no-Godot conformance in `1119.4580241 s`. Its retained
17,339-byte receipt is
`C:\Users\Cole\CodeStuff\games\SporeSpore_Evidence\conformance-runs\20260815T002656Z-4813229f-77cf6c8f860749919900eabcba45d3e9\receipt.json`,
`sha256:b7663927c26f30ea9622f96de018bdd18904d6ad536dc849b765fa7ad60fcb50`.
The independent post-run audit rehashed every stage receipt and CAS object plus
the 34,252-byte transcript
(`sha256:5ba1aca33c5d379a4f6465c4229b89f689657f22f67cc8b1e850ad1075be4b5c`).
Seven stages passed, the declared Godot stage was skipped, and the MJOP source/
evidence markers each occur once. Dependency coverage remains incomplete and
non-transitive; cache/reuse, physics, subset, training, scientific, physical-
acceptance, and release authority remain false. Release is still `10/25`.

## Run zero-world conformance

From PowerShell at the repository root:

```powershell
.\sdk\run_adaptation_provider_conformance.ps1
.\sdk\run_adaptation_experience_encyclopedia_conformance.ps1 -SkipBuild
.\sdk\run_tier2_adaptation_architecture_conformance.ps1 -SkipBuild
.\sdk\run_mujoco_warp_equivalence_calibration_conformance.ps1
.\tests\test_mujoco_warp_equivalence_calibration_validation.ps1
.\sdk\run_mujoco_warp_semantic_ceiling_readiness_conformance.ps1
.\tests\test_mujoco_warp_semantic_ceiling_readiness_validation.ps1
.\sdk\run_mujoco_warp_metric_semantics_conformance.ps1
.\tests\test_mujoco_warp_metric_semantics_validation.ps1
.\sdk\run_mujoco_warp_observable_projection_conformance.ps1
.\tests\test_mujoco_warp_observable_projection_validation.ps1
```

The first command builds the real release DLL and exercises A0-A7 through the
public Python/C ABI. The second exercises AEC0-AEC7, retains all five result
classes, and rejects nine storage/characterization mutations. The third
exercises T0-T6, including the training-only promotion negative control. The
fourth exercises MJCAL0-MJCAL7 and its 15 protocol mutations. The fifth audits
the immutable clean-pushed source report. The sixth exercises MJSC0-MJSC7 and
retains the five unresolved production-ceiling metrics while rejecting 25
provenance mutations. The seventh independently audits the exact source blobs
and retained MJSC report. The eighth exercises MJMS0-MJMS7 and all 52 formula,
trace, adequacy, failure, and authority controls. The ninth independently
audits the accepted and prior invalid MJMS attempts. The tenth exercises
MJOP0-MJOP7 and all 48 field, address, dtype, shape, lifecycle, energy, contact,
failure, and authority controls. The eleventh independently rehashes the MJOP
source/report, exact 24 refusal-code pairs, MJMS predecessor, fixture identities,
and incomplete topology inventory. All eleven open zero physics worlds and
grant no
walking, calibration, production-margin, held-out, encyclopedia-promotion,
engine-qualification, release, or physical-acceptance authority.
