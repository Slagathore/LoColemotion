# LoColemotion Locomotion SDK

Current SDK1 checkpoint (2026-10-03): **20/20**, full program **19/25**.
The [package acceptance closure](release/sdk1_package_acceptance_closure_v1.json)
closes M01/M11/M15 after two identical source packages and isolated build/API/
quickstart validation. All 83 native exports are declared and invoked; 524 Rust,
21 ctypes, three SDK1 extension and eight developer-experience tests pass.
The retained packages are watermarked validation candidates, not public releases.
The six deferred full-program gates and binary-publication limits remain intact.

The [installed live Studio](explorer/README.md#studio-desktop-successor-development-interface-verified)
runs native physics with user impulses, edited MuJoCo bodies, six tested-scenario
recipes, provenance/history and optional recorded timeline inspection. Use
`SporeSpore Studio` on Cole's desktop. Godot walking is near real time after
startup; its fast path does not yet run the full get-up controller after a fall.

The [engine integration comparison](docs/ENGINE_INTEGRATION_COMPARISON.md)
explains how the Godot/Jolt, Rapier and MuJoCo hosts map the portable command,
why their observation timing differs, and what the retained timing data can
and cannot establish. It includes the integration table and figure provenance.

Prior licensing decision (2026-10-03): Charles Chambers selected the
[Community/commercial terms](release/licensing/README.md), with a US$100,000
whole-group annual gross-revenue cap for free business use and a paid private-
modifications option. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
The clean-source licensing audit and adoption passed; SDK1 is **16/20**,
full program **16/25**, with M20 and M01/M11/M15 remaining.
No commercial customer order, binary distribution or release is authorized.

Prior SDK1 checkpoint (2026-10-02): **15/20**, full program **15/25**.
R10DH's six held-out recovery cells and independent audit passed; M07 is
accepted only for its exact finite S169/Godot/Jolt runtime and conditions.
The [Explorer evidence view](explorer/README.md) displays those verified records
and keeps live sandbox recovery unproven. M14 licensing and M20 Explorer remain
prerequisites to the final M01/M11/M15 package checks. The historical checkpoints
below retain their original status and do not supersede this current checkpoint.

This directory contains the emerging engine-neutral locomotion core. It is
usable for deterministic C0/C1 schema, morphology, policy, scheduling, and
coverage work. It is **not yet the completed engine-neutral SDK**, and it does
not claim that arbitrary quadrupeds physically walk.

Current M07 checkpoint (2026-09-05): L13's qualified source `0eee6539` and
separate v14 freeze/authority graph ran once. The baseline retained 2,882 steps
in one world, including 720 walking-prefix and 1,920 continuation steps, before
terminal evaluation emitted two array-index errors. The independent audit also
rejected a terminal content address. The
[v14 physical closure](qsdk_r10f_development_route_ghost_physical_closure_v14.json)
consumes the result as invalid/incomplete with no behavioral conclusion. The
kick child never launched. The [L14 diagnosis and design](qsdk_r10f_l14_terminal_boundary_successor_design_v1.json)
now isolate three terminal-boundary faults and pass one positive plus 18 scope
mutations at zero worlds. Versioned implementation is next; no rerun or new
physics is authorized. Scores remain `14/20` and `14/25`.

Preceding M07 checkpoint: the L13 freeze-binding repair passes a
138-path v16 complete zero-world audit with 43 source tests, 24 positive cases,
237 forced failures, 86 wrapper corruptions, and five actual production
source-binding functions. The test also rejects ten historical/current adapter
binding corruptions. The successful `ebee5501` qualification is
[retired before freeze](qsdk_r10f_l13_qualified_source_retirement_v1.json), not
reclassified or reused; its six files / 63,609 bytes remain intact. A distinct
source qualification and separate v14 freeze/authority graph are required.
No L13 physical identity has opened; scores and release authority are unchanged.

Preceding M07 checkpoint: R10F-L12 is closed invalid/incomplete
after 241 steps. L13's walking-ledger transport and exact host-target projection
are implemented, but its first official qualification at `8de3a28f` is consumed
because the wrapper required an explicit zero scene-insertion counter absent
from the nested historical report. The
[failure closure](qsdk_r10f_development_route_ghost_zero_world_qualification_failure_closure_v1.json)
preserves four files / 28,659 bytes. The forward reporting repair passes the
complete zero-world audit (42 source tests, 24 positive cases, 237 forced
failures) plus one actual-wrapper positive and 86 corruptions. The v15 source
manifest binds 136 paths. No L13 world has run; a fresh source qualification,
separate freeze, separate authority, and committed-graph check remain required.
The older implementation snapshots below do not supersede this checkpoint.
Scores remain `14/20` and `14/25`; no recovery or release claim changes.

Current portable-boundary status: clean-pushed implementation `fa3e6aae` passes
the complete `QSDK-R01` source and exact package-projection proof. It also
qualifies the previously missing bridge from bounded SDK1 17+3 readiness into a
separately watermarked, non-publishable candidate. The retained source report
binds 1,467 files / 31,157,392 bytes and all 58 Rust/C/Python functions, 193
Rust tests, 21 Python ABI tests, and ten surface mutations. The bridge audit
adds one valid authorization shape, 13 authority mutations, forged-live-source
refusal, and conflicting-mode refusal.

No candidate was created or executed. QSDK-R13 has satisfied M08; `SDK1-M07`,
`M14`, and `M20` now block the one artifact that must later answer `M01`,
`M11`, and `M15`. Therefore `QSDK-R01` and `SDK1-M01` remain false, and the
scores are SDK1 `14/20` and full program `14/25`. The R10D-L1 development
population is a valid finite negative, while its separately qualified held-out
population is consumed and invalid/incomplete with no behavioral conclusion.
The R10E observer-minimized path completed one valid-negative L2 development
pair and consumed one incomplete L2 held-out graph. R10E-L3 preserved both,
repaired only the numeric self-link and terminalization boundaries, then ran a
distinct complete six-world held-out graph. All six cells, three pairs, native
effects, and local recovery windows are valid. All six worlds still fail the
unchanged full walking conjunction only on a pre-push anchor-limit crossing.
R10E-L3 is therefore a consumed valid complete finite negative; it advances no
claim or score, cannot rerun, and leaves no physical authority open. QSDK-R10F
implemented the distinct continuous same-body successor, but its L2 physical
identity is consumed and invalid/incomplete after one world build and zero
solver steps. The bootstrap receipt was sent to an active-application
validator, so no walking or recovery outcome exists. R10F-L3 provided and
qualified the separate bootstrap consumer, then consumed one new physical
development identity. Both worlds built and one solver step completed, but
compact trace retention required a child-axis field absent from the exact
recovery-world state schema. L3-P1 is invalid/incomplete with no behavior
conclusion; no kick or evaluator ran. R10F-L4 repaired that compact geometry
consumer, passed its v5 graph, and consumed a new identity. Both worlds built
and four solver steps completed, but the second baseline collection exposed
the native route's cumulative count `2` to a worker check that wrongly required
the per-call literal `1`. L4-P1 is invalid/incomplete; no kick or evaluator ran.
R10F-L5 separated cumulative source validation from one-step aggregate
accounting. Its 98-path zero-world development audit passed 29 source tests,
16 outer positives, and 80 forced failures; the official v6 graph then passed.
Its one physical identity built both worlds and completed 480 arm steps, but
the baseline crossed V6's stable-standing terminal one frame before the active
world. The worker's exact same-frame phase check stopped before walking, the
kick, or evaluation. L5 is consumed and infrastructure-invalid. R10F-L6
implemented and qualified a source-bound, motors-disabled precondition pair
barrier, then consumed one physical identity. The baseline stood at frame 240
and completed 60 valid barrier waits. The active arm reached a non-complete
precondition terminal at frame 300 without publishing a standing source; a
remaining generic terminal-lockstep check stopped before walking, the kick, or
evaluation. L6 is also invalid/incomplete. L7 is selected to retain the exact
arm-local terminal disposition and V6 failure source. No physical authority is
open.
See
[`portable_api/README.md`](portable_api/README.md) and the content-bound
[`portable API validation manifest`](portable_api/portable_api_validation_manifest.json).

### R10E-L1 zero-world qualification repair

Source `831e5703` carried the complete R10E worker, supervisor, recursive
dependency gate, qualification gate, stage materializer, and physical-closure
compiler. Its sole official `development_route_ghost` zero-world qualification
failed while Godot compiled the audit: three Boolean locals used untyped
inference across `Variant`-valued dictionary or awaited results. The process
stopped before any model, world attempt, world build, scene insertion, native
read, solver step, or outcome exposure.

The
[`immutable failure closure`](qsdk_r10e_development_route_ghost_zero_world_qualification_failure_closure_v1.json)
binds that consumed identity and all four retained files, totaling `5,853`
bytes. R10E-L1 gives those three locals explicit Boolean types. Running the real
Godot compiler in development also found seven zero-world test locals that
needed explicit `Variant` types; established 21, rather than 17, actual
malformed/incomplete source refusals; and measured generator 225's adapter
capability hash as
`b9f59849bb6b22c8837f9c2784345899b95a14b1aa058df53df480da9f7a4a68`.

The versioned
[`R10E-L1 dependency manifest`](qsdk_r10e_dependency_manifest_v2.json) contains
85 exact GDScript/resource, Rust-build, and process/audit paths with path-set
SHA-256
`fa7dd62aa503db13c15818a5a66df1fbbf94351348da7a047de950cc99888a1d`.
The complete L1 development audit passed while every physical counter remained
zero. Clean-pushed L1 source `0dbd259477d01c6de026f4c99587619a69b59b44`
then passed its one official qualification. Commit
`047739f02306d20f28153ef34758ec3d30fbcb2e` froze that qualification, and
commit `716feb860ba3ca980d90cb96cc4d72cd2e24b808` granted the separate
single-use development authority.

### R10E-L2 physical dispositions and R10E-L3 forward repair

The first physical-mode invocation of that exact L1 graph did not reach the
worker. A physical-closure output path used `Join-Path (if (...) { ... })`.
PowerShell parsed the grouped `if` as a command expression and tried to run a
command named `if` when physical mode evaluated it. The process stopped before
creating the authorized output root. It constructed no model, attempted or
built no world, inserted nothing into a scene tree, performed no native read,
took no solver step, and exposed no locomotion result.

The
[`immutable supervisor-refusal closure`](qsdk_r10e_development_route_ghost_physical_supervisor_refusal_v1.json)
is `5,728` bytes with SHA-256
`831c1c8bdc3720be7e1c9abe584cea098856982b4795f23f00c029f18b3b7fc0`.
It binds the passing qualification, stage, authority, exact terminal error,
one supervisor invocation, one lock acquisition, and absent evidence
directory. Because no attempt record or world existed, the physical identity
was not consumed. The old L1 stage and authority are nevertheless retired;
they are not reusable and their graph may not be invoked again.

R10E-L2 corrected that supervisor and then completed its own source,
qualification, v2 freeze, v2 authority, and one matched development pair. Both
Godot/Jolt worlds were valid and complete. Their local windows passed and the
pushed world measured a `0.06159316375851631 m/s` native effect, while both
worlds failed the unchanged whole-run walking conjunction only on
`bounded_anchor_error`. The
[`development closure`](qsdk_r10e_development_route_ghost_physical_closure_v2.json)
therefore records an execution-valid finite negative, not push-recovery
acceptance.

The separately qualified held-out graph then consumed `baseline_s40101` and
`push_s40101`; four worlds never opened. The baseline was a valid negative. The
push applied its native impulse exactly once, but the v1 validator compared a
stored Godot `Vector3.length()` value with a separately recomputed binary64 norm
and rejected the `2.4045559432472885e-9 m/s` difference against its fixed
`1e-9` check. With no pair available, a missing `AllowEmptyCollection` parameter
annotation then prevented terminal-report assembly. The
[`immutable L2 failure closure`](qsdk_r10e_l2_held_out_finite_decision_physical_failure_closure_v1.json)
binds both built worlds and all nine retained files. The identity is consumed
invalid/incomplete and supplies no behavioral conclusion.

R10E-L3 leaves the v1 validator byte-identical. Its v2 successor constructs one
host `Vector3` only to replay the producer's declared magnitude operation, then
uses a binary64 transport-only comparison. Axis and impulse links remain scalar;
the effect floor and every behavioral threshold remain unchanged. Empty cell or
pair populations now terminalize as invalid/incomplete while retaining the
primary failure, and historical development execution is refused. The
[`v4 dependency manifest`](qsdk_r10e_dependency_manifest_v4.json) binds 91 exact
paths with path-set SHA-256
`348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67`.

The L3 development audit passed with every physical counter zero. Clean source
`ff69874b5b7315e86865a4a265fd52fbf49ec7be`, freeze
`77fc09913d14b1965b2cb46847fa948f83cab3d5`, and authority
`55447a4791729996cfde10ac02948bbf120f84b9` then completed the official
graph. Its sole six-world invocation is closed below. M07, external push
recovery, the support matrix, release contract, and scores remain unchanged.

### R10E-L3 complete held-out finite negative

All six declared Godot/Jolt cells and all three paired evaluations are valid
and complete. The active arms measure native velocity effects of
`0.06441572308540344`, `0.060107264667749405`, and
`0.08401905745267868 m/s`; every local recovery search succeeds at zero-step
latency. Every matched baseline window also passes.

The unchanged complete behavior rule still fails because each world has one
false walking receipt, `bounded_anchor_error`. Its first logged cumulative
crossing of the `0.025 m` limit precedes the push in every seed. This separates
the cause of the full-run failure from the kick, but it cannot change the
frozen decision rule. The classification is
`valid_complete_behavior_finite_negative`.

The
[`immutable closure`](qsdk_r10e_held_out_finite_decision_physical_closure_v3.json)
is `12,565` bytes at SHA-256
`f764a112b2a3037506d29cced838901e6346027aac1529e39a89da9028abbded`.
It binds the `18,001`-byte terminal report and a `35`-file / `79,688,410`-byte
evidence tree. The identity is consumed, same-identity rerun is forbidden, and
only a zero-world diagnosis plus genuinely distinct M07 successor may follow.

### R10F continuous same-body passive-recovery successor design

The
[`QSDK-R10F design`](qsdk_r10f_continuous_passive_fall_recovery_successor_design_v1.json)
and
[`zero-world audit`](conformance/qsdk_r10f_continuous_passive_fall_recovery_successor_design.py)
select a new development path without changing the consumed R10E-L3 record.
One exact recovery-native S169 body must establish standing with V6, walk for
720 steps under a fresh BW5R-B session, receive the unchanged native
`0.25 N s` lateral kick while walking motors are disabled, pass through a
zero-actuation prone-confirmation interval, stand under V6, and complete a
fresh 720-step walking-resume session. Body, joint, scene-tree, contact,
velocity, and solver identity remain continuous throughout.

The old walking fixture is not reused as if it were the same morphology. Its
limb shapes, five-body callback coverage, and `0.95` friction differ from the
recovery-native capsule-limb, nine-callback-body, rough-`1.8` fixture. R10F
therefore requires a versioned locomotion facade that applies the already-
selected policy and actuator caps to the recovery body.

Recovery receives an explicit time origin without resetting the world. `G` is
the global completed step, `E` is the coherent completed post-kick boundary,
and local step `L = G - E` starts the recovery epoch. The complete live energy
at `E` initializes the new ledger. The kick is deliberately outside recovery
work and stays independently retained by its native application/effect receipt.

The audit binds 15 exact authorities, reopens all 35 consumed R10E-L3 files /
`79,688,410` bytes, checks 48 source seams, exercises offset-time, complete-
energy, and 17-node same-body canaries, and refuses 262 mutations. It performs
zero model constructions, world attempts, world builds, native readbacks, and
solver steps. Development seed `40200` and both of its prospective arms remain
unopened; held-out seeds `40201`-`40203` remain sealed.

This is passive, event-triggered recovery—not real-time force-aware bracing or
recovery. It changes no M07 status, support or release claim, threshold, score,
or physical authority. Implementation and exhaustive zero-world qualification
must complete before any source freeze or execution authority can exist.

### R10E observer-minimized upright-push successor design

The
[`QSDK-R10E design`](qsdk_r10e_observer_minimized_upright_push_recovery_successor_design_v1.json)
and
[`audit`](conformance/qsdk_r10e_observer_minimized_upright_push_recovery_successor_design.py)
close the retained R10D diagnosis without opening another world. The held-out
`push_s40102` worker completed one Godot/Jolt world, 2,979 total ticks, and a
2,739-row SDK trace. Its evaluator rejected only the world-impulse link after
a binary64-normalized task axis was rematerialized as binary32; the resulting
`1.4901189615557087e-8 N s` difference exceeded a validator intended for one
numeric path. The other 14 application predicates passed. This does not admit
the cell or complete the six-world matrix, so R10D remains consumed and
invalid/incomplete with no held-out behavior conclusion.

All five admitted R10D cells separately fail the unchanged walking conjunction
only on anchor error. Three paired prefixes contain 2,700 exactly equal rows
before the step-900 push after excluding only `cell_id`, so the later impulse
cannot explain the shared pre-push behavior. R10E therefore keeps all physical
and behavioral parameters but replaces live rich-row construction with flat
primitive capture and post-solver materialization. Its new receipt retains the
raw host-real task basis and uses the already-qualified exported-scalar
comparison pattern. Every step and field remains required.

The exact successor uses R05E generator 225 and held-out seeds `40101..40103`.
Generator 217 is still the historical overall anchor-margin leader but has
exposed R10D push outcomes. Generator 225 is the best remaining walking-
qualified exact body under a declared worst-seed margin rule; no recovery
advantage is claimed. Development seed `40002` precedes the held-out six-world
matrix. The audit rechecks 35 files / `117,830,382` bytes of R10D evidence, 45
application predicates, 135 R10D walking receipts, all 972 R05E walking
receipts, and 82 design mutations with all physical counters zero. Only R10E
zero-world implementation is authorized.

### Exact Godot/Jolt SDK1 envelope

The zero-world
[`QSDK-R13 decision`](release/qsdk_r13_godot_jolt_sdk1_envelope_decision_v1.json)
and its
[`executable audit`](conformance/qsdk_r13_godot_jolt_sdk1_envelope_decision.py)
compose retained mechanics, exact-point body variation, exact reference-body
material variation, basic turning, and nominal prone-to-standing evidence into
one bounded Godot/Jolt SDK1 product description.

This is a union of measured rows, not permission to mix every row together.
R05E's twelve named body points were measured at one material profile; BW5C's
four nonzero materials were measured on the reference body. Their cross-
product, interpolation between points, arbitrary bodies, pushes/kicks, force-
aware recovery, and general self-righting remain unsupported. Turning and
prone-to-standing also retain their separate controller and exact task limits.
The older C6 and C6R negatives remain unchanged. No model, world, native read,
solver step, package, or release was authorized by M08.

Authorities:

- semantics: [`../docs/LOCOMOTION_SEMANTICS_V1.md`](../docs/LOCOMOTION_SEMANTICS_V1.md)
- portable stability semantics:
  [`../docs/LOCOMOTION_SEMANTICS_V2.md`](../docs/LOCOMOTION_SEMANTICS_V2.md)
- partial-support mapping semantics:
  [`../docs/LOCOMOTION_SEMANTICS_V3.md`](../docs/LOCOMOTION_SEMANTICS_V3.md)
- canonical-velocity actuation semantics:
  [`../docs/LOCOMOTION_SEMANTICS_V4.md`](../docs/LOCOMOTION_SEMANTICS_V4.md)
- machine-readable canonical-velocity profile:
  [`canonical_velocity_actuation_profile_v1.json`](canonical_velocity_actuation_profile_v1.json)
- closed positive exact-finite Rapier ForceBased velocity-only host
  characterization declaration:
  [`rapier_c6_force_based_velocity_only_host_characterization_vh1_preregistration.json`](rapier_c6_force_based_velocity_only_host_characterization_vh1_preregistration.json)
- immutable VH1 closure:
  [`rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json`](rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json)
- executable VH1 closure audit:
  [`../tests/test_rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.ps1`](../tests/test_rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.ps1)
- closed negative exact-finite MuJoCo velocity-only host characterization:
  [`mujoco_c6_velocity_only_host_characterization_vh1_closure.json`](mujoco_c6_velocity_only_host_characterization_vh1_closure.json)
- executable MuJoCo VH1 closure audit:
  [`../tests/test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1`](../tests/test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1)
- frozen stability-aware MuJoCo VH2 declaration:
  [`mujoco_c6_velocity_only_stability_host_characterization_vh2_preregistration.json`](mujoco_c6_velocity_only_stability_host_characterization_vh2_preregistration.json)
- immutable implementation-invalid MuJoCo VH2 closure:
  [`mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.json`](mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.json)
- executable MuJoCo VH2 closure audit:
  [`../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.ps1`](../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.ps1)
- consumed corrected-binding MuJoCo VH3 declaration:
  [`mujoco_c6_velocity_only_stability_host_characterization_vh3_preregistration.json`](mujoco_c6_velocity_only_stability_host_characterization_vh3_preregistration.json)
- immutable temporal-instrumentation-invalid MuJoCo VH3 closure:
  [`mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json`](mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json)
- executable zero-world MuJoCo VH3 closure audit:
  [`../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.ps1`](../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.ps1)
- zero-world Rapier v4 live-integration declaration:
  [`rapier_c6_velocity_only_live_integration_v1.json`](rapier_c6_velocity_only_live_integration_v1.json)
- active Rapier velocity-only configuration v2:
  [`rapier_c6_velocity_only_active_configuration_v2.json`](rapier_c6_velocity_only_active_configuration_v2.json)
- executable live-integration preflight:
  [`run_rapier_c6_velocity_only_live_integration_preflight.ps1`](run_rapier_c6_velocity_only_live_integration_preflight.ps1)
- active v2 configuration audit:
  [`../tests/test_rapier_c6_velocity_only_active_configuration_v2.ps1`](../tests/test_rapier_c6_velocity_only_active_configuration_v2.ps1)
- frozen Rapier v4 EH1 paired mechanism-screen declaration:
  [`rapier_c6_bw19v_velocity_only_early_horizon_eh1_preregistration.json`](rapier_c6_bw19v_velocity_only_early_horizon_eh1_preregistration.json)
- EH1 zero-world/physical supervisor:
  [`run_rapier_c6_bw19v_velocity_only_early_horizon_eh1.ps1`](run_rapier_c6_bw19v_velocity_only_early_horizon_eh1.ps1)
- immutable EH1 closure:
  [`rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.json`](rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.json)
- executable EH1 closure and post-hoc reconstruction audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_early_horizon_eh1_closure.ps1)
- closed Rapier v4 LC1 long-horizon finite-commissioning declaration:
  [`rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json`](rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_preregistration.json)
- LC1 zero-world/physical supervisor:
  [`run_rapier_c6_bw19v_velocity_only_long_horizon_lc1.ps1`](run_rapier_c6_bw19v_velocity_only_long_horizon_lc1.ps1)
- immutable LC1 closure:
  [`rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_closure.json`](rapier_c6_bw19v_velocity_only_long_horizon_commissioning_lc1_closure.json)
- executable LC1 closure and post-hoc reconstruction audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_long_horizon_lc1_closure.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_long_horizon_lc1_closure.ps1)
- closed Rapier v4 TS1 active terminal-return declaration:
  [`rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_preregistration.json`](rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_preregistration.json)
- TS1 zero-world/physical supervisor:
  [`run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1`](run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1)
- immutable TS1 closure:
  [`rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json`](rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json)
- executable TS1 closure and deterministic post-hoc audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_terminal_stance_ts1_closure.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_terminal_stance_ts1_closure.ps1)
- prospective Rapier v4 TR1 frozen-memory contact-restoration declaration:
  [`rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_preregistration.json`](rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_preregistration.json)
- TR1 zero-world/one-shot supervisor:
  [`run_rapier_c6_bw19v_velocity_only_contact_restoration_tr1.ps1`](run_rapier_c6_bw19v_velocity_only_contact_restoration_tr1.ps1)
- executable TR1 prospective freeze audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_contact_restoration_tr1_freeze.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_contact_restoration_tr1_freeze.ps1)
- immutable TR1 valid-negative closure:
  [`rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_closure.json`](rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_closure.json)
- executable TR1 closure and deterministic post-hoc audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_contact_restoration_tr1_closure.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_contact_restoration_tr1_closure.ps1)
- prospective Rapier v4 PH1 pose-hold/restoration declaration:
  [`rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_preregistration.json`](rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_preregistration.json)
- PH1 zero-world/one-shot supervisor:
  [`run_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1.ps1`](run_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1.ps1)
- executable PH1 prospective freeze audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_freeze.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_freeze.ps1)
- PH1 deterministic retained-report evaluator:
  [`adapters/rapier/src/bin/bw19v_velocity_only_pose_hold_restoration_ph1_posthoc.rs`](adapters/rapier/src/bin/bw19v_velocity_only_pose_hold_restoration_ph1_posthoc.rs)
- immutable PH1 exact-finite positive closure:
  [`rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json`](rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.json)
- executable PH1 closure, evaluator-replay, and no-rerun audit:
  [`../tests/test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.ps1)
- closed-positive BW20F BW19V-B cold material declaration:
  [`balanced_wave_bw20f_cold_material_preregistration.json`](balanced_wave_bw20f_cold_material_preregistration.json)
- BW20F production receipt evaluator:
  [`balanced_wave_bw20f_material_characterization_gate.ps1`](balanced_wave_bw20f_material_characterization_gate.ps1)
- BW20F zero-world/physical supervisor:
  [`run_balanced_wave_bw20f_material_characterization.ps1`](run_balanced_wave_bw20f_material_characterization.ps1)
- immutable BW20F stage-1 closure:
  [`balanced_wave_bw20f_material_characterization_closure.json`](balanced_wave_bw20f_material_characterization_closure.json)
- executable BW20F closed-state audit:
  [`../tests/test_bw20f_material_characterization_closure.ps1`](../tests/test_bw20f_material_characterization_closure.ps1)
- retained historical BW20F prospective-freeze audit:
  [`../tests/test_bw20f_material_characterization_freeze.ps1`](../tests/test_bw20f_material_characterization_freeze.ps1)
- prospective BW20F deterministic profile-publication declaration:
  [`balanced_wave_bw20f_material_profile_publication_preregistration.json`](balanced_wave_bw20f_material_profile_publication_preregistration.json)
- BW20F zero-world profile-publication supervisor:
  [`run_balanced_wave_bw20f_material_profile_publication.ps1`](run_balanced_wave_bw20f_material_profile_publication.ps1)
- executable BW20F profile-publication freeze audit:
  [`../tests/test_bw20f_material_profile_publication_freeze.ps1`](../tests/test_bw20f_material_profile_publication_freeze.ps1)
- immutable BW20F profile-publication closure:
  [`balanced_wave_bw20f_material_profile_publication_closure.json`](balanced_wave_bw20f_material_profile_publication_closure.json)
- executable BW20F profile-publication closed-state audit:
  [`../tests/test_bw20f_material_profile_publication_closure.ps1`](../tests/test_bw20f_material_profile_publication_closure.ps1)
- prospective BW20F exact-finite material-locomotion declaration:
  [`balanced_wave_bw20f_material_locomotion_preregistration.json`](balanced_wave_bw20f_material_locomotion_preregistration.json)
- BW20F material-locomotion production evaluator:
  [`balanced_wave_bw20f_material_locomotion_gate.ps1`](balanced_wave_bw20f_material_locomotion_gate.ps1)
- BW20F zero-world/physical material-locomotion supervisor:
  [`run_balanced_wave_bw20f_material_locomotion.ps1`](run_balanced_wave_bw20f_material_locomotion.ps1)
- executable BW20F material-locomotion freeze audit:
  [`../tests/test_bw20f_material_locomotion_freeze.ps1`](../tests/test_bw20f_material_locomotion_freeze.ps1)
- prospective BW21L branch-free lateral-development candidates:
  [`balanced_wave_bw21l_lateral_development_candidates.json`](balanced_wave_bw21l_lateral_development_candidates.json)
- frozen BW21L 53-cell development preregistration:
  [`balanced_wave_bw21l_lateral_development_preregistration.json`](balanced_wave_bw21l_lateral_development_preregistration.json)
- BW21L 73-gate production evaluator:
  [`balanced_wave_bw21l_lateral_development_gate.ps1`](balanced_wave_bw21l_lateral_development_gate.ps1)
- BW21L zero-world/physical supervisor:
  [`run_balanced_wave_bw21l_lateral_development.ps1`](run_balanced_wave_bw21l_lateral_development.ps1)
- historical BW21L prospective-freeze audit:
  [`../tests/test_bw21l_lateral_development_freeze.ps1`](../tests/test_bw21l_lateral_development_freeze.ps1)
- immutable invalid BW21L physical closure:
  [`balanced_wave_bw21l_lateral_development_closure.json`](balanced_wave_bw21l_lateral_development_closure.json)
- executable BW21L invalid-closure audit:
  [`../tests/test_bw21l_lateral_development_closure.ps1`](../tests/test_bw21l_lateral_development_closure.ps1)
- architecture decision:
  [`../docs/adr/ADR-015_ENGINE_NEUTRAL_CORE_LANGUAGE_AND_BOUNDARY.md`](../docs/adr/ADR-015_ENGINE_NEUTRAL_CORE_LANGUAGE_AND_BOUNDARY.md)
- post-C6 successor decision:
  [`../docs/adr/ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md`](../docs/adr/ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md)
- portable balanced-wave successor decision:
  [`../docs/adr/ADR-017_PORTABLE_BALANCED_WAVE_SUCCESSOR.md`](../docs/adr/ADR-017_PORTABLE_BALANCED_WAVE_SUCCESSOR.md)
- balanced-wave evidence bootstrap:
  [`../docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md`](../docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
- live-code audit:
  [`../docs/SDK_POST_C6_AUDIT_2026-07-28.md`](../docs/SDK_POST_C6_AUDIT_2026-07-28.md)
- Godot/Jolt stability-influence commissioning:
  [`../docs/SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md`](../docs/SDK_GODOT_JOLT_STABILITY_INFLUENCE_BOOTSTRAP.md)
- public ABI: [`include/sporespore_locomotion.h`](include/sporespore_locomotion.h)
- exact Rust/C/Python/package-source conformance for `QSDK-R01` and
  `SDK1-M01`: [`portable_api/README.md`](portable_api/README.md)
- portable implementation: [`core`](core)
- Godot 4.7 GDExtension: [`adapters/godot`](adapters/godot)
- Rapier 0.34/Parry 0.29 adapter: [`adapters/rapier`](adapters/rapier)
- MuJoCo 3.11 adapter: [`adapters/mujoco`](adapters/mujoco)
- GDScript/Rust golden vectors:
  [`conformance/golden/candidate35_gq15_v1.json`](conformance/golden/candidate35_gq15_v1.json)
- convenience Python binding: [`python/sporespore_locomotion.py`](python/sporespore_locomotion.py)
- public adapter-authoring contract and reference fixture:
  [`adapter_kit/README.md`](adapter_kit/README.md)
- public optional-provider resolver, deterministic append-only experience
  layer, and executable Tier 2 successor pipeline:
  [`adaptation_provider/README.md`](adaptation_provider/README.md)
- public versioning, ABI, schema-migration, and deprecation contract:
  [`versioning/README.md`](versioning/README.md)
- standalone quickstart, diagnostics, and canonical record/replay guide:
  [`docs/QUADRUPED_SDK_INTEGRATION.md`](docs/QUADRUPED_SDK_INTEGRATION.md)
- executable standalone-quadruped submission boundary:
  [`release/README.md`](release/README.md)

## Closed Rapier v4 EH1 screen

`C6-RAP-BW19V-V4-EH1` is the first prospective two-world screen for the exact
v4 selected-policy path. It ran once from clean pushed source `fad011b`, built
both declared worlds, and retained all 944 trace steps and 7,552
commands/readbacks per layer. Its primary report is invalid and remains
`ok=false`; EH1 is permanently closed and `-RunPhysical` now fails before
checking mutable checkout inputs.

The primary gate expected the invented host profile ID
`rapier_force_based_velocity_only_target_v1`, while the production mapper and
all pinned v4 declarations use `rapier_force_based_velocity_only_v1`. It also
recomputed effective residual applications from pre-clamp nonzero residuals,
which is wrong when the final complete command saturates. Treatment contained
1,822 nonzero bounded residuals but 1,759 effective host changes; the remaining
63 were absorbed by the declared speed clamp. The frozen synthetic report had
neither an authoritative-profile witness nor a saturated-residual case, so it
shared both evaluator defects.

The immutable 79,950,421-byte report is retained at
`<evidence-root>\c6-rapier-bw19v-velocity-only-eh1-fad011b\report.json`,
SHA-256
`cdbcebc11eb727f9d24be6900788f6fd180cf8fc27a7df71780dc7d1921f6fa5`.
A distinct post-hoc diagnostic, SHA-256
`6f6c0fefe33b86fd0388101194344105b5e2fd1e6f184a55b8848ea1fdc523fa`,
shows that the immutable trace is otherwise completely reconstructible. Both
arms completed 472 steps with no declared event, torso-ground contact,
controller/composition error, nonfinite observation, motor-field mismatch, or
impulse-limit violation. This is useful diagnostic evidence, but it does not
restore primary integrity or grant physical acceptance.

The corrected, nonphysical regression route remains available:

```powershell
pwsh -NoProfile -File `
  .\sdk\run_rapier_c6_bw19v_velocity_only_early_horizon_eh1.ps1 `
  -PreflightOnly
```

Expected receipt:

```text
C6-RAP-BW19V-V4-EH1 PREFLIGHT_PASS arms=2 trace_steps=944 commands_per_layer=7552 outcomes=4 canaries=14 worlds=0 physical_authority=False
```

The four outcome-pattern checks, all 14 negative controls, the new
saturated-residual fidelity variant, and the closure audit are part of normal
conformance. A successor needs a new campaign/source/preregistration identity;
EH1 may not be rerun or reclassified. Neither the primary report nor its
post-hoc reconstruction establishes walking, BW19V improvement, selected-policy
physical authority, release, or cross-engine equivalence.

## Closed Rapier v4 LC1 long-horizon commissioning

`C6-RAP-BW19V-V4-LC1` was a one-world finite technical-commissioning
decision, not an EH1 rerun or repair. It asked only whether the exact BW19V-B
composition on the fixed s169 body can satisfy the complete declared walking
and integrity contract through the corrected Rapier v4 ForceBased
velocity-only path. The study estimates no population effect and grants no
superiority, equivalence, independent-validation, arbitrary-morphology,
material-robustness, cross-engine, release, or completed-SDK authority.

LC1 fixes 2,992 controller steps: 472 clocked steps, then contact-gated evidence
progression with a 1,440-step gait requirement, at most 720 extension steps, a
step-2,632 exclusive evidence deadline, and 360 required post-evidence steps.
It uses no zero-target settle because a zero-stiffness velocity-only motor has
no native posture-holding term. All walking thresholds are inherited
byte-for-value from the prospectively frozen pre-EH1 C2/ED1 family; none were
calibrated from EH1 observations.

The preregistration's raw SHA-256 is
`a5e88d5e0f69772c7dec67cc0d8bd83aa903ab2fe642a301fbf8ed3f09b47d0b`.
Its complete synthetic report exercises all 2,992 steps and 23,936 entries per
ordered command/readback layer, imports the production motor-profile identity,
includes a positive saturation case, and rejects 17 negative controls. The
zero-world receipt is:

```text
C6-RAP-BW19V-V4-LC1 PREFLIGHT_PASS trace_steps=2992 commands_per_layer=23936 bounded=2992 effective=2991 canaries=17 worlds=0 physical_authority=False
```

LC1 later consumed its one permitted world from clean pushed source `6a19680`.
The complete 250,318,994-byte report is retained under
`SporeSpore_Evidence\c6-rapier-bw19v-velocity-only-lc1-6a19680`, SHA-256
`a2fc9432b4c18806dae4c906b9d6e826c21b1468bcadf40f74baa24efa13146f`.
Its primary report is invalid and remains `ok=false`. The evaluator zipped
scheduler-ordered limb memory against morphology-ordered IDs by array
position; the synthetic report used the morphology order and failed to expose
that defect. Matching memory by explicit `limb_id` removes four cascade
failures but leaves the frozen `C6_RAP_V4_LC1_TERMINAL_STANCE` failure.

The post-hoc trace advanced `1.47705 m` through evidence completion and
`1.89383 m` overall, with zero torso contact, approximately `0.01975 m`
lateral drift, `0.00360 rad` yaw, `0.12280 rad` maximum tilt, and 5–6 contact
cycles per limb. All four contacts were present at evidence completion step
2,091. The completed gait memory then stayed fixed at step 1,912 while the
front-left knee reference remained at its raised-leg clamp; that foot lost
contact at step 2,094 and remained airborne for the final 898 steps. The body
stayed upright on the other three contacts, but the frozen four-contact
terminal gate is not waived.

The immutable closure's SHA-256 is
`526ed77562036f1a5e0a039269a053f154f29ec76903c3709006798a8b848206`.
Normal conformance now invokes the closure audit, which verifies the physical
Git blobs and every retained artifact, deterministically reruns the corrected
post-hoc evaluator, and proves `-RunPhysical` fails closed before mutable
checkout inputs. LC1 may not be rerun, rewritten, relaxed, or reclassified.
The complete pre-freeze non-Godot conformance pipeline passed in approximately
291.7 seconds, including the LC1 full-horizon gate; no LC1 world opened.
The complete closed-state pipeline subsequently passed in approximately 207.3
seconds with deterministic LC1 closure reconstruction and the rerun interlock.

## Closed negative Rapier v4 TS1 active terminal-return commissioning

`C6-RAP-BW19V-V4-TS1` is the scientifically distinct successor to LC1, not an
LC1 repair, rerun, threshold edit, or reclassification. It preserves the exact
fixed s169 body, BW19V-B composition, Rapier v4 ForceBased velocity-only host
path, inherited physical thresholds, 472-step clocked segment, 1,440
contact-gated evidence gait steps, and exclusive step-2,632 evidence deadline.
It changes only the prospectively declared post-evidence question: can the
active portable controller return the completed schedule to an analytically
selected four-limb stance reference and finish with all four contacts?

The source and LC1 trace fix the evidence endpoint at gait step `1912`, global
cycle step `112`. In production scheduler order
`rear_left, front_left, rear_right, front_right`, the local phases are
`112, 22, 292, 202`; front-left alone is inside the 72-step swing interval.
TS1 advances every limb by exactly 58 contact-gated gait steps to gait step
`1970`, global phase `170`, whose local phases are `170, 80, 350, 260`—all
stance. The target is fixed before outcome exposure. The maximum terminal
acquisition window is 180 semantic steps: 58 required gait advances, at most
120 wall-step holds at the simultaneously encountered production gates, and
two semantic-step accounting steps. TS1 then requires 360 post-terminal steps.
The total horizon is fixed at 3,172 steps with no outcome-dependent early stop
and no zero-target/native-settle phase.

The TS1 evaluator corrects LC1's order defect prospectively. Every limb-memory
layer must contain the complete unique limb-ID set and is evaluated by explicit
`limb_id`, never array position. The perfect synthetic report deliberately uses
the real scheduler memory order while the compiled morphology remains ordered
`front_left, front_right, rear_left, rear_right`; this would fail the former
positional zip. A focused unit test also proves that reversing the array does
not change the result when the explicit identities remain complete and unique.

The complete zero-world preflight covers all 3,172 trace steps and 25,376
commands at every actuation layer, imports the real production motor profile,
retains a positive saturation witness, analytically proves the terminal target
is all-stance, and rejects 23 negative controls. Its receipt is:

```text
C6-RAP-BW19V-V4-TS1 PREFLIGHT_PASS trace_steps=3172 commands_per_layer=25376 bounded=3172 effective=3171 canaries=23 identity_order=True terminal_target=1970 terminal_phase=170 worlds=0 physical_authority=False
```

The frozen artifacts are:

- [`rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_preregistration.json`](rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_preregistration.json),
  SHA-256 `749e873c5ee4652d59a266f046de638c36b656dc8a783ad43fadf67b8e2c1948`;
- [`adapters/rapier/src/bw19v_velocity_only_terminal_stance_ts1.rs`](adapters/rapier/src/bw19v_velocity_only_terminal_stance_ts1.rs),
  SHA-256 `38b2459a68199e66fe3446015f3184b8ca44d4173df64fb116eccec82d7e5244`;
- [`adapters/rapier/src/bin/bw19v_velocity_only_terminal_stance_ts1.rs`](adapters/rapier/src/bin/bw19v_velocity_only_terminal_stance_ts1.rs),
  SHA-256 `17928f36e7ab81635370cdf6419965513407cc556fd78c1fc0537494104906f0`;
- [`run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1`](run_rapier_c6_bw19v_velocity_only_terminal_stance_ts1.ps1),
  SHA-256 `732e8573dec2b743d34b09c348e525a5cf2536aff911dce37c5a708d55d0a1f7`;
- [`../tests/test_rapier_c6_bw19v_velocity_only_terminal_stance_ts1_freeze.ps1`](../tests/test_rapier_c6_bw19v_velocity_only_terminal_stance_ts1_freeze.ps1).

TS1 consumed its one permitted world from clean pushed source
`9cb55a581efe0b3743bcb2bee82eb3be6802efd0`. The complete 3,172-step primary
report is a valid negative with exactly one failure:
`C6_RAP_V4_TS1_TERMINAL_STANCE`. Every integrity counter is zero, all four
limb memories reached target gait step `1970` in 60 semantic steps, and 1,020
post-target steps were retained. Front-left contact ended at step `2094` and
never returned; its final site was `0.06796658784151077 m` high, or
`0.030245651801427208 m` above the mean of the three contacting sites.

The retained report is
`<evidence-root>/c6-rapier-bw19v-velocity-only-terminal-stance-ts1-9cb55a5/report.json`,
SHA-256 `4db84024a07b40d8edb3bfcfefbaa98e8c0d58996d7f4f985ba34a50309d968c`.
The deterministic post-hoc diagnostic beside it is SHA-256
`4dcf0c38951637c78a2e7b4771c2b64aa2e5b4e1266f3f345cc5e59aa01e2b1b`.
The immutable closure is
[`rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json`](rapier_c6_bw19v_velocity_only_terminal_stance_commissioning_ts1_closure.json),
SHA-256 `375fdec1e04efede7beefc80b0fd5a916f201e9b83fb40b572c28c20b9d43891`.
Its audit recomputes the frozen evaluator, regenerates the diagnostic
byte-for-byte, checks all source/evidence hashes, and proves `-RunPhysical`
fails closed before another world can open.

The chosen front-left local phase `80` satisfied the analytic predicate
`local_phase >= 72`, but the retained trajectory proves that predicate did not
guarantee a contact-restoring physical reference. Because direct per-step joint
angles were not retained, the evidence does not uniquely assign the final gap
to one joint, servo tracking error, kinematic reference geometry, or contact
detection. TS1 remains a negative result; its terminal gate was not waived or
reinterpreted. It establishes no finite walking contract, selected-policy
release C6, independent validation, population or arbitrary/continuous-
morphology coverage, friction/material or nuisance robustness, cross-engine
equivalence, release, physical-acceptance, or completed-SDK authority.

The complete pre-freeze `run_conformance.ps1 -SkipGodot` pipeline passed in
`390.0 s` with 98 portable-core tests, 32 Rapier tests, 2 Godot-adapter Rust
tests, the TS1 full-horizon freeze audit, all retained closures, and the wider
SDK conformance gates. TS1 remained zero-world and non-authoritative.

After closure integration, the complete `run_conformance.ps1 -SkipGodot`
pipeline passed in `259.7 s` with the same 98 portable-core, 32 Rapier, and 2
Godot-adapter Rust tests; deterministic TS1 report reconstruction; every
retained positive, negative, and invalid closure; and the adapter-authoring,
ABI/versioning, developer-experience, release-readiness, selector, and integrity
controls. The closure audit's expected child `-RunPhysical` refusal is reset to
an audit success status only after its nonzero exit and exact interlock message
are verified.

## Prospective Rapier v4 TR1 contact-restoration commissioning

`C6-RAP-BW19V-V4-TR1` preserves TS1's valid negative and asks a new mechanistic
question. The walking-evidence schedule is unchanged through gait step `1912`;
gait memory then remains frozen. Contacting limbs receive exact zero joint
velocity, while a missing limb receives a two-joint damped-least-squares
endpoint command for `[0,-0.02,0] m/s`, `lambda=0.04 m`, bounded to
`0.35 rad/s`. The production canonical Rapier ForceBased velocity-only mapper
still owns host commands; native position targets and stiffness remain zero.

The `3172`-step preflight records direct pre/post joint observations, retains
reconstructible kinematics for every terminal command, and rejects `29`
negative controls. It is zero-world and non-authoritative:

```text
C6-RAP-BW19V-V4-TR1 PREFLIGHT_PASS trace_steps=3172 commands_per_layer=25376 bounded=11985 effective=11984 canaries=29 identity_order=True restorer=dls_vertical_0.02 lambda=0.04 max_qdot=0.35 worlds=0 physical_authority=False
```

The prospective frozen artifacts are:

- preregistration SHA-256
  `4e1a3f402a7bce27fad8c5d9eac403e75cf9b4f7a8983260beb2cc8b4b2e7ee2`;
- evaluator SHA-256
  `4646a708545029a1bdc37885d567272fe4da13cef5cab5773b5651e18634e46a`;
- Rust binary source SHA-256
  `bfb506434ad6e3742ea666cd0dc92f7d2dccb4fece96f6fb2bad282e70eba7eb`;
- supervisor SHA-256
  `00a14125a763c967870c1b68b30195d40b6e056ab2eab3c3d2251b905d2df73b`;
- prospective freeze audit SHA-256
  `eccc012cac183a1ebfa44830f0b5d2c0266943463199a8eae59a5c2a135f88c0`.

The one-shot path remains hidden from the workbench. It can run only from a
clean pushed freeze with live-main equality, the global physical-operation
lock, and a fresh exact-source full-Godot V2 attestation. Any reserved process
consumes the identity. Even a positive result could have established only exact
finite s169 Rapier v4 contact-restoration technical commissioning plus the
declared single-body walking conjunction; it could not have established
release-selected C6, robustness, cross-engine equivalence, or release
authority.

## Closed Rapier v4 TR1 contact-restoration result

TR1 executed once from clean pushed freeze
`93f855ca443c92c3d1d386995e38961bac0a36b2` after the exact-source full-Godot
V2 attestation at SHA-256
`03a2a1177f5a3843a81e823a7679e8dc5000addf1ecfcf3093a6409f53c89b05`.
It retained one complete `3172`-step report, one world, zero resets, at
SHA-256
`e9f6e56c51092d1ce8d3fcfb880afde01fa1a17d23783fd8ff2f2e4cd88de419`.

The contact mechanism did what it was designed to test: all four physical
contacts were present at activation step `2092`, and the reset-aware
`360`-consecutive-contact hold completed at step `3161` with a longest run of
`370`. The complete conjunction nevertheless failed. Final yaw was
`0.505171 rad` against a `0.45 rad` bound; maximum tilt was `0.996172 rad`
against `0.6 rad`; minimum torso height was `0.229626 m` against
`0.249971 m`; and torso-ground contact persisted for `66` steps. The frozen
evaluator therefore retained the exact failures `DECLARED_PHYSICAL_EVENT`,
`YAW_DRIFT`, `TILT`, `TORSO_HEIGHT`, and `TORSO_GROUND_CONTACT`.

The seven-file evidence tree is
`<evidence-root>\c6-rapier-bw19v-velocity-only-contact-restoration-tr1-93f855c`,
tree SHA-256
`507ca62d879afe471e76fe65a317759a8b02602ef02f254bf5954f6e8dbce7b0`.
The immutable closure is
[`rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_closure.json`](rapier_c6_bw19v_velocity_only_contact_restoration_commissioning_tr1_closure.json),
SHA-256
`1bb0204dd78733ee5de6b1af95007625e844108fd9246d5ab353fc0aa5e7b127`.
Normal conformance recomputes the frozen evaluator and proves same-identity
physical refusal. Contact restoration is a development observation under a
failed walking contract; it is not technical commissioning, walking
acceptance, selected-policy C6, release, or cross-engine authority.

## Standalone quadruped submission status

The SDK source tree is not currently authorized for release or packaging.
[`release/quadruped_release_contract.json`](release/quadruped_release_contract.json)
and
[`release/quadruped_support_matrix.json`](release/quadruped_support_matrix.json)
make that boundary machine-readable. The current contract classifies 29 gates:
all 4 informational proofs are intact, while 10 of 25 release requirements
pass; 11 are missing and 4 are contradicted by retained negative physical
evidence. R21/R22 now pass for the optional-provider adaptation interface and
executable Tier 2 architecture. The remaining new requirements are commanded
turning, prone-to-standing, and formal cross-engine comparative inference.
The product and learned-adaptation sequence is maintained in
[`../docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md`](../docs/SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md).

The commanded-turning prerequisite is now source-complete under
[`turning`](turning/README.md). The selected public `MotionCommand`/C ABI/
Python surface already carried absolute heading requests; H0-H8 now prove
exact omitted-versus-reference-heading output, signed bilateral steering,
bounded and wrapped errors, typed ordered safe-zero refusals, exact
stateless/session equivalence, and finite ordered output at all 64 descriptor
vertices. Run it with:

```powershell
.\sdk\run_heading_command_turning_conformance.ps1
```

It builds zero worlds and deliberately leaves QSDK-R23 missing. It is not a
real-physics turn, zero-command physical straight-walk comparison, continuous
morphology result, cross-engine result, or release proof.

R23D60 has since closed positive for one exact held-out Godot/Jolt case. The
selected `portable_hip__fixture_knee` profile, exact
`qsdk_r05_generated_s169` morphology, seed `21516`, frozen schedule, and
reference/`+0.2`/`-0.2 rad` arms all passed their preregistered common and
directional gates. That is a bounded Godot/Jolt finite decision—not portable
three-engine turning, repeatability, arbitrary morphology, equivalence, or
QSDK-R23.

R23D61 now publishes that selected eight-cap vector as the versioned public
profile
`sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1`. The core, C ABI,
Python, and Godot GDExtension return a content-addressed receipt with explicit
exact-support, OOD-morphology, and unsupported-profile semantics. Godot, Rapier,
and MuJoCo mappings preserve maximum angular impulse over the complete `120 Hz`
outer step. Cross-language support is keyed by the canonical descriptor and
compiled morphology digests; every published cap is separately bound by its
binary64 hexadecimal identity. A provisional raw-bit descriptor gate is a
retained zero-world negative because it falsely refused Godot's equivalent
JSON-decoded descriptor. Run the complete local zero-world boundary with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_qsdk_r23d61_zero_world_gate.ps1
```

It passes `6` core tests, `2` Rapier tests, `2` MuJoCo tests, one real-library
Python FFI test, the Godot 4.7 runtime gate, and `35` adapter mutation controls.
It opens zero worlds and proves configured mappings only, not measured torque,
movement, turning in Rapier/MuJoCo, cross-engine equivalence, or physical
acceptance. The exact contract is
[`turning/r23d61_selected_actuator_profile_publication_v1.json`](turning/r23d61_selected_actuator_profile_publication_v1.json).
The publication is closed by
[`turning/r23d61_selected_actuator_profile_publication_closure_v1.json`](turning/r23d61_selected_actuator_profile_publication_closure_v1.json).
Its clean-pushed full-cold qualification passed all eight stages from source
`c61e56907d255e920297f088b93fc3e09ba12aef`, with retained receipt SHA-256
`f2afd63e164ea53c12823f78477de75a879fb8e415f530ac5ae5f6d54ad323a2`.

The later R23D62 and R23D63 score-bearing successors did not close QSDK-R23.
R23D62 was consumed before physics by an authorization-receipt projection
defect. R23D63 then passed its fresh `23`-gate qualification, separate adoption,
and complete `13`-gate zero-world freeze from exact clean-pushed source
`649277e3abc8cfd481cfc6cd22719f32ebc9a332`. Its first three Godot
authorization-preflight processes passed, but Rapier rejected the supervisor's
`--campaign-seed` option because the production binary accepts `--seed`. The
retained attempt contains zero physical cells, models, worlds, steps, traces,
measurements, or turning results. R23D63 is consumed invalid/incomplete and
cannot be patched or rerun; the exact authority is
[`turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json`](turning/r23d63_selected_profile_three_engine_turning_validation_closure_v1.json).
R23D64 is the distinct launcher-contract successor. It uses unused seed
`23171`, leaves all scientific turning semantics unchanged, and routes both
Rapier supervisor vectors through one shared builder using the production
parser's exact `--seed` option. Its complete zero-world surface covers `3/3`
authorization producers, `2/2` launcher call sites, all three public-profile
routes, all three native workers, nine arm preflights, `14` campaign gates,
and a `233`-path/`229`-edge recursive dependency closure. Run the safe local
boundary with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_qsdk_r23d64_supervisor.ps1 -PreflightOnly
```

The first R23D64 clean-pushed qualification at `d1b3f9bf...` passed `12`
global and `2` lineage gates, then failed closed at ordinal `15` because the
directly invoked receipt gate could not import MuJoCo from system Python with
an empty caller `PYTHONPATH`. Its complete retained `47`-file, `341,615`-byte
root records zero models, worlds, solver steps, consumed physical identity, or
turning result. The prospective gate correction now self-binds and hashes all
`9` locked distributions and `8,094` installed files (`131,440,050` bytes),
and passes both empty and non-empty caller-path controls with zero margins. A
fresh corrected-source qualification is mandatory; the failed qualification
is not reusable.

This remains prospective machinery with zero attempted worlds. It must be
corrected, clean-pushed, freshly qualified, and separately adopted before the one-shot
nine-world finite decision may open. `QSDK-R23` and the release total remain
false at `10/25` until a valid-complete positive and immutable physical closure
pass. R24D10 prone/recovery development remains separate, and no prone physical
world has opened.

The first shared physical-development question was implemented and consumed as
QSDK-R23D1. It declared the
exact-s169 `BW5R-B` matrix across three engines and three heading arms and
cold-evaluates a common normalized v2 report whose native-validation provenance
was load-bearing. Its design gate proved the schedule and rejected 29 negative
controls. All three actual workers were commissioned at zero worlds:

```powershell
.\sdk\run_qsdk_r23d1_physical_development_preflight.ps1
```

The three actual-route gates invoke each engine's real BW5R-B command boundary
for all three arms, validate engine-specific host and mapping receipts, signed
steering, zero legacy-parity claims or waivers, unknown-arm refusal, and direct-
physical bypass refusal, and still open zero worlds:

```powershell
.\sdk\run_qsdk_r23d1_godot_jolt_worker_preflight.ps1
.\sdk\run_qsdk_r23d1_rapier_worker_preflight.ps1
.\sdk\run_qsdk_r23d1_mujoco_worker_preflight.ps1
```

The frozen aggregate supervisor composed those three bundles in exact nine-cell
order, retains every synthetic report through a test content-addressed store,
passes the shared aggregate, rejects three incomplete/reordered/tampered
aggregates, exercises the operation-lock path, rejects a stale full-conformance
attestation, and refuses an unattested physical launch before reserving an
attempt. That prospective audit remains historical:

```powershell
.\tests\test_qsdk_r23d1_supervisor_freeze.ps1
```

Do not invoke an individual physical R23D1 cell. The authorization source was
cleanly pushed at `dd61a90`, matched local/origin/live `main`, and passed exact-
source full-Godot V2 conformance at SHA-256
`0ebd70a6238db4e791fb4e99921729c36a3c56c583e7e73d953f427d2bf3e9b3`.
The supervisor then consumed all nine ordered process slots. Godot/Jolt
retained `3/3` complete reports; Rapier/Parry and MuJoCo retained `0/3` each
after rejecting the first real controller-validation step. The shared workers
had incorrectly required the controller's desired heading error to equal the
raw heading command, although the selected controller also applies nonzero
cross-track position and velocity corrections. Their zero-world states had
hidden that mismatch.

R23D1 is now immutable, implementation-invalid, and incomplete—not a positive
or negative three-engine result. Its closure is
[`turning/physical_development_closure_v1.json`](turning/physical_development_closure_v1.json),
SHA-256
`022b42ae025abc3ee4eb502ee1857d5b43c1f6bc0e67b7e84c07bd6aa7076717`,
with executable audit
[`../tests/test_qsdk_r23d1_closure.ps1`](../tests/test_qsdk_r23d1_closure.ps1).
The current supervisor and the Godot/Jolt, Rapier/Parry, and MuJoCo worker
entrypoints each refuse every physical rerun before campaign or solver loading;
selective completion is mechanically unavailable. QSDK-R23, turning,
zero-command all-engine compatibility, equivalence, and release authority
remain false; the corrected lineage must use distinct identity QSDK-R23D2.
That successor now has a physically unauthorized stage-zero oracle
preregistration at
[`turning/r23d2_oracle_preregistration.json`](turning/r23d2_oracle_preregistration.json).
Its independent zero-world gate passes seven canaries, including six nonzero
cross-track states that all reject the R23D1 raw-heading oracle, 35 per-field
negative controls, and six stage-aware failure-count controls. The separate
Rapier worker contract and gate are now commissioned at zero-world: all three
arm entrypoints add explicit zero/positive/negative command boundaries to the
21 generic oracle canaries. The resulting 24 selected-policy controller steps
validate 192 ForceBased native commands and 24 host mappings, reject the old
oracle 18 times, and pass 105 field mutations. The direct physical route
refuses before any world attempt.

The MuJoCo physical worker is now implemented behind the same closed shared
authorization. Its zero-world gate executes the same 21 generic canaries plus three signed arm
commands through 24 public-core-DLL controller steps, 192 VH5-characterized
native commands, 24 host mappings, and three production model-XML validations.
The gate traps any preflight `MjModel` construction, validates `3/3`
evaluator-shaped success reports and `18/18` stage-specific failures, and
proves zero model/world builds. The dormant physical route preserves the R23D1
world/settlement/controller/schedule while independently validating every
physical controller receipt.
The Godot/Jolt worker is independently commissioned too. It executes the same
24 controller steps through 24 real GDExtension sessions, validates 192 native
commands and 24 production host mappings, and performs 192 writes/readbacks on
unparented `HingeJoint3D` motor objects. No object enters the SceneTree and no
physics world is built. Its physical world/report/failure route is now
implemented behind the still-closed shared authorization. Three exact one-step
trace canaries, `3/3` evaluator-shaped success reports, and `18/18` arm-by-stage
failure receipts pass while direct physical bypass records zero attempts and
builds. Actual R23D2 engine and physical workers are therefore both `3/3`; the
shared evaluator and complete synthetic supervisor are commissioned. The clean
prospective source/runtime freeze, exact-source attestation, and physical
execution remain unfinished. This is not turning or physical evidence.
The prior canonical no-Godot conformance route including the Rapier worker,
before this MuJoCo worker was added, exited `0` in `1,775.2 s` without opening
an R23D2 world. The uninterrupted prospective-worktree route including both
workers then exited `0` in `1,515.4 s`, also with no R23D2 world. This is
precommit implementation qualification, not physical authorization.
The integrated prospective-worktree `sdk/run_conformance.ps1` route then
exited `0` in `1,831.5 s`, with all three R23D2 worker gates included and no
R23D2 world opened. This is precommit implementation qualification, not
clean-pushed physical authorization.

The current shared contract is
[`turning/r23d2_development_contract_v1.json`](turning/r23d2_development_contract_v1.json),
implemented by
[`turning/r23d2_development.py`](turning/r23d2_development.py). Unlike the
closed R23D1 evaluator, it distinguishes a structurally valid physical negative
from implementation invalidity and sums the workers' actual stage-aware attempt
and build counts. The focused runner
[`run_qsdk_r23d2_development_preflight.ps1`](run_qsdk_r23d2_development_preflight.ps1)
passes a synthetic `9/9` positive, one valid-negative aggregate, `18/18`
structural rejections, nine valid outcome-negative controls, `4/4` malformed
aggregate rejections, all six stage receipts, and `5/5` provenance-mutation
rejections. Rejected projections are canonicalized before embedding and
hashing, and cross-language expected receipts remain structurally exact while
using only the selected profile's frozen `1e-12` tolerance for numeric receipt
fields.

[`run_qsdk_r23d2_supervisor.ps1`](run_qsdk_r23d2_supervisor.ps1) serializes the
oracle, evaluator, and all three real zero-world worker gates. Its executable
audit content-addresses nine synthetic reports plus three staged failure
receipts before cross-process aggregation, verifies projected stage totals
`8/8`, `9/8`, and `9/9`, and proves direct physical mode refuses before any
attestation or world. Run it with:

```powershell
.\tests\test_qsdk_r23d2_supervisor.ps1
```

The passing marker is:

```text
QSDK_R23D2_SUPERVISOR_AUDIT_PASS workers=3 entrypoints=9 reports=9 failure_receipts=3 aggregate=1/1 valid_negative=1/1 negative_controls=4/4 stage_counts=3/3 physical_refusal=1 physical_workers=3/3 worlds=0 physical_authority=False
```

This closes the complete synthetic `3 engines x 3 arms` aggregate layer and
records exactly `3/3` physical workers implemented. No R23D2 physical world,
source/runtime freeze, exact-source attestation, development result, turning
result, equivalence result, or QSDK-R23 authority exists yet.

With this aggregate layer and its safe workbench row integrated, the canonical
no-Godot conformance route exited `0` in `1,402.3 s`. The complete Godot-
inclusive route then exited `0` in `1,570.4 s`, including all workbench
Godot/live self-tests and the supervisor's three real adapter boundaries. Both
runs came from the dirty prospective worktree, opened no R23D2 world, and are
precommit implementation qualification only.

With the authorization-closed Rapier physical worker integrated, the complete
Godot-inclusive canonical route again exited `0`, in `1,642.521 s`. The
expanded Rapier gate and complete three-worker supervisor passed, zero R23D2
worlds opened, and no R23D2 physical identity was consumed. This is still
prospective-worktree implementation qualification, not physical authority.

The subsequent MuJoCo and Godot/Jolt physical-worker focused gates each passed
with `3/3` success-report canaries and `18/18` failure-stage receipts. MuJoCo
constructed zero models; Godot inserted zero physics objects into a SceneTree;
both opened zero worlds. The complete supervisor now reports
`physical_workers=3/3`. Canonical Godot-inclusive conformance then exited `0`
in `1,658.506 s`, with no R23D2 world or physical identity consumed. The
isolated clean-pushed boundary remains required before a physical freeze.

From PowerShell at the repository root:

```powershell
.\sdk\test_quadruped_sdk_release_readiness.ps1
.\sdk\compile_quadruped_sdk_release_readiness.ps1
```

The compiler currently returns `status=blocked`. The package command in
[`package_quadruped_sdk.ps1`](package_quadruped_sdk.ps1) reruns the live
compiler before creating output, so neither a stale nor hand-edited readiness
report can authorize publication. Its separate `-CleanRoomCandidate` stage
can run only after all non-package-validation gates pass, carries no release
or publication authority, and exists to generate the R01/R16/R20 evidence
needed by the final `-RequireReady` path. Exact requirements, current
blockers, commands, durable evidence paths, and SHA-256 identities are in
[`release/README.md`](release/README.md).

## Standalone developer experience

The source implementation for QSDK-R16 now lives entirely inside this SDK
tree:

- runnable selected-policy quickstart:
  [`examples/quadruped_quickstart.py`](examples/quadruped_quickstart.py);
- engine-neutral descriptor diagnostics:
  [`diagnostics`](diagnostics);
- canonical, hash-chained JSONL verification and deterministic policy replay:
  [`record_replay`](record_replay);
- positive and fail-closed conformance:
  [`developer_experience/test_developer_experience.py`](developer_experience/test_developer_experience.py);
- machine-readable contract:
  [`developer_experience_contract_v1.json`](developer_experience_contract_v1.json);
  and
- complete host-loop, troubleshooting, and migration instructions:
  [`docs/QUADRUPED_SDK_INTEGRATION.md`](docs/QUADRUPED_SDK_INTEGRATION.md).

Run the source suite after building the release core:

```powershell
Set-Location .\sdk
.\run_developer_experience_conformance.ps1 -SkipBuild
```

It passes eight Python tests plus the quickstart, diagnostics CLI, recording
verifier, and deterministic replayer. Modified/deleted records, numeric
transport drift, version drift, and policy mismatch fail closed. Every receipt
keeps world builds, walking acceptance, physics replay, and
physical-acceptance authority false.

QSDK-R16 now passes from the clean-room candidate outside the game tree,
with its complete source inventory verified and the same locally built library
used by R01. The [acceptance closure](release/sdk1_package_acceptance_closure_v1.json)
pins that isolated result. `record_replay.implemented` is true; physics replay
and new physical acceptance remain false. The following earlier source-only
receipt is retained as history. The clean pushed-source receipt is retained at
`<evidence-root>\sdk-developer-experience-d0da604\report.json`,
SHA-256
`e31ad6186bcae10b70593a2af7861bef8faeeefc548653a27f3e2cb5b973f016`,
and indexed by
[`developer_experience_validation_manifest.json`](developer_experience_validation_manifest.json).

## Build and verify

From PowerShell in the repository root:

```powershell
Set-Location .\sdk
cargo build --workspace --release --offline
.\run_conformance.ps1
```

Expected result:

- all `98/98` Rust core unit/ABI/golden-vector tests, `2/2` Godot adapter
  boundary tests, and `29/29` Rapier adapter/conformance tests pass;
- the public adapter-authoring fixture passes its `6/6` unit tests and all
  A0-A6 cells with zero physics worlds;
- the versioning fixture passes its `6/6` source tests and all V0-V6 cells,
  including live dynamic-library symbol resolution and a
  semantics-preserving migration;
- the no-world Godot oracle reports `105 passed, 0 failed`;
- the independent balanced-wave profile oracle reports `10 passed, 0 failed`
  and `10,001/10,001` formula samples;
- the independent stability-v2 Godot oracle reports `23 passed, 0 failed`;
- the independent stability-v3 subset-map oracle reports `12 passed, 0 failed`;
- the native Godot-adapter test reports `41 passed, 0 failed`;
- the Python `ctypes` smoke suite passes `12/12` tests against the real release
  DLL;
- the developer-experience source suite passes `8/8` positive and negative
  tests plus its four public CLI paths, while retaining `r16_passed=false`;
  and
- the script ends with `SDK C0/C1 conformance passed.`

The portable balanced-wave boundary retains the backward-compatible
`balanced_wave_profile_json` and `balanced_wave_step_json` entry points for
`sporespore_balanced_wave_v1`. Strict named-policy callers use
`balanced_wave_policy_profile_json` and `balanced_wave_policy_step_json` with
an explicit policy ID. The currently implemented frozen IDs are:

- `sporespore_balanced_wave_v1` (`BW2-A`);
- `sporespore_balanced_wave_bw2_b_v1` (`BW2-B`); and
- `sporespore_balanced_wave_bw2_c_v1` (`BW2-C`);
- `sporespore_balanced_wave_bw2r_a_v1` (`BW2R-A`);
- `sporespore_balanced_wave_bw2r_b_v1` (`BW2R-B`); and
- `sporespore_balanced_wave_bw2r_c_v1` (`BW2R-C`);
- `sporespore_balanced_wave_bw4r_a_v1` (`BW4R-A`); and
- `sporespore_balanced_wave_bw4r_b_v1` (`BW4R-B`);
- `sporespore_balanced_wave_bw5r_a_v1` (`BW5R-A`);
- `sporespore_balanced_wave_bw5r_b_v1` (`BW5R-B`); and
- `sporespore_balanced_wave_bw5r_c_v1` (`BW5R-C`);
- `sporespore_balanced_wave_bw7d_a_v1` (`BW7D-A`);
- `sporespore_balanced_wave_bw7d_b_v1` (`BW7D-B`);
- `sporespore_balanced_wave_bw7d_c_v1` (`BW7D-C`); and
- `sporespore_balanced_wave_bw7d_d_v1` (`BW7D-D`).

BW5R development selection now freezes `BW5R-B` as the downstream policy.
The machine-readable binding and complete supersession history are
[`balanced_wave_selected_policy.json`](balanced_wave_selected_policy.json);
Rust callers can use `SELECTED_BALANCED_WAVE_POLICY_ID`, and C callers can use
`SS_SELECTED_BALANCED_WAVE_POLICY_ID`. The legacy unnamed balanced-wave entry
points remain bound to BW2-A for backward compatibility; new downstream
campaigns must request the selected policy explicitly.

BW4R-A/B are implemented rejected development candidates, not selected
policies. Their exact no-branch feedback-timing contract is
[`balanced_wave_bw4r_preregistration.json`](balanced_wave_bw4r_preregistration.json).
Each completed the same `58` opened-development worlds, and the compiler
verified all `116` before rejecting the family:

```powershell
.\sdk\run_balanced_wave_bw4r_development.ps1
```

The orchestrator retains all ten component reports and the compiled selection
under `<evidence-root>`. The retained
selection report is
`balanced-wave-bw4r-selection-b538bea\report.json` (SHA-256
`23bc6f88c46cbed8b848efd9b2663757fd2f33c5c2f9d260e69e4ddc35d6718b`).
Neither candidate met the zero-opened-BW4-treatment-nonwalk requirement, so
the BW4R family selected no policy. Its rejection remains preserved in the
selection history; C6 remains false.

BW5R-A/B/C are implemented development candidates. Their exact source-linked
contract is
[`balanced_wave_bw5r_preregistration.json`](balanced_wave_bw5r_preregistration.json).
All inherit BW2R-C, update bounded feedback every semantic step, and differ
only in a global first-order low-pass time constant of `1/32`, `1/16`, or
`1/8` of the fixed gait cycle. The DReCon source used for this composition and
experiment pattern is
`<repo>\DReCon.pdf`, SHA-256
`aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54`,
DOI `10.1145/3355089.3356536`, pages 5–7. No paper-specific learned policy,
query rate, numeric filter coefficient, humanoid constant, or empirical claim
is copied.

The complete comparison requires all three `58`-world matrices (`174` worlds
and `15` component reports) before selection:

```powershell
.\sdk\run_balanced_wave_bw5r_development.ps1
.\sdk\compile_balanced_wave_bw5r_selection.ps1
```

The controller-step receipt v2 exposes raw/prior/filtered steering, applied
delta, saturation, slew, alpha, and cycle-fraction time constant. The no-world
authority contract passes `11/11`; all opened-cohort preflights preserve
development-only authority and open zero worlds.

The complete source-bound run from
`d17b77afefddb19ae401f3f8f2e8b3b7708a02e6` retained all `174/174` worlds,
all `15` reports, and zero infrastructure/integrity failures. Its selector is:

```text
<evidence-root>\balanced-wave-bw5r-selection-d17b77a\report.json
sha256:d2819d1bca45592fe54f1fc22cd2ad19d64fb3cd9eafd8ad848601338f8b50fc
```

BW5R-A and BW5R-B both passed the mandatory zero-opened-BW4-treatment-nonwalk
gate. BW5R-B won the next lexicographic metric with two opened nonzero-material
treatment nonwalks versus A's three. The selected policy is
`sporespore_balanced_wave_bw5r_b_v1`, candidate digest
`sha256:9dfade277ff0dd28f47aa807447c51a24363ce9d10671930ae01b61273d5f59f`,
with a `1/16`-cycle filter.

This is development-selection authority only. New independent validation and
cold material partitions, fresh morphology and nuisance campaigns, and
Rapier/MuJoCo physical commissioning remain mandatory. Walking acceptance,
material robustness, cross-engine C6, and completed-SDK claims remain false.

BW6N subsequently rejected the selected policy's first combined
baseline/rough/push/sensor-noise campaign. Its opened-world diagnosis is the
sole outcome input to the prospectively frozen BW7D family in
[`balanced_wave_bw7d_preregistration.json`](balanced_wave_bw7d_preregistration.json).
BW7D is a complete branch-free `2 x 2` comparison of moderate/full global
release allowance and linear/reciprocal global steering-to-stride transforms.
It also adds a separate evidence-acquisition receipt whose maximum is the
existing 12-tick phase-skew envelope plus the existing 3-tick minimum airborne
dwell, prospectively reused as the stable all-support dwell; the observed
two-tick delay was not copied.

The zero-world contract and every candidate preflight are green:

```powershell
.\sdk\run_balanced_wave_bw7d_development.ps1 `
  -Candidate BW7D-A `
  -PreflightOnly
```

A full candidate run requires clean `HEAD == origin/main` and a durable
`report.json` output. All four 12-world reports are mandatory before:

```powershell
.\sdk\compile_balanced_wave_bw7d_selection.ps1 `
  -Report <A-report>,<B-report>,<C-report>,<D-report> `
  -Output <selection-directory>\report.json
```

Seeds `22501`-`22503` remain unopened independent validation reservations.
The later cold friction values `0.09`, `0.37`, `0.76`, and `1.18` with seeds
`23001`-`23003` are also sealed from development. No BW7D source or preflight
result is physical acceptance.

BW7D subsequently completed all 48 development worlds at experiment source
`0da1b70fc47e4ba877a3a7dc8016653d381c0b9e` and selected no candidate. A, B,
and D were integrity-complete but failed the zero-timeout/zero-nonwalk
eligibility rule. C completed all 12 worlds but retained two typed
`STABILITY_OVERLAY_CONTRIBUTION_INVALID` integrity failures, so the
preregistered all-complete interlock forbade selection.

The authoritative family closure is:

```text
<evidence-root>\balanced-wave-bw7d-family-closure-0da1b70-27ea2cc\report.json
sha256:a5664b16a01974d60bdc8b1f062ef17c262d63ea736d5417d3aefc069cf46bbe
```

[`balanced_wave_bw7d_closure_manifest.json`](balanced_wave_bw7d_closure_manifest.json)
pins all four report paths/hashes, non-promotable attempts, compiler identity,
and unopened reservations. BW7D is invalidated and rejected, has no
development-selection authority, and may not be patched or rerun. The next
successor requires a new preregistered branch-free identity.

The BW2R selection compiler verified `123/123` retained worlds. Its immutable
report is
`<evidence-root>\balanced-wave-bw2r-selection-924aa44\report.json`
(SHA-256
`038e30c3a044ae5b01a0e6d440de6a12931bc7a1fae534c4eb86570784e92ea0`).
That is development selection authority only.

Unknown policy IDs fail closed. The reference, material, and counterexample
runners accept their explicitly declared BW2/BW2R/BW4R/BW5R candidate IDs;
their physics matrices and each family selection order remain frozen by
[`balanced_wave_bw2_preregistration.json`](balanced_wave_bw2_preregistration.json).

After all three complete matrices exist, compile the source-bound selection
from the nine immutable retained reports:

```powershell
.\sdk\compile_balanced_wave_bw2_selection.ps1 `
  -Output 'C:\path\to\evidence\report.json'
```

The compiler verifies every report path, SHA-256, source commit, schema,
candidate policy digest, world/step/command count, execution gate, and
recomputed first-five score component. The preregistration names but does not
define the final normalized-safety-margin formula, so the compiler fails
closed if that tiebreak is required. It never invents a post-observation
normalization.

BW3 is separately frozen in
[`balanced_wave_bw3_preregistration.json`](balanced_wave_bw3_preregistration.json).
Before opening a physics result, run its no-world fixture/identity preflight:

```powershell
.\sdk\run_balanced_wave_bw3_material_characterization.ps1 -PreflightOnly
```

The first retained isolated characterization must run from clean, pushed
source and write into a new durable evidence directory:

```powershell
.\sdk\run_balanced_wave_bw3_material_characterization.ps1 `
  -Output 'C:\path\to\new-evidence-directory\report.json'
```

That campaign owns authored friction `0.30`, `0.70`, and `1.20`, three
breakaway/steady-slide replicates per value, and one frictionless control. It
does not run locomotion or grant material robustness. Only after its first
result is retained may its derived coefficients and exact provenance be
frozen as the three adapter profiles consumed by the separate `12`-world BW3
validation matrix.

The source-`98d12b5` first result is retained as a typed instrumentation
rejection; the unchanged campaign passed after the narrowly documented
analyzer-input repair at source `60df802`. Its accepted `19/19`, `10/10`
report is
`<evidence-root>\balanced-wave-bw3-material-characterization-60df802\report.json`
(SHA-256
`94d3d9b6b2dc9086c4e21840540d8faf8d2fb7f64d915bc809d8969e9accd2e7`).
The published Godot/Jolt profiles are:

- `godot_jolt_bw3_mu030_v1`: authored `0.30`, characterized `0.28`;
- `godot_jolt_bw3_mu070_v1`: authored `0.70`, characterized `0.68`; and
- `godot_jolt_bw3_mu120_v1`: authored `1.20`, characterized `1.00`.

Their clean-source, no-world `22/22` publication report is
`<evidence-root>\balanced-wave-bw3-material-profiles-03f36ec\report.json`
(SHA-256
`1f829a4ece0b5a7256de7ae22e04fa866f88c372459a49356ffcde5f5e368934`).

The separate locomotion-validation contract is frozen in
[`balanced_wave_bw3_validation_manifest.json`](balanced_wave_bw3_validation_manifest.json).
It binds both prerequisite evidence hashes, selected BW2-C, all three profile
digests, seeds `17001`-`17003`, the exact ordered `9`-treatment/`3`-control
matrix, and the `22` gates. Check it without constructing a world:

```powershell
.\sdk\run_balanced_wave_bw3_validation.ps1 -PreflightOnly
```

After that source is committed and pushed, retain the first complete result:

```powershell
.\sdk\run_balanced_wave_bw3_validation.ps1 `
  -Output 'C:\path\to\new-evidence-directory\report.json'
```

BW3 is development validation, not cold material acceptance or a
material-robustness claim.

The first complete BW3 validation at source `81acb53` is a retained rejection:

```text
<evidence-root>\balanced-wave-bw3-validation-81acb53\report.json
sha256:e3f590c090b3d352b0e2385e0342db98032cb478d136dc811ddeb524c972c9d1
```

It completed `12/12` worlds at zero execution-integrity failures and passed
`21/22` gates, `8/9` treatment walking gates, `3/3` controls, and `3/3`
causal pairs. The only false walking receipt was `bounded_lateral_drift` for
`validation_mu070_s17002_treatment`: `0.1356338263 m` against the frozen
`0.10 m` bound. That identity must not be rerun. A changed controller must
receive a new validation identity.

The selected BW2R-C replacement campaign is frozen in
[`balanced_wave_bw3r_preregistration.json`](balanced_wave_bw3r_preregistration.json).
Its material characterization uses previously unopened values `0.25`, `0.55`,
and `1.10`; its later validation uses seeds `17501`-`17503`. Both sets are
disjoint from old BW3 and from BW4's reserved cells. Verify the prospective
boundary without opening a physics result:

```powershell
.\sdk\run_balanced_wave_bw3r_material_characterization.ps1 -PreflightOnly
```

The first eligible characterization passed `19/19` gates over `10/10` worlds
at source `9d99485`. Its durable report is
`<evidence-root>\balanced-wave-bw3r-material-characterization-9d99485\report.json`
(SHA-256
`044952767924503bfd6f213dad930f24beedc256164d9bbceb5e8f31db44b1a1`).
It derives immutable Godot/Jolt profiles with controller coefficients `0.22`,
`0.53`, and `1.00`; it does not itself run locomotion or grant robustness.

The clean-source profile publication passed `25/25` zero-world gates at source
`2997ea6`. Its durable report is
`<evidence-root>\balanced-wave-bw3r-material-profiles-2997ea6\report.json`
(SHA-256
`7433787ac1dcf4264212f93b5b40c7ecde33fa4799c24c6da4bf7043782b68cb`).
The exact downstream validation contract is
[`balanced_wave_bw3r_validation_manifest.json`](balanced_wave_bw3r_validation_manifest.json).
Check it without opening a world:

```powershell
.\sdk\run_balanced_wave_bw3r_validation.ps1 -PreflightOnly
```

The first complete BW3R validation passed `22/22` gates across `12/12` worlds
at clean pushed source `8d43b76`. Its durable report is
`<evidence-root>\balanced-wave-bw3r-validation-8d43b76\report.json`
(SHA-256
`8cb29f019497a1b9bd0f4285ccd7eef20083ccd1b636ec5ef914d7e10e261913`).
The result contains `9/9` passing treatments, `3/3` matched controls, `3/3`
passing causal pairs, and zero execution-integrity failures. Its explicit
`retention_recovery` record documents that the PowerShell parent timed out
after launching Godot, the child completed naturally, the full raw engine log
was retained, and no physics world was rerun. BW3R opens BW4; it does not grant
material robustness or cross-engine C6.

The BW4 cold boundary is frozen in
[`balanced_wave_bw4_preregistration.json`](balanced_wave_bw4_preregistration.json).
It pins the accepted BW3R report and reserves authored friction
`0.15`, `0.50`, `0.90`, and `1.40` plus validation seeds
`18001`-`18003`. Before opening its first characterization world, verify the
`13`-world/`23`-gate sled contract without SceneTree insertion:

```powershell
.\sdk\run_balanced_wave_bw4_material_characterization.ps1 -PreflightOnly
```

The runner fails before physics if the durable BW3R report path, hash, source,
or accepted receipt drifts. Characterization publishes no locomotion or
material-robustness claim; its later immutable profiles must be committed and
published before the separately frozen `17`-world cold locomotion matrix can
open.

The branch-free balanced-wave successor has a separate zero-world BW0
conformance runner:

```powershell
.\sdk\run_balanced_wave_bw0_conformance.ps1 `
  -Output 'C:\path\to\evidence\report.json'
```

Its accepted clean-source report is
`<evidence-root>\balanced-wave-bw0-c2fe41c\report.json`
(SHA-256
`65b2c3d74eac94137e3b43734be19f1deeb932813777fd7f2254a59f13a289b2`);
the adjacent transcript SHA-256 is
`5a98c8342f23c8ccd703d85c97d35092c6055c127c2f396415f08e64d5c65e09`.
It accepts `7/7` focused balanced-wave tests, `1/1` retained Candidate 35
golden-vector regression, `65/65` full-workspace tests, and `12/12` Python
tests against the real release DLL. BW0 opens no physics world and grants no
locomotion, robustness, cross-engine C6, or completed-SDK claim. Full accepted
and rejected-run provenance is retained in the balanced-wave bootstrap linked
above.

The Godot/Jolt BW1 bridge and zero-authority same-world shadow use:

```powershell
.\sdk\run_balanced_wave_bw1_shadow.ps1 `
  -Output 'C:\path\to\evidence\report.json'
```

The runner requires clean pushed source and combines the `10,001`-sample
GDScript oracle, native boundary tests, material-profile regression, and one
fixed `1,514`-step Godot/Jolt shadow. It requires `12,112` complete bounded
balanced-wave commands and zero native motor/body writes. BW1 remains a shadow
integration gate and grants no physical locomotion, recovery, robustness,
cross-engine, or completed-SDK claim.

The accepted clean-source BW1 report is
`<evidence-root>\balanced-wave-bw1-f915168\report.json`
(source `f915168a546410ab2ed1f61ba2e9e38f560053bc`, report SHA-256
`e5d6d62e66d13885bfafd982fefd493c5ee5d1895d083939eb324df718534e5f`);
the adjacent transcript SHA-256 is
`39903ae63759caf9872674a4a25e77976bc1a10f90d15bd035bb0ef9a38fc719`.
It accepts `1/1` Candidate regression, `65/65` workspace, `12/12` real-DLL
  Python, `10,001/10,001` profile samples, `10/10` profile-oracle, `35/35`
  native-boundary, the then-current material-profile suite, and `12/12`
  physical-shadow gates.
The single world completes `1,514` steps and validates `12,112` commands with
zero native motor writes; every physical and cross-engine completion claim is
false.

The pure stability-v2 slice also has a focused evidence harness:

```powershell
.\sdk\run_stability_v2_conformance.ps1
```

It requires exactly `15/15` Rust stability/mapping tests and `23/23` independent
GDScript-oracle checks. Pass
`-Output C:\path\to\evidence\report.json` only from a clean committed
worktree to retain a machine-readable receipt. The report records source,
semantics, fixture, test, and Godot executable hashes while explicitly keeping
adapter emission, actuation, balance recovery, locomotion, material
robustness, cross-engine C6, and physical-acceptance authority false.

The separate partial-support v3 slice has its own no-world evidence harness:

```powershell
.\sdk\run_stability_v3_subset_map_conformance.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe' `
  -Output 'C:\path\to\evidence\report.json'
```

It requires focused Rust `5/5`, independent GDScript `12/12`, native Godot
`27/27`, and Python real-DLL `10/10`. The retained source-`8d1c536` report is
`<evidence-root>\stability-v3-subset-map-8d1c536\report.json`
(SHA-256
`0de2d43dda1698a1e716aae8f0fd693c0211c25f5cc617c5f7d2135510bcc8a9`).
It proves full-support v2/v3 equivalence and a three-contact exact-order map
with six active and two exact-zero inactive actuators. It constructs no
physics world and grants no motor-response, balance, recovery, or acceptance
authority.

The output-only physical Godot/Jolt shadow test is intentionally separate
because it constructs and advances a real physics world:

```powershell
Set-Location ..
.\sdk\run_godot_jolt_shadow_conformance.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe'
```

Expected result: `20 passed, 0 failed`, followed by
`Godot/Jolt SDK physical shadow conformance passed.` The script creates an
isolated temporary Godot project, pins Jolt at `120 Hz` and `20/7` solver
iterations before startup, and prints the retained transcript path. The last
eight gates require live stability-v2 state, zero native/GDScript observer
mismatches, typed centroidal/mapping outcomes, at least one available nonzero
eight-actuator `J-transpose` map, every signal inside its frozen shadow
tolerance, and zero stability actuation or physical authority. Pass
`-Output C:\path\to\evidence\report.json` from a clean commit to retain the
machine receipt and transcript.

The isolated Godot/Jolt motor-response characterization is a separate,
no-contact physical fixture:

```powershell
.\sdk\run_godot_jolt_motor_response_characterization.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe' `
  -Output 'C:\path\to\evidence\report.json'
```

It requires exactly `16 passed, 0 failed` over three independent `43`-cell
worlds and retains every per-tick response, fit intermediate, source hash,
transcript, and engine log. The accepted implementation-source report is
`<evidence-root>\godot-jolt-motor-response-c816ab3\report.json`
(SHA-256
`aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729`).
It characterizes only the pinned Godot 4.7/Jolt `120 Hz, 20/7` isolated hinge
response. It does not run a gait, apply a stability contribution, or grant
balance or physical-acceptance authority.

The exact legacy Candidate 35 material has a separate isolated provenance
gate because its authored friction `1.8` is outside Godot's documented
`[0,1]` range:

```powershell
.\sdk\run_godot_jolt_legacy_material_characterization.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe'
```

The runner creates independent force-driven sled worlds at the pinned
Godot/Jolt `120 Hz, 20/7` configuration, including a `0.0`-friction A/B
control and three legacy-material breakaway ramps. It applies no gait or
actuator command. Pass `-Output C:\path\to\evidence\report.json` from a clean
commit to retain the complete stage receipts and derived conservative
controller coefficient. The retained source-`d3d5cd1` report is
`<evidence-root>\godot-jolt-legacy-material-d3d5cd1\report.json`
(SHA-256
`f673eceb7e67a395943ebf7e00927a031d221a60eef371b1505b4a680db8a795`).
It brackets the exact legacy pair at `70-72 N` in all three worlds and derives
`controller_mu = 1.0`, while retaining every locomotion/material-robustness
claim as false.

The dedicated supported-capability C2-C5 campaign is also separate from
locomotion:

```powershell
.\sdk\run_godot_jolt_c2_c5_conformance.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe'
```

Expected result: `20 passed, 0 failed`, followed by
`Godot/Jolt SDK C2-C5 conformance passed.` C2 checks the canonical quadruped
topology, semantic order, joint frames, limits, observations, and coordinate
mapping. C3 characterizes controller-free integration, damping, free fall, and
a passive hinge. C4 characterizes the position-to-velocity conversion, native
velocity motor, and per-step impulse cap. C5 checks the adapter's declared
contact capability, live raw contact geometry/velocity/impulse provenance,
per-step contact identity, and the rule that unavailable normal load remains
null. It neither runs a gait nor grants physical-acceptance authority.

The Rapier/Parry adapter has its own native C2-C5 report:

```powershell
cargo run --manifest-path .\sdk\Cargo.toml `
  --package sporespore-rapier-adapter `
  --bin conformance
```

To retain a new report, add
`-- --output C:\path\to\evidence\report.json`. The executable refuses an
output filename other than `report.json` and writes through a temporary file.
Its C2-C5 cells cover pose/twist and revolute-joint mapping, free fall and
damping, the position/velocity motor with an exact per-step impulse-to-force
mapping, and contact/material provenance. Passing these cells does not run a
gait. Normal load, breakaway/steady-slide characterization, C6 locomotion,
controller-policy authority, and physical-acceptance authority remain false.

The project-local MuJoCo adapter has a dedicated C0-C5 harness:

```powershell
.\sdk\run_mujoco_c0_c5_conformance.ps1
```

Create `sdk\adapters\mujoco\.venv` with Python 3.11 and install
`sdk\adapters\mujoco\requirements-lock.txt` first. The harness rebuilds the
real release C ABI, runs `5/5` adapter tests, and emits the five-cell report.
Pass `-Output C:\path\to\evidence\report.json` to retain it. MuJoCo's Z-up
frame, explicit-Euler integration, force-limited position servo, 5D contact
friction, and solver contact force remain explicit host provenance; the
adapter does not relabel them as Godot/Jolt or Rapier semantics.

Both non-Godot host slices were refreshed from current clean source
`a2cf1a052b3685a64ca784035f595d2844fefbaf` after the BW5C cold result:

```text
<evidence-root>\rapier-c2-c5-a2cf1a0-refresh\report.json
sha256:e9f66bdbe96b920d0e12f7541658c2c17af575be4e504ba3475f266e06937fc1

<evidence-root>\mujoco-c0-c5-a2cf1a0-refresh\report.json
sha256:a4f6aa753387918aa3e1bc42cbc24998da427fcf68e1b15b6bbffa6fa83b3be4
```

The ignored MuJoCo environment was recreated from the exact checked-in lock
before that run and reports MuJoCo `3.11.0` and NumPy `2.4.6`. The real
`MjModel.from_xml_string` load and the adapter's `5/5` suite passed. Rapier
again passed `4/4`. These are refreshed C0-C5 receipts only: both reports keep
C6 locomotion, controller-policy authority, and physical-acceptance authority
false.

MuJoCo's first velocity-only host gate has completed and is permanently closed:

```powershell
.\tests\test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1
```

The original preflight constructed zero `MjModel` instances. It verified the exact
Python `3.11.9` / MuJoCo `3.11.0` / NumPy `2.4.6` host, nine installed
wheel/header files, the base interpreter, and the requirements lock. It then
routes a perfect serialized 12-cell target/load grid and ten corruptions
through the production evaluator. The declared native profile is MuJoCo's
unit-joint `velocity` actuator with `kv=10`, force range `[-6, 6] N m`, no
native position target, and no independent position feedback, under
`implicitfast` Newton `20/7` at `1/120 s`. This matches locomotion semantics
v4: the portable controller owns position feedback and the adapter receives
the complete canonical target velocity. The frozen source is
[`mujoco_c6_velocity_only_host_characterization_vh1_preregistration.json`](mujoco_c6_velocity_only_host_characterization_vh1_preregistration.json),
the implementation is
[`adapters/mujoco/sporespore_mujoco_adapter/velocity_only_characterization.py`](adapters/mujoco/sporespore_mujoco_adapter/velocity_only_characterization.py),
the immutable closure is
[`mujoco_c6_velocity_only_host_characterization_vh1_closure.json`](mujoco_c6_velocity_only_host_characterization_vh1_closure.json),
and the executable closure audit is
[`../tests/test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1`](../tests/test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1).

All declared loads are sub-limit, with maximum load fraction `0.375`; the gate
therefore characterizes only the finite affine sub-limit response, not dynamic
saturation. The implementation separately observes actuator-space force,
joint-space actuator torque, and applied generalized torque. A read-only
observation `MjData` buffer computes coherent post-step diagnostics without
feeding them into the primary trajectory. MuJoCo `xanchor` is treated as a
world-space position residual from the declared origin, not mislabeled as a
generic constraint error. The draft `100/50` solver declaration was corrected
to the shared builder's real `20/7` before any physical model was constructed.
The one permitted physical process ran from clean pushed source
`19831738abf8800f572e974898980c2b8aab1c40` under the global operation lock
and its exact-source full-Godot V2 attestation. It completed all `12/12` worlds
with zero resets, model/field mismatches, nonfinite observations, force-limit
violations, actuation/joint-space mismatches, or applied-torque readback
mismatches. All eight loaded cells passed: terminal normalized velocity was
within floating-point noise of `1.0`, normalized force was exactly `1.0`, and
all six signed pairs had zero measured asymmetry. All four unloaded cells
failed the frozen response gate: each ended at zero velocity with signed
`6 N m` saturated actuator force and no acceptable streak. The whole result is
therefore a complete valid negative, `8/12`, not a partial positive.

The retained report is
`<evidence-root>\c6-mujoco-velocity-only-vh1-1983173\report.json`,
SHA-256
`6f1ceb050e1bf5e7366db0ff619c8262e896ee1d930f3952c016862d6ff70d41`.
The unloaded endpoints support a prospective stability/limit-cycle hypothesis,
but VH1 did not retain every-step traces, so the exact trajectory is not a
measured VH1 claim. A distinct successor may use this result to preregister a
stability-aware timestep/substep, gain, inertia/armature, initial-condition
grid, and direct trace. VH1 itself may not be rerun, rethresholded, split, or
reclassified. Until that distinct host successor passes, MuJoCo selected-policy
integration, walking, saturation response, cross-engine equivalence, and
release authority remain false.

That scientifically distinct successor is now frozen prospectively as
`C6-MJC-HC-VH2`, but it has not opened a physical world. It keeps the portable
controller cadence at `1/120 s` while taking five `1/600 s` MuJoCo
`implicitfast` steps per controller step. The exact declared fixture changes
the source-grounded saturated-band crossing ratio from VH1's `5.0` to
approximately `1.0`; even the conservative armature-only upper ratio is
approximately `1.6666667`, below the declared no-full-band-skip bound of
`2.0`. These calculations are a finite design hypothesis, not a substitute
for the physical grid.

VH2 expands the original twelve signed target/load cells across two initial
conditions—zero velocity and adverse velocity opposite the predicted steady
response—for `24` once-built worlds. Each cell declares `360` controller
steps, `1,800` internal steps, at least one force-saturated transient, recovery
to at least `120` consecutive acceptable controller steps, and full retention
of a compact eleven-field internal trace, including direct generalized inertia
and joint-anchor residual. The aggregate trace therefore contains
`43,200` records. The physical path must read generalized inertia directly
from MuJoCo's one-DoF mass matrix and match the analytic fixture within
`1e-12 kg m^2`; it also retains the existing force, impulse, signed-pair,
readback, finite-value, operation-lock, clean-pushed-source, and exact
full-Godot-attestation gates.

Before freezing, the whole-gate audit caught and corrected a `14` versus `15`
negative-control declaration mismatch and an incomplete generalized-inertia
trace field. Three further prephysical canaries require numeric initial-state
readback and reject forged recovery streaks and coherent anchor-limit
violations. Those are legitimate prephysical infrastructure corrections:
the audit's constructor trap proves that neither the ordinary preflight nor
the trapped preflight can call the MuJoCo model constructor. The production
evaluator now accepts a perfect serialized `24`-cell result, reconstructs
recovery and integrity receipts from the retained trace, rejects all `18/18`
declared corruptions, and reports `worlds=0` and
`physical_authority=False`.

Run the safe prospective audit with:

```powershell
pwsh -NoProfile -File tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh2_freeze.ps1
```

Its terminal marker is:

```text
C6_MJC_HC_VH2_FREEZE_PASS cells=24 traces=43200 canaries=18 stability=5->1 armature_upper=1.666667 worlds=0 physical_authority=False
```

VH2 subsequently consumed its one permitted physical process at clean pushed
source `d6c38c5f11e389fe0f2f1356f2eb1918403e46e6`. The process constructed
one `MjModel` and two `MjData` instances, called `mj_forward` once, and then
raised `AttributeError` at the frozen `len(data.qM)` read because the pinned
MuJoCo `3.11.0` Python binding exposes `MjData.M`, not `MjData.qM`. It reached
zero `mj_step` calls, completed zero cells, and serialized no `report.json`.
Those counts are explicitly post-hoc control-flow inference from the retained
traceback and historical source—not physical measurements.

VH2 is therefore closed implementation-invalid, with neither a positive nor a
negative host-characterization result. Its retained six-file evidence tree is
audited at:

```powershell
pwsh -NoProfile -File tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh2_closure.ps1
```

The expected marker is:

```text
C6_MJC_HC_VH2_CLOSURE_PASS status=implementation-invalid models_inferred=1 steps_inferred=0 cells=0 report=False binding_M=True binding_qM=False scientific_result=False walking=False physical_authority=False rerun_refused=True
```

A distinct successor must pin the installed `M` and
`mj_fullM(model, data, destination)` interface in its zero-world preflight and
use a new campaign, gate, source identity, preregistration, attestation, and
one-shot attempt. No new Godot walker is required: BW19V remains the fixed
portable reference, and changing it here would confound host repair with a
moving controller target.

That successor is now prospectively frozen as `C6-MJC-HC-VH3`. VH3 rederives
and retains the same 24-cell, five-substep, two-initial-condition, 43,200-trace
estimand and unchanged numeric gate because VH2 generated no scientific
result. It does not reuse VH2's process identity. Its only implementation
correction is the source-grounded generalized-inertia boundary: each physical
readback uses a writable C-contiguous dense `float64` matrix filled by
`mj_fullM(model, data, destination)` over the binding's `M`-backed state.

Before an `MjModel` can be constructed, VH3 now requires all three binding
canaries: `MjData.M` exists, `MjData.qM` does not exist, and the installed
`mj_fullM` wrapper exposes the exact pinned model/data/destination signature.
The complete zero-world audit also retains the 24-cell production evaluator,
43,200 synthetic trace records, all 18 result-corruption controls, exact host
file hashes, and a constructor trap. Run it with:

```powershell
pwsh -NoProfile -File tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh3_freeze.ps1
```

The expected marker is:

```text
C6_MJC_HC_VH3_FREEZE_PASS cells=24 traces=43200 canaries=18 binding_canaries=3 stability=5->1 armature_upper=1.666667 worlds=0 physical_authority=False
```

This is prospective experiment infrastructure only. An ordinary zero-step,
non-campaign ABI smoke fixture calls the exact dense readback helper and
recovers `1/60 kg m^2`; it consumes no attempt and grants no physical
authority. No VH3 campaign world, host result, selected-policy trajectory, or
MuJoCo walking claim exists until the clean pushed source receives an exact
full-Godot V2 attestation and the one permitted physical process is retained
and immutably closed.

VH3 subsequently received that exact full-Godot attestation and consumed its
one permitted physical process at clean pushed source
`57e97f2f08636ef42b38511e11650e89b674dfaf`. It completed all `24` worlds
and all `43,200` trace rows. The frozen evaluator reported `22/24`: the signed
zero-initial unloaded `0.75 rad/s` pair alone had zero retained saturated rows.
That apparent negative is not scientifically valid. The implementation called
`mj_step`, copied the resulting state into a second `MjData`, called
`mj_forward`, and then labeled the recomputed post-state `actuator_force` and
`qfrc_actuator * dt` as the force and impulse of the completed step.

A zero-world forensic audit of the immutable traces reconstructs completed-step
motor impulse from the one-DoF momentum balance. It finds `114` capped steps,
versus `90` retained post-state saturation rows: exactly one saturation event
was lost in each of the `24` cells. In each reported failure, the first step
actually applied the `6 N m` cap for `0.01 N m s`, moving velocity from zero to
approximately `+/-0.6 rad/s`; the copied post-state recomputation instead read
approximately `+/-1.5 N m`. The maximum capped momentum-balance discrepancy is
about `3.47e-18 N m s`.

VH3 is therefore closed consumed and temporal-instrumentation-invalid, with no
scientific positive or negative. The complete report is real physical
development evidence, and its convergence behavior strongly informs a
corrected successor, but post-hoc reconstruction cannot retroactively rescore
or promote VH3. Audit it without opening a world:

```powershell
pwsh -NoProfile -File tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.ps1
```

The expected marker is:

```text
C6_MJC_HC_VH3_CLOSURE_PASS status=temporal-measurement-invalid worlds=24 reported_passed=22 reported_failed=2 retained_saturation=90 reconstructed_saturation=114 lost_events=24 integrity_otherwise=True scientific_positive=False scientific_negative=False walking=False physical_authority=False rerun_refused=True
```

The next MuJoCo host campaign must use a new identity and record actuation at
the pre-integration pipeline stage separately from post-integration state. It
must also cross-check completed-step motor impulse by the one-DoF momentum
balance, preserve the signed grid and force limits, and prove the entire gate
synthetically before constructing a campaign model. No new Godot walker is
needed: BW19V remains the fixed portable policy target, so host instrumentation
can be repaired without moving the controller under test.

The two native-authority campaigns are also isolated physical runs:

```powershell
.\sdk\run_godot_jolt_authority_handoff.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe'

.\sdk\run_godot_jolt_full_authority.ps1 `
  -Godot 'C:\path\to\Godot_v4.7-stable_mono_win64_console.exe'
```

The bounded handoff expects `11 passed, 0 failed`: GDScript retains warm-up
authority, then the native SDK exclusively applies every evidence command.
The full campaign expects `14 passed, 0 failed`: the SDK exclusively owns all
eight motors from the post-settle boundary through clocked warm-up,
contact-gated evidence, cooldown, and terminal settling. The full test emits a
machine-readable `SDK_FULL_AUTHORITY_RECEIPT` and independently gates
position, velocity, speed-limit, steering, and integer-phase mapping errors.

To run the Python ABI smoke suite directly after the release build:

```powershell
Set-Location .\sdk\python
python -m unittest -v test_ctypes_smoke.py
```

## C ABI example

The JSON calls use a caller-owned two-pass buffer:

1. call with `output = NULL` and capacity `0`;
2. allocate the exact `output_length` reported with
   `SS_BUFFER_TOO_SMALL`; and
3. call again and parse the returned UTF-8 JSON envelope.

Unknown fields, invalid IDs, nonfinite values, out-of-domain scales, unresolved
references, topology errors, and unsupported capability requests fail closed.
No SDK compile or pure-controller receipt carries physical acceptance
authority.

## Current evidence boundary

The core currently establishes:

- arbitrary valid semantic morphology IDs within the six-axis GQ15 descriptor;
- total compilation at every point of its closed descriptor box;
- exact Candidate 35 pure-policy parity with the frozen GDScript oracle;
- generic semantic scheduling for 2, 4, 6, 8, and 32 limbs;
- pure Locomotion Semantics v2 whole-system COM, gravity-aligned convex support
  geometry, linearized capture observation, bounded centroidal contact
  commands, a portable endpoint-force/Jacobian-to-generalized-joint-torque
  mapping, and a bounded fail-zero influence limiter, checked by `15/15` Rust
  tests and a shared `23/23` GDScript oracle without a physics world; the
  latest clean-commit receipt is
  `<evidence-root>\stability-v2-joint-map-f399ede\report.json`
  (SHA-256
  `2cf29aede42db40e233c54d486ad5ebda619cc01f02fc630c26ec327a67bec0a`);
- a stable C ABI exercised through Rust and Python; and
- a Godot 4.7 GDExtension that exercises the same C ABI and safely round-trips
  Godot's floating-point JSON representation of integer protocol fields;
- a Rapier `0.34.0`/Parry `0.29.0` Rust adapter whose retained clean-commit
  C2-C5 report passes `4/4` cells and whose capability manifest fails closed
  for unsupported material, load, policy, and locomotion claims;
- a MuJoCo `3.11.0` adapter in a project-local Python 3.11 environment whose
  retained clean-commit C0-C5 report passes `5/5` cells through the real Rust
  C ABI and fails closed for unsupported contact, material, policy, and
  locomotion claims;
- one dedicated `20/20` Godot/Jolt C2-C5 campaign covering the supported
  kinematic, passive-dynamics, actuator, and contact-observation capabilities
  on isolated fixtures without locomotion or acceptance authority;
- one full same-world Candidate 35 Godot/Jolt physical-shadow gait with all
  eight native commands compared per step, exact contact-gated phase, bounded
  binary32 host-mapping deltas, and zero native actuation;
- one retained same-world stability-v2 shadow at source
  `c0b130ea24ca82a443b678a3ef7d362ded2d7199` with `1,514/1,514`
  observations available, zero native/GDScript observer mismatches, and
  `16/16` gates. Its report is
  `<evidence-root>\godot-jolt-stability-shadow-c0b130e\report.json`
  (SHA-256
  `4f48b8e7a4c46452ba5c67006bb8e13e43a0a6ba25eba09e30c421a42b7acf74`);
  it explicitly grants no stability actuation, balance recovery, material
  robustness, or physical authority;
- one retained live Godot/Jolt centroidal-to-joint mapping shadow at source
  `e85cc2fb8b500ced389d8ccc74671671b60cf190`. Its `20/20` report records
  `1,514` attempts, `821` available exact-order full-support maps, `627`
  typed unavailable partial-support maps, `66` typed infeasibilities, `6,568`
  independently compared actuator commands, zero mismatches, and zero
  actuation. It is retained at
  `<evidence-root>\godot-jolt-joint-mapping-shadow-e85cc2f\report.json`
  (SHA-256
  `2aa5047762a0cbbb7562422682987eb2993da4f21f1540fe0637003bd7d77371`);
  its adjacent transcript SHA-256 is
  `4c97605af33e8323a2e1d8574a987ec092bf0652c4ce5be5c61b68ccd1f6a5ab`.
  The zero-gain result establishes live mapping transport, not actuator
  response, balance feedback, or recovery; and
- one retained isolated Godot/Jolt motor-response characterization at source
  `c816ab36e4b696d8e8073fac88e6570242909609`. Its first eligible `16/16`
  report pins sign `-1`, conservative proposal coefficient
  `0.24999998477941607 rad/s per N m`, uncertainty
  `3.0654117577633144e-8`, and an exact
  `0.2805286655276139 N m`/`0.075 rad/s` envelope. It is retained at
  `<evidence-root>\godot-jolt-motor-response-c816ab3\report.json`
  (SHA-256
  `aec35f9c954a7d05755b43b2aa8474d81715aa7c71982d4209eb87fa40557729`);
- publication source
  `3b54b3f975298c08f00aacb6d1423f7d2897ecd4` pins that profile in the
  Godot/Jolt adapter manifest and re-passes the same-world physical shadow
  `20/20` with no profile application or actuation. The retained report is
  `<evidence-root>\godot-jolt-motor-profile-shadow-3b54b3f\report.json`
  (SHA-256
  `1aa0f5e20fea276373a8db0c6c22c137de506970057f375f6f70dd07c76d8a5b`);
  this establishes bounded transport only, not connected balance feedback; and
- one retained portable partial-support map at source
  `8d1c5364d945102387b1763f3d0c17a1db86c059`. Its report passes Rust
  `5/5`, independent GDScript `12/12`, native Godot `27/27`, and Python
  `10/10`, preserves full-support v2 equivalence, and emits six active plus
  two explicit exact-zero commands in the three-contact fixture. It is
  retained at
  `<evidence-root>\stability-v3-subset-map-8d1c536\report.json`
  (SHA-256
  `0de2d43dda1698a1e716aae8f0fd693c0211c25f5cc617c5f7d2135510bcc8a9`);
  it is pure mapping evidence, not connected balance feedback; and
- one bounded same-world native evidence-authority handoff plus one full
  post-settle native-authority Candidate 35 gait. In the full run, the SDK
  applied `20,648` commands across `2,581` frames, legacy applied zero
  post-settle commands, all limbs completed exactly `1,440` evidence steps,
  every physical walking gate passed, and all parity/safety counters were
  zero;
- a rejected formal C6 selection at `10/12` worlds and `382/396` assertions,
  retained without opening its held-outs;
- one prospectively constrained C6R morphology-guard repair whose selection
  passed `12/12`, `396/396`, then whose cold held-out R1 rejected at `6/8`,
  `254/264`; and
- a machine-readable claim boundary that explicitly records bounded
  Godot/Jolt stability influence while keeping balance recovery,
  friction/material robustness, cross-engine C6, and continuous physical proof
  false.

The native Godot binding establishes C0-C5 for its explicitly declared
supported capabilities, dynamic output parity, and native-controlled
Candidate 35 commissioning. Formal Godot/Jolt C6 remains false because both
allowed campaigns rejected under their frozen rules. Candidate 35 is now a
legacy conformance oracle; it will not receive another heldout-shaped repair.

The P5I.3B-R1 live contribution shadow is complete at `28/28` on clean source
`38ff4b3ee7ee548efaf2df7e76ba7e13d2ab9a86`; the first source remains
retained as a rejected `25/28` result. P5I.3C-R2 then passed its separately
authorized bounded physical-influence campaign at `24/24`.

The subsequent `23`-world cold Godot/Jolt material campaign completed on clean
source `ac52b5cb7af46a419c5f661025929a8577b37cd0` and rejected at `28/32`
aggregate gates: `11/12` primary treatments, `3/4` matched controls, `4/4`
paired causal gates, `6/6` lower-friction diagnostics, and `1/1`
zero-friction safety controls. Its retained report is
`<evidence-root>\godot-jolt-material-robustness-r1-ac52b5c\report.json`
(SHA-256
`7c58a73df1187076087e1c2f47536030b8a1e9536b157ea8d6b7818f9bf6a0ef`).
The exact-order portable map remains unchanged; the next controller must be a
non-Candidate-35 successor with separate development and cold partitions.

Rapier/Parry is the second C0-C5 host and MuJoCo is the third C0-C5 host; both
C6 capabilities remain false. A dependency, pure algorithm, or adapter
existing does not establish an undeclared capability. Friction/material
robustness, rough terrain, pushes, sensor noise/latency, physical full-volume
morphology coverage, multi-legged locomotion, running, production packaging,
and bipedal locomotion remain separate prospective gates.

BW5V is the frozen next Godot/Jolt boundary for the development-selected
BW5R-B policy. Its manifest is
[`balanced_wave_bw5v_preregistration.json`](balanced_wave_bw5v_preregistration.json)
and its source-bound runner is
[`run_balanced_wave_bw5v_material_characterization.ps1`](run_balanced_wave_bw5v_material_characterization.ps1).
The no-world entry gate is:

```powershell
.\sdk\run_balanced_wave_bw5v_material_characterization.ps1 -PreflightOnly
```

It passes `6/6` while opening zero worlds. The first retained physical result
must run only after this source is clean, committed, pushed, and equal to
`origin/main`. It will characterize `0.05`, `0.65`, and `1.30` for the later
`19501`-`19503` independent validation; it may not open or characterize the
reserved cold values `0.12`, `0.48`, `0.95`, and `1.50`.

The first eligible result passed `19/19` over `10/10` worlds from source
`2a5eb94dca81a8c638e31a0d7c9692c270b44ca6`. Its durable report is
`<evidence-root>\balanced-wave-bw5v-material-characterization-2a5eb94\report.json`
(SHA-256
`a99a7f2aa9798d26c7a4df9e9b218a5979195eb05dc97b02cd36a5dc21d45d84`).
It derives immutable profiles `godot_jolt_bw5v_mu005_v1`,
`godot_jolt_bw5v_mu065_v1`, and `godot_jolt_bw5v_mu130_v1` with conservative
controller coefficients `0.05`, `0.63`, and `1.00`. The expanded profile
conformance passes `32/32` over `21` profiles and opens zero worlds.

The source-`e76477b` profile publication is retained at
`<evidence-root>\balanced-wave-bw5v-material-profiles-e76477b\report.json`
(SHA-256
`2430c1a77d7007c13c3a5262e19fba7693154ba40ea61aa3d1cf601844a2a37c`).
The separate independent-locomotion contract is
[`balanced_wave_bw5v_validation_manifest.json`](balanced_wave_bw5v_validation_manifest.json),
and its wrapper is
[`run_balanced_wave_bw5v_validation.ps1`](run_balanced_wave_bw5v_validation.ps1):

```powershell
.\sdk\run_balanced_wave_bw5v_validation.ps1 -PreflightOnly
```

That check passes with the exact `12` cells, `22` gates, three seed receipts,
three profile receipts, and zero physics worlds. The full campaign must run
once from clean pushed source and retain `report.json` whether it passes or
rejects. A pass remains independent Godot/Jolt development validation only;
the unopened cold material partition, nuisance axes, fresh morphologies, and
Rapier/MuJoCo physical campaigns remain mandatory before C6.

The first eligible complete BW5V run passed from source
`7d8b046f752974b8d9498db91b0d46ae99ac1729`. Its durable report is
`<evidence-root>\balanced-wave-bw5v-validation-7d8b046\report.json`
(SHA-256
`a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee`).
It records `22/22` gates, `12/12` worlds, `9/9` treatments, `3/3` controls,
`3/3` causal pairs, and zero integrity failures. This is exact-cohort
independent validation, not cold material acceptance. All broader claims in
the report remain false, and the reserved cold partition is the next material
gate.

BW5C is that source-frozen cold partition. Its manifest is
[`balanced_wave_bw5c_preregistration.json`](balanced_wave_bw5c_preregistration.json),
and its characterization wrapper is
[`run_balanced_wave_bw5c_material_characterization.ps1`](run_balanced_wave_bw5c_material_characterization.ps1):

```powershell
.\sdk\run_balanced_wave_bw5c_material_characterization.ps1 -PreflightOnly
```

The preflight binds the accepted BW5V report
`<evidence-root>\balanced-wave-bw5v-validation-7d8b046\report.json`
(SHA-256
`a22858ef96e0affb6cf68fe2f63f75885158a602a41f93fa10c20439d672ebee`),
the prior reservation hashes, BW5R-B, friction values
`{0.12, 0.48, 0.95, 1.50}`, and seeds `{20001, 20002, 20003}`. It must pass
`6/6` while building and inserting zero worlds.

The full characterization is exactly `13` worlds and `23` gates. It may only
publish immutable Godot/Jolt material profiles. A later source-frozen
locomotion manifest must then execute `17` worlds and `28` gates:
`12` treatments, `4` matched controls, and `1` zero-friction zero-write
control. Until that separate result passes, cold/material robustness and all
broader physical, cross-engine, and completed-SDK claims remain false.

The first complete BW5C characterization passed `23/23` gates and `13/13`
worlds from physics source `dca2618bd1cb42768235bc69711eb3dab6b2379a`.
Its durable report is
`<evidence-root>\balanced-wave-bw5c-material-characterization-dca2618\report.json`
(SHA-256
`067b033266166b15eb0e9f98a5962fdfe7bc199a0af335a64bbb44cc18a09143`).

Godot completed the one physics run after the outer command host returned.
[`finalize_balanced_wave_bw5c_completed_run.ps1`](finalize_balanced_wave_bw5c_completed_run.ps1)
then fail-closed on the single complete engine-log receipt and packaged it
without rerunning physics. The report retains the partial command-host
transcript separately and binds packaging source `2dc17b5`.

The four immutable profiles publish coefficients `0.10`, `0.45`, `0.94`,
and `1.00` under IDs `godot_jolt_bw5c_mu012_v1`,
`godot_jolt_bw5c_mu048_v1`, `godot_jolt_bw5c_mu095_v1`, and
`godot_jolt_bw5c_mu150_v1`. The expanded profile gate passes `36/36` over
`25` profiles and still opens zero physics worlds.

The retained source-`677e97e` profile publication is:

```text
<evidence-root>\balanced-wave-bw5c-material-profiles-677e97e\report.json
sha256:381132c430140ec4b70a1cff65d7099974bf1b6eefa59bafa523c1b287076c97
```

The now-materialized cold locomotion contract is
[`balanced_wave_bw5c_validation_manifest.json`](balanced_wave_bw5c_validation_manifest.json).
Its source-bound runner is
[`run_balanced_wave_bw5c_validation.ps1`](run_balanced_wave_bw5c_validation.ps1):

```powershell
.\sdk\run_balanced_wave_bw5c_validation.ps1 -PreflightOnly
```

That check passes while opening zero worlds. It binds BW5R-B, all three
prerequisite report hashes, the four profile digests, seeds
`{20001, 20002, 20003}`, the exact ordered `17`-cell matrix, and the frozen
`28`-gate all-or-nothing result contract. The check is only a source freeze;
walking and bounded discrete material robustness remain false until the first
complete run from clean pushed source is retained.

The first complete cold result passed from clean pushed source
`dac405df52abfda12f5633022e6814b02f561a3e`:

```text
<evidence-root>\balanced-wave-bw5c-validation-dac405d\report.json
sha256:6648c1473c97d2b7229ba0decd8881ca2d8f06e68ca9737d7255120dab2653da
```

It records `28/28` gates, `17/17` worlds, `12/12` treatments, `4/4`
material-matched controls, `4/4` causal pairs, the `1/1` zero-friction
zero-write safety control, and zero integrity failures. This authorizes
walking and bounded discrete material robustness only for BW5R-B on the
pinned Godot/Jolt fixture, solver settings, friction values
`{0.12, 0.48, 0.95, 1.50}`, and seeds `{20001, 20002, 20003}`. Continuous or
arbitrary material coverage, physical recovery, nuisance robustness,
fresh-morphology coverage, cross-engine C6, and completed-SDK authority
remain false.

BW6N is the next prospectively frozen Godot/Jolt nuisance ladder. Its
machine-readable contract is
[`balanced_wave_bw6n_validation_manifest.json`](balanced_wave_bw6n_validation_manifest.json);
its source-bound runner is
[`run_balanced_wave_bw6n_validation.ps1`](run_balanced_wave_bw6n_validation.ps1):

```powershell
.\sdk\run_balanced_wave_bw6n_validation.ps1 -PreflightOnly
```

The zero-world preflight passes. It binds the unchanged BW5R-B policy,
reference morphology, characterized `godot_jolt_bw5c_mu095_v1` material,
solver/clock, fresh seeds `{21001, 21002, 21003}`, and an ordered `12`-world,
`24`-gate matrix. Three active-policy baselines are matched to three rough
height-strip worlds, three one-impulse lateral-push worlds, and three
deterministic observation-noise worlds. Noise is applied to the portable
base/joint state and to stability body/support observations at the adapter
boundary; it does not modify physics state. The external impulse is separately
receipted and is not counted as a controller body write.

The four frozen challenge-configuration digests are:

```text
bw6n_baseline_v1     sha256:0b3f9e0fafd1f00c69a72a216975446897492e4e6e96f9e0405958f99621bb1b
bw6n_rough_v1        sha256:da97bf60b8ed83c80b9ab3c00c188b8d8b874b3c1ca9b180a4940873cef8ec7e
bw6n_push_v1         sha256:0f8bb1a1c522c3d36ea277b4ce778bc6e71f45172f1d3b37e2a7e23021dfa02a
bw6n_sensor_noise_v1 sha256:1f1f7ad6837c16dd7a0415f6fa90c501300968f1c6ffad8775080dd2f399dbbb
```

Preflight opens no world and grants no recovery claim. The first complete run
must come from clean pushed source and retain `report.json` plus all three
transcripts. Until that result passes, rough-terrain robustness, external-push
recovery, sensor-noise robustness, and physical balance recovery remain false.
Arbitrary/continuous terrain, arbitrary pushes or faults, sensor latency,
combined-nuisance behavior, fresh morphology, cross-engine C6, and
completed-SDK authority remain outside BW6N regardless of its result.

The first and only physical result for source
`e44a7e2fabf7547aaba778a94c0f3eaa64b1920e` is retained at:

```text
<evidence-root>\balanced-wave-bw6n-validation-e44a7e2\report.json
sha256:8fe82a73b4bd8bae9789932fda47af2104b6204a4594a62c44998019ca949442
```

BW6N was rejected at `16/24` gates after all `12/12` worlds completed.
Ordinary-walking counts were baseline `2/3`, rough `1/3`, push `2/3`, and
sensor noise `2/3`. Baseline, push, and sensor-noise `s21003` all missed only
`evidence_four_contact_stance`, so those three failures share one baseline
boundary miss rather than authorizing either nuisance claim.
The rough axis added independent failures: `s21001` exceeded bounded lateral
drift and did not complete two contact cycles per limb; `s21002` timed out
contact gating; only rough `s21003` passed.

The infrastructure itself was complete: all three rough worlds realized `64`
terrain shapes, all three push worlds applied and measured exactly one
non-controller impulse, all three sensor worlds faulted both observation paths
for `1,514/1,514` steps, and all `12/12` worlds applied nonzero bounded
stability influence. Those are execution facts, not robustness acceptance.
Godot/Jolt rough-terrain, external-push, sensor-noise, and physical-recovery
claims therefore remain false. BW6N is final and must not be rerun or repaired
under the same source identity.

The source-bound, explicitly non-acceptance causal replay is
[`run_balanced_wave_bw6n_opened_diagnostic.ps1`](run_balanced_wave_bw6n_opened_diagnostic.ps1).
Its complete report is:

```text
<evidence-root>\balanced-wave-bw6n-opened-diagnostic-6189535\report.json
sha256:fc370752d51ae1b1571cf9179fc483132b008ee859fc814494dbafbf0529569c
```

It reproduced the six opened baseline/rough cells twice with exact diagnostic
receipts. Baseline `s21003` had only `front_right` non-bearing at nominal
evidence start and recovered it two ticks later; it had zero timeouts,
completed `4/4/5/3` accepted cycles, and ended all-four-bearing. That is an
evidence-start acquisition defect, not a controller-balance failure. A new
protocol must prospectively bound and receipt acquisition without fitting the
bound to those two observed ticks.

Rough `s21002` separately timed out `await_release` on both front limbs while
they remained bearing. Rough `s21001` had no timeout, but three rear-right
recontacts failed the unchanged `0.015 m` relocation gate and the world
reached `0.100246 m` lateral displacement with `384` steering-saturation
steps. Those remain real controller/terrain failures. The next development
family may not relax timeouts or walking thresholds and must remain
branch-free and morphology-normalized. This replay grants no walking,
terrain, recovery, C6, or completed-SDK authority.

The first BW3 selected-policy validation is retained as a `21/22` rejection,
not rerun. The prospective replacement family is
`balanced_wave_bw2r_preregistration.json`: three branch-free policies inherit
BW2-C and vary only the global yaw-error stride gain (`1.1`, `1.2`, `1.3`).
Every opened candidate must repeat the `29`-world BW2 ladder plus the complete
`12`-world opened BW3 cohort. That replay is development data. A selected
candidate still requires newly characterized material values, new seeds, and
a separately frozen validation before BW4 or cross-engine C6 can open.

## Current branch-free successor: BW8U

BW7D is closed and rejected under the retained negative closure described
above. The next source-frozen identity is
[`balanced_wave_bw8u_preregistration.json`](balanced_wave_bw8u_preregistration.json).
BW8U inherits BW7D-D's reciprocal stride, full release allowance,
cycle-normalized filter, material binding, stability overlay, and empty
morphology branch surface. Its `2 x 2` factors independently hold the existing
analytic knee and hip swing-apex targets only while the existing phase-54
release gate remains loaded.

This is not another Candidate 35 branch or threshold fit. It introduces zero
new free numeric constants and emits a typed
`sporespore_release_gate_unweighting_receipt_v1` on every step. The Godot/Jolt
adapter validates and aggregates those receipts, including factor activation
counts. The zero-world native authority contract passes `17/17`, and all four
candidate preflights pass without creating a physics body.

Frozen identities:

- canonical preregistration:
  `sha256:51b3af71af5ad933eaaee9767383f38d8b1cdfe00a9845754b7e36370fbc3793`;
- raw preregistration:
  `f6cdfca3c8956deb4a48ac22d8d8507a373923aa60e3d59f51d40f72554f61a5`;
- development test:
  [`../tests/test_sdk_balanced_wave_bw8u_development.gd`](../tests/test_sdk_balanced_wave_bw8u_development.gd);
- source-bound runner:
  [`run_balanced_wave_bw8u_development.ps1`](run_balanced_wave_bw8u_development.ps1);
  and
- fail-closed compiler:
  [`compile_balanced_wave_bw8u_selection.ps1`](compile_balanced_wave_bw8u_selection.ps1).

The matrix is `12` worlds per candidate: opened baseline/rough seeds
`21001`-`21003` plus fresh development seeds `24001`-`24003`. The complete
family is `48` worlds, with early stopping forbidden. Seeds `22501`-`22503`
remain sealed for independent validation; friction
`{0.09, 0.37, 0.76, 1.18}` and seeds `23001`-`23003` remain sealed for the
later cold unbiased axis.

The preregistration directly retains the research-source ledger and the local
PDF paths/hashes for `DReCon.pdf`, `2604.08780v1.pdf`, and
`2507.22653v2.pdf`; see
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

BW8U subsequently completed all `48/48` development worlds from pushed source
`a8f3887cb164a7b6b4b65682a021a48f025b5a1c`. No candidate was eligible and
no selection occurred. A and B each retained `3/12` non-walks, `11` release
timeouts, and one typed integrity failure after fresh rough seed `24003`
fell; their new mechanism receipts had zero failures. C and D were complete
but each regressed to `11/12` non-walks and `35` release timeouts. The
authoritative family report is
`<evidence-root>\balanced-wave-bw8u-family-closure-a8f3887\report.json`
with SHA-256
`fb89fe9cc4467b8484d4bee4cc5fe4cd5e21efc77ad748c1594dc11a0bd9a040`.
Exact candidate paths and hashes are retained in
[`balanced_wave_bw8u_closure_manifest.json`](balanced_wave_bw8u_closure_manifest.json).

BW8U is closed and rejected. Its independent seeds and cold-friction
reservation remain unopened and may not be used to promote or repair BW8U.
Walking, material, terrain, recovery, fresh-morphology, Rapier/MuJoCo physical
C6, and completed-SDK claims remain false.

## Frozen BW9L portable load-transfer family

BW9L replaces BW8U's ineffective or harmful loaded-joint target interventions
with a portable stability-layer hypothesis. It keeps
`sporespore_balanced_wave_bw5r_b_v1` fixed and independently toggles:

1. a preferred zero normal force at the one scheduler-selected swing contact
   that remains bearing, with equal weight preference over the remaining
   qualified contacts; and
2. replacement of only the lateral all-support-centroid target by the
   remaining-support centroid.

The machine-readable freeze is
[`balanced_wave_bw9l_preregistration.json`](balanced_wave_bw9l_preregistration.json).
Its canonical digest is
`sha256:b0b708bc6bcfd5475606b4014295f204a9b9d64846eb60d362b355184a5e2767`;
its raw-file SHA-256 is
`da66fd10e7596b69858631eda41cdba7661b638610dbd788c7bd3269452bf85b`.
All four candidate branch surfaces are empty, no new fitted numeric constant
was introduced, and friction/material/morphology/seed/outcome conditions are
forbidden.

The portable Rust operation is `ss_plan_scheduled_load_transfer_v1_json`.
It is available through the C ABI, Python binding, Godot GDExtension, and
Godot/Jolt authority adapter. The native no-world authority test passes `5/5`;
all four physical-matrix preflights also pass without opening a world.

After committing and pushing the frozen source, run each arm exactly once:

```powershell
.\sdk\run_balanced_wave_bw9l_development.ps1 `
  -Candidate BW9L-A `
  -Output '<evidence-root>\balanced-wave-bw9l-a-development-<source>\report.json'
```

Repeat for B, C, and D. Each arm contains `12` baseline/rough worlds and every
arm must finish; early stopping is forbidden. The runner binds every retained
report to the source commit and hashes the preregistration, test, adapters,
portable stability source, research ledger, and all three local PDFs:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf), and
[`../2507.22653v2.pdf`](../2507.22653v2.pdf).

After all four reports exist, the already-frozen selector is:

```powershell
.\sdk\compile_balanced_wave_bw9l_selection.ps1 `
  -Report <A-report>,<B-report>,<C-report>,<D-report> `
  -Output '<evidence-root>\balanced-wave-bw9l-selection-<source>\report.json'
```

Seeds `22501`-`22503` and cold friction
`{0.09, 0.37, 0.76, 1.18}` / seeds `23001`-`23003` remain unopened. Until the
full family, selection, independent validation, and later reserved campaigns
complete, BW9L grants development evidence only.

BW9L subsequently executed all `48/48` worlds from pushed source
`f4d25081132d5e6cdecf2ca0c4a55e657a9e92d4`, but every candidate was
integrity-incomplete at `8/22`. The planner emitted only
`68,792/72,672` expected receipts because partial or rank-deficient support
could turn centroidal planning into an FFI error rather than a typed fail-zero
receipt. The frozen selector refused the incomplete A report and performed no
selection.

The exact A/B/C/D report SHA-256 values are:

```text
BW9L-A ab34879af86f27a23fabd772eeb5f9fcf2e0bfea953171ecfc4f29ac97f2cbe0
BW9L-B 43bcfe82e998d8bf5d44a2af8da506344068fd9c6865c304b09b56d8a9b30c22
BW9L-C 3100a6598a7d7ad7028d3d259d0c5aeca4fac64883347455362e553ee6989bd9
BW9L-D ec0dd411142af9fe8a0f3a9998a37b7f32c42c900fd9b9b934a7f3b30e770dd7
```

Raw physical walking was observed in A `7/12`, B `7/12`, C `10/12`, and D
`5/12`; release timeouts were respectively `15`, `32`, `8`, and `22`.
These are unranked development observations because every world failed the
execution-integrity gate. The hard-bound
[`compile_balanced_wave_bw9l_negative_closure.ps1`](compile_balanced_wave_bw9l_negative_closure.ps1)
can only retain a negative family closure for those exact bytes. BW9L is
closed; it grants no walking or robustness claim and may not be repaired or
rerun.

Authoritative closure:

```text
<evidence-root>\balanced-wave-bw9l-family-closure-f4d2508\report.json
sha256:4d0faa6c5d755b1ff3e32937a38d09a9f6197c52cfe9f90636e5c1933f6d40f1
```

The durable source-controlled evidence index is
[`balanced_wave_bw9l_closure_manifest.json`](balanced_wave_bw9l_closure_manifest.json).

## BW10F v2 typed fail-zero endpoint

Pushed implementation source
`b59f00018a55df5f7e5468a53c2cbda354ce9d0a` adds
`ss_plan_scheduled_load_transfer_v2_json` without changing BW9L v1. The public
request/receipt identities are:

```text
sporespore_plan_scheduled_load_transfer_request_v2
sporespore_scheduled_load_transfer_request_v2
sporespore_scheduled_load_transfer_receipt_v2
```

Policy IDs:

```text
sporespore_scheduled_load_transfer_bw10f_a_v2
sporespore_scheduled_load_transfer_bw10f_b_v2
sporespore_scheduled_load_transfer_bw10f_c_v2
sporespore_scheduled_load_transfer_bw10f_d_v2
```

The core returns `planning_availability=available` with a centroidal pair, or
a typed `observation_unavailable` / `upstream_infeasible` receipt with
`fail_zero_required=true` and every compiled actuator ID in exact semantic
order. This is a control receipt, not measured load, balance recovery,
walking, or physical-acceptance evidence.

Implementation paths:

- [`core/src/stability.rs`](core/src/stability.rs);
- [`core/src/ffi.rs`](core/src/ffi.rs);
- [`include/sporespore_locomotion.h`](include/sporespore_locomotion.h);
- [`python/sporespore_locomotion.py`](python/sporespore_locomotion.py);
- [`adapters/godot/src/lib.rs`](adapters/godot/src/lib.rs);
- [`../scripts/lab/gait/sdk_godot_jolt_adapter.gd`](../scripts/lab/gait/sdk_godot_jolt_adapter.gd);
  and
- [`../tests/test_sdk_balanced_wave_bw10f_authority_contract.gd`](../tests/test_sdk_balanced_wave_bw10f_authority_contract.gd).

Verified at the implementation commit: Rust workspace plus warnings-as-errors
Clippy and offline release build, Python `12/12`, Godot C0/C1 `41/41`, frozen
BW9L `5/5`, and implementation-only BW10F no-world `6/6`. No BW10F physics
world was opened.

The supporting research files remain
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf), and
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), interpreted in
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).
The physical-development freeze is now source controlled in
[`balanced_wave_bw10f_preregistration.json`](balanced_wave_bw10f_preregistration.json),
with raw SHA-256
`ea3f2c8521e630928ea7e9864277959e3c3ce577496821e0b0880200802cc59f`
and canonical JSON identity
`sha256:eb460a1b373a5aef4a9f07724d5e08e573fc18f3898cd94401c80047ebfa5148`.
It owns four branch-free A/B/C/D policies, baseline and rough worlds at fresh
seeds `25001`-`25006`, and a complete `48`-world family.

[`run_balanced_wave_bw10f_development.ps1`](run_balanced_wave_bw10f_development.ps1)
enforces clean pushed source and retains one complete `12`-world candidate
report. [`compile_balanced_wave_bw10f_selection.ps1`](compile_balanced_wave_bw10f_selection.ps1)
requires all four reports and selects a treatment only if its frozen
lexicographic vector is strictly better than control. All four zero-world
runner preflights passed the preregistration-bound `7/7` authority contract
and returned `observed_world_count=0`; no BW10F physics world had opened at
freeze time. The next operation is to commit/push these exact bytes and
execute the family once.

BW10F subsequently executed all `48/48` worlds from pushed source
`80388bf995addd657cf29b1c801de66211464259` and is closed as an
integrity-invalid family. The inherited common-execution gate hardcoded the
old `p5i3c_support_centroid_tilt_feedback_v1` policy ID, so all four new v2
identities were structurally rejected. Three rough cells also lost `138`
planner receipts after downstream
`STABILITY_OVERLAY_CONTRIBUTION_INVALID:` failures. D retained all `18,168`
receipts, but its raw `9/12` walking observations and `3` timeouts cannot be
ranked or selected under the failed family contract.

Authoritative negative closure:

```text
<evidence-root>\balanced-wave-bw10f-family-closure-80388bf\report.json
sha256:eba83f6deed0ae27814342489c579ca2e46f8b8d8b4cc3d926af51960bc59ec1
```

The durable source index is
[`balanced_wave_bw10f_closure_manifest.json`](balanced_wave_bw10f_closure_manifest.json).
BW10F may not be repaired or rerun. A new successor must use candidate-relative
policy identity and retain one planner receipt before every downstream
overlay decision.

## BW11R v3 observation-availability endpoint

The additive v3 endpoint is:

```text
ss_plan_scheduled_load_transfer_v3_json
```

Its public identities are:

```text
sporespore_plan_scheduled_load_transfer_request_v3
sporespore_scheduled_load_transfer_request_v3
sporespore_scheduled_load_transfer_receipt_v3
```

Policy IDs:

```text
sporespore_scheduled_load_transfer_bw11r_a_v3
sporespore_scheduled_load_transfer_bw11r_b_v3
sporespore_scheduled_load_transfer_bw11r_c_v3
sporespore_scheduled_load_transfer_bw11r_d_v3
```

The request explicitly distinguishes an available same-step stability state
from a host observation that is unavailable. Available input requires a state
and forbids an unavailable reason. Unavailable input requires a nonempty
reason and may omit the unusable state. Both paths retain scheduler order and
semantic identity. The unavailable path returns a successful typed fail-zero
receipt naming every actuator; the adapter does not fabricate it.

Godot/Jolt uses manifest v15 only for these v3 policies. v1 and v2 policies
retain their historical manifest identities. The no-world contracts are:

- [`../tests/test_sdk_scheduled_load_transfer_v3_authority_contract.gd`](../tests/test_sdk_scheduled_load_transfer_v3_authority_contract.gd);
  and
- [`../tests/test_sdk_full_integrity_gate_satisfiability.gd`](../tests/test_sdk_full_integrity_gate_satisfiability.gd).

The second test invokes the exact post-physics analysis and integrity path for
all four declared policies with a synthetic perfect result and one typed
unavailable step.

The fresh successor is frozen in
[`balanced_wave_bw11r_preregistration.json`](balanced_wave_bw11r_preregistration.json):

```text
raw:       b52ac012e67668b050342746fc2415f0c81eff19f027deb6b1d09e476023ec5d
canonical: sha256:f272738224284c2c978b555547cfca83da55fe212fdc1231ae3266cce6dcebbd
parent:    abb2df1e24df9e62eb56bd2eefcb0f076ac7f5ed
```

It uses fresh seeds `26001`-`26006` in baseline and rough cohorts, producing
`12` worlds per arm. Before the runner may create that physical process, it
requires the portable v3 contract, all-policy exact full-gate test, and the
selected candidate's own exact-gate preflight to pass in three separate
zero-world processes:

```powershell
.\sdk\run_balanced_wave_bw11r_development.ps1 `
  -Candidate BW11R-A `
  -PreflightOnly
```

All four A/B/C/D preflights pass with `observed_world_count=0`. The campaign
also repeats its candidate preflight internally before entering the world
loop. A requires exact-zero stability activity; B/C/D require nonzero bounded
activity. The source-bound full runner retains all preflight receipts and
transcripts with each durable report. After four complete same-commit reports
exist, the frozen selector is:

```powershell
.\sdk\compile_balanced_wave_bw11r_selection.ps1 `
  -Report <A-report>,<B-report>,<C-report>,<D-report> `
  -Output <selection-directory>\report.json
```

At the freeze boundary these tests granted development-selection authority
only; no BW11R physical result existed. The later launch attempt opened zero
worlds and is now permanently closed under the manifests below. Neither the
freeze nor the zero-world closure grants a physical walking, balance,
material, morphology, nuisance, cross-engine, or completed-SDK claim.

## Policy-semantic full-gate preflight v3

BW11R and BW12E are now closed negative families, indexed by
[`balanced_wave_bw11r_closure_manifest.json`](balanced_wave_bw11r_closure_manifest.json)
and
[`balanced_wave_bw12e_closure_manifest.json`](balanced_wave_bw12e_closure_manifest.json).
BW11R opened no worlds because the physical entrypoint omitted its v3 policy
identities. BW12E corrected that entrypoint and executed all `48/48` worlds,
but its control declaration was semantically wrong: disabling both
experimental scheduled-load-transfer factors did not disable the shared
baseline centroidal correction.

The mandatory successor contract in
[`../tests/test_sdk_full_integrity_gate_satisfiability.gd`](../tests/test_sdk_full_integrity_gate_satisfiability.gd)
now executes the real portable planner, endpoint-force mapper, and
bounded-influence path before constructing its synthetic full result. That
result then traverses the exact production integrity analyzer. Available and
typed-unavailable samples are both required; mechanism counters come from
real receipts rather than from hand-authored expected values.

The current `6/6` zero-world result proves all four v3 policies can satisfy
their corrected declarations. All four retain nonzero shared baseline
influence. Factor activity remains off for A and on for B/C/D. The included
BW12E regression proves the obsolete A exact-zero-overlay declaration fails
with `DECLARED_POLICY_MECHANISM_UNSATISFIABLE`. Missing semantic witnesses fail
with `POLICY_SEMANTIC_WITNESS_REQUIRED`.

This is a launch-integrity result only: zero worlds, zero SceneTree
insertions, no physics-state mutation, no locomotion result, and no physical
acceptance authority. Receipt v3 additionally exercises the selected
`BW5R-B` full-authority adapter start, and the R05B runner proves that its
complete 36-cell perfect synthetic aggregate report and every retained source
file can be resolved and round-tripped. A future successor wrapper must
validate those applicable receipt-v3 policy, entrypoint, exact-gate, complete
report, and source-identity checks before it starts a physical Godot process
or creates a durable output directory. Full evidence and research-source paths
are retained in
[`../docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md`](../docs/SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md).
The clean pushed-source transcript checkpoint is indexed by
[`policy_semantic_preflight_checkpoint_manifest.json`](policy_semantic_preflight_checkpoint_manifest.json).

## QSDK-R05 independent morphology

The standalone quadruped release contract requires fresh physical morphology
evidence for the selected policy; GQ15 cannot satisfy that requirement because
it is finite Candidate 35 evidence. QSDK-R05 therefore freezes twelve
previously unopened six-axis low-discrepancy shapes (`169`-`180`) and three
fresh perturbation seeds (`21501`-`21503`) under
`sporespore_balanced_wave_bw5r_b_v1`.

The frozen contract is
[`qsdk_r05_independent_morphology_preregistration.json`](qsdk_r05_independent_morphology_preregistration.json).
The one-world harness is
[`../tests/test_sdk_qsdk_r05_independent_morphology.gd`](../tests/test_sdk_qsdk_r05_independent_morphology.gd),
and the runner is
[`run_qsdk_r05_independent_morphology.ps1`](run_qsdk_r05_independent_morphology.ps1).
The runner refuses dirty or unpushed source for physics, never overwrites an
evidence directory, and retains the first complete `36`-world result whether
it passes or fails.

Most importantly, the runner creates no durable campaign directory and opens
no world until the complete synthetic production gate, all `36`
CLI-equivalent real-entrypoint preflights, and a perfect synthetic
runner/result hash-and-JSON round trip pass:

```powershell
.\sdk\run_qsdk_r05_independent_morphology.ps1 -PreflightOnly
```

The first complete result ran `36/36` worlds but was rejected at `0/36`
integrity and walking conjunctions: the adapter's start contract forbade
`BW5R-B` full authority, so every cell retained Candidate 35 legacy authority
instead of the selected SDK policy. The immutable report and interpretation
are indexed by
[`qsdk_r05_independent_morphology_validation_manifest.json`](qsdk_r05_independent_morphology_validation_manifest.json).
QSDK-R05A must close the real adapter-start capability, and QSDK-R05B must use
a new independent population. R06 arbitrary-valid-quadruped coverage and R07
continuous full-volume physical coverage remain explicitly false.

QSDK-R05A is frozen in
[`qsdk_r05a_selected_policy_authority_preregistration.json`](qsdk_r05a_selected_policy_authority_preregistration.json).
It permits only the selected `BW5R-B` policy to enter `post_settle_full`,
upgrades the complete integrity preflight to a real zero-world adapter-start
receipt, and requires every R05 entrypoint preflight to perform that start.
Its single physical cell is an explicitly outcome-exposed technical replay:

```powershell
.\sdk\run_qsdk_r05a_selected_policy_authority.ps1 `
  -Output "<evidence-root>\qsdk-r05a-<source>\report.json"
```

A pass establishes native selected-policy execution and motor ownership on
that one development cell only. It does not repair QSDK-R05 or authorize any
independent-morphology, arbitrary-quadruped, continuous-volume, cross-engine,
release, or completed-SDK claim.

QSDK-R05A passed its single authorized physical cell from clean pushed commit
`db1e397b96a259809abbfdd7ff29dc21b11ba588`. Its immutable report is
`<evidence-root>\qsdk-r05a-db1e397\report.json`
with
`sha256:ee9bf244830dc3826eaa99efcd9ffe08742dd7b93631009a4bcc4e02c80bdef0`;
the checked-in interpretation is
[`qsdk_r05a_selected_policy_authority_validation_manifest.json`](qsdk_r05a_selected_policy_authority_validation_manifest.json).

Before constructing that world, the runner passed receipt-v3 full integrity,
all `36/36` real full-authority R05 entrypoint starts, and both report
serialization layers. The physical cell then recorded `2826` SDK steps,
`22608` validated commands, `22608` native motor writes, zero legacy motor
writes, zero SDK mismatches or safe-disable events, and every frozen walking
gate true. Because the cell deliberately reused outcome-exposed
`qsdk_r05_generated_s169` with seed `21501`, this is technical capability
evidence only. Fresh QSDK-R05B remains required.

QSDK-R05B is now prospectively frozen in
[`qsdk_r05b_independent_morphology_preregistration.json`](qsdk_r05b_independent_morphology_preregistration.json).
It uses unopened sequential generator indices `181`-`192`, fresh structured
seeds `21601`-`21603`, the unchanged `BW5R-B` policy, the same characterized
material, and the same production walking gates. Its campaign specialization
is
[`../tests/test_sdk_qsdk_r05b_independent_morphology.gd`](../tests/test_sdk_qsdk_r05b_independent_morphology.gd);
the retained launcher is
[`run_qsdk_r05b_independent_morphology.ps1`](run_qsdk_r05b_independent_morphology.ps1).

The preflight runs the complete receipt-v3 synthetic integrity gate, all 36
real full-authority entrypoint starts, and the PowerShell report round trip
before any world or durable output directory:

```powershell
.\sdk\run_qsdk_r05b_independent_morphology.ps1 -PreflightOnly
```

After the exact source is clean, committed, and pushed:

```powershell
.\sdk\run_qsdk_r05b_independent_morphology.ps1 `
  -Output "<evidence-root>\qsdk-r05b-<source>\report.json"
```

The first complete `36`-world result is final for that source identity. A pass
would close finite fresh same-selected-policy morphology evidence, not
arbitrary-valid-quadruped, continuous-volume, robustness, cross-engine,
release, or completed-SDK claims.

QSDK-R05B completed from clean pushed commit
`51d1b70d14ce3861cebbb1c238c5888b1bfc33ba` and is rejected. Its immutable
report is
`<evidence-root>\qsdk-r05b-51d1b70\report.json`
with
`sha256:d5880f2ff78396d8d1ee4ab8851b454dd908ba85a3d9dfae3ac8ca6893054b3a`;
the complete interpretation is
[`qsdk_r05b_independent_morphology_validation_manifest.json`](qsdk_r05b_independent_morphology_validation_manifest.json).

All `36/36` receipts were complete and integrity-green, with exact selected
`BW5R-B` identity, full native authority, native command/write arithmetic, and
zero legacy writes or SDK safety failures. Only `33/36` passed every walking
gate: `s182/21602` missed the two-cycle requirement on `rear_right`,
`s190/21601` exceeded bounded lateral drift, and `s191/21601` missed the
every-limb relocation gate. R05B is final and may not be rerun or relaxed.
BW11R and BW12E were already closed before this result and cannot be reopened.
The next physical experiment requires a new prospectively frozen, branch-free
mechanism identity that does not condition on these three failures. Any later
independent morphology successor must use a new campaign identity, unopened
morphologies, and fresh seeds.

## BW13P development-only portable mechanism

`BW13P` is the current unselected successor implementation. Its four portable
v3 identities form a branch-free progressive load-transfer factorial:

- A: equal commanded-weight preferences, with both experimental factors off;
- B: progressive, mass-conserving scheduled-contact normal redistribution;
- C: progressive lateral target interpolation toward remaining support; and
- D: both progressive factors.

The smoothstep progress value is derived only from the declared scheduler
phase and swing bounds. Total preferred normal force remains commanded weight.
There is no morphology, seed, material, R05B failure, or outcome-conditioned
branch. The portable implementation and public ABI live in
[`core/src/stability.rs`](core/src/stability.rs),
[`core/src/lib.rs`](core/src/lib.rs), and [`core/src/ffi.rs`](core/src/ffi.rs);
Godot/Jolt routing lives in
[`../scripts/lab/gait/sdk_godot_jolt_adapter.gd`](../scripts/lab/gait/sdk_godot_jolt_adapter.gd).

Both v3 families are now covered by the public no-world authority contract and
the complete synthetic production gate. Each declared policy must produce its
own available and typed-unavailable receipts, traverse the real physical
entrypoint, portable planner, endpoint-force mapping, bounded influence, and
exact production analyzer, and accept a perfect all-zero error/mismatch/
failure/violation campaign before any world or durable evidence directory may
open. The R05B preflight also round-trips the complete 36-cell aggregate report
and source-file hashes.

BW13P has no physical, selection, walking, R05, or release authority yet. Its
development preregistration is frozen at
[`balanced_wave_bw13p_morphology_development_preregistration.json`](balanced_wave_bw13p_morphology_development_preregistration.json),
raw SHA-256
`3d3433f6e9fa05790bb493eb3190fd174a543311bf143972b7ae0ed18b3207b7`.
The development cohort may use outcome-exposed R05B data only for paired
hypothesis selection; reserved R05C indices `193`-`204` and seeds
`38101`-`38103` remain unopened for independent validation. Research inputs
remain pinned in
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md)
and the repository-root PDFs `DReCon.pdf`, `2604.08780v1.pdf`, and
`2507.22653v2.pdf`.

The frozen campaign runner is
[`run_balanced_wave_bw13p_morphology_development.ps1`](run_balanced_wave_bw13p_morphology_development.ps1),
its Godot harness is
[`../tests/test_sdk_balanced_wave_bw13p_morphology_development.gd`](../tests/test_sdk_balanced_wave_bw13p_morphology_development.gd),
and its four-report selector is
[`compile_balanced_wave_bw13p_selection.ps1`](compile_balanced_wave_bw13p_selection.ps1).
All four candidate-specific preflights pass without a world. Each invokes the
complete declared-policy integrity gate on perfect synthetic input, proves the
real full-authority adapter combines the portable base and stability
contribution into eight motor writes, validates all `36` real entrypoints, and
round-trips a complete `36`-cell aggregate report with every retained source
resolved and hashed. Only clean pushed source may enter the physical loop.

## Current BW13P closure and pre-world contract

The paragraph above describes the earlier frozen development launch state.
BW13P-R1 subsequently ran all `144` worlds from source
`06a4ea6efecb91abbcbf73457375b51a1512f59b`, but all four candidates are
invalid because a shared execution-mode route sent signed initial gait memory
into a public `u64` boundary and retained legacy overlay writes. Each candidate
recorded `0/36` integrity, `36/36` mechanism observation, `0/36` combined
application, and `0/36` walking. No selection is legal.

The authoritative closure, exact durable report paths and hashes, interrupted
attempt inventory, source identity, research-PDF hashes, and false claim
fields are in
[`balanced_wave_bw13p_r1_closure_manifest.json`](balanced_wave_bw13p_r1_closure_manifest.json).
[`../tests/test_bw13p_r1_closure.ps1`](../tests/test_bw13p_r1_closure.ps1)
reconciles all `144` retained result signatures. R1 is historical evidence and
must not be rerun, repaired, or used as an active conformance launch target.

Every successor physical runner must execute
[`../tests/test_sdk_full_integrity_gate_satisfiability.gd`](../tests/test_sdk_full_integrity_gate_satisfiability.gd)
and strictly reconcile
`sporespore_full_integrity_gate_satisfiability_receipt_v5` before it creates a
durable evidence directory or opens a world. Receipt v5:

- calls the same production execution-mode resolver used by the physical
  harness;
- crosses the real runtime boundary for all four BW13P policies at both signed
  offsets;
- advances the worst signed route through the complete `3,232`-step schedule
  with `3,232` native controller calls, `3,232` portable plans, and `25,856`
  ordered commands;
- sends every declared policy's real semantic receipts into the exact
  production analyzer with every integrity error, mismatch, failure, and
  violation count at zero; and
- proves the retained R1 misroute is rejected at synthetic step zero.

The perfect synthetic result is zero-defect, not zero-actuation: policies that
declare active balance behavior must still produce real nonzero semantic,
mapping, bounded-influence, and combined-application witnesses. The receipt
always reports zero world builds, zero SceneTree insertions, no physics-state
mutation, no locomotion outcome, and no physical authority.

The corrected production path lives in
[`../scripts/lab/gait/physical_wave_gait_quadruped.gd`](../scripts/lab/gait/physical_wave_gait_quadruped.gd)
and
[`../scripts/lab/gait/sdk_godot_jolt_adapter.gd`](../scripts/lab/gait/sdk_godot_jolt_adapter.gd).
The next physical work used the prospectively frozen R2 identity in
[`balanced_wave_bw13p_r2_morphology_development_preregistration.json`](balanced_wave_bw13p_r2_morphology_development_preregistration.json),
raw SHA-256
`0d5429d6b58cff495fec6ac75dfb1fd5f536b21ca726a7a1bdbab9862dd012f6`.
Its runner, harness, selector, and selector test are
[`run_balanced_wave_bw13p_r2_morphology_development.ps1`](run_balanced_wave_bw13p_r2_morphology_development.ps1),
[`../tests/test_sdk_balanced_wave_bw13p_r2_morphology_development.gd`](../tests/test_sdk_balanced_wave_bw13p_r2_morphology_development.gd),
[`compile_balanced_wave_bw13p_r2_selection.ps1`](compile_balanced_wave_bw13p_r2_selection.ps1),
and
[`../tests/test_bw13p_r2_selector.ps1`](../tests/test_bw13p_r2_selector.ps1).

All four candidate preflights passed from exact clean pushed R2 source. R2
then opened only its A control: `36/36` execution, mechanism, and combined
application receipts were valid, and `35/36` recorded walking. Before B could
open, the retained report contradicted its one failed cell by writing zero for
`aggregate_failed_production_walking_gate_count`.

The live objects were `OrderedDictionary` instances. `Measure-Object
-Property` did not expose their keys; the resulting null sum became zero under
an `Int32` cast. R2 is closed, may not resume or select, and remains
development diagnostics only. Its exact report hash, all 108 referenced
cell-artifact hashes, reconstructed metrics, unopened B/C/D directories, and
claim boundary are pinned in
[`balanced_wave_bw13p_r2_closure_manifest.json`](balanced_wave_bw13p_r2_closure_manifest.json)
and audited by
[`../tests/test_bw13p_r2_closure.ps1`](../tests/test_bw13p_r2_closure.ps1).

The perfect all-zero declared-policy gate remains mandatory because it proves
that the complete production integrity predicate is satisfiable. It is now
paired with a mandatory nonzero report sentinel: the exact ordered in-memory
type must propagate injected failed-gate, timeout, lateral, and cross-track
values through aggregation, JSON serialization, readback, and reconciliation
before a world can open. Shared fail-closed aggregation is in
[`experiment_result_integrity.ps1`](experiment_result_integrity.ps1), with its
zero-world regression in
[`../tests/test_experiment_result_integrity_preflight.ps1`](../tests/test_experiment_result_integrity_preflight.ps1).
R05C and the unbiased friction reservation remain unopened.

## Frozen BW13P-R3 successor

The corrected successor is prospectively frozen in
[`balanced_wave_bw13p_r3_morphology_development_preregistration.json`](balanced_wave_bw13p_r3_morphology_development_preregistration.json),
raw SHA-256
`ac8b4d2c1b866b42bcffda2aac0daa8eb1ce521dd9733e8d6fa8c68a7c750f1a`.
Its implementation parent is pushed R2-closure checkpoint
`1360f5247aa7a262d7d6f9899f823d309bcc1a54`.

R3 changes no candidate, policy digest, mechanism, fitted constant, branch
surface, morphology, seed, material, clock, walking threshold, metric order,
or selection rule. It changes only experiment infrastructure:

- both R1 and R2 closure audits must pass before the Godot preflights;
- every aggregate field is extracted explicitly through
  [`experiment_result_integrity.ps1`](experiment_result_integrity.ps1);
- the complete perfect 36-cell matrix must pass the exact production
  aggregate gate;
- a deliberately nonzero ordered-dictionary canary must preserve failed-gate,
  timeout, lateral, and cross-track values through aggregation, SHA-256, JSON
  readback, and recomputation; and
- the selector independently recomputes every aggregate from the 36 retained
  results and requires byte-equivalent metric JSON before comparing candidates.

The runner, Godot harness, selector, and selector regression are:

- [`run_balanced_wave_bw13p_r3_morphology_development.ps1`](run_balanced_wave_bw13p_r3_morphology_development.ps1);
- [`../tests/test_sdk_balanced_wave_bw13p_r3_morphology_development.gd`](../tests/test_sdk_balanced_wave_bw13p_r3_morphology_development.gd);
- [`compile_balanced_wave_bw13p_r3_selection.ps1`](compile_balanced_wave_bw13p_r3_selection.ps1); and
- [`../tests/test_bw13p_r3_selector.ps1`](../tests/test_bw13p_r3_selector.ps1).

An authored-tree A preflight passed the R1/R2 audits, receipt-v5 full horizon,
all 36 exact entrypoints, perfect aggregate, and nonzero canary with zero
worlds. Physical execution remains forbidden until these exact R3 bytes are
committed and pushed, `HEAD == origin/main`, and all four candidate preflights
pass again from that clean identity.

## Closed BW13P-R3 family

BW13P-R3 completed all `144/144` physical worlds from clean pushed source
`6080c964bdf0c3cd231c29bccb956d86df826322`. All 144 pass execution,
mechanism, and combined-application integrity. Walking conjunction totals
`133/144`; candidate A/B/C/D record respectively `35/36`, `32/36`, `33/36`,
and `33/36`.

The frozen selector, retained at
`<evidence-root>\bw13p-r3-morphology-development-6080c96\selection\selection.json`
with SHA-256
`52a10669d3266c54fc52d7f457da73e7c173cd2745b4a30871f95a83c127115a`,
rejects the treatment family because no treatment strictly beats the A
control's one walking failure. There is no selected R3 policy.

[`balanced_wave_bw13p_r3_closure_manifest.json`](balanced_wave_bw13p_r3_closure_manifest.json)
pins all four report paths and hashes, exact metric vectors, the selection,
`468/468` referenced artifact hashes, research sources, reservations, and
false claim fields.
[`../tests/test_bw13p_r3_closure.ps1`](../tests/test_bw13p_r3_closure.ps1)
reconstructs every metric from raw results and audits the complete closure.
R3 is historical development evidence and must not be rerun or used as an
active conformance launch target. R05C and the unbiased friction reservation
remain unopened.

## Prospectively frozen BW14V forward-velocity successor

`BW14V-MORPHOLOGY-DEVELOPMENT` is the next distinct, development-only
hypothesis. It is frozen before its first physics world in
[`balanced_wave_bw14v_morphology_development_preregistration.json`](balanced_wave_bw14v_morphology_development_preregistration.json),
raw SHA-256
`5030239a59fa477f0dab6cf749572edf7c9040569fff93d42d40c18da3dedd33`,
with implementation parent
`f7d8f2eabc907002ac8d3c540ef18040d4f1de5a`.

The two paired candidates use the already outcome-exposed R05B indices
`181`-`192` and seeds `21601`-`21603`:

- `BW14V-A` is the exact `BW5R-B` control, candidate digest
  `sha256:288012fe4af5e93f1ecd2f007821a03e95c316c27cda196317617b8130017292`;
- `BW14V-B` inherits the complete `BW5R-B` profile and adds a portable,
  branch-free task-frame forward-velocity foot-placement correction, candidate
  digest
  `sha256:3404217d991b8eaf6b9c0d74e84768ffd36264b6d664a7c02fc14f57b176713b`.

The treatment computes measured forward speed by projecting the base linear
velocity onto the task-frame forward axis. It normalizes
`desired - measured` by the magnitude of nonzero desired speed, clamps the
error to `[-1, 1]`, multiplies by the existing `0.30`-rad forward hip target,
and applies a continuous scheduler-derived swing/stance envelope. Desired
speed zero produces exactly zero correction. There are no morphology,
material, seed, known-failure, or outcome branches and no newly fitted
threshold.

The portable core owns the mechanism and emits a typed v4 receipt with four
ordered limb corrections. The Godot/Jolt adapter validates the policy,
profile, bound, receipt order, and exclusive eight-motor native authority.
The no-world authority contract is
[`../tests/test_sdk_balanced_wave_bw14v_authority_contract.gd`](../tests/test_sdk_balanced_wave_bw14v_authority_contract.gd).

Every candidate launch must run two complementary experiment-infrastructure
checks before a durable evidence directory is created or a world is built:

1. the complete declared-policy production integrity gate must accept an exact
   perfect synthetic 36-cell result whose error, mismatch, timeout, failure,
   and violation fields are all zero; and
2. the same live ordered-object aggregation and JSON round-trip must preserve
   deliberately nonzero failed-gate, timeout, lateral, and cross-track
   sentinels.

The first proves that a perfect result is actually admissible by the declared
policy and complete gate. The second proves that the experiment cannot pass
by dropping nonzero values or converting a missing aggregate into zero. This
pre-world rule is reusable infrastructure, not a BW14V-specific threshold.
It would have rejected the BW9L unsatisfiable-gate defect and the BW10F/R2
report-path defects before expensive physical execution.

The retained runner, harness, selector, and selector regression are:

- [`run_balanced_wave_bw14v_morphology_development.ps1`](run_balanced_wave_bw14v_morphology_development.ps1);
- [`../tests/test_sdk_balanced_wave_bw14v_morphology_development.gd`](../tests/test_sdk_balanced_wave_bw14v_morphology_development.gd);
- [`compile_balanced_wave_bw14v_selection.ps1`](compile_balanced_wave_bw14v_selection.ps1); and
- [`../tests/test_bw14v_selector.ps1`](../tests/test_bw14v_selector.ps1).

Run each zero-world launch proof from PowerShell:

```powershell
.\sdk\run_balanced_wave_bw14v_morphology_development.ps1 `
  -Candidate BW14V-A `
  -PreflightOnly

.\sdk\run_balanced_wave_bw14v_morphology_development.ps1 `
  -Candidate BW14V-B `
  -PreflightOnly
```

Physical execution is forbidden until these exact bytes are committed and
pushed, `HEAD == origin/main`, and both preflights pass again from that clean
identity. A strict lexicographic treatment win permits only a newly frozen
independent validation; a tie rejects the treatment. BW14V does not itself
authorize walking, balance improvement, independent morphology coverage,
arbitrary quadrupeds, continuous-volume coverage, material robustness,
cross-engine C6, SDK release, or a completed engine-neutral SDK. R05C and the
unbiased friction reservation remain sealed.

The research inputs are retained and hash-pinned in the preregistration:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

## Closed BW14V forward-velocity treatment family

BW14V completed all `72/72` paired physical worlds from clean pushed source
`b519fe094196d235a9a09c8c3a5637d2553e2bc2`. All worlds pass execution,
mechanism, combined-application, and result-integrity gates. The A control
records `33/36` walking conjunctions. The B treatment records `0/36`, with
`344` failed walking gates and `194` release timeouts.

All 36 B receipts prove `forward_velocity_foot_placement_v1` was enabled,
branch-free, bounded to the declared `0.30`-rad correction and unit normalized
error, and applied through exclusive native eight-motor authority. B's
collapse is therefore retained as a negative controller result.

The exact durable artifacts are:

- A report:
  `<evidence-root>\bw14v-morphology-development-b519fe0\BW14V-A\report.json`,
  SHA-256
  `29166d1b2f28b53942a2bbd6ff03fe52077804ffc9e960f95f405d30065d33b4`;
- B report:
  `<evidence-root>\bw14v-morphology-development-b519fe0\BW14V-B\report.json`,
  SHA-256
  `438593b539f6e31a12b5bd4760b41e9c5a8a5a71d0d99e8c2ff8f3073562e25a`;
  and
- selection:
  `<evidence-root>\bw14v-morphology-development-b519fe0\selection\selection.json`,
  SHA-256
  `228c6101909170a13cff52750422c96e91a7e17a19c03e4298caeee3da527b87`.

The reports were deterministically finalized from complete retained world
artifacts after an external wrapper timeout for A and a PowerShell finalizer
defect after B world 36. Recovery receipts prove zero physical reruns,
replacements, or deletions. The generic runner now resolves the
freeze-parent commit before report construction, and preflight exercises the
same path.

[`balanced_wave_bw14v_closure_manifest.json`](balanced_wave_bw14v_closure_manifest.json)
is the immutable family disposition.
[`../tests/test_bw14v_closure.ps1`](../tests/test_bw14v_closure.ps1)
recomputes both reports, verifies `228/228` retained artifacts, and enforces
`family_selected=false`.

BW14V is closed and may not be tuned, repaired, rerun, reclassified, or
selected after outcome inspection. R05C indices `193`-`204`, seeds
`38101`-`38103`, and the unbiased friction reservation remain unopened. A new
controller hypothesis requires a distinct prospectively frozen source and
preregistration identity. This closure grants no walking, balance,
independent morphology, material, terrain, push, sensor, cross-engine,
running, biped, release, or completed-SDK authority.

## BW15F signed-error/gain factorial

The distinct next development identity is
[`balanced_wave_bw15f_morphology_development_preregistration.json`](balanced_wave_bw15f_morphology_development_preregistration.json),
raw SHA-256
`722a65c741d3bd41c5374225c5d7b0d611ce87cf5ac5ede1d3eda9142c362e29`.
It is based on the complete matched diagnostic in
[`balanced_wave_bw14v_posthoc_diagnostic.json`](balanced_wave_bw14v_posthoc_diagnostic.json),
not on per-morphology repairs. BW14V-B reached its `0.30`-rad cap in all
`36/36` cells and was worse than its matched control on evidence-window
forward displacement, maximum tilt, and minimum torso height in all `36/36`.

BW15F freezes four global arms:

- `BW15F-A`: exact `BW5R-B` control;
- `BW15F-B`: desired-minus-measured error, `0.03`-rad cap;
- `BW15F-C`: measured-minus-desired error, `0.03`-rad cap; and
- `BW15F-D`: measured-minus-desired error, `0.06`-rad cap.

B/C isolate sign at fixed gain; C/D isolate gain at fixed sign. No arm has a
morphology, material, seed, failure-identity, or outcome branch. The portable
core emits typed v5/v2 controller/mechanism receipts naming the orientation
and gain. The no-world contract
[`../tests/test_sdk_balanced_wave_bw15f_authority_contract.gd`](../tests/test_sdk_balanced_wave_bw15f_authority_contract.gd)
passes `8/8`.

The retained surfaces are:

- [`run_balanced_wave_bw15f_morphology_development.ps1`](run_balanced_wave_bw15f_morphology_development.ps1);
- [`../tests/test_sdk_balanced_wave_bw15f_morphology_development.gd`](../tests/test_sdk_balanced_wave_bw15f_morphology_development.gd);
- [`compile_balanced_wave_bw15f_selection.ps1`](compile_balanced_wave_bw15f_selection.ps1); and
- [`../tests/test_bw15f_selector.ps1`](../tests/test_bw15f_selector.ps1).

Each arm must pass the perfect full-gate synthetic input, nonzero aggregation
canary, selector regression, zero-world authority contract, and all `36/36`
entrypoints before a durable evidence directory or physics world can exist.
All four physical reports are mandatory. The selector recomputes raw-result
metrics, uses B/C/D as the treatment tie order, and selects only a treatment
that strictly beats A. A control tie rejects every treatment.

Run the zero-world proof for each arm from PowerShell:

```powershell
foreach ($candidate in "BW15F-A", "BW15F-B", "BW15F-C", "BW15F-D") {
  .\sdk\run_balanced_wave_bw15f_morphology_development.ps1 `
    -Candidate $candidate `
    -PreflightOnly
}
```

The R05B cohort is already outcome-exposed and is development-only here.
R05C and the unbiased friction reservation remain unopened. A selected BW15F
treatment would still require a new prospectively frozen independent
validation. The family grants no walking, balance, arbitrary-quadruped,
continuous-volume, material, terrain, push, sensor, cross-engine, running,
biped, release, or completed engine-neutral SDK claim.

The exact method inputs remain linked and hash-pinned:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

## Closed BW15F development selection

BW15F completed all `144/144` physical worlds from clean pushed source
`14647c1c17ea30f3d73542e0f24c2c66c37fb487`. All 144 receipts pass
harness, integrity, mechanism, and application gates. Independent closure
verification hash-matches `448` report artifacts and `12` supervisor
artifacts and exactly reconstructs all four metric objects.

The primary walking-failure counts were A=`3`, B=`2`, C=`2`, D=`5`. B and C
therefore both strictly beat control on the first metric; B won the frozen
second metric with `2` failed gates versus C's `3`. The selector selected
`BW15F-B`, the small `desired - measured` arm, not the reversed-sign arms.

The exact report hashes are:

- A: `65b1aab891a77eacd88d75de374e740cb8d6dd4cbb82f0e0ace1fd856b01fe54`;
- B: `e54d4bbc48046f572dc2eec70688e00b156d0cd0cfededc73861e01750e79c9b`;
- C: `64f971b64106b4d93de7b5e970c87be9240c89977d38431f27e78d84a25256e5`;
- D: `b04606495e6b26b80a4d237af8703581339f3d9e210d2ba044f111981399ac50`;
  and
- selection:
  `daf95012d1d7fb0bcd6771200d5a08d90858e2e409237c22ad0b1dae989195cf`.

The durable root is
`<evidence-root>\bw15f-morphology-development-14647c1`.
[`balanced_wave_bw15f_closure_manifest.json`](balanced_wave_bw15f_closure_manifest.json)
and
[`../tests/test_bw15f_closure.ps1`](../tests/test_bw15f_closure.ps1)
seal the result.

BW15F cannot be rerun, repaired, reclassified, or reselected. `BW15F-B` is
development-selected only; its `34/36` result on an exposed cohort is not
walking acceptance. The next legal step is a separately frozen independent
R05C campaign on indices `193`-`204` and seeds `38101`-`38103`. Friction and
all broader robustness/release claims remain unopened.

## Frozen QSDK-R05C independent BW15F-B validation

[`qsdk_r05c_independent_morphology_preregistration.json`](qsdk_r05c_independent_morphology_preregistration.json)
is frozen before the first R05C physics world, raw SHA-256
`1fa59563ac88de693028be0cf541a9a94b22fe15dad0a70d86ace95abd0789d6`.
It binds the unchanged selected `BW15F-B` policy digest
`sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd`
to the twelve outcome-unexposed generator indices `193`-`204` and fresh
campaign seeds `38101`-`38103`.

The selected development output is separately frozen in
[`balanced_wave_bw15f_selected_policy.json`](balanced_wave_bw15f_selected_policy.json),
raw SHA-256
`6e114c809df93ff6b7059a9e203ae1538f2f6a12a45cadc6760f379bf1c99bed`.
The R05C launcher verifies that file, the BW15F closure manifest, the complete
selection report, and the selected B report byte-for-byte before it can open a
world. It also rejects any change to the controller identity, branch surface
count, material, solver, walking thresholds, host scaffold, generator cells,
or seeds.

The retained implementation surfaces are:

- [`run_qsdk_r05c_independent_morphology.ps1`](run_qsdk_r05c_independent_morphology.ps1);
- [`run_qsdk_independent_morphology_v2.ps1`](run_qsdk_independent_morphology_v2.ps1);
- [`../tests/test_sdk_qsdk_r05c_independent_morphology.gd`](../tests/test_sdk_qsdk_r05c_independent_morphology.gd); and
- [`../scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd`](../scripts/lab/gait/physical_quadruped_proportion_spec_v2.gd).

The exact production preflight has passed with zero worlds: all eight declared
policy runtime boundaries, the `3,232`-step/`25,856`-command worst signed
runtime horizon, the perfect 36-cell aggregate, the nonzero failure canary,
all `36/36` R05C entrypoints, and hashing/serialization of `28` retained
source files. Physical execution remains forbidden until these bytes are
committed and pushed with `HEAD == origin/main`, followed by the same cold
preflight from that clean source.

R05C accepts only if the first complete `36`-world result has `36/36` common
execution integrity, exact exclusive SDK motor authority, and `36/36`
continuous-world walking conjunctions. Any nonwalking cell rejects R05C;
there is no repair, threshold relaxation, rerun, seed deletion, cell
replacement, or early stop under this identity.

Even a pass establishes only independent evidence for one frozen policy on
this finite 12-by-3 population. It does not establish arbitrary quadrupeds,
continuous full-volume coverage, friction/material robustness, terrain,
pushes, sensor noise/latency, another engine, running, release, or a completed
engine-neutral SDK.

Methods provenance remains retained and hash-pinned:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

## Closed QSDK-R05C independent validation

QSDK-R05C completed its first and only `36`-world result from clean pushed
source `c41522cbffa2a2f8c6f504a07e532aeef57f1dbd`. All `36/36` cells have
parseable receipts, exact `BW15F-B` policy identity, full native SDK motor
authority, common execution integrity, the declared mechanism, and combined
application. The campaign is nevertheless rejected: only `29/36` cells pass
every frozen walking receipt.

The immutable report is
`<evidence-root>\qsdk-r05c-c41522c\report.json`,
SHA-256
`f4318de42b7c206077d2b4301491567270274812cf7eaba8a8e816864c5f2015`.
[`qsdk_r05c_independent_morphology_validation_manifest.json`](qsdk_r05c_independent_morphology_validation_manifest.json)
pins its disposition, and
[`../tests/test_qsdk_r05c_closure.ps1`](../tests/test_qsdk_r05c_closure.ps1)
reconstructs the metrics and independently verifies `28` source hashes, `108`
cell artifacts, `3` preflight artifacts, and `2` supervisor logs.

The seven nonwalking cells contain `25` false walking booleans:
`bounded_lateral_drift=5`,
`contact_gating_completed_without_timeout=4`,
`bounded_tilt=2`, `bounded_torso_height=2`, `bounded_yaw_drift=2`,
`terminal_four_contact_recovery=2`, `zero_torso_contact=2`, plus one each for
the contact-gated evidence horizon, every-limb evidence horizon, every-limb
relocation, every-limb two-cycle, minimum evidence translation, and minimum
final translation receipts. These identities are retained as diagnostics
only; they may not be used to repair, rerun, or reclassify R05C.

The report envelope exposes a known aggregation limitation. It records one
failed-production-gate scalar for each nonwalking cell (`7`) rather than the
raw false-boolean count (`25`), and it records zero release-timeout scalars
even though four raw
`contact_gating_completed_without_timeout` receipts are false. The closure
audits both representations and forbids rewriting the historical report.
There is no effect on acceptance: the preregistered rule required all `36/36`
walking conjunctions, so both representations reject R05C.

The cells sum to `101,008` SDK steps and `808,064` validated native commands
and motor writes, with zero direct body writes, legacy post-settle or evidence
writes, mismatches, safe-disable events, or safe-no-actuation events. This is
therefore a clean physical generalization rejection, not an adapter,
authority, process, parsing, or evidence-retention failure.

R05C is final. It cannot be tuned, relaxed, rerun, averaged, or reopened.
`BW15F-B` does not gain independent morphology acceptance, arbitrary
quadruped, continuous-volume, friction/material, terrain, push, sensor,
cross-engine, running, variable-limb, biped, release, or completed-SDK
authority. A new controller mechanism requires a distinct prospective
identity and may not condition on these seven failures; any later validation
requires unopened morphologies and fresh seeds. The unbiased friction
reservation remains unopened.

The closure retains the exact methods provenance:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

## Frozen BW16S portable-balance composition development

QSDK-R05C established a clean technical execution but rejected the unchanged
`BW15F-B` policy at `29/36` walking conjunctions. The next experiment does not
repair or rerun R05C and does not condition on any of its seven failed-cell
identities. It asks one global mechanism question under the new
`BW16S-MORPHOLOGY-DEVELOPMENT` identity: does the already-frozen portable
P5I.3C support-centroid/torso-tilt feedback composition strictly improve the
unchanged BW15F-B controller on the complete paired, now-outcome-exposed R05C
cohort?

The exact prospective inputs are:

- [`balanced_wave_bw16s_balance_composition_candidates.json`](balanced_wave_bw16s_balance_composition_candidates.json),
  raw SHA-256
  `0c42d2c90159980a695480a561b2fe519ddcc8b7b7cc65a2515257bfa24731ec`;
- [`balanced_wave_bw16s_morphology_development_preregistration.json`](balanced_wave_bw16s_morphology_development_preregistration.json),
  raw SHA-256
  `3701265647edacad07138d817c6c48c571eff9250d84e827657b4d2148bbfa94`;
- [`../tests/test_sdk_balanced_wave_bw16s_morphology_development.gd`](../tests/test_sdk_balanced_wave_bw16s_morphology_development.gd);
- [`../tests/test_sdk_balanced_wave_bw16s_authority_contract.gd`](../tests/test_sdk_balanced_wave_bw16s_authority_contract.gd);
- [`run_balanced_wave_bw16s_morphology_development.ps1`](run_balanced_wave_bw16s_morphology_development.ps1);
- [`compile_balanced_wave_bw16s_selection.ps1`](compile_balanced_wave_bw16s_selection.ps1); and
- [`../tests/test_bw16s_selector.ps1`](../tests/test_bw16s_selector.ps1).

Both candidates use controller candidate `BW15F-B`, controller policy
`sporespore_balanced_wave_bw15f_b_v1`, digest
`sha256:7e6004c57a1f2b193beb3757c5b45ecc3589aabd1b70c103920f0a74dd1207cd`,
the same twelve generator indices `193`-`204`, the same seeds
`38101`-`38103`, material `godot_jolt_bw5c_mu095_v1`, solver, host scaffold,
and production walking thresholds. Their only declared difference is:

- `BW16S-A`, digest
  `sha256:5fdd2fae60409d31fb66c7152cecf7123e8cf410c56dd902a21ea90aad037bce`:
  P5I.3B shadow, feedback disabled, overlay disabled, and exclusive
  `post_settle_full` native authority; versus
- `BW16S-B`, digest
  `sha256:e77f0ab9a8828a95c1c6d30003a381b5d4a8386a4ff49df270fcf31b86e0c94c`:
  the pre-existing `p5i3c_support_centroid_tilt_feedback_v1` law and its
  commissioned `stability_contribution_overlay` route.

P5I.3C's gains remain the earlier dimensional/mechanical freeze: horizontal
position `5.0 N/m`, horizontal velocity `0.1 Ns/m`, maximum horizontal force
`0.75 N`, roll/pitch position `0.5 Nm/rad`, roll/pitch velocity
`0.05 Nms/rad`, maximum roll/pitch moment `0.1 Nm`, and exact-zero vertical
feedback. No gain, morphology/material/seed/failure/outcome condition, or
branch surface was added after R05C.

The treatment route distinction is explicit. The current commissioned overlay
temporarily permits and counts the host base write, then the Godot adapter
writes the final portable BW15F-B base plus bounded P5I.3C contribution. It is
not described as the same route as candidate A's exclusive post-settle native
authority. Every treatment cell must prove one typed contribution attempt per
SDK step, eight typed outputs per step, one overlay application per step,
eight final overlay motor writes per step, a nonzero effective application,
and zero mapping, limiter, profile-conversion, speed-limit, readback, or
overlay failures.

The complete no-world preflight already passes for both arms:

- the immutable R05C closure and retained report hashes;
- all eight declared-policy runtime boundaries and the worst signed full
  runtime horizon;
- the BW16S `10/10` authority contract;
- all `36/36` exact candidate entrypoints for each arm (`72/72` total);
- the strict-selector win/tie/loss/missing/invalid regressions;
- the full perfect all-zero 36-cell production aggregate;
- the deliberately nonzero three-failed-gate/two-timeout canary; and
- a serialized/re-read report containing all `30` retained source hashes.

Run the zero-world gate from PowerShell:

```powershell
foreach ($candidate in "BW16S-A", "BW16S-B") {
  .\sdk\run_balanced_wave_bw16s_morphology_development.ps1 `
    -Candidate $candidate `
    -PreflightOnly
}
```

Physical execution is forbidden until this freeze is committed and pushed
with `HEAD == origin/main`, then the same preflight passes from that exact
source. Both complete 36-world reports are mandatory. Selection requires
`36/36` integrity, mechanism, and combined-application receipts for both
arms, then selects B only if its frozen metric vector is strictly
lexicographically lower than A. A tie or control win rejects B.

The report envelope fixes the historical R05C aggregation limitation for new
work: each cell exports the exact raw false-walking-gate count and exact
release-timeout scalar. R05C's immutable report is not rewritten.

BW16S is development-only. Even a strict treatment win does not authorize
walking acceptance, balance improvement, independent morphology validation,
arbitrary quadrupeds, continuous morphology volume, friction/material,
terrain, pushes, sensor faults, other engines, variable limb counts, running,
bipeds, release, or a completed engine-neutral SDK. Promotion would require a
new prospectively frozen population of unopened morphologies and fresh seeds.

Research provenance remains byte-pinned:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

## Closed BW16S portable-balance composition development

BW16S completed both frozen 36-world arms from clean pushed source
`896a49ca57452ad1a2e1d3d1c63cdf1de4dd0dc8`. All `72/72` worlds have
complete receipts, common integrity, the declared controller and stability
mechanisms, and combined application. Candidate B physically applied its
typed P5I.3C contribution overlay in every treatment world. The result is
therefore a real controller-composition comparison, not a missing-mechanism,
adapter, process, or evidence failure.

The exact evidence root is
`<evidence-root>\bw16s-morphology-development-896a49c`.
The retained identities are:

- A report:
  `BW16S-A\report.json`, SHA-256
  `6258ac8bd94412f342034a54d3b265d49bb567be2d2b8b4716ae20a9be8cfb56`;
- B report:
  `BW16S-B\report.json`, SHA-256
  `ef4a80969e865a689761980e420a3d67e2575fb9b634d2de6d8243adef173a9b`;
  and
- selection:
  `selection\selection.json`, SHA-256
  `3a185fbe7e4a0dfc99a0a617989515f855aa2a6f893ceeb0ae9ba1ca2e52e5ec`.

The frozen vectors are:

- A: `[7, 25, 15, 5.488835366380132, 19.693325581880757,
  45.15938733062067]`, with `29/36` walking; and
- B: `[8, 10, 2, 1.383704013779304, 15.317166675247709,
  23.00660056835144]`, with `28/36` walking.

The selector minimizes walking-conjunction failures first. B has eight,
versus A's seven, so
`result_status=bw16s_family_rejected_treatment_worse_than_control` and no
candidate is selected. B's large secondary improvements remain useful
diagnostics: raw false walking receipts fall from `25` to `10`, release
timeouts from `15` to `2`, maximum normalized lateral displacement from
`5.488835366380132` to `1.383704013779304`, and aggregate cross-track error
from `45.15938733062067` to `23.00660056835144`. They do not override the
preregistered primary metric and do not establish balance improvement.

[`balanced_wave_bw16s_closure_manifest.json`](balanced_wave_bw16s_closure_manifest.json)
pins the reports, selection, supervisor logs, exact vectors, mechanism
totals, source hashes, research inputs, and false claim fields.
[`../tests/test_bw16s_closure.ps1`](../tests/test_bw16s_closure.ps1)
reconstructs both metric objects from raw cells and verifies `60`
report-declared source hashes, `224` cell/preflight artifacts, `4` supervisor
logs, `2` reports, and the selection.

BW16S is closed negative development evidence. It may not be repaired, rerun,
reclassified, threshold-relaxed, averaged, or patched after observing the
result. P5I.3C does not advance from this family, and the portable release
policy is unchanged. Cross-engine C6 infrastructure may continue without
promoting BW16S, while any new controller/composition hypothesis requires a
new prospective identity. A later independent acceptance campaign requires
unopened morphologies and fresh seeds.

This closure grants no walking acceptance, balance improvement, independent
morphology validation, arbitrary-quadruped or continuous-volume claim,
friction/material robustness, terrain, pushes, sensor faults, other engines,
variable limb counts, running, bipeds, release, or completed engine-neutral
SDK authority. The unbiased friction reservation remains unopened.

The closure retains the exact method sources:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).

## Frozen BW18G global residual-scale development

BW18G is a four-arm, branch-free successor to the closed negative BW17P
composition. Every arm uses the same BW15F-B base controller, BW13P-A
portable scheduled-support plan, Godot/Jolt material, morphology/seed pairs,
and exclusive `post_settle_full` native authority. The only declared factor
is one portable-core global residual scale:

- `BW18G-A = 0.0` (exact-zero residual control);
- `BW18G-B = 0.25`;
- `BW18G-C = 0.5`; and
- `BW18G-D = 1.0`.

The public v3 operation is `ss_bound_stability_influence_v3_json`. It scales
every typed requested correction before the existing magnitude and slew
limits and returns raw, scaled, and applied values. Rust, the C header,
Python, the Godot GDExtension, and the Godot/Jolt adapter expose the same
contract. The legacy v2 operation remains available.

The prospective identities are:

- [`balanced_wave_bw18g_residual_scale_candidates.json`](balanced_wave_bw18g_residual_scale_candidates.json),
  SHA-256
  `a6bc578006217c8bea3601c1de2b62bbcaaa6fbb5809679d8bd97a2fac9e3d7f`;
- [`balanced_wave_bw18g_morphology_development_preregistration.json`](balanced_wave_bw18g_morphology_development_preregistration.json),
  SHA-256
  `86ee6166408e3a60b649f6c618d559dd5accd8b8e7dc5b5af68e2a07b519edfa`;
- [`run_balanced_wave_bw18g_morphology_development.ps1`](run_balanced_wave_bw18g_morphology_development.ps1);
- [`compile_balanced_wave_bw18g_selection.ps1`](compile_balanced_wave_bw18g_selection.ps1);
- [`../tests/test_sdk_balanced_wave_bw18g_scale_contract.gd`](../tests/test_sdk_balanced_wave_bw18g_scale_contract.gd); and
- [`../tests/test_bw18g_selector.ps1`](../tests/test_bw18g_selector.ps1).

All four zero-world runner preflights pass. Together they exercise `144/144`
exact morphology/seed entrypoints, the full perfect declared-policy horizon,
the nonzero aggregation canary, retained predecessor interlocks, report
roundtrips, and the strict selector. The separate scale contract passes
`8/8`, and Python ctypes crosses the rebuilt release DLL.

No BW18G physics world had opened at this freeze. Physical reports must be
written once to
`<evidence-root>`, never a temporary
directory, and only from clean pushed source with `HEAD == origin/main`. All
four `36/36` reports are required. Selection requires a treatment to be
strictly lexicographically better than A; ties or a control win reject the
family.

This is outcome-exposed development, not independent validation. It grants no
walking or balance acceptance, arbitrary-quadruped or continuous-volume
coverage, friction/material robustness, terrain, push, sensor-fault,
cross-engine, variable-limb, running, biped, release, or completed-SDK
authority. Any development winner must face a new preregistered population of
unopened morphologies and fresh seeds.

The exact research inputs remain:
[`../DReCon.pdf`](../DReCon.pdf),
[`../2604.08780v1.pdf`](../2604.08780v1.pdf),
[`../2507.22653v2.pdf`](../2507.22653v2.pdf), and
[`../docs/research/LOCOMOTION_RESEARCH_SOURCES.md`](../docs/research/LOCOMOTION_RESEARCH_SOURCES.md).


## Closed-positive BW20F cold material characterization

BW20F is the exact-finite Godot/Jolt material-characterization stage for the
independently confirmed BW19V-B successor composition. The prospective freeze
declared authored values `0.09`, `0.37`, `0.76`, and `1.18`, three replicates
per value, one frictionless control, 13 total worlds, and 23 all-or-nothing
production gates. Locomotion seeds `23001`-`23003` remained sealed through
stages 1 and 2; stage 3 has now outcome-exposed them.

The one supervised attempt ran from clean pushed source `476aa4e`, completed
`13/13` worlds, and passed `23/23` gates. The retained report is:

```text
<evidence-root>\balanced-wave-bw20f-material-characterization-476aa4e\report.json
SHA-256 f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030
```

The characterized adapter coefficients are `0.07`, `0.35`, `0.73`, and
`1.00`, in authored-value order. They are pinned Godot/Jolt profile inputs,
not portable material coefficients and not locomotion evidence.

Run the immutable closed-state audit from PowerShell at the repository root:

```powershell
pwsh -NoProfile -File .\tests\test_bw20f_material_characterization_closure.ps1
```

Expected terminal receipt:

```text
BW20F_MATERIAL_CLOSURE_PASS status=positive worlds=13 gates=23 cells=4 profile_publication=True locomotion_seeds_opened=0 rerun_refused=True material_robustness=False physical_authority=False
```

The closure is
[`balanced_wave_bw20f_material_characterization_closure.json`](balanced_wave_bw20f_material_characterization_closure.json),
SHA-256
`68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a`.
It retains every physical artifact and source binding and forbids another
BW20F stage-1 attempt. Do not call either physical runner for this identity.
Routine conformance may still exercise the zero-world supervisor preflight;
it cannot reopen the campaign.

The positive closure authorizes immutable profile publication only. It does
not establish walking, BW19V-B material robustness, continuous friction,
arbitrary materials, cross-engine equivalence, release, physical acceptance,
or a completed SDK. The release-selected BW5R-B/QSDK-R08 authority remains
unchanged. Stage-3 locomotion is now blocked behind its still-unfrozen distinct
manifest and complete synthetic gate; stage-2 publication itself is closed.


## Closed-positive BW20F material-profile publication

BW20F stage 2 is a separate deterministic zero-world publication identity:
`BW20F-BW19V-COLD-MATERIAL-PROFILE-PUBLICATION`, gate `BW20F-PROFILE`. Its
preregistration is
[`balanced_wave_bw20f_material_profile_publication_preregistration.json`](balanced_wave_bw20f_material_profile_publication_preregistration.json),
SHA-256
`07eef222b7aba50b1963db54f6ef80710359be2c4e4a38fd7af0c62c8d791372`.
It binds stage-1 closure SHA-256
`68d1ba699d1dcfd9b190423fd542b18843823374cdd8f69029c4e05548e3bf2a`
and retained characterization-report SHA-256
`f0a279fb9660554a0d4997c6b8adb5c767bc3f92f2497694448429f142155030`.

The four published immutable records are:

| Profile ID | Authored friction | Adapter coefficient | Canonical profile SHA-256 |
|---|---:|---:|---|
| `godot_jolt_bw20f_mu009_v1` | `0.09` | `0.07` | `sha256:92891cfbed2b30c5d6c72fa02a30770fcf75880416a92fe2f69d9ece8246ee55` |
| `godot_jolt_bw20f_mu037_v1` | `0.37` | `0.35` | `sha256:690e5c2f035a7a3efc32fa31c86cfab03299f8c539500e110b5ddf9e35b6dfb9` |
| `godot_jolt_bw20f_mu076_v1` | `0.76` | `0.73` | `sha256:76f42bc89da95e09d081d17d5e3aa520de25fa6a352067dd8c30ace3834667b0` |
| `godot_jolt_bw20f_mu118_v1` | `1.18` | `1.00` | `sha256:e0c6a6d78ae63a129e7ae44088aeb86da44941dba8cfcfd5680f73a236c9b297` |

The complete preflight resolves all 29 historical-plus-BW20F profiles and
passes `40/40` gates over 30 adapter starts. It preserves the legacy default,
requires every canonical digest to be unique, and rejects an unknown profile,
fixture mismatch, solver mismatch, and record tamper. It reports zero worlds,
samples, commands, and opened locomotion seeds:

```text
BW20F-PROFILE PREFLIGHT_PASS profiles=29 bw20f_profiles=4 gates=40 adapter_starts=30 worlds=0 samples=0 commands=0 locomotion_seeds_opened=0 physical_authority=False
```

The first development invocation exposed a stale outer cardinality assertion:
the inner Godot receipt correctly passed `40/40`, but the PowerShell wrapper
still expected the former `36` gates and rejected it. That nonphysical defect
created no retained evidence and opened no world; the assertion was corrected
before this freeze, then the complete supervisor preflight passed. This is a
positive example of the whole-gate preflight rejecting incomplete plumbing
before consuming a retained identity.

The executable prospective-freeze audit is
[`../tests/test_bw20f_material_profile_publication_freeze.ps1`](../tests/test_bw20f_material_profile_publication_freeze.ps1),
SHA-256
`04dc560a5f2a74d16a5ee57e2f540ccdfbd3dd9f0058e628cde2a8fbd30bf740`.
Its full receipt is:

```text
BW20F-PROFILE_FREEZE_PASS profiles=29 bw20f_profiles=4 gates=40 worlds=0 samples=0 commands=0 canaries=4 profile_canaries_executed=True bypass_canaries_declared=3 bypass_canaries_executed=3 supervisor_preflight_executed=True profile_published=False material_robustness=False physical_authority=False
```

The one permitted publication then ran from clean pushed source
`cf9431e7b45fdbff50af8d8f386c19bb85b4fc5f`. It retained its report at:

```text
<evidence-root>\balanced-wave-bw20f-material-profiles-cf9431e\report.json
SHA-256 96ef9fd50da7e92b668d9552ebf821d8fe02fa8ab0a2247b93cda0a48115968f
```

The report passed `40/40` gates for 29 profiles and 30 adapter starts, with
four BW20F records and zero worlds, samples, commands, actuation, transform or
velocity writes, and opened locomotion seeds. The attempt and completion
SHA-256 hashes are respectively
`ebcb30971b6ad5286fa58391c3f45e1e4155d299e107a781df355019bc304575`
and
`7dd07d772f1b82825589b0b59b0f4d97e5b916ed3247aa16724baeffb789648d`.

The immutable closure is
[`balanced_wave_bw20f_material_profile_publication_closure.json`](balanced_wave_bw20f_material_profile_publication_closure.json),
SHA-256
`d5e08e0602f745e78b1c34cc10a95f1399a969f9ccab0fd62ff68f6a53e25f1e`.
Its executable audit is
[`../tests/test_bw20f_material_profile_publication_closure.ps1`](../tests/test_bw20f_material_profile_publication_closure.ps1),
SHA-256
`b2aabd22b1b092a785df2b856b4aa7fc30d36f55f18a81db1f2d3c472db4b05a`.
It hash-verifies all eight retained files and ten frozen source blobs,
reconciles all profile identities/digests and negative claims, confirms exactly
one attempt, and proves a repeat `-Publish` fails at the closure interlock
before Godot starts:

```text
BW20F_PROFILE_CLOSURE_PASS status=positive profiles=29 bw20f_profiles=4 gates=40 worlds=0 samples=0 commands=0 rerun_refused=True stage3_manifest=True material_robustness=False physical_authority=False
```

Stage 3 subsequently froze that scientifically distinct 17-world locomotion
manifest and complete policy-relative synthetic gate. At that prospective
boundary, no stage-3 locomotion world had opened and physical execution was
blocked until the exact frozen source was clean, pushed, and equal to live
GitHub `main`.

No walking, locomotion material robustness, continuous-friction coverage,
portable material coefficient, cross-engine equivalence, release, or physical
acceptance claim follows from a profile table or its zero-world publication.

Verification at this prospective boundary passed the complete audit with all
three runtime bypass canaries and the full 40-gate supervisor preflight. The
release-readiness suite remained `24/24`. The complete
`sdk/run_conformance.ps1 -SkipGodot` regression then passed in `281.4 s`,
including every retained campaign closure and the new static freeze audit.
The targeted Godot path and the broad regression path both opened zero BW20F
physics or locomotion worlds.

After the retained publication and closure integration, the closed-state audit,
`24/24` release-readiness gates, and the complete post-publication zero-world
profile preflight all passed. The full
`sdk/run_conformance.ps1 -SkipGodot` pipeline passed in `299.3 s`, with the
immutable profile-publication closure audit replacing the prospective audit in
routine conformance. No check reopened the publication or any BW20F world.

## Historical prospective freeze: BW20F stage-3 material locomotion

Stage 3 is frozen under the distinct campaign identity
`BW20F-BW19V-COLD-MATERIAL-LOCOMOTION`, gate `BW20F-LOCOMOTION`. Its source
contract is
[`balanced_wave_bw20f_material_locomotion_preregistration.json`](balanced_wave_bw20f_material_locomotion_preregistration.json),
with raw SHA-256
`fc3749e6ce0d7a68603884c89e0ac8d5060aef8f419a375cb1ab3db39975797d`.
The campaign is an exact finite all-cells-must-pass decision, not a development
screen, superiority study, equivalence/noninferiority study, or population
inference.

The ordered physical matrix is fixed at 17 worlds:

- 12 BW19V-B treatments: all four authored values `0.09`, `0.37`, `0.76`,
  and `1.18` crossed with seeds `23001`, `23002`, and `23003`, using global
  requested correction scale `0.5`;
- four BW19V-A controls: seed `23001` at every authored value, using exact-zero
  scale `0.0`; and
- one zero-friction seed-`23001` safety cell using published profile
  `godot_jolt_p5m1r1_mu000_v1`, with zero SDK-native motor writes and no
  walking claim.

The controls are configuration/application controls, not outcome comparators.
Each matched pair must retain identical fixture, profile, seed, thresholds,
solver, controller configuration, perturbation, and initial pose while
expressing the frozen `BW19V-B/0.5` versus `BW19V-A/0.0` policy-relative
contrast. Treatment terminal displacement need not differ from or outperform
the control. This is why the older BW5C terminal-separation threshold is not
part of the new gate. Every treatment must independently pass every ordinary
production walking gate.

The actual evaluator in
[`balanced_wave_bw20f_material_locomotion_gate.ps1`](balanced_wave_bw20f_material_locomotion_gate.ps1)
reconstructs 28 gates: three result/host/prerequisite gates, 17 per-world
gates, and eight aggregate gates. The perfect serialized 17-cell result and
round trip pass; twelve independent mutations fail closed for wrong host,
missing cell, wrong role/order, missing treatment application, false control
application, walking failure, forbidden safety actuation, profile mismatch,
nonfinite data, paired-identity drift, claim inflation, and prerequisite
drift. Receipt:

```text
BW20F_MATERIAL_LOCOMOTION_GATE_PASS gates=28 cells=17 treatments=12 controls=4 safety=1 pairs=4 canaries=12 roundtrip=True worlds=0 terminal_separation_gate=False superiority=False physical_authority=False
```

The real Godot entrypoint then starts all 16 treatment/control adapter paths
and compiles the safety path without constructing a world, inserting a scene,
mutating physics, or exposing an outcome. The prospective audit pins every
source and prerequisite hash, runs the complete supervisor route, and proves
three bypasses fail before physics: missing durable output, direct worker
entry, and forged nonexistent attempt authorization. Receipts:

```text
BW20F-LOCOMOTION PREFLIGHT_PASS production_gates=28 cells=17 treatments=12 controls=4 safety=1 adapter_starts=16 canaries=12 worlds=0 scene_insertions=0 terminal_separation_gate=False superiority=False physical_authority=False
BW20F-LOCOMOTION FREEZE_PASS worlds=0 production_gates=28 cells=17 treatments=12 controls=4 safety=1 profiles=4 seeds=3 canaries=12 bypass_canaries=3 terminal_separation_gate=False superiority=False material_robustness=False physical_authority=False
```

At this prospective boundary, no stage-3 attempt existed and no locomotion seed
had been opened. A physical run was permitted only after this exact source was
committed, pushed, and equal to
live GitHub `main`. The supervisor was required to create the source-named
durable evidence root, write the immutable attempt receipt before the first
worker, run each world in its own process, retain all 17 attempts even if one
failed, and evaluate the first complete result through the same production
gate. Until then, walking acceptance, BW19V-B material robustness, continuous
friction,
arbitrary materials/morphologies, cross-engine equivalence, release, and
physical acceptance all remain false.

At this prospective boundary, the targeted Godot freeze audit passed all 17
real entrypoints, 16 adapter starts, and three physical-bypass canaries.
Quadruped release readiness remained `24/24`, and the complete
`run_conformance.ps1 -SkipGodot` regression passed in `326.5 s`, including all
retained closures and the static stage-3 audit. No check opened a BW20F
locomotion world, created a physical attempt, or exposed a stage-3 outcome.

## Closed rejected BW20F stage-3 material locomotion

The one permitted physical attempt ran from clean pushed source
`452c11d3ca5262670615f9fb4804a956c0e0977b` and retained all `17/17` worlds at
[`<evidence-root>/balanced-wave-bw20f-material-locomotion-452c11d/report.json`](<evidence-root>/balanced-wave-bw20f-material-locomotion-452c11d/report.json).
The report SHA-256 is
`69400655be32d09404222a647601aa7a1a0856c5c4f3c0cd6a07dac3841caf03`.
The frozen evaluator rejected the result at `19/28` gates, with zero integrity
failures, no timeouts, and all receipts parsed.

All 12 BW19V-B treatments passed common integrity, mechanism, exact scale,
nonzero application, and zero SDK mismatch/failure checks. Ten passed every
ordinary walking gate. The two failures were both localized to authored
friction `0.76`: seed `23001` and seed `23003` failed only
`bounded_lateral_drift` against the frozen `0.100 m` maximum. Their last
retained world-frame torso-z samples were approximately `0.177 m` and
`0.153 m`; seed `23002` at the same profile passed, as did all nine treatments
at `0.09`, `0.37`, and `1.18`. This is a non-monotonic, seed-sensitive
mid-friction observation, not evidence that higher friction generally worsens
walking.

The same attempt discovered an independent prospective-contract defect. All
four zero-scale controls correctly reported zero residual applications,
zero applied residual velocity, and `combined_application_gate_passed=false`.
The balanced-wave base remained active, so the broad `physical_influence`
field correctly remained true. The perfect synthetic result, physical worker,
and production evaluator had incorrectly required controls to report
`combined_application_gate_passed=true` and `physical_influence=false`, which
guaranteed that real controls would fail. The intended control-conformance
layer is therefore invalid. It does not rescue the finite campaign: two
treatments independently failed an all-treatments-must-pass rule.

The immutable closure is
[`balanced_wave_bw20f_material_locomotion_closure.json`](balanced_wave_bw20f_material_locomotion_closure.json),
SHA-256
`bd18cd9a4905182673459b7b203ff7b7ae4cd5f954f00175f14fc721980bc1ef`.
Its executable audit is
[`../tests/test_bw20f_material_locomotion_closure.ps1`](../tests/test_bw20f_material_locomotion_closure.ps1),
SHA-256
`cef75f0d5782ebbadc51b8d293b8ce822d28a92d33b99b34a820f355b962f4bb`:

```text
BW20F-LOCOMOTION CLOSURE_PASS status=rejected gates=19/28 worlds=17 treatments_walking=10/12 controls_walking=3/4 integrity_failures=0 treatment_lateral_failures=2 control_contract_valid=False safety=True rerun_refused=True material_robustness=False physical_authority=False
```

BW20F may not be rerun, rethresholded, repaired in place, or reclassified.
Its outcome-exposed cells may inform development diagnostics. A validation
successor requires a new campaign/source/preregistration/evidence identity,
fresh seeds, corrected separation of zero residual influence from base-policy
physical influence, and a zero-world synthetic control receipt matching these
retained real semantics. Material robustness, continuous friction, arbitrary
materials or quadrupeds, cross-engine equivalence, release, and physical
acceptance all remain false.

Closed-state verification passed the immutable audit above and all `24/24`
quadruped release-readiness classification gates. The full
`run_conformance.ps1 -SkipGodot` pipeline passed in `269.9 s`, exercising the
BW20F closure reconstruction plus every retained campaign, selector,
integrity, adapter, ABI/versioning, developer-experience, and Rust conformance
path. It opened no BW20F world and created no second attempt.

## Closed infrastructure-invalid BW22L lateral development

`BW22L-FRESH-MATERIAL-LATERAL-DEVELOPMENT` consumed its one permitted source
identity at clean, pushed commit
`0b1883070d05c235609284ab07460233b91a208b`. The supervisor retained all 28
declared worlds—24 candidate cells, three zero-residual mechanism controls, and
one zero-friction safety cell—under:

```text
<evidence-root>\balanced-wave-bw22l-lateral-development-0b18830
```

All 28 workers exited zero, all 28 receipts parsed, no process timed out, no
process tree was killed, and the supervisor recorded zero transport/integrity
failures. The physical machinery therefore ran; the final scientific result
did not become valid. The frozen evaluator passed only `21/50` gates because
every cell failed its receipt-identity gate and the candidate outcome/metric
aggregate consequently failed.

The closure identifies three receipt-composition defects:

1. All 27 non-safety workers forwarded the inherited 26-key walking dictionary
   and computed walking status/count from it, while the frozen evaluator's
   declared decision surface expected exactly four projected walking keys.
2. `controller_coefficient` was absent from all 28 real final receipts even
   though every synthetic final receipt carried it.
3. The zero-friction safety receipt preserved correct no-actuation physics but
   did not traverse nine required BW22L common fields and identity values.

The result is permanently classified
`closed_invalid_final_receipt_composition_mismatch`. It is not a valid
`NONE` selection and not a locomotion negative. The original report SHA-256 is
`c921a2300d321da60b5f4b2f434ae5b23a7b7efaade75e22a73a8e6898bfdea6`.
The complete retained tree contains 90 files, 2,111,840 bytes, and has digest
`15f39fe4861fc075d8a394965c12a63e6ba21fae0856e1ef76b4e8a7649844e8`.

The deterministic post-hoc compiler
[`compile_balanced_wave_bw22l_posthoc_receipt_diagnostic.ps1`](compile_balanced_wave_bw22l_posthoc_receipt_diagnostic.ps1)
does not rewrite retained physical artifacts or reclassify the result. It
reproduces the frozen `21/50`, applies only the prospectively intended receipt
shape in memory, and obtains `50/50` with diagnostic selector output `NONE`.
On that non-authoritative surface, A passed the four declared walking gates in
`9/12` cells; B passed `6/12`, with four paired regressions. B therefore may
not be promoted or simply retested as the selected successor. These failures
are design evidence, not selection evidence.

The immutable closure is
[`balanced_wave_bw22l_lateral_development_closure.json`](balanced_wave_bw22l_lateral_development_closure.json),
SHA-256
`e35a93c19613a302e72800d1be9222970ef127fd0028baf8e7440e620e2929e5`.
Its executable audit is
[`../tests/test_bw22l_lateral_development_closure.ps1`](../tests/test_bw22l_lateral_development_closure.ps1):

```text
BW22L LATERAL_DEVELOPMENT_CLOSURE_PASS status=infrastructure-invalid worlds=28 parsed=28 process_failures=0 gates=21/50 cell_gates=0/28 receipt_shape_defects=3 reconstructed=50/50 diagnostic_selector=NONE paired_regressions=4 selection_authority=False validation_authority=False physical_authority=False rerun_refused=True
```

A successor requires a new campaign, gate, source, preregistration, fresh
material values, fresh seeds, and evidence identity. Before physics, actual
real-shaped candidate, control, zero-friction safety, and negative walking
receipts must pass through the complete production evaluator. Walking
projection/count semantics must be single-sourced, coefficients must be
present in every final receipt, and canaries must reproduce all three BW22L
defect families. Walking acceptance, material robustness, continuous friction,
arbitrary quadrupeds, turning, cross-engine equivalence, release, and completed
SDK authority remain false.

## BW23Y development policy and zero-world guard

sporespore_balanced_wave_bw23y_b_v1 is an unselected development policy that
changes only BW15F-B's yaw-error-to-stride gain from 1.3 to 1.0. The
core/examples/inspect_policy_profile.rs utility emits its canonical zero-world
profile receipt. Run the complete host-selected debug-artifact and authority
guard from PowerShell:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File sdk\run_balanced_wave_bw23y_yaw_gain_development_preflight.ps1
~~~

The expected marker begins BW23Y_YAW_GAIN_DEVELOPMENT_PREFLIGHT_PASS and ends
with worlds=0 outcomes_exposed=False physical_authority=False. The development
probe accepts only already-exposed BW22L values/seeds and writes no retained
evidence. Three admissible real-physics diagnostics passed 2/3 walking cells
versus the exposed baseline's 1/3, while worsening precision on the
already-passing cell. This mixed signal authorizes only design of a fresh
paired successor campaign, not policy promotion or a robustness claim.

## BW24M zero-world fresh-material declaration

BW24M prospectively reserves Godot/Jolt authored-friction values `0.59`,
`0.71`, and `0.83` and future locomotion seeds `26011`-`26014`. The grid is
outcome-unexposed but prior-informed, not an independent validation sample.
Run its zero-world fixture and declaration checks from PowerShell:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File sdk\run_balanced_wave_bw24m_material_declaration_preflight.ps1
pwsh -NoProfile -File tests\test_bw24m_material_declaration.ps1
~~~

Both commands must report zero worlds and `physical_authority=False`. Stage
zero only proves that the declaration, exact host, source hashes, fixture
allowlist, downstream BW25Y A/B identity, and claim boundary are executable.
It cannot characterize a coefficient or authorize walking. Stage one remains
blocked until its complete production gate, synthetic canaries, one-shot
supervisor, source freeze, and freeze audit are committed and pushed.

BW24M stage one is also frozen prospectively. Its production evaluator passes
a perfect serialized result at `19/19` and rejects ten mutated canaries; the
Godot authorization, wrong-token, and direct-bypass paths open zero worlds.
Run the complete prospective check with:

~~~powershell
pwsh -NoProfile -File sdk\run_balanced_wave_bw24m_material_characterization.ps1 -PreflightOnly
pwsh -NoProfile -File tests\test_bw24m_material_characterization_freeze.ps1
~~~

The only eventual physical form is the same supervisor with `-RunPhysical`
and the exact new durable evidence-root leaf. Do not invoke that form unless
the committed source is clean, pushed, equal to live GitHub, and complete
conformance has passed. The preflight/freeze alone create no material profile
or walking authority.

## BW25Y paired yaw-development stage zero

BW24P has published the exact three BW24M profiles, so the distinct BW25Y
manifest is now declared. This stage opens no physics worlds. Run its complete
declaration audit from PowerShell:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File tests\test_bw25y_yaw_development_declaration.ps1
~~~

For the native zero-world portion alone, run:

~~~powershell
pwsh -NoProfile -File sdk\run_balanced_wave_bw25y_yaw_development_declaration_preflight.ps1
~~~

The declaration freezes exact BW15F-B (`yaw_error_stride_gain_per_rad=1.3`)
against exact unselected BW23Y-B (`1.0`) over three published material profiles
and four sealed seeds. The planned matrix is 24 paired candidate worlds, three
material-matched zero-residual controls, and one zero-friction safety world.
All controller conditioning branch counts remain zero.

Expected terminal markers include `BW25Y_AUTHORITY_PASS`,
`BW25Y_DECLARATION_PREFLIGHT_PASS`, and `BW25Y_DECLARATION_PASS`, each with
`worlds=0` or `worlds_opened=0` and `physical_authority=False`. The stage-one
gate remains mandatory: it must pass real-shaped candidate, control, safety,
and negative-walking receipts through the exact future production evaluator and
reject all three BW22L receipt-composition defect families. No physical BW25Y
run is authorized by this declaration alone.

The zero-world production evaluator and real-shaped final-receipt parity layer
are also active:

~~~powershell
pwsh -NoProfile -File tests\test_bw25y_yaw_development_gate.ps1
pwsh -NoProfile -File tests\test_bw25y_yaw_development_receipt_parity.ps1
~~~

The first command must end with `BW25Y_YAW_DEVELOPMENT_GATE_PASS` at `50/50`
gates and `28` rejected canaries. The second must end with
`BW25Y_RECEIPT_PARITY_PASS`, proving all 28 realistic synthetic receipts use the
same final composer, the three BW22L defect families fail closed, and a valid
negative walking cell remains infrastructure-valid. These commands open zero
worlds. A physical worker and source freeze are still required before launch.

The preregistration reserves one exact infrastructure-replacement slot per
cell (`BW25Y-R1::<cell_id>`). It is usable only if the cell has no complete
receipt; complete pass and failure receipts are final. Replacement inputs and
evaluation are byte-identical, all partial artifacts remain retained, and no
outcome-based retry is permitted. Retained physics stays serialized on this
host unless a separate isolation contract is prospectively proven.

## BW25Y immutable physical closure

The one permitted BW25Y physical identity has now run and is closed
infrastructure-invalid. It retained all `28` primaries plus the `28`
prospectively reserved replacements, for `56` real Godot/Jolt process streams.
Every stream hit an inherited post-world receipt-constructor error because
BW20F requires `cell.cohort` and BW25Y did not declare it. All `56` partial raw
receipts were incorrectly marked complete, failed exact supervisor identity
validation, and yielded zero complete final receipts. The selector never ran;
this is neither a locomotion negative nor a valid `NONE` selection.

Run the immutable closure audit from PowerShell:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File tests\test_bw25y_yaw_development_closure.ps1
~~~

Expected terminal marker begins
`BW25Y_YAW_DEVELOPMENT_CLOSURE_PASS status=infrastructure-invalid-incomplete`
and ends with `physical_authority=False rerun_refused=True`. The retained
evidence root is
`<evidence-root>\balanced-wave-bw25y-yaw-development-14c1c34`;
its exact `227`-file tree SHA-256 is
`8d28c9ddef2335954edfc59d4d586bca1c40f77792afcfbe012d198421c8eff8`.

The successor must use a new campaign, gate, source identity,
preregistration, values, and seeds. Before physics, its zero-world preflight
must execute the actual inherited receipt constructor for every role, derive
raw completeness from the exact schema and stderr, traverse raw validation and
the production evaluator end to end, handle an empty candidate set without an
evaluator exception, and hold a cross-process operation lock against
conformance. BW25Y itself may not be repaired, rerun, scored, or selected.

## BW26I actual worker-receipt route commissioning

BW26I is a distinct zero-world infrastructure campaign, not a repair or replay
of BW25Y. It supplies an explicit fixture cohort before entering the shared
route, while the shared production helper refuses to manufacture a missing
campaign declaration. Every one of the inherited `24` candidate, `3` control,
and `1` safety roles then traverses the exact BW25Y-to-BW20F post-world
constructor using a real-shaped synthetic completed-world summary.

Run the complete proof from PowerShell:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File tests\test_bw26i_actual_worker_receipt_route.ps1
~~~

The expected terminal marker is:

~~~text
BW26I_ACTUAL_WORKER_RECEIPT_ROUTE_PASS raw=28 final=28 constructors=28 gates=50/50 negative_walking_valid=True missing_key=True forged_complete=True script_error_veto=True attempt_identity=True empty_matrix_structured=True worlds=0 physical_authority=False
~~~

The supervisor independently recomputes every raw receipt's structural
completeness from the contract and worker stderr; it does not trust the
worker's boolean. It rejects a missing required key, a forged `true` flag, a
worker `SCRIPT ERROR`, and wrong world-attempt identity before composition.
It then calls the exact BW25Y final composer and all `50` production gates.
A walking-negative canary remains infrastructure-valid, while an empty
candidate matrix returns a structured terminal infrastructure failure without
calling or throwing from the frozen evaluator.

This closes only the constructor/completeness/composition/evaluator boundary.
The synthetic summaries report hypothetical completed worlds to exercise the
constructors, but the process actually builds zero worlds, inserts zero nodes,
and exposes no locomotion outcome. BW26I creates no walking, turning, material,
selection, validation, or release authority. The cross-process experiment
lock and durable source-bound full-Godot conformance attestation remain open
preconditions for a new physical campaign.

### BW26I is closed infrastructure-invalid

Do not use the former `BW26I_ACTUAL_WORKER_RECEIPT_ROUTE_PASS` marker as current
commissioning authority. An audit of the pushed source at
`e7d55858c999ed48554fbee210ddb65394bff742` reproduced a contradiction: the
outer result said `candidate_selected=false` but exposed `BW25Y-B` and
`development_selection_authority=true`, matching its nested production
evaluation. The synthetic fixture itself created that result by failing every
BW25Y-A arm on one walking gate and giving BW25Y-B better comparison metrics.

Run the authoritative closure instead:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File tests\test_bw26i_actual_worker_receipt_route_closure.ps1
~~~

Expected marker:

~~~text
BW26I_ACTUAL_WORKER_RECEIPT_ROUTE_CLOSURE_PASS status=infrastructure-invalid synthetic_selection=BW25Y-B nested_authority=True claimed_pass_marker=True worlds=0 locomotion_negative=False physical_authority=False
~~~

The closure grants no candidate, walking, material, validation, or physical
authority. A distinct successor must make the perfect fixture neutral, require
`NONE`, veto any nested selection authority, and distinguish residual-overlay
influence from active base-controller influence.

## BW26J actual-worker receipt authority commissioning

BW26J is the distinct zero-world correction; it does not edit or reinterpret
closed BW26I. Run it from PowerShell:

~~~powershell
Set-Location <repo>
pwsh -NoProfile -File tests\test_bw26j_actual_worker_receipt_authority.ps1
~~~

Expected terminal marker:

~~~text
BW26J_ACTUAL_WORKER_RECEIPT_AUTHORITY_PASS raw=28 final=28 constructors=28 gates=50/50 selected=NONE authority=False negative_walking_valid=True missing_key=True forged_complete=True script_error_veto=True attempt_identity=True empty_matrix_structured=True selection_authority_veto=True control_overlay_semantics=True worlds=0 physical_authority=False
~~~

The neutral fixture gives A and B identical walking and comparison outcomes,
so the exact frozen production evaluator selects `NONE`. The selection canary
then makes A worse, confirms that the nested evaluator selects B, and requires
the BW26J wrapper to fail with `BW26J_SYNTHETIC_SELECTION_AUTHORITY` while all
outward selection and authority fields remain false. Control receipts also
show the residual overlay inactive and the portable base active as separate
facts.

This is a positive infrastructure result only. It builds zero worlds and
creates no candidate, walking, turning, material, validation, cross-engine,
arbitrary-quadruped, release, or physical authority. A shared cross-process
operation lock and durable source-bound full-Godot conformance attestation are
still required before a fresh physical campaign.

## Physical/conformance operation lock and full-conformance attestation

The executable contract is
`sdk/locomotion_operation_attestation_contract.json`. Every canonical
conformance run now holds the machine-wide mutex
`Global\SporeSpore.Locomotion.PhysicalConformance.Serial.v1`; every new
qualified physical runner must acquire the same lock with role `physical`.
Run the cross-process audit with:

~~~powershell
pwsh -NoProfile -File tests\test_locomotion_operation_lock.ps1
~~~

Run the whole-attestation synthetic gate with:

~~~powershell
pwsh -NoProfile -File tests\test_locomotion_full_conformance_attestation.ps1
~~~

After the safeguard source is committed, pushed, and clean, publish a real
attestation only through a complete Godot-including conformance run:

~~~powershell
pwsh -NoProfile -File sdk\run_conformance.ps1 `
  -DurableAttestationOutput `
  '<evidence-root>\<new-root>\attestation.json'
~~~

`-SkipGodot`, dirty/unpushed source, live-GitHub mismatch, source drift,
overwrite, and paths outside the durable evidence root all fail before
publication. The receipt binds the source tree, runner and safeguard blobs,
Godot identity, PowerShell runtime identity, global lock, timestamps, and false
scientific claims. The serialized temporary file must independently verify
before the atomic publication move. A future
physical launcher verifies the exact current source/host against that receipt
and records its path and SHA-256.

Neither the lock nor an attestation is walking evidence. They prevent overlap
and prove which infrastructure passed; a separate frozen physical campaign is
still required for every locomotion claim.

The targeted safeguard preflights build zero worlds. Complete conformance may
still run ordinary regression-test physics; it does not consume a one-shot
campaign identity or expose a new scientific outcome, and the attestation
schema requires both of those claims to remain false.

### Conformance observability phase one

Every canonical invocation now creates a durable observation root under
`SporeSpore_Evidence\conformance-runs`. The executable contract and helper are
[`conformance_observability_contract_v1.json`](conformance_observability_contract_v1.json)
and [`conformance_observability.ps1`](conformance_observability.ps1). They split
the unchanged full-cold route into eight ordered stages, record monotonic
duration plus UTC bounds, write one create-only JSON receipt per stage, retain
the full transcript, retain a bounded excerpt on caught failure, and publish
each retained object into the existing SHA-256 artifact store.

The canonical source test is:

~~~powershell
pwsh -NoProfile -File tests\test_conformance_observability.ps1
~~~

It exercises the eight-receipt success path and six fail-closed controls with
zero worlds. Production runs print one compact `CONFORMANCE_STAGE_RECEIPT` per
completed stage, `CONFORMANCE_STAGE_FAILURE` for a caught failing stage, and a
final `CONFORMANCE_RUN_RECEIPT` containing the durable paths and digests.

This phase does **not** make conformance cacheable. Every receipt says
`observed_not_transitive` and `disabled_uncommissioned`; lookup, reuse,
historical-audit waiver, physical authority, scientific authority, and release
authority are false. The existing complete run remains mandatory until a later
contract proves the transitive dependency and host key, invalidation mutation
controls, authorization safety kernel, and a complete cold equivalence
baseline.

The first clean-pushed production observation is run
`20260810T211106Z-b1627db3-656c086d6125444ca5dd07dd02bbe2f0`, created by
`sdk/run_conformance.ps1 -SkipGodot` at source
`b1627db3882cdf13f6c2b3af9a43de55e4dccf60`. It passed in
`1597.2312833 s`. The aggregate receipt SHA-256 is
`42b61999b4649d7d4a7c88c9a3aba528eabef1031cbb59a19cabcfa951ae16c1`;
the transcript SHA-256 is
`48e7bed60c63d4399ca94efdc46ddf8f97499031f71ccbe9b15cebaba4949262`.
Independent verification reproduced the transcript, all eight stage receipts,
and the run receipt from CAS and validated all ten manifests. This is a
canonical no-Godot executed baseline only. It does not authorize reuse and is
not the complete Godot-inclusive cold-equivalence gate.

### Conformance dependency-key candidate

[`conformance_dependency_contract_v1.json`](conformance_dependency_contract_v1.json)
and [`conformance_dependency_key.ps1`](conformance_dependency_key.ps1) define
CDK1, the first executable candidate for the later transitive cache key. The
focused zero-world gate is:

~~~powershell
pwsh -NoProfile -File tests\test_conformance_dependency_key.ps1
~~~

CDK1 canonicalizes declared files by normalized relative path in ordinal order
and hashes path, byte length, and exact bytes. The live repository candidate
also binds HEAD/tree, the Git tree listing, origin, remote, dirty/untracked
status, tracked checkout bytes, and statically referenced environment values.
Raw environment values never enter a receipt. Generic declared-directory
inventories provide the same mutation-sensitive primitive for later runtime
and evidence manifests.

The test proves root/order invariance, file-content invalidation, missing/path-
escape/case-collision refusal, environment invalidation and redaction, dynamic
lookup classification, and runtime mutation. The canonical runner invokes it
in stage 1. Production candidate construction also happens inside stage 1,
after the transcript begins, so construction failure is retained as a failed
stage/run; the observability audit has a synthetic control for that path.

This is not a cache. The current candidate declares runtime and evidence
inventories incomplete. It retains a complete process-environment digest, so
nonliteral lookup values are conservatively covered; constant-flow resolution
or explicit per-audit declarations remain a reuse-granularity refinement.
`transitive_dependency_key_complete`, lookup, reuse, historical waiver,
physical authority, and release authority remain false. Do not suppress a test
or historical audit using a CDK1 digest.

The first clean-pushed probe at `d3ac713` found that two real referenced
environment values were present but empty. The byte-hash helper rejected the
zero-length array non-terminatingly, so its printed `b901b422...` candidate is
invalid and was never eligible for reuse. The corrected gate pins SHA-256 of
empty bytes to `e3b0c442...` and distinguishes present/nonempty,
present/empty, and missing values. This negative is infrastructure evidence;
it changes no conformance, physics, or release result.

CDK1 also builds a referenced-CAS inventory. It scans tracked text source for
explicit `artifacts/sha256/<digest>` paths and SHA-256 literals, selects only
objects that exist in the canonical artifact store, and revalidates each
selected payload and manifest. The inventory contains content digest, byte
length, root-independent payload path, and manifest hash. An explicit missing
object or selected-object corruption fails; appending an unrelated valid CAS
object leaves the inventory unchanged.

The clean published `af8d440` measurement selects `568/900` CAS objects and
`354994572` payload bytes. Complete source, process-environment, and referenced-
CAS construction took `31.951019 s`; source eligibility was true. Its digest
`sha256:d0c86d32c49025d6b9f8ed2df2dd516090e0ea6cf8bd1340c7524db3b253f002`
is still `candidate_incomplete_cache_disabled`. Non-CAS evidence paths remain
incomplete, so transitive completeness, lookup, reuse, and all authority are
false.

### Per-audit external-dependency candidate

[`conformance_audit_dependency_contract_v1.json`](conformance_audit_dependency_contract_v1.json),
[`conformance_audit_dependency_registry_v1.json`](conformance_audit_dependency_registry_v1.json),
and [`conformance_audit_dependency.ps1`](conformance_audit_dependency.ps1)
define CAD1. Its focused zero-world gate is:

~~~powershell
pwsh -NoProfile -File tests\test_conformance_audit_dependency.ps1
~~~

CAD1 represents non-CAS reads as exact files, complete directory trees, or
bounded immediate-directory queries. The last shape captures checks such as
"all completed attempts whose directory begins with this campaign prefix"
without making an unrelated evidence append invalidate the audit. Missing
trees, escaping paths, reparse points, content changes, and matching query
changes fail or invalidate as appropriate.

Historical Git objects are a fourth shape. The batch reader consumes raw
commit/tree bytes, recomputes each native Git SHA-1 identity including its
type/size header, and records raw-content SHA-256. Object order is canonical;
missing objects and wrong types fail closed. This avoids assuming that a named
historical commit exists merely because the current checkout is valid.

The initial registry reconciles the R23D13 closure audit against the `95`-audit
CEP1 inventory and binds its `26`-file / `35559068`-byte evidence tree, exact
full-conformance attestation, and same-lineage completion query. Its original
closure tree digest and CAD1's canonical inventory digest are separate named
projections. The registry is intentionally partial: `1` audit is registered,
`0` are complete, and `94` are unregistered.

A development-only command-proxy run left the unmodified R23D13 audit passing
and observed `331` path calls / `163` unique durable-evidence command paths.
That parent observation cannot see nested PowerShell, native child processes,
direct .NET file APIs, module-qualified bypasses, or dynamic dot-source
resolution. An attempted Windows kernel FileIO trace failed with access denied
before recording in the non-elevated session. Those are declared gaps, not
assumed absences. CAD1 is bound into CDK1's evidence digest, but complete audit
count, evidence completeness, lookup, reuse, physical authority, and release
authority remain zero/false.

The CAD1 boundary is clean-pushed at `c90f54a`. Its clean combined CDK1
candidate completed in `91.852412 s`; an immediate isolated CAD1 measurement
completed in `2.7458226 s` and reproduced audit-dependency digest
`sha256:9fa4b58183b7b9c3dd55483b31c8da47d33f295be7894d114405e699e29fa9e9`.
One combined timing is not enough to attribute disk/cache/antivirus variance
inside the wider `355 MB` CAS scan. The combined candidate remained
`candidate_incomplete_cache_disabled` with `0/95` audits complete.

The R23D13 entry now binds its exact frozen commit and tree as raw-rehashed Git
objects, so its external evidence dimension is complete. A first correct but
overbroad `git fsck` test took `81.1 s`; one binary-safe batch transport reduced
the complete focused gate to `6.0302049 s`. The isolated live candidate took
`1.9559036 s`, with aggregate inventory
`sha256:5d25ac8741cd85d47f44520bdbab5c66de9567d9250e9a76a58b7db8a9af0e47`
and Git-object inventory
`sha256:1b5fd93b2ee2059b79110c0d41db060f296f6e9d51caf64a8a43ffb6f9652c94`.
Runtime and complete transitive closure remain false, so complete audits and
reuse remain `0`/disabled.

The raw-object boundary is clean-pushed at `f645d57`. CAD1 reproduced in
`1.3773919 s`; the complete clean candidate took `49.5523506 s` and produced
key `sha256:a79db8d7efeb237fd6670e5edd9ee7a103b9457802937c00546c1fba957852a0`.
Source eligibility and external-evidence completion for R23D13 were true, while
complete audit count, lookup, reuse, and all authority stayed zero/false.

### Declared runtime-profile candidate

[`conformance_runtime_profile_contract_v1.json`](conformance_runtime_profile_contract_v1.json),
[`conformance_runtime_profile_registry_v1.json`](conformance_runtime_profile_registry_v1.json),
and [`conformance_runtime_profile.ps1`](conformance_runtime_profile.ps1)
define CRP1. Its focused zero-world audit is:

~~~powershell
pwsh -NoProfile -File tests\test_conformance_runtime_profile.ps1
~~~

The first profile binds the registered R23D13 parent audit to the files actually
seen in development module snapshots plus PowerShell boot configs/manifests:
`84` PowerShell files / `83367040` bytes and `7` Git-shipped files /
`6730128` bytes. It also binds PowerShell/runtime identity, Git version and exec
path, and the system, global, and repository Git configuration file bytes.
Configuration paths are role-tokenized and raw configuration values are never
retained.

The focused gate proves install-root independence, runtime mutation, missing-
file refusal, and config-value redaction. A development measurement completed
the profile in `2.9167256 s`, producing runtime inventory
`sha256:356610abea075b44ccd9d8892a465c3c516f53d448041d1338d60d7679b3cffa`.
This is one partial profile, not runtime closure. Parent-process snapshots do
not prove every nested/native child read, Windows system DLL/kernel semantics,
locale/filesystem/scheduling semantics, Git object availability, or any of the
other `94` CEP1 audit profiles. CRP1 is bound into CDK1's runtime digest while
profile completion, host completion, lookup, reuse, and all authority remain
false.

CRP1 is clean-pushed at `82c8ed2`. The clean runtime profile reproduced in
`2.5193855 s`; the wider combined candidate completed in `77.3636533 s` with
key `sha256:13c9688857b97ca1e4a7c9ab52795310a85471666fcf5da3aa287dc4d5b45be3`.
Source eligibility was true, but complete profiles/audits stayed `0/0` and all
execution or authority edges stayed false.

CRP2 completes the one exact R23D13 parent/closed-child route. It binds `7`
measured source files, `86` PowerShell files / `85403280` bytes, `7` Git files
plus three config roles, `59` Windows modules / `57481752` bytes, `2` versioned
Defender modules / `2506800` bytes, and explicit Windows/.NET/culture/timezone/
encoding/NTFS semantics. Any measured source or host-semantic drift fails the
profile closed. The child is scoped to the retained refusal before Git,
engines, models, workers, or worlds.

The focused CRP2 gate and CAD1 integration now report one complete runtime
binding and one complete audit input manifest. This does not enable cache use:
the other `94` audits have no complete profile/manifest and cold executed-versus-
reused equivalence is still absent. Aggregate runtime/host completeness,
lookup, reuse, physical authority, and release authority remain false.

CRP2 is clean-pushed at `ff05c7e`. The exact-source runtime profile resolved in
`2.1843774 s` with digest
`sha256:2965277151b452da68cced45381c32529f6d5654d76fd93caf5e40493e4c33b6`;
CAD1 resolved in `0.6983410 s` with digest
`sha256:c9b00f25174e87e6f935c3d04806b79d8ae1175fd415bf44a023093d87605c6b`.
The conservative combined candidate took `34.6474164 s` and produced key
`sha256:7228fff072a125b7008853ed3badf85f8d8ee16de3000a2c1f1bbc634c5cb5ad`.
Source eligibility was true; runtime/evidence completeness and every execution
or authority edge were false.

### Prospective content-addressed execution receipt

[`conformance_execution_receipt_contract_v1.json`](conformance_execution_receipt_contract_v1.json),
[`conformance_execution_receipt.ps1`](conformance_execution_receipt.ps1), and
[`run_conformance_execution_receipt_commissioning.ps1`](run_conformance_execution_receipt_commissioning.ps1)
define CER1 for the exact closed R23D13 audit. Its input key combines the
complete CAD1 entry, complete CRP2 profile, complete process-environment
digest, canonical PowerShell command/executable, and exact receipt machinery.
Executed stdout/stderr and the create-only record are independently retained in
CAS; verified read-back contains no audit invocation.

Run the zero-world control surface with:

~~~powershell
pwsh -NoLogo -NoProfile -File tests\test_conformance_execution_receipt.ps1
~~~

The gate covers key/environment invalidation, canonical LF, exact result
projection, failed/duplicate refusal, and missing/corrupt record or payload
bytes. At the prospective freeze, CER1's real `Execute` and `ReadBack` modes
still had to run in distinct cold processes from clean pushed source.
Production cache lookup, result reuse, audit waiver, physical authority, and
release authority were hard false pending both that observation and a
separately frozen successor.

CER1-C1 is retained by
[`conformance_execution_receipt_cold_equivalence_closure_v1.json`](conformance_execution_receipt_cold_equivalence_closure_v1.json)
and audited by
[`../tests/test_conformance_execution_receipt_commissioning.ps1`](../tests/test_conformance_execution_receipt_commissioning.ps1).
From clean source `ddc3d5d`, the executed process invoked R23D13 once and took
`12.6491433 s`; a distinct read-back process invoked it zero times and took
`6.1857223 s`. Both reproduced input key `sha256:567ebdff...2431b6`, record
`sha256:2cc456d3...cd89c6`, and result `sha256:ebb56767...e2c34c0`.
This `2.044893x` single-audit observation permits a successor design only.
CER1 still cannot suppress an invocation.

[`conformance_execution_receipt_adoption_decision_v1.json`](conformance_execution_receipt_adoption_decision_v1.json)
records why no such R23D13 successor was adopted. A clean direct process took
`5.2191931 s`; read-back took `6.1857223 s`, or `18.5187%` longer after exact
key verification. Its executable audit keeps the direct canonical invocation
and requires the next target to be materially more expensive or batch-
amortized.

### Historical closure-audit duration profiler

[`conformance_audit_profiler_contract_v1.json`](conformance_audit_profiler_contract_v1.json)
and [`measure_conformance_audit_durations.ps1`](measure_conformance_audit_durations.ps1)
define CAP1. The profiler serializes the exact CEP1 audit inventory, verifies
each source digest, CAS-retains stdout/stderr, preserves failures, and writes a
create-only duration ranking. Its focused zero-world gate is:

~~~powershell
pwsh -NoLogo -NoProfile -File tests\test_conformance_audit_profiler.ps1
~~~

The full profiler is deliberately outside ordinary conformance and must use
clean pushed source plus the durable evidence root. Its output is development
target selection only; dependency/runtime completeness, cache lookup, reuse,
physical authority, and release authority remain false.

CAP1-C1 is frozen by
[`conformance_audit_profiler_closure_v1.json`](conformance_audit_profiler_closure_v1.json)
and audited by
[`../tests/test_conformance_audit_profiler_commissioning.ps1`](../tests/test_conformance_audit_profiler_commissioning.ps1).
All `95` audits passed in `2274.4750496 s`; all `190` streams and the profile
reproduce from CAS. The top five consume `44.3596%`, while the five material-
profile publication audits consume `40.0430%`; BW27P ranks first at
`350.1956976 s`.

The host wrapper timed out while the profiler survived and completed. CAP1
retained streams incrementally but durations only in the final profile, so
CAP2 must add immediate create-only duration receipts and verified resumption
before another full sweep. The ranking grants no cache or release authority.

CAP2 is declared by
[`conformance_audit_profiler_contract_v2.json`](conformance_audit_profiler_contract_v2.json)
and implemented by
[`measure_conformance_audit_durations_v2.ps1`](measure_conformance_audit_durations_v2.ps1).
It CAS-publishes an immutable run manifest, then publishes each audit's outputs
and duration receipt before atomically extending a contiguous create-only
prefix. Production start/resume also require the expected origin URL and live
`main` equal to the clean local freeze. Resume requires the identical complete
input key and verifies every
manifest, receipt, and output CAS object before invoking only the suffix.

[`../tests/test_conformance_audit_profiler_resume.ps1`](../tests/test_conformance_audit_profiler_resume.ps1)
covers environment and selection drift, a concurrent lease, manifest/receipt/
payload corruption, an ordinal gap, pending-directory non-authority, and
completed-run refusal. After this implementation is clean and pushed,
[`run_conformance_audit_profiler_resume_commissioning.ps1`](run_conformance_audit_profiler_resume_commissioning.ps1)
performs the frozen two-child-process stop/resume commissioning. The prospective
implementation itself carries no commissioned, cache, waiver, physical,
scientific, or release authority; only a retained closure can add the bounded
process-recovery claim.
The CAP1 executable now refuses new non-test profiles, while its test-only
regression path and frozen CAP1-C1 evidence remain intact; new durable profiles
must use CAP2.

CAP2-C1 is now frozen by
[`conformance_audit_profiler_resume_closure_v1.json`](conformance_audit_profiler_resume_closure_v1.json)
and audited by
[`../tests/test_conformance_audit_profiler_resume_commissioning.ps1`](../tests/test_conformance_audit_profiler_resume_commissioning.ps1).
From clean pushed `6be80ba`, the first child published one receipt and stopped;
the second verified that prefix, invoked only the remaining audit, and finished
`2/2`. Eight CAS references (seven unique objects) reproduce. CAP2 is now the
commissioned path for future development profiles and controlled-interruption
resume. It does not authorize cache lookup, audit skipping, physics, or release,
and it did not empirically induce an OS/host crash.

[`conformance_transitive_historical_audit_tha1_closure_v1.json`](conformance_transitive_historical_audit_tha1_closure_v1.json)
closes THA1 negative after its eligible run exposed legacy direct-path visibility
checks. [`conformance_transitive_historical_audit_contract_v2.json`](conformance_transitive_historical_audit_contract_v2.json)
and [`conformance_transitive_historical_audit_gate_v2.ps1`](conformance_transitive_historical_audit_gate_v2.ps1)
declare THA2. The canonical runner still invokes BW27P as the single root for
its existing BW27M/BW24P/BW24M/BW22M/BW20F publication lineage. Seven duplicate
top-level launches remain absent, while BW20F characterization remains direct.
An exact declaration-only registry supplies legacy coverage visibility; the
gate proves its variable is never consumed and verifies the eight source hashes,
ordered graph, retained ten-line CAP1 stdout/CAS witness, predecessor negative,
root failure handling, and ten mutations.

CAP1 durations estimate `700.392132 s` removed from the `1597.2312833 s`
no-Godot baseline (`43.8503891%`, estimated `1.7809562x`). This is a prospective
hypothesis only. THA2's clean pushed complete run passed all eight stages. The
target campaign-closure stage improved by `169.9574578 s` / `23.4331038%`, so
the graph and declaration-only registry are commissioned. The full suite was
`55.1866869 s` / `3.4551469%` slower than the older baseline, so the whole-suite
speedup and `43.8503891%` estimate are rejected. The exact bounded result is in
[`conformance_transitive_historical_audit_tha2_closure_v1.json`](conformance_transitive_historical_audit_tha2_closure_v1.json)
and its executable gate. It performs no cache read-back and grants no waiver,
physical, scientific, or release authority.

### Physical-authorization safety-kernel candidate

[`conformance_authorization_kernel_contract_v1.json`](conformance_authorization_kernel_contract_v1.json),
[`conformance_authorization_kernel_manifest_v1.json`](conformance_authorization_kernel_manifest_v1.json),
and [`conformance_authorization_kernel.ps1`](conformance_authorization_kernel.ps1)
define CAK1. Its focused zero-world audit is:

~~~powershell
pwsh -NoProfile -File tests\test_conformance_authorization_kernel.ps1
~~~

The manifest declares `12` permanent safeguards and binds every one to an
ordered identity, invocation kind/arguments, tracked source path and digest,
and canonical-runner marker. The surface covers authority boundaries,
reproducible builds, operation locking, CAS/provenance and attestation,
result/physical-receipt integrity, shared adapter/ABI/language behavior, and
release-claim refusal. Canonical conformance now invokes the existing
`test_quadruped_sdk_release_readiness.ps1` gate instead of leaving that
fail-closed package/publication test outside the full route.

Campaign worker, evaluator, and supervisor negative controls are required but
not hard-coded to the closed R23D13 lineage. A future distinct successor must
bind all three with exact sources, tests, and retained refusal receipts. The
focused audit rejects manifest omission/reordering/duplication, path escape,
missing runner integration, unsafe `-RunPhysical` or `-SkipGodot` arguments,
premature campaign binding, and authority inflation. CDK1 includes the CAK1
inventory digest.

All `12` declared gates passed once as a dirty-tree development surface in
`193.8 s`, with zero worlds. That does not satisfy the future per-gate receipt
or clean cold-equivalence contract. `global_gate_execution_complete`, all
campaign bindings, cold equivalence, commissioning, cache lookup, reuse,
physical launch, and release authority remain false.

The implementation is clean-pushed at `917e7fa`. CAK1 alone resolved in
`2.3774189 s` with inventory
`sha256:0395567d2ac2d03c67fde413b7b9ea3b86cc3602f8751e3a4e4a6a4a2a4c1bbd`.
The combined clean CDK1 candidate took `97.5874481 s`, bound `3151` tracked
files / `41255478` bytes, and produced key
`sha256:608ca1d8b3239a27db0df359c4309ecd8bf671cb5220f904318aa4d34172eb88`.
The kernel digest matched the key input, but complete audits/profiles stayed
`0/0` and all execution or authority edges stayed false.

Do not use the retained `3a52c764` A1 attestation for a physical launch. Full
conformance exited zero, but the serialized receipt independently failed its
duration invariant after PowerShell converted ISO timestamps to `DateTime`.
Its immutable SHA-256 is
`6c638a8e0dca553063add361d0c1630c78fcbf2d2d54e9c5f9cba6fe6026d9c0`.
The corrected schema-v2 verifier is type-aware, binds the PowerShell runtime,
and must verify the real serialized temporary file before publishing a new
path.
The historical V1 file is bound by
[`locomotion_full_conformance_attestation_v1_closure.json`](locomotion_full_conformance_attestation_v1_closure.json)
and
[`../tests/test_locomotion_full_conformance_attestation_v1_closure.ps1`](../tests/test_locomotion_full_conformance_attestation_v1_closure.ps1).
Normal conformance reproduces the historical verifier failure without altering
the retained JSON before exercising schema v2.

The distinct V2 commissioning run succeeded from clean-pushed source
`0513be82370604e958c2ff1e563e444b70746b72`. Full Godot-including conformance
completed in `855.3993872 s`; the atomically published `3562`-byte artifact is:

```text
<evidence-root>\full-godot-conformance-v2-0513be82-20260802T140317Z\attestation.json
SHA-256 e4f9386964c213ff686e151357ae9e8928391ca5a5ad35fb60851db42aeae910
```

Production postpublication verification passed with no failure codes. The
artifact binds the exact source/tree, four safeguard blobs, Godot identity,
PowerShell identity, operation-lock receipt, duration, and all-false claim
schema. Post-run physical-role acquisition/release and a second acquisition
succeeded without abandoned ownership. The result commissions the safeguard;
it does not establish walking or any other physical claim.

[`locomotion_full_conformance_attestation_v2_closure.json`](locomotion_full_conformance_attestation_v2_closure.json)
and
[`../tests/test_locomotion_full_conformance_attestation_v2_closure.ps1`](../tests/test_locomotion_full_conformance_attestation_v2_closure.ps1)
freeze the exact artifact and replay its historical verifier. Normal
conformance runs this audit before the current schema-v2 synthetic preflight.
Because the closure changes source, the successful receipt is historical and
cannot authorize a physical launcher built from a later commit. Freeze and
clean-push the next physical successor, issue a new matching full-Godot
attestation, then launch under the same mutex.

## BW27M prospective material successor

[`balanced_wave_bw27m_fresh_material_preregistration.json`](balanced_wave_bw27m_fresh_material_preregistration.json)
reserves the next distinct authored material grid `0.62/0.74/0.86` and future
BW28Y locomotion seeds `27011–27014`. The declaration opens zero worlds and
does not itself authorize material characterization. Its exact parent-Git
freshness and nonclaim audit is
[`../tests/test_bw27m_material_declaration.ps1`](../tests/test_bw27m_material_declaration.ps1),
which is integrated into canonical conformance.

The required order is BW27M fixture/gate/supervisor freeze, clean push, matching
V2 full-Godot attestation, ten-world adapter characterization, zero-world
profile publication, and only then a distinct BW28Y paired yaw-development
freeze. The planned controller contrast retains baseline yaw authority `1.3`
versus lower authority `1.0`; values, seeds, fixtures, schedules, residual
scale, and acceptance gates are paired. Neither BW23Y nor invalid BW25Y selected
that lower-yaw policy, and no robustness claim exists before a later unseen
validation cohort.

### BW27M zero-world fixture and production-gate checks

Run the complete synthetic production gate:

```powershell
pwsh -NoProfile -File tests\test_bw27m_material_characterization_gate.ps1
```

Run the pinned-Godot actual-constructor preflight:

```powershell
pwsh -NoProfile -File sdk\run_balanced_wave_bw27m_material_declaration_preflight.ps1
```

Expected markers are:

```text
BW27M_MATERIAL_GATE_PASS gates=19 cells=3 canaries=10 roundtrip=True worlds=0 physical_authority=False
BW27M_MATERIAL_PREFLIGHT_PASS fixtures=4 positive_values=3 worlds=0 scene_insertions=0 wrong_value_rejected=true locomotion_exposed=false physical_authority=false
```

Both checks are wired into canonical conformance; the Godot constructor check
is omitted only by `-SkipGodot`. They open no world and grant no material,
locomotion, robustness, or launch authority.

### BW27M frozen one-shot supervisor

Run the complete freeze and supervisor audit without opening a world:

```powershell
pwsh -NoProfile -File tests\test_bw27m_material_characterization_freeze.ps1
```

Expected final marker:

```text
BW27M MATERIAL_CHARACTERIZATION_FREEZE_PASS worlds=0 production_gates=19 canaries=12 fixture_gates=7 fixtures=4 bypass_canaries=2 source_bindings=25 one_shot_contract_frozen=True physical_execution_authorized=False physical_authority=False
```

The freeze manifest is
[`balanced_wave_bw27m_material_characterization_freeze.json`](balanced_wave_bw27m_material_characterization_freeze.json),
the sole intended physical entrypoint is
[`run_balanced_wave_bw27m_material_characterization.ps1`](run_balanced_wave_bw27m_material_characterization.ps1),
and the executable closure of the prospective source boundary is
[`../tests/test_bw27m_material_characterization_freeze.ps1`](../tests/test_bw27m_material_characterization_freeze.ps1).
At this historical freeze boundary, canonical conformance ran the static
freeze audit and the supervisor's Godot authorization preflight unless
`-SkipGodot` was selected. The positive closure below now permanently replaces
those prospective routes in normal conformance.

At that boundary, `-RunPhysical` was not yet authorized. The required next
steps were to commit and push the exact freeze, run complete Godot-including
conformance to a new durable V2 attestation for that commit, and independently
verify the attestation. The physical supervisor additionally required a new
output directory named
`balanced-wave-bw27m-material-characterization-<source7>` beneath the sibling
`SporeSpore_Evidence` root. The raw freeze/supervisor/worker/audit SHA-256
values are respectively
`8d17138df375dcde3db1542ff02462412530687a6a5a7d986562971532329b36`,
`54d51cce9866bd7ed92ac6f9a9bc9e3903a177530ddf9635ee2d7ea5ed2dfc39`,
`1a58407151c46c2dc699b363935b03932731887b22372b9326cb945c2d8c1754`,
and
`7b8337c69d96d4eabda31f23fa9bcb907e2d07a5a32251a9580073782b234998`.
This is a frozen instrument contract, not a material, walking, controller, or
robustness result.

### BW27M closed-positive exact finite characterization

The exact frozen source was committed and pushed as
`a219ba86f8033971c6025edb4e45d04d651a73ee`. Full Godot-including conformance
then passed from that source and published a matching V2 attestation:

```text
<evidence-root>\full-godot-conformance-v2-a219ba86-20260802T152828Z\attestation.json
SHA-256 012e6d51315c3db57ab67880e44eb1a5136bd80b4d731ebd7c5b56eb74ba6fad
bytes   3562
```

The one authorized supervisor invocation consumed exactly one attempt and
opened the declared ten Godot/Jolt material-fixture worlds. All `19/19`
production gates passed. The frictionless control slid, the forbidden `0.25`
value was rejected, the three-replicate cells were deterministic, and the
measured response was monotone:

| Authored friction | Replicate force brackets | Minimum lower empirical ratio | Conservative controller coefficient |
|---:|---:|---:|---:|
| `0.62` | `24–25 N` in all three | `0.6119398367698766` | `0.61` |
| `0.74` | `29–30 N` in all three | `0.739513920992915` | `0.73` |
| `0.86` | `33–35 N` in all three | `0.8415623682133044` | `0.84` |

The retained physical evidence root is:

```text
<evidence-root>\balanced-wave-bw27m-material-characterization-a219ba8
report.json     eb44e73c8494becd7d5bfc777f08630b3442cade64971a203079aadad29ccae3
attempt.json    661edd0af9603a92f3fced6c018fd960254d6bae379967cb98ac044b56eb201e
engine.log      e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
transcript.log  c7f24ac8de1b480187a32b217f990ed5b27331572baf87e3bf9befd9412b669a
worker log      fb18732d4a42b9ff9d1fda71621216e43c0ba98ec75c14f3f8f95c9aa7d7c2bb
```

[`balanced_wave_bw27m_material_characterization_closure.json`](balanced_wave_bw27m_material_characterization_closure.json)
freezes that result and
[`../tests/test_bw27m_material_characterization_closure.ps1`](../tests/test_bw27m_material_characterization_closure.ps1)
reconstructs the historical source, attestation, operation lock, evidence,
matrix, evaluator decision, one-attempt cardinality, bounded claims, and rerun
refusal. Their raw SHA-256 values at closure are respectively
`5960c5d7f5b70f4d98356de884bb4d0c6fbc55f14d7060780efe07d6b278d519`
and
`843e8deaa4f696600252cf691633a30264f47682f209e5dce0475c1ee90baeb6`.
Run the closure audit with:

```powershell
pwsh -NoProfile -File tests\test_bw27m_material_characterization_closure.ps1
```

Its terminal marker is:

```text
BW27M_MATERIAL_CLOSURE_PASS status=positive worlds=10 gates=19 cells=3 profile_publication=True locomotion_seeds_opened=0 pre_physical_attestation=True conformance_overlap=False post_closure_conformance_required=True rerun_refused=True material_robustness=False physical_authority=False
```

Normal conformance now runs this immutable closure and contains no BW27M
`-PreflightOnly` or `-RunPhysical` supervisor route. BW27M may never run again
under the same identity. This result authorizes only deterministic zero-world
publication of the exact `0.61/0.73/0.84` Godot/Jolt adapter coefficients. It
does not establish walking, turning, friction/material locomotion robustness,
continuous friction coverage, a portable coefficient, cross-engine
equivalence, arbitrary quadrupeds, release readiness, or a completed SDK.
Seeds `27011–27014` remain unopened; BW28Y cannot freeze until profile
publication closes and the required post-closure conformance boundary passes.

### BW27P prospective zero-world profile publication

BW27P is the distinct deterministic successor authorized by the positive
BW27M closure. It adds exactly three immutable Godot/Jolt adapter profiles to
the previously closed 35-profile registry:

| Profile | Authored friction | Characterized coefficient | BW27M provenance |
|---|---:|---:|---|
| `godot_jolt_bw27m_mu062_v1` | `0.62` | `0.61` | three `24–25 N` brackets |
| `godot_jolt_bw27m_mu074_v1` | `0.74` | `0.73` | three `29–30 N` brackets |
| `godot_jolt_bw27m_mu086_v1` | `0.86` | `0.84` | three `33–35 N` brackets |

The resulting prospective registry has `38` profiles. Its isolated adapter
test starts the adapter `39` times and passes `49` gates while constructing
zero physics worlds, samples, or controller commands. The publication
supervisor uses the same exact attempt constructor for its perfect synthetic
receipt and any future retained receipt; the production parser accepts the
perfect serialized record and rejects ten independent one-field defects. It
also requires clean pushed live source, a matching durable V2 full-Godot
conformance attestation, a new source-named evidence root, an attempt written
before the report, and the shared machine-wide operation lock.

Run the complete prospective audit with:

```powershell
pwsh -NoProfile -File tests\test_bw27p_material_profile_publication_freeze.ps1
```

The commissioned markers are:

```text
BW27P-PROFILE CONFORMANCE_PASS profiles=38 prior_profiles=35 bw27m_profiles=3 gates=49 adapter_starts=39 worlds=0 samples=0 commands=0 locomotion_seeds_opened=0 physical_authority=False
BW27P-PROFILE PREFLIGHT_PASS profiles=38 prior_profiles=35 bw27m_profiles=3 gates=49 adapter_starts=39 canaries=10 worlds=0 samples=0 commands=0 attempt_contract=True locomotion_seeds_opened=0 physical_authority=False
BW27P_PROFILE_FREEZE_PASS profiles=38 prior_profiles=35 bw27m_profiles=3 gates=49 adapter_starts=39 canaries=10 worlds=0 samples=0 commands=0 attestation_required=True operation_lock=True supervisor_preflight=True profile_published=False locomotion_seeds_opened=0 material_robustness=False physical_authority=False
```

The prospective contract is frozen by
[`balanced_wave_bw27p_material_profile_publication_preregistration.json`](balanced_wave_bw27p_material_profile_publication_preregistration.json),
[`run_godot_jolt_bw27p_material_profile_conformance.ps1`](run_godot_jolt_bw27p_material_profile_conformance.ps1),
[`run_balanced_wave_bw27p_material_profile_publication.ps1`](run_balanced_wave_bw27p_material_profile_publication.ps1),
and
[`../tests/test_bw27p_material_profile_publication_freeze.ps1`](../tests/test_bw27p_material_profile_publication_freeze.ps1).
Their current raw SHA-256 values are respectively
`c1d17fea278eccaf558e3a03013b088d1d4e63cafac2353f16b95a4906d2b4cb`,
`d5ab360d1e94a8964b83f0143ba70ec8d45ef013fe5e28150bd2489fd8355ae7`,
`2ac4e191b305bf62fa647335036037ab6d63d9e23297f71f164d0abfc0188148`,
and
`413ddd1317349d1513e47a8082536efeca5fb6a614f3a370a10bb789a4a239bc`.

This is still a prospective instrument. No BW27P attempt or report exists,
the three profiles are not yet published under a retained receipt, and seeds
`27011–27014` remain sealed. The current source must first become a clean
pushed commit and receive a matching durable V2 full-Godot attestation. Even a
later positive publication will remain a zero-world adapter-registry result:
it cannot establish walking, turning, material locomotion robustness,
continuous friction coverage, portability to Rapier or MuJoCo, arbitrary
quadrupeds, release readiness, or a completed SDK.

### BW27P retained zero-world publication and immutable closure

BW27P has now consumed its sole publication identity from clean pushed source
`e3a3c0b7ce8e7a6346b751458d92ac3b19acc33f`. The required full-Godot V2
attestation is retained at
`<evidence-root>\full-godot-conformance-v2-e3a3c0b7-20260802T170031Z\attestation.json`
with SHA-256
`333616fff706cb4809abe7f4fa727ccc78482a32792aa1140906638efa2ca34d`.

The publication evidence root is
`<evidence-root>\balanced-wave-bw27p-material-profiles-e3a3c0b`.
Its accepted report passes `49/49` gates for `38` profiles and `39` adapter
starts, with zero worlds, samples, and commands. The report SHA-256 is
`7cf2485149f3ca97a23f3ec0d7bc9ad352bbe3fad8ba3ffdd3e45948b6587b80`.
The exact published profiles are:

| Profile ID | Authored fixture | Controller input | SHA-256 |
|---|---:|---:|---|
| `godot_jolt_bw27m_mu062_v1` | `0.62` | `0.61` | `62bd8b2543c7c3cdb9b389029e5ae3de777cbcc29c5a5ba5b769863442c854c3` |
| `godot_jolt_bw27m_mu074_v1` | `0.74` | `0.73` | `6a8128171b87ad824b3675cbf731927681b55c0f529d179e3dbb32c842752857` |
| `godot_jolt_bw27m_mu086_v1` | `0.86` | `0.84` | `29735973a8334064f1a1a1fb8c8d679c335e68b4a97a396c550f68b76321863d` |

[`balanced_wave_bw27p_material_profile_publication_closure.json`](balanced_wave_bw27p_material_profile_publication_closure.json)
and
[`../tests/test_bw27p_material_profile_publication_closure.ps1`](../tests/test_bw27p_material_profile_publication_closure.ps1)
close and audit this identity. Their commissioning SHA-256 values are
`1709a79a2929159cca075c43e516bdfaa7dd1f87806dde648f6629e6069f41de`
and
`c0e88a8c7457d8aec967c8c0d19fb1f4de3fa15c3dc835b362c6ea301a3b7596`.
The audit also verifies that a duplicate pre-attempt invocation was safely
rejected by the shared mutex, that only one attempt exists, and that the
closed supervisor cannot publish again.

This result publishes exact Godot/Jolt adapter inputs only. It is not walking,
turning, material locomotion robustness, continuous friction coverage,
Rapier/MuJoCo equivalence, arbitrary-quadruped, release, or completed-SDK
evidence. Seeds `27011–27014` remain unopened. The next permitted action is to
freeze a distinct BW28Y paired turning-development manifest and its complete
zero-world policy-relative gate; physical launch remains separately blocked.

## BW28Y stage-zero turning-development declaration

BW28Y now has a prospective, zero-world declaration surface:

- [`balanced_wave_bw28y_yaw_development_candidates.json`](balanced_wave_bw28y_yaw_development_candidates.json)
  freezes the `1.3` BW15F-B baseline and the `1.0` lower-yaw hypothesis as a
  single-mechanism contrast, plus a zero-residual active-base control;
- [`balanced_wave_bw28y_yaw_development_preregistration.json`](balanced_wave_bw28y_yaw_development_preregistration.json)
  freezes the development-only decision rule, exact nonclaims, stage
  interlocks, and the requirement for a distinct independent validation;
- [`balanced_wave_bw28y_yaw_development_manifest.json`](balanced_wave_bw28y_yaw_development_manifest.json)
  freezes `24` paired candidate cells, `3` material-matched controls, and `1`
  zero-friction safety cell across the published BW27P profiles and unopened
  seeds `27011–27014`; and
- [`../tests/test_bw28y_yaw_development_declaration.ps1`](../tests/test_bw28y_yaw_development_declaration.ps1)
  reconstructs all `28` ordered cells, verifies source hashes, and requires an
  explicit nonempty `cohort` in every cell.

This declaration repairs the exact BW25Y infrastructure defect at the data
boundary, but the declaration alone is not the complete repair and cannot
authorize a worker, composer/evaluator, supervisor, whole-path synthetic
preflight, stage-one freeze, or matching full-Godot attestation. Therefore no
BW28Y world may open from these files alone, no candidate is selected, and no
walking, turning, material-robustness, or release claim changes.

The first implementation layer is now present but remains nonphysical. The
Godot actual-path preflight feeds all `28` manifest cells through the shared
post-BW25Y route and the real inherited BW25Y-to-BW20F receipt constructors.
The PowerShell outer gate then validates raw identities before invoking the
single final composer and the `50`-gate production evaluator. A neutral perfect
fixture passes `50/50` and selects `NONE`; a deliberately selection-favoring
synthetic fixture is vetoed from exporting selection authority. Missing cohort,
worker script error, full-dictionary composer bypass, wrong world-attempt
identity, empty candidate set, and the declared policy/application/profile/
host/prerequisite/claim mutations all fail closed. The aggregate proof opens
zero worlds and exposes no locomotion outcome.

The production worker, supervisor, and
[`balanced_wave_bw28y_yaw_development_freeze.json`](balanced_wave_bw28y_yaw_development_freeze.json)
are now commissioned. The independent freeze audit binds `29` source files and
the complete supervisor preflight passes `28` entrypoints, `50` production
gates, `19` evaluator canaries, `13/13` native authority checks, `5` receipt
canaries, `16` attempt canaries, `5` authorization/bypass canaries, and `9`
outcome-blind recovery canaries with zero worlds. Physical authorization still
cannot succeed until this exact source is clean, committed, pushed, equal to
live GitHub `main`, and covered by a matching durable full-Godot V2
attestation. No attempt receipt exists and seeds `27011–27014` remain sealed.

### BW28Y closed complete with a valid `NONE` selection

The prospective source above became clean pushed commit
`77b4ca34fc2d8c3271fcfa364a817b02d7eb81ed`. Full Godot-including
conformance passed on that exact source and published the V2 attestation at
`<evidence-root>\full-godot-conformance-v2-77b4ca34-20260802T190515Z\attestation.json`,
SHA-256
`0ed780d926228097fccdf71edf369f213a844bdd89e31b09509e0736af08f6cd`.
The only authorized physical supervisor invocation then consumed attempt
`7a44427e656244358f8f774333eb2af5` under the shared operation lock.

All `28/28` declared cell receipts were complete, all `28/28` role and
production cell gates passed, all `50/50` aggregate evaluator gates passed,
and no replacement was used. The finite result was:

| Arm | Walking | Failures | `mu=0.62` | `mu=0.74` | `mu=0.86` |
|---|---:|---:|---:|---:|---:|
| BW28Y-A, yaw gain `1.3` | `7/12` | `5` | `4/4` | `1/4` | `2/4` |
| BW28Y-B, yaw gain `1.0` | `9/12` | `3` | `3/4` | `2/4` | `4/4` |
| Material-matched controls | `2/3` | `1` | `1/1` | `0/1` | `1/1` |
| Zero-friction safety | `0/1` | n/a | n/a | n/a | n/a |

B was strictly better in the frozen aggregate vector, but it regressed two
paired cells that A passed: `mu=0.62/seed=27013` and
`mu=0.74/seed=27011`. The preregistration required exactly zero paired
walking regressions, so the frozen selector correctly returned `NONE`.
Conversely, B repaired four A failures, including both A failures at
`mu=0.86`. Every candidate/control nonwalk missed exactly one gate,
`bounded_lateral_drift`; no candidate had a mechanism, application, identity,
receipt, finite-number, tilt, forward-translation, or native-actuation
failure. The safety cell correctly produced zero native motor writes and zero
effective applications.

This is a useful negative development result, not wasted work. It shows that
lower yaw gain improves the finite aggregate and high-friction block but does
not monotonically dominate the baseline. A successor may optimize from that
tradeoff—for example by freezing new intermediate or structurally different
turning hypotheses—but it must use a new campaign, source, preregistration,
fresh unexposed materials/seeds, and evidence identity. BW28Y may not be
rerun, rethresholded, rewritten, or post hoc changed to select B.

The immutable evidence root is:

```text
<evidence-root>\balanced-wave-bw28y-yaw-development-77b4ca3
attempt.json     584a85a267669a8d3ff0fdd17bd8e779a48bddc708bd73200b555ad0beede177
raw-result.json  a178dce3218f8f7254c590aa1602b7cfd26af6d3dd5a645eb4a063cb965ece2c
evaluation.json  3bc76ea47eb765a1c0adbf04f27bf462fdba74382afb194710439e9fb3a808f1
report.json      a7371506a0d295a02b67daea2cdc3fd959e80ed1157b40cd3ccfecfccba7e85b
completion.json  280909598da9a1637be23c232da043e155167e7e35b9b98e7d418d9a418e0d74
tree             c98fed56a9597f1c250f50279663a1e471ef325f44ab72678a6d2ad77188cbf1
```

[`balanced_wave_bw28y_yaw_development_closure.json`](balanced_wave_bw28y_yaw_development_closure.json)
and
[`../tests/test_bw28y_yaw_development_closure.ps1`](../tests/test_bw28y_yaw_development_closure.ps1)
have commissioning SHA-256 values
`28b95ae71cc00be49ae1f84d94356c3b410d80a156e7641e0fc02a610898919c`
and
`4cf4f4d78886327110d846998c9932566d0bab83a27f2729968c2070dcfc8689`.
The audit also reconstructs the complete canonical 29-file experiment-source
binding tree at SHA-256
`4a1ae8e38aa1d407a4c6369470f816542bea383f3ee5e0032032e565f0b0990d`
while retaining the prospective freeze's exact Windows-checkout raw hashes.
Run the audit with:

```powershell
pwsh -NoProfile -File tests\test_bw28y_yaw_development_closure.ps1
```

Its terminal marker is:

```text
BW28Y_YAW_DEVELOPMENT_CLOSURE_PASS status=valid-none worlds=28 process_attempts=28 replacements=0 receipts=28 cell_gates=28/28 evaluation_gates=50/50 walking=18 candidate_a=7/12 candidate_b=9/12 improvement_pairs=4 regression_pairs=2 selected=NONE development_selection=False validation_authority=False turning_acceptance=False material_robustness=False physical_authority=False rerun_refused=True
```

This closes only the exact finite development screen. It establishes no
turning acceptance, bounded material-locomotion robustness, continuous
friction coverage, population claim, arbitrary quadruped coverage,
Rapier/MuJoCo equivalence, release authority, or completed SDK.

## Closed negative MuJoCo velocity-only host characterization VH1

`C6-MJC-HC-VH1` consumed its only physical identity from clean pushed source
`19831738abf8800f572e974898980c2b8aab1c40`. The exact official MuJoCo `3.11.0`
wheel, Python `3.11.9`, NumPy `2.4.6`, velocity actuator, unit joint
transmission, gain `10`, force range `[-6,6] N m`, `1/120 s` timestep, and
`implicitfast` Newton `20/7` host produced a complete `8/12` valid negative.

All eight loaded affine-response cells passed with normalized velocity and
force response effectively `1.0`, a `240`-step acceptable streak, zero mirrored
asymmetry, and zero integrity errors. All four unloaded cells failed the frozen
response gate: terminal velocity was `0`, terminal force was signed saturated
`6 N m`, and no acceptable streak occurred. The result authorizes neither a
passing velocity-only host profile nor BW19V selected-policy integration or
walking.

The retained report is:

```text
<evidence-root>\c6-mujoco-velocity-only-vh1-1983173\report.json
SHA-256 6f1ceb050e1bf5e7366db0ff619c8262e896ee1d930f3952c016862d6ff70d41
```

The closure SHA-256 is
`e3f6d9a801ac1781b6a3d30d34b13ae7e33db603e5ce55b5cbed4a2627550ca5`.
Run its immutable audit with:

```powershell
pwsh -NoProfile -File tests\test_mujoco_c6_velocity_only_host_characterization_vh1_closure.ps1
```

The next MuJoCo host attempt must be a distinct stability-aware campaign with
multiple initial velocities and retained per-step position/velocity/force
traces. It may optimize the internal timestep/substeps, gain, or
inertia/armature from VH1's failure mechanism; it may not rewrite, rethreshold,
rerun, or split VH1 into a retroactive loaded-cell positive. The accepted
Godot/BW19V walker remains the fixed portable reference.

## MuJoCo VH4 prospective freeze

The next distinct MuJoCo host campaign is now frozen as `C6-MJC-HC-VH4`.
Its preregistration is
[`mujoco_c6_velocity_only_stability_host_characterization_vh4_preregistration.json`](mujoco_c6_velocity_only_stability_host_characterization_vh4_preregistration.json),
its split-step implementation is
[`adapters/mujoco/sporespore_mujoco_adapter/velocity_only_stability_characterization_vh4.py`](adapters/mujoco/sporespore_mujoco_adapter/velocity_only_stability_characterization_vh4.py),
and its zero-world freeze audit is
[`../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh4_freeze.ps1`](../tests/test_mujoco_c6_velocity_only_stability_host_characterization_vh4_freeze.ps1).

The audit currently reports:

```text
C6_MJC_HC_VH4_FREEZE_PASS cells=24 traces=43200 canaries=23 binding_canaries=5 stability=5->1 armature_upper=1.666667 worlds=0 physical_authority=False
```

VH4 separately retains completed-step actuation, post-step state, post-state
recomputed actuation, and momentum-inferred motor impulse. It correctly treats
pre-step force times `dt` as realized impulse only while the actuator is
saturated; in unsaturated `implicitfast` steps it is a force-time budget, and
the exact scalar fixture instead gates momentum against post-state force times
`dt`. A non-campaign two-step test reproduced both relations, but no VH4
campaign world or physical result exists yet. BW19V remains the unchanged
portable walker that a positive host result would subsequently carry.

VH4 subsequently passed its exact one-shot physical gate: `24/24` cells,
`43,200/43,200` traces, 114 saturated steps, zero integrity violations, and
valid saturated/unsaturated momentum relations. The retained report is:

```text
<evidence-root>\c6-mujoco-velocity-only-stability-vh4-2722c2b\report.json
SHA-256 f6b5657f14a922aed59e82bc5c6ff4d2e53b2b2a70737eeea4ec94d6a8f53f3d
```

Audit the immutable positive closure with:

```powershell
pwsh -NoProfile -File tests\test_mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.ps1
```

The closure grants exact-finite MuJoCo velocity-only host authority only. It
does not claim that BW19V has run in MuJoCo or that MuJoCo walks. Those require
a distinct selected-policy campaign; the portable Godot reference remains
unchanged.

## MuJoCo selected-policy development status

The unchanged BW19V controller now runs through the release C ABI against a
real MuJoCo articulated quadruped. A full LC1 development trajectory advanced
2,992 portable commands under real gravity and contacts, moved approximately
`1.806 m` forward, cycled every foot through contact, avoided torso-ground
contact, and retained zero native-force or portable-impulse violations.

That is a functional development walker, not yet accepted MuJoCo C6 evidence.
The robot needs morphology-specific actuator limits instead of VH4's uniform
fixture limit, so its exact host profile is deliberately marked uncharacterized
until a new finite per-actuator campaign passes. See
`adapters/mujoco/README.md` and run
`sporespore_mujoco_adapter.selected_policy_development` for the current debug
path. A new Godot walker is neither required nor part of this integration.

## MuJoCo VH5 positive per-actuator host closure

The selected robot's exact host-profile successor `C6-MJC-HC-VH5` has consumed
its sole physical identity and closed positive. Its durable authority surfaces
are:

- [`mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_preregistration.json`](mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_preregistration.json)
- [`adapters/mujoco/sporespore_mujoco_adapter/s169_force_limit_characterization_vh5.py`](adapters/mujoco/sporespore_mujoco_adapter/s169_force_limit_characterization_vh5.py)
- [`run_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5.ps1`](run_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5.ps1)
- [`mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json`](mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.json)
- [`../tests/test_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.ps1`](../tests/test_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.ps1)

Audit the immutable closure from a PowerShell 7 terminal at the repository
root. The audit opens zero new worlds and proves that physical replay refuses:

```powershell
pwsh -NoProfile -File `
  tests\test_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.ps1
```

The one-shot report passed all four exact s169 force-limit classes, `96/96`
cells, `48/48` signed pairs, and `172,800/172,800` traces. It retained `470`
saturated internal steps, `36..43` temporal-force witnesses per cell, zero
integrity violations, and zero mirrored response asymmetry. The six-file
evidence root is:

```text
<evidence-root>\c6-mujoco-s169-force-limit-vh5-d11d8ef
report SHA-256 305b3b462ec463278eedd526d28f32abdde3d0eaff919a3d52b179f6590deb96
tree SHA-256 c96149581e4db495796beda412afd87d1f9f0d740c262f07d10d393839856422
```

VH5 does not accept MuJoCo walking. It characterizes only the exact finite
scalar fixtures for the selected robot's four force-limit classes and unlocks
a separate unchanged-BW19V selected-policy campaign with a new identity,
preflight, clean pushed source, exact-source attestation, and one-shot result.

## MuJoCo MV2 selected-policy walking closure

MV1 is immutably closed implementation-invalid with no scientific result. Its
distinct successor MV2 preserves the exact body, policy, composition, host,
material, initialization, `2992`-step schedule, walking gates, and claim
boundary while strengthening the pre-world implementation contract.

The prospective zero-world supervisor passed with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_mujoco_c6_bw19v_selected_policy_walking_mv2.ps1 `
  -PreflightOnly
```

Expected terminal receipt:

```text
C6_MJC_BW19V_MV2_FREEZE_PASS worlds=0 steps=2992 commands=23936 canaries=29 synthetic=27 dynamic=2 physical_authority=False
```

The clean pushed freeze `badbea292e87c33e2798cf999501764a517af7f7`
then received a fresh full-Godot V2 attestation and consumed its one durable
process. The physical control flow completed all `2992` outer steps and
`23936` native command applications, but the report assembler requested
`morphology_id` from `robot.morphology` instead of `robot.compiled`. The
resulting `KeyError` occurred before the report dictionary was completed,
evaluated, or serialized.

Audit the immutable closure from PowerShell 7 at the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_walking_mv2_closure.ps1
```

MV2 is implementation-invalid with no scientific result. Its in-memory trace
was lost with the terminated process; the inferred completed-step counts are
control-flow facts, not recoverable trajectory measurements. MV2 may not be
patched, rerun, reconstructed, or called walking. A distinct successor must
fix and preflight the report-assembly boundary under a new identity.

## Rapier PH1 pose-hold contact-restoration freeze

TR1 remains a complete valid negative: it restored and held all four declared
contacts, but the same report failed yaw, tilt, torso-height, and torso-contact
gates. PH1 does not edit that record. It is the distinct prospective campaign
`C6-RAPIER-BW19V-VELOCITY-ONLY-POSE-HOLD-RESTORATION-PH1`, gate
`C6-RAP-BW19V-V4-PH1`, and it binds the immutable TR1 closure.

PH1 preserves the exact body, portable selected policy, schedule, horizon,
walking thresholds, and missing-foot DLS downward search. It changes only the
terminal law. A contacting limb captures its current joint pose and applies
the existing portable position/rate gains (`8.0 /s`, `0.65`) within the frozen
`0.35 rad/s` cap. It reconstructs only the already-receipted BW15F-B heading
correction; a missing limb clears pose memory and continues TR1's exact
`[0,-0.02,0] m/s`, `lambda=0.04 m` DLS search. Recontact captures neutral pose
minus current heading delta to avoid a command jump.

Run its complete zero-world audit from PowerShell 7 at the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_freeze.ps1
```

Expected terminal receipt:

```text
C6_RAP_V4_PH1_FREEZE_PASS class=finite_decision worlds=0 trace_steps=3172 commands_per_layer=25376 canaries=33 identity_order=True restorer=pose_hold_heading_plus_dls_vertical gain=8.0 damping=0.65 search=0.02 lambda=0.04 max_qdot=0.35 physical_authority=False
```

This proves prospective implementation readiness only. No PH1 physical world,
walking result, Rapier selected-policy C6 acceptance, cross-engine equivalence,
robustness, release, or physical-acceptance authority exists at this boundary.

## Rapier PH1 exact-finite positive closure

The clean pushed PH1 freeze `91c528e0d0eb494a7ff1d9dc9250ef1af6963249`
received full-Godot V2 attestation SHA-256
`1b54228bf95a995504e1a7f461d05f68465b8dd4a788bbb46e17a63a6594945f`
and consumed its one physical process. The complete retained report is
`251584270` bytes, SHA-256
`8096b48aabdd63fbbfbabcd601a6d0246c5ad6b3bf3670b4573e013c1f770222`.
The frozen evaluator and deterministic post-hoc replay both return no failure
codes.

PH1 completed all `3172` steps and every `25376`-command layer with zero
controller, mapping, nonfinite, motor-readback, impulse-limit, native-position,
or torso-contact violations. It reached its evidence endpoint at step `2091`;
all four feet were already in contact when pose hold activated at step `2092`;
the `360`-step consecutive hold completed at `2451`; and all contacts persisted
for `1080` terminal steps. Its evidence advance was `1.4770498276 m`, final
advance `1.8728120327 m`, lateral drift `0.0099704424 m`, yaw drift
`0.0038630388 rad`, maximum tilt `0.1228043884 rad`, and minimum torso height
`0.4231954515 m`.

Audit the positive closure from PowerShell 7 at the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_rapier_c6_bw19v_velocity_only_pose_hold_restoration_ph1_closure.ps1
```

The accepted claim is exact and finite: PH1 establishes s169 Rapier v4
pose-hold-restoration technical commissioning and its declared single-body
walking contract. Its preregistration explicitly excludes release-selected
Rapier C6, independent validation, population inference, arbitrary morphology,
robustness, cross-engine equivalence, release, and physical-acceptance
authority. The same PH1 identity is closed and cannot run again.

## MuJoCo MV3 selected-policy walking freeze

MV2 is permanently closed implementation-invalid after its complete control
loop but before report construction. MV3 is a distinct successor that binds
that closure and changes only the failed compiled-morphology report lookup.
Run its safe zero-world gate from PowerShell 7 at the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_mujoco_c6_bw19v_selected_policy_walking_mv3.ps1 `
  -PreflightOnly
```

Expected receipt:

```text
C6_MJC_BW19V_MV3_FREEZE_PASS worlds=0 steps=2992 commands=23936 canaries=31 synthetic=27 dynamic=2 report=2 physical_authority=False
```

Audit the complete prospective contract with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_walking_mv3_freeze.ps1
```

The shared physical report-identity assembler now reads the exact compiled
s169 identity and descriptor digest. Its model-free fixture deliberately lacks
the old nested lookup, its projection round-trips through JSON, and both
missing and wrong compiled IDs fail closed. No MuJoCo model, data object, or
campaign world is constructed by these commands.

Do not run `-RunPhysical` manually. The exact prospective freeze must first be
committed, pushed, live-verified, and covered by a fresh exact-source
full-Godot V2 attestation. The supervisor will then allow at most one process
under the global physical-operation lock. Until that retained result is
closed, MV3 establishes no MuJoCo walking, selected-policy C6, cross-engine
equivalence, robustness, release, or physical-acceptance authority.

## MuJoCo MV3 complete valid-negative closure

The exact freeze above was committed and pushed as
`a52af71de64f43b8d742d17d4cf9905b778a134f`, live-verified, and covered by a
fresh full-Godot V2 attestation (SHA-256
`846578bc8f0438f162587445b3c23d4a42b95c4a384259cb50c19ad947532d9c`).
Exactly one supervised process then consumed attempt
`b864b875e99f492398f76317605474f4` and retained a complete `2992`-step,
`23936`-commands-per-layer report. The report is `197179546` bytes, SHA-256
`e23cb1e07e7aef4288a9a3e75416b79f537794a822fc87a5ff27720204393211`;
the seven-file evidence tree SHA-256 is
`3d0fa8399aa70b7b261b29f2e27905bab01364f03782970acf051ffbd80f46d1`.

Audit the immutable result from PowerShell 7 at the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_walking_mv3_closure.ps1
```

Expected receipt:

```text
C6_MJC_BW19V_MV3_CLOSURE_PASS primary_ok=False valid_negative=True worlds=1 trace_steps=2992 receipt_projection=0/2992 nested_policy=2992/2992 memory_order=0/2992 membership=2992/2992 advance=1.399553 terminal_contacts=3/4 walking=False same_identity_rerun=False
```

The frozen result is a complete valid negative for MV3's combined walking-and-
integrity acceptance contract. All `2992` rows retained the exact policy ID at
the nested controller-receipt location but not the declared top-level
projection; all retained the correct four limb memories in the wrong declared
order; and the final snapshot lacked front-left contact. The deterministic
post-hoc diagnostic may normalize order only for diagnosis. It then reproduces
step `1936`, `1.3995530921 m` evidence advance, `1.8059354059 m` final forward
displacement, passing limb cycle/dwell/relocation and physical safety thresholds,
and zero torso contacts, but terminal stance still fails.

That is evidence of real under-gravity self-actuated forward locomotion in a
development run. It is not accepted walking evidence because the primary trace
integrity contract failed, and its terminal stance independently ended at
`3/4` contacts. MV3 is consumed; another physical campaign requires a new
identity, a real-shaped zero-world trace canary, corrected receipt/order
semantics, and an engine-neutral terminal-contact hypothesis that addresses the
front-left miss. No MuJoCo selected-policy C6, cross-engine equivalence,
robustness, release, or physical-acceptance authority follows.

## MuJoCo MV4 pose-hold-restoration implementation-invalid closure

MV4 passed its `31`-control zero-world freeze and a fresh full-Godot V2 suite,
then consumed its only process from exact clean pushed source
`9173439f92ec455d988a6ffd2c57fe5335cca439`. The process constructed one
MuJoCo world and applied walking-phase actuation until the controller reached
its evidence-limit transition. The first terminal-restoration composition
then raised `TypeError` before any terminal mapping or native terminal command:
production endpoint kinematics encode vectors as `{"x", "y", "z"}` objects,
but the new restorer and its synthetic canary assumed three-element lists.

No complete report was built, evaluated, or serialized. Do not recover the
lost step count, trace, metrics, or walking decision from the terminated
process. MV4 is a consumed implementation-invalid no-result and may not be
rerun. Run its safe closure audit from PowerShell 7 at the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure.ps1
```

Expected receipt:

```text
C6_MJC_BW19V_MV4_CLOSURE_PASS status=implementation-invalid worlds=1 evidence_transition=True terminal_commands=0 report=False scientific_result=False walking=False physical_authority=False rerun_refused=True
```

The immutable closure binds source commit/tree, the exact full-Godot
attestation (`d2af18c4...eb1b`), the five-file evidence tree
(`40ea2f40...9578`), the traceback, non-claims, and executable rerun refusal.
A successor must normalize production-shaped vector objects and add a
production-shaped zero-world canary under a new campaign, gate, source,
attestation, and one-shot identity. Accepted MuJoCo walking, selected-policy
C6, cross-engine equivalence, robustness, release, and physical-acceptance
authority remain false.

## MuJoCo MV5 prospective implementation-repair freeze

MV5 preserves MV4's complete physical configuration and changes only strict
normalization of production kinematic `x/y/z` objects plus qualification of the
real `_vec_json` producer/parser boundary. Its frozen source identities are:

- preregistration `b8aff0c6...bcbe2f`;
- implementation `4c949b87...6217b`;
- supervisor `352ff911...a18c5`;
- MV4 closure authority `ee8c6805...fdd28`.

Run the safe audit from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_freeze.ps1
```

Expected terminal marker:

```text
C6_MJC_BW19V_MV5_FREEZE_AUDIT_PASS worlds=0 steps=2992 commands=23936 canaries=37 synthetic=18 dynamic=2 morphology=2 trace=5 restoration=5 vector=5 physical_authority=False
```

This command cannot authorize or consume a physical attempt. MV5 has no
physical result until its exact clean pushed freeze receives a fresh full-Godot
V2 attestation and the supervisor reserves the single permitted process.

## MuJoCo MV5 implementation-invalid closure

MV5 consumed its single clean-source process at commit `899093ee...9d22`.
Frozen control flow reached post-loop report assembly, where the PH1 source
lookup used nonexistent `experiment_source.commit` rather than the closure's
top-level `physical_source_commit`. The child exited `1`; `report.json` is
absent, and no evaluator decision or physical metric is admissible.

Run the safe closure audit:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.ps1
```

```text
C6_MJC_BW19V_MV5_CLOSURE_PASS status=implementation-invalid worlds=1 loop_inferred=True steps_inferred=2992 report=False scientific_result=False walking=False physical_authority=False rerun_refused=True
```

The closure pins the 37-control preflight, exact-source attestation, five-file
evidence tree, traceback, strict non-claims, and executable rerun refusal. The
inferred loop count is not a recovered trajectory or walking result.

## MuJoCo MV6 prospective shared-report-assembler freeze

MV6 is a new campaign and gate, not a repair in place. It binds MV5's immutable
closure and parent commit `067d9062...c916`, preserves the complete physical
hypothesis, corrects PH1 source projection to top-level
`physical_source_commit`, and routes both synthetic and physical final reports
through `_assemble_report()`.

Frozen prospective artifacts:

- preregistration:
  `sdk/mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_preregistration.json`
  (`b08ba1a6...f0956`);
- implementation:
  `sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_pose_hold_restoration_mv6.py`
  (`ea3e96ca...fbd6`);
- supervisor:
  `sdk/run_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6.ps1`
  (`4e831df2...fffb4`);
- prospective audit:
  `tests/test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_freeze.ps1`
  (`bd6771c8...cc88d`).

Run the safe zero-world audit from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_freeze.ps1
```

```text
C6_MJC_BW19V_MV6_FREEZE_AUDIT_PASS worlds=0 steps=2992 commands=23936 canaries=43 synthetic=18 dynamic=2 morphology=2 trace=5 restoration=5 vector=5 assembler=6 physical_authority=False
```

This route cannot consume a physical identity. A complete physical report is
still required before any MuJoCo walking claim exists.

## MuJoCo MV6 exact-finite positive closure

MV6 subsequently ran once from clean pushed source `3ad4d5fb...d3b9` after a
fresh full-Godot V2 attestation. The retained report contains all `2992` trace
rows, reports `ok=true`, and returns zero failures under the unchanged frozen
evaluator. The closure independently reconstructs `1.3995530921 m` evidence
advance, `1.7968949907 m` final advance, zero torso-ground contacts,
four-contact acquisition at step `1939`, and a 360-step required hold within
`1053` consecutive four-contact steps.

Run the safe closed-state audit from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.ps1
```

```text
C6_MJC_BW19V_MV6_CLOSURE_PASS status=positive worlds=1 trace_steps=2992 advance=1.399553 hold=360/1053 walking=True selected_policy_c6=False cross_engine_equivalence=False physical_authority=False rerun_refused=True
```

The evidence root is
`<evidence-root>\c6-mujoco-bw19v-mv6-3ad4d5f`.
The runner now refuses `-RunPhysical` before evidence mutation. The result is
accepted only for its exact-s169 finite contract; release-selected C6, formal
cross-engine equivalence, wider morphology, robustness, release, and physical
authority remain false.

## Closed BW30N implementation-recovery record

BW30N ran once from clean pushed source `08c06bf...a0b3` after a fresh
full-Godot V2 attestation and retained all `24` worlds. The frozen evaluator
closed it implementation-invalid (`12/14` gates, selector `NONE`, no valid
selection): the nominal `1514` horizon began at post-settle time, while the
reference route used `472` ticks for support acquisition and received only
`1042` actual authority/noise applications. The successor route received the
full `1514`.

Run the closed-state audit from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_bw30n_recovery_closure.ps1
```

```text
BW30N_RECOVERY_CLOSURE_PASS status=implementation-invalid worlds=24 parsed=24 logs=24 gates=12/14 schemas=1 horizon=24/24 a_integrity=0/12 b_integrity=12/12 a_noise=1042 b_noise=1514 walking_descriptive=0/12,0/12 selector=NONE valid_none=False selection_authority=False nuisance_authority=False physical_authority=False rerun_refused=True
```

The evidence root is
`<evidence-root>\balanced-wave-bw30n-recovery-08c06bf3`.
Do not invoke BW30N physically again. Its descriptive `0/12` and `0/12`
walking counts are not a valid locomotion negative. A new campaign must freeze
candidate-authority-relative exposure and real-route challenge counts before
opening another world.

## BW31N candidate-authority horizon immutable closure

BW31N ran its complete 24-world matrix from exact source
`2690f24370ad8af09521b7bd9e61ce46ff6c1510` after a passing full-Godot V2
attestation. All 24 receipts parsed; no process timed out and no process tree
was killed. The original frozen evaluator passed 10/15 gates and closed the
only attempt as implementation-invalid with no selected candidate.

The authority-relative clocks themselves held: both routes produced exactly
`3,232` authority observations, excluded their `712` and `240` pre-authority
ticks, and applied all direct sensor-noise challenges. The workers nevertheless
projected legacy parent summary fields. BW31N-A inherited old-horizon challenge
and common-integrity booleans; BW31N-B emitted blank policy identity metadata
and false legacy application/outcome/integrity aggregates. Zero-world receipts
had constructed those fields and therefore missed this dynamic projection
failure.

Run the immutable closure audit from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_bw31n_authority_horizon_closure.ps1
```

Expected marker:

```text
BW31N_AUTHORITY_HORIZON_CLOSURE_PASS status=implementation-invalid worlds=24 parsed=24 logs=24 gates=10/15 horizon=24/24 a_identity=12/12 b_identity=0/12 a_application=12/12 b_application=0/12 integrity=0/24 descriptive_subreceipts=9/12,10/12 selector=NONE selection_authority=False nuisance_authority=False physical_authority=False rerun_refused=True
```

The closure SHA-256 is
`b92320e3122257829cebab3ae08c6dacc0aa2def055a649c1345e78b0a51e65f`.
Its retained evidence tree SHA-256 is
`401f6de3981310b5f92b31949ad13395d1bfa3b561a156719ed3f50b7125e3c9`.
Descriptively, 9/12 A cells and 10/12 B cells had all 26 walking subreceipts
true, but this has no selection or superiority authority; all frozen
`walking_observed` fields remained false under the failed integrity contract.
BW31N-B is not selected. BW31N may not be repaired or rerun. Any successor must
exercise dynamic long-horizon summary projection and the complete evaluator in
repeatable noncampaign physics before consuming a new one-shot identity.

## DRP1 noncampaign dynamic-receipt regression stage zero

`BW31N-DYNAMIC-RECEIPT-PROJECTION-REGRESSION-DRP1` is a repeatable
implementation regression, not a repaired BW31N campaign. Its declared matrix
contains both real route lineages, all four frozen challenge profiles, and
regression-only seeds `22001`-`22003`: 24 future Godot Jolt worlds. It retains
the common `3,232` authority observations and `25,856` native writes per cell.

The required implementation must derive fixed route identity from frozen
route declarations and recompute challenge, application, outcome-completeness,
and common-integrity gates from real summary primitives. Constructed
real-shaped receipts cannot substitute for dynamic worlds. Both routes must
use one shared final composer, and all 24 receipts must traverse one complete
12-gate evaluator. Walking may be true or false in a structurally complete
receipt, but walking counts are not an evaluator input and cannot select a
route.

Run the stage-zero audit:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_drp1_dynamic_receipt_projection_declaration.ps1
```

```text
DRP1_DECLARATION_PASS routes=2 profiles=4 seeds=3 cells=24 authority_horizon=3232 dynamic_parent_summary=True shared_composer=True complete_evaluator=True regression_physics=False one_shot=False worlds=0 selection_authority=False walking_authority=False physical_authority=False
```

This boundary opens zero worlds. Regression physics remains blocked until its
workers, composer, evaluator, negative controls, and source freeze exist and
pass. It may then run only as ordinary physics inside full Godot conformance
under the global conformance lock. It consumes no one-shot identity and grants
no walking, nuisance, turning, self-righting, arbitrary-morphology,
cross-engine, release, or physical authority. Seeds `49101`-`49103` remain
reserved and unopened.

## DRP1 noncampaign dynamic-receipt regression stage one

The real implementation and zero-world authorization gate are now complete.
The reference and successor workers call one shared final composer on their
actual long-horizon parent summaries. The 12-gate evaluator rejects malformed
or missing receipts, enforces exact 24-cell order and route identity, and does
not use the descriptive walking count. The actual Godot preflight exercises
all 24 worker entrypoints, rejects constructed final-receipt substitution, and
refuses both unauthorized regression canaries before a world is created.

Run the stage-one checks from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_balanced_wave_dynamic_receipt_projection_drp1_zero_world_gate.ps1

pwsh -NoLogo -NoProfile -File `
  .\tests\test_drp1_dynamic_receipt_projection_freeze.ps1
```

Expected terminal markers:

```text
DRP1_ZERO_WORLD_GATE_PASS gates=12 evaluator_canaries=12 entrypoints=24 authorization_canaries=2 constructed_receipts_rejected=24 worlds=0 one_shot=False selection_authority=False walking_authority=False physical_authority=False
DRP1_STAGE_ONE_FREEZE_PASS worlds=0 cells=24 gates=12 source_bindings=28 entrypoints=24 evaluator_canaries=12 malformed_receipt_canary=1 authorization_canaries=2 constructed_receipts_rejected=24 shared_composer=True regression_ready_after_clean_push=True one_shot=False selection_authority=False walking_authority=False physical_authority=False freeze_sha256=19d46d3ac1237f7f483f14d8e4f70de7375fa0919232b6900d91f1e46de2f4e2
```

The freeze file is
`balanced_wave_dynamic_receipt_projection_drp1_freeze.json`, SHA-256
`19d46d3ac1237f7f483f14d8e4f70de7375fa0919232b6900d91f1e46de2f4e2`,
and binds 28 source files. It does not authorize standalone physics. After a
clean push, `run_conformance.ps1` with Godot enabled is the sole authorized
route: it owns the global lock, creates an ephemeral random token, captures the
actual clean/live source commit, runs all 24 cells, requires all 12 evaluator
gates, and deletes the non-authoritative temporary records. The regression
retains no scientific evidence, consumes no one-shot identity, and cannot
promote any locomotion or release claim.

## DRP1 repeatable run one and route-specific schema revision

The first clean-pushed full-Godot DRP1 execution opened all 24 regression
worlds and reached the complete evaluator. It passed 9/12 gates and failed
`shared_final_receipt_schema`, `outcome_complete`, and
`common_execution_integrity`. The requested durable attestation was not
published. Verify the retained noncampaign result with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_drp1_dynamic_receipt_projection_run1_result.ps1
```

The exact source diagnosis is a route-schema mismatch, not locomotion: the
reference emits `sdk_stability_overlay_evidence_actuation`; the successor
emits `native_sdk_exclusive_post_settle_actuation`; revision one required the
former in both nested receipts. Revision two keeps the outer schema and the 12
gates unchanged, requires exactly 25 common nested keys plus the correct one
route-specific actuation key, and rejects cross-route substitution.

Run its zero-world and freeze gates with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_balanced_wave_dynamic_receipt_projection_drp1_zero_world_gate.ps1

pwsh -NoLogo -NoProfile -File `
  .\tests\test_drp1_dynamic_receipt_projection_freeze_v2.ps1
```

The revision-two freeze SHA-256 is
`13dc2eeff72915551f126dabdba844cceee5f88aaaecf7932b6b1ad028e5fac6`
with 32 exact source bindings. Rerun physics remains full-conformance-only
after a clean push. It retains no scientific evidence and grants no policy
selection, walking, nuisance, turning, recovery, morphology, cross-engine,
release, or physical authority.

## Closed BW32N dynamic-receipt recovery development screen

BW32N is the finite, outcome-exposed successor that followed the positive DRP1
implementation regression. Exact source
`04226fd076b1a1d856f2b0fcec44fb35318f7d3e` passed full Godot/Jolt conformance,
published a source-exact V2 attestation, and then executed all `24/24` declared
worlds under the one-shot supervisor. All worker exits were zero, all receipts
parsed, and all `16/16` evaluator gates passed.

The frozen comparison selected `BW32N-B` development-only. A passed `9/12`
walking conjunctions, with two rough failures and one push failure. B passed
`10/12`, with two rough failures and zero push failures. That is a valid strict
total improvement with no per-axis regression. It does not alter the SDK's
release-selected policy or create robustness, acceptance, population,
superiority, non-inferiority, or equivalence authority.

Fresh validation remains closed because B did not meet its prospective
`12/12` prerequisite. Seeds `49101`-`49103` remain unopened. BW32N is consumed
and may not be rerun or repaired; only a distinct rough-focused development
successor may use these observed failure mechanisms.

Verify the retained result from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_bw32n_dynamic_receipt_recovery_closure.ps1
```

```text
BW32N_DYNAMIC_RECEIPT_RECOVERY_CLOSURE_PASS status=valid-development-selection worlds=24 receipts=24 gates=16/16 selected=BW32N-B walking=9/12,10/12 failures=3,2 push_failures=1,0 rough_failures=2,2 fresh_validation_ready=False fresh_seeds_opened=False selection_authority=True walking_authority=False nuisance_authority=False physical_authority=False rerun_refused=True
```

The closure file SHA-256 is
`c249a3727402ec5ebbea507d7550d0edd1f36ca58d69d87d69e8ac52489239d0`;
the durable evidence tree SHA-256 is
`0a46e3a7005c6f52c8242da7c983682f03ae69b44ef0b909fe8121d917b5f1fd`.
Walking acceptance, rough-terrain robustness, external-push recovery,
sensor-noise robustness, turning, self-righting, arbitrary morphology,
continuous coverage, cross-engine equivalence, release authorization, and
physical-acceptance authority remain false.

## Godot/Jolt GJTP1 transport execution contract

The Godot adapter's active native JSON route is
`sporespore_godot_json_preallocated_single_pass_v1`. It preallocates `16,384`
output bytes, executes the pure C-ABI operation once on the normal path, and
allows one exact-size retry only after `SS_BUFFER_TOO_SMALL` reports a larger
required output. This replaces the former mandatory null-buffer size query,
which executed every pure operation twice.

The machine-readable declaration is
[`godot_jolt_transport_execution_contract.json`](godot_jolt_transport_execution_contract.json).
The native class exposes `transport_execution_version()` and
`transport_execution_contract_json()`. The GDScript adapter validates every
field before descriptor compilation, while both real-physics runner variants
perform the same validation before fixture construction or scene-tree
insertion. Adapter manifests, pre-world receipts, and physical summaries
retain the contract and its canonical digest. Wrong or missing identity has no
legacy fallback and returns zero world builds, zero scene insertions, no
physics mutation, and no physical authority.

Verify the source-order, route, and future-campaign obligations from the
repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_godot_jolt_transport_execution_contract.ps1
```

After building the debug GDExtension, verify the live route and its three
negative canaries with:

```powershell
& '<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe' `
  --headless `
  --path '<repo>' `
  --script 'res://tests/test_sdk_godot_jolt_transport_execution_contract.gd'
```

GJTP1 changes transport execution count, not controller or physics semantics.
Its retained dirty-source, zero-world development benchmark measured
`1.8653x` at the native boundary: `0.578064 s` single-pass versus `1.078275 s`
legacy for `2,000` valid balanced-wave calls. Receipt SHA-256 is
`2acd9011499707b4e6822b120cae9d982b8d4cb3d7a5b762a098def4c9612949`.
This is not a total-cell speedup and grants no physical, walking, robustness,
turning, recovery, morphology, cross-engine, release, or completed-SDK
authority.

Run that development-only benchmark from the repository root with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_godot_jolt_transport_benchmark.ps1
```

Do not invoke the ignored release test directly against `sdk/target`. The
runner forces a reusable outside-repository Cargo cache, retains each receipt
and transcript in a new evidence directory, hashes both canonical release DLLs
before and after, preserves backups, and fails on mutation or source drift. Its
result measures only the native JSON/controller boundary, not an entire Jolt
cell or physical campaign.

## Godot/Jolt GJPS1 persistent controller sessions

The additive session contract is
[`godot_jolt_persistent_session_contract.json`](godot_jolt_persistent_session_contract.json),
identified by `sporespore_godot_balanced_wave_persistent_session_v1`.
It adds these public lifecycle symbols:

```c
ss_balanced_wave_policy_session_create_json(...);
ss_balanced_wave_policy_session_step_json(...);
ss_balanced_wave_policy_session_destroy(...);
```

Create compiles one bounded descriptor and named balanced-wave policy into an
opaque process-local nonzero `uint64_t` handle. Step still receives explicit
controller memory, state, and command; it does not compile a descriptor or
construct a controller. Destroy owns the handle lifecycle. The Python binding
exposes the same ownership through `create_balanced_wave_policy_session()` and
the context-managed `BalancedWavePolicySession` class.

Verify the source/ABI/schema/runner contract from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_godot_jolt_persistent_session_contract.ps1
```

After building the debug GDExtension, verify its live contract, create/destroy
lifecycle, and five negative canaries with:

```powershell
& '<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe' `
  --headless `
  --path '<repo>' `
  --script 'res://tests/test_sdk_godot_jolt_persistent_session_contract.gd'
```

Run the isolated release benchmark only through:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_godot_jolt_persistent_session_benchmark.ps1
```

The retained dirty-source zero-world run executed `5,000` exact-byte-equivalent
steps in `0.176369 s`, versus `1.601918 s` through GJTP1 stateless single-pass,
or `9.0828x` at the native boundary. Its evidence root is
`SporeSpore_Evidence/gjps1-session-benchmark-20260805T082544Z` and receipt
SHA-256 is
`0c69f3deefec7b705b7c376644646f00efe6c56213350a8831bd51b4f782beb2`.
Canonical release artifacts were unchanged. This is not a whole-cell timing
result and grants no physics, walking, robustness, morphology, cross-engine,
release, or completed-SDK authority.

## WRB1 reproducible Windows Rust artifacts

[`windows_rust_reproducible_build_contract.json`](windows_rust_reproducible_build_contract.json)
defines the prospective Windows/MSVC two-clean-root gate. It pins Rust/Cargo
1.97.0, `--locked --offline`, disabled incremental compilation, the source
commit epoch, source/Cargo-home/Rust-sysroot path remapping, `/Brepro`, and
`/PDBALTPATH:%_PDB%`. It intentionally does not override codegen units.

Verify the contract, exact PE-field diagnosis, historical MV6 non-substitution,
content-store idempotency/corruption rejection, and zero-world runner preflight:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_windows_rust_reproducible_build_contract.ps1
```

After a clean commit is pushed and verified live, run the actual two-root gate:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_windows_rust_reproducible_build.ps1 -VerifyTwoRoot
```

The runner archives the exact pushed commit into separate source roots, uses
separate target roots, requires raw SHA-256 and byte-length equality, rejects
embedded Windows absolute paths, and publishes the winning bytes through
[`content_addressed_artifact_store.ps1`](content_addressed_artifact_store.ps1)
before writing the receipt or allowing a consumer process. The mutable Cargo
target is never evidence authority.

The zero-world characterization at frozen source `3ad4d5fb` produced exact
`1,579,008`-byte DLLs with SHA-256
`c124f52ceb3ce928950bf31653813fb4787e04cdb9e6ee05b0b2998c3fd5e409`.
Its receipt SHA-256 is
`fd913b34096c9c208d279955846386ea9d45b7b3458a9701e778db2708270b1f`.
This neither recovers nor replaces MV6's missing original artifact and does not
establish cross-machine, cross-toolchain, cross-platform, physical, or release
authority.

## GJPT1 invalid phase-timing attempt and GJPT2 successor

[`godot_jolt_phase_timing_contract.json`](godot_jolt_phase_timing_contract.json)
declared a first-and-final one-cell development measurement intended to price the
GJPS1 optimization against actual Godot/Jolt cell work. It does not modify the
frozen BW32N runner. Instead,
[`godot_jolt_phase_timing_source.ps1`](godot_jolt_phase_timing_source.ps1)
generates a hash-pinned derivative under `sdk/target/gjpt1` and the supervisor
retains its exact bytes before physical execution.

Run the zero-world contract, generated-source, and direct-physical rejection
audit from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_godot_jolt_phase_timing_contract.ps1
```

The prospective freeze was pushed at
`d5e6e034748238c583f3e75431cb2a437ca06104`, then its only physical attempt
closed invalid/incomplete after the world returned. The development worker
called `_bw32n_successor_receipt`, whose frozen BW32N source-binding audit
correctly rejected the newer runner, conformance entrypoint, GDScript adapter,
and native adapter. No timing receipt was retained, so GJPT1 authorizes no phase
result and cannot be rerun. Exact source, evidence, log, and failure hashes are
in
[`godot_jolt_phase_timing_gjpt1_closure.json`](godot_jolt_phase_timing_gjpt1_closure.json).

GJPT2 is the distinct successor. It reuses the identical timing transform and
physical configuration, but its post-world evidence projection is
development-owned and deliberately has no acceptance-composer dependency. Run
its zero-world contract and projection canary from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_godot_jolt_phase_timing_gjpt2_contract.ps1
```

GJPT2 was frozen and pushed at
`fdaf2a6577b1e2d4d04e0767ba05cc08491883e6`; its single physical measurement
was launched through:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_godot_jolt_phase_timing_gjpt2.ps1 -RunPhysical
```

The report partitions pre-physics active work excluding the nested native
boundary, native boundary time, physics-frame wait, post-physics
observation/evidence work, setup-summary-cleanup residual, and evidence writing.
The runner serializes the physical workload, emits ten-second progress
heartbeats, and forbids retrying either consumed identity. The reused BW32N cell
is configuration only; its outcome is observed but cannot be interpreted as a
new walking or nuisance result.

GJPT2 completed one world and all 3,472 ticks. Its exact closure is
[`godot_jolt_phase_timing_gjpt2_closure.json`](godot_jolt_phase_timing_gjpt2_closure.json)
and the independent evidence audit is
[`../tests/test_godot_jolt_phase_timing_gjpt2_closure.ps1`](../tests/test_godot_jolt_phase_timing_gjpt2_closure.ps1).
The optimized cell spent `83.972138%` in active pre-physics work excluding the
native boundary, `9.937389%` in the GJPS1 native boundary, `5.503332%` waiting
for physics frames, `0.562854%` in post-physics observation, `0.022163%` in
residual setup/summary/cleanup, and `0.002125%` writing evidence. GJPS1's
isolated `9.0828x` boundary speedup therefore implies a bounded `1.803219x`
stateless-to-persistent whole-cell estimate for this one cell if non-boundary
work is unchanged. It is not a direct paired cell benchmark or general claim.

## R23D10 turning evidence implementation

The active turning successor's production trace and evaluator are frozen by
[`turning/r23d10_stage_two_evidence_contract_v1.json`](turning/r23d10_stage_two_evidence_contract_v1.json).
It retains canonical `3,892`-row NDJSON traces through the shared content-
addressed artifact store, independently replays the `900`-step quiescent taper,
and evaluates the two-cell MuJoCo selector plus conditional nine-cell three-
engine confirmation. Trace staging is create-only, retained paths must match
their digest-derived CAS identity, and the evaluator requires the exact
expected source commit. Run its complete zero-world gate with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_qsdk_r23d10_stage_two_evidence.ps1
```

The five trace and nine evaluator tests pass across all `11` declared
identities, including valid-`NONE`, tamper-refusal, and exact CLI-marker paths.
Clean pushed commit `94f724adecd1ab6d95339dc8a3224fad2a2d586d` is preserved
by
[`../tests/test_qsdk_r23d10_stage_two_closure.ps1`](../tests/test_qsdk_r23d10_stage_two_closure.ps1).
This supplies no physical result: workers, supervisor, models, worlds, turning,
equivalence, QSDK-R23, prone-to-standing, and release remain false.

## QSDK-R05D exact-finite morphology successor design

[`qsdk_r05d_exact_finite_morphology_successor_design_v1.json`](qsdk_r05d_exact_finite_morphology_successor_design_v1.json)
binds the consumed R05B `33/36` and R05C `29/36` reports and rejects a
continuous inner-box interpretation because historical success is not
monotonic by shell radius. The selected R05E support question is an exact
twelve-body local star: one low and one high change for each of the six public
morphology axes, one axis changed per body. It does not claim the space between
those points or any multi-axis combination.

Run the zero-world design audit from the repository root:

```powershell
python .\sdk\conformance\qsdk_r05d_exact_finite_morphology_successor_design.py
```

The audit binds ten authorities, reconstructs the historical result structure,
validates all twelve exact descriptors, and rejects twelve mutations. R05E
must next implement and qualify the selector, then pass one non-held-out route
ghost before any of the reserved `12 x 3` finite population may run. R05D
opens no physics and does not advance M05.

## QSDK-R05E route history: development ghost closed, held-out sealed

The R05E route is implemented and its single development route ghost is closed.
Its literal descriptor authority is
[`../scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd`](../scripts/lab/gait/qsdk_r05e_exact_finite_morphology_spec.gd),
with separate frozen contracts for the
[`12 x 3` held-out decision](qsdk_r05e_exact_finite_morphology_preregistration.json)
and the
[`1 x 1` development ghost](qsdk_r05e_development_route_ghost_preregistration.json).
The worker specializations are
[`../tests/test_sdk_qsdk_r05e_exact_finite_morphology.gd`](../tests/test_sdk_qsdk_r05e_exact_finite_morphology.gd)
and
[`../tests/test_sdk_qsdk_r05e_development_route_ghost.gd`](../tests/test_sdk_qsdk_r05e_development_route_ghost.gd);
both use the same production construction, controller, and walking-evaluation
path through their shared authorization-gated route. The ghost's clean-pushed
source freeze was `52beaf3c`; its closure-only qualification was `33d2a821`;
its authority-only commit was `f44dcc91`; and its consumed
[physical closure](qsdk_r05e_development_route_ghost_physical_closure_v1.json)
is the sole change in `6ea17c4e`.

That one authorized development world completed the production route at index
`229`, seed `40001`: construction, stepping, finalization, nine-file retention,
publication, and evaluation all completed. Its one receipt happened also to
pass all `27` walking gates, with `2,782` SDK steps and `22,256` native motor
writes, but it is still development-only route evidence. It is not one of the
twelve held-out bodies, does not satisfy M05, and cannot be rerun. The retained
tree is exactly `9` files and `437,196` bytes at canonical manifest SHA-256
`f21fedd25851ea8b5517b3a2ee3db34a63466b6cdfe564ba54a37128aaf0deea`.

Run the complete prospective zero-world audit from the repository root:

```powershell
python -B .\sdk\conformance\qsdk_r05e_zero_world_implementation.py
```

It reruns the R05D design audit, the `32`-control descriptor/source gate, the
one-cell ghost supervisor preflight, the 36-cell official supervisor preflight,
and missing-execution-authority refusals for both physical modes. Both source
inventories are the same ordinal, complete `80`-path closure: `41` recursive
GDScript/resource paths, `25` local Rust build inputs, and `15` process/audit
paths with one overlap. Each supervisor owns the common `conformance` mutex for
its complete run, rejects both a wrong token and a wrong JSON field type, and
requires every qualified text path to carry an explicit LF checkout policy so
its raw source digest is stable across Windows and non-Windows checkouts. It
emits the same exact Godot/Jolt, adapter-DLL, Rustup/resolved Rust toolchain,
PowerShell, Git, host, and build-environment identity. Windows executable paths
are normalized only in that identity projection, and the audit deliberately
launches its two supervisors through `.EXE` and `.exe` spellings to prove that
case alone cannot split an otherwise byte-identical runtime. The audit binds
its Python executable separately and reacquires the lock after both runs to
prove release. A pass means the exact descriptor, source, production-policy,
entrypoint, serialization, aggregation, worker-authorization, and refusal paths
reconcile at zero worlds. It is not an official clean-pushed held-out
qualification and says nothing about whether any of the twelve reserved bodies
walks.

The shared
[`qsdk_r05e_execution_authority_contract.ps1`](qsdk_r05e_execution_authority_contract.ps1)
uses a parent-bound authority rather than a self-referential authorization
commit. Its zero-world test builds a real temporary three-commit Git graph,
audits the real immutable ghost graph and its retained bytes, and rejects `35`
content mutations plus `5` source, authority, qualification-receipt, runtime,
or commit-shape mutations. The ghost audit parses and reconciles the closure,
physical report, attempt receipt, all `27` walking gates, consumed-one-world
boundary, nine-file manifest, and every narrow claim/refusal flag; a matching
hash alone is insufficient. A future held-out qualification closure must be the
source freeze's direct, closure-only child and must bind every qualified source
blob plus the parsed zero-world receipt. Its immediate child must change only
the execution-authority file; the physical launcher derives both edges from
`HEAD` and proves the source, runtime, and completed ghost remain exact.

The official zero-world route is
[`qsdk_r05e_zero_world_qualification.ps1`](qsdk_r05e_zero_world_qualification.ps1).
It refuses anything except clean live-equal `main`, consumes one durable
campaign/source qualification claim before launching, and retains the attempt,
stdout, stderr, parsed receipt, and terminal completion in
`SporeSpore_Evidence`. Its child audit is bounded at thirty minutes; success
also requires a second clean branch/commit/cached-remote/live-remote check after
the audit. It shares a named exclusion interlock with R05E physical execution.
Do not run it until this hardening is committed and pushed; a failed attempt
remains consumed for that exact source.

The physical wrappers are
[`run_qsdk_r05e_development_route_ghost.ps1`](run_qsdk_r05e_development_route_ghost.ps1)
and
[`run_qsdk_r05e_exact_finite_morphology.ps1`](run_qsdk_r05e_exact_finite_morphology.ps1).
Do not invoke the ghost physically again: its one identity is consumed and
same-identity rerun is forbidden. Do not invoke the held-out wrapper without
`-PreflightOnly`: its qualification closure and single-use authority do not yet
exist. The next legal sequence is a clean-pushed hardening source freeze, one
official zero-world held-out qualification, a closure-only qualification
commit, and a distinct authority-only commit. Only then may the frozen
`12 x 3 = 36` held-out decision open. Until that prospective population closes,
M05 and every broader morphology or release claim remain false; scores remain
SDK1 `12/20` and full program `12/25`.

## QSDK-R05E exact-finite result: held-out population closed and M05 adopted

The preceding text records the prospective, pre-qualification boundary. The
official held-out route subsequently completed its exact three-commit chain:
source freeze `54d23a7afcca6e98f35eebf5479b1fd145b11c23`, closure-only
zero-world qualification `3228ad65f3afafe0d53572a0bc375e89ff0ea85c`, and
authority-only child `2c47d8b05e3f46f1c752bc544937c0b69826069e`. Its one
authorized held-out campaign is complete and permanently consumed; no second
R05E physical attempt is legal.

The twelve literal descriptor identities at indices `217..228`, crossed with
the three frozen seeds `40101..40103`, produced exactly `36/36` complete
worlds. All `36/36` passed execution integrity, declared mechanism, combined
application, and the unchanged walking conjunction, and all `972/972` raw
walking-gate booleans are true. Across `97,862` SDK steps the native adapter
recorded `782,896` validated balanced-wave commands and exactly `782,896`
native motor writes—eight writes per step—with zero direct-body writes, legacy
writes, SDK mismatches, safe-disable events, retries, timeouts, killed process
trees, receipt-parse failures, or substituted cells.

The
[`qsdk_r05e_exact_finite_morphology_physical_closure_v1.json`](qsdk_r05e_exact_finite_morphology_physical_closure_v1.json)
binds the immutable `890,301`-byte physical report at
`sha256:0fb1d495d079beeda1412c8f3c0af5127dc0646429debf80cf0d20e0d3cd1ab6`.
The retained tree is exactly `149` files / `4,545,211` bytes; its canonical
`26,618`-byte manifest hashes to
`sha256:39100949b3fdc0f8534bdbdd2d4dbf7b0bf74cff9c4f8d6d01b6773dbd50ffd5`.
The read-only post-result auditor was isolated in commit `d4692c02`, the
closure in `25cef1f7`, and the permanent
[`test_qsdk_r05e_physical_closure.ps1`](../tests/test_qsdk_r05e_physical_closure.ps1)
in `e0d2ec75`.

The release contract now marks `QSDK-R05` passed from that content-bound
closure, and the bounded mapping marks `SDK1-M05` passed. The executable score
is therefore SDK1 `13/20` and full program `13/25`, with release and physical
acceptance still blocked. This evidence supports only those twelve exact
one-axis-at-a-time bodies under those three exact seeds in Godot/Jolt. It does
not support the space between the points, a morphology box, multi-axis
combinations, extrapolation, arbitrary-valid quadrupeds, continuous-volume
coverage, material or friction robustness, rough terrain, pushes, sensor
noise, other engines, or publication. The R05B `33/36` and R05C `29/36`
records remain unchanged negatives for their distinct frozen questions.

## QSDK-R10A bounded upright-push recovery successor design

[`qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json`](qsdk_r10a_bounded_upright_push_recovery_successor_design_v1.json)
freezes the focused R10B question that may replace the immutable BW6N push
negative. It keeps the current selected-policy Godot/Jolt production walker
unchanged and adds only a behavior-neutral complete trace. The exact reference
fixture receives either no impulse or one inherited `0.25 N s` positive-
lateral central torso impulse at SDK step `540`.

The evaluator requires an ordinary full-horizon walk, a complete safe gait
cycle before the impulse, a measured native velocity effect against the
same-seed baseline, re-entry within one `360`-step cycle, and another complete
safe gait cycle. A two-world route ghost on seed `50300` must close before the
six held-out baseline/push worlds on seeds `50301..50303`. The ghost need not
walk successfully; it must prove the real route can authorize, construct,
step, retain, pair, and evaluate its complete result.

Run the zero-world design audit from PowerShell at the repository root:

```powershell
python .\sdk\conformance\qsdk_r10a_bounded_upright_push_recovery_successor_design.py
```

The current expected terminal line begins
`QSDK_R10A_BOUNDED_UPRIGHT_PUSH_RECOVERY_SUCCESSOR_DESIGN_PASS` and reports
sixteen bound authorities, nineteen mutation controls, and zero physical
counts. This design authorizes R10B implementation only. It is not a push
positive, fall recovery, prone-to-standing, force-aware controller, other-
engine result, or release claim; `QSDK-R10`, `SDK1-M07`, and the scores do not
change.

## QSDK-R10B bounded upright-push zero-world implementation

The implementation selected by R10A is now present in seven executable layers:

- [`../scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd`](../scripts/lab/gait/qsdk_r10b_bounded_upright_push_recovery.gd)
  compiles the exact fixture and trace contract and evaluates individual worlds
  and same-seed baseline/push pairs.
- [`adapters/godot/gdscript/quaternion_scalar_projection_v1.gd`](adapters/godot/gdscript/quaternion_scalar_projection_v1.gd)
  applies R24D66's exact scalar-space projection and emits a complete,
  recomputable receipt without reading native state or changing behavior.
- [`../tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd`](../tests/test_sdk_qsdk_r10b_bounded_upright_push_recovery_worker.gd)
  exposes zero-world contract/preflight/pair modes and a separately authorized
  physical entrypoint.
- [`run_qsdk_r10b_bounded_upright_push_recovery.ps1`](run_qsdk_r10b_bounded_upright_push_recovery.ps1)
  serializes cells, retains complete evidence, and refuses physics unless the
  exact clean source, stage freeze, operation lock, execution authority, and
  one-shot durable output root all agree.
- [`conformance/qsdk_r10b_zero_world_implementation.py`](conformance/qsdk_r10b_zero_world_implementation.py)
  verifies the frozen R10A parent, recursive dependency closure, format and
  PowerShell parsing, source controls, entrypoints, and authorization boundary.
- [`qsdk_r10b_zero_world_qualification.ps1`](qsdk_r10b_zero_world_qualification.ps1)
  consumes one deterministic source-and-role qualification directory and
  retains its attempt, raw streams, parsed receipt, and terminal completion.
- [`conformance/qsdk_r10b_authority_materializer.py`](conformance/qsdk_r10b_authority_materializer.py)
  generates all per-file source bindings and the later parent-bound stage
  freeze and execution authority without a self-referential commit hash.

From PowerShell at the repository root, the development implementation audit is:

```powershell
python -B .\sdk\conformance\qsdk_r10b_zero_world_implementation.py
```

The expected line begins `QSDK_R10B_ZERO_WORLD_IMPLEMENTATION_PASS`. In
development mode R10B-L2 reports `77` qualified source paths, all eight frozen
cell entrypoints, two direct physical-bypass refusals, `9` invalid controls and
`2` valid finite-negative controls per source-gate execution, `4` valid
authority documents and `96` single-field authority rejections per source-gate
execution, one valid ordinal-order witness, reversed and duplicate order
refusals, and zero models, worlds, native readbacks, or solver steps. Its trace
controls also prove two retained raw-quaternion refusals, two corresponding
projected acceptances, two additional nonidentity projected acceptances, one
zero-quaternion refusal, one zero-input completion refusal, and three altered-
receipt refusals per source-gate execution.
`--official-qualification` additionally
requires every qualified path to be tracked and a clean `HEAD` equal to
`origin/main` and live GitHub `main`.

This gate has no physical-acceptance or release authority. It leaves
`QSDK-R10`, `SDK1-M07`, and both scores unchanged. A content-addressed official
qualification and stage freeze must exist before a two-world route ghost can be
authorized. The qualification commit may change only the stage-freeze file; its
child authorization commit may change only the execution-authority file. The
authority names the earlier source and qualification parents, while the
supervisor derives the authorization commit from the checked-out `HEAD`.

### R10B-L1 authority-check refusal and version-two repair

The first prospective graph used clean-pushed source `5f7ab1da`, freeze-only
commit `959bf78f`, and authority-only commit `881dc1f1`. Its official
qualification retained five files and `11,746` bytes, but the subsequent
`AuthorityCheck` failed before the operation lock or durable output directory.
The materializer's 69 paths were in ordinal order; the supervisor incorrectly
compared them against culture-aware `Sort-Object` output. All frozen blobs,
hashes, lengths, authority fields, flags, and cells otherwise matched. No model,
world, native read, solver step, or outcome occurred, and the v1 physical output
root remains absent.

[`qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json`](qsdk_r10b_development_route_ghost_authority_check_refusal_v1.json)
preserves the complete pre-physics classification and exact v1 bindings. It is
`4,668` bytes with SHA-256
`0196bdbcb8f914421edab305ca37e637708f8e35d5320f5c41fed827bfa9e230`.
The old authority is not reused. L1 validates strict ordinal adjacency directly
and adds positive, reversed, and duplicate-order controls. The refusal record is
also a materializer dependency. The distinct
[`qsdk_r10b_dependency_manifest_v2.json`](qsdk_r10b_dependency_manifest_v2.json)
therefore leaves the observed v1 manifest untouched and defines a new exact
closure containing `70` paths with digest
`sha256:76c421b1c1ab637046c847050fcc38d298f678cae4a6c875732bcf088941fc23`.

After L1 is committed, pushed, and officially qualified, the materializer must
create
[`qsdk_r10b_development_route_ghost_zero_world_qualification_closure_v2.json`](qsdk_r10b_development_route_ghost_zero_world_qualification_closure_v2.json)
as the only change in one commit, then
[`qsdk_r10b_development_route_ghost_execution_authority_v2.json`](qsdk_r10b_development_route_ghost_execution_authority_v2.json)
as the only change in its child. Those links intentionally remain absent until
their respective gates run. Physical execution stays blocked until the
version-two committed graph passes `AuthorityCheck`; no claim or score changes.

### R10B-L1-P1 consumed physical refusal

That forward graph is now complete: source `61783dbc`, stage `ac55feaf`, and
authority `1e595edd`. The official qualification contains five files and
`11,974` bytes, and the v2 `AuthorityCheck` passed. The physical invocation then
consumed its single-use root and completed one matched baseline world with
`2,880` physics ticks and `2,640` retained post-physics rows. It never opened the
pushed cell.

The worker refused the baseline as
`QSDK_R10B_TRACE_ROW_KINEMATICS_INVALID`. Direct reconstruction shows row zero's
serialized quaternion has length error `8.789622585325674e-9` against the fixed
`1e-9` validator; `2,566` rows fail, with maximum
`1.185268823089558e-7` at row `1889`. The other measured kinematic predicates
are finite and the task axes are exact. This is the same float32-to-exported-
scalar representation class already addressed and zero-world-qualified by
R24D66.

[`qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json`](qsdk_r10b_l1_development_route_ghost_physical_invalid_closure_v1.json)
and its
[`conformance audit`](conformance/qsdk_r10b_l1_development_route_ghost_physical_invalid.py)
bind all four retained files (`6,561,324` bytes), the exact marker payload, the
source graph, and the non-claims. The walking summary's lone false
`bounded_anchor_error` receipt is retained but inadmissible because the cell was
neither evidence-valid nor outcome-complete.

### R10B-L2 exact exported-scalar trace projection

[`qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json`](qsdk_r10b_l2_exact_quaternion_projection_successor_design_v1.json)
freezes the representation-only repair and binds both the consumed L1 closure
and R24D66's previously qualified method. The v2 trace policy now passes each
post-physics Godot quaternion through the reusable projection helper and retains
the original values, projected values, norms, deltas, method identity, and
provenance. The evaluator recomputes that receipt exactly before applying the
unchanged `1e-9` unit-length validator.

The complete development gate passes all retained and synthetic controls over
the exact `77`-path dependency closure. It makes no controller, fixture,
challenge, impulse, behavior-threshold, seed, or population change and opens no
physical state. The next legal sequence is one source commit and push, official
clean-source qualification, a stage-freeze-only child, an authority-only child,
and a passing committed-graph `AuthorityCheck`. Until those close, no new
physical run is authorized and scores remain `13/20` and `13/25`.

### R10F-L1 immutable pre-physics refusal and v2 source boundary

[`qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v1.json`](qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v1.json)
preserves the first R10F physical-mode supervisor refusal. A physical-only Git
changed-path expression bound `-split` as a nonexistent parameter. The
supervisor stopped before creating its authority-derived evidence root and
recorded zero models, world attempts, builds, native reads, solver steps, or
outcomes. The v1 identity is unconsumed, but its freeze and authority are
retired and may not be invoked again.

[`qsdk_r10f_dependency_manifest_v2.json`](qsdk_r10f_dependency_manifest_v2.json)
contains the 83-path forward source closure, including the retired v1 freeze,
v1 authority, and `6,012`-byte refusal. Its path-set SHA-256 is
`2af915e6a92e978499f20268c4a259674f016bb3e520834043c1afbc599cc1de`.
The repaired supervisor passes the complete development zero-world audit and
executes the exact line-projection function under positive and empty controls.
This source has no physical authority until a new official qualification, v2
freeze-only commit, v2 authority-only commit, and committed-graph check close.

### R10F-L2 exact Boolean changed-path comparison

[`qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json`](qsdk_r10f_development_route_ghost_physical_supervisor_refusal_v2.json)
preserves the second R10F pre-physics supervisor stop. The L1 projection ran,
but the following unenclosed `-join` yielded a string for a Boolean assertion.
No output root, model, world, native read, solver step, or outcome was created.
The v2 identity remains unconsumed, while its freeze and authority are retired.

[`qsdk_r10f_dependency_manifest_v3.json`](qsdk_r10f_dependency_manifest_v3.json)
binds 86 paths, including both retired graphs and refusals, at path-set SHA-256
`5699c24fbf3fac417b9c7a3a6233872e846ecd64f85d8db1797d5fbf1c4d331a`.
The supervisor now delegates exact ordinal array equality to one pure Boolean
function. The actual verifier and five zero-world set controls use that exact
function. The full engine-backed development audit passes with every physical
counter zero. A fresh official qualification and separate v3 freeze and
authority commits remain prerequisites to any new physical identity.

### R10F-L2-P1 consumed initial-application refusal

The completed v3 graph ran its single development invocation and retained four
files / `13,869` bytes. The baseline constructed one model and world, then
failed `QSDK_R10F_INITIAL_APPLICATION_INVALID` with zero solver steps. The
[`v3 closure`](qsdk_r10f_development_route_ghost_physical_closure_v3.json)
classifies it as consumed invalid/incomplete with no behavioral conclusion.

The worker passed an actuation-free bootstrap intent to
`behavior_application_receipt_valid_v4`, the consumer for wrapped active
applications. Its required schema chain and application fields cannot describe
that bootstrap; R153's retained zero-world path uses a separate initial
predicate. The consumed identity cannot rerun. A successor must add an exact
bootstrap consumer, prove the physical producer/consumer composition at zero
worlds, preserve richer setup-failure detail, and complete a new clean graph.
No physical authority is currently open.

### R10F-L3 exact bootstrap consumer and v4 source closure

The worker now calls
`initial_bootstrap_application_validation_v1` only for the actuation-free
intent returned during arm construction. It continues to call
`behavior_application_receipt_valid_v4` for later active applications. The
bootstrap validator checks the exact base schema and semantic boundary,
initializer command, recovery controller, all eight disabled motor intents,
solver-coupled realization, discrete-staging energy route/authority, and R152
provenance. A failed setup returns the complete initial application plus the
predicate receipt; a valid arm retains the same receipt for later closure.

`zero_world_contract_v2` exercises the physical producer and new consumer over
eight detached joint command surfaces. It proves the active consumer rejects
that valid bootstrap and refuses six altered bootstrap receipts. The complete
development audit passes 25 source tests, 16 positive cases, 48 forced
failures, 27 walking receipts, 16 materializer mutations, 15 physical-closure
mutations, the PowerShell supervisor controls, and real Godot parser/zero-world
execution with every physical counter zero.

[`qsdk_r10f_dependency_manifest_v4.json`](qsdk_r10f_dependency_manifest_v4.json)
binds 90 exact paths at path-set SHA-256
`77a1e3c71f27d4f958b652556e34a418a00a6503c77219ff1cf81849b9ab88f3`.
The new authority toolchain also binds and reauthenticates the immutable
[`L2-P1 physical closure`](qsdk_r10f_development_route_ghost_physical_closure_v3.json)
at SHA-256
`2be7bfb9bc96f744a6ffcdc6b6b7a304142739a782cf209b6062ab9ad10c1717`.
The predecessor remains consumed, invalid/incomplete, one-world, zero-step,
and non-behavioral. L3 source must still be clean-pushed and live-equal before
one official qualification, v4 freeze, v4 authority, and graph check can
authorize a new development attempt. No current physical authority exists.

### R10F-L3-P1 consumed first-step compact-geometry refusal

The clean v4 graph `08c84b28` / `410947d0` / `6fe4677b` ran once and consumed
attempt `582dc98b83104b2ebf1f348d00b28137`. Both models and worlds built. The
matched-no-kick arm completed one native solver frame, then the worker returned
`QSDK_R10F_NATIVE_STEP_INVALID:matched_no_kick_continuation` while retaining
the first compact trace row. No kick was applied and the behavior evaluator
was not invoked.

[`qsdk_r10f_development_route_ghost_physical_closure_v4.json`](qsdk_r10f_development_route_ghost_physical_closure_v4.json)
binds the four-file, `13,946`-byte population. The closure is `4,797` bytes at
SHA-256
`09d084a2639bca7a6c7f6c6e3b2f75c6dce596067eff11a94c1d838972bd31f2`
and classifies the identity as consumed invalid/incomplete with no behavioral
conclusion. The bound supervisor report's exact physical counters are two
model constructions, two world attempts, two world builds, and one solver
step.

`recovery_native_world_v1` emits `axis_parent_local` for its shared planar
hinge axis but does not emit `axis_child_local`. The R10F
`_joint_geometry_summary_v1` helper required both, so the absent child key
returned an unstructured `{"ok": false}` even though collection had
completed. A distinct L4 must repair that consumer without changing the
historical producer, retain exact failure projections, and prove the source
shape under the zero-world gate. The v4 identity cannot rerun. M07, kick/push
recovery, force-aware recovery, support claims, and scores `14/20` and `14/25`
remain unchanged; no physical work is authorized.

### R10F-L4 compact-geometry source integration and v5 closure

The worker now calls `_joint_geometry_summary_v2(model, observation)` after a
completed native collection. The v2 consumer requires the selected recovery
world's exact seven joint-state keys and refuses an injected
`axis_child_local`. It reuses each ordered observation row's finite,
nonnegative, source-measured `anchor_error_m`. For hinge-axis error it treats
the producer's `axis_parent_local = Vector3.BACK` as the shared planar local
axis and projects it through the current parent and child bases. This preserves
the intended two compact geometry measurements without changing any
acceptance threshold or using an outcome-derived correction.

The consumer verifies all eight joint bindings against the native blueprint,
body/joint maps, and node metadata. Every rejected shape returns a versioned
failure projection with an exact code, joint ID where available, and failed
field list. Its zero-world fixture builds nine detached `RigidBody3D` and eight
detached `HingeJoint3D` declarations from the real blueprint, never adds them
to a scene tree, and rejects sixteen malformed source variants after accepting
the exact historical shape. A rotated-child canary proves the axis result is a
measurement rather than a hard-coded zero.

[`qsdk_r10f_dependency_manifest_v5.json`](qsdk_r10f_dependency_manifest_v5.json)
binds 94 exact paths at path-set SHA-256
`6f59733c768afc605849fa5c1fc531b6dd4a3158d985a0a55f17d0a094bf3681`.
It binds the immutable 4,797-byte
[`L3-P1 closure`](qsdk_r10f_development_route_ghost_physical_closure_v4.json)
at SHA-256
`09d084a2639bca7a6c7f6c6e3b2f75c6dce596067eff11a94c1d838972bd31f2`
and therefore also its direct L2-P1 predecessor binding. The complete L4
development audit passes 27 source tests, 16 positive controls, 64 forced
failures, 27 walking receipt fields, both authority-tool mutation suites, both
PowerShell boundaries, and real Godot parse/zero-world execution while every
physical counter remains zero.

This source repair neither rehabilitates either invalid result nor establishes
a walking or recovery outcome. It changes no policy, fixture, kick,
controller, threshold, seed, or population. One official qualification,
separate v5 freeze and authority commits, and an exact committed graph are
still required before a new physical development identity can exist. M07,
kick/push recovery, force-aware recovery, support claims, and scores `14/20`
and `14/25` remain unchanged.

### R10F-L4-P1 physical closure and L5 counter projection

L4 completed its clean source, official qualification, v5 freeze, v5
execution authority, and committed-graph sequence. The exact commits are
source `c44f013af86471e7c2726b8d6e1ff2c0615e7ed4`, freeze
`64304d9c6e5f4413e0a65a3b2417b655efebf9e2`, and authority
`0496fc01b957a677c53671277e72bc80268d2b05`. The authority blob is 2,224 bytes
at SHA-256
`a7a083c942b20f03a80a22b4479d6bc423141f59279f302fe70a39f0ea8b885f`.

Its one attempt, `d22b350814794d12927fe3f21003ef97`, built two models and
two worlds and completed four solver steps. Reaching the second lockstep frame
means the first completed row for both arms crossed L4's repaired geometry
consumer. The second baseline collection then stopped before retention with
inner code `QSDK_R10F_COLLECTOR_SOLVER_STEP_COUNT_INVALID`; the route projected
outer code `QSDK_R10F_NATIVE_STEP_INVALID:matched_no_kick_continuation`. The
worker emitted a valid raw invalid/incomplete receipt, stderr was empty, and
the supervised termination protocol passed.

The source contract is unambiguous: `sample_native_step_v1` assigns
`solver_step_count = semantic_step`. The wrapper retains that cumulative value
unchanged. The R10F worker incorrectly treated it as a per-call count: it added
the whole value to `_total_solver_step_count` and required the value itself to
equal `1`. Global step one passed; global step two returned `2` and failed.

The immutable 4,797-byte
[`L4-P1 closure`](qsdk_r10f_development_route_ghost_physical_closure_v5.json)
has SHA-256
`b862561d0db78c03533a5d7121b4380b9c96507fe37adab2e2a046785d98dd74`.
It binds all retained files and every authority in the chain, records zero kick
and evaluator invocations, and carries no behavior conclusion. The consumed
identity cannot run again.

L5 will add a versioned fail-closed counter projection: the source counter must
be an exact integer equal to the current global semantic step, while its
accepted contribution to the cross-arm aggregate is separately and explicitly
one. Detached controls must accept at least consecutive steps one and two and
reject stale, skipped-ahead, missing, Boolean, floating, and text counters.
The producer, physics world, policy, controller, kick, thresholds, seed,
population, and outcome evaluator remain frozen. A new zero-world/
qualification/freeze/authority graph is required before more physics. M07,
support claims, and scores `14/20` and `14/25` remain unchanged.

### R10F-L5 cumulative-source projection and v6 zero-world closure

The worker now authenticates the collector's cumulative count before turning
an accepted collection into an aggregate step. The versioned projection
requires the exact native collection schema and gate, exact Boolean success
and unchanged-global flags, a positive expected global step, integer
collection/global counters, and exact agreement of all three sequence values
with `G`. It retains the source cumulative values and emits a separate
`completed_step_delta=1`; `_total_solver_step_count` adds only that delta.
Compact invariants bind both semantics and forbid outcome-derived correction.

Pure controls accept `G=1` and `G=2`, prove an accepted-delta sum of two, and
reject sixteen schema, flag, type, sequence, and retained-wrapper mutations.
The complete audit passes 29 source tests, 16 outer positives, 80 forced
failures, the 16/18 authority-tool mutation suites, both PowerShell controls,
real Godot parse, and real Godot zero-world execution with every physical
counter zero.

The [98-path v6 manifest](qsdk_r10f_dependency_manifest_v6.json) has path-set
SHA-256
`80c56eac99c4d3912617db56ffa5e03580a9ba742ef68cd5e4ca11657948626d`.
It binds the consumed L4-P1 closure at SHA-256
`b862561d0db78c03533a5d7121b4380b9c96507fe37adab2e2a046785d98dd74`
and preserves the earlier chain. The producer, model, policy, controller, kick,
thresholds, seed, population, and evaluator are unchanged. This is still
zero-world implementation evidence; a clean pushed source and separate v6
qualification/freeze/authority graph are prerequisites for another physical
development identity. M07 and scores `14/20` and `14/25` remain unchanged.

### R10F-L5-P1 consumed physical closure and L6 barrier selection

The one official L5 qualification bound source
`646889b122803a253c55dad5d31f0b96c01131ba` and all 98 v6 manifest paths.
Its committed freeze SHA-256 is
`8a41727f29d103f87e88bbc8342616157010c488cd0c22334c0c155355ecb982`;
its single-use authority SHA-256 is
`cfaf6e803e9e50fc02d185e87991457c0125d6ef00c715b9ce907b4516b821ff`.

Attempt `a2222fbedc0c40d0afb35372edfb03b6` constructed exactly two models
and two isolated worlds. At global frame 240, after 480 accepted arm
collections, the baseline V6 controller reported a stable-standing terminal
while the active V6 controller remained nonterminal. The engine was healthy,
stderr was empty, and supervised termination was valid. The outer failure was
`QSDK_R10F_NEXT_FRAME_PLAN_INVALID`; its exact inner reason was
`QSDK_R10F_PRECONDITION_NOT_LOCKSTEP`. No walking, kick, or evaluator ran.

The [v6 physical closure](qsdk_r10f_development_route_ghost_physical_closure_v6.json)
is 4,774 bytes at SHA-256
`fb4879cc6645d60fcb71eeb1d618e4a5453f4c2386b1d45cc1d838e4775d6863`.
It retains all four evidence files and classifies the identity as
`invalid_or_incomplete_no_behavioral_conclusion`. The result supplies neither
a positive nor a valid complete negative and may never rerun.

The prospective
[L6 design](qsdk_r10f_l6_precondition_pair_barrier_successor_design_v1.json)
adds a bounded precondition pair barrier. Readiness must be proven by each
arm's own unchanged V6 terminal receipt. While only one arm is ready, that arm
continues to take measured solver steps under an explicit ledger intent that
verifies all eight native motors disabled and zero target velocity; the other
arm continues its unchanged V6 control. When both independent receipts exist,
both orchestrators release together and both fresh BW5R-B prefix sessions
begin at the same next global boundary. The barrier may not copy readiness,
skip native steps, pause a world, rewrite state, change a threshold, or use a
later outcome. A new v7 source and authority graph are required before any
physical successor.

### R10F-L6 source-bound pair barrier and v7 development closure

The new
[`qsdk_r10f_precondition_pair_barrier_v1.gd`](adapters/godot/gdscript/qsdk_r10f_precondition_pair_barrier_v1.gd)
is a pure arm-local readiness and pair-global release state machine. The
orchestrator feeds it only unchanged V6 terminal sources. The worker keeps an
early-ready world stepping under a separately validated no-actuation
application, then applies one no-actuation release frame to both worlds before
starting both fresh 720-step walking-prefix clocks together.

Every wait/release application verifies all eight hinge motors disabled, zero
target velocity, a finite positive configured maximum-impulse readback, and
matching native state. Because the motors are disabled, that retained cap is
not treated as applied motor impulse. The
worker retains the complete pair state, source receipt for each arm, ordered
applications, and content bindings. The future physical-closure compiler
independently validates those fields and their cross-links rather than relying
on a single success flag.

The [v7 manifest](qsdk_r10f_dependency_manifest_v7.json) binds 104 source,
build, test, and process paths at path-set SHA-256
`62e34fd2219e89376ffc5f12aa81e7ea9999012584fd94f4c9c1616e70035826`.
It binds the L6 design at SHA-256
`297890d556da580e9cabe4a2e98de796f51982fb2dd966411b98e579007abd87`
and the consumed L5-P1 physical closure at SHA-256
`fb4879cc6645d60fcb71eeb1d618e4a5453f4c2386b1d45cc1d838e4775d6863`.

The complete development audit passes 31 Python source tests, 17 positive
zero-world compositions, 92 forced failures, 18 future-authority mutations,
and 25 future-closure mutations. Real Godot parse and detached zero-world
execution pass with zero model, world, native-read, solver-step, kick, or
evaluator activity.

This source has not yet passed its one official v7 qualification and no v7
freeze or execution-authority file exists. It advances no recovery or release
claim. M07, `external_push_recovery`, force-aware recovery, and scores `14/20`
and `14/25` remain unchanged.

### R10F-L6-P1 consumed closure and L7 terminal-disposition selection

L6 source `7b04469c1abfdb0bb1412a5e1c3de0323784823c` passed the official
qualification. Freeze `1730edf469c6b6abc002f016439a4fb1a4e89bc8` and authority
`f1c8d15b6cf15cf0fe2e3583f39365b2c9c9e0b8` opened one physical
identity. Attempt `83eca22b4c53471caeff136a17559161` built both worlds and
completed 300 common frames / 600 arm solver steps.

The baseline retained its V6 complete source at frame 240 and then emitted 60
valid `no_actuation_wait` applications. The active arm never became
barrier-ready and reached a non-complete terminal at frame 300. The worker's
preexisting generic terminal branch returned
`QSDK_R10F_TERMINAL_FRAME_NOT_LOCKSTEP`; because invalid output did not retain
per-arm terminal state, the exact active V6 reason is unavailable.

The [`v7 physical closure`](qsdk_r10f_development_route_ghost_physical_closure_v7.json)
is 5,154 bytes at SHA-256
`842af3fab4aa80d1cea43e5a59391978708206174362837c9aeb99ca417d9517`.
It preserves the four durable attempt files and classifies the identity as
`invalid_or_incomplete_no_behavioral_conclusion`. No walking, kick, or
evaluator ran, and the identity may never rerun.

The new
[`L7 design`](qsdk_r10f_l7_precondition_terminal_disposition_retention_successor_design_v1.json)
is 11,508 bytes at SHA-256
`1f1288acb506c39347e33ca6c6f0c86749caaf955f83dce71836cd8100f98c3b`.
It requires a typed per-arm disposition and full source-bound V6 diagnostic on
every precondition terminal. Complete terminals still feed L6 readiness;
failed/refused terminals stop without another step and retain the peer's last
state. The future closure must validate the diagnostics independently. No
physical or behavioral term changes, and no L7 physical authority exists.

### R10F-L7 source-bound terminal disposition and v8 development closure

The new
[`qsdk_r10f_precondition_terminal_disposition_v1.gd`](adapters/godot/gdscript/qsdk_r10f_precondition_terminal_disposition_v1.gd)
retains what both arms actually reported at the last completed precondition
frame. Its four exact dispositions distinguish a complete L6 readiness source,
a failed V6 terminal, a refused V6 terminal, and the peer's still-nonterminal
last completed state. Each receipt binds the arm/model, source steps, V6
memory, step receipt, classification, terminal reason, and unreleased pair
state with canonical digests.

The worker processes this typed boundary before generic whole-route terminal
pairing. Failed/refused preconditions emit
`QSDK_R10F_PRECONDITION_TERMINAL_DISPOSITION_RETAINED`, retain both arms, and
allow no next solver frame. Complete preconditions continue through the
unchanged L6 barrier. The physical closer independently validates the full
receipt population instead of trusting its summary fields.

The [v8 manifest](qsdk_r10f_dependency_manifest_v8.json) binds 110 paths—36
transitive GDScript/resources, 25 Rust/build inputs, and 49 process/audit
paths—at path-set SHA-256
`6a2ae00ea1e278506180ab3a2c4f1b43343b6424c5c095e7450dbd9193357da5`.
The development audit passes 33 source tests, 18 positive compositions, 108
forced failures, 18 authority-materializer mutations, and 45 physical-closure
mutations. L7's focused share is six positive cases and sixteen corruptions.
Real Godot parse and detached zero-world execution pass with zero physical
activity.

This source has not consumed its one official v8 qualification, and the v8
freeze and execution-authority files do not exist. No physical identity is
open. M07, `external_push_recovery`, force-aware recovery, support, release,
and scores `14/20` and `14/25` remain unchanged.

### R10F-L7-P1 consumed closure and L8 integer-valued native step design

L7 completed its qualification/freeze/authority sequence and consumed attempt
`0485211cfa1049e6bdee374b406d0c32`. Both native worlds built and each
advanced once. Before walking or kick logic, the terminal-disposition builder
returned `QSDK_R10F_L7_PRECONDITION_DISPOSITION_BUILD_INVALID`.

The evidence is unusually precise. The retained V6 memory field
`last_semantic_step` is binary64 `1.0`; the enclosing L7 expected step is
integer `1`. The numbers are finite, integral, equal, and content-address to
the same canonical value. The original L7 type check nevertheless accepted
only an integer Variant. The post-physical closer now validates that exact
receipt and number-kind mismatch independently; its self-test covers five
report classes and rejects 55 mutations.

The 6,118-byte
[`v8 physical closure`](qsdk_r10f_development_route_ghost_physical_closure_v8.json)
has SHA-256
`15cf3bdd5485405613726be8c800c5e46f4178a818ae89b947efc992e3094aba`.
It binds two worlds, two solver steps, no kick, no evaluator, no valid route,
and no behavioral conclusion. The L7 identity cannot rerun.

The 10,173-byte
[`L8 design`](qsdk_r10f_l8_integer_valued_native_step_domain_successor_design_v1.json)
at SHA-256
`4d34973a0f2c77696d8e1036e3650f0f877fef21ce67f72b470d0fec80156039`
allows a zero-world implementation to accept that one discrete memory field as
either an exact integer or an integer-valued binary64 number. The binary64 form
must be finite, integral, within steps 1 through 3,842, and equal to the bound
expected step; its original source representation must remain retained. All
other types and values fail. No controller, threshold, horizon, model, kick,
seed, evaluator, schedule, or budget changes. No L8 physical authority exists,
and M07, `external_push_recovery`, force-aware recovery, support, release, and
scores `14/20` and `14/25` remain unchanged.

### R10F-L8 source-preserving native step validation and v9 development closure

The terminal-disposition module now validates the native
`recovery_memory.last_semantic_step` as a discrete number domain instead of
requiring only the integer Variant kind. It accepts either an exact integer or
a finite, integral binary64 number from 1 through 3,842 when—and only when—the
value exactly equals the bound expected step. It retains the original source
number. Fractions, nonfinite values, out-of-domain or mismatched values,
Booleans, strings, nulls, missing fields, source rewrites, digest corruption,
and outcome-derived correction fail.

The L7 schema and component repair ID stay intact. L8 is the consuming
validator. The future physical closer independently applies the same rule and
preserves number kind in its diagnosis.

The [v9 manifest](qsdk_r10f_dependency_manifest_v9.json) binds 115 paths—36
transitive GDScript/resources, 25 Rust/build inputs, and 54 process/audit
paths—at path-set SHA-256
`416b50c5e11380a3acebe6d4d9fc04407e5602cd59a4bc7b52f00f3cb56e44a3`.
The complete development audit passes 34 source tests, 19 positive
compositions, 124 forced failures, 18 materializer mutations, five closer
report classes, 55 closer report mutations, and 15 closer numeric/source-domain
mutations. Pinned Godot parse and detached zero-world execution pass with zero
physical activity.

This exact source still requires its single official v9 qualification, a v9
freeze-only commit, a v9 authority-only commit, and a passing committed graph
before at most one physical identity. M07, `external_push_recovery`,
force-aware recovery, support, release, and scores `14/20` and `14/25` remain
unchanged.

### R10F-L8-P1 consumed closure and L9 process-isolated matched-arm design

L8 subsequently completed the official qualification, freeze, and authority
sequence and consumed attempt `2f418dc12e934bf1a10add729f3554fe`.
The two native worlds each completed 300 solver steps. The first-built
`matched_no_kick_continuation` arm reached V6 complete at step 240 and emitted
60 valid motor-disabled waits. The second-built
`kick_passive_recovery_resume` arm retained
`phase_timeout:stance_dwell` at step 300 while raised and upright but above the
frozen motion limits. No walking prefix, kick, passive fall, recovery resume,
or evaluator ran.

The 6,317-byte
[`v9 physical closure`](qsdk_r10f_development_route_ghost_physical_closure_v9.json)
at SHA-256
`29ef1f7c2db408a2fd09f378e057648825eac2c1e856932dd2ed259829bdadde`
binds the source/freeze/authority graph, four-file durable evidence population,
600 solver steps, 60 wait applications, 1,440 wait-path native readbacks, zero
kicks, and zero evaluator calls. It classifies the identity as consumed,
invalid/incomplete, and behaviorally inconclusive.

The retained L6 identity repeats the first-built-success / second-built-stop
pattern, and its first-built terminal memory and classification exactly equal
L8's. The serial R172 candidate also completed at step 240 with that same
source. R10F used separate non-colliding `World3D` spaces but advanced both in
one process. This localizes an uncontrolled execution-topology variable without
identifying construction order, concurrent multi-space scheduling, or an
engine defect as the cause.

The 19,530-byte
[`L9 design`](qsdk_r10f_l9_process_isolated_matched_arm_successor_design_v1.json)
at SHA-256
`0fc68c2f895afa52a3835d55c0508bc5490b1af98c5da3761eb774aed702f41e`
selects two serialized fresh Godot children, one declared arm and one native
world per child, under one fail-closed aggregate supervisor. It keeps the full
matched comparison and every physical/behavioral term unchanged. Only L9
implementation and zero-world falsification are authorized; there is no L9
physical identity. M07, `external_push_recovery`, force-aware recovery,
support, release, and scores `14/20` and `14/25` remain unchanged.

### R10F-L9-P1 terminal receipt refusal and L10 nullable source design

L9 source `c94a596e731a1899f6e798fe8e9ec0b9e74c9cbc` added the process-isolated
child contract, one-arm worker, serialized supervisor, aggregate evaluator,
v10 manifest, authority materializer, and physical closer. The 122-path
development gate passed 20 positive compositions and 155 forced failures,
plus its source and mutation suites, with no physical activity. Separate
freeze `f82a527b99f5c3b2ed9c94e14853f759d30c9658` and authority
`776cfd2f0a67c50676e8959312bae7ef1aa09bd3` then opened one attempt.

The first child reached the V6 `complete` memory at solver step 240. When the
child contract built the terminal receipt, it called `String(...)` on the
memory's `terminal_failure_code`. Successful Rust recovery memory serializes
that optional field as JSON null, so the constructor failed before finalizing
the child. The supervisor retained the partial report and stopped before the
active child. There was one model, one world, 240 steps, no kick, no walking
segment, no evaluator, and no behavioral outcome.

The 8,646-byte
[`v10 closure`](qsdk_r10f_development_route_ghost_physical_closure_v10.json)
at SHA-256
`7a5b61ec898b9c5b2891911101d34c3cefe7a6c5657a7c6abdea45e6b4299464`
consumes the identity as invalid/incomplete and preserves the partial stable
stance only as diagnostic data.

The 16,553-byte
[`L10 design`](qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1.json)
at SHA-256
`2d186f41fcb73427ef7021a1050e4175791784212bfb9c219d712595370a4817`
requires an explicit two-form projection: null for complete memory, and an
exact nonempty string for failed/refused memory. It preserves the nested source
value and digest and rejects generic Variant conversion. This is a development
consumer repair only. L10 physical execution, M07,
`external_push_recovery`, force-aware recovery, support, release, and score
changes remain unauthorized.
