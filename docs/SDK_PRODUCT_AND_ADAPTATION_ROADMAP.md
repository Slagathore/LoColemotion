# SDK Product and Adaptation Roadmap

This document is the compact product-sequencing and learned-adaptation
authority for the LoColemotion locomotion SDK. It records the decisions made
while the physical campaign was paused and after work resumed on 2026-08-05.
It does not replace the executable evidence or release contracts:

- [`LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md`](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md)
  controls scientific claims;
- [`LOCOMOTION_ARCHITECTURE.md`](LOCOMOTION_ARCHITECTURE.md) controls runtime
  ownership and engine-neutral semantics;
- [`SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md`](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
  records the active portable-policy and engine evidence lineage; and
- [`../sdk/release/quadruped_release_contract.json`](../sdk/release/quadruped_release_contract.json)
  plus
  [`../sdk/release/quadruped_support_matrix.json`](../sdk/release/quadruped_support_matrix.json)
  decide whether the public quadruped package may ship.

Frozen positive, negative, invalid, and rejected campaigns remain immutable.
This roadmap can order a new successor, but it cannot change an old result.

## Current execution order - 2026-10-24

Latest recovery-training preparation (2026-10-24): the [prospective successor](#prospective-bounded-recovery-training---2026-10-24)
implements a separate post-handoff stability objective, fixed input scaling,
training-only candidate selection and independent update verification.
**18 analytical controls** and the **327-control complete zero-world gate**
pass. No new training world has opened at this checkpoint. Next publish this
freeze, complete the **seven-world execution fixture**, then run the declared
**112-world CPU pilot**. All four reserved starts remain unopened; recovery
benefit, useful Tier 3 memory and Tier 2/Tier 3 qualification remain unproved.

Latest recovery result (2026-10-24): the [completed paired handoff diagnostic](#completed-paired-recovery-handoff-diagnostic---2026-10-24)
verifies **14 fresh CPU worlds**, **20,160 commands** and **100,800 internal
samples** from published `24e1ee2d`. All eight interventions match their fresh
challenge prefix exactly, but **0/8 rescue the failing trajectory**. Earlier
handoff delays healthy failure by 0.790 seconds with baseline and 0.955 seconds
with the selected actor; it makes the weakened failures earlier. All **275
prelaunch controls** and **ten closure controls** pass. Next develop a distinct
bounded recovery objective from exposed challenge prefixes and test that
capability before changing warning thresholds or reopening reentry. Reserved
starts, useful Tier 3 memory and Tier 2/Tier 3 qualification remain open.

Latest withdrawal result (2026-10-24): the [completed native diagnostic](#completed-residual-withdrawal-diagnostic---2026-10-24)
verifies **ten fresh CPU worlds**, **14,400 commands** and **72,000 internal
samples** from published `d8d80cc3`, after **218 safety controls**. Silent
guarding preserves both selected-controller trajectories exactly. Explicit
withdrawal reaches zero residual at 0.75 seconds and reenters at 1.0 seconds.
Automatic withdrawal **rescues neither failing-actor run**: the first tilt
violation is 1.67 ms later when weakened and 15 ms earlier when healthy.
All **nine closure controls** pass. Next distinguish intervention timing from
recovery-controller capability; reserved evaluation and useful Tier 3 memory
remain open.

Latest warning component (2026-10-24): the [completed shadow-warning fit](#completed-residual-failure-warning-component---2026-10-24)
reconstructs all **64 training episodes**, including **49 failures**, with
zero worlds. Both crossfit tuning diagnostics and the full-data model warn
within the target window for **49/49 failures**, with **0/15 successful
episodes warned**. These are exposed-training diagnostics, not independent
calibration. The shortest crossfit warning lead is only **3.33 ms**; the native
intervention results are recorded above. All **20 component, eight reader and
six closure controls** pass. Sufficient recovery time, independent calibration,
reserved evaluation and useful reversible Tier 3 memory remain unproved.

Latest selected-artifact closure: the [completed fresh comparison](#completed-frozen-residual-selection-comparison---2026-10-24)
verifies **24 CPU worlds**, **34,560 commands** and **172,800 internal samples**
from published **3a04722f**, after all **138 safety controls**. The fixed artifact
passes **4/4 weakened** and **4/4 healthy** groups and preserves healthy
quality at **4/4 starts**. Disabled traces exactly match all eight fresh
baselines. The declared finite screen **passes**. Eight closure controls reopen
every artifact and reconstruct the scores with zero new worlds. Selection
remains retrospective; the earlier failed final optimizer checkpoint stays
unchanged. Calibrated support, withdrawal, unopened evaluation, useful Tier 3
memory and qualification remain open.

Latest training closure: the [completed native residual pilot](#completed-native-residual-training---2026-10-24)
verifies the three-world execution fixture and **88-world pilot** from published
**b29ea283**, each after all **104 safety controls**. The final trained checkpoint
passes all four healthy comparison groups and improves their quality scores,
but fails all four weakened groups. Disabled traces exactly match baseline.
Its declared finite screen fails. An initial random search perturbation passes
all eight training groups and supplied the lead for the fresh comparison above;
it does not replace the failed fixed final checkpoint. Eight
closure controls reconstruct rewards, moments and updates with zero new worlds.
The separate training-only selection and fresh comparison are now closed above.
Next pursue calibrated support, withdrawal and useful reversible Tier 3 memory.
Reserved starts remain unopened; Tier 2/Tier 3 qualification remains unproved.

Latest native route: the [residual smoke closure](#completed-residual-native-execution-route---2026-10-24)
completes three fresh CPU worlds from 2f8fb95e after all 86 controls, with full
independent replay of 360 commands and 1,800 internal steps. Zero residual
preserves the absent-provider trajectory exactly; the untrained probe changes
both held input and native position at internal step 6. Six closure controls
reopen all 1,202 artifacts without new worlds. This verifies execution, not
training or locomotion benefit. Measured portable-control cost dominates this
short run; the completed profile and declared training successor are recorded above.

Latest controller-comparison closure: the [committed selection comparison](#completed-committed-selection-comparison---2026-10-24)
completed **48 fresh CPU worlds** from published `d228a4d4` after all **388
safety controls**. Independent replay verifies **29/48 eligible and 19/48
negative**. The current frozen/shuffled selectors each pass 2/4 weakened
starts; committed frozen passes 1/4 and committed shuffled 0/4. Baseline and
disabled controls pass 0/4. All 24 healthy trials preserve baseline quality.
The declared shortlist remains empty, and this thirty-command rule is not
promoted. Ten closure controls pass. The [complete state/action diagnosis](#completed-full-state-and-action-coverage-diagnosis---2026-10-24)
now passes ten controls over all 48 trials and identifies omitted-state
differences without assigning causation. A [bounded residual optimizer](#implemented-bounded-residual-optimizer-component---2026-10-24)
passes ten numerical controls. The [residual production component](#implemented-residual-provider-and-continuous-history---2026-10-24)
now passes 22 combined controls over 2,560 decisions on retained inputs through
both core DLLs, with 88 canonical values and continuous resolved-action history.
No native dynamics or training transitions were generated. The [native launch
manifest correction](#corrected-residual-native-launch-manifest---2026-10-24)
retains a zero-world prelaunch failure and passes fourteen focused controls.
The native route and training pilot are now closed above. Complete training
rewards and updates are verified, but weakened-condition recovery failed in
the fixed final checkpoint. Learned-association
benefit, empirical recovery monitoring, reserved evaluation, useful Tier 3
behavior and release remain unproved.

Latest fitting closure: the [first-response repertoire fit](#completed-first-response-repertoire-fit---2026-10-23)
classifies **8/8 training groups** from one actual command response (1/120 s),
with both conditions of each start held out together. Constant nominal scores
4/8 and synthetic reversed associations score 0/8. The complete 32-trial source
ledger is retained; 24 immediate-role episodes supply 15 eligible episodes,
nine failures and **720 frozen cases**. Eight delayed composite-action episodes
remain excluded from single-action fitting. Ten component and four closure
controls pass with zero new worlds. The healthy condition has a complete
baseline default; the weakened condition has no complete fixed-controller
default. The completed comparison above now connects causal runtime retrieval
to fresh full-horizon baseline, disabled and shuffled controls, retaining the
uncovered start. This checkpoint establishes neither useful selection nor
Tier 3 benefit, qualification or release.

Earlier native closure: the [phase-release comparison](#completed-phase-release-comparison---2026-10-23)
completed all 32 CPU worlds from published `e5589f8b` after all 287 controls.
Independent replay verifies **19/32 eligible and 13/32 negative**. Immediate
phase release passes two weakened starts and the vertical reference passes a
different one; neither covers all four. Delayed release passes none. All
nominal trials survive, but every corrected role loses nominal tracking
quality at every start. The declared fixed-controller shortlist is empty.
Eight closure controls pass. Next pursue a distinct repertoire/early-selection
successor that retains the uncovered start and the healthy baseline; no
learned action mapping or useful Tier 3 behavior follows from this result.

Latest diagnosis: the [phase/contact and response reader](#completed-phasecontact-and-command-response-diagnosis---2026-10-23)
verifies all sixteen trials over a common 0.8-second prefix with zero new
worlds. Scheduled stance lacks observed support in 1,868/4,896 leg observations,
including both eventual positives. Eight controls pass. The completed successor
above uses actual controller memory and keeps the resolver limits unchanged;
its full-horizon and healthy-body results now constrain further development.

Latest controller result: the [support-vertical comparison](#completed-support-vertical-comparison---2026-10-23)
retains 2/16 eligible trials and 14/16 negatives after complete independent
replay. No role passes all four starts. The immediate successor improves one
eligible paired tracking score but does not broaden coverage. The diagnosis
above supplies the next development question; useful context-selected
behavior remains unproved.

SDK1 is complete at **20/20** under the October 3 retained receipt; the full
program remains **19/25**. The August sections below are history, not the current
queue. The [master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md) and
[support matrix](../sdk/release/quadruped_support_matrix.json) carry earned
claims. The native development candidate below grants no new qualification or
provider promotion.

Current learning boundary: bounded native retrieval and episode feedback now
have a complete independently audited comparison. Frozen retrieval meets its
finite quality-gain floor against both controls in 3/3 calibration groups;
episode memory meets its benefit floor in 0/3. The distinct contextual-memory
successor also completed its full native comparison: matching-context feedback
was verified, but its benefit floor was met in 0/3 exposed development groups.
Frozen retrieval remained favorable against baseline and disabled control in
3/3 at the longer horizon. Useful Tier 3 behavior remains unproved. The empirical
withdrawal monitor, unopened evaluation and promotion gates remain required.

The subsequent [action-credit diagnosis](#action-credit-and-causal-history---2026-10-23)
finds that 20/22 ordinary-memory decision changes penalized an observed action
and selected an alternative without matching feedback. A distinct host now
supplies actual causal observation/action history through the existing v1 ABI;
its five controls pass on retained inputs. No new physical worlds or useful
adaptation claim follow from this component work.

The [motor-effectiveness pilot](#completed-motor-pilot---2026-10-23) is now closed
after 120 native GPU worlds and complete independent replay. Discovery retained
75/90 eligible episodes; fresh confirmation retained 24/30. Every arm failed
both left-side 75-percent confirmation starts, including the profile selected
from discovery. The declared conditioning-value criterion is false. Diagnose
that failed transfer and strengthen the control repertoire before fitting a
history estimator; no new adaptation benefit or qualification follows.

The [matched GPU diagnostic](#completed-matched-motor-diagnostic---2026-10-23)
then retained 12/48 eligible episodes, with profile 6 passing only the easier
start across the tested layouts. The [native CPU challenge](#completed-native-cpu-motor-challenge---2026-10-23)
has now completed: baseline and profile 6 failed at both starts, leaving
0/4 eligible episodes. Strengthening phase/state-dependent control remains the
immediate task; these diagnostic episodes grant no fitting authority.

The [stance-feedback discovery](#completed-cpu-stance-discovery---2026-10-23)
completed all 24 CPU worlds from published `53cc81c9` after all 105 controls
passed. Independent replay verified every decision and internal sample: **0/24
eligible**, with an empty shortlist. The closure retains all failures and a
post-hoc account of clipping and supported-knee posture before each first tilt
violation. Next separate correction authority from stance-posture effects in a
distinct prospective experiment; no gain sweep or history estimator is promoted
from this negative family. Verified discovery data may support later development
fitting, but no fresh confirmation or adaptation benefit has been established.

The [posture/envelope factorial](#completed-posture-and-envelope-factorial---2026-10-23)
completed all 18 CPU worlds from published `f9a0509d` after all 123 controls
passed. Independent replay verified **1/18 eligible and 17/18 negative**. The
all-high corner walked forward for the complete four-second horizon at the
0.005 m/s start, but failed at 0.002 m/s. No candidate passes both, leaving the
shortlist empty. The next successor must address this start sensitivity before
fresh confirmation and healthy-body preservation; history inference remains
later. The retained result supplies verified development fitting data, with no
new adaptation-benefit, qualification or release authority.

The [body-gain factorial](#completed-body-gain-factorial---2026-10-23) completed
all ten CPU worlds from published `82dc9bfe` after all 141 controls passed.
Independent replay verified **4/10 eligible and 6/10 negative**. Every feedback
corner passed 0.005 m/s and failed 0.002 m/s, so the shortlist remains empty.
The tested gain range did not resolve start sensitivity. A separately labeled
post-hoc common prefix shows different front-right support return. The
[ground-reach diagnosis](#fixed-pose-ground-reach-diagnosis---2026-10-23) now
verifies that the front-right foot cannot reach the floor at 173/180 sampled
torso poses in each failing trial; successful trials regain reachable poses.
The [body-height successor](#completed-body-height-discovery---2026-10-23) has
now completed all six CPU worlds after the full 159-control gate. Independent
replay verifies 3/6 eligible episodes: the height-enabled candidate passes both
starts and is selected for fresh confirmation. It has worse tracking quality
than the reference at the previously successful start. That discovery left
longer-horizon behavior and healthy-body preservation unproved.
The [twelve-second confirmation](#completed-body-height-duration-and-nominal-confirmation---2026-10-23)
is now complete after all 169 controls: 9/12 eligible, with candidate 2 passing
both starts on both bodies. Its nominal tracking score is below baseline at
both starts, so the nominal quality guard is false. New discovery for causal
history and context-dependent selection is next; confirmation grants no fitting
or reselection authority.
The [causal-prefix training repertoire](#completed-causal-prefix-repertoire---2026-10-23)
is now closed after all 192 controls and 24 fresh CPU worlds: 12/24 eligible,
all on the nominal body. All twelve degraded-body trials fail, so its shortlist
is empty; nominal baseline ranks first. Eight shared prefixes are verified
training groups. Earlier observation and initial control now need a distinct
successor. Learned selection and reserved calibration/evaluation remain unopened.

The [16-command training diagnostic](#completed-early-context-feasibility---2026-10-23)
now classifies 8/8 groups with both conditions of each start held out together,
versus constant nominal 4/8 and synthetically reversed associations 0/8. Seven
component and three closure controls pass. Zero new worlds opened; no action
mapping or control authority is assigned. The matched comparison below now
shows that the available feedback still lacks four-start coverage. This internal
classification check does not expose reserved groups or establish useful control.

The [matched activation comparison](#completed-matched-height-activation---2026-10-23)
is now closed after all 217 controls and twelve fresh CPU worlds: **1/12
eligible, 11/12 negative**. Baseline passes 0/4, immediate height 1/4 and
sixteen-command-delayed height 0/4. Independent replay and all seven closure
controls pass, but no role enters the four-start shortlist. The [retained
composition diagnosis](#completed-height-composition-diagnosis---2026-10-23)
now verifies opposing baseline vertical motion in 744/994 supported-leg samples
from a common first second of the four immediate trials. Seven controls pass.
Next test support-only compensation of that opposing component under a distinct
declaration before mapping inferred context to actions. Timing alone has not
resolved the failure; reserved groups and prior confirmation remain excluded.

The objective is to finish the usable SDK1 Studio/setup experience and reach
Tier 2 and Tier 3 quickly through bounded trial, error, discovery and advancement.
Broad morphology certification and engine equivalence are not prerequisites to
experimental learning. They remain prerequisites to their respective advertised
claims. SDK2 names product/research scope; Tier 2 and Tier 3 name adaptation
strategies, not release versions.

### Product work and required completion evidence

| Work | Required result | Evidence still needed |
| --- | --- | --- |
| Live recovery | Fast Godot walking detects a fall, relinquishes control, establishes current recovery observations, recovers and resumes walking on the same bodies | Fresh contained user-timed destabilizing impulse, transition/command/state trace, independent reader and visible Studio exercise; explicit refusal for unsupported entry |
| Startup/recovery cost | Remove measured avoidable preparation and serialization while preserving controller and observation semantics | Matched-workload section timings, command comparisons and safety refusals; startup, recovery and walking reported separately |
| Portable Studio setup | Launch an isolated source bundle without the development checkout or author-specific paths | Relocated config, verified dependencies, curated resource closure, zero-world preflight, fresh native sessions and installed-launcher readback |
| Relocatable proof subset | Separate raw evidence from viewing projections, with required viewing resources available | Manifest of digests, sizes, original identities and missing dependencies; verification after relocation |

Native binary distribution remains a separate release/licensing decision.
Reproducible local setup may use explicitly supplied or locally built runtimes;
it must not imply permission to redistribute unapproved binaries.

The portable setup successor is now implemented in
[`materialize_studio.py`](../sdk/explorer/studio/materialize_studio.py) with
`--portable`. It copies the supplied native images into relative runtime paths,
binds the explicitly supplied Windows CPython 3.11 environment and exact package
code, and includes a separately verified viewing pack. The pack preserves all
5,962 published frames and their three original raw streams, while explicitly
listing omitted scientific dependencies. `portable_setup.py` verifies the
relocated source, runtime images, interpreter and projection without opening
worlds. The [portable installation checkpoint](../sdk/explorer/studio/portable_installation_checkpoint_v1.json)
now retains fresh relocated sessions for all three engines, the rebuilt Python
environment, the graphical preflight and the installed-launcher self-test.
Local Windows portability and the viewing subset are complete at source
`e507c191`; this does not establish another machine/driver combination or native
binary redistribution. Six controls cover relocation, corruption and checkpoint
refusals. The reader reopens 1,344 artifacts and recomputes the native joins.

The new Godot observation took **43.852625 s** through stand-up and **29.662299 s**
for 15 walking seconds, with 68.344/99.537 ms button-to-display responses.
It passes the declared portability/interaction checks but does not close the
startup/walking speed objective. Fast walking still lacks the live recovery
handoff. These are the remaining Studio priorities; no performance superiority
or new recovery acceptance is inferred from the installation work.

Fast walking currently bypasses the recovery ledger. Flipping its mode would
revive stale clocks and energy history. The successor must close walking
ownership and establish a current observation epoch, retaining the gap and
applied impulse. It must not reset poses, velocities or the world, invent
observations, or resume stale memory. Repeated kicks, unsupported orientation,
timeout, cancellation and failed stance must have explicit outcomes. Original
accepted recovery and Studio checkpoints remain immutable.

### Trial, error, discovery, advancement

Use **declare -> qualify safety -> trial -> retain every outcome -> select
candidate -> fresh native challenge -> advance or reject**. Failed trials are
expected data; infrastructure-invalid trials remain distinct from behavioral
failures. Search can adapt between recorded batches, never by revising an
observed batch or tuning against a sealed evaluation population.

1. **Commission GPU execution and measurement.** Bind runtime bytes, device,
   dtype, topology, timestep, solver, capacities and graph mode. Begin with a
   bounded scalar conversion/sampling probe, then the actual quadruped model.
   Exercise containment, cancellation, overflow/nonfinite refusal and complete
   batch accounting. Separate compilation, transfer and simulation timing.
2. **Search and train experimentally.** A distinct development lane permits
   bounded candidate search and provisional model fitting. Retain parameters,
   seeds, controls, outcomes, ranking and every attempted cell. GPU trajectories
   generate candidates; they carry no CPU or three-engine physical authority.
   Full equivalence is not required merely to test a promising hypothesis.
3. **Test task-specific transfer.** Freeze a shortlist and challenge it in fresh
   CPU MuJoCo and intended native targets, with the unchanged baseline. Keep
   failed transfers as counterexamples. Separate numerical calibration from
   candidate selection and evaluation. Reward never waives physical invariants.
4. **Reach Tier 2 through the provider seam.** Fit one bounded morphology/task
   provider; freeze data groups, splits, model, normalization and output limits.
   Evaluate in shadow mode before bounded influence. Missing, stale, unsupported
   or invalid proposals fall back to the deterministic baseline. Promotion uses
   the existing independent native qualification lifecycle.
5. **Reach Tier 3 through episodic memory.** Start with bounded context/retrieval
   updates over the frozen Tier 2 model, with reset and rollback. Compare memory
   enabled/disabled and shuffled associations on fresh task groups, with matched
   trigger/influence controls, and retain before/after decisions.
   Durable encyclopedia promotion stays offline. Online base-weight mutation
   needs its own later qualification.

The August Warp equivalence/calibration contracts remain sealed at their
recorded status. A versioned discovery successor can authorize candidate work
without asserting those contracts passed. The located October 3 GPU activity
behind the three-engine share video was offscreen rendering of retained poses.
Its preparation and rendering scripts construct no new simulation. The Godot
kick/recovery/walk source is the retained
`development-recovery-smoke-960cdb887b00476895c27b012423b60a` report, whose
`c67495bc72644cd3e1b91b0353fd03c579194e50b9c69fbe659e4484f867e3e8` digest was
rechecked against the [existing recovery closure](../sdk/recovery/r10dh_held_out_physical_closure_v2.json).
This resolves the located rendering job's provenance; it establishes no earlier
GPU recovery-training run.

Nine historical rendering inputs/output artifacts are now retained byte-for-byte
in `<evidence-root>/historical-three-engine-render-20261023-e8109373d8784c078c16c079278e6402`.
Its `manifest.json` SHA-256 is
`632dbdf0b5ce492a0a26c15fbe56756e8f43b06507f33430ce2ec8dc5c0c5b4a` and also
binds all five original physics sources. The three panels each have 1,200 frames
at 60 Hz. MuJoCo/Rapier recovery limbs are reconstructed from measured torso
poses and hinge angles; walking and Godot recovery use retained body poses.
Original absolute paths and system-font dependencies remain in the archived
renderer. This is provenance retention, not a relocated runnable render package
or new physical evidence. The derived PNG cache was not copied or deleted.

The first executable route is
[`run_gpu_measurement_probe.py`](../sdk/discovery/run_gpu_measurement_probe.py).
From the repository root in PowerShell, use the pinned environment:

```powershell
& ./sdk/adapters/mujoco/.venv/Scripts/python.exe -B ./sdk/discovery/run_gpu_measurement_probe.py
# After a clean pushed source freeze, a fresh complete gate precedes physics:
& ./sdk/adapters/mujoco/.venv/Scripts/python.exe -B ./sdk/discovery/run_gpu_measurement_probe.py --run
```

Both commands print the fresh durable output location and a final `ok` field.
The first builds zero worlds. The second consumes a new identity, owns one
contained native process, measures eight scalar cells per backend, and runs an
independent complete-trace reader. Its result is measurement commissioning,
not quadruped training, a throughput benchmark, or an equivalence decision.

The [first native probe](../sdk/discovery/gpu_measurement_probe_closure_v1.json)
completed all 1,920 rows. Two cells diverged at a force-clamp branch after a
command reversal, reaching a 0.30 rad/s difference despite matching sensor
semantics. Candidate search must retain such branch-sensitive cases and expose
them to native transfer tests; they must not be hidden by a widened tolerance.
The [quadruped probe](../sdk/discovery/gpu_quadruped_probe_v1.json)
now uses the actual compiled S169 body, eight velocity actuators and 16 named
force sensors. Four bounded feedback profiles each receive 1,200 internal steps
on GPU, followed by four fresh CPU worlds with the same profiles and seeded
inputs. This commissions contacts, per-world attribution, control capture,
capacity refusal and force-clamp labels. It does not run the accepted portable
walking policy or train a provider. The independent reader checks every state
transition and the full 9,600-row denominator; the closure reader reopens every
retained artifact and recomputes that audit.

Use `run_gpu_quadruped_probe.py --core PATH_TO_BOUND_CORE_DLL` in the same pinned
Python environment for the complete zero-world safety gate. Add `--run` only
after its prospective source is clean and pushed. Each invocation retains a
fresh identity; native execution is contained and serialized.

At clean pushed `affab906`, the complete gate passed again and all eight native
worlds finished. The [quadruped closure](../sdk/discovery/gpu_quadruped_probe_closure_v1.json)
reopens 275 artifacts and recomputes all 9,600 rows. Named force sensors agree
exactly and every cell exercised ground contact. The maximum CPU/GPU root
difference was 4.013546 mm; contact counts differ in 659/4,800 paired steps and
clamp branches in 137/38,400 actuator samples. No equivalence margin or locomotion
acceptance is asserted. The cold first GPU step took 94.576994 seconds; later
stepping/synchronization took 16.624734 seconds. The deliberately small,
synchronously captured batch does not establish high-throughput training.

That probe led to the bounded portable candidate search below. Device-side
control/batching, a learned proposal through the existing provider seam,
episodic adaptation and the remaining Studio work stay in the active queue.
The old production Warp qualification contracts and support-matrix flags are
unchanged.

The next [portable parameter search](../sdk/discovery/gpu_portable_search_v1.json)
now has an executable prospective route. It uses the unchanged BW19V controller
and stability composition through the public ABI, followed by the actual optional
provider resolver. The absent-provider baseline is compared with three explicitly
untrained proportional velocity-correction proposals. Four matched GPU worlds
receive 480 outer steps with five internal steps each. Their exposed ranking is
retained before four fresh CPU challenge worlds are constructed; all candidates
are challenged regardless of rank. Provider absolute/slew/speed clamps remain
owned by the core, and the adapter owns canonical-to-native mapping.

GPU observations use split stepping and checked native readback views. CPU
dynamics/forward calls are trapped during GPU execution; a readback may factor
its copied mass matrix without advancing a CPU world. The independent reader
reconstructs body velocities from retained native spatial data, replays all
portable/controller/provider ABI inputs and checks every internal solver input,
force/contact capture and ranking decision. Full telemetry costs are measured
before any reduced-capture or device-resident successor is considered.

The complete zero-world gate is retained as
`sdk2-gpu-portable-search-832c06fa8ef4408f9a4d2c1d11c6503c`: eight new search
controls, ten quadruped controls, seven measurement controls, the eight-cell
public provider conformance, process containment and pinned runtime preflight.
That gate opened zero worlds. This is candidate search, not a trained Tier 2
provider or held-out evaluation. Use `run_gpu_portable_search.py --core
PATH_TO_BOUND_CORE_DLL` in the pinned Python environment; `--run` requires a
clean pushed prospective freeze and repeats the complete gate before physics.

The first native search at clean pushed `cf158067` completed all 19,200 internal
steps and 3,840 controller decisions, but its independent reader refused
`Contact presence join`. The [invalid closure](../sdk/discovery/gpu_portable_search_invalid_closure_v1.json)
preserves all 398 artifacts and reproduces the refusal. GPU contact presence
was wrong in 3,952 of 7,680 site observations (1,786 of 1,920 controller rows);
the CPU rows had no such mismatch. MuJoCo stores `geom` separately from legacy
`geom1`/`geom2`; Warp populated the former while the unchanged adapter read the
latter. Execution completion is not a valid candidate result. Its ranking and
transfer observations are unusable and are not training data.

The distinct [v2 successor](../sdk/discovery/gpu_portable_search_v2.json) copies
checked native geometry ids into the legacy fields of the unstepped host view,
retains before/after representations, and validates the observation join before
retaining GPU control. It changes no native world, candidate, ranking threshold,
portable policy or provider safety envelope. Eleven zero-world controls now
include a real standalone MuJoCo contact consumed by the production adapter,
crossed compatibility fields, and revalidation of the complete failed closure.
The complete safety gate passed at
`sdk2-gpu-portable-search-v2-ac4b85c7027b44318380cf8a30842037`.

Clean pushed `dd009d99` then repeated the complete gate and consumed the fresh
v2 attempt `sdk2-gpu-portable-search-v2-54f8e263fbbc428fa4d6adee036e2b85`.
The [v2 closure](../sdk/discovery/gpu_portable_search_closure_v2.json) inventories
429 artifacts and independently replays all **3,840 controller/provider steps**
against all **19,200 internal physics rows**. All four GPU and four fresh CPU
worlds completed; the force-sensor pairs agree exactly. All candidates satisfy
this batch's height, tilt, torso-contact and no-actuation eligibility limits.

| Untrained proposal | GPU displacement (m) | Fresh CPU displacement (m) |
| --- | ---: | ---: |
| Absent-provider baseline | 0.387820 | 0.394523 |
| -10% of baseline velocity, then core limits | 0.413417 | 0.415105 |
| +10%, then core limits | 0.404115 | 0.418829 |
| +20%, then core limits | 0.403004 | 0.424904 |

GPU selected the -10% proposal before any CPU challenge world was constructed.
Its CPU displacement exceeded the fresh baseline by **20.581641 mm** in this
one four-second trial. CPU's best observed profile was +20%; the different
rankings are retained, and the selection is not changed after CPU inspection.
This is finite exposed discovery, not a trained provider, held-out evaluation,
general superiority or equivalence. The v1 attempt stays invalid.

The native worker took **170.181697 s**, including cold compilation and full
capture. Measured GPU preparation/integration took 81.009746 s, readback
19.116879 s, portable control 24.642861 s and internal capture 8.512576 s.
CPU preparation/control took 25.744654 s and integration/capture 3.833650 s.
These are diagnostic sections, not a controlled throughput comparison; setup,
controller-row serialization and other overhead are also in the total.
Next measure a bounded batching/readback successor, freeze a grouped training
and evaluation corpus, fit a bounded provider, then run shadow and fresh native
influence challenges. Tier 3 follows with reversible episode memory over the
frozen model. Studio recovery handoff and startup/walking performance remain
required alongside that learning work.

### Research-informed acceleration - 2026-10-23

The [reviewed research proposal](https://github.com/Slagathore/LoColemotion/blob/f2a6d088b68ba16577f31ad834b3ddfe5f09576a/docs/SDK2_ADAPTATION_RESEARCH_BOOTSTRAP.md)
provides useful implementation options. Its repository snapshot is `5062134`;
the valid portable v2 search above supersedes its commissioning-only diagnosis.
The controller already runs once per 1/120 s command with five held-control
physics steps. Batched portable calls, fewer observation/capture transfers and
graph execution remain open. The [research review](research/LOCOMOTION_RESEARCH_SOURCES.md#2026-10-23-adaptation-proposal-review)
records adoption limits; this roadmap remains the sequencing authority.

| Order | Development target | Exit evidence before advancing |
| --- | --- | --- |
| L0 complete in the declared S169 development scope | Batch the existing complete portable/controller/provider path on the host; graph held-control GPU substeps with correct sampling stages | Scalar/batch command, memory and refusal conformance; full safety gate; fresh comparison at three declared batch sizes with compilation, transfers, control, physics, capture and audit costs separated |
| L1 | Build a diverse S169 repertoire before expanding body or task scope | Declared bounded genome, two or three behavior axes and eligibility rules; append-only record of every trial and replaced elite; frozen shortlist challenged in fresh native worlds |
| L2 | Use deterministic retrieval of frozen, characterized residual proposals as the first Tier 2 candidate | Grouped corpus and calibration/evaluation splits; bounded provider output; shadow then fresh influence trials against baseline, retrieval-disabled and shuffled-association controls, with trigger/influence matching |
| L3 | Add an empirical monitor that withdraws provider influence using existing refusal states first | Frozen fitting set, hysteresis and explicit unsupported states; fresh non-inferiority evaluation under a prospectively chosen practical margin |
| Next | Reversible Tier 3 episode memory over the frozen retrieval provider | Preserve the immutable base corpus/model, bounded memory, reset/rollback and fresh memory-off/shuffled controls |
| Optional improvement | Residual learning and history-based adaptation | Beat the retrieval baseline on fresh groups while preserving the deployed clamp chain; these are not prerequisites to experimental Tier 3 |

A retrieval provider need not train a neural network, but its frozen corpus and
selection rule are still a fitted artifact requiring evaluation. L1 can begin
with the existing residual channel. An arbitrary `BalancedWaveProfile` genome
or a second shadow controller must first acquire a real, bounded implementation
path; a public Rust struct is not by itself an arbitrary-profile C ABI.
Batching must cover the full deployed composition, not only the gait kernel.

The proposed lighter exploration capture is a development convention to declare
and validate in a distinct successor before L1. It keeps every candidate's
identity, parameters, source/runtime bindings, seed, outcome and failure reason,
always-on capacity/nonfinite/control/contact/no-cheat checks, and predetermined
full-trace canaries. The archive is a selection index, not the trial ledger.
Shortlists run fresh with full traces and independent readers; acceptance keeps
its existing lifecycle. No observed low-capture run is retroactively upgraded.
The invalid v1 contact join shows why checks cannot disappear with telemetry.

A conservative L3 refusal can use v1 `refused` or `uncertain` plus diagnostics.
New core fallback enums or receipt fields require a versioned extension; scaling
a correction after the slew clamp must not silently alter the deployed slew
semantics. Neither bounded commands nor an empirical recoverability estimate
proves an invariant safe region or that the provider can never make things worse.
GPU numerical nondeterminism also does not erase scientific repeatability:
retain original results and assess repeated outcomes separately. A fresh CPU
challenge tests transfer, not reproduction of the original GPU trajectory.

Choose archive axes before L1 and practical non-inferiority margins before L3's
evaluation. Those decisions do not block L0. No claim score, release flag,
physical acceptance threshold or old campaign changes in this review.

The [host-batching component](../sdk/discovery/portable_batch_component_v1.json)
now implements the full baseline composition and batches provider resolution.
Its new optional C/Python entrypoints keep explicit per-cell memory and return
ordered errors. The integrated caller uses four batch stages per outer command;
it retains a distinct provider decision between baseline and resolution. Output
capacity reuse avoids the old bindings' two evaluations on ordinary calls.
The consumed scalar/GPU routes and installed runtimes remain unchanged.

All 3,840 retained v2 controller/provider decisions reproduce bit for bit through
the new path. Seven component controls and all 524 Rust core tests pass. A
zero-world benchmark uses the same saved inputs, alternates execution order and
checks every result outside timing. Across three repeats, median scalar/batch
host-time ratios are **1.4202** at one creature, **1.4457** at four and **2.2981**
at sixteen. All 3,528 compared benchmark decisions match. These are host-only
observations, not GPU throughput or a statistical superiority result.

The [component reader](../sdk/discovery/audit_portable_batch.py) rehashes 45
artifacts and ten source bindings, including the candidate DLL, successful tests,
complete benchmark rows and the initial compile/fixture-binding failures. Its
four corruption controls pass. The next L0 successor must integrate this path
with CUDA-graph substeps and checked capture/readback, qualify the complete gate,
and measure fresh native workloads before scalable search is claimed.

L0's [native GPU execution comparison](../sdk/discovery/gpu_batch_execution_closure_v1.json)
is complete at clean pushed source `15b1fa17`. The full 45-test safety gate and
zero-world runtime preflight passed before the contained worker opened 18 fresh
trials: three repeats per route at 1, 4 and 16 creatures, with alternating order.
All 126 worlds completed 120 outer commands and 600 internal steps. The first 24
outer commands per trial were declared warm-up; all remain retained. The
independent reader replayed every one of the **15,120 controller decisions**
against the original scalar path and checked all **75,600 internal rows**.
Named actuator/joint force samples agree exactly, every world exercised contact
and nonzero force, and no safe-no-actuation step occurred.

| Creatures | Scalar/direct median for 96 measured outer commands | Batch/graph median | Observed scalar/batch time ratio |
| --- | --- | --- | --- |
| 1 | 6.375737 s | 2.336767 s | 2.7284 |
| 4 | 12.691322 s | 6.759074 s | 1.8777 |
| 16 | 33.379350 s | 22.334917 s | 1.4945 |

These are combined full-capture route timings; they do not identify the separate
contribution of host batching, graph dispatch or buffered readback. Native
execution, including setup, cold compilation and all warm-up, took **430.189135 s**;
the complete independent audit took **464.424087 s**. The largest observed paired
final-displacement difference was 3.908 micrometres, without an equivalence
margin or equivalence claim. No training data, trained provider, statistical
superiority or physical acceptance is inferred.

At 16 creatures the measured batch route delivers **68.77 controller steps/s**.
In its median-time trial, prepared observation readback takes 11.488260 of
22.334917 s, portable control 5.796857 s, and integration plus device history
1.359247 s. This supports a modest full-capture retrieval corpus; it does not
establish high-throughput neural training. The next work is L1/L2's bounded S169
repertoire, prospective group splits and frozen retrieval provider. Reversible
Tier 3 memory follows over that model. Further performance work should respond
to measured corpus cost rather than delay the first fitted provider.

The [closure verifier](../sdk/discovery/audit_gpu_batch_execution_closure.py)
rehashes 715 artifacts, verifies 239 frozen-source and 1,359 runtime bindings,
checks the retained full reader and recomputes the timing table. Four corruption
controls pass. Its default does not repeat the unchanged full controller replay;
`--replay` explicitly does so. The [contained launcher](../sdk/discovery/run_gpu_batch_execution.py)
uses `--core` and `--baseline-core`; a new `--run` always consumes a fresh identity
from a clean pushed source after the complete gate. This observed campaign must
not be rerun or regraded. This closure creates no learning corpus or trained provider.

The [bounded retrieval component](../sdk/adaptation_provider/retrieval/component_v1.json)
now fits an immutable casebook and exposes it through the existing v1 provider
contract. Its prospective split declares four training, four calibration and
four evaluation condition groups. Fitting refuses calibration/evaluation data,
missing group/action pairs and malformed windows. A separate all-trial ledger
retains negative and invalid identities; the elite index is only a selection
view. This is an initial bounded repertoire design, not a completed MAP-Elites
search or native learning corpus.

The same provider supports frozen retrieval, disabled and sign-reversed proposal
controls, reversible episode feedback, and a shuffled feedback-association
control. Episode memory updates bounded score offsets while the fitted model
stays immutable. Checkpoint, rollback and reset preserve the core's explicit
memory and clock semantics. The existing absolute/slew clamps and exact absent-
provider fallback remain in the actual ABI path. The sign-reversed control
matches requested magnitudes at the same input; native exposure matching still
requires a prospective physical evaluation.

Eight actual-ABI component tests pass. The [component verifier](../sdk/adaptation_provider/retrieval/verify_component.py)
rehashes 28 retained artifacts and ten source bindings, refits the synthetic
36-episode corpus (35 eligible episodes and one retained negative), and replays
all 183 provider/core decisions over 560 fitted cases. Synthetic episode feedback
changes the selected action while the frozen and shuffled-memory controls keep
the original choice. The initial invalid provider-version identifier is retained
alongside the repaired results. These checks open zero worlds and establish
implementation mechanics only: no native experience, physical acceptance,
release or training-data authority is claimed.

Next: freeze a distinct full-capture native training campaign, collect all 36
training group/action episodes, independently join every observation and action
to native state/control, then freeze the corpus and fitted artifact. Calibration
and evaluation groups remain excluded from fitting. Fresh shadow/influence,
baseline, disabled, shuffled-proposal and shuffled-memory challenges must precede
claims of working native Tier 2/Tier 3; three-engine promotion and the empirical
withdrawal monitor remain separate required work.

The [native repertoire successor](../sdk/discovery/gpu_repertoire_v1.json)
now declares 36 training episodes: nine bounded bilateral correction choices in
each of four training condition groups. Every episode has 480 outer commands and
2,400 internal physics samples. The production baseline, v1 resolver, native
adapter observations, per-substep capture and operation containment remain in the
route. Initial native roll and lateral velocity vary by group; calibration and
evaluation groups are excluded. This new campaign alone permits development
model fitting after complete independent replay. Older training-false campaigns
keep their original authority.

The [launcher](../sdk/discovery/run_gpu_repertoire.py) adds six repertoire controls,
eight retrieval controls and three corpus-pipeline controls to the previous
45-test safety gate. The zero-world development attempts
`sdk2-gpu-repertoire-4cde081d8e5b49b896883de3ae890c7e` and
`sdk2-gpu-repertoire-38d7085a2a72455991c48793fbd8d1f9` passed their complete applicable
gates. The latter also discovered the imported retrieval tests a second time;
this duplicate discovery is removed prospectively, leaving 62 distinct tests.
The initial synthetic root-precision mismatch remains retained in
`sdk2-repertoire-development-4ba0bf4e4a6c44d994494f2698b5b137`.

The [offline corpus step](../sdk/discovery/freeze_retrieval_corpus.py) rehashes the
verified native inputs, then uses the existing Tier 2 candidate-chapter,
frozen-corpus and model-registration pipeline. It starts a separately labeled
empty development lineage and cannot rewrite an installed encyclopedia or
promote a provider. Native collection has not run at this source checkpoint.
A clean pushed freeze and the complete gate must precede its one-time execution.

The [native v1 closure](../sdk/discovery/gpu_repertoire_negative_closure_v1.json)
is a valid complete negative at clean pushed `e87dba34`. All 36 training episodes
ran, but **zero met eligibility**: every episode, including all four baselines,
exceeded tilt and torso-contact limits; two also crossed the height limit. The
independent reader replayed all 17,280 controller decisions and checked all
86,400 internal rows. Native execution took 251.694971 s and the full audit
137.677422 s. The offline fitting step refused with `No eligible baseline cases`
and wrote no model. No failed window is reclaimed as positive training data.

The [negative closure reader](../sdk/discovery/audit_gpu_repertoire_negative_closure.py)
rehashes 759 artifacts, verifies 255 frozen-source and 1,359 runtime bindings,
checks the complete 62-test gate and preserves the original synthetic precision
failure. Four corruption controls pass. Its default binds the original full
reader and recomputes timing; optional `--replay` repeats the unchanged reader.
The consumed attempt, thresholds and negative classifications cannot be rerun
or regraded.

The distinct [flat-start v2 declaration](../sdk/discovery/gpu_repertoire_v2.json)
keeps the actions, episode length, eligibility, features and memory algorithm.
It replaces the starting-condition family with the default upright pose and
small positive native lateral velocities of 0.002, 0.003, 0.004 and 0.005 m/s.
This outcome-informed successor is near the earlier finite upright-start
example; it establishes no continuous support region and isolates neither the
roll nor velocity contribution to v1's failures. Calibration and evaluation
use different prospectively declared conditions and remain excluded from fitting.

The [versioned pure plan](../sdk/adaptation_provider/retrieval/flat_contract_v2.json)
loads the unchanged retrieval algorithm in an isolated module so v1's contract,
model identities and evidence remain intact. The complete **63-test** zero-world
gate passes in `sdk2-gpu-repertoire-v2-11314f3b2b2b400ba3756b214d92a789`.
The earlier v2 test attempt is retained: its copied corruption assigned zero to
an already-zero roll component and was correctly not rejected. The repaired
control introduces an actual changed component. Native v2 collection still
requires its clean pushed source and repeated prelaunch gate.

The public evidence index now distinguishes the exact historical SDK1 support
matrix from the current development matrix. The old readiness receipt still
binds the byte-identical [snapshot](../proof/sources/quadruped_support_matrix_at_sdk1_snapshot.json);
current status has its own checked digest. This forward correction follows a
publication-check refusal at `632cc797`, preserves the old receipt and outcomes,
and passes all 21 publication controls plus replay controls. It grants no new
scientific authority and changes no training or evaluation rule.

Clean pushed `2ab77fcf` repeated the complete 63-test gate and consumed the
[flat-start v2 repertoire](../sdk/discovery/gpu_repertoire_fit_closure_v2.json).
All **36 training episodes met the unchanged eligibility limits**. The full
independent reader replayed **17,280 controller decisions** and checked
**86,400 internal physics rows**. No CPU world was stepped; calibration and
evaluation worlds remain zero. Native execution took **370.790278 s**, including
cold compilation and full capture; the independent audit took **174.429230 s**.
These timings are observations, not a performance comparison with v1.

The create-only offline step froze the native episodes, candidate chapter,
corpus and model registration. The immutable casebook contains **576 cases**;
its canonical model digest is
`sha256:3388543fe3e4d7baef933395376cc3154501073c8fc72ee51c6733b356fb287a`.
Only **two of 48 archive bins** are occupied. This supplies a narrow native
development candidate, not a diverse repertoire, continuous support region,
trained-provider influence result or superiority claim. The original v1
all-negative population and fitting refusal remain unchanged.

The [fit closure reader](../sdk/discovery/audit_gpu_repertoire_fit_closure_v2.py)
rehashes all 768 artifacts, verifies 267 frozen-source and 1,359 runtime bindings,
recomputes timing and independently reconstructs every fitted record. Five
corruption controls pass, including changed raw identities, measured outcomes,
model/count bindings and attempted authority promotion. Their retained attempt is
`sdk2-repertoire-fit-controls-38235e93298748e9b27bff834198656a` under the evidence
root, including the exact reader/test/closure source bytes and original logs.
Default verification
does not repeat the already-retained full native reader; `--replay` does so
without opening worlds. The initial v2 test-fixture failure stays bound as well.

Next, implement and qualify the fresh native shadow route for this exact frozen
model, then the bounded influence route. Use baseline, retrieval-disabled and
shuffled-proposal controls before interpreting Tier 2 behavior. Compare frozen,
episode-memory and shuffled-memory modes with prospectively declared trigger and
influence accounting before interpreting Tier 3 behavior. The empirical
withdrawal monitor, fresh CPU/native transfer, three-engine promotion, Studio
handoff/performance and all SDK2 claim targets remain open.

The [fresh native shadow route](../sdk/discovery/gpu_retrieval_shadow_v1.json)
is now implemented for the exact frozen casebook. One fresh `calibration_0`
world runs 480 baseline commands and 2,400 physics steps. Frozen, disabled,
shuffled, episodic and shuffled-episode providers observe that same trajectory
with separate memory. Checkpoint, rollback and reset occur at steps 120, 240
and 360 in the two episodic modes. Every hypothetical resolution records that
its commands were not applied; previous applied correction remains exactly
zero. Shadow feedback is diagnostic and cannot establish action-effect credit,
become training data or promote the base model.

The [independent reader](../sdk/discovery/audit_gpu_retrieval_shadow.py) replays
the scalar baseline and all five provider streams, checks native observation
joins, reconstructs request/model/memory bindings and independently computes
the hypothetical clamps. Provider errors retain exact baseline actuation;
an invalid host transaction closes its session rather than resuming partial
memory. Nine new actual-ABI controls pass, including the abbreviated lifecycle
exercise on 62 exposed training inputs with zero worlds. These are component
inputs, not fresh calibration observations.

The complete **68-test** development gate passes at
`sdk2-gpu-retrieval-shadow-27cec5731b6f41709b7499ccfe4852e4`, including the native
fit closure, measurement, contact observations, host/graph execution, provider
and actual process-containment controls. Runtime preflight constructs zero
worlds. The [launcher](../sdk/discovery/run_gpu_retrieval_shadow.py) must repeat
this gate from clean pushed source before consuming its fresh one-world attempt.
Shadow readiness requires an eligible baseline, a supported nonzero frozen
proposal and no provider/protocol errors; even a positive opens no learned
influence or promotion authority. Native execution remains next at this source
checkpoint.

Clean pushed `fd472c76` repeated the full 68-test gate and consumed the
[native shadow attempt](../sdk/discovery/gpu_retrieval_shadow_closure_v1.json).
The fresh `calibration_0` baseline world completed all **480 controller steps**
and **2,400 physics steps**. The independent reader also replayed all **2,400
provider decisions**. Frozen retrieval produced nonzero hypothetical corrections
on **447/480 steps**, with three unsupported and 30 no-proposal outcomes. Every
mode had zero provider errors and zero unexpected protocol fallbacks; disabled
retrieval produced no correction. All physical provider-influence rows are zero.

Both episodic modes executed checkpoint, rollback and reset at the declared
steps, then continued with reset epoch 1 and sequence 119. This verifies the
native-observation memory lifecycle while the base model remains immutable.
Because the proposed actions were never applied, the feedback has no causal
action-effect meaning and establishes no useful Tier 3 adaptation. Baseline
displacement was 0.411363 m, minimum height 0.424404 m, maximum tilt 0.071902 rad,
with no torso-contact or safe-no-actuation step. Native execution took
208.154688 s including compilation and capture; the full audit took 25.267103 s.

The [shadow closure verifier](../sdk/discovery/audit_gpu_retrieval_shadow_closure.py)
rehashes 770 artifacts, verifies 277 frozen-source, 1,359 runtime and two
external candidate bindings, checks the complete gate and memory lifecycle,
and recomputes timing. Its default binds the original complete reader;
`--replay` repeats it without opening worlds. The consumed shadow population
cannot supply training data or be relabeled as learned physical influence.
Four corruption controls pass in retained attempt
`sdk2-shadow-closure-controls-920552a68930443184c0813de926c114`, including source,
runtime/model, population, memory-summary and attempted authority changes.

Next is a distinct bounded influence campaign carrying actual applied-correction
history through the core's slew limiter, with fresh baseline, disabled,
shuffled-proposal and episode-memory controls. Freeze the trigger/influence
accounting before comparison. `calibration_0` is now exposed; the other
calibration groups and all evaluation groups remain unopened. The empirical
withdrawal monitor and three-engine promotion remain separate required gates.

### Prospective native influence comparison - 2026-10-23

The [distinct influence campaign](../sdk/discovery/gpu_retrieval_influence_v1.json)
implements six fresh worlds for each remaining calibration group: baseline,
disabled retrieval, frozen retrieval, shuffled proposals, episode memory, and
shuffled feedback. The three batches rotate mode order and retain 8,640 control
decisions and 43,200 internal samples over four seconds per world. Evaluation
groups remain unopened. This declaration is prospective; implementation alone
establishes no physical result.

The [host](../sdk/discovery/retrieval_influence_control.py) recomputes the full
production baseline from each world's current observations, carries the core's
bounded correction history, applies the resolved native commands, and commits
private provider memory only after every host mapping passes. Failed provider
calls retain their errors and return to the exact current baseline. An invalid
host transaction closes its already-advanced sessions. No checkpoint, rollback
or reset is scheduled inside these comparisons; those operations have a separate
verified lifecycle. The base model and training corpus remain immutable.

The [reader](../sdk/discovery/audit_gpu_retrieval_influence.py) independently
replays scalar baseline and provider decisions, checks the actual slew history
and all five held solver inputs, and measures influence before and after final
speed projection and float32 transfer. Equal proposed magnitudes do not establish
equal native exposure after trajectories diverge. The
[comparison accounting](../sdk/discovery/retrieval_influence_accounting.py)
requires exact trigger and absolute-magnitude matching before reporting a
matched-influence memory benefit; all unmatched comparisons remain visible.

The primary development metric is the mean of sixteen 30-command forward/lateral
tracking-quality windows. A 0.001 m/s gain floor is a finite development direction,
not a statistical or practical release margin. Frozen retrieval must exceed both
fresh baseline and disabled control; episode memory must exceed both frozen and
shuffled-feedback controls. Each group is reported separately. Every eligibility
failure remains in the denominator. Feedback uses only completed action windows
observed by a subsequent provider call; the last unobserved endpoint cannot be
credited to memory, although it remains part of physical quality measurement.
The complete safety gate, clean pushed freeze and fresh consumed identity are
required before native collection. This campaign grants no training-data,
held-out, noninferiority, superiority, qualification or release authority.

The complete **77-test zero-world gate** now passes in retained attempt
`sdk2-gpu-retrieval-influence-f4d804eaf0cc4ae4a517c2f54684516c`. This includes
six new synthetic route controls, three host transaction controls and five
comparison-accounting controls, plus the baseline, graph, fitting, shadow,
provider and containment gates. Runtime preflight reports zero worlds and
solver steps. The native launcher must repeat this gate from the published
prospective freeze before opening the declared 18 worlds.

### Native influence result - 2026-10-23

Clean pushed `19c13b8e` repeated all **77 zero-world controls**, then consumed
the [18-world comparison](../sdk/discovery/gpu_retrieval_influence_closure_v1.json).
All **8,640 controller decisions** and **43,200 internal physics samples** passed
the independent scalar/provider/native reader. All 18 arms met the unchanged
posture/contact eligibility limits, with zero provider errors or unexpected
protocol fallbacks. Actual nonzero solver influence occurred on **5,294 rows**.
No CPU world was stepped. Native execution took 423.106087 s and the complete
independent replay took 480.032543 s; these are diagnostic capture/replay costs,
not a lean production latency benchmark.

The metric below is tracking quality in m/s units: higher is better. It combines
forward tracking error and lateral motion, so a gain is not necessarily a speed
increase. Every value is from the frozen sixteen-window rule.

| Group | Frozen minus baseline | Frozen minus disabled | Frozen minus shuffled proposals | Episode memory minus frozen | Episode memory minus shuffled feedback |
| --- | ---: | ---: | ---: | ---: | ---: |
| calibration_1 | +0.009875 | +0.009875 | +0.006770 | -0.002024 | -0.001591 |
| calibration_2 | +0.006201 | +0.006201 | -0.009589 | +0.000042 | +0.000108 |
| calibration_3 | +0.014269 | +0.014269 | +0.016818 | -0.000031 | -0.000084 |

Frozen retrieval meets the predeclared 0.001 m/s development gain floor against
both fresh baseline and disabled control in **3/3 groups**, and exceeds shuffled
proposals in only **2/3**. This is a finite favorable candidate result, not
statistical superiority, broad generalization or provider promotion.

The two episode-memory modes made **87 completed feedback updates** and changed
**35 same-input action selections** relative to zero-offset retrieval: 21 in the
ordinary episode mode and 14 in the shuffled-feedback mode. The immutable base
model did not change. Ordinary episode memory meets its benefit criterion in
**0/3 groups**. All learned-arm comparisons have unmatched influence timing or
magnitude; only baseline/disabled have matched zero influence. Thus native
feedback and decision changes are verified, but useful Tier 3 benefit is not.
The final unobserved action window remains uncredited to feedback.

The [closure verifier](../sdk/discovery/audit_gpu_retrieval_influence_closure.py)
rehashes **820 artifacts**, verifies **289 frozen-source**, **1,359 runtime**
and two external candidate bindings, checks every group and memory summary,
and recomputes timing. Its default binds the original full reader; `--replay`
repeats all scalar/provider/native checks without new worlds. The consumed
attempt is `sdk2-gpu-retrieval-influence-b3bd8906889e47609b6653e31d7f027c`.
All calibration groups are now exposed; all evaluation groups remain unopened.
Four retained closure-corruption controls pass in
`sdk2-influence-closure-controls-b3c7209f179d4a67b1364ec4a2699523`, including
attempted quality, feedback-count, influence-matching and authority changes.
The refreshed readiness compiler remains consistent at **19/25** required
gates: four missing, two contradicted, zero invalid. SDK1 stays **20/20**;
release and publication authority remain false.

Next, diagnose the phase/context dependence and credit assignment of the
current global per-action memory offsets using the retained traces. A different
memory design needs a new component identity, complete safety controls and a
fresh prospective comparison; it cannot regrade this negative result. Build
the empirical withdrawal monitor before qualification. Preserve the frozen
retrieval candidate and challenge any successor with disabled, shuffled-proposal
and shuffled-feedback controls, retaining influence exposure. Open evaluation
only after the design and criteria are frozen. Three-engine promotion and the
full SDK2 targets below remain required.

### Contextual episode-memory successor - 2026-10-23

The [retained feedback diagnosis](../sdk/discovery/episode_feedback_diagnostic.py)
reconstructs 2,880 controller rows, 87 completed feedback updates and 35 changed
same-input choices from the consumed comparison. **34/35 changed choices lack
matching-context feedback for either decisive nonzero-offset action**, using
the frozen phase tuple, contact mask and scaled-distance definition. This is a
post-hoc mechanism diagnosis, not proof of an alternative physical outcome.
The complete diagnostic is retained in
`sdk2-feedback-diagnostic-92e7d766b2cf4fee84bbe115e6783a60/diagnostic.json`, SHA-256
`53dd6dc411bf54ae080e5a86ca14ad7b52b4d7b0ae5583f41f0ec5b13ee03712`.
Four diagnostic controls pass without new worlds.

The distinct [contextual component](../sdk/adaptation_provider/retrieval/contextual_contract_v1.json)
retains up to 64 completed windows with their action-time canonical cues. A
later choice uses up to three nearby records for the same action, exact phase
tuple and contact mask, within the unchanged 1.5 support radius. Bounded
residuals include negative outcomes; unmatched contexts receive zero offset.
The frozen casebook, quality metric, decision window, command bounds and v1
provider ABI stay intact. Checkpoint/rollback/reset remain explicit. The
[research ledger](research/LOCOMOTION_RESEARCH_SOURCES.md#2026-10-23-context-indexed-episode-feedback)
records the algorithmic sources and the limits of this borrowing.

Six actual-ABI component controls pass in
`sdk2-contextual-component-055a4a4fd3884e9f8f6fc5382c8d36cb`: related feedback can
change a synthetic decision on recurrence, unrelated contexts cannot, and
negative records, oldest-first eviction, checkpoint capacity, rollback, reset,
refusal and exact disabled fallback are checked. The earlier attempt
`sdk2-contextual-component-ac2528d13fde4af7821ef4a079afe6a4` retains two fixture
failures: an inexact decimal boundary assumption and an expired synthetic
long-clock command. Nine host/route controls pass in
`sdk2-contextual-route-0d03b1e635594a88a4832fc6d650576d`, including independent
feedback arithmetic, action-time context and actual scalar/native-command replay.
These controls construct no physical worlds.

The [new prospective comparison](../sdk/discovery/gpu_contextual_influence_v1.json)
declares three **exposed development** start families, six fresh worlds each,
and 960 outer commands (eight seconds, 32 quality windows) per world. Baseline,
disabled, frozen, shuffled proposals, contextual feedback and shuffled feedback
remain separate arms. The longer horizon permits context recurrence but is a
different regime from the old 480-step campaign; it cannot establish a causal
improvement over that historical memory design. The launcher's full gate adds
context, host, reader, diagnosis and predecessor-closure controls before a clean,
pushed freeze can start physics. Retain every comparison and influence exposure.
All held-out evaluation groups remain unopened. This preparation was consumed
by the result below; the original global-memory 0/3 result remains unchanged.

### Completed contextual comparison - 2026-10-23

The [contextual closure](../sdk/discovery/gpu_contextual_influence_closure_v1.json)
records one clean, published run from `0828885f`, after all **100 safety controls**
and the zero-world runtime preflight passed. Its 18 fresh exposed-development
worlds completed eight seconds each. Independent scalar/provider/native replay
passed all **17,280 decisions and 86,400 internal rows**. All 18 arms remained
eligible, with zero provider errors or unexpected fallbacks. Actual nonzero
solver influence occurred on 10,289 controller rows. The base model did not
change, and no evaluation or training worlds were opened.

| Exposed development group | Frozen minus baseline quality | Contextual memory minus frozen | Contextual memory minus shuffled feedback |
| --- | ---: | ---: | ---: |
| 0 | +0.005508240 | -0.000611342 | -0.000488345 |
| 1 | +0.003541729 | -0.000396314 | -0.000525983 |
| 2 | +0.008215564 | -0.000104606 | -0.000164416 |

Units are m/s in the declared tracking-error score, averaged across all 32
windows. Positive differences favor the first arm; the frozen development
gain floor is 0.001. Frozen retrieval meets its baseline/disabled criterion in
**3/3** groups and beats shuffled proposals in **2/3**. Contextual memory meets
its frozen/shuffled-feedback criterion in **0/3**, scoring below both in every
group. These are finite exposed-development observations, not statistical
inferiority or a causal comparison with the earlier four-second design.

The reader verifies **176 completed feedback updates**, **84 selections using
matching-context feedback**, and **27 changed same-input choices** (22 ordinary,
five shuffled). Correct context reuse and actual decision changes are established;
useful Tier 3 benefit is not. All learned-arm comparisons have unmatched influence;
baseline/disabled alone have matched zero influence. The final unobserved window
remains uncredited. Preserve this valid negative result alongside its predecessor.

The [closure reader](../sdk/discovery/audit_gpu_contextual_influence_closure.py)
rehashes **988 artifacts**, checks **303 frozen sources**, **1,359 runtime files**,
two candidate artifacts and the retained design diagnostic, then rejoins every
group, context count and timing summary. The consumed attempt is
`sdk2-gpu-contextual-influence-20fe9aa17fee473bbc8b1e67585b9e8e`.
Four closure-corruption controls pass in
`sdk2-contextual-closure-controls-6536a9c3aeae4a30a4e04788f55a1761`, including
altered context counts, invented memory benefit, crossed source/runtime/model
bindings, changed diagnostics and attempted authority escalation.
The worker took 620.298 seconds and full independent replay 609.616 seconds.
Measured worker sections include 312.353 seconds of host control, 153.522 seconds
of observation readback and 40.864 seconds of integration/device-history work.
These measurements identify profiling targets; they are not a matched throughput
comparison or permission to weaken capture.

The following diagnostic now examines action credit without assigning outcomes
to unexecuted alternatives. Context restriction alone did not deliver benefit.
Keep the useful frozen candidate while building the empirical withdrawal monitor
and a distinct adaptive task with an explicit, bounded change to learn from.

### Action credit and causal history - 2026-10-23

The [executable diagnostic](../sdk/discovery/contextual_action_credit_diagnostic.py)
first verifies the complete contextual closure, then reads all 17,280 controller
rows. It independently reconstructs observed window scores and rejoins original
feedback and decision denominators. Five controls pass in
`sdk2-contextual-action-credit-8266899469ee44b2bd81f1b8f38dc969` (36.875 seconds
including the contained wrapper). Its `diagnostic.json` SHA-256 is
`1525dd1530056105edee78d01504ad05d06d7b6a7a44da11604a6feb9f856b96`.

Ordinary memory changed 22 decisions. **20/22** switched from an action with
negative matching feedback to an alternative with no matching feedback;
**2/22** had feedback for both choices. Only 9/92 selections had matching
feedback for two or more supported actions. Of its 89 completed feedback
windows, 62 had an absolute prediction error greater than the predicted gap
between the best two actions. Median absolute error was 0.006080106 m/s,
against a median top-two gap of 0.003163276 m/s. These are descriptive window
counts, not independent episode samples or a statistical error guarantee.

The shuffled-feedback arm changed five choices, four through the same
negative-feedback-to-unobserved pattern. Across the two memory arms the reader
rejoins all 176 updates, 84 context-supported selections and 27 changed choices.
It also reconstructs 90 observed frozen windows. Final windows without an
observed endpoint remain uncredited. Cross-world error correlations are retained
with exact pairing counts; most paired actions are the same, and diverged states
are not counterfactuals. Neither a shared disturbance nor causal action credit
is identified. No original comparison is regraded and no fitting is performed.

The source inspection also found that the development host supplied **empty
history**, although the v1 ABI permits 64 entries. The distinct
[history host](../sdk/discovery/history_influence_control.py) now attaches each
world's past canonical states, commands, resolved corrections and receipt hashes
after provider binding. The [history component](../sdk/adaptation_provider/retrieval/causal_history_v1.py)
keeps a contiguous 64-entry window, preserves final speed projection and commits
all worlds' histories only after a complete host transaction. It never supplies
the current or a future observation as past history. Missing status or a refused
`applied` status cannot be represented truthfully by the v1 history enum, so
those events clear the window and retain an explicit boundary reason; they are
not relabeled. The original receipt remains in the trace.

Five [history controls](../sdk/discovery/test_history_influence_control.py) pass
in `sdk2-causal-history-326d2342d8104fd8aa4e9e282e7aa7f4` (16.609 seconds
including the wrapper). Its `receipt.json` SHA-256 is
`0e2fd364f8e7b4a2098022d3842e329a7465282b2a5dd4d87d8b71e478ae941b`.
The real ABI accepts 66 retained-input requests through rollover; a four-round,
six-mode host replay preserves command, native-target and private-memory bytes.
Applied-action decoding is checked through final speed clamping. Tampered,
missing or future history, provider errors, cross-world aliasing and partial
mapping failure are covered. The earlier
`sdk2-causal-history-223036fc685b4bbe90ed3926d309cdac` retains a fixture failure:
an invalid response was incorrectly expected to retain its parsed status.
The corrected five-control pass at
`sdk2-causal-history-5a3d787c0b2e494f83f9e941cfa3abca` also remains retained;
the latest pass adds the applied speed-projection assertion.

This is tested source and actual-ABI replay, with **zero new physical worlds**.
The current provider still ignores the history content. There is no latent
inference, new trained model, adaptation benefit or empirical recoverability
claim. The consumed physical hosts, model and both negative campaigns remain
unchanged.

The next successor should learn a persistent physical context from state/action
history, with a declared motor-effectiveness change as the initial task family.
Freeze exact strengths, affected actuators, exposure splits, horizons and a
bounded experiment budget before any world. First test whether an oracle that
knows the condition can improve behavior within the unchanged correction limits.
If it cannot, preserve that negative result; an estimator cannot supply missing
control authority. Then fit the estimator using varied action histories and
on-policy deviations, with condition labels available only during fitting.
Compare inferred context against the oracle, history-off and shuffled-history
controls, including measured influence and explicit reset/rollback behavior.
Keep evaluation sealed and build the empirical withdrawal monitor before
qualification. The [research ledger](research/LOCOMOTION_RESEARCH_SOURCES.md#2026-10-23-action-credit-and-physical-context)
records the relevant ideas and tradeoffs. The full SDK2 targets below remain.

### Motor-effectiveness pilot - 2026-10-23

The [declaration](../sdk/discovery/gpu_motor_effectiveness_v1.json) and
[owned launcher](../sdk/discovery/run_gpu_motor_effectiveness.py) instantiate
the oracle-first task above. The question is deliberately finite: does knowing
the motor condition help select among **nine constant bounded residual profiles**
compared with one shared profile? This candidate family does not bound the
performance of all possible residual controllers. No history estimator or
episode-memory update is fitted in this pilot.

Five S169 environments are frozen: nominal, left or right motors at 90 percent,
and left or right motors at 75 percent effectiveness. Both velocity-servo gain
and symmetric force limits scale on all four affected-side actuators. Geometry,
transmission and velocity-target units stay fixed. The altered actuator model
is a separately declared development environment, not the nominal qualified
adapter profile. Exact XML, native actuator arrays and GPU float32 arrays are
checked before stepping. The [research rationale](research/LOCOMOTION_RESEARCH_SOURCES.md#2026-10-23-motor-effectiveness-oracle-pilot)
records the source semantics and adoption limits.

Discovery uses two already exposed start families per condition and all nine
profiles: **90 worlds**. The independent reader must validate every episode
before selection. Each condition selects the highest-mean-quality profile
eligible in both starts; the shared selector requires eligibility in all ten
starts. Ties choose the smallest action index. No eligible profile means an
explicit null selection and diagnostic baseline fallback, never a promoted
winner. Action-to-world assignment is rotated and retained.

Confirmation uses two fresh worlds per condition and role, at two already
exposed calibration start families: **30 worlds**, comparing baseline,
condition-known selection and shared selection. Confirmation cannot fit or
change either selector. Each world lasts four simulated seconds: 480 commands
at 120 Hz and five integration steps per command. The total budget is 120 GPU
worlds, 57,600 controller rows and 288,000 internal rows, with zero CPU-stepped
worlds and zero unopened evaluation worlds. Full capture remains enabled.

The finite conditioning-value criterion requires all three roles to remain
eligible and both selectors to exist in all ten confirmation groups. Across
the eight degraded groups, mean condition-known minus shared quality must be
at least 0.001 m/s, with no individual loss beyond 0.001 m/s. In both nominal
groups the condition-known profile must stay within 0.001 m/s of baseline and
shared. At least one degraded group must use a different profile from shared.
Quality remains the existing forward-tracking and lateral-drift score; the
height, tilt, torso-contact and no-actuation eligibility gates are unchanged.
These are finite development criteria, not inferential margins, population
non-inferiority or safety guarantees.

The preparation's complete 75-control gate passed in
`sdk2-gpu-motor-effectiveness-832103dda31148fb9bb05c73a0bc6d00` with zero worlds
and zero solver steps. Its `receipt.json` SHA-256 is
`6e4665bde8cadc5a240243272a04c61b7d477c89723e41c71d17cc0df8eb487b`.
This includes seven task/selector controls, five full synthetic reader controls,
the existing measurement/controller/provider checks, and real job containment.
The standalone startup failure at
`sdk2-motor-launcher-entry-0040b857d8f843eaa496aa9079e2aad6` is retained: the
component test environment masked a missing SDK import path. The corrected
standalone launcher passed the full gate. This preparation opened no worlds.
The subsequent execution below used the clean published prospective freeze and
repeated the complete gate under the operation mutex before its owned workers.

Only complete independently verified discovery episodes may inform later
development fitting. Failed and invalid attempts remain retained. Confirmation,
acceptance, release, robustness and engine-equivalence authority remain false.
The next decision is whether this profile family offers useful condition-aware
control; a negative result motivates a distinct controller family, not a claim
that history adaptation is impossible.

### Completed motor pilot - 2026-10-23

The [closure](../sdk/discovery/gpu_motor_effectiveness_closure_v1.json) binds
`sdk2-gpu-motor-effectiveness-7440e3ead37d4c918c83244ce56b8c08` to clean published
freeze `33c6506eeffb76ef3ee45cd654191e5d84ce8f03`. The complete 75-control gate
passed again before physics. All 120 GPU worlds completed; neither reader
constructed a world. Independent scalar/controller and native-stream replay
passed all **57,600 controller rows and 288,000 internal rows**. There were no
CPU-stepped worlds or unopened evaluation worlds.

| Motor condition | Discovery eligible / 18 | Condition-informed profile | Confirmation eligible / 6 |
| --- | --- | --- | --- |
| Nominal | 18/18 | 8 | 6/6 |
| Left 90 percent | 17/18 | 8 | 6/6 |
| Right 90 percent | 18/18 | 8 | 6/6 |
| Left 75 percent | 4/18 | 6 | 0/6 |
| Right 75 percent | 18/18 | 7 | 6/6 |

The shared selector froze profile 6. Discovery retained **75 eligible and 15
negative** episodes. Confirmation retained **24 eligible and six negative**
episodes: baseline, condition-informed and shared each remained eligible in
8/10 groups. Every left-75 confirmation role failed height, tilt and torso-contact
eligibility. Selected profile 6 stayed above 0.422 m in both discovery starts,
but reached about 0.171 m and 1.97 rad tilt in both fresh confirmation starts.
The failure is substantial, not a small crossing of the eligibility threshold.

The declared `finite_conditioning_value` is **false**. The nominal guard passed,
and the condition-informed arm met its baseline quality-gain floor in 6/8
degraded groups, but the two failed groups stay in the denominator. The primary
mean remains null because its full eligibility requirement was not met. No
failed group is dropped and no alternative criterion replaces the frozen one.
Knowing the condition and selecting the best eligible discovery mean did not
make this nine-profile family reliable on confirmation. This is a valid negative
result, not an invalid execution or a bound on all possible residual controllers.

Discovery used nine worlds per batch and confirmation used three, while initial
velocities and action-slot assignments also changed. These observations do not
identify whether start sensitivity, GPU numerical variability, batch behavior
or a combination caused the failed transfer. First run a distinct, bounded
diagnostic that separates these factors for the selected profile, including a
fresh native CPU challenge where applicable. Then expand phase/state-dependent
bounded proposals if control brittleness remains. Keep the original declaration,
selection and negative result immutable; confirmation remains excluded from
fitting. Fit history inference only after a useful control repertoire has its
own fresh evidence. Empirical withdrawal monitoring and qualification remain open.

Discovery workers took 792.578 seconds and their reader 520.974 seconds;
confirmation workers took 286.253 seconds and their reader 167.149 seconds.
Discovery's measured outer-loop totals include 357.754 seconds of observation
readback, 216.400 seconds of portable control and 35.742 seconds of integration
plus device history, out of 748.178 seconds. The pinned readback implementation
copies arrays separately for each requested world. A per-command batch snapshot
is a measured optimization target, subject to its own observation/command
conformance and fresh native proof; no capture reduction or runtime change was
made in this consumed pilot.

The [closure verifier](../sdk/discovery/audit_motor_effectiveness_closure.py)
rehashes all 1,810 retained artifacts (4,979,359,925 bytes), verifies 312 frozen
source and 1,359 runtime bindings, and rejoins selection, both complete original
audits, timings, all roles and the unchanged comparison. Optional `--replay`
repeats the full scalar/controller and internal-state checks without worlds.
Four corruption controls passed in
`sdk2-motor-closure-controls-fb14fdfca4cf4601a1ede4d5f33aa50f` (74.674 seconds
including containment), covering provenance, source/runtime bytes, missing or
duplicate artifacts, altered selections, erased negatives and false authority.
The closure SHA-256 is
`928c7ac7a7a37ac460396bfedaa4bff74e5240aa7490f1eb661d8467b50df839`.
Only the complete verified discovery population has later development-fitting
authority. There is no history-inference, memory-benefit, provider-promotion,
statistical superiority, non-inferiority, robustness, equivalence or release claim.

### Matched motor diagnostic prepared - 2026-10-23

The [distinct declaration](../sdk/discovery/gpu_motor_batch_diagnostic_v1.json)
fixes 48 fresh GPU worlds in the left-75 condition, using two previously exposed
lateral starts (0.002 and 0.0035 m/s). Each start runs four layouts: nine mixed
profiles, nine worlds repeating `[0, 6, 6]`, three worlds `[0, 6, 6]`, and a fresh
repeat of that three-world layout. Profile 6 occupies the same focus slot in
every layout. One common development seed, unchanged motor XML, residual
envelope, graph execution, 480-command horizon and full internal telemetry keep
the named comparisons matched. No physical baseline is cached.

The reader predeclares 16 comparisons covering width, neighboring-action
composition, fresh repeats, same-batch duplicates and start changes. It records
the first differing internal step, maximum state/control/force difference and
unchanged full-episode eligibility. The fixed order and small population do not
establish a general causal mechanism or statistical effect. This diagnostic
grants no fitting, profile selection, held-out, CPU transfer, adaptation-benefit
or release authority. The earlier pilot's negative result remains unchanged.

The complete **81-control zero-world gate passed** in
`sdk2-gpu-motor-batch-diagnostic-468010b378a945a58e33c4d0c62b7f6e`;
receipt SHA-256 is
`e96edf0bafe49e84f14c331d77fb19f059efc58f1511c849b8afa451d850a58f`.
The six successor controls cover real-ABI preflight, full synthetic replay,
comparison clocks and denominators, and refusals for missing/crossed records,
false authority, altered motor profiles and rehashed state changes. Standalone
controls also passed in
`sdk2-motor-matched-controls-19391b0f95d54c89b4828273b2538a8a`.
No worlds have run for this declaration at this preparation checkpoint.

### Completed matched motor diagnostic - 2026-10-23

The [closure](../sdk/discovery/gpu_motor_batch_closure_v1.json) retains
`sdk2-gpu-motor-batch-diagnostic-aa28370f6c7a4c389e9c861af010c79e`, run from
clean published `68c3ede738fda5fb8981eeb516c5d0b122777e17`. All 81 controls
passed again under the operation lock before physics. All 48 GPU worlds
completed, and independent replay verified **23,040 controller rows and
115,200 internal rows** with no reader-constructed or CPU-stepped worlds.

| Layout | All profiles eligible at 0.002 m/s | All profiles eligible at 0.0035 m/s | Focus profile 6 |
| --- | --- | --- | --- |
| Nine mixed profiles | 2/9 | 0/9 | Eligible, then negative |
| Nine repeating profiles `[0, 6, 6]` | 6/9 | 0/9 | Eligible, then negative |
| Three profiles `[0, 6, 6]` | 2/3 | 0/3 | Eligible, then negative |
| Fresh repeat of three profiles | 2/3 | 0/3 | Eligible, then negative |

The full population contains **12 eligible and 36 negative** episodes. Across
all duplicate slots, profile 6 is eligible in 11/11 instances at 0.002 m/s and
negative in 11/11 at 0.0035 m/s; these are finite instances within shared batches,
not 22 independent statistical replicates. Its four focus-slot comparisons
change eligibility when the start changes. None of the other 12 predeclared
width, composition, repeat or duplicate-slot comparisons changes eligibility.
Focus height stays above 0.42367 m at the first start and drops to about 0.17056 m
at the second, with roughly 1.975 rad tilt and hundreds of torso-contact steps.

This result supports start-sensitive failure of the fixed controller in this
finite scope. The tested batch-width and composition changes do not explain
away the failed start. All nine constant profiles fail in its fresh mixed
batch. This does not rule out switching those profiles over time, other bounded
residual controllers, or success on a different start. No original result is
regraded, and the diagnostic supplies no fitting or selection authority.

Numerical differences remain material. Same-start pairs diverge from the first
internal state; a fresh repeat at 0.002 m/s reaches a maximum instantaneous
target difference of about 3.3213 rad/s and actuator-force difference of about
8.5991 N m. Their eligibility agrees, but their trajectories are not bitwise
equal. Neither GPU determinism nor batch-neutral quality or CPU equivalence
follows. The fixed execution order and two starts limit causal attribution.

Next challenge the selected profile on fresh native CPU worlds at these two
starts, then build a distinct bounded phase/state-dependent repertoire. Use
fresh declared development discovery for fitting; do not repurpose this
diagnostic or the pilot's confirmation as training data. A useful control
family must precede history-based context inference and episodic adaptation.
Empirical withdrawal monitoring, sealed evaluation and engine qualification
remain required for the Tier 2/Tier 3 targets.

Native workers took 449.347 seconds in total; the independent reader took
267.953 seconds. The closure binds **2,103 artifacts (2,119,051,920 bytes),
320 frozen sources and 1,359 runtime files**. Its
[verifier](../sdk/discovery/audit_motor_batch_closure.py) rehashes all retained
bytes, validates source/runtime and population joins, replays timing and the
16 matched comparisons, and preserves the original complete audit. Optional
`--replay` repeats every scalar decision and native-stream check without worlds.
The closure SHA-256 is
`e016c4cd3c63c1e56d2bc25293ccb07ad0a0a031b04d7c0a15b067bb7b1af76f`.
Four closure integrity controls passed in
`sdk2-motor-matched-closure-controls-ff2102d54938486dafcab3e0b77a2ca1`
(88.054 seconds of tests), covering retained-byte verification without worlds,
authority/population/inventory corruption, changed comparisons or erased
negatives, and frozen source/runtime/reader tampering.
No adaptation benefit, statistical inference, training, qualification or release
authority is granted.

### Native CPU motor challenge prepared - 2026-10-23

The [CPU successor](../sdk/discovery/cpu_motor_challenge_v1.json) fixes four fresh
left-75 worlds: baseline and profile 6 at each of the 0.002 and 0.0035 m/s
lateral starts. It uses one development seed, fresh native data and private
controller memory for every role, unchanged motor XML and eligibility bounds,
and the original scalar portable/provider route. Initial coordinates and
velocities equal the GPU's float32 input values, then evolve using native CPU
float64 dynamics and motor targets. This separates initial-value rounding from
the backend change without claiming equal subsequent trajectories.

Every trial retains 480 commands and five internal samples per command, for
1,920 controller and 9,600 internal rows. The reader independently replays
every controller decision and verifies state continuity, prepared observations,
held targets, named force samples, contacts, warnings and episode eligibility.
No GPU physics, profile selection, fitting, unopened evaluation or statistical
equivalence is authorized. The earlier GPU results remain unchanged.

The complete **88-control zero-world gate passed** in
`sdk2-cpu-motor-challenge-4626110483034b91876eeafdcf2ba198`; receipt SHA-256:
`1a7adcfa82da768eea82fab1183e16df2f624b3d08846b0ac770314caab494b2`.
Seven new CPU controls passed, including full synthetic replay and refusal of
float32-rounded CPU targets, changed initial values, force/warning corruption,
wrong model precision, missing worlds and false authority. Standalone controls
are retained in `sdk2-cpu-motor-controls-18a82f510b2d4c5e9d26d9b2778af76d`.
No worlds have run for this declaration at this preparation checkpoint.

### Completed native CPU motor challenge - 2026-10-23

The [CPU declaration](../sdk/discovery/cpu_motor_challenge_v1.json) was executed
once from clean published `47511ec01596f9edf723c221583c9a447ddeeb74` in
`sdk2-cpu-motor-challenge-cb4a0973db81433893c77efe198475bb`. The complete
**88-control zero-world gate** passed again under the operation mutex before
four fresh CPU worlds. No GPU or evaluation worlds ran. Independent replay
verified **all 1,920 controller decisions and 9,600 internal samples**, including
scalar decisions, native observations, held targets, force sensors, contacts,
warnings, clocks and complete outcome accounting.

All four trials are valid negative outcomes under the original bounds:

| Start / role | Minimum height (m) | Maximum tilt (rad) | Torso-contact steps / 2,400 | Failure |
| --- | ---: | ---: | ---: | --- |
| 0.002 m/s / baseline | 0.170580 | 1.975286 | 784 | Height, tilt, torso contact |
| 0.002 m/s / profile 6 | 0.170529 | 1.974549 | 861 | Height, tilt, torso contact |
| 0.0035 m/s / baseline | 0.250806 | 1.677223 | 1,533 | Tilt, torso contact |
| 0.0035 m/s / profile 6 | 0.170445 | 1.985238 | 773 | Height, tilt, torso contact |

Eligibility is **0/4**. Failed episodes retain null quality and no eligible
training windows. All four worlds received nonzero native force in every
internal step, with no safe-no-actuation step. Equalized float32 initial values
then evolved in float64 CPU dynamics. The earlier GPU profile-6 positive at
0.002 m/s did not transfer to this native CPU challenge. This result does not
isolate a precision, integration, contact or controller mechanism and does not
establish general CPU/GPU equivalence or superiority.

The [closure](../sdk/discovery/cpu_motor_challenge_closure_v1.json) binds
**2,241 artifacts / 429,371,727 bytes**, **329 frozen source files**, and
**1,359 runtime files**. Its SHA-256 is
`acf3471217f77dc20f1c8b9463226f61af0e0080a1a84e8ab6bcf5c962d2ac8d`.
Original receipt SHA-256:
`d9db05f8c1736efeffe8686dab44fe0a22cc94d981a0b18169a9529839cd0692`;
independent audit SHA-256:
`a972a2b2d89499cef1403d950f369ff8af6c7d4a041141928486f6f47d078668`.
Native worker time was **19.322 s** and independent audit time **20.737 s**.
These are measured section times for this workload, not a matched engine benchmark.

The [closure verifier](../sdk/discovery/audit_cpu_motor_closure.py) rehashes all
artifacts, checks source bytes at the frozen Git commit and installed runtime
bytes, and rejoins declaration, consumption, gate logs, worker, raw streams,
original reader, timing and negative outcomes. Optional `--replay` repeats the
full scalar reader without new worlds. Its four controls passed in **26.394 s**
in `sdk2-cpu-motor-closure-controls-9a2f4cbfe7a141168de1c3f02929ffd2`;
terminal log SHA-256:
`f7cf7e767482cafdf8b2ec507f5d2ee30a4bbc76f9bfbce57488d86f78dd0e21`.
The earlier closure-test attempt
`sdk2-cpu-motor-closure-controls-c3ee15304e4743318a36d0c5d0e6fa12`
retains its failure log and draft source: the new verifier initially omitted
the worker's progress messages from its expected log. The corrected verifier
checks every progress and terminal row. Failed log SHA-256:
`27bfcd465706ca3c84fd0603ce9af0f57141f3c2a3d77edffa68450659a46e30`.
No physical worker, reader, threshold or original evidence was changed or rerun.

Next, use the retained failures to diagnose phase, support and force-cap behavior,
then declare a bounded phase/state-dependent controller family with fresh
development fitting authority. Preserve baseline and fixed-profile controls,
challenge a frozen shortlist on CPU, and establish useful control before fitting
a history estimator or extending Tier 3 memory. These four diagnostic worlds
remain excluded from fitting and selection. No adaptation, statistical inference,
qualification or release authority is granted by this closure.

### Stance-feedback discovery prepared - 2026-10-23

The [canonical feedback model](../sdk/adaptation_provider/stance_feedback_v1.py)
uses current body orientation, angular velocity, task velocity and observed
support. It requests stance-foot motions opposite the desired body correction,
then applies analytic planar inverse kinematics with fixed damping. Foot-sphere
centres and Jacobians come from the exact S169 geometry. A straight leg's
singularity remains finite; the model has no lateral joint degree of freedom.
The scalar host uses the unchanged portable baseline and public v1 resolver.

The [12-candidate family](../sdk/adaptation_provider/stance_feedback_v1.json)
contains baseline, fixed profile 6, low/medium/high attitude-and-rate feedback
with and without the fixed profile, rate-only and attitude-only controls, and
two optional speed-feedback variants. Gains remain untrained. The existing
0.25 rad/s correction and 0.02 rad/s per-command slew bounds remain in force.
On a valid host request, unsupported feedback inputs, tilt beyond 0.6 rad,
linear speed beyond 10 m/s, or angular speed beyond 20 rad/s withdraw the provider
and restore the exact baseline. Invalid host requests retain the core's typed
error behavior. These are declared input limits, not a recoverability certificate.
The model gates feedback on observed support; it does not change the gait clock.

Eight component controls pass. Geometry checks cover all **1,920 retained CPU
frames**, with maximum foot-centre error **1.055e-15 m** and Jacobian error
**9.923e-16 m/rad**. They compare against native body poses and joint axes,
including the failed trajectories. These are kinematic checks, not fitting.
Further controls cover analytic derivatives, straight-leg damping, correction
direction, yaw-invariant feedback and speed-domain membership, support gating,
invalid inputs, model binding and public-resolver refusal. In **128 real-ABI
steps**, feedback was supported at 122 and withdrawn at six; the independent
core build reproduced the complete decisions, and baseline velocities matched
the retained bits. No new worlds were constructed by these checks.

The [new discovery declaration](../sdk/discovery/cpu_stance_discovery_v1.json)
uses one development seed and **24 fresh CPU worlds**: every candidate at
0.002 and 0.005 m/s initial lateral velocity under the unchanged left-75 motor
model. Each world has a fresh native data instance and private controller memory,
480 commands and five internal steps per command. Full capture and independent
replay cover **11,520 decisions and 57,600 internal samples**. The reader ranks
only feedback candidates with two complete eligible episodes, using mean quality
and candidate index for deterministic ordering. It retains all failed controls
and candidates; a missing or failed start cannot be dropped from ranking.

The complete **105-control zero-world gate passed** in
`sdk2-cpu-stance-discovery-899c0bda7360444d8a654a4bd97cb029`, with 344 source
bindings and 1,359 runtime bindings. Receipt SHA-256:
`d553bccf74645aa76e968720066d21a07c4ad6352731c16e46aed7895baa1f51`.
The gate includes the eight component controls, nine route/ranking controls,
the complete inherited controls, provider refusals and process containment.
Its runtime preflight confirms zero worlds and zero solver steps.

Only complete independently verified discovery may supply later development
fitting. The selected shortlist must be frozen and challenged in fresh native
confirmation before any benefit claim. Nominal-body preservation, GPU transfer,
unopened evaluation, history inference, Tier 3, qualification and release remain
outside this declaration. No physical world has run at this preparation checkpoint.

### Completed CPU stance discovery - 2026-10-23

The [immutable closure](../sdk/discovery/cpu_stance_discovery_closure_v1.json)
records `sdk2-cpu-stance-discovery-d6928fed6753439abd2151b137196809`, launched
from clean published `53cc81c9fe69a2024cf8172a9cc29ef6fd4e909d` after the complete
105-control safety gate. All **24 fresh CPU worlds** completed; no GPU or
evaluation worlds were constructed. The independent reader replayed **11,520
controller decisions and 57,600 internal samples**, including native force,
contact, state, timing, private memory and public-resolver joins.

Every candidate failed both development starts. Baseline retained **0/2 eligible**,
fixed profile 6 **0/2**, and the ten feedback variants **0/20**. All 24 exceeded
the original tilt and torso-contact limits; 13 also failed minimum height. Every
failed episode has null quality and no eligible scoring windows. Recomputing
the declared ranking over the full population yields an **empty shortlist** and
no selected candidate. No fresh confirmation ran.

The [closure verifier](../sdk/discovery/audit_cpu_stance_closure.py) binds
**3,761 artifacts / 1,224,149,785 bytes**, 344 frozen sources and 1,359 runtime
files. It verifies the original full independent reader and optionally reruns
that replay; its ordinary closure pass constructs no worlds. Native worker wall
time was **153.974 s**, and the original independent replay took **136.673 s**.
Receipt SHA-256:
`f9ada73b625b67c219f3da928792c8bf7971248984f163b5c1e1e5d94bdb36cf`.
Independent-audit SHA-256:
`3584c9c6476dc1b365ba197c5075bec481ec2486b009b33e916aac5dc1decee0`.
Closure SHA-256:
`fd462951fff66fd5f791e36367a1888b141ba77cf34f48243b2cfc6a0ee0fca3`.

All **six closure controls passed** in
`sdk2-cpu-stance-closure-controls-82c98205e64c49239f80e095c96fccb4`.
They cover complete evidence, source/runtime tampering, false authority,
erased failures, false selection, post-hoc count changes, and a hand-constructed
cutoff/support/clipping example. The physical result and its original reader
were not edited to obtain this pass.

The [post-hoc diagnostic](../sdk/discovery/stance_pre_failure_diagnostic.py)
counts only commands prepared before the first completed internal sample that
violates an original physical eligibility predicate. For all 24 episodes that
first violation was tilt, at **0.935-1.333 seconds**. Across the 20 feedback
episodes before that cutoff:

| Descriptive count | Numerator / denominator |
| --- | --- |
| Decisions with at least one absolute correction clamp | 1,597 / 2,551 |
| Actuator commands with an absolute correction clamp | 4,704 / 20,408 |
| Actuator commands with a slew clamp | 3,492 / 20,408 |
| Actuator commands with a final speed clamp | 312 / 20,408 |
| Supported knee observations with `abs(sin(knee_angle)) <= 0.1` | 4,229 / 5,105 |

The supported-knee rule is explicitly post hoc. These counts identify control
limits and frequently near-straight support geometry; they do not establish a
cause of falling, an improved survival target, or a new selection criterion.
The inverse-kinematics model remains finite at straight legs, but damping alone
does not create vertical authority there. The next distinct experiment should
separate correction magnitude/slew from posture bias, keep force and final-speed
limits explicit, and retain the original eligibility criteria. No such successor
has run at this closure checkpoint.

The complete verified discovery population may supply later development fitting,
including its failures. That permission does not create useful eligible windows,
a qualified provider, statistical superiority, cross-engine equivalence or
Tier 2/Tier 3 benefit. The earlier CPU and GPU diagnostic populations retain
their original no-fitting scope. SDK1 stays at 20/20 and full-program readiness
at 19/25; qualification and release authority remain false.

### Completed full-state and action-coverage diagnosis - 2026-10-24

The [report](../sdk/discovery/committed_state_coverage_diagnostic_v1.json) and
[reader](../sdk/discovery/committed_state_coverage_diagnostic.py) reopen all
**48 trials, 69,120 controller rows and 345,600 internal samples**. All 24 fitted
source streams are hash-checked: 15 eligible episodes supply 21,600 feature
rows and 21,165 cases; nine failed episodes still supply zero positive cases.
Every original negative, null official quality and empty shortlist is preserved.

All ten [controls](../sdk/discovery/test_committed_state_coverage_diagnostic.py)
pass in sdk2-state-coverage-verification-4496c364e22c425b960cf18e68857ecf,
including complete regeneration, causal action joins, actual shuffled expert
identity, pre-violation censoring and corruption refusal. The earlier
sdk2-committed-state-coverage-6d964a58631615e9a9f0932e848 generated the report
and passed nine focused controls before an explicit editor-update pause
interrupted verification. Its original files and incomplete log remain retained.
The successor verifies identical report/source bytes with zero new worlds.

The six-dimensional cue omits joint positions/velocities, vertical velocity,
roll/pitch rates and previous issued commands/corrections. Its phase bins omit
exact phase. At runtime command **6** (0.05 s) of the uncovered 0.006 m/s start,
current frozen selection uses a phase-release case from source command **389**.
The rear-left knee is at **0.091423 rad** versus **0.724419 rad**, a **0.632996 rad**
gap despite accepted cue/phase/contact support. Across that trial's **204
complete pre-violation commands and 434 selected neighbors**, maximum joint
velocity and previous-command differences approach **4 rad/s**.

Large differences also occur in positives: successful committed-frozen
0.003 m/s reaches **0.702889 rad** joint-position and **5.464182 rad/s**
joint-velocity gaps. These are omitted-state differences, not a failure
classifier, new support threshold or proof of causation. The tested host
supplies history only at command one. Later issued commands reconstructed
from adjacent raw rows here were not inputs the tested selector received.

| Weakened start | First current/committed frozen correction difference | First native-position difference |
| --- | ---: | ---: |
| 0.001 m/s | 71 | 72 |
| 0.003 m/s | 82 | 83 |
| 0.004 m/s | 73 | 74 |
| 0.006 m/s | 65 | 66 |

Both roles have identical native state at the first correction difference.
All 56 pairings, shuffled roles and healthy/baseline identities are retained.
Force-cap labels are recomputed from every sample. Pre-failure fractions use
different trial durations; they are not common-duration effect estimates or
proof of unavailable counterfactual force.

Report SHA-256:
c35964ba310370f1ccbca69de2d112c692c8f4c8ef97e63207726f190e71e9f2.
Verification receipt SHA-256:
5e2a8b2ce36775a06cf04d553e18b1baced2d3d3b7b93640f941ea59dbfcc36f.
The owner checked 273 shared source files, both exact diagnostic sources,
1,357 runtime files and the bound core DLLs without drift. This descriptive
record grants no fitting, selection, causal, recovery or release authority.

### Prospective bounded recovery training - 2026-10-24

The completed handoff comparison found no rescue from the existing task actor.
The [new declaration](../sdk/discovery/residual_recovery_training_v1.json)
therefore trains a recovery actor on states reached by the frozen challenge
controller. Every world starts afresh, follows the challenge through command
59 and switches once at **command 60 / 0.5 seconds**. The destination remains
latched. The challenge actor, warning, production controller host, native
stepping loop, physical eligibility limits and actual-action slew remain
unchanged. No unverified native-state restoration is used.

The warm start is the original exposed-training selection
`iteration_00/d00_plus`, not the earlier final optimizer checkpoint. Its
normalizer remains byte-identical through all updates. Every mechanically
supported observation and unsupported reason is retained; these moments are
diagnostic and never replace deployed scaling. The complete-population
antithetic update keeps the original **0.02 noise / 0.01 step size** and uses
all declared directions. Equal rewards preserve the policy exactly.

The [objective](../sdk/discovery/residual_recovery_training_objective.py)
scores only internal samples **301 onward**. Before the first original
physical or safe-no-actuation violation, each sample receives
`-0.5 * (tilt / 0.6)^2`; from the first failure through the fixed horizon,
every sample receives **-1**. A failure in the challenge prefix leaves the
entire post-handoff interval negative. The denominator is always **300 samples**
in the fixture or **6,900 samples** in the pilot. Original walking reward,
full-horizon failure, and official quality remain separate diagnostics;
failed official quality remains null.

| Lane | Training search | Fresh challenge references | Fresh comparisons | Horizon and seed |
| --- | --- | --- | --- | --- |
| Execution fixture | 2 worlds, one direction, one update | 1 world | 4 worlds | 1 s; 104240901 |
| Bounded pilot | 64 worlds, two directions, two updates | 16 worlds | 32 worlds | 12 s; 104241001 |

The pilot includes weakened-left and healthy motors at all four exposed
training starts. Each training stage has its own challenge-only reference
for every group. Every candidate must exactly match that stage's reference
through the native prefix and the handoff observation. The fixture must
complete on the same source freeze before pilot launch; its data cannot
initialize the pilot. The pilot declares **161,280 controller commands /
806,400 internal samples**. No GPU or reserved calibration/evaluation world
is declared.

Before comparison, all **eight candidate families** across both iterations
are ranked by descending eligible-group count, descending worst-group
recovery reward, descending mean recovery reward, then lexical identity.
Every group and negative trial is required. The initial and final optimizer
checkpoints remain separate controls and cannot enter this perturbation-only
selection. Comparison results cannot fit or reselect a model.

The four comparison roles are fresh challenge-only, unchanged initial
recovery, fixed final checkpoint and training-selected recovery. The finite
pilot screen requires the selected recovery to remain eligible for the full
horizon in **8/8 groups**. Completing the pipeline does not require that
screen to pass. Survival alone does not establish walking quality, a safe
backup region, robustness, useful memory, Tier 2/Tier 3 qualification or
release authority.

The [native owner](../sdk/discovery/run_residual_recovery_training.py) holds
the global operation mutex, contains every child, requires clean published
source for physical work and retains every consumed identity and partial
failure. The worker directly reuses the published native trial function.
The [reader](../sdk/discovery/audit_residual_recovery_training.py) directly
reuses the published other-core raw replay, then reconstructs the new reward,
actual handoff and fresh paired prefix. Separate zero-world processes verify
each complete update and the selected original model bytes before later
stages can use them.

All **18 analytical component controls** pass at
`<evidence-root>/sdk2-recovery-training-component-c6458c730f9f4f0ab6d0ea99853f280c`,
receipt `d167b523de2eaff2544adc2a7135f83efb6707b21c2925fd6b6310b2d2ff203d`.
The complete gate passes **327 controls**, including **24 new integration
and corruption controls**, at `<evidence-root>/sdk2-recovery-training-759251e9f52f46ae875daf5bc472937c`,
receipt `3e432941d9c7e13525a79bf19c8694be7ac240220c922a37fe692888ad5a2818`. It retains **579 source / 1,359 runtime bindings**
unchanged. The new integration fixture replays the first 120 commands of a
retained recovery trial, with its original violation at internal sample 479;
counterfactual actor replays and analytical updates open no physics and supply
no pilot training data.

The [research notes](research/LOCOMOTION_RESEARCH_SOURCES.md#recovery-specific-objective-and-fixed-scaling---2026-10-24)
explain the separation of task and recovery objectives and the fixed-scaling
choice. No external code or model weights are imported. Native route and
pilot execution remain pending at this prospective checkpoint.

### Completed paired recovery handoff diagnostic - 2026-10-24

The [native closure](../sdk/discovery/residual_recovery_closure_v1.json)
records the complete comparison from clean, published **24e1ee2d15a14720940525dc4103a03dde10060b**.
All **275 safety controls** pass before **14 fresh CPU MuJoCo worlds** open:
**20,160 controller commands**, **100,800 internal samples**, two exposed groups,
seed **104240801**, and a fixed **12-second** horizon. No GPU, training,
reserved calibration or evaluation world opens.

**None of the eight interventions rescues its challenge trajectory.** The
table accounts for every world; a time denotes the first declared tilt
violation, and completion means eligibility through this finite horizon.

| Controller arrangement | Weakened left motors | Healthy motors |
| --- | --- | --- |
| Selected actor throughout | Completes 12 s | Completes 12 s |
| Challenge actor throughout | 0.841667 s | 1.266667 s |
| Baseline throughout | 1.063333 s | Completes 12 s |
| Baseline from command 60 | 0.825000 s | 2.056667 s |
| Baseline at warning | 0.843333 s | 1.251667 s |
| Selected actor from command 60 | 0.798333 s | 2.221667 s |
| Selected actor at warning | 0.841667 s | 1.253333 s |

The scheduled handoff occurs at **0.5 seconds** in both conditions. The unchanged
warning triggers at **command 86 / 0.716667 seconds** when weakened and
**command 140 / 1.166667 seconds** when healthy. Every handoff is delivered.
Baseline handoff removes the residual immediately; selected-actor handoff
applies the original actor while preserving the **0.08 rad/s per-command slew**
from actual preceding corrections. The one-way latch and unsupported fallback
remain intact.

All **8/8 native prefixes and handoff observations** exactly match their fresh
challenge-only reference. Earlier intervention is not uniformly beneficial:
relative to challenge-only, early baseline/selected handoff moves weakened
failure **16.67/43.33 ms earlier**, while delaying healthy failure
**0.790/0.955 seconds**. These are failure-time changes, not successful recovery
or quality improvement. All **11 negative trials** retain null official
quality; only the three eligible controls receive quality scores.

The original independent reader reconstructs every command with the other
core DLL and verifies native state, held inputs, forces and timing without
new physics. The [closure reader](../sdk/discovery/audit_residual_recovery_closure.py)
reopens all **2,520 retained artifacts**, reconstructs raw scores, handoff
transitions and paired prefixes, and preserves that original replay receipt.
All **ten closure controls** pass with zero new worlds. The native owner retains
**565 source / 1,359 runtime bindings** unchanged. Exact attempt identities and
digests are in the closure and support matrix.

**Next:** develop recovery as a distinct bounded objective using the exposed
challenge prefixes and actual executed-action history. Fresh starts can
reproduce the declared challenge prefix before a candidate handoff, avoiding
unverified native-state restoration. Freeze any new training objective,
candidate population, handoff times and comparison rules prospectively, then
run the complete gate before new worlds. Evaluate recovery capability before
retuning warnings or introducing return-to-task decisions. This result does
not prove that every earlier timing or another controller must fail.
No weights or thresholds were fitted here; all four reserved starts remain
unopened. Safe-backup, Tier 2/Tier 3, broader robustness and release authority
remain false.

### Prospective paired recovery handoff diagnostic - 2026-10-24

The completed withdrawal diagnostic below delivered the requested baseline
handoff but rescued neither challenge group. The [new prospective contract](../sdk/discovery/residual_recovery_v1.json)
separates two development variables: **command-60 intervention** versus the
unchanged warning's first request, and **baseline** versus the unchanged
selected actor as the recovery controller. The early command is a scheduled
route intervention at **0.5 seconds**, not a new prediction threshold.

The [provider](../sdk/adaptation_provider/warning/recovery_v1.py) packages both
original actors and the same full-data warning in one immutable composite.
The selected actor remains the original random search perturbation
`iteration_00/d00_plus`; it is not the final optimizer checkpoint or a newly
trained recovery policy. Its ability to succeed from the initial state does
not establish recovery from a state produced by the challenge actor.

| Role in each condition | Before handoff | After handoff |
| --- | --- | --- |
| Selected only | Selected actor | Same actor for the full horizon |
| Challenge only | Challenge actor | Same actor for the full horizon |
| Baseline only | Deterministic baseline | Same baseline for the full horizon |
| Early baseline | Challenge actor through command 59 | Baseline from command 60 |
| Warning baseline | Challenge actor until the first frozen warning request | Baseline |
| Early selected | Challenge actor through command 59 | Selected actor from command 60 |
| Warning selected | Challenge actor until the first frozen warning request | Selected actor |

Every role has fresh native model/data/controller setup under each of the
weakened and healthy `train_001` conditions. The single development seed is
**104240801**; each of the **14 CPU worlds** has **1,440 commands / 7,200 internal
samples / 12 seconds**. No GPU, fitting, reserved calibration or evaluation
world is declared. All fourteen outcomes remain in the denominator.

The [production host](../sdk/discovery/residual_recovery_control.py) preserves
actual issued-action history continuously. Baseline handoff removes the residual
immediately through the existing v1 refusal. Selected-actor handoff retains the
**0.08 rad/s per-command slew** from the actual preceding correction and the
existing correction/final-speed bounds. Unsupported observations still refuse
to baseline, including after selected-actor handoff.

The first handoff latches its destination for the remainder of the episode.
This isolates timing and recovery capability from the return-to-task rule;
it does not evaluate reentry to the challenge actor. The warning remains in
shadow after handoff. A later successor must measure any return-to-task rule
prospectively rather than inferring it from this latch.

**26 component controls** pass over **5,120 new-host decisions** and **1,280
original-actor comparisons** from two retained exposed groups, 160 commands,
eight modes and both core DLLs. The pure actor modes preserve original command
bits; baseline-only matches provider absence. The controls exercise the exact
natural warning, scheduled request, latch, real-history continuity, handoff
slew, unsupported fallback, immutable models and fail-closed lifecycle.
These are counterfactual retained-input replays, not new physical outcomes.
Attempt: `<evidence-root>/sdk2-residual-recovery-component-fb31589031eb4dc3a3955365577f84b2`,
receipt `4a2e811822d1e8ca6ed73c0a4d9439a3fc6d96f1a2d38f148064f69e5a167e42`.
All **551 source / 1,359 runtime bindings** remained unchanged.

The complete zero-world owner passes **all 275 controls** at
`<evidence-root>/sdk2-residual-recovery-04602631ecfd4146a771aee8b1b5d6ef`,
receipt `72ad484bf1d8d774c841f9efdee2469fb04b951ecc0999618b9d5e4d78a6e55c`. It binds
**565 source / 1,359 runtime files** without drift. Runtime preflight opens no
worlds or solver steps and declares **20,160 controller rows / 100,800 internal
samples** for the future native comparison. Native execution is pending at
this prospective freeze.

The [native owner](../sdk/discovery/run_residual_recovery.py) requires the
complete **275-control zero-world gate**, containment, operation mutex and clean
published freeze. The native capture loop is byte-identical to the closed
withdrawal loop. The [independent reader](../sdk/discovery/audit_residual_recovery.py)
replays every decision through the other core DLL, audits every native input/
state/force/timing sample, and compares each intervention against its fresh
challenge-only reference up to handoff. Pre-handoff traces and the handoff
observation must match exactly; no retained physical baseline is substituted.

Recovery success is not required for a complete record. Failed episodes retain
null official quality; quality differences require two eligible episodes and
failure-time differences require two failures. Fresh selected-only and baseline-
only controls provide additional context. This is a finite development
comparison informed by the [recovery-capacity research notes](research/LOCOMOTION_RESEARCH_SOURCES.md#recovery-capacity-and-action-provenance---2026-10-24),
with no automatic actor promotion, learned recovery-region claim, safe-backup
guarantee, Tier 2/Tier 3 completion or release authority.

### Completed residual withdrawal diagnostic - 2026-10-24

The [complete closure](../sdk/discovery/residual_withdrawal_closure_v1.json)
retains **ten fresh CPU worlds** from clean published `d8d80cc3`, following
all **218 applicable zero-world controls**. Every declared role completes its
12-second capture: **14,400 commands / 72,000 internal samples**, with **six
eligible and four negative trials**. Both exposed `train_001` conditions and
seed **104240701** match the prospective declaration. The actors, warning and
thresholds are unchanged; no comparison data fits or selects a model.

**Execution is verified; the two automatic interventions do not rescue the
challenge actor.** In both selected-actor groups, the silent guard preserves
the shadow native trace byte-for-byte and changes quality by exactly zero.
The explicit command-90 request removes a nonzero residual immediately at
**0.75 seconds**, withholds it for **30 commands**, and reenters at command
120 / **1.0 seconds**. The first resumed correction is bounded by **0.08 rad/s**
from the actual zero residual. Both forced-route trials remain eligible.
Their tracking-quality changes versus shadow are **-0.002607374 m/s**
(weakened) and **-0.004828619 m/s** (healthy). These are quality-score changes,
not walking speeds. The explicit request is a route control, not a warning
prediction or successful rescue.

| Challenge condition | Natural warning and withdrawal | First tilt violation, shadow | First tilt violation, guarded | Guarded change |
| --- | ---: | ---: | ---: | ---: |
| Weakened | 0.716667 s | 0.841667 s | 0.843333 s | 1.67 ms later |
| Healthy | 1.166667 s | 1.266667 s | 1.251667 s | 15 ms earlier |

The warning leads the guarded trial's own first violation by **126.67 ms**
and **85 ms**, respectively. Neither challenge reenters before its retained
failure; later unsupported observations continue baseline fallback. All four
challenge episodes remain negative with null official quality. Their paired
capped training rewards are equal despite changed failure times, so reward
equality is not evidence of physical equivalence.

The original independent reader replays every controller decision through
the other core DLL and checks native state continuity, held commands, forces
and timing. It does not independently resimulate physics. The
[closure reader](../sdk/discovery/audit_residual_withdrawal_closure.py) reopens
the complete retained inventory, reconstructs raw scores and warning/withdrawal/
reentry events, and preserves that original replay receipt. Its **nine controls**
open **zero worlds** and perform **zero solver steps**.

- Native attempt: `<evidence-root>/sdk2-residual-withdrawal-d2fee1da3f3d41a18ff1cb838b49320a`,
  receipt `21c6b6a3ea9b01f49b6e1c811b386d613288eb00eccc74b2c0fb667f0d92e2cc`.
- Closure controls: `<evidence-root>/sdk2-residual-withdrawal-closure-controls-e86f113370d14311a8218eb716df3791`,
  receipt `8edfe44fcca337cd0af8488701719a5205bb54d87aade7e5c814f99839fa85cc`.
- Repository closure SHA-256: `245ffbe943ec9849c1f58e773c8ce962deb2847abbf9b9264b05cc35a4eb733d`.
- Native execution retains **2,121 artifacts** and unchanged **548 source /
  1,359 runtime bindings**. Closure controls bind **552 source** files and the
  same runtime population. Full evidence remains in the durable archive on L:.

The next distinct development question is whether an earlier intervention or a
more capable recovery action changes these failures. Prospectively separate
trigger timing, recovery-controller choice and reentry; use fresh paired
worlds and preserve all failed transfers. The [research follow-up](research/LOCOMOTION_RESEARCH_SOURCES.md#recovery-capacity-and-action-provenance---2026-10-24)
motivates this separation without importing another method's safety guarantees.
Do not retune the observed warning contract or treat baseline withdrawal as
a proven backup. Keep all four reserved starts unopened until a separate
calibration/evaluation contract, then test useful reversible Tier 3 memory
against matched frozen, disabled and shuffled controls. This diagnostic grants
no Tier 2/Tier 3 completion, cross-engine equivalence or release authority.

### Prospective residual withdrawal diagnostic - 2026-10-24

The [new provider](../sdk/adaptation_provider/warning/control_v1.py) and
[production host](../sdk/discovery/residual_withdrawal_control.py) join the exact
selected residual with the frozen full-data warning. They preserve both original
model identities and thresholds. An automatic warning produces the existing v1
`uncertain` response, immediately removing the residual correction. The host
continues to record the commands actually resolved and issued while the residual
is withheld. Reentry needs 30 consecutive supported scores below the exit
threshold and resumes slew limiting from the actual zero correction.

The component owner passes **26 controls** over **2,800 new-host decisions** and
**560 original-actor comparator decisions**, using two exposed input groups,
five modes and both core DLLs. Silent-monitor targets match the original actor;
the explicit command-90 request reaches zero immediately and the retained-input
control reenters at command 120. These are counterfactual retained-input replays,
not new physical transitions. The component attempt is
`<evidence-root>/sdk2-residual-withdrawal-component-bf6f25819f144f2398dffaad3d00e5e9`,
receipt `b06a07ed6a4883404b1b3555981bd6ce6c41aa4231b399e96e7d5dafa314b11b`.
It binds **537 source** and **1,359 runtime** files without drift and opens no
worlds or solver steps.

The [prospective campaign](../sdk/discovery/residual_withdrawal_v1.json) declares
one development seed, **104240701**, and only `train_001` under the weakened and
healthy body conditions. Each role receives fresh native setup and the complete
**12-second / 1,440-command / 7,200-internal-sample** horizon:

| Role in each condition | Actor | Withdrawal behavior |
| --- | --- | --- |
| Selected shadow | Unchanged `iteration_00/d00_plus` | Records warnings; retains supported actor control |
| Selected guarded | Same selected artifact | Frozen warning and hysteresis control withdrawal |
| Selected forced | Same selected artifact | One explicit command-90 request; unchanged natural reentry rule |
| Challenge shadow | Unchanged `iteration_00/d00_minus` | Records warnings; retains supported actor control |
| Challenge guarded | Same challenge artifact | Frozen warning and hysteresis control withdrawal |

The challenge is the selected actor's antithetic partner from the original
training population, where all eight groups failed. This is an explicit
retrospective challenge choice, not a new fitted model. The forced request changes
neither observations nor prediction scores; it is a route control. No comparison
data may alter the actors, warning, normalization, thresholds or selection.

The [single owner](../sdk/discovery/run_residual_withdrawal.py) requires all
**218 applicable zero-world controls**, process containment, the operation mutex
and a clean published source freeze before launch. The native worker preserves
the established full-capture loop. The
[independent reader](../sdk/discovery/audit_residual_withdrawal.py) replays every
controller decision through the other core DLL, checks every held solver input
and native state transition, and independently reconstructs the warning state,
immediate-zero handoff and reentry accounting.

Completion does not require rescue. All ten outcomes remain in the denominator;
failed episodes keep null official quality. Quality changes are reported only
when both compared episodes are eligible, and failure-time changes only when
both fail. A silent monitor must preserve the selected shadow trajectory exactly.
The campaign records actual intervention lead without declaring it sufficient
for safety. Bare-baseline and disabled native worlds are covered by the
predecessor comparison, not repeated in this ten-world diagnostic.

The complete zero-world owner also passes all **218 controls** at
`<evidence-root>/sdk2-residual-withdrawal-0ea65707f9a3440c87d32f760ee2b5e6`, receipt
`2d469e34f3d59b44816d187dab86812c192554c2af733fd5c9f4aa9426a0ab9c`. Runtime preflight constructs no worlds;
all source/runtime bindings remain unchanged. Native execution is
**pending at this prospective freeze**. The deterministic
baseline remains an unproved backup in the weakened condition. Reserved
calibration/evaluation starts, useful Tier 3 memory, other engines, robustness,
qualification and release remain outside this campaign.


### Completed residual failure-warning component - 2026-10-24

The [warning closure](../sdk/discovery/residual_warning_closure_v1.json) retains a
causal, immutable linear score for the first original physical violation or
safe-no-actuation within the next 30 commands (0.25 seconds). The runtime uses
current canonical observations and the actual prior resolved command.
Unsupported observations request withdrawal, and reentry requires 30 consecutive
supported scores below the separate exit threshold. This component ran in
shadow mode at its freeze. The separately declared native withdrawal successor
above now records actual interventions without changing this fitted artifact.

All **64 original training episodes**, including **49 failures**, remain in the
source population. The complete **92,160-command / 460,800-internal-sample**
reconstruction retains **1,470 positive**, **31,472 negative**, **435
right-censored** and **58,783 already-failed** command rows. Every already-failed
row also lacked the original mechanical feature; no pre-failure observation
was unsupported. The fit never invents features, treats censored futures as
negative, or removes a failed episode from the denominator.

A regularized linear fit uses fixed mechanical scales and episode balancing
before class balancing. Four folds omit each entire start across both body
conditions and all eight policies. The threshold is chosen on those crossfit
scores, then the same fitting rule produces a full-data frozen model. Therefore
the alarm metrics below are **threshold-tuning and training diagnostics**,
not independent calibration, unopened evaluation, or probability estimates.

| Retained training diagnostic | Crossfit scores at tuned threshold | Full-data model |
| --- | ---: | ---: |
| Failed episodes warned within the target window | 49/49 | 49/49 |
| Successful episodes receiving any warning | 0/15 | 0/15 |
| Selected-controller successful episodes receiving any warning | 0/8 | 0/8 |
| Warnings on 31,472 known-negative commands | 0 | 0 |
| Warning-active positive commands | 600/1,470 | 623/1,470 |
| First-warning lead range | 3.33-168.33 ms | 51.67-158.33 ms |

All observed first failures are tilt violations. In particular, the minimum
crossfit lead is only **3.33 ms**. Warning before a failure does not demonstrate
enough time to change its outcome. The deterministic baseline fails the weakened
body condition, so withdrawing the residual is not an established safe backup.

The frozen [full-data model](../sdk/discovery/residual_warning_model_v1.json)
has canonical digest
`sha256:1ca62d154320deb1159f9370bbc3da3660346750297cc1d06b437133cb3548b5`.
Its score threshold is **0.9391314053184975**, exit threshold is 0.05 lower, and
the score is not a probability. The [recipe](../sdk/discovery/residual_warning_v1.json)
binds the exact population, label order, fixed features, weighting, numerical
method and fold identities. Route, final-comparison, selected-artifact comparison,
reserved and excluded-confirmation data do not fit the warning.

**20 component controls**, **eight independent-reader corruption controls** and
**six closure controls** pass. The reader reopens all original training streams,
reconstructs first failures, features, labels, fits and shadow decisions, and
checks all five fitted models with augmented least squares as a second numerical
method. The closure controls verify the complete retained artifact inventory and
that reader's receipt; they do not repeat fitting or production-controller replay.
Source and runtime bindings remain unchanged during each owner operation.
All work opens **zero worlds** and performs **zero solver steps**.

- Fit attempt: `<evidence-root>/sdk2-residual-warning-fit-181bfb8ddc6d48ecaa78aec031294cab`,
  receipt `1751edcf121cbc7b0ac2ff855219d6c14fdca243b3a7316bf7a61844fff80f9d`.
- Closure controls: `<evidence-root>/sdk2-residual-warning-closure-controls-0bf57d9875f84498b1ddc0140fb0734f`,
  receipt `d51588c5052b83cef40d92c2dbd661716149cbde67b85515df847d94d08c2c5d`.
- Repository closure SHA-256: `95532a01598e27ae5b75e7a8a903de762f366b9cdde58e0ecb9078ffb0a739df`.
- The fit retained **35 artifacts / 117,138,453 bytes**, with **528 source**
  and **1,359 runtime** bindings unchanged. Closure controls bind **533 source**
  and the same runtime population. The original training worlds are reused only
  as retained data; this component opens no new worlds.

The next work is a separately declared intervention study: measure whether the
actual v1 withdrawal and reentry path has enough lead time and preserves control,
including the immediate-zero residual handoff. A timely-warning requirement must
be chosen before any safety-oriented threshold successor. Keep the selected
actor's eight-group result unchanged, preserve all four reserved starts unopened
until a new prospective calibration/evaluation contract, and then test reversible
Tier 3 memory against matched frozen and disabled controls. Tier 2/Tier 3,
cross-engine qualification and release remain unproved.


### Completed frozen residual selection comparison - 2026-10-24

The [complete selected-artifact closure](../sdk/discovery/residual_selection_closure_v1.json)
binds the fresh **24-world CPU comparison** from clean published **3a04722f**.
All **138 applicable zero-world controls** pass before launch. Every role has
fresh native setup; the one development seed and all **eight exposed groups**
retain their frozen **12-second / 1,440-command** horizons. No GPU worlds run,
and no comparison data fit weights, normalization or selection.

The selected initial perturbation **iteration_00/d00_plus** is unchanged at
`sha256:f340fd7eb79abdb7ed52a93ad8f1bb038ba46d1406c81f3ea422cded17ee3c1f`.
It is eligible in **4/4 weakened** and **4/4 healthy** groups.
Healthy quality is preserved at **4/4 starts**. The declared complete
finite development screen **passes**. All four healthy scores change by
**+0.00069041 to +0.00591300 m/s** relative to fresh baseline.
These are changes in the existing tracking-quality metric, not raw walking
speed or a population-wide performance claim.

| Development group | Selected eligible | Selected quality (m/s) | Baseline quality (m/s) | Paired quality change (m/s) |
| --- | --- | ---: | ---: | ---: |
| left_075_train_001 | yes | -0.09665287 | null | not comparable |
| left_075_train_003 | yes | -0.09643404 | null | not comparable |
| left_075_train_004 | yes | -0.09837920 | null | not comparable |
| left_075_train_006 | yes | -0.09795363 | null | not comparable |
| nominal_train_001 | yes | -0.09387661 | -0.09978961 | +0.00591300 |
| nominal_train_003 | yes | -0.09745613 | -0.09994397 | +0.00248783 |
| nominal_train_004 | yes | -0.09733242 | -0.09869678 | +0.00136436 |
| nominal_train_006 | yes | -0.09869947 | -0.09938988 | +0.00069041 |

All **eight disabled raw trajectories exactly equal their fresh baseline
trajectories**. The complete population contains **16 eligible
and 8 negative episodes**; every negative remains retained
with null official quality. Independent replay checks **34,560 commands and
172,800 internal samples** using the baseline core reader and unchanged
production semantics. All **514 source and 1,359 runtime bindings** remain
unchanged. The owner retains **1,953 artifacts / 4,488,194,058 bytes**.

The [closing reader](../sdk/discovery/audit_residual_selection_closure.py) and
[eight contained controls](../sdk/discovery/run_residual_selection_closure.py)
reopen the full artifact population, rederive the training-only selection,
recompute raw rewards and quality, and reconstruct the fixed comparison.
They preserve the original complete command-replay receipt; they do not
perform a second production replay or open new worlds. Corrupt population,
model/fit/receipt bindings, authority, scores and summary controls refuse.

- Native attempt: `<evidence-root>/sdk2-residual-selection-3a1a5cb9863c4e8aaf0daa805ab8802f`,
  receipt `9b7a0c160672c61c5d85bea47554a1b3d65694df072194605ae752af86f2254b`.
- Closure controls: `<evidence-root>/sdk2-residual-selection-closure-controls-f7894710f4084a059b8b2d971780f22a`,
  receipt `9958f2068a50a8c2beb8048a74eddd27d55779107be62492df1ae585c2a5f45a`.
- Repository closure SHA-256: `2a6326d3f3edb8c31d5d0ba644fe370b6bb51de2b6ae749847f7503d033ca5e4`.

This remains an explicitly retrospective training selection followed by fresh
development re-execution. It does not replace the prior pilot's failed fixed
final checkpoint, relabel the original random artifact as an optimizer update,
or establish held-out or statistical robustness. All four reserved starts stay
unopened; the excluded earlier confirmation starts remain excluded.

The fixed training-selected artifact has completed its fresh 24-world
development comparison. It passes all eight groups and preserves healthy
quality at every start. Freeze a separate calibration and empirical withdrawal
design before opening any reserved group. Selection remains retrospective and
uses only the complete prior training population; the failed final optimizer
checkpoint remains immutable. Calibrated confidence, withdrawal, unopened
evaluation, useful reversible Tier 3 memory and prospective three-engine
qualification remain required. Tier 3 must compare actual memory-on behavior
against memory-off and shuffled-feedback controls while preserving immutable
weights and reset/rollback.

### Prepared frozen residual selection comparison - 2026-10-24

The [selection record](../sdk/discovery/residual_selection_fit_v1.json) binds the
complete **eight-candidate / 64-episode training population** from the closed
pilot. This is explicitly retrospective development selection: the training
outcomes were already exposed when this rule was written. Every candidate
must be eligible in all eight training groups before ranking by its mean
original fixed-horizon reward, with lexical candidate identity resolving a tie.
Missing, duplicated, crossed or reordered populations refuse selection.
No eligible candidate means no native launch.

The sole eligible candidate is **iteration_00/d00_plus**. Its
[frozen model](../sdk/discovery/residual_selection_model_v1.json) is byte-identical
to the original artifact, SHA-256
`sha256:f340fd7eb79abdb7ed52a93ad8f1bb038ba46d1406c81f3ea422cded17ee3c1f`.
Weights, count-zero identity normalization, output limits and the original
initial-probe corpus label are preserved. Selection itself neither performs
another optimizer update nor changes the failed pilot's fixed-final result.
Route episodes, final-comparison outcomes and reserved starts do not fit this
selection. The complete population includes all earlier negative candidates.

The [comparison contract](../sdk/discovery/residual_selection_v1.json) declares
one development seed, **24 fresh CPU worlds**, **34,560 commands** and
**172,800 internal samples**. Baseline, disabled and selected roles each cover
all four exposed starts under both nominal and weakened conditions, with the
unchanged **12-second horizon**. The selected artifact must be eligible in
all eight groups and preserve fresh baseline quality at every nominal start;
disabled raw trajectories must equal baseline. All comparison observations
remain excluded from fitting. This finite screen supplies no reserved,
statistical robustness, calibrated confidence, Tier 2/Tier 3 or release claim.

The native run_trial function and independent audit_trial function are
byte-identical to their consumed training predecessors. The successor adds
selection/model binding, fresh claims, complete comparison population checks
and a separate contained owner. All **138 applicable zero-world controls**
pass, including the prior training program, native closure, **26 selection/
native-reader controls**, and **eight complete training-closure controls**.
The latter reopen the original raw evidence and reconstruct rewards, moments
and updates without physics. Provider conformance and containment also pass.

Preparation is retained at
`<evidence-root>/sdk2-residual-selection-31246c70df464b7d9826fd70088950f4`,
receipt `97a0ff5c6a0b72ea2b0f44bf525ab7a284df31a1774b6df979dbe47808fe1f15`.
Sources and runtime bindings remain unchanged; **zero new worlds** opened.
Selection-record SHA-256 is `15240c1e54bd92b4cff6fce1b7a706edfdd0a7a2b2aa2fd010c8f18f67c5b07a`;
comparison-contract SHA-256 is `e03ef77efdc5984e526c6b02c5faeb44b4589e71c8dc8d7715f22110bf787e43`.
Publish this freeze before the fresh comparison. Retain any negative outcome
without changing selection, horizons, quality or eligibility thresholds.

### Completed native residual training - 2026-10-24

The [complete training closure](../sdk/discovery/residual_training_closure_v1.json)
binds two consumed attempts from clean published **b29ea283**: the three-world
execution fixture and the **88-world full-horizon pilot**. Both pass all
**104 applicable zero-world controls** before native launch. All **501 source
and 1,359 runtime bindings** remain unchanged. These are CPU worlds; no GPU
throughput result follows.

| Stage | CPU worlds | Eligible | Negative | Interpretation |
| --- | ---: | ---: | ---: | --- |
| One-second execution fixture | 3 | 2 | 1 | Two search worlds produce a verified update used by a fresh third world |
| Pilot iteration 0 | 32 | 12 | 20 | Complete two-direction, eight-group search and first update |
| Pilot iteration 1 | 32 | 3 | 29 | Complete second search and final update |
| Pilot comparison | 24 | 12 | 12 | Fresh baseline, disabled and fixed-final-model roles at all eight groups |

The pilot starts independently from zero weights and identity normalization.
Its **64 training worlds** contribute **33,377 available feature vectors** and
**58,783 explicitly unsupported rows**. All **15 eligible and 49 negative**
training trajectories remain in the fixed-denominator reward population.
Every available vector contributes to normalization, including vectors from
failed episodes; unsupported rows are never invented. The two optimizer
updates are independently reconstructed before the resulting model is used.
The execution fixture and final comparison supply no pilot fitting data.

The final model is
`sha256:3c0f0c1ac35f4fd4ae167fc6f03542222e4aa2df0f3de4ff3930d774e4cfabd4`.
It passes **4/4 healthy** and **0/4 weakened** comparison groups. Baseline and
disabled controls have the same eligibility counts. At every healthy start
the trained model improves the official quality score by **0.00634 to 0.00757
m/s** relative to the fresh baseline. This is a change in the existing quality
metric, not a speed or robustness claim. All eight disabled raw traces exactly
equal their baseline traces. Failed episodes retain null official quality.
The prospective **8/8 eligibility plus healthy-quality-preservation screen
fails**; Tier 2, Tier 3, physical acceptance and release remain false.

Preserve the useful counterpoint: initial search perturbation
`iteration_00/d00_plus` is eligible in **8/8 exposed training groups**,
including all four weakened starts. Its provider artifact is
`sha256:f340fd7eb79abdb7ed52a93ad8f1bb038ba46d1406c81f3ea422cded17ee3c1f`.
It is an initial random perturbation, not either independently updated
checkpoint. It has no fresh baseline comparison, reserved evaluation or
promotion authority. The pilot prospectively selected the final update, so
this lead cannot replace that checkpoint or turn this negative closure into a
pass. The retained outcomes do not isolate why the updates lost recovery:
weights and observation normalization both changed.

The [closure reader](../sdk/discovery/audit_residual_training_closure.py) and
[eight contained controls](../sdk/discovery/run_residual_training_closure.py)
reopen every artifact and raw stream, reconstruct rewards and feature moments,
verify both attempts' update lineages, and preserve the original complete
independent control replay. They do not rerun production control or physics.
Across both attempts the original readers replayed **127,080 commands and
635,400 internal samples** in **91 CPU worlds**. The closure retains **3,497
artifacts / 13,581,259,758 bytes** from those attempts, including every negative
outcome.

- Execution fixture: `<evidence-root>/sdk2-residual-training-a2cd9bf988bb4c36b64e269b3e04de90`,
  receipt `1655d7076540d5aa9792bc26298af791f89a6e5e8b69ddb21ac6d8ef64163389`.
- Pilot: `<evidence-root>/sdk2-residual-training-6810e4b6dce34e9ea9ad471f9f297bf1`,
  receipt `5289b79e1895ffc9450b9565eba06fa4f7575774b472194eb61bcd59ce1f4a90`.
- Closure controls: `<evidence-root>/sdk2-residual-training-closure-controls-5c6f8f317a66416cb03e4ec4a8d706e4`,
  receipt `dd5646ebc55a0beaf329b0a384ce097d94485c9d2e4a56e011da3f95ee9fc9c9`.
- Repository closure SHA-256: `13ea3010c6759dc2bc18e1d126f323af2766f2b6b971a25b2ecc251873534c91`.

Next use a distinct successor to freeze a selection rule over the complete
exposed training population, retain exact candidate weights and normalization,
and challenge the selected artifact against fresh baseline and disabled roles.
Do not fit on the completed comparison or open reserved groups while making
that choice. Diagnose update behavior separately before changing its mechanism.
Then calibrate support and empirical withdrawal, evaluate frozen proposals on
unopened groups, and test reversible episode memory with memory-off and
shuffled-feedback controls. Three-engine qualification remains a separate
prospective target.

### Prepared native residual training - 2026-10-24

The [training program](../sdk/discovery/residual_training_v1.json),
[contained coordinator](../sdk/discovery/run_residual_training.py), and
[independent reader](../sdk/discovery/audit_residual_training.py) now connect
the immutable residual provider to native ARS training. All **104 applicable
zero-world controls** pass, including 26 native/training controls, six retained
native-closure controls, provider conformance and process containment.
The retained attempt is `<evidence-root>/sdk2-residual-training-dc84eaa727c54325809955c15d979747`;
its receipt SHA-256 is `5038633999a08666b9dc69fb97a0c7eb975c1fcf6fcabb960874d14bc4b4904c`. Sources and all runtime bindings are unchanged.
At this historical preparation boundary there were **zero new worlds and no
trained locomotion policy**; the completed execution is recorded above.

The execution fixture declares two antithetic search worlds and one world
using their independently verified update. It uses one weakened-body start,
one development seed, 120 commands and 600 internal samples per world. Its
checkpoint is honestly labeled as trained on that small development fixture;
it has no official quality, selection or promotion authority. The pilot cannot
use that model or those observations for initialization.

The pilot starts from zero weights and identity normalization. Two iterations
use two Gaussian directions, both signs and all eight exposed healthy/weakened
start groups: **64 training worlds**. The fixed final checkpoint then receives
fresh baseline, disabled and trained roles at each group: **24 comparison
worlds**, for **88 total**, **126,720 commands** and **633,600 internal samples**.
Each world retains the existing 12-second horizon. Step size is 0.01, noise
scale 0.02; every perturbation, rollout, reward, available feature row, unsupported
reason and optimizer update remains bound and replayable. Comparison data
never fits weights or normalization. Reserved and exposed-confirmation starts
remain excluded. Serial CPU execution retains full telemetry and unchanged
actuator/slew limits; no GPU throughput or scaling claim follows.

The training objective averages bounded forward/lateral tracking error over
the entire fixed internal horizon. The first physical violation or safe-no-
actuation command receives -1, as does every remaining sample. There is no
positive survival bonus, shortened denominator or post-fall motion reward.
Ordinary valid negatives remain in the complete update; invalid capture rejects
the whole stage. Official quality remains the existing 30-command-window
metric and is null for failed episodes. All eight trained comparison episodes
must be eligible, every healthy start must preserve fresh baseline quality,
and disabled raw traces must exactly equal baseline. This finite development
screen supplies no reserved evaluation, statistical guarantee, Tier 2/Tier 3
qualification or release authority.

The [production profiler](../sdk/discovery/profile_residual_control.py) retained
`<evidence-root>/sdk2-residual-control-profile-1283ec720f534a238e527baf9ef9a799`,
receipt `cc910d527c67273bbf46f341d4c05db4823f24ab61a48b7d781f15de5cbb65dd`.
All **720 decisions** match their native receipts bit for bit, with no physics.
History deep-copies and JSON core calls dominate these short instrumented
traces. Cumulative timings overlap and must not be added. This pilot keeps
the verified controller intact; a semantic performance change would need its
own successor and native verification.

### Completed residual native execution route - 2026-10-24

The [native closure](../sdk/discovery/residual_native_closure_v1.json) records
**three fresh CPU worlds**, zero GPU worlds and zero training/evaluation worlds
from clean published **2f8fb95e**. All **86 applicable safety controls** and the
zero-world preflight passed before the single-use launch. Each absent, frozen
zero-residual and untrained frozen-probe role completed 120 commands and 600
internal steps at the single declared nominal start: **360 commands / 1,800
internal samples** in total.

The zero-residual raw native trajectory is **byte-identical to absent provider**.
The probe transferred nonzero corrections on **119 commands**; its first
different held solver input and first different native position both occur at
**internal step 6**. The independent baseline-core reader reproduces every
controller decision and observation/history/solver-input join. All controllers
close, all three diagnostic prefixes stay within the declared height, tilt and
torso-contact limits, and all official quality scores remain null. One-second
untrained interface stimuli establish neither whole-cycle/full-horizon
performance nor locomotion improvement, calibrated support or useful memory.

Native attempt: sdk2-residual-native-04bd979f12d44cc1afa32b8a61c07de6.
Receipt SHA-256: 309892e72cbc40c373d43750472ef980a68ff54703f4a16ad207bfb4d93bbbc1.
Closure SHA-256: 8bd842a5997762d2e0776c47e589584d03c23bf1f0c1fe9d9a9405a7a992270d.
The complete inventory binds **1,202 artifacts / 757,742,870 bytes**, **492 source
bindings** at the frozen Git commit and **1,359 runtime bindings**. Native work
took **6.520 s**; the complete gate, execution and original audit took **153.703 s**.
The earlier prelaunch manifest failure remains separately retained with zero
worlds and no consumed claim.

Six [closure controls](../sdk/discovery/test_residual_native_closure.py) pass:
complete original replay with guarded world APIs, authority/population refusal,
exact path/inventory/digest checks, crossed or incomplete records, null official
quality, changed-reader refusal and missing historical source refusal. The
[closure reader](../sdk/discovery/audit_residual_native_closure.py) reopens every
artifact and checks the frozen source instead of substituting current HEAD.
It conservatively requires unchanged replay dependencies. It opens no worlds.
Verification attempt: sdk2-residual-native-closure-controls-5d51c9ee39bf45ad97a0197b895da140.
Verification receipt SHA-256: b50e30342e6b0dbe2b9e541332001f4064262a1f74d46e53385628fcca3590dc.

The three captured loops spent **4.738 s in portable control** versus **0.062 s
in native integration**, out of **6.179 s** total loop time. Their JSONL streams
occupy **33,296,125 bytes**. These are descriptive costs for this small CPU route,
not a throughput or scaling benchmark. Profile the composition/provider/resolver
before expanding the training budget; GPU physics alone does not address the
dominant measured cost here. Preserve complete solver inputs and timing when
considering capture changes.

Next freeze an actual training contract: group-balanced rewards and failure
treatment, complete condition/start groups, seeds, iteration/world limits and
independent reward/ARS-update replay. Training must use combined-controller
transitions from new worlds; the smoke stimuli have no training-data authority.
Fresh full-horizon healthy/degraded comparison, calibrated support, empirical
withdrawal, reserved evaluation and three-engine qualification remain open.
Tier 2 and useful Tier 3 remain incomplete.

### Corrected residual native launch manifest - 2026-10-24

The first launch at published a2e9c9ce stopped before tests, the consumed claim
or any world. The owner's snapshot lookup used forward slashes while its
inherited source manifest carried Windows backslashes. The original failure is
retained as sdk2-residual-native-dcfa27d9460c4da9ac741395f3f7a026, with zero CPU
and GPU worlds. Receipt SHA-256: 63240b08ff2f591eed3850ea8e4f97c486a9d651ccda8225c37aa5cef157e32b.

The prospective successor canonicalizes source keys, refuses conflicting
aliases and exercises every snapshot lookup against the actual full binding
manifest. **Fourteen focused controls pass with zero worlds.** The physical
plan, model artifacts, limits and reader are unchanged. The complete required
launch gate is now **86 controls**.

Control attempt: sdk2-residual-native-controls-2f8cc91364354d80813f66a802713de0.
Receipt SHA-256: f0597c056f296559d6f2e2caa83623d4800708051781e3c8b4d6d08a94928d2d.
The support matrix binds all 460 control artifacts and
both files from the failed launch; earlier preparation receipts remain intact.
Next publish this correction and execute a fresh bounded native attempt.
Neither the failed launch nor these controls is physical or training evidence.

### Prepared residual native execution route - 2026-10-24

The [prospective declaration](../sdk/discovery/residual_native_smoke_v1.json)
binds a contained [CPU worker](../sdk/discovery/residual_native.py),
[independent reader](../sdk/discovery/audit_residual_native.py) and
[coordinator](../sdk/discovery/run_residual_native.py). It declares **three fresh
worlds** at one development start: absent provider, frozen zero residual and
a small untrained frozen probe. Each world has **120 commands / 600 internal
steps / one second**. No weakened, training or reserved partition is opened by
this preparation.

**Thirteen focused controls pass with zero worlds and zero solver steps.**
They verify both-core preflight, lossless model loading, full controller replay
and native observation/endpoint/history joins. Corruption controls cover
missing populations, identities, held inputs, state continuity, clock, forces,
contacts, warning counts, model topology, containment and the consumed launch
record. A provider error is retained before any control transfer. A partial
worker result preserves the original error and reports a marker lower bound or
an unknown actual world count. Synthetic changed-action fixtures reuse original
states and cannot pass as new native trajectories or training evidence.

Retained attempt: sdk2-residual-native-controls-55186daa67414ae49c0b50633c1ef22b.
Receipt SHA-256: 2b2c25c42b3902d53b010170fc723940df73699337f7ba0425df5505d6cee1d4.
The support matrix binds **460 artifacts / 474,374,986 bytes**, all six source
files, 492 shared source bindings and 1,359 runtime bindings without drift.
The earlier twelve-control success remains retained. A separate harness
quoting error stopped before imports or tests; its original script and failure
observation are retained and are not counted as an executed control failure.

The clean published launch must pass **all 85 applicable safety controls**
and zero-world preflight while holding the global operation mutex. Every native
child and reader is job-contained. Success requires exact absent/zero raw
trajectory identity, a nonzero probe command followed by a changed native
state, all **360 controller / 1,800 internal rows**, and independent replay
through the baseline core. These are route requirements, not a locomotion
success threshold. All official trial qualities remain null; all acceptance,
selection, training and release flags remain false.

Next execute this bounded route and retain its actual outcome. Then freeze
training rewards and failure treatment, all condition/start groups, seeds and
iteration/world budgets, and implement independent complete reward/update
replay before training. Full-horizon healthy/degraded comparisons, calibrated
support, empirical recovery, useful Tier 3 memory and three-engine
qualification remain separate gates.

### Implemented residual provider and continuous history - 2026-10-24

The [provider](../sdk/adaptation_provider/bounded_residual_provider_v1.py),
[feature contract](../sdk/adaptation_provider/bounded_residual_features_v1.py)
and [production controller component](../sdk/discovery/residual_control.py)
connect the immutable residual optimizer to the actual policy composition and
public adaptation resolver. The [definition](../sdk/adaptation_provider/bounded_residual_provider_v1.json)
binds all six directly used implementations and declares development scope.

Each command supplies **88 canonical values**: the exact S169 descriptor,
height, body-frame up/motion/desired motion, joint positions and velocities,
baseline targets and their actual per-actuator speed limits, the previous
resolved targets/corrections and one-command position-response error, exact
sine/cosine gait phase, observed support and a history-availability flag.
The latest resolved observation/action remains available on every command
after startup. Private episode/model/seed identities prevent stale or crossed
memory; weights and normalizer remain frozen within an episode.

Scope is the declared S169 flat task and mechanical envelope. Domain refusal,
uncertainty and disabled mode return the original baseline through the real
core. Confidence is a declared-domain indicator, not calibrated safety or
recoverability. An absent provider retains its actual receipt and empty history
because v1 cannot represent that status; unexpected provider failures or
unrepresentable resolutions close the host. No status is relabeled.

The resolver keeps the **3.5 rad/s correction** and **0.08 rad/s per-command
slew** bounds and each baseline command's own final-speed limit. The latter
can be 3.0 rather than 3.5 rad/s. Frozen model storage uses lossless compact
JSON and an exact byte digest. Core canonical JSON deliberately quantizes
numbers for receipt identity and is not used to store weights/statistics.

**22 controls pass**: ten optimizer controls and twelve
[provider/host controls](../sdk/discovery/test_bounded_residual_provider.py).
Both core DLLs reproduce all **2,560 decisions** bit-identically: eight retained
condition/start groups, four roles and forty commands per group/core. Absent,
disabled and zero-residual roles preserve baseline command bits. Controls
also cover continuous receipt/history joins, exact phase wrapping, body
coordinates, immutable model round trips and one-bit identity changes,
domain refusal, private resets, provider failures, slew and deliberately
injected absolute/final-speed clamps. Uncertainty fallback retains ongoing
history. All guarded world/solver entrypoints remain unused.

The original native baseline states were reused as test inputs. New residual
commands were never transferred to a solver; these are not new physical
outcomes or valid training transitions for the changed controller.

Retained attempt: sdk2-residual-provider-controls-0e13e714051740eaaccec9bc8997038d.
Receipt SHA-256: 8b803235b4eb8336f2b67ad102f7fbc8f6d85d3ce01e9b4b5c1def161194076c.
The support matrix binds its source snapshots, input hashes, all
81 artifacts and all three earlier failed attempts. The first run
exposed the dynamic speed-limit assumption and lossy model serialization.
The second run passed 21/22 controls but did not naturally reach final-speed
clipping. The third correctly refused an inconsistent artificial baseline.
The final control injects over-limit proposals against unchanged, actually
saturated baseline commands, including the lower knee limit. This completes
coverage without changing the runtime. No failed attempt was overwritten.

Next implement the contained native worker, independent trajectory/reward
reader and complete ARS update replay. Prospectively freeze failure handling,
group-balanced rewards, training seeds/population, iteration/world budget and
the applicable safety gate. First run the smallest declared route ghost that
covers production construction, stepping, finalization, retention and audit.
Then train on actual combined-controller trajectories; keep failed official
quality null and its training reward separate. Fresh full-horizon weakened and
healthy comparisons, calibrated support, reserved evaluation, empirical
recovery withdrawal and three-engine qualification remain required. Useful
Tier 3 memory benefit remains a separate test on an immutable base.

### Implemented bounded residual optimizer component - 2026-10-24

The [pure optimizer](../sdk/adaptation_provider/bounded_residual_ars_v1.py)
implements paired Gaussian parameter search for an immutable linear policy
with bounded tanh outputs. Each iteration freezes its normalizer/perturbations,
requires every declared group in both signs of every direction, averages group
rewards and scales the selected-direction update by paired reward deviation.
All training observations update the next normalizer, including negative runs
and directions omitted from the weight update. Equal rewards leave weights
unchanged; normalizer statistics can still change. Constant coordinates
normalize to zero, which is explicitly not an OOD or support check.

Ten [controls](../sdk/discovery/test_bounded_residual_ars.py) pass in
sdk2-residual-ars-publication-controls-fa37dc4685284f4ea666c6ad9cab5914: analytical update,
complete paired populations, reserved-data refusal, crossed model identities,
arrival-order independence, immutable inputs, finite extreme rewards, bounded
outputs, population moments and twelve optimization iterations on an analytical
plant. That plant is a numerical control, not locomotion. Zero native worlds
or solver steps run. Receipt SHA-256:
0bbdc5c856c04adbeff9f265c128eff2589517a8b1343b9488c4be95aa53effb.
The original ten-control run remains retained. This publication successor
removes only trailing blank lines and adds an optimizer-only LF rule; it
rechecks the identical numerical implementation and exact final source bytes.

This component follows [Mania, Guy and Recht, Algorithm 2](https://arxiv.org/pdf/1803.07055)
with local group averaging, bounds, complete-population checks and a zero
reward-variance rule. [Residual RL](https://arxiv.org/pdf/1812.03201v2)
motivates correction learning on combined-controller transitions;
[RMA's inputs](https://arxiv.org/html/2107.04034v1) motivate richer state and
actual previous actions. No external code, weights, defaults or performance
result was imported, and none of those complete systems has been reproduced.

The next choice is a bounded residual trained on actual induced trajectories.
Richer retrieval alone is cheaper and reuses audited cases, but retains the
finite action family and can reduce support. Residual training can introduce
new corrections at the cost of more simulation and explicit reward/support
validation. The linear component keeps inference small; a later nonlinear
successor can preserve the public proposal ABI if this declared family is
insufficient. Neither option guarantees benefit.

Next connect canonical joint/body state, exact phase and actual prior issued
commands through ongoing causal history. Bind morphology/task/model identity
and explicit support/confidence refusal; verify absent/disabled/zero influence
through both core DLLs. Freeze reward, failure treatment, seed/population,
iteration/world budget, containment and independent update replay before
training worlds. Official failed quality stays null; training reward cannot
replace eligibility. Fresh full-horizon/healthy comparisons, reserved evaluation,
three-engine qualification and empirical recovery withdrawal still precede
promotion. Tier 3 then needs demonstrated benefit from bounded resettable
memory on an immutable base. This checkpoint has no native host integration,
trained residual, calibrated confidence or Tier 2/Tier 3 completion claim.

### Completed committed selection comparison - 2026-10-24

The [closure](../sdk/discovery/cpu_committed_feedback_closure_v1.json) retains
`sdk2-cpu-committed-feedback-b4b51448289b40d4a5263d3bc83b6d56`, executed from
clean published `d228a4d40b3bbb4719a1d897e2e94eb84cf258e7`. All **388 controls**
passed before any new world. The owner completed **48 fresh sequential CPU
worlds**, with six roles at each of eight condition/start groups and no
calibration, evaluation or GPU worlds. All original source/runtime bindings
remained unchanged: **522 source files and 1,359 runtime files**.

Independent replay verified **69,120 controller decisions and 345,600 internal
samples** and constructed zero worlds. The result is **29 eligible episodes
and 19 negatives**:

| Role | Weakened starts eligible | Healthy starts eligible | Healthy quality loss |
| --- | ---: | ---: | --- |
| Baseline | 0/4 | 4/4 | Zero at every start |
| Disabled | 0/4 | 4/4 | Zero at every start |
| Current frozen | 2/4 | 4/4 | Zero at every start |
| Current shuffled | 2/4 | 4/4 | Zero at every start |
| Committed frozen | 1/4 | 4/4 | Zero at every start |
| Committed shuffled | 0/4 | 4/4 | Zero at every start |

The committed frozen role passes only the 0.003 m/s weakened start; current
frozen passes 0.003 and 0.004 m/s. Current shuffled passes 0.001 and 0.004 m/s.
Every role fails the 0.006 m/s weakened start. On the sole weakened start where
current and committed frozen are both eligible, the committed tracking-quality
score is lower by **0.00218997082690287 m/s**. This is a finite paired score
difference, not a population inference or a change in the failure threshold.

Of the **56 declared contrasts, 30 are eligible and 26 remain censored**.
Failed whole-episode qualities stay null. No role passes all eight episodes,
so the complete-screen shortlist remains empty. The tested thirty-command
rule is not promoted. Opportunity, actual correction and commitment-event
counts remain distinct, and full dynamic action sequences are retained rather
than labeled as fixed experts.

The [closure reader](../sdk/discovery/audit_cpu_committed_feedback_closure.py)
rechecks the complete **23,243-artifact / 7,962,598,846-byte** inventory,
prospective population, source and runtime bindings, causal prefixes, action
sequences, physical failure censoring, quality windows and healthy comparisons.
Ten [closure controls](../sdk/discovery/test_cpu_committed_feedback_closure.py)
pass in `sdk2-committed-closure-controls-797879304fde4098b1ac386cf1166fe1`.
They include crossed roles and resolver memory, erased failures, altered
quality and denominators, crossed native conditions, and source/runtime
changes. They open zero worlds and do not repeat the already completed full
controller replay. The closure source bytes match the retained tested copies.

Native execution took **1,023.725 s** and independent replay **1,030.881 s**.
Closure SHA-256 is
`5aeb46084f5431386656a029f3a887433945c0df97f3180a6ac58d0ba2b5d633`;
the original receipt is
`0e9391b705e4dbaaa8112f2bc336e3169436f432c57b9c2d634ff6676dee9b9e`
and original independent audit is
`2c6648bfcbac08f9980e2d560d946691701b30526aa5f1543cae1d9d042d9323`.
Large artifacts remain in the relocated durable evidence store through the
unchanged compatibility path.

This rejects the tested timing rule as the next candidate. It does not prove
that every temporal policy will fail or that switching alone caused the
observed failures. Next diagnose early control divergence and state and action
history coverage, then declare a distinct successor that can strengthen
control on the states it actually reaches. A bounded learned residual is a
research option through the existing provider seam. Keep all failed training
episodes, the healthy baseline, original eligibility and unopened reserved
partitions. No outcome-memory updates, useful Tier 3 behavior, statistical
superiority, cross-engine qualification or release authority is established.

### Prepared committed selection comparison - 2026-10-24

This preparation checkpoint is retained below; the completed comparison above
records its subsequent execution and outcome.

The [prospective declaration](../sdk/discovery/cpu_committed_feedback_v1.json)
compares six fresh roles at all four exposed starts in both weakened and healthy
motor conditions: **48 CPU worlds**, each twelve seconds, 1,440 controller
commands and 7,200 internal samples. It keeps development seed 104232601 to
isolate the timing change under the existing exposed starts; every world still
has fresh setup and private memory. Calibration and evaluation stay unopened.

| Role | Selection implementation | Actual correction |
| --- | --- | --- |
| Baseline | Deterministic baseline | None |
| Disabled | Committed selection | Suppressed |
| Current frozen | Original dense selector | Original association |
| Current shuffled | Original dense selector | Shuffled association |
| Committed frozen | Supported thirty-command commitment | Original association |
| Committed shuffled | Supported thirty-command commitment | Shuffled association |

Seven contrasts per group give **56 paired comparisons**: committed versus
current, the same timing comparison under shuffled associations, each selector
versus its shuffled control, committed versus baseline/disabled, and disabled
versus baseline. Failed quality remains null. Selection still requires all
eight episodes eligible and zero observed healthy-quality loss at every start.
No statistical superiority or non-inferiority claim follows from that screen.
Opportunity, actual influence and commitment events are reported separately.
Dynamic sequences remain dynamic; they are not relabeled as fixed experts.

The [host](../sdk/discovery/committed_feedback_control.py) gives each role its
own provider/model binding and uses the same production baseline and resolver.
Nine [host controls](../sdk/discovery/test_committed_feedback_control.py) pass
under `sdk2-committed-host-controls-2a6a488d51aa413c859614c7b2c5df5e`, retaining
**3,360 input-driven decisions** across both real core DLLs. Current roles
reproduce the original host, every healthy role preserves baseline bits, and
explicit stimuli verify expiry, closure, absence fallback and crossed models.
The [independent reader](../sdk/discovery/audit_committed_feedback.py) checks
neighbors, expert arithmetic, interval events, resolver limits and the exact
provider-to-resolver memory join. These are retained-input checks, not new
physical trajectories. Receipt SHA-256 is
`a0bfed5cbe94fbaa23ad5c6afbca55f5d3c249c7364c73e5abdfa83013ec415b`.

The initial attempt `sdk2-committed-host-controls-64f1de9b8c2c44e2907b0467d3ea06de`
retains eight passes and one missed corruption. Its reader did not join the
resolver's returned memory to the provider's response. The separate diagnosis
`sdk2-committed-host-reader-diagnostic-21cac68028484924bee464c63d0a06bd`
identifies that exact missed stimulus while all 3,360 valid joins match. The
successor enforces the join and corrupts it independently in all six roles.
The failed receipt and diagnostic remain bound in the support matrix; no
original evidence was rewritten.

Fourteen [route controls](../sdk/discovery/test_cpu_committed_feedback.py) pass
in **223.563 s** under `sdk2-committed-route-controls-93f482f8f3344ff5b6322057b217d0cd`.
They cover all 48 synthetic transport cells, actual ABI preflight, disjoint
partitions, original quality/censoring rules, current-model crossing, force,
state, target, history, commitment and returned-memory corruption. A sixty-
command fixture checks complete quality windows and causal feature joins.
They open zero worlds and grant no synthetic training authority. Receipt
SHA-256 is `d288c9624735c7c72b44ab6e591ea6d02b5cc53ab4474fec952e9cd34d2f9421`.
All 522 source and 1,359 runtime bindings remain unchanged during that run.

The [launcher](../sdk/discovery/run_cpu_committed_feedback.py) requires the full
**388-control zero-world gate**, Windows job containment, the operation mutex,
unchanged source/runtime bindings and a clean pushed prospective source before
physical execution. The [worker](../sdk/discovery/cpu_committed_feedback.py)
and [full reader](../sdk/discovery/audit_cpu_committed_feedback.py) retain and
independently replay all 69,120 commands and 345,600 internal samples. The
complete gate has not yet run for this campaign, and no native successor world
has started at this preparation checkpoint. The hardest-start coverage issue,
empirical recoverability, useful Tier 3 outcome memory and three-engine
promotion remain open. Qualification and release authority stay false.

### Implemented committed selection component - 2026-10-24

The distinct [provider](../sdk/adaptation_provider/retrieval/committed_feedback_v1.py)
and [definition](../sdk/adaptation_provider/retrieval/committed_feedback_v1.json)
implement the timing hypothesis from the complete-population diagnosis below.
A supported logical expert chosen at command one persists through command
thirty; command thirty-one reconsiders it using the original gain rule. Loss
of that expert's current case support ends the commitment immediately, allowing
another supported selection or exact baseline fallback. Posture and safe-no-
actuation checks still apply at every command. The shuffled control deliberately
corrupts the expert association after logical support and commitment checks;
that support does not establish safety of the mapped expert.

The new model identity is
`sha256:2b41a1b8c48b8157a077ba98398c1ca8332aa079bbfa394516f385d82c23fd11`.
It binds the new timing definition while retaining the same 21,165-case fit,
context estimator, context bounds, feedback experts and corpus. Healthy context
still chooses baseline. Resolver limits remain 3.5 rad/s absolute correction
and 0.08 rad/s per-command slew. No weights, cases or outcome memories update.
This is a Tier 2 component; commitment state is not Tier 3 outcome learning.

All sixteen [component controls](../sdk/discovery/test_committed_feedback_provider.py)
pass under `sdk2-committed-provider-controls-c3e81e53a643441782a72149a9e59013`.
They include both real core DLLs, baseline bits, context/case filtering, exact
expiry, support withdrawal without residual correction, immutable fitted bytes,
and rejection of crossed identities, stale sequence and rehashed invalid
commitment state. The suite takes 8.561 s and opens zero worlds. Execution binds
published `158c334d` plus the three explicitly owned new component files;
513 source and 1,359 runtime bindings remain unchanged. Receipt SHA-256 is
`3f41a7fec0866dc129a346157ae51c4379ff095ccb44b99532f956841c9d3392`.
The [support matrix](../sdk/release/quadruped_support_matrix.json) binds the
source snapshots, definition, declaration, owner, model and control log.

The earlier attempt
`sdk2-committed-provider-controls-31328f93e4114af7b05e79512b0bb8de` retains
fifteen passes and one invalid expiry fixture. Advancing only its state clock
left the motion command expired, and the actual resolver correctly refused
`TIME_INVALID:command_expired_or_early`. The fresh attempt uses the original
retained command-31 observation and command together. Neither the resolver nor
the observed refusal was changed; the failed receipt remains
`2662d55066823a1f22ff2261256cfee6ca603e1f630934fe7924e455d1ebee40`.

The preparation above now integrates this provider into a distinct host and
independent reader and declares all six roles across every healthy and weakened
start, including the uncovered 0.006 m/s start. The complete safety gate and
clean published prospective freeze remain prerequisites. No native successor
world has run at this preparation checkpoint.
The hardest-start prediction/coverage problem, empirical recoverability,
useful Tier 3 outcome memory, reserved evaluation and three-engine promotion
remain open. No qualification or release claim changes.

### Completed selection-window and case-support diagnosis - 2026-10-24

The [record](../sdk/discovery/conditioned_selection_diagnostic_v1.json) and
[reader](../sdk/discovery/conditioned_selection_diagnostic.py) reopen every
original conditioned-selection episode: forty trials, 57,600 decisions and
288,000 internal samples. All 26 eligible episodes and fourteen negatives keep
their original disposition. A failed episode's official quality remains null.
No new worlds, fitting, selection or outcome-memory update occurred.

A case predicts a fixed expert's next thirty commands. The diagnostic joins
that prediction to the expert actually proposed, including shuffled mappings,
and measures the actual subsequent trajectory. Disabled or rejected proposals
receive no prediction-error score. Only complete windows strictly before the
first physical violation enter the following table. Windows that change or
withdraw their expert describe mixed behavior, not fixed-expert counterfactuals.

| Weakened role | Scored windows | Constant expert | Mixed or withdrawn | Constant mean prediction minus actual quality | Mixed mean prediction minus actual quality |
| --- | ---: | ---: | ---: | ---: | ---: |
| Frozen | 3,199 | 1,155 | 2,044 | +0.00748503 m/s | +0.02474633 m/s |
| Shuffled | 2,710 | 688 | 2,022 | -0.01029450 m/s | -0.00131169 m/s |

The denominator includes available predictions for the actual proposed expert;
434 applied shuffled correction commands have no such prediction. A further
58 frozen and 47 shuffled predicted windows are censored at the twelve-second
horizon. These overlapping windows are not independent trials. Their errors
do not establish survival probabilities, causes or whole-episode benefit.

On the uncovered 0.006 m/s start, both learned roles first lose case support at
**0.725 s**, before physical failure at **1.703333 s frozen** and **1.393333 s
shuffled**. Frozen has 24 direct expert switches before failure; shuffled has
only two. Successful learned episodes have 89 to 108 direct switches. Therefore
switching alone does not explain failure. All nineteen constant-expert frozen
windows and all thirty-three constant-expert shuffled windows at this start
are optimistic, with mean errors **+0.05263396** and **+0.01918781 m/s**.
Temporal commitment cannot be assumed to repair unsupported or aliased states.

Seven focused controls and all eight [full controls](../sdk/discovery/test_conditioned_selection_diagnostic.py)
pass under `sdk2-conditioned-selection-diagnostic-79009d42ea1b4507ab830569d684d8cb`.
The full suite regenerates the complete parent and diagnostic, and rejects
crossed role/state/time, altered raw traces, invented fixed-expert attribution,
changed failed quality and incorrect boundary censoring. It forbids world
construction and stepping. Execution used published `e1d20b6f` plus the two
explicitly owned new reader/test files; all 260 source and 1,357 runtime
bindings remained unchanged. The report SHA-256 is
`030bcb41c5c248645a57d969f3867304f97adcd1ed226627b361393a683c5030`;
the retained receipt is
`d55998b57d7d5a9623ec8e7840be04b012951ef76dd5ccbd9088b4a09069d9d9`.
The [support matrix](../sdk/release/quadruped_support_matrix.json) binds the
execution declaration, owner, receipt and control log.

The next distinct hypothesis holds a supported selected expert for the same
thirty-command horizon used by its labels, with immediate termination when
support is absent. Compare it prospectively against current frozen selection,
shuffled association, disabled control and fresh baseline across all four
healthy and four weakened starts. Keep resolver limits and failure thresholds.
This is a timing hypothesis, not a selected winner or a presumed coverage fix.
Missing state and the uncovered start remain required work. The empirical
recoverability monitor, useful Tier 3 outcome memory, reserved evaluation and
three-engine promotion remain open. SDK1 remains 20/20 and full-program
readiness 19/25; qualification and release authority remain false.

### Completed conditioned selection comparison - 2026-10-23

The [prospective declaration](../sdk/discovery/cpu_conditioned_feedback_v1.json)
ran from clean published `59aacf3cfc361f4ed2d102c32558721053e441a6` under
`sdk2-cpu-conditioned-feedback-258191c7b334449093301732f6e097ba`.
All 349 safety controls passed before construction. Forty fresh sequential
CPU worlds completed the twelve-second horizon, with no GPU, calibration or
evaluation worlds. Independent baseline-core replay verifies every one of
**57,600 controller decisions and 288,000 internal samples**. The full
population contains **26 eligible episodes and 14 negatives**.

| Role | Weakened eligible / 4 | Healthy eligible / 4 | Healthy quality versus fresh baseline |
| --- | ---: | ---: | --- |
| Baseline | 0 | 4 | Reference |
| Provider disabled | 0 | 4 | Equal at all four starts |
| Frozen selection | 2 | 4 | Equal at all four starts |
| Shuffled selection | 2 | 4 | Equal at all four starts |
| Immediate phase reference | 2 | 4 | Lower at all four starts |

Frozen selection and the phase reference pass weakened starts 0.003 and
0.004 m/s. Shuffled selection passes 0.001 and 0.004 m/s. Every role fails at
0.006 m/s. Thus the learned association does not establish improved eligible
coverage over the shuffled control, and no role satisfies the declared
eight-episode eligibility and healthy-preservation screen. The shortlist is
empty. Frozen versus reference quality is higher by 0.004131265 m/s at the
eligible 0.003 start and lower by 0.006300043 m/s at 0.004. Frozen versus
shuffled quality is higher by 0.008010674 m/s at their only shared eligible
weakened start, 0.004. These are finite observations, not superiority or
non-inferiority claims. Only 23/40 declared paired contrasts have two eligible
episodes; the other seventeen retain null quality differences.

All twenty nominal episodes are eligible. Disabled, frozen and shuffled roles
make no nonzero corrections and reproduce baseline whole-episode quality at
each nominal start. The fixed reference loses 0.003218 to 0.004270 m/s of
quality there. This preserves healthy behavior in these exposed training
groups; it does not establish robustness or population-level non-inferiority.

The weakened actual nonzero correction counts, in start order 0.001, 0.003,
0.004, 0.006, are `[275, 1400, 1435, 147]` for frozen selection and
`[1430, 208, 1429, 124]` for shuffled selection. Disabled control has
`[99, 111, 114, 78]` supported correction opportunities but zero actual
influence. The fixed reference applies `[262, 1439, 1439, 163]` nonzero
corrections; a learned selection-opportunity count does not apply to that
role. Every influencing role first changes a command at step one. Provider
errors are zero throughout. Opportunity, influence and survival differ and
remain separate measurements; the comparison does not assume matched influence.

The [closure](../sdk/discovery/cpu_conditioned_feedback_closure_v1.json) and
[reader](../sdk/discovery/audit_cpu_conditioned_feedback_closure.py) bind
**18,132 artifacts, 6,368,093,273 bytes, 506 frozen source bindings and 1,359
runtime bindings**. Closure SHA-256 is
`9727d866d7f1ca81f18c12b2b568e6918cb0be24ad40d0bc8c045bb63246e6c9`.
Original receipt SHA-256 is
`cd4183855cb68f12535829c155e1f4b8843b4a05b23ea2e4462fce6f6297b21a`;
the independent audit is
`401ce91402d6d0f7df9f340d6dda41bc8bea4768ad015b6296222e59785ab9c3`.
The worker took 948.100414 s and independent replay 1003.374134 s. These are
full-capture development timings, not product latency or an engine benchmark.

Nine [closure controls](../sdk/discovery/test_cpu_conditioned_feedback_closure.py)
pass in 224.846 s under
`sdk2-conditioned-closure-controls-fc03cd0898d446669e72d583f96dcd83`, with zero
new worlds. They rehash the complete population, resolve frozen Git sources,
verify current runtime and reader bytes, rejoin actual first-response history,
recompute eligible quality, retain failure censoring and bind every dynamic
action sequence and influence count. They reject crossed condition models,
changed receipts, invented fixed-expert labels and expanded claims. The default
closure verifies the retained independent replay; explicit `--replay` can repeat
all controller and native-trace checks.

The complete-population diagnosis above now measures local predicted action
quality, switching and support loss while preserving shuffled successes and
the uncovered start. A new
selection or outcome-memory rule needs its own frozen comparison; this result
does not justify relabeling dynamic episodes as fixed experts, relaxing an old
threshold or opening reserved evaluation. The empirical recoverability monitor,
useful Tier 3 adaptation and three-engine promotion remain open. SDK1 remains
20/20 and the full program 19/25; qualification and release remain false.

### Prepared conditioned selection comparison - 2026-10-23

The first runtime check exposed a sampling limit: the original 720-case model
has no exact phase/contact match at the first weakened-body decision. Its
refusal was correct. Attempt `sdk2-conditioned-provider-controls-5bcd04ae2724479f8e244242e97de37b`
retains eight passing controls and the failed expectation of an applied
correction. The distinct diagnosis
`sdk2-conditioned-provider-diagnostic-03b2ea566ebc4338a378ee0664cb2481`
retains all 24 exposed queries. The original fit, failed test and support
limits remain unchanged.

The [command-resolution declaration](../sdk/discovery/command_resolution_repertoire_v1.json)
and [closure](../sdk/discovery/command_resolution_repertoire_closure_v1.json)
use every retained command with a complete thirty-command future window.
This produces 1,411 overlapping cases per eligible episode: **21,165 cases
from fifteen eligible episodes**, with all nine failed immediate episodes
retained without positive cases. The full source ledger still has 32 trials;
eight delayed composite episodes remain excluded from single-expert fitting.
These overlapping examples are not independent trials. The thirty-command
outcome horizon, phase bins, exact contacts, 1.5 support-distance bound and
original whole-episode scores remain unchanged. The context estimator is not
refitted. The [reader](../sdk/discovery/audit_command_resolution_repertoire.py)
independently rejoins every cue, action and outcome and reproduces the fit.

Seven fitting controls pass in 98.227 s under
`sdk2-command-resolution-controls-5164dfcc606841cfb9e2039f3c5af630`.
Three closure controls and eighteen sparse/dense provider controls pass under
`sdk2-conditioned-dense-controls-7a36105c5bf1476eb869b535be112f7f`.
Closure SHA-256 is
`19fa595e36719c287f2985298d062e7ce89e25a12f41654c4c46655f7231c7bb`.
The distinct dense casebook is
`sha256:bcf801782709a33d9e5b398770ad606029c33b1067b2bf7a3bac9a9ecba233cb`;
the composite runtime model is
`sha256:8cc55e0017e01a1f7d188a74bcd7729acdcc0ef9e65fa2916d6a3bc96f0c1a96`.

The [frozen provider](../sdk/adaptation_provider/retrieval/conditioned_feedback_v2.py)
infers context after one actual baseline command. Its feature support is the
closed coordinate range of the four training examples per condition, with no
padding or calibrated-confidence claim. Healthy context chooses the complete
baseline default. Weakened context retrieves the nearest supported cases at
the current phase, contacts and body state and selects a vertical or phase
expert; a supported previous action remains unless predicted gain reaches
0.001 m/s. The public resolver retains the 3.5 rad/s correction and 0.08 rad/s
per-command slew bounds. Unsupported context or observations withdraw to the
current baseline. Private context and previous-action state do not update
outcome scores or base weights; this is a Tier 2 development candidate.

The [host](../sdk/discovery/conditioned_feedback_dense_control.py) consumes only
the first baseline history entry, while retaining every subsequent raw state
and actual command. Eight host controls pass in 34.984 s under
`sdk2-conditioned-host-controls-31b21a1ff6234dfca7ea5d0be67bcb28`.
Both core binaries agree on all 1,440 retained-input decisions. Disabled and
healthy selection preserve baseline command bits. Weakened selection first
applies at command one. Independent checks reconstruct nearest cases, expert
proposals, shuffle association and resolver outputs. This replay opens no
world and supplies no new physical outcome.

The [prospective declaration](../sdk/discovery/cpu_conditioned_feedback_v1.json),
[worker](../sdk/discovery/cpu_conditioned_feedback.py),
[reader](../sdk/discovery/audit_cpu_conditioned_feedback.py) and
[contained launcher](../sdk/discovery/run_cpu_conditioned_feedback.py) declare
fresh baseline, disabled, frozen, shuffled and unchanged immediate phase
reference roles. Each runs at all four exposed training starts in both motor
conditions: **40 worlds, 57,600 decisions and 288,000 internal samples**.
Seed 104232601, the full twelve-second horizon, native force capture,
eligibility thresholds and zero-observed-loss healthy-body screen are fixed.
Dynamic-policy episodes bind their actual action sequence and cannot be
misrepresented as fixed-expert episodes. The five declared contrasts retain
censored failed quality, supported correction opportunities and actual
influence separately. No matched-influence claim is assumed.

Twelve synthetic route controls pass in 46.898 s under
`sdk2-conditioned-route-controls-79a1c230740a4dab8f5b29ffe9393d53`.
They use retained states as explicitly synthetic transport fixtures and reject
crossed history, forces, targets, dynamic identities and expanded authority.
The 48 focused controls above opened zero worlds. The completed comparison
above subsequently passed all 349 controls from its clean published freeze.
Calibration and evaluation remain unopened. The empirical recoverability
monitor and useful Tier 3 outcome-memory comparison remain separate work.
SDK1 stays 20/20, the full program stays 19/25, and qualification and release
claims remain false.

### Completed first-response repertoire fit - 2026-10-23

The [declaration](../sdk/discovery/first_response_repertoire_v1.json),
[fit](../sdk/discovery/first_response_repertoire.py),
[closure](../sdk/discovery/first_response_repertoire_closure_v1.json) and
[reader](../sdk/discovery/audit_first_response_repertoire.py) reuse only the
closed phase-release training campaign. Complete parent verification binds
14,636 artifacts and preserves all 32 native outcomes. This work constructs
zero worlds and changes no consumed controller, window, threshold or result.

The [distinct feature definition](../sdk/discovery/first_response_v1.py) uses
one actual baseline command and its two observed joint positions. The one-step
window was chosen as the earliest causal response before fitting, without a
window sweep. At 120 Hz this is 0.008333333 s of simulated observation, not
measured host inference latency. Eight groups each rejoin two matching fresh
baseline prefixes. Neither condition labels, future outcomes nor provider
identity enter the feature vector. Four internal folds hold both conditions of
one training start out together. The result is **8/8 correctly classified**,
versus 4/8 for constant nominal and 0/8 for synthetic reversed associations.
This is exposed-training validation, not reserved evaluation or noise robustness.
The reader independently recomputes centroids, predictions and all three scores.

The [feedback case contract](../sdk/adaptation_provider/retrieval/feedback_contract_v1.json)
binds the unchanged fitting algorithm to baseline, immediate vertical feedback
and immediate phase release. All 24 immediate-role episodes remain in its
ledger: **15 eligible and nine negative**. Only eligible episodes supply cases,
producing **720 thirty-command windows**. All eight delayed episodes, including
four failures, remain in the full source ledger but are excluded from this fit
because their action sequence combines a baseline prefix and a different
controller. The failed weakened 0.006 m/s start remains represented and uncovered.

A declared whole-episode rule ranks only controllers eligible at every training
start within a condition, then uses mean tracking quality and an action-index
tie break. Nominal baseline ranks first; no weakened controller qualifies.
These are fitted options, not privileged runtime condition labels or a live
action selector. The frozen model is
`sha256:4f80591a7964c50a13f11fb4e92115f0d223c4f169071900efce18d69fe55c7f`.
It changes neither base weights nor the consumed retrieval contracts.

Ten component controls pass in 51.432 s under
`sdk2-first-response-controls-cd45f6ecbb7346708efe82845ff16b4b`; original stderr
SHA-256 is `a40f013e27cfb1c822f2939c60a4359efc4a59a58ea9ddaa94cb43aca99c3462`.
The fitting attempt retains thirteen artifacts, including exact tested sources,
original streams, declaration, source/runtime bindings and fitted result.
Four closure controls pass in 40.088 s under
`sdk2-first-response-closure-controls-7fd386e316a84e24be6e1dbe9d39512c`; stderr
SHA-256 is `e25fec6127e51eb321954420497d3ffda25b2fc6e43e3f81e469b768ef3d4e94`.
They rebuild the complete fit, refuse crossed source bytes, labels, cases,
fold identities, scores and expanded authority, and block world constructors
and stepping. Closure SHA-256 is
`dcd829f123b0ec15aa383049ebed5ba2b8d1bc0fc3854109b880d2435f6aefec`.

Next connect a distinct provider to these immutable context/case artifacts:
infer context from actual history, evaluate current phase/contact support,
retain bounded resolver outputs and explicit fallback, and keep private,
versioned memory. A fresh comparison must retain both motor conditions, all
four starts and the full twelve-second horizon, with baseline, disabled,
frozen-selector and shuffled-association controls. Influence opportunity and
actual application must be reported separately. No new native comparison is
authorized by this fitting closure. The empirical withdrawal monitor, reserved
evaluation, healthy-body preservation and three-engine promotion remain open.
Useful Tier 3 adaptation still requires a separate memory-on/off/shuffled test.
SDK1 remains 20/20; full-program readiness remains 19/25, and Tier 2/Tier 3
qualification and release claims remain false.

### Completed phase-release comparison - 2026-10-23

The [closure](../sdk/discovery/cpu_phase_release_closure_v1.json),
[executable reader](../sdk/discovery/audit_cpu_phase_release_closure.py) and
[eight controls](../sdk/discovery/test_cpu_phase_release_closure.py) retain the
complete prospective population. Published freeze `e5589f8b` passed all **287
zero-world controls** again before any physical construction. The fresh attempt
`sdk2-cpu-phase-release-ad8e0e7c7f074f5f95415ae68598d453` then completed **32 CPU
worlds**, with zero GPU, calibration or evaluation worlds. Each trial retained
all 1,440 decisions and 7,200 internal samples over twelve simulated seconds.
Independent replay with the separate baseline core verified **46,080 decisions
and 230,400 samples**, plus native inputs, phase proposals, resolver outputs,
timing, actual history receipts and all eight condition/start groups.

| Role | Weakened motors | Nominal motors | Nominal quality preserved at every start |
| --- | ---: | ---: | --- |
| Baseline | 0/4 | 4/4 | Yes, identical reference |
| Vertical reference, immediate | 1/4 | 4/4 | No |
| Phase release, immediate | 2/4 | 4/4 | No |
| Phase release, after 16 commands | 0/4 | 4/4 | No |

There are **19 eligible episodes and 13 physical negatives**. The vertical
reference succeeds at the 0.001 m/s weakened start. Immediate phase release
fails there but succeeds at 0.003 and 0.004 m/s, traveling 1.178274 and 1.176264 m
forward respectively. Every tested role fails the 0.006 m/s weakened start.
The union of these exposed successes covers three of four weakened starts;
this is an observation about retained trials, not a qualified portfolio or
learned selection result. All thirteen negatives first violate tilt, and their
quality remains censored. The delayed role supplies no successful weakened
action for the existing sixteen-command context estimate.

All sixteen nominal episodes pass physical eligibility. Nevertheless every
corrected role has a lower tracking-quality score than its fresh nominal
baseline at every start. For immediate phase release, the differences range
from -0.004269788 to -0.003217977 m/s in the declared score. All **forty** planned
contrasts are retained: twenty nominal contrasts have two eligible endpoints;
all twenty weakened contrasts retain censored quality differences. No role
satisfies all-eight eligibility and the zero-observed-loss nominal screen, so
the prospective ranked shortlist is empty. This does not estimate a population
non-inferiority margin or decide the performance of a future conditional policy.

The closure binds **14,636 artifacts / 4,878,019,860 bytes**, 470 frozen source
files and 1,359 runtime files. Native execution took 410.037441 s; independent
audit took 411.358642 s. Receipt SHA-256 is
`e90fd34733b950bf0f626f500e2f8d64414f0f84aa25ebbbb384a8d5eb05dd64`,
audit SHA-256 is
`24ede3147d9f15f937601bda4a89862c986ec43860c7c4037e66a44e8a30aa09`,
and closure SHA-256 is
`df78a08932a8d3ba262190c3ce8c55ba07bced79979985cb9fa17c4dd586983b`.
All eight closure controls pass at
`sdk2-phase-release-closure-controls-268d29fd84404a8995657d03947b58d2`, with zero
new worlds. They verify the complete inventory and outcome denominator and
reject changed dependencies, erased failures, invented winners, altered
healthy-body comparisons, false history and crossed native models. The
preparation failure and its corrected zero-world gate below remain retained.

Next retain both immediate behaviors as development leads for a distinct
repertoire and early-selection successor. The uncovered 0.006 m/s start,
failure after a sixteen-command delay, and healthy-body score loss are explicit
requirements, not exclusions. Use retained causal responses to investigate
earlier condition information and a control transition that leaves the nominal
baseline useful, then prospectively test any resulting policy across the full
declared population. Verified training data can support development fitting;
this result itself selects no controller and establishes no learned choice,
memory benefit, qualification or release authority. Reserved groups remain
unopened.

### Prepared phase-release comparison - 2026-10-23

This is the prospective preparation retained at `e5589f8b`; the execution and
closure above now supersede its pending-work status without changing its rules.

The [provider](../sdk/adaptation_provider/phase_release_feedback_v1.py),
[host](../sdk/discovery/phase_release_control.py),
[declaration](../sdk/discovery/cpu_phase_release_v1.json),
[native route](../sdk/discovery/cpu_phase_release.py) and
[independent reader](../sdk/discovery/audit_cpu_phase_release.py) implement a
distinct successor to the complete phase/contact diagnosis. No previous
campaign, threshold, source pin or interpretation changes.

The parent remains the support-vertical controller. The new candidate uses
the actual current `controller_context.controller_memory` for the unchanged
360-command wave and 72-command swing. It first bounds the parent's proposed
joint correction to +/-3.5 rad/s, then applies weight
`min(1, (360 - local_phase_step) / 44)` during stance and zero during swing.
The 44-command release interval is `ceil(3.5 / 0.08)`, derived from the existing
correction and per-command slew limits. The public resolver still applies
correction, slew and final-speed limits. The provider changes neither the gait
clock nor the baseline. Unsupported phase context withdraws the proposal.

The full-cycle controls verify release through adversarial raw sign changes,
actual phase/receipt joins, 172 partial-release leg observations and 288
scheduled-swing observations. Both frozen cores agree across 1,440 real-ABI
controller decisions, and the unchanged parent's target bits are preserved.
The independent reader separately computes phase weights, bounds and proposals
from the original parent equations; it rejects altered weights or commands.
No counterfactual trajectory or physical success follows from these controls.

| Role | Candidate | Influence begins | Truthful baseline history |
| --- | --- | ---: | ---: |
| Baseline | 0 | None | 16 commands |
| Vertical reference | 3 | Command 0 | None |
| Immediate phase release | 4 | Command 0 | None |
| Delayed phase release | 4 | Command 16 | 16 commands |

Each role runs at all four training starts (0.001, 0.003, 0.004 and 0.006 m/s
initial lateral velocity), under both left-side 75-percent motors and nominal
motors. The declaration fixes **32 fresh sequential CPU worlds**, seed
104232600, 1,440 commands and five substeps per command: **46,080 decisions and
230,400 internal samples**, with complete original streams. All forty planned
paired contrasts remain visible; failed-episode quality stays censored. Prior
confirmation and reserved calibration/evaluation starts are excluded.

Eligibility remains minimum torso height 0.25 m, maximum tilt 0.6 rad, zero
torso contacts and zero safe-no-actuation commands over the full twelve seconds.
To enter the fixed-controller shortlist, a role must pass all eight episodes
and show **zero observed nominal tracking-quality loss against the fresh
baseline at each start**. Both endpoints must be eligible with measured
quality; missing or failed nominal baselines cannot establish preservation.
Rank only eligible, preserving roles by mean whole-episode tracking quality,
then role index. This is a finite development screening rule, not a population
non-inferiority margin or a claim about future context-selected behavior.

The first focused controls at
`sdk2-phase-release-controls-7172ce5f7ef244f5affc565d347fa8c4` retained one route
test failure: its expectation accidentally counted 32 history features,
where the unchanged feature schema has 16. The expectation was corrected;
the failed logs and tested source remain. A fixture input stream was also
closed explicitly. No physical world was involved.

The [supervisor](../sdk/discovery/run_cpu_phase_release.py) then passed all
**287 controls** at `sdk2-cpu-phase-release-0928389ea10849c3acf76fc0c247e001`:
470 source and 1,359 runtime bindings remained unchanged, preflight opened zero
worlds, and physical execution remained false. The receipt SHA-256 is
`694468d60665afa31aa244393f21a9763f06f934b7ed10bcac93242206c5bf1b`.
Its new phase/contact, provider, host and route stages passed 8, 10, 8 and 11
controls in 40.561, 13.830, 4.163 and 12.284 seconds respectively. Exact copies
of all twelve new files and their bindings are retained in
`sdk2-phase-release-preparation-a00e7507727640a4879ea9386587c5a5`.

Next use a clean pushed prospective freeze, repeat the complete gate and run
this declared population under the operation mutex and Windows containment.
Releasing a correction may improve swing coordination or remove useful support;
it cannot alone establish reachable touchdown. The physical comparison must
decide its usefulness. Training/selection authority requires complete execution
and independent closure; learned choice, Tier 3 benefit, qualification and
release remain unproved.

### Completed phase/contact and command-response diagnosis - 2026-10-23

The [record](../sdk/discovery/phase_contact_diagnostic_v1.json),
[executable reader](../sdk/discovery/phase_contact_diagnostic.py) and
[eight controls](../sdk/discovery/test_phase_contact_diagnostic.py) cover the
same first **96 commands (0.8 s) from all sixteen** support-vertical trials.
This interval was chosen after observing outcomes and ends before the earliest
violation at 0.945 s. It contains **1,536 controller decisions, 7,680 completed
internal samples, 6,144 leg evaluations and 12,288 joint command/response
pairs**. No role or start is excluded; the original 2 positives, 14 negatives,
censored contrasts and empty shortlist remain unchanged. Zero worlds were
built and zero solver steps executed.

Phase is joined to the actual actuation receipt, output memory and provider
`controller_context.controller_memory`. The existing v1 input therefore
already exposes the phase needed by a successor; elapsed time need not stand
in for actual controller state. The frozen wave has 360 commands per cycle,
72 swing commands and the ordered offsets rear-left, front-left, rear-right,
front-right. Scheduled stance is intent, not measured support.

Each command's response uses the measured joint velocity **after its five
held-control substeps**. The prepared observation remains the before-command
measurement. Canonical/native signs, commands, phase, raw feedback and original
artifact hashes are checked. Foot-velocity projections use the start-of-command
Jacobian, including the projected end velocity; these are fixed-configuration
projections, not measured world foot velocities. Joint-response error is not
the campaign's tracking-quality score. Contact loads are unavailable; actuator
force-cap counts are not ground-reaction forces.

| Scheduled phase / observed support | Leg observations | Floor beyond geometric reach at that torso pose | Nonzero applied residual without support |
| --- | ---: | ---: | ---: |
| Stance / support | 3,028 | 0 | 0 |
| Stance / missing | 1,868 | 1,442 | 110 |
| Swing / support | 127 | 0 | 0 |
| Swing / missing | 1,121 | 34 | 113 |

The front-right foot contributes **1,462/1,868** missing-stance observations:
91 or 92 of its 96 scheduled-stance commands per trial, with uninterrupted
gaps of 89 or 90 commands. This also occurs in both positive trials. A leg
extension alone cannot reach the floor at a geometrically unreachable torso
pose; that geometric result does not prove which body/control change will
succeed.

The resolver retains nonzero corrections through **223/2,989** observations
without support as it slews toward the requested zero. Eleven joint commands
have opposing raw/applied correction signs. Across all 12,288 joint commands,
1,622 absolute, 2,587 slew and 72 final-speed clamp labels are present; labels
can overlap. There are 3,781 force-cap samples out of 61,440 internal joint
samples. Per-trial end-response RMS ranges from 0.30765 to 0.39691 rad/s.
These interactions occur across successful and unsuccessful trials and are
not causal findings or a post-hoc ranking rule. Scheduled load-transfer
influence is inactive throughout this prefix, with its original available
and unavailable planning outcomes retained.

Generation is retained at
`sdk2-phase-contact-generation-a824b7c019724b2589488c14764a715c`.
The eight controls passed in **37.190 s** at
`sdk2-phase-contact-controls-6c5feeebeae64eaa87f59695bfbf3a1b`, with exact tested
source/record copies and bindings. They verify the complete parent, original
files and all diagnostic values; reject phase/response timing substitutions,
missing trials, crossed failure boundaries, invented loads and promoted
authority; and test wrap boundaries and zero-denominator groups. The maximum
native endpoint versus independent geometry discrepancy is
7.077671781985373e-16 m.

Next declare a **phase-aware residual-release successor** using actual v1
controller context. A concrete candidate can taper a bounded stance residual
before scheduled liftoff and request zero during swing while retaining the
same public correction/slew/speed resolver. Any taper duration must follow
the declared bound and slew budget, and its components must be tested before
fresh worlds. This may avoid opposing intended swing, but can remove useful
attitude support from a foot that stays in contact; it also cannot by itself
solve unreachable touchdown poses. Compare against the parent across every
declared training start and include healthy-body preservation. Retain full
horizons, failures and all denominators before any learned action mapping.
Calibration/evaluation and prior confirmation stay excluded. The present
diagnostic grants no new training, selection, causal, qualification or
release authority.

### Completed support-vertical comparison - 2026-10-23

The [closure](../sdk/discovery/cpu_support_vertical_closure_v1.json) and
[executable verifier](../sdk/discovery/audit_cpu_support_vertical_closure.py)
retain the complete attempt
`sdk2-cpu-support-vertical-50c80cec5ebe4ac8beb2d8dcc5f40b8e` at clean pushed
source `cdc77febb454528284eb8ce561d9693012e89cee`. All **250 applicable controls**
and the zero-world preflight passed again before the sixteen fresh native CPU
worlds. Independent replay verifies every one of **23,040 controller decisions**
and **115,200 internal samples**. Execution is valid; the finite controller
family does not meet its selection rule.

| Role | Eligible starts | Negative starts | Four-start selection |
|---|---|---|---|
| Baseline | 0/4 | 4/4 | Ineligible |
| Current height, immediate | 1/4 | 3/4 | Ineligible |
| Opposing-vertical successor, immediate | 1/4 | 3/4 | Ineligible |
| Same successor after sixteen commands | 0/4 | 4/4 | Ineligible |

Both positives occur at the 0.001 m/s start and remain eligible for the full
twelve seconds, each with 48 quality windows and no torso contact or
safe-no-actuation step. Current height advances **1.2160593 m**, with minimum
height 0.4097502 m, maximum tilt 0.2637508 rad and quality -0.125242727 m/s.
The immediate successor advances **1.1711269 m**, with minimum height 0.4032100 m,
maximum tilt 0.2575302 rad and quality -0.116387114 m/s. Their declared paired
tracking-score difference is **+0.008855613 m/s**. This is a combined tracking
score, not an increase in forward speed. All other nineteen contrasts remain
censored because at least one endpoint is negative. The four-start shortlist
and selected role remain empty.

| Start (m/s) | Baseline first tilt (s) | Height immediate (s) | Successor immediate (s) | Successor after sixteen (s) |
|---|---|---|---|---|
| 0.001 | 1.063333 | None | None | 1.390000 |
| 0.003 | 1.151667 | 2.110000 | 2.083333 | 2.063333 |
| 0.004 | 1.163333 | 2.421667 | 2.215000 | 2.098333 |
| 0.006 | 0.945000 | 1.355000 | 1.403333 | 1.060000 |

Every negative also records torso contact later in the episode; baseline at
0.001 and 0.006 additionally violates minimum height. The successor's feedback
is supported before every first violation after its declared onset. Four
baseline/delayed prefix groups retain genuine sixteen-command histories, while
both immediate roles retain no claimed baseline prefix. Thus this experiment
retains a local score improvement but no broader eligibility, learned choice,
nominal-preservation, memory-benefit, non-inferiority or release result.

The closure binds **11,725 artifacts / 2,617,732,655 bytes**, 452 frozen source
files and 1,359 runtime files. Native execution took 248.094048 s and independent
replay 196.200493 s. All **seven closure controls** passed in 261.979 s in
`sdk2-support-vertical-closure-controls-76d9430d9493484cb553fc0780edf47c`.
They reject altered population/authority, omitted or duplicate artifacts,
invented winners, erased failures, changed positive or censored scores, false
causal history, crossed model profiles and changed source/runtime/reader pins.
The original closure generation is
`sdk2-support-vertical-closure-generation-324af96a042b410b890e46f66d701c45`.
No new physics is used by generation or closure controls.

The [completed diagnosis above](#completed-phasecontact-and-command-response-diagnosis---2026-10-23)
uses the proposed **post-hoc common first 96 commands (0.8 s)** from all sixteen
retained trials to examine actual gait phase, expected versus observed contact, joint
command versus measured response, and clamp effects. That interval precedes the
earliest retained violation at 0.945 s and keeps every role/start in the
comparison. Rejoin phase to the actual controller receipt/memory and contacts
to their recorded observation stage; do not invent unavailable contact loads.
This diagnosis proves no cause and does not retroactively choose a
controller. Use its findings to declare a distinct coordination/control
successor, then require fresh full-horizon and healthy-body checks before
mapping the context estimator to actions. Calibration/evaluation and prior
confirmation stay excluded. A single favorable score cannot replace the
failed family-selection rule.

### Prepared support-vertical comparison - 2026-10-23

The [provider](../sdk/adaptation_provider/support_vertical_feedback_v1.py),
[host](../sdk/discovery/support_vertical_control.py),
[declaration](../sdk/discovery/cpu_support_vertical_v1.json),
[native route](../sdk/discovery/cpu_support_vertical.py) and
[independent reader](../sdk/discovery/audit_cpu_support_vertical.py) implement the
composition hypothesis below. For a leg whose current observation has both
presence and support, compute `J b` from the actual canonical baseline command.
Only when its vertical component opposes the combined attitude/height request,
add the existing damped inverse of `[0, -(J b)_y]` to the unchanged feedback.
All other cases add zero. The existing resolver owns absolute correction, slew
and final speed limits. No force controller, direct world write, learned action
selection or future outcome input is introduced. Damping and clamps can couple
horizontal motion; this is not a promise to preserve the gait trajectory.

The S169 body, `left_075` actuator profile, ground domain, attitude/posture/height
objectives and correction/slew/speed bounds remain fixed. Seed `104232500`
identifies four fresh roles at each exposed lateral start, 0.001, 0.003, 0.004
and 0.006 m/s:

| Role | Candidate | First possible influence | Baseline-only history |
|---|---|---|---|
| Baseline | Existing baseline | None | Sixteen commands |
| Height immediate | Unchanged current height feedback | Command zero | None |
| Vertical immediate | Opposing-vertical successor | Command zero | None |
| Vertical after sixteen | Same successor | Command sixteen | Sixteen commands |

The complete population is **16 CPU worlds, 23,040 controller decisions and
115,200 internal samples**, with twelve seconds per world. Baseline and delayed
roles must share the actual initial baseline history; neither immediate role may
claim that history. All four starts must remain eligible before a role can rank
by mean whole-episode tracking quality, with role index as tie-break. Twenty
prospective paired contrasts retain failed endpoints and censored quality.
The unchanged eligibility limits are 0.25 m minimum height, 0.6 rad maximum tilt,
zero torso contact and zero safe-no-actuation steps. Prior confirmation starts
0.002 and 0.005 remain excluded from fitting; reserved calibration and evaluation
starts remain unopened. Nominal preservation and learned choice are not covered.

All **26 focused controls** passed in
`sdk2-support-vertical-controls-d70010b83704461381babc65dcfeaa80`:
eight mathematical/real-interface controls in 8.494 s, eight host controls in
2.545 s and ten full-route controls in 7.885 s. On 480 retained-input decisions,
two independent cores agree exactly, the height reference retains its target
bits, and 374 supporting-leg observations exercise compensation. These are
zero-world component checks, not native benefit evidence. Exact tested source
and original logs remain retained.

The [supervisor](../sdk/discovery/run_cpu_support_vertical.py) then passed all
**250 controls**, containment and zero-world preflight in
`sdk2-cpu-support-vertical-32b5487edae44d6482ff9a6781a448f3`.
Source/runtime bindings were unchanged. It retains the operation mutex, fresh
attempt identity, contained children, single-use population, full original
streams and independent replay. Physical execution requires a clean pushed
prospective freeze and a fresh complete gate. No native attempt has begun at
this preparation boundary; no useful adaptation or release claim is earned.

### Completed height composition diagnosis - 2026-10-23

The [executable reader](../sdk/discovery/height_composition_diagnostic.py) and
[retained result](../sdk/discovery/height_composition_diagnostic_v1.json) first
verify the complete matched-activation closure, including all twelve original
outcomes. They then analyze the same first 120 commands from all four immediate
height trials. The interval was chosen after seeing the outcomes and is labeled
post-hoc. All 480 decisions, 2,400 completed internal samples and 1,920 leg
evaluations precede each trial's first physical violation. No new world, fit,
selection, counterfactual outcome or quality promotion is produced.

The reader recomputes the exact height-feedback receipt, verifies foot geometry
against native distal-body poses and projects joint velocities into torso-frame
foot-center x/y motion. It distinguishes the baseline, raw feedback, unclamped
sum, final bounded command and observed instantaneous joint velocity. The
body-motion request contains attitude and height feedback, but excludes the
baseline gait objective. Its discrepancy must not be called the campaign's
walking-quality score or evidence that the baseline is universally incorrect.

| Start (m/s) | Baseline opposes requested vertical / supported observations | Mean vertical discrepancy, raw feedback (m/s) | After adding baseline (m/s) | After bounds (m/s) |
|---|---|---|---|---|
| 0.001, positive | 187/250 | 0.062217 | 0.104129 | 0.114475 |
| 0.003, negative | 186/249 | 0.064210 | 0.106054 | 0.114497 |
| 0.004, negative | 187/248 | 0.063576 | 0.106209 | 0.115585 |
| 0.006, negative | 184/247 | 0.068204 | 0.110278 | 0.116587 |

These are fixed-state kinematic descriptions, including **744/994 opposing
vertical observations**. The actual body and contacts still evolve dynamically.
The positive and negative trials all show the interaction, so it does not
explain their different outcomes. At the retained fixed torso poses, the
front-right distal capsule cannot reach the floor in 113, 113, 111 and 112 of
the 120 respective poses; this again occurs in the positive. Normal contact forces were not retained.
Actuator torque and force-cap samples remain explicitly separate from ground
reaction forces. Maximum native/FK endpoint discrepancy is 7.21645e-16 m.

All **seven diagnostic controls** passed in 69.920 s in
`sdk2-height-composition-controls-2e46d31a269745ecad477610004d4cf1`.
The independent finite-difference oracle checks 144 joint-velocity cases, with
maximum discrepancy 2.63227e-10 m/s. Other controls reject changed native poses,
feedback/proposal joins, invented contact loads, reordered samples, omitted
trials, a prefix crossing failure, altered authority/metrics and source bindings.
The parent closure and every original outcome remain intact. The original
generation is `sdk2-height-composition-generation-dc375af76bfd430e9f01b3aff4e61259`;
exact tested source, result and original logs are retained in both attempts.

Next prepare a distinct **support-only opposing-vertical compensation** test.
For a currently supported leg, compute the baseline foot velocity `J b` from
the real baseline joint command. If its y component opposes the combined
attitude/height request, add the existing damped inverse of `[0, -(J b)_y]` to
the unchanged feedback proposal. Otherwise add zero. This is a local design
hypothesis, not an adopted controller or a result of the current diagnostic.
It targets vertical opposition without intentionally replacing the forward gait
objective; damping and resolver clamps can still couple both coordinates.
Keep the existing correction, slew, speed, domain and withdrawal limits.

The new declaration must compare fresh baseline and current-height roles with
immediate and sixteen-command-delayed successor roles at all four exposed
training starts. Require complete twelve-second eligibility before selection.
Analytic projection, exact reference/fallback commands, causal history, full
route replay and the complete applicable safety gate must pass before a clean
pushed freeze can open those worlds. Calibration/evaluation and prior
confirmation stay excluded. A failed family remains a failed family; neither
this diagnostic nor a better local projection grants adaptation benefit.

### Completed matched height activation - 2026-10-23

The [closure](../sdk/discovery/cpu_height_activation_closure_v1.json) retains
`sdk2-cpu-height-activation-79ebfb867748407098b71385a959f5d7`, executed from clean
published `e6969e3c4e24a091494c80c30d49fd0194a3f0e7`. All **217 controls** passed
again before twelve fresh CPU worlds. Complete independent replay verified
**17,280 controller decisions and 86,400 internal samples**, with 434 source
and 1,359 runtime bindings. Zero GPU, calibration or evaluation worlds opened.

| Role | Eligible / total | Four-start eligible | Selected |
|---|---|---|---|
| Baseline | 0/4 | No | No |
| Immediate height | 1/4 | No | No |
| Height after sixteen baseline commands | 0/4 | No | No |

The complete population is **1/12 eligible and 11/12 negative**. The sole
positive is immediate height at the 0.001 m/s start: 1.2160593213 m forward
travel, minimum height 0.4097502398 m, maximum tilt 0.2637508051 rad and zero
torso-contact or safe-no-actuation samples. Its 48 eligible windows yield
whole-episode tracking quality -0.1252427266 m/s. This is a finite development
positive; the other three immediate-height starts fail.

Every negative reaches the tilt limit and later records torso contact. All
negative qualities remain censored. The original four-start eligibility rule
leaves an empty shortlist, and every one of the twelve declared paired quality
differences is null because no pair contains two eligible episodes. No winner
is invented from the single positive or from partial pre-failure windows.

The four matched groups each contain two bit-identical sixteen-command
baseline prefixes and equal causal features. Immediate-height histories never
claim to be baseline-only. At the 0.001 m/s start immediate feedback passes
while delayed feedback fails; this is a finite matched onset result. Immediate
feedback also fails at 0.003, 0.004 and 0.006 m/s, so removing observation delay
alone does not solve the available controller's coverage. Earlier confirmation
at 0.002 and 0.005 m/s remains valid within its own population and cannot be
used to erase these training failures or fit the next controller.

Feedback is active before the failed height trials cross the tilt threshold;
they do not begin by immediately withdrawing. Original receipts retain requested
corrections, support observations and the resolver's absolute, slew and final
speed clamps. These descriptions do not establish which mechanism causes the
falls. Next compare retained support geometry, requested motion, bounded
commands and observed response over a common pre-failure interval. Any resulting
controller change needs a distinct declaration and fresh worlds. Do not attach
the 8/8 internal label estimator to an unavailable four-start action choice.

The [closure reader](../sdk/discovery/audit_cpu_height_activation_closure.py)
checks all **10,246 artifacts / 2,081,442,262 bytes**, frozen source/runtime
bindings, actual controller receipts, native outcomes, quality censoring, causal
prefixes, role eligibility and all paired contrasts. Native execution took
151.923744 s and independent replay 141.463824 s. The original receipt and
audit digests are respectively
`bd82cc87a05bc2849e77972948ebe35a31b91773f78bff1f1a50d1742f0a89b6`
and `4ea8014b7fd54223b298d3fd5e33cd4c44c3eaef4e0113e3ba74b14f4c1ddb4c`.

All **seven closure controls** passed in 158.839 s in
`sdk2-height-activation-closure-controls-3ce72ac66b374717bc75e93acf866d90`.
They reject erased failures, invented winners, altered causal values, crossed
model profiles, censored-quality changes and source/runtime/proof mutations.
Exact tested sources and logs are retained; zero worlds were constructed by
these checks. This closure grants finite development training and selection
scope with an empty selected set. It establishes no learned adaptation benefit,
Tier 3 memory benefit, population inference, non-inferiority, engine equivalence,
qualification or release authority. The consumed physical identity must not rerun.

### Matched height activation prepared - 2026-10-23

The [new declaration](../sdk/discovery/cpu_height_activation_v1.json) separates
activation timing from the start changes in the failed 64-command repertoire.
It keeps the exact S169 model, left-side 75-percent actuator profile, unchanged
height equations, clamps, initial values and twelve-second horizon. It uses the
four exposed training lateral velocities 0.001, 0.003, 0.004 and 0.006 m/s, with
one development seed `104232400`. Every role receives a fresh world and private
controller memory; no retained physical baseline is reused.

| Role | First possible height influence | Baseline-only history retained |
|---|---|---|
| Baseline | Never | Sixteen commands, then retired |
| Immediate height | Command 0 | None; its feedback history is not relabeled |
| Early height | Command 16, after 0.133333 s | Sixteen actual baseline commands |

The [new host](../sdk/discovery/height_activation_control.py) preserves the
existing height controller's exact numeric commands for immediate activation.
Baseline and delayed roles produce bit-identical baseline prefixes and measure
the same sixteen causal response features at command 16. The immediate role
never claims those baseline features. All roles retain the real resolver's
clamp, slew and refusal behavior. No classifier selects actions in this campaign.

Twelve fresh CPU worlds are planned: four starts times three roles, totaling
17,280 controller decisions and 86,400 internal samples. Each role must pass all
four full horizons before ranking by mean whole-episode tracking quality, with
role-index ties. Twelve fixed paired contrasts cover immediate minus baseline,
early minus baseline and early minus immediate at each start. Quality differences
are reported only when both episodes have uncensored quality; failures remain
in the denominator. This finite development comparison grants no statistical
superiority or non-inferiority claim.

All **217 controls** passed in
`sdk2-cpu-height-activation-cdc8ac9ede204502b222bed971318afb`, binding 434 source
and 1,359 runtime files. The eight host controls and ten route controls passed
separately in 2.438 s and 7.389 s in
`sdk2-height-activation-controls-ce8c359e7a46468c857ce36b1d39efed`. Their exact
tested sources and original logs remain retained. Coverage includes unchanged
immediate commands, truthful history, exact first influence and fresh slew,
unsupported-state withdrawal, close-on-partial-failure, full transition replay,
model/force/state corruption, matched contrasts and complete population/splits.
No failed preparation attempt or native world occurred at this checkpoint.

The [contained supervisor](../sdk/discovery/run_cpu_height_activation.py) holds
the existing operation mutex, enforces native child containment and checks the
complete source/runtime binding before and after execution. It must rerun the
full applicable gate from a clean pushed freeze before opening worlds. The
[independent reader](../sdk/discovery/audit_cpu_height_activation.py) replays
every controller decision and joins native state, force, contact, timing and
baseline-prefix evidence before assigning any development training authority.

Next run and close this exact campaign. If early activation is useful across
all four starts, freeze the inferred context-to-action mapping and challenge
learned, condition-known, baseline, disabled and association controls on fresh
groups. Nominal preservation, reserved calibration/evaluation, memory benefit,
broader morphology and engine transfer remain separate later questions.
Earlier confirmation is still excluded from fitting. The previous negative
64-command repertoire and the limited 8/8 context diagnostic retain their
original identities and claim limits.

### Completed early-context feasibility - 2026-10-23

The [fixed 16-command diagnostic](../sdk/discovery/early_context_feasibility_v1.json)
uses only authorized training histories from the closed 24-world repertoire.
Its shorter window was fixed before this analysis at one quarter of the prior
64-command prefix; there was no window or feature sweep. It is retrospective
development fitting, not fresh calibration or evaluation. The extractor joins
actual issued baseline commands, canonical observations and seventeen position
samples into sixteen per-joint mean/RMS response features at 0.133333 s.
All three fresh role prefixes match within each of eight training groups.
Labels, model identities, actuator-force metadata and future outcomes do not
enter feature values. All twelve failed source trials remain accounted for.

The [estimator](../sdk/discovery/early_context_v1.py) uses unscaled nearest
centroids in the common rad/s units. Each validation fold excludes both body
conditions at one initial lateral velocity, fits six groups and classifies two.
This prevents the three repeated prefixes or the other condition at the same
start from entering the fold's fitting data. No confidence threshold is fitted;
exact distance ties are ambiguous. The final model fits all eight training
groups and is retained for future development, with **no action mapping and
no control authority**.

| Internal training check | Correct groups | Physical control tested |
|---|---|---|
| Leave one training start out, both conditions blocked | 8/8 | No |
| Constant nominal prediction | 4/8 | No |
| Synthetic reversal of condition associations | 0/8 | No |

Correct-class squared distances range from 0.002615 to 0.041416; opposite-class
distances range from 0.585567 to 0.789162. These distances are descriptive,
not calibrated confidence or an acceptance threshold. The two exposed actuator
profiles, one morphology and four closely spaced training starts are a narrow
population. Neither internal fold accuracy nor the full-training fit establishes
reserved performance, recognition of unknown conditions, useful control or
population generalization. The 64-command degraded shortlist remains empty.

Seven component controls passed in 38.564 s in
`sdk2-early-context-controls-7d6e0f9e814b4736ba4da8b73cb07fed`. They test analytic
joint motion, actual actions and the endpoint, chronology and unsupported
history refusals, metadata leakage, grouped fitting, split contamination,
ambiguous predictions and an exact native-data rejoin. The [closure](../sdk/discovery/early_context_feasibility_closure_v1.json)
retains the complete fitted models and per-fold predictions, nine diagnostic
artifacts, exact tested sources and the parent closure. Its [reader](../sdk/discovery/audit_early_context_feasibility.py)
rechecks all 9,181 parent artifacts and regenerates the full training analysis.
All three closure controls pass in 39.054 s in
`sdk2-early-context-closure-controls-c90af070a6d648d59c2dda777f10c674`, including
missing source inventory, altered labels/centroids, changed proofs and unearned
control authority. Earlier passing closure controls remain retained in
`sdk2-early-context-closure-controls-f53acc21dd334db3a05d3558f5542607`; the final
reader adds an explicit complete-tested-source inventory requirement.
All analysis and verification construct **zero new worlds**.

The next bounded native question is a **new matched activation comparison**:
fresh baseline, height feedback from command zero, and height feedback after
sixteen actual baseline commands, at each of the four exposed degraded-body
training starts. That is twelve proposed fresh CPU worlds at the existing
twelve-second horizon. The prospective declaration, production-route controls,
full applicable safety gate and clean pushed freeze must precede launch; this
paragraph is not an executable campaign or a result. Retain all failures and
require all four starts for any eligible controller choice. Nominal condition,
learned-choice challenge, reserved calibration/evaluation and memory-benefit
comparisons remain later distinct questions. If sixteen-command activation
works, freeze its action mapping and challenge the inferred choice against
condition-known, baseline, disabled and association controls on fresh groups.

### Completed causal-prefix repertoire - 2026-10-23

The [training declaration](../sdk/discovery/cpu_context_repertoire_v1.json)
completed from published `e15bd02b` after all **192 controls** passed again.
Attempt `sdk2-cpu-context-repertoire-9bdf4639cc51410cb2739ba07a55bc74` constructed
24 fresh CPU worlds, with zero GPU, calibration or evaluation worlds. Complete
independent replay verified **34,560 decisions and 172,800 internal samples**.
Each world ran twelve seconds; its first 64 commands used actual `no_proposal`
responses and exact baseline commands. The result is **12/24 eligible and
12/24 negative** across all four new training starts on each condition.

| Condition | Baseline eligible | Reference eligible | Height eligible | Declared selection |
|---|---|---|---|---|
| Left-side effectiveness 75 percent | 0/4 | 0/4 | 0/4 | Empty shortlist |
| Nominal actuator profile | 4/4 | 4/4 | 4/4 | Baseline, index 0 |

All twelve degraded trials first violate tilt between 0.941667 and 1.163333 s;
their quality remains censored. Height feedback was active before failure, with
49-75 supported feedback decisions before the first violation, but no candidate
passes even one degraded training start. Nominal mean whole-episode tracking
qualities are -0.0994551, -0.1008696 and -0.1323308 m/s for baseline, reference
and height respectively; higher is better. All nominal trials have 48 complete
scoring windows. The degraded shortlist stays empty under the unchanged
four-start rule; a best failed trial is not a selected controller.

All three fresh roles within each of eight groups have bit-identical causal
inputs and sixteen joint-response features at command 64. Those repeated
prefixes are one training example per group. The complete verified corpus,
including failures, earns finite development fitting and controller-selection
authority. It does not provide a useful degraded action mapping at this delayed
selection point. No model has been fitted and no learned choice has run.

The earlier immediate-height confirmation remains valid on its own starts.
Both activation timing and initial velocities changed here, so this result
does **not** isolate delay as the cause or refute history-based adaptation.
Next resolve earlier observation and initial control in a distinct successor,
using authorized training histories for feasibility work while leaving earlier
confirmation and reserved calibration/evaluation outside fitting. A continuously
updating selector also needs coverage of histories produced by its own choices.

The [closure record](../sdk/discovery/cpu_context_repertoire_closure_v1.json)
and [verifier](../sdk/discovery/audit_cpu_context_repertoire_closure.py) bind
**9,181 artifacts / 4,075,817,332 bytes**, 415 frozen sources and 1,359 runtime
files. Native execution took 441.484 s; independent replay took 424.154 s.
All **seven closure controls** passed in 306.639 s in
`sdk2-context-repertoire-closure-controls-9ba9a8d1a8ac419ca4a01ae98f23b7f1`.
They reject invented winners, removed failures, changed causal inputs and
receipt bindings, crossed condition models, altered runtime/source identities,
and changed quality or authority. Their exact tested sources and logs remain
retained. Verification constructs no new worlds.

An earlier closure-development attempt,
`sdk2-context-repertoire-closure-generation-f81158127fa74a9d8dfa800458eb0ec4`,
failed with `Outcome denominator`: a copied verifier constant still expected
three negatives. Its exact source and original failure log are retained. The
new verifier was corrected to twelve negatives; original native data, receipt,
audit and interpretation were unchanged. The corrected complete verification
passed in `sdk2-context-repertoire-closure-generation-cb15ccab14c54b01a2aa0ff4a9ce1712`.

No learned-selection benefit, Tier 3 memory benefit, population inference,
non-inferiority, qualification or release authority is earned. SDK1 remains
20/20 and full-program readiness remains 19/25 pending the next fresh compiler
report; the six existing release blockers are unaffected by this discovery.

### Causal-prefix repertoire discovery prepared - 2026-10-23

The [new training declaration](../sdk/discovery/cpu_context_repertoire_v1.json)
asks whether the fixed baseline/reference/height repertoire remains useful after
a common observation prefix. Immediate height feedback passed the previous
confirmation, but its nominal tracking cost prevents treating it as a universal
replacement. That confirmation supplies the design question, not fitting data.

Each fresh world first issues 64 real `no_proposal` responses, preserving the
baseline commands bit for bit for 0.533333 s. At command 64 it activates its
prospectively assigned fixed role. The [new host](../sdk/discovery/context_probe_control.py)
retains the actual past states and resolved commands through the existing v1
history contract. It never relabels an absent provider as a history status.
Sixteen features measure each joint's mean and RMS response error: observed
position change divided by command duration, minus the final issued velocity.
The current state closes the last past interval. No condition label, actuator
force, model identity or future outcome enters the feature values. This is a
local untrained feature design, not an implemented RMA model or learned choice.

| Partition | Initial native lateral velocities (m/s), on each condition | Worlds now |
| --- | --- | --- |
| Training | 0.001, 0.003, 0.004, 0.006 | 24: four starts, two conditions, three fresh roles |
| Reserved calibration | 0.0015, 0.0045 | 0 |
| Reserved evaluation | 0.0025, 0.0055 | 0 |

The exposed 0.002 and 0.005 m/s confirmation starts are excluded. Both conditions
remain the already exposed nominal and left-side 75-percent actuator profiles,
on exact S169 and fixed flat ground. The new seed is `104232300`; each world
runs 1,440 commands and 7,200 internal samples, totaling 34,560 and 172,800.
The reader must reproduce every decision, verify native state/force/contact
joins and establish that all three fresh roles in each training group observed
the same causal prefix. Those repeated prefixes are one fitting group, not
three independent training examples. World order is fixed and sequential.

Per condition, a candidate must pass all four training starts before ranking
by mean whole-episode tracking quality; ties resolve by candidate index. Every
negative stays in the ledger with censored quality. Only a complete independent
audit grants this campaign development fitting/selection authority. The
controller equations, clamps, native timing and eligibility rules are unchanged.
A delayed switch can fail even though immediate feedback worked; this question
must be answered before a selector can claim to use the observation period.

All **192 zero-world controls** passed in
`sdk2-cpu-context-repertoire-25f4457df66341abb844f5b7d633a170`, binding 415 source
and 1,359 runtime files. Eight new host controls and ten route controls also
passed separately in
`sdk2-context-repertoire-controls-b4add79f013244ebb2c90e90db1168c3`, in 42.248 s
and 43.464 s. Their exact tested sources and original logs remain retained.
They cover real-ABI baseline bits, truthful history, first-influence slew,
analytic features, chronology/leakage refusals, close-on-partial-failure,
full-prefix independent replay, native corruption, population and split rules.
No failed preparation attempt or new native world occurred at this checkpoint.

The [contained launcher](../sdk/discovery/run_cpu_context_repertoire.py) must
rerun the complete gate from a clean pushed freeze before opening the 24 worlds.
Next close those outcomes, freeze any useful training-only model, then challenge
a condition-known comparator and a learned selector on fresh reserved groups.
Prior confirmation remains excluded from fitting and reselection. Condition
changes during a run, memory benefit, broader morphology, other engines,
population inference, non-inferiority, qualification and release remain open.

### Completed body-height duration and nominal confirmation - 2026-10-23

The [fixed-candidate confirmation](../sdk/discovery/cpu_body_height_confirmation_v1.json)
completed from published `499ca1f3` after all **169 controls** passed again.
Attempt `sdk2-cpu-body-height-confirmation-aa7d02ac2ddd4ac3a4a52c5cae4d6053`
constructed twelve fresh CPU worlds, with no GPU or evaluation world. Complete
independent replay verified **17,280 decisions and 86,400 internal samples**.
The result is **9/12 eligible and 3/12 negative** over twelve seconds per world.

| Condition | Baseline eligible | Reference eligible | Fixed height candidate eligible |
|---|---|---|---|
| Left-side effectiveness 75 percent | 0/2 | 1/2 | 2/2 |
| Nominal actuator profile | 2/2 | 2/2 | 2/2 |

Candidate 2 passes all four trials, with 48 complete scoring windows each,
zero torso contacts and zero safe-no-actuation commands. Forward travel is
1.208788 m and 1.242721 m on the degraded body, and 1.262716 m and 1.318782 m
on the nominal body. This confirms the exact candidate's finite duration result;
it does not establish broad robustness, a learned selector or adaptation benefit.

The **nominal quality guard is false**. Against fresh nominal baseline, height
feedback's tracking score is worse by **0.0538553 m/s** at the 0.002 m/s start
and **0.0123895 m/s** at the 0.005 m/s start. It is also worse than the nominal
reference at both starts. On the degraded start where the reference remains
eligible, the height role's score is worse by 0.0247385 m/s. These are differences
in the declared negative tracking-error score, not simple forward-speed losses.
The three contrasts against failed episodes have no eligible quality difference.
All eight planned contrasts remain retained; no failed episode is treated as a
zero-cost comparator and no replacement winner is selected from confirmation.

The [closure](../sdk/discovery/cpu_body_height_confirmation_closure_v1.json) binds
**6,955 artifacts and 1,894,759,202 bytes**, plus 403 frozen source and 1,359 runtime
bindings. Native worker wall time is 274.3745 s; the complete independent audit
took 228.7907 s. The [closure verifier](../sdk/discovery/audit_cpu_height_confirmation_closure.py)
rehashes the inventory, checks both native model profiles, rejoins original
receipts and trials, recomputes scoring windows and failures, and checks the
fixed selection and nominal costs without new worlds. All six
[closure controls](../sdk/discovery/test_cpu_height_confirmation_closure.py)
pass in 268.949 s under
`sdk2-height-confirmation-closure-controls-a47e481cd013479fb22b6865fa342256`.
Original logs and exact tested-source copies are retained.

Duration eligibility is established in this finite population; full nominal
performance preservation is not. This is a reason to test context-dependent
selection in a new discovery design, not to deploy height feedback universally.
Collect separately declared fitting data for the unchanged control repertoire
on nominal and degraded bodies, with actual causal state/action histories and
separate calibration/evaluation groups. Fit or select only from authorized
discovery data, then challenge a condition-known comparator and a learned selector
in fresh worlds before another memory-off/shuffled Tier 3 comparison. The present
confirmation remains excluded from fitting and reselection. No population,
non-inferiority, qualification or release authority is earned; SDK1 stays 20/20
and full-program readiness 19/25.

### Body-height duration and nominal confirmation prepared - 2026-10-23

The [fixed-candidate declaration](../sdk/discovery/cpu_body_height_confirmation_v1.json)
extends the exact selected height controller from four to **twelve seconds**.
It opens twelve fresh sequential CPU worlds: baseline, the unchanged reference
and candidate 2 at the same 0.002/0.005 m/s starts, on both left-75 and nominal
actuator profiles. Each world has a private controller memory and native data
instance. The development seed remains 104232200 to retain the original command
and initial-state design. This is a duration and nominal-body check on exposed
conditions, not an unopened evaluation cohort or an independent population sample.

The controller, final speed limits, native force limits, five substeps per
command, full capture and eligibility thresholds are unchanged. The worker
retains separate compiled/XML/native-profile records for each condition. The
independent reader rejoins those records, replays every controller decision with
the independent core build and checks all force, state, contact and timing rows.
The planned denominator is **17,280 decisions and 86,400 internal samples**.

The eight prospective contrasts compare candidate 2 with baseline and reference
at each condition/start. A quality difference exists only when both complete
episodes are eligible and scorable. Nominal quality below baseline is retained
as a cost; a failed or unscorable pair is censored, never interpreted as no harm.
The report's exact finite check for nominal quality at least equal to baseline
is descriptive. It has no statistical margin, non-inferiority, fitting,
reselection, adaptation-benefit, qualification or release authority. The selected
candidate remains index 2 regardless of this confirmation's outcome.

All **169 zero-world controls** pass under
`sdk2-cpu-body-height-confirmation-77f395209fea41f1b6f8778c2c556fce`, including ten new
condition/denominator/authority/corruption/comparison controls. The gate binds
403 source and 1,359 runtime files and opens zero worlds. The ten route controls
also passed independently in 9.522 s under
`sdk2-height-confirmation-controls-b4f4f80f3ef1429ba032b7b786fbde4a`, with exact
tested-source copies and original logs retained. The
[contained supervisor](../sdk/discovery/run_cpu_body_height_confirmation.py)
will repeat the full gate from a clean published prospective freeze before any
physical execution. Longer-duration behavior and healthy-body preservation are
unproved at this preparation checkpoint.

### Completed body-height discovery - 2026-10-23

The [declared six-world successor](../sdk/discovery/cpu_body_height_discovery_v1.json)
completed from published `d2ff50fc` after all **159 safety controls** passed again.
Attempt `sdk2-cpu-body-height-discovery-49a059f2497e43f787f7097a406f4222`
constructed six fresh CPU worlds and no GPU or evaluation world. Independent
replay verified every one of **2,880 controller decisions and 14,400 internal
samples**. The complete result is **3/6 eligible and 3/6 negative**.

| Role | 0.002 m/s start | 0.005 m/s start | Complete eligible pair |
|---|---|---|---|
| Baseline | Negative: height, tilt, torso contact | Negative: height, tilt, torso contact | No |
| Existing attitude/posture reference | Negative: tilt, torso contact | Eligible | No |
| Height-enabled candidate | Eligible | Eligible | Yes |

The height candidate moved forward **0.314898 m and 0.310418 m** through the
four-second horizon. Minimum torso heights were 0.410127 m and 0.418833 m;
maximum tilts were 0.261144 rad and 0.203551 rad. Neither trial had torso contact
or safe-no-actuation commands. Both yielded all 16 eligible scoring windows.
Candidate index **2**, `feedback_height_v1`, is the sole complete eligible pair
and is selected for fresh confirmation under the unchanged finite rule.

The two predeclared contrasts retain the tradeoff. At 0.002 m/s, the reference
first violated tilt at 1.690 s while the height candidate remained eligible;
the reference has no eligible quality score, so no quality difference is
reported. At 0.005 m/s, both passed, but height-enabled tracking quality was
**0.0275593 m/s worse**: -0.156943 versus -0.129383. Its forward travel was also
smaller than the reference's 0.380400 m. Scores measure negative tracking error,
not signed distance. This result supplies a candidate that meets the two-start
rule; it does not establish a generally superior controller or learned adaptation.

The [closure](../sdk/discovery/cpu_body_height_discovery_closure_v1.json) binds
**5,841 artifacts, 644,733,843 bytes, 394 frozen source files and 1,359 runtime
files**, including the original gate, receipt, complete native streams,
independent audit and both planned contrasts. Native worker wall time was
48.9321 s and independent audit wall time 43.7498 s. The [closure reader](../sdk/discovery/audit_cpu_body_height_closure.py)
checks the complete inventory, source/runtime identity, all trial joins,
scoring windows, failures, first violations and selection without constructing
new worlds. All five [closure controls](../sdk/discovery/test_cpu_body_height_closure.py)
pass in 105.961 s under
`sdk2-body-height-closure-controls-b0f47279878e4ef98364e4caa321009a`, including
refusal of erased failures, wrong selection and a removed tracking regression.
Tested source copies and original logs are retained.

Next freeze fresh, longer-horizon confirmation and nominal healthy-body
comparisons for this exact selected candidate. Preserve the reference because
it has better tracking at the already successful start. Only after those
checks should the candidate enter a new retrieval/history-based adaptation
comparison with memory-off and shuffled controls. Verified development fitting
data and finite selection are earned; confirmation, healthy-body preservation,
unopened evaluation, useful Tier 2/Tier 3 adaptation, population inference,
equivalence and release remain unproved. SDK1 remains 20/20 and full-program
readiness 19/25.

### Body-height successor prepared - 2026-10-23

The [three-role declaration](../sdk/discovery/cpu_body_height_discovery_v1.json)
now specifies six fresh CPU worlds: baseline, the unchanged `feedback_kp3_kd05`
reference, and one `feedback_height_v1` candidate at each exposed lateral start,
0.002 and 0.005 m/s. The development seed remains 104232200, with four seconds,
480 controller decisions and 2,400 internal samples per world. The left-75
motor condition, native XML, force limits, final speed bounds and physical
eligibility criteria are unchanged. Both reference/height contrasts are
prospective; only complete eligible pairs may enter the shortlist.

The [component](../sdk/adaptation_provider/body_height_feedback_v1.py) reuses the
frozen attitude/rate/posture reference. The height-enabled role adds a request
`vy = clamp(3*(target_y-current_y) - 0.5*measured_vy, -0.20, 0.20)` in m/s.
Its nominal torso target is 0.40 m. The target is reduced by the minimum
all-leg geometric height limit minus a 0.01 m margin, with a lower target bound
of 0.28 m. The receipt explicitly records when that lower bound exceeds the
geometric cap; a target clamp is not proof of ground reach or safe support.

For feet currently bearing support, the controller rotates the opposite
vertical translation into the torso frame and maps its planar x/y components
through the existing damped leg Jacobian. These joint-velocity corrections add
to the unchanged attitude/posture proposal. Airborne feet receive no added
translation. The host keeps the 3.5 rad/s correction cap, 0.08 rad/s per-command
slew, final speed limits and exact baseline withdrawal. There is no body-pose
write, force override, phase change, inferred foot load or future observation.
The declared y-up plane at height zero is a narrow host-owned domain assumption,
not an observed terrain height. Actual rigid-body motion is not guaranteed by
the inverse-kinematics request.

All **159 zero-world controls** pass under
`sdk2-cpu-body-height-discovery-e18561b4bf61471f92f49535243726d7`, binding 394
source files and 1,359 runtime files. The eight new component controls check
height/velocity signs, geometric target and speed bounds, yaw invariance,
support gating, independent damped normal equations, domain refusal and exact
reference/fallback bits. Across two independent core builds, 384 real-ABI
decisions include 244 supported feedback and 12 withdrawals. Ten route
controls cover all roles, native timing/precision/force integrity, missing or
crossed populations, corrupted height receipts, ranking and censored contrasts.

Two preparation fixture failures remain retained with exact tested source
copies and original logs. The first emitted three synthetic substeps where the
unchanged reader required five. The second incorrectly expected a finite quality
contrast from two commands, shorter than a scoring window. The corrected fixture
preserves unscorable values and checks finite contrasts separately. Neither
failure opened a physical world or changed an eligibility threshold.

The 394 tested source bindings reproduce at `0b8851da`. A subsequent
checkout-rule change adds explicit LF rules for the two new model files; their
tested implementation bytes are unchanged. The complete gate must rerun on
the published successor before any world.

No physical world has run at this preparation checkpoint. Next publish this
prospective freeze and execute the six fresh worlds through the contained
supervisor, including its full gate and independent replay. Fresh confirmation,
healthy-body preservation, unopened evaluation, learned history inference,
Tier 2/Tier 3 benefit, equivalence and release remain open.

### Fixed-pose ground-reach diagnosis - 2026-10-23

The [retained diagnostic](../sdk/discovery/support_reach_diagnostic_v1.json)
and its [executable reader](../sdk/discovery/support_reach_diagnostic.py) now
check the same post-hoc 180-decision prefix of all eight feedback trials from
the closed body-gain comparison. The two baselines remain in the original
ten-trial denominator but are excluded from this common pre-failure prefix.
This analysis opens zero worlds and performs zero solver steps: it recomputes
1,440 controller rows, 7,200 completed internal samples and 5,760 leg-reach
bounds from 20 exact source artifacts, after verifying the full parent closure.

At a fixed torso pose, write `(A,B,C)` for the world-y row of its rotation.
For hip anchor `a`, segment lengths `L1,L2` and capsule radius `r`, the exact
minimum distal-capsule clearance above the declared flat ground is
`base_y + (A,B,C) dot a - (L1+L2)*hypot(A,B) - r`.
Both segments attain this bound at `hip=-atan2(A,B), knee=0`; every analyzed
witness is inside the compiled joint limits. This is a frozen-pose geometric
bound, not an achievable trajectory, force allocation or stability guarantee.
A clearance above 1e-6 m is counted as ground below the reachable minimum.

| Exposed start | Feedback trials | Front-right unreachable rows, out of 180 per trial | Maximum minimum clearance | Front-right support rows |
|---|---:|---|---|---|
| 0.002 m/s | 4 | 173, 173, 173, 173 | 0.06478-0.07332 m | 5, 5, 5, 5 |
| 0.005 m/s | 4 | 142, 137, 144, 145 | 0.04838-0.05433 m | 36, 41, 34, 33 |

For the unchanged reference, the failing start still has 0.05780 m minimum
front-right clearance at outer step 179. The successful start has -0.00435 m
minimum clearance there and has regained support. Both start groups initially
have unreachable poses. The later difference does not prove a cause or a
corrective policy's success. Original eligibility, failures and the empty
shortlist remain unchanged; the prefix was chosen after outcomes were known.

The reader derives both capsule endpoint centres from native distal-body
poses, then checks them against torso/joint forward kinematics. It does not
mistake a contact point for a sphere centre. Maximum endpoint discrepancy is
7.21645e-16 m. Snapshots retain body pose, linear/angular velocity, gait counters,
support and planning status. Scheduled transfer is inactive in all 1,440 rows,
including positive trials. All 5,760 foot-load observations are unavailable;
raw contacts contain geometry but no force. The 7,200 torque samples describe
actuator torques and cap occupancy, not measured ground-reaction forces.

All seven [controls](../sdk/discovery/test_support_reach_diagnostic.py) pass in
91.371 s under `sdk2-support-reach-controls-f79178da21c5428181744fb3d3b3397d`,
with tested source copies and original stdout/stderr retained. They include an
independent 702,768-point joint grid, full native geometry joins, no-world
guards, changed-floor/capsule/raw-order refusal and corrupted authority,
denominator and measurement records. Grid minima remain above the analytic
bound, within 1.884994e-6 m of its attaining witness.

Next develop a distinct bounded body-height/vertical-rate correction for
observed stance support, preserving the existing attitude/posture reference,
provider withdrawal, correction/slew limits and native force caps. It must be
tested against fresh baseline/reference worlds at both exposed starts under a
new declaration and published freeze. Ground height must be an explicit domain
assumption; this diagnostic does not supply a terrain sensor. A new controller
must establish benefit before fresh confirmation and healthy-body preservation.
No new fitting, selection, causal, population, adaptation or release authority
is earned by the geometric analysis itself.

### Completed body-gain factorial - 2026-10-23

The [prospective declaration](../sdk/discovery/cpu_body_gain_discovery_v1.json)
ran from clean, published freeze `82dc9bfea45e1e4ca5812066fe1bc4e3de347840`.
Attempt `sdk2-cpu-body-gain-discovery-54047c7d83df4b298c93b34b8e5469a0` repeated
the complete **141-control safety gate**, then completed **ten fresh CPU
worlds**, **4,800 decisions** and **24,000 internal samples**. The complete
independent replay passed. The source/runtime binding retains **375 source
files / 1,359 runtime files**. Native execution took **58.300 s** and independent
replay **51.378 s**. No GPU or evaluation world was opened.

The full result is **four eligible and six negative episodes**. All four
feedback combinations passed the 0.005 m/s start and failed 0.002 m/s. Baseline
failed both. Every feedback candidate is therefore **1/2 eligible** and no
candidate is selected:

| Attitude gain (/s) | Angular damping | First physical violation at 0.002 m/s | Eligible travel at 0.005 m/s | Eligible quality at 0.005 m/s |
| --- | --- | --- | --- | --- |
| 3 | 0.5 | Tilt at 1.6900 s | 0.38040 m forward | -0.12938 m/s |
| 3 | 1.0 | Tilt at 1.7200 s | 0.37155 m forward | -0.12878 m/s |
| 6 | 0.5 | Tilt at 1.6650 s | 0.33653 m forward | -0.14482 m/s |
| 6 | 1.0 | Tilt at 1.7383 s | 0.34931 m forward | -0.14726 m/s |

Each positive supplies 16 eligible windows and zero torso contacts. Quality is
negative velocity-tracking error, with zero best; it is not signed travel.
All six negative episodes failed tilt and torso contact; both baseline episodes
also failed minimum height. Negative episodes retain no eligible windows or
finite quality score. The fresh 3/s, 0.5 reference repeats the preceding
one-start success/failure pattern. These are finite exposed development
outcomes, not a robust controller or independent confirmation.

All **eight prospective single-factor contrasts** have zero eligibility change.
The four same-start comparisons at 0.005 m/s have eligible quality differences;
the four at 0.002 m/s do not. A score from one start cannot substitute for the
required complete eligible pair. Failure time remains diagnostic only, and no
failure time is invented for a surviving horizon. Stronger attitude gain does
not improve eligible quality in this tested grid; no population or causal
generalization is inferred.

A separately labeled [post-hoc diagnostic](../sdk/discovery/body_gain_contact_diagnostic.py)
uses the same first **180 prepared decisions / 1.5 seconds** for all eight
feedback episodes. The prefix was chosen after outcome exposure and lies
before every feedback episode's first physical violation. Baseline is excluded
from this prefix because it fails earlier, while remaining in the complete
outcome denominator. Each failing feedback episode has **five front-right
support observations** in this prefix, all in steps 1 and 3-6. The successful
episodes have **36, 41, 34 and 33** respectively, with additional support runs
starting at steps **149, 144, 151 and 152**. All four feet's complete support runs
and counts are retained. This is a descriptive association; it does not prove
whether contact loss causes or follows the divergence and never changes
selection or eligibility.

The [closure](../sdk/discovery/cpu_body_gain_discovery_closure_v1.json) binds
**5,431 artifacts / 781,520,022 bytes**. Original receipt SHA-256:
`f69df573e79c7b608015a52b069bdaa5637f7a264196c8bd9addbc28802640af`.
Original complete independent audit SHA-256:
`6a11e052e916c5f1c7b45d6ebd2847fb98a6c580c9657d5f5d2444e4785cd63a`.
The [closure reader](../sdk/discovery/audit_cpu_body_gain_closure.py) verifies
exact retained bytes, frozen Git sources, installed runtime bytes, all plans
and gate terminals, every outcome, positive-window scores, all eight factorial
contrasts and the post-hoc diagnostic's separate scope. It constructs no world;
an explicit option repeats the complete original controller replay.

All **seven closure controls passed** in
`sdk2-cpu-body-gain-closure-controls-0a490141096e41b1894994ccd4e6d975`
(151.117 s), with original test-log SHA-256
`aba74c644a7741bbaf36939eab3eaba73fa4aec55d6a2b25f24ae5dca5f8a864`.
The controls cover complete retained bytes, frozen source/runtime bindings,
full outcomes and scores, all prospective pairs, post-hoc scope, corrupted
contact histories and refusal of false selection or causal authority. They
construct zero worlds.

This experiment closes the proposed body-attitude/rate comparison without
resolving the two-start problem. Next use retained force, foot-kinematic,
velocity and phase traces to distinguish forefoot reach and support-transfer
questions, then declare a distinct controller successor. The data do not
justify selecting the longest-lived failed candidate or promoting the best
single-start score. Verified development fitting data is available, but fresh
confirmation, healthy-body preservation, learned history inference, useful
Tier 2/Tier 3 adaptation, equivalence and release remain unproved.

### Body-gain factorial prepared - 2026-10-23

The [declared successor](../sdk/discovery/cpu_body_gain_discovery_v1.json)
asks whether changed body feedback can preserve the preceding finite walking
behavior at both exposed starts. The [five-role model](../sdk/adaptation_provider/body_gain_feedback_v1.json)
contains baseline and all four combinations of **attitude gain 3 or 6 /s** and
**angular damping 0.5 or 1.0**. Every feedback role holds correction cap at
**3.5 rad/s**, slew at **0.08 rad/s per command**, supported-posture gain at
**8/s**, hip/knee preference at **-0.3/0.6 rad**, and velocity-feedback gain at
zero. Native force caps, final motor-speed limits, geometry, observation domain,
support gating and eligibility rules remain unchanged.

The 3/s, 0.5 combination is `feedback_kp3_kd05`, a fresh reference for the earlier
all-high corner. Both reference episodes and both baseline episodes are newly
constructed; previous physical output is never cached or substituted. The
same exposed development seed **104232200** and starts **0.002/0.005 m/s** are
retained for this local control question. This is not a held-out comparison or
independent confirmation. All ten worlds receive private controller memories,
480 decisions and 2,400 internal samples, giving **4,800 decisions / 24,000
samples**. One contained owner holds the native-operation mutex for the entire
sequential run. Full original streams are retained; worker and reader limits
remain 600 seconds each.

The [component](../sdk/adaptation_provider/body_gain_feedback_v1.py) reuses the
pinned body-feedback equations and support-posture objective. It changes only
the finite candidate family. Eight component controls verify the complete
factorial, fixed settings, known rotation/rate responses, source pins, support
and domain refusals, parent compatibility, host envelope ownership and real-ABI
bounds. Across **640 decisions**, two independently built core binaries agree
exactly: 488 supported feedback decisions, 24 withdrawn decisions and 128
baseline decisions. The fresh reference reproduces the preceding controller's
target bits on retained inputs. These controls do not predict locomotion.

Ten complete-route controls cover synthetic native-stream replay, all roles,
initial precision, force semantics, corruption refusal, complete ranking and
eight prospective single-factor contrasts. The complete **141-control safety
gate** passed in
`sdk2-cpu-body-gain-discovery-e72ea3bd409c462ab45069f8866b758e`, binding **375
source files / 1,359 runtime files**. Receipt SHA-256:
`da6db00af3daaeaac9341accd24170b3112379f9899a63e472c19860674e3f6f`.
It constructed zero worlds and executed zero solver steps. The earlier focused
8+10-control run is retained in
`sdk2-body-gain-component-controls-b6084f23215b4c01b5a607a4cf89752b`, including
its exact tested source snapshot.

The reader retains every first physical violation, the declared pre-violation
activity counts, and all eight same-start single-factor contrasts. Failure time
never enters ranking; a censored full horizon is not assigned a failure time.
Selection still requires two complete eligible episodes and finite window
quality. Any selected candidate needs a separately frozen fresh confirmation
and healthy-body preservation before history-conditioned learning. No evaluation
world, GPU transfer, learned history inference, Tier 3 benefit, population
inference, equivalence, qualification or release is covered here. The family is
untrained, and no new physical result has run at this preparation checkpoint.

### Completed posture and envelope factorial - 2026-10-23

The [prospective declaration](../sdk/discovery/cpu_posture_discovery_v1.json)
ran from clean, published freeze `f9a0509ddb77aa49ddddae5d681fabd222786c7f`.
Attempt `sdk2-cpu-posture-discovery-fd02e08111c54c4e8ff850109e65ed7b` repeated the
complete **123-control safety gate**, then completed **18 fresh sequential CPU
worlds**, **8,640 controller decisions** and **43,200 internal samples**. No GPU
or evaluation world was opened. The original independent reader replayed every
controller decision and native stream, with **360 source bindings and 1,359
runtime bindings**. Native execution took 130.431 s; independent replay took
111.646 s. Exit success certifies the complete execution and audit, not a
successful controller family.

The complete outcome is **1 eligible and 17 negative episodes**. Each candidate
still requires two eligible starts before ranking, and none qualifies:

| Correction cap (rad/s) | Slew per command (rad/s) | Posture gain (/s) | First physical violation at 0.002 m/s | First physical violation at 0.005 m/s | Eligible / 2 |
| --- | --- | --- | --- | --- | --- |
| Baseline | Baseline | 0 | Tilt at 1.0117 s | Tilt at 0.9467 s | 0/2 |
| 0.25 | 0.02 | 0 | Tilt at 1.0517 s | Tilt at 1.1533 s | 0/2 |
| 0.25 | 0.02 | 8 | Tilt at 1.1317 s | Tilt at 1.3150 s | 0/2 |
| 0.25 | 0.08 | 0 | Tilt at 1.0000 s | Tilt at 1.0283 s | 0/2 |
| 0.25 | 0.08 | 8 | Tilt at 1.1017 s | Tilt at 1.2250 s | 0/2 |
| 3.5 | 0.02 | 0 | Tilt at 1.0683 s | Tilt at 1.1617 s | 0/2 |
| 3.5 | 0.02 | 8 | Tilt at 1.1950 s | Tilt at 1.5567 s | 0/2 |
| 3.5 | 0.08 | 0 | Tilt at 1.0283 s | Tilt at 1.0500 s | 0/2 |
| 3.5 | 0.08 | 8 | Tilt at 1.6900 s | Eligible through 4.0000 s | 1/2 |

All 17 negative episodes failed the original tilt and torso-contact criteria;
four also failed minimum height. None is removed or assigned an eligible
quality window. The sole positive, `start_005_feedback_a350_s008_p8`, retained
16 eligible windows, zero torso contacts, minimum height **0.41337 m**, maximum
tilt **0.23341 rad**, net forward travel **0.38040 m** and lateral displacement
**-0.02111 m**. Its mean quality **-0.12938 m/s** is a negative velocity-tracking
error score; zero is perfect, and a negative score does not mean backward
travel. These observations establish one finite upright forward-walking episode,
not reliable adaptation or a selected controller.

All **24 prospectively declared single-factor contrasts** are retained. Each
axis has one finite eligibility improvement at the all-high corner, but no
pair has two eligible members for a quality difference. A surviving four-second
horizon is censored: the reader does not invent a failure time or subtract it
from an observed failure time. Failure timing never enters selection. Activity
counts use each trial's declared pre-violation prefix, which differs in length;
clipping and supported-posture proportions do not establish a population effect
or isolate a general cause.

The [closure](../sdk/discovery/cpu_posture_discovery_closure_v1.json) inventories
**4,821 artifacts / 1,044,859,064 bytes** under the durable evidence root.
Original receipt SHA-256:
`ce86a75b6db14bd230c57f08f5e21ecf63740f15660f0bcfdf3f403a8a985186`.
Original full-replay audit SHA-256:
`33b629fef53c0975c5cde5385aabcd2d120b24fe0b6dc8251817c1c55fb66de3`.
The [closure reader](../sdk/discovery/audit_cpu_posture_closure.py) checks exact
retained bytes, frozen Git sources, installed runtime hashes, complete plans,
all gate terminals, full outcome denominators, positive-window scoring,
first-violation activity, all factorial pairs and the empty shortlist. It opens
no physical world; an explicit option repeats the original full controller
replay. Original physical streams and the consumed declaration remain immutable.

All **six closure controls passed** in
`sdk2-cpu-posture-closure-controls-8efddabb199649f88df8483cd4c5ee8e`
(129.627 s). They refuse changed source/runtime or retained bytes, missing
population, erased failures, false selection, changed positive scoring and
factorial/activity tampering; they also enforce zero physical construction.
The original test log SHA-256 is
`b948beee83801d2943cad6532cbcfb6ccdbb825388d47e6a2979b7910b490119`.

The next question is whether a distinct body-feedback successor can preserve
this finite walking behavior at both exposed starts. The prospective design
must keep the full baseline/candidate denominator and original eligibility
rules. A successful discovery pair would still need a separately frozen fresh
confirmation and healthy-body preservation before training or evaluating
history-conditioned behavior. This family is untrained. Only verified
development discovery fitting authority is earned; useful Tier 2/Tier 3
adaptation, population inference, equivalence and release remain unproved.

### Posture and envelope factorial prepared - 2026-10-23

The [successor model](../sdk/adaptation_provider/posture_feedback_v1.py)
retains the original canonical body feedback, geometry, observation domain and
support gating. It adds a joint-posture preference to the damped solve. For
supported legs, the posture-enabled corner uses `u = 8 * (q_reference - q)`,
with hip reference **-0.3 rad** and knee reference **0.6 rad**, both strictly
inside the compiled joint limits. It proposes `delta = J# v + (I - J# J) u`,
where `J#` is the existing damped inverse and `v` is body-feedback foot velocity.
This minimizes `||J delta - v||^2 + lambda^2 ||delta - u||^2`. Because the inverse
is damped, the posture term is not an exact nullspace projection. The reference
is a preference, not a commanded or guaranteed attained posture.

The [nine-role model](../sdk/adaptation_provider/posture_feedback_v1.json)
contains baseline plus all eight corners of these independent factors:

| Factor | Low / off | High / on |
| --- | --- | --- |
| Absolute correction cap | 0.25 rad/s | 3.5 rad/s |
| Correction slew per command | 0.02 rad/s | 0.08 rad/s |
| Supported-leg posture preference gain | 0/s | 8/s |

Body attitude gain stays at 3/s and rate damping at 0.5; no speed-feedback or
fixed-profile blend is added. Each host session binds its candidate's envelope
before execution, and provider responses cannot raise it. Native force caps,
final motor speed limits, XML, initial values and original episode eligibility
remain unchanged. Unsupported observations withdraw the complete provider,
including its posture contribution, and return the exact baseline.

Eight component controls cover the declared quadratic objective, independent
normal equations, straight-leg behavior, geometry and reference limits,
zero-preference compatibility, yaw invariance, family/envelope binding and
real-ABI refusals. Across **1,152 decisions**, two independent core binaries
reproduced the complete outputs. The eight feedback roles supplied 976 supported
and 48 withdrawn decisions; the remaining 128 were baseline. The unchanged
corner preserves the earlier controller's target bits. Ten route controls cover
all synthetic roles, raw-stream corruption, pair completeness, activity cutoffs,
unchanged native force semantics and refusal of false authority.

Before this freeze, a weaker draft used a 1.0 rad/s high correction cap and a
2/s posture preference. Its eight component and ten route controls passed, but
it never ran physics. A separately retained inspection of the earlier medium
feedback trajectory found active baseline knee-return commands: among 104
supported observations with knee angle between 0.02 and 0.15 rad before feedback
withdrawal, median angle was 0.04685 rad and median baseline target -0.3870 rad/s.
The median negative-velocity/angle ratio was 8.672/s; this is a descriptive ratio,
not an identified controller gain. It motivated a stronger prospective contrast.
The earlier tested source bytes remain in `verified-source/` under
`sdk2-posture-feedback-controls-4764c47fa0c64444a3a72a7f7dc04cb5` and
`sdk2-cpu-posture-controls-8dc5b19009034d09baf3fbc7f01ebaba`. Both source-manifest
SHA-256 values are
`be7b77d877400fa88b3e23c47515f5897abdbfc4c0e07de23d58c9dc764709e1`.
The first folder retains `retained-knee-return-inspection.json`, SHA-256
`af11a070680f48858f58f6b7a08016ebce60503cc2065fd80cc1127ac046c1ef`.

The revised family passed the complete **123-control zero-world gate** in
`sdk2-cpu-posture-discovery-effaf0c859b4442ea9623e0276d7160d`, with **360 source
bindings and 1,359 runtime bindings**. Receipt SHA-256:
`35b1be1d16bb3721a574d5eaf0866b999520b80790a7562d28cd4a743c56307e`.
The gate includes all 105 inherited controls, eight revised component controls,
ten route controls and the inherited provider/process-containment checks. The
preflight confirms zero constructed worlds and zero solver steps.

The [prospective declaration](../sdk/discovery/cpu_posture_discovery_v1.json)
uses one development seed, both exposed starts at 0.002 and 0.005 m/s, and all
nine roles: **18 fresh sequential CPU worlds**, **8,640 decisions** and
**43,200 internal samples**. The reader independently verifies every decision
and native sample. It also retains the first original physical eligibility
violation, control activity before it (or the entire horizon when absent), and
all **24 single-factor contrasts**. Near-straight support uses the prospectively
fixed `abs(sin(knee_angle)) <= 0.1` rule. Safe-no-actuation decisions remain
separately counted and still make the original episode ineligible.

First-violation time is diagnostic only and is never substituted for eligibility
or quality. A candidate needs two complete eligible episodes before ranking;
a missing or failed start stays in the denominator. No population inference,
causal generalization, useful adaptation or release authority follows from these
finite contrasts. Only complete independently verified discovery may support
later development fitting, and a selected candidate still needs fresh frozen
confirmation. No new physical world has run at this preparation checkpoint.

### SDK2 claim targets

| Gate / capability | Target |
| --- | --- |
| R06 | Physical support for a declared bounded quadruped family, with held-out bodies and explicit unsupported regions |
| R07 | Continuous morphology coverage justified independently of compiler totality |
| R09 | Prospectively declared rough-terrain acceptance |
| R11 | Prospectively declared sensor-noise robustness |
| R12 | Prospectively declared sensor-latency robustness |
| R25 | Engine equivalence/non-inferiority with frozen outcomes, margins and adequate cohorts |
| Force-aware recovery | Whole-body support/loading feedback beyond SDK1's bounded posture/contact routes |
| Tier 2 / Tier 3 | Qualified bounded learned proposals, then reversible experience-dependent adaptation |

The release contract currently records R06, R07, R12 and R25 as missing.
R09 and R11 have retained contradictory evidence (BW34Y and BW6N respectively);
they require distinct successful successors, not completion of empty paperwork.

Start learning in a diagnosable domain while retaining the full target list.
Additional topology buckets and tasks must preserve old failures and results;
the first successful demo does not redefine SDK2 completion.

## Historical product truth at the 2026-08-13 boundary

The project has a real engine-neutral SDK source foundation:

- one versioned portable Rust controller core;
- a C ABI and Python surface;
- a public adapter-authoring contract and reference fixture;
- versioned morphology, observation, command, policy, capability, and receipt
  schemas;
- deterministic record/replay and migration source paths; and
- separately implemented Godot/Jolt, Rapier/Parry, and MuJoCo adapters.

All three engines have run genuine native physics and have separate exact-
finite walking positives. Rapier PH1 and MuJoCo MV6 close their declared s169
pose-hold-restoration and walking contracts. Godot/Jolt has the deeper bounded
quadruped evidence lineage. XV2 also retained one exact finite discrete-
material walking result from each engine. These results establish that the
portable architecture can drive three real engines; they do **not** yet prove
formal cross-engine equivalence, arbitrary morphology, continuous morphology
coverage, general robustness, or public-release readiness.

The native Live Explorer already launches real Rapier and MuJoCo workers
alongside the Godot/Jolt world, receives native body/contact frames, and can
schedule a bounded torso impulse in each native simulation. The button is a
real-physics development interaction, not an animation or replay. It does not
establish recovery: a kicked creature may recover, stumble, or fall, and the
current result is only an observation. Edited and randomly generated
morphologies can be previewed, but native Rapier and MuJoCo launch currently
refuse anything other than their descriptor-bearing exact-s169 worker paths.
The first paired realtime-requested smoke measured the Python-hosted MuJoCo
worker at `0.760x`, so three-engine realtime performance remains false.

The latest Godot/Jolt rough-yaw development successor, BW34Y, is a complete
valid `NONE`. It walked only seed `21003`; seed `21002` missed the contact
timeout gate; and the required comparator-passing seed `21001` regressed to
eleven failed walking gates. Fresh seeds remain sealed. BW34Y is useful
negative mechanism evidence, not rough-terrain acceptance.

The latest finite turning positive remains R23D21's three-cell Godot/Jolt
result for s169 and seed `21501`. R23D23 then retained three execution-valid
Rapier negatives: both commanded creatures fell during the active turn rather
than narrowly missing a terminal threshold. Its MuJoCo implementation seam was
repaired prospectively in R23D24, which produced three execution-valid cells;
both commanded arms passed, but the zero-heading reference repeated seven late
passive front-right contact losses. R23D25 proved its terminal zero-forward
command and receipt semantics exactly across `1,510` active-terminal steps but
repeated the same seven losses, so that semantic correction was causally
insufficient. R23D24 and R23D25 are valid complete negatives and cannot rerun.
R23D26 closed a nine-cell Rapier-only steering-cap development screen as a
valid complete negative. Cap `0.10` stayed upright but did not turn; `0.20`
passed every individual cell but its positive response above reference drift
was `0.00725 rad`, below the frozen `0.01 rad` command-conditioned margin;
`0.30` made both commanded arms fall. The selector returned `NONE`. The
identity cannot rerun, and finite three-engine turning, portable turning, and
equivalence remain false.

Later work established bounded turning positives separately in all three
engines, but not one accepted fresh synchronized three-engine validation.
R23D44's paired Rapier screen showed that the unconditional startup ramp can
reduce one conditioned turning response below its development floor. R23D47
then proved one portable alternative in an exact, outcome-exposed MuJoCo
reference world: latch that same ramp only after simultaneous loss of all four
foot contacts during startup. It walked `1.638926076250989 m` with zero torso
contacts after the predicate fired at step `3`. This is a mechanism positive,
not a production selection; no heading command was present, and portable
turning, formal equivalence, prone-to-standing, and release remain open.

The evidence system was also hardened at the layer above physics. New closure
rules retain load-bearing bytes in content-addressed storage before later work
can overwrite them; historical audits must use retained bytes or pinned Git
blobs instead of mutable live paths; unrecoverable legacy bytes are counted
rather than reconstructed; and the checkout-filter migration is separated
from frozen-history interpretation. Reproducible Windows DLL work established
that compiler output was stable while MSVC linker timestamps and CodeView
metadata required a distinct `/Brepro`-based successor recipe. These are
foundational SDK-quality improvements, not locomotion results.

## Three product checkpoints

### Checkpoint 1: first public quadruped SDK

Ship the first public package only after every required gate in the executable
quadruped release contract passes. The package must include:

- bounded quadruped morphology input, explicit support/OOD reporting, and the
  evidence required for its advertised coverage;
- the portable controller, public ABI/bindings, adapter kit, versioning,
  deterministic records, diagnostics, examples, and clean-room package test;
- independently characterized and qualified Godot/Jolt, Rapier/Parry, and
  MuJoCo integrations running the same canonical policy semantics;
- a prospective formal equivalence or non-inferiority study across every
  advertised engine, with margins and adequacy frozen before results;
- bounded command-conditioned turning with zero-command straight-walk
  compatibility;
- a canonical prone-to-standing skill with explicit entry, exit, contact,
  safety, timeout, and no-cheat gates;
- the real-physics three-engine Explorer with loud capability, provenance,
  refusal, and performance reporting; and
- a public **optional-provider adaptation interface** plus the versioned Tier
  2 data/training/encyclopedia/promotion architecture described below.

“Optional” applies to the provider at runtime, not to the interface in the
SDK. A consumer that installs no provider must receive the deterministic
baseline controller behavior, byte-for-byte wherever the public numeric
contract promises exactness. Checkpoint 1 does not require a trained Tier 2
model, but it does require the stable seam so later learning does not break the
ABI or invite an engine-specific back door.

### Checkpoint 2: Tier 2 learned offline adaptation

Train and ship a versioned morphology-conditioned provider after the
deterministic public baseline and its safety envelope are stable. MuJoCo Warp
is the preferred high-throughput discovery/training plane on the local NVIDIA
GPU. It can batch thousands of worlds and vary supported per-world model
fields, but GPU throughput is not cross-engine evidence.

Tier 2 must:

- learn from a prospectively declared morphology/task/environment corpus;
- predict bounded controller corrections or parameter suggestions from
  engine-neutral inputs rather than emit engine-specific motor hacks;
- report confidence, support distance, OOD/refusal, model identity, and data
  provenance;
- retain successes, failures, and counterexamples;
- pass shadow evaluation before gaining bounded influence;
- preserve the deterministic controller and safety clamps as the fallback;
  and
- qualify the promoted model independently in ordinary CPU MuJoCo,
  Rapier/Parry, and Godot/Jolt under prospective physical gates.

Tier 2 is stronger than a lookup table. It may use prior encyclopedia chapters
as examples, priors, or retrieval context, but it must infer within an
evidenced support region without requiring an exact prior numeric match. It
must refuse or fall back outside that support rather than present extrapolation
as generalization.

### Checkpoint 3: Tier 3 online and long-context adaptation

Tier 3 is a required destination for the program, not an optional curiosity.
It allows a creature to use recent trials and retained memory to improve its
next behavior while it encounters a new morphology or condition. The goal is
eventual safe adaptation across broader topology and skill families, including
the “almost alive” quality of trying, remembering, and trying better.

That ambition does not authorize uncontrolled online weight mutation. Tier 3
must retain an immutable base model and deterministic safety layer; version
every memory and adaptation event; bound every influenced output; expose OOD
and uncertainty; retain complete before/after traces; support reset and
rollback; and promote durable lessons only through an offline reviewed release
boundary. Its claims begin with a bounded task and support domain and expand
only through evidence.

## Adaptation tiers

### Tier 1: deterministic compilation and behavior encyclopedia

Tier 1 derives scheduling, stance, gains, limits, and known skill parameters
from the versioned morphology descriptor and a curated encyclopedia of
mechanisms and bounded recipes. The existing morphology compiler, policy
profiles, host characterization, negative-result ledger, and deterministic
fallback make this tier comparatively close. They do not yet establish the
release contract's arbitrary or continuous physical-coverage claims.

Tier 1 should be built deliberately because it remains:

- the safe fallback for every learned tier;
- the source of interpretable priors and training labels;
- the conformance oracle for zero-provider behavior; and
- the way a developer gets useful deterministic behavior without a model
  runtime.

### Tier 2: learned offline morphology-conditioned provider

Tier 2 learns a mapping from morphology, task, state/history, baseline output,
and supported environment features to bounded adaptation output. Plausible
implementations include retrieval plus interpolation, supervised parameter
prediction, a bounded residual policy, an offline system-identification model,
or a hybrid. The architecture should permit those implementations without
changing the host adapters or public base controller.

### Tier 3: online or long-context adaptation

Tier 3 updates episode memory or adaptation state while the creature operates.
The first safe form should update bounded external memory or context, not
silently rewrite the deployed base weights. A later weight-updating form would
need a separately versioned runtime, rollback semantics, stronger containment,
and its own evidence program.

## Public adaptation-provider boundary

The provider is a pure engine-neutral proposal layer. It receives typed,
versioned data and cannot read or mutate a native physics world.

Required inputs are:

- morphology graph/descriptor, derived morphology features, and support-domain
  status;
- canonical observation and recent canonical history;
- task command and skill/phase identity;
- deterministic baseline controller output and controller memory;
- provider memory/context, seed, model/version identity, and capabilities; and
- unit, frame, timestep, adapter, and provenance metadata.

Allowed outputs are:

- a bounded residual or bounded parameter proposal in canonical units;
- confidence, support distance, uncertainty, and explicit OOD/refusal status;
- a versioned provider-memory update;
- diagnostics and causal/provenance labels; and
- an append-only candidate-lesson event for the encyclopedia pipeline.

The provider may not construct a world, apply a native force, write a body
transform, bypass the deterministic scheduler, change a safety limit, or
publish a new encyclopedia chapter. The portable core validates identity,
shape, units, finiteness, age, capability, support status, and bounds before
composition. Invalid, stale, unsupported, uncertain, or absent provider output
reduces to the deterministic baseline and emits a reasoned receipt.

The source implementation now exists in
[`../sdk/core/src/adaptation.rs`](../sdk/core/src/adaptation.rs), with public C
and Python entrypoints, the normative
[`../sdk/adaptation_provider/provider_contract_v1.json`](../sdk/adaptation_provider/provider_contract_v1.json),
and A0-A7 zero-world conformance. It resolves exact-order canonical velocity
corrections through absolute, slew, and original actuator-speed clamps. The
absent or rejected path is tested for binary64-bit-exact final velocities
against the deterministic baseline. The clean pushed-source A0-A7 report from
commit `211cb78c1db6818c44470714a165db0df8dbd2dd` is retained at
`SporeSpore_Evidence/adaptation-provider-211cb78/report.json`, SHA-256
`e8ddc4fd0da1fe85346251103f8c6a1e9fc9c7e9121902d2cafb8fa5390f3b86`,
and closes QSDK-R21. This is public-interface evidence, not a trained-provider,
walking, packaging, or physical claim.

## Turning training responses into encyclopedia chapters

Yes: Tier 2 training and later Tier 3 episodes should be able to generate new
chapters. They must do so through an append-only promotion pipeline, not by
editing the live encyclopedia that produced the current run.

```text
retained raw episode
  -> immutable feature/outcome receipt
  -> candidate lesson or counterexample
  -> reviewed candidate chapter
  -> frozen training/evaluation corpus
  -> new provider/model version
  -> independent cross-engine qualification
  -> promoted encyclopedia release
```

A candidate chapter can contain the triggering morphology/support region, task
and environment, baseline response, proposed adaptation, measured result,
failure modes, confidence/calibration, and the exact model/data/evidence
identities. Both successful and failed adaptations belong in the corpus. A
chapter learned from MuJoCo Warp is a training hypothesis until independent
qualification says what, if anything, transfers to each release engine.

The currently deployed provider may emit candidate events and use its own
versioned short-term memory. It may not rewrite its own published model,
controller, thresholds, or global encyclopedia mid-campaign. Promotion always
creates a new identity and preserves the predecessor.

That lifecycle is now executable in
[`../sdk/adaptation_provider/tier2_architecture.py`](../sdk/adaptation_provider/tier2_architecture.py)
under
[`../sdk/adaptation_provider/tier2_architecture_v1.json`](../sdk/adaptation_provider/tier2_architecture_v1.json).
Its T0-T6 fixture retains one success and one counterexample, creates a
candidate-only chapter, freezes the corpus and split plan, registers a new
immutable model candidate, rejects MuJoCo-Warp-only promotion, and requires
the exact `{godot_jolt, rapier_parry, mujoco_cpu}` qualification set before it
can emit a new successor identity. Those qualification records are synthetic
architecture fixtures today; no trained model or physical qualification is
being claimed. The clean pushed-source T0-T6 report from commit `211cb78` is
retained at
`SporeSpore_Evidence/tier2-adaptation-architecture-211cb78/report.json`,
SHA-256
`6bc9951d1f625d61ce378cbb0ff6ca87a59b63d198bbef5a5bd4dc881f87eb2d`,
and closes QSDK-R22.

## MuJoCo Warp training plane

[MuJoCo Warp](https://github.com/google-deepmind/mujoco_warp) is a strong fit
for this project because it is optimized for high-throughput NVIDIA GPU
simulation, exposes batched `nworld` models/data, supports CUDA graph capture,
and permits domain randomization through supported per-world model fields.
Its public examples include thousands of simultaneous worlds and Brax/JAX
training integration.

The first training design should use topology-compatible morphology buckets:

1. compile a canonical base topology with enough declared assets/slots;
2. vary supported dimensions, masses, inertias, joints, materials, tasks, and
   disturbances per world;
3. retain exact descriptors, seeds, model hashes, outcomes, and failure codes;
4. separate exploratory reward from strict safety/locomotion predicates;
5. train or fit a canonical provider; and
6. replay held-out candidates through ordinary MuJoCo and then through
   Rapier/Parry and Godot/Jolt.

Heterogeneous worlds and per-world meshes are possible within MJWarp's model
constraints, but arbitrary topology still needs explicit compilation/bucketing
and may require separate captured graphs. MJWarp is throughput-oriented rather
than guaranteed low-latency, lacks automatic differentiation, and does not
support every MuJoCo feature. Feature compatibility and actual local GPU/RAM
throughput must be measured before fixing the 5,000-world campaign design.

The first prospective source boundary now exists at
[`../sdk/adaptation_provider/mujoco_warp_supported_subset_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_supported_subset_contract_v1.json).
It pins the local development stack to MuJoCo/MuJoCo Warp `3.11.0` and Warp
`1.16.0`, enumerates the candidate rigid-quadruped subset and documented
refusals, and verifies the batched upload/step/reset signatures plus CUDA
availability without constructing a model or stepping a world. The local RTX
4070 Ti runtime passes that zero-world installation probe. The actual physics-
subset question is separately classified as equivalence/non-inferiority and
remains sealed pending a retained calibration cohort, margin provenance,
factor/cohort adequacy, and a prospective held-out freeze. Training-plane and
training-data authority therefore remain false.

The retained Warp preflight and its validation audit now compose through the
canonical no-Godot cold route from exact clean pushed source
`42faa71eeeec3f5651935e89e3c8128c56e3502e`. The run passed all seven executed
stages in `1124.725705 s`, with only the declared Godot stage skipped. Receipt:
`SporeSpore_Evidence/conformance-runs/20260814T203430Z-42faa71e-f4718333e4b742ed95662425e6319676/receipt.json`,
SHA-256
`a9a475da5a1576cf6b01f0ffd0ab6dae7a5ae9168f2f09bead9b2918054eddd3`.
That receipt is non-transitive and cache/reuse-disabled. It proves only this
exact source-integration observation and supplies no physics-subset,
throughput, training-data, population, equivalence, physical, or release
claim.

The first calibration-protocol source is now executable at
[`../sdk/adaptation_provider/mujoco_warp_equivalence_calibration_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_equivalence_calibration_contract_v1.json).
It refuses to treat runtime/API availability as physics equivalence. A later
production plan must freeze semantic ceilings before calibration outcomes,
bind every model/condition/runtime/batch/graph/dtype input, and keep calibration
and held-out identities disjoint. For a claim scoped only to one declared
exchangeable generator, at least `59` unique calibration groups and `59`
held-out groups provide the declared distribution-free `95%` content / `95%`
confidence zero-exceedance boundary. MJCAL0-MJCAL7 currently exercise only
synthetic records and reject `15` mutations at zero worlds; no production
factor grid, margin, held-out cohort, subset qualification, or training plane
is authorized.

Exact clean pushed source `daca13321288ba27e5c619509c554bf2126e362e`
now has a create-only retained source-conformance report at
`SporeSpore_Evidence/mujoco-warp-equivalence-calibration-daca133/report.json`,
4,882 bytes with
`sha256:d45b7e3499775e846f8b77d36bf06a265fbf2238fd9cb2e71125888ed910b3d0`.
[`../sdk/adaptation_provider/mujoco_warp_equivalence_calibration_validation_manifest.json`](../sdk/adaptation_provider/mujoco_warp_equivalence_calibration_validation_manifest.json)
binds the report and five frozen source blobs. Its executable audit confirms
8/8 cells, all 15 mutation refusals, 59/59 fixture minima, and zero models,
steps, attempts, and worlds. This is not a production calibration plan or a
physics result; semantic ceilings, margins, held-out qualification, supported-
subset, throughput, training, equivalence, physical, and release authority all
remain false.

The exact evidence-binding source
`368f915880f27483672d0815f7e2c853ce0acccb` subsequently passed the complete
canonical no-Godot cold route in `994.0961292 s`. The retained 17,336-byte
receipt is
`SporeSpore_Evidence/conformance-runs/20260814T212642Z-368f9158-b9feb7f4253b4f8284756623dcc0908b/receipt.json`,
`sha256:8081b65e74cfa613acfad9ecc34a03214b3582514482dc1181be8200aa715bdf`.
All eight stage receipts and the full log were independently matched to their
CAS payloads/manifests; seven stages passed and only the declared Godot stage
was skipped. The MJCAL source and evidence markers are each present once. This
is a cache/reuse-disabled, non-transitive source-integration observation, not a
physics-subset, throughput, training-data, equivalence, physical, or release
result.

The next zero-world development gate is
[`../sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_contract_v1.json).
It makes the missing semantic provenance measurable before any production plan
can exist. The current inventory accepts `0` production sources and preserves
all `5` required metrics as unresolved. A future source must bind an exact
metric/unit/value through a strict JSON pointer into hashed source bytes on the
live main lineage, plus pre-outcome chronology, downstream decision invariance,
an explicit adequacy argument, and bounded factor scope. Synthetic MJCAL
fixture values, adapter-specific readback tolerances, and historical outcome
thresholds do not meet that contract by substitution.

MJSC0-MJSC7 prove a separate fixture-only positive compiler path and reject
`25` content/path/locator/value, chronology, outcome-leakage, fixture-leakage,
unit, finiteness/discrete-step, scope, invariance/adequacy, duplicate, and
authority mutations. They open zero models, steps, attempts, or worlds.
Production semantic ceilings, the factor grid,
margins, held-out cohort, subset qualification, throughput, training,
equivalence, physical, and release authority all remain false.

The clean-pushed source freeze
`faaf057ad6379ba66ec1a4425f479082f28cb1b6` produced the immutable 3,926-byte
report at
`<evidence-root>\mujoco-warp-semantic-ceiling-readiness-faaf057\report.json`
with SHA-256
`8102f0cbc8153f724d408ea4fc0393dfdb226b4a70c8521fb9e7b45b6be4b3fe`.
The repository validation manifest and audit independently rehash the five
source Git blobs and retained report, then recheck `0/5` production readiness,
the fixture-only `5/5` compiler path, all 25 refusals, and every zero-world and
authority boundary. Production semantic sources remain the next unresolved
prerequisite; this evidence does not invent them.

Binding commit `dd553b6e669c8875eaff71fb0d35c59d65c5c329` then passed the
full canonical no-Godot cold route in `1147.5648811` seconds. Its 17,339-byte
receipt is retained under durable run ID
`20260814T222617Z-dd553b6e-5108da71f3fe495c976a89e5d7f6a987` with SHA-256
`67b6eedcb9aed2a2b2c16d8290c1452d4d2f8256c65f14d9f554c26d6487cfe9`.
Seven stages passed and Godot was explicitly skipped. Independent CAS and
source-tree rehashing found both MJSC terminals exactly once, no cache lookup
or reuse, an incomplete non-transitive dependency key, and no physical,
scientific, or release authority. This closes source integration only; the
five production semantic sources remain unresolved.

The transfer strategy is **not** to reverse-engineer three bespoke policies.
We should learn one engine-neutral adaptation hypothesis from the high-volume
MuJoCo plane, compile the same canonical decisions through each adapter, and
then characterize or reject the hypothesis independently on each engine.
MuJoCo can accelerate discovery; it cannot declare Jolt or Rapier equivalent.

The locally supplied MuJoCo documentation PDFs, the Coros gait paper and
supplement, and its demonstration binary are inventoried with SHA-256 in
[`research/LOCOMOTION_RESEARCH_SOURCES.md`](research/LOCOMOTION_RESEARCH_SOURCES.md).
They are design inputs rather than LoColemotion evidence.

## Movement and showcase order

The product movement path after the current straight walker is:

1. bounded commanded turning with zero-command compatibility; R23D16 has
   passed its implementation-recovery zero-world gate and still requires a
   clean push, source-exact attestation, and its single serialized matrix;
2. canonical prone-to-standing;
3. explicit-orientation fall and self-righting successors;
4. push recovery and interactive kick recovery evidence;
5. rough/varying terrain, noise, latency, and material extensions;
6. running and other quadruped modes; and
7. six-, eight-, many-, two-, and zero-legged topology programs.

Prone-to-standing comes before general self-righting because it provides a
repeatable recovery state, reusable contact/clearance gates, and a clean
product feature without pretending all fall orientations are solved. General
self-righting can then test a finite orientation family and learn whether a
tuck/roll-to-prone route, direct support construction, or both deserve
promotion.

The showcase should expose real physics loudly: exact engine/version, source
and policy identities, canonical inputs, native steps, body/contact state,
controller/application receipts, simulation-to-wall-time ratio, capability
gaps, and evidence authority. It should support seed entry, random generation,
live descriptor editing, refusal explanations, three-engine launch, and the
kick action. A descriptor may animate in the editor before it is runnable, but
“Walk” must fail closed until every selected native worker can compile and run
that descriptor honestly.

## Why this has usually remained bespoke

Researchers have pursued generalist and multi-morphology locomotion; it would
be wrong to claim otherwise. Examples include
[Shared Modular Policies](https://proceedings.mlr.press/v119/huang20d.html),
[MetaMorph](https://arxiv.org/abs/2203.11931),
[Universal Morphology Control](https://proceedings.mlr.press/v202/xiong23a.html),
[URMA](https://proceedings.mlr.press/v270/bohlinger25a.html), and
[LocoFormer](https://proceedings.mlr.press/v305/liu25a.html). LocoFormer, for
example, reports one long-context policy trained across a very large
procedurally generated robot population and evaluated on unseen legged and
wheeled robots.

What remains rare is the whole product LoColemotion is trying to assemble:

- a stable public SDK and adapter contract rather than a paper's internal
  training harness;
- one canonical semantic boundary across unrelated physics engines;
- procedural morphology compilation with explicit support and refusal;
- deterministic fallback plus learned adaptation rather than either one alone;
- native real-physics developer tooling;
- independent engine characterization instead of assuming sim-to-sim transfer;
- retained failures, immutable campaigns, reproducible artifacts, and
  auditable evidence provenance; and
- packaging, ABI/versioning, diagnostics, licensing, migration, and ongoing
  support.

There are structural reasons. Morphologies change observation/action sizes,
joint topology, contacts, leverage, and failure modes. Physics engines differ
in solver, actuator, contact, integration, and readback semantics. GPU batches
prefer static shapes while a public SDK must accept dynamic developer input.
Training reward is not a safety or locomotion proof. Cross-engine transfer adds
a sim-to-sim gap on top of the usual generalization problem. Finally, academic
incentives reward a novel benchmark result more directly than years of ABI,
packaging, verification, and backward-compatibility work.

So the research ingredients exist. The unusual opportunity is to combine them
with the engine-neutral product and evidence layer. The honest novelty claim is
not “nobody has made a universal locomotion policy.” It is that LoColemotion is
building a developer-facing, multi-engine, procedurally conditioned locomotion
system whose limits and provenance are executable rather than implicit.

## Immediate order of work

1. Keep every closed campaign immutable and keep physical and qualification
   workloads serialized.
2. Complete the zero-world process commissioning specified in
   [`LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md` §111](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#111-post-r23d13-process-acceleration-without-weaker-evidence--2026-08-10):
   stage timings, compact receipts, content-addressed dependency keys,
   invalidation controls, the physical-authorization safety kernel, and one
   full cold equivalence baseline.
3. Use the retained zero-world R23D26 trace-lineage report to freeze the next
   observable successor. Its focused replay separates authority saturation and
   direction-dependent stability from contact collapse, while correctly
   reporting limiting actuators unavailable because the old trace omitted
   complete final commands and declared limits. Use that retained diagnosis to
   preregister that distinct mechanism—not a threshold relaxation or
   same-identity rerun. Then decide prospectively whether turning while
   walking, controlled stop and settle, passive standing, and their composition
   remain one endpoint or become separately gated primitives.
4. Only after that decision, use the repeatable MuJoCo or MuJoCo Warp
   development lane to screen candidates without release authority, freeze one
   artifact and one question, and validate it prospectively on held-out native
   engine paths.
5. Complete the public real-physics Explorer, canonical prone-to-standing,
   packaging, diagnostics, documentation, licensing, and every remaining
   executable quadruped release gate.
6. Ship Checkpoint 1 before starting a load-bearing mass-training campaign.
7. Use MuJoCo Warp for Tier 2 discovery and training, then qualify a frozen
   provider independently in every advertised engine.
8. Advance Tier 3 through its own bounded, versioned, fail-closed program.

Process commissioning phase one now has a prospective eight-stage timing,
receipt, transcript, failure-excerpt, and content-addressed-retention
implementation. Its focused success and mutation tests pass, but its own
receipts declare the dependency key incomplete and cache reuse disabled. It
therefore measures the next full cold run without shortening or waiving it.

Its first clean-pushed canonical no-Godot observation subsequently passed in
`1597.2312833 s` as run
`20260810T211106Z-b1627db3-656c086d6125444ca5dd07dd02bbe2f0`.
Campaign closures/zero-world gates, portable core/release source, and
authority/historical closures consumed about `94.4%` of the run. All retained
receipt and transcript bytes reproduced from content-addressed storage. This
is a measured no-Godot baseline, not cached equivalence or the required full
Godot-inclusive cold baseline; cache lookup and reuse remain disabled.

The next process layer now constructs a conservative dependency-key candidate
from exact tracked checkout bytes, Git identity/status, and hashed referenced
environment values. Its root/order/content/path/environment/runtime mutation
controls and retained construction-failure control pass, and every canonical
run executes the audit. The live candidate remains explicitly incomplete:
the complete process-environment digest now covers all nonliteral lookup
values, but exact runtime/evidence manifests and non-environment dependency
closure are still absent. No lookup, reuse, movement, or release authority
follows from this candidate.

Referenced CAS evidence is now included without hashing the unrelated 20.4-GB
durable root: `568` matched objects / `354994572` payload bytes revalidate in a
roughly `32.3 s` full candidate construction, while corruption and explicit
missing-object controls fail and unrelated CAS append stays stable. Non-CAS
campaign-path manifests remain incomplete, so this changes no lookup, reuse,
movement, or release claim.

No checkpoint may borrow authority from a later one. A visually persuasive
demo is valuable, but it cannot replace release conformance; a large GPU
training result is valuable, but it cannot replace independent engine
qualification; and online adaptation is valuable only while the deterministic
safety and evidence boundaries remain intact.

## 2026-08-08 release-path update: R23D6 closes negative

The R23D6 implementation reached clean pushed commit
`acf0511fe9c24cd0439107ca3f8510054629263d`, passed complete Godot-including
conformance in `1964.5542466 s`, and then completed both preregistered MuJoCo
Stage A cells. Both commanded signs produced the requested signed yaw, but the
exact terminal-restoration policy failed the complete frozen outcome: both
cells carried an airborne front-left foot through the entire acquisition
window, and neither established the required on-time, passively stable four-
contact stance. The evaluator selected `NONE`; Stage B did not open.

R23D6 is therefore an immutable valid finite negative, not a crash and not a
portable turning success. Checkpoint 1 still requires QSDK-R23 turning and
QSDK-R24 canonical prone-to-standing in addition to the other missing or
contradicted release gates. A distinct R23D7 may change the terminal-stance
acquisition and passive handoff mechanism, but may not rerun, rethreshold, or
reinterpret R23D6. The public adaptation seam and Tier 2 architecture remain
implemented; this result does not change their release status or pull mass GPU
training ahead of the Checkpoint 1 SDK.

## 2026-08-08 release-path update: R23D7 implementation-qualified

R23D7 is the distinct turning successor. It keeps the entire frozen R23D6
estimand and release gate but replaces the failed terminal policy with an
engine-neutral all-eight-joint morphology-neutral stance target. The pure audit
compiles exact s169, passes five equation canaries, rejects ten mutations, and
opens zero worlds. Separate MuJoCo, Rapier/Parry, and Godot/Jolt worker routes
now implement the same neutral target through their native velocity mappings.

The complete aggregate gate passes `25` dependency-removal controls, `15`
retained-marker cases, all `11` possible worker identities, eight independent
evaluator tests, exact release-runtime materialization, direct-physical refusal,
and worktree invariance. It constructs zero models and opens zero worlds. This
advances implementation readiness without advancing QSDK-R23: the source is
not yet an isolated clean pushed freeze, full-Godot source-exact attestation is
not yet retained, and the frozen physical selector has not run. Prone-to-
standing and the other Checkpoint 1 gates remain separate and are not displaced
by R23D7.

## 2026-08-09 release-path update: R23D7 closes before world

R23D7 reached clean pushed source and passed exact-source Godot-including
conformance, but both MuJoCo Stage A workers correctly failed authorization
before model or world. The supervisor's 75-path freeze contained all 16
declared MuJoCo dependencies. The worker independently duplicated that list as
a stale ordered 11-path tuple, so its exact comparison failed. The immutable
closure retains 22 attempt files and CAS copies, two terminal failures, zero
world attempts/builds, selector `INVALID`, and nine unopened Stage B cells.

This is an implementation-validity finding, not a turning result. R23D7 is
consumed and cannot be rerun. R23D8 may preserve the same neutral-stance
scientific hypothesis and thresholds because no physics world opened, but its
new implementation identity must use one dependency authority and must execute
all three engines' actual production authorization functions against a
supervisor-shaped freeze during zero-world qualification. Checkpoint 1 remains
open on turning, prone-to-standing, formal cross-engine comparison, and the
other unsatisfied release gates.

## 2026-08-09 release-path update: R23D8 stage zero

R23D8 now freezes that authorization-only successor. It inherits every R23D7
scientific field and the `2 + 9` physical schedule unchanged, but forbids a
worker-local dependency tuple in every engine. Its planned zero-world gate
must run three positive and three mutated-binding calls through the actual
production authorization functions before any model can be constructed.

The independent declaration audit passes the predecessor, inheritance,
single-authority, and eight-mutation checks with zero R23D8 workers, models, or
worlds. This advances the turning implementation line without claiming that a
creature has turned. Checkpoint 1 is still `10/25`: turning and canonical
prone-to-standing are both unproven, alongside formal cross-engine comparison
and the remaining release-quality and robustness gaps. The adaptation seam and
Tier 2 architecture remain implemented; Tier 2 GPU training stays after this
first public-SDK checkpoint.

## 2026-08-09 release-path update: R23D8 closes with selector NONE

R23D8 reached clean pushed source
`841a4382cefa27ab2d679b4faae966c6dd29d40a`, passed source-exact full-Godot
conformance, and passed all six production authorization canaries before two
serialized MuJoCo Stage A worlds opened. Both cells completed execution-valid
3,772-row traces, advanced more than `1.85 m`, and produced yaw with the
requested sign. Positive reached four contacts at terminal step `313` and held
them for `227/360`; negative first reached four contacts at step `163` but held
them for at most `158/360`. Both then maintained all four contacts through all
`240` passive zero-actuation steps.

The active neutral-stance hold therefore failed even though its resulting pose
was passively stable. The evaluator validly selected `NONE`, leaving every
three-engine Stage B world unopened. R23D8 is an immutable finite negative for
that exact policy, not a negative for turning in general. A distinct successor
may prospectively test a support-aware active-to-passive handoff. Checkpoint 1
remains `10/25`: turning, prone-to-standing, formal cross-engine comparison,
clean-room packaging, coverage, robustness, and distribution gaps remain open.

## 2026-08-09 release-path update: R23D9 stage zero

R23D9 now freezes the next turning mechanism before implementation or physics.
It keeps R23D8's total `780` terminal-plus-settle steps and every outcome
threshold, allows no more than `420` active neutral-acquisition steps, requires
`30` consecutive completed all-four-contact observations, and then
irreversibly applies zero native actuation for at least `360` steps. The
confirmation count deliberately exceeds R23D8's `23`- and `16`-step transient
support episodes and is therefore labeled development-informed, not an
independent validation rule.

The pure temporal oracle passes five canaries and rejects twelve mutations.
No R23D9 worker, physical process, model, or world exists, so this advances
design readiness without changing the `10/25` release scoreboard. Turning and
canonical prone-to-standing remain the first two movement gaps; the optional
adaptation interface and Tier 2 architecture remain implemented and unchanged.

## 2026-08-09 release-path update: R23D9 three-engine native routes

The stage-zero no-worker design is preserved at clean pushed commit
`53df1481aa03e1d638a46222c51f0d40fdb457ed`. Stage one now supplies independent
MuJoCo Python, Rapier Rust, and Godot/Jolt GDScript mirrors of its exact temporal
policy. All three execute the five canaries and reject the twelve mutations,
preflight `11` declared identities in total, and explicitly refuse physical
mode before model construction.

This is meaningful SDK implementation progress, but it is not a movement
result: production physical workers, the evaluator, the supervisor, models,
worlds, and physical authorization remain absent. Checkpoint 1 stays `10/25`.
Turning and canonical prone-to-standing remain the first two movement gaps;
formal cross-engine comparison and the other release-quality/robustness gates
also remain open. The adaptation interface and Tier 2 architecture are
unchanged.

## 2026-08-09 release-path update: R23D9 consumed, R23D10 required

R23D9 passed exact-source full-Godot qualification and all six production
authorization canaries, then opened exactly its two declared MuJoCo Stage A
worlds. Both cells completed and turned in the commanded direction; one passed
the frozen irreversible-handoff outcome and one lost contact after handoff.
The evaluator produced a diagnostic `valid_none_stage_a` payload, but its
generic CLI marker did not match the supervisor's stage-specific marker. The
supervisor therefore closed the one-shot campaign infrastructure-invalid
before an authoritative selector result, and no Stage B world opened.

This does not move the `10/25` Checkpoint 1 scoreboard. R23D9 cannot rerun, and
its diagnostic payload cannot be promoted into a scientific result. R23D10
must be a scientifically distinct turning mechanism and must add exact CLI
producer/consumer integration canaries before physics. Turning remains the
active movement gap, followed by canonical prone-to-standing. Formal three-
engine comparison, the real-physics Explorer, clean-room packaging and
distribution, and the other support/robustness gates also remain open. The
optional adaptation-provider interface and Tier 2 architecture remain
implemented; trained adaptation remains outside the first-release gate.

## 2026-08-09 release-path update: R23D10 stage-zero taper frozen

The immediate turning path now has a distinct prospective mechanism rather
than an unspecified R23D10 placeholder. Retained R23D9 traces are disclosed as
development evidence for a support-and-pose-confirmed `120`-step active
quiescent taper, followed only after tight confirmation by at least `360`
irreversible passive steps. Its pure reference implementation passes five
canaries and rejects sixteen mutations. The declaration also freezes exact
Stage A and complete evaluator CLI marker contracts, directly retiring the
wire-protocol omission that invalidated R23D9.

This is zero-world stage zero: R23D10 has no native three-engine mirrors,
production workers, model construction, physical authorization, or movement
result. Checkpoint 1 remains `10/25`. The next turning work is native temporal
mirroring and an executable evaluator CLI integration canary, then full zero-
world qualification and exact-source attestation before any physical campaign.
After portable turning is evidenced, canonical prone-to-standing remains the
other first-release movement primitive. Formal three-engine comparison, the
real-physics Explorer, clean-room packaging and distribution, and the remaining
support/robustness gates stay open. The optional adaptation-provider interface
and Tier 2 architecture remain implemented and unchanged.

## 2026-08-09 release-path update: R23D10 native stage one passes

The turning path has advanced from a pure declaration to three independently
implemented native-language temporal routes. MuJoCo/Python, Rapier/Rust, and
Godot/Jolt/GDScript collectively preflight `11` identities, execute `15`
canaries, reject `48` mutations, and refuse all `3` physical commands before
model construction. Both frozen evaluator CLI commands now execute against
their exact distinct consumer prefixes, eliminating the untested wire seam
that consumed R23D9.

This does not move Checkpoint 1 beyond `10/25`: no R23D10 physical worker,
production evaluator, supervisor, model, world, turning result, or equivalence
result exists yet. The next turning checkpoint is the production-shaped
worker/evidence/supervisor implementation under a complete zero-world gate,
then a clean pushed freeze and exact-source full-Godot attestation before
physics. Canonical prone-to-standing remains the next first-release movement
primitive after portable turning; formal three-engine comparison, the real-
physics Explorer, packaging/distribution, and the remaining support/robustness
gates remain open. The optional adaptation interface and Tier 2 architecture
remain implemented and unchanged.

## 2026-08-09 release-path update: R23D10 production evidence stage passes

R23D10 now has a production-shaped zero-world evidence layer. Its canonical
trace retains all `2,992` controller steps and all `900` terminal steps for
exactly `3,892` rows per cell. All `11` declared identities are written as
canonical NDJSON, copied into content-addressed storage only after digest and
length checks, reopened from retained bytes, and independently replayed through
the frozen taper oracle. The evaluator covers the two-cell selector and the
conditional ordered nine-cell three-engine aggregate.
It also requires create-only trace staging, the digest-derived CAS path shape,
and one exact expected source commit across all evaluated reports.

The combined gate passes `14` tests, including selected and valid-`NONE` paths,
taper deadline/reset/contact-loss negatives, artifact and report tamper
refusals, identity/order/duplicate refusals, and both actual stage-specific CLI
commands with the forbidden generic marker absent. This closes an evidence-
implementation gap only: physical workers, supervisor, models, worlds, turning,
and equivalence remain absent. Checkpoint 1 therefore stays `10/25`; the next
turning work is the dormant physical execution layer and its complete zero-
world gate, followed by a clean push and exact-source attestation. Canonical
prone-to-standing remains the next movement primitive after portable turning.
The exact zero-world evidence layer is clean-pushed and immutably audited at
commit `94f724adecd1ab6d95339dc8a3224fad2a2d586d`.

## 2026-08-09 release-path update: R23D10 dormant physical layer qualifies

R23D10 now has real, dormant production workers for MuJoCo, Rapier/Parry, and
Godot/Jolt plus one serialized supervisor. Every worker emits the same exact
`3,892`-row retained trace and applies the taper scale in canonical coordinates
before its engine-specific host mapping. The supervisor freezes and
content-addresses source, runtime, and external-host inputs; opens both
MuJoCo Stage A cells serially; launches the ordered nine-cell Stage B only
after an exact valid selection; retains process bytes before marker
interpretation; and seals any consumed infrastructure exception.

The complete exact-staged-byte zero-world gate passed in `165.7 s`. It covered all three
workers, the exact `2 + 9` campaign topology, all `44` declared production
dependencies with `44` removal controls, `15` terminal-marker cases, `10`
production evaluator tests including the exact trace-retention CLI seam, the
authorization-runner command shapes, and the direct physical-bypass refusal.
It launched zero physical processes and
constructed zero models or worlds.

This advances turning to the clean-freeze boundary, not to a physical result.
Checkpoint 1 remains `10/25`; command-conditioned turning, formal cross-engine
equivalence, and canonical prone-to-standing remain false. The next legal
sequence is clean commit and push, source-exact full-Godot attestation, all six
production authorization canaries, and only then the one-shot serialized
R23D10 Stage A. If the selector opens and all nine Stage B cells pass, portable
turning can be interpreted and canonical prone-to-standing becomes the active
movement primitive. The adaptation interface and Tier 2 architecture remain
implemented and unchanged.

## 2026-08-09 release-path update: R23D10 closes valid-none

Clean source `c7e9510e12609ce71170736e3328bd782dc16ef2` passed full Godot-
inclusive conformance and all six production authorization canaries. Both
serialized MuJoCo Stage A cells then completed with exact `3,892`-row traces
and correctly signed yaw. The positive cell passed walking plus confirmed
taper-to-passive support. The negative cell did not confirm quiescence before
the `540`-step active deadline and lost contact for `97` passive steps after
the forced handoff. The frozen selector returned `valid_none_stage_a` and
opened none of the nine three-engine confirmation cells.

Checkpoint 1 therefore remains `10/25`. R23D11 is the next turning successor
and must add a direction-neutral observed-state residual-motion dissipation
phase without regressing the positive arm or zero-command straight walking.
Portable turning, formal equivalence, and canonical prone-to-standing remain
false; prone-to-standing still follows accepted portable turning on the
checkpoint path. The optional adaptation interface and Tier 2 architecture are
unchanged by this finite negative.

## 2026-08-09 release-path update: R23D11 stage zero

R23D11 now has a prospective zero-world freeze. It retains every R23D10
physical threshold and the two-MuJoCo-plus-conditional-nine topology, but
changes active terminal actuation by retaining the SDK's preexisting portable
support-centroid and tilt correction while acquiring and tapering the neutral
pose. No gain was tuned to R23D10 and the composition cannot inspect direction
or outcome identity. Seven pure canaries and `18` mutations pass; there are no
native R23D11 routes or physical worlds. Checkpoint 1 remains `10/25`, with
accepted portable turning still preceding canonical prone-to-standing.

## 2026-08-09 release-path update: R23D11 stage one

R23D11 now has independently executable MuJoCo/Python, Rapier/Rust, and
Godot/Jolt/GDScript composition mirrors. Across `11` declared identities they
pass `21` composition canaries, reject `54` malformed-input mutations, recheck
`15` inherited temporal canaries, and refuse all three physical commands before
any model or world can exist. The stage-zero bytes are separately closed at
clean pushed commit `40ebd67d3a1936be23a9ee6d1a6761e931dfb5d8`.

This advances turning from pure design to three-engine native implementation,
but not to a physics result. The next boundary is dormant physical-worker,
trace/evaluator, CAS, authorization, and serialized-supervisor integration under
a complete zero-world gate. Checkpoint 1 remains `10/25`; portable turning,
formal equivalence, and prone-to-standing remain false. The optional adaptation
interface and Tier 2 architecture are unchanged.

## 2026-08-09 release-path update: R23D11 stage two

The immutable stage-one native-route boundary is retained at clean pushed
commit `9686045903c3e6ccaf237276526c52c7862e67d2`. R23D11 now has a production-
shaped evidence boundary for all `11` declared cells. Each cell retains the
complete `3,892`-row trace in content-addressed storage before terminal
interpretation, replays the inherited temporal handoff independently, and
validates the stability-assisted composition and typed safe-zero behavior.

The trace adds six prospective diagnostics without adding an outcome
threshold: task-frame forward, lateral, and yaw velocity; minimum dynamic
support margin; planning availability; and the eight ordered applied stability
deltas. Seven trace tests and `11` evaluator tests pass, including diagnostic-
rewrite and real CLI-consumer controls. This is evidence-path qualification,
not physical turning. Checkpoint 1 remains `10/25`; turning, equivalence, and
prone-to-standing remain false.

## 2026-08-09 release-path update: R23D11 dormant physical routes

The immutable stage-two boundary is retained at clean pushed commit
`166845a67ed0a166cff789b691c76173d85e796b`. R23D11 now has dormant production
physical workers for MuJoCo, Rapier/Parry, and Godot/Jolt. A `49`-path
dependency closure, `15` terminal-marker cases, six authorization canaries,
content-addressed trace publication, the authoritative `11`-test evaluator,
and one serialized two-plus-conditional-nine supervisor are integrated behind
a complete zero-world gate.

That gate binds `99` exact source paths and four external runtimes and exits
successfully with zero physical process launches, model constructions, world
attempts, or world builds. Before any physics, the verifier also prospectively
clarifies that passive planning availability is null, passive support margin is
finite only when a qualified support set exists and otherwise null, and passive
stability deltas remain exact zero. This changes no physical threshold or
decision rule.

The next legal boundary is reviewed conformance, a clean commit and push with
live remote equality, fresh full-Godot source attestation, and all six
production authorization canaries. Only then may the supervisor open the two
serialized MuJoCo Stage A worlds. Stage B stays closed unless both signed arms
select the declared policy. Checkpoint 1 remains `10/25`; turning, formal cross-
engine equivalence, canonical prone-to-standing, physical acceptance, and
release remain false.

## 2026-08-09 release-path update: R23D11 closes infrastructure-invalid

Clean pushed source `2477b6bece55a31257b1306a64330f59633b6c58`
passed full Godot-inclusive conformance, source-exact V2 attestation, and all
six production authorization canaries. The eligible one-shot attempt consumed
both serialized MuJoCo Stage A worlds and retained two complete `3,892`-row
traces. Both traces were rejected for exactly one diagnostic-semantics class:
the producer retained an independently measured finite support margin while
planner availability was `observation_unavailable`, whereas the frozen
validator required the margin to be null in that state. The selector returned
`INVALID`, and Stage B remained `0/9`.

This is an infrastructure-invalid completion, not a turning success, turning
negative, worker crash, or GPU crash. R23D11 is consumed and cannot rerun or be
post-hoc salvaged. Distinct R23D12 must prospectively separate planner
availability from independently measured support-margin availability before
fresh worlds can open. Checkpoint 1 remains `10/25`; portable turning, formal
cross-engine equivalence, canonical prone-to-standing, physical acceptance,
and release remain false. The optional adaptation interface and Tier 2/Tier 3
roadmap are unchanged by this finite infrastructure result.

## 2026-08-09 release-path update: R23D12 stage zero

R23D12 is frozen under a fresh implementation-recovery identity at commit
`6116fcef7c28c3bc91d2ad115dca61b9a97bfb0a`. It preserves the complete R23D11
physical policy and decision contract but adds an explicit
`minimum_dynamic_support_margin_availability` field. Planner availability now
controls only whether stability correction must fall back to exact zero;
support-margin availability independently controls whether the signed margin
is finite or null. The pure oracle passes seven canaries, including all six
active planner/margin availability pairs and the exact R23D11 failure shape,
and rejects fourteen malformed or recoupled variants.

This is design/evidence-semantics authority only. There are zero native routes,
workers, evaluators, supervisors, models, or worlds. Stage one must implement
the schema independently across MuJoCo, Rapier, and Godot/Jolt before a later
clean-pushed, source-attested physical implementation can open fresh worlds.
Checkpoint 1 remains `10/25`; turning, equivalence, prone-to-standing, physical
acceptance, and release remain false. The adaptation checkpoints are unchanged.

## 2026-08-09 release-path update: R23D12 stage one

Stage one is frozen at commit
`f5c686e94c4702cac9a8aadcbcc3e42e2bb83bbb`, tree
`0a6a540a8faca16813a5225596d95fbfe4593fdb`. Three independently authored
native-language mirrors now implement the stage-zero schema in MuJoCo/Python,
Rapier/Rust, and Godot/Jolt/GDScript. Each passes seven valid canaries, all six
active planner/margin combinations, fourteen exact mutation refusals, and the
critical R23D11 shape. The valid and cross-product semantic vectors match
exactly across all three languages.

This closes only native diagnostic semantics. Each route refuses physical
execution before model/world; no production trace validator, publisher,
physical worker, evaluator, supervisor, model, or world exists. The next
release-path boundary is the production evidence layer, followed by a separate
physical implementation and authorization freeze. Checkpoint 1 remains
`10/25`; turning, equivalence, prone-to-standing, physical acceptance, and
release remain false. The adaptation checkpoints are unchanged.

## 2026-08-09 release-path update: R23D12 stage two

The production evidence layer is frozen at commit
`7d71a4d5b39bab8756e639247e70216ca104269a`. It provides the 35-field,
3,892-row-per-cell trace schema, explicit independent planner/margin
availability validation, CAS-first publisher, and cold evaluator for all
eleven conditional campaign identities. Twenty tests cover the complete
synthetic producer/validator path, all availability states, inherited temporal
and outcome replay, selected/`NONE`/invalid aggregates, exact CLI markers, and
retained new-field tampering. The immutable closure binds eight source blobs
and proves zero physical workers, models, and worlds at this stage.

This removes the production-evidence gap but does not move the release score.
Next is the separately frozen dormant three-engine physical implementation,
dependency/marker closure, authorization canaries, and serialized supervisor,
all qualified at zero worlds before any clean-pushed physical attempt.
Checkpoint 1 remains `10/25`; turning, equivalence, prone-to-standing,
physical acceptance, and release remain false. The adaptation checkpoints are
unchanged.

## 2026-08-10 release-path update: R23D13 stage zero

The next turning successor is now frozen as a zero-world design. R23D13 retains
the existing whole-body neutral-plus-stability terminal command but gives it a
measured residual-pose authority floor, preventing the time-only taper from
collapsing control while supported tilt or joint error remains outside the
unchanged tight pose. The law has no arm/sign branch, no fitted gain, no new
decision threshold, and no passive reactivation. Ten canaries and twenty
mutation controls pass; native routes and physical worlds remain zero.

This advances Checkpoint 1's portable basic-turning implementation path but
does not change its `10/25` score or any release claim. Independent MuJoCo,
Rapier, and Godot/Jolt mirrors, production evidence, clean-pushed attestation,
and the bilateral physical selector remain future gates. The debugger,
prone-to-standing, packaging, optional adaptation-provider interface, and Tier
2/Tier 3 roadmap are unchanged and remain required.

The R23D13 source-family byte rules are clean-pushed at `a0872c6`, and the
canonical no-Godot suite passed in `1710.9464222 s` with zero R23D13 worlds.

## 2026-08-10 release-path update: R23D13 stage one

Checkpoint 1's turning path now has independent zero-world implementations of
the frozen residual-pose authority law in Python/MuJoCo, Rust/Rapier, and
GDScript/Godot-Jolt. All three agree exactly on ten canaries and twenty ordered
mutation refusals and reject their physical command before model creation.
The immutable stage-zero tree is separately audited, and CEP1 now reports
`92` audits, `74` pinned-blob signatures, and zero live historical risks.

This removes the native-transcription gap but does not change the `10/25`
release score. R23D13 still needs its production evidence layer, dormant
workers, clean pushed qualification, source-exact full-Godot attestation,
authorization canaries, and prospective bilateral selector. The debugger,
canonical prone-to-standing, packaging, optional adaptation-provider surface,
and Tier 2/Tier 3 commitments are unaffected and remain required.

The final prospective stage-one worktree passed canonical no-Godot conformance
in `3142.463 s`, including the 50-entry workbench and all 33 classified release
gates, with zero R23D13 models or worlds and no physical authorization.

## 2026-08-10 release-path update: R23D13 stage two

Checkpoint 1 now has the production evidence and selector layer needed to
observe the residual-pose authority law honestly in all three adapters. The
`51`-field trace binds command-time feedback to the preceding post-step row,
replays the temporal state and authority floor independently, preserves both
ordered eight-actuator vectors, retains exact-zero passive behavior, and uses
CAS-first publication before a terminal report can exist. Eleven trace tests
and twelve evaluator tests pass without constructing a model or world.

This removes the evidence-transport gap but does not change the `10/25`
release score. Dormant workers, dependency and marker closure, clean-pushed
qualification, source-exact full-Godot attestation, production authorization
canaries, and the serialized bilateral selector remain ahead. The debugger,
canonical prone-to-standing, packaging, optional adaptation-provider surface,
and Tier 2/Tier 3 commitments are unchanged. Once R23D13 reaches an honest
positive, `NONE`, invalid, or incomplete closure, the program must pause before
opening another series so the research process can be revised.

Canonical no-Godot conformance passed the prospective stage-two boundary in
`1660.858 s` with `51` safe workbench entries, `33/33` classified release
gates, and zero R23D13 models or worlds.

## 2026-08-10 release-path update: R23D13 physical closure and process pause

R23D13 is consumed and closed as `valid_none_stage_a`. Its two serialized
MuJoCo Stage A cells both produced complete execution-valid traces, walked
forward, and yawed with the requested sign. Positive passed the complete
walking-plus-quiescent-taper outcome. Negative failed only
`R23D13_QUIESCENT_TAPER`, so the selector chose `NONE` and Stage B remained
unopened at `0/9`.

The retained negative trace improved through its final active row while all
four contacts remained present: tilt fell from `0.0204353485` to
`0.0170804079 rad` and joint error from `0.2383445018` to `0.2079429633 rad`
over the final 120 active rows. That narrows the design problem but does not
select a gain, horizon, floor shape, or terminal target change. The inherited
`0.01 rad` tilt and `0.20 rad` joint-error gates came from thin retained R23D9
development calibration; they are neither population-calibrated nor an
unrecorded guess.

The exact closure remains
[`../sdk/turning/r23d13_physical_closure_v1.json`](../sdk/turning/r23d13_physical_closure_v1.json).
The next legal work is the zero-world process commissioning in
[`LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md` §111](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#111-post-r23d13-process-acceleration-without-weaker-evidence--2026-08-10).
No movement successor, physical series, or changed release claim is authorized
by this roadmap update.

## 2026-08-11 release-path update: R23D14 dormant physical implementation

Checkpoint 1's turning path now has one complete dormant direct-matrix
implementation across Godot/Jolt, Rapier/Parry, and MuJoCo. The three native
workers use real physics, share the exact `3,952`-row evidence contract, and sit
behind one serialized nine-cell supervisor with CAS-before-interpretation
retention. The clean-pushed control-plane freeze is
`71f6e8910d27b5b8b832ec25f4886779138923d6`; its complete zero-world gate passed
`70` dependency removals, `15` terminal-marker cases, all three worker
preflights, seven evaluator tests, and physical-bypass refusal in `373.4 s`
without constructing a model or world.
The authority-only contract update re-passed that complete gate in `481.7 s`
with unchanged counts and zero worlds.

This removes the dormant-worker and supervisor implementation gap but does not
change the `10/25` release score. The nine physical confirmation cells remain
unopened pending source-exact attestation, production authorization canaries,
and the opening decision. Portable turning still requires the complete matrix
outcome; canonical prone-to-standing, the showcase debugger, clean-room
packaging, optional adaptation-provider interface, and Tier 2/Tier 3 roadmap
remain separate required work.

## 2026-08-11 release-path update: R23D14 consumed invalid

The nine-cell R23D14 confirmation identity is now consumed. MuJoCo produced
three execution-valid walking, taper, passive-stability, and signed-yaw cell
positives. Rapier's three cells refused before world construction at an
inherited stage-identity seam, while Godot/Jolt's three real-physics processes
failed during post-handoff terminal-summary construction. With six mandatory
cells execution-invalid, the complete matrix establishes neither a positive
nor a negative turning result and does not change the `10/25` release score.

The closure and audit are
[`../sdk/turning/r23d14_physical_closure_v1.json`](../sdk/turning/r23d14_physical_closure_v1.json)
and [`../tests/test_qsdk_r23d14_closure.ps1`](../tests/test_qsdk_r23d14_closure.ps1).
R23D14 cannot rerun. The turning path now requires a separately frozen
implementation-recovery successor with exact production-composition canaries.
Prone-to-standing, the showcase debugger, clean-room packaging, adaptation
interfaces, MJX Warp development, and Tier 2/Tier 3 remain unchanged product
requirements rather than being displaced by this infrastructure result.

## Turning track after R23D14

R23D15 is the active prospective turning successor. Its first boundary repairs
only the exact Godot terminal-summary and Rapier inherited-stage composition
seams that invalidated R23D14; it leaves the locomotion policy and finite
three-engine question unchanged. Its clean-pushed stage-zero source is now
immutably closed with the runtime/compiled canaries passing. A prospective
stage-one evidence layer adds distinct trace/report identities, direct
nine-cell evaluation, and content-addressed retention while importing the
R23D14 temporal oracle unchanged. Its `13` tests pass with zero worlds; the
exact source is clean-pushed at `7217faa`, tree `187a540f`, and independently
closed over `16` effective Git-blob bindings. No R23D15 worker matrix or
physical authorization exists yet. This keeps portable basic turning on the public-SDK
critical path without detouring into adaptation training, MJX scale-up, or
broader morphology before the baseline quadruped release gates close.

## 2026-08-11 release-path update: R23D16 zero-world qualified

R23D15 remains consumed and invalid; its valid MuJoCo subset cannot rescue the
six evidence-pipeline failures. R23D16 preserves the exact scientific question
and repairs only the observed production seams: Godot now routes the current
trace schemas through the live independent-support-availability projection and
retains diagnostic-only trace-failure detail, while Rapier invokes the exact
pinned CAS publisher with an explicit child `ExecutionPolicy Bypass`. A
hostile inherited `AllSigned` control reproduces the old refusal and passes
through the repaired route.

The complete R23D16 zero-world gate passed in `551.8 s`: reproducible runtime
materialization, four external-runtime bindings, the immutable R23D15 closure,
`76` dependency removals, `15` marker cases, all three worker preflights, and
all `8` evaluator tests passed with zero physical processes, models, attempts,
or worlds. A clean push, source-exact full-Godot attestation, and production
authorization canaries remain mandatory before the single nine-cell matrix.
The Checkpoint 1 score stays `10/25`; turning, equivalence, prone-to-standing,
and release remain false until their own physical gates close.

The first `ad89cde1` full-conformance attempt failed closed before attestation
or physics because CEP1 had not registered the R23D16 source-family LF rules
as a non-migration extension. The exact failed receipts are retained, all
world counters are zero, and the repair changes only CEP1's prospective rule-
extension registry and executable diff/live controls. This does not change
the `10/25` release score or any movement claim; fresh clean-source attestation
is still required.

## 2026-08-11 release-path update: R23D16 consumed invalid

R23D16 later passed exact-source full-Godot qualification and consumed its
nine serialized worlds. MuJoCo again produced three valid finite walking,
taper, and signed-yaw cells. Godot/Jolt completed all three worlds but the live
terminal R23D13 authority-input predicate rejected all terminal rows. Rapier
completed all three worlds and traces, but the child publisher rejected the
Windows extended-path spelling of the repository root. The complete matrix is
execution-invalid, so the Checkpoint 1 score remains `10/25`; portable turning,
cross-engine equivalence, prone-to-standing, and release remain false.

The closure pins all evidence and forbids an R23D16 rerun. A future successor
requires exact live-composition canaries for the entire Godot predicate and
Rapier `\\?\` path normalization. Per Cole's process instruction, that physical
successor is paused until the process changes are discussed. This closure does
not detour the product path into adaptation training, MJX campaigns, or broader
morphology.

## 2026-08-11 release-path update: R23D17 closure and LCA1 process successor

R23D17 completed all nine serialized real-physics worlds and every worker
retained a complete `3,952`-row trace. That directly fixes R23D16's Godot live
composition and Rapier extended-path publication seams. The matrix remains
invalid because Godot serialized three correct receipt byte lengths as JSON
reals while the frozen evaluator requires exact integers. Rapier's three cells
are execution-valid outcome negatives—reference and positive fail quiescent
taper, and negative also fails stability/contact gates—while MuJoCo repeats
three walking, taper, and signed-yaw positives. R23D17 cannot rerun and does not
advance the `10/25` release score, portable turning, equivalence, prone-to-
standing, or release authority.

LCA1 now implements the proof-preserving process shortcut needed before a
corrected successor: the permanent `12`-gate Godot-inclusive safety kernel plus
only the successor's lineage and exact worker/evaluator/supervisor controls,
with timed CAS-retained streams/receipts, source/toolchain bindings, create-only
output, and zero claims. Its focused implementation gate passes, but it remains
uncommissioned until one same-source full-Godot V2 baseline and production
scoped run are retained and compared. This is product-path acceleration, not a
new feature gate: Checkpoint 1 still requires a distinct corrected turning
successor, canonical prone-to-standing, the showcase real-physics Explorer,
interaction/recovery, packaging, documentation, and its other release gates.

The first LCA1 cold pair produced useful negative evidence before R23D18. Full
V2 passed in `2100.9241034 s` and scoped LCA1 passed in `106.401997 s`, but the
full runner omitted all three exact campaign-role checks used by the scoped
manifest. That failed commissioning's declared subset proof despite zero
worlds and successful exit codes. The bounded repair adds those three checks
and retains the negative; one new same-source cold pair is still required.
Consequently the approximately `19.7x` observed process reduction is not yet a
physical-launch permission, and the `10/25` Checkpoint 1 score is unchanged.

The next full run passed at `b16dbf3f`, but PowerShell's parent transcript did
not retain output written directly by the nested role-check processes. That
second process negative stopped before scoped execution. The runner now
captures and re-emits child output through the parent host and canaries the
exact retained marker, but one new cold pair is still required. This remains a
short-path infrastructure repair; the release score and all movement claims
are unchanged.

LCA1 commissioning now passes at `655d425b`: full `8/8`, scoped `16/16`, exact
marker vector `1/1/1/1`, `48` scoped CAS objects verified, and a measured
`14.3676x` duration ratio. This removes the repeated full-history sweep from a
future campaign's critical path after a separate adoption composer is added.
It does not change the `10/25` release score or establish turning, recovery,
equivalence, packaging, Explorer, adaptation, or release claims.

## 2026-08-12 release-path update: turning through R23D25

R23D18 through R23D20 repaired the three-engine trace/evidence path and exposed
a real Godot/Jolt reference-oscillation mechanism. R23D21 changed only the
portable yaw-error stride gain from `1.3` to `1.0` and closed a finite positive
three-cell Godot/Jolt turning candidate. R23D22 and R23D23 then repaired the
Rapier/MuJoCo transfer seams without rerunning Godot. The final R23D23 evidence
is mixed: Rapier's three reports are execution-valid negatives, while MuJoCo's
three terminals were implementation-invalid.

Post-closure receipt diagnosis produced a full real-receipt mutation gate, and
R23D24 reopened only the invalid MuJoCo cells. All three then evaluated valid;
the two commanded arms passed every frozen gate, while the reference failed on
seven isolated late-passive front-right contact losses. R23D25 changed only the
terminal desired-forward command to exact zero and proved that change through
all `1,510` affected real controller receipts. It repeated the same seven
losses, closing a second valid complete negative and disproving terminal
forward intent as a sufficient cause.

R23D26 was that distinct Rapier successor, not a rerun or threshold relaxation.
It ran every cell and selected `NONE`: `0.10` was stable but ineffective,
`0.20` was a stable command-conditioned near miss, and `0.30` restored the
fall. Its final runtime came from `201` Git-blob-exact, CAS-retained source
bindings after the pre-world gate exposed four Windows checkout mismatches.
MuJoCo still requires a separately justified support/contact interpretation or
mechanism study. The commissioned LCA1 path qualified R23D26 through its own
R23D23/R23D25 lineage, permanent kernel, and exact campaign controls without
rerunning unrelated historical closures.
The release score stays `10/25`; prone-to-standing, formal equivalence, the
showcase Explorer, adaptation, and the other public-package gates remain open.

## 2026-08-12 release-path update: predictive Rapier stability direction

R23D27 preserved walking in its reference but both signed Rapier arms fell;
its observable tilt-only fallback reacted after destabilizing roll was already
accumulating. A clean-pushed, CAS-only diagnosis now closes the immediate
mechanism question: a one-scheduler-swing (`0.6 s`) tilt projection reaches the
unchanged minimum-authority boundary before the old guard reacts in both failed
directions across four simultaneously reported middle windows, while the
reference never reaches that boundary. No window was selected post hoc and no
counterfactual recovery is claimed.

R23D28 implemented that exact engine-neutral state-frame predictor and ran all
three fresh serialized Rapier worlds. The reference again passes, but both
commanded arms fall and the positive arm turns in the wrong sign. All `8,976`
predictive receipts are valid; the mechanism fires before actual tilt crosses
`0.10 rad`, then repeatedly restores full authority while the fall develops.
The finite development result is therefore negative with no selected
candidate.

The zero-world persistence diagnosis over R23D28's immutable CAS traces is now
closed. Its complete scheduler grid is `72, 144, 216, 288, 360`
steps. The one-swing hold leaves `25` and `32` pre-crossing reopenings; two
swings is the smallest declared duration leaving none, while the reference
never triggers the floor. Report
`sha256:6ed95b4d2095427d13eaea17d84f3749a79b37f6c2d178224d25d2f6ddda1d6d`
and its closure support only a distinct stateful development policy and fresh
physical identity. It does not change the `10/25` score;
turning, equivalence, prone-to-standing, Explorer, packaging, and release gates
remain open.

R23D29 is the resulting fresh development identity: the same portable
predictor plus a versioned two-swing (`144`-step) floor-hold countdown and a v3
transition receipt. Independent zero-world oracles validate trigger, refresh,
persistence, expiry, and malformed-memory refusal. The exact three Rapier
worlds remain a development screen; success would select a distinct validation
candidate, not establish turning by itself.

R23D29 is now physically closed. Its persistent guard is independently valid
on all `8,976` retained rows, and all three Rapier cells remain upright while
walking `1.922683-1.943467 m` with four contact cycles per limb. This retires
the immediate commanded-fall symptom in the finite matrix, but not the
turning requirement: positive passes, while negative produces only
`0.00029444164763026137 rad` of reference-conditioned response against the
frozen `0.01 rad` minimum. The development selector is `NONE`; no validation
candidate or follow-on series is open. The release score remains `10/25`, and
turning, equivalence, prone-to-standing, Explorer, packaging, adaptation, and
release gates remain open.

The closed R23D29 directional-response diagnosis now separates missing
authority from response retention. Both commanded arms receive correctly
signed requested steering on all active rows and reach conditioned peaks near
`0.04 rad`; negative crosses the frozen threshold, peaks at
`0.039542539075027736 rad`, then regresses almost completely before the final
sample. Complete-cycle terminal means exceed `0.01 rad` bilaterally, but they
are post-outcome development observations, not a replacement acceptance
metric. The next turning work therefore needs a distinct portable measurement
contract with an independently scheduler-derived estimator and fresh held-out
validation conditions before deciding whether any controller change is still
needed. No estimator, controller, or physical series is currently selected,
and the release score remains `10/25`.

R23D30 prospectively tested that scheduler-derived complete-cycle estimator on
fresh Rapier seed `21504` without changing the R23D29 controller. All three
cells again walk safely; both complete-cycle conditioned magnitudes clear
`0.01 rad`. The stricter all-five-swing condition fails because positive swing
two is wrong-signed relative to reference. The measurement-validation selector
is `NONE`, R23D30 is consumed, and no successor series is open. The public SDK
score remains `10/25`; turning, equivalence, prone-to-standing, Explorer,
packaging, adaptation, and release gates remain open.

R23D31 is now immutably closed as the narrow positive follow-up, not as a rerun.
It kept the same controller, physics, schedule, physical gates, and `0.01 rad`
cycle-level development floor, used fresh seed `21505`, and ran exactly three
serialized Rapier worlds. All three walked safely and both complete-cycle
bilateral gates passed; phase-window reference dominance remained false as a
retained nonselecting diagnostic. This advances finite Rapier cycle-integrated
measurement validation only. The public SDK score remains `10/25`, while
turning, equivalence, prone-to-standing, Explorer, packaging, adaptation, and
release remain open. The identity is consumed.

R23D32 is now the frozen replication successor. It changes only the fresh
held-out Rapier initial condition to seed `21506`; the safe R23D29 controller,
R23D31 estimator, schedule, commands, physical gates, and `0.01 rad`
development floor remain exact. Its focused production-shaped zero-world gate
passes without opening a model or world. After clean push and scoped LCA1
adoption, exactly three serialized worlds may run. A positive advances finite
Rapier turning only; the public SDK remains `10/25`, and native portable
turning, equivalence, prone-to-standing, Explorer, packaging, adaptation, and
release remain open.

The first R23D32 scoped qualification failed before physics when CEP1 rejected
a campaign-specific checkout-filter addition that moved the frozen global
migration boundary. The retained incident contains zero processes, models, or
worlds and does not consume the physical identity. The corrected source removes
only that nonessential path rule while retaining Git-blob-exact source
materialization; a new clean push and full scoped qualification are required.

R23D32 is now immutably closed positive after that corrected qualification.
Exactly three fresh-seed Rapier worlds ran; all walked safely and both
predeclared raw and reference-conditioned complete-cycle gates passed in both
directions. With R23D31, this provides two independently held-out positive
fixtures and advances the roadmap from measurement validation to bounded
finite Rapier turning. The public SDK score remains `10/25`, because the
release gate requires the same prospectively bounded command-conditioned
behavior on every advertised engine. Native Godot/Jolt and MuJoCo turning,
portable turning, formal equivalence, prone-to-standing, Explorer polish,
packaging, adaptation, and release remain open. The one-shot identity is
consumed and no new physical series is open.

## Current turning-to-recovery checkpoint — 2026-08-14

Later retained work supersedes the R23D32 snapshot above without changing its
result. Rapier has bounded finite turning positives; MuJoCo has a bounded
turning positive in the shared lineage; Godot/Jolt has strong walking evidence
but no accepted turning result. R51 added one exact Godot/Jolt reference
walking world before a supervisor schema mismatch consumed its incomplete
matrix.

R52 prospectively repaired that schema boundary and then completed all three
real Godot/Jolt arms from qualified, adopted source. The repair worked and all
three worlds passed every common walking/stability gate, adding `8,976`
retained trace rows and three finite exact-condition walking positives. Turning
closed validly negative: the negative-heading arm responded in the wrong
direction even at a zero floor, so the segment-origin reanchor mechanism was
not selected and a threshold-only retry is unsupported.

R52 is consumed. The later retained-trace diagnosis showed that its step-zero
origin latch changed the nominal common warm-up, so R23D53 opened a
scientifically distinct warmup-preserving command-onset successor. The new
policy binds the initial schedule without moving the origin, holds the fixed
origin through step `599`, and first reanchors at step `600`; local zero-world
worker/evaluator/supervisor gates passed. Its first clean-pushed qualification at
`64a84ef` failed closed at CEP1 before any world because the four new LF rules
were not yet registered; the retained verifier-only repair changes no physical
input. Repaired source `6e200c4` then passed all `18` scoped gates under the
exact commissioned runtime, was adopted, and ran all three serialized worlds
exactly once. Every arm passed the common walking gates, retained `2,992` rows,
and had zero torso-ground contacts.

R23D53 nevertheless closed validly negative for turning. The raw signed gate
passed, but the negative command produced only `-0.0532672479719114 rad` versus
reference drift of `-0.09942303053658974 rad`, so its reference-conditioned
effect was a wrong-direction `-0.04615578256467834 rad`. The mechanism is not
selected and a threshold-only retry is unsupported. R23D53 is consumed, no
successor is open, and the physical series is paused. Fresh synchronized
MuJoCo/Rapier/Godot turning confirmation therefore cannot begin from this
candidate; canonical portable prone-to-standing also remains unopened. The
public SDK score remains `10/25`. Explorer polish, packaging, the
adaptation-provider release surface, Tier 2 architecture, and the later MJX
Warp training path remain product requirements, not claims established by R52
or R53 work.

The closed post-R53 command-contrast diagnosis narrows the immediate turning
work without changing the `10/25` score. Its clean-pushed zero-world report
`sha256:550a7750d529abcdd19c12a0d00d9fa069b808a20d4c69d3532ba6535199db67`
validates all `8,976` retained rows. The arms match for the complete `600`-step
warmup, desired-heading contrasts remain correctly signed for `1,200/1,200`
turn rows, and reported saturation is zero. The negative arm has `974` correctly
signed held-steering contrast rows but only `556` correctly signed yaw-effect
rows relative to reference. That pushes the next work below the task-origin and
command-transport layers.

No actuator-level mechanism can yet be selected from the consumed R53 rows
because final and applied actuator commands, effort limits, and contact-phase
alignment were not retained there. The prospective Godot/Jolt observation
contract now closes the implementation reachability gap for future rows: it
retains ordered controller targets, host applications/configured readbacks,
compiled impulse limits/configured readbacks, portable/host joint identities,
limb phase, and before/after contact. Its Godot 4.7 gate rejects nine route/row
mutations and a wrong schema at zero worlds. Configured parameter readback is
not measured torque or measured impulse. No R54 or physical successor is open;
the next decision must use this frozen instrumentation only in a distinct,
prospectively classified and adequately justified question.

## Deterministic experience layer — implementation boundary

The next Endpoint 2 source layer is implemented under
[`../sdk/adaptation_provider/experience_encyclopedia_contract_v1.json`](../sdk/adaptation_provider/experience_encyclopedia_contract_v1.json).
It accepts a bounded ordered window of canonical observations and derives a
deterministic threshold-free characterization: duration, forward-velocity
tracking error, maximum absolute torso tilt, minimum torso height, qualified-
contact fraction, fallback fraction, and provider-influence fraction. Exact
descriptor, provider, model, corpus, task, environment, support/OOD, seed,
step, and time identities remain in the receipt.

The adjacent append-only experience store retains canonical content-addressed
objects and create-only parent-bound events. Its finite result vocabulary is
exactly `positive`, `negative`, `rejected`, `invalid`, and `incomplete`; none
may be discarded or silently converted. Duplicate experiences, stale parent
digests, unknown fields, nonfinite or reordered samples, object/event
mutations, and continuation after an orphaned incomplete object fail closed.

This is a development and retention layer only. It applies no outcome
threshold, makes no population inference, does not establish training-data
fitness, cannot promote an encyclopedia chapter or provider, and opens zero
worlds. AEC0-AEC7 pass with nine mutation controls from exact clean pushed
source `ac20bcdbca7d3f76fa01f2024f44d062c298ade7`. The retained report is
`<evidence-root>\adaptation-experience-ac20bcd\report.json`,
`sha256:3d0b20cf97d49b174f68a51c34b98e04726ddecd658ba0601a9a4ab380e891b5`.
The validation manifest and executable evidence audit independently bind the
frozen Git blobs, all five finite result counts, all nine controls, zero-world
execution, and every authority denial. The support matrix therefore promotes
only this source-development fact; training, provider promotion, physical
qualification, online adaptation, and release remain open.

Canonical integration is now observed from exact clean pushed binding source
`34992ff620b2d4361bb798889d54bb3d6c02d662`. The no-Godot cold receipt at
`SporeSpore_Evidence/conformance-runs/20260814T195223Z-34992ff6-7f1fa39d7e4947efa0937cde0cf52adc/receipt.json`
has SHA-256
`665e4ea1361d79131245ebd0a90f82ba07967aa18ade9fcb20a42306e2d3c145`;
all seven executed stages passed and the declared Godot stage was skipped.
This proves composition with the canonical no-Godot source route only. The
receipt is non-transitive, cache/reuse-disabled, and supplies no learned,
physical, population, equivalence, or release claim.

## Score-bearing turning continuation — R23D62 declaration

R23D62 now supplies the prospective path from the current `10/25` score to a
possible `11/25` by targeting `QSDK-R23` directly. It is a **finite decision**
over nine fresh matched worlds: Godot/Jolt, Rapier/Parry, and MuJoCo crossed
with `reference_zero`, `+0.2 rad`, and `-0.2 rad`. All cells use the exact
R23D61-published s169 actuator profile, unchanged R23D60 policy semantics and
gates, and unused seed `23167`. Historical engine positives are retained but
cannot be substituted for any cell.

The frozen cohort is adequate only for the exact deterministic nine-cell
conjunction. The declaration makes no superiority, equivalence/non-inferiority,
repeatability, robustness, continuous-morphology, or population claim. Its
audit rejects `35` mutations and its seed compiler runs at zero models and
worlds. The first retained-evidence evaluator is preserved as a zero-world
negative because its synthetic placeholder actuator IDs reject genuine public-
ID Godot traces. Its distinct evaluator-v2 now passes nine public-ID
full-horizon trace canaries, cold-accepts the exact retained `2,992`-row Godot
trace shape, and rejects `30` task-origin/schedule, `60` actuator-observation,
`48` public-profile/host-binding, `3` trace-cap, `8` finite-decision, and `9`
matrix-order mutations with zero models and worlds. Native
workers, dependency closure, the one-shot supervisor, the complete campaign
zero-world gate, clean-pushed qualification and adoption, all nine serialized
physical worlds, strict retained-evidence execution, and content-addressed
closure are still required.

Consequently the scoreboard remains `10/25` at this boundary. A future
valid-complete positive R23D62 closure may satisfy only `QSDK-R23`, moving the
total to `11/25`; a negative, invalid, or incomplete result earns no point and
remains immutable. R24D10 stays the independent next recovery-development
successor toward canonical prone-to-standing.

## 2026-09-03 SDK1-M20 update: retained solver-divergence diagnostic closes

The current executable scores are now SDK1 `12/20` and full program `12/25`;
the older score immediately above remains the contemporaneous R23D62 boundary.
The future Explorer's diagnostics/provenance surface now has one exact,
content-addressed example to expose. A zero-world retrospective compiler read
the complete retained R23D65 population and compared the only matched pair:
Godot/Jolt and Rapier/Parry `reference_zero`, each with seed `23175`, the same
frozen feedback policy and cap profile, and `2,992` synchronized steps.

The two runs finish `9.831 deg` apart in start-aligned heading and `0.661 m`
apart at the tracked torso reference point. Full-trace RMS separations are
`8.984 deg` for heading and `0.564 m` for the torso point; contact state differs
in `23.54%` of synchronized foot samples. The maintainer bundle publishes every
matched step and all `99` observed contact transitions, explains the alignment
and event-matching rules in plain language, and refuses to invent the two
measurements the old trace schema cannot support: per-step measured joint-angle
RMS and whole-body COM drift.

The exact bundle is
`<evidence-root>\sdk1-m20-r23d65-retained-divergence-cecfda67`
(`6` files, `1,607,556` bytes; manifest
`sha256:4ea979975242953e70196383482614f375b16cec0935750d37fcb3cdc3d03752`).
Its repository authority is the
[retained-divergence closure](../sdk/turning/r23d65_retained_trace_descriptive_divergence_closure_v1.json).
This is one retrospective two-engine zero-command description. MuJoCo is
absent, no engine is declared correct, and no equivalence, population, or
three-engine claim follows. It supplies an M20 design/input artifact; it does
not prove the polished Explorer, alter the stable milestone mapping, or change
a score. No physics process, model, world, native read, historical evaluator,
or solver step ran.
