# SDK Product and Adaptation Roadmap

This page owns the current work order toward adaptable, self-learning and
self-correcting locomotion in the SDK and live Studio. Search the
[dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md)
for earlier decisions; individual result records retain the detailed evidence.

## Current execution order - 2026-11-13

**Search many actual bodies and controller trajectories cheaply, then apply
fresh full-capture scrutiny to useful, diverse leads.** Walking discovery found
finite useful profiles. The frozen condition-known selector failed confirmation,
and useful self-righting remains unestablished after six negative cohorts.

| Current evidence | Verified result and boundary |
| --- | --- |
| [Walking population](../sdk/discovery/population_discovery_native_result_v2.json) and [shortlist](../sdk/discovery/population_shortlist_native_result_v1.json) | 64 profiles on S169; fresh twelve-second checks preserve weak-left eligibility for 55/27 at the two exposed starts, with a nominal tracking tradeoff |
| [Actual-creature breadth](../sdk/discovery/creature_breadth_native_result_v1.json) | 240 two-second worlds across 24 bodies, five profiles and two conditions: 171 eligible, 69 failed, zero invalid; 69 shortlist entries in 37 of 48 groups |
| [Diverse confirmation](../sdk/discovery/creature_confirmation_native_result_v1.json) | 284 fresh twelve-second worlds: 221 eligible, 63 failed, zero invalid. Both-start eligible groups: baseline 30/48, frozen choice 33/48, fixed profile 27 36/48. Neither declared choice comparison passes |
| Confirmation gaps | Four groups have a passing alternative to the failed choice; eleven weakened-body groups have no tested candidate passing both starts. The choice was not refitted |
| [Studio handoff](../sdk/explorer/studio/live_handoff_native_failure_v2.json) | Fresh measured entry and 240 passive intervals replay correctly; the inverted body times out without active recovery or walking resume. The earlier timestep refusal stays retained |
| [Four-phase righting](../sdk/discovery/creature_righting_sequence_native_result_v1.json) | 256 fresh six-second worlds across 16 bodies and 16 profiles: zero eligible, 256 valid failures, zero invalid or joint-breach worlds, and 16 empty shortlists. All 184,320 decisions and 921,600 samples replay after 143 controls |
| Righting diagnosis | All 224 sequence worlds reach wind-up, but none meets a later rotation/contact transition. Maximum recorded boundary rotation is 9.6 degrees for a sequence and 14.4 for the timed comparator. Static-pose proposals did not produce useful dynamic motion |
| [Compact capture native result](../sdk/discovery/creature_capture_native_result_v1.json) | Both eight-world canaries pass 153 controls and independent reading. Same-run projection is exact; fresh compact streams are 75.7% smaller. Outer-loop time is 14.58 vs 13.86 seconds, descriptive only because full also writes projection. Retained 256-world reconstruction remains exact |
| [Dynamic trajectory result](../sdk/discovery/creature_trajectory_native_result_v1.json) | 224 valid six-second failures across 16 bodies after 159 controls: zero eligible, zero progress leads, 16 joint-breach worlds. Compact reading reconstructs 161,280 records and 806,400 samples. Only 32 of 192 new-profile worlds make any distal contact; the timed comparator reaches 14.37 degrees without joint violations |
| [Retained motion diagnosis](../sdk/discovery/creature_trajectory_diagnosis_result_v1.json) | Six controls pass; all 1,290,240 velocity commands match. 3,512/3,616 completed phases time out, with large pose errors despite close velocity tracking and rare force saturation. Zero new worlds; no causal or recovery claim |
| [Paired retiming result](../sdk/discovery/creature_trajectory_retiming_native_result_v1.json) | 224 fresh twelve-second worlds after 172 controls: zero eligible or progress leads, 32 joint-breach worlds. Longer holds increase measured pose completions 160 to 382 and contact worlds 23/96 to 33/96; all nonviolating proposals still trail their own fresh timed comparator. All 2,580,480 velocity commands match in the retained-motion diagnostic |
| Scope | Finite exposed development evidence. No learned selection, useful online correction, broad morphology qualification, recovery, real-time or release authority |

1. **Test anticipatory joint braking across the diverse exposed population.**
   The [onset read](../sdk/discovery/creature_contact_onset_diagnosis_result_v1.json)
   finds outward velocity commands at all 32 first joint crossings despite
   inward position targets; 24 crossings precede any distal contact and only
   two have saturated actuators. The
   [braking component](../sdk/discovery/creature_joint_braking_component_v1.json)
   passes all 175 zero-world controls. It projects measured joint motion and
   shapes speed before the original observed-bound guard; its deceleration
   estimate is not a physical guarantee. After the clean pushed freeze, run
   the fourteen-world 0.75-second full canary, then 224 fresh twelve-second
   worlds: 24 braked/unbraked trajectory pairs on four bodies each, with fresh
   timed/brake comparators on all 16 bodies. Poses, timing, gains, speed, slew,
   force and eligibility stay fixed. No native braking benefit is established.
   All 1,456 valid negative performance worlds remain. Useful diverse leads
   still require fresh full-capture varied-start checks before SDK/Studio adoption.
2. **Complete the Studio behavior with a useful controller.** Keep the existing
   fresh observation epoch, body identity, motor ownership, native clocks and
   measured work. The required end-to-end run is walking, fall, active recovery,
   recovery completion, then 120 resumed walking steps on the same body.
   No pose reset, invented history or relaxed entry/joint-limit gate is allowed.
   Installed interaction and startup/stepping performance remain separate work:
   the earlier fifteen-second run took 43.852625 seconds through stand-up and
   29.662299 seconds for walking. The shorter energy probe is descriptive and
   does not establish a matched speed improvement.
3. **Build useful adaptation with separate training and evaluation.** Keep the
   four walking-selection misses distinct from the eleven controller gaps, and
   keep fixed profile 27 as a finite comparator. Declare morphology features,
   training data and untouched evaluation groups before fitting a provider.
   Condition-known lookup is not learned Tier 2. Tier 3 additionally requires
   useful bounded memory with reset, rollback and memory-off controls; earlier
   [contextual memory](../sdk/discovery/gpu_contextual_influence_closure_v1.json)
   verified mechanics but failed its benefit criterion. Do not reward an
   unobserved alternative because the selected action failed.

## How work advances

Follow the [qualification economy rule](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#qualification-economy-and-audit-growth-control):
reuse shared runners and readers, add code for new interfaces or invariants,
and run the complete applicable safety gate before physics. Native work uses
a clean pushed prospective freeze and owned containment. Consumed attempts,
failed outcomes and original streams stay immutable. Compact discovery cannot
substitute for fresh full-capture confirmation or official qualification.

The [master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md),
[portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md),
[research contract](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md),
[architecture](LOCOMOTION_ARCHITECTURE.md) and
[release matrix](../sdk/release/quadruped_support_matrix.json) retain their own
claim authority. Experiments do not automatically advance crate versions;
a versioned SDK release deliberately rebinds manifests and package records.
[Detailed tier requirements](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md#adaptation-tiers)
remain the design contract.

<a id="immediate-order-of-work"></a>

The [historical immediate order](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md#immediate-order-of-work)
is retained for old links; the current order is above.
