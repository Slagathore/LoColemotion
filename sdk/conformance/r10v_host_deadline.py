"""The R10V deadline belongs to its bound design, never to a mutable global."""
import r10v_development as development

CANDIDATE_ID = 'r10v-v56-post-recovery-hold-integrated-v2'


def timeout_seconds(chosen, declaration):
    """Called after exact candidate selection by the shared final auditor."""
    schedule = chosen.get('diagnostic_schedule', {})
    development.require(schedule.get('walking_policy_id') == development.ROUTE
        and chosen.get('candidate', {}).get('candidate_id') == CANDIDATE_ID,
        'HOST_DEADLINE_CANDIDATE')
    development.require(declaration.get('candidate_profile') == chosen.get('candidate_profile'),
        'HOST_DEADLINE_REFERENCE')
    basis = schedule.get('coverage_basis', {})
    development.require(basis.get('successor_design') == development.DESIGN.relative_to(development.ROOT).as_posix()
        and basis.get('successor_design_sha256') == development.DESIGN_SHA
        and development.sha(development.DESIGN) == development.DESIGN_SHA, 'HOST_DEADLINE_DESIGN')
    # This also rejects a crossed campaign, reused population, or forged context.
    development.validate_context(declaration.get('r10v_development'), declaration)
    value = development.read(development.DESIGN)['limits']['per_child_wall_seconds']
    development.require(type(value) is int and value == 1740, 'HOST_DEADLINE_VALUE')
    return value
