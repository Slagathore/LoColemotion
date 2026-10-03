"""Independent observation reader. No locomotion/recovery success is inferred."""
import json
import math
from pathlib import Path
import recovery_discovery as D

MARKER = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '


def vec(value):
    D.require(isinstance(value, list) and len(value) == 3 and all(type(v) in (int, float) and math.isfinite(v) for v in value), 'VECTOR')
    return value


def magnitude(value):
    return math.sqrt(sum(v*v for v in vec(value)))


def validate_report(report, declaration):
    D.require(report.get('schema_version') == 'sporespore_recovery_discovery_observation_v1' and report.get('ok') is True, 'REPORT_STATUS')
    D.require(all(report.get(k) is False for k in D.FLAGS + ('complete_route_proven', 'held_out')), 'REPORT_CLAIM')
    cell = declaration['discovery_cell']
    D.require(report['cell'] == cell and report['manifest'] == declaration['discovery_manifest'], 'REPORT_CELL')
    D.require(report['parent_attempt_id'] == declaration['attempt_id'] and report['child_attempt_id'] == declaration['children'][0]['child_attempt_id'], 'REPORT_IDENTITY')
    D.require(report['world_build_count'] == 1, 'WORLD_COUNT')
    event = report['disturbance']
    start = event['completed_prefix_step']
    D.require(31 < start <= 352 and start + cell['tail_steps'] == report['solver_step_count'] == report['global_solver_frame_count'] <= 592, 'STEP_BOUND')
    D.require(event['application_count'] == int(cell['impulse_ns'] > 0), 'IMPULSE_COUNT')
    D.require(abs(magnitude(event['impulse_world_ns']) - cell['impulse_ns']) < 1e-7, 'IMPULSE_MAGNITUDE')
    D.require(report['terminal_identity'].get('ok') is True, 'TERMINAL_IDENTITY')
    rows = report['tail_rows']
    D.require(len(rows) == cell['tail_steps'], 'TRUNCATED_TAIL')
    baseline = event['baseline']
    D.require(baseline['local_step'] == 0 and baseline['global_step'] == start, 'BASELINE_STEP')
    body_ids = [b['body_id'] for b in baseline['bodies']]
    instances = [b['instance_id'] for b in baseline['bodies']]
    D.require(len(body_ids) == len(set(body_ids)) == len(set(instances)) == 9, 'BODY_POPULATION')
    D.require('torso' in body_ids, 'TORSO')
    caps = {m['joint_id']: m['maximum_impulse'] for m in baseline['motors']}
    D.require(len(caps) == 8 and all(math.isfinite(c) and c > 0 for c in caps.values()), 'MOTOR_CAPS')
    torsos = []
    for n, row in enumerate([baseline] + rows):
        D.require(row['ok'] is True and row['local_step'] == n and row['global_step'] == start+n, 'ROW_SEQUENCE')
        D.require([b['body_id'] for b in row['bodies']] == body_ids and [b['instance_id'] for b in row['bodies']] == instances, 'BODY_IDENTITY_DRIFT')
        for body in row['bodies']:
            D.require(body['callback_sequence'] == start+n, 'CALLBACK_SEQUENCE')
            for pose in (body['pose'], body['callback_pose']):
                vec(pose['origin'])
                D.require(len(pose['basis_columns']) == 3, 'POSE_BASIS')
                for column in pose['basis_columns']: vec(column)
            magnitude(body['linear_velocity']); magnitude(body['angular_velocity'])
            D.require(math.isfinite(body['up_dot']) and abs(body['up_dot']) <= 1.001, 'UP_DOT')
            if body['body_id'] == 'torso': torsos.append(body)
        D.require({m['joint_id']: m['maximum_impulse'] for m in row['motors']} == caps, 'MOTOR_CAP_DRIFT')
        if n:
            D.require(all(m['enabled'] is (cell['actuation'] == 'zero_velocity_brake') and m['target_velocity'] == 0 for m in row['motors']), 'MOTOR_COMMAND')
        contacts = row['contacts']
        D.require(contacts['capture_space_step_sequence'] == contacts['read_space_step_sequence'] == start+n, 'CONTACT_CLOCK')
        D.require(contacts['complete'] is True and contacts['reported_point_count'] == len(contacts['points']), 'CONTACT_COMPLETE')
    return dict(cell=cell, valid=True, solver_steps=report['solver_step_count'],
                initial_height_m=torsos[0]['pose']['origin'][1], terminal_height_m=torsos[-1]['pose']['origin'][1],
                height_change_m=torsos[-1]['pose']['origin'][1]-torsos[0]['pose']['origin'][1],
                minimum_up_dot=min(t['up_dot'] for t in torsos), terminal_up_dot=torsos[-1]['up_dot'],
                terminal_speed_m_s=magnitude(torsos[-1]['linear_velocity']),
                terminal_angular_speed_rad_s=magnitude(torsos[-1]['angular_velocity']),
                physical_acceptance_authority=False, release_authority=False)


def audit_batch(folder, cell_id=None):
    folder = Path(folder)
    summaries = []
    invalid = False
    for row in D.read(folder / 'cells.json'):
        if cell_id is not None and row['cell']['cell_id'] != cell_id: continue
        cell_folder = Path(row['folder'])
        value = D.read(cell_folder / 'declaration.json')
        child = Path(value['children'][0]['evidence_path'])
        if not (child / 'process.json').exists(): continue
        if (child / 'discovery-audit.json').exists():
            summary = D.read(child / 'discovery-audit.json')
        else:
            try:
                D.require(D.read(child / 'relationship-audit.json')['ok'] is True, 'PROCESS_RELATIONSHIP')
                D.require((child / 'stderr.log').read_bytes() == b'', 'STDERR')
                D.require((child / 'world-claim.json').exists(), 'WORLD_CLAIM')
                candidates = []
                with (child / 'stdout.log').open(encoding='utf-8-sig') as stream:
                    for line in stream:
                        if line.startswith(MARKER): candidates.append(line[len(MARKER):])
                D.require(len(candidates) == 1, 'ONE_REPORT')
                with (child / 'worker-report.json').open('x', encoding='utf-8', newline='\n') as stream:
                    stream.write(candidates[0])
                report = json.loads(candidates[0])
                D.require(report['declaration_sha256'] == D.binding(cell_folder / 'declaration.json')['raw_sha256'], 'REPORT_DECLARATION')
                summary = validate_report(report, value)
                del candidates, report
                D.process(child, 'native-contact-replay', [value['runtime']['images']['godot_engine']['path'], '--headless', '--path', D.ROOT,
                    '--script', 'res://sdk/discovery/recovery_discovery_reader_v2.gd', '--', child / 'worker-report.json', child / 'contact-replay.json'])
                D.require(D.read(child / 'contact-replay.json')['ok'] is True, 'CONTACT_REPLAY')
                summary['report'] = D.binding(child / 'worker-report.json')
            except Exception as exc:
                summary = dict(cell=row['cell'], valid=False, failure=str(exc), physical_acceptance_authority=False, release_authority=False)
            D.write_new(child / 'discovery-audit.json', summary)
        summaries.append(summary)
        invalid |= not summary['valid']
    path = folder / ('summary-' + D.uuid.uuid4().hex + '.json')
    D.write_new(path, dict(cells=summaries, valid_count=sum(s['valid'] for s in summaries), planned_count=len(D.read(folder / 'cells.json')),
                          physical_acceptance_authority=False, release_authority=False))
    print(json.dumps(dict(summary=path.as_posix(), completed=len(summaries), valid=sum(s['valid'] for s in summaries))))
    D.require(not invalid, 'INVALID_CELL_RETAINED')
