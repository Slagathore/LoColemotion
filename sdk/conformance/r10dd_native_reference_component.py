"""R10DD native reference composition preparation and retained compiled audit."""
import argparse
import itertools
import json
import os
from pathlib import Path
import re
import subprocess
import time
import uuid
import zipfile
import r10dc_native_reference_kernel as previous
import r10db_native_reference_angles as M
import r10ap_progressive_headroom_kernel_component as builds

C=M.C
CONTRACT=C.ROOT/'sdk/recovery/r10dd_native_reference_composition_contract_v1.json'
ENTRY=C.ROOT/'sdk/core/contracts/r10dd_native_reference_entry_v1.json'
INPUTS=C.ROOT/'sdk/core/contracts/r10dd_native_reference_inputs_v1.json'
SOURCE=C.ROOT/'sdk/core/src/recovery_runtime/partial_native_reference_composition.rs'
TEST=C.ROOT/'sdk/core/src/recovery_runtime/tests/partial_native_reference_composition_tests.rs'
WRAPPER=C.ROOT/'sdk/run_r10dd_native_reference_component.ps1'
RECORD=C.ROOT/'sdk/recovery/r10dd_native_reference_component_v1.json'
CLAIMS=dict(native_composition_source_implemented=True,physical_worker_integrated=False,
    complete_safety_gate_qualified=False,new_physical_population_declared=False,
    world_build_count=0,solver_step_count=0,physical_tracking_proven=False,
    physical_acceptance_authority=False,release_authority=False)


def projection(o):
    return {k:o[k] for k in ('state','center_of_mass','ordered_foot_bearing_observations','ordered_body_clearance_observations')}


def prepare():
    previous.audit();report=C.CHILD/'worker_report.json';assert C.bind(report)['raw_sha256']==C.REPORT_SHA
    entries=M.G.records(report,'passive_entry','entry_packets')
    entry=next(p for p in entries if p['bound_observations']['observation_v3']['semantic_step']==512)
    packets=list(itertools.islice(M.G.records(report,'r10ap_partial_recovery','step_packets'),237));assert len(packets)==237
    requests=[json.loads(p['call']['request']['utf8_text']) for p in packets]
    first=requests[0];passive=first['step']['declaration']['entry_request']['passive_request']
    assert [p['step']['observation']['semantic_step'] for p in requests]==list(range(513,750))
    C.write_new(ENTRY,dict(schema_version='sporespore_r10dd_native_reference_entry_v1',
        source_report=C.bind(report),descriptor=first['collection']['descriptor'],
        setup_entry_projection=projection(passive['observation']),raise_entry_projection=projection(first['step']['observation'])))
    folder=C.EVIDENCE/('r10dd-native-reference-inputs-'+uuid.uuid4().hex);folder.mkdir()
    fixture=folder/'original_native_inputs.json'
    C.write_new(fixture,dict(schema_version='sporespore_r10dd_original_native_inputs_v1',
        source_report=C.bind(report),entry_request=json.loads(entry['call']['request']['utf8_text']),
        original_setup_commands=entry['native_receipt']['initial_partial_control']['ordered_commands'],
        step_requests=requests))
    C.write_new(INPUTS,dict(schema_version='sporespore_r10dd_native_reference_input_binding_v1',fixture=C.bind(fixture),
        source_report=C.bind(report),usage='Original inputs are immutable. Tests make separately labeled in-memory synthetic copies with new owner, applied-command hash, task memory and source binding; no physical result is replayed or regraded.'))
    C.write_new(CONTRACT,dict(schema_version='sporespore_r10dd_native_reference_composition_contract_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt_native_interfaces',authority_mode='finite_diagnostic_native_composition',question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        dependencies=[C.bind(p) for p in (previous.RECORD,previous.CONTRACT,previous.SOURCE,previous.TABLE,M.RESULT,ENTRY,INPUTS)],
        design=dict(entry='Retain the original source-validated selector. At its step512 partial selection require exact descriptor and declared portable physical projection; preserve V28 setup joint targets/caps under distinct V29 identity. At step513 require original Establish-to-Raise transition and the applied V29 setup command hash.',
            physical_entry='State, COM, ordered foot bearing and body clearance projections at steps512 and513: same shape/discrete values and finite numeric absolute error <=1e-6 in the published units. Exact semantic step, outer cadence and descriptor. Source/owner/energy checks remain independent; no body transforms unavailable to portable observations are synthesized.',
            reference='R10DC ticks1..236. Each next plan is source-bound to the validated current observation, profile and original partial memory. Match previous issued command hash to reported application, declaration/profile, prior semantic step and contiguous phase/reference tick.',
            stop='Validate the final post-step sample after reference236. Emit no next command and label finite_reference_exhausted_not_recovery_completion; retain original task receipt unchanged. An earlier original-supervisor phase transition stops the diagnostic with that disposition. Finished reference memory cannot resume.',
            admission='Register V29 for native observation ownership only; generic profile API stays unsupported. Preserve actuator caps/speed, native collection/source validation, original energy/classification/deadline logic, and old APIs.',
            qualification='Archive each build attempt source, tool invocation, exit and complete logs. Synthetic source-rebound copies of immutable original inputs exercise setup, every236 command and final observation, corruption/entry/clock/energy/ownership/command refusals and C ABI. No retained physical report is edited and no synthetic call is counted as physical tracking.',
            next='Build a distinct pinned adapter/core runtime and verify public Python/Godot calls, then integrate the production worker/reader and complete applicable smoke gate before any fresh diagnostic world.'),
        claim_boundary=CLAIMS))
    return dict(prepared=True,fixture=C.bind(fixture))


def source_bindings():
    paths={Path(b['path']).resolve() for b in builds.build_sources()}
    paths.update([CONTRACT,ENTRY,INPUTS,SOURCE,TEST,WRAPPER,Path(__file__).resolve(),C.ROOT/'sdk/python/sporespore_locomotion.py',C.ROOT/'sdk/adapters/godot/src/lib.rs'])
    return [C.bind(p) for p in sorted(paths)]


def run_tests(folder):
    folder=Path(folder).resolve();assert folder.is_relative_to(C.EVIDENCE) and folder.is_dir()
    lock=folder/'operation-lock.json';receipt=C.read(lock)
    assert receipt['acquired'] and receipt['role']=='conformance' and receipt['owner_process_id']==os.getppid()
    for binding in C.read(CONTRACT)['dependencies']:assert C.bind(binding['path'])==binding
    before=source_bindings();C.write_new(folder/'bindings-before.json',before)
    with zipfile.ZipFile(folder/'source-snapshot.zip','x',compression=zipfile.ZIP_DEFLATED) as archive:
        for b in before:
            p=Path(b['path']);archive.writestr(p.relative_to(C.ROOT).as_posix(),p.read_bytes())
    command=[str(builds.CARGO),'test','--manifest-path','sdk/core/Cargo.toml','--release','--locked','--offline','--lib','--','--nocapture','--test-threads=1']
    C.write_new(folder/'invocation.json',dict(command=command,cwd=C.ROOT.as_posix(),operation_lock=C.bind(lock),cargo=C.bind(builds.CARGO),started_unix=time.time()))
    with (folder/'stdout.log').open('xb') as out,(folder/'stderr.log').open('xb') as err:
        result=subprocess.run(command,cwd=C.ROOT,stdout=out,stderr=err,creationflags=subprocess.CREATE_NO_WINDOW)
    after=source_bindings();C.write_new(folder/'bindings-after.json',after)
    C.write_new(folder/'execution.json',dict(return_code=result.returncode,source_unchanged=before==after,finished_unix=time.time()))
    print(builds.tail(folder/'stderr.log',4000),flush=True)
    assert result.returncode==0 and before==after
    return dict(ok=True,run=folder.as_posix())


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);mode=parser.add_mutually_exclusive_group(required=True)
    mode.add_argument('--prepare',action='store_true');mode.add_argument('--run-tests',type=Path)
    args=parser.parse_args();print(json.dumps(prepare() if args.prepare else run_tests(args.run_tests),indent=2))
