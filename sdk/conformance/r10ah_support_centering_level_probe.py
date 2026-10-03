"""Retain and audit the distinct bounded-leveling mathematical probe."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import traceback
import uuid

import r10ah_support_centering_level_model as model
import r10ah_support_centering_probe as prior

closure, ROOT, EVIDENCE = prior.closure, prior.ROOT, prior.EVIDENCE
PROTOCOL=ROOT/'sdk/recovery/r10ah_support_centering_level_model_protocol_v2.json'
RECORD=ROOT/'sdk/recovery/r10ah_support_centering_level_model_result_v2.json'


def derive():
    path=closure.CHILD/'worker_report.json'
    assert closure.bind(path)['raw_sha256']==closure.REPORT_SHA
    descriptor=closure.streams.small_fields(path)['configuration']['base_descriptor']
    loaded,probes=[],[]
    for kind,packet in closure.partial_records():
        if kind!='packet':continue
        native=packet['native_receipt'];plan=native['next_load_plan']
        if plan is None or plan['mode']!='loaded_geometry_rise':continue
        observation=native['collection']['observation'];state=model.geometry.Model(observation,descriptor)
        search=state.search();original=search['selected']['original'];retained=plan['rise_geometry']
        assert search['feasible']==retained['feasible_candidate_count']
        assert original['scale']==retained['selected_candidate_scale'] and original['blend']==retained['selected_virtual_level_blend']
        assert max(abs(a-b) for a,b in zip(original['targets'],retained['ordered_target_positions_rad']))<1e-10
        assert abs(original['cost']-retained['selected_model_cost'])<1e-12
        step=observation['semantic_step'];loaded.append((step,state))
        probes.append(dict(step=step,support_margin_m=model.prior.margin(state.feet,state.com),plan=model.select(state)))
    assert len(loaded)==110
    return dict(original_loaded_plan_parity_count=110,
        loaded_poses_outside_modeled_support_hull=sum(p['support_margin_m']<0. for p in probes),
        support_margin_range_m=[min(p['support_margin_m'] for p in probes),max(p['support_margin_m'] for p in probes)],
        one_step_admissible_counts=dict(coupled_translation_and_level=sum(p['plan']['selected'] is not None for p in probes)),
        probes=probes,trajectories=[dict(start_step=step,variant='coupled_translation_and_level',result=model.propagate(state))
            for step,state in (loaded[0],loaded[-1])],**prior.CLAIMS)


def run():
    assert not RECORD.exists()
    out=EVIDENCE/('r10ah-support-centering-level-model-'+uuid.uuid4().hex)
    out.mkdir();print('R10AH_LEVEL_MODEL_ROOT '+str(out),flush=True)
    paths=[Path(__file__),Path(model.__file__),Path(model.prior.__file__),Path(model.geometry.__file__),
        Path(model.rollout.__file__),Path(prior.__file__),Path(closure.__file__),Path(closure.streams.__file__),
        Path(prior.snapshot.__file__),PROTOCOL,prior.PROTOCOL,prior.RECORD,closure.RECORD,closure.CHILD/'worker_report.json',
        ROOT/'tests/test_r10ah_support_centering_model.py',ROOT/'tests/test_r10ah_support_centering_level_model.py']
    before=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-before.json',before)
    source=prior.snapshot._source_snapshot();closure.write_new(out/'source-before.json',source)
    execution=dict(ok=False,**prior.CLAIMS)
    try:
        command=[sys.executable,'-B','-X','utf8','-m','unittest','discover','-s','tests','-p','test_r10ah_support_centering*model.py','-v']
        run=subprocess.run(command,cwd=ROOT,capture_output=True,timeout=60,creationflags=subprocess.CREATE_NO_WINDOW)
        (out/'controls.stdout.txt').write_bytes(run.stdout);(out/'controls.stderr.txt').write_bytes(run.stderr)
        execution.update(controls_command=command,controls_returncode=run.returncode)
        assert run.returncode==0 and b'Ran 9 tests' in run.stderr,run.stderr.decode()
        result=derive();closure.write_new(out/'result.json',result);execution['ok']=True
    except BaseException:
        execution['error']=traceback.format_exc();raise
    finally:
        after=[closure.bind(p) for p in paths];closure.write_new(out/'bindings-after.json',after)
        source_after=prior.snapshot._source_snapshot();closure.write_new(out/'source-after.json',source_after)
        execution['source_unchanged']=before==after and source==source_after
        closure.write_new(out/'execution.json',execution)
    assert execution['source_unchanged']
    record=dict(schema_version='sporespore_r10ah_support_centering_level_model_result_v2',
        ledger_scope=closure.read(PROTOCOL)['ledger_scope'],protocol=closure.bind(PROTOCOL),evidence_root=out.as_posix(),
        files=[closure.bind(p) for p in sorted(out.iterdir()) if p.is_file()],observed=prior.summary(result),claim_boundary=prior.CLAIMS)
    closure.write_new(RECORD,record);return record['observed']


def audit():
    record=closure.read(RECORD);assert record['claim_boundary']==prior.CLAIMS
    for item in [record['protocol'],*record['files']]:assert closure.bind(item['path'])==item
    out=Path(record['evidence_root']);before=closure.read(out/'bindings-before.json')
    assert before==closure.read(out/'bindings-after.json')
    for item in before:assert closure.bind(item['path'])==item,item['path']
    assert closure.read(out/'source-before.json')==closure.read(out/'source-after.json')
    execution=closure.read(out/'execution.json')
    assert execution['ok'] is True and execution['source_unchanged'] is True and execution['controls_returncode']==0
    controls=(out/'controls.stderr.txt').read_text()
    assert controls.count(' ... ok\n')==9 and controls.rstrip().endswith('OK')
    result=derive();assert result==closure.read(out/'result.json') and prior.summary(result)==record['observed']
    return record['observed']


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--run',action='store_true')
    print(json.dumps(run() if parser.parse_args().run else audit(),indent=2,allow_nan=False))
