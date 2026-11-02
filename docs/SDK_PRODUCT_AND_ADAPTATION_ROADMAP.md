# SDK Product and Adaptation Roadmap

This is the current work order. Read this page first; search the
[dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md)
only for a specific decision or experiment. The goal is adaptable, self-learning
and self-correcting locomotion that can be used in the SDK and live Studio.

## Current execution order - 2026-11-01

**Priority: search many actual creature variants and controller candidates,
then apply full scrutiny to the useful and diverse results.** The completed
population varied controllers on one S169 body. It did not search different
creatures. A separate small condition-choice comparison has not been launched;
include that question in the broader program when it helps select a usable policy.

| Current evidence | What it establishes |
| --- | --- |
| [Population v2](../sdk/discovery/population_discovery_native_result_v2.json): 64 profiles, 256 discovery worlds, 16 canaries | Candidate discovery on one body, nominal and left-side 75% actuation |
| [Full-capture shortlist](../sdk/discovery/population_shortlist_native_result_v1.json): 20 fresh worlds, 12 seconds each | Profiles 55 and 27 stay eligible under weakened actuation at both exposed initial lateral velocities; baseline, 08 and 18 fail |
| Nominal-body tradeoff | All five profiles pass both starts; mean velocity errors are baseline 0.08838, 08 0.08573, 18 0.08778, 55 0.09194 and 27 0.09115 m/s |
| [Preserved population v1 failure](../sdk/discovery/population_discovery_native_failure_v1.json) | Canary failure; zero population worlds opened |
| [Mixed-creature native route gate](../sdk/discovery/creature_native_component_v1.json) | 106 controls pass, including the 32-shape controller check and new model transport/reader controls; zero native worlds; four-world, three-shape native check declared |
| Scope of these runs | No learned selection, online correction memory, new morphology result, recovery qualification, real-time qualification or release authority |

The shortlist's 28,800 controller decisions and 144,000 native samples were
independently replayed. Its 14 eligible and six failed episodes remain finite
development evidence. Failed episodes have no quality score. Earlier
[learned influence and memory experiments](../sdk/discovery/gpu_contextual_influence_closure_v1.json)
remain retained; memory mechanics worked, but useful memory benefit was unproved.

1. **Verify the native route for creature variation.** Shared model transport,
   execution and independent replay are implemented and pass the zero-world
   gate. Run the declared four-world, three-shape construction/step check from
   a clean pushed freeze. It checks per-creature geometry, compiled constants,
   actuator conditions and observation/solver joins. Native execution remains
   unproved until that attempt completes; the gate grants no locomotion result.
2. **Run a bounded breadth search.** Declare the creature population, controller
   references (including 08, 18, 55 and 27), baseline, conditions, budget,
   selection rule and reduced-capture limits before launch. Retain all failures
   and rank within each creature/condition; do not advance only easy bodies.
   Use full-capture canaries and live validation. Keep evaluation groups closed.
3. **Challenge a frozen, diverse shortlist.** Use fresh worlds, full capture,
   independent replay and the prospective acceptance criteria. Test whether
   useful condition-based choices exist before fitting inference. A choice
   supplied with the true condition is an oracle comparison, not trained Tier 2.
   Training needs a separate declared corpus and held-out test; reduced discovery
   records do not become training or qualification data retroactively.
4. **Turn useful results into SDK and Studio behavior.** After the first breadth
   batch, take a product checkpoint before another narrow tuning sequence.
   The next Studio increment is fall detection, live recovery handoff and resumed
   walking on the same bodies. Profile startup and stepping on that actual route.
   The retained Godot measurements are 43.852625 seconds to stand up and 29.662299
   seconds for 15 walking seconds; they have not been rerun by this documentation
   change. Do not reset world state or reuse stale recovery clocks to fake a handoff.

## How work advances

Use the existing [qualification economy rule](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#qualification-economy-and-audit-growth-control):
new experiments normally add declarations to shared runners/readers. Add code
for a new interface, invariant or evidence shape. Keep full historical audits
in their specified lane; run the complete applicable safety gate before physics.
Native work requires a clean pushed prospective freeze and owned containment.
A failed attempt keeps its identity and original evidence.

Tier 2 means a frozen learned provider with independent evidence of useful
influence. Tier 3 adds bounded, reversible memory with reset, rollback and
memory-off controls. Neither is established by selecting a hand-authored profile.
[Detailed tier requirements](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md#adaptation-tiers)
remain the design contract.

The [master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md),
[portable lineage](SDK_PORTABLE_BALANCED_WAVE_SUCCESSOR_BOOTSTRAP.md),
[research contract](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md),
[architecture](LOCOMOTION_ARCHITECTURE.md) and
[release support matrix](../sdk/release/quadruped_support_matrix.json)
remain authoritative for their own claims. Experiments do not automatically
advance crate versions or release status; a versioned SDK release must deliberately
rebind its manifests and package records.

<a id="immediate-order-of-work"></a>

The [historical immediate order of work](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md#immediate-order-of-work)
is retained for old links; the current order is above.
