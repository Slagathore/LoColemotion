# SDK Product and Adaptation Roadmap

This page owns the current work order toward adaptable, self-learning and
self-correcting locomotion in the SDK and live Studio. Search the
[dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md)
for earlier decisions; individual result records retain the detailed evidence.

## Current execution order - 2026-11-13

**Search many actual bodies and controller trajectories cheaply, then apply
fresh full-capture scrutiny to useful, diverse leads.** Walking discovery found
finite useful profiles. The frozen condition-known selector failed confirmation,
and self-righting still has no qualifying controller after ten cohorts.

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
| [Paired joint braking](../sdk/discovery/creature_joint_braking_native_result_v1.json) | 224 twelve-second worlds after 175 controls: braked joint-crossing worlds 0/96 versus 16/96 unbraked; zero recovery or progress leads. Contact worlds fall 33 to 25, and maximum nonviolating rotation falls 14.03 to 13.98 degrees. All 2,580,480 commands match. A historical test-input inventory omission is disclosed and corrected by a later exact-byte supplement and complete zero-world successor |
| [Body-aware contact result](../sdk/discovery/creature_contact_reach_native_result_v1.json) | 128 twelve-second worlds after 172 controls: all 96 new-controller worlds acquire distal contact, with zero joint violations, but zero recovery or progress leads. Best new rotation is 14.235 degrees; best gain over its own fresh timed comparator is 1.467 degrees. The eight-world full route replays 2,880 decisions and 14,400 samples; broad compact reading reconstructs 184,320 records and 921,600 samples |
| [Paired torso targets](../sdk/discovery/creature_torso_target_native_result_v1.json) | 224 twelve-second worlds after 182 controls: all 128 new-target worlds acquire contact with zero joint violations, but zero recovery or progress leads. Peak new rotation 14.272 degrees; mean change from each paired base is +2.711 degrees for root targets and +2.952 for torso-edge targets. Fourteen full route worlds replay 5,040 decisions and 25,200 samples; broad reading reconstructs 322,560 records and 1,612,800 samples |
| [Reach bounds](../sdk/discovery/creature_contact_envelope_result_v1.json) and [contact moments](../sdk/discovery/creature_contact_moment_result_v1.json) | 334 bodies and 7,585 poses each; 374.9 million geometric pose/orientation cases, twenty controls, zero worlds. Only 483,751 of 2,533,390 body/pose combinations avoid nonadjacent overlap. Upward foot force offers no positive moment at sampled side-roll angles 20–45 degrees. Optimistic friction bounds remain; 31 bodies have a pitch proposal at every sampled orientation in both directions. No force or trajectory qualification |
| [Body-moment native result](../sdk/discovery/creature_body_moment_native_result_v1.json) | 230 controls, ten full six-second route worlds and 240 compact twelve-second search worlds. Zero recoveries or joint-breach worlds; 29 partial-rotation leads in 22 of 24 body groups, with eleven groups in each geometric stratum. Peak new rotation 24.485 degrees. All 345,600 compact records and 1,728,000 native samples reconstruct; selected-path diagnosis follows below |
| [Retained path and geometry result](../sdk/discovery/creature_body_moment_geometry_result_v1.json) | 26 of 29 leads are clear at every retained sample, across 21 bodies; three overlap. All 22 timed comparators are clear. Geometry calculation is 9.503 times faster on retained inputs, with exact full-route replay and zero new worlds. Continuous clearance, native throughput and recovery remain unproved |
| Scope | Finite exposed development evidence. No learned selection, useful online correction, broad morphology qualification, recovery, real-time or release authority |

1. **Advance beyond the sampled-clear partial motions.**
   The [geometry result](../sdk/discovery/creature_body_moment_geometry_result_v1.json)
   checks 367,200 native samples and 51 initial states: 26 of 29 leads stay clear
   at all samples across 21 bodies; all 22 timed comparators stay clear.
   Three leads overlap. One retains a useful peak before overlap begins;
   another sampled-clear lead passes within only 10.5 micrometres.
   These are sampled paths, with robot self-collision still disabled.
   The best clear rotation remains 24.485 degrees; all 240 recovery outcomes
   and the raw 29-lead selection remain unchanged.
   Batched geometry is 9.503 times faster in the paired retained-input
   benchmark. All 5,760 geometry outputs and the complete 7,200-decision,
   36,000-sample route replay remain exact; 68 focused controls pass.
   Native throughput and Studio speed have not been measured after this change.
   Build a distinct broad successor around the clear leads and useful prefix,
   varying contact handoff and momentum timing across bodies. Include fresh
   original-profile and timed/brake comparators, prospective path checks and
   unchanged joint/recovery criteria. Full-capture varied-start confirmation,
   collision-response qualification and actual recovery remain necessary.
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
