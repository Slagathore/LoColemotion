# Getting started

There are three useful entry points. Pick the one that matches what you want to do.

| Path | Needs | First result |
| --- | --- | --- |
| [Browser replay](../replay/README.md) | A browser and this checkout | Recorded poses from three native engine sessions |
| Portable core, below | Python 3.11+, Rust and its native build tools | Two policy calls, a recording and exact policy replay |
| [Live Studio](SHOWCASE.md) | Windows, configured native workers and exact runtime dependencies | Fresh development physics |

## Build the core

Use **PowerShell 7**. Start in the cloned LoColemotion repository. The first build
needs access to the dependencies in `sdk/Cargo.lock`; later builds can use a
populated local Cargo cache. Windows builds use the MSVC Rust toolchain and its
C++ linker. The retained package qualification used Windows x86_64 and Python 3.11.

```powershell
Set-Location .\sdk
cargo build --locked -p sporespore-locomotion-core --release
$env:PYTHONPATH = (Get-Location).Path
New-Item -ItemType Directory -Force .\local-output | Out-Null
python .\examples\quadruped_quickstart.py --recording .\local-output\quadruped-example.jsonl
```

Use your Python 3.11+ executable in place of `python` if your machine has several
versions. The final command prints a JSON receipt. Look for:

```json
{
  "frame_count": 2,
  "ordered_actuator_command_count": 16,
  "recording_integrity_verified": true,
  "deterministic_policy_replay_exact": true,
  "world_build_count": 0,
  "walking_acceptance": false,
  "physical_acceptance_authority": false
}
```

This runs real SDK calls and verifies their recording. The state inputs are
synthetic; no physics world opens. Deterministic **policy** replay means the same
inputs produce the same policy outputs. It does not mean a native engine repeats
a trajectory. The [integration guide](../sdk/docs/QUADRUPED_SDK_INTEGRATION.md)
continues from here.

## If it does not start

| Symptom | Check |
| --- | --- |
| `cargo` or the linker is missing | Install the native prerequisites for your Rust toolchain; then rerun the build from `sdk/`. |
| Python cannot import `python` or find the core library | Keep `PYTHONPATH` set to the absolute `sdk/` path in the same shell. Confirm the release build finished. The integration guide shows how to pin the library path. |
| Cargo cannot resolve a locked dependency | Keep `Cargo.lock` intact. Check connectivity or the local cache before trying an offline build. |
| A research command refuses repository identity, source or evidence | It is an archive-bound research command. See [the harness guide](HARNESS.md); do not remove its guard to make it run. |
| A viewer needs a native DLL or an evidence directory | You opened a native Explorer/Studio route. `replay/index.html` is the bundled browser route. |

The creature editor remains available through the root `project.godot`.
Its source is separate from the SDK licensing scope. The public onboarding path
does not require opening the editor or running the full research test suite.
