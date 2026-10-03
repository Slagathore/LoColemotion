"""Retain incomplete discovery populations without manufacturing terminals."""
import argparse
import gc
from pathlib import Path
import recovery_discovery as D
import recovery_panel as P
import recovery_panel_reader as R
from recovery_discovery_analysis import verify_archive


def assess(batch):
    batch = Path(batch)
    source = D.read(batch/'manifest.json'); verify_archive(source)
    incident = D.read(batch/'interruption.json')
    retired = D.read(batch/'commission-closed.json')
    D.verify_binding(retired['interruption'])
    D.require(retired['all_remaining_cells_retired'] is True
              and incident['source_runtime_unchanged'] is True
              and incident['source_file_count'] == len(source['source_files']), 'INTERRUPTION_RETIREMENT')
    D.require(all(r['current_identity'] is None for r in incident['post_exit_observations']), 'INTERRUPTION_EXIT')
    rows = D.read(batch/'cells.json')
    D.require([r['cell'] for r in rows] == P.cells(source['design'])
              and [r['cell'] for r in incident['cells']] == [r['cell'] for r in rows], 'INTERRUPTION_POPULATION')
    counts = dict(valid_complete=0, positive_cells=0, valid_negative_cells=0,
                  incomplete_infrastructure_failure=0, unopened_retired=0, known_complete_solver_steps=0)
    for row, observed in zip(rows, incident['cells']):
        folder = Path(row['folder']); declaration = D.read(folder/'declaration.json')
        child = Path(declaration['children'][0]['evidence_path'])
        status = observed['status']; D.require(status in counts, 'INTERRUPTION_DISPOSITION')
        audit_path = child/'discovery-audit.json'
        if status == 'valid_complete':
            audit = D.read(audit_path); native = D.read(child/'full-native-replay.json')
            D.verify_binding(audit['report']); D.verify_binding(observed['audit'])
            D.require(audit['valid'] is True and audit['cell'] == row['cell']
                      and D.read(child/'pool-process.json')['exit_code'] == 0
                      and native['ok'] is True and native['test_only'] is False
                      and native['complete_report_timeline_replayed'] is True
                      and native['input_raw_sha256'] == audit['report']['raw_sha256']
                      and native['runtime_raw_sha256'] == declaration['runtime']['images']['candidate_dll']['raw_sha256'],
                      'INTERRUPTION_COMPLETE_CUSTODY')
            report = D.read(audit['report']['path']); R.validate_report_header(report, declaration)
            core = R.LocomotionCore(declaration['runtime']['images']['candidate_dll']['path'])
            measured = R.measure(report, core.compile_bounded_quadruped(report['configuration']['base_descriptor']))
            D.require(measured == audit['measurement'] and native['transition_count'] == audit['solver_steps']
                      and observed['solver_steps'] == audit['solver_steps']
                      and observed['positive'] == measured['finite_task_predicates_passed'], 'INTERRUPTION_REPLAY')
            counts['positive_cells' if measured['finite_task_predicates_passed'] else 'valid_negative_cells'] += 1
            counts['known_complete_solver_steps'] += audit['solver_steps']
            del report, core; gc.collect()
        else:
            D.require(not audit_path.exists() and not (child/'worker-streamed-report.json').exists()
                      and not (child/'process.json').exists(), 'INTERRUPTION_UNEXPECTED_TERMINAL')
            D.require((child/'world-claim.json').exists() == (status == 'incomplete_infrastructure_failure'),
                      'INTERRUPTION_WORLD_DISPOSITION')
        counts[status] += 1
    return counts


def close(batch, path):
    D.repository(); batch = Path(batch)
    counts = assess(batch)
    roots = [batch]+[Path(r['folder']) for r in D.read(batch/'cells.json')]
    paths = sorted({p for root in roots for p in root.rglob('*') if p.is_file()}, key=str)
    D.write_new(path, dict(schema_version='sporespore_discovery_interrupted_closure_v1',
                ledger_scope=D.read(batch/'manifest.json')['design']['ledger_scope'],
                status='retired_incomplete_no_population_conclusion', batch=batch.as_posix(),
                auditor=D.binding(Path(__file__)), artifacts=[D.binding(p) for p in paths], counts=counts,
                interpretation='Completed cells retain their own result. Incomplete cells are infrastructure failures; their step counts and exact termination trigger are unknown. Unopened cells are retired. No matched pair or population success is inferred.',
                next_design='sdk/discovery/recovery_panel_e_v1.json', baseline_reuse_permitted=False,
                official_qualification=False, physical_acceptance_authority=False, release_authority=False))
    print(counts)


def check(path):
    D.repository(); v = D.read(path)
    D.require(v['schema_version'] == 'sporespore_discovery_interrupted_closure_v1'
              and v['status'] == 'retired_incomplete_no_population_conclusion'
              and all(v[k] is False for k in D.FLAGS) and v['baseline_reuse_permitted'] is False, 'INTERRUPTION_CLAIMS')
    for b in [v['auditor']]+v['artifacts']: D.verify_binding(b)
    D.require(v['counts'] == assess(v['batch']), 'INTERRUPTION_COUNTS')
    print('INTERRUPTED_DISCOVERY_CLOSURE_PASS; no SDK mark')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(); parser.add_argument('action', choices=('close','check'))
    parser.add_argument('path', type=Path); parser.add_argument('--closure', type=Path)
    args = parser.parse_args()
    if args.action == 'close': close(args.path, args.closure)
    else: check(args.path)
