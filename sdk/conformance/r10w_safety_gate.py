"""Exact R10W safety-stage population and retained original-log validation."""
import argparse
import json
from pathlib import Path
import re

import r10w_campaign_authority as authority

CONTRACT = authority.ROOT/'sdk/development/r10w_safety_stage_contract_v1.json'


def require(value, code):
    if not value: raise ValueError('R10W_SAFETY_'+code)


def contract(*, complete=False):
    value = authority.parse(CONTRACT.read_bytes())
    require(value.get('schema_version') == 'sporespore_r10w_safety_stage_contract_v1', 'SCHEMA')
    stages = value['stages']
    require(type(stages) is list and stages and len({s['id'] for s in stages}) == len(stages), 'POPULATION')
    require(all(type(s['tests']) is int and s['tests'] > 0 and type(s['timeout_seconds']) is int
        and 0 < s['timeout_seconds'] <= 900 for s in stages), 'BOUNDS')
    require(sum(s['tests'] for s in stages) == value['total_tests'], 'TEST_TOTAL')
    require(sum(s['timeout_seconds'] for s in stages) + value['prehost_cleanup_wait_seconds'] < 30000,
        'HOST_DEADLINE_BUDGET')
    require(all((authority.ROOT/'tests'/s['pattern']).is_file() for s in stages), 'TEST_FILE_MISSING')
    require(set(value['prehost_stage_ids']) <= {s['id'] for s in stages}, 'PREHOST_PARTITION')
    require(value['physical_acceptance_authority'] is False and value['release_authority'] is False, 'CLAIMS')
    if complete: require(value.get('additional_required_controls') == [], 'INTEGRATION_CONTROLS_PENDING')
    return value


def validate_stages(root, actual, expected):
    """Receipt booleans never substitute for exact original unittest streams."""
    root = Path(root)
    require(type(actual) is list and len(actual) == len(expected), 'COMPLETE_STAGES')
    for spec, stage in zip(expected, actual, strict=True):
        for key, value in [('id',spec['id']), ('passed',True), ('timed_out',False), ('exit_code',0),
                           ('test_count',spec['tests']), ('expected_test_count',spec['tests'])]:
            require(authority.same(stage.get(key),value), 'STAGE_'+key)
        logs=[]
        for stream in ('stdout','stderr'):
            name=spec['id']+'.'+stream+'.log'
            require(stage.get(stream)==name, 'LOG_PATH')
            raw=(root/name).read_bytes()
            require(authority.sha(raw)=='sha256:'+str(stage.get(stream+'_sha256')), 'LOG_BYTES')
            logs.append(raw.decode('utf-8-sig',errors='strict'))
        text='\n'.join(logs)
        require(re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$',text,re.M)==[str(spec['tests'])]
            and len(re.findall(r'^OK\s*$',text,re.M))==1
            and not re.search(r'^FAILED\b|^ERROR:',text,re.M), 'TEST_POPULATION')
    return sum(s['tests'] for s in expected)


def validate_complete(root, stages):
    value=contract(complete=True)
    count=validate_stages(root,stages,value['stages'])
    return dict(stage_count=len(stages),test_count=count,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root',type=Path);p.add_argument('--stages',type=Path)
    args=p.parse_args()
    try:
        value=validate_complete(args.root,authority.parse(args.stages.read_bytes())) if args.root else contract()
        print(json.dumps(dict(ok=True,result=value)))
    except (ValueError,OSError,KeyError,TypeError) as error:
        print(json.dumps(dict(ok=False,failure_code=str(error),physical_execution_authorized=False)))
        raise SystemExit(1)
