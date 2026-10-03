# Rapier engine patches

This directory is source authority for minimal, version-pinned Rapier changes
needed by the SporeSpore adapter. The Cargo registry checkout and any patched
dependency copy are dependencies, not project source.

## R24D46 exact motor-work telemetry

[`rapier3d_0_34_0_sporespore_motor_work_telemetry_v1.patch`](rapier3d_0_34_0_sporespore_motor_work_telemetry_v1.patch)
applies only to the crates.io `rapier3d` 0.34.0 package with checksum
`4592f61e65aa81ecb8701576336c8e66e893f4ad6a1238efe9ff17f2c77006ef`.
Its complete source and claim contract is
[`r24d46_rapier_exact_solver_work_observer_contract_v1.json`](../../../recovery/r24d46_rapier_exact_solver_work_observer_contract_v1.json).

The patch adds the opt-in Cargo feature
`sporespore-motor-work-telemetry`. At every scalar rigid impulse-joint motor
constraint application it records:

- signed and absolute generalized impulse in Rapier's body2-minus-body1 joint
  coordinate;
- positive supplied work, positive absorbed-work magnitude, and signed net
  work;
- exact application and solver-small-step counts; and
- a monotonically published outer-step sequence used to reject stale data.

For one constraint application, Rapier applies its native constraint impulse
with plus sign to body1 and minus sign to body2. The generalized impulse in the
declared body2-minus-body1 coordinate is therefore the negative of the native
constraint delta impulse. Work is that generalized impulse multiplied by the
mean relative velocity immediately before and after the application. The patch
does not change the native impulse, bounds, solver order, or body-velocity
updates.

The adapter feature `sporespore-rapier-motor-work` consumes this surface. It is
intentionally empty at the stock dependency boundary so ordinary workspace
resolution remains compatible with unpatched crates.io Rapier. An isolated
qualification harness must enable both the adapter feature and the patched
Rapier feature explicitly. The collector rejects stale sequences, incomplete
counters, non-finite values, negative magnitude partitions, and impulse/work
partitions inconsistent beyond a bound derived from the exact f32 accumulation
count.

### Qualified scope and refusals

R24D46 is scoped to the active non-SIMD rigid-body impulse-joint path used by
the frozen R24D45 morphology. Enabling Rapier SIMD together with this patch
fails compilation. Generic/multibody constraints are not claimed.

The patch measures motor work only. It does not measure contact/friction work,
nonmotor joint or stabilization work, explicit external-force work, or
integration/numerical dissipation. Those channels remain typed refusals; a
mechanical-energy residual must not be relabelled as measured dissipation.
Consequently this source alone cannot close a complete energy partition,
authorize recovery physics, reclassify R24D45, claim prone-to-standing, or
advance an SDK milestone.

### Applying the patch

Do not edit the Cargo registry checkout in place and do not commit an absolute
dependency path to the workspace lockfile. Verify the cached `.crate` archive
against the contract's crates.io checksum, extract it into the durable evidence
directory, and run from that fresh extracted crate root:

```powershell
git -c core.autocrlf=false apply --check C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\rapier\engine_patches\rapier3d_0_34_0_sporespore_motor_work_telemetry_v1.patch
git -c core.autocrlf=false apply C:\Users\Cole\CodeStuff\games\SporeSpore\sdk\adapters\rapier\engine_patches\rapier3d_0_34_0_sporespore_motor_work_telemetry_v1.patch
cargo check --features sporespore-motor-work-telemetry
```

Feature-gated adapter compilation must use an isolated Cargo harness whose
`[patch.crates-io]` entry points at the freshly patched extraction. This
prevents the machine-local path override from rewriting `sdk/Cargo.lock`. The
shared [`patched Rapier zero-world runner`](../../../run_qsdk_patched_rapier_zero_world_qualification.ps1)
constructs that harness, retains the exact dependency source, logs, and
receipt, and proves that the repository worktree did not change.

## R24D47 scalar solver-phase energy-exchange telemetry

[`rapier3d_0_34_0_sporespore_energy_exchange_telemetry_v2.patch`](rapier3d_0_34_0_sporespore_energy_exchange_telemetry_v2.patch)
is a complete stock-to-successor patch for the same exact crates.io Rapier
`0.34.0` package. Do not apply the R24D46 patch first: this successor already
contains the qualified motor-work seam. Its opt-in
`sporespore-energy-exchange-telemetry` feature implies
`sporespore-motor-work-telemetry`.

The successor brackets the existing sequential scalar solver phases without
changing their order, equations, impulses, or velocity updates. For every
active island it measures total supported rigid-body kinetic energy immediately
before and after contact warmstart, biased joint solve, biased contact solve,
joint stabilization solve, and contact stabilization solve. One outer step
therefore publishes independent joint, contact/friction, warmstart, and total
signed kinetic-exchange accumulators with exact island, small-step, phase, CCD,
and active-body counters. A redundant total-versus-grouped partition makes a
missed or duplicated phase rejectable.

The public pipeline receipt also counts unsupported runtime capabilities:
non-dynamic active bodies, locked dynamic axes, damping, non-unit gravity
scale, user force or torque, gyroscopic forces, multibody participation, and
generic solver degrees of freedom. Parallel and SIMD configurations fail at
compile time. The R24D47 adapter combines this surface with all eight qualified
R24D46 motor receipts, subtracts motor net work from joint-phase exchange, and
publishes the remaining nonmotor joint/stabilization exchange separately from
contact/friction exchange. Explicit external work and passive dissipation are
zero only when every declared route-capability check passes, including exact
timestep, length-unit, warmstart, biased/stabilization iteration, CCD, and
sleep-disabled readback.

The public adapter entrypoint accepts the actual patched `PhysicsWorld` and an
ordered set of actuator joint handles. It derives the internal capability
receipt and all native motor samples from that live world; the raw receipt is
crate-private and cannot be supplied by an SDK caller. Only external impulse-
application and intervention counts remain host inputs because Rapier does not
retain those application-level histories.

Integration and numerical closure defect is not manufactured into a work or
dissipation channel. It remains the independent signed/absolute V2 energy-
balance residual, and the existing `0.25 J` physical gate is unchanged. The
[R24D47 contract](../../../recovery/r24d47_rapier_energy_exchange_accounting_contract_v1.json)
content-addresses all twelve changed upstream files and the complete patch.
The shared zero-world runner consumes contract-declared preflight expectations,
so this successor reuses the same archive, patch, isolated-build, audit, lock,
and receipt mechanics without adding a physical canary or a gate-specific
runner.

The sole official R24D47 zero-world qualification from clean-pushed source
`2922a65f` passed the exact archive/patch application, patched output bindings,
stock and isolated builds, both expected compile refusals, and all fourteen
adapter checks. The retained closure is
[`r24d47_rapier_energy_exchange_accounting_qualification_closure_v1.json`](../../../recovery/r24d47_rapier_energy_exchange_accounting_qualification_closure_v1.json).
It qualifies the patch and supported-route adapter logic without constructing
or stepping a physics world; live physical observation remains a successor
responsibility.
