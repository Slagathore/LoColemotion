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

## Current execution order - 2026-10-22

SDK1 is complete at **20/20** under the October 3 retained receipt; the full
program remains **19/25**. The August sections below are history, not the current
queue. The [master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md) and
[support matrix](../sdk/release/quadruped_support_matrix.json) carry earned
claims. This update claims no new qualification or trained provider.

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
without asserting those contracts passed. The owner reports earlier GPU
rough-draft work contributing to SDK1 recovery; its exact artifact has not yet
been located. It is useful history, not reproduced training qualification.

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
