"""Exact R10AG schedule admission; its V23/V56 route needs no alias projection."""
import json
import r10ag_development as identity

ENTRY = 'r10ag_v56_joint_bounded_contact_gated_v1'
START = 'r10ag_v56_front_left_first_post_interaction_v1'


def native_schedule(schedule):
    """Validate the complete declared diagnostic before selecting native laws.

    Only fresh selection inputs are projected; retained reports are never edited.
    The independent R10AG entry key remains checked by candidate admission.
    """
    identity.reference()
    profile = json.loads(identity.PROFILE.read_text(encoding='utf-8'))
    path = identity.ROOT / ('sdk/development/recovery_schedules/'+profile['diagnostic_schedule_id']+'.json')
    identity.require(identity.sha(path) == profile['diagnostic_schedule_sha256'], 'SCHEDULE_DRIFT')
    expected = json.loads(path.read_text(encoding='utf-8'))['schedules'][profile['diagnostic_schedule_id']]
    identity.require(schedule == expected, 'CAPTURE_SCHEDULE_CROSSED')
    return dict(schedule)
