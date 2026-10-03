"""Prospective source/qualification/authority graph and single-use world custody."""
import re
from pathlib import Path
import subprocess
import r10dh_contract as C
import r10dh_dependency_manifest as M
from r10dh_dependency_manifest import D

# Cole authorized an infrastructure retry, preserving the original consumed claim.
# The untouched scientific held-out population retains its original one-shot claim.
CLAIMS = {mode: C.EVIDENCE/('r10dh-'+mode+'-single-use-'+('v2' if mode == 'development_ghost' else 'v1')) for mode in C.MODES}


def clean_head():
    D.repository()
    C.require(not D.git('status', '--porcelain=v1', '--untracked-files=all'), 'DIRTY_SOURCE')
    C.require(D.git('symbolic-ref', '--short', 'HEAD') == 'main', 'BRANCH')
    head = D.git('rev-parse', 'HEAD')
    C.require(head == D.git('rev-parse', 'origin/main'), 'CACHED_ORIGIN')
    C.require(D.git('ls-remote', 'origin', 'refs/heads/main').split() == [head, 'refs/heads/main'], 'LIVE_ORIGIN')
    return head


def committed(commit, path):
    C.require(re.fullmatch('[0-9a-f]{40}', commit) and path in M.OUTPUTS | {M.PREREGISTRATION}, 'COMMITTED_PATH')
    # New R10DH records are prospectively LF-pinned; historical source bytes
    # are separately retained by the dependency manifest and archive.
    return subprocess.check_output(['git', 'show', commit+':'+path], cwd=C.ROOT)


def validate_graph(authority, qualification, ghost, *, head, parents, changes, blob):
    C.require(authority.get('schema_version') == 'sporespore_r10dh_execution_authority_v1', 'AUTHORITY_SCHEMA')
    C.require(authority.get('campaign_id') == 'R10DH-HELD-OUT-FINITE-DECISION-V1', 'AUTHORITY_ID')
    C.validate_population(authority.get('cells'), 'held_out')
    rules = dict(maximum_campaign_attempts=1, maximum_world_attempts=6, maximum_solver_steps=18912,
        all_cells_must_pass=True, all_cells_run_regardless_of_behavior=True, retry_permitted=False,
        cell_replacement_permitted=False, baseline_reuse_permitted=False, threshold_override_permitted=False,
        physical_execution_authorized=True, physical_acceptance_authority=False, release_authority=False)
    C.require(all(C.same(authority.get(k), v) for k, v in rules.items()), 'AUTHORITY_RULES')
    freeze = authority.get('source_freeze_commit'); qcommit = authority.get('qualification_commit')
    C.require(all(type(v) is str and re.fullmatch('[0-9a-f]{40}', v) for v in (head, freeze, qcommit)), 'GRAPH_COMMITS')
    C.require(parents(head) == [qcommit] and parents(qcommit) == [freeze], 'THREE_COMMIT_GRAPH')
    C.require(changes(head) == [M.AUTHORITY] and changes(qcommit) == [M.QUALIFICATION], 'EXCLUSIVE_GRAPH_CHANGES')
    C.require(C.same(C.parse(blob(head, M.AUTHORITY)), authority), 'COMMITTED_AUTHORITY')
    for path, value, key, commit in ((M.QUALIFICATION, qualification, 'qualification_sha256', qcommit),
            (M.GHOST, ghost, 'ghost_sha256', freeze)):
        raw = blob(commit, path)
        C.require(C.sha(raw) == authority.get(key) and C.same(C.parse(raw), value), 'GRAPH_BINDING_'+key)
    C.require(qualification.get('passed') is True and qualification.get('source_freeze_commit') == freeze
        and qualification.get('world_build_count') == 0 and qualification.get('solver_step_count') == 0
        and qualification.get('physical_execution_authorized') is False, 'GRAPH_QUALIFICATION')
    C.require(all(ghost.get(k) is True for k in ('production_route_ghost_passed', 'all_tasks_positive',
        'original_host_success', 'original_publication_complete', 'owned_cleanup_complete', 'source_unchanged',
        'independent_audit_ok')), 'GHOST_INCOMPLETE')
    C.require(C.same(ghost.get('branch_coverage'), dict(no_kick=True, canonical_prone=True, fresh_walking=True, settled_stop=True))
        and ghost.get('held_out_worlds_opened') == 0 and ghost.get('physical_acceptance_authority') is False, 'GHOST_SCOPE')
    C.validate_population(ghost.get('declared_cells'), 'development_ghost')
    manifest_raw = blob(freeze, M.MANIFEST)
    prereg_raw = blob(freeze, M.PREREGISTRATION)
    C.require(C.sha(manifest_raw) == authority.get('manifest_sha256') == qualification.get('manifest_sha256'), 'FROZEN_MANIFEST')
    C.require(C.sha(prereg_raw) == authority.get('preregistration_sha256') == qualification.get('preregistration_sha256'), 'FROZEN_PREREGISTRATION')
    manifest = C.parse(manifest_raw)
    C.require(manifest['production_route_key'] == ghost.get('production_route_key') == qualification.get('production_route_key'), 'GHOST_KEY_CHANGED')
    prereg = C.parse(prereg_raw)
    C.validate_population(prereg.get('cells'), 'held_out')
    C.require(prereg.get('all_cells_must_pass') is True and prereg.get('retry_permitted') is False
        and prereg.get('baseline_reuse_permitted') is False and prereg.get('physical_execution_authorized') is False, 'PREREGISTRATION')
    return dict(source_freeze_commit=freeze, qualification_commit=qcommit, authority_commit=head,
                production_route_key=manifest['production_route_key'])


def validate_launch(mode, *, check_unconsumed=True):
    C.require(mode in C.MODES, 'MODE'); head = clean_head()
    manifest = C.read(C.ROOT/M.MANIFEST); key = M.validate(manifest)
    import r10dh_qualification as Q
    if mode == 'held_out':
        authority = C.read(C.ROOT/M.AUTHORITY); gate = C.read(C.ROOT/M.QUALIFICATION); ghost = C.read(C.ROOT/M.GHOST)
        validate_graph(authority, gate, ghost, head=head,
            parents=lambda commit: D.git('show', '-s', '--format=%P', commit).split(),
            changes=lambda commit: D.git('diff-tree', '--no-commit-id', '--name-only', '-r', commit).splitlines(), blob=committed)
        Q.validate_record(gate, key)
        import r10dh_closure as Closure
        Closure.verify_ghost(ghost, key)
    else:
        gate = C.read(C.ROOT/M.DEVELOPMENT_QUALIFICATION)
        Q.validate_record(gate, key)
    if check_unconsumed: C.require(not CLAIMS[mode].exists(), 'CONSUMED_POPULATION')
    return dict(head=head, production_route_key=key)


def consume(batch):
    batch = Path(batch).resolve(); prepared = C.read(batch/'prepared.json'); mode = prepared['mode']
    state = validate_launch(mode)
    C.require(prepared['qualification_only'] is False and prepared['source_snapshot'] ==
        dict(head=state['head'], dirty=False, status=[]), 'PHYSICAL_PREPARATION')
    C.require(C.read(batch/'manifest.json')['production_route_key'] == state['production_route_key'], 'PHYSICAL_KEY')
    # Directory creation consumes the population even if the following durable
    # write is interrupted. Neither an absent terminal nor an unopened cell is a retry.
    CLAIMS[mode].mkdir()
    record = dict(mode=mode, batch=batch.as_posix(), prepared=D.binding(batch/'prepared.json'),
        cells=D.binding(batch/'cells.json'), source_commit=state['head'], production_route_key=state['production_route_key'],
        retry_permitted=False, physical_acceptance_authority=False, release_authority=False)
    D.write_new(CLAIMS[mode]/'claim.json', record)
    D.write_new(batch/'campaign-claim.json', record)


def validate_running(batch, declaration):
    batch = Path(batch).resolve(); mode = declaration['r10dh_campaign']['mode']
    state = validate_launch(mode, check_unconsumed=False)
    claim = C.read(CLAIMS[mode]/'claim.json')
    C.require(C.same(claim, C.read(batch/'campaign-claim.json')) and claim['batch'] == batch.as_posix()
        and claim['source_commit'] == declaration['source_snapshot']['head'] == state['head'], 'CROSSED_CAMPAIGN_CLAIM')
    D.verify_binding(claim['cells']); D.verify_binding(claim['prepared'])
    C.require(not (batch/'supervisor-result.json').exists(), 'CAMPAIGN_ALREADY_CLOSED')
