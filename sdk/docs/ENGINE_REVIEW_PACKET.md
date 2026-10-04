# A short route through the engine integration evidence

I built LoColemotion around two things: a portable locomotion controller and an
experiment harness that makes the results inspectable. The core carries body
geometry, ordered observations, velocity commands and angular-impulse budgets.
The harness binds a declared question to source, runtime, qualification,
authorization and retained outcomes.

This page points to the specific integration findings worth reviewing. The
[full comparison](ENGINE_INTEGRATION_COMPARISON.md) carries the explanation.
These are bounded host results. They do not establish formal cross-engine
trajectory equivalence, a solver ranking or an upstream engine defect.

## The two figures

- [Native actuator mapping](figures/host-actuation-mapping.png): how an outer
  angular-impulse budget becomes the command accepted by each adapter.
- [MuJoCo force sampling](figures/mujoco-force-sampling.png): completed-step
  force, post-state recomputation and momentum-inferred motor impulse in the
  first declared VH4 cell.

The mapping figure is a units and API illustration. The MuJoCo figure shows the
first 12 internal steps of retained data. Neither required another physics run.

## Exact profiles and review targets

| Integration | Profile in the retained work | What needs careful interpretation |
| --- | --- | --- |
| Godot / Jolt | Instrumented Godot 4.7; 1/120 s outer schedule; recovery worker Jolt velocity/position iterations 20/4 | Authored hinge frames and velocity sign; the hinge max-impulse parameter and the implementation's physics-step estimate; contact-frame and energy observation timing |
| Rapier / Parry | Rapier 0.34.0; ForceBased velocity motor; native stiffness zero; damping 10 N m s/rad; 16 solver small-steps with internal PGS/stabilization settings 3/5 | Native motor impulse readback at the small-step scale, rather than treating it as an accumulated outer-step impulse |
| MuJoCo | MuJoCo 3.11.0 official Windows CPython wheel; Python 3.11.9; five 1/600 s implicitfast steps per 1/120 s outer command | The force observation's sampling stage and the distinction between force-time budgeting and effective motor impulse |

The Godot column describes the retained adapter and recovery integration; it
has no new scalar host characterization. The Rapier VH1 result covers its exact
12-cell signed target/load grid. MuJoCo VH4 covers its exact 24-cell
target/load/initial-condition grid. Solver settings and signs belong to these
profiles, and are not general recommendations for other models.

Profile and source details:

- [Rapier VH1 declaration](../rapier_c6_force_based_velocity_only_host_characterization_vh1_preregistration.json)
  and [closure](../rapier_c6_force_based_velocity_only_host_characterization_vh1_closure.json).
- [MuJoCo VH4 declaration](../mujoco_c6_velocity_only_stability_host_characterization_vh4_preregistration.json)
  and [closure](../mujoco_c6_velocity_only_stability_host_characterization_vh4_closure.json).
- [Godot recovery source bindings](../explorer/recovery_sources.json).
- [Figure provenance and exact digests](../explorer/studio/engine_integration_figures_v1.json).

## Download the MuJoCo trace

[Download the original CSV export](figures/mujoco-force-sampling.csv).

- Size: 170,413 bytes; 1,800 internal-step rows plus the header.
- Cell: `unloaded_vn075_izero`, first in the declared VH4 order.
- Coverage: all rows of that one cell, out of 24 declared cells and 43,200
  retained internal-step rows. It is an illustrative subset of the full study.
- Columns: step index; post-step simulated time in seconds; completed-step
  force in N m; force recomputed at the post-step state in N m; motor impulse
  inferred from momentum in N m s; post-step joint velocity in rad/s.
- Raw-byte SHA-256:
  `9a67abea3823dccd5b0f5d89aa4a592e85288a4a775cbe9e513603a9a0a48a34`.

The public copy preserves the existing export byte for byte. Every CSV value
was checked against the corresponding column of the digest-bound original
report before publication. The figure record preserves the original export's
identity. No cell was selected for looking better, and no attempt was rerun or
rescored for this packet.

## Why the harness belongs in this review

MuJoCo VH1 remains a [valid negative](../mujoco_c6_velocity_only_host_characterization_vh1_closure.json).
VH3 remains [temporally invalid](../mujoco_c6_velocity_only_stability_host_characterization_vh3_closure.json):
its declared evaluation sampled the wrong force stage. VH4 is a separately
identified successor with its own declaration, qualification and execution
record. Correcting the implementation did not rewrite either earlier outcome.

The [harness guide](../../docs/HARNESS.md) explains those boundaries. The
[proof index](../../proof/README.md) retains the SDK1 **20/20 bounded milestones**
and the separate **19/25 broader-program** scope. Those scores are project
milestone results, not certification by the engine teams.

## What a reviewer can do with this packet

Inspect the units, sampling stages, profile choices and retained trace without
installing the full lab. The historical source commits cited by the closures
belong to the frozen research archive; [export provenance](../../EXPORT_PROVENANCE.json)
explains the public source boundary.

This packet does not provide a newly verified standalone reproducer. If a
finding warrants an upstream bug report, the next artifact is a minimal model
and runner with exact dependencies and expected versus observed behavior.
Any fresh execution has to use a separately declared and identified route;
it cannot reuse or revise the consumed experiments linked above.

The [license FAQ](../../LICENSE-FAQ.md) explains the custom community/commercial
terms and covered paths. Sharing a finding does not grant permission to
relicense project code into an upstream engine.
