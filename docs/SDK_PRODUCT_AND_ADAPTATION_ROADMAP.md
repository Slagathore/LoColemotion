# SDK Product and Adaptation Roadmap

This page owns the current work order toward adaptable, self-learning and
self-correcting locomotion in the SDK and live Studio. Detailed experiments
stay in their result records and the [portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md);
earlier decisions stay in the [dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md).

## Current execution order - 2026-11-14

**Search many actual bodies and controller trajectories cheaply, then apply
fresh full-capture scrutiny to useful, diverse leads.** The latest contact
diagnosis changes what the recovery search should optimize; Studio performance
is the next bounded implementation task.

| Current evidence | Verified result and boundary |
| --- | --- |
| [Walking confirmation](../sdk/discovery/creature_confirmation_native_result_v1.json) | 284 fresh twelve-second worlds; 221 eligible, 63 failed. Both-start groups: baseline 30/48, frozen choice 33/48, fixed profile 27 36/48. Both declared choice comparisons fail; no learned Tier 2 |
| [Recovery cohorts](../sdk/discovery/creature_support_sharing_native_result_v1.json) | Thirteen complete cohorts retain 2,896 valid recovery failures. The later [torque-map v2 search](../sdk/discovery/creature_torque_map_native_failure_v2.json) is separately retained: all 126 completed new-controller worlds lose to fresh references; five joint-violation worlds |
| [Contact-force diagnosis](../sdk/discovery/creature_contact_reactions_result_v1.json) | Zero new worlds; all 12,960 decisions and 64,800 solved samples read. On bodies 0/16, requested feet average 8.190/2.052 Nm, torso -8.309/-2.066 Nm, net 0.013/0.012 Nm. Body 21 makes no positive request. Foot-only moment misses the opposing torso reaction |
| [Studio handoff](../sdk/explorer/studio/live_handoff_native_failure_v2.json) | Fresh measured entry and 240 passive intervals replay. The inverted body times out without active recovery or resumed walking |
| [Studio performance comparison](../sdk/explorer/studio/walking_performance_cache_result_v1.json) | Four fresh matched worlds: old cache stand-up 19.934/20.260 seconds, LRU 21.326/20.673 seconds. All 2,041 frames and 1,799 full controller rows match. LRU fails the speedup criterion; previous default restored. Fifteen-second walking intervals take 14.974-15.124 seconds; no general real-time qualification |

1. **Reduce measured Studio stand-up processing cost.** The
   [matched cache comparison](../sdk/explorer/studio/walking_performance_cache_result_v1.json)
   failed: 1.38% fewer canonicalization calls did not improve startup.
   The previous cache is restored as the default and passes the full route
   preflight. Do not repeat a cache-size tuning grid.
   The [retained-packet CPU profile](../sdk/explorer/studio/startup_packet_profile_result_v1.json)
   verifies 288 exact replays and rejects two scalar-validator changes: observed
   warm median reductions 4.7% and -1.0%, below the declared 10% threshold.
   Original validation stays active. The input is one historical terminal
   stand-up packet with the current DLL; recent timing archives do not contain
   intermediate startup requests. Next retain representative exact inputs across
   startup phases in one bounded capture diagnostic, then evaluate shared compiled
   validation/retention. Require a useful CPU result before another matched timing
   trial. Preserve full capture and solver inputs; no cache or scalar-loop grid.
2. **Search recovery using the whole body's contact response.** The
   [36-world diagnostic](../sdk/discovery/creature_torque_map_route_native_v3.json)
   verifies solved reactions and empty-cone fallback, with no recovery.
   Its [force comparison](../sdk/discovery/creature_contact_reactions_result_v1.json)
   shows that accurate initial joint torque and a strong foot moment can coexist
   with almost cancelling torso reaction. Choose a coupled contact/support
   trajectory family and rank measured motion, including torso support.
   Do not repeat the unchanged foot-only force grid. Keep failures and diverse
   body outcomes; confirm useful leads in fresh full-capture worlds.
3. **Complete the Studio recovery handoff with a useful controller.** Preserve
   fresh observations, body identity, motor ownership, native clocks and
   measured work. The required run is walking, fall, active recovery, completed
   recovery, then 120 resumed walking steps on the same body. No pose reset,
   invented history or relaxed entry/joint-limit gate is allowed.
4. **Build learned adaptation with separate training and evaluation.** Keep the
   four walking-selection misses distinct from eleven weakened-body groups
   with no candidate passing both starts. Retain fixed profile 27 as comparator.
   Declare morphology features, training data and untouched evaluation groups
   before fitting. Tier 3 also requires useful bounded memory with reset,
   rollback and memory-off controls. Earlier contextual memory passed mechanics
   but failed benefit; an unobserved alternative cannot earn reward from a
   selected action's failure.

## How work advances

Follow the [qualification economy rule](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#qualification-economy-and-audit-growth-control):
reuse runners and readers; add code for new interfaces or invariants. Complete
the applicable safety gate before physics and run native work from a clean,
pushed prospective freeze with owned containment. Keep consumed attempts,
negative outcomes and original streams immutable. Compact discovery never
substitutes for fresh confirmation or official qualification.

The [master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md),
[portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md),
[research contract](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md),
[architecture](LOCOMOTION_ARCHITECTURE.md) and
[release matrix](../sdk/release/quadruped_support_matrix.json) retain claim
authority. Useful recovery, learned selection, beneficial online correction,
real time and the full Studio handoff remain unqualified. Experimental pushes
do not automatically bump pinned crate versions; an SDK release deliberately
rebinds manifests and package records.
[Detailed tier requirements](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md#adaptation-tiers)
remain the design contract.

<a id="immediate-order-of-work"></a>

The [historical immediate order](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md#immediate-order-of-work)
is retained for old links; the current order is above.
