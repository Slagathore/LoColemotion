# Portable Balanced-Wave Successor Bootstrap

## Current SDK2 native evidence - 2026-11-13

The [current roadmap](SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md) owns work order.
The [dynamic trajectory result](../sdk/discovery/creature_trajectory_native_result_v1.json)
is complete at source `aed3bc18`: 224 fresh six-second worlds, 16 bodies and
48 bounded wave, impulse and waypoint proposals, each assigned to four bodies.
Every body also receives fresh brake and timed comparators. The five-world
two-interval full canary and the compact search each pass all 159 controls.
The canary replays 10 decisions and 50 native samples and verifies exact compact
projection. The broad compact reader reconstructs 161,280 controller records
and 806,400 native samples; it does not claim full controller decision replay.
All 6,251 artifacts and 40 top-level stage cleanups across both runs verify.

All 224 search worlds are valid performance negatives, with zero eligible
worlds, upright dwell or progress leads, and sixteen empty shortlists. Sixteen
worlds also violate joint limits: all four assigned bodies for wave_05,
impulse_05, waypoint_01 and waypoint_13. Only 32 of 192 new-profile worlds make
any distal contact. Timed reaches 14.3705 degrees without joint violations;
wave reaches 12.5995 in a violating world and only 0.1312 without a violation.
The best nonviolating impulse reaches 11.6124 degrees. The separate five-degree
progress screen is unchanged; no result qualifies for recovery or adoption.

Next diagnose the retained joint motion against declared ranges, target rates,
phase timing and contact reach. Contact absence, tracking and limit excursions
must be separated before attributing a force deficit or declaring another broad
body/controller successor. Keep physical bounds and eligibility unchanged.
Useful diverse leads require fresh full-capture varied-start confirmation and
the complete Godot recovery handoff with 120 resumed walking steps.

The earlier [four-phase result](../sdk/discovery/creature_righting_sequence_native_result_v1.json)
retains 256 valid negatives at source `217d591b`, with 184,320 decisions and
921,600 native samples independently replayed. All sequence worlds reach wind-up,
but later transitions use timeout rather than measured rotation/contact gates.
The static [geometry proposal](../sdk/discovery/creature_righting_geometry_result_v1.json)
did not yield useful dynamic transfer. Together with the 752 earlier
[timed and feedback failures](../sdk/discovery/creature_righting_feedback_native_result_v1.json),
the five cohorts now retain 1,232 valid negative performance worlds. All original
records and route discrepancies remain preserved; this does not prove impossibility.

The [compact recording canaries](../sdk/discovery/creature_capture_native_result_v1.json)
at source `670cffc2` retain exact same-run projection and 75.7% smaller fresh
streams. Full-plus-projection outer-loop time is 14.5752 seconds versus 13.8561
for compact; one ordered pair per body does not establish ordinary full-capture
speedup or real time. The broad search reuses the same-freeze full interface
check without duplicating its entire population. Native reads, solver inputs
and every substep remain captured. Compact outcomes confer no full-replay,
recovery, training or release authority.

The native route now constructs and steps actual bounded quadruped variants.
Four fresh GPU worlds across three shapes passed the 0.2-second route check,
including full model transport and independent replay. Different body shapes
use separate batches because the engine has shared geometry-dependent constants.
The first refused attempt remains retained. The 24-body, 240-world breadth
cohort is now complete after its 117-control gate: 171 eligible episodes,
69 performance failures and zero invalid. All 57,600 controller decisions and
288,000 native samples passed independent replay. The
[confirmation cohort](../sdk/discovery/creature_confirmation_native_result_v1.json)
now completes after 139 fresh zero-world controls: 284 twelve-second worlds,
all 24 bodies, both conditions and two new starts. Its 221 eligible and 63
failed worlds are valid; 408,960 decisions and 2,044,800 native samples pass
independent replay. The
[shared-readback route](../sdk/discovery/creature_readback_native_result_v1.json)
now passes after 122 fresh controls: six worlds in four bounded chunks,
144 exact original-path observation matches and 720 independently verified
native samples. Those completed cohorts used full capture; no snapshot survives
its prepared step.

| Record | Status and scope |
| --- | --- |
| [Population v1 failure](../sdk/discovery/population_discovery_native_failure_v1.json) | Consumed canary failure; 16 canary worlds, zero population worlds |
| [Population v2](../sdk/discovery/population_discovery_native_result_v2.json) | 16 canaries and 256 two-second discovery worlds; 64 controller profiles on S169; shortlist 08/18 nominal and 55/27 weak-left |
| [Shortlist component](../sdk/discovery/population_shortlist_component_result_v1.json) | Complete 128-control zero-world gate for the declared route |
| [Shortlist native result](../sdk/discovery/population_shortlist_native_result_v1.json) | 20 fresh twelve-second worlds, full capture and independent replay; 14 eligible, six performance failures, zero invalid |
| [Mixed-creature component](../sdk/discovery/creature_batch_component_v1.json) | 21 controls pass; 64 cells across 32 compiled shapes match scalar execution; zero worlds and no native launch authorization |
| [Native route v1 refusal](../sdk/discovery/creature_route_native_failure_v1.json) | Four CPU models constructed; shared model fields differed; zero GPU worlds and zero steps |
| [Grouped native route gate](../sdk/discovery/creature_native_component_v3.json) | 110 controls pass; four fresh worlds in three body-shape batches declared for a 0.2-second route check |
| [Grouped native route result](../sdk/discovery/creature_route_native_result_v2.json) | All four worlds complete; 96 controller decisions and 480 native samples independently replayed; route proof only |
| [Actual-creature breadth gate](../sdk/discovery/creature_breadth_component_v1.json) | 117 controls pass; zero-world prerequisite for the native cohort |
| [Actual-creature breadth result](../sdk/discovery/creature_breadth_native_result_v1.json) | 24 bodies, five profiles, two actuator conditions, one exposed start and two seconds: 171 eligible, 69 failed; useful shortlists in 37 of 48 groups |
| [Diverse confirmation result](../sdk/discovery/creature_confirmation_native_result_v1.json) | Both-start eligible groups: baseline 30/48, frozen choice 33/48, fixed profile 27 36/48; the frozen choice fails its predeclared criterion against both comparators |

The native shortlist came from prospective source freeze ca57f6bb.
Both 55 and 27 remained eligible under 75% left-side actuation at the two
exposed initial lateral velocities, 0.001 and 0.003 m/s. Baseline, 08 and 18
failed there. All nominal episodes passed, with lower nominal tracking error
for 08/18 and higher error for 55/27 than baseline. Its separately assessed
two-second prefix retains the same eligibility split.

Across the later creature breadth cohort, weak-left eligibility was baseline
9/24, 08 8/24, 18 10/24, 55 12/24 and 27 14/24. All nominal bodies passed with
18/55/27; baseline and 08 each failed on `route_shape_b`. Nine weakened bodies
failed with every profile. `explorer_seed_6119` under weak-left actuation passed
only with baseline. Every body/condition remains in the result, including empty
shortlists. The whole-episode average velocity error ranks only eligible
candidates within their own body and condition.

Confirmation retains every discovery shortlist and empty group. Four groups
have a passing tested alternative to the failed frozen choice; eleven weakened
groups have no tested candidate passing both starts. Do not refit or adopt that
choice using its confirmation outcomes. S169 profile 55 fails one new weak-left
start, while 27 passes both; the earlier finite positive remains valid at its
original starts. Next work separates selection misses from controller gaps,
declares learning and held-out data prospectively, and completes the Studio
recovery handoff. Its [fresh observation boundary](../sdk/explorer/studio/live_recovery_epoch_native_result_v1.json)
now passes a 360-step native route: three measured boundaries, the same nine
body instances and two independently reconstructed staging pairs. The
[measured energy route](../sdk/explorer/studio/live_recovery_energy_native_result_v1.json)
also passes one 360-step world after 35 adapter checks and 19 reader controls:
two fresh increments, 16 motor observations, five reconstructed work channels
and two replayed compiled evaluations. The combined
[handoff v1 native attempt](../sdk/explorer/studio/live_handoff_native_failure_v1.json)
detected a fall at 552 and independently verified passive interval 553, then
refused the observation projection before recovery control. Its comparison
mixed portable binary64 and native binary32 timesteps. The
[v2 component](../sdk/explorer/studio/live_handoff_component_v2.json) checks the
exact mapping and retains rejected sources. Its zero-world gate passes 32
adapter checks, 486 exact compiled-call replays and eight reader corruption
controls. The [v2 native attempt](../sdk/explorer/studio/live_handoff_native_failure_v2.json)
verifies that correction and all 240 passive entry intervals: 240 entry calls,
240 energy evaluations and 1,920 motor observations independently replayed.
It times out at 792 with an almost inverted torso and joint-limit and entry
checks false. No active recovery command or walking restart occurs. Next
search a declared recovery-entry/self-righting cohort, retain unsafe and
inverted failures, and rigorously check diverse useful candidates through the
full handoff. Recovery benefit, installed interaction and real time remain open.

Every failed episode has null quality. No numeric gain is computed against
a failed weak baseline. The result does not demonstrate general creature
coverage, a learned selector, online memory, recovery success, robust control,
real-time behavior, cross-engine equivalence or release readiness.

Use the existing public descriptor/compiler, policy-session and composition
interfaces when extending the development route. Keep per-creature controller
and provider memory isolated. Preserve exact-S169 routes and all consumed
declarations. Different model dimensions or geometry require a newly checked
native construction/observation boundary; a renamed descriptor is not coverage.

The [dated portable ledger](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP_HISTORY_2026-11-01.md)
retains earlier policy, engine, recovery and failure checkpoints. Its dated
"next" instructions are historical. The
[master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md),
[research evidence contract](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md),
[architecture](LOCOMOTION_ARCHITECTURE.md) and
[support matrix](../sdk/release/quadruped_support_matrix.json)
retain their respective authority. Full raw evidence remains in the durable
archive identified by each closure.
