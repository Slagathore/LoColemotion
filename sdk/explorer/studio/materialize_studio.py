"""Project clean pushed Studio source for local installation; no release authority."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import zipfile

from studio_layout import ROOT,EVIDENCE,SCHEMA,source_files,verify_source


def materialize(output,config):
    source=verify_source(physical=True)
    output=output.resolve()
    if not output.is_relative_to(EVIDENCE):raise ValueError('Use the durable evidence root')
    paths=['sdk/explorer',':(exclude)sdk/explorer/phase74_diagnostic/**',
           'sdk/conformance/r10v_windows_job.py','sdk/python/sporespore_locomotion.py',
           'sdk/adapters/mujoco/sporespore_mujoco_adapter',
           'sdk/recovery/r10dh_release_gate_adoption_v2.json','sdk/recovery/r10dh_held_out_physical_closure_v2.json',
           'sdk/LICENSE','sdk/THIRD_PARTY_NOTICES.md','sdk/release/licensing']
    raw=subprocess.check_output(['git','archive','--format=zip',source,*paths],cwd=ROOT)
    output.mkdir(parents=True,exist_ok=False)
    layout=output/'source';layout.mkdir()
    with zipfile.ZipFile(io.BytesIO(raw)) as archive:
        for member in archive.infolist():
            if member.is_dir():continue
            target=(layout/member.filename).resolve()
            if not target.is_relative_to(layout):raise ValueError('Archive path escape')
            target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(archive.read(member))
    record=dict(schema_version=SCHEMA,source_commit=source,
        ledger_scope=dict(subsystem='explorer',engine_scope='3e',authority_mode='development',question_class='development'),
        files=[dict(path=p.relative_to(layout).as_posix(),byte_length=p.stat().st_size,sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in source_files(layout)],
        physical_acceptance_authority=False,release_authority=False)
    (layout/'studio-layout.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8',newline='\n')
    cfg=json.loads(config.read_text(encoding='utf-8-sig'));cfg['source_commit']=source
    (output/'dependencies.json').write_text(json.dumps(cfg,indent=2)+'\n',encoding='utf-8',newline='\n')
    verify_source(source,root=layout)
    print(json.dumps(dict(source_commit=source,isolated_root=str(layout),files=len(record['files']),runtime_dependencies='explicit external inputs',release_authority=False)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True);parser.add_argument('--config',type=Path,required=True)
    args=parser.parse_args();materialize(args.output,args.config)
