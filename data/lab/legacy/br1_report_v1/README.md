# BR1 report v1 legacy qualification records

This directory preserves two incompatible contracts that were both published
under the same v1 report-schema identifier and the same v1 inventory identifier.
The collision is historical fact:

| Qualification profile | Source commit | Tests | Test artifacts | Inventory SHA-256 | Report-schema SHA-256 |
| --- | --- | ---: | ---: | --- | --- |
| `BR1_L0_V1_R001_I45` | `2f748218e5d11532f0179df0d182d8c6712a3923` | 45 | 90 | `4e090096c4009e1406214307a80e46480e80efbb4228f30df8efdc9de4ff13f6` | `f7596fcaf798c1c4627d5cef1af4bda4136cbf08346acf00284e13f23e502567` |
| `BR1_L0_V1_R002_I51` | `77b96212133a71863b517eb5c6dd0c17678c8db7` | 51 | 102 | `f287e53d6b47fad15205a8ed416b0616e5eaae694453cd661c6eb08e1e2b79fa` | `f42f060962fd2870f36c9e615d9efea5af1e2744f36f3c95e9ed4f46991b7be8` |

The files below `r001_i45/`, `r002_i51/`, and `common/` are byte-exact Git
blob snapshots. Do not reformat, normalize, rename in place, or replace them.
Their paths and SHA-256 values are pinned by immutable qualification profiles
and by the allowlisted registry loader.

The common campaign snapshot has SHA-256
`c8146b00bfabfd2c4784cf2907ef68244d03388ccc184a9d16a99d49423419cd`.
The common receipt-schema snapshot has SHA-256
`8cb6aceefa9b11bbd6756b91185c6f00adea06633633929d5c588d2a1804d716`.

## Safety boundary

These profiles are `verify_only`. The production compatibility verifier uses
them to select the exact historical contract before authenticating an already
sealed report. They do not authorize a new v1 attestation, do not broaden either
schema to accept a range such as 45 through 51, and do not authorize the current
operator to create another report-v1 object.

Dispatch is fail-closed on this exact tuple:

1. report schema identifier;
2. inventory SHA-256;
3. required test count;
4. test-artifact count;
5. campaign identifier; and
6. campaign SHA-256.

Snapshot paths come only from the source-controlled allowlist. No path supplied
by an evidence report is used to choose a local schema or inventory file.

`known_certifications_v1.json` is a portable discovery index for the two sealed
reports and receipts observed on 2026-07-21. Its hashes help locate and identify
the expected objects, but the index is not a substitute for schema qualification
or receipt HMAC verification.

## Append-only maintenance rule

Never edit an existing snapshot or profile after release. A newly discovered
historical byte contract gets a new revision directory, a new profile ID, a new
allowlist entry, and explicit adversarial tests. A future authoring contract must
use a new report/receipt version and HMAC domain rather than reusing v1.

## Integration state

Completed here:

- exact byte snapshots, immutable profile data/schema, known-report index, and
  fail-closed allowlisted registry dispatch;
- production report-v1 verification routed through the exact selected profile;
- production report-v1 authoring disabled with
  `LEGACY_CERTIFICATION_AUTHORING_DISABLED`;
- both known external reports and HMAC receipts successfully verified through
  the compatibility dispatcher (`R001/I45` and `R002/I51`); and
- an append-only current authoring contract using report-v2, inventory-v2,
  receipt-v2, a distinct HMAC domain, and a distinct receipt directory.

The clean production v2 campaign passed at implementation commit
`1779accd87b8b30f3985c83a3fdb2ea536856389` under certification ID
`br1_20260721T200358Z_63a593be`. Its report-v2 and detached receipt were both
verified under production trust. This authenticates current-suite execution;
it does not retroactively broaden either historical BR1 claim or, by itself,
declare BR2/BR3/standing/walking accepted.
