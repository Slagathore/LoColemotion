"""Read an exact historical blob; never write or run the frozen source archive."""
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = ROOT.parent / "SporeSpore"


def read_blob(commit: str, relative: str) -> bytes:
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Historical lookup requires an exact commit")
    path = PurePosixPath(relative)
    if path.is_absolute() or not relative or ".." in path.parts or "\\" in relative or ":" in relative:
        raise ValueError("Historical lookup requires a safe relative path")
    spec = commit + ":" + relative
    current = subprocess.run(["git", "cat-file", "blob", spec], cwd=ROOT, capture_output=True)
    if current.returncode == 0:
        return current.stdout
    if not (ARCHIVE / ".git").is_dir():
        raise ValueError("Historical blob needs the retained private source archive")
    def git(*words):
        return subprocess.check_output(["git", *words], cwd=ARCHIVE)
    expected = json.loads((ROOT / "EXPORT_PROVENANCE.json").read_bytes())["source"]["commit"]
    if (Path(git("rev-parse", "--show-toplevel").decode().strip()).resolve() != ARCHIVE.resolve()
            or git("remote", "get-url", "origin").decode().strip() != "https://github.com/Slagathore/sporespore.git"
            or subprocess.run(["git", "merge-base", "--is-ancestor", expected, "HEAD"], cwd=ARCHIVE).returncode != 0
            or subprocess.run(["git", "merge-base", "--is-ancestor", commit, expected], cwd=ARCHIVE).returncode != 0):
        raise ValueError("Frozen source archive identity changed")
    return git("cat-file", "blob", spec)
