"""Selected R10AJ native images and retained zero-world test transport.

V26 fixtures retain their compiled AI identity; compatibility probes retain
the original APIs and receipts while selecting the AI build. This module never constructs a physics world.
"""
import json, subprocess, time, os, sys
from pathlib import Path
import r10aj_native_interface as interface
import r10aj_host_runtime as host
import r10aj_development as identity
import development_passive_entry_profile as entry
import development_recovery_candidate as candidate
import r10ac_support_loss_diagnosis as diagnosis
from r10aa_native_component import ExactInputCore, read, write, verify
ROOT, EVIDENCE = identity.ROOT, identity.EVIDENCE

def runtime():
    selected = candidate.selection(identity.reference())
    bound = entry.binding(selected)
    for item in bound['source_files']: verify(item)
    verify(bound['runtime'])
    selected_runtime, fixture_binding, fixtures = interface.inputs()
    assert bound['runtime']['raw_sha256'] == selected_runtime['raw_sha256']
    return bound, fixtures

def run_godot(self, name, script, source, timeout=180):
    expected = host.expected_binding()
    bound = host.bind_runtime(expected['images']['godot_console']['path'], expected['images']['powershell_host']['path'])
    output = self.out / (name + '.json')
    command = [bound['images']['godot_engine']['path'], '--headless', '--path', str(ROOT), '--script', 'res://tests/' + script, '--', str(source), str(output)]
    started = time.monotonic()
    with (self.out / (name+'.stdout.log')).open('xb') as stdout, (self.out / (name+'.stderr.log')).open('xb') as stderr:
        try:
            result = subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=timeout,creationflags=subprocess.CREATE_NO_WINDOW,env=godot_environment(self.out,name))
        except subprocess.TimeoutExpired:
            write(self.out/(name+'.execution.json'),dict(command=command,timed_out=True,direct_process_killed_and_reaped=True))
            raise
    write(self.out/(name+'.execution.json'),dict(command=command,exit_code=result.returncode,seconds=time.monotonic()-started,world_build_count=0,solver_step_count=0))
    self.assertEqual(0,result.returncode,(self.out/(name+'.stderr.log')).read_text())
    self.assertEqual(b'',(self.out/(name+'.stderr.log')).read_bytes())
    value=read(output)
    self.assertTrue(value['ok'],value.get('failure', {k:v for k,v in value.get('checks',{}).items() if not v}))
    self.assertTrue(value['checks'] and all(value['checks'].values()))
    self.assertEqual((0,0),(value['world_build_count'],value['solver_step_count']))
    self.assertFalse(value['physical_acceptance_authority'] or value['release_authority'])
    return value


def godot_environment(directory, name):
    sys.path.insert(0,str(ROOT/'tests'))
    import r10aj_preflight_fixture
    path=directory/(name+'.synthetic-declaration.json')
    write(path,r10aj_preflight_fixture.fixture(entry._source_snapshot()['head']))
    environment={k:v for k,v in os.environ.items() if not k.startswith('SPORESPORE_GODOT_RECOVERY_')}
    environment['SPORE_R10AJ_GATE_DECLARATION']=str(path)
    return environment
