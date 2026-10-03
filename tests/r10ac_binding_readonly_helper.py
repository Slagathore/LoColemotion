"""Read-only R10AC helper predicate diagnosis; never claims a world."""
import json, os, sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'sdk/conformance'))
import r10ac_native_world_authority as authority
import r10ac_development_launch as launch
import r10ac_host_runtime as host
path=Path(sys.argv[1]); pid=int(sys.argv[2])
value=launch.read(path);child=value['children'][0];identity=authority.identity.seed_identity(authority.identity.SEED)
expected=dict(AUTHORIZATION_SHA256=authority.identity.sha(path),SOURCE_COMMIT=value['source_snapshot']['head'],PARENT_ATTEMPT_ID=value['attempt_id'],ATTEMPT_ID=child['child_attempt_id'],CHILD_ROLE=child['role'],TERMINATION_NONCE=child['termination_nonce'],SEED=str(identity['seed']),SEED_LABEL=identity['label'],SEED_SHA256=identity['sha256'],SUPERVISED_TERMINATION='1')
checks={'child_environment':{'ok':all(os.environ.get(authority.PREFIX+k)==v for k,v in expected.items()),'mismatches':[k for k,v in expected.items() if os.environ.get(authority.PREFIX+k)!=v]}}
for name, operation in (
    ('declaration', lambda: launch.declared(path)),
    ('worker_image', lambda: authority.validate_worker(pid)),
    ('launch_verify', lambda: launch.verify(path)),
    ('current_freeze', lambda: launch.current_freeze(launch.read(path)['source_snapshot']['head'])),
    ('runtime_images', lambda: host.bind_runtime(host.expected_binding()['images']['godot_console']['path'],host.expected_binding()['images']['powershell_host']['path'])),
):
    try:
        operation(); checks[name]={'ok':True}
    except Exception as error:
        checks[name]={'ok':False,'error':str(error),'type':type(error).__name__}
print(json.dumps(dict(checks=checks,diagnosis_only=True,native_claim_called=False,world_build_count=0,solver_step_count=0)))
