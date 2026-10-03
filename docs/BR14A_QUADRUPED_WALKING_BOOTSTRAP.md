# BR14A Quadruped Walking Bootstrap

- **Status:** active experimental continuation; two atomic limb steps are
  independently commissioned, but same-world sequential stepping and walking
  are not established
- **Date:** 2026-07-25
- **Baseline commit:** `d049056ebc8748451900d0f516b681e52044bbb2`
- **Priority:** establish repeated, bounded, same-world quadruped locomotion
  before beginning another morphology
- **Claim boundary:** this document is a work ledger, not certification

## Mission

Turn the canonical BR14A wide, low, 12-DOF quadruped from a collection of
isolated physical capabilities into a creature that repeatedly advances in
one continuously simulated world.

The work must preserve LoColemotion's evidence-first boundary:

1. An independently passing limb trial establishes one atomic locomotor step.
2. Two passing trials rebuilt in separate worlds do not establish a sequence.
3. Two steps in one world establish only a sequential two-step prerequisite.
4. Repeated ordered limb cycles, net body advancement, bounded contact and
   structure behavior, and a stable terminal state are required before this
   branch may say that the quadruped walks.
5. Running, automatic creature guidance, terrain generality, and
   morphology-general locomotion require later experiments.

## Protected operator environment

Cole's interactive Godot editor is operator-owned. Laboratory automation must
not terminate, reuse, or inject state into the editor or its console process.
Every probe and test must:

- launch its own Godot worker;
- use isolated `APPDATA` and `LOCALAPPDATA` directories;
- write explicit logs below `C:\tmp`;
- run with a hidden window; and
- terminate only a PID whose executable path, creation time, and launch
  ownership were recorded by that exact automation run.

Generated `.gd.uid` files and unrelated `.github/` material in the working tree
are also operator-owned and must not be staged as part of this program.

## Verified baseline

The repository and remote were both at:

```text
d049056ebc8748451900d0f516b681e52044bbb2
```

The baseline contains these already committed milestones:

- `0822c4a` corrects the certification-attester global class names that caused
  Godot's language server to report one class hiding another.
- `d049056` commissions the mirrored rear-left atomic locomotor step.

The exact rear-left program passed **1/1 program and 17/17 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate13_rear_left_exact_pass\
20260724T172350479\report.json
```

The exact BR14A family passed **22/22 programs and 412/412 assertions**:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_candidate13_full_family_resume\
20260724T181203816\report.json
```

Those reports establish the fresh-world front-right and rear-left atomic-step
claims. They do not establish that either controller can start from the
physical state left by the other.

## Current same-world harness

The in-progress harness is implemented in:

- `scripts/lab/rigs/canonical_spatial_centroidal_contact_rig.gd`
- `scripts/lab/probes/probe_br14a_spatial_same_world_front_right_rear_left_sequence.gd`

Its contract is deliberately stricter than invoking two tests:

- construct one viewport, physics world, floor, torso, four limbs, and eight
  physical joint nodes;
- execute the front-right atomic step;
- preserve the live fixture only if that step passes its exact atomic gate;
- prove the second phase receives the same viewport, world, and torso instance
  IDs;
- do not freeze, rebuild, teleport, or restore the creature;
- rebase only the second swing trajectory to the measured rear-left foot pose;
- retain accumulated body pose, body velocities, joint state, contacts, and
  ground history;
- execute the rear-left phase;
- express second-phase release and recontact in global sequence ticks; and
- leave all gait, walking, and guidance claims false.

The first phase still reproduces its certified fresh-world behavior. The
second phase performs a real rear-left release, relocation, semantic
recontact, and post-recontact body translation in the preserved world.

## Current development evidence

The contact-consistent recovery intervention produced a complete development
pass for seed `14001`:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_continuation_contract_probe\
20260724T235605367\seed14001.stdout.log
```

Its second phase retained the same world and completed rear-left release and
recontact at local ticks `725/735`. The terminal receipts included:

| Receipt | Observed |
| --- | ---: |
| second-phase COM translation X | `+0.016180 m` |
| second-phase torso translation X | `+0.017887 m` |
| final four foot contacts | `true` |
| torso contact ticks | `0` |
| maximum anchor error | `0.001617 m` |
| maximum hinge-axis error | `0.011794 rad` |
| maximum applied torque | `20.400937 N m` |
| final torso height | `0.392869 m` |
| final torso tilt | `0.000817 rad` |
| final angular speed | `0.000188 rad/s` |
| final rear-left foot relocation | `0.031312 m` |
| maximum stance-foot slip | `0.012807 m` |

This is a development probe, not a sealed exact test. It establishes neither
the all-seed sequence nor walking.

Seed `14002` reaches the second release and recontact but enters the swing
controller's predictive retreat after recontact. The original conservative
three-support recovery collapses; continuously re-admitting the full
four-contact allocator improves the first roughly 100 recovery ticks but then
requires an increasing normal-force-bound projection residual:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_bounded_projection025_seed14002_short\
20260725T005451153\seed14002.stdout.log
```

At its bounded failure, the force residual had grown to `0.310547 N`, the
moment residual to `0.143675 N m`, and three normal commands required clamping.
This is evidence of controller drift into physical infeasibility, not
justification to increase a pass tolerance.

The sequence therefore remains correctly reported as:

```text
SPATIAL_CENTROIDAL_SAME_WORLD_ATOMIC_STEP_SEQUENCE_NOT_ESTABLISHED
```

Two sealed height gates apply. The general recovery equation uses the nominal
`0.440 m` torso center and permits `0.060 m` recovery error, producing a
`0.380 m` floor. The inherited long-horizon targeted-relocation recovery
contract independently requires `0.390 m`. The effective atomic-step floor is
therefore the stricter `0.390 m`; meeting only the general recovery envelope
cannot establish the second atomic step.

## Diagnosed controller mismatches

The continuation controller currently performs a one-time joint pose-reference
rebase when the second phase becomes ready for body translation. This avoids
commanding an obsolete pre-step pose through fixed contacts. It also makes the
translated, crouched joint configuration the new pose controller equilibrium.

The endpoint controller then asks the stance feet to move downward relative to
the torso when height is low. That creates an upward body reaction, but it is
opposed by the rebased joint-pose equilibrium and capped by the existing
endpoint-force envelope. The result is a stable height near `0.358 m`, below
the atomic-step recovery floor.

The next controller must change the joint posture in the same direction as the
contact-consistent endpoint task. It must not restore an old world pose or
blindly disable pose feedback.

The second mismatch is specific to the hard continuation seed: immediately
after semantic recontact, predictive retreat disables the full centroidal
allocator. Blindly overriding that retreat forever is also wrong because the
allocator eventually asks the contact system to exceed a normal-force bound.
A hybrid that latched back to conservative recovery at that first bounded
infeasibility still collapsed, so allocator re-admission is no longer the
active path.

The remaining discontinuity is in the relocated rear-left leg itself. The
swing task overrides its pose controller while airborne, but the old
`desired_relative_basis` resumes as soon as predictive retreat stops the swing
task after recontact. Rebasing that limb to the live planted geometry removed
too much posture authority and let the chain buckle. Adding the newly planted
limb to a bounded Cartesian endpoint-support task also failed to arrest the
height loss. The controller is back at the seed-`14001` development baseline.

Exact-boundary diagnostics now show that the collapse is already in progress
before any post-recontact authority change could help. At the seed-`14002`
semantic recontact, the rear-left foot was descending at `0.729928 m/s`, the
torso was descending at `0.466684 m/s`, and the torso yaw component was
`1.826447 rad/s`. The swing-joint-rate norm was `3.464572 rad/s`. The isolated
diagnostic receipt is:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recontact_kinematics_seed14002\
20260725T012946775\seed14002.stdout.log
```

The corresponding seed-`14001` control was also dynamic at recontact but
materially less severe: foot descent `0.412510 m/s`, torso descent
`0.255408 m/s`, torso yaw `1.130472 rad/s`, and swing-joint-rate norm
`3.532829 rad/s`:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recontact_kinematics_seed14001\
20260725T013239202\seed14001.stdout.log
```

Those runs were intentionally truncated after the diagnostic boundary and are
not sequence evidence. They identify the active intervention: reduce the
continuation-only landing approach speed while leaving both certified
fresh-world atomic-step configurations unchanged.

## Rejected experiments

These experiments are negative evidence. They must not be resurrected as
successful paths or cited as support for walking:

- restoring the old joint pose in one tick caused structural collapse;
- interpolating back to the old pose over 360 ticks delayed but did not remove
  that incompatibility;
- reversing the vertical correction sign collapsed the body;
- adding the recontacted leg as a fourth vertical-only support gained roughly
  one millimeter while worsening attitude and angular speed;
- suppressing vertical feedback during translation worsened early height and
  tilt;
- globally suppressing joint pose feedback during stabilization lost contact
  and collapsed;
- tracking measured support-joint pose references every tick caused immediate
  post-translation collapse;
- applying a new phase-start roll/pitch attitude loop at the same instant as
  contact-consistent posture recovery drove a pitch runaway, collapsed torso
  height near `0.25 m`, and increased hinge-axis error to `0.1465 rad`; posture
  recovery and attitude correction must be isolated rather than introduced as
  one coupled intervention;
- unbounded readiness targets, unqualified four-contact re-admission, and
  direct pose restoration failed earlier continuation experiments;
- rebasing every joint at the continuation boundary caused immediate
  four-contact sag and collapse;
- increasing the readiness target margin from `0.047 m` to `0.057 m` improved
  the lift margin but did not prevent the seed-`14002` post-recontact collapse;
- rebasing only the rear-left swing-limb pose at lift worsened hinge-axis error
  and introduced torso contact;
- an early post-recontact attitude-velocity override commanded zero ticks
  because predictive retreat had already disabled the allocator;
- ramping the recontacted swing limb into the vertical-only recovery worsened
  hinge-axis error; and
- raising the allocator's residual tolerance from `0.05` to `0.25` merely
  postponed failure by one tick while the required projection grew from
  `0.165771 N` to `0.310547 N`; and
- using that bounded allocator prefix and then latching back to conservative
  recovery converged to a collapsed posture: `0.261807 m` torso height,
  `0.367354 rad` tilt, `0.246747 rad` hinge-axis error, and 25 torso-contact
  ticks; and
- rebasing only the recontacted limb's pose references at semantic recontact
  ended at `0.255975 m` torso height, `0.381311 rad` tilt, `0.306296 rad`
  hinge-axis error, and 31 torso-contact ticks; and
- a bounded Cartesian endpoint-support task for the newly planted limb
  commanded 463 ticks but ended at `0.252899 m` torso height, `0.458020 rad`
  tilt, and `0.161043 rad` hinge-axis error; and
- extending the continuation-only lowering trajectory from 10 to 36 ticks
  reduced foot descent at recontact to `0.284997 m/s`, but left the body on
  three supports too long: torso descent was still `0.505762 m/s`, terminal
  height was `0.277416 m`, terminal tilt was `0.430366 rad`, and the relocated
  foot missed its target by `0.124809 m`. Its receipt is:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_soft_landing36_seed14002_20260725T013858512\seed14002.stdout.log`;
  and
- capping only downward target-velocity feedforward at `0.10 m/s` preserved the
  original `6/10/20` timing and recontact tick, but still changed the coupled
  limb response destructively: terminal torso height was `0.276030 m`, tilt
  was `0.441520 rad`, hinge-axis error was `0.154488 rad`, and final foothold
  error was `0.131172 m`. Its receipt is:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_downward_cap010_seed14002_20260725T014349386\seed14002.stdout.log`;
  and
- halving the continuation contact-release task-force cap from `40 N` to
  `20 N` delayed release by one tick and modestly improved the exact recontact
  height and velocities, but it still ended at `0.277636 m` torso height,
  `0.444068 rad` tilt, `0.151878 rad` hinge-axis error, and without four
  terminal contacts. Its receipt is:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_release_force20_seed14002_20260725T014852719\seed14002.stdout.log`;
  and
- applying up to `0.60 N m` of ground-mediated yaw damping during the
  16-tick airborne interval barely changed recontact yaw
  (`1.800413 rad/s` versus the `1.826447 rad/s` baseline), while terminal
  height fell to `0.268753 m` and tilt rose to `0.426479 rad`. Its receipt is:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_airborne_yaw060_seed14002_20260725T015701218\seed14002.stdout.log`;
  and
- advancing lift from tick `720` to tick `500` did not avoid the impulse:
  angular speed jumped from `0.021382 rad/s` at tick `480` to
  `0.707254 rad/s` on the first lift-command sample. Its release/recontact
  velocities closely matched baseline and it ended at `0.274976 m` height,
  `0.445694 rad` tilt, and `0.126061 rad` hinge-axis error. Its receipt is:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_early_lift500_seed14002_20260725T020316167\seed14002.stdout.log`;
  and
- a compact `0.012 m` release target did not break contact. At tick `736` the
  allocator correctly rejected `NORMAL_ABOVE_MAXIMUM:rear_right.foot` with a
  `-0.079719 N` normal reserve, so no release or recontact evidence exists for
  that run:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_compact_release012_seed14002_20260725T020950429\seed14002.stdout.log`;
  and
- a compact `0.020 m` release target with the inherited `40 N` task-force cap
  also did not break contact. At tick `735` the allocator correctly rejected
  `NORMAL_ABOVE_MAXIMUM:rear_right.foot` with a `-0.099160 N` normal reserve:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_compact_release020_seed14002_20260725T021359023\seed14002.stdout.log`;
  and
- combining the compact `0.020 m` target with a `20 N` task-force cap narrowed
  the allocator deficit to `-0.016764 N` and reduced the pre-failure tilt to
  `0.084586 rad`, but the target backed the servo out of saturation before
  physical separation and the foot still did not release:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_compact_release020_force20_seed14002_20260725T021935832\seed14002.stdout.log`;
  and
- raising that force-bounded target to `0.025 m` narrowed the deficit again to
  `-0.007108 N`, but still produced no physical separation:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_compact_release025_force20_seed14002_20260725T022404718\seed14002.stdout.log`;
  and
- a final `0.030 m` scalar-only target also failed to release and reached a
  `-0.012613 N` normal reserve:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_compact_release030_force20_seed14002_20260725T022810691\seed14002.stdout.log`;
  and
- a vertical-only pre-release task did release at ticks `727/730`, improved
  recontact torso height from `0.366153 m` to `0.388665 m`, cut torso descent
  from `0.466684 m/s` to `0.244792 m/s`, reduced torso yaw from
  `1.826447 rad/s` to `0.633180 rad/s`, and preserved allocator feasibility.
  Removing all horizontal damping was nevertheless destructive: the foot left
  with `-0.826894 m/s` X velocity, recontacted after only three absent ticks,
  relocated just `0.005874 m`, and ended in a `0.272291 m` crouch. Its receipt
  is:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_vertical_release_seed14002_20260725T023321104\seed14002.stdout.log`;
  and
- keeping live horizontal position but restoring the full inherited horizontal
  velocity damping prevented separation. The allocator rejected a
  `NORMAL_ABOVE_MAXIMUM:rear_right.foot` request with only a `-0.002604 N`
  normal reserve:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_live_horizontal_release_seed14002_20260725T023825962\seed14002.stdout.log`;
  and
- scaling horizontal release damping to `25%` established the local mechanical
  sequence at ticks `727/736`: nine absent ticks, `0.023098 m` release gap,
  `0.016404 m` horizontal relocation, `0.009050 m` target error, and no
  allocator infeasibility. It reduced foot descent at recontact to
  `0.338178 m/s`, but the torso still arrived descending at `0.421155 m/s` and
  the terminal posture collapsed to `0.266217 m` height and `0.411262 rad`
  tilt. This is useful boundary evidence, not an atomic-step pass:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_horizontal_damping025_seed14002_20260725T024229989\seed14002.stdout.log`;
  and
- switching the bounded airborne vertical feedback from COM state to torso
  state saturated the existing `30 N` correction cap for all 16 command ticks
  and changed recontact torso descent only from `0.421155 m/s` to
  `0.420647 m/s`. It did not alter the failure class and was removed:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_airborne_torso_support_seed14002_20260725T024758443\seed14002.stdout.log`;
  and
- raising horizontal damping from `25%` to `50%` reduced release X speed to
  `-0.335980 m/s` and recontact target error to `0.003260 m`, but it also
  reduced upward release speed to `0.278967 m/s`. Recontact worsened to
  `0.630640 m/s` foot descent and `0.493934 m/s` torso descent, with eight
  torso-contact ticks:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_horizontal_damping050_seed14002_20260725T025245895\seed14002.stdout.log`;
  and
- separating the caps into `20 N` vertical and `4 N` horizontal tasks preserved
  vertical authority and softened recontact to `0.050343 m/s` foot descent,
  `0.299269 m/s` torso descent, and `0.385201 m` torso height with no allocator
  infeasibility. Four absent ticks were real, but horizontal relocation reached
  only `0.005826 m` and the reversal drove swing-joint rate to `5.850002 rad/s`:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_axis_bounded_release_seed14002_20260725T025828146\seed14002.stdout.log`;
  and
- increasing the independent horizontal bound to `8 N` reduced release X
  speed to `-0.283470 m/s`, but delayed release to the tick-`730` deadline,
  reduced upward release speed to `0.184645 m/s`, and recontacted after only two
  absent ticks with `0.001254 m` relocation:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_axis_bounded_release8_seed14002_20260725T030236152\seed14002.stdout.log`;
  and
- preserving measured upward release velocity through a four-tick decay
  extended airborne dwell from four to eleven ticks and established
  `0.020870 m` relocation with `0.004130 m` error. The new last-airborne
  receipt measured `-0.443544 m/s` foot descent and `-0.432479 m/s` torso
  descent one tick before impact; the extra unsupported time lowered recontact
  torso height to `0.361883 m` and still collapsed terminal recovery:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_release_velocity_preservation_seed14002_20260725T030718836\seed14002.stdout.log`;
  and
- reducing the two-tick preservation target to half of measured velocity above
  the `0.05 m/s` floor did not split the behavior. It still remained absent for
  eleven ticks, recontacted with `0.601758 m/s` foot descent and `0.437527 m/s`
  torso descent at `0.362018 m` torso height, and collapsed. The relocation
  itself passed locally at `0.022235 m` with `0.002765 m` error. This proves
  that the full measured-velocity value was not the controlling threshold:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_release_scale050_seed14002_20260725T032029770\seed14002.stdout.log`;
  and
- reducing the same target again to one fifth also produced eleven absent ticks,
  `0.022764 m` relocation, `0.603712 m/s` foot descent, and `0.435209 m/s`
  torso descent. This rejects vertical release-velocity preservation as the
  effective continuation control axis:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_release_scale020_seed14002_20260725T032533084\seed14002.stdout.log`;
  and
- applying `0.30 m/s` horizontal target velocity for the first two relocation
  ticks produced the intended middle branch: seven absent ticks, `0.013425 m`
  relocation, `0.011902 m` target error, slightly upward post-solver foot
  velocity, `0.376263 m` torso height, `0.065688 rad` tilt, no torso contact,
  and no allocator or structural failure. The first bounded semantic task was
  `(17.381260, -8.302903, -5.380847) N`, within the unchanged `20 N` norm cap.
  Terminal recovery still failed because the `6.039802 rad/s` swing-joint rate
  and torso angular velocity prevented the recovery dwell from latching:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_horizontal_redirection030_seed14002_20260725T033043831\seed14002.stdout.log`;
  and
- doubling relative-joint damping to `0.40 N m s/rad` with a `1.0 N m` cap
  reduced terminal angular speed but worsened planted-foot drift and did not
  preserve torso height. The controller is therefore not merely
  under-damped:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_joint_damping1_seed14002_20260725T033556320\seed14002.stdout.log`;
  and
- rebasing all twelve joint pose references to the live configuration on the
  semantic recontact tick removed the stance springs still carrying the body.
  Torso height fell to `0.255290 m` within 26 ticks and ended at `0.169681 m`.
  This rejects a full live-pose rebase even at the improved recontact:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recontact_all_pose_rebase_seed14002_20260725T034158055\seed14002.stdout.log`;
  and
- holding the recontacted limb in the Cartesian semantic task removed the
  old-pose switch but coupled that leg too aggressively into a three-support
  attitude loop. It produced large roll/pitch oscillation, eight torso-contact
  ticks, and `0.419767 rad/s` terminal angular speed:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recontact_swing_hold_seed14002_20260725T034826870\seed14002.stdout.log`;
  and
- readmitting the fourth contact to the existing attitude block commanded zero
  ticks and reproduced the baseline exactly. Predictive retreat disables that
  entire block before continuation recovery, proving that recontact recovery
  had vertical support but no attitude moment:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_four_contact_attitude_seed14002_20260725T035238702\seed14002.stdout.log`;
  and
- a separate continuation recovery attitude loop commanded its full bounded
  `5 N m` roll/pitch and `1 N m` yaw moments for 265 ticks. It reduced terminal
  pitch only slightly while sustaining `0.638076 rad/s` angular speed and
  lowering terminal torso height to `0.266012 m`. Attitude correction alone
  cannot resolve the planted-foot/body kinematic mismatch:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recovery_attitude5_seed14002_20260725T035735410\seed14002.stdout.log`;
  and
- starting body translation one tick after recontact did latch and command 265
  ticks, but the still-descending, rotating body moved backward and slipped
  every foot by up to `0.205182 m`. Terminal tilt worsened to `0.490749 rad`.
  Dynamic plant-then-follow requires a gentler pre-handoff state than this one:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_early_body_follow_seed14002_20260725T040306706\seed14002.stdout.log`;
  and
- raising the continuation semantic task norm from `20 N` to `24 N` shortened
  airborne dwell from seven to six ticks, raised recontact torso height to
  `0.379433 m`, and reduced torso descent to `0.355536 m/s`. It missed the
  local relocation gates narrowly at `0.011985 m` displacement and
  `0.013136 m` target error:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_semantic_force24_seed14002_20260725T040728283\seed14002.stdout.log`;
  and
- raising the two-tick horizontal target to `0.40 m/s` crossed to a nine-tick
  flight. Relocation passed at `0.017546 m`, but recontact torso height fell to
  `0.369194 m` and descent rose to `0.428880 m/s`:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_force24_redirect040_seed14002_20260725T041106834\seed14002.stdout.log`;
  and
- `0.32 m/s` remained on the improved six-tick branch with `0.379413 m`
  recontact torso height and `0.355583 m/s` torso descent. Relocation improved
  smoothly to `0.012392 m`, only `0.000608 m` below the gate:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_force24_redirect032_seed14002_20260725T041518195\seed14002.stdout.log`;
  and
- `0.35 m/s` passed both local relocation gates at `0.015335 m` displacement
  and `0.010580 m` target error, but crossed to an eight-tick flight. The
  harder recontact left the torso at `0.372804 m` descending at
  `0.406526 m/s`; the unchanged post-contact controller still collapsed to
  `0.255690 m` height and `0.400727 rad` tilt by development tick 999:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_force24_redirect035_seed14002_20260725T042155000\seed14002.stdout.log`;
  and
- `0.34 m/s` also selected the eight-tick branch. It passed the local gates at
  `0.015097 m` displacement and `0.010747 m` target error, with effectively
  unchanged recontact descent (`0.406618 m/s`) and terminal collapse. This is
  retained as the lower passing horizontal command:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_force24_redirect034_seed14002_20260725T042450000\seed14002.stdout.log`;
  and
- distributing the measured release force as an upward endpoint request over
  the three support limbs issued five ticks at `20 N` total, but the sign was
  wrong for this actuator mapping: release torso descent worsened from
  `0.217327` to `0.229380 m/s`. Recontact descent improved slightly to
  `0.391876 m/s`, and terminal height improved by roughly one centimeter, but
  the posture still collapsed. The upward endpoint sign is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_release_reaction_comp_seed14002_20260725T042930000\seed14002.stdout.log`;
  and
- reversing that request to the ground-directed endpoint sign improved release
  torso descent from `0.217327` to `0.208330 m/s`, but selected a nine-tick
  flight and worsened recontact descent to `0.436767 m/s`. Recontact height
  fell to `0.369713 m`; terminal height improved only to `0.269795 m` while
  tilt worsened to `0.419456 rad`. Both compensation signs are rejected, and
  the policy is inactive:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_release_reaction_comp_down_seed14002_20260725T145100000\seed14002.stdout.log`;
  and
- applying vertical-only contact-consistent pose-reference integration after
  recontact issued 142 command ticks and 1,704 joint-reference updates. It
  improved terminal torso height from `0.255831` to `0.295633 m`, proving the
  reference equilibrium has useful authority, but the asymmetric leg geometry
  pitched the torso to `0.477209 rad`; terminal tilt reached `0.482612 rad` and
  one foot stopped bearing. Maximum joint-reference rate was
  `0.119666 rad/s`, below its `0.25 rad/s` cap, and maximum accumulated
  rotation was `0.123872 rad`, below its `0.22 rad` cap. The vertical-only
  reference is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_early_vertical_posture_seed14002_20260725T145925000\seed14002.stdout.log`;
  and
- adding contact-consistent roll/pitch twist at a `0.08 rad/s` angular-speed
  cap preserved the exact local recontact result (`0.015097 m` relocation and
  `0.010747 m` target error) and improved terminal tilt from `0.482612` to
  `0.407599 rad`. The request reached its angular-speed cap while maximum
  joint-reference rate remained `0.198273 rad/s`, below its `0.25 rad/s` cap.
  Terminal torso height was only `0.281646 m`, one foot stopped bearing, and
  maximum accumulated joint-reference rotation reached `0.193968 rad`.
  Therefore the `0.08 rad/s` twist reference is a useful directional result
  but is rejected as a recovery:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_early_twist_posture_seed14002_20260725T150735000\seed14002.stdout.log`;
  and
- raising only the angular-speed cap to `0.12 rad/s` retained all four terminal
  contacts and reduced terminal tilt again to `0.344780 rad`, but lowered torso
  height to `0.267132 m`. The integrator reached its `0.22 rad` accumulated
  reference-rotation cap, and the relocated foot drifted to `0.082580 m` from
  its phase-start position. This cap is rejected even though it establishes a
  useful contact-retention direction:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_twist012_seed14002_20260725T151700000\seed14002.stdout.log`;
  and
- raising only the early vertical endpoint-speed cap to `0.05 m/s` improved
  tick-800 torso height by about `0.006 m` and reduced maximum hinge-axis error
  from `0.161282` to `0.156197 rad`, but weakened the pitch-correction
  differential. One foot stopped bearing after 115 command ticks, and terminal
  tilt worsened to `0.449753 rad`. The unequal rate change is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_twist012_vertical005_seed14002_20260725T152600000\seed14002.stdout.log`;
  and
- uniformly time-scaling the fixed-foot twist reference by `1.5` improved final
  foothold displacement to `0.065782 m` and stayed below the accumulated
  rotation cap at `0.186549 rad`, but it became dynamically aggressive. One
  foot stopped bearing after 127 command ticks; terminal height was
  `0.274473 m`, tilt was `0.377414 rad`, and angular speed rose to
  `0.051000 rad/s`. The `1.5` scale is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_twist012_uniform15_seed14002_20260725T153700000\seed14002.stdout.log`;
  and
- the `1.2` uniform scale reached the `0.22 rad` accumulated-reference cap and
  lost a contact late in its 219 command ticks. Terminal height changed only
  from `0.267132` to `0.266268 m`, while tilt changed only from `0.344780` to
  `0.340403 rad`; structural hinge error worsened slightly to `0.162774 rad`.
  The `1.2` scale is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_twist012_uniform12_seed14002_20260725T154700000\seed14002.stdout.log`;
  and
- restoring the `1.0` rate and raising only the early accumulated-reference
  cap to `0.35 rad` produced the same terminal `0.267132 m` height,
  `0.344780 rad` tilt, four contacts, and `0.082580 m` final foot displacement
  as the `0.22 rad` run. Only one abduction reference moved beyond the old cap,
  reaching `0.224842 rad`. Larger excursion is therefore not the governing
  constraint during the first 240 ticks:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_twist012_accum035_seed14002_20260725T160000000\seed14002.stdout.log`;
  and
- preserving 240 twist-aware ticks and then applying 240 vertical-only ticks
  raised torso height temporarily to `0.277843 m`, but tilt regressed to
  `0.390380 rad`. The front-right foot first lost bearing at tick `1094`;
  terminal height was `0.271383 m`, tilt was `0.391971 rad`, and final swing
  foot displacement worsened to `0.090840 m`. The staged split is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_staged_posture_seed14002_20260725T161200000\seed14002.stdout.log`;
  and
- sustaining the twist-aware reference for all 480 early-recovery ticks kept
  four contacts at the terminal sample and reduced terminal tilt to
  `0.306060 rad`, but torso height fell to `0.256490 m`. The controller reached
  the raised `0.35 rad` accumulated-reference cap, front-right first stopped
  bearing at tick `1134`, and rear-left drifted `0.079863 m` with
  `0.085721 m` target error. Sustained attitude shaping consumed leg workspace
  without recovering height and is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_sustained_twist_seed14002_20260725T155417093\seed14002.stdout.log`;
  and
- the `0.33 m/s` initial horizontal command crossed both unchanged local gates
  at `0.013765 m` relocation and `0.011690 m` target error. It reduced
  recontact foot descent from `0.190339` to `0.027357 m/s` and torso descent
  from `0.406618` to `0.382677 m/s`, with no contact loss through development
  tick `999`. It selected a seven-tick rather than six-tick branch, however,
  and the relocated foot subsequently drifted `0.141709 m` while hinge-axis
  error reached `0.170632 rad`. This is a useful release bracket, not an atomic
  step or accepted recovery:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_redirect033_seed14002_20260725T160213638\seed14002.stdout.log`;
  and
- lowering the same command to `0.325 m/s` also crossed the gates at
  `0.013658 m` relocation and `0.011776 m` error, but selected the same
  seven-tick branch and reproduced the `0.33 m/s` post-contact trajectory:
  `0.382712 m/s` recontact torso descent, `0.141732 m` later foot displacement,
  and `0.170764 rad` hinge error. Further velocity bracketing inside this branch
  is rejected:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_redirect0325_seed14002_20260725T160708885\seed14002.stdout.log`;
  and
- damping only rear-left horizontal foot velocity for 60 ticks commanded all
  60 ticks and reached its `4 N` cap. It modestly reduced early foot motion and
  hinge error from `0.170764` to `0.167741 rad`, but later foot displacement
  worsened from `0.141732` to `0.142277 m` and terminal tilt rose from
  `0.322490` to `0.327062 rad`. The 60-tick duration is rejected because it
  rebounds after its initially useful arrest:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recontact_horizontal_damping_seed14002_20260725T161323451\seed14002.stdout.log`;
  and
- shortening that damper to 20 ticks worsened the same failure. It commanded
  all 20 ticks at the `4 N` cap, increased final foot displacement to
  `0.144997 m`, and left torso height at `0.259107 m`. The planted-foot
  endpoint-force damper is rejected and disabled:
  `<evidence-root>\temp-roots-2026-07-28\sporespore_same_world_recontact_horizontal_damping20_seed14002_20260725T161753800\seed14002.stdout.log`.

The front-left experiment rejected before rear-left commissioning is also not
valid locomotion evidence.

## Next mechanical intervention

Test an axis-bounded continuation release around the bounded local sequence:

1. Preserve the inherited `720-840` lift window and all position/velocity gains.
2. Replace the continuation's absolute `0.150 m` pre-release target with a
   target `0.030 m` above its live phase-start foot center.
3. Require a measured geometric release gap of at least `0.002 m` plus the
   unchanged semantic contact-absence dwell. This is a flat-ground
   continuation contract, not a terrain-clearance claim.
4. Bound the continuation-only pre-release task force at `20 N`. This is below
   the approximately `22 N` unconstrained request and is intended to avoid the
   stance-contact overload observed with the `40 N` cap. It does not relax or
   bypass the allocator's normal-force feasibility bound.
5. While the foot is still bearing, track its measured horizontal position
   instead of the stale phase-start anchor. Use the existing velocity gain with
   a separate `4 N` horizontal damping-force bound and the proven `20 N`
   vertical separation bound. The combined task magnitude can reach only
   `sqrt(20^2 + 4^2) = 20.396 N`, but horizontal damping can no longer consume
   the vertical component of a shared spherical cap. Restore the ordinary 3-D
   swing target immediately after measured release.
6. Preserve the `0.025 m` horizontal relocation, six-tick lift, ten-tick lower,
   twenty-tick recontact bound, and every terminal recovery gate.
7. Record the active live-horizontal-position policy, horizontal damping-force
   bound, measured maximum horizontal and vertical task forces, target height,
   measured release gap, release/recontact kinematics, and all existing
   force/structure receipts.
8. Reject the change if it achieves a smaller impulse by losing a real contact
   release or the ordered absence/recontact sequence.
9. Keep these overrides out of the underlying front-right and rear-left
   experiment configurations.
10. Retire continuation release-velocity preservation. Both the half- and
    one-fifth-scale commands stayed on the same eleven-tick branch as full
    preservation, while the inherited trajectory without preservation returned
    in four ticks.
11. Record the final airborne tick and its foot, lower-limb, and torso
    velocities so touchdown approach is measured before collision resolution.
12. During the first two relocation ticks, require `0.30 m/s` target velocity
    along the declared horizontal foothold direction. This removes the
    smoothstep endpoint's zero-velocity mismatch while retaining the existing
    `20 N` total semantic relocation force limit. Record the first target
    position, target velocity, and bounded task force so the command is
    auditable.
13. Restore the certified `0.20 N m s/rad`, `0.5 N m` relative-joint damping.
14. Keep the all-joint semantic-recontact rebase disabled.
15. Keep the post-recontact Cartesian swing-task hold disabled.
16. Keep the separate continuation recovery attitude loop disabled.
17. Begin the existing bounded body-translation ramp one tick after a valid
    semantic recontact was rejected; restore its 600-tick recovery gate.
18. Retain the continuation `24 N` semantic-relocation norm and the lower
    passing `0.34 m/s` horizontal command. The `0.32` command stayed on the
    six-tick branch only `0.000608 m` short; both `0.34` and `0.35` selected an
    eight-tick flight; and `0.40` stayed airborne nine ticks. No useful
    seven-tick branch was observed in the bracket.
19. During continuation-only contact release, measure the actual upward swing
    task force and distribute an equal total ground-directed endpoint request
    over the three still-bearing support limbs. The sign is explicit because
    this Jacobian-transpose mapping applies its requested force at the endpoint:
    pushing planted endpoints downward produces the desired upward torso
    reaction. Cap each support request at `7 N`, require a real support contact,
    and record direction, command ticks, and maximum total/per-support force.
    This tests whether the release reaction can be arrested before touchdown
    without adding any post-impact attitude authority.
20. The measured release-reaction compensation is rejected in both endpoint
    directions and must remain inactive. Instead, isolate the already existing
    contact-consistent posture mechanism from every attitude and horizontal
    command. For at most 240 ticks immediately after semantic recontact, and
    only while all four feet bear and the torso does not contact the floor,
    integrate a vertical-only downward relative-endpoint reference through
    every bearing limb. Reuse the `0.025 m/s` endpoint-speed cap, `0.25 rad/s`
    per-joint reference-rate cap, `0.22 rad` accumulated reference-rotation
    cap, and damped least-squares Jacobian. This changes the pose-controller
    equilibrium toward leg extension without a teleport, instantaneous rebase,
    direct body force, attitude loop, or horizontal body command. Record the
    first tick, command ticks, update count, maximum rate/rotation, and
    per-limb command ticks.
21. Vertical-only reference integration is rejected because it extends the
    asymmetric post-step legs unevenly and produces a pitch runaway. Retain the
    same bounded joint-reference integrator but add its contact-consistent
    angular kinematics: derive a desired body roll/pitch velocity from the
    existing position and velocity gains, cap it at `0.08 rad/s`, and subtract
    its `omega cross r` contribution from each bearing foot's relative-endpoint
    velocity before the DLS update. Cap the combined relative endpoint velocity
    at `0.05 m/s`. This is one kinematically consistent pose-reference update;
    it is not the separately rejected direct body-attitude torque loop. Record
    the active angular-reference policy plus maximum desired angular and
    combined endpoint speeds.
22. The `0.08 rad/s` angular reference reduced pitch but saturated at its
    declared speed cap and still lost a bearing contact. Preserve every
    release, recontact, damping, DLS, accumulated-rotation, and combined
    endpoint-speed setting; raise only the attitude-speed cap to
    `0.12 rad/s`. Reject it if the stronger kinematic request reaches the
    `0.25 rad/s` joint-rate or `0.22 rad` accumulated-rotation bound, loses
    contact earlier, degrades terminal height, or does not materially reduce
    pitch. This is a bounded authority bracket, not acceptance of the
    mechanism.
23. The `0.12 rad/s` bracket retained all four contacts but spent nearly the
    entire combined endpoint budget extending the front legs for pitch
    correction, leaving too little rear-leg extension for height recovery.
    Keep the later post-translation stabilization cap at `0.025 m/s`; introduce
    a continuation-early-only vertical endpoint-speed cap of `0.05 m/s`.
    Preserve the `0.05 m/s` combined twist cap, `0.25 rad/s` joint-reference
    rate cap, and `0.22 rad` accumulated-rotation cap. This changes only the
    vertical-versus-angular allocation inside the same bounded DLS reference
    integrator. Reject it if height does not improve without materially
    worsening tilt, contact retention, joint-reference saturation, or final
    foothold drift.
24. The early-only `0.05 m/s` vertical cap is rejected because changing the
    vertical/angular ratio loses contact and pitch control. Restore the
    `0.025 m/s` vertical cap and preserve the `0.12 rad/s` angular cap. Apply
    one `1.5` reference-rate scale uniformly to the early vertical body speed,
    angular body speed, combined endpoint-speed cap, and per-joint reference
    rate. Keep the `0.22 rad` accumulated-reference limit unchanged. This
    advances the same fixed-foot body-twist trajectory faster without changing
    its direction or total allowed joint excursion. Reject it if it reaches the
    excursion cap without improving early height, tilt, contact retention,
    structural alignment, and foothold drift together.
25. The `1.5` uniform scale crossed a contact-retention threshold while the
    unscaled reference retained all four contacts. Preserve the exact reference
    field and all caps, but bracket only the uniform scale at `1.2`. Accept the
    direction for further recovery work only if all four contacts remain and
    the terminal height/tilt pair improves over the unscaled
    `0.267132 m`/`0.344780 rad` result without worsening structural alignment
    or the final foothold gates.
26. The `1.2` rate bracket is rejected and rate scaling is no longer the active
    axis. Restore the contact-retaining `1.0` scale and keep its vertical,
    angular, combined-endpoint, and joint-reference-rate limits. Raise only an
    early-specific accumulated-reference cap from `0.22` to `0.35 rad`; the
    later stabilization cap remains `0.22 rad`. The larger early cap remains
    inside the fixture's `+-0.8 rad` physical joint limits and is still reached
    only through the existing `0.25 rad/s` rate bound. Record final
    contact-by-limb state plus the first post-recontact contact-loss tick and
    limb IDs. Reject the cap if additional excursion does not recover height
    and attitude together or worsens contact, structural alignment, or foothold
    drift.
27. The early `0.35 rad` cap does not materially change the first 240 ticks, so
    keep it only as bounded room for a second recovery stage. Preserve 240 ticks
    of the contact-retaining twist-aware reference, then disable only its
    angular-velocity contribution while continuing vertical-only
    contact-consistent integration for another 240 ticks. The desired
    roll/pitch pose references accumulated by stage one remain active in the
    ordinary joint controller. This separates attitude shaping from subsequent
    height extension without rebasing, restoring an old pose, applying a body
    force/torque, or changing release/recontact mechanics. Record the total
    early duration and attitude-enabled duration separately. Reject the staged
    controller if it loses contact or fails to improve height without undoing
    the stage-one attitude and foothold gains.
28. The vertical second stage is rejected because disabling twist correction
    allows pitch to regrow and unloads front-right. Preserve the 480-tick total
    recovery window, `1.0` rate scale, and `0.35 rad` early accumulated cap, but
    keep the twist-aware contribution active for all 480 ticks. This tests
    whether sustained attitude shaping can drive the angular request out of
    saturation, after which the unchanged vertical component can extend all
    four legs. Reject it if the extended twist reaches the accumulated cap,
    loses any contact, or fails to improve height, tilt, structural alignment,
    and foothold displacement together.
29. Sustained twist is rejected because it reaches the raised accumulated
    limit without restoring torso height. Restore the contact-retaining
    240-tick twist-aware baseline, `1.0` rate, and `0.22 rad` accumulated cap.
    Preserve the `24 N` semantic task norm and every release, recontact, and
    recovery setting, but bracket only the two-tick initial horizontal target
    velocity between the observed `0.32` and `0.34 m/s` branches at
    `0.33 m/s`. Accept the bracket for recovery work only if it crosses both
    unchanged local relocation gates while retaining the gentler six-tick
    flight and materially reducing recontact torso descent. A gate miss, an
    eight-tick branch, or no handoff improvement rejects the bracket.
30. The `0.33 m/s` bracket establishes a softer exact local recontact but not
    the predicted six-tick branch, and its later planted-foot drift is worse.
    Preserve the restored 240-tick recovery baseline and every other release
    setting. Test only the interpolated `0.325 m/s` initial horizontal command.
    It is useful only if both local gates remain exact while recontact descent
    moves toward the gentler `0.32 m/s` observation and post-contact foothold
    drift does not reproduce the `0.33 m/s` regression.
31. The `0.325 m/s` bracket reproduces the `0.33 m/s` branch, so stop tuning
    initial target velocity. Preserve its exact softer local recontact and add a
    continuation-only damper for the newly planted rear-left foot. While that
    foot bears, and for at most 60 ticks after semantic recontact, request only
    horizontal endpoint force opposite measured horizontal foot velocity using
    `20 N s/m` gain and a `4 N` norm cap. Do not hold a world position or request
    vertical force. Record command ticks, maximum observed horizontal speed,
    and maximum damping force. Reject it if it changes the exact release or
    recontact gates, loses contact, increases structural error, or does not
    materially reduce later foothold drift.
32. The 60-tick horizontal damper is rejected because its early arrest becomes
    a later rebound. Preserve its `20 N s/m` gain, `4 N` force cap, contact gate,
    and every other mechanism; shorten only the duration to 20 ticks. Reject it
    if early arrest does not persist after the command ends or if height, tilt,
    contact retention, structural alignment, or foothold drift worsen.
33. The 20-tick bracket also worsens foothold drift. Disable the planted-foot
    endpoint-force damper, restore the lower-drift `0.34 m/s` exact local
    sequence, and preserve the receipted mechanism only as negative development
    instrumentation. Do not spend another bracket on its gain, cap, duration,
    or sign. The next intervention must address gait-level contact sequencing
    or pose-reference continuity rather than forcing a constrained foot.

Only after the hard seed reaches a measurably gentler and still bounded
recontact should the full post-recontact recovery run be used to tune the
existing contact-consistent posture integrator. A terminal recovery pass is
still required; lower impact by itself does not establish an atomic step.

## Sequential-step acceptance gate

The front-right then rear-left sequence is established only when all exact
seeds `14001`, `14002`, and `14003` pass with:

- one world build and the same viewport/world/torso identities;
- exactly two phase invocations with one continuation boundary;
- both atomic-step predicates true;
- ordered global release and semantic recontact ticks;
- the original per-step translation floors;
- all four foot contacts at the end;
- no torso-ground contact;
- final torso height, tilt, and angular speed inside the existing atomic-step
  recovery envelope;
- joint anchor, hinge axis, actuator, torque-rate, structural, and allocator
  bounds intact; and
- gait, walking, and guidance claims still false.

Passing this gate authorizes repeated-cycle work. It does not yet establish
walking.

## Walking acceptance gate

The first walking experiment should use a conservative crawl order because it
maximizes the support polygon and reuses the proven atomic machinery:

```text
front_right -> rear_left -> front_left -> rear_right
```

The exact order may change if measured support margins prove another crawl
ordering safer, but the decision and evidence must be recorded before a claim
change.

Walking requires, at minimum:

- one continuously simulated fixture;
- all four limb identities participating;
- at least two complete ordered limb cycles;
- no phase reset that rebuilds, freezes, restores, or teleports the body;
- every swing limb showing an ordered bearing-contact release, airborne dwell,
  forward relocation, semantic recontact, and recovery;
- monotonically increasing global phase timestamps;
- positive net whole-system COM and torso displacement along the declared
  travel axis;
- bounded lateral drift and yaw;
- bounded cumulative foot slip for stance feet;
- all four feet bearing at the terminal sample;
- no torso-ground contact;
- terminal height, tilt, linear speed, and angular speed inside preregistered
  recovery bounds;
- no missing actuation receipts, structural saturation, or allocator
  infeasibility; and
- exact-seed repeatability.

The first passing repeated-cycle experiment may claim bounded canonical
quadruped walking in the laboratory. It may not claim running, arbitrary
steering, terrain robustness, general creature locomotion, or automatic
guidance.

## Regression and publication sequence

For each controller change:

1. format and lint the edited GDScript;
2. run the isolated seed-`14001` sequence probe;
3. inspect the full terminal receipt, not only the process exit code;
4. run seeds `14002` and `14003` after the first seed passes;
5. add an exact automated sequence test before promoting the result;
6. rerun the fresh front-right and rear-left atomic programs;
7. run the full `test_experimental_br14a*.gd` family;
8. update this ledger and the BR14A bootstrap with report paths and exact claim
   language;
9. stage only the intentional files;
10. commit an evidence-coherent unit of work; and
11. push `main`.

## After walking

No second morphology begins until the quadruped passes the repeated walking
gate. The provisional best next target is a creature with more than four legs,
because it exercises morphology scaling while reusing stance contacts,
per-limb phase coordination, semantic release/recontact, and the same receipt
pipeline. A millipede is the likely high-value specialization after a general
six- or eight-legged walker.

Running should follow only after walking has a speed-parameterized controller
and a gait transition experiment. A biped, snake, and sea urchin are more
architecturally distinct and therefore provide less reuse for the immediate
post-quadruped step.

## BR14A.6 physical wave-gait walking observation

### Result

BR14A.6 now has a reproducible development walking observation. The passing
fixture is not the earlier atomic-step rig with phases replayed in separate
worlds. It is one continuously simulated physical quadruped:

- one Jolt physics world built once and never reset;
- one free `3.0 kg` torso, four free upper-leg bodies, and four free spherical
  distal foot bodies;
- eight `HingeJoint3D` motors as the only locomotor authority;
- four direct physics-state contact observers;
- a real high-friction floor;
- no torso force, impulse, velocity, transform, freeze, teleport, root pin,
  rail, guide, or world rebuild after release; and
- a continuous one-leg-at-a-time wave schedule with warmup, an evidence
  boundary, three measured cycles, cooldown, and terminal recovery.

The working implementation is:

- `scripts/lab/gait/physical_wave_gait_quadruped.gd`;
- `scripts/lab/probes/probe_physical_wave_gait_quadruped.gd`;
- `scripts/lab/probes/demo_physical_wave_gait_quadruped.gd`;
- `tests/test_experimental_br14a_6_physical_wave_gait_quadruped.gd`; and
- `scripts/run_br14a_physical_wave_gait_development.ps1`.

The pinned physical candidate uses:

```text
physics_hz                         120
Jolt velocity steps                20
Jolt position steps                 6
motor direction sign               -1
knee motor impulse scale           10
knee flexion scale                1.75
phase order             lateral wave
swing duration                      72 ticks
contact-conditioned clearance     0.40 rad, all scheduled limbs
evidence-boundary alignment        112 ticks
```

The clearance term is not a root or body-space lift. During a limb's declared
swing window, it adds bounded knee flexion only while that limb's direct
physics-state observer still reports a real bearing floor contact. Once the
foot releases, the extra term stops. Its per-limb execution counts are retained
in the summary.

The 112-tick alignment is also not a reset or a neutral-pose restoration. The
gait continues without interruption after warmup. Evidence starts at a natural
four-contact point after the warmup rear-left foot has physically recontacted.
This preserves the coupled dynamics while satisfying the preregistered
four-contact evidence boundary.

### Exact passing witness

The pinned run completed 2,392 physics ticks. Evidence began at tick 712 and
ended at tick 1,792. Its accepted contact cycles were:

```text
front_left   2
front_right  3
rear_left    3
rear_right   3
```

There were zero rejected short or non-relocating cycles. The minimum accepted
forward relocation for each limb was:

```text
front_left   0.028419435 m
front_right  0.014799535 m
rear_left    0.023825526 m
rear_right   0.018079415 m
```

The whole-body witnesses were:

```text
evidence displacement   (0.849883, -0.001190, 0.067920) m
final displacement      (1.042311,  0.010201, 0.088408) m
minimum torso height     0.427514 m
final torso height       0.439622 m
maximum tilt             0.136237 rad
final yaw drift          0.160445 rad
maximum anchor error     0.022944 m
maximum hinge-axis error 0.096369 rad
torso-contact ticks      0
motor commands           19,136
```

All walking receipts were true:

- one continuous world and zero resets;
- pinned Jolt `20/6` solver settings;
- no direct torso locomotor authority;
- initial and evidence-boundary four-contact stance;
- every contact observer executed;
- every limb completed at least two accepted contact cycles;
- every limb's accepted cycles relocated forward;
- positive evidence and final forward translation;
- lateral drift below `0.10 m`;
- bounded yaw, tilt, torso height, anchor error, and hinge-axis error;
- zero torso contact; and
- terminal four-contact recovery.

The visible presentation wrapper renders the exact same rigid bodies, joints,
motors, and measurements with colored meshes, a floor, camera, light, and an
explicit development-claim label. The rendering layer has no physics
authority.

### Solver isolation and ordinary regression behavior

The established gait requires Jolt position-steps `6`; the older repository
baseline remains pinned to position-steps `4`. Changing `project.godot`
globally would alter previously exact BR14A trajectories and is therefore not
authorized by this observation.

The BR14A.6 test has two explicit modes:

- under the ordinary repository `20/4` solver, it performs a one-assertion
  containment check and refuses to impersonate the isolated walking variant;
- under the minimal `20/6` project created by the dedicated runner, it executes
  the complete 19-assertion exact walking test.

Run the complete isolated campaign from PowerShell at the repository root:

```powershell
.\scripts\run_br14a_physical_wave_gait_development.ps1
```

The runner creates three fresh minimal projects with private Godot user-state
directories, runs hidden workers, waits for natural exits, retains stdout,
stderr, and engine logs, scans for engine errors, hashes all sources and
outputs, and writes one scoped JSON report.

The first committed-source campaign passed `57/57` assertions with zero engine
errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_physical_wave_gait_committed\
  20260725T194255958\report.json
sha256:5ef5ed9acb606e76bceb9bb0619915e394355ea5b99dfd57136868e45f3fe7cc
source commit: 2ff1343161e42d9e618af32da4c6cae4f193a4e7
```

The complete ordinary-solver BR14A family was then rerun from scratch after
the same-world diagnostic compatibility fixes. It passed `23/23` programs and
`413/413` assertions with zero failures, timeouts, killed process trees, open
containment trees, engine errors, or stderr output:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_family_clean_post_walking_20260726T202000\
  reports\20260725T200345418\report.json
sha256:1ec6a20fa56f94da16bd24ed2661cb141416282d56121fdf8d79ef6f03564af6
test timeout: 600 seconds
```

That family run includes the fresh `17/17` three-seed rear-left atomic-step
reproduction and the BR14A.6 ordinary-solver containment assertion. It does
not replace the separate `20/6` walking campaign: under the repository's
pinned `20/4` solver, BR14A.6 deliberately refuses to execute or claim the
isolated solver-6 gait.

### Rejected same-world atomic continuation interventions

Before the independent physical wave-gait fixture was introduced, the hard
seed `14002` was reproduced in the original front-right then rear-left
same-world atomic harness. Front-right remained atomic. Rear-left reached
release and recontact gates but did not satisfy the complete atomic predicate.
It did not produce a defensible same-world alternating gait.

Three narrowly bounded continuation interventions were measured and rejected:

1. A release-phase vertical task-force ramp did not recover the rear-left
   continuation without worsening the coupled outcome.
2. Partial blending of the swing limb's joint-pose reference at semantic
   recontact did not establish the second atomic step.
3. Advancing the airborne center-of-mass target along the declared travel
   direction did not establish the second atomic step.

Their default values remain physically disabled: zero ramp ticks, an initial
force fraction of one, zero pose-reference blend, and zero airborne body
advance. These observations are negative development evidence, not support for
walking.

### Physical search ledger

The physical gait search retained the walking bound instead of weakening it:

- Jolt position-steps `4` produced all-limb cycles in one branch but exceeded
  the `0.025 m` joint-anchor bound and the lateral bound.
- Position-steps `8` improved structural alignment but repeatedly suppressed a
  front-limb cycle.
- Position-steps `5`, knee-flexion scale `2.0` produced all-limb repeated
  cycles but missed the anchor bound by about `1 mm` and exceeded the lateral
  bound.
- Position-steps `6`, knee-flexion scale `1.75` passed lateral, yaw, tilt,
  height, and structural bounds but initially gave front-right only one
  accepted cycle.
- Global swing-duration changes were rejected because they traded one missing
  limb cycle for another or worsened lateral drift.
- A `0.30 rad` contact-conditioned clearance assist produced repeated cycles
  on all limbs but drifted `0.199 m` laterally.
- A `0.40 rad` assist produced repeated cycles on all limbs with `0.055 m`
  lateral drift, but the original evidence boundary landed during a warmup
  foot's airborne interval.
- A 240-tick neutral-stance pause restored the boundary but disrupted the
  coupled gait and was rejected.
- Continuous evidence-boundary alignment at 80 ticks missed the lateral bound
  by `8.47 mm`; 96 ticks missed it by `2.47 mm`; 112 ticks passed at
  `0.088408 m`; and 120 ticks again missed at `0.103885 m`.

The accepted candidate is therefore the measured 112-tick natural contact
handoff, not a relaxed lateral threshold.

### Seeded initial-condition robustness

The next preregistered task has now produced a positive development result.
Three fresh solver-6 processes compiled campaign seeds `14601`, `14602`, and
`14603` into small but physically non-nominal initial conditions. Each seed
changes some combination of fixture clearance, yaw, common-body linear
velocity, torso angular velocity, and gait phase. The compiler and runtime both
fail closed outside these maximum bounds:

- vertical clearance: `0.002 m`;
- yaw: `0.010 rad`;
- common linear speed: `0.008 m/s`;
- torso angular speed: `0.008 rad/s`; and
- gait phase offset: three 120 Hz physics ticks.

The campaign preserves all nominal walking thresholds. It does not loosen the
forward, lateral, yaw, tilt, torso-height, torso-contact, joint-anchor,
hinge-axis, repeated-contact-cycle, or terminal four-contact gates.

The perturbed controller adds four bounded joint-schedule mechanisms:

1. Each limb has its own virtual gait clock and waits for a three-frame
   semantic contact transition near late swing release and early stance
   recontact.
2. A transition may be held for at most 96 ticks; a timeout is recorded and
   fails the walking predicate.
3. A 12-tick phase-skew leash prevents one limb's virtual clock from running
   away from the slowest limb.
4. A joint-only lateral correction scales the left/right hip target by gain
   `0.5/m`, hard-clamped to a 20 percent adjustment. It never commands root
   force, impulse, velocity, or transform.

The gait phase perturbation begins during the 112-tick natural alignment
window. Each evidence window ends only after every limb advances exactly
three virtual gait cycles, with a bounded 720-tick maximum extension. The
ordinary unperturbed controller keeps these robustness mechanisms disabled by
default except for inert configuration defaults, so its deterministic witness
does not change.

Run the isolated campaign from PowerShell at the repository root:

```powershell
.\scripts\run_br14a_physical_wave_gait_seeded_robustness.ps1
```

The final committed-source campaign passed `66/66` assertions with zero
engine errors:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_seeded_robustness_committed_e763cfa\
  20260725T215909896\report.json
sha256:6751ffb414501d70747e525d94cb27120e9a7d34b640aff2482cce049b2c107e
source commit: e763cfae1c7040bf97b8444e5db5bcafcb909b9f
scoped source tree dirty: false
```

Its per-seed results were:

| Seed | Accepted cycles FL/FR/RL/RR | Evidence forward | Final lateral | Maximum tilt | Maximum anchor error |
| --- | --- | ---: | ---: | ---: | ---: |
| `14601` | `3/3/3/3` | `0.879103 m` | `-0.045927 m` | `0.137616 rad` | `0.023153 m` |
| `14602` | `4/3/3/3` | `0.923291 m` | `-0.073017 m` | `0.117440 rad` | `0.022922 m` |
| `14603` | `3/3/3/4` | `0.952152 m` | `0.047350 m` | `0.088914 rad` | `0.023218 m` |

Every limb's minimum accepted-cycle relocation remained at least `0.012 m`;
all contact-gate timeout counts were zero. The same committed tree then passed
the original exact nominal campaign `57/57` across three fresh processes:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_nominal_walk_committed_e763cfa\
  20260725T220001844\report.json
sha256:c130636b16e99916449e4a197f34a1ee28909c37217c333baa6d6f2146bc4370
source commit: e763cfae1c7040bf97b8444e5db5bcafcb909b9f
```

That exact reproduction confirms that the optional robustness path preserves
the unperturbed witness bit-for-bit.

The complete ordinary-solver BR14A family was then rerun from scratch with the
new seeded program present. It passed `24/24` programs and `414/414`
assertions:

```text
<evidence-root>\temp-roots-2026-07-28\sporespore_br14a_full_family_post_seeded_e763cfa_retry_held\
  reports\20260725T221437070\report.json
sha256:754ebe7bc677fda86ae0948ee189af24ad5ae2f9a89e867f27581ebd9e6f7739
test timeout: 600 seconds per program
```

The report records zero failed programs, assertion failures, timeouts, killed
process trees, open containment trees, nonzero exits, engine-error programs,
unexpected engine errors, and missing or unreadable logs. Both solver-6
walking programs contributed exactly one passing solver-4 containment
assertion and did not execute an isolated walking trajectory inside the
ordinary family.

### Remaining claim boundary

The combined result establishes repeatable deterministic laboratory walking
and a small bounded initial-condition robustness observation for this canonical
quadruped fixture. The three nominal fresh-process repetitions were bit-for-bit
identical, which proves reproducibility of the pinned deterministic program.
The three perturbed seeds establish only the declared local envelope; three
samples are not evidence of broad distributional robustness.

It does not yet establish:

- robustness to larger initial-condition changes, external impulses, friction,
  mass, geometry, or terrain changes;
- steering, arbitrary headings, speed control, gait transitions, or running;
- walking for generated creatures or morphologies other than this fixture;
- broad or promotion-grade statistical robustness;
- formal milestone acceptance;
- encyclopedia or accepted-knowledge admission; or
- automatic creature-guidance authority.

The bounded hip-target correction is lateral stabilization around the original
heading, not arbitrary steering or heading control. The report and summary
explicitly keep all promotion and guidance authorities false. With the clean
ordinary-solver regression complete, the next quadruped task is morphology and
parameter generalization. Only evidence that survives declared mass, geometry,
friction, and generated-fixture variation should begin to support a reusable
walking system.

### Semantic gate versus performance contract

The current `0.040 m` minimum evidence-window torso advance is a semantic
walking gate: it rejects stationary cycling, backward motion, and contact
activity without meaningful forward translation. It is deliberately not
retroactively tightened. Historical evidence remains judged by the contract
frozen before those worlds ran.

Before the controller is described as performant rather than merely physically
walking, a separate prospective contract must freeze:

- evidence-window and terminal forward progress normalized by torso length;
- evidence-window mean and minimum forward speed;
- progress per accepted complete contact cycle;
- lateral displacement per unit forward progress; and
- performance retention under each separately declared perturbation.

The current implementation already uses contact/phase, heading/yaw,
cross-track position and velocity, and anchor-safety feedback. It does not yet
use projected COM, support polygon, capture margin, or body roll/pitch as
whole-system feedback inputs. The read-only support observer and the staged
diagnostic-to-control decision are specified in the
[generalization bootstrap](BR14A_QUADRUPED_GENERALIZATION_BOOTSTRAP.md#validated-critique-constraints).
That diagnostic must not be presented as a solved balance controller.

## Productization boundary

This bootstrap supplies the reference physical behavior and same-world
acceptance predicates for a future portable controller. It is not itself an
engine-neutral SDK:

- the fixture, observer, motor application, and worker lifecycle are
  Godot/Jolt-specific;
- controller and receipt code still uses GDScript and Godot value types;
- one solver's deterministic witness does not imply another solver's
  trajectory; and
- no second physics host has passed a conformance ladder.

The extraction destination, canonical morphology/state/command/actuation
contracts, adapter responsibilities, cross-engine conformance gates, and
phased roadmap are defined in the
[Engine-Neutral Locomotion SDK Bootstrap](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md).
The three paper sources and the exact decisions imported from them are recorded
in the
[Locomotion Research Sources and Adoption Ledger](research/LOCOMOTION_RESEARCH_SOURCES.md).

The current walking implementation should remain the independent oracle until
`Locomotion Semantics v1` and engine-free golden vectors exist. Productization
must extract the exact reference behavior before replacing its implementation.
