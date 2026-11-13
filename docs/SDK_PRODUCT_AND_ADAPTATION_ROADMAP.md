# SDK Product and Adaptation Roadmap

This is the current work order. Read this page first; search the
[dated history](SDK_PRODUCT_AND_ADAPTATION_ROADMAP_HISTORY_2026-11-01.md)
only for a specific decision or experiment. The goal is adaptable, self-learning
and self-correcting locomotion that can be used in the SDK and live Studio.

## Current execution order - 2026-11-12

**Priority: search many actual creature variants and controller candidates,
then apply full scrutiny to the useful and diverse results.** The 24-body
breadth search and fresh twelve-second confirmation are complete. The frozen
condition-known choice fails its declared comparison criterion against both
baseline and fixed profile 27. Keep that negative result; the next work must
address the revealed controller gaps and turn existing components into useful
SDK and Studio behavior.

| Current evidence | What it establishes |
| --- | --- |
| [Population v2](../sdk/discovery/population_discovery_native_result_v2.json) | 64 controller profiles, 256 discovery worlds and 16 canaries on S169 |
| [Full-capture shortlist](../sdk/discovery/population_shortlist_native_result_v1.json) | 20 fresh twelve-second worlds; profiles 55/27 preserve weak-left eligibility at the two exposed starts, with a nominal tracking tradeoff |
| [Actual-creature breadth](../sdk/discovery/creature_breadth_native_result_v1.json) | 240 two-second worlds across 24 bodies, five profiles and two conditions: 171 eligible, 69 performance failures, zero invalid; 69 shortlist entries in 37 of 48 groups |
| [Diverse confirmation](../sdk/discovery/creature_confirmation_native_result_v1.json) | 284 fresh twelve-second worlds, both conditions and two new starts: 221 eligible, 63 performance failures, zero invalid; 408,960 decisions and 2,044,800 native samples independently replayed |
| Confirmation choice comparison | Both-start eligibility in 48 body/condition groups: baseline 30, frozen choice 33, fixed profile 27 36. Choice loses groups that each comparator passes, so neither declared comparison passes |
| Confirmation gaps | Four groups have a passing tested alternative to the failed choice; eleven weakened-body groups have no tested candidate passing both starts. These are descriptive findings, not a refitted selector |
| [Shared-readback route](../sdk/discovery/creature_readback_native_result_v1.json) | Six fresh worlds, four bounded batches, 144 exact original-path observation matches and 720 independently verified native samples; full capture |
| Preserved refusals | [Population v1](../sdk/discovery/population_discovery_native_failure_v1.json) opened zero population worlds; [creature route v1](../sdk/discovery/creature_route_native_failure_v1.json) constructed CPU models but opened zero GPU worlds |
| Scope | Finite exposed development evidence; no learned selection, useful online correction, broad morphology qualification, recovery, real-time or release authority |

The confirmation retains all 69 discovery shortlist entries, baseline and
fixed profile 27, including all eleven empty discovery groups. The choice was
frozen before its new starts (-0.003 and 0.005 m/s); it was not refitted.
All 139 applicable zero-world controls passed before physics. Failed episodes
have null quality, and paired tracking comparisons include only groups where
both policies pass both starts. These results do not overturn the earlier
finite positive at different starts: S169 profile 55 now fails one new start,
while profile 27 passes both.

1. **Complete the Studio recovery handoff.** Fast walking must detect a fall,
   enter recovery and resume walking on the same native bodies. The current
   fast worker stops advancing the recovery ledger, so a fresh observation
   epoch must start at a measured completed boundary. Preserve body identity,
   global callback sequence and per-step energy/contact measurements; do not
   reset world state, invent missing cumulative history or reuse stale clocks.
   Validate the actual production route with the smallest adequate development
   ghost before testing useful recovery and the visible Studio interaction.
   The [fresh observation route](../sdk/explorer/studio/live_recovery_epoch_native_result_v1.json)
   now passes in one native world after 31 adapter checks and ten reader controls.
   All 360 steps complete; boundaries 300-302 retain the same nine body instances
   and two contiguous staging pairs, reconstructed exactly by the independent
   reader. Next map the complete measured energy partition, then integrate fall
   detection, recovery command ownership and walking resume on those bodies.
   Profile startup and stepping on that route. The short probe observed
   18.504827 seconds through stand-up and 0.952072 seconds for 119 walking steps.
   This is not a matched speed comparison or a new fifteen-second result; the
   earlier fifteen-second run retains its 43.852625 and 29.662299 second timings.
2. **Broaden candidates where confirmation exposed gaps.** Keep the four
   selection misses separate from the eleven groups with no passing tested
   candidate. Search factored creature/controller cohorts through the public
   descriptor/compiler and batched controller, retain every failed body and
   condition, and keep fixed profile 27 as a finite comparator. Select on
   full-horizon eligibility before tracking quality, then challenge diverse
   leads at fresh starts. Do not adopt or retune the failed frozen lookup
   inside its consumed confirmation.
3. **Build a declared learning corpus and held-out evaluation.** Condition-known
   choices are oracle comparisons, not trained Tier 2. A broader learned
   provider needs explicit morphology features, a separate training contract
   and untouched evaluation groups. Exposed discovery and confirmation records
   do not become training or qualification data retroactively. Earlier
   [contextual-memory work](../sdk/discovery/gpu_contextual_influence_closure_v1.json)
   verified influence and feedback mechanics, but memory missed its benefit
   criterion in every group. Do not reward an unobserved alternative merely
   because the selected action failed; preserve memory-off, reset and rollback
   controls when testing useful correction.

## How work advances

Use the existing [qualification economy rule](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#qualification-economy-and-audit-growth-control):
new experiments normally add declarations to shared runners/readers. Add code
for a new interface, invariant or evidence shape. Keep full historical audits
in their specified lane; run the complete applicable safety gate before physics.
Native work requires a clean pushed prospective freeze and owned containment.
A failed attempt keeps its identity and original evidence.

The readback route took 0.666 seconds for shared reads versus 0.956 seconds for
original reads on the same prepared states. That short diagnostic grants no
whole-run speedup claim. The confirmation retains full capture in two-world
chunks; its 92.2-minute native worker time is descriptive, not a matched
throughput or real-time result.

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
