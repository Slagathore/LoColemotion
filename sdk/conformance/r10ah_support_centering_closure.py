"""Close three unsuccessful mathematical variants without physical exposure."""
import argparse
import json
from pathlib import Path

import r10ah_support_centering_probe as first
import r10ah_support_centering_level_probe as second

closure=first.closure
RECORD=first.ROOT/'sdk/recovery/r10ah_support_centering_model_closure_v1.json'
DECISION='Reject all three center-first model variants as candidates for native integration or physical commissioning in their current form.'
NEXT='Design and check a feasible path through the measured joint constraints while coordinating body motion and foot placement. Do not require monotone COM centering before any rise unless the complete bounded path is demonstrated. Preserve task thresholds, consumed populations and the pending full positive hold/walking consumer coverage requirement.'


def observed(reproduce):
    a=first.audit() if reproduce else closure.read(first.RECORD)['observed']
    b=second.audit() if reproduce else closure.read(second.RECORD)['observed']
    assert a['original_loaded_plan_parity_count']==b['original_loaded_plan_parity_count']==110
    assert a['loaded_poses_outside_modeled_support_hull']==b['loaded_poses_outside_modeled_support_hull']==110
    paths=a['trajectories']+b['trajectories']
    assert len(paths)==6 and [p['updates'] for p in paths]==[12,11,1,3,12,2]
    assert all(p['stop']=='no_admissible_plan' and p['first_centered_update'] is None
        and p['mode_counts']['raise_body']==0 and p['final_support_margin_m']<0. for p in paths)
    return dict(model_variants=3,bounded_trajectories=6,stalled_trajectories=6,
        centered_trajectories=0,modeled_rise_trajectories=0,
        original_loaded_plan_parity_count=110,
        modeled_com_outside_support_polygon_on_all_loaded_inputs=True,
        support_margin_range_m=a['support_margin_range_m'],
        step_counts=[p['updates'] for p in paths],
        original_attempt_reclassified=False,new_physical_population_consumed=False,
        native_controller_implemented=False,complete_positive_consumer_coverage=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False,
        sdk1_score='14/20',full_program_score='14/25')


def create():
    assert not RECORD.exists()
    result=observed(True)
    record=dict(schema_version='sporespore_r10ah_support_centering_model_closure_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',
            authority_mode='post_exposure_mathematical_probe_closure',question_class='development'),
        dependencies=[closure.bind(p) for p in (Path(__file__),first.RECORD,second.RECORD)],
        observed=result,decision=DECISION,next_action=NEXT,
        limitation='Negative under the declared bounded candidate searches and perfect-tracking assumptions. This does not prove centering is generally impossible, does not predict dynamics, and does not establish an alternative physical controller.')
    closure.write_new(RECORD,record);return result


def audit():
    record=closure.read(RECORD)
    for item in record['dependencies']:assert closure.bind(item['path'])==item
    assert record['decision']==DECISION and record['next_action']==NEXT
    result=observed(True);assert result==record['observed']
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--create',action='store_true')
    print(json.dumps(create() if parser.parse_args().create else audit(),indent=2))
