"""Retain complete original stage outputs; a record boolean never substitutes for them."""
import re
from pathlib import Path
import r10dh_contract as C
import r10dh_dependency_manifest as M
from r10dh_dependency_manifest import D

STAGES = (
    ('finite_contract','tests/test_r10dh_contract.py',6,60),
    ('authority_graph','tests/test_r10dh_authority.py',5,60),
    ('report_boundary','tests/test_r10dh_reader.py',3,60),
    ('native_ownership','tests/test_r10dg_native_process_observation.py',13,300),
    ('context_environment','tests/test_qsdk_r10f_l15_context_environment.py',5,300),
    ('enclosing_retention','tests/test_qsdk_r10f_l15_collection_enclosing_retention.py',7,180),
    ('exact_publication','tests/test_exact_json_transport.py',5,180),
    ('durable_owner','sdk/discovery/test_recovery_discovery_host_v2.py',10,900),
)


def validate_python_stage(root, spec):
    name, script, tests, timeout = spec
    process = C.read(root/(name+'.process.json'))
    C.require(process['exit_code'] == 0 and process['timed_out'] is False, 'GATE_STAGE_PROCESS_'+name)
    logs = ''
    for stream in ('stdout','stderr'):
        expected = D.binding(root/(name+'.'+stream+'.txt'))
        C.require(process[stream] == expected, 'GATE_STAGE_LOG_'+name)
        logs += Path(expected['path']).read_text(encoding='utf-8-sig')
    C.require(re.findall(r'^Ran (\d+) tests? in [0-9.]+s\s*$', logs, re.M) == [str(tests)]
        and len(re.findall(r'^OK\s*$', logs, re.M)) == 1
        and not re.search(r'^FAILED\b|^ERROR:', logs, re.M), 'GATE_STAGE_RESULT_'+name)
    return D.binding(root/(name+'.process.json'))


def validate_record(record, key):
    C.require(record.get('schema_version') == 'sporespore_r10dh_qualification_v1' and record.get('passed') is True
        and record.get('production_route_key') == key and record.get('physical_execution_authorized') is False,
        'QUALIFICATION_RECORD')
    C.require(C.same(record.get('world_build_count'),0) and C.same(record.get('solver_step_count'),0), 'QUALIFICATION_WORLDS')
    root=Path(record['evidence_root']).resolve()
    C.require(root.parent == C.EVIDENCE and root.name.startswith('r10dh-'), 'QUALIFICATION_ROOT')
    D.verify_binding(record['manifest']); M.validate(C.read(record['manifest']['path']))
    C.require(record['manifest'] == D.binding(root/'manifest.json'), 'QUALIFICATION_MANIFEST_PATH')
    C.require(record['stage_specs'] == [list(s) for s in STAGES], 'QUALIFICATION_STAGE_POPULATION')
    C.require(record['python_stages'] == [validate_python_stage(root,s) for s in STAGES], 'QUALIFICATION_STAGE_BINDINGS')
    for item in record['artifacts']:D.verify_binding(item)
    C.require(record['artifacts'] == [D.binding(p) for p in sorted(root.rglob('*')) if p.is_file()
        and p.name not in ('qualification-record.json',)], 'QUALIFICATION_ARTIFACT_POPULATION')
    native=C.read(root/'native-safety.json')
    # This independently validates each expected positive/corrupt fixture and
    # its original output, rather than trusting the summary's `ok` field.
    import r10dh_safety as Safety
    Safety.validate_native(root,native)
    interface=C.read(root/'interfaces.json')
    C.require(interface['ok'] is True and interface['world_build_count']==interface['solver_step_count']==0, 'QUALIFICATION_INTERFACES')
    for item in interface['artifacts']:D.verify_binding(item)
    import r10dh_header_wire as HeaderWire
    for row in C.read(root/'cells.json'):
        folder=Path(row['folder'])
        C.require(C.same(HeaderWire.validate(folder),C.read(folder/'header-wire-audit.json')), 'QUALIFICATION_HEADER_WIRE')
    owner=C.read(root/'durable-host-controls.json')
    C.require(owner['ok'] is True and owner['tests']==10, 'QUALIFICATION_OWNER')
    for item in record['owner_fixture_artifacts']:D.verify_binding(item)
    expected=[D.binding(p) for name in owner['fixtures'] for p in sorted(Path(name).rglob('*')) if p.is_file()]
    C.require(record['owner_fixture_artifacts']==expected,'QUALIFICATION_OWNER_ARTIFACT_POPULATION')
    return key


def run(mode):
    import r10dh_authority as A
    import r10dh_campaign as Campaign
    import r10dh_safety as Safety
    head=A.clean_head(); manifest=C.read(C.ROOT/M.MANIFEST); key=M.validate(manifest)
    batch=Campaign.prepare(mode); print(batch,flush=True)
    Campaign.interfaces(batch)
    for stage in STAGES:
        name,script,tests,timeout=stage
        command=[manifest['runtime']['images']['python_helper']['path'],'-B',C.ROOT/script]
        if name=='durable_owner':command.append(batch)
        D.process(batch,name,command,timeout=timeout,test_stderr=True)
        validate_python_stage(batch,stage)
        print('R10DH_STAGE_PASS '+name,flush=True)
    Safety.run_native(batch)
    M.validate(manifest)
    value=dict(schema_version='sporespore_r10dh_qualification_v1',ledger_scope=C.SCOPE,passed=True,
        source_freeze_commit=head,production_route_key=key,evidence_root=batch.as_posix(),
        manifest=D.binding(batch/'manifest.json'),manifest_sha256=D.binding(C.ROOT/M.MANIFEST)['raw_sha256'],
        preregistration_sha256=D.binding(C.ROOT/M.PREREGISTRATION)['raw_sha256'],
        stage_specs=[list(s) for s in STAGES],python_stages=[validate_python_stage(batch,s) for s in STAGES],
        artifacts=[D.binding(p) for p in sorted(batch.rglob('*')) if p.is_file()],
        owner_fixture_artifacts=[D.binding(p) for name in C.read(batch/'durable-host-controls.json')['fixtures']
            for p in sorted(Path(name).rglob('*')) if p.is_file()],
        world_build_count=0,solver_step_count=0,physical_execution_authorized=False,
        physical_acceptance_authority=False,release_authority=False)
    validate_record(value,key);D.write_new(batch/'qualification-record.json',value)
    return value
