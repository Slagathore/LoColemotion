"""Retained native identity/host preflight check, with no world or reservation."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests'))
import r10aj_preflight_fixture as fixture
import r10aj_host_runtime as host
import development_passive_entry_profile as source


def write(path,value):
    with path.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2);stream.write('\n')


def run(out,require_clean_success=False):
    out=Path(out).resolve()
    assert out.parent==fixture.identity.EVIDENCE and out.name.startswith('r10aj-startup-preflight-')
    assert out.is_dir() and not (out/'fixture.json').exists()
    before=source._source_snapshot();write(out/'source-before.json',before)
    if require_clean_success:assert bool(before['status']) is False,'CLEAN_SOURCE_REQUIRED'
    value=fixture.fixture(before['head']);write(out/'fixture.json',value)
    runtime=host.expected_binding()
    host.bind_runtime(runtime['images']['godot_console']['path'],runtime['images']['powershell_host']['path'])
    command=[runtime['images']['godot_engine']['path'],'--headless','--path',str(ROOT),
        '--script','res://tests/test_r10aj_startup_preflight.gd','--',str(out/'fixture.json'),str(out/'native.json')]
    write(out/'command.json',dict(command=command,working_directory=ROOT.as_posix(),timeout_seconds=180,
        synthetic_declaration=True,world_build_count=0,solver_step_count=0))
    with (out/'stdout.log').open('xb') as stdout,(out/'stderr.log').open('xb') as stderr:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr,creationflags=subprocess.CREATE_NO_WINDOW)
        timed_out=False
        try:exit_code=process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            timed_out=True
            # The live owned process anchors its descendant tree; no unrelated PID search.
            killed=subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=30,
                creationflags=subprocess.CREATE_NO_WINDOW)
            write(out/'timeout-kill.json',dict(exit_code=killed.returncode,stdout=killed.stdout.decode(errors='replace'),stderr=killed.stderr.decode(errors='replace')))
            exit_code=process.wait(timeout=30)
    write(out/'execution.json',dict(exit_code=exit_code,timed_out=timed_out))
    after=source._source_snapshot();write(out/'source-after.json',after)
    assert before==after,'SOURCE_CHANGED'
    assert not timed_out and exit_code==0,(out/'stderr.log').read_text(encoding='utf-8')
    assert (out/'stderr.log').read_bytes()==b''
    observed=json.loads((out/'native.json').read_text(encoding='utf-8'))
    assert all(value is True for value in observed['identity_checks'].values())
    preflight=observed['preflight'];receipt=preflight['helper_receipt']
    if bool(before['status']):
        assert preflight['ok'] is False and receipt['ok'] is False
        assert receipt['stage']=='source_freeze' and receipt['failure_code']=='R10AJ_STARTUP_SOURCE_NOT_CLEAN'
    else:
        assert preflight['ok'] is True and receipt['ok'] is True
        assert receipt['freeze']['head']==before['head'] and receipt['freeze']['clean'] is True
    assert all(receipt[k] is False for k in ['physical_execution_authorized','physical_acceptance_authority',
        'release_authority','launch_reservation_created','native_world_claim_created','candidate_source_key_checked','complete_safety_gate_checked'])
    assert not (fixture.identity.EVIDENCE/('development-recovery-smoke-'+value['attempt_id'])).exists()
    result=dict(ok=True,source_commit=before['head'],source_clean=not bool(before['status']),
        identity_checks=len(observed['identity_checks']),native_preflight_passed=preflight['ok'],
        owned_dirty_source_refused=bool(before['status']),retained_helper_output=True,
        candidate_source_key_checked=False,complete_safety_gate_checked=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
    write(out/'result.json',result);return result

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('output',type=Path)
    parser.add_argument('--require-clean-success',action='store_true');args=parser.parse_args()
    print(json.dumps(run(args.output,args.require_clean_success),separators=(',',':')))
