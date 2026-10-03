"""Audit R10T worker/reader component checks; complete route remains closed."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify
from recovery_post_completion_hold_probe import write
RECORD=ROOT/'sdk/recovery/r10t_worker_reader_interface_component_v1.json'
CLAIMS=dict(world_build_count=0,solver_step_count=0,native_core_changed=False,native_dll_changed=False,
    full_worker_report_round_trip_qualified=False,complete_dependency_key_declared=False,
    launcher_implemented=False,complete_route_qualified=False,physical_attempt_started=False,
    held_out_population_declared=False,physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')

def inspect_run(root):
    root=Path(root)
    execution=read(root/'execution.json')
    assert execution['exit_code']==0 and execution['source_unchanged']
    lock=read(root/'operation_lock.json')
    assert lock['acquired'] and lock['role']=='conformance' and not lock['test_only']
    assert lock['mutex_name']=='Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'
    before=read(root/'source_before.json');after=read(root/'source_after.json')
    assert before==after and before['remote']=='https://github.com/Slagathore/sporespore.git'
    assert before['head']=='3a241fe6c73ce5fc1ce10a0a7b5ecf0da1c5d513'
    log=(root/'tests.stderr.txt').read_text(encoding='utf-8')
    assert re.search(r'Ran 23 tests in [0-9.]+s',log) and log.rstrip().endswith('OK')
    cases=[]
    stdout=(root/'tests.stdout.txt').read_text(encoding='utf-8')
    for marker,count in [('R10T_HOLD_ROUTE_INTERFACE_ROOT ',55),('R10T_WORKER_SETTLING_BOUNDARY_ROOT ',33)]:
        lines=[line[len(marker):].strip() for line in stdout.splitlines() if line.startswith(marker)]
        assert len(lines)==1
        child=Path(lines[0]); assert child.parent.resolve()==EVIDENCE.resolve()
        result=read(child/'result.json');ran=read(child/'interface.execution.json')
        assert result['ok'] and len(result['checks'])==count and all(result['checks'].values())
        assert ran['returncode']==0 and not ran['timed_out'] and ran['source_unchanged']
        assert not (child/'interface.stderr.txt').read_bytes()
        assert result['world_build_count']==result['solver_step_count']==0 and not result['physical_route_qualified']
        snapshot=read(child/'interface.source_snapshot.json')
        for item in snapshot['changed_files']:
            assert not item['deleted']
            raw=base64.b64decode(item['replacement_base64'],validate=True)
            assert 'sha256:'+hashlib.sha256(raw).hexdigest()==item['raw_sha256']
        cases.append(dict(root=str(child),executable_checks=count,result=bind(child/'result.json')))
    return dict(ok=True,unittest_groups=23,gdscript_checks=88,python_tests=19,suites=cases,**CLAIMS)

def create(root):
    assert not RECORD.exists()
    root=Path(root).resolve(); observed=inspect_run(root)
    source=read(root/'source_before.json')
    paths=[ROOT/item['path'] for item in source['changed_files']]
    assert Path(__file__).resolve() in [p.resolve() for p in paths]
    children=[Path(v['root']) for v in observed['suites']]
    retained=[bind(p) for directory in [root,*children] for p in sorted(directory.iterdir()) if p.is_file()]
    prior_roots=['r10t-hold-route-interface-6280311906d64a729f0602d5d9630d64',
        'r10t-hold-route-interface-18404490540647eea8f95373cb15b397',
        'r10t-hold-route-interface-3ba115c3a0bb4a25ba786b4e80d3ef5c',
        'r10t-hold-route-interface-595b3a9ba50441dabdefe1594ea6eee3',
        'r10t-hold-route-interface-36fde5fdbc02429d908ffea9720a68ca',
        'r10t-worker-settling-boundary-c3c1f82541c64bb48d4324e630869ea8']
    value=dict(schema_version='sporespore_r10t_worker_reader_interface_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='bounded_worker_reader_interface_component',question_class='development'),
        source_commit=source['head'],run_root=str(root),auditor=bind(__file__),
        source_files=[bind(p) for p in paths],retained_files=retained,
        prior_interface_attempts=[dict(root=str(EVIDENCE/name),files=[bind(p) for p in sorted((EVIDENCE/name).iterdir()) if p.is_file()]) for name in prior_roots],
        correction_record='Initial fixture loaded the candidate DLL alongside the default extension and was stopped after its registration error, before policy calls. The next fixture had two refusals: its ramp alias lacked stationary-command selection, and its hold used the outer segment for the internal facade handoff. Original failed stdout, stderr, results and exact source snapshots remain retained. Later passes added explicit six-counter hold initialization, cold native replay refusals and actual worker transition hooks.',
        scope='Native facade starts and detached motor applications, one-command cold hold replay, retained terminal source projection, actual worker scheduling/retention/publication hooks with synthetic hold observations, finite measurement and development-context controls. Full report production/replay and the complete launcher safety graph remain unfinished. The candidate fails closed at source_key_complete=false.',
        observed=observed,claim_boundary=CLAIMS)
    write(RECORD,value)
    return audit()

def audit(current_sources=False):
    record=read(RECORD)
    assert record['claim_boundary']==CLAIMS
    for item in record['retained_files']+[record['auditor']]: verify(item)
    snapshot=read(Path(record['run_root'])/'source_before.json')
    originals={item['path']:item for item in snapshot['changed_files']}
    for item in record['source_files']:
        key=Path(item['path']).relative_to(ROOT).as_posix()
        raw=base64.b64decode(originals[key]['replacement_base64'],validate=True)
        assert len(raw)==item['byte_length'] and 'sha256:'+hashlib.sha256(raw).hexdigest()==item['raw_sha256']
        if current_sources:verify(item)
    for attempt in record['prior_interface_attempts']:
        for item in attempt['files']:verify(item)
    assert inspect_run(record['run_root'])==record['observed']
    return dict(ok=True,record=bind(RECORD),current_sources_verified=current_sources,unittest_groups=23,gdscript_checks=88,python_tests=19,**CLAIMS)
if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print('R10T_WORKER_READER_INTERFACE_COMPONENT '+json.dumps(create(args.create_from) if args.create_from else audit(args.current_sources)))
