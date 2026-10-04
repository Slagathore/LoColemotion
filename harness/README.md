# LoColemotion experiment harness

The harness is the other half of LoColemotion. It connects the question asked,
the source allowed to run, the run that actually happened and the claim made
afterward.

I want to be able to come back to a result months later and answer: which code,
which conditions, what failed, and why does this count? The answer should be in
the retained records, not in my memory.

**[Why I built it](../docs/WHY_THE_HARNESS_EXISTS.md)** ·
**[Read the lifecycle](../docs/HARNESS.md)** ·
**[Inspect a negative or refusal](../proof/README.md)** ·
**[Verify the curated bytes](../sdk/publication/evidence.py)**

This directory is the public entry point. The implementation remains at its
existing paths because declarations and qualification records bind those paths
and bytes. It has not been extracted into an independent general-purpose package.

| Part | Implementation and records |
| --- | --- |
| Declarations and frozen questions | [Recovery contracts](../sdk/recovery/) and [turning contracts](../sdk/turning/) |
| Qualification before world construction | [R10DH qualification](../sdk/recovery/r10dh_development_qualification_v2.json), [conformance](../sdk/conformance/) and [tests](../tests/) |
| Authorization, process ownership and retention | [Recovery host](../sdk/recovery/), [discovery infrastructure](../sdk/discovery/) and [process helpers](../sdk/process/) |
| Evaluation and independent closure | [Recovery closure](../sdk/recovery/r10dh_held_out_physical_closure_v2.json), [turning closure](../sdk/turning/r23d78_production_route_three_engine_turning_validation_closure_v1.json), [trace analysis](../sdk/trace_analysis/) |
| Evidence-gated claims and packaging | [Release boundary](../sdk/release/README.md) and [SDK1 compiler](../sdk/compile_quadruped_sdk1_milestone_readiness.ps1) |
| Earlier laboratory infrastructure | [Lab source](../scripts/lab/) and [evidence-first architecture](../docs/adr/ADR-001_EVIDENCE_FIRST_LOCOMOTION_RESEARCH_PIPELINE.md) |

The architecture may be useful outside locomotion. Portability of the harness to
another domain is still engineering work, not an already-qualified claim.
Licensing also follows the source: `sdk/` is covered by the SDK terms; other
parts retain their existing scope. See the [license FAQ](../LICENSE-FAQ.md).
