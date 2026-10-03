# Contributing

Useful bug reports, clearer integration docs and narrowly scoped fixes are welcome.
Start with an issue for a controller change, new engine, harness extraction or
change to the evidence model. Those usually affect more than one file.

## Before changing source

Read [getting started](docs/GETTING_STARTED.md), the [harness guide](docs/HARNESS.md)
and the relevant contract. Keep the change focused and explain how to reproduce
the problem. Include the commit, platform, engine/runtime identity and the exact
command when they matter. Say whether the failure happened during build,
qualification, native execution, retention or evaluation.

Do not upload the full evidence archive, native binaries, local runtime
configuration, secrets or private customer data. A small receipt, hash, source
record and reproduction are usually more useful.

## Scientific records are not ordinary generated files

- Preserve original failures and consumed identities.
- Do not edit an observed threshold, result or support flag to make a test pass.
- Describe a correction in a distinct successor with its own identity and scope.
- Do not rename pinned internal symbols just to remove the old project name.
- Keep development observations separate from finite acceptance and comparative claims.

Public documentation and the replay viewer can change without rerunning physics.
Check local links and run `python sdk/publication/evidence.py verify` after edits
to the curated boundary. If you change the replay projection, compare it to the
original streams with `build_replay.py --archive-root <path> --check`; do not
silently regenerate historical records.

## Pull requests

Explain the problem, the resulting behavior, what you checked and what remains
unverified. Show the exact retained evidence when a claim changes. A successful
build or viewer test is not physical acceptance.

Contributions keep their ownership. Commercial relicensing requires the separate
[Contributor Agreement](licenses/CONTRIBUTOR-AGREEMENT.md) and recorded affirmative
acceptance covering the submission. Opening a PR, checking a template box or
publishing a fork does not sign it. Licensing outside `sdk/` must also be resolved
explicitly before code is accepted into a broader grant.
