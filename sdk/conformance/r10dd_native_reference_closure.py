"""Post-exit closure for R10DD, preserving failed builds and invalid publication."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import zipfile
import r10dd_native_reference_component as component
import r10dd_native_interfaces_v2 as native

C=component.C
CORE=C.EVIDENCE/'r10dd-composition-core-c2912e5ad3b9400aa3ae71d25d4be1ab'
FAILED=C.EVIDENCE/'r10dd-composition-core-e9550674ad8c4880b2d206b475793b5c'
HOST_FAILED=C.EVIDENCE/'r10dd-native-build-host-a3aabbbc6cbd48e78fa0b88913179e07'
HOST_BUILD=C.EVIDENCE/'r10dd-native-build-host-021b2312a5f44e4d99dbb26846d19997'
OLD_NATIVE=C.EVIDENCE/'r10dd-native-interfaces-c969c3041f514c92935522f3c8106f51'
NEW_NATIVE=C.EVIDENCE/'r10dd-native-interfaces-v2-fd960251f75246fba44556b46047c18c'
RECORD=component.RECORD


def archive(folder,code):
    execution=C.read(folder/'execution.json')
    assert execution['return_code']==code and execution['source_unchanged']
    before=C.read(folder/'bindings-before.json');assert before==C.read(folder/'bindings-after.json')
    with zipfile.ZipFile(folder/'source-snapshot.zip') as saved:
        assert sorted(saved.namelist())==sorted(Path(b['path']).relative_to(C.ROOT).as_posix() for b in before)
        for b in before:
            raw=saved.read(Path(b['path']).relative_to(C.ROOT).as_posix())
            assert len(raw)==b['byte_length'] and 'sha256:'+hashlib.sha256(raw).hexdigest()==b['raw_sha256']
    return len(before)


def observations():
    source_count=archive(CORE,0);archive(FAILED,101)
    assert 'Option<std::string::String>' in (FAILED/'stderr.log').read_text()
    assert C.read(HOST_FAILED/'host-execution.json')['return_code']==1
    assert 'unrecognized arguments: - - b u i l d' in (HOST_FAILED/'host-stderr.txt').read_text()
    for folder in (CORE,HOST_BUILD,NEW_NATIVE):assert C.read(folder/'host-execution.json')['return_code']==0
    text=(CORE/'stdout.log').read_text();assert 'test result: ok. 524 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out;' in text
    assert len(re.findall(r'^test recovery_runtime::tests::partial_native_reference_composition_tests::[^ ]+ \.\.\.',text,re.M))==7
    commands=[];fixtures=[]
    for line in text.splitlines():
        for marker,out in [('R10DD_COMMAND_REFERENCE ',commands),('R10DD_NATIVE_FIXTURE ',fixtures)]:
            _,found,payload=line.partition(marker)
            if found:out.append(json.loads(payload))
    assert len(commands)==236 and len(fixtures)==5
    references=component.previous.expected_references()[1:];error=0.
    for row,expected in zip(commands,references,strict=True):
        assert row['tick']==expected['tick'] and row['semantic_step']==512+row['tick'] and len(row['targets'])==8
        error=max(error,max(abs(a-b) for a,b in zip(row['targets'],expected['ordered_target_positions_rad'],strict=True)))
    # The unchanged command builder projects references to guarded canonical
    # decimal numbers. Rust tests assert that exact projection; this separately
    # bounds the resulting numerical difference against the original references.
    assert error<=1e-12
    indexed={r['id']:r for r in fixtures};assert sorted(indexed)==sorted(native.IDS)
    source=C.read(C.read(component.INPUTS)['fixture']['path'])
    setup=indexed['partial_entry']['expected']['initial_partial_control']
    assert setup['ordered_commands']==source['original_setup_commands']
    end=indexed['reference_observation_237']['expected']
    assert end['next_control'] is None and end['next_reference'] is None
    assert end['diagnostic_stop_reason']=='finite_reference_exhausted_not_recovery_completion'
    assert end['step']['next_phase']=='raise_body' and not end['step']['partial_fall_standing_complete']
    assert end['reference_memory']['finished']
    observed=native.audit()
    # Repeating the same native calls is a new interface qualification. The
    # original publication remains invalid despite unchanged native results.
    old_record=C.read(C.ROOT/'sdk/recovery/r10dd_native_interfaces_v1.json')
    drift=[b for b in old_record['retained_evidence'] if C.bind(b['path'])!=b]
    assert len(drift)==1 and Path(drift[0]['path']).name=='host-stdout.json' and drift[0]['byte_length']==0
    assert (OLD_NATIVE/'native-calls.jsonl').read_bytes()==(NEW_NATIVE/'native-calls.jsonl').read_bytes()
    assert C.read(OLD_NATIVE/'godot-result.json')==C.read(NEW_NATIVE/'godot-result.json')
    assert all(not Path(b['path']).name.startswith('host-') for b in C.read(native.RECORD)['retained_evidence'])
    return dict(observed,complete_command_ticks_checked=236,final_post_step_observation_checked=True,
        setup_physical_commands_preserved=True,maximum_guarded_command_projection_error_rad=error,
        archived_core_sources=source_count,retained_compile_failures=1,retained_host_argument_failures=1,
        original_interface_publication_valid=False,publication_successor_qualified=True,
        original_native_result_regraded=False)


def dependencies():
    return [Path(__file__),component.CONTRACT,component.ENTRY,component.INPUTS,component.SOURCE,component.TEST,
        native.RECORD,native.BINDING,native.EXTENSION,C.ROOT/'sdk/recovery/r10dd_native_interfaces_v1.json',
        C.ROOT/'sdk/recovery/r10dd_native_interface_publication_successor_v1.json']


def create():
    observed=observations();roots=(CORE,FAILED,HOST_FAILED,HOST_BUILD,OLD_NATIVE,NEW_NATIVE)
    C.write_new(RECORD,dict(schema_version='sporespore_r10dd_native_reference_component_v1',ledger_scope=C.read(component.CONTRACT)['ledger_scope'],
        dependencies=[C.bind(p) for p in dependencies()],retained_evidence=[C.bind(p) for folder in roots for p in sorted(folder.iterdir()) if p.is_file()],
        observed=observed,claim_boundary=native.CLAIMS,
        next_action='Integrate the V29 production worker/source/reader and finite-stop publication; complete applicable zero-world smoke safety checks before a fresh bounded SingleKick tracking diagnostic. No physical population or acceptance authority exists here.'))
    return observed


def audit():
    record=C.read(RECORD)
    for b in [*record['dependencies'],*record['retained_evidence']]:assert C.bind(b['path'])==b
    assert record['claim_boundary']==native.CLAIMS and record['observed']==observations()
    return record['observed']


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(),indent=2))
