"""Post-exit R10DF closure: preserve all attempts and qualify the changed key."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile
import r10df_worker_component as component

C = component.C
RECORD = component.RECORD


def verified_run(folder):
    assert C.read(folder / 'execution.json') == dict(ok=True, source_unchanged=True)
    assert C.read(folder / 'host-execution.json')['exit_code'] == 0
    before = C.read(folder / 'bindings-before.json')
    assert before == C.read(folder / 'bindings-after.json') == [C.bind(p) for p in component.dependencies()]
    result = C.read(folder / 'result.json')
    assert result['ok'] and len(result['stages']) == 3
    for index, stage in enumerate(result['stages']):
        run = C.read(folder / f'stage-{index}-execution.json')
        checks = C.read(folder / f'stage-{index}-result.json')
        assert run['return_code'] == 0 and not run['timed_out']
        assert checks['ok'] and all(checks['checks'].values())
        assert checks['world_build_count'] == checks['solver_step_count'] == 0
        assert stage == dict(script=component.SCRIPTS[index], checks_passed=len(checks['checks']))
        assert (folder / f'stage-{index}-stderr.txt').read_bytes() == b''
    worker = C.read(folder / 'stage-0-result.json')
    assert len([k for k in worker['checks'] if k.startswith('worker_')]) == 238
    assert len([k for k in worker['checks'] if k.startswith('motor_') and k[6:].isdigit()]) == 237
    assert worker['checks']['original_task_preserved'] and worker['checks']['no_walking_resume']
    packets = [json.loads(line) for line in (folder / 'stage-1-result.json.packets.jsonl').read_text().splitlines()]
    assert len(packets) == 238 and packets[-1]['action'] == 'stop' and packets[-1]['next_control'] is None
    assert packets[-1]['task_memory']['phase'] == 'raise_body'
    with zipfile.ZipFile(folder / 'source.zip') as archive:
        for binding in before:
            data = archive.read(Path(binding['path']).relative_to(C.ROOT).as_posix())
            assert len(data) == binding['byte_length'] and 'sha256:' + hashlib.sha256(data).hexdigest() == binding['raw_sha256']
    return result


def close(folder, earlier):
    folder = Path(folder).resolve()
    assert folder.is_relative_to(C.EVIDENCE)
    result = verified_run(folder)
    attempts = []
    for name in earlier:
        path = Path(name).resolve()
        assert path.is_relative_to(C.EVIDENCE) and path != folder
        state = C.read(path / 'execution.json')
        assert state['source_unchanged']
        attempts.append(dict(execution_root=path.as_posix(), outcome=state,
            evidence=[C.bind(p) for p in sorted(path.iterdir()) if p.is_file()]))
    observed = dict(worker_partial_hooks_qualified=True, worker_observations_checked=238,
        real_motor_applications_on_uninserted_hinges=237, real_motor_writes=1896,
        stages=result['stages'], reference_packets_requalified_on_changed_key=True,
        old_v28_source_compatibility_verified=True, full_physical_worker_qualified=False,
        complete_report_reader_qualified=False, complete_safety_gate_qualified=False,
        physical_tracking_proven=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)
    C.write_new(RECORD, dict(schema_version='sporespore_r10df_worker_component_v1',
        ledger_scope=C.read(component.CONTRACT)['ledger_scope'], execution_root=folder.as_posix(),
        auditor=C.bind(Path(__file__)), contract=C.bind(component.CONTRACT),
        dependencies=C.read(folder / 'bindings-before.json'),
        evidence=[C.bind(p) for p in sorted(folder.iterdir()) if p.is_file()], earlier_attempts=attempts,
        prior_session_qualification='R10DE source.zip remains the historical authority; three shared source files changed prospectively and all session checks were freshly rerun.',
        observed=observed))
    return audit()


def audit():
    record = C.read(RECORD)
    for binding in [record['auditor'], record['contract'], *record['dependencies'], *record['evidence']]:
        component.previous.prior.verify(binding)
    for attempt in record['earlier_attempts']:
        for binding in attempt['evidence']: component.previous.prior.verify(binding)
        assert C.read(Path(attempt['execution_root']) / 'execution.json') == attempt['outcome']
    result = verified_run(Path(record['execution_root']))
    assert result['stages'] == record['observed']['stages']
    component.historical_session()
    return record['observed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--close')
    parser.add_argument('--earlier', nargs='*', default=[])
    args = parser.parse_args()
    print(json.dumps(close(args.close, args.earlier) if args.close else audit(), indent=2))
