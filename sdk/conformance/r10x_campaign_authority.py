"""Exact R10X population and committed freeze/qualification/authority checks.

This module does not launch physics. The production campaign runner must hold
the repository operation lock, consume the fixed campaign identity before its
first launch, and validate the source/runtime again before every fresh child.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

import r10x_held_out_design as design

ROOT = Path(__file__).resolve().parents[2]
EXPECTED_ROOT = Path('C:/Users/Cole/CodeStuff/games/SporeSpore')
REMOTE = 'https://github.com/Slagathore/sporespore.git'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
CAMPAIGN_ID = 'R10X-HELD-OUT-FINITE-DECISION-V1'
AUTHORITY_PATH = 'sdk/recovery/r10x_held_out_execution_authority_v1.json'
QUALIFICATION_PATH = 'sdk/recovery/r10x_held_out_zero_world_qualification_v1.json'
PREREGISTRATION_PATH = 'sdk/recovery/r10x_held_out_preregistration_v1.json'
MANIFEST_PATH = 'sdk/recovery/r10x_dependency_manifest_v2.json'
GHOST_PATH = 'sdk/recovery/r10x_production_route_ghost_closure_v1.json'
CANDIDATE_RESOURCE = 'res://sdk/development/recovery_candidates/r10x-v56-campaign-v1.json'
TASK_PATH = 'sdk/recovery/r10v_post_recovery_settling_finite_cycle_contract_v2.json'
TASK_SHA = 'sha256:321d5edfd8498f89fb015528961a9f77a282af7aecbc94a685a87b6f8f5572f2'
READER_CONTRACT_PATH = 'sdk/recovery/r10x_campaign_reader_contract_v1.json'
READER_CONTRACT_SHA = 'sha256:34bc01751cf99a14f79bdb75aaa15511cb8c1e73c4f35fd41ee706b1ed8f8d44'
READER_COMPONENT_PATH = 'sdk/recovery/r10v_development_population_closure_v1.json'
READER_COMPONENT_SHA = 'sha256:f774fbe7e3ce03dab27fc2736c86bf0cb0d837d5aa7c45f1f4f5c9f48177bf04'
DESIGN_PATH = 'sdk/recovery/r10x_held_out_finite_decision_graph_design_v1.json'
DESIGN_SHA = design.DESIGN_SHA
ROLES = ('matched_no_kick_continuation', 'kick_passive_recovery_resume')
SEEDS = design.SEEDS
DEVELOPMENT_SEEDS = (42445,)
CLAIM_PATH = EVIDENCE / 'r10x-held-out-finite-decision-v1' / 'campaign_claim.json'


def require(value, code):
    if not value:
        raise ValueError('R10X_AUTHORITY_' + code)


def sha(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def parse(raw):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'DUPLICATE_JSON_KEY')
            result[key] = value
        return result
    return json.loads(raw, object_pairs_hook=pairs,
                      parse_constant=lambda value: require(False, 'NONFINITE_JSON'))


def same(a, b):
    # Bool/int aliases are not interchangeable in an authority envelope.
    return json.dumps(a, sort_keys=True, allow_nan=False) == json.dumps(b, sort_keys=True, allow_nan=False)


def git(*arguments):
    result = subprocess.run(['git', '-C', str(ROOT), *arguments], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=False)
    require(result.returncode == 0, 'GIT_' + arguments[0])
    return result.stdout.decode('utf-8').strip()


def seed_identity(seed):
    require(type(seed) is int and seed in (*DEVELOPMENT_SEEDS, *SEEDS), 'SEED')
    if seed in DEVELOPMENT_SEEDS:
        phase = 245
        label = 'R10X-DEVELOPMENT-PREFIX-245-PAIR-V1'
    else:
        phase = seed % 360
        label = f'{CAMPAIGN_ID}/godot/prefix-phase-{phase}/seed-{seed}'
    return dict(seed=seed, label=label, sha256=sha(label.encode('utf-8')), prefix_phase=phase)


def population(mode):
    require(mode in ('development_ghost', 'held_out_finite_decision'), 'MODE')
    if mode == 'held_out_finite_decision':
        return design.population()['cells']
    # This fresh pair covers the changed campaign path and conditional hold;
    # R10V's committed five-cell closure supplies the exposed branch prerequisite.
    return [dict(cell_id=f'{42445}:{role}', seed=seed_identity(42445), role=role,
                 maximum_world_attempts=1, maximum_world_builds=1,
                 maximum_solver_steps=2552 if role == ROLES[0] else 3752)
            for role in ROLES]


def validate_population(cells, mode):
    require(same(cells, population(mode)), 'EXACT_CELL_POPULATION')


def repository_state(*, require_live=True):
    require(ROOT.resolve() == EXPECTED_ROOT.resolve(), 'ROOT')
    require(Path(git('rev-parse', '--show-toplevel')).resolve() == ROOT.resolve(), 'GIT_ROOT')
    require(git('remote', 'get-url', 'origin') == REMOTE, 'REMOTE')
    require(git('status', '--porcelain=v1', '--untracked-files=all') == '', 'DIRTY_SOURCE')
    head = git('rev-parse', 'HEAD')
    require(head == git('rev-parse', 'origin/main'), 'CACHED_MAIN')
    require(git('symbolic-ref', '--short', 'HEAD') == 'main', 'BRANCH')
    if require_live:
        live = git('ls-remote', 'origin', 'refs/heads/main').split()
        require(live == [head, 'refs/heads/main'], 'LIVE_MAIN')
    return head


def file_binding(relative):
    require(type(relative) is str and '\\' not in relative, 'RELATIVE_PATH')
    path = (ROOT / relative).resolve()
    require(path.is_relative_to(ROOT) and path.relative_to(ROOT).as_posix() == relative, 'PATH_ESCAPE')
    raw = path.read_bytes()
    return dict(path=relative, byte_length=len(raw), raw_sha256=sha(raw))


def validate_preregistration(value):
    require(value.get('schema_version') == 'sporespore_r10x_held_out_preregistration_v1', 'PREREGISTRATION_SCHEMA')
    require(value.get('campaign_id') == CAMPAIGN_ID, 'CAMPAIGN')
    candidate = value.get('candidate_profile', {})
    require(type(candidate) is dict and set(candidate) == {'resource', 'raw_sha256'} and
            candidate.get('resource') == CANDIDATE_RESOURCE and
            type(candidate.get('raw_sha256')) is str and
            re.fullmatch('sha256:[0-9a-f]{64}', candidate['raw_sha256']), 'PREREGISTRATION_CANDIDATE')
    validate_population(value.get('cells'), 'held_out_finite_decision')
    required = dict(task_contract_path=TASK_PATH, task_contract_sha256=TASK_SHA,
                    reader_contract_path=READER_CONTRACT_PATH, reader_contract_sha256=READER_CONTRACT_SHA,
                    reader_component_path=READER_COMPONENT_PATH, reader_component_sha256=READER_COMPONENT_SHA,
                    design_path=DESIGN_PATH, design_sha256=DESIGN_SHA,
                    measurement_schema='sporespore_r10v_finite_task_measurement_v1',
                    baseline_reuse_permitted=False,
                    maximum_campaign_attempt_count=1, maximum_world_attempt_count=6,
                    maximum_solver_step_count=3*(2552+3752),
                    all_cells_must_pass=True, all_cells_run_regardless_of_behavior=True,
                    cell_replacement_permitted=False, retry_permitted=False,
                    threshold_override_permitted=False, physical_execution_authorized=False,
                    physical_acceptance_authority=False, release_authority=False)
    for key, expected in required.items():
        require(same(value.get(key), expected), 'PREREGISTRATION_' + key)
    return value


def validate_graph(authority, qualification, ghost, *, head, parents, changes, blob):
    """Validate the real graph through injected read-only Git accessors.

    Unit controls use an in-memory graph; validate_authority supplies real Git
    parents, changed paths, and blobs. No mock graph creates execution authority.
    """
    require(authority.get('schema_version') == 'sporespore_r10x_execution_authority_v1', 'SCHEMA')
    require(authority.get('campaign_id') == CAMPAIGN_ID, 'CAMPAIGN')
    require(authority.get('qualification_closure_path') == QUALIFICATION_PATH, 'QUALIFICATION_PATH')
    require(authority.get('prerequisite_ghost_path') == GHOST_PATH, 'GHOST_PATH')
    required = dict(maximum_campaign_attempt_count=1, maximum_world_attempt_count=6,
                    maximum_solver_step_count=18912, physical_execution_authorized=True,
                    physical_acceptance_authority=False, release_authority=False,
                    retry_permitted=False, cell_replacement_permitted=False,
                    baseline_reuse_permitted=False, threshold_override_permitted=False,
                    all_cells_must_pass=True, all_cells_run_regardless_of_behavior=True)
    for key, expected in required.items():
        require(same(authority.get(key), expected), 'AUTHORITY_' + key)
    validate_population(authority.get('cells'), 'held_out_finite_decision')
    freeze = authority.get('source_freeze_commit')
    qualification_commit = authority.get('qualification_commit')
    require(all(type(v) is str and re.fullmatch('[0-9a-f]{40}', v) for v in
                (head, freeze, qualification_commit)), 'COMMIT_ID')
    require(parents(head) == [qualification_commit] and
            parents(qualification_commit) == [freeze], 'THREE_COMMIT_GRAPH')
    require(changes(head) == [AUTHORITY_PATH], 'AUTHORITY_ONLY_CHILD')
    require(changes(qualification_commit) == [QUALIFICATION_PATH], 'QUALIFICATION_ONLY_CHILD')
    require(same(parse(blob(head, AUTHORITY_PATH)), authority), 'COMMITTED_AUTHORITY')
    qraw = blob(qualification_commit, QUALIFICATION_PATH)
    require(sha(qraw) == authority.get('qualification_closure_sha256') and
            same(parse(qraw), qualification), 'QUALIFICATION_BINDING')
    require(qualification.get('schema_version') == 'sporespore_r10x_zero_world_qualification_v1' and
            qualification.get('passed') is True and qualification.get('source_freeze_commit') == freeze,
            'QUALIFICATION_FAILED_OR_CROSSED')
    require(same(qualification.get('world_build_count'), 0) and same(qualification.get('solver_step_count'), 0) and
            qualification.get('physical_execution_authorized') is False, 'QUALIFICATION_AUTHORITY')
    for path, expected in ((DESIGN_PATH, DESIGN_SHA), (TASK_PATH, TASK_SHA),
                           (READER_CONTRACT_PATH, READER_CONTRACT_SHA), (READER_COMPONENT_PATH, READER_COMPONENT_SHA)):
        require(sha(blob(freeze, path)) == expected, 'FROZEN_READER_OR_TASK:' + path)
    graw = blob(freeze, GHOST_PATH)
    require(sha(graw) == authority.get('prerequisite_ghost_sha256') and same(parse(graw), ghost), 'GHOST_BINDING')
    require(ghost.get('schema_version') == 'sporespore_r10x_production_route_ghost_closure_v1' and
            ghost.get('all_tasks_positive') is True and
            ghost.get('reader_component_sha256') == READER_COMPONENT_SHA and
            ghost.get('production_route_ghost_passed') is True and ghost.get('launcher_ok') is True and
            ghost.get('independent_audit_ok') is True and ghost.get('post_exposure_regraded') is False,
            'PRODUCTION_GHOST_INCOMPLETE')
    require(all(ghost.get(name) is True for name in ('original_host_success','original_publication_complete',
        'owned_cleanup_complete','source_unchanged')) and
        same(ghost.get('branch_coverage'), dict(no_kick=True,upright_bounded_hold=True)), 'GHOST_ORIGINAL_WORKFLOW')
    require(same(ghost.get('held_out_worlds_opened'), 0) and ghost.get('physical_acceptance_authority') is False,
            'GHOST_AUTHORITY')
    validate_population(ghost.get('declared_cells'), 'development_ghost')
    for path, key in ((PREREGISTRATION_PATH, 'preregistration_sha256'), (MANIFEST_PATH, 'dependency_manifest_sha256')):
        require(sha(blob(freeze, path)) == authority.get(key) == qualification.get(key), 'FROZEN_' + key)
    preregistration = validate_preregistration(parse(blob(freeze, PREREGISTRATION_PATH)))
    require(authority.get('candidate_profile') == preregistration.get('candidate_profile'), 'CANDIDATE')
    require(sha(blob(freeze, CANDIDATE_RESOURCE.removeprefix('res://'))) ==
            preregistration['candidate_profile']['raw_sha256'], 'FROZEN_CANDIDATE_BYTES')
    manifest = parse(blob(freeze, MANIFEST_PATH))
    key = manifest.get('production_route_key')
    require(type(key) is str and re.fullmatch('sha256:[0-9a-f]{64}', key) and
            key == ghost.get('production_route_key') == qualification.get('production_route_key'),
            'PRODUCTION_ROUTE_CHANGED_AFTER_GHOST')
    return dict(source_freeze_commit=freeze, qualification_commit=qualification_commit,
                authority_commit=head, campaign_id=CAMPAIGN_ID, cells=population('held_out_finite_decision'))


def committed_runtime_bytes(commit, path):
    """Read Git's working-tree byte projection, including declared line endings.

    Plain Git blobs can be LF while the Windows runtime consumed CRLF. Current
    dependency validation separately binds actual disk bytes; the exclusive
    three-commit graph prevents source/attribute edits after qualification.
    """
    require(type(commit) is str and re.fullmatch('[0-9a-f]{40}', commit), 'BLOB_COMMIT')
    require(type(path) is str and path in (AUTHORITY_PATH,QUALIFICATION_PATH,GHOST_PATH,
        PREREGISTRATION_PATH,MANIFEST_PATH,DESIGN_PATH,TASK_PATH,READER_CONTRACT_PATH,
        READER_COMPONENT_PATH,CANDIDATE_RESOURCE.removeprefix('res://')), 'BLOB_PATH')
    result = subprocess.run(['git','cat-file','--filters',f'{commit}:{path}'],cwd=ROOT,
        stdout=subprocess.PIPE,stderr=subprocess.PIPE,check=False)
    require(result.returncode == 0, 'MISSING_COMMITTED_RUNTIME_BYTES')
    return result.stdout


def validate_authority(relative=AUTHORITY_PATH, *, check_unconsumed=True, retained_commit=None):
    require(relative == AUTHORITY_PATH, 'AUTHORITY_PATH')
    head = repository_state() if retained_commit is None else retained_commit
    require(retained_commit is None or (not check_unconsumed and type(head) is str and
            re.fullmatch('[0-9a-f]{40}', head)), 'RETAINED_AUTHORITY_COMMIT')
    authority = parse((ROOT / relative).read_bytes())
    qualification = parse((ROOT / QUALIFICATION_PATH).read_bytes())
    ghost = parse((ROOT / GHOST_PATH).read_bytes())
    blob = committed_runtime_bytes
    result = validate_graph(authority, qualification, ghost, head=head,
                            parents=lambda commit: git('show', '-s', '--format=%P', commit).split(),
                            changes=lambda commit: git('diff-tree', '--no-commit-id', '--name-only', '-r', commit).splitlines(),
                            blob=blob)
    require(git('rev-parse', f"{authority['qualification_commit']}:{QUALIFICATION_PATH}") ==
            authority.get('qualification_closure_git_blob_oid'), 'QUALIFICATION_GIT_BLOB')
    # A committed boolean cannot substitute for the actual retained gate,
    # publication, native replay, or complete current dependency closure.
    import r10x_dependency_manifest as dependencies
    import r10x_qualification as qualification_reader
    dependencies.validate(parse((ROOT / MANIFEST_PATH).read_bytes()))
    qualification_reader.validate_retained_qualification(qualification, ghost)
    if check_unconsumed:
        require(not CLAIM_PATH.parent.exists(), 'CAMPAIGN_CONSUMED')
    result.update(authority_file=file_binding(AUTHORITY_PATH), physical_execution_authorized=retained_commit is None,
                  physical_acceptance_authority=False, release_authority=False)
    return result


def validate_pair_declaration(declaration):
    """Independent reader binding for campaign pairs, including consumed ones.

    The historical smoke reader calls this only when a campaign context is
    present. Legacy declarations retain the fixed 40200/unofficial rules.
    This checks retained authority bytes, not current-head launch permission.
    """
    require(not any(key.startswith('r10') and key not in ('r10x_campaign','r10x_host') for key in declaration), 'CROSSED_CAMPAIGN_CONTEXT')
    context = declaration.get('r10x_campaign')
    require(type(context) is dict and context.get('schema_version') == 'sporespore_r10x_campaign_child_context_v1', 'CHILD_CONTEXT')
    mode, attempt = context.get('mode'), context.get('campaign_attempt_id')
    require(type(attempt) is str and re.fullmatch('[0-9a-f]{32}', attempt), 'CAMPAIGN_ATTEMPT')
    cells = population(mode)
    identity = seed_identity(declaration.get('seed'))
    require(same(context.get('seed'), identity) and any(same(c['seed'], identity) for c in cells), 'PAIR_SEED')
    require(context.get('source_commit') == declaration.get('source_snapshot', {}).get('head'), 'PAIR_SOURCE')
    require(same(declaration.get('source_snapshot'), dict(head=context['source_commit'], dirty=False,
            status=[], changed_file_bindings=[])), 'PAIR_SOURCE_NOT_FROZEN')
    candidate = declaration.get('candidate_profile')
    require(type(candidate) is dict and set(candidate) == {'resource', 'raw_sha256'}
            and candidate.get('resource') == CANDIDATE_RESOURCE
            and candidate.get('raw_sha256') == file_binding(CANDIDATE_RESOURCE.removeprefix('res://'))['raw_sha256']
            and same(context.get('candidate_profile'), candidate), 'PAIR_CANDIDATE')
    claim_path = (EVIDENCE / ('r10x-production-ghost-'+attempt) / 'campaign_claim.json'
                  if mode == 'development_ghost' else CLAIM_PATH)
    bound = context.get('claim_binding', {})
    require(bound.get('path') == claim_path.as_posix(), 'CLAIM_PATH')
    raw = claim_path.read_bytes()
    require(sha(raw) == bound.get('raw_sha256'), 'CLAIM_BYTES')
    claim = parse(raw)
    require(claim.get('schema_version') == 'sporespore_r10x_campaign_claim_v1' and
            claim.get('attempt_id') == attempt and claim.get('mode') == mode and
            claim.get('source_commit') == context['source_commit'] and
            same(claim.get('candidate_profile'), candidate), 'CLAIM_IDENTITY')
    validate_population(claim.get('cells'), mode)
    children = claim.get('children')
    require(type(children) is list and [c.get('cell_id') for c in children] == [c['cell_id'] for c in cells], 'CLAIM_CHILD_POPULATION')
    require(len({c.get('child_attempt_id') for c in children}) == len(cells), 'CLAIM_CHILD_REUSE')
    expected_roles = [c['role'] for c in cells if c['seed']['seed'] == identity['seed']]
    require([c.get('role') for c in declaration.get('children', [])] == expected_roles, 'PAIR_ROLES')
    for descriptor in declaration['children']:
        matches = [c for c in children if c['cell_id'] == f"{identity['seed']}:{descriptor['role']}"]
        require(len(matches) == 1 and matches[0].get('parent_attempt_id') == declaration['attempt_id'] and
                same(matches[0], descriptor), 'PAIR_CHILD_BINDING')
    if mode == 'held_out_finite_decision':
        for name, path in (('authority_binding', AUTHORITY_PATH), ('preregistration_binding', PREREGISTRATION_PATH)):
            bound = context.get(name, {})
            require(bound.get('path') == 'res://'+path and file_binding(path)['raw_sha256'] == bound.get('raw_sha256'), 'PAIR_'+name)
        authority = parse((ROOT / AUTHORITY_PATH).read_bytes())
        preregistration = validate_preregistration(parse((ROOT / PREREGISTRATION_PATH).read_bytes()))
        require(authority.get('campaign_id') == CAMPAIGN_ID and authority.get('physical_execution_authorized') is True and
                authority.get('preregistration_sha256') == context['preregistration_binding']['raw_sha256'] and
                same(authority.get('candidate_profile'), candidate) and same(preregistration.get('candidate_profile'), candidate), 'PAIR_AUTHORITY')
        validate_population(authority.get('cells'), mode)
    return dict(seed=identity['seed'], held_out=mode == 'held_out_finite_decision',
                ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode=mode,
                                  question_class='finite decision' if mode == 'held_out_finite_decision' else 'development'))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=['population', 'validate', 'repository'])
    parser.add_argument('--mode', choices=['development_ghost', 'held_out_finite_decision'], default='held_out_finite_decision')
    args = parser.parse_args()
    try:
        value = (population(args.mode) if args.command == 'population' else
                 dict(head=repository_state()) if args.command == 'repository' else validate_authority())
        print(json.dumps(dict(ok=True, result=value), allow_nan=False))
        return 0
    except (ValueError, OSError, KeyError, TypeError, ImportError) as error:
        print(json.dumps(dict(ok=False, failure_code=str(error), physical_execution_authorized=False)))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
