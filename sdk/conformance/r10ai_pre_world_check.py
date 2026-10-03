"""R10AI selected-runtime context and complete pre-world sequence; no reservation."""
import argparse, copy, json, os, subprocess, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests'))
import r10ai_preflight_fixture as fixture
import r10ai_host_runtime as host
import r10ad_startup_invalid_closure as closure
import development_passive_entry_profile as source

def write(path,value):
    with path.open('x',encoding='utf-8',newline='\n') as f:json.dump(value,f,indent=2);f.write('\n')

def run(out):
    before=source._source_snapshot();write(out/'source-before.json',before)
    declaration=fixture.fixture(before['head'])
    runtime=host.expected_binding()
    host.bind_runtime(runtime['images']['godot_console']['path'],runtime['images']['powershell_host']['path'])
    tokens={p.name:closure.bind(p) for p in closure.EVIDENCE.glob('*consumption*.json')}
    def native(name,mode,binding=None,decl=None):
        request={'declaration':declaration if decl is None else decl}
        if binding is not None:request['expected_binding']=binding
        write(out/(name+'.request.json'),request)
        command=[runtime['images']['godot_engine']['path'],'--headless','--path',str(ROOT),'--script',
            'res://tests/test_r10ai_pre_world_path.gd','--',str(out/(name+'.request.json')),
            str(out/(name+'.json')),mode]
        env={k:v for k,v in os.environ.items() if not k.startswith('SPORESPORE_GODOT_RECOVERY_')}
        write(out/(name+'.command.json'),dict(command=command,working_directory=str(ROOT),timeout_seconds=180))
        with (out/(name+'.stdout.log')).open('xb') as stdout,(out/(name+'.stderr.log')).open('xb') as stderr:
            process=subprocess.Popen(command,cwd=ROOT,stdin=subprocess.DEVNULL,stdout=stdout,stderr=stderr,env=env,
                creationflags=subprocess.CREATE_NO_WINDOW)
            timed_out=False
            try:code=process.wait(timeout=180)
            except subprocess.TimeoutExpired:
                timed_out=True
                killed=subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],capture_output=True,timeout=30)
                write(out/(name+'.timeout-kill.json'),dict(exit_code=killed.returncode))
                code=process.wait(timeout=30)
        write(out/(name+'.execution.json'),dict(exit_code=code,timed_out=timed_out))
        assert code==0 and not timed_out,(name,code)
        assert (out/(name+'.stderr.log')).read_bytes()==b''
        result=closure.read(out/(name+'.json'))
        assert result['ok'] and result['world_build_count']==result['solver_step_count']==0
        assert not result['population_reserved'] and result['campaign_admission_doubled'] is True
        return result
    produced=native('producer','produce')
    binding={k:produced['capture'][k] for k in ('raw_sha256','utf8_byte_length')}
    consumed=native('selected-runtime','consume',binding)
    assert consumed['comparison']['ok'] is True and consumed['capture']==produced['capture']
    assert consumed['construction_boundary_reached'] is True
    assert consumed['construction_guard']['failure_code']=='R10AI_NATIVE_WORLD_QUALIFICATION_PENDING'
    assert consumed['configuration']['ok'] is True and consumed['runtime_preflight']['ok'] is True
    assert consumed['terminal_code']=='QSDK_R10F_L9_CHILD_ARM_SETUP_INVALID:kick_passive_recovery_resume'
    old=closure.read(closure.RUN/'declaration.json')['prepared_context_expectation']['raw_capture_binding']
    legacy=native('legacy-runtime','consume',old)
    assert legacy['construction_boundary_reached'] is False and legacy['comparison']['failure_code']=='L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH'
    corrupt=copy.deepcopy(binding);corrupt['raw_sha256']='sha256:'+'0'*64
    negative=native('corrupt-digest','consume',corrupt)
    assert negative['construction_boundary_reached'] is False and negative['comparison']['failure_code']=='L15_PRE_WORLD_PREPARED_CONTEXT_MISMATCH'
    crossed=copy.deepcopy(declaration);crossed['runtime']=closure.read(closure.ROOT/'sdk/development/r10ad_host_runtime_contract_v1.json')
    wrong=native('crossed-runtime','consume',binding,crossed)
    assert wrong['construction_boundary_reached'] is False and wrong['terminal_code']=='QSDK_R10F_EXTENSION_UNAVAILABLE'
    after=source._source_snapshot();write(out/'source-after.json',after);assert before==after
    assert tokens=={p.name:closure.bind(p) for p in closure.EVIDENCE.glob('*consumption*.json')}
    assert not (fixture.identity.EVIDENCE/('development-recovery-smoke-'+declaration['attempt_id'])).exists()
    result=dict(ok=True,source_commit=before['head'],source_clean=not bool(before['status']),
        independent_native_processes=5,selected_runtime_context_accepted=True,legacy_context_refused=True,
        corrupt_digest_refused=True,production_pre_world_comparator_used=True,
        inherited_pre_world_sequence_exercised=True,campaign_admission_doubled=True,full_launch_path_proven=False,
        construction_guard_refused=True,crossed_runtime_refused=True,world_build_count=0,
        solver_step_count=0,population_reserved=False,physical_acceptance_authority=False,release_authority=False)
    write(out/'result.json',result);return result

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('output',type=Path)
    print(json.dumps(run(p.parse_args().output)))
