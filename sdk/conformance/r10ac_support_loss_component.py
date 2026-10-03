"""Reproduce the retained R10AA/R10AB support-loss diagnosis without physics."""
import argparse
import json
from pathlib import Path
import r10ac_support_loss_diagnosis as motion
import r10ac_contact_attribution_diagnosis as contact
ROOT, EVIDENCE = motion.ROOT, motion.EVIDENCE
RECORD = ROOT/'sdk/recovery/r10ac_support_loss_component_v1.json'
MOTION = EVIDENCE/'r10ac-support-loss-diagnosis-d3cf1f47044b4a44bc713298a42e3ea5'
CONTACT = EVIDENCE/'r10ac-contact-attribution-5a9d6c0896a64429a909cbd49953b5a0'
WRAPPERS = [EVIDENCE/name for name in ('r10ac-diagnosis-check-c1928873997c4ddbbeaf0db0d0cc2082','r10ac-contact-check-50dc007465a44d6f81b053dc872e6b93')]
FAILED = EVIDENCE/'r10ac-diagnosis-check-3b56ec38d8234f59bcd691bd8415b701'
CLOSURES = EVIDENCE/'r10ac-closure-check-4a405586bbbf4c1ba24e28d3f76fc46f'
read = lambda p: json.loads(Path(p).read_text(encoding='utf-8-sig'))


def observations():
    m, c = read(MOTION/'result.json'), read(CONTACT/'result.json')
    for value in (m,c):
        assert value['world_build_count']==value['solver_step_count']==0
        assert value['physical_acceptance_authority'] is value['release_authority'] is value['causal_mechanism_proven'] is False
        assert value['original_results_regraded'] is value['comparative_authority'] is False
    assert c['production_tolerance_m']==1e-6 and c['threshold_modified'] is False
    for row in c['source_bindings']+[m['analysis_source'],m['geometry_source']]:assert motion.binding(row['path'])==row
    for label,module,mode in motion.SOURCES:
        source,descriptor,rows = motion.extract(module)
        measured = motion.analyze(descriptor,rows,mode)
        assert measured.pop('transitions') == read(MOTION/(label+'-transitions.json'))
        assert measured == m['analyses'][label]
        assert source == m['sources'][label]['report']
        replay = contact.analyze(module,mode)
        assert replay.pop('transitions') == read(CONTACT/(label+'-transitions.json'))
        retained = dict(c['analyses'][label]); artifact = retained.pop('transition_artifact')
        assert motion.binding(artifact['path']) == artifact and replay == retained
        assert read(CLOSURES/(label+'.execution.json'))['exit_code']==0
        assert (CLOSURES/(label+'.stderr.log')).read_bytes()==b''
    for folder in WRAPPERS:
        assert read(folder/'execution.json')['exit_code']==0
        assert (folder/'stderr.log').read_bytes()==b''
    assert read(FAILED/'execution.json')['exit_code']==1
    assert 'ImportError' in (FAILED/'stderr.log').read_text(encoding='utf-8-sig')
    ab=c['analyses']['r10ab']; aa=c['analyses']['r10aa']
    assert ab['loaded_transitions']==ab['support_lost_next_step']==ab['transitions_with_zero_foot_and_nonfoot_load']==34
    assert [f['zero_foot_cases'] for f in ab['feet']]==[11,0,0,32]
    assert [f['nonfoot_load_in_zero_foot_cases'] for f in ab['feet']]==[11,0,0,32]
    return dict(ok=True,observed_partial_samples=1292,loaded_transitions=dict(r10aa=44,r10ab=34),
        replayed_distal_contact_classifications=aa['distal_attribution_matches']+ab['distal_attribution_matches'],
        r10ab_loaded_failures_with_nonfoot_distal_load=34,
        r10ab_zero_foot_counts_by_limb=[11,0,0,32],
        r10ab_front_left_margin_m=ab['feet'][0]['positive_margin_m'],
        r10ab_rear_right_margin_m=ab['feet'][3]['positive_margin_m'],
        r10aa_loaded_transitions_with_nonfoot_distal_load=aa['transitions_with_zero_foot_and_nonfoot_load'],
        modeled_joint_only_down_all_r10ab_limbs=all(f['realized_joint_only_up']==0 and f['planned_down']==34 for f in m['analyses']['r10ab']['feet']),
        modeled_world_endpoint_up_count=sum(f['realized_total_up'] for f in m['analyses']['r10ab']['feet']),
        classification_tolerance_m=1e-6,original_closures_reaudited=True,original_results_regraded=False,
        physical_contact_motion_cause_proven=False,host_callback_coherent_in_source=True,
        counterfactual_physics_predicted=False,successor_controller_declared=False,
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def capture():
    assert not RECORD.exists()
    result=observations()
    assert result['replayed_distal_contact_classifications']==5112
    evidence=[p for folder in (MOTION,CONTACT,*WRAPPERS,FAILED,CLOSURES) for p in sorted(folder.iterdir()) if p.is_file()]
    paths=[Path(__file__),Path(motion.__file__),Path(contact.__file__),
        ROOT/'sdk/conformance/r10ab_loaded_rise_diagnosis.py',
        ROOT/'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd',
        ROOT/'scripts/lab/mechanics/semantic_contact_rigid_body.gd', ROOT/'sdk/core/src/quadruped.rs',
        motion.aa.RECORD,motion.ab.RECORD]
    motion.write(RECORD,dict(schema_version='sporespore_r10ac_support_loss_component_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='offline_retained_contact_attribution_diagnosis',question_class='development'),
        source_bindings=[motion.binding(p) for p in paths],retained_evidence=[motion.binding(p) for p in evidence],observed=result,
        inference='R10AB loses the counted foot-cap load while the same distal limb retains nonfoot load in every loaded-rise failure. The original attribution boundary exactly reproduces the raw samples; these observations do not establish whether pose geometry, engine contact sampling or another mechanism places the points outside the cap.',
        next_action='Inspect native distal orientation and contact-point sampling relative to the cap boundary before declaring any controller successor. Preserve all thresholds and consumed populations.'))
    return result


def audit():
    value=read(RECORD)
    for row in value['source_bindings']+value['retained_evidence']:assert motion.binding(row['path'])==row
    result=observations()
    assert result==value['observed']
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--capture',action='store_true')
    print('R10AC_SUPPORT_LOSS_COMPONENT '+json.dumps(capture() if parser.parse_args().capture else audit()),flush=True)
