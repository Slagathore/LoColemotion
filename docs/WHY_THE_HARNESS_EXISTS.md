# The harness is half the project

I built LoColemotion because I wanted to control physically simulated creatures
across Godot/Jolt, Rapier/Parry and MuJoCo. Getting the control through each engine
was one part of the work. Figuring out exactly what the results supported became
another.

The walking is easy to show. The harness is what lets me come back to a result
and explain which code ran, under which conditions, what failed, and why the
result counts.

Both are part of LoColemotion.

## A finished run can still be invalid

In the [original R10DH production attempt](../sdk/recovery/r10dh_production_ghost_closure_v1.json),
the worker completed 1,755 steps. The independent reader then refused the report
with `R10DH_REPORT_IDENTITY`. The kicked cell never opened.

That attempt stays invalid. It does not become a successful recovery experiment
because some motion happened, or because I later fixed the reader.

The corrected route has a [separate v2 record](../sdk/recovery/r10dh_production_ghost_closure_v2.json).
The later [held-out acceptance](../sdk/recovery/r10dh_release_gate_adoption_v2.json)
has its own six cells and its own narrow Godot/Jolt scope. You can follow that
chain without replacing the failed attempt with the better-looking result.

## A valid run can still fail the task

[Recovery Panel C](../sdk/discovery/recovery_panel_c_closure_v1.json) opened four
valid worlds. Two cells were positive and two were negative. There were zero
positive pairs.

The execution worked. The population did not pass. Those are different facts,
and I want the records to keep them different.

## Passing a check has a scope

The applicable qualification happens before a physical campaign is allowed to
open a world. It checks the actual route and binds its source, runtimes and
dependencies. Authorization is a separate step. The outputs then have to survive
retention, evaluation and closure before they can support a claim.

The tested paths refuse missing or mismatched evidence. Changes to source do not
quietly inherit an old qualification. The [package controls](../sdk/release/test_sdk1_package_adoption.py)
include corrupted receipt hashes and an unsupported full-program claim.

That is the part I think other experimental software projects may find useful.
The implementation is still tied to this research workflow. Making it a portable
harness for another project would take more work.

## What is public now

The [browser replay](https://Slagathore.github.io/LoColemotion/) lets you inspect
three retained development sessions without installing an engine. The
[proof index](../proof/README.md) gives you positive results, a valid negative and
an invalid attempt, with their records and byte identities. The roughly 517 GB
research archive stays outside the repository.

SDK1 reached [20/20 bounded milestones](../proof/receipts/sdk1-clean-readiness.json)
at the October 3, 2026 source snapshot. The broader program remains 19/25. The
three engine routes have finite, per-engine evidence; formal cross-engine
equivalence is still outside the claim.

The [SDK and lab license](../LICENSE-FAQ.md) covers the SDK, the listed lab
source, harness entry point, curated proof and replay under the same terms.
Simulation and training folders, general tools and root documentation remain
outside the grant. The root notice lists the exact boundary.

If you work on experiment runners, simulation or reproducibility, I would like
to know which part of this chain you would need to inspect first. The
[harness guide](HARNESS.md) maps the lifecycle to actual source and records.
