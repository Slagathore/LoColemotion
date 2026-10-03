"""Preserve completed cell data separately from a refused outer workflow."""
import argparse
from pathlib import Path
import recovery_discovery as D
import recovery_discovery_host as H
import recovery_panel_interruption as I


def assess(batch):
    batch = Path(batch)
    source = D.read(batch/'manifest.json')
    for binding in source['runtime']['images'].values():
        D.verify_binding(binding)
    counts = I.assess(batch)
    incident = D.read(batch/'interruption.json')
    D.require(incident['original_workflow_passed'] is False, 'OWNER_REFUSAL_REQUIRED')
    states = []
    for retained in incident['hosts']:
        for key in ('result', 'publication'):
            D.verify_binding(retained[key])
        status = H.status(retained['root'])
        D.require(status['state'] == retained['state'] and status['host_alive'] is False
                  and status['result']['owned_cleanup_complete'] is True, 'OWNER_CUSTODY')
        states.append(status['state'])
    D.require(states == ['complete', 'failed'], 'OWNER_DISPOSITION')
    failed = D.read(incident['hosts'][1]['result']['path'])
    D.require(failed['command_exit_code'] == 0 and 'HOST_ORPHAN_DESCENDANT' in failed['error'],
              'OWNER_ORIGINAL_REFUSAL')
    D.require(counts['valid_complete'] == counts['positive_cells'] == 3
              and counts['unopened_retired'] == 5 and counts['known_complete_solver_steps'] == 5720,
              'OWNER_CELL_COUNTS')
    return counts


def close(batch, path, history):
    D.repository(); batch = Path(batch)
    counts = assess(batch)
    roots = [batch]+[Path(r['folder']) for r in D.read(batch/'cells.json')]
    retained = D.read(history)
    for row in retained:
        root = Path(row['path']); roots.append(root)
        if (root/'cells.json').exists():
            roots.extend(Path(r['folder']) for r in D.read(root/'cells.json'))
    paths = sorted({p for root in roots for p in root.rglob('*') if p.is_file()}, key=str)
    D.write_new(path, dict(schema_version='sporespore_discovery_owner_refusal_closure_v1',
        ledger_scope=D.read(batch/'manifest.json')['design']['ledger_scope'],
        status='retired_owner_refusal_no_complete_panel_conclusion', batch=batch.as_posix(),
        auditor=D.binding(Path(__file__)), inherited_cell_auditor=D.binding(Path(I.__file__)),
        artifacts=[D.binding(p) for p in paths], retained_history=retained, counts=counts,
        original_workflow_passed=False, prospective_panel_selection_completed=False,
        interpretation='Three cells passed unchanged task predicates and their original full native replay. The second outer owner refused shutdown after both leaf commands exited zero, then completed owned cleanup. Its exact residual descendant was not recorded. Five cells stayed unopened and are retired. The panel selection rule remains incomplete; these are leads for a distinct fresh production pair and untouched finite population, not a complete route ghost or acceptance result.',
        planned_successor='Distinct R10DH production route with qualified ownership and a fresh phase-71 pair before any held-out authority.',
        baseline_reuse_permitted=False, official_qualification=False,
        physical_acceptance_authority=False, release_authority=False))
    print(counts)


def check(path):
    D.repository(); v = D.read(path)
    D.require(v['schema_version'] == 'sporespore_discovery_owner_refusal_closure_v1'
              and v['original_workflow_passed'] is False
              and v['prospective_panel_selection_completed'] is False
              and all(v[k] is False for k in D.FLAGS), 'OWNER_CLOSURE_CLAIMS')
    for binding in [v['auditor'], v['inherited_cell_auditor']]+v['artifacts']:
        D.verify_binding(binding)
    D.require(assess(v['batch']) == v['counts'], 'OWNER_CLOSURE_COUNTS')
    print('OWNER_REFUSAL_CLOSURE_PASS; no SDK mark')


if __name__ == '__main__':
    p = argparse.ArgumentParser(); p.add_argument('action', choices=('close', 'check'))
    p.add_argument('path', type=Path); p.add_argument('--closure', type=Path); p.add_argument('--history', type=Path)
    a = p.parse_args()
    if a.action == 'close': close(a.path, a.closure, a.history)
    else: check(a.path)
