# Portable API conformance

The current prospective SDK1 contract is
[`portable_api_contract_v2.json`](portable_api_contract_v2.json): **83 existing
native exports**, all checked and invoked through their exact signatures. The
original v1 contract and its 58-function source receipts remain historical.
Use `include/sporespore_locomotion_sdk1.h` for the complete C surface, or
`from python.sporespore_locomotion_sdk1 import LocomotionCore` with the SDK root
on `PYTHONPATH`. The SDK1 Python class inherits the legacy convenience API and
adds four R10AA/R10AB development methods. Optional loading still supports older
pinned libraries; complete SDK1 qualification requires every declared symbol.
These additions grant no new physical behavior claim. The original header and
Python binding remain unchanged for retained consumers and Explorer evidence.


This directory owns the standalone proof for release gate `QSDK-R01` and
bounded SDK1 milestone `SDK1-M01`. The proof asks a deliberately narrow
question: can the same versioned portable locomotion API be seen and used
consistently from Rust, C, Python, and the source set that the packager will
copy?

## What the proof checks

| Layer | Plain-language check |
| --- | --- |
| Rust library | The core still builds as a Rust library, static library, and dynamic library, and its unit suite passes. |
| C header | Every public function name, parameter type, and return type matches the Rust export exactly. |
| Real dynamic library | All 83 declared symbols load and are actually called through the frozen C calling convention. |
| Python binding | All 83 `ctypes` signatures match the same contract, and the 21 end-to-end binding tests pass against the real library. |
| Failure behavior | Malformed requests return typed JSON failures; output-only calls and caller-owned output buffers obey their declared protocol. |
| Package source | Every required API file is selected by the same machine-readable inventory consumed by the real packager. |
| Negative controls | Ten deliberate removals, type changes, or clean-room-contract weakenings are rejected, plus one current-source positive control. |

The C ABI does not require a separate native C compiler in the conformance
environment. The auditor compares normalized primitive signatures across Rust
and the public C header, then independently loads and invokes every symbol via
CPython `ctypes`, which is a real foreign-function consumer of that ABI.

## Run against the source tree

From PowerShell at the repository root:

```powershell
./sdk/run_portable_api_conformance.ps1
```

This builds the release core, runs 193 Rust tests, runs the surface mutation
suite, invokes every C symbol, runs 21 Python binding tests, and emits one
`PORTABLE_API_CONFORMANCE` JSON receipt. The exact test counts are checked at
runtime and retained in the receipt rather than assumed from this guide.

To retain an authoritative source report, provide a new path whose parent
already exists:

```powershell
./sdk/run_portable_api_conformance.ps1 `
    -Report C:\path\outside\the\repository\report.json
```

A retained source report is refused unless `HEAD` is clean and exactly equals
`origin/main`. Existing reports are never overwritten.

## Create the future bounded SDK1 candidate

Candidate creation remains forbidden until all 17 non-package SDK1 milestones
pass. At that future clean, pushed source commit, retain the bounded readiness
report outside the repository and ask the packager for the explicit SDK1 role:

```powershell
./sdk/compile_quadruped_sdk1_milestone_readiness.ps1 `
    -RequireCandidate `
    -Output C:\path\outside\the\repository\sdk1-readiness.json

./sdk/package_quadruped_sdk.ps1 `
    -ReadinessReport C:\path\outside\the\repository\sdk1-readiness.json `
    -OutputDirectory C:\path\outside\the\repository\sdk1-candidate `
    -Sdk1CleanRoomCandidate
```

The first command currently refuses because `SDK1-M07`, `M08`, `M14`, and
`M20` are not passed. Do not bypass it. The packager independently reruns that
same compiler, demands exact retained/live source and authority hashes, and
uses the distinct `sdk1_clean_room_conformance_candidate` role. The older
`-CleanRoomCandidate` switch remains the stricter full-program path; the two
switches are mutually exclusive.

## Run against a future clean-room candidate

The release packager will eventually create a watermarked, non-publishable
candidate outside the game repository. From PowerShell, validate that candidate
with:

```powershell
./run_portable_api_conformance.ps1 `
    -PackageRoot C:\path\to\candidate `
    -RequireIsolatedPackage `
    -ForbiddenSourceRoot C:\path\to\SporeSpore `
    -Report C:\path\to\durable-evidence\report.json
```

Candidate mode additionally verifies the exact content-addressed readiness
report that authorized the candidate, rejects that report if it is read from
the package or source tree, rejects source-repository metadata and laboratory
directories, symbolic links, reparse points, and files not named by the package
manifest. It verifies every package-manifest hash and proves every required API
file is present. It then refuses a library override, writes all build artifacts
inside the candidate, runs against that newly built library, rechecks the
packaged source hashes, and retains its report outside both the candidate and
source tree. Retained source-tree reports likewise refuse a library override;
the override remains available only for non-retained diagnostic runs.

## Current claim boundary

A passing source-tree run proves source conformance and the exact package-source
projection. It does **not** pass `QSDK-R01` or `SDK1-M01`, because both require
the later isolated candidate run. Neither mode grants publication, walking,
physical-acceptance, or completed-SDK authority. The entire proof constructs
zero physics models or worlds, performs zero native physics reads, and takes
zero solver steps.

The current retained source proof is clean-pushed implementation `fa3e6aae`:
all 58 symbols are matched and invoked, 193 Rust and 21 Python tests pass, ten
surface mutations are refused, and the exact projection contains 1,467 files /
31,157,392 bytes. Its 4,119-byte report has SHA-256
`ee2a7bbdebc432449b152c3233522f758c445be547260fc900cef979029ed087`.
The separate bridge audit passes one positive authorization shape and refuses
13 mutations, a forged retained source identity, and conflicting candidate
modes without creating a package. Those are source/bridge qualifications, not
the still-missing isolated-candidate result.
