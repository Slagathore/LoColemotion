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

## 2026-10-22 upstream discussion follow-through

[Rapier discussion 1032](https://github.com/dimforge/rapier/discussions/1032)
contains a community reply supporting the final-substep interpretation. For the
pinned profile, the per-substep cap is B/N. A final readback cannot reconstruct
an outer-step sum under varying loads. The existing R24D46 application observer
already supplies a stronger exact measurement for its qualified non-SIMD scope;
use that surface rather than scaling a last readback. Changing N changes the
experiment. This reply is advice, not upstream certification of this SDK.
Source cross-check: [Rapier 0.34 JointMotor](https://github.com/dimforge/rapier/blob/v0.34.0/src/dynamics/joint/generic_joint.rs),
and the [existing observer patch](../../sdk/adapters/rapier/engine_patches/README.md).

[MuJoCo discussion 3652](https://github.com/google-deepmind/mujoco/discussions/3652)
recommends named actuatorfrc/jointactuatorfrc sensors and distinct sampling stages.
The owner's follow-up identifies the crucial clamp exception: the implicitfast
velocity derivative is omitted at the force limit. Post-state force-time predicts
the unsaturated unloaded scalar result; the clamped step instead uses the
completed-step force. Contacts and other forces invalidate motor-only attribution
from a raw momentum change. Named sensors prevent mapping mistakes but do not
change sampling semantics or measure effective impulse automatically.
Source cross-check: [MuJoCo 3.11 derivative](https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_derivative.c#L2020)
and [integration](https://github.com/google-deepmind/mujoco/blob/3.11.0/src/engine/engine_forward.c).

The new [measurement helpers](../../sdk/discovery/actuation_measurement.py)
encode the scalar clamp distinction, explicit sensor-object binding and refusal
to invent Rapier outer totals. Their archived-trace test checks all 1,800 rows
of the published VH4 cell; it does not rescore VH4. Contact-rich accounting needs
its own full generalized-force/integrator treatment, including bias, passive,
applied and constraint channels. No scalar residual is promoted to that claim.

The distinct [GPU probe closure](../../sdk/discovery/gpu_measurement_probe_closure_v1.json)
subsequently retained a concrete clamp-boundary counterexample: two of eight
scalar cells use different CPU/GPU derivative branches at the same step after
command reversal. The observed equations remain locally consistent while the
trajectories differ materially. Preserve both branch identity and the original
result when designing training labels and fresh native transfer challenges.

## 2026-10-23 adaptation proposal review

Reviewed the complete [research proposal at f2a6d088](https://github.com/Slagathore/LoColemotion/blob/f2a6d088b68ba16577f31ad834b3ddfe5f09576a/docs/SDK2_ADAPTATION_RESEARCH_BOOTSTRAP.md)
against the current provider implementation and the valid portable search v2.
This is a research/sequencing decision, not a behavioral adoption or campaign
result. The [existing roadmap](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#research-informed-acceleration---2026-10-23)
carries the next work. No external code or model was imported.

Adopt the ordering of host batching, diverse candidate search and deterministic
retrieval before neural residual learning. Retain memory-off and shuffled-key
controls, and match trigger/influence opportunities so another generic correction
cannot masquerade as a retrieval benefit. The small, fixed-topology body family
makes a bounded provider a useful first target without waiting for general
morphology support or formal engine equivalence. Tier 3 can then test bounded,
reversible episode memory over that frozen retrieval provider; residual neural
learning and a history encoder are optional improvements, not prerequisites.

Corrections and implementation boundaries:

1. **Update the source baseline.** The proposal read `5062134`; portable search
   v2 at `dd009d99` subsequently completed the actual controller/provider route
   and fresh CPU transfer audit. It already holds each command for five internal
   steps. Optimize measured host control, readback and capture costs rather than
   restarting commissioning or claiming that control still runs every substep.
2. **Separate the archive from the experiment log.** The default
   [MAP-Elites algorithm, v1](https://arxiv.org/html/1504.04909v1#S3)
   retains the best occupant per feature cell and can replace earlier occupants.
   It does not preserve every evaluation by construction. Keep an append-only
   trial ledger containing failures and replaced elites alongside the archive.
3. **Qualify the v1 compatibility claim.** The current provider already accepts
   refusal/uncertainty and diagnostics. A monitor using those responses can
   preserve v1. The proposal's new fallback enum and receipt authority field are
   schema changes: current structs deny unknown fields. A profile-difference
   bridge also needs an implemented profile execution path and bounded memory;
   it is not supplied merely by declaring a parameterized profile struct.
4. **Treat recoverability as an empirical prediction.** Fit on declared data,
   with unsupported-state refusal and hysteresis, then evaluate fresh. Command
   bounds and bit-exact fallback preserve interface behavior; they do not prove
   future recoverability or universal non-inferiority. Changing influence after
   a slew clamp can change temporal constraints and needs explicit semantics.
5. **Distinguish two statistical questions.**
   [TOST](https://pmc.ncbi.nlm.nih.gov/articles/PMC5502906/) tests both sides of
   an equivalence interval. Non-inferiority tests one unacceptable direction.
   For a fall-rate difference defined as provider minus baseline, the declared
   upper confidence bound must lie below the allowed increase. Freeze the
   estimand, practical margin, error level, cohort/pairing, power and any interim
   looks before evaluation. Dependent simulation frames are not independent
   episodes; a nonsignificant difference does not establish either claim.
6. **Do not promote marginal calibration to conditional safety.**
   [Conformal prediction, v6](https://arxiv.org/html/2107.07511v6)
   supplies marginal coverage under its assumptions, not an automatic bound on
   fall risk among accepted proposals, out-of-domain states or a changing closed
   loop. Split by episode/task groups, state the prediction target and check
   calibration separately. A selective-risk claim needs an appropriate method
   and validation; [conformal risk control, v4](https://arxiv.org/abs/2208.02814v4)
   is an additional reference, not a drop-in proof for arbitrary thresholds.
7. **Separate GPU replay, repeatability and native transfer.** The
   [current MuJoCo Warp documentation](https://mujoco.readthedocs.io/en/stable/mjwarp/index.html#frequently-asked-questions)
   warns that GPU runs can differ numerically and describes a CPU device mode.
   That does not forbid reproducible methods or statistical replication. Keep
   original observed traces, seeds, configuration and outcomes; measure repeat
   variability under a pinned runtime. A fresh native CPU MuJoCo challenge is a
   different backend experiment, not exact regeneration of a GPU trajectory.
   The project remains on its pinned 3.11.0 runtime; no upgrade is implied.
8. **Reduce capture only after qualifying its replacement checks.** Full capture
   found the first search's 3,952 incorrect GPU contact observations. A faster
   lane must retain on-device or boundary checks, complete candidate accounting
   and prospectively selected full-trace canaries. Shortlist and acceptance work
   rerun fresh at their stronger evidence level. Invalid trials remain invalid.

Primary-source spot checks support narrower prior-art statements:

- [Wu et al., PLOS ONE, 2026](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0356505)
  describes a CPG with bounded residuals, gait-parameter proposals and position/
  command-rate projection on an eight-actuator robot. This is relevant prior
  art, but it is not the same velocity-delta ABI or engine-transfer evidence.
- [Wang et al., RTPC, v1](https://arxiv.org/abs/2610.24573v1) reports a retrieval
  correction result that did not replicate and was not distinguishable from
  random corrections in the tested family. Its task is VLA manipulation, not
  quadruped locomotion. Use the control lesson without treating it as a result
  about this provider or about retrieval generally.

These checks used the linked primary HTML/abstract versions and repository
source, not newly archived PDF bytes. They do not certify all sources or license
entries in the proposal. Imported code remains subject to the repository's
normal provenance/license review. Possible novelty of an integration is a
research hypothesis, not established by this literature selection.

## 2026-10-23 context-indexed episode feedback

The retained native comparison supports frozen retrieval in its finite domain
but gives episode memory a 0/3 benefit result. Its global per-action offsets
reuse feedback across contexts: the diagnostic records 34/35 changed choices
without matching phase/contact/nearby-state feedback for the decisive offsets.
This observation motivates a distinct component; it does not prove its benefit.

[Pritzel et al., Neural Episodic Control, ICML 2017](https://proceedings.mlr.press/v70/pritzel17a/pritzel17a.pdf),
sections 3.1-3.3, indexes per-action memories by state representations and uses
normalized kernel weights over nearby keys. The key represents the action-time
state; insertion waits for the outcome estimate. Adopt context-indexed lookup
and delayed credit, using the existing canonical cue and frozen casebook. The
new component is not an NEC replication: it has no learned visual embedding,
Q-value bootstrapping, gradient updates or Atari performance claim.

[Blundell et al., Model-Free Episodic Control, v1](https://arxiv.org/html/1606.04460v1#S2)
explains that retaining only the highest observed return can produce risk-seeking
behavior in stochastic settings. This component retains negative residuals and
uses weighted averaging rather than best-return selection. Its 64-record bound,
oldest-first eviction and explicit checkpoint/rollback/reset are project choices,
not results established by either paper. Neither source establishes locomotion
safety or transfer across this project's engines.

These are primary-paper idea adoptions. No external implementation, model or
third-party code was imported. The native successor must earn its own result
with memory-off, shuffled-proposal and shuffled-feedback controls, unchanged
command bounds and measured influence exposure. Empirical withdrawal monitoring,
unopened evaluation and qualification remain separate work.

The [native contextual comparison](../../sdk/discovery/gpu_contextual_influence_closure_v1.json)
subsequently verifies 176 feedback updates and 84 selections using matching
context, but memory benefit remains 0/3. Correct implementation of a borrowed
memory mechanism is therefore insufficient evidence of useful adaptation here.
The result motivates investigation of action credit, prediction error and a
declared task that actually requires adaptation; it does not refute either
paper's distinct algorithm or domain. Both the global and contextual negative
results remain retained, and evaluation groups remain unopened.

## 2026-10-23 action credit and physical context

The [retained action-credit diagnostic](../../sdk/discovery/contextual_action_credit_diagnostic.py)
finds one-sided feedback in 20/22 ordinary-memory choice changes. Observed
prediction error is often larger than the leading action-score gap. This
motivates learning physical context and reporting uncertainty; it does not
identify which unexecuted action would have performed better.

[Kumar et al., RMA, v1](https://arxiv.org/html/2107.04034v1)
estimates a latent physical context from recent state/action history. Section
III-B also explains why expert trajectories alone are inadequate and trains
the estimator on trajectories affected by its own prediction errors. Borrow
the separation between persistent physical context and fast state, and the
need to cover those deviations. A 64-entry ABI allowance is not an implemented
estimator: the current host supplied empty history. The new causal-history
host closes that input gap but has no learned encoder or RMA performance claim.

[Cully et al., 2014 preprint v2](https://arxiv.org/html/1407.3501v2)
models performance residuals over a repertoire with a Gaussian process and
chooses experiments using prediction uncertainty. It is a useful alternative
to treating unobserved action offsets as equally known. Its repeated physical
trials and behavior-space assumptions differ from this continuous controller;
an eight-second windowed comparison is not a replication of that method.

For the next implementation, history-conditioned physical context offers a
diagnosable target and an oracle-condition control, at the cost of new varied
training data and estimator validation. Repertoire-based Bayesian search offers
explicit exploration and uncertainty, but consumes additional trials and needs
a declared exploration budget. Further offset tuning is inexpensive but leaves
the action-identification problem unresolved. Start with a bounded motor-
effectiveness family, establish that an oracle has useful control authority,
then train and test context inference with history-off and shuffled-history
controls. Unsupported dynamics and withdrawal monitoring remain separate.

These are primary-paper idea adoptions. No external code or model is imported.
No new result establishes recoverability, safety probability, cross-engine
transfer, statistical superiority or release authority.

## 2026-10-23 motor-effectiveness oracle pilot

The [MuJoCo velocity-actuator reference](https://mujoco.readthedocs.io/en/stable/XMLreference.html#actuator-velocity)
defines a fixed gain `kv` and an affine velocity bias `-kv`. The
[force-limit documentation](https://mujoco.readthedocs.io/en/stable/modeling.html#force-limits)
distinguishes output-force clamping from input-control clamping. These semantics
motivate scaling both gain and symmetric force caps while retaining velocity
targets and the existing transmission. The pinned 3.11.0 native and Warp arrays
are checked against the declared profile; current documentation is not a runtime
upgrade or a substitute for those checks.

The [new task](../../sdk/discovery/gpu_motor_effectiveness_v1.json) first asks
whether a condition-known selector over nine constant bounded profiles is useful
on fresh confirmation starts. Discovery alone chooses per-condition and shared
profiles. This makes the control-authority question observable before spending
trials fitting the RMA-inspired history estimator discussed above. Scaling gains
and caps together is a declared model of motor effectiveness, not a calibrated
model of damaged hardware. Five settings and two start families per phase do not
establish continuous coverage, broad robustness or engine transfer.

No external implementation or model was copied. This pilot fits no history
encoder, does not reproduce RMA or Intelligent Trial and Error, and cannot bound
all residual policies with its nine-profile oracle. Its finite comparison has
no population-inference or non-inferiority authority. Only complete independently
verified discovery episodes may be reused for later development fitting;
confirmation is excluded and unopened evaluation groups remain sealed.

The [completed pilot](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-motor-pilot---2026-10-23)
is a valid negative: 75/90 discovery episodes were eligible, but all three roles
failed both left-75 confirmation starts, leaving 24/30 eligible. The fixed
conditioning-value criterion is false. Profile 6 survived both discovery starts
and failed both confirmation starts; this is a concrete reason to diagnose and
strengthen control before fitting an RMA-inspired estimator. Discovery and
confirmation also differ in batch width, so the result does not isolate the
cause as initial-state sensitivity. It does not prove that all nine profiles, or
all bounded residual controllers, lack useful control authority.

The measured discovery readback cost was 357.754 seconds, versus 35.742 seconds
for integration and device history. The official
[MuJoCo Warp tutorial](https://github.com/google-deepmind/mujoco_warp/blob/main/notebooks/tutorial.ipynb)
uses `get_data_into` for host readback. Inspection of the pinned 3.11.0
`mujoco_warp/_src/io.py` (SHA-256
`6fe550047ed4b82c307741f84a8a4800587469c52e5ce292a3073824f3451fa6`)
shows repeated `.numpy()` transfers in each per-world call. Caching immutable
host arrays for one prepared command boundary is a proposed local optimization,
not an existing qualified batching API. It needs complete field, contact,
clock, aliasing and controller-output conformance plus fresh native measurement.
No library code was copied and no capture reduction was made in the pilot.

The matched diagnostic separates batch width and neighboring controller
composition from initial lateral velocity while preserving the same focus
slot. The official [Warp collision implementation](https://github.com/google-deepmind/mujoco_warp/blob/main/mujoco_warp/_src/collision_core.py)
uses a shared atomic contact counter and stores each contact's world identity.
This motivates inspecting attributed native traces; it does not establish
cross-world physical coupling. The installed solver's per-world convergence
flags also do not promise bitwise trajectory equality across batch sizes.
The new finite diagnostic retains numerical differences and every failed
episode without changing tolerances or the original pilot result. No upstream
source or pretrained model was copied and no runtime was upgraded.

The [completed matched diagnostic](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-matched-motor-diagnostic---2026-10-23)
retains 12/48 eligible episodes. Profile 6 passes every tested 0.002 m/s instance
and fails every 0.0035 m/s instance, across batch widths, neighbor compositions
and fresh repeats. Eligibility does not flip in any same-start comparison,
although native trajectories and commands differ. This supports developing a
phase/state-dependent controller family before fitting a history estimator; it
does not prove numerical determinism or identify a particular GPU kernel as
the cause. All nine constant profiles fail at the second start in one fresh
mixed batch. Their time-varying combinations remain an untested possibility.

The subsequent CPU challenge follows MuJoCo's documented
[split simulation loop](https://mujoco.readthedocs.io/en/stable/programming/simulation.html):
prepare position/velocity observations with `mj_step1`, set motor targets,
then advance dynamics with `mj_step2`. The documented split supports the pinned
implicitfast integrator. Named actuator and joint force sensors are retained
immediately after each completed step, before the next preparation recomputes
the state-dependent quantities. The native model, sensor identities and full
stream joins remain executable checks; current documentation does not upgrade
the pinned runtime or establish CPU/GPU equivalence. No external code was copied.

The [completed CPU challenge](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-native-cpu-motor-challenge---2026-10-23)
retains four valid negative episodes: baseline and profile 6 fail at both exposed
starts. The earlier GPU positive did not transfer under this finite native CPU
challenge, despite equalized initial values. That observation does not identify
the backend mechanism or justify changing the earlier result. It strengthens
the reason to establish a useful phase/state-dependent control family before
fitting an RMA-inspired history estimator: inference cannot supply control
authority that the tested action family has not demonstrated. The diagnostic
has no fitting or selection authority; fresh development discovery is required.

## 2026-10-23 support-conditioned body feedback

[Iscen et al., PMTG, CoRL 2018](https://proceedings.mlr.press/v87/iscen18a.html)
demonstrates that compact observation-conditioned policies can complement a
trajectory generator. Its learned controller also modulates generator parameters.
The [stance-feedback component](../../sdk/adaptation_provider/stance_feedback_v1.py)
uses that architectural motivation while keeping this project's generator fixed:
current attitude/rate feedback and optional speed error request small planted-foot
motions through the existing velocity-residual interface. No PMTG implementation,
weights or performance claim is imported.

The inverse-kinematics calculation uses the damped least-squares expression
`J^T (J J^T + lambda^2 I)^-1 v`, described in
[Buss's author-hosted IK survey](https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/iksurvey.pdf).
This local implementation specializes the calculation to the exact planar
two-joint S169 leg and verifies its forward kinematics and Jacobians against
retained native body poses and axes. Fixed damping makes the solve finite at a
straight leg; it does not create a missing degree of freedom or enforce actuator
limits. The existing resolver separately enforces correction, slew and speed
bounds. No external source code or runtime dependency was copied. The family is
untrained, and fresh declared physics must establish whether the feedback helps.

The subsequent [closed native discovery](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-cpu-stance-discovery---2026-10-23)
retained **0/24 eligible episodes** and an empty shortlist. Complete independent
replay validates execution, not this control design's usefulness. A separately
labeled post-hoc diagnostic finds correction clipping in 1,597/2,551 pre-failure
feedback decisions and near-straight posture in 4,229/5,105 supported-knee
observations under its explicit trigonometric rule. These local counts support
separating correction authority and posture bias in a successor; they do not
prove either is causal or import a result from PMTG or the IK survey. No policy
was trained and no Tier 2/Tier 3 benefit was established by this family.

## 2026-10-23 posture preference and explicit correction authority

The [posture successor](../../sdk/adaptation_provider/posture_feedback_v1.py)
uses the damped least-squares objective described in
[Buss's survey, section 5](https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/iksurvey.pdf)
as its starting point. The local extension centres its regularizer on a supported
joint-posture velocity preference. Its normal equation becomes
`(J^T J + lambda^2 I) delta = J^T v + lambda^2 u`; this extension and the chosen
reference/gains are project design decisions, not a locomotion result supplied
by the survey. Independent tests check that equation and the objective minimum.
Damping means `(I - J# J)` is not an exact nullspace map, and physical execution
must determine attained posture and usefulness.

The [declared factorial](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#posture-and-envelope-factorial-prepared---2026-10-23)
separates correction magnitude, slew and posture preference while preserving
native force limits and final speed limits. This follows the retained clipping
and posture observations; it does not turn them into causal proof. The model is
untrained, all 123 zero-world controls pass, and native benefit remains open at
this preparation checkpoint. No external source code or dependency was imported.

The subsequent [complete native factorial](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-posture-and-envelope-factorial---2026-10-23)
retains **1/18 eligible and 17/18 negative** episodes. The all-high corner walked
0.3804 m forward through four seconds at one start and failed the other, leaving
no complete eligible pair. All 24 predeclared contrasts and the original
failures remain in the closure. This is one finite local walking observation;
it does not import a locomotion guarantee from the inverse-kinematics source or
establish useful adaptation. Start sensitivity remains the next control question.

## 2026-10-23 body-attitude and rate factorial

The [body-gain successor](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#body-gain-factorial-prepared---2026-10-23)
reuses the already reviewed damped inverse and the project's existing
body-attitude/rate feedback. It adds no external algorithm, code or dependency.
The two gain levels are local prospective design choices within the original
declared gain domain, motivated by the retained one-start walking result and
failure at the other start. Eight analytic/ABI controls and ten route controls
join the inherited gate for 141 passing zero-world controls. The native test
must establish usefulness; source compatibility and literature do not supply it.

The [completed native comparison](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-body-gain-factorial---2026-10-23)
retains four eligible and six negative episodes. Every feedback corner passes
only the 0.005 m/s start, so the tested attitude/rate gains do not resolve the
start split. All eight planned contrasts remain intact. A separately labeled
post-hoc common prefix describes different front-right support return, without
causal or selection authority. The next design question is contact/kinematic
support transfer; a further gain sweep is not promoted from single-start scores.

## 2026-10-23 fixed-torso ground-reach diagnosis

The [retained native diagnosis](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#fixed-pose-ground-reach-diagnosis---2026-10-23)
adds an elementary geometric bound derived from the exact local two-link
morphology. Each rotated planar segment has vertical contribution at least
`-L*hypot(R_yx,R_yy)`; the straight-leg witness attains the sum within the
compiled joint limits. Independent numerical grid and native endpoint checks
validate this calculation. No external algorithm, source code or dependency
was imported. This is a local post-hoc observation, not a literature result.

Both outcome groups initially include unreachable front-right poses, while
only the successful group regains support within the chosen prefix. A bounded
body-height/vertical-rate successor is the next design hypothesis. Geometry
does not establish achievable motion or controller benefit; no measured foot
forces are available in these traces. Prospective fresh-world tests remain
necessary, with original negative outcomes and the empty shortlist preserved.

## 2026-10-23 bounded stance-height successor

The [height successor](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#body-height-successor-prepared---2026-10-23)
reuses the previously reviewed damped inverse from
[Buss's survey](https://mathweb.ucsd.edu/~sbuss/ResearchWeb/ikmethods/iksurvey.pdf).
It adds a local bounded height/vertical-rate request and a geometric height cap
from the retained two-link reach diagnosis. The chosen height, margin, gains
and bounds are project hypotheses. The survey does not supply these settings
or a locomotion guarantee; planar inverse kinematics does not guarantee the
requested torso translation under contact and force limits. No external code
or dependency was imported. Independent normal-equation and real-ABI controls
pass; fresh native physics must establish usefulness.

The subsequent [closed native comparison](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-body-height-discovery---2026-10-23)
retains three eligible and three negative episodes. The height role passes
both starts, while the unchanged reference passes one and baseline neither.
At the already successful start, the height role has worse tracking quality
by 0.0275593 m/s. This local finite result selects a candidate for confirmation;
it establishes no general robustness, learned adaptation or literature-derived
performance guarantee. Fresh longer-horizon and healthy-body comparisons are
required before using the candidate in another adaptation comparison.

The [fixed-candidate follow-up](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#body-height-duration-and-nominal-confirmation-prepared---2026-10-23)
extends duration to twelve seconds and adds the nominal actuator profile, with
fresh baseline and reference worlds. It changes no control equation or bound.
Full-horizon eligibility and censored quality differences remain distinct; an
exact finite comparison is not a statistical non-inferiority result. The new
controls pass, but physical confirmation remains unopened.

The [completed duration/nominal comparison](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-body-height-duration-and-nominal-confirmation---2026-10-23)
retains nine eligible and three negative trials. The fixed height role passes
all four twelve-second trials, but its nominal tracking score is below baseline
at both starts; the declared nominal quality guard is false. This motivates a
new discovery question about causal-history/context-dependent selection. It
supplies no training data, replacement selection, learned benefit or statistical
non-inferiority result. Future fitting must use separately authorized discovery;
all three failures and the healthy-body costs remain part of the record.

## 2026-10-23 causal-prefix repertoire preparation

The [declared training successor](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#causal-prefix-repertoire-discovery-prepared---2026-10-23)
uses the earlier reviewed idea of inferring dynamics from recent states and
issued actions. It introduces a local 16-value joint-response feature vector,
not an implementation or reproduction of a published adaptation model. The
64-command baseline prefix is a prospective design choice using the existing
history capacity. It must leave enough physical opportunity for the fixed
controller to work; immediate-feedback confirmation cannot establish that.
No external source code or dependency was imported.

Eight real-ABI host controls and ten route controls pass; the complete gate
contains 192 passing controls. Training, calibration and evaluation starts are
declared before collection. The reader joins repeated fresh prefixes into one
training group and preserves every fixed-role outcome. Only complete verified
training data may support fitting. The earlier confirmation is excluded, and
no native result, learned benefit or broad generalization follows yet.

## 2026-10-23 completed causal-prefix repertoire and history coverage

The [closed training repertoire](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-causal-prefix-repertoire---2026-10-23)
retains twelve eligible nominal trials and twelve failed degraded-body trials.
All eight shared prefixes are verified training groups, but no degraded
candidate survives the unchanged four-start selection rule. Nominal baseline
ranks first. The sixty-four-command baseline observation design therefore has
no useful degraded action mapping in this finite training population. The
previous confirmation used different starts and immediate height feedback;
this comparison does not isolate an activation-delay effect.

Re-read [Kumar et al., RMA, sections III-B and III-C](https://arxiv.org/html/2107.04034v1)
on 2026-10-23. Its estimator uses recent states and actions; training includes
trajectories generated using imperfect estimated context, rather than only
expert behavior. A controller that changes its own input distribution needs
that training coverage. Its history window does not prescribe an initial
period of baseline-only control. Our common baseline prefix and one-time fixed
choice are local experimental restrictions, not a reproduction of the paper.

The result motivates earlier causal observation and/or stronger initial
control under a new declaration. Authorized training histories can test
context feasibility, while fresh native worlds must establish whether the
chosen control can help at the declared activation time. Do not reinterpret
this failed delayed repertoire as a positive selector, fit from the earlier
confirmation, or expose reserved calibration/evaluation to tuning. No external
code or dependency was imported; no published performance claim transfers here.

## 2026-10-23 early causal context feasibility

The [16-command diagnostic](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-early-context-feasibility---2026-10-23)
implements a small local label estimator over the already authorized training
prefixes. In four blocked folds it classifies 8/8 condition/start groups; the
constant-nominal and synthetic association-reversal controls score 4/8 and 0/8.
Each fold holds both conditions at one initial velocity out together, and the
three repeated role prefixes count once. The complete source population retains
all twelve negative trials. Seven component and three final closure controls
pass, with a deterministic regeneration from the original native records.

This is an observability result for the two exposed profiles at the specified
training starts, not a reproduction of RMA or a physical adaptation result.
The fixed 16-command window was chosen before this analysis; no feature/window
search, confidence calibration or reserved evaluation was performed. The fitted
centroids have no action mapping or control authority. A matched native timing
comparison must establish usable feedback before the inferred context can be
credited with useful control. Continuously updated adaptation still needs
coverage of the histories its own choices produce, as discussed above.

## 2026-10-23 matched activation preparation

The [matched activation declaration](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#matched-height-activation-prepared---2026-10-23)
turns early context observability into a separate control question. Fresh
baseline, immediate-height and sixteen-command-delayed-height worlds use the
same four exposed degraded-body starts. It preserves the earlier local height
controller and all eligibility limits, while isolating the declared onset
between the height roles. The 64-command negative changed both onset and
starts; this new comparison is needed before attributing a timing effect.

All 217 zero-world controls pass; native execution remains unopened at this
checkpoint. No published research performance transfers to this local controller,
and an 8/8 internal condition classifier does not establish physical benefit.
The campaign imports no external code or new dependency. Reserved groups and
prior confirmation remain excluded from development fitting.

## 2026-10-23 matched activation outcome

The [completed comparison](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-matched-height-activation---2026-10-23)
retains one eligible and eleven negative native CPU episodes after all 217
controls. Immediate height passes only the 0.001 m/s start; baseline and delayed
height pass none. All seven closure controls pass. The four-start shortlist is
empty, while all twelve paired quality contrasts preserve censoring. The shared
sixteen-command baseline histories are verified separately from immediate
feedback histories, so the latter never supply mislabeled baseline features.

This narrows the local design question: earlier context is observable, but
immediate use of the existing controller still fails three training starts.
The observation delay cannot by itself explain that coverage deficit. Retained
support geometry, requested corrections, resolver clamps and observed response
need mechanical diagnosis before another controller is proposed. The prior
RMA discussion motivates context-dependent control; it does not make this
available action reliable. No external code or dependency was imported and no
published result or earlier confirmation is used as fresh training evidence.

## 2026-10-23 retained command composition

The [height-composition diagnostic](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-height-composition-diagnosis---2026-10-23)
verifies a post-hoc common prefix from all four immediate-height training
trials. It finds opposing baseline vertical motion in 744/994 supported-leg
observations, including the positive trial. Seven controls pass, with a separate
finite-difference projection oracle and full original-closure verification.
The body-motion request excludes the gait objective; its fixed-state discrepancy
is neither the declared quality metric nor evidence of a causal failure.

The primary [MIT record for Di Carlo et al. (2018)](https://dspace.mit.edu/entities/publication/bc8c7e1e-5830-443f-a879-787947111fcf)
describes convex predictive planning of ground reaction forces for a
torque-controlled quadruped using simplified three-dimensional dynamics. Only
the primary abstract was accessible in this review; the full accepted manuscript
was not retrieved. This motivates examining combined body requests and contact
constraints, but supplies no implementation or performance evidence here.
The current provider emits velocity residuals, so force-control results cannot
be transferred without a separately verified actuation mapping. No external
code or dependency was imported.

The next local hypothesis instead reuses the already reviewed damped inverse
to compensate opposing baseline vertical motion during observed support. Its
formula and fresh comparison roles are recorded in the roadmap. This proposal
must still pass analytic, ABI and physical checks; an improved fixed-state
projection alone cannot establish a useful controller or a learned selector.

## 2026-10-23 support-vertical composition preparation

The [local successor](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#prepared-support-vertical-comparison---2026-10-23)
implements the previously declared opposing-vertical hypothesis through the
existing damped inverse and bounded velocity-residual ABI. Eight component
controls include an independent damped normal equation and two-core agreement;
eight host and ten synthetic route controls also pass. The complete applicable
gate passes all 250 controls without new worlds. Sixteen fresh native trials
remain prospective. This does not implement the cited predictive force planner
or establish physical benefit. No third-party code or dependency was imported.

## 2026-10-23 support-vertical outcome and coordination question

The [complete comparison](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-support-vertical-comparison---2026-10-23)
retains 2/16 eligible trials and an empty four-start shortlist. One positive
paired tracking score improves; eligibility coverage does not. All seven
closure controls pass. The current hypothesis has not produced a usable
condition-dependent controller family.

Re-read [Wu et al., primary HTML](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0356505),
sections 2.2-2.4 and 2.7. Their feedback uses contact mismatch and body attitude
to adjust phase; leg residuals observe phase/contact context, while shared
frequency and clearance proposals preserve coordination. This motivates a
retained-data diagnosis, not a causal conclusion about the present failures.
Their position-servo and gait-parameter interface does not implement this
project's velocity-residual ABI. No code, weights or numerical gains were
imported. The next controller still requires its own prospective comparison.

## 2026-10-23 phase/contact and command-response diagnosis

The [retained-data reader](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-phasecontact-and-command-response-diagnosis---2026-10-23)
now covers all sixteen trials over the same 96-command prefix. Eight controls
pass with zero new worlds. Actual phase memory is already exposed through the
v1 provider context. Scheduled stance lacks observed support in 1,868/4,896
leg observations, and the fixed-torso reach bound excludes floor contact in
1,442 of those. Both positive trials share this pattern, preventing a causal
or success-predictor interpretation.

The primary [Wu et al. method](https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0356505),
sections 2.2-2.4, motivates using actual phase/contact context to coordinate
residuals. The local next hypothesis is bounded release before scheduled
liftoff, with the existing slew resolver retained. This is a development
inference from the local measurements, not a replication of their learned
position controller. It may remove useful support as well as conflicting
corrections; fresh full-horizon and healthy-body comparisons remain necessary.
No third-party code, weights or gains were imported, and no claim gate changed.

## 2026-10-23 phase-aware residual-release preparation

The [local successor](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#prepared-phase-release-comparison---2026-10-23)
now implements bounded release using actual v1 phase context. It derives the
44-command interval from this project's existing correction and slew limits;
it does not copy paper gains, policies or code. All 287 zero-world controls
pass, including complete-cycle real-ABI agreement on both frozen cores and an
independent taper calculation. The prospective comparison includes all four
training starts and healthy/degraded motors, with a finite zero-observed-loss
healthy-body screen. Physical usefulness and experience-dependent adaptation
remain unproved until fresh execution and closure.

## 2026-10-23 phase-release physical comparison

The [completed comparison](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-phase-release-comparison---2026-10-23)
retains all 32 CPU trials after the full 287-control gate and independent
replay: 19 eligible and 13 negative. Immediate phase release succeeds at two
weakened starts where the vertical reference fails, but fails at the reference's
successful start. Delayed release succeeds at none of the four weakened starts.
All nominal trials survive, while every corrected role loses nominal tracking
quality at every start. Eight closure controls pass; the declared fixed-role
shortlist remains empty.

These finite observations support investigating a repertoire of complementary
behaviors and earlier causal selection. They do not establish that the local
rule reproduces Wu et al.'s learned position controller, explains a cause, or
provides useful adaptation. A future successor must retain the uncovered
weakened start, delayed-control failure and healthy baseline in its question.
No third-party code, weights or gains were imported; no claim gate changed.

## 2026-10-23 first-response context and feedback repertoire

The [completed fit](../SDK_PRODUCT_AND_ADAPTATION_ROADMAP.md#completed-first-response-repertoire-fit---2026-10-23)
reuses all 32 closed training outcomes and constructs zero worlds. The earliest
causal response classifies 8/8 groups in paired-start internal validation; 24
immediate episodes retain nine failures and yield 720 eligible cases. Ten
component and four closure controls pass. The healthy baseline remains an
explicit fitted option, and the uncovered weakened start is not removed.
Runtime selection and useful adaptation remain unproved.

Re-read the primary sources for [Cully et al., Robots that can adapt like
animals](https://arxiv.org/abs/1407.3501v4) and [Kumar et al., RMA](https://www.roboticsproceedings.org/rss17/p011.html).
The first constructs a behavior map before deployment and uses it to guide
trial-and-error adaptation after damage without requiring self-diagnosis. RMA
combines a base policy with a simulation-trained adaptation module. These
motivate maintaining complementary behaviors and estimating hidden conditions
from experience. Our one-command window, centroid classifier, velocity-feedback
experts and selection rules are local hypotheses; they are not reproductions
of either method or imported paper constants. No third-party code, weights or
dependencies were copied. Internal context accuracy and repertoire coverage
remain separate from physical control benefit and reserved evaluation.
