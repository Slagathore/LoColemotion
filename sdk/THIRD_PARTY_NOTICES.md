# Third-party notices and distribution boundary

The custom Community and Commercial terms in `LICENSE` cover only material
Charles Chambers has authority to license. Separately licensed material retains
its existing rights and obligations. A commercial Private Modifications option
does not waive a third party's source-disclosure or attribution conditions.

This licensing decision covers the **source-first SDK projection**. It does not
authorize redistribution of a compiled Godot editor, Jolt runtime, Rust dependency
binaries, Python environment or a bundled Explorer executable. Those distributions
need an inventory of the artifacts actually shipped and their applicable notices.
No dependency source is vendored by the current source-first package declaration.

## Godot Engine and Jolt Physics

The seven Godot/Jolt engine patches in `adapters/godot/engine_patches/` contain
upstream source context and modifications. Upstream portions retain their original
MIT terms and copyright notices; the custom SDK terms do not replace them.
The retained upstream notices are:

- [Godot MIT license](release/licensing/GODOT-LICENSE.txt)
- [Godot authors](release/licensing/AUTHORS.md)
- [Godot copyright and third-party inventory](release/licensing/GODOT-COPYRIGHT.txt)
- [Jolt MIT license](release/licensing/JOLT-LICENSE.txt)

Origins and exact byte digests are recorded in
`release/licensing/upstream-license-origins.json`. The six original patch identities remain preserved; the v2 audit additionally
binds the seventh contact-frame instrumentation patch now in the source projection.
These notices describe upstream provenance, not an assertion that every component
listed in Godot's inventory is redistributed in this SDK source projection.

## Locked Rust dependencies

[The locked dependency inventory](release/licensing/locked-dependency-licenses.json)
identifies all 84 external packages from the current `Cargo.lock`, including
package name, version, registry source, checksum and declared license expression.
Dependencies are obtained separately by the build tools; the inventory is not
permission to redistribute them without satisfying their actual license terms.

The `godot` 0.5.4 crate family and covered dependencies include MPL-2.0 material.
The [MPL-2.0 license](release/licensing/MPL-2.0.txt) is included. When distributing
compiled MPL-covered code, provide the applicable source availability notice and
access to corresponding covered source, including covered modifications. The
Customer's separate application need not become MPL solely because it uses those
components. Other dependencies retain their MIT, Apache, Unicode, Zlib or other
recorded terms. No royalty payment to Charles Chambers buys an exemption from them.

## Python and native host dependencies

MuJoCo, Python, numerical packages and other externally installed host tools are
not redistributed by this source-only decision. Their own licenses govern them.
The source package must not silently acquire copied wheels, DLLs, executables or
vendored source under this decision. A future bundled desktop release requires a
new concrete dependency/distribution review before publication.

## Contributions and previous permissions

Existing notices must be preserved. New third-party contributions require a
recorded rights/provenance review before being advertised under the commercial
private-modification grant. Public fork publication is not a contributor agreement.
This notice neither retracts prior permissions nor claims ownership of third-party
code. The license decision and automated inventory check are not legal opinions,
medical certifications or permission to ship the otherwise unreleased SDK.
