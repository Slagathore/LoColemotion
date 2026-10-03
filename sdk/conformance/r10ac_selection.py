"""Explicit R10AC admission aliases over unchanged V24/V56 native behavior."""
import json
import r10ac_development_v2 as identity

ENTRY = 'r10ac_v56_joint_bounded_contact_gated_v1'
START = 'r10ac_v56_front_left_first_post_interaction_v1'


def native_schedule(schedule):
    """Validate the complete declared diagnostic before selecting native laws.

    Only fresh selection inputs are projected; retained reports are never edited.
    The independent R10AC entry key remains checked by candidate admission.
    """
    identity.reference()
    profile = json.loads(identity.PROFILE.read_text(encoding='utf-8'))
    path = identity.ROOT / ('sdk/development/recovery_schedules/'+profile['diagnostic_schedule_id']+'.json')
    identity.require(identity.sha(path) == profile['diagnostic_schedule_sha256'], 'SCHEDULE_DRIFT')
    expected = json.loads(path.read_text(encoding='utf-8'))['schedules'][profile['diagnostic_schedule_id']]
    identity.require(schedule == expected, 'CAPTURE_SCHEDULE_CROSSED')
    return dict(schedule, walking_entry_profile_id='r10ab_v56_joint_bounded_contact_gated_v1',
        walking_start_profile_id='r10ab_v56_front_left_first_post_interaction_v1')
