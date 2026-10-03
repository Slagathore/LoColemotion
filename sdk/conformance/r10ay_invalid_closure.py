"""Audit R10AY's retained work-check failure without changing or rerunning it."""
import json
from pathlib import Path
import r10ay_joint_contact_search as original

C=original.C
RECORD=C.ROOT/'sdk/recovery/r10ay_joint_contact_search_invalid_closure_v1.json'


def audit():
    record=C.read(RECORD)
    for value in record['bindings'].values():assert C.bind(value['path'])==value
    bindings=record['bindings']
    run=C.read(bindings['execution']['path']);assert run['returncode']==1
    trace=Path(bindings['stderr']['path']).read_text()
    assert 'AssertionError' in trace and 'abs(work-bound) <= 1e-9' in trace
    assert bindings['source']['raw_sha256']==bindings['original_source_snapshot']['raw_sha256']
    assert bindings['declaration']['raw_sha256']==bindings['original_declaration_snapshot']['raw_sha256']
    d=C.read(bindings['diagnosis']['path'])
    assert d['source']['raw_sha256']==bindings['source']['raw_sha256']
    assert d['declaration']['raw_sha256']==bindings['declaration']['raw_sha256']
    assert d['function']=='finite' and d['exception']=='AssertionError'
    assert max(d['geometric_checks'].values())<=1e-9
    assert d['work_j']<=1e-9 and abs(d['work_j']-d['minimum_diamond_work_j'])>1e-9
    assert d['absolute_error_j']==abs(d['work_j']-d['minimum_diamond_work_j'])
    assert not original.RESULT.exists()
    assert record['outcome']=='invalid_zero_world_model_attempt'
    for key in ('physical_execution_authorized','physical_acceptance_authority','release_authority','original_result_regraded'):
        assert record[key] is False
    return dict(ok=True,outcome=record['outcome'],geometric_sector_error_m=d['geometric_checks']['sector_1'],
        friction_work_error_j=d['absolute_error_j'],world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':print(json.dumps(audit(),indent=2))
