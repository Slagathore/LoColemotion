# Locomotion Architecture — Reference-Tracking Control

## Active - R10G frame fixtures repaired; complete v3 gate pending, 2026-09-11

The [second R10G safety gate](../sdk/recovery/r10g_walking_frame_safety_gate_refusal_v1.json)
ran 141 of the declared 149 checks: **139 passed and two old frame-fixture
expectations failed**. Eight contact checks had not run. No physical child
launched. The original gate, native fixture and failure streams remain immutable.

The [v3 frame-fixture repair](../sdk/recovery/r10g_walking_frame_fixture_repair_implementation_v1.json)
recognizes the prospectively selected anatomical frame in both post-interaction
roles and the unchanged 3160-command tail/3512-step bound. It adds independent
frame refusal checks for the matched branch. All **21/21** focused frame, contact,
native-contact, profile and route checks pass; **85 source files** are bound.
No controller, DLL, contact, motor, phase, stopping or task-criterion change was
made. Consumed v1 and v2 JSON remain exact.

Next: clean pushed v3 freeze, fresh complete **149-check** safety gate, two fresh
seed-40200 children and full independent replay. The native V50 controller stays
fixed. This is development integration; no R10G physics or held-out acceptance
has run, and SDK1 remains **14/20**.

## Prior boundary - R10G reader fixtures repaired; v2 awaits a fresh complete gate, 2026-09-11

The [first R10G safety gate](../sdk/recovery/r10g_first_safety_gate_refusal_v1.json)
stopped after 87 tests at the candidate reader: 79 preceding checks passed, then
three reader checks passed and five failed/errored. **No physical child launched.**
The consumed freeze and its original stdout, stderr, synthetic source records and
empty child population are retained unchanged.

The [reader fixture repair](../sdk/recovery/r10g_reader_fixture_repair_implementation_v1.json)
corrects two synthetic producer omissions: the complete report now carries its
derived finite-task receipt, and baseline events use the selected V50 ownership
hook. Missing or forged task receipts have explicit negative controls. The new
**v2 integration profile** binds 83 source files and passes **21/21** focused
reader, profile, both-role event and finalization checks. Native V50 controller,
DLL, measured-body/contact logic, amplitude/phase rules and finite task criteria
are unchanged; observed v1 profile and schedule JSON are preserved.

Next: a clean pushed v2 freeze, the complete **149-check** safety gate, then the
fresh seed-40200 baseline/kicked development pair. Full replay is required before
any diagnostic conclusion. Held-out qualification, separate adoption and the
six prospective fresh worlds remain subsequent gates. SDK1 remains **14/20**.

## Prior boundary - R10G paired V50 integration ready for its development ghost, 2026-09-11

The [R10G Godot integration](../sdk/recovery/r10g_godot_integration_implementation_v1.json)
passes **44 focused interface checks**, including both fresh role adapters,
separate baseline and kicked event replay, corrupted-reader refusals, actual
session finalization and the unchanged finite stopping kernel. Its explicit route
selection maps to the **unchanged V50 native policy and DLL**; no Rust controller
component or native runtime rebuild was added.

Both post-interaction branches now start V50 with fresh memory and gait clocks 90.
The no-kick branch uses the measured current body directly; the kicked branch
retains passive descent, V20 recovery and V7 stance first. Both retain the common
V6 setup/BW5R-B prefix, native contacts, four planned cycles and all 120 stopping
commands. A separately labeled task boundary is derived from replayed cycle
memory. Independent Python measurements reconstruct foot endpoints from native
body poses; every incidental stance loss and original diagnostic negative remains
in the record.

The complete applicable safety gate now includes the seven independent finite
walking measurement tests (**149 checks expected**). It has not yet run on this
freeze, and no R10G physical child has launched. Next: clean pushed freeze, full
safety gate, then one seed-40200 fresh baseline/kicked development pair with full
telemetry and cold replay. A valid negative still closes the development route;
held-out acceptance requires final qualification, separate adoption and the
prospectively declared six fresh worlds. SDK1 remains **14/20**; M07, licensing,
Explorer and package-dependent work retain their existing claim boundaries.

## Prior boundary — R10G finite recovery contract and independent walking measurements, 2026-09-10

The [R10G contract](../sdk/recovery/r10g_finite_cycle_kick_recovery_contract_v1.json)
keeps the V50 Rust controller fixed and declares both fresh post-interaction roles:
V50 directly in the no-kick child, and V50 after passive descent/V20 recovery in the
kicked child. Both retain the common BW5R-B prefix, one measured four-foot cycle,
all 120 stopping commands and the final 30 settled observations. This changes the
unused baseline integration explicitly; it does not change an observed campaign.

The [shared measurement component](../sdk/recovery/r10g_finite_cycle_component_implementation_v1.json)
passes **7/7** zero-world checks. It calculates foot endpoints independently from
native body poses and compiled contact sites, binds the actual controller phase
order, requires measured flight and forward relocation, and checks body advance
and settled stopping from native observations. Forged controller geometry cannot
make a step; foot motion cannot substitute for body advance. All 33 V50 contact-loss
episodes, including 17 required-support onsets, remain visible in the test data.
The two retained setup failures exposed display-order versus native phase-order
assumptions; their original source and outputs are retained.

The new prospective task uses the existing 3-sample flight dwell, 12 mm foot
advance and 20 mm body-advance magnitudes, with planned-cycle identity made explicit.
It retains the original evaluator and its negative. It claims neither uninterrupted
stance contact nor arbitrary-duration walking or robustness. This component test
does not regrade V50 and does not constitute a native R10G result.

Next integrate and test the actual two-role worker, reader and publication path,
then commission one fresh seed-40200 development ghost. The three finite held-out
prefix-phase fixtures remain sealed until the final exact freeze, complete shared
qualification and separate adoption. No R10G world is authorized at this boundary.
SDK1 remains **14/20**; M07 acceptance, owner licensing, the actual seeded native
Explorer and the final package-bound proofs remain open.

## Prior boundary — V50 Godot startup losses clear; verified four-cycle walk and stop, 2026-09-10

The [V50 Godot closure](../sdk/development/v50_godot_cycle_stop_closure_v1.json)
retains **128/128** safety checks, a fresh seed-40200 SingleKick from clean pushed
`6e643a7a`, **2,015 solver steps**, and complete independent replay of the timeline,
**1,157** walking/stop commands and **1,187** native walking-contact steps. The V20
recovery hands off at step **858**. All four planned foot cycles finish at walking
command **1037**, followed by all **120** stopping commands. All 120 stopping
observations meet the declared settled limits with four measured supports.

There are **zero required-support contact-loss onsets** and **zero speed-clipped
motor commands** in the first **72** walking commands. Startup still includes
**116.68 mm/s** backward COM speed. Body advance is **119.80 mm**; planned measured
foot-endpoint advances are **58.14, 59.79, 64.64 and 71.24 mm** for FL, FR, RL and RR.
The original evaluator passes **26/27** checks, including terminal four-contact
recovery, and still fails `every_limb_forward_relocation`.

All **33** contact-loss episodes remain retained, including **17** starting on a
required support foot: at most **15 samples**, worst backward endpoint motion
**3.05 mm**, maximum nominal gap **2.63 mm**. Four retained-data diagnosis tests
preserve these negatives and reject crossed clock/contact/stop/reader records.
The old evaluator counts contact losses with at least three absent samples as
cycles and requires each to advance 12 mm. The separately measured planned cycles
are additional diagnostic information; no old result or threshold is changed.

Native child execution took **811.645 s**, cold replay **251.641 s**, and the
complete invocation **1,766.767 s**. The exact **67-file / 1,718,930,768-byte**
retained population is bound. Both MuJoCo and Godot now have observed V50 startup
positives in their distinct development diagnostics; no equivalence or formal
paired effect is established. Historical fixed-tail coverage remains false.

Next keep V50 fixed and define the distinct prospective finite recovery contract
and complete paired commissioning route. Bind both fresh roles and their intended
policy composition; retain planned-cycle measurements, unintended stance losses,
settled stopping and native interaction/recovery invariants. The current SingleKick
is not M07 acceptance. SDK1 remains **14/20**; owner licensing, the actual seeded
native Explorer and final package-bound proofs also remain open.

## Prior boundary — V50 Godot startup integration ready, 2026-09-10

The [V50 Godot integration](../sdk/development/v50_godot_recovery_integration_implementation_v1.json)
selects the already built startup reference-velocity policy through the measured-
body request, motor receipt, retained command chain and independent cold reader.
Its **30/30** targeted checks pass, including the measured-body/start/entry
negative controls, actual native command interface, four-cycle cutoff and all
120 stop commands projected from retained MuJoCo data. The DLL and **362** Rust
test result remain bound unchanged; no V50 Godot world has run at this boundary.

V50 eases in only reference-velocity feed-forward during the existing 72-command
startup. V6 setup, V20 get-up, V7 stance, BW5R-B prefix, native measurements,
contacts, motor limits and finite cycle/stop calculations persist. The schedule
retains at most **1,600** walking commands, **120** stopping commands and a settled
final **30**, within **3,512** total child steps. Full capture and independent
replay remain required. The complete **128-test** safety gate must pass together
on the final source before one fresh seed-40200 SingleKick.

The next diagnostic asks whether Godot also avoids the early required-support
losses removed in V50's MuJoCo startup. All later contact losses and the original
relocation check stay visible. This is development evidence; paired commissioning,
prospective M07 acceptance, owner licensing, the actual Explorer and package-bound
proofs remain open. SDK1 remains **14/20**.

## Prior boundary — V50 native startup losses clear; four cycles and stop complete, 2026-09-10

The [V50 closure](../sdk/development/v50_mujoco_closed_loop_closure_v1.json)
retains **26/26** safety checks, one **1,129-command / 5,645-step** fresh MuJoCo
world, zero warnings, empty worker stderr and a complete independent replay.
All four planned foot cycles complete by command **1009**, followed by all **120**
stop commands and a settled final **30**. Body advance is **111.49 mm**; planned
endpoint advances are **58.15, 60.69, 77.31 and 61.41 mm** for FL, FR, RL and RR.

The first **72** commands have **zero required-support contact-loss onsets** and
**zero speed-clipped motor commands**. Backward COM speed still reaches **77.71
mm/s** during startup. All later losses remain retained: **61** total episodes,
**19** beginning on required support feet, at most **six samples**, worst backward
endpoint movement **3.32 mm**, maximum nominal gap **2.60 mm**. Four diagnosis
tests preserve these negatives and reject crossed clock/contact/stop records.

The clean pushed implementation freeze is `1d45f730`. Native execution took
**14.156 s**, independent replay **11.188 s**, and the complete gate **41.500 s**.
This projected post-recovery diagnostic supports a distinct Godot integration
of the same startup-only change. It does not prove Godot get-up/walking, paired
commissioning, equivalence or acceptance. Next bind V50 to the actual Godot
recovery route, retain the unchanged four-cycle/120-stop schedule and run its
complete gate before a fresh SingleKick. SDK1 remains **14/20**; M07 acceptance,
owner licensing, the actual Explorer and package-bound proofs remain open.

## Prior boundary — V50 startup reference-velocity ramp ready, 2026-09-10

The [V50 implementation](../sdk/development/v50_startup_reference_velocity_implementation_v1.json)
eases in only the joint-reference velocity feed-forward term over the existing
72-command startup ramp. It extends the existing body-reference component;
position feedback, measured-rate damping, world targets, analytic IK, support
preparation, origin recentering, motor caps and finite cycle/stop limits persist.
The original command arithmetic returns when the startup scalar reaches one.

V49's retained Godot command 2 has gait amplitude **0.000344** but all **eight**
motor commands reach the **3.5 rad/s** speed limit. Rear contacts disappear on
commands 3–4, before any planned release. Under exactly those retained inputs,
V50 commands peak **0.284884 rad/s** with **zero** speed clipping and unchanged
reference targets. This is a command-generation counterfactual, not a native
benefit or causal proof. It does not directly resolve later stance contact losses.

**362 Rust tests** and the complete **26-test** affected native-route gate pass.
All **1,165 Godot + 1,131 MuJoCo V49** raw native responses and the **2,128 V46–V48**
responses remain byte-exact under the new DLL. Fresh cached/stateless calls agree
through 80 startup commands. The record retains test-harness failures involving
session schema, integral tokens, the engine-specific descriptor, parsed-number
precision and the local Python environment; no physics ran during those checks.

Next: freeze and push this implementation, then run the complete gate and one
fresh seed-40200 MuJoCo diagnostic with the same 1,600 walking / 120 stopping
limits and full independent replay. No V50 world has run at this boundary.
SDK1 remains **14/20**; V49's old relocation negative, paired commissioning,
prospective M07 acceptance, owner licensing, Explorer and package proofs stay open.

## Prior boundary — V49 Godot completes four planned cycles and a settled stop, 2026-09-10

The [V49 Godot closure](../sdk/development/v49_godot_cycle_stop_closure_v1.json)
retains one fresh seed-40200 SingleKick from clean pushed `324c9d47`: **128/128**
safety checks, **2,023 solver steps**, independent replay of the full timeline,
and **1,165** walking/stop commands. The unchanged V20 get-up reaches its stance
handoff at step **858**. All four planned measured foot cycles finish by walking
command **1045**, followed by all **120** zero-amplitude/zero-speed stop commands.
The final **30** commands have four measured supports and satisfy the prospective
settled limits. The terminal four-contact diagnostic now passes.

Forward body advance is **116.14 mm**; planned endpoint advances are **59.12,
60.58, 66.13 and 66.39 mm** for FL, FR, RL and RR. The original evaluator passes
**26/27** receipts and still fails `every_limb_forward_relocation`. The new
retained-data diagnosis preserves all **36** contact-loss episodes, including
**21** beginning on a required support foot: at most **17 samples**, worst
backward endpoint movement **12.98 mm**, maximum nominal gap **2.66 mm**. The
largest rear-foot recoil begins in walking commands **3–4**, before any planned
release, with no speed-clipped motor command during those episodes. Three
zero-world diagnosis tests preserve these negatives and reject crossed records.

The cycle-aligned development schedule completed. Historical fixed-tail
`coverage_complete` remains **false**, and no old evaluator or observation is
regraded. Native child time was **794.168 s**, independent replay **255.797 s**,
and the complete invocation **1,765.177 s**. The exact **67-file / 1,724,052,948-byte**
retained population is bound by the closure.

Next: inspect the retained recovery-to-walking startup and required-support
losses before selecting a distinct successor; retain V49 as observed. Fresh
complete paired commissioning and prospectively frozen acceptance remain needed
for M07. SDK1 stays **14/20**; owner licensing input, the actual seeded native
Explorer, and final package-bound proofs remain open. This development result
proves neither recovery acceptance nor cross-engine equivalence.

## Prior boundary — V49 Godot recovery integration ready for its fresh diagnostic, 2026-09-10

The [integration record](../sdk/development/v49_godot_recovery_integration_implementation_v1.json)
binds the unchanged V49 core to Godot's actual synchronized body/contact samples
and a distinct finite cycle-aligned walking cutoff plus 120-command stop. All
128 applicable checks have passed across the development and targeted runs;
the complete gate must run together again before the fresh Godot diagnostic.
The [portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md) records
coverage, retained failed tests and the next physical boundary. No Godot V49
world has run and SDK1 remains **14/20**.

## Prior boundary — V49 completes all four foot cycles and the stop, 2026-09-10

[V49's closure](../sdk/development/v49_mujoco_closed_loop_closure_v1.json) retains
113.56 mm forward advance, four measured forward foot cycles and all 120 stopping
commands in one valid MuJoCo diagnostic. The final 30 commands are settled with
four measured supports. The audit preserves 20 brief required-support contact
losses; this is development evidence and SDK1 remains **14/20**. The
[portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md) records
the next Godot recovery integration and remaining acceptance/package gates.

## Prior boundary — V49 remaining-support preparation ready, 2026-09-10

[V49's implementation](../sdk/development/v49_remaining_support_release_implementation_v1.json)
requires positive measured support from the three feet that remain in stance,
while allowing a known unloaded planned swing foot. **362 Rust tests** and **22
interface/launch tests** pass, with all V46–V48 response regressions preserved.
The [portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md) records
the fresh diagnostic and unchanged motion, dwell, timeout, cycle and stop bounds.
There is no V49 physical result yet; SDK1 remains **14/20**.

## Prior boundary — V48 reference cap resolved; preparation contact population is next, 2026-09-10

[V48's closure](../sdk/development/v48_mujoco_closed_loop_closure_v1.json)
records 107.00 mm forward body advance and three measured forward foot cycles.
Origin recentering works, but the planned swing foot's contact flicker prevents
the all-four-contact preparation dwell. The [portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
records the retained three-support diagnosis and the distinct successor. V48 stays
a valid negative; SDK1 remains **14/20**.

## Prior boundary — V48 continuous origin recentering ready, 2026-09-10

[V48's implementation](../sdk/development/v48_advancing_body_origin_implementation_v1.json)
advances the body-reference origin with planned stance anchors and compensates
the stored bias to preserve body-pose continuity. **360 Rust tests** and **20
interface/launch tests** pass; motor commands match V47 exactly through the first
recenter. The [portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
records the fresh MuJoCo diagnostic and unchanged finite limits. There is no V48
physical result yet, and SDK1 remains **14/20**.

## Prior boundary — V47 completes three forward foot cycles; fourth remains blocked, 2026-09-10

[V47's closure](../sdk/development/v47_mujoco_closed_loop_closure_v1.json)
records three measured forward foot relocations, 77.12 mm body advance and low
body tilt in one valid MuJoCo diagnostic. The fourth swing times out while all
four feet are supported and the body-reference translation bias is capped.
The [portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
records the retained diagnosis and the next continuous origin-recentering change.
There is no complete walking/stop result or acceptance promotion; SDK1 is **14/20**.

## Prior boundary — V47 independent body and foot references ready, 2026-09-10

[V47's implementation](../sdk/development/v47_anchored_body_pose_implementation_v1.json)
replaces the drifting-pose stance generator with stationary world foot references
and an independently specified upright body pose. **358 Rust tests**, **242 exact
V46 response regressions**, and **18 launch-safety tests** pass, including direct
swing/landing reference transitions. The [portable bootstrap](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
records the next fresh bounded MuJoCo diagnostic and claim limits. There is no
V47 physical result yet. SDK1 remains **14/20**.

## Prior boundary — V46 closed: preparation exposes incompatible support geometry, 2026-09-10

The [V46 closure](../sdk/development/v46_mujoco_closed_loop_closure_v1.json)
retains one fresh MuJoCo world from clean pushed `31ce61aa`, **17/17** launch
tests, **241 commands / 1,205 native steps**, zero native warnings and empty
stderr. The separate reader reproduced the exact policy responses and refusal.
Native execution took **2.922 s**, independent reading **2.172 s**. Call 242
refused at the unchanged 240-command preparation limit. No swing released,
no limb cycle completed, and no stopping tail began. Displacement was **45.81 mm
backward**. This is a consumed valid development negative.

The retained-data diagnosis checks all **964 limb samples** against independent
hinge FK and native body geometry. During preparation the inherited common-height
lowering rule raises the supporting feet's targets above the measured floor;
at command 100 the gap is **9.538 mm**. Later the four joint-compatible body-height
intervals have no intersection. At command 241 front-left is near its requested
fully extended pose, without speed clipping, but its target is still **14.635 mm
above the floor**. Maximum observed precommand body tilt is recorded in the
closure. The front-left preparation contact losses must not disappear behind
its frozen phase-0 scheduled-swing label. Geometry remains separate from measured
contact and does not establish sole causal attribution.

Next: separate desired body posture from measured pose and stationary foot
support. Resolve the support-reference conflict before another gait timing or
timeout change. Preserve V44–V46 and their original thresholds. No Godot V45/V46
recovery route has been run. SDK1 remains **14/20**; the owner licensing decision
is pending, followed by the native Explorer and final clean-source/package gates.

## Prior boundary — V46 measured-pose support ready for bounded MuJoCo diagnostic, 2026-09-10

The [V46 implementation record](../sdk/development/v46_measured_pose_support_implementation_v1.json)
binds **356/356 Rust tests**, 399 byte-exact V45 command responses plus its exact
final refusal, 399 stateless/cached V46 interface inputs, and **17/17 complete
launch-safety tests**. Every one of the **975** independently eligible retained
support targets reaches the floor in the measured pose. The remaining reach and
common-height-lowering cases keep their original explicit residuals and bounds.
Zero-amplitude startup still selects neutral goals.

V46 retains V45's measured transfer gate, native contact truth, wave schedule,
motor gains/caps, reference slew and finite timeouts. It removes the virtual
upright geometry selector and its unused latch memory. During preparation or a
support hold, both current and comparison references remove lift using the same
measured body orientation and current hip bias. This repairs the identified
above-floor target mismatch; it does not yet prove physical support or walking.

Next is one fresh [declared MuJoCo diagnostic](../sdk/development/v46_mujoco_closed_loop_v1.json)
from a clean pushed freeze: the same explicit V44 native-state projection,
1,600-command walking maximum, four measured completed limb cycles with all
phases in supported stance, then exactly 120 stopping commands and the same
30-command settled-tail predicate. No V46 physical result exists at this
boundary, and no Godot V46 recovery route is selected. SDK1 remains **14/20**.

## Prior boundary — V45 MuJoCo negative and geometry diagnosis, 2026-09-10

The [V45 closure](../sdk/development/v45_mujoco_closed_loop_closure_v1.json)
retains one fresh world from clean pushed `e27b9116`, 17/17 launch safety tests,
399 stepped commands / **1,995 native steps**, zero warnings, empty native
stderr, and a separate independent reader. Native execution took **4.875 s**;
reader replay took **3.953 s**. Command 400 refused on the unchanged inherited
120-command missing-support timeout, retained exact request/response bytes,
cleared native controls and ended without another integration step.

Measured transfer established **26.658 mm** margin and **2.930 mm/s** horizontal
COM speed before the first front-left release at command **146**. No limb cycle
completed. Net torso displacement was **69.52 mm backward**; there was no
cycle-aligned walking cutoff or stopping tail. This is a valid development
negative, not walking acceptance or evidence of a successful MuJoCo controller.

Three new retained-data tests cross-check all **1,596 limb samples** against
native measured geometry (maximum hinge-FK foot-bottom difference **5.97e-16 m**).
In **182 of 241 absent stance inputs**, the selected inherited virtual-upright
target places that foot above the floor in the measured body orientation.
**169** of those have zero common lowering in the separately computed
measured-pose reference. At command 160, rear-right's selected target is
**2.676 mm above the floor**, while its measured-pose support target reaches the
floor. Static support margin alone did not repair this reference mismatch.
Geometry still does not substitute for native contact truth or prove sole cause.

Next: implement a distinct measured-pose support successor retaining V45's
measured support-transfer gate, native contact inputs, motor bounds and finite
timeout. Validate unchanged V45 outputs and the new geometry/hold transition
before one fresh bounded MuJoCo diagnostic. Do not extend this consumed run's
timeout or alter its interpretation. SDK1 remains **14/20**; M07 acceptance,
owner licensing, native Explorer and package gates remain open.

## Prior boundary — V45 implementation freeze, 2026-09-10

The [V45 implementation record](../sdk/development/v45_measured_support_transfer_implementation_v1.json)
binds a separate DLL, **353/353 Rust tests**, **400 byte-exact unchanged V44
responses**, all 400 V45 stateless/cached measured-body inputs, and **17/17
complete affected-route safety tests**. The new strict v3 C ABI/Python entry
accepts synchronized measurements of all nine bodies. It computes measured COM
and velocity, holds the next swing until a 20 mm remaining-triangle margin and
body-motion/contact conditions hold for six samples, and adjusts a bounded common
hip reference toward 25 mm margin. The inherited support-loss timeout remains.
These are controller parameters; geometry never replaces native contact truth.

The [distinct MuJoCo declaration](../sdk/development/v45_mujoco_closed_loop_v1.json)
uses the same explicit V44 initial native-state projection in one fresh world,
with V45's own measured feedback. Maximum: 1,600 walking commands, then exactly
120 stopping commands after all four released swings actually leave support and
return during stance. The walking cutoff requires all four feet supported and
all four phases in stance. The final 30 stopping samples must meet the declared
four-contact, COM-speed, angular-speed and tilt conditions. Full native telemetry
and a separate no-world reader are required. A controller refusal writes exact
request/response bytes, clears native controls and terminates without another
solver step. Synthetic gate fixtures include the refusal and complete stopping
paths; **no V45 physical result exists at this boundary**.

Next: clean pushed freeze, complete launch gate, one fresh declared diagnostic,
then retain and close its result. Godot V45 recovery integration is not selected.
SDK1 remains **14/20**; M07 acceptance, the owner's licensing decision, native
Explorer proof and the final package gates remain open. The V44 observations,
original acceptance checks, release contract and support matrix are unchanged.

## Prior boundary — V44 MuJoCo contact replay closed, 2026-09-10

The [fixed-command replay closure](../sdk/development/v44_mujoco_fixed_command_closure_v1.json)
retains one fresh MuJoCo world from clean, pushed `5992d244`: **12/12 safety
tests, 400 recorded V44 commands, 2,000 native steps, zero warnings**, and a
separate cold-reader pass with zero worlds/steps. The worker took **7.343 s**.
All four feet initially bore positive support; the largest body-position
projection error was **0.3965 mm** (link velocity mismatch up to 0.00902 m/s).

**Both rear feet also lose support in MuJoCo.** Rear-right first loses all
five-substep bearing at command **24**, rear-left at **35**, both labeled
stance in the recorded source schedule. Rear-left has **190** outer samples
without any positive-force foot support, all source-labeled stance; rear-right
has **101**, including **28** source-labeled stance. Any-substep and final-substep
contact channels remain separately retained. No hidden initial settling or
height offset was used. The starting state, XML, every requested command,
force/contact sample, body/joint state, stdout/stderr and runtime/source
bindings are retained in the closure.

This weakens an exclusively Jolt-contact explanation for the recorded command
stream. It does **not** isolate controller geometry from motor/contact response,
prove a Jolt bug, or test V44 closed-loop behavior on MuJoCo feedback. The later
open-loop trajectory diverges substantially. The earlier venv-launcher refusal
`bd34f810` remains consumed, with zero model constructions and zero steps.

The [checked pre-liftoff diagnosis](../sdk/development/v44_pre_liftoff_diagnosis_closure_v1.json)
passes three retained-data tests over all 400 precommand rows. At the first
active wave command (2; command 1 has zero amplitude), measured COM is only
**1.470 mm inside the three-contact triangle excluding front-left**. Its margin
is **3.663 mm** at the last bearing front-left input (18), and **2.188 mm**
at the last bearing rear-right input (23). Rear-right is absent at input 24.
The margin uses impulse-weighted native contact points; hypothetical capsule
endpoint geometry remains separately labeled. This is a narrow static margin,
not proof of dynamic instability or a successful proposed controller.

A rigid-hinge reconstruction from the existing walking StateFrame has maximum
COM position error **0.472 mm**, COM velocity error **72.15 mm/s**, and individual
body-center error **6.614 mm**. Measured body-mass reconstruction agrees with
native COM position within **1.020e-7 m**. Therefore the next policy must use
measured COM/body motion and actual foot geometry for support transfer and
velocity damping; ideal hinge velocity is not a substitute measurement.

The next implementation boundary is a distinct measured-support-transfer
successor: finite all-contact preparation, deliberate COM placement inside the
remaining support triangle before liftoff, body-velocity damping, then one
declared gait cycle and bounded stop/settle. Reuse the existing native observation
and portable stability representations where possible. Freeze its thresholds,
source/input channels, timeout, cycle completion and stopping budget before its
first new world. Keep V44's policy, 400-command evidence and evaluator immutable.

**Next: implement and gate the measured-support-transfer successor.** A future walk termination needs a
prospective bounded stop/settle phase; neither old cutoff is regraded. SDK1
remains **14/20**; no acceptance/support/release authority changed. M14's owner
license/copyright decision remains open.

[Closed-evidence compression is complete](../sdk/development/closed_evidence_ntfs_maintenance_closure_v1.json):
**33 closed attempts / 165 large text files**, preserving every original path,
logical byte and complete inventory digest. NTFS compression recovered
**18,437,017,600 bytes (18.44 GB / 17.17 GiB)** including the pilot. The V44
report passed all three existing retained-data tests after compression and its
decompression/restore check. Fourteen closure records with unsupported inventory
schemas, unregistered evidence, executables and directory inheritance were
left outside this bounded maintenance scope. Nothing was deleted.

## Historical V44 closure: support releases, stance interruptions remain

[V44 attempt b308b58a](../sdk/development/recovery_attempts/b308b58a36144525866e2f96b2abe0be.json)
ran from clean, pushed `50c76790`: **132/132 safety checks**, one fresh
seed-40200 SingleKick, **1,258 solver steps**, standing transition at 858 and
**400 resumed-walking commands**. Engine stderr is empty. Independent replay
validates all 1,258 transitions, 430 native contact rows and 400 resumed
commands. All **73 files / 1,129,966,250 bytes** are retained. This is a valid
complete development observation with a **negative walking evaluation**, not
complete-route or M07 acceptance.

The [support diagnosis](../sdk/development/recovery_v44_support_diagnosis_v1.json)
finds **258 held commands, 13 releases, a longest hold of 53 commands** and a
final open three-command hold. Forward advance is **75.65 mm** and maximum
walking tilt **0.01925 rad (1.10 degrees)**. The original failures remain
`every_limb_forward_relocation` and `terminal_four_contact_recovery`.
There are **44 contact losses, 26 with scheduled-stance onset**. Of 30 counted
cycles, 22 miss 12 mm relocation and 12 go backward. The final front-left loss
starts in stance at 397; rear-right starts in swing at 388. A cutoff-only
explanation is insufficient.

Three retained-data checks pass, including independent reconstruction of all
3,200 motor commands (maximum error 6.515e-13 rad/s), original cycle counts/minima
and five crossed-data refusals. Two failed diagnostic assertions and their
sources are retained. No original evaluator, threshold, DLL or observed record
changed. Fresh readiness is **14/20 SDK1, 14/25 full program, zero invalid
proofs**; R173 and release/support bytes remain unchanged.

**Next: the bounded MuJoCo fixed-command stance/contact replay before another
controller variant.** Bind the actual recovery morphology, actuator caps,
material interpretation, initial pose/twist projection, frame conversion and
contact observations; pass the complete applicable zero-world gate before its
fresh native attempt. Replaying Jolt-recorded commands and running V44 on
MuJoCo's own feedback are different questions. Neither alone establishes
cross-engine equivalence or identifies a Jolt defect. The stopping route still
needs an explicit prospective stop/settle phase with a hard timeout; do not
regrade this cutoff or extend a consumed run.

Absent scheduled-stance inputs number 42 front-left, 35 front-right, 40 rear-left
and 131 rear-right. All 248 lack raw native contact samples. Maximum nominal
capsule-bottom heights in those populations are 3.819, 2.358, 1.681 and 6.141 mm
respectively. Nominal geometry never substitutes for contact or impulse.
Ideal-joint versus measured-body bottom discrepancy reaches 2.711 mm across
the full population. The frame conversion records 1.586e-7 maximum axis error;
its 16-binary32-epsilon roundoff guard is an engineering check, not a physical
acceptance threshold. Original cycle relocation starts at the first absent
post-step sample, not the last supported sample.

For the MuJoCo screen, match the recovery body's ranges and anchors as well as
its base descriptor. Bind requested velocities and native readback rounding
separately. The development declaration must expose the one-time initial-state
projection and the material mapping. No new physical authority comes from
this prose; the fresh declaration and safety gate precede model construction.

## Profile-driven recovery development

The shared contract is `sdk/development_recovery_candidate_contract_v1.json`;
candidate data lives under `sdk/development/recovery_candidates/`. A profile
binds the selected post-kick controller, runtime manifest, DLL and extension
hashes. V6 setup, the native energy ancestry, caps and official gates are not
candidate-configurable. The common worker and reader consume the same profile;
compiled Rust still decides whether a controller is actually registered.

Use PowerShell from the canonical repository:

```powershell
./sdk/run_development_recovery_smoke.ps1 -ProfileSteps -ReuseContextChecks `
  -CandidateProfile sdk/development/recovery_candidates/v8_harness_v1.json
```

Without `-RunSmoke`, this runs only the complete applicable zero-world gate.
With `-RunSmoke`, the default creates both roles fresh. Add `-SingleKick` only
for the explicitly non-comparative controller question: it creates fresh setup
and one kicked child, retains the full bounded trajectory and independently
replays it. It does not establish a causal effect, a matched comparison, full
paired commissioning, or acceptance. A paired declaration missing its baseline
is still rejected. No physical baseline is cached.

This was chosen over continued per-controller worker/reader copies to remove
repeated integration work. The cost is one shared surface requiring regression
checks; old entrypoints retain their default closed schemas and observed bytes.
Candidate-specific controller math belongs in Rust tests, while common worker,
transport, negative-control and reader tests are parameterized over the profile.
The build helper `sdk/conformance/development_recovery_candidate_build.py`
retains new compiler logs and DLLs, then emits a create-only declaration patch;
it cannot launch physics. Processing-hotspot optimization and question-specific
early stopping remain follow-ups, not prerequisites for the next recovery test.

Integration evidence is retained under
`SporeSpore_Evidence/development-candidate-integration-21fac302ef954c70a9ddab564a52deae`:
24 connected candidate tests, seven original V8 runtime checks and three cold
V8 closure checks pass. The candidate replay covers a 286-step synthetic
timeline and rejects 34 corruptions; its Python subprocess receipt is consumed
independently. The final controller-format refusal check passes under
`development-candidate-integration-final-4dd0243cb32b443c825512339e51b982`.
That refactor checkpoint is zero-world integration, not physical commissioning.
V9 subsequently exercised the common build helper and a new compiled identity
through the fresh single-child diagnostic described below.
R173's digest is unchanged; readiness rechecks at 14/20 and 14/25, zero invalid
proofs. These engineering changes neither earn nor remove a behavior point.

## Development runtime performance boundary

The candidate builder now accepts `--reuse-build-cache` in addition to the
explicit compiler profile. Compilation uses a mutable repository-local directory
partitioned by compiler/Cargo versions, build mode, selected build-environment
fingerprints and repository Cargo configuration. Cargo still checks dependencies
on every invocation; the full core tests and six fixtures run anew. This is not
an evidence/qualification cache or a claim that the partition key describes all
compiler dependencies. The exact source population and output DLL are separately
bound, and the applicable runtime/smoke checks remain required.

Each result is copied into an independent, create-only per-candidate DLL and an
independent durable evidence DLL. No extension points into the mutable cache;
old candidates cannot be overwritten by a later build. Default builds remain
unchanged. [The cold/warm control receipt](../sdk/development/recovery_build_cache_v1.json)
records 253.109 s versus 1.765 s for the three build stages with unchanged Rust
source. Both run 234 core tests and six fixtures. Their copied DLLs match each
other exactly, all six original V11 fixtures are preserved, and four connected
runtime checks pass. Original V11 remains immutable. Changed-controller build
time, full iteration time, and physical speedup are not measured by this pair.

The `v11-compiler-cache-cold-v1` and `v11-compiler-cache-warm-v1` profiles are
zero-world build controls, not new physical V11 attempts. Use the cache option
for a fresh controller build; do not turn those controls into V11 reruns.

`ss_canonicalize_json` now obtains its canonical string and digest from the
same conversion. The canonical-number projection, sorting, serialization,
hashed bytes, receipt schema and refusal rules are unchanged. No cache,
tolerance, sampling reduction or physics-input change is introduced.

The immutable candidate builder accepts `--build-profile release` for an
optimized Rust core/adapter; it still defaults to the original debug mode.
Tests and adapter compilation use the same explicit mode, recorded in retained
commands, and the profile binds the exact new DLL. The `.gdextension` can load
this optimized DLL in the existing development Godot process. Compiler
"release" mode is not SDK release, qualification or acceptance authority.
The default pinned extension and all previous artifacts remain untouched.

The two `v9-canonical-single-pass-*` profiles are zero-world performance/control
artifacts, not a new V9 physical outcome or permission to repeat its consumed
attempt. Future controller changes require fresh build/profile identities.
Both builds pass 220 core tests; the optimized image also preserves six old
controller fixture outputs and passes the shared runtime/worker/reader checks.
The optional retained-data benchmark has no physical entrypoint and is not an
extra mandatory smoke gate. Its [receipt and limitations](../sdk/development/recovery_performance_v1.json)
separate local operation timings from unmeasured whole-run performance.

The recursive GDScript comparator remains an explicitly unused experiment:
its large-string microbenchmark improved but its complete retained reader
regressed. The production reader retains its original comparison. No observed
record, threshold, claim or independent replay has been replaced.

## Support posture during a finite walking hold

The [V44 component and complete retained geometry](../sdk/development/recovery_support_hold_posture_component_v1.json)
close the rear-right stall diagnosis at development authority. V43's final
120 saved precommand inputs have no rear-right supporting contact. Its last
nominal capsule bottom is 71.04 mm above the floor, while its joint positions
differ from the current targets by at most 0.000833 rad, without clipping.
The upright-reference target evaluated at the actual tilted torso predicts
70.90 mm clearance. Even full extension along the requested leg direction
leaves 61.34 mm. This is a reference/body-posture problem to test, not proof
that changing a single joint target would restore contact. Geometry uses the
retained native anatomical quaternion; the walking-basis mapping is checked
over all 704 leg samples. Capsule geometry never replaces contact truth.

The [V44 contract](../sdk/development/recovery_support_hold_posture_contract_v1.json)
adds one policy-selected change: while the unchanged V43 guard holds, select
the existing upright support reference for every limb and remove walking
knee lift from that reference. Keep nominal leg directions, scheduled phases,
feasible-height arithmetic, target slew, gains, caps and the guard lifecycle.
This also addresses the front-left leg staying bent during the opposite
rear-right support deficit. It is a posture request, not force-aware control.

Keep the scheduled wave in memory. Record the effective no-lift wave separately
and apply the same current hold mode to both reference evaluations, preventing
a mode switch from masquerading as gait-wave feedforward. An upright reference
selection during swing does not alter the ordinary stance-latch decision or
create supporting contact. Non-held commands match V43 for identical inputs
and reference memory; all 176 original V43 and 4,800 older-policy responses
remain byte-exact under the new DLL.

The 347 core checks and five exported-interface checks pass. The latter cover
both interfaces, independently reconstructed motor math, one-command and
chained-reference substitutions, six unchanged recovery fixtures, eight safe
refusals and four malformed-transport refusals. The first new assertion failed
because two different goals initially hit the same existing slew cap; its
original source/logs remain bound. Neither substitution predicts another
trajectory. The original missing next V43 response is still unknown.

The new profile is component-only and cannot select physics. Shared route
integration, a fresh complete source binding including refusal retention, the
applicable full safety gate and a clean pushed freeze precede the next fresh
SingleKick. Support may still fail, recur after release or prevent forward
progress. No timeout, horizon, threshold, release score or old result changes.

## Development native refusal retention

The [failure-retention implementation](../sdk/development/recovery_native_step_failure_retention_v1.json)
adds a failure-only development path, not a permissive normal-receipt schema.
The shared recovery facade enables it only after explicit development-policy
and native-profile validation; default adapters and the actual legacy facade
leave it disabled. Successful command responses are unchanged.

The adapter stores exact request, native response and initial verification
strings before interpreting the failure. Its existing native verifier checks
the distinct generic error receipt. The new helper additionally binds the
request step/command, compiled morphology and adapter capability; requires an
explicit no-actuation flag, nonempty consistent failure codes/error, exactly
the compiled ordered motors with zero target/residual/safety velocities, and
unchanged incoming memory. Numeric comparisons are exact, not approximate;
an integral JSON zero and a floating JSON zero can represent the same value.
Missing/empty identities do not match merely because both sides omit them.

A verified refusal returns `ok=false` with
`ADAPTER_NATIVE_VERIFIED_ZERO_ACTUATION_REFUSAL`. Malformed or unverified
responses also remain failures, with their raw bytes preserved. Neither
returns an actuation value, advances adapter memory/step count, or reaches
motor application. The actual facade's early-return wrapper and the existing
worker partial-arm JSON projection retain the record. A cold checker recreates
the classification and refuses forged fields or altered byte bindings.

Three new tests pass in 28.40 s through the selected candidate runtime and real
adapter: all 176 retained V43 normal responses are unchanged, the explicitly
synthetic counter boundary keeps its native timeout reason and unchanged
memory, 23 malformed/altered-response cases refuse, and six forged records
refuse. Four original default-path checks also pass. The legacy differential
finds no new failures but preserves the historical suite's three failures and
one error. Total targeted validation is eight checks / 95.99 s. The first
compile-error attempt, two intermediate passing checks, final checks and exact
tested source populations are retained: 96 files / 13,919,093 bytes.

The three-test check is mandatory in the development runner whenever a walking
policy is explicitly selected. It probes the generic refusal interface using
the frozen V43 case on the selected candidate DLL; the selected controller's
behavior still requires its own candidate checks. No DLL rebuild, native
physics query, world or solver step ran. This is zero-world failure-path proof,
not a complete physical route, successful recovery or qualification reuse.

The remaining control question is the rear-right support stall. Diagnose the
retained final V43 hold window and implement a distinct bounded correction
before creating another physical profile. The original V43 profile now
correctly refuses changed adapter source with
`DEVELOPMENT_CANDIDATE_WALKING_ENTRY_CONTRACT_DRIFT`; preserve that original
binding. A fresh entry contract must include the failure helper and contract
in its complete dependency key and pass the full applicable gate before a new
physical diagnostic. Old results, hold limits, horizons, evaluators, official
gates, R173 and release/support records are unchanged. Readiness is 14/20 SDK1,
14/25 full program.

## V43 incomplete physical closure and safe-stop diagnosis

Historical diagnosis; the subsequent refusal-retention fix is recorded above.

The [original V43 child](../sdk/development/recovery_attempts/b72c4d6447704de49bbc6c348c0f8ff0.json)
is closed as invalid/incomplete, never as a successful route or a complete
behavior negative. Its fresh 114-check gate passed; it then ran 1,034 solver
steps, reached the standing-to-walking transition at 858, and retained 176
walking commands. No walking evaluator or independent complete-route replay
ran. Total elapsed time was 26 min 31 s: 15 min 26 s for the gate and 9 min
28 s for the physical child. The shorter child is an early failure, not a
measured runtime speedup. All 62 original files / 994,710,390 bytes are bound.

The controller paused all gait clocks on 143 of those 176 commands. It
released once at local step 47; the final retained receipt records incoming
hold count 119, outgoing count 120 and missing rear-right support. These are
retained-prefix observations, not an evaluation of a completed walking route.
The next frame plan failed with
`GODOT_ADAPTER_NATIVE_STEP_VERIFICATION_RECEIPT_SCHEMA_MISMATCH`; its raw
request/response were not retained, so its hidden controller error is unknown.

The [separate diagnostic](../sdk/development/recovery_v43_safe_stop_diagnosis_v1.json)
reproduces every retained command's raw response hash through both C ABI
interfaces, reconstructs the support guard and parent control math, and checks
the decoded memory chain: 176 commands, 143 holds, zero motor discrepancy.
It then changes only incoming `held_steps` from 119 to 120 on the known
local-step-176 input. That synthetic boundary is explicitly **not** a
reconstruction of missing physical command 177. The exact DLL emits
`CAPABILITY_UNSUPPORTED:support_progression_hold_timeout`, eight zero motor
velocities, unchanged memory and the generic controller receipt schema.
The real native verifier and shared Godot adapter reject that schema while
accepting the unchanged normal input. Wrong policy, wrong step and a changed
error with an unchanged digest also refuse. Four focused tests pass in
35.45 s, with no world, native physics query or solver step.

The first test attempt is retained separately. One assertion confused three
nested integer-zero versus floating-zero Variant representations; the corrected
test compares exact numeric values without tolerance and still checks raw
native bytes. An unintentionally discovered imported historical suite also
refused its own old runtime; explicit four-test selection removes that unrelated
discovery. Neither correction changes the production adapter or old evidence.

The bounded next work has two blockers: (1) retain exact failed request/response
bytes and propagate a verified native refusal through the shared development
failure path, without accepting it as normal actuation or weakening the
official gate; (2) diagnose the rear-right support stall and select a distinct
bounded controller correction. Do not extend the hold limit, walking budget
or horizon. The interface mechanism is reproduced, but the original hidden
error is not proved and no production fix is yet implemented. R173 and the
release/support records remain byte-exact; SDK1/full readiness is 14/20, 14/25.

## V43 prospective shared-route integration

Historical prospective checkpoint; the subsequent physical result and next
work are recorded in the V43 incomplete-child section immediately above.

**Full-gate update:** attempt
[491a30fb](../sdk/development/recovery_attempts/491a30fb3dcd4e859d3850aa11664a3e.json)
stopped before physics: 77 checks passed in preceding stages, then the
four-test schedule stage had three passes and one error. Its coverage test
omitted V43 from the inherited-budget list. The
[test-only correction](../sdk/development/recovery_support_progression_gate_fix_v1.json)
passes all four targeted checks in **35.60 s**, including preservation of the
original attempt. Review also caught two analogous walking-entry test-list
omissions before another full gate; all **six walking-entry checks pass in
39.00 s** after their registration fix. Production source, DLL, profile,
schedule and evaluator are
unchanged by this correction. **Next is a fresh full gate, not reuse of the
consumed attempt.** No physical child, world or solver step started.

The [integration record](../sdk/development/recovery_support_progression_ledger_integration_v1.json)
binds the distinct runnable profile, unchanged V43 DLL, 29 source dependencies,
and all successful/failed focused checks. No production worker or reader was
cloned, no native controller was rebuilt, and no old physical result was edited.

The actual adapter/motor-ledger and independent reader exercise 200 synthetic
commands. All original native-response hashes and decoded memory links match;
the independent scheduler/reference/motor reconstruction has zero observed
motor discrepancy. This input sequence contains 45 held commands and four
released hold windows. All 54 existing floor/rate/geometry/latch corruption
cases and 20 added progression-receipt/memory corruptions refuse, including
self-consistently rehashed receipts. These counts describe synthetic coverage,
not likely physical behavior.

Three integration failures are retained with their tested source snapshots:

- A missing V43 branch in the motor ledger's expected-schema mapping caused
  its identity predicate to refuse. The explicit caller-selected branch fixes
  it without changing any predicate.
- A new Python comparison mixed raw Rust values with Godot-decoded values.
  All 200 raw hashes already matched; decoded motor fields differed by at most
  4.44e-16. The corrected test verifies the raw hashes before native arithmetic.
  The production reader and exact parsed-memory checks are unchanged.
- The startup fixture kept one foot absent forever while requiring 450 valid
  commands. V43 safely refused after 320 valid commands at its 120-command
  hold limit. That output is preserved. V43's startup-success fixture now uses
  a declared synthetic absence at commands 61..150 followed by recontact;
  all 450 commands pass. Separate native timeout checks remain mandatory.

The adapter fixture likewise supplies finite synthetic loss/recontact windows.
It is not a changed physical trace. The shared route, profile selection,
startup, and unchanged 44-case legacy-source differential pass. The declared
full gate has **114 checks** and is still pending at this prospective boundary.
The retained focused population is **189 files / 1,273,858,814 bytes**, with
readiness separately bound; every test stays development-only.

The next physical question is whether truthful-support waiting helps recovery
without exhausting forward progress. Use one fresh seed-40200 SingleKick,
the same 986-step tail, 1,338-step child cap and 400-command walking budget.
Report hold/release counts and semantic versus gait progress alongside the
original relocation, contact, clipping, posture and terminal-support criteria.
No cached baseline, paired effect, force-aware recovery, horizon extension,
acceptance or release claim is authorized. R173 and release/support bytes stay
exact; readiness remains **14/20, 14/25**, zero invalid proofs.

## V43 native support-aware phase progression

The [V43 native component](../sdk/development/recovery_support_progression_component_v1.json)
implements the bounded scheduling question selected by V42's diagnosis. Its
[prospective contract](../sdk/development/recovery_support_progression_contract_v1.json)
remains the pre-verification record; the component closure supersedes that
record's implementation-pending fields. The distinct policy/profile/memory
and actuation identities do not change the old policies or public support.

The new interlock previews the **existing scheduler's** next phases. During
an active current or imminent swing, a proposed-stance foot without explicit
present-and-bearing contact holds all four gait clocks and gate counters.
Semantic/sample time continues; normal bounded joint commands and V42's
reference math still run. No contact is fabricated, latched or smoothed.
The reference-selection latch remains a separate V42 mechanism.

A fresh clear state proceeds immediately. Once held, three consecutive clear
samples release it; interrupted clear dwell starts over. The hold permits at
most 120 held commands, including clear-dwell commands. Another required hold
returns an explicit timeout, safe no actuation and unchanged memory. A ready
third clear sample can release at the limit. Zero-amplitude waves or no
current/proposed swing disable/reset this interlock. The numbers reuse the
existing scheduler's dwell/hold constants as prospective engineering limits,
not acceptance thresholds or estimates of physical stability.

Five added core cases cover phase boundaries/wrap, truthful missing and
nonbearing support, interrupted release, finite timeout, disabled behavior,
malformed/crossed memory, continued nonzero bounded commands during holds,
and exact parent commands/gate memory when no hold is needed. All **342 core
tests pass**. The cached compiler performs fresh work: **81.89 s** core stage,
**0.31 s** fixture stage and **60.30 s** adapter build. The new DLL is an
independent durable copy; the old DLL and mutable compiler cache are not its
published identity.

Four exported-interface checks pass in **31.36 s**:

| Check | Result and scope |
| --- | --- |
| Original V42 inputs, one-command substitutions | All 400 checked; 220 select a hold |
| Separate candidate-memory sequence on the saved observations | All 400 checked; 315 holds; no refusal |
| Stateless versus persistent native interface | Exact raw output agreement for both populations |
| Scheduler/reference/motor reconstruction | Decision and phases checked against truthful contacts and the unchanged parent preview; downstream V42 math reused on the actual candidate wave; maximum observed motor discrepancy 0 rad/s |
| Older-policy compatibility | 4,800 byte-exact outputs across 12 policies, with zero refusals in this checked population |
| Recovery fixtures | All six match the prior runtime |
| Invalid/bounded-limit controls | Nine safe refusals with unchanged memory/zero motor rates; four malformed transport refusals |

**These are saved-input component tests, not a different physical trajectory.**
The saved body/contact states do not respond to the candidate's changed
commands. The high hold count may translate into poor forward progress or a
timeout in physics; a held clock need not recover a missing foot. All old V42
failures remain unchanged, and successful recovery is not proved.

The closure binds **26 build/source/test evidence files / 10,073,801 bytes**, including the
pre-build owned-source copies, original generated declaration draft, compiler
logs, DLL, exact tested Python source and native output logs. The published
profile is component-only/non-runnable and retains the actual unchanged V20
post-kick identity. No world, solver step or native physics read ran.
The final cold audit is separately bound: all source/runtime/evidence digests
and native test receipts match, and fresh readiness remains 14/20 and 14/25
with five missing, one contradicted and zero invalid proofs.

**Next:** integrate the exact verified component through the shared
profile-selected worker, floor/start/entry records, motor ledger and replay
reader. Test new memory/receipt rejection and keep held gait clocks distinct
from elapsed solver/semantic steps. Preserve bounded refusals and every old
profile; do not clone the harness. The complete applicable development safety
gate precedes any fresh SingleKick selection. No physical attempt is selected
at this component boundary. Force-aware whole-body recovery remains SDK2;
SDK1/full readiness remains **14/20, 14/25** and R173/release/support bytes are
unchanged.

## V42 retained relocation diagnosis

The [complete retained-data diagnosis](../sdk/development/recovery_v42_relocation_diagnosis_v1.json)
accounts for **all 400 commands, 1,600 limb inputs and 3,200 joint commands**
from the unchanged V42 result. It reconstructs the original evaluator's
**19 counted cycles**, their minima and the terminal open flight. All **26
contact losses** are included: 19 counted cycles, six shorter completed losses
and one open flight. **20 losses begin during scheduled stance.** Of the 19
counted cycles, 13 fall below the original +12 mm requirement; six move
backward. Neither counting a short stance loss nor explaining one removes
it from the original evaluator.

The table includes **every counted backward event**, not a selected subset.
Trace steps are local to resumed walking; add 858 for global solver steps.
"Absent samples" counts post-solver samples without the original qualified
contact. A foot position here is the distal-body origin, not a ground contact
point. Relocation starts at the first absent sample, exactly as in the
original evaluator.

| Foot | Loss to recontact, local steps | Absent samples | Scheduled phase during interval | Forward relocation | Speed-clipped joint commands, onset through landing |
| --- | ---: | ---: | --- | ---: | ---: |
| Front-left | 18–24 | 6 | Swing, phases 17–23 | -3.36 mm | 6 |
| Rear-left | 93–100 | 7 | Stance, phases 182–189 | -5.18 mm | 0 |
| Rear-left | 199–203 | 4 | Stance, phases 288–292 | -0.33 mm | 0 |
| Rear-left | 365–397 | 32 | Stance, phases 90–122 | -64.41 mm | 0 |
| Rear-right | 23–39 | 16 | Stance, phases 292–308 | -23.87 mm | 4 |
| Rear-right | 54–88 | 34 | Stance, phases 323–357 | -5.82 mm | 8 |

The largest backward interval has **no speed clipping** and retains the
upright reference for all 32 absent-contact inputs. Its measured motion can
be written as body translation, body rotation and movement relative to the
body. The two possible orders of the last two terms give:

- body translation: **-13.24 mm**;
- body rotation: **-41.24 to -41.59 mm**;
- body-relative foot movement: **-9.58 to -9.93 mm**.

Each order sums to the same **-64.41 mm**. Heading changes by **12.95 degrees**
during that interval. The rotation term includes the full measured torso
orientation, not yaw alone; relative movement includes articulation and
constraint compliance. These are coordinate identities, **not causal shares**
or evidence that another controller would prevent the motion.

There is a concrete scheduling concern to test next. At command **365**,
front-left enters scheduled phase **0** while front-right's precommand
contact is already absent. Rear-left then loses contact in that solver step.
The phase clocks keep advancing through those support gaps. The current
shared scheduler checks each foot at its release/recontact gates; it does
not require the other scheduled-stance feet to remain in contact before a
swing proceeds. This code observation does not prove that a new hold will
restore support.

The terminal front-left flight starts at trace **395** and remains open at
the original **400** cutoff; its final command is scheduled swing phase **35**.
No recontact or next-command torso pose is invented. The original terminal
four-contact failure remains false.

**Verification:** six focused tests pass in **4.96 s**. All 3,200 commands
reconstruct with maximum motor-rate difference **1.01e-12 rad/s** (rounded
up; existing arithmetic allowance 1e-10). Tests cover the complete population,
both motion-accounting orders, independent simple translation/rotation cases,
partial/open flights, and refusal of altered motor, clipping, memory, phase,
contact and original-minimum fields. The full 1,582,436-byte timeline and
source-bound test receipts remain under the declared evidence root, with
their exact paths and digests in the repository diagnosis. No native call,
world, solver step, old-result edit, gate change or support promotion occurred.

**Historical selection, now implemented as the component above:** design and test a **distinct support-aware
phase-progression component** using the existing shared scheduler. Its narrow
question is whether scheduled swing progression can be held when another
scheduled-stance foot lacks truthful contact. Define bounded hold, release,
timeout and phase-wrap behavior; keep measuring contact and applying bounded
joint-only support commands while held. Preserve older policies, gains, caps,
evaluators and all observed records. Use saved V42 inputs and synthetic
boundary cases to test code paths, not predict a different physical outcome.
A hold may fail to regain contact or harm progress; no physical attempt is
selected until the component and applicable route/safety checks are ready.
Force-aware whole-body recovery remains SDK2 work. SDK1/full readiness remains
**14/20, 14/25**; protected R173 and release/support bytes are unchanged.

## V42 physical result and next diagnosis

The [V42 closure](../sdk/development/recovery_attempts/6514ace221e547c6b7b69e2d6bbdebaa.json)
is **closed_consumed_valid_development_observation**. Source
`ee6d83fb8306ef0677c1e4008f23ef15cc219e3c` was clean and pushed before execution.
All **113 applicable safety checks** passed. The single fresh seed-40200
Godot/Jolt child took **1,258 solver steps**, reached standing at step **858**
and completed the unchanged **400-command** walking tail. Independent replay
checks all 1,258 transitions, 400 walking commands and 430 native-contact
steps; engine health and the final supervisor audit pass. The exact
**65-file / 1,117,027,268-byte** retained population stays under
`SporeSpore_Evidence/development-recovery-smoke-6514ace221e547c6b7b69e2d6bbdebaa`.

**The behavioral result is still negative:** the original evaluator rejects
every-foot forward relocation and terminal four-foot contact. All original
criteria, including these failures, remain unchanged. No torso contact or
native contact-gate timeout occurs in resumed walking. A completed diagnostic
and exact replay do not make the recovery feature accepted.

The [descriptive observation](../sdk/development/recovery_stance_latch_observation_v1.json)
retains the original evaluation and explicit count definitions over all 400
native receipts. The small comparison below is between **separate development
trajectories**, not a matched experiment, causal effect or superiority test.

| Measurement | V41 | V42 |
| --- | ---: | ---: |
| Per-foot reference-selection switches between commands | 108 | 11 |
| Joint commands clipped at the unchanged speed limit | 246 | 99 |
| Forward body advance | 11.32 cm | 10.56 cm |
| Absolute sideways drift | 0.55 cm | 2.70 cm |
| Heading drift | 5.20 degrees | 15.94 degrees |
| Largest torso tilt | 4.72 degrees | 6.51 degrees |
| Original failed walking criteria | Forward foot relocation; final four-foot contact | Same two |

V42 selects the upright reference on **1,253 limb inputs**, including **300
with actual contact absent**. Those absent contacts remain absent in every
observation and in independent replay; the latch preserves only the reference
choice. Reduced switching/clipping does not establish better locomotion.

The original evaluator's worst completed observed lift-and-land relocation
is **-3.36 mm front-left**, **+12.16 mm front-right**, **-64.41 mm rear-left**
and **-23.87 mm rear-right**, against its unchanged **+12 mm** minimum.
Negative means the foot landed behind its observed lift-off point along the
requested forward direction. These observed contact cycles need not be
planned gait cycles. At the endpoint the front-left still has an open
observed flight; its final precommand scheduled phase is **35** (swing).
The other three final precommand observations bear support. Keep the
precommand receipt and postcommand evaluated endpoint distinct.

Timing is **2,042.483 s** overall, **890.995 s** safety gate, **707.638 s**
physical child and **290.110 s** independent replay. Earlier focused timeout
and fixture failures remain in the prospective integration record below;
the complete safety gate subsequently passed without dropping checks.

**Historical selection, now completed above:** inspect the retained V42 backward landing events,
their scheduled phase/contact intervals, reference/rate selection and body
rotation. Distinguish planned swing from unplanned stance contact gaps and
from the terminal horizon cutoff. Do not choose a V43 correction, claim a
cause, extend a horizon, regrade V42 or run another physical attempt before
that bounded diagnosis. Whole-body force-aware recovery remains SDK2 work.

R173 and the official release/support records remain byte-exact. SDK1 remains
**14/20**, full program **14/25**; no acceptance, equivalence, superiority or
release claim advances.

The final cold audit reproduces the closure and its **65 retained files**,
and rejects forged solver-step counts, physical-acceptance authority and
successful-recovery claims. It runs no new world or solver step. The audit
receipt and fresh readiness report are retained under
`SporeSpore_Evidence/development-v42-final-audit-aca1065d642a4a648aa8d25abfcec533/`:
**five missing, one contradicted and zero invalid proofs**. The descriptive
counts and original evaluation were also checked against all 400 retained
command rows and all 3,200 joint commands.
The audit receipt SHA256 is
`6c4d587f2c42a1db83a2eea13765c32311c7716226473ee1d71d60392cc415f7`;
the readiness report SHA256 is
`9ef1e0967c1c1f1fca35534d052f4782b6dce631c87d1944e2b9c5a8a2f39ffa`.

## V42 prospective shared-route integration

Historical prospective boundary: the physical closure above supersedes this
section's full-gate/physical-next pointer; its original failures remain intact.

The [integration record](../sdk/development/recovery_stance_latch_ledger_integration_v1.json)
selects [v42-stance-latch-integrated-v1](../sdk/development/recovery_candidates/v42-stance-latch-integrated-v1.json).
It connects the already-verified DLL to the shared profile loader, start/entry
contracts, adapter, worker, motor ledger and independent native reader.
The ledger and memory checks derive V42's schema from the selected policy.
No worker or reader was cloned, and no native DLL, gain, contact observation,
motor cap, physical schedule or evaluator changed during integration.

**Completed focused checks:** five launcher/profile checks in **6.749 s**,
four corrected worker/route checks in **31.093 s**, and the unchanged legacy
source differential in **40.631 s**. The last compares the same 44-case
historical suite against its frozen baseline; it finds no new failures, not
an entirely green historical official-source suite.

The real adapter produced **200 synthetic commands / 1,600 joint commands**.
Independent reconstruction verifies the latch lifecycle, memory chain,
reference choices, rate selection and motor output: **590 selected limb
inputs**, including **230 with truthful absent contact**, five selector
transitions and maximum motor arithmetic difference **4.33e-14 rad/s**.
The cold reader rejects **54 altered cases** covering floor provenance,
actual-contact rates, both geometry plans, latch receipts and memory.
Four crossed-schema cases also refuse in the real motor ledger.
These are zero-world interface results, not a new creature trajectory.

Two focused failures remain preserved with original sources and logs:

- The six-test adapter batch reached the legacy differential after about
  165 seconds and hit its unchanged **180-second** outer limit. Three test
  methods had completed, including all cold-reader controls, but the batch
  is still failed/incomplete, not a completed gate. The same six mandatory
  checks are partitioned into five adapter/reader checks plus one legacy
  differential stage, each with the original timeout. The complete gate
  still requires **113 checks**, with none skipped.
- A synthetic route report used an older profile hash because its fixture
  had a stale policy-family list. The actual worker event flow passed. The
  fixture now uses the shared policy selector; the corrected four-test
  route suite passes. This was not a controller or physics failure.

The new schedule stays compact by binding the preserved V41 schedule for
historical lineage. Limits remain **986 post-interaction steps**, **1,338
maximum child steps**, and the existing **400-command resumed-walking budget**.
The original component-only profile remains non-runnable.

**Next:** commit/push this prospective source boundary, pass the complete
applicable safety gate, and only then run one fresh non-comparative
seed-40200 SingleKick and its independent replay. There is no cached baseline,
horizon extension, rerun of V41, matched-effect claim or expected physical
success. Latching an upright reference can still delay recontact or worsen
posture. SDK2 force-aware recovery remains separate.

No V42 world, native physics read or solver step ran at this boundary.
R173 and the official release/support records remain byte-exact.
Fresh readiness is **SDK1 14/20, full program 14/25, zero invalid proofs**, under
`SporeSpore_Evidence/development-v42-integration-readiness-0fe7ea53001c48c5b6f222c8857c94c9/report.json`.
The component-only boundary below is historical; this section supersedes its
integration-next pointer.

## V42 native stance-reference latch

The [V42 component record](../sdk/development/recovery_stance_latch_component_v1.json)
closes native implementation against the unchanged
[prospective contract](../sdk/development/recovery_stance_latch_contract_v1.json).
Four ordered reference-choice bits preserve an established upright reference
through the same stance. They do not replace contact observations. Inactivity,
swing and phase-wrap handling, distinct policy/memory/receipt identities,
truthful carry receipts and fail-closed memory validation are implemented.
Older policies omit the added fields; the selected public policy is unchanged.

**Verification:** all **337 core tests** pass, including the new selector,
400-input synthetic chain and malformed/crossed-memory controls. The fresh
optimized adapter build is retained under
`SporeSpore_Evidence/development-candidate-build-05ee782ab1f1427cb26c907f6cba759d`.
Core compilation/tests take **76.75 s**, fixture capture **0.344 s**, adapter
build **65.906 s**. The existing compiler cache saves compilation work only;
no qualification or test result was reused, and no old DLL was overwritten.

Four real exported-interface tests pass in **23.947 s** under
`SporeSpore_Evidence/development-v42-component-check-b4a1afbf98614eb8a44a88e7d29ae3b5`:

- All **400 original V41 inputs** pass with byte-identical stateful/stateless
  outputs, chained actual candidate memory, and independent latch/target/rate/
  motor reconstruction. Maximum motor arithmetic difference is
  `3.2679414729841483e-12 rad/s`, below the existing `1e-10` comparison allowance.
- **4,400 old-policy outputs** are byte-exact against the previous DLL: 400
  requests for each of 11 policies, all valid on these inputs. All **six**
  captured recovery fixtures are unchanged. This is finite compatibility,
  not a claim about every possible input or engine.
- **11** native safe refusals preserve memory and zero actuation; **three**
  malformed latch-value transports refuse. Component-only physical selection
  also refuses, as intended.

The native calculation confirms **11 selector changes**, **1,253 selected limb
inputs**, and **310 selections retaining upright references with absent actual
contact**. Chained memory yields **230** speed-clamped commands; isolated
substitutions into original memory yield **611**. These remain saved-input
calculations, not another creature trajectory. Recontact and walking can worsen.

**Next legal work:** integrate this exact DLL/profile through the existing
worker, native motor ledger, independent reader and start/entry contracts.
Verify the explicit V42 receipt-schema mapping and latch-memory transport,
then pass the complete applicable safety gate before a fresh SingleKick
diagnostic with the existing 400-command tail. The component profile is
non-runnable; no physical attempt is selected or performed at this boundary.
No new world, native physics read or solver step ran. R173 and official
release/support records remain byte-exact; SDK1 remains **14/20**, full program
**14/25**. V41 and every older observed result remain unchanged below.
Fresh readiness is retained under
`SporeSpore_Evidence/development-v42-component-readiness-9b3342e060d44573a77fabf09f2544aa/report.json`:
five missing, one contradicted and zero invalid proofs.

## V41 contact-loss diagnosis and V42 selection

The [cold diagnosis](../sdk/development/recovery_v41_contact_loss_diagnosis_v1.json)
now covers **all 400 commands, 1,600 limb inputs and all 55 contact losses**,
including brief and unfinished losses. Command n reads trace n-1; the command
after loss is not confused with the command that preceded it. Original contact
truth, evaluation and failures are preserved. The complete 5,609,686-byte
timeline is retained under
`SporeSpore_Evidence/development-v41-contact-loss-diagnosis-ee16bfde74504af4a8c7389ef06919fa/diagnosis.json`;
the compact record binds its digest and every analysis source.

| Foot | All contact losses | Began while scheduled to support | Supporting-phase losses without speed clipping at onset | Followed by clipping on the next command | One-step losses |
| --- | ---: | ---: | ---: | ---: | ---: |
| Front-left | 9 | 7 | 7 | 6 | 2 |
| Front-right | 8 | 7 | 7 | 6 | 3 |
| Rear-left | 9 | 8 | 8 | 6 | 2 |
| Rear-right | 29 | 28 | 14 | 26 | 21 |
| Total | 55 | 50 | 36 | 44 | 28 |

All four feet have loss onsets without clipping. Early front-left loss at
command 85 accompanies body rotation and a rising nominal foot surface;
late rear-right losses accompany alternating joint motion. The ideal-hinge
motion breakdown includes a measured residual and is an algebraic description,
not a causal experiment. Distal-body origins are not contact points; nominal
capsule surfaces are not Jolt's contact predicate or measured contact forces.

Rear-right commands 384..388 alternate supporting/absent/supporting/absent/
supporting inputs. On supporting commands its geometric knee motor request is
+3.5 rad/s; on the interleaved absent-contact commands it is -3.5 rad/s. Actual
knee angles also alternate. At command 385 the total knee-goal change is about
-0.24930 rad; changing only the selector at that same saved pose and wave gives
-0.25233 rad. Both substitution orders are retained, so pose and wave effects
are not silently assigned to the selector. This identifies an abrupt command
mechanism, not proof that it caused every initial loss or walking failure.
Front-left's unfinished loss starts at stance phase 351, command 356, before
the eventual swing-phase ending. Rear-right's unfinished loss starts at 398.
No missing terminal body/joint sample is invented.

**Selected next component: V42 stance-reference latch.** The
[prospective contract](../sdk/development/recovery_stance_latch_contract_v1.json)
adds only four reference-choice bits: after actual contact establishes an
upright stance reference, keep that choice through the same scheduled stance.
Clear it at swing, inactivity or a phase wrap. Never latch or fabricate contact
truth. Preserve V41's geometry, actual-contact rate selector, gains, motor
limits, physical schedule, evaluator and all original results.

The [saved-input precheck](../sdk/development/recovery_stance_latch_precheck_v1.json)
reconstructs every original command before doing substitutions. Reference-choice
changes are **108 original / 11 proposed** on those unchanged inputs. Keep both
arithmetic views visible: substituting one command into original reference memory
gives **611** speed-clamped commands; carrying proposed reference memory gives
**230**, versus **246** originally. Neither is another physical trajectory.
The latter changes 865 motor commands. Same-mask/same-memory commands are exact;
all original joint, slew and speed bounds hold. Complete comparisons are retained
under `SporeSpore_Evidence/development-stance-latch-saved-input-e155bff1e5db4c7998587686e1f484ba/precheck.json`.

**Risk and scope:** retaining an upright target after a foot loses contact could
delay or prevent recontact. The unchanged contact-selected rate still switches.
This proposal does not solve whole-body load transfer by declaration or explain
all 50 initial stance losses. It is not SDK2 force-aware recovery.

The four diagnosis tests pass in **5.84 s**, including crossed motor/clamp/contact
controls, under `development-v41-contact-loss-check-3cb6cb3c00ad4bf8bebad2a123b0de62`.
The three latch-sketch tests pass in **2.72 s**, including lifecycle and invalid
input cases, under `development-stance-latch-precheck-f74a277bd15c4163a73a43e4dd1956a2`.
Both directories are in the durable evidence root. No native controller call,
model, physics world, native read or solver step ran for either analysis.
The unchanged V41 observer's two regression tests also pass in **4.66 s** under
`development-v41-observer-regression-e02c7a2f697b40779810285bf3b77746`.
Both complete retained analyses and compact records cold-reproduce exactly.
Fresh readiness is retained under
`development-v41-contact-loss-readiness-593fecb3c77a46709ce1fb7a63f80fd6/report.json`:
14/20 SDK1, 14/25 full program, five missing, one contradicted, zero invalid.

The selected native implementation is now verified in
[V42 native stance-reference latch](#v42-native-stance-reference-latch).
Shared-route integration and ledger/reader checks remain next. No runnable V42
profile or physical attempt exists yet. After complete applicable safety checks,
use a distinct fresh SingleKick diagnostic with the existing 400-command tail;
no V41 rerun or horizon extension. Commanded stop, complete planned cycles,
paired commissioning and acceptance remain separate.
SDK1 remains **14/20**, full program **14/25**; R173 and official records are
unchanged. The earlier physical closure follows, unchanged in its result.

## V41 prospective route integration

V41's [physical attempt](../sdk/development/recovery_attempts/f4a08fa3230d4276869bb865c8c25a58.json)
is closed as a complete, valid, non-comparative **development observation**.
It is not successful recovery, a complete official route proof or acceptance.
All **113** applicable safety checks passed at clean pushed source
`ec22a5b9923a59654ced514ab982b66153c07b2e`; the fresh seed-40200 SingleKick
completed **1,258 solver steps**, standing transition at 858 and **400 resumed
walking commands**. The independent reader verifies all 1,258 transitions,
430 prefix/resume native-contact steps and all 400 resumed commands.

The original evaluator remains `behavior_passed=false`, with exactly
`every_limb_forward_relocation` and `terminal_four_contact_recovery` false.
There is no torso contact and no native gate timeout. Its 6/4/5/6 observed
foot-contact cycles are not counts of complete planned gait cycles.
Front-left ends at scheduled phase 35 (swing), while rear-right ends at phase
305 (stance) without contact. The terminal four-contact failure is preserved,
not excused by the ending phase. Commanded stop/cooldown remains uncovered.

The [V41 native-receipt description](../sdk/development/recovery_upright_stance_observation_v1.json)
checks all 400 rows, actual selected goals, both explicitly labeled height
plans and their source contacts. Its two cold tests pass in **4.99 s**,
including four crossed-receipt refusals, under
`SporeSpore_Evidence/development-v41-observation-check-cb9f5352c53d4aab811b4ac0583f5639`.
This is retained-data description, not a new native execution or evaluation.
It retains the original walking evaluation unchanged.

These are **two individual development trajectories**, not a matched comparison
or proof that V41 caused an improvement or regression:

| Recorded measurement | V40 | V41 |
| --- | ---: | ---: |
| Commands with no common all-four-leg body-height interval | 103 / 400 | 0 / 400 |
| Maximum torso tilt | 6.48 degrees | 4.72 degrees |
| Forward body travel during resumed walking | 16.04 cm | 11.32 cm |
| Sideways drift magnitude | 2.71 cm | 0.55 cm |
| Joint commands clipped at the unchanged motor-speed cap | 85 / 3,200 | 246 / 3,200 |

[V40's unchanged receipt summary](../sdk/development/recovery_absent_contact_reference_observation_v1.json)
provides the earlier measurements. V41 has no empty interval in either its
measured-pose baseline plan or its upright reference plan. That does not prove
anchoring, stable load transfer or a cause of V40's failures.

V41 selects upright references on 943 limb-command inputs, with 108 selector
transitions. Of its 246 speed-clamped joint commands, **169** occur with absent
contact during scheduled stance, **56** in swing/landing and **21** in bearing
stance. Rear-right alone has 71 absent-stance clamps. Every foot has at least
one observed contact cycle with backward relocation under the original metric.

The formerly selected retained-data diagnosis is now complete in
[V41 contact-loss diagnosis and V42 selection](#v41-contact-loss-diagnosis-and-v42-selection).
No V41 rerun, horizon extension, changed threshold, outcome-derived correction
or claim that the geometry conflict alone explained the old result is allowed.

Observed elapsed time: safety gate **842.60 s**, child **708.428 s**, independent
replay **301.64 s**, whole invocation **2,010.186 s (33 min 30 s)**. The retained
population is **63 files, 1,107,530,164 bytes**, with exact inventory, source,
runtime, report and publication digests in the closure. Do not append to the
consumed physical root.

The preceding [zero-world gate failure](../sdk/development/recovery_attempts/9ad0a4c4dbc94e899752549d9f3aa457.json)
and its frozen v1 declarations are immutable. Its cause was an omitted V41
entry in the production ledger's expected-schema lookup, not a bad native
receipt. The [v2 integration repair](../sdk/development/recovery_upright_stance_ledger_integration_v2.json)
adds that explicit mapping and three crossed-schema controls. It changes no
DLL, controller, motor cap, physical schedule or evaluator.

Fresh readiness is **SDK1 14/20, full program 14/25, zero invalid proofs**.
R173 and official release/support records remain byte-exact.

## V41 native component: contact-bearing upright stance reference

Historical component boundary; prospective route integration is recorded above.

The [V41 native component receipt](../sdk/development/recovery_upright_stance_component_v1.json)
implements the [unchanged prospective contract](../sdk/development/recovery_upright_stance_contract_v1.json).
Its profile remains deliberately **non-runnable** until shared-route integration.
No new world, solver step or native physics read ran at this boundary.

For active, explicitly contact-bearing stance feet at phase 73..359, the
controller uses floor-upright reference goals at the actual measured torso
height. Every other foot retains V40's measured-pose goal. The upright reference
uses anatomical vertical projections `[forward_y, up_y, side_y] = [0, 1, 0]`;
it never edits an observation quaternion or pretends a foot has contact.
Both geometries retain all four leg-height constraints. One current contact
selector is held fixed for both wave evaluations, preserving V40's rate rule,
gains, caps, slew, gait clocks and upstream wave memory.

The V41-only `upright_stance` receipt separately labels measured-pose baseline
proposals/plan, upright-reference proposals/plan, actual selected goals and
the same-mask comparison. Top-level limb proposals are the actual chosen
proposals. There is no single mixed-geometry plan, so the old top-level plan
is omitted for V41 and both complete plans are labeled inside the new receipt.
Absent optional fields preserve all older-policy serialized bytes.

The first build passes **334 core tests** in **74.09 s** including compilation;
V20 fixture extraction takes **0.36 s**, and the adapter build takes **65.14 s**.
The existing release compiler cache is reused, but tests and the separately
copied immutable DLL are fresh. The four final native-export checks pass in
**18.57 s** through the actual exported interfaces, without a physics world:

- All 400 saved V40 inputs give byte-exact stateful/stateless output matches.
- 4,000 outputs across ten older policies remain byte-exact between DLLs;
  all six V20 recovery fixtures and R173 remain exact.
- The independent precheck reconstructs 6,400 joint commands across separate
  one-command and chained-reference comparisons. Maximum motor discrepancy
  is **6.061e-13 rad/s**, inside the existing 1e-10 arithmetic allowance.
- 1,126 currently unselected joint commands match V40 exactly with identical
  incoming memory. All 400 upstream next memories match after accounting
  only for the distinct schema and intentionally changed reference positions.
- 19 invalid-context cases refuse without advancing memory; four malformed
  transport requests refuse. Core tests cover upright yaw identity, tilted
  contact switching, initialization, activation, inactivity and invalid state.

The native results reproduce the precheck's important risks: **1,037** selected
stance-foot inputs and **47** selector changes; one-command substitution has
**83** speed-clamped joint commands, while the chained replay has **168** versus
V40's original **85**. In the chain, **102** currently unselected commands carry
earlier changed references. These are old-state probes, not another trajectory
or proof that the creature stays anchored and recovers.

Three earlier four-test invocations are retained as failures. The new Python
test incorrectly used exact equality against archive-projected command numbers,
then wave numbers, then a floating-point slew endpoint. Only that new test
changed: exact compatibility still compares the two native DLLs, the original
archive checks retain their existing arithmetic allowances, and every native
slew flag must equal its actual target/goal inequality. All three cross-calculation
slew-flag discrepancies are retained; both endpoint gaps stay below **3.47e-18 rad**.
No Rust source, DLL, precheck, physical record, threshold or outcome changed
after the first build. All observed test sources and logs are preserved.

Next integrate this DLL into the existing shared worker, adapter motor ledger
and independent reader, then complete the applicable safety checks before a
fresh bounded development diagnostic. Physical posture/contact retention,
relocation, landing, later cycles and stop/cooldown still need observation;
paired commissioning and prospective acceptance remain separate. No force-aware
recovery, behavioral success or release claim is promoted. Fresh readiness is
**SDK1 14/20**, full program **14/25**, **zero invalid proofs**.

## V41 precheck: floor-upright support reference selected

Historical selection boundary; native implementation is now verified above.

The [saved-input precheck](../sdk/development/recovery_upright_stance_precheck_v1.json)
and [verification decision](../sdk/development/recovery_upright_stance_verification_v1.json)
select the [prospective V41 native component](../sdk/development/recovery_upright_stance_contract_v1.json).
The component is **not yet implemented or route-integrated**, and no physical
attempt is selected. This is the next bounded response to V40's opposite-corner
height conflict, not evidence that another trajectory will recover.

The rule changes position goals only for an active wave's currently
contact-bearing stance feet: phase **73–359**, explicit contact presence and
explicit support bearing. It computes an additional floor-upright **reference**
using the same measured floor-relative body height, compiled leg geometry,
nominal directions, joint limits and all-four-leg height constraints. For a
horizontal floor the vertical projections are forward=0, up=1, side=0,
independent of upright yaw. The actual measured orientation is never replaced
or relabeled; both measured-pose and reference-pose proposals must remain
explicit in the new native receipt.

Absent-contact, nonbearing, swing and landing feet retain their measured-pose
goals. The **current** per-foot selector is held fixed while comparing the
current and previous upstream waves; a selector/frame change must not be
misreported as wave velocity. V40's absent-contact full-reference rate, other
contacts' wave-rate fallback, reference slew, gains, speed/impulse caps and
gait clocks remain unchanged. The distinct memory carries the actual selected
reference positions without adding a new dynamic state.

The full population has **400 commands / 1,600 leg samples / 3,200 joint
commands**. The baseline reconstruction matches V40 within its existing
arithmetic policy; all 400 upright reference plans have nonempty shared height
ranges. This is reference geometry at a different orientation, not 400 new
feasible physical observations.

| Check on original V40 inputs | One-command substitution | Chained reference replay |
| --- | ---: | ---: |
| Changed motor velocities | 2,044 | 2,186 |
| Commands at the unchanged speed clamp | 83 | 168 |
| Unselected commands with changed carried reference positions | 0 | 102 |
| Joint, speed and reference-slew bounds | Preserved | Preserved |

V40 itself had **85** clamped commands. The one-command result uses V40's
incoming reference memory independently at each input. The chained result
carries proposed reference positions across all inputs while keeping the body
states, contact observations and upstream wave/gait inputs frozen to V40.
Neither is an alternative physics rollout, and the low one-command clamp count
must not hide the chained increase.

The rule selects **1,037 leg inputs**, with **47 selector transitions**.
There are **131 two-contact**, **175 three-contact** and **94 four-contact**
input commands; zero/one-contact physical coverage is absent. Some selected
goals move a foot upward at the original fixed torso pose. That could request
body lowering if the foot remains anchored, but may instead lift the foot or
destabilize load transfer. Contact switching, reference carry and the higher
chained clamp count remain explicit native/physical test risks.

All **six non-native checks pass in 5.40 s**, covering complete reproduction,
selector refusals, initialization/activation, phase boundaries, same-current-mask
comparison, contact transitions, chained bounds and original no-claim limits.
The first invocation is retained as **incomplete**: after one test completed,
a Python-tuple versus JSON-array comparison triggered expensive recursive
failure formatting. Only the exact owned test process was stopped, after
160.21 s. The corrected test verifies the representation distinction,
compares the full JSON-normalized result and bounds mismatch output; no
calculation or physical output changed. The original precheck generation
passed in **2.71 s** and its full **8,919,841-byte** result remains retained,
together with both test invocations and the exact before-fix test source.

Next implement the specified distinct native policy/profile/memory/receipt.
Run real stateless and stateful exported-interface checks over all 400 saved
inputs, preserve older-policy bytes, and independently check selected and
unselected command behavior before integrating the shared worker, adapter,
motor ledger and reader. A complete applicable safety gate still precedes
any fresh bounded physical diagnostic. No timeout/horizon extension, fitted
contact threshold or higher force/speed limit is selected.

No native controller, physics read, world or solver step ran in this precheck.
R173, V40's original failure and official release/support records remain exact.
Fresh readiness stays **SDK1 14/20**, full program **14/25**, **0 invalid proofs**.
Stance/relocation stability, second planned cycles, commanded stopping, fresh
paired commissioning and prospective acceptance remain outstanding. SDK2
force-aware recovery is separate future work.

## V40 landing diagnosis: incompatible corner heights

Historical diagnosis boundary; its selected V41 precheck is complete above.

The [complete saved-data diagnosis](../sdk/development/recovery_landing_reach_diagnosis_v1.json)
and [verification/next-work decision](../sdk/development/recovery_landing_reach_verification_v1.json)
cover all **400 commands, 1,600 leg samples and 3,200 joint commands**. They
reuse the existing motor audit and measured-frame reconstruction, independently
check every per-leg height interval, retain every original contact loss and
cycle, and decompose all 15 measured cycles without deleting their failures.
No native controller, physics read, world, solver step or alternate rollout ran.

The height conflict is consistently between opposite corners of the creature:

| Quantity | Observed result | Meaning |
| --- | --- | --- |
| Empty common-height plans | 103; commands 246–263 and 316–400 | The four current leg plans cannot share a body height. |
| Lower bound owner | Front-right on all 103 | This leg cannot fold enough, at its planned direction, to support a lower body. |
| Upper bound owner | Rear-left on all 103 | This leg cannot extend far enough, at its planned direction, to reach from a higher body. |
| Gap between those bounds | 0.187–10.245 mm | Moving the whole body vertically at the same orientation cannot satisfy both plans. |
| Original controller response | Common lowering disabled on every conflict | The refusal is real; the controller does not invent a feasible height. |

Dropping either front-right or rear-left from the arithmetic makes all 103
intersections nonempty. Considering only scheduled-stance legs does so for 97.
These are diagnostic omissions, **not proposed support claims or safe fixes**:
they say nothing about supporting or reaching with the omitted foot.

Rear-left enters landing phase at command **345**; the hold counter increments
on **346–400**, explaining **56 landing inputs** versus the recorded
**55-command hold**. All 56 inputs have no native contact and no raw contact
samples. Their relaxed fixed-torso planar reach lower bounds are **4.91–7.44
mm above the floor**. An independent aligned-link calculation attains that
bound on all 1,600 saved leg samples, confirming its geometry. This bound even
relaxes the joint limits, but still fixes the measured torso pose: it predicts
neither a future body pose nor a physical alternative.

During those landing inputs, the original goal leaves the ideal foot bottom
**6.98–9.26 mm above the floor**; the measured nominal capsule bottom is
**6.41–13.39 mm above it**. Both landing motors are within their speed caps.
At the final pre-command sample, front-right's requested knee is approximately
1.100 rad while rear-left requests full extension at 0 rad. This is an
incompatible body-pose/leg-plan condition, not merely an airborne leg waiting
for a faster command. Native contact remains authoritative; nominal capsule
geometry and motor impulse slots are not contact or delivered-force evidence.

Stance instability remains separate and fully retained: **199 unsupported
stance inputs** (32 front-left, 46 front-right, 66 rear-left, 55 rear-right),
**27 contact losses**, **22 starting in stance**, and **8 of 15 counted cycles
failing original relocation**. The fixed-pose conflict does not explain every
one of those losses, and a posture change is not assumed to fix them.

Next work is **V41's zero-world supporting-stance floor-upright reference
precheck**, not a selected native policy or physical attempt. Evaluate one
explicit geometric rule: use a floor-upright support reference for currently
contact-bearing stance feet while preserving measured-pose references for
absent-contact, swing and landing feet. Compare all saved inputs, retain the
unchanged baseline, bounds, caps, reference slew, gains and phase clocks, and
exercise activation, contact switching and phase boundaries synthetically.
Report supporting-contact counts, reference discontinuities, foot-lift risks
and all unresolved reach residuals. Only then decide whether a distinct native
component is justified. No fitted contact threshold, ignored leg constraint,
new force/impulse limit, timeout extension or old-result regrading is selected.
This uses existing pose/contact observations; SDK2 force-aware recovery remains
future work.

The full diagnosis is **6,216,902 bytes** in its dedicated durable evidence root.
Its successful generation took **2.46 s**; all **six checks pass on their first
invocation in 6.42 s**. The first analysis invocation is retained separately:
a new exact-subtraction assertion failed on serialized-height roundoff, at
most **6.55e-17 m**. The fix uses the existing **1e-12** cold arithmetic allowance
and records the discrepancy, with the exact failed source preserved. No
behavioral or reach threshold changed. Source fingerprints and both evidence
populations are bound by the verification record.

R173, V40's consumed physical closure and official release/support bytes remain
exact. Fresh readiness stays **SDK1 14/20**, full program **14/25**, with
**0 invalid proofs**. Later second planned cycles, commanded stopping, full
fresh paired commissioning and prospective acceptance remain outstanding.

## V40 closure: stance tracking verified, landing and support still fail

Historical physical-closure boundary; the saved-data diagnosis above is now complete.

The [immutable V40 closure](../sdk/development/recovery_attempts/9791149066cc43e2b42df2f1def7adc1.json)
records one fresh seed-40200 SingleKick diagnostic from clean pushed source
`07fe6a9cf853136cca1ddaa2591c6537b85e0a4d`. The complete **113-check safety
gate**, original native replay and final publication audit passed on the
first attempt. One world ran **1,258 solver steps**: standing completed at
step **858**, followed by all **400 resumed commands**. This is valid bounded
development evidence, not a full paired route or acceptance result.

The original walking evaluator still fails **foot relocation** and **terminal
four-foot support**. Forward travel is **16.04 cm**, lateral drift **2.71 cm**
and peak tilt **6.48 degrees**; there are no torso contacts during resumed
walking and no native landing timeouts. No threshold, command budget, gate
timeout or observed evaluation changed.

The [saved-data observation](../sdk/development/recovery_absent_contact_reference_observation_v1.json)
retains every contact loss, including short and unfinished flights. The table
uses resumed-command numbers; a measured contact cycle is an observed
liftoff/touchdown with the original minimum airborne dwell, not necessarily
a deliberately scheduled walking step.

| Foot | First landing hold | Measured cycles | Cycles failing original relocation | Cycles with no scheduled swing/landing overlap | Contact at cutoff |
| --- | --- | ---: | ---: | ---: | --- |
| Front-left | Commands 76–77; 2 commands | 5 | 3 | 3 | Supported; scheduled stance |
| Front-right | Commands 256–257; 2 commands | 5 | 3 | 3 | Supported; scheduled stance |
| Rear-left | Commands 346–400; 55 commands, still open | 2 | 0 | 1 | Unsupported; landing held at phase 72 |
| Rear-right | Commands 166–167; 2 commands | 3 | 2 | 2 | Supported; scheduled stance |

Across the complete population, **22 of 27 contact losses begin during
scheduled stance**. Eight of 15 counted cycles fail the original relocation
minimum, and nine have no scheduled swing/landing overlap. Rear-left last
loses contact at command **297** and has no observed touchdown through command
400. Its two earlier counted cycles do not resolve that unfinished landing.
No terminal failure or inconvenient short interval is removed.

The cold command audit reconstructs all **3,200 motor commands** and **1,600
leg-lift targets**, including **874** selected absent-contact joint commands,
of which **398** occur during scheduled stance. There are **85** speed-clamped
commands, including **26** in the added stance selection. These are counts on
the new physical V40 trajectory; they are not the earlier old-V39-input native
probe's 416 added stance inputs and 133 clamped commands. Existing arithmetic
allowances, targets, limits and independent replay checks remain unchanged.

The support plan requests lowering on **141 commands**, by at most **1.24 cm**,
and reports **103 empty common height intervals**. In plain terms, the current
leg directions and bounds cannot all share one modeled body-height range on
those inputs. This is a leg-plan feasibility conflict, not proof that no
conceivable physical pose could reach the floor, nor proof that it caused the
rear-left landing failure. Saved V39 had zero such empty intervals; this is a
finite descriptive contrast, not superiority, equivalence or causal evidence.

The [cold verification receipt](../sdk/development/recovery_absent_contact_reference_cold_verification_v1.json)
binds all six passing checks, the exact analysis/test sources, all **63 physical
files / 1,084,642,270 bytes**, and the separate launcher and closure populations.
The first cold observation missed a math import; the first six-test invocation
had five passes and one relative-versus-absolute source-path assertion failure.
Both failed invocations and before-fix sources are retained. The corrected six
checks pass in **45.71 s**, with no native physics read, world or solver step.
Neither cold repair changes the physical record or original evaluation.

The outer invocation took **32 min 8 s**. The inner supervisor records **13 min
18 s** for safety checks, **11 min 27 s** for the physical child and **4 min
42 s** for independent replay; other launch/publication overhead is separate.
These are measured stage times for this invocation, not a controlled speedup
claim. No physical rerun was needed to close this result.

Next perform a bounded diagnosis of all saved commands: locate the rear-left
landing/reach conflict and every empty common-height interval alongside stance
loss, tracking error and measured foot motion. **No V41 is selected yet.**
Keep the finite blockers explicit:

1. Lost stance contact and original per-foot relocation failures.
2. Rear-left touchdown and coordinated body-height/current-reach behavior.
3. Second complete planned cycles per foot and commanded stop/cooldown.
4. Full fresh paired commissioning and prospective acceptance.

The command amplitude never decreases in this observation and is still at its
maximum at cutoff; stopping is not proved by process shutdown. Preserve the
same 400-command result without extension, rerun or regrading. R173 and official
release/support bytes remain exact. Fresh readiness is **SDK1 14/20**, full
program **14/25**, **0 invalid proofs**; no behavior or release gate advances.

## V40 prospective route integration: safety gate pending

Historical pre-physics boundary, now superseded by the V40 closure above.

V40's [separate integrated profile](../sdk/development/recovery_candidates/v40-absent-contact-reference-integrated-v1.json)
binds the verified DLL and a distinct prospective schedule; its original
native-component profile remains non-runnable. The shared Python/GDScript
selectors, startup, native adapter, motor-ledger identity and frozen-source
closure resolver recognize the new policy, memory and receipt identities.
No controller code or native build artifact changes at this boundary. The
independent reader retains its real native-output comparison and floor/context
validation; no permissive replay or alternate worker is introduced.

The [prospective schedule](../sdk/development/recovery_schedules/v40-absent-contact-reference-integrated-v1.json)
preserves V20 recovery, stance V7, BW5R-B prefix, clock offset 90, amplitude
ramp/cap, all motor limits, the 986-step tail, 1,338-step child cap and original
behavioral criteria. One fresh seed-40200 SingleKick will observe V40 through
the same 400-command walking budget. It is explicitly not second-cycle or
commanded-stop coverage, a paired comparison, or an acceptance attempt. Every
failure and incomplete cycle remains retained; V39 is never rerun or regraded.

Static Python selection and source binding pass. Real route-interface checks
are **pending**, not inferred from the native component. Run the complete
applicable **113-check safety gate** at the clean pushed boundary, followed by
the physical diagnostic only if every check passes. That gate includes all
affected profile, floor/adapter, native component, recovery-route, start,
schedule and retention tests, so no overlapping preliminary pass is required.
The actual adapter and cold-reader suite is now parameterized between V39 and
V40; V40 must demonstrate selected stance inputs and reject a rehashed false
selector in that added phase range. Constructor, geometry, motor ledger and
the remaining corruption tests stay shared.

No world or native physics read has run for this source-integration boundary.
Lost stance contact/relocation, coordinated body height/reach, second planned
cycles and commanded stop/cooldown remain unresolved before full paired
commissioning and prospective acceptance. R173, official release/support
records and all observed attempts remain unchanged. Latest native-component
readiness remains SDK1 14/20, full program 14/25, invalid proofs 0.

## V40 native component: absent-contact stance reference tracking

The [V40 component receipt](../sdk/development/recovery_absent_contact_reference_component_v1.json)
records the implemented prospective rule and its fresh native evidence. A foot
whose pre-command contact explicitly reports absence now uses the existing
full moving-reference rate during stance as well as swing/landing. Supported
or present-but-nonbearing feet retain V39's prior behavior; malformed or missing
contact still refuses safely. Positive elapsed time and two active wave snapshots
remain required. No position target, support-height plan, gain, gait/contact
gate, reference slew, speed/impulse cap or joint bound changes. The memory has
a distinct identity but no additional dynamic state.

All **330 core tests** and **four exported-interface tests** pass on their first
attempt. The four new Rust tests cover 360 selector combinations, 400 synthetic
chained inputs and invalid/inactive cases. The native checks use every one of
the 400 saved V39 walking inputs with full binary64 input precision and chained
memory, not independently reset rows. Stateful and stateless output bytes match
on all 400 steps. Independent arithmetic checks all 1,600 foot selections,
3,200 position/comparison references and 3,200 final motor velocities. All
3,600 outputs from nine predecessor policies and all six V20 recovery fixtures
remain byte-exact. Nineteen invalid-context cases retain unchanged memory and
safe no-actuation; four malformed requests refuse at the transport boundary.

On those old inputs, the native result matches the prospective sketch: **416
newly selected stance joint inputs**, 278 changed velocities, and 133 commands
at their existing speed clamp versus the saved V39 population's 82. The other
2,784 joint-command objects remain exactly V39's. Position targets, gait memory
and support plans remain exact throughout. This is a measured command change,
not a new trajectory, a prediction of better support, or proof of adequate
delivered motor force. Upward/downward effects and current-body reach problems
remain possible; no numerical limit or original physical criterion is raised.

The optimized build stages took **142.77 seconds** and the exported checks
**16.23 seconds**. Compiler-cache reuse saves compilation work, not tests or
qualification evidence. The new 8,455,168-byte DLL is independently retained
under `SporeSpore_Evidence/development-candidate-build-85941c4160844671bb958051288b6799`
and in its immutable repository-local candidate path. Test logs, exact source
snapshot and readiness are retained under
`SporeSpore_Evidence/development-v40-native-component-03cf91d4df14453b9116d2882ba8149a`.
The original generated patch is preserved; only the new profile schema was
changed before applying it so this component **cannot select a physical run**.
Older DLLs, runtime bindings, contracts and observed evidence stay untouched.

Next connect V40 to the existing shared worker, motor ledger and independent
reader, then pass the complete applicable safety gate before a distinct fresh
diagnostic. Lost stance contact/relocation, coordinated body height/reach and
second planned cycles plus commanded stopping remain the finite behavioral
blockers before full paired commissioning and prospective acceptance. No new
world, solver step or native physics read ran for this component. R173 and
release/support bytes remain exact; fresh readiness is SDK1 **14/20**, full
program **14/25**, with **0 invalid proofs**. No behavior or release gate advances.

## V39 stance diagnosis: V40 lost-contact tracking selected

The [saved-data diagnosis](../sdk/development/recovery_absent_stance_diagnosis_v1.json)
and [V40 selection](../sdk/development/recovery_absent_contact_reference_selection_v1.json)
retain every one of V39's 400 resumed commands, 1,600 foot-command samples,
19 original dwell-qualified cycles and 24 contact losses. Command `n` is paired
with pre-command trace `n-1`; trace 400's final contacts are retained without
inventing a next body input. Six zero-world checks pass in **6.68 seconds**.
No native controller call, physics world, solver step or new physics read runs.

| Foot | Supporting-phase commands | Commands with no contact | Motor commands at their speed clamp during those missing-contact samples | Largest ideal goal height above the floor during missing contact |
| --- | ---: | ---: | ---: | ---: |
| Front-left | 287 | 43 | 0 | 3.65 mm |
| Front-right | 323 | 40 | 0 | Approximately zero (1.8 nm numerical/frame residual) |
| Rear-left | 323 | 30 | 0 | Approximately zero (1.2 nm numerical/frame residual) |
| Rear-right | 321 | 95 | 0 | 15.72 mm |

The 208 unsupported stance inputs have no raw distal contacts either. Measured
joint positions sometimes lag reachable position references; other samples
have a separate geometry problem. Rear-right loses contact after command 376,
when its ideal goal is still at the floor. Later, its current measured torso
pose and leg directions leave its ideal goal above the floor. At command 390
the goal is about 4.53 mm above the floor even though the plan's link-projection
flag is false: the plan was computed for a **lower proposed body height**, not
the body height the creature has actually reached. Even the unrestricted
planar reach lower bound is positive at that sample. A nonempty shared height
interval therefore does not establish current reach or physical support.

This does not identify all causes of contact loss. Ideal hinges omit native
constraint compliance, and nominal capsule bottom is not a contact predicate.
The independently retained canonical/native orientation difference is 2.126e-7
in axis-vector distance. Motor readback checks match the expected binary32
engine slots for all 3,200 commands; absence of a speed clamp does **not** prove
delivered motor force/impulse adequacy. Maximum impulse settings are retained,
but they are not measurements of delivered impulse.

The selected [prospective V40 contract](../sdk/development/recovery_absent_contact_reference_contract_v1.json)
makes one controller change relative to V39: when both existing pre-command
contact booleans explicitly report absence and both wave snapshots are active
with positive elapsed time, use the existing full-reference rate in **stance
as well as swing/landing**. Keep the current fallback for supported or ambiguous
contacts. Preserve every position target, support-height plan, floor binding,
gain, phase/contact gate, memory dynamic, speed/impulse cap and joint bound.
Use distinct policy, profile, memory and receipt identities; no extra sensor,
fitted gain, timed episode selector or force-aware recovery claim is introduced.

On the complete saved V39 inputs the sketch newly selects 208 stance limb inputs
(416 joint inputs), changes 278 motor commands beyond the existing arithmetic
allowance, and yields 133 saturated commands versus the observed 82. Every
unselected velocity remains exact, and all proposed velocities remain within
the existing caps. Its instantaneous fixed-torso vertical velocity difference
has **both signs** (range -0.198 to +0.183 m/s). This tracks a moving target; it
is not a downward-only correction or a predicted trajectory. Independent
finite differences check all 3,200 ideal vertical joint derivatives. Abrupt
contact switching, reach conflicts and posture regressions remain risks.

Do not raise speed limits based on these data, revert to full-reference
tracking on supported feet, discard failed/short cycles, or extend/regrade V39.
The next bounded work is the non-runnable V40 native component: real chained
stateless/session tests on all 400 V39 inputs, exact parent/older-policy output
checks, and malformed-context refusals. Shared route integration and the full
applicable safety gate must precede a separately declared fresh diagnostic.
V40 is **selected, not built, integrated or physically tested** at this boundary.

The finite remaining blockers are lost stance contact/relocation, coordinated
body height and reach, and missing second-cycle/commanded-stop coverage before
full paired commissioning and prospective acceptance. A future schedule needs
its own coverage argument; a 400-command observation is not a completed stop.
The 5,793,600-byte full diagnosis, compact output, logs and readiness receipt
are retained under `SporeSpore_Evidence/development-v39-stance-88532ddcd8644c259b5d6c7989663550`
and hash-bound by the selection. Original V39 and R173 bytes are unchanged;
fresh readiness remains SDK1 **14/20**, full program **14/25**, invalid proofs
**0**. No acceptance, superiority, equivalence or release claim advances.

## V39 closure: short landings, stance contact still fails

The [immutable physical closure](../sdk/development/recovery_attempts/681e45b2b4784caba4018cac4e6c2b61.json)
retains the single fresh seed-40200 kicked child from source
`529682476a3865aa928368bd73f6a96e28e2cacb`. All 113 safety checks pass; one world
executes 1,258 steps. Standing completes at 858 with its original 60-sample
stable dwell, and all 400 resumed commands run from 859 through 1,258.
Original supervisor, native health and independent replay pass. The original
reader validates all 1,258 transitions, 430 contact steps and 400 resumed
commands. This is a valid bounded development observation, not a full paired
route proof, behavioral acceptance, force-aware recovery or release evidence.

The body advances **16.25 cm**, drifts sideways **3.46 cm** and reaches a peak
tilt of **4.18 degrees**. There are no torso contacts or native landing timeouts.
The original evaluation remains negative for `every_limb_forward_relocation`
and `terminal_four_contact_recovery`. Its unchanged minimum relocation is
1.2 cm per counted cycle; no short, backward or unscheduled cycle is removed.

The [complete retained-data observation](../sdk/development/recovery_airborne_reference_observation_v1.json)
separates commanded steps from measured loss and return of foot contact:

| Foot | First scheduled swing begins at resumed command | First landing hold | Counted contact cycles / failing relocation | Contact at the final sample |
| --- | ---: | ---: | ---: | --- |
| Front-left | 1 | 2 commands | 6 / 5 | Absent; second scheduled swing, phase 35 |
| Front-right | 181 | 2 commands | 4 / 2 | Present; scheduled stance |
| Rear-left | 271 | 2 commands | 3 / 2 | Present; scheduled stance |
| Rear-right | 91 | 4 commands | 6 / 5 | Absent; scheduled stance, phase 303 |

All four first swing windows reach their landing phase. Front-left begins its
second swing at command 365, which is unfinished at cutoff. The amplitude is
still its declared maximum, 0.5994550408719347, and never decreases: this window
does not exercise a commanded stop/cooldown. Nevertheless, the terminal failure
is **not only an unfinished planned swing**. Rear-right loses contact at command
376 while in stance and has not regained it at 400. Of all 24 contact losses,
18 begin in scheduled stance. Thirteen of the 19 dwell-qualified cycles have
no scheduled swing/landing overlap; 14 fail relocation. A counted contact
cycle is not proof of an intended step. Coordinates used for relocation are
retained distal-body origins, not sole-contact points.

Six cold checks pass in 48.96 seconds. They verify the original complete
publication/inventory/replay, 1,864 unchanged standing commands, all 3,200
resumed motor commands and 1,600 lift goals, every contact cycle/loss, and ten
deliberate selector/provenance/target corruptions plus report/claim refusals.
V39 selects full-reference tracking for 424 joint commands and the unchanged
fallback for 2,776. Eighty-two motor commands saturate (31 selected, 51 fallback).
The common support-height interval is nonempty at all 400 samples; this is
geometric feasibility, not proof that the measured feet actually track it.

The first cold analysis failed at command 84 because the historical independent
formula factored the hip-span scale outside a sum. At the exact full-extension
branch that different binary64 grouping produced a 4.215e-8-radian knee
discrepancy. A distinct cold helper uses the compiled hip coordinates before
projection. Maximum comparison discrepancy is now 2.221e-16 radians, with no
increased arithmetic allowance, production change or rewrite of the historical
helper. The failed invocation is preserved and reproduced by the regression
test; the original physical replay had already passed.

The physical population retains **63 files / 1,084,807,628 bytes**. Total
invocation time is **1,903.259 seconds (31 min 43 s)**: safety gate 779.787 s,
child 693.483 s, independent replay 280.922 s, remaining supervision/publication
149.067 s. The cold logs and fresh readiness receipt live separately under
`SporeSpore_Evidence/development-v39-closure-3d68853524cc4e3bb8d74eb4ac2a1875`;
the [cold verification record](../sdk/development/recovery_airborne_reference_cold_verification_v1.json)
binds their original bytes, including the failed analysis.

Next bounded work: use **all saved scheduled-stance commands and every contact
loss** to distinguish reference/reach geometry, tracking lag, speed-cap use and
measured foot motion. Prioritize the persistent rear-right terminal loss, while
keeping the full population as context. Then choose a distinct targeted
controller successor if warranted. A separate future prospective schedule must
cover additional planned cycles and commanded stopping before claiming those
paths; neither extending V39 nor dropping its terminal failure is permitted.
No longer horizon or new controller is authorized by this closure itself.

R173 remains byte-exact. Fresh readiness remains SDK1 **14/20**, full program
**14/25**, invalid proofs **0**, with five missing and one contradicted SDK1
gate. The release contract and support matrix are unchanged. No new world,
solver step or native physics read ran during this cold closure.

## V39 route integration: ready for the complete smoke gate

The [V39 integration record](../sdk/development/recovery_airborne_reference_route_integration_v1.json)
binds the shared adapter, motor ledger, startup/entry selection, worker route,
independent reader, separate integrated profile and all retained test results.
The verified native component and optimized DLL are unchanged; all 69 native
build-source hashes still match. The original component-only profile remains
non-runnable. Use `v39-airborne-reference-integrated-v1.json` for the next
explicit development diagnostic, not the component profile.

All 29 focused checks pass across targeted invocations. Their successful stage
times total 240.13 seconds; this is not the elapsed time for the whole integration
or a first-pass result. Coverage includes 200 consecutive synthetic commands
through the real adapter and cold reader, independent reconstruction of all
1,600 joint commands (162 selected, 1,438 fallback), 14 existing floor/memory
corruption refusals and nine additional airborne-receipt refusals. Altered
receipts are rehashed before the negative check. The original native-response
hash and complete output remain independently checked. The route also preserves
49 synthetic transitions and five cold-event refusals; startup probes 450
commands. Existing schedule bounds and all 11 walking-entry corruption cases
pass. Detached floor objects are constructed without a physics world.

Four failed stages are preserved, including their original outputs:

- The real facade omitted V39's expected receipt schema. One of 125 motor-ledger
  predicates failed although the native verification and 200-command replay
  passed. Add only the explicit V39 branch; retain all verification predicates.
- A new test compared two timestamp representations with Python float equality.
  Use the existing canonical-number policy for that comparison, with no new
  tolerance or production-reader change. The exact raw-response check and
  deliberately corrupted timestamp refusal remain.
- The shared synthetic route-report fixture selected an older profile digest.
  Add V39 to that test-only family; all 49 transitions already replayed.
- Startup's Python family lists omitted V39, although the actual startup passed.
  Complete those lists and the matching schedule/entry test families. No
  controller, native observation, schedule, threshold or evaluator changed.

The reader's V37/V38 frozen-source outputs remain exactly equal to the pre-change
reader: 38 and 39 bindings, respectively, all present in the immutable original
closures. The prospective V39 owned-source projection resolves 40 bindings and
rejects crossed selection/source data. The legacy 44-check source suite retains
its same three failures and one error, with no new failures; it is not reported
as a passing historical suite. The 110-file integration evidence population,
including failed tests, is retained under the declared evidence root and bound
by the compact record's manifest.

Next: clean pushed checkpoint, all 113 applicable smoke safety checks, and one
fresh non-comparative seed-40200 SingleKick. Preserve V20 standing recovery,
stance V7, BW5R-B prefix, clocks 90, 72-command ramp, existing caps and finite
floor, 986-step tail, 1,338-step child cap and 400 resumed commands. Observe
landing delay/tracking and speed-cap use together with unresolved stance
contact/reach conflicts, body motion/tilt, foot relocation/cycles and terminal
four-foot support. Do not extend a failed attempt or cache a baseline.
Fuller airborne target tracking may help or harm contact and posture; the
integration does not predict a physical outcome or establish force-aware recovery.

No physics world, solver step or native physics read ran here.
Fresh readiness remains SDK1 **14/20**, full program **14/25**, invalid proofs
**0**; R173 is byte-exact. No acceptance, equivalence or release claim advances.

## V39 native component: contact-selected airborne tracking

The [V39 component record](../sdk/development/recovery_airborne_reference_component_v1.json)
binds the implemented controller, immutable optimized DLL and first-pass tests.
For feet scheduled in swing or landing, the new rule uses the speed of the
actual moving position target only when both pre-command contact signals
explicitly report absence. It requires a positive time interval and active
previous/current wave snapshots. Feet in contact, ambiguous/non-bearing
contact, and scheduled stance retain V38's pose-separated rate exactly.
Missing or contradictory contact data refuse actuation instead of guessing.

No position goal, support-height plan, reference slew, gain, phase clock,
contact gate, speed/force cap, evaluator or horizon changes. V39 has a distinct
memory identity but no new dynamic state. Its optional receipt retains each
pre-command contact observation and provenance, source step/time/capability,
the per-foot selector and eight full-reference rates. V38's comparison
references and wave snapshots remain available for independent reconstruction;
older policies omit the new field entirely.

Verification is zero-world and uses the real exported native interfaces:

- 326 core tests pass, including 288 selector truth-table cases, a 400-input
  synthetic chain, activation/deactivation and contact/state refusal cases.
- Four exported-interface tests pass in 14.39 seconds on their first attempt.
  All 400 saved V38 inputs are fed through the new controller with its memory
  chained; stateless and session outputs match byte-for-byte at every step.
- All 400 V38 actual position paths, feasible plans and gait memories remain
  exact. Of 3,200 joint commands, 550 select the new rule and 474 velocities
  change. The other 2,650 commands remain completely exact, not just close.
- Independent arithmetic reconstructs 1,600 foot selectors, all 3,200 full
  reference rates, comparison references and motor commands. Maximum comparison
  reference discrepancy is 3.886e-15 radians, below the existing arithmetic
  allowance. Every rate and velocity remains inside its existing selected cap.
- All 3,200 outputs from eight older policies match the previous DLL byte-for-
  byte; six original recovery fixtures also match. None of those policies
  refuses this V38 input population. This does not change the 37 V33 refusals
  previously retained on the different V37 population.
- Nineteen invalid-context cases return safe no-actuation with unchanged
  memory, and four malformed requests are rejected at the interface. The
  component-only profile is explicitly tested to refuse physical selection.

The three build stages take 83.17 seconds for fresh core compilation/tests,
0.33 seconds for fixture verification and 66.09 seconds for the adapter.
Compiler work is cached; test/evidence authority is not. The new 8,451,072-byte
DLL has SHA-256 `4095e594a5925d915081c7fd9a1e3768bd439a478fc3a453c17695330d2ea118`
and is preserved independently under
`SporeSpore_Evidence/development-candidate-build-7b5c5c309ac64dcca0e7eef0fec99d4f/`.
Export logs and the fresh readiness report are under
`SporeSpore_Evidence/development-v39-native-component-9a3f941ddc464edc900f1cc2cfe5acf5/`.

The new controller reaches speed caps 120 times on saved inputs, versus V38's
19. This confirms the earlier algebra sketch, not a new trajectory or better
landing. Faster airborne motion could improve or worsen later contact/pose;
caps do not establish acceleration or impact safety. Stance reach conflicts,
unplanned contact losses, relocation/cycle failures and terminal four-foot
support remain explicit unresolved issues.

Next integrate the verified component into the existing worker/independent
reader, complete the applicable zero-world safety gate, and declare one fresh
bounded diagnostic. Do not use the component-only profile as a runnable route.
No world, solver step or native physics read ran here. R173 remains byte-exact;
fresh SDK1/full readiness is 14/20 and 14/25, with zero invalid proofs. No
recovery, force-aware, equivalence, acceptance or release claim advances.

## V38 landing diagnosis and V39 airborne-reference selection

The [V38 landing diagnosis](../sdk/development/recovery_wave_velocity_landing_diagnosis_v1.json)
uses every saved command and original contact cycle, without loading a native
controller or constructing a model or world. Its complete 1,600-limb-command
timeline is retained as a 3,651,542-byte content-addressed evidence file.
The compact repository record preserves all summary counts and all 13 cycle
decompositions. Command n reads trace n-1; post-command contact is trace n.
There is no invented next-body input after terminal trace 400.

Two distinct mechanisms must not be collapsed into a single timeout story:

- Rear-right holds its landing gate for commands 166-255: 88 of those 90
  commands have no raw native contact. Its measured nominal foot bottom starts
  33.84 mm above the floor even though the complete goal already reaches the
  floor. Only seven hold joint commands are reference-slew-limited and none
  saturates speed. Tracking continues after the references reach their goals.
- The same interval contains 76 front-left and 80 each front-right/rear-left
  phase-sync holds in the actual controller memory. These are observed clock
  holds, not an imagined faster trajectory.
- Rear-left loses native contact after command 286, in stance phase 294,
  well before its first swing at command 352. Of its stance commands, 65 lack
  contact and 45 require link-reach projection. Its ideal stance goal can be
  24.13 mm above the floor at the observed body pose. This is not merely a
  late swing that would necessarily land if given more time.

All 21 true-to-false contact transitions are retained; 17 occur in scheduled
stance. All 13 original dwell-qualified cycles remain, including nine failed
relocations and nine cycles without scheduled swing/landing overlap.
Ideal kinematics omit joint compliance and quaternion transport roundoff.
Nominal foot clearance is not a native contact predicate; even contact-bearing
samples can have small positive nominal clearances.

The [V39 contract](../sdk/development/recovery_airborne_reference_contract_v1.json)
selects a contact- and phase-specific tracking branch, not new gains.
For both joints of a limb, use the full finite difference of the existing
slewed position reference only when both wave snapshots are active, dt is
positive, the current scheduled phase is 0-72, and both current contact
booleans explicitly say absent. Otherwise retain V38's pose-separated wave
rate exactly. Presence without bearing is not treated as airborne; missing
or malformed state must refuse through existing validation. No post-command
contact or outcome-selected time window enters the rule.

On the exact saved V38 inputs, the arithmetic sketch selects 550 joint
commands and changes 474. All unselected commands are unchanged; all rates
and motor speeds retain the existing caps. The sketch has 120 saturated
commands versus the original 19. Those are saved-input arithmetic counts,
not a prediction of the next native run. Switching rates at contact changes
can create abrupt bounded commands, and direct pose-driven corrections
return only in the selected airborne phases. The separate stance-reach,
contact-retention and relocation failures remain explicit blockers.

The [selection and audit receipt](../sdk/development/recovery_airborne_reference_selection_v1.json)
binds six passing tests in 4.96 seconds: complete population/evaluation,
one-step timing, gate and phase-sync observations, all cycle decompositions,
selector boundaries and caps, and crossed-source/floor/timing refusals.
The debugging and testing work separates measured response from geometric
intent rather than treating the proposed branch as an established cause.

Next implement one distinct V39 native component, verify real stateless and
stateful exports against all 400 saved V38 inputs and preserve older raw
outputs, then bind it to the existing shared worker and independent reader.
No physical attempt is authorized by this selection. Keep the same 400-command
budget, evaluator and thresholds; no consumed rerun or horizon extension.
No native controller calls, physics reads, worlds or solver steps ran here.
R173 is byte-exact; fresh SDK1/full readiness remains 14/20 and 14/25 with
zero invalid proofs. No acceptance, force-aware or release claim advances.


## V38 closure: forward bounded motion, unfinished rear-left landing

The [original V38 closure](../sdk/development/recovery_attempts/db53de264ab04bc29157f8a1524e73d0.json)
is a valid consumed development observation from pushed source
`4931509b055fa0cc79012a6a3e1b868e23d02888`. All 113 safety checks pass before
one fresh seed-40200 kicked world executes 1,258 steps. Standing completes
at 858 after the unchanged 60 consecutive stable samples. Independent replay
validates every transition, all 430 contact observations and all 400 resumed
commands. It builds no additional world and takes no native physics reads.

The creature moves **12.57 cm forward**, drifts **1.41 cm sideways**, and reaches
**6.92 degrees** peak tilt. There are zero torso contacts and native gate
timeouts. This is an encouraging bounded observation after V37's backward,
high-tilt trajectory, not a matched effect estimate or proof of superiority.
The original evaluator still fails foot relocation, two contact cycles for
every foot, and terminal four-foot support. Its generic diagnostic coverage
flag means the declared horizon finished, not that every scheduled swing did.

The [complete retained-data observation](../sdk/development/recovery_wave_velocity_observation_v1.json)
includes every counted contact cycle. A counted cycle is a foot leaving and
returning after the original minimum airborne dwell, not necessarily a
planned step. Coordinates measure distal-body origins, not sole contact points.

| Foot | First scheduled swing starts at command | Counted cycles | Smallest forward relocation | First landing wait | Supported at cutoff |
| --- | ---: | ---: | ---: | --- | --- |
| Front left | 1 | 7 | 0.53 mm | 2 commands | Yes |
| Front right | 262 | 2 | 13.12 mm | 2 commands | Yes |
| Rear left | 352 | 0 | No completed cycle | Not reached | No |
| Rear right | 91 | 4 | -16.79 mm | 90 commands | Yes |

Nine of 13 completed contact cycles fail the unchanged 12 mm relocation rule;
nine have no scheduled swing/landing overlap. The rear-right landing wait
spans commands 166-255. Rear-left receives only 49 first-swing commands and
ends at scheduled phase 48, still unsupported. Its incomplete cycle is
retained as incomplete, not assigned a favorable imagined touchdown.
Adding time cannot erase the earlier completed relocation failures.

The nominal common-height interval is empty on 46 of 400 commands; lowering
is requested on 159 commands. These describe the controller's geometry
calculation, not proof of the physical cause of a contact loss or recovery.
Only 19 of the 3,200 observed motor commands saturate. This native trajectory
is distinct from the V38 component's 79 saturated commands on saved V37 inputs.

The [six-check cold audit](../sdk/development/recovery_wave_velocity_closure_audit_v1.json)
passes in 46.08 s. It independently reconstructs all 3,200 comparison targets,
position targets, reference rates and motor velocities, with maximum
comparison-target discrepancy 3.914e-15 rad. It also checks all 1,600 smooth
lift goals, bounds and saturation flags, original stance commands and dwell,
all contact cycles, and refusal of changed reports or claim promotion.

All 63 physical evidence files are retained, totaling 1,077,346,059 bytes,
inventory SHA-256
`300db4643e916978c47b4fd0882cc855113f260da5f57f0233064d94456d853b`.
The complete invocation takes **32 min 15.17 s**: safety checks 792.392 s,
physical child 706.161 s, independent replay 291.062 s and remaining recorded
overhead 145.557 s. These are measured durations, not a causal timing comparison.

Next inspect the saved rear-right landing wait, native contact/target timing,
late rear-left swing and nine failed-relocation cycles before choosing any
successor. No controller, gain, threshold or horizon change is selected here.
Do not rerun V38 or replace its result. R173 remains exact; fresh SDK1/full
readiness remains 14/20 and 14/25, zero invalid proofs. No force-aware,
acceptance, release or cross-engine equivalence claim is advanced.


## V38 connected pose-separated wave-velocity route

The [V38 route integration](../sdk/development/recovery_wave_velocity_route_integration_v1.json)
connects the fixed native component to the shared worker, startup scheduler,
floor adapter and independent reader. The new integrated profile selects
V38 explicitly; the component-only profile still refuses physical selection.
No DLL, controller arithmetic, original result or behavioral threshold changed.

All 19 focused checks pass in 139.96 seconds. The actual detached-floor
constructor and shared adapter replay 200 commands, check 1,600 wave-rate
values, comparison-target shapes and previous-wave memory continuity, and
refuse all 14 existing floor/memory corruptions. The independent event reader
accepts all 49 synthetic recovery events and refuses five corruptions.
Both launcher modes select the complete applicable 113-check safety gate.
The legacy 44-test source suite retains its same three failures and one
error as the frozen baseline: no new failures, not a claim that all 44 pass.

The updated archival resolver returns the same 38/37/36/34/28 original source
bindings for V37/V36/V35/V34/V33 as the pre-change reader, with every binding
independently checked against its immutable closure. Two flawed ad hoc probes
are retained without proof value: one compared empty results after selecting
the schedule container; the other used physical-freeze reader versions that
predated some closure support. The corrected check requires each expected
nonzero count and uses the pre-change HEAD reader as its comparison.

Next, from a clean pushed integration checkpoint, run all 113 safety checks
and one fresh non-comparative seed-40200 SingleKick. Preserve V20 recovery,
stance V7, BW5R-B prefix, clocks 90, the 72-command amplitude ramp and cap
0.5994550408719347, floor geometry, contacts, smooth lift, position-reference
path, speed/force limits and all behavioral criteria. The walking budget
remains 400 commands, the tail 986 steps and the child cap 1,338 steps.
Observe startup, stance contact loss, body travel and tilt, relocation,
landing and coverage; failed or incomplete cycles do not justify extra time.
This integration produces no world, solver step or native physics read.
The native benefit remains unknown. R173 is exact; last compiled SDK1/full
remain 14/20 and 14/25 with zero invalid proofs.


## V38 native component: pose-separated wave speed verified

The [V38 component record](../sdk/development/recovery_wave_velocity_component_v1.json)
binds a new immutable DLL, 322 passing core tests and four passing real exported
interface tests. The build reuses compiler work but reruns all core tests;
core tests/build take 76.42 s, recovery fixtures 0.31 s, adapter build 64.30 s.
The final exported audit takes 13.47 s. No physical world is constructed.

V38 stores the previous upstream wave snapshot in its distinct memory, while
old policies omit the new memory and receipt fields. Its two support-goal
calculations use the same current pose and reference-slew origin. Static wave
inputs give zero added rate under body-height changes and reference catch-up;
initialization and activation/deactivation suppress the extra term. Invalid
memory or comparison geometry refuses with no actuation, not a V37 fallback.

All 400 saved V37 inputs are processed through both real session and stateless
exports with exact raw agreement. All 3,200 comparison references and motor
velocities are independently reconstructed; maximum comparison-reference error
is 1.975e-14 rad. V38 preserves every V37 actual position path and gate memory.
It changes 1,491 velocity commands above the existing arithmetic comparison
allowance and produces 79 saturated commands versus 465 on these saved inputs.
The eight first commands stay exact. This is not a new physical trajectory,
proof of improved walking, or force-aware recovery.

The new DLL preserves 2,800 older-policy outputs byte-for-byte against the
immutable V37 DLL: 400 each for V37, V36, V35, V34, V33, V32 and BW5R-B.
Thirty-seven of those outputs are V33's original reachability refusals at
saved inputs 364–400; preserving refusal is compatibility, not locomotion.
All six recovery fixtures remain exact. The first exported audit mistakenly
required every older-policy result to actuate; its failure log and exact test
source are retained, and the corrected audit checks both success and refusal.
No controller or DLL change was needed for that test correction.

The native profile digest is
`4190154b2d21d9b73f86acac0295774be45e5e94b04443e0694c168a0bb5639e`.
The 8,411,648-byte DLL digest is
`badcdae0cf4cee3035255029632cfa28dfd1379059932e168102e7f493380f78`;
its deliberate durable path and exact source graph are in the component record.
The component profile is nonrunnable: physical selection is explicitly refused.

Remaining work is shared worker/reader integration followed by the complete
applicable safety gate and one newly declared bounded diagnostic. No V38 route
or physical attempt is selected by this component checkpoint. No model, world,
solver step or native physics read ran. R173 remains byte-exact; fresh readiness
is SDK1/full 14/20, 14/25, zero invalid proofs.

## V37 diagnosis and V38 selection: separate wave speed from support corrections

The [saved-input diagnosis](../sdk/development/recovery_reference_velocity_diagnosis_v1.json)
reconstructs all 400 goal sets, 3,200 motor commands and every original contact
cycle from the exact closed V37 report. No controller library, model, world or
new physical read is used. Its new result is about the command calculation,
not a unique physical cause of the backward unstable walk.

The V37 rate term combines four things: catching up to an old target, switching
on the support posture, changing upstream gait targets, and changing support
targets because the measured body pose changed. At walking command 2, all eight
motors hit their speed limits even though the amplitude ramp has barely begun.
The activation component has RMS 3.303 rad/s; the upstream wave-change component
is only 0.00522 rad/s in that ordered decomposition. These magnitudes can cancel
and must not be converted into causal percentages.

| First occurrence in the saved walk | Command | Meaning |
| --- | ---: | --- |
| All eight velocity outputs saturated | 2 | The support-posture activation produces a large rate request. |
| Unplanned stance contact loss | 4 | Rear-right contact turns off while its scheduled phase is stance. |
| Empty common support-height interval | 51 | At these directions and body orientation, no one nominal height satisfies all four legs' joint limits. |
| Original tilt limit exceeded | 369 | The later instability is an existing failed criterion, not a new threshold. |

There are 42 true-to-false contact transitions, 34 during scheduled stance.
After activation, direct pose changes contribute RMS 1.072 rad/s and upstream
wave changes 0.511 rad/s when wave is changed first. Reversing the calculation
order gives 1.064 and 0.493 rad/s respectively. The difference is retained:
clamps make the decomposition order-dependent. Upstream directions also include
steering feedback, so this is not a pure planned-phase derivative.

The [selected V38 contract](../sdk/development/recovery_wave_velocity_contract_v1.json)
changes only the source of the added velocity term. Evaluate the previous and
current upstream wave snapshots at the same current pose, floor, preceding
position reference, time interval and caps. Difference those two bounded target
positions, then retain the existing rate and final output caps. Initialization
and zero/nonzero activation receive zero added rate. Static wave inputs therefore
give zero added rate even when body pose or reference catch-up changes. The
actual position targets, geometry, gains, force limits, gait, gates and recovery
are unchanged. A distinct memory stores the previous wave snapshot; old policies
and consumed evidence remain exact.

On the same saved V37 inputs, this arithmetic sketch changes 1,491 motor
commands above the 1e-12 rad/s comparison allowance, gives 79 saturated commands
instead of 465, and gives zero saturated activation commands instead of eight.
This is **not another physical trajectory** and does not establish better walking.
Both comparison goals can hit the same slew endpoint, giving zero added rate;
slow tracking or landing can remain. Upstream feedback and near-extension
sensitivity also remain risks.

Six diagnosis checks pass in 5.27 s. The first six-check attempt had one faulty
test expectation: it demanded nonzero rate despite identical slew endpoints.
That zero case is now checked alongside a nonzero moving-target case. Both logs
are retained by the [V38 selection](../sdk/development/recovery_wave_velocity_selection_v1.json).
Next: implement and verify one native V38 component, integrate its explicit
identities into the shared route, then run the complete applicable safety gate
and one fresh bounded diagnostic. No V38 native component or physical attempt
exists yet. No gain, threshold, timeout or horizon change is selected. R173 is
byte-exact; fresh SDK1/full readiness is 14/20, 14/25 with zero invalid proofs.

## V37 closure: short landings, backward unstable walking

The [original V37 closure](../sdk/development/recovery_attempts/8ceafcfb9d5c4439859aee7f959e2740.json)
is a valid consumed development observation from pushed freeze
`6cb28e642186bf60052a57b6875925716a2522b5`. All 113 safety checks pass before
one fresh seed-40200 kicked world executes 1,258 steps. Standing completes at
858 after the unchanged 60 consecutive stable samples; the independent reader
validates all transitions, 430 contact records and 400 resumed commands.
Engine health passes with no errors, assertions or fatal diagnostics.

The four first landing holds are now **two commands each**, and every limb
reaches its first scheduled swing within the diagnostic budget. This does not
establish stable landing or gait. The creature travels **24.67 cm backward**,
drifts **9.34 cm sideways**, reaches **46.14 degrees** of tilt and ends with
neither front foot supported. There are zero torso contacts and native gate
timeouts. The unchanged walking evaluator fails bounded tilt, every-foot
relocation, both forward-translation receipts and terminal four-foot support.

The [complete retained-data observation](../sdk/development/recovery_reference_velocity_observation_v1.json)
preserves all original contact cycles. A counted cycle is an observed foot
leaving and returning after the fixed airborne dwell, not necessarily a planned step.

| Foot | First scheduled swing starts at command | Counted cycles | Smallest forward relocation | Supported at cutoff |
| --- | ---: | ---: | ---: | --- |
| Front left | 1 | 7 | -54.87 mm | No |
| Front right | 186 | 5 | -15.77 mm | No |
| Rear left | 282 | 8 | -18.21 mm | Yes |
| Rear right | 96 | 5 | -151.89 mm | Yes |

Twenty of 25 completed cycles fail the unchanged 12 mm relocation rule;
17 have no scheduled swing/landing overlap. Thus the passing two-cycles-per-foot
receipt does not mean two clean scheduled strides. The nominal common-height
interval is empty on 329 of 400 commands. The original tilt limit is first
exceeded at global step 1,227; the first sample with no foot contact is 1,241.
Extending the run cannot undo its completed relocation and tilt failures.

All 63 physical evidence files remain retained, totaling 1,069,818,179 bytes,
inventory SHA-256 `af82a4d5222812d0a9b32813751051384e186ae3b717a5a0cb02ac92dc066553`.
The invocation takes **31 min 10.55 s**: safety checks 755.93 s, child execution
694.19 s, independent replay 280.20 s, other recorded overhead 140.23 s.
These are measured costs, not a causal attribution of timing differences.

The [six-check cold audit](../sdk/development/recovery_reference_velocity_closure_audit_v1.json)
passes in 45.56 s. It reconstructs all 3,200 reference rates and motor velocities,
verifies position/slew/speed bounds and saturation flags, checks all 1,600 smooth
lift goals, and preserves the original evaluation and standing commands.
Next diagnose early backward movement and unintended stance contact loss from
these saved inputs, distinguishing phase-driven targets from observed-pose
support changes before selecting another controller. No new successor is selected
here. V37 is not rerun or rethresholded; R173 stays byte-exact. Fresh readiness
remains SDK1/full 14/20, 14/25, zero invalid proofs; no acceptance or release claim.

## V37 connected reference-velocity route

The [V37 route integration](../sdk/development/recovery_reference_velocity_route_integration_v1.json)
connects the unchanged native component to the shared launcher, recovery worker,
adapter, motor ledger and independent reader through distinct entry/start/policy
declarations. The component-only profile remains non-runnable. No new worker,
physics implementation, observer, limit or evaluator is introduced.

All **19 focused checks pass in 145.09 seconds**. The actual floor constructor
is exercised while detached from a physics world; the adapter and cold reader
process 200 serialized native controller commands and independently reconstruct
all 1,600 retained reference speeds. Fourteen floor/source/memory corruptions
refuse. The shared scheduler and cold event reader validate 49 synthetic recovery
transitions and five corrupted event streams; earlier-phase event bytes remain
unchanged. Startup preserves clocks 90, the 72-command ramp and neutral first
references. Both launcher role modes select the complete 113-check V37 gate.

The updated archival resolver reproduces V36/V35/V34/V33's original walking
source bindings exactly (37/36/34/28 entries). The historical 44-check source
suite has the same three failures and one error before and after; this is a
no-new-failures comparison, not a claim that the old suite passes.

Next complete all 113 applicable safety checks, then one fresh seed-40200
SingleKick from the clean pushed integration. Preserve the 986-step tail,
1,338-step child cap and 400-command walking budget. The question is whether
reference-rate tracking improves landing and joint tracking without worsening
stance, attitude or foot relocation. Retain all negative and incomplete behavior
at the unchanged cutoff. No world, solver step or native physics read occurs in
this integration. R173 is exact; SDK1/full remain 14/20, 14/25.

## V37 native reference-velocity component

The [V37 native component](../sdk/development/recovery_reference_velocity_component_v1.json)
is implemented under distinct policy, profile, memory and top-level receipt
identities. It retains V36's position path and adds the bounded speed of that
path to the motor's position-error correction and reference-relative damping.
No new measurement, body impulse, transform write, gain or limit is introduced.
Its component profile deliberately refuses physical selection until a separate
shared-route integration is complete.

All **318 core tests** pass. Four actual exported-interface checks pass in
**9.56 seconds**: 400 exact session/stateless output matches, independent
reconstruction of all 3,200 velocity commands, unchanged parent position paths,
height plans and scheduling, plus explicit missing/crossed/source/time refusals.
The eight initial commands remain exact. On these saved inputs, 3,123 commands
change and 280 reach the unchanged velocity cap; none exceeds it. All 2,400
older-policy outputs and six recovery fixtures remain byte-exact. These are
controller calls on saved observations, not a new physical trajectory.

The immutable optimized DLL has SHA-256
`16e557c405004ce536718d16c62d9500696772a8ccbb2ee141813c10d3a06c82`.
The shared compiler cache saves build work but substitutes for no test or
qualification; old pinned images remain unchanged. Core testing, fixture
capture and adapter build took 87.95, 0.70 and 62.27 seconds respectively.

Next bind V37 into the shared entry/start/policy route and independent reader,
then complete the applicable safety gate and one fresh bounded SingleKick.
The unresolved physical questions remain landing delay, stance interruptions,
foot relocation and full scheduled-cycle coverage. No new world, solver step,
native physics read or acceptance claim occurs here. R173 remains byte-exact;
fresh readiness compilation reports SDK1/full 14/20, 14/25, zero invalid proofs.

## V36 tracking diagnosis and V37 reference-velocity selection

The [six-check retained-data diagnosis](../sdk/development/recovery_smooth_swing_tracking_diagnosis_v1.json)
finds no unreachable or joint-limit-clipped goal in the 163 held landing commands.
Front-right's last pre-command nominal foot clearance is 0.52 mm, with no raw
contact during its 69-command hold. Its knee-position error falls from 0.289 to
0.0011 radians. Reachability alone therefore does not establish timely landing.
Stance interruptions and the original eight failed relocation cycles remain.
The terminal foot record has no next controller input; no terminal joint/body
pose or post-command response is invented.

All 3,200 saved motor commands match the existing control law independently.
That law reacts to position error and measured joint speed, but omits how fast
the desired joint angle itself moves. The separately identified
[V37 selection](../sdk/development/recovery_reference_velocity_selection_v1.json)
and [prospective component contract](../sdk/development/recovery_reference_velocity_contract_v1.json)
add a bounded reference-rate term after V36's unchanged position-reference slew.
For a velocity-output servo, the new command is reference speed plus position
correction minus damping of speed relative to that reference. Its coefficient
is derived from the existing damping, not fitted to a successful physical result.

On identical saved inputs, arithmetic changes 3,123 of 3,200 commands, leaves
the eight initial commands unchanged, and reaches the existing speed cap on
280 commands rather than zero. This is not an alternate trajectory: real motor
response, torque limits and contacts still require a fresh physical test. More
assertive commands could worsen stance stability. All position paths, gains,
speed/force caps, contact gates, schedule and evaluator stay unchanged.

Next verify a distinct immutable native component, then integrate the shared
route and run the applicable safety gate before a fresh bounded diagnostic.
No new world, solver step, native physics read, acceptance or score claim occurs
in this diagnosis. R173 is byte-exact; SDK1/full remain 14/20, 14/25.

## V36 closure: smooth lift executed, walking still negative

The [original V36 closure](../sdk/development/recovery_attempts/9959c99703944cbd80789ac00ed2d90c.json)
is a valid, consumed development observation from pushed freeze
`77988eefde092a3ff0d618803b998d7f169ce7ba`. All 114 safety checks pass before
one fresh seed-40200 kicked world takes 1,258 solver steps. Standing completes
at step 858 after the unchanged 60 consecutive stable samples. The independent
reader replays all 1,258 transitions, 430 native-contact records and 400 resumed
commands. The complete 63-file physical population is retained:
1,070,357,679 bytes, inventory SHA-256
`b603821edb921a513724433d8fa70ebc5610af743b62e9bbeb5ccc14fa1e2e7c`.

The creature advances **8.59 cm** with **0.56 cm** lateral drift, maximum body
tilt **2.60 degrees**, and zero torso contacts during resumed walking.
Nevertheless, the unchanged walking evaluator fails the same three requirements:
every foot's forward relocation, two contact cycles per foot, and terminal
four-foot support. There are no native gate timeouts. A still-open landing hold
at the diagnostic cutoff is not a completed landing or a timeout.

The [retained-data observation](../sdk/development/recovery_smooth_swing_observation_v1.json)
includes every resumed command and every original dwell-qualified contact cycle.
A counted cycle means a foot lost contact and returned after the existing minimum
airborne time; it does **not** necessarily mean the controller planned a step.

| Foot | Commands with a planned swing | Counted contact cycles | Smallest forward relocation in a counted cycle | Supported at the end |
| --- | --- | ---: | --- | --- |
| Front left | 1–74 | 5 | 1.37 mm | Yes |
| Front right | 257–330 | 0 | No completed cycle | No; landing held for commands 332–400 |
| Rear left | None within this budget | 2 | 8.50 mm | No |
| Rear right | 97–170 | 3 | -18.55 mm, meaning backward | Yes |

Eight of ten completed cycles fail the unchanged **12 mm** relocation rule;
six have no planned swing/landing overlap. The first front-left planned swing
contains two contact cycles (6.97 and 11.84 mm); neither passes. Rear-right
landing holds for 79 commands. Rear-left's two counted cycles are stance
interruptions, not evidence that its planned swing was exercised. These
positions are distal-body origins, not invented sole contact points.

All 400 nominal height intersections are nonempty in V36, compared descriptively
with 94 empty intersections in the retained V35 trajectory. V36 requests
lowering on 96 commands. Neither a nonempty geometric interval nor this
one-run descriptive difference establishes native support, causation or
superiority. V35's observed record and interpretation remain unchanged.

The [six-check cold audit](../sdk/development/recovery_smooth_swing_closure_audit_v1.json)
passes in 34.843 s. It exactly reconstructs the original closure, reuses the
standing-command audit, verifies all 3,200 bounded joint commands and 1,600
phase-only lift fractions, checks all original cycles, and rejects crossed
floor data and claim promotion. The smooth lift was executed, not merely
declared. No new native controller call, physical world or solver step is
needed for these retained-data checks.

Measured invocation time is **24 min 9.454 s**: safety stages 593.902 s,
physical child 528.459 s, independent replay 213 s, and other orchestration/
publication work 114.093 s. This is an observed run duration, not a controlled
speedup claim.

Next use retained command, joint and body geometry to diagnose the long
rear-right/front-right landing holds and unintended stance contact losses.
Keep first-swing relocation and unexercised rear-left/two-cycle coverage explicit.
More time cannot repair the eight completed negatives. No new controller,
rerun or horizon extension is selected by this closure. R173 stays exact;
SDK1/full remain 14/20 and 14/25, zero invalid proofs. No force-aware recovery,
acceptance, cross-engine effect or release authority is earned.

## V36 connected smooth-swing route

The [V36 integration record](../sdk/development/recovery_smooth_swing_route_integration_v1.json)
binds a distinct runnable profile to the already verified native component.
Shared adapter, entry/start/policy and reader selection now recognize V36's
policy, memory and receipt identities. The DLL and all native source remain
unchanged from the component checkpoint. The component-only profile still
refuses physical selection; old policies, results and thresholds remain exact.

All 19 focused checks pass in 112.938 s of completed stage time: launcher
selection, six actual-floor/motor-ledger checks, four route checks and four
startup checks. The cold reader replays 200 commands and refuses 14 corruptions;
the shared scheduler and event reader cover 49 synthetic events and five
corruptions. Startup covers 450 native commands. One earlier 12.022 s route
setup failure is retained: the test fixture supplied an older policy digest
for V36, which the actual validator correctly refused. A test-only selector
fix resolved it; no controller, DLL or physical schedule was changed.
The historical 44-check source comparison has no new failures, not a clean
pass: the same three failures and one error remain in both projections.

Frozen V35/V34/V33 archival resolution is unchanged (36/34/28 source bindings).
The applicable pre-physics gate now selects 114 checks. Next clean pushed
freeze, exact frozen V36 lookup, that full gate and one fresh non-comparative
seed-40200 SingleKick. The 986-step tail, 1,338-step cap, 400-command resumed
walk, stance-height plan, contact gates, motor bounds and all behavioral
criteria remain unchanged. No longer horizon, cached baseline, bundled support
correction or force-aware claim. This integration builds zero worlds and takes
zero solver steps or native physics reads. R173 stays exact; readiness remains
SDK1 14/20 and full program 14/25 with zero invalid proofs.

## V36 native component: phase-only swing lift

The [V36 component](../sdk/development/recovery_smooth_swing_component_v1.json)
implements the [selected lift-only correction](../sdk/development/recovery_smooth_swing_contract_v1.json)
in the Rust controller. Contact no longer switches the raw knee-lift curve at
liftoff; it still controls the existing gates and motor limits. V35's floor,
height plan, support composition and reference slew are unchanged. Distinct
policy/profile/memory and actuation-receipt identities identify V36; old
profiles and receipts omit its optional lift-mode field byte-for-byte.

The separate DLL is 8,356,864 bytes, SHA-256
`7056f352d86bbddcc29c49014c70e00441fdb76a5702fd12e057fac606230695`.
It is durably retained under `development-candidate-build-0d6b2470f3e94b9fa85d583124a98b82`;
the [runtime binding](../sdk/development/recovery_candidates/v36-smooth-swing-v1.runtime.json)
records every compiled source, compiler option, log and independent DLL copy.
The [component profile](../sdk/development/recovery_candidates/v36-smooth-swing-v1.json)
deliberately refuses physical selection. No default extension or old DLL changes.

All 314 core tests pass, including four V36 tests. Five actual exported-ABI
checks pass in 8.750 s: all 360 fixed-phase contact pairs, exact session/stateless
outputs on 400 saved V35 state/command inputs, all 400 matched-input parent
height plans/gate memories, all 3,200 bounded references, 2,000 byte-exact older
policy outputs (400 each for V35, V34, V33, V32 and BW5R-B), and six unchanged
recovery fixtures. The new sequential reference chain changes 291 knee goals
and slew-limits 315 actuator commands on those saved inputs. These are native
controller calculations, not another physical trajectory or a walking result.
Core tests/build take 63.875 s, fixture emission 0.453 s and adapter build 55.187 s.

Two new-test defects were caught before any physics: creation-only fields sent
to session-step were correctly refused, and canonical-hash projection rounded
fractional test inputs. Both failed runs and original test sources are retained.
The corrected probe preserves fractional binary64 input values, normalizes only
integral numbers as the adapter does, and compares actual parent/native outputs
on identical inputs except their required policy/memory identities. Explicit
negative/precision checks prevent those test mistakes from silently returning.
No controller change or rebuild was needed for either correction, and no old
test, physical report, threshold or evaluator was rewritten.

Next integrate V36's entry/start/policy contracts and new receipt/memory handling
through the shared real worker and independent reader. Run the full applicable
safety gate before a fresh declared seed-40200 SingleKick with the unchanged
400-command diagnostic budget. Keep the four physical blockers from the
selection; no extra support correction or horizon is bundled into V36.
Zero new models/worlds, solver steps or native physics reads at this boundary.
R173 exact; SDK1/full 14/20, 14/25, zero invalid proofs. No physical acceptance,
force-aware recovery or release authority.

## V35 step diagnosis and V36 smooth-lift selection

The [complete retained step diagnosis](../sdk/development/recovery_feasible_support_step_diagnosis_v1.json)
uses all 400 V35 commands, 1,600 pre-command limb samples, all 16 original
contact cycles, eight within-swing contact transitions and all 94 empty height
intervals. [Six cold checks](../sdk/development/recovery_smooth_swing_selection_audit_v1.json)
pass; no native controller, new world, solver step or physics read is invoked.
Command n reads trace n-1; measured responses and target geometry are kept
separate, and no terminal joint/body sample is invented.

| Finding | Plain-language meaning | What it does not prove |
| --- | --- | --- |
| Five liftoffs precede lower knee goals; only three lower the slew-limited reference | The lift formula withdraws assistance just when a foot leaves the ground; reference smoothing can mask that drop temporarily | That the commanded drop causes every physical hop |
| First front-left cycles advance 5.12 and 8.96 mm | Both miss the unchanged 12 mm minimum | That increasing amplitude or time alone will repair them |
| In the second cycle, joint change contributes +25.73 mm and body rotation -18.13 mm in the declared ordered decomposition | Body rotation offsets much of the leg's forward motion | A unique causal separation or a prediction for a different controller |
| Ten cycles have no scheduled swing/landing overlap; six overlap lowering requests and four do not | Some support feet briefly lose contact, with more than one situation involved | That all contact gaps are caused by the height planner |
| All 94 empty intervals conflict between front-right's minimum and rear-left's maximum; gap up to 12.31 mm | Those saved leg directions cannot share one torso height inside their joint bounds | That removing swing legs solves it: eight intervals remain empty |

The [V36 selection](../sdk/development/recovery_smooth_swing_selection_v1.json)
changes only the raw swing knee-lift curve in a new policy. Instead of adding
assistance only while contact exists, use
`amplitude * (0.82 * 1.75 + 0.40) * sin(pi * phase / 72)` during swing and
exactly zero at landing/stance. The peak uses the existing loaded-swing value,
not a fitted increase. The existing 0.599455 amplitude cap, 72-command startup
ramp, first neutral reference, bounded support composition, joint/reference
limits, contact gates, motors, actual floor and V35 height plan stay unchanged.
The curve is continuous in value, not a claim of derivative continuity.

Next implement the native component, verify same-input contact sensitivity,
phase endpoints and old-policy compatibility, then integrate the shared real
route. Only after the complete applicable safety gate may a fresh declared
SingleKick test the new curve. Keep the 400-command diagnostic budget; no
extra horizon or support correction is bundled into this selection. More lift
after release may delay landing; less assistance early in swing may delay
liftoff. Neither improved first-step placement nor sustained support is proved.

The finite blocker list is first-swing fragmentation/placement, stance contact
gaps, height/attitude compatibility, and missing landing/repeated-cycle coverage.
V35's original evaluation and all retained records stay unchanged. R173 exact;
SDK1/full 14/20, 14/25. This is neither force-aware recovery nor acceptance.

## V35 physical closure: forward progress with foot-cycle failures

The [V35 physical closure](../sdk/development/recovery_attempts/2d88c07d2ae0497a8fe9bc1fb60832e5.json)
records one fresh seed-40200 SingleKick at pushed freeze `6a14d37a`.
All 113 safety checks pass. One same-body world executes 1,258 steps, standing
completes at step 858 after 60 consecutive stable samples, and walking resumes
for steps 859–1258. Independent replay validates every transition, 430 native
contact steps and all 400 resumed commands. The retained population is 63 files,
1,069,954,004 bytes. [Five cold closure/observation checks](../sdk/development/recovery_feasible_support_physical_closure_audit_v1.json)
pass in 33.021 s.

The body advances 0.12746422657976403 m (12.75 cm), with 1.71 cm sideways drift,
maximum tilt 0.10654 rad, heading drift 0.05721 rad and no torso contact.
There are zero actual native landing timeouts. This is a valid development
observation, not successful completion of the full kick–recover–walk behavior:
the original evaluation still fails per-foot forward relocation, two contact
cycles per foot and terminal four-foot support. No threshold is changed.

The [complete retained observation](../sdk/development/recovery_feasible_support_observation_v1.json)
separates commanded gait phases from measured contact cycles:

| Foot | First scheduled swing, local command | Landing-hold commands | Completed contact cycles | Contact at cutoff |
| --- | ---: | ---: | ---: | --- |
| Front left | 1 | 9 | 7 | Yes |
| Front right | 238 | 7 | 5 | Yes |
| Rear left | 328 | Not reached | 0 | No; scheduled phase 70, before landing phase 72 |
| Rear right | 91 | 66 | 4 | Yes |

A contact cycle is an observed takeoff/touchdown pair satisfying the original
three-step airborne dwell, not necessarily a planned swing. Twelve of sixteen
completed cycles fail the original 1.2 cm minimum forward relocation; ten cycles
have no overlap with that foot's scheduled swing or landing commands. The two
front-left cycles overlapping its first swing advance only 5.12 and 8.96 mm.
Coordinates here are the original distal-body origins, not inferred sole contacts.
More time cannot erase those already-completed short/backward cycles, and the
rear-left cutoff is not evidence of a failed landing that was never reached.

All 3,200 requested joint references respect existing joint and slew bounds.
The native planner requests lowering on 144 commands for 438 stance-limb
commands, up to 11.704 mm on a single command. Actual pre-command body height
ranges from 0.389794 to 0.367615 m; this change is not causal proof of the
height request's effect. Ninety-four commands have an empty common feasible
height interval and correctly request no lowering. Swing and landing retain
actual-floor targets; floor source/model continuity and native memory replay
remain exact. No force-aware behavior, reset or body pose/velocity write occurs.

Elapsed time: 1,554.498 s overall (25.91 min), including 613.402 s safety checks,
570.672 s physical child and 228.891 s independent replay. The earlier
[zero-world fixture failure](../sdk/development/recovery_attempts/4a7d2a0b220547d6a19d6421411b45bf.json)
remains separate and negative. An initial closure-copy integer/float conversion
was caught by strict cold comparison; the rejected copy is retained and the
repo closure uses the generator's exact numeric text. Original physical data
and its successful independent replay were never changed.

Finite next work: diagnose first front-left placement, stance contact losses
and common-height conflicts from this retained trace before choosing a native
successor. Assess the still-unexercised rear-left landing separately. Do not
extend this consumed horizon, rethreshold, call contact interruptions intended
steps, or claim a longer observation would fix completed failures. No new run
or controller is selected at closure. R173 is exact; readiness recompiles to
SDK1/full 14/20, 14/25 with zero invalid proofs and no acceptance promotion.

## V35 shared route integration

The first complete gate at `1d5d9f8a` stopped before a world on a test-fixture
mismatch. Its [unchanged zero-world closure](../sdk/development/recovery_attempts/4a7d2a0b220547d6a19d6421411b45bf.json)
retains 73 passing preceding checks and the four-test failing startup stage
(one pass, two failures, one error). All 450 synthetic native commands were
valid. Of 37 GDScript assertions, only the first-swing inference failed:
combined knee targets include stance support bending, not just swing.
The corrected fixture uses the existing separate swing fraction for policies
declaring a stance-support mode. Test-only startup/entry/schedule identity lists
now include V35. All 14 affected checks pass in 76.784 s. No native source,
DLL, production route, candidate profile, schedule, evaluator or threshold
changed. A fresh attempt must pass the full gate before physics; the consumed
failure is neither retried under its old identity nor relabeled successful.

The [V35 integration record](../sdk/development/recovery_feasible_support_route_integration_v1.json)
binds the distinct integrated profile, shared adapter, session start, motor
ledger, saved-command reader and closure reporter. Nineteen focused checks
pass without a world: six actual-floor/adapter checks (66.405 s), four worker
route checks (27.073 s), five profile/launcher checks (6.658 s) and four native
compatibility checks (9.218 s). The latter reuse the existing DLL; no rebuild
or native-source edit occurred here.

The actual adapter executes and retains 200 synthetic-state commands, all
independently replayed in a fresh reader process. Fourteen corrupted inputs
refuse. The shared worker/event route replays 49 synthetic events and rejects
five corruptions. V35's entry/start/policy contracts resolve through the real
closure reporter, including crossed identities and source-drift refusals;
this pre-commit check uses an explicitly owned file projection, not a claimed
Git freeze. Pure frozen-object lookups for V34 and V33 remain exactly equal
to the previous resolver. The old 44-test source suite still has its same
three failures and one error; this is no new regression, not an all-green suite.

The floor test producer, real motor ledger and reader-corruption population
are parameterized through small V35 selectors rather than copied. Actual floor
construction/capture, native contacts, V20 recovery, prefix BW5R-B, stance V7,
phase clocks, gains, motor caps, horizon and behavior criteria stay unchanged.
All 1,600 old native outputs and six recovery fixture lines remain exact.

Finite next work: clean pushed integration freeze and exact frozen lookup,
complete applicable 113-check safety gate, then one fresh non-comparative
seed-40200 SingleKick. Ask whether the stance-height request produces enough
measured lowering for landing and forward foot relocation within the existing
986-step tail and 1,338-step cap. Do not equate a reference height with actual
body movement or force support. No V35 physical result or acceptance claim
exists at this boundary. R173 remains byte-exact; readiness recompiles to
SDK1/full 14/20, 14/25 with zero invalid proofs.

## V35 joint-feasible stance-height native component

The [V35 component](../sdk/development/recovery_feasible_support_component_v1.json)
implements the [prospective geometry contract](../sdk/development/recovery_feasible_support_contract_v1.json)
under policy `sporespore_balanced_wave_recovery_feasible_support_v1`.
It is a distinct native component, not a qualified physical route or an edit
to the consumed V34 result.

For each existing leg direction, the planner derives the range of floor-relative
torso heights compatible with both hip and knee limits. It intersects all four
ranges and requests only the necessary lowering; it never requests a rise.
An empty intersection or an already-too-low body disables this correction
explicitly. The support geometry is nominal endpoint geometry, not a collision
or load-support guarantee.

Only legs whose actual post-gate clock is strictly after swing end receive
the common stance-height reference. Swinging legs and legs held at the landing
gate continue using the real floor and measured torso height. This preserves
the distinction between asking stance legs to lower the torso and asking the
landing leg to reach the floor. Phase clocks, gate dwell/timeouts, existing
swing composition, neutral first reference, target slew, gains and motor caps
are unchanged. New receipt fields retain the height interval, proposed lowering,
participant limbs, per-limb reference height and scheduled phase; older policy
serialization omits them.

All 310 core tests pass, including seven new checks for interval/hip bounds,
both link-length orderings, refusal, phase separation and 400-step scheduling.
Four exported-native checks pass in 7.167 s. An independent closed-form inverse
checks the native bisection-derived intervals. All 400 session/stateless responses
are exactly equal, and all 3,200 commands respect existing joint and slew bounds.
On V34's retained inputs, lowering is requested on 314 steps for 948 scheduled
stance-limb commands, up to 0.014192730063184 m; all 400 intersections are nonempty.
These are component proposals, not measured V35 movement or an alternative rollout.
The previous DLL and new DLL produce 1,600 identical raw outputs across V34,
V33, swing-end and BW5R-B policies, plus six unchanged recovery fixture lines.

The optimized runtime build takes 119.64 s across core tests, fixtures and
adapter compilation. Its image is retained independently from the compiler
cache; no old runtime is overwritten. The new component profile deliberately
refuses physical selection. Finite next work: bind the V35 route/receipt/memory
identities, parameterize the existing floor-source and motor-ledger/replay checks,
then run the complete applicable gate and one fresh seed-40200 SingleKick under
the existing horizon from a clean pushed freeze. No longer cutoff, sweep or
force-aware behavior is selected. No world or physics read ran here; R173 is
exact and SDK1/full remain 14/20, 14/25 with zero invalid proofs.

## V34 closure: floor-bound route valid, walking still negative

The [original V34 result](../sdk/development/recovery_attempts/beb9c66e4c194930b6283fd227613f44.json)
is closed and consumed at freeze `ef4636af0eaac60a997d43547178d575ec52b1f9`.
The fresh seed-40200 SingleKick passes all 113 safety checks, executes one world,
one kick and 1,258 solver steps, and retains 63 files / 1,065,502,894 bytes.
Independent replay validates all 1,258 transitions, 430 native-contact steps
and 400 resumed controller commands with no new world or physics read.

The same creature completes standing at step 858 and resumes walking at
859–1258. All 400 commands consume the same actual constructed-floor source,
including its signed Godot resource identity, model binding and finite extent.
All 3,200 joint targets remain within existing limits; 120 are reference-slew
limited and 778 limb proposals exceed directional link reach. The controller
retains those projections rather than claiming that a reachable floor contact
exists. No body rebuild, pose/velocity write or solver reset occurs.

| Resumed-walk observation | Original result |
| --- | --- |
| Standing before resumed walking | Complete, including 60 consecutive stable samples |
| Forward travel | 0.019951651740741427 m; fails the unchanged 0.02 m minimum |
| Sideways drift | 0.005492380489120929 m |
| Maximum tilt / heading drift | 0.05241498037961852 / 0.04179125885265478 rad |
| Torso contacts during resumed walking | 0 |
| Counted foot cycles: front-left / front-right / rear-left / rear-right | 4 / 0 / 0 / 5 |
| Terminal four-foot support | Passes |
| Native recontact timeouts | 1: front-left, resumed command 196 |

The four original failed receipts are forward foot relocation, two contact
cycles per limb, minimum evidence forward translation and minimum final forward
translation. The historical evaluator's summary-derived timeout-free flag is
still true; it does not inspect the native timeout counter. Both values are
retained, with the distinction explicit, and neither is regraded.

The [retained-data diagnosis](../sdk/development/recovery_floor_support_recontact_diagnosis_v1.json)
examines all 400 commands, 1,600 precommand limb/body samples and every native
landing-hold increment. Front-left commands 76–195 request a direction beyond
link reach in all 120 samples, leaving nominal target clearance 0.47–9.16 mm.
In 32 samples, even relaxing planar joint-angle limits cannot reach the floor
at the measured torso pose. Rear-right commands 277–373 have a reachable nominal
floor goal but delayed measured tracking: 97 hold steps. Front-right swing
therefore starts at command 380; rear-left does not start within this horizon.
These are measured timing and ideal-geometry facts, not proof of a complete
causal explanation, a contact-margin model or an alternative physical outcome.

Next bounded work is a separately versioned reachable-touchdown/support-height
proposal. Check landing direction, full link reach and compatibility with the
supported torso before another candidate. Keep joint limits, reference slew,
contact rules and official gates; do not extend the consumed horizon, alter a
threshold, claim force-aware recovery or introduce an unbounded parameter sweep.

Measured wall time: 1,587.665 s total (26.46 min), 648.837 s safety gate,
581.109 s child and 228.922 s independent replay. The remaining 128.797 s is
other orchestration/publication overhead, not isolated solver time. The
closure reporter initially omitted V34's three contract lookups; its additive
archival lookup fix changes no physical input or original replay. Six cold
closure checks and three diagnosis checks pass. Initial reporting/test errors
and the exact correction evidence are retained in the
[closure audit](../sdk/development/recovery_floor_support_closure_audit_v1.json).
V33's archival source resolver and closure bytes remain exact; the current
launch validator correctly refuses its superseded live dependency graph.
R173 remains exact, SDK1/full remain 14/20 and 14/25, and no support/acceptance
or cross-candidate superiority claim advances.

## V34 connected floor-source route

The [first full-gate attempt](../sdk/development/recovery_attempts/5a2098c021324698b53ec8c6736d18dd.json)
is closed before physics. Its first 49 checks pass; one launcher test still
expects the V32 test-suite filename instead of the correctly selected V34 suite.
A subsequent targeted whole-report check finds a synthetic fixture missing the
base descriptor present in the real worker configuration. Both fixes are in
tests only: preserve exact V34 suite/count expectations and supply the production
descriptor before the fixture configuration is hashed. All 28 candidate checks
now pass, including independent full-report replay and four native component
checks. Both original failures and source snapshots remain retained. No controller,
floor source, runtime, schedule, limit, criterion or reader relaxation changed.
Next a fresh attempt identity and the entire 113-check gate, then the same bounded
SingleKick question; no world has run for V34 yet.

[The integration record](../sdk/development/recovery_floor_support_route_integration_v1.json)
binds the source, original failed check and all retained focused checks.
The separate [prospective candidate](../sdk/development/recovery_candidates/v34-floor-support-integrated-v1.json)
selects V34 only for resumed walking. The original component profile remains
non-runnable, and no consumed candidate, native image or physical result changes.

The native world builder and detached checks now use the same floor constructor;
its construction statements are verified unchanged. The producer reads that
actual static box's dimensions, shape margin, collision identity and complete
translation chain. The plane is its nominal top in world Y-up metres, not an
assumed zero or a native contact measurement. Rotation, scale, moving or missing
surfaces refuse. Model, floor and shape identities are retained as exact decimal
strings, including negative signed resource IDs. The source binds at session
start and is checked again before sampling each command.

The independent reader reconstructs the top and finite XZ rectangle from the
retained source, verifies model/session continuity and matches the v2 request.
A conservative compiled-body/limb reach bound must fit inside that rectangle;
otherwise the request refuses. This limits where the plane may be used, without
changing a walking-success criterion or asserting support near a floor edge.
The inside-scene global-transform cross-check remains mandatory in the physical
route; detached checks cannot prove that branch or a physical outcome.

All **24 focused checks pass in 164.93 s**: six floor/adapter checks, four route
checks, four startup checks, six entry/retention checks and four schedule checks.
They cover **200** consecutive V34 native commands and fresh-reader replay,
**14** corrupted report refusals, **450** synthetic startup commands, **49**
synthetic state transitions, real motor-application ledger operations, and
unchanged earlier-phase event bytes and motor caps. Independent Python arithmetic
also verifies authored, parent/shape-translated and top-level floor geometry.
The historical 44-test source suite retains its same three failures and one
error, with no new failures; it is not reported as passing.

The first floor check rejected a real negative signed shape-resource ID because
the new reader incorrectly required a positive integer. Its source and original
logs are retained. The fix preserves exact nonzero signed IDs; no tolerance,
controller, floor geometry or behavioral threshold changed. The initial five
floor checks then passed in **31.52 s** before the whole route was connected.

Next: a clean pushed prospective boundary, the complete **113-check** applicable
safety gate, and one fresh seed-40200 `-SingleKick` child. The gate must pass
before any world. Keep V20 recovery/stance V7, prefix BW5R-B, clocks 90,
72-command amplitude ramp and cap 0.5994550408719347, motor limits, native
contacts, solver, 986-step tail and 1,338-step child cap unchanged. Retain and
independently replay the complete result, including a negative or unexercised
walking phase. No force-aware recovery, comparison, acceptance or release
authority; R173 and SDK1/full remain exact at **14/20, 14/25**.

## V34 floor-referenced native component

[The component record](../sdk/development/recovery_floor_support_component_v1.json)
binds the optimized DLL, source graph, original failures and four passing
[exported-interface checks](../tests/test_development_v34_floor_support_component.py).
The new policy is `sporespore_balanced_wave_recovery_floor_support_v1`; no old
policy, observed attempt, selected release policy or physical criterion changes.

The [floor context contract](../sdk/development/recovery_floor_reference_contract_v1.json)
adds an explicit **static horizontal surface** in the same world position frame
and metres as the measured torso. Its source geometry digest, surface and
instance identity, frame and height bind on the first accepted step and must
remain identical thereafter. Context-bearing requests use **v2**; existing
context-free v1 requests retain their path. Null, missing, crossed-policy,
wrong-frame and changed-context inputs refuse. The core verifies syntax and
continuity; it cannot prove that a caller's digest describes the native floor.
The adapter and independent reader must establish that connection.

V34 uses measured torso height above this supplied plane, projects leg reach
and existing joint bounds, and retains the nominal residual. It reuses V33's
neutral startup, swing composition, reference slew, gains, motor caps and gait
scheduler. No force estimator, new physical tolerance, longer limb or successful
contact assertion is introduced. Vertical world translation with the plane
translated by the same amount preserves the geometric targets.

Verification at this boundary:

- **303 core tests** pass, including five new context, translation, geometry,
  refusal and serialized-sequence tests. Optimized build stages take **66.266 s**
  for core tests including compilation, **0.359 s** for fixture replay, and
  **61.672 s** for adapter compilation.
- **1,200** old/new DLL outputs match byte-for-byte: 400 each for V33, V32 and
  BW5R-B on the same retained state inputs with their correct memory schemas.
  These are output-preservation probes, not three physical trajectories.
  All **six** old recovery fixtures remain exact.
- All **400** new retained-input commands match byte-for-byte between the
  stateless and session APIs. The **3,200** joint references remain bounded;
  **216** commands require slew limiting and **279** leg proposals require
  reach projection. Maximum nominal support residual is **24.175 mm**. The
  supplied floor here is an explicitly labeled component fixture, not native
  floor-producer evidence or an alternative V34 physical outcome.
- Four malformed request cases and five unsafe context/policy cases refuse.
  The complete four-test exported audit passes in **8.242 s**. Its first run
  caught a test comparing pre-canonical memory with the encoded input; the
  corrected assertion uses the actual input exactly, without a new tolerance
  or native code change. The failed source and logs are retained in the record.

The exact DLL is
`sha256:e77b0adeae626edb88e06a82df534e324e85831394c8e73a0c3c0b2e9aacb77f`,
retained under
`SporeSpore_Evidence/development-candidate-build-4ee81e20f39043b89ee66f66d6c6c973`.
The passing exported audit is
`SporeSpore_Evidence/development-v34-component-audit-fb2e15821838451b99d8da8f7700892d`.
The [component profile](../sdk/development/recovery_candidates/v34-floor-support-v1.json)
is deliberately non-runnable.

Next connect actual floor/shape transforms, finite extent and model provenance
to the request, retain those source values and verify them independently. Then
integrate the selected policy through the actual walking adapter and shared
recovery route, pass its complete applicable safety gate and run one fresh
bounded SingleKick. No baseline caching, horizon extension or threshold change.
R173 remains byte-exact; SDK1/full remain **14/20, 14/25**.

## V33 support tracking diagnosis and floor reference precheck

Historical diagnosis; V34's native implementation boundary is above.

[The retained diagnosis](../sdk/development/recovery_bounded_support_tracking_diagnosis_v1.json)
and [four executable checks](../tests/test_development_v33_support_tracking_diagnosis.py)
use V33's own report, unchanged closure and frozen controller sources. They
reconstruct **1,600 precommand body samples**, **3,192 measured joint responses**
and all **15** evaluated foot cycles. Command `n` reads trace `n-1`; response
error compares trace `n` with command `n`, never with a later request. The
last trace has foot positions/contacts but no next-command body pose, so only
**14** cycle endpoint decompositions are available. No endpoint is invented.

The bounded-support controller aligns nominal support targets around a
**proposed torso height**. At the actual measured torso pose, its nominal
support-foot height above the authored floor equals:

`actual torso height - proposed torso height + retained joint-projection error`

That identity agrees across the native/walking coordinate conversion to
**6.23e-9 m**. This is a geometric limitation of the current command calculation,
not proof that it caused every contact loss. Counts cover the full population:

| Leg | Scheduled-support commands | Nominal goal above floor | Explicit-floor request beyond reach at the same leg direction | Fixed torso cannot reach even with unrestricted planar angles |
| --- | ---: | ---: | ---: | ---: |
| Front-left | 326 | 193 | 0 | 0 |
| Front-right | 326 | 199 | 2 | 1 |
| Rear-left | 363 | 232 | 103 | 32 |
| Rear-right | 326 | 217 | 129 | 49 |
| **Total** | **1,341** | **841** | **234** | **82** |

"Above floor" here is signed ideal capsule geometry, not the native contact
predicate or a new tolerance. The greatest nominal stance-goal height is
**24.175 mm**. A proposed alternative uses a supplied floor height and measured
torso height, preserving each nominal leg direction and explicitly projecting
link reach and the existing hip/knee limits. All **1,600** proposed targets stay
joint-bounded; **279** require link-reach projection, including the **234**
scheduled-support cases above. There are no joint-limit projections on these
particular inputs. The residuals remain visible; geometry does not promise
contact, support force, a new body pose or successful walking.

Two other observations prevent treating height correction as a complete fix:

- The greatest measured knee lag behind its preceding reference is
  **0.45885 rad (26.3 degrees)**: rear-left at trace 397 measures **0.39115 rad**
  after a **0.85000 rad** reference. None of the 3,200 outgoing velocity requests
  is flagged velocity-saturated. This does not establish unused force capacity
  or authorize higher gains or motor caps.
- Rear-right's **35.427 mm** backward event at traces 255–268 decomposes into
  **17.675 mm** backward torso translation, **16.938 mm** backward torso rotation
  at initial joint angles, **0.672 mm** backward joint contribution at the final
  torso pose, and **0.141 mm** residual. This is an explicitly ordered geometric
  accounting, not causal isolation. Front-right's later backstep instead has a
  larger joint contribution, so one explanation must not be applied to all
  failures. These positions are distal-body origins, not measured contact-point
  slip. The first short front-left flight also lands while its knee is still
  bending: body movement offsets its geometric lift.

Seven of ten failed cycles begin outside the **emitted command's** swing phase.
The diagnosis separately retains the original closure's input-memory phase;
some labels differ by one step because memory advances before target generation.
The original cycle count, criterion and negative interpretation do not change.

Next development direction: **an explicitly plane-referenced, joint-bounded
support successor**, preserving the existing reference transition and all
physical limits. The finite implementation requirements are:

1. Bind the supplied plane to the actual construction and native coordinate
   frame. The geometry precheck uses this fixture's authored `y=0` floor;
   production policy must not silently assume every world's origin is its
   floor. A frame-bound runtime plane contract is not implemented yet.
2. Preserve neutral startup, bounded goal composition, reference slew, old
   policy outputs and explicit unreachable residuals. Do not solve geometric
   unreachability by extending limbs, increasing joint limits or asserting
   that every leg is in contact. This is kinematic support geometry, not SDK2
   force-aware recovery.
3. Integrate the distinct policy through the shared route and applicable
   safety checks, then ask one fresh bounded physical question. Retain the
   same prefix, standing, seed class, horizon and evaluator; the alternative
   trajectory and whether body motion settles remain unobserved.

Four checks pass in **2.560 s** under
`SporeSpore_Evidence/development-v33-support-tracking-audit-d74e3108ce924cd9adddff9d514840b1`;
`stage.json` is
`sha256:ff9239c7594b2a73fb479536b31bbf391b80e1be97a94b0d00c5bf3ee3cffcbe`.
The diagnosis digest is
`sha256:39965a4ebdf96e240a9b66a9e087c2b79531a35d06fef2d280796f6a17aa02a0`.
The first audit's exact-zero full-extension assumption failed because inverse
cosine of a value one floating-point increment below one gives a tiny nonzero
angle. Its logs, test, analyzer, diagnosis and unchanged post-failure source
snapshot are preserved under
`SporeSpore_Evidence/development-v33-support-tracking-audit-c1094cb037874efb9e7e35d1da0d6911`.
The corrected check verifies the cosine boundary and geometric residual; only
its test-source binding changes in the diagnosis, not the proposal, physical
measurements, evaluator or interpretation. No native world/read/step, runtime
build, acceptance or score change occurred. R173 remains exact; SDK1/full stay
**14/20, 14/25**.

## V33 closure: bounded references, placement still negative

Historical physical closure; the subsequent diagnosis and selected development
direction are above. The consumed physical record remains unchanged.

[The immutable V33 closure](../sdk/development/recovery_attempts/4e5cacbc49e64ceab61fff2762217804.json)
records fresh attempt `4e5cacbc49e64ceab61fff2762217804` from clean, pushed
source `320668509058bfadcb31d66b4e83d67fbb783202`. All **112 safety checks**
passed before one seed-40200 SingleKick world. The child exited successfully,
with empty stderr and passing engine health; independent replay reproduced all
**1,258 transitions** and **400 resumed-walking commands**. No baseline was
cached or omitted from a paired claim: this is explicitly non-comparative
development, not complete official-route or recovery acceptance evidence.

The unchanged V20/stance-V7 standing path completes at solver step **858**.
V33 walking occupies steps **859–1,258** within the existing bounded cutoff:

| Measured during resumed walking | Result and meaning |
| --- | --- |
| Forward travel | **10.15 cm**; displacement alone does not establish valid walking. |
| Sideways displacement | **6.53 mm** in absolute value. |
| Maximum body tilt / heading change | **0.12172 / 0.11009 rad** (about **6.97 / 6.31 degrees**). |
| Torso contact with the ground | **0 samples**. |
| Counted foot cycles | **15**, of which **10** fail the unchanged forward-placement criterion. |
| Final foot support | Front-left, front-right and rear-right contact; rear-left absent for the last **5 samples**. |

The two false walking conditions remain `every_limb_forward_relocation` and
`terminal_four_contact_recovery`. Each foot has two counted contact cycles,
but no gait clock advances a full 360 increments from its initial 90; do not
describe these as two complete scheduled gait cycles. Native controller memory
records no recontact timeout. The diagnostic cutoff is not behavioral success.

[Four closure tests](../tests/test_development_v33_recovery_checkpoint.py) pass
in **38.816 s** including stage overhead. They reconstruct this run's own
standing commands, all **3,200** walking joint references and all **15** measured
foot cycles; verify the complete original population/replay and frozen source;
and refuse authority promotion or alteration of historical records. All
references remain within existing joint limits, with neutral startup and a
strict serialized memory chain. **259** commands require rate limiting and
**25** of the 1,600 nominal support proposals require joint-bound projection.
The largest remaining nominal plane error is **20.827 mm**, not measured foot
clearance or an established cause of contact loss. Independent native replay
is exact; decimal-data arithmetic checks use the same pre-world **1e-14 rad**
roundoff allowance already present in the frozen native component test, not a
new behavioral tolerance.

Evidence remains in
`<evidence-root>/development-recovery-smoke-4e5cacbc49e64ceab61fff2762217804`:
**63 files, 1,059,969,112 bytes**, inventory digest
`sha256:ac13b7bc8fd76049d52900e354cbf0946cab3651d43eacecda44caf94ccb5ca4`.
The report is **283,560,314 bytes** with digest
`sha256:5377605e4bb8ff4a516bfeb61331bb9edc9b840df70fc778b6ec8006e7893d68`.
The closure itself is
`sha256:42aa3ca80ec16a8c8f7fae1a592d64375cc0e7c163ee236973c8ea2d08a52651`.
The separate zero-world audit is retained under
`SporeSpore_Evidence/development-v33-closure-audit-1e9425d6f66443cd82655c3365b65e2d`;
its `stage.json` digest is
`sha256:e1f7813a215925f676c73d006d91d5f3e4cf195af5d05b6a1934fc65f7442e04`.
No audit output was appended to the immutable physical population.

The measured invocation took **25 min 31 s**: safety checks **10 min 4 s**,
child execution **9 min 28 s**, independent replay **3 min 47 s**, and roughly
**2 min 13 s** remaining orchestration/publication overhead. These are local
observations, not a guaranteed next-candidate turnaround or physics-only cost.

Next question: **why do placements fail despite bounded references?** Seven
of the ten failed foot cycles start outside scheduled swing; three start
inside it. Inspect command-versus-measured-pose tracking and native contact
transitions on this retained trajectory before selecting a distinct successor.
Do not infer causation from timing, transfer V32's geometric decomposition to
V33, retune the measured threshold, repeat this consumed identity or extend
this completed run. No next physical candidate is selected. R173 and all old
records remain byte-exact; SDK1/full remain **14/20, 14/25**.

## V33 bounded-support controller and connected route

Historical prospective integration boundary, preceding the physical closure
above; its next-test wording is preserved as that boundary's plan.

[The native component](../sdk/development/recovery_bounded_support_component_v1.json),
[adapter integration](../sdk/development/recovery_bounded_support_walking_adapter_integration_v1.json)
and [connected route](../sdk/development/recovery_bounded_support_route_integration_v1.json)
separate compiled-command proof, real-interface proof and still-unobserved
physical behavior. No world or solver step ran during these integrations.

The new walking policy uses all four nominal leg directions to calculate a
horizontal support arrangement for the measured body orientation. It explicitly
accounts for the historical walking observation's differently oriented axes.
Unlike the rejected proposal, knee/hip goals stay within existing limits, and
the receipt retains any remaining nominal foot-plane error. Swing uses the
remaining available knee range. A separate serialized reference starts at
neutral and moves toward those goals no faster than the existing motor-speed
limits permit over the measured sample interval. Changing gait membership does
not replace the geometric leg population, and abrupt goal changes do not bypass
the reference transition. This is pose accommodation, not force estimation,
torso-force control, a contact detector or proof of a stable support plane.

Verification is finite and reproducible:

- All **298 core tests** pass, including seven new tests. The optimized DLL is
  `sha256:952fe825ea8007c425d6c48018a050ee86ece69c90c371cb09fe29ec66bc5b29`.
- Four exported-interface checks pass: **800 exact legacy output matches**,
  six unchanged recovery fixtures, 400 consecutive V33 retained-input probes,
  source binding and five refusal cases. The 3,200 new commands are bounded;
  539 require reference rate limiting. Across all four leg proposals per input,
  38 require support-joint projection; largest remaining nominal plane residual
  is **12.627 mm**. These inputs are V32's observed trajectory, not V33 physics.
- Five adapter checks pass in **62.660 s**: actual compiled session, 200 commands,
  real motor-parameter application on eight detached hinge containers, ledger,
  cold native replay and ten corruptions. Receipt-format mistakes were caught
  at the adapter and ledger boundaries; explicit new-policy selection now uses
  one adapter schema constant. Rehashed crossed formats still refuse.
- **19 focused route checks** pass: 49 synthetic worker transitions with five
  cold-reader refusals, 450 startup commands, 100 retained entry commands with
  eleven cold-reader refusals, and actual launcher selection. Both paired and
  single-child declarations select the exact **112-check** gate: prior 108
  applicable checks, parameterized for V33, plus four native-component checks.

Two old test assumptions were corrected only for the new policy: a supporting
knee need not target zero, and even an amplitude-one first request now begins
with a neutral reference. Failed checks, source snapshots and all old-policy
assertions are retained. The old 44-test official-source suite remains at its
three historical failures and one historical error; the adapter differential
adds none and does not call that old suite green.

The final binding inspection verifies all 220 listed source/evidence bindings
across the three records. Its receipt is retained at
`SporeSpore_Evidence/development-v33-integration-audit-d72584bf7774448d9238f39381f015d1/audit.json`,
digest `sha256:a009f833cf0300de8c25848c03b279738165318f343190027e70498ad6974f10`.

The separate [integrated candidate](../sdk/development/recovery_candidates/v33-bounded-support-integrated-v1.json)
uses V20 recovery, stance V7 and the original BW5R-B prefix. Preserve initial
gait clocks 90, 72-command amplitude ramp, cap 0.5994550408719347, native contacts,
all limits/evaluators and the 986-step tail / 1,338-step child maximum. The
component-only profile remains non-runnable. Next clean pushed freeze and the
complete gate, then one fresh non-comparative seed-40200 SingleKick asking
whether the new references produce supported foot relocation within that same
horizon. Do not reuse a baseline or consumed identity, extend the horizon,
reinterpret V32, infer superiority, or promote development evidence into SDK1
support. R173 is unchanged; SDK1/full remain **14/20, 14/25**.

## V32 placement diagnosis: support loss and body motion

[The retained diagnosis](../sdk/development/recovery_swing_end_placement_diagnosis_v1.json)
binds the unchanged V32 closure/report and its three analysis sources. It
reconstructs 1,600 precommand body samples, all 13 counted foot cycles and all
1,600 knee requests. Frame-conversion error is below `2.06e-7`; maximum knee
formula error is `4.72e-16` rad. No new model, native read, world or solver step
is involved; the original negative evaluation remains exact.

Six of seven failed foot movements start while the leg is scheduled to
support the body, not swing. For rear-right's largest backward event, walking
249–267, the following explicit accounting sums to the measured displacement:

| Forward foot movement component | Distance |
| --- | ---: |
| Torso translation | -16.71 mm |
| Torso rotation, holding the initial joint angles | -35.26 mm |
| Joint-angle change, holding the final torso pose | -7.16 mm |
| Measured-minus-ideal constraint residual | -1.13 mm |
| Total measured movement | -60.26 mm |

This algebraic order is declared, not a causal experiment or a percentage of
fault assigned to a controller. For the first short front-left event, 28–34,
the knee continues bending and its joint contribution raises the nominal foot
surface by 0.80 mm. Torso movement lowers it by 1.63 mm; the measured net
clearance change is -0.53 mm. Peak nominal clearance is less than 1 mm.
Five knee-target jumps caused by the contact-dependent clearance term are
verified, but those jumps alone do not establish why a foot lands.

An analytic lower bound also relaxes all planar joint angles while holding
each measured torso pose fixed. During some stance losses even that ideal
fully extended leg cannot reach floor height. For example, front-left's
162–253 gap includes 72 such samples, with a maximum reach shortfall of
32.12 mm. This is a fixed-pose geometric statement, not dynamic impossibility,
a new contact predicate or a prediction of another controller's result.

The next finite question is stance support/body motion during resumed walking.
A longer wait cannot guarantee floor reach, and a knee-only smoothing change
does not address most failed events. No successor controller or physical
attempt is selected by this diagnosis. R173, thresholds and readiness stay exact.

Four cold retained-data tests pass in **2.092 s**, including whole-record
equality, all-cycle accounting, analytic reach bounds and source-drift refusal:
`SporeSpore_Evidence/development-v32-placement-diagnosis-27e1f333fe154052b8de41ab839407b4`.
The stderr digest is
`sha256:960e5c1cf832cebaf9dcf47c0e56779247fe6b639e9019fad28192d0d78d3935`.
The earlier four-test run remains retained under
`development-v32-placement-diagnosis-79c7507f86934d2e8eb5915e966f1883`.

## Stance-plane proposal feasibility: not a runnable controller

[The complete geometric proposal](../sdk/development/recovery_stance_plane_feasibility_v1.json)
preserves each scheduled stance leg's requested direction, shortens the legs
to a common horizontal endpoint plane, and computes the highest corresponding
torso height. It uses the retained native anatomical quaternion, not the
walking request's differently oriented basis. All 400 V32 inputs and 1,357
proposed stance targets are retained, with frozen original joint limits.

The ideal endpoint calculation closes to `1.67e-16 m`, but **15 knee requests
exceed the unchanged 1.10-rad limit**, reaching **1.2210827432409743 rad**.
Violations occur at walking commands 227–239 and 317–318. Hip requests remain
within the original +/-0.72-rad limit. The first zero-amplitude input also
produces nonzero stance targets. Therefore the unclipped proposal is rejected
as a ready-to-run controller. It has no startup/phase-transition rule, does not
preserve world foot positions or establish body-force control, and predicts
no alternative physical trajectory. Joint limits are not widened; silently
clipping the targets would not prove a shared support plane.

Next formulate joint-bounded support targets with explicit startup and phase
transitions, then verify the actual compiled interface before a fresh physical
candidate. No new controller is registered or physical attempt authorized here.
This is bounded walking development, not force-aware SDK2 recovery.

Four tests pass in **2.071 s**: exact complete-record reproduction, original-limit
rejection, zero-amplitude startup exposure, independent endpoint geometry,
yaw invariance and invalid-input refusals. Evidence is retained under
`SporeSpore_Evidence/development-stance-plane-feasibility-ab8677ab46104958b2ec90ff004a8cf2`;
stderr digest
`sha256:99476f835db584c2c0b7ced7f4be3fe84b899e79e94bf088103d21f2f50ecfe3`.
No new native read, model, world, solver step, evaluation or support change.

## V32 closure: swing-end holds work, walking still negative

[Attempt 987a8848999d457a820c078eb9273dbb](../sdk/development/recovery_attempts/987a8848999d457a820c078eb9273dbb.json)
ran from clean pushed source `10e6310b678d0aadaeb1bb64b1aae5d113c4f332`.
All **108** safety checks passed, then one fresh seed-40200 kicked child took
**1,258** solver steps. The child exited cleanly; independent replay verifies
all 1,258 transitions, 467 canonical observations, 119 entry observations,
430 native contact steps and 400 new-policy walking commands. The original
baseline was not cached or reused, and no comparison/acceptance authority is
created. The closure preserves 61 files totaling **1,052,203,673 bytes**, with
inventory digest `sha256:354866e384321894d0f4a553e701475fdda799d5ddfcda16158e4d6938822585`.
The 281,340,120-byte report digest is
`sha256:f85572e993169c913ecd979bc27fc46d377bc835b5db143ec1becb82f41d6830`.

Standing still completes at global step **858**. The cold audit independently
reconstructs this run's 1,864 retained stance motor commands and verifies the
unchanged 60-sample final stable stance. Walking runs from 859 through 1258,
with initial clocks 90, the same 72-step ramp/cap and strict consecutive memory.
The prefix remains BW5R-B; resumed walking explicitly uses the new policy.
All 1,600 knee requests fit the unchanged joint bound without position saturation.

The selected mechanism is physically exercised: front-left's recontact guard
holds at local phase **72** for walking commands **76–146** (71 samples), then
its contact transition completes without timeout. Rear-right holds at 228–229
and front-right at 318–373, also at phase 72. All actual native timeout counters
remain zero throughout. This is direct retained mechanism evidence, not a
claim that waiting guarantees touchdown or solves early stance-foot loss.

| Descriptive observation | V31 | V32 |
| --- | ---: | ---: |
| Resumed-walking samples | 400 | 400 |
| Forward advance | 5.79 cm | 5.47 cm |
| Absolute sideways drift | 0.175 cm | 1.129 cm |
| Maximum torso tilt | 0.21142 rad | 0.12478 rad |
| Final heading drift | 0.15142 rad | 0.19365 rad |
| Front-left long contact gap | 251 samples | 103 samples |
| Actual native gate timeouts | 1 | 0 |
| Counted foot cycles failing 1.2 cm forward placement | 15 of 18 | 7 of 13 |
| Feet missing support at cutoff | rear-left, front-right | rear-left, front-right |

These are two finite development trajectories, not a superiority test. V32's
forward advance is **0.054691217740539644 m**, lateral drift
**0.01129419696802314 m**, maximum tilt **0.12478447678633481 rad**, and heading
drift **0.19364722231554107 rad**. Torso contact count is zero. The unchanged
walking result remains negative on `every_limb_forward_relocation` and
`terminal_four_contact_recovery`. Each foot now satisfies the two-contact-cycle
counter, but that counter is not proof of clean repeated gait: final RL/FL/RR/FR
clocks are 380/380/380/369, only 290/290/290/279 increments after start 90.
**No foot completes a full 360-increment gait cycle.**

The cold audit reconstructs every counted lift/touchdown and its displacement.
Front-left's first short 28–34 event advances only 5.95 mm; later 41–144 and
162–253 events pass placement, while 278–284 advances only 5.27 mm. Rear-right
has three backward events, including 249–267 at **−6.03 cm**. Rear-left has one
slightly backward event. At cutoff, rear-left has lacked contact for 49 samples
and front-right for 18. These are specific remaining failures, not a basis to
censor inconvenient cycles or lower the placement requirement.

[Four cold closure tests](../tests/test_development_v32_recovery_checkpoint.py)
pass in 34.1544864 seconds. Retained logs:
`SporeSpore_Evidence/development-v32-cold-closure-910a38db30bb4a18a4019c228fb2b090`,
stderr digest `sha256:099b54f398ccb30d10f60b2fdb3cf0ed2bc6838a5ab21a43a6287ca2119a9492`.
They reproduce the complete original closure, measured standing commands,
phase-72 holds, all 13 counted cycles, original negatives and promotion refusals.
No cold-audit world or solver step ran; earlier records and R173 remain exact.

The full invocation took **1,572.640 seconds (26.21 minutes)**: safety gate
613.201 s, physical child 592.508 s, independent replay 236.328 s, and remaining
launch/publication/audit overhead about 130.603 s. This is an observed loop
time, not a controlled speedup claim against earlier runs.

**Next finite work:** use the retained joint commands, body orientation, distal
foot geometry and contact timing to explain the fragmented initial swing,
backward/insufficient placement and rear-left/front-right stance losses. Keep
the demonstrated recontact mechanism distinct from those failures. No new
candidate, parameter sweep, longer cutoff or additional world is selected at
this closure. SDK1/full remain **14/20, 14/25**; no force-aware recovery,
held-out success, formal comparison or release authority is claimed.

## V32 connected development route

[The prospective integration record](../sdk/development/recovery_swing_end_route_integration_v1.json)
binds 30 current source/declaration/test files and 73 retained files totaling
60,077,571 bytes. The distinct runnable profile is
`v32-swing-end-recontact-integrated-v1`; the original component profile remains
non-runnable. It reuses the qualified native component DLL without rebuilding.

Only fresh resumed walking selects the swing-end policy. Its commands and
ledger explicitly identify the new policy and canonical `stance` owner;
initial walking remains BW5R-B, initial standing remains V6 and post-kick
standing remains V20/stance V7. Initial clocks 90, first-full-amplitude step 73,
amplitude cap 0.5994550408719347, contact sources, motor limits and the 986-step
post-interaction/1,338-step total limits remain fixed. No memory exception,
threshold change or reinterpretation of an old result is introduced.

Twenty-eight focused tests pass: startup 4, retained entry 6, connected route 4,
schedule/finalizer 4, launcher profile 5 and adapter/ledger/reader 5. They execute
450 synthetic startup commands, independently replay 100 retained entry
commands and 200 adapter commands, and replay all 49 synthetic route events in
a fresh process. Wrong policy/owner, malformed selections and altered events
refuse. All non-resume event bytes remain identical with and without the new
walking selection. Identical synthetic measurements yield exactly identical
diagnostic results under the two explicitly selected policy identities.

Two development-test failures are retained: an old coverage-test profile list
omitted the new successor, and the new route fixture initially omitted the arm
storage used by the real kick-transition hook. Only those test assumptions
were repaired; numerical criteria and the production memory-clear hook were
not weakened. The old 44-test source suite still has the same three failures
and one error, with no new failures; it is not claimed green. The edited
evaluator's line endings were normalized after focused checks; the complete
gate will verify the final clean source. No native world or solver step ran.

Next, from a clean pushed prospective freeze, run the complete **108-check**
applicable development safety gate (99 existing plus nine V32-specific checks),
then **one fresh seed-40200 SingleKick** only if all pass. Observe whether the
new checkpoint really holds at swing end, whether that foot lands, and what
the unchanged walking diagnostics say. No baseline reuse or cutoff extension.
Early stance-foot loss and the bounded contact timeout remain possible; this
is not force-aware recovery, held-out behavior, equivalence or SDK support.
R173 and support/release authorities stay unchanged: SDK1/full **14/20, 14/25**.

## V32 adapter and reader integration boundary

[The integration receipt](../sdk/development/recovery_swing_end_walking_adapter_integration_v1.json)
binds eight source/test/declaration files and all 27 retained files (62,967,594
bytes), including the first four-test pass and the later five-test pass.
It reuses the exact V32 DLL; no native rebuild or world is involved.

The actual recovery facade can now select the new policy for a fresh resumed
session. Unknown policies, prefix/continuation selection and the ordinary
default-extension path refuse it. The returned native profile must match
BW5R-B in every field except the declared schema, policy ID and recontact mode.
The old default remains BW5R-B; no public policy or release contract changes.

The production handoff and motor ledger use distinct development schemas and
bind the policy declaration's raw digest. That digest is explicitly separate
from the descriptor-specific native profile digest. Existing host impulse caps,
binary32 projection rules, motor writes and all command checks remain intact.
New ledger ownership uses the canonical `stance` enum and the explicit new
walking policy ID; it does not pretend to be `walking_bw5r_b`.

Five focused tests pass in 78.9952969 seconds. They include 30 producer checks,
real adapter/motor-application/ledger execution on detached hinge parameter
containers, 200 consecutive native policy commands and a fresh-process reader
that reproduces all 200 outputs and rejects ten corruptions. The synthetic
sequence demonstrates a front-left clock hold at 162 (local swing phase 72).
It uses absent-contact fixtures and the old base amplitude schedule, not the
eventual V32 candidate schedule or a physical trajectory. Empty body-state
placeholders are fixture metadata, not observations. There is no scene
insertion, body construction, physical-world read or solver step.

The broad legacy 44-test source audit is **not green**: three old source-location
assertions and one old freeze-binding check fail both before and after this
change. A read-only projection of all four changed files used by that suite
from `7317262bc8d5b4963585578bc7f75a8abdba0aa5` reproduces the same failure IDs.
The differential passes with no new failures; it does not repair, waive or
promote the old audit into current qualification.

There are three remaining blockers before physics:

1. A distinct integrated candidate/schedule and new entry/start bindings must
   preserve clocks 90, the 72-step amplitude ramp and cap, V20 recovery, stance
   V7, contacts and the existing finite horizon. The old component profile
   remains deliberately non-runnable and all earlier contracts stay immutable.
2. Wire its explicit policy through the actual worker, development state
   machine and whole-report reader. The state machine's old BW5R-B owner
   expectations must not be silently relabeled. Test wrong owner/segment and
   unchanged prefix/recovery behavior through those real interfaces.
3. Pass the complete applicable safety gate, freeze clean and pushed, then run
   one fresh seed-40200 SingleKick diagnostic. No baseline reuse or extended
   cutoff. Standing or walking failure remains valid development evidence.

Early unintended contact losses, inability to land and the original bounded
timeout remain possible. This integration is neither a route ghost nor proof
of walking, force-aware recovery, superiority, equivalence or SDK support.
R173 and the support/release authorities are unchanged.

## V32 native component: swing-end recontact, not yet route-integrated

[The V32 component receipt](../sdk/development/recovery_swing_end_recontact_component_v1.json)
records a new native scheduling policy and an exported-interface check, **not a
physical observation**. [The retained V31 diagnosis](../sdk/conformance/development_recovery_v31_recontact_diagnosis.py)
separates joint tracking, body geometry and command sequencing. It uses V31's
original report and the scheduler source at its frozen commit; the old result
and its thresholds remain untouched.

At trace-local 200, front-left's knee is already straight at its zero target,
and hip measurement 0.126489 rad is near target 0.123617 rad. The foot is still
**48.7896 mm above the nominal floor**. Relative to startup, the vertical
decomposition is torso translation -3.7566 mm, orientation at initial joint
angles +45.5062 mm, joint changes at the current pose +7.2918 mm, and ideal-hinge
residual change -0.1078 mm. These sum to the change from the initial bottom
-0.1439 mm. A relaxed all-planar-angle reach calculation at the fixed measured
torso still leaves a **39.7705 mm** gap. This does not forbid recovery through
body motion or compliance; it shows that simple knee-tracking lag is not a
sufficient explanation of the late retained gap. No dynamics model is run.

The source and actual memory expose a sequencing risk:

| Recorded walking command | Front-left state | Following rear-right state |
| ---: | --- | --- |
| 75 | Reaches nominal swing end, phase 72; no measured contact | Still in stance |
| 91 | Phase 88, still no measured contact | Starts next swing, phase 0 |
| 148 | Only now begins recontact wait at phase 144 | Already at swing phase 55 |

The existing 12-step phase-skew control later holds rear-right at phase **66**
for 110 commands, 159–268. Its contact input switches **37 times**, and the
unchanged loaded-swing assist switches the knee target between
**0.2226407971086264** and **0.4624228134574003 rad**. The difference is exactly
the existing `0.4 * selected_amplitude` term. These are source-reproduced command
relationships, not causal proof that removing the switches would fix walking.

The distinct development policy
`sporespore_balanced_wave_recovery_swing_end_recontact_v1` changes only its
recontact checkpoint to the canonical scheduler's **existing swing end**.
Its profile names `scheduled_swing_end_recontact_v1`; it does not introduce a
fitted phase number. All legacy policies omit that field and retain phase 144.
Selected SDK policy BW5R-B is unchanged. The new mode preserves the three-sample
consecutive contact dwell, 120-step timeout and bounded escape, release gate,
12-step skew, joint targets, loaded-contact assist, steering, motor limits and
observation/refusal rules. This is binary-contact sequencing, not force-aware
whole-body recovery.

Before timeout, **72 + 12 = 84 < 90** keeps the following foot short of its next
scheduled swing while the first foot waits at swing end. Native tests verify
that property through all 120 wait steps, the original timeout escape, contact
dwell reset, missing-input refusal, and unchanged clocked / unaffected-phase
outputs. It cannot retroactively repair V31's early 28–34 insufficient cycle,
prevent every unintended stance contact loss, or guarantee that contact returns.
Those remain physical questions, not reasons to weaken the evaluator.

The new DLL is independently retained under
`SporeSpore_Evidence/development-candidate-build-20006092f265429f9bca5bc611347763`;
SHA `1e7f091bd8ba93e0f85f426f9132100fb404e2ecfbe4e7e9331afccfb1582dbf`.
All **291 native core tests** pass. Build stages take 77.454 s for core tests,
0.375 s for fixture emission and 69.515 s for the adapter. These are compiler
stage timings, not an iteration or physics speedup. Old DLLs are not overwritten.

All four [exported-API and retained-data checks](../tests/test_development_v32_recontact_component.py)
pass in **5.306 s**, retained at
`SporeSpore_Evidence/development-v32-native-component-84715417cf5d4a589830a5d7e03024bd`.
They compare the old and new DLLs' **complete native output bytes on all 400
retained V31 inputs using the old policy**, and preserve all six V20 recovery
fixtures exactly. A separate post-exposure one-step probe through the actual
new DLL export holds front-left at clock 162 on command 76. That probe does not
predict a different trajectory or regrade V31. The component receipt's 69 file
bindings were checked; its SHA is
`3f2a04362d53d14e2ddec1b014a58000370c2bc6936afdbe82d84b91924fc6a7`.

The component profile uses a deliberately non-runnable schema: physical
selection rejects it with `DEVELOPMENT_CANDIDATE_PROFILE_SCHEMA`. Its DLL is
built, but **the recovery facade and independent recovery reader are not yet
integrated for the new policy**. Do not run it by merely changing that schema.
Next create a distinct prospective integrated profile, bind policy identity and
profile digest through the real facade, retained commands and independent
reader, and reuse this exact DLL. Keep prefix BW5R-B, recovery V20, V31's initial
phase 90, amplitude, native contacts, motor bounds and physical horizon. Run
complete affected-path interface controls and applicable smoke safety before
one fresh bounded child. No new world or support promotion occurred here;
R173 and every observed record remain exact. Current-source keys changed with
the new core: old qualification is not silently reused.

## V31 closure: front-left-first exercised, real recontact timeout

[V31's immutable closure](../sdk/development/recovery_attempts/72f7accb15c44d68a7ba817a61b3ac08.json)
retains one fresh seed-40200 kicked child from clean pushed source
`56d5ec64c87f261785405968cc598b8e966e0d27`. All **99 safety checks** pass.
The child exits zero, with empty stderr and passing engine health. Independent
replay passes **1,258 transitions**: 467 canonical observations, 119 entry
observations, one measured-prone initialization, 30 prefix commands, 400 resumed
commands and 430 native-contact inputs. All walking commands use contact gating
and exact consecutive memory equality, with no reset or transition exception.
Replay creates no world, reads no native physics and takes no solver steps.
This is a valid development negative, not walking success or acceptance.

The same-body recovery again completes standing at **858**: 232 stance samples,
73 stable overall, and the final 60 consecutively stable at 799–858. The cold
audit reconstructs all **1,864** handoff/dwell commands from V31's own measured
joints and unchanged rules. Walking spans 859–1258. Initial gait clocks are
**90** for all feet; front-left receives the first swing command and is the
first foot to lose support, at walking 28. The prefix still starts at 240.

Front-left's first counted swing, **28–34**, advances only **5.9454 mm**, below
the unchanged 12 mm minimum. Its next flight, **41–292**, advances 62.2275 mm
but has **251 consecutive native inputs with no raw contact**. The correctly
framed nominal capsule bottom is positive throughout that interval, ranging
from 0.2375 to **66.9972 mm** above the authored floor. The first six-step gap
also has zero raw contacts. These are retained geometry/contact observations,
not a contact-threshold adjustment or causal explanation.

At walking command **268**, front-left exhausts the existing 120-step recontact
wait: prior gait clock 234 and hold 120 become clock 235, hold zero and native
timeout count **1**. The original evaluator's `contact_gating_completed_without_timeout`
flag remains **true**, because that frozen summary checks a narrower condition;
the closure separately reports `actual_native_gate_timeout_total=1`. Preserve
both. The summary flag must not be used to claim zero native timeouts.

| Foot | Counted contact cycles | Minimum cycle advance (mm) | Open flight at cutoff | Actual gait increments since start |
| --- | ---: | ---: | --- | ---: |
| Rear left | 2 | -0.9874 | 395–400, 6 samples | 288 |
| Front left | 2 | 5.9454 | None | 277 |
| Rear right | 13 | -60.4016 | None | 286 |
| Front right | 1 | 17.0248 | 327–400, 74 samples | 286 |

**Fifteen of 18** counted cycles miss relocation: both rear-left, the first
front-left, and 12 rear-right cycles. Nine rear-right cycles begin while its
actual gait phase is held at **66**; these repeated contact interruptions are
not nine clean gait repetitions. The cold audit reconstructs every lift,
landing, projected displacement and actual phase. Final absolute clocks are
378/367/376/376 in policy order, but subtracting start 90 shows **no limb has
completed 360 gait increments**. The absolute evidence limit 1530 still has
the same 1440-increment span. Preserve all original generic horizon flags;
they do not establish a completed native gait cycle here.

The wall-clock amplitude reaches cap **0.5994550408719347** at local 73,
with 328 samples at cap. All **1,600 knee requests** are within the original
limits; none is position-saturated, and the maximum is 1.0991812630882631 rad.
Forward advance is **0.057889645867921 m**, absolute lateral drift
0.0017548201942294561 m, maximum tilt 0.21141690241135402 rad, minimum torso
height 0.38399213552474976 m and yaw drift 0.15141933906594043 rad. There is
no torso contact. The original three false receipts remain relocation,
two contact cycles per limb and terminal four-foot support. This result does
not support the startup-triangle hypothesis as a sufficient walking solution;
it neither establishes general inferiority nor licenses another phase sweep.

All **57 files / 1,052,463,319 bytes** are retained under
`SporeSpore_Evidence/development-recovery-smoke-72f7accb15c44d68a7ba817a61b3ac08`.
Inventory SHA: `a46c6a78689cbd91a7b25d6e1bfe2fdf4663529b261867cfcf7cfd9a4fd87276`.
Report SHA: `76bf505328df4147ed5002b73add3d811cd6a289f8cdd25e00bbfd77a5bf498d`.
Closure SHA: `638c375a87053ee104c53e7d4336d76d885267107a5406070c654c1978841b64`.
The closure binds 32 frozen rule sources. Whole invocation takes **1,839.100 s
(30.65 min)**: safety 669.054 s, native child 718.916 s, independent replay
288.344 s and other overhead 162.786 s. This is longer than V30's invocation;
no speedup is claimed. Diagnosis, implementation and cold audit are excluded.

All four [cold closure checks](../tests/test_development_v31_recovery_checkpoint.py)
pass in **43.823 s**, retained under
`SporeSpore_Evidence/development-v31-cold-closure-ce2595f814744c1999200b603d28916a`.
Cold stderr SHA: `3b393ab857da72a203217d1d6f90c63d20673164b8e0ffbe1176c46430167e35`.
They reproduce the complete population, standing, commands, raw gaps, cycles,
native timeout and original negatives; reject promotion; and preserve V30,
V29, V28, the failed preflight, V23's original invalid replay and separate
diagnostic, the runtime and R173 byte-for-byte.

Next use retained native body pose, joint tracking, command geometry and raw
contacts to diagnose **why front-left remains above the floor through its
recontact wait**, and the repeated rear-right interruptions. The first-foot
choice was exercised and did not solve walking; do not continue a timing or
amplitude search without a new mechanistic basis. No successor, longer cutoff,
old-attempt rerun or physical sweep is selected at this closure. R173 and
SDK1/full remain **14/20, 14/25**; force-aware recovery remains later scope.

## V31 prospective: front-left-first walking

[V31's profile](../sdk/development/recovery_candidates/v31-front-left-first-walking-v1.json)
changes only the initial walking phase relative to V30. The normal initializer
runs, then all four clocks receive offset **90 before the first command**.
This selects front-left through the unchanged order rear-left, front-left,
rear-right, front-right. Limb identities are not exchanged. The absolute
evidence-clock limit moves from 1440 to 1530 with its starting clock; its
relative span stays 1440, and the physical horizon does not grow.

The [read-only diagnosis](../sdk/conformance/development_recovery_v30_startup_diagnosis.py)
reconstructs V30's 1,600 native walking inputs. Front-right has no raw contact
for all 80 inputs at trace indices 34–113. Its nominal capsule bottom changes
from -0.0353 mm at 33 to +0.4650 mm at 34. At 34, relative to startup, the
vertical change decomposes into torso translation -0.4978 mm, orientation at
initial joint angles +0.9760 mm, joint motion at the measured torso +0.2249 mm,
and ideal-hinge residual change -0.1736 mm. This is a geometric decomposition,
not identification of the physical cause. A relaxed fixed-torso reach bound
omits compliance and subsequent body motion; it is not a controller impossibility
claim. Native recovery-body orientation is used, not the walking-frame quaternion.

At startup, the signed distance from measured center of mass to the closest
edge of the other three **actual raw contact points** is:

| Foot omitted for first swing | Static margin (mm) | Meaning at this instant |
| --- | ---: | --- |
| Rear left | -1.118717 | Center of mass is outside the remaining triangle |
| Front left | +1.625105 | Inside; largest of these four small margins |
| Rear right | -1.625105 | Outside |
| Front right | +1.118717 | Inside |

The center of mass is already moving: world velocity is approximately
(0.0189204, -0.0000566, -0.0166506) m/s. Static triangles therefore do **not**
prove dynamic viability. V31 selects the single largest-margin existing phase,
index 1 times 360/4 = 90, as a development hypothesis. There is no minimum-margin
threshold, online selection, phase sweep, causal conclusion or superiority claim.

The exact V20 recovery/stance DLL is reused without a build. Preserve V30's
contact gating from command one, 72-step wall-clock amplitude ramp, cap
0.5994550408719347, prefix, motor limits, model, native contacts, 986-step tail,
1338-step total cap, time limits and every evaluator. Independent replay keeps
exact consecutive memory equality: no mid-session reset or transition exception.
The new start and entry identities must be paired; crossed and missing selectors
are refused. This is not force-aware recovery or an SDK support expansion.

All **42 focused checks** pass: four retained-geometry/design controls, V31
startup/entry/schedule 4/6/4, V30 startup/entry 4/6, V29 startup/entry 4/6,
and four V30 cold closure checks. The real initializer supplies clocks 90,
front-left receives the first swing command, and both contact guards hold
during 450 synthetic commands. Results are retained under
`SporeSpore_Evidence/development-v31-integration-3af8ca019da64202a64a52879351b810`;
the design receipt is under `development-v31-integration-15b3771af39841ce8068a9b87fb23ee3`.
That earlier batch also retains a failed test-only integer-versus-JSON-float
dictionary comparison. Its actual initializer and all 450 commands succeeded;
the comparison now projects declared counts to integers without changing native
values or contracts. The original failure is neither deleted nor regraded.

Next run the complete **99-check applicable safety gate**, then one fresh
seed-40200 kicked child and independent replay from a clean pushed freeze.
Retain a complete negative if it occurs; standing failure gives no walking
coverage. No old attempt is rerun or extended. No V31 physical observation yet.
R173 and SDK1/full remain **14/20, 14/25**.

## V30 closure: contact guards exercised, walking still negative

[V30's immutable closure](../sdk/development/recovery_attempts/f31bc1e0355244b1866629edd7122d81.json)
retains one fresh seed-40200 kicked child from clean pushed source
`e61c0a1134bb855ff897b9fbf5a2174bea823fd9`. All **99 applicable safety checks**
pass. The native child exits zero with empty stderr and passing engine health.
Independent replay passes **1,258 transitions**: 467 canonical observations,
119 entry observations, one measured-prone initialization, 30 prefix and 400
resumed walking commands, and 430 native-contact inputs. All resumed commands
use contact gating and exact consecutive memory equality; **no transition
exception is selected**. Replay creates no world, reads no native physics
and takes no solver steps. This is a valid development observation, not
walking success, official route commissioning or acceptance authority.

The same recovery controller completes standing at **858**: 232 stance-dwell
samples, 73 stable samples overall and the final 60 consecutive stable samples
at 799–858. Cold reconstruction checks all **1,864** handoff/dwell commands
against V30's own measured joints and the unchanged ramp, damping and cap.
Walking spans 859–1258 in that same body, with no reset or force-aware recovery.

The selected mechanism is actually exercised. At walking command **56**, the
front-right recontact guard holds gait step 54 with zero satisfied dwell;
rear-left's release guard also starts its required dwell. All **400 commands**
are contact-gated. Terminal memory is below, in the policy's limb order:

| Foot | Final gait clock | Release holds | Recontact holds | Phase-alignment holds | Native gate timeouts |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rear left | 347 | 2 | 2 | 48 | 0 |
| Front left | 336 | 2 | 11 | 50 | 0 |
| Rear right | 345 | 2 | 2 | 50 | 0 |
| Front right | 336 | 2 | 61 | 0 | 0 |

The wall-clock amplitude ramp remains zero at local 1 and reaches its exact
selected cap **0.5994550408719347** at 73, with 328 samples at that cap.
All **1,600 knee requests** remain within the original limits, none is
position-saturated, and the largest requested bend is **1.0991812630882631 rad**.
The generic historical `full_amplitude_sample_count=0` still means unit
amplitude 1.0, not this profile's smaller cap; it is not rewritten.

Forward movement is **0.14915311594890523 m**, absolute lateral drift
0.0048042890245509895 m, maximum tilt 0.05004154296158737 rad, minimum torso
height 0.38558292388916016 m and yaw drift 0.030285927319832307 rad. Torso
contact count is zero. Two unchanged checks still fail:
`every_limb_forward_relocation` and `terminal_four_contact_recovery`.
Every counted cycle is retained below; movement is along the frozen evaluator's
axis using distal-body origins, not sole centers. The relocation minimum is
still **0.012 m**, with minimum airborne dwell **3 steps**. Unlike a clocked
gait, phase here comes from each limb's **actual retained command memory**,
not walking elapsed time.

| Foot | Lift | Landing | Forward movement (m) | Actual phase at lift | Relocation rule |
| --- | ---: | ---: | ---: | --- | --- |
| Rear left | 44 | 163 | 0.03444035855455385 | 43, swing | Pass |
| Rear left | 353 | 376 | 0.008090594243768803 | 300, stance | Fail |
| Front left | 159 | 169 | 0.020086683645259562 | 18, swing | Pass |
| Front left | 176 | 268 | 0.10202829904810784 | 35, swing | Pass |
| Front left | 279 | 296 | 0.010548254071853336 | 136, stance | Fail |
| Front left | 308 | 314 | 0.00440296170646981 | 154, stance | Fail |
| Rear right | 168 | 206 | 0.010191076702996682 | 297, stance | Fail |
| Rear right | 258 | 342 | 0.08329763094316522 | 27, swing | Pass |
| Front right | 34 | 114 | 0.0653552351886888 | 123, stance | Pass |
| Front right | 127 | 146 | -0.0033802683205539363 | 155, stance | Fail |
| Front right | 352 | 355 | 0.0058170146727280075 | 20, swing | Fail |

Six of 11 cycles miss relocation: five begin in commanded stance and one in
swing. At cutoff, front-right's flight remains open from 358 for 43 samples,
and rear-left's from 393 for eight. The other two feet have support. The
original two-contact-cycles counter passes with FL/FR/RL/RR **4/3/2/2**,
but no limb reaches 360 gait-clock increments. These interrupted contacts
must not be called two clean gait cycles or completed gait-horizon evidence.
Zero native timeouts are checked directly from memory, not inferred from the
original evaluator's more limited timeout-free flag.

All **57 files / 1,052,718,834 bytes** are retained at
`SporeSpore_Evidence/development-recovery-smoke-f31bc1e0355244b1866629edd7122d81`.
Inventory SHA: `8d714aae6feee01b14ce8063269e4077c564c9a01204a5022207c69d665a6f16`.
The 281,496,765-byte report SHA is
`284285483ed8242d1c7b13a27118862465f71fa8ddba6c2067d2374ffcdc9359`;
closure SHA is `3a2b29b37b2054ef0b9105d34591fb8da6084e8ac16e6b4d9dd0daaa7a78a3df`.
There are 29 frozen rule-source bindings. Whole invocation is
**1,478.456 s (24.64 min)**: safety 521.298 s, native child 589.595 s,
independent replay 235.766 s, and other workflow overhead 131.797 s.
Those timings exclude diagnosis, implementation, focused checks and closure;
neither a causal performance gain nor behavioral superiority is claimed.

All four [cold closure checks](../tests/test_development_v30_recovery_checkpoint.py)
pass in **39.092 s**, retained at
`SporeSpore_Evidence/development-v30-cold-closure-3ec662a491534ff5bd5f2e5862b94930`.
Cold stderr SHA: `841f7be1b7829e7756d5ed723f238c971dd03486641ab9d933f036bd442b6bea`.
They reproduce the complete population, replay, standing commands, amplitude,
real guard holds, every counted cycle and terminal negatives; reject promotion;
and preserve earlier closures, the original runtime and R173 byte-for-byte.

Next diagnose the **front-right stance lift at local 34**, before the first
recontact guard at 56, using retained raw contacts, measured joint tracking
and correctly framed geometry. The guard waits after a loss; it does not
prevent that earlier loss. Also retain and examine the later insufficient
cycles and fragmented front-right swing. This is a concrete earlier failure
boundary to investigate, not proof of its physical cause. No further timing
sweep, new candidate, old-attempt rerun, longer cutoff or physical successor
is selected at closure. R173 and SDK1/full remain **14/20, 14/25**.

## V30 prospective: contact-gated walking from command one

[V30's profile](../sdk/development/recovery_candidates/v30-contact-gated-walking-from-start-v1.json)
selects one change: use the **existing contact-gated gait from resumed command
one**, instead of clocked commands 1–360. It preserves V29's exact amplitude
cap **0.5994550408719347**, 72-step wall-clock ramp, V20 recovery/stance DLL
and commands, native contacts, normal zero-phase initializer, motor limits,
model, 986-step tail, 1338-step cap and every evaluator. The amplitude reaches
its selected cap at 73 regardless of gait holds. Prefix remains amplitude
one and seeded gait 240. No Rust change, rebuild, force-aware recovery,
threshold change, sweep or longer horizon is introduced.

The [entry contract](../sdk/development/recovery_contact_gated_walking_entry_contract_v1.json)
binds V29's immutable closure/report and the unchanged runtime/adapter. Its
retained-data diagnosis reproduces **45 raw-contact-free input samples** in
the four failed rear-foot stance intervals. Front-left's first scheduled
swing contains three real flights with **14 intervening raw-contact inputs**;
these are not merely differently labeled continuous flight. More specifically:

| V29 command | Foot | Prior gait checkpoint | Measured support | What clocked mode did |
| ---: | --- | ---: | --- | --- |
| 56 | Front right | Recontact phase 144 | Absent | Advanced the gait clock |
| 236 | Front left | Recontact phase 144 | Absent | Advanced the gait clock |

The existing contact gate checks prior memory, requires three consecutive
satisfied samples, holds at most 120 samples and limits phase lead to 12.
Release/recontact checkpoints remain 54/144. Starting the mode at 73 would
miss the first observed unsatisfied checkpoint. This identifies an unexercised
coordination guard, **not a proved cause of V29's gaps**. The guard does not
monitor every stance loss, and can itself delay progress or time out.

Policy-specific clarification: BW5R-B does **not** activate the later BW8U
release-gate apex overrides mentioned in V29's generic command-bound
explanation. Its same bound is nevertheless exact at ordinary loaded-swing
phase 36: `(0.82*1.75+0.4)*cap = 1.1 rad`. No inactive override is used as a
V30 mechanism or rationale; the historical contract and result remain exact.

The separately named [startup contract](../sdk/development/recovery_contact_gated_walking_start_contract_v1.json)
calls the same normal initializer and pairs it with the always-contact-gated
phase family. V30 does not select a mode-transition exception. The actual
adapter must preserve consecutive memory exactly, and the independent reader
must reject a break. This reuses the old phase-mode/retention family only,
not its different amplitude duration.

Forty focused checks pass: new design/entry/start/schedule **4/6/4/4**, plus
V29 entry/start/transition/prospective/cold-closure **6/4/4/4/4**. The real
compiled interface executes 450 zero-world startup commands and verifies
both blocked gates at command 56 on explicitly synthetic contacts. A separate
100-command retained probe crosses a gate; a fresh reader accepts the exact
sequence and refuses all 11 corruptions. This is command/transport evidence,
not native physical success. The first startup check caught non-string
selection rejection emitting GDScript errors; the type guard was corrected.
That failed check and all outputs remain retained, not overwritten.
Focused roots are `development-v30-integration-ff22676122364b928bd32a5dfd449178`
and `development-v30-integration-0b25779b08d04029bc0964e1025a127c` under the
durable evidence root. The cold V29 stderr digest is
`390ba0edcf22f6588dd258aa6d5e801b65cbc1b532acf72b7c66cff6416a18c7`.

Next: clean pushed freeze, the complete **99-check applicable safety gate**,
then one fresh seed-40200 kicked child. The eight mode-switch-only checks are
not applicable to V30's no-switch path; they have separately passed against
V29. The launcher already selects those checks conditionally; its gate has
not been weakened. A valid physical negative stays useful; no old attempt is
rerun, baseline cached, native outcome predicted or comparative authority
claimed. No V30 physics has run at this boundary. R173 and SDK1/full remain
**14/20, 14/25**.

## V29 closure: bounded knee requests, two walking negatives

[V29's immutable closure](../sdk/development/recovery_attempts/66b2e79c43d3401285f7cdba0f607990.json)
records one fresh seed-40200 kicked child from clean pushed source
`d24d394ba0eec042337ad3702a712b54fd4d9fd4`. All **107 safety checks** pass.
The native child exits zero with empty stderr and passing engine health.
Independent replay passes **1,258 transitions**: 467 canonical observations,
119 entry observations, one measured-prone initialization, 30 prefix and 400
resumed walking commands, 430 native-contact inputs, zero-phase startup and
one actual local-361 adapter-mode switch. Replay builds no world and takes no
native physics reads or solver steps. Status is
`closed_consumed_valid_development_observation`, not walking success or
official route/acceptance authority.

The unchanged recovery/stance policy again completes standing at **858**,
after 232 dwell samples and the final 60 consecutive stable samples at
799–858. Cold reconstruction checks all 1,864 handoff/dwell commands against
V29's measured inputs, the original ramp, damping and cap. The same body then
walks through 1258, without transform/velocity reset or force-aware recovery.

The new command bound is actually exercised: **all 1,600 knee commands are
within the existing position limits**, none is position-saturated, and the
maximum requested bend is exactly **1.1 rad**. Amplitude is zero at local 1,
reaches **0.5994550408719347** at 73, and stays there for 328 samples. Every
request is checked against that schedule. The historical generic closure
fields `full_amplitude_sample_count=0` and
`first_full_amplitude_global_step=null` count **unit amplitude (1.0)**, not
this profile's selected maximum; they are left unchanged rather than relabeled.
V28's 148 saturated requests remain an observation from a distinct attempt,
not a matched causal comparison or evidence that saturation caused its gaps.

Over 400 resumed-walking steps, forward advance is **0.18202034222863173 m**,
absolute lateral drift 0.0009707247369661332 m, maximum tilt
0.11340671227783802 rad, minimum torso height 0.3850322365760803 m and yaw
drift 0.010317733249084108 rad. Torso contact count is zero. Two original
checks fail: `every_limb_forward_relocation` and
`terminal_four_contact_recovery`. All 13 counted cycles remain included below.
Steps are local to walking; movement uses retained distal-body origins and the
frozen evaluator's axis, not sole centers. The relocation minimum remains
**0.012 m** and minimum airborne dwell remains **3 steps**.

| Foot | Lift | Landing | Forward movement (m) | Commanded phase at lift | Original relocation rule |
| --- | ---: | ---: | ---: | --- | --- |
| Rear left | 44 | 81 | 0.06821726822965099 | Swing | Pass |
| Rear left | 93 | 111 | -0.04677319726134413 | Stance | Fail |
| Rear left | 286 | 293 | 0.0017295576434348536 | Stance | Fail |
| Rear left | 328 | 343 | 0.003400743798754928 | Stance | Fail |
| Front left | 111 | 123 | 0.02054411131541567 | Swing | Pass |
| Front left | 127 | 146 | 0.05276434834112287 | Swing | Pass |
| Front left | 156 | 163 | 0.013958964047420253 | Swing | Pass |
| Front left | 180 | 262 | 0.038178713770673056 | Stance | Pass |
| Rear right | 98 | 103 | -0.0013244415564503953 | Stance | Fail |
| Rear right | 120 | 186 | 0.021693217240560614 | Stance | Pass |
| Rear right | 207 | 283 | 0.09656083191381004 | Swing | Pass |
| Front right | 34 | 96 | 0.04831712973770563 | Stance | Pass |
| Front right | 292 | 393 | 0.15455107958559589 | Swing | Pass |

All four insufficient cycles start in commanded stance (phases 92, 285, 327,
277). Front-right's last flight closes at 393. Rear-left's 378–400 flight
remains open for 23 samples; the other three feet have support at cutoff.
The original two-contact-cycles counter passes with FL/FR/RL/RR counts
**4/2/4/3**, but that is not proof of two clean gait cycles: front-left alone
has three counted flights within its first scheduled swing. Neither the extra
contact interruptions nor the shorter horizon are silently promoted into
better locomotion. This closure does not establish raw-contact absence or a
cause for V29's new gaps merely from support flags.

All **61 files / 1,052,717,952 bytes** remain in
`SporeSpore_Evidence/development-recovery-smoke-66b2e79c43d3401285f7cdba0f607990`.
Inventory SHA: `26139d373f23403e04234acb1d926de779e54f8bcc077d259ac51e8f8a2ab464`.
The 281,497,566-byte report SHA is
`c6ecd396aaaad898b4d0c4cfa235429507559e680ebc2c00a4c27332067b24d9`;
closure SHA is `5a09474a9408233dd885fd1d6a80ff62a7db0e91c1a676e3eca8ea6e96fb97ce`.
Its 32 source bindings include the new command contract and its unchanged
runtime/morphology ancestry. Whole invocation: **1,745.204 s (29.09 min)**;
safety 675.749 s, native child 677.347 s, independent replay 249.062 s and
other workflow overhead 143.046 s. These timings exclude prior diagnosis,
implementation, focused checks and closure work; no matched speedup is claimed.

Four [cold closure checks](../tests/test_development_v29_recovery_checkpoint.py)
pass in **34.863 s**, retained at
`SporeSpore_Evidence/development-v29-cold-closure-2e97ef7c880f481fafeb809d27802c60`.
Cold-test stderr SHA:
`bd002df40cb705fd605b2c1b977c827bad8231cb356cda5644be9fd12900cc04`.
They reconstruct the full population/replay, standing, all capped commands,
all cycles and negatives; refuse promotion; and preserve V23/V25/V26/V27/V28,
the V28 preflight failure, original runtime sources and R173 byte-for-byte.

Next diagnose the four remaining rear-foot stance interruptions and the
fragmented front-left swing from V29's retained native contacts, actual joint
tracking and geometry. A smaller command removed out-of-range requests but
did not establish stable walking. No new candidate, sweep, contact threshold,
old-attempt extension or physical successor is selected at this closure.
R173 and SDK1/full readiness remain **14/20, 14/25**.

## V29 prospective: joint-bounded walking amplitude

[V29's distinct profile](../sdk/development/recovery_candidates/v29-joint-bounded-walking-amplitude-v1.json)
is implemented and passes **34 focused zero-world checks**. It reuses V28's
exact recovery/stance DLL, runtime binding and extension; no Rust rebuild or
new recovery controller is needed. Change only the scalar on the existing
72-step resumed-walking ramp: maximum amplitude **0.5994550408719347** instead
of one. The [command contract](../sdk/development/recovery_joint_bounded_walking_entry_contract_v1.json)
derives this as `1.1 / (0.82 * 1.75 + 0.4)`: the existing knee limit divided
by the frozen policy's largest loaded-swing knee request, including its
release-gate apex override. This is a command choice, not a new physical
threshold, fitted margin or change to the policy's position/velocity limits.
The native velocity controller uses the requested angle; a separately reported
clamped angle does not itself make an out-of-range request reachable.

The retained-data [diagnosis](../sdk/conformance/development_recovery_v28_contact_geometry.py)
and [four design checks](../tests/test_development_v29_recovery_design.py) bind
V28's original closure and 281,576,524-byte report. All **45 available native
inputs** within its four failed stance cycles contain **zero raw distal-body
contacts**, not merely a false foot-support label. Front-right's final gap has
zero raw contacts in all **107 available next-command inputs**. Command n+1
contains the observation after walking step n; trace 400 has no next input.
All 148 knee requests marked position-saturated are reproduced: front-left 40,
front-right 40, rear-left 28 and rear-right 40. V28 stays a valid development
observation with all three original walking negatives; this analysis regrades
nothing and proves no causal explanation.

The following heights describe the lowest point of the declared foot capsule
relative to the authored floor, in millimetres. They are not Jolt's contact
margin, a new contact test, or proof of load. Step intervals exclude landing.

| Foot and walking steps | Available raw-contact inputs | Raw contacts | Nominal foot-bottom height, min to max (mm) |
| --- | ---: | ---: | ---: |
| Rear left, 104–115 | 12 | 0 | -0.784 to 2.033 |
| Rear left, 280–294 | 15 | 0 | 0.010 to 7.963 |
| Rear right, 115–118 | 4 | 0 | 0.112 to 0.794 |
| Rear right, 132–145 | 14 | 0 | 0.219 to 2.582 |
| Front right, 293–399 | 107 | 0 | 0.347 to 82.955 |

Geometry uses the retained native torso orientation, not the walking sampler's
different orientation convention. That sampler maps host -Z to canonical +X;
both preserve the capsule's Y axis. All 1,600 precommand body samples are
aligned; native/canonical torso axes differ by at most 2.009e-7 after the
explicit conversion. Ideal-hinge reconstruction from measured joint angles
has mean/max foot-bottom discrepancies **0.193/2.412 mm** and a maximum
distal-origin discrepancy **15.785 mm**. It omits measured anchor/axis
compliance. Geometry from requested angles at the measured torso is a
hypothetical pose, not a simulated outcome. In particular, three of the four
failed stance intervals have ideal requested foot bottoms above the floor,
while rear-left 104–115 does not; one simple label or geometry explanation
does not explain every interruption.

Hypothesis: a smaller, in-range requested bend may reduce swing-return lag;
the accompanying smaller hip sweep also reduces ideal straight-leg reach
loss. It may instead fail to lift or relocate a foot. Earlier contact gating
is not selected: its exact phase-54/144 checks do not directly guard the four
observed stance-loss phases (103, 279, 294, 311). No new feedback or force-aware
controller is introduced.

Keep zero-phase startup, 360-step actual gait, clocked mode through local 360,
contact-gated mode from 361, native contacts and independent replay. Amplitude
is zero at local 1 and reaches the selected maximum at 73; prefix amplitude
remains one. Preserve the 986-step tail, 1,338-step total cap and existing time
limits. Every startup sample and original evaluator remains. The horizon does
not guarantee two completed cycles per foot. No baseline reuse, matched effect,
controller/amplitude sweep, extended old attempt or acceptance authority.

All 34 checks pass under
`SporeSpore_Evidence/development-v29-integration-630d78a25728443fa5c55fcac8fdc91c`:
design 4, real entry/reader 6, schedule 4, start 4, prospective replay 4,
historical transition 4, exact runtime/fixtures 4, cold V28 closure 4.
The selected native command probe stays within the knee limit and all old
profiles, V28's complete record, and R173 remain exact. Diagnostic stdout SHA:
`749d22cd9a477c7ec79db908809e81b6a5f219bd47a5ea2005394cab126a85b8`.
Contract/profile/schedule SHAs respectively:
`2030f252770ec0d13635f2955afc9dafabb54c4fb87e375520908637dd4877c6`,
`395e8a35942389ab3b00209b945382e03a0f5d0d396a2441a25bb4758217d63f`,
`13a175393d133012dcc985c1176f3b29ce1cdf552dab862cd0168738d52f00e5`.

Next: from a clean pushed freeze, run the complete applicable **107-check**
safety gate and, only if green, one fresh seed-40200 kicked child through the
shared production worker, bounded native path, retention and independent
reader. V29 has not run physics at this prospective boundary. SDK1/full remain
**14/20, 14/25**; R173 and official acceptance gates are unchanged.

## V28 closure: first swing exercised, three walking negatives

[V28's immutable physical closure](../sdk/development/recovery_attempts/dd42319c12564b7ea402626dbaf8f845.json)
records one fresh seed-40200 kicked child from clean pushed source
`276f95959964df52ba3ccab0c3642e8836f4f937`. All **107 safety checks pass**, the
native child exits zero with empty stderr and no engine-health failure, and
the independent reader replays **1,258 transitions**: 467 canonical observations,
119 entry observations, one measured-prone initialization, 30 prefix and 400
resumed walking commands, 430 native-contact inputs, the zero-phase start and
the actual local-361 adapter-mode transition. Replay creates no physics world.
Status is `closed_consumed_valid_development_observation`, not walking success,
matched superiority, complete official route proof or acceptance authority.

The unchanged stance ramp again reaches the original standing criterion at
**858**, after 232 dwell samples and the final 60 consecutive stable samples
at 799–858. Cold reconstruction checks all 1,864 handoff/dwell joint commands
against measured inputs, the reference ramp, damping and motor cap. The initial
walking target mismatch is 0.0026744266506284475 rad. The same body continues
without pose/velocity resets or force-aware control.

The new amplitude schedule is independently verified: zero at local 1, full
at local 73/global 931, with **328 full-amplitude samples**. The actual gait
period remains 360 and contact gating still starts at 361. Rear-left support
first disappears at local 32; short interruptions are not conflated with a
complete qualifying cycle. Its first counted flight is **38–87**, advancing
**0.11340429609771685 m**, above the unchanged **0.012 m** relocation minimum.
The first 72 samples contain 34 supported samples, versus V27's retained 72/72.
These are descriptive observations from distinct attempts, not a matched effect
or a causal explanation of other contact losses.

Walking spans 859–1258 (**400 steps**) and advances **0.3191290686609283 m**.
Absolute lateral drift is 0.031408854487085414 m, maximum tilt
0.13329925113152552 rad, minimum torso height 0.37848326563835144 m and torso
contact count zero. The original negatives remain `every_limb_forward_relocation`,
`every_limb_two_contact_cycles`, and `terminal_four_contact_recovery`. No warmup
samples or negative cycles are dropped. All nine counted cycles are reconstructed
below; step numbers are local to resumed walking. Forward movement uses the
retained distal rigid-body origins, not sole centers, exactly as the evaluator.

| Foot | Lift step | Landing step | Forward movement (m) | Lift began during commanded | Original relocation rule |
| --- | ---: | ---: | ---: | --- | --- |
| Rear left | 38 | 87 | 0.11340429609771685 | Swing | Pass |
| Rear left | 104 | 116 | -0.027494080551459132 | Stance | Fail |
| Rear left | 280 | 295 | 0.005898586999390942 | Stance | Fail |
| Front left | 119 | 226 | 0.21814446124026254 | Swing | Pass |
| Front left | 238 | 248 | 0.013784930308466059 | Stance | Pass |
| Rear right | 115 | 119 | 0.002042377940309592 | Stance | Fail |
| Rear right | 132 | 146 | 0.011887551526145401 | Stance | Fail |
| Rear right | 209 | 279 | 0.16471696796940094 | Swing | Pass |
| Front right | 29 | 113 | 0.07874688939958846 | Stance | Pass |

All four inadequate cycles begin during commanded stance, before contact-gated
progression starts. Front-right's later flight begins at 293 and remains open
through 400 (108 samples); rear-left's final gap is 394–400 (7 samples).
Front-left and rear-right support are present at cutoff. These support flags
do not alone establish raw-contact absence, geometry error or a physical cause.
The short horizon does not guarantee two cycles per foot, but that does not
erase the relocation failures or change the terminal negative.

All **61 files / 1,052,965,717 bytes** remain in
`SporeSpore_Evidence/development-recovery-smoke-dd42319c12564b7ea402626dbaf8f845`.
Inventory SHA: `e19e479273a4906f795db2c06e2ffe7580f90dcf0df1d973ef44aab9a244e376`.
The 281,576,524-byte report SHA is
`4dfc5c69f268e97a88d6d6c910f83691d9fb82b9757a610981d0ca761494b293`;
closure SHA is `28720cc4c1662f98066ccf6e83d7fe985557b62c676f91c9bbc09ba28bc293ab`.
Whole invocation: **1,931.863 s (32.20 min)**; safety 746.428 s, native child
713.519 s, replay 299.047 s, other workflow overhead 172.869 s. This excludes
preceding implementation/preflight attempts and later closure work; it is not
a general or matched performance claim.

Four [cold closure checks](../tests/test_development_v28_recovery_checkpoint.py)
pass in **43.333 s**, retained at
`SporeSpore_Evidence/development-v28-cold-closure-f0ac0730b722473198122f0013be0a8b`.
They reproduce the complete record, actual ramp/standing/first swing, all nine
cycles and negatives; reject promotion; and preserve V23/V25/V26/V27, the V28
preflight failure and R173 byte-for-byte. The preflight failure remains separately
closed, not converted into a pass by the test fix or this new attempt.

Next diagnose the unwanted stance support losses and front-right's final flight
from retained native inputs, joint commands and geometry, separating labels
from actual contact state. No physical successor, controller sweep, new margin,
extended old horizon or acceptance claim is selected at this closure. R173 and
SDK1/full readiness remain **14/20, 14/25**.

## V28 prospective: first-swing walking activation

### V28 preflight failure and test-only correction

[The first full-gate attempt](../sdk/development/recovery_attempts/4e43b57e644d47a78c1e80681361a24a.json)
is closed as a zero-world safety failure from clean pushed source
`4a83be9cc7e5a276189c47369e92f7efda3af60a`. It ran 95 tests: all 91 in preceding
stages passed; one of four transition tests failed. No child started. The
700.205469-second invocation retains 42 gate files and five actual-interface
fixture files. Closure SHA is
`3acbd4a157cd72a67589e8171705fb5cc46205f611c63a0755f2229ef2841755`.

The fixture selected the current V28 runtime correctly but also selected its
new amplitude identity for untouched V23 walking rows. Both original and
transition-enabled readers correctly returned
`DEVELOPMENT_WALKING_ENTRY_READER_RETENTION`, before memory-chain validation.
The test now chooses the amplitude identity retained in the historical report,
and separately verifies the current different identity still refuses it. It
does not relabel old observations, relax a reader, or regrade V23's original
invalid outcome. All 445 old walking commands replay only in the explicitly
separate transition diagnostic; all nine corrupted boundaries still refuse.

The correction changes only the two transition-test files, this closure and
bookkeeping. Production code, DLL, candidate profile, schedule, first-swing
contract and every bound/criterion remain byte-identical to the first freeze.
All 16 focused checks pass at
`SporeSpore_Evidence/development-v28-transition-fix-3fafda1e987f480b92a98ee262f5ad9f`:
transition 4, prospective replay 4, walking contacts 4 and native contacts 4.
The transition suite also cold-checks every file in the failed gate/fixture
populations and keeps the failure's zero-world/no-claim status exact.
Next: a fresh complete 107-check safety gate, then one fresh kicked child only
if green. No V28 physics yet; readiness and R173 remain unchanged.

### Initial prospective implementation

[V28](../sdk/development/recovery_candidates/v28-first-swing-walking-warmup-v1.json)
keeps V27's exact V20 recovery/stance DLL
`b0fc357702a7040bd38c9262f94207e16cee4ca22ba0335d7664e7f052e100fb`.
Only the smooth amplitude ramp for resumed BW5R-B walking changes: 360 to 72
steps. The [new distinct entry contract](../sdk/development/recovery_first_swing_walking_entry_contract_v1.json)
uses the existing normal launcher's `SWING_TICKS=72`, not a value fitted to a
successful outcome. Amplitude is zero at local step 1 and full at 73. The
actual gait period remains 360; progression remains clocked through 360 and
contact-gated from 361 through the actual existing adapter-memory operation.
Zero-phase startup, seed 40200, body continuity, all recovery/stance commands,
motor gains/caps, native contacts, standing deadline and walking criteria stay
fixed. The [schedule](../sdk/development/recovery_schedules/v28-first-swing-walking-warmup-v1.json)
preserves the 986-step tail and 1338-step total cap. No startup rows are dropped.

Four [retained-data design checks](../tests/test_development_v28_recovery_design.py)
reproduce V27's exact closure/report identities and these observations:

- All 72 samples of the first scheduled rear-left swing still report support.
  Maximum commanded gait amplitude is 0.10134726508916322 and maximum requested
  rear-left knee angle is 0.08612768053860428 rad. The first intended swing is
  therefore being commanded at low amplitude; native release is not inferred.
- Six of nine completed contact cycles miss the original relocation criterion;
  five of those six begin while their limb is commanded to remain in stance.
- Rear-left support is absent in the final 93 trace samples. All 92 available
  subsequent native controller inputs contain zero raw rear-left distal contact
  samples; there is no next input for the final trace row. This is not merely
  a support-label mismatch, and the shorter ramp is not a proven explanation.

The build is retained at `SporeSpore_Evidence/development-candidate-build-c7e000ff5d1640ea975c471905fa2ecc`.
All 287 core tests reran; core/fixture/adapter stages took 1.954/0.406/0.656 s
using the existing compiler cache. The immutable binding records all sources,
toolchain inputs and logs. No test/qualification evidence was reused.
Focused preflight retains:

- `development-v28-integration-9716f1d8302c4d9f9b0468a1d7099caf`: four design
  checks pass; the runtime suite's unbound worker reaches its original 30-second
  startup timeout with zero worlds. Host CPU was subsequently observed at 100%;
  causation is not established. The original failure remains exact.
- `development-v28-integration-27ed12a4f06b45dea1f5071cd1674ad4`: unchanged-code
  retry passes runtime 4, startup 4 and schedule 4. The walking probe then
  catches a GDScript Boolean type-inference error in the new test (zero worlds).
- `development-v28-integration-d166c8d5b3cb45d7a4d961a55824fbe6`: after the
  explicit test-only Boolean annotation, walking entry 6, prospective replay 4
  and V27 cold closure 4 pass. Producer/reader refusal controls remain intact;
  the closure binds the new 15-source entry/start/transition set while old
  frozen closures continue resolving their own exact historical sources.

Next run the complete applicable 107-check safety gate, then one fresh kicked
child and independent replay. This question tests first-swing activation, not
guaranteed sustained walking or two cycles per limb. Do not extend a consumed
attempt, sweep ramp values, cache a baseline, relax a criterion, regrade old
records or claim superiority. No V28 physical outcome exists at this prospective
boundary. R173 and SDK1/full readiness remain 14/20, 14/25; acceptance and release
authority remain false.

## V27 closure: stable neutral handoff, three walking negatives

[The immutable V27 closure](../sdk/development/recovery_attempts/8f778946bed1448d80196dc57b446dda.json)
records one fresh seed-40200 kicked child from clean pushed source
`45fb08a32f304bb68376647717792238eaf615fd`. Its status is
`closed_consumed_valid_development_observation`, not walking success or official
recovery acceptance. All **107 applicable safety checks pass**. The native child
exits zero without timeout, stderr, engine errors, assertions or fatal diagnostics.
The independent reader passes **1,258 transitions**, 467 canonical observations,
119 entry observations, one measured-prone initialization, 30 prefix and 400
resumed walking commands, 430 native contact inputs, the actual adapter mode
switch and the selected zero-phase startup. Replay runs no physical world.

Pre-stance phase boundaries remain support completion 408, raise completion
625 and handoff 626. The recorded stance commands follow the declared flexed-to-
neutral reference: neutral from dwell command 60 (global 686), then held neutral.
The measured knees are still substantially bent at that moment; reference
completion is **not** pose completion. The body subsequently reaches the
unchanged standing criterion at **858**, after **232** of the available 240
dwell samples. There are 73 stable samples overall, with the final required
**60 consecutive samples at 799–858**. No deadline or threshold is altered.

At walking entry the maximum measured joint-to-target mismatch is
**0.0026744266506284475 rad (about 0.15 degrees)**. The first requested walking
motor speed is at most 0.04987381026148796 rad/s. V26 retained a 0.2524440884590149
rad mismatch; this is a descriptive difference between separate development
observations, not a matched effect, superiority result or explanation of later
contact loss. The same body is retained without transform/velocity writes,
rebuilds, solver resets or force-aware control.

Resumed walking spans **859–1,258 (400 steps)**, advances
**0.13511383533674404 m**, drifts laterally 0.003764468887860861 m, has maximum
tilt 0.11764276944772123 rad and minimum torso height 0.38081803917884827 m,
and records no torso contact. The three original false receipts remain:
`every_limb_forward_relocation`, `every_limb_two_contact_cycles`, and
`terminal_four_contact_recovery`. The later standing completion leaves fewer
walking samples within the same total budget; the selected diagnostic never
guaranteed two complete cycles per limb or a full official walking horizon.
That coverage limitation does not erase any negative.

The cold check reconstructs all **nine** completed contact cycles. **Six** miss
the unchanged 0.012 m relocation rule; all six finish within the original
360-step warmup and none is excluded. Per-limb cycle counts are front-left 3,
front-right 1, rear-left 1, rear-right 4. The final open support-loss intervals
are front-right 374–400 (27 samples) and rear-left 308–400 (93 samples).
Front-left and rear-right support are present at cutoff. These are recorded
support flags, not new raw-contact or causal claims. The evaluator's position
field is the distal rigid-body origin, not a sole center. There are 40
full-amplitude samples, starting at local 361/global 1,219. All native walking
inputs agree with the controller inputs and actual native gate timeouts total
zero; this does not make the three walking negatives pass.

All **61 files / 1,052,968,542 bytes** remain under
`SporeSpore_Evidence/development-recovery-smoke-8f778946bed1448d80196dc57b446dda`.
Inventory SHA: `b4a587ad54c8a41ef9f70234dda7e3cc107e7594048bec88ea8e5af4e1e87c3f`.
The 281,571,856-byte report SHA is
`0a5936d2745d1c92ce891edc5a0bcb24e63f289dd15e98ddb1483882d0855be1`.
Whole invocation: **2,156.742 s (35.95 min)**; safety 584.441 s, native child
910.938 s, replay 487.484 s, other workflow overhead 173.879 s. These exclude
preceding implementation/build/integration and later closure work. No matched
performance experiment or general speedup is established by this attempt.

Four cold closure checks pass in **33.786 s** under
`SporeSpore_Evidence/development-v27-cold-closure-425a17494d6941238996cb7e2f31a30c`.
They reproduce the complete closure, check all **1,864** recorded handoff/dwell
joint commands against the declared reference/damping/caps, verify measured
standing and same-body startup, reconstruct every cycle, reject promotion and
preserve V23/V25/V26/R173 bytes. The preceding test invocation also reports four
passes, but its ad hoc receipt wrapper supplied `-Text` to the byte-only writer
and failed after creating an empty execution receipt. Its original logs and
empty receipt remain under `development-v27-cold-closure-881e6c7a8bd74686a70b7a5a40c876ab`;
the corrected invocation uses `-Bytes` in a fresh output directory. No physical
attempt or independent physics replay was repeated for that wrapper correction.

**Next finite work:** diagnose the retained walking startup/contact cycles and
later support loss after this near-neutral handoff, separating actual motion
failures from the deliberately bounded cycle-coverage limit. Select at most one
grounded successor afterward. Do not sweep phases, extend the consumed cutoff,
exclude warmup failures, rethreshold, or claim that the initial mismatch explains
the remaining negatives. No new physical successor is selected at this closure.
R173 and SDK1/full readiness remain **14/20, 14/25**; full paired commissioning
and official recovery/walking acceptance remain open.

## V27 prospective: ramped neutral stance

[V27](../sdk/development/recovery_candidates/v27-ramped-neutral-stance-v1.json)
selects recovery controller V20 and stance controller V7. It preserves every
pre-stance command and changes only the separately owned stance reference:
start at V18's existing flexed goal, smoothly approach the existing neutral
goal during the first 60 upcoming dwell commands, then remain exactly neutral.
The reference is not a measured pose and does not guarantee support or standing.

The [new stance contract](../sdk/core/contracts/recovery_candidate_stance_profiles_v6.json)
uses the existing -0.25 rad knee origin, zero endpoint and smoothstep
`t*t*(3-2*t)`. At 120 Hz, 60 commands take 0.5 s; the maximum reference-coordinate
speed is `1.5 * 0.25 / 0.5 = 0.75 rad/s`, matching the existing stance speed cap.
This duration is derived from existing command limits, not fitted to an
observed success or timeout. The command clock is zero at handoff and completed
dwell steps plus one afterward, so command 60 is already neutral before the
earliest possible consecutive-60 standing completion. Actual joint velocity
and pose tracking are not proven by this reference-speed calculation.

Retained V26 data motivates the test without supplying a causal conclusion.
Its first walking command has zero amplitude/zero targets against knees near
-0.25 rad and hips near +0.12 rad; the largest mismatch is
0.2524440884590149 rad, and the largest requested motor speed exceeds 2 rad/s.
The prolonged rear-left gap is not merely a support-classification mismatch:
all **147 available native post-loss inputs** contain zero raw contact samples
for `rear_left_distal`. They correspond to resumed trace steps 298–444 carried
by commands 299–445. Trace step 445 also lacks support, but there is no later
command input to establish its raw-contact sample. Preserve that distinction
from the **148** unsupported trace samples. This does not show that the initial
transient caused the later gap. V25's constant-neutral standing timeout remains
a separate valid negative, not a reason to lengthen its deadline.

The 0.1 s stance response, 0.5 measured-velocity damping, 0.75 rad/s motor cap,
impulse caps, consecutive-60 stability gate and 240-step stance timeout stay
fixed. V26's zero-phase resumed BW5R-B walking, 360-step clocked amplitude ramp
then contact gating, native contacts, resume frame and independent replay stay
fixed. The tail remains 986 steps, total resource cap 1,338; child/replay time
limits remain 1,500/900 s. There is no new phase, body replacement, pose or
velocity write, solver reset, walking-policy change or force-aware recovery.

Build evidence is retained under
`SporeSpore_Evidence/development-candidate-build-2fcbb65da6d8474d9ff0826e5baebebe`.
All **287 core tests pass**, including five new tests covering exact pre-stance
preservation, the full reference clock, actual planner/damping/caps, negative
controls and public-interface fixtures. Core tests/build, fixture export and
adapter build take 74.968/0.532/63.640 s. The independent optimized DLL SHA is
`b0fc357702a7040bd38c9262f94207e16cee4ca22ba0335d7664e7f052e100fb`.

Both initial zero-world integration failures are preserved under
`development-v27-integration-58a154869ca94061aea203e15be64346` and
`development-v27-integration-de43dc75e4684d7897d4f51f6a1c6038` in the evidence root.
The first exposed missing successor-profile registration in the Python/Godot
mapping; the second exposed a test's constant-goal assumption. Registration
now includes the new contract. Rust tests verify trajectory mathematics;
the actual DLL/applier test verifies the exported position command's motor
translation, with the old static-profile assertions preserved. No physics ran.

All **12 integration/cold checks pass** under
`development-v27-integration-b0787550bb0847e2b957cfc3d7ad2133`: runtime 4
(24.235 s), walking start 4 (14.620 s), original V26 closure 4 (27.123 s).
Four additional read-only design checks pass in 4.699 s under
`development-v27-retained-diagnosis-d0a7ad4948124a3bbd1fbc6990349adc`, binding
the exact V26 record/report, mismatch, raw-contact gap and unchanged limits
and historical bytes. No result is promoted or rewritten.

**Next test:** from the clean pushed prospective source, run the complete
107-check applicable safety gate, then one fresh seed-40200 kicked child with
full bounded retention and independent replay. A standing negative provides
no walking coverage; it is retained without extending the attempt. No phase
sweep, warmup exclusion, baseline reuse, matched effect, superiority, complete
official-route or acceptance claim is selected. R173 and SDK1/full readiness
remain **14/20, 14/25**; official paired commissioning and acceptance remain open.

## V26 closure: valid startup replay, two walking negatives

[The immutable V26 closure](../sdk/development/recovery_attempts/4ed1bcc619b64a4284505e44e122ee82.json)
records one fresh seed-40200 kicked child from clean pushed source
`f0498670c70fd2e90f4abc66b2bc1153b8684693`. Its status is
`closed_consumed_valid_development_observation`: the selected diagnostic path
is complete and independently replayed, but resumed walking is **not successful**
under the unchanged evaluator. No baseline was reused or causal comparison made.

All **107 applicable safety checks pass**. The native process exits zero with
empty stderr and clean engine health. The independent reader passes all
**1,258 transitions**, 422 canonical observations, 119 entry observations,
one measured-prone initialization, 30 prefix commands, 445 resumed commands,
475 native-contact inputs, the actual adapter mode switch, and one explicitly
selected zero-phase resume. The prefix still starts at 240, the resume at zero,
and the original seed remains 40200. There is no body rebuild, pose/velocity
write, solver reset or force-aware recovery.

Standing completes at **813**, after the existing 187-step flexed-stance dwell
and its required final 60 consecutive stable samples. Resumed walking spans
814–1,258. It advances **0.1615721188493282 m**, drifts laterally
0.005744734002927743 m, has maximum tilt 0.10113618534691704 rad, and records
no torso contact. Two original receipts remain false:
`every_limb_forward_relocation` and `terminal_four_contact_recovery`.
The new phase origin therefore does not clear the walking blockers.

The cold test reconstructs all **11** completed contact cycles from the original
trace and matches the evaluator's per-limb counts and minima. **Six** miss the
unchanged 0.012 m relocation requirement; all six finish within the 360-step
amplitude warmup. None is excluded or regraded. At cutoff, front-left and
rear-right support flags are true, front-right and rear-left false. The last
open rear-left interval starts at resumed step 298 and covers 148 samples
through 445; front-right's final interval starts at 440 and covers six samples.
These are recorded support flags, not a newly inferred native-contact cause.
The producer's positions are distal rigid-body origins, not sole centers.

The retained first command still has a maximum joint-position-to-target jump
of **0.2524440884590149 rad**. Changing the starting clock did not remove that
standing-to-walking pose mismatch. Its causal contribution, and the cause of
the prolonged rear-left loss, remain to be diagnosed. A better-looking metric
or fewer missed cycles than an older run is not a matched effect or superiority
claim. V23 remains originally replay-invalid and V25 remains a valid neutral
standing-timeout negative.

All **61 files / 1,000,249,300 bytes** remain under
`SporeSpore_Evidence/development-recovery-smoke-4ed1bcc619b64a4284505e44e122ee82`.
Inventory SHA: `cc8000041189bd3547d822bfb154c9b9b1a7c5c4dcd7f7c9a81dd1f33692d3a9`.
The 268,023,639-byte report SHA is
`b147debd22eb00dd1c75a2f51437bde96f5a50954e9cc921b027e9b271ec7757`.
The whole invocation takes **2,686.710 s (44.78 min)**: 1,134.488 s safety gate,
1,138.089 s child, 241.484 s replay and 172.649 s other workflow overhead.
These timings exclude the preceding build/integration work and do not establish
the cause of this attempt's slower gate or a general throughput estimate.

Four cold checks pass in 34.648 seconds under
`SporeSpore_Evidence/development-v26-cold-closure-36779078e1354814a0841d1e6dda6788`.
They reproduce the complete closure, verify actual startup/body continuity,
reconstruct all cycles and original negatives, reject forged promotion, and
preserve V22/V23/V25 and R173 bytes. R173 and SDK1/full readiness stay **14/20,
14/25**; no support, recovery, equivalence or release authority is advanced.

**Next finite work:** inspect the retained initial handoff and rear-left support
loss, then select one evidence-grounded bounded successor. Do not phase-sweep,
extend the old cutoff, exclude warmup misses, retune thresholds, or infer that
normal startup phase solved pose matching. No new physical successor is selected
at this closure. Full paired commissioning and official acceptance remain open.

## V26: normal-phase walking start

[V26](../sdk/development/recovery_candidates/v26-normal-phase-walking-start-v1.json)
selects the existing V18 recovery and damped flexed stance, not V25's unqualified
neutral stance. The only new physical choice relative to the V23/V24 design is
the initial common gait clock of resumed walking: **zero instead of 240**.
The actual normal launcher's `compile_sdk_execution_mode_plan` returns the
zero-base start for full post-settle authority. Recovery's original facade
instead uses `seed % 360`; the retained V23 start receipt and first actual
native request both contain 240 for seed 40200. The seed itself is not changed.

At phase 240 the rear-right limb begins partway through its coded swing; the
zero origin begins the rear-left swing at its start. This is a command-schedule
difference to test, not a demonstrated cause of V23's later contact losses.
The first zero-amplitude target remains neutral, so the flexed standing-pose
mismatch is **not** solved by this change. No warmup sample or missed contact
cycle is removed from the original evaluator.

The [shared startup contract](../sdk/development/recovery_walking_start_contract_v1.json)
binds the normal launcher SHA `80f5197940e971dbff6bba0720eb92d72843386754f327e5c533f3737fdf17eb`.
The real facade executes that existing plan only for the explicitly selected
resume profile. Default callers and the fresh prefix retain seed-modulo phase.
The session retains the selected startup identity, original seed and initial
gait clocks; the independent reader checks those against the first actual
native request. Missing first rows, crossed seeds/phases/selectors and duplicate
limbs refuse. Early physical termination before walking retains zero resume
sessions and cannot be reported as startup coverage.

Build root:
`SporeSpore_Evidence/development-candidate-build-d76d94b2e67545f79c28f251e03e2f67`.
All **282 core tests run anew and pass**. Core tests, exported V18 recovery/stance
fixtures and adapter build take 1.484/0.297/0.453 seconds. Unchanged compiler
work is reused; the independently copied DLL remains
`c7ed66d3d2d14f772af4ed29f130647f45ff8155fe246247a10cdb4d66d3cad2`.
The Rust recovery and walking implementations are unchanged.

During integration, **39 connected checks pass** across
`SporeSpore_Evidence/development-v26-real-interfaces-07bbcd0409a94742a3cc785b428d6a6e`
(startup 4, profile 5, runtime 4, reader 8, schedule 4, entry 6) and
`SporeSpore_Evidence/development-v26-cold-integration-2cfabe92a6a34026bbcc7829357b660a`
(prospective binding 4, actual adapter transition 4). The latter also passes
four cold V25 closure/preservation checks. The new zero-world probe executes
450 compiled walking commands through the actual adapter start and mode
transition, with explicitly synthetic observations and no motor/world access.
No physical outcome is inferred from it.

The initial zero-world failures remain retained: declaration counts parsed as
binary64 did not exactly match the normal plan's integer dictionary; one new
test used the recovery command field name on a walking command; the existing
closure-binding test expected five sources instead of the selected eleven.
The corrections validate/project declaration counts only, use the actual
walking command fields, and assert the exact six added source identities.
Roots: `development-v26-start-integration-b7acb371940e4596b8b31e540ecbd525`,
`development-v26-start-diagnosis-086ccb3c19504e7a8cbcdef565d5c6f9`,
`development-v26-start-fixed-018efe1829d44d09b33059bd2cef05eb`, and the first
connected-integration root above. These are zero-world test failures, not
physical attempts or repaired historical observations.

**At the prospective implementation boundary:** from a clean pushed source,
the selected next work was the **complete 107-test applicable
safety gate**, then one fresh kicked child, seed 40200, full retained telemetry,
unchanged 986-step tail/1,338-step cap and 1,500-second child/900-second reader
bounds. Preserve V25's valid negative and V23's original invalidity. The question
is whether this normal phase origin helps the bounded recovery-to-walking path;
it does not test neutral stance, force-aware recovery, a phase sweep, a matched
effect, the normal launcher's separate 112-step evidence alignment, or held-out
acceptance. R173 and readiness remain SDK1 14/20 and full program 14/25.

## V25 closure: neutral standing times out with valid replay

[V25's physical closure](../sdk/development/recovery_attempts/d8f05d136e4849248b7246e3e546ecf2.json)
records one fresh, non-comparative seed-40200 child from clean pushed source
`2bee626311f50cfbd8ffbfe025c8be490e40b469`. All **103 safety checks pass**;
the child exits zero with healthy native diagnostics after **866 solver steps**.
Independent replay validates all 866 transitions, 475 canonical observations,
119 passive-entry observations, one initialization and 30 walking-prefix
commands. It validates zero resumed-walking commands or adapter mode switches:
the candidate never reaches walking. The complete report is valid, but the
planned diagnostic tail and walking coverage are not completed.

The result is **standing-timeout negative**, not infrastructure-invalid and not
a successful recovery. Support establishment takes six samples (403–408),
raising takes 217 (409–625), handoff is 626, and standing consumes its full
240-sample budget (627–866). During standing, four-foot support qualifies on
66/240 samples, raised-body criteria on 196/240, and complete stable-standing
criteria on 41/240. The best and final uninterrupted stable stretch is **32**
samples, 835–866, short of the unchanged **60** requirement. Step 834 fails
four-foot support. Safety, ownership and no-cheat gates remain true throughout;
there are no body rebuilds, transform/velocity writes or solver resets.

The final pose is nearly level (0.0306 degrees tilt), with linear speed
0.04483 m/s and angular speed 0.03287 rad/s. That quiet endpoint cannot replace
the required preceding stable interval. The cold audit checks all 1,920 stance
motor requests against the declared neutral-position plus measured-velocity
damping rule, under the unchanged 0.75 rad/s cap. No thresholds, timeouts,
controller bytes, evaluator results or consumed identities are revised.

Retained root:
`SporeSpore_Evidence/development-recovery-smoke-d8f05d136e4849248b7246e3e546ecf2`.
All **59 files / 906,052,132 bytes** are bound by inventory
`7a31025dfa423b4943dc73364ebf7a6fad493a4b832a3e6028442e34490e9212`;
the 239,903,609-byte report is
`7c0da74e1c3f26d59caa5b2b5266357a9a40ee4937063323c17e53ab2d2eec26`.
The invocation takes 1,343.376 s (22.39 minutes), including 477.679 s safety
gate, 529.914 s native child and 217.406 s independent replay; the remaining
118.377 s is other invocation overhead. These timings exclude candidate
implementation/build and the separate earlier failed preflight.

Twelve cold checks pass under
`SporeSpore_Evidence/development-v25-cold-closure-0c0f75f486be45999182001764ae47bd`:
V25 four in 21.087 s, V22 four in 25.893 s, V23 four in 12.553 s. They reproduce
the complete original populations, validate the new negative and its commands,
reject fabricated promotion, and preserve the prior V15 negative, V22 valid
negative, V23 original invalidity, separate transition replay, first V25
zero-world failure and R173 bytes.

**Next bounded work:** return to the already-standing flexed-stance lineage and
its retained walking evidence. The outstanding behavior is sustained resumed
walking: V23's separately replayed record still has per-foot relocation and
terminal four-contact negatives. Its late counted contact releases occurred
during commanded stance with smooth joint targets, not at the startup mode
switch. Diagnose a concrete change for those losses before choosing a fresh
candidate. Do not extend V25's timeout, carry neutral stance forward as qualified,
or infer a walking effect from V25. No new physical successor is selected by
this closure. Single-child results remain non-comparative; SDK1 M07 is not
closed, R173 stays exact, and readiness remains SDK1 14/20, full program 14/25.

## V25: damped neutral stance hypothesis

[V25](../sdk/development/recovery_candidates/v25-damped-neutral-stance-v1.json)
is implemented, not physically proved. Candidate SHA-256:
`152a39aca806be64c4e2ce8420344a36a2ffdc7a2394b52679f8c588665cb2f3`.
Recovery controller V19 preserves every pre-stance V18 command and profile limit.
Its separately owned stance v6 uses the existing zero-joint goal while retaining
the current 0.1-second response, 0.5 measured-velocity damping, 0.75 rad/s stance
speed cap, actuator impulse caps, 60-step standing requirement and 240-step
stance timeout. The [new stance contract](../sdk/core/contracts/recovery_candidate_stance_profiles_v5.json)
is shared by Rust and GDScript; no historical profile is edited.

Retained V23 commands show both full-amplitude contact losses happen during
commanded stance, with zero knee targets and smooth hip targets. The rear-left
loss follows a sharp measured joint-velocity disturbance; front-left loss
coincides with a small torso rise. Neither observation establishes a cause or
warrants a walking gain/threshold change. Separately, the first walking command
targets zero at all eight joints while the measured standing pose differs by
up to **0.2524440884590149 rad**; maximum measured joint speed then is
0.05788791924715042 rad/s. The exact source projection is
[retained handoff fixture](../sdk/core/contracts/recovery_v25_retained_walking_handoff_fixture_v1.json),
SHA-256 `dd84095c234912b4638f0e309809d6fcc459e44971cb694ed4a93a09266a4f7a`.

The development question is whether neutral standing **with current damping
and world-vertical support** can satisfy unchanged standing requirements and
reduce that entry mismatch. Earlier undamped neutral standing lost foot load;
its negative is not dismissed. Neutral knees also remove the flexed pose's
first-order vertical adjustment sensitivity. V25 may fail standing, may not
reduce the actual entry mismatch, or may leave later walking losses unchanged.
It is a new combination to test, not a claimed fix or causal comparison.

The new optimized DLL is `c7ed66d3d2d14f772af4ed29f130647f45ff8155fe246247a10cdb4d66d3cad2`.
Build root: `SporeSpore_Evidence/development-candidate-build-3dc1b93dda8b49118b94f3932aa87436`.
All **282 core tests pass**, including pre-stance command equality across three
engine-shaped inputs and boundary clocks, native-shaped stance fixtures, bounds,
input preservation and ownership refusals. Core tests/fixture export/adapter
build take 61.391/0.297/58.140 seconds. Compiler work is reused; fresh tests run
and old pinned DLLs are untouched. No qualification evidence is reused.

All **12 actual-interface checks pass** under
`SporeSpore_Evidence/development-v25-real-interface-659c0411212b4df6b90e94e262b023eb`:
four runtime checks in 24.214 s, four actual transition checks in 13.478 s and
four prospective-selector checks in 8.182 s. The new DLL reproduces all 445
retained V23 walking commands; the original strict-memory failure still
reproduces. Tests now use the selected candidate's source-bound runtime rather
than trying to load an old compiled source graph after a new build. Original
V23 inputs, outputs, invalid closure and separate replay remain unchanged.

The first preflight, [417a25fe](../sdk/development/recovery_attempts/417a25fee80e4c618cd1a43252e7079c.json),
stopped before any physical child: 73 checks passed in preceding stages, then
three passed and one failed in the four-test schedule stage. Godot's
`unchanged_or_explicit_successor` assertion omitted V25's narrower
`new_controller_preserves_pre_stance_motion_and_limits` declaration already
handled by Python. All actual cutoff/finalizer/refusal assertions passed. The
test-only correction adds that branch; it does not change the controller,
profile, DLL, time limits, or official gate. The old failed result is preserved,
not repaired: 34 invocation files (168,681 bytes, inventory
`63388e79ed2c6646135398272c08c4478f0024c9cc0dee0489a55a6143aa5bff`)
and all four nested Godot test files are bound in its cold closure. The corrected
four-test stage passes in 32.370 seconds under
`SporeSpore_Evidence/development-v25-schedule-fix-c150780b2b8e4d5cb4ec52ea2044f0e0`,
including original-byte checks and refusal to close a physical child as zero-world.

Prospective plan, now consumed by the V25 closure above: from clean pushed source
and a fresh identity, run the **complete 103-test applicable safety
gate**, then one fresh kicked child with seed 40200, full retained telemetry,
unchanged 986-step tail and 1,338-step resource cap, 1,500-second child and
900-second reader bounds. This covers the new stance combination and any
walking reached, not guaranteed recovery, a full walking route, a paired effect,
held-out behavior or force-aware recovery. Retain every startup cycle and all
negative outcomes; no horizon extension or evaluator changes. R173, SDK1
14/20 and full-program 14/25 remain unchanged.

## V24: prospective reader integration and retained-cycle diagnosis

[V24](../sdk/development/recovery_candidates/v24-prospective-transition-reader-v1.json)
is a **zero-world reader integration**, not another physical attempt or a behavior
correction. Candidate SHA-256: `b542b091ef57296ffbc0cef402801ee4001490ccba84fc9273843254b2cff1d2`.
Its schedule preserves V23's exact motion, DLL, seed/role bounds, native contacts,
walking entry and thresholds. Only its explicit prospective replay selection is
new. The [prospective contract](../sdk/development/recovery_prospective_walking_replay_contract_v1.json)
binds the previously tested pure adapter operation and separate diagnostic; it
does not reuse V23's failed replay or its consumed identity.

The normal candidate reader now selects that operation only for an opted-in
schedule. The Python process receipt binds the selected memory profile, even if
recovery ends before walking and there are zero walking commands/transitions.
Crossed post-exposure/prospective selections, missing receipt selection, unknown
profiles, wrong entry modes and dependency drift fail closed. Old candidates
retain strict memory continuity. The valid-result closure resolves the selected
entry contract from the frozen Git tree and binds the transition contracts and
reader. V22's original complete closure still reproduces exactly.

The launcher adds eight affected-path checks only for opted-in profiles, making
their applicable smoke gate **103 tests**. This checkpoint runs 39 targeted/cold
checks, not a full physical safety gate or official qualification:

| Retained test root under `SporeSpore_Evidence` | Checks | Result |
| --- | ---: | --- |
| `development-v24-reader-integration-badd787cbc20443e8c4b5031cc70bee9` | 21 | Actual selectors, adapter transition/corruptions, launcher and normal reader/process path pass. |
| `development-v24-cold-preservation-667c3d17811a4f1a849c7cfc7316fefb` | 14 | Cycle description, original V23, separate diagnostic and schedule preservation pass. |
| `development-v24-v22-preservation-cf8a370f9c284525a6db2c5b47a750f6` | 4 | Original V22 closure and evidence reproduce. |

No physical world, native physics read, solver step or DLL build runs. New
hash-bound text files and reused dependencies verified to have identical LF Git
and checkout bytes are pinned to LF; no historical content is normalized.

The [reproducible retained-cycle description](../sdk/development/recovery_v23_retained_walking_cycle_diagnosis_v1.json)
has SHA-256 `07f935291b1304b1ff07d26639738d3d2ee76c2e7ffa7c4e336d914885d92408`.
It lists every counted cycle and reproduces V23's original per-limb counts and
minimum forward distances from the same 445 trace rows. **13 of 19 cycles miss
the original 12 mm relocation requirement**; eleven misses occur during the
amplitude ramp and two occur entirely at full amplitude:

| Limb | Local release → return | Steps without native distal contact | Forward displacement |
| --- | --- | ---: | ---: |
| Front left | 414 → 417 | 3 | 3.143 mm |
| Rear left | 396 → 404 | 8 | 1.479 mm |

These distances are travel of the distal rigid-body origins along the original
fixed forward axis, **not measured sole/contact-point travel**. The raw native
records contain no distal contact samples during either interval; these two
misses are not merely zero-impulse or nonfoot classification. At the diagnostic
cutoff only front-left and rear-right support are present. Front-right and
rear-left observed nonbearing intervals remain open for 32 and 27 steps.

Inference, not a causal finding: the failures are not all warmup-only or contact
filtering. Extending the same run cannot undo previously failed completed cycles.
The physical cause of those support losses is not established. No warmup samples
are removed, no thresholds relaxed and no original result regraded; V23 stays
originally independent-replay-invalid despite the separate successful replay.

Finite next work: inspect the two full-amplitude stance-contact losses against
actual commanded/measured joint trajectories and the production startup handoff;
then select one distinct bounded handoff correction and its smallest adequate
native diagnostic. Do not spend a physical attempt solely repeating the already
replayed reader transition. Full Godot route completion and later cross-engine
validation remain separate outstanding work. R173 and readiness remain
**14/20 SDK1, 14/25 full program**; no support or release claim changes.

## Post-V23: separate adapter-transition replay passes

[Diagnostic 89d773c5108647efb2b66283db69ee49](../sdk/development/recovery_attempts/89d773c5108647efb2b66283db69ee49.json)
is a distinct post-exposure retained-data result, **not a repaired or promoted
V23 attempt**. Its record SHA-256 is
`b70ee2f62b9dece34645b8ee2ce50ef7dd654e11808b9ebd5454566942c4f4d8`.
The original V23 report SHA-256 remains `334f447d…2c6a7c2`; its original invalid
closure remains `e1fe7401…21fd4f8`, including the failed reader and supervisor.

The [explicit transition contract](../sdk/development/recovery_walking_memory_transition_contract_v1.json)
binds the exact production adapter source `1a417867…be91d1b` from V23's freeze.
The successor constructs only an adapter object, copies the previous native
output memory into it, and calls `_configure_phase_progression_mode` before
comparing the **whole** expected memory against the next retained request.
It does not mask endpoint fields, reset clocks, reconstruct a physical world,
or change the worker's recorded commands. The old reader's default is strict;
the successor requires an explicit profile and separate post-exposure directory.
Unknown/crossed profiles and changed adapter source are refused.

Four targeted checks pass in 15.469 s under
`development-transition-reader-integration-a77ef84205214f168a700e342297215f`.
They use V23's real retained boundary, exercise the actual adapter at steps
359–362, reject nine memory/boundary corruptions, replay all 445 walking commands
through the successor and reproduce the original reader's exact failure.
Six existing walking-entry checks and eight shared candidate-reader checks
also pass in 24.988/74.054 s under
`development-transition-reader-regression-86e4a2fe31c3423eb6240921f04bdea1`.

The full diagnostic completes in **205.907 s (3 min 26 s)** under
`SporeSpore_Evidence/development-passive-entry-post-exposure-replay-89d773c5108647efb2b66283db69ee49`:

- All 1,258 timeline transitions replay from initialization through the cutoff.
- All 119 passive-entry and 422 canonical observations, plus one canonical
  initialization, validate through the existing independent consumer.
- All 475 native contact records, 30 prefix commands and 445 resumed commands
  validate; exactly one adapter mode transition is reproduced.
- Zero worlds, native physics reads or solver steps run. No DLL rebuild occurs.
- The original two walking negatives and fixed evaluator thresholds remain
  unchanged; this is not a full route, acceptance, causal or equivalence claim.

The four diagnostic files total **102,561 bytes**. Inventory SHA-256:
`1190f4d37313009660ddd15134d9a68dc244a9d93fb8e51f754fb53b21a99e38`.
Execution SHA-256: `2e220c64…0005308`; exact owned source snapshot SHA-256:
`7024c09d…e93ba4d`. That snapshot binds parent `a1604a98` plus the exact reader
edits and stays unchanged during replay. Reader process 185564 exits zero.
Four cold diagnostic checks and four original-V23 preservation checks pass in
8.117/13.504 s under `development-transition-cold-checkpoint-818cef3cd0fb4f439ab232dbacb6154d`.

Finite next work: integrate this tested transition into a distinct prospective
candidate's reader selection and applicable safety gate; update the valid-result
closure helper to bind the new entry selector; inspect the remaining foot-cycle
relocation and terminal-support failures from retained data. Do not censor or
regrade V23. Select more physics only after the next bounded question is clear.
R173 and SDK1/full readiness remain **14/20 and 14/25**.

## V23 closure: provisional walking progress, original replay invalid

[V23's immutable invalid closure](../sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json)
binds clean pushed `50f19c4edc2f16b84f0c87cd985f1115001e3b95` and
**54 files/1,000,179,864 bytes** under
`SporeSpore_Evidence/development-recovery-smoke-92dd4a7de9124bd6bde70dd7a9042843`.
Inventory SHA-256: `cc53c1ad3db5c324255cf96a8b09a28dd3fcce0688856080f8f31fb669aaa4e0`.
Original report: 268,017,122 bytes, SHA-256
`334f447d01b1ac258d90a5d604576ffe6a92d3142842d5e72de7c96e92c6a7c2`.
All 95 safety checks pass and the native child exits zero after 1,258 steps,
with passing engine health and zero stderr. **The original independent replay
fails**, and no independent supervisor audit is completed. This is not a
validated route or an acceptance result.

The report records the same phase timings as V22: support 403–408, body raise
409–625, stance handoff 626, stable standing through 813, then 445 walking steps
814–1258. No body replacement, transform/velocity write or solver reset occurs.
The walking commands contain 360 clocked samples followed by 85 contact-gated
samples. The following are descriptive report measurements, not a matched
causal comparison; **V23's column remains provisional because its replay failed**.

| Walking measurement | V22, replay validated | V23, report only |
| --- | --- | --- |
| Forward travel | 1.39 cm | 16.96 cm |
| Sideways drift | 16.81 cm | 0.128 cm, about 1.3 mm |
| Maximum body tilt | 0.6060 rad, above the 0.6 limit | 0.1796 rad, below the same limit |
| Contact cycles FL / FR / RL / RR | 1 / 7 / 5 / 2 | 4 / 6 / 7 / 2 |
| Negative walking checks | Six | Two |

The two remaining report negatives are unchanged requirements: every completed
foot cycle must relocate at least 0.012 m forward, and four feet must support
at the terminal cutoff. Minimum recorded relocation by leg is FL 0.003143 m,
FR −0.002618 m, RL −0.006669 m, RR 0.022500 m. Do not censor startup cycles,
relax the rule, or regrade the consumed result in response to those values.

The original reader returns `DEVELOPMENT_WALKING_ENTRY_READER_MEMORY_CHAIN`.
Read-only comparison finds exactly one adjacent-memory difference, at local
361/global 1174. The frozen production adapter's
`_configure_phase_progression_mode` changes each `evidence_gait_step_limit`
from 1680 to `599 + 1 + 4 * 360 = 2040` when switching from clocked to
contact-gated. Gait clocks, counters, steering and all other memory remain
unchanged. The next native output clocks are 600. This is the existing
adapter's planned-endpoint operation, not an observed gait-clock reset.
The V23 pure-native 450-command test bypassed that adapter operation; its
sampler capture stub checked arguments without executing mode configuration.
The reader's literal whole-memory continuity rule therefore omitted a real
production transition. This diagnosis has not independently executed the
adapter transition or validated the complete native sequence.

Keep the original failed replay and supervisor immutable. Next build a
**separate zero-world successor diagnostic** that invokes the actual adapter
transition, checks every other memory field exactly, rejects crossed/extra
transitions, and replays retained V23 data into a fresh evidence directory.
Its results must never replace or promote the original invalid attempt.
The post-processing closure helper also needs explicit support for the new
entry selector before a future successful candidate closure; the old valid
closure branch currently binds the old entry selector only. No new physics,
controller, threshold, horizon or force-aware work is selected at this boundary.

Observed time: safety 486.276 s, child 538.511 s, failed replay 16.969 s,
whole invocation 1,151.845 s (19 min 12 s). The abbreviated failed replay means
this is not a valid end-to-end speed comparison with V22. Four cold V23 checks
and four V22 preservation checks pass in 14.446/28.894 s under
`development-v23-cold-closure-7ee1b297435b44e4b73ae47bff8ee6eb`.
Owned console 106284, engine 199052 and reader 208264 have exited. R173 is exact;
SDK1/full readiness remains **14/20 and 14/25**, with no score promotion.

## V23 prospective: clocked walking warmup

[V23 profile](../sdk/development/recovery_candidates/v23-clocked-walking-warmup-v1.json)
selects a development command schedule, not a new controller or success rule.
Its SHA-256 is `0a4ca70b3a48fc798e777384bf835c9d733ff8fe8f3bb9ffaddd3a4fda180e74`;
the [schedule](../sdk/development/recovery_schedules/v23-clocked-walking-warmup-v1.json)
SHA-256 is `c23bd76fd08b8b9a1216a7e99161131740c5f5c23d0cf8302d4ed3cdbd948816`.
The [new entry contract](../sdk/development/recovery_clocked_walking_entry_contract_v1.json)
preserves the old ramp/retention contract and its historical selector unchanged.

Read-only diagnosis verified V22's original report digest before projecting
its actual 445 walking requests and post-step observations. The first target
jump settles while the body stays nearly level: tilt at walking local steps
61 and 121 is 0 and about 0.00242 rad. The larger tilt develops later. At local
391 the front-left leg waits for recontact; at 421 its current hold is 35 steps,
and at 445 it is 59. The gait clocks then remain rear-left 606, front-left 594,
rear-right 606, front-right 606. The other legs are held by the existing
12-step phase-skew limit; native timeout counters remain zero. These are
observed command states, not proof that holds caused the fall or sideways drift.

The normal production walker uses clocked progression before its evidence
window. The recovery bridge previously copied its amplitude ramp but explicitly
kept contact gating from the first command. V23 tests that bounded difference:

- Walking prefix, kick, recovery and standing remain unchanged.
- Resumed local steps 1–360 use clocked progression and the same amplitude ramp.
- Local step 361 onward uses contact gating and the continuous native memory.
- Keep seed 40200, initial gait clocks 240, native foot-support inputs, anatomical
  resume frame, frozen BW5R-B policy and exact V22 DLL `46bf61bd…567b077`.
- Keep all V22 resource limits: 986 post-interaction steps, maximum 1,338 per
  child, one fresh kicked child, no cached or matched baseline. Keep full
  diagnostic retention, existing reader and unchanged success thresholds.

This is not the normal launcher's whole startup: its separate 112-step evidence
alignment and initial phase choice are not copied. No pose blend, new motor
control, force-aware recovery, native read, rebuild or acceptance claim is added.
Earlier recovery failure can leave this new path unexercised; the finite horizon
does not guarantee full walking completion or two cycles per leg.

Six focused checks pass in **26.474 s** under
`SporeSpore_Evidence/development-v23-entry-integration-71f19faa5f0445908692db8d749718df`.
They exercise the worker selector, actual facade sampler argument boundary,
450 pure native commands across the mode switch, unchanged historical/prefix
modes, retained request/output/motor links and an independent reader rejecting
11 corruptions, including a wrong phase mode. The synthetic contact/body inputs
are not native physical observations. No world or solver step runs in this tier.
The first test-only integration failure is retained under
`development-v23-entry-integration-58dfd792d8c6433e8a56af70e34fb459` and
`development-walking-entry-494b651ec43b4cf8843096b7cddf6d66`: its sampler stub
did not inherit the required adapter type; the corrected stub does. No physical
attempt was consumed by that parse error.

Next run the complete 95-check safety gate and a fresh single-kick diagnostic
from the pushed source boundary. V22 remains closed and negative for walking;
R173 is exact, and SDK1/full readiness remains **14/20 and 14/25**.

## V22 closure: support and standing complete, walking remains negative

The [V22 closure](../sdk/development/recovery_attempts/51f490ed6eac47c4afc1b9b691103d83.json)
binds clean pushed `3b53ce2f8a612e2ecfb88c5fd7d9932fafce33c4` and all
**55 files/1,000,097,343 bytes** under
`SporeSpore_Evidence/development-recovery-smoke-51f490ed6eac47c4afc1b9b691103d83`.
Inventory SHA-256: `86d8130c969e73db47f8e9255b8c79b663ac1d56d948e86a30611603ef46dbc4`.
The 267,980,797-byte original report SHA-256 is
`9022960086c6051ebf1176650aec22d0dfef0a660ce3ae5cf8ac3f53a7f5c503`.
All **95 safety checks pass**; the child exits zero, the original independent
reader validates all 1,258 transitions, and the supervisor passes. Diagnostic
coverage is complete at the declared cutoff, not a full official route proof.

The same creature receives the kick at 272, reaches measured prone handoff at
391, and progresses through the following observed phases:

| Part of the recovery | Native solver steps | Result under the unchanged rules |
| --- | --- | --- |
| Establish foot support | 403–408; six active steps | Four-foot support gate reached at 408 |
| Raise the body | 409–625; 217 steps | Raised-body gate reached |
| Transfer to standing controller | 626 | Exclusive stance ownership verified |
| Settle into standing | 627–813; 187 steps | Required final 60 consecutive stable samples completed |
| Resume walking | 814–1258; 445 steps | Complete retained diagnostic, but six walking checks negative |

No body rebuild, solver reset, transform write or velocity write occurs.
The replay validates 119 passive-entry and 422 canonical observations, all
**30 prefix and 445 resumed commands**, and **475 native walking-contact records**.
Every one of the 1,900 controller foot-support flags agrees with the preceding
native observation. Native contact-gate timeout totals are zero in both sessions.
The native-input bridge is now exercised after standing as well as before the
kick; it is not being credited with a causal explanation of the motion.

The resumed-walking result remains explicitly negative:

| Existing requirement | Observed result |
| --- | --- |
| Tilt no greater than 0.6 rad | Peak 0.606045 rad; first exceedance at step 1258 |
| Every leg's completed cycles relocate forward | Front-right and rear-left minimum relocation is negative |
| At least two observed contact cycles for each leg | Front-left 1, front-right 7, rear-left 5, rear-right 2 |
| Evidence forward advance at least 0.02 m | 0.0139335 m (about 1.39 cm) |
| Final forward advance at least 0.02 m | The same 0.0139335 m misses this separate fixed receipt |
| Four supporting feet at termination | Not met |

Other retained context: lateral drift 0.168095 m, minimum torso height
0.345706 m, zero torso-contact samples and zero all-feet-off samples in the
resumed walk. Amplitude starts at zero at 814, reaches full amplitude at 1174,
and retains 85 full-amplitude samples. The first command has a maximum joint
target jump of 0.252444 rad despite zero gait amplitude. This is a diagnostic
lead, not proof that the jump caused the late tilt or limited forward motion.
The finite horizon does not guarantee two complete cycles for every limb.
Do not extend/regrade this consumed run or relax any of its six negative checks.

Elapsed times: safety **576.077 s**, native child **655.571 s**, independent
replay **242.922 s**, whole invocation **1,612.464 s (26 min 52 s)**. These are
observed workflow timings, not a controlled comparison with V21's shorter run.
Four new cold closure checks and four V21 preservation checks pass under
`development-v22-cold-closure-aaa46763f0104989afd6a89af5d65b0b`
(33.179/17.731 s). Both earlier V22 zero-world failures remain preserved.
The owned console, engine and replay processes have exited. R173 remains exact;
SDK1/full readiness stays **14/20 and 14/25**, with zero invalid proofs.

Finite next blocker: inspect the actual standing-to-walking command transition,
contact-cycle development and later lateral/tilt trajectory, then select the
smallest justified prospective correction. This closure selects no new
controller, horizon or physical attempt. Successful standing in this one
development trajectory is not robustness, acceptance, cross-engine equivalence
or force-aware recovery. The overall resumed-walking result remains negative.

## V22 integration follow-up: historical test scope

Attempt [e71531726e074783ba6fdb1e0c857852](../sdk/development/recovery_attempts/e71531726e074783ba6fdb1e0c857852.json)
is closed as a zero-world safety failure from clean pushed `91d310e5`.
The first 77 tests passed; the four-test walking-frame stage had one failing
historical assertion. Its actual worker/adapter/evaluator/reader interfaces
passed. The assertion incorrectly required every selected successor to retain
core V17's identity; V22 intentionally selects V18. The same latent assumption
was found in the ramp-only test. These identity equalities now explicitly
compare the historical V17/V18 and V18/V19 profiles. Selected-profile interface,
bound, rejection and immutable-evidence checks remain in place.

Preserve all 36 attempt files/171,280 bytes and six failed-stage source files/
4,847 bytes. The stopped result remains failed with no child, world or solver
step; it is not promoted by the fix. No DLL, controller, profile, schedule or
threshold was changed. All **18 focused checks pass** under
`development-v22-walking-integration-e5b6884d50234a61a42db02e71dde480`:
retained-input/failure preservation four (1.709 s), frame four (16.256 s),
walking entry six (37.452 s), native contacts four (36.454 s). Next run the
same complete 95-check safety gate with a fresh attempt identity. R173 exact;
SDK1/full readiness unchanged at 14/20 and 14/25. No V22 physics result yet.

The next attempt [7932dc6bcc944333b7f0ec4352f772fd](../sdk/development/recovery_attempts/7932dc6bcc944333b7f0ec4352f772fd.json)
from clean pushed `d9cebdf9` passed all first 87 tests, including frame/entry.
Legacy contact-suite setup then correctly refused V20's old runtime source key:
three core files no longer match that build. The gate had explicitly routed
this suite to V20. Its successor routes every candidate suite to the selected
current runtime; the legacy test selects the old contact branch only in a
labeled synthetic in-memory fixture. No runtime-loader guard or disk profile
is changed. The early launcher test now verifies every stage's profile binding.
All 13 routing/contact checks pass under
`development-v22-gate-routing-7fc4fee648f442ce9d5c2d0e3b9812e4`
(profile five, legacy four, native four; 5.617/23.996/26.801 s). Four additional
cold checks preserve both stopped attempts and the original source/R173 under
`development-v22-stopped-preservation-aa8ac647814741a8b5c643b6cf946c05`
(1.947 s). Both stopped identities remain consumed with zero worlds/steps.
Next use a fresh identity and the complete 95-check gate, not a stale pass.

## V22 prospective: world-vertical support matching

The [V22 profile](../sdk/development/recovery_candidates/v22-world-vertical-support-v1.json)
selects new core controller V18. V21's retained step 450 has front foot-site
centers at approximately 0.0285/0.0395 m world height and rear centers at
0.1549/0.1525 m. These are ideal-hinge reconstructions, not extra native reads.
The independent native source reports positive front impulses and zero rear
impulses. Similar leg extension relative to a tilted torso is not equal reach
toward the floor. This motivates the change; it does not establish the cause
of V21's rollover or prove a solution.

V18 uses the measured torso quaternion's world-Y row and the production
descriptor-derived hip/link geometry to match ideal foot heights vertically.
It keeps the previous rearward monotone knee branch, common reachable-plane
rule, final joint destinations, 4 rad/s cap and coordinated fallback. Hip
requests stay at measured angles during matching; once within the existing
one-step readiness bound, the original coordinated support motion continues.
If the lowest current plane is unreachable within the existing destinations,
the common plane can rise: this is not an always-push-down rule. Level/yaw-only
input takes the exact old arithmetic. No force channel, new native read,
floor-height constant, dwell, phase deadline or acceptance threshold is added.

Later get-up commands remain exact; new stance identity V5 keeps V17's response,
geometry, knee destination and velocity damping parameters. One shared added
stance-contract fragment supplies the Rust/GDScript mapping. Native walking
contacts, anatomical resume frame and one-cycle amplitude ramp stay fixed.
The [schedule](../sdk/development/recovery_schedules/v22-world-vertical-support-v1.json)
keeps seed 40200, one fresh kicked child, 320-step setup cap, 30-step prefix,
one kick, 240-step passive descent cap, 986-step tail and 1,338-step total cap.
It remains non-comparative: no cached baseline or reuse of a consumed attempt.
Support/standing timeouts still leave later paths explicitly unexercised.

All **278 core tests pass**, including seven new retained-pose, projection,
fallback, preservation and public-JSON tests. The build emits six recovery and
six stance fixtures and an isolated optimized DLL under
`development-candidate-build-5885b93da2744c859a1fe221d148eaa1`.
DLL SHA-256: `46bf61bd903b152dcb0330f15b12f30c0ede02bf5456434a85f716bca567b077`.
Core/fixture/adapter stages took 57.828/0.297/52.765 seconds. Compiler artifacts
were reused, not qualification evidence. Two earlier failed zero-world builds
remain under `development-candidate-build-6183d1149e6d47ee8eb15fbbced544a5`
and `development-candidate-build-42a80857122f4066ade7c815a973f6a4`: the first
caught a test's raw binary64 descriptor-equality assumption across JSON; the
second caught its incorrect always-fixed-lowest-foot assertion at step 450.
The tests now use production canonical identity and the unchanged reachable
plane rule. Neither failure ran physics or changed an acceptance threshold.

All **12 focused checks pass** under
`development-v22-targeted-1b37f7ced0934a62bd16c5e840eb4f62`: retained source/
geometry four, real runtime four, schedule four, in 1.897/29.698/35.639 seconds.
The source test binds all four retained V21 state samples (402, 410, 430, 450)
byte-semantically to the original report and binds the exported first-step
commands through the actual DLL. The compiled requests inject only the retained
pose/joint values into explicitly synthetic adapter-shaped observations; they
are not full native request replays or cross-engine physical observations.
On step 402, the ideal foot-height spread decreases from about 15.03 mm to
9.51 mm under the first command with fixed torso pose. This is geometry, not
measured movement, native contact, load, stability or a recovery prediction.

Next run the complete **95-check** affected-path smoke safety gate and one fresh
diagnostic through the existing launcher, worker, native DLL, original reader
and supervisor. No V22 physical result exists at this prospective boundary.
Keep V21 and all older results immutable, R173 exact and SDK1/full readiness
14/20 and 14/25. No acceptance, equivalence or force-aware recovery claim.

## V21 closure: native inputs agree, support establishment rolls over

The [V21 closure](../sdk/development/recovery_attempts/0b50a7ac1bc34180ac714bf950d2510b.json)
binds clean pushed source `66883dbfc5f2dbcc1fcfd5202d7d1c9f7bef4cc3` and all
55 files/552,475,763 bytes under
`SporeSpore_Evidence/development-recovery-smoke-0b50a7ac1bc34180ac714bf950d2510b`.
Inventory SHA-256:
`2cac442ce1f6dba2c017dfaf9b6a8135e05cf2f5c336fe579db8f5fe3bdf8c96`.
The 146,831,243-byte original report SHA-256 is
`7f6efca7774ad6b417a43c970417b72bd0a12e599af182bf813fb4f99ae1b5fb`.
All **95 safety checks pass**. The native child exits zero and the original
independent reader validates 642 transitions, 251 canonical observations,
119 passive-entry observations, and all 30 native-contact records. It also
reproduces all 30 prefix commands through the unchanged V17 DLL. The supervisor
passes. No resumed commands exist: complete diagnostic coverage remains false.

The input discrepancy is resolved on the exercised prefix, not inferred from
the creature's motion. Every retained controller contact equals its original
native observation, linked to the preceding trace and unchanged body population:

| Foot | Controller says supporting weight, out of 30 | Native measurement says supporting weight | Disagreements |
| --- | --- | --- | --- |
| Front left | 3 | 3 | 0 |
| Front right | 30 | 30 | 0 |
| Rear left | 30 | 30 | 0 |
| Rear right | 10 | 10 | 0 |

Actual native gate-timeout count is zero for the prefix. V20's original 50/120
disagreements remain preserved; these different trajectories are not a matched
comparison or proof of what caused the subsequent roll-over.

The same body walks at 242–271 and receives the kick at 272. Measured prone
handoff occurs at 391, with the 12-sample confirmation including initialization.
Active support establishment occupies **403–642**, its fixed 240-sample limit.
No sample meets the existing four-foot support gate. The torso's up axis first
falls below horizontal at 514 and ends nearly inverted (`torso_up_dot`
`-0.9999999870444004`). The terminal reason is
`phase_timeout:establish_distal_support`. The run never enters body raising,
standing dwell or resumed walking. There is no body rebuild, solver reset,
transform write or velocity write. A clean execution is not recovery success.

Elapsed times: safety gate **505.704 s**, native child **320.277 s**, independent
replay **142.703 s**, whole invocation **1,035.841 s (17 min 16 s)**. This shorter
run ends earlier in the phase sequence; it is not a controlled speedup estimate.
Four V21 cold closure tests and four V20 preservation tests pass under
`development-v21-cold-closure-64c0b546af474eb59359224454268bfb`. R173 stays
byte-exact, no acceptance claim changes, and last verified readiness remains
SDK1 **14/20**, full program **14/25**, zero invalid proofs.

Finite next blocker: inspect the retained support-phase joint commands,
rotation and support loss before 514, then choose the smallest prospective
correction justified by those sources. Do not tune the standing deadline for
a run that never reached standing, revert truthful contact inputs to obtain
an old trajectory, or claim force-aware recovery. This closure selects no new
controller, horizon or physical attempt. V21 and all earlier results stay exact.

## V21 prospective: native-qualified walking contact inputs

The [V21 profile](../sdk/development/recovery_candidates/v21-native-walking-support-v1.json)
selects `recovery_native_qualified_contacts_v1`. The native recovery observer
already distinguishes the foot's lower capsule cap from the rest of the lower
leg and excludes zero-impulse contacts. The old walking adapter instead used
shape-floor contact existence. V21 copies the existing native observation's
presence, weight-bearing flag and provenance unchanged into walking commands.
It selects stability geometry from the matching cached samples that the native
receipt classified as foot contacts; the existing upward-normal rule stays.
Command N consumes observation N-1, checked against the preceding trace digest,
native clock, current body population and callback sequence. No new load
threshold or physics read is introduced. All limbs validate before binding.

The worker retains each source observation/receipt and actual controller
contacts. The independent reader links them to the preceding report trace and
replays the short prefix's native commands, in addition to the already-retained
resumed commands. Actual timeout counters remain separate from the unchanged
evaluator. Historical contact selectors retain their original behavior.

All **27 targeted zero-world checks pass**: four new native-contact tests,
four old shape-contact tests, six walking-entry tests, five profile tests and
eight complete-reader tests. The new tests use four exact retained V20 epoch
observations (380, 381, 840, 841), the actual native DLL, real adapter consumers
and worker/reader hooks, with explicitly synthetic bridge containers, controller
poses and uninserted component bodies. They do not reconstruct V20's unretained
global walking requests or establish physical performance. Seven producer
corruptions and fifteen cold-reader corruptions are rejected. Evidence roots:
`development-v21-contact-integration-5bb1eacaf800483b96146fd6fcaecd00`
and `development-v21-shared-integration-e0eae17d076e47d9bf6615758b29601b`.

Next run the complete **95-check** applicable safety gate, then one fresh
seed-40200 kicked diagnostic using the shared production launcher/worker/reader.
Keep the exact V17 DLL/controller, V18 resume frame, V19 ramp and V20 limits
(986-step tail, 1,338-step cap). No standing deadline, acceptance threshold,
baseline, comparison or causal claim changes. Correcting prefix inputs can
change the later trajectory; V20's 56-sample near miss is not a prediction that
V21 will stand. A standing timeout still leaves resumed walking unexercised.
No V21 physical result exists at this boundary. R173 remains byte-exact and
last verified readiness remains SDK1 14/20, full program 14/25.

## V20 closure: contact lookup and standing near miss

The [original V20 closure](../sdk/development/recovery_attempts/a6ee7a70d3f4412f9ade65ab44e4148c.json)
binds clean pushed source `a7f2ebdad746734d411d238e5eceaea65d29903e` and all
53 files/941,614,146 bytes in
`SporeSpore_Evidence/development-recovery-smoke-a6ee7a70d3f4412f9ade65ab44e4148c`.
Inventory SHA-256:
`4f7324eec0fd1608053d155c04cc87feb2c5a5c3a320e4acf9b57d4caba83581`.
The 248,917,783-byte report SHA-256 is
`6f07a600d793d9e35ef08a4d9fcbad5424190d97e5f440c183b6cf721a499ea5`.
All 91 safety checks pass, the native child exits zero, and the original
independent reader validates all 895 transitions, 516 canonical observations,
107 passive-entry observations and 30 walking-contact records. The supervisor
passes. There are **zero resumed walking commands**, so the full requested
diagnostic coverage remains incomplete despite a valid retained negative.

The same body executes the 30-step prefix at 242–271 and the kick at 272.
Measured prone handoff is 379; active support begins at 408. Support takes
28 samples (408–435), raising takes 219 (436–654), handoff is 655, and the
standing phase consumes its fixed 240 samples (656–895). Of those, 85 satisfy
the standing rule, but only the final **56 consecutive** samples (840–895)
remain stable. At 839, torso linear speed is 0.1074779038 m/s, above the frozen
0.100 m/s limit; it is 0.0895472811 m/s at 840. The controller therefore ends
with `phase_timeout:stance_dwell`, not success. Terminal linear speed is
0.0319038025 m/s and tilt about 0.03456 degrees, but a good final pose cannot
replace the required 60-sample history. No extra four samples are inferred,
no timeout is extended, and the consumed result is not regraded.

The new source retention separates two meanings that must not be conflated:

| Foot | Walking controller says contact / supporting weight, out of 30 | Native recovery observation says supporting weight at the same pre-command step | Support flags disagree |
| --- | --- | --- | --- |
| Front left | 30 / 30 | 3 | 27 |
| Front right | 30 / 30 | 30 | 0 |
| Rear left | 30 / 30 | 30 | 0 |
| Rear right | 30 / 30 | 7 | 23 |

The explicit shape lookup succeeds; all four cached callback sequences advance
241–270, matching the pre-command clock. But `_foot_bears_floor` asks whether
the semantic shape-floor contact key exists, and the walking request copies
that answer into both `presence` and `bears_support`. The native trace's
`contact_by_limb` comes specifically from its **load-bearing** flag, not mere
contact presence. Thus 50/120 support flags disagree. This table does not prove
the channels use equivalent criteria or that the disagreement caused the
standing timeout. Callback impulse values were not included in the new compact
contact summary; do not reconstruct them or invent a load threshold from the
observed motion. The prefix ends with zero actual native controller gate
timeouts; the new count and old evaluator label agree for that finite segment.

Eight cold checks pass: V20 closure 4 in 24.643 s, V19 preservation 4 in
25.973 s. They verify the complete retained population and original replay,
the unchanged 60/240/0.1 standing rule, exact 56-sample near miss, all contact
counts and clocks, no resumed-walking inference, no-promotion controls and R173
preservation. Artifacts:
`SporeSpore_Evidence/development-v20-cold-closure-8ecc063c80da451d8e46f77a9b1ce5ea`.
V20 stderr SHA-256:
`bdef54fb788a9154ba98a39ccdb530e61a9e2c02a7dc0150c4c0afeb06f8f30d`;
V19 stderr SHA-256:
`362308aa48eddc5ef63b6c79161246dae64c43ba342c1314865b1547d5188898`.
Whole invocation: 1,381.203 s (23 min 01 s), including 505.280 s safety gate,
485.502 s native child and 277.937 s original independent replay. No second
physical run or controller rebuild was used to close this result.

**Next finite blocker:** trace and reconcile the walking policy's contact/
support input contract with the already-available native recovery observation,
using real-interface positive and unloaded-contact negative controls. Preserve
the new shape identities and all historical semantics; select any changed
input translation only in a distinct prospective development profile. Do not
first tune standing or gait around an unresolved support-input meaning. A
successor must also expose what remains unexercised when standing times out.
No successor world is selected at this closure boundary. No acceptance,
force-aware recovery, matched effect, equivalence or score promotion is added.
R173 stays exact; last verified readiness is 14/20 and 14/25 with zero invalid
proofs. All 17 body/joint identities are retained, with no rebuild, reset,
transform write or velocity write.

## V20 prospective: explicit recovery walking-contact binding

The [V20 profile](../sdk/development/recovery_candidates/v20-bound-walking-contacts-v1.json)
and [named schedule](../sdk/development/recovery_schedules/v20-bound-walking-contacts-v1.json)
select `recovery_distal_shape_contacts_v1`. The facade checks the existing four
distal bodies, their active collision-shape metadata, floor identity and live
semantic callback availability before binding any limb dictionary. It changes
no body, shape name, transform, velocity, joint, native controller or physics
parameter. The adapter's contact-presence lookup, provenance IDs and stability
sample filter consume that same explicit shape ID. Unselected routes preserve
the historical `foot` default; old records are not reinterpreted.

The binding applies to **all walking sessions**, including the 30-step prefix.
Consequently the kick trajectory may change. This is one fresh non-comparative
development attempt, not evidence that V19's fall had a single cause. Reuse the
exact V17 controller/DLL, V18 anatomical resume frame, V19 resume-only amplitude
ramp, seed 40200 and unchanged 986-step tail/1,338-step cap. No extra seed,
baseline, longer horizon, warmup exclusion or acceptance-threshold change.

The selected worker retains every walking step's actual controller contacts,
stability contacts and already-cached semantic callback source summaries. It
adds **zero native physics reads**. The independent reader verifies their
shape identities, values, session/step digests and complete population; resumed
inputs and native limb memory are also linked to the existing independently
replayed full walking requests/outputs. Native memory is joined by limb ID,
not array position: its gait order differs from contact-observation order.
The report separately states each session's actual native gate-timeout count
and whether that count is zero. The old evaluator flag stays untouched and
is not allowed to stand in for that measured count.

Twenty-three targeted zero-world tests pass in 138.407 s: contact integration
4, unchanged entry/ramp 6, real launcher/profile 5 and independent recovery
reader 8. The contact tier uses the actual recovery shape factory, semantic
body script, three adapter consumers, candidate worker retention and native
controller, with explicitly synthetic callback samples on four uninserted
component bodies. It reproduces the old false-contact condition, verifies
correct contacts and actual absence, refuses missing/crossed identities without
partial binding, and rejects twelve serialized corruptions. This is interface
evidence, not physical support or walking evidence.

Artifacts: `SporeSpore_Evidence/development-v20-contact-integration-3d3ef18906c64ad4af2ad3d0abec1ed2`.
Contact stdout SHA-256:
`77dc42b4b7ffe4e3884d2418502f8674414404b682130a8fa9bfe2d329b2158e`;
independent recovery-reader stdout SHA-256:
`57ecea0e2b0976397f5df5f1fecc6f20952fc1e6cf3717991e160b2a3ed1e932`.
Earlier failed zero-world probes remain under the same evidence prefix with
IDs `809ac7b9eecc4f7ab843202f4cab4d59`,
`34b9695a90c747d0a2181f31e9847969` and
`fe41671aec764f44a32ea69f5aa8b696`, including original logs and source snapshots.
They caught the new diagnostic's native-memory ordering assumption, an empty
failure-path fixture index, and the test reader's use of ordinary JSON parsing
instead of the production exact decoder. None launched a physical world.

Next: clean pushed prospective source, complete applicable **91-check** safety
gate, then one fresh kicked diagnostic and its original independent reader.
Any failure prevents launch or is retained as a fresh observed negative;
never rerun V19 or silently promote the new contact semantics into official
acceptance. R173 stays exact. The last verified readiness is SDK1 14/20,
full program 14/25, M07 contradicted and zero invalid proofs.

The four cold V19 preservation tests also pass in 25.626 s and the current
readiness compiler confirms those unchanged scores with zero invalid proofs.
Artifacts: `SporeSpore_Evidence/development-v20-preservation-57f4e072af4c42f0b7ebaa1359517b55`;
preservation stderr SHA-256:
`a0aa3d1f63000fd09e2b789437f1c893894522c75774ec587eaa4f6fec2cc8ba`.

## V19 closure: walking negative exposes contact-shape mismatch

The [original V19 closure](../sdk/development/recovery_attempts/013cf8e4b52a46e89e68336d4edb3203.json)
binds clean pushed source `ae00d925899ab76fc98392c8616cff0ccdac5cd4` and all
51 files/896,274,427 bytes in
`SporeSpore_Evidence/development-recovery-smoke-013cf8e4b52a46e89e68336d4edb3203`.
Inventory SHA-256 is
`6a6d0bdeb3ec614267da8b550887b376023ad03a2f07b4c9ba9fcbf34b36ced4`;
the 238,119,075-byte native report SHA-256 is
`6e0ddb1cd4e92c9b118d4ffa0d1a31d312b672b59d6e84278b9d12c2d1a84bdc`.
All 87 safety checks, the native child, the original 1,258-transition replay
and supervisor pass. The independent reader additionally reproduces all 453
walking native-response digests and decoded commands. This validates retention
and execution, not the correctness of the controller's contact observations.

Standing completes at 805 with the unchanged 60 consecutive stable samples
746–805. The same body executes walking commands 806–1,258, including the full
360-step amplitude ramp and 93 full-amplitude commands. The initial measured
target jump is 0.2545978 rad, about 14.6 degrees. Walking remains negative:
0.515313 m backward, maximum tilt 1.728768 rad (about 99.1 degrees), and 52
torso-contact steps. Tilt first exceeds the unchanged limit at 1,173; all feet
are first absent at 1,202; torso contact starts at 1,207. All eight original
false walking conditions remain false. No early event or threshold is removed.

The new trace exposes a specific integration defect. Across **all 453 walking
commands**, every controller foot-contact presence/support field is false.
Compare that with the native trace at each command's measured step N-1:

| Foot | Controller samples saying contact, out of 453 | Time-aligned native trace contact samples | Native controller gate timeouts by the end |
| --- | --- | --- | --- |
| Front left | 0 | 335 | 0 |
| Front right | 0 | 123 | 1 |
| Rear left | 0 | 223 | 0 |
| Rear right | 0 | 413 | 1 |

These are different contact channels, not a claim that every raw contact meets
the same load-qualification rule. However, at the initial pre-command step
805 the native standing rule passes with all four feet, while all four walking
inputs say no contact. The frozen source provides the concrete mismatch:
`recovery_native_world_v1.gd::_body_shape` labels each collision shape with its
body ID (for example `rear_right_distal`); the walking adapter's controller
contact and stability-contact paths instead request/filter the literal
`foot`. `SemanticContactRigidBody.has_semantic_contact` is an exact shape-ID
lookup. Retain this evidence; do not interpret the run as a valid test of a
correctly informed contact-gated controller or as proof the ramp caused the
fall. V18's unretained walking inputs are not reconstructed or regraded.

There is also a reporting limitation: the original evaluator's
`contact_gating_completed_without_timeout` flag is true because its frozen
predicate checks summary success and step count, not the actual native timeout
counters. Those counters end at two. The closure reports both, preserves the
old flag, and expressly denies that it proves zero timeouts. No acceptance
claim may rely on that label as a substitute for the measured counter.

Four cold V19 tests pass in 26.693 s; four V18-preservation tests pass in
19.634 s. They revalidate the entire retained population, original replay,
standing continuity, complete ramp/source population, all contact counts,
frozen shape-ID code, negative motion, timeout-label limit and no-promotion
controls. Artifacts:
`SporeSpore_Evidence/development-v19-cold-closure-474d5f06a7bb4fb6acfb17f0ec0b0282`.
V19 stderr SHA-256 is
`fa467e882591160a1a4c53eec62d548598e3ba645c3a2d8bd3de6c95dce1fdaf`;
V18 diagnostic stdout remains exactly
`aeea7a9b3ba3b59f82937cc8b31aad5631f6dd7f31f0ff2406698720678fa6b6`.
Whole invocation: 1,441.955 s (24 min 02 s), including 453.435 s safety gate,
629.836 s native child and 234.281 s original replay. No controller rebuild
or second physical run was used to close this result.

**Next bounded work:** a distinct successor must explicitly bind the recovery
shape IDs through the walking controller-contact and stability/provenance
consumers, with real semantic-contact interface tests and missing/crossed-ID
refusals. Preserve native world shape identities and historical semantics;
do not tune gait around the false contact inputs. Make actual timeout counters
explicit in successor diagnostics without replacing the old evaluator/result.
No successor world is selected at this closure boundary. R173 remains exact;
readiness is 14/20 and 14/25, M07 contradicted, zero invalid proofs. No SDK1
acceptance, force-aware recovery, cross-engine or causal claim is added.

## V19 prospective gait ramp and retained walking commands

**Integration update:** the first full gate stopped before physics at
`candidate_schedule`. Its [consumed zero-world failure](../sdk/development/recovery_attempts/3be9fc86cdfb4d16b30f3617b49469ca.json)
preserves all 34 gate files/168,719 bytes plus the four-file failing schedule
probe. The profile loader recognized the named 986-step schedule, but the
finalizer consulted only the historical global schedule registry. The shared
lookup now includes the named immutable schedule files; an undeclared longer
bound still refuses. No candidate, runtime, threshold or consumed result is
rewritten, and no physical child started.

The targeted finalizer, frame, walking-entry and V18-preservation stages all
pass: 4 + 4 + 6 + 4 tests in 90.866 s, including all ten new-reader corruption
refusals. Artifacts are retained at
`SporeSpore_Evidence/development-v19-finalizer-integration-77f1661a34bd4e5aa71012dfc24c1012`.
Schedule stdout SHA-256 is
`6f23e848ed5637aa490da2830465917ad872d587ac6853a66b290e1a337abf1c`;
entry stdout SHA-256 is
`bcd833a81873a4e2966fce8ce4255a85de79ef48037d08a17495c49543e624d4`.
V18's cold diagnostic stdout remains exactly
`aeea7a9b3ba3b59f82937cc8b31aad5631f6dd7f31f0ff2406698720678fa6b6`.
Next is a fresh attempt under the complete 87-test gate, not reuse of the
stopped attempt or its source snapshot.

The standing-to-walking diagnosis now has a bounded successor:
[`v19-ramped-walking-entry-v1`](../sdk/development/recovery_candidates/v19-ramped-walking-entry-v1.json).
It keeps the exact V17 DLL/controller and V18 anatomical resume frame. Only
resumed walking adopts the normal launcher's existing one-cycle smooth
amplitude ramp; the recovery bridge retains its contact-gated phase progression.
This does **not** adopt the normal launcher's separate clocked startup schedule.
No new physical result exists at this prospective boundary.

The source audit confirms the bridge previously supplied amplitude 1 from its
first resumed command, whereas the established launcher starts at 0 and ramps
to 1 over 360 steps. A real-DLL, zero-world command probe uses V18's retained
standing joint observations and explicitly synthetic contact provenance.
Its largest initial target change is 1.36708 rad (about 78.3 degrees) at full
amplitude versus 0.254596 rad (about 14.6 degrees) at amplitude zero. This is
not an exact replay of V18's first physical walking command: that request was
not retained. Nor is the ramp pose-matched; its opening knee target is still
zero rather than the standing knee position near -0.25 rad. Physical benefit
and causal attribution remain unproved.

The [entry contract](../sdk/development/recovery_walking_entry_contract_v1.json)
adds compact retention of the actual sampled joint states, nine body poses and
twists, native outputs, motor applications, and their step links. It copies
existing samples and performs no additional native physics reads. A commanded
global step N is linked to the pre-command observation at N-1; final post-step
body orientations are not invented if there is no following sample. Historical
distal-body-origin contact-cycle measurements remain unchanged.

The independent reader recomputes each frozen walking command through the
same DLL's stateless policy API, first checking the original pre-parse native
response SHA-256, then matching the production adapter's actual post-parse
representation. It also checks the memory chain, phase clocks, amplitude,
motor requests and full-step digest links. An early interface test caught the
difference between Godot's production decoder and the exact decoder; using
the correct representation is explicit, not a numerical tolerance. Raw native
response verification remains separate and exact.

Six focused tests cover the real worker retention hooks, all 361 opening/ramp
positions, a separate-process serialized reader, corruption refusals and old
profile preservation. The first passing stage (27.628 s) is retained at
`SporeSpore_Evidence/development-v19-entry-integration-6341e467f7d641e0ba454b53ba23121f`;
stdout SHA-256 `a8908641ee72244bab60b24cfff2bd8783c2dd883826df45e0b2364d3e0d7b02`,
stderr SHA-256 `4ab934b366a9a11e5fea2858f72bb1019fcf8b4ce6c5ca2aec6b372ae088a3e0`.
That stage rejects nine corruptions; a tenth raw-response-digest corruption is
added to the complete 87-test applicable safety gate before physical launch.
These tests use synthetic body/application inputs, not a physics world or
proof of native walking behavior. Earlier failed interface attempts are kept.

The [prospective schedule](../sdk/development/recovery_schedules/v19-ramped-walking-entry-v1.json)
adds exactly the newly introduced 360-step warmup to the prior 626-step tail:
986 post-interaction steps, at most 1,338 steps in one fresh kicked child.
This covers the new ramp and preserves the earlier post-ramp diagnostic
budget. All early cycles remain in the unchanged evaluator; a failed minimum
is not erased. No baseline caching, threshold change, old-result regrading,
additional seed, official acceptance or force-aware recovery is included.
Launch is permitted only after all applicable safety checks pass from the
new source snapshot. R173 and readiness remain 14/20 and 14/25, M07
contradicted, zero invalid proofs.

## V18 closure: forward startup with three walking negatives

The [original V18 closure](../sdk/development/recovery_attempts/88d86686f4d1421286b59eb03c7d8115.json)
binds clean pushed source `6b8bda51ee3791fee96a1574db1d01eee03ae871` and all
49 files/813,463,530 bytes in
`SporeSpore_Evidence/development-recovery-smoke-88d86686f4d1421286b59eb03c7d8115`.
Inventory SHA-256 is
`07fad8cd5be1225fa26a5562d165e6bb14f8a8675b0bb1871dc55e88b000d253`.
The 214,932,272-byte native report SHA-256 is
`24956143e994127fbf071ca30c9de05bec5ec6f0204fe87412fe2e1ce681073c`.
All 81 safety checks, the original full 898-transition independent replay and
supervisor pass. No extra replay or world is used to close the observation.

| Observed part | V18 result and limit |
| --- | --- |
| Standing | Completes at 805; all 60 samples from 746–805 pass the unchanged stable-standing rule |
| Native continuity | Same body population; no rebuild, body transform/velocity rewrite or solver reset |
| Walking startup | 93 steps, 806–898, with the declared anatomical resume frame and unchanged gait phase 240 |
| Forward distance | +0.0433149 m; both unchanged 0.02 m forward-distance checks pass |
| Other motion bounds | 0.0554518 m lateral drift, 0.0678191 rad maximum tilt, no torso/floor contact |
| Walking outcome | Still behavior-negative: `every_limb_forward_relocation`, `every_limb_two_contact_cycles`, `terminal_four_contact_recovery` |
| Coverage/authority | All 626 post-interaction steps captured; short development startup only, not full walking or recovery acceptance |

The unchanged evaluator's complete observed cycle population is:

| Leg | Lift-off → touchdown (global step) | Airborne samples | Recorded reference-point forward relocation |
| --- | --- | --- | --- |
| Front left | 819 → 831 | 12 | +0.0262706 m |
| Front left | 852 → 871 | 19 | +0.00457776 m |
| Rear left | 814 → 817 | 3 | -0.00196926 m |
| Rear left | 842 → 851 | 9 | -0.0199635 m |
| Rear right | 831 → 855 | 24 | +0.0233146 m |

Front right remains airborne from 858 to the endpoint; rear left has another
open flight from 867. These are not invented completed cycles. Counts remain
FL=2, FR=0, RL=2, RR=1. The historical trace field
`foot_position_world_m_by_limb` contains distal rigid-body origins, not exact
foot-contact-site centers. That limitation is preserved; the table recomputes
the original evaluator's values rather than silently changing point semantics.

Four cold tests in `tests/test_development_v18_recovery_checkpoint.py` pass in
20.814 s. They verify the complete original population/replay, unchanged
standing and same-body handoff, the frame against the retained native
quaternion, both forward checks, all three negatives and all five completed
cycle distances; forged promotion flags are rejected. Four original V17
closure tests also pass in 21.057 s, including exact closure reproduction.
Both stages are retained at
`SporeSpore_Evidence/development-v18-cold-closure-d48e3ebbc9f748ee8f7489125ebe039d`.
V18 stdout SHA-256 is
`aeea7a9b3ba3b59f82937cc8b31aad5631f6dd7f31f0ff2406698720678fa6b6`;
stderr SHA-256 is
`0ed079dd075278192cfc02a7be1813fe50ddf4f974c31210d42d3234ce888abd`.
V17's diagnostic stdout remains exactly
`3e78ac559e1aa7c618592928dc0ee3891d8e9db6740f6755bb0156cabe24bbc6`.

Observed timing: 417.133 s safety gate, 478.801 s native child, 224.781 s
original replay and 1,223.071 s whole invocation (20 min 23 s). No controller
rebuild was required. This is not a controlled performance or superiority
comparison with V17; their resumed physics and declared measurement frames
differ, and V17 is not regraded.

**Next bounded question:** audit the standing-to-gait entry state and retained
lift-off/touchdown geometry before selecting another controller or schedule.
More elapsed steps could supply missing cycles and terminal contact, but
cannot erase an already observed too-short/backward minimum in the same
evaluation window. Do not spend a longer physical attempt merely to rediscover
that known negative. Check the existing reference-point semantics explicitly,
keep old observations/evaluators intact, and do not choose thresholds or
discard early events from the observed outcome. No V19 candidate is selected
here. R173 stays exact; readiness remains 14/20 and 14/25, M07 contradicted,
zero invalid proofs, with no held-out, cross-engine or force-aware claim.

## V18 prospective resumed-walking frame correction

The cold V17 audit finds a concrete bridge discrepancy. The normal walking
launcher in `physical_wave_gait_quadruped.gd` takes the torso's local +Z axis,
projects it onto the floor, and obtains forward from world-up crossed with
that sideways axis. The recovery bridge instead supplied local +X as sideways
and local -Z as forward. The original native quaternion at standing completion
(805) puts anatomical forward and the recorded walking task direction
`89.99999897172546` degrees apart. This verifies the mapping discrepancy, not
its causal contribution to V17's five negative walking checks. Those 93 steps
are also shorter than the declared 360-step gait cycle; they cannot establish
failure over the full walking horizon. No old evaluation is replaced.

The distinct `v18-anatomical-walking-frame-v1` candidate/schedule fixes the
frame **only at resumed walking**. It is a host-adapter candidate, not a V18
recovery controller. It binds the exact V17 controller and DLL
`18d939ca2f7c6efc1bf0f010b85a3b68dae19f4a58780e500d6c8c12809b9578`.
No Rust rebuild is needed. Setup, walking prefix, kick direction, get-up,
standing feedback/criteria, gait phase 240, motor caps and all timeouts remain
unchanged. So do the 626-step post-interaction tail and 978-step resource cap.

The new frame contract is `sdk/development/recovery_walking_frame_contract_v1.json`.
The facade uses the normal launcher's horizontal task axes and preserves the
adapter's separate legacy -Z yaw argument and canonical heading conversion.
Resumed trace heading uses the live anatomical +X direction, so control and
the unchanged evaluator agree on which way is forward. Profile selection is
bound into session and row receipts and checked by the independent report
reader. Empty selection preserves historical/default routes. Unknown frame
IDs, wrong types and applying the successor to the prefix are refused.

Four tests in `tests/test_development_recovery_walking_frame.py` pass in
15.149 s at `SporeSpore_Evidence/development-v18-frame-integration-cdb13420421347efa346dd8f8e5bf561`.
Stdout SHA-256 is
`0385124dc0c8e99815ff89b062ba9cd34f5c6089746a9c7f55dc809f70f195d8`;
stderr SHA-256 is
`abbb019b681f13d1861e1a08e49540609b64bfb767d877c1917681a90c83c25a`.
They reopen the original V17 report, preserve its negative and R173, and
exercise the real worker hook, compiled adapter session/start/shutdown and
unchanged evaluator using identity, rotated, tilted and retained native poses.
A deliberately mixed control/trace frame remains a valid heading negative;
the official evaluator still refuses the short synthetic population. There
are no constructed models, physics worlds, native physics reads or solver
steps. Additional shape guards retain fail-closed malformed-report handling.

Next run the complete applicable 81-check smoke safety gate and one fresh
single-kick child using this profile. This asks about short resumed-walking
startup only: coverage depends on actual standing completion and is not
guaranteed. It does not cover two full contact cycles, the official walking
horizon, causal comparison, held-out behavior, other engines or force-aware
recovery. Preserve the V17 mixed result and every original physical artifact.
R173, release/support matrices and readiness remain unchanged at 14/20 and
14/25 with M07 still contradicted and zero invalid proofs.

## V17 single-kick closure: standing completes, walking remains negative

The [original V17 closure](../sdk/development/recovery_attempts/5436af3ddcad48dda0f2450ce0a9dd7b.json)
binds clean pushed source `f901618632436a250eab9d3cb7aebcad22de2b10` and all
47 files/813,429,767 bytes under
`SporeSpore_Evidence/development-recovery-smoke-5436af3ddcad48dda0f2450ce0a9dd7b`.
Inventory SHA-256 is
`786f03043fa7bb51dd9cfed0416c6637c3af3a0f28d3cdb67f189f770deef62a`;
the 214,924,712-byte report SHA-256 is
`2ec328e3dac08ff9457c485e49f8a1820756117f45967d7904cc8d444004b7f7`.
The original 77 safety checks, child, full 898-transition independent reader
and supervisor pass. All 626 post-interaction steps are observed, so bounded
diagnostic coverage is complete. Official/full route authority remains false.

This is a mixed development result, not an overall behavior pass:

| Part of the observed path | Result |
| --- | --- |
| Get-up | Body lift at 627, stance handoff at 628 |
| Standing | 177 samples; 98 with all four feet sufficiently loaded, 170 raised-body passes, 68 complete stable samples |
| Required uninterrupted dwell | All 60 samples from 746 through 805 pass; recovery phase transitions to `complete` at 805, inside the unchanged 240-step stance deadline |
| Native continuity | The same 17 body/joint instances remain; no body transform/velocity rewrite, rebuild or solver reset |
| Walking handoff | Selected BW5R-B controller executes steps 806–898 and finalizes its 93-step segment |
| Walking behavior | Original evaluator is execution-valid but behavior-negative; five walking conditions fail |

At standing completion the torso tilt is 0.01850 degrees, linear speed
0.02538 m/s and angular speed 0.01703 rad/s, with every foot meeting the
unchanged load requirement. All 1,416 stance commands reproduce the declared
position-error minus half measured-velocity rule within at most
`4.688516241913021e-11` rad/s guarded-number transport difference. This
observed completion is not held-out recovery acceptance, a causal superiority
result over V16, or a three-engine claim.

The original resumed-walking evaluation reports forward advance
`-0.07224338988678158` m in the segment's frozen task frame, absolute lateral
drift `0.07719043540584979` m, and contact-cycle counts FL=3, FR=0, RL=1, RR=3.
Its five false checks are `every_limb_forward_relocation`,
`every_limb_two_contact_cycles`, `minimum_evidence_forward_translation`,
`minimum_final_forward_translation`, and `terminal_four_contact_recovery`.
The fixed forward minimum remains 0.02 m; no threshold override occurs.
The body does not touch the floor, and maximum tilt is 6.280 degrees, within
the existing tilt limit. Those passing checks do not cancel the five negatives.
Nor does a 93-step segment establish failure over the full walking horizon.

The four tests in `tests/test_development_v17_recovery_checkpoint.py` reopen
the original evidence, check the complete standing streak and command
population, verify same-body walking handoff, retain the negative walking
evaluation, reject forged claims and preserve predecessors exactly. They pass
in 21.787 s under
`SporeSpore_Evidence/development-v17-cold-closure-a4f88d74f1ed4ccf966cdf7d11f14c60`.
Diagnostic stdout SHA-256 is
`3e78ac559e1aa7c618592928dc0ee3891d8e9db6740f6755bb0156cabe24bbc6`;
stderr SHA-256 is
`b63df214b63e31b3a83fbc77fb3193477bf894304df6076401c692b7d1bd9c86`.
No extra world, native read or replay process is used for that cold closure.

Observed invocation timing is 387.876 s for the safety gate, 496.198 s for
the native child, 230.578 s for original independent replay, and 1,214.274 s
overall (20 min 14 s). Capture is complete and compilation optimized. The
different phase mix and 898-step trajectory prevent treating this as an exact
performance comparison with the earlier 868-step standing negatives.

**Next bounded question:** audit the retained resumed-walking task frame,
initial gait state and short-horizon behavior before choosing a controller or
schedule successor. Keep the established V17 standing result intact. Do not
assume a wrong forward axis, reinterpret the negative walking evaluation,
extend the consumed run, or promote its standing completion into M07/SDK1
acceptance. No V18 controller or new horizon is selected here. R173 remains
exact; readiness stays 14/20 and 14/25, M07 contradicted, zero invalid proofs.

## V17 measured-joint-velocity damping development

The cold V16 motion diagnostic in
`sdk/conformance/development_recovery_leg_geometry.py::observe_stance_motion_v16`
reopens the exact original report and recomputes all 240 standing speed
magnitudes from the retained native velocity vectors. In steps 749–808 and
809–868, the body front/rear hip axis accounts for respectively 99.2607% and
99.1987% of squared translational speed. In the last window its RMS speed is
0.0855751 m/s, versus 0.00441505 m/s world-vertical RMS. Its sample correlation
with mean hip-joint velocity is -0.990396. These correlated development samples
motivate testing motion opposition; they do not establish the cause or prove
damping, a contact mechanism, or superiority. The anatomical hip axis is body
x, not the walking policy's forward axis.

The new [V17 stance contract](../sdk/core/contracts/recovery_candidate_stance_profiles_v3.json)
preserves V16's knee/hip goals and 0.1-second relaxation. For each joint it
requests `(goal - measured_position)/0.1 - 0.5*measured_velocity`, then applies
the existing +/-0.75 rad/s clamp and guarded position-target projection.
The coefficient 0.5 is a prospective dimensionless half-strength feedback
choice, not a fitted optimum. Positive measured velocity contributes an
opposing negative term and vice versa. Valid finite native joint velocities
are required. No observation, impulse cap, standing condition, timeout,
external-force estimate or get-up command changes.

Recovery controller V17 and stance controller V4 have distinct identities.
The old stance contract files and candidate DLLs remain untouched. Rust and
GDScript consume the same new profile; existing profiles do not gain damping.
Tests cover both stance-entry/dwell paths, both velocity signs and saturation,
source/identity/velocity refusals, and unchanged three-engine get-up commands
at phase boundaries. An ideal one-step velocity-follower recurrence checks
signs, units and decay for the selected coefficient. It excludes contacts,
motor impulse saturation and native dynamics and is not a physical predictor.

Optimized build evidence is retained under
`SporeSpore_Evidence/development-candidate-build-81edf45838594e139f0521226103b85f`:
271 core tests pass in 70.562 s, fixture export in 0.281 s and adapter build
in 56.422 s. The independent 8,173,056-byte DLL SHA-256 is
`18d939ca2f7c6efc1bf0f010b85a3b68dae19f4a58780e500d6c8c12809b9578`.
The [candidate profile](../sdk/development/recovery_candidates/v17-velocity-damped-stance-v1.json)
binds that DLL and the new runtime/extension manifests. Its separate
[schedule](../sdk/development/recovery_schedules/v17-velocity-damped-stance-v1.json)
retains the previously justified 626-step post-interaction tail and 978-step
resource bound. The get-up motion equality test preserves that coverage
basis; actual fresh-process phase timing and walking completion are not assumed.

The three cold motion tests, four actual runtime/interface tests and four
schedule tests pass under
`SporeSpore_Evidence/development-v17-integration-ec9fa4020ac14c9bb7efabc2b6dac74c`.
The motion diagnostic stdout SHA-256 is
`75dbfee8771b5ead642c218e3decd45dac504ae72c612b83ccf338a7f253cfaf`;
runtime stderr SHA-256 is
`dd81dad20c1a862340db8ac60965044d8768da6a8237bd6834347e9a340a7a43`;
schedule stderr SHA-256 is
`cafb17458bbbe4e4b837a31f696839774f25aca7455f2f06fdbc69cf731aac5f`.
The real-interface test compares six nonzero-velocity stance fixtures against
the actual compiled DLL and Godot native command-applier surface with no
world insertion or solver steps; it is not fixture-only controller coverage.

Next use the complete applicable safety gate and one fresh single-kick
diagnostic to test whether standing persists and walking handoff becomes
reachable. No V17 physical world has run at this implementation boundary.
No causal effect, complete recovery path, force-aware kick recovery or new
support claim is established; R173 and readiness remain unchanged.

## V16 single-kick closure: standing interruptions remain

The [original attempt closure](../sdk/development/recovery_attempts/16d22c82f50247f3be4fd349e76407a7.json)
binds clean pushed source `7191bee367bc5882c9a6c4be8f0e2fdc2f42b478`, the
V16 profile and optimized DLL, and all 47 files/908,318,723 bytes under
`SporeSpore_Evidence/development-recovery-smoke-16d22c82f50247f3be4fd349e76407a7`.
Inventory SHA-256 is
`12fe9953603fa9e99e3624b7cf9188feda8fdf2300086f0261781f591299a20d`;
the 239,904,021-byte report SHA-256 is
`fadc72a4bc33f2a489f5f31fe24370acdf7fbe2fa2ed924a58c7d6b3e7c3cfdf`.
The original 77 safety checks, child exit, full 868-transition independent
reader and supervisor all pass. This is an execution-valid development
negative, not an infrastructure-invalid attempt or successful recovery.

The body reaches lift at step 627 and stance handoff at 628. Across the
unchanged 240-step standing budget, all four feet meet their original load
requirement in 135 samples, raised-body checks pass in 232, and complete
standing checks pass in 59. The longest consecutive standing stretch is
13 samples, not the required 60. Step 868 is itself stable (four sufficiently
loaded feet, 0.0621 degree torso tilt, 0.06712 m/s linear speed and
0.02262 rad/s angular speed), but it ends only a seven-sample streak. The
controller correctly terminates `phase_timeout:stance_dwell`; walking remains
zero. Complete diagnostic-tail coverage and complete route proof remain false.

The retained-data check counts every standing sample in four adjacent
half-second windows. Failures can overlap; these are not disjoint causes.

| Standing steps | Samples | All four feet sufficiently loaded | All standing conditions met | Linear speed above 0.1 m/s | Angular speed above 0.2 rad/s |
| --- | ---: | ---: | ---: | ---: | ---: |
| 629–688 | 60 | 5 | 0 | 60 | 56 |
| 689–748 | 60 | 44 | 15 | 45 | 11 |
| 749–808 | 60 | 37 | 18 | 30 | 1 |
| 809–868 | 60 | 49 | 26 | 23 | 1 |

No safety, ownership or no-cheat failure occurs during those 240 samples.
All 1,920 actual stance commands reproduce the declared bent-knee goal and
0.1-second measured-position relaxation, within at most
`4.688516241913021e-11` rad/s guarded-number transport difference. The native
speed and impulse caps remain unchanged. V15's six-sample streak versus
V16's thirteen is descriptive development history, not causal superiority.

The four cold tests in `tests/test_development_v16_recovery_checkpoint.py`
pass in 23.769 s under
`SporeSpore_Evidence/development-v16-cold-closure-826dae246bb046aeb550ede44da53793`.
Their diagnostic stdout SHA-256 is
`4df5f0dc7533db323a09460f4d69f111216c31c8627523937456dbc1589bf119`;
stderr SHA-256 is
`212679f422eac15f3a00dd56d3cfdb7bc4e0c201719becc2f26c6b4da33b86c0`.
The one-off wrapper subsequently failed its cleanup call by supplying `-Lock`
instead of the existing `-Receipt` parameter. That error is retained separately
in the same directory; it did not affect the completed tests or earlier
physical run. A separate check confirms a fresh, non-abandoned operation lock
can be acquired and released. Neither the tests nor physics were repeated.

| Observed elapsed time | V15, unoptimized | V16, optimized |
| --- | ---: | ---: |
| Full pre-physics safety gate | 463.549 s | 396.135 s |
| Native child process | 1,035.743 s | 477.885 s |
| Original independent replay | 569.922 s | 261.875 s |
| Whole invocation, including publication and other overhead | 2,188.859 s | 1,248.113 s |

Whole-invocation elapsed time falls from 36 min 29 s to 20 min 48 s, about
43% less in this observed pair. Both contain 868 solver steps and complete
telemetry/replay, but controller and other runtime conditions are not held
constant; this is not an isolated compiler benchmark or guaranteed speedup.

**Next bounded question:** inspect the retained body-velocity components
alongside native contact/load changes to distinguish vertical bouncing,
horizontal movement and load loss before selecting a stance-control successor.
Do not infer a mechanism from the speed magnitude alone, lengthen the observed
timeout, lower the standing requirement, or treat the final stable frame as
recovery. No V17 controller is selected here. R173 remains byte-for-byte exact;
SDK1 readiness is unchanged at 14/20, full program 14/25, M07 contradicted and
zero invalid proofs. Acceptance, same-body walking resume and force-aware
recovery are not established by this development result.

## V16 flexed under-hip stance development

The distinct candidate is
`sdk/development/recovery_candidates/v16-flexed-stance-v1.json`. V16 preserves
V15's get-up motion, 0.1-second stance relaxation, 0.75 rad/s standing motor
speed limit, actuator impulse caps, standing criteria and timeouts. It changes
only the standing goal: every knee targets -0.25 rad, with the hip angle derived
from the descriptor's link-length ratio to place the ideal foot beneath its
hip. The new stance controller is v3. Its definition is in
`sdk/core/contracts/recovery_candidate_stance_profiles_v2.json`; the original
V15/v1 contract file is preserved byte-for-byte, not rewritten to add V16.

The additional cold V15 diagnostic uses actual retained contact points, not
the historical distal-body-origin field. All 687 positive foot-contact point
samples across 240 stance steps are joined through their retained raw-to-
portable identity projections, and all 960 per-foot load sums recompute exactly.
Qualifying sample counts are front-left 188, front-right 180, rear-left 146,
rear-right 137. Across steps 800-868, the normal-impulse-weighted contact center
relative to the COM ranges from -0.19666911711206775 to 0.19495534706288933 m
along the torso's front/rear hip axis; its mean is 0.0018012482408512837 m,
with 36 positive and 33 negative samples. The final rear unloading therefore
does not demonstrate a persistent forward loading bias. This center is a
descriptive contact statistic, not proof of static equilibrium or stability.
The original V15 result and its interpretation remain unchanged.

The candidate addresses a specific ideal-geometry limitation. For link lengths
`u,l`, hip `h`, knee `k`, foot height relative to the hip is
`-u*cos(h)-l*cos(h+k)`. At the old straight goal `h=k=0`, both first-order
joint-to-height derivatives vanish. With `k=-0.25`, choose
`h=-atan2(l*sin(k), u+l*cos(k))`. The exact S169 descriptor gives hip
0.11948200043625823 rad, a nominal leg shortening of 0.002725529521188652 m,
and knee-to-height derivative -0.02177567143259285 m/rad. This restores ideal
vertical adjustment sensitivity while leaving nominal horizontal foot offset
zero. It does not prove actual native load distribution, clearance, damping,
stable standing or walking. The modest flexion is a prospective design choice,
not a fitted optimum or a changed acceptance threshold; no force feedback is
added. Its shorter distance from the handoff pose may also alter settling time,
so the next single-child test will not isolate a causal mechanism.

The optimized DLL has SHA-256
`07806c642824e27fecce92303e797c2c2de12dd12aff78becf1d0edfa9674348`.
Build evidence is under the durable evidence root at
`development-candidate-build-88ee43c126074c13859aa8354fd4da44`: all 267 core
tests pass, including V15 command preservation, independent forward-kinematic
and derivative checks, unchanged caps and crossed-identity refusals. The
explicit `--release` build passes in 67.625 s for core tests, 0.328 s for
fixtures and 56.657 s for the adapter. Existing pinned artifacts are untouched.

Under `development-v16-integration-b748a50e630d47789283b9d8eb45bfa0`, all four
actual runtime tests (24.568 s), four schedule/real-close tests (37.908 s), and
six retained geometry/negative-control tests (4.352 s) pass. The runtime test
executes the actual DLL, Godot wrapper, binding validator and uninserted native
hinge applier on six stance fixtures. Geometry stdout digest is
`e1aef27c86e0cf7a81225597c620384c3961911a424c05df97e71e0dbbbfc661`;
runtime and schedule stderr digests are respectively
`042b4d42761925dba1e3ebc42c7eeedf27d4a81ba0014aa9aaf69c42f90e6cda` and
`963b874f100d238cec3b255e06e4bc0665344b481ca31035b1ae7993566c424d`.
No physics world or solver step ran during these checks.

Next: the full applicable safety gate and one fresh non-comparative kicked
child, using the new named 626-step-tail/978-step-cap schedule and full retained
telemetry from clean pushed source. Actual phase coverage must be recomputed;
no successful standing, walking or fresh-process determinism is assumed.
V16 is implemented and integration-tested, not physically proved at this
boundary. Stable standing, same-body walking resume and official validation
remain the recovery blockers. R173, official thresholds and readiness are
unchanged.

## V15 single-kick closure: quiet body still loses rear-foot load

Attempt `e890db0576d94a2e9380186b56ac732b`, from clean pushed source
`eeeeb8182fe639f5137b6846d1dfb0a98d87eac4`, is closed as an execution-valid
development behavior negative. All 77 safety checks, the original 868-step
independent reader, native shutdown, engine-health and supervisor checks pass.
The large-log publisher now completes this actual production invocation; the
preceding publication-invalid V14 attempt remains invalid and unchanged.

The exact closure is
`sdk/development/recovery_attempts/e890db0576d94a2e9380186b56ac732b.json`.
All 47 original files/906,758,132 bytes remain under the durable evidence root
at `development-recovery-smoke-e890db0576d94a2e9380186b56ac732b`.
The 239,507,863-byte worker report has SHA-256
`00e0c39491e97def5cf6dc5c2bc84d4608c3e724262b0f5653b8ce1cd85f0468`;
the retained inventory digest is
`36f74d2e8f432d3f5f9150b73f703818e29029aec4a49453fa715168f71adc3c`.

| Observed question | Exact bounded result | Interpretation |
| --- | --- | --- |
| Did the creature get its body up? | Body-lift check at 627; stance handoff at 628. | The get-up path executes; stable standing is a separate requirement. |
| Did it stand steadily? | 240 stance steps, 629-868; 22 stable samples; longest streak 6/60. | The unchanged stance timeout expires. No completed recovery. |
| Did all feet remain sufficiently loaded? | Four-foot support in 69/240 stance samples. At 868 the front loads are 0.20020315051078796 and 0.16550733149051666 Ns; rear loads are 0.017596598714590073 and 0 Ns, below the unchanged 0.019293 Ns per-foot requirement. | Rear support still fails even with a quiet, nearly upright body. |
| Did walking resume? | 0 steps. | Full route and diagnostic-tail coverage remain false; observing the full stance budget does not cover the unexecuted walking path. |

At the final sample torso tilt is 0.08660774992605982 degrees, linear speed
0.0320072867577454 m/s and angular speed 0.01748762815952834 rad/s. Both speed
checks pass. Across stance, support fails 171 times and the raised-body check
22 times; safety, exclusive ownership and no-cheat checks never fail.
All 1,920 applied stance motor requests agree with the V15 measured-position
smoothing rule, within its existing decimal-transport precision. This rules
out merely retaining the old command rule; it does not establish a causal
improvement over V14. These are separate development traces, not a superiority
experiment. The next question is supported foot placement and weight
distribution during the raising-to-standing transition, using retained pose,
native load and command observations before selecting a distinct successor.
Do not substitute distal-body origins for actual contact-site geometry.
Do not extend this consumed run, relax the standing gates or infer force-aware
recovery. No V16 controller is selected at this closure.

Whole invocation: 2,188.859 s (36 min 29 s); safety gate 463.549 s, native child
1,035.743 s, independent replay 569.922 s. V15 was accidentally built in the
helper's unoptimized default, whereas V14 used `--release`. The V15 artifact
and result remain exact. The helper's real CLI now defaults to optimized
compilation; explicit debug remains available and low-level historical callers
keep their original behavior. Optimization does not grant release authority,
reuse qualification, overwrite pinned DLLs or establish cross-build behavioral
equivalence. Future physical candidates must use their own freshly bound
optimized artifact; no rerun solely to make this timing look better is selected.

Four cold closure/negative-control tests pass in 22.147 s, and six build-mode
and independent-copy tests pass in 0.369 s, under
`development-v15-cold-closure-ebca1aede347471b8fffced37958773d`. Closure stderr
digest is `b309c8ea7009fae828618a388cb849490143742c3aad069a48e98385a08f0bf3`;
build-test stderr digest is
`b01b27787548b3eafec9b624afbdc3a70aa0d53360618e0aff4892aac8589979`.
The first cold-test run, retained under
`development-v15-cold-closure-bedddafd545942f890e392d81974ac27`, caught an
incorrect test expectation that the longer diagnostic tail had completed;
the observed record was not altered. R173, official gates and readiness remain
unchanged. Stable standing, same-body walking resume and official prospective
validation remain the finite recovery blockers.

## V15 measured-position stance relaxation

The distinct development candidate is
`sdk/development/recovery_candidates/v15-smooth-stance-v1.json`. It preserves
V14's fold, replant and rise commands and changes only the selected stance
controller from v1 to v2. The shared, compiled Rust/Godot mapping is
`sdk/core/contracts/recovery_candidate_stance_profiles_v1.json`.

The retained V14 report (SHA-256
`9031e168d95d4129a1272b7e921f9a81e2513c45a78ac74d6267a5eedad76474`)
shows why settling is the next question. Among 240 stance samples, four-foot
support fails 183 times and raised-body checks fail 23 times; safety, exclusive
ownership and no-cheat checks never fail. Stable streaks break at steps 751,
775, 791, 811, 816 and 831 through support loss and/or excess body speed.
Across steps 800-868, maximum absolute joint position is only
0.025117002427577972 rad (about 1.44 degrees), but maximum measured joint speed
is 1.875051498413086 rad/s. Near-target joints do not establish body stability.
All 1,920 applied stance commands match the preceding measured position's
zero-target error divided by 1/120 second, capped at 0.75 rad/s.

V15 tests a specific hypothesis: sharp near-goal motor corrections may impede
settling. For each measured joint position `q`, stance v2 asks for
`q + dt * clamp((0 - q) / 0.1, -0.75, 0.75)`. The existing native applier then
converts that target to motor velocity. The final zero-joint goal, 0.75 rad/s
speed cap, actuator impulse caps, 60-sample standing requirement and 240-step
stance timeout are unchanged. The 0.1-second response time is a prospective
development design choice, not a fitted optimum, acceptance threshold or
proven causal explanation. There is no force-feedback recovery.

The independently pinned V15 DLL has SHA-256
`bbc689a801ffdc613a9725b74f1a6789e4a34df60bfbdd2d593b3b3d83fc4250`.
Build evidence is under the durable evidence root at
`development-candidate-build-3cb3bd9f16b34b82ae4e8e9c4c1dcbad`:
263 core tests pass, including exact V14 recovery-command preservation across
three engine-shaped inputs and boundary clocks. Six recovery and six stance
fixtures are exported by the tested core. Two preceding failed build roots
(`f7668d9cac30461aaa7685054855229b` and
`05f1b4e40e3c4045ad4d749d39744d33`, with the same build-root prefix) remain
retained: a test integer-type mismatch and a test that omitted the established
thirteen-significant-digit transport rounding. Neither published a DLL.

Eight real-interface/schedule tests pass under
`development-v15-integration-badcdf54f7214be9bd4941740face096` (runtime
22.136 s, schedule 39.685 s). They exercise the actual DLL, Godot wrapper,
observation-binding validator, eight uninserted native hinges, ownership
propagation, crossed-controller refusal before writes, and the production
walking close. Runtime/schedule stderr digests are respectively
`71fa8914c1a8f0503c64a9e05de99e4e5abbcec84b60849800c5d2f9bc84ca04` and
`18dcb1c1a958a210e179314a7f04892f71f939ec46d38b7a24adc58a59595de3`.
Four cold V14 closure/diagnosis tests pass in 6.315 s under
`development-v15-retained-diagnosis-df728ea8256c49a2b84b07456b6d4c67`;
diagnostic stdout digest is
`d09d62db177837f7e971af12e3907f95aacf914c779e6bbd35a9385f05710e9b`.
No physics world or solver step ran during these checks.

The new named schedule lives in
`sdk/development/recovery_schedules/v15-smooth-stance-v1.json`, with the already
coverage-justified 626-step tail and 978-step resource cap. Resolution is by
safe schedule ID and exact digest; historical profiles still bind the original
unchanged schedule file. Cold closures resolve the file in the frozen Git tree.
This avoids shortening the next observation below the known settling interval
without extending the controller's own budget or assuming fresh-process
determinism. Next: the full applicable gate, then one fresh non-comparative
kicked child from clean pushed source using this profile. Preserve and close
the result even if negative. Remaining blockers are stable standing, same-body
walking resume, and official prospective validation. R173 and SDK readiness
stay unchanged; V15 is implemented and integration-tested, not physically
proved at this boundary.

## V14 remaining stance budget and large-log publication

Attempt `f3761195cea64b7c9b58a34f04651173`, from clean pushed
`c98466e12aafeb218fcd4f938e8342e52d3ba864`, passed all 77 development safety checks.
The child produced a terminal report, but publication failed while wrapping its
182,106,256-byte stdout as one JSON string: the host's single-string writer
rejected that size. The original supervisor is false, with no child envelope or
independent audit published. Its [immutable failure closure](../sdk/development/recovery_attempts/f3761195cea64b7c9b58a34f04651173.json)
binds all 38 original files/182,301,540 bytes. Invocation time through failure:
877.245 seconds. Missing termination metadata is not synthesized afterward.

`sdk/conformance/development_recovery_stdout_diagnostic.py` checks original
attempt/source/profile identities and copies the exact terminal JSON token into
a distinct create-only diagnostic population. It does not edit the original
attempt, reconstruct missing publication receipts or rerun physics. The six
files/182,119,987 bytes under
`development-recovery-raw-stdout-diagnostic-b4d0a65857674973be837db0ccb42ec6` include
the extracted report, source snapshot and original new replay receipt. All 868
transitions pass the existing reader in 258.437 seconds, with zero new worlds,
native physics reads or solver steps. The original attempt remains invalid.
The original stdout SHA-256 is
`108a1ba034c848db8015446c547af362f54635c6d47ed5d01e7342b1ee79a7e1`;
the exact extracted report is
`9031e168d95d4129a1272b7e921f9a81e2513c45a78ac74d6267a5eedad76474`.

The captured trajectory supplies the missing observation, without acceptance:

| Question | Captured result | Meaning |
| --- | --- | --- |
| Did the remaining stance interval execute? | Steps 629-868, all 240 allowed stance steps | The prior 124-step observation was not the whole stance budget. |
| Did four feet carry the required load? | 57 of 240 stance samples | Load support appeared intermittently, not continuously. |
| Did all stable-standing checks pass together? | 16 samples; longest consecutive streak 5 at 770-774 | The unchanged requirement is 60 consecutive samples; recovery did not complete. |
| Was the body upright at the endpoint? | Tilt 0.230 degrees; only two feet met the load requirement | Upright appearance alone is not stable standing. |
| Did walking resume? | 0 steps; `phase_timeout:stance_dwell` at 868 | The next controller question is settling/support, not a longer observation window. |

The publication fix uses bounded string segments on hosts exposing
`Utf8JsonWriter.WriteStringValueSegment`, verified on the installed .NET 10 host.
The [documented API](https://learn.microsoft.com/en-us/dotnet/api/system.text.json.utf8jsonwriter.writestringvaluesegment?view=net-10.0)
escapes each segment as part of one string. Whole-string surrogate validation,
numeric type/bit preservation, depth refusal and create-only file semantics
remain unchanged. Older hosts retain their existing small-string behavior;
large-output support on those hosts is not claimed. No telemetry is dropped,
and no original file is rewritten.

Five real-host tests pass under
`development-large-stdout-publication-1db82daa1ac548ff99e89870e25d6008`, including
the actual 182 MB log through the production writer and its exact decoded hash,
Unicode across a segment boundary, legacy floats and malformed-value refusals.
Stderr SHA-256:
`99d357aedc29b08a9bb6371713c18023bb828802b6f3f333890560977402ccce`.
Three cold closure and eight downstream publication tests pass under
`development-v14-settling-cold-closure-2f4ccfaeb01c4b3f9f62f13da841933f`.
Their stderr SHA-256 values are
`330fabc7fffe8903ac4a07b00a4861e10830d4ca21b25c78ce02ecafe548211d` /
`4f9a793905d6bf72fe723b4b5cb201c7a6d706b9fc44a98fea4c8a4d9d2820ce`;
all three stdout logs are empty. These are zero-world fixes/audits, not original
physical commissioning of the repaired publisher.

Next inspect the retained loss-of-stability boundaries and actual commanded
versus observed joint motion before a distinct controller successor. Do not
repeat a longer V14 run, change the 60-sample criterion or extend the 240-step
controller timeout. No new controller, physical attempt or SDK point is selected
by this closure. R173 and readiness remain unchanged at 14/20 and 14/25.

## V14 distinct stance-settling schedule

`sdk/development/recovery_candidates/v14-stance-settling-v1.json` is a new
prospective development profile, not a replacement for the consumed V14 run.
Its V2 schema adds a named schedule and the exact digest of
`sdk/development_recovery_candidate_schedules_v1.json`. That single JSON source
supplies the limits to Python selection, PowerShell declaration, native worker
and independent reader. V1 profiles retain their strict old keys and 480/832
limits. The shared worker/reader remain in use; no candidate copy, Rust change,
DLL build or old artifact overwrite is required.

Coverage derives from the original V14 observation: the 480-step tail contains
124 stance-phase steps, while the unchanged stance timeout is 240. Add the 116
unobserved stance-budget steps and a 30-step walking probe: `480 + 116 + 30 = 626`.
The existing setup/prefix allowance gives `320 + 30 + 2 + 626 = 978` maximum
solver steps. This is development-only observation budgeting, not an extension
of the controller timeout or a prediction of success. Fresh-process timing may
differ: the closure must state which phase coverage actually occurred. It must
not infer recovery, 30 walking steps or whole-route commissioning from merely
reaching the declared cutoff. Full official walking coverage remains excluded.

Focused checks under
`development-v14-settling-integration-a572ad3945804e47b0485ade708d09c2` pass 4/4
schedule and 5/5 profile tests. They bind the original result and unchanged
timeout, retain the exact DLL, test real configure/cutoff/retention/walking-close
bound hooks, reject crossed limits and legacy-profile extension, and reopen the
original V14 population without another replay or world. Schedule stdout/stderr
SHA-256 values are
`f405a3e8307ada0c50e8e3d48326026f36c04208dce06079762976cd62046eec` /
`ba0c5211b11bdf16da46af0850b996032c51af009702ee3c9ec9da142072c5e3`;
profile stdout/stderr are
`39d5d2d343f17ddca44e4dbacbba183c52b5112e2ff2f8bedf5659f8d941fdce` /
`bb3f89e7825fedd52997395f3fb220b39a078e5ca544ce9a5fa57b515e0c266e`.

The prospective full gate has 77 checks: existing 73 plus the four schedule
checks. The shared reader suite adds two crossed-tail negatives and explicit
real-command producer/reader checks at 832, 833, 978 and 979; these must pass
before the fresh physical child. The old default reader bound remains 832.
The changed layer is only development scheduling and its exact consumption;
official qualification, evaluation, ownership and physics inputs are unchanged.

First gate attempt `f870f80d6bf94943b310549d5b2624e2` is closed as a zero-world
reader-gate failure, with no child launched. Its [retained failure record](../sdk/development/recovery_attempts/f870f80d6bf94943b310549d5b2624e2.json)
binds all 32 gate files/172,361 bytes and the separate reader-fixture population.
Godot JSON parsing left integral schedule counts as binary64; the worker emitted
integer counts and the exact reader refused the crossed representation. The
loader now explicitly projects already-validated whole counts into the integer
protocol. It does not rewrite observations or alter the schedule/controller.
Eight focused reader tests pass under
`development-v14-settling-reader-fix-026537b33cd64ab2a87eef594901057b`, including
36 negative cases and real producer/reader checks at 832, 833, 978 and 979.
Original stdout/stderr SHA-256 are
`0c80133a6f4c41e923980f20a15020a54064137ab39e90794dc847fa8dcf628c` /
`ab93ac502ff47a71a3199c0560a623416a5b46f99ca4298fdb0bd3b7f13d864c`.
The next invocation requires a fresh identity and the full 77-check gate.

The next attempt, `4337cdb9c34d4661881a56b6a20175e7`, passed all 77 safety checks
but is [closed infrastructure-invalid](../sdk/development/recovery_attempts/4337cdb9c34d4661881a56b6a20175e7.json).
One world completed 271 steps and no kick. The 30-step prefix completed and its
SDK session shut down, but the diagnostic evaluator's separate 30/60/480 bound
list rejected the declared 626 maximum. Termination, engine health and raw
publication checks passed; no independent full replay ran. All 42 original
files/27,754,633 bytes are retained. This says nothing about post-kick behavior.

The earlier test verified the bound getter, not the closing call. Its new
regression reproduces failure under
`development-v14-close-regression-red-f3932a3501d849a4863aff382b988c82` and passes
all four focused tests after the fix under
`development-v14-close-regression-green-a6fb7acec76241028319eef6a1a9d40e`.
Green stdout/stderr SHA-256 are
`61f0000912d3ab5261ff9d0895451d743a940fb629896ad63c6459175bed5f39` /
`f9bf688d3333493d55939fa874da7168bd3666e1c709e1b197bfc62409351e2e`.
The real finalizer and evaluator now close the original retained 30-step input
and explicitly synthetic 60/480/626-row populations without a new world or
native physics read. They still reject missing rows, malformed shutdown,
undeclared bounds and 627 rows. Official evaluation still refuses shortened
prefix/resume inputs. Diagnostic limit validation consumes the same named
schedule JSON; no controller, schedule value, timeout or official branch changes.

Next command from clean pushed source:

```powershell
./sdk/run_development_recovery_smoke.ps1 -RunSmoke -ProfileSteps -ReuseContextChecks -SingleKick -CandidateProfile sdk/development/recovery_candidates/v14-stance-settling-v1.json
```

No new post-kick observation exists. R173 and readiness remain 14/20 and 14/25. The finite
blockers are completed stable get-up, same-body walking resume and unchanged
official validation; no wider physical scope is added.

## V14 knee fold and replant before straightening

V13's original step-410 angles and torso transform motivate a different loaded
path, not another dwell. A fixed-body ideal-hinge calculation shows that folding
knees toward -1.05 rad while leaving the observed hips unchanged raises each
distal endpoint; folding toward +1.05 lowers it. This calculation does not hold
the real torso still, remove initial overlap, establish contact feasibility or
prove why earlier candidates tipped. It omits native anchor separation and
out-of-plane error. The original V13 report is hash-checked by the entry test.

`v14-knee-fold-replant-v1` preserves V11-V13 support entry. Only `raise_body`
changes: 120 reference steps fold knees toward -1.05 while each hip target equals
its actual current reading; 120 move toward the mirrored existing support pose
`[+0.6, -1.05]` per leg; 120 move toward the existing zero-joint stance. Equal
thirds are a prospective development choice, not fitted physical thresholds.
Every segment uses actual observations and the existing measured-pose smooth
rule and 4 rad/s command bound. No boundary assumes waypoint attainment. There
is no added state schema, latch, force input, engine branch, body write, enlarged
joint/motor limit, new phase timeout or changed success requirement.

Native lower-leg upper-cap/knee contacts remain non-foot contacts under the
unchanged local-point classifier. They may participate physically during a
recovery, but cannot count as stable standing. Clarification of the unchanged
classifier: `raised_body_gate` requires COM gain and non-foot clearance, not
four-foot support; `stable_stance_gate` additionally requires all four qualifying
feet, pose, speed, ownership and safety conditions. The earlier combined prose
description did not distinguish those gates correctly; no executable rule is
changed. A knee-supported transfer remains an unproved causal hypothesis, not
an achievement inferred from the ideal geometry or commanded joint poses.

Build `development-candidate-build-e46cc5ff15654674bae1716a7d08a313` reruns 259
core tests and six exported native-shaped fixtures, then copies an independent
immutable optimized DLL. Its stages take 120.173 s. Nine new core tests cover
profile/gate preservation, all adapter-shaped inputs, fold direction, ideal
three-segment tracking, actual boundary errors, odd/exhausted clocks, invalid
inputs, other-phase preservation and public ABI. No physics is simulated there.

Three cold entry tests pass under
`development-v14-entry-controls-a9e2ea6bc3654dfa9a6f3c4d7b095f6a`: original
V13 step-410 fixture binding, independently calculated first command, and
fixed-body fold geometry with the observed orientation. The last check preserves
initial overlap and labels all geometry as conditional, not native measurements.
Original stdout SHA-256 is
`89a349f4b45d5cffcef07b60be98677665553f28dc88d1ccb1787943085bc908`;
stderr SHA-256 is
`9e4cb583df1df8dbc9d6826ec0f360791f9fff0d6c35543295e1855817b14269`.

The complete applicable safety gate and one fresh kicked child have now run
from clean pushed source with full telemetry. This is the historical command
for the consumed attempt, not permission to repeat it:

```powershell
./sdk/run_development_recovery_smoke.ps1 -RunSmoke -ProfileSteps -ReuseContextChecks -SingleKick -CandidateProfile sdk/development/recovery_candidates/v14-knee-fold-replant-v1.json
```

The [closed physical result](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v14-single-kick-closure-body-lift-and-brief-stable-stance)
passes all 73 safety checks, the original 752-transition reader and supervisor.
Knee folding executes while the torso remains nearly level; replanting reaches
body lift at 627 and the existing stance controller takes over at 628, before
V14's final reference segment. Two samples at 749-750 meet the unchanged stable
stance rule, but the 60-sample dwell does not complete and walking does not
resume. At 752 the body is nearly upright, with only two qualifying feet and
ongoing knee straightening. This is not a solved recovery or comparison claim.
Next bind a distinct, coverage-adequate development horizon for the remainder
of the existing stance-settling budget and walking handoff; do not modify this
consumed run, its controller, gates or official timeouts. No baseline is cached,
held-out cohort previewed or support/release claim advanced. R173 is unchanged.

## V13 support waypoint before straightening

V12 demonstrates that accurate straight-leg joint tracking can coexist with an
almost horizontal torso. The existing `EstablishDistalSupport` state advances
when all four feet qualify, not when the prescribed bent-leg pose is reached;
at V12 step 410 the torso is still in contact with the floor. The retained
measured COM and ideal-hinge reconstruction put front contact-site centers
0.090090/0.090461 m behind that COM along the horizontal torso +X direction,
with rear centers about 0.4844 m behind it. Distal-body-origin reconstruction
residuals at that sample are 0.000909-0.002037 m. These are descriptive residuals,
not tolerances or contact-site error bounds. The historical compact point remains
a distal body origin, not a pressure/contact-site measurement.

At the existing hypothetical level support waypoint `[-0.6, 1.05]` per leg,
ideal front/rear contact-center X coordinates relative to the torso origin are
0.166753/-0.227504 m. That geometry motivates an intermediate posture; it does
not establish a physically reachable or stable path from the kicked state.

`v13-support-waypoint-rise-v1` preserves V11/V12 matched-reach support entry.
Only the raising reference changes: first use the measured-pose smooth rule
toward the existing bent-leg support waypoint, then toward the existing zero-
joint stance. The total 360-step reference clock is unchanged and split equally
into 180-step segments. Equal allocation is a prospective development design,
not a fitted physical threshold. The second segment starts from its actual
observation, not an assumed completed waypoint. Late error can remain at the
switch; joint tracking, load, stance and walking still require physical evidence.
There is no new phase/memory schema, force input, body write, engine branch,
hidden pose/latch, changed limit, acceptance rule or phase timeout.

The optimized build `development-candidate-build-79ac33a6ef5e4191acb385b2317a27dd`
reruns 250 core tests and six exported native-shaped fixtures, copies an
independent immutable DLL, and takes 124.203 s across its three stages. Eight new
tests cover profile preservation, all adapter-shaped inputs, ideal two-segment
tracking, actual boundary error, odd/exhausted clocks, malformed observations,
other-phase preservation and public ABI. The ideal path is algebra, not physics.

Three cold checks pass under
`development-v13-entry-controls-b8083452877248ab87c4c27ad2047352`. They bind all
three raising fixtures to V12's exact original step-410 angles, independently
calculate the first waypoint-directed commands, and retain the source-bound
COM/ideal-hinge geometry above. Original stdout SHA-256 is
`39369e556f8a8893c744f66adaa910e6b1cc2ac074fabf677a2bfc32b2151150`;
stderr SHA-256 is
`f56ccd9431fd60641dc047f3ef1d23acd0eabe02d18b36027c2a31cc164dc7a2`.
Calculated site positions omit anchor separation and out-of-plane hinge errors;
they are not new native reads, floor-clearance proof, support feasibility or
causal attribution. The nominal waypoint comparison is not a world simulation.

The complete applicable safety gate and one fresh Godot/Jolt kicked child have
now run with the current bounded horizon and full telemetry. This is the
historical command for the consumed attempt, not permission to repeat it:

```powershell
./sdk/run_development_recovery_smoke.ps1 -RunSmoke -ProfileSteps -ReuseContextChecks -SingleKick -CandidateProfile sdk/development/recovery_candidates/v13-support-waypoint-rise-v1.json
```

The [closed physical result](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v13-single-kick-closure-waypoint-tracking-still-loses-body-support)
passes all 73 safety checks, the original 752-transition reader and supervisor
audit. Four-foot support lasts only at 410-411. At the first segment endpoint
590, maximum measured waypoint error is 0.005806 rad while torso tilt is already
76.27 degrees; neither standing nor walking resume occurs by 752. The second
segment executes, but inserting this waypoint does not establish a feasible
loaded path. Next investigate front/rear placement with actual body orientation
and ground/joint geometry, not another dwell or uniform speed change. No V14 is
selected by this closure. No baseline is cached, prior attempt repeated, held-out
cohort previewed, or support/release claim advanced. R173 remains unchanged.
The finite blockers are stable get-up after a kick, same-body walking resume,
then unchanged official validation.

## V12 measured-pose smooth raise

`v12-measured-pose-rise-v1` keeps V11's matched-reach support command and all
existing destinations, speed/impulse ceilings, phase gates, timeouts and stance
handoff rules. Only the raising reference changes. V11's first raising command
uses the old fixed support pose, even though the actual supported pose at 410
is different; all eight requested speeds at 411 reach 4 rad/s. V12 instead
allocates each step's share of the remaining smooth movement from the current
measured joint positions toward the unchanged zero-joint standing destination.

For the existing smoothstep clock `s(t)`, the remaining-motion fraction is
`(s(t+1)-s(t))/(1-s(t))`. With perfect tracking this is the same smooth curve
starting at the actual phase-entry pose. Under imperfect tracking the next
actual reading is used, and the existing coordinated one-step limit still caps
every request. At/after the clock endpoint, move toward the destination within
that same cap. No saved hidden pose, new phase schema, force input, body write,
or synthetic native observation is introduced. This changes the development
trajectory; it does not claim that the previous transition caused support loss
or that V12 can stand. A later tracking error can still consume the unchanged
phase deadline without reaching stance.

The fresh optimized build `development-candidate-build-8e2415e9cfd847e1a1ed5c449195cfc7`
uses the compiler cache, reruns 242 core tests and six exported fixtures, and
copies its new DLL into independent per-candidate/durable locations. The build
stages take 126.734 s with changed Rust source; this is a build observation,
not a controlled whole-iteration speedup. Eight new core tests cover preserved
profiles/other phases, all adapter-shaped inputs, first command, ideal 360-step
trajectory, current-reading feedback, late errors, exhausted clocks, invalid
sources and public ABI. The synthetic ideal trajectory is not a physics run.

Two cold checks under `development-v12-entry-controls-14ff97512f13471fa4194c94142c7b41`
bind the three raising fixtures to the original V11 report's exact step-410
joint angles. Their first calculated speeds are below 0.005 rad/s, not new
physical measurements or a new speed threshold. The old compiler-cache copy
audit also passes there after V12 rebuilds the mutable cache.

The complete applicable safety gate and fresh Godot/Jolt kicked child have now
run with the current horizon and full telemetry. This is the historical command
for the consumed attempt, not permission to repeat it:

```powershell
./sdk/run_development_recovery_smoke.ps1 -RunSmoke -ProfileSteps -ReuseContextChecks -SingleKick -CandidateProfile sdk/development/recovery_candidates/v12-measured-pose-rise-v1.json
```

The [closed result](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v12-single-kick-closure-smooth-joint-motion-is-not-stable-body-support)
passes all 73 safety checks, the original independent 752-transition reader and
supervisor audit. The actual first raising requests are below 0.005 rad/s, but
four-foot support lasts only at 410-411 and the rear feet lose qualifying load
at 412. By the bounded endpoint all joint magnitudes are below 0.013 rad while
the torso is tilted 86.94 degrees; stable standing and walking resume are absent.
These are observed values, not new controller or acceptance thresholds.
Next inspect foot placement, support geometry and the intermediate support-pose
path before selecting a successor, rather than just slowing the same trajectory.
No cached baseline, held-out use, paired commissioning, force-aware recovery,
causal conclusion or acceptance authority is introduced. The original V12
profile, runtime and attempt remain immutable.

## V11 matched foot reach before common lift

The [cold geometry record](../sdk/development/recovery_leg_geometry_v11.json)
consumes V10's original report and frozen source. The historical compact field
`foot_position_world_m_by_limb` contains each distal body's origin, **not** its
contact-site center: `_foot_position_map_v1` reads `body.global_position`.
Previous rows, closures, and native load-bearing classifications are unchanged.
Do not use that field as foot clearance. Ideal-hinge reconstruction from the
observed joint angles and torso pose covers all 267 canonical observations and
1,068 lower-leg origins; its maximum body-origin residual is 0.013397986 m.
That residual is descriptive, not a new tolerance or an endpoint-error bound.
Computed contact-site centers are not additional native measurements.

At step 386, the rear-left calculated contact-site center is at 0.155605 m
world Y, while the three others are at 0.034936-0.037379 m. During V10 knee
preparation, the front calculated sites remain near that height while the torso
tilts and rises; the rear-left calculated site reaches 0.192927 m at 443.
This motivates a lagging-reach catch-up rule, not a proven causal explanation.

`v11-matched-foot-reach-v1.json` selects a fresh optimized compiled controller.
Only the support-phase command rule differs from V9. On the rearward-folded
branch where knee extension monotonically lowers the ideal foot relative to
the torso, calculate each leg's reach using the production upper/distal lengths.
Match the lowest current relative foot height, limited to a height reachable
by every leg at its unchanged final knee destination. Solve the negative-angle
knee branch and hold hip requests at measured angles while knees catch up.
Once every knee is within the existing one-motor-step distance, use ordinary
V9 coordinated motion. Outside that branch, or if the matching target would
leave the range spanned by measured knees and the existing destination, use
V9 coordination directly. Re-evaluate each observation; no hidden latch, dwell,
force feedback, acceptance threshold, or native body write is added.

This body-relative construction is not a ground-plane or contact-force
controller. Its suitability under body tilt and contact load remains a physical
question. Final poses, speed ceilings, impulse caps, timeouts, rise trajectory,
later phases, official gates and R173 are unchanged.

Build `development-candidate-build-a6fbb67b32d347989c194fed613e5428` retains the
source snapshot, 234 passing core tests, six exported fixtures, and optimized
DLL. Eight new core tests cover retained-entry commands, geometric spread,
catch-up/rechecking, nonmonotone branches, exact destination, invalid/crossed
sources, old phase behavior, three adapter-shaped inputs, and the public ABI.
Three cold geometry checks pass under
`development-v11-geometry-controls-74947bf935ab45daa19f226a7122d4a8`, covering
the exact retained record, body-origin/site distinction, and axis/unit math.
The consumed invocation from the canonical root used the existing shared gate
plus fresh single-kick diagnostic (no cached baseline; not an instruction to rerun):

```powershell
./sdk/run_development_recovery_smoke.ps1 -RunSmoke -ProfileSteps -ReuseContextChecks -SingleKick -CandidateProfile sdk/development/recovery_candidates/v11-matched-foot-reach-v1.json
```

It retained the current bounded horizon and full telemetry. The [752-step
result is closed](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v11-single-kick-closure-brief-support-before-rise-instability):
four-foot support occurs at 410-413, but is lost at 414 after raising begins.
There is no stable standing or walking resume. All 73 safety tests, original
independent reader and supervisor audit pass. The next investigation is the
transition from the actual support-entry pose into the fixed raise trajectory;
no replacement controller or longer attempt is selected by this result.

For new descriptive checkpoints, `development_recovery_candidate_checkpoint.py
<root> --distal-body-origins` selects schema V2: corrected point labels plus all
four-foot support rows, first subsequent loss, and both sides of phase changes.
The default V1 remains solely for exact historical closure reproduction; its
old coordinate label must not be read as a newly validated contact-site location.
Neither mode modifies old reports or replaces native load-bearing measurements.

## V10 knees before hip lift

`sdk/development/recovery_candidates/v10-knees-before-lift-v1.json` binds the
new V10 controller and optimized runtime. During `establish_distal_support`,
if any knee is farther from its unchanged destination than the existing maximum
motor speed times the fixed outer-step duration, hip targets remain at the
current measured angles and only the knees advance using V9's coordinated
fraction. The existing guarded decimal projection applies to all emitted
targets; this requests no intentional hip progress, not exactly zero measured
velocity or a frozen body. Once all four knees are within that existing motor
step distance, all joints use V9 coordination. The rule is evaluated anew on
every observation, so a knee drifting away pauses hip progress again. There
is no hidden latch, added phase, tuned dwell, force input or engine-specific rule.

The support destination, four-rad/s ceilings, impulse caps, 240-step support
timeout, contact thresholds, rise trajectory and later phases remain unchanged.
Knee-angle readiness is a command-scheduling condition, not proof of foot
placement, load, stability or successful recovery. A knee may fail to reach the
target while the torso is down; this is a physical hypothesis for the fresh
single-kick diagnostic, not an outcome inferred from V9's retained geometry.

All 226 core tests pass, including six new tests of the rule, three adapter-
shaped inputs, exact projected hip targets, near/far knee conditions, drift
rechecking, invalid/crossed sources, other phase branches and the public buffer
ABI. The shared builder retains the new DLL and six fixtures under
`SporeSpore_Evidence/development-candidate-build-da01ba7038414bda9df743c94a97101a`.
The first core invocation retained 224 passes and two test failures under
`development-candidate-build-23e418bea31748eda345dc1192565402`: the tests had
compared projected command targets with unprojected angles. They now require
the exact pre-existing projection, not a new tolerance or changed controller.
Its original execution SHA-256 is
`b8a30eada7f37cacea97c05a1576fcccbca69cadd53ecd0d628a368ffb5cfe6b`;
no adapter image or world was produced by that failed build.

The consumed V10 invocation used the existing shared launcher, from the canonical root:

```powershell
./sdk/run_development_recovery_smoke.ps1 -RunSmoke -ProfileSteps -ReuseContextChecks -SingleKick -CandidateProfile sdk/development/recovery_candidates/v10-knees-before-lift-v1.json
```

Its complete applicable safety gate passed before the child started. One seed,
one fresh kicked child and the complete observed tail are retained. The declared
maximum horizon was not reached because support timed out. Comparisons,
held-out evidence, full paired commissioning and acceptance remain outside this
scope. The [626-step result is closed negative](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v10-single-kick-closure-knee-preparation-does-not-place-the-rear-foot).
Knee preparation executes for 57 steps, but rear-left foot-site height increases
before intentional hip progress, and no four-foot support occurs. Do not repeat
the consumed attempt or infer physical placement from knee-angle readiness.

## V9 coordinated support entry

`sdk/development/recovery_candidates/v9-coordinated-support-v1.json` binds the
new compiled controller and uses the common worker/reader. V6 setup, the V8
support destination, four-rad/s ceiling, impulse caps, rise trajectory, phase
rules and acceptance thresholds remain unchanged. Only support-phase requested
positions change: at every observation, all eight joints advance the same
fraction of their remaining position error. The largest requested increment is
at most the existing speed ceiling times the fixed outer-step duration. If all
errors fit in one step, the exact destination is requested; zero error never
causes division by zero. No engine identity, force estimate, or outcome-derived
threshold enters this calculation. Actual motion/contact coordination is a
physical hypothesis, not a consequence guaranteed by the command math.

The command-only check reads the original V8 report at global step 386 by its
exact hash and injects only its eight joint positions into explicitly synthetic
native-shaped planning requests. It neither edits the old observation nor
claims a new native trace. The resulting requested speeds are approximately
1.77-1.79 rad/s at the hips, 2.36-2.39 at the other knees, and 4 at the rear-left
knee, instead of saturating all eight joints at 4. These are calculated motor
requests, not measured solver motion. Three adapter-shaped inputs produce the
same command vector, which is not cross-engine effect equivalence.

The generated build and DLL are retained under
`SporeSpore_Evidence/development-candidate-build-e1d0f2b693c44e89976e0d7e0be46988`.
Its initial build receipt records 38 focused tests. A separate unchanged-source
full-core run at `development-v9-full-core-5f3e69831ddd43ee88b5bd895c09a74a`
passes all 219 tests; the common helper now defaults to that full-core command.
The selected-runtime/retained-input check passes under
`development-v9-integration-f1bcdeaa33a248b18aebb61d56a75dd9`; the final
worker/reader check passes under
`development-v9-integration-c0e0867b8f6c4c7db7d1311591edf629` (eight tests,
286 synthetic steps, 34 rejected corruptions). First-use fixed-ID boundary
failures remain retained; the fixes parameterize shared checks, not candidate
wrappers or official authority. Subsequently the complete 73-test safety gate
and a fresh single-kick diagnostic ran; no baseline was reused and no comparison
or recovery-success claim was granted.

The first full-gate invocation, `development-recovery-smoke-059922d5f7b94848866f74a9b1b06266`,
stopped with `SMOKE_SAFETY_GATE_FAILED:candidate_transport`, before any child.
Its original supervisor result SHA-256 is
`85f376a61435574c959a09beb37de3bc4ed623e72d53ec0c933b2dffc2297043`.
Only the generic manifest test's inherited bookkeeping assumption was corrected;
explicit zero-world and no-authority checks remain mandatory. All seven affected
tests pass under `development-candidate-manifest-control-0523af97fa684344a6a471700152b016`.
The controller, DLL, profile, old test branch and failed receipt are unchanged.

V9's distinct physical attempt `46cc3bddeed5433d8c25f6f3ae16e11c` is closed as a
valid development negative. The original complete 626-step reader and supervisor
audit pass. Coordinated requests execute, but the rear-left foot never meets the
existing support requirement; the torso overturns and support times out after
240 active steps. No standing or resumed walking occurs. The original 45 files
and 524,053,871 bytes are immutable. [Full closure, geometry and timing](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v9-single-kick-closure-coordination-does-not-establish-support).

`sdk/conformance/development_recovery_candidate_checkpoint.py` provides one cold
closure implementation for profile-selected attempts. It counts all original
contact samples, distinguishes tracked foot positions from load/clearance,
and consumes rather than reruns the original reader. A separate leg-placement
step before lift is the next investigation; it is not yet a selected controller
or a causal finding. The official gate and SDK2 force-aware scope are unchanged.

## Shared recovery boundary definitions

[`sdk/core/contracts/recovery_interfaces_v1.json`](../sdk/core/contracts/recovery_interfaces_v1.json)
owns the existing canonical ownership domain/mapping and Godot host-process
relationship constants. Rust generates the wire enum in its build; Python reads
the source directly; GDScript and PowerShell use generated projections checked
by the development gate. This removes duplicated definitions, not independent
validation. Process isolation, command semantics and official acceptance remain
unchanged. The [implementation checkpoint](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#shared-recovery-interfaces-one-definition-checked-at-real-boundaries)
records tests, exact retained development receipts and adoption limits.

## Development ghost and held-out validation lanes (2026-08-25)

The [V8 rate-limited development selection](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v8-rate-limited-candidate-connected-through-worker-reader-and-launcher)
reuses V7's fixed targets but caps both support/rise target velocities at 4 rad/s.
It is not a new acceleration/force-feedback controller. Separate controller,
runtime and record identities connect the existing worker/reader/launcher path;
V6 setup and its native measurement ancestry remain unchanged. Old entrypoints
still reject V8 records, while explicit V6/V7 compatibility on the new compiled
superset is tested. Native motor and synthetic full-timeline checks pass; the
complete smoke safety gate and fresh physics remain required.

The subsequent [V8 physical pair](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v8-physical-smoke-closes-valid-negative-no-four-foot-support)
passes the full safety gate and both original independent replays but remains a
development behavior negative: no four-foot support, overturn, support timeout,
no stable standing or walking resume. Native contacts show no qualifying rear-left
foot support during any of the 240 active support steps. Unequal initial joint
travel under equal speed ceilings motivates investigating a coordinated reference
trajectory; it does not establish causality or adopt a new controller. V7, V8,
R173, native measurement ancestry and official acceptance remain immutable.

The [rearward-fold V7 candidate](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#rearward-fold-v7-candidate-real-compiled-and-native-motor-boundaries-pass)
is an explicit portable profile, not an edit to V6 or an automatic pose selector.
Its native command entrypoint reuses the production motor/energy machinery with
an explicit expected controller ID; existing calls still default to V6. Its
separate consumption context binds the unchanged native measurement ancestry
while forbidding new-world and behavior authority. Compiled entry/advance and
native motor-application checks pass with synthetic observations and uninserted
hinges. The subsequent [worker connection](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#rearward-fold-v7-worker-connected-through-the-first-native-support-command)
now selects V6 for setup and explicit V7 ownership/scheduling/advance/application
only after measured prone. Its consumption context binds the actual unchanged
native measurement context; the energy epoch is not reset. Supplied-observation
worker checks reach the first native support command on uninserted hinges. The
independent V7 reader and launcher profile are now connected through a single
explicit selection definition. Separate replay checks the full synthetic worker
timeline through the first active support step, preserving V6 measurement ancestry
and explicit V7 command ownership. The complete affected 76-test smoke gate must
still pass before the fresh physical diagnostic; no get-up or route claim follows.

The [subsequent V7 physical pair](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#v7-physical-smoke-closes-valid-negative-transient-support-then-overturn)
passes that 76-test gate and both independent original report replays. It remains
a development behavior negative: transient four-foot support and body lift lead
to loss of support, overturn and a stance-dwell timeout. The read-only closure
recomputes the support samples from retained contacts and the frozen rule; later
controller work must preserve this result and use a distinct prospective profile.

The additive development [passive-entry component](../sdk/core/src/recovery/passive_entry.rs)
separates post-kick descent from the canonical prone-to-standing supervisor. It
observes owner-none, zero-motor-impulse steps under a distinct declared bound.
Only a measured prone sample can create new canonical memory, with its COM
reference and the first of the existing confirmation samples. Subsequent steps
use the existing canonical ownership and sequencing contract. Terminal entry
state cannot be stepped again; a later bounce does not restart get-up. The
kick-boundary energy ledger continues across this control boundary, checked
against supplied increments without a new zero or residual-derived correction.

The C/JSON, Python and Godot source bindings are additive. Existing step and
trace APIs do not accept the owner-none prefix by relabeling it as canonical
recovery. Worker integration, retained entry-prefix replay and a newly bound
native adapter are still required before physical commissioning. Component
tests grant no route, recovery, acceptance or release authority. See the
[implementation checkpoint](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#passive-entry-component-measured-initialization-without-restarting-the-clock).

The subsequent [native bridge](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#passive-entry-native-bridge-exact-source-validation-and-energy-continuity)
now supplies the separate owner-none collector and retains its actual JSON call
alongside the entry step. Native Godot energy continuity explicitly checks global
increment accumulation followed by the fixed kick-boundary offset; local staging
keeps its existing sum. The new path uses typed JSON decoding for exact numeric
state. Its separate adapter is bound and tested in a zero-world Godot process;
the subsequent worker connection supplies the scheduler and retention hooks.
Existing canonical collection and stepping stay unchanged.

The [development entry worker](../sdk/adapters/godot/gdscript/development_passive_entry_smoke_worker_v1.gd)
uses a distinct state/event/report/declaration identity. Its energy clock starts
at the kick; its canonical confirmation clock starts at measured prone. The
existing no-actuation ownership mapping already supports owner-none with empty
memory and supplies a canonical-alphabet command ID while retaining its original
source. A lossless UTF-8/hex projection binds the worker attempt ID into the
entry API's identifier alphabet. Neither projection changes an observed record.
The first recovery-owned application binds the actual handoff receipt and memory
without another initialize/advance call; subsequent applications use the existing
canonical controls. Descent packets, scheduler transitions, the first application
and canonical transport packets are attached to completion/child-abort reports.
Three zero-world tests exercise the actual hooks, including a successful supplied
prone handoff and two subsequent compiled steps. The independent new-prefix reader
and diagnostic launcher/closing integration remain required before a fresh world;
these hooks do not establish physical recovery or complete-route evidence.

The subsequent [cold reader](../sdk/adapters/godot/gdscript/development_passive_entry_replay_v1.gd)
reconstructs fresh report initialization and replays the retained entry and
canonical calls, preserving source bytes, the one-time handoff and kick-boundary
energy continuity. Real active/disabled producer checks validate the existing
integral counter projection and distinct command hashes. Full-report and explicit
segment requests are separate. This reader is tested with synthetic observations;
the new launcher/walking-close/outer-audit profile and a fresh physical smoke are
still required. See the [checkpoint](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#passive-entry-cold-replay-complete-timeline-and-real-command-source-checks).

The [subsequent opt-in profile](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#measured-entry-smoke-profile-launcher-close-and-independent-audit-connected)
connects that reader through a separately retained subprocess and the outer audit.
The supervisor selects the distinct adapter/report and finite 240-descent/480-tail
limits; walking close receives the same declared 480-step diagnostic maximum.
Its focused integration is tested, while the complete safety gate and first
physical invocation remain required at that source checkpoint.

The first invocation exposed a second runtime loader inside walking startup.
The new worker now explicitly passes its preloaded-runtime choice through the
facade to the walking adapter, which creates a fresh SDK/controller session
without loading the default DLL. Default callers retain the old path. A real
portable walking-session start/shutdown runs before any new worker model and
its receipt is retained. The [failed attempt and targeted repair](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#measured-entry-first-physical-attempt-runtime-collision-retained-and-startup-repaired)
remain distinct: no engine-health refusal or old physical result is reclassified.

The [measured-entry physical replay diagnosis](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md#measured-entry-full-replay-passes-support-pose-motion-overturns-the-body)
clarifies a separate consumer boundary: `applied_actuation.adapter_receipt_sha256`
binds the post-step native execution receipt, not the pre-step command intent.
The reader validates both records' command/step links and measured impulses.
Post-exposure replays use a fresh durable directory with their own source/process
bindings; they cannot overwrite or reclassify the original attempt. A replayed
support timeout remains distinct from successful get-up or a complete route.

The production execution path now has two authority lanes, not two physics
implementations:

```text
focused component checks
  -> smallest coverage-adequate production route ghost
     (one development seed and a short declared horizon by default)
  -> append-only development result
  -> targeted or full-horizon ghost only for an explicit remaining code risk
  -> exact source, dependency, toolchain, and environment freeze
  -> complete zero-world gates, negative controls, and separate adoption
  -> fresh held-out native finite decision
  -> immutable official closure
```

Both lanes use the same entry point, worker, canonical controller, adapter,
native world, parameterized scheduler, recorder, evaluator code, CAS
publisher, terminal path, and supervisor. The route ghost may use a declared
development seed, smaller coverage-selected cell set, and shorter horizon,
provided the same production machinery carries those values through real
construction, stepping, finalization, retention, evaluation, and terminal
assembly. Its `coverage_manifest` states exactly what it does and does not
exercise.

A ghost succeeds on an execution-valid result, including a valid physical
negative. It does not predict the official behavioral outcome. A separate
physics implementation, synthetic native substitute, swallowed infrastructure
failure, alternate retention path, or bypassed finalization is an
architectural violation. A full horizon or extra seed is justified only by a
specific code-path risk that the minimal route does not cover.

A later held-out authority must validate a consumed ghost at two levels. First,
the closure, Git blob, commit graph, and retained file population must remain
content-addressed. Second, the validator must parse the closure, report, attempt
receipt, route-completion state, consumption limit, and denied claims. A matching
hash proves identity; it does not by itself prove that the identified document
says what the prerequisite requires. The R05E authority contract is the first
walking implementation of this combined content-and-semantics rule.

Runtime identities canonicalize path spelling only where the host filesystem's
execution semantics make spelling differences non-identifying. On Windows,
absolute executable paths use forward slashes and invariant lowercase before
identity hashing, while executable bytes, byte length, version, resolved tool
target, adapter artifact, host, and build environment remain separate exact
bindings. Qualification must exercise an equivalent differently cased launch
path; a string-normalization unit check alone is not adequate production-route
evidence.

Outputs carry `ledger_scope.subsystem`, `engine_scope`, `authority_mode`, and
`question_class`, which supports readable labels such as `[turning/rapier]`
and `[harness/3e]` without changing the identity of historical records. The
complete evidence and promotion rules live in the
[research program](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md).

SDK1 uses this architecture to earn bounded, explicit per-engine capability
support in genuine Godot/Jolt, Rapier/Parry, and MuJoCo. It does not require
formal equality of native effects or arbitrary physical-morphology coverage.
Those population claims belong to SDK2 and still require prospective native
evidence. The versioned
[bounded SDK1 mapping](../sdk/release/quadruped_sdk1_milestone_mapping_v1.json)
partitions every full-program gate exactly once as mapped or deferred, adds one
explicit Explorer milestone, and now compiles to `14/20` without changing the
durable full-program denominator; that ledger now reports `14/25`. See the
[master SDK roadmap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).

Cole's explicit goal injection resumed hashed scientific work. M07's R10E-L2
ghost lane has now closed as a valid finite negative, and a later held-out graph
was consumed invalid/incomplete after two of six worlds. R10E-L3 repairs only
the observed numeric self-link and incomplete terminalization boundaries. Its
development zero-world audit passes, but it remains non-authoritative and
changes no score by itself.

## Current R23D65 execution architecture closure (2026-08-25)

R23D65 proves why the route ghost must traverse finalization and failure paths,
not merely construct and step a world. Its exact source passed all `25`
qualification gates, adoption, and nine authorization preflights. Three
Godot/Jolt worlds then each generated a complete `2,992`-row diagnostic but
failed at trace retention. The Rapier/Parry reference world generated a
complete `2,992`-row canonical trace but projected contradictory world counts
between its nested execution record and top-level terminal. The supervisor
rejected that contradiction, then its own frozen failure-normalization handler
failed because PowerShell `(if ...)` was used where a subexpression was
required. The remaining five worlds never opened and the complete evaluator
never ran.

The closure is therefore an infrastructure-invalid/incomplete finite decision,
not a turning outcome. All four built worlds and the complete `41`-file,
`134,685,582`-byte retained population remain evidence; none may be post-hoc
promoted. Exact authority is
[`../sdk/turning/r23d65_selected_profile_three_engine_turning_validation_closure_v1.json`](../sdk/turning/r23d65_selected_profile_three_engine_turning_validation_closure_v1.json),
audited by
[`../tests/test_qsdk_r23d65_physical_closure.ps1`](../tests/test_qsdk_r23d65_physical_closure.ps1).

At the R23D65 closure no held-out successor was open, and `QSDK-R23` remained false at `10/25`. The
prospective
[`three_engine_turning_production_route_v1.json`](../sdk/turning/three_engine_turning_production_route_v1.json)
now fixes the architectural ghost slice: one positive-heading cell in each
advertised engine, reused exposed seed `21516`, and two controller steps. The
shared
[`three_engine_turning_route_evaluator.py`](../sdk/turning/three_engine_turning_route_evaluator.py)
already owns canonical NDJSON, real test-only CAS publication, exact success
versus failure count ownership, complete engine aggregation, and a
non-behavioral route-validity decision. The parameterized genuine native
workers now feed that route through Godot/Jolt, Rapier/Parry, and MuJoCo and
pass their separate zero-world preflights. The shared
[`three_engine_turning_route_supervisor.py`](../sdk/turning/three_engine_turning_route_supervisor.py)
implements the remaining gate and freeze machinery: one machine-wide lock,
exact clean/local/remote/live equality, append-only reservation/freeze/attempt,
pre-model authorization in every worker, ordered physical launch, immutable
stream and terminal retention, and one complete evaluator call. Its exact
clean-pushed source `9ac608070809c1b559750e04666d3375a4133a03` passed all
eight serialized zero-world processes and `13` negative controls with zero
model and world constructions. Its first frozen attempt
`843b1e6848024df5b2a80696adc89f07` then stopped before world one because a
successful Rapier authorization receipt used Windows' canonical `\\?\` path
prefix while the supervisor compared it to an ordinary path spelling. That
attempt is immutable infrastructure-incomplete development evidence. The
prospective supervisor canonicalizes both spellings and writes each
authorization process append-only before receipt validation, closing both the
identity and failure-retention seams without changing a worker, controller,
physics route, or evaluator. That repair shipped at
`cdba50e2ab8e1d2a118063b8e7aaa74f0f36f7b3`; distinct attempt
`23a120d0f0c7461e9a0087bcae769909` then passed every positive authorization
preflight and serialized one genuine model and world per engine. Its complete
evaluator invocation accepted zero cells because three separate integration
contracts failed: the Godot inheritance boundary projected the historical
`2,992`-step integrity horizon over the route's exact two-step trace, the shared
trace publisher did not pass process-scoped PowerShell execution-policy
bypass for Rapier's host, and the MuJoCo binding used shortened perturbation
aliases instead of the inherited canonical shape. The retained `59`-file,
`331,605`-byte population is immutable invalid/incomplete development
evidence, applies no behavior thresholds, and changes no claim. The
prospective architecture repair adds a route-scoped Godot execution projector,
the publisher launch flag, and the exact inherited MuJoCo field shape. It
shipped at `68dd3d7dd3d016a873613063ff7daa966228f0f5`; distinct attempt
`fa1b5fdf25304f70ac401a78606a52f5` then made Godot/Jolt and Rapier/Parry
execution-valid with exact retained two-row traces. MuJoCo built one model and
world and completed both steps, but its native application receipt carried a
NumPy boolean scalar into the route's standard-JSON trace boundary. JSON
refused that transport representation, the sole complete evaluator invocation
refused the incomplete matrix, and the full `60`-file, `256,520`-byte attempt
remains immutable invalid/incomplete development evidence. The next
architecture repair losslessly projected NumPy scalars to JSON-native scalars
at the route boundary; it changed no observed value, physics, controller,
threshold, or evaluator. Source
`c93bcc479d3f882ce61e4ff21d036d3aae3f877d` then produced distinct attempt
`2f586ca10fc4421b9e133f0801061cb7`: one genuine world and exactly two
controller steps in each of Godot/Jolt, Rapier/Parry, and MuJoCo, three retained
two-row traces, three execution-valid terminals, and one passing complete
evaluator.

The exact architectural boundary is content-addressed in
[`../sdk/turning/three_engine_turning_production_route_development_closure_v1.json`](../sdk/turning/three_engine_turning_production_route_development_closure_v1.json)
and enforced by
[`../tests/test_three_engine_turning_production_route_development_closure.ps1`](../tests/test_three_engine_turning_production_route_development_closure.ps1).
The route has therefore proved construct → step → finalize → retain → publish
→ evaluate through all three production adapters. It has not proved a
behavioral horizon, turning, cross-engine equivalence, or release authority.
A longer or repeated development ghost is unnecessary unless a named
late-horizon or volume-only code path is introduced. The next architectural
consumer is a fresh held-out finite-decision contract, not another generic
route canary.

## R23D66 execution architecture and observed boundary (2026-08-25)

R23D66 was that fresh held-out finite-decision contract. It configured the
same qualified production route for nine ordered cells: Godot/Jolt,
Rapier/Parry, and MuJoCo, each with reference, `+0.2 rad`, and `-0.2 rad`
heading arms on then-unused seed `23179`. It preserved the published exact-s169
profile, canonical portable controller, native adapter semantics, startup,
task origin, `2,992`-step schedule, common physical gates, measurement, and
turning floors. Engine and arm identities remain outside policy input.

The prospective declaration is
[`../sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json`](../sdk/turning/r23d66_production_route_three_engine_turning_validation_preregistration_v1.json).
Its pure Godot seed compiler deterministically records the fresh fixture
without constructing a model or world. Its compact validator and executable
audit bind the immutable predecessor, route closure, declaration parent,
matrix, schedule, thresholds, decision rule, and public claim boundary while
rejecting `13` representative mutations. This keeps declaration conformance
small and content-addressed rather than multiplying aliases into a canary
suite.

The existing route ghost already proves the shared construct → step → finalize
→ retain → publish → evaluate path in every native engine, so another physical
ghost was not architecturally justified. R23D66 layered a compact
[content-addressed implementation](../sdk/turning/r23d66_production_route_three_engine_turning_implementation_v1.json)
over that route. Its complete zero-world gate binds `201` dependencies and
first runs the cheap integration frontier: one positive preflight, one invalid
selector, and one missing-authorization physical entry per engine. Only after
those pass does it pay for the complete nine-trace `2,992`-step evaluator and
shared mutex/append-only gates. Positive, negative, invalid, and incomplete
outcomes are all proved without constructing a model or world.

Only a clean-pushed source that replayed this gate, froze exact source and
toolchain identity, passed fresh scoped qualification, and was separately
adopted could approach the nine serialized worlds. Source `2d57cac4` satisfied
those prerequisites, froze and content-addressed all `210` inputs, and consumed
its single-use attempt. The complete native authorization population then
closed `6/9` before the first physical worker: Godot/Jolt and Rapier/Parry
passed six receipts, while all three MuJoCo receipts reported
`authorization_passed=true` but omitted the supervisor-required `ok` field.
R23D66 therefore built zero models and worlds and produced no turning result.
Its exact [closure](../sdk/turning/r23d66_production_route_three_engine_turning_validation_closure_v1.json)
is immutable; readiness remains `10/25`.

## Successor authorization architecture

The successor integration repair begins with one campaign-neutral
[common receipt validator](../sdk/three_engine_authorization_receipt.ps1) and
its versioned
[contract](../sdk/turning/three_engine_authorization_receipt_contract_v1.json).
This is development work followed by complete-population
equivalence/non-inferiority conformance across the three advertised producers;
it is not a physical question. Every positive receipt must carry exact
campaign, gate, engine, stage, cell, and schema identities plus the common
`ok`, `authorization_passed`, `returned_before_model`, zero execution counts,
and false physical-authority fields. Missing, aliased, wrong-type, wrong-value,
or nonzero projections fail closed.

The contract's executable audit covers all three positive producer shapes and
117 missing, wrong-type, and wrong-value controls at zero models/worlds.
R23D67 is now a consumed finite-decision integration result. Its `206`-input
implementation passed the complete zero-world route, a clean-pushed `16/16`
qualification, separate adoption, and the physical supervisor's full `9/9`
authorization population before one Godot/Jolt world opened. Those gates remain
valid evidence for the seams they actually traversed; they are not a turning
result.

The first real horizon exposed two production paths the earlier ghosts did not
execute. The Godot row emitter used the historical terminal segment token
`after_declared_schedule`, while the R23D67 runtime bound its inherited
evaluator to `reference_continuation`. This rejected exactly steps
`2400..2991` during trace retention despite a complete `2,992`-row trace. Then,
after terminal CAS publication, the cell projection called `Contains` on the
Godot runner's `PSCustomObject` process result as if it were a Hashtable. The
[immutable closure](../sdk/turning/r23d67_authorization_schema_repaired_three_engine_turning_validation_closure_v1.json)
proves both source relationships and preserves every observed artifact.

The successor architecture needs two small production-path conformance
fixtures, not another broad canary layer: one advances the actual trace-row
constructor across steps `2399/2400`, and one feeds the actual Godot process
result shape through terminal-to-cell projection. Both are non-official
development ghosts and open no world. Complete zero-world qualification and a
fresh finite-decision identity still precede physics. R23D67 itself cannot be
rerun, completed, or interpreted as turning.

R23D68 consumed that architecture across all nine native cells, but exposed
three production trace contracts and one projection contract that the compact
helper ghosts did not cover: complete Godot row observations, Rapier's inherited
final segment relabeling, strict MuJoCo row serialization, and inner MuJoCo
failure-count projection. Its closure preserves the original report and
separately binds the pinned control-flow proof for nine complete horizons.

R23D69 therefore uses a narrower but deeper production witness architecture.
Each native route must pass seven boundary-sensitive representative complete
rows through the actual shared production seam and frozen row contract. MuJoCo
must additionally pass strict JSON with native-derived predicates, while its
outer failure path must preserve both an inner before-world receipt and an
inner settlement-complete `1/1` receipt. These are pure zero-world conformance
checks. Helper-only witnesses and full ghost worlds are both outside this gate.
The implemented witness population passed all `21/21` rows and both failure
cases without constructing a model or opening a world. Clean-pushed source
`2b7a2be1` subsequently passed `16/16` qualification and separate adoption, and
the R23D69 supervisor consumed all nine physical cells.

All nine native routes reached complete `2,992`-step trace publication, but a
single shared receipt contract stopped every route before behavior evaluation:
the producer returned `trace_summary.row_count`, while each worker required a
top-level `row_count`. The [immutable closure](../sdk/turning/r23d69_complete_production_row_three_engine_turning_validation_closure_v1.json)
binds the complete `75`-file, `779,848,989`-byte population and the pinned source
chain. This is not a physics or threshold failure; readiness remains `10/25`.

The successor architecture adds one compact contract fixture at the real
retain-publish-parse boundary. A tiny complete-row input is enough to prove
publisher invocation, receipt shape, and all three consumer parsers. A full
single-seed ghost world would add runtime without proving a different coding
property, so it is outside this development gate.

R23D70 froze and passed that receipt architecture, but its physical attempt
exposed the next adjacent seam. After `16/16` exact-runtime qualification,
separate adoption, and `9/9` authorization, the first Godot/Jolt world completed
all `2,992` steps and retained its trace. The worker success terminal included
the canonical nested `execution` object with one attempt and one build, while
also inheriting stale root counters with both values zero. The shared terminal
projector deliberately rejected the ambiguous shape as
`TERMINAL_EXECUTION_PROJECTION_SUCCESS_SHAPE_INVALID:sporespore_qsdk_r23d70_engine_cell_report_v1`
before terminal retention. Eight worlds did not open and no behavior evaluator
ran; the immutable R23D70 closure keeps readiness at `10/25`.

The architectural correction is not another full ghost world. The smallest
complete code population is each of the three native success-terminal producers
followed by the actual shared projector, plus negative mutations that re-add any
root execution counter or remove/corrupt the nested execution object. This
zero-world surface directly proves that a completed worker can cross the exact
post-physics retention seam. It predicts no locomotion outcome and cannot
replace a fresh finite physical decision.

R23D71 proved that correction but also exposed the next architectural boundary.
Corrected clean-pushed source `f82e3454` passed `16/16` qualification gates,
separate adoption, and `9/9` authorization receipts. All nine genuine worlds
completed their `2,992` steps and retained CAS traces. The common projector
accepted all six Godot/Jolt and Rapier success terminals, while the MuJoCo
success constructor omitted `question_class` and was preserved as three
supervisor transport failures.

The frozen evaluator then rejected every directly evaluated success report with
`R23D65_TRACE_ARTIFACT_IDENTITY`. The producers retained valid trace bytes but
distributed transport identity differently: Godot embedded only part of it in
`trace_artifact`, while Rapier and MuJoCo carried it in a sibling
`trace_transport` object. The evaluator requires the complete canonical set in
the artifact receipt itself. This is a post-physics assembly contract, so the
synthetic terminal ghost did not cover it. Independently, Rapier's three reports
failed `R23D34_FORWARD_DISPLACEMENT` against the unchanged `0.030123046875 m`
floor. The [R23D71 closure](../sdk/turning/r23d71_success_terminal_projection_repaired_three_engine_turning_validation_closure_v1.json)
therefore keeps the score at `10/25`; the result is invalid, consumed, and not
rerunnable.

The corrected architecture for the next successor has two serialized lanes.
First, zero-world conformance still proves selectors, authorization, negative
controls, and pure transformations. Then a bounded, explicitly developmental
native smoke instantiates each actual producer and advances only enough steps
to emit the real success receipt through the frozen evaluator boundary. It
must prove complete `question_class`, execution, trace artifact, and transport
identity without pretending to forecast a held-out behavior result. Only after
that lane closes does separate Rapier physical development address the observed
forward-displacement failure. A new finite decision is not justified until
both lanes pass.

The first lane now has an exact implementation boundary. Clean-pushed source
`150b94cd` is bound by the
[v2 implementation record](../sdk/turning/three_engine_turning_success_transport_route_v2_implementation.json)
and [audit](../sdk/audit_three_engine_turning_success_transport_v2_implementation.ps1).
The shared evaluator owns the complete artifact projection for every producer;
each success terminal must carry `question_class=development`, nested execution
counts, and an artifact receipt containing the exact transport ID, engine ID,
canonical-NDJSON flag, and full-precision flag. The supervisor owns one
machine-wide lock, exact clean/local/origin/live equality, append-only
reservation and freeze, pre-model authorization, serial launch, and complete
aggregation. Its live zero-world gate passed eight processes and all 23
negative controls without constructing a model or world.

Attempt `f8a11109` opened that exact physical slice. All three native workers
constructed, stepped twice, retained complete CAS traces, and emitted success
terminals. The aggregate evaluator rejected Godot first because the GDScript
JSON parser and serializer carried the correct `5414`-byte artifact length as
JSON `5414.0`; the strict Python projection therefore saw a float rather than
an integer. The [closure](../sdk/turning/three_engine_turning_success_transport_route_v2_attempt1_closure.json)
and [audit](../sdk/audit_three_engine_turning_success_transport_v2_attempt1_closure.ps1)
bind the complete invalid attempt and all three external CAS artifacts.

The first repair adds one narrow producer-boundary normalization: a finite,
nonnegative, exactly integral JSON number is restored to GDScript `int` before
both root and retention projections; fractional input fails closed in the
preflight. That raises the complete zero-world mutation population from 23 to
24. The [repair implementation](../sdk/turning/three_engine_turning_success_transport_godot_integer_projection_repair_implementation_v1.json)
and [audit](../sdk/audit_three_engine_turning_success_transport_godot_integer_projection_repair_v1.ps1)
bind clean-pushed source `c50eac34` and pass that complete gate at zero worlds.

The following clean-pushed attempt `d1158485` proved that integer repair on the
actual Godot producer and retained complete two-row traces from all three
engines. It also exposed one independent Rapier projection omission: the root
and ledger identity were correct, while nested `trace_retention.question_class`
was absent. The [closure](../sdk/turning/three_engine_turning_success_transport_route_v2_attempt2_closure.json)
and [audit](../sdk/audit_three_engine_turning_success_transport_v2_attempt2_closure.ps1)
bind the complete invalid result. Rapier now inserts that exact nested identity,
and zero-world preflight executes the real success projector and requires the
field. The [repair implementation](../sdk/turning/three_engine_turning_success_transport_rapier_retention_question_class_repair_implementation_v1.json)
and [audit](../sdk/audit_three_engine_turning_success_transport_rapier_retention_question_class_repair_v1.ps1)
bind exact clean-pushed source `b0cac1bd`; the full 24-control gate passes
without a model or world. Wrapper source `d5c5fa5e` then opened one fresh
serialized population. Each of the three actual producers constructed a world,
advanced two controller steps, retained a complete canonical trace, projected
the full success identity, and passed the common evaluator. The
[route closure](../sdk/turning/three_engine_turning_success_transport_route_v2_closure.json)
and [audit](../sdk/audit_three_engine_turning_success_transport_v2_closure.ps1)
close this architecture lane; another transport smoke is unnecessary. This is
the complete producer population but not a behavioral sample, so separate
Rapier behavior development remains and the result cannot authorize turning,
`QSDK-R23`, equivalence, or release.

## R23D71 measurement-origin architecture diagnosis

The retained [development diagnosis](../sdk/turning/r23d71_forward_displacement_measurement_origin_diagnosis_v1.json)
proves that task-frame path state and evidence-window measurement state were
architecturally conflated in the Rapier and MuJoCo terminal producers. Godot
already freezes its advance origin at evidence semantic step `472`; Rapier and
MuJoCo computed terminal advance from the task origin last reanchored at step
`2400`. The [executable audit](../sdk/audit_r23d71_forward_displacement_measurement_origin_diagnosis.ps1)
uses pinned historical source blobs and all nine retained traces, with zero new
worlds.

The prospective contract is explicit: `evidence_window_start_semantic_step_v1`
owns release measurements, while task-frame reanchors remain controller path
state only. Applying that observation model post-hoc makes every retained
Rapier arm pass the unchanged forward gate, and Godot plus Rapier pass the
unchanged directional-cycle estimator. It does not rescue MuJoCo, whose torso
contacts ground at step `146` before the step-`600` turn window in all arms.
R23D71 and all thresholds remain immutable; this architecture diagnosis grants
no turning authority and redirects behavior development to MuJoCo stability.

## Forward-displacement measurement-origin implementation boundary

The [prospective source authority](../sdk/turning/forward_displacement_measurement_origin_parity_v1.json)
now separates measurement state from controller path state in all three native
producer code paths. Godot continues to use its existing evidence-start torso
position. Rapier and MuJoCo add an explicit opt-in plan that captures the torso
position before semantic step `472` and projects final displacement from that
immutable origin along the initial reference-heading forward axis. Their
mutable task origins can still reanchor at steps `600`, `1800`, and `2400`
without changing the terminal measurement origin.

Compatibility is fail-closed: all historical Rapier execution plans and the
default MuJoCo API remain legacy, while an opted-in report carries the shared
origin-policy receipt. The [audit](../sdk/audit_forward_displacement_measurement_origin_parity_v1.ps1)
binds the complete `3/3` source population and passes ten focused plus inherited
tests with eight negative-control classes and zero worlds. Godot does not yet
emit the new common receipt, so full three-engine report-receipt parity is not
claimed. This boundary authorized the bounded MuJoCo pre-turn development
result below, not a finite turning decision or release-score change.

## R23D72 closed scoped pre-turn execution boundary

The [R23D72 development contract](../sdk/turning/r23d72_mujoco_selected_profile_preturn_startup_development_v1.json)
uses scoped bindings around the immutable R23D65 MuJoCo production module. The
bindings change only the exposed seed fixture, controller horizon, expected
step-`600` task-origin reanchor, and startup-transform object; they are restored
after every preflight or physical call. Both preflight and physical execution
load the same explicitly recorded release core binary, preventing a debug/release
runtime split. The public actuator-cap route, native force-range binding,
controller policy, morphology, and host application loop remain unchanged.

The fixed horizon contains `601` reference-walk commands and zero turn commands.
The core's final-step yaw window is a one-step internal completion sentinel only;
the report and trace mark `turning_tested=false`. Forward displacement opts into
an immutable step-`0` evidence origin and is descriptive. Full-precision NDJSON
is written durably and hashed before the terminal report is emitted. The
[supervisor](../sdk/run_qsdk_r23d72_supervisor.ps1) binds the clean live-equal
source, exact release DLL, contract, worker, and inherited production sources,
then grants one world under the global physical-operation lock. The
[audit](../sdk/audit_r23d72_mujoco_preturn_startup_development.ps1) proves the
zero-world path and inherited evidence but does not predict the physical result.

That one source-pinned world completed all `601` native MuJoCo steps with no
torso-ground-contact row. The
[closure authority](../sdk/turning/r23d72_mujoco_selected_profile_preturn_startup_development_closure_v1.json)
binds source `b35ea21d`, the exact release execution, `13` retained evidence
files, and the `601`-row trace. Its
[closure audit](../sdk/audit_r23d72_mujoco_preturn_startup_development_closure.ps1)
streams the trace, recomputes the startup ramp, checks cross-file identities,
and replays the prospective zero-world semantics while leaving the observed
closure in place. This closes the pre-turn mechanism positive and permits a
distinct selected-profile turning successor; it does not establish turning.

## R23D73 closed full-horizon positive-turn boundary

The [R23D73 contract](../sdk/turning/r23d73_mujoco_selected_profile_positive_turn_development_v1.json)
reuses R23D72's scoped-binding architecture but restores the production
`2,992`-step schedule. Its one cell carries `600` reference-warmup steps,
`1,200` positive commanded-turn steps, `600` recovery steps, and `592`
continuation steps. The only behavioral substitution remains the unconditional
one-cycle ramp. The task frame may reanchor at steps `600`, `1800`, and `2400`,
while the evidence origin is captured once before step `472` and remains
immutable.

The [worker](../sdk/adapters/mujoco/sporespore_mujoco_adapter/qsdk_r23d73_positive_turn_development.py)
retained full-precision NDJSON before terminal construction, applied the exact
common physical gate vector, and computed the positive arm's raw cycle shift
with the existing R23D31 estimator. The reference-conditioned and bilateral
projections were structurally unavailable from one cell and remained
unevaluated. The [supervisor](../sdk/run_qsdk_r23d73_supervisor.ps1) granted one
world from clean-pushed live-equal source under the global lock.

That one world completed all `2,992` steps and closed positive: all common gates
passed and raw cycle shift was `0.14718188227060067` rad against the `0.01` rad
floor. The [closure](../sdk/turning/r23d73_mujoco_selected_profile_positive_turn_development_closure_v1.json)
and [closure audit](../sdk/audit_r23d73_mujoco_positive_turn_development_closure.ps1)
bind the executed source, all `13` retained files, and every trace row, then
recompute the schedule, ramp, contacts, and directional estimator. This closes
the scoped MuJoCo behavior lane and permits authoring a fresh finite
three-engine decision; the single-cell architecture still cannot establish
portable turning by itself.

## R23D74 consumed three-engine physical boundary

The [R23D74 declaration](../sdk/turning/r23d74_fresh_finite_three_engine_turning_decision_v1.json)
froze one held-out seed and the complete three-engine-by-three-arm **finite
decision**. It added no fourth controller or duplicate physics path. The final
[content-addressed implementation](../sdk/turning/r23d74_production_route_three_engine_turning_implementation_v1.json)
bound `229` exact dependencies at clean-pushed `32b9db7f` and used thin
campaign bindings over the existing native Godot/Jolt, Rapier/Parry, and
MuJoCo production routes.

Four retained qualification histories exercised that architecture. The first
passed `12` global checks and failed at the nested campaign lock. The second
passed `3` and failed inventory provenance. The third passed `16/16` on an
uncommissioned MuJoCo-venv Python identity and was correctly refused by
adoption. The fourth passed `16/16` on the exact LCA1 system Python identity
and was adopted. All `9/9` authorization receipts then passed; every native
world completed its `2,992`-step horizon and preserved a raw trace. Six
Godot/Jolt and Rapier/Parry paths produced success terminals with CAS-backed
traces, while three MuJoCo paths preserved complete raw traces and produced
worker-failure terminals during trace publication.

The failure localizes a real contract split. The native MuJoCo worker recorded
the unconditional `canonical_velocity_smoothstep_one_gait_cycle_v1` startup
transform. The inherited complete evaluator instead rebound those cells to
`support_loss_latched_smoothstep_one_cycle_v1`, producing
`R23D58_STARTUP_TRANSFORM_INVALID` before trace publication. Thus the source
was internally inconsistent at the native trace/evaluator seam even though all
nine physics horizons completed. This is deterministic integration invalidity,
not a physics or threshold failure.

The [immutable physical closure](../sdk/turning/r23d74_production_route_three_engine_turning_validation_closure_v1.json),
[closure audit](../tests/test_qsdk_r23d74_physical_closure.ps1), and
[live-authority audit](../sdk/audit_r23d74_zero_world_implementation_authority.ps1)
bind the exact qualification and physical populations. No result may bypass
the complete evaluator, so R23D74 establishes no official turning claim. Seed
`23193` and attempt `9dbe54d9cc8241b0bf40da3b4b28b541` are consumed and
cannot be rerun or selectively repaired. `QSDK-R23` remains false and release
readiness remains `10/25`. The required architectural successor is a distinct
zero-world native startup trace/evaluator conformance contract; only a later
fresh finite decision may reopen physics.

## R23D75 engine-aware startup evaluator boundary

R23D75 adds one process-local binding layer without changing any observed
worker or historical evaluator. The
[contract](../sdk/turning/r23d75_native_startup_trace_evaluator_conformance_v1.json)
maps declared native engine identity to an immutable startup specification:
Godot/Jolt and Rapier/Parry bind the support-loss-conditioned governor, while
MuJoCo binds the unconditional one-cycle governor. The same accepted trace,
task-origin, actuator-observation, and public-profile algorithms then validate
the native rows under that selected specification. A process lock serializes
the inherited evaluator's process-local module binding, and an unknown engine
fails closed.

The architecture is verified at two layers. The compact layer enumerates all
three mappings, both mechanisms, boundary/support branches, `19` mutations, and
unknown-engine refusal without constructing physics. The retained integration
layer replays every exact R23D74 trace—nine files and `26,928` rows—and all pass
their native startup shape plus the shared retained-trace contract. Authority
is the [closure](../sdk/turning/r23d75_native_startup_trace_evaluator_conformance_closure_v1.json)
with [executable audit](../tests/test_qsdk_r23d75_native_startup_trace_evaluator_conformance_closure.ps1).

This closes an evaluator architecture seam for a distinct future campaign. It
does not mutate or repair R23D74, compute a turning result, change a threshold,
or authorize a world. `QSDK-R23` and readiness remain `10/25`; a fresh finite
decision must separately freeze a new identity and seed before physics can
reopen.

## R23D76 finite turning decision boundary

R23D76 freezes the next score-bearing question without yet opening physics.
Its [contract](../sdk/turning/r23d76_fresh_finite_three_engine_turning_decision_v1.json)
enumerates the complete three-engine by three-arm matrix on fresh held-out seed
`23197` and keeps the production controller, `2,992`-step schedule, semantic
measurement origin, common physical gates, and `0.01` rad directional floors
unchanged. Each native lane selects startup semantics solely through the
R23D75-closed engine-aware binding. The question class is finite decision; no
equivalence margin or arbitrary-population claim is present.

Its [declaration audit](../sdk/audit_r23d76_fresh_finite_three_engine_turning_decision.ps1)
proves seed freshness, deterministic fixture compilation, all nine cell
identities, and `12` mutation refusals with zero models and worlds. The native
implementation now content-addresses `222` dependencies. Its complete compact
[zero-world gate](../tests/test_qsdk_r23d76_zero_world.ps1) proves all three
native preflights, the selector and authorization negatives, nine receipt
positives, declaration and terminal mutation controls, both predecessor
replays, the engine-aware evaluator controls, and unsupported-engine refusal
with zero models, worlds, or solver steps and no full seeded ghost.

The three native adapters may next perform only a non-held-out smoke of at most
one world and two solver steps each, testing construction and initial stepping
rather than behavior. Held-out physical qualification remains unauthorized and
readiness remains `10/25` until a future valid-complete positive closure.

## R23D78 finite three-engine turning closure boundary

R23D78 supersedes the open R23D76 implementation narrative without changing
the immutable R23D76 result. Its
[contract](../sdk/turning/r23d78_fresh_finite_three_engine_turning_decision_v1.json)
freezes fresh seed `23199` across the complete three-engine by three-arm matrix
and preserves the controller, startup mapping, schedule, measurement origin,
behavior estimator, thresholds, and selector. The only new evaluator layer is
the R23D77 existing-file CAS identity wrapper: it may replace only the exact
path-identity singleton after both payload and manifest identify the expected
existing files, then must rerun the complete frozen byte verifier.

The [declaration audit](../sdk/audit_r23d78_fresh_finite_three_engine_turning_decision.ps1)
proves the identity, seed fixture, nine-cell population, and mutation boundary
without constructing a model or world. R23D76 already commissioned every
unchanged native route through bounded smoke and nine full horizons, so R23D78
adds no redundant smoke. Precise invalidation restores that requirement if a
native worker, shared kernel, model-construction path, startup transform,
controller, schedule, actuation, or observation changes. The next architecture
layer is therefore compact zero-world binding and complete mutation coverage,
followed by exact clean-pushed qualification and separate adoption.

The first exact clean-pushed qualification at source `0e479979` passed three
global gates and failed closed at `CAK1-EVIDENCE-PROVENANCE` before any
campaign-local role or physics. The `.gitattributes` LF extension had not
atomically rebound the provenance contract's moving current-checkout identity.
The architectural successor preserves that complete `13`-file failure, rebinds
only the current identity, and reconciles exactly one missing pre-existing
R23D76 closure-audit inventory entry (`183` to `184`, no changed or removed
entry). The campaign manifest now content-addresses the provenance contract,
inventory, and executable gate in addition to the original `230` sources. This
changes no physical or scientific semantics.

The qualification architecture now also makes its Python runtime partition
explicit. The generic outer attestation remains commissioned on the system
Python identity; the native MuJoCo lineage gate resolves the repository's
qualified MuJoCo environment through its existing default. A compact ghost
first proved that forwarding the outer interpreter fails before a lineage
marker with no physical launch, then the corrected no-override route passed the
complete lineage and three-role population with zero worlds.

Clean-pushed, live-equal source
`7b876726ba1471c6acd228181a877bd18bbb08a3` then passed all `16/16`
qualification gates and separate exact-key adoption. Its single authorized
physical attempt completed the full `3`-engine by `3`-arm architecture: nine
native worlds, nine `2,992`-step horizons, nine retained CAS traces, and one
complete frozen evaluation. All engine cells obeyed the shared public-policy
command semantics and the complete evaluator accepted each engine's raw-signed
and reference-conditioned cycle-integrated turning gates.

The immutable R23D78 closure pins every implementation dependency to the source
commit's Git blob, binds the exact `50`-file qualification/adoption population
and `72`-file physical population, and rejects drift in every terminal, trace,
report, and claim field. Architecturally this closes the finite portable basic
turning requirement and satisfies `QSDK-R23`, moving readiness to `11/25`.
The shared semantics and finite conjunction are established; formal numerical
cross-engine equivalence, repeatability, population robustness, arbitrary
morphology, prone-to-standing, physical acceptance, and release remain separate
unimplemented or unproved boundaries.

The portable controller and native physics semantics are unchanged for
QSDK-R23D65. The current architectural work is the exact orchestration needed
to carry one frozen public-policy command and one complete terminal identity
through Godot/Jolt, Rapier/Parry, and MuJoCo without silently changing the
scientific question.

R23D65 repairs seven integration edges derived from the immutable R23D64
failure population:

1. Rapier registers the campaign under its own namespace.
2. Godot resolves and records all eight exact hinge bindings before SceneTree
   insertion and carries that receipt into world construction.
3. Rapier sends evaluator output through the declared child PowerShell host
   with `-ExecutionPolicy Bypass` and then through the content-addressed
   publisher.
4. MuJoCo bridges the inherited private preflight entry point without changing
   its schedule semantics.
5. Every engine emits a complete immutable terminal identity on worker failure.
6. The supervisor preserves those terminals and normalizes world counts without
   replacing worker truth.
7. The sole canonical evaluator accepts every declared complete failure
   terminal while still rejecting identity mutation and incomplete matrices.

These edges form a complete seven-item source-conformance population. The
zero-world gate passes `7/7` with zero equivalence and non-inferiority margins,
and the recursive dependency authority fixes the source surface at `237` paths
and `238` edges. This establishes orchestration conformance only. Exact
clean-pushed source `15e308aa4f61d9a5d382f90fdef59f41cee32438` then failed
closed at the fourth global qualification gate because the retained
executable-evidence inventory omitted R23D65's new dependency-closure audit.
The correction extends the complete inventory from `172` to `173` audits by
exactly one entry, changes or removes none, and binds every byte of the retained
`13`-file, `12,703`-byte failure. This provenance maintenance uses no sampling,
zero equivalence/non-inferiority margins, and changes no controller, physics,
threshold, selector, evaluator, result, or interpretation.

R23D65 has opened no physical world, and no turning, physical equivalence,
prone-to-standing, acceptance, or release claim follows until the distinct
corrected clean-pushed source is freshly qualified, separately adopted, and its
one-time nine-cell finite decision closes positively.

## Current engine-neutral actuation-semantics boundary (2026-07-31)

The durable architecture remains **plan → track → emergent**, but the current
SDK audit exposed a portability defect in where tracking feedback and host
coordinate conversion were implemented. This section is the authority for
new SDK work; the historical design record below explains how the architecture
was reached and is not erased by the correction.

At audited source `22ca385a80070c3cbbc1d71a341dd4a879f8bfce`, the
portable selected controller computes a complete closed-loop velocity command:

```text
raw canonical velocity = 8 * position error - 0.65 * measured joint velocity
emitted velocity        = raw canonical velocity * -1
```

That final `-1` is the characterized Godot/Jolt host-motor sign, not a
canonical controller sign. Godot/Jolt applies the emitted result only to
`HingeJoint3D.PARAM_MOTOR_TARGET_VELOCITY`, so the existing output correctly
reproduces the retained working Godot/Jolt behavior. Rapier declares a
canonical-to-host velocity sign of `+1`, however, and applied the same base
velocity without converting it while adding a correctly signed canonical
stability residual. It then supplied both portable position and composed
velocity to a ForceBased motor with stiffness `40` and damping `10`. The
Rapier path therefore mixed base and residual coordinate spaces and added an
independent native position loop around an already complete portable feedback
loop.

The retained zero-world/source diagnostic is
[`../sdk/rapier_c6_bw19v_actuation_semantics_diagnostic.json`](../sdk/rapier_c6_bw19v_actuation_semantics_diagnostic.json),
with executable audit
[`../tests/test_rapier_c6_bw19v_actuation_semantics_diagnostic.ps1`](../tests/test_rapier_c6_bw19v_actuation_semantics_diagnostic.ps1).
Its constructive zero-state example requests `+0.3 rad`: the portable law
computes canonical `+2.4 rad/s` but emits legacy Godot host `-2.4 rad/s`; the
Rapier combined `40/10` nominal law is consequently `-12 N m`, opposite the
position error before force limiting. ED1 independently shows the defect was
physically active: at semantic step `0`, all `5/5` nonzero position targets
have opposing velocity signs, the next joint angles oppose the position signs,
and those angles match the velocity signs. This is a confirmed cross-host
actuation-semantics defect. It does **not** establish that the defect alone
caused ED1 torso contact, or that a corrected Rapier realization will walk.

The first corrective boundary is now implemented under the separate
[`LOCOMOTION_SEMANTICS_V4.md`](LOCOMOTION_SEMANTICS_V4.md) identity and
[`../sdk/canonical_velocity_actuation_profile_v1.json`](../sdk/canonical_velocity_actuation_profile_v1.json)
declaration. The portable core wraps the immutable legacy frame, converts its
Godot-oriented velocity to canonical space, composes the stability residual in
that space, clamps once, and leaves the final sign conversion to a typed host
profile. Position is retained only as provenance/bounds evidence. Focused
zero-world tests prove `8/8` bit-exact Godot legacy commands and distinguish
the former Rapier mixed-space expression on all `5/5` nonzero legacy commands.
Rapier now consumes this exact live v4 path. VH1 closed positive for its exact
finite ForceBased zero-stiffness velocity-only host characterization, including
builder and mutable readback, signed responses, force limits, and host
precision. The first selected-composition mechanism study, EH1, then consumed
its two declared worlds but produced an invalid primary report because its
synthetic/evaluator pair shared a nonexistent profile ID and conflated bounded
pre-clamp residuals with effective post-clamp host changes. Its complete trace
is retained only as post-hoc development evidence; EH1 is closed and cannot be
rerun or promoted. The scientifically distinct LC1 long-horizon finite
technical-commissioning study subsequently consumed its one declared world.
Its primary report is also invalid: the evaluator compared scheduler-ordered
limb memories with morphology-ordered limb IDs by array position, while its
synthetic report used only morphology order. Identity-based post-hoc
reconstruction removes the four resulting cascade failures but leaves the
frozen terminal-four-contact gate failed. LC1 advanced about `1.894 m` with no
torso contact and remained upright, but its front-left foot stayed airborne
after the completed gait memory froze at a raised-leg reference. This is useful
successor-design evidence, not a valid primary result. The scientifically
distinct TS1 successor matched limb memory by explicit `limb_id`, used the real
scheduler order in its perfect synthetic trace, preserved LC1's walking-evidence
segment, and actively advanced from gait step `1912` to analytically all-stance
gait step `1970`. Its complete 3,172-step zero-world gate and 23 negative
controls passed before its one world opened. The retained TS1 primary report is
a complete valid negative with one failure: front-left contact ended at step
`2094` and never returned, despite all four memories reaching `1970` at step
`2151` and 1,020 subsequent hold steps. The final front-left contact site was
about `0.03025 m` above the mean of the three contacting sites. Thus
`local_phase >= swing_steps` is an analytic schedule classification, not proof
that the reference restores physical contact through a particular host.
Rapier walking, selected-policy physical C6, cross-engine equivalence, and
release authority remain false.

The correction does not kill reference tracking, the working Godot/Jolt
architecture, BW19V's bounded evidence, the stability residual, or Rapier as a
host. It sharpens the ownership rule:

1. A new versioned semantic profile must emit host-independent canonical joint
   position and velocity signs. Frozen predecessor outputs remain immutable.
2. Canonical-to-host sign and coordinate conversion exists only in the host
   adapter.
3. For the BW19V successor profile, the complete portable closed-loop velocity
   is the load-bearing reference-tracking command. Requested and clamped
   position remain controller provenance and bounds evidence; the adapter may
   not add a second independent position-feedback loop.
4. Base and stability-residual velocity contributions compose in one canonical
   space before one final host conversion and clamp.
5. Godot/Jolt retains exact host-command equivalence to its characterized
   velocity-only behavior. Rapier's VH1 authority is limited to the exact
   finite ForceBased zero-stiffness velocity-only realization it measured; it
   is not selected-policy walking evidence.
6. Every successor integrity gate must accept a complete perfect synthetic
   zero-world result and reject semantic, production-fidelity, and authority
   canaries before any physical world. An invalid primary report remains
   invalid even when a post-hoc reconstruction is encouraging. A successor
   must use a new identity, preregistration, and source freeze rather than
    editing or rerunning the failed campaign.
7. Array position is not identity across independently ordered domains. Limb
   memory, morphology, scheduler, contact, and actuator records must be joined
   by explicit typed IDs, with complete/unique identity-set checks and a
   synthetic witness that exercises the real production ordering.

Reference tracking remains honest when a characterized host velocity servo
produces bounded physical joint forces: the plan is a reference, contacts and
dynamics determine realized motion, and no root or body write supplies
locomotion. What portability forbids is silently duplicating or changing the
feedback law at a host boundary.

## Live Explorer control plane (2026-08-04)

The showcase/debugger is a control plane over native physics, never a motion
source. Its first engine-neutral transport is
`sporespore_live_explorer_protocol_v1`:

```text
Godot workbench / viewer
  |-- starts a fresh native worker
  |-- receives hello + exact render scene
  |-- receives a body/contact frame after each real outer physics step
  |-- releases a shared post-preflight start barrier for comparison
  `-- may schedule a bounded canonical development impulse

Rapier worker                        MuJoCo worker
  |-- Rapier World::step()             |-- five real mj_step2 substeps
  |-- native RigidBody poses            |-- native MjData body poses
  |-- native contact pairs              |-- native contact array
  `-- RigidBody::apply_impulse           `-- xfrc_applied for one outer step
```

The Rapier hook is opt-in and lives beside, not inside, the frozen PH1
campaign implementation. The MuJoCo worker wraps the existing MV6 robot class
at process runtime and does not edit the frozen MV6 implementation. With the
Explorer transport disabled, accepted campaign entrypoints do not emit frames,
read commands, pace wall time, or change their native step path.

Every message carries engine identity, engine version, session identity,
native-physics and replay booleans, frame number, simulation and wall time, and
an explicit false scientific-evidence-authority flag. Renderers consume native
body transforms after a step; they cannot author a transform or feed a
rendered pose back into physics. A retained trace may later be inspected in a
separate replay mode, but a replay must never carry `native_physics=true`.

Physics/control frequency and observer frequency are separate. The MuJoCo
worker retains its exact `120 Hz` outer control loop and five native substeps,
while emitting ordinary read-only render packets at `30 Hz`; an impulse event
always forces an exact packet at its simulation frame. Frame indices therefore
remain physics-frame identities even when ordinary telemetry is decimated.
The viewer interpolates only its camera, never a physical body or receipt.

The first paired realtime-requested development smoke on source `6412dc4`
measured MuJoCo at `0.760x` simulation/wall time and therefore failed the
Explorer realtime range `[0.90, 1.10]`. The control and impulse paths were
complete, but the current Python-hosted MuJoCo live path is not realtime on
this machine. Telemetry decimation may not be presented as a physics-rate
increase, and the viewer must display the measured ratio.

The initial command surface permits only a finite, scheduled torso impulse:

- canonical `x-forward, y-up, z-right` impulse vector;
- explicit target simulation frame;
- exact command ID and native application receipt;
- maximum magnitude `8 N s`;
- target body fixed to `torso`;
- development authority only.

For a simultaneous multi-engine launch, Rapier and MuJoCo run their complete
zero-world gates and settle paths, emit `ready_to_start`, and block before the
first load-bearing Explorer actuation. The workbench verifies one source-bound
ready receipt from each native worker, creates one repository-local start-gate
receipt, sends `start` to both transports, and opens the Jolt physical window.
No native worker may step through the showcase horizon early merely because
its preflight finishes first. Standalone development viewers do not request
this barrier and start normally.

The impulse is an operator disturbance, not locomotor authority. Rapier uses
its native instantaneous rigid-body impulse. MuJoCo applies the equivalent
world-frame force over exactly one `1/120 s` outer step across the five native
substeps, then clears the external-force slot. A shared-frame command can be
sent to both workers for a live comparison, but the resulting fall, stumble,
or recovery is only a development observation. Terminal four-contact
restoration after an ordinary walk is not push recovery, fall recovery, or a
prone-to-standing get-up result.

The current transport worker is exact-s169 first. A later descriptor-bearing
worker must compile the edited bounded descriptor independently in each host,
return a compatibility receipt before opening worlds, and label every fresh
shape as supported, unsupported, or unvalidated. Random generation is allowed
as an exploratory queue; no UI may promise that every generated quadruped will
walk while arbitrary-morphology and continuous-domain authority remain false.

## Adaptation provider and tier boundary (2026-08-05)

The public SDK must contain a stable optional-provider seam before a learned
provider is trained. The deterministic portable controller remains the owner
of scheduling, safety bounds, and final canonical command composition. With no
provider installed, its output is unchanged. A provider receives only
versioned morphology, canonical observation/history, task, baseline output,
provider memory, capability, seed, and provenance data. It returns only a
bounded canonical correction or parameter proposal, confidence/support/OOD,
memory, diagnostics, and an append-only candidate-lesson event.

The provider cannot read or mutate a native world, apply a native force, write
a body transform, replace a safety bound, or publish an encyclopedia chapter.
Invalid, stale, uncertain, unsupported, or absent output fails to the
deterministic baseline with a reasoned receipt. Host adapters remain mechanical
semantic translators and never become learned-policy owners.

Tier 1 is deterministic descriptor conditioning plus the versioned behavior
encyclopedia. Tier 2 is an offline-trained morphology-conditioned provider
whose candidates must pass independent cross-engine qualification. Tier 3 is
the required online/long-context destination, but it retains an immutable base,
bounded memory/output, rollback, and offline chapter/model promotion. The
complete data flow, candidate-chapter lifecycle, MJWarp training boundary, and
three product checkpoints are authoritative in
[`SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md`](SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md).

The implemented v1 seam is normative in
[`../sdk/adaptation_provider/provider_contract_v1.json`](../sdk/adaptation_provider/provider_contract_v1.json)
and [`../sdk/core/src/adaptation.rs`](../sdk/core/src/adaptation.rs). The public
resolution record carries the full provider request plus an optional raw JSON
response so malformed provider output can be observed and reduced to baseline
without making the host request unparsable. Invalid host state, command,
descriptor, history, memory, or safety authority still returns a typed core
error. Accepted proposals are canonical velocity deltas only, composed through
absolute, slew, and actuator-speed clamps before the adapter-owned host map.

The executable Tier 2 successor boundary is
[`../sdk/adaptation_provider/tier2_architecture_v1.json`](../sdk/adaptation_provider/tier2_architecture_v1.json).
An episode may become a candidate chapter; it cannot edit the current
encyclopedia. A frozen corpus may produce a new immutable model candidate; it
cannot change its split after observing results. A model can be promoted only
to new encyclopedia/provider identities after the required three-engine
qualification set. MuJoCo Warp remains a discovery/training plane rather than
a promotion engine.

The deterministic post-episode layer is versioned separately in
[`../sdk/adaptation_provider/experience_encyclopedia_contract_v1.json`](../sdk/adaptation_provider/experience_encyclopedia_contract_v1.json).
It summarizes only already-canonical ordered observations and never reads a
native world. Characterization is threshold-free and outcome-neutral; the
question owner separately records one of five finite result classes. Candidate
experience objects are content-addressed, while append events form a
create-only predecessor hash chain. A stale parent, duplicate, mutation, or
orphaned incomplete object stops further appends. This candidate ledger cannot
rewrite the deployed behavior encyclopedia, become a training corpus by
itself, mutate a provider, or grant scientific, physical, or release authority.

MuJoCo Warp training is additionally gated by
[`../sdk/adaptation_provider/mujoco_warp_supported_subset_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_supported_subset_contract_v1.json).
The source/runtime preflight is development-only and opens zero worlds. A
distinct equivalence/non-inferiority qualification must freeze calibrated
margins and held-out topology/morphology/material/task/contact cohorts before
any Warp-generated episode can become training-plane input.

## Portable heading-command boundary (2026-08-05)

The selected `BW5R-B` portable policy already implements absolute-heading
steering through `sporespore_motion_command_v2`; turning does not require a
second controller API. `desired_heading_rad` is an absolute world yaw in the
canonical x-forward, z-right coordinates. Omission means hold
`task_frame.reference_yaw_rad`. The runtime wraps the shortest angular error,
applies the existing cross-track terms, clamps desired error to `0.25 rad`,
maps it through the selected policy's `1.3/rad` yaw gain, clamps steering to
`0.40`, filters it through versioned controller memory, and scales hip stride
bilaterally as `left=1-held` and `right=1+held`.

The same command and receipt schemas cross the stateless and persistent C ABI
and Python surfaces. Heading plus yaw rate is schema-invalid; yaw rate alone
is unsupported by the selected policy. Both cases return the ordinary ordered
safe-zero actuation frame with a typed failure, rather than granting the host
permission to improvise.

Controller memory initialization is policy-specific. Hosts must call
`ss_balanced_wave_policy_initial_memory_json` (or the corresponding Python or
Godot method) with the same named policy and descriptor used to create/step
the controller. The legacy no-input initializer exists only for compatibility
with stateless balanced-wave policies. A stateful policy paired with legacy
memory must fail safe; an adapter must never infer, patch, or silently upgrade
the memory schema itself.

The normative source-only contract and H0-H8 fixture live in
[`../sdk/turning`](../sdk/turning/README.md). They exercise the public release
DLL, including every vertex of the six-field bounded descriptor box, while
building zero worlds. This makes the command mechanism an explicit SDK
precondition; it does not establish that a real body turns or walks straight
under zero command. QSDK-R23 remains blocked until a distinct prospective
real-physics campaign passes commanded turning and zero-command compatibility
in every advertised engine.

The decision (2026-06-30): creatures move by **plan → track → emergent**.

- **PLAN (procedural / kinematic):** a skeleton-aware kinematic model computes where every joint and
  foot *should* be over the gait cycle — a spine constraint-chain for the body, FABRIK for limbs,
  anchored-foot step-triggering for the gait. This is the "backboard": correct-by-construction motion.
- **TRACK (honest control):** the real Jolt creature drives its joints with **torque** toward the
  plan's reference angles (PD feedback + gravity-comp feed-forward), capped by muscle/`tau_cap`.
- **CONSEQUENCE (physics-emergent):** the body actually moves because gripping feet + joint torques
  make real forward force. It can be pushed, trip, slip, and fail honestly. We give up "the gait
  emerged from nothing"; we keep "the locomotion is produced by real forces."

This dissolves the wall the pure-CPG hit. The CPG drove each joint as an *independent sinusoid* and
hoped walking would emerge — but the hard part (keep the planted foot down while the body rolls over
it; sequence the steps) was left to emerge and didn't (worming/bellying — see the contact metrics).
The plan **provides that coordination**; the physics only has to execute it.

## The honesty line (what keeps it physics-emergent, not animation)
- ✅ track reference **joint angles** with **torque**. Propulsion = gripping feet × joint torques.
- ❌ never kinematically pin a foot's world position, never shove the body with a central force.
- **Gravity compensation via joint torque is honest** (it's what muscle does — torque at the joint,
  reaction at the ground through the leg). The deleted "posture lift" central force was the cheat.
- **Slip is the honest failure:** if foot normal-force × friction is too small, the foot slides and
  the body falls behind the plan. You can't torque out of it — the *assembler* must give the creature
  enough foot/grip/mass. (This is the honest version of "the foot must grip to propel.")
- **How tightly you track is the dial** between emergent (loose PD, reactive, shove-able) and
  animation (tight PD, precise, overrides contacts). Target: moderate PD + gravity-comp, let contacts
  move the body freely. The honesty test: shove it and it should stumble.

## Shared skeleton
The creature's `PartGene` tree folds (via `CharacteristicsEvaluator.fold_graph`) into parts + joints.
That SAME fold is the rig for BOTH the Jolt body (`CreatureBody`) and the kinematic plan — segment
lengths, joint positions, axes, limits, foot parts. The plan is only feasible if generated from the
body's real geometry, so they must share one source of truth (the fold). No separate "ideal" rig.

## Modules (to build)
1. **KinematicSkeleton** — reads a fold → segments, joints (pos/axis/limits), feet. Shared rig.
2. **SpineChain** — node chain with distance + angular/curvature constraints; solved with
   FABRIK-style passes (or Verlet/PBD). Body for snake/centipede; the trunk for limbed creatures.
   Parametric body outline (radii profile → left/right via bisector normals; head/tail caps) for the
   visual + collider sizing.
3. **FabrikLeg** — IK: given hip (root) + foot target + segment lengths + joint limits → joint
   angles. Forward/backward reaching, constraint clamps folded in.
4. **GaitPlanner** — the anchored-foot stepping: each foot has a body-relative rest offset; the
   planted foot stays world-fixed while the body moves; when it overextends past `step_length` it
   lifts and arcs to a spot *ahead* of the rest (anticipation); phasing groups (trot = diagonal
   pairs; hexapod tripod = {1,4,5}/{2,3,6}; wave for many-legs). Step triggers read the REAL foot
   positions (from the contact sensors) → closed loop, reactive to terrain/pushes.
5. **ReferenceTracker** (the controller) — each tick: GaitPlanner + FABRIK give reference joint
   angles; drive joints with torque = PD(error) + gravity-comp feed-forward, clamped to `tau_cap`.

## Prior art — what this maps onto (refs Cole vetted, 2026-06-30)
Our "track a reference joint trajectory with real, capped torque" is the textbook control law
**Computed-Torque Control (CTC)** / feedback linearization. The canonical teaching artifact is the
**2-link manipulator** (hip + knee, two segments) — mathematically *a leg*, the exact minimum a
trotter's leg needs. CTC's full law is `τ = M(q)·(q̈_des + Kd·ė + Kp·e) + C(q,q̇)·q̇ + G(q)`.

What we take vs. drop, given **Jolt is our dynamics integrator** (we do NOT integrate the equations
of motion ourselves — that's the whole point of using a physics engine):
- **`M·q̈ + C` (inertia + Coriolis feed-forward):** DROP the explicit computation. Jolt's articulated
  solver already produces these reaction forces when we apply joint torque; computing them ourselves
  would duplicate the engine and is intractable for arbitrary procedural morphologies. The PD term
  absorbs the residual.
- **`G(q)` (gravity comp):** KEEP, as an honest feed-forward. The torque needed to hold a limb's
  weight at its current pose is exactly what muscle tone does; adding it tightens tracking *without*
  any reaction-less force. This is the one concrete CTC upgrade to the current drive loop (which today
  is pure PD `kp·e − kd·ω`, no feed-forward) — see build order step 1.
- **The honesty clamp:** CTC's textbook form is a high-gain tracker that will overpower contacts. We
  clamp the output to the muscle/`tau_cap` budget and let it *under-track*. Under-tracking IS the
  honest failure (the body falls behind the plan, slips, stumbles) — never raise the cap to force the
  pose. This is already how `cpg_controller` caps every joint torque.

**Whole-body control + MPC (the Unitree Go2 `wbc-mpc` repo):** this is the modern gold standard —
an MPC picks footstep timing + a CoM trajectory over a horizon, a per-tick QP (WBC) solves for joint
torques + contact forces under friction-cone and torque-limit constraints. It is the right *north
star* but the **wrong vehicle** for us: (a) the MPC needs its own predictive dynamics model → it
duplicates Jolt; (b) the WBC needs a live QP solver (OSQP/qpOASES) we'd have to port to GDScript;
(c) it's welded to MuJoCo's `mjModel`/contact-Jacobians and assumes one fixed 12-DOF morphology, while
our creatures are arbitrary procedural topologies. We harvest its **decomposition** — footstep/contact
schedule (→ GaitPlanner), swing-foot trajectory (→ FabrikLeg), stance torque law (→ ReferenceTracker
PD+gravity-comp) — and get ~80% of the behavior at ~5% of the complexity, honest by construction
because we only ever command capped joint torque, never solve for contact forces.

**Inverse-dynamics / gait-analysis repos:** these are *analysis*, not control (they back out the
torques that produced recorded human walking — the wrong direction for a controller). Their use to us
is as a **validation oracle**: the target *shape* of a real gait — stance/swing duty factor, joint
torque curves, foot-contact timing. We compare our contact-sensor output (`foot_plants`,
`true_airborne_frac`, duty fraction) against that shape; we do not run their code.

Bottom line for the build: the architecture below is already the right one; CTC names it and hands us
the gravity-comp feed-forward; WBC-MPC confirms the module decomposition; the ID repos give the
validation target. Nothing here changes the plan — it sharpens step 1 (add gravity-comp) and step 4
(the GaitPlanner's contact schedule is the MPC's job, done kinematically instead of by QP).

## Differential diagnosis — why the QUAD doesn't step (2026-07-01, live-probe finding)
Cole's agent gave the right framework: walking has six links that must ALL hold, and a geometric
reference fixes only coordination. The contact sensors are the differential diagnosis. A live probe
(`debug_track`: per-tick body_y / up / foot-clearance / slip / torque-saturation) pinned the quad's
failing link precisely:
- The quad STARTS standing tall + upright (body_y 0.74, up 1.0, torque well within budget: sat 0.2).
- Once the gait cycle begins, the demanded torque JUMPS to 3.6× the muscle cap and STAYS there, and
  the body slowly sinks 0.74 → 0.45 → topples (up 1.0 → 0.70).
Sustained `sat >> 1` while sinking = the tracker demands torque it can't deliver, and it *starts fine
then diverges once the cycle starts*. That is link **#2 (reference↔physics desync)**: the GaitPlanner
sweeps the STANCE foot backward in the BODY frame at an ASSUMED gait speed, but the physics body moves
slower (weak propulsion), so the swept target runs away from the planted foot → position error explodes
→ joints saturate → sink. Confirmed live. (Link #1 stance feed-forward is NOT the quad's bug — the Jᵀ
tracker DOES have gravity-comp + a stance-support downforce; #1 is the frog's problem, since the frog
uses the sinusoid PD drive which has no feed-forward.)

**Resolution (2026-07-01) — the quad now WALKS (fwd ~7 m, up_min ~0.73, traction 0, 185 foot plants).**
Five changes, each attacking one diagnosed link, landed it. In the order they mattered:

1. **Metronomic timing + world-locked stance (#2 desync).** The gait clock (GaitPlanner phase, per-leg
   offsets) decides only WHEN each foot lifts; the stance foot is world-locked at its plant, NOT swept at
   an assumed speed. The clock guarantees the feet always cycle (no chicken-and-egg deadlock — a purely
   geometry-triggered step never fires if the body isn't already moving), while the world-lock kills the
   desync (the target no longer runs away from the planted foot).
2. **Contact gate (#3).** A foot the clock calls "stance" only bears weight / propels / world-locks when
   it is actually within contact_eps of the ground. A still-airborne "stance" foot just reaches DOWN to
   plant (no phantom mid-air support). And the plant is locked at GROUND level, not at whatever height the
   foot had — locking the raw y latched hind feet in the air and perpetuated a tail-up pitch.
3. **Lighter body (#5 feasibility — the big one).** A knee's torque cap is INERTIA-limited
   (`cap = (base + k·muscle_frac)·I_subtree`); the shin+foot subtree is tiny, so the knee saturates ~89
   N·m no matter the muscle. A near-straight stance leg under a 92 kg body buckles once load×deflection
   passes that cap — the legs collapsed from their 0.71 m reach to a ~0.35 m belly-drag crouch. Halving
   the body density (680→300) keeps the buckling moment under the cap; the legs now stand a stable column.
4. **Walker-aware spawn.** `_spawn_y` dropped every creature with its soles 0.4 m up; that free-fall slams
   a tall-legged walker into a collapsed pose its extensors can't recover from. Leg walkers now spawn
   standing on their feet (a 3 cm settle gap) and hold their stance through the settle ticks.
5. **Hip-lean propulsion.** Propulsion is NOT a backward foot force (that fought the anchored-foot ratchet
   and inverted the travel direction — a long red herring). It's the hip extensor rest_angle: holding
   every hip at a fore-aft lean (+0.18 rad) angles the stance legs so the body vaults forward over them.
   The rest_angle is the speed+direction knob (0 stands, +0.18 walks -Z, negative reverses).

**What's still not honest — the remaining link, balance.** The walk currently classifies `assist_carried`:
it leans on the posture righting torque (a free root torque, scale 3.0) to stay upright. Drop it and the
quad belly-worms. Real balance must come through the LEGS — differential vertical foot force (leg-based
righting, scaffolded but inert) + capture-point foot placement (active, gain 0.10). Both are geometry-
limited by the quad's NARROW stance (feet at x=±0.16): the roll-righting moment arm is too short for the
knees (still cap-limited) to hold the body up on their own. The honest next step is a wider-stance
re-author (bigger support polygon + longer righting moment arm) so the free posture torque can come off.
The six links: #1 stance feed-forward (done — Jᵀ + gravity-comp), #2 desync (done — world-lock), #3
contact-triggered phase (done — contact gate), #4 grip/friction (ok — traction 0, feet grip), #5
feasibility (done for the quad — light body; the assembler validator is still unbuilt), #6 support-polygon
/ balance (PARTIAL — needs leg-based righting on a wider stance to shed the posture-torque assist).

## Balance feedback + shadow pacing (2026-07-01) — SIMBICON + the general recipe
The remaining link (#6 balance) got its named fix. Diagnosis from Cole's friend, stated as a force law:
*forward motion only happens from ground-reaction force while a foot is planted; a pose-tracker that
blindly copies the shadow's joint angles has no notion of "am I balanced?" — it jitters or topples.* The
three differential-diagnosis checks: (a) the root **is** dynamic (`RigidBody3D`, no freeze/kinematic) —
ruled out; (b) the tracker had gravity-comp feed-forward but **no COM balance feedback** — the gap; (c)
phase advances on a **paced timer**, not raw time.

- **SIMBICON** (Yin/Loken/van de Panne 2007), `cpg_controller` balance vector: the swing-foot target is
  shifted by the CoM state so the foot lands where it CATCHES the fall — `shift = c_d·(CoM − support) +
  c_v·CoM_vel`, capped to a fraction of leg reach (over-reach crosses legs → solver jam). This is what
  turned the spider from tipping (up −0.34) to upright + stepping (up ~0.8) at the right gain. Gain scales
  per creature by leg count (a narrow quad over-steers at the gain a wide splay needs).
- **Shadow pacing** (Cole's insight): the reference clock is clamped to lead the physics by at most one
  gait cycle (`GAIT_LEAD`), driven by real forward distance travelled. A struggling body is never chased
  by a target several steps ahead — that gap is what spiked the tracking force and jammed a foot through
  the floor (scorpion teleport 7.2 m → 0.08). A *soft* min-pace creep was tried and reverted: it let the
  reference drift ahead of a stalled body and re-blew the spider; the hard clamp holds.
- **Force safeties:** per-foot support cap (a tippy many-legger dropping to ONE grounded foot would press
  1.4× its weight through one thin foot → jam) + a total-foot-force clamp.

**The general recipe (validated on the quad, the tractable geometry): STAND → PROPEL → BALANCE.**
1. STAND (#5 feasibility): the legs must hold the body off its belly. A leg's joint torque cap is
   inertia-limited, and a splayed leg has a huge moment arm, so the body collapses onto its belly unless
   the body is light AND the legs are steep enough (short moment arm). Quad: light body did it.
2. PROPEL: a fore-aft (X-hinge) walker vaults on the hip rest_angle lean; a lateral (crab) walker uses the
   backward propel foot force. A Y-hinge splayed walker (spider) has neither a usable uniform lean (it
   would yaw, being L/R-antisymmetric) nor, once steep enough to stand, much stroke left.
3. BALANCE: SIMBICON catches the tip once the creature stands and moves.

**The splayed-leg wall (why spider/scorpion/crab/daddy-longlegs aren't solved yet).** Their identity is a
wide splayed stance, and that geometry is mechanically self-defeating for a walker: splayed legs give the
lateral/fore-aft power stroke (propulsion) BUT their long hip moment arm collapses the body onto its belly
(no stand); steepening the legs to stand kills the stroke (no propel). Measured on the crab: splayed →
`body_drag 1.0` (belly) + moves; steep (out 0.40/down 0.94) → `body_drag 0.67`, up 0.62 (stands) but
`fwd ~2 m` (barely moves). SIMBICON works but only *after* the creature stands, so it can't rescue a
belly-dragger. These need per-creature geometry re-authoring that trades some splay fidelity for feasibility
(or a fundamentally different propulsion, e.g. a proper metachronal wave with per-leg mirrored leans) —
a research effort, not a global tune. STATUS: quad walks (editor-verified via the shared `spawn_y`);
serpent/centipede (undulators) + frog/hopper (jumpers) + urchin/starfish (radial) + glider (aero) use
their own mechanisms and are suite-green; the splayed/biped leg-walkers stand-or-tip but stay finite.

## Data flow (closed loop)
```
contact sensors (who's on the floor) ─┐
                                       ▼
real foot/body state → GaitPlanner (step triggers, body velocity) → foot targets
                     → FABRIK / SpineChain → reference joint angles
                     → ReferenceTracker (PD + gravity-comp → joint TORQUE, capped by muscle)
                     → Jolt step (contacts, friction, momentum)
                     → back to real state
```

## Validation instruments (built 2026-06-30)
Real Jolt **contact sensors** in `sim_rollout`: `true_airborne_frac` (zero parts touching = real
flight), `body_drag_frac` (a non-foot part touches = worming/bellying), `foot_contact_frac`,
`foot_plants` (lift→plant transitions = real steps), `feet_lifted_ever`. These replaced the geometric
`airborne_frac`, which over-read on tilted feet and falsely scored the worming frog as 49% airborne.
The honest read: frog/hopper `true_air=0, body_drag~0.95` (worm); quad `body_drag=1.0, plants=0`
(bellies). The same per-part contact set drives the urchin's pogo (fire the prong most-opposed to the
heading).

## Build order
1. KinematicSkeleton + SpineChain + a serpent reference + ReferenceTracker — prove plan→track→emergent
   end-to-end on the creature that already moves (body-drag undulation is the simplest plan). Bake the
   **gravity-comp feed-forward** (CTC `G(q)` term) into the tracker here: per joint, add the torque
   that holds the child sub-tree's weight at the current pose, clamped under `tau_cap` with the PD term.
   This is the honest tightener that lets us track tightly without raising the cap.
2. FabrikLeg + GaitPlanner → make the quad take a real step (feet carry the body: `body_drag` low,
   `foot_plants` high). This is the proof that the architecture solves walking.
3. Roll out to biped/hexapod/segmented (gait phasing) + gallop; migrate frog/hopper to a real jump
   plan (synchronized loaded-leg extension with a true flight phase, `true_air > 0`).
4. **Assembler = capability spec + validator:** each locomotion archetype declares the skeleton it
   needs (segment counts, joint axes/ranges, proportions, foot attach). On assembly, run the
   kinematic model on the creature's REAL geometry: can FABRIK reach the gait's foot targets within
   limits, with enough grip to track? If yes → emit its reference + tracker params. If no → reject /
   pick a feasible gait / tell the user what's missing ("each leg needs a knee").
5. Flip default + delete the legacy cheats; restore every `DEFERRED-MIGRATION` assertion.

---

## 2026-07-02 — The propulsion resurrection (fresh-eyes audit + controller rework)

A multi-agent audit + live experiments answered "why does the honest quad only creep 0.22 m?" The
answer: **reference tracking was the right architecture and its propulsion had been removed by later
fixes** — plus four implementation bugs the docs never saw. Full detail in memory
`sporespore-locomotion`; the headline findings, all verified against source + git + live rollouts:

1. **The world-lock deleted the power stroke.** 8edda65 tracked the planner's moving stance sweep
   (the propulsion of reference tracking); 81e2148 froze the stance target at the plant point;
   eca2311's message admits it ("the world-lock stance replaced the OLD swept foot target, which was
   the propulsion"). `foot_target_local` had zero callers. The hip-lean "propulsion" that replaced it
   was a position hold that BRAKES once hips pass rest (3 legs braking, 1 driving = the creep).
2. **Shadow pacing deadlocked the clock** (`_ref_phase ≤ travelled/step_len + 0.5`): cycling needed
   travel, travel needed cycling. Measured: with sane gains the quad stands perfectly still forever.
3. **The 3 m bar was structurally unreachable**: freq × step_len = 1.17 Hz × 0.161 m = 1.89 m / 10 s
   even with perfect tracking.
4. **`hinge_angle` frame bug**: the delta quaternion (child-rest frame) was dotted against the
   parent-frame axis → all splayed-socket angles read 0.414× true. **Jᵀ pivot bug**: torque/gravity
   pivot was the segment CENTER, not the hinge anchor (hip 68% / knee 59% of correct torque).
5. **Null-space legs**: at the rest pose both quad leg joints move the foot purely fore-aft —
   vertical foot force maps to ZERO torque, so task-space control cannot LIFT (or firmly re-plant) a
   foot; lift is a second-order knee fold Jᵀ can't see. (This is why swing needs joint-space refs.)
   Related: the knee stance_spring never fires under the tracker (leg_tracked skips the spring pass).
6. **Yaw crosstalk is structural**: the hip world axes are ~24° from vertical (NOT the "fore-aft X
   hinges" the comments claimed), so every stroke yaws the body — walkers curved 1.5-2.6 rad off
   heading while "stalling" on the forward metric. Do NOT straighten the axes: that tilt is the
   leg's only lateral compliance (pure-X hips + pure-X knee over-constrain a planted flat foot —
   measured solver ejection).

### The reworked controller (cpg_controller `_apply_leg_tracking`)

- **Stance = plant-anchored body-frame sweep** (the power stroke, back): target starts AT the real
  touchdown and sweeps backward in the body frame — self-regulating (zero force at plan speed, push
  proportional to lag, error bounded by ~step_len), no startup mismatch.
- **Per-leg contact-anchored gait FSM** (sagittal walkers, `_swing_joint_pd`): each leg runs its own
  stance→swing cycle. Liftoff only when enough other feet bear (support guard — the last support
  never abandons the body) and one swing at a time; landing is contact-triggered on a TRUE touch
  (not the sticky bearing latch, which never releases below ~8 cm and was ending swings at half-arc).
  Authored phase offsets only stagger the start. Clock is a free metronome with a soft-start ramp.
- **Joint-space swing**: hip sweeps the step (+ SIMBICON fore-aft catch via the live Jacobian
  column), distal joints fold for clearance and extend to land; reach-down legs get the same PD
  toward the extended plant pose (task-space alone left them hanging mid-air forever).
- **Extensor split**: knee keeps the 0.9×cap strut tone; hip tone is 0.05 (the hold was the brake).
- **Balance stack**: SIMBICON caps split (lateral 0.4×reach, fore-aft 0.75×reach); leg-righting ON
  for hip-lean walkers with a tilt-RATE term (catches the fall while the tilt is small — a pure tilt
  gain steals hind-foot normal force and stalls traction); honest heading hold = differential
  fore-aft stroke left/right (tank turn through the feet, no root torque).
- **Authored gait fields**: `GaitDef.step_len` / `step_h` (the derived stride/lift were wrong for
  this body); quad_v2 bakes step 0.20 m, lift 0.06 m, duty 0.75, freq scale 1.45, gain 3.0
  (gain_scale 20 was silently making an 18,000 N/m foot PD out of the "softened" 900).

### Status after the rework (assist-off, seed-independent)

quad_v2: **+1.03 m / 10 s, upright the whole run (up_min 0.70), 21 real foot plants, a_ratio 0.000,
no teleport** — real load-bearing stepping (was: 0.22 m of foot-skating). Best hand-tuned configs
reached 1.5-1.6 m with sustained back-half progress; path length ~3-4 m (it walks; heading + speed
conversion are the remaining gap). **The 3 m straight-line bar is NOT yet met.** The remaining work
is multi-parameter tuning (freq/step/duty/lift/gains/balance interact chaotically) — exactly what
`GaitOptimizer` should sweep now that the mechanisms exist — plus possibly a lateral-hip DOF for a
cleaner lateral/heading authority.

### Addendum (2026-07-02, after Cole's editor screenshots): the aggregates lied about the shape

Cole watched the "walk" in the editor: it face-planted at ~3 s and nose-shuffled. He was right —
rendered-frame inspection (`scripts/sim/render_walk.gd`, the new visual diagnostic: viewer-equivalent
sim, PNG every 0.5 s) reproduced it exactly: `up_min 0.70, fwd 1.03` DESCRIBES a 45° pitch-dive plus
an early lurch; the aggregate never said "upright walking". Motion-shape validation is mandatory
(HONEST_MIGRATION already said so). Three more mechanisms landed from the frame-by-frame diagnosis:
- **Over-extension liftoff** (the STEP_TRIGGER semantic, finally wired): a planted foot trailing
  > 0.8×step behind neutral lifts NOW, jumping the one-swing queue — kills the hip-windup
  pole-vault that caused the deterministic ~3 s nose-over.
- **Late contact-landing gate** (touch counts only past 0.8 of the swing arc): first-skim landings
  planted every foot barely ahead of neutral, so the support polygon fell ~5 cm/stride behind the
  CoM — the face-plant was ON A TIMER. Brief toe-scuff is physical; chronic short-stepping is a fall.
- **Swing hip-arc clamp** (±0.5 rad): big references PADDLE the leg sideways about this rig's
  tilted hip axes (Cole's "odd actuation").
Current TRUE state (rendered + numeric): no face-plant (up stays ≥ ~0.79, typically 0.85-0.9),
~1.1-1.4 m / 10 s, gait visually a LISTING CROUCH-SHUFFLE — legs sprawl (near-free hips on
near-vertical axes), body rides low, heading still wanders. The Z-leg geometry is now the binding
constraint: its hip axes make strokes paddle/yaw, and it has ZERO leg-length reserve (knee bend only
shortens — a tilted body physically cannot re-plant its raised legs; measured parked-pose attractors).
RECOMMENDED NEXT: re-author quad_v2 with sagittal dog-style legs (mild splay, near-world-X hips like
the old flagship rig that demonstrably trotted) on a wider hip base — the controller NOW has the
lateral tools (weight-shift, SIMBICON, leg-righting, heading hold) whose absence originally forced
the Z-leg design. Keep validating by frames, not aggregates.

### 2026-07-02 (later): the SAGITTAL re-author — first stable periodic gait

Cole freed the quad's geometry (the Z-leg belongs to the FROG's leap design — opposed constrained
leg springs). quad_v2 is now a sagittal dog-leg walker (mild-splay near-world-X pitch hips, zigzag
thigh-back/shin-forward, feet under hips) — card renamed "Built-in Quad v2 (honest walker)". The
controller gates were re-keyed GEOMETRICALLY (`_swing_joint_pd` = hip axis mostly cross-track;
the old hip-lean proxy died with the lean), the distal fold direction auto-detects from the live
Jacobian's lift gain, and sagittal rigs skip the splayed-walker support press.

Chasing the frames surfaced three deep lessons (each measured, each documented in-code):
1. **The support down-press is propulsion contamination on a zigzag leg** — through Jᵀ it torques
   the knee, which shoves the foot down-backward: ~0.5 g of spurious forward thrust (instant
   launch + back-flip). Weight must flow through the strut (extensor / stance PD), not a commanded
   vertical foot force. Sagittal rigs now skip it.
2. **Foot targets must live in the YAW-FLATTENED body frame** (translation + heading only). Full
   body-frame targets rotate with pitch: body noses up → targets swing forward → task force drags
   the feet forward → support leads the CoM → more pitch. That positive-feedback loop slammed the
   settle's hips to their stops. Settle now WORLD-LOCKS the feet (an animal holds its feet, not a
   body-relative pose); all stance anchors store yaw-flat scalars.
3. **The stance hip needs a moving reference with matched damping — this is the OPEN problem.**
   The live-Jacobian-derived reference (position error ÷ live fg) softens under fold (fg shrinks →
   reference chases the collapse): stable but rear-LOW. The angle-anchored variant (θ+fg frozen at
   plant) held angles rigidly but went underdamped through the body modes and bounced the settle
   airborne. A proper STAND-FIRST controller (posture-referenced leg support with matched damping,
   verified under perturbation before any gait runs) is the prerequisite for both the mirrored-hind
   zigzag (tried: walked 4 m but sideways-dragging) and higher speeds.

CURRENT STATE (rendered frames + trace, `render_walk.gd`): **the first genuinely stable periodic
gait of this effort** — 10 s of perfectly monotonic advance, up-dot flat at 0.893, zero falls,
zero lurches, front legs stepping tall — but SLOW (+0.78 m / 10 s ≈ 25% of plan speed) and
rear-low (the uniform zigzag is weak at the hinds; see debt notes). The 3 m bar remains open.
NEXT, in order: (1) stand-first controller (hold the stand under shove, both solver configs),
(2) re-mirror the hinds on top of it, (3) speed/heading tuning toward the bar, frames as the judge.


---

## 2026-07-31 — Engine-neutral material evidence staging

Material support is not a controller constant and is not inferred from an
authored engine friction number. The current SDK evidence architecture requires
four separate objects and three prospectively ordered stages:

```text
authored engine material cell
        |
        v
adapter-specific isolated characterization
        |
        v
immutable characterized adapter profile
        |
        v
policy-relative locomotion acceptance
        |
        v
bounded public support claim
```

An adapter characterization may measure only the declared operational behavior
of an exact fixture, engine, solver configuration, executable, and finite
authored values. It may publish no locomotion result. A positive report can
authorize profile publication only after its report, host identity, source
hashes, units, conservative derivation, and claim boundary are retained. The
profile is adapter-local: a Godot/Jolt coefficient is neither a portable
material coefficient nor evidence of Rapier, MuJoCo, continuous-friction, or
arbitrary-material equivalence.

Locomotion acceptance is a distinct campaign. The controller composition must
be frozen before material outcomes, and material identity may not appear in a
controller branch condition unless that branch is itself the declared
intervention. Policy-relative controls prove application and mechanism
integrity; they are not automatically comparative estimators. A finite
all-cells-must-pass decision does not become a population claim merely because
it uses multiple deterministic values and seeds.

BW20F instantiates this architecture for the BW19V-B successor:

- stage 1: closed-positive 13-world exact finite Godot/Jolt material
  characterization at `0.09`, `0.37`, `0.76`, and `1.18`;
- stage 2: closed-positive deterministic zero-world adapter-profile
  publication with four source/report-bound records; and
- stage 3: closed rejected after one complete 17-world attempt as distinct
  campaign `BW20F-BW19V-COLD-MATERIAL-LOCOMOTION`, gate
  `BW20F-LOCOMOTION`, with 12 BW19V-B treatments, four material-matched
  BW19V-A integrity controls, and one zero-friction safety control.

The stage-3 production evaluator has now accepted a perfect serialized
17-cell result through all 28 declared gates and a serialization round trip.
Twelve independent mutations cover host identity, missing/order-invalid cells,
treatment and control application, ordinary walking, zero-friction native
actuation, profile binding, nonfinite observations, paired identity,
prerequisite evidence, and claim inflation; all fail closed. The real worker
then traverses all 17 entrypoints and 16 exact adapter starts with zero worlds,
SceneTree insertions, physics mutations, or locomotion outcomes. Three bypass
canaries reject missing durable output, direct physical-worker entry, and a
forged nonexistent attempt before a world.

The matched controls retained exact fixture, material, seed, threshold,
solver, controller, perturbation, and initial-pose identity while changing
only the declared BW19V composition/scale from `BW19V-B` / `0.5` to
`BW19V-A` / `0.0`. They were not outcome comparators; BW5C's historical
terminal-position-separation threshold was therefore not inherited. Every
treatment had to pass the ordinary production walking gates without
outperforming its control.

The physical launch satisfied the clean pushed freeze, immutable pre-process
attempt reservation, pinned host, live-GitHub identity, durable evidence root,
and one-process-per-cell requirements. All 17 worlds completed with zero
integrity failures. The frozen gate rejected the result at `19/28`: treatments
passed `10/12`, with authored friction `0.76` seeds `23001` and `23003`
failing only bounded lateral drift. The safety cell passed.

The attempt also exposed a control-contract defect. The inherited semantics
correctly report `combined_application_gate_passed=false` for a zero residual
scale, while the still-active balanced-wave base makes the broad
`physical_influence` field true. The synthetic result, worker, and evaluator
incorrectly required controls to report the opposite, guaranteeing four
control cell failures. Consequently the intended control-conformance layer is
invalid, but the two treatment failures independently reject the exact finite
all-treatments-must-pass decision. Any repair requires a new campaign identity,
fresh validation seeds, a new preregistration, and a synthetic control receipt
that matches the retained runtime semantics. The old identity may not be
edited or rerun.

This successor architecture does not replace the current release authority.
BW5R-B remains release-selected and QSDK-R08 remains bounded to its accepted
four-value Godot/Jolt material campaign. BW20F stage 1 consumed one clean-
source attempt at `476aa4e`, completed `13/13` characterization worlds, and
passed `23/23` gates. Its adapter-local coefficients are `0.07`, `0.35`,
`0.73`, and `1.00`. Stage 3 is now closed rejected, so it remains
non-authoritative for locomotion material robustness, continuous friction,
another engine, and release. Its `10/12` treatment result and control-semantic
defect are development inputs for a distinct successor, not a reason to relax
or reinterpret the frozen campaign.

Stage 2 has a separate campaign identity and consumption boundary. Its full
gate resolves 29 immutable profiles through 30 adapter starts, checks every
canonical digest and provenance binding, preserves the legacy default, and
rejects unknown profile IDs, fixture mismatch, solver mismatch, and record
tamper. It must report `worlds=0`, `samples=0`, and `commands=0`. A retained
publication requires clean pushed source equal to live GitHub `main`, an
unused source-named durable evidence root, and an attempt receipt written
before the report. Direct retention through the generic runner is forbidden.
The one accepted publication ran from source `cf9431e`, passed `40/40`, and
retained zero worlds, samples, and commands. Its identity is now closed and
may not publish again.

This separation is load-bearing even though publication is nonphysical. The
first development pass demonstrated why: the inner receipt correctly reached
the new `40/40` cardinality while an outer wrapper still expected `36` and
failed closed. No retained identity or physics world was consumed. Only after
the wrapper and complete synthetic path agreed was the stage-2 source eligible
for a prospective freeze. The accepted publication still confers no
locomotion or release authority; it only supplies an immutable adapter-local
input for the later, distinct physical acceptance campaign.

## 2026-08-02 — BW25Y prephysical authorization and receipt boundary

The material-staging architecture now has an executable cell-level boundary
between physical authorization and scientific evaluation:

```text
immutable campaign attempt
        |
        +-- exact primary world reservation: BW25Y-P1::<cell>
        |       |
        |       v
        |   isolated Godot world -> raw identity-bound receipt
        |                              |
        |                              v
        |                    sole PowerShell final composer
        |                              |
        |                              v
        |                    structurally complete final receipt
        |                              |
        |                              v
        |                    frozen production evaluator
        |
        +-- BW25Y-R1::<cell> only if no structurally complete receipt exists
```

No scientific outcome is an authorization or recovery signal. Every parsed,
identity-exact, structurally complete, deterministically composable receipt is
final: a walking-negative receipt goes to the frozen evaluator as a possible
valid negative, while a complete mechanism/application, numeric, or integrity
failure goes there as an invalid retained result. Only transport, process,
identity, declared structural-completeness, or deterministic-composition
failure can consume the single predeclared R1 slot. The launch attempt is
written once before any world and remains immutable; raw and final receipts,
transcripts, completion, evaluation, and report are distinct retained
artifacts.

This boundary is source- and host-bound through one shared `40`-field attempt
constructor/parser and independent worker checks. The current zero-world proof
traverses all 28 entrypoints, 27 native adapter starts, the 50-gate evaluator,
receipt parity, attempt mutations, and authorization bypasses without scene
insertion or physics mutation. It authorizes only a later clean-pushed one-shot
BW25Y development attempt—not walking, material robustness, turning,
cross-engine equivalence, arbitrary morphology, or SDK release.

## 2026-08-02 — BW25Y closure exposes the missing constructor boundary

The retained physical attempt showed that the previous diagram omitted one
load-bearing edge. The actual pipeline was:

```text
physical Godot/Jolt process
        |
        v
inherited BW20F post-world receipt constructor
        |  requires cell.cohort, absent from BW25Y
        X  GDScript SCRIPT ERROR
        |
        v
partial dictionary marked raw_receipt_complete=true
        |
        X  supervisor raw identity/schema rejection
        |
        +-- primary incomplete -> exact preallocated R1
        +-- R1 repeats defect -> cell closes incomplete

28 cells -> 56 physical process streams -> 0 final receipts
```

Thus authorization, post-world construction, structural completeness, and
scientific evaluation are four separate boundaries. The stage-one synthetic
suite crossed final composition and evaluation, but it bypassed the real
inherited constructor. A successor's zero-world commissioning route must
cross all four boundaries with real-shaped synthetic summaries for every
worker role. Completeness is a derived exact-schema property and is false if
stderr contains a worker script error, regardless of process exit code.

The closed BW25Y identity remains bound to commit
`14c1c3488e858398158be59f608e21f09cf50671`. It retains `56` physical
process-attempt streams and zero admissible final receipts. It cannot select a
controller and cannot be rerun. A new cross-process operation lock must also
serialize full conformance against physical campaigns so the repository has
one machine-wide experimental writer, not merely one supervisor-local writer.
The qualified physical launcher must also consume a durable, source-bound
Godot-inclusive conformance attestation rather than restating success booleans
inside its own attempt. An empty eligible matrix must produce a retained
infrastructure-invalid terminal result instead of throwing before evaluation,
completion, and report metadata can be written.

## 2026-08-02 — BW26I commissions the missing constructor edge

The active zero-world receipt architecture is now:

```text
successor-declared cell (including cohort)
        |
        v
exact inherited post-world constructor + real-shaped synthetic summary
        |
        v
GDScript required-key/identity completeness derivation
        |
        v
captured stdout + complete stderr
        |
        v
PowerShell required-key/identity/SCRIPT-ERROR completeness derivation
        |
        v
exact BW25Y final composer -> exact 50-gate production evaluator
```

BW26I crosses that path for all `28` inherited roles. The shared route refuses
a missing cohort before constructor entry, and the supervisor treats the raw
boolean as an assertion to verify rather than authority. The frozen walking
outcome is absent from structural completeness and process-exit control: a
complete negative reaches evaluation, while missing transport structure or a
script error cannot. The empty-candidate guard sits outside the exact frozen
evaluator and returns a structured terminal failure without attempting to bind
an empty candidate array.

This architecture still lacks the outer machine boundary. Full conformance and
physical supervisors must acquire the same cross-process operation lock, and a
physical launch must consume a durable attestation binding clean pushed source,
Godot/runtime/adapter identities, and a complete Godot-including conformance
pass. BW26I intentionally does not claim those two requirements are complete.

## 2026-08-02 — BW26I closure adds an authority firewall requirement

The first BW26I implementation is preserved as an invalid architecture
counterexample. It crossed every mechanical receipt edge, but its perfect
fixture was not neutral: the nested production evaluator selected BW25Y-B and
granted development authority. The wrapper copied those values while separately
hard-coding `candidate_selected=false`, allowing contradictory authority state
to escape a passing gate. Its control fixture likewise treated residual-overlay
influence and active-base influence as the same observation.

Every future infrastructure-only evaluator route therefore needs an authority
firewall after the production evaluator:

```text
neutral perfect fixture -> production evaluator -> selected NONE
                                             |-> authority false
any selected candidate or authority true ----+-> structured invalid result
```

The firewall does not rewrite the production evaluator. It constrains what a
zero-world infrastructure commissioning may call a perfect no-selection route.
Candidate labels must be exchangeable for all comparison inputs, outer and
nested authority fields must agree, and all public claim booleans must remain
false. A distinct successor owns that correction; BW26I remains immutable under
its closure.

## 2026-08-02 — BW26J commissions the authority firewall

BW26J implements the distinct successor architecture without modifying BW26I:

```text
actual inherited constructors -> independent raw validation -> exact composer
        -> exact production evaluator -> authority firewall -> outer result

neutral fixture: 50/50, NONE, no authority ---------------------> valid
synthetic B selection: 50/50, B, authority ----------------------> invalid
```

The firewall consumes the actual nested selection state. It does not accept a
separate wrapper boolean as proof and does not suppress the nested diagnosis.
On a forbidden synthetic selection it reports
`production_selected_candidate_id=BW25Y-B` and the nested authority, but forces
the public selected candidate to `NONE`, every outward authority false, and the
whole commissioning invalid with a stable failure code. Thus diagnostic
visibility and claim authority are deliberately separate.

The fixture layer also models control composition in two channels: residual
overlay influence and base-controller influence. A scale-zero control has the
former false and the latter true. Future production receipts must preserve
that separation whenever a disabled optional layer sits over an active base.

This closes the in-process receipt/selection boundary only. The architecture
still requires one global cross-process operation lock and a durable
source-bound full-conformance attestation before any future physical supervisor
may be considered qualified.

## 2026-08-02 — machine-wide physical/conformance serialization

The outer execution architecture is now:

```text
              Global physical/conformance mutex
                         |
            +------------+------------+
            |                         |
     full conformance            physical successor
            |                         |
 clean pushed source + host            +-- verifies exact durable attestation
            |                         +-- records attestation path + SHA-256
            v
 durable full-Godot attestation
```

The mutex handle lives for the complete conformance process, including failure
cleanup and optional attestation publication. The attestation is written before
the handle is released, removing the gap in which a physical process could
start after tests but before their source-bound receipt existed. Future
physical supervisors use the same module; frozen historical supervisors remain
unchanged and cannot be rerun regardless.

The verifier is part of the attestation's source bindings along with the
runner, lock module, and executable JSON contract. Consequently, a physical
launcher does not trust an unattested verifier implementation. Durable output
is immutable and restricted to the sibling evidence root.

The architecture intentionally grants no physical acceptance to conformance.
It qualifies infrastructure for a later, separately preregistered experiment.
Ordinary regression-test physics may execute inside full conformance, but no
one-shot physical campaign identity or new scientific outcome is consumed.

The first V1 publication proved that the interpreter is part of this boundary:
its full process passed, but PowerShell's deserialized `DateTime` values failed
the independent duration invariant. V2 binds the PowerShell executable, hash,
version, edition, and process architecture in addition to Godot and source. It
reopens and validates the serialized temporary file before the atomic move.
The invalid V1 file remains immutable historical evidence and cannot qualify a
physical launcher.

## 2026-08-02 — V2 commissions the serialized source/host boundary

The first distinct V2 production run completed full Godot-including
conformance from clean-pushed source `0513be82` in `855.3993872 s`. Its
serialized file passed the same production verifier after atomic publication,
including the type-aware timestamp invariant and the newly bound PowerShell
host. The global mutex was independently acquired and released after both run
processes exited, then acquired and released a second time without abandoned
ownership.

The architectural result is narrower and more useful than a generic test-pass
claim: the lock, source/host identity model, serialized publication boundary,
and consumer verifier work together for one exact commit. The retained
attestation's all-false claims prevent that infrastructure fact from becoming
walking or release authority. A historical closure reconstructs the exact
validator and source blobs from `0513be82`; later source cannot inherit the
receipt. Consequently, the physical workflow is now explicitly two-phase:

```text
freeze and clean-push exact successor source
                    |
                    v
full Godot conformance publishes matching V2 receipt
                    |
                    v
physical supervisor verifies receipt, acquires same mutex, opens one-shot world
```

Documentation or campaign-design commits after a pass invalidate its use as a
current launch gate by construction. That cost is intentional: a receipt
qualifies executable source, not a project name or a moving branch.

## 2026-08-02 — successor design separates material truth from controller truth

BW27M restores the staged dependency that BW25Y required but could not
complete:

```text
fresh authored material reservation
              |
              v
exact adapter characterization (no locomotion)
              |
              v
deterministic profile publication (zero worlds)
              |
              v
paired yaw-controller development on fresh seeds
              |
              v
separate unseen validation if a candidate is selected
```

The stages answer different questions and therefore cannot share authority.
Characterization establishes exact fixture/adapter behavior at three authored
points. Publication turns those retained observations into controller inputs.
Development compares one isolated controller mechanism. Independent
validation is the earliest stage that could support a bounded robustness
claim. BW27M's declaration audits freshness from historical Git blobs rather
than relying on naming convention or human memory, and opens zero worlds.

## 2026-08-02 — BW27M separates constructor, evaluator, and launch authority

The prospective characterization path now has three explicit architectural
layers:

```text
actual fixture constructor outside SceneTree ----> reachability receipt
perfect/defective synthetic reports -------------> 19-gate evaluator
frozen one-shot supervisor + lock + attestation --> physical launch
```

All three source layers are now commissioned, but their authorities remain
separate. The fixture and evaluator conformance entrypoints cannot launch the
physical worker and report zero worlds and zero scene insertions. The frozen
supervisor is the only intended launch surface: it binds the exact constructor
and evaluator bytes, rejects a direct worker invocation, verifies clean pushed
source and a matching V2 receipt, and acquires the same global mutex as
conformance. It consumes a durable attempt identity before passing the
physical token and retains interruption or rejection instead of permitting
selective reruns.

The freeze itself is still not launch authority. Before its commit is pushed
and receives a matching full-Godot V2 attestation, its executable audit reports
`one_shot_contract_frozen=True`, `physical_execution_authorized=False`, and
`physical_authority=False`. This layering lets normal CI exercise the full
decision and authorization semantics without opening a world or making a
physical campaign identity reusable.

## 2026-08-02 — a positive characterization closes the launch surface

BW27M completed the architectural chain once from clean pushed source
`a219ba8`: matching full-Godot attestation, shared-lock acquisition, durable
attempt reservation, private worker authorization, ten physical fixture
worlds, atomic report publication, independent evaluator replay, and closure.
All `19/19` gates passed for the exact `0.62/0.74/0.86` material cells.

Closure changes the normal control flow permanently:

```text
historical frozen supervisor ----X----> another physical attempt
                |
                v
immutable report + source/evidence hashes + evaluator replay
                |
                v
zero-world publication of exact 0.61 / 0.73 / 0.84 profiles
```

Canonical conformance now invokes the closure audit, not the prospective
constructor/supervisor preflight. The closure proves one attempt exists and
actively checks that a supplied matching attestation still cannot bypass the
closure interlock. This is the architectural difference between preserving an
instrument and preserving a result: the instrument remains inspectable, but
its launch authority is destroyed after its identity is consumed.

The result also preserves the staged truth boundary. The measured lower
ratios justify conservative Godot/Jolt controller coefficients at three exact
authored fixture values. They do not become continuous material behavior,
walking robustness, or cross-engine coefficients. Profile publication is a
separate deterministic transformation with zero worlds; paired turning
development is a later physical study on still-unopened seeds; independent
validation is later still.

## 2026-08-02 — profile publication becomes an attested one-shot transform

BW27P treats deterministic profile publication as evidence-bearing
infrastructure even though it opens zero worlds. The input side is the exact
BW27M closure/report plus the closed 35-profile prefix. The transform side is
the registry and canonical JSON digest. The output side is a one-attempt
receipt/report/completion set under a clean pushed source identity.

```text
BW27M retained cells + prior 35-profile prefix
                    |
                    v
38-profile / 49-gate zero-world transform
                    |
       exact-source V2 attestation + shared mutex
                    |
                    v
one immutable publication receipt (not yet executed)
```

The supervisor proves the production parser with a perfect serialized attempt
and ten one-field canaries before source freeze. A later publication must write
the attempt before invoking the report-producing runner. Normal conformance
routes to the prospective audit until a paired closure exists, after which it
must route only to the immutable closure. This prevents the zero-world nature
of the work from becoming an excuse for mutable provenance or selective
republishing.

The published coefficients, if the one-shot transform passes, remain exact
Godot/Jolt adapter records. They do not express a continuous friction law and
cannot be copied to Rapier or MuJoCo without each engine's own evidence.

Historical source verification is intentionally two-dimensional. The V2
attestation binds normalized Git blobs to identify committed semantics and raw
SHA-256 values to identify the exact checkout bytes executed by the host.
After closure changes `run_conformance.ps1`, the audit resolves the former from
physical commit `a219ba86` and the latter from the immutable attestation; it
does not hash the current closure-era runner and mislabel those bytes as the
pre-physical checkout. Unchanged bindings are still re-hashed directly. This
keeps provenance independent without making legitimate lifecycle transitions
look like historical source corruption.

## 2026-08-02 — BW27P treats profile publication as a gated state transition

BW27P makes the material-registry transition explicit instead of treating
three source records as self-authenticating evidence:

```text
closed BW27M report + closed 35-profile prefix
                         |
                         v
38-profile / 49-gate zero-world adapter receipt
                         |
                         v
exact production attempt parser + 10 defect canaries
                         |
                         v
clean-pushed source + V2 attestation + shared operation lock
                         |
                         v
one durable publication receipt
```

The source edit and the scientific authority remain different objects. The
prospective registry is testable now, but `profile_published` stays false
until the one source-bound attempt and report exist. The full supervisor path
constructs no physics world, sample, or motor command, yet it uses the shared
production lock because retained state transitions must not overlap with the
conformance run that authorizes them.

BW27P reuses one constructor for perfect synthetic and future real attempt
records. The real production parser is therefore the tested interface, not a
parallel test-only approximation. Ten single-defect canaries protect
cardinality, identity, digest, and exact-key-set failures. This is the direct
architectural repair for BW24M-PROFILE, where the adapter work passed but the
retained attempt carried predecessor cardinalities and correctly closed
invalid.

The dependency edge remains narrow. Publishing `0.61/0.73/0.84` authorizes
later Godot/Jolt controller development at those exact profiles. It does not
make the coefficients continuous, engine-neutral, or locomotion-robust. The
four BW28Y seeds stay inaccessible until a positive publication closure
replaces this prospective route.

## 2026-08-02 — BW27P closes the deterministic material-input edge

BW27P consumed one source-bound zero-world publication identity at clean
pushed commit `e3a3c0b7`. The retained receipt contains `38` immutable
profiles, `39` adapter starts, `49` passed gates, and no world, sample, motor
command, transform write, or actuation application. The new terminal records
bind authored Godot/Jolt fixture values `0.62/0.74/0.86` to conservative
controller coefficients `0.61/0.73/0.84` and to their distinct canonical
digests.

The dependency edge is now mechanically closed on both sides. Upstream,
BW27P hash-verifies the positive BW27M characterization and the prior 35-entry
registry. Downstream, its retained report is immutable and its supervisor
refuses another publication as soon as the closure exists. A full-Godot V2
attestation binds the exact publication source and execution environment;
the closure audit reconstructs that historical document from its four source
bindings rather than incorrectly comparing it to a later router revision.

The shared global mutex also produced an operational negative example: a
duplicate pre-attempt invocation was refused and consumed no identity, while
the one lock owner wrote the sole durable attempt before report generation.
Serialization is therefore part of evidence correctness, not merely process
hygiene.

This edge authorizes only construction of a distinct BW28Y manifest. The
reserved seeds remain unopened, and the future 28-world paired turning screen
must carry its own source identity, exact profile references, paired fixtures,
policy-relative synthetic whole-gate proof, and attempt-before-world contract.
No coefficient here is continuous, engine-neutral, or itself evidence that a
quadruped can walk or turn on the material.

## 2026-08-02 — BW28Y declares a repaired turning-development edge

BW28Y separates the experimental declaration from physical authorization. Its
candidate, preregistration, and ordered-manifest documents bind the two yaw
gains, three published adapter profiles, four unopened seeds, controls, safety
cell, selector, and negative claim surface. All `28` cells now carry the
`cohort` field consumed by the inherited receipt constructor.

That schema repair is necessary but not sufficient. The downstream edge stays
closed until the same production constructor, final composer, and evaluator
accept real-shaped synthetic receipts for every role and every ordered cell;
their failure canaries must traverse those same functions. Only a later
source-bound stage-one freeze and matching full-Godot V2 attestation may expose
a seed. This prevents a declaration-only mock from authorizing a physical
pipeline whose actual receipt path is broken.

The zero-world implementation now closes that internal path through three
layers: Godot produces real-shaped raw receipts through the inherited
constructor; an outer PowerShell firewall validates raw cardinality and exact
attempt/cell identities; and the sole final composer projects the full walking
diagnostics into the four frozen decision gates before the production evaluator
runs. Synthetic data may prove this path accepts `50/50`, but the outer layer
forbids it from exporting candidate-selection authority. The source-bound
stage-one freeze and one-shot supervisor are now present and their complete
authorization preflight passes with zero worlds. The physical edge remains
disconnected until that exact tree is clean, committed, pushed to live GitHub,
and covered by a matching durable full-Godot V2 attestation; only then may the
supervisor consume the single physical attempt identity.

## 2026-08-02 — BW28Y closes the edge without promoting either candidate

BW28Y consumed the one physical identity from clean pushed commit
`77b4ca34fc2d8c3271fcfa364a817b02d7eb81ed`. The supervisor wrote attempt
`7a44427e656244358f8f774333eb2af5` before the first world, then obtained one
complete final receipt from each of the `28` isolated workers. No receipt was
incomplete, no replacement was used, all `28/28` cell gates passed, and the
production evaluator passed all `50/50` integrity and decision gates.

The decision edge deliberately has two inputs, not one aggregate score:

```text
BW28Y-B aggregate vector strictly better than BW28Y-A
                           +
BW28Y-B paired walking regressions must equal zero
                           |
                           v
                  select B or select NONE
```

B increased finite candidate walking from `7/12` to `9/12` and repaired four
paired A failures, including two at authored friction `0.86`. It also turned
two A passes into B failures at `0.62/27013` and `0.74/27011`. Because the
second input was `2`, not the frozen required `0`, the sole selector returned
`NONE`. This prevents an aggregate improvement from hiding fixture-specific
regressions and leaves the currently selected policy unchanged.

The closure replaces the prospective conformance route. Normal conformance now
executes the immutable closure audit, which re-hashes the `145`-file retained
evidence tree, reconstructs the canonical `29`-blob source-binding tree at the
experiment commit, checks the exact historical full-Godot V2 attestation,
requires exactly one durable attempt, and proves the physical runner refuses a
same-identity rerun. The original stage-one freeze continues to retain the
exact raw hashes of the Windows checkout used before the worlds. The closure
separately pins Git's canonical text blobs so configured line-ending
normalization is represented honestly rather than misreported as source-code
drift.

Architecturally, `NONE` is a completed transition, not a missing state. The
observed lateral/yaw tradeoff may shape a distinct successor, but no component
may lower BW28Y's threshold, remove its paired-regression gate, or promote B
after exposure. A successor needs a new campaign and source identity, fresh
unexposed materials and seeds, the same actual-path zero-world proof, and an
independent validation campaign after any development selection. Turning and
material-robustness edges therefore remain closed.

## 2026-08-06 — R23D3 separates stage authority from supervisor completion

The two-stage turning supervisor now has an observed third terminal form:

```text
valid Stage A NONE -> withhold Stage B -> complete-transport failure
```

Stage authority and supervisor completion are separate immutable objects. The
former can remain a bounded valid result while the latter remains invalid. A
closure may describe both, but may not synthesize the missing complete report
or replace the emergency completion. Canonical conformance must switch from the
prospective route to a closure audit as soon as the physical identity is
consumed.

Empty stage manifests are protocol values, not absence. Successor supervisors
must serialize them as an explicit JSON array object and exercise those exact
bytes through the production evaluator at zero worlds. Evaluator stdout,
stderr, exit code, and result artifacts must be retained before any marker is
parsed. Closure interlocks belong at both supervisor and native-worker physical
authorization boundaries because an exposed single-use token is not itself a
durable post-closure lock.

R23D3's outcome trace also shows why diagnostic horizons must cover every
thresholded physical phase. Its 2,992 controller rows remained below the tilt
gate, while the terminal aggregate crossed it during a later 240-step
zero-actuation settle. R23D4 must either trace that phase or declare controlled
recovery and passive terminal stability as separate prospective estimands.

## 2026-08-06 — R23D4 makes terminal restoration an explicit portable phase

The prospective turning pipeline now has three physical phases under one trace
and one outcome accumulator:

```text
balanced-wave turn/return (2,992)
                |
                v
contact acquisition + captured-pose hold (180 + 360)
                |
                v
traced passive zero-actuation settle (240)
```

Restoration is neither a hidden host cleanup nor a post-hoc report transform.
It has a portable policy identity, fixed kinematic/search and damping constants,
per-step native application receipts, contact/pose-memory gates, and exact
phase boundaries. The later passive phase must contain zero native writes while
remaining fully observed. MuJoCo MV6 and Rapier PH1 provide separately accepted
source semantics; the R23D4 Godot/Jolt implementation must reproduce the
portable receipt rather than borrowing their physical results.

The supervisor edge also treats empty stage collections as data. `[]\n` is the
only accepted empty manifest projection, and process transport is retained
before marker parsing. At stage zero every physical edge remains disconnected.

## 2026-08-10 — conformance becomes observable before it becomes reusable

The canonical conformance path now has an explicit eight-stage observation
plane around the unchanged execution plane:

```text
unchanged full-cold stage execution
                |
                v
create-only timed stage JSON -----> immediate SHA-256 artifact retention
                |
                v
one retained full transcript -----> bounded retained excerpt on failure
                |
                v
aggregate run observation --------> no cache or release authority
```

[`../sdk/conformance_observability_contract_v1.json`](../sdk/conformance_observability_contract_v1.json)
is deliberately phase-one. It identifies the exact stage order, receipt fields,
toolchain observation, log-retention path, and all-false claims. The canonical
runner invokes its executable audit inside the first stage, so later full runs
cannot silently lose the instrumentation.

Observation is not dependency proof. The current receipt binds the runner,
observability module, contract, artifact-store implementation, repository
state, and runtime identities, but labels that set `observed_not_transitive`.
Its cache state is `disabled_uncommissioned`; it performs no lookup and cannot
reuse a result. This prevents a useful timing document from being mistaken for
the future authorization key. Only a successor contract with complete
transitive inputs, evidence and host semantics, mutation-tested invalidation,
the global authorization safety kernel, and a cold equivalence baseline may
make a cache hit actionable.

The first clean-pushed no-Godot execution of that plane is retained as run
`20260810T211106Z-b1627db3-656c086d6125444ca5dd07dd02bbe2f0`. It passed in
`1597.2312833 s`; stages 1, 3, and 4 accounted for about `94.4%` of elapsed
time. The aggregate receipt SHA-256 is
`42b61999b4649d7d4a7c88c9a3aba528eabef1031cbb59a19cabcfa951ae16c1`,
and all receipt/transcript CAS payloads and manifests independently verified.
This measurement changes no execution edge: reuse remains disconnected until
per-audit transitive keys, invalidation controls, the authorization kernel,
and Godot-inclusive executed-versus-reused equivalence are commissioned.

### Dependency-key design decision

Three designs were considered. Hashing only the audit plus statically guessed
imports is fast but cannot detect indirect files, runtime libraries, evidence,
or dynamic environment inputs, so it is rejected as cache authority. Hashing
the entire machine and evidence root is conservative but self-invalidates when
unrelated evidence is appended and gives no per-audit reuse. The selected path
is a declared per-audit closure built on conservative canonical inventories,
with inference used to find omissions rather than silently define authority.

CDK1 implements the first executable layer. It computes a root-independent,
ordinal SHA-256 inventory of exact checkout bytes, binds Git tree/remote/status,
hashes both referenced and complete process-environment values without storing
them, and provides the same mutation-sensitive primitive for declared runtime
and evidence roots. A live candidate starts inside timed stage 1, after
transcript ownership; even candidate construction failure therefore produces
retained failure evidence.

This choice makes every omission visible but keeps reuse disconnected. The
complete process-environment inventory conservatively covers the values behind
all nonliteral lookups, at the cost of invalidation by unrelated session
variables. A later refinement may resolve constant-flow names or require
explicit declarations, but it must first attach exact runtime/evidence
inventories and partition the measured stages into per-audit manifests. Only
after mutation controls and Godot-inclusive executed/reused equivalence may a
matching receipt control an execution edge.

The evidence side uses the same declared-closure rule. CDK1 intersects tracked
SHA-256 literals and explicit CAS paths with the durable artifact store, then
rehashes only matched payloads/manifests. This avoids making unrelated CAS
append operations invalidate every audit while still refusing missing explicit
objects or any selected-object corruption. The current repository selects
`568` objects / `354994572` payload bytes in a roughly `32.3 s` complete
candidate construction.

That inventory is not a substitute for file-access closure. Non-CAS durable
campaign paths remain outside the proven set, so evidence completeness and the
execution edge remain false. Per-audit manifests must declare those paths and
their digests, and the cold executor must reconcile actual audit identities
against the declaration before reuse can be considered.

### Per-audit external evidence shapes

CAD1 adds a compact registry beside CEP1 instead of reparsing every retained
JSON document or hashing the complete durable evidence root. A registered
audit may bind an exact file, a complete recursive directory tree, or an
immediate-child directory query constrained by a literal name
prefix and one child-file probe. The query projection includes matching names,
probe presence, and present probe bytes, while deliberately excluding unrelated
prefixes. This mirrors same-lineage/refusal scans without introducing a global
append tax.

A fourth shape binds historical Git objects that are not implied by the current
checkout. It uses one binary-safe `git cat-file --batch` transport, reads the
raw commit/tree bytes, recomputes the full Git object ID including the native
type/length header, and records a SHA-256 of the raw content. This makes
historical object availability explicit without paying for a whole-repository
`git fsck` on every audit.

The registry is executable but not authoritative for reuse. Every registered
audit must match its CEP1 path, source digest, and provenance mode. Missing
paths and reparse points fail closed; mutations alter the inventory. An audit
becomes complete only after external evidence, runtime, transitive helpers, and
all read mechanisms are closed. The first R23D13 entry remains incomplete
because its parent command observation cannot see the nested supervisor process
or prove the absence of direct/module-qualified bypasses. Consequently an
unregistered or incomplete audit leaves the aggregate execution edge false.

### Per-audit runtime profiles

CRP1 applies the same declared-closure rule to tools. A runtime profile binds
root-independent exact-file inventories, safe version/architecture identity,
and hashed configuration-file roles. It does not hash raw config values into
logs or receipts and does not treat a version string as a substitute for file
identity. Unexpected Git config origins fail closed.

The first profile is deliberately narrow: the parent R23D13 closure process's
PowerShell boot/runtime files and two built-in module manifests, plus the Git
launcher, real binary, loaded Git DLLs, and three active config files. This
avoids the false precision and startup cost of hashing every installed Python,
Godot, Cargo, PowerShell, and Git file for an audit that does not use them.

Loaded-module observation is discovery, not completeness proof. The profile
stays incomplete until nested/native child reads, transitive helpers, Git
objects, system DLLs, and host semantics are either declared or proven
irrelevant by executable negative controls. An incomplete profile contributes
an invalidation digest but cannot enable a cached execution edge.

CRP2 completes only the exact R23D13 parent audit and already-closed supervisor
refusal route. Seven measured source bindings prevent a later helper change
from inheriting the observation. The declared runtime union contains `86`
PowerShell files, `7` Git files and three config roles, `59` Windows modules,
and `2` Defender/AMSI modules. The host projection also binds Windows build,
.NET and architecture, culture/UI culture, timezone, console encodings, and
the source-volume format. The child refuses before Git, engines, models,
workers, or worlds; the parent Git objects and all evidence are bound by CAD1
and CDK1. There is no wall-clock or scheduling threshold on that exact audit
route.

This is a per-audit completeness statement, not a global runtime claim. Any of
the seven measured sources changing makes the completed profile fail closed.
The other `94` audits remain unprofiled, aggregate runtime/host completeness is
false, and no receipt may yet control execution.

CER1 attaches a content-addressed execution envelope only to that complete
R23D13 audit. The key is composed from its CAD1 entry, CRP2 projection, complete
process-environment digest, canonical command, PowerShell executable bytes,
and the exact receipt implementation. Execution stores canonical UTF-8/LF
stdout and stderr plus a create-only record; read-back rehashes all three CAS
objects and the semantic result projection without exposing a process-launch
edge. A same-key second result is a determinism conflict and refuses.

The read-back route is intentionally not a cache hit. CER1 has no production
lookup edge and may not suppress an invocation. Two clean cold processes must
first reproduce the exact input and result projection, and that observation
must be frozen before a successor can connect per-audit reuse.

CER1-C1 has now supplied that first narrow observation. From clean source
`ddc3d5d`, the execute process invoked R23D13 once and the read-back process
invoked it zero times; both resolved the same input, record, and result digests.
The read-back took `6.1857223 s` versus `12.6491433 s` end-to-end for execution.
The closure records the positive infrastructure result while leaving CER1's
lookup/reuse edge disconnected. A successor must explicitly bind this closure,
the immutable candidate record, and fresh invalidation/refusal controls before
the canonical scheduler can substitute read-back for execution.

The follow-up adoption measurement rejects that substitution for R23D13.
Direct cold execution took `5.2191931 s`, while read-back including its exact
key cost took `6.1857223 s`. The canonical graph therefore keeps the direct
edge. Future reuse must either target a substantially more expensive audit or
compute one shared dependency identity for a batch; correctness equivalence
alone is not a performance justification.

CAP1 adds a separate measurement plane over the CEP1 historical inventory. It
does not sit on the canonical execution edge: it serially invokes the declared
audit sources, CAS-retains each output stream, and emits an ordinal, duration-
ranked development profile. This lets the next dependency/profile effort be
chosen by observed cost while keeping failures and all authority boundaries
visible. Only a later target-specific contract can act on the ranking.

The clean CAP1 profile shows the architectural target clearly: five material-
profile publication audits consume `40.0430%` of all `95` audit seconds, and
BW27P alone takes `350.1956976 s`. The next optimization boundary should
therefore characterize their shared reconstruction/runtime graph before
choosing receipt lookup versus one batch key or a persistent verifier.

CAP1 also demonstrated why observability must be incremental. Its stream bytes
were retained per audit, but durations lived only in the final profile; the
outer host timed out while the orphaned profiler continued. CAP2 must publish a
create-only duration receipt after every audit and make resumption a verified
state transition, not a reconstruction from directory timestamps.

CAP2 implements that state transition as an append-only receipt prefix. A
CAS-backed immutable manifest owns the ordered run; a process holds an exclusive
lease while advancing it. Output CAS precedes receipt CAS, and receipt CAS
precedes the atomic create-only ordinal publication. Therefore a crash before
publication leaves no authoritative ordinal and safely repeats that audit,
while a crash after publication resumes from verified `N+1` without repeating
`1..N`. A final profile is only a projection of the verified prefix.

CAP2-C1 commissioned that transition with two distinct processes: one
create-only receipt survived the controlled stop, the resume verified it and
invoked only the remaining audit, and `2/2` passed with all manifest, receipt,
stream, and profile CAS references intact. This qualifies the process-recovery
state machine for development profiling; it is not cache equivalence and did
not empirically crash the OS or host.

THA1 established that historical closure execution can be modeled as a directed
graph rather than a flat list, but closed negative because legacy verifiers
equated direct runner-path visibility with coverage. THA2 preserves the graph
and adds a declaration-only coverage registry. The canonical runner owns roots;
a root may cover descendants only when
the exact CEP1 source graph and a retained ordered terminal-marker witness prove
that the descendants execute as child processes and propagate failure. BW27P is
the first declared root. This removes duplicate top-level process launches but
does not replace an execution with a receipt, cache entry, or assertion.

Graph coverage is deliberately distinct from dependency coverage. THA2 can
deduplicate an audit that actually runs under its parent; it cannot omit BW20F
characterization because the BW20F publication leaf never invokes it. Any graph
source, order, marker cardinality, root path, or fail-closed behavior change
invalidates the route. The legacy-visibility registry is metadata only: its
variable may occur once and may never be read, piped, iterated, or passed to a
process. This lets immutable verifiers observe canonical coverage without
silently restoring a duplicate launch.

THA2 commissioning passed all eight canonical no-Godot stages. The graph's
target campaign-closure stage improved by `169.9574578 s` / `23.4331038%`, but
the cross-commit whole suite was `55.1866869 s` slower. The graph and registry
are therefore commissioned as correctness-preserving execution structure; no
whole-suite performance, cache, waiver, physical, or release claim follows.

### Global authorization kernel and campaign-role interface

CAK1 separates permanent physical safeguards from a campaign's scientific
identity. Its manifest binds `12` source-exact gates for repository authority,
reproducible artifacts, operation serialization, evidence provenance, full
attestation, result integrity, physical-entrypoint and receipt integrity,
shared adapter/ABI/language bindings, and fail-closed release claims. Every
gate has an ordered identity, invocation kind and arguments, tracked relative
path, raw digest, and exact marker in the canonical conformance runner.

```text
complete per-audit dependency closure ----+
                                           |
12-gate permanent safety kernel -----------+--> authorization candidate
                                           |
current campaign worker/evaluator/         |
supervisor negative-control bindings ------+
                                           |
Godot-inclusive cold executed/reused ------+--> only then may reuse affect
equivalence                                      a physical launch decision
```

The worker, evaluator, and supervisor bindings cannot be permanently filled by
a historical campaign: each new physical successor must preregister exact
source/test digests and retain its own refusal receipts. The current manifest
keeps all three roles unbound. Development execution of the declared gate
surface is not the same as commissioned execution receipts; the latter and the
cold equivalence result remain false. The kernel contains no physics launcher,
cannot select or accept a campaign, rejects `-RunPhysical` and `-SkipGodot`
arguments, and is itself bound into CDK1's candidate digest.

### Campaign-local qualification and scheduled historical sweeps

A new physical campaign's critical-path gate owns only the immutable closures
in its declared lineage, the current CEP1 provenance inventory, permanent
authorization safeguards, and that campaign's worker/evaluator/supervisor
negative controls. It must not launch every unrelated historical closure merely
because those closures remain valuable regression evidence. Broad historical
execution is a separately scheduled maintenance sweep with retained receipts;
failures there remain defects and cannot be erased or reclassified by a local
campaign pass.

This separation does not authorize an uncommissioned shortcut. A physical
launcher may consume only an attestation schema that its prospective contract
explicitly names and whose source/host binding, Godot coverage, operation lock,
negative controls, and cold commissioning are complete. R23D14 therefore uses
its own-lineage-plus-CEP1 zero-world supervisor for campaign qualification but
continues to require the existing full-Godot V2 attestation. Replacing that
attestation's broad historical execution is a distinct future infrastructure
successor, never an in-place waiver made to accelerate an already-frozen run.

The first R23D14 attestation start exercised this fail-closed separation: CEP1
had advanced to `100` audits while the partial CAD1/CDK1 candidate still named
`95`, so the attestation stopped before publication or physics. The successor
advances the conservative inventory totals only; it does not register the five
new audits as reusable, alter any historical evidence, or grant a cache edge.

CAP1 exposed the complementary rule: a historical verifier must read its
inventory from the campaign's pinned Git source, not from the growing live CEP1
file. The verifier may separately require the historical path set to remain a
subset of live inventory. This preserves both immutable 95-audit CAP1 semantics
and current 100-audit coverage without forcing either identity to impersonate
the other.

LCA1 is the concrete scoped-attestation implementation of this boundary. Its
production topology is:

```text
clean pushed live source + global operation lock
        |
        +-- fixed 12-gate Godot-inclusive safety kernel
        |
        +-- manifest-owned immutable lineage closure(s)
        |
        +-- exact worker / evaluator / supervisor refusal gates
        |
        +-- CAS(stdout, stderr, receipt) before each next edge
        |
        `-- create-only zero-claim campaign attestation
```

The manifest cannot add an arbitrary executable: invocation kinds are bounded,
paths must be repository-contained non-reparse tracked files, every gate and
transitive binding carries raw checkout and Git-blob identity, physical
arguments are rejected, and role source/test digests are explicit. The runner
strips all inherited `SPORESPORE_*` authorization values. The attestation binds
the source commit/tree and all participating toolchains but remains
`physical_launch_prerequisite_satisfied=false` until its separate same-source
full-V2 cold commissioning closure is present and verified. This keeps the
short path compositional: campaign code can change without rerunning unrelated
history, while a kernel/toolchain/evidence change invalidates the short-path
authority itself.

The first cold pair exposed a missing composition edge in that topology: the
full runner executed the lineage closure but did not execute the exact three
role refusals named by the scoped manifest. Both processes passed, yet their
terminal-marker languages were not in the required subset relation. The pair
is retained as a negative commissioning incident. The canonical full runner
now executes the worker, evaluator, and supervisor role test explicitly, and
the focused LCA1 gate statically requires the exact role set and invocation.
This repair does not commission the path; another same-source cold pair must
prove the repaired transcript relation before a closure can enable it.

The second full run proved that an execution edge and a transcript edge are
distinct. A nested native `pwsh` can execute and return zero while its direct
stdout never enters the parent `Start-Transcript`. LCA1 therefore captures the
role child's combined output and exit code, re-emits the output through the
transcript-owning host, and checks the saved exit code. A focused real-
transcript canary requires exactly one marker. This converts the role edge from
inferred control flow into inspectable retained evidence; commissioning still
depends on a future same-source cold comparison.

That comparison now passes at `655d425b`. The full and scoped paths share exact
source and runtime identities; full transcript marker cardinality is
`1/1/1/1`; scoped execution is `16/16` with `48` verified gate CAS objects. The
commissioning closure is an immutable bridge from the two zero-authority
executions to an implementation-level `commissioned` fact.

The bridge deliberately does not mutate the original attestation schema into a
launch token. A separate adoption composer must consume the closure and a
future campaign's scoped document, revalidate both, and emit a bounded physical
prerequisite. This prevents a closure-era metadata commit from changing the
executor that was cold-compared and keeps scientific acceptance downstream of
the physical result evaluator.

### Terminal execution projection boundary

The supervisor must not infer count location from a convenient terminal shape.
Each accepted terminal schema has one declared projection: successful engine
cell reports expose attempt/build counts through their nested `execution`
object; worker and supervisor failure reports expose counts and optional
uncertainty bounds at the terminal root. A shared projector validates schema,
shape, integer type, count ordering, exactness, and bounds, and rejects mixed
or unknown forms.

The production post-capture path and campaign-local positive/failure canaries
must call the same projector. A preflight that only reaches worker receipt
creation is insufficient, because the load-bearing boundary is the
supervisor's consumption of that receipt after capture and CAS retention. This
rule preserves transport failures as inspectable terminal entries without
allowing a projection defect to masquerade as physics or silently truncate a
declared matrix.

R23D52 is the first physical observation of this repaired boundary. Its three
successful Godot/Jolt worker terminals all projected through the same helper
used by the pre-world canaries, entered the complete matrix, and retained their
terminal and trace evidence. The separate turning evaluator then returned a
valid negative. That separation is intentional: successful evidence transport
establishes that the result is readable and complete; it does not make the
underlying locomotion hypothesis positive.

### MuJoCo Warp calibration and held-out separation

The optional Tier 2 training plane now has a source-only measurement-system
protocol before any GPU physics qualification. Runtime installation,
supported-feature declarations, calibration, and held-out equivalence are four
distinct states. The calibration state measures fresh-process repeatability,
Warp batch-placement invariance, and adjacent-representable-input sensitivity;
it cannot qualify the physics subset or produce training data.

Production semantic ceilings must come from downstream label stability,
canonical normalization resolution, safety guard bands, or contact-event
tolerance before calibration outcomes exist. Calibration may prove those
margins resolvable but may never widen them. Calibration and held-out condition
IDs and seeds are disjoint, every declared factor level occurs in both cohorts,
and a generator-population statement requires at least `59` independent
condition groups in each cohort for the declared `95%` content / `95%`
confidence zero-exceedance rule. Repeated executions and sensitivity arms are
dependent measurements inside one condition group, not extra population
samples. The current MJCAL0-MJCAL7 implementation is fixture-only and opens
zero models or worlds.

The exact clean pushed source record from `daca133` is retained at
`SporeSpore_Evidence/mujoco-warp-equivalence-calibration-daca133/report.json`,
`sha256:d45b7e3499775e846f8b77d36bf06a265fbf2238fd9cb2e71125888ed910b3d0`,
and bound by
[`../sdk/adaptation_provider/mujoco_warp_equivalence_calibration_validation_manifest.json`](../sdk/adaptation_provider/mujoco_warp_equivalence_calibration_validation_manifest.json).
Its 8/8 source cells and 15 mutation refusals establish only the protocol's
zero-world implementation. They do not create a production plan, semantic
ceiling, margin, held-out cohort, qualified subset, training plane, physics
result, or downstream authority.

Before that calibration state can open, the semantic-ceiling provenance layer
in
[`../sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_contract_v1.json)
must close. It treats source installation, ceiling provenance, calibration,
margin freeze, and held-out qualification as separate states. Each future
ceiling binds a strict JSON-pointer metric/unit/value assertion in exact source
bytes and chronology to one bounded downstream invariance and adequacy claim.
The current state is explicitly
incomplete: zero accepted production sources and five unresolved metrics.
Fixture values, adapter readback tolerances, and historical physics thresholds
cannot cross that boundary by relabeling. MJSC0-MJSC7 enforce the separation
at zero worlds; they do not freeze a plan or authorize calibration.

The source implementation is frozen at clean-pushed commit `faaf057` and bound
by
[`../sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_validation_manifest.json`](../sdk/adaptation_provider/mujoco_warp_semantic_ceiling_readiness_validation_manifest.json)
to an immutable `8/8`, 25-mutation, zero-world report. That closure establishes
the provenance state machine and its present incomplete state; it does not
install any of the five missing production sources.

Binding source `dd553b6` also passed the complete canonical no-Godot cold
route. The content-addressed receipt SHA-256 is
`67b6eedcb9aed2a2b2c16d8290c1452d4d2f8256c65f14d9f554c26d6487cfe9`;
seven stages passed, Godot was declared skipped, and the two MJSC markers each
occurred exactly once. Because dependency coverage remains incomplete and
non-transitive and cache/reuse is disabled, this observation cannot be reused
as physical, semantic-ceiling, subset, training, equivalence, or release
authority.

### Dependency registries must grow with their enumerated authorities

RC6 exposed a missing edge in the commissioning preflight architecture. CEP1
is an enumerated authority whose audit count grew from 148 to 150 when the RC5
and R23D54 closure audits were added. The audit-dependency contract and
registry remained byte-stable at 148 total / 147 unregistered. The RC6 freeze
validated CEP1 itself but did not construct the audit-dependency candidate;
the full runner did, and therefore failed closed before its first stage body.

That failure is the desired runtime behavior but an incomplete prelaunch
surface. Future commissioning freezes must directly execute the complete
audit-dependency candidate gate, not infer its validity from the upstream CEP1
gate. The count relationship is exact:

`CEP1 audit_count == dependency contract audit_count == dependency registry audit_count`

and, while one audit remains registered and complete:

`unregistered_audit_count == audit_count - 1`

RC6 is retained as a terminal process-input negative and cannot rerun. A
distinct RC7 layer may update only the four semantic count fields and six test
literals to 150/149 and bind the missing preflight. This repair changes no
runner, physics, controller, margin, or movement semantics. Only a subsequent
clean-pushed full/scoped pair can commission the executor.

### Commissioning preflight owns both registry and composed-key checks

RC7 closes the architectural gap prospectively by requiring two separate
zero-world checks before a cold pair:

`CEP1 -> audit-dependency candidate -> composed dependency-key candidate`

The first proves the 150/149 registry reconciliation and external-evidence
shapes. The second proves that the reconciled candidate composes into the
larger source/environment/runtime/CAS key and rejects its own mutations. This
second layer exposed two additional stale test literals while RC7 was still
unfrozen; they are declared separately from the six literals diagnosed after
RC6.

RC7 binds both candidate tests, their evaluator/contract/registry sources, and
the immutable RC6 incident directly. Its 53-dependency freeze and 54-binding
scoped manifest keep the runner byte-identical and preserve exact-zero
commissioning margins. Clean-pushed source
`da5e35817d413b159dbb1665542de10c9ce76c46`, tree
`f04d952849b1256224a249ce1ec833f12cc947d8`, then passed the complete eight-stage
cold Godot-including run followed serially by all 16 scoped gates. The scoped
evidence binds 48 CAS references to 35 unique objects. Source, runtime, host,
marker, numeric, and claim-vector comparisons all met the exact-zero boundary.

The versioned closure is verified by one reusable audit that reads the current
adoption contract to select the commissioned closure, but reads historical
source through pinned Git blobs and evidence through retained bytes and CAS.
Future recommissioning closures can therefore reuse the same audit path instead
of recursively increasing the audit count for every closure. Adding that audit
once moves the post-closure inventory to 151 audits, 72 CAS-aware and 131
Git-pinned, with one complete dependency registration and 150 unregistered.
This post-closure maintenance does not rewrite the observed 150/149 pair.

The architecture now commissions the exact executor implementation, not the
observed scoped attestation as physical authority. Candidate-specific scoped
qualification and fail-closed adoption remain mandatory after every source
change, and no physical, turning, prone-to-stand, or release claim follows from
the process pair.

### MuJoCo Warp metric-semantics boundary

The next measurement-system layer is
[`../sdk/adaptation_provider/mujoco_warp_metric_semantics_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_metric_semantics_contract_v1.json).
It is development-only and opens zero models or physics worlds. MJCAL names
five comparison metrics, while MJSC governs the provenance of their future
production ceilings; neither predecessor supplied executable production
component registries, normalization scales, periodic/quaternion rules, horizon
populations, energy denominators, or contact-event matching.

MJMS separates the universal formula grammar from those still-missing
production definitions. An ordered suite fixes value kinds and units,
pre-outcome normalization provenance and adequacy, exact step populations,
CPU-reference energy-denominator semantics, and one-based exact contact-event
identities. A paired trace must match its suite hash, cover every step and
component exactly, retain any declared exact failure, and is itself
content-addressed. Any failure or contact identity/count mismatch yields no
numeric metric vector.

The fixture-only compiler/evaluator passes MJMS0-MJMS7 and 52 controls, but
cannot install a production suite. The live inventory remains zero production
definitions and five unresolved metrics. Production metric semantics,
production semantic ceilings, calibration, held-out qualification, supported-
subset, training, equivalence, scientific, physical-acceptance, and release
authority remain false pending a later independently justified successor.

The source grammar is retained from exact clean-pushed verifier source
`ba3ba521a8570c623ce26c06fb0c4148ac2e0a27`; its 6,037-byte report is
`sha256:d3d8e68fa904e1712642e0767b93b3f4c9395c36da3a46660aee123937d7a7e9`.
[`../sdk/adaptation_provider/mujoco_warp_metric_semantics_validation_manifest.json`](../sdk/adaptation_provider/mujoco_warp_metric_semantics_validation_manifest.json)
binds the five source blobs, all formula/trace identities and controls, and the
earlier `6ccc6c9` terminal-audit failure as a separate invalid/incomplete
attempt. The executable audit grants source-conformance status only; it does
not convert the fixture suite into production semantics.

Binding source `4249920` also passed full cold canonical no-Godot
conformance. Receipt
`sha256:18bf77deb0006f40153582162d4fc7efe8732740b3f5895709fef5e1ae721a98`
binds seven passing stages, one declared Godot skip, and exact-once MJMS
source/evidence terminals. Its dependency key remains incomplete and non-
transitive with cache/reuse disabled, so it is integration evidence rather
than production metric, physics, subset, training, or release authority.

### MuJoCo Warp native-observable projection boundary

The next layer separates native runtime layout from MJMS formula semantics.
[`../sdk/adaptation_provider/mujoco_warp_observable_projection_contract_v1.json`](../sdk/adaptation_provider/mujoco_warp_observable_projection_contract_v1.json)
binds CPU and Warp `qpos`, `qvel`, `actuator_force`, energy, and constrained-
contact sources, shapes, observed dtypes, capture lifecycle, topology identity,
world selection, component ordering, quaternion representation, and contact-
event construction. A topology binding must cover every native state and
actuator slot exactly and may not contain normalization scales or semantic
ceilings; those remain separately governed by MJMS and MJSC.

Snapshot validation precedes projection. CPU samples are captured immediately
after `mj_step` and before any `mj_forward`; Warp samples follow completed
step/device synchronization and bind a single batch world. Disabled or
nonfinite energy, mismatched shapes/dtypes/bindings/steps, invalid contact
counts, wrong-world records, or lifecycle drift fail closed. Capacity overflow,
an unmapped included contact, or a Warp contact whose constraint bit cannot be
resolved is retained as an exact runtime failure and cannot produce a numeric
metric vector.

The fixture compiler passes MJOP0-MJOP7, `48` controls, and `24` exact
structural refusals, then reaches the exact five-metric MJMS evaluator. This
establishes source semantics only. The first required
`bounded_quadruped_gq15` production topology remains `0/1` bound and `1/1`
unresolved. No model was constructed and no step or world ran. Consequently,
production observable binding, metric semantics, ceilings, calibration,
supported-subset qualification, training, equivalence, scientific, physical,
and release authority all remain false.

Clean-pushed source `c163524` is bound to the retained 9,494-byte report
`sha256:3afc83d3a49630371386e89b099e9ca832b9e61457c5fc20d38f9bd121afebe2`
by
[`../sdk/adaptation_provider/mujoco_warp_observable_projection_validation_manifest.json`](../sdk/adaptation_provider/mujoco_warp_observable_projection_validation_manifest.json).
Binding source `4813229` then passed full cold canonical no-Godot conformance;
receipt
`sha256:b7663927c26f30ea9622f96de018bdd18904d6ad536dc849b765fa7ad60fcb50`
binds seven passing stages, one declared Godot skip, exact-once MJOP source/
evidence terminals, and no cache reuse or physical campaign. The observation
remains non-transitive integration evidence, not native-physics validation.

### Campaign-local process status is separate from authority

The campaign-attestation schema deliberately distinguishes successful local
execution from authority. A scoped run that passes every declared global,
lineage, and role gate sets `campaign_local_qualification_passed=true`; that
process-status claim does not imply that cold commissioning is complete or
that any physical, scientific, movement, coverage, equivalence, or release
claim is true. Consumers must evaluate the complete versioned claim vector,
not collapse it to either “all false” or “the run passed.”

RC3 exposed why this separation belongs in the architecture. Its full and
scoped executions passed, matched their exact source/runtime/host identities,
verified every content-addressed object and marker count, and opened zero
worlds. The prospective RC3 acceptance contract nevertheless required all
scoped claims to be false, which is incompatible with a successful scoped
attestation. That frozen condition remains authoritative, so RC3 is retained
as complete but invalid for executor promotion.

RC4 prospectively declares the schema-valid vector: the one local process
status is true, while every authority, scientific, physical, movement,
coverage, release, and cold-commissioning claim remains false. Claim-vector
comparison is exact and zero-margin. Any missing, extra, or differently valued
claim fails closed. A positive process closure may authorize a later adoption
step only; it cannot itself open a physical campaign or confer locomotion or
release authority.

### Proof catalogs participate in executor identity

The canonical full runner does not depend only on its own script bytes. Its
stage-1 workbench audit dereferences content-addressed proof identities from
`sdk/workbench/experiment_catalog.json`; stale proof bindings therefore make
the full executor fail even when the runner and audited source files are each
otherwise valid. RC4 demonstrated this boundary by stopping on the first stale
release-contract proof before producing a full attestation or starting its
scoped half.

RC5 treats the catalog as an explicit executor dependency. Its prospective
repair changes eight proof-digest fields—four release-contract references and
four support-matrix references—and changes no audit code, runner byte, physics,
controller, gate, margin, or claim vector. The repaired workbench audit must
pass before launch and the catalog, audit, and both ledgers are source-bound by
the RC5 freeze and scoped manifest. This repairs dependency coherence; it does
not make the repository's transitive dependency key complete and does not
authorize result reuse or physical execution.

RC5 subsequently passed its complete same-source cold full/scoped pair. The
architectural authority is the versioned RC5 closure, not the scoped
attestation's mutable interpretation and not a digest waiver. That closure
pins the exact executor source, runtime/host identity, eight full stages,
sixteen scoped gates, `48` gate CAS references, marker cardinalities, and claim
vector with zero margins. It commissions the exact campaign-local executor
while the scoped attestation's own `commissioned` and physical-authority fields
remain false.

Adoption remains a separate composition layer. It must pin the RC5 closure,
the exact commissioned executor and runtime, and the candidate campaign's own
fresh clean-pushed scoped attestation. Any runner-semantic or accepted
toolchain/host change requires another explicit recommissioning; source changes
that do not alter the pinned executor remain admissible only through the
fail-closed adoption verifier. This separation prevents process commissioning
from becoming movement, physics, or release authority.

### Live host parameters are part of adapter conformance

An engine adapter does not conform merely because it can compute a canonical
command and read a host parameter. For each actuator, the live object used by
the physical world must carry the same bounded authority declared by the
compiled morphology, or an explicit versioned mapping must prove their exact
relationship. The conformance path is therefore:

`descriptor -> compiled actuator -> live fixture joint -> adapter write/readback -> retained observation`

Every arrow is source- and identity-bearing. A detached host object populated
directly from the compiled actuator can test the final write/readback code, but
it cannot substitute for the fixture-created joint path. R23D54 made that gap
observable: the detached zero-world joint was assigned the compiled impulse
cap, while the physical fixture retained legacy global hip/knee caps. The
production authority path wrote target velocity only and then compared the
live cap readback to the morphology-specific compiled value, so every world
failed before trace row zero.

Future Godot/Jolt adapter qualification must therefore include a zero-world
fixture-path canary that constructs or composes the same live joint definitions
used by physical execution without advancing physics. It must prove complete
one-to-one actuator/joint coverage, exact cap application or declared mapping,
readback within the prospectively justified tolerance, and fail-closed
behavior for missing, stale, nonfinite, swapped, and wrong-scale caps. The
fixture compiler, proportion compiler, inherited descriptor contract, adapter,
and worker composition are all direct dependencies and must be bound in the
physical freeze.

This architectural repair is prospective. It does not reinterpret R23D54,
whose terminal observed a composite application mismatch and whose historical
source comparison proves a cap mismatch sufficient to cause it. The consumed
campaign remains complete-invalid with zero valid observations and no turning,
characterization, prone-to-standing, or release authority.

R23D55 implements that prospective boundary as a distinct development-only
layer. The physical builder and zero-world gate share a hinge-pair composer,
and every created host joint carries an exact joint ID plus a versioned fixture
composition marker. A one-time binder validates the complete eight-actuator
surface before any write, applies compiled maximum-impulse parameters, reads
all values back, and exposes a receipt to the physical walking gate. The policy
is opt-in and accepted only for full post-settle SDK authority, so historical
campaigns cannot silently acquire changed behavior.

The zero-world conformance route creates only unparented hinge objects. Its
finite S169/Godot 4.7 result and fourteen mutation controls prove configured
parameter plumbing, not measured motor output or dynamics. The fixture
compiler, proportion compiler, inherited descriptor contract, adapter,
physical composer, binder, runtime gate, and canonical runner are direct
exact-byte dependencies. The content-addressed surface also includes the LF
policy and CEP1 contract, executable audit, inventory, and analyzer. CEP1
retains the initial undeclared-rule refusal and now proves this as a four-path
R23D55-only non-migration extension with no ambient, historical-rule, or
tracked-history renormalization. Any change invalidates this local result;
current full conformance must be recommissioned before a later physical
declaration.

### Runner commissioning is a source-versioned architectural layer

Adding R23D55's source and runtime gates changes the canonical executor even
though it changes no physics. The process-commissioning layer therefore uses
a new identity, `LCA1-RC6-R23D55-CANONICAL-RUNNER-RECOMMISSIONING`, and cannot
inherit RC5's pass. RC6 binds 46 exact dependencies across the runner, runtime
profile, campaign roles, R23D55 cap-conformance route, evidence provenance,
workbench, and release authorities.

The layer is architected as one ordered, cold, same-source transaction:

`clean pushed freeze -> full 8-stage Godot suite -> scoped 16-gate/48-CAS suite -> retained RC6 closure`

Every transition is fail closed. Full failure prevents scoped execution;
source, runtime, toolchain, host, marker, or claim-vector drift invalidates the
pair; cache/reuse/selective execution is disallowed; and the exact source gets
no second attempt after a complete or failed pair. The zero margins are
appropriate only because this layer commissions a deterministic executor. It
does not establish statistical, physical, morphology, engine, or movement
equivalence.

The first R109 invocation exposed a publication-interface mismatch before the
operation lock: the route-specific closure key did not satisfy the shared
integration-ghost reader's established `physical_ghost_authorized` key. The
corrected publication retains both names, requires the consumer key in the
shared closure audit, and leaves every qualified physical path byte-identical to
the passing freeze. No physical attempt was opened by the refusal.

The corrected first attempt then commissioned the route in one real Godot/Jolt
world. The canonical eight-joint solve produced positive pivots, zero target
crossings, nonincreasing target error on all joints, nine aggregate body writes,
and 18 immediate native readbacks inside the outer guard across exactly two
solver steps. The following native and portable observation, supervised
termination, retained trace, CAS copy, and terminal all passed. R109 is now a
consumed integration result; the architecture permits no same-identity rerun and
grants no behavior or standing claim. R110 must wrap the commissioned route in a
distinct finite behavior contract before any longer horizon is opened.

R110 performs that composition without adding a new controller, evaluator, or
harness mechanic. Its declarative contract reuses the shared finite-behavior
gate and shared serialized supervisor, binds the consumed R107 behavior pair
and R109 route closure, and changes only the engine-side actuator mode selected
by the physical wrapper. The existing R109 component worker supplies two
positive fixtures and five forced failures; the gate separately parses the real
behavior worker and proves the shared refusal paths at zero world. The finite
two-world horizon cannot open until the clean, pushed, live-equal qualification
closure exists.

That closure now exists for source `a39d5b61`. The shared qualification stack
passed all ten checks over the 70-entry source manifest and 54-path physical
partition while constructing no model or world. The publication authorizes one
serialized two-world behavior pair and nothing broader; the physical wrapper
still rechecks the committed closure and all qualified physical blobs under the
global operation lock before creating an attempt identity.

That physical identity is now consumed as infrastructure-invalid. The shared
supervisor passed its source and authorization checks and launched Godot, but
the behavior worker produced neither final raw receipt nor ready marker within
the wrapper's exact `900 s` limit. The retained terminal records timeout exit
`124`, empty stderr, and no selected fatal diagnostic. Since the worker publishes
its complete counters only in the final receipt, model/world/step and trajectory
counts are unobservable rather than proven zero.

The architecture therefore requires R111 to separate wall-clock adequacy from
scientific horizon: retain the frozen finite physical question, justify a host
budget with explicit margin, and provide compact progress observability that
does not become behavior evidence or mutate physics. No same-identity rerun,
additional route ghost, or bespoke physics canary follows automatically.

R111 implements that separation in the shared receipt-terminated process layer.
Progress markers use their own schema and protocol, bind the termination nonce
and descendant process, require a strictly monotone sequence, and carry explicit
zero physics-evidence, physical-acceptance, and release authority. The behavior
supervisor additionally binds gate, source, attempt, authorization, seed, step
budgets, and monotone completed-step counts. Markers are retained in stdout and
only a compact final progress projection enters the terminal receipt; neither
surface is passed to the controller or evaluator.

Two independent clocks now bound execution. The `24,000 s` absolute cap covers
the maximum 2,400-step horizon using the retained R109 two-step duration as an
intentionally conservative per-step upper bound plus a `1.25x` required margin.
The `600 s` liveness cap resets only after a valid progress receipt and covers a
30-step interval with more than the declared `2.0x` margin. A malformed progress
receipt fails the protocol; silence trips the stall clock; a valid final raw and
ready receipt remain mandatory for any behavior result.

R111's single official zero-world qualification passed all `10/10` checks from
exact clean, pushed, live-equal source `4af46a3b`. It retained a nine-file,
content-addressed transaction while constructing zero models, opening zero
worlds, taking zero solver steps, and re-executing zero historical closure
audits. Its closure authorizes one finite candidate-plus-matched-zero physical
population. This changes execution readiness only: progress remains
non-evidentiary, and no behavior, recovery, standing, or release result exists
until a complete final raw receipt is retained and evaluated.

The authorized R111 run then validated this architecture under a long native
transaction. Twenty-five process-bound markers kept a roughly 34-minute worker
observable, while only its final 117,626,336-byte raw result entered behavior
evaluation. Both worlds completed 268 steps, all 536 in-run invariants passed,
and engine health remained green. The evaluator accepted a finite negative:
candidate and matched zero both timed out `establish_distal_support`, but the
candidate's 238 nonzero coupled applications created rear-only distal support
that the zero arm never produced. Front support remained absent. The result
therefore proves liveness separation and a real trajectory effect without
promoting progress into evidence or promoting rear-only support into recovery.
R112 remains zero-world diagnosis until a distinct physical successor is
prospectively declared and qualified.

The prospective freeze audit exercises declaration structure, exact bindings,
the inherited RC5 closure, R23D55 source/runtime gates, evidence provenance,
and workbench authorities, including 20 mutations, without constructing a
model or opening a world. Its pass is not executor commissioning. The freeze
must be committed and pushed before the cold transaction, and adoption cannot
move until a later content-addressed RC6 closure passes. This keeps process
authority separate from a future physical turning successor and from release
authority.

### Immutable results use pinned history; current implementation uses live bytes

The R23D55 audit now models two intentionally different dependency edges. Five
campaign-era infrastructure inputs point to exact blobs at observed source
commit `0d173d385f22fb8a30e7cc2234be8b17799512d9`; their Git object IDs and raw
SHA-256 digests prove the historical bytes. Fourteen production, runtime,
compiler, inherited-contract, and immutable-parent inputs point to the live
checkout and must remain byte-identical to the observed contract. The two sets
are executable, disjoint, complete, and total the original 19 bindings.

This split prevents normal prospective authority evolution from invalidating
an old result while still failing closed if the implementation on which that
result depends drifts. Mutable current-successor labels likewise belong to the
live campaign ledger, not to an immutable result assertion. The versioned
compatibility contract changes only audit architecture: it builds no world and
grants no physical, turning, prone-to-standing, or release authority.

### Corrected live-host routes retain their binding receipt

R23D56 makes the post-R23D55 data flow explicit:

`compiled morphology -> fixture-created hinges -> one-time cap binding ->`
`controller authority -> per-step actuator/phase observation -> retained CAS`

The cap-binding option is normalized at the shared physical entrypoint. The
worker requires its exact policy during preparation and again at the run
boundary. Preflight proves that the option is enabled but not executed before
world construction. During a real world, the shared fixture path binds all
eight caps before controller stepping; the R23D56 worker then projects the
resulting receipt into `sdk_authority_summary`, which is already retained by
the inherited terminal predicate projection.

This projection is evidence plumbing, not a control-plane input. The evaluator
checks the receipt schema, policy, eight writes, eight readbacks, host and
portable identities, configured cap values, and first-row readbacks. A bad or
missing receipt marks SDK summary integrity false and forces an invalid
terminal. Configured parameter readback still does not claim measured torque
or impulse.

R23D56 remains a three-world development characterization with no turning
gate. Its exact source freezer binds 82 paths plus the Rust source prefixes;
the nine-gate campaign manifest binds six lineage gates and the worker,
evaluator, and supervisor roles. Clean-pushed scoped qualification and separate
adoption remain mandatory before physics. No R23D56 world is currently open,
and this architecture adds no prone-to-standing or release authority.

### Trace report identity and physical readback use separate tolerances

The consumed R23D56 attempt exposed a serialization-boundary defect after all
three physical worlds completed. The live route produced a complete
actuator/phase observation on every step, and all eight configured cap
readbacks per world satisfied the host tolerance. The worker then serialized
three related values independently: applied target velocity, target-velocity
readback, and their precomputed absolute error.

The frozen Python evaluator reconstructed the absolute error from the first
two values and compared it with the third at `1e-15`. Decimal JSON round trip
can change the subtraction result by several binary64 ulps even though each
serialized value is valid. R23D56 observed maxima near `9.77e-15`, so trace
retention rejected the rows despite actual readback errors remaining within
the separate `2.5e-7` interface bound.

The closure architecture now keeps four layers explicit:

`live host write/readback -> configured-readback bound -> serialized report`
`-> representation-consistency check -> retained evaluator input`

A failure in the final check invalidates the campaign but does not imply that
the host write/readback failed. Conversely, a diagnostic showing the host
route worked cannot bypass a frozen evaluator or promote raw rows after the
fact. The closure binds both the complete raw files and the CAS-retained trace
diagnostics that mirror those rows, then reconstructs the exact historical
evaluator to reproduce the invalid result.

Future implementations must either derive the error once on the evaluating
side or use a prospectively justified representation tolerance. A zero-world
canary must traverse the production GDScript/JSON/Python shape with values that
exercise real round-trip residuals; exact-zero and conveniently representable
fixtures are insufficient. Physical readback bounds, serialization bounds,
and scientific outcome gates remain distinct contracts.

### Full-precision transport keeps the evaluator single-sourced

R23D57 chooses the first allowed successor architecture: preserve all three
production fields but serialize their binary64 values with Godot 4.7's
explicit `full_precision=true` mode. The runtime data flow is therefore:

`Godot binary64 application -> full-precision JSON -> CPython binary64 decode`
`-> unchanged derived-error recomputation -> unchanged trace predicate`

The Godot half does not reparse its own string or create a competing residual
oracle. It emits the source application plus default and full-precision nested
strings; the Python consumer alone applies the production predicate and checks
that each selected-path operand is bit-identical to its source value. This
keeps writer, transport, and evaluator responsibilities explicit.

The transport implementation is deliberately zero-world. Its receipt reports no
scene insertion, model, controller step, world attempt, or world build, and the
Python layer rejects any mutation that opens one. The immutable closure binds
and reconstructs its clean-pushed 12-file source dependency set before replay,
then checks exact runtime and live authority mirrors. This closes the transport
component only. It does not authorize the future worker, change the historical
R23D56 evaluator, or establish any actuator, walking, turning, recovery, or
release result.

### Cap-source factorial campaigns bind one profile before controller authority

R23D58 adds a narrow prospective layer around the existing production route:

`frozen profile -> live fixture construction -> one-time cap-source binding ->`
`controller authority -> per-step observation -> shared JSON transport -> CAS`

Each Godot/Jolt worker accepts exactly one of four profile IDs and always uses
the zero-heading arm. Profile normalization occurs at entry, but native binding
is deliberately deferred until the fresh world's eight hinge objects exist.
The complete surface is validated before the first write; exactly eight writes,
eight readbacks, and eight authority applications are then linked by actuator,
joint, host-joint, limb, selected source, selected cap, and tolerance. Terminal
and trace payloads use the same sorted full-precision serializer.

The evaluator revalidates all `2,992` rows and `23,936` applications per cell
from retained CAS objects before producing compact sequence digests and five
predeclared descriptive contrasts. No compact summary replaces the raw trace,
and no contrast is a winner or turning predicate. The supervisor serializes
four fresh worker processes under the global operation lock, retains positive,
negative, invalid, and incomplete terminals, and forbids selective replacement
of any complete cell. An incomplete replacement requires a distinct linked
identity and never overwrites the first attempt.

The campaign manifest separates worker, evaluator, and supervisor roles from
six lineage gates. The local zero-world surface can establish only source and
route conformance. Clean-pushed scoped qualification and fail-closed adoption
remain separate prerequisites for physical execution, and neither step creates
turning, prone-to-standing, cross-engine, or release authority.

### Finite selection and held-out validation remain different architecture layers

R23D59 and R23D60 deliberately split configuration selection from held-out
validation. R23D59 compares portable- and fixture-knee source profiles over its
own three-seed cohort and selects exactly one profile under a frozen
all-cells-adequate rule. R23D60 then binds that selected profile to a new seed
and three ordered reference/positive/negative arms. No R23D59 world is reused
as an R23D60 validation cell.

The R23D60 evaluator consumes only retained full-precision traces and the
prospectively closed source graph. It applies unchanged common physical gates,
then computes reference-conditioned positive and negative response magnitudes
against frozen selecting floors. Descriptive terminal-swing diagnostics are
retained but cannot be promoted into acceptance gates after the outcome. This
layering yields an exact bounded Godot/Jolt turning result without composing
historical Rapier or MuJoCo results into an undeclared three-engine claim.

### Enumerated closure and conformance dependencies reconcile exactly

CEP1 is the enumerated set of closure audits. CAD1 provides per-audit external
dependency manifests, and CDK1 composes that partial evidence inventory into
the larger conformance input candidate. Their count invariant is:

`CEP1 audit_count == CAD1 contract count == CAD1 registry count == CDK1 declared count`

With one registered complete audit, the current companion invariant is:

`unregistered_audit_count == audit_count - 1`

R23D60's closure moved CEP1 to `159` audits. A cold run correctly failed when
CAD1 remained at `151/150`; the repair advances all current declarations and
focused assertions to `159/158`. This reconciliation changes only dependency
metadata. The failed and passing runs remain separate retained zero-world
process observations, while cache reuse, physical authority, and release
authority remain disabled.

### Selected actuator semantics cross hosts by conserved outer-step impulse

R23D61 adds one explicit boundary between finite physical selection and the next
movement. The portable quantity is not a host force or solver-iteration limit;
it is the maximum angular impulse available to one actuator over one complete
`120 Hz` outer controller step:

```text
versioned exact-s169 profile receipt
                 |
                 +--> Godot HingeJoint3D maximum impulse
                 |
                 +--> Rapier ForceBased maximum force = impulse / outer dt
                 |
                 `--> MuJoCo symmetric force range = impulse / outer dt
                          five 1/600 s substeps sum to one outer budget
```

Solver iterations and MuJoCo substeps partition the budget; they do not multiply
it. The eight actuator IDs and cap values are ordered and content-addressed.
The profile resolution happens before host mutation, requires the exact
canonical public descriptor digest plus the compiled morphology-spec digest,
and returns typed OOD or unsupported receipts for valid but uncovered
requests. Raw input binary64 bits are deliberately not a support predicate:
the provisional form falsely refused Godot's equivalent JSON-decoded
descriptor while both portable identities matched. Exact cap bits remain
independently bound as hexadecimal binary64 strings. A host must not infer a
nearby morphology, apply a fixture override, or silently fall back.

The Godot mapping validates the complete receipt and all eight unparented hinges
before any write, rolls back on a post-write failure, and uses configured-value
readback only. Rapier validates real standalone `RevoluteJoint` ForceBased motor
configuration in f32 with an explicit representation bound. MuJoCo builds
ordered float64 force ranges and production-shaped XML fragments without
importing MuJoCo or constructing a model. These are three configuration
mappings of one portable semantic, not three physics results and not an
equivalence/non-inferiority study.

The exact contract is
[`../sdk/turning/r23d61_selected_actuator_profile_publication_v1.json`](../sdk/turning/r23d61_selected_actuator_profile_publication_v1.json).
Its complete zero-world runner builds no world and takes no solver step. It
changes no R23D58, R23D59, or R23D60 observation and supplies no measured
actuator response, movement, arbitrary-morphology support, turning extension,
prone-to-standing, or release authority. The publication is closed by
[`../sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json`](../sdk/turning/r23d61_selected_actuator_profile_publication_closure_v1.json)
from clean-pushed source `c61e56907d255e920297f088b93fc3e09ba12aef` after all eight
full-cold conformance stages passed. The architecture's next movement question
is canonical prone-to-standing rather than another turning campaign.

The R23D61 closure audit advances the enumerated CEP1 side of the dependency
invariant to `160`. A clean-pushed cold attempt correctly refused to construct
a dependency key while CAD1/CDK1 remained at `159` total and `158`
unregistered. The bounded repair sets both declared totals to `160` and derives
`159` unregistered from the unchanged single registered complete audit. It
adds no dependency shape, registration, cache authority, physical world, or
scientific result; the failed attempt remains a separate retained process
record. The distinct clean-pushed source `a56e4f4` then passed all eight cold
stages without reuse, satisfying the maintenance prerequisite without
broadening the publication or turning claim.

### Canonical recovery is an observation-gated state machine

QSDK-R24D1 places recovery above the engine adapters and below any learned or
hand-authored policy. QSDK-R24D2 implements the observation, classification,
supervision, evaluation, ABI, and adapter-capability layers of this architecture
without implementing the policy or opening physics. The portable architecture
is:

```text
native engine observations
        -> canonical observation receipt
        -> prone/stance/contact classifier
        -> ordered recovery phase supervisor
        -> bounded portable actuator request
        -> published actuator-profile resolver
        -> native adapter mapping
        -> post-step observation and assistance ledgers
        -> fail-closed evaluator/result receipt
```

Phase advancement is based only on post-step canonical observations. The six
ordered success states are `confirm_prone`, `establish_distal_support`,
`raise_body`, `stance_handoff`, `stance_dwell`, and `complete`. Phases cannot
skip or reorder. Recovery and stance control cannot overlap during handoff, and
success cannot latch before the exclusive stance dwell completes.

Every native adapter must either provide the ten required observation channels
and exact applied-actuation/intervention receipts or return a typed capability
refusal. It may not synthesize a missing physical observation, infer success
from an engine-local label, branch the policy by engine, or apply an implicit
fallback. Valid descriptors outside the admitted recovery scope remain OOD;
malformed or nonfinite observations are invalid.

The evaluator joins seven independent gate families: entry, exit, contact,
clearance, safety, timeout, and no-cheat. Thirteen assistance/mutation counters
must be exactly zero, including root force/torque/impulse, root pose/velocity
writes, guides, hidden body actuation, teleportation, collision disabling,
contact relabeling, gravity/time-scale mutation, and engine-specific policy
branches. A matched zero-command control prevents the initial state or passive
dynamics from masquerading as controller success.

R24D2 now executes the portable observation schema, classifier, supervisor,
matched-zero evaluator, and typed capability receipts through Rust, C, Python,
and Godot host surfaces. Its adapter mapping is a conjunction, not a vote:
Rapier/Parry and MuJoCo map `10/10` required channels, while stock Godot
4.7/Jolt maps `8/10`. Godot exposes post-step contact impulse but not solved
per-step hinge-motor impulse or the dependent actuator-work ledger, so
`applied_actuation_receipts` and `energy_balance_ledger` produce a typed
`unsupported_capability` refusal. A configured motor limit cannot substitute
for measured applied effort.

The abstract three-engine synthetic canary verifies portable phase and refusal
branches only; it is not native-collector or physical support evidence. R24D1's
sixteen physical thresholds remain unset, both development and held-out cohorts
remain empty, and no recovery controller or native collector exists.
Consequently the three-engine capability conjunction and complete prephysical
gate remain false, as do recovery, QSDK-R24, and release.

### Motor effort is receipted at the native impulse application site

QSDK-R24D3 adds an optional custom Godot/Jolt profile without changing the stock
adapter or the portable velocity-motor actuator. The profile is pinned to one
Godot source commit and one patch digest. It instruments each Jolt hinge-motor
warm-start and iterative velocity-solver application, where the signed delta
Lagrange multiplier and the generalized rate immediately before and after that
impulse are both available.

For Jolt's angle-constraint Jacobian
`J = [0, -axis_transpose, 0, axis_transpose]`, generalized rate is the hinge-axis
projection of body-2 minus body-1 angular velocity. The discrete kinetic-energy
change attributable to one motor impulse is therefore
`delta_lambda * 0.5 * (Jv_before + Jv_after)`. Accumulating this term at each
application is architecturally important: multiplying a final total impulse by
outer step endpoints can include velocity changes caused by other sequential
constraints. Positive and absorbed terms remain separate so a zero net sum
cannot hide substantial actuator activity.

The host receipt is versioned and includes a per-live-constraint sequence,
exact solver step, captured motor mode/target/limits, signed final motor impulse,
positive work, absorbed work, and derived net work. Reads fail closed outside a
safe synchronized post-step window, for invalid or non-hinge RIDs, fixed-joint
substitution, absent space/constraint, or before a positive-duration solver
setup. A caller must detect an unchanged sequence as stale; a numeric zero is
never manufactured for an invalid read.

This instrumented profile is separate from stock Godot and remains a candidate
until native characterization validates sign, cap, energy, limit, disabled-
motor, refusal, and freshness behavior. Compilation and a zero-world binding do
not establish those properties. No recovery policy, native recovery collector,
physical threshold/cohort, recovery world, or release gate changes here.

The engine evidence key is the executable pair, not the Windows console launcher
alone. The first clean-pushed cold run passed but bound only that launcher and
retained neither binary, so it cannot be adopted. The artifact-complete successor
copies both build outputs to durable evidence before execution, proves their
source-to-retained hashes, executes the retained pair, and verifies both hashes
again afterward. A post-hoc copy cannot repair the earlier receipt. The v2
successor passed and is adopted for its exact retained pair; different hashes
from the earlier cold output explicitly withhold reproducible-build and reuse
authority. This changes no native measurement or recovery capability.

The adoption source later passed the complete eight-stage uncached canonical
full-cold suite, with a content-addressed run receipt and independently verified
full-Godot attestation. That is a conformance prerequisite over the stock Godot
runtime plus retained-evidence audits. It does not substitute stock Godot for
the custom instrumented profile, does not characterize the patched telemetry,
and does not open a recovery or characterization world. A distinct committed
zero-world measurement/oracle freeze remains the next boundary.

### Native telemetry development preserves failed freezes and stays one-shot

QSDK-R24D4 froze a distinct development campaign, then closed as an immutable
zero-world negative before fixture construction. The declaration and rig used
parent-local `+Z` through `Vector3.BACK`, while the frozen worker and evaluator
expected `-Z`; the pinned engine source proves `Vector3.BACK` is `+Z`. This is a
source/oracle coordinate inconsistency, not telemetry evidence. The architecture
therefore requires a new versioned source family rather than repair of the
observed freeze.

QSDK-R24D5 was that prospective successor. Its physical fixture was one
world containing nine independent one-hinge cells with spherical child inertia
and a frozen parent. Signed drive and braking cells expose acceleration and
absorption; disabled-motor cells preserve moving negative controls; narrow-
limit cells expose motor-versus-limit separation; a sleep input exposes an
unchanged sequence as stale. A read-only `_integrate_forces` probe tests the
native stepping refusal without mutating direct body state. Axis identity is
consistently `+Z`. The declaration attempted to bind the Godot `real_t`/JSON
representation of the inertia vector exactly.

The evaluator derives effective axis inertia from the host inverse-inertia
tensor, then recomputes angular-momentum and kinetic-energy changes from raw
pre/post rates. It reports impulse and work residuals, positive/absorbed
decomposition, and the configured `max_abs_torque * solver_step` clamp. Those
are measurements, not development acceptance thresholds. Structural
completeness, exact cell/step identity, finite encoding, no-cheat counts, and
claim boundaries determine validity; a surprising finite physical result does
not. This separation permits later thresholds to be justified prospectively
without optimizing or discarding the first observation. R24D5 additionally
binds its R24D4 negative closure and executable audit, uses 24 evaluator
negative controls plus 14 supervisor-contract mutations. Exact clean-pushed
source `fffb773b408b0cf8bb4a3ba78e773b62c3a0e52a` passed that declared
zero-world receipt.

The physical route is one-shot for an exact source/runtime key. The supervisor
requires clean local/upstream/cached/live equality, ten exact Git blobs, the
adopted two-executable R24D3 pair, a content-addressed same-source zero-world
receipt, and the global physical lock. It persists the consumed attempt before
the launcher starts and preserves failures with bounded world counts.

That one-shot R24D5 world completed its worker schedule (`1` world, `20`
physics steps, `68` raw samples) but failed the frozen evaluator before any
evaluation record. The physical worker called
`JSON.stringify(report, "", true, true)` and emitted the exact single-precision
component as `0.05000000074505806`; the frozen evaluator required
`0.0500000007450581`. The zero-world worker had compared two in-memory values
derived from the same constant and never passed the physical raw-envelope
through the full-precision serializer/evaluator pair. Therefore a complete
zero-world gate must include an end-to-end serialization oracle for every exact
identity consumed later by a physical evaluator. R24D5 remains consumed and
implementation-invalid; its retained raw numbers cannot become measurements,
and only a distinct successor may correct the architecture. None of this
supplies a recovery controller or changes the stock Godot profile.

QSDK-R24D6 is the distinct prospective successor that implements that
architectural correction. The physical fixture and descriptive question stay
finite and unchanged, but the zero-world path no longer compares a constant to
itself. The frozen evaluator emits the complete synthetic nine-cell/68-sample
report shape. The pinned Godot runtime replaces engine, fixture, refusal, and
`real_t` readback fields and serializes the entire envelope through both default
and full-precision `JSON.stringify` calls without building physics. The default
form must fail the real evaluator at the exact inertia identity; the full form
must pass it. Both envelopes are retained and content-addressed, and the receipt
separates their synthetic `1/1/20/68` shape from actual `0/0/0` execution.

The numeric source boundary is explicit rather than inferred from one observed
payload. Five files at pinned Godot commit
`5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` establish default single-precision
`real_t`, `Vector3` storage, `Vector3.BACK = +Z`, sorted dictionary keys, and the
two JSON float-conversion paths. Five binary32 projections are exact identities,
including `0.05 -> 0.05000000074505806` at the full-precision evaluator. The
shorter default form is a preregistered negative control, not a tolerance.

R24D6 retains R24D5's closure and audit among eleven source bindings and preserves
all earlier observations. Its local freeze rejects 29 evaluator mutations and
18 contract mutations while accepting both declared surprising finite outcome
controls. A retained warnings-as-errors parser negative and the subsequent
explicitly typed parser pass are precommit diagnostics only. The first clean-
pushed source at `ef540fa50ce9d155aa5d78bbef04070b62dc0a76` then produced an
immutable incomplete official attempt: two static stages passed and the
inherited R24D3 audit rejected its stale `.gitattributes` binding before any
worker, Godot process, template, serialized envelope, evaluator invocation, or
world. That source cannot rerun. The incident is now an exact dependency of a
new maintenance source, which must clean-push and pass the entire zero-world
gate before physical authorization can change. This instrumentation integrity
gate is a prerequisite to honest recovery-controller evidence, not an
additional turning campaign.

That maintenance source was clean-pushed at
`55032839756cc8a9089a2a4eb4e06db71ab99ca4` and exposed the next architectural
boundary without constructing physics. All five static stages passed, the real
custom Godot worker passed its zero-object fixture preflight, and both serializer
calls reached the frozen evaluator. The default form produced its declared
inertia negative. The full-precision form failed first at
`fixture_collision_layer` because the JSON template parse changed integral
Variant values into floating-point Variants before reserialization.

The failure surface is complete and finite: `313` values across `21` normalized
path families changed from integer tokens to double tokens, and `234` values
across `9` families are consumed by strict integer evaluator predicates. The
binary32 decimal projections themselves remained correct. Thus numeric
precision and semantic JSON type preservation are separate transport
obligations. A full-precision float formatter cannot reconstruct an integral
type erased earlier in the pipeline.

R24D6 is now an immutable valid zero-world negative with `18` retained files,
`17` unique CAS digests, and actual `0/0/0` world/build/solver counts. A distinct
successor must carry a frozen integral-path schema, restore all declared paths
before serialization, and exercise mutation controls over every family through
the unchanged evaluator. No R24D6 source or result may be repaired, no physics
is open, and the architectural priority remains trustworthy recovery telemetry
before prone-to-standing rather than another turning campaign.

QSDK-R24D7 implements the required distinct type-restoration boundary without
changing the R24D6 record. A frozen declarative schema identifies 21 normalized
path families and all 313 intended integral occurrences in the synthetic and
future physical report shape. Restoration happens after the real Godot JSON
parse and before either serializer. It is narrow: only a declared `TYPE_FLOAT`
that is finite, exactly integral, and numerically unchanged may become
`TYPE_INT`; missing, extra, duplicated, ambiguous, non-finite, fractional, or
value-changing conversions fail closed.

The worker emits a compact restoration receipt proving all 313 pre-restore
floats, all 313 conversions, and all 313 post-restore integers, including the
predecessor's 234 strict evaluator inputs across nine families. The evaluator
also validates the complete schema and rejects one family-specific type-loss
mutation for each of the 21 families in addition to the 29 inherited controls.
This closes the known oracle-adequacy hole prospectively; it does not claim the
official zero-world gate has passed.

The prospective freeze and one parser-only diagnostic remain zero-world work.
The exact source must be committed and pushed before the supervisor may prove
the real default-negative/full-precision-positive serializer pair. Physical
authorization, native telemetry characterization, profile promotion, recovery,
prone-to-standing, and release authority remain false. This is still the
observation-integrity layer needed before a recovery controller can be judged,
not a new turning policy campaign.

The clean-pushed R24D7 source subsequently passed that complete serializer
qualification with exact `21/313` type restoration and actual `0/0/0` physical
execution. The sole authorized physical development world nevertheless closed
implementation-invalid at its stepping-refusal control. The architectural
mistake was treating Godot's `_integrate_forces` callback as if it executes
inside `JoltSpace3D::step`. Jolt enqueues the callback while stepping, clears
the flag before returning, and Godot dispatches the callback later through
`PhysicsServer3D::flush_queries`, before the next step.

Consequently, a read from `_integrate_forces` cannot by itself test the
instrumentation binding's `space->is_stepping()` refusal. R24D7's 65 observed
non-refusals are consistent with the guard and supply no active-step safety
evidence. The source and attempt remain immutable. Any successor must expose or
inject a prospectively specified hook whose call order is proven to lie inside
the guarded step, or redesign the refusal contract prospectively and qualify
that distinct source. It must then repeat the complete serializer gate before
one new physical identity. No telemetry profile or recovery layer may consume
R24D7's raw numbers.

QSDK-R24D8 moves the timing witness into the adapter's native step boundary.
The v2 architecture has two clocks: Jolt's hinge telemetry sequence advances
only when that constraint receives velocity-constraint setup, while a
`JoltSpace3D` sequence advances on every containing space step. Immediately
after `PhysicsSystem::Update`, the space asks every registered joint to capture
telemetry while `stepping` is still true. A hinge replaces its immutable
snapshot only when the native sequence has advanced. The public static binding
continues to refuse access while the space is stepping and otherwise returns a
copy annotated with the current read-space sequence.

This separates three states that the earlier direct read conflated:

- no supported snapshot exists, so the binding returns `null`;
- a snapshot was captured in the just-completed step, so capture and read space
  tokens match and `snapshot_is_current_space_step` is true;
- the containing space advanced while a sleeping constraint produced no new
  solver receipt, so the capture token remains fixed, the read token advances,
  and `snapshot_is_current_space_step` is false.

The capture call is deliberately between the native update and Godot/Jolt's
post-step cleanup. It does not change actuator, solver-order, body, contact, or
limit semantics, and it never relabels a configured limit as applied effort.
The wrapper snapshot prevents a later safe scripting read from observing
mutable Jolt solver state directly.

The first physical consumer is constrained to eight exact space steps. Godot's
pre-step `physics_frame` signal requires one priming boundary; the eighth sample
then arrives at the boundary after solve eight. Global server deactivation at
that point makes the impending ninth `PhysicsServer3D::step` a no-op. This
control is part of the frozen execution schema and is mutation-tested. Until
the complete cold zero-world qualification passes, this remains prospective
architecture with zero physical authority. Even after a timing positive, the
numerical telemetry and recovery layers remain separately gated.

Historical closure verification and live-successor verification are now
explicitly separate adapter responsibilities. The first R24D8 zero-world
source incorrectly routed its ten-file live source tree into the unchanged
R24D7 audit, which binds a seven-file historical working tree; the audit failed
closed before build or worker. The maintenance route instead materializes a
sparse, disposable R24D7 view from the pinned upstream commit and frozen v1
patch, normalizes only those generated files to their retained raw-LF identity,
executes the old audit unchanged, and removes the view. The R24D8 freeze then
verifies the live v2 diff independently. This prevents mutable successor source
from becoming an implicit input to historical closure truth while avoiding any
temporary rewrite of the live instrumented engine.

## R24D8 qualified snapshot-timing architecture

The two-clock design is now physically observed for the exact isolated hinge.
During four active steps, native telemetry sequence and captured-space sequence
advanced in lockstep with the post-step read sequence (`2` through `5`), and
each immutable snapshot reported that it was captured while the space was
stepping and belonged to the current read step. After the declared terminal
sleep transition, native telemetry and capture remained at `5`, while the
space read sequence advanced from `6` through `9`; the adapter therefore
exposed the last immutable active capture with an explicit stale/current bit
rather than silently presenting old solver state as new.

This closes the architectural timing uncertainty that invalidated R24D7. It
does not close numerical semantics. The values transported in the snapshot are
retained evidence but have not yet been checked against a prospectively frozen
one-hinge oracle and are not accepted as accurate impulse or work telemetry.
Accordingly, capability negotiation must continue to refuse promoted solved
per-step hinge-motor impulse and dependent actuator-work support for release
purposes. Recovery observation can use this route only after the separate
numerical characterization and profile-promotion boundaries pass.

The closure audit reconstructs the exact external ten-file patch view from
pinned source rather than trusting the current live engine checkout. It binds
all fifteen executed repository sources as historical Git blobs, verifies
every retained zero-world and physical object through CAS, enforces exactly one
matching physical attempt, and removes the reconstructed view. Thus current
checkout state is a runtime safety input, not historical result identity.

## R24D9 numerical characterization boundary

R24D9 separates the now-established snapshot timing mechanism from the still
unaccepted numerical semantics. The future adapter characterization must
sample the same immutable v2 telemetry payload together with capture/read
sequence tokens, public motor-parameter readbacks, native body state, and exact
fixture identity. The evaluator independently reconstructs momentum, kinetic
energy, non-cancelling work, and the Jolt source-derived clamp comparison; the
adapter receipt is evidence input, not its own oracle.

The architectural unit is intentionally one isolated hinge. Nine declared
cells separate signed drive, signed braking, disabled-motor behavior,
limit-active behavior, and sleeping stale-snapshot behavior so a passing
aggregate cannot cancel a failed mechanism. All `68` samples and all cells are
mandatory. Registration/refusal, current-step timing, and finite-value checks
are validity gates; numerical residuals are reported without an empirical
acceptance margin.

The implementation now realizes this boundary with a nine-cell rig, dual-mode
worker, strict evaluator, serialized supervisor, fifteen-binding manifest, and
freeze audit. The zero-world worker validates the runtime/fixture/refusal
surface, then byte-passes the evaluator-authored synthetic envelope unchanged;
this avoids Godot Variant and `real_t` reserialization drift while keeping the
Python evaluator as the exact schema authority. Five retained precommit
diagnostics preserve the three successive serialization failure modes plus the
initial worker failure and final compatibility pass. All are `0/0/0` and none
is official qualification.

Capability negotiation must continue to refuse promoted solved-impulse and
actuator-work support until this exact implementation passes a fresh complete
independent cold zero-world gate, a single finite physical characterization
produces a valid result, and a separate profile-promotion decision is declared
and closed. Consequently recovery and prone-to-standing remain downstream.
This architecture does not alter the separate bounded turning positives
already earned by all three native engines.

## Canonical runner extensions require RC10 recommissioning after the RC8 and RC9 negatives

The campaign-attestation layer correctly distinguishes qualification from
adoption. R23D62's clean-pushed scoped run at source `93d31e8e` passed all
`22` declared global, lineage, and role gates and retained `66` CAS references
without constructing a model or world. Adoption nevertheless refused because
the current `sdk/run_conformance.ps1` bytes no longer equal the executor bound
by RC7. Nine of ten commissioned core bindings still match. The runner alone
contains six additive conformance-extension families totaling `192` added
lines, which is still source drift under an exact commissioning contract.

The first architectural response was LCA1-RC8, not an exception in the
adoption composer. RC8's one clean-pushed full launch passed stages 1 through 3
and failed stage 4 because the R23D62 preregistration audit still asserted the
older pre-qualification release/support state. The scoped graph did not start,
the pair root remained empty, and no model/world opened. The retained incident
proves exactly five stale expectation values and seven content-addressed
artifacts. RC8 is closed negative and cannot rerun. It does not establish that
the runner or physics failed; it establishes that one source consumer was
inconsistent with the live authority.

RC9 was the next architectural response. It repaired that preregistration
consumer, but its one clean-pushed full launch then reached a second stale
consumer in the same stage. Stages 1 through 3 passed; the repaired R23D62
preregistration and evaluator-v2 gates passed; the Rapier route audit then
failed on its original pre-qualification status literal. Two executed
release/support values disagreed. The later Godot route, MuJoCo route, and
MuJoCo worker-test consumers carried the same literal but were never reached.
The scoped graph did not start, the pair root remained empty, and no model or
world opened. RC9 is another immutable process/source-consumer negative, not a
runner, route, physics, or turning failure.

The current architectural response is LCA1-RC10. It reconciles exactly those
four consumers and three implementation hash bindings while binding the exact
unchanged runner, measured PowerShell `7.6.5` / `.NET 10.0.11` runtime
inventory, reconciled `167`-entry audit inventory, R23D62 physical semantics,
and immutable RC8/RC9 incidents. It requires one serialized same-source pair:
the complete `8`-stage Godot-inclusive conformance graph followed by a
`16`-gate scoped graph with `48` content-addressed gate references. All
identity, marker, numeric, and claim-vector margins are zero. Caching,
prior-result reuse, partial execution, and a second same-source attempt are
disabled.

The `72`-dependency RC10 freeze passes all direct preflights and rejects `22`
claim-changing mutations with zero models/worlds. This remains prospective
zero-world process architecture; no RC10 pair or commissioning closure exists
yet. After a positive immutable closure, the
changed source invalidates the earlier R23D62 qualification for adoption, so
R23D62 must qualify again and be adopted against the exact newly commissioned
executor. Only then can its nine native turning cells open. This preserves a
narrow trust chain:

1. exact executor/runtime commissioning;
2. exact campaign source and independent role qualification;
3. exact composition/adoption;
4. serialized physical execution and immutable evaluation.

No earlier layer can stand in for a later one. At this boundary R23D62 has no
physical result, `QSDK-R23` remains false, and release readiness remains
`10/25`. The architecture grants no formal cross-engine equivalence,
arbitrary-morphology, robustness, prone-to-standing, physical-acceptance, or
release authority.

## Production authorization receipt parity is a pre-attempt architectural gate

R23D62 demonstrated that production authorization logic and the supervisor's
receipt projection are separate trust boundaries. At source `b784368a`, the
Godot and Rapier authorization functions each compare both frozen and attempt
ordered matrices against the complete nine-cell identity set. MuJoCo does the
same. Yet only MuJoCo's receipt composer exposed
`complete_ordered_nine_cell_matrix_validated=true`. Godot's first runtime
receipt omitted it, and the supervisor discovered the mismatch only after
issuing the one-shot attempt authorization.

The R23D62 interlock remains correct and immutable: the closure path now exists
and all three historical workers refuse that campaign. Its five retained files
prove zero cells, models, worlds, controller steps, traces, or physical
measurements, while `completion.json` consumes the attempt and forbids repair
or selective continuation. This is a receipt-schema projection failure, not a
controller or physics observation.

Every physical successor must therefore treat production authorization receipt
parity as a zero-world gate that runs before both freeze and attempt issuance.
The gate must exercise the actual production authorization path for each
engine against synthetic durable authorization fixtures, require an exact
shared field set and Boolean types, prove the complete ordered matrix field is
true, and reject field removal, false values, wrong types, and engine-specific
aliases. Supervisor property access must fail with a named schema error rather
than an incidental host missing-property exception. Passing this gate grants
only source/process conformance; fresh clean-pushed qualification and adoption
still precede physical execution, and only a complete prospective nine-cell
result can satisfy `QSDK-R23`.

## R24D10 makes native step scheduling an explicit adapter boundary

The R24D9 failure establishes that a scene-loop iteration is not an admissible
proxy for one retained solver step. R24D10 therefore treats the Jolt-space
sequence token as the authoritative execution clock. The adapter must arm while
the server is inactive, retain its initial observation before enable, and
transition through a small event-driven state machine: start token `1`, observe
completed token `N`, prepare token `N+1`, then deactivate immediately after
observing token `20` and before the next solve can start.

This state machine is intentionally outside the immutable numerical
recomputation kernel. The worker validates exact token topology and first-state
preservation, then delegates the unchanged nine-cell numerical report to a
content-addressed R24D9 kernel only after those validity checks pass. A loop
counter cannot author `physics_step_count`; the count is reconstructed from the
zero-initialized native token interval. This prevents an integration layer from
declaring a convenient count that disagrees with the physics engine.

The zero-world supervisor is a separate architecture component with no
physical switch. It serializes the operation, consumes one same-source
qualification identity before its first stage, verifies clean local/upstream/
cached/live equality, binds nineteen source and toolchain dependencies, performs
an independent cold runtime build, checks the real zero-object refusal path,
and evaluates an exact synthetic report shape. Its synthetic one-world payload
is schema input only, never a physics observation. Exact source `11df9b56`
passed that complete route with the independently cold-built binary pair and
actual `0/0/0`; the immutable closure binds `23` run files and `19` unique
digests. This qualifies the source/runtime route. Only a later prospectively
declared and separately authorized native attempt could characterize the finite
fixture.

## R24D11 separates channel-source evidence from mechanism coverage

R24D10 subsequently passed its parent-bound physical authorization and retained
one exact native world, one build, Jolt-space tokens `1..20`, and all `68`
samples. That result is execution-valid and characterizes the frozen fixture,
but it deliberately contains no fitted accuracy tolerance or profile-promotion
rule. R24D11 therefore makes profile adoption a separate **finite decision**
rather than allowing the characterization worker or evaluator to promote its
own runtime.

The decision distinguishes three layers that must not be collapsed:

- a generic instrumented source exists at Jolt's motor-impulse application
  site;
- a finite fixture actually activates each mechanism needed by the portable
  channel semantics;
- a future recovery collector safely composes those measurements into complete
  per-actuator and energy ledgers.

The first layer is source-proved and the R24D10 fixture supplies finite witnesses
for signed drive, positive work, source-derived cap behavior, disabled zero,
limit separation, invalid-RID refusal, and current/stale snapshot timing. The
second layer remains incomplete: both intended signed-braking cells report
zero motor impulse and zero absorbed motor work and match their disabled controls
in every motor-telemetry field. R24D3 declared absorbed-work characterization as
a prerequisite before any of those values existed. Treating exact nonzero
directionality as a mechanism-activation witness therefore does not introduce a
post-hoc performance tolerance or reinterpret R24D10's residuals.

The instrumented v2 profile consequently remains a candidate, stock Godot
remains an explicit `8/10` recovery-observation profile, and the three-engine
capability conjunction remains false. The next adapter boundary is deliberately
small: a new development identity must establish that initial hinge-relative
motion reaches the native solver, contrast motor-enabled and motor-disabled
signed braking, and expose opposing impulse plus absorbed work. It must pass a
complete zero-world gate before physics, but it need not repeat R24D10's drive,
limit, sleep, or sixty-eight-sample coverage and it does not need a separate
shortened physics ghost.

## R24D12 makes activation order part of the native adapter contract

The R24D10 braking absence came from an adapter state-transition mismatch, not
from an observed weak motor. While a Godot rigid body is frozen/static,
`JoltBody3D::set_angular_velocity` records angular surface velocity. Changing
the mode from static to rigid clears that surface velocity. A scene property
readback before the transition therefore cannot prove that the native rigid
body will enter the next solve with the requested rate.

R24D12 makes the admissible order explicit: attach to `SceneTree`, unfreeze,
disable sleeping, write the public angular velocity, verify both the scene and
PhysicsServer body-state projections, and only then enable physics. The adapter
must stop after native step token one. The complete fixture is four isolated
signed cells—two motor-enabled and two disabled controls—so its production
question is already the smallest useful physical route and no separate physics
ghost is required.

The source freeze reuses the exact R24D10 cold-built executable pair only when
source, patch, binary, environment, and cold-baseline keys match. It explicitly
does not reuse R24D10's campaign result or promote any capability. Fifteen
content bindings plus source, evaluator, and runtime-reuse mutation controls
guard this transition.

Exact clean-pushed source `7b807819...` passed the complete five-stage
zero-world route with the byte-identical R24D10 binary pair, a real
custom-runtime zero-object worker, and independent synthetic evaluation. The
retained route has `19` files, `15` unique digests, and actual `0/0/0`. This
qualifies activation-order source and exact-runtime reuse, not native braking.
The synthetic two-direction braking witnesses remain explicitly nonphysical.
No R24D12 world may open until a separate production supervisor path is frozen,
qualified, and explicitly authorized.

## R24D14 closes the native mechanism layer without promoting the profile

The qualified R24D14 representation seam and one-step production route now have
a valid physical result. In one isolated zero-gravity world, both signed enabled
cells produced motor impulse opposing their initial hinge rate, positive
absorbed work, and negative net work, while their paired disabled controls
preserved exact-zero impulse and work. One step is architecturally sufficient
for this mechanism-activation contrast because every declared cell and both
signs are present; it is not a numerical-accuracy or recovery horizon.

This closes the second of the three layers separated at R24D11: the source site
exists, and a finite native fixture now activates the required braking channel.
The third layer remains gated. Capability negotiation must continue to refuse
the promoted Godot solved-impulse and actuator-work profile until a distinct
finite decision confirms that all previously declared R24D3 mechanism-coverage
requirements are jointly satisfied by immutable evidence. Only after that
decision may a native recovery collector and canonical prone-to-standing route
consume the profile. No additional physical run belongs inside the promotion
decision itself.

## R24D15 promotes a runtime profile, not the stock adapter or recovery route

The third mechanism layer identified at R24D11 now closes positive. The exact
active-step-snapshot v2 profile has immutable finite coverage for all eight
R24D3 mechanism families, so it may back applied-actuation receipts and the
dependent energy-balance ledger. This promotion is keyed to the custom source
patch and retained console/engine binary pair; it is not transferable to stock
Godot and carries no numerical-accuracy claim.

The architecture keeps evidence promotion separate from executable adapter
publication. R24D15 authorizes, but does not implement, a new profile-scoped
Godot recovery capability mapping. R24D16 must make that mapping fail closed on
runtime identity: the exact instrumented binary may expose all ten measured
channels, while stock Godot must continue returning typed unsupported-
capability for solved motor impulse and actuator work. Only after that zero-
world source/conformance boundary closes may the three-engine capability
conjunction become true and collector/controller work begin.

## R24D16 keeps runtime identity, capability mapping, and recovery execution separate

The Godot adapter now has two explicit capability paths. The historical stock
mapping remains byte-unchanged and reports eight measured channels. A new
profile-scoped wrapper promotes the two missing measurement channels only when
the running console and engine SHA-256 identities match the retained
active-step-snapshot v2 pair and
`JoltPhysicsServer3D.hinge_joint_get_motor_telemetry` is registered. Otherwise
it delegates to the stock mapping. Both paths cross the same public Godot
extension and portable recovery core, so refusal and support semantics do not
fork by engine-specific controller code.

R24D16 qualifies this routing and capability conjunction at zero-world; it does
not add a recovery collector or state transition. R24D17 is the next
architectural layer: native collectors must assemble the canonical recovery
observation, the deterministic controller must consume that observation under
the existing ordered supervisor, and the physical decision contract must bind
its thresholds and cohorts before a recovery model or world is constructed.

## R24D17 publishes the recovery runtime seam without pretending it ran physics

The portable recovery layer now exposes three versioned operations: publish the
exact-s169 development profile, validate one complete already-sampled native
post-step observation, and plan one deterministic engine-neutral control step.
Those operations cross the Rust core, C ABI, Python wrapper, Godot extension,
and the Rapier and MuJoCo adapter bindings. The adapter remains responsible for
sampling native state after its declared substeps; the portable core remains
responsible for strict channel, identity, finite-value, intervention, actuator-
budget, and controller validation.

The controller has no engine branch. Confirm-prone emits no actuation,
establish-distal-support emits the frozen symmetric joint target, raise-body
uses a `360`-step binary64 smoothstep toward the canonical zero-joint stance,
and stance handoff returns ownership without a recovery command. Matched-zero
also emits no command. The qualification proves these transformations and
refusals as software behavior only.

The prospective physical profile is now part of the architecture: `16`
thresholds bind exact s169 geometry and product task requirements; three
outcome-exposed MuJoCo cells form the repeatable development lane; and nine
separate native cells form the held-out finite-decision lane. The official
qualification executed neither lane and opened zero worlds. R24D18 must add the
genuine construction, native post-step sampling, trace, terminal, retention,
and evaluator route behind a distinct development declaration. Its first ghost
should be only large enough to traverse those production seams; behavioral
success remains a later development observation, and the held-out lane remains
sealed until a frozen finite decision.

## R24D18 exposes the public-profile validator boundary before any solver step

The MuJoCo recovery route now has explicit construction, prone initialization,
five-substep actuation, ten measured observation channels, portable
supervision, paired evaluation, full-trace retention, and a compact
content-addressed projection. The first route ghost was intentionally only
fourteen steps per arm, but it did not reach step zero. Its exact public-profile
readback accepted the compiled model; the inherited `MujocoBw19vRobot`
identity validator then recomputed force limits from the base morphology and
rejected the published knee override.

R24D19 must replace that inherited force-range predicate with a recovery-route
validator that checks cardinality, timestep, integrator, velocity gain, and the
already-bound exact public per-actuator vector. A zero-world model-shaped
fixture must accept the frozen vector and reject one mutated force range before
a new clean-pushed qualification. No controller, threshold, selector, horizon,
evaluator, or held-out identity changes at this boundary.

## R24D19 makes the authored timestep the next explicit route dependency

The public-profile validator now reaches past actuator binding in the genuine
MuJoCo constructor. Its first physical invocation exposed an architectural
identity bug: the model XML owns the timestep through
`selected_policy_development.INTERNAL_DT_S`, while the recovery validator
reconstructed a nominally equivalent value from outer-step constants. Those
two evaluation orders differ by one binary64 ULP, so exact validation rejected
the correctly authored model before initialization.

R24D20 must preserve exact comparison while removing duplicate authority. Its
route validator and zero-world fixture both consume the production internal
timestep, and the fixture rejects the adjacent representable value. This is a
model-identity correction only; construction order, controller, thresholds,
initializer, native substeps, mapping, collector, evaluator, retention, and
held-out routing remain unchanged.

## R24D20 closes the native route seam and moves the boundary to initial state construction

The v3 route now traverses the complete architecture in genuine MuJoCo:
public-profile construction and readback, `MjData`, exact initial-state writes,
native contact/kinematic/energy collection, portable validation and phase
supervision, matched-zero execution, paired evaluation, and content-addressed
full/compact publication. The completed two-world trace means the next defect
is not another unresolved bridge between those components.

The remaining boundary is the initializer itself. Its folded pose places
multiple limb capsules deeply through the ground; `mj_forward` reports twenty
contacts before solver step zero. With no actuator input, contact resolution
ejects the model from the prone gate. R24D21 must version the initializer and
initial-state identity, derive its pose from the same compiled geometry, and
commission it with a minimal native no-actuation stability check. It must not
hide a settling simulation, loosen the existing prone predicate, or change the
controller and call that an initializer repair.

## R24D21 promotes recovery-pose feasibility into morphology capability

The current bounded descriptor does not expose the two geometric authorities
that recovery now needs: hip-anchor vertical placement and a joint range that
can fold the upper link clear of a ventral-contact plane. Those values are
hardcoded in the compiled v1 morphology. R24D21 proves their exact s169
combination cannot satisfy the canonical prone start, so the architecture must
refuse that task for that immutable identity.

R24D22 must add these authorities through a versioned engine-neutral contract,
not a MuJoCo-only XML override. The old descriptor, morphology-spec digest,
walking claims, and turning claims remain untouched. A distinct recovery-
capable descriptor/spec identity must carry its own validation, support
receipt, geometry-feasibility result, adapter mapping, and later physical
evidence. This converts the discovered incompatibility into the same explicit
support/OOD/refusal model the public SDK requires.

## R24D22 establishes the recovery-morphology compilation boundary

The additive `sporespore_recovery_morphology_descriptor_v1` surface now owns
the recovery-only hip vertical anchor, symmetric hip and knee range authority,
and canonical prone pose. Compilation preserves the embedded base descriptor
and morphology identities, emits a distinct recovery morphology identity, and
returns either `supported_exact`, a valid typed geometry refusal, or a typed
schema/identity error. The exact R24D22 reference is geometry-positive with
`0.01625237411795359 m` minimum limb clearance; that result has zero native
model or behavior authority.

Native recovery adapters must therefore consume the compiled recovery receipt
instead of modifying the legacy bounded morphology or applying engine-local
XML overrides. A mapping must preserve the base and recovery identities,
materialize the declared anchor/ranges/canonical pose, report enough native
readback to detect a mapping mismatch, and refuse unsupported host capability
before controller execution. The first development implementation is MuJoCo;
Rapier/Parry and Godot/Jolt receive the same portable semantics later without
making formal cross-engine equivalence an SDK1 prerequisite.

R24D23's route ghost is intentionally small: construct the production native
model, apply the canonical initializer, establish its first valid observation,
and take only the few steps needed to prove the route executes. It is not a
seed-level behavior demonstration and cannot accept prone-to-standing. Once
that route is code-valid, physics failures belong to controller development
and must remain visible rather than being hidden behind more harness canaries.

## R24D23 binds recovery morphology through the existing production route

The first native recovery-morphology adapter does not own a second morphology
compiler or actuator path. It consumes the public R24D22 receipt, passes its
compiled morphology through the existing MuJoCo tree generator, and calls the
same extracted public actuator-profile XML binder used by walking and turning.
An exhaustive zero-world projection binds all eight child-body positions,
joint positions, axes, and limits. The physical constructor repeats those
eight readbacks from `MjModel` before the canonical initializer writes state.

The route class changes only morphology and initializer identity. Native
stepping, ten-channel collection, portable phase supervision, controller
planning, paired evaluation, full/compact retention, manifest publication,
terminal propagation, and operation locking remain shared. Its two-step-per-
arm coverage contract is sufficient for this construction and first-step
question because no changed branch is seed-, phase-, horizon-, or volume-
dependent. Controller-command coverage begins only after this route is shown
execution-valid; it is not smuggled into the mapping ghost.

## R24D23 closes the adapter route and exposes the portable-context boundary

The genuine MuJoCo route now proves that one public recovery receipt can drive
production XML construction, exhaustive eight-joint native readback, canonical
recovery initialization, solver stepping, native observation collection,
portable supervision, paired evaluation, retention, and publication. The
paired two-step trace passed all declared in-run invariants with zero hidden
interventions and no held-out access. Adapter construction and route plumbing
are therefore no longer the active recovery blocker for this exact identity.

Portable recovery supervision still accepts only the bounded walking
descriptor as its context authority. Consequently, native joints correctly
constructed with recovery hip limits of `+/-1.6 rad` are classified against
the old `+/-0.72 rad` limits. R24D24 must add a versioned recovery-aware
request/context that binds base descriptor, recovery descriptor, compiled
recovery morphology, capability, and threshold identities together. It must
preserve the legacy request byte-for-byte and fail closed on mixed or mutated
identities. Classification must consume the recovery joint limits without
changing any behavioral threshold.

The native contact observer is a separate interface question. Ordinary
MuJoCo box-plane soft contact keeps the torso near `0.06 m`, yet the ventral-
contact predicate changes after the second retained step. The observer must be
qualified against declared native contact geometry and provenance before a
longer prone-confirmation or command-coverage run; the frozen prone predicate
cannot simply be loosened. Once context and observation are execution-valid,
controller behavior—not another full route ghost—is the next physical subject.

## R24D24 closes the recovery context and native contact seam

The portable recovery ABI now uses an additive V2 request family to carry one
complete content-addressed recovery context through initialization, native
collection, classification, control, and paired evaluation. V1 shapes remain
unchanged and reject the new field. V2 validates the base and recovery
descriptor/morphology identities as a unit, so recovery observations use the
recovery joint authority without changing the immutable walking/turning
descriptor or any behavior threshold.

The MuJoCo collector reconstructs the named torso geom's nearest surface point
from `mjContact.pos`, signed `dist`, and the oriented first frame vector before
applying the inherited ventral-face classifier. The frozen two-step native
decision proves that this observer identity and the V2 context survive the
production route on the declared development cell. It does not prove the
controller: both arms ended in `confirm_prone` before any active command. A
distinct R24D25 route may now extend only far enough to cover that first active
command while retaining the same engine-neutral command semantics.

## R24D25 exposes the active application receipt as a distinct JSON boundary

The first active native application executes before its content-addressed
receipt is published. R24D25 reached that boundary and exposed a type leak:
the NumPy comparison used to compute host clamping produced `numpy.bool_`
leaves, while the portable canonical JSON surface accepts only standard JSON
scalars. Inactive routes initialized the same vector with built-in `False`, so
all earlier two-step coverage remained valid without exercising the active
serialization branch.

Architecturally, a production route is not qualified merely because its
decision evaluator accepts synthetic facts. Every result-bearing branch must
construct its exact production receipt and pass that receipt through the same
canonicalization boundary zero-world before physics. R24D26 may factor receipt
construction into a pure helper and cast the comparison to built-in `bool`;
it may not broaden the JSON encoder, alter command meaning, or change any
physical threshold. The historical foreign-scalar shape must remain a forced
failure. R24D25 itself is consumed invalid/incomplete and establishes no
command or recovery behavior claim.

## R24D26 makes active receipt construction a reusable production primitive

The native MuJoCo route now separates two model-free production primitives:
`prepare_active_recovery_host_command_v1` maps ordered portable commands to
host targets and built-in clamp booleans, while
`canonicalize_recovery_application_receipt_v1` constructs and canonicalizes
the exact application receipt. `step_native` calls both primitives after its
normal command checks and native solve; the zero-world gate calls those same
functions without constructing a model. This keeps qualification coupled to
the real result-bearing branch rather than a parallel fixture encoder.

The receipt primitive rejects any clamp leaf whose concrete type is not the
built-in JSON boolean type. The positive path therefore proves its own output
types and canonical digest, while the retained `numpy.bool_` mutation fails at
the production boundary before physics. Numeric target, force, impulse, and
work fields retain their existing explicit float projections. No generic
encoder widening or hidden coercion was introduced, and the frozen R24D25
source/evidence interpretation remains untouched.

## R24D26 physically qualifies the first active application boundary

The shared production primitives now have both zero-world and native evidence.
The qualification called the exact mapper and canonicalizer with no model,
then the physical route called them after the candidate's five native
substeps. The retained application receipt contains eight built-in boolean
clamp facts, eight finite target velocities, eight measured force caps, eight
non-zero signed impulses, and its own canonical digest. The independent
post-step observation carries the same active-command identity through the
portable collector and evaluator.

This establishes a clean architecture boundary: command planning, native
application, receipt canonicalization, source observation, collection, and
portable evaluation are connected for one active step without an
engine-specific policy branch. It deliberately says nothing about later
phase viability. Successors should reuse the same receipt and evaluation
mechanics and extend only to a predeclared phase/progression boundary rather
than add another parallel integration harness.

## R24D27 uses the route's natural stop instead of another micro-horizon

The R24D27 architecture changes no result-bearing controller, model, adapter,
observer, threshold, or portable evaluator. It invokes the same paired
`run_paired_development` route with the physical profile's existing `1,200`
step upper bound. `_run_arm` already stops immediately after a portable
terminal or entry into a stance-owned phase, so the physical trajectory ends
at the first natural boundary and never steps terminal memory or the
uncommissioned stance controller.

This produces one complete answer about the currently commissioned recovery
controller. The candidate either reaches `stance_handoff` through the exact
ordered recovery phases or terminates under an already-frozen timeout. The
matched-zero arm independently does the same while remaining unactuated. A
positive progression decision requires measured `distal_support_gate`, then
measured `raised_body_gate && safety_gate`, on the actual portable transition
receipts. No separate empirical score or campaign threshold is introduced.

The portable evaluator intentionally remains broader: it defines recovery
success as portable `Complete` with a failed matched-zero control. R24D27
retains that verdict byte-for-byte and adds a separate preregistered projection
for reaching the recovery-to-stance ownership boundary. The two answers must
not be conflated. Reaching `stance_handoff` would prove the current recovery
controller's distal-support and body-raising progression on one development
cell; it would not prove stance-controller execution, dwell, complete
prone-to-standing, repeatability, held-out behavior, or cross-engine recovery.

Qualification stays compact. It executes the inherited production zero-world
controls, six direct decision mutations, an exact predecessor source-manifest
comparison, and the retained R24D26 real trace as a known-incomplete projection
control. It does not replay historical closure audits or construct a physics
world. This shared natural-stop pattern is intended for later progression and
terminal-development successors rather than another bespoke horizon harness.

## R24D28 must make every collection refusal a first-class retained receipt

R24D27 exposed one remaining observability break in the shared route. After
`world.step_native` returned, `collect_native_v2` produced a value that failed
the route's acceptance predicate. `_run_arm` immediately collapsed that value
to `QSDK_R24D18_NATIVE_COLLECTION_REFUSED`, and the worker's invalid publisher
could retain only the generic exception and stack. This erased the distinction
between an in-run observation-invariant refusal and an integration mismatch.

The successor architecture factors that exact acceptance seam into a reusable,
model-free helper. A rejected receipt must carry its support status and refusal
reason together with arm identity, semantic step, phase, current observation,
current native application receipt, and the accumulated partial-state identity
to the durable invalid envelope. A direct zero-world forced-refusal control
must execute the same helper and publisher boundary. This is diagnostic
instrumentation only: it changes no controller command, MuJoCo dynamics,
morphology, initializer, observer meaning, threshold, margin, selector, seed,
horizon, or portable evaluator, and it does not add a predictive physics
canary.

R24D28 implements that boundary with one reusable
`require_supported_native_collection_v1` helper rather than another physical
harness. Accepted collector receipts pass through unchanged. Rejections become
`NativeRecoveryCollectionRefusal` values whose JSON-safe diagnostic is consumed
by a compact shared worker path. The publisher writes the complete partial
result first, hashes the exact bytes, and exposes only a small linked invalid
summary to the supervisor. That ordering prevents a later summary or transport
failure from erasing the last interpretable route state.

The complete source gate retains `59` exact predecessor bindings, permits two
declared source changes, adds seven successor sources, and passes the inherited
`31` controls plus six focused observability controls at zero physical
execution. This is the reusable architecture for future native collection
refusals; successors should add a new focused control only when they introduce
a genuinely new failure boundary, not for every observed outcome.

## R24D28 proves the receipt path and exposes one semantic contact seam

The physical R24D28 execution proves the typed refusal architecture end to end.
At candidate step `82`, the production route preserved the exact
`invalid_observation / absent_nonfoot_contact_values_invalid` receipt, current
observation and application receipt, `82` accepted prior steps, and exact
`1 model / 1 world / 83 outer / 415 solver-step` counts. The worker durably
wrote and hashed the full partial result before the compact invalid envelope.
No generic exception now stands between a native observation defect and its
diagnosis.

The retained step also identifies the next reusable conformance boundary.
Native contact classification treats each rear distal lower-cap contact as a
foot contact and therefore excludes it from nonfoot IDs and impulse, while the
separately computed foot-cap-excluded clearance remains negative. The portable
validator correctly refuses that internally inconsistent representation. The
successor must define one authoritative relationship among contact presence,
clearance, and provenance and lock it with the exact retained observation plus
focused mutations. This is observer-schema work, not a controller or behavior
threshold change; it must pass without constructing a world before any new
physical progression attempt is authorized.

## R24D29 separates contact provenance from signed geometric clearance

R24D29 replaces the two copied body-clearance validators with one engine-neutral
`validate_body_clearance_observation_v1` helper called by both the native
collector and portable supervisor. The helper owns identity, ordering,
finiteness, unique contact IDs, impulse, ventral classification, and
present/absent provenance consistency. It deliberately does not infer native
contact presence from the sign of a separate geometric-clearance measurement.

This separation keeps both channels honest. A negative foot-excluded clearance
without a distinct native nonfoot contact is valid data, but its sign is neither
clamped nor converted into a fabricated engine contact. Downstream classification
therefore still sees the exact negative value and refuses raised-body and
stable-stance progress. The retained R24D28 step-82 tuple and eight focused
mutations prove that both entrypoints apply the same rule while malformed IDs,
impulse, and ventral claims still fail closed.

The complete R24D29 development gate is `45/45` over `75` exact sources and
constructs no world. Its pending official qualification can close only this
semantic conformance boundary. It cannot establish controller viability or
standing; those require a distinct R24D30 physical development freeze.

## R24D29 closes through the shared content-addressed zero-world verifier

The official clean-pushed qualification passed all `45/45` controls over `75`
frozen source bindings without constructing or stepping a world. Its closure
uses `sdk/conformance/content_addressed_zero_world_closure.py` to verify the
source commit and parent, all Git blobs in the retained receipt, all eight
qualification artifacts, canonical source-manifest and preflight identities,
toolchain, operation lock, exact retained observation projection, and zero
physical counts. No historical closure population is re-executed.

One closure-audit draft incorrectly treated a JSON object's property order as
the mutation population's semantic order. The qualification runner had
intentionally serialized sorted keys. The correction verifies exact key set,
cardinality, and truth values in the receipt while the frozen contract/fixture
retain the ordered population; it adds no canary and does not rerun the
qualification.

R24D29 is now a closed semantic-conformance dependency. It authorizes no
physical route and cannot be requalified. Any controller-progression work must
start at a separately frozen and qualified R24D30 physical development source.

## R24D30 composes the prior route, decision, diagnostics, and semantics

R24D30 adds no new locomotion mechanism. Its worker is a thin composition
layer: R24D27 still owns the natural-stop progression projection and all in-run
route checks, R24D28 still owns typed native-collection refusal retention, and
R24D29 still owns the complete signed-clearance semantic preflight. R24D30
retargets only immutable envelope identities before append-only publication and
invokes the same `run_recovery_morphology_route_ghost` production entrypoint for
its eventual physical attempt.

This composition keeps the zero-world gate compact. All `45` predecessor
controls execute unchanged; three additional controls bind the R24D29 closure,
prove that projection retargeting preserves every decision field, and prove
that refusal retargeting preserves the complete diagnostic with zero behavior
or release authority. No model is instantiated. The source audit reuses the
shared content-addressed helpers instead of re-executing historical closures
or duplicating their verifier mechanics.

The architecture remains fail-closed at the physical boundary. The wrapper
accepts only one exact clean-pushed qualification receipt for its source,
serializes the physical workload with the shared operation lock, rejects a
second reservation for the same source/campaign, and publishes either a full
trace plus compact decision or a content-addressed partial refusal plus invalid
projection. Until qualification succeeds, no R24D30 world is authorized.

## R24D30 retains a complete trace and isolates the failed safety term

The clean-pushed qualification and physical route exercised the architecture
as designed. Qualification rebound all `83` source blobs and passed `48/48`
controls without a world. The serialized physical reservation then published
two complete native arms, a `47,130,382`-byte full result, a compact decision,
and a manifest that binds both. The closure audit uses the shared
content-addressed verifier for Git, qualification, source-manifest, and durable
artifact checks; it reads the retained physical trace but does not re-execute
physics or historical closures.

R24D30's complete result makes a useful architectural distinction between pose
progress and supervisor completion. The candidate reaches `raised_body` and
stays there for `439` observations, but recovery ownership cannot hand off to
stance until both `raised_body_gate` and `safety_gate` are simultaneously true.
Safety is the conjunction of joint limits, actuator budget, zero forbidden
nonfoot contact impulse, and bounded energy-balance residual. The first three
hold for every raised-body observation; the energy residual exceeds its frozen
`0.25 J` maximum for every one. The phase therefore times out without a skip,
and the portable evaluator correctly returns a valid development failure.

This separation prevents a visually upright pose from silently becoming a
standing claim. It also prevents the closure from guessing which layer caused
the energy discrepancy: the native collector, actuator-work integration,
dissipation ledger, and controller are still distinct hypotheses. R24D31 must
analyze them against the immutable trace in a zero-world boundary, preserve the
R24D30 outcome, and freeze any correction before constructing another world.

## R24D31 makes MuJoCo energy work independent and inspectable

R24D31 leaves `RecoveryEnergyBalanceLedgerV1` and its residual equation
unchanged. It versions only the MuJoCo observation mapping and replaces the
adapter's constant zero dissipation with a native-work collector. Around each
split MuJoCo step, the adapter copies the generalized velocity after
`mj_step1`, applies the already-existing control, completes `mj_step2`, and
forms force-work increments at the exact solver timestep. The native receipt
retains constraint, damper, fluid, and adhesion increments and cumulatives
separately before their signed net energy-removal value enters the portable
ledger.

Actuator work remains an independent ledger term. The adapter computes it in
actuator coordinates and cross-checks it against `qfrc_actuator dot qvel`; it
does not fold a discrepancy into dissipation. The work function accepts no
mechanical-energy or residual argument, preventing an implementation from
defining dissipation as whatever value makes the equation close. Shape,
finiteness, identity, and nonnegative-cumulative-removal failures are typed
route failures rather than silent repairs.

The ten-point retained fixture proves why this change is needed without another
world: R24D30's unactuated arm has an absolute terminal residual of
`0.7191017288295729 J` under a ledger that records every known work term as
zero. Twelve controls bind that diagnosis, the exact source change, and
mutation failures. They construct no MuJoCo model. Physical adequacy remains a
separate question: only R24D32 can show whether the signed native terms remain
representable by the portable nonnegative cumulative field and whether the
unexplained residual satisfies the unchanged `0.25 J` bound on a trajectory.

## R24D31 closes through shared content-addressed qualification mechanics

The clean-pushed R24D31 source passed one complete `90`-source, `12/12`-control
qualification without constructing a model or world. Its closure audit does
not reproduce another full campaign verifier: the common
`verify_zero_world_qualification_closure` path owns retained-file hashes,
canonical JSON identities, commit and source-manifest binding, toolchain,
operation-lock state, attempt cardinality, production-preflight identity, and
all zero-physics counters. The R24D31 layer supplies only its finite fixture,
semantic decision, claim boundary, and successor rules.

This preserves a strict architectural boundary between source qualification
and physical adequacy. The v2 collector is accepted as an independently
sourced energy-work implementation, but no native trajectory has yet shown
that its signed components fit the portable nonnegative cumulative field or
that the resulting residual stays within `0.25 J`. R24D31 therefore exposes no
physical runner and cannot be requalified. R24D32 must be a distinct
clean-pushed **development** freeze that reuses the production route, retains
every native component and invariant, and qualifies fully before its first
model construction.

## R24D32 compact qualification and physical invariant boundary

R24D32 keeps historical verification out of the changing-source critical
path. The immutable R24D30 closure content-addresses its complete `48`-control
population; the successor executes only the `12` live R24D31 controls and five
R24D32 controls. This prevents old audits from depending on current source while
preserving a constant-cost proof of their exact frozen population. The new
controls cover identity/lineage, unchanged cell and decision semantics,
energy-field mutations, and lossless collection-refusal retargeting.

The physical worker is a thin envelope around the unchanged production route.
After each portable step it joins observation, native receipt, and portable
receipt by exact order and rejects a count mismatch. Every native constraint,
damper, fluid, adhesion, step-total, cumulative-total, actuator-work, and
portable energy field must be finite. Signed step and cumulative component sums
must agree within the `1e-10 J` representation tolerance, native and portable
actuator/dissipation values must be exactly identical, cumulative dissipation
must be nonnegative, and the independently recomputed residual must be finite.
Any collection refusal is republished through the existing R24D28/R24D30 typed
partial-plus-invalid path under the R24D32 identity.

The pre-freeze smoke exercises this complete success path for only two outer
steps per arm. Its accepted source state built two genuine MuJoCo models and
worlds, completed `20` native solver steps, and validated four energy records;
it did not reach raised-body state, evaluate natural progression, or consume an
official physical identity. After the prospective commit is pushed, the shared
clean-source runner must still execute one complete qualification before the
full `1,200`-step-per-arm route can open.

## R24D32 closes through reusable physical-attempt mechanics

The official R24D32 route exercised the architecture end to end: exact clean
source qualification, one physical reservation, paired production model
construction, native stepping, collection, portable classification, energy
validation, natural termination, compact projection, full-trace publication,
and manifest retention. The completed trace contains `1,520` outer steps and
`7,600` MuJoCo solver steps. Re-derivation in the closure confirms that every
retained step satisfies the signed component identities and the native to
portable energy mapping.

The closure adds reusable physical-attempt verification to
`content_addressed_zero_world_closure.py`. That shared layer now owns exact
retained inventory, source binding, attempt cardinality, schema identities,
qualification binding, lock lifecycle, artifact hashes, model/world/step
counts, and common no-held-out/no-release fields. The R24D32-specific audit is
limited to its phase transitions, paired-arm semantics, per-step energy
equations, frozen decision, and claim mutations. Future physical successors
should use this layer rather than copy another full campaign verifier.

Architecturally, the corrected component source is sound under the declared
invariants but the aggregate balance is not yet closed tightly enough for the
existing safety threshold. Constraint work is the only nonzero passive term in
this model. The matched-zero route stays within `0.07633092795183449 J`, while
the actuated candidate grows to `1.0714549090012824 J`; that localization makes
a universal constant offset less plausible, but it does not establish
integration error, force-staging error, missing work, controller fault, or
threshold inadequacy. R24D33 must remain zero-world until one of those
distinctions is supported by the retained trace and source.

## R24D32 retained-trace diagnosis: continuous power versus discrete work

The v2 energy component layer is internally coherent but has a temporal
abstraction leak. It samples generalized velocity before `mj_step2`, then
multiplies the force fields produced by the forward-dynamics stage by that
velocity and `dt`. This is a left-endpoint approximation to continuous power.
The production model uses `implicitfast`, whose effective velocity update also
contains derivatives of smooth forces, including the linear velocity-servo
actuators. Those effective discrete terms are not represented in the v2
receipt.

The reusable retained-trace diagnostic intentionally stays outside the runtime
and evaluator. Its endpoint-centered actuator projection explains
`0.7473909068066504 J` of the candidate's `1.0714549090012788 J` terminal
discrepancy, while leaving the matched-zero outer impulse projection unchanged.
Because R24D32 did not retain per-native-substep post velocities, effective
implicit forces, or generalized constraint impulses, the projection cannot
close or certify the remaining `0.3240640021946284 J`.

The v3 architecture must therefore expose both measurement layers. Historical
v2 left-endpoint fields stay immutable. A successor adds per-native-substep
pre/post velocities, reported pre-step forces, independently derived effective
implicit velocity-actuator forces, and time-centered actuator/constraint work.
The matched-zero receipt must report effective implicit work explicitly rather
than infer zero from a zero pre-step force. This is a source/observer change;
the controller, morphology, physics configuration, threshold, and R24D32
decision remain unchanged. No physical successor is open yet.

## R24D33 reusable implicit-step observer boundary

The v3 measurement now exists as a pure adapter-level primitive rather than a
campaign-specific runtime fork. It accepts only the exact information needed
to reconstruct one native velocity update: timestep, target and reported
pre-step actuator state, gain and force ranges, actuator moment, pre/post
generalized velocity, and reported pre-step generalized force components. It
accepts no mechanical-energy, residual, decision, or threshold input.

For an unsaturated direct velocity servo the primitive applies `-kv` to the
actuator-space velocity increment. At either reported force limit it applies a
zero derivative, matching MuJoCo 3.11's derivative source. Both branches map
through the same retained actuator moment and must agree in actuator and
generalized work space. Constraint work uses midpoint generalized velocity;
nonzero damping, fluid, and adhesion are typed refusals until supported.

Reusable algebra and mutation controls live with the primitive. The R24D33
worker adds only lineage, immutable-digest, unchanged-threshold, and no-physics
checks, while its source audit checks the declarative inventory in one Git
operation. This keeps the new observable qualified without adding historical
audit replay to the critical path. Physical route wiring belongs to a distinct
post-qualification R24D34 source.

## R24D33 qualified observer and R24D34 integration boundary

The pure v3 observer passed its one clean-pushed qualification at source
`4e7a94daebec600621cfeb6a1eaee54f43c8a196`: `12/12` controls, `104` exact
sources, and zero model/world/step execution. Its qualification closure uses
the shared content-addressed verifier for commit ancestry, retained files,
canonical JSON, toolchain, source-manifest, lock, and zero-physics invariants;
the R24D33-specific audit checks only measurement semantics and claim state.

The integration seam remains deliberately unimplemented. R24D34 must sample
pre/post generalized velocity and the retained pre-step force/moment data for
each native substep, invoke the qualified observer, and serialize historical
v2 and new v3 terms together. Its wiring needs a distinct clean-pushed source
and zero-world qualification before the bounded two-step-per-arm smoke can
instantiate MuJoCo. R24D33 cannot itself authorize that physics.

## R24D34 native implicit-step integration seam

`MujocoImplicitStepRecoveryWorld` is a distinct production world type; the
historical `MujocoNativeRecoveryWorld` continues to select the v2 ledger. The
new route replaces only the opaque `mj_step2` call with its public MuJoCo 3.11
components in source order:

`mj_step1 -> control -> fwdActuation -> fwdAcceleration -> fwdConstraint ->
sensor/check -> pre-state copy -> mj_implicit -> post-velocity copy`.

This creates an observation seam without adding a second forward solve or a
second integration. The per-substep receipt owns copies rather than live
`MjData` views and includes target, gain, force range, actuator moment,
pre/post generalized velocity, reported pre-force components, the qualified
force-limit branch, v2 left-endpoint work, and v3 effective centered work.
`implicit_step_energy_trace.py` is the reusable serialization/aggregation
authority: it re-invokes both independent observers and validates native-step,
application, cumulative, and portable mappings. Its portable selection uses v3
while the v2 values remain explicit evidence. No behavior API, controller,
model, threshold, or historical result changes under this seam. The full local
development gate passed `10/10` controls over `114` paths at zero models,
worlds, and solver steps; official qualification and physical execution remain
separate and unopened.

## R24D34 sparse actuator-moment failure and R24D35 seam

R24D34's qualified route reached the pre-integration snapshot in its first
candidate substep but failed before native integration. In MuJoCo 3.11,
`MjData.actuator_moment` is not a dense Python-visible `(nout, nv)` matrix: it
is the `nJmom` sparse-value buffer, with row structure in
`moment_rownnz[nout]`, `moment_rowadr[nout]`, and
`moment_colind[nJmom]`. The frozen R24D34 route copied that one-dimensional
buffer and then required dense shape. The immutable R24D34 closure preserves
that failure and refuses all behavior interpretation.

The R24D35 representation seam must be a small fail-closed adapter between the
completed MuJoCo forward stages and the already-qualified R24D33 observer:

`sparse MjData fields -> structural validation -> mju_sparse2dense ->
independent dense-shape/value cross-check -> immutable observer input copy`.

No observer algebra, route staging, controller, model, integrator, portable
mapping, or threshold belongs in that adapter. Its zero-world controls own
sparse structural mutations; the reusable trace validator continues to own
per-substep v2/v3 algebra and aggregation. The next physical route smoke stays
at two outer steps in each of two serial arms and remains code-path evidence
only.

## R24D35 sparse adapter and reusable bounded-smoke mechanics

`sparse_actuator_moment.py` owns the engine-specific representation boundary.
It validates the CSR-like MuJoCo arrays, calls `mju_sparse2dense`, independently
reconstructs the dense matrix, and returns an immutable value plus a complete
replayable receipt. `native_recovery_development.py` consumes the dense copy
only after all control-dependent forward stages and before `mj_implicit`; the
new v2 world route selects v3 native-step and v2 substep schemas without
changing the historical R24D34 route type.

`implicit_step_energy_trace.py` re-expands each retained sparse receipt before
replaying the existing observer algebra and aggregate mappings. Sparse
structure mutations live with the sparse primitive, while serialized
sparse/dense mutations live with the trace authority. The R24D35 campaign
worker therefore binds those reusable results instead of duplicating their
mechanics.

`bounded_recovery_route_smoke.py` now owns the common clean-qualification,
one-writer, exact-source, paired-route, count, append-only publication, CLI,
and invalid-result-retention mechanics. The R24D35 development gate passed
`9/9` controls at zero worlds. Its content-addressed dependency model binds the
R24D34 `114`-entry manifest digest plus a complete `16`-file current overlay;
official qualification and physical execution remain separate and unopened.

## R24D35 retained invariant rejection and R24D36 projection seam

R24D35's sole official qualification passed `9/9` at zero worlds. Its one
bounded physical smoke then crossed the sparse-adapter and native-integration
seams before the unchanged historical-v2 nonnegative cumulative-dissipation
guard rejected the first candidate outer step. No complete observation or
native-step receipt escaped `step_native`, so exact runtime counts and values
remain unpublished rather than inferred from mutable process state.

The architectural defect now exposed is a projection mismatch. The native
observer owns signed work components; constraint work can add or remove energy.
The existing portable energy-balance field owns nonnegative cumulative
dissipation. Negating the sum of signed constraint and passive work does not
turn all possible trajectories into a nonnegative dissipative quantity.

R24D36 therefore belongs before portable observation construction:

`signed native work receipt -> semantic classification -> nonnegative
dissipation projection or typed refusal -> portable observation`

The receipt must preserve every signed component and both historical-v2 and
effective-v3 measurements before any projection. A valid projection must have
an explicit physical meaning and algebraic adequacy argument; it cannot clamp,
take an absolute value, use the energy residual as an input, or rewrite R24D35.
Until this zero-world seam is declared and qualified, no new recovery physics
is authorized. Controller, model, integrator, morphology, initializer,
behavior evaluator, thresholds, and held-out cohorts remain unchanged.

## R24D36 exact-zero projection and typed-refusal architecture

`energy_work_projection.py` is a pure engine-adapter semantic boundary. Its only
inputs are the four signed native work components; mechanical-energy change and
the balance residual are absent from the function signature. It retains those
values in a replayable receipt, classifies portable-v1 representability, and
never clamps, takes an absolute value, or invents a balancing term.

The currently qualified R24D33 passive subset is exact-zero. The portable-v1
mapping is therefore:

`(constraint, damper, fluid, adhesion) == (0, 0, 0, 0) -> supported_exact,
external_work = 0, dissipation = 0`

`constraint != 0 with passive == 0 -> unsupported_capability:
portable_v1_signed_constraint_work_unrepresentable`

`any passive != 0 -> unsupported_capability:
nonzero_unqualified_passive_work`

`MujocoSignedWorkPreprojectionRecoveryWorld` is a distinct v3 route; historical
R24D35 route classes keep their existing behavior. Each v3 substep receipt adds
parallel historical-v2 and portable-v3 preprojection receipts. After native
integration, the new route summarizes the v3 receipts and, when unrepresentable,
raises `NativeEnergyProjectionRefusal` with the exact signed components before
`_state_frame` constructs the current portable observation. R24D36 has no
physical runner. Its `9/9` development controls pass at zero worlds; one
clean-pushed zero-world qualification is pending before a distinct successor
may version the engine-neutral signed-work ledger or ask another physical
question.

The sole R24D36 clean-source qualification subsequently passed `9/9` complete
and `6/6` primitive controls at `0/0/0` model/world/solver execution. Its
content-addressed closure makes the preprojection/refusal seam reusable but does
not add a representable nonzero signed channel to portable ledger v1. R24D36 is
closed and has no physical execution authority.

R24D37 therefore owns the next architectural layer rather than another MuJoCo
route patch:

`native signed components -> engine-neutral signed-exchange ledger version ->
energy-balance evaluator version -> portable observation`

That successor must specify schema migration, API/ABI bindings, exact
aggregation, support/refusal behavior, evaluator algebra, and mutation controls
at zero world. Only a later distinct contract may wire the qualified ledger into
a physical recovery route.

## R24D37 versioned portable energy-ledger layer

The portable core now owns a v2 ledger independently of any engine adapter:

`ordered signed source increments -> engine-neutral ledger v2 -> versioned
balance evaluator`

The ledger retains cumulative applied actuator work, signed external work,
signed constraint exchange, and nonnegative passive dissipation as disjoint
fields. Its balance equation is `current - initial - actuator - external -
constraint + passive`. The evaluator exposes the signed residual and its
absolute magnitude but contains no threshold, acceptance branch, or physical
result.

Ordering has two identities: `sequence_index` is contiguous and owns exact
aggregation order, while `semantic_step` is nondecreasing and may repeat for
multiple native substeps. Aggregation is a deterministic binary64 left fold;
each finite source increment carries explicit measurement provenance, and the
ordered population and ledger each receive a digest. Invalid order,
nonmeasurement, nonfinite values, negative passive dissipation, overflow, and
component-partition mutation fail closed.

Migration is an explicit API operation rather than implicit deserialization.
The unchanged v1 domain maps losslessly into v2 with zero signed constraint and
external channels. A v2 value maps back only when both channels are exactly
zero; otherwise the receipt retains a typed unsupported-capability reason. The
same aggregate, evaluate, and migrate semantics are exposed through additive C,
Python, and Godot bindings.

R24D37 does not consume R24D36 native receipts, change the current portable
observation, or construct an engine world. After clean-source qualification,
R24D38 must separately map every retained native component receipt to ordered
v2 increments and version the enclosing portable observation. That wiring must
preserve the R24D36 preprojection receipt and cannot infer a signed channel from
mechanical-energy change or a residual.

## R24D37 closure and R24D38 native-to-portable seam

R24D37's one clean-source qualification passed the complete engine-neutral
ledger population at zero worlds. The v2 ledger, ordered aggregation, evaluator,
explicit migration/refusal operations, and C/Python/Godot bindings are now
qualified for their deterministic semantics. The current recovery observation
and every native route remain unchanged; no adapter yet constructs a v2 ledger.

The retained qualification records both the raw Windows checkout identity and
the canonical Git blob OID for every source. Text checkout filters can make
those byte streams differ without changing source semantics, so the shared
closure verifier now treats the receipt's raw checkout hash as observed evidence
and the Git blob OID as the immutable repository identity. Historical closure
audits retain their stricter raw-blob mode.

R24D38 owns the next integration seam:

`R24D36 native component receipt -> one ordered ledger-v2 increment ->
aggregate ledger v2 -> recovery observation v2`

The mapper must bind each native receipt exactly once, preserve its sequence and
semantic-step identities, retain the source profile and component partition,
and reject missing, duplicate, reordered, residual-derived, or unmeasured
inputs. The enclosing observation needs an additive schema/version boundary so
the historical v1 route remains unchanged. R24D38 is zero-world-only; a later
distinct contract must qualify any physical route smoke.

### R24D38 implemented seam

The prospective implementation keeps this dependency direction:

`complete R24D36 v3 receipts -> pure replay/mapping -> public core V2
aggregation -> flat recovery observation V2`

The adapter mapper imports neither MuJoCo nor NumPy. It independently replays
the retained sparse matrix, then uses the existing pure implicit-step and
preprojection kernels. The core remains the sole ledger aggregation authority.
The mapper does not subclass or modify the historical R24D36 route, and the
current native collector/evaluator remains V1-only.

Observation V2 deliberately preserves the flat observation shape. Its thirteen
non-energy fields are passed through unchanged and content-addressed; only the
energy ledger version changes. R24D38 validates the seam identities needed to
bind those fields to the final native step, but does not requalify the other
observation channels. A later versioned collector/evaluator must own their full
V2 validation and behavior use before any native world is authorized.

### R24D38 closed seam and R24D39 ownership

R24D38's single clean-source qualification passed `9/9` controls at zero
physics and closes this pure dependency edge:

`R24D36 native receipt -> R24D38 replay/mapping -> core ledger V2 -> flat
observation V2`

The mapping and observation are now qualified as content-addressed source
semantics, including both constraint signs and fail-closed passive/external
refusals. They are not yet a production observation path. R24D39 owns the next
architectural edge:

`flat observation V2 -> versioned collector validation -> versioned evaluator
input -> additive MuJoCo route publication`

That successor must remain additive, keep the V1 collector/evaluator and R24D36
route immutable, prove construction/finalization/publication/evaluation at zero
world, and authorize no physics. R24D38 cannot requalify.

### R24D39 implemented consumer seam

R24D39 implements the next dependency edge without changing either predecessor:

`R24D36 receipts -> R24D38 mapper -> flat observation V2 -> source-chain
binding -> V3 collector -> V3 supervisor/controller/evaluator`

The engine-neutral source binding names the MuJoCo adapter, exact R24D36 route,
R24D38 mapping profile, mapping receipt, complete component population,
observation base, ledger, and final observation. The binding includes a digest
of that complete identity payload, allowing the core to reject mutation of
upstream provenance that cannot otherwise be reconstructed from the portable
observation alone. The collector still independently reconstructs and checks
the observation-base, ledger, and observation digests.

Request versioning is deliberately additive. Step/evaluation V1 consume the
original observation V1; their morphology-aware V2 requests also continue to
consume observation V1. Only V3 consumes observation V2. The same separation
applies to collection and control requests, preventing an energy-ledger version
change from silently changing historical request semantics.

The MuJoCo publisher is a pure composition layer. A distinct native consumer
class may later feed it complete measured receipts, but R24D39 never
instantiates that class. The R24D36 class retains its original fail-closed
preprojection behavior. R24D39's `8/8` source controls authorize zero physics;
one clean-pushed qualification must close before a separately declared native
execution smoke.

### R24D39 closed consumer seam and R24D40 ownership

R24D39's sole clean-source qualification passed the complete `8/8` population
and closed this source dependency edge:

`flat observation V2 -> self-content-addressed source binding -> V3 collector
-> V3 supervisor/controller/evaluator -> additive MuJoCo publication receipt`

The closure content-addresses 27 source files, nine retained artifacts, both
publication digests, and the exact toolchain. It also preserves the historical
V1 and morphology-aware observation-V1 request meanings and the R24D36
preprojection refusal. Architecturally, this proves deterministic source
composition and public transport; no model was constructed, no world was
opened, and no solver was stepped.

R24D40 owns the next edge: instantiate the distinct native consumer, retain
complete measured V3 receipts across the smallest adequate step population,
publish observation V2, and evaluate it while checking declared in-run
physical invariants. Its own clean-pushed development contract must state the
exact physical budget before execution. R24D39 cannot requalify and supplies
no native behavior, recovery, handoff, standing, or release authority.

### R24D40 prospective native edge and two-phase invariant replay

R24D40 commissions the next edge without adding a parallel harness:

`R36 measured substeps -> R38 mapping -> R39 V2 publication -> in-run pure
replay -> V3 collector/supervisor/controller -> paired V3 evaluator -> retained
post-run replay`

`MujocoObservationV2RecoveryWorld.step_native` remains the only physical
producer. After the existing native integrator and publisher complete, it runs
`validate_recovery_observation_v2_in_run_invariants_v1` before returning. That
pure function imports no MuJoCo or NumPy, constructs no world, takes no step,
and selects no behavior threshold. It binds native time and counters, the
complete cumulative component population, the native-step digest, observation
identity, source chain, collection request/receipt, arm, and phase by exactly
republishing from retained inputs. The route-smoke validator invokes the same
function again from the append-only trace and requires byte-structural equality
with the in-run receipt.

The shared R18 serial supervisors and bounded smoke publisher own process
locking, clean-pushed qualification binding, reservation, invalid retention,
and publication. R40 adds only a thin worker and thin wrappers. Its one-step
paired horizon is the smallest complete evaluator topology, not a behavioral
trajectory. Until official qualification passes, physics remains blocked.

### R24D40 closed constructor seam and R24D41 composite route

R24D40 qualified the intended invariant and publisher source, then exposed a
missing production conjunction: `bounded_recovery_route_smoke` invoked
`run_paired_development` without `route=`, so its default
`compile_public_profile_model_route` receipt entered
`MujocoObservationV2RecoveryWorld`. That class completes its superclass
constructor and then requires recovery-morphology context before initialization
or stepping. The refusal is retained as an integration invalid; exact runtime
counts were not published and are intentionally absent from the closure.

R24D41 keeps the shared publisher and makes the route dependency explicit:

`compile_recovery_morphology_model_route -> RecoveryMorphologyModelRoute ->
composite recovery-morphology readback/initializer + observation-V2 step ->
bounded paired publisher`

The composite world must inherit the recovery-morphology identity validation
and native prone initializer while retaining the signed-work preprojection and
observation-V2 step/publication behavior. Its route ID must resolve to the
observation-V2 native source route. The zero-world gate owns the exact compiled
schema, morphology digests, MRO, route IDs, explicit route-factory handoff, and
unchanged pure invariant replay. That deterministic proof replaces no physical
evidence; it authorizes only one distinct minimum paired route smoke after a
clean-pushed qualification.

### R24D41 composite route is source-complete

The production dependency is now explicit and single-path:

`bounded publisher -> one LocomotionCore -> recovery-morphology route factory
-> composite world -> paired production evaluator -> append-only publisher`

`MujocoRecoveryMorphologyObservationV2World` uses cooperative multiple
inheritance deliberately. Its first base owns the recovery model route,
native morphology readback, torso-contact reconstruction, and canonical prone
initializer. Its second base owns signed-work implicit stepping, additive
observation-V2 publication, in-run invariant validation, and the V3 consumer
route. An explicit class-level native route ID prevents the first base's older
morphology-route identifier from shadowing the signed-work source identity.

The pure conjunction validator binds the exact recovery receipt schema and
digests, model XML, portable morphology context, MRO, method owners,
initializer, native route, and publication route before construction. It
typed-refuses both the R24D40 base route and the non-composite observation-V2
world. Existing bounded-publisher callers continue passing no route and retain
their historical default behavior. R24D41 changes the explicit handoff and
world composition only; the behavior-bearing scientific inputs remain fixed.

### R24D41 physically closes the composite route

The production composition now has a retained native positive. From frozen
source `de418f0f`, both serial arms constructed the same explicit
`RecoveryMorphologyModelRoute`, entered
`MujocoRecoveryMorphologyObservationV2World`, validated eight native joint
mappings, applied the canonical prone initializer, and advanced five implicit
MuJoCo substeps. Each arm then published one
`sporespore_recovery_observation_v2` through the signed-work source route and
the V2 consumer route. The same public collector, supervisor, controller
planner, paired evaluator, and append-only publisher completed without a
parallel integration path.

The retained result therefore moves the route from source-complete to
physically integrated for this exact finite smoke. It does not move the
behavior state: one outer step leaves both arms in `confirm_prone`. The next
architecture boundary is not another route shim. R24D42 must reuse this single
path for the direct full natural-stop progression, with behavior-bearing inputs
inherited from R24D32 and a new prospective gate before physics.

### R24D42 streams observation V2 without replaying prior history per step

The R24D42 world subclasses the R24D41 composite only to replace its publisher.
It bypasses the old cumulative mapper, takes the unchanged signed-work native
step, validates the current five-substep batch, and advances a compact
`RecoveryObservationV2` streaming state. The state carries exact cumulative
actuator, external, constraint, and passive terms; contiguous semantic and
sequence counters; arm and initial-energy identity; a source-chain digest; and
its own canonical digest. Each next source-chain node commits the prior chain,
current native batch, current increments, arm, step, and sequence range.

The public V3 collector accepts both the immutable legacy mapping profile and
the new streaming profile, but requires the source binding and ledger profile
to match exactly. The shared publication helper validates that same crossing
before collection. Legacy callers and ABI symbols are unchanged. R24D42 uses
the shared runner's optional `release` core profile; qualification records the
profile and library digest and the physical runner rechecks both.

In-run validation replays the current mapping and all source/collector/hash,
native-time, counter, arm, phase, and semantic-step bindings before the
observation reaches the supervisor. Durable receipts contain the full current
streaming publication and native step but no cumulative native array. Post-run
validation walks the retained chain once from genesis, then performs exactly
one legacy full aggregate at the final observation of each arm and compares the
complete numeric observation after excluding only the intentionally different
source-profile and source-digest fields. Thus work and retained publication
size are linear in trace length. A binding failure is invalid; a complete
behavior miss remains a finite negative. The complete development gate passed
`9/9` controls and all 21 forced-failure checks with no physical execution;
the clean-pushed official qualification remains pending.

### R24D42 closed with linear physical publication and a positive handoff

The clean-pushed qualification and sole physical attempt both passed. Across
1,082 outer steps, each step retained one current five-substep publication and
one compact chain state; the retained publications totaled 75,661,558 canonical
bytes and the largest was 71,757 bytes. The paired full-result artifact was
159,886,974 bytes, and the paired process completed in about 108 seconds. All
chain nodes replayed once and both final legacy full aggregates matched.

The candidate reached `stance_handoff` in 307 steps while the 775-step
matched-zero arm remained unactuated and stopped failed. This closes the
currently commissioned recovery controller, not the six-state canonical
machine: the stance controller never owned a step, `stance_dwell` never ran,
and `complete` was not observed. Accordingly the public evaluator's broader
negative verdict and R24D42's narrower positive handoff projection are both
correct. R24D42 closed and cannot rerun. An R24D43 successor must commission
exclusive stance ownership without recovery/stance overlap. SDK1 remains
`11/20`, full program `11/25`.

### R24D43 composes stance ownership without a second engine path

The portable `sporespore_recovery_stance` module owns no engine object and
performs no actuation. It accepts the existing observation-V2 collection and
the core supervisor receipt for only three adjacent edges, replays collection
validation, binds both receipts to one observation digest, and emits the
existing eight-command control receipt. Its controller identity, actuator and
joint order, zero pose, 0.75 rad/s target-speed cap, and actuator impulse caps
are exact. Recovery is explicitly inactive and no engine identity reaches the
composer.

The MuJoCo shared runner retains `continue_through_stance=False` for every
historical caller. R24D43 selects it explicitly, using the same streaming world,
collector, supervisor, evaluator, and R42 one-pass invariant replay. Only the
terminal-stop and mixed recovery/stance request-family checks are campaign
owned. The development gate passed `10/10` controls and 12 forced failures at
zero physical execution; official qualification remains pending and physics is
blocked. No separate integration canary is needed. SDK1 remains `11/20`, full
program `11/25`.

### R24D44 makes the physical launcher selector a zero-world boundary

R24D43's clean-pushed qualification passed, but its first physical-wrapper
invocation exposed a contract vocabulary mismatch before any attempt was
reserved: the shared runner read `ghost_horizon` and `held_out_seal`, whereas
the R43 contract exposed `natural_stop_horizon` and no held-out object. The
strict-mode failure occurred before every physical side effect, so R43 has no
physical result and no execution counts to infer beyond exact zeros established
by source order and the absent physical evidence population.

The shared runner now owns one `Read-ValidatedPhysicalContract` function used
both by normal physical launch and `ContractValidationOnly`. R24D44 invokes
that exact function during its Python zero-world preflight, checks a compact
receipt, and forces both missing-object refusals. Validation-only returns before
source-freeze enforcement, qualification selection, reservation scanning,
operation-lock acquisition, evidence creation, worker launch, or physics. The
R43 controller, route, evaluator, and in-run invariant machinery are reused;
R24D44 adds no policy, physics, or ABI fork. The complete development gate now
passes `11/11` controls, all 14 forced failures, source-contract conformance,
release-core tests, and worktree stability. Official qualification remains
pending. SDK1 remains `11/20`, full program `11/25`.

### R24D44 closed exact nominal MuJoCo positive through exclusive stance ownership

The frozen R24D44 route passed its official zero-world gate and then completed
one paired native execution. The candidate retained recovery ownership through
`raise_body`, transferred once to
`sporespore_exact_s169_stance_handoff_controller_v1`, remained exclusively
stance-owned for 66 observations, satisfied the 60-observation dwell, and
published portable `complete`. Matched zero never actuated and timed out in
`raise_body`. The same public collector, supervisor, controller, evaluator,
streaming invariant validator, and final legacy replay covered all 1,148 outer
steps and 5,740 native substeps without an engine-identity policy branch.

This architecture result proves the exact nominal MuJoCo route, not a general
recovery capability or cross-engine completion. SDK1-M19 therefore remains
open and the ledgers stay `11/20` and `11/25`. R24D45 is deliberately
undeclared while the native Rapier/Parry and Godot/Jolt recovery surfaces are
audited; both physical paths remain closed until a distinct source contract and
complete zero-world qualification exist.

### R24D45 centralizes stance ownership before the Rapier port

R45 selects Rapier/Parry because its exact-s169 world construction, public-cap
motor binding, and native state/contact access are already in one Rust adapter.
The prior Python stance composer is no longer the only portable implementation:
the core now accepts V1, V2, and V3 recovery collections, content-binds the
supervisor handoff, enforces exclusive stance ownership, and emits the same
eight frozen pose commands through three public ABI entrypoints. The Rapier
adapter now exposes morphology-aware V2 collection, recovery, and stance
surfaces as well as the original V1 surface.

The route-owned canonical prone planner now derives all nine native body poses
from the recovery morphology and content-addresses the initializer manifest.
Its pure control bridge derives the same position-error velocity command used
by the existing recovery semantics and maps all eight commands through the
frozen public Rapier cap profile; six ordering, cap, ownership, zero-arm,
engine-branch, and nonfinite mutations fail closed. The physical route now adds
the real nine-body Rapier construction, typed post-step state, contact,
clearance, and energy measurement, native motor application/readback, signed
impulse-work accounting, and a content-addressed in-run invariant chain. Its
qualification-digest-bound entrypoint serializes the candidate and matched-zero
arms and invokes the unchanged portable paired evaluator. The first bounded
ghost stopped after one candidate step on an adapter-versus-validator execution
accounting inversion; the corrected second attempt passed two steps per arm.
Both are retained non-evidence diagnostics. The official pair remains blocked
until a clean-pushed zero-world qualification passes. R17 held-out cells remain
sealed, and the ledgers stay `11/20` and `11/25`.

### R24D45 closes at the native Rapier work-energy observation seam

The exact `3b722610` route passed all 12 zero-world mutation controls, then ran
one serial pair. Candidate and matched-zero execution shared the same native
world builder, typed collector, public-profile mapping, in-run receipt chain,
and unchanged evaluator. Across 771 candidate plus 252 zero-arm steps, every
observation and route binding was accepted. The candidate advanced into
`raise_body`, reached the geometric raised-body boundary for 46 observations,
and ended with valid stance height, uprightness, clearance, speeds, four bearing
feet, contacts, joint limits, actuator budget, and no-cheat state.

The missing conjunction was the shared safety gate. Its energy-residual term
crossed the frozen 0.25 J limit at candidate step 28 and ended at
11.181510863482373 J, while cumulative applied actuator work was reported as
-0.924410707601083 J against a 10.25710015588129 J mechanical-energy increase.
Those values locate an observation seam; they do not by themselves prove which
native impulse, velocity, constraint, contact, or energy term is wrong, nor do
they prove controller failure. R24D45 is an immutable valid negative. The next
architecture boundary must characterize and qualify native Rapier actuator-
work and energy-exchange semantics before commissioning another recovery
trajectory. No engine-specific policy branch or behavior threshold changes.

### The R24D45 diagnosis moves work measurement into the Rapier solver seam

Frozen Rapier `0.34.0` source resolves the ambiguity without opening another
world. The active adapter's outer step is internally 16 small steps. Rapier
rebuilds each motor constraint with zero accumulated impulse, interleaves joint
and contact solves, and writes only the final small-step constraint impulse to
the joint after the loop. Reading `JointMotor.impulse` once at the adapter
boundary therefore cannot produce complete outer-step motor work.

The generalized-coordinate sign also belongs at the solver seam. R45 observes
child-minus-parent angular rate; Rapier applies positive constraint impulse
plus to parent and minus to child. Its motor contribution in that coordinate is
negative impulse times the rate at each actual application. The outer endpoint
average cannot recover those interleaved application-time rates, and the
retained trace cannot be repaired exactly by a factor, sign flip, or residual
closure.

R24D46 therefore uses the same architectural pattern as the qualified Jolt
telemetry profile: a minimal, version-pinned native patch accumulates every
motor delta-impulse contribution at the point of application and exposes total,
supplied, absorbed, and net work with source and binary provenance. Portable
ledger V2 accepts only independently observed channels; anything unavailable
is a typed refusal, never a value derived from the residual. This diagnosis is
zero-world and does not reinterpret R45 or authorize physics.

### R24D46 implements a narrow, opt-in Rapier telemetry profile

The native patch is intentionally below the adapter boundary. Each scalar
rigid impulse-joint motor solve captures the body2-minus-body1 generalized
velocity immediately before and after Rapier applies its native constraint
delta impulse. Because that impulse acts plus on body1 and minus on body2, the
published generalized motor impulse is its negative. Trapezoidal impulse work
is accumulated directly into supplied, absorbed, and net partitions; the
outer adapter never reconstructs missing applications from endpoints.

Telemetry lives on `JointMotor` only after final outer-step writeback and
includes a monotonic sequence, small-step count, application count, signed
impulse, and absolute impulse. The adapter rejects stale publications and any
counter or arithmetic mismatch. The stock workspace dependency remains
unchanged; an isolated build must explicitly enable the adapter and patched
Rapier features, preventing a machine-local dependency path from rewriting
the canonical lockfile.

This profile deliberately refuses Rapier SIMD and generic/multibody solver
paths. It also refuses to call unmeasured contact, friction, nonmotor
constraint, external-force, or numerical energy exchange a measured
dissipation channel. R24D46 source is implemented but not yet clean-pushed
qualified, so the architectural physical boundary remains closed.

### R24D46 qualifies the seam, while the energy-partition boundary stays closed

The sole clean-pushed qualification now proves that the version-pinned patch
can be freshly reproduced and that the adapter accepts exactly one complete,
fresh 128-application publication while rejecting every declared structural
and arithmetic mutation. This promotes the active scalar motor-work telemetry
profile from implemented source to qualified observation infrastructure. It
does not promote any physical behavior or change the stock workspace's Rapier
dependency.

The next architecture work is deliberately one layer above the qualified motor
seam and below another recovery controller run. R24D47 must define a complete
Rapier energy-accounting capability boundary for contact/friction,
nonmotor-constraint, external-force, and integration/numerical exchange. A
channel may be independently observed or explicitly unsupported, but it cannot
be synthesized from the balance residual. Until that zero-world boundary is
qualified, Rapier recovery physics remains unauthorized.

### R24D47 brackets native solver phases without changing the solver

The successor patch keeps Rapier's sequential scalar order intact and measures
the aggregate supported solver-body kinetic energy immediately before and after
each velocity-mutating constraint phase. The five measurement families are
contact warmstart, biased joint solve, biased contact solve, joint no-bias
stabilization, and contact no-bias stabilization. Per-island exchange is
accumulated into independent total, joint, contact/friction, and warmstart
fields, then published once per outer pipeline step with a monotonic sequence.
For the active `16`-small-step configuration, exact counts are `128` joint,
`128` contact, and `16` warmstart phases.

The adapter composes that phase observer with R24D46 rather than replacing it:

`nonmotor joint/stabilization exchange = joint phase exchange - motor net work`

`signed constraint exchange = nonmotor joint/stabilization exchange + contact/friction exchange`

The independently accumulated native total must also equal joint plus contact
within an error bound derived from the exact f32 addition count. This redundant
identity detects a missing or double-counted instrumentation phase. Motor
supplied and absorbed magnitudes remain diagnostic partitions; signed motor net
work is the ledger actuator channel.

### Zero work and dissipation are capability claims, not inferred residuals

The patched pipeline observes engine-side body type, locked axes, damping,
gravity scale, user force/torque, gyroscopic flags, multibody participation,
generic degrees of freedom, active-body count, islands, and CCD substeps. The
public production collector derives fixed/dynamic/kinematic body counts,
impulse-joint population, sleeping capability, timestep, length unit,
warmstart, and separate biased/stabilization-iteration readbacks from the same
actual `PhysicsWorld`. Only the exact declared route may set explicit external
work and passive dissipation to zero; any capability drift is a typed refusal.
SIMD and parallel features fail compilation. Because the collector constructs
the internal capability receipt itself, an adapter caller cannot substitute
declared constants for native readback. The only host inputs are external
intervention and impulse-application counts that Rapier does not retain
natively, plus the ordered handles that identify the eight actuators.

Gravity remains represented by mechanical potential energy and is not counted
again as external work. Contact/friction effects are already in signed
constraint exchange, while motor damping and absorption are in exact actuator
work. Everything left by integration, projection, mass updates, finite
precision, or other numerical closure stays in the independent V2 energy-
balance residual under its unchanged threshold. The observer never feeds that
residual back as a work or dissipation value.

R24D47 reuses the isolated patched-dependency qualification architecture. The
shared runner now resolves contract-declared JSON pointers for each gate's
preflight semantics while retaining the closed R24D46 compatibility path. This
keeps archive verification, clean patch application, source binding, compile,
operation lock, and append-only receipt mechanics common. The source boundary
is implemented; official zero-world qualification and every physical claim are
still blocked.

### R24D47 qualification makes the collector eligible, not observed

The sole official R24D47 qualification from source `2922a65f` passed the exact
archive/patch binding, stock and patched builds, both compile-time route
refusals, contract-declared receipt checks, and all thirteen adapter mutations.
Its complete evidence tree is compactly content-addressed. Because the run
constructed zero worlds, qualification establishes that the instrumentation
and capability logic are eligible for a future production route; it does not
establish that a live trajectory satisfies those capabilities or closes its
energy balance.

Accordingly the architecture boundary moves from “missing complete accounting
instrumentation” to “distinct physical consumer not yet declared.” R24D48 must
integrate `collect_r24d47_rapier_world_energy_exchange_v1`, capture the native
pre/post-step capability state and two host activity counters, retain the V2
residual independently, and fail before interpretation on any route drift. No
R24D48 question or physical budget exists yet, so the current maximum remains
zero solver steps.

### R24D48 streams the qualified Rapier partition into recovery V2

R24D48 adds the missing production consumer without changing the recovery
policy. After each unchanged R45 native outer step, the adapter obtains the
actual-world R24D47 capability state and complete energy-exchange sample. It
maps motor net work, signed external work, signed constraint exchange, and
passive dissipation directly into `RecoveryEnergyWorkIncrementV2`, preserving
native sequence order. The existing V2 aggregator produces the cumulative
ledger; the adapter replaces only the V1 observation's energy field and binds
that V2 observation to the exact Rapier adapter, R24D48 route, mapping profile,
and content digests.

The public V3 collector accepts that binding only for the exact qualified
Rapier identity. The existing V3 supervisor and controller then consume the
V2 observation, and the existing stance planner converts the decision into the
next native command. The paired evaluator remains unchanged. Each retained
step therefore carries the base physical invariant receipt, native R47 sample,
component and aggregation receipts, source binding and portable collector
receipt, supervisor receipt, and planned control. Pre- and post-step actual-
world capability observations must match exactly; any drift refuses the trace
before behavioral interpretation.

The architecture deliberately separates integration qualification from
behavior. A clean-pushed official zero-world closure is required first. The
only initial physical stage is then a two-step-per-arm ghost that proves the
candidate and matched-zero pipelines instantiate and execute; it neither
requires nor predicts standing. A full paired development attempt can run only
from the same source, toolchain, environment, and qualification after that
ghost passes. The shared patched-Rapier qualifier inherits the exact R47
content-addressed dependency declaration, so successor contracts reuse common
archive and patch mechanics instead of copying bespoke qualification code.
Both later physical stages reuse the qualification harness's exact retained
`Cargo.lock` under locked offline resolution, binding the transitive Rust graph
alongside the patched Rapier files and toolchain identity.
No physical execution, behavior, equivalence, population, or release claim has
yet been made.

### R24D48 qualification freezes the physical dependency chain

The official R24D48 zero-world closure qualifies the exact adapter/route/
mapping tuple and the public V3 consumption path at source `2633da02`. The
retained qualification binds not only the crates.io Rapier archive and every
patched output, but also the generated standalone-harness `Cargo.lock`. The
physical launcher reads that lock from the content-bound qualification receipt,
copies it without alteration, and runs Cargo offline with `--locked`. Its
environment identity includes the lock digest, so a ghost cannot authorize a
development run with a different transitive dependency graph.

Qualification and integration remain separate state transitions. The closure
contains zero physical observations and grants only R24D48-A: two native outer
steps per paired arm. Each completed step must preserve the R45 physical
invariant chain, stable pre/post R47 capability state, ordered energy sequence,
direct V2 aggregation, observation and source digests, portable collection,
supervisor transition, and next-command plan. Behavior success is not a ghost
gate. A valid ghost may authorize the unchanged full development stage; it does
not itself establish recovery, prone-to-standing, or release authority.

### Cross-language runtime identity uses one producer-owned projection

R24D48-A exposed an architectural ambiguity without opening physics. The
PowerShell launcher hashed the Python-canonical retained preflight, while the
Rust worker hashed its independently serialized `serde_json::Value`; both
bound the intended object but produced different bytes. The worker rejected
the mismatch before compiling the recovery boundary, leaving model, world,
solver-step, and outer-step counts at zero. That exact Stage A attempt is
retained invalid and consumed; it is not a recovery negative.

R24D49 must remove cross-language reserialization from the trusted path. Rust
owns a compact, non-self-referential runtime-binding projection and emits its
SHA-256 as an explicit zero-world preflight field. Qualification binds the
field and its projection; the closure copies it; PowerShell transports the
exact string without recomputing the full object; and the Rust physical worker
recomputes only the declared projection. Any field, projection, source,
toolchain, dependency, or environment mismatch refuses before model
construction. This successor requires a fresh complete zero-world
qualification and preserves every R24D48 controller, evaluator, threshold,
morphology, result, and interpretation.

### R24D49 reuses behavior and parameterizes launch authority

The implementation separates runtime identity from physical mechanics. The
R48 public entry points retain their historical full-preflight validators; the
unchanged post-validation ghost and development bodies are extracted as
crate-private functions. R49 first validates its producer-owned projection
digest, then invokes those exact bodies and relabels only the top-level gate and
schema. Candidate and matched-zero arm data retain the R48 route lineage.

The physical PowerShell launcher now reads gate, closure status, binding field,
Rust entry points, markers, artifact prefixes, and dependency contract from the
declared contract. The R49 launcher is a thin contract-path wrapper. This avoids
copying the physical harness and makes later invalidation precise: a changed
contract/source/dependency/toolchain/environment or runtime projection blocks
before world construction, while the historical R48 launcher remains
configurable through its defaults. R49 still needs a fresh content-addressed
zero-world qualification before any physical stage is authorized.

### The qualified R24D49 binding is a physical-stage dependency

The official preflight emits
`sha256:946d9f1dda22658c989b59daf7f75b32d82586009288baca0207b8ca8c01ea28`
over the declared 12-field projection. The qualification closure copies that
field rather than hashing the full receipt. The shared physical launcher reads
the field through the contract's JSON pointer, writes the same named field into
attempt and receipt artifacts, and passes it unchanged to the R49 Rust entry
point. Rust recomputes the projection before it can invoke the inherited R48
post-validation body.

The physical dependency tuple also includes the exact qualification source,
patched Rapier tree, retained Cargo lock, toolchain, environment, and clean
local/upstream/live identity. Any mismatch fails before world construction.
Only R24D49-A's two steps per arm are currently authorized; a passing ghost is
required before the unchanged finite recovery body can run.

### A passing integration ghost advances authority without becoming behavior evidence

R24D49-A exercised the complete production route in two genuine Rapier worlds
and four native steps. Candidate and matched-zero initial-state digests matched
exactly. Each step crossed the retained R45 invariant, R47 source-energy
sample, R48 component mapping, cumulative V2 ledger, observation source
binding, V3 native collector, portable supervisor, and deterministic control
planner. This is the architectural condition for opening the inherited finite
development body. It does not require a full-seed rehearsal and it does not
predict the physical decision.

Closure verification now reuses two common mechanics: one content-addressed
staged-runner verifier for attempt/result/receipt, environment, Cargo lock,
source identity, lock release, and complete evidence population; and one
Rapier recovery-V2 arm verifier for every in-run link. Campaign audits retain
only their question-specific projection and interpretation. Historical audits
are not re-executed on this physical critical path, and no new physical canary
was added. The same helpers are intended to close R24D49-B regardless of
whether its finite behavior result is positive, negative, incomplete, or
invalid.

R24D49-A is consumed. Current authority is R24D49-B: exactly one candidate and
one matched-zero development attempt, at most `1200` outer steps per arm, from
a clean-pushed live-equal source with the same qualified runtime binding,
patched dependency, Cargo lock, toolchain, and environment. Held-out data and
all acceptance or release authority remain sealed.

### Physical identity, not repository commit identity, crosses a closure boundary

A physical result cannot share its literal commit with the repository commit
that subsequently publishes its closure. Stage B therefore accepts an earlier
ghost only through an explicit authority contract. The contract binds the
ghost closure, receipt, result, runtime binding, dependency lock, toolchain,
environment, and the complete qualified non-launcher path population. Git
proves those paths identical to both qualification and ghost sources.

Launcher changes are isolated as authority-only drift and content-addressed by
the R49 wrapper. Their validation occurs before the operation lock and before
attempt/evidence creation. Wrong closure digest, receipt digest, runtime
binding, or source population is rejected by the zero-world source gate. This
keeps closure publication possible without weakening physical identity or
requiring a redundant physical ghost.

### A terminal recovery trace has no fictitious next command

The reusable Rapier recovery-V2 verifier treats all observation, invariant,
energy, mapping, aggregation, binding, collection, and portable-step arrays as
one record per executed outer step. A terminal `complete`, `failed`, or
`refused` observation has no next step to control, so its planned-control array
is exactly one element shorter. This is a protocol property, not missing
evidence: each nonterminal observation still binds the command that can be
applied on the following step, and all active applications remain paired with
their originating plan. Campaign audits add only their decision-specific
phase, gate, and claim checks on top of this common chain.

### R24D49-B isolates the remaining observed gate at stance-dwell energy

The finite candidate traversed `confirm_prone`, `establish_distal_support`,
`raise_body`, and `stance_handoff`, then entered `stance_dwell`. Its final pose
remained mechanically strong: four bearing feet, raised body, high uprightness,
low linear/angular velocity, positive non-foot clearance, respected joint and
actuator limits, no forbidden contact impulse, and no hidden intervention. All
non-energy stance gates held for every dwell observation. The stable
conjunction lasted `19` frames, then the independently measured energy balance
residual crossed the frozen `0.25 J` ceiling and continued upward until the
`240`-step dwell timeout.

Architecture must not turn that decision fact into an unsupported diagnosis.
The trace proves where the evaluator rejected the otherwise valid stance; it
does not yet prove whether the cause lies in physical settling, controller
work, adapter measurement, aggregation, or another factor. R24D50 therefore
starts with zero-world decomposition of the retained measurements. It may
declare a physical successor only after a correction or unchanged-path
hypothesis is explicit, independently controlled, and completely qualified.

### R24D50 separates constraint exchange from discrete gravity staging

The retained R49 trace exposes an architectural boundary that the qualified
R47 observer intentionally left inside its independent integration/numerical
residual. Rapier computes each rigid body's force-derived velocity increment,
adds it before the warmstart and joint/contact solve measurements, then
integrates positions after those constraints. In a supported near-stationary
zero-control state, gravity injects a small kinetic term and constraints remove
it before the outer endpoint moves materially. The current observer records
the removal but has no independent sample at the preceding force-integration
boundary.

R24D50 quantifies this without changing runtime code: terminal zero-control
constraint removal is `99.953%` of the source-derived zero-velocity gravity
kick, and the final 64-step window remains within roughly `0.064%` of that
projection while COM and endpoint energy are nearly stationary. This is a
measurement-topology diagnosis, not a corrected balance equation. Simply
adding gravity-kick energy to the ledger would be wrong in free fall because
physical gravity is already paired with gravitational potential energy.

The successor observer must therefore treat force integration and position
integration as explicit native staging boundaries. It must independently
measure enough information to demonstrate both supported cancellation and
free-flight kinetic/potential pairing, including upward/downward motion and a
zero-gravity control. No term may be calculated from the balance residual it
is intended to test. The reusable retained-trace diagnosis remains descriptive;
only a distinct, mutation-controlled R24D51 zero-world design may define the
prospective runtime measurement. R49 behavior and all release claims remain
immutable while that design is open.

### R24D51 separates measurement from the balance it will test

The R51 observer is a pure ordered aggregation boundary. Each of sixteen
small-step records carries aggregate supported-body kinetic energy before and
after force integration and aggregate raw gravitational potential before and
after position integration. A separate outer-step record carries Rapier's
half-step potential projection before and after the step. The observer emits
the three signed differences and their sum; it never receives mechanical-
energy change, constraint exchange, energy residual, threshold, controller
state, or behavior classification.

This decomposition has two deliberately different closures. At supported
rest, the positive force-boundary kinetic term is cancelled by the existing
independent negative constraint exchange while position and endpoint terms are
zero. In free flight, no constraint term exists: force kinetic change, raw-
potential position change, and the endpoint projection jointly equal Rapier's
discrete endpoint-energy change. Upward/downward and zero-gravity controls
prove the sign and absence-of-double-counting cases. Contiguous zero-based
indices and source flags make omitted, duplicated, stale, or reordered stage
populations invalid rather than silently incomplete.

R51 is intentionally not a native patch or portable-ledger revision. The next
architecture layer must instrument these exact boundaries in a version-pinned
Rapier successor and add a versioned engine-neutral signed discrete-staging
channel; mapping the term into physical external work or passive dissipation
would be semantically wrong. Only after native and portable source identities
are qualified can a small integration smoke ask whether the complete path
executes. The R49 trace and V2 ledger remain unchanged meanwhile.

### R24D51 qualification preserves the design/integration split

The official R51 qualification proves the pure observer API and its complete
control population from exact source `f5ca0e16`; it does not make the API's
`source_measurement` assertion true for a native world. That assertion remains
the responsibility of a version-pinned Rapier successor which must place each
sample at the declared solver boundaries and publish the complete ordered
population. A separate engine-neutral ledger version must then retain the
signed staging channel rather than mislabel it as external work or passive
dissipation.

Consequently, R51 closure advances architecture authority but not physical
authority. R52 owns both native telemetry placement and portable ledger
integration under zero-world controls. A later short integration smoke may
test transport only after R52 qualifies; behavior evidence still requires its
own finite prospective question.

### R24D52 makes staging a first-class native and portable channel

The R52 native layer is an ordered delta over the complete R47 Rapier telemetry
patch. It threads the explicit world-gravity vector into the scalar island
solver, samples aggregate kinetic energy immediately around force-derived
velocity increments, samples raw gravitational potential immediately around
position integration, and samples Rapier's half-step projection before and
after the outer pipeline step. A fixed sixteen-entry population retains native
sequence and source identity; overflow, multiple island/CCD routes, or endpoint
body-population drift are visible and rejected by the adapter.

The portable layer is a new additive V3 ledger, not a reinterpretation of V2.
Its balance equation subtracts signed discrete-staging exchange exactly once
in a channel separate from actuator work, external work, constraint exchange,
and nonnegative passive dissipation. Ordered source values are content-
addressed, thresholds and physical decisions are outside the ledger, and no
implicit V2-to-V3 migration exists. The R52 adapter preserves the R47 external
and passive mappings, assigns only the independently observed R51 sum to the
new channel, and refuses sequence, topology, source, population, and finiteness
violations. This architecture is implemented prospectively; zero-world
qualification must close before any native transport smoke, and behavior still
requires a later finite physical declaration.

### R24D52 qualification closes the source layer, not runtime observation

The official R52 result binds the exact frozen source, ordered base/delta patch
sequence, and eight final Rapier outputs. Its zero-world checks qualify the
native sampling sites, population metadata and refusal paths, V3 equation and
source digest, and the adapter's one-to-one staging mapping. The forced omission
control proves that the portable evaluator consumes the separate staging term
without deriving it from the balance residual.

This creates a precise architectural seam between source qualification and
runtime transport. R52 executed no physics, so it cannot prove the pipeline
publishes all sixteen samples and both endpoints in a native recovery world.
R53 must own that observation as a distinct minimal transport smoke with its
own clean freeze, zero-world preflight, finite physical budget, and retained
receipt. Only after that transport seam closes may a later campaign recompute
an energy trace or ask a behavior question; no R49 interpretation changes now.

### R24D53 observes transport through an additive post-step seam

The recovery arm loop now accepts one internal post-step observer. Historical
R48/R49 paths pass an exact no-op, preserving their result shape. R53 supplies
an observer that reads the already-completed Rapier pipeline's R52 telemetry,
combines it with the same-step R47 energy sample, and constructs one V3 increment
before the existing R45 native observation and invariant validation continue.
The observer cannot alter the world, controller, phase machine, or evaluator.

R53's result owns a single `transport_arm`, the two raw native telemetry
populations, two independently computed staging exchanges, and one cumulative
portable V3 aggregation receipt. The shared physical launcher selects this
shape from the contract while preserving its old paired shape by default. This
keeps the runtime question to one world and two steps, with the same clean-
pushed source, operation lock, exact qualification Cargo lock, patched-file
bindings, durable evidence, and drift checks used by the established route.

### R24D53 qualification-to-physical authority seam

The R53 closure binds the clean source commit, exact patched dependency tree,
isolated qualification lockfile, producer runtime-binding digest, complete
source manifest, and full retained evidence tree. The shared physical launcher
must consume that exact closure and Cargo lock and must refuse if the source,
remote, worktree, dependency outputs, runtime binding, or attempt population
drifts.

The resulting capability is intentionally smaller than the historical paired
runner: a single `transport_arm`, one world, and two steps. The live gate exposes
only that budget. Development mode is disabled, so the launcher cannot silently
expand it into a long controller run; the behavior evaluator remains absent and
physical acceptance authority remains false.

The R53 launch exposed one authority-label mismatch before the lock was
acquired: the contract says `physical_development`, while the lock originally
accepted only `conformance` and `physical`. The lock role is receipt metadata;
all roles share the same global mutex. The bounded repair adds the descriptive
label to validation and regression coverage without changing the mutex,
qualified adapter paths, runtime binding, world construction, or physical
budget.

### R24D53 closes the transport seam without coupling it to behavior

The live two-step result validates the intended architecture: each completed
Rapier step publishes one immutable native telemetry population to the additive
post-step observer, which maps it exactly once into the separate portable V3
staging channel before the historical observation/invariant path continues.
The retained sequences are `1, 2`; all `32` small-step values and four endpoints
are source measured; both R45 in-run invariant receipts pass; and the cumulative
V3 ledger is independently reproducible from the retained native values. The
unthresholded signed residual is `-1.7859705581102503e-7 J` after accounting for
`0.007154857967179851 J` of cumulative discrete staging exchange.

Transport success does not flow into behavior authority. The observer remains
read-only, the two-step route executed no active control and no recovery
evaluator, and its final `confirm_prone` phase is not a standing result. R53's
physical identity is consumed and the live physical maxima return to zero. A
new R54 contract must independently bind its behavior evaluator, finite horizon,
threshold provenance, cohort, V3 accounting requirements, and complete
zero-world controls before the architecture permits another native world.

### R24D54 consumes the staging channel through an additive trace layer

`RecoveryObservationV3` preserves the flat non-energy observation surface and
replaces only the energy ledger with the qualified V3 partition. Additive step
request V4 and trace/evaluation request V4 reuse the generic recovery phase
machine; V1 and V2 remain strict, separately deserializable contracts. Focused
mutation tests prove that the discrete-staging term changes safety
classification exactly once and that neither older observation schema can
silently accept the V3 payload.

The native route remains the R49 implementation. A post-step observer collects
one R52 staging exchange alongside the existing R47 energy sample. After the
finite arm completes, R54 constructs each cumulative V3 ledger from the exact
ordered prefix and replays it. Before a V3 terminal transition, its prior and
next phase must equal the live V2 supervisor phases; otherwise the result is
invalid. This prefix invariant establishes that all accepted physical commands
were selected from identical controller state without duplicating the world
loop or modifying historical R49 semantics.

Qualification mechanics are now reusable: the shared runner can inherit a
content-addressed patched-Rapier profile, execute named zero-world tests, pass a
contract to one generic source audit, and accept an earlier live integration
closure instead of demanding a fresh ghost. The R54 development preflight
exercised those paths successfully with zero physics. Official authority is
still closed until the source freeze and clean-pushed qualification.

### R24D54 qualification binds the additive V3 route without another harness

The clean-pushed `0249b288` source population passed one official qualification
and is now frozen by a compact content-addressed closure. The shared closure
verifier owns retained-tree, source-manifest, dependency, toolchain, lock,
zero-count, and live-authority mechanics; the R54 audit adds only the semantic
V3 staging-consumption, phase-prefix, finite-budget, and mutation assertions.
This keeps successor conformance proportional instead of copying another large
bespoke verifier.

Physical launch consumes the exact qualification receipt and Cargo lock, checks
the unchanged qualified-code path population, rebinds the R53 positive transport
closure, and permits one candidate/control pair with a hard `2400`-step total.
The qualification itself authorizes no physical observation or standing claim.
No new ghost is interposed because the live native transport route has already
been exercised and every R54-only trace/evaluator branch was covered by focused
zero-world controls.

### Integration authority and ghost authority are disjoint launcher routes

The shared physical runner now maintains two explicit development-authority
shapes. Historical stages bind a ghost receipt and validate its result. R54
binds a prior live integration closure and therefore has no ghost object. The
launcher validates a ghost result only when that object exists; otherwise it
requires the content-addressed integration authority before lock acquisition.

An authority-only repair closure may exclude exactly the shared launcher from
an older qualification source population. It must prove that this is the sole
changed qualified path, bind the repaired source, reject routing mutations, and
retain a complete cold-equivalence qualification of the full zero-world route.
The physical launcher then checks both the unchanged 22-path population and the
one repaired-path identity before any evidence directory or world can open.

### Cold equivalence composes one repaired launcher with 22 frozen paths

The R24D54-L1 closure treats the original qualification and the repaired
launcher as two explicit authority components. Git proves that the qualified
23-path population differs only at the shared physical runner. The original
closure continues to own the other 22 paths and official receipt; the repair
closure owns the new runner blob, its routing mutations, and the complete cold
development evidence tree.

Development mode has 13 shared checks and no live-remote boolean, while official
mode has those 13 plus `live_remote_unchanged`. The closure compares the shared
checks and entire producer preflight byte-for-byte, then binds an independent
clean/pushed/live equality observation as the fourteenth composite condition.
This precise invalidation permits the original finite physical question without
claiming that a non-identical full receipt was identical or adding another
physical integration run.

### Production-route authority probes stop before the physical harness

Static source mutations prove structure, but they do not execute PowerShell's
runtime collection-shape behavior. R24D54-L2 therefore adds a narrow opt-in
mode to the production runner rather than another campaign-specific harness.
It traverses all clean-source, qualification, repaired-path, patched dependency,
and integration-authority checks used by the physical route. It then takes the
same global operation mutex in the `conformance` role, retains a small receipt,
releases the lock, and exits before the physical-role lock and harness.

The receipt asserts zero attempt records, models, worlds, and solver steps and
cannot authorize physics by itself. The probe is limited to one retained
execution per exact source so it cannot become seed rehearsal or behavior
selection. Its closure composes with L1's complete cold-equivalence evidence:
L1 continues to own the 22 unchanged qualified paths and full rebuild, while L2
owns only the corrected launcher blob and its observed production-route receipt.

### L2 composes a tiny runtime receipt with the existing cold baseline

The passing R24D54-L2 probe demonstrates the intended split in practice. L1
continues to own the costly complete rebuild, exact toolchain/dependency/patch
identity, producer preflight, and 22 unchanged qualified paths. L2 owns one
changed launcher blob plus a `2243`-byte receipt from the actual route. The
receipt proves clean/pushed/live-equal authority routing and lock serialization,
then terminates with zero physical counts.

This composition avoids both a second full qualification and a behavioral
ghost. The closure may authorize the already frozen physical question because
its complete invalidated surface has been exercised; it cannot authorize any
new physical question, policy choice, threshold, or claim.

### Captured traces and evaluator traces have distinct populations

R24D54 exposed an architectural distinction that must now be explicit. A native
supervisor may retain observations after the additive V3 phase machine becomes
terminal because an older supervisor still owns physical stopping. That full
capture is provenance. The V3 evaluator population, however, ends exactly at
the first V3 terminal transition. Passing the full capture to an evaluator that
correctly stops at terminal creates an accepted-count mismatch.

Future routes must retain both identities: a complete captured trace and a
content-addressed terminal-prefix evaluator trace. A pure projection must prove
that the prefix count is nonzero, does not exceed the capture, ends on the sole
terminal transition, preserves every earlier observation byte-for-byte, and
contains no later observation. The physical evaluator receives only that
prefix; the full capture remains immutable evidence. R24D54 itself is not
rewritten and its invalid result cannot be promoted by applying the repair
retrospectively.

### Native initializer identity is an engine representation contract

R24D57 demonstrated why an engine-neutral authored pose and a native engine
readback cannot share an unexplained decimal-equality tolerance. The exact
Godot route created its native scene nodes, then refused the first hip while
all bodies were still frozen and before any solver step. That outcome is an
integration failure: it cannot be interpreted as physics, recovery behavior,
or a reason to fit a behavior threshold after observation.

A successor must keep the authored engine-neutral initializer immutable while
declaring the native projection used for comparison. Its zero-world controls
must exercise positive, adjacent-value, sign, order, and nonfinite cases and
must record expected value, native readback, absolute error, representation
rule, and adequacy argument. Attempted node/model construction, completed world
construction, body unfreeze, solver steps, observation collection, and command
application are separate counters. Supervisor stdout and semantic exit status
are likewise one typed result, not incidental PowerShell pipeline values. The
compact closure should reuse shared content-addressed evidence mechanics; this
representation defect does not justify another bespoke physical canary.

### Published physical authority is a versioned projection plus runtime control

A physical supervisor must not infer authority by reaching into a campaign's
arbitrary closure layout. Each successor exports one versioned projection with
the exact gate, source freeze, seed identity, held-out status, model/world/step
budgets, timing, rerun rule, success requirement, and claim limits. A shared
parser owns these semantics and rejects missing, malformed, legacy, or mutated
fields. Campaign wrappers bind identity and paths; they do not reimplement the
projection.

Publication itself changes repository identity, so a pre-publication source
audit cannot prove the exact committed closure-to-runner path. Before physical
mode can consume an identity, the production supervisor therefore runs a
separate zero-world authorization control from clean, pushed, live-equal source
under the common conformance lock. Its durable receipt binds the exact closure
path and raw digest, normalized projection, source/tool path population,
preflight, and released lock with zero physical counts. Physical mode requires
exactly one matching receipt before its lock and rechecks it after the lock.
This control verifies executable routing; it is neither a behavioral canary nor
a prediction that the subsequent physics result will pass.

### Native telemetry invariants use the binding's exact interface

The instrumented Godot/Jolt motor-telemetry binding publishes its version
identity under the field `schema`. Native recovery consumers must validate that
exact interface; `schema_version` is not an alias and fails closed. The complete
dictionary invariant also includes active-step capture, current-step freshness,
coherent capture/read sequences, finite impulse and work fields, nonnegative
supplied/absorbed work, the net-work identity, the qualified outer-step impulse
cap, and exact zero telemetry for an explicit zero command.

One pure validator owns those rules and is called by the physical sampler.
Zero-world conformance invokes that same function with binding-shaped positive
and mutated dictionaries. This makes the software check directly relevant to
the in-run invariant without constructing a model or trying to predict whether
the later physical trajectory succeeds. Engine telemetry acquisition remains
adapter-specific; controller policy, thresholds, and recovery interpretation
remain portable and unchanged.

### Native contact identity is a lossless adapter projection

Engine contact keys may contain delimiters that are meaningful to the native
engine but forbidden by the engine-neutral protocol's conservative identity
grammar. The adapter must not pass such strings through verbatim, silently
drop punctuation, or replace them with an opaque digest. It projects the exact
native UTF-8 bytes into a collision-free portable namespace and retains the
raw-to-portable mapping beside the source receipt.

The Godot implementation uses `godot_contact_` followed by lowercase
hexadecimal of the complete UTF-8 byte sequence. Distinct byte sequences are
therefore distinct portable identities without depending on a probabilistic
hash, and the raw value is recoverable from the payload. Deduplication occurs
on raw native identity before encoding, preserves first-observation order, and
does not change ordered contact samples or per-point impulse aggregation. A
portable owner collision is still checked and refused so a later encoder
change cannot silently weaken the contract.

Zero-world conformance must drive both the raw and projected values through the
actual portable collector, retain the exact observed production refusal, test
collision-tricky and invalid inputs, and prove zero physical counts. Physical
workers consume the same pure projection for foot and nonfoot buckets. This is
an adapter representation contract; it changes no controller, threshold,
evaluator, native physics, or behavior interpretation.

### In-run invariant predicates are one cross-layer contract

An adapter-side physical invariant and the portable-core invariant it feeds
must not be merely similar. They must have identical acceptance semantics for
the same measured value, published limit, inclusivity, representation, and
nonfinite behavior. An adapter check that accepts `cap + tolerance` while the
core accepts only `cap` creates a value interval that is locally valid and
portably invalid. Reaching that interval is an integration failure even when
the world and solver are genuine.

The adapter must forward the raw measurement unchanged. It may not make the
layers agree by clipping the observation, relabeling the cap, or adding an
unpublished post-observation margin. A rejected receipt must retain the exact
measurement, exact cap, exact difference, actuator identity, and both validator
decisions. If a host representation guard is required to keep future native
measurements within a strict portable budget, that guard is a separately
declared prospective design with its own source identity and boundary controls;
it is not a retrospective repair of consumed evidence.

Zero-world conformance for a shared numeric predicate should cover exact
equality, the adjacent accepted and rejected representations declared by the
contract, nonfinite inputs, order and identity mutations, and deliberate
cross-layer decision disagreement. This is focused execution of the actual
in-run code, not a physical success rehearsal. Once a real route has already
reached and localized the seam, another seeded ghost adds no distinct software
evidence unless the successor changes the route that leads to it.

### Strict published caps require a host-representation floor

The exact S169 Godot/Jolt recovery adapter stores a hinge motor's maximum
impulse in a binary32 host field while the portable profile and core retain the
published binary64 value. R24D68 owns this representation seam with
`godot_jolt_binary32_floor_strict_published_impulse_cap_v1`: configure the
greatest binary32 value no greater than the immutable published cap, then
require exact host readback before command application. A nearest-value cast is
insufficient because both rear-hip caps round upward by one binary32 unit.

This floor is not a policy margin. The portable cap, observation, controller,
and evaluator remain unchanged. The model and every command receipt retain the
published cap, nearest binary32 value, configured binary32 value and bits,
their deltas, whether the floor was needed, and exact readback. A missing,
misordered, nonfinite, above-cap, or non-round-tripping binding fails closed.

`native_motor_telemetry_contract_v2` is the single production adapter owner of
the strict in-run decision. It preserves V1's unrelated telemetry invariants,
but budget acceptance is exactly `abs(raw signed impulse) <= published cap`
with zero tolerance. It retains enough data to reproduce either decision and
then projects the same raw value into the core. Deliberate decision disagreement
is a zero-world negative control. Complete and aborted behavior receipts retain
the host projection map so an in-run refusal remains diagnosable without
reconstructing a lost floating-point value.

### Physical evaluator consumers validate verdict semantics, not pass-only flags

The portable recovery evaluator owns the physical verdict. Its
`all_negative_control_requirements_enforced` field is an outcome conjunction:
in physical mode it is true only when the candidate completes and matched zero
fails. It is therefore not a universal receipt-validity bit. A consumer that
requires it for every admitted verdict makes supported negative and incomplete
evidence structurally impossible even when both traces are valid.

The Godot consumer now reconstructs the expected outcome from the frozen trace
receipts. Both trace populations must be present, non-refused, and fully
accepted. Candidate completion and matched-zero failed-terminal state determine
the producer completion flags; those determine pass. Two noncomplete,
nonfailed terminals determine incomplete; every other supported physical case
is failed. The reported verdict, physical result, standing claim, negative-
control conjunction, synthetic flags, counts, and authority fields must all
match that reconstruction. This admits honest finite negative and incomplete
results without loosening malformed-receipt refusal.

Per-step physical invariants remain checked in-run before they enter an arm
result. Terminal evidence does not duplicate every large receipt inline. It
retains, in canonical arm order, exact outer/native/invariant counts, terminal
identity, trace and initial-state digests, a canonical digest of each invariant
population, and a canonical digest of the ordered compact summaries. Valid and
invalid exits both carry this receipt; an active partial arm is included when
observations exist, while an early pre-observation exit honestly reports zero
arms. Content mutation changes the digest and dictionary insertion order does
not. This makes invariant observability compact and content-addressed without
turning each physical bug into a new canary or bespoke process supervisor.

### Checkout representation evidence is distinct from frozen Git identity

A clean Windows worktree may expose different raw line-ending bytes from the
canonical Git blob when a text path is governed only by `text=auto`. A
qualification source receipt must bind both layers: the immutable blob OID and
the exact checkout bytes actually read by the build. A closure may accept such
a difference only when it names the exact path, observed and canonical byte
lengths and SHA-256 digests, and the applicable representation rule. Every
undeclared difference remains drift and fails closed.

This distinction grants no semantic-equivalence shortcut. Source audits still
operate on frozen Git content, builds remain bound to observed checkout bytes,
and the complete exception population must be finite and explicit. R24D70 has
one such entry: the `.gdextension.uid` file's clean Windows CRLF checkout versus
its LF Git blob. The other 146 source entries match at both layers.

### Published-closure controls release physical authority without running physics

After a zero-world qualification closure is committed and pushed, the
production supervisor loads that exact closure and reconstructs its normalized
physical projection. It then repeats the complete campaign preflight, parses
the real worker, and acquires and releases the same serialized conformance lock
used by physical work. The retained receipt must show zero model, world, build,
solver-step, and physical-execution counts before it may release the next
finite invocation.

This control is a publication and route-binding seam, not a behavior canary.
It runs once, cannot predict the later physical verdict, and does not grant
acceptance or release authority. R24D70 passed this seam with one compact
3,226-byte receipt and thereby authorized only its declared two-world,
2,400-step development pair.

### A valid physical negative is distinct from an invalid execution

The physical supervisor accepts positive, negative, and physically incomplete
portable evaluator receipts only when their common and verdict-specific
conjunctions are internally consistent. A negative terminal may therefore be
a successful execution even though locomotion failed. Its terminal receipt
must bind clean source, authorization, the real worker, the complete retained
tree, content-addressed raw and terminal payloads, and the released operation
lock.

R24D70 demonstrates this boundary. The worker completed with semantic exit
zero, the evaluator-consumer checks passed `22/22` and `9/9`, and all 526
in-run physical invariants passed, while both arms timed out establishing
distal support. That outcome is scientifically negative but infrastructure
valid. It consumes the physical identity and requires a distinct successor;
it is never converted into success by rerunning or changing the threshold.

### Contact-field availability is not contact-load adequacy

An adapter may expose a finite contact-impulse field and still lack an adequate
source for a load-bearing predicate. Source quality is conditional on when the
value is measured, whether it is estimated or solver-applied, which constraint
components it contains, how manifold points map to semantic contacts, and
whether the engine's documented validity conditions hold in the actual world.
The capability label must preserve those conditions; field availability alone
cannot justify `qualified_bearing`.

Godot 4.7/Jolt is the concrete case. Its ordinary direct-body contact report
uses `EstimateCollisionResponse` during the contact callback, before the full
articulated multi-contact solve. Godot documents that estimate as accurate only
when neither colliding body is also colliding with any other body. A shared
floor supporting several bodies violates that condition even if every contact
identity and geometric classification is correct. The R70 whole-system
vertical-momentum discrepancy is an in-world adequacy rejection of that source;
it is not permission to rethreshold or relabel the observed result.

A solved-contact successor must remain observation-only. It obtains the
per-point normal and two friction lambdas after the native solve, binds them to
the same ordered `SubShapeIDPair` manifold points used to build the constraint,
records native step identity and source kind, and refuses missing, duplicate,
count-mismatched, CCD-only, or otherwise ambiguous mappings. Existing estimated
fields remain explicitly estimated. Only a separately qualified exact source
may feed a bearing predicate that claims solved impulse semantics.

Contact telemetry and energy telemetry are related native constraint data but
distinct portable claims. Exact contact lambdas can repair the bearing
observation without closing actuator-versus-nonmotor constraint work. A
successor may design one reusable native telemetry substrate, but adoption and
evidence for each portable consumer remain separately versioned and fail
closed.

R24D71 is the first concrete implementation of that solved-contact seam. Its
native v3 profile captures the finalized Jolt cache after
`PhysicsSystem::Update` while the space still reports active stepping, replaces
generic report vectors only for a complete finite point population, and
publishes a space-level receipt before `_post_step` flushes the contacts. The
adapter requires exact schema/profile, capture/read equality to the same native
step, reported/exact manifold and point equality, zero missing/CCD/mismatch/
nonfinite counts, and `complete=true` before any bearing or nonfoot contact
projection executes.

That structure is source- and zero-world-qualified only after its prospective
gate closes. Even then, the `qualified_bearing` mapping remains bounded to the
exact content-addressed runtime and requires a separate minimal native
calibration before behavior work. The seam grants no contact-force accuracy,
recovery, standing, energy-closure, cross-engine, or release claim by field
availability alone.

R24D71 has now crossed that zero-world boundary from clean, pushed, live-equal
source. Its compact closure binds one official nine-file evidence tree, nine
green checks, four current workers, and zero historical-audit replay or physics.
This advances the architecture state from “implemented” to “source-qualified,”
not to “physically calibrated.” QSDK-R24D72 must remain a separate development
contract whose complete zero-world gate authorizes at most one existing-world
construction and the smallest fixed number of native steps needed to observe a
current complete nonzero snapshot. It must stop early on observation, retain a
valid bounded negative if the step cap expires, and fail closed on any
infrastructure-invalid or incomplete route.

R24D72 implements that boundary by parameterizing runtime identity on the
existing shared supervisor and reusing the existing one-world/two-step worker.
This keeps the new executable surface to a thin campaign binding: the common
supervisor still owns clean/live-equal source checks, exact physical-path drift,
authorization, serialization, termination, and content-addressed retention.
The calibration classification is deliberately outside behavior semantics:
complete integer point populations distinguish zero from nonzero, while every
route or completeness failure remains invalid. No new threshold, evaluator,
worker, supervisor, or physical canary is needed.

R24D72's clean, pushed qualification has now closed that zero-world boundary.
The executable authority remains layered: the compact closure binds the exact
source, runtime, route, retained qualification tree, and two-step envelope;
the reused supervisor independently enforces committed authorization,
clean/live-equal source, exact physical-path drift, process serialization,
termination, and durable content-addressed retention at execution. Because
those common mechanics already cover publication-to-run drift, no separate
post-publication canary is added.

Physical authority is exactly one model attempt, one world, and two 120 Hz
steps with no behavior evaluator. That attempt can calibrate whether the
current complete solved-contact population is zero or nonzero on the existing
route. It cannot establish numerical accuracy, recovery, prone-to-standing,
repeatability, population coverage, or release authority.

The first R72 publication exposed a missing lifecycle edge in that layering:
the prospective source audit correctly described the implementation freeze but
reapplied its path-set assertion to the later commit that necessarily added the
closure and its audit. The supervisor stopped before loading authorization or
opening any physical resource, so the architecture failed closed but the
publication phase lacked executable coverage.

R73 makes source-freeze resolution a shared mechanic. A prospective audit uses
the current implementation commit while no closure exists; the same audit,
after publication, reads the immutable source freeze from the closure, proves
it is an ancestor of the current checkout, and evaluates the authored delta at
that commit. R73's zero-world gate exercises the post-publication branch against
R72's real published closure. This is a lifecycle regression control, not a new
behavior canary. The physical route, runtime, worker, seed, and two-step budget
remain unchanged and unavailable until the corrected gate closes.

R73 has now qualified that architecture from exact source `94ac327a`. The
published-closure branch was executed against R72's real closure, not inferred
from source text, and all other release checks passed with zero physics. Its
closure therefore authorizes one world and two steps while leaving the common
supervisor responsible for a second clean/live, frozen-path, runtime,
serialization, and termination check at the physical boundary. No extra
publication canary is needed because the previously absent phase now has a
direct regression execution.

R73 then exposed the next interface boundary after one native step. The R71
world correctly attached exact solved-contact source identity to each portable
contact, but the engine-neutral core protocol still had the older four-field
`ContactProvenance` schema with unknown-field refusal. The adapter-to-core JSON
therefore failed before the first observation could become portable. This is a
schema integration failure, not a contact-dynamics finding.

R74 must keep unknown-field refusal while making the two new fields explicit.
Their validation must be paired—both absent for legacy/general contacts or both
present and valid for source-qualified impulse contacts—and the zero-world gate
must deserialize the exact R71-shaped observation through the production core
route. Only after that deterministic seam is green may another bounded native
calibration be declared.

### Paired contact-source provenance remains backward compatible and strict

R74 implements that interface without forking the observation protocol. The
two source-specific strings are optional serialized fields: ordinary legacy
contacts omit both and preserve their prior bytes, while a qualified impulse
source supplies both. Core validation rejects either half-populated form before
policy use, and `deny_unknown_fields` continues to reject schema drift. This
keeps source qualification explicit without requiring every engine contact to
pretend it has exact post-solve impulse provenance.

The executable zero-world proof uses the production Godot binding and core
decoder rather than a parallel JSON model. It accepts the exact R71 pair,
refuses both one-sided mutations, refuses an undeclared field, and then runs
the existing supervisor's forced-failure projection at zero physical authority.
The prior publication-aware resolver is reused as a lifecycle regression
control; no per-bug physical canary or historical-audit sweep is added. The
development qualification passed all nine checks with zero physical execution.

Only a clean-pushed closure may turn that structural proof into authority for
the unchanged one-world/two-step calibration. The physical worker, native
telemetry source, controller, evaluator, seed, and world remain frozen. Thus a
later complete zero or nonzero result can answer only route/contact-population
viability; it cannot establish contact-force accuracy, recovery, standing, or
release readiness.

R74 has now closed that structural seam from exact source `454dbd02`. The sole
official qualification exercised every paired/partial/unknown branch through
the production decoder, both real worker parsers, the publication lifecycle
control, and forced supervisor failure with zero physics. Its closure preserves
the source freeze separately from the later publication commit, so the same
audit remains valid on the physical boundary without confusing closure files
for implementation changes.

The resulting authority is intentionally tiny: one unchanged native world and
two outer steps. The common supervisor must still prove clean/live-equal source,
the 36-path frozen physical population, exact runtime identity, serialized
ownership, termination, and durable retention. A complete physical result may
classify zero versus nonzero solved-contact population; nothing in the zero-
world closure licenses recovery or standing interpretation.

### R24D74 exposes the contact-receipt retention boundary

The physical R74 route proves the existing component boundary can hash solved
contact telemetry, transport the hash through two native steps, decode paired
source provenance in core, and terminate under the common supervisor. It does
not retain the object that was hashed. Consequently the raw campaign artifact
cannot recover the prospectively named
`solved_contact_telemetry_contract.exact_contact_point_count` without consulting
an unretained intermediate.

That is an evidence-transport defect, not a reason to redesign the controller
or add another physical canary. R75 should extend the component receipt with a
deep copy of the already-produced contact source receipt alongside its digest.
The zero-world architectural invariant is then direct: canonical hashing of
the retained receipt must equal `contact_source_sha256`, and its exact point
count must remain typed and available to the campaign record. The legacy hash
continues to identify the source; the retained receipt supplies auditable
classifier provenance.

R74 remains immutable and consumed as a valid integration route with an
incomplete calibration classifier. R75 must reuse the common qualification,
publication, supervisor, and retention machinery, change no physical policy or
world, and open no physics until a distinct clean-pushed complete zero-world
closure authorizes the same bounded two-step development route.

### R24D75 makes contact classifier provenance self-contained

The R75 component receipt advances to
`sporespore_qsdk_r24d75_godot_source_component_receipts_v1` and carries two
paired fields: the deep-copied `contact_source_receipt` and its existing
`contact_source_sha256`. The nested solved-contact contract remains the single
classifier authority; no parallel count is inferred from portable contacts.

A pure production helper owns validation, copying, and canonical hashing. The
physical collection path calls it before component assembly, while the
zero-world worker calls the identical function with complete positive, zero,
and invalid branch fixtures. This keeps evidence retention executable without
constructing a second classifier implementation or opening physics to test
serialization. The final development qualification passed all nine checks in
about 21 seconds with zero physical execution.

The architectural invariant is exact: canonical hashing of the retained
receipt equals its paired digest, and the nested
`exact_contact_point_count` exists as a nonnegative integer. Failure of any
part invalidates the route. R75 does not change the ten portable observation
channels, native contact capture, controller semantics, or physical world.

R75 has now closed that retention seam from exact source `4ceadcf1`. The sole
official qualification exercised the production helper's populated, zero, and
invalid branch population; independently recomputed both digests; proved
deep-copy isolation; parsed both real workers; and forced supervisor failure
with zero physics. Its closure preserves the implementation freeze separately
from this later publication commit.

The resulting authority is intentionally tiny: one unchanged native world and
two outer steps. The common supervisor must still prove clean/live-equal source,
the 36-path frozen physical population, exact runtime identity, serialized
ownership, termination, and durable retention. A complete physical result may
classify only the retained zero versus nonzero solved-contact population;
nothing in this closure licenses recovery or standing interpretation.

### R24D75 closes the native contact input seam

The authorized route subsequently completed from source `9cc1e03a`. At both
physical steps, the component receipt retained the full solved-contact source,
its exact typed point count (`8`), and its paired canonical digest. Loading the
exact core binary preserved from the qualification toolchain and canonicalizing
each retained source reproduces both hashes exactly. This establishes one
self-contained, content-addressed native-contact input path from Jolt capture
through portable collection and durable evidence.

The architectural result is intentionally below the recovery layer: it proves
that the controller can receive authenticated nonzero contact input, not that
its phase machine produces useful pose change. R75 is consumed. R76 must reuse
this proven transport and introduce the smallest measurable recovery-progression
route with a declared horizon and structural outcome; physical construction
remains blocked until that distinct source passes a complete zero-world gate.

### R24D76 reconnects the proven contact path to the full phase machine

R76 changes no recovery-layer implementation. The existing behavior worker
still creates candidate and matched-zero worlds, collects post-step native
observations, advances the branch-free portable phase supervisor, plans and
applies commands, retains an invariant receipt per solver step, stops at a
terminal phase or 1,200 steps per arm, and invokes the frozen V4 evaluator once.
The architectural delta from R70 is beneath that layer: each foot-bearing
observation now originates in the complete current-step post-solve constraint
receipt whose source and digest R75 made self-contained.

This permits a full behavior successor without a new worker or a rehearsal
world. The prospective source is keyed by one clean pushed commit, a focused
74-path qualification manifest, and 50 load-bearing physical paths. Seven
reused zero-world workers exercise the live composition, while immutable R70
and R75 closures are byte-bound rather than replayed. Physical authority stays
zero until the official R76 qualification publishes its closure.

### R24D76 publishes the bounded physical projection

The official qualification passed at source `deaf7551` and the closure now
projects only the fields the shared supervisor needs: the exact source freeze,
seed and digest, development class, non-held-out identity, two-model/two-world
budget, 2,400-step ceiling, 120 Hz step semantics, no-rerun rule, and universal
false release claims. The supervisor also compares all 50 qualified physical
paths against that freeze before a world may open.

This keeps the new authority architectural rather than campaign-specific: the
existing supervisor and existing behavior worker execute the one paired run;
the R76 closure supplies content-addressed authorization. No new physical
canary, behavior worker, controller branch, evaluator, or threshold was added.

### R24D76 authorization survives publication

The production supervisor loaded the closure from committed source
`be5da9ea`, normalized its `physical_authorization` object, and matched every
finite identity and budget field before returning a positive zero-world
control. The control also reran the shared source/runtime preflight and worker
parse under the serialized conformance lock. Its one-file evidence tree records
zero models, worlds, steps, and physical executions. This is the final
authorization seam: the existing supervisor may now open the one paired run,
while qualified physical-path drift, extra controls, and reruns still fail
closed.

### R24D76 exposes a missing runtime projection edge

R76's source audit used the qualified V3 runtime, but its thin production
wrapper did not pass that runtime into the shared supervisor. The supervisor
therefore validated and launched its own older default binary. Since both
binaries share the same Godot version banner, version text could not expose the
mismatch; their SHA-256 identities do. The old binary rejected the native
world's V3 solved-contact method during compilation, before construction.

R77 must make executable selection part of the shared preflight receipt. The
wrapper will pass path, digest, and length explicitly; the production
supervisor will publish the selected identity it already verifies; and the R77
zero-world audit will compare that receipt directly with the contract. This is
a reusable projection fix at the invocation boundary, not a new behavior
canary or physics heuristic.

### R24D77 makes selected runtime identity a reusable supervisor projection

The shared Godot recovery supervisor now owns one additional zero-world mode:
`RuntimeIdentity`. It validates the selected console's path-bound digest and
length, uses that exact executable to parse the configured production worker,
and emits the selected path, SHA-256, length, and zero-authority counters. The
same three identity fields are also carried by the ordinary preflight receipt
used inside publication control and physical launch.

R77's thin wrapper supplies those three values from its versioned contract, so
the wrapper-to-supervisor binding—not a separately reconstructed audit command
—is what the zero-world gate observes. This reusable projection addresses the
R76 omission without introducing a campaign-specific physical canary. All
behavior semantics and the two-world/2,400-step production envelope stay in
the existing worker and supervisor.

### R24D77 freezes the runtime-bound physical projection

Official qualification at `8de08149` retained the full production projection:
the thin wrapper supplied the V3 console identity, the supervisor verified and
published it, and that selected executable parsed the physical behavior
worker. The receipt binds the exact path, `19dc32…` SHA-256, and 293,376-byte
length alongside the existing two-model/two-world and 2,400-step envelope.

This keeps authorization compact: the committed qualification closure is the
content-addressed source of the finite physical projection, while one
publication control proves the later supervisor reads the closure unchanged.
No new worker, controller branch, evaluator, threshold, physical ghost, or
campaign-specific process scaffold was added.

### R24D77 reuses normalized publication-control mechanics

The R77 publication control uses the shared supervisor and the common closure-
verification helper. That helper now accepts an explicit list of source-only
authorization fields omitted by a generic projection, verifies every omitted
key exists exactly once, and compares every remaining field without a
campaign-specific projection verifier. R77 declares only the known per-arm
step subdivision and evaluator count as omissions.

The retained production preflight independently binds the selected executable
path, digest, and length, so runtime identity is not weakened by authorization
normalization. This keeps future successor controls compact while preserving
exact fail-closed comparison and zero-physics authority.

### R24D77 exposes the binary64-to-host-real command edge

The corrected runtime binding reached the intended architecture: the exact V3
console parsed the worker, one genuine world was built, and 137 candidate
solver boundaries flowed through native measurement, portable V4 advancement,
actuation receipts, source digests, and in-run invariant retention. The failure
occurred at the next adapter-owned write/readback boundary, before step 138 and
before the matched-zero world or evaluator.

That boundary currently mixes numerical domains. Portable recovery commands
and joint-derived velocity calculations are binary64, while the Godot host
parameter path has an existing explicit binary32 projection model elsewhere in
the adapter. The recovery route wrote the binary64 value directly and compared
the host readback to it with a fixed `1e-9` tolerance. It also returned only a
generic readback failure code, discarding the actuator, requested value,
readback, and error needed for precise diagnosis.

R78 should repair this as shared adapter machinery rather than add a campaign
heuristic: project the bounded canonical target into host-real representation
before the write; preserve canonical and projected values as distinct receipt
fields; validate the readback in the host domain; and retain both quantization
and readback errors. The zero-world application path can exercise the complete
edge with a non-binary32-exact command and forced failures. The physical worker,
controller, phase machine, evaluator, thresholds, morphology, and two-arm
cohort need not change, and no extra physical canary is architecturally
required.

### R24D78 makes the command representation boundary explicit

The recovery route now treats canonical command calculation and Godot host
storage as two named numerical domains. A bounded binary64 canonical velocity
is sign-projected, explicitly rounded through `PackedFloat32Array`, checked
against the published speed envelope and a conservative IEEE-754 binary32
`2^-23` relative representation bound, and only then written to the hinge. The
readback validator recomputes the projection and requires exact equality with
the already-representable host value.

This is production machinery, not a campaign tolerance: the actual active
control function uses it for every recovery- and stance-owned motor command,
and the application receipt preserves both sides of the boundary plus
quantization and readback errors. The legacy `godot_target_velocity_rad_s`
field remains the observed host value for existing consumers. A focused
zero-world worker reaches this same eight-hinge application surface with
non-exact values and three mutation controls. The physical worker, controller,
phase machine, evaluator, thresholds, morphology, runtime, seed number, and
two-world/2,400-step envelope are unchanged; no separate ghost or canary is
architecturally needed.

### R24D78 freezes the projected command route

Official qualification at `87a8d5f1` binds the production representation seam
to the same immutable source as its wrapper, runtime, and physical worker. The
focused current worker traversed all eight application writes with values that
actually change under binary32 projection; every projected value round-tripped
exactly. The retained projection receipt also makes the canonical-to-host sign,
format, method, quantization magnitude, formal bound, and zero-authority
counters inspectable.

Authorization remains compact. The source commit is the dependency key, the
79-entry manifest and 9-file evidence-tree digest bind what executed, and the
shared closure verifier owns qualification mechanics. R78 adds one semantic
worker and one small successor audit, but no physical supervisor, canary,
ghost, or historical-audit replay. A publication control must still prove the
production supervisor consumes the committed closure before the one physical
pair is launched.

### R24D78 publication control binds the unchanged finite projection

The reused production supervisor consumed the committed R78 closure and
matched all 22 common authorization fields. As in R77, the only normalized
omissions are the 1,200-step per-arm subdivision and single evaluator count,
which remain enforced by the immutable worker and supervisor. Runtime path,
digest, and length were independently revalidated through production
preflight.

This control adds no campaign-specific verifier or physical route. The shared
authorization-control helper binds repository identity, closure bytes, source
freeze, projection, preflight, operation lock, and all-zero physical counters.
Its one receipt is consumed; committing its closure opens exactly the already-
declared two-world/2,400-step physical pair.

### R24D78 exposes a second numerical boundary before host application

The binary32 projection worked through 393 genuine solver boundaries without
repeating R77's readback error. The next candidate command stopped earlier in
the application pipeline: the Godot adapter canonicalized the decoded command
array and compared that digest with the portable core's receipt digest before
preflight or any hinge write. Those identities differed.

R78 retained the failure code but not both digest values or the offending
command, so the exact numeric cause is intentionally unresolved. The physical
prefix remains useful invariant evidence but cannot become a complete behavior
result. This also reveals the coverage hole in R78's focused zero-world worker:
one eight-command shape exercised the application machinery, but not the whole
deterministic ramp-command population.

### R24D79 makes command-transport conformance finite and complete

The successor should reuse the existing production planner and application
function in zero worlds while enumerating every reachable deterministic active
command shape across recovery phase steps, plus stance and forced digest
mutation. Its mismatch receipt must expose the portable digest, recomputed
digest, phase, semantic step, command index, actuator identity, and canonical
command projection. That population directly covers the newly observed seam
without a physics rehearsal.

This should be common adapter conformance machinery, not another physical
supervisor or campaign canary. The controller, evaluator, thresholds,
morphology, seed, and two-world/2,400-step envelope remain frozen unless the
diagnostic population proves a separately declared change is necessary.

### R24D79 qualifies the guarded command boundary once, exhaustively

The portable planner now projects only recovery `target_position_rad` values to
`13` significant decimal digits before the existing `14`-digit canonical JSON
digest. The extra decimal is a guard against the observed one-binary64-ULP Godot
JSON parse shift; canonical encoding, controller phases, evaluator, physical
caps, and host-real binary32 projection remain separate and unchanged.

One compact worker enumerates all `603` declared command cells and routes each
through the real extension transport and production application surface. It
observed `4,824` validated writes and `4,824` exact readbacks with zero digest
mismatches, plus one forced bad-digest refusal before write. The population is
content-addressed as
`sha256:0285fcd60dd739084fa6131d58ce7d389d556a9da1d4dae1239d98293228dc46`.

The official gate uses one worker, one mutation, one exact runtime, and a
32-file source inventory. Shared qualification and closure mechanics own the
rest; no historical closure audits, seeded ghost, physical canary, model, world,
or solver step run in the gate. This closes the architecture seam exposed by
R78 while keeping physical recovery behind a distinct R80 declaration.

### R24D80 reopens behavior without reopening the integration stack

R80 is a new campaign identity around the existing generic supervisor and
behavior worker. The wrapper changes gate-scoped schemas, markers, evidence
directory, and seed label only; it still selects the exact V3 executable and
serializes one candidate plus one matched-zero world through the same `1,200`-
step-per-arm budget and single evaluator.

Its zero-world dependency graph is deliberately narrow. The R78 incomplete and
R79 transport closures are bound by immutable content, not re-executed. One
current worker traverses the complete command population, and the shared
supervisor supplies runtime parsing, forced-failure projection, and missing-
switch refusal. The load-bearing physical route cannot open until that exact
source is clean, pushed, qualified, and consumed through its published closure.

### R24D80 qualification validates the compact dependency graph

The exact clean-pushed source passed with one command-population worker:
`603/603` cells and `4,824/4,824` writes/readbacks, with no digest mismatch.
Runtime parsing and the two supervisor refusal surfaces passed separately. The
gate therefore exercised its current code-path risks without replaying historical
closures or adding a seeded physics rehearsal; model, world, and step counts
remained zero.

The resulting closure binds the 76-file source graph and nine-file evidence
tree. Its authorization projection preserves the existing two-world,
`2,400`-step, single-evaluator envelope. A separate published-closure control
must still load that committed projection before the generic supervisor may
construct either world, so qualification evidence cannot accidentally become
physical execution authority.

### R24D80 exposes a publication-versus-physics path-role collision

The publication control compared the freeze and closure commits across 61
declared physical paths and correctly stopped on two differences. Both were
live release-authority JSON files changed by the required closure projection;
the physical controller, adapter, runtime, worker, evaluator, and supervisor
were unchanged. R80's dependency graph had assigned the release files both a
mutable publication role and an immutable physical role, so no successful
post-publication state could satisfy it.

The control stopped before receipt reservation and before all physical counts.
The architectural correction is a declared path-role partition: live
publication authorities remain source inventory and closure outputs, while the
qualified physical set contains only paths whose mutation could change route,
runtime, physics, or authorization semantics. The two sets must be explicitly
disjoint and audited before the successor freeze.

### R24D81 makes the path-role partition executable

The R81 contract now exposes `publication_only_paths` separately from
`qualified_physical_paths`. The two live release authorities remain in the full
source inventory and may change only to publish a closure; they are excluded
from the 59-path drift predicate used by authorization and physical execution.
The source audit requires both sets to exist, requires the physical set to be a
source subset, and requires their intersection to be empty.

Nothing below that classification layer changes: the thin wrapper still binds
the generic serialized supervisor, exact V3 runtime, existing behavior worker,
two-world/`2,400`-step budget, and single evaluator. The compact command-
population gate is rerun because the wrapper identity is new; another physics
rehearsal would not test this source-role correction.

### R24D81 qualifies the corrected dependency partition

The clean-pushed gate proved the source audit, full command population, runtime
parser, and refusal controls while retaining zero physical counts. Its declared
source graph resolves to 59 immutable physical/authorization paths and two
publication-only live authorities with no overlap. The two release files can
therefore carry the required closure projection without tripping the physical
drift predicate.

The qualification closure preserves the unchanged physical projection but does
not itself construct a world. The generic supervisor must next load that exact
committed closure, compare only the 59 immutable paths, rerun the preflight, and
release its serialized lock before physical execution can become current
authority.

### R24D81 validates publication without reopening physical dependencies

The production supervisor loaded the committed R81 qualification closure from
source `12290ca4` and applied the new path-role partition exactly. Its 59-path
physical and authorization drift check was empty; the only two source deltas
were the release contract and support matrix, both declared publication-only,
and the role intersection remained empty. Runtime parsing, authorization-
projection binding, and serialized lock acquisition/release all completed in
one control receipt with zero physical counts.

This makes publication a permitted authority transition rather than false
physical drift, while retaining fail-closed immutability for everything that
can affect route, runtime, physics, or authorization semantics. The supervisor
may now open the already-frozen candidate-plus-matched-zero development pair.
That later physical invocation remains separately finite and consuming; this
control neither constructs a world nor establishes recovery behavior.

### R24D81 exposes the remaining raise-body transition boundary

The complete physical route now reaches farther than the earlier integration-
invalid attempts. Its candidate passed the command boundary, completed distal
support, produced 572 classified four-foot-bearing frames, cleared nonfoot
contact in its final classification, and reached `0.232109 m` COM height. The
matched-zero arm never established distal support. Both traces, all `999`
in-run invariants, and the verdict-aware evaluator consumer remained valid.

The architecture nevertheless correctly refused the next phase. Candidate COM
gain peaked at `0.162044 m`, below the frozen `0.22 m` raised-body predicate,
and the final energy-balance residual was `95,828.906754 J`, above the frozen
`0.25 J` safety predicate. Thus `raised_body_gate` and `safety_gate` were never
simultaneously true, stance ownership was never requested, and the phase timed
out. R82 must first diagnose the retained policy trajectory and Godot energy
mapping without changing R81. Any successor must name one controlled change and
qualify exactly its affected route; another automatic full-seed ghost or
physical canary is not implied.

### Refinement-safe native guard fallback is a versioned receipt path

The Godot/Jolt component-norm pair solver now has a versioned successor for one
representational terminal. It first executes the frozen R99 solver. Ordinary
success returns the same impulse semantics under the new schema, and every
failure except the exact exhausted-refinement code passes through unchanged.
For that one code, a pure diagnostic reconstructs the interval, binary32 scale
sequence, terminal predicates, predicted body velocities, and zero-scale
relations. A zero impulse may replace the requested pair only when the terminal
failure is exclusively the component-norm boundary relation and both source
bodies are independently inside the same inner target at zero scale.

This fallback is not a controller, threshold, margin, or native safety-limit
change. It is part of the actuator receipt and therefore remains visible to the
existing route validation, immediate native readback, source-measured centered
work, telemetry, raw behavior trace, and in-run validation chain. A mutated or
incomplete diagnosis cannot reconstruct and fails closed. Physical authority
remains a separate clean-pushed prospective declaration and qualification.

### Finite behavior successors use a compact reusable qualification shape

R101 is the first recovery behavior successor to use the common declarative
envelope while preserving a predecessor-selected seed that was not derived
from the successor label. The shared validator therefore accepts an explicit
seed only when the contract supplies its provenance; existing label-derived
contracts retain their original rule. This lets a controlled mapping change
hold the physical cell fixed without copying another campaign-sized validator.

The critical path combines current pure-data worker specifications, canonical
predecessor-receipt equivalence, production wrapper/runtime identity, forced
supervisor failure, missing-switch refusal, and content-addressed source/path
controls. Historical closure audit programs remain regression-cadence work and
are not re-executed. Native worlds, if later authorized, still retain every
step's invariant receipt; compact qualification changes no physical safety or
trace requirement.

### Qualification publication is reusable and outside frozen physics source

Finite behavior qualification closures now use a common publication-only
validator. It content-addresses the complete retained evidence tree, attempt,
receipt, production preflight, source manifest, frozen Git bindings, runtime
identity, authorization projection, and false claim boundary. A campaign adds
only a thin binding and its immutable closure record.

The validator and binding are deliberately excluded from the already-qualified
physical path population: adding publication verification cannot create
physical-source drift after the prospective freeze. The frozen source audit
selects the closure by exact presence and validates the live transition, while
the shared physical supervisor independently rechecks the committed closure,
source ancestry, and all 49 runtime-affecting paths under the operation lock.

### R24D101 separates route validity from distal-support behavior

R101 proves the refinement-safe production route can remain valid under the
exact native states that defeated R99. Across the complete candidate arm, 125
per-actuator predecessor refinement failures were converted to typed,
diagnostic-bearing zero holds; every immediate readback stayed inside the
unchanged outer guard. Both arms then reached the evaluator with complete
traces and `536/536` passing in-run invariant receipts. The physical closure is
therefore a valid negative rather than an integration-invalid prefix.

The newly visible architectural boundary is the portable
`establish_distal_support` policy. Candidate control generated contact on every
foot and briefly reached three simultaneous contacts, whereas zero generated
none, but the conjunction of four ordinary bearing contacts was never true.
The phase transition depends only on that conjunction, so energy residual and
later raise-body safety gates did not cause this timeout. Candidate COM also
ended lower than its initial observation; the retained result does not justify
calling its mixed changes superior.

Physical-result publication now uses a reusable validator layered on the
existing supervised-attempt, retained-tree, CAS, source-drift, and complete raw
invariant helpers. It recomputes trajectory and fallback projections from the
retained raw result; an R101-specific binding pins only identity and markers.
R102 can therefore diagnose the immutable trajectory without copying another
campaign-sized closure audit or opening a rehearsal world.

### R24D102 exposes a greedy shared-body allocation boundary

The R100 safety projector is correct at each versioned pair boundary, but the
route invokes it sequentially in fixed actuator order and immediately updates
native angular velocity after each pair. Each limb's hip therefore changes its
upper body before that limb's knee is projected. R102 proves that exact dataflow
through 960/960 hip-readback-to-knee-source equalities in the retained R101
trace.

That sequencing is behaviorally material. Hips received nonzero impulse on all
960 intents; knees received zero scale on 770/960. Every one of the 645 typed
outer holds occurs with the shared upper parent outside the unchanged inner
target, the distal child inside, and the requested knee parent delta pointing
farther outward. The remaining 125 knee zeros are R100's already-versioned
representational fallback. This is an allocation topology problem, not a need
to weaken the native angular-velocity guard.

Historical result audits must likewise exclude forward-moving successor
state. R101's shared closure audit continues to bind its immutable source,
retained tree, CAS, invariant, trajectory, and outcome facts, but R102's live
audit alone owns whether R102 remains required. This prevents valid successor
progress from reddening an unchanged historical result.

The selected successor architecture computes requested joint impulses exactly
as before, accumulates their predicted deltas by body, and solves one common
binary32-floored population scale before any body write. Only after all nine
predicted bodies pass the unchanged inner target may the route apply one
aggregate impulse per affected body; the receipt still retains each actuator's
requested impulse, common scale, attributed applied impulse, work, and pairing
identity. This removes action authority from iteration order while preserving
the controller, targets, gains, caps, inner and outer safety boundaries, and
evaluator.

R102's frozen-state replay found such a positive scale on 240/240 retained
states and kept 2,160/2,160 final body relations inside the target. That is an
architecture-selection argument only. R103 must implement and mutation-test
the new population receipt at zero world, and a later qualified physical
successor must independently observe its trajectory.

### R24D103 removes iteration order from the native action topology

R103 implements the selected population seam in three explicit layers. The
pure projector accepts one complete request for each canonical actuator,
rejects duplicates, omissions, identity mismatches, broken parent/child
pairing, nonfinite values, and invalid body state, and emits a canonical
nine-body population. Its one common binary32-floored scale is constrained by
every predicted body relation under the unchanged component-norm inner target.
Zero remains a typed outer hold or refinement-safe representational fallback,
not an implicit failure.

The native route validates the complete population and all eight mappings
before the first write. It then applies at most one aggregate torque impulse
per nonzero body rather than 16 sequential parent/child writes. All nine
post-application angular velocities are read once after the aggregate
population, and every joint receipt references that shared readback. The
joint-level work mapping remains centered and attributed even though the
physical write belongs to the body aggregate. This separates action topology
from evidence attribution without weakening pairing, cap, guard, or work
provenance.

The behavior worker selects the new mapping only through the versioned R103
actuator mode and validates dynamic zero-to-nine body-write counts, eight
attributions, nine shared body receipts, aggregate reconstruction, and all
readback/work identities. Existing modes retain their original sequential
semantics. The production dispatcher, mapping selector, and mutation controls
all pass under the clean-pushed zero-world qualification, while the R100
predecessor receipt remains exact.

The compact qualification architecture stores one 18-entry manifest digest and
two worker receipt digests. Its ordinary closure audit hashes that frozen
population and does not re-execute historical closures or the workers; full
worker re-execution belongs to the declared regression cadence. This is source
authority only. R104 must still exercise aggregate write plus immediate shared
readback in a genuine minimal Godot/Jolt world before any behavior successor
uses the route.

### R24D104 commissions the aggregate seam through the real route

R104 adds no new control mathematics. It exposes the versioned R103 actuator
mode through the existing serialized two-step production supervisor and makes
the worker validate the complete aggregate application receipt. The validator
requires canonical mapping and work identities, eight commands and actuator
receipts, nine body receipts, dynamic one-to-nine nonzero body writes, one
positive common scale, complete pre/post native readback, no motor targets,
and no input-iteration action authority.

The smallest native architecture check is therefore one world and two solver
steps: the first performs the changed aggregate write and shared readback; the
second proves continuation through the ordinary finalization path. Existing
in-run physical invariants remain required on both steps. The architecture
does not add a campaign-specific canary, full-seed rehearsal, second seed, or
behavior evaluator. R104 must pass the reusable zero-world source and refusal
controls before this single physical commission is authorized, and the later
behavior successor remains a distinct freeze.

### R24D104 qualification binds the route without another audit subsystem

R104's one official zero-world qualification passed all ten shared checks. Its
closure stores a compact retained-tree digest and source-manifest digest while
binding exact source, runtime, toolchain, checkout representation, worker
receipt, and supervisor-control identities. Full verification uses the
existing `verify_declared_zero_world_qualification_authority` mechanics; R104
adds no campaign-specific closure-audit implementation and replays no
historical closure audit.

The qualified physical partition is frozen at 50 paths. Publication changes
may update only declared documentation, matrices, and the closure; any change
to those 50 load-bearing paths invalidates authorization. The direct physical
supervisor will recheck the committed closure under the operation lock before
constructing the sole two-step world.

### R24D104 proves the aggregate topology through a genuine native step

The physical route used the architecture exactly as declared: collect eight
canonical intents, solve one population scale, validate the complete
nine-body result, apply each nonzero aggregate body impulse once, read all
nine bodies once after application, and reconstruct eight attributed joint
receipts. All nine bodies were nonzero in this identity, so the native route
made nine writes rather than the predecessor's 16 sequential parent/child
writes. Input iteration order remained non-authoritative.

The route continued through the second native and portable step with both
in-run physical invariants and native-engine health passing. Its closure audit
reuses the shared bounded-ghost, two-step-route, and complete-invariant
mechanics; no new campaign-sized verifier is added. Because the physical
partition is now deliberately changed by closure publication, any attempted
R104 rerun fails source-drift authority. R105 behavior work must bind the
immutable R104 closure by digest instead of replaying this route.

### R24D105 reuses the behavior architecture with one allocation delta

R105 returns to the full two-arm behavior worker without adding another
physical route layer. The production worker already dispatches the R103
order-neutral mode, validates its population/readback receipt, and feeds the
unchanged per-actuator attribution into the existing work observer, trace,
in-run invariant, and recovery evaluator surfaces. The exact R101 controller,
state machine, target poses, gains, caps, morphology, initializer, thresholds,
arm order, seed, and horizon are frozen; only the actuator-allocation identity
differs.

The source authority is a thin campaign binding over the reusable finite
behavior gate. Its single current worker checks the complete deterministic
population projection and mutations, while runtime identity parses the real
behavior worker and the shared supervisor provides forced-failure and missing-
switch controls. R101, R102, and R104 are content-addressed dependencies, not
critical-path audit executions. Consequently no new route ghost, canary,
extra seed, or rehearsal world is architecturally necessary before the exact
finite behavior pair; that pair remains blocked pending R105 qualification.

### R24D105 qualification freezes the load-bearing behavior partition

The official qualification closes the prospective architecture at source
`1f9012db`. Its manifest binds 51 physical paths, including the production
worker, shared supervisor, order-neutral route/world mapping, finite contract,
thin source audit, and exact R101/R102/R104 evidence dependencies. The closure
publication and release matrices are publication-only surfaces, so recording
the result does not mutate the frozen physical partition.

The shared qualifier rebuilt the native library and adapter, ran targeted
core, Python, and versioning checks, executed the single 17-positive/eight-
mutation population worker, parsed the real behavior worker, and exercised
both refusal paths without constructing a world. Physical authority is now
bounded to the exact two-arm R105 population and 2,400 total outer steps. No
architectural claim follows until that behavior evaluator returns a valid
complete physical result.

### R24D105 proves allocation delivery but not the support sequence

The full behavior route completed without adding another adapter seam. Across
240 candidate actuation steps, the architecture solved one positive common
scale, reconstructed eight joint attributions, applied nine nonzero aggregate
body impulses, and completed 18 shared native readbacks per step. Every hip
and knee received a nonzero attributed impulse at every candidate actuation
step. The matched-zero arm emitted no order-neutral population application.
The reusable physical-closure verifier now selects either the legacy
per-actuator guard projection or this population projection through a thin
campaign binding; R101 remains green under the same shared mechanics.

The resulting motion still never assembled more than two simultaneous distal
contacts and never crossed the four-site support gate. That cleanly moves the
next architectural question above the allocator: R106 must derive a compact
phase-localized comparison of target error, body motion, individual contact,
and simultaneous support from the immutable R101 and R105 traces. No new
world, canary, route ghost, or threshold is authorized by that diagnosis, and
R105's exact source identity is permanently consumed.

### R24D106 selects a joint-target-monotone prewrite projection

The R106 audit extends the reusable retained-trace diagnosis module rather
than creating another campaign-sized physical harness. It loads the two
content-addressed raw traces, derives phase-local velocity, pose, anchor,
contact, and body-motion projections, hashes the full canonical 27,905-byte
result, and retains only a compact human-facing summary. The old R102 path
continues through the same module and remains green after forward live-state
keys are explicitly excluded from its immutable evidence comparison.

R105's body guard is architecturally doing what it declares: all nine body
angular-velocity component norms remain below the engine-derived inner target.
It does not constrain the eight relative joint velocities to the portable
controller's much smaller canonical targets. Aggregate impulses therefore
drive those joints across their `±1 rad/s` targets before each solver step;
the solver returns the opposite sign, producing a near-every-step limit cycle
and rapidly alternating front-pair/rear-pair contact.

R107 may add one pure prewrite projection to the existing order-neutral
population solver. For each actuator it projects the complete aggregate
nine-body delta onto that joint's retained world axis, derives the largest
common scale that cannot cross the canonical target, binary32-floors the
population minimum, and composes it with the existing body-guard scale. A
nonhelpful aggregate delta makes the whole population hold for that step. This
uses no empirical threshold or behavior margin. All controller, route,
attribution, aggregate-write, native-readback, work, trace, invariant,
evaluator, and supervisor architecture remains unchanged. R104 and R105
already cover the physical route topology, so only pure zero-world projection
and mutation qualification is presumed before the next finite behavior pair.

### R24D107 composes joint-target and body-population safety

R107 keeps the R103 aggregate topology and adds one pure prewrite layer. The
layer canonicalizes all eight validated R87 predecessors, reconstructs the
complete nine-body aggregate delta, projects each final body delta back onto
its joint axis, and selects one binary32-floored scale no larger than the first
helpful joint-target crossing. A nonzero delta that does not reduce its source
target error makes the whole population hold. The scaled requests then enter
the unchanged refinement-safe R103 body-population guard.

The production route writes the same canonical body population once, performs
the same nine-body post-application readback, and reconstructs the same eight
source-measured joint attributions. Versioned R107 mapping, work, projection,
readback, sampler, and application receipts make both scales and both guard
decisions explicit. The compact zero-world test validates those seams and the
real behavior-worker dispatch while retaining R103 as an exact regression;
it opens no physical world. R104 already commissions the aggregate route and
R105 already exercises its full behavior horizon, so the next load-bearing
work is the declared finite pair after clean-source qualification, not another
route layer.

### R24D107 qualification publishes physical eligibility

The sole zero-world qualification passed all `10/10` checks at exact
clean-pushed, live-equal source `7268ee2c`. Its nine-file content-addressed
tree binds `68` source entries and the complete `52`-path qualified physical
population. The pure worker passed `48` positive cases and rejected eight
forced failures or receipt mutations, while one production parse and both
shared supervisor refusals covered the actual dispatch boundary. No historical
closure audit, physical canary, full-seed ghost, model, world, or solver step
was added.

The qualification closure changes publication state only: it enables exactly
one ordered candidate-plus-matched-zero **development** invocation bounded to
two worlds and `2,400` total outer steps. It does not change the physical
partition, actuator mechanics, controller, evaluator, thresholds, seed,
morphology, arm order, or horizon frozen at `7268ee2c`; nor does it establish a
behavioral or release claim. SDK scores remain `11/20` and `11/25`.

### R24D107 exposes the whole-population target-hold deadlock

The finite physical result confirms that the R107 receipt and execution
architecture agree. Across all 240 candidate command steps, each application
reconstructed the same ordered eight-joint and nine-body population, classified
the four front joints and two rear knees as helpful, classified both rear hips
as nonhelpful, and emitted a target common pre-scale of zero. All 240
applications consequently produced a whole-population hold, zero host/body
impulse writes, nine-body before/after readbacks, and eight source attributions.
The complete pair retained `4,320` native readbacks and all `536/536` in-run
invariants passed.

This is a policy-composition deadlock, not an order-dependent write, native
health, receipt, or evaluator failure. The globally coupled safety rule makes
six helpful joint requests depend on two persistently nonhelpful rear-hip
requests, so the candidate has the same COM, contact, energy, phase, and
terminal projection as the matched zero. R108 must diagnose the retained
rear-hip predecessor projections before choosing between a per-actuator
target-monotone layer and a controller-target correction. No physical route is
authorized by that diagnosis, and R107 itself is consumed.

### R24D108 replaces scalar direction coupling with a joint-space solve

R108 shows why neither the R107 scalar hold nor a six-request rear-hip deletion
is a sound composition layer. An equal-and-opposite impulse at one hinge changes
the shared torso and therefore several measured joint velocities. The eight
canonical hinge errors and eight signed joint impulses are coupled by an
eight-by-eight effective inverse-inertia response matrix. On all 240 retained
R107 states that matrix is symmetric to a maximum absolute residual of
`2.2737367544323206e-12` and has positive Cholesky pivots.

R109's selected architecture computes that matrix simultaneously from the
source-measured world axes, parent/child identities, and body inverse-inertia
tensors; symmetrizes reciprocal entries by their arithmetic mean; and solves
the full canonical velocity-error vector in canonical actuator order. One
common scale then enforces the unchanged per-actuator S169 caps, the existing
R103 body-population guard, and the existing downward binary32 representation
refinement. The finite R108 replay required no cap or body reduction and at
most five of the inherited 16 representation refinements.

This keeps policy targets engine-neutral while making Godot/Jolt's force-based
realization inertia-aware and order-neutral. It is still only a zero-world
mechanics selection: implementation, source reconstruction, matrix mutation,
singular/indefinite refusal, cap, body-guard, readback, work, and production-
receipt qualification must pass before any physical question can be declared.

### R24D109 makes the solve an in-run production invariant

The implemented R109 layer is a pure prewrite projection inside the existing
aggregate force-based route. It forms each matrix column by applying a unit
equal-and-opposite joint impulse through the current world inverse-inertia
tensors and observing every canonical joint axis. Reciprocal matrix entries are
averaged in float64, then a fixed-order Cholesky factorization refuses any
nonfinite or nonpositive pivot. No regularizer, fitted condition threshold, or
fallback direction is introduced.

The solved impulses are scaled first by the unchanged per-actuator cap and then
by the unchanged R103 body-population guard. Binary32 representation uses at
most the already-authorized 16 downward common-scale refinements; exhaustion
becomes an explicit zero hold. Before native writes, the exact recomputed
receipt must show finite values, cap compliance, positive pivots, a valid body
guard, nonincreasing absolute error for all eight joints, and zero target
crossings. After aggregate body writes, the shared immediate readback must
remain inside the frozen outer component-norm guard. The next observation binds
centered joint work to the attributed impulse without using a mechanical-energy
residual as an actuator source.

R109 reuses the shared declarative qualification gate under its new
`native_route_ghost_v1` profile. That profile fixes one model, one world, two
solver steps, no behavior evaluator, one development seed, full finalization,
and the normal CAS and supervisor path. A later behavior campaign may reuse the
commissioned route but must declare a distinct finite question and horizon.

R110 is that declarative behavior layer. It binds the exact R107 non-held-out
candidate-plus-matched-zero cell and keeps its portable controller, evaluator,
thresholds, seed value, arm order, and `1,200`-step-per-arm horizon unchanged.
The wrapper selects the already commissioned R109 actuator mode while the
shared supervisor continues to own serialization, source-drift checks, complete
in-run invariant scanning, retention, CAS publication, and terminal handling.
No additional integration ghost or behavior-specific physical canary is part of
the architecture.

The exact `5b4dba47` implementation freeze passed the sole official `10/10`
zero-world qualification over `69` source entries and `53` qualified physical
paths. The immutable closure authorizes only that one-world, two-step route
profile. Qualification itself opened no world and proves no physical route,
recovery behavior, standing, repeatability, population result, or cross-engine
equivalence.

### R24D119 makes phase-boundary speed part of portable controller identity

The R118 trace establishes an architectural distinction between ordinary
contact and a load-bearing support state. Its candidate retains four ordinary
foot contacts throughout `raise_body`, yet the torso and distal bodies remain
in nonfoot contact and no foot meets the frozen bearing impulse. The production
route is active and healthy; the missing progress is above integration and
inside the portable phase policy/load path.

The existing planner begins `raise_body` at the exact support target pose but
reads its speed ceiling from `stance_pose`, causing an `8` to `0.75 rad/s`
discontinuity at phase transition. R120 treats that value as versioned portable
controller semantics: the historical profile remains immutable, while a new
controller/profile/stance-pose identity may continue the already-qualified
speed across the ramp. Target geometry, ramp shape, phase predicates, native
mapping, caps, and evaluator do not change. Retained-state projection is
adequate to qualify the new source mechanics, not to claim the ensuing native
trajectory or standing.

R120 realizes that seam as controller V4 without introducing a new request or
collection schema. Controller identity selects an immutable profile; the
existing engine-neutral planner continues to interpolate support targets to
the zero-joint stance targets, while the versioned stance-pose speed field now
remains `8 rad/s` for the complete raise-body ramp. Godot context, bootstrap,
fixture, and production-worker dispatch carry the new identity, but native
world construction and command application remain the same registered route.
The zero-world proof binds support plus ramp endpoints and midpoint, exact
digests, production application, ownership refusals, and digest-breaking
mutations. It is source conformance only and does not predict a physical
trajectory.

The exact `90f3e383` source passed its sole official `12/12` zero-world
qualification with no model, world, or solver step. The qualified boundary is
therefore the V4 identity, profile delta, portable command ramp, Godot dispatch,
production application seam, and refusals—not the behavior that will result
when those commands first enter a native world.

### R24D123 reuses the versioned speed seam without duplicating the campaign harness

R122's immutable-trace diagnosis selects `22 rad/s` only as one bounded
development input. R123 therefore clones the complete V4 portable profile into
V5 and versions only the controller, profile, and zero-joint stance-pose
identities while changing the stance-pose speed field from `8` to `22 rad/s`.
The distal-support pose and speed, all ordered targets, ramp, phase gates,
thresholds, evaluator, actuator caps and mappings, morphology, seed, arm order,
and horizon remain exact. The existing engine-neutral planner and native
application route are reused without a request, observation, or world schema
change.

The native zero-world proof is now split into reusable mechanics and a thin
campaign binding. The common evaluator owns support and ramp sampling,
cross-version ownership refusals, digest-breaking target and speed mutations,
unregistered-controller refusals, bootstrap application, and eight-command
application. R123 supplies only V4/V5 callables and exact content identities;
R120's observed worker is not rewritten. This is source conformance with zero
models, worlds, and solver steps. It does not predict lift or standing, and
physics remains blocked pending the sole clean-pushed qualification.

The exact `71d4ed13` freeze subsequently passed that sole official `12/12`
qualification. The closure binds all 32 frozen sources and the complete
11-file retained evidence tree, including the genuine production-worker parse
and native zero-world application. All 24 sampled ramp commands changed only
their speed ceiling, and all seven ownership, mutation, and registration
refusals fired. No model, world, or solver step existed. The V5 route is now
qualified as portable source mechanics; a distinct R124 finite behavior
contract and complete zero-world gate remain mandatory before native physics.

### R24D124 preserves the exact finite cell while changing only controller identity

R124 is a behavior declaration, not another controller implementation and not
another integration campaign. It binds the consumed R121 candidate-plus-
matched-zero cell byte-for-byte, including its numerical seed and seed label,
and replaces only the qualified controller/profile identity selected by the
portable planner. V5 therefore reaches the same native Godot/Jolt construction,
collection, planning, application, invariant-receipt, progress, retention, and
evaluation route already exercised by R121.

The campaign layer remains deliberately thin. A shared declarative finite-
behavior gate owns the complete zero-world envelope; the R124 worker projects
the already complete R123 V4-to-V5 mechanics receipt into a physical-question
declaration. The shared supervisor continues to own serialization, source-
drift checks, process termination, progress timeouts, complete raw invariant
scanning, and outcome-neutral retention. Its registered-controller boundary
now admits V5 explicitly. No request, observation, command, trace, evaluator,
or physical-result schema changes.

This architecture authorizes no physics by declaration alone. One clean,
pushed, live-equal zero-world qualification must first close the R124 source
identity. Only that closure may authorize the single sequential candidate and
matched-zero development pair; a valid negative remains scientifically valid,
while infrastructure-invalid or incomplete work is retained and consumed.

The exact R124 freeze `9a68021f` subsequently passed its sole official
qualification. Its closure content-addresses all 75 source entries, all 53
physical paths, and the complete nine-file retained tree while authorizing no
model, world, or solver step during qualification. The publication audit also
models the Windows checkout and Git blob as distinct exact representations
when line-ending materialization differs. Git remains source authority; the
qualification's checkout digest must match the corresponding retained manifest
entry and be explicitly named in the checkout-only population. This closes a
representation seam without changing the frozen physical partition.

R124 may now enter the native route exactly once with two sequential worlds:
candidate first, matched zero second, at most 1,200 outer steps per arm, and
one evaluator invocation. Progress receipts remain process evidence rather
than behavior evidence, and the complete per-step invariant population remains
mandatory. Qualification does not predict the result and does not establish
standing.

### R24D125 separates observed V5 response from latent acceptance authority

The immutable V4 and V5 candidates share their complete physical state through
semantic step 39 and diverge first on step 40, where the raise-body speed
ceiling becomes behaviorally relevant. The complete position-error-clamped
command reconstruction retains all `9,600` joint intents; in particular it
does not misclassify V5's `1,213` position-error-limited intents as requiring
full `22 rad/s` saturation. V5 loses all-four ordinary/bearing support only on
steps 70-76 and 335-352, then restores all four through terminal step 639.

The faster command materially transfers load: total absolute joint impulse is
`2.6207295045673833x` V4, settled foot load is `2.1800427383481997x`, and
settled nonfoot load falls from `0.23230416057243322` to
`0.04915037958999165 N s`. It does not finish the geometric task. The final
zero-target window moves COM only `5.9194862842559814e-6 m`, the summed joint
range is `0.0006834045052528381 rad`, and the torso plus front distal bodies
remain in native nonfoot contact. R125 therefore selects neither another speed
ceiling nor a post-outcome horizon extension.

The same replay exposes an independent source-authority seam. Both candidates
cross the frozen `0.25 J` energy component at semantic step 14, never recover
it, and enter raise-body at step 40 with that component already false. This is
not evidence that the threshold is wrong: R86 binds the Godot R57 mapping as
an intentionally unclosed constraint/passive partition with no exact balance
authority. The existing `safety_gate` remains the physical-acceptance gate and
must not be weakened or reinterpreted.

R126 is additive and zero-world. It may expose the energy-partition authority
explicitly and add a development-only stance-handoff predicate requiring a
valid raised-body observation, joint limits, actuator budgets, zero forbidden
contact, and no-cheat. An incomplete energy partition remains false for the
unchanged safety, stable-stance, physical-result, and release gates. This lets
a later genuinely raised controller exercise stance ownership without
manufacturing energy balance or a standing claim. Legacy request, receipt, and
transition semantics remain exact; physical work requires a later distinct
declaration and complete qualification.

### R24D127 makes actuation realization an explicit controller-bundle seam

Portable controller V6 clones V5 exactly except for profile and controller
identity. This allows an engine adapter to bind a versioned realization
without smuggling engine identity into the portable planner or pretending an
adapter change is a target change. For Godot/Jolt, the realization is
`godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1`: eight
HingeJoint3D constraint motors receive the unchanged position-error-clamped
velocity targets and published per-step impulse caps inside Jolt's contact
solve. It performs zero pre-solver direct-body impulse writes.

The adapter context, initial application, active application, worker mode,
and raw-result projection all carry or derive that identity. The worker treats
controller V6 and the solver-coupled mode as an inseparable pair. Historical
legacy mode remains available under its old name and behavior; historical V1-
V5 controllers and R109 force mapping are not rewritten.

The common versioned-controller evaluator now parameterizes application and
expected realization while preserving R123 defaults. R127 therefore needs
only a thin binding: V5 and V6 must emit identical support and sampled
raise-body command populations, the new receipt must show eight solver-coupled
motor targets and no body impulses, and historical-controller plus mutated-
context realization controls must refuse. This is a complete zero-world
source gate, not a physical ghost. The sole clean, pushed, live-equal R127
qualification passed all 12 checks with a 37-entry manifest, 11 retained
files, and zero models, worlds, or solver steps. Its closure qualifies this
exact realization binding only. R128 subsequently declared and qualified one
exact nominal candidate-plus-matched-zero development pair; no broader
physical authority follows from that declaration.

### R24D128 reuses the finite behavior envelope for V6

R128 is a declarative binding over the existing finite Godot/Jolt behavior
gate. The physical envelope remains one exact nominal cell with a sequential
candidate and matched-zero arm, the preserved R121/R124 numerical seed and
seed label, two worlds, at most 1,200 outer steps per arm, one evaluator
invocation, and one same-source attempt. Every native step must still carry a
passing in-run physical-invariant receipt.

The candidate uses controller V6 with
`solver_coupled_native_constraint_motor_v1`. The worker hard-pairs those two
identities, projects
`godot_jolt_r24d127_solver_coupled_native_constraint_motor_v1`, performs zero
pre-solver body-impulse writes, and retains the explicitly incomplete R57
energy-source authority. The matched-zero arm uses the same controller,
realization, model, and evaluator but requests no actuation.

The declaration changes no portable target, speed, cap, phase gate, threshold,
initializer, morphology, collision rule, solver configuration, evaluator,
seed, arm order, or horizon. Its compact zero-world worker reuses R127's exact
receipt and refusal population. The production wrapper is parsed through the
real supervisor, including missing-switch, projection, runtime-identity, path-
partition, and progress-stall controls, before any physical authorization can
exist.

The sole R128 clean, pushed, live-equal qualification passed all `10/10`
checks at frozen source `b28090ba`. Its compact closure binds the 75-entry
source manifest and 9-file retained qualification tree, records zero models,
worlds, and solver steps, and authorizes exactly the declared sequential pair.
It does not establish behavior success, standing, repeatability, population
coverage, cross-engine recovery, or release authority.

That single authority was consumed from publication source `c2094719`. The
candidate completed 28 native steps with every in-run physical-invariant
receipt passing. The next application receipt retained eight enabled motors,
eight solver-coupled target writes, eight host writes/readbacks, and zero body
impulses, but inherited `physics_state_modified=false` from the shared command
writer. The solver-coupled consumer requires `true` for an active physical
application, so it rejected the receipt before step 29. No matched-zero world
or evaluator ran. R128 is therefore infrastructure-invalid with a partial
physical trace, not a behavior negative; R129 must change and qualify the
producer/consumer mutation semantics before opening successor physics.

### R24D129 separates constraint configuration from rigid-body integration

R129 leaves the qualified V6 portable policy and R127 native realization
unchanged and versions only their application receipt. The new semantics treats
an active HingeJoint3D motor enable/target write as mutation of the physics
object's constraint configuration. It does not claim that a direct rigid-body
impulse occurred or that the solver advanced: both remain independently false
until the caller performs the native step. A matched-zero disable/reset remains
non-actuating and therefore keeps the application mutation flag false.

This distinction is carried by
`godot_jolt_r24d129_solver_coupled_constraint_configuration_mutation_v1`.
Historical V10 still emits the exact R128 receipt. V11 wraps it, verifies the
known predecessor shape before changing any interpretation, and adds the
versioned scope fields. The production behavior consumer requires the new ID,
active/matched-zero mapping, eight host-configuration writes, zero direct body
mutation, and zero solver advancement.

The R129 zero-world test calls both producer versions and the real production
consumer over uninserted hinge objects. This gives direct coverage of the
failed seam without constructing or stepping a world; the retained R128 partial
trace already proves that the live path reached the same eight host writes.
Five mutations cover missing predecessor authority, wrong semantics, inverted
active and matched-zero mutation claims, and a fabricated pre-solver body
change. The sole official qualification passed all ten checks from exact
clean, pushed, live-equal source `6d444b72`, with six positives, five forced
failures, and zero physics. Its content-addressed closure opens only the exact
sequential R129 candidate-plus-matched-zero pair; it does not broaden the
architecture claim or authorize a rehearsal, extra seed, or retry.

The resulting native pair is valid-complete. The candidate performed 609
active pre-solver constraint-motor configurations and 4,872 target writes;
matched-zero performed none. Both arms retained the same versioned semantics
ID, zero direct rigid-body writes, and zero application-time solver
advancement, while the later native solve produced 905 fully checked physical
steps. This confirms that the receipt model describes configuration versus
integration without suppressing the actual solver-coupled trajectory.

Behaviorally, the candidate completed distal support and spent 600 phase steps
in `raise_body`. The center of mass rose as high as
`0.3324928283691406 m`, and the raised-body predicate was true on 579 steps,
but stable stance was never jointly true and the phase timed out. Matched-zero
timed out in distal support. R130 therefore begins with a zero-world
phase-localized predicate-overlap projection, not a rerun or speculative
physical tweak. Because the solver-coupled energy partition is incomplete,
the retained energy residual is recorded but is not complete energy authority.

### R24D130 makes progression dispatch an explicit production contract

The R129 physical closure above is retained unchanged, but R130 establishes a
later architecture correction. `prepare_context_v6` and the V6 native
application do not themselves activate R126 progression. That authority enters
the portable step only through `advance_behavior_v5`, whose internal
`use_r126_development_progression=true` path sends a V5 step request and
returns the separate development-progression receipt. The exact worker invoked
by R129 instead called `advance_behavior_v4`, which hard-codes that selector to
false. The qualified mechanics existed but were not integrated into the
production advancement call.

This source fact is decisive before any stance-predicate optimization. On the
immutable candidate's semantic step 59, the classification already satisfied
the qualified R126 input conjunction: raised body, respected joint limits and
actuator budget, exactly zero forbidden-contact impulse, and no cheat. V5 would
therefore change ownership to `stance_handoff`; V4 remained in `raise_body`.
The architecture can preserve all route-agnostic native measurements while
refusing to treat the later V4 trajectory as the answer to a V5 question.

R131 must remove this class of hidden selector from qualification. The
production worker will call one versioned dispatch surface; the zero-world
worker will invoke that same surface, prove V6 maps to R126/V5, and force wrong
controller/version mappings to fail. A V6 physical arm must also retain one
validated progression receipt for every observation, so a future result is
runtime evidence of the selected portable route rather than merely source
intent. These are integration and observability changes only: targets,
thresholds, phase predicates, evaluator, acceptance, and release authority do
not change.

### R24D131 binds versioned dispatch to runtime progression evidence

The qualified R131 implementation adds `production_advance_dispatch_v1` as
the sole production advancement selector.
It maps controller V6 to the qualified R126 `advance_behavior_v5` path and
maps historical V5 to `advance_behavior_v4`; callers do not select either
portable function directly. The returned production receipt names the
dispatch and selected route, and each V6 observation carries the underlying
R126 development-progression receipt. Arm and population validation require
those receipts to be exact and one-to-one with observations.

The native zero-world worker invokes that public production selector for both
versions. Six positive checks cover exact dispatch, consumer, receipt, and
population behavior; seven forced failures cover wrong context, route or
dispatch mutation, missing progression evidence, authority mutation, and
population omission. The sole official qualification from clean-pushed source
`48b10510` passed all 12 shared checks and opened no model, world, or solver
step. This qualifies the integration and observability route only; it does not
itself authorize physics or a standing claim. R132 supplies the distinct
physical declaration.

### R24D132 reopens only the exact bounded behavior question

R132 composes the already-frozen pieces instead of creating a new controller
or harness. The genuine Godot/Jolt worker, V6 controller, solver-coupled
constraint motors, R129 application-mutation semantics, seed, initializer,
candidate-then-matched-zero order, evaluator, thresholds, and horizon are
unchanged. The sole route delta from what physically ran in R129 is R131's
qualified production selector: V6 now advances through R126/V5, and every
observation retains its validated development-progression receipt.

The gate executes the exact R131 zero-world receipt through the
shared finite-behavior machinery, checks the real production wrapper's runtime
identity, projection refusal, missing-switch refusal, and qualified physical
path partition, and re-executes no historical closure audits. It declares one
two-world development pair with no repeatability or population inference. The
sole official qualification from clean, pushed, live-equal source `ad7c8fe7`
passed all 10 checks, retained a content-addressed 9-file tree, and opened zero
models, worlds, or solver steps. The closure authorizes only that exact pair;
it does not turn integration qualification into behavior evidence.

The consumed R132 pair exposed the precise missing interface contract at its
first development handoff. `step_v5` consumes energy-extended
`observation_v3`, so its portable step receipt binds that representation's
digest. `plan_stance_control_v3` still owns a source-bound `observation_v2`
collection and compares its digest with the handoff step. At native solver
step 59 those exact, intentionally different representations reached the
existing equality guard and produced
`DIGEST_INVALID:STANCE_STEP_OBSERVATION_BINDING`. This is a versioned interface
integration failure, not a threshold or native-physics failure. R133 must make
the step-to-stance representation explicit and version-consistent, preserve
the strict digest equality, and qualify the real handoff path at zero worlds
before a distinct physical question can be declared.

### R24D133 makes the V3-to-V2 stance seam explicit

`RecoveryStanceControlRequestV4` is the additive representation boundary.
It carries the source-bound V2 collection used by the stance planner, the V3
observation already consumed by the portable step, and the exact R126 energy-
partition authority and development-progression receipt. The planner validates
both observations, requires their shared base projections to hash identically,
recomputes the progression decision, and returns
`RecoveryStanceObservationBindingReceiptV1` with every full and projected
digest. The production Godot route recomputes that receipt before retaining it,
and the physical worker requires the complete retained population.

This does not collapse V2 and V3 into one ambiguous digest and does not weaken
the existing stance guard. The old V1-V3 request surfaces remain strict. The
only special case is the exact already-qualified R126 development handoff,
whose incomplete energy partition intentionally has legacy energy-safety
false; it cannot enter stable-stance, completion, acceptance, or release
authority. R133's finite-behavior declaration reuses the shared gate and
supervisor and changes no native physics. Its sole official clean-pushed
zero-world qualification passed all 10 checks, including the actual first-
handoff production path and its forced failures, with zero models, worlds, or
solver steps. The closure therefore authorizes one exact candidate-plus-
matched-zero development pair; it is interface qualification, not behavior
evidence or a standing claim.

The consumed R133 physical pair proves that binding survives the native route,
but exposes the next version seam in offline evaluation. Both arms reached
terminal route summaries with all 568 in-run invariants passing; the candidate
entered stance ownership and ended at `phase_timeout:stance_dwell`. Evaluation
V4, however, calls the legacy authority-free replay function. Its replay memory
therefore remains in `raise_body` after candidate observation 59 and rejects
the next stance-owned observation as `active_recovery_phase_owner_invalid`.
R134 must add a versioned evaluation request that carries and validates the
same R126 development authority for every replayed observation. Existing V1-V4
evaluation semantics remain strict and unchanged. Until that additive path is
qualified, the R133 pair is infrastructure-invalid/incomplete and supplies no
behavior verdict.

### R24D134 binds offline replay to the production development authority

`RecoveryEvaluationRequestV5` is the additive evaluator boundary. It carries
the exact `RecoveryEnergyPartitionAuthorityV1` used by the V6 production step,
validates that authority against every replayed V3 observation, and calls the
same internal development replay path. Evaluation V1-V4 continue to reject an
authority field and retain their historical authority-free semantics. The V5
authority can reproduce incomplete development progression only; it cannot
authorize stable-stance acceptance, completion, or release.

The Godot behavior route derives the authority from the first retained
candidate observation, requires both paired traces to share that source-bound
authority, and binds it into the evaluation receipt. The reusable production
selector maps controller V6 to evaluator V5 and all historical controllers to
V4. Its compact zero-world test reuses the existing worker fixture to exercise
both positive arms and fail-closed selector, route, trace, and authority
mutations. The exact R133 replay seam is also retained in Rust as a regression
that demonstrates the V4 refusal before demonstrating V5 acceptance. These
checks establish implementation conformance only. The prospective contract
supplies the distinct R134 declaration while reusing the shared finite-behavior
gate and serialized supervisor. Its sole official qualification from clean,
pushed source `c3d76583` then passed all `10/10` checks, `14/14` positives, and
`20/20` forced failures while opening zero models, worlds, and solver steps.
The immutable qualification closure qualifies the V6-to-V5 production
evaluator mechanics and authorized exactly one candidate-plus-matched-zero
physical development pair. Both native worlds then completed with all 568 in-
run invariants passing. V5 accepted the complete authority-bound traces and
returned a valid physics negative: the candidate completed stance handoff but
never satisfied stable stance during the full 240-step stance-dwell window.
The physical closure consumes the identity, adds no seeded ghost or physical
canary, and establishes no standing claim. The zero-world R135 diagnosis then
recomputes the complete stance-dwell predicate population: every non-energy
stable-stance component holds for 120 consecutive observations, while the
frozen energy component and explicit R126 completion authority each hold for
zero. The supervisor correctly accumulates zero formal dwell under incomplete
energy authority. R136 must therefore implement and qualify the missing
Godot/Jolt constraint/passive energy partition before a distinct physical
successor can be declared; no controller or threshold change is selected.

### R24D136 and R24D137 separate complete energy authority from behavior evidence

R136 adds a versioned Godot/Jolt v4 source for native constraint exchange and
combines it with the already-qualified R109 actuator-work partition. Complete
authority is structural: native joint motors are disabled, CCD and active soft
bodies are outside the supported subset, ordered rigid-body damping is
replace-mode zero, every solver source is current and finite, and residual
balancing is forbidden. The exact zero-world qualification closes the source,
partition, and refusal mechanics without constructing a world or making a
trajectory claim.

R137 is the production binding between that authority and the unchanged V6
recovery policy. A distinct adapter execution profile replaces the
incompatible native constraint-motor realization with R109 force/body-impulse
application while preserving portable targets and caps. The sampler receives
the exact predecessor application schema it already validates, plus retained
wrapper, route, mapping, and realization identities. Advancement and
evaluation select complete-energy V5 routes only for the exact tuple of V6,
R109 actuator mode, and the R136 energy route; every other cross-binding fails
closed. One compact zero-world worker covers these new seams. The exact
clean-pushed `a10c4806` freeze passed the sole official qualification with all
4 positives and 6 forced failures at zero models, worlds, and solver steps.
Its closure authorized one finite candidate-plus-matched-zero pair. Both arms
completed a subordinate raw negative with all 907 in-run invariants passing,
but the debug runtime emitted 130,608 Jolt velocity-access-right assertions at
two `MotionProperties` sites. The terminal native-health screen therefore
consumed R137 as infrastructure-invalid/incomplete and blocks behavior
inference. A distinct R138 runtime-source diagnosis and zero-world
qualification is required before further physics. Even a later valid finite
pair cannot by itself establish repeatability, a population, cross-engine
recovery, or release authority.

### R24D138 narrows the native correction to one access-right grant

The v4 solver-energy profile measures body kinetic energy on both sides of
position correction through Jolt's checked velocity getters. Debug Jolt
requires every job to declare that read. The upstream position job declares
velocity `None`, so R137's native-health screen correctly converted an
otherwise complete raw negative into an infrastructure-invalid result.

R138's additive v5 source delta changes the position job to velocity `Read`
and retains position `ReadWrite`. Assertions stay enabled, checked accessors
stay checked, and no physics equation, policy, threshold, or evaluator changes.
The reusable compact qualifier now optionally binds a complete dirty external-
dependency diff, repository patch chain, final source blobs, and retained
runtime without making later closure audits depend on the mutable checkout.
Its seven mutation controls cover upstream, diff hash/length, path population,
source blob, patch hash, and final patch-chain blob.

The sole official qualification from clean, pushed `4992db55` passed that
external-source control and a single Godot worker with five positives and ten
semantic mutations at zero models, worlds, or solver steps. Its closure binds
the exact runtime and 13-entry source manifest. Source proof alone cannot
demonstrate an empty native diagnostic stream, so the next physical
architecture boundary is a distinctly declared R139 minimal route ghost that
reaches position solving. A full recovery pair remains sealed until that
integration risk is observed cleanly.

### R24D139 reuses the shared two-step route boundary

The route worker now consumes the supervisor's declared controller and energy-
route identities instead of silently assuming its original V1 profile. The
legacy tuple remains exact; the only added tuple is V6 plus the R136 complete-
energy route plus the R109 effective-inertia actuator mode. The complete tuple
selects the R137 bootstrap, complete-energy observation composer, and wrapped
R109 application. Every other cross-binding fails closed.

Each complete-energy sample projects and retains the native solver-exchange
receipt only when constrained islands, velocity and position coverage, a
position phase, dynamic observations, completeness, source identity, and all
negative controls pass. The shared PowerShell supervisor separately binds the
same route identity and requires the typed engine-health screen. R139 uses one
world and two steps because that covers both the bootstrap solve and the first
post-application solve. The architecture adds no behavior evaluator or full-
horizon rehearsal at this boundary; the route result cannot claim recovery or
standing.

The sole official qualification from clean, pushed, live-equal `fe33086c`
passed this compact architecture at zero models, worlds, readbacks, or solver
steps. Its closure bound the exact 56-entry source manifest and authorized only
the predeclared one-world, two-step route.

The physical invocation exposed the missing zero-world seam: parsing the worker
and testing pure tuple selection did not execute
`prepare_complete_energy_context_v2`. At runtime, that call saw the v5
executable selected by the wrapper but the v4-only hashes retained inside
`recovery_capability_instrumented_v2.gd`, then failed closed before model
construction. R140 therefore moves the real SDK-instantiation and context call
into the zero-world gate; this is the reusable route policy for future runtime-
identity changes.

### R24D140 closes the inner/outer runtime-identity seam before a world

The complete-energy capability now admits the exact R138-qualified v5 console
and engine pair. Its telemetry profile remains v4 because the only v5 source
delta is the position job's debug velocity `Read` grant; channel identity,
measurement mapping, energy partition, and portable policy are unchanged.

R140's compact worker loads the native extension, instantiates the SDK, and
executes the real `prepare_complete_energy_context_v2` path. It checks both
inner executable hashes, the complete-energy validation and ten-channel
capability, supported-exact morphology compilation, the V6/R136/R109 route
tuple, and zero physical authority. Wrong controller plus mutated hash, route,
world count, and profile-selection projections all fail. The repeatable gate
passes four positives and all five forced failures at zero models, worlds, or
steps.

No shared qualification or physical-worker implementation changes in R140.
The sole official clean-pushed qualification at `ccac468e` passed and its
immutable 56-entry closure authorized the same shared one-world/two-step route
once under seed `212860496`.

That invocation from clean, pushed, live-equal `0ae6d526` constructed one
model and one genuine world, completed exactly two solver steps, passed both
complete-energy position-solver receipts, performed one R109 application, and
returned a clean typed native-health screen. The reusable physical-closure
audit recomputes the entire five-file retained population and CAS, complete raw
invariant population, ordered two-step native/portable route, coupled effective-
inertia projection, and live-authority projection. The campaign-specific audit
is only a thin identity binder over those shared mechanics.

R140 is therefore consumed as a valid complete integration-ghost positive.
The architecture has commissioned its exact v5 context and two-step native
route, including observation of zero fatal position-solver diagnostics during
those steps. Behavior evaluation was never invoked, so recovery, standing,
repeatability, population coverage, equivalence, acceptance, and release remain
separate. A distinct R141 finite behavior successor must pass a complete zero-
world gate before any further physics.

### R24D141 lifts the commissioned v5 route into the existing behavior harness

R141 adds no controller, adapter, worker, evaluator, or shared-audit behavior.
Its physical wrapper supplies a new gate identity to the existing serialized
supervisor and generic recovery worker, while its source audit is a thin binder
over `finite_godot_recovery_behavior_gate.py`. The worker continues to select
the R137 complete-energy progression and evaluation dispatches, R136 energy
partition, R109 effective-inertia application, and R133 stance-observation
binding.

The architecture binds two immutable edges rather than replaying their audits:
R137 records the complete raw trajectory rejected by native-health authority,
and R140 records the exact v5 two-step route positive. R141 preserves all
behavior inputs and replaces only the v4 runtime identity with R140's v5 pair.
The reusable zero-world gate executes the existing production-route component,
parses the actual new wrapper, verifies runtime identity and zero authority, and
forces the missing-switch refusal. It adds no new physical ghost or canary.

The clean-pushed `4d84b49c` freeze passed the sole official qualification. Its
closure binds the exact v5 runtime, 68-entry source manifest, 50-path physical
partition, nine retained files, and all generic worker/process controls while
recording zero physical authority during qualification. The published
authorization covers only one sequential candidate-plus-matched-zero
development pair, at most 2,400 combined solver steps, and one evaluator
invocation; broader recovery or release authority remains outside this
architecture boundary.

That physical pair from live-equal `8f11b826` completed both worlds and all 907
in-run invariants under a native-health-clean v5 process, but exposed a
supervisor/worker schema seam after raw serialization. The worker's stable
top-level route field is `energy_route_id`; the shared supervisor instead read
`recovery_energy_route_id`. Both sides carried the same required route value,
and all other binding and result-specific predicates passed, but the absent
supervisor field forced the terminal invalid.

The R141 physical closure therefore retains the complete subordinate raw
negative while refusing behavior inference and rerun. R142 must align this
field through a distinct, completely zero-world-qualified source boundary. The
correction belongs in shared supervisor mechanics and needs an exact positive
route projection plus a wrong/missing-route negative control; it does not by
itself require another full rehearsal world or physical canary.

### R24D142 makes raw binding one shared, directly exercised predicate

The shared supervisor now owns one `Test-R57RawBinding` conjunction used by the
post-process physical path and by a new non-physical control mode. The route
member is the production worker's stable `energy_route_id`; R142 does not add an
alias and deliberately rejects a legacy-only `recovery_energy_route_id`
projection. Missing and wrong route values also fail closed.

This closes the architectural gap that let wrapper parsing and component tests
pass without exercising the eventual terminal binding. The R142 wrapper merely
binds campaign identity and a control-receipt schema. The reusable Python gate
invokes the same wrapper mode and checks one positive plus three forced
failures, empty stderr, and zero model/world/step and authority counts. No new
GDScript worker, controller, evaluator, native executable, or physical canary
is introduced.

R142 directly binds the immutable R141 invalid closure, rather than replaying
its audit population or changing its interpretation. Until the prospective
source is clean-pushed and the sole official zero-world qualification passes,
the unchanged two-world behavior pair remains physically blocked.

The qualification passed once from clean, pushed, live-equal `c56ae194`. Its
closure binds the complete source/evidence population and confirms that the
actual wrapper reaches the shared predicate while every zero-authority and
mutation control passes. The architecture now permits the same serialized
supervisor to open exactly one candidate world and one matched-zero world under
the frozen authorization; no broader behavior or release authority follows.

### R24D143-R24D148 adds an independent Godot/Jolt discrete-staging seam

R143-R147 localized the complete-energy residual without rewriting a physical
result: the solver-coupled motor/constraint partition is commissioned, while
Godot's adapter-applied gravity force and subsequent position integration sit
outside the already measured constraint phases. R148 therefore adds one pure
adapter-side observer rather than another controller or native-engine patch.

For each semantic step, the observer accepts an ordered complete dynamic-body
population with source-measured pre/post positions and velocities, resolved
uniform gravity, the fixed solver duration, and the source-measured mass-weighted
position-constraint displacement. It computes:

```text
v_after_gravity = v_pre + gravity * dt
force_kinetic_exchange = sum(0.5 * mass * (|v_after_gravity|^2 - |v_pre|^2))
integration_displacement = sum(mass * (x_post - x_pre))
                         - position_constraint_displacement
integration_potential_exchange = -gravity dot integration_displacement
signed_discrete_staging_exchange = force_kinetic_exchange
                                  + integration_potential_exchange
```

The route validates this receipt against the unchanged R144 step identity,
replaces only R144's structural-zero staging fields, advances one content-
addressed append-only accumulator event, and passes the measured signed value
into the existing portable V3 staging channel. It never derives staging from
the whole-step mechanical change, residual, threshold, constraint exchange, or
behavior result; omission remains visible as a nonzero residual. Older routes
continue to refuse nonzero staging.

The clean-pushed R148 qualification proves the equations and source/mapping
refusals with `13` positive and `15` forced-failure cases over a 47-entry frozen
manifest, at zero models, worlds, native readbacks, or solver steps. The R148
context deliberately refuses physical world construction. R149 must connect
the existing native sampler to this seam and traverse one world for two outer
steps before the architecture may call the live transport commissioned. That
ghost validates construction, capture ordering, accumulation, portable binding,
retention, finalization, and native health—not recovery success.

### R24D151 consumes the commissioned staging seam through shared behavior machinery

R150 has now commissioned the R148 seam through the production GDScript,
GDExtension, Rust core, native-motor application, and second collection. R151
therefore does not add another route harness. It layers a V7 behavior context
over the content-addressed R150 context, selects a separately versioned complete-
partition authority, and routes the existing V6 portable step and evaluator
through the same shared finite-behavior supervisor used by R146.

The R148 authority remains immutable and correctly refuses a live physical
context. R151 reconstructs the exact R148 zero-world predecessor, verifies its
digest against the retained context ancestry, and only then reuses its complete
source-mapping validation. The emitted R151 authority additionally requires the
R150-commissioned context and exact R148 energy profile. Cross-profile,
uncommissioned-context, and mutated context/dispatch/application/evaluator
inputs fail closed.

This keeps campaign code compact: the Python source audit and qualification-
closure files are thin bindings over shared gates; the physical wrapper is a
declarative parameter binding over the existing serialized supervisor. The
contract declares one current zero-world worker, `7` positives, `6` forced
failures, zero historical audit re-executions, zero full seeded ghosts, and zero
bespoke physical canaries. The sole official qualification passed from clean,
pushed, live-equal `f7f0c3e6` with all `10/10` shared checks green over 88
source-manifest entries and 65 qualified physical paths.

The subsequent R151 attempt exposed one unqualified producer/consumer seam.
`initial_behavior_application_discrete_staging_complete_energy_v1` emits the
R148 route and mapping, but `sample_native_step_v1` still validates every
solver-coupled application against R144 constants. After one genuine solver
step, that branch refused provenance before constructing a native sample. The
architecture therefore treats R151 as consumed integration-invalid evidence:
no in-run invariant or behavior inference is available, and R152 must make the
native sampler's route-aware provenance rule explicit and zero-world testable
before another physical world can open.

### R24D152 makes application provenance an explicit shared projection

The native sampler no longer infers that every solver-coupled complete-energy
application must carry the R144 outer route. It first evaluates one pure
provenance projection shared with zero-world qualification. The legacy branch
still requires and emits R144. The discrete-staging branch requires R148 outer
route and mapping, the R144 predecessor route, the R151 commissioned authority,
and the R152 provenance profile while preserving the R144 partition rule,
actuation realization, and bootstrap/active mutation semantics.

Only the outer command application, native application receipt, and native
source trace acquire R152 schemas. They retain both outer and predecessor
identities so an auditor can distinguish observation transport from underlying
solver partition. The R148 component wrapper continues to contain the unchanged
R144 energy, component, motor-work, and partition receipts; no physical quantity
is relabeled.

The shared two-step route worker selects the R152 context and production
discrete-staging application wrappers only when the gate identity is exactly
`QSDK-R24D152`; older gates keep their prior paths. The generic physical-closure
auditor now supports this declared outer-to-predecessor projection while its
existing R150 profile still passes against the retained result. A thin R152
contract and wrapper reuse compact qualification and serialized supervision.

Two steps—not a full world horizon—are required because the first native sample
consumes bootstrap application and the second consumes active application. The
route proof retains complete in-run physical invariants and native health but
has zero behavior-evaluation, recovery, acceptance, or release authority.

The clean-pushed R152 zero-world qualification passed at `6e8cb6c0`. Its
content-addressed closure binds the 76-entry source manifest and authorized one
world with at most two solver steps. The qualified physical partition remained
unchanged by the closure and live-authority publication commit. The sole route
identity then completed from `6163caba`: both outer provenance receipts and
both predecessor partition receipts passed, so R153 may inherit the commissioned
route but must separately declare and qualify any behavior question.

### R24D153 layers finite behavior identity over the commissioned route

R153 adds a V9 behavior context only after reconstructing and validating the
exact R152 V8 route-aware application context. The V9 layer binds the finite
R151 candidate-plus-matched-zero identity; it does not alter the R148 energy
mapping, R151 complete-partition authority, R152 application-provenance
profile, or R144 solver/motor partition beneath it.

The shared behavior machinery accepts two exact context families: the original
R151 V7 context and the R153 V9 context. R151 continues through its historical
application and receipt validation. R153 alone selects the route-aware
bootstrap and active application wrappers, then requires the R152 native
application and source-trace schemas through an additive receipt validator.
Every R153 native step therefore binds the outer R148 route and mapping, R144
predecessor, R151 authority, R152 provenance profile, and unchanged partition
before the observation may enter progression or evaluation.

This is an extension of shared production machinery, not a campaign-specific
parallel harness. The campaign Python files remain thin bindings over the
generic finite-behavior source and closure audits, and one compact zero-world
worker exercises the actual selector and application functions. Historical
R151 and R152 paths remain separately executable and green. At the prospective
freeze, physical construction remained refused pending qualification.

The sole qualification subsequently passed from clean, pushed, live-equal
`1b788176`. The published closure turns on only the existing qualified physical
projection: one exact candidate-plus-matched-zero pair, two sequential worlds,
at most 2,400 outer steps, and one evaluator invocation. It does not alter the
implementation tree qualified at the freeze or grant acceptance, population,
cross-engine, or release authority.

The sole physical R153 attempt then reached the intended native route for two
solver steps. Bootstrap and active sampling both produced complete native
samples with green underlying energy-partition, route-provenance, discrete-
staging, and native-health flags. The first behavior invariant was retained;
the second was rejected because the shared behavior validator compared the
adapter's cumulative discrete-staging event count against the per-observation
constant `1`. At semantic step `2`, the producer correctly reported `2`.

R153 is consequently an infrastructure-invalid/incomplete result rather than a
behavior result. The defect is in consumer count semantics, not in the V9
context, R152 provenance route, R148 staging observer, R144 partition, or
native physics. R154 must introduce a versioned accumulator-aware validator and
zero-world coverage for successive counts `1` and `2` plus crossed-count
refusal. The immutable R153 attempt cannot rerun, and no full seeded ghost or
extra physical canary is presumed necessary for that source correction.

### R24D154 makes cumulative-count validation an explicit context capability

R154 derives a V10 behavior context from the exact R153 V9 context and binds
the predecessor digest before changing the construction gate. It adds one
capability flag and one validator profile ID; all route, application, energy,
controller, and evaluator identities below that layer remain unchanged. The
route-aware production wrappers accept the V10 context only through its exact
binding, while the V9 branch remains separately exact.

The behavior worker now dispatches staging-count validation by context. Legacy
and R153 contexts retain the prior one-event observation rule. Only the exact
R154 context requires the cumulative value to equal its positive semantic step
and emits a V2 invariant receipt carrying the validator profile. Non-staging
routes continue to require zero. The count predicate is pure and is the same
function called by the full in-run receipt validator, so the compact zero-world
worker can exercise the failed production branch without constructing physics.

The direct control covers successive steps `1` and `2`, stale and future
counts, crossed gate/profile/selection identities, nonpositive steps, and the
non-staging zero rule. This is a versioned consumer correction rather than a
new physical observer, threshold, or parallel harness. The sole clean-pushed
qualification passed at freeze `3d4a0bdf` with nine retained files and zero
physical execution. Its content-addressed closure now authorizes the exact R154
pair without a full seeded ghost or additional physical canary; it authorizes
no broader recovery or release claim.

That pair subsequently completed from clean, pushed, live-equal `dfafa4b2`.
Both worlds, `905` native solver steps, raw binding, native health, and every
in-run invariant passed. The candidate left `establish_distal_support` but
timed out after `600` `raise_body` steps; `raised_body_gate` was true on `579`
observations while `stable_stance_gate` was never true. Matched zero remained
in distal-support establishment and timed out after `268` steps. R154 is thus a
valid complete finite behavior negative, and its context/validator route is
qualified on the complete production path. The next architectural action is
offline phase-localized diagnosis; no R154 rerun or new physical campaign is
authorized by this result.

### R24D155 separates physical identity from rotational staging coverage

The reusable retained-energy projection now compares a staging successor as a
pair of immutable traces rather than replaying either physical campaign. For
each arm it requires exact initial state, step count, selected physical
projection, and every non-staging numeric V3 component. It then verifies the
algebraic identity `successor residual - predecessor residual + added staging`
under a forward binary64 operation bound. Crossed root, physical state,
non-staging ledger, and matched-zero-control mutations fail closed.

R146 and R154 satisfy that contract across all `905` steps. R154 did not alter
physics; it exposed one additional measured channel. Within R154, the exact
candidate/zero prefix ends when active constraint motors begin on step 29. The
zero tail remains essentially flat while active support and raise-body phases
accumulate the remaining discrepancy. Since the exact-authority supervisor
requires both raised-body geometry and energy safety, zero of 579 raised-body
samples can enter stance handoff.

The next architecture seam is an observation boundary, not yet a controller
revision. Mechanical energy includes rotational kinetic energy through the
body's current world inertia. The R148 observer covers linear gravity-force and
translation-potential staging only. R156 must identify the exact native
orientation-integration boundary and decide whether current telemetry can bind
its independent pre/post rotation, angular velocity, and inertia state or a
versioned native extension is necessary. Whole-step residual, threshold, and
behavior outcome remain forbidden inputs. No physical work is open.

### R24D156 selects a native, coverage-counted rotation boundary

The exact seam is `PhysicsSystem::JobIntegrateVelocity`: velocity constraints
and clamps finish, `Body::AddRotationStep(omega * dt)` updates orientation, and
only then does Jolt translate the body and enter CCD/position correction. An
outer adapter pair cannot separate those later stages. The v6 delta therefore
reuses the native v4 kinetic-energy function on the same body directly before
and after the rotation call.

Instrumentation is batched rather than per-body synchronized. Each integration
job accumulates locally, then merges once through the existing telemetry mutex.
`JobPreIntegrateVelocity` freezes the expected active-body population. The v2
snapshot is complete only when observed equals expected, dynamic count is
positive, invalid count is zero, and signed exchange is finite. This preserves
the meanings of v4's existing solver-observation counters and makes omitted,
duplicated, nonfinite, or partial rotation coverage invalid rather than zero.

The engine-neutral reference observer accepts ordered source boundaries only
and rejects residual or threshold inputs. Its zero-, principal-, and off-axis
controls prove the ideal update is energy invariant because the left rotation
axis is world angular velocity itself. Consequently v6 is a diagnostic channel,
not a presumed correction. R157 must prove compilation and binding at zero
world; only a later minimal native smoke can quantify float32 behavior. No
portable-ledger or controller mutation follows from R156 alone.

### R24D157 binds build provenance and v2 consumption separately from physics

The reusable compact Godot qualifier can now bind exact retained build
artifacts and required completion markers. R157 uses that shared surface for a
full clean native build transcript, the resulting console/engine pair, and the
autoloaded host-extension dependency. The exact external source diff and v6
patch-to-final-blob chain remain independently checked.

`recovery_solver_energy_exchange_v2.gd` is the versioned pure consumer. It adds
rotation exchange to the prior joint, contact, position-kinetic, and position-
potential sum only after exact schema/profile, current sequence, complete
active-body population, finite terms, native completeness, source-measurement,
and no-residual-source checks pass. The R136 v1 consumer is untouched.

The zero-world worker proves compiled method registration, invalid-RID refusal,
one synthetic complete input, and the targeted mutation population. It does not
route synthetic data into production and does not pretend a native step occurred.
Production adoption and actual field population remain an R158 integration seam
with one world and no more than two outer steps by default.

### R24D158 isolates native field population from recovery behavior

R158 adds one reusable compact native-observation supervisor and closure audit
around a thin campaign binding. Campaign physics stays in a declarative
fixture and dual-mode worker; the shared supervisor owns repository equality,
authorization, operation locking, exact evidence retention, supervised Godot
termination, engine health, and no-retry terminalization. The shared compact
zero-world qualifier selects a `native_observation_smoke` profile rather than
copying a campaign-specific harness.

The physical architecture is intentionally one-way: create one isolated world,
activate one off-axis anisotropic pinned body, wait for two completed native
steps, consume the current v6 dictionary after each, disable the physics server
before an unreported third solve, and retain both full dictionaries plus their
per-step invariant receipts. No portable observation, policy, command,
actuator, recovery evaluator, or acceptance predicate enters this path.

The clean, pushed, live-equal `07172a2d` source has now passed its sole official
zero-world gate and missing-switch refusal. Its committed closure authorizes
exactly one world and two steps once; the physical identity remains unattempted.
This architecture can prove that the compiled telemetry field populates and
remains internally complete for two consecutive steps; it cannot prove a
nonzero effect, explain R154, or establish standing.

### R24D159 makes the evidence destination an explicit route dependency

Pre-physical inspection exposed one missing declarative dependency: R158's
shared supervisor reads `physical_runner.evidence_directory_name`, but the
contract did not supply it. Its empty-string cast aliases the campaign root to
the durable evidence root and triggers the existing-directory refusal before
an attempt. This is a source-level launcher invalidity with zero physics, not a
native-observation result.

R159 retains the R158 physical worker intact and adds an exact, safe child
directory to a distinct contract. The compact qualifier validates the field's
shape, while physical mode requires it before authorization use or evidence
creation and verifies its resolved parent. The supervisor now carries separate
qualification and physical-question gate IDs through preflight, attempt,
terminal, summary, and closure audit, allowing a route-only successor to reuse
an unattempted worker without obscuring provenance.

The architecture change adds no new physical rehearsal. Its repeatable
development gate passes the same zero-world worker and missing-switch refusal;
the sole official qualification also passed from clean pushed freeze
`0b3ec11c`. Its committed closure authorized the unchanged one-world/two-step
observation exactly once.

That invocation exposed a second, independent lifecycle seam. `world_3d` is the
Viewport's explicitly assigned custom-world property; enabling `own_world_3d`
does not make that property the safe effective-world accessor. The R159 worker
reached its first observation statement and dereferenced
`viewport.world_3d.space` while `world_3d` was null. No raw or report receipt was
available before the ensuing timeout, so the architecture must not infer exact
world or solver counts from source order alone.

R160 therefore owns a narrow reusable correction: resolve the effective world
through the inserted `Node3D.get_world_3d()` or equivalent Viewport lookup,
validate the resulting World3D and space RID before the first step, retain that
RID for both reads, and increment completed-boundary counters before every
possible terminal emission. A missing world or invalid RID must produce an
orderly structured invalid result instead of an engine timeout. The R159
four-file closure remains immutable and no behavior semantics change.

The implemented R160 seam uses `child.get_world_3d()` only after the viewport
subtree has entered the SceneTree. It validates `World3D.space` once before the
first physics boundary and carries that exact RID through the two native reads.
Each sample rechecks the child/world/RID relationship in-run. Null-world and
invalid-RID branches disable the physics server and emit a structured invalid
receipt rather than relying on a host timeout.

The lifecycle counts are ordinary declarative contract fields. The shared
supervisor and closure audit enforce the source-successor ID, expected world-
binding fields, 15-check invariant receipt, exact completed-step count, and one
terminal physics-server deactivation. The shared qualifier's generic source-
text controls bind the changed code shape at zero worlds; no R160-specific
audit body or physical rehearsal is introduced. Official qualification and
all physical authority remain pending the clean pushed freeze.

The clean, pushed, live-equal `a383f088` freeze has now passed that sole
official gate. Its closure content-addresses 19 source blobs, both declarative
source controls, and three retained qualification files, then passes the shared
closure verifier. The publication layer may therefore supply this exact
closure to the R160 supervisor as authority for one world and two completed
steps. The worker has not been invoked physically, so field population and all
downstream recovery semantics remain unobserved.

That one invocation has now completed validly. The dynamic child remained
registered to the same effective World3D and valid space RID across both native
reads; explicit counters establish two completed steps and one terminal server
deactivation. The shared supervisor accepted one raw receipt, a full report,
valid supervised termination, and clean engine health. The closure layer now
also verifies the attempt record, independently reparses the raw receipt, and
content-addresses the complete five-file directory rather than trusting only
the report/terminal projection.

The architecture has therefore crossed the missing-observation seam: v6 emits
finite current complete values in native physics. It has not crossed the
recovery-adoption seam. R161 must remain pure analysis over the frozen R154 and
R160 evidence and may only determine whether a separately qualified integration
question is warranted; it may not rewrite the existing energy predicate or
infer behavior from this two-step fixture.

## R24D161 recovery-adoption architecture decision

R161 closes the adoption decision without adding a campaign-specific helper.
The existing digest-bound engineering-diagnosis mechanism verifies the exact
R154/R155/R157/R160 JSON identities and selected fields, the current production
recovery source blob, and the qualified v2 consumer source blob. Historical
closure logic is not replayed, and all physics counters remain zero.

The architecture explicitly separates *measurement exists* from *measurement
scale transfers*. R160 proves that v6 populates a finite, current, complete
rotation-integration field on its declared fixture. It does not provide a
mapping from that fixture to R154's different recovery bodies, motions, and
905-step horizon. Consequently the two observed magnitudes and their signed
cancellation cannot support an omission margin, residual correction, or
behavior forecast.

The integration seam is nevertheless concrete. `recovery_native_world_v1.gd`
still calls `native_solver_energy_exchange_contract_v1`, whose signed exchange
omits the new field. `recovery_solver_energy_exchange_v2.gd` is already
qualified and adds the independently measured rotation term while preserving
residual-input refusal. R162 must give that v2 selection a new recovery-route
authority and carry its provenance through the existing constraint-exchange
and complete-energy receipts. It must preserve legacy selectors and fail closed
on missing, stale, incomplete, or crossed telemetry. This source integration is
zero-world work; it grants no physical or standing authority by itself.

## R24D162 versioned recovery-ledger selection

R162 crosses the recovery-adoption seam in source without opening the physical
boundary. `prepare_complete_energy_context_v11` binds the retained native-v6
pair, the rotation-aware capability variant, the qualified v2 consumer schema,
the R161 diagnosis digest, and the existing R148 route plus R144 partition rule.
The context explicitly carries `physical_world_construction_authorized = false`;
the native world builder independently refuses that context before constructing
a viewport, node, model, or world.

`sample_native_step_v1` now dispatches through two versioned selectors. An exact
R162 context consumes telemetry v2 and propagates rotation identity and value
through the solver receipt, constraint partition, source trace, energy receipt,
component receipts, and native measurement result. Its 14-term partition
reconstructs the raw solver exchange with rotation exactly once, then removes
the current-step native motor population exactly once. Legacy contexts still
dispatch to the unchanged telemetry-v1 consumer and R144 13-term partition;
partial R162 fields never fall back silently.

The clean official gate at `76b70f46` verifies those call sites and exercises
six positives plus ten refusals with every physical counter at zero. This is
measurement completeness, not evidence that rotation is large, causal, or
behavior-improving. A distinct R163 zero-world design must define any future
production-path ghost and its adequacy before physics can be authorized.

## R24D163 content-bound rotation-aware production route

R163 adds `prepare_complete_energy_context_v12` as the sole construction
authority for the rotation-aware route ghost. The context binds the exact
R162 closure and ledger, the v6 collector/runtime tuple, the unchanged R148
route and mapping identities, and the R152 application-provenance boundary.
The route maps the original rotation-aware source receipts and their legacy
compatibility projections by digest; crossed source, partition, gate,
collector, or runtime identities refuse instead of falling back.

The zero-world worker reaches the actual portable collection and planning APIs
without constructing a model or world. Six positive cases cover construction,
blueprint compilation, production collection/planning support, predecessor
binding, and rotation-aware mapping. Seven negative cases prove fail-closed
behavior across missing authority, stale partitions, crossed mappings, wrong
gates, and legacy collector/runtime identities. The shared supervisor adds
runtime identity, raw binding, and missing-switch process controls.

The audited closure at freeze `26a0fab9` exposes a deliberately tiny physical
boundary: one development world, one model, two outer solver steps, two
collections, two plans, one application, and no behavior evaluator. That
boundary is sufficient to exercise construction, stepping, finalization,
retention, publication, and evaluation of route completeness; it cannot prove
recovery behavior, energy significance, R154 causation, or standing.

## R24D170 initializer-receipt retention boundary

R170 exposes a distinction between runtime state continuity and publishable
source provenance. The R168 native initializer successfully creates sequence-
zero transport state and returns a receipt for its nine inactive body
readbacks. Later callbacks can therefore advance contiguous pairs and retain
valid terminal sequence, pair-count, and revision state even if the returned
initializer receipt itself is discarded.

That runtime success is insufficient for the evidence architecture. The
behavior worker publishes initializer provenance from
`model["boundary_transport_initializer_receipt"]`, but the R170 source never
assigned the initializer return value to that key. Its two arm outputs are
empty dictionaries and the aggregate readback count becomes `-2`. The
independent closure audit consequently preserves the supervisor's complete
positive terminal observation while rejecting it as a publication-valid
complete behavior result.

R171 is the narrow, distinct zero-world plumbing successor. Its implementation
persists a deep copy of the already-returned receipt under the exact model key
consumed by the behavior worker. Before physics activation, an exact validator
requires the R168 17-field schema, origin gate, nine inactive readbacks,
attempt/model identity, cached boundary identity, and sequence-zero transport
state. Missing or malformed receipts, crossed identities, nonzero initial
revision, and already-active physics are refused; a failed internal retention
check removes the receipt, initialized flag, and transport state.

The sole official zero-world qualification passes from clean, pushed,
live-equal freeze `5cc96023`: four positive properties and twelve forced
refusals over 22 frozen source paths. One positive reads the production worker
source and proves that the exact retention-validator call precedes its sole
physics-activation call. All model-construction, native-readback, world,
evaluator, body-write, and solver-step counts remain zero. R171 does not
declare a physical question or authorize a new world, and it changes no
transport semantics, controller behavior, threshold, evaluator, morphology,
seed, horizon, or consumed result. A distinct R172 declaration is required
before any physical successor can be considered.

## R24D172 distinct initializer-retention behavior context

R172 layers a new content-bound context over the exact R170 behavior context.
The new context stores the canonical digest of that R170 predecessor, the
immutable R170 physical-closure digest, and the immutable R171 qualification-
closure digest. Its validator first checks the R172 schema, gate, finite-
behavior profile, and closure identities, then reconstructs the R170 context
and passes it through the unchanged R170 validator. This makes the new gate
identity explicit without duplicating or weakening the earlier source-
provenance chain.

The physical worker recognizes that context throughout route-aware
application, accumulator validation, rotation-aware ledger selection, and
native source-trace validation. Its R171 retention validator still runs after
inactive initialization and before the sole physics-activation call. The
behavior controller, transport state machine, observer, energy ledger,
threshold, margin, evaluator, morphology, seed, arm order, and horizon do not
change.

R172's development worker passes 13 positive properties and 15 forced
refusals without physical execution. The sole official zero-world
qualification then passed from clean, pushed, live-equal source commit
`a70b44f60aff7609aac91d81c43a287ab8d13aaf`. Its retained preflight parsed the
production worker once and re-established the exact runtime, controller,
energy route, R162 ledger, R165 source validator, R168 transport, R171 receipt
retention, and R172 profile identities without opening physics.

The passing closure authorizes the declared two-world finite population once.
The runtime must still recheck that committed closure and qualified physical
source under the global operation lock before activation. Authorization does
not relax the initializer-receipt pre-activation validator, permit a repeated
identity, or grant behavioral, physical-acceptance, or release authority.

The sole R172 physical invocation exercised that architecture completely.
Each arm preserved its original initializer receipt under
`boundary_transport_initializer_receipt`; both receipts validate sequence and
state revision zero, nine native body reads, and inactive physics at capture.
The candidate transport then advanced transactionally through 240 committed
boundaries and portable `complete`, while matched zero advanced through 268
committed boundaries before its frozen phase timeout. The per-arm terminal
state revision, cached sequence, and accepted-pair count equal the arm's outer
step count, and their total equals the 508-step raw population.

The result is a valid exact-nominal Godot/Jolt development positive. It
validates the corrected retention path in a complete production trajectory;
it does not imply that receipt retention caused the physical completion, nor
does it establish repeatability or equivalence. The architecture now routes
to a zero-world R173 three-engine evidence conjunction decision. No additional
physical route is active.

## R24D173 finite three-engine decision architecture

R173 closes the evidence-composition layer without introducing another
controller, adapter, world, or evaluator path. The decision binds the exact
immutable R44 MuJoCo, R55 Rapier/Parry, and R172 Godot/Jolt closures and checks
their common canonical task and evaluator-gate semantics directly. All three
candidate arms reached portable `complete`; all three matched-zero arms failed;
and all three retained evaluators classified the paired execution as a valid
physical-development positive under the same frozen threshold authority.

The architecture deliberately keeps implementation identity separate from
gate-semantic identity. R44 and R55 used recovery controller V1, whereas R172
used V6, so R173 does not claim controller equality, trajectory equality, or
native-effect equivalence. It proves only the finite advertised-engine
conjunction required by `QSDK-R24` and bounded milestone `SDK1-M19`. The scores
advance to `12/25` and `12/20`, respectively; repeatability, population,
arbitrary-morphology, physical-acceptance, and release claims remain closed.

The R173 audit constructs zero models or worlds, executes zero solver steps,
and rejects 14 mutation or over-promotion cases. The architecture now routes to
`QSDK-R01`: refresh the current clean-source portable core, C ABI, Python, and
package proof without opening physics.

## QSDK-R01 two-stage portable API proof architecture

`QSDK-R01` now has an explicit two-stage structure. The source stage reads one
versioned contract and one packager-owned inventory. It parses the Rust FFI,
public C header, and Python `ctypes` declarations into a common primitive type
model; requires exact agreement for all 58 symbols; builds the release dynamic
library; loads and invokes every symbol through Python as a real foreign-
function consumer; and runs the Rust, Python, malformed-request, caller-owned-
buffer, and mutation suites. The retained source report also requires clean
`HEAD` equality with local and live `origin/main` and must live outside the
source repository.

The package stage is intentionally stricter and remains unexecuted. It accepts
only a clean-room candidate produced under a content-addressed readiness report
for the same source commit and contract. Before building, it requires the exact
manifested file population plus the non-distribution marker, rejects repository
metadata, extra files, symbolic links, reparse points, and library overrides,
and requires authorization and output reports outside both package and source.
Cargo's target directory is forced inside the package; all checks use that new
library; packaged source hashes are checked again after execution. This keeps a
future clean-room pass from silently borrowing source-tree code or binaries.

Clean source `5fe95a60` passed the first stage and retained a report at SHA-256
`ed7091fa8dbf69dcb1b7df1e361b7a373a2d4957c620de7df26ce8b5ba2220f5`.
The architecture does not collapse the two stages: source conformance remains
true while clean-room validation, `QSDK-R01`, and `SDK1-M01` remain false. A
separate bounded candidate-authorization decision is the next M01 dependency;
the full release contract is unchanged. No physics path participates in either
stage.

The later 17+3 SDK1 decision exposed one missing connection: its bounded
readiness compiler could eventually authorize an SDK1 candidate, but the
packager and package-side consumers recognized only the full-program schema.
Implementation `fa3e6aae` adds an explicit, mutually exclusive
`Sdk1CleanRoomCandidate` path and the distinct
`sdk1_clean_room_conformance_candidate` artifact role. It does not relax the
full candidate. Both paths still bind clean source, the release contract,
support matrix, exact inventory, and an external readiness receipt; the SDK1
path additionally binds its mapping and exact 17 passed plus 3 still-missing
milestone partition.

One shared validator now serves the source-side packager and package-side R01
and R16 consumers. It rejects any non-passed prerequisite, non-missing package
validation, blocker, changed deferred-gate population, publication/release
claim, dirty or mismatched source, or authority hash mismatch. The packager
then reruns the live SDK1 compiler before copying a byte. Package manifests and
warning files carry both the exact role and `bounded_sdk1_17_plus_3` scope so a
bounded artifact cannot masquerade as the full-program candidate.

This work also corrected a prospective package-side R01 hash error: the old,
never-executed branch compared the readiness report's release-contract hash to
the portable-API contract file. The runner now verifies the packaged release
contract and support matrix themselves. The bridge audit accepts one synthetic
shape solely as a validator test, rejects 13 mutations plus forged-live-source
and conflicting-mode cases, and creates no package. Clean source `fa3e6aae`
then passed all eight real API cells over 1,467 files / `31,157,392` bytes.

This is preparation, not candidate evidence. `M07`, `M14`, and `M20`
still block the one artifact that must answer R01/R16/R20 together. R01 and M01
remain false, scores are `14/25` and `14/20` after M08, and every bridge qualification
physics counter is zero.

## QSDK-R13 exact-finite Godot/Jolt envelope composition

M08 adds no physics implementation. It is a release-ledger composition layer
over four immutable evidence slices: the older C2-C5 adapter/mechanics
transcript, R05E exact-point selected-policy walking, BW5C reference-body
material walking, and the separate bounded turning and recovery decisions.
The executable audit verifies every retained file by byte length and SHA-256,
verifies repository evidence by its parent Git object, checks the exact facts
used from each result, and rejects 25 mutated overclaim forms.

The central architectural rule is a tagged union, not a product. R05E's twelve
one-axis-at-a-time bodies were tested at `godot_jolt_bw5c_mu095_v1`; BW5C's
four nonzero material profiles were tested on the reference body. A request in
either measured slice can be supported. A cross-slice body/material
combination is not supported merely because both coordinates appear somewhere
in the ledger. The adapter must return explicit unsupported/OOD status unless
a later prospectively frozen campaign measures that combination.

Movement capabilities remain similarly typed. R23D78 supports basic turning
at exact seed 23199. R173 supports an exact nominal ventral-prone-to-stance task
through the separate V6 recovery controller. Neither is silently attributed to
the BW5R-B straight-walking controller, and prone-to-standing is not treated as
evidence for a kick transition, continuous force awareness, general self-
righting, or M07 external-push recovery.

The support matrix may therefore advertise the complete *bounded SDK1*
Godot/Jolt envelope while keeping its global release flag false. The legacy C6
selection and C6R held-out populations remain negative, formal cross-engine
equivalence remains false, and no physical-acceptance or publication authority
is created. QSDK-R13/M08 moves the ledgers to `14/25` and `14/20`; it opens no
model or world and authorizes no successor run.

## QSDK-R10E-L3 producer-faithful measurement and terminalization architecture

R10E's production route has now exercised both authority lanes. The L2
development graph ran one matched pair through source qualification, committed
stage and authority, worker construction/stepping, deferred trace
materialization, evidence retention, pair evaluation, terminal report, and
closure. Both worlds were evidence-valid finite negatives. That result proves
the route can close a negative without swallowing it; it does not turn the
development seed into a held-out behavioral claim.

The separate held-out graph consumed two of six worlds before its first pair.
Its push receipt demonstrated an architectural distinction that the earlier
validator blurred:

```text
producer inside Godot                    consumer after JSON export
---------------------                    --------------------------
binary32 Vector3 components              binary64 scalar components
          |                                        |
          v                                        v
Vector3.length() -> stored magnitude     sqrt(x*x + y*y + z*z)
          \__________________ compared __________________/
                     fixed 1e-9 allowance
```

Those are two legitimate calculations but not the same operation at the same
precision. Their `2.4045559432472885e-9 m/s` difference rejected the otherwise
linked receipt. Increasing the old allowance after seeing that value would make
the consumed outcome help choose its own acceptance boundary. L3 instead
version-separates the consumer and replays the declared producer operation:

```text
exported scalar components
          |
          v
one Godot Vector3 construction
          |
          v
Vector3.length() -> producer-faithful replay
          |
          v
binary64 transport-only comparison to stored magnitude
```

That is the sole permitted vector reconstruction in the v2 validator. Raw
forward/lateral task axes, their trace links, task impulse, and world impulse
remain scalar arrays checked in binary64. The validator exposes the replay
operation, both diagnostic norms, stored magnitude, comparison allowance, and
explicit `effect_floor_changed=false`, `behavior_threshold_changed=false`, and
`observed_l2_outcome_used_to_select_allowance=false` fields. The old v1 source
remains byte-identical so the L2 failure can always be reconstructed on its own
terms.

Terminalization is independently total over incomplete populations. The
supervisor's outcome function now allows empty `Cells` or `Pairs` collections,
but an empty or partial population can produce only
`invalid_or_incomplete_no_behavioral_conclusion`. It cannot become execution-
valid, complete, evidence-valid, or behavior-passing. If a worker fails, the
terminal failure records the cell identity and primary worker failure before
any later supervisor exception is appended. This ensures the reporting layer
cannot erase the causally earlier evidence failure.

Authority routing is asymmetric by design. The historical L2 development role
is refused before its old authority could be loaded. Current physical authority
may target only a separately qualified L3 held-out identity. Stage v3 binds the
exact L2 failure closure as a consumed, non-rerunnable prerequisite; authority
v3 binds that stage, current implementation receipt, runtime identity, and the
same failure-closure digest. A new campaign cannot resume at world three: its
authorized identity and expected order are all six cells from the beginning.

The recursive v4 dependency graph contains 91 paths, including both validator
versions and the immutable L2 failure closure, at path-set SHA-256
`348c65a448016b769cc13f3c23336a295a03990ef39e40a8418650a2d9667f67`.
Its current development audit reopens all nine retained L2 files and the exact
four-commit lineage, tests the old and new numeric dispositions, tests empty-
population closure shapes, and verifies both historical-rerun and current-
authorization bypass refusals. All audit-side model, world, native-read, and
solver-step counts are zero.

This architecture is implemented but not yet official physical authority. The
required order is clean-pushed L3 source, one official held-out qualification,
one freeze-only v3 child, one authority-only v3 child, committed-graph check,
then one complete six-world run. No development rerun, L2 retry, four-world
continuation, threshold adjustment, physical acceptance, or release is implied.

### R10E-L3 completed graph and negative-behavior boundary

That graph is now complete. Source
`ff69874b5b7315e86865a4a265fd52fbf49ec7be`, freeze
`77fc09913d14b1965b2cb46847fa948f83cab3d5`, and authority
`55447a4791729996cfde10ac02948bbf120f84b9` passed their ordered boundaries.
One physical invocation then produced six valid cell receipts, three valid pair
receipts, and one valid terminal report. The
[immutable closure](../sdk/qsdk_r10e_held_out_finite_decision_physical_closure_v3.json)
binds the whole `79,688,410`-byte retained tree.

The architecture now distinguishes three result layers that must not be
collapsed:

| Layer | R10E-L3 result | Authority |
| --- | --- | --- |
| Native disturbance | Three exact impulses and three measurable next-step velocity effects | Confirms that the physical interaction path executed |
| Local recovery window | All three pushed arms find the frozen post-marker window at zero search latency; all matched windows also pass | Describes bounded local continuation only |
| Complete behavior conjunction | All six worlds fail only `bounded_anchor_error` | Controls the finite decision and makes it negative |

The anchor receipt is not a kick-response measurement. Its first logged
over-limit cumulative sample precedes the push in every seed, and paired arms
share the same pre-marker trace. But it is part of the prospectively frozen
whole-run integrity contract, so the evaluator correctly leaves
`behavior_passed=false`. A later design may ask a different physical question;
it may not relabel this answer or choose a new threshold from its observed
margin.

There is no live R10E authority after closure. Any next M07 implementation must
start with a new zero-world design that explicitly binds the transition it
claims. In particular, combining a retained kick receipt with an independently
retained prone-to-standing receipt is not enough to claim kick recovery unless
one prospective path physically connects those states without teleportation,
direct body-state writes, or force-aware inference hidden in the supervisor.

## QSDK-R10F continuous same-body passive-recovery architecture

R10F selects one recovery-native S169 fixture as the physical owner of every
phase. The selected BW5R-B gait becomes a facade that supplies motor targets to
that fixture; the separate V6 recovery policy supplies targets only during the
standing phases. Neither controller owns or reconstructs the body. The old
walking fixture cannot serve as the owner because its box/sphere limb geometry,
five-body callback coverage, and friction `0.95` differ from the recovery
fixture's capsule limbs, nine-body callback coverage, and rough friction `1.8`.

```text
one recovery-native S169 body and one solver history
    |
    +-- V6 canonical standing precondition (<= 1,200 steps)
    +-- fresh BW5R-B walking prefix (720 steps)
    +-- motors off + native 0.25 N s kick (one completed step)
    +-- zero-actuation passive prone confirmation (<= 60 steps)
    +-- V6 recovery inside the same <= 1,200-step post-kick epoch
    +-- fresh BW5R-B walking resume (720 steps)
```

The kick event has a strict order. Immediately before its solver step, the
walking motors are disabled and the native central impulse is applied. Walking
motors do not remain enabled through that solve, and recovery does not start
during it. The completed boundary is retained first. A bounded zero-actuation
interval may then confirm the declared prone state; the design does not claim
that the impulse by itself mechanically guarantees that state.

The existing recovery implementation expects its first semantic boundary at
local step zero, while the continuously simulated world may already have
completed thousands of solver steps. R10F preserves both truths with three
integers:

| Symbol | Meaning | May restart? |
| --- | --- | --- |
| `G` | Global completed solver step used by callbacks, native sequence, and complete-world chronology | No |
| `E` | One coherent completed post-kick boundary across all nine bodies | Bound exactly once per recovery epoch |
| `L` | Recovery-local completed step, `L = G - E` | Begins at zero for the versioned recovery epoch |

A new versioned epoch transport must carry `G`, `E`, `L`, all nine body states,
and the relevant digest chain without accepting duplicate, stale, or skipped
boundaries. A corresponding accumulator and initializer establish the complete
live energy at `E`; they do not rebuild world-start energy. Translational,
rotational, and potential terms are included. Recovery-local actuator,
external-work, constraint-exchange, staging-exchange, and passive-dissipation
accumulators begin at zero, while the prior kick remains excluded and is bound
by a separate native-interaction receipt. This is a partition boundary, not an
energy correction or threshold change.

Body identity is structural and temporal. The same nine body instance IDs and
eight joint instance IDs must survive every phase in the same scene tree, with
monotone global native-read and callback sequences. Phase changes may replace
controller-session state and motor targets, but may not rebuild the model,
reinsert nodes, or write transforms, linear or angular velocities, contacts,
sleep state, or solver state.

The implementation surface is intentionally versioned: epoch-aware boundary
transport, staging accumulator, live-energy initializer, recovery-native S169
walking facade, continuous worker, evaluator, supervisor, dependency gate,
qualification gate, stage, authority, and closure. The maximum active arm is
3,841 steps because the 1,200-step post-kick epoch includes the prone-
confirmation interval rather than adding another 60 steps outside it.

The zero-world design audit checks the exact 15 input authorities on disk and
at parent `21a1019bc170c2f09125896df6b3e0934b217812`, reopens all consumed
R10E-L3 evidence, exercises offset boundaries at `E=508` and `G=509/510`,
checks 17 same-body node identities, demonstrates a complete-energy fixture of
`39.775 J`, and refuses 262 mutations. Forty-eight source seams are located;
all physical counters remain zero.

This architecture is event-triggered passive recovery. There is no contact-
impulse estimator, force sensor, reactive bracing term, or force-conditioned
policy input. Force-aware recovery remains SDK2 work. R23D78's turning behavior
also remains a separate M20 input rather than being hidden in the R10F
controller. Until implementation qualification, source freeze, execution
authority, and committed-graph checks close in order, this architecture opens
no world and advances no claim or score.

### R10F-L1 physical-boundary path projection

The first R10F authority graph exposed one physical-only integration defect
before evidence-root creation: `-split` followed a multiline
`Invoke-GitText` invocation and was bound as a named function parameter. The
v1 graph is retained but retired. Its immutable refusal records zero models,
worlds, native reads, solver steps, and physical changes, so it is neither a
behavioral success nor a behavioral failure.

L1 gives the authority-graph path conversion one pure owner:

```text
git diff --name-only <source> <authority-head>
                    |
                    v
complete returned text
                    |
                    v
ConvertFrom-R10fGitPathText
                    |
                    v
non-empty changed-path sequence
                    |
                    v
exact {v2 freeze, v2 authority} set comparison
```

The same function is executed with CRLF/LF positive input and empty input in
zero-world testing, and the physical verifier is source-checked to call it.
The v2 manifest also binds the old v1 freeze, old v1 authority, and the
`6,012`-byte refusal at SHA-256
`27528d78b217278700f5d1860046a2e5f7fc1e2324cef1a0239ffbd7859391e0`.
No body, solver, controller, challenge, threshold, seed, or evidence-population
architecture changed. A fresh source/qualification/freeze/authority chain is
still required before construction of either R10F world.

### R10F-L2 exact ordinal path-set boundary

The v2 graph proved the L1 projection itself, then failed before output-root
creation because the following joined-string equality did not produce a
Boolean. That graph is retained and retired with zero physical state. L2 makes
both stages explicit and independently testable:

```text
Git changed-path text
        |
        v
ConvertFrom-R10fGitPathText
        |
        v
path array -------------------- expected {v3 freeze, v3 authority}
        |                                      |
        +---------------+----------------------+
                        v
             Test-R10fExactOrdinalPathSet
                        |
                        v
              Boolean true or false only
```

`Test-R10fExactOrdinalPathSet` copies both inputs, sorts with
`StringComparer.Ordinal`, refuses unequal lengths, and compares each entry
ordinally. Reordering is therefore harmless, while missing, duplicate, or
extra paths cannot collapse into an equal joined string. The same source
function runs in five preflight controls and in the physical authority check.

The 86-path v3 manifest includes both superseded freezes, both superseded
authorities, and both refusal records. No engine object is constructed to test
this boundary, and the L2 development audit records zero worlds and zero
solver steps. The repair changes authority verification only; same-body
identity, controller sessions, recovery epoch, impulse, energy accounting,
fixture, and outcome evaluation are unchanged.

### R10F-L2-P1 exposes a bootstrap-versus-active consumer boundary

The first v3 physical world stopped during baseline setup, before a solver
step, because two different receipt stages were treated as interchangeable:

```text
initial_behavior_application_route_aware_discrete_staging_v2
        |
        v
actuation-free bootstrap intent
  R24D57 base schema + R144/R148/R151/R152 identity fields
        |
        X  incorrectly sent to
        |
        v
behavior_application_receipt_valid_v4
  active R152 wrapper schema + R151/R144 predecessors + application fields
```

The v4 predicate is correct for receipts produced after
`apply_behavior_control_route_aware_discrete_staging_v2`; it is not the
bootstrap contract. R153's architecture already represents these as separate
predicates. R10F-L2 reused the active consumer at both points, and the
zero-world suite exercised active receipt mutations without executing this
exact initial producer/consumer composition.

A successor should not relabel the bootstrap as an active application. It
should give the bootstrap its own public exact predicate, require the
actuation-free fields and route/provenance identities it actually owns, and
use v4 only after a real control application. Zero-world coverage must execute
the same producer and consumer called by physical arm setup and distinguish at
least missing bootstrap identity, forged active schema, wrong route,
actuation-enabled mutation, and valid bootstrap controls. The physical v3
closure remains immutable and no body, controller, challenge, or threshold
changes follow from this integration failure.

### R10F-L3 installs stage-specific consumers and retains their receipts

L3 makes the receipt-stage distinction executable:

```text
initial_behavior_application_route_aware_discrete_staging_v2
        |
        v
R24D57 actuation-free bootstrap intent
        |
        v
initial_bootstrap_application_validation_v1
        |
        +---- retained in the arm result
        +---- retained with the full application on setup refusal

later recovery control + apply_behavior_control_route_aware_discrete_staging_v2
        |
        v
active R152/R151/R144 application receipt
        |
        v
behavior_application_receipt_valid_v4
```

The bootstrap consumer owns eleven groups of invariants: candidate recovery
context, producer status, base bootstrap schema, step boundary, command
identity, controller ownership, actuation-free fields, eight ordered disabled
motor intents, solver-coupled realization, discrete-staging energy identity,
and R152 provenance. It explicitly reports that the active validator is not
applicable. It has zero model/world/native/solver authority in its own receipt.

`zero_world_contract_v2` wraps the preexisting worker contract and adds one
exact producer/consumer control. It obtains the physical producer's required
joint surface through eight detached `HingeJoint3D` nodes, never adds them to a
scene tree, and frees them afterward. The positive bootstrap must pass its own
consumer and fail the active v4 consumer. Six structural mutations must all
fail. The outer zero-world gate incorporates those six failures, increasing
its frozen total from 42 to 48 without changing a physical or behavioral
threshold.

The v4 authority pipeline binds the consumed L2-P1 closure as a predecessor at
every layer: source audit, official-qualification attempt and completion,
stage freeze, physical authority, supervisor preflight, physical attempt,
physical report, and future v4 closure. The binder independently hashes the
closure's eight retained files. A future valid arm is also required to carry
the successful bootstrap validation receipt; the closure compiler rejects an
arm that claims the active validator applied to that bootstrap.

The 90-path manifest and complete Godot-backed development audit pass at zero
worlds. This architecture has no live physical authority until the clean
source, official qualification, v4 freeze, v4 authority, and exact two-commit
graph are present. L3 is not force-aware recovery and makes no M07 or outcome
claim.

### R10F-L3-P1 exposes the compact geometry consumer boundary

The L3 v4 graph reached the physical worker and proved that the bootstrap
consumer now admits both arms. The worker built the matched-no-kick and
active-kick instances and advanced the shared physics clock once. Collection
of semantic step one succeeded. Failure occurred in the following compact-row
translation:

```text
recovery_native_world_v1 joint state
        |
        | parent, child, joint, anchor_parent_local,
        | anchor_child_local, axis_parent_local
        v
NativeEpochRoute.collect_completed_step_v1       [succeeds; one solver step]
        |
        v
_retain_compact_step_v1
        |
        v
_joint_geometry_summary_v1
        |
        +---- requests axis_child_local           [producer has no such key]
        +---- returns {"ok": false}
        v
QSDK_R10F_NATIVE_STEP_INVALID:matched_no_kick_continuation
```

This is not a missing solver measurement. The recovery fixture is a planar
hinge system: the producer binds `Vector3.BACK` as its parent-local hinge axis,
constructs every child pose by rotation about that same axis, and its native
observer already measures anchor separation from the two retained local
anchors. The R10F helper introduced a second local-axis storage requirement
that the historical model schema neither promises nor needs. The facade
correctly accepted the producer's actual shape; the later summarizer did not.

The consumed v4 result records two models, two worlds, one shared solver frame,
no kick, and no behavior-evaluator call. A forward L4 architecture should keep
the producer immutable and move the consumer onto the exact shared-planar-axis
contract. It should validate every required field explicitly, report the joint
ID and failed predicate on refusal, and exercise the historical source shape
directly in zero-world controls. It must not turn `axis_child_local` into an
unversioned producer requirement, synthesize behavioral data, or infer a
recovery outcome. A fresh content-bound graph remains mandatory before physics.

### R10F-L4 makes the compact geometry boundary source-exact

L4 implements the consumer side of that boundary without mutating
`recovery_native_world_v1`. The retained data flow is now:

```text
completed recovery-native observation
        |
        +---- ordered joint row.anchor_error_m        [source snapshot]
        |
recovery-native joint state
        |
        +---- parent + child + joint                  [object identity]
        +---- both local anchors                      [blueprint identity]
        +---- one axis_parent_local = Vector3.BACK    [shared planar axis]
        v
_joint_geometry_summary_v2
        |
        +---- parent_basis * shared_axis_local
        +---- child_basis  * shared_axis_local
        +---- acos(abs(dot(normalized axes)))
        v
compact walking row: maximum anchor and hinge-axis error
```

The anchor value is not recomputed from a later outcome and the missing child
axis is not fabricated. The recovery fixture's child poses are rotations about
the same local `Vector3.BACK` axis, so the shared local vector is invariant
under the intended hinge motion; projecting it through both live bases exposes
off-axis joint disagreement while allowing ordinary hinge rotation. The
absolute dot product preserves the earlier unoriented-axis comparison.

The consumer requires the exact seven joint-state keys, eight joint rows in
canonical order, nine body nodes, and eight joint nodes. It binds every object
to its blueprint ID and node metadata; checks the retained anchors against the
blueprint; requires finite body bases and a finite, nonnegative,
source-validated anchor error; and emits a structured failure containing the
joint and field projection. A successful result explicitly records that no
`axis_child_local` was required or consumed and no outcome-derived correction
was made.

`zero_world_contract_v3` composes this with the previous L3 bootstrap proof.
It creates only detached node declarations, measures a known rotated-axis
canary, and rejects sixteen targeted mutations. The outer zero-world gate now
has 16 positive controls and 64 forced failures. The v5 dependency closure
binds 94 paths, both consumed invalid physical closures, and prospective v5
stage/authority names while excluding those future documents from source
closure. No model or world is constructed, no node enters a scene tree, and no
native read or solver step occurs. L4 remains event-triggered passive recovery,
not force-aware recovery, and carries no M07 or outcome authority.

### R10F-L4-P1 distinguishes a cumulative source from a per-call delta

L4-P1 crossed the geometry boundary and exposed the next interface mismatch:

```text
native collector                         R10F worker before L5
----------------                         ----------------------
global step 1 -> solver_step_count = 1  -> require == 1; add 1   [accepted]
global step 2 -> solver_step_count = 2  -> require == 1; add 2   [refused]
global step G -> solver_step_count = G
```

The producer field is not ambiguous inside its own authority. The native world
sets `model.solver_step_count = semantic_step`, returns the same value, and the
epoch wrapper retains the global collector unchanged. It is a cumulative
source-sequence check. The worker's separate terminal invariant, by contrast,
needs a count of completed arm steps, which is a delta aggregate. Using one
integer for both meanings works only at step one.

L5 therefore belongs at the consumer seam. A versioned projection must take
the collection plus expected global semantic step, reject non-integers
(including Boolean values), require the cumulative value to equal that global
step, and return both the authenticated cumulative source value and
`completed_step_delta=1`. Only the delta may increment the worker-wide total.
The existing terminal equation remains meaningful:

```text
total completed arm steps = global lockstep frames * 2 arms
```

Detached controls must exercise at least `G=1` and `G=2`, then reject a stale
value, a skipped-ahead value, absence, Boolean, floating-point, and text forms.
This repair does not modify the collector, model, solver schedule, trace
thresholds, controller, or behavior result. The L4-P1 closure at SHA-256
`b862561d0db78c03533a5d7121b4380b9c96507fe37adab2e2a046785d98dd74`
preserves the two-world/four-step invalid identity with no kick and no outcome.

### R10F-L5 gives the two counter meanings separate typed edges

L5 implements the architecture above as a pure boundary projection:

```text
native collection at global step G
        |
        +---- global_semantic_step = G               [integer sequence]
        +---- solver_step_count = G                   [cumulative source]
        +---- global_result.solver_step_count = G     [unchanged wrapper]
        v
_collection_solver_counter_projection_v1
        |
        +---- cumulative_solver_step_count = G
        +---- retained_global_cumulative_solver_step_count = G
        +---- completed_step_delta = 1                [accepted call]
        v
worker aggregate += completed_step_delta
```

The projection admits no numeric coercion: Boolean, floating-point, text, and
missing counters are rejected. It also rejects a nonpositive expected step,
wrong collection schema/gate/flags, stale or future cumulative sequence, and a
retained global wrapper that disagrees with the collection. A successful
receipt marks the cumulative field as a source measurement and explicitly
sets `outcome_derived_correction=false`.

`zero_world_contract_v4` composes the entire earlier contract with consecutive
`G=1`/`G=2` positives and sixteen negative mutations. The outer gate retains
16 positives and expands to 80 forced failures. The v6 dependency manifest
binds 98 source/build/audit paths at
`80c56eac99c4d3912617db56ffa5e03580a9ba742ef68cd5e4ca11657948626d`.
Real Godot parse and detached zero-world execution pass with every physical
counter zero. The architecture therefore repairs units and ownership only; it
does not alter the native producer, solver, controller, threshold, or behavior
question, and it does not convert L4-P1 into a behavioral result.

### R10F-L5-P1 separates solver lockstep from threshold lockstep

The L5 graph passed qualification and authorized one exact two-world route.
Both isolated worlds advanced on every common host physics frame, and every
accepted collection retained its cumulative native sequence. At global frame
240, however, the baseline recovery controller crossed its unchanged
stable-standing terminal while the active controller remained nonterminal.
The worker's planner had only this topology:

```text
same host frame
    -> process active V6 state
    -> process baseline V6 state
    -> require active.phase == baseline.phase
```

That last equality conflated two properties. Solver lockstep means both worlds
advance once on the same global frame. It does not mean two independent
floating-point worlds must cross a threshold on the same frame. The latter is
neither required by the frozen behavioral question nor guaranteed by the
engine. L5 therefore stopped after 240 global frames / 480 arm steps with zero
kicks and zero evaluator calls. The immutable closure SHA-256 is
`fb4879cc6645d60fcb71eeb1d618e4a5453f4c2386b1d45cc1d838e4775d6863`.

The prospective
[R10F-L6 design](../sdk/qsdk_r10f_l6_precondition_pair_barrier_successor_design_v1.json)
introduces a precondition pair barrier:

```text
each completed global frame
        |
        +-- unfinished arm: apply next unchanged V6 command
        |
        +-- ready arm: disable all hinge motors and retain no-actuation intent
        v
source-bound readiness receipt per arm
        |
        +-- one ready: stay inside canonical precondition barrier
        +-- both ready: release both on one shared global boundary
        v
start two fresh 720-step BW5R-B prefix sessions together
```

Readiness is arm-local and monotonic. It must carry that arm's terminal source
step and receipt digest; it cannot be inferred from processing order, copied
from the other arm, or reconstructed from later behavior. Waiting is explicit
physics, not a paused or skipped world: the solver still advances, the native
observation is retained, all eight motors are verified disabled with zero
target velocity, and no body transform, velocity, or solver state is rewritten.
The pair releases only when both source terminals are valid. This preserves the
design's common walking-prefix start and equal global horizon while admitting
ordinary one-or-more-frame threshold timing differences. It makes no threshold,
policy, model, kick, or outcome change.

### R10F-L6 implements a source edge per arm and one shared release edge

L6 realizes the pair-barrier topology as a pure state machine plus explicit
physical application validation:

```text
active V6 terminal source ------+
                                +--> pair ready
baseline V6 terminal source ----+       |
                                        v
                              common no-actuation release frame
                                        |
                                        v
                         two fresh BW5R-B session clocks
```

Before an arm is ready, its next command remains the unchanged V6 recovery
command. After it is ready but before pair release, its world still advances;
the application edge must prove all eight motors disabled, zero targets, a
finite configured cap that is not misreported as applied motor impulse, and
no-actuation ledger ownership against native readback. When
both arm-local terminal sources exist, the barrier emits a pair-global release
plan. Both arms take exactly one no-actuation release application and begin
walking on the next common boundary.

The raw physical result retains the barrier state, its content digest, each
arm's terminal source, and the ordered application projections. The future
closure compiler independently validates those records rather than treating
the worker's summary Boolean as authority. That check includes arm identity,
source-step monotonicity, release ordering, application counts, all eight
motor configurations/readbacks, and ledger ownership.

The v7 zero-world composition passes four timing schedules, two positive
application projections, nine pair-state mutations, and three application
mutations. The full outer gate passes 31 source tests, 17 positives, and 92
forced failures; future graph and closure tools reject 18 and 25 mutations.
The 104-path manifest digest is
`62e34fd2219e89376ffc5f12aa81e7ea9999012584fd94f4c9c1616e70035826`.
All physical counters remain zero. The architecture is implemented but not
yet officially qualified or physically exercised.

### R10F-L6-P1 exposes a precondition terminal edge outside the barrier

The physical L6 graph exercised this topology:

```text
baseline V6 complete at G=240 --> barrier ready --> 60 no-actuation waits
                                                     |
active V6 nonterminal -------------------------------+
                                                     v
active becomes non-complete terminal at G=300 --> generic terminal-pair check
                                                     |
                                                     v
                              QSDK_R10F_TERMINAL_FRAME_NOT_LOCKSTEP
```

The wait applications and native readbacks are valid. The architectural defect
is the top-level terminal check that precedes the phase-specific barrier path.
It knows only two route-terminal Booleans. It does not retain the active V6
terminal memory or distinguish complete, failed, and refused precondition
dispositions. The invalid result consequently proves that one arm became
terminal without becoming barrier-ready, but loses the exact source reason.

L7 introduces a typed precondition-terminal edge before generic post-release
terminal pairing:

```text
V6 step receipt + memory + classification
                    |
                    v
         arm-local terminal disposition
          /          |             \
  complete         failed         refused
     |                |               |
barrier source     route abort      route abort
     |                +-------+-------+
     v                        v
peer continues       retain both arm snapshots; no next solver frame
```

Each disposition binds arm/model identity, global step, orchestrator phase,
V6 terminal phase and reason, memory, final step receipt, classification, pair
readiness, and pair-state digest. The invalid raw result must carry both arms;
the future closure must independently revalidate their content and ordering.
This moves and enriches orchestration data only. It does not convert failure
into readiness, extend a timeout, or change any physical/behavioral parameter.

### R10F-L7 implements a source-bound abort edge before generic pairing

The implemented topology now distinguishes two kinds of precondition terminal
without changing the V6 state machine:

```text
completed shared solver frame
          |
          +--> retain active V6 source and disposition
          +--> retain baseline V6 source and disposition
                         |
             +-----------+-----------+
             |                       |
      both non-failing          failed/refused arm
             |                       |
       unchanged L6 plan       direct typed abort
                                     |
                         no subsequent solver frame
```

The per-arm receipt binds the model, global step, last V6 semantic step,
memory, step receipt, classification, route/orchestrator terminal state, L6
readiness and terminal-source digest, and the complete unreleased pair-state
digest. The two-arm abort population binds its ordered failure set to the
worker's exact `2 * global_frame` completed-step count. Both nested receipts and
the population are canonical-content addressed.

The future Python closer contains a separate canonical serializer matching the
native core's fourteen-significant-digit binary64 policy. It recomputes every
L7 digest, validates ready-arm sources against L6, validates nonready/failing
arms from their V6 records, and rejects a worker summary without the full
population. Four synthetic report classes and 45 mutations test both the direct
L7-invalid route and the generic infrastructure-invalid fallback.

The v8 dependency graph contains 110 source/build/process paths at path-set
SHA-256
`6a2ae00ea1e278506180ab3a2c4f1b43343b6424c5c095e7450dbd9193357da5`.
The full development audit passes 33 source tests, 18 positive compositions,
and 108 forced failures. Godot parses and executes the detached gate with zero
models, worlds, native reads, or solver steps. The architecture is implemented
but not officially qualified; no physical authority exists and no M07 or
recovery claim advances.

### R10F-L7-P1 exposes a discrete-step representation seam

The one qualified L7 route ghost stopped after its first shared physical frame:

```text
native V6 memory                      L7 disposition envelope
last_semantic_step = 1.0 (binary64)   expected source step = 1 (integer)
                  \                    /
                   \-- numerically equal --/
                              |
                  canonical digests agree
                              |
               L7 Variant-kind check rejects
```

Both worlds were built and each took exactly one solver step. The retained
baseline disposition is otherwise independently valid and remains
`nonterminal_last_completed_state_retained`. The worker stopped before a kick,
behavior evaluator, or outcome. The immutable v8 closure therefore records an
invalid/incomplete route, not a negative recovery result. Its SHA-256 is
`15cf3bdd5485405613726be8c800c5e46f4178a818ae89b947efc992e3094aba`.

L8 changes the validation edge, not the stored measurement. For the single
native field `recovery_memory.last_semantic_step`, the validator may accept an
integer Variant or a binary64 Variant only when the latter is finite, has no
fractional component, lies in the declared 1-to-3,842 route domain, and equals
the already-bound expected integer step. It must keep the original Variant in
the retained receipt. Every other L7 identity, hash, ordering, abort, and
no-extra-step rule stays exact.

The prospective design supplies six positive and sixteen negative controls,
including `1` versus `1.0`, native-shaped receipt construction, fractional and
nonfinite numbers, type confusion, range violations, mismatched steps, source
rewrites, and digest corruption. This is zero-world implementation authority
only. It changes no V6/BW5R-B state, body, threshold, horizon, kick, seed,
solver schedule, evaluator, or claim.

### R10F-L8 implements a source-preserving numeric-domain consumer

The implemented boundary keeps producer, receipt, and consumer responsibilities
separate:

```text
native V6 memory value
        |
        +--> retain original integer or binary64 number in the L7 receipt
        |
        +--> L8 consumer: finite + integral + 1..3842 + exact expected value
                         |
                 accept / refuse without rewriting
```

The L7 disposition schema and repair ID therefore remain the component
identity. L8 owns the narrow validation rule. The GDScript consumer and the
independent Python closure compiler both reject Boolean-as-integer confusion,
fractions, nonfinite numbers, range violations, mismatches, wrong types,
missing fields, source rewrites, digest corruption, and outcome-derived
correction. Neither changes canonical number serialization or any other
discrete field.

The v9 graph contains 115 source/build/process paths at path-set SHA-256
`416b50c5e11380a3acebe6d4d9fc04407e5602cd59a4bc7b52f00f3cb56e44a3`.
The complete development audit passes 34 source tests, 19 positive
compositions, 124 forced failures, 18 authority mutations, five closure report
classes, 55 closure report mutations, and 15 focused closer
numeric/source-domain mutations. Pinned Godot parse and detached execution report zero models,
worlds, native reads, solver steps, and state writes. This architecture is
implemented but not officially qualified; it opens no physical authority and
advances no recovery claim.

### R10F-L8-P1 exposes a one-process, two-space precondition confound

The qualified L8 identity proved the native step-number repair on a real
source, then reproduced an older asymmetry before the route reached walking:

```text
one Godot process
    |
    +-- first-built World3D: baseline V6 complete at G=240
    |                            + 60 motors-disabled waits
    |
    +-- second-built World3D: active V6 stance_dwell timeout at G=300
                                 (raised and upright, still moving)
```

Each arm lived in a separate `SubViewport` with its own `World3D`, so the two
bodies could not collide with each other. Both worlds were nevertheless built
before physics activation and advanced under the same process physics
schedule. The first-built arm's final memory and classification exactly match
the first-built successful arm in L6 and the serial successful R172 candidate.
The retained evidence therefore leaves two coupled variables: within-process
construction index and simultaneous multi-space scheduling. It identifies no
specific engine mechanism and supports no engine-bug claim.

L9 replaces only the execution container:

```text
aggregate supervisor consumes one parent identity
    |
    +-- child 1: fresh Godot process -> baseline arm -> one World3D -> close
    |
    +-- child 2: fresh Godot process -> active arm   -> one World3D -> close
    |
    +-- validate both complete child records -> phase-local pair evaluation
```

The child lifetimes may not overlap. Process IDs, attempt IDs, evidence paths,
roles, nonces, counters, and termination receipts must all be unique and
retained. A complete behavioral negative in child 1 does not suppress child 2;
an infrastructure-invalid child makes the pair inconclusive and cannot be
retried or replaced. Pair comparison uses declared phase-local receipts and
walking-session local steps, never rewritten global solver-step values.

The [prospective L9 design](../sdk/qsdk_r10f_l9_process_isolated_matched_arm_successor_design_v1.json)
holds every physical and behavioral term fixed. It authorizes implementation
of the single-arm worker, serialized supervisor, independent pair evaluator,
dependency closure, materializer, closer, and zero-world controls. It opens no
physical execution authority and advances no recovery claim.

## R10F-L9 terminal adapter failure and L10 nullable projection boundary

L9 completed the intended process-topology refactor: the aggregate supervisor
owns no physics world, and each declared arm runs serially in a fresh child
process with one model and one world. Source commit
`c94a596e731a1899f6e798fe8e9ec0b9e74c9cbc`, freeze
`f82a527b99f5c3b2ed9c94e14853f759d30c9658`, and authority
`776cfd2f0a67c50676e8959312bae7ef1aa09bd3` formed the qualified v10 graph.

The one authorized attempt validated the fresh-process boundary for its first
child, but exposed a narrower data-adapter defect. After 240 solver steps, the
Rust recovery producer returned a successful terminal memory with phase
`complete` and `terminal_failure_code = null`. That shape is required by
`RecoverySupervisorMemoryV1`, whose failure field is `Option<String>` and is
present exactly for `failed` or `refused` memory. The L9 child receipt builder
instead performed unconditional `String(...)` conversion. Godot rejected the
valid null before the child could finalize, so the aggregate supervisor
correctly refused the incomplete population and never launched the second
child.

The [v10 closure](../sdk/qsdk_r10f_development_route_ghost_physical_closure_v10.json)
at SHA-256
`7a5b61ec898b9c5b2891911101d34c3cefe7a6c5657a7c6abdea45e6b4299464`
therefore preserves one child process, one model, one world, 240 solver steps,
and no behavioral conclusion. The retained complete memory and stable stance
classification diagnose the adapter boundary; they do not become route,
recovery, support, or release evidence.

L10 keeps the L9 receipt schema and explicitly projects the two valid source
forms:

- `complete` requires source `null` and retains that null in nested memory,
  while the existing flat receipt field remains the empty string;
- `failed` or `refused` requires a nonempty source string and copies it
  exactly;
- all other phase/type/presence combinations fail before receipt publication.

The [prospective L10 design](../sdk/qsdk_r10f_l10_nullable_terminal_failure_code_successor_design_v1.json)
is 16,553 bytes at SHA-256
`2d186f41fcb73427ef7021a1050e4175791784212bfb9c219d712595370a4817`.
It authorizes only the strict consumer repair and zero-world controls. Process
isolation, child order, V6, BW5R-B, S169, all physical terms, and every claim
remain frozen; no L10 world is authorized.
