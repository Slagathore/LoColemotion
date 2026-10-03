# SDK Explorer

The standalone desktop implementation is `showcase.gd`, launched by
`showcase_owner.py`. The owner compiles seeded or edited descriptors through
the native public C ABI. The UI renders a construction preview and separately
renders native worker poses. Exact S169 is the current native launch boundary.
The owner serializes physics with the project operation mutex and contains
each worker in a Windows kill-on-close job before permitting native launch.

The app provides seeded construction, six bounded descriptor edits, orbit/zoom,
wireframe display, native engine selection, native torso impulses, retained
observations, a 1x recorded-pose replay, runtime digests, simulated/wall timing,
and the independently verified finite recovery evidence view. Godot uses the
actual R10AP V28 controller through a separately declared 600-step walking
prefix and 1800-step timed showcase. Its 0.25 N.s kick occurs after setup plus
five simulated seconds. This is a new development observation, not the R10DH
held-out schedule or a new acceptance attempt. Extra Godot impulses are refused.

The [standalone closure](showcase_closure_v1.json) passes SDK1 M20. Fresh native
UI checks from pushed source `54869d5c3ea167219bc329d3092028099e030ae8`
completed 2,041 Godot steps, 2,992 MuJoCo steps (749 published frames), and
3,172 Rapier steps, with one actual impulse in each. Godot selected upright
stabilization and resumed walking. These are interface development observations,
not new physical acceptance or cross-engine recovery equivalence.

The isolated SDK has no Git checkout or game project. Fourteen desktop editing,
camera and labeling checks and fifteen recorded-replay checks passed with no
native launch. The visible UI was reviewed. Eleven closure corruption controls
passed. Recheck with `python sdk/release/check_explorer.py` from the repository;
the SDK1 readiness compiler invokes that auditor before counting M20.
The three package-bound milestones M01/M11/M15 remain open.

Runtime paths are explicit in a local JSON configuration, supplied with
`--config`; `--output` must name a fresh durable directory. Runtime binaries
are external dependencies and are not bundled or redistributed by this source
implementation. `showcase_contract_v1.json` declares the development bounds.

## Run the desktop app

Use Windows PowerShell and a Python 3.11+ executable. Copy
`dependencies.example.json` outside the source tree and supply actual absolute
dependency paths and the full source commit. The MuJoCo Python environment must
have the adapter's locked dependencies installed. The Godot recovery option
requires the exact instrumented engine pair and V28 DLL identified in the
retained recovery route; a stock Godot or newly built V29 DLL cannot replace it.
The standard Godot executable renders the UI independently of that worker.

```powershell
& ./sdk/explorer/open_showcase.ps1 `
    -Config 'C:/your/runtime-dependencies.json' `
    -Output 'C:/your/durable-evidence/explorer-fresh-session'
```

The output directory must be new. Closing the window stops and reaps the native
session. Each native attempt retains its declaration, exact runtime/source
bindings, safety results, original stdout/stderr, original JSON stream, commands,
and terminal receipt. Stop retains an incomplete diagnostic and grants no claim.
The operation mutex prevents overlapping another project's locomotion campaign.

Select a body seed and press **Generate**, or change the six parameters and
press **Apply construction edits**. The real C ABI compiler checks construction
without physics. **Restore native S169** restores the exact worker boundary.
Choose an engine and start a fresh session. Rapier and MuJoCo use their fixed
native startup; Godot additionally accepts an explicit prefix phase. The app
does not advertise arbitrary generated bodies as runnable or proved.

Godot's full diagnostic capture is computationally expensive. The window remains
responsive while the separate process calculates, shows the measured speed, and
offers **Replay at 1x** after completion. Replay creates no physics world and is
explicitly labeled as recorded native poses.

## Relocated recovery sources

`recovery_sources.zip` contains only byte-preserved Godot and MuJoCo project source/resources,
enumerated and hashed in `recovery_sources.json`. It supplies the actual route's
transitive dependencies within the installed SDK; launch never reads the game
checkout. Historical `scripts/` and `tests/` resource names are retained inside
the generated worker project so source hashes and imports remain intact. Native
binaries are excluded. `build_recovery_resources.py` is a maintainer-only
projection utility and is never called by the installed app.

MuJoCo's existing dynamic-library canary expects its C ABI library at the
relocated SDK's `target/release` path. The owner copies the explicitly selected
external library there and verifies identical bytes. The canary remains active.
For repeated launches, the owner also accepts `--evidence-root` instead of
`--output` and creates a fresh UUID directory on every launch.

`native_recovery/` contains the distinct showcase schedule, transport and local
runtime loader. The latter verifies the exact supplied DLL without requiring
the original machine's archived DLL path. Original scientific workers, profiles,
records and physical results are unchanged. The controller inputs and solver
timing are unchanged; rendering and stream observation grant no acceptance.

## Retained recovery evidence component

The SDK-local recovery evidence component presents R10DH's immutable finite
acceptance and keeps the current sandbox's recovery status unproven. It grants
no execution, new physical acceptance or release authority.

`recovery_evidence.gd` reads only the two digest-pinned JSON records below a
supplied SDK root. It never follows the historical absolute paths inside those
records or launches an auditor or physics process. Missing files are unproven;
changed or crossed bytes are ambiguous. A matching retained DLL is reported,
but it cannot prove that a live setup matches the accepted engine, state,
controller and schedule.

`recovery_evidence_panel.gd` renders the six results, finite scope, runtime
identity and current sandbox boundary. The repository workbench includes this
panel. The component also works with an isolated SDK directory containing
`explorer/` and the two explicitly projected `recovery/` records.

The component test runs in Godot with zero physical worlds:

```powershell
& $Godot --headless --path $ProjectRoot --script sdk/explorer/test_recovery_evidence.gd
```

For a relocated SDK layout, invoke the relocated test script and supply
`-- --sdk-root <isolated-sdk-root>`. The test exercises the actual panel,
retained records, missing/crossed/modified records and runtime mismatch.

This original component remains a narrower historical proof. The complete
standalone application is covered by the distinct closure above. Final package
conformance and public release are separate gates.

## Retained implementation findings

The first isolated Godot launch used seven Jolt position iterations at process
startup and ended as a valid stand-up negative at step 300. Matching the original
project's startup setting of four restored the observed trajectory; the inherited
worker still applies its unchanged runtime settings. The fresh successful run
matches the original torso positions and phases through the checked prefix.
The previous negative remains retained. A separate earlier file-sharing refusal
is also retained: display-file contention now coalesces presentation updates
while the original native JSON stream continues to be captured.

The detailed development attempts and current validated local configuration are
under `SporeSpore_Evidence/explorer-build-20261003`. The public source includes
no machine-specific dependency configuration or native binaries.

## Required live interaction

The expanded showcase must run genuine native physics at or near real time and
let the user kick the creature at user-chosen moments during the live session.
Replay and timeline scrubbing are optional inspection tools; they cannot replace
this capability. Godot's current slow diagnostic and prescribed kick schedule
leave the live-interaction requirement open.

The interactive successor must apply bounded user input at the next feasible
native step. Its verification must measure input-to-native-application latency
alongside simulation/wall-clock rate, including during recovery. The existing
60-step diagnostic command lead is not the intended live input behavior. Keep
finite scientific schedules and evidence intact while qualifying the separate
interactive path. A live run does not inherit a historical acceptance label.

## Active studio expansion and measured performance baseline

Cole's active objective extends beyond the original M20 surface: near-real-time
native exploration, genuinely runnable previously untested valid setups, easy
navigation of tested scenarios and their provenance/history, an informative
three-engine comparison with tables and visual aids, then M01/M11/M15 to reach
SDK1 20/20. The existing M20 mark does not establish these additional features.
The controller is deterministic; the product should say **tested and tuned**
rather than imply a trained model where no learned weights exist.

The [first performance baseline](studio/performance_baseline_v1.json) reopens the
three original native streams, verifies their bindings and exports JSON, CSV,
PNG and SVG plots. It creates no worlds. The source compiler is
`studio/build_performance_baseline.py`; Matplotlib is an optional maintainer
analysis dependency, not a new application runtime or bundled binary dependency.

| Retained application route | Simulated seconds | Reported native-loop seconds | Loop real-time factor | Complete physical-session seconds |
| --- | ---: | ---: | ---: | ---: |
| Godot/Jolt R10AP V28 stand-up, kick and recovery | 17.008 | 959.497 | 0.0177x | 983.875 |
| MuJoCo MV6 walk, impulse and terminal hold | 24.933 | 27.637 | 0.9022x | 121.063 |
| Rapier PH1 walk, impulse and terminal hold | 26.433 | 26.427 | 1.0002x | 65.718 |

These are different application schedules and observation loads. They do not
rank engines, establish maximum throughput or prove cross-engine equivalence.
Rapier and MuJoCo explicitly request real-time pacing, so a value near 1x is not
a throughput ceiling. Subtracting loop time from session time gives a residual
outside the loop, not a separately instrumented initialization measurement.

The selected adapters also implement different native interfaces:

| Route | Native mechanism in the inspected implementation | Why the mapping matters |
| --- | --- | --- |
| Godot/Jolt | Instrumented native contacts/energy; V28 recovery route; full staged observation and provenance composition | Its observed 214.109 s energy-composition cost and 117.624 s local-epoch projection cost identify diagnostic work to isolate before blaming the solver. Startup position iterations also changed the actual trajectory in the retained failed integration. |
| MuJoCo | Five 1/600 s native substeps per 1/120 s controller step; velocity targets; accumulated absolute actuator force-time; external impulse as force over the outer step | Applying the same numeric value as force and impulse would be physically different. The adapter integrates force-time against the portable impulse budget and restores external force after the scheduled application. |
| Rapier/Parry | Direct `RigidBody::apply_impulse`; characterized velocity-only host mapping and separate PH1 terminal pose/contact restoration | Its direct impulse API and host motor mapping must be compared at the portable semantic boundary. The walking schedule includes its own terminal restoration and therefore differs from Godot's recovery task. |

Sources: `sdk/adapters/mujoco/sporespore_mujoco_adapter/live_explorer_worker.py`,
`selected_policy_development.py`, `actuator_cap_profile.py`, and
`sdk/adapters/rapier/src/live_explorer.rs`,
`bw19v_velocity_only_pose_hold_restoration_ph1.rs`. Exact executed image and
source identities are retained in the original closure; source inspection is
not a new native result.

**Next implementation priorities:** isolate Godot's per-step diagnostic overhead
without changing solver observations or actuator inputs; measure cold-start
work independently; add the scenario browser and phase/history timeline; add
an explicitly exploratory runtime for valid edited bodies and arbitrary bounded
interactions; qualify that runtime through native checks. The eventual engine
comparison must distinguish matched physical tasks from this unmatched baseline
and explain any remaining engine-specific motor/contact/configuration choices.
The original M20 source/closure and every prior failure stay preserved.

### Prospective edited-body MuJoCo diagnostic

`studio/run_mujoco_sandbox.py` qualifies the descriptor-capable
`studio/mujoco_sandbox.py` entrypoint before any optional `--run`. It reuses the
production bounded compiler, persistent balanced-wave controller, measured
MuJoCo state, canonical velocity composition and five-substep native actuator
mapping. Its host profile is explicitly uncharacterized for edited bodies.

The first declared child is `studio/mujoco_seed42_development_v1.json`: generated
seed 42, fresh clocked startup, 960 outer steps (8 simulated seconds; 4,800 native
substeps), one 0.25 N.s rightward torso impulse at frame 360. There is no paired
effect or recovery claim. One fresh child covers edited model construction,
actual controller/host interfaces, scheduled impulse application, measured
display streaming and retained finalization. It does not cover arbitrary
morphologies, terrains, recovery, robustness or engine equivalence.

The applicable zero-world gate checks native compilation and controller
create/destroy while trapping world construction, rejects crossed/unbounded
inputs, exercises loop limits and cap-failure cleanup using synthetic data,
and runs the existing native ownership/descendant-reaping and stream negative
controls. The coordinator holds the operation mutex throughout qualification
and execution, starts the child only after Windows job containment, rechecks
exact source/native dependency digests, requires a clean pushed physical freeze,
and retains each attempt separately in the durable evidence root. Loop time is
bounded to 120 seconds, owner time to 150 seconds, trace and stream to 256 MiB
each. Full controller requests, mapped actuator inputs and native force-time
readbacks are retained. Native streamed poses are observations; a complete
development observation grants neither physical acceptance nor release authority.

The [first edited-body observation](studio/mujoco_edited_body_observation_v1.json)
retains two fresh runs. The first exposed a one-substep derived-pose publication
lag. Its unchanged record is rejected by `studio/audit_sandbox.py`'s final-pose
check. The successor at `67a6864c` completed 960 steps and one kick, 8 simulated
seconds in 8.0067 loop wall seconds (10.297 s native session), 0.89217 m forward
advance and 0.02610 rad final tilt. The independent audit verifies every actuator
force-time cap and stream/trace population, plus final native/display agreement.
The desktop successor below now exposes this runtime through construction and
interaction controls; the original installed M20 app remains unchanged.

### Studio desktop successor (development interface verified)

**Installed locally:** use `SporeSpore Studio` on Cole's desktop. Each launch
creates a fresh retained session. The [isolated installation checkpoint](studio/isolated_installation_checkpoint_v1.json)
checks all three live engines without a Git checkout or game project. It binds
the exact external runtime inputs and preserves the original Explorer app.

`studio/studio_owner.py` and `studio/studio_view.gd` add edited-body MuJoCo
sessions to the original desktop presentation without changing its accepted
source. Generate or edit a bounded body, select MuJoCo, choose 1–60 simulated
seconds, then start a fresh native session. Direction and magnitude controls
send real torso impulses during the run (at most 16, each at most 8 N.s).
Stop retains the interrupted session and reaps its owned native descendants.
Rapier and Godot still require exact S169. The Godot development integration
uses phase 74, fresh stand-up and 15 seconds of live walking; kicks become
available during walking and apply at the next native step. The full recovery
controller is not yet connected to that faster loop.

MuJoCo button impulses now apply on the next native step after the physics
thread polls the command. The former 60-frame lead is removed from this Studio
path. Cumulative session-bound events preserve acknowledgements even if the
viewer skips an intermediate pose snapshot. The complete applicable zero-world
gate still runs before construction; each live run has a fresh identity.

The [next-step interaction record](studio/next_step_interaction_record_v1.json)
retains a passing real desktop run at `65f216ae`: seed 42, 960 steps, two
opposite 0.25 N.s button kicks, and the independent native/command/UI audit.
Owner-receipt-to-native-application times were 14.7471 and 46.4614 ms; the
separate button-to-observed-application times were 167.569 and 124.308 ms.
Eight simulated seconds took 10.13371 native-loop wall seconds (0.7894x).
These finite observations do not establish a general latency guarantee or
recovery. The preceding UI negative, where the first acknowledgement was lost
despite both impulses being applied, remains retained unchanged.

The [desktop development checkpoint](studio/desktop_development_checkpoint_v1.json)
retains an actual visible UI/native run from clean pushed `11e484fb`: seed 42,
960 steps, one live button-driven kick, 8 simulated seconds in 8.0066 loop wall
seconds and 0.89445 m advance. Its native session took 8.750 s, excluding the
separate safety gate. The full trace audit passed. This is an interaction proof,
not a comparison to the earlier scheduled kick or a recovery acceptance result.

The **Tested scenarios** browser explains six recipes, their history and pinned
source records. Loading a recipe configures the controls without launching a
world. **Load timeline** opens retained native poses with simulated-time seeking,
kick/phase markers and replay; recorded data remains explicitly labeled. The
actual Godot UI test checks recipe selection, engine/body refusals, 241 retained
frames, seeking to frame 480, kick labeling and replay start with zero worlds.
The final graphical test and visual inspection passed with an empty error log.
Earlier UI parse-error, timeout and stale recipe-text findings remain retained
in the checkpoint with their limits.

The Studio successor uses an explicit local dependency configuration.
`studio/materialize_studio.py` projects clean pushed source to an isolated
layout with a complete file digest inventory. The same owner accepts that
checked layout without Git, and `studio/open_studio.ps1` creates a fresh session
for every launch. Isolated UI/native validation and local installation passed.
Faster Godot recovery and a matched engine performance study remain open.
The original installed desktop app and its M20 evidence remain intact. No new
SDK mark or general morphology claim is granted by this checkpoint.

### Prospective Godot context-cache diagnostic

The separate [live walking loop](studio/live_walking_prefix_v1.json) retained
all 360 original body/contact/phase/event samples while its 119-command walking
interval ran at approximately real time. Startup remains slow. The next
bounded native diagnostic can be selected with `--live-walking --walking-steps
1800 --probe-impulses` on `studio/run_godot_cache_diagnostic.py`; it runs the
complete applicable gate before any world and sends two next-step impulses
after observing walking seconds 5 and 10. Original stand-up, contact
classification, walking control and motor bounds remain in use. Recovery
energy ledgers are omitted during this walking loop; it has no transition
back into the recovery controller yet. The desktop calls the same qualified
launcher. The [actual desktop run](studio/godot_desktop_interaction_v1.json)
passed its independent button-to-native-to-display audit: 70.113 and 82.340 ms
button responses, next-step native application, and 1.0030 m world-X advance.
With the viewer running, 15 walking seconds took 21.177442 wall seconds (0.7083x).
The next presentation revision caps viewer rendering at 60 FPS and coalesces
display snapshots to 30 Hz; the complete native stream remains retained.
No acceptance or release authority is granted.

The [capped-viewer observation](studio/godot_paced_desktop_v1.json) passes the
same physical interaction audit but does not establish a speed improvement:
15 walking seconds took 22.499738 s (0.6667x), button acknowledgements took
117.619/135.084 ms, and startup took 46.296796 s. All native data remains
retained. Only display snapshots are coalesced, with measured publication cost.

The [15-second next-step observation](studio/live_walking_impulses_v1.json)
completed 1,800 walking commands in 16.649547 wall seconds (0.9009x), with two
owner-triggered 0.25 N.s impulses applied at steps 842 and 1442. It advanced
1.0790 m along world X, with maximum walking torso tilt 0.076064 rad. Startup
still took 32.448342 s. These are native physical observations of one finite
development run, not a general performance or recovery guarantee.

The [optimized-engine successor](studio/optimized_godot_prefix_v1.json) has now
passed a fresh 360-step phase-74 prefix with the full applicable safety gate.
Its retained body poses, contacts, phases and events match the original prefix.
Three simulated seconds took 36.783772 s, versus 87.758787 s on the earlier
cached engine. The new [runtime pair](studio/optimized_godot_build_v1.json)
keeps development checks/instrumentation and strict floating-point settings,
with explicit compiler optimization. Its 0.08156x rate still does not meet the
live showcase requirement, and this short run contains no kick or full recovery.
Further live execution work is required. The original installed M20 app and
all consumed scientific observations remain unchanged.

`studio/run_godot_cache_diagnostic.py` materializes a separate development
successor from the digest-checked original recovery archive. Its generator
wraps exactly 16 pure context predicates, retaining their unchanged bodies as
the uncached oracle. The canonical original route is never overwritten. The
cache is restricted to the exact native SDK or the known pure serializer
wrapper. Positive object-free inputs are retained as private deeply read-only
snapshots, with bounded size/entry counts. Each hit requires matching owner,
predicate, structural equality and exact native binary representation. Inputs,
observations, actuator decisions, solver inputs and controller steps are not
replaced; negatives always execute the original predicate.

The complete original pre-world gate and 15 synthetic cache boundary checks
precede physics. The actual runtime-context probe adds 110 oracle comparisons
and timing checks. Its qualified zero-world attempt under
`SporeSpore_Evidence/explorer-studio-godot-cache-qualification-20261003-02`
measured 29,099 us for one uncached top-level predicate versus 126,404 us for
100 cached calls. This is an operation-level measurement, not a physical-loop
performance claim. Earlier refusals remain retained; the initial probe selected
a candidate predicate for the base context and therefore refused qualification.

The prospective physical diagnostic uses one fresh phase-74 development world,
at most 360 outer steps and 180 wall seconds, with complete existing observation
capture. It covers startup/stand-up and entry to the walking prefix; its shortened
horizon intentionally ends before the scheduled kick. It is neither a complete
recovery route ghost nor an acceptance population. The owner holds the global
operation mutex, qualifies the exact generated source/runtime bindings, contains
all descendants before launch and requires a clean pushed source freeze.

The [completed shortened diagnostic](studio/godot_context_diagnostic_record_v1.json)
ran from clean pushed `1bd3bf84`. All 360 retained body-pose, contact, phase and
event samples match the original prefix. Its reported prefix clock fell from
173.410345 s to 87.758787 s for 3 simulated seconds (0.03418x real time).
The cache recorded 1,087 hits and 2,899 misses. This is a single retrospective
prefix comparison, not statistical superiority, internal bitwise solver
equivalence or a complete recovery claim. `studio/audit_godot_context_diagnostic.py`
reopens both digest-bound streams and independently checks the sample population.

The next performance work must go beyond context caching. The original retained
engine build command uses `dev_build=yes`, no `optimize` override, and its
corresponding SConstruct maps that default to `none` (`/Od` on MSVC). No
`custom.py` override is present in that dependency checkout. An optimized build
must receive a fresh identity and qualification; keeping `dev_build=yes` while
setting `optimize=speed` first separates optimization from disabling developer
checks. No new optimized engine has been built or measured at this checkpoint.

The 0.018x historical timing measures the instrumented application, not Jolt
alone. Residual profiler time is not an isolated engine benchmark. The MuJoCo
baseline's actual kick was at frame 800 / 6.667 simulated seconds; a slowdown
around 19.7 seconds cannot be attributed to that kick without further evidence.
Most importantly, the energy ledger cannot simply disappear: `core/src/recovery.rs`
validates its residual and includes it in the safety/stable-stance gates. A lean
compiled execution path must preserve those numeric checks and state semantics
while avoiding repeated JSON/provenance composition. Full diagnostic capture
remains the oracle; recorded replay already exists but does not replace the
requested live interactions.
