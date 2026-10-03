# ADR-015: Engine-neutral core language and boundary

- **Status:** accepted for Locomotion Semantics v1 extraction
- **Date:** 2026-07-28
- **Decision scope:** portable deterministic locomotion core, not host physics

## Context

GQ15 completed the current generated-quadruped program at `36/36` physical
worlds and `900/900` assertions. The next work must extract reusable semantics
without silently turning Godot/Jolt laboratory code into an allegedly neutral
SDK.

The live development machine provides:

```text
rustc 1.97.0
cargo 1.97.0
Python 3.11.9
CMake 3.31.7
no clang executable on PATH
```

The repository has no existing portable core and no second physics package
installed. Current authority remains the GDScript GQ15 implementation and its
source-pinned evidence.

## Decision

Implement the engine-neutral deterministic core in stable Rust and expose a
versioned C ABI.

The core:

- uses no Godot, Jolt, MuJoCo, Bullet, Unity, Unreal, or host-object types;
- accepts and emits explicit SI-unit, right-handed canonical records;
- rejects unknown fields and nonfinite values;
- uses stable semantic IDs and spec-defined ordering;
- produces canonical JSON and SHA-256 evidence digests;
- has no scene discovery, contact callback, wall-clock, or actuator side
  effects;
- supports variable body, joint, limb, contact, and actuator token counts; and
- keeps physical execution in separately certified adapters.

The checked-in C header is the outward authority. Rust and Python APIs are
convenience bindings and must not define different semantics.

## Why Rust

Advantages:

- memory-safe ownership for immutable compiled morphologies and controller
  handles;
- strong enums and exact schema validation;
- deterministic, engine-free unit tests;
- straightforward `staticlib`, `cdylib`, and WebAssembly targets;
- a small C ABI can hide Rust implementation details; and
- the required toolchain is already installed and testable offline.

Costs:

- Godot requires an explicit native adapter rather than importing Rust types
  directly;
- ABI data must use C-compatible buffers/handles rather than Rust layouts;
- floating-point and panic behavior must be deliberately constrained; and
- future console targets may impose separate toolchain approval.

## Rejected alternatives

### GDScript-only core

Fastest extraction, but still binds the semantics to Godot containers, numeric
types, loading, and lifecycle. It is an oracle and first adapter, not the
portable core.

### C++ core

Viable for game-engine integration, but there is no verified compiler on the
current machine. It also increases ownership/ABI footguns without adding a
capability the C boundary cannot provide.

### Python core

Useful for analysis and bindings, but unsuitable as the authoritative
real-time portable core because interpreter, allocation, packaging, and
embedding behavior would become part of the runtime contract.

### New repository

Rejected until extraction and conformance stabilize. Keeping core, oracle,
adapters, golden vectors, and evidence together makes semantic drift visible.

## Compatibility and evidence consequences

- GDScript remains the independent golden-vector oracle until Rust parity is
  complete.
- A Rust unit-test pass establishes pure-core behavior only.
- A Godot/Jolt adapter pass establishes only that adapter and its declared
  conformance layer.
- A second Godot backend is useful evidence but is not the only permitted
  engine-neutrality proof.
- The SDK is not complete until one materially different physics host passes
  the frozen C0-C6 ladder using the same core build.
- No adapter may patch controller policy or reinterpret failed core validation.

## First implementation slice

The first slice contains:

1. strict engine-free schemas;
2. canonical JSON and digest rules;
3. generic topology compilation;
4. the bounded six-axis quadruped descriptor and Candidate 35 formulas;
5. a variable-limb semantic gait scheduler;
6. coverage/OOD and continuous-domain compiler certificates;
7. state, command, actuation, and controller receipts;
8. C header and buffer-based C ABI;
9. golden vectors against the GDScript oracle; and
10. offline Rust and Python conformance tests.

Physical adapters and physical robustness campaigns remain later, separately
gated work.
