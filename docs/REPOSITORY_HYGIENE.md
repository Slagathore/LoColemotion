# Before publishing a change

Everything pushed here is public. Keep source, small proof records and the
replay here. Keep installed runtimes, the full evidence archive and local
settings on disk.

## Set up every writing checkout

From the repository root, run these commands in PowerShell or your terminal:

```text
git config user.name Slagathore
git config user.email Slagathore@users.noreply.github.com
git config core.hooksPath .githooks
git config core.autocrlf true
git config core.longpaths true
python tools/hygiene/check.py tree
python tools/hygiene/check.py eol
```

Python 3.11 or newer is required. The hooks refuse to commit or push if they
cannot run the checker. A fresh clone does not automatically install Git hooks;
set the configuration before writing. Use one writing checkout at a time.

The public identity above is the current publication identity for both author
and committer. An outside contributor should open an issue before making a PR
so we can agree how to preserve their authorship under this policy. Do not
rewrite someone else's credit to satisfy a check.

## What the checks cover

- Commit identity, messages and added lines are checked before publication.
  Assistant credit, co-author trailers and assistant names in public prose are
  refused. Tool names in source get a review warning.
- Local instruction files, editor settings, environments, build output and
  private design notes must stay untracked. Private keys, environment files,
  recognized credential patterns and personal mail addresses are refused.
  Existing upstream contacts at the fixed export snapshot and example domains
  are allowed.
- Machine names and home paths are refused in new public prose. Source and
  historical JSON can contain runtime paths; new ones get a review warning.
- Third-party game asset formats and reference directories are refused. New
  claims that source contains extracted game assets are refused too.
- A blob above 50 MiB gets a warning. A blob above 95 MiB is refused. The large
  evidence corpus belongs in the durable archive, with a small indexed record
  here.
- Published history moves forward. Do not force push, delete a published ref,
  rename `main`, or amend or rebase published commits. Earlier bytes remain
  available at the commit cited by their records.

The fixed export snapshot is the boundary for inherited upstream contacts and
existing prose. It is not permission to add new personal information. Checking
a new branch excludes that already published snapshot from repeated history
inspection and checks every later introduced commit.

## Commands and expected results

```text
python tools/hygiene/check.py staged
python tools/hygiene/check.py message PATH_TO_COMMIT_MESSAGE
python tools/hygiene/check.py tree
python tools/hygiene/check.py range OLD_FULL_COMMIT_ID NEW_FULL_COMMIT_ID
python -m unittest discover -s tools/hygiene -p "test_*.py" -v
```

Success prints `Publication hygiene passed` and exits with status zero. A
`BLOCK` message identifies the file or condition to fix. Review warnings before
committing. Do not skip the hooks to get around a failure.

The pre-commit hook checks the index and the whole working tree's text endings.
Verified newline checks are cached under Git metadata using the path, size,
modification time, blob identity and active policy. The pre-push hook checks
every introduced commit, including intermediate content later deleted, and
refuses history rewrites and ref deletion. CI repeats tree and history checks
on pushes and pull requests, with refusal tests in disposable repositories.

## Server protections and their limits

The default-branch ruleset prevents deletion and non-fast-forward updates,
with no bypass actors. It also requires the `Publication hygiene` check from
GitHub Actions before a change reaches `main`. Push a new commit to a review
branch, wait for the checks, then advance `main` to that exact checked commit.
Secret scanning and secret push protection are enabled. The repository hygiene
workflow inspects pushes and PRs from other clones.

Local hooks depend on checkout configuration. CI runs after a branch has been
submitted; it cannot erase content already pushed. Secret protection detects
supported patterns, not every possible secret. Neither layer is a promise that
arbitrary content can never reach GitHub. Review the intended diff before
publishing, and inspect a failed hygiene run immediately.

See [GitHub's ruleset documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
for the distinction between branch rules and push rules.

## Line endings

- Git stores text with LF. `.gitattributes` sets `* text=auto` plus explicit
  `eol=lf` rules for files whose bytes are verified at runtime.
- This checkout uses `core.autocrlf=true`, the setting under which the inherited
  pins were made: `text=auto` files check out with CRLF, `eol=lf` files with LF.
  Never change `core.autocrlf` or existing `.gitattributes` rules; either would
  change checkout bytes and stop pins on working-copy bytes from holding. New
  folders may add their own `.gitattributes` (for example `* text eol=lf`).
- Invariant: every tracked file on disk equals either its stored Git blob or its
  fresh-checkout form. Mixed endings, CRLF in an `eol=lf` file, and lone CRs are
  violations. Any pin on such bytes would hold only on one disk.
- Before a record pins a file, run `python tools/hygiene/check.py eol` so the
  pinned bytes are reproducible from Git. Write files with explicit newline
  control (Python `newline='\n'` or bytes; PowerShell `WriteAllText` or
  `-NoNewline` with explicit endings).
- Editors and agent tools on Windows can silently rewrite a whole file with CRLF
  (this happened to `docs/README.md` in SporeSpore on 2026-10-03). Git status may
  not show it. The pre-commit hook checks the whole tree; `eol --fix` restores.
- History: 316 SporeSpore files carried pins on CRLF bytes that only that working
  copy reproduced; their exact bytes are archived at
  `SporeSpore_Evidence\working-copy-bytes-archive-20261003-01`.

Exact retained receipts explicitly marked `-text` keep their original bytes.
Do not normalize them. These rules concern text, not binary data or the raw
evidence copies identified by their hashes.

To repair only a newline change, give an explicit tracked path:

```text
python tools/hygiene/check.py eol --fix docs/README.md
```

Repair is refused if the content differs from the indexed blob after CRLF to
LF conversion, or if a checkout filter would make another content change. Save
and review real edits yourself; the repair command never discards them.
