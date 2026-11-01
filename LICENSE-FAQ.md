# License FAQ

The SDK and the covered lab are open source under the GNU Affero General Public
License, version 3 only (AGPL-3.0-only), with a commercial agreement as the
alternative. The [root notice](LICENSE) and [complete terms](licenses/AGPL-3.0.txt)
control; this page explains where to look and adds no permissions.

| Question | Answer under the current terms |
| --- | --- |
| What is covered? | Original materials in `sdk/`, `scripts/lab/`, `data/lab/`, `tests/`, the top-level lab runners and their tests listed in the [root notice](LICENSE), `scenes/tools/`, `harness/`, `proof/` and `replay/`. The covered lab material is treated as part of the SDK under the same terms. Third-party material keeps its own terms. |
| Is the whole repository under that license? | No. `scripts/sim/`, `scenes/sim/`, `scripts/tools/` and `docs/` are outside the grant. The creature editor, game, assets and other paths not listed in the root notice remain reserved unless separately licensed. |
| Is it open source? | Yes. The AGPL is an OSI approved open source license. It applies to the covered paths only. |
| Can I use it for free? | Yes, for any purpose, including research and commercial use, as long as you follow the AGPL. There is no revenue limit and no evaluation period. |
| Can I keep my application closed source? | Not under the AGPL. If you distribute a program that includes the SDK, the whole program has to be offered under the AGPL with its complete source. Closed distribution needs a [commercial agreement](COMMERCIAL.md). |
| Can I change the SDK privately? | Yes. Changes you never distribute, and never let other people use over a network, do not have to be published. |
| What about hosted services? | If you modify the SDK and let users interact with it over a network, the AGPL requires offering those users the complete source of your modified version. |
| What does the commercial agreement add? | Shared Improvements lets you ship a closed application that includes the SDK while sharing your SDK changes under the AGPL. Private Modifications also lets you keep those SDK changes private. Pricing is quoted by business size. |
| What about copies under the earlier license? | Until 2026-11-01 this material was offered under the [Community License 1.0](licenses/COMMUNITY-LICENSE.md). Copies obtained under it keep those terms. Versions that include the current notice are offered only under the AGPL or a commercial agreement. |
| Does a pull request accept the contributor agreement? | No. It requires separate affirmative acceptance identifying the contributor and covered submissions. |

The existing source-only distribution decision does not authorize redistributing
native engine builds or imply that the validated SDK1 candidates are public
releases. See [third-party notices](THIRD_PARTY_NOTICES.md) and the
[release boundary](sdk/release/README.md).

The unchanged `sdk/LICENSE` and legal texts in `sdk/release/licensing/` retain
the former SporeSpore name and the earlier Community terms because evidence
records bind their bytes. They are historical. The root notice and `licenses/`
govern this repository.

The [current source check](docs/GETTING_STARTED.md#check-the-current-licensing-inputs)
verifies a separate declaration for this public checkout, including the root
notice, the exact AGPL text and the unchanged earlier terms. It preserves the
earlier declarations and audit and does not requalify SDK1 or authorize a
release. Its refusal controls also reject adding reserved paths to the declared
license scope or restoring a revenue limit.
