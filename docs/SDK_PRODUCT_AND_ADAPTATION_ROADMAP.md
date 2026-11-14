# SDK Product and Adaptation Roadmap

This page owns the current work order toward adaptable, self-learning and
self-correcting locomotion in the SDK and live Studio. Detailed experiments
stay in their result records and the [portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md);
earlier decisions stay in the [dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md).

## Current execution order - 2026-11-14

**Search many actual bodies and controller trajectories cheaply, then apply
fresh full-capture scrutiny to useful, diverse leads.** The latest contact
diagnosis changes what the recovery search should optimize. The bounded startup
comparison is closed; coupled contact recovery is next.

| Current evidence | Verified result and boundary |
| --- | --- |
| [Walking confirmation](../sdk/discovery/creature_confirmation_native_result_v1.json) | 284 fresh twelve-second worlds; 221 eligible, 63 failed. Both-start groups: baseline 30/48, frozen choice 33/48, fixed profile 27 36/48. Both declared choice comparisons fail; no learned Tier 2 |
| [Recovery cohorts](../sdk/discovery/creature_support_sharing_native_result_v1.json) | Thirteen complete cohorts retain 2,896 valid recovery failures. The later [torque-map v2 search](../sdk/discovery/creature_torque_map_native_failure_v2.json) is separately retained: all 126 completed new-controller worlds lose to fresh references; five joint-violation worlds |
| [Contact-force diagnosis](../sdk/discovery/creature_contact_reactions_result_v1.json) | Zero new worlds; all 12,960 decisions and 64,800 solved samples read. On bodies 0/16, requested feet average 8.190/2.052 Nm, torso -8.309/-2.066 Nm, net 0.013/0.012 Nm. Body 21 makes no positive request. Foot-only moment misses the opposing torso reaction |
| [Coupled response model](../sdk/discovery/coupled_contact_response_result_v1.json) | Retained mean rotation error falls 63%/56%/36%; 66 states worsen. The [84-world action probe](../sdk/discovery/creature_response_probe_native_failure_v1.json) completes full replay after 195 controls, but exact prefix matching refuses all six later groups. Action ordering remains unassessed; numerical matching and repeated identical-action controls are next |
| [Studio handoff](../sdk/explorer/studio/live_handoff_native_failure_v2.json) | Fresh measured entry and 240 passive intervals replay. The inverted body times out without active recovery or resumed walking |
| [Studio startup comparison](../sdk/explorer/studio/startup_native_runtime_result_v1.json) | Four fresh ABBA worlds: original 18.440/18.452 seconds, compiled 17.634/17.620. All 360 frames and 118 full controller rows match. Reductions 4.37%/4.51%, mean 4.44%, miss the frozen 5% threshold. Original default remains active; no further startup tuning grid |

1. **Search recovery using the whole body's contact response.** The
   [36-world diagnostic](../sdk/discovery/creature_torque_map_route_native_v3.json)
   verifies solved reactions and empty-cone fallback, with no recovery.
   The [coupled predictor](../sdk/discovery/coupled_contact_response_result_v1.json)
   passes its retained-state mean-error screen, with substantial joint-velocity
   error and worse individual states preserved. The [first action comparison](../sdk/discovery/creature_response_probe_native_failure_v1.json)
   retains 84 complete worlds and full replay, but small state differences
   begin before the later interventions; its exact-prefix rule refuses a score.
   Declare a fresh numerical-matching successor with unit-specific bounds and
   repeated identical-action controls that bound background dispersion before
   physics. Keep the failed comparison immutable. Useful action ordering is
   required before broad factored recovery search and fresh full-capture
   confirmation of diverse leads. Do not repeat the foot-only force grid.
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
