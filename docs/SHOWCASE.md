# Replay, Explorer and live Studio

## Browser replay: available in this checkout

Open `replay/index.html` in a browser. The included data covers all published
pose frames from three retained Explorer sessions: Godot/Jolt, MuJoCo and
Rapier/Parry. There are no remote scripts, downloads or engine dependencies.

Play, pause, scrub, change speed, jump to the recorded impulse and rotate the
camera. The time display uses recorded simulation time. Playback speed says
nothing about how quickly the original engine ran.

The bundle keeps poses, ground-contact flags and impulse events. It omits the
full solver and controller telemetry. Its [manifest](../replay/manifest.json)
binds the original streams and derived files to the existing Explorer closure.
It is a viewing copy, not an acceptance trace or a new physical result.

## Native Explorer and Studio: runtime setup required

The [existing Explorer guide](../sdk/explorer/README.md) documents the original
desktop application and the later Studio successor. Their retained isolated
installation checks are real, but the configured installation on the author's
machine is not a portable download supplied by this repository.

| Component | Requirement / current boundary |
| --- | --- |
| Desktop host | Windows and explicit local runtime configuration |
| UI | Godot 4.7 executable, separate from the instrumented physics worker |
| Core | A native core library matching the configured source |
| MuJoCo | Adapter environment pinned to `mujoco==3.11.0` and `numpy==2.4.6` |
| Rapier/Parry | Native worker built for its declared dependency and telemetry profile |
| Godot/Jolt recovery | Exact instrumented engine pair and retained V28 adapter library; a stock engine or different DLL is not interchangeable |
| Evidence/provenance panels | Their referenced retained artifacts or a future explicitly packaged subset |

See [dependencies.example.json](../sdk/explorer/dependencies.example.json) for
the configuration fields and [the engine comparison](../sdk/docs/ENGINE_INTEGRATION_COMPARISON.md)
for the reason those details matter.

With an already prepared runtime, the original Explorer entry point is:

```powershell
# PowerShell 7, from the repository root. Use your real absolute paths.
& ./sdk/explorer/open_showcase.ps1 `
    -Config 'C:/your/runtime-dependencies.json' `
    -Output 'C:/your/durable-evidence/explorer-fresh-session'
```

The output directory must be new. The configuration must identify the source
that actually built the workers. Do not substitute the public snapshot commit
for a historical worker's identity.

This is an expert route, not a claim that a fresh clone can recreate the installed
Studio today. Public runtime packaging and a relocatable curated evidence subset
still need work. The browser replay is the complete no-engine viewing path.

## Keep the two native scopes separate

The original M20 Explorer closure is fixed. Later Studio sessions add development
features, including edited MuJoCo bodies and a faster Godot walking path. Those
sessions do not broaden physical acceptance. Godot/Rapier live routes remain
exact-S169; fast Godot does not yet re-enter the full recovery controller after
a fall. Successful editing or playback does not prove a new body will walk.
