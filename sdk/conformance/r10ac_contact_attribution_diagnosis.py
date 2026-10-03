"""Replay original foot-cap attribution from retained native contact samples.

The production boundary is preserved: lower cap center plus one micrometre.
No threshold search, changed classification, controller or physical execution.
"""
import argparse
import json
from pathlib import Path
import struct
import uuid
import r10ac_support_loss_diagnosis as base
ROOT, EVIDENCE = base.ROOT, base.EVIDENCE
TOLERANCE = 1.0e-6
WORLD = ROOT/'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd'
MORPHOLOGY = ROOT/'sdk/core/src/quadruped.rs'


def analyze(module, mode):
    report = module.CHILD/'worker_report.json'
    before = base.binding(report)
    assert before['raw_sha256'] == module.REPORT_SHA
    rows, matched, samples_seen = [], 0, 0
    for kind, packet in module.partial_records(report):
        if kind != 'packet': continue
        request = json.loads(packet['call']['request']['utf8_text'])
        observed = request['step']['observation']
        descriptor = request['collection']['descriptor']
        # ContactSiteSpec is -(0.35 * (1 - upper_fraction))/2; Godot stores
        # the compiled center in Vector3 binary32 before comparing local y.
        center = struct.unpack('<f',struct.pack('<f',-.35*(1-descriptor['upper_length_fraction'])/2))[0]
        receipt = packet['bound_observations']['source_component_receipts']['rotation_aware_source_component_receipts']['contact_source_receipt']
        assert receipt['semantic_step'] == observed['semantic_step']
        contacts = receipt['ordered_contact_samples']
        limbs = []
        for j, limb in enumerate(base.LIMBS):
            body = limb+'_distal'
            samples = [s for s in contacts if s['body_id']==body]
            for sample in samples:
                predicted = sample['position_body_local_m']['y'] <= center+TOLERANCE
                assert predicted == sample['classified_as_foot'], (observed['semantic_step'], limb, sample)
                matched += 1
            foot = sum(s['normal_impulse_ns'] for s in samples if s['classified_as_foot'])
            other = sum(s['normal_impulse_ns'] for s in samples if not s['classified_as_foot'])
            native_foot = observed['ordered_foot_bearing_observations'][j]['bearing_normal_impulse_ns']
            native_other = next(x for x in observed['ordered_body_clearance_observations'] if x['body_id']==body)['accumulated_nonfoot_normal_impulse_ns']
            assert abs(foot-native_foot)<1e-12 and abs(other-native_other)<1e-12
            limbs.append(dict(limb=limb,foot_impulse_ns=foot,nonfoot_impulse_ns=other,
                cap_center_local_y_m=center, samples=[dict(s,boundary_margin_m=s['position_body_local_m']['y']-center-TOLERANCE) for s in samples]))
        samples_seen += len(contacts)
        plan = packet['native_receipt']['next_load_plan']
        rows.append(dict(semantic_step=observed['semantic_step'],mode=plan['mode'] if plan else None,
            support_gate=packet['native_receipt']['step']['classification']['distal_support_gate'],limbs=limbs))
    assert len(rows)==646 and base.binding(report)==before
    transitions=[]
    for a,b in zip(rows,rows[1:]):
        if a['mode']!=mode:continue
        assert b['semantic_step']==a['semantic_step']+1
        losses=[f for f in b['limbs'] if f['foot_impulse_ns']==0]
        transitions.append(dict(semantic_step=a['semantic_step'],before=a,after=b,
            zero_foot_limbs=[f['limb'] for f in losses],
            zero_foot_with_nonfoot_load=[f['limb'] for f in losses if f['nonfoot_impulse_ns']>0]))
    summary=[]
    for j,limb in enumerate(base.LIMBS):
        lost=[t['after']['limbs'][j] for t in transitions if t['after']['limbs'][j]['foot_impulse_ns']==0]
        margins=[s['boundary_margin_m'] for f in lost for s in f['samples'] if not s['classified_as_foot']]
        summary.append(dict(limb=limb,zero_foot_cases=len(lost),
            nonfoot_load_in_zero_foot_cases=sum(f['nonfoot_impulse_ns']>0 for f in lost),
            nonfoot_contact_sample_count=len(margins),
            positive_margin_m=base.distribution(margins),
            margins_under_10_micrometres=sum(0<x<1e-5 for x in margins),
            margins_under_100_micrometres=sum(0<x<1e-4 for x in margins)))
    return dict(report=before,partial_samples=len(rows),contact_samples=samples_seen,distal_attribution_matches=matched,
        loaded_transitions=len(transitions),support_lost_next_step=sum(not t['after']['support_gate'] for t in transitions),
        transitions_with_zero_foot_and_nonfoot_load=sum(bool(t['zero_foot_with_nonfoot_load']) for t in transitions),
        feet=summary,transitions=transitions)


def run():
    assert 'const CONTACT_CLASSIFICATION_TOLERANCE_M := 1.0e-6' in WORLD.read_text(encoding='utf-8')
    assert 'y: -geometry.lower_length_m / 2.0,' in MORPHOLOGY.read_text(encoding='utf-8')
    out=EVIDENCE/('r10ac-contact-attribution-'+uuid.uuid4().hex);out.mkdir()
    result=dict(schema_version='sporespore_r10ac_contact_attribution_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='offline_native_contact_attribution_replay',question_class='development'),
        analyses={},production_tolerance_m=TOLERANCE,threshold_modified=False,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False,original_results_regraded=False,
        comparative_authority=False,causal_mechanism_proven=False)
    for name,module,mode in base.SOURCES:
        value=analyze(module,mode);base.write(out/(name+'-transitions.json'),value.pop('transitions'))
        value['transition_artifact']=base.binding(out/(name+'-transitions.json'));result['analyses'][name]=value
        print(name+' '+json.dumps(value),flush=True)
    result['source_bindings']=[base.binding(p) for p in (Path(__file__),Path(base.__file__),WORLD,MORPHOLOGY)]
    base.write(out/'result.json',result)
    print('R10AC_CONTACT_ATTRIBUTION_ROOT '+str(out),flush=True)


if __name__=='__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    run()
