"""Check links, index bindings and the separate publication manifest."""
from html.parser import HTMLParser
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

from evidence import ROOT, check_bytes, read_json, require, verify, within

DOCS = ["README.md", "LICENSE-FAQ.md", "COMMERCIAL.md", "CONTRIBUTING.md",
        "docs/README.md", "docs/GETTING_STARTED.md", "docs/LOCOMOTION.md",
        "docs/HARNESS.md", "docs/SHOWCASE.md", "docs/LAUNCH_CHECKLIST.md",
        "docs/WHY_THE_HARNESS_EXISTS.md",
        "harness/README.md", "proof/README.md", "replay/README.md"]


class Links(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []

    def handle_starttag(self, tag, attrs):
        self.links.extend(value for key, value in attrs if key in {"href", "src"} and value)


def check_links() -> int:
    total = 0
    for name in DOCS + ["replay/index.html"]:
        file = ROOT / name
        content = file.read_text(encoding="utf-8")
        if file.suffix == ".html":
            parser = Links(); parser.feed(content); links = parser.links
        else:
            links = re.findall(r"\[[^\]]*\]\(([^\s)]+)\)", content)
        for link in links:
            parsed = urlsplit(link)
            if parsed.scheme or not parsed.path:
                continue
            target = (file.parent / unquote(parsed.path)).resolve()
            require(target.is_relative_to(ROOT) and target.exists(), f"Broken local link: {name} -> {link}")
            total += 1
    return total


def main():
    report = verify(read_json(ROOT / "proof/EVIDENCE_INDEX.json"), ROOT)
    report["local_links_checked"] = check_links()
    manifest = read_json(ROOT / "proof/PUBLICATION_PROVENANCE.json")
    require(manifest["schema_version"] == "locolemotion_publication_curation_v1", "Publication schema")
    require(manifest["scientific_records_changed"] is False, "Scientific records changed")
    for binding in manifest["files"]:
        if binding["byte_basis"] == "lf_normalized_text":
            # Public prose follows Git's text checkout policy. Scientific receipts
            # and replay data always use their separate raw-byte bindings.
            raw = within(ROOT, binding["path"]).read_bytes().replace(b"\r\n", b"\n")
            require(len(raw) == binding["byte_length"] and hashlib.sha256(raw).hexdigest() == binding["sha256"],
                    "Publication content mismatch: " + binding["path"])
        else:
            require(binding["byte_basis"] == "raw", "Unknown publication byte basis")
            check_bytes(ROOT, binding)
    report["publication_files_verified"] = len(manifest["files"])
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
