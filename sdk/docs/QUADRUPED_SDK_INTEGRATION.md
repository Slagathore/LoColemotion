# Standalone quadruped SDK integration

This guide covers the bounded-quadruped submission surface. It uses only files
inside the SDK package and does not depend on the SporeSpore game tree.

The current selected controller is `BW5R-B`, exposed by the exact policy ID
`sporespore_balanced_wave_bw5r_b_v1`. Always request that policy explicitly.
Do not silently fall back to the legacy balanced-wave policy.

## What this SDK does and does not do

The portable core can:

- compile a descriptor in the published six-axis bounded-quadruped domain;
- validate canonical state, command, memory, and actuation schemas;
- produce one deterministic, ordered actuation frame per semantic step;
- fail to an ordered zero-actuation frame when required observations are
  unavailable or invalid;
- report capability, domain, schema, version, and deprecation information;
- diagnose descriptor acceptance without constructing a world; and
- record, verify, and deterministically replay portable policy calls.

Portable policy replay is not physics replay. A successful replay proves that
the same SDK version, ABI generation, policy, canonical request, and memory
produce the same portable output. It does not prove that Godot/Jolt, Rapier,
MuJoCo, or another engine will reproduce a trajectory, and it does not grant
walking, robustness, cross-engine, or physical-acceptance authority.

## Prerequisites

Use PowerShell 7 in the unpacked SDK root. You need:

- Python 3.11 or later;
- a Rust toolchain able to build the checked-in lockfile; and
- the SDK package itself.

For an offline build, the lockfile dependencies must already exist in the
local Cargo cache.

```powershell
cd C:\path\to\unpacked-sporespore-sdk
cargo build -p sporespore-locomotion-core --release --offline
$env:PYTHONPATH = (Get-Location).Path
```

The Python binding searches `target/release` and `target/debug`. You can pin a
specific build instead:

```powershell
$env:SPORESPORE_LOCOMOTION_LIBRARY = (
    Resolve-Path .\target\release\sporespore_locomotion_core.dll
).Path
```

On Linux use `libsporespore_locomotion_core.so`; on macOS use
`libsporespore_locomotion_core.dylib`.

## Run the complete standalone quickstart

From the SDK root:

```powershell
python .\examples\quadruped_quickstart.py `
    --recording .\quadruped-example.jsonl
```

Expected properties in the one-line JSON receipt:

- `frame_count` is `2`;
- `ordered_actuator_command_count` is `16`;
- `recording_integrity_verified` is `true`;
- `deterministic_policy_replay_exact` is `true`;
- `world_build_count` is `0`;
- `walking_acceptance` is `false`; and
- `physical_acceptance_authority` is `false`.

The example compiles the reference morphology, executes two explicit
`sporespore_balanced_wave_bw5r_b_v1` steps, records the requests and outputs,
verifies the hash chain, and re-executes both calls. It intentionally opens no
physics world.

The important integration pattern is:

```python
from python import (
    LocomotionCore,
    SELECTED_BALANCED_WAVE_POLICY_ID,
    reference_quadruped,
)

core = LocomotionCore()
descriptor = reference_quadruped("my_quadruped")
compiled = core.compile_bounded_quadruped(descriptor)
memory = core.balanced_wave_policy_initial_memory(
    SELECTED_BALANCED_WAVE_POLICY_ID,
    descriptor,
)

# Populate these from your engine adapter in the exact compiled order.
request = {
    "schema_version": "sporespore_balanced_wave_policy_step_request_v1",
    "policy_id": SELECTED_BALANCED_WAVE_POLICY_ID,
    "descriptor": descriptor,
    "memory": memory,
    "state": canonical_state_frame,
    "command": canonical_motion_command,
}
result = core.balanced_wave_policy_step(
    SELECTED_BALANCED_WAVE_POLICY_ID,
    request,
)

# Apply only through the host adapter after validating its capability,
# ordering, timing, and bounds. Feed the returned memory into the next step.
actuation = result["actuation"]
memory = result["next_memory"]
```

See
[`../examples/reference_quadruped.py`](../examples/reference_quadruped.py)
for a complete state and command fixture. It is synthetic API data, not a
physical result.

## Bounded heading commands

`sporespore_motion_command_v2` already carries the selected policy's public
heading surface:

```python
canonical_motion_command["desired_heading_rad"] = target_world_yaw_rad
canonical_motion_command["desired_yaw_rate_rad_s"] = None
```

`desired_heading_rad` is an absolute world yaw in the canonical x-forward,
z-right convention. `None` means hold the state frame's
`task_frame.reference_yaw_rad`. The portable core takes the shortest wrapped
angular difference, limits desired heading error to `0.25 rad`, limits the
steering fraction to `0.40`, filters it through the selected policy's
versioned memory, and differentially scales left/right hip stride. The step
receipt exposes requested, previous, held, applied, saturated, filtered,
cross-track, measured-yaw, and desired-heading values.

Yaw-rate commands are not implemented by the selected policy. Supplying both
heading and yaw rate returns ordered safe-zero actuation with `SCHEMA_INVALID`;
supplying yaw rate alone returns ordered safe-zero actuation with
`CAPABILITY_UNSUPPORTED`. Do not apply either frame as motion.

Run the public source contract with:

```powershell
.\run_heading_command_turning_conformance.ps1 -SkipBuild
```

H0-H8 prove exact omitted-versus-reference-heading compatibility, signed
bilateral output, bounds, angle wrapping, typed safe-zero failures,
stateless/persistent-session equivalence, and finite ordered output at all 64
descriptor-domain vertices. This opens zero worlds. It does not prove that a
body turns, that zero-command walking remains physically equivalent, or that
any engine passes QSDK-R23.

## Host-loop rules

Your adapter owns engine access. The portable core never creates a body,
constraint, contact, motor, scene node, or physics world.

At startup:

1. Publish an adapter capability receipt with exact frames, units, ordering,
   contact semantics, timing, and actuation ownership.
2. Compile the descriptor once.
3. Preserve `ordered_body_ids`, `ordered_joint_ids`,
   `ordered_contact_site_ids`, and `ordered_actuator_ids` exactly.
4. Start with `balanced_wave_policy_initial_memory(policy_id, descriptor)` so
   the memory schema is selected by the exact named policy. The legacy
   no-input initializer is retained only for compatibility with stateless
   balanced-wave policies.
5. Refuse a policy or capability mismatch before applying any motor command.

At each semantic step:

1. Sample all state fields at one declared time.
2. Express positions in metres, velocities in metres/second or
   radians/second, forces in newtons, torques in newton-metres, and gravity in
   metres/second squared.
3. Distinguish contact presence from qualified load-bearing support. Do not
   call raw multi-shape impulses a per-foot load.
4. Include the previously applied host actuation when available; do not claim
   that a requested command was applied.
5. Call the exact named policy once.
6. Validate the ordered actuation frame, its receipt digest, validity window,
   and safe-zero status.
7. Apply commands only through the declared adapter path.
8. Retain the returned `next_memory` for the next semantic step.

If required state is stale, malformed, reordered, or unavailable, do not
invent observations. Preserve the SDK's typed failure and ordered safe-zero
actuation.

## Descriptor diagnostics

Diagnose the reference descriptor:

```powershell
python -m diagnostics --reference
```

Diagnose your own JSON descriptor:

```powershell
python -m diagnostics --descriptor .\my-quadruped.json
```

Exit code `0` means the descriptor compiles. Exit code `2` means it was
rejected and the JSON receipt contains `failure_code`, `failure_detail`, and a
suggestion. Acceptance means only that the portable compiler and selected
policy are defined at that point. Read the embedded domain certificate:
`controller_continuous_over_complete_domain` and
`continuous_full_volume_physical_locomotion_validated` remain separate facts.

## Canonical record/replay

The quickstart produces a UTF-8 JSON Lines file with:

- one `sporespore_canonical_recording_header_v1`;
- one `sporespore_canonical_recording_frame_v1` per policy call; and
- one `sporespore_canonical_recording_footer_v1`.

Transport JSON is sorted, compact, finite, and preserves executable float
spellings. Every request, response, and record has both a semantic SHA-256
produced by the core canonicalization authority and an exact transport
SHA-256. Every record identifies the previous record by its exact transport
digest, so modification, deletion, insertion, reordering, and numeric-spelling
drift fail closed.

Verify integrity without executing the policy:

```powershell
python -m record_replay verify .\quadruped-example.jsonl
```

Verify and re-execute every policy request:

```powershell
python -m record_replay replay .\quadruped-example.jsonl
```

Replay refuses:

- invalid or noncanonical JSONL;
- a modified record or broken hash chain;
- missing or reordered frame indices;
- request or response digest drift;
- an SDK-version or ABI-generation mismatch;
- a policy-ID mismatch;
- a frame that claims a world build or physical authority; or
- any replayed output whose canonical digest differs from the recording.

Recordings may contain detailed morphology, state, command, and controller
data. Treat them as application data: choose retention and access controls
appropriate to your product. The SDK never overwrites an existing recording.

## Versioning and migration

Before consuming a recording or persisted request:

1. compare SDK SemVer and ABI generation;
2. look up its schema in `versioning/schema_registry_v1.json`;
3. use only a registered migration in `versioning/migrations.py`; and
4. retain the migration receipt next to the migrated artifact.

Do not relabel an old schema or bypass a typed migration refusal. Deprecated
surfaces remain callable for the declared window, but new integrations should
use the explicitly named policy and v3 load-transfer/joint-map surfaces.

## Adapter implementation

For another engine, start with:

- `adapter_kit/README.md`;
- `adapter_kit/adapter_contract_v1.json`;
- `adapter_kit/reference_adapter.py`; and
- `run_adapter_authoring_conformance.ps1`.

Adapter-authoring conformance proves the public boundary and safe failure
behavior. It is not engine C6 or physical walking evidence. An engine may be
advertised only after its own characterization, C0-C5 conformance, and the
separately preregistered C6 physical campaign pass.

## Optional learned adaptation

The first public package includes the adaptation interface even when no
learned provider is installed. Start with:

- `adaptation_provider/README.md`;
- `adaptation_provider/provider_contract_v1.json`;
- `adaptation_provider/tier2_architecture_v1.json`; and
- `run_adaptation_provider_conformance.ps1`.

Run the ordinary portable controller first. If a provider is installed, give
it the versioned engine-neutral request and pass its raw response together
with that request to `LocomotionCore.resolve_adaptation_v1` (or
`ss_resolve_adaptation_v1_json`). Apply only the final canonical velocities in
the core's resolution receipt. Do not apply the provider's proposed deltas
directly. An absent or rejected provider produces a bit-exact deterministic
baseline receipt; an invalid host request remains a typed error.

Provider episode feedback may enter the append-only Tier 2 candidate-chapter
pipeline. It cannot rewrite the deployed encyclopedia or model. MuJoCo Warp
training output remains a hypothesis until the successor passes ordinary CPU
MuJoCo, Rapier/Parry, and Godot/Jolt qualification. The current executable
fixture proves the architecture and its negative controls, not a trained
provider or physical result.

## Run developer-experience conformance

Source-tree validation:

```powershell
.\run_developer_experience_conformance.ps1 -SkipBuild
```

This executes the eight positive and negative unit tests plus the quickstart,
record verifier, deterministic replayer, and diagnostics CLI. Its source-tree
receipt deliberately reports `r16_passed=false`.

R16 can pass only against the non-publishable clean-room candidate outside the
game source tree:

```powershell
.\run_developer_experience_conformance.ps1 `
    -PackageRoot C:\path\to\candidate `
    -RequireIsolatedPackage `
    -ForbiddenSourceRoot C:\path\to\SporeSpore `
    -Report C:\durable\evidence\report.json
```

That mode rehashes every package-manifest entry, requires the
`NOT_FOR_DISTRIBUTION.json` interlock, rejects game-tree contents, builds and
loads the package's own core, and runs the same public examples and negative
tests. It still grants no release or publication authority by itself.
