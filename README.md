# LoColemotion

**Portable locomotion across Godot/Jolt, Rapier/Parry and MuJoCo. A fail-closed experiment harness that keeps the results honest.**

I built LoColemotion to control physically simulated creatures across different
physics engines. That also meant building a system for deciding what an
experiment actually proved, keeping the failures, and preventing a bad run from
quietly becoming a good claim.

Both parts are the project.

| Locomotion SDK | Experiment harness |
| --- | --- |
| A Rust core, C ABI and Python bindings; canonical commands and observations; native adapters for three physics engines. | Prospective declarations, source and runtime identity, qualification before physics, separate authorization, retained outcomes and evidence-gated claims. |
| Finite walking, turning and recovery results with explicit per-engine limits. | Positive, negative and invalid results stay distinguishable. A passed check does not automatically authorize the next step. |
| **[Explore locomotion](docs/LOCOMOTION.md)** | **[Explore the harness](harness/README.md)** |

**[Watch the recordings](https://Slagathore.github.io/LoColemotion/)** · **[Inspect the proof](proof/README.md)** · **[Build the core](docs/GETTING_STARTED.md)** · **[License](LICENSE-FAQ.md)**

## Try it without the lab

[Open the browser replay](https://Slagathore.github.io/LoColemotion/). Choose an
engine, play or scrub the recording, and rotate the view. No engine install,
build, account or evidence archive.

For offline playback, clone or download this repository and open
**`replay/index.html`** in a browser. Everything it needs is included.

The replay contains recorded body poses from three retained Explorer development
sessions. It shows what those sessions did. It does not run new physics, replay
the SDK1 acceptance campaigns, or compare engine performance.

For the SDK itself, [start with the portable core](docs/GETTING_STARTED.md).
The [live Studio guide](docs/SHOWCASE.md) spells out the extra runtime requirements.

## What is proven

**SDK1: 20/20 bounded milestones at the 2026-10-03 source snapshot.**
The [original compiler receipt](proof/receipts/sdk1-clean-readiness.json) records
20 passed, zero missing, zero contradicted and zero invalid proofs. The broader
program remains **19/25**. This is milestone completion, not a binary release.

| Result | Boundary |
| --- | --- |
| Native walking in all three engines | Finite per-engine evidence and declared morphology/material envelopes. See the [support guide](docs/LOCOMOTION.md). |
| Commanded turning in all three engines | Nine cells: one exact seed, three engines, three arms. [R23D78](sdk/turning/r23d78_production_route_three_engine_turning_validation_closure_v1.json). |
| Push, fall, recovery and resumed walking in Godot/Jolt | Six held-out cells on exact S169 and the retained V28 runtime. [R10DH adoption](sdk/recovery/r10dh_release_gate_adoption_v2.json). |
| Standalone SDK package validation | Two identical 2,870-file source candidates; 524 Rust tests; 83 native exports invoked. [Package closure](sdk/release/sdk1_package_acceptance_closure_v1.json). |
| Qualification and claim controls | Retained refusal paths, source bindings and corruption controls. [Harness walkthrough](docs/HARNESS.md). |

Running through three engines does **not** establish formal cross-engine
equivalence. SDK1 also does not establish arbitrary creature support, continuous
morphology coverage, general recovery, or terrain/noise/latency robustness.
The [support matrix](sdk/release/quadruped_support_matrix.json) keeps those limits
explicit. Full-program release and native binary redistribution remain separate.

## Evidence without a 517 GB download

The full research archive stays outside GitHub. This repository contains:

- A [curated index](proof/EVIDENCE_INDEX.json) connecting selected claims and
  counterexamples to their source records, hashes and artifact locations.
- Small, original [SDK1 receipts](proof/receipts/) and a derived pose replay.
- The declarations, evaluators, closures and source behind those records.

Run `python sdk/publication/evidence.py verify` from the repository root to
check the indexed local bytes. That verifies the curated files, not every
dependency or experiment in the archive. External artifacts are marked as
unpublished; there are no pretend download links.

## Find your way around

| Path | Start here for |
| --- | --- |
| [docs/](docs/README.md) | Setup, scope, architecture and engine integration |
| [harness/](harness/README.md) | The experimental lifecycle and implementation map |
| [proof/](proof/README.md) | Receipts, positive results, negatives and refusals |
| [replay/](replay/README.md) | Browser playback of retained native observations |
| [sdk/](sdk/README.md) | Core, adapters, bindings, contracts, qualification and release tools |
| `scenes/`, `scripts/`, `data/` | The creature editor and original research lab |

The project was called SporeSpore before October 2026. Internal names and
scientific records keep that name where changing it would break their identity.
[EXPORT_PROVENANCE.json](EXPORT_PROVENANCE.json) describes the initial export;
[publication provenance](proof/PUBLICATION_PROVENANCE.json) records this launch
curation separately. Historical commits and some dependency bytes still require
the original archive. This clone does not claim to reproduce the whole lab.

## License and contributions

The SDK and the covered lab, harness, proof and replay use the custom
**LoColemotion SDK Community License 1.0**, or a separately executed commercial
agreement. Eligible business use is free at or below **US$100,000 gross revenue
over the preceding twelve months**, assessed across the controlled group.
A **90-day non-production business evaluation** is also available under the terms.

This is **source available**. The grant covers `sdk/`, `scripts/lab/`,
`data/lab/`, `tests/`, the top-level lab runners listed in the root notice,
`scenes/tools/`, `harness/`, `proof/` and `replay/` under the same terms.
`scripts/sim/`, `scenes/sim/`, `scripts/tools/`, `docs/`, the editor, the game
and other unlisted material remain reserved unless separately licensed.
Third-party terms still apply. Read the [license FAQ](LICENSE-FAQ.md),
[complete terms](LICENSE), and [commercial options](COMMERCIAL.md).
Before publishing a change, read [repository hygiene](docs/REPOSITORY_HYGIENE.md).

[Contributions and bug reports](CONTRIBUTING.md) are welcome. Evidence corrections
need the record, the mismatch and the proposed scope of the correction.

Created by **Charles Chambers**. [Citation details](CITATION.cff).
