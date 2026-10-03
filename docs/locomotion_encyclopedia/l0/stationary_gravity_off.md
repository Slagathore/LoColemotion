# L0.0 — stationary isolated body with gravity disabled

**Knowledge status:** accepted; entry
`L0.stationary_gravity_off.no_invented_motion.v1` admitted 2026-07-21 from
certified bundle
`20260721T002330Z_L0_0_STATIONARY_GRAVITY_OFF_seed-42_pid-92840_5a7b3b2bd6a507b5643dafd53f9c57d3`

**Experiment ID:** `L0_0_STATIONARY_GRAVITY_OFF`

**Hypothesis ID:** `H_L0_0_NO_INVENTED_MOTION`

**What this page is:** the human protocol and interpretation card for the
first atomic calibration experiment.

**What this page is not:** evidence that a creature can stand, brace, recover,
or walk. There is currently no such evidence.

## Question

When a single rigid body has no gravity, no initial velocity, no contact, and
no applied operation, does the live Jolt simulation or its observer invent
translation, velocity, kinetic energy, contact, or external work?

This is deliberately smaller than a foot, limb, or creature. If this baseline
cannot be explained exactly, later actuation and support measurements cannot
be trusted.

## Sealed setup

The authored source is
`data/lab/experiments/L0_0_stationary_gravity_off_v1.tres`.
The compiler expands it before the simulation starts, and the run seals
authored, resolved, applied, and observed configuration separately.

| Quantity | Authored value |
|---|---:|
| Body count | 1 |
| Mass | 2 kg |
| Initial position | (0.25, 1.75, -0.5) m |
| Initial velocity | (0, 0, 0) m/s |
| Gravity scale | 0 |
| Linear damping | 0 s⁻¹ |
| Angular damping | 0 s⁻¹ |
| Physics rate | 60 Hz |
| Measured intervals | 60 |
| Observer | `full_contacts_v1` |
| Contact cap | 32 per body |
| Controller | `none` |

The fixture is not allowed to resolve an unknown field from a hidden default.
An unrecognized parameter, configuration mismatch, missing observer channel,
or unavailable contact capacity makes the run invalid or inconclusive.

## Analytic expectation

For mass \(m\), position \(\mathbf{x}\), velocity \(\mathbf{v}\), external
force \(\mathbf{F}_{ext}\), and integration interval \(\Delta t\):

\[
\mathbf{a} = \frac{\mathbf{F}_{ext}}{m}
\]

\[
\mathbf{v}_{n+1} = \mathbf{v}_n + \mathbf{a}_n \Delta t
\]

\[
\mathbf{x}_{n+1} = \mathbf{x}_n + \mathbf{v}_{n+1}\Delta t
\]

The L0.0 evidence streams must establish all of the following:

\[
\mathbf{g}=\mathbf{0},\quad
\mathbf{v}_0=\mathbf{0},\quad
N_{contacts}=0,\quad
N_{applications}=0,\quad
N_{interventions}=0
\]

and every transition command must be a hash-valid `NONE` command with no joint
or intervention operations. Only then may the external-work metric be
available as:

\[
W_{ext}=0\ \mathrm{J}
\]

The runtime note is not trusted as the proof. The independent bundle
validator reconstructs that proof from `frames.jsonl`, `commands.jsonl`,
`applications.jsonl`, and `interventions.jsonl`, then checks that the note and
summary agree.

Under those conditions:

\[
\mathbf{v}_n=\mathbf{0},\quad
\mathbf{x}_n=\mathbf{x}_0,\quad
K_n=\frac{1}{2}m\lVert\mathbf{v}_n\rVert^2=0
\]

for every recorded frame.

## Preregistered gates

| Recomputed metric | Gate |
|---|---:|
| Maximum position residual | ≤ 1×10⁻⁷ m |
| Maximum velocity residual | ≤ 1×10⁻⁷ m/s |
| Maximum kinetic energy | Recorded, but not a promotion gate in v1 |
| Total contact count | 0 |
| External work | 0 J, available only from sealed absence |

All five summary metrics must have the exact versioned stream, field,
frame-range, aggregation ID, unit, availability, and target provenance.
Changing a summary value and rebuilding `checksums.json` must still fail
independent semantic validation.

## What X changes in Y

These are dependencies, not conclusions from a one-point experiment:

| If X changes | Y that may change | Why | What must test it |
|---|---|---|---|
| Gravity scale becomes nonzero | Velocity and position | Gravity supplies acceleration | L0.1 paired timestep sweep |
| Initial velocity becomes nonzero | Position and momentum | The body carries initial linear momentum | L0.2 ballistic control |
| Linear damping becomes nonzero | Velocity and kinetic energy | Damping removes momentum and energy | Separate damping sweep |
| A contact appears | Momentum and energy | The ground may apply an impulse | Contact calibration ladder |
| A command or intervention appears | External work availability | Applied operations break the zero-work proof | Command/application audit |
| Observer profile changes | Recorded fields or perturbation | Contact monitoring can alter observation cost or behavior | L0.3 observer A/B |
| Timestep changes | Discrete residuals | Integration error and callback cadence change | L0.1 timestep sweep |

## What hinges on this result

L0.0 is a prerequisite for trusting later “force happened” claims:

```text
L0.0 zero-input baseline
  -> L0.1 gravity and timestep calibration
  -> L0.2 nonzero-momentum ballistic calibration
  -> L0.3 observer non-perturbation
  -> BR2 articulated state and inertia
  -> BR3 command -> motor -> link -> contact force transmission
  -> bracing, fall arrest, recovery, and locomotion experiments
```

A pass says only that the smallest zero-input baseline is coherent. A failure
stops the ladder and stays small enough to locate in fixture application,
engine integration, observation, transition accounting, or evidence sealing.

## Required bundle evidence

A current L0.0 run must contain, checksum, and cross-link at least:

- manifest, frozen launch/process provenance, and configuration evidence;
- pre-event history and direct-state frames;
- command, application, decision, intervention, mechanics, event, and runtime
  note streams;
- a provenance-bearing summary; and
- checksums computed only after the child process has exited.

For canonical runs, a parent reserves the run and launches a fresh child. The
child may prepare a candidate but cannot checksum or rename it. Only the
reserving parent can publish it after observing the child’s actual exit.

## Current boundary

On 2026-07-21 the formal BR1 certification campaign passed on the clean
committed tree (commit `2f74821`, session `br1_20260721T002052Z_40077d42`):
the pinned 45-test inventory, this experiment's cell run twice in fresh
processes at 60 Hz with seed 42, production HMAC publication receipts,
independent validation, zero-physics replay of all 61 frames, and same-seed
replicate comparison all passed, alongside the L0.1, L0.2, and L0.3 cells.

The machine entry `L0.stationary_gravity_off.no_invented_motion.v1` was then
admitted as **accepted** from the replicate-1 bundle. The admission path
revalidated the bundle and required the accepted status because the evidence
was promotion grade. The claim stays exactly this narrow: the zero-input
isolated body invented no translation, velocity, kinetic energy, contact, or
external work within the preregistered gates. There is intentionally no
automatic creature-repair rule attached to this calibration experiment, and
this page is still not evidence of standing, bracing, recovery, or walking.
