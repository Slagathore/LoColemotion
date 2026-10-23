# SDK2 Adaptation Research Bootstrap

- **Status:** research proposal and work menu. It is architecture input, not
  accepted LoColemotion evidence, and it changes no frozen result, gate,
  threshold or support flag.
- **Recorded:** 2026-10-23, against `main` at `5062134`.
- **Scope:** forward research toward Tier 2, Tier 3 and the SDK2 claim targets
  (R06, R07, R09, R11, R12, R25 and force-aware recovery). SDK1 release work,
  Studio speed and the live recovery handoff are deliberately out of scope here.
- **Authorities this document serves, not replaces:**
  [product and adaptation roadmap](SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md),
  [provider contract](../sdk/adaptation_provider/provider_contract_v1.json),
  [Tier 2 architecture](../sdk/adaptation_provider/tier2_architecture_v1.json),
  [release contract](../sdk/release/quadruped_release_contract.json) and the
  [research sources ledger](research/LOCOMOTION_RESEARCH_SOURCES.md), whose
  research-use rules apply to everything below.

## 0. How to use this document

This is a bootstrap for the implementing session. It answers four questions:

1. What published work can be reused to reach a trained Tier 2 provider and a
   first Tier 3 adaptation faster than designing every piece from scratch?
2. Exactly where does each idea attach to the code that already exists?
3. What does each idea cost, what can go wrong, and what would count as done?
4. In what order should the work happen?

Read sections 1-3 first. Sections 4-12 are the individual leapfrogs (L0-L8)
and the evidence/statistics upgrades (S1-S7). Section 13 maps them onto the
SDK2 gates, section 14 is the recommended sequence, section 15 lists traps,
section 16 positions the work against prior art, and section 17 is the source
table with links, code and licenses.

Rules that carry over unchanged:

- A paper result is an external observation. It enters LoColemotion knowledge
  only through the usual declare, qualify, run, retain, close lifecycle.
- GPU (MuJoCo Warp) results are candidate-generation evidence only. CPU MuJoCo,
  Rapier/Parry and Godot/Jolt native challenges remain the authority.
- Strict physics, safety, contact and no-cheat gates stay unnormalized booleans.
  Reward can rank candidates; it never waives an invariant.
- Failed, invalid and refused attempts are retained and counted.
- Before importing any third-party code, record its license in
  [third-party notices](../THIRD_PARTY_NOTICES.md). Prefer reimplementing small
  algorithms (MAP-Elites, kernel regression, the clamp chain) over importing a
  framework, so determinism and identity stay under project control.

## 1. Executive summary

The provider seam that the learning literature needs already exists. The core
validates a bounded per-actuator velocity correction, clamps it three times and
falls back bit-exactly to the deterministic baseline. In research terms that is
**residual policy learning behind a runtime safety shield, with history and
memory inputs ready for adaptation**. What is missing is the first thing that
plugs into it, plus the throughput to produce it.

The fastest route is not a new architecture. It is to reuse established recipes
in an order that produces a working end-to-end loop early:

| ID | Leapfrog | Main sources | Contract change | Effort | Feeds |
| --- | --- | --- | --- | --- | --- |
| L0 | Batched GPU control loop: one host round trip per 1/120 s command, physics substeps captured on device | MuJoCo Warp, MuJoCo Playground, Rudin et al. | None | Small-medium | Everything below |
| L1 | Quality-diversity search instead of single-best search: an archive of diverse working gait profiles per body | MAP-Elites, Cully et al., CMA-ME, QDax | None | Medium | Tier 1 encyclopedia, L2, L6, R06/R07 |
| L2 | Retrieval provider: nearest neighbours plus locally weighted interpolation over the experience encyclopedia | REGENT, episodic control, locally weighted learning | None (v1 bridge) | Small | First Tier 2 provider, Tier 3 substrate |
| L3 | Recoverability monitor: revoke provider authority near the edge of what the baseline can recover from | Simplex, shielding, safety filters | Additive fallback reason | Small-medium | "Never worse than baseline", force-aware recovery |
| L4 | Residual RL with the exact clamp chain inside training, zero-initialized output, domain randomization | Residual policy learning, residual RL, PMTG, CPG-RL, Walk These Ways | None for v1; v2 for parameter modulation | Medium | Tier 2, R09, R11, R12 |
| L5 | History-based adaptation (RMA-style), including engine identity as a hidden factor | RMA, UP-OSI, Lee et al. 2020 | None | Medium | "Tier 2.5", cross-engine transfer, R25 support |
| L6 | Tier 3 episodic adaptation over a versioned repertoire: trial-and-error on a frozen prior | Intelligent Trial and Error, reset-free trial and error, REGENT, LocoFormer | None (memory digest already exists) | Medium-large | Tier 3 |
| L7 | Sampling-based MPC teacher on GPU, distilled into the provider with DAgger | Predictive Sampling / MJPC, MPPI, DAgger | None | Medium-large | Recovery, rough terrain, dense labels |
| L8 | Morphology-conditioned network only when topology varies | GenLoco, MetaMorph, URMA, Body Transformer | None | Large; deferred | Multi-topology SDK phase |

Harness-side upgrades that save compute and sharpen claims:

| ID | Upgrade | Sources | Feeds |
| --- | --- | --- | --- |
| S1 | Robust aggregate reporting for development comparisons (IQM, stratified bootstrap CIs, performance profiles) | Agarwal et al. 2021 (rliable), Henderson et al. 2018 | Every learning comparison |
| S2 | Equivalence and non-inferiority by two one-sided tests with prospectively frozen margins | Schuirmann 1987, Lakens 2017 | R25, "never worse than baseline" |
| S3 | Sequential designs and anytime-valid inference so campaigns can stop early without inflating error | O'Brien-Fleming, Ramdas et al. 2023 | Every campaign's compute cost |
| S4 | Active level-set estimation to map supported and unsupported morphology regions | Gotovos et al. 2013 | R06, R07 |
| S5 | Conformal calibration of the provider's confidence and support thresholds | Angelopoulos and Bates | Tier 2 safety envelope |
| S6 | Ensemble disagreement as an uncertainty signal for learned providers | Lakshminarayanan et al. 2017 | Tier 2 `confidence` |
| S7 | A specification-gaming catalogue turned into explicit no-cheat gates | Lehman et al. 2020 | GPU search and RL |

**If only three things happen next:** L0 (stop paying a host round trip per
physics step), L1 plus L2 (an archive and a retrieval provider give a working,
auditable Tier 2 loop with no neural training), then L3 (so the "never worse
than baseline" claim is actually defensible before any learned influence goes
live).

## 2. Where the project stands, in the terms this document uses

These are facts read from the repository at `5062134`.

**The provider seam (QSDK-R21, closed).**
[`provider_contract_v1.json`](../sdk/adaptation_provider/provider_contract_v1.json)
and [`adaptation.rs`](../sdk/core/src/adaptation.rs):

- Inputs: bounded quadruped descriptor, canonical state, command,
  deterministic baseline, up to **64** history entries (state, command,
  baseline and applied correction), controller context, versioned provider
  memory with a verified digest (opaque state capped at **65,536** canonical
  bytes), safety envelope and seed.
- Output kind: exactly one, `canonical_velocity_delta_rad_s`, in actuator
  order, plus `confidence`, `support_distance`, a status
  (`applied`, `no_proposal`, `refused`, `unsupported`, `uncertain`, `reset`),
  next-memory digest, diagnostics, candidate experience and provenance.
- Composition: validate, bind response to request digest, require applied
  status plus confidence and support, then absolute clamp, per-step slew clamp,
  actuator-speed clamp, reasoned receipt. Absent or rejected providers produce
  binary64-bit-exact baseline velocities.
- The safety envelope has static `minimum_confidence` and
  `maximum_support_distance` thresholds and per-actuator absolute and slew
  limits.

**The Tier 2 pipeline (QSDK-R22, closed on fixtures).**
[`tier2_architecture_v1.json`](../sdk/adaptation_provider/tier2_architecture_v1.json)
already defines episode, candidate chapter, frozen corpus, model candidate,
three-engine qualification and promotion, with `online_weight_mutation_permitted: false`
and a `tier3_extension` requiring an immutable base model plus reset and
rollback. Its qualification records are synthetic fixtures; no model exists.

**The experience encyclopedia.**
[`experience_encyclopedia_contract_v1.json`](../sdk/adaptation_provider/experience_encyclopedia_contract_v1.json)
is a create-only, hash-chained, content-addressed journal of candidate
experiences with deterministic characterization features (velocity error, tilt,
torso height, contact fraction, fallback and provider-influence fractions). A
chain head digest is therefore already a natural, rollback-able memory version.

**The body space.** [`BoundedQuadrupedDescriptor`](../sdk/core/src/quadruped.rs)
is a fixed-topology, **six-axis continuous box**: torso length and width scale,
upper-limb length fraction, hip span, foot radius and front-limb mass scale,
each normalized by a declared deviation (0.10, or 0.05 for the length fraction).
Eight velocity actuators (two per leg). This matters: most morphology-general
learning papers solve a much harder variable-topology problem than SDK2 needs.

**The controller.** [`BalancedWaveProfile`](../sdk/core/src/controller.rs) is a
parameterized gait generator (stride, heading and cross-track gains, swing-knee
speed limits, steering fraction bounds, forward-velocity hip correction and a
family of mode identifiers). The controller already contains a
**predicted-tilt and contact steering authority guard**
(`steering_guard_full_authority_maximum_tilt_rad`,
`steering_guard_minimum_authority_tilt_rad`,
`steering_guard_minimum_support_contact_count`,
`steering_guard_prediction_horizon_s`, `steering_guard_floor_hold_steps`).
That is a Simplex-style authority monitor for steering; L3 generalizes it.

**Timing.** The portable command runs at **1/120 s**. MuJoCo integrates five
1/600 s `implicitfast` steps per command
([engine comparison](../sdk/docs/ENGINE_INTEGRATION_COMPARISON.md)). Sixty-four
history entries therefore cover about **0.53 s**.

**GPU commissioning.** The
[quadruped probe closure](../sdk/discovery/gpu_quadruped_probe_closure_v1.json):
four GPU and four fresh CPU worlds of the actual S169 body, 1,200 internal steps
each, all 9,600 rows independently checked, named force sensors exact, maximum
CPU/GPU root difference 4.01 mm, contact counts differing in 659/4,800 paired
steps and clamp branches in 137/38,400 actuator samples. The cold first GPU step
took 94.6 s and later stepping 16.6 s. In
[`gpu_quadruped_probe.py`](../sdk/discovery/gpu_quadruped_probe.py) the control
for every world is computed in Python on the host and copied to the device every
internal step. That was right for commissioning and is the first bottleneck for
search.

**SDK2 gates.** In the release contract R06, R07, R12 and R25 are `missing`.
R09 is **contradicted** by BW34Y (rough-yaw rescue selected `NONE`: one of three
seeds walked, the required comparator seed regressed to eleven failed gates).
R11 is **contradicted** by BW6N (the required 3/3 paired sensor-noise walking
gates were not met). The MuJoCo Warp semantic-ceiling readiness gate still
accepts **0/5** production metric sources.

**Prior-art ledger.** The
[research sources ledger](research/LOCOMOTION_RESEARCH_SOURCES.md) already
covers DReCon, QWM, UniLegs, Coros et al. 2011, Shared Modular Policies,
MetaMorph, Universal Morphology Control, URMA and LocoFormer. This document
builds on that ledger and does not repeat its adoption decisions.

## 3. Diagnosis: why Tier 2 has not started

The bottleneck is not a missing algorithm. It is ordering:

1. **Verification infrastructure ahead of the first experiment.** Six MuJoCo
   Warp contracts exist, their production semantic ceilings and all five
   production metric definitions are unresolved, and no training run has
   happened. The 2026-10-22 roadmap already authorizes a separate discovery
   lane that does not wait for those contracts. Use it.
2. **Acceptance-grade auditing applied to exploration.** Independently
   re-reading every row and reopening every artifact is right for a claim. It is
   too expensive for thousands of search candidates that will mostly be
   discarded. Proposal: three explicit evidence weights.

   | Weight | Use | What is retained | Who may consume it |
   | --- | --- | --- | --- |
   | Exploration | Search batches, RL training, archive filling | Declaration, source and runtime identity, seeds, per-candidate summary row, outcome, failure code, clamp-branch counts, hash of the batch | Only the next search batch and shortlist selection |
   | Development | Shortlist challenge, shadow evaluation | Full traces for the shortlist, independent reader | Development decisions, encyclopedia candidates |
   | Acceptance | Gate claims | The existing full closure lifecycle | Release contract and support matrix |

   Promotion between weights always re-runs the candidate fresh at the higher
   weight. Nothing is upgraded retroactively.
3. **Host-side control per physics step.** See L0.
4. **No first provider.** L2 gives one in days, without training, and it doubles
   as the baseline every learned provider must beat.

## 4. L0: Make the GPU route fast enough to search

**Problem.** The commissioning probe computes controls in a Python loop and
copies them to the device every 1/600 s internal step. At 4 worlds that is fine;
at thousands it is the whole cost.

**What the sources show.** MuJoCo Playground trains locomotion policies on MJX
and MuJoCo Warp with thousands of parallel worlds and reports minutes-scale
training for quadruped joystick tasks. Rudin et al. (2021) showed that
massively parallel PPO on one GPU trains blind quadruped locomotion in minutes,
with a terrain curriculum. Both keep the policy and physics on the device and
batch every step.

**Options.**

| Option | How | Pros | Cons |
| --- | --- | --- | --- |
| A. Batched Rust core on host, decimated | One FFI call computes commands for all N worlds per 1/120 s command; five 1/600 s physics steps run on device inside a captured CUDA graph; one copy each way per command | Single controller implementation; identity and conformance unchanged | Host CPU becomes the limit at very large N; still a sync per command |
| B. Discovery-only controller kernel on device | Re-implement the balanced-wave controller in Warp for search only; conformance-test it against the Rust core on randomized inputs at a declared float32 tolerance | Fully on device; highest throughput | Two implementations can drift; every shortlisted candidate must be re-run through the Rust core |
| C. Parameter-only search with fixed open-loop schedules | Search over profile parameters but replace feedback terms with schedules on device | Simple | Not the real controller; poor transfer; not recommended |

**Recommendation.** Start with A. Measure host-controller time, transfer time
and device stepping time separately, as the roadmap already requires. Move to B
only if the measured host share stays dominant at the batch size the search
actually needs, and treat B as a candidate generator whose output is always
re-run through the Rust core.

**How.**

1. Add a batched entrypoint to the core (`policy_step_batch` over contiguous
   arrays of N states, returning N command vectors) behind the C ABI. Keep the
   scalar path as the conformance oracle: batch output must equal N scalar calls
   bit-for-bit on CPU.
2. Capture the five internal `implicitfast` steps per command in one CUDA graph.
   Static shapes are required; bucket by topology.
3. Use pinned host buffers and one `wp.copy` in each direction per command.
4. Keep the commissioning capture available as a sampled mode (for example 1
   world in 256 fully traced) so branch-sensitive behavior is still seen.
5. Retain clamp-branch counters per world on device; they are cheap and they are
   the known CPU/GPU divergence mechanism.

**Done means.** A declared throughput measurement (world-steps per second,
split into host control, transfer, device stepping and capture) at three batch
sizes, with the scalar-versus-batch conformance passing. No training claim.

## 5. L1: Quality-diversity search instead of single-best search

**Sources.** Mouret and Clune 2015 (MAP-Elites); Cully, Clune, Tarapore and
Mouret 2015 (*Robots that can adapt like animals*, Intelligent Trial and Error);
Vassiliades and Mouret 2018 (directional "iso+line" variation); Fontaine et al. 2020
(CMA-ME); the QDax library as a reference implementation.

**What it is.** Instead of searching for one best parameter set, MAP-Elites
divides a low-dimensional **behavior descriptor** space into cells and keeps the
best-performing solution found for each cell. The result is an archive of many
different working behaviors. Cully et al. built such an archive offline in
simulation for a hexapod and then, after damage, used Bayesian optimization
over the archive to find a compensating gait in a small number of physical
trials.

**Why it fits LoColemotion unusually well.**

- The roadmap's next step is a bounded candidate search. QD makes that search
  produce a reusable asset instead of one winner.
- The archive is a ready-made Tier 1 encyclopedia section, the training data
  for L2, and the prior for L6.
- QD retains every evaluation by construction. Failures are data.
- Single-objective gait search is deceptive: the best-scoring early candidates
  often lead nowhere. Diversity is a known remedy.
- The descriptor box is only six-dimensional, so a per-body archive is
  tractable.

**How.**

1. **Genome:** the numeric subset of `BalancedWaveProfile` that is safe to vary,
   with declared bounds. Mode identifiers stay fixed per archive.
2. **Behavior descriptors** (declare before running; two or three axes):
   achieved forward speed, achieved yaw rate, duty factor or mean torso height.
3. **Fitness for ranking only:** for example, velocity tracking minus energy.
   Strict gates (no torso contact, no fall, no invariant violation, no
   nonfinite value) decide eligibility before fitness is read.
4. **Bodies:** start with S169 only, then a declared grid or Sobol sample of the
   six-axis descriptor box. One archive per body, or the body descriptor as an
   extra context dimension.
5. **Variation:** iso+line operator first (simple, strong); CMA-ME emitters if
   progress stalls.
6. **Batch protocol:** each batch is declared (bounds, seeds, budget, selection
   rule) before it runs and retained at exploration weight. Adapting between
   batches is allowed; editing an observed batch is not.
7. **Clamp-branch and contact-count sensitivity** are recorded per candidate. A
   candidate whose success depends on a branch the CPU would take differently is
   flagged, not hidden.
8. **Shortlist:** freeze a shortlist from the archive, then run it fresh on CPU
   MuJoCo, Rapier and Godot against the unchanged baseline (development weight).
9. **Consider a second search lane on CPU Rapier.** The Rapier adapter is native
   Rust and can run deterministically in double precision. A public tutorial
   (section 17) reports about 50,000 MAP-Elites rollouts of a simple quadruped
   on deterministic Rapier in about 98 s. Its model was simpler than S169, so
   measure before relying on that figure. Searching in MuJoCo Warp and Rapier
   at the same time, and keeping only candidates that work in both, filters
   engine-specific exploits before the expensive native challenge. Godot/Jolt
   stays challenge-only.
10. **Held-out replay is the real test.** The same tutorial filled 240 of 400
    niches, yet only 27 of those elites stayed feasible on all five held-out
    terrains. Report archive coverage and held-out survival side by side.

**Pros.** Reusable archive; automatic negative retention; direct path to Tier 3;
low implementation cost (a MAP-Elites loop is short).

**Cons and risks.** Descriptor choice is a design decision that shapes
everything; choose it before seeing results. Archives are large; retain summary
rows, not full traces, at exploration weight. GPU-specific exploits will fill
cells (see S7); only native challenge removes them.

**Done means.** A retained archive for S169 with declared coverage and QD-score,
a frozen shortlist, and a native challenge reporting transfers and failed
transfers as counterexamples.

## 6. L2: A retrieval provider as the first Tier 2 provider

**Sources.** Sridhar et al. (REGENT): a simple retrieve-and-play nearest
neighbour agent is a strong baseline, and REGENT improves on it by conditioning
a model on retrieved neighbours. Blundell et al. 2016 (Model-Free Episodic
Control) and Pritzel et al. 2017 (Neural Episodic Control): acting from a
non-parametric episodic store learns fast. Atkeson, Moore and Schaal 1997
(*Locally Weighted Learning for Control*): kernel-weighted local regression for
control from stored experience.

**Why first.** It needs no neural training, it is deterministic, and it fills
the two fields that learned policies cannot fill honestly:

- `support_distance` = distance from the query to the nearest stored experience
  under a declared normalization;
- `confidence` = a declared function of neighbour agreement, neighbour success
  fraction and effective sample size.

Every proposal can name the encyclopedia entries it came from, and rolling back
means moving the chain head. It also satisfies the roadmap's requirement that
Tier 2 be "stronger than a lookup table": locally weighted interpolation infers
between stored points without an exact numeric match, and refuses outside
support.

**Design.**

- **Key:** normalized six-axis descriptor, task command, and a compact state
  summary (gait phase bucket, tilt, forward-velocity error, contact pattern).
  Keep the key under about 15 dimensions; nearest neighbours degrade in high
  dimension.
- **Value:** what was done and how it turned out. Two value types are possible.

  | Value type | Where it comes from | How it reaches the core today |
  | --- | --- | --- |
  | Per-step velocity correction | L4 or L7 logs | Directly as the v1 velocity delta |
  | Profile parameters | L1 archive | **Profile-difference bridge** (below) |

- **Profile-difference bridge (v1-compatible).** The provider keeps a second
  instance of the portable controller in its own memory, running with the
  retrieved profile on the same observations, and proposes
  `command_retrieved − command_baseline` as the velocity delta. The core's
  clamps bound it as usual. This delivers parameter-level adaptation with no
  contract change. The shadow controller's state must live in provider memory
  and be reset with it; budget it against the 64 KiB opaque-state cap.
- **Interpolation:** Gaussian-kernel weighted average over the k nearest
  successful neighbours, bandwidth declared in advance.
- **Multi-modality guard.** Two good but different corrections can average into
  a bad one (for example, step left versus step right). If the neighbour set
  splits into clusters that disagree beyond a declared threshold, return the
  dominant cluster or `uncertain`; never the mean.
- **Thresholds:** set `maximum_support_distance` and `minimum_confidence` by S5
  conformal calibration on a held-out calibration set, not by hand.

**Pros.** Days rather than weeks; fully auditable; deterministic; natural Tier 3
substrate; a strong baseline for every later learned provider.

**Cons.** Does not extrapolate (which is correct behavior here); lookup cost per
step (small stores are fine with brute force; use a k-d tree beyond tens of
thousands of entries); the state summary must be designed carefully.

**Done means.**

1. A shadow-mode evaluation in which the provider runs, its proposals and
   fallback reasons are retained, and no influence is applied.
2. A bounded-influence development comparison against the unchanged baseline,
   using S1 reporting.
3. A **shuffled-memory control** in that comparison: the same store with
   randomly permuted keys. A retrieval benefit that the shuffled store also
   produces is not a memory benefit (see RTPC in section 17).

## 7. L3: A recoverability monitor before any learned influence

**Sources.** Sha 2001 (Simplex); Alshiekh et al. 2018 (shielding); Ames et al.
2019 (control barrier functions); Wabersich and Zeilinger (predictive safety
filters); Brunke et al. 2022 (safe-learning survey).

**The gap.** Every current check is on the **proposal**: finite, ordered,
confident, inside support, inside clamps. None is on the **state**. A sequence of
individually valid corrections can steer the body, step by step, out of the
region the baseline can recover from. The Simplex idea is to switch back to the
verified controller **before** that boundary, not after it.

**Design.**

- Reuse the shape of the existing steering authority guard: an authority scale
  between 0 and 1 computed from predicted tilt over a short horizon and support
  contact count, with a floor-hold latch.
- Apply it to provider influence: `applied_correction = authority × clamped_correction`,
  or revoke entirely with a new fallback reason such as
  `outside_recoverable_envelope`.
- Fit the envelope from data the project already owns: SDK1 fall and recovery
  traces, and the failures retained by L1. Fit conservatively and declare the
  fitting set before the evaluation set.
- Add hysteresis so authority does not chatter at the boundary.

**Why not control barrier functions directly.** They need a dynamics model that
supports the required derivatives. Legged contact dynamics make that hard and
engine-dependent. An empirically measured, conservatively shrunk envelope is the
practical version; a learned safety filter can come later.

**Contract change.** Additive: a fallback reason and an optional authority scale
in the receipt. Keep v1 behavior bit-exact when the monitor is absent.

**Closest prior art.** The Simplex-enabled Safe Continual Learning Machine
(section 17) hands control from a learning student to a verified model-based
teacher near a safety envelope, on a real quadruped. Read it before designing
the switching logic. Its student keeps learning online; here the provider stays
frozen, and the monitor only removes authority.

**Done means.** A non-inferiority statement (S2) that provider plus monitor
fails no more often than the baseline, within a prospectively frozen margin, on
fresh worlds. Until that exists, "never worse than baseline" is a design goal,
not a claim.

## 8. L4: Residual RL, with the deployed clamp chain inside training

**Sources.** Silver, Allen, Tenenbaum and Kaelbling 2018 (*Residual Policy
Learning*); Johannink et al. 2019 (*Residual Reinforcement Learning for Robot
Control*); Iscen et al. 2018 (PMTG); Bellegarda and Ijspeert 2022 (CPG-RL);
Margolis and Agrawal 2022 (*Walk These Ways*); Rudin et al. 2021 and MuJoCo
Playground for the training recipe; Tan et al. 2018, Peng et al. 2018 and Tobin
et al. 2017 for dynamics and domain randomization.

**What it is.** A policy learns a correction that is added to a hand-designed
controller. Learning only the correction is far more sample-efficient than
learning the whole behavior, and it works even when the base controller is
imperfect. PMTG and CPG-RL apply the same idea to legged gait generators: the
policy modulates the generator's parameters (and optionally adds a residual),
which keeps the gait structure.

**Two recipes the papers make cheap.**

1. **Zero-initialize the output layer.** At step 0 the residual is exactly zero,
   so training starts from baseline behavior instead of from flailing.
2. **Train under the deployed clamps.** Apply the same absolute, slew and
   actuator clamps inside the training environment. Training unclamped and
   clamping afterwards deploys a policy that never saw its own outputs; this is a
   common and quiet failure. Implement the three clamps on device and
   conformance-test them against `resolve_adaptation_v1` on randomized vectors
   at a declared float32 tolerance.

**Design.**

- Observations: the same fields the provider request carries, including the
  baseline command and recent applied corrections.
- Action: `tanh(output) × maximum_absolute_correction` per actuator, then the
  slew and actuator clamps exactly as deployed.
- Reward: tracking and effort terms for learning only. Strict gates are episode
  terminations and are retained as failures.
- Penalize clamp saturation and opposition to the baseline, so the residual does
  not learn to fight the controller.
- Randomize friction, masses, motor strength, **sensor noise** (motivated by the
  BW6N R11 contradiction) and **observation and actuation latency** (R12 has no
  campaign yet). Declare the ranges before training.
- Evaluate in shadow first, then bounded influence behind L3.

**v1 velocity deltas versus a v2 parameter-modulation channel.** The roadmap
already lists "bounded parameter proposal" as an allowed provider output; the
v1 contract implements only velocity deltas.

| | v1 per-step velocity deltas | v2 bounded profile-parameter modulation (PMTG-style) |
| --- | --- | --- |
| Work | None; ready | New correction kind, per-parameter bounds and per-cycle slew, conformance |
| Dimensionality | 8 channels at 120 Hz | A handful of parameters per gait cycle |
| Training difficulty | Higher, noisier | Lower |
| Cross-engine transfer (hypothesis) | Weaker: fine corrections are tuned to one solver's contacts | Stronger: "lengthen stride" means the same thing in all three engines |
| What it can express | Anything, including one-step reactions | Only what the profile parameters express |
| Validation | Generic numeric bounds | Each parameter has a physical meaning and natural bounds |

Recommendation: first training run on v1, so the loop exists. Design v2 in
parallel. The likely end state is both: parameter modulation for gait shape,
small velocity deltas for the remainder. The transfer advantage of v2 is a
hypothesis to test, not an established fact.

**Risks.** Reward hacking of GPU contact behavior (S7); residuals that only work
with one engine's clamp branch; policies that rely on the slew limit as a
low-pass filter and misbehave when it changes.

**Done means.** A trained candidate whose shadow proposals, bounded-influence
results and native challenges are retained; a comparison against L2 and the
baseline using S1 statistics; failed transfers kept as counterexamples.

## 9. L5: History-based adaptation (RMA-style), "Tier 2.5"

**Sources.** Kumar, Fu, Pathak and Malik 2021 (RMA); Yu, Tan, Liu and Turk 2017
(UP-OSI); Lee et al. 2020 (teacher-student privileged learning); Nagabandi et
al. 2019 (fast adaptation with learned models).

**What it is.** Train the policy with privileged access to hidden environment
factors (friction, payload, motor strength) compressed into a small latent
vector. Then train an adaptation module that estimates that vector from recent
state-action history. At deployment the frozen policy adapts within a fraction of
a second with no weight change and no memory store.

**Fit.** The request already carries 64 history entries (about 0.53 s at the
1/120 s command rate). If a longer or decimated window is needed, the provider
can keep its own downsampled history in opaque memory within the 64 KiB cap.
Reset is trivial: clear the window.

**The leapfrog angle.** The body is known exactly; the unknowns are surface,
disturbance and **engine**. Randomize contact softness and impedance, friction
model parameters, timestep and actuator gains during GPU training so that the
spread covers the measured differences between engines, and let the adaptation
module absorb what remains. That is the sim-to-real recipe applied to
sim-to-sim. It does not create an equivalence claim; it is a way to make one
easier to earn.

Two external results bear on this (section 17):

- *PolySim* found that training across several simulators beat single-simulator
  training by a wide margin when tested zero-shot in an engine it never saw.
  That is the "randomize the engine away" half of the idea.
- Mohammed and Valdenegro-Toro found cross-engine transfer fragile and strongly
  seed-dependent. Expect variance, and use S1 reporting.

Inferring engine identity from history, rather than only randomizing over it,
did not appear in the sweep. If it works, it is a publishable result.

**Done means.** Native challenges in all three engines comparing the
history-adapted provider with the same provider given a zeroed latent, on fresh
worlds.

## 10. L6: Tier 3 episodic adaptation on a frozen prior

**Sources.** Cully et al. 2015 (Intelligent Trial and Error);
Chatzilygeroudis et al. 2018 (reset-free trial and error); REGENT and
Schmied et al. 2024 (retrieval-augmented decision transformer); LocoFormer
(already in the ledger) for long-context adaptation.

**What it is.** Keep the base provider frozen. During operation, record what was
tried and what happened, and use that versioned record to choose better next
behavior. Intelligent Trial and Error is the closest template: an offline
repertoire (L1) supplies a prior, and a Gaussian process over the repertoire's
descriptor space is updated after each trial to pick the next candidate.

**Design.**

- Memory version = encyclopedia chain head digest plus a session-local episode
  list. Reset returns to the frozen head; rollback moves to any earlier head.
- The provider's opaque memory holds the digest and a small working summary, not
  the episodes.
- Promotion of durable lessons stays offline through the existing Tier 2
  pipeline. Online weight mutation stays prohibited.
- Evaluation (already in the roadmap): memory enabled versus disabled on fresh
  task groups, with before and after decisions retained.

**Why not meta-RL or in-context RL now** (Duan et al. 2016, RL²; Laskin et al.,
Algorithm Distillation). Both require very large task distributions or full
learning histories, are expensive and unstable to train, and adapt inside
opaque activations. That makes "bounded, reversible, qualifiable" hard to
state. Repertoire-plus-retrieval delivers the same behavior with auditable
state.

**Done means.** A comparison of three arms on fresh conditions (for example a
perturbed foot radius or friction):

- memory on;
- memory off, i.e. reset to the frozen head. *RDumb* showed that plain reset is
  a strong baseline.
- shuffled memory.

Report with S1 statistics and retain every episode. Adaptation that does not
beat both controls is not a Tier 3 result.

## 11. L7: A GPU MPC teacher distilled into the provider

**Sources.** Howell et al. 2022 (*Predictive Sampling*, MuJoCo MPC); Williams
et al. 2017 (MPPI); Ross, Gordon and Bagnell 2011 (DAgger).

**What it is.** A sampling-based model-predictive controller rolls out many
short candidate futures from the current state and picks the best. With batched
GPU worlds that is cheap offline. Run it as a **teacher** only in situations
where the baseline fails (recovery entry, rough-terrain steps, latency), log its
corrections relative to the baseline, and distill them into the residual
provider with DAgger so the student is trained on the states it actually
visits.

**Pros.** Dense supervised labels instead of sparse reward; no reward hacking by
the student; the teacher is interpretable.

**Cons.** The teacher has privileged, exact knowledge of one MuJoCo model, so
distillation can encode engine-specific behavior; the teacher's identity and
model must be retained with every label; compute is significant.

**Best targets.** Force-aware recovery and R09 rough terrain, where BW34Y shows
the deterministic route alone is struggling.

## 12. L8: Morphology-conditioned networks, deliberately deferred

**Sources.** Feng et al. 2022 (GenLoco); Gupta et al. 2022 (MetaMorph);
Bohlinger et al. 2024 (URMA); Sferrazza et al. 2024 (Body Transformer);
Huang et al. 2020 (Shared Modular Policies). Several are already in the ledger.

**Assessment.** These solve variable-topology control. SDK2's body space is a
six-axis box with fixed topology. For it, a plain network that takes the six
normalized descriptor values as input is adequate and easier to qualify.
GenLoco's lesson that matters now is about the training distribution: randomize
morphology across the declared box during training, and evaluate on held-out
bodies.

Use the transformer-style encoders when the topology tokens from the UniLegs
adoption (ledger Source 3) become real, and use URMA or MetaMorph as a
**from-scratch comparison**: "deterministic floor plus residual" versus "one
end-to-end learned policy" on held-out bodies and across engines is a genuinely
informative experiment.

## 13. Evidence and statistics upgrades (S1-S7)

**S1. Robust aggregate reporting.** Agarwal et al. 2021 showed that point
estimates over few runs mislead, and recommended the interquartile mean,
stratified bootstrap confidence intervals and performance profiles (the
`rliable` library). Henderson et al. 2018 documented how seeds and
implementation details swing results. Use these for every development
comparison between providers. They do not replace frozen pass/fail gates.

**S2. Equivalence and non-inferiority.** R25 requires equivalence or
non-inferiority with frozen margins. The standard tool is two one-sided tests
(Schuirmann 1987; tutorial in Lakens 2017). The same test expresses "provider
plus monitor is not worse than baseline by more than δ". The hard part is the
margin; derive it from a declared practical tolerance, never from observed data.

**S3. Stop campaigns early, legitimately.** Group-sequential designs with
O'Brien-Fleming boundaries, or anytime-valid e-value methods (Ramdas et al.
2023), allow interim looks with error control preserved. Declare the looks and
spending rule up front. This can cut native-challenge compute substantially and
fits the prospective-declaration model exactly.

**S4. Map the supported region instead of sampling it blindly.** Gotovos et al.
2013 (active level-set estimation) uses a Gaussian process to sample where the
success probability is most uncertain relative to a threshold, finding the
boundary of the supported region with far fewer evaluations. In a six-axis box
this is practical and directly produces R06's "explicit unsupported regions".

Be precise about R07: sampling cannot prove continuous coverage. It can support
either (a) a distribution-free statement over a declared sampling distribution
(the existing 59-sample, 95%/95% zero-exceedance rule is Wilks' 1941 tolerance
result) or (b) a model-based statement under a declared smoothness assumption.
State which, and keep the compiler-totality refusal.

**S5. Calibrated thresholds.** Conformal prediction (Angelopoulos and Bates)
turns any score, such as nearest-neighbour distance or ensemble disagreement,
into a threshold with a finite-sample guarantee under exchangeability. Use it to
set `maximum_support_distance` and `minimum_confidence` on a held-out calibration
set, so the fallback rate and the error rate of accepted proposals are
predictable rather than hand-tuned.

**S6. Uncertainty for learned providers.** A small ensemble's disagreement
(Lakshminarayanan et al. 2017) is the simplest dependable `confidence` signal for
L4 and L5 providers. Calibrate it with S5.

**S7. Specification gaming.** Lehman et al. 2020 collect many cases of evolved
or learned simulated creatures exploiting physics-engine quirks. Turn the
relevant patterns (penetration-driven propulsion, jitter energy injection,
solver instabilities, clamp-branch dependence) into explicit no-cheat gates for
GPU search. LoColemotion has an unusual defense: a behavior that exploits one
engine's quirk will usually fail to transfer to the other two, so the three-engine
native challenge doubles as an exploit filter. Retain those failures as a
labeled counterexample set.

## 14. Mapping to the SDK2 targets

| Target | Current state | Most useful leapfrogs | First experiment |
| --- | --- | --- | --- |
| R06 bounded morphology family | missing | L1 archives per body, S4 level-set mapping, GenLoco-style training distribution | Level-set map of a 2-3 axis slice of the descriptor box with the baseline |
| R07 continuous coverage | missing | S4, the R07 precision note | Declare which kind of coverage statement is sought before sampling |
| R09 rough terrain | contradicted (BW34Y) | L4 with terrain curriculum (Rudin et al.), L7 MPC teacher, L3 | GPU residual training on declared terrain families; native challenge on fresh seeds |
| R11 sensor noise | contradicted (BW6N) | L4 and L5 with declared noise randomization, S6 | Shadow residual under BW6N-style noise; compare to baseline with S1 |
| R12 sensor latency | missing | L4 and L5 with latency randomization (Tan et al. 2018) | First declared latency campaign for the baseline alone, then the residual |
| R25 engine equivalence | missing | S2, S3, L5 | Freeze estimands and margins; run a sequential design |
| Force-aware recovery | open | L7, L3 | MPC teacher on retained recovery entry states |
| Tier 2 | interface only | L2, then L4 | Retrieval provider in shadow mode on S169 |
| Tier 3 | architecture only | L6 over L1 | Memory on versus off on a perturbed body |

## 15. Recommended sequence

Each phase has an exit condition. Phases after C can overlap.

| Phase | Work | Exit condition |
| --- | --- | --- |
| A | L0 batched control and CUDA-graph substeps; declare the exploration evidence weight | Throughput measured and split; batch/scalar conformance passes |
| B | L1 MAP-Elites archive for S169 | Archive and QD-score retained; shortlist frozen; native challenge run |
| C | L2 retrieval provider (profile-difference bridge) in shadow mode; S5 calibration | Shadow proposals and fallback reasons retained; thresholds calibrated |
| D | L3 recoverability monitor; first bounded influence of the retrieval provider | Non-inferiority (S2) against baseline on fresh worlds |
| E | L4 residual RL on v1 with randomization; v2 parameter channel designed | Trained candidate compared with L2 and baseline (S1); native challenges retained |
| F | L5 history adaptation; L1 extended across the descriptor box; S4 mapping | Three-engine challenge with and without adaptation; supported-region map |
| G | L6 Tier 3 memory over the archive | Memory on versus off on fresh conditions |
| H | L7 MPC teacher for recovery and terrain | Distilled student versus teacher versus baseline on fresh states |

The first public story worth telling is the end of phase D: a provider that
measurably helps, with a defended "not worse than baseline" result.

## 16. Traps to avoid

- Building more zero-world contracts before the first search batch exists.
- Treating a GPU result, a training curve or reward as physical evidence.
- Widening a tolerance to absorb a CPU/GPU branch disagreement.
- Averaging multi-modal corrections in the retrieval provider.
- Training a residual without the deployed clamps, then clamping afterwards.
- Starting with meta-RL or a transformer for a fixed six-axis body.
- Letting the evaluation population inform search or calibration.
- Normalizing a safety or no-cheat failure into a reward penalty.
- Calling the recoverability envelope safe before it is measured on fresh worlds.
- Replacing the deterministic baseline instead of building on it.

## 17. Positioning against prior art

A web sweep on 2026-10-23 looked for the closest existing work to each part of
the plan. Items marked † are not peer reviewed (repositories, tutorials, games).
The sweep cannot see internal or commercial tools, so "nothing found" means
nothing public was found, not that nothing exists.

**Residual plus runtime fallback is well covered for robots.**

- *Phy-DRL* (Cao, Mao, Sha and Caccamo, ICLR 2024) combines a model-based
  linear policy with a learned residual and a safety envelope, tested on a
  quadruped.
- The *Simplex-enabled Safe Continual Learning Machine* (Cao, Mao, Cai, Sha and
  Caccamo, arXiv 2409.05898) pairs a learning student with a verified
  model-based teacher that takes over near the safety envelope, on a real
  quadruped. This is the closest prior art to L3. Differences: its switch is
  state-triggered and its student keeps learning online. LoColemotion's provider
  is frozen and is gated on its own confidence and support as well.
- Wu, Zhang and Wang (*PLOS ONE* 2026, "A unified CPG-based and multi-agent
  control framework for low-cost quadruped robots") use a CPG prior with
  per-leg residuals, joint-limit and rate-limit projection, and a tilt and
  saturation supervisor that stops the gait. It is nearly the same clamp stack,
  on one robot in Isaac Sim, without a gated fallback.
- *Bayesian Controller Fusion* (Rana et al., arXiv 2107.09822) blends a learned
  policy with a hand-crafted prior according to uncertainty, so the prior
  dominates in unfamiliar states. It suggests an option for L2 and L4: scale an
  accepted correction by calibrated confidence instead of applying it in full.

**What is specific to LoColemotion here** is the provider's own
confidence/support gate, a bit-exact deterministic fallback that is tested as an
invariant, and the evidence lifecycle around promotion.

**Quality-diversity repertoires as adaptation memory are well covered.**

- Intelligent Trial and Error (Cully et al. 2015) started the line. Follow-ups
  include hierarchical repertoires for physical damage recovery (Allard et al.,
  ACM TELO 2023), GPU-accelerated QD and QDax (Lim et al.; Chalumeau et al.,
  JMLR 2024), and QDAC/URSA skill repertoires for few-shot adaptation (Grillotti
  et al., ICML 2024; arXiv 2508.19172).
- A public tutorial† in the fcmaes-rust repository runs MAP-Elites over a
  25-parameter CPG quadruped on **deterministic double-precision Rapier**. Its
  descriptors are duty factor and torso-height variability. It reports 50,048
  evaluations in about 98 s and 240/400 niches filled. Its most useful number is
  a caution: when the elites were replayed on five held-out terrains, only 27/240
  stayed feasible on all of them. Archive coverage is not robustness, which is
  why L1 insists on a native challenge.

Running this on MuJoCo Warp is incremental, not novel. Running it with a
three-engine challenge as the exploit filter is not something the sweep found.

**Cross-engine transfer has been measured, but not with game engines.**

- Mohammed and Valdenegro-Toro (arXiv 2010.14444) found that policies often fail
  to transfer between physics engines and that results depend strongly on seed.
- *PolySim* (arXiv 2510.01708) trains one humanoid policy across several
  simulators and reports large zero-shot gains in a held-out engine (MuJoCo)
  over single-simulator training.
- Several Isaac-to-MuJoCo sim-to-sim reports show gait-level stability but
  systematic joint and contact-force differences.

The sweep found no locomotion transfer study involving Jolt or Rapier, and no
work that treats engine identity as a hidden variable to infer at runtime (L5).
PolySim randomizes the engine away during training; it does not infer it.

**Procedural creatures in game engines.**

- Spore's runtime animation system (Hecker et al., SIGGRAPH 2008) compiled gaits
  from player-made bodies, but kinematically, not with physics.
- *Wobbledogs*† simulates mutating quadrupeds physically in a single engine,
  with hand-coded stabilization.
- *Creature Lab*† evolves or trains brains for user-drawn 2D creatures on Rapier
  2D, with exact replays.
- Unity ML-Agents, Unreal Learning Agents and Godot RL Agents provide
  end-to-end RL tooling for fixed bodies.

No public SDK was found that sells learned or adaptive physical locomotion for
arbitrary procedural creatures.

**Morphology-conditioned learning has moved fast**, but every example stays
inside one engine:

- URMA, and URMAv2 on MJX with very large randomized embodiment sets
  (arXiv 2509.02815);
- *Towards Embodiment Scaling Laws* (GenBot-1K, arXiv 2505.05753);
- LocoFormer and PAL (arXiv 2505.16042);
- QWM (already in the ledger).

None of them reports zero-shot transfer across physics engines.

**Versioned, reversible adaptation exists in pieces, with two warnings.**

- Governance and rollback for embodied agents have been described (Qin et al.,
  arXiv 2604.08059 and 2604.07799).
- *RDumb* (Press et al., NeurIPS 2023) found that periodically resetting to the
  pretrained model beat every continual test-time adaptation method it tested.
  Tier 3 must beat the memory-off reset baseline, not just show change.
- *RTPC* (Wang et al., arXiv 2610.24573) wrapped a frozen policy with auditable
  external-memory retrieval. Its primary effect **did not reproduce in an
  independent replication**, and the retrieved corrections could not be told
  apart from random corrections of the same family. Every L2 and L6 evaluation
  therefore needs a **shuffled-memory control** (same store, randomly permuted
  keys) alongside memory-off, or a "memory helped" result is unsupported.

**Evidence practice.**

- Pre-registration workshops (NeurIPS 2020/2021) and *Robot Learning as an
  Empirical Science* (Kress-Gazit et al., arXiv 2409.09491) argue for
  prospective protocols.
- STEP (Snyder et al., arXiv 2503.10966) provides sequential policy comparison
  with error control, a direct input to S3.

The sweep found no published fail-closed, machine-enforced claim-gating harness
for locomotion.

**Honest positioning.** The individual mechanisms are established. What appears
uncovered is the combination:

1. a deterministic controller compiled from a bounded descriptor for
   non-robot creatures;
2. one canonical contract across a robotics simulator and two game engines;
3. a learned layer gated on its own support with a bit-exact fallback; and
4. a fail-closed evidence lifecycle around every promotion.

Claims should say "integration" and "first in game engines" only after a
targeted search at publication time, not "first residual" or "first
adaptation".

## 18. Sources

Links point to the canonical abstract page where one exists. **Before importing
code, open the repository and confirm the license yourself**; the license column
records what was observed on 2026-10-23, and "check" means it was not
confirmed. Under the ledger rules, a source that becomes load-bearing gets its
own ledger row with the exact reviewed version.

### Residual control, gait modulation and safe switching

| Source | Link | Code / license | Use here |
| --- | --- | --- | --- |
| Silver, Allen, Tenenbaum, Kaelbling 2018, *Residual Policy Learning* | [arXiv:1812.06298](https://arxiv.org/abs/1812.06298) | check | L4 core idea |
| Johannink et al., ICRA 2019, *Residual Reinforcement Learning for Robot Control* | [arXiv:1812.03201](https://arxiv.org/abs/1812.03201) | none known | L4 |
| Iscen et al., CoRL 2018, *Policies Modulating Trajectory Generators* | [arXiv:1910.02812](https://arxiv.org/abs/1910.02812) | none known | L4 v2 parameter channel |
| Bellegarda and Ijspeert 2022, *CPG-RL* | [arXiv:2211.00458](https://arxiv.org/abs/2211.00458) | check | L4 v2 |
| Margolis and Agrawal, CoRL 2022, *Walk These Ways* | [arXiv:2212.03238](https://arxiv.org/abs/2212.03238) | check | L4 v2: gait parameters as inputs |
| Sha 2001, *Using Simplicity to Control Complexity* (Simplex) | [IEEE Software](https://doi.org/10.1109/MS.2001.936213) | n/a | L3 |
| Alshiekh et al., AAAI 2018, *Safe Reinforcement Learning via Shielding* | [arXiv:1708.08611](https://arxiv.org/abs/1708.08611) | n/a | L3 |
| Ames et al., ECC 2019, *Control Barrier Functions: Theory and Applications* | [arXiv:1903.11199](https://arxiv.org/abs/1903.11199) | n/a | L3 (why not directly) |
| Wabersich and Zeilinger, *Automatica* 2021, predictive safety filter | [arXiv:1812.05506](https://arxiv.org/abs/1812.05506) | n/a | L3 later option |
| Brunke et al. 2022, *Safe Learning in Robotics* (survey) | [arXiv:2108.06266](https://arxiv.org/abs/2108.06266) | n/a | L3 background |
| Cao, Mao, Sha, Caccamo, ICLR 2024, *Phy-DRL* | [arXiv:2305.16614](https://arxiv.org/abs/2305.16614) | check | Section 17 |
| Cao, Mao, Cai, Sha, Caccamo 2024, *Simplex-enabled Safe Continual Learning Machine* | [arXiv:2409.05898](https://arxiv.org/abs/2409.05898) | check | L3 closest prior art |
| Wu, Zhang, Wang, *PLOS ONE* 2026, CPG plus bounded multi-agent residuals | [doi:10.1371/journal.pone.0356505](https://doi.org/10.1371/journal.pone.0356505) | check | Section 17 |
| Rana et al., *Bayesian Controller Fusion* | [arXiv:2107.09822](https://arxiv.org/abs/2107.09822) | check | L2/L4 confidence-scaled blending |

### Adaptation, retrieval and memory

| Source | Link | Code / license | Use here |
| --- | --- | --- | --- |
| Kumar, Fu, Pathak, Malik, RSS 2021, *RMA* | [arXiv:2107.04034](https://arxiv.org/abs/2107.04034) | check | L5 |
| Yu, Tan, Liu, Turk, RSS 2017, *UP-OSI* | [arXiv:1702.02453](https://arxiv.org/abs/1702.02453) | check | L5 |
| Lee et al., *Science Robotics* 2020, challenging-terrain teacher-student | [arXiv:2010.11251](https://arxiv.org/abs/2010.11251) | check | L5, R09 |
| Nagabandi et al., ICLR 2019, fast adaptation via meta-learning | [arXiv:1803.11347](https://arxiv.org/abs/1803.11347) | check | L5 background |
| Blundell et al. 2016, *Model-Free Episodic Control* | [arXiv:1606.04460](https://arxiv.org/abs/1606.04460) | n/a | L2 |
| Pritzel et al., ICML 2017, *Neural Episodic Control* | [arXiv:1703.01988](https://arxiv.org/abs/1703.01988) | n/a | L2 |
| Sridhar et al., *REGENT* | [arXiv:2412.04759](https://arxiv.org/abs/2412.04759) | check | L2, L6 |
| Schmied et al. 2024, *Retrieval-Augmented Decision Transformer* | [arXiv:2410.07071](https://arxiv.org/abs/2410.07071) | check | L6 |
| Atkeson, Moore, Schaal 1997, *Locally Weighted Learning for Control* | [doi:10.1023/A:1006511328852](https://doi.org/10.1023/A:1006511328852) | n/a | L2 interpolation |
| Duan et al. 2016, *RL²* | [arXiv:1611.02779](https://arxiv.org/abs/1611.02779) | n/a | L6: deferred, with reasons |
| Laskin et al., *In-context RL with Algorithm Distillation* | [arXiv:2210.14215](https://arxiv.org/abs/2210.14215) | n/a | L6: deferred, with reasons |
| Press et al., NeurIPS 2023, *RDumb* | [arXiv:2306.05401](https://arxiv.org/abs/2306.05401) | check | L6 reset baseline |
| Wang et al. 2026, *RTPC* (failed replication) | [arXiv:2610.24573](https://arxiv.org/abs/2610.24573) | check | L2/L6 shuffled-memory control |
| Qin et al. 2026, governed capability evolution | [arXiv:2604.08059](https://arxiv.org/abs/2604.08059) | check | Section 17 |

### Quality diversity and trial-and-error adaptation

| Source | Link | Code / license | Use here |
| --- | --- | --- | --- |
| Mouret and Clune 2015, *MAP-Elites* | [arXiv:1504.04909](https://arxiv.org/abs/1504.04909) | n/a | L1 |
| Cully, Clune, Tarapore, Mouret, *Nature* 2015, *Robots that can adapt like animals* | [doi:10.1038/nature14422](https://doi.org/10.1038/nature14422) | check | L1, L6 |
| Vassiliades and Mouret, GECCO 2018, directional variation | [arXiv:1804.03906](https://arxiv.org/abs/1804.03906) | check | L1 variation operator |
| Fontaine, Togelius, Nikolaidis, Hoover, GECCO 2020, *CMA-ME* | [arXiv:1912.02400](https://arxiv.org/abs/1912.02400) | check | L1 if progress stalls |
| Chalumeau et al., JMLR 2024, *QDax* | [JMLR v25](https://www.jmlr.org/papers/v25/23-1027.html) | check | L1 reference implementation |
| Lim, Allard, Grillotti, Cully 2022, *Accelerated QD through Massive Parallelism* | [arXiv:2202.01258](https://arxiv.org/abs/2202.01258) | check | L1 GPU recipe |
| Chatzilygeroudis et al. 2018, reset-free trial and error | [arXiv:1610.04213](https://arxiv.org/abs/1610.04213) | check | L6 |
| Allard et al., ACM TELO 2023, hierarchical QD damage recovery | [doi:10.1145/3596912](https://doi.org/10.1145/3596912) | check | L6 |
| Grillotti et al., ICML 2024, *QDAC*; URSA 2025 | [PMLR v235](https://proceedings.mlr.press/v235/grillotti24a.html), [arXiv:2508.19172](https://arxiv.org/abs/2508.19172) | check | L6 |
| fcmaes-rust Rapier quadruped gait tutorial† | [GitHub](https://github.com/dietmarwo/fcmaes-rust/blob/main/tutorials/rapier-quadruped-gait/README.md) | check | L1 Rapier lane, held-out caution |

### Training stacks, randomization and MPC teachers

| Source | Link | Code / license | Use here |
| --- | --- | --- | --- |
| MuJoCo Warp | [GitHub](https://github.com/google-deepmind/mujoco_warp) | check | L0 |
| Zakka et al. 2025, *MuJoCo Playground* | [arXiv:2502.08844](https://arxiv.org/abs/2502.08844) | check | L0, L4 recipe |
| Rudin, Hoeller, Reist, Hutter, CoRL 2021, *Learning to Walk in Minutes* | [arXiv:2109.11978](https://arxiv.org/abs/2109.11978) | check | L0, L4, R09 curriculum |
| Tan et al., RSS 2018, *Sim-to-Real: Learning Agile Locomotion for Quadruped Robots* | [arXiv:1804.10332](https://arxiv.org/abs/1804.10332) | n/a | L4 latency and actuator modeling, R12 |
| Peng, Andrychowicz, Zaremba, Abbeel, ICRA 2018, dynamics randomization | [arXiv:1710.06537](https://arxiv.org/abs/1710.06537) | n/a | L4, L5 |
| Tobin et al., IROS 2017, domain randomization | [arXiv:1703.06907](https://arxiv.org/abs/1703.06907) | n/a | L4 background |
| Howell et al. 2022, *Predictive Sampling* (MuJoCo MPC) | [arXiv:2212.00541](https://arxiv.org/abs/2212.00541) | check | L7 teacher |
| Williams et al., ICRA 2017, MPPI | [doi:10.1109/ICRA.2017.7989202](https://doi.org/10.1109/ICRA.2017.7989202) | n/a | L7 |
| Ross, Gordon, Bagnell, AISTATS 2011, DAgger | [arXiv:1011.0686](https://arxiv.org/abs/1011.0686) | n/a | L7 distillation |
| PolySim 2025, multi-simulator training | [arXiv:2510.01708](https://arxiv.org/abs/2510.01708) | check | L5 |
| Mohammed and Valdenegro-Toro 2020, RL across physics engines | [arXiv:2010.14444](https://arxiv.org/abs/2010.14444) | n/a | L5 caution |

### Morphology-conditioned policies

| Source | Link | Code / license | Use here |
| --- | --- | --- | --- |
| Feng et al., CoRL 2022, *GenLoco* | [arXiv:2209.05309](https://arxiv.org/abs/2209.05309) | check | L8 training distribution |
| Gupta et al., ICLR 2022, *MetaMorph* | [arXiv:2203.11931](https://arxiv.org/abs/2203.11931) | check | L8 (also in ledger) |
| Bohlinger et al., CoRL 2024, *URMA*; URMAv2 2025 | [PMLR v270](https://proceedings.mlr.press/v270/bohlinger25a.html), [arXiv:2509.02815](https://arxiv.org/abs/2509.02815) | check | L8 comparison |
| Sferrazza et al. 2024, *Body Transformer* | [arXiv:2408.06316](https://arxiv.org/abs/2408.06316) | check | L8 |
| Huang, Mordatch, Pathak, ICML 2020, *Shared Modular Policies* | [PMLR v119](https://proceedings.mlr.press/v119/huang20d.html) | check | L8 (also in ledger) |
| *Towards Embodiment Scaling Laws* 2025 | [arXiv:2505.05753](https://arxiv.org/abs/2505.05753) | check | Section 17 |
| PAL 2025, procedural quadrupeds | [arXiv:2505.16042](https://arxiv.org/abs/2505.16042) | check | Section 17 |
| LocoFormer 2025 | [arXiv:2509.23745](https://arxiv.org/abs/2509.23745) | check | L6 (also in ledger) |

### Evidence and statistics

| Source | Link | Code / license | Use here |
| --- | --- | --- | --- |
| Agarwal et al., NeurIPS 2021, *Statistical Precipice* (rliable) | [arXiv:2108.13264](https://arxiv.org/abs/2108.13264) | check | S1 |
| Henderson et al., AAAI 2018, *Deep RL that Matters* | [arXiv:1709.06560](https://arxiv.org/abs/1709.06560) | n/a | S1 |
| Schuirmann 1987, two one-sided tests | [doi:10.1007/BF01068419](https://doi.org/10.1007/BF01068419) | n/a | S2 |
| Lakens 2017, *Equivalence Tests: A Practical Primer* | [doi:10.1177/1948550617697177](https://doi.org/10.1177/1948550617697177) | n/a | S2 |
| O'Brien and Fleming 1979, group-sequential boundaries | [doi:10.2307/2530245](https://doi.org/10.2307/2530245) | n/a | S3 |
| Ramdas, Grünwald, Vovk, Shafer, *Statistical Science* 2023, anytime-valid inference | [arXiv:2210.01948](https://arxiv.org/abs/2210.01948) | n/a | S3 |
| Snyder et al. 2025, *STEP* sequential policy comparison | [arXiv:2503.10966](https://arxiv.org/abs/2503.10966) | check | S3 |
| Kress-Gazit et al. 2024, *Robot Learning as an Empirical Science* | [arXiv:2409.09491](https://arxiv.org/abs/2409.09491) | n/a | Harness positioning |
| Gotovos, Casati, Hitz, Krause, IJCAI 2013, active level-set estimation | [IJCAI 2013](https://www.ijcai.org/Abstract/13/202) | n/a | S4 |
| Wilks 1941, tolerance limits | [doi:10.1214/aoms/1177731788](https://doi.org/10.1214/aoms/1177731788) | n/a | S4, the 59-sample rule |
| Angelopoulos and Bates, *A Gentle Introduction to Conformal Prediction* | [arXiv:2107.07511](https://arxiv.org/abs/2107.07511) | n/a | S5 |
| Lakshminarayanan, Pritzel, Blundell, NeurIPS 2017, *Deep Ensembles* | [arXiv:1612.01474](https://arxiv.org/abs/1612.01474) | n/a | S6 |
| Lehman et al., *Artificial Life* 2020, *Surprising Creativity of Digital Evolution* | [arXiv:1803.03453](https://arxiv.org/abs/1803.03453) | n/a | S7 |

### Game-engine and creature context

| Source | Link | Use here |
| --- | --- | --- |
| Hecker et al., SIGGRAPH 2008, real-time motion retargeting to highly varied user-created morphologies | [PDF](https://www.chrishecker.com/images/c/cb/Sporeanim-siggraph08.pdf) | Section 17 |
| Coros et al., SIGGRAPH 2011, *Locomotion Skills for Simulated Quadrupeds* | Already in the ledger | Tier 1 lineage |
| Godot RL Agents (Beeching et al.) | [arXiv:2112.03636](https://arxiv.org/abs/2112.03636) | Section 17 |
| *Wobbledogs*† developer interview | [Game Developer](https://www.gamedeveloper.com/design/behind-the-ai-and-physics-of-i-wobbledogs-i-procedurally-goofy-wobbledogs) | Section 17 |

## 19. Open questions for the owner

1. Is a v2 parameter-modulation correction kind acceptable as a planned
   successor contract, or should all Tier 2 work stay inside v1 for now?
2. Which two or three behavior descriptors define the first archive?
3. What practical margin defines "not worse than baseline" (for example, an
   absolute increase in fall rate)? It must be frozen before any comparison.
4. Should the exploration evidence weight be formalized in the harness, or
   handled as a development-lane convention first?
5. Is device-side reimplementation of the controller (L0 option B) acceptable
   for discovery if every shortlisted candidate is re-run through the Rust core?
