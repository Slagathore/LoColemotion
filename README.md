# LoColemotion

LoColemotion is an engine neutral locomotion SDK for physically simulated
creatures, together with the Godot 4.7 creature editor and research lab it grew
out of. One portable controller drives the same quadruped in three physics
engines: Godot with Jolt, MuJoCo and Rapier. Every behavior claim here is tied
to retained, hash pinned evidence, and every claim states what it does not cover.

The project was named SporeSpore until October 2026. Many internal identifiers,
schema names and file names still use the old name, because the evidence records
pin their exact bytes. See [Evidence and hash pins](#evidence-and-hash-pins).

## Where it stands (2026-10-03)

- **SDK1 is complete: 20 of 20 bounded milestones.** The full program stands at
  19 of 25 gates. Two identical source packages passed isolated build, API and
  quickstart validation, and all 83 native exports are declared and exercised.
  Those packages are validation candidates, not public binary releases.
- **One creature, three engines.** The same generated quadruped (S169) walks
  under the portable controller in Godot with Jolt, MuJoCo and Rapier, and takes
  pushes to its torso while walking.
- **Turning** passed a finite decision in all three engines on one exact seed.
- **Getting up.** In Godot with Jolt, the creature is kicked, falls, gets back up
  and walks again; all six held out cells passed (three kicked runs and their
  matched controls). MuJoCo and Rapier each completed one development run from
  lying flat to standing.
- **Live Studio.** A desktop app runs fresh native physics in all three engines,
  and you can kick the creature live in Godot and MuJoCo. Godot walking runs near
  real time after startup; its fast path does not yet run the get up controller
  after a fall.

These are finite results for specific bodies, seeds and conditions. They are not
claims about arbitrary creatures, robustness across populations, or equivalence
between engines.

## What is in here

| Path | Contents |
| --- | --- |
| `sdk/` | The SDK: Rust core with a C ABI, Python binding, Godot, MuJoCo and Rapier adapters, conformance suites, the Studio and release tooling |
| `scenes/`, `scripts/` | The Godot creature editor, simulation code and the evidence lab |
| `tests/` | GDScript, Python and PowerShell tests and campaign audits |
| `data/` | Lab experiment specs, knowledge entries and creature cards |
| `docs/` | Architecture, research ledgers and decision records |
| `legacy/` | Retired spline model code kept for reference |

## Getting started

### Creature editor

1. Open this folder in Godot 4.7.
2. Press F5. The editor bench (`scenes/editor/bench.tscn`) opens as the main scene.
3. Pick a bundled card, click a part, edit it in the inspector, and use Save to
   write a card under `data/creatures/`.

### SDK quickstart

From `sdk/` in PowerShell 7, with Python 3.11 or later and a Rust toolchain:

```powershell
cargo build -p sporespore-locomotion-core --release
$env:PYTHONPATH = (Get-Location).Path
python .\examples\quadruped_quickstart.py --recording .\quadruped-example.jsonl
```

The one line JSON receipt reports `recording_integrity_verified` and
`deterministic_policy_replay_exact` as `true`. The full guide is
[sdk/docs/QUADRUPED_SDK_INTEGRATION.md](sdk/docs/QUADRUPED_SDK_INTEGRATION.md).

### Tests

```powershell
$godot = "<path to Godot_v4.7-stable_mono_win64_console.exe>"
.\scripts\run_all_tests.ps1 -Godot $godot
```

Some research tooling only runs inside the private research archive. It checks
the repository identity, the patched engine builds and the evidence folder, and
refuses to run anywhere else by design. The SDK, the editor and the standalone
tests need none of that.

## Evidence and hash pins

Research records here certify exact bytes. A closure pins the SHA-256 of every
source file, configuration and result it depends on, and many records also name
the commit they ran from. About 90 percent of the files in this repository are
pinned by another file.

This repository is a fresh export of the private research archive at commit
`5abf4b69`. Every pinned file is byte identical to that commit, so every pin
between files in this repository still verifies. Two things only resolve
against the private archive:

- **Commit ids.** Records cite commits from the archive's history, which is not
  published here.
- **Raw evidence.** Physics traces, packages and run folders live in a separate
  evidence archive, roughly 489 GB, which is not published.

[EXPORT_PROVENANCE.json](EXPORT_PROVENANCE.json) lists every file that differs
from the archive commit, every file added, and the pinned files left out, with
their digests.

## License

The SDK source in `sdk/` is offered under the **LoColemotion SDK Community
License 1.0**, or under a separately signed commercial agreement. The Community
License covers personal learning and hobbies, evaluation, monetized tutorials,
and business use at or below US$100,000 annual gross revenue across the whole
business group. Larger businesses need commercial terms. It is a custom source
available license, not an OSI open source license. See [LICENSE](LICENSE) and
[licenses/](licenses/README.md).

Everything outside `sdk/`, including the editor, game, lab and documentation, is
all rights reserved.

Third party code keeps its own terms. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Key docs

- [docs/README.md](docs/README.md): documentation map and current checkpoint.
- [docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md](docs/ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md): master roadmap and claim ledger.
- [sdk/README.md](sdk/README.md): SDK overview and checkpoints.
- [sdk/docs/ENGINE_INTEGRATION_COMPARISON.md](sdk/docs/ENGINE_INTEGRATION_COMPARISON.md): how the three engines map the same commands.
- [sdk/explorer/README.md](sdk/explorer/README.md): the Studio and its retained interaction records.
- [docs/LOCOMOTION_ARCHITECTURE.md](docs/LOCOMOTION_ARCHITECTURE.md): locomotion architecture.
- [docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md](docs/LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md): the evidence contract.
- [docs/adr/ADR-001_EVIDENCE_FIRST_LOCOMOTION_RESEARCH_PIPELINE.md](docs/adr/ADR-001_EVIDENCE_FIRST_LOCOMOTION_RESEARCH_PIPELINE.md): why evidence comes first.
- [docs/DESIGN.md](docs/DESIGN.md): creature editor architecture and roadmap.
