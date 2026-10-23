"""Verify a relocated Studio installation and its viewing resources; zero worlds."""
import argparse
import json
from pathlib import Path
import sys

from studio_layout import isolated_source
from studio_portability import load_dependencies
from studio_proof import verify as verify_proof


def verify(installation, python):
    source = isolated_source(installation / "source")
    cfg = load_dependencies(installation / "dependencies.json", source, python)
    proof = verify_proof(installation / "proof-pack")
    if proof["source_commit"] != source:
        raise ValueError("Proof pack and installed source have different materialization identities")
    return dict(ok=True, source_commit=source, dependency_roles=sorted(k for k in cfg if k != "source_commit"),
                proof=proof, world_build_count=0, native_session_started=False,
                physical_acceptance_authority=False, release_authority=False)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--installation", type=Path, required=True)
    parser.add_argument("--mujoco-python", type=Path, default=Path(sys.executable))
    args = parser.parse_args()
    print(json.dumps(verify(args.installation.resolve(), args.mujoco_python), indent=2))
