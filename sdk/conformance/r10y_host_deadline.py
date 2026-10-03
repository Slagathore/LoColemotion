"""Bind R10Y's existing wall deadlines to its exact task and population."""
import json

import r10y_development as development

CANDIDATE_ID = 'r10y-partial-direct-neutral-integrated-v1'
TASK = development.ROOT / 'sdk/recovery/r10y_partial_direct_neutral_finite_cycle_contract_v1.json'
TASK_SHA = 'sha256:3d78684470f51379955306c9bf717b5132711577c39422b8c04abe35d452f40c'


def timeout_seconds(chosen, declaration):
    schedule = chosen.get('diagnostic_schedule', {})
    development.require(schedule.get('walking_policy_id') == development.ROUTE
        and chosen.get('candidate', {}).get('candidate_id') == CANDIDATE_ID, 'HOST_DEADLINE_CANDIDATE')
    development.require(declaration.get('candidate_profile') == chosen.get('candidate_profile'), 'HOST_DEADLINE_REFERENCE')
    basis = schedule.get('coverage_basis', {})
    development.require(basis.get('successor_design') == development.DESIGN.relative_to(development.ROOT).as_posix()
        and basis.get('successor_design_sha256') == development.DESIGN_SHA
        and development.sha(development.DESIGN) == development.DESIGN_SHA, 'HOST_DEADLINE_DESIGN')
    development.require(basis.get('task_contract') == TASK.relative_to(development.ROOT).as_posix()
        and basis.get('task_contract_sha256') == TASK_SHA and development.sha(TASK) == TASK_SHA, 'HOST_DEADLINE_TASK')
    development.validate_context(declaration.get('r10y_development'), declaration)
    limits = json.loads(TASK.read_text(encoding='utf-8'))['limits']
    value = limits['child_wall_time_limit_seconds']
    development.require(type(value) is int and value == 1740
        and type(limits['independent_reader_wall_time_limit_seconds']) is int
        and limits['independent_reader_wall_time_limit_seconds'] == 900, 'HOST_DEADLINE_VALUE')
    return value
