# Locomotion Research Sources and Adoption Ledger

- **Status:** active source ledger; architecture input, not accepted LoColemotion
  evidence
- **Recorded:** 2026-07-27
- **Scope:** the original three-paper BR14A source set plus Cole's later
  controller, gait, recovery, and morphology research inputs
- **SDK destination:** [Engine-Neutral Locomotion SDK Bootstrap](../ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md)
- **Active experiment:** [BR14A Quadruped Generalization Bootstrap](../BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md)

## Why this ledger exists

The paper files remain local, untracked research inputs. A paper path mentioned
only in chat would be easy to lose during cleanup. This file records each exact
local source, its SHA-256 identity, a portable publication URL, the ideas we
are using, and the evidence boundaries we must not silently erase.

The PDFs are not copied into Git by this change. DReCon is an ACM publication
and the morphology papers are large versioned preprints; source control policy,
redistribution rights, and repository-size cost should be decided before paper
binaries become tracked assets. A byte-identical recovery copy of each of the
three original papers is retained outside the repository under
`<evidence-root>\base-dirty-recovery-2026-07-28`.
If both local copies move, reacquire the declared version from the canonical
URL and verify the recorded SHA-256.

## Exact source inventory

| Short name | Exact local PDF | SHA-256 | Portable source |
| --- | --- | --- | --- |
| DReCon | `<repo>\DReCon.pdf` | `aee8a67b3532ca3cd3cc80b51248b2db94dfb175fcae0d653f90c9b3c70c2a54` | [ACM DOI 10.1145/3355089.3356536](https://doi.org/10.1145/3355089.3356536) |
| QWM | `<repo>\2604.08780v1.pdf` | `ae0ecb7fa7b16659b6a9ae5561176fa5c4d76788528b2ba8fc4bc533792824ae` | [arXiv:2604.08780v1](https://arxiv.org/abs/2604.08780v1) |
| UniLegs | `<repo>\2507.22653v2.pdf` | `6734394082dac95355277f477f01ea9e0ee90cb03e28cc20508632f7d11ddb31` | [arXiv:2507.22653v2](https://arxiv.org/abs/2507.22653v2) |
| Coros quadruped skills | `<repo>\paper.pdf` | `981d0e755a6eacfac68c327a8b8585afd375b38d96dbc93fb9a9c4a0b4cc8b36` | [UBC paper PDF](https://www.cs.ubc.ca/~van/papers/2011-TOG-quadruped/paper.pdf) |
| Coros supplementary material | `<repo>\supp.pdf` | `b3dc5432f7a37083860f7fab7a9254a2297f846ca0f04523f3857fc457cd6a87` | [UBC supplement PDF](https://www.cs.ubc.ca/~van/papers/2011-TOG-quadruped/supp.pdf) |

The three original local files inspected on 2026-07-27 were respectively
`3,687,182`, `50,493,393`, and `1,029,038` bytes. Hash identity, rather than
filename or size alone, decides whether a later file is the same source.

The durable recovery paths use the same filenames beneath
`<evidence-root>\base-dirty-recovery-2026-07-28`.
Their SHA-256 values were rechecked on 2026-07-28 and match the table exactly.

The later Coros paper and supplement were inspected on 2026-08-05 at
`2,197,519` and `384,761` bytes respectively. They remain untracked and are not
claimed to exist in the older recovery bundle.

## Source 1: DReCon

**Citation:** Kevin Bergamin, Simon Clavet, Daniel Holden, and James Richard
Forbes. 2019. "DReCon: Data-Driven Responsive Control of Physics-Based
Characters." *ACM Transactions on Graphics* 38(6), Article 206, 11 pages.

### What the paper actually demonstrates

- The controller composes a kinematic motion-matching reference, open-loop
  joint-level PD targets, and learned corrective offsets before sending the
  filtered targets to a physics engine. See PDF pages 2-3 and Figure 3.
- The feedback policy changes only a declared subset of joints rather than
  replacing every open-loop target. See PDF pages 2 and 4-6.
- The policy state includes target and simulated motion, direct tracking
  errors, desired velocity, velocity error, and the previous filtered action.
  See PDF page 5, Section 6.3.
- The corrective action is held across multiple simulation steps and passed
  through a recursive exponentially weighted moving average. Their experiment
  uses a 60 Hz simulation, a 30 Hz policy query rate, `k = 2`, and
  `beta = 0.2`. See PDF pages 6-7, Section 6.4 and Table 2.
- The state is resolved in heading-and-gravity-aligned frames anchored at the
  kinematic and simulated centers of mass. See PDF page 5, Section 6.3.

### What LoColemotion adopts now

1. Keep a deterministic reference controller as the authority-bearing base.
2. Define any future learned component as a bounded residual, not a hidden
   replacement controller.
3. Make raw residual, filtered residual, previous filtered residual, saturation,
   slew, update cadence, and affected actuator IDs observable receipts.
4. Keep a filter state in the canonical controller state if filtered residuals
   are enabled.
5. Express motion-state errors in an explicitly declared travel, gravity, and
   body frame instead of leaking a host engine's coordinate convention.

### What LoColemotion does not copy

- `beta = 0.2`, `k = 2`, 30 Hz, the network dimensions, and the controlled
  joint subset are results for DReCon's humanoid, simulator, and motion data.
  They are not portable quadruped constants.
- DReCon's reward is not a substitute for BR14A's strict structural, contact,
  motion, and no-cheat gates.
- Motion matching is a possible future reference generator. It is not required
  for extracting the current deterministic quadruped controller.

### Preregistered future experiment shape

If a new fresh population again exposes a lateral-correction versus
contact-progression tradeoff, development may compare:

1. the current 90-tick held correction;
2. a higher-rate unfiltered bounded correction; and
3. the same higher-rate correction with a cycle-normalized low-pass filter.

The filter must be parameterized by a time constant or a declared fraction of
the gait cycle, then compiled to the engine step rate. It must not inherit
DReCon's numeric `beta`. Each arm must record raw and filtered correction,
per-step slew, peak correction, lateral-error integral and overshoot, contact
timeouts, limb relocation, phase, and terminal support.

This prospective shape is now instantiated by the frozen BW5R-A/B/C
development family in
[`../../sdk/balanced_wave_bw5r_preregistration.json`](../../sdk/balanced_wave_bw5r_preregistration.json).
The three arms use time constants of `1/32`, `1/16`, and `1/8` of the fixed
gait cycle. Those constants, the complete `174`-world comparison, filter
diagnostics, selection rule, and disjoint future reservations were frozen
before the first BW5R physics world. This is use of DReCon's experiment and
composition pattern, not a transfer of its learned policy, query rate, numeric
filter coefficient, humanoid constants, or empirical claims.

## Source 2: QWM morphology conditioning

**Citation:** Mohamad H. Danesh, Chenhao Li, Amin Abyaneh, Anas Houssaini,
Kirsty Ellis, Glen Berseth, Marco Hutter, and Hsiu-Chin Lin. 2026. "Toward
Hardware-Agnostic Quadrupedal World Models via Morphology Conditioning."
arXiv:2604.08780v1.

### What the paper actually demonstrates

- Static physical structure is supplied explicitly rather than inferred only
  from motion history. The morphology vector contains hip offset, thigh and
  shank length, knee-configuration style, stance length and width, stance
  aspect ratio, logarithmic total mass, trunk-mass ratio, and actuator torque
  density. See PDF pages 4-5, Section IV-A, and page 22, Table III.
- Static morphology and dynamic proprioception use separate encoder towers
  before fusion, and morphology is injected into the recurrent transition at
  every time step. See PDF page 5, Section IV-B.
- Per-robot adaptive reward normalization prevents one hardware family's
  reward scale from dominating pooled model training. The authors explicitly
  call it a practical stabilizer, not a guarantee of equivalent reward meaning.
  See PDF page 5, Section IV-C.
- Held-out morphologies near the training cohort transfer substantially better
  than the Unitree B2 extrapolation outlier. The authors describe the result as
  distribution-bounded interpolation, not a universal physics engine. See PDF
  pages 1 and 8-9, Section V-D and the conclusion.
- Their coverage analysis uses standardized morphology features and Euclidean
  distance. Interpolation examples are within `d < 1.15`; B2 is approximately
  `d = 5.3` from its nearest training exemplar and performs poorly. See PDF
  page 8.

### What LoColemotion adopts now

The next newly preregistered generated-family campaign should add two
output-only, no-world-reconstructable receipts:

```text
sporespore_morphology_feature_receipt_v1
sporespore_morphology_coverage_receipt_v1
```

The feature receipt should preserve both generator intent and compiled physical
reality:

- signed generator coordinates and normalized scale values;
- topology family and ordered limb count;
- hip/support longitudinal and lateral extents;
- support aspect ratio;
- upper, lower, and total leg reach;
- foot radius relative to leg reach;
- total mass, trunk-mass ratio, and front/rear mass imbalance;
- projected center of mass and nominal support margin;
- normalized yaw inertia;
- motor impulse or torque authority relative to body weight and lever arm; and
- the fixture, controller, clock, solver, and feature-schema digests.

The coverage receipt should include:

- reference cohort ID and digest;
- feature ordering, units, and normalization constants;
- raw and standardized feature vectors;
- nearest validated morphology ID and distance;
- maximum single-axis excursion;
- declared coverage shell;
- `SUPPORTED`, `EDGE`, or `OUT_OF_DISTRIBUTION` status; and
- the policy governing that status.

Initially those statuses are diagnostic. A distance threshold becomes an
acceptance or controller-selection input only in a later preregistration that
freezes its reference cohort, normalization, metric, threshold, and response
before new bodies are generated or observed.

### Read-only GQ diagnostic already learned

After GQ12 was rejected, the 20 already-opened GQ11 bodies were used as a
development reference cohort. The six signed generator axes were standardized
on that cohort and ordinary Euclidean nearest-neighbor distance was calculated
for the 12 opened GQ12 selection bodies.

- `gq12_generated_s126`, the sole GQ12 lateral failure, was nearest to
  `gq11_generated_s1005` at distance `1.546`.
- `s1005` was itself GQ11's R2 lateral-drift failure.
- `s126` ranked only seventh-farthest among the 12 GQ12 bodies.
- `s132` was farthest at distance `3.122` and passed.

This indicates a recurring lateral-control neighborhood, but it also shows
that simple unsigned distance does not predict failure. The current scalar
morphology-interaction score sums products of absolute normalized deviations
and therefore discards the signs and semantic combinations that the later
piecewise controller branches recover manually.

This calculation is a post-result development diagnostic, not GQ12 evidence,
not an accepted coverage model, and not permission to classify future bodies
after observing their outcomes. The future no-world receipt must reconstruct
the calculation before it can become durable machine-verifiable data.

### GQ13 receipt result and ordering lesson

GQ13 implemented the signed feature receipt and cohort-distance coverage
receipt described above. In the exact one-shot selection, eleven queries were
`SUPPORTED` and one was `EDGE`; physical outcomes nevertheless included four
failures spanning lateral drift, anchor error, and foot relocation. This
confirms the earlier warning: coverage status describes proximity to a frozen
cohort, not guaranteed controller success.

The new dynamic-support trace produced zero samples because four active contact
points were passed in semantic receipt order rather than support-polygon
perimeter order. A no-world rectangle reproduced the exact failure as
`SPATIAL_DYNAMIC_SUPPORT_POLYGON_DEGENERATE`. Future topology schemas must
therefore keep at least two explicit order contracts:

1. canonical semantic token order for identity, masks, receipts, and JSON; and
2. geometric perimeter or hull order for polygon algorithms.

Conflating these is not merely a quadruped bug: any variable-topology SDK that
lets token enumeration imply geometry can produce self-intersections,
solver-dependent results, or silent cross-engine disagreement. The GQ13
negative report and exact evidence path are retained in
[`BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md`](../BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md).

### What LoColemotion defers

- A learned world model is optional and comes after deterministic semantics,
  cross-engine conformance, and a sufficiently broad morphology corpus.
- Adaptive reward normalization is relevant only when learning from pooled
  heterogeneous reward streams. It must never normalize away strict safety,
  contact, or structural failures.
- A fixed quadruped feature vector is an interim representation. Variable
  kinematic trees require ordered body/limb tokens or a graph representation.

## Source 3: UniLegs

**Citation:** Weijie Xi, Zhanxiang Cao, Chenlin Ming, Jianying Zheng, and Guyue
Zhou. 2025. "UniLegs: Universal Multi-Legged Robot Control through
Morphology-Agnostic Policy Distillation." arXiv:2507.22653v2, IROS 2025.

### What the paper actually demonstrates

- The method first trains a specialist PPO teacher for each morphology, then
  distills those teachers into one Transformer student. See PDF pages 1 and
  3-4.
- Training covers three quadrupeds plus six-legged and eight-legged variants.
  The held-out zero-shot evaluation uses one similar quadruped, Unitree Go2.
  See PDF page 4, Section IV-A.
- The Transformer student reaches `94.47%` of normalized teacher reward over
  training morphologies and `72.64%` on the unseen Go2. The comparable MLP
  reaches `90.45%` and `69.29%`. See PDF page 5, Table III.
- The deployed student uses normalized joint-position targets tracked by a PD
  controller. See PDF page 3, Section III-B.

### What LoColemotion adopts now

1. Replace quadruped-only runtime dictionaries with an ordered topology schema:
   body tokens, joint tokens, limb tokens, contact tokens, and actuator tokens.
2. Give every token a stable semantic ID and declared parent/child or attachment
   relationship; array position alone must not define anatomy.
3. Define masks and deterministic ordering for absent, passive, or
   non-contacting limbs before introducing a variable-topology policy.
4. Preserve specialist deterministic controllers and their evidence as
   teachers or reference oracles if later policy distillation is attempted.
5. Score any distilled policy against the exact specialist gates per
   morphology, not only aggregate normalized reward.

### What LoColemotion does not claim

- One held-out quadruped does not establish arbitrary unseen topology.
- Normalized reward is not equivalent to passing every LoColemotion locomotion,
  contact, structure, safety, and evidence gate.
- Attention is a promising variable-relationship mechanism, not a reason to
  choose a Transformer before the engine-neutral token contract and baseline
  corpus exist.

## Source 4: Coros quadruped skill controllers

**Citation:** Stelian Coros, Andrej Karpathy, Ben Jones, Lionel Reveret, and
Michiel van de Panne. 2011. "Locomotion Skills for Simulated Quadrupeds."
*ACM Transactions on Graphics* / SIGGRAPH 2011.

### What the paper actually demonstrates

- One dynamically simulated dog performs six named gaits—walk, trot, pace,
  canter, transverse gallop, and rotary gallop—plus declared transitions,
  turning, sitting, lying down, standing up, manually designed get-up from a
  fall, and parameterized leaps over gaps and obstacles and onto or off low
  platforms.
- The controller is genuine forward-dynamics control, not rendered
  visualization. It combines gait graphs, per-leg stance/swing trajectories,
  front and rear leg frames connected by a flexible spine, joint PD torque,
  and leg- and phase-specific internal virtual forces mapped through a
  Jacobian transpose. Offline optimization tunes many gait and leap
  parameters.
- Robustness is tested against fixed-time pushes in eight front/rear and
  cardinal-direction combinations and against a series of low terrain steps.
  The terrain height is queried at the beginning of swing; this is useful
  reactive traversal evidence, not arbitrary rough-terrain coverage.
- The supplement retains experimental gait graphs, parameterized leap
  capability plots, and representative leg-torque traces.

### The exact generalization boundary

This is a broad **skill-repertoire result** and a strong controller-design
reference. It is not an arbitrary-morphology or cross-engine result:

- the only physical model is an approximately `34 kg` female German shepherd
  with `30` links and `67` internal degrees of freedom;
- the only reported engine is ODE with its iterative solver at `1000 Hz`;
- the ground coefficient is fixed at `1.0`, self-collision is disabled, and
  hip and shoulder joint limits are omitted because they destabilized that ODE
  setup;
- pushes use a finite fixed schedule, the terrain consists of low steps, and
  the authors explicitly present broader animal transfer as future work; and
- the get-up controller is manually authored, acknowledged as difficult, and
  shown for that dog. It does not prove recovery from arbitrary orientations,
  impulses, morphologies, contacts, or engines.

Accordingly, LoColemotion may say that the paper establishes these capabilities
for its declared single-dog ODE system. It may not import them as evidence that
our SDK already turns, self-rights, runs, traverses arbitrary terrain, or
generalizes across morphology or engines.

### What LoColemotion adopts

1. Treat gait families and transitions as explicit versioned controller-graph
   records, not hidden conditionals inside one walking controller.
2. Keep stance and swing phase schedules explicit and receipt-bearing. Our
   scheduler already supplies the right semantic home for this idea.
3. Retain leg- and phase-specific virtual-force control as a serious successor
   branch. The portable core already has centroidal support commands and
   endpoint-force-to-joint `J^T` mapping, so the paper validates the direction
   of that architecture without supplying LoColemotion's gains or acceptance.
4. Separate front and rear support-frame intent where fast-gait or flexible-
   spine work eventually requires it, while keeping the public topology
   contract body-plan-neutral.
5. Model get-up, stand, sit, lie, jump, and gait transition as separately
   versioned skills with explicit entry conditions, exit conditions, failure
   states, and prospective physical campaigns. A successful walking policy is
   not presumed to possess any of them.

### What LoColemotion does not copy

- No ODE timestep, friction coefficient, torque limit, push magnitude, gait
  period, virtual-force curve, PD gain, foot trajectory, or optimized parameter
  transfers without a new dimensional derivation and prospective campaign.
- Disabling self-collision or joint limits is not an acceptable hidden route to
  passing LoColemotion morphology, recovery, or release gates.
- The current Explorer kick is a real-physics development interaction, but the
  paper cannot turn that button into recovery evidence. Get-up and kick
  recovery remain distinct prospective skill campaigns.

## Adoption map

| Paper-derived idea | Immediate bootstrap effect | First allowed implementation stage |
| --- | --- | --- |
| Explicit signed morphology features | Add output-only feature and coverage receipts to the next fresh generated-family preregistration | GQ follow-on |
| Distribution support boundary | Report diagnostic coverage state; fail closed for unsupported production use | GQ follow-on and SDK core |
| Reference plus bounded correction | Preserve deterministic controller and define a residual interface | SDK semantics v1 |
| Filtered residual action | Preregister only after a new opened-body failure motivates it | GQ development or later learned residual |
| Static/dynamic separation | Separate morphology spec from runtime state in the SDK ABI | SDK semantics v1 |
| Variable limb relationships | Use ordered semantic topology tokens, not four hardcoded limbs | Multi-leg SDK phase |
| Specialist-to-student distillation | Retain deterministic specialists as teachers and conformance oracles | Learned policy phase |
| Morphology-conditioned world model | Optional predictive layer after coverage and adapter conformance | World-model phase |
| Heterogeneous reward normalization | Training-only equalizer; never a safety-gate normalizer | Pooled ML training phase |
| Explicit gait and skill graphs | Version controller families, transitions, entry/exit states, and receipts | Turning/running/recovery successors |
| Phase-specific internal virtual forces through `J^T` | Build on portable centroidal and endpoint-force mapping without importing paper gains | Balance and fast-gait successors |
| Dual front/rear support frames and flexible spine | Preserve as an optional topology-aware abstraction | Flexible-spine quadruped phase |

### Post-C6 incorporation

The retained C6/C6R negative results and
[post-C6 live-code audit](../SDK_POST_C6_AUDIT_2026-07-28.md) now make three
paper-derived boundaries concrete in
[ADR-016](../adr/ADR-016_PORTABLE_STABILITY_AND_MULTI_ENGINE_ORDER.md):

1. DReCon's composition pattern supports retaining Candidate 35 as a
   deterministic oracle while a new, separately identified, bounded and
   receipted stability contribution is commissioned in shadow before
   authority. DReCon does not supply the stability gains.
2. QWM's static/dynamic separation supports keeping immutable morphology in
   `MorphologySpec` while Locomotion Semantics v2 adds ordered runtime body and
   support-contact state. QWM's learned embedding and distance results do not
   certify the six-axis physical domain.
3. UniLegs' variable-relationship lesson supports keeping semantic token order
   separate from geometric support-hull order and retaining deterministic
   specialists before any cross-topology distillation.

None of the three sources validates LoColemotion's `1.8` material, supplies a
portable friction interval, proves rough-terrain/push/latency robustness, or
establishes cross-engine trajectory tolerances. Those values and claims remain
prospective LoColemotion experiments.

## Primary MuJoCo semantics used by the VH2/VH3 host experiments

The prospective `C6-MJC-HC-VH2` design also relies on narrower engine semantics
from MuJoCo's primary documentation and source. These references explain the
design; the experiment separately pins and hashes the exact installed `3.11.0`
wheel files that can affect its result.

- [MuJoCo XML actuator reference](https://github.com/google-deepmind/mujoco/blob/main/doc/XMLreference.rst)
  defines the native `velocity` shortcut as a stateless SISO velocity servo:
  fixed gain `kv` plus an affine velocity bias of `-kv`. It explicitly says a
  position actuator must be combined with it to form a PD controller and
  recommends the `implicit` or `implicitfast` integrators for velocity
  actuators. VH2 therefore declares no native position target or independent
  position feedback and uses `implicitfast`.
- [MuJoCo simulation pipeline](https://github.com/google-deepmind/mujoco/blob/main/doc/programming/simulation.rst)
  documents that `mj_step` advances one model timestep and that actuation,
  acceleration, constraints, and integration are distinct pipeline stages. In
  the documented split, `mj_step2` computes actuation and acceleration before
  invoking the implicit integrator. Five `1/600 s` calls per unchanged
  `1/120 s` portable-controller command are consequently a declared host
  integration schedule, not five controller decisions. It also means that a
  later `mj_forward` on a copied post-integration state computes a new force for
  that resulting state; it does not recover the actuation used during the
  already completed step.
- [MuJoCo API function reference](https://github.com/google-deepmind/mujoco/blob/main/doc/APIreference/functions.rst)
  documents `mj_fwdActuation` as the stage that computes generalized actuator
  force `qfrc_actuator`, and `mj_fullM` as the sparse-to-dense conversion for
  the joint-space inertia matrix. The exact pinned MuJoCo `3.11.0` Python
  binding exposes sparse inertia as `MjData.M` and wraps the dense conversion
  as `mj_fullM(model, data, writable_dense_destination)`; it does not expose
  `MjData.qM`. VH2 incorrectly used the older/internal `qM` name and closed
  implementation-invalid before its first `mj_step`. The distinct VH3
  successor uses dense `mj_fullM` readback and freezes three zero-world
  binding-surface canaries—`M` presence, `qM` absence, and the exact wrapper
  signature—before model construction.
- The same primary XML/API references distinguish scalar actuator-space force
  (`actuator_force`, also exposed by an `actuatorfrc` sensor) from generalized
  joint-space force (`qfrc_actuator`). VH2 retains both on every internal trace
  row and requires their unit-gear mapping to agree; it does not silently use
  one as a substitute for the other.

These sources make the intended actuator interpretation and measurement
boundary auditable. VH2 produced no interpretable physical grid: one model was
constructed, zero steps and zero cells completed, and no report was serialized.
VH3 corrected the binding and completed all 24 worlds, but then exposed a
second implementation defect. Its trace called `mj_step`, copied the resulting
state to another `MjData`, called `mj_forward`, and recorded the recomputed
post-state `actuator_force` and `qfrc_actuator`; it multiplied that value by
`dt` as though it were completed-step impulse. The frozen `22/24` output is
therefore neither a scientific positive nor negative. A zero-world momentum
diagnostic reconstructs capped steps in all 24 cells and guides a new temporal-
instrumentation successor, but cannot retroactively promote VH3. These sources
do not prove that the successor will pass, that MuJoCo can carry BW19V, or that
MuJoCo walks. Those questions remain behind a corrected host gate and later
selected-policy evidence gates.

VH4 implements the allowed distinct correction using the same primary source
semantics. The split `mj_step1`/`mj_step2` pipeline exposes the force retained
by the completed integration before a separate copied-state `mj_forward`
recomputes actuator force for the post-state. Under the exact scalar
`implicitfast` fixture, this yields two deliberately different checks:
saturated pre-step force times `dt` equals momentum-inferred motor impulse;
unsaturated pre-step force times `dt` is only a conservative budget, while
post-state force times `dt` equals the momentum-inferred impulse. The
prospective gate pins both relations and a temporal-distinction witness. This
source grounding justifies the experiment design; it does not supply a VH4
physical result or prove MuJoCo locomotion.

The subsequently executed VH4 grid passed `24/24` with all 43,200 temporal
trace rows and both source-grounded momentum relations intact. This makes the
exact pinned five-substep host profile a positive LoColemotion finite
characterization; it does not turn the MuJoCo documentation into locomotion
evidence, nor does it establish BW19V walking, cross-engine trajectory
equivalence, or any continuous actuator domain. Those remain separate physical
questions.

## 2026-08-05 MuJoCo, MJWarp, and Coros local source inventory

Cole supplied the following local research inputs at the repository root. They
remain intentionally ignored source material rather than committed project
authority. The hashes make the reviewed versions identifiable without treating
the files as LoColemotion evidence:

| Local file | Bytes | SHA-256 |
| --- | ---: | --- |
| `mujoco_mjx.pdf` | 65,674 | `88c619021588fc64591f3dffd15f04381cbfa478482b857ecce364c3b3e10eb4` |
| `mujoco.readthedocs.io_en_stable__sources_computation_index.rst.txt.pdf` | 102,375 | `1b7e6798557ea853dcdf57910a6a41ec21475b25ba0f0bb5235961a8a7e021ac` |
| `mujoco.readthedocs.io_en_stable__sources_mjwarp_index.rst.txt.pdf` | 50,868 | `4629646b721ee078c80b69262569c4feef3672b8cc3e128266c45077f9126a05` |
| `mujoco.readthedocs.io_en_stable__sources_modeling.rst.txt.pdf` | 90,778 | `f8279e8a0f9afb863519e437ca94618db90c3f8115becb80542e9045532d722e` |
| `mujoco.readthedocs.io_en_stable__sources_programming_index.rst.txt.pdf` | 29,570 | `0b7e9d94788f1ce3eb5e9aef21d217cdb63fd9dfc91d10bb6bec4d49b0f05b9e` |
| `mujoco.readthedocs.io_en_stable__sources_python.rst.txt.pdf` | 53,858 | `13676b3d6d7c4210ef993ded1aa3b3ab8432b196d5b290ba6bb2a0f3b1cfac2b` |
| `paper.pdf` — *Locomotion Skills for Simulated Quadrupeds* | 2,197,519 | `981d0e755a6eacfac68c327a8b8585afd375b38d96dbc93fb9a9c4a0b4cc8b36` |
| `supp.pdf` — Coros supplemental material | 384,761 | `b3dc5432f7a37083860f7fab7a9254a2297f846ca0f04523f3857fc457cd6a87` |
| `binary.zip` — corresponding Coros demonstration binary/assets | 3,244,640 | `9f4dbe52731559b6583dc617d4bc86f8ce3350d6f6e8ead4b47c1f94fdbe36b3` |

Current primary online authorities are the
[MuJoCo repository](https://github.com/google-deepmind/mujoco),
[MuJoCo documentation](https://mujoco.readthedocs.io/en/stable/overview.html),
[MuJoCo Warp repository](https://github.com/google-deepmind/mujoco_warp), and
[MuJoCo Menagerie](https://github.com/google-deepmind/mujoco_menagerie).
The reviewed MJWarp documentation exposes batched `nworld` models/data, CUDA
graph capture, supported per-world model fields for domain randomization, and
examples at thousands of worlds. It is designed for NVIDIA GPU throughput,
not guaranteed low latency, and does not implement every MuJoCo feature or
automatic differentiation.

Engineering consequence: MJWarp is the preferred Tier 2 discovery/training
plane, not a qualification authority. Start with topology-compatible buckets,
retain every descriptor/seed/model/outcome, train one canonical provider, and
then validate it independently in ordinary CPU MuJoCo, Rapier/Parry, and
Godot/Jolt. A 5,000-world target remains a benchmark-dependent campaign design,
not an assumed local capacity.

## Source 5: generalist and multi-morphology locomotion programs

The following work prevents an incorrect novelty claim that generalized robot
control has never been attempted:

- [Shared Modular Policies](https://proceedings.mlr.press/v119/huang20d.html)
  learns structure-aware modular policies and evaluates transfer across robot
  designs;
- [MetaMorph](https://arxiv.org/abs/2203.11931) conditions a Transformer policy
  on robot morphology across a procedurally generated design distribution;
- [Universal Morphology Control](https://proceedings.mlr.press/v202/xiong23a.html)
  is explicitly aimed at one controller across morphology;
- [URMA](https://proceedings.mlr.press/v270/bohlinger25a.html) studies one policy
  across distinct quadruped robots and tasks; and
- [LocoFormer](https://proceedings.mlr.press/v305/liu25a.html) uses long-context
  adaptation and a very large procedurally generated robot population to
  evaluate a single policy on unseen legged and wheeled robots.

These are meaningful generalization results. Their typical unit of delivery is
a research policy, generator, benchmark, or training codebase inside a chosen
simulation stack. They do not collectively supply LoColemotion's public ABI,
three unrelated native engine adapters, host characterization, deterministic
fallback, OOD/refusal contract, real-physics editor, immutable evidence chain,
clean-room package, or long-term support matrix.

LoColemotion therefore does not claim to have invented universal morphology
control. Its prospective contribution is the integration: a developer-facing,
procedurally conditioned, multi-engine locomotion SDK whose provider, fallback,
support limits, evidence, and provenance are executable. Training reward and a
finite held-out robot set cannot be substituted for the release contract's
physical or continuous-domain gates.

## Primary Godot JSON semantics used by the R23D57 transport gate

- [Godot 4.7 `JSON.stringify` reference](https://docs.godotengine.org/en/4.7/classes/class_json.html#class-json-method-stringify)
  defines `String stringify(data, indent = "", sort_keys = true,
  full_precision = false)` and documents that enabling `full_precision`
  includes additional float digits to guarantee exact decoding. R23D57 uses
  the explicit four-argument call `JSON.stringify(data, "", true, true)`.
- This primary API contract justifies the transport mechanism, not a locomotion
  claim. LoColemotion separately proves the concrete Godot 4.7 writer and
  CPython reader over 35 production-shaped records, negative controls, and the
  unchanged evaluator boundary.
- The documentation does not justify changing the physical `2.5e-7`
  configured-readback tolerance, loosening the `1e-15` evidence predicate,
  promoting R23D56 raw rows, or inferring behavior for another Godot version,
  JSON implementation, engine, morphology, or physical population.
- LoColemotion's immutable R23D57 zero-world closure separately binds the exact
  Godot 4.7 and CPython 3.11.9 runtimes, clean-pushed source commit
  `95f6acf3d52bcaffda84833dc59d39a38f8c7f42`, 35-record cohort, boundary
  controls, and replay result. That executable evidence closes only the cited
  transport mechanism; it supplies no physical or turning authority.

## R24D6 observed Godot JSON parse and Variant-type boundary

- The R24D6 result uses the same pinned Godot `JSON.stringify` source boundary
  but distinguishes decimal fidelity from Variant-type preservation.
  Full-precision serialization preserved exact binary32-derived float values;
  it did not restore integer types lost when the synthetic JSON template was
  parsed into runtime Variants.
- The exact clean-pushed source
  `55032839756cc8a9089a2a4eb4e06db71ab99ca4` and retained custom Godot/Jolt
  runtime produced `313` integer-to-double projections across `21` normalized
  path families. `234` values across `9` families were subject to the frozen
  evaluator's strict integer predicates, with the first failure at
  `$.fixture.collision_layer`.
- This is repository-owned finite runtime evidence, not a claim that every JSON
  implementation or Godot version has identical behavior. Its immutable
  authority is
  [`../../sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json`](../../sdk/recovery/r24d6_godot_jolt_one_hinge_telemetry_zero_world_failure_closure_v1.json).
  The attempt opened zero worlds and grants no recovery, prone-to-standing,
  turning, equivalence, physical-acceptance, or release authority.

## R24D7 prospective integral-Variant restoration boundary

- R24D7 treats R24D6's 313 observed integer-to-double projections as a finite
  repository-owned design input, not as a population estimate or permission to
  rewrite R24D6. The immutable R24D6 closure and audit remain exact predecessor
  bindings.
- The prospective schema enumerates 21 normalized path families and all 313
  intended integral occurrences. Restoration is permitted only for declared,
  finite, exactly integral parsed floats and must preserve their numerical
  values. No heuristic inference from a field name or observed outcome is
  allowed.
- The evaluator requires integer Variants at all 313 locations and rejects one
  type-loss mutation from every family, alongside 29 inherited controls. This
  is an executable adequacy argument for the bounded serialized-envelope
  oracle, not evidence about native motor behavior.
- Exact clean-pushed source
  `ab6e763e466db86ea1d6fea6b72a23a68ff63587` subsequently passed the complete
  official zero-world qualification with all 313 intended integers restored and
  actual `0/0/0` execution. This is bounded repository transport evidence, not
  native telemetry characterization.
- The sole physical development attempt exposed a distinct timing-control
  defect. Pinned Godot/Jolt source shows `_integrate_forces` is delivered from
  `flush_queries` after `JoltSpace3D::step` cleared `stepping`, so the probe did
  not test the native binding's active-step refusal. The immutable closure is
  [`../../sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json`](../../sdk/recovery/r24d7_godot_jolt_one_hinge_telemetry_physical_failure_closure_v1.json).
  It grants no telemetry, recovery, prone-to-standing, turning, equivalence,
  physical-acceptance, or release authority.

## R24D8 pinned Godot/Jolt step-order boundary

- The R24D8 timing design is grounded in exact source at Godot `4.7-stable`
  commit `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88`, not in a generic callback
  assumption. `SceneTree::physics_process` emits `physics_frame` before the
  main loop later calls `PhysicsServer3D::step`.
- In the pinned Jolt integration, `JoltSpace3D::step` sets its stepping flag,
  calls `PhysicsSystem::Update`, then performs the prospective telemetry
  capture before `_post_step` and before clearing the flag. The public telemetry
  method explicitly refuses reads while that flag is true.
- Bundled Jolt's `ConstraintManager` calls `SetupVelocityConstraint` only for
  active constraints, and `TwoBodyConstraint::IsActive` requires at least one
  connected active body. This supplies the exact source basis for the declared
  sleeping stale-snapshot negative control; it is not a claim about another
  Jolt revision or another engine.
- The combined patch is retained at
  [`../../sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch`](../../sdk/adapters/godot/engine_patches/godot_4_7_jolt_motor_telemetry_active_step_snapshot_v2.patch)
  with raw SHA-256
  `9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c`.
  Its local compile and mutation checks are development evidence only. The
  official cold zero-world qualification and physical timing question remain
  unexecuted at this boundary.

## R24D9 source-derived numerical bound

- The R24D9 numerical characterization retains the exact Godot `4.7-stable`
  source identity `5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88` and the exact combined
  Godot/Jolt v2 patch SHA-256
  `9629982deb74da1d3e16ea8eaff7cefef7c37a33f407c4cd777e332f05ff376c`.
- Its sole hard numerical comparison comes from the frozen native motor clamp:
  `max(abs(min_torque_limit_nm), abs(max_torque_limit_nm)) * solver_step_s`.
  This is a source/configuration identity check, not an empirical threshold and
  not a value selected from R24D7 or R24D8 observations.
- Exact declaration authority is
  [`../../sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json`](../../sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_characterization_preregistration_v1.json).
- The implemented evaluator uses the source-derived clamp only as a descriptive
  recomputation and explicitly accepts adverse finite cap outcomes. Its
  implementation identity and `46` negative controls are bound by
  [`../../sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json`](../../sdk/recovery/r24d9_godot_jolt_one_hinge_numerical_telemetry_validation_manifest.json).
  Four failed serialization diagnostics and one local compatibility pass are
  retained in
  [`../../sdk/recovery/r24d9_precommit_zero_world_diagnostics_v1.json`](../../sdk/recovery/r24d9_precommit_zero_world_diagnostics_v1.json);
  they contain no native numerical observation. Numerical residuals, sign,
  work, and cap behavior remain unobserved under R24D9 until its own complete
  cold zero-world gate and prospective physical freeze pass.

## R24D24 primary MuJoCo contact-geometry semantics

- The [MuJoCo `mjContact` API reference](https://mujoco.readthedocs.io/en/stable/APIreference/APItypes.html#mjcontact)
  defines `pos` as the midpoint between the two nearest geom points, `dist` as
  their signed distance with penetration negative, and the first `frame`
  vector as the normal from geom 0 to geom 1.
- R24D24 therefore reconstructs the two nearest surface points exactly as
  `geom0 = pos - dist * normal / 2` and
  `geom1 = pos + dist * normal / 2`, then selects the point belonging to the
  named torso geom. This source-derived algebra adds no empirical penetration
  threshold or margin.
- The documentation justifies the observer definition, not its physical
  outcome. The separately frozen native R24D24 decision supplies the bounded
  evidence that the observer preserves ventral-prone classification through
  the two declared MuJoCo settling steps.

## R24D31/R24D32 MuJoCo native-work source boundary

- The official [MuJoCo simulation pipeline](https://github.com/google-deepmind/mujoco/blob/main/doc/programming/simulation.rst)
  separates `mj_step1`, control assignment, `mj_step2`, and integration. R24D31
  therefore copies generalized velocity at the split-step pre-integration
  boundary instead of inferring it from a later mechanical-energy residual.
- The official [`mjData` API reference](https://mujoco.readthedocs.io/en/stable/APIreference/APItypes.html#mjdata)
  exposes actuator, constraint, damper, fluid, and adhesion generalized-force
  fields as distinct native sources. R24D31 retains their signed work terms
  separately; R24D32 checks their step and cumulative sums on every retained
  physical observation.
- This documentation supports source semantics, not physical adequacy. The
  two-step R24D32 integration smoke proved only that the exact source/runtime
  path instantiated and satisfied its declared invariants. The later qualified
  finite decision completed `1,520` outer steps and independently confirmed all
  component identities, but retained a `0.7256340038771327 J` minimum raised
  residual against the unchanged `0.25 J` limit. The cited APIs justify the
  source fields and split-step measurement boundary; they do not identify the
  remaining residual as numerical integration, force staging, missing work, or
  threshold error. That distinction requires retained-trace and frozen-source
  diagnosis before another physical successor.

## R24D32 implicit-step diagnosis source refinement

- MuJoCo's official [computation documentation](https://mujoco.readthedocs.io/en/stable/computation/)
  describes `implicit` and `implicitfast` as velocity-implicit methods whose
  effective solve uses derivatives of smooth generalized forces with respect
  to velocity. Those derivatives include actuation; this matters for the exact
  direct velocity servos used by R24D32.
- Combining that primary-source fact with the frozen route establishes a source
  mismatch: R24D32 retained reported force times pre-integration velocity,
  while its integrator's discrete velocity update contains a velocity-dependent
  actuator term not represented by that product.
- The retained endpoint-centered projection is LoColemotion evidence, not an
  external claim and not an accepted replacement formula. It materially lowers
  the discrepancy but still misses the frozen gate. Per-native-substep
  measurement and independent zero-world algebra are required before a v3
  ledger can be qualified.

## Research-use rules

1. Paper claims are external observations. They do not enter accepted
   LoColemotion knowledge merely because this ledger cites them.
2. A paper-derived behavior change must be separately developed on already
   opened bodies, removed, preregistered, implemented, frozen, and tested on a
   fresh population before it can support a LoColemotion claim.
3. Source hashes identify the reviewed PDF versions. A later paper revision
   must receive a new row or explicit supersession note.
4. Strict physics and safety gates remain unnormalized booleans. Reward or
   score improvements cannot cancel a contact, structure, no-cheat, timeout, or
   containment failure.
5. Engine-neutral semantics must never erase engine-specific observation
   quality. Contact points, normals, impulses, solver settings, and actuator
   behavior retain provenance and capability labels.
6. The SDK must expose out-of-distribution status and bounded fallback behavior
   rather than silently pretending that a morphology or adapter is certified.
7. Campaign dependencies that require raw checkout-to-Git-blob identity must
   declare a platform-stable line ending instead of relying on host defaults.

## R24D33 MuJoCo 3.11 implicit-step source binding

- The tagged MuJoCo 3.11
  [`mj_implicitSkip` source](https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_forward.c)
  constructs the `implicitfast` solve from `qfrc_smooth + qfrc_constraint`
  and `M - timestep * qDeriv`, then advances velocity with the solved
  acceleration. The reviewed raw source digest is
  `sha256:f44d0de9a2f81faf58812c70b97bf0e64070561134e4c7f6a46e3a176e8fd862`.
- The tagged
  [`mjd_actuator_vel` source](https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_derivative.c)
  maps actuator velocity derivatives through `actuator_moment` and skips an
  actuator's derivative when its reported scalar force is at either force
  limit. The reviewed raw source digest is
  `sha256:1bd041b6ccc61e51d771d7f07bc707d10496d60db07d81755c972f4c56310c35`.
- Those source branches justify R24D33's algebra for the exact direct scalar
  velocity-servo subset. They do not establish that the later full trajectory
  meets LoColemotion's unchanged energy gate; physical adequacy remains a
  distinct prospective native result.
- The one official R24D33 qualification at clean-pushed source
  `4e7a94daebec600621cfeb6a1eaee54f43c8a196` retained its complete source and
  toolchain manifest and passed all declared source-derived controls without
  constructing or stepping a model. This qualifies the cited source mapping;
  it adds no empirical or physical claim.

## R24D34 MuJoCo split-step route binding

- The tagged MuJoCo 3.11
  [`mj_step1` and `mj_step2` source](https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_forward.c)
  fixes the public split-step order used by R24D34. After `mj_step1` and control
  assignment, `mj_step2` evaluates actuation, acceleration, constraints,
  acceleration sensors, and acceleration validity before dispatching the
  selected integrator. The reviewed file is the same R24D33-bound source with
  digest
  `sha256:f44d0de9a2f81faf58812c70b97bf0e64070561134e4c7f6a46e3a176e8fd862`.
- R24D34 reproduces those public force and constraint stages in their tagged
  order only to expose a serialized preintegration snapshot, then calls the
  genuine `mj_implicit` entry point exactly once. It does not call `mj_step2`
  on that route and does not perform a second solve or integration. The
  historical v2 ledger remains beside the v3 ledger for every retained native
  substep.
- This source binding supports the route's staging and interpretation, not its
  physical adequacy. The prospective bounded smoke may establish only that the
  qualified production path instantiates, steps, and satisfies its declared
  in-run invariants. It cannot answer recovery behavior, threshold adequacy,
  population coverage, cross-engine equivalence, or SDK release readiness.

## R24D34/R24D35 MuJoCo sparse actuator-moment representation

- The tagged MuJoCo 3.11 public
  [`mjData` definition](https://github.com/google-deepmind/mujoco/blob/3.11.0/include/mujoco/mjdata.h)
  declares `moment_rownnz` and `moment_rowadr` per actuator-output row,
  `moment_colind` per nonzero, and `actuator_moment` as `nJmom` stored values.
  The pinned local 3.11.0 header reviewed after the R24D34 invalid smoke has
  byte length `26294` and digest
  `sha256:e5c1f0bfc1d9338849e05728e94186ff33c66bfc173c853459e5e0f8aa86131c`.
- The tagged
  [`mjModel` definition](https://github.com/google-deepmind/mujoco/blob/3.11.0/include/mujoco/mjmodel.h)
  defines `nJmom` as the number of nonzeros in the sparse actuator-moment
  matrix. The reviewed pinned header has byte length `66202` and digest
  `sha256:2f25d9f7c340acaf018c6502ae01aaac8f2d7487dd6a8f9a605256bfc6c9db67`.
- MuJoCo's public
  [`mju_sparse2dense` API](https://mujoco.readthedocs.io/en/stable/APIreference/APIfunctions.html#mju-sparse2dense)
  is the R24D35 expansion authority. R24D34 instead treated the raw sparse
  value buffer as dense and failed its own shape guard before `mj_implicit`.
  These sources establish the representation defect and successor design; they
  do not establish any recovery behavior, energy-threshold result, or standing
  claim.

## R24D70 Godot/Jolt contact-impulse source adequacy

- Godot 4.7's official
  [Jolt contact-impulse documentation](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html)
  says the Jolt backend estimates contact impulses ahead of time from the
  manifold and body velocities. It limits accuracy to a colliding pair whose
  two bodies are not simultaneously colliding with other bodies. That
  documented condition is false for R70's shared floor and articulated
  multi-contact creature.
- At pinned Godot source
  [`5b4e0cb0`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/modules/jolt_physics/spaces/jolt_contact_listener_3d.cpp#L180-L250),
  `JoltContactListener3D::_try_add_contacts` calls
  `EstimateCollisionResponse` during the contact callback and places that
  estimate in the public body-contact report. The reviewed local file is
  23,117 bytes with SHA-256
  `18db805f8551807d02ff988383d3fbb4e3b38df036235a3b923aa3e09664221b`.
- The same pinned tree's vendored
  [`ContactConstraintManager`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/thirdparty/jolt_physics/Jolt/Physics/Constraints/ContactConstraintManager.cpp#L1713-L1727)
  copies each solved point's total nonpenetration and two friction lambdas into
  the write manifold cache. Finalization then makes that exact cache the read
  cache before `PhysicsSystem::Update` returns. The reviewed local `.cpp` is
  73,085 bytes with SHA-256
  `4af02c429fc50581ff3a9e0937713ea6c047597691ba514ac5bfc01d627f5d75`.
- These primary sources justify a post-solve observation route, not its
  implementation or adequacy. R70's retained whole-system momentum mismatch is
  the project evidence rejecting the public estimate for this exact world.
  R71 now implements the observation route and its complete source, step,
  population, ambiguity, invalid-RID, and pure-data mutation controls. Exact
  clean-pushed source `09fcdf58` passed the sole official zero-world
  qualification with four current workers, 18 mutation rejections, zero
  historical-audit replay, and zero physical steps. A separately declared and
  qualified minimal native calibration remains required before physical source
  accuracy is claimed. A distinct prospective behavior result is still
  required before solved contact values can support standing.

## R24D93 Godot/Jolt angular-velocity safety boundary

- Godot 4.7's official
  [`physics/jolt_physics_3d/limits/max_angular_velocity` setting](https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html#class-projectsettings-property-physics-jolt-physics-3d-limits-max-angular-velocity)
  documents the Jolt angular-velocity cap as a fail-safe against simulation
  explosion and gives a default of approximately `47.12389 rad/s`. R93 reads
  the effective value from the selected runtime at execution instead of
  assuming the documented default.
- In the exact Godot source lineage used by the selected runtime, vendored
  Jolt's
  [`MotionProperties::SetAngularVelocity`](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/thirdparty/jolt_physics/Jolt/Physics/Body/MotionProperties.h)
  asserts that the requested angular-velocity magnitude does not exceed that
  body's configured maximum. This supports treating the R92 assertion as an
  engine-health validity signal; it does not identify its physical cause.
- A development-only zero-world observation from the exact selected runtime
  serialized the effective setting as `47.1238899230957 rad/s`. That
  observation is not the official R93 qualification and establishes no
  behavioral threshold, safety margin, recovery result, or engine-general
  conclusion. R93's comparison uses exact less-than-or-equal with zero invented
  margin, retains all nine source-measured body vectors and norms per native
  step, and refuses incomplete or unhealthy populations before interpretation.
- The later sole official R93 zero-world qualification observed the same exact
  selected-runtime value and passed the complete deterministic validity gate:
  four positives, 13 forced failures, one production-worker parse, and zero
  models, worlds, or solver steps. Its content-addressed closure qualifies the
  implementation of this source-derived boundary only. It does not establish
  a safe physical operating margin, diagnose R92's cause, authorize raising the
  engine limit, or provide recovery evidence.

## R24D152 provenance change has no new empirical source or margin

- R152 introduces no literature-derived or empirical threshold, safety factor,
  equivalence margin, non-inferiority margin, or population assumption. Its
  acceptance predicates are exact identity and schema conjunctions.
- The outer R148 route and mapping, R144 solver-coupled partition, and R151
  complete-energy authority are already versioned repository evidence. R152
  names their producer/consumer relationship explicitly rather than modifying
  any observed physical value or historical interpretation.
- The two-step ceiling is justified only by code-path coverage: one native
  sample consumes bootstrap application and the next consumes active
  application. It is not a locomotion threshold and cannot support recovery,
  standing, robustness, morphology, or cross-engine inference.

## R24D106 source-derived joint-target monotonicity

- R106 introduces no external empirical source, threshold, safety factor, or
  acceptance margin. For each retained R105 actuator source it uses the
  controller's already-declared canonical target velocity and the exact
  relative-velocity delta induced by the complete nine-body aggregate impulse
  population.
- The proposed bound follows directly from the affine prewrite projection
  `qdot_predicted = qdot_source + scale * delta_qdot`: when the delta points
  toward the target, the first nonovershooting scale is
  `abs((target - source) / delta_qdot)`; when a nonzero delta points away from
  the target, the population scale is zero. The minimum across all eight
  joints is binary32-floored and composed with the existing engine-derived body
  guard. This is a source-derived numerical bound, not a statistical margin.
- Applying that calculation to the immutable R105 sources is explicitly a
  nonpredictive zero-world sensitivity. It establishes that 238 positive
  common scales and two population holds exist on those retained states and
  that their affine predictions do not cross a joint target. It does not
  establish the subsequent solver trajectory, distal support, recovery,
  standing, repeatability, population behavior, or cross-engine validity.

## R24D94 source-derived representation headroom

- R94 retains R93's exact selected-runtime limit and does not alter the Godot
  project setting. Its guard is derived prospectively from IEEE-754 binary32
  machine epsilon (`2^-23`) times a fixed `1024` error multiplier. Applying
  that relative headroom and projecting once into binary32 gives
  `47.11813735961914 rad/s`, or `0.0057525634765625 rad/s` below the observed
  runtime limit.
- This headroom covers representation and sequential application error in the
  guarded host calculation. It is not inferred from the 191 R92 assertions,
  not a recovery threshold, not a population margin, and not evidence that the
  resulting physical controller stands. The complete pure-data mutation
  population and a separately qualified production-route ghost are required
  before the mapping can become input to another behavior question.
- R94's sole official zero-world qualification passed the complete guard
  population under the selected runtime. Its later authorization limit is a
  live-publication predicate defect, not a negative observation about the
  guard mathematics or native physics; no physical world was opened.

## R24D155 source-derived rotational staging boundary

- R155 introduces no external empirical source, threshold, margin, or
  population assumption. It uses the frozen R17 `0.25 J` predicate unchanged
  and binds the exact R146/R154 retained traces and Godot/Jolt source blobs.
- The patched native mechanical-energy snapshot explicitly computes rotational
  kinetic energy from angular velocity and the inertia transformed by current
  body rotation. The R148 staging observer's declared inputs are linear
  velocity, gravity, body translation, and position-constraint displacement;
  it contains no pre/post rotation, angular-velocity, or inertia boundary.
- The R148 authority also freezes gyroscopic forces as disabled for this exact
  engine profile. Therefore orientation integration can change the rotational
  term represented by the mechanical-energy snapshot without a corresponding
  R148 staging observation. This is a structural coverage finding, not evidence
  for the sign or magnitude of that exchange and not proof that it fully
  explains R154.
- R156 must derive its measurement equation from the exact native integration
  stage and validate analytic zero-rotation, principal-axis, and off-principal-
  axis controls before the term can enter a future ledger. Outcome residual,
  acceptance threshold, and behavior result remain forbidden observer inputs.

## R24D156 source-derived rotation-integration design

- R156 adds no external empirical source, physical threshold, margin, or
  population assumption. It binds pinned Godot `4.7-stable`, the exact v4/v5
  source chain, R148's observer, R155's retained diagnosis, and the additive v6
  patch.
- Jolt's source orders velocity constraints, `JobIntegrateVelocity`, CCD, then
  position constraints. Inside the integration job it left-multiplies body
  orientation by the axis-angle rotation formed from current world angular
  velocity and `dt`, before translating the body.
- The derived identity is `R_post = Q(omega dt) R_pre` and
  `Q(omega dt)^T omega = omega`. Therefore
  `R_post^T omega = R_pre^T omega`, so the ideal anisotropic rotational kinetic
  energy is unchanged even when body-frame angular velocity is off a principal
  axis. Three analytic cases confirm this within a deterministic binary64 ULP
  implementation bound; that bound is not physical acceptance authority.
- The exact native float32 implementation includes axis-angle construction and
  quaternion normalization, so its finite accumulated roundoff is not assigned
  from the analytic result. The v6 measurement must be compiled, bound, and
  exercised prospectively before any magnitude statement. Whole-step residual,
  the existing `0.25 J` predicate, controller outcome, and behavior result remain
  forbidden inputs.

## R24D157 implementation evidence adds no empirical threshold

- R157 adds no literature-derived or empirical threshold, margin, or population
  assumption. It binds a full clean build of the exact R156 source, the resulting
  binary pair, build transcripts, and an exact source/patch/blob chain.
- The zero-world observations are categorical: method registered, invalid RID
  refused, complete synthetic schema accepted, and 17 malformed or incomplete
  consumer inputs rejected. Synthetic numeric component values exercise
  arithmetic only and are not physical measurements or calibration data.
- Native rotation-exchange field population and magnitude remain unobserved
  because they require a real solver step. R158's maximum two-step development
  smoke is justified only by route coverage, not as a sample-size or behavior
  adequacy claim.

## R24D158 route adequacy adds no empirical threshold

- R158 introduces no external source, empirical threshold, margin, or cohort.
  It binds the exact R157 implementation evidence and uses one deterministic
  non-held-out seed only to name its finite development identity.
- One off-principal-axis anisotropic body reaches the instrumented native
  rotation call, while its center pin creates a constrained island without
  prescribing angular motion. Two steps are required only to distinguish a
  current first read from a consecutive second read.
- The accepted value may have any finite sign or be exactly zero. The smoke
  records native float32 observations but supplies no effect-size adequacy,
  population inference, causal attribution to R154, recovery claim, or
  behavioral acceptance authority.
- The sole official zero-world qualification passed at exact freeze
  `07172a2d` and authorizes that finite observation once. This publication
  change adds no numerical criterion and no physical measurement; the world
  remains unattempted.

## R24D159 launcher correction adds no evidence assumption

- R159 is derived entirely from the frozen R158 contract and supervisor. The
  missing evidence-directory name and empty-string path resolution are exact
  source facts; no physical result, literature value, or empirical tuning is
  involved.
- Requiring one nonempty ASCII-safe child name is a storage-integrity rule, not
  a physical threshold or population margin. The R158 runtime, fixture, seed,
  horizon, read count, and admissible finite values remain unchanged.
- The distinct qualification-gate and worker-gate binding preserves provenance
  for the source correction. It supplies no effect-size, recovery, standing,
  robustness, or cross-engine evidence.
- The repeatable development gate passes entirely at zero worlds and adds no
  measurement to this ledger. The sole official clean-source qualification at
  `0b3ec11c` also adds no measurement; it only authorizes the preserved finite
  observation once.
- The sole authorized invocation at `9f4a61ac` emitted no raw or report receipt
  after a null `viewport.world_3d.space` access and timeout. Its Jolt job-
  capacity warning is retained as a diagnostic, not interpreted as a native
  measurement, physical negative, effect estimate, or population datum.
- R160's effective-world correction is justified by the exact frozen failure
  site and Godot object-lifecycle semantics. It introduces no empirical
  threshold, equivalence margin, additional seed, cohort, or claim about the
  missing native value.
- Godot 4.7's official
  [Viewport reference](https://docs.godotengine.org/en/4.7/classes/class_viewport.html)
  defines `world_3d` as the explicitly assigned custom world and
  `find_world_3d()` as the effective-world lookup; the official
  [Node3D reference](https://docs.godotengine.org/en/4.7/classes/class_node3d.html)
  defines `get_world_3d()` as the world to which the inserted node is actually
  registered. Those API contracts motivate R160's lookup correction but do
  not substitute for its prospective native observation.

## R24D160 route correction adds no empirical evidence assumption

- R160 preserves R158's deterministic seed, one-world/two-step ceiling,
  fixture, runtime, admissible finite values, and no-population claim. It adds
  no physical threshold, equivalence margin, cohort, or behavior predicate.
- The new child-in-tree, effective-world-stability, valid-RID, and RID-binding
  checks are categorical lifecycle invariants. The exact two-step and one-
  deactivation counts are route-completion facts, not success criteria fitted
  to an outcome.
- The repeatable source/route gate remains zero-world work: two positives, five
  targeted failures, and one missing-switch refusal. Its reusable declarative
  text controls verify the changed source shape but provide no observation of
  physics or the v6 field.
- A sole official clean-source qualification is required before the finite
  physical observation can open. Until then, no native magnitude, recovery,
  prone-to-standing, robustness, equivalence, or release claim exists.
- That sole qualification passed at clean, pushed, live-equal freeze
  `a383f088`. It adds categorical implementation authority only: the exact
  one-world/two-step observation is now authorized once but remains physically
  unattempted, so no empirical datum or claim is added to this research ledger.

## R24D160 finite native observation adds two exact fixture values

- The single authorized one-world/two-step observation completed validly from
  live-equal `f79dec82`. Current consecutive read sequences `2` and `3` passed
  all `30/30` in-run invariants and both 38-check v2 consumptions with empty
  stderr and valid supervised termination.
- The exact signed rotation-integration kinetic exchanges are
  `+1.4901161193847656e-8 J` and `-1.4901161193847656e-8 J`. Their finite values
  establish native field population for this fixture; their signed two-sample
  sum of zero is retained but is not a physical threshold or a population
  estimate.
- No literature value, empirical margin, or outcome criterion is introduced.
  R160 does not establish that the channel explains or fails to explain R154,
  and does not authorize recovery-ledger adoption, controller change, standing,
  robustness, equivalence, or release claims.
- R161 may compare immutable evidence at zero worlds using source-derived
  arithmetic, but it must keep R154's `0.25 J` predicate unchanged and state
  explicitly why this finite fixture does or does not justify a distinct
  prospective integration question.

## R24D161 uses exact observations without inventing a scale law

- R161 binds R154, R155, R157, and R160 by exact bytes and SHA-256 while
  re-executing zero historical closure audits. The two source bindings show the
  current production recovery call to the legacy v1 consumer and the qualified
  v2 consumer's explicit addition of `rotation_integration_kinetic_exchange_j`.
- The R160 pair, `+1.4901161193847656e-8 J` and
  `-1.4901161193847656e-8 J`, remains a two-observation fixture result. Its
  signed cancellation is not generalized, and its maximum absolute value is
  not promoted into a physical omission margin.
- R154's two-world, 905-step recovery result is a different population. No
  source, retained authority, or external reference supplies a scale transform
  from R160 to R154, so R161 does not estimate a missing residual fraction or
  alter the frozen `0.25 J` threshold.
- R162 is selected on measurement-completeness grounds only: a qualified,
  independently measured channel exists but is not yet consumed by the
  production recovery route. Integrating it does not assert that it is large,
  causal, behavior-improving, or sufficient for prone-to-standing.

## R24D162 integrates qualified measurement without adding empirical claims

- R162 introduces no new external literature or physical observations. It
  binds R161, the retained v6 runtime, the already-qualified v2 consumer, and
  the current recovery source through a clean 22-entry manifest.
- The production selectors now admit the rotation-aware consumer only for the
  exact R162 context and retain the legacy v1/13-term path otherwise. The new
  14-term partition includes rotation once and subtracts native motor work once;
  ten mutations demonstrate fail-closed behavior for incomplete, stale, or
  crossed authority.
- The official result is entirely zero-world: no R160 value is replayed, no
  R154 trajectory is resampled, and no scale law, causal estimate, threshold,
  behavior improvement, standing claim, or release authority is introduced.
- R163 may define a separate prospective production-path ghost only after its
  cell set and horizon are justified. R162 itself authorizes no physical work.

## R24D163 qualifies route coverage without adding empirical evidence

- R163 adds no external literature, physical observation, threshold, margin,
  or recovery outcome. Its sole official qualification binds the R162 closure,
  exact native-v6 pair, 69 frozen source entries, four source controls, and a
  fresh host build at zero worlds.
- Six positive cases establish that the exact rotation-aware identity reaches
  production construction, collection, planning, and mapping. Seven targeted
  refusals plus the missing-switch process refusal reject incomplete, stale,
  crossed, wrong-gate, and legacy identities.
- The smallest adequate physical question is one development seed, one world,
  and two outer steps because that traverses both sampling boundaries, two
  collections and plans, one application, and terminal receipt publication.
  No behavior evaluator, matched-zero arm, extra seed, or full horizon is part
  of the question.
- The closure grants executable authority only for that one route ghost. It
  does not make an energy magnitude causal, generalize R160 to R154, claim
  recovery success or standing, or change readiness.

## QSDK-R10F adds no external empirical assumption

- R10F introduces no new paper, external benchmark, physical observation,
  threshold, learned parameter, or causal model. It binds already-retained
  R10E-L3, R172/R173, R05E, selected-policy, actuator-profile, turning-scope,
  SDK1-mapping, and implementation-source authorities.
- The native lateral challenge remains exactly `0.25 N s`; its size and
  direction are not selected from an R10F result. The BW5R-B policy, S169
  descriptor, actuator caps, V6 recovery policy, materials, and acceptance
  limits likewise remain prospective inputs rather than fitted outputs.
- The new `G`/`E`/`L` epoch is measurement bookkeeping for one continuous body.
  Initializing the recovery ledger from complete live energy at `E` does not
  assert that any energy term explains the fall or recovery, and it changes no
  allowed residual.
- Development seed `40200` and held-out seeds `40201`-`40203` identify finite
  populations; they do not imply a robustness rate, general self-righting,
  force-aware response, cross-engine equivalence, or arbitrary-body support.
- The design audit is entirely zero-world. A positive route, finite M07
  decision, support claim, and any later Explorer presentation each require
  their own prospective authority and evidence.

## Recovery posture/contact coordination review, 2026-09-29

The publisher/repository abstracts were checked for two primary sources:

- Di Carlo et al., 2018, [Dynamic Locomotion in the MIT Cheetah 3 Through Convex
  Model-Predictive Control](https://dspace.mit.edu/entities/publication/bc8c7e1e-5830-443f-a879-787947111fcf).
  The work optimizes ground reaction forces using simplified three-dimensional
  dynamics for a torque-controlled quadruped.
- Fahmi et al., 2019 revision, [Passive Whole-body Control for Quadruped Robots](https://arxiv.org/abs/1811.00884v2).
  Its formulation includes rigid-body dynamics, contact interaction, joint limits
  and actuation limits while tracking trunk motion.

Our inference is that contact support and torso attitude should be planned
jointly. R10AL is only a bounded kinematic feasibility study informed by that
principle; it implements neither paper's MPC/QP controller, force optimization,
passivity proof, nor demonstrated robustness. Abstract-level review is not a
full derivation review. No paper binary was downloaded or redistributed here.
The direct project evidence is the immutable R10AJ posture diagnosis and R10AL's
retained geometry results. Physical contact acquisition, friction and force
tracking remain questions for a distinct prospective native successor.

## R10AR stationary multi-contact modeling references, 2026-09-30

- [Russ Tedrake, Underactuated Robotics: Multi-Body Dynamics](https://underactuated.mit.edu/multibody.html): generalized manipulator equations and the contact Jacobian-transpose mapping. R10AR uses the stationary restriction; acceleration and Coriolis terms are explicitly excluded.
- [Russ Tedrake, Robotic Manipulation: Bin Picking](https://manipulation.mit.edu/clutter.html): static equilibrium, unilateral contact and Coulomb friction. R10AR declares an inner linear friction pyramid using the existing authored coefficient; this does not validate native dynamic friction.
- [SciPy 1.16.0 linprog highs-ds documentation](https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.linprog-highs-ds.html): installed-version linear-program interface, bounds and marginal sign conventions. The study binds the local solver files and checks primal/dual residuals independently of the success flag.

These references support the [R10AR model declaration](../../sdk/recovery/r10ar_multicontact_statics_study_v1.json), not a physical recovery or release claim. The retained 601-pose population remains exposed development evidence; a stationary model allocation is not a measured native force or a realizable control trajectory.

## R10AS contact-preserving differential motion, 2026-09-30

- [MIT Robotic Manipulation: Basic Pick and Place](https://manipulation.mit.edu/pick.html): spatial transforms, point Jacobians and constrained differential inverse kinematics. R10AS uses a measured-frame retraction and checks analytic contact Jacobians independently by finite differences.
- [MIT Underactuated Robotics: Multi-Body Dynamics](https://underactuated.mit.edu/multibody.html): generalized constraints and contact forces. R10AS retains R10AR stationary-force assumptions; contact-preserving geometric increments are not dynamically realizable motor commands by implication.
- The [R10AS declaration](../../sdk/recovery/r10as_contact_motion_study_v1.json) binds one exposed entry input, one support mode, exact numerical bounds and all limitations before evaluation. Its result proves only admission of five sampled model poses, not a recovery trajectory or a physical claim.

## R10AT/R10AU contact-mode limits, 2026-09-30

- R10AT retains a 32-step admitted fixed-contact model path and the finite-progress refusal at step33. R10AU enumerates all128 source-contact subsets and records63 stationary-feasible sets and252 motion problems. These are distinct retained-input model studies, not native or held-out attempts.
- [MIT Robotic Manipulation: frictional contact](https://manipulation.mit.edu/clutter.html) distinguishes stationary force balance, collision geometry, point-contact approximations and friction. [MIT Underactuated Robotics: multibody contact](https://underactuated.mit.edu/multibody.html) supplies the generalized contact constraints and frictional mechanics background. Contact velocity and allowed force must remain consistent when a successor permits sliding or rolling; simply unpinning coordinates is insufficient evidence.
- The current zero torso-motion results apply only to the declared measured-point sticking/non-descent model. The retained sampling/callback-stage mismatch and existing penetration may make that model too restrictive. No physical impossibility or dynamic equivalence is asserted.

## R10AV/R10AW sliding-force consistency and geometric diagnosis, 2026-09-30

- [MIT Underactuated Robotics: Coulomb friction and maximum dissipation](https://underactuated.mit.edu/multibody.html) describes sticking versus sliding and polyhedral friction models. R10AV uses the exact opposing extreme vertex for the existing inner diamond and its matching signed dominant-velocity sector; it does not apply the circular-cone direction rule to a diamond.
- R10AV's128-subset model refuses all entry slides. R10AW's102 diagnostic LPs identify tangential anchoring of selected foot/leg contacts as an active model restriction. Relaxed diagnostics are not admissible physical steps; a successor must enforce contact-specific velocity/force consistency.
- Existing native shape-source inspection confirms capsule segment length plus two radii in Godot and capsule_y(segment/2,radius) in Rapier. The reported contact points remain close to authored surfaces in callback coordinates, while original penetration and moving-state limitations remain explicit.

## R10AX/R10AY/R10AZ coupled mode search and work units, 2026-09-30

- [SciPy 1.16.0 milp reference](https://docs.scipy.org/doc/scipy-1.16.0/reference/generated/scipy.optimize.milp.html) specifies integrality, finite variable bounds, linear constraints, solver limits and reported MIP bounds. R10AY/R10AZ bind the installed solver and derive conditional bounds from declared coordinate, force and torque boxes. Selected fixed modes receive independent continuous-LP certificates; the global mixed-integer bound is solver-reported only.
- R10AX retains 729 prescribed-sector modes with no admitted entry motion. R10AY's original attempt is invalid after a work-check assertion: a displacement error inside the geometry tolerance can exceed the separate energy tolerance when multiplied by a force. The exact failed source and candidate remain immutable.
- The distinct R10AZ work-refusal successor keeps both tolerances and admits only a 1.378532-micrometer torso step at 1/256 scale. A linear step followed by contact-height projection does not automatically preserve the nonlinear friction sector. The next motion law must enforce those constraints jointly; this result does not justify relaxing them.
- The four sliding sectors choose extreme forces of the existing inner friction diamond. They do not cover every convex combination of adjacent extreme forces at tied sector boundaries. No global physical-impossibility, native-friction, sustained-path or recovery claim follows from the finite search.

## R10BA joint nonlinear geometry, 2026-09-30

- [SciPy 1.16.0 SLSQP reference](https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.minimize-slsqp.html) describes nonlinear constraint optimization, tolerances and local QP multipliers. R10BA pins the installed backend and explicitly differentiates normalized constraints. Solver success is only a proposal; raw-unit geometry, stationary-load certificates and maximum-dissipation work are independent admission checks. No global nonlinear optimality is asserted.
- The full four-node step advances the torso 0.351286 mm under unchanged guards, resolving the R10AZ projection limitation for this initial fixed contact mode. The remaining 95.217771 mm foot-hull gap and required nonfoot support keep sustained transfer and native realization open. A successor must retain global constraints during propagation and explicitly declare any contact-mode transition.

## R10BB/R10BC path limits and contact eligibility, 2026-09-30

- R10BB propagates five admitted R10BA-law steps with global anchor/floor/headroom checks; step six hits the unchanged nonlinear iteration bound at effectively zero torso progress. The terminal rear-left hip is at its headroom boundary. This is retained finite model evidence, not a new physical trial or a regrade of R10AP.
- R10BC excludes original markers that lifted above their original contact heights from every active mode. Its terminal fixed-mode LP certifies zero forward tangent progress; the bounded eligible-contact mixed-integer search also selects a zero-progress mode. Independent fixed-mode certificates do not certify the global mixed-integer bound or nonlinear physical impossibility.
- These results motivate direct support-transfer planning and preparatory posture motion. The forward torso-motion objective is a development proxy, not the recovery acceptance requirement. Any successor must prospectively state its objective and contact-transition rules while retaining physical safety and claim thresholds.

## R10BI incomplete execution and R10BJ numerical successor, 2026-09-30

- R10BI logged93 admitted increments before a secondary LP reported
  infeasibility during an integration probe. An unhandled assertion prevented
  full trajectory/result publication. The exact failure is retained and closed;
  progress logs cannot replace per-node artifacts or an independently replayed
  path. No physical impossibility or successful recovery follows from it.
- R10BJ keeps the motion objective and physical bounds, scales the secondary
  near-optimum row by a positive norm without changing the represented bound,
  and uses analytic shape-floor Jacobians verified against finite differences.
  The combined numerical successor does not isolate a single causal change.
- Each R10BJ completed/refused step is durably journaled before continuing.
  Numerical LP failures retain exact matrices, bounds, probe and primary
  feasibility witness when available. Creation and cold replay are separate;
  the replay must reproduce both the complete result and journal content hash.
  Its 119 controls and complete cold replay pass. The 97 admitted increments
  advance the body 32.061034 mm but leave89.950825 mm of foot-hull gap and
  55.042232% nonfoot support; the torso is not unloaded or raised.
- R10BK compares all four declared dual-simplex/interior-point and presolve
  on/off variants on the exact retained step 98 LP. Both presolve-enabled
  variants reproduce the 1.457720726e-6 stationarity residual; both disabled
  variants pass the unchanged 1e-6 certificate check. This localizes this saved
  numerical failure without claiming a general solver defect. R10BJ's refusal
  remains immutable. R10BK's129 controls and complete cold replay pass.
- [SciPy 1.16 dual simplex reference](https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.linprog-highs-ds.html)
  documents presolve, statuses and marginal signs; the
  [interior-point reference](https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.linprog-highs-ipm.html)
  documents the alternate method and crossover. Solver success alone is not
  admission; independently recomputed primal/dual checks remain mandatory.

## R10BI material-velocity rolling-contact model, 2026-09-30

- [MIT Underactuated Robotics: Multi-Body Dynamics](https://underactuated.mit.edu/multibody.html)
  describes contact velocity through a Jacobian, generalized contact force
  through its transpose, zero tangential velocity for sticking, and opposing
  maximum-dissipation forces for sliding. These distinguish movement of a
  geometric contact location from velocity of the material at that location.
- R10BI updates classified foot sites to current spherical-cap bottoms and
  constrains the material velocity evaluated there. A moving lowest point is
  not itself evidence of sliding. Manufactured sphere tests verify nonzero
  center motion with zero material contact velocity under pure rolling.
- Bounded numerical kinematic integration replaces repeated fixed-marker
  displacement constraints. Independent loads and material-work checks remain
  sampled at four nodes per increment; they do not certify continuous force
  feasibility, contact acquisition or inertial dynamics. No controller or
  release claim follows. The incomplete execution closure is described above;
  there is no complete R10BI result available for path replay.

## R10BG/R10BH rear placement and material-anchor mobility, 2026-09-30

- R10BG keeps the body/front joints fixed and moves unloaded rear spherical-cap
  sites at fixed modeled height. Its one admitted step reaches the rear-left hip
  headroom bound; subsequent optimizer refusal and feet-only force infeasibility
  remain in the immutable result.
- R10BH permits coordinated body and limb variables and rear-cap lift, while
  preserving the same three material anchors. The retained anchor Jacobian is
  rank eight on its eight body/front-left columns; its admitted body update is
  effectively zero. Merely exposing body variables does not produce mobility.
  This is a model-local diagnosis, not a native impossibility theorem.
- The source sign check compares `Model.poses` in
  `sdk/conformance/r10as_contact_motion_study.py` with
  `_signed_relative_angle_z`, `_signed_basis_angle_z` and
  `_joint_rate_from_snapshots` in
  `sdk/adapters/godot/gdscript/recovery_native_world_v1.gd`. Positive rotations
  agree about parent +Z. `sdk/core/src/recovery_morphology.rs` retains hip1.60
  and knee1.10 rad bounds. No sign or limit change is supported by this check.
- A sphere's changing lowest geometric point is not one fixed material point.
  R10BG/R10BH avoid claiming loaded rolling by assigning zero force to the
  moving rear sites. Any successor with loaded rolling must explicitly model
  material contact velocity and work. A native controller or a continuous path
  cannot be inferred from sampled geometry and stationary force certificates.
- Full fresh-process replay and controls pass for both studies (98 and103,
  inherited coverage shared). Their separate declarations and refusals remain
  unchanged; no additional physics or release authority is obtained.

## R10BD/R10BF direct load transfer and finite solver admission, 2026-09-30

- [MIT Underactuated Robotics: Planning and Control through Contact](https://underactuated.mit.edu/contact.html) distinguishes contact modes, transition guards and planning with fixed versus searched mode sequences. R10BD/R10BF use a finite quasistatic model; they do not implement impact dynamics or prove native contact acquisition.
- [SciPy 1.16.0 SLSQP reference](https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.minimize-slsqp.html) describes local constrained optimization. Solver success is a proposal status, not recovery admission. R10BF's step31 reports success but fails independently checked load progress at its half-node.
- R10BD couples a first-order force-balance model to contact-mode search and then optimizes nonlinear pose and force together. R10BE prospectively removes exactly zero-force active labels, retaining original and canonical certificates. R10BF initializes force variables from a certified load allocation at each actual fractional pose. All predecessors and refusals remain immutable.
- R10BF retains30 admitted steps and120 sampled poses, reaching nonfoot weight fraction0.222249303 and85.231546 mm foot-hull gap. The unchanged torso and rear joints show that this path redistributes front-limb mass; a declared rear-foot support sequence remains necessary to investigate further transfer. Greedy load descent can reject a useful sequence that temporarily increases body support; this limitation is not a physical impossibility claim.

## R10BL/R10BM forward limit and entry raising directions, 2026-09-30

- R10BL prospectively disables presolve only in velocity LPs, following the
  retained R10BK comparison. The underlying dual-simplex objective, physical
  bounds and 1e-6 independent certificate limit remain unchanged; no status-only
  fallback is admitted. It retains106 admitted increments / 424 sampled nodes,
  followed by the unchanged finite-progress refusal on step 107. Its 135 controls
  and complete cold replay pass, including the exact109-line journal hash.
- Body advance32.073399 mm, remaining foot-hull gap 89.942477 mm, torso drop45.092348 mm
  and 55.048328% required nonfoot support show that this fixed forward objective
  has not achieved unloading. The result is not a proof of global or physical
  impossibility and does not regrade any earlier numerical refusal.
- R10BM tests only three prospectively named world-Y objectives at original
  entry: torso origin and either authored rear hip anchor. It reuses the joint
  six-mode contact search, then rebuilds and independently certifies the selected
  continuous force/velocity problem without binary conditional bounds. Objective
  gradients are checked against finite differences; force balance, linear
  geometry, caps, friction and instantaneous material work are checked separately.
- All three have positive verified instantaneous directions. The torso-raise
  direction raises torso 0.481125 mm and rear-left hip0.742834 mm per model interval.
  Rear-right-hip maximization lowers the torso, so these directions are not
  interchangeable. The142 controls and full cold replay pass. No finite pose or
  controller is adopted by this diagnostic.
- [Installed-version dual-simplex documentation](https://docs.scipy.org/doc/scipy-1.16.0/reference/optimize.linprog-highs-ds.html)
  supports the declared backend and presolve switch; an independent certificate
  remains required. [Multibody contact mechanics](https://underactuated.mit.edu/multibody.html)
  motivates using the same material Jacobian for velocity and generalized force,
  without turning a quasistatic direction into dynamic or native evidence.
- R10BN separately declares a bounded 120-increment torso-raise path from the
  original entry and selected R10BM mode, with unchanged integration and sampled
  admission. It retains 64 admitted increments / 256 nodes, torso rise 30.717001 mm
  and rear-left-hip rise 47.820663 mm. Required nonfoot support increases slightly
  from 47.353622% to 47.794209%; this is preparatory clearance without full unloading.
  Step 65 reaches the 2048-RHS integration-work budget and is not propagated. Its
  exact probe and 67-line journal survive; the full cold replay reproduces both
  result and journal hash. Release authority remains false.

## R10BO/R10BP local lift-field diagnosis and R10BQ transition, 2026-09-30

- R10BO reconstructs the 64 admitted R10BN deltas and evaluates the exact refused
  step 65 probe plus 56 fixed nearby probes. All 57 velocity solves certify, while
  the front-right knee exhibits strong local sensitivity with almost unchanged
  primary lift objective. Of28 secondary L1-face bounds, 27 certify;13 complete
  coordinate ranges are narrow under the declared allowance. The missing bound
  retains a HiGHS Unknown status. No global uniqueness or physical impossibility
  is inferred. Its 148 controls and complete cold replay pass.
- The retained front-right normal/active-sector block has a minimum singular
  value4.61019e-8 against maximum 1.58574 in normalized coordinates. This is a
  local conditioning diagnostic, not a complete causal account of integrator
  behavior or native dynamics.
- R10BP tests the 3.128052 nm difference between binary64 floor endpoints and
  binary32 configured cap centers. Aligning the front-right endpoints or all
  distal endpoints removes the mismatch without reducing the observed velocity
  sensitivity. All 171 probes and 152 controls pass, as does complete cold replay.
  The counterfactual geometry variants are not selected for production.
- The exact compiler and adapter sources are bound for the endpoint intent:
  `sdk/core/src/quadruped.rs` declares capsule segment length and cap center,
  while `sdk/adapters/godot/gdscript/recovery_native_world_v1.gd` creates the
  collision capsule and converts the configured site to Vector3. This source
  comparison does not inspect actual collision-resource rounding.
- R10BQ prospectively reselects one contact mode at the last admitted pose.
  Original sites 0,3,4,5 alone are height-eligible for force; the three elevated
  sites must remain inactive. Original height/floor/headroom references survive
  the new horizontal sticking anchors. At most 60 additional increments retain
  all previous integration and physical admission limits. It admits 16 additional
  increments, with 7.698002 mm more torso rise and 43.319823% required nonfoot support.
  The next secondary LP returns Unknown status; exact inputs, primary certificate,
  witness and probe survive. Its 146 controls and full cold replay pass.
- R10BR compares the original secondary progress requirement with 99%, 95%, 90%
  of certified maximum rise on 57 local problems and the exact saved R10BQ failure.
  All three reserve variants certify those inputs. The 99% variant reduces the
  larger-scale maximum normalized velocity change from 0.185753273 to 3.681194e-7.
  This changes a prospective development rate objective, not physical admission
  limits or old results. All 232 declared secondary solves, including the original
  failed variant, are retained. Its 152 controls and complete cold replay pass.
  A fresh finite lifting path must test the smallest sampled reserve before any
  controller or physical interpretation. No native world or acceptance population
  is consumed.

## R10BS reserved lift and R10BT-R10BV solver regression, 2026-09-30

- R10BS propagates a fresh original-entry model path at 99% of maximum
  instantaneous torso-rise rate. It admits 69 increments /276 sampled nodes,
  raises the torso 32.264894 mm, and retains 47.777790% required nonfoot support.
  Step 70 refuses the secondary LP despite a certified primary solution and a
  constructed secondary witness with 1.110223e-16 row residual. The 155 controls,
  full cold replay and 72-line journal replay pass. No native recovery follows.
- R10BT compares the existing four backend/presolve configurations on five exact
  retained LPs without changing their original objectives or bounds. They certify
  2/5,2/5,3/5,4/5 respectively; none certifies the entire bank. All 20 outcomes,
  163 controls and complete cold replay survive. The original R10BQ secondary
  near-maximum requirement is different from the 99%-reserve runtime objective.
- R10BU uses equality-null-space coordinates and reconstructs original duals;
  the complete unchanged original-matrix certificate remains required. Only 1/5
  cases certifies. Four solver infeasibility statuses are not independent
  infeasibility certificates. Its 170 controls and full cold replay pass.
- R10BV retains original row scale for projected coefficients at roundoff scale,
  avoiding amplification of cancellation-sized equality-redundant rows. No row
  is deleted or relaxed. It certifies 3/5; the auxiliary face query still refuses,
  while R10BQ solver success fails the 1e-6 stationarity threshold at 1.192093e-6.
  Its 173 controls and full cold replay pass. Neither formulation is selected
  for production. All control counts share inherited coverage.
- These are finite numerical studies using the previously bound SciPy backend
  and marginal conventions, not new external research claims or physical proof.
  The next declared comparison must distinguish the actual reserved-rate
  runtime LPs from the unchanged historical diagnostic queries. A fresh finite
  path and then an explicit placement/contact-acquisition/load-transfer sequence
  remain necessary. Zero native worlds and zero acceptance populations consumed.

## R10BW-R10CB runtime coverage and sequential rear placement, 2026-09-30

- R10BW certifies four complete runtime LP pairs using a fixed interior-point
  backend and 99% of each fresh primary optimum. R10BX's fresh path immediately
  exposes an entry secondary iteration-limit refusal absent from that bank.
  It admits no pose. Both complete results and cold replays survive.
- R10BY prospectively orders at most two backend calls: dual simplex, then
  interior point on refusal, both presolve disabled. Only an unchanged full
  original-matrix certificate authorizes a direction. All five runtime pairs,
  including entry, certify; every failed attempt is retained. R10BZ's fresh path
  recovers one LP refusal but reaches the unchanged integration-work budget,
  admitting the same 69 poses as R10BS. Its full journal/cold replay passes.
- R10CA's both-rear-unloaded mode search returns infeasible status without an
  independent infeasibility certificate. No additional pose is admitted.
  R10CB instead permits left-rear support and targets only the right-rear
  placement deficit relative to COM with the existing 20 mm margin. Analytic
  gradients include COM motion and are checked against finite differences.
- R10CB admits five increments / 20 sampled nodes. Right-rear deficit drops
  6.024812 mm, geometric hull gap drops 4.873046 mm, and nonfoot support in the
  selected mode ends at 38.569557%. The target and landing remain unproved.
  Step six reaches the 2048-RHS limit; its 2049th request is refused before
  evaluation. Maximum retained velocity-certificate residual is 7.354e-13.
  The 180 controls and full result/nine-line-journal replay pass.
- All six cold replays and complete bindings are retained. These are finite
  model/numerical results, not native recovery or release evidence. A strictly
  convex motion selector is a prospective integration hypothesis, not a proven
  explanation. Single-foot placement, explicit contact acquisition, transfer
  and raising remain necessary before native controller implementation and
  acceptance. Zero native worlds or held-out populations were consumed.

## R10CC-R10CG quadratic motion selection and fresh placement path, 2026-09-30

- The finite 59-pose diagnostic uses the original phase entry, admitted R10CB
  endpoint, refused integration probe and 56 nearby poses. Original L1 selector
  certificates pass throughout. The proposed half-squared normalized velocity
  secondary retains 99% of each freshly certified primary optimum.
- R10CC full-coordinate SLSQP admits 4/59; R10CD equality-coordinate SLSQP 39/59.
  Independent full-matrix KKT checks reject solver-success outputs when needed.
  SciPy's documented SLSQP multipliers omit ordinary bound multipliers, so the
  implementation includes finite bounds as explicit rows and audits their duals:
  https://docs.scipy.org/doc/scipy/reference/optimize.minimize-slsqp.html
- R10CE binds isolated Clarabel 0.11.1 and follows its quadratic cone and dual
  conventions: https://clarabel.org/stable/python/getting_started_py/ . The exact
  wheel is checked against retained version-specific PyPI metadata and installed
  without changing the global environment. Every one of 59 independent proofs
  passes but AlmostSolved remains ineligible under R10CE's strict declaration.
- R10CF prospectively admits Solved or AlmostSolved only with the unchanged full
  independent certificate. All 59 pass. Maximum normalized velocity change at
  perturbation scale 1e-6 falls from 0.434108165 to 7.2420394e-8. These are finite
  diagnostic samples, not a global regularity theorem. R10CE is not regraded.
- R10CG uses the qualified selector on a fresh path from the 69-increment lift
  endpoint. Same fixed modes, physical constraints, integrator and work budget.
  It admits 11 increments / 44 nodes, reducing right-rear deficit 27.253570 mm.
  Increment 12 retains a Solved output whose complementarity residual 2.313e-4
  fails the unchanged 1e-6 independent threshold. That increment is not advanced.
- All five original results and full cold replays pass their retention audits.
  R10CG has 202 inherited controls and exact 15-line journal replay. Controls
  overlap across studies. Zero native worlds; no controller or release claim.
  Diagnose the retained QP through a distinct successor before another path;
  placement, contact acquisition, support transfer and native recovery remain.

## R10CH-R10CN conic conditioning and retained integration barrier, 2026-09-30

- R10CG's saved failure has large dual multipliers on nearly coincident floor
  and contact constraints. R10CH's equality-coordinate diagnostic publication
  fails on nonfinite certificate values; original bytes and incomplete output
  remain bound. R10CI explicitly tags nonfinite diagnostics, forces refusal and
  completes all60 cases, certifying51. Its full cold replay passes.
- R10CJ declares at most two QP formulations, full coordinates then equality
  coordinates after refusal, with unchanged original certificates. All60 cases
  certify, but its fresh R10CK path still ends at11 admitted increments. Four
  refusals are recovered before both formulations fail a later runtime probe.
  The exact two failed results and complete journal/cold replay are retained.
- R10CL's known-answer preflight wrongly omits fixed-coordinate bounds from its
  expected redundant-row list. It refuses before regression exposure. R10CM
  corrects that control and runs the unchanged declared preprocessing: remove
  only roundoff-sized projected rows with nonnegative shifted RHS from the
  backend, restore zero duals, then audit every original row and full QP KKT.
  All61 saved problems certify, with three omitted backend rows in each.
- This uses the already bound Clarabel cone/dual conventions and SVD coordinate
  mapping. It is explicit numerical preprocessing, not relaxed physical limits.
  Maximum original stationarity residual across61 cases is1.863e-8 versus1e-6.
- R10CN's fresh path certifies all5430 evaluated RHS solves but reaches the2048
  per-increment budget on increment12. The2049th request is refused before
  evaluation. It admits11 increments/44 nodes, retaining101.554782 mm of
  right-rear placement deficit. Maximum retained velocity-certificate residual
  is3.725291e-8. Full cold result/15-line journal replay and220 controls pass.
- Five complete studies, one incomplete publication and one refused preflight
  remain distinct. No native world, held-out population, controller adoption or
  release claim. Next investigate local motion-field sensitivity around the
  retained budget probe; numerical certification has not proved bounded
  integration, landing, support transfer or native recovery.

## R10CO-R10CQ reserved objective and completed horizontal placement, 2026-09-30

- R10CO evaluates59 exposed poses under six predeclared geometry/progress
  combinations. All354 directions certify. Original geometry at95% requested
  primary progress reduces maximum normalized velocity change at1e-6-scale
  perturbations from1.946e-7 to1.095e-8. Counterfactual distal-cap alignment
  barely changes that larger-scale result and is not adopted as native geometry.
  The228 controls and full cold replay pass; no global smoothness claim follows.
- R10CP's fresh95% path retains23 logged increments, then aborts on zero primary
  optimum divided into an informational achieved-progress ratio. No complete
  result is published. The source/declaration and original25-line journal remain
  immutable with an explicit incomplete-execution closure.
- R10CQ reports null for that undefined ratio while retaining the exact QP and
  all physical/path admission checks. It reproduces the first23 logged increment
  records exactly, then completes24 increments/96 nodes and reaches zero right-
  rear horizontal placement deficit. The231 controls, full cold replay and
  27-line journal replay pass. The9420 evaluated velocities certify;1937 primary
  LP backend recoveries retain their complete failed/successful attempts.
- This is horizontal placement only. The right rear remains248.342572 mm above
  ground, nonfoot support39.174223%, and geometric hull gap24.151392 mm. The old
  all-contact non-descent rule must change explicitly in a distinct landing
  phase, with ground-contact evidence required before assigning new support.
  No native world, held-out population, controller adoption or release authority.

## R10CR-R10CT partial ground approach and knee-headroom diagnosis, 2026-09-30

- R10CR tests three unloaded-contact descent permissions at the R10CQ endpoint.
  All certify; releasing only the right-rear normal restriction permits
  4.242673 mm/interval at95% progress, equal to releasing all inactive contacts.
  Its236 controls and independent full numerical replay pass. The original
  path-only presenter fails after complete result write; that invocation remains
  failed and the post-exposure auditor explicitly does not regrade it.
- R10CS admits eight descent increments/32 samples, lowering the unloaded foot
  23.444875 mm while preserving horizontal placement. The final cap is224.897697
  mm above ground; knee angle1.079580931 rad approaches its1.08-rad bound.
  Its239 controls, full cold replay and12-line journal pass. Increment9 refuses
  an AlmostSolved QP after200 iterations: complementarity7.8518223e-6 and gap
  7.9322779e-6 exceed unchanged1e-6. The failed increment is not propagated.
- R10CT compares original bounds and a fixed right-rear knee at entry, final
  admitted pose and the exact unadmitted solver probe. All six primary LPs
  certify with independent fixed-mode load/material-work checks. Fixed-knee
  descent at the final admitted pose is0.695970 mm/interval, versus0.752292
  under original bounds. Its243 controls and cold replay pass. This disproves
  immediate knee-only tangent blockage at these poses; no finite landing route
  or replacement secondary selector is established.
- R10CS losslessly compresses full recovery diagnostics when needed, with raw
  canonical and compressed hashes and exact replay. Prior1937 recovery records
  measure13,670,654 raw versus2,986,523 gzip bytes. Current path needed zero
  recovery artifacts. No official/native capture change. Its predeclaration
  builtin-zlib discovery failure has a separate retained no-execution closure.
- These use the already bound analytic geometry, primary LP and conic certificate
  sources. No new native world, contact acquisition, force transfer, controller
  adoption, held-out population or release authority. Next address the exact
  secondary-QP certificate without relaxing physical limits, then qualify a
  fresh descent/contact path and native observation/actuation before acceptance.

## R10CU-R10CY numerical correction and extended partial descent, 2026-09-30

- R10CU solves a certified dual LP at the unchanged candidate primal. It retains
  the R10CS refusal:64/65 regression cases pass, failed QP gap remains7.911103e-6.
  The250 controls and full cold replay pass. A certified dual subproblem alone
  does not certify the original QP.
- R10CV proposes one minimum-norm active-face candidate from dual support,
  then requires every original row and complete KKT/duality certificate at1e-6.
  All65 cases pass; the saved failure gap becomes1.776357e-14. Its256 controls
  and cold replay pass. The fresh R10CW path still admits eight increments,
  exhausting the per-increment integration budget after321 retained corrections.
  Its258 controls, full result,12-line journal and compressed artifacts replay.
- R10CX applies the correction consistently, qualifying65/65 regression cases
  and57/57 local poses. Maximum normalized velocity variation at1e-8 perturbations
  falls from3.493190e-4 to1.357089e-6; at1e-6 it falls from4.091740e-4 to1.357097e-4.
  The259 controls and full replay pass; this establishes finite local evidence,
  not global smoothness or permission to propagate the unadmitted budget probe.
- R10CY admits17 increments/68 nodes under unchanged physical/integration limits,
  lowering the unloaded foot29.090807 mm to219.251765 mm. Its261 controls, full
  cold result,21-line journal and3511 complete solver records replay. Increment18
  refuses a mandatory correction even though the original answer passes with
  gap1.299849e-12; the proposed correction has gap2.992989e-5 and is not propagated.
- R10CY's full records occupy183,023,669 canonical bytes /32,197,076 gzip bytes;
  original inputs and attempts are preserved losslessly. This uses existing
  bound linear algebra/LP/QP conventions without new library or native capture
  changes. No contact, native controller, physical world, held-out population
  or release claim. Next qualify accurate-seed preservation with finite field
  checks before another path; native observation/actuation remains unproved.

## R10DD native finite-reference composition and interfaces, 2026-09-30

- Distinct V29 composition retains original selection, supervision and energy,
  preserves setup command targets/caps, binds the step-513 physical entry and
  checks the previous issued command against each next native observation.
  All 236 reference commands and the final post-step observation are covered;
  finite exhaustion is explicitly not recovery completion.
- All 524 release core tests pass, with seven composition tests. C/Python tests
  cover 10 new successes, 18 refusals, 14 historical compatibility calls and two
  old-runtime unavailable API refusals. Actual Godot calls add five successes
  and five crossed-schema refusals. A distinct pinned DLL is retained.
- The original optional-command-hash compile failure and host argument failure
  remain archived. The first interface publication prematurely bound its parent
  stdout and remains invalid. A distinct successor repeats the same native calls
  with completed child-artifact bindings; the post-exit closure passes and the
  native-call bytes/Godot results reproduce. No old publication is regraded.
- This qualifies interfaces only. Original numeric inputs become explicitly
  synthetic source-rebound test copies, never revised physical evidence. The
  production worker/reader and applicable smoke gate are still required before
  any fresh native tracking world; no recovery or release claim is obtained.

## R10DC compiled finite diagnostic reference scheduler, 2026-09-30

- The portable core preserves all 119 R10DB native endpoint vectors, with one
  arithmetic midpoint per interval. Tick zero is entry; 236 command ticks follow.
  No implicit hold/repeat or recovery-completion claim is supplied.
- All 517 release core tests pass, including seven new tests. All 237 compiled
  reference points equal independent reconstruction exactly. Maximum reference
  rate is 2.000050843 rad/s; no rate or hard-limit violation occurs.
- Finite entry-joint admission, malformed identity/data, skipped/repeated ticks,
  exact endpoints, midpoint bounds and exhaustion are checked. The component
  retains full logs, a compiled test image and a 161-file exact source snapshot.
- This is a finite reference kernel, not a native controller or general feedback
  policy. A distinct native composition still needs complete fresh-entry, source,
  clock, ownership, energy and supervisor admission and the applicable smoke gate.
  Slower timing/interpolation does not inherit model contact or force admission.
  No physical world, tracking, recovery or release claim is obtained.

## R10DB native joint-reference semantics, 2026-09-30

- The actual production Godot signed full-quaternion helper was called on the
  119 admitted measured-transform endpoint poses: entry plus 69 lift, 24 placement
  and 25 descent increments. Every saved snapshot matches; refused increments
  remain excluded. This is a zero-world semantic audit, not native tracking.
- The entry agrees exactly with retained native joint readback. Maximum
  native/additive difference is 0.0004395382 rad, at the front-right knee. All
  endpoints stay within hard limits, with minimum clearance 0.02000258 rad.
- Fifteen one-tick reference changes exceed the unchanged 4 rad/s limit; maximum
  4.000101686 rad/s. These negatives remain intact. A distinct slower timing
  schedule requires its own validation before a diagnostic actuator test.
- Eleven Python and eight native manufactured controls pass; fresh original and
  cold native processes reproduce complete result and exact transport bytes.
  Retained logs/source/runtime/lock bindings are in the support-matrix closure,
  audited by `sdk/conformance/r10db_native_reference_closure.py`. No new physical
  world, controller adoption, recovery or release evidence is obtained.

## R10CZ-R10DA strict seed preservation and extended descent, 2026-09-30

- R10CZ retains every passing consistent correction. Only after correction
  refusal does it preserve an unchanged original seed with all six certificate
  errors <=1e-9 and a passing original full certificate. All179 cases certify;
  57 use preservation. Its270 controls and cold replay pass. The old57-pose
  field is exactly unchanged; the new57-pose field changes at most1.239955e-6
  and1.236213e-4 under1e-8 and1e-6 perturbations. No global continuity claim.
- R10DA reproduces all17 earlier records, including compressed/canonical hashes,
  changing only the artifact storage path. It then admits25 increments/100 nodes,
  lowering the unloaded foot33.953343 mm to214.389229 mm. Its274 controls, full
  cold replay,29-line journal and4661 complete solver records pass.
- Increment26 stops on the prospectively declared extra quality threshold:
  original complementarity1.007543461e-9 exceeds1e-9 although its full original
  certificate passes with objective gap7.833734e-13. The attempted face correction
  has gap2.143518e-4 and a near-dependent singular value2.632413e-9. Neither the
  failed increment nor its threshold is altered after exposure.
- All records remain lossless:244,166,474 canonical bytes /42,925,903 gzip bytes
  in26 artifacts, plus the inline terminal refusal. No new library conventions,
  native capture changes, physics worlds, held-out populations or release claims.
- Next scope an independently gated native joint-tracking diagnostic for admitted
  lift/placement references; confirm entry/joint semantics and available production
  observations before launch. Also diagnose the numerical constraint set rather
  than chasing the extra threshold. Static model progress is not native motor,
  contact-acquisition, complete recovery or SDK acceptance evidence.

## R10DE finite native reference source and packet session, 2026-09-30

The [component closure](../../sdk/recovery/r10de_reference_session_component_v1.json)
qualifies the V29 request/source bridge and command-or-stop packet session with
1,217 checks in the real Godot extension. All 238 saved packets round-trip and
replay; all 236 reference commands and the final post-step observation are
covered. Native entry rejection, early supervisor transition and finite
exhaustion retain distinct outcomes. Neither exhaustion nor a validated source
binding is evidence of physical recovery.

The original numeric inputs are used only as explicitly synthetic copies with
new owner/command/memory/source binding. Original physical reports and the
retained test parse failure remain immutable. Physical worker integration,
complete-report physical-source links and the launch safety gate remain open;
no physical population or acceptance claim was added. SDK1 remains 14/20.

## R10DF finite-reference worker and motor component, 2026-09-30

The [closure](../../sdk/recovery/r10df_worker_component_v1.json) qualifies the
V29 production worker partial-step and scheduler hooks with 745 checks,
238 supplied observations, 237 actual motor applications and 1,896 configuration
writes to uninserted hinges. R10DE's 1,217 session checks and 849 V28 compatibility
checks pass on the changed dependency key. Original RaiseBody memory and the
terminal observation survive diagnostic exhaustion; walking remains unopened.

Three shared ownership/stance/source-dispatch files changed prospectively.
The earlier R10DE source archive remains the historical qualification; it is not
regraded or claimed reusable under the new key. Both failed R10DF test attempts
remain retained. Synthetic packet injection does not prove native source/energy
collection or physical setup. Complete-report links, entry-refusal disposition,
launcher binding and full applicable smoke safety remain open. No world,
held-out population or recovery acceptance was added; SDK1 remains 14/20.
