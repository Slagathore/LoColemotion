# Quadruped SDK release boundary

This directory is the executable submission boundary for the first standalone
LoColemotion quadruped SDK. It is intentionally **not** a release declaration.
Public release and publication remain unauthorized. The separate bounded SDK1
candidate stage becomes available when its 17 prerequisites and clean-source
checks pass.

The boundary has four parts:

- [`quadruped_support_matrix.json`](quadruped_support_matrix.json) states only
  the capabilities that are implemented or physically evidenced and keeps
  every unsupported public claim false.
- [`quadruped_release_contract.json`](quadruped_release_contract.json) defines
  the exact informational and release-blocking gates.
- [`../compile_quadruped_sdk_release_readiness.ps1`](../compile_quadruped_sdk_release_readiness.ps1)
  verifies source files, evidence hashes, report predicates, repository
  cleanliness, and `origin/main`, then emits one machine-readable readiness
  report.
- [`../package_quadruped_sdk.ps1`](../package_quadruped_sdk.ps1) implements a
  two-stage package boundary. It can create either a watermarked,
  non-publishable clean-room conformance candidate after all prerequisite
  gates pass, or a final artifact after every release gate passes. It
  independently reruns the matching live readiness gate before creating an
  output directory. Editing a report cannot bypass either stage.

## Current SDK1 disposition

SDK1 is **20/20**, with zero missing, contradicted or invalid SDK1 milestones.
The full program is **19/25**, preserving its six explicitly deferred gates.
The [package acceptance closure](sdk1_package_acceptance_closure_v1.json) adopts
R01/M01, R16/M11 and R20/M15 from clean pushed `8f73690e` after independently
staging two identical 2,870-file source candidates and consuming one outside
the game checkout. The complete API has 83 checked/invoked exports; 524 Rust,
21 ctypes, three extension, 11 surface and eight developer-experience tests pass.
The [package auditor](audit_sdk1_package.py) verifies original artifacts and
17 refusal controls. The [adoption test](test_sdk1_package_adoption.py) exercises
the actual release compiler against corrupted package receipt hashes and a
full-program release overclaim. Original failed candidates remain retained.

The [Explorer closure](../explorer/showcase_closure_v1.json) still passes its
[auditor](check_explorer.py), and the separate live Studio is installed locally.
The [SDK1 API contract](../portable_api/portable_api_contract_v2.json) preserves
the original contract, C header and Python binding through explicit extensions.

These source candidates remain watermarked and non-publishable. The existing
`public_release_packaged` fields mean that R20 source packaging/consumption has
passed; `release_authorized` and publication/binary-redistribution permission
remain false. SDK1 milestone completion does not satisfy the full-program
`-RequireReady` gate. No new physics or comparative claim comes from packaging.

## Historical L13 disposition

The current M07 development checkpoint is the consumed L13
[v14 physical closure](../qsdk_r10f_development_route_ghost_physical_closure_v14.json).
The qualified, frozen, authorized baseline retained one world and 2,882 solver
steps, but terminal evaluation emitted two array-index errors and independent
validation also rejected the terminal content address. The second child and
kick/recovery route never ran. This is invalid/incomplete evidence, not a
behavioral negative or acceptance. No M07, support, score, candidate, or release
claim changes. The [L14 successor design](../qsdk_r10f_l14_terminal_boundary_successor_design_v1.json)
now binds the completed zero-world diagnosis of three terminal faults and
passes one positive plus 18 mutations. Only implementation is open, with
physical execution still blocked behind complete new qualification and a
prospective authority graph.

The preceding development checkpoint repaired L13's production freeze binding.
The `ebee5501` receipt repair passed official qualification, but its source was
[retired before freeze](../qsdk_r10f_l13_qualified_source_retirement_v1.json)
when the production binder demanded the current adapter equal the root design's
historical source. All six successful qualification files remain intact. The
forward 138-path v16 repair passes 43 source tests, 24 positives, 237 forced
failures, 86 wrapper corruptions, five actual source-binding functions, and
ten binding corruptions. A new source qualification and separate freeze and
authority remain required. No physical or release claim changes.

The preceding checkpoint repaired qualification-receipt completeness.
The first source (`8de3a28f`) passed the implementation suite but failed the
official wrapper on a missing nested scene-insertion counter. Its
[consumed qualification closure](../qsdk_r10f_development_route_ghost_zero_world_qualification_failure_closure_v1.json)
preserves the exact four-file, 28,659-byte record. The repaired successor source
passes 42 source tests, 24 positives, 237 forced failures, and the actual
wrapper's one-positive/86-corruption check. No L13 world or behavioral evidence
exists, and no release gate changes. A distinct official qualification and the
separate freeze/authority graph are still required before physical development.

The current contract contains 29 gates:

- 4 informational prerequisites, all with valid evidence;
- 25 requirements for the standalone quadruped submission;
- 14 requirements currently passed;
- 8 requirements currently missing;
- 3 requirements contradicted by retained negative physical evidence; and
- 0 invalid proofs.

R21 and R22 now pass for the public optional-provider adaptation interface and
the executable Tier 2 data/encyclopedia/promotion architecture. R23D78
satisfies commanded turning (`QSDK-R23`), and R24D173 satisfies the finite
advertised-engine canonical prone-to-standing conjunction (`QSDK-R24`). R05E
now satisfies the exact-finite same-selected-policy morphology requirement
(`QSDK-R05`) without claiming a continuous morphology region. Formal
cross-engine comparative inference remains separate. QSDK-R13 now composes the
already-retained Godot/Jolt foundation, exact morphology, exact material,
turning, and prone-to-standing slices into M08's bounded engine envelope. The
composition is a finite union, not a morphology-by-material product. The
detailed sequence is
[`../../docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md`](../../docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md).

R23D78 is the accepted finite commanded-turning result for exact held-out seed
`23199`, the selected public profile, and the declared Godot/Jolt,
Rapier/Parry, and MuJoCo by three-arm population. Clean-pushed source
`7b876726ba1471c6acd228181a877bd18bbb08a3` passed `16/16` qualification
gates and separate adoption with zero worlds. Attempt
`59f9c4302a5e413285102dd720fd6e2f` then completed all `9/9` native worlds,
all nine `2,992`-step horizons, and all nine retained traces; the frozen complete
evaluator accepted every engine's inherited raw-signed and
reference-conditioned turning gates. The content-addressed
[`R23D78 closure`](../turning/r23d78_production_route_three_engine_turning_validation_closure_v1.json)
binds the exact qualification and physical populations. This satisfies
`QSDK-R23` and moves the executable total to `11/25`; it does not establish
formal cross-engine equivalence, repeatability, robustness, arbitrary
morphology, prone-to-standing, physical acceptance, or release authority.
Later `10/25` statements in the retained campaign chronology below describe
their contemporaneous historical boundaries; they do not override this current
disposition.

The durable 25-gate contract remains the full-program ledger. The narrower
bounded first release is tracked separately by
[`quadruped_sdk1_milestone_mapping_v1.json`](quadruped_sdk1_milestone_mapping_v1.json)
and [`../compile_quadruped_sdk1_milestone_readiness.ps1`](../compile_quadruped_sdk1_milestone_readiness.ps1).
That compiler partitions all 25 full-program gates exactly once, maps 19 into
SDK1, explicitly defers R06/R07/R09/R11/R12/R25, and adds one polished Explorer
milestone. It currently reports `14/20`: five missing, one contradicted, and
zero invalid. This scope mapping does not mark deferred work passed, rewrite the
full-program denominator, or authorize packaging/publication.

M20 now has a closed descriptive diagnostics input without being promoted. The
[retained R23D65 divergence closure](../turning/r23d65_retained_trace_descriptive_divergence_closure_v1.json)
binds a self-contained six-file maintainer bundle at
`<evidence-root>\sdk1-m20-r23d65-retained-divergence-cecfda67`
(`1,607,556` bytes; manifest
`sha256:4ea979975242953e70196383482614f375b16cec0935750d37fcb3cdc3d03752`).
For the only matched retained pair, Godot/Jolt and Rapier/Parry finish `9.831`
degrees apart in start-aligned heading and `0.661 m` apart at the tracked torso
point; contact state differs in `23.54%` of time-aligned foot samples. The
bundle explicitly marks joint-angle RMS and whole-body COM drift unavailable,
and MuJoCo absent. It is one retrospective two-engine description, not formal
equivalence, an engine ranking, or a three-engine answer. The stable milestone
mapping remains unchanged, M20 remains `missing`, and both scores remain
`14/20` and `14/25` after the separate M08 decision.

R24D173 is a zero-world evidence decision over three immutable, already-
consumed exact-nominal positives: R44 MuJoCo, R55 Rapier/Parry, and R172
Godot/Jolt. Every candidate reached portable `complete`; every matched-zero arm
failed; and every retained evaluator verdict is a physical-development positive
under the same frozen canonical task and threshold authority. The decision and
its 14 mutation refusals satisfy `QSDK-R24` and `SDK1-M19`, advancing the full
program to `12/25` and SDK1 to `12/20` without opening a model or world.

The bounded result is not controller or effect equivalence. R44 and R55 used
controller V1, R172 used V6, and R173 establishes no repeatability, population,
arbitrary-morphology, physical-acceptance, or release authority. At that
checkpoint `QSDK-R01` was the next selected nonphysical gate. Its source bridge
and the later M08 composition are now closed; the current candidate blockers
are M07, M14, and M20. No physics is authorized by either zero-world decision.

R10E has now closed its active M07 successor. L2 completed a valid-negative
two-world development pair, then a separate held-out graph consumed two of six
worlds.
The held-out baseline was a valid negative; the push cell was invalidated by
one host-real-versus-binary64 redundant-magnitude link after applying and
measuring the native impulse. An empty-pair parameter defect then prevented
terminal-report assembly. The immutable L2 failure closure records the graph,
both worlds, four unattempted worlds, and nine retained files without drawing a
behavioral conclusion. R10E-L3 preserved every controller, physical term,
threshold, seed, and population while repairing that numeric self-link and
incomplete terminalization under a 91-path source graph. Clean source
`ff69874b`, freeze `77fc0991`, and authority `55447a47` then passed their
separate gates. The one six-world invocation completed all cells and pairs,
confirmed all three native effects, and passed every local pre/post recovery
window. Every world still failed the unchanged full walking conjunction only
on a pre-push `bounded_anchor_error`. The immutable v3 closure therefore
records a consumed valid complete finite negative. M07 and every release score
or claim remain unchanged, and no current R10E physical execution is
authorized.

R23D60 is now a valid-complete positive only for the exact held-out native
Godot/Jolt profile/morphology/seed/schedule/arm set. R23D61 follows as one
non-physical publication boundary: it names that selected eight-cap vector,
exposes typed public resolution/refusal receipts, and maps the same maximum
outer-step angular-impulse semantic into Godot, Rapier, and MuJoCo configuration
surfaces. Its complete gate builds zero worlds. R23D61 is now closed from
clean-pushed source `c61e56907d255e920297f088b93fc3e09ba12aef` after all eight
full-cold conformance stages passed. Closure does not satisfy QSDK-R23 or add a
Rapier/MuJoCo turning, equivalence, arbitrary-morphology, prone-to-standing, or
release result. The contract also retains a rejected raw-binary64 descriptor
support gate: canonical descriptor and compiled-morphology identities cross the
Godot JSON boundary, while exact cap bits are bound separately. The release
total therefore stays `10/25`.

R23D62 implemented the first complete prospective `3 engines x 3 arms` finite
decision using the R23D61 public profile, unchanged R23D60 policy semantics and
gates, and fresh seed `23167`. Its one-shot attempt was consumed before physics
when the authorization-receipt projection omitted the complete-matrix field.
That invalid/incomplete attempt cannot be patched or rerun.

R23D63 was the distinct receipt-repaired successor on fresh seed `23169`. Exact
clean-pushed source `649277e3abc8cfd481cfc6cd22719f32ebc9a332` passed a fresh
`12 + 8 + 3 = 23`-gate qualification, separate fail-closed adoption, and the
complete `13`-gate local zero-world freeze. The freeze covered all `228` exact
dependency paths and edges, all three receipt composers, and all `12` declared
receipt-schema negative controls before any model or world.

Attempt `a48bcdec043e453497d1097754d47630` then consumed R23D63. All three
Godot authorization-preflight processes emitted valid receipts before model
construction. Rapier's first authorization process rejected the supervisor's
`--campaign-seed` option because the production binary accepts `--seed`. The
complete retained population is `11` files across `8` unique CAS-backed
digests, with zero physical cells, models, worlds, steps, traces, measurements,
or turning results. Exact source analysis covers both Rapier supervisor call
sites: `0/2` conform to the sole production parser, with zero equivalence and
non-inferiority margins. R23D63 is therefore invalid/incomplete—not positive,
negative, or near-miss turning evidence—and cannot be patched, selectively
completed, or rerun. See
[`../turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json`](../turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json).

R23D64 was that distinct launcher-contract successor. It reserved unused seed
`23171`, preserved the complete R23D63 scientific design, and centralized both
Rapier supervisor vectors on the production parser's exact `--seed` option.
Its first qualification failure remains immutable and non-reusable. Corrected
clean-pushed source `8277ab3e934561902bd375f7bcaf263ac7fae231` subsequently
passed all `12 + 9 + 3 = 24` scoped qualification gates and separate adoption.
That qualification constructed zero models and worlds. Attempt
`9629fdfcbe9249a98b0c45213b58fc89` then consumed the seed-`23171`
nine-cell physical identity.

All nine physical worker processes emitted a terminal marker. Their exact
reported population is six native world attempts/builds: three Godot/Jolt,
three Rapier/Parry, and zero MuJoCo. None of the nine cells is execution-valid
or turning-evaluated:

- Godot/Jolt built all three worlds, but the selected public-profile route
  returned empty resolution, host-mapping, and physical-binding receipts before
  any SDK authority step or native command;
- Rapier/Parry built all three worlds and wrote three complete `2,992`-row
  canonical traces, but the exact worker-to-evaluator-to-PowerShell CAS
  publication failed with an authorization-manager error; and
- MuJoCo rejected an inherited private `command_schedule` preflight seam before
  model construction or a world.

The Rapier and MuJoCo worker failures also lacked required immutable identity
fields. The supervisor retained replacement failures, and the strict complete
evaluator rejected six identity-incomplete entries. No complete evaluation,
campaign report, scientific result, or physical turning result exists. The
three Rapier traces are retained diagnostic bytes only and may not be evaluated
post hoc into an R23D64 result.

The immutable closure is
[`../turning/r23d64_selected_profile_three_engine_turning_validation_closure_v1.json`](../turning/r23d64_selected_profile_three_engine_turning_validation_closure_v1.json);
its executable audit is
[`../../tests/test_qsdk_r23d64_physical_closure.ps1`](../../tests/test_qsdk_r23d64_physical_closure.ps1).
They bind all `60` retained files (`265,254,983` bytes), `44` unique digests,
and `60/60` CAS objects. R23D64 is closed, consumed, invalid/incomplete—not a
positive, negative, or near-miss turning result—and cannot be patched,
selectively completed, or rerun.

Accordingly `QSDK-R23` remains `missing` and the total remains `10/25`. A
distinct unused-seed successor must preserve the same profile, policy, native
physics, task origin, schedule, thresholds, selector, evaluator decision rule,
and interpretation while prospectively qualifying the Godot binding, Rapier
CAS chain, MuJoCo inherited entry, and complete failure-terminal identity seams.
Only a valid-complete positive nine-cell result followed by an immutable passing
closure may move the score to `11/25`. Formal cross-engine equivalence is not
part of that finite decision. Canonical prone-to-standing remains an independent
open movement requirement, with R24D10 the next recovery-development successor.

The R23D61 closure/provenance boundary was subsequently qualified by a fresh
eight-stage uncached run from clean-pushed source
`a56e4f4b966de733b16d418b814151e895844a8a`. The retained receipt is
`sha256:f0563a37e1f9cc0b89ab0692813f4be71bf5787bb46fd2849fea510de40f809c`.
All claim flags stayed false and no physical world opened.

QSDK-R24D1 remains the qualified design-only predecessor for canonical prone-
to-standing. QSDK-R24D2 now implements that exact-s169 observation,
classification, ordered-supervision, matched-zero evaluation, ABI, and typed
adapter-capability layer. Rapier/Parry and MuJoCo map `10/10` required channels;
genuine Godot 4.7 maps `8/10` and correctly returns
`unsupported_capability` because its public hinge surface does not expose
solved per-step motor impulse or the dependent actuator-work ledger. The live
contract is
[`../recovery/r24d2_portable_recovery_semantics_v1.json`](../recovery/r24d2_portable_recovery_semantics_v1.json)
and its zero-world runner is
[`../run_qsdk_r24d2_zero_world_gate.ps1`](../run_qsdk_r24d2_zero_world_gate.ps1).
All sixteen physical thresholds and both physical cohorts remain unset. No
controller, native collector, complete three-engine capability conjunction,
complete prephysical gate, native recovery world, or QSDK-R24 result exists.
The release scoreboard therefore remains `10/25`.

QSDK-R24D3 adds a distinct candidate runtime rather than changing that stock
Godot result. A content-addressed seven-file patch against exact Godot
`4.7-stable` commit `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` exposes Jolt's signed solved
hinge-motor impulse and accumulates positive and absorbed discrete motor work at
each warm-start and iterative impulse. The custom engine compiles, its source
audit rejects `12/12` mutations, and its binding probe passes `6/6` without a
physics object or solver step. The live source contract is
[`../recovery/r24d3_godot_jolt_motor_telemetry_source_v1.json`](../recovery/r24d3_godot_jolt_motor_telemetry_source_v1.json).

Those facts establish source and binding reachability only. The instrumented
profile still lacks native sign, cap, work/energy, limit-active,
motor-disabled, refusal-timing, and freshness characterization. Its first
clean-pushed cold build passed, but the v1 receipt hashed only the console
launcher and retained neither member of the exercised executable pair. That
positive result is preserved but rejected as artifact-incomplete qualification.
The v2 successor passed from clean-pushed source
`2ca77925147db4ef381737b17aedc4af723130b4`, retained and executed both binaries,
and is adopted for the exact compile/binding key. Consequently
`clean_pushed_cold_build_qualified=true`; differing cold binary hashes keep
reproducible-build and result-reuse authority false. The exact adoption source
`e0626fad670e74f1f6b195eb771892e7de054624` also passed the complete uncached
eight-stage full-cold suite, retained under receipt
`sha256:1ab1342391ceaf972500b2221781ce52d2e266cf52ddb0c863f02c52c6c46157`
and attestation
`sha256:15692faad3f5fdd20d4a8c32fbf650457120a90e398c41208d00374bc7ccfcff`.
The full run used stock Godot and audited, but did not execute, the retained
instrumented build. Both profiles remain unpromoted until native
characterization passes. No gate count changes.

QSDK-R24D4 froze that native characterization but closed as an immutable valid
zero-world negative. Its clean-pushed worker found the declaration/rig at
parent-local `+Z` and the frozen worker/evaluator oracle at `-Z`; pinned Godot
source confirms `Vector3.BACK` is `+Z`. The failure occurred after all four
static audits and before construction, with zero world attempts/builds and zero
solver steps. Its closure forbids repair or a same-source physical opening.

QSDK-R24D5 was the distinct development characterization successor. It
preserved the nine ordered isolated-hinge cells and 68 raw samples, bound `+Z`,
rejected `24` evaluator and `14` contract mutations, and kept both explicit
surprising finite outcomes structurally valid. Its immutable ten-source
declaration is
[`../recovery/r24d5_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json`](../recovery/r24d5_godot_jolt_one_hinge_telemetry_characterization_preregistration_v1.json).
Clean-pushed source `fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a` passed its
declared zero-world qualification, then consumed one native development world.
The worker completed 20 physics steps and retained 68 raw samples, but the
frozen evaluator rejected the report before producing an evaluation because
the full-precision worker value `0.05000000074505806` did not equal the frozen
fixture identity `0.0500000007450581`. The closure is
[`../recovery/r24d5_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json`](../recovery/r24d5_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json).
R24D5 is implementation-invalid and consumed; it promotes no profile, recovery
gate, prone-to-standing result, or release gate. The release total remains
`10/25`.

The R21/R22 source implementations live under
[`../adaptation_provider`](../adaptation_provider/README.md). The A0-A7
provider fixture proves exact deterministic fallback, bounded application,
request/provenance binding, refusal/OOD/reset, and candidate-only events
through the public release DLL with zero worlds. The T0-T6 Tier 2 fixture
retains success and failure episodes, creates an append-only candidate
chapter, freezes a prospective corpus, registers an immutable model candidate,
rejects training-only promotion, and exercises the required three-engine
successor-promotion record shape. Clean pushed-source reports from exact
commit `211cb78c1db6818c44470714a165db0df8dbd2dd` are now retained, hash-pinned,
and accepted by the executable gates. Neither fixture evaluates a trained
model or runs physical qualification.

The next movement prerequisite is now explicit under
[`../turning`](../turning/README.md). H0-H8 exercise the existing public
absolute-heading command through the release DLL, prove exact source output
for omitted versus reference heading, signed bilateral stride, bounds,
shortest-arc wrapping, typed safe-zero refusals, stateless/session equivalence,
and all 64 bounded descriptor vertices. This is a zero-world source fixture,
not a passed release gate. `command_conditioned_turning` remains false and
QSDK-R23 remains missing until commanded turning plus zero-command physical
straight-walk compatibility pass prospectively in every advertised engine.
The shared QSDK-R23D1 development contract declared an exact three-engine by
three-arm BW5R-B screen. Its 24-source authorization boundary reached clean,
pushed, live commit `dd61a90`, passed full Godot-including conformance at
attestation SHA-256
`0ebd70a6238db4e791fb4e99921729c36a3c56c583e7e73d953f427d2bf3e9b3`,
and consumed one serialized nine-process attempt. Godot/Jolt retained `3/3`
complete physical reports; Rapier/Parry and MuJoCo retained `0/3` each after
all six processes rejected their first real controller validation. The zero-
world preflights had exercised only zero cross-track state and therefore missed
the workers' incorrect raw-heading-equality oracle. No complete nine-report
aggregate or scientific result exists. The immutable closure is
[`../turning/physical_development_closure_v1.json`](../turning/physical_development_closure_v1.json),
SHA-256
`022b42ae025abc3ee4eb502ee1857d5b43c1f6bc0e67b7e84c07bd6aa7076717`.
R23D1 is consumed. Its aggregate supervisor and all three individual physical
workers refuse every same-identity launch before campaign or solver loading,
so no retained attempt token can selectively complete the six missing reports.
Only a distinct QSDK-R23D2 may correct the validation and failure-provenance
defects. This is not a passed release prerequisite, turning result, aggregate
negative, or cross-engine equivalence result.
R23D2's distinct stage-zero oracle is now preregistered under
[`../turning`](../turning/README.md). Its seven zero-world canaries include six
nonzero cross-track states, all of which reject the invalid R23D1 raw-heading
oracle. It also freezes per-predicate receipt failures and stage-aware
attempt/build accounting. Its separate Rapier worker is now commissioned at
zero-world across all three arm entrypoints. Twenty-one generic oracle canaries
plus three exact signed arm-command boundaries produce 24 selected-policy
controller steps, 192 ForceBased commands, 24 host mappings, 18 old-oracle
rejections, and 105 passing receipt-field mutations. The physical route refuses
before any world attempt. The Rapier physical worker is now implemented behind
that shared authorization boundary; its zero-world gate additionally passes
`3/3` evaluator-shaped success reports and all `18/18` arm-by-stage failure
receipts. Direct physical mode still refuses before any attempt or world. The
independently commissioned MuJoCo worker repeats
the corrected oracle and signed-arm checks through 24 public-DLL steps, 192
VH5-characterized commands, 24 mappings, and three production-XML validations;
its real physical loop is now also implemented behind shared authorization,
and its zero-world gate accepts `3/3` success reports plus `18/18` staged
failures while trapping any preflight `MjModel` construction. The independently
commissioned Godot/Jolt
worker crosses 24 real GDExtension sessions and selected-policy steps, 192
native commands, 24 production mappings, and 192 unparented `HingeJoint3D`
motor writes/readbacks. No object enters the SceneTree and no world is built.
Its real world/report/failure route is now implemented behind closed shared
authorization; three exact one-step trace canaries, `3/3` success reports, and
`18/18` staged failure receipts pass without opening a world. Actual successor
engine and physical workers are both `3/3`. Shared evaluation/supervision is
commissioned at zero-world: the independent evaluator distinguishes valid
positives, valid negatives, and invalid/incomplete execution; canonicalizes
rejected projections before embedding and hashing; and confines cross-language
numeric comparisons to the frozen `1e-12` receipt tolerance. The complete
supervisor content-addresses nine synthetic reports plus three failure receipts
before aggregation and refuses physical mode without complete authority before
world construction. The prospective source/runtime freeze now binds the exact
workers, evaluators, runtimes, consumer artifacts, operation lock, and
attestation verifier. Physical execution is authorized only for one ordered,
serialized supervisor-authored nine-cell attempt. Launch remains operationally
blocked until the authorization boundary is clean, pushed, live, and covered
by its own current full-Godot V2 attestation. This adds no passed release
prerequisite.
The canonical no-Godot conformance route including the Rapier worker gate
exited `0` in `1,775.2 s` without opening an R23D2 world. The uninterrupted
prospective-worktree route including the MuJoCo worker then exited `0` in
`1,515.4 s`, also with no R23D2 world; it is precommit implementation
qualification, not physical authorization.
The integrated prospective-worktree full-Godot conformance route subsequently
exited `0` in `1,831.5 s`, with all three worker gates included and no R23D2
world opened. It is precommit implementation qualification, not physical
authorization.
After the shared evaluator, complete supervisor, and 34th safe workbench row
were integrated, the canonical no-Godot route exited `0` in `1,402.3 s` and the
complete Godot-inclusive route exited `0` in `1,570.4 s`. The latter passed all
workbench Godot/live self-tests and the supervisor through all three real
adapter boundaries. These are still dirty-worktree precommit implementation
checks: zero R23D2 worlds opened and no R23D2 physical identity was consumed.
After the authorization-closed Rapier physical worker and its integration pins
were added, the complete canonical Godot-inclusive route again exited `0`, in
`1,642.521 s`. The expanded worker/supervisor gates passed with zero R23D2
worlds and no consumed R23D2 physical identity. This remains implementation
qualification and adds no passed release prerequisite.
The subsequent MuJoCo and Godot/Jolt physical-worker focused gates each passed
`3/3` success reports and `18/18` staged failures through the production
evaluator. MuJoCo constructed zero models; Godot inserted zero physics objects
into a SceneTree; both opened zero worlds. The complete supervisor reports
`physical_workers=3/3`. Canonical Godot-inclusive conformance then exited `0`
in `1,658.506 s`, with no R23D2 world or physical identity consumed. Isolated
commit and clean pushed verification remain pending at this prospective
boundary.

The clean preauthorization source at commit `50b715a` subsequently passed the
full Godot-inclusive V2 attestation route; the retained attestation SHA-256 is
`2a941b26c8dfb814f64151d96bd803ed979623b033a6ccdda26c620b51f5fa22`.
That receipt verifies the worker-implementation boundary but intentionally
cannot authorize a later source commit. The authorization supervisor now also
revalidates every exact runtime artifact after all zero-world worker gates and
before CAS publication or attempt creation. All Rust consumers use one pinned
recipe with a constant later-precedence Cargo-target remap plus `/Brepro` and
the bare PDB path. Two fresh, separate target roots produced byte-identical
core DLL, Godot adapter DLL, and Rapier worker EXE at SHA-256
`d3679e5781270781fa83f90e2cf3f915d4254eedf48c22447d3b04d04bc0edc8`,
`3f43ca2dca8cf5632449863458d8c91caa3025854435f9636f2c79394752ee03`,
and `a50043e63828179efa08204a27490a81f200dbc38fba5d9be30f1de69e01113c`
respectively.
The final focused R23D2 supervisor audit exited `0` in `115.383 s`, passed all
three worker gates and complete aggregate controls at zero worlds, and left all
`17/17` frozen runtime artifacts exact. Final canonical full-Godot conformance
then exited `0` in `1,703.6 s`; the terminal supervisor and two post-suite
artifact checks preserved all `17/17` bindings with zero physical identities.
The prospective boundary may now be committed, but a fresh clean-source V2
attestation is still required before any physical launch.
Final review added one checkout-only safeguard: the new raw-hash-bound
materializer has an explicit `eol=lf` rule, with CEP1, freeze, support, and
catalog pins advanced together. CEP1 and a final `108.54 s` complete supervisor
rerun passed on those bytes with all `17/17` artifacts exact.

R23D2 then reached clean pushed commit `2b46e0f86f23e5a6fbf0b0ed69e7000cb7f5aeeb`.
Its exact-source full-Godot V2 suite passed in `1,769.877 s`; the retained
attestation SHA-256 is
`b1e51909ec1b0ef52403b1e9a95ae18f0abf2333b08670b1ec47d67d890c10c3`.
The sole serialized physical attempt built and attempted all `9/9` worlds.
Rapier and MuJoCo retained `6/6` execution-valid reports: both reference-zero
and positive-heading arms passed their frozen per-cell screens, while both
negative-heading arms were valid physical negatives. Rapier's negative arm
failed six outcome gates and MuJoCo's failed tilt plus turn-walk.

Godot/Jolt completed all three real-physics traces but each exited after the
loop with `QSDK_R23D2_GJT_SDK_EXECUTION_INVALID`. The failure receipt groups
seven execution-accounting predicates and omitted the `sdk_authority_summary`,
so the exact failed subpredicate is not recoverable and is not guessed. With
only six complete reports, the frozen aggregate correctly closed
`invalid_or_incomplete`; commanded turning, bilateral turning, equivalence,
QSDK-R23, release, and physical-acceptance authority remain false. The exact
35-file attempt, all CAS objects, six cell results, three failures, two
nonregenerable-but-CAS-retained checkout images, and same-identity refusal are
pinned by
[`../turning/r23d2_physical_closure_v1.json`](../turning/r23d2_physical_closure_v1.json)
and audited by
[`../../tests/test_qsdk_r23d2_closure.ps1`](../../tests/test_qsdk_r23d2_closure.ps1).
QSDK-R23D3 subsequently implemented all three workers, fixed the Godot horizon,
passed its complete zero-world gate, and ran its full eight-world classic-
MuJoCo Stage A from clean pushed, exact-source-attested commit `e497785`. All
eight reports were execution-valid. Its frozen evaluator selected `NONE`: four
positive-heading cells passed, while all four negative-heading cells produced
signed yaw but failed maximum tilt. Stage B correctly remained unopened.
The supervisor then persisted the empty Stage B manifest as a blank newline
instead of JSON `[]`, so the immutable complete record is infrastructure-
invalid even though the Stage A nonselection is a bounded valid finding.
[`../turning/r23d3_physical_closure_v1.json`](../turning/r23d3_physical_closure_v1.json)
and [`../../tests/test_qsdk_r23d3_closure.ps1`](../../tests/test_qsdk_r23d3_closure.ps1)
pin the 38-file evidence tree, 70 frozen inputs, eight outcomes, terminal-settle
diagnostic, and closure interlocks. Only scientifically distinct successors
could proceed. R23D4 through R23D7 retained their respective implementation-
invalid or finite-negative outcomes; R23D8 reached exact-source-qualified
physics and closed as a valid finite Stage-A negative for its active neutral-
stance hold. R23D9 is the live, prospectively declared support-confirmed
irreversible-passive-handoff successor. Its three physical workers, serialized
supervisor, cold evaluator, CAS-first evidence path, and authorization-canary
boundary are implemented. After a retained pre-attestation Clippy repair,
source `ab729fab05fb63963448da85c1ea122fe3dd543a` passed full Godot-inclusive
conformance and published attestation SHA-256
`75fa0e5a07cd55bdd069cf29d41fa04196c76a0e218442b82e165c1e763f9571`.
The first production canary then exposed a missing uniform MuJoCo receipt field
before any model/world. The retained receipt-only repair changes no scientific
semantics, and the 92-binding complete zero-world gate re-passes. The repair is
clean-pushed and live-verified at
`575c6249f55a2fcad9aaf996f564043d51a9e7ac`; it remains dormant pending fresh
exact-source full-Godot attestation and all six production authorization
canaries.
No R23D9 world or outcome exists; QSDK-R23 remains missing.
The clean source-precondition report from exact commit `4e1ad48` is retained
at
`<evidence-root>\heading-command-4e1ad48\report.json`,
SHA-256
`616e3f3db912d0a53610bd1e7a36d086e7f77615331299bd710f9175ff37fbf8`,
and indexed by
[`../turning/heading_command_validation_manifest.json`](../turning/heading_command_validation_manifest.json).

The current retained 29-gate clean pushed-source checkpoint is
[`quadruped_readiness_checkpoint_manifest.json`](quadruped_readiness_checkpoint_manifest.json).
It indexes source commit
`bdbe43db0b4ab12760a297eea82be387629cfbe9` and the durable report at
`<evidence-root>\quadruped-sdk-readiness-bdbe43d\report.json`,
SHA-256
`6f5430aa8df68a24656faf997230c77a786b5e0da6d454728649a5aae07a89d3`.
That receipt records a clean tree equal to `origin/main`, a support matrix
consistent with its gate dispositions, no invalid proof, the exact `11/25`
current result, and the satisfiable
`22`-prerequisite / `3`-candidate-validation package flow.

The earlier two-stage satisfiability checkpoint is retained separately in
[`quadruped_two_stage_readiness_checkpoint_manifest.json`](quadruped_two_stage_readiness_checkpoint_manifest.json).
It indexes clean pushed source `fdddb21ba9e4815efd4660bd2838b12873eba05c`
and
`<evidence-root>\quadruped-sdk-two-stage-readiness-fdddb21\report.json`,
SHA-256
`a13b20c0db41a2c306ae8afaccffe50739dced2e07b555faed6416ae2c4cc1bd`.
It is the historical checkpoint that first established the structurally
satisfiable package flow. Historical reports are not rewritten; the current
checkpoint independently verifies the expanded 29-gate contract and its
`22`-prerequisite / `3`-candidate-validation partition.

The three contradicted requirements are rough terrain, external pushes, and
sensor noise. The complete QSDK-R05B selected-release-policy result remains an
immutable `33/36` historical negative with `36/36` execution integrity; it was
not repaired or reinterpreted. The separately preregistered R05E exact-finite
population passed `36/36` and now supplies the narrower positive required by
QSDK-R05. BW6N completed its 12 planned nuisance worlds but was rejected at
16/24 gates. A failure is evidence about its exact boundary, not permission to
erase or reinterpret that boundary.

The later development-selected `BW15F-B` successor also failed its separate
QSDK-R05C independent validation at `29/36` walking with `36/36` integrity,
mechanism, and combined application. Its immutable report is
`<evidence-root>\qsdk-r05c-c41522c\report.json`,
SHA-256
`f4318de42b7c206077d2b4301491567270274812cf7eaba8a8e816864c5f2015`,
and its closure is
[`../qsdk_r05c_independent_morphology_validation_manifest.json`](../qsdk_r05c_independent_morphology_validation_manifest.json).
R05C does not replace `BW5R-B` as the release-selected policy; it records that
the attempted successor also failed to earn promotion.

The current passed release requirements establish only:

- a public bounded six-axis quadruped compiler with explicit OOD refusal;
- selection identity for branch-free portable policy `BW5R-B` /
  `sporespore_balanced_wave_bw5r_b_v1`;
- a public source adapter-authoring contract and independent A0-A6 reference
  fixture, without engine C6 or physical authority;
- public SemVer, ABI-generation, strict schema-migration, and deprecation
  contracts proven by V0-V6 without release or physical authority;
- a public optional-provider adaptation seam with exact deterministic
  fallback and bounded, provenance-checked proposals, without a trained model
  or physical authority;
- an executable append-only Tier 2 episode/chapter/corpus/model/promotion
  architecture, without training or engine qualification;
- bounded cold-material evidence at the four authored Godot/Jolt friction
  values `{0.12, 0.48, 0.95, 1.50}`;
- exact-finite same-selected-policy Godot/Jolt morphology evidence at the
  twelve R05E one-axis-at-a-time descriptors under three frozen seeds, without
  interpolation, multi-axis, arbitrary-body, or continuous-volume authority;
- exact-finite same-policy Rapier/Parry C6 and material authority within the
  frozen PH1/XV2 boundary, without equivalence or release authority;
- exact-finite same-policy MuJoCo C6 and material authority within the frozen
  MV6/XV2 boundary, without equivalence or release authority; and
- a fail-closed negative claim matrix.

The separate BW19V-B successor track has closed BW20F stage 1 positive for
exact Godot/Jolt material characterization at
`{0.09, 0.37, 0.76, 1.18}`. Its one clean-source attempt completed `13/13`
characterization worlds and passed `23/23` gates; it opened zero locomotion
worlds and kept its future locomotion seeds sealed through stage 2. Stage 3 has
now outcome-exposed those seeds. Stage 1 authorizes only an
immutable adapter profile with coefficients `{0.07, 0.35, 0.73, 1.00}`.
The separate deterministic zero-world stage-2 publication has closed positive
with four exact profile IDs and canonical digests. Its retained report passes
`40/40` gates for 29 profiles and 30 adapter starts with zero worlds, samples,
or commands. The distinct stage-3
`BW20F-BW19V-COLD-MATERIAL-LOCOMOTION` / `BW20F-LOCOMOTION` campaign then
consumed one complete clean-source 17-world attempt at `452c11d`. The frozen
evaluator rejected it at `19/28` gates. All 12 treatments passed integrity,
mechanism, and nonzero application; `10/12` walked, while authored friction
`0.76` seeds `23001` and `23003` failed only bounded lateral drift. The
zero-friction no-SDK-native-actuation safety cell passed.

The run separately exposed an invalid control contract: its four zero-scale
controls correctly had zero residual application and
`combined_application_gate_passed=false`, but their active balanced-wave base
kept broad `physical_influence=true`. The synthetic result, worker, and
evaluator had required the opposite. That defect forbids control-conformance
authority; the two treatment failures independently suffice to reject the
all-treatments-must-pass finite decision. The identity is closed and cannot be
repaired or rerun.
BW20F does not alter release-selected BW5R-B, satisfy or replace QSDK-R08, or
grant release, locomotion material-robustness, continuous-friction,
cross-engine, or physical-acceptance authority. Its exact stage-1 evidence,
stage-2 report/closure, stage-3 rejected closure, published profiles, and claim boundary are
recorded in
[`quadruped_support_matrix.json`](quadruped_support_matrix.json).

They do not establish a released SDK, arbitrary quadrupeds, continuous
full-volume morphology, terrain, push, sensor noise or latency robustness,
same-policy physical C6 in Godot/Jolt, formal cross-engine equivalence, a
public release-packaged adapter kit, clean-room-validated record/replay,
isolated packaging, commanded turning, prone-to-standing, a trained or
physically qualified Tier 2 provider, Tier 3 online authority, or a completed
engine-neutral SDK.

R16 now has a complete source implementation:
[`../examples/quadruped_quickstart.py`](../examples/quadruped_quickstart.py),
[`../diagnostics`](../diagnostics),
[`../record_replay`](../record_replay), and
[`../docs/QUADRUPED_SDK_INTEGRATION.md`](../docs/QUADRUPED_SDK_INTEGRATION.md).
Its source runner passes eight positive/negative tests plus the quickstart,
diagnostics, verify, and replay CLIs with zero worlds and no physical
authority. R16 deliberately remains missing because its release requirement
is package-bound: the identical suite must pass from the future clean-room
candidate outside the game tree. The support matrix therefore distinguishes
`source_implemented=true` from `implemented=false`.

The source-only receipt is retained at
`<evidence-root>\sdk-developer-experience-d0da604\report.json`,
SHA-256
`e31ad6186bcae10b70593a2af7861bef8faeeefc548653a27f3e2cb5b973f016`,
and indexed by
[`../developer_experience_validation_manifest.json`](../developer_experience_validation_manifest.json).
It is a prerequisite implementation checkpoint, not QSDK-R16 release proof.

The full-program clean-room candidate stage is also currently blocked. It deliberately
excludes only R01, R16, and R20 because those three requirements must execute
against an isolated package. The other 22 required gates are candidate
prerequisites; 8 currently block that stage. Once those prerequisites pass,
the candidate artifact can be built without publication authority, used to
produce R01/R16/R20 evidence, and discarded. This removes the circular
dependency where final packaging required proof that could only be produced
by final packaging.

## Verify the boundary

From PowerShell at the repository root:

```powershell
.\sdk\test_quadruped_sdk_release_readiness.ps1

.\sdk\compile_quadruped_sdk_release_readiness.ps1

.\sdk\compile_quadruped_sdk1_milestone_readiness.ps1
```

The first command must end with:

```text
Quadruped SDK release-readiness tests passed: 33/33 contract gates classified, satisfiable two-stage package flow and fail-closed interlocks verified.
```

The full-program compiler currently reports `status=blocked`, `required=14/25`,
`missing=8`, `contradicted=3`, and `invalid=0`. To prove that a workflow
cannot proceed unless every requirement passes:

```powershell
.\sdk\compile_quadruped_sdk_release_readiness.ps1 -RequireReady
```

That command must throw while any required gate is missing, contradicted, or
invalid. It also refuses a dirty source tree or a source commit that differs
from `origin/main`.

The SDK1 compiler independently reports `status=blocked`, `required=14/20`,
`missing=5`, `contradicted=1`, and `invalid=0`. It is a milestone tracker, not
a release-authority bypass: even `20/20` would not itself authorize publication.

To retain a clean pushed-source receipt, use a new empty durable evidence
directory and the exact filename `report.json`:

```powershell
$receipt = "<evidence-root>\quadruped-sdk-readiness-<source-commit>\report.json"
.\sdk\compile_quadruped_sdk_release_readiness.ps1 -Output $receipt
```

The compiler refuses to overwrite an existing receipt.

## Two-stage packaging interlock

The final package path remains unusable while any release gate is blocked:

```powershell
.\sdk\package_quadruped_sdk.ps1 `
  -ReadinessReport <durable-ready-report.json> `
  -OutputDirectory <new-directory-outside-the-repository>
```

Before any output directory is created, the packager requires:

1. a retained report that authorizes release, packaging, and publication;
2. zero retained blockers;
3. a fresh live `-RequireReady` compiler pass;
4. exact retained/live source commit, `origin/main`, contract hash, release ID,
   and gate-disposition agreement; and
5. a clean current source tree equal to `origin/main`.

Only then does it stage tracked SDK files, hash-verify every copy, write
`PACKAGE_MANIFEST.json`, and atomically move the completed directory into
place. The package does not include LoColemotion laboratory scripts.

R01, R16, and R20 must be proven against an isolated artifact, so the contract
also defines a non-publishable clean-room candidate stage:

```powershell
.\sdk\compile_quadruped_sdk_release_readiness.ps1 -RequireCandidate

.\sdk\package_quadruped_sdk.ps1 `
  -ReadinessReport <durable-candidate-authorized-report.json> `
  -OutputDirectory <new-clean-room-candidate-directory> `
  -CleanRoomCandidate
```

`-RequireCandidate` passes only after all required gates other than R01, R16,
and R20 pass. The resulting artifact records
`artifact_role=clean_room_conformance_candidate`,
`release_authorized=false`, and `publication_authorized=false`, and carries a
separate `NOT_FOR_DISTRIBUTION.json`. It exists only to run package-bound
portable API, examples/record-replay, and isolation conformance. After those
three receipts are retained and entered into the release contract, the final
path still reruns `-RequireReady` and requires all 25 release gates.

## Retained evidence anchors

The release contract verifies the report content and exact SHA-256 at these
durable paths under
`<evidence-root>`:

- finite GQ15 selection:
  `temp-roots-2026-07-28\sporespore_gq15_selection_52ce84d_r1\20260728T000031496\report.json`,
  SHA-256
  `07c4a62cd906a08de344fddc16dfc3ac237a997d7089bae422fa3349bb5b3463`;
- GQ15 held-out repetitions:
  `temp-roots-2026-07-28\sporespore_gq15_heldout_r1_52ce84d\20260728T000617319\report.json`,
  `temp-roots-2026-07-28\sporespore_gq15_heldout_r2_52ce84d\20260728T000958498\report.json`,
  and
  `temp-roots-2026-07-28\sporespore_gq15_heldout_r3_52ce84d\20260728T001338434\report.json`;
- bounded cold material:
  `balanced-wave-bw5c-validation-dac405d\report.json`, SHA-256
  `6648c1473c97d2b7229ba0decd8881ca2d8f06e68ca9737d7255120dab2653da`;
- rejected nuisance campaign:
  `balanced-wave-bw6n-validation-e44a7e2\report.json`, SHA-256
  `8fe82a73b4bd8bae9789932fda47af2104b6204a4594a62c44998019ca949442`;
- Rapier/Parry C2-C5:
  `rapier-c2-c5-a2cf1a0-refresh\report.json`, SHA-256
  `e9f66bdbe96b920d0e12f7541658c2c17af575be4e504ba3475f266e06937fc1`;
- MuJoCo C0-C5:
  `mujoco-c0-c5-a2cf1a0-refresh\report.json`, SHA-256
  `a4f6aa753387918aa3e1bc42cbc24998da427fcf68e1b15b6bbffa6fa83b3be4`;
  and
- public adapter authoring A0-A6:
  `adapter-authoring-63fea14\report.json`, SHA-256
  `f2572ed28cc2475b69b9d6891f2bec14a6e54bb2aca1ac8cfb9f26763b546a67`;
  and
- SDK versioning V0-V6, refreshed for all 27 C symbols and 35 schemas:
  `sdk-versioning-211cb78\report.json`, SHA-256
  `875e16efe7feb7c18283231d9f096c39d67cd72c9a7c003770acd0efd1a7ef09`;
- optional adaptation provider A0-A7:
  `adaptation-provider-211cb78\report.json`, SHA-256
  `e8ddc4fd0da1fe85346251103f8c6a1e9fc9c7e9121902d2cafb8fa5390f3b86`;
  and
- Tier 2 architecture T0-T6:
  `tier2-adaptation-architecture-211cb78\report.json`, SHA-256
  `6bc9951d1f625d61ce378cbb0ff6ca87a59b63d198bbef5a5bd4dc881f87eb2d`.

GQ15 is retained as an informational prerequisite because it is real finite
Candidate 35 evidence, not same-policy independent morphology evidence for
the selected portable `BW5R-B` controller. Rapier and MuJoCo are likewise
informational because their C0-C5 transport/host conformance does not grant
physical C6 authority.

MuJoCo VH4 now adds a positive exact-finite host characterization: all 24
signed target/load/initial-condition cells and 43,200 temporally explicit
internal traces passed with corrected split-step force and momentum gates. This
is a prerequisite for a selected-policy MuJoCo campaign, not selected-policy
C6 itself. MuJoCo walking and cross-engine equivalence therefore remain absent
from the release boundary.

## Mandatory no-world experiment preflight

Every future physical successor must also pass
[`../../tests/test_sdk_full_integrity_gate_satisfiability.gd`](../../tests/test_sdk_full_integrity_gate_satisfiability.gd)
before opening a world or creating a durable campaign directory. That test
executes each declared policy through the real portable planner,
endpoint-force mapper, bounded-influence path, synthetic perfect result, and
the exact production analyzer. A policy that cannot pass its own integrity
gate on a perfect semantic witness is unrunnable.

For a policy that adds a physical stability contribution under full native
authority, the witness must also invoke the actual combined adapter application
path and prove that portable base plus bounded contribution produces the exact
declared motor-write count, nonzero effective influence, zero application
failures, and zero direct body writes. The campaign runner must then exercise
its own final aggregate/report code against a complete perfect synthetic
matrix, including source resolution, serialization, SHA-256, readback, and the
same final integrity predicate. Policy-only success is insufficient if the
launcher or retained-report gate cannot accept a perfect campaign.

The perfect matrix is necessary but cannot prove that nonzero counters survive
aggregation: both a correct sum and a missing-value-to-zero defect can produce
zero. Every successor must therefore run a second deliberately nonzero report
canary through the same ordered in-memory object type, aggregation,
serialization, readback, and reconciliation path. Missing fields, nonnumeric
values, NaN/infinity, counter overflow, or any exact canary mismatch fail
closed before the first world. The shared implementation is
[`../experiment_result_integrity.ps1`](../experiment_result_integrity.ps1),
and its zero-world regression is
[`../../tests/test_experiment_result_integrity_preflight.ps1`](../../tests/test_experiment_result_integrity_preflight.ps1).

The clean pushed-source `6/6`, zero-world checkpoint is indexed by
[`../policy_semantic_preflight_checkpoint_manifest.json`](../policy_semantic_preflight_checkpoint_manifest.json).
It explicitly caught the obsolete BW12E whole-overlay exact-zero declaration
and rejects missing semantic witnesses. It is launch-integrity evidence only,
not a walking or physical-acceptance result.

## Updating this boundary

Do not turn a missing or contradicted gate into `"passed"` by editing the
support matrix alone. First produce the prospective, source-bound evidence
named by the requirement; retain its report at a durable path; record its
SHA-256 and exact predicates in the contract; then rerun the tests and
compiler from clean pushed source.

Post-quadruped work—six/eight/many legs, bipeds, running, snake/serpentine
movement, and radial sea-urchin pogo locomotion—stays outside this submission
contract. Its roadmap is retained in
[`../../docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md`](../../docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).

## Receipt-v5 launch-satisfiability requirement

The mandatory pre-world test now emits
`sporespore_full_integrity_gate_satisfiability_receipt_v5`. A future
quadruped physical runner must execute and strictly reconcile that receipt
before creating its retained output directory or constructing any world.

Receipt v5 is stronger than a hand-authored perfect report. It uses the same
production execution-mode resolver as the physical loop, checks every BW13P
policy at each declared signed-offset transition, and runs the worst signed
route over the full `3,232`-step GQ15 horizon through the real native
controller and portable planner. It then feeds each declared policy's real
semantic, endpoint-map, bounded-influence, combined-application, and typed
unavailable receipts into the exact production aggregate analyzer with zero
error, mismatch, failure, violation, legacy-write, and safe-disable counts.

The required zero values are defects, not mechanism activity. A policy that
declares active influence must still produce nonzero real activity and exact
eight-motor application. The receipt is invalid if either the mechanism cannot
act or the analyzer cannot accept a perfect result.

This boundary was added after the closed BW13P-R1 family exposed a production
routing gap that the earlier one-step gate missed. Its immutable negative
evidence and report hashes are indexed by
[`../balanced_wave_bw13p_r1_closure_manifest.json`](../balanced_wave_bw13p_r1_closure_manifest.json).
The old signed-initial-memory route is now an explicit negative control and
must fail at synthetic step zero. None of this supplies physical walking,
balance, robustness, cross-engine C6, release, or publication authority.

BW13P-R3 is now a closed negative development family, not a release input.
All `144/144` execution/mechanism/application receipts are valid, but none of
the three treatment arms strictly beats the A control's one walking failure.
The exact four reports, selection, and `468/468` referenced artifact hashes
are pinned in
[`../balanced_wave_bw13p_r3_closure_manifest.json`](../balanced_wave_bw13p_r3_closure_manifest.json)
and audited by
[`../../tests/test_bw13p_r3_closure.ps1`](../../tests/test_bw13p_r3_closure.ps1).
This grants no walking, balance, independent morphology, C6, or release
authority. R05C remains sealed because there is no R3 treatment to validate.

BW14V is now a closed negative development family. All `72/72` execution,
mechanism, and application receipts are valid, but the branch-free portable
forward-velocity foot-placement treatment collapsed from the A control's
`33/36` walking conjunctions to `0/36`, with `344` failed walking gates and
`194` release timeouts. The frozen selector records
`family_selected=false`; no treatment advances to independent validation.

The exact reports, zero-rerun recovery receipts, selection, `228/228`
retained artifact hashes, and unopened R05C/friction reservations are pinned
in
[`../balanced_wave_bw14v_closure_manifest.json`](../balanced_wave_bw14v_closure_manifest.json)
and audited by
[`../../tests/test_bw14v_closure.ps1`](../../tests/test_bw14v_closure.ps1).
This result changes no support-matrix cell and grants no package, publication,
walking, balance, cross-engine, or release authority. A new controller
hypothesis requires a distinct prospectively frozen identity.

Rapier PH1 is one such distinct prospective identity, but it is not a release
input. It preserves TR1's successful missing-foot DLS search and adds captured
pose plus existing-receipt heading hold for contacting limbs. Its full
`3172`-step synthetic report and `33/33` controls pass at zero worlds. No PH1
physical result exists, so Rapier selected-policy C6, walking, cross-engine
equivalence, release, and physical-acceptance authority remain false.

PH1 has since consumed its one exact-source physical process and closed as a
complete valid positive. Its exact s169 pose-hold-restoration technical
commissioning and declared finite single-body walking contract pass, including
`1080` consecutive terminal four-contact steps, `1.4770498276 m` evidence
advance, `0.0038630388 rad` final yaw drift, `0.1228043884 rad` maximum tilt,
and zero torso-contact steps. That closes PH1 without promoting it into a
release input: its preregistered release-selected C6, independent-validation,
wider-morphology, robustness, equivalence, release, and physical-acceptance
claims remain false. Any promotion requires a distinct prospective campaign.

Closed MuJoCo MV3 is also not a release input. From clean pushed source
`a52af71de64f43b8d742d17d4cf9905b778a134f` and a fresh matching full-Godot
V2 attestation, its sole process retained all `2992` steps and a complete
report. The frozen combined walking-and-integrity decision is a valid negative:
policy receipt projection and declared limb-memory order fail on all `2992`
rows, and the terminal snapshot has only three contacts. A deterministic
order-normalized diagnostic preserves a real `1.3995530921 m` evidence-window
and `1.8059354059 m` total forward-locomotion observation, with all reconstructed
physical thresholds except terminal stance passing, but it may not replace the
primary result. MuJoCo selected-policy C6, accepted walking, same-policy
cross-engine evidence, release, and physical-acceptance authority therefore
remain missing. MV3 is consumed and cannot be rerun.

Closed MuJoCo MV4 is also not a release input. It rejected `31/31` zero-world
controls and passed an exact-source full-Godot V2 suite, but its sole process
then closed implementation-invalid. The walking-phase controller reached its
evidence-limit transition; the first terminal-restoration composition failed
before terminal actuation because production kinematic vectors are `x/y/z`
objects while the restorer and synthetic canary assumed lists. No complete
report, metric, or scientific result survived. MV4 is immutable and cannot be
rerun. Consequently it does not change `QSDK-R15`: accepted MuJoCo walking,
same-policy physical C6, cross-engine evidence, release, and
physical-acceptance authority remain missing.

Prospective MuJoCo MV5 also does not satisfy `QSDK-R15`. It is a distinct
implementation-repair freeze that preserves MV4's physical hypothesis while
strictly normalizing production `x/y/z` vectors. Its complete zero-world audit
rejected `37/37` controls and created no model, data object, world, evidence, or
physical authority. The support matrix records MV5 as frozen and prospective,
with zero physical attempts. `QSDK-R15` remains `missing` until a complete
accepted same-policy MuJoCo physical campaign exists.

MV5 has now consumed and closed implementation-invalid, so the prospective
entry described above is historical rather than open. Its clean pushed process
reached post-loop report assembly but retained no report after a PH1 closure
field-name `KeyError`. A fixed-loop control-flow inference is not a physical
metric or evaluator decision. `QSDK-R15` therefore remains `missing`, with no
accepted MuJoCo walking, selected-policy C6, cross-engine, release, or physical
authority.

Closed MV6 still does not satisfy `QSDK-R15`, but it does replace the old
prospective status with a bounded positive result. From clean pushed source
`3ad4d5fb...d3b9`, one exact-s169 MuJoCo world retained all 2,992 trace rows
and passed the unchanged evaluator: `1.3995530921 m` evidence advance, zero
torso-ground contacts, four-contact acquisition at step `1939`, and the
required 360-step hold within `1053` consecutive contact steps. The closure
audit independently reconstructs those values and refuses a same-identity
rerun.

The support matrix therefore records finite MuJoCo selected-policy walking as
accepted for MV6's declared exact-s169 contract while keeping
`selected_policy_physical_c6`, formal cross-engine equivalence, release, and
physical authority false. `QSDK-R15` specifically requires release-selected
same-policy physical C6 with its broader validation contract, so it remains
`missing`. A distinct prospective promotion campaign is required.

## R23D5 turning successor zero-world implementation

R23D5 is prospectively declared as the dependency-closed successor to the
consumed zero-world R23D4 identity. It retains the unexposed R23D4 scientific
estimand and numeric gates while requiring three exact worker dependency
manifests (`21` unique paths and one removal canary per path) plus retained
zero/one/many/mixed/malformed terminal-marker classification for each native
worker family. Its three native workers, evaluator, shared dependency composer,
retained marker classifier, trace-CAS transport, runtime materializer, and
one-shot supervisor pass the complete zero-world gate. The cold gate covers
`21` dependency removals, `15` marker cases, all `11` worker identities, and
eight evaluator controls with zero models/worlds. A clean push and source-exact
full-Godot attestation are still required before Stage A. QSDK-R23 and every
turning, equivalence, prone-to-standing, release, and physical claim remain
false.

R23D5 has since consumed its one-shot identity and is not a release input.
Clean pushed source `f237809...aaa3a2` passed full Godot-including conformance,
then both MuJoCo Stage A workers completed the `2992`-step turning-controller
horizon and crashed on restoration step zero. The BW5R-B turning receipt does
not contain `forward_velocity_foot_placement`; the reused MV6 restorer was
derived for BW15F-B and unconditionally required that policy-specific member.
The complete campaign is implementation-invalid, the selector is `INVALID`,
and Stage B remained unopened. The immutable closure and audit retain all 22
evidence files and same-identity refusal. QSDK-R23, turning, cross-engine
equivalence, prone-to-standing, release, and physical authority remain false;
only a distinct policy-compatible R23D6 successor may continue.

## R23D6 turning successor implementation-qualified at zero worlds

R23D6 is now prospectively declared under a new identity. It retains R23D5's
still-unresolved two-stage estimand and unchanged numeric gates, but replaces
the invalid cross-policy composition with an explicitly BW5R-B-only derivation.
The registered linear bilateral stride law has no forward-velocity placement
term; the declaration therefore forbids silently reading or defaulting the
BW15F-B-specific receipt member.

The declaration audit pins five derivation authorities, evaluates five
independent algebra canaries, requires eight mutation controls, and freezes an
exact production-shaped release-core restoration-step-zero preflight. The
implementation now drives both signed BW5R-B arms through that real release
core, emits all eight terminal commands per arm, rejects every frozen
mutation, and fails closed on a wrong policy, transform, or unexpected
forward-placement member.

Classic MuJoCo, Rapier/Parry, and Godot/Jolt now have distinct R23D6 workers,
with a production evaluator, shared `23`-file dependency closure, retained
terminal-marker classifier, trace-CAS transport, runtime materializer, and one-
shot supervisor. The complete zero-world gate passed all `23` dependency
removals, `15` marker cases, all `11` possible worker identities, eight
evaluator tests, exact external runtime bindings, and direct-physical refusal.
It constructed zero models and zero worlds.

This is implementation qualification, not a locomotion result or release
input. The implementation still requires an isolated clean push and source-
exact full-Godot attestation before its frozen two-cell MuJoCo Stage A can
open; the nine-cell three-engine Stage B remains conditional on a valid Stage
A selection. QSDK-R23, turning, equivalence, prone-to-standing, release, and
physical authority remain false.

Canonical integration runs the R23D6 declaration, strict restoration,
dependency/marker, implementation, evaluator, and native-worker preflights
directly. The aggregate supervisor is intentionally separate because both it
and canonical conformance independently own the global operation mutex. A
precommit attempt that nested them correctly failed closed; an executable
audit now forbids that route. The final uninterrupted non-Godot canonical
suite passed in `1755.1 s`, followed by a standalone complete aggregate pass in
`316.1 s` with `74` source bindings, all three workers, `23` dependencies,
`15` marker cases, eight evaluator tests, and zero models/worlds.

## R23D6 physical closure: valid NONE at Stage A

The prospective implementation above was isolated at clean pushed commit
`acf0511fe9c24cd0439107ca3f8510054629263d`. Full Godot-including conformance
passed in `1964.5542466 s`; its independently verified attestation SHA-256 is
`aa20b6b899b73f0fd169dee9dd04c0014344482c18f2e06ed9dbedd81082ba14`.
The authorized one-shot supervisor then completed both serial MuJoCo Stage A
cells. Both reports were execution-valid, retained exactly `3772` trace rows,
and passed signed-yaw response with deltas `+0.0842283890` and
`-0.1525791244` rad.

Both failed the frozen terminal-restoration outcome. The front-left foot stayed
airborne for all `180` acquisition steps in both cells. The positive arm never
held four contacts during active restoration and captured only `6/8` pose
memories. The negative arm first acquired four contacts at step `242`, held
them for at most `288/360` consecutive steps, and reached `0.6773622330` rad
tilt during passive settle against the `0.6`-rad ceiling. The evaluator
returned `valid_none_stage_a`; selector `NONE` forbade Stage B, so zero Godot,
Rapier, or additional MuJoCo confirmation worlds opened.

[`../turning/r23d6_physical_closure_v1.json`](../turning/r23d6_physical_closure_v1.json)
and [`../../tests/test_qsdk_r23d6_closure.ps1`](../../tests/test_qsdk_r23d6_closure.ps1)
bind the 26-file attempt tree, all CAS payloads, both reports and traces, the
source-exact attestation, pinned source blobs, contact-mask diagnosis, and same-
identity refusal. The audit also found that two unchanged staging row arrays
had not been copied into CAS; both were retained post-attempt before closure,
with no physics/evaluation replay and no attempt-tree mutation.

This is a valid finite scientific negative for the exact R23D6 terminal-
restoration policy. It is not portable turning evidence. QSDK-R23, formal
cross-engine equivalence, canonical prone-to-standing, and release remain
false. R23D6 is consumed; only a new R23D7 identity with a scientifically
distinct terminal-stance acquisition and passive-stability handoff may proceed.

## R23D7 neutral-stance successor implementation-qualified at zero worlds

R23D7 preserves the complete R23D6 turning estimand, selector, schedule, and
numeric outcome gates under a new identity. It changes only the failed terminal
mechanism: every morphology-ordered actuator targets the authored zero-radian
joint coordinate through
`clamp(8 * (0 - position) - 0.65 * velocity, -0.35, +0.35)`. Contact does not
select targets, and native position targets or direct physics-state mutation
are forbidden.

MuJoCo, Rapier/Parry, and Godot/Jolt have distinct native worker routes. The
complete aggregate zero-world gate passes the pure five-canary/ten-mutation
design audit, `25` dependency removals, `15` retained-marker cases, all `11`
possible worker identities, eight evaluator tests, exact runtime
materialization, direct-physical refusal, and worktree invariance. It builds no
model and opens no world.

This is implementation qualification only. The implementation still requires
an isolated clean push and source-exact full-Godot attestation before the
frozen two-cell MuJoCo Stage A may open; the nine-cell three-engine Stage B is
conditional on a valid Stage A selection. QSDK-R23, turning, equivalence,
prone-to-standing, release, and physical authority remain false.

The closure-integrated canonical `-SkipGodot` suite passed in `1664.8 s` after
the generated evidence-mode inventory was advanced from 72 to 73 audits for
the new pinned-blob closure verifier. The run opened no physical world and did
not mutate the consumed attempt.

## R23D8 closure and R23D9 live turning successor

R23D8 repaired the R23D7 dependency-authority failure, reached clean pushed
exact-source-qualified physics, and passed all six production authorization
canaries. Both serialized MuJoCo Stage-A cells completed execution-valid
`3,772`-row traces and produced correctly signed yaw. Both also remained on all
four contacts for every one of the `240` passive-settle steps, but neither
passed the frozen active neutral-stance hold. Selector `NONE` correctly kept
all nine three-engine Stage-B cells unopened. R23D8 is an immutable finite
negative for that exact terminal policy and cannot be rerun or rethresholded.

R23D9 is the distinct live successor. It retains the complete walking,
turning, safety, selector, and `780`-step terminal challenge, but prospectively
hands off from bounded neutral acquisition to irreversible zero actuation after
`30` consecutive completed all-four-contact observations. Three physical
workers, the serialized two-cell Stage-A/conditional-nine-cell Stage-B
supervisor, cold evaluator, CAS-first evidence path, and production
authorization-canary boundary are implemented. The initial complete zero-world
gate passed over `41` worker dependencies, `88` source bindings, all `11`
native identities, eight evaluator tests, and fifteen terminal-marker cases.
No physical process, model, attempt, or world was opened.

The first exact-source full-Godot run from clean pushed authority closure
`c2a49b1c2cb513122c8ab74e77542cfb4151b8aa` failed closed after `368.4 s` at
Rust Clippy before full Godot qualification. It published no attestation,
started no R23D9 process, model, attempt, or world, and consumed no physical
identity. The incident declaration and audit pin the exact `35,253`-byte log at
`<evidence-root>\full-godot-conformance-v2-c2a49b1-20260809T084524Z\conformance.log`,
raw SHA-256
`aab25a7ba4ac1363b4a5667cc59159e00529e34449b769003983cae56f7e7814`.

The repair changes only the Rust observation helper from a five-member tuple to
a private named structure. Cargo formatting and workspace-wide offline Clippy
with warnings denied pass; every scientific semantic remains fixed. The
corrected complete zero-world gate re-passed in `154.3 s` over `41` unique
worker dependencies, `90` exact source bindings, all `11` native identities,
eight evaluator tests, fifteen terminal-marker cases, and zero physical
processes, attempts, models, or worlds.

This remains a dormant implementation boundary, not a turning result. The
repaired implementation is clean-pushed and independently matched at local
`HEAD`, `origin/main`, and the live GitHub branch as
`bc385660c85f0208a42e10431cb98bb279a993d6`. A fresh source-exact full-Godot
attestation and all six production authorization canaries remain required
before its one-shot MuJoCo Stage A. QSDK-R23, portable turning, formal cross-
engine equivalence, prone-to-standing, release, and physical acceptance remain
false.

## R23D9 full attestation and retained production-canary receipt incident

Clean live authority closure `ab729fab05fb63963448da85c1ea122fe3dd543a`
passed full Godot-inclusive conformance in `1606.825641 s`. The exact-source V2
attestation is retained under
`SporeSpore_Evidence/full-godot-conformance-v2-ab729fab-20260809T090941Z`, raw
SHA-256 `75fa0e5a07cd55bdd069cf29d41fa04196c76a0e218442b82e165c1e763f9571`.

The first production-canary verifier then failed before model construction:
MuJoCo's positive zero-model receipt omitted `returned_before_model`, which
Rapier and Godot already emit. A retained second invocation reproduced the
failure. Across both invocations, only two MuJoCo authorization-preflight
processes ran; zero canaries completed, zero mutated-binding canaries ran, zero
models/worlds opened, and the physical identity stayed unconsumed.

The incident declaration and audit bind the old source, attestation, durable
reproduction, and receipt-only repair. Adding `returned_before_model: true` to
MuJoCo changes no controller, terminal policy, threshold, schedule, selector,
adapter physics semantics, or physics equation. The expanded complete zero-
world gate re-passed in `166.0 s` with `92` source bindings, `41` worker
dependencies, all `11` identities, eight evaluator tests, fifteen marker cases,
and zero models/worlds.

The `ab729fab` attestation cannot authorize the changed receipt source. The
repair is clean-pushed and independently matched at local `HEAD`, `origin/main`,
and live GitHub as `575c6249f55a2fcad9aaf996f564043d51a9e7ac`. Fresh source-
exact full-Godot attestation and all six production canaries remain required
before Stage A. QSDK-R23, portable turning, formal cross-engine equivalence,
prone-to-standing, release, and physical acceptance remain false.

## R23D9 consumed physical closure

Source `74f45053c69cd264e60e0927d9eaf4bcd8a43038` passed exact-source
full-Godot attestation and all six production authorization canaries. R23D9
then consumed its one-shot identity in two serialized MuJoCo Stage A worlds.
Both workers retained execution-valid `3,772`-row traces and passed signed-yaw
response; one passed the walk-plus-handoff outcome and one lost support after
passive handoff.

The evaluator exited zero but emitted generic marker
`QSDK_R23D9_EVALUATION`; the supervisor required
`QSDK_R23D9_STAGE_A_EVALUATION`. The supervisor failed closed after byte
retention and sealed `SUPERVISOR_INFRASTRUCTURE_EXCEPTION`. No authoritative
selector or campaign result exists and Stage B never opened. The closure at
[`../turning/r23d9_physical_closure_v1.json`](../turning/r23d9_physical_closure_v1.json)
and audit at [`../../tests/test_qsdk_r23d9_closure.ps1`](../../tests/test_qsdk_r23d9_closure.ps1)
forbid a same-identity rerun and require a scientifically distinct R23D10 with
exact evaluator CLI marker integration canaries. The release scoreboard is
unchanged at `10/25`; QSDK-R23, portable turning, formal cross-engine
equivalence, prone-to-standing, release, and physical acceptance remain false.

## R23D10 prospective stage-zero turning successor

R23D10 freezes a scientifically distinct support-and-pose-confirmed active
quiescent taper. Four-contact support, torso tilt at most `0.035` rad, and
maximum joint error at most `0.32` rad begin a `120`-step linear velocity-
authority taper. Any coarse-gate failure resets acquisition. Handoff requires
the complete taper plus `0.01` rad tilt and `0.20` rad joint-error confirmation,
within a `540`-step active cap and before at least `360` irreversible passive
steps in the `900`-step terminal window.

The exact declaration SHA-256 is
`8a367a311b1133737037900bb0922f14a3c31d0e3f063fc39bb2fc554f263b3b`.
Its pure oracle passes five canaries and sixteen mutation refusals. The
declaration audit also pins the consumed R23D9 closure, both conditional
campaign stages, and distinct exact Stage A and complete evaluator CLI marker
prefixes. R23D10 currently has zero native engine routes, workers, models, or
worlds and no physical authorization. The `10/25` scoreboard and every open
turning, equivalence, prone-to-standing, acceptance, and release gate therefore
remain unchanged. Native three-language mirrors and an executable two-command
CLI integration canary are the next zero-world implementation boundary.

## R23D10 stage-one native temporal implementation

The stage-zero tree is preserved at clean pushed commit `6b39e1d`. Stage one
now supplies independent MuJoCo/Python, Rapier/Rust, and Godot/Jolt/GDScript
mirrors of the frozen terminal scheduler. The aggregate audit executes `11`
identity preflights, `15` canaries, `48` mutation refusals, and `3` physical-
route refusals before model construction. It also invokes both exact evaluator
CLI commands and observes their distinct required prefixes with zero generic
marker emissions.

The native contract SHA-256 is
`232eb24838c2a12ea4cbf6d88954c999415319b154891841f472cbe90aa9881c`;
the audit SHA-256 is
`0f3231225e5ba258034cb702d1ae483fc14f6a93c5eeb6092335f5dd7a629522`.
There are still no physical workers, production evaluator, supervisor, models,
worlds, or physical authorization. Accordingly the release score remains
`10/25`, and turning, equivalence, prone-to-standing, acceptance, and release
remain false. A production-shaped worker/evidence layer and its complete zero-
world gate are required before a separately pushed and attested physical
campaign can be considered.

## R23D10 stage-two production evidence boundary

The stage-one native temporal boundary is preserved at clean pushed commit
`60f475352fde6958798b4a0d7c21fb0dc354f87b`. Stage two adds the exact
production trace, content-addressed publisher, cold evaluator, and aggregate
selector without adding a physical route. Each of the `11` declared identities
has a canonical `3,892`-row shape: `2,992` controller rows plus every one of the
`900` terminal taper rows. Retained bytes and manifests are revalidated and all
terminal receipts are independently replayed. Existing trace staging paths are
never overwritten, retained paths must match their digest-derived CAS
hierarchy, and both evaluator commands require the exact expected source
commit for every report.

The stage-two contract SHA-256 is
`f307facd3c1051eb1313831dfd2e8236c71fc775df832d5d3e6ee440aa0578be`;
the executable gate SHA-256 is
`a114e05568f77c850aa06a9c5dd1804bae07e3442b10f8a313c9890e66b054c3`.
It passes five trace and nine evaluator tests, including actual execution of
both exact stage-specific CLI markers and explicit absence of the generic
marker that consumed R23D9.
The exact stage-two tree is clean-pushed at
`94f724adecd1ab6d95339dc8a3224fad2a2d586d`; its Git-tree closure audit SHA-
256 is `2f896bb4d07ba01c302636b0eb60dbf62a879c76ffd86d1912d243e8c745db05`.

There are still zero physical workers, supervisors, models, worlds, or physical
authorization. The release score remains `10/25`; turning, equivalence, prone-
to-standing, acceptance, and release remain false. A separately frozen worker,
dependency, authorization, and supervisor layer must pass its complete zero-
world gate before any physical campaign.

## Canonical release-claim refusal gate

The release-readiness suite is now an explicit member of the CAK1 global
physical-authorization kernel and canonical `sdk/run_conformance.ps1`. It
recompiles the current release/support declarations, verifies the blocked
scoreboard, rejects forged release and clean-room-candidate authorization, and
proves that blocked input creates no package directory. This integration does
not satisfy a missing release gate or change the `10/25` score; it makes the
existing fail-closed result mandatory in every future full conformance route.

## Historical turning boundary: R23D27 closed negative

R23D27 executed its three preregistered Rapier real-physics worlds from clean,
pushed source after a scoped `17`-gate attestation and adoption check. All three
worlds were execution-valid. The uncommanded reference passed, while both
commanded-turn worlds fell and therefore failed qualification. Retained traces
show that the direction-neutral stability guard activated exactly as declared,
but its tilt-triggered authority reduction began too late and was insufficient
to arrest the accumulated roll.

The campaign is closed as `valid_complete_negative` with selected candidate
`NONE`; it does not establish Rapier turning, three-engine turning, or cross-
engine equivalence. No release gate changes: the scoreboard remains `10/25`,
and turning, prone-to-standing, equivalence, acceptance, and release remain
blocked. No successor physical series is currently authorized.

## Current recovery boundary: R24D13 qualified and authorized; physics unopened

R24D12 remains consumed-invalid after its sole one-step Godot/Jolt attempt was
rejected on authored-binary64 versus native-float32 inertia identity. R24D13 is
the distinct prospective development successor; it does not repair or promote
those bytes. It freezes exact native/full-precision serializer identities for
inertia, maximum motor impulse, and solver timestep, with zero tolerance and no
empirical acceptance threshold.

The new zero-object production route constructs the full evaluator-shaped
report directly in GDScript and exercises the exact custom runtime, native
`real_t` storage, full-precision serializer, evaluator, termination protocol,
and retained-artifact path without constructing a physics world. One failed and
one passing development calibration remain separately retained.

Exact clean-pushed source `1231701240fe5c85f59ec74a610dc806ad6e2a2a`
then passed the six-stage official preflight in about twelve seconds with actual
`0 worlds / 0 builds / 0 solver steps`. Its `20` files span `17` unique
digests and `15` embedded CAS references across `13` unique objects; receipt
`sha256:9606de7e82b6d73dc91c14de8f8bec076d7a2e6ca0b5c52d85bf00018b025491`
is closed and mutation-audited. A separate direct-child parent-bound record now
authorizes one world, four isolated cells, one solver step, and four retained
samples with no rerun. Physics remains unopened pending the production
authorization-only check. Readiness remains `11/20` for SDK1 and `11/25` for
the full program.

## Historical turning boundary: R23D42 consumed

R23D42 passed its focused `17/17` zero-world qualification from clean-pushed
source `91db855` and ran all nine serialized real-physics worlds on fresh seed
`21510`. Godot/Jolt's repaired trace schema worked and all three cells passed
the common walking gates, but the frozen bilateral turning rules failed.
MuJoCo's three cells passed both walking and turning. Rapier's three worlds
completed, then their workers failed at production trace-CAS retention; the
wrapper did not preserve the evaluator's stdout exception, so the lower cause
remains unresolved.

Postclosure validation and CAS publication of the exact Rapier rows cannot
repair the official failure and also found the positive conditioned response
below the unchanged `0.01 rad` floor. R23D42 therefore closes
implementation-invalid for the three-engine question. It adds a bounded valid
Godot/Jolt walking/turning negative and a bounded valid MuJoCo positive, not
portable or three-engine turning. QSDK-R23, equivalence, prone-to-standing,
acceptance, and release remain blocked. The identity cannot rerun; no successor
is open and the physical series is paused.

## Current QSDK-R01 boundary: bounded bridge qualified, candidate still blocked

Clean, pushed, live-equal implementation `fa3e6aae` refreshes the portable API
source proof and connects it to the bounded SDK1 17+3 candidate authority. All
eight real source cells pass: 58 Rust/C/Python symbols match, load, and are
invoked; 193 Rust and 21 Python ABI tests pass; and ten deliberate source
mutations are rejected. The exact package projection contains 1,467 files
totaling `31,157,392` bytes. The retained 4,119-byte report's SHA-256 is
`ee2a7bbdebc432449b152c3233522f758c445be547260fc900cef979029ed087`.

The bridge uses a separate `sdk1_clean_room_conformance_candidate` role and
`bounded_sdk1_17_plus_3` scope. It requires all 17 non-package milestones
passed, M01/M11/M15 still missing, no blocker conditions, the exact six SDK1-
deferred full-program gates, clean source, and matching SDK1 mapping, release
contract, and support matrix. The packager re-runs the live compiler before
copying files. Package-side R01 and R16 consumers verify the external report,
manifest, warning, source commit, and packaged authorities. The existing full-
program candidate path retains its distinct role and stricter prerequisites.

This closes two prospective wiring defects without consuming a package: the
bounded compiler previously had no accepted packager path, and the unexecuted
R01 consumer compared the release-authority hash against the portable-API
contract rather than the release contract. One exact report shape passes the
shared validator; 13 mutations, forged retained source, and conflicting modes
are refused. The normal 33-gate readiness suite remains green, and no rejected
test creates an artifact.

The current
[manifest](../portable_api/portable_api_validation_manifest.json) and
[bridge closure](qsdk_r01_sdk1_candidate_bridge_closure_v1.json) preserve the
new report plus the earlier `5fe95a60` and `767194d5` reports. After the
separate M08 decision, M07, M14, and M20 still block candidate creation.
Consequently `QSDK-R01` and
`SDK1-M01` remain false, release/publication remain unauthorized, and scores
are SDK1 `14/20` and full program `14/25`. No physics engine, model, world,
native read, or solver step ran in the bridge or M08 decision.

## Current QSDK-R13 boundary: exact-finite Godot/Jolt SDK1 envelope

The
[QSDK-R13 decision](qsdk_r13_godot_jolt_sdk1_envelope_decision_v1.json)
closes M08 by composing four immutable, already-observed evidence slices:
C2-C5 adapter/mechanics foundations; R05E exact-point morphology walking;
BW5C reference-body material walking; and the separate R23D78 turning and R173
prone-to-standing capability decisions. Its
[executable audit](../conformance/qsdk_r13_godot_jolt_sdk1_envelope_decision.py)
checks the exact retained bytes, parent Git objects, adopted measurements,
readiness ledgers, and 25 overclaim mutations without opening a physics world.

The walking claim is a union of two tables, not their cross-product. R05E
supports twelve named one-axis morphology points at one named material profile
and three exact seeds. BW5C supports four named nonzero material profiles on
the reference body. It does not follow that every R05E body supports every
BW5C material. Interpolation, multi-axis morphology combinations, continuous
regions, and arbitrary quadrupeds remain unsupported.

The capability rows are equally narrow. R23D78 supports the exact basic-
turning population; R173 supports the exact nominal ventral-prone-to-stance
task through a separate V6 recovery controller. Neither proves kick/push entry,
force-aware recovery, general self-righting, population reliability, or
controller/effect equivalence. The original C6 (`10/12`) and C6R (`6/8`)
results remain negative and immutable.

The support-matrix field `claim_boundary.cross_engine_c6=true` means only that
each of the three advertised engines now has its own bounded finite SDK1
envelope. It is not a claim that those engines behave the same. The matrix
keeps formal comparative inference and equivalence false. QSDK-R13/M08 moves
the ledgers to `14/25` and `14/20`; it grants no candidate, physical-
acceptance, release, or publication authority.

## Preceding M05 boundary: R05E implemented at zero worlds; qualification pending

The additive release ledger now records the
[`R05D exact-finite successor design`](../qsdk_r05d_exact_finite_morphology_successor_design_v1.json).
The content-bound support matrix and SDK1 mapping remain byte-identical to the
R173 twelve-of-twenty checkpoint.
It preserves the rejected R05B and R05C populations and refuses to reinterpret
their non-monotonic shell outcomes as a supported inner box. R05E will retain
the selected `BW5R-B` policy and unchanged walking gate while asking a
complete finite question about twelve new exact descriptor identities—both
directions of every public morphology axis, one changed axis per body.

R05E is now prospectively implemented, but it is not yet officially qualified
or physically authorized. The exact source contains only the frozen twelve
held-out descriptors and one separate ghost descriptor—no sampler. Its source
gate passes all thirteen compiles and `32/32` mutation controls. The ghost and
official production supervisors respectively pass `1/1` and `36/36`
entrypoint/serialization preflights under the common conformance lock, reject
mismatched or missing worker authority and wrong JSON field types, and report
zero models, worlds, native reads, solver steps, physics mutation, or outcome
exposure. Both bind the same complete `80`-path closure: `41` recursive
GDScript/resource paths, `25` Rust inputs, and `15` process/audit paths with one
overlap, and the dependency audit requires explicit LF checkout policy for all
eighty qualified text paths. The independent authority-contract test also
proves direct source-freeze -> closure-only qualification -> authority-only
commit edges, parsed qualification-receipt, source-blob, and exact runtime
binding, `25` content-mutation refusals, and `5` repository/evidence refusals;
the final audit
lock probe proves the last supervisor released the shared mutex.

The executable audit is
[`../conformance/qsdk_r05e_zero_world_implementation.py`](../conformance/qsdk_r05e_zero_world_implementation.py).
This prospective pass is not the clean-pushed qualification and cannot update
the release contract or support matrix. Both execution-authority files remain
absent. After a clean live-equal source freeze, the official wrapper must
consume and retain the one ghost qualification identity, its closure must be
published alone, and a distinct authority-only commit must be published before
one non-held-out ghost may commission construction, stepping, retention, and
evaluation. The sealed twelve-body by three-seed decision remains later still.
The one-shot qualification process is bounded at thirty minutes and must
reconcile clean cached/live source again after its audit; its named interlock
also excludes concurrent R05E physical execution.
M05 and QSDK-R05 remain contradicted; no support claim, score, candidate
authority, publication authority, or release state changes at this
implementation boundary.

## 2026-09-03: R05E exact-finite result adopted into QSDK-R05 and SDK1-M05

The preceding implementation-boundary section is retained as chronology. R05E
subsequently completed the entire prospective chain: clean-pushed held-out
source freeze `54d23a7afcca6e98f35eebf5479b1fd145b11c23`, closure-only
zero-world qualification `3228ad65f3afafe0d53572a0bc375e89ff0ea85c`, and
authority-only child `2c47d8b05e3f46f1c752bc544937c0b69826069e`. Exactly one
authorized held-out campaign then ran. No retry, timeout, process-tree kill,
receipt-parse failure, failed-cell replacement, or post-outcome substitution
occurred.

All `36/36` frozen worlds passed the complete harness, execution-integrity,
declared-mechanism, combined-application, and walking conjunctions: the twelve
literal descriptor identities at indices `217..228`, each under seeds
`40101..40103`. All `972/972` raw walking-gate booleans are true. Across
`97,862` SDK steps, the adapter recorded `782,896` validated commands and the
same `782,896` native motor writes—exactly eight writes per SDK step—with zero
direct-body writes, legacy writes, SDK mismatches, or safe-disable events. The
[physical closure](../qsdk_r05e_exact_finite_morphology_physical_closure_v1.json)
binds the immutable `890,301`-byte report at
`sha256:0fb1d495d079beeda1412c8f3c0af5127dc0646429debf80cf0d20e0d3cd1ab6`.
The retained evidence tree contains exactly `149` files and `4,545,211` bytes;
its `26,618`-byte canonical manifest hashes to
`sha256:39100949b3fdc0f8534bdbdd2d4dbf7b0bf74cff9c4f8d6d01b6773dbd50ffd5`.

The post-result audit was added alone in `d4692c02`, the closure alone in
`25cef1f7`, and its permanent reconstruction test alone in `e0d2ec75`. Those
steps read and reconstruct the retained evidence; they do not change the
policy, morphology population, evaluator, thresholds, solver, or physical
outcome. The release contract now accepts that closed exact-finite result for
`QSDK-R05`, and the bounded milestone ledger accepts it for `SDK1-M05`. The
current executable scores therefore become SDK1 `13/20` and full program
`13/25`; packaging, physical acceptance, and publication remain blocked.

This is deliberately a point-list claim, not a box claim. It covers only those
twelve exact one-axis-at-a-time bodies under those three exact seeds in
Godot/Jolt with the unchanged selected `BW5R-B` policy. It does not cover the
space between points, multi-axis combinations, extrapolation, arbitrary valid
quadrupeds, a continuous morphology volume, material or friction robustness,
rough terrain, pushes, sensor noise, other engines, or a complete SDK release.
The R05E physical identity is consumed permanently; no further R05E run is
authorized.

## 2026-09-03: QSDK-R10A freezes the M07 successor without advancing it

The
[`R10A bounded upright-push design`](../qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json)
binds the still-contradicted live `QSDK-R10` requirement and selects only a
zero-world R10B implementation. Its future finite claim is exact: Godot/Jolt,
the reference quadruped, selected `BW5R-B` policy, characterized `0.95`
material, one `0.25 N s` positive-lateral central torso impulse at SDK step
`540`, a one-cycle re-entry deadline, and a full safe gait cycle after
re-entry.

One matched baseline/push development pair at seed `50300` must first prove
the production route. Only an execution-valid ghost may expose the three
held-out pairs at seeds `50301..50303`; every cell and pair must pass, and no
pooling, averaging, replacement, or rerun is permitted. No physical world was
opened by R10A. The release contract and support matrix remain unpromoted,
SDK1 remains `13/20`, the full program remains `13/25`, and R10B zero-world
implementation is the next legal step.

## 2026-09-03: QSDK-R10B implements but does not yet exercise the M07 route

The R10B implementation now carries the frozen reference fixture through the
ordinary production walker, a complete post-physics measurement trace, a
fail-closed world and pair evaluator, and a serialized supervisor. Its exact
dependency audit originally discovered `69` source/build/process paths. The development
zero-world gate passes all eight frozen cell entrypoints, the positive,
negative, incomplete, and mutation controls, and both unauthorized physical
entry refusals. It reconstructs the immutable R10A inputs from their historical
Git blobs rather than modifying or relaxing the predecessor record.

The physical boundary is deliberately stronger than a command-line flag. A
future run requires clean equality among `HEAD`, `origin/main`, and live GitHub
`main`; a content-addressed zero-world stage freeze; the shared serial operation
lock; and a separate execution authority bound to one exact, initially absent
directory below `SporeSpore_Evidence`. The supervisor creates that directory
before the first world, so a failed or interrupted attempt cannot be retried
under a fresh timestamp while claiming the same authority.

The source, qualification, and authorization are deliberately three commits:
the latter two may change only their one JSON authority apiece. The authority
binds its earlier parents, the supervisor derives the current authorization
commit from live-equal `HEAD`, and every qualified source blob
must still equal the implementation freeze. This removes the impossible
self-hash that would arise if an authority tried to contain its own commit ID.

No model, world, scene insertion, native readback, solver step, or outcome
exposure occurred in this implementation gate. The support matrix and release
contract remain unchanged, `QSDK-R10` and `SDK1-M07` remain false, and scores
remain SDK1 `13/20` and full program `13/25`. Clean-pushed official zero-world
qualification is the next gate; no physical execution is authorized by this
record.

## 2026-09-03: QSDK-R10B-L1 repairs a preserved pre-physics authority refusal

The first clean-pushed implementation (`5f7ab1da`), freeze-only commit
(`959bf78f`), and authority-only commit (`881dc1f1`) were successfully kept
separate. The five-file official qualification completed with zero physical
counters. The next committed `AuthorityCheck`, however, failed before the
operation lock, evidence-directory creation, model construction, or world one.

The mismatch was entirely in the gate: Python emitted the 69 source paths in
ordinal order, while the PowerShell supervisor compared them against a
culture-aware sort. All blobs, hashes, byte lengths, scalar fields, claim flags,
and ordered cells matched independently. The v1 output root remains absent and
no physical attempt was consumed. The exact infrastructure-invalid invocation
is retained in
[`../qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json`](../qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json),
SHA-256
`0196bdbcb8f914421edab305ca37e637708f8e35d5320f5c41fed827bfa9e230`.

R10B-L1 replaces only that comparison with strict ordinal adjacency, tests a
valid order plus reversed and duplicate refusals, and promotes the immutable
refusal record into the qualified dependency closure. The repaired closure is
`70` paths with path-set digest
`sha256:76c421b1c1ab637046c847050fcc38d298f678cae4a6c875732bcf088941fc23`;
the development gate passes `88` authority mutations per source execution and
still reports zero models, worlds, native reads, solver steps, and outcomes.

This changes no release-contract or support-matrix field. `QSDK-R10` and
`SDK1-M07` remain false, SDK1 remains `13/20`, and the full program remains
`13/25`. The repair needs a new clean-pushed official qualification, v2 freeze,
v2 authority, and passing committed-graph check before the unchanged two-world
route ghost can begin.

## 2026-09-03: QSDK-R10B-L1-P1 is consumed and representation-invalid

The repaired graph completed at source `61783dbc`, freeze-only `ac55feaf`, and
authority-only `1e595edd`. Its five-file, `11,974`-byte official zero-world
qualification and v2 committed-graph authority check both passed.

The single-use physical root then opened exactly one matched baseline world.
It ran `2,880` Godot/Jolt physics ticks and retained all `2,640` post-physics
controller rows with no external impulse. The cell failed mandatory evidence
validation as `QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID`; therefore no valid cell,
pushed world, pair evaluation, or campaign report exists. The four retained
files total `6,561,324` bytes with canonical tree SHA-256
`c3d08863f43ba335100a5c20044663d77ec861b5d80aa03551ac831c5f367dfc`.

The exact failure is exported quaternion unit length. Row zero differs from one
by `8.789622585325674e-9` against the unchanged `1e-9` check; `2,566` rows
violate it and row `1889` peaks at `1.185268823089558e-7`. The retained walking
summary also has `bounded_anchor_error=false`, but it is not a valid negative
because the evidence contract failed first.

The immutable physical-invalid closure forbids an identity rerun and selects
R10B-L2: apply the already-qualified R24D66 exported-scalar quaternion
projection and largest-component reconstruction, with retained diagnostics and
zero-world controls. This does not alter the controller, fixture, challenge,
impulse, behavior thresholds, validator tolerance, seeds, or population. The
release contract and support matrix remain unchanged; `QSDK-R10` and
`SDK1-M07` remain false, with scores `13/20` and `13/25`.

## 2026-09-04: QSDK-R10E-L1 preserves and repairs a pre-physics refusal

The later R10C/R10D evidence path selected R10E's observer-minimized successor,
whose first complete execution boundary was clean-pushed as
`831e5703f682703cfa6e9f721b0ce564dcb6ce9b`. Its sole official
`development_route_ghost` zero-world qualification failed while Godot compiled
the complete implementation audit. Three locals—`common_execution_integrity`,
`exact`, and `exact_attempt`—used inferred types across `Variant`-valued reads
or an awaited result. Godot refused them before source-gate completion.

The
[`failure closure`](../qsdk_r10e_development_route_ghost_zero_world_qualification_failure_closure_v1.json)
binds that consumed identity and the four retained files under
`SporeSpore_Evidence/qsdk-r10e-development-route-ghost-zero-world-qualification-831e5703f682`.
They total `5,853` bytes; the canonical 569-byte file manifest has SHA-256
`fda2b3fba88474418ae7ed888af0b1ed5b55723a7608eb931afbb820ac6d0aeb`.
The record reports zero model constructions, world attempts, world builds,
scene-tree insertions, native reads, solver steps, outcomes, and physics-state
changes. It has no physical or behavioral interpretation and may not rerun.

R10E-L1 makes the three rejected Boolean types explicit. Real Godot development
compilation additionally exposed seven test-only `Variant` declarations,
established that the complete source refusal population is 21, and measured the
generator-225 preflight's actual adapter capability digest as
`b9f59849bb6b22c8837f9c2784345899b95a14b1aa058df53df480da9f7a4a68`.
The versioned
[`dependency manifest`](../qsdk_r10e_dependency_manifest_v2.json) binds 85
source/build/audit paths with path-set SHA-256
`fa7dd62aa503db13c15818a5a66df1fbbf94351348da7a047de950cc99888a1d`.

The complete local development audit passes with all physical counters zero.
The controller, fixture, material, push, schedule, thresholds, seeds, and
populations are unchanged. A new clean-pushed source identity must still pass
one official qualification, receive separate freeze-only and authority-only
children, and pass the committed-graph check before either development world
can open. `QSDK-R10`, SDK1-M07, and external push recovery remain false. The
current post-M08 scores remain SDK1 `14/20` and full program `14/25`; the release
contract and support matrix are unchanged.

## 2026-09-04: QSDK-R10E-L2 preserves and repairs a supervisor refusal

R10E-L1 became clean-pushed source
`0dbd259477d01c6de026f4c99587619a69b59b44` and passed its single official
replacement qualification with every physical counter zero. The freeze-only
child was `047739f02306d20f28153ef34758ec3d30fbcb2e`; the separate authority-only
child was `716feb860ba3ca980d90cb96cc4d72cd2e24b808`.

The first physical-mode invocation of that graph failed before its worker or
physics engine ran. Its role-dependent physical-closure path was written as a
grouped `if` passed to `Join-Path`. PowerShell accepted the file, then treated
the grouped statement as a command expression and tried to launch a command
named `if`. The authorized evidence directory was never created. The
[`supervisor-refusal closure`](../qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json)
is `5,728` bytes with SHA-256
`831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0`.
It records one supervisor invocation and lock acquisition, zero explicit
release by the terminated process, a healthy independent post-process lock
probe, and zero models, world attempts, world builds, scene insertions, native
reads, solver steps, or outcomes. Thus the physical identity was not consumed,
but the old stage and authority are retired and may not be reused.

R10E-L2 makes the two role-specific closure paths plain role data, validates
both paths in zero-world mode, rejects a parsed PowerShell command node named
`if`, and encloses all work after lock acquisition in guaranteed cleanup. The
[`v3 dependency manifest`](../qsdk_r10e_dependency_manifest_v3.json) binds 88
exact paths and path-set SHA-256
`f228a9c1bbeca5beee17d9cf92b08c8c016a18d6e975428d820a58f3d554b0d3`.
The full L2 development audit passes and reconstructs the exact old defect from
the committed L1 supervisor while every physical counter remains zero.

This is source-development evidence only. Before either unchanged development
world may open, L2 needs a new clean, pushed, live-equal source commit, one new
official qualification, separate v2 stage and authority commits, and a passing
committed-graph check. No controller, fixture, challenge, impulse, threshold,
seed, or population changes. `QSDK-R10`, SDK1-M07, external push recovery,
physical acceptance, release, and publication remain false; the release
contract, support matrix, and `14/20` and `14/25` scores are unchanged.

### R10F-L1 changes no release claim

The first R10F physical-mode supervisor invocation was infrastructure-invalid
before evidence-root creation because PowerShell misbound an infix `-split`
token in the physical-only authority graph check. The
[immutable refusal](../qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v1.json)
records zero models, worlds, reads, steps, state changes, and outcomes. The v1
identity was not consumed, but its authority graph is retired and cannot be
reused.

L1 repairs only that boundary and binds the refusal into an 83-path v2 source
closure. Its complete development zero-world audit passes, but no clean-source
official qualification, v2 freeze, v2 authority, or replacement physical run
has occurred yet. Therefore `external_push_recovery`, SDK1-M07, submission
readiness, physical acceptance, release, and publication remain false. The
release contract, support matrix, and scores remain `14/20` and `14/25`.

### R10F-L2 also changes no release claim

The first L1 replacement physical call stopped before evidence-root creation
when its changed-path set comparison supplied a string to a Boolean assertion.
The
[`v2 immutable refusal`](../qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json)
binds the qualified `04a4b4aa` / `e211187d` / `fc3187f9` graph and records zero
models, worlds, reads, steps, state changes, and outcomes. That output identity
was not consumed, but the v2 freeze and authority are retired.

L2 replaces that joined-text expression with a pure ordinal Boolean path-set
function and binds both refusal lineages in an 86-path v3 closure. Its complete
Godot-backed development zero-world audit passes. No new official L2
qualification, v3 freeze, v3 authority, or physical result exists yet.
Accordingly `external_push_recovery`, SDK1-M07, submission readiness, physical
acceptance, release, and publication remain false. The release contract,
support matrix, and scores remain `14/20` and `14/25`.

### R10F-L2-P1 consumes no release evidence

The qualified v3 R10F development graph ran once and stopped after one model
and world build but before its first solver step. The baseline bootstrap intent
was checked with the active-application validator, producing
`QSDK_R10F_INITIAL_APPLICATION_INVALID`. The
[`v3 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v3.json)
binds four retained files / `13,869` bytes and classifies the identity as
consumed invalid/incomplete with no behavioral conclusion.

No kick, fall, standing recovery, resumed walking, or valid negative was
observed. The attempt cannot rerun, and no successor authority exists.
Therefore `external_push_recovery`, SDK1-M07, submission readiness, physical
acceptance, release, and publication remain false. The release contract,
support matrix, and scores remain `14/20` and `14/25`.

### R10F-L3 zero-world repair also changes no release claim

L3 introduces a dedicated consumer for the unchanged actuation-free bootstrap
intent and leaves the active-application validator on the later control path.
The exact initial producer/consumer pair passes at zero worlds, the active
validator is proven inapplicable to that bootstrap, and six malformed
bootstrap variants are refused. Setup failures now retain the complete
application and validation projection; valid future arms must retain the same
successful receipt.

The 90-path v4 manifest has path-set SHA-256
`77a1e3c71f27d4f958b652556e34a418a00a6503c77219ff1cf81849b9ab88f3`.
Its audit authenticates the consumed L2-P1 closure and all eight underlying
evidence/source bindings, then passes 25 source tests, 16 positive controls,
48 forced failures, both future-authority mutation suites, PowerShell
preflight/refusal checks, and real Godot parser/zero-world execution with zero
models, worlds, native reads, or solver steps.

This is only a prospective source repair. It neither rehabilitates the L2-P1
invalid result nor supplies kick, fall, recovery, resumed-walking, or valid
negative evidence. No clean-source L3 qualification, v4 freeze, v4 authority,
or L3 physical result exists yet. Therefore `external_push_recovery`,
SDK1-M07, submission readiness, physical acceptance, release, publication,
the support matrix, the release contract, and scores `14/20` and `14/25`
remain unchanged.

### R10F-L3-P1 also supplies no release evidence

The clean qualified v4 graph `08c84b28` / `410947d0` / `6fe4677b` consumed its
one development identity. Both declared models and worlds built and the
matched-no-kick arm completed one solver frame. The first compact trace row
then refused as
`QSDK_R10F_NATIVE_STEP_INVALID:matched_no_kick_continuation`. No external kick,
fall classification, recovery phase, resumed walking, or behavior evaluation
occurred.

The
[`v4 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v4.json)
binds four retained files / `13,946` bytes and is `4,797` bytes at SHA-256
`09d084a2639bca7a6c7f6c6e3b2f75c6dce596067eff11a94c1d838972bd31f2`.
It classifies the consumed result as invalid/incomplete with no behavioral
conclusion. The native marker, engine-health projection, termination receipt,
and evidence bindings are valid; route and outcome evidence are false.

The source diagnosis is a producer/consumer schema mismatch in trace
measurement. The recovery producer retains one parent-local planar hinge axis;
the R10F summary additionally required a nonexistent child-axis field and
returned a bare failure projection. This is not evidence against or for the
policy, kick response, passive fall, standing controller, or walk resumption.
The identity cannot rerun and no held-out seed was accessed. A distinct
zero-world-qualified L4 consumer repair is required before any new physical
authority. Consequently `external_push_recovery`, SDK1-M07, submission
readiness, physical acceptance, release, publication, the support matrix, the
release contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L4 measurement completeness still supplies no release evidence

L4 fixes the compact geometry consumer that rejected L3-P1's first completed
row. The native producer is unchanged and still retains one shared planar
hinge axis rather than a separate child-axis field. The new consumer uses the
completed observation's anchor measurement and the shared local axis plus live
body bases. It adds explicit schema, identity, finiteness, anchor, and axis
refusals; it changes no policy, kick, controller, threshold, seed, population,
or behavior evaluator.

The 94-path v5 manifest has path-set SHA-256
`6f59733c768afc605849fa5c1fc531b6dd4a3158d985a0a55f17d0a094bf3681`.
It binds both consumed invalid R10F closures. The complete development audit
passes 27 source tests, 16 positive controls, 64 forced failures, both future-
authority mutation suites, PowerShell preflight/refusal controls, the real
Godot parser, and a detached-node Godot zero-world composition with every
physical counter at zero.

No kick, passive fall, recovery, resumed walk, valid behavioral negative, or
held-out result is introduced. The L4 source still needs official
qualification, separate v5 freeze and authority commits, a committed-graph
check, and then one valid development route ghost before M07 could even select
a held-out decision successor. Therefore `external_push_recovery`, SDK1-M07,
submission readiness, physical acceptance, release, publication, the support
matrix, the release contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L4-P1 remains infrastructure-invalid and supplies no release evidence

L4 completed its official zero-world qualification and exact v5 committed
graph, then consumed one development identity. Both worlds built and four
solver steps completed. The route stopped in the second baseline collection
because the worker required the collector's cumulative `solver_step_count=2`
to equal a per-call literal `1`. No kick, fall, recovery, resumed walk, or
behavior evaluation occurred.

The 4,797-byte
[`L4-P1 closure`](../qsdk_r10f_development_route_ghost_physical_closure_v5.json)
has SHA-256
`b862561d0db78c03533a5d7121b4380b9c96507fe37adab2e2a046785d98dd74`.
It records two worlds, four solver steps, a consumed identity, and
`invalid_or_incomplete_no_behavioral_conclusion`. It is not a valid negative
and cannot support any recovery, reliability, or release claim.

R10F-L5 is limited to separating cumulative source validation from one-step
aggregate accounting. It changes no advertised behavior or acceptance term
and must earn a new zero-world and committed authority graph before another
development run. Therefore `external_push_recovery`, SDK1-M07, submission
readiness, physical acceptance, release, publication, the support matrix, the
release contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L5 counter accounting still supplies no release evidence

L5 preserves the collector's cumulative source sequence and adds a separate
one-step delta only after exact schema, gate, status, wrapper, type, and global-
step agreement. Consecutive values one and two pass at zero worlds; sixteen
malformed or mis-sequenced cases fail closed. The complete development audit
passes 29 source tests, 16 outer positives, and 80 forced failures with every
physical counter zero.

The 98-path
[`v6 manifest`](../qsdk_r10f_dependency_manifest_v6.json) has path-set SHA-256
`80c56eac99c4d3912617db56ffa5e03580a9ba742ef68cd5e4ca11657948626d`
and preserves the L4-P1 closure at
`b862561d0db78c03533a5d7121b4380b9c96507fe37adab2e2a046785d98dd74`.
The repair changes no advertised behavior, physical fixture, controller,
impulse, threshold, seed, population, or evaluator. It neither rehabilitates
L4-P1 nor proves recovery. Until L5 is clean-pushed, officially qualified, and
bound by separate v6 freeze/authority commits, no physical development
identity exists. `external_push_recovery`, SDK1-M07, submission readiness,
physical acceptance, release, publication, the support matrix, the release
contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L7 remains development-only and supplies no release evidence

L7 now implements exact arm-local terminal-disposition retention before the
generic post-release terminal-pair rule. A complete precondition continues to
the unchanged L6 barrier. A failed/refused precondition stops without another
solver frame and retains both the failing V6 source and the other arm's last
completed state. The future physical closer independently recomputes and
checks every nested digest and source binding.

The 110-path v8 development audit passes 33 source tests, 18 positive
compositions, and 108 forced failures. L7 contributes six positive cases and
sixteen corruption refusals; the future materializer and closer reject 18 and
45 mutations. Real Godot parse and detached execution pass with every physical
counter zero. No official qualification, freeze, authority, model, world,
solver step, kick, or recovery result exists for L7.

Therefore this implementation does not establish that the creature reaches
the walking prefix, receives the kick, falls prone, stands, resumes walking, or
satisfies an advertised recovery capability. `external_push_recovery`,
SDK1-M07, M20, candidate readiness, physical acceptance, release, publication,
the support matrix, the release contract, and scores `14/20` and `14/25`
remain unchanged.

### R10F-L5-P1 is consumed and supplies no release evidence

L5 subsequently passed its official qualification and separate committed v6
freeze/authority graph. Its sole physical development identity built two
worlds and completed 480 arm solver steps. The baseline world reached the V6
stable-standing terminal one frame before the active world, and the worker
stopped on the overstrict `QSDK_R10F_PRECONDITION_NOT_LOCKSTEP` condition.
No walking prefix, kick, passive fall, post-kick recovery, resumed walking, or
behavior evaluation occurred.

The immutable
[`v6 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v6.json)
has SHA-256
`fb4879cc6645d60fcb71eeb1d618e4a5453f4c2386b1d45cc1d838e4775d6863`
and classification `invalid_or_incomplete_no_behavioral_conclusion`. It cannot
be counted as a pass, a behavioral negative, a supported recovery capability,
or a release test. The identity cannot rerun.

The prospective
[R10F-L6 design](../qsdk_r10f_l6_precondition_pair_barrier_successor_design_v1.json)
is an orchestration-only successor: a source-bound,
motors-disabled wait barrier will allow each isolated world to finish the
unchanged precondition independently and will start both walking-prefix clocks
only after both are ready. Until that distinct source passes its own zero-world
gate and a future physical result actually closes the complete route,
`external_push_recovery`, SDK1-M07, M20, candidate readiness, physical
acceptance, release, publication, the support matrix, the release contract,
and scores `14/20` and `14/25` all remain unchanged.

### R10F-L6 remains development-only and supplies no release evidence

L6 now implements and development-tests the source-bound precondition pair
barrier. Each world must finish the unchanged V6 standing precondition from
its own native source. An early-ready world continues taking solver steps with
all eight motors disabled and zero targets until both sources exist; both
worlds then take one no-actuation release frame and begin their fresh walking
prefixes together on the next shared boundary.

The 104-path v7 development audit passes 31 source tests, 17 positive
compositions, and 92 forced failures. The future authority materializer and
physical-closure compiler reject 18 and 25 mutations. Real Godot parse and
detached zero-world execution pass with every physical counter zero. The
future closure independently checks each retained terminal source, wait and
release application, native motor readback, and no-actuation ledger owner.

No official v7 qualification, freeze, execution authority, or physical L6
result exists yet. Therefore the implementation does not establish that the
creature walks to the kick, falls prone, stands, resumes walking, or satisfies
any supported recovery capability. `external_push_recovery`, SDK1-M07, M20,
candidate readiness, physical acceptance, release, publication, the support
matrix, the release contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L6-P1 remains invalid and supplies no release evidence

L6 subsequently passed its official qualification and committed graph, then
consumed one two-world identity. Both worlds built and completed 300 common
frames / 600 arm solver steps. The baseline stood at frame 240 and completed
60 valid motors-disabled barrier waits. The active arm did not publish a
standing source and reached a non-complete precondition terminal at frame 300.
The route stopped on `QSDK_R10F_TERMINAL_FRAME_NOT_LOCKSTEP` before any walking
prefix, kick, passive fall, post-kick recovery, or evaluator.

The immutable
[`v7 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v7.json)
has SHA-256
`842af3fab4aa80d1cea43e5a59391978708206174362837c9aeb99ca417d9517`
and classification `invalid_or_incomplete_no_behavioral_conclusion`. It is not
a recovery failure rate, a valid negative, or support evidence.

L7 will retain the exact precondition terminal source needed to diagnose a
failed/refused arm; it changes no advertised behavior and currently authorizes
zero-world implementation only. Therefore `external_push_recovery`, SDK1-M07,
M20, candidate readiness, physical acceptance, release, publication, the
support matrix, the release contract, and scores `14/20` and `14/25` remain
unchanged.

### R10F-L7-P1 remains invalid and L8 has no release authority

L7 subsequently passed its official zero-world and authority sequence, then
consumed one physical development identity. Both worlds built and each took
one solver step. The diagnostic builder rejected native
`last_semantic_step = 1.0` because it required the same discrete step to have
integer runtime kind. No walking prefix, kick, fall, standing attempt, resume,
or evaluator occurred.

The immutable
[`v8 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v8.json)
has SHA-256
`15cf3bdd5485405613726be8c800c5e46f4178a818ae89b947efc992e3094aba`
and classification `invalid_or_incomplete_no_behavioral_conclusion`. It is not
a recovery negative, a supported capability, or release evidence, and the
identity cannot rerun.

The prospective
[L8 design](../qsdk_r10f_l8_integer_valued_native_step_domain_successor_design_v1.json)
only authorizes zero-world validation of finite, integral native step numbers
that exactly equal the already-bound step. It does not change or prove any
advertised behavior. Therefore `external_push_recovery`, SDK1-M07, M20,
candidate readiness, physical acceptance, release, publication, the support
matrix, the release contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L8 implementation remains development-only and supplies no release evidence

L8 now implements and development-tests the narrow number-domain consumer for
the native `last_semantic_step`. It preserves the original integer or binary64
source number and accepts it only when it is finite, integral, within steps 1
through 3,842, and exactly equal to the already-bound expected step. Six
positive controls and sixteen corruption/type/range refusals pass. The complete
v9 development audit covers 115 source paths, 34 static tests, 19 positive
compositions, 124 forced failures, and the future authority and closure
mutation suites. Pinned Godot reports zero physical activity.

This does not show that the creature reaches walking, receives a kick, falls,
stands, resumes, or satisfies a supported recovery capability. No official v9
qualification, freeze, execution authority, or L8 physical result exists yet.
Therefore `external_push_recovery`, SDK1-M07, M20, candidate readiness,
physical acceptance, release, publication, the support matrix, the release
contract, and scores `14/20` and `14/25` remain unchanged.

### R10F-L8-P1 is pre-kick, inconclusive, and supplies no release evidence

L8 later passed its official qualification and exact committed graph, then
consumed one physical development identity. The first-built no-kick world
completed the standing precondition at step 240 and waited for 60 additional
motor-disabled steps. The second-built active world reached step 300 raised and
upright but still moving above the frozen stability limits, so it retained
`phase_timeout:stance_dwell`. Neither world began the walking prefix. There was
no kick, fall, post-kick standing test, resumed walking, or behavior evaluation.

The immutable
[`v9 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v9.json)
has SHA-256
`29ef1f7c2db408a2fd09f378e057648825eac2c1e856932dd2ed259829bdadde`
and classification `invalid_or_incomplete_no_behavioral_conclusion`. It binds
the two worlds, 600 solver steps, exact wait-path readbacks, no kick, no
evaluator, and a consumed identity. It is not a behavioral negative, support
test, recovery demonstration, or release result.

The repeated L6/L8 first-built-success pattern and the matching serial R172
success justify a new development topology test, not a capability claim. The
prospective
[L9 design](../qsdk_r10f_l9_process_isolated_matched_arm_successor_design_v1.json)
will run each matched arm in a separate, serialized Godot process with one
world per process. Every body, policy, controller, threshold, horizon, kick,
seed, material, actuator limit, evaluator, and solver budget remains frozen.
No L9 physical execution is authorized yet. Therefore
`external_push_recovery`, SDK1-M07, M20, candidate readiness, physical
acceptance, release, publication, the support matrix, the release contract,
and scores `14/20` and `14/25` remain unchanged.

### R10F-L9-P1 is instrumentation-invalid and L10 has no release authority

L9 later passed its complete v10 zero-world qualification, freeze, and
execution-authority sequence, then consumed one development identity. Its
first fresh child built one model and one world and ran 240 solver steps. The
child retained successful terminal recovery memory and a stable stance
classification, but its receipt adapter crashed while converting the valid
null optional failure code to a Godot string. The active child never launched,
and no walking prefix, kick, fall, resumed walking, or evaluator ran.

The immutable 8,646-byte
[`v10 physical closure`](../qsdk_r10f_development_route_ghost_physical_closure_v10.json)
at SHA-256
`7a5b61ec898b9c5b2891911101d34c3cefe7a6c5657a7c6abdea45e6b4299464`
classifies the identity as consumed,
`invalid_or_incomplete_no_behavioral_conclusion`. The retained partial state
is diagnostic and supplies no recovery, support, acceptance, or release
evidence.

The prospective 16,553-byte
[L10 design](../qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1.json)
at SHA-256
`2d186f41fcb73427ef7021a1050e4175791784212bfb9c219d712595370a4817`
only authorizes strict zero-world handling of null success and nonempty-string
failure sources. It changes no advertised behavior and authorizes no physical
work. Therefore `external_push_recovery`, SDK1-M07, M20, candidate readiness,
physical acceptance, release, publication, the support matrix, the release
contract, and scores `14/20` and `14/25` remain unchanged.
