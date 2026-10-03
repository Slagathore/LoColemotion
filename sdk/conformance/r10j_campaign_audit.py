"""Independent retained R10J campaign audit. No process or world is launched."""
import argparse
import json
from pathlib import Path
import re
import sys

import development_recovery_smoke as smoke
import development_passive_entry_profile as entry
import qsdk_r10f_l15_collection_retention as packet
import qsdk_r10f_l15_launch_relationship as launch
import r10j_campaign_authority as authority
import r10j_finite_task_audit as finite


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


def audit(root, *, retained=False):
    root = root.resolve()
    authority.require(root.parent == authority.EVIDENCE.resolve() and
                      (root.name == 'r10j-held-out-finite-decision-v1' or
                       re.fullmatch('r10j-production-ghost-[0-9a-f]{32}', root.name)), 'AUDIT_ROOT')
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
    authority.require(authority.same([pair['seed'] for pair in claim['pairs']], [c['seed'] for c in expected[::2]]), 'AUDIT_PAIR_POPULATION')
    import r10j_dependency_manifest as dependencies
    manifest = authority.parse((root / 'source_manifest.json').read_bytes())
    authority.require(dependencies.validate(manifest) == claim['production_route_key'], 'AUDIT_DEPENDENCY_CLOSURE')
    if mode == 'held_out_finite_decision':
        authority.require(authority.validate_authority(check_unconsumed=False, retained_commit=claim['source_commit'])['authority_commit'] == claim['source_commit'], 'AUDIT_FROZEN_AUTHORITY')
    sys.path.insert(0, str(authority.ROOT / 'sdk/python'))
    from sporespore_locomotion import LocomotionCore
    cells, previous_end, seen_pairs = [], None, set()
    for pair in claim['pairs']:
        pair_root = Path(pair['root']).resolve()
        authority.require(pair_root.parent == root.parent and
                          pair_root.name == 'development-recovery-smoke-'+pair['attempt_id'] and
                          pair['attempt_id'] not in seen_pairs, 'AUDIT_PAIR_PATH')
        seen_pairs.add(pair['attempt_id'])
        declaration = smoke.read(pair_root / 'declaration.json')
        header = authority.validate_pair_declaration(declaration)
        authority.require(declaration['r10j_campaign']['campaign_attempt_id'] == claim['attempt_id'] and
                          declaration['source_snapshot']['head'] == claim['source_commit'] and
                          declaration['source_snapshot']['dirty'] is False and
                          packet.same(declaration['children'], pair['children']) and
                          header['seed'] == pair['seed']['seed'], 'AUDIT_PAIR_DECLARATION')
        pair_audit = smoke.audit(pair_root)
        authority.require(packet.same(pair_audit, smoke.read(pair_root / 'independent_audit.stdout.json')), 'AUDIT_PAIR_PUBLICATION')
        for descriptor in pair['children']:
            child = Path(descriptor['evidence_path'])
            envelope = smoke.read(child / 'child_envelope.json')
            started, ended = launch.utc_ticks(envelope['started_utc']), launch.utc_ticks(envelope['completed_utc'])
            authority.require(previous_end is None or previous_end <= started, 'AUDIT_CAMPAIGN_OVERLAP')
            previous_end = ended
            report_path = child / 'worker_report.json'
            report = smoke.read(report_path)
            chosen = entry.selection_for_report(report)
            runtime_binding = entry.binding(chosen)['runtime']
            authority.require(entry.runtime.file_identity(Path(runtime_binding['path'])) == runtime_binding, 'AUDIT_RUNTIME_DRIFT')
            core = LocomotionCore(runtime_binding['path'])
            compiled = core.compile_bounded_quadruped(report['configuration']['base_descriptor'])
            measurement = finite.measure(report, compiled)
            cells.append(dict(cell_id=descriptor['cell_id'], seed=report['seed'], role=descriptor['role'],
                              child_attempt_id=descriptor['child_attempt_id'], execution_valid=True,
                              finite_task_predicates_passed=measurement['finite_task_predicates_passed'],
                              solver_steps=report['solver_step_count'], world_build_count=report['world_build_count'],
                              original_report_sha256=smoke.sha(report_path),
                              envelope_sha256=smoke.sha(child / 'child_envelope.json'), measurement=measurement))
    decision = decide(cells, mode)
    authority.require(sum(c['world_build_count'] for c in cells) == len(expected) and
                      all(c['solver_steps'] <= e['maximum_solver_steps'] for c,e in zip(cells,expected)), 'AUDIT_WORLD_OR_STEP_BOUND')
    result = dict(schema_version='sporespore_r10j_campaign_audit_v1', mode=mode, attempt_id=claim['attempt_id'],
                  ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='independent_retained_campaign_audit',
                                    question_class='development' if mode == 'development_ghost' else 'finite decision'),
                  **decision, cells=cells, total_world_builds=len(cells), total_solver_steps=sum(c['solver_steps'] for c in cells),
                  source_commit=claim['source_commit'], production_route_key=claim['production_route_key'],
                  campaign_claim_sha256=smoke.sha(root / 'campaign_claim.json'),
                  physical_acceptance_authority=False, release_authority=False,
                  audit_world_build_count=0, audit_solver_step_count=0)
    if retained:
        supervisor = smoke.read(root / 'supervisor_result.json')
        marker = (root / 'published_marker.txt').read_text(encoding='utf-8').splitlines()
        prefix = 'R10J_CAMPAIGN_COMPLETE '
        authority.require(len(marker) == 1 and marker[0].startswith(prefix) and
                          packet.same(packet.parse_json(marker[0][len(prefix):]), supervisor), 'AUDIT_SUPERVISOR_PUBLICATION')
        authority.require(supervisor['ok'] is True and supervisor['cell_failures'] == [] and
                          packet.same(supervisor['independent_audit'], result) and
                          supervisor['production_route_key'] == claim['production_route_key'], 'AUDIT_SUPERVISOR_RESULT')
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
