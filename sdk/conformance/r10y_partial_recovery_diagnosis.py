"""Describe original R10V/R10X partial trajectories without regrading or physics.

The original report hashes authorize the fixed-format streaming reader. Each
native step is counted once; the redundant call.value copy is checked, not
counted. This keeps the 600 MB reports out of a multi-gigabyte Python DOM.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RECORD = ROOT / 'sdk/recovery/r10y_partial_recovery_diagnosis_v1.json'
KICK = 'kick_passive_recovery_resume'
SOURCES = ('3e6eeba85e8b424c9efd3e791e3689013b89505b',
           'fdf5ceca8bed978bc3781a13f7c3e690b2ea67e6')
CLOSURES = (
    ('sdk/recovery/r10v_development_population_closure_v1.json',
     'sha256:f774fbe7e3ce03dab27fc2736c86bf0cb0d837d5aa7c45f1f4f5c9f48177bf04'),
    ('sdk/recovery/r10x_held_out_physical_closure_v1.json',
     'sha256:bcf757a42a673a2fc800abf6e535f6117026e8baa7412a122e0a27a6add5eebd'))
CORE_PATHS = ('sdk/core/src/recovery/partial_fall.rs',
              'sdk/core/src/recovery_runtime/partial_fall_control.rs',
              'sdk/core/src/recovery_runtime.rs')


def require(value, code):
    if not value:
        raise ValueError('R10Y_DIAGNOSIS_' + code)


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def binding(path):
    with path.open('rb') as stream:
        sha = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=sha)


def checked_json(path, sha):
    raw = path.read_bytes()
    require(digest(raw) == sha, 'BOUND_JSON_BYTES')
    return json.loads(raw)


def read_partial(path):
    """Yield metadata and packets from the hash-bound, two-space JSON layout."""
    found = False
    closed = False
    with path.open(encoding='utf-8') as stream:
        for line in stream:
            if line.startswith('  "r10v_partial_recovery": {'):
                require(not found, 'DUPLICATE_PARTIAL_SECTION')
                found = True
                for line in stream:
                    if line.startswith('    "step_packets": ['):
                        require(line.rstrip().endswith('['), 'EMPTY_PARTIAL_POPULATION')
                        packet_lines = []
                        for line in stream:
                            if line.startswith('    ]'):
                                require(not packet_lines, 'UNTERMINATED_PACKET')
                                break
                            packet_lines.append(line)
                            if line.startswith('      }'):
                                yield 'packet', json.loads(''.join(packet_lines).rstrip().removesuffix(','))
                                packet_lines = []
                        else:
                            require(False, 'UNTERMINATED_PACKETS')
                    elif line.startswith(('    "declaration": {', '    "final_memory": {')):
                        key = line.split('"')[1]
                        lines = ['{\n']
                        for line in stream:
                            lines.append(line)
                            if line.startswith('    }'):
                                break
                        yield key, json.loads(''.join(lines).rstrip().removesuffix(','))
                    elif line.startswith('  }'):
                        closed = True
                        break
            elif line.startswith('  "') and not line.startswith('   '):
                # Only scalar top-level identity fields; nested sections are skipped.
                key = line.split('"')[1]
                if key in ('source_commit', 'seed', 'arm_id', 'child_attempt_id', 'solver_step_count', 'held_out'):
                    yield key, json.loads('{' + line.rstrip().removesuffix(',') + '}')[key]
    require(found and closed, 'PARTIAL_SECTION_MISSING_OR_UNTERMINATED')


def snapshot(packet):
    receipt = packet['native_receipt']
    step = receipt['step']
    observation = receipt['collection']['observation']
    state = observation['state']
    q = state['base_pose_world']['orientation_xyzw']
    # The world-Y components of local forward, up and lateral axes. This avoids
    # ambiguous Euler-angle names for the project's X-forward/Y-up convention.
    axes = [2 * (q['x'] * q['y'] + q['z'] * q['w']),
            1 - 2 * (q['x'] ** 2 + q['z'] ** 2),
            2 * (q['y'] * q['z'] - q['x'] * q['w'])]
    require(math.isclose(axes[1], step['classification']['torso_up_dot'], abs_tol=1e-12), 'UP_AXIS_DISAGREES')
    joints = state['ordered_joint_observations']
    control = receipt['next_control']
    return dict(semantic_step=observation['semantic_step'],
        partial_step=step['memory']['total_steps_observed'],
        prior_phase=step['prior_phase'], next_phase=step['next_phase'],
        prior_phase_step=packet['prior_memory']['phase_steps_observed'],
        classification=step['classification'],
        local_axes_world_y=axes, orientation_xyzw=q,
        joint_positions_rad=[j['position_rad'] for j in joints],
        joint_velocities_rad_s=[j['velocity_rad_s'] for j in joints],
        foot_bearing=[c['bears_support'] for c in state['ordered_contact_observations']],
        applied_target_velocities_rad_s=[c['canonical_target_velocity_rad_s'] for c in packet['source_application']['ordered_intents']],
        next_control=None if control is None else dict(controller_id=control['controller_id'],
            profile_sha256=control['controller_profile_sha256'], phase=control['phase'],
            phase_step=control['phase_step'],
            target_positions_rad=[c['target_position_rad'] for c in control['ordered_commands']]))


def summarize(path, expected, sha, source):
    require(path.resolve().is_relative_to(EVIDENCE.resolve()), 'REPORT_LOCATION')
    bound = binding(path)
    require(bound['raw_sha256'] == sha, 'ORIGINAL_REPORT_BYTES')
    metadata, rows, controls = {}, [], set()
    previous = None
    for kind, value in read_partial(path):
        if kind != 'packet':
            require(kind not in metadata, 'DUPLICATE_METADATA')
            metadata[kind] = value
            continue
        require(value['ok'] is True and value['call']['value'] == value['native_receipt'], 'ORIGINAL_NATIVE_COPY')
        native = value['native_receipt']
        require(native['step']['prior_phase'] == value['prior_memory']['phase'], 'PRIOR_PHASE')
        if previous is not None:
            require(value['prior_memory'] == previous, 'MEMORY_CHAIN')
        row = snapshot(value)
        require(row['partial_step'] == len(rows) + 1, 'PARTIAL_CLOCK')
        require(row['semantic_step'] == 513 + len(rows), 'GLOBAL_CLOCK')
        require(value['source_attempt_id'] == expected['child_attempt_id'], 'PACKET_ATTEMPT')
        control = row['next_control']
        if control is not None:
            controls.add((control['controller_id'], control['profile_sha256']))
        rows.append(row)
        previous = native['step']['memory']
    require(rows and metadata['final_memory'] == previous, 'FINAL_MEMORY')
    require(metadata['source_commit'] == source and metadata['seed'] == expected['seed']
        and metadata['arm_id'] == KICK and metadata['child_attempt_id'] == expected['child_attempt_id']
        and metadata['solver_step_count'] == expected['solver_steps'], 'ORIGINAL_IDENTITY')
    fields = ('torso_height_ratio', 'torso_up_dot', 'center_of_mass_height_gain_m',
              'minimum_nonfoot_clearance_m', 'maximum_nonfoot_contact_impulse_ns',
              'terminal_linear_speed_m_s', 'terminal_angular_speed_rad_s')
    gates = ('distal_support_gate', 'raised_body_gate', 'safety_gate', 'stable_stance_gate',
             'any_nonfoot_contact', 'joint_limits_respected', 'actuator_budget_respected')
    require(all(type(r['classification'][f]) in (int, float) and math.isfinite(r['classification'][f])
                for r in rows for f in fields), 'NONFINITE_CLASSIFICATION')
    require(all(type(r['classification'][g]) is bool for r in rows for g in gates), 'BOOLEAN_GATE')
    phases = []
    for phase in dict.fromkeys(r['prior_phase'] for r in rows):
        selected = [r for r in rows if r['prior_phase'] == phase]
        phases.append(dict(phase=phase, count=len(selected), first=selected[0]['semantic_step'],
            last=selected[-1]['semantic_step'],
            ranges={f: [min(r['classification'][f] for r in selected), max(r['classification'][f] for r in selected)] for f in fields},
            gate_counts={g: sum(r['classification'][g] for r in selected) for g in gates}))
    events = dict(first_up_dot_below_half=next((r['partial_step'] for r in rows if r['classification']['torso_up_dot'] < .5), None),
        first_raised_body=next((r['partial_step'] for r in rows if r['classification']['raised_body_gate']), None),
        first_clear_of_nonfoot_contact=next((r['partial_step'] for r in rows if not r['classification']['any_nonfoot_contact']), None),
        first_all_knees_negative=next((r['partial_step'] for r in rows if all(x < 0 for x in r['joint_positions_rad'][1::2])), None))
    indices = {0, len(rows)-1}
    indices.update(i for i,r in enumerate(rows) if r['prior_phase'] != r['next_phase']
                   or r['partial_step'] % 30 == 0)
    indices.update(x - 1 for x in events.values() if x is not None)
    initial = metadata['declaration']['entry_request']['passive_request']['observation']
    return dict(seed=expected['seed'], original_outcome=expected.get('outcome', 'positive'),
        report=bound, source_commit=source, child_attempt_id=expected['child_attempt_id'],
        original_solver_steps=expected['solver_steps'], partial_steps=len(rows),
        original_final_memory=metadata['final_memory'],
        entry_joint_positions_rad=[j['position_rad'] for j in initial['state']['ordered_joint_observations']],
        entry_orientation_xyzw=initial['state']['base_pose_world']['orientation_xyzw'],
        actual_control_profiles=[dict(controller_id=c, raw_sha256=s) for c,s in sorted(controls)],
        phase_summary=phases, events=events, snapshots=[rows[i] for i in sorted(indices)])


def reconstruct():
    require(Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True).strip()).resolve() == ROOT, 'ROOT')
    require(subprocess.check_output(['git', 'remote', 'get-url', 'origin'], cwd=ROOT, text=True).strip()
            == 'https://github.com/Slagathore/sporespore.git', 'REMOTE')
    positive, negative = [checked_json(ROOT / p, s) for p,s in CLOSURES]
    require(positive['source_commit'] == SOURCES[0] and negative['source_commit'] == SOURCES[1], 'SOURCES')
    audit = negative['independent_audit']
    require(audit['execution_valid'] is True and audit['outcome'] == 'negative'
            and negative['population_consumed'] is True and audit['total_solver_steps'] == 8012, 'NEGATIVE_CLOSURE')
    manifest = positive['evidence_manifest']
    files = checked_json(Path(manifest['path']), manifest['raw_sha256'])['files']
    positive_run = next(r for r in positive['observed']['runs'] if r['seed'] == 41341)
    positive_cell = next(c for c in positive_run['cells'] if c['role'] == KICK)
    require(positive_cell['all_tasks_positive'] is True and positive_cell['entry_kind'] == 'partial', 'POSITIVE_CLOSURE')
    path = Path(positive_run['evidence_root']) / 'children' / KICK / 'worker_report.json'
    bound = next(f for f in files if Path(f['path']) == path)
    observations = [summarize(path, positive_cell, bound['raw_sha256'], SOURCES[0])]
    claim_path = Path(negative['evidence_root']) / 'campaign_claim.json'
    claim = checked_json(claim_path, audit['campaign_claim_sha256'])
    children = {c['cell_id']: c for c in claim['children']}
    cells = [c for c in audit['cells'] if c['role'] == KICK]
    require([c['seed'] for c in cells] == [51007, 51008, 51009]
            and all(c['outcome'] == 'negative' and c['execution_valid'] for c in cells), 'NEGATIVE_POPULATION')
    for cell in cells:
        path = Path(children[cell['cell_id']]['evidence_path']) / 'worker_report.json'
        observations.append(summarize(path, cell, cell['original_report_sha256'], SOURCES[1]))
    sources = []
    for path in CORE_PATHS:
        blobs = [subprocess.check_output(['git', 'show', source + ':' + path], cwd=ROOT) for source in SOURCES]
        require(blobs[0] == blobs[1], 'PARTIAL_CONTROL_SOURCE_CHANGED')
        sources.append(dict(path=path, source_commits=list(SOURCES), byte_length=len(blobs[0]), raw_sha256=digest(blobs[0])))
    return dict(schema_version='sporespore_r10y_partial_recovery_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_diagnosis', question_class='development'),
        original_closures=[dict(path=p, raw_sha256=s) for p,s in CLOSURES],
        positive_retention_manifest=manifest, identical_original_core_sources=sources,
        observations=observations, original_results_regraded=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    result = reconstruct()
    if args.verify:
        require(json.loads(RECORD.read_text(encoding='utf-8')) == result, 'RECONSTRUCTION')
        print(json.dumps(dict(ok=True, cells=4, world_build_count=0, original_results_regraded=False)))
    else:
        print(json.dumps(result, indent=2, allow_nan=False))
