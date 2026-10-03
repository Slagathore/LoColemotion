"""Close the consumed R10AG Python-consumer failure without regrading it."""
import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess

import r10ab_first_support_closure as streams
import qsdk_r10f_l15_launch_relationship as ownership
from r10ae_replay_invalid_closure import ROOT, EVIDENCE, read, bind, write_new

HEAD = 'bb5052c893878229307256deb3d367512b74cd5f'
RUN = EVIDENCE / 'development-recovery-smoke-9a42d367f7854202b43e7525a66c4b03'
CHILD = RUN / 'children/kick_passive_recovery_resume'
OUTER = EVIDENCE / 'r10ag-qualified-supervisor-1378d8e2ccd044b8b6b444c557f9ad33'
TOKEN = EVIDENCE / 'r10ag_contact_frame_diagnostic_65248_consumption_v1.json'
KEY = ROOT / 'sdk/recovery/r10ag_v56_walking_entry_contract_v15.json'
CONTRACT = ROOT / 'sdk/development/r10ag_safety_stage_contract_v1.json'
RECORD = ROOT / 'sdk/recovery/r10ag_replay_invalid_closure_v1.json'
SOURCE_BYTES = EVIDENCE / 'r10ag-frozen-source-bytes-915a54b1d36540df904947784a394f07'
REPORT_SHA = 'sha256:e5f6da423da6eaecd713b09650bc839533d9ca779f62905135e31cd18f434b94'
CLAIMS = dict(original_attempt_classification='consumed_infrastructure_invalid_after_world',
    original_attempt_reclassified=False, population_consumed=True, rerun_authorized=False,
    full_python_consumer_passed=False, final_independent_audit_passed=False,
    valid_development_ghost=False, recovery_success_obtained=False,
    physical_acceptance_authority=False, release_authority=False,
    sdk1_score='14/20', full_program_score='14/25')


def frozen_sources():
    rows = read(KEY)['bound_source_files']
    assert len(rows) == len({r['path'] for r in rows}) == 2116
    result = subprocess.run(['git', 'cat-file', '--batch'], cwd=ROOT,
        input=''.join(HEAD + ':' + r['path'] + '\n' for r in rows).encode(),
        capture_output=True, check=True, timeout=60, creationflags=subprocess.CREATE_NO_WINDOW)
    assert not result.stderr
    raw, cursor = result.stdout, 0
    for row in rows:
        end = raw.index(b'\n', cursor); header = raw[cursor:end].split()
        assert len(header) == 3 and header[1] == b'blob', row['path']
        size = int(header[2]); data = raw[end + 1:end + 1 + size]; cursor = end + 2 + size
        variants = [data] if b'\r\n' in data else [data, data.replace(b'\n', b'\r\n')]
        if not any(len(v) == row['byte_length'] and 'sha256:' + hashlib.sha256(v).hexdigest() == row['raw_sha256'] for v in variants):
            exact = (SOURCE_BYTES / row['path']).read_bytes()
            assert len(exact) == row['byte_length'] and 'sha256:' + hashlib.sha256(exact).hexdigest() == row['raw_sha256']
            assert exact.replace(b'\r\n', b'\n') == data.replace(b'\r\n', b'\n'), row['path']
    assert cursor == len(raw)
    source = subprocess.check_output(['git', 'show', HEAD + ':sdk/conformance/r10ag_development.py'], cwd=ROOT).decode()
    assigned = {n.id for item in ast.parse(source).body if isinstance(item, ast.Assign)
        for target in item.targets for n in ast.walk(target) if isinstance(n, ast.Name)}
    assert 'ROUTE' not in assigned
    consumer = subprocess.check_output(['git', 'show', HEAD + ':sdk/conformance/development_passive_entry_profile.py'], cwd=ROOT).decode()
    assert 'from r10ag_development import ROUTE as R10AG_ROUTE_ID' in consumer


def partial_records():
    """Read original AG packets with bounded memory, preserving their namespace."""
    with (CHILD / 'worker_report.json').open(encoding='utf-8') as stream:
        found = False
        for line in stream:
            if line.startswith('  "r10ag_partial_recovery": {'):
                found = True
            if found and line.startswith('    "final_memory": {'):
                lines = ['{\n']
                for line in stream:
                    lines.append(line)
                    if line.startswith('    }'): break
                yield 'final_memory', json.loads(''.join(lines).rstrip().removesuffix(','))
            if found and line.startswith('    "step_packets": ['):
                lines = []
                for line in stream:
                    if line.startswith('    ]'):
                        assert not lines
                        return
                    lines.append(line)
                    if line.startswith('      }'):
                        yield 'packet', json.loads(''.join(lines).rstrip().removesuffix(','))
                        lines = []
    raise AssertionError('AG_PARTIAL_RECORDS_INCOMPLETE')


def retained_diagnostic():
    rows, plans, final = [], [], None
    for kind, value in partial_records():
        if kind == 'final_memory': final = value; continue
        rows.append(streams.diagnosis.snapshot(value))
        plans.append(value['native_receipt']['next_load_plan'])
    assert len(rows) == 601 and final['phase'] == 'failed'
    assert final['terminal_failure_code'] == 'phase_timeout:raise_body'
    assert final['standing_samples_observed'] == 0 and final['ordered_completed_phases'] == ['establish_distal_support']
    assert [r['prior_phase'] for r in rows] == ['establish_distal_support'] + ['raise_body'] * 600
    modes = dict(Counter(p['mode'] for p in plans if p))
    assert modes == dict(loaded_geometry_rise=110, seek_distal_load=490)
    raise_rows = rows[1:]
    gates = {k: sum(r['classification'][k] for r in raise_rows) for k in (
        'distal_support_gate', 'raised_body_gate', 'stable_stance_gate', 'joint_limits_respected',
        'actuator_budget_respected', 'any_nonfoot_contact')}
    assert gates == dict(distal_support_gate=109, raised_body_gate=0, stable_stance_gate=0,
        joint_limits_respected=600, actuator_budget_respected=600, any_nonfoot_contact=600)
    lost = sum(not rows[i+1]['classification']['distal_support_gate']
        for i, p in enumerate(plans[:-1]) if p['mode'] == 'loaded_geometry_rise')
    assert lost == 86
    return dict(reported_terminal_failure=final['terminal_failure_code'], partial_steps=601,
        raise_commands=600, mode_counts=modes, raise_gate_counts=gates,
        immediately_after_loaded_rise_support_losses=86, loaded_rise_commands=110,
        torso_height_ratio_range=[min(r['classification']['torso_height_ratio'] for r in raise_rows),
            max(r['classification']['torso_height_ratio'] for r in raise_rows)],
        maximum_center_of_mass_height_gain_m=max(r['classification']['center_of_mass_height_gain_m'] for r in raise_rows),
        analysis_scope='Unqualified retained-data observation from an infrastructure-invalid attempt; no matched effect or acceptance conclusion.',
        original_attempt_reclassified=False)


def observed():
    declaration, supervisor = read(RUN/'declaration.json'), read(RUN/'supervisor_result.json')
    assert supervisor['ok'] is False and supervisor['physical_attempt_started'] is True
    assert supervisor['failure_code'] == 'SMOKE_ENTRY_REPLAY_FAILED:kick_passive_recovery_resume'
    assert supervisor['independent_audit'] is None
    assert declaration['source_snapshot'] == supervisor['source_snapshot'] == dict(head=HEAD, dirty=False, status=[], changed_file_bindings=[])
    assert read(OUTER/'execution.json')['exit_code'] == 1
    error = (OUTER/'stderr.log').read_text(encoding='utf-8-sig')
    assert "ImportError: cannot import name 'ROUTE' from 'r10ag_development'" in error
    assert "from r10ag_development import ROUTE as R10AG_ROUTE_ID" in error
    assert (CHILD/'passive_entry_replay_result.json').read_bytes().strip() == b''
    launch, token, contract = read(RUN/'r10ag_development_launch.json'), read(TOKEN), read(CONTRACT)
    assert token['attempt_id'] == declaration['attempt_id'] == launch['attempt_id']
    assert token['source_commit'] == HEAD and token['seed'] == declaration['seed'] == 65248 and token['attempt_limit'] == 1
    assert launch['declaration'] == streams.gate_reader.binding(RUN/'declaration.json')
    assert launch['stage_reservation'] == streams.gate_reader.binding(TOKEN)
    assert launch['source_key'] == streams.gate_reader.binding(KEY)
    assert launch['freeze'] == dict(root=ROOT.as_posix(), remote='https://github.com/Slagathore/sporespore.git', branch='main', head=HEAD, origin_main=HEAD, live_origin_main=HEAD, clean=True)
    stages = declaration['safety_stages']
    assert stages == supervisor['safety_stages'] and len(stages) == len(contract['stages']) == 65
    assert sum(s['test_count'] for s in stages) == contract['total_tests'] == 240
    for stage, spec in zip(stages, contract['stages'], strict=True):
        assert stage['id'] == spec['id'] and stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0
        assert stage['test_count'] == stage['expected_test_count'] == spec['tests']
        for stream in ('stdout', 'stderr'):
            assert bind(RUN/stage[stream])['raw_sha256'] == 'sha256:' + stage[stream+'_sha256']
    termination = streams.small_fields(CHILD/'termination_receipt.json')
    context = json.loads(termination['r10f_l15_launch_relationship']['payload_json'])['context']
    ownership.validate_child_launch(streams.small_fields(CHILD/'child_envelope.json'), context)
    assert termination['exit_code'] == 0 and termination['timed_out'] is False and termination['termination_protocol_valid'] is True
    assert read(CHILD/'engine_health.json')['passed'] is True
    release = read(CHILD/'payload_release_receipt.json')
    assert release['original_evidence_rewritten'] is False and release['launch_relationship_valid'] is True
    for value in [release['retained_envelope'], *release['verified_artifacts'].values()]: assert bind(value['path']) == value
    assert bind(CHILD/'worker_report.json')['raw_sha256'] == REPORT_SHA
    execution = read(CHILD/'passive_entry_replay/execution.json')
    assert execution['returncode'] == 0 and execution['timed_out'] is False and execution['input_raw_sha256'] == REPORT_SHA
    marker = 'DEVELOPMENT_RECOVERY_CANDIDATE_REPLAY '
    receipts = [json.loads(line[len(marker):]) for line in (CHILD/'passive_entry_replay/stdout.txt').read_text().splitlines() if line.startswith(marker)]
    assert len(receipts) == 1 and receipts[0]['ok'] is True and receipts[0]['controller_and_diagnostic_replay_passed'] is True
    assert receipts[0]['transition_count'] == 1113 and receipts[0]['partial_observation_count'] == 601
    report = streams.small_fields(CHILD/'worker_report.json')
    assert report['world_build_count'] == report['world_attempt_count'] == report['external_kick_application_count'] == 1
    assert report['solver_step_count'] == 1113 and report['coverage_complete'] is False
    assert report['held_out_cell_access_count'] == 0 and report['finite_recovery_task']['planned_cycle_count'] == 0
    return dict(complete_declared_safety_gate_passed=True, safety_stages=65, safety_tests=240,
        seed=65248, reported_worlds=1, reported_solver_steps=1113, reported_kicks=1,
        native_replay_passed=True, final_python_consumer_passed=False, final_audit_started=False,
        failure_cause='Production consume_replay imports ROUTE from the AG identity module, which has no such export.',
        coverage_gap='Complete-report tests call native replay and independent contact replay directly. They do not execute the remaining production consume_replay branches; workflow tests double that transport.',
        retained_diagnostic=retained_diagnostic())


def audit(record):
    assert record['source_commit'] == HEAD and record['claim_boundary'] == CLAIMS
    for item in [record['auditor'], *record['bindings']]: assert bind(item['path']) == item, item['path']
    frozen_sources()
    assert record['observed'] == observed()
    return dict(ok=True, **{k:v for k,v in record['observed'].items() if k != 'retained_diagnostic'}, **CLAIMS)


def create():
    assert not RECORD.exists()
    frozen_sources(); observation = observed()
    paths = [p for root in (RUN, OUTER, SOURCE_BYTES) for p in sorted(root.rglob('*')) if p.is_file()]
    paths += [TOKEN, KEY, CONTRACT]
    record = dict(schema_version='sporespore_r10ag_replay_invalid_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='consumed_post_world_infrastructure_invalid_closure', question_class='development'),
        source_commit=HEAD, original_run=RUN.as_posix(), auditor=bind(__file__),
        bindings=[bind(p) for p in paths], observed=observation, claim_boundary=CLAIMS,
        next_action='Repair shared production consumer route binding and exercise its complete real entrypoint on retained/synthetic reports in a separately labeled post-exposure component. Keep this attempt invalid. Diagnose support loss before selecting any behavioral successor; new physical work requires a distinct population and complete applicable gate.')
    result = audit(record); write_new(RECORD, record); return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true')
    args=parser.parse_args(); print(json.dumps(create() if args.create else audit(read(RECORD))))
