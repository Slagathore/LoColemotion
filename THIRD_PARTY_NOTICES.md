# Third party notices

This file covers third party material across the LoColemotion repository. It
supplements [sdk/THIRD_PARTY_NOTICES.md](sdk/THIRD_PARTY_NOTICES.md), which keeps
the project's former name because other records pin its exact bytes. Everything
in that file still applies.

## Godot Engine and Jolt Physics

The Godot and Jolt engine patches in `sdk/adapters/godot/engine_patches/` contain
upstream source context and modifications. Upstream portions keep their MIT terms
and copyright notices. The Godot license, authors list, copyright inventory and
the Jolt license are in [sdk/release/licensing/](sdk/release/licensing/).

## Rapier

The three patches in `sdk/adapters/rapier/engine_patches/` modify the crates.io
package `rapier3d` 0.34.0 from Dimforge (https://github.com/dimforge/rapier),
which is licensed under the Apache License 2.0. Each patch contains upstream
Rapier source context together with LoColemotion changes that add opt in solver
telemetry for motor work, energy exchange and discrete staging. The patch files
and their README identify what was changed.

Upstream Rapier portions keep the Apache License 2.0. The full license text is in
[licenses/APACHE-2.0.txt](licenses/APACHE-2.0.txt). The `rapier3d` 0.34.0 crate
ships no NOTICE file. The LoColemotion SDK terms do not replace Apache terms for
upstream code.

## Rust, Python and other dependencies

The locked Rust dependency inventory, the MPL-2.0 text for the `godot` crate
family, and the rules for Python and native host dependencies are described in
[sdk/THIRD_PARTY_NOTICES.md](sdk/THIRD_PARTY_NOTICES.md). Dependencies are
obtained separately by the build tools. No third party binaries, wheels or
vendored dependency sources are included in this repository.
