"""Describe retained V23 contact cycles; never regrade its invalid attempt.

The existing evaluator calls these foot positions, but their actual producer
records distal rigid-body origins. Keep that distinction in the output.
"""
import json
from pathlib import Path

import development_recovery_candidate as candidate

ROOT = candidate.ROOT
ORIGINAL = 'sdk/development/recovery_attempts/92dd4a7de9124bd6bde70dd7a9042843.json'
ORIGINAL_SHA = 'sha256:e1fe74012d27269c081a36971e57e674df09c3d8640adc3ece1b5b70e21fd4f8'


def diagnose():
    candidate.require(candidate.sha(ROOT / ORIGINAL) == ORIGINAL_SHA, 'CYCLE_ORIGINAL_DRIFT')
    original = candidate.read(ROOT / ORIGINAL)
    path = Path(original['kicked_report']['path'])
    candidate.require(candidate.sha(path) == original['kicked_report']['raw_sha256'], 'CYCLE_REPORT_DRIFT')
    report = candidate.read(path)
    arm = report['retained_arm']
    session = next(s for s in arm['walking_sessions'] if s['evaluation_segment_id'] == 'walking_resume')
    evaluation = session['evaluation']
    start = session['start_receipt']
    rows = [r for r in arm['trace_rows'] if r.get('walking_session_id') == session['session_id']]
    initial = arm['trace_rows'][start['global_start_step'] - 1]['contact_by_limb']
    candidate.require(all(initial.values()), 'CYCLE_EXPECTED_V23_INITIAL_CONTACTS')
    forward = start['task_frame_forward_axis_world_host_real']
    commands = {r['commanded_global_step']: r for r in report['development_walking_entry']['rows']}
    native = {r['commanded_global_step'] - 1: r['native_source']
              for r in report['development_native_walking_contacts']['rows']}
    minimum_dwell = evaluation['fixed_thresholds']['minimum_airborne_dwell_steps']
    minimum_forward = evaluation['fixed_thresholds']['minimum_foot_relocation_m']
    cycles, open_flights, short_flights = [], {}, {}
    for limb in initial:
        bearing, release = initial[limb], None
        short_flights[limb] = 0
        for row in rows:
            current = row['contact_by_limb'][limb]
            if bearing and not current:
                release = row
            elif not bearing and current and release is not None:
                first, last = release['global_semantic_step'], row['global_semantic_step']
                dwell = last - first
                if dwell >= minimum_dwell:
                    before, after = (r['foot_position_world_m_by_limb'][limb] for r in (release, row))
                    displacement = sum((after[i] - before[i]) * forward[i] for i in range(3))
                    contact_kinds = dict(no_distal_contact=0, nonfoot_only=0, foot_zero_impulse=0, bearing=0)
                    for step in range(first, last):
                        source = native[step]
                        raw = [p for p in source['contact_source_receipt']['ordered_contact_samples'] if p['body_id'] == limb + '_distal']
                        contact = next(c for c in source['observation']['state']['ordered_contact_observations'] if c['contact_site_id'] == limb + '_foot')
                        candidate.require(contact['bears_support'] == arm['trace_rows'][step-1]['contact_by_limb'][limb], 'CYCLE_NATIVE_CONTACT_LINK')
                        kind = ('no_distal_contact' if not raw else 'nonfoot_only' if not any(p['classified_as_foot'] for p in raw)
                                else 'foot_zero_impulse' if not contact['bears_support'] else 'bearing')
                        contact_kinds[kind] += 1
                    cycles.append(dict(limb=limb, release_local_step=release['walking_session_local_step'],
                        touchdown_local_step=row['walking_session_local_step'], release_global_step=first,
                        touchdown_global_step=last, nonbearing_step_count=dwell, forward_relocation_m=displacement,
                        meets_original_relocation_requirement=displacement >= minimum_forward,
                        release_amplitude=commands[first]['request']['command']['gait_amplitude'],
                        touchdown_amplitude=commands[last]['request']['command']['gait_amplitude'],
                        native_nonbearing_contact_classification=contact_kinds))
                else:
                    short_flights[limb] += 1
                release = None
            bearing = current
        selected = [c for c in cycles if c['limb'] == limb]
        candidate.require(len(selected) == evaluation['contact_cycle_count_by_limb'][limb], 'CYCLE_COUNT_MISMATCH')
        # Roundoff check only, not a behavioral threshold or a new result grade.
        candidate.require(abs(min(c['forward_relocation_m'] for c in selected)
                              - evaluation['minimum_cycle_forward_relocation_by_limb_m'][limb]) <= 1e-15, 'CYCLE_MINIMUM_MISMATCH')
        open_flights[limb] = (None if release is None else dict(release_local_step=release['walking_session_local_step'],
                             nonbearing_steps_through_cutoff=rows[-1]['global_semantic_step']-release['global_semantic_step']+1))
    failed = [c for c in cycles if not c['meets_original_relocation_requirement']]
    return dict(schema_version='sporespore_retained_walking_cycle_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_data_description', question_class='development'),
        original_closure=dict(path=ORIGINAL, raw_sha256=ORIGINAL_SHA), original_status=original['status'],
        original_report=original['kicked_report'], session_id=session['session_id'], trace_row_count=len(rows),
        analysis_source=dict(path='sdk/conformance/development_recovery_walking_cycle_diagnosis.py', raw_sha256=candidate.sha(Path(__file__))),
        position_definition='Distal rigid-body origins, projected onto the original fixed walking forward axis; not sole/contact-point travel.',
        nonbearing_definition='Existing qualified native foot bears_support flag is false; raw native distal contact samples distinguish absence from classification or zero impulse.',
        original_fixed_thresholds=evaluation['fixed_thresholds'], original_false_walking_receipts=evaluation['false_walking_receipts'],
        original_counts_and_minima_reproduced=True, counted_cycles=len(cycles), failed_relocation_cycles=len(failed),
        failed_cycles_entirely_at_full_amplitude=sum(c['release_amplitude'] == c['touchdown_amplitude'] == 1 for c in failed),
        cycles=cycles, uncounted_short_touchdown_count_by_limb=short_flights, open_flight_at_cutoff_by_limb=open_flights,
        terminal_contact_by_limb=rows[-1]['contact_by_limb'],
        inference='The recorded relocation failures are not all warmup-only or qualified-contact filtering. Extending the same run cannot undo failed completed cycles. These data alone do not establish why the limbs lost contact or predict a corrective controller.',
        original_attempt_reclassified=False, evaluation_regraded=False, causal_attribution_proven=False,
        complete_route_proven=False, successful_recovery_proven=False, physical_acceptance_authority=False,
        release_authority=False, world_build_count=0, native_physics_read_count=0, solver_step_count=0)


if __name__ == '__main__':
    print(json.dumps(diagnose(), indent=2, allow_nan=False))
