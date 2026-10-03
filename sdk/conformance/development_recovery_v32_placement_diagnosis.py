"""V32 measured placement decomposition; no alternative trajectory or new physics.

Torso translation, torso rotation at initial joints, then joint change at the
final torso pose is an EXPLICIT algebraic order. It is not causal attribution.
Observed hinge compliance remains in the residual instead of being discarded.
"""
import argparse
import hashlib
import json
import math
import re
import subprocess
from pathlib import Path

import development_recovery_v28_contact_geometry as geometry

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '987a8848999d457a820c078eb9273dbb'
SOURCE = '10e6310b678d0aadaeb1bb64b1aae5d113c4f332'
LIMBS = ('rear_left', 'front_left', 'rear_right', 'front_right')


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def relaxed_fixed_torso_bottom(torso, limb, dimensions):
    """Lower bound with unrestricted planar angles and perfectly aligned links.

    Positive means the foot cannot reach floor y=0 with this torso pose held
    fixed even after relaxing joint limits. It predicts no future torso pose.
    """
    upper, lower, radius, span = dimensions
    forward, up, side = (geometry.rotate(torso['orientation_xyzw'], axis)
                         for axis in ([1, 0, 0], [0, 1, 0], [0, 0, 1]))
    anchor_y = span*((.2 if limb.startswith('front') else -.2)*forward[1]
                     + (-.18 if limb.endswith('left') else .18)*side[1])
    return torso['position_m']['y'] + anchor_y - (upper+lower)*math.hypot(forward[1], up[1]) - radius


def summarize(report):
    source = subprocess.check_output(['git', 'show', SOURCE + ':sdk/core/src/runtime.rs'], cwd=ROOT)
    constants = {}
    for name in ('CYCLE_STEPS', 'SWING_STEPS', 'KNEE_SWING_FLEXION_RAD', 'KNEE_FLEXION_SCALE', 'CONTACT_CLEARANCE_ASSIST_RAD'):
        values = re.findall(r'const ' + name + r': (?:u64|f64) = ([0-9.]+);', source.decode())
        if len(values) != 1:
            raise ValueError('V32_PLACEMENT_FROZEN_CONSTANT:' + name)
        constants[name] = float(values[0])
    measured, frame_error = geometry.reconstruct(report)
    body = {(row['limb'], row['trace_local_step']): row for row in measured}
    entries = {int(row['session_local_step']): row for row in report['development_walking_entry']['rows']}
    native = {int(row['session_local_step'])-1: row['native_source']
              for row in report['development_native_walking_contacts']['rows'] if row['segment_id'] == 'walking_resume'}
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    trace = [row for row in report['retained_arm']['trace_rows'] if row.get('walking_session_id') == session['session_id']]
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    descriptor = report['configuration']['base_descriptor']
    upper = .35 * descriptor['upper_length_fraction']
    dimensions = (upper, .35-upper, .04*descriptor['foot_radius_scale'], descriptor['hip_span_scale'])

    def phase(limb, local):
        memory = next(m for m in entries[local]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)
        return int((memory['gait_step'] + constants['CYCLE_STEPS'] - LIMBS.index(limb)*constants['CYCLE_STEPS']/4) % constants['CYCLE_STEPS'])

    def decomposition(limb, first, last):
        a, b = body[limb, first], body[limb, last]
        pa, pb = (native[local]['observation']['state']['base_pose_world'] for local in (first, last))
        aa, aa_bottom = geometry.ideal_distal(pa, limb, a['hip_rad'], a['knee_rad'], *dimensions)
        ba, ba_bottom = geometry.ideal_distal(pb, limb, a['hip_rad'], a['knee_rad'], *dimensions)
        bb, bb_bottom = geometry.ideal_distal(pb, limb, b['hip_rad'], b['knee_rad'], *dimensions)
        ta, tb = (native[local]['precommand_trace']['foot_position_world_m_by_limb'][limb] for local in (first, last))
        translation = [pb['position_m'][key]-pa['position_m'][key] for key in 'xyz']
        rotation = [ba[i]-aa[i]-translation[i] for i in range(3)]
        joints = [bb[i]-ba[i] for i in range(3)]
        actual = [tb[i]-ta[i] for i in range(3)]
        residual = [actual[i]-translation[i]-rotation[i]-joints[i] for i in range(3)]
        forward = {name: sum(value[i]*axis[i] for i in range(3)) for name, value in
                   dict(actual=actual, torso_translation=translation, torso_rotation_at_initial_joints=rotation,
                        joint_change_at_final_pose=joints, ideal_constraint_residual=residual).items()}
        clearance = dict(actual=b['nominal_capsule_bottom_m']-a['nominal_capsule_bottom_m'],
                         torso_translation=translation[1], torso_rotation_at_initial_joints=ba_bottom-aa_bottom-translation[1],
                         joint_change_at_final_pose=bb_bottom-ba_bottom)
        clearance['ideal_constraint_residual'] = clearance['actual']-sum(value for name, value in clearance.items() if name != 'actual')
        return dict(forward_components_m=forward, clearance_change_components_m=clearance,
                    hip_start_end_rad=[a['hip_rad'], b['hip_rad']], knee_start_end_rad=[a['knee_rad'], b['knee_rad']])

    cycles, gaps = [], {}
    for limb in LIMBS:
        previous, start = True, None
        for row in trace:
            contact, local = row['contact_by_limb'][limb], row['walking_session_local_step']
            if previous and not contact:
                start = local
            elif not previous and contact and start is not None:
                if local-start >= session['evaluation']['fixed_thresholds']['minimum_airborne_dwell_steps']:
                    data = decomposition(limb, start, local)
                    span = [r for r in measured if r['limb'] == limb and start <= r['trace_local_step'] < local]
                    relaxed = [relaxed_fixed_torso_bottom(native[t]['observation']['state']['base_pose_world'], limb, dimensions)
                               for t in range(start, local)]
                    data.update(limb=limb, liftoff_trace_local=start, touchdown_trace_local=local,
                                liftoff_command_phase=phase(limb, start),
                                started_during_scheduled_swing=phase(limb, start) < constants['SWING_STEPS'],
                                nominal_floor_clearance_max_m=max(r['nominal_capsule_bottom_m'] for r in span),
                                raw_contact_sample_count=sum(r['raw_contact_count'] for r in span),
                                relaxed_fixed_torso_bottom_min_m=min(relaxed), relaxed_fixed_torso_bottom_max_m=max(relaxed),
                                relaxed_fixed_torso_cannot_reach_floor_sample_count=sum(x > 0 for x in relaxed))
                    data['forward_placement_passed'] = data['forward_components_m']['actual'] >= session['evaluation']['fixed_thresholds']['minimum_foot_relocation_m']
                    cycles.append(data)
                start = None
            previous = contact
        gaps[limb] = None if start is None else dict(first_trace_local=start, observed_samples=401-start,
                                                     liftoff_command_phase=phase(limb, start))

    knee_errors, discontinuities = [], []
    for local, entry in entries.items():
        contact = {c['contact_site_id'].removesuffix('_foot'): c['bears_support'] for c in entry['request']['state']['ordered_contact_observations']}
        commands = {c['actuator_id']: c for c in entry['native_output']['actuation']['ordered_commands']}
        amplitude = entry['request']['command']['gait_amplitude']
        for limb in LIMBS:
            p = phase(limb, local)
            envelope = math.sin(math.pi*p/constants['SWING_STEPS']) if p < constants['SWING_STEPS'] else 0.
            base = amplitude*constants['KNEE_SWING_FLEXION_RAD']*constants['KNEE_FLEXION_SCALE']*envelope
            assist = amplitude*constants['CONTACT_CLEARANCE_ASSIST_RAD'] if p < constants['SWING_STEPS'] and contact[limb] else 0.
            actual = commands[limb+'_knee_motor']['requested_target_position_rad']
            knee_errors.append(abs(actual-base-assist))
            if local > 1 and p < constants['SWING_STEPS']:
                before = entries[local-1]
                prior_contact = next(c['bears_support'] for c in before['request']['state']['ordered_contact_observations'] if c['contact_site_id'] == limb+'_foot')
                if prior_contact != contact[limb]:
                    prior_target = next(c['requested_target_position_rad'] for c in before['native_output']['actuation']['ordered_commands'] if c['actuator_id'] == limb+'_knee_motor')
                    discontinuities.append(dict(limb=limb, input_trace_local=local-1, commanded_local=local,
                        scheduled_phase=p, support_before=prior_contact, support_now=contact[limb],
                        knee_target_before_rad=prior_target, knee_target_now_rad=actual,
                        total_target_change_rad=actual-prior_target,
                        same_input_contact_toggle_difference_rad=amplitude*constants['CONTACT_CLEARANCE_ASSIST_RAD']))
    failed = [c for c in cycles if not c['forward_placement_passed']]
    return dict(schema_version='sporespore_development_v32_placement_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_diagnosis', question_class='development'),
        source_commit=SOURCE, runtime_source_sha256=digest(source), frozen_constants=constants,
        measured_body_sample_count=len(measured), coordinate_conversion_maximum_axis_difference=frame_error,
        verified_knee_command_count=len(knee_errors), maximum_knee_formula_error_rad=max(knee_errors),
        counted_cycles=cycles, failed_cycle_count=len(failed),
        failed_cycles_started_during_scheduled_stance=sum(not c['started_during_scheduled_swing'] for c in failed),
        terminal_contact_gaps=gaps, swing_contact_target_discontinuities=discontinuities,
        original_false_walking_receipts=session['evaluation']['false_walking_receipts'],
        interpretation_limit='Complete observed cycle population; explicit-order geometric accounting is not causal isolation. Knee targets can change discontinuously with contact, but this does not establish the cause of touchdown. Nominal shape clearance is not a replacement contact predicate. Trace 400 has no retained next-command body pose, so it is not reconstructed.',
        physical_cause_proven=False, alternate_physical_outcome_predicted=False, original_evaluation_changed=False,
        world_build_count=0, solver_step_count=0, additional_native_physics_read_count=0,
        physical_acceptance_authority=False, release_authority=False)


def observe():
    path = ROOT / 'sdk/development/recovery_attempts' / (ATTEMPT + '.json')
    raw = path.read_bytes()
    closure = json.loads(raw)
    report_path = Path(closure['kicked_report']['path'])
    report_raw = report_path.read_bytes()
    if digest(report_raw) != closure['kicked_report']['raw_sha256'] or closure['source_snapshot']['head'] != SOURCE:
        raise ValueError('V32_PLACEMENT_SOURCE_DRIFT')
    result = summarize(json.loads(report_raw))
    result['source_closure'] = dict(path=path.relative_to(ROOT).as_posix(), raw_sha256=digest(raw))
    result['source_report'] = closure['kicked_report']
    result['analysis_sources'] = [dict(path=p, raw_sha256=digest((ROOT / p).read_bytes())) for p in (
        'sdk/conformance/development_recovery_v32_placement_diagnosis.py',
        'sdk/conformance/development_recovery_v28_contact_geometry.py',
        'tests/test_development_v32_placement_diagnosis.py')]
    return result


if __name__ == '__main__':
    argparse.ArgumentParser(description=__doc__).parse_args()
    print(json.dumps(observe(), indent=2, allow_nan=False))
