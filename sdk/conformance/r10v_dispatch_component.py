"""Audit the retained R10V dispatch checkpoint; no production launch authority."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import uuid
import r10t_route_integration_component as base

ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10v_dispatch_component_v1.json'
KEY = ROOT/'sdk/recovery/r10v_v56_walking_entry_contract_v3.json'
FAILED = EVIDENCE/'r10v-dispatch-check-74c9396ce4f3436e92e7c8bce928a64a'
ROUTE = EVIDENCE/'r10v-dispatch-check-e120d505220f4957a12a2d81744b309b'
LAUNCHER = EVIDENCE/'r10v-launcher-check-4232f05de2c84abab4e569075f06303e'
INTERFACES = EVIDENCE/'r10v-dispatch-interfaces-575187f1c7624a839e93dd181cc2764f'
ROUTE_CHILD = EVIDENCE/'r10v-route-review-cbadc9a5399949829a55b7fb5082563f'
LAUNCHER_CHILD = EVIDENCE/'development-r10v-launcher-d7a62a8bee794cfaa14d51bb0586e116'
EXPECTED = [('exact_runtime_binding',11),('host_runtime_successor',3),('shared_interface_definitions',4),
    ('exact_publication',5),('production_publication',8),('owned_process_relationship',7),('godot_rust_owner_contract',2)]
CLAIMS = dict(population_and_route_dispatch_integrated=True,production_host_integrated=False,
    complete_report_and_final_auditor_qualified=False,complete_safety_gate_passed=False,
    physical_launch_authorizer_closed=True,physical_attempt_started=False,
    world_build_count=0,solver_step_count=0,native_controller_changed=False,native_dll_changed=False,
    original_attempt_reclassified=False,held_out_population_declared=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def snapshot(root):
    before = base.read(root/'source_before.json')
    assert before == base.read(root/'source_after.json')
    assert before['head'] == '9f03a7d3286eb4d350a1622e17eb02edc75a2d30'
    assert before['remote'] == 'https://github.com/Slagathore/sporespore.git'
    for row in before['changed_files']:
        assert not row['deleted']
        assert 'sha256:'+hashlib.sha256(base64.b64decode(row['replacement_base64'],validate=True)).hexdigest() == row['raw_sha256']
    return before


def unit_run(root, count, failures):
    assert base.read(root/'result.json')['exit_code'] == (1 if failures else 0)
    log = (root/'stderr.log').read_text(encoding='utf-8-sig')
    assert re.findall(r'^Ran (\d+) tests in ',log,re.M) == [str(count)]
    assert len(re.findall(r'^test_.* \.\.\. ok$',log,re.M)) == count-failures
    assert not re.findall(r'^ERROR:',log,re.M)
    assert log.rstrip().endswith('FAILED (failures=1)' if failures else 'OK')
    for child in base.children(root)-{root}:
        snapshot(child)


def interfaces():
    assert snapshot(INTERFACES) == snapshot(ROUTE_CHILD) == snapshot(LAUNCHER_CHILD)
    execution = base.read(INTERFACES/'execution.json')
    assert execution['exit_code'] == 0 and execution['source_unchanged']
    values = [json.loads(line.split(' ',1)[1]) for line in (INTERFACES/'stdout.log').read_text().splitlines()
        if line.startswith('DEVELOPMENT_INTERFACES_COMPLETE ')]
    assert len(values) == 1
    result = values[0]
    assert result['passed'] and not result['physical_smoke_executed'] and not result['official_qualification_passed']
    assert [(s['id'],s['test_count']) for s in result['stages']] == EXPECTED
    root = Path(result['output_root']); assert root.parent == EVIDENCE
    for stage in result['stages']:
        assert stage['passed'] and stage['exit_code'] == 0 and not stage['timed_out']
        for kind in ('stdout','stderr'):
            assert base.bind(root/stage[kind])['raw_sha256'] == 'sha256:'+stage[kind+'_sha256']
    assert (INTERFACES/'stderr.log').stat().st_size == 0
    return result


def observed():
    unit_run(FAILED,15,1); unit_run(ROUTE,16,0); unit_run(LAUNCHER,12,0)
    assert 'FAIL: test_actual_worker_prefix_and_four_native_routes ' in (FAILED/'stderr.log').read_text()
    result = base.read(ROUTE_CHILD/'routes.json')
    assert result['ok'] and len(result['checks']) == 50 and all(result['checks'].values())
    assert result['world_build_count'] == result['solver_step_count'] == 0
    reader = base.read(ROUTE_CHILD/'reader.json')
    assert reader['ok'] and all(reader['checks'].values()) and reader['complete_report_exercised'] is False
    assert reader['checks']['actual_retained_worker_replayed']
    discovery = base.read(LAUNCHER_CHILD/'selected-stages.json')
    assert len(discovery['stages']) == 64 and discovery['test_count'] == 229
    assert sum(discovery['discovered_test_counts'].values()) == 229
    lock = base.read(LAUNCHER/'operation_lock.json')
    assert lock['acquired'] and not lock['abandoned_owner_recovered'] and not lock['test_only']
    interface = interfaces()
    return dict(targeted_tests_passed=28,shared_interface_tests_passed=40,shared_interface_stages=7,
        actual_godot_route_checks_passed=50,synthetic_upright_consumer_replay_passed=True,
        inherited_stages_discovered=64,inherited_tests_discovered=229,inherited_full_gate_executed=False,
        initial_fixture_failure_retained=True,source_unchanged_during_tests=True,
        interface_root=interface['output_root'])


def audit(record):
    assert record['claim_boundary'] == CLAIMS
    for item in [record['auditor'],record['manifest'],record['source_archive']['key'],record['source_archive']['snapshot']]:
        base.verify(item)
    for item in base.read(record['manifest']['path'])['files']:
        base.verify(item)
    folder = Path(record['source_archive']['directory'])
    key = base.read(record['source_archive']['key']['path'])
    for item in key['bound_source_files']:
        assert base.bind(folder/item['path'])['raw_sha256'] == item['raw_sha256']
    guard = (folder/'sdk/conformance/r10v_development_launch.py').read_text()
    assert "require(False, 'PRODUCTION_HOST_INTEGRATION_PENDING')" in guard
    assert len(key['bound_source_files']) == 1054
    assert record['observed'] == observed()
    return dict(ok=True,**record['observed'],**CLAIMS)


def create():
    assert not RECORD.exists()
    observation = observed()
    directory = EVIDENCE/('r10v-dispatch-component-'+uuid.uuid4().hex); directory.mkdir()
    archive = base.archive_key(directory,KEY,ROUTE_CHILD/'source_before.json')
    roots = {FAILED,ROUTE,LAUNCHER,INTERFACES,Path(observation['interface_root'])}
    for root in list(roots): roots.update(base.children(root))
    paths = {p for root in roots for p in root.rglob('*') if p.is_file()}
    paths.update(p for p in Path(archive['directory']).rglob('*') if p.is_file())
    manifest = directory/'manifest.json'
    base.write_new(manifest,dict(files=[base.bind(p) for p in sorted(paths)]))
    record = dict(schema_version='sporespore_r10v_dispatch_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='zero_world_dispatch_component',question_class='development'),
        auditor=base.bind(__file__),manifest=base.bind(manifest),source_archive=archive,
        observed=observation,claim_boundary=CLAIMS,
        history='The v2 route test retained a ramp FRAME_INVALID refusal because the shared synthetic fixture had no R10V alias handling. The distinct v3 source adds R10V to the existing ramp and hold fixture cases; all original checks remain. No physical world was constructed in either run.',
        scope='Actual Python and PowerShell population and declaration selection, Godot candidate and four native route adapters, a synthetic upright worker retention fixture and fresh consumer replay, plus all real shared interfaces. Discovery of 229 inherited tests is not execution of the full successor gate.',
        remaining=['Distinct durable production host with canonical runtime, source and invocation binding; append-only child, replay and audit progress.',
            'Complete exposed-pair final-auditor diagnostic; cloned historical helper is not yet the R10V pair implementation.',
            'Complete safety graph including host and retention controls; resolve real operation-lock ownership for pre-lock host tests.',
            'Fresh complete dependency key, full applicable qualification, clean pushed freeze, five fresh development cells, separate held-out decision and QSDK-R10/M07 adoption.'])
    audit(record); base.write_new(RECORD,record)
    return dict(ok=True,record=base.bind(RECORD),**observation,**CLAIMS)


if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('--create',action='store_true'); args=parser.parse_args()
    print(json.dumps(create() if args.create else audit(base.read(RECORD))))
