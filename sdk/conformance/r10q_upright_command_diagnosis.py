"""Compare existing native rise laws on exposed inputs and ideal tracking only.

The fixture-shaped requests are synthetic. Retained joint readings are copied
into them explicitly; no alternate physical trajectory is asserted or replayed.
"""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
sys.path.insert(0, str(ROOT / 'sdk/python'))
from sporespore_locomotion import LocomotionCore

RUNTIME = ROOT / 'sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.runtime.json'
CLOSURE = ROOT / 'sdk/recovery/r10q_phase246_development_pair_closure_v1.json'
P_DIAGNOSIS = ROOT / 'sdk/recovery/r10p_entry_domain_diagnosis_v1.json'
FIXTURE = EVIDENCE / 'development-candidate-build-bea09596be3f4184bd5df530217c826b/fixtures.stdout.log'
FIXTURE_SHA = 'sha256:fe93775b4f188f797fac6756d54449bd960ba914feeb26995f82415e8114ffdf'
CLOCKS = [0, 59, 119, 120, 239, 240, 359, 360, 599]
CONTROLLERS = ['sporespore_exact_s169_prone_to_standing_controller_v20',
               'sporespore_exact_s169_prone_to_standing_controller_v12']


def read(path):
    return json.loads(Path(path).read_bytes())


def bind(path):
    path = Path(path)
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=digest)


def write(path, data):
    with Path(path).open('xb') as stream:
        stream.write((json.dumps(data, indent=2, allow_nan=False) + '\n').encode())


def inputs():
    closure = read(CLOSURE)
    qpath = Path(closure['evidence_root']) / 'children/kick_passive_recovery_resume/worker_report.json'
    qbinding = next(b for b in closure['retained_evidence'] if b['path'] == qpath.as_posix())
    assert bind(qpath) == qbinding
    report = read(qpath)
    observation = report['r10q_upright_recovery']['declaration']['entry_request']['original_request']['passive_request']['observation']
    result = [dict(id='r10q_upright_phase246', report=qbinding, semantic_step=512, state=observation['state'])]
    del report
    for cell in read(P_DIAGNOSIS)['negative_cells']:
        if cell['role'] != 'kick_passive_recovery_resume':
            continue
        binding = cell['report']
        assert bind(binding['path']) == binding
        report = read(binding['path'])
        observation = report['passive_entry']['entry_packets'][-1]['native_receipt']['collection']['collection']['observation']
        assert observation['semantic_step'] == 512
        result.append(dict(id='r10p_upright_phase'+str(cell['seed'] % 360), report=binding,
                           semantic_step=512, state=observation['state']))
        del report
    assert [p['id'] for p in result] == ['r10q_upright_phase246', 'r10p_upright_phase245', 'r10p_upright_phase246']
    return result


def request(fixture, source, controller, clock):
    q = copy.deepcopy(fixture['request'])
    q['controller_id'] = controller
    q['phase_step'] = clock
    q['collection']['observation']['controller_ownership']['recovery_controller_id'] = controller
    state = q['collection']['observation']['state']
    state['ordered_joint_observations'] = copy.deepcopy(source['state']['ordered_joint_observations'])
    state['base_pose_world']['orientation_xyzw'] = copy.deepcopy(source['state']['base_pose_world']['orientation_xyzw'])
    assert q['collection']['phase'] == 'raise_body'
    return q


def run():
    assert Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True).strip()).resolve() == ROOT
    assert subprocess.check_output(['git', 'remote', 'get-url', 'origin'], cwd=ROOT, text=True).strip() == 'https://github.com/Slagathore/sporespore.git'
    runtime = read(RUNTIME)
    dll = Path(runtime['runtime']['path'])
    if not dll.is_absolute():
        dll = ROOT / dll
    assert bind(dll)['raw_sha256'] == runtime['runtime']['raw_sha256']
    for source in runtime['source_files']:
        assert bind(ROOT / source['path'])['raw_sha256'] == source['raw_sha256']
    assert bind(FIXTURE)['raw_sha256'] == FIXTURE_SHA
    fixtures = [json.loads(line.partition(' ')[2]) for line in FIXTURE.read_text().splitlines()
                if line.startswith('CANDIDATE_RECOVERY_CONTROL_FIXTURE ')]
    fixtures = [f for f in fixtures if f['request']['collection']['phase'] == 'raise_body']
    assert len(fixtures) == 3
    population = inputs()
    directory = EVIDENCE / ('r10q-upright-command-diagnosis-' + uuid.uuid4().hex)
    directory.mkdir()
    sources = [bind(ROOT / p) for p in [Path(__file__).relative_to(ROOT),
        'sdk/core/src/recovery_runtime.rs', 'sdk/core/src/recovery/upright_recovery.rs',
        'sdk/core/src/joint_pose_entry.rs']]
    declaration = dict(schema_version='sporespore_r10q_upright_command_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='3e_native_command_inputs_only',
                          authority_mode='post_exposure_command_diagnosis', question_class='development'),
        runtime=bind(RUNTIME), dll=bind(dll), fixture=bind(FIXTURE), sources=sources,
        predecessor_closures=[bind(CLOSURE), bind(P_DIAGNOSIS)], population=population,
        fixed_input_clocks=CLOCKS, controllers=CONTROLLERS, ideal_tracking_commands=360,
        fixed_input_calls=162, ideal_tracking_calls=2160,
        copied_fields=['ordered_joint_observations', 'base_pose_world.orientation_xyzw'],
        original_observations_rewritten=False, synthetic_fixture_context=True,
        ideal_tracking_is_simulated_physics=False, physical_response_predicted=False,
        physical_world_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)
    write(directory / 'declaration.json', declaration)
    print('R10Q_COMMAND_DIAGNOSIS_ROOT', directory, flush=True)
    core = LocomotionCore(dll)
    calls = 0
    summaries = []
    with (directory / 'native_calls.jsonl').open('xb') as trace:
        def call(q, label):
            nonlocal calls
            result = core.recovery_plan_control_v1(q)
            trace.write((json.dumps(dict(label=label, request=q, response=result), separators=(',', ':'), allow_nan=False) + '\n').encode())
            trace.flush()
            calls += 1
            assert result['support_status'] == 'supported_exact' and len(result['ordered_commands']) == 8
            assert result['world_build_count'] == result['solver_step_count'] == 0
            return result
        for source in population:
            for controller in CONTROLLERS:
                fixed = []
                for clock in CLOCKS:
                    commands = []
                    for fixture in fixtures:
                        q = request(fixture, source, controller, clock)
                        out = call(q, dict(population=source['id'], mode='fixed_input', controller=controller,
                                           clock=clock, adapter=q['collection']['adapter_capability']['adapter_id']))
                        commands.append(out['ordered_commands'])
                    assert commands[0] == commands[1] == commands[2]
                    fixed.append(dict(clock=clock, targets=[c['target_position_rad'] for c in commands[0]]))
                q = request(fixtures[0], source, controller, 0)
                initial = [j['position_rad'] for j in q['collection']['observation']['state']['ordered_joint_observations']]
                crossings = set()
                peak_speed = 0.0
                for clock in range(360):
                    q['phase_step'] = clock
                    out = call(q, dict(population=source['id'], mode='ideal_joint_tracking', controller=controller, clock=clock))
                    for i, (joint, command) in enumerate(zip(q['collection']['observation']['state']['ordered_joint_observations'], out['ordered_commands'], strict=True)):
                        before, target = joint['position_rad'], command['target_position_rad']
                        speed = (target - before) * 120
                        assert abs(speed) <= command['maximum_target_speed_rad_s'] + 1e-9
                        peak_speed = max(peak_speed, abs(speed))
                        if initial[i] * target < -1e-10:
                            crossings.add(joint['joint_id'])
                        joint['position_rad'] = target
                        joint['velocity_rad_s'] = speed
                terminal = [j['position_rad'] for j in q['collection']['observation']['state']['ordered_joint_observations']]
                assert max(map(abs, terminal)) < 1e-10
                if controller.endswith('_v12'):
                    assert not crossings
                summaries.append(dict(population=source['id'], controller=controller, fixed_input=fixed,
                    ideal_tracking_sign_crossings=sorted(crossings), ideal_tracking_peak_requested_speed_rad_s=peak_speed,
                    ideal_tracking_terminal_positions_rad=terminal))
                print('R10Q_COMMAND_CASE', source['id'], controller, 'calls', calls, flush=True)
    assert calls == 2322
    assert sources == [bind(item['path']) for item in sources]
    write(directory / 'result.json', dict(ok=True, native_calls=calls, cases=summaries,
        native_calls_binding=bind(directory / 'native_calls.jsonl'), source_after=sources,
        physical_world_count=0, solver_step_count=0, physical_response_predicted=False))
    print('R10Q_COMMAND_DIAGNOSIS_COMPLETE', directory, calls, flush=True)


if __name__ == '__main__':
    run()
