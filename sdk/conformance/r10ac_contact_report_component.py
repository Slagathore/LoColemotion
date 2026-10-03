"""Audit full-population diagnostic sidecar replay and original-observation links."""
import argparse
import json
from pathlib import Path

import r10ac_contact_frame_report as reader
import r10ac_contact_report_check as check
import r10ac_development as identity
from r10ac_support_loss_diagnosis import binding, write

RECORD = identity.ROOT/'sdk/recovery/r10ac_contact_report_component_v1.json'
CHECK = identity.EVIDENCE/'r10ac-report-check-f13105e135864e10a881262048bc2569'
EARLIER = identity.EVIDENCE/'r10ac-report-check-d94f789321a4441c9690bb37d820584a'
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))


def observations():
    for folder in (CHECK, EARLIER):
        result=read(folder/'result.json')
        assert result['ok'] is True
        assert result['observed']['positive_cases']==3 and result['observed']['negative_cases']==40
        assert result['world_build_count']==result['solver_step_count']==0
        assert result['physical_acceptance_authority'] is result['release_authority'] is False
        before=read(folder/'source-before.json')
        assert before==read(folder/'source-after.json')
        for row in before:
            source=(folder/'worker-source.gd' if folder==EARLIER
                and row['path']=='sdk/adapters/godot/gdscript/r10ac_linked_capture_worker_v1.gd'
                else identity.ROOT/row['path'])
            bound=binding(source)
            assert bound['raw_sha256']=='sha256:'+row['sha256'].lower() and bound['byte_length']==row['bytes']
        assert read(folder/'lock.json')['acquired'] is True
        for name in ('prepare','worker-parse','report','verify'):
            execution=read(folder/(name+'.execution.json'))
            assert execution['exit_code']==0 and (folder/(name+'.stderr.log')).read_bytes()==b''
            if name in ('worker-parse','report'):
                assert execution['timed_out'] is False and execution['stderr_bytes']==0
                command=read(folder/(name+'.command.json'))
                assert command['executable']==read(folder/'engine.json')['path'] and command['timeout_ms']==60000
        engine=read(folder/'engine.json')
        assert binding(engine['path'])['raw_sha256']==engine['raw_sha256']
        native,fixture=read(folder/'native.json'),read(folder/'fixture.json')
        assert native['ok'] is True and len(native['checks'])==52 and all(native['checks'].values())
        assert len(fixture['positives'])==3 and len(fixture['negatives'])==40
        for row in fixture['positives']:
            assert native['replays'][row['name']]==reader.replay_report(row['report'],fixture['declaration'])==row['expected']
        assert set(native['refusals'])=={row['name'] for row in fixture['negatives']}
        for row in fixture['negatives']:
            assert native['refusals'][row['name']]['ok'] is False
            try: reader.replay_report(row['report'],fixture['declaration'])
            except (ValueError,KeyError,TypeError,IndexError,OverflowError): pass
            else: raise AssertionError('Mutation admitted: '+row['name'])
        assert native['replays']['four_steps_all_fixtures']['diagnostic_steps_replayed']==4
        assert native['replays']['four_steps_all_fixtures']['classification_changes']==2
    check.identity_check.check_declarations()
    worker=(identity.ROOT/'sdk/adapters/godot/gdscript/r10ac_linked_capture_worker_v1.gd').read_text()
    assert worker.startswith('extends "res://sdk/adapters/godot/gdscript/r10ac_capture_worker_v1.gd"')
    assert 'func _authorized_seed_binding_v1' not in worker
    assert '_cost.begin_v1("r10ac_contact_frame_link")' in worker
    assert '_cost.end_v1("r10ac_contact_frame_link")' in worker
    return dict(ok=True,native_checks=52,positive_sidecar_reports=3,negative_sidecar_reports=40,
        independent_python_parity=True,original_observation_hash_chain_verified=True,
        full_step_population_checked=True,constant_body_population_checked=True,
        capture_link_constructor_checked=True,worker_parse_passed=True,
        linked_capture_cost_instrumented=True,live_capture_cost_measured=False,
        complete_controller_report_audited=False,physical_worker_hooks_exercised=False,
        launch_still_refused=True,complete_safety_gate_passed=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def capture():
    observed=observations()
    sources=[Path(__file__),identity.ROOT/'sdk/conformance/r10ac_support_loss_diagnosis.py',
        identity.ROOT/'sdk/recovery/r10ac_contact_capture_component_v1.json',
        identity.ROOT/'sdk/recovery/r10ac_development_identity_component_v1.json']
    sources += [identity.ROOT/row['path'] for row in read(CHECK/'source-before.json')]
    files=[check.SOURCE]+[p for folder in (CHECK,EARLIER) for p in sorted(folder.iterdir()) if p.is_file()]
    write(RECORD,dict(schema_version='sporespore_r10ac_contact_report_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',
            authority_mode='prospective_diagnostic_full_population_replay',question_class='development'),
        source_bindings=[binding(p) for p in dict.fromkeys(sources)],
        retained_evidence=[binding(p) for p in files],observed=observed,
        scope='The successor capture worker retains the original global observation and source trace. Both readers verify compact trace observation hash -> engine source trace hash -> direct-state/contact source hashes -> complete contact-frame packet for every completed step, then replay classifications independently. Missing, duplicated, reordered, stale, rehashed crossed-source and internally valid replaced-body records refuse.',
        limits='Synthetic diagnostic sidecar reports only. The complete controller/task reader must also pass on a real report. Source selection, prefix dispatch, supervisor integration, single-use reservation and the complete applicable safety gate remain pending; no world or held-out attempt was executed.',
        next_action='Integrate the distinct R10AC source qualification and candidate/prefix/launcher selection; compose both controller and diagnostic readers, qualify the complete safety graph and run the declared fresh diagnostic.'))
    return observed


def audit():
    value=read(RECORD)
    for row in value['source_bindings']+value['retained_evidence']: assert binding(row['path'])==row
    observed=observations()
    assert observed==value['observed']
    return observed


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    print('R10AC_CONTACT_REPORT_COMPONENT '+json.dumps(capture() if parser.parse_args().capture else audit()),flush=True)
