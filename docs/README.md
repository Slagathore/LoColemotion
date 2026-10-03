# Documentation

Start with the part you came for. The locomotion SDK and the experiment harness
have separate guides, and they meet at the same retained evidence.

| I want to… | Read |
| --- | --- |
| See native motion without installing engines | [Browser replay](../replay/README.md) |
| Build the portable core and run its first example | [Getting started](GETTING_STARTED.md) |
| Understand what each engine has actually shown | [Locomotion and support](LOCOMOTION.md) |
| Understand qualification, authorization and retained failures | [The harness](HARNESS.md) |
| Inspect the 20/20 result or a counterexample | [Proof index](../proof/README.md) |
| Use the desktop Studio or work toward a live setup | [Replay, Explorer and Studio](SHOWCASE.md) |
| Understand the license or discuss commercial use | [License FAQ](../LICENSE-FAQ.md) / [Commercial terms](../COMMERCIAL.md) |
| Contribute a fix or report an evidence problem | [Contributing](../CONTRIBUTING.md) |

## Technical references

- [Standalone SDK integration](../sdk/docs/QUADRUPED_SDK_INTEGRATION.md):
  descriptors, policy calls, capability/refusal semantics and record/replay.
- [Three-engine integration comparison](../sdk/docs/ENGINE_INTEGRATION_COMPARISON.md):
  actuator mapping, joint frames, solver timing and observation time.
- [Adapter authoring kit](../sdk/adapter_kit/README.md).
- [Portable API contracts](../sdk/portable_api/README.md).
- [Architecture](LOCOMOTION_ARCHITECTURE.md) and
  [research evidence contract](LOCOMOTION_GROUND_UP_RESEARCH_PROGRAM.md).
- [Release boundary](../sdk/release/README.md) and
  [machine-readable support matrix](../sdk/release/quadruped_support_matrix.json).

## Research history

The [master ledger](ENGINE_NEUTRAL_LOCOMOTION_SDK_BOOTSTRAP.md) contains the
SDK1 completion boundary and earlier checkpoints. The
[original documentation history](RESEARCH_HISTORY.md) preserves the previous
documentation map in full. Entries saying “current,” “active” or “next” refer to
their own date. Read the completion boundary before treating one as present status.

Some historical commands expect the private research repository, its commit
history, retained artifacts and exact instrumented runtimes. Start with the public
guides above; changing a repository-identity guard is not an installation step.
