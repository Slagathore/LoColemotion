"""Audit the retained R10T launcher/report integration, without granting physics authority."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import subprocess
import uuid
from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify

RECORD = ROOT / 'sdk/recovery/r10t_route_integration_component_v1.json'
RUN = EVIDENCE / 'r10t-route-integration-02dfb148491e4c5c97219b0987c65148'
HOLD = EVIDENCE / 'r10t-complete-hold-report-33b6bd268fc94e40a26a97ec3f0811ee'
PREPARATION = EVIDENCE / 'development-r10t-preparation-report-1fd7bef0f4db42e1a68577ef7bc1100f'
KEY = ROOT / 'sdk/recovery/r10t_v56_walking_entry_contract_v9.json'
CORRECTION_V8 = EVIDENCE / 'r10t-integration-corrections-92500f15070f43b593a098f235189594'
CONTRACT = ROOT / 'sdk/development/r10t_safety_stage_contract_v1.json'
PRIOR = [
    CORRECTION_V8.name,
    'r10t-launcher-component-d5fc1b56f5544b7fb9cb9854897824f2',
    'r10t-complete-report-component-3d21383c71a34b5ea74c4af3c0862fa5',
    'r10t-hold-report-component-ede6a017a5404e82a0d8967c6c44142f',
    'r10t-hold-report-component-880fc5a40a1c4eb18e0440afee50168a',
    'r10t-hold-reader-repair-2d62c7905e8d48e9963dfe9a698c374c',
    'development-passive-entry-post-exposure-replay-ee71effa76784630b042157e72709c61',
    'r10t-hold-reader-repair-09913462626d47cabdd85336ff0accf0',
    'development-passive-entry-post-exposure-replay-eeecc2adb571488088f4d31ae717c4c4',
]
CLAIMS = dict(world_build_count=0, solver_step_count=0, native_core_changed=False,
    native_dll_changed=False, launcher_implemented=True, complete_dependency_key_declared=True,
    complete_smoke_safety_gate_passed=False, complete_route_qualified=False,
    physical_attempt_started=False, held_out_population_declared=False,
    physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20')


def write_new(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2); stream.write('\n')


def inspect_run(root, count, failures):
    root = Path(root)
    value = read(root/'execution.json')
    assert value['exit_code'] == (1 if failures else 0) and value['source_unchanged']
    before, after = read(root/'source_before.json'), read(root/'source_after.json')
    assert before == after and before['remote'] == 'https://github.com/Slagathore/sporespore.git'
    lock = read(root/'operation_lock.json')
    assert lock['acquired'] and not lock['test_only'] and lock['role'] == 'conformance'
    assert lock['mutex_name'] == 'Global\\SporeSpore.Locomotion.PhysicalConformance.Serial.v1'
    log = (root/'tests.stderr.txt').read_text(encoding='utf-8')
    assert re.findall(r'^Ran (\d+) tests in ', log, flags=re.M) == [str(count)]
    found = re.findall(r'^FAIL: (.+)$', log, flags=re.M)
    assert len(found) == failures and not re.findall(r'^ERROR:', log, flags=re.M)
    assert len(re.findall(r'^test_.* \.\.\. ok$', log, flags=re.M)) == count-failures
    assert log.rstrip().endswith('FAILED (failures='+str(failures)+')' if failures else 'OK')
    return dict(tests=count, passed=count-failures, failures=found, source_unchanged=True)


def observations(correction):
    original = inspect_run(RUN, 59, 3)
    expected = ['test_coverage_math_uses_observed_stance_and_unchanged_timeout',
        'test_declared_recovery_limits_and_bound_runtime', 'test_declared_recovery_limits_and_bound_runtime']
    assert [x.split(' ',1)[0] for x in original['failures']] == expected
    corrected = inspect_run(CORRECTION_V8, 16, 1)
    assert corrected['failures'][0].startswith('test_actual_gate_selects_r10t_and_every_declared_test_exists ')
    current = inspect_run(correction, 5, 0)
    cases = []
    for name, count, dwell, handoff in [('ready',30,30,'bounded_hold'),('timeout',240,0,'timeout')]:
        replay = read(HOLD/name/'replay.json'); measured = read(HOLD/name/'finite-task.json')
        assert replay['ok'] and replay['complete_report_timeline_replayed']
        assert replay['transition_count'] == 575+count
        stance = replay['stance_entry_replay']
        assert stance['replayed_post_recovery_hold_commands'] == count
        assert stance['recomputed_readiness_samples'] == count+1 and stance['post_recovery_ready_dwell'] == dwell
        assert stance['world_build_count'] == stance['solver_step_count'] == 0
        assert not measured['finite_task_predicates_passed'] and not measured['entry']['initial_recovery_ready']
        assert measured['entry']['post_recovery']['handoff'] == handoff
        execution = read(HOLD/name/'execution.json')
        assert execution['exit_code'] == 0 and execution['world_build_count'] == execution['solver_step_count'] == 0
        assert not (HOLD/name/'stderr.log').read_bytes()
        cases.append(dict(case=name, transitions=575+count, hold_commands=count,
            recomputed_readiness_samples=count+1, ready_dwell=dwell, handoff=handoff, complete_task_positive=False))
    prep = read(PREPARATION/'replay-result.json')
    assert prep['ok'] and prep['complete_report_timeline_replayed'] and prep['transition_count'] == 611
    assert (prep['stance_entry_replay']['replayed_neutral_commands'],prep['stance_entry_replay']['replayed_hold_commands']) == (166,171)
    assert len(read(PREPARATION/'refusals.json')) == 8
    contract = read(CONTRACT)
    assert len(contract['stages']) == 48 and sum(s['tests'] for s in contract['stages']) == contract['total_tests'] == 220
    return dict(original_integration=original, corrected_assertions_and_launch_guards=corrected, current_schedule_and_launcher_discovery=current,
        complete_hold_reports=cases, preparation_transitions=611, preparation_refusals=8,
        declared_safety_stages=48, declared_safety_tests=220)


def children(root):
    result = {Path(root)}
    for name in ['tests.stdout.txt','stdout.log']:
        path = Path(root)/name
        if path.exists():
            for value in re.findall(r'^[A-Z0-9_]+ (C:[^\r\n]+)$',path.read_text(encoding='utf-8'),flags=re.M):
                child = Path(value.strip())
                assert child.parent.resolve() == EVIDENCE.resolve() and child.is_dir(), child
                result.add(child)
    return result


def archive_key(directory, key_path, snapshot):
    key = read(key_path); original = {x['path']:x for x in read(snapshot)['changed_files']}
    folder = directory/key_path.stem; folder.mkdir()
    for item in key['bound_source_files']+[dict(path=key_path.relative_to(ROOT).as_posix(),raw_sha256=bind(key_path)['raw_sha256'])]:
        name = item['path']; retained = original.get(name)
        raw = base64.b64decode(retained['replacement_base64'],validate=True) if retained else (ROOT/name).read_bytes()
        assert 'sha256:'+hashlib.sha256(raw).hexdigest() == item['raw_sha256'], name
        target = folder/name; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(raw)
    return dict(key=bind(key_path), directory=folder.as_posix(), snapshot=bind(snapshot))


def audit(record, current_sources=False):
    assert record['claim_boundary'] == CLAIMS
    for item in [record['auditor'],record['manifest'],record['safety_contract']]: verify(item)
    for item in read(record['manifest']['path'])['files']: verify(item)
    for archive in record['source_archives']:
        verify(archive['key']); verify(archive['snapshot']); key = read(archive['key']['path'])
        for item in key['bound_source_files']:
            assert bind(Path(archive['directory'])/item['path'])['raw_sha256'] == item['raw_sha256']
            if current_sources and Path(archive['key']['path']) == KEY:
                assert bind(ROOT/item['path'])['raw_sha256'] == item['raw_sha256'], item['path']
    assert observations(record['correction_root']) == record['observed']
    return dict(ok=True,record=bind(RECORD) if RECORD.exists() else None,
        current_sources_verified=current_sources,**record['observed'],**CLAIMS)


def create(correction):
    assert not RECORD.exists() and not list(EVIDENCE.glob('r10t_*consumption_v1.json'))
    assert Path(subprocess.check_output(['git','rev-parse','--show-toplevel'],cwd=ROOT,text=True).strip()).resolve() == ROOT.resolve()
    assert subprocess.check_output(['git','remote','get-url','origin'],cwd=ROOT,text=True).strip() == 'https://github.com/Slagathore/sporespore.git'
    correction = Path(correction).resolve(); assert correction.parent == EVIDENCE.resolve()
    observed = observations(correction)
    directory = EVIDENCE/('r10t-route-integration-closure-'+uuid.uuid4().hex); directory.mkdir()
    archives = [archive_key(directory, ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v7.json', RUN/'source_before.json'),
        archive_key(directory, ROOT/'sdk/recovery/r10t_v56_walking_entry_contract_v8.json', CORRECTION_V8/'source_before.json'),
        archive_key(directory, KEY, correction/'source_before.json')]
    retained = set()
    for root in [RUN,correction,*[EVIDENCE/name for name in PRIOR]]: retained.update(children(root))
    retained.update([HOLD,PREPARATION,directory])
    files = {p for root in retained for p in root.rglob('*') if p.is_file()}
    manifest = directory/'manifest.json'
    write_new(manifest,dict(schema_version='sporespore_r10t_route_integration_retention_v1',files=[bind(p) for p in sorted(files)]))
    record = dict(schema_version='sporespore_r10t_route_integration_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='bounded_launcher_and_complete_report_interfaces',question_class='development'),
        auditor=bind(__file__),manifest=bind(manifest),safety_contract=bind(CONTRACT),
        source_archives=archives,correction_root=str(correction),observed=observed,claim_boundary=CLAIMS,
        correction_record='Retained original seed fixture refusal, missing synthetic finalizer counters, full hold policy-reader refusal, diagnostic-directory refusal and full hold contact-reader refusal. Distinct source keys repair those interfaces. The 59-test integration then passed 56 tests; three inherited assertions expected the predecessor budget or a Rust change. Those assertions and all launch guards passed on v8. Renaming the schedule override also exposed its inherited test, so launcher discovery correctly refused the count mismatch. Restoring the override name preserves the declared four-test population; the complete schedule suite and actual launcher discovery pass on v9. All original reports, failed replays and source keys remain unchanged.',
        scope='Actual worker, native facade, finalization, report retention, reader and launcher interfaces with synthetic or explicitly exposed supplied poses. The ready and timeout reports stop after the hold and remain complete-task negatives. The complete 48-stage safety graph and all physical evidence remain pending.')
    audit(record,current_sources=True)
    write_new(RECORD,record)
    return audit(record,current_sources=True)

if __name__ == '__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create-from');parser.add_argument('--current-sources',action='store_true');args=parser.parse_args()
    print('R10T_ROUTE_INTEGRATION_COMPONENT '+json.dumps(create(args.create_from) if args.create_from else audit(read(RECORD),args.current_sources)))
