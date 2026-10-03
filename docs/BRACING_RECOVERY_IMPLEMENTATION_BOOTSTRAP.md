# Bracing, Self-Support, and Recovery Implementation Bootstrap

- **Status:** BR1's historical report-v1 revisions remain verification-only, current report-v2 production evidence is accepted at its exact gate, and Cole has formally accepted bounded BR2.1 articulated-observer truth, BR3A L1 engine/contact truth, BR4 L2 joint-actuator truth, BR3B L3 basic loaded-foot truth, BR6A L4 vertical-rail leg support, BR7 scaffold-constrained planar multi-contact stance, BR8 early loss-of-viability detection, BR9 scaffold-constrained planar existing-contact pitch arrest, BR10 scaffold-constrained planar reachable catch, BR11 scaffold-constrained planar controlled fall arrest, BR12 profile-specific pose/static-feasibility truth, and BR13 constrained canonical planar get-up; the accepted catalog contains 51 observation-only entries with empty repair rules and no guidance authority; one exact guided physical get-up is proved and exact bounded atomic locomotor steps are independently commissioned on the front-right and rear-left limbs in separate fresh worlds, but BR14A formal acceptance, same-world alternation, accurate final foothold placement, repeated stepping, gait, and walking remain unproved
- **Date:** 2026-07-23
- **Decider:** Cole
- **Scope:** Internal joint actuation, contact/load sensing, standing, fall arrest, self-righting,
  crouch-to-rise, diagnostics, morphology-neutral movement authoring, evidence-backed minimal
  creature repair, and eventual locomotion integration
- **Research contract:** [Ground-Up Locomotion Research Program](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md)
- **Evidence baseline:** LoColemotion has never walked; one exact guided canonical fixture has
  proved a physical get-up and one exact unpinned canonical quadruped has completed a bounded
  atomic locomotor step, but no current game creature has proven general bracing, free-3D
  recovery, morphology transfer, repeated locomotion, gait, or walking

> This document is the executable companion to the ground-up research program. The research program
> defines how LoColemotion learns what is true. This bootstrap defines the concrete code seams,
> equations, experiments, dependencies, and promotion gates needed to make a creature support and
> recover its body through its own limbs.
>
> Every `file:line` anchor below was rechecked against the live repository on 2026-07-19. Anchors are
> navigation aids, not a substitute for reading the current implementation before editing it.

### Implementation checkpoint — 2026-07-19

#### Progress percentages and their denominators

Progress is now reported with auditable gate denominators rather than one
blended implementation estimate:

| Scope | Current result | What the number means |
|---|---:|---|
| Narrow dirty-tree operator checkpoint | **100% executed** | On 2026-07-19 the bounded harness, all lab scripts, canonical L0.0 publication, independent validation, and zero-physics replay completed. Dirty source correctly prevented promotion. |
| Formal BR1 certification matrix | **7 of 7 clean canonical cells certified** | On 2026-07-21 `scripts/run_br1_certification.ps1` passed on clean commit `2f74821` (session `br1_20260721T002052Z_40077d42`): pinned 45-test suite, L0.0; L0.1 at 30/60/120 Hz; L0.2 with gravity disabled/enabled; and L0.3, each twice in fresh processes with production HMAC receipts, independent validation, zero-physics replay, replicate comparison, a final readback sweep, and a detached attested report ending `BR1 certification=pass`. |
| Knowledge admissions | **51 accepted entries: 1 L0 baseline, 9 BR3A observations/constraints, 3 BR3B observations, 8 BR4 observations, 3 BR6A observations, 4 observations each from BR7, BR8, BR9, BR10, BR11, and BR12, and 3 BR13 observations** | The BR3A, BR3B, BR4, BR6A, BR7, BR8, BR9, BR10, BR11, BR12, and BR13 entries bind their exact accepted evidence through separate append-only operations. Every repair-rule array is structurally empty, automatic application and guidance remain false, and the family-specific support/brace/catch/fall/recovery/consumer/guidance unlock fences remain closed. |
| BR1 report-version integrity repair | **complete; legacy verification and current v2 production authoring verified** | Byte-exact 45/90 and 51/102 report-v1 contracts dispatch through immutable profiles `BR1_L0_V1_R001_I45` and `BR1_L0_V1_R002_I51`; both original external receipts re-verified as non-promotable legacy evidence. Production v1 authoring is disabled. Current session `br1_20260721T200358Z_63a593be` passed under report/inventory/receipt v2 with its distinct HMAC domain. |
| BR2 coordinate-frame oracles | **BR2.1 bounded articulated-observer gate accepted** | BR2.1 fixes the noncommuting rest-frame defect with `joint_binding_v2` / `joint_state_v2`, binds morphology-derived tolerances and stream provenance, witnesses unwrap branch selection against angular rate, and hardens whole-body inertia. The exact 62-test suite passed inside the clean production campaign at `1779acc`; Cole accepted those observer contracts through byte-pinned decision `BR2_1_ARTICULATED_OBSERVER_DECISION_V1`. `frame_v2` consumer integration, actuator truth, load bearing, bracing, standing, recovery, and walking remain explicitly excluded. |
| BR3A/L1.0-L1.7 engine/contact truth | **accepted at the exact certified claim scope; 9 observation-only entries separately admitted** | Campaign `br3a_20260723T050201Z_109cc664` passed 19/19 programs, 38/38 fresh-process capsules, and 584/584 assertions at exact source `109cc664`; its independently verified production report receipt binds the 472 milestone assertions separately from 86 supplementary and 26 integrity assertions. Cole accepted only the exact L1.0-L1.7 scopes through `BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1`. A later, separately authorized operation admitted eight matching milestone observations and the L1.8 supplementary instrumentation constraint. The knowledge guard remains containment evidence rather than knowledge; automatic guidance remains forbidden. |
| BR4/L2 joint-actuator truth | **accepted at the exact certified L2.0-L2.7 scopes; 262/262 promotion assertions; 8 observation-only entries separately admitted** | Campaign `br4_20260723T090118Z_1760c2cf` retained two fresh-process replicates for all eight programs, 16 production-attested bundles, 16 unique target processes, and a detached BR4 report receipt. `BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1` accepts only the fixture-bounded joint/actuator observations. A later admission created eight empty-repair-rule observations. Fixed scaffolds remain scaffolds, hard-limit reaction is not strength, and no contact-bearing limb or guidance is established. |
| BR3B/L3 basic loaded-foot truth | **accepted at the exact certified L3.0-L3.2 scopes; 86/86 promotion assertions; 3 observation-only entries separately admitted** | Campaign `br3b_20260723T103240Z_f5f54a58` retained two fresh-process replicates for all three programs, six production-attested bundles, six unique target processes, and a detached BR3B report receipt. `BR3B_L3_BASIC_LOADED_FOOT_TRUTH_DECISION_V1` accepts only the free unary pad's exact normal/shear/rocking observations. The later admission adds no guidance and establishes no general wrench, allocation, or articulated support. |
| BR6A/L4 vertical-rail leg support | **accepted at the exact certified L4.0, L4.1, and L4.3 scopes; 80/80 promotion assertions; 3 observation-only entries separately admitted** | Campaign `br6a_20260723T121533Z_c0e72549` retained two fresh-process replicates for all three programs, six production-attested bundles, six unique target processes, and a detached BR6A report receipt. `BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT_DECISION_V1` accepts only rail-constrained articulated vertical support. The later admission adds no guidance. The material rail reaction remains controlling; L4.2, per-foot allocation, free-root standing, balance, guidance, and locomotion remain excluded. |
| BR7 planar multi-contact stance | **accepted at the exact certified BR7.0–BR7.3 scopes; 80/80 milestone and 24/24 integrity assertions** | Campaign `br7_20260723T134427Z_91a160b9` retained ten production-attested fresh-process bundles. BR7.4 remains integrity-only. The accepted positive scope is scaffold-constrained planar height/pitch stance and support-loss detection. The unpowered guide still locks out-of-plane translation, roll, and yaw; command shares remain non-measurements; knowledge and guidance remain closed. |
| BR8 early loss-of-viability detection | **accepted at the exact certified BR8.0–BR8.3 scopes; 80/80 milestone and 36/36 integrity assertions; 4 observation-only entries separately admitted** | Campaign `br8_20260723T144351Z_90b2c1ce` retained ten production-attested fresh-process bundles. BR8.4 remains integrity-only. The accepted positive scope is passive planar-scaffold early loss-of-viability detection. The detector and supervisor remain observer-only and execute no brace, step, root rescue, creature edit, or guidance. |
| BR9 existing-contact planar brace | **accepted at the exact certified BR9.0–BR9.3 scopes; 78/78 milestone and 42/42 integrity assertions; 4 observation-only entries separately admitted** | Certification `br9_20260723T160129Z_4023e51f` retained ten production-attested fresh-process bundles. BR9.4 remains integrity-only. The paired live world starts the controller only on the first post-impulse observation, reduces angular-momentum area to 14.97% of the no-brace control and pitch excursion to 27.35%, retains both original contacts continuously, and reconciles finite paired actuator receipts without root rescue, foot pinning, new contact, or guidance. The material out-of-plane guide remains controlling, commanded shares are not per-foot measurements, and the entries add no repair or guidance authority. |
| BR10 reachable planar catch | **accepted at the exact certified BR10.0–BR10.3 scopes; 112/112 milestone and 70/70 integrity assertions; 4 observation-only entries admitted separately** | Certification `br10_20260723T181129Z_980549f8` retained ten production-attested fresh-process bundles. BR10.4 remains integrity-only and is not knowledge. The active fixture creates one new bearing distal contact, expands support, and returns to the full-horizon stance dwell relative to a matched crash control. The material guide, preparation freeze/release, fixed fixture, finite actuators, and command-not-measurement boundary remain controlling; the entries add no repair rule or guidance authority. |
| BR11 controlled planar fall | **accepted at the exact certified BR11.0–BR11.3 scopes; 122/122 milestone and 86/86 integrity assertions; 4 observation-only entries separately admitted** | Certification `br11_20260723T195911Z_d4551f99` retained ten production-attested fresh-process bundles. BR11.4 remains integrity-only and is not knowledge. The active fixture creates semantic protective contact before core impact and improves the preregistered kinetic-energy proxy, core-speed, local-load witness, and linear-momentum comparisons relative to its same-state zero-command control; both worlds finish stably `FALLEN`. The kinetic proxy is not an injury model, the local witness is not load allocation, the material planar guide remains controlling, and the entries grant no repair or guidance authority. |
| BR12 pose and recovery feasibility | **accepted at the exact certified BR12.0–BR12.3 scopes; 122/122 milestone and 28/28 integrity assertions; 4 observation-only entries separately admitted** | Certification `br12_20260723T211754Z_0ace3791` retained ten production-attested fresh-process bundles. BR12.4 remains integrity-only. The accepted scope is profile-specific canonical-pose classification and conservative static torque/power/structure/friction/reach feasibility. Feasible is not dynamic execution evidence; no controller, actuation, contact creation, body rise, stance handoff, repair, or guidance is established. |
| BR13 constrained canonical get-up | **accepted at exact certified BR13.0, BR13.2, and BR13.4 scopes; 114/114 milestone and 66/66 integrity assertions; 3 observation-only entries separately admitted** | Certification `br13_20260723T225845Z_897b93c2` retained ten production-attested fresh-process bundles. Each of three active seeds rose from observed prone to stable stance with finite paired actuation and closed energy/guide accounting; every zero-command control remained prone. BR13.1 and BR13.3 remain integrity-only. The sagittal guide, symmetry-collapsed fixed morphology, exact seed/actuator/threshold/engine boundary, and no-walking claim remain controlling. The later admission adds no repair rule, automatic application, or guidance authority. |
| BR14A spatial controllability | **BR14A.0-BR14A.4 and the BR14A.4R prerequisite are implemented positively; twenty-two programs pass 412/412 assertions across positive, analytic, rejection, observer, and atomic-step contracts; six BR14A.5 controller candidates are rejected, four contact-transition/recovery/translation prerequisites are positive, and two bounded atomic locomotor-step programs are positive on independent limbs** | The unpinned nine-body, 12-DOF quadruped holds all four ordinary contacts across three seeds, arrests a matched 0.020 N m s roll impulse, and repeatedly leaves and reacquires a declared three-contact handoff while all four feet remain down. Matched controls never reacquire. Candidates 1-2 clear provisionally but fail complete overlap. Candidate 3 refuses an over-cap transition. Candidate 4 aborts safely without rearming. Candidate 5 advances nine logical lift ticks but never clears. Candidate 6 exposes the geometric-gap/contact distinction. Candidate 7 removes the selected foot from Jolt's semantic manifold and observes same-place recontact. Candidate 8 commands a bounded 0.020 m horizontal relocation before ordinary recontact. Candidate 9 recovers after targeted recontact. Candidate 10 advances whole-system COM and torso in positive world X. Candidate 11 seals one exact front-right support-to-support locomotor cycle. Candidate 13 independently seals a rear-left diagonal cycle after real airborne relocation and exposes a support-geometry defect: the inherited roll/pitch velocity-feedback term injects energy on one seed, while a fixed 300-tick post-recontact suppression window restores a quiet supported finish. The two programs run in separate fresh worlds. They do not establish same-world alternation, a second sequential step, repeated stepping, accurate final foothold placement, gait, walking, formal acceptance, repair, or guidance. |
| Full BR0-BR14 evidence ladder | **77.8% accepted gate-complete (14 of 18 named BR milestones)** | BR0, BR1, bounded BR2.1, BR3A L1, BR4 L2, BR3B L3, BR6A L4, BR7 planar stance, BR8 early loss-of-viability detection, BR9 planar existing-contact pitch arrest, BR10 planar reachable catch, BR11 controlled planar fall, BR12 pose/static-feasibility truth, and BR13 constrained planar get-up are closed at their exact scopes. No accepted milestone establishes free-3D or morphology-generalized recovery, independent four-limb control, a step, gait, or walking. Separate BR14A commissioning now establishes independently reproduced front-right and rear-left bounded atomic steps in fresh worlds without changing the 14/18 formal denominator. |
| Proven free-3D standing/recovery, general bracing, generalized fall arrest, repeated locomotion, or walking | **formal acceptance remains 0%; one exact free-3D static stance and two independent bounded atomic-step programs are observed in BR14A commissioning** | BR14A.3, Candidate 11, and Candidate 13 are real unpinned articulated physics, but none has crossed a promotion/certification decision. Candidates 11 and 13 establish one exact support-to-support locomotor cycle per fresh world on two different limbs; same-world sequencing, accurate final foothold placement, a second transition, alternation, repeatability, gait, walking, repair, and guidance remain open. |

BR1 certification is an evidence-pipeline claim only. It must never be quoted
as "locomotion is done": it proves the laboratory can produce, validate,
replay, replicate, and attest clean evidence, and nothing else.

The repository now contains the BR1/L0 laboratory foundation described by
this bootstrap:

- strict experiment expansion and execution registries;
- direct-state frame, command, application, intervention, mechanics, event,
  runtime-note, summary, process, configuration, and checksum contracts;
- parent-reserved fresh-process execution with one-shot child adoption and
  parent-only publication;
- controlled-abort and pre-event evidence;
- L0.0-L0.3 physical fixtures plus L0.4 trace-only replay;
- independent L0.0-L0.2 unary metric recomputation from sealed raw streams;
- strict L0.3 observer A/B recomputation that requires all four metrics, all
  four complete frame streams, exact observer-arm configuration evidence,
  collision-free/no-control ledgers, cross-arm callback identity, the
  primary/contact stream identity, reporting mirrors, and independently
  rebuilt gate/hypothesis/promotion conclusions;
- hardened test harnesses that reject Godot script errors even when the native
  process returns exit code zero, impose declared deadlines, capture stdout and
  stderr without pipe deadlock, terminate the complete child process tree on
  timeout, and record start/timeout/termination failures; and
- append-only knowledge admission and fail-closed morphology-aware querying.

The repository also tracks a VS Code Insiders GDScript workspace contract for
the exact Godot 4.7 console executable. It supplies a deterministic headless
language-server path and an explicit `type: "godot"` F5 profile. C#-specific
Godot extensions are marked unwanted because they were auto-activating
Roslyn, C# Dev Kit, Mono Debug, and .NET services in this GDScript-only
workspace.

That is the instrumentation and prerequisite-mechanics bootstrap, not the
bracing result. BR4 joint-actuator truth has crossed only its exact
fixture-bounded gate. Command-to-contact load transmission through a
contact-bearing articulated limb has not. Therefore no current result
establishes standing, bracing, fall arrest, self-righting, getting up, gait,
or walking.

There is no external Godot execution quota. The exact local Godot 4.7 console
binary runs headless. A complete dirty-tree checkpoint on 2026-07-19 passed
the process-runner self-test, 39/39 scripts and 632/632 assertions, canonical
L0.0 bundle validation, and L0.4 replay of 61 frames and one event with zero
physics steps. The L0.0 physical and configuration gates passed; the source
gate failed solely on `DIRTY_WORKTREE`, so promotion remained
`not_evaluated`. No entry was admitted.

The formal closeout gap that checkpoint exposed is now closed:
`scripts/run_br1_certification.ps1` pins the complete 45-test certification
inventory and both engine binaries by SHA-256, publishes the full
L0.0/L0.1/L0.2/L0.3 canonical matrix twice per cell in fresh processes, and
authenticates every bundle and the final report with detached HMAC receipts
from a trust store held outside the evidence directory. Its only positive
marker is `BR1 certification=pass`, first produced on 2026-07-21.

#### Current cryptographic trust boundary

The bundle proves that its conclusions follow from its currently sealed raw
records. SHA-256 checksums detect accidental corruption and localized edits,
and the semantic validators reject a writer who changes only a metric, gate,
profile label, frame range, report, or checksum inventory.

Since 2026-07-21, publication and certification additionally require detached
HMAC-SHA256 receipts from a trust store held outside the evidence directory
(the second option below, now implemented). A writer who can replace bundle
bytes but cannot read the trust-store key can no longer manufacture an
acceptable bundle, and knowledge admission revalidates the receipt before any
entry is written.

The remaining boundary is the key itself: it is one locally held symmetric
key, so an attacker with full local-machine access, including the trust
store, can still re-sign a forged bundle. The stronger options remain open:

- a parent-held asymmetric signing key and detached signature over the final
  content digest, verified from a separately trusted public key; or
- a remote/content-addressed append-only evidence store with authenticated
  writes and retention.

Documentation and UI should therefore say **checksum-sealed with detached
keyed receipts**, not third-party-verifiable signatures or adversarially
immutable storage.

---

## 0. Read this first

### 0.1 The problem is upstream of walking

The immediate engineering question is not:

> Which gait parameters make the quadruped move forward?

It is:

> Can one powered joint produce a predicted torque, can one planted leg turn that torque into a
> measured ground reaction, can several legs carry and reorient a body, and can the controller
> deliberately recover after support is lost?

Until those questions are answered independently, gait work mixes at least five different failure
classes:

1. actuator capacity;
2. joint-state and frame correctness;
3. contact/load perception;
4. support and balance control;
5. recovery planning.

A gait can fail because any one of those is broken. Increasing muscle, adding a tendon, or tuning a
phase cannot repair the other four.

### 0.2 The current honest statement

The current runtime can apply equal-and-opposite torque across a hinge. That is a valid internal
actuation primitive.

The current runtime does **not** yet provide a certified pipeline from:

```text
actual body and contact state
  -> desired whole-body support wrench
  -> feasible contact-load allocation
  -> current-axis joint torques
  -> actuator/passive-tissue limits
  -> paired torque application
  -> measured ground reaction
  -> body support, fall arrest, or recovery
```

The missing pipeline—not a lack of sinusoidal motion—is the subject of this bootstrap.

### 0.3 Three claims that must remain separate

The implementation and UI must never collapse these into a single `stable` or `fell` boolean:

| Claim | Meaning | Minimum proof |
|---|---|---|
| **Can support** | The morphology and actuators can hold a declared load in a declared pose | Loaded-joint and rail-leg experiments |
| **Can brace** | The controller detects support loss soon enough and arrests a declared disturbance | Deterministic tip/push trials with brace on/off |
| **Can get up** | From a declared fallen pose, the creature establishes contacts, raises its CoM, and holds a stand | Pose-specific recovery trials with no root assistance |

A creature can be strong enough to stand but have no brace reflex. It can brace small disturbances
but be unable to get up from its side. It can possess a recovery policy that its morphology cannot
physically execute.

### 0.4 What this bootstrap does not permit

None of the following can satisfy a support, brace, or recovery gate:

- direct root lift;
- unreacted root righting torque;
- transform edits or teleportation;
- respawning upright;
- a rail or gantry doing positive vertical work;
- a physical umbrella or outrigger carrying undeclared load;
- collision penetration or solver ejection;
- disabling self-collision when limb-through-body motion is required for the result;
- a rollout ending before the recovery window and then inferring recovery;
- a summary classifier without the raw causal trace;
- any previous `credible_walk`, champion, optimizer, or green walking test.

Scaffolds are allowed as isolating instruments. Their impulse and work must be recorded, and the
claim must name the scaffolded degrees of freedom.

---

## 1. Verified current-state diagnosis

This section fixes the implementation starting point. It is intentionally blunt so a future coding
thread cannot accidentally reintroduce an old assumption as fact.

### 1.1 What is already physically useful

| Existing seam | Current behavior | Reuse decision |
|---|---|---|
| [JointKinematics](../scripts/sim/joint_kinematics.gd#L1-L22) | Reads a signed hinge angle from live parent/child bases | Reuse after expanding frame tests |
| [LegTracker task math](../scripts/sim/leg_tracker.gd#L19-L46) | Computes a virtual foot force, one \(J^T\) torque column, and distal gravity compensation | Reuse as a tested micro-oracle, not as a complete stance controller |
| [CreatureBody hinge metadata](../scripts/sim/creature_body.gd#L173-L197) | Exposes parent, child, initial axis, parent-local axis, rest-relative basis, and limits | Extend into a stable `JointBinding` |
| [Paired torque application](../scripts/sim/cpg_controller.gd#L583-L589) | Applies \(+\tau\) to child and \(-\tau\) to parent | Move behind one ledgered actuator service |
| [Static stand solver](../scripts/core/CharacteristicsEvaluator.gd#L668-L909) | Estimates vertical foot loads and per-joint stance moments | Extract shared math; validate it against live contacts |
| [Contact monitor build option](../scripts/sim/creature_body.gd#L23-L33) | Can enable Godot/Jolt contact monitoring per rigid body | Make canonical in lab fixtures |
| [Project physics baseline](../project.godot#L33-L35) | Uses Jolt with 20 velocity and 4 position steps | Record in every manifest; sweep rather than assume |

These are useful mechanisms. None is inherited proof that a limb can carry the body.

### 1.2 The live control split is structurally unsafe

The normal drive loop skips every reference-tracked leg joint:

```gdscript
if bool(d.get("leg_tracked", false)):
    continue
```

See [cpg_controller.gd:551-562](../scripts/sim/cpg_controller.gd#L551-L562).

That skip occurs before:

- ordinary overlay consumption;
- passive spring application;
- `_theta` and `_omega` storage;
- ordinary command telemetry.

The spring call and state write occur later at
[cpg_controller.gd:583-610](../scripts/sim/cpg_controller.gd#L583-L610). The tendon pass then reads
those stored values at
[cpg_controller.gd:1600-1631](../scripts/sim/cpg_controller.gd#L1600-L1631).

The resulting failure is:

```text
reference-tracked joint
  -> skips normal loop
  -> spring is not evaluated there
  -> live tendon state is not written there
  -> tendon pass reads stale/default joint state
```

This is why a resource being present on the anatomy does not prove that its force participated in
the observed motion.

### 1.3 Generic joint torque uses a stale world axis

At bind time the generic drive stores `axis_world` as `d["axis"]` at
[cpg_controller.gd:289-304](../scripts/sim/cpg_controller.gd#L289-L304). The ordinary torque path
later uses that stored vector at
[cpg_controller.gd:563-589](../scripts/sim/cpg_controller.gd#L563-L589).

The physical hinge axis rotates with its parent body. A build-pose world vector does not.

The reference-tracked path already demonstrates the correct pattern:

```gdscript
var axis_world := (parent.global_basis * axis_parent_local).normalized()
```

See [cpg_controller.gd:1015-1019](../scripts/sim/cpg_controller.gd#L1015-L1019).

Every active torque, passive spring, tendon contribution, IK calculation, and recovery command must
use the same current-axis calculation.

### 1.4 “Grounded” is geometric proximity, not load

The tracked-leg controller currently latches `grounded` from foot height and a dead band at
[cpg_controller.gd:824-833](../scripts/sim/cpg_controller.gd#L824-L833).

That signal does not establish:

- collision contact;
- contact point;
- ground normal;
- normal load;
- tangential slip;
- center of pressure;
- whether a body part rather than a foot supports the creature.

`SimRollout` can opt into true contact monitoring, but it is off by default because it perturbs old
chaos-fragile results; see
[sim_rollout.gd:54-64](../scripts/sim/sim_rollout.gd#L54-L64). Its contact analysis is performed
after the physics step for aggregate diagnostics at
[sim_rollout.gd:189-246](../scripts/sim/sim_rollout.gd#L189-L246), not fed into the live stance
controller.

The new system will retain both channels:

```text
near_ground       # geometric predictor
contact_present   # exposed collision fact
bearing           # inferred from contact + normal load + persistence
```

They may correlate. They may never share one name.

### 1.5 The current muscle model conflates strength and inertia

The evaluator constants are:

```gdscript
MUSCLE_BASELINE_CAP = 120.0
MUSCLE_TORQUE_K     = 240.0
```

at [CharacteristicsEvaluator.gd:118-123](../scripts/core/CharacteristicsEvaluator.gd#L118-L123).
The maximum torque is:

```gdscript
return (MUSCLE_BASELINE_CAP + MUSCLE_TORQUE_K * muscle_frac) * inertia
```

at
[CharacteristicsEvaluator.gd:1585-1586](../scripts/core/CharacteristicsEvaluator.gd#L1585-L1586).
`subtree_muscle_frac()` clamps its result to `4.0` at
[joint_model.gd:40-64](../scripts/sim/joint_model.gd#L40-L64).

Consequences:

1. A small distal subtree receives a small cap even if its joint carries a large share of whole-body
   load.
2. Increasing authored muscle beyond the fraction clamp is a no-op.
3. A non-muscular joint still receives the baseline actuator term.
4. Inertia controls both the plant's physical response and the declared strength, making cause and
   effect difficult to separate.

The evaluator itself documents the concrete failure: a roughly 92 kg quadruped had an approximately
89 N·m knee cap even though the knee needed to resist a body-share stance moment. See
[CharacteristicsEvaluator.gd:623-663](../scripts/core/CharacteristicsEvaluator.gd#L623-L663).

### 1.6 The live tracker controls a foot path, not body support

The tracked path builds:

```text
tau = tau_task + tau_gravity_of_distal_subtree + tau_extensor
```

and clamps the sum at
[cpg_controller.gd:1037-1069](../scripts/sim/cpg_controller.gd#L1037-L1069).

There is no general desired pelvis/CoM height, desired whole-body wrench, or contact-force allocator.
A planted foot can remain close to its target while the knee folds and the pelvis drops. The code
also documents that the live stance-hip reference can follow a deep collapse and soften into the
low posture at
[cpg_controller.gd:1047-1060](../scripts/sim/cpg_controller.gd#L1047-L1060).

For sagittal rigs, the controller deliberately skips a downward support-foot bias because it
previously created spurious propulsion; see
[cpg_controller.gd:961-974](../scripts/sim/cpg_controller.gd#L961-L974). That was a sensible local
safety response, but it leaves the system without a replacement whole-body support objective.

### 1.7 The telemetry erases the failure distinction

For reference-tracked joints, `_last_commands` writes:

```gdscript
"target": th,
"base_target": th,
"theta": th,
```

at [cpg_controller.gd:1137-1149](../scripts/sim/cpg_controller.gd#L1137-L1149).

The recorded target is therefore identical to the measured angle even when the actual controller
target was elsewhere. The record also omits the component torques, cap, saturation, desired foot
force, and bearing state.

Today these five failures can look identical:

```text
brace was never requested
contact did not exist
target followed the collapse
joint lost leverage near a singularity
actuator saturated
```

The flight recorder must separate them before the controller is tuned.

### 1.8 Existing “balance” includes direct root assistance

The posture stabilizer applies torque directly to the root at
[cpg_controller.gd:1694-1717](../scripts/sim/cpg_controller.gd#L1694-L1717). The legacy path can
also apply upward central force at
[cpg_controller.gd:1719-1734](../scripts/sim/cpg_controller.gd#L1719-L1734).

Those may remain available as explicitly measured scaffolds. They cannot certify limb bracing,
standing, or recovery.

The root-righting cross product also has no unique correction axis at exactly upside down. Even an
arbitrarily strong direct-root stabilizer is not a prone/supine recovery policy.

### 1.9 Falling is terminal evidence, not a live behavior state

The rollout accumulates historical minimum height and up-dot values at
[sim_rollout.gd:139-162](../scripts/sim/sim_rollout.gd#L139-L162), aborts on major inversion or
height loss at
[sim_rollout.gd:318-321](../scripts/sim/sim_rollout.gd#L318-L321), and derives a permanent `fell`
summary at
[sim_rollout.gd:345-365](../scripts/sim/sim_rollout.gd#L345-L365).

That is useful for legacy failure classification. It is incompatible with a recovery experiment:
the trial ends before the behavior can recover, and a later recovery would not erase the historical
minimum anyway.

The current spawn path also avoids the problem by lowering legged walkers to a 3 cm settle gap
because the prior 0.4 m drop created a collapsed pose the extensors could not recover from; see
[sim_rollout.gd:600-611](../scripts/sim/sim_rollout.gd#L600-L611).

### 1.10 Arbitrary 3D recovery is not currently morphologically available

`SocketDef.hinge_axis_2` is explicitly authored-but-undriven at
[socket_def.gd:15-63](../scripts/core/socket_def.gd#L15-L63). `CreatureBody` creates one
`HingeJoint3D` for an actuated socket at
[creature_body.gd:234-255](../scripts/sim/creature_body.gd#L234-L255).

A sagittal-only hip can flex and extend but cannot necessarily abduct a side-lying body into a
supporting pose. Until proximal multi-axis dynamics exist, some 3D recovery poses must be:

- constrained to a plane for research;
- solved with another effector such as an arm or tail; or
- reported as morphologically infeasible.

---

## 2. Physics and control model

This section establishes signs, units, and dependencies. Every implementation snippet later in the
document follows these conventions.

### 2.1 Coordinate and force conventions

- World \(+\hat y\) is up.
- Scalar \(g > 0\).
- Gravity acceleration is \(\mathbf g = (0,-g,0)\).
- \(\boldsymbol\lambda_i\) is the force the environment exerts on the creature at contact \(i\).
- \(\mathbf u_i = -\boldsymbol\lambda_i\) is the virtual force with which the foot presses the
  environment in the simplest virtual-model controller.
- \(\tau_j\) is the scalar generalized torque about joint \(j\)'s current positive axis.
- Units are SI: metres, seconds, kilograms, newtons, newton-metres, joules, and watts.

The sign convention must be verified in the one-joint and force-reversal controls. A comment is not a
sign oracle.

### 2.2 Why internal torque needs external contact

Equal-and-opposite joint torques conserve the total angular momentum of the isolated articulated
system. They can change relative pose. They cannot create net linear momentum.

Whole-body translation requires an external impulse:

\[
\Delta \mathbf p
=
\int \left(
\sum_i \boldsymbol\lambda_i
+ m\mathbf g
+ \mathbf f_\text{other}
\right)\,dt
\]

Therefore:

- an airborne creature can reconfigure and rotate;
- a planted creature can push the floor and receive a ground reaction;
- a fallen creature must find or use a contact before it can raise its center of mass;
- an unpaired root or foot force is external assistance, regardless of its variable name.

### 2.3 Required contact force for height control

For a vertically constrained body:

\[
a_y^\* =
k_h(h^\*-h)
- d_h v_y
\]

\[
F_\text{contact,y}^\*
=
m(a_y^\* + g)
\]

Where:

- \(h^\*\) is desired support height;
- \(h\) is whole-body CoM height above the support plane for the certified analytic rail oracle;
- \(v_y\) is vertical velocity;
- \(k_h\) has units \(s^{-2}\);
- \(d_h\) has units \(s^{-1}\).

The \(m(a_y+g)\) relation is exact for whole-body CoM acceleration. An authored pelvis/root height
may be a useful control output, but internal articulation can move it without the same whole-body net
force. Any pelvis-height version is therefore an identified proxy with its own calibration, not the
analytic force oracle.

Cause and effect:

| Change | Direct effect | Failure if too large |
|---|---|---|
| Raise \(k_h\) | More upward correction per metre of sag | Oscillation, contact impact, actuator saturation |
| Raise \(d_h\) | More opposition to vertical velocity | Sluggish rise, excessive active braking |
| Raise body mass \(m\) | Proportionally raises required support force | More joint torque and contact demand |
| Raise desired height \(h^\*\) | Requires longer leg geometry and positive work | ROM/singularity failure |
| Lower physics `dt` | Usually improves feedback resolution | More runtime cost; does not repair a bad model |

### 2.4 Desired whole-body wrench

For a free body, support is not only an upward force. The contact set must also create a rotational
moment:

\[
\mathbf F^\*
=
m(\mathbf a^\*-\mathbf g)-\mathbf f_\text{known-other}
\]

\[
\mathbf M^\*
=
\mathbf K_R\mathbf e_R
- \mathbf D_R\boldsymbol\omega
- \mathbf m_\text{known-other}
\]

`SupportMath.orientation_error_world(desired, current)` defines \(\mathbf e_R\) as the shortest
world-space rotation vector that rotates the current authored anatomical basis toward the desired
basis. Positive \(\mathbf K_R\mathbf e_R\) must therefore reduce the error. A labeled-box oracle at
\(\pm90^\circ\) about each axis pins this sign before any stance or arrest controller uses it.

The contact allocator must find \(\boldsymbol\lambda_i\) such that:

\[
\sum_i \boldsymbol\lambda_i = \mathbf F^\*
\]

\[
\sum_i(\mathbf p_i-\mathbf c)\times\boldsymbol\lambda_i = \mathbf M^\*
\]

subject to:

\[
\mathbf n_i\cdot\boldsymbol\lambda_i \ge 0
\]

\[
\left\|\boldsymbol\lambda_{i,t}\right\|
\le
\mu_i(\mathbf n_i\cdot\boldsymbol\lambda_i)
\]

and the resulting joint torques remaining inside their active and structural envelopes.

Definitions:

- \(\mathbf p_i\): contact position;
- \(\mathbf c\): whole-body center of mass;
- \(\mathbf n_i\): contact normal;
- \(\mu_i\): empirically measured friction coefficient for that material/contact regime.

A foot may push a floor. It may not pull an ordinary floor.

### 2.5 Contact force to joint torque

For a revolute joint with current world axis \(\mathbf a_j\), pivot \(\mathbf o_j\), and contact
position \(\mathbf p_i\), one Jacobian column is:

\[
\mathbf J_{ij}
=
\mathbf a_j\times(\mathbf p_i-\mathbf o_j)
\]

Let \(\boldsymbol\lambda_i\) mean the **ground-on-body** contact force. Its external generalized load
on joint \(j\) is:

\[
Q_{\lambda,ij}
=
\mathbf J_{ij}\cdot\boldsymbol\lambda_i
=
\mathbf a_j\cdot\left((\mathbf p_i-\mathbf o_j)\times\boldsymbol\lambda_i\right)
\]

The current helper
[LegTracker.joint_task_torque](../scripts/sim/leg_tracker.gd#L30-L35) implements this scalar
relation for a commanded force. The actuator command that statically opposes an external
ground-on-body load is:

\[
\tau_{\text{actuator},ij}=-Q_{\lambda,ij}
\]

Equivalently, if a controller defines \(\mathbf u_i=-\boldsymbol\lambda_i\) as its
**foot-on-ground** command, then \(\tau_{\text{actuator}}=J^T\mathbf u\). Every function and trace
field must name which force convention it uses.

For full constrained dynamics:

\[
\mathbf M(\mathbf q)\ddot{\mathbf q}
+ \mathbf C(\mathbf q,\dot{\mathbf q})
+ \mathbf G(\mathbf q)
=
\mathbf S^T\boldsymbol\tau
+ \mathbf J_c^T\boldsymbol\lambda
\]

LoColemotion does not need a full rigid-body dynamics library for the first rail-leg controller. It
does need to avoid double-counting gravity or contact force when it graduates from virtual-model
control to whole-body inverse dynamics.

### 2.6 Static joint requirement

For a declared contact load, first compute the external load moment about joint \(j\):

\[
Q_{\text{load},j}
=
\mathbf a_j\cdot
\left[
\sum_{i\in contacts(subtree(j))}
(\mathbf p_i-\mathbf o_j)\times\boldsymbol\lambda_i
+
\sum_{b\in subtree(j)}
(\mathbf c_b-\mathbf o_j)\times m_b\mathbf g
\right]
\]

With the convention that positive actuator torque is applied to the child/distal subtree:

\[
\tau_{\text{required},j}=-Q_{\text{load},j}
\]

The first sum includes only contacts whose force acts on the distal subtree. The second sum is the
distal subtree's gravitational moment. This sign matches the current
`LegTracker.joint_gravity_torque()` helper, which negates the gravitational load moment.

This is why compensating only the shin's weight does not prove that the knee can carry the torso.

### 2.7 Torque reserve, power, and rise energy

Static holding requires:

\[
\rho_{\tau,j}
=
\frac{|\tau_{\text{required},j}|}{\tau_{\text{available},j}}
< 1
\]

But \(\rho_\tau=0.99\) is not a useful animal. It has almost no authority left for impact, damping,
load transfer, or rising.

The experiment declares a reserve before running. A reasonable initial engineering target is:

```text
nominal static utilization <= 0.50–0.60
declared transient utilization < 1.00
```

This is a starting design target, not a biological law.

Mechanical power is:

\[
P_j = \tau_j\dot q_j
\]

The minimum change in gravitational potential for a rise is:

\[
\Delta E_g = mg\Delta h
\]

If commanded positive actuator work is far below \(mg\Delta h\), then one of four things is true:

1. a scaffold or hidden assist lifted the body;
2. stored passive energy supplied the difference;
3. the energy ledger is incomplete;
4. the reported height or mass is wrong.

### 2.8 Why a perfectly straight leg is not the universal answer

A straight column can transmit compression with little joint moment when perfectly aligned. It is
also near a kinematic singularity:

- the first-order vertical Jacobian may approach zero;
- the controller loses leverage in some directions;
- the knee has no robust preferred buckling direction;
- small contact errors can flip it into hyperextension or collapse;
- a hard extension command can kick the contact away.

The first active brace should use:

- slight flexion;
- a known knee direction;
- a soft extension limit;
- passive stiffness near extension;
- active damping;
- declared torque reserve.

### 2.9 Active muscle, passive spring, and structural limits

These are different ledgers:

| Component | Can do positive net work? | Capacity source | Applied when |
|---|---:|---|---|
| Active actuator/muscle | Yes | Isometric torque, speed, power, activation | Controller requests it |
| Passive joint spring | No over a closed lossless cycle | Deflection and stiffness | Every tick |
| Passive tendon coupling | No over a closed lossless cycle | Coupled joint deflection | Every tick |
| Damper | No; dissipates energy | Relative speed and damping | Every tick |
| Structural stop | No controlled positive work | Joint geometry/material limit | Near/at limit |

A tendon does not decide to brace. A spring at its rest angle produces zero elastic torque. Muscle
cannot help if the controller never requests the needed action.

### 2.10 Feedback gains and inertia

Inertia belongs in the response calculation, not in the strength definition.

For a desired second-order joint response:

\[
K_p = I_\text{ref}\omega_n^2
\]

\[
K_d = 2\zeta I_\text{ref}\omega_n
\]

Where:

- \(I_\text{ref}\) is the reflected inertia around the joint;
- \(\omega_n\) is desired natural frequency;
- \(\zeta\) is damping ratio.

Changing inertia with fixed torque changes acceleration:

\[
\alpha = I^{-1}\tau
\]

Changing muscle capacity changes the reachable torque envelope. Those effects must be independently
sweepable.

---

## 3. Target architecture and source layout

### 3.1 Architectural decision

Build and certify the pipeline inside `scripts/lab/` first. Do not repair bracing by adding more
branches inside `CpgController`.

The lab path will have:

1. one authoritative joint-state reader;
2. one authoritative current-axis calculation;
3. one actuator-envelope implementation;
4. one passive-tissue evaluation pass;
5. one command arbiter;
6. one paired-torque application service;
7. one contact-frame provider;
8. one whole-body state provider;
9. small stance, brace, and recovery controllers;
10. adapters into gameplay only after the primitives pass.

### 3.2 Proposed files

```text
scripts/core/parts/
  actuator_spec.gd                 # authored active capacity and structural envelope
  recovery_profile.gd              # anatomical basis, contact roles, pose goals

scripts/lab/
  experiment_spec.gd               # already required by the research program
  expanded_experiment.gd           # immutable, validated, fully defaulted spec
  spec_compiler.gd                 # precedence, canonicalization, stable hash
  observer_profile.gd
  lab_process_launcher.gd           # unique run reservation + isolated process/log paths
  lab_runner.gd
  rig_factory.gd
  random_stream_capability.gd       # draw-only named RNG; no reseed/replace authority
  capture_clock.gd
  frame_assembler.gd
  finite_sanitizer.gd
  pre_event_ring_buffer.gd
  comparison_runner.gd
  campaign_runner.gd
  command_ledger.gd
  frozen_value.gd
  canonical_json.gd
  actuation_executor.gd
  intervention_executor.gd
  trace_store.gd
  schema_validator.gd
  mechanics_accountant.gd
  gate_evaluator.gd
  event_detector.gd
  trace_replay.gd
  report_builder.gd
  run_bundle_validator.gd
  run_index.gd
  failure_codes.gd

  records/
    body_sample.gd
    joint_torque_command.gd
    decision_record.gd
    mechanics_record.gd
    intervention_record.gd
    execution_receipt.gd
    recovery_event.gd
    runtime_note.gd
    run_summary.gd

  mechanics/
    joint_binding.gd               # stable runtime references and frames
    joint_state.gd                 # q, qdot, axis, pivot, limits, leverage
    joint_actuator.gd              # active envelope, clamp, paired torque
    passive_tissues.gd             # spring/tendon generalized torques
    contact_sample.gd
    contact_frame.gd
    observed_rigid_body.gd         # caches direct-state body/contact facts
    whole_body_state.gd
    sensor_frame_builder.gd        # mutable assembly -> frozen schema value
    support_snapshot.gd
    support_math.gd                # shared load/support/CoM geometry
    body_wrench.gd
    support_allocator.gd           # V1 vertical, V2 planar, V3 spatial
    energy_ledger.gd

  control/
    lab_control_context.gd         # read-only sensor capability + command sink
    command_sink.gd
    control_intent.gd
    control_arbiter.gd
    behavior_coordinator.gd
    stance_controller.gd
    brace_detector.gd
    brace_assessment.gd
    support_supervisor.gd
    brace_controller.gd
    fall_arrest_controller.gd
    pose_classifier.gd
    recovery_phase.gd
    recovery_controller.gd
    recovery_feasibility.gd

  rigs/
    stationary_body_rig.gd
    free_fall_rig.gd
    ballistic_rig.gd
    friction_sled_rig.gd
    tipping_prism_rig.gd
    foot_press_rig.gd
    loaded_hinge_rig.gd
    rail_leg_rig.gd
    stance_platform_rig.gd
    planar_tip_rig.gd
    catch_step_rig.gd
    recovery_pose_rig.gd

  run_lab.gd

tests/
  test_lab_spec_compiler.gd
  test_lab_schema_validator.gd
  test_lab_trace_store.gd
  test_lab_comparison_runner.gd
  test_lab_joint_binding.gd
  test_lab_joint_actuator.gd
  test_lab_passive_tissues.gd
  test_lab_contact_frame.gd
  test_lab_support_math.gd
  test_lab_loaded_hinge.gd
  test_lab_rail_leg.gd
  test_lab_stance_controller.gd
  test_lab_brace_detector.gd
  test_lab_planar_brace.gd
  test_lab_pose_classifier.gd
  test_lab_recovery_controller.gd
  test_lab_recovery_feasibility.gd

data/lab/
  experiments/
    L0_0_stationary_gravity_off_v1.tres
    L0_1_free_fall_v1.tres
    L0_2_ballistic_zero_g_v1.tres
    L0_3_observer_ab_v1.tres
    L0_4_trace_playback_v1.tres
    BR00_*.tres
  schemas/
    manifest_v1.schema.json
    frame_v1.schema.json
    command_v1.schema.json
    application_v1.schema.json
    event_v1.schema.json
    decision_v1.schema.json
    mechanics_v1.schema.json
    intervention_v1.schema.json
    comparison_v1.schema.json
    campaign_manifest_v1.schema.json
    child_run_index_v1.schema.json
    matrix_summary_v1.schema.json
    runtime_note_v1.schema.json
    process_metadata_v1.schema.json
    pre_event_entry_v1.schema.json
    summary_v1.schema.json
    checksums_v1.schema.json
  accepted/                       # selected compact evidence only
```

Godot's current test runner scans `tests/test_*.gd` rather than nested directories; see
[run_all_tests.ps1](../scripts/run_all_tests.ps1#L12-L13). This bootstrap therefore uses flat
`tests/test_lab_*.gd` files. A recursive-runner migration is a later, separate gate that first lists
every newly discovered script. Do not silently create tests that the suite never executes.

### 3.3 Runtime data flow

```text
ObservedRigidBody._integrate_forces
  -> immutable BodySample + ContactSample for tick N
  -> WholeBodyState
  -> BehaviorCoordinator selects exactly one active mode
       STANCE | GAIT | BRACE | FALL_ARREST | RECOVERY
  -> mode produces whole-body/contact/joint intents
  -> DecisionRecord seals detector terms, alternatives, selected strategy, desired wrench
  -> ControlArbiter resolves ownership and priorities
  -> PassiveTissues evaluates current q/qdot independently
  -> JointActuator applies active envelope and structural envelope
  -> CommandLedger records pre-clamp and post-clamp components
  -> paired torque is applied once for tick N+1
  -> InterventionExecutor applies declared non-joint fixture/disturbance operations
  -> observer records resulting state
  -> MechanicsAccountant compares predicted and realized momentum/energy/wrench
  -> TraceStore commits cross-linked immutable streams
```

The one-tick observation/control relationship must be explicit in the trace. A post-step contact
sample from tick \(N\) may inform commands for tick \(N+1\); the logger must not label it as a
pre-step fact from the same tick.

---

## 4. Core data contracts

Use immutable-per-tick snapshots. A controller must not read half of its state before the physics
step and half after it.

Mutable record `RefCounted` objects are allowed only while assembling a sample or command. Their
payload does not cross a seal boundary. (`JointBinding` remains executor-internal, and
`CommandSink` remains an intentionally append-only capability.) At the boundary, convert every
record builder to a recursively copied value tree
containing only:

```text
null, bool, int, float, String/StringName
Vector2/Vector3/Quaternion/Basis/Transform3D
recursively frozen Array
recursively frozen Dictionary with stable scalar keys
```

Do not place a `Node`, `Resource`, `RefCounted`, RID, callable, or mutable packed array in a sealed
frame. Stable IDs replace object references. This is a behavioral requirement, not merely a type
preference: changing a retained controller reference after sealing must be unable to change either
the executor input or the recorded hash.

Target file: `scripts/lab/frozen_value.gd`

```gdscript
class_name FrozenValue
extends RefCounted

static func snapshot(value: Variant) -> Variant:
    match typeof(value):
        TYPE_DICTIONARY:
            var source: Dictionary = value
            var copy: Dictionary = {}
            for key in source.keys():
                assert(_is_stable_key(key))
                copy[key] = snapshot(source[key])
            copy.make_read_only()
            return copy

        TYPE_ARRAY:
            var source: Array = value
            var copy: Array = []
            copy.resize(source.size())
            for i in source.size():
                copy[i] = snapshot(source[i])
            copy.make_read_only()
            return copy

        # Packed arrays do not offer the same recursive read-only boundary.
        # Convert them to an ordinary frozen Array for sealed records.
        TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, \
        TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, \
        TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, \
        TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, \
        TYPE_PACKED_COLOR_ARRAY, TYPE_PACKED_VECTOR4_ARRAY:
            return snapshot(Array(value))

        TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID:
            assert(false, "Runtime object crossed a sealed value boundary")
            return null

        _:
            # Scalars and Godot math value types copy by value.
            return value

static func _is_stable_key(key: Variant) -> bool:
    return typeof(key) in [
        TYPE_STRING,
        TYPE_STRING_NAME,
        TYPE_INT,
    ]
```

`CanonicalJson.encode()` then sorts dictionary keys recursively, uses a fixed float policy, rejects
non-finite values, and produces the bytes used for both the trace and SHA-256. Godot dictionary
insertion order is not the scientific canonicalization rule. Every value-producing boundary must
therefore run `FiniteSanitizer` **before** canonical encoding, sealing, or a physics mutation; frame
capture is only one of those boundaries.

### 4.1 `BodySample`

```gdscript
class_name BodySample
extends RefCounted

var physics_step_id: int
var body_callback_sequence: int
var capture_epoch: int
var sample_phase: StringName       # registry value from Section 14.3

var body_id: StringName
var part_index: int
var transform: Transform3D
var center_of_mass_world: Vector3
var linear_velocity: Vector3
var angular_velocity: Vector3

var mass_kg: float
var inverse_inertia_tensor_world: Basis
var sleeping: bool
var finite: bool
```

`sample_phase` is mandatory because a callback sample and a post-`physics_frame` sample are not the
same temporal fact.

The direct-state CoM fields have easy-to-miss semantics. `state.center_of_mass` is the offset from
the body origin expressed in global coordinates; it is not the absolute world point.

```gdscript
sample.transform = state.transform
sample.center_of_mass_world = (
    state.transform.origin + state.center_of_mass)

# Independent frame oracle for the same world point.
var com_from_local := (
    state.transform * state.center_of_mass_local)
assert(
    sample.center_of_mass_world.distance_to(com_from_local)
    <= com_frame_tolerance_m)

# Godot's Vector3 `inverse_inertia` is not the tensor.
sample.inverse_inertia_tensor_world = (
    state.inverse_inertia_tensor)
```

The observer rejects a non-finite CoM, disagreement between these expressions, or an unavailable
tensor before whole-body aggregation.

### 4.2 `JointBinding`

`JointBinding` is stable for the life of a rig. It replaces loose dictionaries distributed across
controllers.

```gdscript
class_name JointBinding
extends RefCounted

var joint_id: StringName
var part_index: int
var parent_body_id: StringName
var child_body_id: StringName

var parent_body: RigidBody3D
var child_body: RigidBody3D
var hinge_node: HingeJoint3D

# Current axis is reconstructed from this every tick.
var axis_parent_local: Vector3

# The same directed physical axis, authored in both body-local frames.
var axis_child_local: Vector3
var rest_child_rotation_parent_local: Quaternion

var pivot_parent_local: Vector3
var pivot_child_local: Vector3

var limit_enabled: bool
var lower_limit_rad: float
var upper_limit_rad: float
var requires_unwrapped_angle: bool
var initial_turn_index: int

var actuator: ActuatorSpec
var spring: SpringDef
var tendon_ids: Array[StringName]
```

The current code already constructs most of this metadata between
[creature_body.gd:183-197](../scripts/sim/creature_body.gd#L183-L197) and
[cpg_controller.gd:448-484](../scripts/sim/cpg_controller.gd#L448-L484). The new implementation
centralizes it instead of reconstructing slightly different versions in each controller.

### 4.3 `JointState`

```gdscript
class_name JointState
extends RefCounted

var tick: int
var capture_epoch: int
var sample_phase: StringName
var unwrap_segment_id: int
var joint_id: StringName

var angle_rad: float
var wrapped_angle_rad: float
var unwrapped_angle_available: bool
var angular_velocity_rad_s: float
var axis_world: Vector3
var pivot_world: Vector3

var lower_limit_rad: float
var upper_limit_rad: float
var distance_to_lower_rad: float
var distance_to_upper_rad: float
var limit_active: bool
var angle_is_unwrapped: bool

var pivot_parent_world: Vector3
var pivot_child_world: Vector3
var pivot_separation_m: float
var pivot_valid: bool

var contact_jacobian_columns: Dictionary = {}
var minimum_leverage_m: float
var finite: bool
var complete: bool
var invalid_reason: StringName
```

Authoritative update:

```gdscript
static func sample(
        binding: JointBinding,
        parent: BodySample,
        child: BodySample,
        previous: JointState,
        pivot_tolerance_m: float,
        axis_tolerance: float,
        allow_unwrap_initialization: bool,
        unwrap_segment_id: int) -> JointState:
    var out := JointState.new()
    out.tick = parent.physics_step_id
    out.capture_epoch = parent.capture_epoch
    out.sample_phase = parent.sample_phase
    out.unwrap_segment_id = unwrap_segment_id
    out.joint_id = binding.joint_id

    if (
            not parent.finite
            or not child.finite
            or parent.body_id != binding.parent_body_id
            or child.body_id != binding.child_body_id
            or parent.physics_step_id != child.physics_step_id
            or parent.capture_epoch != child.capture_epoch
            or parent.sample_phase != child.sample_phase):
        out.finite = false
        out.invalid_reason = &"JOINT_BODY_SAMPLE_FRAME_MISMATCH"
        return out

    var axis_parent := binding.axis_parent_local
    var axis_child := binding.axis_child_local
    if (
            not axis_parent.is_finite()
            or not axis_child.is_finite()
            or axis_parent.length_squared() <= 1.0e-12
            or axis_child.length_squared() <= 1.0e-12):
        out.finite = false
        out.invalid_reason = &"HINGE_AXIS_INVALID"
        return out

    axis_parent = axis_parent.normalized()
    axis_child = axis_child.normalized()
    var axis_parent_from_child := (
        Basis(binding.rest_child_rotation_parent_local) * axis_child
    ).normalized()
    if axis_parent.dot(axis_parent_from_child) < 1.0 - axis_tolerance:
        out.finite = false
        out.invalid_reason = &"HINGE_AXIS_FRAME_MISMATCH"
        return out

    var parent_basis := parent.transform.basis
    var child_basis := child.transform.basis
    if not SupportMath.basis_is_orthonormal(parent_basis):
        out.finite = false
        out.invalid_reason = &"PARENT_BASIS_NOT_RIGID"
        return out
    if not SupportMath.basis_is_orthonormal(child_basis):
        out.finite = false
        out.invalid_reason = &"CHILD_BASIS_NOT_RIGID"
        return out

    var axis_world := (
        parent_basis * axis_parent
    ).normalized()

    # relative and delta_from_rest are both expressed in the parent frame.
    # Reversing this multiplication yields a child-rest-frame delta and is
    # wrong for a noncommuting rest orientation.
    var relative := parent_basis.get_rotation_quaternion().inverse() \
        * child_basis.get_rotation_quaternion()
    var delta_from_rest := relative \
        * binding.rest_child_rotation_parent_local.inverse()
    var q_wrapped := JointKinematics.twist_angle(
        delta_from_rest,
        axis_parent)
    var qdot := (
        child.angular_velocity.dot(axis_world)
        - parent.angular_velocity.dot(axis_world))
    var needs_unwrapped := binding.requires_unwrapped_angle
    var q_unwrapped := NAN
    var unwrapped_available := not needs_unwrapped
    if needs_unwrapped:
        if previous == null:
            if not allow_unwrap_initialization:
                out.finite = false
                out.invalid_reason = &"UNWRAPPED_ANGLE_STREAM_DISCONTINUITY"
                return out
            q_unwrapped = (
                q_wrapped
                + TAU * binding.initial_turn_index)
            unwrapped_available = is_finite(q_unwrapped)
        elif (
                not previous.finite
                or previous.joint_id != binding.joint_id
                or previous.tick != out.tick - 1
                or previous.capture_epoch != out.capture_epoch - 1
                or previous.sample_phase != out.sample_phase
                or previous.unwrap_segment_id != out.unwrap_segment_id):
            out.finite = false
            out.invalid_reason = &"UNWRAPPED_ANGLE_STREAM_DISCONTINUITY"
            return out
        else:
            var shortest_delta := wrapf(
                q_wrapped - previous.wrapped_angle_rad, -PI, PI)
            var rate_integral := 0.5 * (
                previous.angular_velocity_rad_s + qdot) * parent.step_s
            var witnessed_delta := JointKinematics.closest_tau_branch(
                shortest_delta, rate_integral)
            if (
                    absf(witnessed_delta - rate_integral)
                        > binding.unwrap_rate_witness_tolerance_rad
                    or absf(witnessed_delta)
                        > binding.max_tick_rotation_rad):
                unwrapped_available = false
                out.invalid_reason = &"WRAPPED_ANGLE_AMBIGUOUS"
            else:
                q_unwrapped = previous.angle_rad + witnessed_delta
                unwrapped_available = is_finite(q_unwrapped)

    var pivot_parent := (
        parent.transform * binding.pivot_parent_local)
    var pivot_child := (
        child.transform * binding.pivot_child_local)
    var pivot_separation := pivot_parent.distance_to(pivot_child)

    out.wrapped_angle_rad = q_wrapped
    out.unwrapped_angle_available = unwrapped_available
    out.angle_rad = (
        q_unwrapped if needs_unwrapped and unwrapped_available else q_wrapped)
    out.angular_velocity_rad_s = qdot
    out.axis_world = axis_world
    out.angle_is_unwrapped = needs_unwrapped and unwrapped_available
    out.pivot_parent_world = pivot_parent
    out.pivot_child_world = pivot_child
    out.pivot_separation_m = pivot_separation
    out.pivot_valid = pivot_separation <= pivot_tolerance_m
    out.pivot_world = 0.5 * (pivot_parent + pivot_child)
    out.lower_limit_rad = binding.lower_limit_rad
    out.upper_limit_rad = binding.upper_limit_rad
    out.distance_to_lower_rad = out.angle_rad - binding.lower_limit_rad
    out.distance_to_upper_rad = binding.upper_limit_rad - out.angle_rad
    out.limit_active = (
        binding.limit_enabled
        and minf(
            out.distance_to_lower_rad,
            out.distance_to_upper_rad) <= 0.01)
    out.finite = (
        is_finite(q_wrapped)
        and is_finite(qdot)
        and axis_world.is_finite()
        and out.pivot_world.is_finite()
        and out.pivot_valid)
    out.complete = out.finite and (not needs_unwrapped or unwrapped_available)
    if not out.pivot_valid:
        out.invalid_reason = &"HINGE_PIVOT_SEPARATION"
    return out
```

Tests must rotate the parent through several world orientations while preserving the same relative
joint angle. `angle_rad`, `qdot`, and the torque direction must remain coherent. Add a branch-cut
test that crosses \(+\pi\) to \(-\pi\), plus a deliberately mismatched parent/child anchor test that
must invalidate the sample instead of silently selecting one body's pivot. For a morphology whose
legal range can cross the wrapped-angle branch cut, the compiled binding supplies the authored
initial turn index. Initialization is allowed only at the first accepted sample of a declared
`unwrap_segment_id`, while the fixture is in a known/scaffolded authored configuration. Subsequent
samples unwrap only from the immediately previous valid same-stream sample. A dropped/invalid
sample, skipped tick, epoch discontinuity, phase change, joint mismatch, or segment change produces
`UNWRAPPED_ANGLE_STREAM_DISCONTINUITY`; it does **not** silently choose turn zero. Restarting requires
a new declared segment and a re-established authored configuration. Tests also inject invalid body
samples, zero axes, inconsistent parent/child rest axes, mixed physics steps, capture epochs, sample
phases, skipped ticks, and cross-segment prior states.

The concrete `joint_state_v2` serializer uses `null` for an unavailable
unwrapped value and records `availability`, `invalid_reasons`, `finite`, and
`complete` separately. Therefore an unwrap ambiguity can leave the independently
observed wrapped angle, current axis, anchors, and projected angular rate finite
while making the requested continuous-angle channel unavailable and the sample
incomplete. Consumers that require continuous angle must gate on both
`unwrapped_angle_available` and `complete`; they must never substitute the
wrapped value as though it carried the missing turn count.

### 4.4 `ContactSample`

```gdscript
class_name ContactSample
extends RefCounted

var physics_step_id: int
var body_callback_sequence: int
var capture_epoch: int
var sample_phase: StringName
var contact_key: StringName

var body_id: StringName
var other_id: StringName
var local_shape_index: int
var other_shape_index: int

var point_world: Vector3
var other_point_world: Vector3
var point_body_local: Vector3
var normal_world: Vector3
var normal_frame_source: StringName # jolt_world_backend | adapter_converted_world
var normal_available: bool
var normal_quality: StringName      # backend_pinned | oracle_validated | invalid
var relative_velocity_world: Vector3
var tangential_velocity_world: Vector3
var tangential_velocity_available: bool
var tangential_velocity_quality: StringName

var impulse_world: Vector3
var impulse_available: bool
var impulse_quality: StringName   # exposed_estimate | residual_inferred | unavailable

var contact_age_ticks: int
var role: StringName              # support_effector | body | scaffold | obstacle
var ownership: StringName         # creature_environment | same_creature_internal
var canonical_pair_side: bool
var near_ground: bool
var contact_present: bool
var bearing: bool
```

Godot 4.7 requires contact monitoring and a positive `max_contacts_reported` for direct-state
contact count to be populated. With Jolt, exposed contact impulses are estimates and may be
inaccurate when either body participates in several simultaneous collisions. Therefore:

- do not name the channel `exact_impulse`;
- preserve `impulse_quality`;
- compare exposed estimates to whole-system momentum residuals;
- never turn `unavailable` into numeric zero.

### 4.5 `WholeBodyState`

```gdscript
class_name WholeBodyState
extends RefCounted

var tick: int
var total_mass_kg: float
var center_of_mass_world: Vector3
var center_of_mass_velocity_world: Vector3
var linear_momentum_world: Vector3
var angular_momentum_about_com_world: Vector3
var angular_momentum_available: bool
var angular_momentum_quality: StringName
var angular_momentum_unavailable_reason: StringName
var gravity_world_m_s2: Vector3

var root_basis_world: Basis
var anatomical_up_world: Vector3
var anatomical_forward_world: Vector3
var anatomical_right_world: Vector3
var root_angular_velocity_world: Vector3
var root_inertia_world: Basis
var root_inertia_available: bool
var root_is_whole_body: bool
var kinetic_energy_j: float
var gravitational_potential_energy_j: float
var energy_available: bool

var support_height_m: float
var support_height_velocity_m_s: float
var support_height_available: bool
var anatomical_axes_available: bool
var support_contacts: Array[ContactSample]
var support_polygon_plane_uv: PackedVector2Array
var support_margin_m: float
var capture_margin_m: float

var body_contacts: Array[ContactSample]
var contact_regions: Array[StringName]
var has_foot_support: bool
var pose_class: StringName
var finite: bool
```

Aggregate the body samples, rather than treating root state as whole-body state:

\[
M=\sum_b m_b,\qquad
C=\frac{1}{M}\sum_b m_b c_b,\qquad
P=\sum_b m_bv_b,\qquad
V_C=\frac{P}{M}
\]

\[
L_C
=
\sum_b
\left[
I_b^W\omega_b
+
(c_b-C)\times m_bv_b
\right]
\]

\[
K
=
\sum_b
\left[
\frac12m_b\|v_b\|^2
+
\frac12\omega_b^\mathsf{T}I_b^W\omega_b
\right]
\]

\[
U_g=-\sum_bm_b\,g^W\cdot c_b
\]

The gravitational datum is fixed in the expanded experiment so \(\Delta U_g\), rather than an
arbitrary absolute value, is portable. `PhysicsDirectBodyState3D.inverse_inertia` is a `Vector3` of
principal inverse inertia, while `inverse_inertia_tensor`/`get_inverse_inertia_tensor()` is the
world-space `Basis` tensor used here. Invert that tensor only after checking availability,
finiteness, determinant, locked axes, and any fixture-imposed rotation constraints. If it is
singular or unavailable, mark rotational energy and angular momentum unavailable; never substitute
identity or zero.

`angular_momentum_available` is true only when every body contribution required for the declared
whole system is available in the same frame. `angular_momentum_quality` records
`engine_tensor_aggregate`, `exact_rigid_composite`, or another versioned estimator; the reason names
the first missing/singular body channel. The orbital term alone is never mislabeled as total
angular momentum. A `root_is_whole_body` fixture may supply the exact rigid-composite alternate
channel, but only with its own availability/provenance and a fixture assertion.

`support_height_m` should be the center-of-mass or authored pelvis reference measured along world up
from the current support plane. It must not assume that the root body's Y coordinate universally
means upright height.

### 4.6 `JointTorqueCommand`

```gdscript
class_name JointTorqueCommand
extends RefCounted

var tick: int
var behavior_state: StringName
var joint_id: StringName
var source_id: StringName

var active_components: Dictionary[StringName, float] = {}
var passive_components: Dictionary[StringName, float] = {}

var requested_active_nm: float
var rate_limited_active_nm: float
var applied_active_nm: float
var requested_passive_nm: float
var applied_passive_nm: float
var total_pre_structure_nm: float
var structural_guard_reaction_nm: float
var applied_total_nm: float

var structural_cap_nm: float
var active_saturated: bool
var structural_saturated: bool
var torque_rate_limited: bool
var speed_limited: bool
var power_limited: bool
var selected_work_regime: StringName
var limit_causes: Array[StringName]

var activation_previous: float
var activation_requested: float
var activation_applied: float
var activation_next: float
var activation_update_phase: StringName

var active_lower_bound_nm: float
var active_upper_bound_nm: float
var angle_rad: float
var angular_velocity_rad_s: float
var axis_world: Vector3
var pivot_world: Vector3

var active_power_w: float
var passive_power_w: float
var structural_guard_power_w: float
var applied_total_power_w: float
```

The expected active component keys include:

```text
stance.body_wrench
stance.height
stance.orientation
stance.impedance
gravity.distal
brace.load
brace.catch
brace.damping
recovery.roll
recovery.plant
recovery.rise
gait.stance
gait.swing
```

The expected passive keys include:

```text
spring.<spring-id>
tendon.<tendon-id>
passive_damping.<joint-id>
soft_limit.lower
soft_limit.upper
```

### 4.7 `ControlIntent`

The current `DriveIntent` stores one target, weight, TTL, and source at
[drive_intent.gd:1-21](../scripts/sim/drive_intent.gd#L1-L21). That is too weak for whole-body
ownership.

```gdscript
class_name ControlIntent
extends RefCounted

enum Mode {
    STANCE,
    GAIT,
    BRACE,
    FALL_ARREST,
    RECOVERY,
    SAFE_DAMP,
}

const PRIORITY_GAIT := 100
const PRIORITY_STANCE := 200
const PRIORITY_RECOVERY := 300
const PRIORITY_BRACE := 400
const PRIORITY_FALL_ARREST := 500

var tick: int
var mode: Mode
var source: StringName
var priority: int
var valid_until_tick: int
var feasible := true

var desired_wrench: BodyWrench = BodyWrench.new()
var desired_contact_forces: Dictionary = {}
var desired_contact_targets: Dictionary = {}
var desired_joint_torques: Dictionary = {}
var joint_preferences: Dictionary = {}
var contact_plan: Dictionary = {}

var required_contacts: Array[StringName] = []
var forbidden_liftoffs: Array[StringName] = []
var reason: StringName
var diagnostics: Dictionary = {}
```

Only one active behavior owns a joint at a time in V1:

```text
FALL_ARREST > BRACE > RECOVERY > STANCE > GAIT
```

Passive tissues remain active regardless of behavior. `SAFE_DAMP` is the fallback when the active
task is infeasible or non-finite.

This explicit ownership prevents gait torque and brace torque from fighting inside one final clamp.

### 4.8 `SensorFrame` schema and builder

The controller reads one immutable aggregate, never a mixture of node state queried at different
times:

```gdscript
class_name SensorFrameBuilder
extends RefCounted

var frame_id: int
var physics_time_s: float
var sample_phase: StringName
var experiment_phase: StringName
var release_frame_id: int
var whole_body: WholeBodyState
var bodies_by_id: Dictionary = {}
var joints_by_id: Dictionary = {}
var contacts_by_id: Dictionary = {}
var support: SupportSnapshot
var availability: Dictionary = {}
var finite := true
```

The runner freezes a frame before controller dispatch. In development builds, attempts to mutate its
arrays/dictionaries after sealing should assert.

The controller-visible frame is the deep-frozen `Dictionary` returned by
`SensorFrameBuilder.seal()`, validated against `frame_v1.schema.json`. `SensorFrame` remains the
schema/concept name used in equations and method signatures; it is not a mutable runtime payload.
For readability, later controller snippets accept typed `WholeBodyState`/`SupportSnapshot` views;
the production views are getter-only projections of this frozen value and contain no nodes or
mutable record references.

### 4.9 `SupportSnapshot`

```gdscript
class_name SupportSnapshot
extends RefCounted

var tick: int
var contact_ids: Array[StringName] = []
var bearing_contact_ids: Array[StringName] = []
var support_plane_origin_world: Vector3
var support_plane_normal_world: Vector3
var support_tangent_u_world: Vector3
var support_tangent_v_world: Vector3
var support_polygon_plane_uv: PackedVector2Array
var support_geometry_kind: StringName # empty | point | segment | polygon
var center_of_pressure_world: Vector3

var has_bearing_support := false
var static_margin_m: float
var capture_margin_m: float
var friction_margin_min: float
var load_capacity_margin_n: float
var support_map_rank: int
var support_map_condition: float
var valid := false
var invalid_reason: StringName
```

`has_bearing_support` is derived from confirmed `BEARING` contacts. It is not set from foot height.

### 4.10 `BraceAssessment`

The detector publishes its entire reasoning to the supervisor:

```gdscript
class_name BraceAssessment
extends RefCounted

var tick: int
var safe := false
var precarious := false
var requires_new_contact := false
var imminent_impact := false
var is_fallen := false
var upright_and_supported := false

var static_margin_m: float
var capture_margin_m: float
var time_to_boundary_s: float
var time_to_impact_s: float
var actuator_reserve_fraction: float
var friction_reserve_fraction: float
var allocator_residual_norm: float
var urgency_terms: Dictionary = {}
var urgency: float

var safe_confirm_ticks := 8
var stable_confirm_ticks := 30
var best_arrest_contact_plan: Dictionary = {}
var strategy_reason: StringName
var recovery_ready := false
var recovery_infeasible := false
var recovery_reason: StringName
```

### 4.11 `CommandSink` and `RecoveryEvent`

`CommandSink` is the only capability a controller can use to submit commands:

```gdscript
class_name CommandSink
extends RefCounted

var tick: int
var sealed := false
var sealed_sha256: String
var _builders: Array[ControlIntent] = []
var _sealed_values: Array = []

func submit(intent: ControlIntent) -> void:
    assert(not sealed)
    assert(intent.tick == tick)
    _builders.append(intent)

func seal() -> Array:
    assert(not sealed)
    for intent in _builders:
        _sealed_values.append(
            FrozenValue.snapshot(intent.to_value_dictionary()))
    _builders.clear()
    _sealed_values.make_read_only()
    sealed_sha256 = CanonicalJson.sha256(_sealed_values)
    sealed = true
    return _sealed_values
```

`SensorFrame` uses the same conversion: assemble mutable DTOs, call `to_value_dictionary()` on each,
deep-snapshot the result, compute `frame_sha256`, and give controllers only that sealed tree.
Development tests retain references to every builder, mutate them after sealing, and require:

```text
sealed hash unchanged
serialized bytes unchanged
executor input unchanged
write through sealed Array/Dictionary raises an assertion/error
```

`RecoveryEvent` is a small observation result, not a body mutation:

```gdscript
class_name RecoveryEvent
extends RefCounted

var kind: StringName = &"none"
var phase_id: StringName
var reason: StringName
var evidence: Dictionary = {}

static func none() -> RecoveryEvent:
    return RecoveryEvent.new()
```

---

## 5. Authored actuator model

### 5.1 Why an explicit actuator comes first

The first actuator experiments need a declared physical input:

```text
this joint can hold 80 N·m at zero speed
```

That makes the loaded-hinge prediction falsifiable. Anatomy-derived strength can be introduced after
the pipeline is certified.

### 5.2 Proposed `ActuatorSpec`

```gdscript
class_name ActuatorSpec
extends Resource

@export_group("Active envelope")
@export var enabled: bool = true
@export var max_isometric_torque_nm: float = 80.0
@export var no_load_speed_rad_s: float = 12.0
@export var max_positive_power_w: float = 600.0
@export var max_absorption_power_w: float = 600.0
@export var max_eccentric_multiplier: float = 1.25

@export_group("Activation dynamics")
@export var activation_time_s: float = 0.050
@export var deactivation_time_s: float = 0.080
@export var max_torque_rate_nm_s: float = 1600.0

@export_group("Structure")
@export var structural_torque_limit_nm: float = 180.0
@export var tear_dwell_s: float = 0.050

@export_group("Derivation metadata")
@export var capacity_source: StringName = &"explicit_lab"
@export var muscle_pcsa_m2: float = 0.0
@export var specific_tension_pa: float = 0.0
@export var moment_arm_m: float = 0.0
```

No-muscle behavior becomes explicit:

```text
enabled=false                 -> no active torque
capacity_source=explicit_lab  -> lab calibration value
capacity_source=anatomy       -> derived from muscle geometry
capacity_source=legacy        -> old formula, allowed only in legacy adapter
```

There is no universal hidden baseline actuator.

`SpecCompiler` rejects—not repairs—any non-finite or out-of-domain actuator value:

| Field | Accepted domain | Zero semantics |
|---|---|---|
| `max_isometric_torque_nm` | \(\ge 0\) | valid no-active-strength negative control |
| `no_load_speed_rad_s` | \(>\omega_\epsilon\) | invalid |
| `max_eccentric_multiplier` | \(\ge 1\) | no eccentric boost |
| activation/deactivation time | \(>0\) | invalid |
| `max_torque_rate_nm_s` | \(\ge 0\) | torque cannot change |
| positive/absorption power cap | \(\ge 0\) | exactly zero disables that cap |
| `structural_torque_limit_nm` | \(\ge 0\) | valid zero-capacity structure control |
| `tear_dwell_s` | \(\ge 0\) | immediate declared tear threshold |

An enabled zero-torque actuator is legitimate experimental anatomy. Negative values, NaN/Inf,
sub-epsilon no-load speed, or a sub-unity eccentric multiplier are configuration errors. Runtime
epsilons protect a mathematically valid division; they never manufacture capacity or silently
rewrite scientific input.

### 5.3 Initial active envelope

For the first bidirectional lab motor, define the work regime from the torque candidate that is
actually being resolved:

\[
P_{\text{candidate}}
=
\tau_{\text{rate-limited}}\dot q
\]

Positive work uses \(P_{\text{candidate}}>0\); negative work/braking uses
\(P_{\text{candidate}}<0\). Request direction may choose excitation, but it never chooses the legal
speed/power envelope after torque-rate limiting. In the positive-work regime:

\[
\tau_{\text{speed,+}}
=
\tau_{\text{iso}}
\max\left(
0,
1-\frac{|\dot q|}{\dot q_{\text{no-load}}}
\right)
\]

At and above the declared no-load speed, positive-work capacity is therefore zero. During negative
work/braking, use a deliberately simple bounded eccentric curve:

\[
\tau_{\text{speed,-}}
=
\tau_{\text{iso}}
\min
\left(
m_{\text{ecc,max}},
1+0.25\frac{|\dot q|}{\dot q_{\text{no-load}}}
\right)
\]

The corresponding positive-output or negative-absorption power limit is:

\[
\tau_{\text{power}}
=
\frac{P_{\max}}{\max(|\dot q|,\omega_\epsilon)}
\]

but only when \(|\dot q|>\omega_\epsilon\). At zero speed, mechanical power is zero and the power
cap is infinite; static capacity is controlled by isometric torque. A configured power value
equal to zero disables that particular power cap during early torque-only experiments. A negative
power value is invalid configuration.

\[
\tau_{\max}
=
a
\min(\tau_{\text{speed}},\tau_{\text{power}})
\]

Where \(a\in[0,1]\) is the activation state.

This V1 curve is not claimed to be a complete Hill-type muscle model. It provides separately
testable hold torque, speed, power, and activation effects.

Cause and effect:

| Parameter | Raising it does | It does not do |
|---|---|---|
| `max_isometric_torque_nm` | Raises slow/holding load capacity | Improve contact sensing or choose a brace |
| `no_load_speed_rad_s` | Preserves torque at higher joint speed | Increase zero-speed holding strength |
| `max_positive_power_w` | Allows more positive torque-speed product | Change static hold when \(\dot q\approx0\) |
| `max_absorption_power_w` | Allows stronger/faster active braking | Add passive damping or contact impulse |
| `activation_time_s` | Slows how quickly full force appears | Change final static capacity |
| `max_torque_rate_nm_s` | Reduces impulsive command changes | Guarantee enough fall-arrest time |
| `structural_torque_limit_nm` | Raises non-tearing total load | Create active work |

### 5.4 Activation update

V1 derives requested activation from requested torque and the full-activation directional capacity
at the current speed:

\[
a_\text{requested}
=
\operatorname{clamp}
\left(
\frac{|\tau_\text{requested}|}
{\tau_{\text{direction},a=1}+\epsilon},
0,1
\right)
\]

When the requested direction has zero capacity and the request is nonzero, request activation
\(1\) and let the directional torque bound report infeasibility. A later antagonist-muscle model
may expose separate flexor/extensor excitations; it must not silently reinterpret this one-motor
state.

For command \(N\), which acts over transition \(N\rightarrow N+1\), integrate the first-order
activation analytically. Store the endpoint for the next tick and use the interval mean to bound
the torque applied during this transition:

```gdscript
static func activation_step(
        current: float,
        requested: float,
        dt: float,
        spec: ActuatorSpec) -> Dictionary:
    var target := clampf(requested, 0.0, 1.0)
    var tau := (
        spec.activation_time_s
        if target > current
        else spec.deactivation_time_s)
    assert(tau > 0.0) # SpecCompiler already proved the domain.
    var decay := exp(-dt / tau)
    var next := target + (current - target) * decay
    var mean := next
    if dt > 1.0e-9:
        mean = (
            target
            + (current - target)
            * (tau / dt)
            * (1.0 - decay))
    return {
        "activation_previous": current,
        "activation_requested": target,
        "activation_applied": clampf(mean, 0.0, 1.0),
        "activation_next": clampf(next, 0.0, 1.0),
        "activation_update_phase": &"transition_mean",
    }
```

Activation delay becomes important in fall arrest: a theoretically strong limb can still be too
slow to reach force before impact. The actuator state for tick \(N+1\) is
`activation_next`; it is not ambiguously reused as though it existed throughout the previous
transition.

### 5.5 Directional capacity bounds

```gdscript
static func _capacity_for_work_sign_nm(
        activation: float,
        omega_rad_s: float,
        negative_work: bool,
        spec: ActuatorSpec) -> Dictionary:
    if not spec.enabled:
        return {"cap_nm": 0.0, "speed_limited": false, "power_limited": false}

    assert(spec.no_load_speed_rad_s > 0.001)
    assert(spec.max_isometric_torque_nm >= 0.0)
    assert(spec.max_eccentric_multiplier >= 1.0)
    var speed_ratio := (
        absf(omega_rad_s)
        / spec.no_load_speed_rad_s)
    var speed_factor := clampf(1.0 - speed_ratio, 0.0, 1.0)
    if negative_work:
        speed_factor = minf(
            spec.max_eccentric_multiplier,
            1.0 + 0.25 * speed_ratio)

    var speed_cap := (
        spec.max_isometric_torque_nm
        * speed_factor)
    var selected_power_w := (
        spec.max_absorption_power_w
        if negative_work
        else spec.max_positive_power_w)
    var power_cap := INF
    if selected_power_w > 0.0 and absf(omega_rad_s) > 0.001:
        power_cap = selected_power_w / absf(omega_rad_s)
    var cap := (
        minf(speed_cap, power_cap)
        * clampf(activation, 0.0, 1.0))
    var binding_tolerance := 1.0e-9

    return {
        "cap_nm": cap,
        "speed_limited": speed_cap <= power_cap + binding_tolerance,
        "power_limited": power_cap <= speed_cap + binding_tolerance,
    }

static func active_bounds_nm(
        activation: float,
        omega_rad_s: float,
        spec: ActuatorSpec) -> Dictionary:
    var positive_work := _capacity_for_work_sign_nm(
        activation, omega_rad_s, false, spec)
    var negative_work := _capacity_for_work_sign_nm(
        activation, omega_rad_s, true, spec)

    var lower_nm: float
    var upper_nm: float
    var omega_epsilon := 0.001
    if omega_rad_s > omega_epsilon:
        # +tau drives; -tau brakes.
        lower_nm = -float(negative_work["cap_nm"])
        upper_nm = float(positive_work["cap_nm"])
    elif omega_rad_s < -omega_epsilon:
        # -tau drives; +tau brakes.
        lower_nm = -float(positive_work["cap_nm"])
        upper_nm = float(negative_work["cap_nm"])
    else:
        var isometric := (
            clampf(activation, 0.0, 1.0)
            * spec.max_isometric_torque_nm)
        lower_nm = -isometric
        upper_nm = isometric

    return {
        "lower_nm": lower_nm,
        "upper_nm": upper_nm,
        "positive_work": positive_work,
        "negative_work": negative_work,
    }
```

The eccentric sign logic is an acknowledged V1 approximation for a bidirectional joint motor. Its
tests validate the declared curve, not physiological realism. Required envelope cases include zero
speed, just below/at/above no-load speed, positive versus negative mechanical work, both power
limits, and torque reversals in both velocity directions. Capacity is chosen from the sign of the
**rate-limited candidate actually being applied**, never merely from the earlier requested sign.

### 5.6 Anatomy-derived capacity later

The later derivation target is:

\[
F_{\max}
=
\sigma_{\text{specific}}
A_{\text{PCSA}}
\]

\[
\tau_{\text{iso}}
=
F_{\max}r_{\text{moment arm}}
\]

Where:

- \(\sigma_{\text{specific}}\) is muscle-specific tension;
- \(A_{\text{PCSA}}\) is physiological cross-sectional area;
- \(r_{\text{moment arm}}\) is the effective joint moment arm.

Scaling consequences:

- muscle volume alone is not force;
- longer muscle fibers can permit excursion/speed without proportionally increasing force;
- greater PCSA raises force;
- greater moment arm raises torque but reduces angular excursion/speed for a given fiber excursion;
- body mass and lever lengths raise required torque;
- distal inertia affects acceleration and feedback gains.

The authoring system may estimate these values, but runtime control should consume the compiled
`ActuatorSpec`. That keeps authored biology and physical execution separable.

---

## 6. Unified torque pipeline

### 6.1 Required order

For each physics tick and each joint:

```text
1. sample current q, qdot, axis, pivot, and limits
2. evaluate every passive spring/tendon contribution
3. select exactly one active behavior owner
4. decompose the owner's active torque request by source
5. update activation
6. enforce torque-rate, torque-speed, and power limits
7. sum active and passive torque
8. enforce structural limit
9. record the sealed command
10. apply equal-and-opposite torque once
```

No controller gets a private shortcut around this pipeline.

### 6.2 Passive spring

For joint deflection \(x=q-q_0\):

\[
\tau_s = -kx-c\dot q
\]

\[
E_s = \frac12kx^2
\]

\[
P_\text{damper} = -c\dot q^2 \le 0
\]

The spring is evaluated in air and on the ground. Contact determines what external reaction exists;
it does not switch internal anatomy on and off.

```gdscript
static func spring_torque(
        state: JointState,
        spring: SpringDef) -> Dictionary:
    if spring == null or not spring.enabled:
        return {"torque_nm": 0.0, "energy_j": 0.0, "damping_power_w": 0.0}

    var k := maxf(spring.stiffness, 0.0)
    var q0 := spring.rest_angle_rad
    var x := state.angle_rad - q0

    var c_nm_s_rad := maxf(
        spring.damping_nm_s_per_rad, 0.0)
    var elastic := -k * x
    var damping := -c_nm_s_rad * state.angular_velocity_rad_s

    return {
        "torque_nm": elastic + damping,
        "elastic_nm": elastic,
        "damping_nm": damping,
        "energy_j": 0.5 * k * x * x,
        "damping_power_w": (
            damping * state.angular_velocity_rad_s),
    }
```

The existing `efficiency` return multiplier can remain in the legacy adapter. The certified model
should use physical damping for loss, because multiplying only the return stroke changes the force
law and complicates the energy ledger. Add `rest_angle_rad` and `damping_nm_s_per_rad` to the
versioned certified spring resource immediately. Migration from the current dimensionless
`damping` field is an explicit, versioned conversion:

```text
legacy SpringDef version
+ declared conversion rule and units
-> CertifiedSpringSpec version
```

Do not silently reinterpret existing resource numbers as SI damping.

### 6.3 Conservative tendon coupling

For a two-joint tendon:

\[
\delta
=
(q_1-q_{1,0})
- r(q_2-q_{2,0})
- \delta_0
\]

\[
E_t = \frac12k_t\delta^2
\]

\[
\tau_1 = -k_t\delta-c_t\dot\delta
\]

\[
\tau_2 = r(k_t\delta+c_t\dot\delta)
\]

These are generalized torques derived from one shared potential. They must be queued into the same
joint pipeline instead of directly applying four body torques inside the tendon module.

```gdscript
static func tendon_pair(
        a: JointState,
        b: JointState,
        ratio: float,
        rest_a: float,
        rest_b: float,
        rest_offset: float,
        stiffness: float,
        damping: float) -> Dictionary:
    var delta := (
        (a.angle_rad - rest_a)
        - ratio * (b.angle_rad - rest_b)
        - rest_offset)
    var delta_dot := (
        a.angular_velocity_rad_s
        - ratio * b.angular_velocity_rad_s)
    var generalized := (
        stiffness * delta
        + damping * delta_dot)

    return {
        "joint_a_nm": -generalized,
        "joint_b_nm": ratio * generalized,
        "energy_j": 0.5 * stiffness * delta * delta,
        "damping_power_w": -damping * delta_dot * delta_dot,
    }
```

### 6.4 Active/passive and structural clamps

Active muscle and total structure have different limits:

```gdscript
static func resolve_torque(
        active_components: Dictionary,
        passive_components: Dictionary,
        previous_active_nm: float,
        previous_activation: float,
        state: JointState,
        dt: float,
        spec: ActuatorSpec) -> Dictionary:
    assert(state.finite)
    assert(dt > 0.0)
    assert(spec.max_torque_rate_nm_s >= 0.0)
    assert(spec.structural_torque_limit_nm >= 0.0)
    var requested_active := _sum(active_components)
    var full_bounds := active_bounds_nm(
        1.0, state.angular_velocity_rad_s, spec)
    var requested_direction_cap := (
        float(full_bounds["upper_nm"])
        if requested_active >= 0.0
        else -float(full_bounds["lower_nm"]))
    var activation_requested := 0.0
    if absf(requested_active) > 1.0e-9:
        activation_requested = (
            1.0
            if requested_direction_cap <= 1.0e-9
            else clampf(
                absf(requested_active) / requested_direction_cap,
                0.0,
                1.0))
    var activation := activation_step(
        previous_activation,
        activation_requested,
        dt,
        spec)
    var bounds := active_bounds_nm(
        float(activation["activation_applied"]),
        state.angular_velocity_rad_s,
        spec)

    var rate_step := spec.max_torque_rate_nm_s * dt
    var rate_limited := clampf(
        requested_active,
        previous_active_nm - rate_step,
        previous_active_nm + rate_step)
    var applied_active := clampf(
        rate_limited,
        float(bounds["lower_nm"]),
        float(bounds["upper_nm"]))
    var qdot := state.angular_velocity_rad_s
    var candidate_power_w := rate_limited * qdot
    var selected_work_regime := &"isometric"
    if candidate_power_w > 1.0e-9:
        selected_work_regime = &"positive_work"
    elif candidate_power_w < -1.0e-9:
        selected_work_regime = &"negative_work"

    var selected_curve: Dictionary = bounds["positive_work"]
    if selected_work_regime == &"negative_work":
        selected_curve = bounds["negative_work"]

    var envelope_clamped := (
        not is_equal_approx(applied_active, rate_limited))
    var torque_rate_limited := (
        not is_equal_approx(rate_limited, requested_active))
    var limit_causes: Array[StringName] = []
    if torque_rate_limited:
        limit_causes.append(&"TORQUE_RATE")
    if envelope_clamped:
        var full_direction_bound := (
            float(full_bounds["upper_nm"])
            if rate_limited >= 0.0
            else -float(full_bounds["lower_nm"]))
        var applied_direction_bound := (
            float(bounds["upper_nm"])
            if rate_limited >= 0.0
            else -float(bounds["lower_nm"]))
        if applied_direction_bound < full_direction_bound - 1.0e-9:
            limit_causes.append(&"ACTIVATION")
        if selected_work_regime == &"isometric":
            limit_causes.append(&"ISOMETRIC_TORQUE_CAP")
        else:
            if bool(selected_curve["speed_limited"]):
                limit_causes.append(
                    &"POSITIVE_WORK_SPEED_CURVE"
                    if selected_work_regime == &"positive_work"
                    else &"NEGATIVE_WORK_SPEED_CURVE")
            if bool(selected_curve["power_limited"]):
                limit_causes.append(
                    &"POSITIVE_POWER_CAP"
                    if selected_work_regime == &"positive_work"
                    else &"ABSORPTION_POWER_CAP")

    var requested_passive := _sum(passive_components)
    var applied_passive := requested_passive
    var total_pre_structure := applied_active + applied_passive
    var structure := spec.structural_torque_limit_nm
    var applied_total := clampf(
        total_pre_structure, -structure, structure)
    var structural_guard_reaction := (
        applied_total - total_pre_structure)
    var structural_saturated := (
        absf(total_pre_structure) > structure + 1.0e-6)
    if structural_saturated:
        limit_causes.append(&"STRUCTURAL_GUARD")

    return {
        "requested_active_nm": requested_active,
        "rate_limited_active_nm": rate_limited,
        "applied_active_nm": applied_active,
        "requested_passive_nm": requested_passive,
        "applied_passive_nm": applied_passive,
        "total_pre_structure_nm": total_pre_structure,
        "structural_guard_reaction_nm": structural_guard_reaction,
        "applied_total_nm": applied_total,
        "active_lower_bound_nm": bounds["lower_nm"],
        "active_upper_bound_nm": bounds["upper_nm"],
        "selected_work_regime": selected_work_regime,
        "limit_causes": limit_causes,
        "activation_previous": activation["activation_previous"],
        "activation_requested": activation["activation_requested"],
        "activation_applied": activation["activation_applied"],
        "activation_next": activation["activation_next"],
        "activation_update_phase": activation["activation_update_phase"],
        "structural_cap_nm": structure,
        "active_saturated": envelope_clamped,
        "torque_rate_limited": torque_rate_limited,
        "speed_limited": (
            envelope_clamped
            and selected_work_regime != &"isometric"
            and bool(selected_curve["speed_limited"])),
        "power_limited": (
            envelope_clamped
            and selected_work_regime != &"isometric"
            and bool(selected_curve["power_limited"])),
        "structural_saturated": structural_saturated,
        "active_power_w": applied_active * qdot,
        "passive_power_w": applied_passive * qdot,
        "structural_guard_power_w": (
            structural_guard_reaction * qdot),
        "applied_total_power_w": applied_total * qdot,
    }
```

`active_lower_bound_nm` and `active_upper_bound_nm` are the authoritative directional envelope.
There is no ambiguous scalar `active_cap_nm`. `selected_work_regime` is chosen from the
rate-limited candidate, and `limit_causes` may contain several simultaneous causes (`TORQUE_RATE`,
`ACTIVATION`, a speed curve, a positive/absorption power cap, and `STRUCTURAL_GUARD`). A singular
reason string would erase exactly the interaction the dyno is meant to expose.

The structural clamp is a temporary safe model. Later, sustained over-structure load should produce
a declared tear/damage event rather than quietly granting a perfectly rigid cap forever. Its
reaction and work are classified as an artificial safety intervention, not active muscle or passive
tissue. A run that touches this clamp cannot promote an unassisted anatomy claim unless the fixture
explicitly tests the structural guard.

### 6.5 Sealed ledger and executor

`CommandLedger` records intent. `ActuationExecutor` applies the sealed result. This prevents the
logger and physics mutation from disagreeing.

```gdscript
class_name CommandLedger
extends RefCounted

var _tick := -1
var _sealed := true
var _joint_commands: Array[JointTorqueCommand] = []
var _sealed_envelope: Dictionary = {}
var sealed_sha256: String

func begin_tick(tick: int) -> void:
    assert(_sealed)
    _tick = tick
    _sealed = false
    _joint_commands.clear()
    _sealed_envelope = {}

func queue_joint(command: JointTorqueCommand) -> void:
    assert(not _sealed)
    assert(command.tick == _tick)
    assert(command.axis_world.is_finite())
    _joint_commands.append(command)

func seal(record_fields: Dictionary) -> Dictionary:
    assert(not _sealed)
    assert(int(record_fields["command_id"]) == _tick)
    assert(not record_fields.has("joint_commands"))
    assert(not record_fields.has("command_payload_sha256"))

    var joint_values: Array = []
    for command in _joint_commands:
        joint_values.append(
            FrozenValue.snapshot(command.to_value_dictionary()))
    _joint_commands.clear()

    # The hash domain is exactly `/payload`; the hash field is outside it, so
    # there is no self-referential digest.
    var payload_builder := record_fields.duplicate(true)
    payload_builder["joint_commands"] = joint_values
    var payload: Dictionary = FrozenValue.snapshot(payload_builder)
    sealed_sha256 = CanonicalJson.sha256(payload)
    _sealed_envelope = FrozenValue.snapshot({
        "command_payload_sha256": sealed_sha256,
        "payload": payload,
    })
    _sealed = true
    return _sealed_envelope
```

```gdscript
class_name ActuationExecutor
extends RefCounted

static func apply_command_envelope(
        envelope: Dictionary,
        bodies_by_stable_id: Dictionary,
        receipt_sink: ExecutionReceiptSink) -> void:
    var payload: Dictionary = envelope["payload"]
    var command_payload_sha256: String = envelope["command_payload_sha256"]
    assert(CanonicalJson.sha256(payload) == command_payload_sha256)

    for joint_command in payload["joint_commands"]:
        # `joint_command` and every planned operation are sealed values.
        for operation in joint_command["planned_application_operations"]:
            var body_id: StringName = operation["body_id"]
            var body: RigidBody3D = bodies_by_stable_id[body_id]
            var torque_world: Vector3 = operation["torque_world_nm"]
            assert(body != null)
            assert(torque_world.is_finite())

            var ordinal := receipt_sink.next_call_ordinal()
            body.apply_torque(torque_world)
            receipt_sink.append_call_returned({
                "source_kind": &"command",
                "source_record_id": (
                    "command:%d" % int(payload["command_id"])),
                "source_payload_sha256": command_payload_sha256,
                "operation_id": operation["operation_id"],
                "executor_call_ordinal": ordinal,
                "api": &"RigidBody3D.apply_torque",
                "target_body_id": body_id,
                "arguments": {
                    "torque_world_nm": torque_world,
                },
            })
```

Godot 4.7's `apply_torque()` applies force for one physics update and requires a valid inverse
inertia, normally supplied by an active collision shape. It must therefore be called on every tick
for sustained effort. The fixture validates that each body has a collider and finite inverse inertia
before actuation.

### 6.6 Hard executor assertions

Certified lab execution rejects:

```gdscript
assert(is_finite(float(command["applied_total_nm"])))
var axis_world: Vector3 = command["axis_world"]
assert(axis_world.length() > 0.999)
assert(StringName(command["source_id"]) != &"")
assert(StringName(command["behavior_state"]) != &"")
assert(command["planned_application_operations"].size() == 2)
var child_op: Dictionary = command["planned_application_operations"][0]
var parent_op: Dictionary = command["planned_application_operations"][1]
var child_torque: Vector3 = child_op["torque_world_nm"]
var parent_torque: Vector3 = parent_op["torque_world_nm"]
assert(child_op["body_id"] != parent_op["body_id"])
assert((child_torque + parent_torque).length() <= pairing_tolerance_nm)
assert(bodies_by_stable_id.has(child_op["body_id"]))
assert(bodies_by_stable_id.has(parent_op["body_id"]))
```

Required negative test: retain a reference to the original `JointTorqueCommand`, call `seal()`,
mutate its torque, axis, source dictionary, and nested diagnostics, then prove the sealed hash,
serialized command record, and applied torque are unchanged. A shallow `Array.duplicate()` does not
pass this test.

Separate command types exist for:

- environmental disturbances;
- rails and gantries;
- physical sensor/scaffold contact;
- deliberately invalid negative controls.

They are never stored as muscle torque.

---

## 7. Contact observation and support state

### 7.1 Observer seam

Lab fixtures should use an observed rigid body subclass that caches direct physics state during the
integration callback.

```gdscript
class_name ObservedRigidBody
extends RigidBody3D

var body_id: StringName
var part_index := -1
var latest_body_sample: BodySample
var latest_contacts: Array[ContactSample] = []
var callback_sequence := 0
var capture_clock: LabCaptureClock
var observer_profile: ObserverProfile

func _ready() -> void:
    assert(capture_clock != null)
    assert(observer_profile != null)
    contact_monitor = observer_profile.contacts_enabled
    max_contacts_reported = observer_profile.contact_cap_per_body

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
    callback_sequence += 1
    var tag := capture_clock.current_tag()
    latest_body_sample = _sample_body(
        state, tag, callback_sequence)
    latest_contacts = _sample_contacts(
        state, tag, callback_sequence, observer_profile)
```

The controller does not mutate transforms or velocities in this callback. The callback is used to
capture a coherent state sample. Commands are issued through the executor once per lab tick.

`LabCaptureClock` is owned by the runner. Its tag contains `physics_step_id`, `capture_epoch`, and
`sample_phase`. A per-body callback counter is diagnostic only and is never used as the global tick.
The clock increments `capture_epoch` exactly once when it opens each canonical capture epoch, not
once per body. Invalid/dropped frames still consume their epoch, so an unwrapped joint's explicit
`previous.capture_epoch == current.capture_epoch - 1` test detects the gap.
After each step, `FrameAssembler` checks the required-body set:

```text
same physics_step_id for every required sample
same capture_epoch
no duplicate body callback for the committed phase
missing/sleeping/late bodies explicitly unavailable
frame invalidated when a required channel is absent
```

Tests cover sleeping bodies, a body spawned after step zero, duplicate callbacks, and a deliberately
missing callback. The assembler cannot silently combine adjacent engine steps.

If callback ordering proves unsuitable for a fixture, use the lower-level
`PhysicsServer3D.body_set_state_sync_callback()` adapter. Whichever seam is selected must be
identified in the manifest and observer A/B tests.

Godot API facts pinned for this adapter:

- the Godot 4.7
  [`PhysicsDirectBodyState3D`](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectbodystate3d.html)
  reference documents `get_contact_local_position()` as a **global-coordinate** position despite
  the method name;
- the current Godot 4.7
  [Jolt contact listener source](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/modules/jolt_physics/spaces/jolt_contact_listener_3d.cpp)
  converts Jolt's `mWorldSpaceNormal` into the stored per-body contact normals;
- the pinned
  [Jolt direct-body-state source](https://github.com/godotengine/godot/blob/5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88/modules/jolt_physics/objects/jolt_physics_direct_body_state_3d.cpp)
  returns the stored local-body contact normal unchanged;
- `get_contact_count()` is zero unless contact monitoring/reporting is configured;
- the official
  [Jolt Physics differences](https://docs.godotengine.org/en/4.7/tutorials/physics/using_jolt_physics.html#contact-impulses)
  state that reported contact impulses are predicted estimates and are only accurate when the two
  bodies are not simultaneously colliding with other bodies.

Those facts are why the adapter does not transform the reported point again, why contact capability
is manifest data, and why impulse quality is a field rather than an unstated assumption.

### 7.2 Contact capture skeleton

```gdscript
func _sample_contacts(
        state: PhysicsDirectBodyState3D,
        tag: CaptureTag,
        callback_sequence: int,
        profile: ObserverProfile) -> Array[ContactSample]:
    var out: Array[ContactSample] = []

    for i in state.get_contact_count():
        var sample := ContactSample.new()
        sample.physics_step_id = tag.physics_step_id
        sample.capture_epoch = tag.capture_epoch
        sample.body_callback_sequence = callback_sequence
        sample.sample_phase = tag.sample_phase
        sample.body_id = body_id

        # Despite the "local" name, Godot 4.7 documents this position as
        # global. Transforming it again would corrupt the contact location.
        sample.point_world = state.get_contact_local_position(i)
        sample.point_body_local = (
            state.transform.affine_inverse() * sample.point_world)
        sample.other_point_world = (
            state.get_contact_collider_position(i))

        # In the project's pinned Jolt backend, "local" identifies this
        # body-side contact; the backend stores a world-space manifold normal.
        # A future GodotPhysics adapter must independently prove/convert its
        # frame instead of inheriting this Jolt-specific fact.
        var reported_normal := state.get_contact_local_normal(i)
        var normal_valid := (
            reported_normal.is_finite()
            and reported_normal.length_squared()
                > profile.normal_epsilon_squared)
        sample.normal_world = (
            reported_normal.normalized()
            if normal_valid
            else Vector3.ZERO)
        sample.normal_frame_source = &"jolt_world_backend"
        sample.normal_available = normal_valid
        sample.normal_quality = (
            &"backend_pinned"
            if normal_valid
            else &"invalid_zero_or_nonfinite")

        var local_velocity := (
            state.get_contact_local_velocity_at_position(i))
        var other_velocity := (
            state.get_contact_collider_velocity_at_position(i))
        sample.relative_velocity_world = (
            local_velocity - other_velocity)

        if normal_valid:
            var vn := (
                sample.relative_velocity_world.dot(sample.normal_world)
                * sample.normal_world)
            sample.tangential_velocity_world = (
                sample.relative_velocity_world - vn)
            sample.tangential_velocity_available = true
            sample.tangential_velocity_quality = &"derived_from_valid_normal"
        else:
            sample.tangential_velocity_world = Vector3.ZERO
            sample.tangential_velocity_available = false
            sample.tangential_velocity_quality = &"normal_invalid"

        if profile.contact_impulse_capability == &"jolt_estimate":
            sample.impulse_world = state.get_contact_impulse(i)
            sample.impulse_available = sample.impulse_world.is_finite()
            sample.impulse_quality = (
                &"exposed_estimate"
                if sample.impulse_available
                else &"invalid")
        else:
            sample.impulse_world = Vector3.ZERO
            sample.impulse_available = false
            sample.impulse_quality = &"unavailable"

        sample.local_shape_index = (
            state.get_contact_local_shape(i))
        sample.other_shape_index = (
            state.get_contact_collider_shape(i))
        sample.contact_present = true
        out.append(sample)

    return out
```

When serialized, `impulse_world` becomes `null` whenever `impulse_available == false`; the in-memory
zero placeholder is never emitted as a measured zero. Availability comes from the compiled
backend/profile capability first; finiteness only distinguishes a valid exposed value from an
invalid one.

The same rule applies to tangential velocity: the in-memory zero used when the normal is invalid
serializes as `null` plus `/tangential_velocity_world = invalid`, never as a measured zero.

The exact normal transform/sign must be pinned by tests because engine APIs differ in whether a
normal points toward the local body or away from it. The bootstrap intentionally does not bury that
ambiguity in an unexplained minus sign.

### 7.3 Contact identity and lifetime

One solver contact point may move slightly every tick. A useful persistent contact key combines:

```text
local body ID
other stable body/environment ID
local shape index
other shape index
quantized local contact position
```

Use nearest-neighbor continuation inside a small scale-normalized radius. Record:

- birth tick;
- age;
- last tick;
- touchdown;
- liftoff;
- normal discontinuity;
- point drift.

Do not equate contact-point count with foot count. One foot can have several contact points.

A collision pair can be reported once from each participating body. `FrameAssembler` canonicalizes
the stable pair/shape IDs, selects exactly one creature-side record for a
creature-versus-environment contact, and expresses its normal/impulse as **environment on
creature**. The duplicate is retained only as optional raw diagnostic data and is excluded from
all sums.

Same-creature self-contact is an internal interaction:

```text
record it for tangling, collision, damage, and recovery-pose evidence
do not add it to the external support hull
do not add its equal/opposite impulses to whole-creature external impulse
do not let it increase support-map rank
```

Tests deliberately enable self-collision, dual-sided reporting, and reversed body creation order.
The canonical external contact count, net impulse, and support region must remain unchanged.

### 7.4 From collision to bearing support

A contact is a candidate support when:

```text
contact_present
and role permits support in the current behavior
and normal opposes gravity within the declared cone
and contact is not only a separating high-speed impact
```

It becomes bearing when:

```text
candidate support
and contact persists for minimum dwell
and normal impulse/load exceeds the calibrated noise floor
```

During get-up, a knee or forearm can be an allowed recovery support without being reclassified as a
foot.

```gdscript
static func is_support_candidate(
        contact: ContactSample,
        up_world: Vector3,
        allowed_roles: Array[StringName],
        minimum_up_dot: float) -> bool:
    return (
        contact.contact_present
        and contact.ownership == &"creature_environment"
        and contact.canonical_pair_side
        and contact.normal_available
        and allowed_roles.has(contact.role)
        and contact.normal_world.dot(up_world) >= minimum_up_dot)
```

### 7.5 Support polygon and static margin

Determine one declared support plane for the fixture (or a validated fitted plane), then project
bearing contact points into its tangent coordinates \((u,v)\). Do not hard-code world XZ except in a
fixture whose support normal is explicitly world up.

The signed static margin is:

```text
positive  -> CoM projection is inside the hull
zero      -> on an edge
negative  -> outside
```

Degenerate geometry is not sent blindly to a polygon algorithm:

| Bearing geometry | Representation | Margin meaning |
|---|---|---|
| zero points | `empty`, invalid | no support claim |
| one point | authored footprint/tolerance around the point | radial point/footprint margin |
| two distinct points | segment or authored-width capsule | distance to segment/capsule boundary |
| three or more non-collinear points | convex polygon | signed distance to polygon boundary |
| three or more collinear points | reduce to segment | never pretend a polygon has area |

For a finite-area foot, use either the raw measured contact hull or a preregistered authored
pressure footprint. A single contact centroid does not magically acquire area. The snapshot stores
plane origin, normal, tangent basis, geometry kind, projected vertices, fit residual, and source
(`fixture_declared`, `contact_fit`, or `authored_footprint`).

### 7.6 Capture point

For a planar linear-inverted-pendulum approximation, first express CoM position and velocity in the
support-plane tangent coordinates:

\[
g_n=-g^W\cdot n,\qquad
h=(C-o)\cdot n,\qquad
\omega_0 = \sqrt{\frac{g_n}{h}}
\]

\[
\xi_{uv}=C_{uv}+\frac{V_{C,uv}}{\omega_0}
\]

The capture margin compares this predicted point to the support region.

Increasing CoM velocity moves the capture point farther in the fall direction. Lowering CoM height
increases \(\omega_0\), so the velocity-dependent offset \(v/\omega_0\) becomes smaller. This
estimate is only valid for the declared planar, roughly constant-height regime.

The channel is invalid, not infinite or zero, when:

```text
g_n <= gravity_epsilon_m_s2
h <= minimum_capture_height_m
support plane is unavailable
the fixture violates the constant-height/planar approximation
```

Flat-world `support_polygon_xz` can remain a derived compatibility view only when
`support_plane_normal_world` passes its world-up oracle.

A floor, wall, and knee contact that are not approximately coplanar do not have one meaningful
support polygon or LIP capture point. Spatial recovery evaluates their full contact-wrench cone;
plane-based margins become unavailable with reason `MULTIPLANE_CONTACT_SET`.

### 7.7 Contact and observer gates

Before a controller consumes contact samples:

1. stationary box contact persists without invented liftoffs;
2. box drop reports contact after the analytically predicted impact time;
3. contact normal points in the calibrated direction;
4. sliding contact produces tangential relative velocity with the expected sign;
5. contact-monitor off/on trajectories stay inside the declared A/B envelope;
6. Jolt impulse estimate is compared to whole-system momentum change;
7. multi-contact impulse limitations are labeled, not tuned away.

---

## 8. Whole-body wrench and support allocation

### 8.1 `BodyWrench`

```gdscript
class_name BodyWrench
extends RefCounted

var reference_point_world: Vector3
var force_world: Vector3
var moment_world: Vector3
var source_id: StringName
```

Moments are meaningless without their reference point. To move the same physical wrench from
reference \(r_\text{old}\) to \(r_\text{new}\):

\[
M_\text{new}
=
M_\text{old}
+
(r_\text{old}-r_\text{new})\times F
\]

```gdscript
static func shift_wrench(
        wrench: BodyWrench,
        new_reference_world: Vector3) -> BodyWrench:
    var out := BodyWrench.new()
    out.reference_point_world = new_reference_world
    out.force_world = wrench.force_world
    out.moment_world = (
        wrench.moment_world
        + (
            wrench.reference_point_world
            - new_reference_world
        ).cross(wrench.force_world))
    out.source_id = wrench.source_id
    return out
```

The arbiter rejects adding or comparing wrenches with different reference points unless one is
explicitly shifted. Unit tests use a pure force with a known lever arm to catch the sign error.

### 8.2 Height-only rail controller

The rail removes lateral translation and body rotation. That is a real scaffold: it may supply
lateral reaction force and rotation-constraint torque even if it supplies nearly zero work. The
honest first claim is therefore:

```text
the controller applies no direct root rescue force or torque;
the declared rail supplies constrained-DOF reactions;
rail linear/angular impulse and work are measured when exposed,
or inferred as a labeled whole-system residual when the engine does not expose them;
the actuator must provide the vertical support/rise work under test.
```

Use a translation-only guide when testing vertical support if the engine can expose its lateral
reaction cleanly. A fully rotation-locking rail is acceptable for a height-only oracle, but it
cannot support an attitude-control claim.

```gdscript
static func desired_vertical_reaction(
        state: WholeBodyState,
        desired_height_m: float,
        desired_vertical_velocity_m_s: float,
        kp_s2: float,
        kd_s1: float,
        gravity_m_s2: float,
        max_accel_m_s2: float) -> float:
    var height_error := desired_height_m - state.support_height_m
    var velocity_error := (
        desired_vertical_velocity_m_s
        - state.support_height_velocity_m_s)
    var accel := clampf(
        kp_s2 * height_error + kd_s1 * velocity_error,
        -max_accel_m_s2,
        max_accel_m_s2)
    return state.total_mass_kg * (gravity_m_s2 + accel)
```

This returns the desired upward ground reaction. If it is negative, the controller cannot ask a
normal floor to pull downward; clamp to zero and report the unilateral constraint.

### 8.3 Full desired wrench

V1 below is a **reference-body attitude law** only for a named single-rigid-composite fixture where
`root_is_whole_body == true`, the sampled root inertia is the full assembly inertia, and the root
CoM is the whole-body CoM. “Low articulation” is not sufficient. This is not a general centroidal
controller for a freely moving articulated creature.

```gdscript
static func desired_body_wrench(
        state: WholeBodyState,
        goal,
        gains,
        gravity_world: Vector3) -> BodyWrench:
    var position_error: Vector3 = (
        goal.com_position_world
        - state.center_of_mass_world)
    var velocity_error: Vector3 = (
        goal.com_velocity_world
        - state.center_of_mass_velocity_world)
    var accel_des := (
        position_error * gains.position_kp_s2
        + velocity_error * gains.position_kd_s1)
    accel_des = accel_des.limit_length(gains.max_linear_accel_m_s2)

    var orientation_error := SupportMath.orientation_error_world(
        goal.anatomical_basis_world,
        state.root_basis_world)
    var alpha_des := (
        orientation_error * gains.rotation_kp_s2
        - state.root_angular_velocity_world * gains.rotation_kd_s1)
    alpha_des = alpha_des.limit_length(gains.max_angular_accel_rad_s2)

    var out := BodyWrench.new()
    out.reference_point_world = state.center_of_mass_world
    out.force_world = (
        state.total_mass_kg
        * (accel_des - gravity_world))

    assert(state.root_is_whole_body)
    assert(state.root_inertia_available)
    var angular_momentum_root := (
        state.root_inertia_world
        * state.root_angular_velocity_world)
    out.moment_world = (
        state.root_inertia_world * alpha_des
        + state.root_angular_velocity_world.cross(
            angular_momentum_root))
    out.source_id = &"stance.body_wrench"
    return out
```

This function returns a target for contact forces. It does not call `root.apply_force()`.
`orientation_error_world(desired, current)` is defined to point from current orientation toward the
desired orientation, so its proportional sign is positive. The root inertia is sampled plant state,
never a gain.

For unrestricted articulated motion, replace the reference-body approximation with a centroidal
angular-momentum objective:

\[
\dot L_C^\*
=
K_R e_R
-
K_L(L_C-L_C^\*)
\]

and ask the contact allocator for the external moment about the whole-body CoM. Internal joint
torques can redistribute link momentum but cannot change total \(L_C\) without external contact.
Do not promote an articulated 3D whole-body attitude claim using the root-only inertia law.

### 8.4 Vertical load allocator V1

The existing evaluator already solves a minimum-norm vertical distribution with force and horizontal
moment balance at
[CharacteristicsEvaluator.gd:797-909](../scripts/core/CharacteristicsEvaluator.gd#L797-L909).
Extract the pure math into `support_math.gd` so analytic feasibility and live stance share one tested
implementation.

Inputs:

```text
live bearing contact points
live whole-body CoM
desired total upward force
optional excluded contact
```

Outputs:

```text
per-contact vertical load
unloaded contacts
rank
residual
feasible flag
reason
```

The active-set rule is:

1. solve equality-constrained minimum norm;
2. if a contact receives negative load, remove it;
3. solve again;
4. stop when all loads are nonnegative or rank is insufficient.

Never replace a rank failure with an equal split while still calling the result exact. An equal
split may be emitted as a labeled fallback estimate for diagnostics.

### 8.5 Planar allocator V2

For the sagittal brace rig, each contact has normal \(f_y\) and fore/aft \(f_x\).

Solve:

\[
\sum_i f_{x,i}=F_x^\*
\]

\[
\sum_i f_{y,i}=F_y^\*
\]

\[
\sum_i
\left[
(x_i-c_x)f_{y,i}
-
(y_i-c_y)f_{x,i}
\right]
=M_z^\*
\]

subject to:

\[
f_{y,i}\ge0
\]

\[
|f_{x,i}|\le\mu_i f_{y,i}
\]

and joint torque caps.

This is enough to validate height, fore/aft capture, pitch correction, and fall arrest in one plane
before introducing roll/yaw.

### 8.6 Full 3D allocator V3

Do not start here. After V1 and V2 match analytic micro-oracles, implement constrained least squares:

\[
\min_\lambda
\|A\lambda-b\|_W^2
+ \epsilon\|\lambda-\lambda_{\text{previous}}\|^2
\]

subject to unilateral, friction, and actuator constraints.

The smoothing term reduces contact-load chatter. Raising \(\epsilon\) makes load changes smoother but
slower; too much delays bracing.

The result always includes:

```gdscript
{
    "feasible": bool,
    "reason": StringName,
    "contact_forces": Dictionary,
    "desired_wrench": BodyWrench,
    "achieved_wrench": BodyWrench,
    "allocator_arithmetic_residual": Vector6Like,
    "predicted_feasibility_residual": Vector6Like,
    "realized_physical_wrench_residual": Vector6Like,
    "joint_torque_margins": Dictionary,
    "friction_margins": Dictionary,
}
```

These residuals are distinct:

```text
allocator arithmetic residual
  numerical error in A*lambda versus the constrained target

predicted feasibility residual
  portion intentionally shed because contact/actuator constraints made the target infeasible

realized physical wrench residual
  predicted target-contact wrench versus an independently momentum-derived,
  nuisance-subtracted target-contact wrench
```

The last residual does **not** compare foot contact to total external wrench. Choose one world point
\(R\) and hold it fixed over transition \(N\rightarrow N+1\). Compute:

\[
\bar F_{\text{ext}}
=
\frac{P_{N+1}-P_N}{\Delta t}
\]

\[
\bar M_{\text{ext},R}
=
\frac{L_{R,N+1}-L_{R,N}}{\Delta t}
\]

where every link contributes to \(P\) and \(L_R\). Then isolate the target anatomical contact set:

\[
\bar{\mathcal W}_{\text{contact,target},R}^{\text{realized}}
=
\bar{\mathcal W}_{\text{ext},R}
-
\mathcal W_{\text{gravity},R}
-
\mathcal W_{\text{direct disturbances},R}
-
\mathcal W_{\text{damping/drag},R}
-
\mathcal W_{\text{scaffold/constraint},R}
-
\mathcal W_{\text{other non-target external},R}
\]

Every subtracted wrench comes from a separately sealed application/observation/mechanics channel.
This includes direct fixture impulses, rail/gantry reactions, authored damping/drag, non-target body
contacts, and moving/dynamic surfaces classified as scaffolds. If a necessary nuisance reaction is
unavailable, the realized **target-contact** wrench is unavailable; it is not credited to the feet
through a residual. A moving ground may still produce real contact force, but its scaffold-sourced
share cannot promote an unassisted anatomy claim.

Shift the allocator's predicted contact wrench to the same \(R\) before subtraction. If a report
uses a moving reference \(A(t)\), include the transport term:

\[
M_{\text{ext},A}
=
\frac{dL_A}{dt}
+
v_A\times P
\]

or convert both wrenches to a fixed interval reference first. A changing reference point without
this term is an invalid mechanics record. The BR7 realized-physics gate uses this nuisance-subtracted
definition, so a perfect allocator cannot pass by borrowing \(mg\), a root impulse, or rail support.

Combining them into one number makes an optimizer bug indistinguishable from contact slip or solver
realization error.

### 8.7 Contact force to joint torque

```gdscript
static func map_ground_reaction_to_joint_torques(
        ground_on_body_force: Vector3,
        contact_point_world: Vector3,
        chain: Array[JointState]) -> Dictionary:
    var foot_on_ground_command := -ground_on_body_force
    var out := {}

    for joint in chain:
        var r := contact_point_world - joint.pivot_world
        var jacobian_column := joint.axis_world.cross(r)
        out[joint.joint_id] = (
            jacobian_column.dot(foot_on_ground_command))

    return out
```

Record both the desired ground-on-body force and the opposite foot command. This makes the sign
convention inspectable.

### 8.8 Joint feasibility before application

For every mapped joint:

```text
required active torque
  = body-wrench task
  + active joint impedance
  + gravity compensation

available active torque
  = actuator envelope(qdot, activation, power)
```

Reject or reduce the desired wrench when the required torque is infeasible. Do not clamp every joint
independently and pretend the desired wrench was achieved; report the resulting wrench residual.

### 8.9 Static stand versus active rise

Static stand:

```text
vertical velocity ≈ 0
height error ≈ 0
active power may be near 0 even with nonzero holding torque
```

Active rise:

```text
vertical velocity > 0
positive actuator work accumulates
CoM potential energy increases
```

These require separate gates. A motor can hold a pose but lack sufficient power to rise at the
requested speed.

---

## 9. Stance controller: support before gait

### 9.1 What stance owns

The stance controller is not a frozen gait phase. It owns a smaller, explicit problem:

1. keep the assigned support contacts loaded;
2. regulate root height inside a reachable band;
3. regulate root roll and pitch;
4. keep the projected CoM and capture point inside a viable support region;
5. preserve joint reserve for a disturbance;
6. request a different mode when those goals become infeasible.

It does **not** own foot swing, step timing, recovery sequencing, root rescue forces, or direct body
mutation.

The initial stance controller should run on a rail fixture, then a planar fixture, then a spatial
fixture. Walking is not a prerequisite for any of those tests.

### 9.2 Why "straighten the leg" is a whole-body request

A knee angle target alone does not say how much upward force the body should receive. At a contact
point \(p\), a desired body force \(F\) maps into joint torque through:

\[
\tau = J^T(-F)
\]

The negative sign is present because the joint command pushes the foot into the ground while the
ground pushes the body in the desired direction.

This separates two useful commands:

- **task-space support:** produce a desired body wrench through contact;
- **joint-space shape:** prefer a comfortable bend and avoid limits.

The controller combines them before the single active clamp:

\[
\tau_{\text{active,requested}}
=
\tau_{\text{support}}
+
\tau_{\text{shape}}
+
\tau_{\text{gravity}}
\]

If the support task needs nearly all available torque, shape preference must yield. If shape
preference consumes the reserve needed to support weight, the prioritization is backwards.

### 9.3 Do not command the exact straight-leg singularity

For a two-link leg, the vertical height \(h(q_1,q_2)\) approaches a kinematic maximum as the links
align. Near that maximum:

- a tiny additional height request can require a large joint change or become impossible;
- the Jacobian loses useful leverage in one direction;
- joint-limit and collision errors become dominant;
- a controller may alternate violently between "more extension" and a hard stop.

The default loaded stance target should therefore preserve a small bend:

```text
knee_extension_reserve_rad = 0.12 to 0.30
```

This is an experimental range, not a final organism constant. The rail-leg sweep must identify the
actual relationship:

```text
extension reserve
  -> vertical force leverage
  -> available height
  -> joint torque reserve
  -> stability under disturbance
```

An "almost straight" leg may support better than either a deeply bent leg or a geometrically locked
leg.

### 9.4 Height and attitude command

For root height:

\[
F_y^\*
=
m
\left[
g
+
k_h(h^\*-h)
-
d_h\dot h
\right]
\]

For small-angle roll and pitch:

\[
M_x^\*
=
k_\phi(\phi^\*-\phi)-d_\phi\omega_x
\]

\[
M_z^\*
=
k_\theta(\theta^\*-\theta)-d_\theta\omega_z
\]

For horizontal capture:

\[
F_{xz}^\*
=
k_c(c^\*_{xz}-c_{xz})
-
d_c v_{xz}
\]

where \(c_{xz}\) is the planar CoM or capture-point projection. Start with position regulation on a
rail; add capture-point regulation only after the raw CoM and velocity channels pass their oracles.

### 9.5 Proposed `StanceController`

Target file: `scripts/lab/control/stance_controller.gd`

```gdscript
class_name StanceController
extends RefCounted

var height_kp_s2 := 18.0
var height_kd_s1 := 6.0
var attitude_kp_nm_per_rad := Vector3(180.0, 0.0, 180.0)
var attitude_kd_nm_s_per_rad := Vector3(24.0, 0.0, 24.0)
var desired_height_m := 0.75
var desired_up_world := Vector3.UP

func build_intent(
        state: WholeBodyState,
        support: SupportSnapshot,
        delta: float) -> ControlIntent:
    var intent := ControlIntent.new()
    intent.tick = state.tick
    intent.valid_until_tick = state.tick
    intent.source = &"stance"
    intent.mode = ControlIntent.Mode.STANCE
    intent.priority = ControlIntent.PRIORITY_STANCE

    if not support.has_bearing_support:
        intent.feasible = false
        intent.reason = &"STANCE_NO_BEARING_SUPPORT"
        return intent

    var height_error := desired_height_m - state.support_height_m
    var gravity_m_s2 := maxf(
        0.0, -state.gravity_world_m_s2.dot(Vector3.UP))
    var desired_vertical_force := (
        state.total_mass_kg
        * (
            gravity_m_s2
            + height_kp_s2 * height_error
            - height_kd_s1
            * state.support_height_velocity_m_s))

    # Attitude error must be derived by a tested orientation helper. Do not
    # subtract Euler angles directly across wrap boundaries.
    var attitude_error := SupportMath.up_alignment_error(
        state.root_basis_world, desired_up_world)

    var desired_moment := Vector3(
        attitude_kp_nm_per_rad.x * attitude_error.x
            - attitude_kd_nm_s_per_rad.x
            * state.root_angular_velocity_world.x,
        0.0,
        attitude_kp_nm_per_rad.z * attitude_error.z
            - attitude_kd_nm_s_per_rad.z
            * state.root_angular_velocity_world.z)

    intent.desired_wrench.force_world = Vector3(
        0.0, maxf(0.0, desired_vertical_force), 0.0)
    intent.desired_wrench.moment_world = desired_moment
    intent.desired_wrench.reference_point_world = (
        state.center_of_mass_world)
    intent.joint_preferences = _comfortable_joint_preferences(state)
    return intent
```

The constants are fixture seeds. They are not "realistic values" until the mass, timestep, actuator
caps, and measured response are recorded beside them.

The height gains are mass-normalized acceleration gains, matching Sections 2.3 and 9.4. Doubling
body mass therefore doubles requested force without silently halving the nominal closed-loop
acceleration response. A force-gain implementation in N/m could also be valid, but it would be a
different declared controller and must not reuse these field names.

### 9.6 Support-load state for each limb

Binary `grounded` is insufficient. Each candidate support limb needs a small contact state:

```text
SEARCH   no usable contact; limb may seek a surface
TOUCH    contact exists but impulse/load has not persisted
LOAD     controller is ramping compressive force
BEARING  persistent, compressive, low-slip support
UNLOAD   deliberately reducing load before release
LOST     support disappeared unexpectedly
```

Suggested transitions:

```text
SEARCH -> TOUCH
  when a qualifying ground contact appears

TOUCH -> LOAD
  after contact persists for contact_confirm_ticks

LOAD -> BEARING
  when normal impulse/load proxy and slip stay inside thresholds

BEARING -> LOST
  immediately on separation, excessive slip, or invalid sample

BEARING -> UNLOAD
  only by an explicit higher-level release request

UNLOAD -> SEARCH
  after support force approaches zero and contact is released
```

The controller may only count `BEARING` limbs in its guaranteed support set. `TOUCH` and `LOAD` can
be candidates, but claiming their full load too early creates false support.

### 9.7 Load ramps

A newly touching foot should not receive its maximum requested force in one tick, and an unloading
foot should not be forced to use the loading rate. Use separate one-sided limits:

\[
F_\text{lower}
=
\max(0,F_{n,k-1}-\dot F_{\text{unload}}\Delta t)
\]

\[
F_\text{upper}
=
F_{n,k-1}+\dot F_{\text{load}}\Delta t
\]

\[
F_{n,\text{rate}}
=
\operatorname{clamp}
\left(
F_{n,\text{desired}},
F_\text{lower},
F_\text{upper}
\right)
\]

```gdscript
var lower := maxf(
    0.0,
    previous_normal_n - unload_rate_n_s * delta)
var upper := (
    previous_normal_n + load_rate_n_s * delta)
var rate_limited_normal_n := clampf(
    desired_normal_n, lower, upper)
```

Increasing the loading-rate cap:

- makes catches faster;
- increases impact and solver stress;
- makes contact chatter more damaging;
- can hide poor approach-velocity control.

Decreasing it:

- makes contact gentler;
- can make fall arrest physically too slow;
- may cause a valid foot to unload before it becomes bearing.

The unloading rate controls release latency and must be calibrated separately: a very slow unload
can trap a foot; an instantaneous unload can destroy the support wrench. Log `desired`,
`load_rate_limited`, `unload_rate_limited`, `friction_limited`, `actuator_limited`, and
`achieved_estimate` separately, including the reason selected by the active bound.

### 9.8 Anti-windup under saturation

If height control later gains an integral term, freeze or back-calculate it when:

- active torque is saturated;
- the support allocator is infeasible;
- height target is kinematically unreachable;
- no bearing contact exists.

Otherwise the integral term grows while the creature cannot satisfy it, then launches the body when
contact or leverage returns.

Initial stance deliberately uses PD control and no integral term. Add integral action only after a
measured steady-state bias remains with valid reserve.

### 9.9 Rail-leg stance oracle

The vertical rail removes roll, pitch, lateral escape, and gait decisions. The fixture contains:

```text
one root mass constrained to Y translation
one foot using ordinary unilateral collision and friction against a flat ground
one two-link leg with explicit hinge axes
one actuator per driven hinge
optional spring/tendon toggle
no controller-applied root rescue force/torque and no pose reset after release
declared rail reaction force/torque measured or residual-inferred
```

`PINNED_EFFECTOR`, a fixed foot joint, or any floor constraint that can pull the foot is forbidden.
The floor must be able to push but not pull, and slip must remain possible when friction is
insufficient. Passive tissue is disabled for the primary active-support gate; it is introduced only
in a separately labeled variant.

Minimum trials:

1. gravity-off zero command;
2. gravity-on passive collapse;
3. gravity-on analytic feed-forward hold;
4. feed-forward plus height PD;
5. commanded crouch;
6. commanded rise;
7. downward impulse recovery;
8. load increase until declared infeasible.

Promotion requires:

```text
|measured support impulse / dt - expected weight| <= tolerance
root height error settles inside band
no active command exceeds its declared envelope
potential-energy increase <= positive motor work + numerical tolerance
rail/scaffold impulse and work remain inside the declared constrained-DOF envelope
no hidden central force, pinned foot, or pose write occurs
```

---

## 10. Support supervisor and brace state machine

### 10.1 Why bracing cannot be an emergency gain multiplier

When a creature begins to tip, the problem is no longer merely "hold the same pose harder." The
controller must decide:

- is the current support polygon still viable?
- can existing feet generate the correcting wrench?
- is a new contact reachable before impact?
- which limb should press, unload, or move?
- is the body already fallen enough that a get-up profile should take over?

Those are discrete mode decisions. Hiding them inside a larger PD gain makes them unobservable and
usually produces fighting controllers.

### 10.2 Supervisor states

Target file: `scripts/lab/control/support_supervisor.gd`

```gdscript
enum Mode {
    STAND,
    PRECARIOUS,
    BRACE,
    FALL_ARREST,
    FALLEN,
    GET_UP,
    STABILIZE,
    COMPLETE,
    FAILED,
}
```

Semantics:

| Mode | Meaning | Primary owner |
|---|---|---|
| `STAND` | support margin and reserve are healthy | stance |
| `PRECARIOUS` | margin/reserve is shrinking, but current support may recover | stance with conservative targets |
| `BRACE` | active redistribution or a new support contact is required | brace |
| `FALL_ARREST` | impact/catch is imminent; minimize momentum and injury proxy | fall arrest |
| `FALLEN` | upright support objective is no longer valid | pose classifier |
| `GET_UP` | execute one explicit recovery profile | recovery |
| `STABILIZE` | recovered support exists; settle before declaring success | stance |
| `COMPLETE` | recovery/stand experiment passed | none |
| `FAILED` | explicit terminal failure with evidence | none |

Gameplay gait is intentionally absent. Once `STAND` is proven, gameplay may ask a higher-level
coordinator to transition between `STAND` and `GAIT`; the support supervisor retains authority to
preempt gait with `BRACE`.

### 10.3 Precariousness metrics

Use multiple independent signals:

```text
static margin                  distance from projected CoM to support boundary
capture margin                 distance from capture point to support boundary
tilt                          angle between root up and world up
tip angular speed              component rotating the body toward failure
height loss rate               negative CoM vertical velocity
support-count change           expected bearing support vanished
friction reserve               distance to friction-cone boundary
actuator reserve               distance to active torque/power boundary
allocator residual             desired wrench minus feasible wrench
predicted time to boundary     margin / closing speed
predicted time to impact       geometry/velocity estimate
```

No single threshold means "falling." A low static margin while moving inward may be safe; a modest
margin disappearing rapidly may require immediate bracing.

### 10.4 Time-to-boundary

For signed support margin \(s\) and its rate \(\dot s\), use the piecewise definition:

\[
t_{\text{boundary}}
=
\begin{cases}
0, & s\le0 \\
\dfrac{s}{-\dot s}, & s>0\ \land\ \dot s<-\epsilon \\
\infty, & \dot s\ge-\epsilon
\end{cases}
\]

An already-negative margin has zero time remaining; it must not become a negative time or an
apparently safe infinity.

For a tilted body with tilt \(\theta\) moving toward a terminal tilt \(\theta_f\):

\[
t_{\text{tilt}}
\approx
\begin{cases}
0, & \theta\ge\theta_f \\
\dfrac{\max(0,\theta_f-\theta)}{\dot\theta},
& \dot\theta>\epsilon \\
\infty, & \dot\theta\le\epsilon
\end{cases}
\]

These are coarse predictors, not truths. Record prediction error after each run so the model can be
improved instead of silently trusted.

### 10.5 Brace urgency

Normalize inputs to \([0,1]\), then:

\[
u
=
\operatorname{clamp}
\left(
w_s u_s
+
w_c u_c
+
w_t u_t
+
w_h u_h
+
w_r u_r,
0,1
\right)
\]

where terms represent static margin, capture margin, tilt/time-to-impact, height-loss, and reserve.

The trace must retain every term and weight. A scalar urgency without its decomposition cannot
explain why the mode changed.

### 10.6 Proposed transition code

```gdscript
class_name SupportSupervisor
extends RefCounted

enum Mode {
    STAND,
    PRECARIOUS,
    BRACE,
    FALL_ARREST,
    FALLEN,
    GET_UP,
    STABILIZE,
    COMPLETE,
    FAILED,
}

var mode := Mode.STAND
var ticks_in_mode := 0
var safe_ticks := 0
var bearing_loss_ticks := 0
var transition_events: Array[Dictionary] = []

# ExpandedExperiment supplies these; values shown are fixture examples.
var timeout_ticks_by_mode := {
    Mode.BRACE: 120,
    Mode.FALL_ARREST: 90,
    Mode.FALLEN: 30,
    Mode.GET_UP: 300,
    Mode.STABILIZE: 180,
}

func update(
        state: WholeBodyState,
        support: SupportSnapshot,
        assessment: BraceAssessment) -> Mode:
    # Terminal modes are absorbing. New bad sensor data cannot rewrite the
    # already-recorded terminal result.
    if mode in [Mode.COMPLETE, Mode.FAILED]:
        return mode

    ticks_in_mode += 1

    if not state.finite:
        return _transition(Mode.FAILED, &"NONFINITE_STATE")

    if (
            assessment.is_fallen
            and mode not in [Mode.FALLEN, Mode.GET_UP]):
        return _transition(Mode.FALLEN, &"POSE_CLASSIFIED_FALLEN")

    match mode:
        Mode.STAND:
            if assessment.imminent_impact:
                return _transition(
                    Mode.FALL_ARREST, &"IMMINENT_IMPACT")
            if assessment.requires_new_contact:
                return _transition(
                    Mode.BRACE, &"CURRENT_SUPPORT_INFEASIBLE")
            if assessment.precarious:
                return _transition(
                    Mode.PRECARIOUS, &"MARGIN_SHRINKING")

        Mode.PRECARIOUS:
            if assessment.imminent_impact:
                return _transition(
                    Mode.FALL_ARREST, &"IMMINENT_IMPACT")
            if assessment.requires_new_contact:
                return _transition(
                    Mode.BRACE, &"CURRENT_SUPPORT_INFEASIBLE")
            if assessment.safe:
                safe_ticks += 1
                if safe_ticks >= assessment.safe_confirm_ticks:
                    return _transition(
                        Mode.STAND, &"MARGIN_RECOVERED")
            else:
                safe_ticks = 0

        Mode.BRACE:
            if assessment.imminent_impact:
                return _transition(
                    Mode.FALL_ARREST, &"CATCH_WINDOW_CLOSING")
            if assessment.safe:
                safe_ticks += 1
                if safe_ticks >= assessment.safe_confirm_ticks:
                    return _transition(
                        Mode.STAND, &"BRACE_SUCCEEDED")
            else:
                safe_ticks = 0
            if _mode_timed_out():
                return _transition(
                    Mode.FALL_ARREST, &"BRACE_TIMEOUT")

        Mode.FALL_ARREST:
            if assessment.safe:
                return _transition(
                    Mode.STABILIZE, &"MOMENTUM_ARRESTED")
            if _mode_timed_out():
                return _transition(
                    Mode.FALLEN, &"FALL_ARREST_TIMEOUT")

        Mode.FALLEN:
            if assessment.recovery_infeasible:
                return _transition(
                    Mode.FAILED, assessment.recovery_reason)
            if assessment.recovery_ready:
                return _transition(
                    Mode.GET_UP, &"RECOVERY_PROFILE_SELECTED")
            if _mode_timed_out():
                return _transition(
                    Mode.FAILED, &"RECOVERY_SELECTION_TIMEOUT")

        Mode.GET_UP:
            if assessment.recovery_infeasible:
                return _transition(
                    Mode.FAILED, assessment.recovery_reason)
            if assessment.upright_and_supported:
                return _transition(
                    Mode.STABILIZE, &"UPRIGHT_SUPPORT_RESTORED")
            if _mode_timed_out():
                return _transition(
                    Mode.FAILED, &"GET_UP_TIMEOUT")

        Mode.STABILIZE:
            if assessment.safe:
                safe_ticks += 1
                if safe_ticks >= assessment.stable_confirm_ticks:
                    return _transition(
                        Mode.COMPLETE, &"STABLE_DWELL_PASSED")
            else:
                safe_ticks = 0
            if assessment.precarious:
                return _transition(
                    Mode.BRACE, &"RECOVERY_STABILIZE_UNSAFE")
            if _mode_timed_out():
                return _transition(
                    Mode.FAILED, &"STABILIZE_TIMEOUT")

    return mode

func _mode_timed_out() -> bool:
    if not timeout_ticks_by_mode.has(mode):
        return false
    return ticks_in_mode >= int(timeout_ticks_by_mode[mode])

func _transition(next: Mode, reason: StringName) -> Mode:
    if next == mode:
        return mode
    transition_events.append({
        "previous_mode": mode,
        "next_mode": next,
        "reason": reason,
        "ticks_in_previous_mode": ticks_in_mode,
    })
    mode = next
    ticks_in_mode = 0
    safe_ticks = 0
    bearing_loss_ticks = 0
    return mode
```

`_transition()` must emit an event containing previous mode, next mode, reason, tick, and all
triggering metrics. The abbreviated snippet queues the structural fields; the production
implementation adds the frame ID and a frozen copy of the assessment. Tests prove `COMPLETE` and
`FAILED` are absorbing, every nonterminal mode has a path or timeout, false safety resets dwell, and
`FALLEN` can enter `GET_UP`.

### 10.7 Hysteresis is part of the model

Enter and exit thresholds must differ:

```text
enter PRECARIOUS when static_margin < 0.035 m
return STAND only when static_margin > 0.055 m for N ticks
```

Likewise, contacts require a confirmation dwell before they become `BEARING`, while unexpected
bearing loss can be immediate. Symmetric debouncing delays emergencies and encourages chatter.

Every threshold includes:

- units;
- direction (`<`, `>`, or range);
- confirmation ticks;
- reset rule;
- reason it exists;
- fixture that calibrated it.

### 10.8 Control ownership and preemption

The arbiter accepts many requests but assigns one owner per active objective:

| Objective | Stand | Brace | Fall arrest | Get up |
|---|---:|---:|---:|---:|
| root height | owner | secondary | relinquish | phase-specific |
| root/body attitude | owner | secondary | centroidal momentum arrest/protective orientation | phase-specific |
| stance contact load | owner | owner | owner | phase-specific |
| swing/catch limb | none | owner | owner | phase-specific |
| joint shape | preference | preference | safety preference | owner |
| root assist | forbidden | forbidden | forbidden | forbidden |

If two commands target the same joint, the ledger records both, and the arbiter resolves them before
the actuator clamp. It must never be possible for two controllers to call `apply_torque()` directly.

### 10.9 Brace strategy selection

Use the least disruptive feasible strategy:

1. **redistribute** load among existing bearing contacts;
2. **press** a lightly loaded touching limb into support;
3. **widen** a reachable unloaded limb while existing support remains viable;
4. **catch-step** to create a new support point;
5. **protective contact** when upright recovery before impact is infeasible;
6. **classify fallen** and hand off to recovery.

For each candidate strategy, report:

```text
reachable before deadline?
collision-free enough for the fixture?
expected support-polygon improvement?
required joint torque/power feasible?
expected friction feasible?
which existing contacts must unload?
predicted body-wrench residual?
```

A strategy is chosen because its scored constraints are visible, not because a hidden if-statement
liked one limb index.

---

## 11. Fall arrest: momentum first, pose second

### 11.1 What "brace itself" means during a fall

Once tipping momentum is substantial, returning immediately to the nominal pose may be impossible.
The first goal becomes reducing harmful momentum while creating or preserving support.

Linear impulse:

\[
J
=
\int F\,dt
=
m(v_{\text{after}}-v_{\text{before}})
\]

Angular impulse about the CoM:

\[
\int \tau\,dt
=
L_{\text{after}}-L_{\text{before}}
\]

A contact force that is large but badly placed may stop downward motion while increasing rotation.
A useful brace must consider both force and its moment arm:

\[
\tau_{\text{contact}}
=
(p-c)\times F
\]

### 11.2 Static support and fall arrest are different load cases

Static support asks roughly for:

\[
\sum_i F_{y,i}\approx mg
\]

Fall arrest may ask for:

\[
\sum_i F_{y,i}
\approx
mg+\frac{m\Delta v_y}{\Delta t}
\]

Shortening the stopping time raises required force. If the actuator, structure, or friction limit
cannot provide it, the controller must lengthen the stop by bending, rolling, or adding contacts.

This is why a perfectly rigid "straighten everything" reflex can be worse than a controlled
crouch: joint flexion increases stopping distance and reduces peak force.

### 11.3 Catch feasibility

For each candidate limb:

\[
t_{\text{swing}}
=
t_{\text{reaction}}
+
\max_j t_j
\]

\[
t_{\text{bearing}}
=
t_{\text{swing}}
+
t_{\text{touchdown}}
+
t_{\text{confirm}}
+
t_{\text{load-ramp}}
\]

Require:

\[
t_{\text{bearing}}
<
t_{\text{impact}}-t_{\text{safety}}
\]

Each \(t_j\) is the earliest time for joint \(j\) to traverse its required signed displacement under
its current activation state, torque-speed-power envelope, inertia/load estimate, torque-rate
limit, velocity cap, and joint limit. A constant-acceleration trapezoidal/triangular estimate is a
valid conservative V1 oracle; a norm divided by one scalar speed is not, because one slow joint
controls the serial reach deadline. `t_touchdown` covers the final approach/first-impact window,
`t_confirm` covers contact persistence, and `t_load-ramp` covers force acquisition to `BEARING`.
If first touch and bearing support have different safety deadlines, declare and test both. If the
bearing inequality fails, the trace says `CATCH_UNREACHABLE_BEFORE_IMPACT`; the controller chooses
a different contact or protective strategy. A free-space swing/touchdown fixture validates every
term before a falling body depends on it.

### 11.4 Desired arrest wrench

Let \(v_c\) be CoM velocity and \(L_C\) whole-system angular momentum about the whole-body CoM. An
articulated fall-arrest controller can request:

\[
F^\*
=
m g_{\text{cancel}}
-
K_v v_c
-
K_p(c-c_{\text{safe}})
\]

\[
M^\*
=
K_R e_R
-
K_L(L_C-L_C^\*)
\]

Here `orientation_error_world(desired, current)` points from current toward desired; changing that
definition requires changing the sign and its unit oracle together. \(K_L\) has units \(s^{-1}\).
For a single rigid composite, \(L_C=I^W\omega\); for an articulated creature, root angular velocity
is not a substitute for \(L_C\).

Clamp desired deceleration by:

- maximum safe contact-force rate;
- friction cone;
- active joint torque and power;
- structural joint envelope;
- time remaining;
- maximum acceptable root acceleration for the fixture.

Record the unclamped wrench and every limiting stage.

### 11.5 Proposed `FallArrestController`

Target file: `scripts/lab/control/fall_arrest_controller.gd`

```gdscript
class_name FallArrestController
extends RefCounted

var linear_damping_n_s_per_m := Vector3(180.0, 240.0, 180.0)
var angular_momentum_decay_s1 := Vector3(6.0, 4.0, 6.0)
var max_requested_accel_m_s2 := 18.0

func build_intent(
        state: WholeBodyState,
        assessment: BraceAssessment) -> ControlIntent:
    var intent := ControlIntent.new()
    intent.tick = state.tick
    intent.valid_until_tick = state.tick
    intent.source = &"fall_arrest"
    intent.mode = ControlIntent.Mode.FALL_ARREST
    intent.priority = ControlIntent.PRIORITY_FALL_ARREST

    if not state.angular_momentum_available:
        intent.mode = ControlIntent.Mode.SAFE_DAMP
        intent.feasible = false
        intent.reason = &"ANGULAR_MOMENTUM_UNAVAILABLE"
        intent.diagnostics = {
            "quality": state.angular_momentum_quality,
            "unavailable_reason":
                state.angular_momentum_unavailable_reason,
        }
        return intent

    var desired_net_accel := Vector3(
        -linear_damping_n_s_per_m.x
            * state.center_of_mass_velocity_world.x
            / state.total_mass_kg,
        -linear_damping_n_s_per_m.y
            * state.center_of_mass_velocity_world.y
            / state.total_mass_kg,
        -linear_damping_n_s_per_m.z
            * state.center_of_mass_velocity_world.z
            / state.total_mass_kg)
    desired_net_accel = desired_net_accel.limit_length(
        max_requested_accel_m_s2)

    # Newton: m*a_net = F_contact + m*g.
    # Clamp the desired NET acceleration first; then add gravity
    # cancellation. Clamping a force that already contains m*g would
    # accidentally spend the acceleration budget on standing still.
    var force := (
        state.total_mass_kg
        * (desired_net_accel - state.gravity_world_m_s2))

    intent.desired_wrench.reference_point_world = (
        state.center_of_mass_world)
    intent.desired_wrench.force_world = force
    intent.desired_wrench.moment_world = Vector3(
        -angular_momentum_decay_s1.x
            * state.angular_momentum_about_com_world.x,
        -angular_momentum_decay_s1.y
            * state.angular_momentum_about_com_world.y,
        -angular_momentum_decay_s1.z
            * state.angular_momentum_about_com_world.z)
    intent.desired_wrench.source_id = &"fall_arrest.body_wrench"
    intent.contact_plan = assessment.best_arrest_contact_plan
    intent.reason = assessment.strategy_reason
    return intent
```

The fixture will almost certainly force these numbers to change. Their value is that every unit and
dependency is explicit. The allocator still enforces unilateral contact, friction, load-rate,
actuator, and structural limits; `max_requested_accel_m_s2` alone does not make the request
physically feasible. `SAFE_DAMP` here is an honest degraded/no-certified-wrench result: passive
tissues may continue and the supervisor may choose a separately proven protective action, but the
run cannot promote fall arrest. A certified rigid-composite fixture may use its explicitly
available exact alternate channel; no controller substitutes root angular velocity or zero for
missing articulated \(L_C\).

### 11.6 Energy and impulse honesty

Motor work:

\[
W_{\text{motor}}
=
\sum_j\int \tau_{\text{active},j}\dot q_j\,dt
\]

Keep signed work:

```text
positive motor work    actuator adds mechanical energy
negative motor work    actuator absorbs/brakes mechanical energy
absolute motor effort  integral of |tau * qdot|, useful but not energy balance
```

Contact impulse:

\[
J_{\text{contact}}
=
\sum_k J_k
\]

Root scaffold intervention must track **both**:

```text
scaffold linear impulse = integral(F_scaffold dt)
scaffold angular impulse = integral(tau_scaffold dt)
scaffold signed work = integral(F dot v + tau dot omega) dt
```

Work alone is insufficient: a rail or constraint may apply decisive impulse while doing nearly zero
work. Therefore an unassisted gate requires zero unauthorized scaffold force/torque/impulse, not
merely low scaffold work.

### 11.7 Catch-step fixture

The planar catch rig starts from a reproducible pushed state:

```text
root + two stance legs in sagittal plane
one stance foot initially bearing
one candidate catch foot initially clear
known horizontal impulse at a declared tick
no yaw/roll freedom
no root assist
```

Sweep:

- push magnitude;
- push direction;
- catch-foot reach;
- actuator speed/power;
- friction;
- reaction delay;
- contact confirmation delay.

Expected phase order:

```text
STAND
-> PRECARIOUS
-> BRACE
-> catch foot TOUCH
-> LOAD
-> BEARING
-> STABILIZE
-> COMPLETE
```

An allowed alternate result is an explicit infeasible failure:

```text
BRACE
-> FALL_ARREST
-> FALLEN
-> FAILED(CATCH_UNREACHABLE_BEFORE_IMPACT)
```

It is not acceptable to remain in `STAND` until the existing terminal fall check fires.

### 11.8 Fall-arrest promotion gate

A catch passes only if:

- the fall detector fires before forbidden impact;
- the selected foot was reachable under declared actuator limits;
- contact becomes bearing before the deadline;
- peak active torque, power, passive torque, and structural torque are all separately legal;
- whole-system linear momentum and centroidal angular momentum \(L_C\) change as predicted;
- no pose teleport, root force, or root torque is used;
- a replay with the same seed reproduces the same event ordering;
- at least one negative control fails for the expected reason.

Negative controls:

```text
actuator capacity = 0
friction below required cone
reaction delay greater than time-to-impact
catch foot outside reach
contact reporting disabled
```

---

## 12. Fallen-state classification and getting up

### 12.1 Do not use root height alone

The current rollout's fall logic is a terminal evaluator based heavily on low root/CoM height and
prolonged attitude failure. Recovery needs a pose classifier that distinguishes:

```text
upright but crouched
upright but kneeling
belly/prone
back/supine
left side
right side
tangled/self-colliding
unsupported/freefall
unknown or sensor-invalid
```

Features:

- authored anatomical up, forward, and right axes relative to world up;
- CoM height relative to morphology scale;
- which named body regions contact ground;
- contact normals and persistence;
- root linear/angular speed;
- limb reach and joint-limit state;
- self-contact graph;
- number and location of bearing contacts.

### 12.2 Pose classification result

Target file: `scripts/lab/control/pose_classifier.gd`

```gdscript
class_name PoseClassification
extends RefCounted

var pose: StringName = &"unknown"
var confidence := 0.0
var evidence: Dictionary = {}
var stable_for_ticks := 0
var sensor_valid := true
```

Example deterministic first pass:

```gdscript
static func classify(
        state: WholeBodyState,
        spec: PoseClassifierSpec) -> PoseClassification:
    var out := PoseClassification.new()
    if (
            not state.finite
            or not state.support_height_available
            or not state.anatomical_axes_available
            or not state.anatomical_up_world.is_finite()
            or not state.anatomical_forward_world.is_finite()
            or not state.anatomical_right_world.is_finite()):
        out.sensor_valid = false
        out.pose = &"unknown"
        out.confidence = 0.0
        out.evidence = {"reason": &"POSE_FEATURE_UNAVAILABLE"}
        return out

    var up_dot := state.anatomical_up_world.dot(Vector3.UP)
    var forward_dot_up := (
        state.anatomical_forward_world.dot(Vector3.UP))
    var right_dot_up := (
        state.anatomical_right_world.dot(Vector3.UP))
    var normalized_height := (
        state.support_height_m
        / maxf(spec.reference_stance_height_m, 1.0e-4))

    out.evidence = {
        "up_dot": up_dot,
        "forward_dot_up": forward_dot_up,
        "right_dot_up": right_dot_up,
        "contact_regions": state.contact_regions.duplicate(),
        "support_height_m": state.support_height_m,
        "normalized_height": normalized_height,
    }

    var prone_contact := spec.prone_contact_regions.any(
        func(role): return state.contact_regions.has(role))
    var supine_contact := spec.supine_contact_regions.any(
        func(role): return state.contact_regions.has(role))
    var scores := {
        &"upright": minf(
            PoseMath.threshold_margin(
                up_dot, spec.upright_up_dot_min),
            minf(
                PoseMath.threshold_margin(
                    normalized_height,
                    spec.upright_height_ratio_min),
                1.0 if state.has_foot_support else -1.0)),
        &"prone": minf(
            PoseMath.threshold_margin(
                -forward_dot_up, spec.face_vertical_dot_min),
            1.0 if prone_contact else -1.0),
        &"supine": minf(
            PoseMath.threshold_margin(
                forward_dot_up, spec.face_vertical_dot_min),
            1.0 if supine_contact else -1.0),
        &"left_side": PoseMath.threshold_margin(
            right_dot_up, spec.side_vertical_dot_min),
        &"right_side": PoseMath.threshold_margin(
            -right_dot_up, spec.side_vertical_dot_min),
    }
    var ranked := PoseMath.rank_scores(scores)
    var best: Dictionary = ranked[0]
    var second: Dictionary = ranked[1]
    var ambiguity_margin := (
        float(best["score"]) - float(second["score"]))

    if (
            float(best["score"]) < 0.0
            or ambiguity_margin < spec.minimum_class_margin):
        out.pose = &"unknown"
        out.confidence = 0.0
    else:
        out.pose = best["pose"]
        out.confidence = clampf(
            minf(float(best["score"]), ambiguity_margin),
            0.0,
            1.0)
    out.evidence["class_scores"] = scores
    out.evidence["best_second_margin"] = ambiguity_margin
    return out
```

This code is a first **profile-specific** classifier, not a universal definition of prone. A biped,
quadruped, radial body, and pogo morphology can assign different semantic axes and contact-region
oracles. Axis signs must be confirmed against LoColemotion's authored basis conventions. The first
classifier test rotates a labeled box marked HEAD/FEET/FRONT/BACK/LEFT/RIGHT through known poses and
proves every label before a creature is involved.

Negative tests cover a strong orientation axis with missing required contact evidence, invalid
support height, unavailable anatomical axes, and nearly tied side/prone scores. `confidence` means
the winning class has both positive required-evidence margin and separation from the runner-up; it
is never merely the largest absolute direction cosine.

### 12.3 Recovery profile is anatomy data, not hard-coded leg indices

Target file: `scripts/core/parts/recovery_profile.gd`

```gdscript
class_name RecoveryProfile
extends Resource

@export var profile_id: StringName
@export var accepted_start_poses: Array[StringName]
@export var required_joint_roles: Array[StringName]
@export var candidate_contact_roles: Array[StringName]
@export var forbidden_contact_roles: Array[StringName]
@export var phases: Array[RecoveryPhase]
@export var maximum_duration_s := 5.0
@export var minimum_torque_reserve_fraction := 0.15
```

Example roles:

```text
front_left_foot
front_right_foot
rear_left_foot
rear_right_foot
left_knee_pad
right_knee_pad
ventral_body
dorsal_body
head_protection
```

The profile can represent a biped, quadruped, pogo foot, microtoe friction pad, a separately
authored adhesive pad, tentacled body, or stranger morphology as long as it declares usable contact
roles and driven joints.

### 12.4 Recovery phases

Each phase is a guarded objective:

```gdscript
class_name RecoveryPhase
extends Resource

@export var phase_id: StringName
@export var desired_contact_roles: Array[StringName]
@export var released_contact_roles: Array[StringName]
@export var joint_targets_rad: Dictionary
@export_enum("support_plane", "anatomical_at_phase_entry")
var desired_com_region_frame := "support_plane"
@export var desired_com_region_m: AABB
@export var desired_root_up_min_dot := -1.0
@export var maximum_duration_s := 1.0
@export var success_dwell_ticks := 6
@export var failure_conditions: Array[StringName]
```

At phase entry, resolve `desired_com_region_m` through the current support-plane/anatomical frame
into a frozen world-space goal and record both authored and resolved forms. Do not let an `AABB`
silently mean world coordinates, and do not recompute a moving anatomical frame every tick unless
the phase explicitly declares a tracking frame. The `_m` suffix and schema enforce SI units.

A quadruped prone profile might be:

```text
0 SETTLE_AND_CLASSIFY
  wait for low enough velocity to choose a reproducible plan

1 ESTABLISH_FRONT_SUPPORT
  place/load front feet or forelimb pads

2 ESTABLISH_REAR_SUPPORT
  place/load rear feet while preserving front contacts

3 LIFT_CORE
  increase total vertical support and CoM height

4 TUCK_UNDER
  move feet under projected CoM; do not chase nominal height yet

5 EXTEND_TO_STANCE
  raise CoM while maintaining reserve and contact

6 STABILIZE
  hand off to stance and require stable dwell
```

A supine biped may require a roll-to-side phase before it can create a useful support polygon.
Profiles should be allowed to transform one fallen pose into another deliberately.

### 12.5 Recovery feasibility

Before applying commands, answer:

```text
Does the morphology contain every required role?
Can candidate contacts reach a surface?
Is the next phase collision-compatible?
Can active torques overcome gravity at current joint angles?
Can actuator power raise the CoM at requested speed?
Can friction support the required horizontal force?
Can the profile avoid forbidden body contacts?
Is there enough structural margin?
```

For phase \(k\), define a conservative feasibility margin:

\[
\rho_k
=
\min_j
\left(
\frac{\tau_{\max,j}-|\tau_{\text{required},j}|}
{\max(\tau_{\max,j},\epsilon)}
\right)
\]

and similarly for power and friction. Then:

\[
\rho_k < 0
\Rightarrow
\text{declared infeasible}
\]

This estimate can be conservative. It must not claim feasibility when an obvious static load already
exceeds capacity.

### 12.6 Proposed recovery controller

Target file: `scripts/lab/control/recovery_controller.gd`

```gdscript
class_name RecoveryController
extends RefCounted

var profile: RecoveryProfile
var phase_index := 0
var phase_ticks := 0
var success_dwell := 0
var profile_ticks := 0
var finished := false
var terminal_failure: StringName

func begin(selected_profile: RecoveryProfile) -> RecoveryEvent:
    profile = selected_profile
    phase_index = 0
    phase_ticks = 0
    success_dwell = 0
    profile_ticks = 0
    finished = false
    terminal_failure = &""
    if profile == null:
        terminal_failure = &"RECOVERY_PROFILE_MISSING"
        return _terminal_event(&"failure", terminal_failure)
    if profile.phases.is_empty():
        terminal_failure = &"RECOVERY_PROFILE_EMPTY"
        return _terminal_event(&"failure", terminal_failure)
    return _phase_event(&"begin", profile.phases[0])

func build_intent(
        state: WholeBodyState,
        support: SupportSnapshot,
        delta: float) -> ControlIntent:
    var intent := ControlIntent.new()
    intent.tick = state.tick
    intent.valid_until_tick = state.tick
    intent.source = &"recovery"
    intent.mode = ControlIntent.Mode.RECOVERY
    intent.priority = ControlIntent.PRIORITY_RECOVERY

    if (
            profile == null
            or finished
            or terminal_failure != &""
            or phase_index < 0
            or phase_index >= profile.phases.size()):
        intent.feasible = false
        intent.reason = (
            terminal_failure
            if terminal_failure != &""
            else &"RECOVERY_PHASE_INDEX_INVALID")
        return intent

    var phase: RecoveryPhase = profile.phases[phase_index]
    var feasibility := RecoveryFeasibility.evaluate(
        state, support, profile, phase)

    if not feasibility.feasible:
        intent.feasible = false
        intent.reason = feasibility.reason
        intent.diagnostics = feasibility.to_dictionary()
        return intent

    intent.contact_plan = _build_contact_plan(phase, state)
    intent.joint_preferences = phase.joint_targets_rad
    intent.desired_wrench = _build_phase_wrench(
        phase, state, support)
    intent.reason = phase.phase_id
    return intent
```

Phase advancement happens only from observed post-step state:

```gdscript
func observe_result(
        state: WholeBodyState,
        support: SupportSnapshot) -> RecoveryEvent:
    if profile == null or profile.phases.is_empty():
        return _terminal_event(
            &"failure", &"RECOVERY_PROFILE_INVALID")
    if finished:
        return RecoveryEvent.none()
    if phase_index < 0 or phase_index >= profile.phases.size():
        return _terminal_event(
            &"failure", &"RECOVERY_PHASE_INDEX_INVALID")

    var phase: RecoveryPhase = profile.phases[phase_index]
    phase_ticks += 1
    profile_ticks += 1

    if profile_ticks > _seconds_to_ticks(
            profile.maximum_duration_s):
        return _terminal_event(
            &"failure", &"RECOVERY_PROFILE_TIMEOUT")

    if _phase_success(phase, state, support):
        success_dwell += 1
        if success_dwell >= phase.success_dwell_ticks:
            if phase_index + 1 >= profile.phases.size():
                finished = true
                return _terminal_event(
                    &"complete", &"RECOVERY_PROFILE_COMPLETE")
            phase_index += 1
            phase_ticks = 0
            success_dwell = 0
            return _phase_event(
                &"begin", profile.phases[phase_index])
    else:
        success_dwell = 0

    if phase_ticks > _seconds_to_ticks(phase.maximum_duration_s):
        return _fail_phase(phase, &"RECOVERY_PHASE_TIMEOUT")

    return RecoveryEvent.none()
```

This prevents a controller from declaring success from its own target rather than the body's
response. `_terminal_event()` is idempotent, records final phase/profile elapsed time, and never
increments `phase_index` beyond the array. A supervisor may transition to `STABILIZE` only after the
final observed completion event and an independent upright-and-supported assessment.

### 12.7 Recovery must allow pushing through non-foot contacts

Biological and strange bodies use elbows, knees, sides, tails, tentacles, shells, and the ground
itself as intermediate supports. A foot-only definition of support blocks plausible get-up
strategies.

Every contact role declares:

```text
may_bear_load
may_slide
maximum normal load
friction estimate
damage/cost weight
allowed recovery phases
allowed steady-stance use
```

This preserves a clean distinction:

- a knee can be a legal temporary recovery support;
- the same knee may be forbidden as evidence of standing;
- body impact can be tracked without counting as successful stance.

### 12.8 Recovery energy gate

To raise the CoM by \(\Delta h\):

\[
\Delta U_g
=
mg\Delta h
\]

The narrow height-only inequality is usable only when the run begins and ends near rest, passive
energy is explicitly accounted, the ground is stationary, and there is no disturbance:

\[
\Delta(K+U_g+E_\text{passive})
\le
W_{\text{active,signed}}
+
W_{\text{dynamic contact}}
-
E_{\text{dissipated}}
+
\epsilon_{\text{ledger}}
\]

The complete equality, including scaffold and disturbance terms, is defined in Section 14.10. On a
static floor, ideal contact does no net work at a stationary contact point, but collision impulses,
moving ground, slip, and constraint stabilization can invalidate that simplification. If the
measured mechanical-state change is unexplained, inspect:

- root forces;
- pose writes;
- constraint work;
- collision correction;
- incorrect energy accounting;
- stale before/after timestamps.

### 12.9 Recovery promotion gate

For each canonical fallen pose, require:

- deterministic pose classification;
- a named feasible or infeasible result before actuation;
- observable phase transitions;
- legal intermediate support contacts;
- no forbidden root intervention;
- no joint command outside active/passive/structural envelopes;
- CoM height gain explained by energy sources;
- final upright-and-supported dwell;
- successful transition to ordinary stance;
- negative controls that fail with specific codes.

Getting upright for one frame is not recovery. Recovery ends only after the stance controller owns
the body and maintains the stable dwell without recovery commands.

---

## 13. Morphology feasibility and strange-body support

### 13.1 The controller cannot manufacture missing degrees of freedom

The current creature builder creates `HingeJoint3D` constraints in
[`creature_body.gd`](../scripts/sim/creature_body.gd#L240-L255). The socket model exposes
`hinge_axis_2`, but explicitly says the second axis is authored for future use and is not currently
driven in [`socket_def.gd`](../scripts/core/socket_def.gd#L15-L63).

That means the current runtime is effectively one driven rotational degree of freedom per joint.
Consequences:

- a nominal hip cannot independently flex and abduct unless the morphology has separate joints;
- a sagittal leg may be unable to widen its support polygon laterally;
- a biped can be controllable on a planar rail yet impossible in 3D;
- a catch target may be geometrically close but unreachable in the driven joint subspace;
- a controller failure may be correct evidence of morphology infeasibility.

Do not tune gains around missing actuation. Either add a real joint/axis, change morphology, or declare
the task infeasible.

### 13.2 Build-time `MorphologyControlReport`

Target file: `scripts/lab/control/recovery_feasibility.gd` or a dedicated
`scripts/lab/mechanics/morphology_control_report.gd`.

```gdscript
class_name MorphologyControlReport
extends RefCounted

var feasible_for_fixture := false
var fixture_id: StringName
var body_dofs := 0
var driven_joint_dofs := 0
var candidate_support_roles: Array[StringName] = []
var missing_roles: Array[StringName] = []
var unreachable_wrench_axes: Array[StringName] = []
var static_torque_margins: Dictionary = {}
var power_margins: Dictionary = {}
var reasons: Array[StringName] = []
```

The report answers fixture-specific questions. A pogo foot can be feasible for vertical height
regulation while infeasible for unassisted 3D attitude. That is useful knowledge, not a failed
creature.

### 13.3 Rank of the support map

Contact forces map to a body wrench:

\[
w=A\lambda
\]

where columns of \(A\) encode contact force directions and moment arms. If the relevant rows of
\(A\) do not have sufficient rank, the contact arrangement cannot control all requested wrench
components.

Examples:

- one frictionless point contact can push along one normal but cannot pull;
- two collinear contacts may control vertical force and one pitch moment but not yaw;
- a broad multi-point foot can produce a larger moment range;
- multiple gecko toes can create a wide distributed support region if their contacts are actually
  independent;
- motorless tentacles provide passive collision and damping but no arbitrary active wrench.

The allocator should report rank/conditioning warnings before control:

```text
SUPPORT_MAP_RANK_DEFICIENT
SUPPORT_MAP_ILL_CONDITIONED
REQUESTED_WRENCH_OUTSIDE_CONTACT_CONE
```

### 13.4 Joint-space controllability

The limb maps joint torques to a contact force through \(J^T\). A near-singular or rank-deficient
Jacobian means some force directions require enormous torque or cannot be produced.

Useful logged values:

```text
Jacobian singular values
condition number
per-joint moment arm for requested force
force-direction feasibility
distance to joint limits
speed-direction feasibility
```

The condition number is diagnostic, not a sole failure test. A singular value may be irrelevant if
the corresponding force direction is not needed in the current fixture.

### 13.5 Strength, speed, and power are independent axes

A limb may:

- have enough static torque to hold;
- lack enough speed to place a catch foot;
- have enough no-load speed and enough stall torque separately;
- still lack enough power in the middle of the motion;
- survive active torque but exceed structural torque when passive tissue adds load.

Therefore morphology evaluation contains at least:

\[
\text{static reserve}
=
\tau_{\max}-|\tau_{\text{required}}|
\]

\[
\text{speed reserve}
=
\dot q_{\max}-|\dot q_{\text{required}}|
\]

\[
\text{power reserve}
=
P_{\max}-|\tau\dot q|
\]

\[
\text{structural reserve}
=
\tau_{\text{structural}}-|\tau_{\text{total}}|
\]

Do not collapse these to a single "muscle strength" scalar in evidence.

### 13.6 Scaling active capacity from anatomy

The constants near
[`CharacteristicsEvaluator.gd`](../scripts/core/CharacteristicsEvaluator.gd#L121-L122) are legacy
torque-per-inertia calibration knobs, not muscle-density or muscle-stress measurements. The runtime
currently estimates a bounded muscle fraction in
[`joint_model.gd`](../scripts/sim/joint_model.gd#L40-L64).

Eventually, an anatomy-derived maximum joint torque can follow:

\[
\tau_{\max}
\approx
\sigma_{\text{muscle}}
A_{\text{physiological}}
r_{\text{moment arm}}
\eta
\]

where:

- \(\sigma_{\text{muscle}}\) is muscle stress in N/m²;
- \(A_{\text{physiological}}\) is physiological cross-sectional area in m²;
- \(r\) is effective moment arm in m;
- \(\eta\) represents geometry/efficiency.

But the actuator dyno must first prove an explicit `ActuatorSpec`. If an anatomy formula and actuator
integration are introduced simultaneously, a failure cannot be isolated.

### 13.7 Passive tissue is not free active strength

A spring:

\[
\tau_s=-k(q-q_0)-c\dot q
\]

can support load around its rest angle and return stored energy. It cannot choose arbitrary torque
independently of deformation.

A unilateral tendon or ligament may be modeled later as:

\[
T
=
\begin{cases}
\max(0,k_t e+c_t\dot e), & e>0 \\
0, & e\le0
\end{cases}
\]

where \(e\) is extension beyond slack length and \(T\) is nonnegative tension. Map it through the
extension gradient:

\[
\tau_j=-\frac{\partial e}{\partial q_j}T
\]

This prevents a rapidly shortening tendon from numerically becoming a compressive pusher. It is
different from the initial bilateral conservative generalized coupling in Section 6.3. The initial
model exists to validate bookkeeping; the unilateral anatomical model should replace it only with a
stretch/slack/release oracle.

Passive torque can:

- improve static economy;
- worsen a catch by resisting required flexion;
- destabilize a controller if counted as active reserve;
- exceed structural limits when added after active clamp;
- inject numerical energy if evaluated from stale \(q,\dot q\).

### 13.8 The weird rigs are not distractions

The following bodies isolate useful control facts:

| Rig | What it teaches | Promotion value |
|---|---|---|
| one pogo foot on a rail | vertical force, active/passive energy, load rate | base support law |
| wide cup foot | pressure distribution and moment authority | attitude without gait |
| umbrella feeler ring | earliest contact angle and tip direction | fall sensing |
| 24 or more micro-toes | contact identity, support hull, load sharing | distributed support |
| gecko-like friction pad with compliant digits | staged contact creation and local slip | high-contact allocator |
| passive hanging tentacles | momentum observability and damping | inertial witness channels |
| active tail | internal angular momentum exchange | body attitude without fake root torque |
| sacrificial knee/elbow pads | protective fall arrest | recovery contact roles |

Each rig still obeys the same data and evidence contracts. Weird geometry is encouraged; bespoke
telemetry or secret control paths are not.

Multiple solver points on one rigid cup/pad are not automatically independent actuators. They may
describe a richer measured pressure distribution, but the allocator can request only a resultant
wrench realizable by the rigid foot, its frictional contact cone, and its driven joints. If the
solver's individual point impulses are not independently commandable, classify them as one contact
patch for actuation while retaining the raw points for center-of-pressure evidence.

#### 13.8.1 Twenty-four-direction sensor umbrella

“Every 15 radians” should be implemented as every **15 degrees** around one ring:

\[
\phi_i=i\frac{\pi}{12},
\qquad i\in\{0,\ldots,23\}
\]

Fifteen radians is about \(859^\circ\), so it is not the intended angular spacing.

Build two deliberately different rigs:

**Virtual umbrella**

```text
24 non-contact radial distance/shape queries
known origin and direction in the authored anatomical frame
distance, hit point, hit normal, collider stable ID
range rate from synchronized adjacent frames
no collision shape, mass, force, or contact
```

For clearance \(d\) and closing rate \(\dot d\):

\[
t_\text{hit}
=
\begin{cases}
0, & d\le d_\text{clearance} \\
\dfrac{d-d_\text{clearance}}{-\dot d},
& \dot d<-\epsilon \\
\infty, & \dot d\ge-\epsilon
\end{cases}
\]

The ray/query timing and physics-space snapshot are manifest data. A query result can inform the
detector; it can never become a force.

**Physical feeler umbrella**

```text
24 passive whiskers with real mass/inertia/joints/collision
contact sequence and bend/velocity channels
all ground reactions included in support/momentum accounting
with/without-whisker A/B trajectory
```

A physical feeler that touches the ground may brace the body, dissipate energy, or trip it. It is
an anatomical appendage, not a noninvasive sensor. Run the virtual umbrella first to calibrate fall
direction/time-to-contact; add physical feelers only when that perturbation is the experimental
subject.

#### 13.8.2 Cup, ring, and “untippable” pogo-foot card

Compare equal-total-mass/equal-material/equal-outer-radius feet:

```text
flat pad
wide ring
compound-convex cup
low-CoM weighted ring
active two-axis ankle variant
```

Do not call any of them untippable. Measure a stability basin:

```text
24 horizontal push directions
multiple impulse magnitudes and application heights
flat floor plus preregistered slopes
nominal and low friction
with ankle disabled, passive, and active
```

Primary outputs:

```text
center-of-pressure excursion before edge loss
maximum recoverable impulse by direction
tip axis and time-to-boundary prediction error
slip-before-tip versus tip-before-slip
passive/active/scaffold energy and impulse
return-to-support dwell
```

A cup that appears stable because its compound collision geometry interlocks with the floor fails
the low-friction and geometry-rotation controls. A rotation-locking rail can certify the vertical
pogo energy cycle, but only the later free-foot basin can establish passive/active anti-tip
authority.

#### 13.8.3 Hundred-finger foot card

The first 1/4/16/64/100-element experiment keeps total projected area, nominal material, total foot
mass, outer footprint, floor, and imposed load constant. It asks what contact discretization alone
changes:

```text
reported/raw contact count
normal-load distribution and center of pressure
chatter and contact lifetime
slip onset
solver/timestep sensitivity
CPU time and trace volume
trajectory divergence
```

Only after `L1.8` passes should digits gain compliance. Only after passive compliance passes should
some digits gain actuators. Use a hierarchical controller:

```text
whole-body allocator
  -> desired resultant wrench for this foot patch
  -> foot-level feasibility under ankle/joint limits
  -> toe load-sharing allocator
  -> per-toe actuator/passive pipeline
```

This avoids granting a rigid foot one hundred fictional independent control inputs. Log both patch
residual and toe-allocation residual. Compare passive, grouped-actuator, and fully independent
actuator variants at equal total motor mass/power so “more toes” is not secretly “more muscle.”

### 13.9 Micro-toe scaling rules

A hundred toes can overwhelm the current contact cap of eight configured in
[`creature_body.gd`](../scripts/sim/creature_body.gd#L23-L33). For distributed-foot experiments:

1. derive `max_contacts_reported` from expected simultaneous contacts plus margin;
2. record configured cap and observed peak;
3. flag `CONTACT_BUFFER_SATURATED` when observed count reaches the cap;
4. cluster raw points into pressure cells only **after** raw capture;
5. retain toe/body/shape identity;
6. compare clustered total impulse with raw total impulse.

Never infer "eight toes touched" merely because the observer returned eight contacts at an
eight-contact cap.

Ordinary Jolt contact plus friction is not gecko adhesion. A real adhesive experiment is a later,
separate capability with a tensile normal bound:

\[
-F_{\text{adh,max}}
\le
n\cdot\lambda
\]

It requires attach/detach state, engagement rate, detachment work, energy/source accounting, surface
compatibility, and negative controls with adhesion disabled. Until then, call the rig a
`microtoe_friction_pad`, not an adhesive gecko foot.

### 13.10 Tentacles as witnesses versus actuators

Motorless tentacles can be useful inertial witnesses:

```text
tip height
tip velocity
tip angular momentum proxy
contact sequence
lag relative to root motion
```

They should not be fed into a controller until their sensing model is validated. First use them as
an independent visual/recorded correlate of rotation and acceleration. Later, if actuated, they need
the same actuator spec, ledger, and energy accounting as every other limb.

Even motorless tentacles change mass distribution, inertia, collision, drag-like contact loss, and
the body's natural modes. Every witness experiment therefore runs an A/B pair:

```text
same root/limbs without witness tentacles
same total authored body with witness tentacles
```

Record tentacle mass fraction, inertia contribution, length, damping, collision layers, and contact
work. A tentacle signal can be called an informative correlate only after its physical perturbation
is quantified.

---

## 14. Observability and evidence contract

### 14.1 The recorder is part of the physics experiment

If tick labels, coordinate frames, command timing, or missing data are ambiguous, a beautiful graph
can support a false conclusion. The evidence pipeline is therefore promoted and tested alongside
the controller.

The controller receives a read-only capability. It does not receive a mutable
`ExpandedExperiment` resource or a raw `RandomNumberGenerator`:

```gdscript
class_name LabControlContext
extends RefCounted

var _expanded_experiment: Dictionary   # deep-frozen compiled value
var _expanded_spec_sha256: String
var _rng_streams: Dictionary[StringName, RandomStreamCapability]

func expanded_experiment() -> Dictionary:
    return _expanded_experiment

func rng(stream_id: StringName) -> RandomStreamCapability:
    assert(_rng_streams.has(stream_id))
    return _rng_streams[stream_id]

func assert_spec_unchanged() -> void:
    assert(_expanded_experiment.is_read_only())
    assert(
        CanonicalJson.sha256(_expanded_experiment)
        == _expanded_spec_sha256)
```

`LabControlContext` contains bind-time capabilities only. The per-tick deep-frozen `SensorFrame` and
append-only `CommandSink` arrive as arguments to `decide(frame, command_sink)`, so a controller
cannot retain a context whose apparent “current frame” silently changes. Controllers do not receive
raw `RigidBody3D` nodes. This prevents accidental transform writes, direct force calls, or extra
post-observation reads. Context construction deep-freezes the expanded spec, verifies its hash,
constructs the RNG-capability map, calls `make_read_only()` on that map, and then binds the
controller. `assert_spec_unchanged()` runs at bind, every evidence flush, and completion.

`RandomStreamCapability` owns exactly one named stream. Its public API permits typed draws such as
`randf()`, `randf_range()`, and `randi_range()` and exposes only `stream_id`, `seed_sha256`, and
`draw_count`. It has no public seed setter, reseed method, raw-generator getter, or replacement
method. Every draw increments the count recorded in the manifest/runtime notes. A static ownership
gate rejects controller references to `RandomNumberGenerator`, `_rng`, `seed`, or `state` **and**
rejects unqualified/global calls to `randf`, `randi`, `randfn`, `randf_range`, `randi_range`,
`randomize`, and `rand_from_seed`. Controller draws must be syntactically rooted at
`context.rng(<registered-stream-id>)` (or a capability variable produced by that getter), which the
AST/linter resolves rather than trusting a text substring. A runtime test proves a controller
cannot reseed or replace a stream after the manifest is sealed; a negative controller using global
`randf()` must fail the static gate. The actual seed remains in the trusted runner/manifest so the
run is reproducible.

### 14.2 Canonical tick order

Use one declared order:

```text
Frame N committed post-step
  -> controllers read Frame N
  -> intents generated for command tick N
  -> intent/decision finite-path validation
  -> arbiter resolves ownership
  -> active/passive/structural clamps evaluated
  -> resolved command and intervention-plan finite-path validation
  -> CommandRecord N with planned operation IDs sealed
  -> executor applies planned operations and appends ExecutionReceipts
  -> intervention executor applies declared fixture operations and appends receipts
  -> application streams flush before physics step N -> N+1
  -> engine advances
  -> direct-state callbacks capture body/contact facts
  -> raw Frame N+1 assembled
  -> finite/path validation and terminal sanitization branch
  -> valid Frame N+1 support/mechanics fields derived and validated
  -> derived events evaluated from Frame N+1
  -> derived frame/mechanics/event finite-path validation
  -> Frame N+1 and EventRecords committed
  -> abort/promotion checks run
```

This means command \(N\) causes the transition from frame \(N\) to frame \(N+1\). Store both IDs.
Never graph a command against a same-numbered post-step frame without documenting the relationship.

A non-finite value cannot be passed to `CanonicalJson`, but the failure still needs inspectable
evidence. The same deterministic path walker runs before **every serialized-record boundary**,
including at least:

```text
raw frame, before derived state or controller execution
derived frame/support/mechanics/event candidates, before commit
controller intents and DecisionRecord builder, before arbitration/sealing
resolved command and intervention builders, before sealing/execution
runtime notes, summaries, comparisons, and campaign aggregates, before commit/finalization
```

The failure branch is therefore:

```text
assemble the candidate frame/intent/decision/command/intervention value
-> walk every field in deterministic JSON-pointer order
-> on first NaN / +Inf / -Inf:
     replace every non-finite serialized value with null
     availability[path] = {
       status: invalid,
       reason: NAN | POS_INF | NEG_INF,
       source: observer/component ID
     }
     emit NONFINITE_DETECTED with first path/source and total bad-field count
     commit the sanitized terminal record, runtime note, and event
     controlled safety abort
     do not run later derivation/arbitration for that candidate
     do not seal or execute the original value
     if application has not occurred, do not apply any command/intervention from that tick
     if detected during final aggregation, leave the bundle partial and evidence-invalid
-> otherwise continue normal derivation/control
```

For a rejected intent/command, the sanitized terminal evidence uses
`status: rejected_nonfinite`, `null` at each invalid field, and an empty
`planned_application_operations` list. It may be sealed as failure evidence, but it is never passed
to an executor. The raw in-memory non-finite payload never reaches canonical JSON. Negative tests
inject NaN separately into a body channel, controller intent, passive-tissue result, resolved
command, fixture intervention, mechanics-derived residual, event field, and summary aggregation;
each `.partial` bundle must name the first source/path, contain no post-rejection application
receipt, and keep every JSONL line parseable.

### 14.3 Sample phases

`SamplePhase` is one registry used by every in-memory type and schema:

```text
pre_control
command_sealed
pre_integrate
integrate_callback
post_step
derived
```

`ExperimentPhase` is orthogonal:

```text
CONFIGURE
SPAWN
SETTLE_SCAFFOLDED
RELEASE
WARMUP
MEASURE
COOLDOWN
TERMINATED
```

Every frame stores both. The expanded spec declares which command/intervention types are allowed in
each experiment phase. Spawn placement is a declared setup operation; any pose/velocity write after
`release_frame_id` becomes an intervention and normally emits `UNAUTHORIZED_INTERVENTION`.
Schema validation rejects any phase outside these registries.

Every field also has an availability status:

```text
measured
engine_estimate
derived
commanded
unavailable
invalid
```

Missing data is `null` plus status/reason. Zero means a measured or commanded zero.

Serialized availability is a JSON-pointer map, so nested arrays do not need shadow fields with
ambiguous alignment:

```json
{
  "availability": {
    "/contacts/0/impulse_n_s": {
      "status": "engine_estimate",
      "reason": "JOLT_MULTI_CONTACT_LIMITATION"
    },
    "/whole_body/rotational_kinetic_energy_j": {
      "status": "unavailable",
      "reason": "LOCKED_AXIS_INERTIA_SINGULAR"
    }
  }
}
```

Every optional field has exactly one entry when it is unavailable, invalid, estimated, or derived.
Schema validation rejects a numeric placeholder paired with `unavailable`.

#### 14.3.1 Spec compilation

The runner never executes a partially defaulted `ExperimentSpec` directly. `SpecCompiler` produces
an immutable `ExpandedExperiment`:

```text
authored ExperimentSpec
  < registered campaign/matrix patch
  < explicit command-line override
```

Ambient environment variables do not silently set scientific parameters.

Compilation performs:

```text
schema version migration
default expansion
unit validation
finite-value and parameter-domain validation
stable ID validation
fixture/controller compatibility
required observer-channel validation
allowed/forbidden scaffold validation
canonical key ordering
canonical serialization
SHA-256 expanded_spec_sha256
```

The manifest stores the authored resource hash, every applied override, the fully expanded
parameters, and `expanded_spec_sha256`. A dry run must reject:

- unknown fields or schema versions;
- values without required units;
- non-finite values or actuator fields outside the Section 5.2 domain table;
- more than one undeclared independent variable;
- a gate requiring a channel the observer profile does not capture;
- a controller requesting a capability the fixture forbids;
- hidden debug defaults.

### 14.4 Run manifest

One `manifest.json` per run:

```json
{
  "schema": "sporespore.lab.manifest.v1",
  "run_id": "20260718T213045Z_BR06_rail_leg_seed-0042",
  "status": "RUNNING",
  "experiment_id": "BR06_RAIL_LEG_HOLD",
  "hypothesis_id": "H-BRACE-004",
  "experiment_resource_path": "res://data/lab/experiments/BR06_rail_leg_hold_v1.tres",
  "experiment_resource_sha256": "sha256:...",
  "fixture_version": 3,
  "fixture_resource_path": "res://scripts/lab/rigs/rail_leg_rig.gd",
  "fixture_resource_sha256": "sha256:...",
  "schema_set": "sporespore.lab.schemas.v1",
  "recorder_version": "flight-recorder-v1",
  "expanded_spec_sha256": "sha256:...",
  "git_commit": "CURRENT_OR_EXPLICIT_DIRTY",
  "dirty_worktree": true,
  "dirty_diff_sha256": "sha256:...",
  "execution_mode": "development",
  "reproducibility": "partial_dirty_source",
  "godot_version": "4.7.stable.mono.official.5b4e0cb0f",
  "godot_commit": "5b4e0cb0fd279832bbdd69fed5354d4e5ad26f88",
  "physics_backend": "Jolt Physics 3D",
  "physics_backend_adapter": "jolt_direct_state_v1",
  "platform": "windows-x86_64",
  "physics_ticks_per_second": 60,
  "solver_velocity_iterations": 20,
  "solver_position_iterations": 4,
  "observer_profile": "full_contacts_v1",
  "observer_parity_envelope_id": "L0_3_jolt_full_contacts_v1",
  "contact_cap_per_body": 32,
  "process_isolation": "fresh_process_per_canonical_run",
  "body_dynamics": {
    "root": {
      "mass_kg": 8.4,
      "center_of_mass_mode": "custom",
      "center_of_mass_local_m": [0.0, -0.03, 0.0],
      "inertia_source": "engine_direct_state",
      "gravity_scale": 1.0,
      "linear_damp_mode": "replace",
      "linear_damp_s1": 0.0,
      "angular_damp_mode": "replace",
      "angular_damp_s1": 0.0,
      "can_sleep": false,
      "sleeping_at_release": false,
      "freeze": false,
      "freeze_mode": "static",
      "lock_rotation": false,
      "axis_locks": [],
      "continuous_cd": false,
      "custom_integrator": false
    }
  },
  "joint_dynamics": {
    "left_knee": {
      "motor_enabled": false,
      "limit_enabled": true,
      "limit_lower_rad": -1.7,
      "limit_upper_rad": 0.1,
      "limit_bias": 0.3,
      "limit_softness": 0.9,
      "limit_relaxation": 1.0
    }
  },
  "surface_materials": {
    "ground": {
      "friction": 0.8,
      "rough": false,
      "bounce": 0.0,
      "absorbent": false
    }
  },
  "seed_root": 42,
  "rng_derivation": "sporespore-lab-seed-v1-sha256-low63",
  "rng_streams": {
    "disturbance": {
      "seed": 428441,
      "consumed": true,
      "draw_count": 1
    },
    "morphology": {
      "seed": 818203,
      "consumed": false,
      "draw_count": 0
    },
    "sensor_noise": {
      "seed": 902114,
      "consumed": false,
      "draw_count": 0
    }
  },
  "scaffolds_allowed": ["vertical_rail"],
  "scaffolds_forbidden": [
    "controller_root_central_force",
    "controller_root_torque",
    "pinned_effector",
    "pose_write_after_release"
  ],
  "expanded_parameters": {},
  "comparison_role": null,
  "paired_run_id": null,
  "units": "SI",
  "started_utc": "2026-07-18T21:30:45Z"
}
```

Canonical promotion requires a clean committed worktree. A development run may be dirty and store a
diff hash for identity, but it is labeled `reproducibility: partial_dirty_source` because a hash
does not contain the source bytes and ordinary `git diff` omits untracked files. It cannot promote.
An optional diagnostic snapshot may include `source_state.patch` plus a manifest/archive of every
untracked source/resource loaded by the run, all checksummed; that improves debugging but does not
waive the clean-tree promotion rule.

Canonical promotion runs launch one fresh Godot process per run so static caches, scene-tree state,
and RNG consumption cannot leak across cells. Multi-run in-process batches are allowed for
development only and are labeled `development_batch`.

### 14.5 Frame record

Use versioned JSON Lines:

```json
{
  "schema": "sporespore.lab.frame.v1",
  "run_id": "example",
  "frame_id": 121,
  "physics_time_s": 2.016666667,
  "sample_phase": "post_step",
  "experiment_phase": "MEASURE",
  "release_frame_id": 60,
  "bodies": [
    {
      "body_id": "root",
      "position_m": [0.0, 0.731, 0.0],
      "linear_velocity_m_s": [0.0, -0.013, 0.0],
      "angular_velocity_rad_s": [0.02, 0.0, -0.01],
      "mass_kg": 8.4,
      "finite": true
    }
  ],
  "joints": [
    {
      "joint_id": "rear_left_knee",
      "q_rad": 0.44,
      "qdot_rad_s": -0.08,
      "axis_world": [0.0, 0.0, 1.0],
      "limit_state": "inside"
    }
  ],
  "contacts": [],
  "support": {},
  "availability": {}
}
```

Arrays are sorted by stable ID. Floating-point formatting is stable enough for structural diffing.

### 14.6 Command record

The following JSON is the immutable `/payload` object. Each `commands.jsonl` line wraps it as
`{"command_payload_sha256": "<SHA-256 of canonical /payload bytes>", "payload": {...}}`. The hash
field is outside the hash domain; the executor rehashes `/payload` before making any physics call.
`command_v1.schema.json` validates both the two-field envelope and the nested payload; an unknown
outer field, missing digest, or payload/schema mismatch is invalid evidence.

```json
{
  "schema": "sporespore.lab.command.v1",
  "run_id": "example",
  "command_id": 120,
  "source_frame_id": 120,
  "applied_transition": [120, 121],
  "mode": "BRACE",
  "joint_commands": [
    {
      "joint_id": "rear_left_knee",
      "actuator_spec_sha256": "sha256:...",
      "angle_rad": 0.44,
      "angular_velocity_rad_s": -0.08,
      "axis_world": [0.0, 0.0, 1.0],
      "active_components_nm": {
        "stance.body_wrench": 66.5,
        "stance.impedance": 8.4,
        "gravity.distal": 5.1
      },
      "active_component_provenance": {
        "stance.body_wrench": {
          "intent_id": "intent_120_stance",
          "source_id": "stance_controller",
          "priority": 200
        },
        "stance.impedance": {
          "intent_id": "intent_120_stance",
          "source_id": "stance_controller",
          "priority": 200
        },
        "gravity.distal": {
          "intent_id": "intent_120_stance",
          "source_id": "stance_controller",
          "priority": 200
        }
      },
      "requested_active_nm": 80.0,
      "rate_limited_active_nm": 70.0,
      "applied_active_nm": 61.0,
      "activation_previous": 0.71,
      "activation_requested": 1.0,
      "activation_applied": 0.73,
      "activation_next": 0.75,
      "activation_update_phase": "transition_mean",
      "active_lower_bound_nm": -47.0,
      "active_upper_bound_nm": 61.0,
      "selected_work_regime": "negative_work",
      "limit_causes": [
        "TORQUE_RATE",
        "ACTIVATION",
        "NEGATIVE_WORK_SPEED_CURVE"
      ],
      "torque_rate_limited": true,
      "speed_limited": true,
      "power_limited": false,
      "active_saturated": true,
      "passive_components_nm": {
        "spring.knee_extension": 2.2,
        "tendon.posterior_chain": 0.0
      },
      "requested_passive_nm": 2.2,
      "applied_passive_nm": 2.2,
      "total_pre_structure_nm": 63.2,
      "structural_cap_nm": 180.0,
      "structural_guard_reaction_nm": 0.0,
      "applied_total_nm": 63.2,
      "structural_saturated": false,
      "active_power_w": -4.88,
      "passive_power_w": -0.176,
      "structural_guard_power_w": 0.0,
      "applied_total_power_w": -5.056,
      "planned_application_operations": [
        {
          "operation_id": "op_120_knee_child",
          "body_id": "rear_left_shin",
          "torque_world_nm": [0.0, 0.0, 63.2]
        },
        {
          "operation_id": "op_120_knee_parent",
          "body_id": "rear_left_thigh",
          "torque_world_nm": [0.0, 0.0, -63.2]
        }
      ],
      "pairing_expectation": "equal_opposite_parent_child"
    }
  ],
  "intervention_operation_ids": []
}
```

`intervention_operation_ids` exists even when empty and links to
`interventions.jsonl`; the detailed mutation is not duplicated with a second schema.

Immediately before application, each command record is already a deep-frozen value snapshot. The
planned operation IDs and vectors are part of that immutable command. The executor never appends to
or rewrites it and never re-reads the mutable controller intent after sealing.

#### 14.6.1 Execution receipt

`applications.jsonl` is a discriminated receipt stream written after each actual executor call.
`source_kind` is `command` or `intervention`; both variants carry a stable source record ID, the
hash of the immutable source payload, the planned operation ID, the exact API/target/arguments
passed, call ordinal, and return/failure status:

```json
{
  "schema": "sporespore.lab.application.v1",
  "run_id": "example",
  "application_sequence": 241,
  "source_kind": "command",
  "source_record_id": "command:120",
  "source_payload_sha256": "sha256:...",
  "operation_id": "op_120_knee_child",
  "executor_call_ordinal": 0,
  "api": "RigidBody3D.apply_torque",
  "target_body_id": "rear_left_shin",
  "arguments": {
    "torque_world_nm": [0.0, 0.0, 63.2]
  },
  "status": "call_returned",
  "failure_code": null
}
```

The validator derives `paired_application_verified` only after seeing two successful receipts with
the expected bodies, the same source payload hash, and equal/opposite vectors within tolerance. The
pre-application command may state the pairing expectation; it cannot state that application already
succeeded. If a controlled executor failure occurs between the child and parent calls, the partial
bundle preserves the asymmetry and aborts immediately.

`application_v1.schema.json` uses `oneOf` on `source_kind`. Every planned command operation and every
allowed planned intervention operation must have exactly one matching receipt—successful or
failed—with the same source hash, operation ID, API, target, and argument bytes. Duplicate, missing,
or orphan receipts invalidate evidence. Observed constraint reactions are observations, not planned
executor calls, and therefore do not receive fake application receipts.

### 14.7 Decision, intervention, and mechanics records

`decisions.jsonl` answers **why the controller chose this action**:

```json
{
  "schema": "sporespore.lab.decision.v1",
  "run_id": "example",
  "decision_id": 120,
  "source_frame_id": 120,
  "supervisor_mode": "BRACE",
  "detector": {
    "static_margin_m": 0.019,
    "static_enter_threshold_m": 0.035,
    "capture_margin_m": -0.011,
    "time_to_boundary_s": 0.14,
    "urgency_terms": {"static": 0.46, "capture": 0.72}
  },
  "candidate_strategies": [
    {"id": "redistribute", "feasible": false, "reason": "WRENCH_OUTSIDE_CONE"},
    {"id": "catch_left", "feasible": true, "score": 0.81}
  ],
  "selected_strategy": "catch_left",
  "desired_wrench": {
    "reference_point_world_m": [0.0, 0.61, 0.0],
    "force_world_n": [91.0, 111.0, 0.0],
    "moment_world_nm": [0.0, 0.0, -13.2]
  },
  "allocator": {
    "feasible": true,
    "arithmetic_residual_norm": 0.00002,
    "predicted_feasibility_residual_norm": 0.0
  },
  "anti_windup": {"active": false, "reason": null}
}
```

This stream includes detector terms and thresholds, chosen and rejected strategies, phase guards,
desired wrench/reference point, allocator constraints, feasibility, and anti-windup state.

`interventions.jsonl` answers **what non-joint mutation or fixture action was planned or what
constraint reaction was observed**. Like a command, each line is an immutable envelope:
`{"intervention_payload_sha256": "<hash of /payload>", "payload": {...}}`. The planned payload below
is sealed before execution:

```json
{
  "schema": "sporespore.lab.intervention.v1",
  "run_id": "example",
  "record_kind": "planned_operation",
  "operation_id": "push_0042",
  "source_frame_id": 120,
  "applied_transition": [120, 121],
  "source": "fixture.disturbance",
  "type": "central_impulse",
  "planned_api": "RigidBody3D.apply_central_impulse",
  "target_body_id": "root",
  "point_world_m": null,
  "force_world_n": null,
  "torque_world_nm": null,
  "linear_impulse_world_n_s": [2.0, 0.0, 0.0],
  "angular_impulse_world_n_m_s": [0.0, 0.0, 0.0],
  "signed_work_j": null,
  "work_quality": "unavailable",
  "availability": {
    "/signed_work_j": {
      "status": "unavailable",
      "reason": "POST_IMPULSE_ENDPOINT_NOT_CAPTURED"
    }
  },
  "allowed": true,
  "experiment_phase": "MEASURE"
}
```

Every force, central force, torque, impulse, velocity/transform write, scaffold command,
spawn/release operation, and dynamic environment motion is first sealed as a
`planned_operation`, then goes through `InterventionExecutor`. The executor rehashes the payload
before the call and appends an `application.v1` receipt with `source_kind: intervention`. The
validator pairs every planned operation to exactly one receipt and rejects any receipt that was not
planned.

Built-in rail/constraint reactions are declared in the manifest and written as
`record_kind: observed_constraint_reaction` with
`measured_constraint_reaction` or `residual_inferred_constraint_reaction` quality. These are
observer records, not executor plans. An unavailable reaction is never serialized as zero and never
gets an invented call receipt.

For an instantaneous impulse with valid before/after application-point velocities, estimate work
from the corresponding kinetic-energy change (equivalently
\(J\cdot(v_p^-+v_p^+)/2\) for the translational term, plus the rotational term for angular impulse).
If either endpoint is unavailable, work is `null`; a nonzero impulse is never assigned fabricated
zero work.

`mechanics.jsonl` answers **what the physical system realized**. It stores whole-body CoM,
linear/angular momentum, kinetic/gravitational/passive energy, external impulse, scaffold reaction,
desired/predicted/realized wrenches, all three residual classes, dissipation estimates, and
availability/quality. `MechanicsAccountant` derives it from adjacent sealed frames and the
successful application receipts plus their sealed command/intervention sources, not from controller
claims or unexecuted plans.

### 14.8 Contact record

For each contact:

```json
{
  "contact_key": "toe_07:shape_0|ground:shape_0|track_0002",
  "body_id": "toe_07",
  "other_id": "ground",
  "point_world_m": [0.12, 0.0, -0.04],
  "point_body_local_m": [0.01, -0.03, 0.00],
  "normal_world": [0.0, 1.0, 0.0],
  "normal_frame_source": "jolt_world_backend",
  "relative_velocity_m_s": [0.01, -0.02, 0.00],
  "tangential_speed_m_s": 0.01,
  "impulse_n_s": [0.0, 1.37, 0.0],
  "impulse_available": true,
  "impulse_quality": "engine_estimate",
  "contact_age_ticks": 8,
  "ownership": "creature_environment",
  "canonical_pair_side": true,
  "support_state": "BEARING",
  "qualifies_as_ground": true
}
```

Godot requires contact monitoring for nonzero contact count. Jolt exposes contact impulses, but
multi-contact impulses are estimates rather than an exact force sensor. The manifest and field
status retain that limitation. Use analytic total momentum change as an independent check.
`track_0002` is a deterministic within-run contact-lifetime ID derived from stable body/shape IDs
and nearest-neighbor matching in quantized body-local coordinates; a runtime RID or backend manifold
index is diagnostic metadata, never cross-run identity.

### 14.9 Event record

```json
{
  "schema": "sporespore.lab.event.v1",
  "run_id": "example",
  "event_sequence": 37,
  "frame_id": 121,
  "event": "MODE_TRANSITION",
  "from": "PRECARIOUS",
  "to": "BRACE",
  "reason": "CURRENT_SUPPORT_INFEASIBLE",
  "evidence": {
    "static_margin_m": 0.019,
    "capture_margin_m": -0.011,
    "time_to_boundary_s": 0.14,
    "active_reserve_fraction": 0.08
  }
}
```

Other mandatory event families:

```text
CONTACT_BEGIN / CONTACT_END / SUPPORT_STATE_CHANGE
SATURATION_BEGIN / SATURATION_END
LIMIT_HIT / NONFINITE_DETECTED
ALLOCATOR_INFEASIBLE
RECOVERY_PHASE_BEGIN / SUCCESS / FAILURE
UNAUTHORIZED_INTERVENTION
ABORT
PROMOTION_DECISION
```

`event_sequence` is a run-global monotonic integer. Events detected for the same frame are ordered
by a versioned family priority (`integrity/abort`, contact, support, saturation/limit, allocation,
mode/recovery, termination/promotion), then stable subject ID, then detector-local ordinal. The
schema-set version pins this tie-break; hash-map iteration order never does.

#### 14.9.1 Paired comparison record

Control/intervention or parameter-matrix conclusions receive their own immutable
`comparison.json`:

```json
{
  "schema": "sporespore.lab.comparison.v1",
  "comparison_id": "cmp_BR09_brace_on_off_seed-42",
  "experiment_id": "BR09_EXISTING_CONTACT_BRACE",
  "control_run_id": "run_brace_off",
  "intervention_run_id": "run_brace_on",
  "declared_independent_variable": {
    "path": "/controller/brace_enabled",
    "control": false,
    "intervention": true
  },
  "paired_base_spec_sha256": "sha256:...",
  "control_expanded_spec_sha256": "sha256:control...",
  "intervention_expanded_spec_sha256": "sha256:intervention...",
  "declared_diff_paths": ["/controller/brace_enabled"],
  "shared_seed_streams": true,
  "seed_equality": {
    "root_seed_equal": true,
    "derivation_rule_equal": true,
    "named_initial_seed_map_sha256": "sha256:..."
  },
  "nuisance_manifest_fingerprint_sha256": "sha256:...",
  "allowed_manifest_diff_paths": [
    "/run_id",
    "/started_utc",
    "/comparison_role",
    "/paired_run_id",
    "/terminal_results"
  ],
  "alignment": "physics_time_and_disturbance_event",
  "first_divergence": {
    "frame_id": 121,
    "field": "command.mode",
    "control": "STANCE",
    "intervention": "BRACE",
    "expected": true,
    "reason": "PREREGISTERED_BRACE_INTERVENTION"
  },
  "first_unexpected_divergence": null,
  "metric_differences": {},
  "evidence_validity": "valid",
  "conclusion": "supported"
}
```

To compute `paired_base_spec_sha256`, remove only run/campaign identity, artifact-output paths, and
the declared independent-variable paths from each expanded spec; the remaining canonical bytes must
match. **Do not remove** `seed_root`, the RNG derivation rule, named stream IDs, or their initial
derived seeds. Runtime draw counts/state are run evidence rather than authored-spec fields and may
diverge only after the preregistered causal seam. `shared_seed_streams` is validator-derived, never
trusted as a self-reported boolean: validation compares root seed, derivation rule, exact named
stream set, each initial seed, and each pre-divergence draw count. The comparison validator rejects
any undeclared difference.

Expanded-spec equality is necessary but not sufficient. `ComparisonRunner` also derives a
versioned nuisance fingerprint from both **final child manifests**. Unless one item is itself the
preregistered independent variable, the fingerprint requires equality of:

```text
clean git commit and loaded source/resource hashes
Godot version/commit, physics backend/adapter, platform
schema set, recorder version, fixture ID/version/hash
physics tick rate and solver settings
resolved observer profile ID, channel set, contact cap, parity envelope
body/joint dynamics, materials, gravity/damping, collision policy
seed derivation and initial named streams
allowed/forbidden scaffolds and execution/isolation mode
```

Only the versioned `allowed_manifest_diff_paths` may differ. A backend, observer, fixture, or source
comparison must declare that field as the treatment and use its own compatibility gate; it cannot
hide inside a brace-on/off pair. Campaign source revision and nuisance fingerprint are derived from
matching child manifests, never copied from a caller's assertion. A preregistered divergence in the
treatment channel is marked expected;
`first_unexpected_divergence` is reserved for trajectories separating before, or outside, that
predicted causal seam. A time series alone establishes ordering/correlation; the paired intervention
is what supports a causal conclusion.

#### 14.9.2 Summary and campaign provenance

Every `summary.json` metric links back to the evidence that produced it:

```json
{
  "metric_id": "maximum_absolute_height_error",
  "value": 0.012,
  "unit": "m",
  "availability": "derived",
  "source_stream": "frames.jsonl",
  "source_frame_range": [180, 420],
  "source_field": "/whole_body/support_height_m",
  "aggregation_id": "max_abs_error",
  "aggregation_version": 1,
  "target_value": 0.75
}
```

A summary value without stream, frame/event range, field, units, availability, and versioned
aggregation is invalid. The report builder can cache convenient plots; the raw link is canonical.

Paired comparisons and sweeps are sealed campaign bundles, not loose files:

```text
user://lab/campaigns/<campaign-id>.partial/
  campaign_manifest.json
  comparison.json              # present for paired/control campaigns
  matrix_summary.json          # present for sweeps/factorial campaigns
  child_run_ids.json
  checksums.json
```

The campaign manifest records its preregistered factors, factor roles, allowed interactions,
expected-feasible/infeasible/exploratory cells, child run IDs, child final-manifest hashes, derived
child nuisance fingerprint/source revision, and campaign schema set. It follows the same `.partial`
workflow: write the final
manifest, hash every immutable artifact except its checksum file, validate children and declared
differences, then rename. A campaign cannot promote if any referenced child bundle is partial,
hash-mismatched, or evidence-invalid.

`runtime_notes.jsonl` is schema-controlled evidence generated **during** a run:

```text
note_sequence
frame_id or null
source component
severity
stable code
short message
structured evidence
```

It is flushed and hashed with the other run streams. Human review after the run belongs to the
separate append-only annotation store and cannot rewrite runtime notes.

### 14.10 Energy and momentum ledger

For a command that is constant over transition \(k\rightarrow k+1\), integrate active joint work
using the average measured endpoint velocity:

\[
\Delta W_{\text{active},j}
=
\tau_{\text{active},j,k}
\frac{\dot q_{j,k}+\dot q_{j,k+1}}{2}
\Delta t
\]

Use the corresponding trapezoidal rule when force/torque itself changes across the interval.
Left-endpoint work is retained only as an error-comparison channel during timestep calibration.

For a force applied at world point \(p\) on body \(b\):

\[
v_p=v_b+\omega_b\times(p-c_b)
\]

\[
P_\text{intervention}
=
F\cdot v_p
+
\tau_{p}\cdot\omega_b
\]

Use the velocity of the actual application point and the torque about that same reference. Whole
body CoM velocity plus root angular velocity is not generally equivalent for an articulated body.
A multi-body scaffold sums the power/impulse at every constrained body/point.

\[
\Delta E_\text{mech}
=
\Delta(K+U_g+E_\text{passive})
\]

\[
\Delta E_\text{mech}
=
W_\text{active}
+
W_\text{scaffold}
+
W_\text{disturbance}
+
W_\text{dynamic-contact}
-
E_\text{dissipated}
+
r_E
\]

\[
\Delta J_s=\int F_s\,dt
\qquad
\Delta L_s=\int \tau_s\,dt
\]

Store:

```text
signed positive active work
signed negative active work
absolute active effort
signed passive work by component
stored passive energy by component
change in gravitational potential energy
whole-system translational and per-body rotational kinetic energy
contact impulse estimate
scaffold impulse and work
disturbance and dynamic-contact work
dissipated energy estimate
unexplained energy/momentum residual and quality
```

Conservative spring/tendon work and stored-energy change are both useful diagnostics, but only one
enters a given side of the balance; do not double-count them. Damper loss enters
`E_dissipated >= 0`. The structural guard is an artificial intervention and has its own work/impulse
channel.

The simple rail-rise oracle

```text
Delta Ug <= positive active work + tolerance
```

is valid only with passive tissue disabled, endpoints at rest, no disturbance, stationary ground,
and rail work/impulse inside its declared envelope. Otherwise use the full balance. When the engine
does not expose rail reactions, infer them from whole-system momentum/energy residuals and label the
quality `residual_inferred`; never assume zero.

The current rollout accumulator named `assist_work` adds impulse-like quantities rather than
physical work. Do not reuse that name or value as proof. The lab ledger replaces it with
dimensionally explicit channels.

### 14.11 Evidence validity is independent of run success

Record four separate judgments:

```text
termination
  completed | timed_out | aborted | crashed

evidence_validity
  valid | invalid | partial

hypothesis_result
  supported | contradicted | inconclusive

promotion
  pass | fail | not_evaluated
```

Examples:

- a creature falls, but the trace is valid and the hypothesis is contradicted;
- a creature stands, but contact capture saturated, so evidence is invalid;
- a run times out with stable data and still produces a useful inconclusive result;
- a controller succeeds only with forbidden root impulse, so promotion fails.

### 14.12 Run lifecycle and crash safety

Default artifact path:

```text
user://lab/runs/<run_id>/
```

This avoids writing runtime artifacts into the repository. A deliberate export command copies a
small accepted evidence bundle into:

```text
data/lab/accepted/<experiment_id>/<run_id>/
```

`LabProcessLauncher` owns run identity and process isolation. It builds a collision-resistant ID
from UTC time with sub-second precision, experiment ID, seed label, process ID, and a 128-bit
OS-random nonce. The nonce is identity-only and never enters a physics/controller RNG stream. The
launcher atomically reserves `<run_id>.partial/`; an existing directory is a hard error, never an
overwrite. Each child receives unique:

```text
run artifact directory
Godot --log-file target
captured stdout file
captured stderr file
process metadata record
```

All are associated with the run ID. `process_metadata.json` validates against
`process_metadata_v1.schema.json` and records parent/child process IDs, exact executable/arguments,
working directory, start/end times, exit disposition, and log paths. Canonical runs still use one
fresh process each.

`PreEventRingBuffer` provides crash-local context without trusting graceful shutdown. For the first
implementation:

```text
minimum window: max(2 seconds, fixture-declared pre-event duration)
capacity: ceil(window / fixed_dt) slots
one disk-backed `pre_event_entry_v1` slot per tick with sequence and previous-record hash
write slot.tmp, flush, atomically replace slot_<index>.json
evict by deterministic modulo index only after replacement succeeds
trigger on NONFINITE, constraint explosion, unauthorized intervention,
  contact-cap saturation, controlled abort, or explicit capture request
```

On a controlled trigger, materialize the latest contiguous sequence as
`pre_event_snapshot.jsonl`. After an uncontrolled crash, the inspection command reconstructs the
latest valid hash chain directly from the slots in the `.partial` directory. Promotion runs set the
slot flush interval to one physics tick. Engine log/stdout/stderr and a materialized snapshot are
checksummed diagnostics; raw rotating slots are transient and removed only during successful final
validation. A test kills/aborts between slot writes and proves the last complete slot remains
readable.

Every slot and materialized snapshot line validates against
`pre_event_entry_v1.schema.json`. Engine stdout/stderr/log files are explicitly opaque byte
diagnostics, not structured “records”; `G0_SCHEMA` does not parse them, while `checksums.json` still
seals their bytes when retained. This keeps “every record validates” literal.

Lifecycle:

```text
create <run_id>.partial/
write manifest with status RUNNING
write process_metadata.json with status RUNNING
append frames.jsonl
append commands.jsonl
append applications.jsonl
append decisions.jsonl
append interventions.jsonl
append mechanics.jsonl
append events.jsonl
append runtime_notes.jsonl
materialize pre_event_snapshot.jsonl on a declared trigger
flush periodically
close and flush every immutable evidence stream
atomically write summary.json
atomically replace process_metadata.json with final child exit disposition
atomically replace manifest.json with final status COMPLETE
compute hashes for every immutable artifact except checksums.json
atomically write checksums.json
run RunBundleValidator against schemas, line counts, hashes, and cross-record IDs
close every remaining read/validation handle
atomically rename directory without .partial
```

An interrupted `.partial` run is inspectable but cannot be promoted. A genuine process/OS crash
cannot promise an exit code; the next invocation discovers the `.partial` directory. Exit code `5`
is reserved for a **controlled crash-safe abort** that caught a runtime safety/integrity failure,
flushed what it safely could, and left the bundle partial. It is not a synonym for arbitrary engine
termination.

Human annotations are append-only sidecars with author/time and their own hash chain. They are not
allowed to mutate any sealed evidence file or its checksum after promotion.

### 14.13 Seed discipline

Every random concern receives a named stream:

```text
morphology
disturbance
controller_exploration
sensor_noise
surface_variation
```

Record:

- root seed;
- derived stream seeds;
- whether each stream was consumed;
- first/last draw count if practical.

Changing an unrelated random call must not shift the disturbance sequence.

### 14.14 Observer profiles and parity

Profiles:

```text
minimal_state_v1
full_state_v1
full_contacts_v1
full_energy_v1
debug_everything_v1
```

These are immutable registered IDs, not mutable aliases. The CLI resolves only an exact ID; the
expanded spec and manifest seal that ID plus a channel-set hash. Adding/removing a field or changing
capture semantics creates `_v2` and requires a new parity envelope.

Before using a cheaper profile in batches, run observer parity:

```text
same fixture
same seed
same controller commands
minimal observer versus full observer
state trajectory stays within declared tolerance
event ordering matches
```

If full observation changes behavior materially, report `OBSERVER_PERTURBATION` and fix the capture
path or timing before trusting batches.

### 14.15 Trace viewer

The first viewer can be simple and read-only:

```text
timeline scrubber
mode and recovery-phase bands
root pose/CoM path
contact points and normals
support polygon/capture point
per-joint q, qdot, torque components, limits
detector thresholds, urgency terms, and rejected strategies
desired versus achieved wrench
allocator arithmetic versus realized physical residual
energy and impulse ledgers
fixture/disturbance/scaffold interventions
event/filter panel
manifest and validity panel
```

It reads completed trace files after the run. Do not make the physics experiment depend on an editor
UI refresh or rendering frame rate.

---

## 15. Failure taxonomy

Every failure has a stable code, a plain-language meaning, required evidence, and likely repair
layer.

| Code | Meaning | Evidence that distinguishes it | Repair layer |
|---|---|---|---|
| `OBS_CONTACT_DISABLED` | contacts were never captured | contact monitor/cap manifest | observer/build |
| `CONTACT_BUFFER_SATURATED` | reported count hit configured cap | per-body peak equals cap | observer/build |
| `CONTACT_NORMAL_AMBIGUOUS` | sign/frame oracle failed | box-drop normal comparison | observer adapter |
| `STALE_JOINT_AXIS` | torque used an axis not sampled this tick | axis sample ID differs from command | binding |
| `TORQUE_NOT_PAIRED` | equal/opposite application missing | executor audit | actuator executor |
| `ACTIVE_TORQUE_SATURATION` | requested active torque exceeded envelope | request/applied/reserve | controller or anatomy |
| `ACTIVE_POWER_SATURATION` | torque-speed point exceeded power | qdot, tau, power cap | controller or actuator |
| `STRUCTURAL_TORQUE_EXCEEDED` | active plus passive exceeded joint structure | component sum | anatomy/controller |
| `PASSIVE_ENERGY_CREATED` | passive element added unexplained net energy | signed passive cycle work | tissue model/timestep |
| `SUPPORT_MAP_RANK_DEFICIENT` | contacts cannot span requested wrench | map rank/singular values | contacts/morphology |
| `ALLOCATOR_FRICTION_INFEASIBLE` | desired force is outside friction cones | tangential/normal margins | strategy/surface |
| `ALLOCATOR_ACTUATOR_INFEASIBLE` | contact wrench maps beyond motors | per-joint required/cap | controller/anatomy |
| `HEIGHT_TARGET_UNREACHABLE` | requested CoM height exceeds kinematics | reach envelope | controller/morphology |
| `STRAIGHT_LEG_SINGULARITY` | extension lost useful leverage | Jacobian conditioning, reserve | pose target |
| `SUPPORT_LOST` | bearing contact disappeared | contact lifecycle/event | contact/strategy |
| `REACTION_TOO_LATE` | brace began after catch deadline | TTC versus transition tick | detector |
| `CATCH_UNREACHABLE_BEFORE_IMPACT` | candidate foot cannot arrive in time | reach/speed/deadline | morphology/strategy |
| `CATCH_CONTACT_NEVER_BEARING` | foot touched but never carried support | TOUCH/LOAD history, slip | loading/friction |
| `FALL_ARREST_INSUFFICIENT_IMPULSE` | legal force could not stop momentum | impulse requirement versus cap | strategy/anatomy |
| `POSE_CLASSIFICATION_AMBIGUOUS` | recovery start pose is uncertain | axis/contact features | classifier/sensing |
| `RECOVERY_PROFILE_MISSING` | no anatomy-specific plan applies | role/profile match | authored data |
| `RECOVERY_PHASE_INFEASIBLE` | next phase cannot meet constraints | feasibility margins | profile/morphology |
| `RECOVERY_PHASE_TIMEOUT` | observed goal never reached | phase trace | phase/controller |
| `UNAUTHORIZED_ROOT_INTERVENTION` | hidden root force/torque/write occurred | intervention ledger | control architecture |
| `ENERGY_ACCOUNTING_RESIDUAL` | mechanical change is unexplained | full energy ledger | observer/physics |
| `OBSERVER_PERTURBATION` | instrumentation changed trajectory | profile A/B | observer |
| `NONFINITE_STATE` | NaN/Inf entered state or command | first invalid field/tick | immediate upstream |

Failure codes are append-only once evidence has been archived. Renaming a code breaks encyclopedia
queries; add an alias/migration if terminology improves.

---

## 16. BR0-BR14 implementation ladder

Each milestone changes one principal uncertainty. A later milestone may be coded in a branch, but it
cannot be used as evidence until every dependency gate passes.

The BR milestones are bracing/recovery integration gates layered over the broader `L0-L12`
locomotion research ladder in
[LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md#9-experimental-ladder).
An `L` experiment is not silently replaced by a similarly themed BR test; the mapping below names
which exact `L` cells are prerequisites.

Two delivery tracks share the same foundation:

```text
minimum support pipeline for atomic-step research
  recorder -> engine/contact truth -> actuator -> loaded foot/rail support
  -> planar stance -> detection -> existing-contact brace
  -> free-space swing/touchdown/load-transfer prerequisites

robust autonomy pipeline
  minimum support foundation -> catch creation -> fall arrest
  -> pose classification -> constrained get-up -> spatial recovery
```

The first track can unlock carefully scaffolded `L7` atomic-step work without pretending arbitrary
get-up is complete. A shipping/free creature may require both tracks.

### BR0 — Freeze claims and baseline

**Question:** What does the current system actually do with no new controller?

Build:

- add this bootstrap and link it from the research program;
- capture the existing stand-only probe;
- label all old "walking" claims historical/unaccepted;
- define fixture IDs and versioning.

The legacy [`_stand_only.gd`](../scripts/sim/_stand_only.gd#L1-L60) probe exists, but there is no
captured artifact supporting remembered numeric outputs. Those numeric recollections are discarded.
BR0 may rerun the legacy probe only as explicitly unaccepted characterization:

```powershell
& $godot --headless --path . --script "res://scripts/sim/_stand_only.gd"
```

Archive its exact stdout, configuration, executable version, and source-state identity or make no
numeric baseline claim. BR1 reruns every value that matters through the accepted recorder.

Gate:

- if the probe is rerun, its observed qualitative/numeric output, configuration, executable, and
  source identity are archived and labeled `legacy_unaccepted_characterization`;
- if it is not rerun, BR0 records `no_observed_baseline` and makes no outcome claim;
- no legacy outcome—whatever it is—can support stand/walk promotion;
- no future test compares against an undocumented memory.

Depends on: nothing.

Unlocks: BR1.

### BR1 — Evidence spine and complete L0 calibration

**Question:** Can we prove when a measurement and command happened?

Build:

- compiled/frozen experiment specs, draw-only named RNG capabilities, and immutable controller
  context;
- isolated process launcher, atomic run reservation, `lab_runner.gd`, and crash-safe pre-event
  buffer;
- canonical JSON, frozen values, `trace_store.gd`, schema/bundle validators, and exact lifecycle;
- capture clock, frame assembler, finite sanitizer, body/whole-system observers, event detector,
  mechanics accountant, report builder, and gate evaluator;
- empty command-envelope/ledger and application-receipt contracts even before an actuator exists;
- manifest/frame/command/application/decision/intervention/mechanics/event/runtime-note/summary/checksum
  schemas;
- sealed comparison/campaign schemas and child-run linkage;
- partial-run lifecycle, stable IDs, and named seeds;
- stationary, free-fall, ballistic/zero-g, observer A/B, and trace-playback fixtures;
- `trace_replay.gd`, which renders/recalculates recorded evidence without invoking physics.

Tests:

```text
test_lab_trace_round_trip.gd
test_lab_tick_order.gd
test_lab_spec_compiler.gd
test_lab_schema_validator.gd
test_lab_seed_streams.gd
test_lab_controller_context_immutable.gd
test_lab_global_rng_rejected.gd
test_lab_command_envelope_hash.gd
test_lab_application_receipts.gd
test_lab_nonfinite_terminal_evidence.gd
test_lab_summary_provenance.gd
test_lab_unique_run_reservation.gd
test_lab_process_metadata_lifecycle.gd
test_lab_pre_event_buffer_dump.gd
test_lab_run_bundle_validator.gd
test_lab_comparison_bundle.gd
test_lab_source_state_gate.gd
test_lab_partial_run_not_promotable.gd
test_lab_l0_stationary_gravity_off.gd
test_lab_l0_free_fall.gd
test_lab_l0_ballistic_zero_g.gd
test_lab_observer_ab.gd
test_lab_trace_playback_no_physics.gd
```

Gate:

- `L0.0`: a stationary gravity-off body acquires no invented motion/contact/work;
- `L0.1`: free-fall acceleration matches configured gravity over a timestep sweep;
- `L0.2`: ballistic and zero-gravity coast match the analytic momentum trajectory;
- `L0.3`: enabling each observer channel implemented in the exact BR1
  `schema_set + observer_profile + adapter` has a measured, acceptable perturbation envelope;
- `L0.4`: trace playback reproduces recorded transforms/events/derived metrics with physics
  disabled;
- command N explicitly maps frame N to N+1;
- missing values are not serialized as zero;
- interrupted run remains `partial`.

Depends on: BR0.

Unlocks: trace-producing experiments. Every observer/control capability introduced later remains
independently gated.

A new contact, mechanics, energy, high-contact, adapter, backend, or contact-cap profile invalidates
the older parity assumption. It must pass `G10_OBSERVER_PARITY` for that exact configuration before
its channels support promotion.

### BR2 — Body/joint observer and coordinate-frame oracles

**Question:** Are position, velocity, axis, angle, and inertia channels true?

#### Implementation checkpoint — 2026-07-21

> **BR2.1 integrity erratum — later on 2026-07-21:** This checkpoint records
> what the earlier implementation and certification actually did; it is not a
> current acceptance claim. A deliberately noncommuting fixture proved that
> `rest.inverse() * relative` is a delta in the child-rest frame, while the
> implementation projected it onto `axis_parent_local`. Identity-rest and
> same-axis fixtures commute, so all six old tests could pass while a valid
> general hinge returned angle zero and nonzero swing. The corrected
> parent-frame equation is `relative * rest.inverse()`, decomposed about the
> parent-local axis. BR2.1 also adds directed rest-axis validation, rigid-basis
> checks, body/step/epoch/phase identity, explicit unwrap-segment initialization
> and predecessor continuity, and symmetry/SPD/conditioning checks for inverse
> inertia. `joint_binding_v1`, `joint_state_v1`, and `whole_body_state_v2`
> describe the historical behavior; the corrected contracts advance their
> version identifiers rather than silently changing those meanings.

The corrected BR2.1 observation layer is implemented and its targeted tests are
green under the real Godot 4.7/Jolt runtime with zero unexpected engine errors.
This is implementation evidence, not yet the clean full-suite acceptance run.
What exists, where, and why it is shaped that way:

- **`scripts/lab/mechanics/joint_binding.gd`** seals authoring-time hinge
  declarations as LOCAL-frame quantities only: the axis expressed in BOTH
  the parent and child body frames, the anchor expressed in both frames,
  the rest relative rotation, agreement tolerances, and a per-tick rotation
  ceiling for unwrap ambiguity. Storing both-side axes is deliberate: a
  wrong-frame authoring mistake becomes a detectable disagreement at sample
  time instead of a silently scaled angle. Nothing world-frame is ever
  stored, which is the gate clause "no controller reads stored
  construction-time world axes" made structural.
- **`scripts/lab/mechanics/joint_state.gd`** recomputes every world-frame
  joint quantity per sample from the two live transforms: current axis
  (recomputed independently through parent and child frames, required to
  agree), both world anchors (required to coincide), the hinge angle as
  the twist of `(parent⁻¹·child)·rest⁻¹` about the parent-local axis with a
  documented right-hand sign convention, the off-axis swing residual as a
  hinge-conformity witness, an axis-projected angular-rate cross-check,
  and a fail-closed unwrapped angle stream. Mismatched anchors, axis
  disagreement, and ambiguous per-tick jumps INVALIDATE the sample rather
  than drifting, exactly as this section's gate demands. The file header
  records the gait-era 0.414x hinge_angle frame bug this design answers.
- **`scripts/lab/mechanics/joint_angle_stream.gd`** owns the unwrap predecessor
  rather than trusting a caller to select one. It refuses segment-ID reuse,
  requires exact run/stream/binding/step/epoch/phase continuity, and admits a
  new segment only with an explicit authored initialization witness. Endpoint
  quaternion branches are selected against the trapezoidal integral of the
  independently sampled angular rate; a residual over the registered tolerance
  or a witnessed per-tick rotation over the ceiling makes the unwrapped channel
  unavailable instead of guessing a turn.
- **`scripts/lab/mechanics/whole_body_rotational_state.gd`** derives total
  angular momentum (spin `I_world·ω` plus orbital `m·(r−r_com)×v`), both
  kinetic energies, and the reference-point shift identity
  `L_P = L_com + (r_com − P)×p` from sampled engine channels only. A
  singular inverse inertia tensor (a locked axis) or any missing channel
  makes the aggregate unavailable with an exact reason, never zero.
- **Version boundary, decided here:** the sealed `frame_v1` stream is
  UNTOUCHED. `frame_v1.schema.json` pins angular momentum to null with
  reason `BR1_INERTIA_CHANNEL_NOT_CERTIFIED`, the published BR1 bundles
  validate against that pin, and the lab's schemas are append-only. BR2's
  rotational and joint channels therefore live at the mechanics layer
  (historical source ids `whole_body_state_v2` / `joint_state_v1`; corrected
  BR2.1 source ids `whole_body_state_v3` / `joint_state_v2`) and enter a sealed
  stream only when the first jointed experiment family versions the whole
  chain (`frame_v2` schema, jointed rig, contract-registry entry, metric
  recomputer generalized past its `/bodies/body_0` pin) together. That is
  BR3A/BR4 integration work and is intentionally NOT smuggled into BR2.
  `test_lab_body_sample_frames.gd` guards the v1 pin explicitly.

The BR2/BR2.1 tests and what they prove on the live engine:

- `test_lab_body_sample_frames.gd` — the labeled rotated box through the
  complete sealed-frame chain: authored skew rotation reproduced to 4e-8,
  center-of-mass frame oracle at zero error, coherent step/epoch identity,
  and the frame_v1 angular-momentum pin still holding.
- `test_lab_joint_axis_rotates_with_parent.gd` — a live Jolt HingeJoint3D
  on a co-rotating pair (gravity off, spin about world +Y, hinge axis +X
  through the child's center): anchors held to 39 microns, both-side axis
  recomputations agreed to 10 microradians, swing residual stayed under a
  milliradian, and the live axis ended the run rotated by the parent's own
  rotation angle, proving a cached construction axis would now be wrong by
  that exact angle.
- `test_lab_angle_sign.gd` — the sign convention locked geometrically
  (+X carried onto +Y by a positive rotation about +Z), rest-pose zeroing,
  parent-pose invariance, and the negative space: wrong-frame axes and
  separated anchors invalidate instead of scaling. BR2.1 adds the missing
  noncommuting rest orientation, an independent vector-geometry oracle,
  rate projection, quaternion `q/-q` digest identity, forged-binding rejection,
  and non-finite-output exclusion (27 targeted assertions green).
- `test_lab_unwrapped_angle_stream_continuity.gd` — the historical test proved
  continuity across both ±π seams and ambiguous-jump rejection, but it also
  allowed an invalid predecessor to restart implicitly. BR2.1 replaces that
  unsafe behavior: a missing/invalid/cross-joint/cross-step/cross-epoch/
  cross-phase/cross-segment predecessor fails closed, and only an explicit new
  segment with an authored initial turn index may restart the stream. Full
  positive/negative turns, two turns, the 0.019/0.021 rad witness boundary,
  endpoint/rate mismatch, coordinate change, and segment reuse are exercised
  (21 targeted assertions green).
- `test_lab_direct_inertia_finite.gd` — the collider-inertia comparison:
  the engine's sampled inverse tensor matched the analytic solid box
  (through an authored skew rotation) and sphere to 2e-6 relative, with
  symmetry at float32 rounding (the backend computes in single precision;
  the tolerance says so rather than pretending doubles).
- `test_lab_angular_momentum_availability.gd` — a hand-computed two-body
  assembly reproduced exactly (L=(1,0,16.8), energies 2.5 J and 18.5 J,
  shift identity to 1e-9), the unavailable negative space, and a pinned
  ENGINE CONTRACT: this Jolt configuration applies no gyroscopic term, so
  a torque-free body holds world angular velocity constant. Consequence,
  both asserted live: principal-axis spins conserve derived L (matching
  analytic inertia to display precision) while off-principal spins rotate
  the tensor under constant ω and derived L visibly varies. Later balance
  work must model THIS engine, not the textbook: angular momentum of a
  tumbling body is only a conserved quantity here on principal axes.

The historical certification inventory grew 45 → 51 with these tests. The old
checkpoint changed the contents of files still named `..._v1` and retained the
same schema/inventory identifiers. That was an append-only integrity error even
though both produced reports remain authentic. BR2.1 preserves byte-exact 45
and 51 test snapshots behind immutable, allowlisted legacy qualification
profiles. Production verification now selects a profile only from the exact
report schema + inventory hash + test count + artifact count + campaign ID +
campaign hash tuple. Both original external reports and receipts were re-read
and HMAC-verified through that dispatcher. Production report-v1 authoring is
disabled, and the current 62-test authoring inventory uses report-v2,
inventory-v2, receipt-v2, a distinct HMAC domain, and a distinct receipt
directory. The complete v2 synthetic report/receipt adversarial fixture is
green. The clean production v2 campaign then passed at commit
`1779accd87b8b30f3985c83a3fdb2ea536856389`:

- certification ID `br1_20260721T200358Z_63a593be`;
- report contract `BR1_L0_V2_CURRENT_I62` and schema
  `sporespore.lab.br1_certification_report.v2`;
- 62/62 pinned tests and exactly 124 authenticated test artifacts;
- 7/7 cells, 14/14 bundles, 14/14 zero-physics replays, 7/7 replicate
  comparisons, and 14/14 final readbacks;
- report SHA-256
  `sha256:af7551251b2a53f0cdd0b2431d262067540c70467db3e4efcd907c633f15f828`;
- receipt SHA-256
  `sha256:e99b84576f676e7a5acd948dc719248a2a712f255bd79516eff692930059366c`;
  and
- production attest and independent verify both returned
  `ok=true`, `can_promote=true`, `legacy_verification_only=false`.

The operator first caught and refused a culture-sensitive PowerShell test-order
disagreement (`observer_ab.gd` versus `observer_ab_bundle.gd`). The harness and
operator now both sort signed test identities with
`StringComparer.Ordinal`; the two-test regression passed before the clean
campaign was restarted. This is exactly the kind of small pipeline defect the
bootstrap is intended to expose before it can contaminate a physical claim.

The complete current suite was rerun after L1.2 on 2026-07-21 as 62 isolated
Godot 4.7/Jolt processes: 62 passed, 0 failed, 1,118 assertions passed, no
timeout, and zero unexpected engine errors. The count remained exactly 62,
proving the three `test_experimental_*` files did not mutate report-v2 discovery.
One engine error marker was the registered positive control that proves the
harness detects engine-reported failures. This closes the broad development
regression run; it is not a signed promotion artifact.

Cole supplied the required explicit BR2.1 decision on 2026-07-21. The repository
records it as append-only decision
`BR2_1_ARTICULATED_OBSERVER_DECISION_V1` in
`data/lab/milestone_decisions/br2_1_articulated_observer_decision_v1.json`,
byte-pinned at
`sha256:6cd15ef94c737741bd4119a8849ae17a8732069054c17db80da7b49fafe0a37c`
by `scripts/lab/milestone_decision_registry.gd`. The registry revalidates its
strict schema, exact report/receipt/source identities, accepted contracts,
decider, claim boundary, and exclusions. This leaves BR1's report claim boundary
unchanged while making the bounded human BR2.1 decision independently auditable.

Still open for BR2's later consumers: wiring joint/rotational channels
into sealed experiment bundles behind a `frame_v2` family, a jointed rig
in `rig_factory.gd`, and observer profiles that advertise joint channels.
Axis, angle, and inertia are now promotion-grade only within the accepted BR2.1
observer contracts and their provenance/availability limits. BR3A/BR4 consumers
must use those exact contracts; they may not infer `frame_v2`, actuation,
force transmission, or load-bearing capability from this decision.

Build:

- `joint_binding.gd`;
- `joint_state.gd`;
- extend BR1's body-only `observed_rigid_body.gd`, immutable `SensorFrame`, and `WholeBodyState`
  with joint/current-axis/inertia/availability channels;
- current-axis recomputation for every joint path.

Fixtures:

- labeled rotated box;
- gravity-off spinning body;
- single hinge with known axis;
- collider-inertia comparison.

Tests:

```text
test_lab_body_sample_frames.gd
test_lab_joint_axis_rotates_with_parent.gd
test_lab_angle_sign.gd
test_lab_unwrapped_angle_stream_continuity.gd
test_lab_direct_inertia_finite.gd
test_lab_angular_momentum_availability.gd
```

Gate:

- analytic orientation/velocity cases match tolerance;
- a rotated parent rotates sampled joint axis correctly;
- no controller reads stored construction-time world axes;
- engine inverse inertia is recorded alongside any analytic estimate.
- whole-body CoM, momentum, energy, and reference-point shift equations pass analytic assemblies;
- mismatched hinge anchors and wrapped-angle ambiguity invalidate the sample rather than drifting.

Depends on: BR1.

Unlocks: BR3A. BR4 code may be developed experimentally after BR2, but accepted L2 promotion waits
for BR3A/L1 engine truth.

### BR3A — L1 engine and contact truth

**Question:** Can we distinguish touching from bearing support?

#### Implementation checkpoint — 2026-07-21

BR3A.0 now answers that question for one deliberately narrow fixture: a single
convex box falling onto a semantically identified flat floor under the real
Godot 4.7/Jolt backend. This is commissioning evidence for the observation
pipeline, not acceptance of the full `L1.0-L1.7` engine-truth pack.

Implemented seams:

- **`observer_profile.gd` / `observed_rigid_body.gd`:** opt-in
  `full_contacts_v2` collection runs beside, and is compared with, the sealed
  legacy contact-v1 adapter. It captures append-only raw contact points in
  `_integrate_forces`, including exact physics step, observed/collider local
  positions, normals, predicted normal/tangential impulses, and semantic
  creature/body/shape identity. Runtime instance IDs, callback order, and
  rounded world positions are diagnostics only and never define contact
  identity.
- **`box_drop_contact_rig.gd` / `rig_factory.gd`:** the fixture authors semantic
  floor/body/shape IDs and derives a contact-buffer cap from four expected box
  vertices plus a four-contact diagnostic margin: cap 8 for
  `full_contacts_v2`. The legacy profile retains its historical cap 32. A
  saturated buffer invalidates evidence; it never silently truncates a result
  and calls it complete.
- **`contact_canonicalizer.gd`:** validates finite points, ownership, normal
  direction, impulse sign, body/shape provenance, and combines raw solver
  points only inside one external convex-manifold scope. It deliberately does
  not pretend that concave colliders, multiple simultaneous manifolds, or
  deformable/high-contact feet are solved.
- **`contact_lifetime_tracker.gd`:** assigns `BEGIN`, exact-step `PERSIST`, and
  exact-step `END` transitions to stable patches. A skipped step is a lineage
  failure, not an invented persistence interval.
- **`ground_qualifier.gd` / `contact_support_state.gd`:** semantic layer/tag
  qualification excludes self-contact and progresses the measured box through
  `SEARCH -> TOUCH -> LOAD -> BEARING`; loss follows the declared unload/lost
  rules. Predicted impulse divided by step time is explicitly a solver-load
  estimate, not a claim that Godot exposed an exact continuous contact force.
- **`support_geometry.gd`:** projects qualified points onto an authored support
  plane, forms point, segment/capsule, or convex-polygon support, and derives a
  center of pressure only when the required normal-impulse weights are
  available. In the live box fixture the stable polygon area was approximately
  `0.1200000047 m^2`. Floor-side points define the floor support plane because
  body-side solver points legitimately include penetration depth.

Targeted live-runtime evidence is green with zero unexpected engine errors:

| Test | Assertions | Established boundary |
| --- | ---: | --- |
| `test_lab_contact_position_frame.gd` | 14 | Real Jolt raw-v2 capture through cap, canonical patch, lifetime, semantic ground, support-state progression, and support polygon; legacy/v2 point counts agree |
| `test_lab_contact_normal_sign.gd` | 18 | Normal orientation and predicted impulse sign conventions, including rejection cases |
| `test_lab_contact_buffer_saturation.gd` | 9 | Fixture-derived capacity and fail-closed saturation diagnostics |
| `test_lab_contact_lifetime.gd` | 5 | Exact `BEGIN/PERSIST/END` step lineage and gap refusal |
| `test_lab_external_contact_dedup.gd` | 6 | One canonical owner/patch for the external convex manifold |
| `test_lab_self_contact_not_support.gd` | 8 | Same-creature contact cannot qualify as ground support |
| `test_lab_support_point_segment_polygon.gd` | 9 | Point, segment/capsule, polygon, projection, and center-of-pressure math |
| `test_lab_contact_support_state.gd` | 14 | `SEARCH/TOUCH/LOAD/BEARING/UNLOAD/LOST` transitions and invalid-input behavior |
| **BR3A.0 released-suite subtotal** | **83** | **Implementation commissioning only; no BR3A gate acceptance** |
| `test_experimental_l1_1_contact_slip.gd` | 29 | Pure normal/tangent decomposition, post-step slip authority, predicted-load semantics, unavailable ratios, staged breakaway bracketing, and adversarial config/history refusal |
| `test_experimental_l1_1_friction_breakaway.gd` | 20 | Free real-Jolt sled; material/config refusal; frictionless A/B; completed 0-40 N ramp; 22-24 N breakaway bracket; pre/post velocity separation; no hidden rail/damping |
| **L1.1 experimental subtotal** | **49** | **Green commissioning outside report-v2's immutable 62-test inventory; not BR3A acceptance evidence** |
| `test_experimental_l1_2_incline_threshold.gd` | 19 | Seven independent real-Jolt slopes; gravity normal/tangent balance; post-step hold/slide; 30-32 degree threshold; rotated-normal/cross-slope/tip gates; adversarial config/frame refusal |
| **L1.1-L1.2 experimental subtotal** | **68** | **Green commissioning outside report-v2's immutable 62-test inventory; not BR3A acceptance evidence** |
| `test_experimental_l1_3_tipping_edge.gd` | 15 | Seven independent real-Jolt COM-offset worlds; authored support-margin oracle; raw-point impulse-weighted CoP; 0.28-0.32 m stable/tip bracket around the 0.30 m edge; pre-pivot slip gate; negative-offset symmetry; adversarial config/geometry refusal |
| **L1.1-L1.3 experimental subtotal** | **83** | **Green commissioning outside report-v2's immutable 62-test inventory; not BR3A acceptance evidence** |
| `test_experimental_l1_4_pad_center_of_pressure.gd` | 20 | Seven independent free-pad load locations; raw-point pressure refusal; complete 0.30 x 0.20 m manifold; monotonic/mirrored CoP; 6 mm CoP and 0.25 N load gates; digest-bound adversarial analyzer |
| **L1.1-L1.4 experimental subtotal** | **103** | **Green commissioning outside report-v2's immutable 62-test inventory; not BR3A acceptance evidence** |
| `test_experimental_l1_5_timestep_convergence.gd` | 13 | Physical-time-preserving 30/60/120/240 Hz dynamic drop plus static eccentric pad; TOUCH/LOAD phase separation; first-principles timing/speed/impulse gates; contiguous accepted envelope; causal 30 Hz rejection; adversarial analyzer |
| **L1.1-L1.5 experimental subtotal** | **116** | **Green commissioning outside report-v2's immutable 62-test inventory; not BR3A acceptance evidence** |
| `test_experimental_l1_6_solver_step_sensitivity.gd` | 17 | Eight fresh Jolt spaces plus repeat controls; settings-notification boundary; exact-cell solver admission; whole-system external-impulse reconstruction; local raw-load transmission-blindness detection; adversarial analyzer |
| **L1.1-L1.6 experimental subtotal** | **133** | **Green commissioning outside report-v2's immutable 62-test inventory; not BR3A acceptance evidence** |
| `test_experimental_l1_7_mass_ratio_grid.gd` | 20 | Fixed-2-kg neutral plus twenty directed 2:1-1024:1 cells and three fresh-world repeats; tagged activation warmup; physical-metric classification; 16:1-32:1 top-heavy bracket; bottom-heavy measured endpoint; local/transmitted-load separation; adversarial analyzer |
| **L1.1-L1.7 experimental subtotal** | **153** | **All planned L1.0-L1.7 implementation cells now exist; experimental cells remain outside report-v2 and are not BR3A acceptance evidence** |
| `test_experimental_br3a_commissioning_status.gd` | 13 | Byte-pinned commissioning schema/status/test sources; exact 8/8-cell and 83+153 assertion accounting; immutable 62-test report-v2 guard; milestone/knowledge/locomotion zero-claim gates; adversarial readiness refusal |
| `test_experimental_l1_8_contact_discretization.gd` | 28 | Separate nonblocking 1/4/16/64/100 equal-area pack outside the pinned grid; measured 1.00x/4.00x/11.21x same-body multi-manifold raw-sum overcount with reconstruction authoritative; frozen-policy 64/100 enumeration refusal; actuator-framing refusal; digest-bound adversarial analyzer |
| `test_experimental_br3a_knowledge_draft_guard.gd` | 15 | Development-draft containment outside the pinned grid; strict draft schema plus forged-field refusal; accepted-knowledge verifier/query/repair/admission all fail closed on drafts; nine separately admitted entries exclude draft identity and repair authority |
| `test_experimental_br3a_knowledge_admission_contract.gd` | 22 | Exact decision/report/receipt identity; both production-attested capsules per cited program; 8 milestone observations plus 1 supplementary constraint; structural zero-repair/guidance policy; report, decision, claim, classification, containment-program, and rule-injection refusal; live installed-entry and shared-catalog readback |

L1.1 friction-slip/breakaway, L1.2 incline threshold, and L1.3 support-edge
tipping, L1.4 static foot-pad pressure, L1.5 timestep convergence, and L1.6
solver-step sensitivity, plus L1.7 directed contact-stack mass-ratio behavior are
implemented and
green as experimental commissioning, but remain outside the released signed
inventory. All eight planned `L1.0-L1.7` implementation cells now exist. The
separate `L1.8` 1/4/16/64/100-contact discretization pack was implemented on
2026-07-22 as additional nonblocking experimental work outside the pinned
grid (see the L1.8 checkpoint below). Still open: promotion-grade L1.1-L1.7
inventory/report versioning and campaign-level repeat evidence. BR2.1's
observer prerequisite is accepted, but until BR3A
received its later explicit gate decision, this work proved neither a
load-bearing leg nor standing, bracing, recovery, or walking.

`BR3A_L1_commissioning_status_v1.json` now makes that boundary executable.
`br3a_commissioning_registry.gd` byte-pins the owned schema and status file,
verifies SHA-256 identity for all eight experimental sources, reopens the BR1
report-v2 inventory, verifies its existing SHA-256 and exact 62-test identity,
and proves none of the experimental tests overlap it. The historical
commissioning-snapshot denominators are therefore explicit:

- planned L1.0-L1.7 implementation cells: **8/8 (100%)**;
- L1.0 released-suite commissioning assertions: **83**;
- L1.1-L1.7 experimental assertions: **153**;
- total implementation-commissioning assertions: **236**;
- BR3A promotion blockers open at snapshot time: **5/5**;
- formal BR3A milestone acceptance at snapshot time: **no**;
- accepted BR3A encyclopedia entries: **0**;
- automatic creature guidance from BR3A findings: **forbidden**; and
- standing, bracing, fall arrest, getting up, and walking: **0% proven**.

The five promotion blockers are not paperwork aliases for the same test run:

1. `PROMOTION_GRADE_L1_BUNDLE_FAMILY_MISSING`: the experimental executables
   do not yet emit immutable per-cell manifests, metric artifacts, summaries,
   checksums, and bundle receipts through a registered L1 experiment family;
2. `BR3A_CERTIFICATION_REPORT_FAMILY_MISSING`: BR3A needs its own report schema
   and claim boundary;
3. `BR3A_DETACHED_ATTESTATION_DOMAIN_MISSING`: the report requires a distinct
   HMAC domain and receipt directory so BR1 credentials cannot authorize it;
4. `CLEAN_FRESH_PROCESS_BR3A_CAMPAIGN_MISSING`: commissioning reruns are not a
   clean source-pinned production campaign with required repeats/readbacks; and
5. `EXPLICIT_BR3A_MILESTONE_DECISION_MISSING`: only Cole can accept the bounded
   milestone after the machine evidence exists.

This must be a new `sporespore.lab.br3a_*` trust family, version 1 within that
family. It must **not** be implemented by adding the experimental files to
`BR1_required_lab_tests_v2.json`, broadening BR1's claim, or casually calling
the result “BR1 report-v3.” L1.8 contact discretization and the post-L2
articulated mass-ratio grid remain valuable separate work, but neither can
erase these five blockers.

The final development-regression checkpoint ran both trust domains separately
on 2026-07-21:

| Domain | Pattern | Programs | Assertions | Failures/timeouts | Unexpected engine errors |
| --- | --- | ---: | ---: | ---: | ---: |
| Immutable released regression | `test_lab_*.gd` | 62/62 | 1,118/1,118 | 0 | 0 |
| Experimental BR3A commissioning/readiness | `test_experimental_*.gd` | 9/9 | 166/166 | 0 | 0 |

The released suite retains one intentional expected engine-error fixture; the
runner reported zero **unexpected** engine errors. These are development
regressions from the current worktree, not a production BR3A certification.
They remain separate instead of being advertised as a fictitious combined
71-test signed suite.

#### L1.1 friction-sled checkpoint — 2026-07-21

The L1.1 fixture is `scripts/lab/rigs/friction_sled_rig.gd`, registered as
`friction_sled_v1`. It is a 4 kg, `0.8 x 0.2 x 0.6 m` freely rotating box on a
flat static floor. The low/wide proportions make slide-before-tip likely, but
the fixture does not enforce that outcome: `lock_rotation=false`, damping is
zero, and there is no rail, custom integrator, or stabilizing force. Unknown
fixture parameters—including a proposed rotation rail—fail closed. Both
surfaces receive the same `PhysicsMaterial`, `rough=false`, and bounce zero.
Godot 4.7 documents that two non-rough surfaces use the lower authored
friction, so the equal-material pair retains the requested one-factor value.

The runner calls `RigidBody3D.apply_central_force(Vector3(force_n, 0, 0))`
exactly once per physics tick. This matters because Godot defines that API as a
time-dependent force meant to be applied every physics update; using an impulse
each tick would make the experiment timestep-dependent by construction. The
operation is at the center of mass, so it contributes no direct applied torque.
The body is still free to pitch because ground friction acts below its center.

For contact normal \(\mathbf n\), solver impulse \(\mathbf J\), and physics
step \(\Delta t\), `contact_slip_observer.gd` computes:

\[
J_n = \mathbf J\cdot\mathbf n,
\qquad
\mathbf J_t = \mathbf J - J_n\mathbf n
\]

\[
\widehat F_n = J_n/\Delta t,
\qquad
\widehat{\mathbf F}_t = \mathbf J_t/\Delta t
\]

The hats are deliberate: Godot exposes a contact impulse, and this bootstrap
uses impulse divided by one step only as a predicted step-average solver-load
estimate. It is not relabeled as an exact continuous contact force.

L1.1 exposed a subtler velocity timing defect. The contact-relative velocity
captured from `PhysicsDirectBodyState3D` inside `_integrate_forces` behaved as a
pre-constraint candidate. While friction held the body at exactly zero
post-step displacement/velocity, the callback reported:

| Applied force | Callback tangential candidate | Post-step slip | Window displacement |
| ---: | ---: | ---: | ---: |
| 8 N | 0.03333 m/s | 0.00000 m/s | 0.00000 m |
| 16 N | 0.06667 m/s | 0.00000 m/s | 0.00000 m |
| 20 N | 0.08333 m/s | 0.00000 m/s | 0.00000 m |
| 22 N | 0.09167 m/s | 0.00000 m/s | 0.00000 m |

Those candidate values are exactly the one-tick free acceleration
\(F\Delta t/m\) for a 4 kg body at 60 Hz. Treating them as slip would falsely
declare every successfully friction-held foot to be sliding. The observer now
keeps that input as
`integrate_callback_pre_constraint_candidate_v1`, marks it forbidden for slip
classification, and reconstructs authoritative post-step contact-point motion:

\[
\mathbf v_{point}^{+}
=
\mathbf v_{com}^{+}
+
\boldsymbol\omega^{+}\times(\mathbf p-\mathbf c)
\]

\[
v_{slip}
=
\left\|
(\mathbf I-\mathbf n\mathbf n^T)
(\mathbf v_{point}^{+}-\mathbf v_{other}^{+})
\right\|
\]

The `+` means after the constraint solve. This first fixture's counterparty is a
static body, so \(\mathbf v_{other}^{+}=0\). A future moving-ground fixture must
supply its measured post-step point velocity; it may not inherit zero.

The real 60 Hz Jolt results were:

- friction `0.0`, 8 N: `1.00000 m/s` maximum post-step slip and `0.18278 m`
  displacement in the 15-sample observation window;
- friction `0.6`, 8 N: zero post-step slip/displacement, approximately
  `7.924 N` opposing predicted contact shear, and tangential balance residual
  below `1 N`;
- friction `0.6`, monotonic stages `0, 8, 16, 20, 22, 24, 26, 28, 32, 40 N`:
  last completed hold at `22 N`, first completed slide at `24 N`;
- predicted normal load at those endpoints: approximately `39.215 N` and
  `39.196 N`, producing the empirical ratio bracket `0.56101-0.61230` around
  the authored `0.6`; and
- predicted contact shear saturated near `23.53 N` after breakaway while body
  tilt remained below the test's five-degree contamination gate (observed
  `0.000 deg`).

`friction_breakaway_analyzer.gd` never derives an exact coefficient from one
frame. It classifies fixed completed windows as `HELD`, `AMBIGUOUS`, or
`SLIDING`, requires a strictly increasing force schedule and complete contact,
and returns:

\[
F_{last\ held}
\le
F_{breakaway}
\le
F_{first\ sliding}
\]

The current `22-24 N` / `0.56101-0.61230` bracket applies only to this material
pair, body, Godot 4.7/Jolt build, 60 Hz timestep, and the project's current
20/4 velocity/position solver steps. L1.5-L1.7 must test timestep, solver-step,
and mass-ratio sensitivity before the knowledge catalog generalizes it.

The L1.1 test files deliberately use `test_experimental_*`. Adding them to
`test_lab_*.gd` would change the signed inventory from 62 tests without a new
report contract and would invalidate report-v2's exact identity. Promotion
therefore still requires a versioned inventory/report/receipt family, repeated
fresh-process execution, admission rules, and Cole's later BR3A decision.

#### L1.2 incline-block checkpoint — 2026-07-21

`scripts/lab/rigs/incline_block_rig.gd` registers `incline_block_v1`. Every
angle is a fresh independent Godot world containing the same 4 kg low/wide
block and equal-material pair used by L1.1. The plane is authored at its final
angle before entering the scene tree; it is never rotated under a live body.
The block remains free: no translation or rotation constraint, no damping,
no custom integrator, and no applied drive other than gravity. A hidden rail
parameter and slopes outside the declared `0-60 degree` range fail closed.

For slope angle \(\theta\), plane normal \(\mathbf n\), and gravity
\(\mathbf g\), the gravitational demand is decomposed independently of the
contact solver:

\[
F_n = mg\cos\theta,
\qquad
F_t = mg\sin\theta,
\qquad
\frac{F_t}{F_n}=\tan\theta
\]

For an ideal Coulomb threshold with authored pair friction \(\mu=0.6\):

\[
\theta_{critical}=\arctan(\mu)=30.96376^\circ
\]

`incline_threshold_analyzer.gd` accepts only complete, strictly increasing,
independent-angle trials with the correct rotated contact normal and L1.1's
post-step slip channel. It classifies completed windows as `HELD`,
`AMBIGUOUS`, or `SLIDING`; coherently rehashed unknown config fields and a
wrong normal frame both fail closed.

The seven real 60 Hz Godot 4.7/Jolt trials produced:

| Slope | Post-step slip | Down-slope displacement | Predicted normal / analytic normal | Predicted shear / gravity shear | Result |
| ---: | ---: | ---: | ---: | ---: | --- |
| 0° | 0.00000 m/s | 0.00000 m | 39.276 / 39.200 N | 0.184 / 0.000 N | held |
| 20° | 0.00000 m/s | 0.00000 m | 36.839 / 36.836 N | 13.414 / 13.407 N | held |
| 28° | 0.00000 m/s | 0.00000 m | 34.620 / 34.612 N | 18.380 / 18.403 N | held |
| 30° | 0.00000 m/s | 0.00000 m | 33.963 / 33.948 N | 19.424 / 19.600 N | held |
| 32° | 0.40993 m/s | 0.09043 m | 33.245 / 33.243 N | 19.953 / 20.773 N | sliding |
| 34° | 1.20061 m/s | 0.26484 m | 32.500 / 32.498 N | 19.507 / 21.920 N | sliding |
| 40° | 3.56003 m/s | 0.78530 m | 30.031 / 30.029 N | 18.025 / 25.197 N | sliding |

Thus the empirical threshold is:

\[
30^\circ \le \theta_{breakaway} \le 32^\circ
\]

or, expressed as shear/normal demand:

\[
0.57735=\tan(30^\circ)
\le \mu_{effective}
\le \tan(32^\circ)=0.62487
\]

The analytic `30.96376 degree` prediction lies inside both brackets. At 40
degrees, predicted solver shear divided by predicted normal load was within
`0.02` of the authored `0.6`, independently confirming the L1.1 saturation
observation. Every measured contact normal had dot product `1.0000000` with
the authored rotated-plane normal; cross-slope displacement stayed below
`0.001 m`; and classification occurred before `3 degrees` of block/plane tilt.

The callback's pre-constraint velocity again appeared nonzero during held
trials—`0.05586 m/s` at 20 degrees through `0.08167 m/s` at 30 degrees—while
post-step slip and displacement were exactly zero. L1.2 therefore independently
confirms L1.1's observer correction: `_integrate_forces` contact velocity is a
solver-input diagnostic in this configuration, not a support-slip verdict.

This is still one equal-material pair, one mass/shape, 60 Hz, and the current
20/4 Jolt solver-step configuration. It does not establish uneven-terrain
support, a load-bearing limb, bracing, standing, recovery, or walking. The
experimental test must enter a later versioned signed inventory and repeat
campaign before L1.2 becomes promotion evidence.

#### L1.3 tipping-prism checkpoint — 2026-07-21

`scripts/lab/rigs/tipping_prism_rig.gd` registers `tipping_prism_v1`. It is a
freely rotating 4 kg prism with a fixed `0.6 x 1.0 x 0.8 m` collision shape on
a flat floor. Only its custom local center-of-mass x coordinate changes, and
every coordinate receives a fresh world. The body has no rail, rotation lock,
damping, custom integrator, controller, applied impulse, or rescue force.
Unknown fixture parameters—including a proposed balance umbrella—fail closed.
The equal-material pair uses friction `1.0` to make support-edge rotation, not
early translational breakaway, the intended one-factor transition; the live
pre-pivot slip measurement still has authority to reject that assumption.

For authored footprint half-width (b=0.30\,m) and local horizontal center of
mass (x_{com}), the independent rectangular-footprint prediction is:

\[
m_{support}=b-|x_{com}|
\]

\[
m_{support}>0 \Rightarrow \text{inside the flat support polygon},
\qquad
m_{support}<0 \Rightarrow \text{gravity torque about the same-sign edge}
\]

`support_geometry.gd` separately projects the custom COM into the authored
four-corner footprint and must reproduce that signed margin within
`1e-5 m`. The live solver path does not reuse the authored margin to decide
whether the body tipped. For each raw Jolt contact point (i), the predicted
normal-impulse weight is:

\[
w_i=\max(\mathbf J_i\cdot\mathbf n_i,0)
\]

and the diagnostic center of pressure is:

\[
\mathbf p_{CoP}
=
\frac{\sum_i w_i\mathbf p_i}{\sum_i w_i}
\]

Only CoP samples collected while body tilt is at most 5 degrees can establish
the initiating bottom-edge load. Once the prism hits the floor on its side,
that new contact may lie far outside the original footprint and is explicitly
forbidden from masquerading as evidence of the earlier pivot. Likewise, slip
uses post-step rigid contact-point kinematics only while tilt is below the
2-degree pivot marker. A tip verdict requires sustained rotation above 20
degrees, the predicted rotation sign, CoP migration to at least 80% of the
same-sign edge, a witnessed pivot, and pre-pivot slip below `0.05 m/s`.

The real 60 Hz Godot 4.7/Jolt results were:

| COM x | Analytic margin | Maximum tilt | Maximum pre-pivot CoP/edge | Maximum pre-pivot slip | Result |
| ---: | ---: | ---: | ---: | ---: | --- |
| 0.00 m | +0.30 m | 0.00° | 0.027 | 0.00001 m/s | stable |
| +0.15 m | +0.15 m | 0.00° | 0.485 | 0.00003 m/s | stable |
| +0.24 m | +0.06 m | 0.00° | 0.667 | 0.00021 m/s | stable |
| +0.28 m | +0.02 m | 0.00° | 0.740 | 0.00029 m/s | stable |
| +0.32 m | -0.02 m | 90.12° | 1.000 | 0.00349 m/s | tipping; pivot tick 23 |
| +0.36 m | -0.06 m | 91.98° | 1.000 | 0.00445 m/s | tipping; pivot tick 14 |
| -0.36 m | -0.06 m | 91.98° | 1.000 | 0.00445 m/s | mirrored tipping; pivot tick 14 |

Thus:

\[
0.28\,m
\le |x_{critical}| \le
0.32\,m
\]

and the analytic `0.30 m` edge lies inside the empirical `0.04 m` bracket.
Positive and negative `0.36 m` trials matched within the declared tilt and CoP
symmetry tolerances and rotated toward their respective predicted edge. The
test passed 15/15 assertions with zero engine errors. This establishes one
passive support-edge/pivot oracle for this exact box, material, timestep, and
solver configuration. It does not establish active load bearing, disturbance
rejection, a limb, bracing, standing, recovery, or walking; it remains
fixture-bounded inside the later versioned BR3A promotion and decision.

#### L1.4 foot-pad center-of-pressure checkpoint — 2026-07-21

`scripts/lab/rigs/foot_press_rig.gd` registers `foot_press_v1`: a free 2 kg,
`0.30 x 0.08 x 0.20 m` rigid pad on a flat floor. Seven fresh worlds place its
custom internal COM at x = `-0.12, -0.09, -0.045, 0, +0.045, +0.09, +0.12 m`.
All locations remain inside the pad's `+/-0.15 m` x support extent. The fixture
has no floor clamp, rail, rotation lock, damping, custom integrator, controller,
or applied force beyond gravity; proposed hidden clamps and out-of-range load
locations fail closed.

`contact_pressure_observer.gd` accepts only finite same-step semantic floor
contacts whose normal agrees with the authored support plane and whose impulse
quality is exactly `jolt_predicted_estimate`. It computes:

\[
w_i=\max(\mathbf J_i\cdot\mathbf n_i,0),
\qquad
\widehat N=\frac{\sum_i w_i}{\Delta t},
\qquad
\widehat{\mathbf p}_{CoP}
=\frac{\sum_i w_i\mathbf p_i}{\sum_iw_i}
\]

The hats and the returned
`impulse_weighted_jolt_predicted_estimate_v1` quality label are mandatory:
this is a predicted per-step impulse/load channel, not an exact continuous
force transducer. Missing contacts, zero total weight, wrong normals, unknown
impulse quality, nonfinite input, or contact-cap saturation cannot manufacture
a CoP.

For a static free pad with gravity as its only external load, the independent
equilibrium oracles are:

\[
N=mg,
\qquad
(p_{CoP,x},p_{CoP,z})=(p_{COM,x},p_{COM,z})
\]

The real 60 Hz results, impulse-weighted across each completed 60-sample window,
were:

| Internal load x | Measured CoP x/z | Mean CoP projection error | Predicted / gravity load | Tilt / slip |
| ---: | ---: | ---: | ---: | ---: |
| -0.120 m | -0.11795 / +0.00026 m | 0.00206 m | 19.797 / 19.600 N | 0.0000° / 0.00000 m/s |
| -0.090 m | -0.09021 / +0.00016 m | 0.00026 m | 19.698 / 19.600 N | 0.0000° / 0.00000 m/s |
| -0.045 m | -0.04522 / +0.00006 m | 0.00022 m | 19.645 / 19.600 N | 0.0000° / 0.00000 m/s |
| 0.000 m | -0.00023 / +0.00002 m | 0.00023 m | 19.649 / 19.600 N | 0.0000° / 0.00000 m/s |
| +0.045 m | +0.04483 / +0.00011 m | 0.00020 m | 19.637 / 19.600 N | 0.0000° / 0.00000 m/s |
| +0.090 m | +0.08859 / +0.00007 m | 0.00141 m | 19.751 / 19.600 N | 0.0000° / 0.00000 m/s |
| +0.120 m | +0.11507 / +0.00015 m | 0.00494 m | 19.812 / 19.600 N | 0.0000° / 0.00000 m/s |

Every analysis frame retained the full `0.300 x 0.200 m` raw contact span.
Measured CoP moved strictly monotonically with the internal load, the centered
load remained within 5 mm of both pad axes, and opposite offsets mirrored
within 5 mm. `pad_cop_analyzer.gd` now seals those properties plus a 6 mm mean
CoP-error ceiling, 0.25 N mean normal-load error, 0.5-degree tilt, 0.005 m/s
slip, 0.002 m displacement, sample completeness, and cap completeness behind a
canonical config digest. Unknown coherently rehashed fields and a corrupted
edge-load error fail closed. The complete test passed 20/20 assertions with
zero engine errors.

This establishes static predicted-impulse CoP calibration for one rigid flat
foot at 60 Hz and the current solver settings. It does not establish dynamic
CoP, exact continuous force, compliant/digit pressure independence, a
load-bearing limb, bracing, standing, or walking. L1.5-L1.7 still own timestep,
solver-step, and mass-ratio applicability, L1.8 owns contact discretization,
and the later signed promotion plus explicit BR3A decision preserve those
boundaries.

#### L1.5 timestep-convergence checkpoint — 2026-07-21

`test_experimental_l1_5_timestep_convergence.gd` changes only
`Engine.physics_ticks_per_second` across `30, 60, 120, 240 Hz`. Geometry, mass,
materials, gravity, observer profile, Jolt velocity/position solver steps, and
physical durations remain fixed. Tick counts scale with rate, so each cell runs
the same two seconds of dynamic box drop plus the same 1.5-second settle and
one-second eccentric-foot pressure window. This prevents a high-rate cell from
receiving more physical settling time merely because it has more ticks.

The first implementation exposed and repaired a measurement-phase error. A
positive predicted impulse is `LOAD`, not `TOUCH`; using the first positive
pressure sample as the first contact event can report collision too late.
L1.5 now keeps four distinct witnesses:

1. first finite semantic raw contact (`TOUCH`);
2. first positive impulse-weighted pressure (`LOAD`);
3. last airborne post-step velocity before `TOUCH`; and
4. peak predicted normal arrest impulse after contact begins.

For initial bottom clearance (h=1.2\,m) and (g=9.8\,m/s^2), the independent
continuous-time drop oracles are:

\[
t_{impact}=\sqrt{\frac{2h}{g}}=0.494872\,s,
\qquad
v_{impact}=\sqrt{2gh}=4.84974\,m/s
\]

The analytic time must fall inside, or within one nominal step of, the bracket
between the last airborne frame and first semantic contact. Last-airborne
speed error is normalized by one gravity step (g\Delta t); peak predicted
normal impulse is compared with arrest momentum (mv_{impact}=9.69948\,N s).
The dynamic cell additionally gates penetration, final vertical speed, and
rest-height bias. The static companion must retain L1.4 CoP, normal-load, tilt,
slip, sample-completeness, and contact-cap bounds at every tested rate—even a
rate rejected by the impact channel.

The real Godot 4.7/Jolt results were:

| Rate | First touch/load | Raw time error | Last-airborne / analytic speed | Peak impulse / arrest momentum | Minimum bottom y | Final center y | Dynamic class |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 30 Hz | 0.666667 / 0.666667 s | 0.171795 s | 4.90000 / 4.84974 m/s | 10.46674 / 9.69948 Ns | -0.09578 m | 0.28000 m | rejected |
| 60 Hz | 0.516667 / 0.516667 s | 0.021795 s | 4.73667 / 4.84974 m/s | 9.81468 / 9.69948 Ns | -0.00000 m | 0.30000 m | accepted |
| 120 Hz | 0.508333 / 0.508333 s | 0.013462 s | 4.81833 / 4.84974 m/s | 9.81452 / 9.69948 Ns | -0.00458 m | 0.29542 m | accepted |
| 240 Hz | 0.500000 / 0.500000 s | 0.005128 s | 4.81833 / 4.84974 m/s | 9.73282 / 9.69948 Ns | 0.00000 m | 0.30000 m | accepted |

The 30 Hz body was not merely “less accurate”: it missed the analytic impact
bracket after falling through the surface, reached `95.78 mm` of penetration,
and settled `20 mm` below the authored rest center. It is therefore a named
negative cell with `ANALYTIC_IMPACT_OUTSIDE_BRACKET`, `PENETRATION_EXCEEDED`,
and `REST_HEIGHT_ERROR_EXCEEDED`, despite eventually reporting a plausible
arrest impulse. This is why a single impulse/load number cannot certify a
contact simulation.

At all four rates, the eccentric `+0.12 m` foot produced the same rounded
impulse-weighted CoP (`+0.11507 m`), mean projection error (`0.00494 m`), and
normal-load error (`0.2116 N`), with no tilt or slip. Static contact pressure is
therefore not what rejects 30 Hz; dynamic collision timing/penetration is.

`timestep_convergence_analyzer.gd` seals the full rate grid and thresholds. A
rejected low rate is allowed, but accepted rates must form a contiguous
high-rate suffix, include the finest rate, meet the declared minimum count,
retain valid static pressure everywhere, and contract dynamic timing, speed,
and impulse errors from the coarsest accepted cell to the finest. It admits a
bounded `60-240 Hz` envelope and rejects `30 Hz`. The test passed 13/13
assertions with zero engine errors. This is not a universal minimum rate: new
geometry, speeds, continuous-collision settings, articulation, mass ratios,
and solver settings require their own applicability evidence. It establishes
neither a load-bearing limb, bracing, standing, nor walking.

#### L1.6 solver-step and transmitted-load checkpoint — 2026-07-21

`solver_stack_v1` is ten identical `1 kg`, `0.5 x 0.2 x 0.5 m` free rigid
boxes stacked on a static floor. Gravity is the only external drive; damping,
sleep, custom integration, controller forces, joints, axis locks, and hidden
supports are absent. L1.6 refuses unequal masses so the next cell can vary mass
ratio without silently contaminating this one-factor sweep.

Godot 4.7's Jolt backend caches the project solver settings and copies
`simulation_velocity_steps` and `simulation_position_steps` into each new
Jolt space. The commissioning runner therefore cannot mutate the existing
default world. For every cell it performs this exact sequence:

1. write both `ProjectSettings` values;
2. cross a process boundary so Jolt's `settings_changed` listener refreshes
   its cache;
3. construct a new `SubViewport` with `own_world_3d=true`; and
4. build, settle, and measure the stack only in that fresh world.

The first repeat campaign caught why step 2 is mandatory: constructing the
world immediately after the write shifted each numerical trajectory by one
scheduled cell. Readback from `ProjectSettings` was correct while the newly
constructed Jolt space had snapshotted the previous cached value. Those
mislabelled results were invalidated, the harness was repaired, and repeat
controls now reproduce the corrected pass/fail classifications in fresh
spaces. This is exactly the kind of small, singular pipeline failure the
bootstrap is meant to expose before a creature depends on it.

Local raw contact impulse is not sufficient to infer load transmitted through
a coupled system. L1.6 therefore adds a whole-system external-impulse
reconstructor. For body set \(B\), consecutive post-step states, known gravity
impulse \(\mathbf J_g\), and step \(\Delta t\):

\[
\mathbf P^- = \sum_{b\in B}m_b\mathbf v_b^-,
\qquad
\mathbf P^+ = \sum_{b\in B}m_b\mathbf v_b^+
\]

\[
\widehat{\mathbf J}_{external,unknown}
=\mathbf P^+-\mathbf P^- - \mathbf J_g,
\qquad
\widehat N_{external}
=\frac{\widehat{\mathbf J}_{external,unknown}\cdot\mathbf n}{\Delta t}
\]

Body identity and mass must match across the two states or reconstruction
fails closed. This balance reconstructs only the **aggregate unknown external
impulse on the declared system**. It cannot allocate that impulse among feet,
contacts, or joints, and it cannot produce a per-foot CoP. Those require later
instrumentation and must never be invented from this residual.

The corrected real Godot 4.7/Jolt results were:

| Velocity / position steps | Raw bottom load | Reconstructed / expected whole-stack load | Max center-height error | Max pair/floor penetration | Max speed / tilt | Class |
| ---: | ---: | ---: | ---: | ---: | ---: | --- |
| 2 / 4 | 10.974 N | 93.886 / 98.000 N | 1.6953 m | 0.4937 / 0.0399 m | 4.8460 m/s / 151.246 deg | rejected |
| 4 / 4 | 10.167 N | 98.640 / 98.000 N | 0.2617 m | 0.0291 / 0.0255 m | 0.5395 m/s / 11.855 deg | rejected |
| 10 / 4 | 9.823 N | 98.114 / 98.000 N | 0.1126 m | 0.0199 / 0.0181 m | 0.2353 m/s / 5.257 deg | rejected |
| 20 / 1 | 9.821 N | 98.005 / 98.000 N | 0.0198 m | 0.0045 / 0.0027 m | 0.0552 m/s / 0.905 deg | accepted |
| 20 / 2 | 9.821 N | 98.005 / 98.000 N | 0.0198 m | 0.0045 / 0.0027 m | 0.0552 m/s / 0.905 deg | accepted |
| 20 / 4 | 9.821 N | 98.005 / 98.000 N | 0.0198 m | 0.0045 / 0.0027 m | 0.0552 m/s / 0.905 deg | accepted |
| 20 / 8 | 9.821 N | 98.005 / 98.000 N | 0.0198 m | 0.0045 / 0.0027 m | 0.0552 m/s / 0.905 deg | accepted |
| 40 / 4 | 9.822 N | 98.000 / 98.000 N | 0.0042 m | 0.0013 / 0.0007 m | 0.0057 m/s / 0.207 deg | accepted |

The fixed-position velocity sweep changes class once, from rejected below 20
steps to accepted at 20 and 40. The four measured position cells at velocity
20 all pass. This does **not** license interpolation or an engine-wide claim:
only the eight measured combinations are admitted for this exact equal-mass
stack. The project's current 20/4 cell is inside that measured envelope.

The load-channel result is the more consequential finding. At the stable
20/4 project cell, raw predicted impulses on only the bottom body's floor
contacts average approximately `9.821 N`—one box weight, or about ten percent
of the stack load—while whole-system momentum balance reconstructs
approximately `98.005 N` against the independent `98.000 N` gravity oracle.
Thus the current raw per-body contact channel is a useful local diagnostic but
is transmission-blind in this coupled stack. A brace controller, strength
validator, or repair advisor may not treat it as the total load carried by a
limb or creature.

The complete cell passed 17/17 assertions with zero engine errors. It
establishes neither articulated constraint convergence, a mass-ratio envelope,
per-contact reconstructed load allocation, a load-bearing limb, bracing,
standing, recovery, nor walking.

#### L1.7 directed mass-ratio checkpoint — 2026-07-21

`mass_ratio_stack_v1` contains two geometrically identical free
`0.5 x 0.2 x 0.5 m` boxes in contact with each other and a static floor. It
holds total mass fixed at `2 kg`, keeps the project's accepted measured
`60 Hz`, `20/4` timestep/solver cell, and changes only how mass is distributed.
For heavy-to-light ratio \(r\) and total mass \(M\):

\[
m_{light}=\frac{M}{1+r},
\qquad
m_{heavy}=\frac{Mr}{1+r}
\]

Every unequal ratio is run twice: `top` places \(m_{heavy}\) above
\(m_{light}\), while `bottom` reverses them. The `1:1` control is neutral.
This is essential: the nominal magnitude `32:1` does not describe which body
must push which. There are no joints, motors, springs, dampers, sleep, axis
locks, custom integration, controller forces, or hidden supports. L1.7 is a
contact-stack experiment; articulated parent/child mass ratios remain open.

The commissioning survey exposed another lifecycle hazard. A newly attached
`SubViewport` world can consume its first physics frame while becoming active.
In the initial runner, the first cell happened to capture epoch 0 while every
later fresh world missed its first callback. A render/process-frame wait did
not repair this consistently. The final runner opens one explicit tagged
physics warmup epoch per fresh world and excludes that activation tick from
evaluated settling. All primary and repeat cells then retain finite body
samples, complete whole-system reconstruction, and unsaturated raw-contact
buffers (peak bottom/top counts at most `8/8` under cap `16`).

`mass_ratio_stability_analyzer.gd` does not use ratio as a classification
threshold. It gates measured contact persistence, center-height error, pair
separation/penetration, floor penetration, linear/angular speed, tilt, lateral
drift, pair-relative speed, linear kinetic energy, reconstructed-load error,
and raw-load-model residual. The principal bounds are `10 mm` center-height
error, `5 mm` pair/floor penetration or pair vertical error, `0.16 m/s` linear
speed, `0.3 rad/s` angular speed, `1 degree` tilt, `5 mm` drift, and `0.03 J`
linear kinetic energy. A test that worsens only the measured 16:1 top-heavy
height error moves the reported bracket to 8:1-16:1, proving classification is
driven by physical evidence rather than a hard-coded preferred ratio.

The corrected real Godot 4.7/Jolt results were:

| Ratio | Top-heavy: height / floor penetration | Top-heavy: speed / tilt / drift | Top-heavy class | Bottom-heavy class |
| ---: | ---: | ---: | --- | --- |
| 1:1 neutral | 0.0000 / 0.0000 m | 0.0011 m/s / 0.000 deg / 0.0000 m | accepted | same neutral cell |
| 2:1 | 0.0000 / 0.0000 m | 0.1201 m/s / 0.000 deg / 0.0001 m | accepted | accepted |
| 4:1 | 0.0003 / 0.0002 m | 0.1229 m/s / 0.040 deg / 0.0002 m | accepted | accepted |
| 8:1 | 0.0012 / 0.0009 m | 0.1308 m/s / 0.107 deg / 0.0006 m | accepted | accepted |
| 16:1 | 0.0038 / 0.0031 m | 0.1453 m/s / 0.533 deg / 0.0026 m | accepted | accepted |
| 32:1 | 0.0347 / 0.0208 m | 0.2491 m/s / 1.864 deg / 0.0082 m | rejected | accepted |
| 64:1 | 0.0454 / 0.0237 m | 0.3378 m/s / 1.488 deg / 0.0101 m | rejected | accepted |
| 128:1 | 0.0752 / 0.0393 m | 0.5588 m/s / 2.948 deg / 0.0174 m | rejected | accepted |
| 256:1 | 0.1825 / 0.1018 m | 0.7584 m/s / 19.629 deg / 0.5653 m | rejected | accepted |
| 512:1 | 0.2000 / 0.0988 m | 1.0441 m/s / 35.760 deg / 0.4858 m | rejected | accepted |
| 1024:1 | 0.2000 / 0.1082 m | 1.4147 m/s / 19.111 deg / 0.5182 m | rejected | accepted |

Thus the measured top-heavy contact-stack boundary is:

\[
16:1\ \text{accepted}
\quad<\quad
r_{failure}
\quad\le\quad
32:1\ \text{rejected}
\]

All measured bottom-heavy cells through 1024:1 pass, but the upper boundary is
explicitly **open beyond the measured grid**. No interpolation between cells
is permitted. Fresh-world repeats of top-heavy 16:1, top-heavy 32:1, and
bottom-heavy 1024:1 reproduce the same classifications.

Contact presence alone does not diagnose stability. Floor-pressure and
box-pair contact fractions remained `1.00` even for top-heavy 256:1-1024:1,
where penetration exceeded `98 mm`, drift approached `0.57 m`, and tilt
reached `35.76 degrees`. A future limb can therefore remain “in contact” while
being completely unable to transmit load cleanly.

The raw impulse channel repeats L1.6's warning across the full directed grid.
With total mass \(M\) and bottom mass \(m_b\), the observed ratio follows:

\[
\frac{\widehat N_{raw,bottom}}{\widehat N_{whole-system}}
\approx \frac{m_b}{M}
\]

At top-heavy 1024:1, raw bottom-floor predicted load is only about `0.0215 N`
while whole-system balance reconstructs `19.6671 N` against the `19.6000 N`
gravity oracle. In the reversed bottom-heavy cell raw load is `19.6237 N` and
whole-system load is `19.6000 N`. The raw floor impulse is therefore a local
bottom-body diagnostic in this stack, not an authority for transmitted load.

The final test passed 20/20 assertions with zero engine errors. It establishes
a directional contact-stack envelope only. It does not establish an
articulated mass-ratio envelope, a joint constraint, a limb, bracing, standing,
recovery, or walking.

#### L1.8 contact discretization and the bounded easy-work pass — 2026-07-22

This checkpoint executed the bounded easy-work list from
`docs/BR3A_EASY_WORK_HANDOFF.md`: the separate L1.8 contact-discretization
pack, development-only knowledge drafts for L1.1-L1.8, a containment guard
test, and a read-only status CLI. None of it touches the pinned
`BR3A_L1_commissioning_status_v1.json`, the BR1 report-v2 inventory, any
schema/attestation/receipt/decision artifact, or the five promotion blockers.
The pinned commissioning grid remains exactly L1.0-L1.7 with 236 assertions;
everything below is additional experimental work outside that accounting.

##### L1.8 fixture and honest evidence classes

`discretized_pad_rig.gd`, registered as `discretized_pad_v1`, reuses the L1.4
pad exactly (one free rigid 2 kg body, `0.30 x 0.08 x 0.20 m`, friction 1.0,
flat static floor, gravity only) and tiles its collision footprint into
exactly `1/4/16/64/100` equal-area box elements on the same single body. The
grid mapping is `1x1`, `2x2`, `4x4`, `8x8`, `10x10`. Elements are collision
geometry only. The fixture rejects `body_parameters`, unknown fixture
parameters (including a proposed `per_element_actuation`), and any element
count outside the preregistered five. Its constraint contract pins
`single_rigid_pad`, `elements_are_collision_geometry_only`, and
`elements_are_actuators: false`.

The a-priori contact declaration is four raw points per element plus a safety
margin of eight. Under the frozen `full_contacts_v2` policy ceiling of 256
raw points per body, that declaration exceeds policy at 64 elements
(`4*64+8 = 264`) and 100 elements (`4*100+8 = 408`). The capacity derivation
therefore refuses with `DERIVED_CONTACT_CAP_EXCEEDS_POLICY`, and the test
asserts the refusal instead of letting the buffer silently truncate evidence.
The same 64/100 geometries then run under the contacts-disabled
`full_state_v1` profile as reconstruction-only cells: whole-system momentum
balance is the only load channel, and the runner asserts the raw-contact
channel stayed empty. The three evidence classes (`measured_contact`,
`policy_refused`, `reconstruction_only`) are explicit in every summary and in
`contact_discretization_analyzer.gd`, which fails closed on a forged class,
an unmeasured count, unknown config fields, or a coherently rehashed
actuator-permission field.

##### The central L1.8 finding: multi-manifold raw sums are not a load

The measured 60 Hz results, with settle 90 ticks and a 60-tick analysis
window per fresh `SubViewport` world:

| Elements | Class | Cap | Peak points | Raw predicted sum | Reconstructed load | Raw/recon ratio |
| ---: | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | measured_contact | 12 | 4 | 19.6490 N | 19.6000 N | 1.0025 |
| 4 | measured_contact | 24 | 16 | 78.3803 N | 19.6000 N | 3.9990 |
| 16 | measured_contact | 72 | 64 | 219.7367 N | 19.6000 N | 11.2111 |
| 64 | policy_refused + reconstruction_only | n/a | n/a | unavailable | 19.6000 N | n/a |
| 100 | policy_refused + reconstruction_only | n/a | n/a | unavailable | 19.6000 N | n/a |

The expected static support is \(mg = 19.6\ \text{N}\). The one-manifold
control balances it within `0.049 N`, exactly as L1.4 calibrated. But the
4-element pad's summed raw predicted load reports approximately **4.0x mg**
and the 16-element pad approximately **11.2x mg**, while whole-system
momentum reconstruction stays at `19.6 N` for every count and the pad stays
planted, untilted, slip-free, and chatter-free (load-chatter fraction and
element-presence churn both `0.0`). Per element, each shape-pair manifold's
own sum stays at or below about `1.0x` the whole-pad weight; the manifold
count is what inflates the total.

The physically transmitted support cannot exceed \(mg\), so this pins an
instrumentation truth extending L1.6 and L1.7: Godot/Jolt predicted contact
impulses reported across **multiple same-body shape-pair manifolds do not
form an additive partition of the external support load**. Summing them
overcounts roughly with manifold count. A future multi-shape foot, toe pad,
or heel/toe split therefore may not compute "load on this foot" by summing
raw predicted impulses; whole-system momentum reconstruction remains the only
trusted total, and per-manifold sums are diagnostics. The analyzer pins
`raw_impulse_summation_interpretation =
same_body_multi_manifold_raw_sum_is_not_external_support_load`, gates the
measured overcount ratios inside preregistered exact-cell brackets
(`0.95-1.05`, `3.5-4.5`, `9.0-13.0`), forbids interpolation, and lists
`additive_per_element_load_partition_from_raw_impulse` under
`does_not_establish` alongside actuators, toes, standing, and walking.
Impulse-weighted CoP remained centered within `3.5 mm` at every measured
count, so the CoP channel is not invalidated by the summation overcount.
Wall-clock tick cost is recorded per cell as a diagnostic and deliberately
not gated. `test_experimental_l1_8_contact_discretization.gd` passed 28/28
assertions with zero engine errors.

##### Development-only knowledge drafts and their containment guard

`data/lab/knowledge/drafts/br3a/` now holds eight
`sporespore.lab.br3a_development_observation.v1` drafts, one per cell
L1.1-L1.8, validated by the strict
`data/lab/schemas/br3a_development_observation_v1.schema.json`
(`additionalProperties: false` everywhere). Each draft records the claim,
exact measured scope, mechanism, applicability, failure boundaries,
parameter effects, advisory-only repair rules, unknowns, and non-claims of
one finding, and each pins `admissible_now: false`, all five snapshot-era
promotion blockers, `promotion_grade_bundle_exists: false`, and a `does_not_establish`
list containing standing, bracing, fall arrest, getting up, and walking.

`test_experimental_br3a_knowledge_draft_guard.gd` (15/15 assertions) proves
the containment: forged admissibility/ceiling/blocker/rule/bundle fields fail
the schema; `LabKnowledgeBase.verify_entry` rejects every draft as a
non-entry; `LabKnowledgeQuery.load_entries` over the draft directory fails
closed with zero entries; `repair_candidates` yields nothing from drafts;
`propose_from_bundle` without a valid promotion-grade bundle stays refused;
the admitted-entries directory contains zero BR3A L1 entries; and the pinned
commissioning snapshot still records its original five blockers. The current
registry derives zero open promotion blockers from the accepted decision while
still reporting zero admitted entries and no guidance authorization. Any later
admission must re-author selected findings as `knowledge_entry.v1` records
against promotion-grade bundles; relabeling the drafts is forbidden.

##### Read-only status CLI

`scripts/lab/br3a_status_cli.gd` renders the pinned commissioning snapshot and
the current decision-derived state for a human (or as one canonical JSON object
with `--json`) strictly through
`LabBr3aCommissioningRegistry.inspect_current()`. It prints implemented cells,
assertion counts, source-pin verification, the report-v2 guard, historical and
current blockers, accepted decision identity, knowledge and locomotion zeros,
and the claim boundary.
It writes nothing, refuses unknown arguments with exit 4, and exits 3 if the
registry refuses the pinned bytes:

```powershell
$godot = "<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe"
& $godot --headless --path . --script "res://scripts/lab/br3a_status_cli.gd"
& $godot --headless --path . --script "res://scripts/lab/br3a_status_cli.gd" -- --json
```

##### Experimental-domain accounting after this checkpoint

The experimental domain now contains eleven programs: the eight pinned
L1.1-L1.7 sources (153 assertions), the pinned readiness status test (13),
plus the new separate L1.8 pack (28) and the draft guard (15), for 209
experimental assertions total. The registry and status file intentionally
still pin only the original eight sources and 153+13 assertions; L1.8 and the
guard are separate nonblocking work by design and enter no pinned inventory.
Nothing in this checkpoint closes any of the five promotion blockers, admits
knowledge, authorizes creature guidance, or claims a foot, limb, brace,
stand, recovery, gait, or walk.

#### Promotion checkpoint — 2026-07-23

The later hard-stream campaign closes the four machine-verifiable promotion
gaps without manufacturing the fifth, human decision. Certified source
`109cc664c3282077cd806e61e1ba756e6578e639` produced campaign
`br3a_20260723T050201Z_109cc664` with:

- 19/19 declared programs and 38/38 fresh target-process capsules;
- 584/584 assertions: 472 milestone, 86 supplementary, and 26 integrity;
- 38/38 generic production bundle receipts and complete final readback;
- a 185-file exact source closure, clean at campaign start and end;
- the frozen BR1 inventory unchanged;
- report SHA-256
  `8574122ad227084657bb8edd947b4e7c7d001af553f63cf645cb595afbd5fc6b`;
  and
- detached BR3A report-receipt SHA-256
  `a355f549907eb87742a8310eb56e58c88aaf1ebd98ee68f22c05b459c3f8dd8c`.

An independent post-campaign verification returned `ok=true`,
`trust_mode=production`, and `can_promote=true`. The last field means the
report is eligible to support a separate decision; it is not acceptance.

At the moment this campaign checkpoint was written, blocker state was 4/5
closed and `EXPLICIT_BR3A_MILESTONE_DECISION_MISSING` remained open. Cole later
closed that final blocker through the bounded acceptance recorded below. The
exact evidence, controlling claim boundary, options, and supplied decision
language remain in `docs/BR3A_L1_MILESTONE_DECISION_REVIEW.md`.

The older `BR3A_L1_commissioning_status_v1.json` and its read-only CLI remain
an immutable pre-certification snapshot, so their five-open-blocker rendering
is historical. No pinned lab source or status artifact is rewritten while the
certified closure awaited Cole's review.

#### BR3A milestone-acceptance checkpoint — 2026-07-23

Cole explicitly accepted `BR3A_L1_ENGINE_CONTACT_TRUTH` using certification
`br3a_20260723T050201Z_109cc664`, report SHA-256
`8574122ad227084657bb8edd947b4e7c7d001af553f63cf645cb595afbd5fc6b`,
and detached receipt SHA-256
`a355f549907eb87742a8310eb56e58c88aaf1ebd98ee68f22c05b459c3f8dd8c`.
Append-only decision `BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1` binds that
authority to the exact L1.0-L1.7 program scopes and the report's verbatim claim
boundary. A separate BR3A schema and semantic contract preserve the existing
BR2.1 decision schema and bytes unchanged.

The state immediately after the milestone decision, before the separate
knowledge operation, was:

- BR3A promotion blockers open: **0/5**;
- formal ladder accepted: **4/18 (22.2%)**;
- accepted BR3A encyclopedia entries: **0**;
- automatic creature guidance from BR3A findings: **forbidden**;
- per-foot or per-toe allocation of reconstructed load: **not established**;
- articulated load-bearing limb: **not established**; and
- standing, bracing, fall arrest, getting up, gait, and walking:
  **0% proven**.

L1.8 and the knowledge guard remain supplementary constraints, not newly
accepted milestone cells. The old commissioning JSON remains byte-pinned as
the five-blocker historical snapshot; current state is derived from the
append-only decision registry. Knowledge admission, automatic guidance, and
BR4/L2 actuator/force-transmission truth were separate downstream gates.

Post-decision verification passed 13/13 experimental programs and 260/260
assertions, then the unchanged released pattern passed 62/62 programs and
1,118/1,118 assertions. There were no failures, timeouts, or unexpected engine
errors. The reports are:

- `<evidence-root>\temp-roots-2026-07-28\sporespore_br3a_experimental_acceptance\20260723T005910563\report.json`;
  and
- `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br3a_acceptance\20260723T010329167\report.json`.

#### BR3A knowledge-admission checkpoint — 2026-07-23

Cole's standing instruction authorized the pipeline to accept only the
evidence-backed knowledge recommended by the maintained trust boundary. ADR-004
rejects three tempting but false adapters: treating BR3A capsules as BR1
`summary.json` bundles, modifying already certified capsules, or widening the
existing `knowledge_entry.v1` contract. Instead,
`sporespore.lab.br3a_knowledge_entry.v1` binds each entry to:

- append-only decision
  `BR3A_L1_ENGINE_CONTACT_TRUTH_DECISION_V1`;
- exact report SHA-256
  `8574122ad227084657bb8edd947b4e7c7d001af553f63cf645cb595afbd5fc6b`;
- exact detached report-receipt SHA-256
  `a355f549907eb87742a8310eb56e58c88aaf1ebd98ee68f22c05b459c3f8dd8c`;
- the report's verbatim certification claim boundary;
- exact cited program IDs and claim scopes; and
- both production-HMAC-attested, checksummed capsules for every cited program.

The fixed admission manifest authorizes exactly nine entries:

1. `L1.0.contact_observer_foundation.v1`;
2. `L1.1.contact_slip_and_friction_breakaway.v1`;
3. `L1.2.incline_hold_slide_threshold.v1`;
4. `L1.3.support_edge_tipping.v1`;
5. `L1.4.static_pad_center_of_pressure.v1`;
6. `L1.5.timestep_envelope.v1`;
7. `L1.6.solver_sensitivity_and_external_impulse_reconstruction.v1`;
8. `L1.7.directed_mass_ratio_stability.v1`; and
9. `L1.8.contact_discretization_raw_sum_overcount.v1`.

The first eight are accepted milestone observations. L1.8 is an accepted
supplementary instrumentation constraint, not a promoted milestone cell. The
knowledge-draft guard and commissioning-registry integrity programs are not
knowledge entries.

Every admitted entry has an empty `minimal_repair_rules` array and a strict
`observation_only` guidance policy with both
`automatic_creature_guidance_allowed=false` and
`automatic_application_allowed=false`. Unlocking either requires an accepted
support milestone and a separate guidance decision. Consequently:

- accepted BR3A entries: **9**;
- accepted BR3A milestone observations: **8**;
- accepted BR3A supplementary constraints: **1**;
- total accepted knowledge entries including the earlier L0 baseline: **10**;
- automatic creature guidance: **forbidden**;
- per-foot or per-toe load allocation: **not established**;
- an articulated load-bearing joint, limb, or creature: **not established**;
- standing, bracing, fall arrest, getting up, gait, and walking:
  **0% proven**; and
- formal milestone ladder: unchanged at **4/18 (22.2%)**.

The machinery was committed cleanly before any append-only entry was written.
The focused pre-admission compatibility suite passed 3/3 programs and 64/64
assertions. The complete pre-admission experimental pattern then passed 14/14
programs and 280/280 assertions with no failures, timeouts, or unexpected
engine errors:

- `<evidence-root>\temp-roots-2026-07-28\sporespore_br3a_knowledge_machinery\20260723T013915331\report.json`;
  and
- `<evidence-root>\temp-roots-2026-07-28\sporespore_br3a_knowledge_machinery_full\20260723T014040670\report.json`.

After the append-only write, the five BR3A status/admission/containment/
promotion checks passed 5/5 programs and 101/101 assertions. The unchanged
released pattern then passed 62/62 programs and 1,118/1,118 assertions. Both
runs had zero failures, timeouts, or unexpected engine errors:

- `<evidence-root>\temp-roots-2026-07-28\sporespore_br3a_knowledge_postadmission\20260723T015107438\report.json`;
  and
- `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br3a_knowledge\20260723T015142894\report.json`.

BR4/L2 joint and actuator truth is now the next experimental stream. Knowledge
admission does not skip, satisfy, or partially accept BR4.

Build:

- opt-in contact monitoring for lab bodies;
- derived contact cap;
- `_integrate_forces` adapter;
- stable contact identity/lifetime;
- SEARCH/TOUCH/LOAD/BEARING/UNLOAD/LOST state;
- ground qualification by layer/tag/normal, not geometry alone.
- canonical external-contact ownership and same-creature self-contact exclusion;
- support-plane geometry for point, segment/capsule, and polygon cases.

Fixtures:

- `L1.0` box drop;
- `L1.1` friction sled;
- `L1.2` incline block;
- `L1.3` tipping prism;
- `L1.4` foot-sized flat pad;
- `L1.5` timestep sweep;
- `L1.6` solver-step sweep;
- `L1.7` mass-ratio grid;
- separate `L1.8` 1/4/16/64/100 contact-discretization pack before any microtoe claim.

After the minimal box-drop normal/sign oracle, `L1.1` friction sled is the first
locomotion-adjacent experiment. Promotion still requires the complete `L1.0-L1.7` pack.

Tests:

```text
test_lab_contact_position_frame.gd
test_lab_contact_normal_sign.gd
test_lab_contact_lifetime.gd
test_lab_contact_buffer_saturation.gd
test_lab_external_contact_dedup.gd
test_lab_self_contact_not_support.gd
test_lab_support_point_segment_polygon.gd
test_lab_contact_support_state.gd

# Experimental implementations now exist outside the signed inventory:
test_experimental_l1_1_contact_slip.gd
test_experimental_l1_1_friction_breakaway.gd
test_experimental_l1_2_incline_threshold.gd
test_experimental_l1_3_tipping_edge.gd
test_experimental_l1_4_pad_center_of_pressure.gd
test_experimental_l1_5_timestep_convergence.gd
test_experimental_l1_6_solver_step_sensitivity.gd
test_experimental_l1_7_mass_ratio_grid.gd

# Planned promotion names/open; these files do not exist yet:
test_lab_contact_slip.gd
test_lab_friction_breakaway.gd
test_lab_tipping_edge.gd
test_lab_pad_center_of_pressure.gd
test_lab_solver_step_sensitivity.gd
test_lab_mass_ratio_grid.gd
```

Gate:

- begin/end events align with visible/analytic contact;
- a near-ground airborne body is not supported;
- impulse/status limitations are explicit;
- cap saturation invalidates evidence.
- all `L1.0-L1.7` engine-truth cells have accepted positive/negative evidence;

Depends on: BR1, BR2.

Unlocks: accepted BR4/L2 work. `L1.8` separately unlocks distributed-foot experiments after BR3B.

### BR4 — L2 joint and actuator truth pack

**Question:** Can a joint exert declared force through equal/opposite torques?

Build:

- `actuator_spec.gd`;
- activation dynamics;
- torque-speed-power envelope;
- extend BR1's generic sealed command-envelope/executor/receipt seam with
  `JointTorqueCommand`, `JointActuator`, and equal/opposite parent/child torque operations;
- no direct torque outside executor.

Trials:

```text
L2.0 passive pendulum
L2.1 gravity-off free-hinge torque pulse
L2.2 unloaded PD step
L2.3 loaded horizontal link/static gravity hold
L2.4 torque-cap and power-cap ramp
L2.5 hard-limit approach and reaction classification
L2.6 two-link fixed-base and free-floating parent/child variants
L2.7 deliberate anchor-error perturbation
positive/negative symmetry and orientation sweep
```

The primary analytic fixture is a coaxial free-floating two-rotor system. With equal-and-opposite
joint torques \(\pm\tau a\):

\[
\alpha_\text{relative}
=
\tau
\left(
a^\mathsf{T}(I_c^W)^{-1}a
+
a^\mathsf{T}(I_p^W)^{-1}a
\right)
\]

\[
\Delta L_\text{parent+child}\approx0
\]

The first fixed-parent variant places the child CoM on the hinge axis, so the rotational inertia
oracle is unambiguous. A later off-axis child uses inertia about the pivot and explicitly accounts
for mount reaction impulse; a fixed parent is a scaffold, not momentum conservation.

For every dyno:

```text
HingeJoint3D built-in motor disabled
ordinary dynos disable hard limits or place them safely beyond the complete motion envelope
only the dedicated L2.5 hard-stop fixture intentionally approaches a hard limit
limit enabled/bounds/bias/softness/relaxation recorded
gravity, linear/angular damping, sleeping, axis locks, freeze, and CCD recorded
zero-damping/gravity-off primary pulse
finite engine direct-state inertia required
```

Tests:

```text
test_lab_actuator_zero_command.gd
test_lab_actuator_paired_torque.gd
test_lab_actuator_capacity.gd
test_lab_actuator_power_limit.gd
test_lab_actuator_reversal_bounds.gd
test_lab_actuator_spec_domain_rejection.gd
test_lab_actuator_momentum_conservation.gd
```

Gate:

- measured angular acceleration agrees with applied torque/inertia within tolerance;
- parent/child torque is paired exactly once;
- saturation is visible and correctly attributed;
- no root reaction cheat exists.
- hard-limit solver reaction is never attributed to motor/passive-tissue strength;
- any hard-limit strike invalidates an ordinary motor/energy claim;
- `L2.5` independently distinguishes declared engine hard-stop reaction from active, passive,
  authored soft-limit, and structural-guard channels;
- deliberate anchor error produces the predicted observer/constraint failure.

Depends on: BR1, BR2, BR3A for promotion. Contact-free fixture code/exploration may run in parallel
after BR2, but it cannot promote, unlock BR5, or support a downstream claim until L1 is accepted.

Unlocks: BR3B and BR5.

### BR3B — L3 basic loaded-foot truth

**Question:** Does a simple foot transmit declared normal/shear loads and expose rocking before a
leg depends on it?

Fixtures:

```text
L3.0 loaded flat pad under a force-controlled carriage boundary
L3.1 loaded pad plus shear ramp
L3.2 rocking rectangular pad
```

Tests:

```text
test_experimental_l3_0_loaded_pad_normal.gd
test_experimental_l3_1_loaded_pad_shear.gd
test_experimental_l3_2_loaded_pad_rocking.gd
```

The carriage is a boundary condition, not a physical guide: the runner applies
one declared force once per physics tick to an otherwise free rigid pad. No
translation rail, pin, rotation lock, damping, motor, or balancing reaction is
present. An off-center load therefore introduces only the declared
`offset × force` moment.

Gate:

- measured normal load/momentum balance matches the imposed load within calibrated tolerance;
- tangential breakaway matches the accepted L1 friction envelope;
- center of pressure moves toward the predicted edge before rocking;
- no pin/fixed foot constraint can pull or supply hidden moment;
- loaded-pad normal/shear/rocking predictions pass before a leg relies on the floor.

Depends on: BR3A and BR4.

Unlocks: contact-bearing BR6A. `L1.8` plus BR3B separately unlocks high-contact/distributed feet.

### BR5 — Passive tissue dyno

**Question:** Do springs/tendons behave as declared without hiding active failure?

Build:

- `passive_tissues.gd`;
- current-state evaluation;
- signed passive work;
- active/passive/structural separation;
- optional unilateral tissue implementation after conservative oracle.

Tests:

```text
test_lab_spring_rest_angle.gd
test_lab_spring_damping_sign.gd
test_lab_spring_cycle_energy.gd
test_lab_tendon_slack_and_stretch.gd
test_lab_total_structural_clamp.gd
```

Gate:

- zero deformation yields expected zero elastic torque;
- damping never accelerates motion in its own generalized coordinate;
- passive closed cycle creates no net energy beyond tolerance;
- passive torque cannot increase active capacity.

Depends on: BR2, BR4.

Unlocks: optional passive variants of later gates.

### BR6A — Vertical rail-leg support

**Question:** Can one limb carry weight, crouch, rise, and absorb a vertical disturbance?

Build:

- `body_wrench.gd`;
- V1 vertical allocator;
- force-to-joint map;
- `rail_leg_rig.gd`;
- height PD;
- load ramp and anti-windup.
- `L4.0` rigid-strut rail oracle;
- `L4.1` hinged-strut static load curve;
- `L4.3` two-link leg on vertical carriage with ordinary contact.

Tests:

```text
test_lab_rail_freefall_honesty.gd
test_lab_one_link_static_hold.gd
test_lab_two_link_static_hold.gd
test_lab_crouch_and_rise.gd
test_lab_vertical_impulse_recovery.gd
test_lab_unreachable_height.gd
```

Gate:

- freefall matches gravity when motors are zero;
- support force/impulse balances weight in hold;
- commanded rise increases CoM potential energy through legal work;
- downward impulse is rejected without root intervention;
- insufficient actuator produces declared infeasibility.
- no pinned foot, built-in joint motor, controller-applied root rescue, or unexplained rail reaction
  participates;
- the primary gate runs with passive spring/tendon capacity disabled.

Depends on: BR3B basic loaded-foot pack and BR4 actuator dyno. BR5 is optional and off for the
primary active-support gate.

Unlocks: BR7.

### BR6B — Separate pogo energy gate

**Question:** Can stored passive energy and timed active work produce a bounded vertical hop without
being confused with static support?

Build only after BR6A and BR5:

```text
L5.0 passive spring on vertical rail
L5.1 driven pogo on vertical rail
L5.2 contact-triggered drive
```

The first pogo reuses the certified two-link **rotational** rail leg, so its generalized coordinates
remain radians, torque remains N·m, and power is \(\tau\dot q\). A telescoping pogo is a different
prismatic actuator contract:

```text
q in metres
generalized effort in newtons
power = F * qdot
Jacobian column = translation axis
```

Do not put prismatic force values into the rotational N·m fields.

Gate:

- passive-only energy decays by the declared damping/loss model;
- active signed work replaces measured losses without runaway;
- contact-triggered actuation uses true contact phase, not foot height;
- liftoff, flight, touchdown, compression, and rebound events have unique observed guards;
- the rail reaction remains accounted;
- zero-active and zero-spring controls fail in the predicted channels.

BR6B is useful knowledge and later unlocks free-pogo experiments, but it is not a prerequisite for
ordinary planar stance. Calling BR6A “pogo” would conflate weight support with an oscillatory energy
cycle.

### BR7 — Planar multi-contact stance

**Question:** Can two or more supports regulate height and pitch?

Build:

- V2 planar allocator;
- support segment/polygon math;
- static and capture margins;
- planar stance platform;
- contact load redistribution.

Tests:

```text
test_lab_vertical_load_split.gd
test_lab_pitch_moment_allocation.gd
test_lab_friction_cone_rejection.gd
test_lab_support_polygon_margin.gd
test_lab_support_loss.gd
```

Gate:

- allocator arithmetic residual is within numerical tolerance;
- predicted feasibility residual is zero for every required-feasible trial;
- momentum-derived realized physical wrench residual is within its calibrated tolerance;
- measured height and pitch response have the predicted sign and bounded error;
- allocator rejects pulling and friction violations;
- CoM/capture margin predicts direction of tip;
- loss of one support produces an event and supervisor response.

Depends on: BR6A.

Unlocks: BR8.

### BR8 — Brace detection without stepping

**Question:** Can the system recognize loss of viability early enough?

Build:

- `brace_detector.gd`;
- decomposed urgency;
- time-to-boundary/impact estimates;
- supervisor STAND/PRECARIOUS/BRACE;
- hysteresis and reasoned transitions.

Fixtures:

- slowly tilting platform;
- repeatable horizontal root impulse;
- disappearing support.

Tests:

```text
test_lab_brace_detector_static_margin.gd
test_lab_brace_detector_capture_margin.gd
test_lab_brace_hysteresis.gd
test_lab_brace_transition_reason.gd
```

Gate:

- detector fires before terminal fall;
- safe disturbances do not chatter into brace;
- every transition contains decomposed evidence;
- delayed negative control is classified `REACTION_TOO_LATE`.

Depends on: BR7.

Unlocks: BR9.

### BR9 — Existing-contact brace

**Question:** Can the body stop a tip by redistributing force through contacts it already has?

Build:

- `brace_controller.gd`;
- desired arrest wrench;
- load-rate limits;
- reserve-aware contact redistribution;
- STABILIZE handoff.

Tests:

```text
test_lab_existing_contact_brace.gd
test_lab_brace_actuator_infeasible.gd
test_lab_brace_friction_infeasible.gd
test_lab_brace_no_root_intervention.gd
```

Gate:

- legal contact wrench reduces tip momentum;
- desired/achieved residual is reported;
- negative controls fail specifically;
- stance resumes only after stable dwell.

Depends on: BR8.

Unlocks: BR10.

### BR10 — Reachable catch step

**Question:** Can an unloaded limb create a new bearing contact before impact?

Before the falling-body catch trial, certify the limb in simpler `L4` fixtures:

```text
L4.2 two-link free-space target tracking
L4.5 suspended swing with measured clearance and no scuff
L4.6 bounded touchdown
TOUCH -> LOAD -> BEARING transition under a known landing
per-joint reach-time prediction versus measured first contact
```

Build:

- candidate contact scoring;
- actuator-limited reach-time estimate;
- catch target generation;
- contact SEARCH/TOUCH/LOAD/BEARING coordination;
- planar catch rig.

Tests:

```text
test_lab_catch_reach_deadline.gd
test_lab_catch_contact_load.gd
test_lab_catch_step_success.gd
test_lab_catch_step_unreachable.gd
test_lab_swing_clearance.gd
test_lab_touchdown_impact_bound.gd
test_lab_contact_phase_order.gd
test_lab_reach_prediction_error.gd
```

Gate:

- free-space swing reaches the target under the same actuator speed/power envelope;
- minimum clearance is positive and measured;
- touchdown impulse/load rate stays below preregistered bounds;
- `TOUCH -> LOAD -> BEARING` occurs from observed contact/load, never target arrival;
- measured reach/contact time lies inside the conservative predicted deadline envelope;
- catch begins before predicted deadline;
- foot reaches without pose teleport;
- new contact becomes bearing;
- support polygon improves;
- body returns to stance or produces an honest infeasible/fallen result.

Depends on: BR9.

Unlocks: BR11.

### BR11 — Controlled fall arrest

**Question:** When upright recovery is impossible, can the body reduce impact and momentum honestly?

Build:

- `fall_arrest_controller.gd`;
- protective contact roles;
- impulse/momentum metrics;
- impact severity proxy;
- supervisor FALL_ARREST/FALLEN.

Tests:

```text
test_lab_fall_arrest_impulse.gd
test_lab_fall_arrest_angular_momentum.gd
test_lab_fall_arrest_missing_angular_momentum.gd
test_lab_protective_contact_role.gd
test_lab_fall_arrest_insufficient_capacity.gd
```

Gate:

- intervention reduces declared severity metric versus zero-control baseline;
- no claim of upright recovery is made;
- impulse and energy remain accounted;
- pose classifier receives a stable fallen state.

Depends on: BR10.

Unlocks: BR12.

### BR12 — Pose classifier and recovery feasibility

**Question:** Can the system identify how it fell and whether a recovery plan can work?

Build:

- labeled-box pose oracle;
- body-region contact roles;
- `pose_classifier.gd`;
- `recovery_profile.gd`;
- recovery feasibility report.

Tests:

```text
test_lab_pose_upright.gd
test_lab_pose_prone_supine_side.gd
test_lab_recovery_profile_role_match.gd
test_lab_recovery_static_feasibility.gd
```

Gate:

- canonical poses classify deterministically;
- ambiguous poses remain ambiguous;
- missing anatomy gives a named infeasible result;
- obviously underpowered phases are rejected before actuation.

Depends on: BR3A, BR4, BR11.

Unlocks: BR13.

### BR13 — One constrained canonical get-up

**Question:** Can one morphology recover from one declared fallen pose while the remaining
uncontrolled spatial degrees of freedom are explicitly scaffolded?

Build:

- one recovery profile only;
- phase guards and timeouts;
- legal non-foot intermediate contacts;
- energy/reserve gates;
- stance handoff.

Choose the easiest feasible pair:

```text
symmetry-constrained quadruped + prone
sagittal recovery plane
lateral/roll guide declared as scaffold
ordinary unilateral ground contacts
```

Do not start with "any body from any pose."

Tests:

```text
test_lab_recovery_prone_phase_order.gd
test_lab_recovery_phase_timeout.gd
test_lab_recovery_energy_gate.gd
test_lab_recovery_handoff_to_stance.gd
```

Gate:

- repeated success across declared seed set;
- every phase success comes from observed state;
- CoM potential gain is explained;
- final stance dwell passes with recovery controller inactive.
- lateral/roll guide impulse and work are recorded or residual-inferred;
- conclusion is exactly `constrained_planar_get_up`, not free 3D recovery.

Depends on: BR12.

Unlocks: BR14A.

### BR14A — One canonical spatial morphology

**Question:** Does the proven planar pipeline survive removal of the recovery/balance scaffolds for
one morphology that has sufficient 3D controllability?

Build:

- V3 spatial allocator;
- full support polygon;
- roll/pitch/yaw requests as morphology permits;
- centroidal angular-momentum objective using measured \(L_C\), never root-only rotation;
- one canonical morphology control/rank report;
- one spatial stance, existing-contact brace, catch/fall-arrest, and feasible get-up cell.

Gate:

- every requested wrench axis is feasible or intentionally omitted by the task;
- scaffolds are annealed to zero and remain untouched;
- the canonical morphology passes its preregistered required-feasible cells;
- expected-infeasible controls fail at the predicted constraint;
- observer/energy/scaffold gates remain valid.

Depends on: BR13 plus spatial rank/controllability and 3D coordinate-frame gates.

Unlocks: BR14B and robust free-creature integration for this morphology.

### BR14B — Spatial morphology and strange-rig expansion

**Question:** Which parts of the proven spatial pipeline generalize, and where does morphology make
the task physically impossible?

Add the umbrella/feelers, distributed-foot, cup-foot, biped, quadruped, and stranger-body cells only
after BR14A has one canonical reference.

Matrix:

```text
morphology:
  pogo/cup foot
  biped
  quadruped
  one strange distributed-foot body

task:
  stand
  existing-contact brace
  catch contact
  fall arrest
  one get-up pose where anatomically feasible

surface:
  nominal friction
  low friction
  small slope

seed:
  fixed promotion seed set
```

Before running, classify every matrix cell:

```text
required_feasible
  morphology report predicts adequate DOFs/contact/torque/power;
  promotion requires success

expected_infeasible
  a named violated constraint is preregistered;
  promotion requires the matching honest failure, not accidental success

exploratory
  useful trace, no pass/fail contribution, cannot rescue a required cell
```

Gate:

- every `required_feasible` cell succeeds;
- every `expected_infeasible` cell produces its preregistered feasibility/failure reason;
- exploratory results remain non-promotional;
- no unsupported "walking" conclusion;
- observer/energy/scaffold gates remain valid;
- knowledge entries identify what generalizes and what is morphology-specific.

Depends on: BR14A. `L1.8` is additionally required before microtoe/distributed-foot cells.

Unlocks: broad morphology claims and the robust-autonomy half of free-creature locomotion.

### 16.1 What actually unlocks walking research

Do not make all locomotion research wait for arbitrary-pose recovery, but do not lower the support
bar either.

The minimum prerequisites for `L7` atomic-step research are:

```text
BR1 complete L0 evidence spine
BR2 coordinate/joint truth
BR3A L1.0-L1.7 engine/contact truth
BR4 L2 joint/actuator truth
BR3B L3.0-L3.2 loaded-foot truth
BR6A rail-leg support
BR7 planar multi-contact stance
BR8 early support-loss detection
BR9 existing-contact brace
L4.2 free-space leg placement
L4.5 swing clearance
L4.6 bounded touchdown and observed TOUCH -> LOAD -> BEARING
L7.0 load transfer between two feet using ordinary unilateral ground contact,
     with the pelvis explicitly fixed/scaffolded
```

That unlocks only constrained `L7.1-L7.6` stepping experiments. It does not prove a free walker.
BR10-BR14 are the robust-autonomy track for contact creation under threat, protective falling, and
getting up. A first `candidate_walking` attempt still follows the complete walking evidence contract
and scaffold annealing in the research program.

---

## 17. Atomic gates and test policy

### 17.1 A gate is more than a green exit code

Every promotion gate declares:

```text
fixture and fixture version
code revision or dirty diff hash
physics engine and solver settings
seed set
parameter set
allowed scaffolds
forbidden interventions
warm-up and measured intervals
metrics and units
thresholds fixed before the promotion run
negative controls
artifact paths
validity decision
```

A test that checks only `not NaN` or `moved more than zero` is a smoke test, not evidence of support,
bracing, recovery, or locomotion.

### 17.2 Threshold policy

Thresholds fall into three groups:

1. **analytic:** derived from a closed-form oracle, such as gravity, mass, or equal/opposite torque;
2. **numerical:** tolerance around an analytic value, calibrated by timestep/solver sweeps;
3. **behavioral:** a task requirement fixed before the promotion seed set.

Do not choose a behavioral threshold after seeing the candidate result. Exploration may discover a
reasonable threshold, but promotion uses a fresh fixed run set and records that separation.

### 17.3 Infrastructure gates G0-G14

These cross-cut the BR ladder:

| Gate | Assertion |
|---|---|
| `G0_SCHEMA` | every record validates against a versioned schema |
| `G1_TICK_ORDER` | frame/command/application ordering is unambiguous |
| `G2_FINITE` | first nonfinite value aborts and names field/source |
| `G3_COORDINATES` | every vector/point frame passes its oracle |
| `G4_COMMAND_OWNERSHIP` | controller active torque, passive tissue, authored soft-limit torque, and structural-guard torque are sealed and only the actuator executor applies them |
| `G5_INTERVENTION` | every environment/body force, torque, impulse, velocity/pose write, or dynamic-surface operation is pre-sealed and paired to exactly one application receipt; every declared constraint reaction is separately observed with quality/availability |
| `G6_CONTACT_CAP` | no accepted run saturates its contact buffer |
| `G7_ENERGY` | energy residual stays inside fixture-calibrated tolerance |
| `G8_TRACE_PLAYBACK` | recorded evidence replays with physics disabled and reproduces transforms, event order, and derived metrics |
| `G9_RERUN_REPRODUCIBILITY` | a fresh-process rerun of the same expanded spec/seed reproduces structural outcomes and metrics within tolerance |
| `G10_OBSERVER_PARITY` | minimal versus full observer profiles stay within the calibrated perturbation envelope |
| `G11_NEGATIVE_CONTROL` | a deliberately broken causal capability fails for the expected reason |
| `G12_ARTIFACT_COMPLETE` | manifest, process metadata, frames, commands, applications, decisions, interventions, mechanics, events, runtime notes, any retained pre-event snapshot, summary, and checksums are complete and cross-linked |
| `G13_SEALED_VALUES` | post-seal mutation attempts cannot change serialized bytes, hashes, or executor inputs |
| `G14_SOURCE_STATE` | promotion uses a clean committed worktree, and the final manifest seals that exact revision and required source/resource content hashes |

No BR milestone promotes if one of its applicable infrastructure gates fails.
`G8_TRACE_PLAYBACK` is mandatory in BR1/L0.4; it is not deferred until after controllers exist.
`G9_RERUN_REPRODUCIBILITY` is a second contract that reruns physics and must never be called trace
playback.

Godot/Jolt hard-limit reactions are engine constraint impulses, not actuator-executor torque. They
are declared and observed as constraint-reaction channels with exposed or residual-inferred
quality. Except in the dedicated `L2.5` hard-stop experiment, a hard-limit strike invalidates the
actuator/energy claim rather than being counted as motor, spring, or structural-guard strength.

### 17.4 Unit tests versus physics experiments

Use unit tests for:

```text
pure support geometry
orientation math
Jacobian algebra
actuator envelope/clamp
state-machine transition logic
schema validation
feasibility inequalities
failure-code stability
```

Use physics experiments for:

```text
engine contact behavior
constraint and solver response
torque/inertia response
friction and load transfer
actual catch timing
energy residuals
stand/brace/recovery behavior
```

Do not mock the physics engine and call the result proof that a physical fixture works. Pure mocks
can prove controller arithmetic; Jolt experiments prove integration.

### 17.5 Test naming and runner discovery

The current PowerShell runner uses:

```powershell
$tests = Get-ChildItem -Path (Join-Path $repo "tests") `
  -Filter "test_*.gd" |
  Sort-Object Name
```

That is non-recursive. Pick one policy and pin it:

**Option A — flat lab tests now**

```text
tests/test_lab_trace_round_trip.gd
tests/test_lab_joint_actuator.gd
tests/test_lab_contact_frame.gd
```

Pros:

- no runner change;
- lowest initial risk.

Cons:

- test directory becomes crowded;
- lab grouping is lexical rather than structural.

**Option B — recursive runner**

```powershell
$tests = Get-ChildItem `
  -Path (Join-Path $repo "tests") `
  -Filter "test_*.gd" `
  -File `
  -Recurse |
  Sort-Object FullName

foreach ($test in $tests) {
    $relative = [System.IO.Path]::GetRelativePath($repo, $test.FullName)
    $scriptPath = "res://" + ($relative -replace "\\", "/")
    # Existing Godot invocation follows.
}
```

Pros:

- clean `tests/lab/` organization;
- scales to fixtures and schema tests.

Cons:

- changes test discovery for the entire repository;
- may discover old nested scripts that were never intended to run;
- requires a discovery-list test before adoption.

Recommendation: start with flat `test_lab_*` files through BR4. Change to recursive discovery in a
separate commit only after listing every newly discovered file and confirming intent.

### 17.6 Required negative-control pattern

Every positive physics experiment has at least one paired negative:

| Positive claim | Negative control |
|---|---|
| motor supports load | active capacity set to zero |
| spring returns energy | spring stiffness set to zero |
| friction permits brace | friction set below analytic requirement |
| contact observer sees support | monitoring disabled |
| catch is timely | reaction delay set beyond deadline |
| recovery raises body | required actuator removed/disabled |
| distributed toes increase support | toe contacts clustered away or disabled |

The negative run must fail the causal channel, not merely use a different seed and happen to fail.

### 17.7 Determinism tolerance

Bit-identical floating-point trajectories may not be realistic across machines/backends. Separate:

```text
structural determinism:
  same phase/event ordering
  same selected contacts/strategy
  same terminal reason

metric determinism:
  values within declared absolute/relative tolerance

bit determinism:
  identical bytes; useful only where actually available
```

The manifest includes hardware/backend information whenever comparing outside the local machine.

### 17.8 Flake policy

A flaky promotion test is a failure, not "mostly passing."

When a fixed-seed run varies:

1. preserve both traces;
2. find the first divergent frame/event;
3. compare commands before comparing final outcomes;
4. check observer timing, shared physics spaces, iteration order, and non-stable IDs;
5. do not widen the final outcome tolerance until first divergence is understood.

---

## 18. Migration from the current locomotion path

### 18.1 Parallel first, cut over later

The lab stack should initially coexist with `CpgController`. It will build the same `CreatureBody`
where practical but must not call the gameplay controller.

```text
current gameplay path
  CreatureBody -> CpgController -> SimRollout

new evidence path
  LabRig/CreatureBody
    -> Observers
    -> SupportSupervisor/controllers
    -> CommandLedger/ActuationExecutor
    -> TraceStore
```

Only after BR6A proves support should gameplay adopt the actuator executor. Only after BR9 proves
bracing should gameplay adopt the supervisor. This avoids replacing every variable while the
primitive mechanics remain unknown.

### 18.2 Legacy behavior is characterization, not accepted truth

Existing tests and documents that say a creature "walks" remain useful for regression and historical
comparison, but they do not establish the new locomotion claim.

Classify old locomotion tests as:

```text
legacy_characterization
integration_smoke
gameplay_regression
accepted_physics_evidence
```

Initially, none of the historical walking tests are `accepted_physics_evidence`. This implements the
explicit project truth: LoColemotion has never yet demonstrated accepted walking.

### 18.3 First extraction from `CpgController`

Current generic joint control:

- stores a world axis at bind time near
  [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L293);
- reads that stored axis during the generic tick path near
  [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L563-L589);
- applies its parent/child torque pair directly near
  [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L587-L589).

The tracked-leg path recomputes the axis from current transforms near
[`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1015-L1019) and applies another paired path
near [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1121-L1123).

Migration:

1. make `JointBinding.sample_state()` the only place that produces current pivot/axis/\(q,\dot q\);
2. route a single generic joint through `CommandLedger`;
3. compare legacy versus ledger commands without applying the ledger command;
4. switch that joint to the executor;
5. expand joint-by-joint;
6. delete direct application only after parity/intentional-difference review.

Shadow comparison record:

```json
{
  "joint_id": "example",
  "legacy_requested_nm": 42.1,
  "new_requested_nm": 40.8,
  "difference_nm": -1.3,
  "difference_reasons": [
    "CURRENT_AXIS_RECOMPUTED",
    "SINGLE_ACTIVE_CLAMP"
  ]
}
```

The goal is not necessarily zero difference. It is an explained difference.

### 18.4 Spring migration

The current spring path is called near
[`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L593), implemented near
[`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1477-L1516), and uses controller-owned
angle/velocity state plus the stored axis.

Migration:

1. reproduce its torque in a pure `PassiveTissues.evaluate_spring()` function;
2. feed current `JointState`;
3. log legacy/new torque in shadow;
4. run rest-angle, damping-sign, and cycle-energy tests;
5. make contact gating an explicit authored rule if still desired;
6. remove the old application call;
7. keep passive torque outside active capacity, inside structural capacity.

Contact-gating a spring can erase or reintroduce stored energy discontinuously. Default lab springs
remain physically active regardless of "grounded" unless the tissue model explicitly includes a
clutch and accounts for it.

### 18.5 Tendon migration

The current tendon pass is called near
[`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L610) and implemented near
[`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1600-L1631).

Migration:

- replace controller-owned stale state with current joint snapshots;
- choose and document conservative coupling or unilateral slack/extension behavior;
- expose each tendon's torque contribution per joint;
- prove power/energy sign over a closed motion;
- apply only through the passive/structural pipeline.

### 18.6 Root intervention cutover

Current root posture and lift assists exist near:

- [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1694-L1717);
- [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1719-L1734);
- additional direct root/parent and foot forces near
  [`cpg_controller.gd`](../scripts/sim/cpg_controller.gd#L1423-L1469).

Do not delete them immediately; that would change gameplay while the replacement is unproven.
Instead:

```text
lab fixtures:
  root interventions forbidden by default

legacy rollouts:
  interventions allowed only when explicitly configured
  every intervention recorded with force/torque/impulse/work

promotion:
  requires an unassisted profile

eventual gameplay:
  supervisor and contact forces replace assists
  legacy assists removed after parity and regression review
```

A debug scaffold is acceptable when its artifact is labeled scaffolded. It cannot support an
unassisted claim.

### 18.7 Contact build configuration

`CreatureBody.BuildParams` currently defaults contact monitoring off and caps reports at eight near
[`creature_body.gd`](../scripts/sim/creature_body.gd#L23-L33). It applies those settings during body
construction near [`creature_body.gd`](../scripts/sim/creature_body.gd#L149-L153).

Add an explicit lab observer profile:

```gdscript
var build_params := CreatureBody.BuildParams.new()
build_params.contact_monitor = experiment.requires_contacts
build_params.max_contacts_reported = (
    experiment.contact_cap_per_body)
```

The runner records both values in the manifest. Avoid globally turning on enormous contact buffers
for every gameplay body before profiling.

### 18.8 Static evaluator reuse

The current static stand solver lives in
[`CharacteristicsEvaluator.gd`](../scripts/core/CharacteristicsEvaluator.gd#L668-L909), including a
vertical load distribution around
[`CharacteristicsEvaluator.gd`](../scripts/core/CharacteristicsEvaluator.gd#L797).

Extract pure math into `support_math.gd`:

```text
CharacteristicsEvaluator -> support_math static feasibility
Lab support allocator     -> same support_math primitives
Tests                     -> analytic oracles for both callers
```

Do not make the runtime allocator call a high-level genome evaluator each tick. Share small pure
functions and data contracts.

### 18.9 Rollout integration

The current rollout:

- enables contact monitoring only on request;
- captures body-pair contact after a physics step;
- aborts on major fall states;
- permanently derives `fell`;
- lowers spawn/drop conditions because the existing extensor cannot recover.

Keep that behavior for legacy evaluation. Add a new explicit lab mode:

```gdscript
enum EvaluationPolicy {
    LEGACY_TERMINAL_FALL,
    LAB_OBSERVE_FALL,
    LAB_ATTEMPT_RECOVERY,
}
```

The recovery policy changes terminal conditions only in a recovery fixture. It does not make every
training rollout spend seconds trying to get up.

### 18.10 `DriveIntent` and gait remain downstream

The current `DriveIntent` contains target, weight, TTL, and source, while `GaitDef` reserves richer
pose/gait switching for later. Do not overload `DriveIntent` into the entire support-control data
model.

After BR9:

```text
gameplay/gait produces desired motion intent
support supervisor decides whether gait is currently permitted
stance/brace/recovery produces physical control intent
arbiter/executor owns actual joint application
```

This keeps "where the animal wants to go" separate from "whether it can physically keep itself up."

### 18.11 Cutover gates

| Cutover | Required proof |
|---|---|
| replace one direct torque path | BR4 dyno plus shadow comparison |
| replace all active joint torque paths | executor ownership scan and paired-torque tests |
| replace passive spring/tendon path | BR5 energy tests |
| disable root lift in lab | BR6A rail support |
| disable root posture in planar lab | BR7 stance |
| disable gameplay emergency assists | BR9/BR10 disturbance matrix |
| allow recovery instead of terminal fall | BR12 classifier and feasibility |
| claim standing | BR6A, then BR7 or BR14A for the declared unconstrained DOFs |
| begin constrained `L7` atomic-step research | minimum-support prerequisites in Section 16.1 |
| claim robust recovery for canonical morphology | BR14A |
| generalize recovery across morphologies | BR14B required-feasible matrix |

---

## 19. Parameter causality and tuning order

### 19.1 Causality matrix

| Change | Direct effect | Secondary effect | Common false conclusion |
|---|---|---|---|
| increase mass \(m\) | weight \(mg\) rises | inertia/required impulse rise | "gain too low" |
| increase limb length \(r\) | moment arm changes | inertia rises roughly with \(r^2\) | "more leverage always helps" |
| increase active torque | larger static force region | more solver/contact shock | "motor fixed balance" |
| increase max speed | faster catch reach | torque may fall on envelope | "faster is always stronger" |
| increase power cap | more torque at speed | more energy/heat demand | "stall torque was the issue" |
| increase \(K_p\) | faster error correction | overshoot/chatter/structural load | "stiff means stable" |
| increase \(K_d\) | more damping | sluggish response/noise sensitivity | "damping cannot hurt" |
| increase spring \(k\) | more passive restoring torque | higher natural frequency | "free support" |
| increase damping \(c\) | dissipates motion | can fight desired rise/swing | "more damping fixes every fall" |
| increase friction \(\mu\) | wider tangential force cone | can increase snag/tip moment | "no slip means good gait" |
| increase contact cap | more points observable | more data/cost, not more physics | "reported contacts created support" |
| increase solver iterations | lower constraint error | more compute, changed trajectory | "controller improved" |
| reduce timestep | finer integration | gains/load rates change per tick | "same parameters mean same model" |
| increase brace threshold | earlier intervention | false positives/lost gait freedom | "early is always safe" |
| reduce load ramp time | quicker bearing force | higher impact/solver stress | "touch instantly means support" |
| increase extension target | more height | worse singularity/less shock travel | "straighter always braces better" |

### 19.2 Natural-frequency interpretation

For a one-DOF inertia \(I\) under PD control:

\[
I\ddot q + K_d\dot q + K_p(q-q^\*)=0
\]

Approximate natural frequency:

\[
\omega_n=\sqrt{\frac{K_p}{I}}
\]

Approximate damping ratio:

\[
\zeta=\frac{K_d}{2\sqrt{IK_p}}
\]

If inertia quadruples and gains do not change, natural frequency halves. If \(K_p\) increases without
matching \(K_d\), damping ratio falls. This is why a gain copied between a tiny toe and a heavy hip
has no stable meaning.

Use measured engine inertia in the dyno. Analytic subtree inertia is a predictor and cross-check,
not the final body-collider tensor.

### 19.3 Timestep scaling

Continuous gains are expressed in SI units:

```text
Kp: N*m/rad
Kd: N*m*s/rad
load rate: N/s
activation time constant: s
```

Update rules multiply by \(\Delta t\) exactly where integration requires it. Avoid constants like
"add 0.1 load per tick" unless converted from a per-second parameter and logged.

When changing physics tick rate:

- repeat observer/timing gates;
- repeat passive energy gates;
- repeat contact/load-rate gates;
- do not merely retune until old outcome returns.

### 19.4 Tuning order

Tune in this order:

1. coordinate frames and signs;
2. mass and measured inertia;
3. active torque/speed/power envelopes;
4. structural limits;
5. contact/friction facts;
6. feed-forward gravity/support estimate;
7. low-gain feedback;
8. damping;
9. disturbance response;
10. brace thresholds;
11. passive tissues;
12. gait/recovery optimization.

If an earlier layer is wrong, later tuning converts the error into brittle compensation.

### 19.5 One-variable sweeps

Every calibration sweep keeps all but one declared factor fixed:

```text
parameter
range and units
seed set
fixture version
primary response metric
secondary side effects
failure-code counts
accepted region
reason for next range
```

Use logarithmic sweeps for values spanning orders of magnitude, such as stiffness or actuator
capacity. Refine locally only after the broad response is understood.

---

## 20. Risks, tradeoffs, and decisions

### 20.1 Separate lab stack versus immediate refactor

**Separate lab stack — recommended first**

Pros:

- singular fixtures remain understandable;
- legacy gameplay stays usable;
- command ownership can be proven before cutover;
- evidence schemas can stabilize without training-loop noise.

Cons:

- temporary duplication/adapters;
- later migration work;
- risk that lab and gameplay diverge.

Mitigation: build shared low-level contracts (`JointState`, actuator, support math, ledger), then make
gameplay consume those proven pieces.

**Immediate controller rewrite**

Pros:

- no parallel architecture;
- fastest path if every current assumption were already correct.

Cons:

- too many simultaneous unknowns;
- regressions cannot be localized;
- old "walking" tests pressure the new code toward preserving unproven behavior;
- high risk of another opaque gain-tuning cycle.

### 20.2 Analytic allocator versus optimizer

**Analytic V1/V2 — first**

Pros:

- closed-form expected outputs;
- easy sign and unit debugging;
- no solver dependency;
- excellent micro-oracles.

Cons:

- limited contacts/DOFs;
- cannot optimally handle a hundred toes.

**Constrained optimizer V3 — later**

Pros:

- handles many contacts and competing constraints;
- exposes residual/margins;
- supports distributed feet.

Cons:

- new numerical failure modes;
- weights and regularization can hide wrong physics;
- optimizer feasibility can be confused with body feasibility.

### 20.3 Contact impulse as force sensor

Pros:

- engine-provided;
- useful for load transitions and momentum cross-checks.

Cons:

- impulse is step-integrated, not continuous force;
- Jolt values are estimates, especially with multiple contacts;
- buffer caps and solver settings affect reporting.

Decision: use it as a status-labeled estimate, compare total momentum change, and avoid precision
claims it cannot support.

### 20.4 Explicit actuator first versus anatomy-derived actuator first

Explicit actuator first isolates integration. Anatomy-derived capacity becomes meaningful only after
the same numeric spec passes the dyno.

The tradeoff is temporary duplication between an authored `ActuatorSpec` and current genome muscle
properties. That duplication is deliberate and short-lived; combining them immediately would make
formula errors indistinguishable from executor errors.

### 20.5 1DOF hinges versus richer joints

Keep 1DOF hinges through the planar ladder because they are easy to measure. Add multi-axis hips or
serial hinge pairs before claiming spatial biped/quadruped balance.

Do not fake a second joint axis by applying arbitrary world torque to a 1DOF joint. That violates the
morphology and makes recovery results unusable.

### 20.6 Full traces versus performance

Full per-contact/per-command traces can be large. The answer is profiles and retention:

```text
exploration:
  full trace for selected runs
  reduced profiles for sweeps after parity proof

promotion:
  full evidence profile

repository:
  only small accepted bundles and summaries

user data:
  raw run archive with retention policy
```

Never reduce fields by changing their meaning. Omit with explicit availability/profile semantics.

### 20.7 Recovery profiles versus learned recovery

Deterministic profiles are recommended first because they expose feasibility, contacts, and phase
failures. A learned policy can later output the same `ControlIntent` contract and face the same
gates.

Learning does not remove the need for actuator, contact, energy, scaffold, or evidence honesty.

### 20.8 Known implementation risks

| Risk | Early tripwire |
|---|---|
| control reads mixed-tick state | frame IDs asserted at controller entry |
| retained builder mutates a sealed record | post-seal mutation/hash/executor negative test |
| double torque application | executor counts exactly one pair/joint/tick |
| stale axis survives in generic path | rotated-parent test plus no raw `axis` reads |
| hinge anchor drift corrupts Jacobian | dual-anchor separation gate |
| wrapped angle jumps at plus/minus pi | branch-crossing unwrapped-angle oracle |
| mismatched wrench references are added | lever-arm reference-shift unit test |
| self-contact becomes fake ground support | creature-internal contact exclusion/dedup test |
| contact cap silently truncates gecko foot | saturation invalidates run |
| spring injects energy | closed-cycle work test |
| standing relies on rail constraint | rail impulse recorded; later rail removal gate |
| pinned foot makes rail support look valid | forbidden-intervention scan and unilateral pull test |
| controller fights joint constraint | requested/applied/limit state logged |
| bracing always triggers too late | TTC prediction error histogram |
| recovery succeeds via collision correction | energy/intervention residual |
| UI observer changes physics | headless/viewer parity |
| final manifest invalidates its own hash | bundle finalization/checksum-order test |
| recursive test change runs unintended files | discovery manifest before runner cutover |
| legacy "walk" label returns by accident | accepted-evidence registry controls claims |

---

## 21. Exact commands and expected outcomes

### 21.1 Environment

Use a **PowerShell 7** (`pwsh`) terminal in VS Code. The bounded native-process
runner deliberately rejects legacy Windows PowerShell 5.1 because it lacks the
modern `ProcessStartInfo.ArgumentList` API used for unambiguous path and
argument handling:

```powershell
Set-Location "<repo>"
$godot = "<godot-dir>\Godot_v4.7-stable_mono_win64_console.exe"
& $godot --version
```

Expected:

```text
4.7...
```

If that exact executable moves, pass the new path to `scripts/run_all_tests.ps1`; do not edit every
command in the documentation.

### 21.2 Re-register new `class_name` scripts

After adding core lab classes:

```powershell
& $godot --headless --path . --editor --quit
```

Expected:

- exit code `0`;
- no parse errors;
- `.godot` metadata refreshed locally.

The engine can still emit known shutdown/leak warnings; a new parse or resource-load error is not
benign.

### 21.3 Run one current-style test

Before any BR code exists, run a real current test:

```powershell
& $godot `
  --headless `
  --path . `
  --script "res://tests/test_joint_kinematics.gd"
```

Expected convention:

```text
... passed
exit code 0
```

The test script itself must print assertion count and failure details; exit zero with no assertions
is not a useful test.

After BR4 creates it, the focused actuator command becomes:

```powershell
& $godot `
  --headless `
  --path . `
  --script "res://tests/test_lab_joint_actuator.gd"
```

Do not present that second command as runnable before the file exists.

### 21.4 Run the full current suite

```powershell
.\scripts\run_all_tests.ps1 -Godot $godot
```

Expected tail:

```text
SUMMARY total=<count> passed=<count> failed=0
```

Because physics suites can be long, run focused lab tests during implementation and the full suite
at every cutover milestone.

### 21.5 Proposed lab command

Once BR1 implements `scripts/lab/run_lab.gd`, the first scientific invocation is `L0.0`, not a
rail-leg controller:

```powershell
& $godot `
  --headless `
  --path . `
  --script "res://scripts/lab/run_lab.gd" `
  -- `
  --experiment-spec "res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres" `
  --seed 42 `
  --observer full_state_v1 `
  --output-root "user://lab/runs"
```

Expected:

```text
LAB run_id=<id>
LAB experiment=L0_0_STATIONARY_GRAVITY_OFF seed=42
LAB resolved_spec=res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres
LAB expanded_spec_sha256=sha256:<hash>
LAB termination=completed evidence_validity=valid
LAB hypothesis_result=<supported|contradicted|inconclusive>
LAB promotion=<pass|fail>
LAB artifacts=<absolute user-data path>
```

The proposed CLI should exit:

```text
0  completed/evidence-valid/promotion-pass, or successful --validate-only with no run
2  completed, evidence valid, promotion fail
3  evidence invalid
4  configuration/schema error
5  crash-safe abort
```

This distinction lets automation preserve scientifically useful failed experiments without treating
configuration errors as behavioral results.

CLI contract:

```text
--experiment-spec <res://...tres>  exactly one resource path
--validate-only                    compile/hash/print; do not spawn physics or create a run
--seed <int>                       mutually exclusive with --seed-set
--seed-set <registered-id>         mutually exclusive with --seed
--observer <registered-profile>
--output-root <user://...>         defaults to user://lab/runs
--sweep <json-pointer>=<csv>       one factor for ordinary experiments
```

Unknown arguments, unknown observer/seed-set IDs, conflicting seed options, unsafe output roots,
duplicate scalar overrides, a second sweep factor without a preregistered factorial-campaign spec,
and unitless scientific values exit `4` before spawn. The resolved resource path, authored resource
SHA-256, expanded spec, and expanded-spec SHA-256 are recorded.

Validate a spec without starting physics or creating any run/campaign directory:

```powershell
& $godot `
  --headless `
  --path . `
  --script "res://scripts/lab/run_lab.gd" `
  -- `
  --experiment-spec "res://data/lab/experiments/L0_0_stationary_gravity_off_v1.tres" `
  --seed 42 `
  --observer full_state_v1 `
  --validate-only
```

Expected: exit `0`, the resolved `res://` path and both resource/spec hashes are printed, and the
runner explicitly reports `spawned_physics=false` and `artifact_directory_created=false`.

### 21.6 Proposed parameter sweep

```powershell
& $godot `
  --headless `
  --path . `
  --script "res://scripts/lab/run_lab.gd" `
  -- `
  --experiment-spec "res://data/lab/experiments/BR06_rail_leg_disturbance_v1.tres" `
  --seed-set promotion_a `
  --sweep /actuator/max_isometric_torque_nm=20,40,80,160
```

Expected:

- one immutable manifest per cell;
- one matrix summary;
- no cell silently skipped;
- invalid evidence separated from physical failures;
- parameter values printed with units.

That is a one-factor torque-capacity campaign. A separate one-factor friction campaign uses:

```powershell
& $godot `
  --headless `
  --path . `
  --script "res://scripts/lab/run_lab.gd" `
  -- `
  --experiment-spec "res://data/lab/experiments/BR06_rail_leg_disturbance_v1.tres" `
  --seed-set promotion_a `
  --sweep /surface_materials/ground/friction=0.2,0.5,1.0
```

Do not place both sweeps in one ordinary experiment: the evidence contract allows one declared
independent variable. A later factorial campaign may preregister multiple factors, interaction
terms, cell policy, and analysis; it uses a dedicated campaign spec/schema and is labeled
`factorial` or `exploratory`, never smuggled through the paired one-factor causal gate.

The sweep launches a fresh Godot process per canonical cell. Its aggregate exit code uses this
precedence:

```text
5  any controlled safety abort
4  matrix configuration invalid before execution
3  any executed cell has invalid evidence
2  evidence valid, but any required-feasible cell fails promotion
0  every required cell passes; exploratory/infeasible cells match their declared policy
```

The matrix summary names every cell and its own exit/result. An in-process `--development-batch`
mode may trade isolation for speed, but it cannot produce promotion evidence.

### 21.7 Inspect a run without the viewer

Proposed artifact inspection:

```powershell
$run = "<absolute run directory printed by the runner>"
Get-Content (Join-Path $run "summary.json")
Get-Content (Join-Path $run "events.jsonl") |
  Select-String "MODE_TRANSITION|ALLOCATOR_INFEASIBLE|ABORT"
```

Expected:

- `summary.json` names termination, validity, hypothesis result, and promotion;
- event lines provide exact frame IDs and reasons;
- completed runs include `checksums.json`.

### 21.8 Static tripwire scans

During actuator cutover:

```powershell
$mutationPattern = @(
  "apply_torque",
  "apply_torque_impulse",
  "apply_central_force",
  "apply_force",
  "apply_central_impulse",
  "apply_impulse",
  "add_constant_force",
  "add_constant_torque",
  "constant_force\s*=",
  "constant_torque\s*=",
  "linear_velocity\s*=",
  "angular_velocity\s*=",
  "global_transform\s*=",
  "global_position\s*=",
  "position\s*=",
  "PhysicsServer3D\..*body_set_state",
  "freeze\s*=",
  "sleeping\s*=",
  "motor/enable",
  "limit/enabled"
) -join "|"
rg -n $mutationPattern scripts\lab scripts\sim
```

Expected:

- lab torque application appears only in the executor;
- allowed fixture disturbance/scaffold calls are named and ledgered;
- no controller writes a body transform after release;
- legacy hits are enumerated until deliberately migrated.

Static scans are tripwires, not proof. Dynamic executor/intervention ledgers remain authoritative.

### 21.9 Validate documentation changes

```powershell
git diff --check
rg -n "[ \t]+$" `
  README.md `
  docs\LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md `
  docs\BRACING_RECOVERY_IMPLEMENTATION_BOOTSTRAP.md
git status --short
```

Expected:

- `git diff --check` reports no tracked-diff whitespace errors;
- `rg` exits `1` with no output, meaning no trailing whitespace even in the new/untracked document;
- only intended documentation/link changes for this bootstrap phase.

`git diff --check` does not inspect an untracked file. That is why the explicit path scan is
required. The final documentation validation also resolves every relative Markdown target and line
anchor against the current workspace; a pretty link whose file does not exist is a failure.

---

## 22. Concrete first implementation slice

### 22.1 What to build first

The first code slice is the complete BR1/L0 evidence spine. Do not stop after creating files and
call the recorder calibrated:

```text
scripts/lab/experiment_spec.gd
scripts/lab/expanded_experiment.gd
scripts/lab/spec_compiler.gd
scripts/lab/observer_profile.gd
scripts/lab/lab_process_launcher.gd
scripts/lab/lab_runner.gd
scripts/lab/rig_factory.gd
scripts/lab/trace_store.gd
scripts/lab/canonical_json.gd
scripts/lab/frozen_value.gd
scripts/lab/random_stream_capability.gd
scripts/lab/capture_clock.gd
scripts/lab/frame_assembler.gd
scripts/lab/finite_sanitizer.gd
scripts/lab/pre_event_ring_buffer.gd
scripts/lab/command_ledger.gd
scripts/lab/actuation_executor.gd
scripts/lab/intervention_executor.gd
scripts/lab/schema_validator.gd
scripts/lab/run_bundle_validator.gd
scripts/lab/trace_replay.gd
scripts/lab/comparison_runner.gd
scripts/lab/campaign_runner.gd
scripts/lab/event_detector.gd
scripts/lab/mechanics_accountant.gd
scripts/lab/gate_evaluator.gd
scripts/lab/report_builder.gd
scripts/lab/run_index.gd
scripts/lab/failure_codes.gd
scripts/lab/records/body_sample.gd
scripts/lab/records/joint_torque_command.gd
scripts/lab/records/decision_record.gd
scripts/lab/records/mechanics_record.gd
scripts/lab/records/intervention_record.gd
scripts/lab/records/execution_receipt.gd
scripts/lab/records/recovery_event.gd
scripts/lab/records/runtime_note.gd
scripts/lab/records/run_summary.gd
scripts/lab/mechanics/observed_rigid_body.gd
scripts/lab/mechanics/sensor_frame_builder.gd
scripts/lab/mechanics/whole_body_state.gd
scripts/lab/control/lab_control_context.gd
scripts/lab/control/command_sink.gd
scripts/lab/control/control_intent.gd
scripts/lab/control/control_arbiter.gd
scripts/lab/rigs/stationary_body_rig.gd
scripts/lab/rigs/free_fall_rig.gd
scripts/lab/rigs/ballistic_rig.gd
scripts/lab/run_lab.gd
data/lab/experiments/L0_0_stationary_gravity_off_v1.tres
data/lab/experiments/L0_1_free_fall_v1.tres
data/lab/experiments/L0_2_ballistic_zero_g_v1.tres
data/lab/experiments/L0_3_observer_ab_v1.tres
data/lab/experiments/L0_4_trace_playback_v1.tres
data/lab/schemas/manifest_v1.schema.json
data/lab/schemas/frame_v1.schema.json
data/lab/schemas/command_v1.schema.json
data/lab/schemas/application_v1.schema.json
data/lab/schemas/decision_v1.schema.json
data/lab/schemas/intervention_v1.schema.json
data/lab/schemas/mechanics_v1.schema.json
data/lab/schemas/event_v1.schema.json
data/lab/schemas/comparison_v1.schema.json
data/lab/schemas/campaign_manifest_v1.schema.json
data/lab/schemas/child_run_index_v1.schema.json
data/lab/schemas/matrix_summary_v1.schema.json
data/lab/schemas/runtime_note_v1.schema.json
data/lab/schemas/process_metadata_v1.schema.json
data/lab/schemas/pre_event_entry_v1.schema.json
data/lab/schemas/summary_v1.schema.json
data/lab/schemas/checksums_v1.schema.json
tests/test_lab_trace_round_trip.gd
tests/test_lab_tick_order.gd
tests/test_lab_spec_compiler.gd
tests/test_lab_schema_validator.gd
tests/test_lab_sealed_values.gd
tests/test_lab_seed_streams.gd
tests/test_lab_global_rng_rejected.gd
tests/test_lab_command_envelope_hash.gd
tests/test_lab_application_receipts.gd
tests/test_lab_controller_context_immutable.gd
tests/test_lab_nonfinite_terminal_evidence.gd
tests/test_lab_unique_run_reservation.gd
tests/test_lab_process_metadata_lifecycle.gd
tests/test_lab_pre_event_buffer_dump.gd
tests/test_lab_summary_provenance.gd
tests/test_lab_run_bundle_validator.gd
tests/test_lab_comparison_bundle.gd
tests/test_lab_source_state_gate.gd
tests/test_lab_partial_run_not_promotable.gd
tests/test_lab_l0_stationary_gravity_off.gd
tests/test_lab_l0_free_fall.gd
tests/test_lab_l0_ballistic_zero_g.gd
tests/test_lab_observer_ab.gd
tests/test_lab_trace_playback_no_physics.gd
```

The first fixtures are one labeled rigid body in stationary, free-fall, ballistic, and zero-gravity
conditions. The hinge moves to BR2 after frame identity and replay are proven. None needs a creature
genome, CPG, foot, or gait.

### 22.2 First implementation acceptance

Stop the slice when:

- a manifest is created;
- the expanded spec validates, canonicalizes, hashes, and prints in `--validate-only`;
- frame 0 and frame 1 have explicit sample/experiment phases and times;
- a sealed empty command record maps 0 to 1;
- synthetic command/intervention operations prove the generic one-plan/one-receipt validator before
  any real actuator is added;
- retained-builder mutation cannot alter any sealed record/hash;
- controllers cannot access mutable specs, raw/global RNG, or unregistered randomness;
- stationary, free-fall, ballistic, and zero-g predictions pass;
- observer A/B quantifies capture perturbation;
- trace playback with physics disabled reproduces transforms, events, and derived metrics;
- a fresh-process same-seed rerun preserves structural event order within its declared tolerance;
- an interrupted run cannot promote;
- process metadata and crash-buffer entries validate and remain recoverable after interrupted writes;
- final bundles validate schemas, cross-record IDs, counts, and checksums before rename;
- no gameplay file needed behavioral modification.

Do not continue into a joint observer or motor until these facts are boringly reliable.

### 22.3 Suggested commit sequence

Keep commits independently inspectable:

```text
docs: establish bracing and recovery bootstrap
lab: add versioned run manifest and trace lifecycle
lab: add immutable body observation and L0 physics oracles
lab: add observer parity and no-physics trace playback
lab: add immutable joint observation and coordinate oracles
lab: add contact capture and support lifecycle
lab: add paired actuator ledger and dyno
lab: add passive tissue energy oracles
lab: add vertical rail support fixture
lab: add planar support allocator and stance
lab: add brace detector and existing-contact arrest
lab: add catch-step fixture
lab: add fallen pose classifier and first recovery profile
sim: migrate proven actuator/support components into gameplay
```

Avoid a single "locomotion rewrite" commit. The history should preserve which physical proposition
became true at each step.

### 22.4 Knowledge entry written after every gate

Target:

```text
docs/locomotion_encyclopedia/<topic>/<entry>.md
```

Template:

```markdown
# Finding

## Claim
Exactly one bounded statement.

## Scope
Fixture, morphology, engine/backend, timestep, surface, seed set.

## Mechanism
Equation and causal explanation.

## Evidence
Run IDs, plots, trace fields, positive and negative controls.

## Failure boundary
Where and why it stops working.

## Parameters
Units, accepted region, sensitivity.

## Reuse
Which later controllers or morphologies may rely on it.

## Unknowns
What remains deliberately unclaimed.
```

Example first claim:

```text
In fixture BR04 loaded_hinge_v1 under Godot 4.7 Jolt at 60 Hz,
the paired actuator produces the predicted angular acceleration within the
declared tolerance across the tested inertia and torque range.
```

That is far more reusable than "the leg looked strong."

### 22.5 Things deliberately not in the first slice

```text
walking
CPG tuning
reinforcement learning
genetic optimization
3D quadruped balance
hundred-toe optimizer
full arbitrary-pose get-up
gameplay assist removal
anatomy-derived motor constants
```

They are not rejected. They are downstream of facts we do not yet possess.

---

## 23. What hinges on what

### 23.1 Dependency graph

```text
truthful tick/frame recorder
  ├─> L0.0 stationary / L0.1 free fall / L0.2 ballistic
  ├─> L0.3 observer A/B
  ├─> L0.4 no-physics trace playback
  ├─> sealed frame/command/decision/intervention/mechanics evidence
  └─> fresh-process reproducibility
        |
        +-> coordinate/body/joint oracles
              └─> current axis, dual-anchor pivot, q/qdot, inertia
                    └─> L1.0-L1.7 engine/contact truth
                          └─> L2 joint/actuator truth
                                ├─> passive tissue energy
                                └─> L3.0-L3.2 loaded pad/shear/rocking
                                      └─> bearing-contact/support geometry

active actuator + loaded-foot truth + support math
  └─> BR6A one-leg rail support
        └─> crouch and active rise
              └─> planar multi-contact stance
                    └─> early brace detection
                          └─> existing-contact brace
                                |
                                +-> L4.2 free swing
                                +-> L4.5 clearance
                                +-> L4.6 touchdown/load transition
                                +-> L7.0 ordinary foot contacts with fixed/scaffolded pelvis
                                      └─> constrained atomic-step research

existing-contact brace + certified swing/touchdown
  └─> reachable catch contact
        └─> controlled fall arrest
              └─> stable fallen pose
                    └─> pose classification and feasibility
                          └─> constrained canonical get-up
                                └─> one canonical free 3D morphology
                                      └─> preregistered morphology matrix

BR5 passive tissue + BR6A rail support
  └─> separate BR6B pogo energy program

L1.8 high-contact discretization
  └─> microtoe/friction-pad expansion
        └─> separately modeled adhesion, if ever added
```

### 23.2 The causal answer to the original symptom

The observed creature could not brace or straighten effectively because the current pipeline does
not yet provide one trustworthy end-to-end chain from:

```text
measured fall state
-> support/catch decision
-> feasible desired contact wrench
-> current Jacobian and joint axes
-> explicit actuator torque/speed/power
-> paired limb torque
-> measured contact impulse and body response
-> state transition based on the response
```

Instead, current behavior mixes pose tracking, tracked-leg task torques, passive calls, contact-light
heuristics, root assists, and terminal fall evaluation. Some components are individually useful,
but the chain is neither unified nor sufficiently observable to say which one failed.

### 23.3 Definition of success before atomic-step research

We may begin constrained `L7` atomic-step research for a declared morphology only when it can:

1. carry its own weight without hidden root support;
2. crouch and rise with legal, explained energy;
3. reject bounded disturbances through its contacts;
4. recognize a worsening fall before terminal impact;
5. redistribute existing support;
6. swing one unloaded limb in free space with measured clearance;
7. touch down with bounded impulse and complete `TOUCH -> LOAD -> BEARING`;
8. transfer load between two feet using ordinary unilateral ground contact while the pelvis alone
   is explicitly fixed/scaffolded;
9. reproduce those claims in fresh processes across the fixed prerequisite seed/parameter set;
10. declare explicit infeasibility outside that envelope.

That makes constrained stepping the next small problem. It does **not** yet prove free walking.

### 23.4 Definition of robust autonomy

The separate robust-autonomy track additionally requires the morphology to:

1. create a reachable catch contact when current support cannot recover;
2. reduce linear/angular momentum honestly when upright recovery before impact is impossible;
3. classify at least one stable fallen pose;
4. reject infeasible recovery profiles before applying fantasy commands;
5. execute one constrained get-up and hand control back to stance;
6. repeat the task without recovery scaffolds for one canonical spatial morphology;
7. pass every preregistered required-feasible matrix cell and fail expected-infeasible cells for the
   expected reason.

Free-walking promotion still uses the locomotion program's repeated stance/swing, propulsion,
load-transfer, body-carriage, energy, robustness, and causal-control evidence. Neither support nor
get-up alone is walking.

### 23.5 First move

The immediate move is not a quadruped gait edit. It is:

```text
BR1 / L0.0 stationary body with gravity off
-> L0.1 free fall
-> L0.2 ballistic and zero-g coast
-> L0.3 observer A/B
-> L0.4 trace playback with physics disabled
-> BR2 labeled body and hinge
-> BR3A L1 engine/contact truth
-> BR4 L2 joint/actuator truth
-> BR3B L3 loaded-foot truth
```

That sequence will tell us whether a limb can actually create and transmit force before we ask it to
coordinate a body, catch a fall, stand up, or walk. Once each link has a passing oracle and a named
failure boundary, every later failure becomes smaller, singular, and fixable—the exact working
method this project now needs.

---

## 24. From verified physics to weird-movement authoring and creature repair

### 24.1 Direct answer

Yes: this foundation is meant to let LoColemotion author movement for weird bodies without baking
“quadruped with four named legs” into the movement system.

It will not make every arbitrary sculpture physically capable of every requested motion. It will do
something more valuable:

```text
describe what contacts and actuators this morphology actually has
-> identify which support/motion primitives are feasible
-> compose those primitives into an authored behavior
-> explain a failure in measured causal terms
-> propose the smallest evidence-backed change that restores feasibility
-> rerun the exact experiment
-> promote the new finding into reusable knowledge
```

That is the path to a real creature sandbox experience: creative freedom, understandable consequences,
and useful guidance that preserves the creature's identity.

### 24.2 Movement vocabulary must be morphology-neutral

Do not author the final behavior as:

```text
move front-left leg, then rear-right leg
```

Author it as:

```text
maintain these bearing contacts
request this bounded body wrench
unload one eligible effector
create a reachable contact in this region
transfer load after TOUCH -> LOAD -> BEARING
release the old contact only after the new support is viable
```

A quadruped may satisfy that sequence with a diagonal pair. A 100-toe pad may propagate a contact
wave. A cup-foot pogo may rock to an edge and launch. A tentacled body may plant two arms, roll over
a side pad, then pull a tail clear. The behavior graph is the same kind of physical proposition;
the morphology supplies different effectors and feasible wrenches.

Proposed post-foundation types:

```gdscript
class_name MorphologyCapabilityDescriptor
extends Resource

var morphology_signature_sha256: String
var bodies: Array[Dictionary]
var joints: Array[Dictionary]
var actuators: Array[Dictionary]
var passive_tissues: Array[Dictionary]
var contact_effectors: Array[Dictionary]
var legal_contact_roles: Array[StringName]
var support_wrench_rank_by_contact_set: Dictionary
var reachable_contact_regions: Dictionary
var tested_parameter_envelopes: Dictionary
var accepted_knowledge_card_ids: Array[StringName]
```

```gdscript
class_name MovementPrimitiveSpec
extends Resource

var primitive_id: StringName
var required_capabilities: Dictionary
var initial_guard: Dictionary
var maintained_contacts: Array[StringName]
var contact_creation_goal: Dictionary
var desired_body_wrench_profile: Array[Dictionary]
var release_guard: Dictionary
var success_event: StringName
var failure_events: Array[StringName]
var evidence_gate_ids: Array[StringName]
```

The descriptor is generated from the actual part graph and the same live mechanics used by the lab.
It contains no guessed “animal class.” `MovementPrimitiveSpec` asks for capabilities, not a
particular skeleton topology.

### 24.3 The encyclopedia needs machine-readable cards and human explanations

The Markdown finding in Section 22.4 is the human view. Each accepted finding also receives an
immutable machine-readable card:

```json
{
  "schema": "sporespore.knowledge.card.v1",
  "card_id": "loaded_hinge_hold_v1_jolt47",
  "status": "accepted",
  "claim": "A paired hinge actuator holds the declared load inside this envelope.",
  "mechanism_id": "joint_static_torque_balance",
  "applicability": {
    "physics_backend_adapter": "jolt_direct_state_v1",
    "fixture_family": "loaded_hinge",
    "required_channels": [
      "joint_state_v1",
      "application_receipt_v1",
      "mechanics_v1"
    ],
    "parameter_predicates": [
      "required_torque_nm <= available_active_plus_passive_nm",
      "pivot_separation_m <= calibrated_tolerance_m"
    ]
  },
  "accepted_envelope": {
    "tested_load_cells_kg": [1.0, 3.0, 6.0, 12.0],
    "tested_angular_speed_cells_rad_s": [0.0, 0.1, 0.25, 0.5],
    "interpolation_policy": "none_without_calibrated_response_surface",
    "active_reserve_fraction_min": 0.15
  },
  "failure_signatures": [
    "ACTIVE_TORQUE_SATURATION",
    "HINGE_PIVOT_SEPARATION",
    "HARD_LIMIT_CONTAMINATION"
  ],
  "repair_levers": [
    {
      "path": "/actuator/max_isometric_torque_nm",
      "direction": "increase",
      "predicted_effect": "raises static active reserve",
      "does_not_fix": ["contact slip", "late detection"]
    }
  ],
  "evidence": {
    "promotion_run_ids": ["run_a", "run_b"],
    "negative_control_run_ids": ["run_zero_motor"],
    "campaign_manifest_sha256": "sha256:...",
    "aggregation_version": 1
  },
  "invalidated_by": []
}
```

Proposed files:

```text
scripts/knowledge/
  knowledge_card.gd
  knowledge_registry.gd
  finding_extractor.gd
  applicability_matcher.gd
  capability_descriptor_builder.gd
  movement_primitive_spec.gd
  movement_composer.gd
  repair_advisor.gd
  repair_sandbox.gd
  run_knowledge.gd

data/knowledge/schemas/
  knowledge_card_v1.schema.json
  capability_descriptor_v1.schema.json
  movement_primitive_v1.schema.json
  repair_suggestion_v1.schema.json

data/knowledge/cards/             # accepted, compact, versioned cards
docs/locomotion_encyclopedia/     # linked human explanations
```

Cards are append-only/versioned evidence products. An engine/backend/schema change does not silently
rewrite an old truth; it marks the old applicability envelope stale and schedules revalidation.
The predicate strings above are compact documentation; production cards encode a versioned,
allowlisted predicate AST—never executable source text. Tested min/max values do not imply every
intermediate morphology works. Interpolation/extrapolation remains disabled until a calibrated
response-surface card and held-out checks justify it.

### 24.4 How the encyclopedia “learns”

It does not promote whatever happened in the latest run. Knowledge has a lifecycle:

```text
exploratory observation
  -> candidate finding with explicit unknowns
  -> causal positive/negative intervention
  -> fresh-seed replication
  -> applicability boundary sweep
  -> accepted knowledge card
  -> cross-morphology challenge
  -> generalized card or morphology-specific exception
  -> revalidation/deprecation when dependencies change
```

Only accepted evidence can drive automatic repair. Exploratory and contradicted runs are still
valuable: they create hypotheses and failure signatures, but they cannot become invisible “facts.”
Every generalized card retains its supporting and contradicting child cards. The system learns both
what transfers and what does not.

The extraction path is:

```text
sealed run/campaign bundles
-> versioned metric aggregation
-> candidate claim + scope + failure boundary
-> human/automated consistency review
-> KnowledgeRegistry promotion
-> applicability matcher available to authoring and diagnostics
```

No language model summary outranks the hashes, raw trace fields, or promotion gates.

### 24.5 Minimal-change creature repair

“Fix this without changing what I made” must be a constrained optimization problem, not a button
that quietly redesigns the animal.

Let \(\theta\) be editable creature/controller parameters and let \(\Delta\theta\) be a proposed
repair:

\[
\min_{\Delta\theta}
\quad
w_e D_{\text{edit}}(\Delta\theta)
+
w_i D_{\text{identity}}(\theta,\theta+\Delta\theta)
+
w_r R_{\text{uncertainty}}(\Delta\theta)
\]

subject to:

\[
\text{required support/contact/actuator margins}
\ge
\text{declared safety margins}
\]

\[
\text{locked creator invariants remain unchanged}
\]

Creator-selected invariants may include:

```text
part/socket topology
limb and digit count
silhouette deviation
overall height/length bounds
color/material appearance
named “do not touch” parts
symmetry or intentional asymmetry
mass budget
behavioral style
```

Repair tiers:

| Tier | Allowed changes | Identity impact |
|---|---|---|
| 0 | controller timing, target height, load ramp, gains inside certified ranges | no body edit |
| 1 | hidden physiology/material parameters such as actuator capacity, damping, tendon rest/slack, pad friction within authored biology limits | visually unchanged |
| 2 | small bounded size/socket/mass-distribution edits under creator-set tolerances | slight geometry change |
| 3 | new contact part, joint, limb, topology, or major proportion change | redesign; never an automatic “quick fix” |

The advisor searches Tier 0 first, then Tier 1, then Tier 2. Tier 3 is an explained design option,
not an automatic mutation.

```gdscript
class_name RepairSuggestion
extends Resource

var diagnosed_failure_code: StringName
var causal_chain: Array[StringName]
var proposed_edits: Array[Dictionary]
var edit_tier: int
var identity_distance: float
var predicted_metric_deltas: Dictionary
var supporting_knowledge_card_ids: Array[StringName]
var applicability_warnings: Array[String]
var validation_experiment_spec: String
var confidence: float
```

Every suggestion must say:

```text
what failed
which measured term caused it
why this edit changes that term
what side effects are expected
what it cannot fix
which accepted experiments support the prediction
which exact sandbox experiment will verify it
```

The repair is first applied to a clone in `RepairSandbox`; the original creature is untouched.
Promotion requires the predicted failure code to disappear without creating a forbidden
intervention, new failure, or identity-bound violation.

### 24.6 Example diagnostic-to-repair mappings

| Symptom | Required diagnosis | Smallest likely lever | Why it may fail |
|---|---|---|---|
| crouches and keeps sinking | negative static torque reserve under measured load | lower stance height, redistribute load, then bounded actuator increase | does nothing if the foot is slipping |
| leg straightens but body does not rise | contact wrench or Jacobian leverage is wrong/insufficient | change contact target or slight joint/socket pose | more motor may only drive the foot sideways |
| foot slides while torque reserve is positive | friction-cone margin is negative | lower tangential demand, change load timing, bounded pad material change | high friction may cause tipping/snags |
| brace begins after impact deadline | \(t_{\text{bearing}}\ge t_{\text{impact}}-t_{\text{safety}}\) | earlier threshold, lower activation delay, nearer catch target | no timing edit can fix unreachable geometry |
| body oscillates on planted feet | closed-loop natural frequency/damping mismatch | certified \(K_p/K_d\) adjustment or load-rate change | can hide a one-tick sensor phase error |
| can stand but cannot rise | positive power/energy reserve is insufficient | slower rise, smaller height change, bounded power increase | static torque alone cannot supply rise work |
| wide weird foot still tips | usable pressure/contact wrench rank is lower than geometric hull suggests | change load distribution or add compliant independent digits | extra solver points on one rigid pad add no independent actuation |
| get-up planner issues impossible torques | recovery contact set/rank is infeasible | choose a different roll/plant phase or expose a legal side/tail contact | controller tuning cannot create missing contact authority |

These are hypothesis templates. The advisor must match the live failure signature and applicability
envelope before offering them.

### 24.7 Authoring weird movement

The authoring service composes only certified primitives:

```text
creator goal: “move forward with a low creeping style”
-> capability descriptor identifies legal bearing/swing/push effectors
-> registry retrieves applicable support, unload, reach, touchdown, and propulsion cards
-> composer proposes one or more event graphs
-> feasibility checker rejects impossible contact/wrench phases
-> sandbox runs the smallest constrained experiment for each phase
-> successful phases combine into an atomic cycle
-> scaffold authority is annealed
-> repeated free behavior faces the walking evidence contract
```

Possible outputs for strange morphologies include:

```text
distributed toe-wave crawl
cup-foot rock-and-pogo
tripod-to-tripod tentacle walk
body-roll plus tail catch
knuckle/elbow plant and vault
many-contact peristaltic pad
asymmetric limp that exploits one strong support side
protective fall-and-recover behavior when walking is infeasible
```

The same tool can explain that a requested style is outside the current morphology's capability
cone and show the smallest changes that would make it feasible.

### 24.8 Knowledge/product gates K0-K6

These begin after the underlying BR/L claims they consume are accepted:

| Gate | Proof |
|---|---|
| `K0_CARD_INTEGRITY` | every card validates, links to immutable accepted evidence, and reproduces its metrics |
| `K1_APPLICABILITY` | in-envelope fixtures pass and boundary/negative fixtures are rejected for the predicted reason |
| `K2_CAPABILITY_DESCRIPTOR` | descriptor rank/reach/reserve predictions match live micro-experiments |
| `K3_COMPOSITION` | an event/contact primitive composes on at least three structurally different morphologies without topology-specific code |
| `K4_MINIMAL_REPAIR` | advisor selects the causal lever, respects locked identity constraints, and beats larger-edit controls |
| `K5_COUNTERFACTUAL` | predicted metric direction/magnitude is calibrated by held-out one-variable interventions |
| `K6_CREATOR_HANDOFF` | UI explains cause, edit, tradeoff, evidence, and before/after validation without silently mutating the original |

The initial three morphology challenge should be deliberately unlike:

```text
one rail/cup pogo body
one ordinary articulated biped or quadruped
one distributed microtoe or tentacled body
```

Passing only three does not establish universality. It proves the authoring vocabulary is no longer
hard-coded to one body plan.

### 24.9 What the full creature sandbox experience means here

The desired player loop becomes:

```text
build something wild
-> see what it can currently do
-> ask why it fails
-> receive a specific, minimal, reversible suggestion
-> preview the physical consequence
-> accept/reject/edit the suggestion
-> watch the creature acquire a movement style appropriate to its body
```

The encyclopedia makes that loop improve over time. It does not erase creativity by normalizing
every animal into a standard quadruped; it expands the library of proven ways unusual bodies can
support, propel, catch, fall, and recover.

### 24.10 Concrete knowledge-layer implementation order

Build this only as accepted BR/L evidence becomes available:

```text
K0 schemas + read-only registry + evidence-link validator
-> finding extractor that can only read finalized accepted bundles
-> capability descriptor generated from the exact creature part graph
-> applicability matcher with explicit accepted/rejected reasons
-> movement primitive registry and event-graph composer
-> diagnostic matcher from failure codes/mechanics residuals
-> minimal-change repair search with locked identity constraints
-> cloned repair sandbox and before/after comparison campaign
-> creator-facing explanation/preview UI
```

Principal tests:

```text
tests/test_knowledge_card_evidence_links.gd
tests/test_knowledge_card_dependency_invalidation.gd
tests/test_capability_descriptor_rank_prediction.gd
tests/test_applicability_boundary_rejection.gd
tests/test_movement_primitive_topology_independence.gd
tests/test_repair_advisor_causal_lever.gd
tests/test_repair_advisor_identity_locks.gd
tests/test_repair_sandbox_original_unchanged.gd
tests/test_repair_counterfactual_calibration.gd
```

Proposed headless commands after those files exist:

```powershell
# Validate every card and its accepted evidence links.
& $godot --headless --path . `
  --script "res://scripts/knowledge/run_knowledge.gd" -- `
  --validate-registry

# Describe what one authored creature can physically attempt.
& $godot --headless --path . `
  --script "res://scripts/knowledge/run_knowledge.gd" -- `
  --describe-creature "res://data/creatures/<creature>.tres" `
  --output "user://knowledge/descriptors"

# Diagnose an evidence-valid failed run and search only small/reversible changes.
& $godot --headless --path . `
  --script "res://scripts/knowledge/run_knowledge.gd" -- `
  --propose-repair "<absolute-finalized-run-directory>" `
  --creature "res://data/creatures/<creature>.tres" `
  --max-edit-tier 2 `
  --lock topology,limb_count,protected_parts `
  --sandbox
```

Expected repair output:

```text
KNOWLEDGE diagnosed_failure=<stable-code>
KNOWLEDGE causal_chain=<measured-field -> violated-equation -> failed-gate>
KNOWLEDGE suggestion_count=<n>
KNOWLEDGE best_edit_tier=<0|1|2>
KNOWLEDGE identity_constraints=preserved
KNOWLEDGE predicted_metric_delta=<versioned values and units>
KNOWLEDGE evidence_cards=<ids>
KNOWLEDGE sandbox_comparison=<campaign-id>
KNOWLEDGE original_creature_mutated=false
```

The command produces suggestions and a cloned sandbox artifact. Applying a suggestion to the
creator's real creature remains an explicit editor action with undo.

---

## 25. BR4/L2 experimental implementation checkpoint — 2026-07-23

This checkpoint begins BR4 implementation after accepted BR3A contact-engine
truth. It does **not** accept BR4. All eight required L2 cells now exist and
pass, but there is no BR4 promotion-grade bundle family, certification report
family, detached attestation domain, clean reconciled campaign, milestone
decision, or accepted BR4 knowledge entry.

### 25.1 L2.0 fixed-base passive pendulum

Implemented:

- `scripts/lab/mechanics/passive_pendulum_analyzer.gd`
- `tests/test_experimental_l2_0_passive_pendulum.gd`

The fixture is a collisionless rectangular rigid link on a live
`HingeJoint3D` whose parent is a fixed `StaticBody3D`. The Godot hinge motor
and limit are disabled. There is no external torque or contact. A frozen
activation phase lets the fresh physics space and joint become live before
the authored 0.2 rad release is reapplied and the link is unfrozen at the
measurement boundary.

The independent small-angle physical-pendulum oracle is:

\[
I_\mathrm{pivot}
=
\frac{m(w^2+l^2)}{12}
+md^2
\]

\[
T
=
2\pi\sqrt{\frac{I_\mathrm{pivot}}{mgd}}
\]

At 120 Hz over 720 measured samples per trial:

| Trial | Measured period | Analytic period | Error | Energy/amplitude result |
|---|---:|---:|---:|---:|
| undamped A | 1.644113 s | 1.640093 s | 0.245% | 3.851% energy range; 99.832% late/early amplitude |
| undamped B | 1.644113 s | 1.640093 s | 0.245% | 3.851% energy range; 99.832% late/early amplitude |
| damped comparison | 1.642287 s | 1.640093 s | 0.134% | 30.159% final energy; 71.787% late/early amplitude |

Maximum live anchor disagreement was approximately 7 micrometers. Axis
disagreement, swing residual, and off-axis relative rate rounded to zero at
the printed precision. The analyzer rejects hidden motors, limits, contact,
external torque, mobile parents, unknown configuration fields, mutated
contracts, wrong sample counts, non-finite channels, off-schedule timestamps,
and negative norm-like channels.

Commissioning result: **24/24 assertions**.

Claim boundary:

> Exact fixed-base passive hinge fixture only; no actuator, load-bearing,
> standing, bracing, recovery, gait, or walking claim.

### 25.2 L2.1 gravity-off free-hinge paired-torque pulse

Implemented:

- `scripts/lab/mechanics/actuator_spec.gd`
- `scripts/lab/mechanics/joint_actuator.gd`
- `scripts/lab/mechanics/joint_torque_pulse_analyzer.gd`
- `tests/test_experimental_l2_1_free_hinge_torque_pulse.gd`

`LabActuatorSpec` rejects malformed, negative, ambiguous, and legacy capacity
sources instead of repairing them. `enabled=false` produces exactly zero
active capacity. `LabJointActuator` implements transition-mean activation,
torque-rate limiting, directional torque-speed and power bounds, structural
classification, signed work channels, and an exact pair of planned
equal-and-opposite torque operations.

The fixture uses two collisionless dynamic boxes whose centers of mass and
hinge anchor coincide. Gravity and damping are zero; sleeping, the built-in
hinge motor, and limits are disabled. Every tick follows:

```text
live joint state
-> actuator resolution
-> BR1 CommandLedger hash boundary
-> ActuationExecutor
-> two hash-linked call-returned receipts
-> live post-step joint/inertia observation
```

For equal/opposite torque \(\pm\tau\mathbf a\), the measured relative angular
velocity increment is compared with:

\[
\Delta\dot q
=
\tau
\left(
\mathbf a^\mathsf{T}(I_c^W)^{-1}\mathbf a
+
\mathbf a^\mathsf{T}(I_p^W)^{-1}\mathbf a
\right)
\Delta t
\]

The positive, negative, and zero controls produced:

| Cell | Applied angular impulse | Final relative rate | Maximum acceleration error | Maximum total axis angular momentum |
|---|---:|---:|---:|---:|
| positive | +0.00994444 N·m·s | +1.063476 rad/s | rounds to 0.0000% | approximately \(10^{-9}\) N·m·s |
| negative | -0.00994444 N·m·s | -1.063476 rad/s | rounds to 0.0000% | approximately \(10^{-9}\) N·m·s |
| zero | 0 | 0 | 0 | 0 |

The engine parent and child inverse inertias agree with their analytic box
values within 0.000023% and 0.000009%, respectively. Every one of the 36
transitions in each cell has two exact receipt-linked executor calls and zero
torque-pair residual.

Commissioning result: **24/24 assertions**.

Claim boundary:

> Exact gravity-off coaxial free-hinge paired-torque fixture only; no
> load-bearing, contact, standing, bracing, recovery, gait, or walking claim.

### 25.3 L2.2 unloaded PD step

Implemented:

- `scripts/lab/mechanics/joint_pd_controller.gd`
- `scripts/lab/mechanics/unloaded_pd_step_analyzer.gd`
- `scripts/lab/rigs/free_hinge_pd_rig.gd`
- `tests/test_experimental_l2_2_unloaded_pd_step.gd`

The controller is a sealed, side-effect-free resolver. It consumes target
angle, measured angle, and measured relative rate, and emits separately named
proportional and derivative torque components. It cannot touch a body. The
existing actuator, ledger, executor, and receipt path remains the only physics
mutation seam.

The two-rotor fixture is free floating, gravity off, collisionless, and has no
built-in motor or limit. The gains use the analytic reflected hinge inertia:

\[
I_\mathrm{eff}
=
\left(I_p^{-1}+I_c^{-1}\right)^{-1}
\]

\[
k_p = I_\mathrm{eff}\omega_n^2,\qquad
k_d = 2\zeta I_\mathrm{eff}\omega_n
\]

For \(\omega_n=8\ \mathrm{rad/s}\), \(\zeta=1\), and targets
\(\{+0.25,-0.25,0\}\ \mathrm{rad}\):

| Cell | 90% rise | Settling | Overshoot | Final angle | Final rate |
|---|---:|---:|---:|---:|---:|
| positive | tick 58 | tick 104 | 0.0000% | +0.2499754 rad | +0.0000983 rad/s |
| negative | tick 58 | tick 104 | 0.0000% | -0.2499754 rad | -0.0000983 rad/s |
| zero | not applicable | tick 0 | 0 | 0 | 0 |

The maximum free-pair angular momentum was approximately
\(3\times10^{-9}\ \mathrm{N\,m\,s}\). Recorded P, D, requested, actuator, and
applied torques agree without an unreported envelope clamp. Every transition
has two command-hash-linked executor receipts.

Commissioning result: **19/19 assertions**.

Claim boundary:

> Exact gravity-off, contact-free, coaxial free-hinge unloaded PD fixture
> only; no load-bearing, standing, bracing, recovery, gait, or walking claim.

### 25.4 L2.3 fixed-scaffold gravity hold

Implemented:

- `scripts/lab/mechanics/gravity_hold_analyzer.gd`
- `scripts/lab/rigs/fixed_hinge_gravity_rig.gd`
- `tests/test_experimental_l2_3_gravity_hold.gd`

A 2 kg, 0.5 m horizontal link is attached to an explicit frozen
`RigidBody3D` scaffold. The built-in motor, limit, damping, and contact are
disabled. Four fresh worlds apply 0%, 80%, 100%, and 120% of:

\[
\tau_g = mg\frac{l}{2} = 4.9\ \mathrm{N\,m}
\]

The live `LabJointState` scalar convention makes gravity acceleration negative
for this fixture; positive compensation opposes it. Results over the declared
30-tick short envelope:

| Compensation | Applied torque | Measured/analytic initial acceleration | Final angle | Final rate |
|---|---:|---:|---:|---:|
| 0% | 0 N·m | -29.21304 / -29.21304 rad/s² | -0.91254 rad | -6.67580 rad/s |
| 80% | 3.92 N·m | -5.84261 / -5.84261 rad/s² | -0.18753 rad | -1.43599 rad/s |
| 100% | 4.90 N·m | 0 / 0 rad/s² | 0 | 0 |
| 120% | 5.88 N·m | +5.84261 / +5.84261 rad/s² | +0.18976 rad | +1.48448 rad/s |

This establishes predicted single-joint gravity compensation on a fixed
scaffold. It does not establish a load-bearing free-root limb.

Commissioning result: **14/14 assertions**.

Claim boundary:

> Exact single-link fixed-scaffold horizontal gravity-hold fixture only; no
> free-root load bearing, articulated limb, standing, bracing, recovery, gait,
> or walking claim.

### 25.5 L2.4 live actuator feasibility curve

Implemented:

- `scripts/lab/mechanics/actuator_envelope_analyzer.gd`
- `scripts/lab/rigs/free_hinge_envelope_rig.gd`
- `tests/test_experimental_l2_4_actuator_envelope.gd`

Six isolated free-hinge transitions use a 1 N·m isometric limit, 10 rad/s
no-load speed, 2 W positive-work cap, 3 W absorption cap, and 1.5 eccentric
multiplier:

| Point | Initial relative rate | Request | Applied | Limiting classification |
|---|---:|---:|---:|---|
| isometric | 0 rad/s | +2 N·m | +1.0 N·m | isometric torque |
| low-speed positive work | 2 rad/s | +2 N·m | +0.8 N·m | torque-speed |
| positive power | 5 rad/s | +2 N·m | +0.4 N·m | positive power |
| near no-load | 9 rad/s | +2 N·m | +0.1 N·m | torque-speed |
| no-load speed | 10 rad/s | +2 N·m | 0 N·m | torque-speed |
| negative work | 5 rad/s | -2 N·m | -0.6 N·m | absorption power |

Every real angular-acceleration increment matched applied torque and analytic
inertia within 0.0002%. The measured curve does not interpolate beyond these
six points and says nothing about endurance or thermal capacity.

Commissioning result: **12/12 assertions**.

Claim boundary:

> Exact one-transition, gravity-off, contact-free free-hinge
> actuator-envelope fixture only; no endurance, load bearing, standing,
> bracing, recovery, gait, or walking claim.

### 25.6 L2.5 hard-limit reaction classification

Implemented:

- `scripts/lab/mechanics/hard_limit_reaction_analyzer.gd`
- `scripts/lab/rigs/free_hinge_limit_rig.gd`
- `tests/test_experimental_l2_5_hard_limit_reaction.gd`

Two free-floating hinge trials approach \(\pm0.25\ \mathrm{rad}\) limits at
\(\pm4\ \mathrm{rad/s}\). A matched control disables the limit. There is no
active torque, passive torque, command, motor, gravity, damping, or contact.

Both enabled cases stop at a maximum directional angle of 0.25683 rad and
produce mirrored momentum-balance impulses of
\(\mp0.0374035\ \mathrm{N\,m\,s}\) at tick 8. The disabled control passes
through to 1.0 rad at 4 rad/s and has zero inferred reaction impulse.

The result schema names the impulse
`hard_limit_constraint_reaction`, uses estimator
`relative_momentum_balance_v1`, and fixes active/passive torque and command
count at zero. A hard-limit impulse is therefore structurally unavailable as a
motor-strength or passive-strength observation.

Commissioning result: **12/12 assertions**.

Claim boundary:

> Exact gravity-off, contact-free coaxial free-hinge hard-limit fixture only;
> the inferred boundary impulse is a constraint reaction, never motor torque
> or passive strength, and proves no load bearing, standing, bracing,
> recovery, gait, or walking.

### 25.7 L2.6 fixed/free-root two-joint chain

Implemented:

- `scripts/lab/mechanics/two_link_chain_analyzer.gd`
- `scripts/lab/rigs/two_link_chain_rig.gd`
- `tests/test_experimental_l2_6_two_link_chain.gd`

The planar chain has a root, 0.4 m proximal link, 0.3 m distal link, and two
live hinges. Joint 1 receives +0.02 N·m and joint 2 receives -0.015 N·m for 24
ticks, followed by 24 zero-command coast ticks. Each transition contains two
joint commands, four exact paired operations, and four receipts.

| Root mode | Max \(|q_1|\) | Max \(|q_2|\) | Root displacement | Max total axis angular momentum | Max system-COM displacement |
|---|---:|---:|---:|---:|---:|
| fixed scaffold | 0.04699 rad | 0.18243 rad | 0 | external scaffold reaction expected | 2.657 mm |
| free | 0.27871 rad | 0.20517 rad | 4.729 mm | \(7\times10^{-8}\) N·m·s | 0.24 μm |

The free root receives no assistance operation. Its only root-targeted torque
is the equal-and-opposite parent half of the joint-1 command and is classified
as `joint_1_pair_reaction`. The free chain therefore does not borrow a hidden
root torque.

Commissioning result: **14/14 assertions**.

Claim boundary:

> Exact gravity-off, contact-free planar two-joint chain fixtures only; the
> fixed-root case has an explicit frozen scaffold and the free-root case uses
> only paired internal torques. This proves no contact load bearing, standing,
> bracing, recovery, gait, or walking.

### 25.8 L2.7 anchor-observer perturbation

Implemented:

- `scripts/lab/mechanics/anchor_error_perturbation_analyzer.gd`
- `tests/test_experimental_l2_7_anchor_error_perturbation.gd`

Four same-epoch synthetic body pairs inject anchor disagreement
\(\{0,2.5,7.5,20\}\ \mathrm{mm}\) around a declared 5 mm tolerance:

| Injected error | Observation | Anchor channel | Dependent angle/rate channels |
|---|---|---|---|
| 0 mm | valid | 0 mm | available |
| 2.5 mm | valid | 2.5 mm | available |
| 7.5 mm | invalid | `null` | unavailable |
| 20 mm | invalid | `null` | unavailable |

Both rejected cases carry `ANCHOR_MISMATCH` and
`JOINT_GEOMETRY_UNAVAILABLE`. The observer never replaces rejected geometry
with numeric zero, and the classification path has zero motor torque, passive
torque, and command count.

Commissioning result: **12/12 assertions**.

Claim boundary:

> Exact synthetic same-epoch joint-observer anchor perturbations only; this
> establishes failure signatures and channel availability, not physical joint
> strength, load bearing, standing, bracing, recovery, gait, or walking.

### 25.9 Current accounting and next work

| Scope | State |
|---|---:|
| L2 implementation cells | 8 / 8 |
| L2 experimental assertions | 131 / 131 |
| BR4 promotion artifacts | 0 |
| BR4 accepted claims | 0 |
| BR4 accepted knowledge entries | 0 |
| Automatic creature guidance newly authorized | No |
| Articulated load-bearing limb proven | No |
| Standing/bracing/fall arrest/get-up/gait/walking proven | No |

The implementation ladder is complete. The next stream must remain separate:

1. define a BR4 campaign and exact L2.0-L2.7 role/claim inventory;
2. define immutable per-program promotion capsules and a BR4 source closure;
3. define a BR4 certification report and detached receipt domain;
4. execute two complete fresh-process replicates from one clean commit;
5. reconcile every declared program without cherry-picking;
6. prepare a bounded BR4 milestone decision for the exact certified scopes;
7. only after acceptance consider observation-only knowledge admission;
8. keep automatic creature guidance disabled until later accepted
   contact-bearing/support milestones make joint evidence actionable.

### 25.10 Regression evidence

The complete experimental suite passed after L2.0-L2.7 implementation:

- programs: 22 / 22;
- assertions: 413 / 413;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br4_l2_full_implementation\20260723T032457095\report.json`.

The 413 assertions comprise:

- 131 L2.0-L2.7 commissioning assertions;
- 153 L1.1-L1.7 commissioning assertions;
- 28 L1.8 supplementary assertions;
- 101 BR3A commissioning, promotion, decision, draft-containment, and
  knowledge-admission assertions.

The unchanged pinned released suite also passed:

- programs: 62 / 62;
- assertions: 1118 / 1118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br4_l2_full\20260723T033009090\report.json`.

The earlier source-closure regression removed one brittle assumption from
`test_experimental_br3a_promotion_contracts.gd`: the test no longer requires
the live repository to remain forever at the historical 201-file closure. It
still independently enumerates every path currently selected by the exact
campaign source policy, verifies the exact live inventory, and proves that
omitting any selected file fails. No accepted BR3A campaign, report, receipt,
decision, knowledge entry, or source hash was rewritten.

## 26. BR4/L2 certification and bounded acceptance — 2026-07-23

BR4 now has a separate promotion-grade evidence family and an append-only
human decision. The accepted milestone is:

```text
BR4_L2_JOINT_ACTUATOR_TRUTH
```

Acceptance is bound to:

- certification `br4_20260723T090118Z_1760c2cf`;
- certified source `1760c2cfdfd4cf6fd5b482d090588a680515d1db`;
- campaign SHA-256
  `sha256:c5a8c97bd5bb3b58e79412f742d44eb266ef6e8f6eb6d83ad25eab15d49af417`;
- source-inventory SHA-256
  `sha256:a7780e98f0801894d474bb0af02ab78499c4768d8e13fd1c75a66b588c0fcec3`;
- report SHA-256
  `sha256:c21e209a37a94cc24072a135c33689b6511965ae9c14c8a56ca1d0b4d253dc33`;
- detached receipt SHA-256
  `sha256:d652b1ab1484110c00ce8769f361033a3e6e58632dcac71cd8b11d11f760f34c`;
- decision `BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1`;
- decision SHA-256
  `sha256:19dc2da4b372d3e50549eb9586b08ae796c6045897190ab4b60b8af4a72421a2`.

### 26.1 Complete campaign result

| Scope | Certified result |
|---|---:|
| Declared milestone programs | 8 / 8 |
| Fresh-process replicates per program | 2 |
| Production-attested bundles | 16 / 16 |
| Assertions | 262 / 262 |
| Target-process invocations | 16 |
| Unique target PIDs | 16 |
| PID recycle events | 0 |
| Supplementary programs | 0 |
| Integrity programs inside the milestone | 0 |
| Final complete readback | 16 / 16 |

The certified assertion total is exactly twice the 131-assertion
implementation inventory. No program was omitted, substituted, upgraded from
supplementary evidence, or cherry-picked.

The report is authenticated in the separate domain:

```text
sporespore.lab.br4_certification_report_attestation.v1
```

The bundle attestations remain in the generic production bundle domain. A
bundle receipt cannot substitute for the final BR4 report receipt.

### 26.2 Accepted boundary

The controlling campaign boundary remains:

> This campaign can certify only the exact L2.0-L2.7 joint-actuator
> observations named by the source-pinned programs. Fixed scaffolds, free
> roots, actuator envelopes, hard-limit reactions, two-joint behavior, and
> anchor-observer failures retain their declared fixture scopes. It
> establishes no contact-bearing articulated limb, per-foot or per-contact
> load allocation, standing, bracing, fall arrest, getting up, gait, walking,
> accepted knowledge, or automatic creature guidance.

The accepted contracts cover passive pendulum analysis, paired free-hinge
torque, PD resolution and unloaded step analysis, fixed-scaffold gravity
compensation, finite actuator resolution and envelope points, hard-limit
reaction classification, two-link chain analysis, and anchor-error
perturbation analysis.

The decision also preserves these interpretation constraints:

- a fixed scaffold is not free-creature support;
- a hard-limit impulse is not muscle or actuator strength;
- exact actuator points do not establish endurance, fatigue, or thermal
  capacity;
- anchor-observer refusal performs no repair;
- no root-only assistance or built-in motor authority was accepted;
- no per-contact, per-foot, or per-toe load allocation was accepted.

### 26.3 Decision authority and side effects

Cole delegated evidence-bounded acceptance judgment in direct conversation.
The decision binds that instruction to the exact review bytes at commit
`3588f92b5fe0e56e4c07aa114491ab4544c0988b`, not to a general permission to
widen claims.

Decision side effects remain exactly zero:

| Side effect | State |
|---|---:|
| BR4 knowledge entries admitted by the decision | 0 |
| Automatic knowledge admission | No |
| Automatic creature guidance | No |
| Contact-bearing articulated limb established | No |
| Standing/bracing/fall arrest/get-up/gait/walking | No |

The formal ladder is now **5/18 accepted (27.8%)**. Proven standing, bracing,
fall arrest, getting up, gait, and walking remain **0%**.

### 26.4 Decision integrity

Dedicated adversarial verification passed **24/24 assertions**. The checks
prove:

- exact decision/schema byte pins;
- exact report, receipt, campaign, source, and accounting identity;
- preservation of BR2.1 and BR3A decision bytes;
- refusal of claim broadening, walking-exclusion removal, evidence
  substitution, user-instruction rewriting, or review substitution;
- refusal of automatic knowledge admission or guidance;
- refusal of invented contact-bearing programs;
- refusal to reinterpret hard-limit reaction as strength;
- no permissive fallback for an unregistered decision revision.

The complete post-decision experimental regression passed:

- programs: 24 / 24;
- assertions: 467 / 467;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br4_acceptance_full\20260723T041706890\report.json`.

The immutable released-suite regression also passed:

- programs: 62 / 62;
- assertions: 1,118 / 1,118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br4_acceptance\20260723T042423229\report.json`.

Observation-only BR4 knowledge was later proposed and admitted through the
separate operation recorded in Section 27. The decision itself still admitted
zero entries. A later contact-bearing limb milestone must independently
combine accepted BR3A contact truth and accepted BR4 joint-actuator truth
under externally measured load.

## 27. BR4 observation-only knowledge admission — 2026-07-23

The accepted BR4 decision enabled a separate recommendation: retain the exact
L2.0-L2.7 observations as queryable knowledge without granting any repair,
controller, or creature-guidance authority.

The admission authority is
`BR4_L2_KNOWLEDGE_ADMISSION_V1`. Its fixed manifest is byte-pinned at
SHA-256
`sha256:d415c56a22e1e62a62d797a964d277cec75781585e7d6bab029c2877989242c8`.
It accepts no caller-supplied claim, status, evidence path, output path,
repair rule, or guidance policy.

### 27.1 Admitted observations

| Cell | Entry | SHA-256 |
|---|---|---|
| L2.0 | `L2.0.passive_hinge_period_and_damping.v1` | `sha256:e7461291acc05d1b3124ea14e5c80f636066dead4684ab63e0b32e290c54ff77` |
| L2.1 | `L2.1.paired_free_hinge_torque.v1` | `sha256:37555b8ecdea36b863b2d1806923c62c19af292640dce73cb7ab6ed4e0d1c480` |
| L2.2 | `L2.2.unloaded_pd_step_response.v1` | `sha256:261abf22e23a2ebf02f0f125b7b1675e280c79ed48ee99daa905fdcf56b7b8ae` |
| L2.3 | `L2.3.fixed_scaffold_gravity_compensation.v1` | `sha256:d53da1d469430e3c53fb73541c67dab29b4ddcbad77656cd4b35dda2ad6b1e34` |
| L2.4 | `L2.4.finite_actuator_operating_points.v1` | `sha256:5fea42e88911fea1c4de9806601227c86e54a06a4a5871962e9198cec62d12e8` |
| L2.5 | `L2.5.hard_limit_constraint_reaction.v1` | `sha256:263623af4f1c966e1aae6e627e0984f5b458c4039ac2d9ff5ed22729c3349d49` |
| L2.6 | `L2.6.two_link_fixed_free_root_separation.v1` | `sha256:64738765b891098a63cdf1d19a8337c1bfac17cdec5eba6efff0fdf988add8ea` |
| L2.7 | `L2.7.anchor_observer_fail_closed.v1` | `sha256:fcba302d4620a9c9ed3a6f88afac70ffd95cc6d4f1aaa9a5016b5db1cfd8a71e` |

Every entry:

- pins decision
  `BR4_L2_JOINT_ACTUATOR_TRUTH_DECISION_V1`;
- pins report SHA-256
  `sha256:c21e209a37a94cc24072a135c33689b6511965ae9c14c8a56ca1d0b4d253dc33`;
- pins detached report-receipt SHA-256
  `sha256:d652b1ab1484110c00ce8769f361033a3e6e58632dcac71cd8b11d11f760f34c`;
- retains exactly one certified program and both production-attested
  replicates;
- has `minimal_repair_rules=[]`;
- has `automatic_application_allowed=false`; and
- has `automatic_creature_guidance_allowed=false`.

The guidance fence can be reconsidered only after both:

1. an accepted contact-bearing support milestone; and
2. a separate guidance decision.

### 27.2 Integrity and accounting

The generic knowledge verifier now dispatches BR4 entries to their dedicated
contract and routes BR3A/BR4 append operations through their direct-child,
append-only writers. This closes a path by which a generic caller could
otherwise have verified a family-specific entry and selected a non-catalog
output location.

Post-admission compatibility passed:

- programs: 3 / 3;
- assertions: 72 / 72;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br4_knowledge_postadmission\20260723T044300469\report.json`.

The complete post-admission experimental suite passed:

- programs: 25 / 25;
- assertions: 488 / 488;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br4_knowledge_full\20260723T044501452\report.json`.

The immutable released suite also remained unchanged and passed:

- programs: 62 / 62;
- assertions: 1,118 / 1,118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br4_knowledge\20260723T045047484\report.json`.

Current knowledge accounting:

| Scope | Count |
|---|---:|
| Earlier L0 baseline | 1 |
| BR3A milestone observations | 8 |
| BR3A supplementary constraints | 1 |
| BR4 milestone observations | 8 |
| Total accepted entries | 18 |
| Entries with BR3A/BR4 repair rules | 0 |
| BR4 entries authorizing automatic application | 0 |
| BR4 entries authorizing creature guidance | 0 |

The formal milestone ladder remains **5/18 (27.8%)**. Knowledge admission
records already accepted evidence; it does not create another scientific
milestone. Contact-bearing load transmission, standing, bracing, fall arrest,
getting up, gait, and walking remain unproved.

## 28. BR3B L3.0-L3.2 implementation checkpoint — 2026-07-23

The three basic loaded-pad cells are implemented and commissioned. They remain
experimental until a clean, source-pinned BR3B campaign, detached report
receipt, and explicit milestone decision exist.

### 28.1 Force-boundary architecture

`loaded_pad_v1` is a single `0.30 m × 0.08 m × 0.20 m`, `2 kg` rigid pad. The
runner applies an explicit world-frame force once per physics tick through
`RigidBody3D.apply_force`.

The load boundary has:

- no physical carriage rail;
- no pin or translation constraint;
- no rotation constraint;
- no hidden linear or angular damping;
- no built-in motor or custom integrator; and
- no balancing moment beyond `application offset × declared force`.

This makes vertical-carriage language a description of the imposed force
boundary, not an undisclosed mechanical support.

### 28.2 L3.0 centered normal load

Four independent cells applied `0`, `20`, `40`, and `80 N` downward in addition
to the pad's `19.6 N` weight.

| External load | Expected support | Reconstructed support | Predicted raw-contact load |
|---:|---:|---:|---:|
| 0 N | 19.6000 N | 19.6000 N | 19.6490 N |
| 20 N | 39.6000 N | 39.6000 N | 39.6990 N |
| 40 N | 59.6000 N | 59.6000 N | 59.7490 N |
| 80 N | 99.6000 N | 99.6000 N | 99.8489 N |

Whole-system momentum reconstruction stayed within `0.000005 N`. The
single-manifold predicted-impulse channel remained a bounded cross-check, with
maximum error `0.248950 N`; it was not promoted into a general foot-force
sensor.

### 28.3 L3.1 loaded shear breakaway

With `40 N` of external downward load, reconstructed normal support remained
`59.6000 N`. A friction-`0.6` pad held through `34 N` of shear and slid at
`36 N`.

The empirical ratio bracket is:

```text
34 / 59.6 = 0.57047
36 / 59.6 = 0.60403
```

That bracket contains the authored coefficient and remains inside the accepted
L1 interval `[0.56122, 0.61224]`. The pad remained level, so rocking did not
contaminate the shear result.

### 28.4 L3.2 loaded rocking edge

For one downward force `F = 40 N` applied at horizontal offset `x`, the static
resultant center of pressure is:

```text
x_cop = F x / (m g + F)
```

With `m = 2 kg`, `g = 9.8 m/s²`, and a `0.15 m` support half-width, the analytic
critical application offset is `0.2235 m`.

- `0.21 m` remained level; predicted CoP was `0.1409 m`, or 93.1% of the edge.
- `0.24 m` rocked in the expected direction; predicted CoP was `0.1611 m`,
  outside the footprint.
- The measured bracket is `[0.21, 0.24] m`.
- A `-0.24 m` fresh-world repeat produced the mirrored edge pivot.

The earlier exploratory `0.28 m` overdrive was excluded from the exact
admission schedule because its already-gross edge violation introduced
pre-pivot slip. The nearest stable/unstable pair and mirror provide the
cleaner bounded claim.

### 28.5 Verification and current boundary

The combined implementation run passed:

- programs: 3 / 3;
- assertions: 43 / 43;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br3b_l3_implementation\20260723T051042754\report.json`.

The complete experimental regression also passed:

- programs: 28 / 28;
- assertions: 531 / 531;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br3b_implementation_full\20260723T051458040\report.json`.

The immutable released suite remained unchanged and passed:

- programs: 62 / 62;
- assertions: 1,118 / 1,118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br3b_implementation\20260723T052107988\report.json`.

This checkpoint proves only a free unary pad's exact centered-load,
loaded-shear, and rocking cells. It establishes no general per-foot allocation,
general contact wrench, articulated load-bearing limb, standing, bracing, fall
arrest, getting up, gait, walking, knowledge admission, or automatic guidance.

The formal ladder remains **5/18 accepted (27.8%)** until BR3B receives its own
clean certification and explicit decision.

## 29. BR3B promotion and certification family — 2026-07-23

BR3B now has a distinct promotion-grade trust family:

- fixed campaign `BR3B_L3_PROMOTION_CAMPAIGN_V1`;
- exact source-inventory, metrics, and evidence-capsule schemas;
- a six-bundle, two-replicate clean campaign operator;
- production bundle receipts;
- a BR3B-specific detached final-report receipt domain; and
- adversarial promotion-contract tests.

The campaign contains only L3.0-L3.2 as milestone programs, totaling 43
assertions per replicate and 86 assertions across six fresh-process capsules.
It permits no supplementary or integrity program to substitute for one of the
three milestone cells.

The detached report schema makes these claims unrepresentable:

- a mechanical carriage rail, hidden pin/lock, or balancing moment;
- raw predicted contact impulse as a general contact wrench;
- per-foot allocation;
- an articulated load-bearing limb;
- standing, bracing, recovery, gait, or walking;
- knowledge admission; and
- automatic creature guidance.

The promotion-contract regression passed 30/30 assertions:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br3b_promotion_contracts\20260723T053026552\report.json
```

This section records certification infrastructure, not a successful campaign.
The formal ladder remains **5/18 (27.8%)** until the operator runs from a clean
commit and an explicit evidence-bound decision accepts the resulting report.

## 30. BR3B clean certification and bounded acceptance — 2026-07-23

The BR3B operator completed from clean source commit
`f5f54a58abae57089b37ab39fdb8b76a2c157219`.

### 30.1 Certified evidence

| Field | Exact value |
|---|---|
| Certification | `br3b_20260723T103240Z_f5f54a58` |
| Campaign | `BR3B_L3_PROMOTION_CAMPAIGN_V1` |
| Programs | 3 / 3 |
| Fresh-process bundles | 6 / 6 |
| Assertions | 86 / 86 |
| Unique target processes | 6 |
| PID recycle events | 0 |
| Source files inventoried | 237 |
| Campaign SHA-256 | `sha256:5409d646a33aa01a81e635c022362bb52bff5be98b98cf993acf077def3c210c` |
| Source-inventory SHA-256 | `sha256:11ddc05761ab144b05015b1b413817f849fe21990513408e15c0708a7e3a633b` |
| Report SHA-256 | `sha256:b3e1a014cf041a8a6ab4569b363c161081dd078ef620323c67076463a0e80986` |
| Detached receipt SHA-256 | `sha256:08cd88607fd461ef32739fc9a367d4cffca5719ef6a44aa4c01c7b7f2022447c` |

Every capsule and receipt survived final readback. Supplementary and integrity
program counts were both zero, so neither could substitute for a milestone
cell.

### 30.2 Decision

Cole's delegated bounded-acceptance instruction was applied through the
separately committed review
`docs/BR3B_L3_MILESTONE_DECISION_REVIEW.md`, pinned at commit
`190e806e59ed69f8ffda963c3d43a1fc886fe5f8` and SHA-256
`sha256:a142f7b606b2327298628c6a5809c5a869a8f0fdbb0cdb6f637337b2b395c4f6`.

Append-only decision
`BR3B_L3_BASIC_LOADED_FOOT_TRUTH_DECISION_V1`, SHA-256
`sha256:f607c2b86599b1bc2ef085ff29819edd736ef161c8e5024916fae8b7d753ea85`,
accepts only the three certified program scopes and verbatim campaign
boundary.

The decision admits zero knowledge entries and authorizes no automatic
creature guidance.

### 30.3 Accepted observations

The bounded milestone accepts:

1. L3.0's exact centered normal-load reconstruction grid for the declared free
   unary pad.
2. L3.1's `34–36 N` loaded shear-breakaway bracket under reconstructed
   `59.6 N` normal support, inside accepted L1 truth.
3. L3.2's predicted contact-pressure migration and `0.21–0.24 m` rocking
   bracket around the analytic `0.2235 m` threshold, including the mirrored
   negative repeat.
4. The explicit force boundary: no physical rail, pin/lock, damping, motor,
   rotation constraint, or hidden balancing moment.

It does not accept a general contact wrench, a per-foot allocator, an
articulated load-bearing limb, support produced by a creature body, terrain or
endurance behavior, standing, bracing, fall arrest, getting up, gait, or
walking.

### 30.4 Decision integrity and ladder state

The dedicated decision contract passed **25/25 assertions**. All three
milestone-decision families passed together:

- programs: 3 / 3;
- assertions: 71 / 71;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_all_milestone_decisions\20260723T054148777\report.json`.

The formal ladder is now **6/18 accepted (33.3%)**. This unlocks construction
and eventual certification of contact-bearing articulated BR6A. It does not
mean any creature has stood, braced, recovered, or walked.

### 30.5 Post-decision regression

The expanded experimental suite passed after the decision was installed:

- programs: 30 / 30;
- assertions: 586 / 586;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br3b_acceptance_full\20260723T054720582\report.json`.

The first released-suite pass correctly exposed one stale compatibility-test
expectation: the allowlisted decision registry now contains BR3B in addition
to BR2.1, BR3A, and BR4. Updating that assertion changed neither the historical
BR1 tuples nor the pinned 62-test report-v2 inventory. The focused test then
passed 32/32, and the complete released suite passed:

- programs: 62 / 62;
- assertions: 1118 / 1118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br3b_acceptance_final\20260723T055727280\report.json`.

## 31. BR3B observation-only knowledge admission — 2026-07-23

BR3B knowledge was admitted as a separate append-only operation after
milestone acceptance. The fixed manifest
`BR3B_L3_KNOWLEDGE_ADMISSION_V1`, SHA-256
`sha256:de68b7ffa37ef1eb74296561f8d64eb85120189d7e802e637d343a81b2103266`,
authorizes exactly three records:

1. `L3.0.loaded_pad_normal_reconstruction.v1`;
2. `L3.1.loaded_pad_shear_breakaway.v1`; and
3. `L3.2.loaded_pad_pressure_rocking.v1`.

Each entry reopens the exact accepted decision, certification report, detached
report receipt, one certified program scope, and both production-attested
replicates. Installed entry SHA-256 identities are:

- L3.0:
  `sha256:662fcc5194d03351a643c5d519a708e3507e052d4a91e10d4367ddca4398d5eb`;
- L3.1:
  `sha256:234db245f839f2fdf91702405704c34373e756e0ab6a91f59411258df3523099`;
  and
- L3.2:
  `sha256:83fb25cc1decb96e9d2a89555dba4916da70358c6c225c0de7e1e23ef636a592`.

The strict BR3B entry schema is byte-pinned at
`sha256:1528c40023e93f03d10ab5964f03d6f0b582605e1113600c2895a7f12c472457`;
the manifest schema is byte-pinned at
`sha256:659022e70f29530a69fe08bd34094e317fb940a9ce3ad3c353f70e9196e01f3a`.

The focused admission contract passed **21/21 assertions**:

- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br3b_knowledge_contract\20260723T060725097\report.json`.

Every entry has:

- `minimal_repair_rules: []`;
- `automatic_application_allowed: false`;
- `automatic_creature_guidance_allowed: false`; and
- an unlock fence requiring both an accepted articulated contact-bearing
  support milestone and a separate guidance decision.

The shared accepted catalog now contains 21 records: one L0 baseline, nine
BR3A observations/constraints, three BR3B observations, and eight BR4
observations. This admission creates no new physical evidence, so the formal
ladder remains **6/18 (33.3%)** and locomotion remains **0% proven**.

Post-admission regression passed:

- experimental programs: 31 / 31;
- experimental assertions: 607 / 607;
- experimental report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br3b_knowledge_full\20260723T060847282\report.json`;
- released programs: 62 / 62;
- released assertions: 1118 / 1118;
- released report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br3b_knowledge\20260723T061458118\report.json`;
- failures, timeouts, and unexpected engine errors: 0.

## 32. BR6A vertical rail-leg implementation checkpoint — 2026-07-23

BR6A's complete implementation question is now populated by three
experimental cells. This checkpoint is deliberately separated from promotion,
certification, acceptance, knowledge admission, and creature guidance.

### 32.1 L4.0 rigid-strut rail oracle

`rail_strut_rig.gd` uses a `Generic6DOFJoint3D` whose X/Z translations and all
rotations are locked while vertical translation remains free. Every linear
motor, angular motor, spring, passive tissue, and controller root-force path is
off.

The paired no-floor/floor result was:

| Cell | Measured result |
|---|---:|
| no-floor velocity change | `-4.900001 m/s` versus `-4.900000 m/s` |
| no-floor reconstructed vertical external load | `-0.000003 N` |
| floor-supported reconstructed load | `29.400002 N` versus `29.4 N` |
| supported contact fraction | `1.000` |
| lateral drift / tilt | zero at reported precision |

This is a rail-scaffold and rigid-geometry oracle. It is not articulated
support.

### 32.2 L4.1 hinged-strut static load curve

The one-link fixture applies equal-and-opposite finite torque through the
sealed command ledger and executor. A separately tagged joint-space
stabilization term holds an otherwise unstable static equilibrium; after
settling, its contribution approaches zero and total torque matches:

\[
\tau =
-L\sin(\theta)
\left(m_{\text{carriage}} + \frac{1}{2}m_{\text{link}}\right)g
\]

Measured settled points were:

| Angle | Applied / analytic torque | Reconstructed support | Maximum angle error |
|---:|---:|---:|---:|
| `0°` | `-0.00000 / 0.00000 N·m` | `29.4000 N` | `0.000000 rad` |
| `15°` | `-3.80465 / -3.80464 N·m` | `29.4000 N` | `0.000000 rad` |
| `30°` | `-7.35000 / -7.35000 N·m` | `29.4000 N` | `0.000000 rad` |
| `45°` | `-10.39447 / -10.39447 N·m` | `29.4000 N` | `0.000000 rad` |

The matched `30°` zero-torque control departed by `1.140038 rad`.

Commissioning exposed and corrected two fixture-integrity hazards:

1. the holding moment must be the equal-and-opposite of the gravitational
   generalized moment; and
2. a full-length link collider plus a distal sphere creates an undeclared
   second floor contact and shifts an automatically derived compound-body
   center of mass.

The accepted experimental fixture recesses the link collider behind the
ordinary distal sphere and pins the declared link COM to its midpoint.

### 32.3 L4.3 two-link rail-leg support

The new support stack is:

```text
body_wrench.gd
  -> vertical_load_allocator.gd
  -> force_to_joint_map.gd
  -> joint_actuator.gd
  -> command_ledger.gd
  -> actuation_executor.gd
  -> rail_leg_rig.gd
  -> external_contact_impulse_reconstructor.gd
```

The V1 allocator regulates only aggregate vertical load. It rate-limits its
output, exposes every clamp cause, has no integral state, and reports
anti-windup whenever saturated. The force mapper accepts only a world-frame
vertical force with zero requested moment and computes exact two-link
J-transpose terms plus declared link-gravity compensation. It refuses rather
than dropping an unsupported moment.

The integrated live fixture produced:

| Measure | Result |
|---|---:|
| static height error | `0.000000 m` |
| static vertical velocity | `0.000000 m/s` |
| static reconstructed support error | `0.00001 N` |
| distal contact fraction | `1.000` |
| crouch depth | `0.09995 m` |
| rise potential-energy gain | `2.44760 J` |
| measured rise joint work | `2.43723 J` |
| declared downward impulse | `1.5 N·s` |
| resulting maximum drop | `0.01147 m` |
| recovery time | `17` physics ticks |
| maximum observed rail tangential load | `16.12362 N` |
| peak requested / applied joint torque | `35.1967 / 35.1967 N·m` |
| actuator saturation | `0` ticks |
| allocator saturation / anti-windup | `1 / 1` ticks |

The rail load is material and visible; therefore this is not free-root
standing. Four execution receipts were matched to the two paired joint
commands on every transition. The controller performed no root rescue, foot
pin, passive-tissue operation, or built-in joint-motor operation.

Preflight classified the declared `0.700 m` baseline as feasible, requiring a
peak static torque of `6.37718 N·m` inside the `50 N·m` experimental envelope.
It separately returned:

- `HEIGHT_TARGET_UNREACHABLE` for `1.2 m`; and
- `ACTUATOR_STATIC_TORQUE_INFEASIBLE` for a `0.1 N·m` actuator.

### 32.4 Implementation evidence and boundary

The combined BR6A implementation grid passed:

- programs: 3 / 3;
- assertions: 40 / 40;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br6a_implementation_grid\20260723T065031791\report.json`.

The complete post-implementation experimental regression also passed:

- programs: 34 / 34;
- assertions: 647 / 647;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_br6a_implementation_full_final\20260723T065347557\report.json`.

The immutable released suite remained exactly 62 programs and passed:

- programs: 62 / 62;
- assertions: 1,118 / 1,118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0;
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br6a_implementation\20260723T070104096\report.json`.

This completes the implementation work named by the BR6A build/test/gate
section: freefall honesty, one-link static truth, two-link static support,
crouch/rise work, vertical-impulse recovery, unreachable height, insufficient
actuator, visible rail reaction, and absence of forbidden assistance.

It does **not** formally accept BR6A. A BR6A-specific promotion campaign,
source inventory, evidence capsules, certification report, detached
attestation domain, clean campaign, and explicit milestone decision do not yet
exist. The formal ladder therefore remains **6/18 accepted (33.3%)**.

The exact claim boundary is rail-constrained articulated vertical support.
There is still no accepted per-foot allocation, free-root standing, balance,
bracing, fall arrest, getting up, gait, walking, knowledge entry, or automatic
creature guidance.

## 33. BR6A promotion and certification family — 2026-07-23

BR6A now has a distinct promotion-grade trust family:

- fixed campaign `BR6A_L4_PROMOTION_CAMPAIGN_V1`;
- exact campaign, source-inventory, metrics, and capsule schemas;
- a three-program, two-replicate clean campaign operator;
- generic production bundle receipts around BR6A-specific inner artifacts;
- a BR6A-specific detached final-report receipt domain; and
- adversarial promotion-contract tests.

The campaign includes exactly:

| Program | Cell | Assertions per replicate |
|---|---|---:|
| `BR6A_L4_0_RIGID_STRUT_RAIL_V1` | L4.0 | 12 |
| `BR6A_L4_1_HINGED_STRUT_RAIL_V1` | L4.1 | 12 |
| `BR6A_L4_3_RAIL_LEG_SUPPORT_V1` | L4.3 | 16 |

The complete clean campaign therefore requires 3/3 programs, two fresh target
processes per program, 6/6 production-attested bundles, and 80/80 assertions.
There are no supplementary or integrity roles that can substitute for a
milestone cell.

The report schema can positively represent
`articulated_rail_constrained_vertical_support: true`. It simultaneously
requires:

- the vertical rail and its locked/free axes to remain explicit;
- every rail motor and spring to remain off;
- both built-in hinge motors to remain off;
- no passive tissue, foot pin, or controller root rescue;
- ordinary distal contact and aggregate external-load reconstruction;
- material rail reaction to be retained;
- per-foot allocation to remain unavailable;
- free-root standing and balance to remain false; and
- bracing, fall arrest, getting up, and walking to remain false.

The focused promotion-contract suite passed **30/30 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br6a_promotion_contracts\20260723T071354294\report.json
```

The read-only preflight passed without running physics or writing evidence:

```text
BR6A preflight=pass non_promotable=true programs=3 source_files=265
```

This section records certification infrastructure, not certification or
acceptance. The operator still requires a clean committed source, a complete
fresh-process campaign, final readback, and detached report authentication.
Only after that evidence exists may a separate explicit milestone decision be
prepared. The formal ladder remains **6/18 accepted (33.3%)**.

## 34. BR6A clean certification and bounded acceptance — 2026-07-23

The clean committed BR6A source at
`c0e725496c5daf6b55bab38b1485920e1d993ff8` completed the full promotion
campaign:

- certification: `br6a_20260723T121533Z_c0e72549`;
- programs: 3 / 3;
- fresh-process production-attested bundles: 6 / 6;
- assertions: 80 / 80;
- unique target processes: 6;
- PID recycle events: 0;
- supplementary substitutions: 0;
- integrity substitutions: 0; and
- final bundle, receipt, metrics, and source-inventory readback: 6 / 6.

The exact retained identities are:

- campaign:
  `sha256:3f79a2c2a90970286dfb3424745c29ff1a57d324079544174fa1aa88ffd0bfd6`;
- source inventory:
  `sha256:6a6d946683fd08a3f36d94e3b32d1052312b37d0d6bdb02e1ab7eb3b19933cd7`;
- report:
  `sha256:431a98cbf727d09885378ad094efae105468c47b41c5df536b13e18c5855e42e`;
  and
- detached report receipt:
  `sha256:1f86dca2a62b10e7a215b9b8791692061eddb65dcdfed8c7a560f83659d4fba5`.

The report and receipt hashes were independently recomputed. The receipt binds
the exact 15,763 report bytes, certification ID, source commit, campaign hash,
production key, and BR6A-specific report-attestation domain.

Cole's delegated acceptance was applied only after separately committing
[the bounded decision review](BR6A_L4_MILESTONE_DECISION_REVIEW.md).
Append-only decision
`BR6A_L4_VERTICAL_RAIL_LEG_SUPPORT_DECISION_V1` accepts only:

1. the L4.0 rigid-strut rail freefall/support oracle;
2. the L4.1 one-hinge static holding-torque curve and zero-torque control; and
3. the L4.3 two-link rail support, crouch/rise, declared impulse recovery,
   material rail reaction, saturation, and exact infeasibility controls.

The decision contract makes L4.2 unaccepted and preserves the report's
verbatim boundary. It admits no knowledge, authorizes no automatic guidance,
provides no per-foot allocation, and establishes no free-root standing,
balance, bracing, fall arrest, getting up, gait, or walking.

The new decision test passed 24/24 assertions. All four earlier decision
families passed beside it for a combined 4/4 programs and 95/95 assertions:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_milestone_decisions_final\20260723T073025109\report.json
```

The formal evidence ladder is now **7/18 accepted (38.9%)**. This is
articulated rail-constrained vertical support at the exact certified scope,
not “38.9% walking.” The next build must preserve the rail as an explicit
material scaffold until each released root degree of freedom is independently
controlled and certified.

## 35. BR6A observation-only knowledge admission — 2026-07-23

Three BR6A observations were admitted through the separate append-only
manifest `BR6A_L4_KNOWLEDGE_ADMISSION_V1`:

| Cell | Entry | Exact entry SHA-256 |
|---|---|---|
| L4.0 | `L4.0.rigid_strut_vertical_rail_support.v1` | `sha256:aab12b2d61425f97ec0c1036ec3b62f1077e863fa60297465dd603e6173ec321` |
| L4.1 | `L4.1.hinged_strut_static_torque_curve.v1` | `sha256:d418a227c1f9d396c4752892f0ad7394f790e9c7dc96910a193c5d18b837efdf` |
| L4.3 | `L4.3.two_link_vertical_rail_support.v1` | `sha256:1d0589390d2a2e8b276593677bb2e05c3b372b652da30901d5eda7af8423640c` |

Each entry:

- binds the exact accepted BR6A decision bytes;
- binds the certified report and detached receipt;
- retains both production-attested program replicates;
- preserves the exact program claim scope and full certification boundary;
- carries an empty `minimal_repair_rules` array;
- forbids automatic application and creature guidance; and
- requires a separately accepted free-root support-control milestone plus a
  separate guidance decision before any future consumer unlock.

The useful observations are now queryable without becoming controller policy:

1. a vertically unlocked rail supplies no vertical support by itself;
2. the one-hinge static holding-torque curve agrees with its analytic oracle
   and the zero-torque control fails; and
3. the two-link leg carries aggregate weight, performs the declared
   crouch/rise, accounts for joint work and potential energy, recovers the
   declared downward impulse, and refuses exact infeasibility controls.

The material rail reaction, aggregate-only load reconstruction, missing L4.2,
and every free-root standing, balance, bracing, recovery, gait, and walking
non-claim remain explicit.

The BR6A knowledge contract passed 21/21 assertions after live reverification
of the decision, report, detached receipt, all six capsules, and all installed
entry bytes:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br6a_knowledge_final\20260723T073856294\report.json
```

All four certification-backed knowledge families then passed together at
4/4 programs and 85/85 assertions against the expanded catalog:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_knowledge_contracts_24\20260723T074111360\report.json
```

The shared accepted catalog now contains **24 observation-only entries**:
one L0 baseline, nine BR3A entries, three BR3B entries, eight BR4 entries, and
three BR6A entries. Knowledge admission does not change the formal ladder,
which remains **7/18 accepted (38.9%)**, and it authorizes no automatic
creature guidance.

## 36. BR7 planar multi-contact stance implementation checkpoint — 2026-07-23

BR7 now has five commissioned implementation cells:

| Cell | Purpose | Assertions |
|---|---|---:|
| BR7.0 | Exact two-contact vertical-force and pitch-moment allocation | 9 |
| BR7.1 | Coulomb-friction, pulling-contact, and single-support rejection | 8 |
| BR7.2 | Static/capture support segment plus support-set transition events | 10 |
| BR7.3 | Live two-leg planar height/pitch stance, impulse recovery, and support loss | 13 |
| BR7.4 | Digest, hidden-assistance, false-measurement, and claim containment | 12 |

The combined commissioning grid passed **5/5 programs and 52/52 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br7_commissioning\20260723T080834597\report.json
```

### 36.1 Exact planar allocator and support geometry

The V2 planar allocator solves:

\[
\sum_i F_{x,i}=F_x^*
\]

\[
\sum_i F_{y,i}=F_y^*
\]

\[
\sum_i x_iF_{y,i}=M_z^*
\]

for two declared supports. Horizontal force is distributed in proportion to
nonnegative normal load. The output is admitted only when each unilateral
normal bound and Coulomb cone is satisfied. The allocator never clamps an
infeasible request into a plausible result.

Commissioned arithmetic includes:

- `98 N` and zero moment splitting exactly to `49/49 N`;
- `100 N` and `+20 N·m` splitting exactly to `30/70 N`;
- the mirrored `-20 N·m` request splitting to `70/30 N`;
- a `+60 N·m` request failing because it requires a pulling left contact;
- friction-cone overflow failing at both contacts;
- one-support moment mismatch failing with an exact residual; and
- zero-support and negative-total-normal requests failing closed.

The support-segment cell computes both the projected static COM margin and a
linear capture-point margin. Mirrored outside-segment COM cases predict
mirrored loss directions. One remaining support degenerates honestly to a
zero-width point rather than being treated as a finite foot polygon.

### 36.2 Live two-leg planar fixture

The live BR7.3 fixture contains:

- one root plus two mirrored two-link legs;
- four ordinary passive `HingeJoint3D` constraints;
- four finite paired explicit joint actuators;
- two ordinary distal sphere/floor contacts;
- no built-in motor, joint limit, passive tissue, foot pin, or root rescue;
- a strict support-wrench allocator and explicit feasibility governor;
- whole-system linear-momentum reconstruction of aggregate vertical support;
- whole-system angular-momentum reconstruction of the external sagittal
  pitch wrench; and
- one declared pitch impulse followed later by one declared right-contact
  removal.

The root is **not free in 3D**. A `Generic6DOFJoint3D` guide:

- releases in-plane X and Y translation;
- releases pitch about Z;
- locks out-of-plane Z translation;
- locks roll and yaw; and
- has every motor and spring disabled.

That guide is an explicit material scaffold even though it performs no
commanded work. The positive scope is therefore scaffold-constrained planar
height/pitch stance, not general standing.

The calibrated run produced:

| Measurement | Result |
|---|---:|
| static left/right contact fraction | `1.0 / 1.0` |
| maximum static height error | `0.00000037 m` |
| maximum static pitch error | `0 rad` at recorded precision |
| maximum static aggregate-support error | `0.00005484 N` |
| maximum realized vertical-wrench residual | `0.00016755 N` |
| maximum realized pitch-wrench residual | `0.00005659 N·m` |
| allocation force/moment residual | `0 / 0` at recorded precision |
| peak requested/applied actuator torque | `4.20287 / 4.20287 N·m` |
| actuator or feasibility-governor saturation | `0 / 0` |
| declared positive pitch impulse | `0.03 N·m·s` |
| maximum signed pitch excursion | `+0.0112352 rad` |
| recovery dwell reached | `25` ticks |
| support-loss event count | `1` |
| support-loss event tick | `301` |
| fail-closed response | `DECLARE_INFEASIBLE_STOP` |

The right support was disabled at tick 300. Once Jolt exposed the changed
bearing set at tick 301, the supervisor emitted one `SUPPORT_LOST` event.
The remaining left point could not realize the independently requested pitch
moment, so the allocator retained `PITCH_MOMENT_RESIDUAL` and the controller
stopped. It did not redistribute a fictional measured load, pin the remaining
foot, rescue the root, or continue on an infeasible wrench.

The controller calibration itself retained an important causal lesson. The
initial high-bandwidth pitch and joint derivative gains were unstable after
root pitch was released because their one-step discrete response exceeded the
fixture's low reflected rotational inertia. The final commissioned gains are
explicitly lower-bandwidth and required no saturation. This is a fixture
calibration, not a universal creature gain schedule.

### 36.3 Evidence containment and regression

The digest-bound analyzer:

- requires the out-of-plane guide to be declared and exact;
- rejects hidden motors, limits, passive capacity, root force, and foot pins;
- rejects contract mutation after sealing;
- rejects pre-loss allocation infeasibility or arithmetic residual;
- rejects missing/wrong-sign disturbance response;
- rejects missing, duplicated, or late support-loss evidence;
- rejects any claim that commanded left/right shares are measured loads; and
- returns a fixed non-claim list covering free 3D standing, unconstrained
  balance, per-foot measured allocation, bracing, fall arrest, getting up,
  gait, walking, and automatic creature guidance.

The complete current experimental inventory passed in bounded groups:

- trust/decision/knowledge/BR7: 19 programs, 379 assertions;
- L1: 9 programs, 181 assertions;
- L2: 8 programs, 131 assertions;
- L3: 3 programs, 43 assertions; and
- L4: 3 programs, 40 assertions.

That totals **42/42 programs and 774/774 assertions**, with no failure,
timeout, or unexpected engine error in the completed group reports. The
immutable released suite separately remained exact and green:

- programs: 62 / 62;
- assertions: 1,118 / 1,118;
- failures: 0;
- timeouts: 0;
- unexpected engine errors: 0; and
- report:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_report_v2_regression_br7\20260723T082346180\report.json`.

BR7 is **implemented and commissioned only**. It has no promotion campaign,
source inventory, evidence capsule family, certification report, detached
attestation domain, clean campaign, milestone decision, knowledge admission,
or guidance consumer. The formal ladder therefore remains **7/18 accepted
(38.9%)**.

The exact future promotion scope must remain the analyzer's verbatim boundary:
scaffold-constrained planar two-contact height/pitch stance and support-loss
detection. It must not be renamed free 3D standing, per-foot measured load
allocation, bracing, fall arrest, getting up, gait, or walking.

## 37. BR7 promotion and certification boundary — 2026-07-23

BR7 now has a separate promotion-grade family:

- fixed five-program campaign `BR7_PLANAR_PROMOTION_CAMPAIGN_V1`;
- exact source-inventory, metrics, capsule, report, and detached-receipt
  schemas;
- a clean-source PowerShell operator;
- production bundle receipts plus a BR7-specific final-report domain; and
- a 32-assertion adversarial promotion-contract test.

The role split is deliberate:

| Role | Programs | Assertions per replicate | Replicated assertions |
|---|---:|---:|---:|
| milestone, BR7.0–BR7.3 | 4 | 40 | 80 |
| supplementary | 0 | 0 | 0 |
| integrity, BR7.4 | 1 | 12 | 24 |
| total | 5 | 52 | 104 |

The report requires 10 fresh target-process invocations and 10
production-attested capsules. Both raw replicates remain retained, and
cherry-picking is forbidden. BR7.4 can make a campaign fail but cannot replace
one of the four milestone programs.

The schema makes the exact positive result representable:
scaffold-constrained planar height/pitch stance and support-loss detection.
It makes free 3D standing, unconstrained balance, measured per-foot load
allocation, guide erasure, bracing, fall arrest, getting up, gait, walking,
knowledge admission, and automatic guidance unrepresentable.

The promotion-contract test passed 32/32:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br7_promotion_contracts\20260723T083846608\report.json
```

This infrastructure does not itself advance the formal ladder. A clean
completed campaign and an explicit evidence-bound decision are still
required.

## 38. BR7 clean certification and bounded acceptance — 2026-07-23

Clean certification `br7_20260723T134427Z_91a160b9` completed the exact
five-program BR7 campaign from source
`91a160b99dce9e7d9c33424c8bdde4b7bd1e3c4d`. All ten fresh-process bundles,
all ten production receipts, and all 104 assertions passed and survived final
readback:

| Evidence role | Programs | Assertions |
|---|---:|---:|
| milestone, BR7.0–BR7.3 | 4 / 4 | 80 / 80 |
| supplementary | 0 / 0 | 0 / 0 |
| integrity, BR7.4 | 1 / 1 | 24 / 24 |
| total | 5 / 5 | 104 / 104 |

The exact evidence identities are:

- campaign:
  `sha256:83868168d51f2d0f30f98305d024571e5c6fd02809b4fbd8f2bd4af74cb26cf5`;
- source inventory:
  `sha256:d37c28fc98caa552d6f6bf639d33ce3934403df4ca97046e4d708df1d39147a0`;
- report:
  `sha256:2cf0eed0bd1a27ff3c4f93fab384e0813834143ac4fe0dc2f67cb5b0f7d2087f`;
  and
- detached receipt:
  `sha256:5e89081ca74e5bfc85205a8265a10a80469927e129bd3352e6422d9177b20257`.

An earlier clean attempt,
`br7_20260723T134223Z_74a4fb06`, completed all ten program invocations but
failed closed before final readback because one operator guard still expected
the cloned six-invocation/80-assertion totals. It issued only
`br7_certification_failure.json`, no certification report. The guard was
corrected and committed; none of that failed attempt was reused by the
successful campaign.

After the separately committed review, append-only decision
`BR7_PLANAR_MULTI_CONTACT_STANCE_DECISION_V1`, byte-pinned at
`sha256:ecd2528d6d766e137b6f69272054a455f047d97befd268ca2989399df3b9aa41`,
accepts only BR7.0–BR7.3. BR7.4 remains integrity-only and cannot substitute
for physical evidence.

The positive conclusion is deliberately exact:
scaffold-constrained planar height/pitch stance and support-loss detection
exist in the certified fixture. The decision preserves:

- the unpowered guide that locks out-of-plane translation, roll, and yaw;
- two ordinary distal contacts and four paired finite joint actuators;
- aggregate-only external support and pitch-wrench reconstruction;
- command shares as commands, not measured per-foot loads;
- the declared positive pitch impulse and right-support removal; and
- zero knowledge admission and zero automatic guidance authority.

All five certification-backed decision tests passed together at **5/5
programs and 122/122 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_milestone_decisions_br7\20260723T085711119\report.json
```

The formal ladder is now **8/18 accepted (44.4%)**. Free 3D standing,
unconstrained balance, bracing, fall arrest, getting up, gait, and walking
remain unproved.

## 39. BR7 observation-only knowledge admission — 2026-07-23

Four BR7 observations were admitted through the separate append-only manifest
`BR7_PLANAR_KNOWLEDGE_ADMISSION_V1`:

| Cell | Entry | Exact entry SHA-256 |
|---|---|---|
| BR7.0 | `BR7.0.planar_contact_wrench_allocation.v1` | `sha256:cccbbe1342ea4eb836efc15a04b6ec41108874eb15d2ec87f07b1f78acbca074` |
| BR7.1 | `BR7.1.planar_friction_feasibility.v1` | `sha256:d32d39c3d9a0119db090e0ad69a316446e2bbd3bd242a30fe2ce71404806e8e3` |
| BR7.2 | `BR7.2.planar_support_segment_and_loss.v1` | `sha256:2b6d67d46afc6f79a133fdf6d9499aca88b9e601604d4d50e85d67324c34510b` |
| BR7.3 | `BR7.3.scaffolded_planar_two_leg_stance.v1` | `sha256:07a8469b26d52cc1edfa55dc4341ed6f038cb42adaf3b1cd868f35fb3d0e2a35` |

Each entry:

- reopens the exact accepted BR7 decision, report, detached receipt, and both
  production-attested program replicates;
- preserves the exact program scope and full certification boundary;
- carries an empty `minimal_repair_rules` array;
- forbids automatic application and automatic creature guidance; and
- requires an accepted free-3D-stance milestone, validated per-contact load
  measurement, and a separate guidance decision before any future consumer
  unlock.

BR7.4 remains integrity-only containment and is structurally ineligible for
knowledge admission. The entries also preserve that allocator shares are
commands rather than measurements, the out-of-plane guide is material, and
aggregate support/pitch reconstruction cannot identify either foot's load.

The BR7 knowledge contract passed 23/23 assertions. All five
certification-backed knowledge families passed together at **5/5 programs and
108/108 assertions** against the expanded catalog:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_knowledge_contracts_28\20260723T091150275\report.json
```

The shared accepted catalog now contains **28 observation-only entries**.
Knowledge admission does not advance the formal ladder beyond **8/18
(44.4%)**, does not authorize guidance, and does not establish free 3D
standing or locomotion.

## 40. BR8 early loss-of-viability detection implementation checkpoint — 2026-07-23

BR8 now has five commissioned implementation cells:

| Cell | Purpose | Assertions |
|---|---|---:|
| BR8.0 | Exact static-margin, support-count, and impact-deadline oracles | 10 |
| BR8.1 | Linear capture margin, boundary clock, mirroring, and delayed negative control | 8 |
| BR8.2 | Immediate escalation plus one-state-at-a-time hysteretic release | 9 |
| BR8.3 | Live passive impulse, slowly tilting platform, and disappearing-support matrix | 13 |
| BR8.4 | Digest, assistance, causal-channel, and claim containment | 18 |

The sealed commissioning suite passed **5/5 programs and 58/58 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br8_commissioning_sealed\20260723T093110303\report.json
```

### 40.1 Detector and supervisor boundary

`brace_detector.gd` consumes only the declared planar support interval,
bearing-support count, center-of-mass position/velocity, body clearance,
vertical velocity, gravity, and timing thresholds. It emits:

- static and linear-capture margins with loss directions;
- time-to-boundary and, when airborne, time-to-impact;
- a reaction deadline with an explicit viability bit;
- decomposed `STAND`, `PRECARIOUS`, or `BRACE` evidence; and
- the fixed delayed classification `REACTION_TOO_LATE`.

The detector applies no force or torque. `brace_supervisor.gd` escalates
immediately, but de-escalates by only one state after three consecutive
safe-release samples. Every transition pins its evidence digest, reason,
margins, deadline, and reaction viability. It issues no brace or step command.

The digest-bound positive boundary is therefore early loss-of-viability
**detection**, not successful bracing. BR8.0–BR8.3 are milestone cells. BR8.4
is integrity-only and cannot substitute for physical evidence.

### 40.2 Live passive disturbance matrix

The BR8.3 fixture creates three fresh Godot/Jolt worlds. Every world retains an
explicit unpowered planar guide that locks out-of-plane translation, roll, and
yaw while leaving sagittal translation and pitch free. No guide motor or
spring, brace controller, step controller, foot pin, root rescue, creature
edit, or automatic guidance exists.

Measured results:

| Scenario | Measured detector result |
|---|---|
| central horizontal impulse | the body remained `STAND` for 60 pre-impulse samples; one `3.4 N·s` impulse produced `1.36988 m/s`; BRACE fired on tick 60 from `CAPTURE_MARGIN_BRACE` while static margin remained `0.24554 m`, capture margin was `-0.03218 m`, and reaction remained viable |
| slowly tilting platform | first PRECARIOUS at tick 160; first BRACE at tick 192 and platform angle `0.46077 rad`; static margin remained `0.04607 m`; measured static exhaustion did not occur until tick 221 |
| disappearing right support | both real supports were observed for 90 samples; the declared removal at tick 90 was observed on tick 90; the supervisor entered BRACE on that same tick with one support and reason `STATIC_MARGIN_EXHAUSTED` |

The support-removal result also preserves a necessary distinction:
`reaction_viable=false` can coexist with the dominant physical cause
`STATIC_MARGIN_EXHAUSTED`. `REACTION_TOO_LATE` is reserved for the delayed
negative control whose support is not already exhausted; it does not overwrite
a more specific observed support-set failure.

### 40.3 Current gate state

BR8 is implemented and commissioned, but it has no promotion campaign, source
inventory, evidence-capsule family, certification report, detached attestation
domain, clean fresh-process campaign, milestone decision, or knowledge
admission. The formal ladder therefore remains **8/18 accepted (44.4%)**.

The exact future positive scope must remain the analyzer's verbatim boundary:
early loss-of-viability detection in the passive planar-scaffold matrix. It
proves no executed existing-contact brace, catch step, free 3D standing,
unconstrained balance, fall arrest, getting up, gait, walking, or automatic
creature guidance.

## 41. BR8 promotion and certification boundary — 2026-07-23

BR8 now has a separate promotion-grade trust family:

- fixed five-program campaign
  `BR8_BRACE_DETECTION_PROMOTION_CAMPAIGN_V1`;
- exact source-inventory, metrics, capsule, report, and detached-receipt
  schemas;
- a clean-source PowerShell operator;
- production bundle receipts plus a BR8-specific final-report domain; and
- a 32-assertion adversarial promotion-contract test.

The fixed role accounting is:

| Role | Programs | Assertions per replicate | Replicated assertions |
|---|---:|---:|---:|
| milestone, BR8.0–BR8.3 | 4 | 40 | 80 |
| supplementary | 0 | 0 | 0 |
| integrity, BR8.4 | 1 | 18 | 36 |
| total | 5 | 58 | 116 |

The report requires ten fresh target-process invocations and ten
production-attested capsules. Both raw replicates remain retained, ordered
assertion labels must reconcile, and cherry-picking is forbidden.

The schema makes only early loss-of-viability detection representable. It
requires the passive impulse, slowly tilting platform, disappearing support,
delayed negative control, material planar guide, observation-only detector,
and observation-only supervisor. It makes an executed brace, catch step, new
support, free 3D standing, fall arrest, walking, accepted knowledge, and
automatic guidance unrepresentable.

The promotion-contract test passed 32/32:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br8_promotion_contracts\20260723T094027599\report.json
```

This infrastructure does not itself advance the formal ladder. A clean
completed campaign, detached production report receipt, and explicit bounded
decision remain required.

## 42. BR8 clean certification and bounded acceptance — 2026-07-23

The clean certification operator completed the complete fixed campaign at
source `90b2c1ce6ebefc24edf7998298ca2bbb861dc57c`:

- certification `br8_20260723T144351Z_90b2c1ce`;
- 5/5 fixed programs and 10/10 production-attested fresh target processes;
- 80/80 milestone assertions from BR8.0–BR8.3;
- 36/36 integrity assertions from BR8.4;
- 116/116 total assertions with zero process recycling;
- report
  `sha256:c7b51fd857816450577afa3973e6397f48e6b4a1afe47f006fdef95f8c9754d7`;
  and
- detached receipt
  `sha256:5e27523e4fb26479ec3147e3f4e13badd035495e332b599e38a5ce261ec217ec`.

After a separately committed bounded review, append-only decision
`BR8_EARLY_LOSS_OF_VIABILITY_DETECTION_DECISION_V1` accepts only the exact
BR8.0–BR8.3 program scopes and the certification report's verbatim claim
boundary. BR8.4 remains integrity-only. The decision schema and record are
byte-pinned in `milestone_decision_registry.gd`; 28 direct BR8 decision
assertions and the complete 150-assertion seven-decision regression passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br8_decision\20260723T095459720\report.json
```

The material unpowered Generic6DOF planar guide remains controlling. Detector
and supervisor output remains observation-only. Acceptance therefore proves
no executed existing-contact brace, catch step, new support contact, free 3D
standing, unconstrained balance, fall arrest, getting up, gait, walking,
accepted BR8 knowledge, or automatic creature guidance.

The formal ladder is now **9/18 accepted (50.0%)**. BR8 knowledge admission is
eligible only as a later append-only operation and must preserve empty repair
rules and zero guidance authority.

## 43. BR8 observation-only knowledge admission — 2026-07-23

A separate append-only operation admitted exactly four BR8 milestone
observations:

- BR8.0 static-margin and impact-deadline classification;
- BR8.1 linear-capture margin, loss direction, and boundary clock;
- BR8.2 hysteretic `STAND` / `PRECARIOUS` / `BRACE` observation state; and
- BR8.3 passive impulse, slow-tilt, and support-removal detection.

BR8.4 remains integrity-only and produced no entry. Each admitted observation
reopens the exact accepted decision, certification report, detached report
receipt, and both production-attested bundles for its one program. The generic
knowledge verifier dispatches the BR8 schema through its owning contract.

All four entries have:

- `minimal_repair_rules: []`;
- `automatic_application_allowed: false`;
- `automatic_creature_guidance_allowed: false`; and
- an explicit unlock fence requiring accepted BR9 existing-contact bracing, a
  validated creature-guidance consumer, and a separate guidance decision.

The BR8 contract passed 23/23 adversarial assertions:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br8_knowledge_contract\20260723T100429109\report.json
```

The shared catalog now contains **32 observation-only entries**. Knowledge
admission does not advance the formal ladder beyond **9/18 (50.0%)** and does
not turn detector state `BRACE` into a physical brace, catch step, fall arrest,
getting up, gait, walking, creature edit, or automatic guidance permission.

## 44. BR9 existing-contact planar brace implementation checkpoint — 2026-07-23

BR9 now has a strict five-cell experimental implementation:

| Cell | Bounded result | Assertions |
|---|---|---:|
| BR9.0 | Digest-bound controller arithmetic, mirrored momentum arrest, rate-limited redistribution, explicit residuals, and stable-dwell handoff | 9 |
| BR9.1 | Reserve, friction, existing-contact, detector-state, finiteness, strict-field, monotonic-tick, and delayed-reaction refusal | 9 |
| BR9.2 | Controller-to-force-map-to-finite-paired-actuator-to-ledger-to-executor-to-receipt chain, including a rejected forged root-force operation | 7 |
| BR9.3 | Fresh paired no-brace/control Godot-Jolt worlds with one declared pitch impulse and a first-post-observation active brace | 14 |
| BR9.4 | Digest, assistance, timing, contact-set, measurement, actuator-identity, result-quality, and claim containment | 21 |

The complete commissioned family passed **5/5 programs and 60/60
assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br9_commissioning_final\20260723T103206069\report.json
```

The full experimental estate then passed **58/58 programs and 1,057/1,057
assertions** with zero failures, timeouts, or unexpected engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_experimental_with_br9\20260723T103358028\report.json
```

The released regression initially exposed one stale assertion that still
expected the milestone registry to end at BR6A. Its expectation was extended
to the already accepted BR7 and BR8 records without changing the pinned
62-path BR1 v2 inventory or its assertion count. The final released suite
passed **62/62 programs and 1,118/1,118 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_released_after_br9_final\20260723T104723635\report.json
```

The physical BR9.3 pair is bound to experiment digest
`sha256:619aef1ea384b6dc8389eaba7f51d4fe06a083e97447e3b3620bf0768d78a2f5`
and finite-actuator digest
`sha256:8d8aa9aba0050c09628a2182d2c6319056a4bcb94746d0e34c7090ec49d6522a`.
Both worlds received the same `0.05 N·m·s` pitch impulse. The active brace
began at tick 121, exactly one observation after the tick-120 impulse, issued
119 commands, and entered `STABILIZE` only after its complete stable dwell at
tick 133.

Measured paired results were:

| Metric | No-brace control | Existing-contact brace |
|---|---:|---:|
| Post-impulse angular momentum | `0.0593018 kg·m²/s` | `0.0593018 kg·m²/s` |
| Tick-150 angular momentum | `0.0145636 kg·m²/s` | `-0.0006916 kg·m²/s` |
| Absolute angular-momentum area | `0.0136412 kg·m²` | `0.0020423 kg·m²` |
| Maximum pitch excursion | `0.0198954 rad` | `0.0054408 rad` |
| Left/right existing-contact fraction | `1.0 / 1.0` | `1.0 / 1.0` |

The brace therefore reduced angular-momentum area to **14.97%** of control
and peak pitch excursion to **27.35%** of control. Its maximum commanded
normal-load rate was `217.307 N/s` inside the sealed `240 N/s` ceiling,
maximum reconstructed-moment residual was `0.940633 N·m` inside the `5 N·m`
gate, maximum applied joint torque was `5.06939 N·m` inside the `75 N·m`
structural boundary, and no actuator saturated.

This is genuine executed physical bracing, but its positive scope is narrow:
**scaffold-constrained planar existing-contact pitch arrest**. The BR7
material guide still removes out-of-plane translation, roll, and yaw. The
left/right contact values are commands, not measured per-foot loads.
No root force, foot pin, new support contact, catch step, creature edit, or
automatic guidance exists in the fixture.

BR9 remains an experimental commissioning result. Section 45 now supplies its
promotion-grade bundle/report/attestation family, but no clean replicated
certification, milestone decision, or accepted knowledge entry yet exists. The
formal ladder therefore remains **9/18 accepted (50.0%)**. This checkpoint
establishes no free-3D bracing or standing, articulated-limb generality, fall
arrest, getting up, gait, or walking.

## 45. BR9 promotion and certification boundary — 2026-07-23

ADR-010 creates a family separate from BR7 stance and BR8 observation:

- campaign `sporespore.lab.br9_existing_contact_brace_promotion_campaign.v1`;
- metrics `sporespore.lab.br9_existing_contact_brace_evidence_metrics.v1`;
- capsule `sporespore.lab.br9_existing_contact_brace_evidence_capsule.v1`;
- report `sporespore.lab.br9_certification_report.v1`; and
- detached receipt
  `sporespore.lab.br9_certification_report_attestation.v1`.

The fixed campaign contains BR9.0–BR9.3 as milestone programs and BR9.4 as an
integrity-only program. Two fresh-process replicates require ten
production-attested bundles and exactly:

| Role | Programs | Assertions per replicate | Campaign assertions |
|---|---:|---:|---:|
| Milestone | 4 | 39 | 78 |
| Supplementary | 0 | 0 | 0 |
| Integrity | 1 | 21 | 42 |
| Total | 5 | 60 | 120 |

The report schema makes the material guide, already-bearing contact set,
paired no-brace control, first-post-impulse command timing, command-not-
measurement semantics, no-new-contact boundary, zero actuator saturation,
aggregate momentum reconstruction, and lack of guidance machine-readable.
It cannot represent a catch step, free-3D brace, free-3D standing, fall
arrest, getting up, walking, accepted knowledge, or automatic guidance.

The 33-assertion adversarial promotion suite passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br9_promotion_contracts\20260723T105821155\report.json
```

The operator is
`scripts/run_br9_existing_contact_brace_certification.ps1`; its runbook is
`docs/BR9_EXISTING_CONTACT_BRACE_CERTIFICATION_OPERATOR.md`. It contains no
decision or knowledge-admission switch. Promotion infrastructure alone does
not advance the ladder: BR9 remains unaccepted and the formal total remains
**9/18 (50.0%)** until a complete clean campaign and separate bounded decision
exist.

## 46. BR9 clean certification and decision review — 2026-07-23

The clean production operator completed certification
`br9_20260723T160129Z_4023e51f` at exact source commit
`4023e51f00030abc6c65574015f37c15265509f0`.

The campaign retained:

- 5/5 programs;
- 10/10 fresh-process, production-attested bundles;
- 10 unique target process IDs with zero PID reuse;
- 78/78 BR9.0–BR9.3 milestone assertions;
- 42/42 BR9.4 integrity assertions; and
- 120/120 assertions overall.

The certification report is:

```text
LabEvidence/BR9/br9_20260723T160129Z_4023e51f/br9_certification_report.json
sha256:243312f7c9de378daa8ea7382a50c3148261f367141b6df0e0becd728b3a0cde
```

Its separately attested receipt is:

```text
LabTrust/v1/br9_certification_reports_v1/receipts/04fc817d756beace9f3d6ffbe99a3887a32de090ffaf5cab087db39ad3822398.json
sha256:0f3bfc904cd23241a3daee3d3d36e70f73982d058d315333e2df22615690a97d
```

The source inventory closes 338 files at
`sha256:5c9cad190ed2f5305d0424219d6f156fdf60f52846134b99164b8836cdce59fe`.
The campaign identity is
`sha256:81bbeeeeaefb075954b7384d78d42c49745b154ed1c39f11c3e833ab282b4f19`.

`docs/BR9_EXISTING_CONTACT_BRACE_MILESTONE_DECISION_REVIEW.md` recommends
accepting only the exact BR9.0–BR9.3 scopes. BR9.4 remains integrity-only.
The material planar guide, two already-bearing contacts, paired no-brace
control, first-post-impulse command timing, finite paired actuators,
command-not-measurement boundary, aggregate-only external moment
reconstruction, and no-new-contact limit remain controlling.

The review recommends no knowledge admission and no automatic creature
guidance. Until the separate append-only decision is installed, the formal
ladder remains **9/18 accepted (50.0%)**.

## 47. BR9 bounded milestone acceptance — 2026-07-23

Cole's standing delegated-acceptance instruction and the bounded
recommendation in commit `6b6347b406ade813106759a330815d7534d72d85`
authorize the append-only decision
`BR9_EXISTING_CONTACT_PLANAR_BRACE_DECISION_V1`.

The decision accepts only the exact BR9.0–BR9.3 program scopes from
certification `br9_20260723T160129Z_4023e51f`. BR9.4 remains integrity-only.
The certification report's verbatim claim boundary remains controlling,
including:

- the material BR7-derived planar guide;
- the two already-bearing distal contacts;
- the paired same-impulse no-brace control;
- the first-post-impulse command timing;
- the finite paired-actuator command, ledger, executor, and receipt path;
- the no-new-contact boundary;
- commanded shares as commands rather than per-foot measurements; and
- whole-system reconstruction as aggregate external pitch-moment evidence
  rather than per-foot allocation.

The accepted positive claim is **scaffold-constrained planar existing-contact
pitch arrest**. It is the ladder's first accepted executed-brace result, but
not a catch step, free-3D brace or stand, unconstrained balance,
articulated-limb generality, fall arrest, getting up, gait, or walking.

The decision admits zero encyclopedia entries and authorizes zero automatic
creature guidance. All seven older decision files remain independently
byte-pinned. The complete decision-registry regression passed 7/7 programs,
and the released BR1 dispatch check also passed:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_all_milestone_decisions\20260723T111546175\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_br9_released_registry\20260723T111543553\report.json
```

The formal ladder advances to **10/18 accepted (55.6%)**. Observation-only
BR9 knowledge, BR10 catch stepping, release of the material out-of-plane
guide, fall arrest, self-righting, gait, and walking remain separate work.

## 48. BR9 observation-only knowledge admission — 2026-07-23

A separate append-only operation admitted exactly four BR9 observations, one
for each accepted milestone cell BR9.0 through BR9.3. BR9.4 remains
integrity-only and cannot enter the catalog.

Each entry reopens and verifies:

- `BR9_EXISTING_CONTACT_PLANAR_BRACE_DECISION_V1`;
- certification `br9_20260723T160129Z_4023e51f`;
- report
  `sha256:243312f7c9de378daa8ea7382a50c3148261f367141b6df0e0becd728b3a0cde`;
- detached report receipt
  `sha256:0f3bfc904cd23241a3daee3d3d36e70f73982d058d315333e2df22615690a97d`;
- certified source `4023e51f00030abc6c65574015f37c15265509f0`;
  and
- both production-attested bundles for its one cited program.

The four entries record controller arithmetic, fail-closed feasibility,
command/receipt provenance, and paired live planar pitch arrest. Every
`minimal_repair_rules` array is structurally empty. Automatic application and
automatic creature guidance are false. The unlock fence requires an accepted
BR10 catch step, a validated guidance consumer, and a separate guidance
decision.

The BR9 knowledge contract passed 23/23 adversarial assertions, and the
complete seven-family admission regression passed 154/154:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br9_knowledge_contract\20260723T112304537\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_all_knowledge_admissions\20260723T112522441\report.json
```

The shared catalog now contains **36 observation-only entries**. The formal
ladder remains **10/18 accepted (55.6%)**. No knowledge entry adds a
new-contact catch step, measured per-foot allocation, free-3D bracing or
standing, fall arrest, getting up, gait, walking, creature repair, or guidance
authority.

## 49. BR10 prerequisite commissioning checkpoint — 2026-07-23

The simpler fixtures required before the BR10 falling-body catch trial are now
implemented and commissioned as a separate experimental family:

| Cell | Exact result | Assertions |
|---|---|---:|
| BR10.0 | Candidate scoring plus actuator-limited reach/deadline refusal | 13 |
| BR10.1 | Strict observed `SEARCH -> TOUCH -> LOAD -> BEARING` coordinator | 12 |
| L4.2/L4.5 | Fixed-root two-link free-space placement with measured clearance and no scuff | 12 |
| L4.6 | Fixed-root known-floor touchdown with bounded impact and semantic distal contact | 15 |
| Total | BR10 prerequisite commissioning only | 52 |

BR10.0 selects only candidates with complete geometry, collision, friction,
torque, clearance, deadline, and predicted support-improvement witnesses. Its
selected candidate remains a plan, not a contact observation. An empty
feasible set returns explicit infeasibility. The planner cannot authorize a
root assist, foot pin, pose teleport, creature edit, or guidance operation.

BR10.1 enforces the phase order from ground-qualified observations. Target
arrival is diagnostic and cannot advance the state. `TOUCH` requires a
semantic ground contact, `LOAD` requires an available normal-load witness, and
`BEARING` requires the complete load/separation dwell. Contact loss revokes
bearing. The local load field is explicitly not a generalized per-foot
allocation.

The first physical L4.2/L4.5 commissioning attempt honestly failed its target
and clearance gates: a pure PD controller settled `105.19 mm` away from the
target and dipped to `18.98 mm` clearance. The gate was not weakened. The
fixture was corrected by adding the already validated analytic two-link
gravity feedforward and raising the landing-independent swing target.

The sealed fresh Godot/Jolt run then passed 12/12:

- first target dwell at tick 64, or `0.533 s`;
- final endpoint error `0.002 mm` against a `12 mm` gate;
- minimum virtual-ground clearance `125.176 mm` against a `40 mm` gate;
- maximum applied torque `7.647 N·m`;
- zero actuator saturation;
- zero collision contacts; and
- zero root assist, foot pin, pose teleport, or guidance operations.

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_l4_2_l4_5_swing_ff\20260723T114013898\report.json
```

L4.6 adds one semantic static floor and one raw-contact-v2 observer to the
distal sphere. A smooth target ramp produced the measured transition
`TOUCH@98 -> LOAD@99 -> BEARING@100`, with first touch at `0.817 s` inside
the preregistered `1.50 s` upper clock. Touchdown approach speed was
`0.2429 m/s`, peak local predicted normal load was `7.334 N`, final horizontal
target error was `2.186 mm`, and no non-distal shape contacted the floor.
The contact buffer remained unsaturated, paired-actuator residual remained
zero, maximum applied torque was `1.296 N·m`, and every command receipt
reconciled.

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_l4_6_touchdown_sealed\20260723T115114726\report.json
```

The L4.6 raw predicted impulse is admitted only as a unary touchdown-phase
witness. L1.6-L1.8 still prohibit treating it as a generalized per-foot
allocation or whole-creature support measurement.

All physical prerequisite fixtures retain a materially frozen root. The L4.6
floor and target are known before the trial; no falling body is arrested and
no support polygon is improved. This checkpoint therefore establishes no
reachable catch step, free-3D bracing or standing, fall arrest, getting up,
gait, walking, creature repair, or automatic guidance. It creates no
promotion bundle, certification, milestone decision, or encyclopedia entry.
The formal ladder remains **10/18 accepted (55.6%)** while the actual BR10
falling-body/new-bearing-contact cell remains open.

## 50. BR10 reachable new-contact catch implementation — 2026-07-23

The actual BR10 paired catch experiment is now implemented and commissioned.
Its five-cell family passed **5/5 programs and 91/91 assertions**:

| Cell | Evidence role | Assertions |
|---|---|---:|
| BR10.0 | Deterministic reachable support-expanding planner | 13 |
| BR10.1 | Observed `SEARCH -> TOUCH -> LOAD -> BEARING` authority | 12 |
| BR10.2 | Strict sagittal tangent/normal J-transpose map | 16 |
| BR10.3 | Paired live Godot/Jolt active-catch versus no-catch trial | 15 |
| BR10.4 | Digest, causal, assistance, measurement, and claim containment | 35 |
| Total | Commissioning only | 91 |

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br10_full_commissioning\20260723T124158115\report.json
```

BR10.3 inherits the material BR7 sagittal scaffold. The unpowered
`Generic6DOFJoint3D` releases X/Y translation and pitch while locking
out-of-plane translation, roll, and yaw. Four hinges remain passive. One
ordinary left distal contact bears during preparation; the observed right
distal sphere is unloaded and clear. The root freeze is preparation-only and
is released exactly when the one declared `0.005 N·m·s` pitch impulse is
applied at tick 120. It is never restored.

The first post-disturbance observation at tick 121 produces one
`forward_catch` plan. Its actuator-limited conservative contact prediction is
tick 167. Finite swing commands create the new semantic distal contact in the
exact order:

```text
TOUCH@167 -> LOAD@168 -> BEARING@169
```

Measured support width expands from `0.110000 m` to `0.299903 m`, an
improvement of `0.189903 m`. Touchdown approach speed is `0.425583 m/s`.
The peak local predicted normal-load witness is `21.4990 N`. No other shape
contacts the floor, the contact buffer remains complete, every paired command
receipt reconciles, the pairing residual is zero, maximum applied joint torque
is `15.9429 N·m`, and no active-catch actuator saturates.

The first controller version could acquire bearing and transiently satisfy the
stance dwell, but later drifted left until the center of mass crossed behind
the old support. The gate was not shortened. Diagnostics showed that the
fixture commanded only vertical contact wrenches; it had no deliberate
horizontal channel to arrest root translation.

BR10.2 therefore adds a separate strict sagittal mapper rather than weakening
the accepted vertical-only force-map contract. It evaluates the full
two-link Jacobian transpose for a commanded tangent/normal pair, retains link
gravity feedforward, preserves exact zero-tangent parity with the old mapper,
and carries explicit machine-readable non-claims that commands are not
measurements. Analytic, mirrored, finite-difference virtual-work, strict-field,
unilateral-normal, nonfinite, and legacy-boundary checks passed 16/16.

The active fixture commands at most `4.96166 N` tangent force inside a
friction reserve and compensates its COM-height pitch moment before vertical
load allocation. Both normal commands are jointly rate-limited; the measured
maximum is exactly the sealed `1200 N/s` boundary. The corrected active world
returns to the declared 15-tick stance dwell at tick 353 and then retains
ordinary `BEARING` contact for all 247 remaining samples through tick 600.
Across that post-stance interval:

- bearing losses: `0`;
- maximum pitch error: `0.020419 rad`;
- maximum pitch rate: `0.031017 rad/s`;
- maximum height error: `0.578 mm`;
- final pitch: `-0.013415 rad`;
- final pitch rate: `-0.000562 rad/s`; and
- final height error: `0.0156 mm`.

The matched no-catch world receives the same scaffold and impulse but no plan
or catch command. Its first right-distal contact occurs only at tick 278 as a
late crash at `19.3336 m/s`, with a `296.471 N` peak local predicted-load
witness, 201 actuator saturations, more than `3.12 rad` pitch excursion, and
no stance return. Later passive crash contacts do not count as a catch.

BR10.4 passed 35/35 adversarial checks. It rejects contract mutation, missing
causal authority, hidden fields, motors, joint limits, passive-tissue credit,
root force, foot pins, pose teleports, forged per-foot sensors, guidance,
free-3D or downstream claims, late commands, skipped phases, target-arrival
authority, transient-only stance, post-stance bearing loss, load-rate
overshoot, planner/geometry mismatch, unstable handoff, and a weak matched
control.

The exact positive statement remains:

> scaffold-constrained planar reachable new-contact catch step and return to
> the declared stance dwell in the paired BR10 fixture.

The preparation root freeze, material out-of-plane guide, fixed disturbance,
one starting support, one preregistered reachable target, finite actuator
contract, command-not-measurement boundary, and full-horizon paired control
remain part of the claim. No root rescue, foot pin, teleport, built-in motor,
creature edit, or automatic guidance operation occurs.

This is implementation and commissioning evidence only. It creates no
promotion bundle, certification, milestone decision, or accepted encyclopedia
entry. It establishes no measured per-foot allocation, free-3D standing or
bracing, general articulated load-bearing limb, generalized fall arrest,
getting up, gait, walking, creature repair, or automatic creature guidance.
The formal ladder therefore remains **10/18 accepted (55.6%)** pending a
separate BR10 promotion/certification/decision stream.

## 51. BR10 promotion family boundary — 2026-07-23

BR10 now has a separate promotion-grade trust family. This does not yet accept
the milestone. It defines the exact evidence that may be certified and makes
broader statements unrepresentable.

The fixed campaign is
`data/lab/campaigns/BR10_reachable_catch_promotion_campaign_v1.json`. Its
machine-owned family includes:

- strict campaign, source-inventory, metrics, capsule, certification-report,
  and detached-report-receipt schemas;
- a clean-commit operator with an exact declared source-byte closure;
- two fresh target-process replicates for each of BR10.0 through BR10.4;
- ten retained evidence bundles and ten production bundle receipts;
- one BR10-specific detached certification-report attestation domain;
- complete-campaign reconciliation with cherry-picking forbidden; and
- 33 adversarial promotion-contract assertions.

Fixed campaign accounting is:

| Role | Programs | Per replicate | Two replicates |
|---|---:|---:|---:|
| Milestone, BR10.0-BR10.3 | 4 | 56 | 112 |
| Integrity, BR10.4 | 1 | 35 | 70 |
| Total | 5 | 91 | 182 |

The campaign copies the physical analyzer's complete claim boundary verbatim.
The positive claim remains one scaffold-constrained planar reachable
new-contact catch and return to the declared stance dwell relative to the
matched no-catch crash control. It retains the inherited BR7 guide,
preparation-only freeze and release, one initially bearing contact, one
initially unloaded catch limb, the first-observation planner, observed
`TOUCH -> LOAD -> BEARING`, strict sagittal J-transpose commands, bounded
normal-load rate, finite paired actuation, full receipts/capacity, measured
support expansion, and the complete post-stance horizon.

The report cannot claim per-foot measured load allocation, free-3D standing or
bracing, a general articulated load-bearing limb, generalized fall arrest,
getting up, gait, walking, accepted knowledge, creature repair, or automatic
guidance. Certification, a human milestone decision, observation admission,
and any future guidance consumer remain separate operations.

Promotion-contract commissioning passed **33/33**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br10_promotion_contracts\20260723T130719753\report.json
```

The architecture and operator contracts are recorded in
`docs/adr/ADR-011_BR10_REACHABLE_CATCH_EVIDENCE_BOUNDARY.md` and
`docs/BR10_REACHABLE_CATCH_CERTIFICATION_OPERATOR.md`.

## 52. BR10 certification and bounded decision review — 2026-07-23

The complete clean-source campaign passed from commit
`980549f87486ebcaaaf7b1653d4569b1665fc12c`:

```text
certification: br10_20260723T181129Z_980549f8
programs: 5/5
fresh-process bundles: 10/10
assertions: 182/182
milestone assertions: 112/112
integrity assertions: 70/70
unique target processes: 10
PID reuse events: 0
report SHA-256: sha256:f4e9aa4f396a25745346cc88d605d8a5a9fd688c28f945a11ffc0296649ddd5d
detached receipt SHA-256: sha256:502f700a48e297bbc5c8929e01dbd757780d8551ccafabbe09bc4eb2196ff4e3
```

All ten bundle receipts, both replicates of every program, the exact source
inventory, ordered assertion labels, raw transcripts, and the detached BR10
report receipt reconciled. No run was cherry-picked.

`docs/BR10_REACHABLE_CATCH_MILESTONE_DECISION_REVIEW.md` recommends bounded
acceptance of BR10.0-BR10.3 and keeps BR10.4 integrity-only. The recommendation
accepts only the scaffold-constrained planar new-bearing-contact catch and
full-horizon stance return relative to the matched no-catch crash control.

The review explicitly preserves no per-foot measured allocation, no free-3D
standing or bracing, no general articulated load-bearing limb, no generalized
fall arrest, no getting up, no gait or walking, no encyclopedia admission, and
no automatic guidance. Until the separate append-only decision is recorded,
the formal ladder remains **10/18 accepted (55.6%)**.

## 53. Bounded BR10 milestone accepted — 2026-07-23

Cole's delegated bounded acceptance is now recorded as the append-only,
byte-pinned decision:

```text
BR10_REACHABLE_PLANAR_CATCH_DECISION_V1
```

The decision binds:

- review commit `7709d1b8be23e34867cd601b761cfe5b6391180e`;
- review SHA-256
  `sha256:be5f50735f69248392215691f3532fab2052995e0778534b22fe389e36900d09`;
- certification `br10_20260723T181129Z_980549f8`;
- certified source `980549f87486ebcaaaf7b1653d4569b1665fc12c`;
- report SHA-256
  `sha256:f4e9aa4f396a25745346cc88d605d8a5a9fd688c28f945a11ffc0296649ddd5d`;
- detached receipt SHA-256
  `sha256:502f700a48e297bbc5c8929e01dbd757780d8551ccafabbe09bc4eb2196ff4e3`;
  and
- the verbatim campaign claim boundary and exact BR10.0-BR10.3 program
  scopes.

BR10.4 remains integrity-only. The accepted result is one
scaffold-constrained planar reachable new-contact catch and full-horizon
return to the declared stance dwell relative to the matched no-catch crash
control. The inherited BR7 guide, preparation-only freeze/release, one
initially bearing contact, one initially unloaded catch limb,
first-observation planning, observed `TOUCH -> LOAD -> BEARING`, strict
sagittal J-transpose command path, bounded normal-load rate, finite paired
actuation, measured support expansion, and command-not-measurement boundary
remain controlling.

The decision admits zero knowledge entries and authorizes zero automatic
guidance. It establishes no per-foot measured load allocation, free-3D
standing or bracing, generalized articulated-limb behavior, generalized fall
arrest, getting up, gait, or walking.

Decision commissioning passed **30/30**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br10_milestone_decision\20260723T132242890\report.json
```

The formal ladder advances to **11/18 accepted (61.1%)**. Observation
admission, if performed, remains a separate append-only operation.

## 54. BR10 observation-only knowledge admission — 2026-07-23

The separately authorized append-only operation has now admitted exactly four
BR10 milestone observations:

| Entry | Certified cell | Entry SHA-256 |
|---|---|---|
| `BR10.0.reachable_catch_planning.v1` | BR10.0 | `sha256:2cb81212944e6795731ed1658fa67f0c068503018ef3c3680fa2b686f6f7b80d` |
| `BR10.1.contact_phase_authority.v1` | BR10.1 | `sha256:e2f657c2ca40d8f6647c6e5bedc4d8a56a791216072abb76c4c6468911fef06c` |
| `BR10.2.sagittal_contact_force_map.v1` | BR10.2 | `sha256:c5db45ed4a7e70705dc50085bb5da4f10d78e9c63531acf9b3a5213d931a0e90` |
| `BR10.3.paired_planar_reachable_catch.v1` | BR10.3 | `sha256:dd4da62d676c51db6c14413878a793887b9216106e2f434e835d841b7f6b2205` |

All four entries share admission timestamp `2026-07-23T18:33:05Z`. Their
fixed authoring source is
`data/lab/knowledge/admission_manifests/BR10_reachable_catch_knowledge_admission_v1.json`
at
`sha256:35976c6bf315a55d6f330ed6b090550fb796f814dd4b51811208af6de532e9df`.

Each entry reopens and verifies:

- decision `BR10_REACHABLE_PLANAR_CATCH_DECISION_V1`;
- certification `br10_20260723T181129Z_980549f8`;
- report
  `sha256:f4e9aa4f396a25745346cc88d605d8a5a9fd688c28f945a11ffc0296649ddd5d`;
- detached receipt
  `sha256:502f700a48e297bbc5c8929e01dbd757780d8551ccafabbe09bc4eb2196ff4e3`;
- certified source `980549f87486ebcaaaf7b1653d4569b1665fc12c`; and
- both production-attested replicates of its one cited milestone program.

BR10.4 remains integrity-only and is not an encyclopedia entry. The admission
schema makes `minimal_repair_rules` structurally empty. Automatic application
and automatic creature guidance remain false. Future guidance remains behind
three intentionally unresolved gates:

1. `VALIDATED_CREATURE_GUIDANCE_CONSUMER`;
2. `CERTIFIED_MORPHOLOGY_TERRAIN_TRANSFER`; and
3. `SEPARATE_GUIDANCE_DECISION`.

That fence builds around, but does not decide, the future guidance-consumer
design. The entries are readable observations only. They establish no
per-foot measured allocation, free-3D standing or bracing, generalized
articulated load-bearing limb, generalized fall arrest, getting up, gait,
walking, creature repair, or automatic guidance.

The BR10 admission contract passed **23/23**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br10_knowledge_admission_final\20260723T133438722\report.json
```

The complete cross-family admission regression passed **8/8 programs**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_all_knowledge_admissions_post_br10\20260723T133541932\report.json
```

The shared accepted catalog now contains **40 observation-only entries**:
one L0 baseline; nine BR3A; three BR3B; eight BR4; three BR6A; four BR7;
four BR8; four BR9; and four BR10. Every accepted entry still yields zero
automatic repair candidates. Knowledge admission does not add a formal
milestone, so the formal ladder remains **11/18 accepted (61.1%)**.

## 55. BR10 pipeline closure regression — 2026-07-23

The complete post-admission experimental suite passed:

```text
programs: 71/71
assertions: 1346/1346
failures: 0
timeouts: 0
engine errors: 0
unexpected engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_experimental_br10_pipeline_final\20260723T133931224\report.json
```

The protected released lab suite also passed:

```text
programs: 62/62
assertions: 1118/1118
failures: 0
timeouts: 0
unexpected engine errors: 0
expected engine-error fixture: CHILD_PROCESS_CREATE_FAILED
report: <evidence-root>\temp-roots-2026-07-28\sporespore_released_br10_pipeline_final\20260723T134913890\report.json
```

The changed GDScript set passes `gdformat --check` and `gdlint`; the new BR10
JSON set parses; no admission lock remains; and `git diff --check` reports no
tracked-diff whitespace error. A deliberately broader all-repository
formatter/linter probe still exposes the repository's pre-existing style
baseline, so no unrelated mass rewrite was folded into this evidence change.

This closes the BR10 implementation, promotion, certification, review,
decision, and observation-admission pipeline. The resulting state is:

- formal ladder: **11/18 accepted (61.1%)**;
- accepted catalog: **40 observation-only entries**;
- BR10 repair rules: **0**;
- automatic BR10 application or guidance: **false**; and
- next capability work: BR11 or another separately defined and certified
  milestone, not an unreviewed expansion of BR10.

The closure does not prove free-3D standing or bracing, per-foot measured load
allocation, a generalized articulated load-bearing limb, generalized fall
arrest, getting up, gait, or walking.

## 56. BR11 controlled-fall implementation commissioning — 2026-07-23

The bounded BR11 implementation now contains five separately identified
cells:

| Cell | Scope | Assertions |
|---|---|---:|
| BR11.0 | semantic protective/core contact roles and pure finite controller | 15 |
| BR11.1 | `FALL_ARREST` / `FALLEN` supervisor authority | 11 |
| BR11.2 | paired momentum, impulse, kinetic-proxy, and energy oracle | 22 |
| BR11.3 | live planar controlled-fall pair | 13 |
| BR11.4 | digest, assistance, measurement, and claim containment | 43 |
| Total | four milestone cells plus one integrity-only cell | 104 |

The live pair uses one exact planar scaffold, a two-body torso/protective-link
system, one finite paired hinge actuator, semantic contact roles, and a
same-state zero-command control. The active link contacts the ground at tick
30; semantic core contact follows at tick 37. In the control, core contact
occurs first at tick 34 and the protective link arrives only at tick 39.

The paired evidence is:

| Measure | Active | Control | Active/control |
|---|---:|---:|---:|
| Pre-core whole-system kinetic-energy proxy | 55.837261 J | 62.257790 J | 0.896872 |
| Core approach speed | 4.077792 m/s | 4.255217 m/s | 0.958304 |
| Peak local predicted core-load witness | 1555.562325 N | 1654.882278 N | 0.939984 |
| Pre-core whole-system linear-momentum magnitude | 26.121127 N s | 29.081337 N s | 0.898209 |

The active result therefore reduces the declared kinetic severity proxy by
10.31%, core approach speed by 4.17%, the local core-load witness by 6.00%,
and whole-system pre-core linear momentum by 10.18% relative to the matched
control. Both worlds end in an observed stable `FALLEN` state. Neither world
recovers upright.

Centroidal angular momentum remains a mandatory measured channel but is not
misrepresented as a universal magnitude-reduction gate. The off-center
protective contact converts falling motion into rotation: active pre-core
angular-momentum magnitude is approximately 10.46 times its initial
magnitude. The result is accepted by the implementation oracle because the
preregistered whole-system kinetic and linear-momentum channels, core approach
speed, and local load witness improve while angular momentum remains explicit
and finite.

The active trial applies at most 40.652886 N m through a 45 N m structural
ceiling, with zero pairing residual and complete command receipts. It records
0.310990 J actuator work, 72.489503 J contact dissipation, and zero energy
accounting residual. Reconstructed external impulse is finite. There are zero
root-rescue, pin, teleport, or automatic-guidance operations.

The sealed configuration now binds the exact actuator-spec SHA-256. The
analyzer also rejects mismatched paired initial states, missing core contact,
missing angular momentum, hidden control work, excessive terminal motion,
negative contact dissipation, nonfinite external impulse, weakened comparison
ratios, unbound actuator evidence, assistance, and broadened claims.

Commissioning passed:

```text
programs: 5/5
assertions: 104/104
failures: 0
timeouts: 0
unexpected engine errors: 0
configuration SHA-256: sha256:5e3933edfa22b69c4abd22e54d80223f7dd674711e0b7005cca4854376f3ae9c
actuator-spec SHA-256: sha256:67aad0c684644758708b825b6816d9cc4aebc2e653e48839e030d5f1481cff42
report: <evidence-root>\temp-roots-2026-07-28\sporespore_br11_commissioning_final\20260723T142638530\report.json
```

This is implementation commissioning, not promotion or acceptance. The
positive scope is only one scaffold-constrained planar protective fall
relative to its matched control. The kinetic proxy is not an injury model;
the local predicted contact witness is not a per-body or per-foot load
allocation; BR11.4 is integrity-only; and nothing here establishes upright
recovery, free-3D standing or bracing, generalized fall arrest, getting up,
gait, walking, creature repair, or automatic creature guidance.

The formal ladder remains **11/18 accepted (61.1%)** pending a separate
source-pinned BR11 promotion family, clean certification, and bounded
milestone decision.

The complete post-commissioning experimental regression passed:

```text
programs: 76/76
assertions: 1450/1450
failures: 0
timeouts: 0
engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_experimental_br11_commissioning_regression\20260723T143031968\report.json
```

The protected released suite remained unchanged:

```text
programs: 62/62
assertions: 1118/1118
failures: 0
timeouts: 0
unexpected engine errors: 0
expected engine-error fixture: CHILD_PROCESS_CREATE_FAILED
report: <evidence-root>\temp-roots-2026-07-28\sporespore_released_br11_commissioning_regression\20260723T143952245\report.json
```

## 57. BR11 promotion trust family — 2026-07-23

BR11 now has an isolated promotion contract. This checkpoint defines a
certifiable boundary but does not itself accept the result.

The fixed campaign contains four milestone programs and one integrity-only
program. Two fresh-process replicates produce ten complete bundles and
**208 assertions**:

| Role | Programs | Per replicate | Two replicates |
|---|---:|---:|---:|
| Milestone: BR11.0-BR11.3 | 4 | 61 | 122 |
| Integrity: BR11.4 | 1 | 43 | 86 |
| Total | 5 | 104 | 208 |

Every declared run must remain in the report. The operator builds an exact
clean-commit source inventory, retains raw transcripts and engine logs,
creates metrics and evidence capsules, applies production bundle receipts,
reconciles both replicates, independently reads back all ten bundles, and
creates a detached receipt in the BR11-specific certification-report domain.

The family certifies only:

- strict semantic protective/core roles and a pure finite controller;
- observation-authoritative `FALL_ARREST` / stable `FALLEN` supervision;
- paired whole-system momentum, reconstructed external impulse, kinetic
  severity-proxy, energy, and explicitly local core-load-witness semantics;
- the exact paired live planar protective-fall result; and
- integrity-only rejection of digest, assistance, measurement, identity,
  terminal-state, and broader-claim forgery.

The schema makes injury prediction, measured per-body/per-foot allocation,
upright recovery, free-3D standing or bracing, generalized or transferred
fall arrest, getting up, gait, walking, accepted knowledge, creature repair,
and automatic guidance unavailable. BR11.4 can reject weakened evidence but
cannot substitute for BR11.0-BR11.3. Recorded actuator saturation remains
permitted as explicit finite-capacity evidence.

The promotion-contract suite passed **33/33**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br11_promotion_contracts_probe\20260723T145500769\report.json
```

The non-promotable operator preflight also passed against the pinned Godot
executable, unchanged 62-test BR1 inventory, campaign schema, and a 392-file
source closure. No physics, bundle, report, decision, or admission was created
by preflight.

The architecture and operator contracts are recorded in
`docs/adr/ADR-012_BR11_CONTROLLED_FALL_EVIDENCE_BOUNDARY.md` and
`docs/BR11_CONTROLLED_FALL_CERTIFICATION_OPERATOR.md`.

The formal ladder remains **11/18 accepted (61.1%)**. A complete clean-source
certification and separate bounded milestone decision are still required.

## 58. BR11 clean certification and bounded acceptance — 2026-07-23

The complete clean-source campaign passed as certification
`br11_20260723T195911Z_d4551f99` at exact source
`d4551f99ce0260ac901ca682e0237e81e38df3d8`:

```text
programs: 5/5
fresh-process bundles: 10/10
unique target processes: 10/10
assertions: 208/208
milestone assertions: 122
integrity assertions: 86
report SHA-256: sha256:914c939f6721bac3d713e7cc62df2189c372ff86bd20416bdd186352d1768f88
detached receipt SHA-256: sha256:c2ca9c82325d7b4dd7720f7b4809e5bcb77bb1785d586bf9b8b1378f673371c0
```

The report and detached receipt were independently bound into review
`BR11_CONTROLLED_FALL_MILESTONE_DECISION_REVIEW.md`. Under Cole's delegated
instruction to continue the pipeline and accept the recommended bounded
result, append-only decision `BR11_CONTROLLED_PLANAR_FALL_DECISION_V1`
accepts only the exact BR11.0 through BR11.3 program scopes. BR11.4 remains
integrity-only and cannot substitute for any physical program.

The acceptance keeps the material planar guide, exact two-body scaffold,
semantic protective/core roles, observation-authoritative supervisor,
same-state zero-command control, finite paired hinge, preregistered mechanics
comparisons, explicit angular-momentum/impulse/energy channels, and stable
`FALLEN` terminal states inside the controlling boundary. It does not turn
the kinetic proxy into an injury model, the local predicted contact witness
into a measured load allocation, or the planar result into generalized fall
arrest.

The byte-pinned registry and adversarial decision suite passed **32/32**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br11_milestone_decision_final\20260723T151245365\report.json
```

The decision admits zero encyclopedia entries and authorizes neither
automatic application nor creature guidance. The formal ladder advances to
**12/18 accepted (66.7%)**. Observation-only knowledge remains a separate,
fail-closed operation.

## 59. BR11 observation-only knowledge admission — 2026-07-23

The separate fixed admission operation installed four accepted observations:

- BR11.0 semantic protective/core roles and pure finite controller;
- BR11.1 observation-authoritative fall-arrest and stable-FALLEN supervision;
- BR11.2 paired severity-proxy, momentum, impulse, and energy accounting; and
- BR11.3 the paired live planar controlled-fall result.

Integrity-only BR11.4 was not admitted. Each entry reopens and revalidates the
exact accepted decision, certification report, detached report receipt,
certified source, and both production-attested program replicas before it can
be proposed or verified. The entry schema cannot represent a nonempty repair
rule, automatic application, or automatic creature guidance.

The admission preserves the material planar scaffold, injury-proxy non-claim,
local-load non-allocation boundary, stable-`FALLEN` rather than upright
terminal state, and lack of morphology or terrain transfer. Adversarial tests
reject report, receipt, decision, program, and integrity-cell substitution;
repair or guidance injection; broader free-3D claims; injury-model relabeling;
and conversion of the fallen result into upright recovery.

The BR11 admission contract passed **24/24** assertions. The complete
cross-family admission family passed **9/9 programs**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br11_knowledge_admission_probe\20260723T152026681\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_all_knowledge_admissions_post_br11_final\20260723T152325122\report.json
```

The shared catalog now contains **44 observation-only entries**. Every BR11
repair-rule array is empty; automatic application and creature guidance
remain false. Knowledge admission does not add a formal milestone, so the
formal ladder remains **12/18 accepted (66.7%)**.

## 60. BR11 pipeline closure regression — 2026-07-23

The complete post-admission experimental family passed after every historical
decision-registry invariant was advanced from the nine-record BR10 state to
the ten-record BR11 state:

```text
programs: 79/79
assertions: 1539/1539
failures: 0
timeouts: 0
engine errors: 0
unexpected engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_experimental_br11_pipeline_final2\20260723T153839239\report.json
```

The protected released family also passed after its append-only
accepted-milestone inventory assertion was updated without changing the
pinned 62-test BR1 inventory:

```text
programs: 62/62
assertions: 1118/1118
failures: 0
timeouts: 0
unexpected engine errors: 0
expected engine-error fixture: CHILD_PROCESS_CREATE_FAILED
report: <evidence-root>\temp-roots-2026-07-28\sporespore_released_br11_pipeline_final2\20260723T155200490\report.json
```

Task-scoped GDScript formatting and linting pass, the new JSON family parses,
no admission lock remains, and tracked-diff whitespace checks pass. This
closes BR11 through implementation, promotion, clean certification, bounded
acceptance, and observation-only knowledge admission.

The resulting state is:

- formal ladder: **12/18 accepted (66.7%)**;
- accepted catalog: **44 observation-only entries**;
- BR11 repair rules: **0**;
- automatic BR11 application or guidance: **false**; and
- next capability work: a separately bounded self-righting/get-up milestone,
  not a broader reinterpretation of the planar controlled-fall result.

Free-3D standing or bracing, generalized or transferred fall arrest, injury
prediction, measured per-contact/per-body/per-foot allocation, self-righting,
getting up, gait, and walking remain unproved.

## 61. BR12 pose and static recovery-feasibility implementation checkpoint — 2026-07-23

BR12 now has a complete five-cell implementation family:

| Cell | Commissioned scope | Assertions |
|---|---|---:|
| BR12.0 | strict semantic body-region contact roles and labeled-box basis oracle | 19 |
| BR12.1 | deterministic profile-specific canonical-pose classification with fail-closed ambiguity | 14 |
| BR12.2 | exact recovery-profile anatomy-role matching with named missing-role failures | 13 |
| BR12.3 | conservative static torque, power, structural, friction, and reach feasibility | 15 |
| BR12.4 | controller, contact-creation, assistance, guidance, and broader-claim containment | 14 |
| Total | implementation commissioning | **75** |

The labeled-box oracle fixes the authored semantic basis at `+X` right, `+Y`
up, and `-Z` forward. The pose classifier combines orientation evidence with
required semantic support contact to classify only the declared canonical
states: upright, prone, supine, left side, and right side. Conflicting,
insufficient, nonfinite, or missing evidence returns `unknown`; ambiguity is
never resolved by guessing.

Recovery profiles address anatomy through semantic roles instead of hardcoded
limb indices. The commissioned profile is one exact prone static-feasibility
profile. The analyzer names missing roles and evaluates conservative torque,
power, structural, friction, and reach margins before any actuation could be
considered. Obviously underpowered, overloaded, slipping, unreachable, or
anatomically incomplete phases are rejected.

BR12.4 proves that the family cannot represent a hidden controller, joint
target, requested wrench, contact-creation operation, external assistance,
automatic application, creature guidance, or a physical get-up claim.
Ventral contact may be labeled as temporary recovery support but is not
silently relabeled as steady stance.

Commissioning passed:

```text
programs: 5/5
assertions: 75/75
failures: 0
timeouts: 0
engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_br12_pose_recovery_final\20260723T160504378\report.json
```

This checkpoint establishes only deterministic pose observation and static,
profile-specific feasibility screening. It does not execute a recovery
controller, create or maintain a contact, raise a body, transfer into stance,
or show that any morphology can get up. BR13's canonical morphology and
recovery-pose choice therefore remains a later implementation decision; BR12
is built so that choice can be supplied as an explicit profile without
weakening the observer/planner boundary.

The formal ladder remains **12/18 accepted (66.7%)** pending a separate
source-pinned BR12 promotion family, clean certification, and bounded
milestone decision. The accepted catalog remains **44 observation-only
entries**. Free-3D standing or bracing, generalized fall arrest, physical
self-righting, getting up, gait, walking, creature repair, and automatic
guidance remain unproved and unauthorized.

## 62. BR12 promotion trust family — 2026-07-23

BR12 now has an isolated, source-pinned promotion contract. The fixed campaign
contains four milestone programs and one integrity-only program. Two
fresh-process replicates produce ten complete bundles and **150 assertions**:

| Role | Programs | Per replicate | Two replicates |
|---|---:|---:|---:|
| Milestone: BR12.0-BR12.3 | 4 | 61 | 122 |
| Integrity: BR12.4 | 1 | 14 | 28 |
| Total | 5 | 75 | 150 |

The family owns separate campaign, source-inventory, metrics, capsule,
certification-report, and detached report-receipt schemas. Every declared run
must remain in the report. The operator retains raw transcripts and engine
logs, creates production-attested bundles, reconciles both replicates,
independently reads back all ten bundles, and authenticates the final report
in the BR12-specific detached domain.

The positive report surface contains only profile-specific pose
classification and static recovery-feasibility screening. Its schema makes
dynamic execution, stance handoff, controller or actuator authority, contact
creation or assistance, generalized recovery, getting up, gait, walking,
accepted knowledge, repair, and guidance false. Static feasibility cannot be
relabeled as dynamic execution proof.

The promotion-contract suite passed **33/33**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br12_promotion_contracts\20260723T161548469\report.json
```

The non-promotable operator preflight passed against the exact pinned Godot
binary, unchanged 62-test BR1 inventory, campaign schema, and a 418-file
source closure. It ran no physics and created no bundle, report, decision, or
knowledge.

The architecture and operator contracts are recorded in
`docs/adr/ADR-013_BR12_POSE_RECOVERY_FEASIBILITY_EVIDENCE_BOUNDARY.md` and
`docs/BR12_POSE_RECOVERY_CERTIFICATION_OPERATOR.md`.

The formal ladder remains **12/18 accepted (66.7%)**. A complete clean-source
certification and a separate bounded milestone decision are still required.

## 63. BR12 clean certification and bounded acceptance — 2026-07-23

The complete clean-source campaign passed as certification
`br12_20260723T211754Z_0ace3791` at exact source
`0ace37912babd34bfc42e24414582e3bf53cb0c8`:

```text
programs: 5/5
fresh-process bundles: 10/10
unique target processes: 10/10
assertions: 150/150
milestone assertions: 122
integrity assertions: 28
report SHA-256: sha256:8c9179471685a3278950c7dd5648fcf0551901996a68ed702b3261e57bf23bda
detached receipt SHA-256: sha256:0c5767c79bbffe400e9640c3c221961fef5116926ad02821ab13eb067691fc07
```

The independently reviewed report and receipt are bound in
`BR12_POSE_RECOVERY_MILESTONE_DECISION_REVIEW.md`. Under Cole's delegated
instruction to continue the pipeline and accept the recommended bounded
result, append-only decision `BR12_POSE_RECOVERY_FEASIBILITY_DECISION_V1`
accepts only the exact BR12.0 through BR12.3 program scopes. BR12.4 remains
integrity-only and cannot substitute for a milestone program.

The accepted positive scope is:

- exact semantic body-region support roles and the labeled-box basis oracle;
- deterministic profile-specific classification of the five declared
  canonical poses;
- `unknown` for ambiguous, conflicting, invalid, nonfinite, or insufficient
  evidence;
- exact semantic anatomy-role profile matching with named missing roles; and
- conservative static torque, power, structural, friction, and reach
  feasibility screening before actuation.

The decision preserves the report's verbatim observer/planner boundary.
`Feasible` remains a static planning result, not dynamic execution evidence.
No accepted BR12 program contains a recovery controller, actuation, command,
wrench, joint target, contact creation, external assistance, physical body
rise, or stance handoff.

The byte-pinned registry and adversarial decision suite passed **33/33**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br12_milestone_decision\20260723T162619567\report.json
```

The decision admits zero encyclopedia entries and authorizes neither repair,
automatic application, nor creature guidance. The formal ladder advances to
**13/18 accepted (72.2%)**. Observation-only knowledge remains a separate,
fail-closed operation.

## 64. BR12 observation-only knowledge admission — 2026-07-23

A separate append-only operation admitted four BR12 observations:

- BR12.0 semantic body-region roles and labeled-box basis truth;
- BR12.1 deterministic profile-specific pose classification and ambiguity
  preservation;
- BR12.2 semantic anatomy-role recovery-profile matching; and
- BR12.3 conservative static recovery-feasibility screening.

Integrity-only BR12.4 was not admitted. Each entry reopens and revalidates the
accepted decision, exact certification report, detached report receipt,
certified source, and both production-attested replicas for its one milestone
program. Every repair-rule array is structurally empty. Automatic application
and creature guidance are false.

The entries preserve the decisive boundary: role/basis interpretation does
not create contact; pose ambiguity remains `unknown`; a complete anatomy-role
match is not feasibility proof; and static feasibility is not dynamic
execution, physical body rise, or stance handoff. No controller, command,
wrench, joint target, contact operation, external assistance, getting-up,
repair, or guidance authority is admitted.

The admission dry run reverified all eight cited bundles without writing. The
actual append-only operation then wrote four exact entries. Their SHA-256
identities are:

| Entry | SHA-256 |
|---|---|
| `BR12.0.body_region_roles_and_labeled_box.v1` | `sha256:9c4b18a1fd95ed35b8a610ece176c8243386152a23cfdef4fcb11eb6e2823bbd` |
| `BR12.1.profile_specific_pose_classifier.v1` | `sha256:276712191ead05d555cb42bfccc995743ac5eb2d3c9246b56416b0a8db8bd851` |
| `BR12.2.semantic_recovery_profile.v1` | `sha256:f46dfba4546e66fd4b2e10b45811afb2db93f11b27d5b596bd8b837a095cee86` |
| `BR12.3.static_recovery_feasibility.v1` | `sha256:bfa4b99ea416f11da96294f31d3de54377bdc5fca2aa52906ccb5464c8bd3749` |

The BR12 admission contract passed **24/24**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br12_knowledge_admission\20260723T163324590\report.json
```

The shared catalog now contains **48 observation-only entries**. Knowledge
admission does not add a formal milestone, so the formal ladder remains
**13/18 accepted (72.2%)**. Physical self-righting, getting up, free-3D
recovery, gait, walking, repair, and automatic guidance remain unproved and
unauthorized.

## 65. BR12 pipeline closure regression — 2026-07-23

Post-admission regression passed the complete experimental family:

```text
programs: 87/87
assertions: 1704/1704
failures: 0
timeouts: 0
engine errors: 0
unexpected engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_experimental_br12_pipeline_final2\20260723T164111863\report.json
```

The protected released family also passed:

```text
programs: 62/62
assertions: 1118/1118
failures: 0
timeouts: 0
engine errors: 1 expected fixture
unexpected engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_released_br12_pipeline_final\20260723T165108112\report.json
```

The expected released-family engine error remains the intentionally generated
child-process failure fixture and was classified as expected. BR12 changed
neither the released test inventory nor its assertion count.

BR12 is therefore closed through implementation commissioning, a
source-pinned promotion family, clean fresh-process certification, bounded
human acceptance, and separate observation-only admission. The closed
positive scope is still pose/profile interpretation and conservative static
feasibility screening. It contains no dynamic recovery controller, physical
body rise, stance handoff, self-righting, getting-up proof, repair rule, or
automatic guidance authority.

The formal ladder remains **13/18 accepted (72.2%)**, and the shared catalog
remains **48 observation-only entries**. BR13 must establish one exact
physical self-righting or getting-up maneuver through a new preregistered
fixture and matched control. It may consume BR12 observations as
interpretation and planning constraints, but it cannot inherit dynamic
execution proof from them.

## 66. BR13 prephysical canonical get-up boundary — 2026-07-23

The first BR13 implementation checkpoint now fixes the laboratory reference
profile and the contracts a later live physics cell must satisfy. This is not
yet a get-up experiment.

The exact reference profile is:

```text
profile: canonical_symmetry_collapsed_quadruped_prone_v1
start: semantic ventral-contact prone
terminal: stable front-pair and rear-pair foot-supported stance
plane: sagittal X/Y
material scaffold: out-of-plane translation Z, roll X, and yaw Y locked
contacts: ordinary unilateral floor contacts
control: matched zero-command world required
seed set: 13001, 13002, 13003
maximum future positive claim: constrained_planar_get_up
```

The front and rear rigid bodies each represent a mirrored left/right limb
pair. That symmetry collapse is part of the fixture and cannot be interpreted
as a four-independent-limb result or morphology transfer.

Four prephysical programs are commissioned:

| Cell | Scope | Assertions |
|---|---|---:|
| BR13.0 | exact profile, quadruped prone/transition/stance observation, successful phase order | 14 |
| BR13.1 | per-phase timeout, energy/reserve revocation, forbidden-contact failure, exclusive handoff | 16 |
| BR13.2 | static work/reserve preflight and explicit post-trace energy/guide-work reconciliation | 21 |
| BR13.3 | adversarial profile, scaffold, contact, claim, anatomy, seed, and guidance containment | 17 |
| Total | prephysical BR13 boundary | 68 |

The profile-specific observer does not reuse the labeled-box orientation as a
quadruped assumption. A quadruped may retain a near-horizontal torso in both
prone and stance, so semantic ventral/distal contacts, morphology-scaled
height, motion, and sensor validity remain authoritative. Invalid or
forbidden-contact evidence returns `UNKNOWN`.

The phase supervisor permits only:

```text
CONFIRM_PRONE
-> ESTABLISH_DISTAL_CONTACT
-> RAISE_BODY
-> STANCE_HANDOFF
-> STANCE_DWELL
-> COMPLETE
```

Each phase has a named timeout. Energy or actuator-reserve revocation and any
forbidden contact fail immediately. `COMPLETE` requires an observed stable
stance dwell with the recovery controller inactive and the stance controller
active. The supervisor itself has no force, torque, contact-creation, root,
repair, or guidance authority.

The energy ledger computes the required center-of-mass potential gain, keeps
torque, power, and structural reserves separate, and reconciles actuator,
known-external, residual-inferred guide, contact-dissipation, and mechanical
energy terms. Positive guide work above the declared bound rejects the trace.
Known external work cannot substitute for the required positive actuator work.

Commissioning passed:

```text
programs: 4/4
assertions: 68/68
failures: 0
timeouts: 0
engine errors: 0
unexpected engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_br13_prephysical_final\20260723T170647652\report.json
```

The next BR13 cell must be a real Godot/Jolt paired physics fixture with
finite paired actuators, command receipts, semantic contacts, the three
declared seeds, the zero-command control, real center-of-mass rise, real
energy accounting, and recovery-to-stance controller handoff. Until that
exists, there is no physical self-righting or getting-up evidence and no
promotion family to certify.

The formal ladder remains **13/18 accepted (72.2%)**, and the shared catalog
remains **48 observation-only entries**. Physical getting up, free-3D
recovery, morphology transfer, gait, walking, repair, and automatic guidance
remain unproved and unauthorized.

## 67. BR13 live constrained canonical get-up commissioning — 2026-07-23

BR13.4 now supplies the live physics cell that the prephysical boundary
required. The fixture is one exact symmetry-collapsed quadruped laboratory
profile: a free sagittal root, one front rigid strut representing the mirrored
front limb pair, and one rear rigid strut representing the mirrored rear limb
pair. Passive hinges connect both pairs to the root. A material
`Generic6DOFJoint3D` guide locks only out-of-plane translation, roll, and yaw.
The body remains free to translate in sagittal X/Y and pitch.

Every active trial uses ordinary unilateral Godot/Jolt floor contacts. Joint
torque is finite and passes through the sealed actuator, command ledger,
actuation executor, and execution-receipt path. The recovery controller and
stance controller are mutually exclusive across the recorded handoff.
There is no root force or pose rescue, foot pin, teleport, contact creation,
kinematic support, or automatic creature guidance.

The contract is digest-bound before any world runs. It owns the exact profile,
actuator specification, rig configuration, three-seed set, numeric acceptance
gates, verbatim claim boundary, and explicit non-claims. Each active seed is
paired with a same-state zero-command world.

The live campaign passed:

| Seed | Active terminal | Active COM gain | Positive actuator work | Control terminal | Control COM gain |
|---:|---|---:|---:|---|---:|
| 13001 | `COMPLETE` / `STANCE` | 0.368067093 m | 48.062315680 J | `FAILED` / `PRONE` | -0.003774717 m |
| 13002 | `COMPLETE` / `STANCE` | 0.368288197 m | 47.585230362 J | `FAILED` / `PRONE` | -0.003774717 m |
| 13003 | `COMPLETE` / `STANCE` | 0.368114330 m | 47.120798988 J | `FAILED` / `PRONE` | -0.003774717 m |

All three active trials followed the exact sequence:

```text
CONFIRM_PRONE
-> ESTABLISH_DISTAL_CONTACT
-> RAISE_BODY
-> STANCE_HANDOFF
-> STANCE_DWELL
-> COMPLETE
```

Every active energy ledger closed with positive finite actuator work,
nonnegative residual-inferred contact dissipation, at most `0.01 J` absolute
balance residual, and no positive guide work. Material guide impulse,
out-of-plane drift, roll, yaw, root pitch, terminal speeds, paired-torque
residual, applied torque, controller exclusivity, and receipt completeness all
remained inside the preregistered gates.

An initial one-seed probe exposed an instrumentation defect: integrating only
the pre-step joint rate undercounted work performed while torque accelerated a
joint during the physics transition. The implementation was corrected to
trapezoidally integrate the before/after relative joint rates under the
constant applied torque. The energy gate was not weakened. The corrected
three-seed campaign then closed the ledger.

The test also adversarially rejected:

- a truncated recovery phase sequence;
- a forged walking result;
- material undeclared guide impulse;
- an unclosed energy ledger;
- recovery commands after stance handoff;
- active-command substitution into a control; and
- post-seal mutation of the campaign contract.

Commissioning evidence:

```text
programs: 1/1
assertions: 22/22
failures: 0
timeouts: 0
engine errors: 0
unexpected engine errors: 0
report: <evidence-root>\temp-roots-2026-07-28\sporespore_br13_live_three_seed\20260723T173939737\report.json
```

The implemented BR13 family now contains five cells and **90 commissioning
assertions**: 68 prephysical assertions plus 22 paired live assertions.
The complete five-program family passed together at:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br13_implementation_all\20260723T174329411\report.json
```

This is positive physical evidence for exactly
`constrained_planar_get_up` in the declared fixture. It is not yet formally
accepted. The material sagittal guide excludes free-3D recovery; the
symmetry-collapsed fixed morphology excludes morphology transfer and
independent four-limb control; and the body performs no step, gait cycle, or
walking motion. Per-foot load allocation, repair, encyclopedia admission, and
automatic creature guidance remain absent.

The next safe pipeline stage is an isolated BR13 promotion bundle,
certification-report, and detached-attestation family followed by a complete
fresh-process campaign. Until that campaign is reconciled and a bounded
milestone decision is recorded, the formal ladder remains **13/18 accepted
(72.2%)** and the accepted catalog remains **48 observation-only entries**.

## 68. BR13 promotion trust family — 2026-07-23

BR13 now has an isolated source-pinned promotion contract. The fixed campaign
contains all five commissioned cells, runs each twice in a fresh Godot target
process, retains all ten declared results, and forbids cherry-picking.

Evidence roles are:

| Role | Cells | Programs | Assertions per replicate | Two-replicate assertions |
|---|---|---:|---:|---:|
| Milestone | BR13.0, BR13.2, BR13.4 | 3 | 57 | 114 |
| Supplementary | none | 0 | 0 | 0 |
| Integrity | BR13.1, BR13.3 | 2 | 33 | 66 |
| Total | BR13.0-BR13.4 | 5 | 90 | 180 |

The promotion family adds:

- a strict campaign schema with the verbatim BR13.4 analyzer boundary;
- exact sorted clean-commit source inventories;
- strict per-run metrics and evidence-capsule schemas;
- production bundle attestation through the existing generic publication
  domain;
- a BR13-specific certification-report schema;
- a distinct detached BR13 report-attestation domain;
- independent complete report readback of every capsule, receipt, source
  inventory, artifact hash, target-process witness, ordered assertion list,
  and raw transcript; and
- a PowerShell 7.5 operator that can run or preflight the complete campaign
  but cannot create a milestone decision or knowledge entry.

The report schema positively represents only constrained planar get-up,
matched zero-command control, and the exact stable terminal stance. It makes
free-3D recovery, morphology transfer, independent four-limb control, general
standing, bracing, fall arrest, per-foot allocation, gait, walking, accepted
knowledge, and automatic guidance unrepresentable.

Promotion-contract verification passed **33/33 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br13_promotion_contract_probe3\20260723T175443527\report.json
```

The complete implementation-plus-promotion family passed **6/6 programs and
123/123 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br13_prepromotion_all\20260723T175648073\report.json
```

The operator contract and exact boundary are documented in
`docs/BR13_CANONICAL_GET_UP_CERTIFICATION_OPERATOR.md` and
`docs/adr/ADR-014_BR13_CANONICAL_GET_UP_EVIDENCE_BOUNDARY.md`.

At this checkpoint the trust machinery exists but no clean production
campaign has yet been executed. BR13 therefore remains formally unaccepted,
the ladder remains **13/18 accepted (72.2%)**, and the catalog remains
**48 observation-only entries**.

## 69. BR13 clean certification and bounded acceptance — 2026-07-23

The clean BR13 production campaign completed successfully at exact source
commit `897b93c2c1094081dd2cf411b99f967770d8c0bc`:

```text
certification: br13_20260723T225845Z_897b93c2
programs: 5/5
fresh-process replicas: 2 per program
production-attested bundles: 10/10
assertions: 180/180
milestone assertions: 114/114
integrity assertions: 66/66
target-process invocations: 10
unique target PIDs: 10
PID recycle events: 0
complete final readback: true
```

The immutable certification identities are:

```text
campaign:
  sha256:e90173e3974c4b50d5d5dcde29761da60c4adbab4890ee57ea87015a892aa797
source inventory:
  sha256:45c727f1732261bc8da8afd0ad42e9bbd94a5d6adab3880058f0ded1afa56683
report:
  sha256:27e3c39fcd78337fe4f749534e0824b2ba1388dafea0bbd0dbfaf82f127f865e
detached report receipt:
  sha256:21593c72a0c39edc64f20aeac3d9461836784033d483c095f1f150f49d028220
engine:
  sha256:baa909d0a905021da80cfc831713e9d3ba4bd0935ac3b93ba4c77dc140cfecc4
```

Independent production verification reopened the complete report and
returned `can_promote: true` while matching the certification, report,
receipt, campaign, source, and engine identities.

The reviewed recommendation is
`docs/BR13_CANONICAL_GET_UP_MILESTONE_DECISION_REVIEW.md`. Under Cole's
delegated instruction to accept the bounded recommendation and continue,
append-only decision `BR13_CONSTRAINED_CANONICAL_GET_UP_DECISION_V1` accepts
only the exact BR13.0, BR13.2, and BR13.4 milestone program claim scopes.
BR13.1 and BR13.3 remain integrity-only.

The positive accepted conclusion is exactly:

```text
constrained_planar_get_up
```

The accepted physical facts are:

- the exact symmetry-collapsed quadruped begins in observed semantic prone;
- each active seed establishes ordinary front-pair and rear-pair distal
  support with finite paired hinge actuation and complete receipts;
- whole-system COM rises by at least `0.35 m`;
- transition-integrated actuator work and the declared mechanical,
  residual-inferred contact-dissipation, guide-work, and energy-residual
  account close;
- recovery control hands exclusively to stance control;
- the active world completes the stable stance dwell; and
- every matched zero-command control remains prone with zero commands and
  actuator work.

The decision preserves the material sagittal guide, mirrored-pair collapse,
fixed morphology, exact actuator, thresholds, seeds, 120 Hz physics rate,
floor, source, and Godot/Jolt version. It accepts no free-3D or transferred
recovery, independent four-limb control, general standing or bracing,
per-foot load allocation, step, gait, candidate walking, or walking.

The decision admits zero knowledge entries and authorizes no repair rule,
automatic application, or creature guidance. Its adversarial contract passed
**34/34 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br13_decision_probe\20260723T181207851\report.json
```

The formal ladder advances to **14/18 accepted (77.8%)**. The accepted
catalog remains **48 observation-only entries** until a separate append-only
BR13 knowledge operation is performed.

The next formal capability is BR14A: remove recovery/balance scaffolds for one
spatially controllable canonical morphology and separately prove the required
free-3D stance, brace, catch/fall-arrest, and feasible get-up cells. A walking
attempt is still later: L7 first requires load transfer and constrained steps,
and L8.3 is the first fully free flat-floor `candidate_walking` attempt.

## 70. BR13 observation-only knowledge admission — 2026-07-23

A separate append-only operation admitted exactly three observations from the
accepted BR13 milestone programs:

| Cell | Entry | Role |
|---|---|---|
| BR13.0 | `BR13.0.canonical_get_up_profile_and_phase_order.v1` | Exact profile, semantic pose observation, and phase-order observation |
| BR13.2 | `BR13.2.recovery_energy_and_reserve_accounting.v1` | Exact finite reserve and transition-energy accounting observation |
| BR13.4 | `BR13.4.constrained_planar_get_up.v1` | Exact guided fixed-morphology physical get-up observation |

BR13.1 and BR13.3 remain integrity-only and are not knowledge entries. The
entry schema structurally requires empty `parameter_effects` and
`minimal_repair_rules` arrays, `observation_only` mode, false automatic
application, and false automatic creature guidance.

Every entry reopens the byte-pinned accepted decision, certification report,
and detached report receipt and then revalidates both production-attested
bundles for its exact milestone program. Historical report verification is
anchored to the accepted source snapshot; later repository growth does not
incorrectly redefine the old campaign's source closure.

The BR13 admission contract passed **23/23 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br13_knowledge\20260723T182913134\report.json
```

The complete cross-generation knowledge regression passed **11/11 programs**
with no failure, timeout, or unexpected engine error:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br13_all_knowledge\20260723T182933400\report.json
```

The accepted catalog now contains **51 observation-only entries**. This
changes what the system may remember, not what it may automatically do:
repair rules remain zero, automatic application remains false, and creature
guidance remains unauthorized. The maximum physical claim remains exactly
`constrained_planar_get_up`; a step, gait, candidate walking, and walking
remain unproved.

## 71. BR14A.0 prephysical spatial-rank bootstrap — 2026-07-23

The first morphology-independent BR14A component is implemented in
`scripts/lab/mechanics/spatial_wrench_rank_oracle.gd`, with the complete
boundary in `docs/BR14A_SPATIAL_CONTROLLABILITY_BOOTSTRAP.md`.

The oracle:

- accepts only the centroidal-world reference frame;
- requires every force/moment axis to be task-required or intentionally
  omitted;
- nondimensionalizes moment rows by one declared characteristic morphology
  length before rank analysis;
- separates ordinary-contact, analytic-actuator, and scaffold columns;
- reports all-column, non-scaffold, and per-source linearized rank;
- reports each axis's projection residual with and without scaffold columns;
  and
- refuses broader claims, guidance permission, nonfinite columns, duplicate
  identities, incomplete axis partitions, zero columns, and post-seal
  mutation.

The synthetic scaffold control demonstrates the key gate: all-column rank is
six, non-scaffold rank is five, and the required roll-moment axis is named
scaffold-dependent. A guide therefore cannot silently turn an underactuated
candidate into a spatially controllable one.

The focused test passed **27/27 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_spatial_rank_final2\20260723T185913882\report.json
```

No canonical morphology is selected. Rank remains a nondimensionalized
linear upper bound and establishes no unilateral/friction feasibility,
actuator reach or capacity, dynamic controllability, scaffold removal,
free-3D stance, bracing, catch, fall arrest, get-up, step, gait, candidate
walking, walking, repair, or guidance. The formal ladder remains **14/18
accepted (77.8%)**.

## 72. BR14A.1 prephysical ordinary-contact feasibility — 2026-07-23

The second morphology-independent BR14A component is implemented in
`scripts/lab/mechanics/spatial_contact_feasibility_oracle.gd` and bounded in
`docs/BR14A_SPATIAL_CONTROLLABILITY_BOOTSTRAP.md`.

The oracle accepts one shared whole-system center of mass and a desired
centroidal-world wrench. Each declared ordinary contact supplies a position,
right-handed orthonormal frame, friction coefficient, and positive
normal-command capacity. It builds an inscribed four-ray friction pyramid,
requires every ray coefficient to remain nonnegative, caps the coefficient
sum independently for each contact, nondimensionalizes moments by the
declared characteristic length, and uses projected gradient descent with
per-contact simplex projection.

The synthetic test establishes:

- bounded positive support without contact pulling;
- conservative friction rejection;
- bounded moment production by separated contacts;
- rejection beyond the declared normal-command capacities; and
- fail-closed frame, authority, numeric, claim, guidance, and digest
  boundaries.

The BR14A.1 program passed **23/23 assertions** inside the combined
BR14A.0-BR14A.1 regression, which passed **50/50 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_prephysical_final\20260723T190941499\report.json
```

This is exactly
`prephysical_polyhedral_contact_wrench_feasibility_only`. The returned
per-contact values are proposed mathematical commands, not measured loads.
The four-ray pyramid is conservative rather than an exact Coulomb cone.
Nothing in this cell proves inverse-kinematic reach, collision clearance,
actuator torque/speed/power, structure, dynamics, contact maintenance, a
canonical morphology, free-3D stance or recovery, a step, gait, candidate
walking, walking, repair, automatic application, or guidance.

The formal ladder remains **14/18 accepted (77.8%)**. The selected-candidate
application and every physical BR14A cell remain open behind the deferred
canonical-morphology preregistration; the following checkpoint adds the
generic BR14A.2 upper-bound tool.

## 73. BR14A.2 prephysical actuator-load envelope — 2026-07-23

The third morphology-independent BR14A component is implemented in
`scripts/lab/mechanics/spatial_actuator_load_oracle.gd`.

For each declared revolute joint, it computes the exact generalized load from
declared contact-force commands:

\[
\tau_i
=
\hat{\mathbf{a}}_i \cdot
\left[
(\mathbf{p}-\mathbf{o}_i)\times\mathbf{f}
\right]
\]

One distal contact may contribute to multiple declared ancestor joints. The
oracle adds an explicitly incomplete analytic bias, takes the opposing active
command, verifies the nested actuator specification under the accepted BR4
digest contract, and checks:

- full-activation torque-speed capacity;
- positive-work or absorption-power capacity;
- structural joint-torque capacity; and
- minimum distance from either joint limit.

The focused BR14A.2 program passed **26/26 assertions**. The combined
BR14A.0-BR14A.2 regression passed **76/76 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_generic_final\20260723T191912151\report.json
```

This is exactly
`prephysical_declared_contact_command_to_actuator_envelope_only`. It does not
establish contact feasibility, measured load, complete gravity/inertia bias,
activation or torque-rate feasibility, inverse-kinematic reach, collision
clearance, structure beyond the declared joint torque cap, a canonical
morphology, dynamics, free-3D stance/recovery, a step, gait, candidate
walking, walking, repair, automatic application, or guidance.

The formal ladder remains **14/18 accepted (77.8%)**. The next checkpoint
selects and preregisters the exact canonical body required before BR14A.3 can
become a physical free-3D stance cell.

## 74. BR14A canonical spatial quadruped preregistration — 2026-07-23

Under Cole's delegated design judgment, the recommended wide, low,
independently actuated quadruped is now the exact BR14A laboratory reference
in `scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd`.

The selection conservatively expands the accepted BR13 fixture:

- torso mass remains `6 kg` and total system mass remains `8 kg`;
- each `1 kg` symmetry-collapsed limb pair becomes two distinct `0.5 kg`
  physical limbs;
- each limb has hip-abduction, hip-pitch, and knee-pitch DOFs;
- the hip-pitch pair's `60 N·m / 500 W` envelope is split left/right to
  `30 N·m / 250 W`; the new hip-abduction and knee roles use the same
  explicit-lab per-DOF candidate cap without claiming anatomical derivation;
- four ordinary contacts form a `0.44 m x 0.44 m` support rectangle;
- all six spatial wrench axes are required;
- allowed scaffolds are exactly empty; and
- the current `120 Hz`, `20/4` solver configuration and three promotion-intent
  seeds are pinned.

The selected static pose passes all three prephysical screens:

- ordinary-contact non-scaffold linearized rank is six;
- the conservative contact oracle allocates the exact `78.4 N` weight command
  evenly across four bounded contacts; and
- all twelve declared joint loads fit the split full-activation BR4
  torque/speed/power, structural, and joint-limit envelopes below 20%
  directional utilization.

The preregistered low-friction lateral-wrench and disabled front-left
abduction controls fail at their predicted constraints. Scaffold injection,
mass drift, walking authority, and final-game-creature relabeling fail the
exact profile.

The profile program passed **23/23 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_selected_profile_final2\20260723T193236391\report.json
```

The clean combined BR14A generic-plus-profile regression passed **99/99
assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_selected_profile_final2\20260723T193236391\report.json
```

This establishes only
`canonical_spatial_quadruped_preregistered_prephysically`. No physics body was
constructed. Inverse-kinematic reach, collision clearance, complete
gravity/inertia bias, activation/rate transients, physical contact
maintenance, free-3D stance/recovery, morphology transfer, final game
anatomy, a step, gait, candidate walking, walking, repair, automatic
application, and guidance remain unproved. The formal ladder remains **14/18
accepted (77.8%)**.

## 75. BR14A.3 preregistered free-3D static stance — 2026-07-23

The first physical BR14A cell is implemented and passes. The exact execution
contract in
`scripts/lab/mechanics/canonical_spatial_stance_experiment.gd` binds the
selected profile digest, `120 Hz` / `20/4`, three seeds, `600` trial ticks,
`120` stable-dwell ticks, controller gains and thresholds, one ordinary
floor, no scaffold, and the complete nonclaim boundary before final evidence.

The physical rig in
`scripts/lab/rigs/canonical_spatial_stance_rig.gd` contains one rigid torso,
eight independently simulated limb links, four two-axis hips, four hinge
knees, and twelve receipt-backed equal/opposite joint actuators. It contains
no root pin, world anchor, rail, guide, gimbal, built-in motor, spring, foot
pin, teleport, root wrench, or post-release freeze.

The three active trials produced stable dwells of `416`, `394`, and `423`
ticks. Final active torso heights were `0.408413`, `0.408369`, and `0.408432
m`, with final tilts `0.001618`, `0.000071`, and `0.000142 rad`. All four
active foot bodies retained ordinary floor contact throughout. Every matched
zero-command twin collapsed to approximately `0.148 m` torso height and
recorded zero stable-dwell ticks.

Worst active anchor error was `0.401 mm`, worst hinge-axis error was
`0.003699 rad`, and worst applied torque was `8.029388 N m`. All `7,200`
active joint commands per seed were receipt-complete, and no structural torque
clamp occurred.

The focused physical program passed **13/13 assertions**. The clean combined
BR14A.0-BR14A.3 regression passed **112/112 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_free3d_full\20260723T200430904\report.json
```

This is the first genuine free-3D articulated stance observation, but it is
still commissioning rather than formal milestone acceptance. It establishes
no recovery, protective contact, per-foot measured load allocation,
morphology transfer, final game anatomy, load-transfer step, gait, walking,
repair, automatic application, or creature guidance. The formal ladder
therefore remains **14/18 accepted (77.8%)** while BR14A promotion and
BR14A.5-BR14A.7 remain open.

## 76. BR14A.4 existing-contact free-3D roll arrest — 2026-07-23

The second physical BR14A cell passes. Its exact experiment contract applies
one `+X` torso torque impulse of `0.020 N m s` at tick `360` after both worlds
have established the same four-contact stance. The active world retains
relative-pose feedback; its matched control retains identical static
feedforward joint commands but loses pose feedback after the disturbance.
Both continue to issue twelve receipt-backed joint commands per tick.

The observed peak roll rates were `0.505494`, `0.509828`, and `0.508078 rad/s`.
Every active seed completed the recovery dwell in exactly `66` ticks and
finished near `0.4084 m` torso height. The active roll-rate areas were
`0.016497`, `0.013402`, and `0.015605 rad`. Controls never recovered,
collapsed to `0.1656-0.1705 m`, and accumulated `0.246797-0.269424 rad` of
roll-rate area.

All four active contacts were the same ordinary foot contacts present before
the disturbance. No new contact body, foot target, root controller wrench,
anchor, rail, guide, gimbal, built-in motor, spring, teleport, or post-release
freeze exists. Geometry and torque remained bounded with no structural clamp.

The focused program passed **14/14 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_roll_arrest_probe2\20260723T201803409\report.json
```

The shared-controller BR14A.3 regression passed **13/13** after the extension:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_stance_after_arrest\20260723T202227736\report.json
```

Together with the unchanged 99 prephysical/profile assertions, all six BR14A
programs pass **126/126** in staged verification. This establishes only
`canonical_existing_contact_roll_arrest_observed_in_commissioning`. It is not
formal acceptance, per-foot measured load allocation, new-contact bracing,
fall arrest, get-up, load transfer, step, gait, walking, repair, automatic
application, or guidance. BR14A.5-BR14A.7 and formal promotion remain open;
the formal ladder stays **14/18 accepted (77.8%)**.

## 77. BR14A.5 first protective-contact candidate rejected — 2026-07-23

The first exact free-3D new-protective-contact controller has been built and
falsified without promoting its useful partial event. The candidate uses the
same unpinned nine-body, 12-DOF morphology and ordinary floor as BR14A.3,
shifts support through joint torques, clears the front-right foot with a
bounded measured-Jacobian-transpose controller, applies one matched `+X`
torso torque impulse, and commands an align-then-descend wider touchdown. A
matched control holds the foot clear until its own incidental collapse.

The active seed-`14001` world recorded 20 physically clear ticks before the
disturbance and created a new floor contact at tick `515`, `0.020939 m` from
the exact target. The hold-clear control contacted incidentally at tick
`519`, four ticks later. Every command remained equal/opposite and
receipt-complete, and maximum applied torque was `30.914259 N m`, below the
`40 N m` structural limit.

Because the candidate required every declared seed to pass, this first-seed
failure is an exact early-stop rejection. Seeds `14002` and `14003` were not
executed and receive no conclusion.

Those facts are not enough for BR14A.5. Post-touch contact fraction was only
`0.946067` against a required `0.95`; recovery dwell remained zero; maximum
anchor error reached `0.024501 m` against `0.01 m`; and hinge-axis error
reached `0.379695 rad` against `0.10 rad`. A lower-force probe improved hinge
quality but lost disturbance-time clearance, so there is no commissioned
clearance-quality-recovery overlap for this candidate.

The new read-only whole-system support-margin observer supplies the missing
centroidal diagnosis. The COM margin against the three support feet is
`+0.029147 m` at lift start, but falls to `-0.219007 m` at the disturbance and
reaches `-0.219864 m` before first touch. The open-loop weight shift initially
succeeds; swing reactions then drive the body far outside the live support
triangle. This observer is geometric, not per-foot measured load allocation.
The next candidate must regulate measured COM/support margin while retaining
the existing clearance, geometry, contact-quality, and recovery gates.

The exact early-stop rejection test passes **15/15 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate_support_margin_final\20260723T224301955\report.json
```

The analytic support-margin observer test passes **9/9 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_support_margin_observer_fixed\20260723T225141047\report.json
```

The shared stance and arrest implementation remains unchanged after the new
read-only per-shape semantic contact observer and optional task-torque hooks:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_stance_shared_rig_regression\20260723T221124514\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_arrest_shared_rig_regression\20260723T221317741\report.json
```

BR14A.3 passes **13/13**, BR14A.4 passes **14/14**, and the eight BR14A
programs now pass **150/150 assertions** across their exact positive,
rejection, or observer contracts. BR14A.5 itself remains open. No protective contact,
bracing, fall arrest, get-up, load transfer, step, gait, walking, repair,
automatic application, or guidance has been established. The formal ladder
remains **14/18 accepted (77.8%)**.

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_support_margin_final\20260723T225259199\report.json
```

## 78. BR14A.5 dynamic observer, support allocator, and second candidate rejection — 2026-07-24

The first rejection identified an open-loop centroidal failure, so the next
bounded increment commissioned the missing read-only state and command tools
before another physical candidate was judged.

`scripts/lab/mechanics/spatial_dynamic_support_observer.gd` measures:

- whole-system mass-weighted COM position and velocity;
- signed COM margin against the live ordered support polygon;
- a deliberately limited level-support capture projection
  \(x_c=x+\dot{x}/\sqrt{g/h}\); and
- signed capture margin and polygon centroid.

It fails closed for an empty or invalid body set, nonpositive gravity,
nonconvex/degenerate support polygons, and COM at or below the support plane.
The projection is a controller-state signal for this fixture, not an
articulated capture guarantee, load measurement, bearing classification, or
locomotion claim. Its focused program passes **11/11 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_dynamic_support_observer_fixed\20260724T001834946\report.json
```

`scripts/lab/mechanics/spatial_centroidal_support_controller.gd` is a pure
analytic allocator. It converts measured whole-system state into a bounded
desired external force and roll/pitch moment, then solves the minimum-norm
normal commands for three or more declared ordinary contacts. It rejects
negative normal allocation, friction-pyramid violations, force/moment
residuals, rank loss, and fewer than three contacts. Its output is a command,
never a measured per-foot load, and it performs no physics write. The focused
program passes **13/13 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_centroidal_support_controller_proportional_final\20260724T003711470\report.json
```

The second physical candidate is sealed in
`scripts/lab/mechanics/canonical_spatial_centroidal_contact_candidate.gd` and
executed by
`scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd`. It retains the
same nine-body, 12-DOF, one-floor, zero-scaffold fixture and adds:

- measured COM/capture feedback;
- a causal four-contact to three-contact commanded load-share transition;
- capture-risk-scheduled stance-endpoint corrections;
- three-support roll and pitch command seams;
- a simultaneous smooth swing trajectory; and
- a measured damped-least-squares resolved-rate swing controller.

The physical loop does **not** claim to use the separate analytic support
allocator. Its accounting explicitly reports `support_allocator_used=false`;
support endpoint values are commands rather than contact-load measurements.

The seed-`14001` rejection witness established a genuine partial event:

- lift-entry COM margin: `+0.050844 m`;
- lift-entry capture margin: `+0.051701 m`;
- clear pre-disturbance ticks: `60`;
- one declared noncontroller roll impulse;
- provisional retouch at tick `911`; and
- maximum applied torque: `31.834711 N m`, with no `40 N m` structural clamp.

The candidate nevertheless fails the preregistered overlap:

- touchdown target error is `0.087228 m` against `0.04 m`;
- post-touch contact fraction is `0.221080` against `0.95`;
- minimum COM margin is `-0.017596 m`;
- minimum capture margin is `-0.038665 m`;
- maximum anchor error is `0.013050 m` against `0.01 m`;
- maximum hinge-axis error is `0.178334 rad` against `0.10 rad`;
- recovery dwell remains zero; and
- at executed tick `1300`, the read-only observer refuses an inverted
  COM/support-plane state with
  `SPATIAL_DYNAMIC_SUPPORT_COM_HEIGHT_INVALID`.

Because the exact candidate required all three seeds to pass, this first-seed
failure rejects only the second candidate. Seeds `14002` and `14003` were not
executed and receive no conclusion. The morphology and future controller
families remain open.

The exact second-candidate rejection program passes **19/19 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_centroidal_rejection\20260724T015126984\report.json
```

The clean complete BR14A family now passes **11/11 programs and 193/193
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_centroidal_full\20260724T015307417\report.json
```

The complete experimental regression passes **106/106 programs and 2077/2077
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_experimental_centroidal_regression\20260724T020440316\report.json
```

The released regression remains **62/62 programs and 1118/1118 assertions**,
with zero failures, timeouts, or unexpected engine errors. Its one deliberately
generated engine-error fixture remains correctly classified as expected:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_released_centroidal_regression\20260724T022207929\report.json
```

BR14A.5 remains open. The new evidence proves that this exact controller can
produce a real physical clearance and provisional retouch, but not a valid
protective contact or recovery. It establishes no per-foot measured load
allocation, bearing, load transfer, articulated capture guarantee, bracing,
fall arrest, get-up, locomotor step, gait, walking, repair, automatic
application, or creature guidance. The formal ladder remains **14/18 accepted
(77.8%)**.

## 79. BR14A.5 preferred-wrench transition and third candidate rejection — 2026-07-24

Candidate 3 closes a different seam without weakening the candidate-2 gates.
`scripts/lab/mechanics/spatial_centroidal_support_controller.gd` now accepts
an optional nonnegative preferred normal command for each declared contact.
For an underdetermined contact set, it solves the minimum correction from that
preferred split while still satisfying the exact total-force and roll/pitch
moment equations. The preference is a command-space nullspace objective, not
a measured per-foot load.

The analytic test now includes a four-contact control whose asymmetric
preferred normals already satisfy the requested wrench. The allocator
preserves that split exactly, continues to close force and moment residuals,
and rejects a negative preference. The expanded focused program passes
**15/15 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_allocator_preference2\20260724T025416198\report.json
```

The sealed physical contract is
`scripts/lab/mechanics/canonical_spatial_wrench_contact_candidate.gd`.
It adds:

- a preferred four-contact-to-three-contact unload transition;
- allocator ownership of load redistribution and torso roll/pitch while the
  stance endpoint loop retains geometry and height duties;
- discrete authority projection through `1.0`, `0.75`, `0.50`, `0.25`, and
  `0.0`, with no interpolation or force-cap clipping; and
- an actually executed vertical-then-horizontal swing path using the
  previously declared `vertical_lift_complete_tick`.

The exact seed-`14001` witness establishes the pre-lift support gate, then
fails closed before the planned disturbance when the swing contact physically
leaves the floor:

- executed ticks: `783`;
- allocator commands: `64`;
- allocator solve attempts: `221`;
- last feasible-authority scale: none, even after feedback is reduced to
  zero;
- required rear-right normal command: `41.019270 N`;
- pinned per-contact normal capacity: `39.2 N`;
- minimum normal reserve: `-1.819270 N`;
- minimum COM margin: `+0.011292 m`;
- minimum capture margin: `-0.073737 m`;
- maximum applied torque: `31.714419 N m`;
- structural saturation count: zero; and
- force and roll/pitch residuals remain below `1e-5`.

The allocator refuses rather than clipping the command or pretending that
ordinary contact presence proves bearing. Every executed joint command remains
equal/opposite and receipt-complete. The exact physical rejection program
passes **18/18 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate3_rejection\20260724T025428374\report.json
```

The clean complete BR14A family passes **12/12 programs and 213/213
assertions**, with zero failures, timeouts, engine errors, or unexpected
engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate3_family\20260724T025549480\report.json
```

This rejects only the exact third all-seed candidate. Seeds `14002` and
`14003` receive no conclusion. The result does not prove the morphology or all
future controllers incapable. It instead identifies the next controller
requirement: swing-path progress must be gated by predicted three-contact
wrench feasibility; a fixed tick schedule cannot be allowed to cross the
contact transition after its feasible set has disappeared.

BR14A.5 remains open. No protective contact, free-3D recovery, per-foot
measured load allocation, bearing, load transfer, articulated capture
guarantee, bracing, fall arrest, get-up, locomotor step, gait, walking, repair,
automatic application, or creature guidance is established. The formal
ladder remains **14/18 accepted (77.8%)**.

## 80. BR14A.5 predictive event gate and fourth candidate rejection — 2026-07-24

Candidate 3 proved that a fixed-time swing may cross into an infeasible
three-contact wrench before its controller notices. Candidate 4 therefore
replaces wall-clock swing progress with an explicit readiness state machine in
`scripts/lab/mechanics/canonical_spatial_feasibility_gated_contact_candidate.gd`.
Its physical implementation remains in the shared
`canonical_spatial_centroidal_contact_rig.gd`.

At 120 Hz, the candidate performs a read-only zero-feedback three-contact
wrench preflight and checks:

- unilateral and pinned contact-normal capacity;
- force and roll/pitch residual closure;
- the already declared COM handoff margin;
- the linearized capture handoff margin;
- the proven stance-height envelope; and
- a sealed `0.04 rad` swing-attitude deviation envelope.

Sensing remains at 120 Hz while swing phase advances only once every four
physics ticks. Any failed readiness check retreats four path ticks. After
retreat reaches zero, the swing override and whole-system allocator disengage.
Rearming requires 40 consecutive ticks above the higher release margin. The
disturbance and landing phases remain causally suppressed unless the swing path
actually completes.

The exact seed-`14001` run reaches the full `1700`-tick horizon:

- predictive checks: `980`;
- passing checks: `9`;
- paused/retreat checks: `971`;
- retreated path ticks: `3`;
- final path progress: `0 / 120`;
- applied allocator commands: `9`;
- applied allocator infeasibility count: zero;
- minimum applied allocator normal reserve: `+0.911446 N`;
- disturbance operations: zero;
- new contacts: zero;
- maximum applied torque: `17.423652 N m`;
- structural saturation count: zero;
- maximum anchor error: `0.000887 m`;
- maximum hinge-axis error: `0.010583 rad`;
- final torso height: `0.404436 m`;
- final tilt: `0.010877 rad`; and
- final full angular speed: `0.003486 rad/s`.

This is a safe rejection rather than a collapse. The exact controller attempts
three phase increments, recognizes that readiness is leaving its feasible
envelope, retreats, suppresses the disturbance, retains ordinary four-contact
stance, and returns near the declared height/tilt/speed envelope. It is still
rejected because it never re-establishes the three-contact readiness gate,
never completes the swing path, and never clears the selected foot.

The exact fourth-candidate rejection program passes **18/18 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate4_rejection\20260724T033706160\report.json
```

The corrected complete BR14A family passes **13/13 programs and 231/231
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate4_family360\20260724T035400703\report.json
```

The rejection identifies a prerequisite rather than a new tuning target:
BR14A needs a separately commissioned four-contact global-pose/readiness
recovery cell that can move whole-system COM back into a declared
three-contact handoff while preserving height, attitude, contacts, joint
geometry, and actuator limits. Relative joint-pose stance is not that
capability, and the existing small roll-arrest cell does not prove it.

Only this exact all-seed candidate is rejected; seeds `14002` and `14003`
receive no conclusion. BR14A.5 remains open. No protective contact, free-3D
recovery, per-foot measured load allocation, bearing, load transfer,
articulated capture guarantee, bracing, fall arrest, get-up, locomotor step,
gait, walking, repair, automatic application, or creature guidance is
established. The formal ladder remains **14/18 accepted (77.8%)**.

## 87. BR14A.5 bounded post-recontact body-translation prerequisite — 2026-07-24

Candidate 10 retains candidate 9's targeted front-right release, relocated
ordinary recontact, and long-horizon recovery branch. It adds no authority
until 600 ticks after recontact. At that point, the existing receipt-backed
four-endpoint torque controller is rebased to the measured four-contact pose
and ramps a `0.030 m` whole-system target along the declared positive world-X
axis over 480 ticks. The exact program runs through tick `2299` and requires at
least 900 translation-command ticks.

The whole-system allocator is deliberately not reactivated for this phase.
It correctly refused the moved-foot topology during development rather than
silently inventing a feasible load distribution. Candidate 10 instead uses
only bounded Jacobian-transpose endpoint torques, applied as equal-and-opposite
parent/child joint torque pairs through the existing receipt path. It adds no
root force or torque, foot pin, rail, guide, teleport, built-in motor, spring,
or per-foot load fiction.

The exact all-seed results are:

| Seed | Translation phase | COM displacement X/Z | Torso displacement X/Z | Worst translation-phase foot slip | Final placed-foot target error |
|---:|---:|---:|---:|---:|---:|
| `14001` | ticks `1333-2299` | `+0.014894 / -0.000780 m` | `+0.016732 / -0.000880 m` | `0.002480 m` | `0.050115 m` |
| `14002` | ticks `1332-2299` | `+0.021223 / -0.001722 m` | `+0.023756 / -0.001934 m` | `0.003760 m` | `0.048978 m` |
| `14003` | ticks `1333-2299` | `+0.019155 / -0.000055 m` | `+0.021402 / -0.000042 m` | `0.003469 m` | `0.061828 m` |

Every seed advances both whole-system COM and torso by at least `0.012 m`
along positive world X while remaining within `0.003 m` of zero lateral
translation. All four feet slip less than `0.004 m` during the commanded
translation phase. Every world finishes with four ordinary contacts, zero
torso-floor contact, intact joint geometry, receipt-complete actuation, zero
structural saturation, and candidate 9's long-horizon recovery predicate.

The exact positive prerequisite passes **22/22 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate10_exact_repaired\20260724T114543185\report.json
```

The complete post-change BR14A family passes **20/20 programs and 374/374
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate10_family_repaired\20260724T115101256\report.json
```

The result is real forward body motion, but it is not yet a complete
locomotor step. The placed front-right foot finishes `0.048978-0.061828 m`
from its original candidate-8 target. Strong and gentle one-foot holds and a
coordinated four-foot hold were tested during development; all three
destabilized at least one exact seed and were removed rather than
commissioned. Candidate 10 therefore proves only that bounded body translation
can follow the exact relocation/recontact/recovery sequence. It does not
prove that targeted placement and subsequent body advance can coexist.

The next prerequisite is an integrated contact-target controller that retains
the relocated foot near its declared target while translating the body,
without unilateral foot pinning or relabeling commanded endpoint forces as
measured loads. A second foot transition, complete locomotor step, repeated
stepping, gait, walking, BR14A.5 formal acceptance, generalized standing or
recovery, repair, automatic application, and creature guidance remain open.
The formal ladder remains **14/18 accepted (77.8%)**.

## 88. BR14A.5 bounded atomic locomotor step — 2026-07-24

Candidate 11 closes the narrower physical question that Candidate 10 left
unnamed: does the unchanged exact program contain one complete
support-to-support locomotor cycle even though it does not retain the nominal
foothold target? The answer is yes.

The physical controller is unchanged from Candidate 10. The selected
front-right foot leaves ordinary support, moves to a bounded targeted ordinary
recontact, the nine-body fixture recovers for 600 uncommanded ticks, the four
measured endpoint references are rebased, and receipt-backed paired joint
torques advance whole-system COM and torso along declared positive world X.
Candidate 11 adds no force, actuator, contact, scaffold, timing, gain, or solver
authority. It adds:

- a final moved-foot displacement vector measured from the semantic release
  pose;
- an exact atomic-step policy that requires the Candidate 8, 9, and 10
  predicates together;
- a `0.035-0.065 m` final moved-foot displacement envelope;
- a `0.065 m` maximum final nominal-foothold error that bounds, but does not
  hide, landing skid;
- the existing `0.012 m` minimum directed COM and torso translations;
- a `0.003 m` maximum lateral body-translation envelope;
- the existing `0.010 m` planted translation-phase foot-slip envelope; and
- an explicit 600-tick minimum separation between ordinary recontact and body
  translation.

The exact results are:

| Seed | Final moved-foot X/Z from release | Final moved-foot distance | Final nominal-target error | COM X/Z after settling | Torso X/Z after settling | Worst translation-phase foot slip |
|---:|---:|---:|---:|---:|---:|---:|
| `14001` | `-0.014650 / +0.036206 m` | `0.039057 m` | `0.050115 m` | `+0.014894 / -0.000780 m` | `+0.016732 / -0.000880 m` | `0.002480 m` |
| `14002` | `-0.004062 / +0.042660 m` | `0.042853 m` | `0.048978 m` | `+0.021223 / -0.001722 m` | `+0.023756 / -0.001934 m` | `0.003760 m` |
| `14003` | `-0.021755 / +0.045598 m` | `0.050522 m` | `0.061828 m` | `+0.019155 / -0.000055 m` | `+0.021402 / -0.000042 m` | `0.003469 m` |

All three fresh worlds set
`bounded_atomic_locomotor_step_observed=true` and
`locomotor_step_established=true`. They finish at `0.398493-0.403542 m`
torso height, `0.003485-0.014473 rad` tilt, and
`0.000097-0.000129 rad/s` angular speed with four ordinary contacts, zero
torso contact, intact joint geometry, complete paired receipts, zero
structural saturation, and zero allocator infeasibility.

The exact program passes **21/21 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate11_atomic_exact\20260724T135631797\report.json
```

The unchanged Candidate 10 compatibility program separately passes **22/22
assertions** and continues to report no locomotor-step establishment because
the atomic claim is exact-contract opt-in rather than a retroactive relabeling:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate11_candidate10_regression\20260724T140233061\report.json
```

The complete BR14A family passes **21/21 programs and 395/395 assertions**,
with zero failures, timeouts, engine errors, or unexpected engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate11_atomic_family\20260724T140735774\report.json
```

Development rejected several broader controllers before this boundary was
selected. Directly dragging the planted foot back to the nominal target
created seed-specific pitch divergence. Stronger endpoint stiffness failed
nonlinearly. Delayed retention allowed excessive landing skid. A slower
three-contact swing approach exceeded the safe three-contact window. Fixed
world anchoring overconstrained the landing and destabilized later translation.
Those variants were removed and are not commissioned evidence.

This is the first exact physical **locomotor step** in the ground-up program,
but it is deliberately not called accurate targeted stepping. The foot's
final lateral/backward seating offset is material and remains a controller
quality defect. The result establishes no second contact transition,
left/right alternation, repeated stepping, gait, candidate walking, walking,
terrain or morphology transfer, per-foot measured load allocation, formal
BR14A acceptance, accepted knowledge, repair, automatic application, or
creature guidance. The formal ladder remains **14/18 accepted (77.8%)**.

## 86. BR14A.5 long-horizon targeted relocation recovery prerequisite — 2026-07-24

Candidate 9 extends candidate 8 from its bounded tick-`780` result to the
original tick-`1699` horizon. The foot-release and relocation sequence is
unchanged. New authority begins only after the engine reports ordinary
relocated recontact and consists of bounded relative joint-rate damping sent
through the existing paired-torque command and receipt path.

A uniform all-joint damper rescued seed `14001` but destabilized the two seeds
that already recovered without it. Swing-limb-only damping preserved seeds
`14002` and `14003` but left seed `14001` in a low tilted equilibrium. The
sealed controller therefore observes the Euclidean norm of the three swing
joint rates at recontact:

- At or above `3.7 rad/s`, it damps all twelve joints.
- Below `3.7 rad/s`, it damps only the three swing-limb joints.
- The damping gain is `0.2 N m s/rad`.
- Every added joint command is capped at `0.5 N m`.
- No root force, root torque, pin, rail, guide, teleport, built-in motor,
  spring, or contact-load fiction is added.

The exact all-seed results are:

| Seed | Swing-rate norm | Damping branch | Damping ticks | Final height | Final tilt | Final angular speed |
|---:|---:|---|---:|---:|---:|---:|
| `14001` | `4.026535 rad/s` | all twelve joints | `967` | `0.397865 m` | `0.019160 rad` | `0.010973 rad/s` |
| `14002` | `3.420490 rad/s` | swing limb only | `968` | `0.400649 m` | `0.023190 rad` | `0.025664 rad/s` |
| `14003` | `3.366267 rad/s` | swing limb only | `967` | `0.402710 m` | `0.016102 rad` | `0.004032 rad/s` |

All three worlds finish with four ordinary contacts, zero torso-floor contact,
zero structural saturation, feasible allocator history, paired
receipt-complete actuation, and intact joint geometry. The exact positive
prerequisite passes **23/23 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate9_exact\20260724T094620316\report.json
```

Candidate 8 remains unchanged at **23/23 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate9_candidate8_regression\20260724T095052873\report.json
```

The complete post-change BR14A family passes **19/19 programs and 352/352
assertions**, with zero failures, timeouts, or unexpected engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate9_family\20260724T095431479\report.json
```

This is the first all-seed long-horizon recovery after a real targeted
single-foot relocation in the unpinned free-3D fixture. The adaptive threshold
was developed from these same three seeds, so it is not an independent or
out-of-sample robustness result. The program commands no body translation and
does not transition a second foot. It therefore establishes neither a
complete locomotor step nor repeatable stepping. BR14A.5, generalized
standing or recovery, bracing, fall arrest, get-up, gait, walking, per-foot
load allocation, formal acceptance, encyclopedia admission, repair,
automatic application, and creature guidance remain open. The formal ladder
remains **14/18 accepted (77.8%)**.

## 85. BR14A.5 bounded targeted relocation/recontact prerequisite — 2026-07-24

Candidate 8 takes the semantic contact transition established by candidate 7
and adds the first controlled horizontal foot placement. The front-right
distal body is removed from commanded support, the other three contacts retain
the bounded whole-system allocator, and the same Jacobian-transpose task
family commands a `0.020 m` horizontal offset before ordinary floor
recontact. The controller does not switch to the previously unstable
free-space resolved-rate servo.

The exact all-seed results are:

| Seed | Release tick | Semantic absence | Recontact tick | Horizontal displacement | Horizontal target error | Final height | Final tilt |
|---:|---:|---:|---:|---:|---:|---:|---:|
| `14001` | `725` | `8` ticks | `733` | `0.021375 m` | `0.001594 m` | `0.402973 m` | `0.051514 rad` |
| `14002` | `724` | `8` ticks | `732` | `0.026687 m` | `0.006687 m` | `0.407974 m` | `0.016543 rad` |
| `14003` | `725` | `8` ticks | `733` | `0.021483 m` | `0.002285 m` | `0.410185 m` | `0.038983 rad` |

All three fresh physical worlds complete the exact `781`-tick horizon. Each
retains all four ordinary contacts, zero torso-floor contacts, paired
receipt-complete actuation, zero structural saturation, feasible physically
applied allocator commands, and the source geometry limits. The legacy
logical swing path remains at zero and the external disturbance is
suppressed, so the new relocated semantic contact is accounted separately
from the older protective-touchdown path.

The exact positive prerequisite passes **23/23 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate8_targeted_relocation_exact\20260724T084003365\report.json
```

Candidate 7 remains unchanged at **20/20 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate8_candidate7_regression\20260724T084151856\report.json
```

The expanded complete BR14A family passed its post-change regression:
**18/18 programs** and **329/329 assertions**, with zero failures, timeouts,
or unexpected engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate8_family\20260724T084533836\report.json
```

The bounded horizon is controlling. A development-only `1700`-tick extension
recovers seeds `14002` and `14003`, but seed `14001` later settles at
`0.277548 m` torso height and `0.455552 rad` tilt with geometry outside the
commissioning envelope. That full-seed failure rejects long-horizon recovery
for this candidate. The positive result therefore establishes only accurate
bounded single-foot relocation/recontact. It does not establish complete
support transfer, body translation, a complete locomotor step, BR14A.5,
standing recovery, bracing, fall arrest, get-up, gait, walking, per-foot load
allocation, formal acceptance, encyclopedia admission, repair, automatic
application, or creature guidance. The formal ladder remains **14/18
accepted (77.8%)**.

## 83. BR14A.5 contact-state lift and sixth candidate rejection — 2026-07-24

Candidate 6 tests an explicit hybrid controller boundary rather than another
load-command ramp. At release entry it:

- excludes the selected front-right foot from the **commanded** support
  topology while continuing to observe its physical contact independently;
- assigns the declared whole-system wrench to the other three support
  commands;
- applies a vertical Jacobian-transpose ground-release task;
- permits a positive measured shape gap to rebase the actual foot pose; and
- executes one exact eight-tick release commitment without advancing the
  logical swing path, after which the predictive wrench/COM/capture gate again
  controls progress.

The distinction between geometry and engine contact is decisive. On seed
`14001`, the foot center reaches a `0.002358 m` positive gap relative to its
nominal touching height at tick `721`, but Jolt's semantic manifold remains
present. The mode switch is therefore recorded, but never relabeled physical
contact removal. Across the complete `1700`-tick horizon:

- semantic contact-absence ticks after lift: zero;
- first semantic contact-absence tick: none;
- bounded release-commitment ticks: `8`;
- maximum logical path progress: `2 / 120`;
- final logical path progress: zero;
- clearance, disturbance, touchdown, and new-contact counts: zero; and
- every physically applied three-support allocator command remains feasible.

The safe retreat finishes at:

- torso height: `0.404864 m`;
- final tilt: `0.008872 rad`;
- final angular speed: `0.014642 rad/s`;
- maximum anchor error: `0.000877 m`;
- maximum hinge-axis error: `0.007873 rad`;
- maximum applied torque: `21.104205 N m`; and
- structural saturation count: zero.

The exact sixth-candidate rejection program passes **19/19 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate6_rejection\20260724T063132763\report.json
```

The expanded complete BR14A family passes **16/16 programs and 286/286
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate6_family\20260724T063649456\report.json
```

This rejects only the exact all-seed candidate; seeds `14002` and `14003`
receive no conclusion. The next prerequisite is a contact-complementarity-aware
release using coordinated joint/posture retraction, with semantic contact
removal required before the free-space swing servo takes authority. Commanded
support topology, positive geometric gap, and semantic contact presence remain
separate observations; none is per-foot measured load or bearing. BR14A.5,
contact removal, articulated three-contact bearing, free-3D recovery, bracing,
fall arrest, get-up, locomotor step, gait, walking, repair, automatic
application, and creature guidance remain open. The formal ladder remains
**14/18 accepted (77.8%)**.

## 84. BR14A.5 bounded semantic release/recontact prerequisite — 2026-07-24

Candidate 7 closes the contact-removal prerequisite without pretending it
closes BR14A.5. The selected front-right foot is excluded from the commanded
support topology, the declared whole-system wrench remains assigned to the
other three support commands, and a bounded vertical Jacobian-transpose task
continues until Jolt reports that the selected distal shape is absent from the
ordinary-floor contact manifold. A geometric gap alone cannot latch this
candidate.

The exact program ends at tick `840` (`841` executed ticks). It deliberately
freezes logical swing-path progress at zero and suppresses the disturbance,
target relocation, landing schedule, and new-contact claim. This isolates one
question: can the exact articulated limb physically leave and then return to
the same ordinary contact without a scaffold, root command, foot pin, pose
teleport, structural clamp, or broken joint geometry?

All three preregistered seeds answer that bounded question positively:

| Seed | Semantic release tick | Shape gap at release | Longest semantic-absence dwell | Same-place recontact tick | Final torso height | Final tilt | Final angular speed |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 14001 | `725` | `0.030413 m` | `4 ticks` | `729` | `0.404568 m` | `0.073545 rad` | `0.848109 rad/s` |
| 14002 | `724` | `0.029404 m` | `4 ticks` | `728` | `0.391258 m` | `0.113807 rad` | `0.314014 rad/s` |
| 14003 | `725` | `0.032196 m` | `4 ticks` | `729` | `0.383688 m` | `0.123251 rad` | `0.495908 rad/s` |

The final speed values are intentionally reported rather than converted into a
recovery claim. The bounded cell requires only non-collapse height/tilt,
ordinary recontact, intact geometry, complete paired receipts, and structural
safety. Development-only full-horizon continuations showed why the claim must
remain narrow: seeds `14001` and `14002` eventually returned inside the static
stance envelope, while seed `14003` did not. Immediate and delayed support
readmission probes also destabilized seed `14003`; those failed tuning probes
are not commissioned evidence. Long-horizon post-recontact recovery is
therefore a separate open controller cell.

The exact positive prerequisite passes **20/20 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate7_semantic_release_exact\20260724T073132608\report.json
```

With this addition, the complete BR14A family contains **17 programs and
306 assertions**. The post-change family regression passed all **17/17
programs** and **306/306 assertions**, with zero failures, timeouts, or
unexpected engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate7_family\20260724T073539723\report.json
```

This establishes only bounded single-foot semantic release and ordinary
same-place recontact for the exact morphology, controller, solver, seed set,
and thresholds. Contact absence and geometric gap are not measured load or
bearing. The result does not establish long-horizon free-3D recovery,
articulated three-contact bearing, BR14A.5 protective contact, per-foot load
allocation, a locomotor step, standing, bracing, fall arrest, get-up, gait,
walking, repair, automatic application, or creature guidance. The formal
ladder remains **14/18 accepted (77.8%)**.

## 81. BR14A.4R four-contact handoff-readiness recovery — 2026-07-24

Candidate 4's safe abort isolated a missing prerequisite: relative-pose stance
could return near its nominal pose, but it could not deliberately rebuild the
COM/capture margin needed to remove the front-right contact. BR14A.4R now
commissions that missing controller as a separate positive experiment before
it is allowed back into a swing candidate.

The exact unscaffolded nine-body, 12-DOF quadruped keeps all four ordinary feet
on the floor. Each active/control pair:

1. acquires the support triangle that excludes the front-right foot;
2. holds the declared `0.025 m` COM and linearized-capture margin;
3. returns to nominal four-contact geometry until the margin is at or below
   `0.010 m`; and
4. gives only the active world the second acquisition target.

All three active seeds record `240 / 120 / 240` ticks of first-ready,
deliberately-not-ready, and second-ready dwell. All three controls record
`240 / 120 / 0`.

| Seed | Active final COM / capture margin | Control final COM / capture margin | Active maximum height error | Active maximum tilt | Active maximum anchor / hinge error | Active maximum torque |
|---:|---:|---:|---:|---:|---:|---:|
| 14001 | `0.051217 / 0.051792 m` | `-0.001958 / -0.001884 m` | `0.051689 m` | `0.093846 rad` | `0.000877 m / 0.007877 rad` | `8.580748 N m` |
| 14002 | `0.045769 / 0.045743 m` | `-0.003815 / 0.004226 m` | `0.051689 m` | `0.079230 rad` | `0.000851 m / 0.007734 rad` | `9.997352 N m` |
| 14003 | `0.050471 / 0.050283 m` | `0.000298 / 0.006104 m` | `0.051689 m` | `0.088958 rad` | `0.000772 m / 0.007275 rad` | `10.155776 N m` |

The active worlds retain all four contacts without torso contact, remain
inside the source height and tilt bounds, finish inside the source static
speed envelope, retain joint geometry, cross no structural torque guard, and
produce complete paired actuator receipts. The commanded transfers
intentionally have nonzero transient speed; the dynamic capture margin is the
velocity-aware transfer gate, while the source static-speed threshold applies
to the final dwell rather than every moving tick.

The exact positive program passes **18/18 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_readiness_recovery_corrected\20260724T043401625\report.json
```

The expanded complete BR14A family passes **14/14 programs and 249/249
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_readiness_recovery_family2\20260724T044641850\report.json
```

This proves only repeatable four-contact global handoff-readiness recovery for
the exact controller, profile, solver, seed set, and thresholds. It does not
remove a contact, move a foot, establish articulated three-contact bearing,
measure or allocate per-foot load, create a protective contact, or prove
BR14A.5. The controller may now be tested as candidate 5's abort/rearm
prerequisite without importing any broader claim. BR14A.5, formal BR14A
acceptance, free-3D recovery, bracing, fall arrest, get-up, locomotor step,
gait, walking, repair, automatic application, and creature guidance remain
open. The formal ladder remains **14/18 accepted (77.8%)**.

## 82. BR14A.5 blended lift and fifth candidate rejection — 2026-07-24

The fifth candidate tests the actuator-mode boundary exposed by the earlier
attempts. It retains candidate 4's zero-feedback three-contact wrench
preflight, COM/capture gate, event retreat, and preferred-contact allocator,
but changes three details:

- the exact commissioning cell is the zero-preload control, so no commanded
  contact share is relabeled an unload measurement;
- vertical lift occupies 60 of the 120 logical swing-path ticks rather than
  requesting the complete `0.10 m` vertical target in one logical tick; and
- the world-space resolved-rate swing torque blends into the existing
  relative-pose torque over eight logical path ticks.

On seed `14001`, the controller advances nine logical path ticks. That is
greater event progress than candidate 4's three ticks, but the selected distal
body remains in ordinary floor contact and never reaches the `0.070 m`
clearance gate. The predictive gate then retreats to zero and causally
suppresses both the disturbance and touchdown schedule.

The full `1700`-tick witness finishes at:

- torso height: `0.393714 m`;
- final tilt: `0.015548 rad`;
- final angular speed: `0.129812 rad/s`;
- maximum anchor error: `0.002169 m`;
- maximum hinge-axis error: `0.015368 rad`;
- maximum applied torque: `28.039589 N m`; and
- structural saturation count: zero.

Every applied allocator command remains feasible, every actuator command is
paired and receipt-complete, and the final pose returns inside the declared
stance envelope. The transient nevertheless proves that smoothly blending a
world-foot servo into a still-contacting relative-pose limb does not create a
valid contact-removal mode transition. Lower commanded-unload development
brackets (`8`, `16`, `24`, and `33` of `40`) either retreated without swing or
became less stable; those exploratory cells are not commissioned conclusions.

The exact fifth-candidate rejection program passes **18/18 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate5_rejection\20260724T054333114\report.json
```

The complete post-change BR14A family passes **15/15 programs and 267/267
assertions**, with zero failures, timeouts, engine errors, or unexpected engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate5_family\20260724T055002039\report.json
```

Only this exact all-seed state machine is rejected; seeds `14002` and `14003`
receive no conclusion. The next prerequisite is a contact-aware limb
mode-transition contract that can change from grounded relative-pose support
to free-space swing without treating command share as measured load and
without dragging the contact. BR14A.5 remains open. No contact removal,
protective contact, articulated three-contact bearing, per-foot measured load
allocation, free-3D recovery, bracing, fall arrest, get-up, locomotor step,
gait, walking, repair, automatic application, or creature guidance is
established. The formal ladder remains **14/18 accepted (77.8%)**.

## 89. BR14A.5 rear-left bounded atomic locomotor step — 2026-07-24

Candidate 13 tests whether Candidate 11's atomic-step machinery is portable
to another physical limb. It runs the rear-left diagonal limb in a fresh
physics world for every seed; it does not start from Candidate 11's final
front-right state. The result therefore closes independent-limb portability,
not same-world sequencing.

The exact rear-left program retains the unpinned nine-body, 12-DOF canonical
fixture, ordinary floor contacts, paired joint-torque actuation, and inherited
front-right phase structure. It changes the swing limb and contact to
`rear_left` / `rear_left.foot`, commands a `(+0.025, +0.012, 0.000) m`
clearance offset over 6 lift and 10 lower ticks, and caps the relocation task
at `700 N/m` position gain, `30 N s/m` velocity gain, and `20 N` force. A
valid touchdown requires at least `0.014 m` horizontal relocation and no more
than `0.012 m` target error. After the inherited 600-tick settling interval,
whole-system COM and torso must advance at least `0.008 m` and `0.009 m` in
declared positive world X.

The exact measurements are:

| Seed | Release / recontact tick | Recontact move / target error | Final rear-left X/Z from release | Final move / target error | COM X/Z | Torso X/Z | Worst foot slip | Final height / tilt / angular speed |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `14001` | `725 / 737` | `0.017026 / 0.007978 m` | `+0.024373 / -0.038748 m` | `0.045776 / 0.038753 m` | `+0.016776 / +0.000285 m` | `+0.018870 / +0.000320 m` | `0.002696 m` | `0.402813 m / 0.016676 rad / 0.000031 rad/s` |
| `14002` | `724 / 736` | `0.016636 / 0.008886 m` | `+0.028902 / -0.038274 m` | `0.047961 / 0.038473 m` | `+0.013366 / +0.000304 m` | `+0.015079 / +0.000339 m` | `0.002081 m` | `0.402871 m / 0.006252 rad / 0.004926 rad/s` |
| `14003` | `725 / 737` | `0.016582 / 0.008435 m` | `+0.053598 / -0.024342 m` | `0.058866 / 0.037555 m` | `+0.014334 / -0.001331 m` | `+0.016067 / -0.001523 m` | `0.002360 m` | `0.402036 m / 0.045314 rad / 0.000067 rad/s` |

All three fresh worlds finish the exact 2300-tick horizon quiet and upright on
four ordinary contacts with no torso contact, intact joint geometry, complete
paired receipts, zero structural saturation, and zero allocator
infeasibility. Each sets both
`bounded_atomic_locomotor_step_observed=true` and
`locomotor_step_established=true`. The exact contract passes **17/17
assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate13_rear_left_exact_pass\20260724T172350479\report.json
```

The clean post-restart BR14A family regression passes **22/22 programs and
412/412 assertions**, with zero failures, timeouts, engine errors, or
unexpected engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate13_full_family_resume\20260724T181203816\report.json
```

Candidate 13 also isolates a controller defect. On seed `14002`, the inherited
post-recontact roll/pitch velocity-feedback term injected energy; increasing
its gain made the response worse and eventually caused collapse. The passing
contract suppresses only those velocity-feedback terms for phase-relative
post-recontact ticks `1000-1299`, then restores the baseline. Position
feedback and every existing force and moment cap stay active. This is
**phase-bounded velocity-feedback suppression for a
geometry/sign/allocation problem**, not “more damping.”

The accompanying yaw-rate correction remains ground-mediated and receipt
bounded. Seed `14002` records 964 commands, a maximum requested yaw moment of
`0.01216783002019 N m` against the `0.2 N m` cap, and a maximum endpoint force
of `0.01120650954545 N` against the `0.5 N` cap.

A development-only mirrored front-left probe relocated the foot but could not
preserve body translation and hold across the exact seeds. It destabilized and
was removed; it is not commissioned evidence and must not be cited as a
passing limb.

The next causal gate is one continuous physics world that performs the
front-right atomic step, explicitly resets the phase-local controller state,
then records a second rear-left release, airborne relocation, ordinary
recontact, recovery, and cumulative body translation. Candidate 13 does not
establish that gate. The two positive atomic-step programs remain independent
fresh-world results. They establish no same-world second transition,
alternation, repeated stepping, gait, candidate walking, walking, accurate
final foothold placement, speed control, steering, terrain or morphology
transfer, formal BR14A acceptance, accepted knowledge, repair, automatic
application, or creature guidance. The formal ladder remains **14/18 accepted
(77.8%)**.
