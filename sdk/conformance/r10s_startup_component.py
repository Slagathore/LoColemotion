"""Fresh V56 startup chains and original-policy terminal checks on the R10S DLL.

Run under the locomotion operation lock. Copied exposed observations do not
predict a physical trajectory. The old full study supplies immutable inputs,
never a reused qualification result for this new runtime.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import re
import time
import traceback

import development_recovery_refusal as native
from development_passive_entry_profile import _source_snapshot
from sporespore_locomotion import LocomotionCoreError

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
RUNTIME = ROOT / 'sdk/development/recovery_candidates/r10s-extended-preparation-core-v1.runtime.json'
RECORD = ROOT / 'sdk/recovery/r10s_startup_component_v1.json'
DESIGN = ROOT / 'sdk/recovery/r10n_zero_world_state_sweep_design_v1.json'
LEGACY = ROOT / 'sdk/recovery/r10r_startup_sweep_component_v1.json'
WALK = 'sporespore_balanced_wave_recovery_extended_preparation_v1'
V55 = 'sporespore_balanced_wave_recovery_initialized_zero_brake_v1'
HOLD = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'
DLL = 'sha256:7b1ce5dd546796e13a726e26a9c1f47ad4a27792768a40d0da58cd67409e9c2b'


def require(value, code):
    if not value:
        raise ValueError('R10S_STARTUP_' + code)


def read(path):
    return json.loads(Path(path).read_bytes())


def bind(path):
    path = Path(path)
    with path.open('rb') as stream:
        digest = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=digest)


def verify(item):
    path = Path(item['path'])
    if not path.is_absolute(): path = ROOT / path
    actual = bind(path)
    require(actual['raw_sha256'] == item['raw_sha256']
        and ('byte_length' not in item or actual['byte_length'] == item['byte_length']), 'FILE:' + str(path))
    return path


def write(path, value):
    with Path(path).open('x', encoding='utf-8', newline='\n') as stream:
        json.dump(value, stream, indent=2, allow_nan=False); stream.write('\n')


def declaration(out):
    runtime = read(RUNTIME)
    require(runtime['runtime']['raw_sha256'] == DLL and len(runtime['source_files']) == 103, 'RUNTIME')
    for item in [runtime['runtime'], *runtime['source_files']]: verify(item)
    design, old = read(DESIGN), read(LEGACY)
    names = [p['id'] for p in design['populations']]
    require(len(names) == 5 and len(set(names)) == 5, 'POPULATIONS')
    original = Path(old['evidence_root'])
    selected = [original/'startup-360-full-blend.json'] + [original/('v50-hold-'+name+'.json') for name in names]
    by_path = {str(Path(v['path']).resolve()):v for v in old['retained_evidence']}
    legacy_inputs = [by_path[str(path.resolve())] for path in selected]
    for item in legacy_inputs: verify(item)
    value = dict(schema_version='sporespore_r10s_startup_study_declaration_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='finite_exposed_input_native_study',question_class='development'),
        runtime_binding=bind(RUNTIME),runtime=runtime['runtime'],population_design=bind(DESIGN),
        successor_design=bind(ROOT/'sdk/recovery/r10s_extended_preparation_design_v1.json'),
        legacy_input_record=bind(LEGACY),legacy_case_files=legacy_inputs,
        component_sources=[bind(ROOT/p) for p in ['sdk/conformance/r10s_startup_component.py',
            'sdk/conformance/development_recovery_refusal.py','sdk/conformance/development_passive_entry_profile.py',
            'sdk/python/sporespore_locomotion.py','tests/test_development_r10s_startup_receipt.py']],
        startup_policy=WALK,startup_phases=list(range(360)),commands_per_startup=73,
        maximum_startup_step_calls=131400,legacy_terminal_calls=3600,
        input_rule='First 73 already-exposed consecutive measurement requests per source; new native V56 memory and session for every phase. Source values are copied before changing only policy and memory identities.',
        legacy_rule='Recompute all retained V55 startup and V50 hold terminal requests on the new DLL and require original response bytes. No claim to a new full V50 360-phase history.',
        refusal_rule='Retain the first typed refusal and stop that synthetic session; complete the declared case population. A refusal prevents positive startup qualification.',
        session_stateless_phases=[0,90,180,270],session_stateless_commands=[1,73],
        source_parent_commit=_source_snapshot()['head'],world_build_count=0,solver_step_count=0,
        physical_prefix_phase_coverage=False,physical_response_predicted=False,original_results_regraded=False,
        reused_qualification=False,physical_acceptance_authority=False,release_authority=False)
    write(out/'declaration.json',value)
    return value


def legacy_groups(declared):
    paths = [verify(item) for item in declared['legacy_case_files']]
    walking = read(paths[0])['populations']
    groups = [(V55, p) for p in walking] + [(HOLD, read(p)) for p in paths[1:]]
    require(len(groups) == 10 and all([c['phase'] for c in p['cases']] == list(range(360)) for _,p in groups), 'LEGACY_CASES')
    return groups


def run(out):
    out = out.resolve()
    require(out.parent == EVIDENCE and re.fullmatch(r'r10s-startup-study-[0-9a-f]{32}',out.name), 'OUTPUT')
    out.mkdir()
    before = _source_snapshot(); write(out/'source_before.json',before)
    started = time.monotonic(); ok = False
    print('R10S_STARTUP_STUDY '+str(out),flush=True)
    try:
        declared = declaration(out)
        design = read(verify(declared['population_design']))
        descriptor = native.integers(read(verify(design['descriptor_source']))['configuration']['base_descriptor'])
        core = native.RecordedCore(verify(declared['runtime']))
        summaries = []
        for population in design['populations']:
            report = read(verify(population['report']))
            source_rows = report['development_walking_entry']['rows'][:73]
            require(len(source_rows) == 73 and [r['session_local_step'] for r in source_rows] == list(range(1,74)), 'SOURCE_CLOCK')
            del report
            cases = []
            for phase in range(360):
                memory = core.balanced_wave_policy_initial_memory(WALK,descriptor)
                for limb in memory['ordered_limb_memory']:
                    limb['gait_step'] = phase; limb['evidence_gait_step_limit'] = phase+1440
                hashes, refusal, comparisons = [], None, 0
                with core.create_balanced_wave_policy_session(WALK,descriptor) as session:
                    for row in source_rows:
                        q = native.integers(copy.deepcopy(row['request']))
                        q.update(schema_version='sporespore_balanced_wave_policy_step_request_v3',policy_id=WALK,descriptor=descriptor,memory=memory)
                        try:
                            result = session.step_with_measured_body({k:v for k,v in q.items() if k not in ['descriptor','policy_id']})
                        except LocomotionCoreError as error:
                            raw = core.raw_response
                            refusal = dict(kind='abi_rejection',command=row['session_local_step'],failure_code=error.failure_code)
                            hashes.append(native.digest(raw)); break
                        raw = core.raw_response; hashes.append(native.digest(raw))
                        if phase in declared['session_stateless_phases'] and row['session_local_step'] in declared['session_stateless_commands']:
                            value = core.balanced_wave_policy_step_with_measured_body(WALK,q)
                            require(core.raw_response == raw and value == result,'STATELESS_SESSION_BYTES'); comparisons += 1
                        if result['actuation']['safe_no_actuation']:
                            require(result['next_memory'] == memory and len(result['actuation']['ordered_commands']) == 8
                                and all(c['target_velocity_rad_s'] == 0 for c in result['actuation']['ordered_commands']), 'SAFE_REFUSAL')
                            refusal = dict(kind='controller_refusal',command=row['session_local_step'],failure_code=result['actuation']['receipt']['controller_error']); break
                        memory = result['next_memory']
                if refusal is None:
                    require(len(hashes) == 73 and result['actuation']['receipt']['recovery_support_plane']['anchored_body_pose']['reference_velocity_startup_scale'] == 1.0,'FULL_STARTUP')
                cases.append(dict(phase=phase,completed_calls=len(hashes),first_refusal=refusal,response_hashes=hashes,
                    terminal_request=q,final_raw_response_utf8=raw.decode(),stateless_session_comparisons=comparisons))
                if (phase+1)%90 == 0:
                    print('R10S_STARTUP_PROGRESS '+json.dumps(dict(population=population['id'],completed_phases=phase+1)),flush=True)
            write(out/('startup-'+population['id']+'.json'),dict(id=population['id'],cases=cases))
            summaries.append(dict(id=population['id'],phases=360,calls=sum(c['completed_calls'] for c in cases),refused=sum(c['first_refusal'] is not None for c in cases)))
        original_checks = []
        for policy, population in legacy_groups(declared):
            hashes = []
            for case in population['cases']:
                q = case['terminal_request']; require(q['policy_id'] == policy,'LEGACY_POLICY')
                core.balanced_wave_policy_step_with_measured_body(policy,q)
                require(core.raw_response == case['final_raw_response_utf8'].encode(),'ORIGINAL_TERMINAL_BYTES')
                hashes.append(native.digest(core.raw_response))
            original_checks.append(dict(policy_id=policy,population=population['id'],response_hashes=hashes))
        write(out/'legacy-terminal-checks.json',dict(groups=original_checks,original_inputs_unchanged=True,new_runtime=DLL))
        write(out/'summary.json',dict(populations=summaries,startup_step_calls=sum(p['calls'] for p in summaries),
            refused_startup_cases=sum(p['refused'] for p in summaries),legacy_terminal_calls=3600))
        ok = True
    except BaseException:
        write(out/'error.json',dict(traceback=traceback.format_exc())); raise
    finally:
        after=_source_snapshot();write(out/'source_after.json',after)
        write(out/'execution.json',dict(ok=ok,elapsed_seconds=round(time.monotonic()-started,3),source_unchanged=before==after,
            world_build_count=0,solver_step_count=0))
        require(before==after,'SOURCE_CHANGED')


def inspect(out, cold=False):
    out=out.resolve()
    require(out.parent == EVIDENCE and re.fullmatch(r'r10s-startup-study-[0-9a-f]{32}',out.name), 'STUDY_ROOT')
    declared=read(out/'declaration.json');run_receipt=read(out/'execution.json')
    require(run_receipt['ok'] is True and run_receipt['source_unchanged'] is True
        and (out/'source_before.json').read_bytes()==(out/'source_after.json').read_bytes(),'RUN')
    require(declared['schema_version']=='sporespore_r10s_startup_study_declaration_v1'
        and declared['startup_policy']==WALK and declared['startup_phases']==list(range(360))
        and declared['commands_per_startup']==73 and declared['maximum_startup_step_calls']==131400
        and declared['legacy_terminal_calls']==3600, 'DECLARED_POPULATION')
    verify(declared['successor_design'])
    for key in ['physical_prefix_phase_coverage','physical_response_predicted','original_results_regraded',
        'reused_qualification','physical_acceptance_authority','release_authority']:
        require(declared[key] is False, 'DECLARED_AUTHORITY')
    runtime=read(verify(declared['runtime_binding']))
    require(runtime['runtime']['raw_sha256']==DLL and declared['runtime']==runtime['runtime'],'RUNTIME')
    for item in runtime['source_files']+declared['component_sources']+[declared['runtime'],declared['legacy_input_record']]:verify(item)
    design=read(verify(declared['population_design']));verify(design['descriptor_source'])
    core=native.RecordedCore(verify(declared['runtime'])) if cold else None
    count=0;comparisons=0;refused=0
    for population in design['populations']:
        verify(population['report'])
        value=read(out/('startup-'+population['id']+'.json'))
        require(value['id']==population['id'] and [c['phase'] for c in value['cases']]==list(range(360)),'PHASES')
        for case in value['cases']:
            q=case['terminal_request'];raw=case['final_raw_response_utf8'].encode();response=json.loads(raw)
            require(case['completed_calls']==len(case['response_hashes']) and native.digest(raw)==case['response_hashes'][-1]
                and q['policy_id']==WALK and q['state']['semantic_step']==case['completed_calls'],'TERMINAL_BINDING')
            refused += int(case['first_refusal'] is not None);count+=case['completed_calls'];comparisons+=case['stateless_session_comparisons']
            require(case['first_refusal'] is None and case['completed_calls']==73
                and response['ok'] is True and response['value']['actuation']['safe_no_actuation'] is False,'STARTUP_REFUSAL')
            if core is not None:
                core.balanced_wave_policy_step_with_measured_body(WALK,q);require(core.raw_response==raw,'V56_COLD_BYTES')
    legacy=read(out/'legacy-terminal-checks.json');groups=legacy_groups(declared)
    require(len(legacy['groups'])==10 and legacy['original_inputs_unchanged'] is True and legacy['new_runtime']==DLL,'LEGACY_RESULT')
    for observed,(policy,population) in zip(legacy['groups'],groups,strict=True):
        require(observed['policy_id']==policy and observed['population']==population['id']
            and observed['response_hashes']==[native.digest(c['final_raw_response_utf8'].encode()) for c in population['cases']],'LEGACY_BYTES')
        if core is not None:
            for case in population['cases']:
                core.balanced_wave_policy_step_with_measured_body(policy,case['terminal_request'])
                require(core.raw_response==case['final_raw_response_utf8'].encode(),'LEGACY_COLD_BYTES')
    require((count,refused,comparisons)==(131400,0,40),'COMPLETE_POPULATION')
    return dict(ok=True,fresh_v56_startup_cases=1800,fresh_v56_startup_step_calls=count,
        stateless_session_byte_comparisons=comparisons,legacy_terminal_byte_checks=3600,
        refused_startup_cases=refused,cold_terminal_replays=5400 if cold else 0,
        world_build_count=0,solver_step_count=0,physical_prefix_phase_coverage=False,
        physical_response_predicted=False,original_results_regraded=False,reused_qualification=False,
        full_v50_phase_histories_repeated=False,complete_safety_gate_qualified=False,
        physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20')


def create(out):
    require(not RECORD.exists(),'RECORD_ALREADY_EXISTS')
    result=inspect(out,cold=True)
    record=dict(schema_version='sporespore_r10s_startup_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='finite_exposed_input_native_study',question_class='development'),
        status='fresh_v56_startup_and_original_terminal_inputs_verified',evidence_root=out.as_posix(),
        sources=read(out/'declaration.json')['component_sources'],retained_evidence=[bind(p) for p in sorted(out.rglob('*')) if p.is_file()],
        observed=result)
    write(RECORD,record)
    return result


def audit(cold=False):
    record=read(RECORD);require(record['schema_version']=='sporespore_r10s_startup_component_v1','SCHEMA')
    for item in record['retained_evidence']+record['sources']:verify(item)
    result=inspect(Path(record['evidence_root']),cold=cold)
    require(dict(result,cold_terminal_replays=5400)==record['observed'],'OBSERVATION')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser();mode=parser.add_mutually_exclusive_group()
    mode.add_argument('--run',type=Path);mode.add_argument('--create',type=Path)
    parser.add_argument('--cold',action='store_true');args=parser.parse_args()
    if args.run:run(args.run)
    else:print('R10S_STARTUP_COMPONENT '+json.dumps(create(args.create) if args.create else audit(args.cold)),flush=True)
