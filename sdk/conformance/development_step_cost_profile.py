"""Exact binding and accounting for diagnostic wall-time profiles, not physics claims."""
import hashlib

import qsdk_r10f_l15_collection_retention as packet

PROFILE_ID = 'recovery_step_cost_wall_clock_v1'
MARKER = 'SPORESPORE_DEVELOPMENT_STEP_COST_PROFILE '
CACHE_PROFILE_ID = 'recovery_exact_context_checks_v1'
CACHE_WORKER_RESOURCE = 'res://sdk/adapters/godot/gdscript/development_cached_recovery_smoke_worker_v1.gd'
CACHE_CALL_SITES = ['epoch_preflight', 'global_context_validation']


def validate_profile(profile, report, raw_report, *, context_cache_expected=False):
    def require(ok, code):
        if not ok:
            raise ValueError('DEVELOPMENT_STEP_PROFILE_' + code)
    def integer(value, minimum=0):
        return type(value) is int and minimum <= value <= 2**63 - 1
    expected = dict(schema_version='sporespore_development_step_cost_profile_v1', profile_id=PROFILE_ID,
                    clock='Time.get_ticks_usec_monotonic_wall_time', physics_solver_time_isolated=False,
                    controller_inputs_changed=False, telemetry_reduced=False,
                    physical_acceptance_authority=False, release_authority=False,
                    raw_report_sha256='sha256:' + hashlib.sha256(raw_report.encode('utf-8')).hexdigest(),
                    raw_report_byte_length=len(raw_report.encode('utf-8')))
    for key in ('source_commit', 'parent_attempt_id', 'child_attempt_id', 'arm_id', 'process_id',
                'diagnostic_declaration_sha256', 'solver_step_count'):
        expected[key] = report[key]
    extra = {'context_cache'} if context_cache_expected else set()
    require(type(profile) is dict and set(profile) == set(expected) | {'timing'} | extra, 'HEADER_KEYS')
    for key, value in expected.items():
        require(packet.same(profile[key], value), 'BINDING_' + key)
    timing = profile['timing']
    require(type(timing) is dict and set(timing) == {'ok', 'failure_code', 'open_section_count',
            'elapsed_us', 'accounted_us', 'unattributed_us', 'sections'}, 'TIMING_KEYS')
    require(timing['ok'] is True and timing['failure_code'] == ''
            and type(timing['open_section_count']) is int and timing['open_section_count'] == 0, 'INCOMPLETE')
    for key in ('elapsed_us', 'accounted_us', 'unattributed_us'):
        require(integer(timing[key]), 'INTEGER_' + key)
    sections = timing['sections']
    require(type(sections) is dict and bool(sections), 'SECTIONS')
    total = 0
    for label, row in sections.items():
        require(type(label) is str and label and type(row) is dict and
                set(row) == {'sample_count', 'inclusive_us', 'exclusive_us', 'maximum_us'}, 'SECTION_KEYS')
        require(integer(row['sample_count'], 1) and all(integer(row[key]) for key in
                ('inclusive_us', 'exclusive_us', 'maximum_us')), 'SECTION_INTEGERS')
        require(row['exclusive_us'] <= row['inclusive_us'] and row['maximum_us'] <= row['inclusive_us']
                <= row['maximum_us'] * row['sample_count'], 'SECTION_ACCOUNTING')
        total += row['exclusive_us']
    require(total == timing['accounted_us'] and total + timing['unattributed_us'] == timing['elapsed_us'], 'TOTAL_ACCOUNTING')
    count = report['solver_step_count']
    def samples(label):
        return sections.get(label, {}).get('sample_count', 0)
    require(samples('step_callback') == count and samples('between_callbacks') == count, 'CALLBACK_COVERAGE')
    require(samples('activation_callback') == samples('startup_before_first_callback') == (1 if count else 0), 'STARTUP_COVERAGE')
    require(samples('final_report_publication') == 1, 'PUBLICATION_COVERAGE')
    for prefix in ('collect_step/', 'retain_step/', 'process_step/'):
        require(sum(row['sample_count'] for name, row in sections.items() if name.startswith(prefix)) == count,
                'STEP_COVERAGE_' + prefix)
    require(sum(row['sample_count'] for name, row in sections.items() if name.startswith('plan_step/'))
            == max(0, count - 1), 'PLAN_COVERAGE')
    for label in ('epoch_preflight', 'global_context_validation', 'native_sampling_and_source_validation',
                  'energy_observation_composition', 'global_projection'):
        require(samples(label) == count, 'COLLECTION_COVERAGE_' + label)
    epoch = report['retained_arm']['orchestrator_state']['epoch_start_global_step']
    require(samples('local_epoch_projection') == (report['after_interaction_step_count'] + 1 if type(epoch) is int else 0),
            'EPOCH_COVERAGE')
    if context_cache_expected:
        validate_context_cache(profile['context_cache'], count)
    return profile


def validate_context_cache(cache, solver_steps):
    def require(ok, code):
        if not ok:
            raise ValueError('DEVELOPMENT_CONTEXT_CACHE_' + code)
    fixed = dict(profile_id=CACHE_PROFILE_ID, maximum_entries=2, observations_cached=False,
                 controller_outputs_cached=False, physical_baselines_cached=False,
                 qualification_cached=False, dynamic_preflight_checks_skipped=False)
    require(type(cache) is dict and set(cache) == set(fixed) |
            {'call_sites', 'hits', 'full_checks', 'bypasses', 'retained_entries'}, 'KEYS')
    for key, value in fixed.items():
        require(packet.same(cache[key], value), 'BINDING_' + key)
    require(packet.same(cache['call_sites'], {site: solver_steps for site in CACHE_CALL_SITES}), 'CALL_COVERAGE')
    total = solver_steps * 2
    for key in ('hits', 'full_checks', 'bypasses', 'retained_entries'):
        require(type(cache[key]) is int and 0 <= cache[key] <= total, 'INTEGER_' + key)
    require(cache['hits'] + cache['full_checks'] == total, 'ACCOUNTING')
    require(cache['bypasses'] <= cache['full_checks'] and cache['retained_entries'] <= 2, 'BOUNDS')
    require(cache['full_checks'] >= (2 if solver_steps else 0), 'COLD_CHECKS_REQUIRED')
    return cache


def declared_context_cache(declaration, *, expected_worker=CACHE_WORKER_RESOURCE):
    if 'context_cache_profile_id' not in declaration:
        if ('context_cache_call_sites' in declaration or
                declaration.get('worker_resource') == expected_worker):
            raise ValueError('DEVELOPMENT_CONTEXT_CACHE_UNDECLARED')
        return False
    if (declaration['context_cache_profile_id'] != CACHE_PROFILE_ID or
            declaration.get('context_cache_call_sites') != CACHE_CALL_SITES or
            declaration.get('worker_resource') != expected_worker or
            declaration.get('step_cost_profile_id') != PROFILE_ID):
        raise ValueError('DEVELOPMENT_CONTEXT_CACHE_DECLARATION')
    return True
