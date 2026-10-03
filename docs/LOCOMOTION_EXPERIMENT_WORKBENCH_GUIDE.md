# LoColemotion Locomotion SDK and Experiment Workbench Guide

This is the newcomer-facing explanation of the LoColemotion locomotion program:
what we are building, why the work is unusually rigorous, what has actually
been proved, what remains open, how to inspect the proof, and how the final SDK
can become a product other developers and researchers can use.

The short version is:

> We are separating a locomotion controller from any one physics engine,
> defining the exact contract between the controller and an engine, and then
> testing that contract prospectively across creatures, materials,
> disturbances, and engines without allowing a failed result to be rewritten
> after it is observed.

The graphical workbench makes that program inspectable. It is an operator
interface, not evidence by itself.

## Open the workbench

From PowerShell:

```powershell
Set-Location <repo>
pwsh -NoProfile -File scripts\open_locomotion_experiment_workbench.ps1
```

From VS Code Insiders:

1. Open the LoColemotion repository.
2. Open **Run and Debug**.
3. Select **LoColemotion: Locomotion Experiment Workbench**.
4. Press **F5**.

To verify the interface without opening a physics world:

```powershell
pwsh -NoProfile -File tests\test_locomotion_experiment_workbench.ps1
```

Expected terminal marker:

```text
LOCOMOTION_EXPERIMENT_WORKBENCH_AUDIT_PASS engines=4 presets=4 parameters=29 runs=77 physical_runs=0 safe_runphysical_exposures=0 proof_hashes=True worlds=0 attempts_unchanged=True godot_self_test=True safe_process_self_test=True live_physics_preflight=True live_process_self_test=True
```

That marker means the catalog, UI scene, runner classifications, proof paths,
and pinned proof digests passed their audit. It also means the workbench used
its real nonblocking process pipe to run and capture the safe repository-boundary
audit. It also compiled the complete live-viewer fixture, solver, and execution
entrypoint through a zero-world preflight, then exercised the GUI's actual
detached-Godot launcher with the child forced into that validate-only mode. It
opened no world and created no additional BW22L attempt. It does **not** mean all
locomotion goals are complete.

## A ten-minute tour

The workbench has four main surfaces.

### 1. Engine and run selection

The engine selector explains the current evidence boundary for:

- Godot 4.7 / Jolt;
- Rapier / Parry;
- MuJoCo;
- repository-wide contracts spanning all engines.

The run selector includes safe audits, retained-evidence closure checks,
historical zero-world gate regressions, and ordinary conformance. BW22L has
consumed its only permitted physical identity, so the workbench now exposes
its closure audit and no BW22L physical launch row.

The MuJoCo VH2 row is deliberately a safe closure audit, not a physical-launch
button. It verifies the frozen source, full-Godot attestation, six retained
attempt artifacts, exact MuJoCo 3.11 `M`/no-`qM` binding mismatch, absent
report, bounded no-result disposition, and hard rerun refusal. A passing row
means VH2 remains immutably implementation-invalid; it does not mean MuJoCo is
walking or that the 24-cell physical gate passed or failed.

The separate MuJoCo VH3 row is now a zero-world closure audit. VH3 completed
all 24 cells, but its frozen force trace recomputed force on a copied post-step
state and therefore did not measure force or impulse during the completed
implicit step. The row verifies the immutable six-file physical attempt, all
43,200 traces, the separate momentum diagnostic, no-result classification, and
hard rerun refusal. It does not expose the consumed physical switch and cannot
establish either a positive or negative host result or walking.

Every run displays:

- its status;
- its world-opening policy;
- its operational risk;
- the exact repository runner;
- what a pass may establish;
- what a pass may **not** establish.

### 2. Parameter laboratory

The left panel exposes 29 controls covering:

- campaign seed;
- terrain seed;
- limb count and locomotion mode;
- six morphology dimensions;
- terrain, friction, slope, roughness, and obstacles;
- external pushes;
- sensor noise and latency;
- steering and residual-controller factors;
- gait timing, stride, simulation frequency, and duration.

The controls are deliberately broader than the current accepted support
matrix. This lets us explore the roadmap while the diagnostics make unsupported
choices conspicuous.

Changing an editable value does not mutate a frozen campaign. It changes the
view to **EXPLORATION DRAFT** and produces a new fingerprint. To test that
combination scientifically, we must give it a distinct identity,
preregistration, preflight, and source freeze.

### 3. 3D setup inspector, live physics, and diagnostics

The center view is an interactive 3D setup inspector. Left-drag orbits the
camera and the mouse wheel zooms. It shows the requested morphology, terrain,
friction, push declaration, and unsupported future locomotion modes. It is a
render-only setup model—not a predicted outcome. It is deliberately static;
only the separate live window shows motion.

For a supported Godot/Jolt quadruped configuration, **Launch real Jolt
physics** opens a second 3D window. That window runs the repository's actual
physical walker:

- one continuously simulated world;
- Jolt at the declared 120 Hz, 20-velocity/7-position solver policy;
- one free torso plus eight free leg bodies;
- eight `HingeJoint3D` motors as the only locomotor authority;
- gravity, collision shapes, material friction, and measured contacts;
- zero torso force, impulse, velocity, transform, freeze, or teleport commands
  after release;
- seeded initial perturbation and, when supported, seeded rough terrain or a
  bounded lateral push.

The live window has orbit, zoom, pause, camera reset, height, speed, and
displacement diagnostics. It is a repeatable development sandbox, not retained
evidence. A negative walking predicate is displayed as a negative outcome—not
as a renderer crash and not as something to hide.

The live button fails closed when a setting is not actually wired to the real
fixture. Today it refuses non-quadrupeds, other locomotion modes, slopes,
discrete obstacles, sensor noise/latency, non-Jolt engines, roughness above
`0.025 m`, pushes above `0.40 N·s`, or a non-120-Hz clock. The 3D setup
inspector may still visualize those roadmap ideas, but the physical window
will not pretend to simulate an implementation that does not exist.

The live sandbox uses the repository's physical baseline controller. It does
not impersonate the closed BW22L-A or BW22L-B campaign. The retained BW22L
result is available through the closure/proof surface under its exact invalid
classification; ordinary sandbox behavior remains nonretained development.

### Native Rapier and MuJoCo Explorer transport

The three-engine Explorer is being added by extending this workbench, not by
replacing physics with an animation. Its first completed backend slice streams
fresh native state from the already working exact-s169 Rapier PH1 and MuJoCo
MV6 development paths:

- Rapier emits body poses and ground contacts immediately after its real
  `World::step()`;
- MuJoCo emits body poses and contacts immediately after the real five-substep
  host application in `MjData`;
- both identify their native engine and version and mark every message
  `replay=false`;
- both accept a wall-clock pacing request while keeping their `120 Hz` physics
  contract, and every terminal receipt reports the achieved simulation/wall
  ratio rather than assuming the host kept up;
- MuJoCo keeps that `120 Hz` physics/control schedule while streaming ordinary
  render telemetry at `30 Hz`; kick application frames are never decimated;
- neither worker writes a retained campaign report or claims scientific
  evidence authority.

The workbench now exposes **Launch all 3 real engines**. Rapier and MuJoCo
first complete their zero-world/pre-step preparation and each emit a
source-bound ready receipt. A shared start gate then releases both native
workers and opens the Jolt sandbox, preventing Jolt's shorter development
horizon from finishing during the native preflights. This is a synchronized
operator launch, not evidence that the three trajectories or policies are
equivalent. Rapier and MuJoCo currently use the exact-s169 portable lineage;
the editable Jolt development fixture is a separate lineage.

The joint zero-world gate is:

```powershell
pwsh -NoProfile -File tests\test_locomotion_live_explorer_native_preflight.ps1
```

It builds the Rapier worker, opens loopback transports to Rapier and MuJoCo,
runs their complete existing preflights, and rejects any frame or world during
that validation. The separate physical probe is intentionally not part of a
dirty-source test. After a clean pushed source boundary, it can run both real
workers concurrently and measure native frame count, movement, wall-clock
rate, provenance, and an optional scheduled disturbance:

```powershell
sdk\adapters\mujoco\.venv\Scripts\python.exe `
  scripts\tools\locomotion_live_explorer_probe.py `
  --source-commit <FULL_40_HEX_HEAD> --realtime
```

Adding `--coordinated-start --kick` makes the command-line probe wait until
both native workers reach the same pre-step barrier, then schedules the same
canonical `3.5 N s` lateral torso impulse
at frame `750` in both engines and requires an engine-native application
receipt at that exact frame. The Jolt and native viewer windows now each expose
a **Kick torso right - 3.5 N s** button. A stumble, fall, continued walk, or
apparent recovery is displayed with raw torso height, up alignment, contacts,
frame, and native application provenance. It is not a push-recovery or get-up
claim.

This first native slice is exact-s169 rather than arbitrary morphology. The UI
may show and edit broader descriptors, but Rapier and MuJoCo live launch must
remain disabled for an edited descriptor until their new descriptor-bearing
workers independently compile it. Random queues must be labeled unvalidated;
the workbench must never say every seed will walk merely because it can create
and render every seed.

The first clean-pushed coordinated physical smoke at source `6412dc4` proved
the shared start and exact native impulse path. Both workers applied the
`3.5 N s` command at physics frame `750`; MuJoCo completed `2992` physics
frames, streamed `750` observer packets, and advanced `1.803 m`; Rapier
completed/streamed `3172` frames and advanced `1.857 m`. Both ordinary walker
gate summaries were positive, but this unpreregistered disturbance session has
no walking, shove-recovery, fall-recovery, or evidence authority.

The separate realtime-requested smoke failed honestly: MuJoCo reached only
`0.760x` simulation/wall time while paired and instrumented, even after its
ordinary render stream was reduced to `30 Hz`. Therefore the present workbench
must not advertise the three-engine view as realtime. Each native window shows
its measured ratio. The remaining remedy is a faster MuJoCo live host path,
not a relaxed threshold or a misleading animation.

The derived-value panel explains quantities such as:

- cross-track proportional heading gain;
- cross-track velocity heading gain;
- physics timestep;
- estimated step count;
- the exploration-draft fingerprint.

The diagnostics panel then explains why a selected setting is or is not inside
the current evidence boundary. For example, selecting six limbs is useful for
design exploration, but immediately reports that the release evidence is
currently quadruped-only.

## What “real physics” means in this project

The actual locomotion research was never a 2D animation. The physical Godot
campaigns use Jolt rigid-body dynamics under gravity; the Rapier and MuJoCo
tracks use their own host dynamics. The original workbench's 2D center panel
was only a parameter schematic, but it failed to make that distinction visible
enough and therefore failed as an explanatory interface. The current workbench
corrects the interface without changing or weakening the experiments.

“Real physics” here means the engine integrates mass, inertia, gravity,
constraints, collisions, friction, and contact response. The controller may
observe declared state and set bounded joint-motor targets. It may not move the
root body directly, teleport the creature, freeze it in a favorable pose, set
its velocity, or apply a hidden torso impulse as locomotion. Forward motion and
balance must emerge from the joint motors acting through contacts with the
terrain.

That still does not make every visual run scientific evidence. Physics answers
what happened in one execution. Scientific authority additionally requires a
prospective question, frozen configuration, complete integrity gate, clean
source identity, declared sample, retained report, and closure. The live
sandbox supplies understanding and diagnostics; the campaign machinery
supplies evidence.

### 4. Proof and execution

The proof tab resolves the selected campaign's repository artifact or retained
physical report, computes its current SHA-256, and compares it with the pinned
digest when one is declared.

The output tab executes safe PowerShell runners without freezing the GUI and
shows stdout and stderr. Editable explorer values are never converted into
arguments for a frozen runner; the runner reloads its own repository
preregistration and freeze.

BW22L's former physical row has been replaced by its immutable closure audit.
That safe row verifies the retained evidence and also proves the original
supervisor refuses another physical attempt. Future one-shot rows will still
use typed confirmation and output-root preview in the GUI, while their frozen
supervisors independently enforce clean pushed source, live GitHub agreement,
exact source hashes, no prior attempt, durable evidence, and complete
zero-world preflight.

## What we are building

We are building an engine-neutral locomotion SDK for physically simulated,
procedurally generated creatures.

The first shippable product boundary is quadrupeds. The longer roadmap extends
the same contract to:

- arbitrary supported quadrupeds inside a declared morphology domain;
- continuous morphology coverage rather than a few handpicked bodies;
- friction and material variation;
- slopes, rough ground, steps, and other terrain;
- external disturbances and recovery;
- noisy and delayed sensors;
- multiple physics engines;
- command-conditioned quadruped turning and curved-path locomotion;
- six-, eight-, and many-legged creatures;
- walking, running, and other contact modes;
- bipeds;
- zero-legged serpentine bodies;
- optional radial or sea-urchin-like pogo locomotion.

“Arbitrary quadruped” cannot honestly mean every imaginable four-legged object
with no bounds. A physically impossible body, a body with no ground-reaching
limbs, or actuators too weak to support its weight cannot be guaranteed to
walk. The product meaning must be:

> Any quadruped admitted by a public, tested schema and supported parameter
> domain either receives a valid controller result or an explicit,
> deterministic out-of-domain refusal.

That is both useful and scientifically testable.

## What an SDK is

SDK means **software development kit**. It is a package of code, contracts,
documentation, examples, tests, and integration tools that lets another
developer use a capability without rebuilding its internals from scratch.

A library is usually code that an application calls. An SDK is broader. A
credible SDK tells the developer:

- what data to provide;
- what the data means;
- what functions to call;
- what outputs mean;
- how to connect those outputs to a host system;
- what versions are compatible;
- what is supported;
- how unsupported inputs fail;
- how to test a new integration;
- how to reproduce the claimed behavior.

The LoColemotion SDK currently contains or is building toward:

- a portable Rust core;
- a stable C ABI for non-Rust hosts;
- Python access;
- versioned schemas and semantic profiles;
- engine-adapter contracts;
- Godot/Jolt, Rapier/Parry, and MuJoCo adapters;
- morphology compilers;
- controller and runtime profiles;
- conformance fixtures;
- evidence-backed support matrices;
- packaging and clean-room consumer tests;
- runnable examples and this operator workbench.

An application should ultimately be able to describe a supported creature,
feed observations into the SDK, receive bounded canonical joint commands, and
let its chosen physics engine apply those commands through a conforming
adapter.

## The architecture in one picture

```text
Creature description + intent + observations
                    |
                    v
       Portable morphology compiler
                    |
                    v
     Engine-neutral controller/runtime
      canonical joint-space commands
                    |
             typed adapter contract
       +------------+-------------+
       |            |             |
       v            v             v
 Godot/Jolt     Rapier/Parry     MuJoCo
       |            |             |
       +------------+-------------+
                    |
                    v
       contacts, motion, failure, recovery
                    |
                    v
   receipts + metrics + gates + retained proof
```

The portable core owns the controller's meaning. The adapter owns host-specific
coordinate conversion, joint handles, motor configuration, and observation
transport. The physics engine owns integration, collisions, contacts, and the
actual physical outcome.

That separation prevents an adapter from quietly changing the controller while
still claiming to run the same policy.

## What physics engines already provide

Godot/Jolt, Rapier, and MuJoCo are powerful systems. They already provide many
of the difficult numerical foundations:

- rigid and articulated bodies;
- collision detection;
- contact constraints;
- joint constraints and motors;
- numerical integration;
- friction models;
- solvers;
- scene or model representation;
- queries and observations.

They generally do **not** provide a universal procedural-creature locomotion
product that:

- accepts a broad generated morphology;
- produces an appropriate gait and stabilizing command policy;
- has identical semantics across engines;
- proves that each adapter ran the same policy;
- states the exact supported morphology and nuisance domain;
- ships preregistered physical validation evidence;
- rejects unsupported configurations rather than silently looking plausible.

A physics engine answers, “Given bodies, constraints, forces, contacts, and a
timestep, what happens next?”

Our SDK must answer a different question: “Given this creature, desired motion,
and observed state, what physically bounded joint commands should be requested,
what do those commands mean on this host, and what evidence supports expecting
them to work?”

## What robotics software already provides

Robotics ecosystems contain excellent components:

- kinematics and inverse kinematics;
- rigid-body dynamics;
- trajectory optimization;
- model-predictive control;
- state estimation;
- standard robot-description formats;
- reinforcement-learning environments;
- controllers for known robots;
- hardware and simulator interfaces.

Most robotics pipelines start from a known robot with a known actuator model,
known sensors, and an engineering team willing to tune or train for that
platform. Many learned locomotion policies also target a fixed morphology or a
bounded family under a particular simulator and training distribution.

LoColemotion's target is different: game and simulation developers may generate
creatures at runtime, use different engines, lack robotics specialists, and
still need honest physical locomotion with explicit failure and support
boundaries.

The novelty of the product is not “we invented joint motors” or “we invented
walking.” It is the integrated delivery of portable semantics, morphology
compilation, adapters, fail-closed evidence contracts, and a usable developer
surface for generated creatures.

## Why the controller uses plan → track → emergent motion

The architecture is:

1. **Plan:** construct a morphology-aware reference gait and joint trajectory.
2. **Track:** request bounded joint motor behavior toward that reference.
3. **Emerge:** let gravity, contact, friction, inertia, and disturbances decide
   the realized motion.

The reference supplies coordination. The engine supplies physics. We do not
kinematically teleport feet, pin the body through space, or add an unexplained
central propulsion force.

This is physically meaningful because the creature moves only when joint
actuation and ground contact produce reaction forces. It can slip, stumble,
fall, or fail a threshold. Those failures are information rather than visual
bugs to hide.

Reference tracking itself is not new; it is standard control engineering. Our
work concerns how to make its semantics portable, morphology-aware, bounded,
and evidence-backed across generated bodies and engines.

## Why the research process is unusually strict

Physics experiments are easy to fool unintentionally.

A creature can appear to walk because:

- the root is being moved directly;
- an assist force supplies propulsion;
- only the best random seeds were shown;
- failures were rerun until they passed;
- thresholds were selected after seeing outcomes;
- a control arm did not actually exercise the intended mechanism;
- an adapter used a different motor model;
- a receipt asserted a policy ran without proving it;
- one engine interpreted velocity or force signs differently;
- a short horizon ended before failure;
- an invalid report was mistaken for a negative or positive result.

Our process is designed to make those mistakes observable.

## Evidence states

Every campaign must end in one of the following states.

| State | Meaning | What we may do next |
|---|---|---|
| Prospective | Design frozen before outcome exposure | Run the declared preflight or authorized experiment |
| Positive | Valid report passed every declared acceptance gate | Make only the bounded claim declared in advance |
| Valid negative | Infrastructure was valid, but one or more acceptance gates failed | Preserve it; diagnose; design a distinct successor |
| Rejected candidate | A development candidate failed selection or safety rules | Preserve rejection; do not promote it |
| Invalid | The experiment or report contract was broken | Preserve observations as diagnostic only; no outcome authority |
| Development-only | Useful exploratory result outside a validation contract | Form a hypothesis; preregister a fresh campaign |
| Missing | Required work has not run or evidence is absent | Claim remains false |

A valid negative is valuable. It tells us that a frozen assumption was not
supported under the tested conditions. We use that knowledge to improve the
next design.

What we refuse to do is change the old threshold, seed set, evaluator, or
interpretation after seeing the result and then call the old experiment a
pass.

## The campaign lifecycle

```text
Question
  -> hypothesis and controlled contrast
  -> fresh values and seeds
  -> preregistration
  -> executable gate and negative controls
  -> perfect synthetic whole-gate preflight
  -> source freeze and digest binding
  -> clean pushed-source verification
  -> one complete physical attempt
  -> immutable retained report
  -> frozen selector/evaluator
  -> closure manifest and executable audit
  -> bounded claim, successor, or explicit invalidity
```

### Question and contrast

The campaign begins with one identifiable question. For example, BW22L asks
whether changing the cross-track proportional factor from `1.0` to `1.5`,
while holding the velocity factor and other dimensions fixed, produces a
strictly better complete finite development result without a paired walking
regression.

Changing many controller values at once may find something that works, but it
makes the causal reason much harder to identify.

### Fresh values and seeds

Fresh conditions reduce overfitting to outcomes we have already observed.
Seeds are declared in advance and controller code is forbidden from branching
on a seed, friction token, failure identity, or outcome.

A seed is not magical randomness. It is a reproducible integer that initializes
a deterministic generator. Anyone using the same source, configuration, and
seed should obtain the same generated condition within the declared host
boundary.

Terrain seeds are separate so morphology, controller, and terrain variation
can be reasoned about independently.

### Preregistration

The preregistration freezes:

- the question;
- candidates and controls;
- engine and host settings;
- seeds and material values;
- world matrix;
- measurements;
- thresholds;
- failure rules;
- selection rule;
- permitted claims;
- forbidden claims.

It prevents us from unconsciously moving the goalposts after seeing a result.

### Complete synthetic preflight

Before spending a physical attempt, we construct a perfect synthetic report
and prove that the **entire production gate** accepts it.

Then we perturb one required fact at a time and prove that negative canaries
fail closed.

This answers two important questions:

1. Could the declared experiment accept a genuinely perfect result?
2. Would it reject known corruptions, mismatches, or inflated claims?

BW22L's prospective preflight exercised 50 production gates, 23 evaluator
canaries, 28 worker entrypoints, authority checks, receipt composition,
supervisor authorization, and direct-worker bypass rejection while opening
zero worlds. Its retained physical closure later proved that this was not a
complete real-shape preflight: the synthetic gate constructed a four-key
walking receipt instead of traversing the inherited 26-key physical receipt,
every synthetic cell included a coefficient that every real final receipt
omitted, and the real zero-friction safety receipt never traversed the complete
BW22L schema. The successor must pass real-shaped candidate, control, safety,
and negative-outcome receipts through the complete production evaluator.

### Source freeze

The freeze binds the exact load-bearing files and external prerequisite reports
by SHA-256. A later run verifies those bytes before opening a world.

The freeze is more precise than “we used roughly this version.” It identifies
the experiment that was actually authorized.

### Clean pushed source

Physical work runs only when:

- the working tree is clean;
- local `HEAD` equals `origin/main`;
- live GitHub `main` matches;
- the freeze remains intact;
- the evidence directory is new and durable;
- no prior attempt exists.

This ensures another person can retrieve the same source identity and inspect
what ran.

### One complete attempt

For a one-shot campaign, the supervisor writes a durable attempt receipt and
consumes the identity before opening the first world. It then attempts the
complete declared matrix, even if an early cell fails.

We do not selectively replace bad cells, average in convenient reruns, or
continue an incomplete attempt under the same identity.

### Closure

The closure records:

- the exact source commit;
- the retained report path;
- SHA-256 digests;
- observed counts and result;
- which gates passed or failed;
- the precise claim ceiling;
- whether rerunning is forbidden;
- what a successor must change.

The executable closure audit re-runs these checks without recreating the
physical worlds.

## What SHA-256 codes are

SHA-256 is a cryptographic hash function. It maps arbitrary bytes to a
256-bit digest usually written as 64 hexadecimal characters.

For example:

```text
5b053de8f9128920ba4b64407a4c3867171579a1aca74aff4e50dfaffa308bd3
```

That is the pinned SHA-256 for the retained Rapier FB1 physical report.

If one byte in the report changes, its SHA-256 will almost certainly change.
The closure audit recomputes the digest and rejects a mismatch.

SHA-256 gives us:

- **identity:** this is the exact file we reviewed;
- **tamper evidence:** silent editing is detectable;
- **portable verification:** anyone can recompute it;
- **composition binding:** a freeze can bind many source and evidence files;
- **clear provenance:** a result can point to its exact inputs and source.

SHA-256 does **not** prove that:

- the experiment was well designed;
- the code is correct;
- the measurements mean what we think;
- the result generalizes;
- a file was honestly produced in the first place.

Those properties come from the surrounding contract, controls, code review,
independent execution, and replication. A digest locks the bytes; it does not
bless their scientific interpretation.

## How to inspect and demonstrate proof

### In the GUI

1. Select an engine.
2. Select a closure audit, such as **BW19V finite-validation closure**.
3. Open the **Proof** tab.
4. Inspect whether each artifact exists.
5. Compare the current SHA-256 with the pinned expected digest.
6. Open the artifact to inspect the report or closure directly.
7. Open **Run Output** and execute the closure audit.

The audit reads retained evidence; it does not rerun the old physical campaign.

To inspect live mechanics instead:

1. Select **Godot 4.7 / Jolt** and a supported quadruped setup.
2. Keep slope, obstacles, sensor faults, and unsupported topologies off.
3. For rough terrain, keep amplitude at or below `0.025 m`; for a push, keep
   impulse at or below `0.40 N·s`.
4. Press **Launch real Jolt physics**.
5. Orbit with left-drag, zoom with the wheel, and watch torso height, speed,
   displacement, and contact-driven motion.
6. Read the final outcome screen. A negative result is a useful development
   observation but is not automatically retained evidence.

### From PowerShell

Repository boundary:

```powershell
pwsh -NoProfile -File tests\test_repository_agent_boundary.ps1
```

BW19V finite-validation closure:

```powershell
pwsh -NoProfile -File tests\test_bw19v_closure.ps1
```

Rapier FB1 valid-negative closure:

```powershell
pwsh -NoProfile -File tests\test_rapier_c6_force_based_host_characterization_closure.ps1
```

BW22M material-characterization closure:

```powershell
pwsh -NoProfile -File tests\test_bw22m_material_characterization_closure.ps1
```

BW22L immutable infrastructure-invalid closure:

```powershell
pwsh -NoProfile -File tests\test_bw22l_lateral_development_closure.ps1
```

Complete non-Godot conformance:

```powershell
pwsh -NoProfile -File sdk\run_conformance.ps1 -SkipGodot
```

Complete Godot-inclusive conformance:

```powershell
pwsh -NoProfile -File sdk\run_conformance.ps1
```

### Applying the proof as an SDK consumer

A downstream developer should not need to trust screenshots or a status page.
The final package should let them:

1. verify the package digest and version;
2. run portable-core and ABI conformance;
3. run an adapter-authoring fixture;
4. validate their engine adapter against semantic canaries;
5. load a declared supported morphology;
6. observe deterministic refusal outside the supported domain;
7. reproduce bounded example campaigns where licensing and platform permit;
8. inspect the support matrix describing exactly what the evidence covers.

That is why the final release contract includes clean-room package and consumer
receipts rather than relying only on tests inside the development repository.

## Where the project is now

As of the MuJoCo VH2 implementation-invalid closure on 2026-08-03:

### Established

- The portable Rust core, C ABI, Python boundary, versioning system, and three
  adapter source boundaries exist.
- Godot/Jolt has substantial bounded physical authority.
- BW19V independently tested 36 fresh finite quadrupeds:
  - control: `31/36` walking;
  - treatment: `33/36` walking;
  - treatment selected because `3 < 5` failures.
- All 36 BW19V treatment cells passed the declared execution integrity and
  mechanism checks.
- BW22M produced positive finite fresh-material characterization and profile
  publication for the BW22L successor.
- Rapier explicitly selects and reads back `ForceBased` motors.
- Rapier's exact finite velocity-only host characterization VH1 is positive.
- Rapier transport and host contracts below selected-policy C6 exist.
- MuJoCo transport and host contracts below selected-policy C6 exist.
- MuJoCo VH1 completed all `12/12` exact finite velocity-only host cells with
  zero execution-integrity errors. Its eight loaded affine-response cells all
  passed; this is retained design information inside an overall negative.
- MuJoCo VH2 passed its zero-world whole-gate preflight across `24` synthetic
  cells, `43,200` trace records, and `18/18` corruption canaries, but its one
  physical process then constructed one model and failed before any `mj_step`
  or completed cell. The implementation requested absent Python `MjData.qM`;
  the pinned binding exposes `MjData.M` and `mj_fullM(model,data,destination)`.
  VH2 is closed implementation-invalid with no scientific host or walking
  result.
- MuJoCo VH3 corrected generalized-inertia readback and completed `24/24`
  worlds and `43,200/43,200` state traces. Its frozen evaluator printed
  `22/24`, but the during-step force/impulse instrumentation was invalid: it
  sampled force recomputed at the resulting state. Zero-world momentum
  reconstruction finds at least one capped step in all `24/24` cells. VH3 is
  closed with no scientific positive or negative; both the physical report and
  the diagnostic remain development evidence for a distinct successor.
- Repository, ABI, versioning, selector, integrity, closure, and negative
  controls are automated.
- BW22L's complete 28-world physical execution is retained and its immutable
  infrastructure-invalid closure is executable. All 28 processes exited zero,
  all 28 receipts parsed, and no supervisor transport failure occurred.

### Negative, rejected, or invalid results that remain important

- Rapier FB1 is a valid `6/8` negative. ForceBased readback worked, but two
  gravity-loaded cells missed the frozen terminal-impulse minimum.
- Several later Rapier candidates closed negative.
- Rapier EH1 and LC1 primary reports are invalid and cannot grant authority.
- Rapier TS1 is a complete valid negative because terminal four-foot contact
  was not restored.
- MuJoCo VH1 is a complete `8/12` valid negative. All four unloaded cells
  ended at zero velocity with signed saturated actuator force and failed the
  frozen steady-response gate. It grants no passing host or walking authority.
- BW20F material locomotion is rejected. The treatment passed `10/12`; two
  finite cells failed the frozen lateral-drift gate. Its control contract also
  contained a prospective defect.
- BW21L completed 53 worlds but is infrastructure-invalid because the inherited
  policy identity gate rejected all new-policy receipts. It selected nothing.
- BW22L completed all 28 worlds but is infrastructure-invalid because three
  final-receipt composition mismatches escaped its synthetic preflight. The
  frozen result is not a valid `NONE` selection and not a locomotion negative.
  A non-authoritative reconstruction gives the intended decision surface
  `50/50` and still returns `NONE`: A passed the declared four walking gates in
  `9/12` cells, B in `6/12`, and B regressed in four matched pairs. Those
  observations constrain successor design but grant no selection authority.
- Older rough-terrain, push, and sensor-noise evidence remains rejected.

These results are not embarrassing debris. They are the causal map that tells
us which assumptions, adapters, measurements, and controllers must change.

### Not established

- Arbitrary quadrupeds across a public supported volume.
- Continuous full-volume morphology coverage.
- Continuous friction or arbitrary material robustness.
- Rough-terrain robustness.
- External-push recovery.
- Sensor-noise robustness.
- Sensor-latency robustness.
- Combined nuisances.
- Accepted selected-policy C6 on Rapier.
- Accepted selected-policy C6 on MuJoCo.
- Cross-engine equivalence.
- Command-conditioned turning, curved-path tracking, or navigation.
- Running.
- Bipeds, six-, eight-, many-, or zero-legged SDK support.
- Final clean-room packaging and consumer receipt.
- A completed release-authorized SDK.

## Challenges already solved or materially reduced

### Honest physical actuation

The walking lineage now distinguishes joint-driven locomotion from root motion,
central assist, or kinematic foot pinning. Application and mechanism receipts
help prove the intended controller contribution reached physical actuation.

### Finite morphology generalization

The system progressed from a single creature toward generated morphology
cohorts. BW19V supplies real independent finite evidence, including failures,
rather than a curated success video.

### Adapter semantic defects

Rapier work exposed that a diagnostic labeled ForceBased had actually used the
default AccelerationBased motor. Explicit selection, builder/mutable readback,
and a default-model negative canary now guard that boundary.

Later work exposed mixed coordinate signs and a duplicated native position loop
around a portable closed-loop velocity command. The version-four canonical
velocity profile moved host conversion into the adapter and made the ownership
rule explicit.

### Invalid-report detection

EH1, LC1, BW20F controls, and BW21L each revealed a different way a test can
produce plausible observations while violating its contract. Those outcomes
were preserved as invalid or rejected rather than forced into positive/negative
categories.

### Proof that a perfect result can pass

Complete zero-world synthetic preflight prevents the expensive discovery that
an evaluator could never accept its own declared ideal result. Negative
canaries prove that obvious corruptions fail.

### Durable, auditable evidence

Physical reports are retained outside temporary storage, bound by SHA-256,
connected to closures, and checked by ordinary conformance without rerunning
closed campaigns.

### Repository isolation

The project has one canonical worktree, one LoColemotion remote, repository-owned
agent authority, and a boundary audit. Ambient VS Code or agent working
directories are treated as untrusted.

## The hard challenges ahead

### A supported morphology volume

Testing a few bodies is not the same as supporting a continuous parameter
volume. We need:

- a precise public schema;
- feasible-region rules;
- sampling or covering strategies;
- boundary and corner tests;
- out-of-domain refusal;
- independent fresh cohorts;
- evidence that failures are not hidden between sampled points.

We may need adaptive compilation, gain scheduling derived from dimensionless
relationships, and explicit subdomains rather than one global controller.

### Materials and terrain

Authored friction is engine-specific input, not universal physical truth. We
must characterize what each engine actually produces, publish host profiles,
then test locomotion using those profiles.

Terrain adds contact timing, reach, impact, foothold, perception, and recovery
problems. A single “roughness” number is not enough; terrain families and
failure modes need explicit declarations.

### Disturbance recovery

Push recovery requires detection, feasible support changes, stepping or
bracing responses, actuator authority, and clear containment gates. Merely
surviving a shove once is not a robustness claim.

### Sensors

Noise and latency alter feedback differently. They should be characterized
independently before combined campaigns, with seeded noise streams and exact
delay semantics that the controller cannot inspect as hidden condition IDs.

### Cross-engine C6

Matching data schemas below the physical layer is easier than matching actual
motor/contact behavior. Each engine needs host characterization, adapter
readback, selected-policy commissioning, and independently frozen evidence.

“Works on three engines” must mean the same canonical controller semantics ran
through three characterized adapters—not three separately tuned controllers
wearing one name.

### Turning

Turning is not just straight walking with a different label, and the current
steering corrections that try to preserve a straight heading are not evidence
of commanded turning. The first portable turning contract will add one signed
task-frame command—prospectively chosen as yaw rate or curvature—with exact
zero-command compatibility. Gentle left/right arcs and
straight-to-turn-to-straight transitions come before pivot turns, reversing,
waypoint following, or general navigation.

A straight-line lateral-drift limit cannot evaluate an intentional arc. A
turning campaign therefore needs a frozen desired curve and curve-relative
cross-track, heading, yaw/curvature response, progress, slip, contact,
stability, saturation, and return-to-straight gates. The ordinary straight
gate remains active for zero-command controls. Signed left/right pairs help
detect frame or sign mistakes, and every advertised engine must show that the
same canonical command reached joint motors without root-body steering.

This is ordered as the first new locomotion capability after the base
engine-neutral quadruped walking slice. A bounded turning release will claim
only its tested commands, speeds, morphologies, materials, terrains, and
engines—not arbitrary navigation or universal agility.

### Multi-engine live debugger status and remaining product gate

The native Live Explorer now launches real Rapier and MuJoCo child workers
alongside Godot/Jolt, consumes native post-step body/contact frames, shares a
post-preflight start barrier, and can schedule a bounded canonical torso
impulse through each engine's real physics API. It is not a visualization
substitute or a replay. The impulse is development-only and does not prove
push recovery, fall recovery, or self-righting. The Python-hosted MuJoCo smoke
measured `0.760x`, so three-engine realtime performance also remains false.

The remaining product gate is descriptor-bearing native compilation and loud
provenance/capability UX. Edited/random morphologies are previewable, but
Rapier and MuJoCo live launch currently remains exact-s169 and must refuse a
fresh descriptor until each native worker can compile it independently. The
showcase must expose engine/version/configuration, source/policy/morphology
identity, simulation/wall ratio, commands, contacts, application receipts,
unsupported capabilities, and evidence authority. Unopened one-shot campaigns
remain protected. The detailed showcase and adaptation sequence is in
[`SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md`](SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md).

### Running and new topologies

Running includes flight phases and different stability/contact contracts. A
biped has a much smaller support region and stronger recovery demands. A
hexapod or centipede has combinatorial contact scheduling. A snake needs
environmental reaction along a body rather than feet.

The engine-neutral observation and command contracts can be reused, but the
controller topology and evidence programs will be distinct.

### Productization

Even scientifically sound code is not a finished SDK. We still need:

- a license and distribution decision;
- deterministic builds;
- stable versioning and migration promises;
- package documentation;
- examples outside the source repository;
- clean-room install and consumer tests;
- performance budgets;
- error messages and telemetry boundaries;
- long-term compatibility policy.

## Why spend so much time on this

Without the rigorous path, we could produce a compelling demo much faster.
That demo might work for one creature, one floor, one engine, and one handpicked
seed. The cost would appear later:

- procedural creatures fail unpredictably;
- engine ports require retuning from scratch;
- nobody knows which controller actually ran;
- regressions cannot be localized;
- unsupported claims become product promises;
- customers cannot reproduce results;
- every new feature destabilizes old successes.

The detailed work buys us compounding assets:

1. **Reusable semantics.** Every new engine implements a known contract.
2. **Reusable experiment infrastructure.** Every campaign starts with gates,
   canaries, receipts, and retention already available.
3. **A causal failure ledger.** Negative and invalid results stop us repeating
   the same mistakes.
4. **Bounded product promises.** The support matrix can say exactly what users
   may depend on.
5. **Regression resistance.** Hashes and closures detect silent evidence drift.
6. **Faster future expansion.** New topologies reuse packaging, ABI, adapter,
   evidence, and workbench surfaces.
7. **External credibility.** A third party can audit or reproduce a claim
   rather than trusting a video.

The payoff is not just a better walker. It is an infrastructure for producing
many defensible locomotion capabilities.

## Why we believe the end result is possible

We do not know that one universal controller will solve every morphology and
condition. That is not required for a useful SDK.

We have strong reasons to believe bounded products are possible:

- reference-tracking locomotion is established control engineering;
- physics engines already solve the underlying constrained dynamics;
- morphology-aware gait construction and kinematic compilation are tractable;
- the existing Godot/Jolt lineage physically walks across substantial finite
  generated cohorts;
- BW19V treatment improved a fresh paired cohort;
- portable controller and adapter boundaries already execute;
- motor semantics can be characterized and corrected prospectively;
- failures are increasingly localized to explicit subsystems and conditions;
- the release contract can ship a supported subdomain while refusing the rest.

The likely end state is a family of versioned policies and compilers over
declared topology/condition domains, not one magical formula for every body.
That is normal engineering: compilers, graphics drivers, and numerical
libraries also expose supported domains and versioned capabilities.

## Is this new research?

There are three different meanings of “new,” and they must not be confused.

### New knowledge inside this project

Yes. The campaigns have produced new empirical knowledge about:

- how this portable policy behaves across the tested generated bodies;
- which Godot/Jolt material points produce which characterized response;
- how Rapier 0.34 ForceBased motor readback and observed impulses behave in our
  fixtures;
- how mixed sign/feedback ownership corrupted the earlier Rapier path;
- which finite conditions and terminal-contact modes fail;
- which receipt and evaluator designs were insufficient.

Those results did not exist before the experiments and materially changed the
architecture.

### New engineering artifact

The combination of:

- a procedural-creature controller core;
- typed cross-engine semantic profiles;
- policy-relative execution receipts;
- preregistered one-shot physical campaigns;
- complete synthetic whole-gate preflight;
- hash-bound closures and a claim-aware workbench

is an unusual and potentially valuable engineering artifact. Product novelty
can exist even when its ingredients have prior art.

### New contribution to the scientific field

That claim is not established yet.

Reference tracking, gait generation, PD/velocity control, support geometry,
motor characterization, preregistration, deterministic seeds, cryptographic
digests, and multi-simulator validation all have prior art.

To claim a field-level research contribution we would need, at minimum:

- a focused literature comparison;
- a precise novel hypothesis or method;
- public baselines;
- statistically and scientifically appropriate experiments;
- independent replication or external review;
- a paper-quality artifact and limitations section.

Potential publishable contributions could emerge from:

- a public benchmark for prospectively evidence-gated locomotion portability
  across generated morphologies and physics engines;
- a semantic adapter contract that predicts or measurably improves cross-engine
  policy transfer;
- a morphology compiler with validated coverage and deterministic refusal;
- a receipt system that proves policy-relative physical execution across hosts;
- a dataset of immutable positive, negative, rejected, and invalid campaigns
  useful for locomotion methodology research.

Those are possibilities, not current claims. The research ledger and future
comparison work must decide what is genuinely novel relative to the field.

## What we will have at the end

A mature quadruped release should contain:

- a documented supported morphology domain;
- a portable controller/runtime package;
- C, Rust, and Python developer surfaces;
- at least one release-authorized engine adapter and documented additional
  adapters;
- engine characterization profiles;
- deterministic examples;
- conformance and adapter-authoring kits;
- support and limitation matrices;
- retained validation reports and executable proof audits;
- clean-room packaging and consumer receipts;
- the experiment workbench;
- versioning, migration, licensing, and distribution documentation.

Later SDK releases can add capabilities without pretending the first release
already contains them:

- quadruped SDK `0.x`: bounded walking and explicit refusal;
- later quadruped releases: larger morphology/terrain/disturbance domains;
- multi-engine releases: selected-policy C6 on additional hosts;
- turning-capable quadruped releases: bounded signed arcs and command
  transitions before broader path following;
- topology releases: hexapod, octopod, many-leg, biped, or serpentine modules;
- locomotion-mode releases: running and specialized modes.

Shipping several evidence-bounded SDK versions is healthier than withholding
everything until every creature imaginable is solved.

## Who benefits

### Game developers

Procedural-creature games can request physically responsive locomotion without
building a robotics team or hand-authoring an animation set for every body.

### Simulation and digital-twin developers

They gain a portable control surface with explicit host characterization and
reproducible support boundaries.

### Robotics researchers

They may use the morphology, cross-engine, and evidence infrastructure as a
benchmark or prototyping layer, while recognizing that simulation evidence is
not hardware validation.

### Physics-engine maintainers

The host-characterization suites expose motor, sign, force-limit, contact, and
semantic mismatches that ordinary API conformance can miss.

### Tool and middleware vendors

They can integrate through the C ABI or adapter contract instead of depending
on LoColemotion's game code.

### Educators and students

The workbench makes the relationship between morphology, control, physics,
experimental design, and claims visible rather than hiding it behind a final
animation.

## Workbench safety rules

The GUI follows these rules:

1. It opens zero physics worlds on startup.
2. Its embedded 3D setup inspector has no physical authority.
3. Real physics starts only through the separate, visible live-sandbox button
   or an explicitly selected repository runner.
4. The live sandbox uses real rigid bodies, gravity, contacts, and joint motors
   but is labeled development-only and never impersonates the closed BW22L A/B
   campaign.
5. Editable values are never passed into a frozen runner.
6. A changed frozen preset becomes an exploration draft.
7. Safe rows cannot contain `-RunPhysical`.
8. The catalog exposes zero current one-shot physical rows because BW22L is
   closed; its safe closure row cannot contain `-RunPhysical`.
9. Any future physical row must require an exact typed phrase and new output
   root.
10. A future frozen physical supervisor remains the final authority and must
    recheck every source/evidence interlock.
11. Proof status is computed from files and digests, not hardcoded green labels.
12. The workbench test proves self-testing and the live configuration preflight
    open zero worlds and leave BW22L attempts unchanged.

The catalog lives at:

```text
sdk/workbench/experiment_catalog.json
```

It is intentionally labeled:

```text
operator_interface_not_scientific_evidence
```

## What to do next

The MuJoCo engine view now includes the safe
`mujoco_velocity_only_stability_vh2_closure_audit` row. It executes the exact
source/evidence/attestation/binding/rerun audit without constructing a model.
The workbench intentionally does not expose VH2's closed `-RunPhysical`
switch. A green row proves only that the implementation-invalid closure still
matches its pinned bytes and grants no scientific result; it does not mean
MuJoCo walked or that VH2's physical gate was evaluated.

It also includes the safe
`mujoco_velocity_only_stability_vh3_closure_audit` row. A green result proves
that the exact source, attestation, six-file physical attempt, complete trace,
separate zero-world temporal diagnostic, claim boundary, and runner refusal
still match their pinned bytes. The row opens zero worlds; the consumed VH3
physical switch remains intentionally unavailable from the workbench.

BW22L is complete and permanently closed infrastructure-invalid. The immediate
evidence-producing step is a scientifically distinct successor with a new
campaign, source, preregistration, fresh material values, fresh seeds, and
evidence identity. Before its first world, real-shaped candidate, control,
zero-friction safety, and negative walking receipts must traverse the complete
production evaluator. Walking projection/count semantics must be single-
sourced, every final receipt must carry its controller coefficient, and
negative canaries must reject the three exact BW22L defect families.

Failure analysis also narrows the controller search: BW22L-B's stronger
proportional factor was descriptively worse and may not be promoted or simply
retested as the selected successor. The next hypothesis should address the
observed high-material lateral behavior with a distinct mechanism or lower,
source-grounded contrast while retaining the original observations as design
evidence—not selection evidence.

In parallel, the broader program still needs:

- accepted Rapier selected-policy C6;
- a distinct MuJoCo successor after MV2's immutable implementation-invalid
  no-result closure;
- the portable turning command and its first signed-pair quadruped campaign;
- real Rapier and MuJoCo development viewers in the workbench;
- expanded morphology coverage and boundary refusal;
- terrain, push, noise, and latency campaigns;
- release licensing and clean-room package verification.

The headless real-MuJoCo selected-policy development bridge now exists at
`sdk/adapters/mujoco/sporespore_mujoco_adapter/selected_policy_development.py`.
Its full LC1 development trajectory is physically functional, and VH5 now
characterizes the exact finite s169 per-actuator host profile. MV2 later
consumed its one physical process and closed implementation-invalid when its
post-trajectory report assembler raised `KeyError: 'morphology_id'`; no report
or scientific walking result exists. The workbench now exposes only the MV2
closure audit and cannot expose or consume its closed physical switch. The
future MuJoCo workbench
viewer should wrap that same model/adapter path and clearly label it
development-only; it must not substitute Jolt, advertise the run as retained
evidence, or expose any consumed one-shot switch. Rapier and MuJoCo remain real
requested viewer options, not decorative engine labels.

The safe MV2 entry is `mujoco_bw19v_mv2_closure_audit`. It verifies the
`29/29` historical zero-world receipt, exact source and attestation, five-file
attempt tree, report-assembly traceback, absent report, no-result boundary,
and same-identity rerun refusal. It cannot recover the lost trace and is not a
walking or C6 result.

The safe Rapier entry is now `rapier_bw19v_ph1_closure_audit`. It verifies the
clean pushed source, exact full-Godot V2 attestation, one consumed world,
seven-file evidence tree, `251584270`-byte report, all `3172` trace rows, frozen
evaluator replay, exact passing metrics, bounded claims, and executable
same-identity refusal. It exposes only the zero-world closure audit—never the
supervisor's `-RunPhysical` switch. A pass preserves PH1's exact-finite s169
technical-commissioning and single-body walking-contract result; it does not
grant release-selected Rapier C6, independent validation, wider morphology,
robustness, cross-engine equivalence, release, or physical-acceptance authority.

## R23D2 consumed closure row

The all-engine view exposes `qsdk_r23d2_closure_audit` as a safe zero-world
audit. The five prospective R23D2 oracle, engine-worker, and supervisor rows
were retired after the one-shot identity was consumed; none exposes a stale
physical authorization path.

The row rehashes the complete 35-file evidence tree and every CAS object,
independently evaluates all nine terminal entries and the frozen aggregate,
and verifies the exact four positive and two negative Rapier/MuJoCo cells plus
the three post-physics Godot/Jolt worker failures. It rejects tampered reports,
failure receipts, CAS metadata, claims, and incomplete aggregate inputs, then
proves same-identity supervisor refusal before attestation read or output
creation. The workbench opens no physics world. R23D2 has no valid three-engine
aggregate and grants no portable turning, bilateral turning, equivalence,
QSDK-R23, release, or physical-acceptance authority.

## R24D7 consumed telemetry-control closure row

The Godot/Jolt view exposes `qsdk_r24d7_physical_failure_closure` as a safe
zero-world audit. It verifies the passing 21-file official zero-world receipt,
the single consumed 27-file physical attempt, all CAS payloads, the 65 observed
callback attempts with zero refusals, the evaluator terminal, and the exact
pinned-source callback order.

A green row means the campaign remains correctly classified as
implementation-invalid: `_integrate_forces` ran after Jolt cleared its stepping
flag, so the preregistered active-step refusal control was not realized. The row
never exposes `Physical` mode or the consumed supervisor identity. It does not
characterize telemetry, prove an unsafe read, promote either Godot profile, or
open recovery or prone-to-standing.

## R24D8 prospective timing-freeze row

The Godot/Jolt view also exposes `qsdk_r24d8_prospective_freeze` as a safe
zero-world source audit. It checks the new active-step snapshot declaration,
the exact combined ten-file patch, twelve source bindings, the immutable R24D7
closure, all three retained precommit diagnostics, and all contract, source,
and evaluator mutation controls.

This row deliberately runs the deterministic freeze audit, not the cold
supervisor. It exposes no `Physical` argument and cannot construct the declared
one-hinge world. A green result means only that the prospective source is
internally consistent and still claims `0/0/0`; it does not mean the official
zero-world gate passed, the timing mechanism was physically observed, numerical
telemetry was characterized, or prone-to-standing opened.

## Glossary

**Acceptance gate** — A condition declared before outcomes that must pass for
the campaign's bounded claim.

**Adapter** — Host-specific code translating portable observations and
commands to a physics engine without changing controller semantics.

**Authority** — What a report is allowed to prove. A diagnostic report may
have mechanism authority but no walking or release authority.

**C0-C5** — Lower contract/conformance layers such as schemas, transport,
identity, and host mechanics below selected-policy physical locomotion.

**C6** — The selected-policy physical integration boundary for an engine.

**Canary** — A deliberately corrupted synthetic case that must be rejected.

**Closure** — Immutable record binding a completed campaign, result, hashes,
claim boundary, and no-rerun rule.

**Conformance** — Executable checks that an implementation obeys a contract.

**Control** — A cell that removes or changes a mechanism so its contribution
can be interpreted. Not every control is a comparative outcome estimator.

**Evidence root** — Durable external storage for physical artifacts at
`<evidence-root>`.

**Freeze** — Prospective binding of source, inputs, gates, and claims before
physical outcome exposure.

**Host characterization** — A bounded experiment establishing how a specific
engine/version/configuration realizes an adapter-level command.

**Invalid result** — A run whose experiment or report contract was broken. Its
observations may guide development but cannot decide the preregistered claim.

**Preregistration** — Prospective declaration of hypotheses, cells, metrics,
thresholds, selectors, and claim limits.

**Receipt** — Machine-readable statement of what source, policy, adapter,
configuration, and mechanism actually executed.

**Selector** — Frozen decision procedure choosing a candidate or `NONE` from a
valid complete report.

**SHA-256** — Cryptographic digest used to bind exact bytes and detect drift.

**Support matrix** — Executable product statement of what is accepted,
rejected, invalid, missing, or outside the current release.

**World** — One isolated physics simulation cell. A zero-world preflight may
exercise parsing, gates, receipts, and authorization without constructing one.

## MV5 safe closure row

The MuJoCo view exposes `mujoco_bw19v_mv5_closure_audit` as a safe zero-world
run. It verifies MV5's clean pushed source, attestation, consumed attempt,
five-file evidence tree, PH1 authority-schema traceback, absent report,
non-claims, and same-identity refusal. It does not expose `-RunPhysical` or
imply a MuJoCo walking result.

## MV6 safe positive-closure row

The MuJoCo view exposes `mujoco_bw19v_mv6_closure_audit`. This safe zero-world
row binds the complete consumed attempt, exact-source attestation, six-file
evidence tree, full 2,992-step report, unchanged evaluator replay, independent
walking/contact reconstruction, strict claim boundary, and executable rerun
refusal. It never exposes `-RunPhysical`.

A green row preserves one complete valid exact-s169 pose-hold-restoration and
finite single-body walking positive. It does not establish release-selected
physical C6, formal cross-engine equivalence, independent validation, wider
morphology, robustness, release, or physical-acceptance authority.

## R24D9 safe numerical-telemetry rows

The Godot/Jolt view exposes
`qsdk_r24d9_numerical_telemetry_preregistration` as a safe zero-world
declaration audit. It binds the immutable R24D8 timing-positive authorization,
the exact v2 patch, the R24D9 preregistration, and the declaration audit. The
row verifies nine cells, `68` retained future samples, `23` raw fields per
sample, `46` declared evaluator negatives, and `33` declaration-mutation
rejections.

A green declaration row means only that the distinct development question is
complete and internally bound. It cannot launch a rig, cold build, supervisor,
or physical mode.

The adjacent `qsdk_r24d9_numerical_telemetry_implementation_freeze` row audits
the later implementation. It verifies the exact rig, worker, evaluator,
supervisor, fifteen-binding manifest, five-attempt/forty-file precommit record,
all `46` evaluator negative controls, three accepted adverse finite descriptive
mutations, and `20` source-mutation controls. It invokes the freeze audit only;
it neither invokes the supervisor nor compiles or opens a world. A green row
therefore proves the committed implementation identity, not official cold
zero-world qualification.

Numerical telemetry, profile promotion, recovery, prone-to-standing,
cross-engine equivalence, physical acceptance, and release remain false. The
rows do not weaken the separately earned bounded turning positives on
Godot/Jolt, Rapier/Parry, and MuJoCo.
