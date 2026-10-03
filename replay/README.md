# Watch the retained runs

Open **`index.html` in this folder** with a browser after cloning or downloading
the repository. You can double-click it; no local server or package install is
required. GitHub's file view displays HTML source, so download the checkout first.

Choose Godot/Jolt, MuJoCo or Rapier/Parry. Play, scrub the timeline, jump to the
recorded impulse, change playback speed, and drag to rotate the view. The camera
follows the torso. Ground-contact markers come from the recorded flags.

The body geometry and every published pose come from three retained native
Explorer development sessions. Godot starts prone, stands, walks, takes an impulse
and follows its declared recovery route. MuJoCo and Rapier start from their own
walking setups. These are different sessions, not a matched comparison.

The viewer reads recorded simulation time and holds the most recent available
pose. It does not interpolate, smooth the motion, run physics or execute a
controller. Playback speed is a viewing control, not an engine speed measurement.

## What is included

| Engine | Published pose frames | Native steps in the original session |
| --- | ---: | ---: |
| Godot/Jolt | 2,041 | 2,041 |
| MuJoCo | 749 | 2,992 |
| Rapier/Parry | 3,172 | 3,172 |

The [manifest](manifest.json) records the original stream hashes and sizes, the
source commits, the existing closure and the derived bundle hash. The original
streams are external; this bundle contains their body poses, contact flags and
impulse events, not full telemetry. The original
[Explorer closure](../sdk/explorer/showcase_closure_v1.json) is unchanged.

From the repository root:

```powershell
python sdk/publication/evidence.py verify
```

That checks the bundled bytes. A maintainer with the retained archive can also
rebuild the projection in memory and compare every byte, without opening a world:

```powershell
python sdk/publication/build_replay.py --archive-root 'C:/your/evidence-archive' --check
```

All scripts and data are local. There are no analytics, remote assets or external
JavaScript dependencies. See [live setup](../docs/SHOWCASE.md) for the native
Explorer/Studio and [the proof index](../proof/README.md) for acceptance records.

This viewing code and data live outside `sdk/`; the root license's existing
scope applies. Displayed development sessions do not establish new acceptance,
general recovery or formal cross-engine equivalence.
