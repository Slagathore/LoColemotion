"""Maintainer validation layout from committed SDK source; not a release package.

The generated SDK has no .git, game project, scripts/ or tests/ directory.
Native sources needed by worker processes come from the checked source archive.
"""
import argparse
import io
import json
from pathlib import Path
import subprocess
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument("output",type=Path);args=parser.parse_args()
    root=subprocess.check_output(["git","rev-parse","--show-toplevel"],cwd=ROOT,text=True).strip()
    remote=subprocess.check_output(["git","remote","get-url","origin"],cwd=ROOT,text=True).strip()
    if Path(root).resolve()!=ROOT or remote!="https://github.com/Slagathore/LoColemotion.git": raise RuntimeError("Repository identity mismatch")
    if subprocess.check_output(["git","status","--porcelain"],cwd=ROOT,text=True).strip(): raise RuntimeError("Commit and push before materializing validation source")
    head=subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip()
    live=subprocess.check_output(["git","ls-remote","origin","refs/heads/main"],cwd=ROOT,text=True).split()[0]
    if head!=live: raise RuntimeError("Source is not pushed")
    paths=["sdk/explorer","sdk/conformance/r10v_windows_job.py","sdk/python/sporespore_locomotion.py",
        "sdk/recovery/r10dh_release_gate_adoption_v2.json","sdk/recovery/r10dh_held_out_physical_closure_v2.json"]
    data=subprocess.check_output(["git","archive","--format=zip",head,*paths],cwd=ROOT)
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=False)
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        for member in archive.infolist():
            if member.is_dir() or member.filename.startswith("sdk/explorer/phase74_diagnostic/"): continue
            destination=(output/member.filename).resolve()
            if not destination.is_relative_to(output): raise RuntimeError("Archive path escape")
            destination.parent.mkdir(parents=True,exist_ok=True);destination.write_bytes(archive.read(member))
    record=dict(source_commit=head,source_only=True,candidate_package=False,release_authority=False,
        isolated_sdk=str(output/"sdk"),game_project_present=False,git_present=False)
    (output/"layout.json").write_text(json.dumps(record,indent=2),encoding="utf-8")
    print(json.dumps(record))


if __name__=="__main__":main()
