# BR14A Spatial Controllability Bootstrap

- **Status:** BR14A.0-BR14A.4 implemented; the selected wide, low 12-DOF quadruped passes preregistered unpinned free-3D stance and existing-contact roll-arrest experiments across all three seeds; this is commissioning, not formal BR14A acceptance
- **Date:** 2026-07-23
- **Depends on:** Accepted BR13 constrained canonical get-up plus accepted BR2.1 frame truth
- **Positive implementation claims:** `prephysical_linearized_spatial_wrench_rank_only`, `prephysical_polyhedral_contact_wrench_feasibility_only`, `prephysical_declared_contact_command_to_actuator_envelope_only`, `canonical_spatial_quadruped_preregistered_prephysically`, `canonical_free_3d_static_stance_observed_in_commissioning`, and `canonical_existing_contact_roll_arrest_observed_in_commissioning`
- **Physical capability claim:** Exact BR14A.3/BR14A.4 commissioning observations only; no formal acceptance, new-contact recovery, step, gait, walking, or guidance

## Why this layer exists

BR13 proves one guided, symmetry-collapsed planar get-up. BR14A must remove the
material out-of-plane scaffold and prove a spatial pipeline for one canonical
morphology. Choosing that morphology affects anatomy, task axes, actuator
maps, reach, torque, power, contact geometry, and the eventual free-3D
experiments. That product choice is intentionally deferred.

The choice was initially deferred while the generic instruments were built.
Cole subsequently delegated the recommendation and authorized continued
implementation. The exact laboratory reference is now selected below. It is
not the final game-creature anatomy and need not be the later L8 walking body.

The work that does not depend on that choice is built first: a strict spatial
rank oracle, a conservative ordinary-contact feasibility oracle, and a
contact-command-to-actuator-load oracle that can evaluate any later candidate
without silently counting a guide, mixing force and moment units, permitting
a contact to pull, ignoring joint torque envelopes, or relabeling a
mathematical allocation as physical controllability.

## Implemented BR14A.0 rank boundary

`scripts/lab/mechanics/spatial_wrench_rank_oracle.gd` accepts:

- one centroidal-world reference frame;
- one characteristic morphology length;
- exact six-component wrench columns;
- explicit column provenance:
  `ordinary_contact_linearization`, `actuator_analytic`, or `scaffold`;
- a complete partition of all force/moment axes into task-required or
  intentionally omitted axes;
- bounded rank and projection-residual tolerances; and
- the exact non-capability claim boundary.

Moment rows are divided by the declared characteristic length before rank is
computed. This converts force and moment rows into one consistent
nondimensionalized structural calculation. Modified Gram-Schmidt with
reorthogonalization reports:

- rank using all columns;
- rank after removing every scaffold column;
- contact, actuator, and scaffold sub-ranks;
- projection residual for each of the six task axes;
- whether a required axis is structurally missing; and
- whether an axis appears reachable only because a scaffold column was
  included.

The oracle also provides a geometry helper for the analytic centroidal wrench
column of one unit contact-force direction:

\[
\mathbf{w}
=
\begin{bmatrix}
\mathbf{f}\\
(\mathbf{p}-\mathbf{c})\times\mathbf{f}
\end{bmatrix}
\]

where \(\mathbf{p}\) is contact position and \(\mathbf{c}\) is whole-system
center of mass, both in the declared world frame.

## What rank cannot prove

Linear rank is an upper bound. It ignores:

- unilateral normal-force sign;
- friction-cone magnitude;
- actuator-to-contact reachability;
- joint torque, speed, power, and structure limits;
- collisions and joint ranges;
- controller delay and saturation;
- dynamic state transitions;
- contact creation or maintenance; and
- whether the columns describe a morphology we actually intend to ship.

Accordingly, a six-rank report is not standing, balance, bracing, recovery,
stepping, gait, or walking evidence. It is only permission to continue
analyzing that candidate.

## Implemented BR14A.1 contact-feasibility boundary

`scripts/lab/mechanics/spatial_contact_feasibility_oracle.gd` adds a generic,
prephysical screen for ordinary unilateral contacts. It accepts one shared
whole-system center of mass, one centroidal-world desired wrench, and up to
sixteen declared contacts. Each contact has:

- one position and right-handed orthonormal contact frame;
- a finite friction coefficient;
- a positive normal-command capacity; and
- an explicit assertion that it is an ordinary unilateral contact.

The oracle replaces each circular Coulomb cone with an inscribed four-ray
friction pyramid:

\[
\mathbf{n}+\mu\mathbf{u},\quad
\mathbf{n}-\mu\mathbf{u},\quad
\mathbf{n}+\mu\mathbf{v},\quad
\mathbf{n}-\mu\mathbf{v}
\]

Every ray coefficient is nonnegative, so the allocation cannot pull on the
surface. The coefficient sum for each contact is capped by that contact's
declared normal capacity. Moment rows are divided by the same declared
characteristic length used by BR14A.0, and projected gradient descent with
per-contact simplex projection searches only inside that bounded convex
command set.

This construction is deliberately conservative. A request rejected by this
screen may still fit the exact circular cone, while a request accepted by the
screen still requires a real candidate's inverse kinematics, collision
clearance, actuator torque/speed/power envelope, structure, controller, and
dynamic experiment. Per-contact outputs are proposed commands, not measured
loads. BR3A L1.6-L1.8 already showed why raw local engine impulses cannot be
used as a substitute for whole-system load reconstruction or per-foot
allocation.

The focused BR14A.1 test proves the following synthetic boundaries:

- a single contact can provide a bounded positive normal command but cannot
  pull;
- shear inside the declared friction pyramid can pass while an excessive
  shear request fails;
- two separated contacts can produce a bounded support moment but reject a
  request beyond their declared normal capacities; and
- left-handed frames, nonordinary contacts, invalid capacity/friction,
  broader claims, guidance authorization, and post-seal mutation fail closed.

The BR14A.1 program passes **23/23 assertions** inside the combined
BR14A.0-BR14A.1 regression, which passes **50/50 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_prephysical_final\20260723T190941499\report.json
```

This does not select a morphology and does not establish an actuator,
physical contact, measured load, free-3D stance, recovery, step, gait, or
walking.

## Implemented BR14A.2 actuator-load boundary

`scripts/lab/mechanics/spatial_actuator_load_oracle.gd` maps declared
contact-force commands to revolute-joint generalized loads:

\[
\tau_i
=
\hat{\mathbf{a}}_i \cdot
\left[
(\mathbf{p}-\mathbf{o}_i)\times\mathbf{f}
\right]
\]

where \(\hat{\mathbf{a}}_i\) and \(\mathbf{o}_i\) are the declared world-frame
joint axis and pivot. A distal contact may load multiple declared ancestor
joints. The oracle sums those contributions, adds an explicitly incomplete
declared analytic bias, and computes the opposing active torque command.

Each joint must carry a digest-valid accepted BR4 actuator specification.
The requested command is compared with:

- the full-activation instantaneous torque-speed envelope;
- the positive-work or absorption-power cap selected by torque/rate sign;
- the structural joint-torque cap; and
- the declared minimum distance from either joint limit.

Synthetic tests cover exact \(J^\mathsf{T}\) mapping, mirrored direction,
multi-ancestor loading, isometric torque shortage, positive-power and
absorption-power shortage, structural saturation, joint-limit proximity, and
a disabled actuator. Topology, actuator-spec digest, incomplete-bias,
measurement, claim, guidance, and post-seal mutation substitutions all fail
closed.

The BR14A.2 program passes **26/26 assertions**. The combined
BR14A.0-BR14A.2 regression passes **76/76 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_generic_final\20260723T191912151\report.json
```

The screen does not establish that its input contact command is feasible.
That remains BR14A.1's job. It also does not include complete rigid-body
gravity/inertia bias, activation or torque-rate transients, inverse
kinematics, collision clearance, or structural analysis beyond the declared
joint torque cap. Full activation is an optimistic upper bound, not an
executable command sequence.

## Selected canonical laboratory morphology

`scripts/lab/mechanics/canonical_spatial_quadruped_profile.gd` now pins the
recommended wide, low, independently actuated quadruped as the exact BR14A
laboratory reference:

- the accepted BR13 6 kg torso and 8 kg whole-system mass are preserved;
- each accepted 1 kg mirrored limb-pair representation becomes two distinct
  0.5 kg physical limbs;
- each limb contains hip-abduction, hip-pitch, and knee-pitch DOFs, for twelve
  independently identified revolute DOFs;
- the hip-pitch pair's 60 N·m / 500 W budget is split left/right to
  30 N·m / 250 W, while the new hip-abduction and knee roles use that same
  explicit-lab per-DOF candidate cap without claiming anatomical derivation;
- four ordinary foot contacts form a \(0.44\,m \times 0.44\,m\) support
  rectangle;
- all six spatial wrench axes are required and none are omitted;
- no scaffold is allowed;
- the current 120 Hz, 20/4 solver configuration and seeds
  `14001, 14002, 14003` are pinned; and
- low-friction lateral demand, disabled front-left abduction, and any
  scaffold injection are preregistered as expected-infeasible controls.

The profile compiler is exact: mass drift, scaffold injection, walking
authority, or relabeling the lab reference as final game anatomy requires a
new identity. It authorizes prephysical analysis only.

Applying BR14A.0-BR14A.2 to the selected static pose produced:

- non-scaffold ordinary-contact linearized rank six;
- a conservative four-contact command allocation supporting the exact
  \(8\,kg \times 9.8\,m/s^2 = 78.4\,N\) weight request evenly;
- twelve joint loads inside the split full-activation BR4 envelopes, with
  maximum directional utilization below 20%; and
- the preregistered low-friction and disabled-abduction controls failing at
  their predicted constraints.

The profile test passes **23/23 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_selected_profile_final2\20260723T193236391\report.json
```

The complete BR14A generic-plus-profile regression passes **99/99
assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_selected_profile_final2\20260723T193236391\report.json
```

This selection does not establish inverse-kinematic reach, collision
clearance, complete gravity/inertia bias, activation transients, a constructed
physics body, free-3D stance or recovery, morphology transfer, a final game
creature, a step, gait, candidate walking, or walking. A six-leg crawl body
may still be the better first walking candidate later; BR14A recovery and L8
walking need not use the same morphology.

## Implemented BR14A.3 physical stance boundary

`scripts/lab/mechanics/canonical_spatial_stance_experiment.gd` freezes the
first physical execution contract separately from the prephysical morphology
selection. It binds the exact profile digest, `120 Hz` and `20/4` solver
configuration, seeds `14001-14003`, a `600`-tick active/control run, a
`120`-tick stable dwell, controller gains, success envelopes, the ordinary
floor, an empty scaffold set, and the verbatim nonclaim boundary.

`scripts/lab/rigs/canonical_spatial_stance_rig.gd` constructs:

- one `6 kg` rigid torso;
- four independently simulated `0.25 kg + 0.25 kg` two-link limbs;
- four two-axis `Generic6DOFJoint3D` hips and four one-axis
  `HingeJoint3D` knees;
- twelve receipt-backed, equal/opposite `LabJointActuator` torque commands per
  active physics tick; and
- one ordinary static floor as the only static collision body.

There is no world anchor, root pin, rail, guide, gimbal, built-in joint motor,
joint spring, foot pin, pose teleport, root wrench, or post-release freeze.
Adjacent torso/upper-link and upper/lower-link collision pairs are excluded as
self-collisions; every nonadjacent body and the ordinary floor remain physical.

The exact controller is relative-pose PD plus a declared static feedforward
term. The gains are `40 N m/rad` and `0.50 N m s/rad`. These gains are frozen
in the experiment contract because the first diagnostic controller reused
planar-scale damping on `0.25 kg` links, generated limit-cycle commands, and
failed honestly. The final evidence was collected only after the corrected
spatial-scale controller and thresholds were preregistered.

Across all three seeds:

| Seed | Active stable dwell | Active final torso height | Active final tilt | Zero-command stable dwell |
|---:|---:|---:|---:|---:|
| 14001 | 416 ticks | 0.408413 m | 0.001618 rad | 0 |
| 14002 | 394 ticks | 0.408369 m | 0.000071 rad | 0 |
| 14003 | 423 ticks | 0.408432 m | 0.000142 rad | 0 |

All four active foot bodies retained ordinary floor contact for the complete
measured interval. The zero-command twins collapsed to final torso heights of
approximately `0.148 m` and never entered the stable dwell. Active trials
remained receipt-complete for `7,200` joint commands per seed. Worst measured
anchor error was `0.401 mm`, worst hinge-axis error was `0.003699 rad`, and
worst applied joint torque was `8.029388 N m`, with no structural torque
clamp.

The focused BR14A.3 program passes **13/13 assertions**. The complete
BR14A.0-BR14A.3 generic/profile/physical regression passes **112/112
assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_free3d_full\20260723T200430904\report.json
```

This is the first real free-3D articulated stance observation in the ladder,
but it remains commissioning evidence for one exact lab morphology and
controller. The summaries explicitly self-report no formal stance
establishment, no recovery, no per-foot measured load allocation, no step,
gait, walking, repair, automatic application, or guidance. Formal promotion
requires its own bundle/report/attestation/campaign/decision chain.

## Implemented BR14A.4 existing-contact roll arrest

`scripts/lab/mechanics/canonical_spatial_arrest_experiment.gd` binds the exact
stance/profile digests, solver, three seeds, controller gains, a `720`-tick
run, disturbance tick `360`, a single `+X` torso torque impulse of `0.020 N m
s`, recovery thresholds, and an active-versus-feedback-withdrawal causal
control.

Both worlds use the same full stance controller before the disturbance and
receive the same impulse. Afterward:

- the active world retains relative-pose feedback plus static feedforward;
- the control retains the same static feedforward commands but loses
  relative-pose feedback;
- both continue issuing twelve receipt-backed joint commands per tick; and
- neither world changes a foot target or creates a new contact body.

The impulse is a declared experiment operation, not a controller root-wrench
channel. The controller still applies only equal/opposite joint torques.

| Seed | Active recovery completion | Active roll-rate area | Peak observed roll rate | Control recovery | Control roll-rate area |
|---:|---:|---:|---:|---:|---:|
| 14001 | 66 ticks | 0.016497 rad | 0.505494 rad/s | none | 0.269424 rad |
| 14002 | 66 ticks | 0.013402 rad | 0.509828 rad/s | none | 0.246797 rad |
| 14003 | 66 ticks | 0.015605 rad | 0.508078 rad/s | none | 0.268881 rad |

Every active trial retained all four preexisting ordinary foot contacts and
returned to approximately `0.4084 m` torso height. The controls never
completed the recovery dwell and collapsed to `0.1656-0.1705 m`. All active
and control command receipts were complete; geometry remained inside the
BR14A.3 envelopes; and no structural torque clamp occurred.

The BR14A.4 program passes **14/14 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_roll_arrest_probe2\20260723T201803409\report.json
```

The shared-controller BR14A.3 regression still passes **13/13** after this
extension:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_stance_after_arrest\20260723T202227736\report.json
```

Together with the unchanged 99 prephysical/profile assertions, all six BR14A
programs now pass **126/126 assertions** in staged verification. This is
existing-contact roll-disturbance rejection only. It creates no protective
contact, measures no per-foot allocation, and proves no generalized bracing,
fall arrest, get-up, load transfer, step, gait, walking, repair, or guidance.

## Implemented and rejected BR14A.5 candidate controller

The first new-protective-contact controller candidate is now implemented as
an explicit early-stop rejection witness rather than a false positive.

`canonical_spatial_protective_contact_experiment.gd` seals one exact
front-right-foot candidate: three-support-limb torso-shift assistance,
bounded measured-Jacobian-transpose foot control, one matched `+X` torso
torque impulse, an align-then-descend wider floor target, actuator receipts,
geometry/contact/recovery thresholds, and a hold-clear causal control. The
candidate uses the same nine physical bodies, twelve joint DOFs, ordinary
floor, solver, and absence of scaffolds as BR14A.3-BR14A.4.

The fixture adds one read-only semantic contact observer because
`RigidBody3D.get_colliding_bodies()` cannot distinguish the lower-link shaft
from its distal foot sphere. The observer resolves the local collision-shape
semantic ID and counterparty body ID inside `_integrate_forces`; it never
applies a force, impulse, transform, or contact modification.

The exact seed-`14001` rejection witness measured:

| Quantity | Observed | Gate/result |
|---|---:|---|
| Clear ticks before disturbance | 20 | provisional event observed |
| Active first new contact | tick 515 | before tick-530 deadline |
| Target error at first contact | 0.020939 m | inside 0.04 m target gate |
| Matched hold-clear incidental contact | tick 519 | active leads by 4 ticks |
| Post-touch contact fraction | 0.946067 | fails required 0.95 |
| Recovery dwell | 0 ticks | fails required 120 ticks |
| Maximum anchor error | 0.024501 m | fails 0.01 m |
| Maximum hinge-axis error | 0.379695 rad | fails 0.10 rad |
| Maximum applied torque | 30.914259 N m | below 40 N m structural limit |
| Three-foot support margin at lift start | +0.029147 m | COM begins inside |
| Three-foot support margin at disturbance | -0.219007 m | COM has left support |
| Minimum pre-touch support margin | -0.219864 m | fails body-centered support |

Positive commissioning required all three profile seeds to pass. The exact
first required seed is therefore a sufficient early-stop rejection witness;
seeds `14002` and `14003` were not executed by this rejection program and
receive no result.

This is a useful partial mechanical event, but it is not a BR14A.5 pass. A
lower-force overlap probe improved hinge quality but could not keep the foot
clear through the disturbance; the higher-force candidate above cleared and
touched accurately but lost geometry, sustained-contact quality, and
recovery. Tuning stopped at that falsification boundary.

The added `spatial_support_margin_observer.gd` computes mass-weighted
whole-system COM and signed distance to the ordered three-contact polygon. It
is read-only and explicitly does not infer bearing or per-foot load. It shows
that the commanded weight shift initially works, but the swing phase drives
the COM from `+29.147 mm` inside to `219.007 mm` outside by the disturbance.
The next controller must close feedback on this measured centroidal support
state; an open-loop torso-offset target is insufficient.

The rejection program passes **15/15 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate_support_margin_final\20260723T224301955\report.json
```

The analytic observer program passes **9/9 assertions**, including exact
mass-weighting, known inside/outside margins, winding normalization,
degenerate and underspecified polygon refusal, empty-body refusal, and the
load/bearing/write nonclaims:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_support_margin_observer_fixed\20260723T225141047\report.json
```

The shared-rig regression after adding the semantic observer and optional
task-torque channels remains clean:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_stance_shared_rig_regression\20260723T221124514\report.json
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_arrest_shared_rig_regression\20260723T221317741\report.json
```

BR14A.3 still passes **13/13** and BR14A.4 still passes **14/14** with their
original measured outcomes. Across eight BR14A programs, **150/150
assertions** now pass their exact contracts; 15 assertions establish candidate
rejection and 9 commission its read-only observer, not protective-contact
success.

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_support_margin_final\20260723T225259199\report.json
```

The next BR14A.5 candidate must demonstrate one actual overlap region where
all of the following pass together:

1. contact loss and declared swing clearance;
2. disturbance-time clearance;
3. nonnegative measured whole-system COM margin throughout the three-contact interval;
4. targeted new ordinary-floor contact;
5. sustained contact quality;
6. joint anchor and hinge-axis integrity;
7. bounded actuator/structure envelopes; and
8. recovery dwell.

Changing the morphology or controller is allowed only through a new sealed
candidate. Weakening the current gates, treating incidental control collapse
as success, or promoting the partial event is not.

## Remaining implementation cells

| Cell | Question | Required before physical claims |
|---|---|---|
| BR14A.0 | Are spatial axes, units, provenance, rank, and scaffold dependence explicit? | Implemented generically and applied: selected contact geometry has non-scaffold rank six |
| BR14A.1 | Can a requested wrench fit inside bounded ordinary unilateral-contact/friction commands? | Implemented generically and applied: symmetric weight command passes; low-friction lateral control fails |
| BR14A.2 | Can declared contact commands map through revolute \(J^\mathsf{T}\) into bounded BR4 actuator, structure, and joint-limit envelopes? | Implemented generically and applied as a full-activation upper bound; complete bias/reach/collision analysis remains |
| BR14A.3 | Can the exact unpinned articulated body maintain a bounded four-contact free-3D stance under receipt-backed actuation? | Implemented and passed in commissioning across three active/control seeds; formal promotion remains open |
| BR14A.4 | Can existing contacts arrest a bounded spatial disturbance without a scaffold? | Implemented and passed in commissioning across three matched active/feedback-withdrawal seeds; formal promotion remains open |
| BR14A.5 | Can the body create and use a bounded protective contact? | First exact controller candidate implemented and rejected; positive cell remains open pending a clearance-quality-recovery overlap |
| BR14A.6 | Can the exact morphology get up in free 3D? | Open |
| BR14A.7 | Do scaffold-removal and adversarial controls preserve the exact causal boundary? | Open |

Only after those physical cells, a clean source-pinned promotion campaign,
detached certification, and an explicit bounded decision can BR14A advance the
formal ladder. Even accepted BR14A would establish robust spatial behavior for
one canonical morphology, not a step, gait, candidate walking, or walking.

## Walking path after BR14A

The earliest locomotion path remains:

1. L4.2 free-space placement.
2. L4.5 swing clearance.
3. L4.6 bounded touchdown with observed `TOUCH -> LOAD -> BEARING`.
4. L7.0 ordinary-contact load transfer under an explicit pelvis scaffold.
5. L7.1-L7.6 constrained atomic stepping.
6. L8.0-L8.2 scaffold annealing for the first crawl body.
7. L8.3 fully free flat-floor `candidate_walking`.
8. L8.4 causal controls and Cole's separate visual/evidence review before the
   word `walking` is accepted.

## Engine-neutral portability boundary

The generic rank, contact-feasibility, actuator-load, and centroidal calculations
are candidates for an engine-neutral core. Physical body discovery, callback
timing, contact sampling, solver settings, and joint-motor application are
adapter responsibilities.

Every future adapter must preserve the observation boundary already learned
here:

- contact point, normal, relative velocity, force, and impulse each carry
  frame, availability, quality, and backend provenance;
- a missing observation is not a measured zero;
- raw multi-shape contact impulses are not silently summed into per-foot load;
- host joint and actuator semantics are characterized before analytic commands
  are called physically realizable; and
- a new backend independently proves its coordinate and callback semantics
  instead of inheriting Jolt-specific facts.

The full canonical contracts and conformance ladder are defined in the
[Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).
