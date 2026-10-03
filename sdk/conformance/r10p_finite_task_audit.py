"""Distinct consecutive-prone reader; downstream of launch and native replay.

R10O remains immutable. Its entry, walking, envelope and partial measurements
are reused verbatim. Only a fresh R10P result uses the reconstructed prone dwell.
This component cannot establish input provenance or grant acceptance by itself;
the enclosing auditor must bind the population, source, runtime and cold replay.
"""
import hashlib
import math
from pathlib import Path

import qsdk_r10f_l15_collection_retention as packet
import r10o_finite_task_audit as prior

ROOT = Path(__file__).resolve().parents[2]
CONTRACT = ROOT / 'sdk/recovery/r10p_consecutive_prone_completion_reader_contract_v1.json'
CONTRACT_SHA = '5ab562ef1b4805c05c81896b301083e5bea2a53ea2e8ea1b927eed9d01acd609'
SCHEMA = 'sporespore_r10p_finite_task_measurement_v1'
PHASES = ['confirm_prone', 'establish_distal_support', 'raise_body', 'stance_handoff', 'stance_dwell']


def require(value, code):
    if not value:
        raise ValueError('R10P_FINITE_TASK_' + code)


def contract():
    raw = CONTRACT.read_bytes()
    require(hashlib.sha256(raw).hexdigest() == CONTRACT_SHA, 'CONTRACT_DRIFT')
    value = packet.parse_json(raw.decode('utf-8'))
    for item in value['bound_sources']:
        data = (ROOT / item['path']).read_bytes()
        require(len(data) == item['byte_length'] and 'sha256:' + hashlib.sha256(data).hexdigest()
                == item['raw_sha256'], 'SOURCE_DRIFT:' + item['path'])
    return value


def counter(value, *, native=False):
    # Godot native-memory numbers serialize as integral floats. Orchestrator
    # counters are JSON integers; bool must never masquerade as either kind.
    allowed = (int, float) if native else (int,)
    require(type(value) in allowed and math.isfinite(value) and value >= 0
            and int(value) == value, 'COUNTER_TYPE')
    return int(value)


def confirmation_inputs(report):
    state = report['retained_arm']['orchestrator_state']
    start = counter(state['canonical_start_global_step'])
    count = counter(state['confirm_prone_step_count'])
    require(start > 0 and count > 0, 'CONFIRMATION_ORIGIN')
    rows = report['passive_entry']['orchestrator_transitions'][start-1:start-1+count]
    samples = []
    for row in rows:
        event, before, after = row['event'], row['state_before'], row['advance']['state_after']
        require(event['no_actuation_requested'] is True and event['walking_actuation_applied'] is False
                and event['recovery_actuation_applied'] is False, 'PASSIVE_CONFIRMATION')
        samples.append(dict(global_step=event['global_semantic_step'], prone_sample=event['prone_sample'],
            event_kind=event['event_kind'], entry_status=event['passive_entry_status'],
            before_elapsed=before['confirm_prone_step_count'], after_elapsed=after['confirm_prone_step_count'],
            before_consecutive=before['consecutive_prone_sample_count'], after_consecutive=after['consecutive_prone_sample_count']))
    canonical = report['passive_entry']['canonical_packets']
    memory = canonical[-1]['memory_after'] if canonical else None
    return dict(start_global_step=start, elapsed_count=count,
        consecutive_count=state['consecutive_prone_sample_count'], samples=samples,
        native_final_memory=None if memory is None else {key: memory[key] for key in
            ('phase', 'prone_confirm_steps_observed', 'stance_dwell_steps_observed',
             'ordered_completed_phases', 'terminal_failure_code')},
        partial_packet_count=len(report['r10k_partial_recovery']['step_packets']))


def prone_completion(value):
    """Reconstruct the counter history. Valid incomplete recovery stays negative."""
    rules = contract()['constants']
    required, maximum = rules['required_consecutive_prone_samples'], rules['maximum_elapsed_confirmation_steps']
    count = counter(value['elapsed_count'])
    final = counter(value['consecutive_count'])
    start = counter(value['start_global_step'])
    require(start > 0 and count > 0 and type(value['samples']) is list
            and len(value['samples']) == count and final <= count, 'COUNTER_POPULATION')
    require(counter(value['partial_packet_count']) == 0, 'CROSSED_RECOVERY_BRANCH')
    elapsed, consecutive = 0, 0
    for index, row in enumerate(value['samples']):
        require(counter(row['global_step']) == start + index, 'CLOCK')
        require(type(row['prone_sample']) is bool, 'SAMPLE_TYPE')
        require(counter(row['before_elapsed']) == elapsed
                and counter(row['before_consecutive']) == consecutive, 'BEFORE_COUNTERS')
        if index == 0:
            require(row['event_kind'] == 'passive_entry_observation'
                    and row['entry_status'] == 'prone_handoff' and row['prone_sample'] is True, 'INITIAL_HANDOFF')
        else:
            require(row['event_kind'] == 'passive_prone_observation', 'CONFIRMATION_EVENT')
        elapsed += 1
        consecutive = consecutive + 1 if row['prone_sample'] else 0
        require(counter(row['after_elapsed']) == elapsed
                and counter(row['after_consecutive']) == consecutive, 'AFTER_COUNTERS')
        require(index == count-1 or consecutive < required, 'LATE_HANDOFF')
    require(consecutive == final, 'FINAL_COUNTER')
    memory = value['native_final_memory']
    native_complete = False
    if memory is not None:
        require(type(memory) is dict and type(memory['phase']) is str
                and memory['phase'] in PHASES + ['complete', 'failed', 'refused'], 'NATIVE_PHASE')
        prone = counter(memory['prone_confirm_steps_observed'], native=True)
        standing = counter(memory['stance_dwell_steps_observed'], native=True)
        phases = memory['ordered_completed_phases']
        require(type(phases) is list and phases == PHASES[:len(phases)], 'NATIVE_PHASE_HISTORY')
        failure = memory['terminal_failure_code']
        require(failure is None or type(failure) is str, 'NATIVE_FAILURE_TYPE')
        native_complete = (memory['phase'] == 'complete' and prone == required
                           and standing == rules['standing_dwell_samples']
                           and phases == PHASES and failure is None)
    return dict(elapsed_steps=elapsed, consecutive_samples=consecutive,
        required_consecutive_samples=required, maximum_elapsed_steps=maximum,
        confirmation_complete=(required <= elapsed <= maximum and consecutive >= required),
        native_recovery_complete=native_complete,
        passed=(required <= elapsed <= maximum and consecutive >= required and native_complete))


def measure(report, compiled):
    contract()
    result = prior.measure(report, compiled)  # Returns a fresh dictionary.
    result['schema_version'] = SCHEMA
    result['reader_contract_sha256'] = 'sha256:' + CONTRACT_SHA
    if report['arm_id'] == prior.ROLES[1] and report['retained_arm']['orchestrator_state']['r10k_entry_kind'] == 'prone':
        completion = prone_completion(confirmation_inputs(report))
        result['prone_completion'] = completion
        result['predicates']['recovery_completed'] = completion['passed']
        result['finite_task_predicates_passed'] = all(result['predicates'].values())
    return result
