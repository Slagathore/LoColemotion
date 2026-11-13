# Portable Balanced-Wave Successor Bootstrap

## Current SDK2 native evidence - 2026-11-13

The [current roadmap](SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md) owns work order.
The [paired braking result](../sdk/discovery/creature_joint_braking_native_result_v1.json)
is complete at source 8c81cf2e: 224 fresh twelve-second worlds across sixteen
bodies. Twenty-four exposed slow trajectories each run with and without the
braking option on four bodies; every body also has both fresh comparators.
Poses, phase timing, gains, speed, slew, force and eligibility remain fixed.

Both the fourteen-world 0.75-second full canary and broad compact run pass
175 controls. The canary replays 1,260 decisions and 6,300 samples with exact
compact projection. Braking activates 410 times before observed bound breaches;
two unbraked canary worlds violate limits and no braked world does.
The broad reader reconstructs 322,560 controller records and 1,612,800 native
samples. All 5,881 native artifacts and 44 stage cleanups verify.

The intervention removes all sixteen observed unbraked crossing failures:
zero of 96 braked worlds cross a joint bound, versus 16/96 unbraked.
The read-only motion diagnostic matches all 2,580,480 velocity commands and
counts 24,313 anticipatory changes. Violating samples fall from 4,488 to zero.
This is finite development evidence for joint-bound handling, not a verified
physical stopping model or broad morphology qualification.

Recovery still fails in all 224 worlds, with no invalid worlds or progress
leads. Contact worlds fall from 33/96 to 25/96; maximum nonviolating rotation
falls from 14.03 to 13.98 degrees, and mean paired rotation changes by -0.526
degrees. Every nonviolating proposal remains below its own fresh timed
comparator. Measured pose exits change only from 382 to 390 of 1,176 completed
visits. No recovery or adaptation mechanism is adopted.

The original direct source inventories omit the historical trajectory
declaration read by the legacy-compatibility control. Its transitive hash pin
is retained in the archived retiming recipe. The
[inventory successor](../sdk/discovery/creature_joint_braking_component_v2.json)
records an exact-byte supplement matching the published freeze, unchanged
checkout and earlier archive. Original receipts and the
[v1 component](../sdk/discovery/creature_joint_braking_component_v1.json) remain
unchanged. The complete successor gate passes 175 controls and now retains all
four declarations. Native physics was not repeated for this inventory-only fix.

The next family should use compiled limb geometry and measured contact to
choose reachable foot placements and supported push directions, with
anticipatory braking available. Declare a small route check, then search
broadly across varied bodies with fresh comparators and unchanged eligibility.
Useful diverse leads still require fresh full-capture varied-start checks
and the complete Godot walk-fall-recover-resume handoff with 120 resumed steps.

The preceding [paired retiming result](../sdk/discovery/creature_trajectory_retiming_native_result_v1.json)
retains 224 twelve-second negatives at source b8f369f2. Longer schedules improve
pose completion and contact but leave 32 joint-breach worlds and no recovery.
The [onset diagnosis](../sdk/discovery/creature_contact_onset_diagnosis_result_v1.json)
finds outward commands at all 32 first crossings despite inward position
targets; 24 precede any distal contact. Those immutable observations motivated
the braking intervention.

The preceding [trajectory cohort](../sdk/discovery/creature_trajectory_native_result_v1.json)
retains 224 six-second negatives and sixteen joint-breach worlds; its
[read-only diagnosis](../sdk/discovery/creature_trajectory_diagnosis_result_v1.json)
motivated the timing intervention. Those original results remain immutable.

The earlier [four-phase result](../sdk/discovery/creature_righting_sequence_native_result_v1.json)
retains 256 valid negatives at source `217d591b`, with 184,320 decisions and
921,600 native samples independently replayed. All sequence worlds reach wind-up,
but later transitions use timeout rather than measured rotation/contact gates.
The static [geometry proposal](../sdk/discovery/creature_righting_geometry_result_v1.json)
did not yield useful dynamic transfer. Together with the 752 earlier
[timed and feedback failures](../sdk/discovery/creature_righting_feedback_native_result_v1.json),
the seven cohorts now retain 1,680 valid negative performance worlds. All original
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
