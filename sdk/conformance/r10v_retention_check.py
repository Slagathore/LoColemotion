"""Separate synthetic payload controls using retained, exposed launch metadata."""
import json
import mmap
from pathlib import Path
import subprocess
import uuid
import development_passive_entry_profile as source
import r10t_route_integration_component as base

ROOT,EVIDENCE=base.ROOT,base.EVIDENCE
RUN=EVIDENCE/'development-recovery-smoke-2e83ffbb9cb84fb1ba1dfc2c76886f37'


def main():
    directory=EVIDENCE/('r10v-retention-check-'+uuid.uuid4().hex);directory.mkdir()
    before=source._source_snapshot();base.write_new(directory/'source_before.json',before)
    envelope_path=RUN/'children/kick_passive_recovery_resume/child_envelope.json'
    with envelope_path.open('rb') as f,mmap.mmap(f.fileno(),0,access=mmap.ACCESS_READ) as raw:
        first=raw.find(b'\n  "report":');last=raw.find(b'\n  "retained_artifact_bindings":')
        assert 0<first<last
        metadata=json.loads(raw[:first]+b'\n  "report": null,'+raw[last:])
    context=json.loads(metadata['r10f_l15_launch_relationship']['payload_json'])['context']
    fixture=directory/'fixture.json'
    base.write_new(fixture,dict(envelope=metadata,context=context,runtime=base.read(RUN/'declaration.json')['runtime'],
        provenance='Post-exposure launch-metadata fixture with separately generated synthetic payloads. No original evidence modified and no new physical launch.',
        original_envelope=base.bind(envelope_path),original_attempt_reclassified=False))
    command=['C:/Program Files/PowerShell/7/pwsh.exe','-NoLogo','-NoProfile','-File',str(ROOT/'tests/test_r10v_compact_child_retention.ps1'),'-Fixture',str(fixture),'-OutputRoot',str(directory)]
    print('R10V_RETENTION_CHECK '+str(directory),flush=True)
    with (directory/'stdout.json').open('xb') as out,(directory/'stderr.txt').open('xb') as err:
        result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
    after=source._source_snapshot();base.write_new(directory/'source_after.json',after)
    receipt=dict(exit_code=result.returncode,source_unchanged=before==after,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)
    base.write_new(directory/'execution.json',receipt)
    print(json.dumps(receipt));return result.returncode


if __name__=='__main__':raise SystemExit(main())
