"""Independent R10DH identity, full contact/controller replay and finite task audit."""
import json
import os
from pathlib import Path
import sys
import types
import r10dh_contract as C
import r10dh_dependency_manifest as M
from r10dh_dependency_manifest import D
import r10dh_measurement as Measurements
import qsdk_r10f_l15_launch_relationship as Launch
sys.path.insert(0, str(C.ROOT/'sdk/python'))
import recovery_panel_contacts as Contacts
from sporespore_locomotion import LocomotionCore

FILE_MARKER = 'R10DH_FULL_REPORT_FILE '


def retain_report(child, declaration):
    lines = (child/'stdout.log').read_text(encoding='utf-8-sig').splitlines()
    publications = [C.parse(line[len(FILE_MARKER):]) for line in lines if line.startswith(FILE_MARKER)]
    C.require(len(publications) == 1 and not any(line.startswith('SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW ') for line in lines), 'ONE_PUBLICATION')
    v = publications[0]; path = child/'worker-streamed-report.json'
    expected = dict(ok=True, telemetry_reduced=False, physical_acceptance_authority=False, release_authority=False,
        transport_id='godot_4_7_sorted_full_precision_authoritative_json_v1',
        parent_attempt_id=declaration['attempt_id'], child_attempt_id=declaration['children'][0]['child_attempt_id'])
    C.require(all(C.same(v.get(k), value) for k, value in expected.items()), 'PUBLICATION_CONTEXT')
    C.require({k: v.get(k) for k in ('path', 'byte_length', 'raw_sha256')} == D.binding(path)
        and not Path(str(path)+'.partial').exists(), 'PUBLICATION_BYTES')
    with path.open('r+b') as stream: stream.flush(); os.fsync(stream.fileno())
    return path


def validate_report_header(report, declaration):
    child = declaration['children'][0]; context = declaration['r10dh_campaign']
    cells = [r for r in C.population(context['mode']) if r['cell_id'] == context['cell_id']]
    C.require(len(cells) == 1 and C.same(context['seed'], cells[0]['seed']) and context['role'] == cells[0]['role'], 'REPORT_POPULATION')
    expected = dict(ok=True, parent_attempt_id=declaration['attempt_id'], child_attempt_id=child['child_attempt_id'],
        arm_id=child['role'], source_commit=declaration['source_snapshot']['head'], seed=declaration['seed'],
        seed_label=context['seed']['label'], seed_sha256=context['seed']['sha256'],
        held_out=context['mode'] == 'held_out', held_out_cell_access_count=int(context['mode'] == 'held_out'),
        world_build_count=1, r10dh_campaign=context, complete_route_proven=False,
        diagnostic_declaration_sha256=D.binding(Path(child['evidence_path']).parents[1]/'declaration.json')['raw_sha256'])
    expected.update(dict.fromkeys(C.FLAGS, False))
    C.require(all(C.same(report.get(k), v) for k, v in expected.items()), 'REPORT_IDENTITY')
    C.require(type(report['solver_step_count']) is int and 0 < report['solver_step_count'] <= cells[0]['maximum_solver_steps']
              and report['global_solver_frame_count'] == report['solver_step_count'], 'REPORT_BOUNDS')
    prefix = [s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_prefix']
    C.require(len(prefix) == 1 and C.same(prefix[0]['start_receipt']['initial_gait_steps'],
        dict.fromkeys(('front_left', 'front_right', 'rear_left', 'rear_right'), context['seed']['prefix_phase'])), 'REPORT_PREFIX')
    C.require(report['terminal_same_body_identity_receipt']['ok'] is True, 'REPORT_TERMINAL_IDENTITY')


def body_prefix(report, role):
    arm = report['retained_arm']; count = report['solver_step_count']
    invariants = arm['invariant_receipts']; trace = arm['trace_rows']
    C.require(len(invariants) == len(trace) == count, 'INVARIANT_POPULATION')
    for step, (sample, invariant) in enumerate(zip(trace, invariants), 1):
        C.require(sample['global_semantic_step'] == invariant['global_semantic_step'] == step
            and sample['arm_id'] == invariant['arm_id'] == role
            and invariant['body_population_instance_sha256'] == arm['body_population_instance_sha256'], 'INVARIANT_IDENTITY')
        C.require(invariant['all_in_run_physical_invariants_passed'] is True and invariant['predicates']
            and all(v is True for v in invariant['predicates'].values()), 'PHYSICAL_INVARIANT')
    C.require(all(C.same(arm[k], 0) for k in ('body_population_rebuild_count', 'body_transform_write_count',
        'body_velocity_write_count', 'solver_reset_count')), 'BODY_MUTATION')
    C.require(arm['active_walking_session'] == {} and arm['last_walking_evaluation_failure'] == {}, 'UNCLOSED_WALKING')
    interaction = [i for i, sample in enumerate(trace) if sample['orchestrator_phase'] == 'native_kick_or_matched_no_kick_step']
    C.require(len(interaction) == 1 and interaction[0] > 0, 'INTERACTION_POPULATION')
    states = [frame['packet']['direct_state_source']['ordered_body_states']
              for frame in report['r10af_contact_frames']['records'][:interaction[0]]]
    C.require(all(len(s) == 9 for s in states), 'PREFIX_BODY_POPULATION')
    prefix = dict(frames=interaction[0], state_sha256=C.sha(json.dumps(states, sort_keys=True, separators=(',', ':')).encode()))
    return prefix


def audit_cell(row, *, native=True):
    folder = Path(row['folder']); declaration = C.read(folder/'declaration.json')
    D.verify_binding(row['declaration'])
    import r10dh_campaign as Campaign
    Campaign.validate_cell(folder/'declaration.json', True)
    child = Path(declaration['children'][0]['evidence_path'])
    C.require(C.read(child/'relationship-audit.json')['ok'] is True and (child/'stderr.log').read_bytes() == b'', 'ORIGINAL_PROCESS')
    envelope = C.read(child/'process.json')
    expected_context = dict(schema_version=Launch.PROCESS['context_schema'], parent_attempt_id=declaration['attempt_id'],
        child_attempt_id=declaration['children'][0]['child_attempt_id'], role=row['cell']['role'],
        source_commit=declaration['source_snapshot']['head'], authority_sha256=D.binding(folder/'declaration.json')['raw_sha256'],
        termination_nonce=declaration['children'][0]['termination_nonce'], ready_marker_prefix=Launch.PROCESS['ready_marker_prefix'],
        root_image=declaration['runtime']['images']['godot_console'], worker_image=declaration['runtime']['images']['godot_engine'])
    Launch.validate_child_launch(envelope, expected_context)
    C.require(envelope['exit_code'] == 0 and envelope['timed_out'] is False and envelope['termination_protocol_valid'] is True,
              'ORIGINAL_TERMINATION')
    claim = C.read(child/'world-claim.json')
    C.require(claim['declaration'] == D.binding(folder/'declaration.json') and claim['world_build_limit'] == 1, 'ORIGINAL_WORLD_CLAIM')
    path = retain_report(child, declaration); report = C.read(path)
    validate_report_header(report, declaration)
    C.require(report['process_id'] == envelope['worker_process_id'] == claim['worker_identity']['pid']
              and 'synthetic_test_fixture' not in report, 'PHYSICAL_REPORT_PROCESS')
    count = report['solver_step_count']
    prefix = body_prefix(report, row['cell']['role'])
    contacts = Contacts.replay_report(report, declaration, types.SimpleNamespace(validate_report_header=validate_report_header))
    core = LocomotionCore(declaration['runtime']['images']['candidate_dll']['path'])
    measurement = Measurements.measure(report, core.compile_bounded_quadruped(report['configuration']['base_descriptor']))
    del report, core
    if native:
        D.process(child, 'full-native-replay', [declaration['runtime']['images']['godot_engine']['path'], '--headless',
            '--path', C.ROOT, '--script', 'res://sdk/adapters/godot/gdscript/r10dh_campaign_reader_v1.gd',
            '--', 'physical', folder/'declaration.json', path, child/'full-native-replay.json'], timeout=1200)
    replay = C.read(child/'full-native-replay.json')
    C.require(replay['ok'] is True and replay['test_only'] is False and replay['world_build_count'] == replay['solver_step_count'] == 0, 'NATIVE_REPLAY')
    C.require(replay['input_raw_sha256'] == D.binding(path)['raw_sha256']
        and replay['contact_replay']['diagnostic_steps_replayed'] == contacts['diagnostic_steps_replayed'] == count, 'REPLAY_POPULATION')
    return dict(cell=row['cell'], valid=True, solver_steps=count, measurement=measurement,
        prefix=prefix, started_utc=envelope['started_utc'], completed_utc=envelope['completed_utc'],
        contact_replay=contacts, report=D.binding(path), native_replay=D.binding(child/'full-native-replay.json'),
        physical_acceptance_authority=False, release_authority=False)


def run_cell_audit(batch, cell_id):
    rows = [r for r in C.read(Path(batch)/'cells.json') if r['cell']['cell_id'] == cell_id]
    C.require(len(rows) == 1, 'AUDIT_CELL')
    row = rows[0]; child = Path(row['folder'])/'children'/row['cell']['role']
    try: result = audit_cell(row)
    except Exception as error:
        result = dict(cell=row['cell'], valid=False, failure=str(error), physical_acceptance_authority=False, release_authority=False)
    D.write_new(child/'campaign-audit.json', result)
    C.require(result['valid'], 'INVALID_CELL_RETAINED')


if __name__ == '__main__': run_cell_audit(sys.argv[1], sys.argv[2])
