"""Check publication hygiene without modifying source or experimental records."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import subprocess
import sys

IDENTITY = ("Slagathore", "Slagathore@users.noreply.github.com")
BASELINE = "c3643d35fe475595fc6be812a2f6b401162d4372"
ZERO = "0" * 40
WARN_BYTES = 50 * 1024 * 1024
MAX_BYTES = 95 * 1024 * 1024
EMAIL = re.compile(r"[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
ASSISTANTS = re.compile(r"\b(?:codex|claude|chatgpt|openai|anthropic|copilot)\b", re.I)
ATTRIBUTION = re.compile(r"co[-]authored[-]by|generated\s+with|claude[.]ai/code|claude[-]session|noreply@anthropic[.]com|\U0001f916", re.I)
SECRETS = re.compile(
    r"\b(?:gh[pousr]_[A-Za-z0-9]{20,255}|github_pat_[A-Za-z0-9_]{40,255}|"
    r"sk-(?:proj-|ant-[A-Za-z0-9-]*-)?[A-Za-z0-9_-]{24,255}|"
    r"(?:AKIA|ASIA)[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{20,255}|"
    r"AIza[A-Za-z0-9_-]{35}|hf_[A-Za-z0-9]{25,255})\b|"
    r"-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY-----"
)
HOME = re.compile(r"[A-Za-z]:[\\/]+Users[\\/]+[^\\/\s]+|/c/Users/[^/\s]+", re.I)
GAME = re.compile(r"ripped\s+from\s+spore|spore" r"modder|remake\s+of\s+spore", re.I)


def git(*args: str, data: bytes | None = None, allowed: tuple[int, ...] = (0,)) -> bytes:
    result = subprocess.run(["git", *args], input=data, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode not in allowed:
        raise ValueError("Git inspection failed: " + " ".join(args) + "\n" + result.stderr.decode(errors="replace"))
    return result.stdout


def forbidden(path: str) -> bool:
    parts = PurePosixPath(path.lower()).parts
    local = {"agents.md", "claude.md", ".claude", ".codex", ".agents", ".fusion", ".vscode", ".venv"}
    return (bool(local.intersection(parts)) or path.lower().startswith((
        ".github/copilot", ".github/instructions/", "docs/design_notes/", "sdk/target/"))
        or "_spore_ref" in parts or PurePosixPath(path.lower()).suffix in {".package", ".rw4", ".gmdl", ".pem", ".key", ".p12"}
        or any(p == ".env" or p.startswith(".env.") or p == "id_rsa" or p.startswith("id_rsa.") for p in parts))


def prose(path: str) -> bool:
    return path.lower().endswith((".md", ".markdown")) or PurePosixPath(path).name.lower().startswith(("readme", "license"))


def entries(ref: str | None = None) -> list[tuple[str, str, str]]:
    result = []
    if ref:
        rows = git("ls-tree", "-r", "-z", ref).split(b"\0")
        for row in filter(None, rows):
            header, name = row.split(b"\t", 1)
            mode, kind, oid = header.decode().split()
            if kind != "blob":
                raise ValueError("Uninspected nested repository: " + name.decode())
            result.append((name.decode("utf-8"), mode, oid))
    else:
        for row in filter(None, git("ls-files", "--stage", "-z").split(b"\0")):
            header, name = row.split(b"\t", 1)
            mode, oid, stage = header.decode().split()
            if stage != "0":
                raise ValueError("Resolve the index conflict before publishing: " + name.decode())
            result.append((name.decode("utf-8"), mode, oid))
    return result


def blobs(rows):
    # Read objects in one Git process; never execute a checkout's files or filters.
    process = subprocess.Popen(["git", "cat-file", "--batch"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    try:
        for path, mode, oid in rows:
            process.stdin.write((oid + "\n").encode()); process.stdin.flush()
            header = process.stdout.readline().split()
            if len(header) != 3 or header[1] != b"blob":
                raise ValueError("Missing blob: " + path)
            size = int(header[2])
            raw = process.stdout.read(size)
            if len(raw) != size or process.stdout.read(1) != b"\n":
                raise ValueError("Truncated blob inspection: " + path)
            yield path, mode, raw
    finally:
        process.stdin.close(); process.stdout.close()
        if process.wait() != 0:
            raise ValueError("Git blob inspection failed")


class Check:
    def __init__(self):
        self.errors: set[str] = set()
        self.warnings: set[str] = set()
        self.upstream: set[str] = set()
        self.historical_prose: dict[str, set[str]] = {}

    def baseline(self):
        # Fixed export history permits existing upstream contacts, never a newly
        # added address from the current checkout or an arbitrary prior commit.
        if subprocess.run(["git", "cat-file", "-e", BASELINE], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
            return
        gitdir = Path(git("rev-parse", "--absolute-git-dir").decode().strip())
        cachefile = gitdir / "hygiene-baseline-cache.json"
        fingerprint = hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
        try:
            previous = json.loads(cachefile.read_text(encoding="utf-8"))
            if previous["commit"] == BASELINE and previous["checker"] == fingerprint:
                self.upstream = set(previous["upstream"])
                self.historical_prose = {key: set(value) for key, value in previous["prose"].items()}
                return
        except (OSError, ValueError, KeyError):
            pass
        for path, _, raw in blobs(entries(BASELINE)):
            if b"\0" in raw:
                continue
            if b"@" in raw:
                for address in EMAIL.findall(raw.decode("utf-8", errors="replace")):
                    if "g" + "mail" not in address.lower():
                        self.upstream.add(address.lower())
            if prose(path):
                self.historical_prose[path] = {
                    line for line in raw.decode("utf-8", errors="replace").splitlines()
                    if ASSISTANTS.search(line)
                }
        temporary = cachefile.with_suffix(".new")
        temporary.write_text(json.dumps({"commit": BASELINE, "checker": fingerprint,
            "upstream": sorted(self.upstream), "prose": {key: sorted(value) for key, value in self.historical_prose.items()}}), encoding="utf-8")
        os.replace(temporary, cachefile)

    def identity(self, author=None, committer=None):
        if author is None:
            identities = [git("var", name).decode().split(">", 1)[0] + ">" for name in ("GIT_AUTHOR_IDENT", "GIT_COMMITTER_IDENT")]
            expected = f"{IDENTITY[0]} <{IDENTITY[1]}>"
            if any(value != expected for value in identities):
                self.errors.add("Author and committer must use the documented public identity.")
        elif author != IDENTITY or committer != IDENTITY:
            self.errors.add("Commit author or committer differs from the documented public identity.")

    def message(self, value: str):
        if ATTRIBUTION.search(value) or ASSISTANTS.search(value):
            self.errors.add("Commit message contains assistant attribution.")
        self.lines("COMMIT_MESSAGE", value.splitlines(), added=True)

    def lines(self, path: str, lines, *, added: bool):
        text = "\n".join(lines)
        lower = text.lower()
        if ATTRIBUTION.search(text):
            self.errors.add("Attribution marker: " + path)
        if ASSISTANTS.search(text):
            if prose(path) or path == "COMMIT_MESSAGE":
                offending = [line for line in lines if ASSISTANTS.search(line)]
                if added or any(line not in self.historical_prose.get(path, set()) for line in offending):
                    self.errors.add("Assistant name in public prose: " + path)
            elif added:
                self.warnings.add("Review a tool-name reference in code: " + path)
        if "g" + "mail" in lower:
            self.errors.add("Personal mail provider reference: " + path)
        if "@" in text:
            for address in EMAIL.findall(text):
                domain = address.lower().split("@", 1)[1]
                if (domain != "users.noreply.github.com" and domain != "example.com"
                        and not domain.endswith((".invalid", ".test"))
                        and address.lower() not in self.upstream):
                    self.errors.add("Non-public email address: " + path)
        if SECRETS.search(text):
            self.errors.add("Possible credential or private key: " + path)
        if added and (HOME.search(text) or re.search(r"\bloki\b", text, re.I)):
            target = self.errors if prose(path) or path == "COMMIT_MESSAGE" else self.warnings
            target.add("Machine-local identity or home path: " + path)
        if added and GAME.search(text):
            self.errors.add("Third-party game asset provenance: " + path)

    def objects(self, rows, *, scan: bool):
        for path, mode, raw in blobs(rows):
            if forbidden(path):
                self.errors.add("Forbidden publication path: " + path)
            if mode not in {"100644", "100755"}:
                self.errors.add("Uninspected link or nested repository: " + path)
            if len(raw) > MAX_BYTES:
                self.errors.add("Blob exceeds 95 MiB: " + path)
            elif len(raw) > WARN_BYTES:
                self.warnings.add("Blob exceeds 50 MiB: " + path)
            if scan and b"\0" not in raw:
                self.lines(path, raw.decode("utf-8", errors="replace").splitlines(), added=False)

    def diff(self, old: str | None, new: str | None):
        args = ["diff", "--no-ext-diff", "--no-textconv", "--no-renames", "--diff-filter=ACMRT", "--unified=0"]
        args += [old, new] if new else ["--cached"]
        # The null-delimited name list handles spaces and avoids quoted patch
        # filenames. Ask for each changed file's diff with a literal pathspec.
        names = git(*(args[:5] + ([old, new] if new else ["--cached"]) + ["--name-only", "-z"]))
        index = {path: (path, mode, oid) for path, mode, oid in entries(new)}
        changed = [p.decode("utf-8") for p in names.split(b"\0") if p]
        self.objects([index[p] for p in changed if p in index], scan=False)
        for current in changed:
            patch = git(*args, "--", ":(literal)" + current).decode("utf-8", errors="replace")
            self.lines(current, [line[1:] for line in patch.splitlines() if line.startswith("+") and not line.startswith("+++")], added=True)

    def range(self, old: str, new: str):
        if not re.fullmatch(r"[0-9a-f]{40}", old) or not re.fullmatch(r"[0-9a-f]{40}", new):
            raise ValueError("Range requires full commit object ids")
        if old == ZERO and subprocess.run(["git", "merge-base", "--is-ancestor", BASELINE, new],
                                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
            old = BASELINE
        for revision in git("rev-list", "--reverse", new, *( [] if old == ZERO else ["^" + old])).decode().splitlines():
            fields = git("show", "-s", "--format=%an%x00%ae%x00%cn%x00%ce%x00%B", revision).decode().split("\0", 4)
            self.identity(tuple(fields[:2]), tuple(fields[2:4])); self.message(fields[4])
            parents = git("rev-list", "--parents", "-n", "1", revision).decode().split()[1:]
            # Include every parent of merges so content introduced through a
            # second parent cannot evade the added-line check.
            for parent in parents or [git("hash-object", "-t", "tree", "--stdin", data=b"").decode().strip()]:
                self.diff(parent, revision)

    def push(self, stream):
        for line in stream:
            fields = line.split()
            if len(fields) != 4:
                raise ValueError("Malformed pre-push ref input")
            _, local, remote_ref, remote = fields
            if local == ZERO:
                self.errors.add("Deleting published refs is forbidden: " + remote_ref); continue
            if not re.fullmatch(r"[0-9a-f]{40}", local + "") or not re.fullmatch(r"[0-9a-f]{40}", remote):
                raise ValueError("Invalid push object id")
            local_commit = git("rev-parse", local + "^{commit}").decode().strip()
            if remote != ZERO:
                # Missing remote history also refuses the push; fetch and inspect.
                remote_commit = git("rev-parse", remote + "^{commit}").decode().strip()
                result = subprocess.run(["git", "merge-base", "--is-ancestor", remote_commit, local_commit])
                if result.returncode:
                    self.errors.add("Non-fast-forward update is forbidden: " + remote_ref); continue
                self.range(remote_commit, local_commit)
            else:
                # A new ref includes every commit not already published to a
                # remote-tracking ref. Tree inspection still checks its tip.
                known = git("rev-list", "--reverse", local_commit, "--not", "--remotes").decode().splitlines()
                for commit in known:
                    parents = git("rev-list", "--parents", "-n", "1", commit).decode().split()[1:]
                    self.range(parents[0] if parents else ZERO, commit)
            self.objects(entries(local_commit), scan=True)


def eol(check: Check, fixes: list[str] | None = None, *, cache: bool = False):
    root = Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve()
    gitdir = Path(git("rev-parse", "--absolute-git-dir").decode().strip())
    rows = git("ls-files", "--eol", "-z")
    index = {path: oid for path, _, oid in entries()}
    fingerprint = hashlib.sha256(rows + Path(__file__).read_bytes()).hexdigest()
    cachefile = gitdir / "hygiene-eol-cache.json"
    state = {}
    if cache and cachefile.exists():
        try:
            prior = json.loads(cachefile.read_text())
            if prior["fingerprint"] == fingerprint:
                state = prior["files"]
        except (OSError, ValueError, KeyError):
            pass
    refreshed = {}
    requested = set(fixes or [])
    seen = set()
    for row in filter(None, rows.split(b"\0")):
        fields, rawpath = row.split(b"\t", 1)
        path = rawpath.decode("utf-8"); flags = fields.decode()
        seen.add(path)
        # Explicit binary attributes protect the exact retained receipt bytes.
        if "attr/-text" in flags or "i/-text" in flags:
            continue
        if "i/crlf" in flags or "i/mixed" in flags:
            check.errors.add("Stored text is not LF: " + path)
        file = root / path
        if not file.is_file() or file.is_symlink():
            check.errors.add("Tracked file is missing or is a link: " + path); continue
        stat = file.stat(); key = [stat.st_size, stat.st_mtime_ns, index[path]]
        if cache and state.get(path) == key and path not in requested:
            refreshed[path] = key; continue
        raw = file.read_bytes()
        if b"\0" in raw:
            continue
        normalized = raw.replace(b"\r\n", b"\n")
        lone_cr = b"\r" in normalized
        mixed = b"\r\n" in raw and b"\n" in raw.replace(b"\r\n", b"")
        bad = lone_cr or mixed or ("eol=lf" in flags and b"\r\n" in raw)
        if path in requested:
            blob = git("cat-file", "blob", index[path])
            if normalized != blob or lone_cr:
                check.errors.add("Refusing to overwrite content changes: " + path); continue
            checkout = git("cat-file", "--filters", ":" + path)
            # Only Git's declared newline transformation is eligible for repair.
            if checkout.replace(b"\r\n", b"\n") != blob:
                check.errors.add("Refusing an unverified checkout filter: " + path); continue
            if raw != checkout:
                file.write_bytes(checkout)
                print("Restored declared checkout endings: " + path)
            bad = False
        if bad:
            check.errors.add("Working-copy newline drift: " + path)
        else:
            stat = file.stat(); refreshed[path] = [stat.st_size, stat.st_mtime_ns, index[path]]
    for path in requested - seen:
        check.errors.add("Not an indexed repair target: " + path)
    if cache and not check.errors:
        temp = cachefile.with_suffix(".new")
        temp.write_text(json.dumps({"fingerprint": fingerprint, "files": refreshed}), encoding="utf-8")
        os.replace(temp, cachefile)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="mode", required=True)
    sub.add_parser("staged"); sub.add_parser("tree"); sub.add_parser("push")
    message = sub.add_parser("message"); message.add_argument("file")
    history = sub.add_parser("range"); history.add_argument("old"); history.add_argument("new")
    endings = sub.add_parser("eol"); endings.add_argument("--fix", nargs="+", metavar="PATH")
    args = parser.parse_args(argv)
    check = Check()
    try:
        if args.mode == "eol":
            eol(check, args.fix)
        else:
            check.baseline()
            if args.mode == "staged":
                for key, value in [("core.hooksPath", ".githooks"), ("core.autocrlf", "true")]:
                    if git("config", "--get", key, allowed=(0, 1)).decode().strip() != value:
                        check.errors.add("Required checkout setting: " + key + "=" + value)
                check.identity(); check.diff(None, None); eol(check, cache=True)
            elif args.mode == "tree":
                check.objects(entries(), scan=True)
                # CI verifies stored bytes, independent of its platform checkout.
                for row in git("ls-files", "--eol", "-z").split(b"\0"):
                    if row and b"attr/-text" not in row and (row.startswith(b"i/crlf") or row.startswith(b"i/mixed")):
                        check.errors.add("Stored text is not LF: " + row.split(b"\t", 1)[1].decode())
            elif args.mode == "message":
                check.message(Path(args.file).read_text(encoding="utf-8"))
            elif args.mode == "range":
                check.range(args.old, args.new)
            else:
                check.push(sys.stdin)
    except (ValueError, OSError, UnicodeError, KeyError) as error:
        check.errors.add(str(error))
    for value in sorted(check.warnings):
        print("WARN " + value, file=sys.stderr)
    for value in sorted(check.errors):
        print("BLOCK " + value, file=sys.stderr)
    if not check.errors:
        print("Publication hygiene passed: " + args.mode)
    return 1 if check.errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
