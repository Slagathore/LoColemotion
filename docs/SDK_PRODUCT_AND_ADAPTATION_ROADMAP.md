# SDK Product and Adaptation Roadmap

This page owns the current work order toward adaptable, self-learning and
self-correcting locomotion in the SDK and live Studio. Search the
[dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md)
for earlier decisions; individual result records retain the detailed evidence.

## Current execution order - 2026-11-14

**Search many actual bodies and controller trajectories cheaply, then apply
fresh full-capture scrutiny to useful, diverse leads.** Walking discovery found
finite useful profiles. The frozen condition-known selector failed confirmation,
and self-righting still has no qualifying controller after 13 cohorts.

| Current evidence | Verified result and boundary |
| --- | --- |
| [Walking confirmation](../sdk/discovery/creature_confirmation_native_result_v1.json) | 284 fresh twelve-second worlds; 221 eligible and 63 failed. Both-start eligible groups: baseline 30/48, frozen choice 33/48, fixed profile 27 36/48. Neither declared choice comparison passes |
| Adaptation gaps | Four groups have a passing alternative to the failed choice; eleven weakened-body groups have no tested candidate passing both starts. No refitted or learned selector is qualified |
| [Studio handoff](../sdk/explorer/studio/live_handoff_native_failure_v2.json) | Fresh measured entry and 240 passive intervals replay correctly. The inverted body times out without active recovery or resumed walking |
| [Latest righting cohort](../sdk/discovery/creature_support_sharing_native_result_v1.json) | 192 fresh twelve-second worlds on 24 bodies; zero recoveries, progress leads or joint violations. Of 96 new-controller worlds, 47 beat their fresh selected reference; best gain is 2.962 degrees, below five. Thirteen cohorts retain 2,896 valid recovery failures |
| [Earlier path and geometry checks](../sdk/discovery/creature_body_moment_geometry_result_v1.json) | 26 leads across 21 bodies are clear at every retained sample. Best rotation is 24.485 degrees. Three leads overlap; one retains a useful pre-overlap peak. Geometry is 9.503 times faster on retained inputs; native throughput remains unmeasured |
| [Support-transfer diagnosis](../sdk/discovery/creature_support_sharing_diagnosis_v1.json) | 52 controls. On one exposed body, the old foot withdraws and replacement torque has 0.040 Nm mean tracking error, yet a 36-interval transfer loses 0.534 degrees. About 74.4% of its proposed moment comes from force that joint torques cannot identify; ground reaction remains unmeasured |
| [Torque-map route failure](../sdk/discovery/creature_torque_map_native_failure_v1.json) | 304 controls passed; 24 worlds opened. Twelve completed three seconds; twelve stopped at interval 203 on numerical cone construction. All 6,756 recorded decisions and 33,780 samples replay. Six derived scalar cases reproduce cancellation; broad search remains unrun |
| [Torque-map v2 closeout](../sdk/discovery/creature_torque_map_native_failure_v2.json) | 312 controls before each run; all 24 full route worlds pass replay and coverage. Broad search completes 210 worlds, interrupts ten on a zero-friction cone error and leaves twenty unopened. All 126 completed new-controller worlds lose to their fresh selected references; zero recoveries or progress leads, five joint-violation worlds |
| Scope | Exposed development evidence. No learned selection, useful online correction, broad morphology qualification, recovery, real-time or release authority |

The [portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md)
links the earlier controller cohorts and capture diagnostics. Their original
declarations, failed outcomes and detailed result records remain authoritative.

1. **Measure the actual contact forces before another recovery search.**
   The [v3 diagnostic component](../sdk/discovery/creature_torque_map_component_v3.json)
   passes 330 controls, repairs empty zero/narrow-cone classification and
   retains exact failed planning memory. All 8,640 earlier route decisions
   and 43,200 samples replay with byte-identical audit output. From a clean
   pushed freeze, run the declared 36-world three-second full route on bodies
   0, 16 and failed body 21. Require fallback coverage and every solved contact
   force to reconcile against the free-root constraint force. Compare proposed
   turning moments with measured foot and torso reactions before choosing
   another force-model family. The [v2 broad failure](../sdk/discovery/creature_torque_map_native_failure_v2.json)
   remains negative: all 126 completed new-controller worlds underperform.
   Do not repeat that unchanged grid. Return to broad factored discovery and
   fresh full-capture confirmation for useful, diverse leads after diagnosis.
2. **Give Studio performance a bounded, independent task.** After the contact
   diagnostic and before another large recovery cohort, profile startup and
   stepping on the current installed build. Separate one-time loading and
   compilation from steady-state simulation, retain the same body and capture
   settings, fix a measured bottleneck, then repeat the matched run. Useful
   recovery is not a prerequisite for this task. The discovery controller's
   53.6% interval share identifies a separate profiling target; it is not a
   measured Studio speed improvement.
3. **Complete the Studio behavior with a useful controller.** Keep the existing
   fresh observation epoch, body identity, motor ownership, native clocks and
   measured work. The required end-to-end run is walking, fall, active recovery,
   recovery completion, then 120 resumed walking steps on the same body.
   No pose reset, invented history or relaxed entry/joint-limit gate is allowed.
   Installed interaction and startup/stepping performance remain separate work:
   the earlier fifteen-second run took 43.852625 seconds through stand-up and
   29.662299 seconds for walking. The shorter energy probe is descriptive and
   does not establish a matched speed improvement.
4. **Build useful adaptation with separate training and evaluation.** Keep the
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
