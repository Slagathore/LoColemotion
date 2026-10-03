# ADR-001: Evidence-first locomotion research pipeline

**Status:** Accepted

**Date:** 2026-07-19

**Deciders:** Cole and the LoColemotion maintainers

## Context

LoColemotion has tests and prototypes historically described as walking, but none
of them are accepted evidence that a creature can walk. In particular, a
creature that begins to fall has repeatedly failed to straighten a limb,
transmit force into the ground, and arrest the fall. Tuning a gait on top of
that failure mixes several unknowns:

- whether the command reached the joint;
- whether the motor had sufficient force, speed, and range;
- whether the limb transmitted that force through its links;
- whether a contact existed and supplied the expected reaction impulse;
- whether the support geometry could resist the center-of-mass motion;
- whether the observer measured the event without perturbing it;
- whether a controller or gameplay assist injected unreported work.

The project also needs locomotion guidance for arbitrary player-authored
morphologies. A quadruped-specific gait implementation cannot become the
general repair and authoring system needed for a creature sandbox experience.

## Decision

Build locomotion knowledge from atomic, falsifiable experiments and admit it
through an immutable evidence pipeline:

```text
authored experiment
        |
        v
validate + expand + seal configuration
        |
        v
parent reserves unique run and launches one child process
        |
        v
child adopts once, applies configuration, and records direct physics state
        |
        v
child closes a candidate bundle (it cannot publish it)
        |
        v
parent observes child termination, validates, checksums, and atomically publishes
        |
        v
independent validation + trace-only replay
        |
        v
development observation or accepted knowledge entry
```

The following are architectural invariants:

1. **Zero baseline.** Historical walking results are not evidence. New claims
   begin at L0 calibration.
2. **One uncertainty at a time.** Each experiment isolates the smallest useful
   mechanism before combining mechanisms.
3. **No silent defaults.** Authored, resolved, applied, and observed
   configuration are separate values. A mismatch makes the result
   inconclusive.
4. **No invented measurements.** Unsupported channels are marked unavailable
   with a reason; they are never written as numeric zero.
5. **Direct-state evidence.** Physics state is captured at a named engine
   boundary with coherent step, epoch, frame, and callback identities.
6. **Complete causal trail.** Commands, decisions, interventions,
   applications, mechanics, events, runtime notes, frames, and pre-event
   history are distinct append-only streams.
7. **Parent-owned publication.** A simulation child may prepare evidence but
   cannot declare or publish its own completed run.
8. **Fresh-process reproducibility.** Promotion requires process-isolated
   reruns, stable seeds, sealed source identity, and matching evidence.
9. **Claim-sized promotion.** Passing stationary-body calibration is evidence
   only for stationary-body calibration. It is not standing, bracing,
   recovery, or walking.
10. **Evidence-backed guidance.** Automatic creature repairs may use accepted
    knowledge only. Dirty-source development observations remain inspectable
    but cannot edit a creature automatically.

## Options considered

### Option A: Continue tuning whole walkers

| Dimension | Assessment |
|---|---|
| Initial implementation effort | Low |
| Diagnostic power | Very low |
| Morphology generality | Low |
| Risk of false success | Very high |
| Long-term reuse | Low |

**Pros**

- Produces visually interesting behavior quickly.
- Reuses existing gait and training code.

**Cons**

- Contact, actuation, balance, timing, morphology, and controller defects are
  entangled.
- Optimizers can exploit assists or measurement defects.
- A failed run does not identify the broken link.
- A visually plausible run cannot explain why it worked.

### Option B: Instrument full gameplay creatures first

| Dimension | Assessment |
|---|---|
| Initial implementation effort | Medium |
| Diagnostic power | Medium-low |
| Morphology generality | Medium |
| Risk of false success | High |
| Long-term reuse | Medium |

**Pros**

- Observes failures in their eventual gameplay environment.
- Makes existing creature behaviors easier to inspect.

**Cons**

- Gameplay assists, terrain, animation, and controllers remain confounders.
- High-volume telemetry does not create causal knowledge by itself.
- Instrumentation can perturb simulation without a calibrated observer A/B
  experiment.

### Option C: Isolated experiment ladder with gated evidence admission

| Dimension | Assessment |
|---|---|
| Initial implementation effort | High |
| Diagnostic power | Very high |
| Morphology generality | High |
| Risk of false success | Lowest |
| Long-term reuse | Very high |

**Pros**

- Failures stay small enough to explain and repair.
- Every combined experiment depends on already measured primitives.
- The same mechanics vocabulary can describe bipeds, quadrupeds, pogo feet,
  distributed micro-toes, passive tentacles, cups, and stranger bodies.
- Failed experiments become reusable boundary knowledge.

**Cons**

- Delays any honest walking claim.
- Requires strict schema, lifecycle, provenance, and replay infrastructure
  before controller work.
- Produces intentionally narrow early results that may look less exciting than
  a whole-creature demo.

## Trade-off analysis

Option C costs more before it produces a locomotion demo, but it is the only
option that directly serves both goals: diagnosing why a limb cannot brace and
building morphology-neutral authoring knowledge. Options A and B can still be
used later as integration and gameplay layers; they simply cannot certify
their own mechanics.

The key trade is short-term spectacle versus durable causal leverage. The
project accepts the extra up-front evidence work so future tuning changes can
be small, attributable, and identity-preserving.

## Current implementation boundary

BR1/L0 now implements the experiment contracts, direct-state recorder,
configuration attestation, parent-reserved child lifecycle, parent-only
finalization, checksum validation, trace-only replay, and gated knowledge
admission described by this decision. The parent-owned lifecycle has targeted
fresh-process and adversarial proof coverage, so action item 5 is complete.
L0.3 additionally preserves and validates all three observer-arm
configurations, rejects missing or attacker-selected comparison metrics,
requires collision-free/no-control ledgers and coherent callback timelines,
and rebuilds its physical gate, hypothesis, promotion, event, and runtime-note
mirrors from sealed streams.

Progress is tracked with gate denominators. On 2026-07-21 the formal BR1
certification campaign passed with all 7 of 7 clean canonical cells certified
(session `br1_20260721T002052Z_40077d42`, commit `2f74821`): the pinned
45-test suite, 14 fresh-process bundles with production HMAC receipts, 14
zero-physics replays, 7 same-seed replicate comparisons, a complete final
readback sweep, and a detached attested certification report ending in
`BR1 certification=pass`. BR0 and BR1 are now 2 of 18 named BR milestones
gate-complete (11.1%). Every named locomotion capability remains at 0% proven
until its own later gate passes.

That completion is an infrastructure claim, not a locomotion claim. The
knowledge catalog now holds exactly one accepted entry,
`L0.stationary_gravity_off.no_invented_motion.v1`, admitted on 2026-07-21
from a certified promotion-grade bundle. Its claim is only that the
zero-input isolated body stays within the preregistered stationary gates.
There are still **zero claims of any status** for standing, bracing, fall
arrest, getting up/recovery, or walking. Historical walker and gait tests are
regression tests only. They cannot be cited as experimental evidence,
regardless of what their names, assertions, or visuals imply.

There is no external Godot execution quota. On 2026-07-19 the exact local
Godot 4.7 console executable completed the bounded dirty-tree operator
checkpoint: 39/39 scripts and 632/632 assertions passed; canonical L0.0
produced valid, physically supported, configuration-matched evidence; and
L0.4 replay reproduced 61 frames and one event with zero physics steps.
Source-state promotion failed solely because the tree was dirty, exactly as
required, and no encyclopedia entry was admitted.

Formal BR1 closed on 2026-07-21 through `scripts/run_br1_certification.ps1`,
which pins the exact test inventory and engine binaries by hash, requires a
clean committed tree at every recorded source gate, publishes and replays the
complete clean L0.0-L0.3 matrix twice per cell in fresh processes, compares
same-seed replicates, and ends with a detached production-key attested
report. Diagnostic or dirty runs cannot produce its `BR1 certification=pass`
marker.

Status is deliberately separated at three layers:

| Layer | Question | What a pass permits |
|---|---|---|
| Evidence validity | Are the configuration, streams, provenance, lifecycle, schemas, checksums, and independently recomputed metrics internally consistent? | The bundle may be interpreted. |
| Physical gate | Did this experiment's exact, narrow hypothesis pass? | Only that named L0 claim may be reported. |
| Promotion gate | Was the run produced from clean, reproducible, fresh-process evidence under the required matrix? | The claim may be considered for accepted knowledge. |

Failure or success at one layer does not silently answer either of the others.
In particular, a dirty-tree bundle can be structurally valid and physically
supported while remaining non-promotable. An `accepted` knowledge entry
requires clean promotion evidence; a development observation can never drive
automatic creature repair.

The current evidence threat model trusts the parent process and the local
post-publication filesystem. Artifact SHA-256 values are unkeyed checksums,
not signatures. They catch corruption and partial/resealed conclusion
forgeries; they cannot distinguish an honest bundle from a hostile writer who
replaces every raw stream and every checksum. Hostile-writer tamper evidence
requires a detached parent signature, separately stored signed receipt, or
authenticated append-only evidence service and remains an explicit follow-up.

## Consequences

What becomes easier:

- locating the first broken link between intent and ground reaction;
- proving whether a parameter reached the live physics body;
- comparing observer profiles without trusting a summary alone;
- replaying and auditing a run without executing physics;
- giving a player a minimal repair with an evidence trail;
- extending movement authoring to unusual morphologies.

What becomes harder:

- claiming progress from a visually plausible animation;
- changing a schema or failure code after evidence has been archived;
- treating dirty-source or same-process runs as accepted knowledge;
- adding a new controller without defining its commands, receipts, forbidden
  interventions, and observer requirements.

What must be revisited:

- BR2 certifies articulated inertia and angular-momentum accounting.
- BR3 certifies joint actuation and limb force transmission.
- Contact, support, bracing, fall arrest, get-up, and locomotion claims remain
  blocked until their corresponding gates pass.
- Knowledge promotion policy may become stricter as replicated morphology and
  disturbance matrices are implemented; it must never become silently looser.

## Action items

1. [x] Define strict run, frame, command, mechanics, event, summary, and
   checksum contracts.
2. [x] Implement isolated L0 rigid-body fixtures and direct-state observation.
3. [x] Separate resolved, applied, and observed configuration.
4. [x] Add append-only knowledge admission with development and accepted
   statuses.
5. [x] Complete and prove parent-owned fresh-process publication.
6. [x] Execute and independently replay the complete dirty-tree L0.0 operator
   checkpoint.
7. [x] Publish and replay the complete clean canonical L0.0-L0.3
   certification matrix.
8. [x] Admit the first knowledge entry with the status dictated by the
   bundle's promotion result.
9. [x] Begin BR2 only after the BR1 evidence gate is closed. BR2 started
   after the 2026-07-21 certification and its coordinate-frame oracle gate
   closed the same day: local-frame-only joint bindings, per-sample world
   axis/anchor recomputation with fail-closed validity, whole-body angular
   momentum with strict availability, and six pinned tests certified
   inside the re-run 51-test suite. Sealed-stream frame_v2 integration is
   deferred to the first jointed experiment family (BR3A/BR4).
10. [x] Add external/keyed publication attestation. Bundle publication and the
   certification report now require detached HMAC receipts from a trust store
   held outside the evidence directory. This detects post-publication
   replacement by a writer without trust-store access; it is still one
   locally held key, not a third-party-verifiable signature.

The operator and admission procedures are documented in the
[locomotion encyclopedia](../locomotion_encyclopedia/README.md). Action items
7 and 8 stay open until clean matrix bundles are published, independently
validated, replayed, and actually admitted where applicable; implementation
of the writers alone does not satisfy those items.
