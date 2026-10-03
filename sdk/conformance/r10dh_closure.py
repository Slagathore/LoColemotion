"""Cold finite-campaign closure. Original process success is required for adoption."""
import argparse
from pathlib import Path
import r10dh_contract as C
import r10dh_dependency_manifest as M
from r10dh_dependency_manifest import D
import r10dh_reader as Reader
import r10dh_authority as A
import recovery_discovery_host_v2 as Host


def workflow(root):
    record=C.read(root/'original-host.json'); D.verify_binding(record['request'])
    request=Path(record['request']['path']); result=Host.status(request.parent)
    C.require(result['host_alive'] is False and result['state'] in ('complete','failed'), 'CLOSURE_HOST_UNFINISHED')
    original=C.read(request)
    C.require(original['mode']=='r10dh' and original['batch']==root.as_posix(), 'CLOSURE_HOST_CROSSED')
    terminal=result['result']
    return dict(original_host_success=result['state']=='complete',original_publication_complete=True,
        owned_cleanup_complete=terminal['owned_cleanup_complete'],
        original_host_request=D.binding(request), original_host_terminal=D.binding(request.parent/'host-result.json'),
        original_host_publication=D.binding(request.parent/'published.json'))


def build(root):
    root=Path(root).resolve(); prepared=C.read(root/'prepared.json'); mode=prepared['mode']
    C.require(root.parent==C.EVIDENCE and prepared['qualification_only'] is False, 'CLOSURE_ROOT')
    manifest=C.read(root/'manifest.json');key=M.validate(manifest)
    claim=C.read(A.CLAIMS[mode]/'claim.json')
    C.require(C.same(claim,C.read(root/'campaign-claim.json')) and claim['batch']==root.as_posix(), 'CLOSURE_CLAIM')
    D.verify_binding(claim['cells']);D.verify_binding(claim['prepared']);D.verify_binding(prepared['source_archive'])
    C.require(claim['source_commit']==prepared['source_snapshot']['head']
        and claim['production_route_key']==key,'CLOSURE_SOURCE_BINDING')
    rows=C.read(root/'cells.json');C.validate_population([r['cell'] for r in rows],mode)
    process=workflow(root); results=[]; previous=None; prefixes={}; artifacts=set()
    for row in rows:
        folder=Path(row['folder']);child=folder/'children'/row['cell']['role']
        try:
            leaf=C.read(child/'leaf-result.json');clean=C.read(child/'owned-cleanup.json')
            C.require(leaf['ok'] is True and leaf['exit_code']==0 and clean['cleanup_complete'] is True
                and clean['remaining_owned_pids']==[], 'CLOSURE_LEAF')
            result=Reader.audit_cell(row,native=False)
            C.require(C.same(result,C.read(child/'campaign-audit.json')), 'CLOSURE_ORIGINAL_READER')
            begin=Reader.Launch.utc_ticks(result['started_utc']);end=Reader.Launch.utc_ticks(result['completed_utc'])
            C.require(begin<=end and (previous is None or previous<=begin), 'CLOSURE_OVERLAP')
            previous=end
            phase=row['cell']['seed']['prefix_phase']
            if phase in prefixes:C.require(C.same(prefixes[phase],result['prefix']), 'CLOSURE_UNMATCHED_PREFIX')
            else:prefixes[phase]=result['prefix']
        except (ValueError,OSError,KeyError,TypeError,RuntimeError) as error:
            launched=(child/'launch-reservation.json').exists()
            result=dict(cell=row['cell'],valid=False,status='incomplete' if launched else 'unopened',
                failure=str(error),solver_steps=None if launched else 0,
                physical_acceptance_authority=False,release_authority=False)
        results.append(result)
        artifacts.update(p for p in folder.rglob('*') if p.is_file())
    workflow_ok=all(process[k] is True for k in ('original_host_success','original_publication_complete','owned_cleanup_complete'))
    decision=C.decide(results,mode,workflow_ok)
    hostroot=Path(process['original_host_request']['path']).parent
    artifacts.update(p for p in hostroot.rglob('*') if p.is_file())
    artifacts.update(p for p in root.rglob('*') if p.is_file())
    out=dict(schema_version='sporespore_r10dh_physical_closure_v1',ledger_scope=C.SCOPE,mode=mode,
        source_commit=prepared['source_snapshot']['head'],evidence_root=root.as_posix(),production_route_key=key,
        independent_audit_ok=True,source_unchanged=True,declared_cells=C.population(mode),cells=results,
        artifacts=[D.binding(p) for p in sorted(artifacts)],decision=decision,**process,
        physical_acceptance_authority=False,release_authority=False)
    if mode=='development_ghost':
        positive=decision['all_finite_tasks_passed']
        kicked=results[-1].get('measurement',{})
        out.update(production_route_ghost_passed=decision['execution_valid'],all_tasks_positive=positive,
            held_out_worlds_opened=0,branch_coverage=dict(no_kick=positive,
                canonical_prone=positive and kicked.get('recovery',{}).get('entry_kind')=='prone',
                fresh_walking=positive,settled_stop=positive))
    return out


def verify_ghost(value,key):
    C.require(value['mode']=='development_ghost' and value['production_route_key']==key
        and value['all_tasks_positive'] is True and value['production_route_ghost_passed'] is True,'GHOST_PROOF')
    C.validate_population(value['declared_cells'],'development_ghost')
    for item in value['artifacts']:D.verify_binding(item)
    original=workflow(Path(value['evidence_root']))
    C.require(all(value[k]==v for k,v in original.items()),'GHOST_WORKFLOW_CHANGED')
    C.require(C.same(value['decision'],C.decide(value['cells'],'development_ghost',True)), 'GHOST_DECISION_CHANGED')
    return True


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('root');p.add_argument('output');a=p.parse_args()
    D.write_new(Path(a.output),build(a.root))
