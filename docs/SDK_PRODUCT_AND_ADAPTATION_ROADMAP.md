# SDK Product and Adaptation Roadmap

This page owns the current work order toward adaptable, self-learning and
self-correcting locomotion in the SDK and live Studio. Detailed experiments
stay in their result records and the [portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md);
earlier decisions stay in the [dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md).

## Current execution order - 2026-11-14

**Search many actual bodies and controller trajectories cheaply, then apply
fresh full-capture scrutiny to useful, diverse leads.** The 24-body feedback
search now completes: raw gains clear five degrees in 164 of 168 model-selected
runs, but every model-selected run violates joint limits. Diagnose the retained first
crossings before declaring a distinct constraint-aware recovery successor.

| Current evidence | Verified result and boundary |
| --- | --- |
| [Walking confirmation](../sdk/discovery/creature_confirmation_native_result_v1.json) | 284 fresh twelve-second worlds; 221 eligible, 63 failed. Both-start groups: baseline 30/48, frozen choice 33/48, fixed profile 27 36/48. Both declared choice comparisons fail; no learned Tier 2 |
| [Recovery cohorts](../sdk/discovery/creature_support_sharing_native_result_v1.json) | The earlier thirteen complete cohorts retain 2,896 valid recovery failures. The later [torque-map v2 search](../sdk/discovery/creature_torque_map_native_failure_v2.json) is separately retained: all 126 completed new-controller worlds lose to fresh references; five joint-violation worlds |
| [Contact-force diagnosis](../sdk/discovery/creature_contact_reactions_result_v1.json) | Zero new worlds; all 12,960 decisions and 64,800 solved samples read. On bodies 0/16, requested feet average 8.190/2.052 Nm, torso -8.309/-2.066 Nm, net 0.013/0.012 Nm. Body 21 makes no positive request. Foot-only moment misses the opposing torso reaction |
| [Actuator-aware action probe](../sdk/discovery/creature_response_probe_native_result_v3.json) | 223 controls, 165 fresh worlds and full replay. Ordering accuracy is 75.9%/71.3%/66.7% on seed 6119/corner 000/seed 14172: two bodies pass, so the all-body screen fails. Predicted winners match all nine measured best means; eight gains against unchanged action exceed the fixed tie margin. No joint violations or recovery. The [retained model correction](../sdk/discovery/coupled_contact_response_result_v2.json) and earlier negatives remain preserved |
| [Closed-loop recovery search](../sdk/discovery/creature_response_search_native_result_v1.json) | 216 controls per launch; ten route worlds and 240 twelve-second worlds fully replay. All 168 model-selected worlds violate joint limits; all 72 fresh references avoid them. Raw peak gains clear five degrees against both controls in 164 model worlds, but all are disqualified. Zero recovery, upright dwell, progress leads or model withdrawals |
| [Studio handoff](../sdk/explorer/studio/live_handoff_native_failure_v2.json) | Fresh measured entry and 240 passive intervals replay. The inverted body times out without active recovery or resumed walking |
| [Studio startup comparison](../sdk/explorer/studio/startup_native_runtime_result_v1.json) | Four fresh ABBA worlds: original 18.440/18.452 seconds, compiled 17.634/17.620. All 360 frames and 118 full controller rows match. Reductions 4.37%/4.51%, mean 4.44%, miss the frozen 5% threshold. Original default remains active; no further startup tuning grid |

1. **Diagnose the joint-limit failures, then search a distinct successor.**
   The [full result](../sdk/discovery/creature_response_search_native_result_v1.json)
   retains all 240 outcomes, including larger but disqualified rotations.
   Use the retained traces to locate every model run's first joint crossing,
   measure its size and duration, and bind it to action, command, measured
   velocity, guard decision, contact support and prediction. Compare all fresh
   references. The command guard's lack of stopping-distance state is a
   hypothesis to test. Use the finding to declare broad feasible-action or
   trajectory alternatives across actual bodies, with fresh controls, complete
   safety checks and a native route. Preserve the earlier ordering failure,
   this cohort's criteria and every outcome; do not repeat the same eight-factor
   search or adopt its raw rotation gains.
2. **Complete the Studio recovery handoff with a useful controller.** Preserve
   fresh observations, body identity, motor ownership, native clocks and
   measured work. The required run is walking, fall, active recovery, completed
   recovery, then 120 resumed walking steps on the same body. No pose reset,
   invented history or relaxed entry/joint-limit gate is allowed.
3. **Build learned adaptation with separate training and evaluation.** Keep the
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
