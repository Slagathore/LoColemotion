# SporeSpore MuJoCo adapter

This is the third physics-host adapter for the engine-neutral locomotion SDK.
It uses the official MuJoCo Python wheel from a project-local Python 3.11
environment and calls the same checked-in C ABI as the Godot and Rapier hosts.

From PowerShell at the repository root:

```powershell
python -m venv .\sdk\adapters\mujoco\.venv
.\sdk\adapters\mujoco\.venv\Scripts\python.exe -m pip install `
  -r .\sdk\adapters\mujoco\requirements-lock.txt
cargo build --manifest-path .\sdk\Cargo.toml `
  --package sporespore-locomotion-core --release --offline

Push-Location .\sdk\adapters\mujoco
.\.venv\Scripts\python.exe -m unittest -v
.\.venv\Scripts\python.exe -m sporespore_mujoco_adapter.conformance
.\.venv\Scripts\python.exe -m sporespore_mujoco_adapter.characterization `
  --preflight-only
Pop-Location
```

An evidence run may append
`--output C:\path\to\evidence\report.json`. The runner refuses to overwrite an
existing report.

The adapter maps canonical `(X forward, Y up, Z right)` vectors to MuJoCo's
Z-up frame as `(x, -z, y)`. Its capability manifest is fail-closed. Passing
C0-C5 does not establish locomotion, material robustness, balance, or physical
acceptance.

## Exact-s169 public actuator-cap mapping

R23D61 adds a configuration-only mapping for the versioned public profile
`sporespore_qsdk_r23d60_selected_s169_actuator_cap_profile_v1`. Each portable
cap is the maximum angular impulse for a complete `1/120 s` outer control step.
The MuJoCo adapter maps it to a symmetric velocity-actuator `forcerange` by
dividing by the outer-step duration; five internal `1/600 s` limits then sum to
the same outer budget. The pure mapping also emits production-shaped ordered
XML fragments.

Run its focused zero-world test from the repository root:

```powershell
$env:SPORESPORE_LOCOMOTION_LIBRARY = `
  (Resolve-Path ".\sdk\target\debug\sporespore_locomotion_core.dll")
Push-Location ".\sdk\adapters\mujoco"
try {
  python -m unittest -v test_actuator_cap_profile.py
} finally {
  Pop-Location
}
```

The canonical cross-adapter runner is
[`../../run_qsdk_r23d61_zero_world_gate.ps1`](../../run_qsdk_r23d61_zero_world_gate.ps1).
This path does not import MuJoCo, construct a model, step a solver, or establish
force response, locomotion, turning, equivalence, or physical acceptance. An
exact descriptor is supported; other valid descriptors are explicitly OOD, and
unknown profiles are refused without fallback.

The C6-HC1-R2 host-characterization entry point separately measures the exact
preregistered discrete breakaway, steady-slide, and force-limited actuator
grid. R1 uses the same shape-derived `1 kg` cuboid mass/inertia fixture as
Rapier and validates those properties before its first motor step. R2 retains
that body and uses MuJoCo's documented `implicitfast` integration for the
position actuator's `kv` damping; material cells remain on frozen Euler. A
retained characterization report still grants no controller-policy,
locomotion, cross-engine C6, robustness, release, or physical-acceptance
authority. Every declared cell is attempted, and a negative report is written
before the command exits unsuccessfully. R2 is now closed with Rapier and
MuJoCo each passing all `28/28` declared cells; the supervisor still permits
zero-world preflight audits but refuses another physical R2 execution.

Current API authorities:

- https://mujoco.readthedocs.io/en/stable/python.html
- https://mujoco.readthedocs.io/en/stable/XMLreference.html
- https://mujoco.readthedocs.io/en/stable/APIreference/APIfunctions.html

## Current C6 host boundary

The adapter's latest host attempt, `C6-MJC-HC-VH3`, completed all 24 exact
finite worlds and 43,200 state traces from clean pushed source `57e97f2`, but
it is closed temporal-instrumentation-invalid. The implementation sampled
`actuator_force` and `qfrc_actuator` only after copying the post-`mj_step` state
and calling `mj_forward`, then treated post-state force times `dt` as the
completed-step impulse. Those fields do not witness the during-step quantity
required by the preregistered saturation and impulse gates.

The frozen evaluator printed `22/24`; both apparent failures nevertheless
converged exactly. A report-only, zero-world momentum reconstruction finds
capped steps in `24/24` cells and the expected `0.01 N m s` maximum motor
impulse. That is development information, not a retroactive pass. The next
host identity must retain separate pre-integration force and post-integration
state samples and cross-check impulse through one-DoF momentum balance before
selected-policy MuJoCo walking can begin.

## Prospectively frozen VH4 temporal correction

`C6-MJC-HC-VH4` is now the distinct, zero-campaign-world successor. It keeps
VH3's exact 24-cell grid, five `1/600 s` internal steps per `1/120 s` portable
controller command, force cap, horizon, and all-cell rule. It changes only the
measurement implementation and the gates needed to prove that implementation:

- `mj_step1` establishes the pre-integration state and generalized inertia;
- control and external torque are then applied before `mj_step2`;
- completed-step `actuator_force` and `qfrc_actuator` are captured immediately
  after `mj_step2`, before any copied-state `mj_forward`;
- post-integration position/velocity and explicitly labeled post-state force
  are retained separately; and
- effective motor impulse is independently reconstructed from the one-DoF
  momentum balance.

For saturated rows, pre-step force times `dt` must equal realized motor
impulse. For unsaturated `implicitfast` rows, pre-step force times `dt` is
retained only as a conservative force-time budget; the exact scalar fixture
requires momentum-inferred impulse to match post-state force times `dt`.

The zero-world production preflight accepts a perfect 43,200-row report and
rejects 23 negative controls, including pre/post-force substitution and both
momentum-relation corruptions. Five binding canaries pin `M`, reject `qM`, pin
`mj_fullM`, and require `mj_step1`/`mj_step2`. An ordinary two-step non-campaign
regression also reproduced the exact saturated and unsaturated relations. None
of this is a VH4 physical result: no VH4 campaign world has opened, MuJoCo is
not yet claimed to walk, and selected-policy C6 remains blocked.

## VH4 positive exact-finite host result

The prospectively frozen source above was committed and pushed as `2722c2b`,
passed the complete Godot-including suite, and received exact-source V2
attestation SHA-256
`8e609e03c79baaefedb776f606fe1b194580fb61d29b7fe4c2e7f49718a433f1`.
Its one permitted physical process then passed all `24/24` cells and retained
all `43,200` temporally explicit trace rows.

The result contains 114 saturated internal steps. Every cell has 40--43
pre-step/post-state force distinction witnesses. Both saturated force-time and
unsaturated post-state force-time agree with the independent momentum balance;
the maximum errors are approximately `3.47e-18` and `8.94e-18 N m s`.
All integrity violation and mismatch counts are zero.

The immutable closure is
`sdk/mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json`.
This is a positive host characterization for the exact finite profile and grid.
It is not selected-policy locomotion or walking. The next allowed step is a new
campaign carrying unchanged BW19V through this characterized host profile.

## Selected-policy development bridge

The adapter now contains a real selected-policy development path:

```powershell
Push-Location .\sdk\adapters\mujoco
.\.venv\Scripts\python.exe -m `
  sporespore_mujoco_adapter.selected_policy_development `
  --schedule lc1
Pop-Location
```

Use `--base-only` for the matched controller without the portable stability
contribution, or `--schedule clocked --steps 480` for a shorter smoke run. The
command constructs and advances a real MuJoCo articulated world. It is a
development/debug launcher, not a retained evidence runner, selector, or
one-shot campaign.

The default host profile uses the selected morphology's exact per-actuator
native force limits. The profile is intentionally named
`mujoco_per_actuator_force_limited_five_substep_development_v1` and reports no
host-response, walking-claim, or physical-acceptance authority. The older
characterized VH4 profile has a uniform `6 N m` fixture cap; using it on the
selected robot fails closed if it violates a morphology-specific portable
impulse budget. Do not reinterpret VH4 or use the development launcher as a
MuJoCo C6 claim.

The full development schedule has produced repeated four-foot contact cycles,
about `1.806 m` forward displacement, low lateral drift, bounded tilt, no torso
ground contact, and zero native-force or portable-impulse violations. This is
functional real-physics walking for engineering purposes. VH5 has now closed
the distinct per-actuator host characterization positive; scientific promotion
still requires a separately frozen selected-policy campaign.

## Closed positive s169 per-actuator host characterization VH5

`C6-MJC-HC-VH5` freezes the missing exact host-profile question without moving
the controller. It reuses VH4's split-step, temporal-force, generalized-inertia,
and momentum-reconstruction primitives under a new campaign/evaluator identity.
VH4 itself remains fixed at a default `6 N m`; VH5 passes an alternative limit
to shared trace evaluation only after its declaration and compiled descriptor
receipt agree.

The finite grid uses four native force limits:

| s169 actuator class | Native limit |
|---|---:|
| front hip | `6.435150204824762 N m` |
| front knee | `5.265122894856622 N m` |
| rear hip | `6.764849795175239 N m` |
| rear knee | `5.534877105143378 N m` |

Each class receives all twelve signed target/load cells at both zero and
adverse initial velocity: `96` worlds, `48` mirrored pairs, and `172,800`
17-field internal traces. All cells and pairs must pass. The zero-world
production preflight accepts a perfect serialized report, rejects `24`
negative controls, reconstructs all four limits from the real compiled s169
descriptor, and checks five binding canaries. Four ordinary class-specific
qualification cells passed after that preflight; they grant no evidence or
physical authority.

The exact source passed full Godot-inclusive conformance, then the one permitted
physical process completed all declared worlds. Audit the retained closure from
the repository root with:

```powershell
pwsh -NoProfile -File `
  tests\test_mujoco_c6_s169_per_actuator_force_limit_host_characterization_vh5_closure.ps1
```

All `96/96` cells, `48/48` mirrored pairs, and `172,800/172,800` temporal
traces passed. The report retained `470` saturated internal steps, `36..43`
temporal-force witnesses per cell, and zero integrity violations or mirrored
response asymmetry. Its SHA-256 is
`305b3b462ec463278eedd526d28f32abdde3d0eaff919a3d52b179f6590deb96`;
the six-file evidence tree SHA-256 is
`c96149581e4db495796beda412afd87d1f9f0d740c262f07d10d393839856422`.
The supervisor now refuses before opening another world. This positive exact-
finite host profile permits a new selected-policy campaign, but grants no
multibody-robot, walking, cross-engine, robustness, release, or physical-
acceptance claim by itself.

## MV1 selected-policy walking closure

MV1 consumed its one allowed physical process from clean pushed source
`51ced7fd74bd54a21e5750675c5503cae7d3fe4e`. The exact-source full-Godot V2
attestation passed, but the campaign closed implementation-invalid: the Python
bridge admitted profile
`mujoco_s169_per_actuator_force_limited_five_substep_vh5_validated_v1` while
the Rust core rejected that previously unregistered identity on the first host
mapping. One model was constructed, but no native actuator command, complete
physics step, trace row, or report was produced.

Audit the immutable source, five-file evidence tree, traceback, non-claims,
and same-identity rerun refusal from the repository root:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_walking_mv1_closure.ps1
```

The closure is not a MuJoCo walking result—positive or negative. The core
profile registry now has a real dynamic-library regression canary, but that
post-closure repair cannot rescue MV1. Any future MuJoCo walking attempt needs
a new campaign/gate/preregistration/source/attestation identity. The MV1
supervisor refuses another physical launch.

## MV2 selected-policy walking closure

MV2 supplies that new identity without moving the portable system. It keeps
the exact s169 body, BW19V-B composition, selected policy, correction scale,
VH5-characterized per-actuator profile, material, initialization, full LC1
schedule, thresholds, evaluator, and finite claims unchanged. The sole design
change is the missing cross-language gate exposed by MV1.

Before `MujocoBw19vRobot` can construct an `MjModel`, the MV2 preflight loads
the exact release `sporespore_locomotion_core.dll`, obtains a real portable
actuation frame through the C ABI, composes the canonical residuals, and maps
the exact VH5 profile. It validates the eight ordered commands, null native
position targets, characterized receipt, DLL digest, and zero-world flags.
False characterization and wrong-native-motor controls must both fail with
`ACTUATION_INVALID`. The full synthetic evaluator rejects `27` additional
report mutations, for a total `29/29` zero-world gate.

The zero-world freeze audit passed, then clean pushed source `badbea292` and
its fresh full-Godot V2 attestation authorized one physical process. That
process completed the frozen `2992`-step loop and applied all `23936` outer
native commands, but it raised `KeyError: 'morphology_id'` while assembling
the report. The frozen compiled record stores that field at
`robot.compiled["morphology_id"]`; the physical assembler incorrectly indexed
the nested `robot.morphology` object. No report was completed or retained.

Audit the immutable closure from the repository root with:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_walking_mv2_closure.ps1
```

MV2 is closed implementation-invalid, not positive or negative. The lost
in-memory trace cannot be reconstructed, evaluated, or promoted to walking.
The supervisor refuses another world. Any correction requires a distinct
campaign with a zero-world compiled-record/report-assembly canary, new clean
pushed source, a new attestation, and a new one-shot identity.

## MV4 selected-policy pose-hold-restoration closure

MV4's prospective freeze passed, but its single exact-source physical process
closed implementation-invalid. `endpoint_kinematics()` emits canonical vectors
through `_vec_json()` as `x/y/z` dictionaries. MV4's new terminal restorer
instead passed those dictionaries directly to `np.asarray(...,
dtype=np.float64)` because its zero-world restoration fixtures used lists.
The first terminal composition raised `TypeError` before a terminal host
mapping or native terminal command existed.

One world was constructed and walking-phase native actuation reached the
controller's evidence-limit transition, but no complete report or admissible
metric survived. That control-flow fact is not a walking result. MV4 cannot be
rerun, and its lost trace cannot be reconstructed. Use the closure audit:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv4_closure.ps1
```

```text
C6_MJC_BW19V_MV4_CLOSURE_PASS status=implementation-invalid worlds=1 evidence_transition=True terminal_commands=0 report=False scientific_result=False walking=False physical_authority=False rerun_refused=True
```

Any successor must normalize the production vector representation and exercise
that exact shape in a new zero-world canary before a new campaign identity may
open a world.

## MV5 production-vector repair freeze

MV5 implements that distinct successor without changing MV4's body, policy,
host, horizon, thresholds, or PH1 terminal-restoration parameters. The helper
`_canonical_vector3()` accepts only exact finite `x/y/z` objects and normalizes
them in canonical order. Its dedicated zero-world canary sources the positive
object through `selected_policy_development._vec_json()` and rejects five
non-production/corrupt shapes.

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_freeze.ps1
```

```text
C6_MJC_BW19V_MV5_FREEZE_AUDIT_PASS worlds=0 steps=2992 commands=23936 canaries=37 synthetic=18 dynamic=2 morphology=2 trace=5 restoration=5 vector=5 physical_authority=False
```

The audit builds no MuJoCo model or data object and grants no walking claim.
Physical execution remains one-shot and requires the separate clean-source,
live-remote, exact-attestation, operation-lock, and new-evidence interlocks.

## MV5 post-loop report-assembly closure

MV5's physical process reached the report dictionary after the fixed loop, but
the dictionary requested `experiment_source.commit` from the PH1 closure. That
closure uses top-level `physical_source_commit`, so Python raised a `KeyError`
before report completion and evaluator execution. No trace or metric file was
retained.

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv5_closure.ps1
```

```text
C6_MJC_BW19V_MV5_CLOSURE_PASS status=implementation-invalid worlds=1 loop_inferred=True steps_inferred=2992 report=False scientific_result=False walking=False physical_authority=False rerun_refused=True
```

A successor must correct the immutable closure field reference under a new
identity and make the zero-world perfect-report route execute the exact shared
physical report assembler before another world is allowed.

## MV6 shared report-assembler repair freeze

MV6 preserves MV5's exact model, controller, restoration law, horizon,
thresholds, and strict production-vector boundary. The repair is isolated to
report assembly: `_assemble_report()` performs the real MV3/PH1 source
projection, production evaluator, declared result, and claim map for both the
perfect synthetic report and the eventual post-loop physical report.

The new six-control schema family rejects absent or legacy PH1 source fields,
malformed or wrong PH1 commits, and absent or wrong MV3 source records. The
complete audit passes all 43 controls without constructing `MjModel` or
`MjData`:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_freeze.ps1
```

```text
C6_MJC_BW19V_MV6_FREEZE_AUDIT_PASS worlds=0 steps=2992 commands=23936 canaries=43 synthetic=18 dynamic=2 morphology=2 trace=5 restoration=5 vector=5 assembler=6 physical_authority=False
```

No MV6 evidence directory or attempt exists at this boundary. Do not invoke
`-RunPhysical` manually; the exact committed freeze must first be pushed,
live-verified, and covered by a fresh full-Godot V2 attestation.

## MV6 exact-finite positive closure

The frozen MV6 source was pushed as `3ad4d5fb...d3b9`, passed a fresh
exact-source full-Godot V2 suite, and consumed one process under the global
physical lock. The process retained a complete `2992`-row report and exited
`0`. Both the production evaluator and the independent closure replay report
zero failures.

```powershell
pwsh -NoLogo -NoProfile -File `
  .\tests\test_mujoco_c6_bw19v_selected_policy_pose_hold_restoration_mv6_closure.ps1
```

```text
C6_MJC_BW19V_MV6_CLOSURE_PASS status=positive worlds=1 trace_steps=2992 advance=1.399553 hold=360/1053 walking=True selected_policy_c6=False cross_engine_equivalence=False physical_authority=False rerun_refused=True
```

This is a complete valid positive for the exact-s169 pose-hold-restoration and
finite walking contract. It is not general MuJoCo walking, release-selected
physical C6, formal cross-engine equivalence, independent validation,
population inference, robustness, release, or physical-acceptance authority.
The campaign is consumed and the supervisor refuses another world.

## Recovery energy observation V2 mapping

`sporespore_mujoco_adapter.recovery_energy_v2_mapping` is the additive,
zero-world bridge from complete R24D36 implicit-substep receipts to the public
engine-neutral ledger V2. Call
`map_r24d36_components_to_recovery_observation_v2(core, request)` with the
exact mapping request schema, a flat observation base without an energy field,
and strictly ordered five-substep batches. The mapper returns either a
`supported_exact` receipt containing the ordered increments, core aggregation
receipt, and flat `sporespore_recovery_observation_v2`, or an
`unsupported_capability` receipt that retains the source population and states
why no ledger was published.

The mapper does not import MuJoCo, construct a model, advance a solver, infer
work from energy change, or apply a threshold. It accepts both signs of
qualified constraint exchange. The current supported passive and external
subset is exact zero; nonzero passive work and an external intervention without
measured work refuse explicitly. Observation V1 and the existing R24D36 route
remain unchanged, and observation V2 is not yet accepted by the recovery
collector/evaluator.

R24D38's sole clean-pushed zero-world qualification passed `9/9` controls at
source `5ff284ae77486be4007698add327445ffa1a5cc0`. The retained closure binds 17
source files, ten mapped substep receipts, five forced failures, two typed
refusals, and zero models, worlds, or solver steps. This qualifies the mapper's
source semantics, not native execution. R24D38 cannot requalify; a distinct
R24D39 collector/evaluator and route-consumer contract is required before the
adapter may publish observation V2 from a native world.

## Recovery observation V2 consumer

`sporespore_mujoco_adapter.recovery_observation_v2_route` is the additive
R24D39 publication seam. It accepts a complete R24D38 mapping request plus the
unchanged descriptor, morphology context, capability, runtime qualification,
arm, and phase identities. It returns a publication receipt containing the
mapping receipt, self-content-addressed source binding, V3 collection request
and receipt, and portable observation V2. Typed mapping refusals stop before
collection and publish no observation.

The source binding covers the exact R24D36 route, R24D38 mapping profile,
mapping receipt, complete component population, observation base, ledger, and
portable observation. Its `source_chain_sha256` binds those fields as one
payload; the core also independently recomputes the base, ledger, and
observation digests. Mutation of any member fails closed.

`MujocoObservationV2RecoveryWorld` is a separate source route that can retain
the qualified V3 substep receipts and compose this publisher after each outer
step. R24D39 does not instantiate it or run MuJoCo. The historical
`MujocoSignedWorkPreprojectionRecoveryWorld` keeps its original refusal before
observation construction. Current qualification covers source wiring and the
public ABI only; native execution and recovery behavior require distinct later
contracts.

R24D39's sole clean-pushed official qualification at source
`bb312b13934362c144eb98e628d5ad2082ba950c` passed all `8/8` controls, eight
forced failures, and one typed unsupported-engine refusal over the exact
27-file source population. Its immutable closure binds nine retained artifacts
and records zero models, worlds, solver steps, physical-state changes, or
held-out access. R24D39 cannot requalify.

The next boundary is an undeclared R24D40 **development** native-execution
smoke. Before this class may be instantiated, that successor must freeze its
own exact model/world/step budget and in-run invariants. R24D39 does not require
a full seeded trajectory or an additional predictive physical canary, and it
does not authorize recovery, handoff, standing, physical acceptance, or
release claims.

## Minimum native observation V2 route smoke

QSDK-R24D40 commissions `MujocoObservationV2RecoveryWorld` through the shared
serial qualification and physical supervisors. It is a development route
smoke, not a standing test: one outer step is executed in each of the required
candidate and matched-zero worlds, for exactly two outer steps and ten native
solver substeps total. No full seed and no additional physical canary are part
of the contract.

Before each observation returns, the world calls the pure
`validate_recovery_observation_v2_in_run_invariants_v1` replay. The retained
trace must reproduce the same content-addressed receipt after the run. It
checks finite values, exact counter order, native time advancement under a
derived ulp bound, cumulative five-substep batches, native-step identity,
source binding, publication, collection, arm, and phase. It performs no model
construction, solver work, threshold selection, or behavior interpretation.

Development/source conformance:

```powershell
pwsh -NoLogo -NoProfile -File `
  .\sdk\run_qsdk_r24d40_observation_v2_native_smoke_zero_world.ps1 `
  -Mode development
```

Only a clean-pushed prospective freeze may run the single official
qualification (`-Mode qualification`). Only after that passes may the physical
wrapper run once. The wrapper retains any complete result or invalid/incomplete
envelope under the durable evidence root; neither outcome alone proves
recovery or prone-to-standing.

## R24D40 invalid closure and R24D41 route-factory requirement

The one R24D40 qualification passed. The one physical wrapper invocation was
retained invalid with
`QSDK_R24D39_RECOVERY_MORPHOLOGY_CONTEXT_REQUIRED`: the shared smoke passed
`MujocoObservationV2RecoveryWorld` but did not pass an explicit compiled route,
so `run_paired_development` used its base public-profile default. The invalid
envelope published no exact runtime counts. Frozen source order establishes
only that the first candidate constructor's superclass model/data path returned
before the morphology-context check, and that prone initialization and native
stepping were not reached. R24D40 must not be rerun.

R24D41 must keep the common publisher and add an optional explicit route
factory. Its worker supplies `compile_recovery_morphology_model_route`, and its
world composes `MujocoRecoveryMorphologyWorld` readback/initializer behavior
with `MujocoObservationV2RecoveryWorld.step_native`, explicitly retaining the
observation-V2 route identity. The source gate must reject any other compiled
schema or MRO before a model is constructed. Only a new clean-pushed R24D41
qualification may authorize its one minimum paired physical smoke.

## R24D41 prospective composite route

R24D41 passes the shared bounded publisher an explicit
`compile_recovery_morphology_model_route` factory. The publisher constructs one
`LocomotionCore`, gives that exact instance to the factory, and passes the
returned route into `run_paired_development`; callers that omit the factory
continue receiving the historical base-route default.

`MujocoRecoveryMorphologyObservationV2World` composes the existing
`MujocoRecoveryMorphologyWorld` and `MujocoObservationV2RecoveryWorld`. Its
zero-world conjunction receipt binds the recovery receipt schema, morphology
digests, model XML, portable context, MRO, method owners, canonical prone
initializer, signed-work native route, and observation-V2 publication route.
It typed-refuses a base route and a non-composite world before physics. The
single official R24D41 qualification remains mandatory before the one minimum
paired smoke; no other R24D41 physical invocation is authorized.

## R24D41 retained route-integration positive

Clean-pushed source `de418f0f` passed the one official qualification at `8/8`
controls plus nine forced failures and zero physical execution. Its one
authorized paired smoke then completed two composite worlds, two outer steps,
and ten native substeps. Both worlds validated the eight-joint recovery
mapping, applied the canonical prone initializer, published observation V2 from
the signed-work native route, replayed the publication, and completed the
public collector, supervisor, controller-planning, paired-evaluator, artifact,
and lock paths.

This proves the exact finite route conjunction only. Both arms ended after one
`confirm_prone` observation, so no recovery or standing behavior was tested.
R24D41 cannot rerun. R24D42 must use this same production path for the direct
full natural-stop development progression after its own declaration and
zero-world qualification; it does not need another physical integration
canary.

## R24D42 direct natural-stop progression

`qsdk_r24d42_observation_v2_natural_progression_worker` compiles the exact
R24D41 recovery model and native signed-work route, then uses
`MujocoRecoveryMorphologyStreamingObservationV2World` for publication. The new
mapper accepts only the current five-substep batch, advances exact cumulative
terms in a compact state, and commits a digest-chain node. It never copies or
replays prior native arrays in the current outer step. The existing paired
runtime, controller, physics, morphology, initializer, supervisor, evaluator,
1200-step maximum, and natural stops are unchanged.

Before physics, the zero-world worker proves nine controls and 21 forced
failures, legacy numeric parity at seven prefixes, exact R24D41 invariant
hashes, and bounded per-step mapping cardinality. That complete development gate
passed `9/9` controls and all 21 forced-failure checks with zero model, world,
or solver execution. No physical canary is present.
The wrapper selects the shared runner's supported `release` core profile; the
qualification receipt records its profile and DLL digest, and the physical
runner requires both to match. During the sole physical attempt, current-batch
mapping and source/collector/native invariants pass before supervision. After
natural stop, the worker replays the complete streaming chain once and runs one
legacy final aggregate per arm for exact numeric parity. The full trace,
compact projection, and manifest publish append-only. A complete behavior miss
is a valid negative; an integration, invariant, chain, baseline, or publication
failure is invalid or incomplete. Neither outcome alone is a prone-to-standing
or release claim. The current published accounting therefore remains `11/20`
for SDK1 and `11/25` for the full program.

## R24D42 closed: exact natural-stop handoff positive

The sole qualification passed from `a3e0384b` at `9/9` controls, all 21 forced
failures, and zero physical execution. The sole physical attempt then completed
307 candidate plus 775 matched-zero outer steps (5,410 native substeps). The
candidate reached `stance_handoff` with raised-body and safety true and a
0.001765744132594449 J residual; matched zero applied no active command and
stopped failed. All streaming publications and in-run invariants replayed, and
both final legacy numeric baselines matched.

The generic evaluator still returns `physical_development_failed` because it
requires stance control, dwell, and `complete`; the separately declared R24D42
handoff decision is positive. R24D42 closed and cannot rerun. R24D43 must own
the exclusive stance continuation. Full prone-to-standing remains unproved, so
SDK1 stays `11/20` and the full program stays `11/25`.

## R24D43 exclusive stance-completion route

`qsdk_r24d43_exclusive_stance_completion_worker` keeps the R42 streaming world
and full invariant replay, but explicitly sets `continue_through_stance=True`.
After an accepted recovery edge, `sporespore_recovery_stance` revalidates the
same observation-V2 collection and emits the existing control receipt under
the exact stance controller identity. The host applies the frozen zero-joint
pose under the already-published caps; the observation reports stance as the
sole owner and recovery inactive. Historical callers keep the handoff-stop
default.

The complete development preflight passed `10/10` controls and all 12 forced
failures through the release core. Its three source-bound supervisor edges and
all composer commands were exercised without constructing a model or world or
advancing a solver. One official clean-pushed qualification remains pending;
the physical wrapper is blocked until it passes and then permits only the one
declared paired nominal attempt. There is no predictive full-run ghost, extra
seed, or physical canary. Full prone-to-standing remains unobserved, so SDK1
stays `11/20` and the full program stays `11/25`.

## R24D43 launch-invalid closure and R24D44 contract ghost

R24D43's sole official qualification passed all ten controls and 12 forced
failures from source `53e624f3`. Its physical wrapper did not reserve or open a
world: strict access to the shared runner's required `ghost_horizon` object
failed because R24D43 used `natural_stop_horizon`; the runner would also have
required the absent `held_out_seal`. Source order and the empty matching
physical evidence population prove that no lock, worker, model, world, or
solver step occurred. R24D43 is closed as a qualified-source, pre-reservation
integration invalid and is not a behavior result.

R24D44 adds those established launcher-facing objects without changing the
MuJoCo world, controller, route, seed, horizon, threshold, or evaluator. The
shared physical runner's validation-only mode calls the same contract-selector
function as a real launch and returns a compact zero-physics receipt. R24D44's
worker verifies that receipt and forces missing-`ghost_horizon` and
missing-`held_out_seal` failures. The complete development gate passes `11/11`
controls, all 14 forced failures, source conformance, release-core tests, and
worktree stability. Prospective qualification remains pending. SDK1 stays
`11/20`, full program `11/25`.

## R24D44 closed exact nominal MuJoCo positive

Source `914f5be5` passed the sole official `11/11` plus 14-forced-failure
qualification and one paired native attempt. The candidate reached portable
`complete` in 373 outer steps after 66 exclusive stance-owner observations and
the frozen 60-step stable dwell; matched zero remained unactuated and failed by
`phase_timeout:raise_body` after 775 steps. All 1,148 in-run invariant receipts
and both replay layers passed over 5,740 native substeps. This finite result is
exact nominal MuJoCo prone-to-standing development evidence only. SDK1-M19
still requires Rapier/Parry and Godot/Jolt, so SDK1 remains `11/20` and the full
program remains `11/25`; R24D45 physics stays closed pending native-port
selection and a distinct qualified contract.
