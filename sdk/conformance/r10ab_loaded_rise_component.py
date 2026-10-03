"""Audit R10AB's retained offline rise diagnosis, never physical qualification."""
import argparse
import hashlib
import json
from pathlib import Path

import r10ab_loaded_rise_diagnosis as probe

ROOT, EVIDENCE = probe.ROOT, probe.EVIDENCE
RUN = EVIDENCE / 'r10ab-loaded-rise-probe-155ed65ee65142188a470cf75aac4bdf'
RECORD = ROOT / 'sdk/recovery/r10ab_loaded_rise_component_v1.json'
binding = probe.closed.binding
read = lambda path: json.loads(path.read_text(encoding='utf-8-sig'))


def observations():
    execution = read(RUN / 'execution.json')
    assert execution['exit_code'] == 0 and execution['source_unchanged'] is True
    digest = hashlib.sha256(Path(probe.__file__).read_bytes()).hexdigest().upper()
    assert execution['source_sha256_before'] == execution['source_sha256_after'] == digest
    assert (RUN / 'stderr.log').read_bytes() == b''
    retained = read(RUN / 'result.json')
    assert retained == probe.derive()
    summary = retained['loaded_event_summary']
    assert retained['exposed_observations'] == 646
    assert retained['retained_loaded_plan_parity_count'] == summary['count'] == 44
    assert summary['all_joint_direction_alignments'] == 352
    assert summary['alternative_feasibility_counts'] == dict(original=44, downward_quarter=44, translation_only=44)
    assert summary['lost_foot_counts'] == [27, 44, 2, 24]
    assert summary['original_upward_foot_target_counts'] == [7, 22, 0, 0]
    for row in retained['observations']:
        selected = row['alternatives'].get('downward_quarter')
        if selected is not None:
            rise = selected['translation'][1]
            assert rise > 0 and selected['lateral_residual'] <= .0005
            assert all(y <= -.25*rise+1e-12 for y in selected['fixed_torso_foot_dy'])
            assert all(abs(q) <= (1.6 if i % 2 == 0 else 1.1) for i,q in enumerate(selected['targets']))
            assert max(abs(a-b) for a,b in zip(selected['targets'],row['joints'])) <= 4/120
    assert retained['world_build_count'] == retained['solver_step_count'] == 0
    return dict(ok=True, exposed_observations=646, retained_loaded_plan_parity_count=44,
        full_offline_reconstruction_matches=True, loaded_event_summary=summary,
        prospective_controller_implemented=False, physical_load_retention_proven=False,
        original_result_regraded=False, world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    assert not RECORD.exists()
    result = observations()
    files = [p for p in sorted(RUN.iterdir()) if p.is_file()]
    value = dict(schema_version='sporespore_r10ab_loaded_rise_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',
                          authority_mode='retained_input_offline_diagnosis',question_class='development'),
        dependencies=[binding(p) for p in (Path(__file__),Path(probe.__file__),probe.KERNEL,probe.closed.RECORD)],
        retained_evidence=[binding(p) for p in files], observed=result,
        next_action='Declare and implement a distinct loaded-rise downward-foot constraint; validate it before any new native diagnostic. Preserve all consumed results and original acceptance conditions.')
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:
        json.dump(value,stream,indent=2,allow_nan=False);stream.write('\n')
    return result


def audit():
    value=read(RECORD)
    for row in value['dependencies']+value['retained_evidence']:
        assert row == binding(Path(row['path']))
    result=observations();assert result==value['observed'];return result


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    print(json.dumps(capture() if parser.parse_args().capture else audit()))
