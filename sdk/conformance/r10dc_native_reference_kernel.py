"""Prepare, exercise and audit the compiled finite native-reference schedule.

The original R10DB one-tick negatives remain unchanged. This declares two ticks
per interval and tests the actual Rust core without granting native world access.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time
import zipfile
import r10db_native_reference_angles as M
import r10db_native_reference_closure as previous
import r10ap_progressive_headroom_kernel_component as builds

C=M.C
CONTRACT=C.ROOT/'sdk/recovery/r10dc_native_reference_kernel_contract_v1.json'
TABLE=C.ROOT/'sdk/core/contracts/r10dc_native_reference_endpoints_v1.json'
SOURCE=C.ROOT/'sdk/core/src/recovery_runtime/partial_native_reference_control.rs'
WRAPPER=C.ROOT/'sdk/run_r10dc_reference_kernel.ps1'
RECORD=C.ROOT/'sdk/recovery/r10dc_native_reference_kernel_component_v1.json'
CLAIMS=dict(reference_kernel_implemented=True,native_controller_integrated=False,
    complete_safety_gate_qualified=False,physical_population_declared=False,
    world_build_count=0,solver_step_count=0,motor_commands_applied=0,
    physical_tracking_proven=False,physical_acceptance_authority=False,release_authority=False)


def prepare():
    previous.audit();result=C.read(M.RESULT)
    value=dict(schema_version='sporespore_r10dc_native_reference_endpoints_v1',
        source_result_raw_sha256=C.bind(M.RESULT)['raw_sha256'],ticks_per_interval=2,
        ordered_joint_ids=[foot+'_'+joint for foot in M.G.FEET for joint in ('hip','knee')],
        endpoints_rad=[row['native_joint_positions_rad'] for row in result['poses']])
    C.write_new(TABLE,value)
    C.write_new(CONTRACT,dict(schema_version='sporespore_r10dc_native_reference_kernel_contract_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_reference_from_godot_measurements',authority_mode='compiled_finite_diagnostic_reference',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        dependencies=[C.bind(p) for p in (M.RESULT,M.STUDY,M.__file__,previous.__file__,SOURCE,TABLE,WRAPPER,__file__)],
        design=dict(reference='Exact119 native endpoints from R10DB. Two controller ticks per interval: unchanged endpoint on even ticks, arithmetic midpoint on odd ticks. Tick0 is observed entry;236 subsequent targets are finite. No clipping, wrapping, final hold, solver rerun or world command.',
            clock='The stateful cursor starts at1, rejects skipped/repeated ticks without advancing, and refuses beyond236. Exhaustion is not recovery completion. Native composition must tie this cursor to the original task clock.',
            limits='Unchanged [1.6,1.1]*4 hard joint limits and1/120 s outer cadence. Reference-rate guard3.9 rad/s leaves margin below unchanged motor cap4 rad/s. Uniform two-tick timing is distinct from the observed one-tick schedule.',
            entry='Kernel admission checks all8 joint positions finite and within1e-6 rad of the audited entry. This is only a joint gate; native composition must additionally bind descriptor, full available entry observation, phase, source, ownership, clock and safety.',
            validation='All237 compiled references must equal independent Python reconstruction exactly. Check endpoints, convex midpoints, all tick rates/hard limits, finite entry admission, malformed identity/data, skips/repeats and finite exhaustion. Run the complete release core library test suite under the shared operation lock and preserve complete source snapshot and output.',
            boundary='Offline absolute reference diagnostic, not a general feedback policy. Slower timing and joint interpolation do not inherit model contact/force or swept-geometry admission. No native controller, smoke safety qualification, tracking or recovery claim.'),
        numerics=dict(ticks_per_interval=2,endpoint_count=119,last_tick=236,outer_step_duration_s=M.G.DT,reference_rate_limit_rad_s=3.9,motor_speed_cap_rad_s=4.,entry_joint_tolerance_rad=1e-6),
        claim_boundary=CLAIMS))


def sources():
    paths={Path(row['path']).resolve() for row in builds.build_sources()}
    paths.update((CONTRACT,TABLE,SOURCE,WRAPPER,Path(__file__).resolve()))
    return [C.bind(p) for p in sorted(paths)]


def run_tests(folder):
    folder=Path(folder).resolve();assert folder.is_relative_to(C.EVIDENCE) and folder.is_dir()
    operation=folder/'operation-lock.json';lock=C.read(operation)
    assert lock['acquired'] is True and lock['role']=='conformance' and lock['owner_process_id']==os.getppid()
    for binding in C.read(CONTRACT)['dependencies']:assert C.bind(binding['path'])==binding
    before=sources();C.write_new(folder/'bindings-before.json',before)
    with zipfile.ZipFile(folder/'source-snapshot.zip','x',compression=zipfile.ZIP_DEFLATED) as archive:
        for binding in before:
            path=Path(binding['path']);archive.writestr(path.relative_to(C.ROOT).as_posix(),path.read_bytes())
    command=[str(builds.CARGO),'test','--manifest-path','sdk/core/Cargo.toml','--release','--locked','--offline','--lib','--','--nocapture','--test-threads=1']
    C.write_new(folder/'invocation.json',dict(command=command,cwd=C.ROOT.as_posix(),operation_lock=C.bind(operation),cargo=C.bind(builds.CARGO),started_unix=time.time()))
    with (folder/'stdout.log').open('xb') as out,(folder/'stderr.log').open('xb') as err:
        result=subprocess.run(command,cwd=C.ROOT,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
    after=sources();C.write_new(folder/'bindings-after.json',after)
    C.write_new(folder/'execution.json',dict(return_code=result.returncode,source_unchanged=before==after,finished_unix=time.time()))
    print(builds.tail(folder/'stderr.log',2000),flush=True)
    assert result.returncode==0 and before==after
    return observations(folder)


def expected_references():
    table=C.read(TABLE);original=C.read(M.RESULT)
    assert table['source_result_raw_sha256']==C.bind(M.RESULT)['raw_sha256']
    points=[r['native_joint_positions_rad'] for r in original['poses']]
    assert table['endpoints_rad']==points and len(points)==119
    rows=[]
    for tick in range(237):
        lower=tick//2;upper=lower+(tick%2);fraction=.5 if tick%2 else 0.
        target=points[lower] if lower==upper else [a+(b-a)*fraction for a,b in zip(points[lower],points[upper],strict=True)]
        rows.append(dict(tick=tick,lower_endpoint=lower,upper_endpoint=upper,interpolation_fraction=fraction,
            ordered_target_positions_rad=target,final_reference=tick==236))
    return rows


def observations(folder):
    folder=Path(folder).resolve();execution=C.read(folder/'execution.json')
    assert execution['return_code']==0 and execution['source_unchanged']
    before=C.read(folder/'bindings-before.json');assert before==C.read(folder/'bindings-after.json')
    with zipfile.ZipFile(folder/'source-snapshot.zip') as archive:
        assert sorted(archive.namelist())==sorted(Path(b['path']).relative_to(C.ROOT).as_posix() for b in before)
        for binding in before:
            raw=archive.read(Path(binding['path']).relative_to(C.ROOT).as_posix())
            assert len(raw)==binding['byte_length'] and 'sha256:'+hashlib.sha256(raw).hexdigest()==binding['raw_sha256']
    invocation=C.read(folder/'invocation.json');lock=invocation['operation_lock'];assert C.bind(lock['path'])==lock
    assert C.read(lock['path'])['acquired'] is True
    assert all(flag in invocation['command'] for flag in ('--release','--locked','--offline','--lib','--test-threads=1'))
    text=(folder/'stdout.log').read_text(encoding='utf-8');rows=[]
    for line in text.splitlines():
        _,marker,payload=line.partition('R10DC_REFERENCE_FIXTURE ')
        if marker:rows.append(json.loads(payload))
    assert rows==expected_references()
    match=re.findall(r'test result: ok\. (\d+) passed; 0 failed; 0 ignored; 0 measured; 0 filtered out;',text)
    assert len(match)==1
    tests=re.findall(r'^test recovery_runtime::partial_native_reference_control::tests::[^ ]+ \.\.\.',text,re.M)
    assert len(tests)==7
    angles=M.np.array([row['ordered_target_positions_rad'] for row in rows])
    maximum=float(M.np.max(M.np.abs(M.np.diff(angles,axis=0))/M.G.DT))
    assert maximum<=3.9 and M.np.all(M.np.abs(angles)<=M.S.LIMITS)
    return dict(release_core_tests_passed=int(match[0]),new_kernel_tests_passed=7,
        compiled_reference_points=237,unchanged_native_endpoints=119,inserted_midpoints=118,
        command_ticks=236,maximum_reference_rate_rad_s=maximum,maximum_compiled_python_error_rad=0.,
        hard_limit_violations=0,reference_rate_violations=0,archived_build_sources=len(before),**CLAIMS)


def create(folder):
    observed=observations(folder)
    C.write_new(RECORD,dict(schema_version='sporespore_r10dc_native_reference_kernel_component_v1',
        ledger_scope=C.read(CONTRACT)['ledger_scope'],contract=C.bind(CONTRACT),auditor=C.bind(__file__),
        execution_root=Path(folder).resolve().as_posix(),retained_evidence=[C.bind(p) for p in sorted(Path(folder).iterdir()) if p.is_file()],observed=observed,claim_boundary=CLAIMS))
    return observed


def audit():
    record=C.read(RECORD)
    for binding in [record['contract'],record['auditor'],*record['retained_evidence'],*C.read(CONTRACT)['dependencies']]:assert C.bind(binding['path'])==binding
    assert record['observed']==observations(record['execution_root']) and record['claim_boundary']==CLAIMS
    return record['observed']


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--prepare',action='store_true');mode.add_argument('--run-tests',type=Path);mode.add_argument('--create',type=Path)
    args=parser.parse_args()
    result=prepare() if args.prepare else run_tests(args.run_tests) if args.run_tests else create(args.create) if args.create else audit()
    print(json.dumps(result,indent=2))
