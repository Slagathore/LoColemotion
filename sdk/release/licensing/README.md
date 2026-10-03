# SDK community and commercial licensing

Charles Chambers selected and authorized these terms on 2026-10-03. The Community
license is effective for covered SDK source; no commercial customer order has
been issued. Product renaming is deferred. The legal licensor is Charles Chambers,
not a presumed company or an LLC that has not been formed.

## Published documents

- [SDK license notice](../../LICENSE): covered source and third-party exclusions.
- [Community License 1.0](COMMUNITY-LICENSE.md): free personal learning, hobbies,
  evaluation, monetized tutorials and business use at or below **US$100,000**.
- [Commercial Agreement 1.0](COMMERCIAL-LICENSE.md): quote-based size bands with
  **Shared Improvements** and **Private Modifications** rights options.
- [Order form](COMMERCIAL-ORDER-FORM.md): unexecuted template; customer scope,
  fee, term, size band and rights must be agreed before a commercial grant exists.
- [Contributor Agreement](CONTRIBUTOR-AGREEMENT.md): affirmative acceptance is
  required for commercial relicensing of accepted contributions. Contributors
  retain ownership. No agreement is inferred from a pull request or public fork.
- [Third-party notices](../../THIRD_PARTY_NOTICES.md) and the exact locked
  [dependency inventory](locked-dependency-licenses.json).

## How the rules work

Business revenue includes the entire controlled group across **all industries**.
A large medical company entering simulation for the first time does not receive
free business use. A low-revenue subsidiary or contractor cannot exempt a large
benefiting parent/client. Unrelated wages and personal investment returns do not
count for an individual acting on their own independent personal project.

The cap is inclusive and uses trailing-twelve-month gross revenue, checked at
least monthly. A genuine first crossing has a 90-day upgrade grace; groups already
above the cap have no grace on entry. The evaluation allowance is 90 days per SDK
major version and excludes production, ongoing business R&D and client delivery.
Ordinary monetized demonstrations/tutorials are expressly permitted.

Community and Commercial Shared Improvements require freely available corresponding
SDK source when distributing covered SDK changes. The source remains under the
Community terms and must stay available throughout distribution and three years
afterward. Private undistributed experiments need not be published. The customer's
separate game/application may remain proprietary under either commercial option.

Commercial Private Modifications removes that sharing requirement only for code
within the licensor's actual grant. Third-party terms remain binding. Customer size
and modification rights are independent pricing dimensions. Prices are by quote;
no dollar price, customer, signed order, royalty or support promise is invented.

The 90-day timing, monthly check, source-retention period and 30-day first-breach
cure are implementation terms selected while drafting the owner-authorized policy.
They are explicit in the published documents, not hidden in a pricing page.

## Review and exact limits

This is original custom software licensing, not MIT, Apache, GPL, MPL, a PolyForm
license or an OSI-approved open-source grant. The previous permissive-license
predecision and its negative result remain immutable. The
[v2 contract](../quadruped_distribution_licensing_contract_v2.json) implements this
owner decision; its audit checks the exact files, metadata, dependencies, package
projection and claim boundaries. It does not establish legal enforceability,
independent ownership verification, attorney review or customer execution.

Software-licensing counsel review is recommended before commercial deals. No
attorney review has occurred in this task and none is represented as completed.
The source-first license decision does not authorize a binary SDK or desktop
release; a bundled Explorer requires its actual dependency inventory and notices.

## Concrete review cases

| Case | Result |
| --- | --- |
| Hobbyist with an unrelated salary | Personal non-business learning is free |
| Business group at exactly $100,000 | Community business eligibility passes |
| Business group above $100,000 | Commercial terms required, subject to first-crossing grace |
| Large diagnostics company doing its first simulation | Whole-group revenue applies |
| Small subsidiary or contractor serving a large group | Benefiting controlled group applies |
| Monetized ordinary independent tutorial | Express free-use exception |
| Corporate research or internal simulation | Business Use, even before product revenue |
| Shared Improvements customer ships modified SDK | Corresponding SDK source is available free |
| Private Modifications customer ships its own SDK changes | Covered modifications may remain private |
| Either customer ships an independent game | Game source need not be shared |
| Customer modifies MPL-covered upstream code | Upstream requirements still apply |
| Customer wishes to resell the SDK as middleware | Express commercial scope required |

## Sources consulted

These comparison sources are not adopted licenses or endorsements:
[PolyForm Small Business](https://polyformproject.org/licenses/small-business/1.0.0),
[PolyForm Noncommercial](https://polyformproject.org/licenses/noncommercial/1.0.0),
[Mozilla MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/), and
[Creative Commons software guidance](https://creativecommons.org/faq/#can-i-apply-a-creative-commons-license-to-software).

## Validation

From the authoritative repository root:

```powershell
& 'C:/Program Files/Python311/python.exe' -B sdk/release/licensing/check_licensing.py
```

The audit is zero-world. `--require-ready` also requires clean pushed source.
Its retained closure, not the existence of these documents alone, determines M14.
