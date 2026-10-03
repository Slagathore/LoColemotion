"""Reusable retained-data summary for explicit feasible-support walking profiles.

No native library, world, alternate rollout, threshold or evaluator is invoked.
Contact cycles use the original post-command trace and original dwell threshold.
"""
import argparse
import hashlib
import json
from pathlib import Path


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def summarize(report):
    rows = report['development_walking_entry']['rows']
    session = next(s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    trace = [r for r in report['retained_arm']['trace_rows'] if r.get('walking_session_id') == session['session_id']]
    assert len(rows) == len(trace) == session['evaluation']['trace_row_count']
    floor = session['start_receipt']['development_floor_source']
    plans, per_limb, phases = [], [], {}
    for local, row in enumerate(rows, 1):
        assert row['session_local_step'] == trace[local - 1]['walking_session_local_step'] == local
        assert row['development_floor_source'] == floor
        assert row['request']['floor_reference'] == floor['floor_reference']
        receipt = row['native_output']['actuation']['receipt']['recovery_support_plane']
        assert receipt['mode_id'] == 'explicit_floor_joint_feasible_stance_height_reference_slew_v1'
        plans.append(receipt['feasible_support_plan'])
        phases[local] = {p['limb_id']: p['scheduled_phase_step'] for p in receipt['ordered_limb_proposals']}
    evaluation = session['evaluation']
    axis = session['start_receipt']['task_frame_forward_axis_world_host_real']
    for limb in trace[-1]['contact_by_limb']:
        swings, holds, cycles = [], [], []
        bearing, release = True, None  # Selected session is independently verified four-contact at entry.
        for local, (row, measured) in enumerate(zip(rows, trace), 1):
            before = next(m for m in row['request']['memory']['ordered_limb_memory'] if m['limb_id'] == limb)
            after = next(m for m in row['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)
            if phases[local][limb] < 72:
                swings.append(local)
            if after['recontact_hold_step_count'] > before['recontact_hold_step_count']:
                assert after['recontact_hold_step_count'] == before['recontact_hold_step_count'] + 1
                if not holds or holds[-1][-1] != local - 1:
                    holds.append([])
                holds[-1].append(local)
            present = measured['contact_by_limb'][limb]
            if bearing and not present:
                release = measured
            elif not bearing and present and release is not None:
                start = release['walking_session_local_step']
                if local - start >= evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']:
                    forward = sum((measured['foot_position_world_m_by_limb'][limb][i] - release['foot_position_world_m_by_limb'][limb][i]) * axis[i] for i in range(3))
                    cycles.append(dict(liftoff_local_step=start, touchdown_local_step=local,
                        airborne_steps=local-start, distal_body_origin_forward_relocation_m=forward,
                        original_minimum_relocation_passed=forward >= evaluation['fixed_thresholds']['minimum_foot_relocation_m'],
                        scheduled_swing_or_landing_command_overlap_count=sum(phases[n][limb] <= 72 for n in range(start, local+1))))
                release = None
            bearing = present
        assert len(cycles) == evaluation['contact_cycle_count_by_limb'][limb]
        assert (min(c['distal_body_origin_forward_relocation_m'] for c in cycles) if cycles else None) == evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb]
        final = next(m for m in rows[-1]['native_output']['next_memory']['ordered_limb_memory'] if m['limb_id'] == limb)
        per_limb.append(dict(limb=limb, first_scheduled_swing_command=swings[0] if swings else None,
            last_scheduled_swing_command=swings[-1] if swings else None, scheduled_swing_command_count=len(swings),
            recontact_hold_intervals=[dict(first=g[0], last=g[-1], count=len(g)) for g in holds],
            terminal_scheduled_phase_step=phases[len(rows)][limb], terminal_contact=bearing,
            terminal_native_gate_timeout_count=final['gate_timeout_count'], contact_cycles=cycles))
    heights = [p['measured_torso_height_m'] for p in plans]
    return dict(command_count=len(rows), lowering_requested_steps=sum(p['requested_lowering_m'] > 0 for p in plans),
        maximum_requested_lowering_m=max(p['requested_lowering_m'] for p in plans),
        empty_common_intersection_steps=sum(not p['common_height_interval_nonempty'] for p in plans),
        lowering_participant_limb_commands=sum(len(p['ordered_lowering_participant_limb_ids']) for p in plans),
        measured_precommand_torso_height_m=dict(first=heights[0], minimum=min(heights), maximum=max(heights), last=heights[-1]),
        original_walking_evaluation=evaluation, per_limb=per_limb)


def observe(closure_path):
    raw = closure_path.read_bytes()
    closure = json.loads(raw)
    source = closure['kicked_report']
    report_raw = Path(source['path']).read_bytes()
    if len(report_raw) != source['byte_length'] or digest(report_raw) != source['raw_sha256']:
        raise ValueError('FEASIBLE_SUPPORT_OBSERVATION_REPORT_DRIFT')
    report = json.loads(report_raw)
    if report['source_commit'] != closure['source_snapshot']['head']:
        raise ValueError('FEASIBLE_SUPPORT_OBSERVATION_SOURCE_CROSSED')
    return dict(schema_version='sporespore_development_feasible_support_observation_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='post_exposure_retained_data_description',question_class='development'),
        source_closure=dict(path=closure_path.as_posix(),raw_sha256=digest(raw)), source_report=source,
        analysis_source=dict(path='sdk/conformance/development_recovery_feasible_support_observation.py',raw_sha256=digest(Path(__file__).read_bytes())),
        selection_rule='Every retained resumed command and every original dwell-qualified contact cycle; no outcome-selected episode subset.',
        observation=summarize(report),
        limits='Measured height changes are not causal attribution to the requested lowering. A contact cycle is not necessarily a scheduled swing. Foot coordinates are distal-body origins, not sole contact points. The final pre-command pose is not an invented post-terminal body pose. Original evaluation is preserved.',
        new_world_build_count=0,new_solver_step_count=0,new_native_physics_read_count=0,
        original_evaluation_changed=False,physical_cause_proven=False,alternate_outcome_predicted=False,
        physical_acceptance_authority=False,release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('closure',type=Path)
    print(json.dumps(observe(parser.parse_args().closure),indent=2,allow_nan=False))
