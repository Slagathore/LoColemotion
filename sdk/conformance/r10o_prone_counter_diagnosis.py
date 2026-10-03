"""Preserve the R10O prone negative and diagnose its elapsed/dwell mismatch.

This post-exposure reconstruction does not change the production reader, the
original predicate, or any physical record. The caller owns the native lock.
"""
import argparse
import copy
import json
from pathlib import Path
import re
import subprocess

import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
from r10l_development_pair import stop_diagnosis
from v52_extended_support_transfer import ROOT, binding, read

ATTEMPT = 'f7b4369982d741949a1235fc82a1f0dc'
SOURCE = 'be891846b5c48af7ceca29d1f7c6559cb96b793f'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
RECORD = ROOT / 'sdk/recovery/r10o_phase243_prone_counter_diagnosis_v1.json'
ROLE = 'kick_passive_recovery_resume'
TASK = 'sdk/recovery/r10o_initialized_zero_brake_finite_cycle_contract_v1.json'
ORCHESTRATOR = 'sdk/adapters/godot/gdscript/qsdk_r10f_event_triggered_passive_recovery_orchestrator_v1.gd'
READER = 'sdk/conformance/r10o_finite_task_audit.py'


def require(value, code):
    if not value:
        raise ValueError('R10O_PRONE_DIAGNOSIS_' + code)


def confirmation_inputs(report):
    state = report['retained_arm']['orchestrator_state']
    start, count = state['canonical_start_global_step'], state['confirm_prone_step_count']
    rows = report['passive_entry']['orchestrator_transitions'][start-1:start-1+count]
    samples = []
    for row in rows:
        event, before, after = row['event'], row['state_before'], row['advance']['state_after']
        require(event['no_actuation_requested'] is True and event['walking_actuation_applied'] is False
            and event['recovery_actuation_applied'] is False, 'PASSIVE_CONFIRMATION')
        samples.append(dict(global_step=event['global_semantic_step'], prone_sample=event['prone_sample'],
            event_kind=event['event_kind'], entry_status=event['passive_entry_status'],
            before_elapsed=before['confirm_prone_step_count'], after_elapsed=after['confirm_prone_step_count'],
            before_consecutive=before['consecutive_prone_sample_count'], after_consecutive=after['consecutive_prone_sample_count'],
            event_sha256=event['payload_sha256'], state_before_sha256=before['payload_sha256'], state_after_sha256=after['payload_sha256']))
    memory = report['passive_entry']['canonical_packets'][-1]['memory_after']
    return dict(start_global_step=start, elapsed_count=count,
        consecutive_count=state['consecutive_prone_sample_count'], samples=samples,
        native_final_memory={k: memory[k] for k in ('phase', 'prone_confirm_steps_observed',
            'stance_dwell_steps_observed', 'ordered_completed_phases', 'terminal_failure_code')},
        partial_packet_count=len(report['r10k_partial_recovery']['step_packets']))


def diagnose_confirmation(value, required=12, maximum=60):
    """Reconstruct both counters from the already replayed passive events."""
    count = value['elapsed_count']
    require(type(count) is int and required <= count <= maximum and len(value['samples']) == count, 'POPULATION')
    elapsed, consecutive = 0, 0
    for index, row in enumerate(value['samples']):
        require(row['global_step'] == value['start_global_step'] + index, 'CLOCK')
        require(type(row['prone_sample']) is bool, 'SAMPLE_TYPE')
        require(row['before_elapsed'] == elapsed and row['before_consecutive'] == consecutive, 'BEFORE_COUNTERS')
        if index == 0:
            require(row['event_kind'] == 'passive_entry_observation' and row['entry_status'] == 'prone_handoff'
                and row['prone_sample'] is True, 'INITIAL_HANDOFF')
        else:
            require(row['event_kind'] == 'passive_prone_observation', 'CONFIRMATION_EVENT')
        elapsed += 1
        consecutive = consecutive + 1 if row['prone_sample'] else 0
        require(row['after_elapsed'] == elapsed and row['after_consecutive'] == consecutive, 'AFTER_COUNTERS')
        require(index == count-1 or consecutive < required, 'LATE_HANDOFF')
    require(consecutive == value['consecutive_count'] == required, 'CONSECUTIVE_DWELL')
    memory = value['native_final_memory']
    require(memory['phase'] == 'complete' and memory['prone_confirm_steps_observed'] == required
        and memory['stance_dwell_steps_observed'] == 60 and memory['terminal_failure_code'] is None
        and memory['ordered_completed_phases'] == ['confirm_prone', 'establish_distal_support', 'raise_body', 'stance_handoff', 'stance_dwell']
        and value['partial_packet_count'] == 0, 'NATIVE_COMPLETION')
    return dict(elapsed_steps=elapsed, consecutive_samples=consecutive,
        maximum_elapsed_steps=maximum, required_consecutive_samples=required,
        reset_steps=[r['global_step'] for r in value['samples'] if not r['prone_sample']],
        final_consecutive_global_steps=[r['global_step'] for r in value['samples'][-required:]],
        original_elapsed_equals_12_term=(elapsed == 12), existing_orchestrator_rule_satisfied=True,
        native_recovery_complete=True, native_standing_dwell=60,
        original_attempt_reclassified=False, physical_acceptance_authority=False, release_authority=False)


def controls(value):
    results = []
    for name in ('missing_sample', 'crossed_clock', 'unknown_prone_sample', 'ignored_reset', 'forged_final_dwell', 'incomplete_native_standing'):
        changed = copy.deepcopy(value)
        if name == 'missing_sample': changed['samples'].pop()
        elif name == 'crossed_clock': changed['samples'][2]['global_step'] += 1
        elif name == 'unknown_prone_sample': changed['samples'][1]['prone_sample'] = None
        elif name == 'ignored_reset': changed['samples'][1]['prone_sample'] = True
        elif name == 'forged_final_dwell': changed['consecutive_count'] = 10
        else: changed['native_final_memory']['stance_dwell_steps_observed'] = 59
        try:
            diagnose_confirmation(changed)
        except ValueError as error:
            results.append(dict(case=name, refused=True, error=str(error)))
        else:
            raise ValueError('R10O_PRONE_DIAGNOSIS_CONTROL_ACCEPTED:' + name)
    return results


def reconstruct():
    supervisor = read(EVIDENCE / 'supervisor_result.json')
    require(supervisor['ok'] is True and supervisor['failure_code'] == '', 'VALID_PUBLICATION')
    require(supervisor['source_snapshot'] == dict(head=SOURCE, dirty=False, status=[], changed_file_bindings=[]), 'FREEZE')
    stages = supervisor['safety_stages']
    selected = read(ROOT / 'sdk/development/r10o_safety_stage_contract_v1.json')['stages']
    require(len(stages) == len(selected) == 41 and sum(s['test_count'] for s in stages) == 201, 'SAFETY_POPULATION')
    for stage, expected in zip(stages, selected):
        require(stage['id'] == expected['id'] and stage['test_count'] == stage['expected_test_count'] == expected['tests']
            and stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0, 'SAFETY_STAGE')
        for stream in ('stdout', 'stderr'):
            require(binding(EVIDENCE / stage[stream])['raw_sha256'] == 'sha256:' + stage[stream+'_sha256'], 'SAFETY_LOG')
    checkpoint = smoke.retained_checkpoint(EVIDENCE)
    result = checkpoint['observed']['r10o_finite_development']
    require(result['seed'] == 40743 and result['all_tasks_positive'] is False and result['branch_coverage_complete'] is True
        and len(result['cells']) == 1, 'ORIGINAL_NEGATIVE')
    cell = result['cells'][0]
    require(cell['role'] == ROLE and cell['entry_kind'] == 'prone'
        and cell['measurement']['predicates'] == dict(entry_ready=True, planned_cycles=True, forward_advance=True,
            settled_stop=True, whole_walking_envelope=True, recovery_completed=False), 'ORIGINAL_PREDICATES')
    report = read(EVIDENCE / 'children' / ROLE / 'worker_report.json')
    require(report['world_build_count'] == report['world_attempt_count'] == report['external_kick_application_count'] == 1
        and report['solver_step_count'] == checkpoint['observed']['total_solver_steps'] == 2041, 'PHYSICAL_POPULATION')
    inputs = confirmation_inputs(report)
    # Bind the actual pre-exposure counter definitions and old predicate.
    for relative in (ORCHESTRATOR, READER, 'sdk/adapters/godot/gdscript/r10k_recovery_orchestrator_v1.gd'):
        require((ROOT / relative).read_bytes() == subprocess.check_output(['git', 'show', SOURCE+':'+relative], cwd=ROOT), 'FROZEN_SOURCE')
    source = (ROOT / ORCHESTRATOR).read_text()
    required = int(re.search(r'const REQUIRED_CONSECUTIVE_PRONE_SAMPLES := (\d+)', source)[1])
    maximum = int(re.search(r'const MAXIMUM_CONFIRM_PRONE_STEPS := (\d+)', source)[1])
    require(required == 12 and maximum == 60 and "state['confirm_prone_step_count'] == 12" in (ROOT / READER).read_text(), 'PUBLISHED_RULES')
    diagnosis = diagnose_confirmation(inputs, required, maximum)
    require(diagnosis['elapsed_steps'] == 14 and diagnosis['reset_steps'] == [390]
        and diagnosis['final_consecutive_global_steps'] == list(range(391, 403)), 'OBSERVED_COUNTER_SEQUENCE')
    stop = stop_diagnosis(report, read(ROOT / TASK))
    require(stop['settled_stop_passed'] is True and stop['final_consecutive_settled_commands'] == 120, 'SETTLED_STOP')
    walking = cell['measurement']['walking']
    require(walking['command_count'] == 1157 and walking['cycle_end_command'] == 1037 and len(walking['planned_cycles']) == 4, 'WALKING')
    paths = [Path(__file__).relative_to(ROOT).as_posix(), READER, ORCHESTRATOR,
        'sdk/adapters/godot/gdscript/r10k_recovery_orchestrator_v1.gd', 'sdk/conformance/r10l_development_pair.py', TASK,
        'sdk/recovery/r10o_phase241_development_pair_closure_v1.json', 'sdk/development/r10o_safety_stage_contract_v1.json',
        'sdk/development/recovery_candidates/r10o-v55-initialized-brake-integrated-v2.json']
    return dict(schema_version='sporespore_r10o_phase243_prone_counter_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_development_negative_and_post_exposure_counter_diagnosis', question_class='development'),
        attempt_id=ATTEMPT, source_commit=SOURCE, evidence_root=EVIDENCE.as_posix(),
        status='valid_development_negative_prone_completion_reader_counter_mismatch',
        safety_gate=dict(stages=41, tests=201, passed=True), retained_checkpoint=checkpoint,
        source_bindings=[binding(path) for path in paths],
        retained_evidence=[binding(path) for path in sorted(EVIDENCE.rglob('*')) if path.is_file()],
        physical_world_count=1, completed_solver_steps=2041, original_predicates=cell['measurement']['predicates'],
        walking_commands=1157, cycle_end_command=1037, planned_cycles=4, stopping_commands=120,
        forward_advance_m=walking['pre_first_to_post_last_body_forward_m'], stop_diagnosis=stop,
        confirmation_inputs=inputs, counter_diagnosis=diagnosis, counter_negative_controls=controls(inputs),
        claim_boundary=dict(original_negative_preserved=True, original_attempt_reclassified=False,
            declared_r10o_development_prerequisites_satisfied=False, production_reader_changed=False,
            successor_reader_required=True, held_out_population_selected=False,
            physical_acceptance_authority=False, release_authority=False, sdk1_score='14/20'))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    observed = reconstruct()
    if args.create:
        with RECORD.open('x', encoding='utf-8', newline='\n') as stream:
            json.dump(observed, stream, indent=2, allow_nan=False)
            stream.write('\n')
    else:
        require(packet.same(observed, read(RECORD)), 'CLOSURE_RECONSTRUCTION')
    print(json.dumps(dict(ok=True, retained_files=len(observed['retained_evidence']), safety_tests=201,
        physical_worlds=1, completed_steps=2041, original_positive=False, elapsed_confirmation_steps=14,
        consecutive_prone_samples=12, native_standing_samples=60, settled_stop_samples=120,
        counter_controls=6, original_attempt_reclassified=False, new_world_count=0, new_solver_step_count=0, sdk1_score='14/20')))


if __name__ == '__main__':
    main()
