"""Independent retained R10X campaign audit. No process or world is launched."""
import argparse
import json
from pathlib import Path
import re

import r10x_pair_audit as smoke
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_launch_relationship as launch
import r10x_campaign_authority as authority


def decide(cells, mode):
    """One exact conjunction. Invalid and negative cells are never omitted."""
    expected = authority.population(mode)
    authority.require(type(cells) is list and [c.get('cell_id') for c in cells] ==
                      [c['cell_id'] for c in expected], 'RESULT_CELL_POPULATION')
    authority.require(all(type(c.get('execution_valid')) is bool and
                          type(c.get('finite_task_predicates_passed')) is bool for c in cells), 'RESULT_DOMAIN')
    valid = all(c['execution_valid'] for c in cells)
    positive = valid and all(c['finite_task_predicates_passed'] for c in cells)
    return dict(execution_valid=valid, all_finite_tasks_passed=positive,
                outcome='positive' if positive else 'negative' if valid else 'invalid')



AUDIT_ERRORS = (ValueError, OSError, KeyError, TypeError, RuntimeError)


def unresolved_cell(descriptor, spec, child, failure):
    """Preserve an invalid or unopened cell without inventing world/step counts."""
    retained = []
    for name in ('child_attempt_identity.json', 'child_envelope.json', 'worker_report.json',
                 'worker.stdout.txt', 'worker.stderr.txt', 'campaign_launch_failure.json',
                 'passive_entry_replay_result.json', 'campaign_launch_started.json'):
        path = child / name
        if path.is_file():
            retained.append(dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=smoke.sha(path)))
    launched = any((child / name).exists() for name in
        ('campaign_launch_started.json', 'child_envelope.json', 'worker.stdout.txt', 'worker.stderr.txt', 'campaign_launch_failure.json'))
    return dict(cell_id=spec['cell_id'], seed=spec['seed']['seed'], role=spec['role'],
        child_attempt_id=descriptor['child_attempt_id'], execution_valid=False,
        finite_task_predicates_passed=False, outcome='invalid' if launched else 'unopened',
        failure_code=failure, solver_steps=None if launched else 0,
        world_build_count=None if launched else 0, entry_kind='unverified', retained_files=retained)


def validate_supervisor(supervisor, result):
    """An accurately published negative or invalid campaign remains closable."""
    authority.require(type(supervisor.get('ok')) is bool and
        packet.same(supervisor.get('independent_audit'), result) and
        supervisor.get('production_route_key') == result['production_route_key'], 'AUDIT_SUPERVISOR_RESULT')
    if result['execution_valid']:
        authority.require(supervisor['ok'] is True and supervisor.get('cell_failures') == []
            and supervisor.get('failure_code') == '', 'AUDIT_SUPERVISOR_VALID')
    else:
        authority.require(supervisor['ok'] is False and bool(supervisor.get('failure_code')),
            'AUDIT_SUPERVISOR_INVALID')


def audit(root, *, retained=False):
    root = root.resolve()
    authority.require(root.parent == authority.EVIDENCE.resolve() and
                      (root.name == 'r10x-held-out-finite-decision-v1' or
                       re.fullmatch('r10x-production-ghost-[0-9a-f]{32}', root.name)), 'AUDIT_ROOT')
    claim = authority.parse((root / 'campaign_claim.json').read_bytes())
    mode = claim['mode']
    expected = authority.population(mode)
    authority.validate_population(claim['cells'], mode)
    authority.require((mode == 'held_out_finite_decision') == (root == authority.CLAIM_PATH.parent), 'AUDIT_MODE')
    if mode == 'development_ghost':
        authority.require(root.name.endswith(claim['attempt_id']), 'AUDIT_ATTEMPT')
    authority.require([c['cell_id'] for c in claim['children']] == [c['cell_id'] for c in expected], 'AUDIT_CHILD_POPULATION')
    authority.require(len({c['child_attempt_id'] for c in claim['children']}) == len(expected), 'AUDIT_CHILD_REUSE')
    authority.require(authority.same(claim['children'], [child for pair in claim['pairs'] for child in pair['children']]), 'AUDIT_PLAN_CHILDREN')
    authority.require(authority.same([pair['seed'] for pair in claim['pairs']], list({c['seed']['seed']: c['seed'] for c in expected}.values())), 'AUDIT_PAIR_POPULATION')
    import r10x_dependency_manifest as dependencies
    manifest = authority.parse((root / 'source_manifest.json').read_bytes())
    authority.require(dependencies.validate(manifest) == claim['production_route_key'], 'AUDIT_DEPENDENCY_CLOSURE')
    if mode == 'held_out_finite_decision':
        authority.require(authority.validate_authority(check_unconsumed=False, retained_commit=claim['source_commit'])['authority_commit'] == claim['source_commit'], 'AUDIT_FROZEN_AUTHORITY')
    cells, previous_end, seen_pairs = [], None, set()
    for pair in claim['pairs']:
        pair_root = Path(pair['root']).resolve()
        authority.require(pair_root.parent == root.parent and
                          pair_root.name == 'development-recovery-smoke-'+pair['attempt_id'] and
                          pair['attempt_id'] not in seen_pairs, 'AUDIT_PAIR_PATH')
        seen_pairs.add(pair['attempt_id'])
        pair_failure = ''
        pair_audit = None
        try:
            declaration = smoke.read(pair_root / 'declaration.json')
            header = authority.validate_pair_declaration(declaration)
            authority.require(declaration['r10x_campaign']['campaign_attempt_id'] == claim['attempt_id'] and
                declaration['source_snapshot']['head'] == claim['source_commit'] and
                declaration['source_snapshot']['dirty'] is False and
                packet.same(declaration['children'], pair['children']) and
                header['seed'] == pair['seed']['seed'], 'AUDIT_PAIR_DECLARATION')
            pair_audit = smoke.audit(pair_root)
            authority.require(packet.same(pair_audit, smoke.read(pair_root / 'independent_audit.stdout.json')),
                'AUDIT_PAIR_PUBLICATION')
        except AUDIT_ERRORS as error:
            pair_failure = str(error)
        for descriptor in pair['children']:
            child = Path(descriptor['evidence_path']).resolve()
            spec = next(c for c in expected if c['cell_id'] == descriptor['cell_id'])
            authority.require(child == pair_root / 'children' / descriptor['role'], 'AUDIT_CHILD_PATH')
            if pair_failure:
                cells.append(unresolved_cell(descriptor, spec, child, pair_failure))
                # A separate diagnostic can preserve a sound child while the
                # incomplete pair stays invalid; it cannot replace the pair.
                try:
                    diagnostic = smoke.audit(pair_root, selected_role=descriptor['role'])
                    cells[-1]['independent_cell_diagnostic'] = diagnostic['finite_cells'][0]
                except AUDIT_ERRORS as error:
                    cells[-1]['independent_cell_failure'] = str(error)
                continue
            try:
                envelope = smoke.read(child / 'child_envelope.json')
                started, ended = launch.utc_ticks(envelope['started_utc']), launch.utc_ticks(envelope['completed_utc'])
                authority.require(previous_end is None or previous_end <= started, 'AUDIT_CAMPAIGN_OVERLAP')
                previous_end = ended
                measured = [row for row in pair_audit['finite_cells'] if row['role'] == descriptor['role']]
                authority.require(len(measured) == 1 and measured[0]['child_attempt_id'] == descriptor['child_attempt_id'], 'AUDIT_CELL_PUBLICATION')
                authority.require(type(measured[0]['solver_steps']) is int and
                    0 < measured[0]['solver_steps'] <= spec['maximum_solver_steps'] and
                    type(measured[0]['world_build_count']) is int and measured[0]['world_build_count'] == 1,
                    'AUDIT_CELL_WORLD_OR_STEP_BOUND')
                cells.append(dict(cell_id=descriptor['cell_id'], outcome='positive' if measured[0]['finite_task_predicates_passed'] else 'negative', **measured[0]))
            except AUDIT_ERRORS as error:
                cells.append(unresolved_cell(descriptor, spec, child, str(error)))
    decision = decide(cells, mode)
    known_worlds = all(type(c['world_build_count']) is int for c in cells)
    known_steps = all(type(c['solver_steps']) is int for c in cells)
    result = dict(schema_version='sporespore_r10x_campaign_audit_v1', mode=mode, attempt_id=claim['attempt_id'],
                  ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='independent_retained_campaign_audit',
                                    question_class='development' if mode == 'development_ghost' else 'finite decision'),
                  **decision, cells=cells, total_world_builds=sum(c['world_build_count'] for c in cells) if known_worlds else None,
                  total_solver_steps=sum(c['solver_steps'] for c in cells) if known_steps else None,
                  source_commit=claim['source_commit'], production_route_key=claim['production_route_key'],
                  campaign_claim_sha256=smoke.sha(root / 'campaign_claim.json'),
                  physical_acceptance_authority=False, release_authority=False,
                  audit_world_build_count=0, audit_solver_step_count=0)
    if retained:
        supervisor = smoke.read(root / 'supervisor_result.json')
        marker = (root / 'published_marker.txt').read_text(encoding='utf-8').splitlines()
        prefix = 'R10X_CAMPAIGN_COMPLETE '
        authority.require(len(marker) == 1 and marker[0].startswith(prefix) and
                          packet.same(packet.parse_json(marker[0][len(prefix):]), supervisor), 'AUDIT_SUPERVISOR_PUBLICATION')
        validate_supervisor(supervisor, result)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--retained', action='store_true')
    args = parser.parse_args()
    try:
        result = audit(args.root, retained=args.retained)
        print(json.dumps(dict(ok=True, result=result), allow_nan=False))
        return 0
    except (ValueError, OSError, KeyError, TypeError, RuntimeError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), physical_acceptance_authority=False, release_authority=False)))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
