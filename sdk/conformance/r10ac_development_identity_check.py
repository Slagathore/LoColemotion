"""Cross-language identity and publication checks, without building a world."""
import argparse
import copy
import json
from pathlib import Path
import uuid

import r10ac_development as identity


def fixture():
    head = 'a' * 40
    attempt, child, nonce = (uuid.uuid4().hex for _ in range(3))
    declaration = dict(attempt_id=attempt, children=[dict(role=identity.ROLE,
        child_attempt_id=child, termination_nonce=nonce,
        evidence_path=(identity.EVIDENCE / ('development-recovery-smoke-' + attempt)
            / 'children' / identity.ROLE).as_posix())],
        source_snapshot=dict(head=head, dirty=False, status=[], changed_file_bindings=[]),
        candidate_profile=identity.reference(), seed=identity.SEED,
        development_execution_mode=identity.SINGLE, comparative_authority=False, baseline_reused=False,
        official_qualification=False, physical_acceptance_authority=False, release_authority=False)
    declaration[identity.CONTEXT_KEY] = identity.context(identity.SINGLE, head, identity.reference())
    cases = [dict(name='valid', declaration=declaration, admitted=True)]

    def change(name, path, value):
        mutated = copy.deepcopy(declaration)
        at = mutated
        for key in path[:-1]: at = at[key]
        at[path[-1]] = value
        cases.append(dict(name=name, declaration=mutated, admitted=False))

    for seed in (51008, 51009, 41341, 61247, True):
        change('undeclared_seed_' + str(seed), ['seed'], seed)
    for key in ('comparative_authority', 'baseline_reused', 'official_qualification',
                'physical_acceptance_authority', 'release_authority'):
        change(key, [key], True)
        change(key + '_numeric', [key], 0)
    change('paired', ['development_execution_mode'], 'paired_development_v1')
    change('crossed_old_campaign', ['r10ab_development'], declaration[identity.CONTEXT_KEY])
    change('dirty', ['source_snapshot', 'dirty'], True)
    change('status', ['source_snapshot', 'status'], ['modified'])
    change('changed_binding', ['source_snapshot', 'changed_file_bindings'], [{}])
    change('bad_head', ['source_snapshot', 'head'], 'x' * 40)
    change('other_head', ['source_snapshot', 'head'], 'b' * 40)
    change('crossed_profile', ['candidate_profile', 'resource'], 'res://sdk/development/recovery_candidates/r10ab-partial-downward-rise-integrated-v2.json')
    change('profile_hash', ['candidate_profile', 'raw_sha256'], 'sha256:' + '0' * 64)
    change('context_extra', [identity.CONTEXT_KEY, 'extra'], True)
    for key, val in [('stage','first_support_diagnostic'), ('required_entry_kind','prone'),
                     ('capture_profile_id','disabled'), ('physical_acceptance_authority',True),
                     ('release_authority',True)]:
        change('context_' + key, [identity.CONTEXT_KEY, key], val)
    change('context_seed', [identity.CONTEXT_KEY,'seed','seed'], 51008)
    change('context_phase', [identity.CONTEXT_KEY,'seed','prefix_phase'], 249)
    change('design_hash', [identity.CONTEXT_KEY,'design_binding','raw_sha256'], 'sha256:'+'0'*64)
    change('observer_hash', [identity.CONTEXT_KEY,'observer_engine','raw_sha256'], 'sha256:'+'0'*64)
    change('observer_path', [identity.CONTEXT_KEY,'observer_engine','path'], 'crossed.exe')
    change('empty_children', ['children'], [])
    change('paired_children', ['children'], declaration['children'] * 2)
    change('wrong_role', ['children',0,'role'], 'no_kick_resume')
    change('bad_attempt', ['attempt_id'], 'x'*32)
    change('reused_child', ['children',0,'child_attempt_id'], attempt)
    change('reused_nonce', ['children',0,'termination_nonce'], child)
    change('bad_nonce', ['children',0,'termination_nonce'], 'x'*32)
    change('outside_evidence', ['children',0,'evidence_path'], 'C:/tmp/diagnostic')
    change('wrong_child_path', ['children',0,'evidence_path'], declaration['children'][0]['evidence_path'] + '/extra')
    for case in cases:
        try:
            identity.validate_declaration(case['declaration'])
            admitted = True
        except ValueError:
            admitted = False
        assert admitted == case['admitted'], case['name']
    report = dict(arm_id=identity.ROLE, source_commit=head, child_attempt_id=child,
        parent_attempt_id=attempt, seed=identity.SEED)
    expected = dict(report, r10ac_development=copy.deepcopy(declaration[identity.CONTEXT_KEY]),
        seed_label=identity.seed_identity(identity.SEED)['label'],
        seed_sha256=identity.seed_identity(identity.SEED)['sha256'], held_out=False, held_out_cell_access_count=0)
    identity.validate_report_header(expected, declaration)
    bad_reports = []
    for key, value in [('arm_id','no_kick_resume'), ('source_commit','b'*40),
                       ('child_attempt_id',attempt), ('parent_attempt_id',child), ('seed',51008)]:
        bad = dict(report)
        bad[key] = value
        bad_reports.append(dict(name=key, report=bad))
        completed = dict(expected)
        completed[key] = value
        try:
            identity.validate_report_header(completed, declaration)
        except ValueError:
            pass
        else:
            raise AssertionError('Crossed report admitted: '+key)
    return dict(cases=cases, report=report, expected_report=expected, bad_reports=bad_reports,
        seed_identity=identity.seed_identity(identity.SEED),
        prefix_selection=identity.prefix_selection(identity.SEED, identity.PREFIX_PROFILE),
        expected_counts=dict(declaration_positive=1, declaration_negative=len(cases)-1,
            report_positive=1, report_negative=len(bad_reports), prefix_positive=1, prefix_negative=4))


def check_declarations():
    design = json.loads(identity.DESIGN.read_text(encoding='utf-8'))
    assert identity.sha(identity.DESIGN) == identity.DESIGN_SHA
    for row in design['dependencies']:
        path = identity.ROOT / row['path']
        assert identity.sha(path) == row['raw_sha256'] and path.stat().st_size == row['byte_length']
    assert identity.sha(design['engine']['path']) == design['engine']['raw_sha256']
    profile = json.loads(identity.PROFILE.read_text(encoding='utf-8'))
    schedule_path = identity.ROOT / ('sdk/development/recovery_schedules/' + profile['diagnostic_schedule_id'] + '.json')
    assert profile['diagnostic_schedule_sha256'] == identity.sha(schedule_path)
    schedule = json.loads(schedule_path.read_text(encoding='utf-8'))['schedules'][profile['diagnostic_schedule_id']]
    predecessor = json.loads((identity.ROOT/'sdk/development/recovery_schedules/r10ab-partial-downward-rise-integrated-v2.json').read_text())['schedules']['r10ab-partial-downward-rise-integrated-v2']
    changed = {key for key in set(schedule) | set(predecessor) if schedule.get(key) != predecessor.get(key)}
    assert changed == {'coverage_basis','coverage_adequacy','coverage_question','diagnostic_capture_profile_id','uncovered_paths'}
    old_basis, new_basis = predecessor['coverage_basis'], schedule['coverage_basis']
    assert {k for k in new_basis if new_basis[k] != old_basis[k]} == {'successor_design','successor_design_sha256'}
    assert new_basis['successor_design_sha256'] == identity.DESIGN_SHA
    for key in ('runtime_binding','extension'):
        assert identity.sha(identity.ROOT/profile[key].removeprefix('res://')) == profile[key+'_sha256']
    runtime = json.loads((identity.ROOT/profile['runtime_binding'].removeprefix('res://')).read_text())
    assert identity.sha(runtime['runtime']['path']) == profile['runtime_sha256'] == design['core_runtime_sha256']
    return dict(controller_and_simulated_schedule_unchanged=True, source_and_runtime_bindings_valid=True,
        exposed_prefix_phase=248, seed=61248, launch_qualified=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--prepare', type=Path)
    parser.add_argument('--verify', type=Path)
    args = parser.parse_args()
    if args.prepare:
        value = fixture()
        with args.prepare.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(value, stream, indent=2)
            stream.write('\n')
        print(json.dumps(dict(**check_declarations(), **value['expected_counts'])))
    elif args.verify:
        result = json.loads(args.verify.read_text(encoding='utf-8-sig'))
        assert result['ok'] is True and all(result['checks'].values())
        assert result['report'] == result['fixture']['expected_report']
        assert result['prefix_selection'] == result['fixture']['prefix_selection']
        assert result['counts'] == result['fixture']['expected_counts']
        identity.validate_report_header(result['report'], result['fixture']['cases'][0]['declaration'])
        print(json.dumps(dict(**check_declarations(), **result['counts'])))
    else:
        parser.error('--prepare or --verify required')
