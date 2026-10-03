"""Run or reproduce the declared mathematical probe; never launch physics."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import traceback
import uuid

import r10ag_replay_invalid_closure as closure
import r10ah_support_centering_model as model
import development_passive_entry_profile as snapshot

ROOT, EVIDENCE = closure.ROOT, closure.EVIDENCE
PROTOCOL = ROOT/'sdk/recovery/r10ah_support_centering_model_protocol_v1.json'
RECORD = ROOT/'sdk/recovery/r10ah_support_centering_model_result_v1.json'
CLAIMS = dict(original_attempt_reclassified=False, physical_causal_effect_established=False,
    controller_implemented=False, native_route_integrated=False, new_physical_population_declared=False,
    world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


def derive():
    report = closure.CHILD/'worker_report.json'
    assert closure.bind(report)['raw_sha256'] == closure.REPORT_SHA
    descriptor = closure.streams.small_fields(report)['configuration']['base_descriptor']
    loaded, probes = [], []
    for kind, packet in closure.partial_records():
        if kind != 'packet':continue
        native=packet['native_receipt']; plan=native['next_load_plan']
        if plan is None or plan['mode'] != 'loaded_geometry_rise':continue
        observed=native['collection']['observation']; state=model.geometry.Model(observed,descriptor)
        search=state.search(); original=search['selected']['original']; retained=plan['rise_geometry']
        assert search['feasible'] == retained['feasible_candidate_count']
        assert original['scale'] == retained['selected_candidate_scale']
        assert original['blend'] == retained['selected_virtual_level_blend']
        assert max(abs(a-b) for a,b in zip(original['targets'],retained['ordered_target_positions_rad'])) < 1e-10
        assert abs(original['cost']-retained['selected_model_cost']) < 1e-12
        step=observed['semantic_step'];loaded.append((step,state))
        probes.append(dict(step=step,original_plan_reproduced=True,
            support_margin_m=model.margin(state.feet,state.com),
            horizontal_only=model.select(state,False),coupled_translation=model.select(state,True)))
    assert len(loaded)==110
    paths=[]
    for step,state in (loaded[0],loaded[-1]):
        for name,coupled in (('horizontal_only',False),('coupled_translation',True)):
            paths.append(dict(start_step=step,variant=name,result=model.propagate(state,coupled)))
    return dict(original_loaded_plan_parity_count=110,
        loaded_poses_outside_modeled_support_hull=sum(p['support_margin_m'] < 0. for p in probes),
        support_margin_range_m=[min(p['support_margin_m'] for p in probes),max(p['support_margin_m'] for p in probes)],
        one_step_admissible_counts={name:sum(p[name]['selected'] is not None for p in probes)
            for name in ('horizontal_only','coupled_translation')},
        probes=probes,trajectories=paths,**CLAIMS)


def summary(result):
    return {key:result[key] for key in ('original_loaded_plan_parity_count',
        'loaded_poses_outside_modeled_support_hull','support_margin_range_m','one_step_admissible_counts')} | dict(
        trajectories=[dict(start_step=p['start_step'],variant=p['variant'],
            stop=p['result']['stop'],updates=p['result']['updates'],
            mode_counts=p['result']['mode_counts'],first_centered_update=p['result']['first_centered_update'],
            final_support_margin_m=p['result']['final_support_margin_m'],
            final_height_gap_m=p['result']['final']['modeled_height_goal_gap_m']) for p in result['trajectories']],**CLAIMS)


def run():
    assert not RECORD.exists()
    out=EVIDENCE/('r10ah-support-centering-model-'+uuid.uuid4().hex)
    out.mkdir();print('R10AH_MODEL_ROOT '+str(out),flush=True)
    paths=[Path(__file__),Path(model.__file__),Path(model.geometry.__file__),Path(model.rollout.__file__),
        Path(closure.__file__),Path(closure.streams.__file__),Path(snapshot.__file__),
        ROOT/'tests/test_r10ah_support_centering_model.py',PROTOCOL,closure.RECORD,closure.CHILD/'worker_report.json']
    before=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-before.json',before)
    source_before=snapshot._source_snapshot();closure.write_new(out/'source-before.json',source_before)
    execution=dict(ok=False,**CLAIMS)
    try:
        command=[sys.executable,'-B','-X','utf8','-m','unittest','discover','-s','tests',
            '-p','test_r10ah_support_centering_model.py','-v']
        controls=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        (out/'controls.stdout.txt').write_bytes(controls.stdout);(out/'controls.stderr.txt').write_bytes(controls.stderr)
        execution.update(controls_command=command,controls_returncode=controls.returncode)
        assert controls.returncode==0 and b'Ran 6 tests' in controls.stderr,controls.stderr.decode()
        result=derive();closure.write_new(out/'result.json',result)
        execution['ok']=True
    except BaseException:
        execution['error']=traceback.format_exc()
        raise
    finally:
        after=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-after.json',after)
        source_after=snapshot._source_snapshot();closure.write_new(out/'source-after.json',source_after)
        execution['source_unchanged']=before==after and source_before==source_after
        closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10ah_support_centering_model_result_v1',
        ledger_scope=closure.read(PROTOCOL)['ledger_scope'],protocol=closure.bind(PROTOCOL),
        evidence_root=out.as_posix(),files=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],
        observed=summary(result),claim_boundary=CLAIMS)
    closure.write_new(RECORD,record)
    return record['observed']


def audit():
    record=closure.read(RECORD);assert record['claim_boundary']==CLAIMS
    for item in [record['protocol'],*record['files']]:assert closure.bind(item['path'])==item
    out=Path(record['evidence_root'])
    before=closure.read(out/'bindings-before.json');assert before==closure.read(out/'bindings-after.json')
    for item in before:assert closure.bind(item['path'])==item,item['path']
    assert closure.read(out/'source-before.json')==closure.read(out/'source-after.json')
    execution=closure.read(out/'execution.json')
    assert execution['ok'] is True and execution['source_unchanged'] is True and execution['controls_returncode']==0
    controls=(out/'controls.stderr.txt').read_text()
    assert controls.count(' ... ok\n')==6 and controls.rstrip().endswith('OK')
    result=derive();assert result==closure.read(out/'result.json') and summary(result)==record['observed']
    return record['observed']


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2,allow_nan=False))
