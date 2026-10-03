"""Reconstruct the retained phase-246 R10Q development negative; never rerun it."""
import argparse
import json
from pathlib import Path

import development_recovery_smoke as smoke
import qsdk_r10f_l15_collection_retention as packet
import r10q_development as development
from v52_extended_support_transfer import ROOT, binding, read

ATTEMPT = '8940c64cbfd74844b46c5de53a3df02e'
SOURCE = '00869f26d9b832518b6c3e1d43df048f4133d91a'
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence' / ('development-recovery-smoke-' + ATTEMPT)
RECORD = ROOT / 'sdk/recovery/r10q_phase246_development_pair_closure_v1.json'
PROFILE = 'sdk/development/recovery_candidates/r10q-v55-upright-integrated-v1.json'
TASK = 'sdk/recovery/r10q_upright_finite_cycle_contract_v1.json'
SAFETY = 'sdk/development/r10q_safety_stage_contract_v3.json'

def require(value, code):
    if not value:
        raise ValueError('R10Q_PAIR_' + code)

def raise_diagnosis(report):
    packets = report['r10q_upright_recovery']['step_packets']
    steps = [p['native_receipt']['step'] for p in packets]
    require(len(steps) == 601 and steps[0]['prior_phase'] == 'establish_distal_support'
            and steps[0]['next_phase'] == 'raise_body', 'UPRIGHT_PHASE_ENTRY')
    raised = [s for s in steps if s['prior_phase'] == 'raise_body']
    require(len(raised) == 600 and raised[-1]['next_phase'] == 'failed', 'RAISE_POPULATION')
    observations = [s['classification'] for s in raised]
    first = observations[0]
    boolean_counts = {k: sum(o[k] is True for o in observations) for k, value in first.items() if type(value) is bool}
    numeric_ranges = {k: dict(minimum=min(o[k] for o in observations), maximum=max(o[k] for o in observations))
                      for k, value in first.items() if type(value) in (int, float)}
    first_loss = next(s['memory']['last_semantic_step'] for s in raised if not s['classification']['all_four_distal_sites_bearing'])
    first_inverted = next(s['memory']['last_semantic_step'] for s in raised if s['classification']['torso_up_dot'] < 0.0)
    require(boolean_counts['all_four_distal_sites_bearing'] == 7 and boolean_counts['joint_limits_respected'] == 576
            and boolean_counts['actuator_budget_respected'] == 600 and boolean_counts['no_cheat_gate'] == 600
            and boolean_counts['stable_stance_gate'] == 0, 'RETAINED_PREDICATE_COUNTS')
    require(observations[-1]['torso_up_dot'] < -0.999 and observations[-1]['torso_height_ratio'] < 0.14,
            'RETAINED_INVERTED_TERMINAL')
    return dict(scope='retained_measurements_only', establish_commands=1, raise_commands=600,
        first_all_four_support_loss_global_step=first_loss, first_inverted_global_step=first_inverted,
        boolean_pass_counts=boolean_counts, numeric_ranges=numeric_ranges,
        first_upright_classification=steps[0]['classification'], terminal_classification=observations[-1],
        terminal_reason='phase_timeout:raise_body', counterfactual_motion_predicted=False,
        successor_controller_selected=False, original_results_regraded=False,
        new_world_count=0, new_solver_step_count=0)

def reconstruct():
    supervisor = read(EVIDENCE / 'supervisor_result.json')
    require(supervisor['ok'] is True and supervisor['failure_code'] == '', 'SUPERVISOR')
    freeze = dict(head=SOURCE, dirty=False, status=[], changed_file_bindings=[])
    require(supervisor['source_snapshot'] == freeze, 'FREEZE')
    selected = read(ROOT / SAFETY)['stages']
    stages = supervisor['safety_stages']
    require(len(stages) == len(selected) == 39 and sum(s['test_count'] for s in stages) == 184, 'GATE_POPULATION')
    for stage, expected in zip(stages, selected, strict=True):
        require(stage['id'] == expected['id'] and stage['test_count'] == stage['expected_test_count'] == expected['tests']
                and stage['passed'] is True and stage['timed_out'] is False and stage['exit_code'] == 0, 'GATE_STAGE')
        for stream in ('stdout', 'stderr'):
            require(binding(EVIDENCE / stage[stream])['raw_sha256'] == 'sha256:' + stage[stream + '_sha256'], 'GATE_LOG')
    checkpoint = smoke.retained_checkpoint(EVIDENCE)
    result = checkpoint['observed']['r10q_finite_development']
    require(result['all_tasks_positive'] is False and result['branch_coverage_complete'] is True
            and not development.positive_pair_result(result, result['candidate_profile']), 'NEGATIVE_PAIR')
    require(checkpoint['attempt_id'] == ATTEMPT and checkpoint['source_snapshot'] == freeze
            and checkpoint['observed']['total_solver_steps'] == 2900, 'CHECKPOINT_POPULATION')
    summaries = []
    diagnosis = None
    for index, cell in enumerate(result['cells']):
        role = cell['role']
        require(role == development.ROLES[index] and cell['finite_task_predicates_passed'] is (index == 0), 'ROLE_RESULT')
        report = read(EVIDENCE / 'children' / role / 'worker_report.json')
        require(report['world_build_count'] == report['world_attempt_count'] == 1
                and report['solver_step_count'] == (1787, 1113)[index]
                and report['external_kick_application_count'] == index, 'FRESH_WORLD_POPULATION')
        state = report['retained_arm']['orchestrator_state']
        measurement = cell['measurement']
        summary = dict(role=role, entry_kind=cell['entry_kind'], solver_steps=report['solver_step_count'],
            finite_task_predicates_passed=cell['finite_task_predicates_passed'], predicates=measurement['predicates'])
        if index == 0:
            walking = measurement['walking']
            memory = report['development_cycle_stop']['final_memory']
            require((state['neutral_entry_step_count'], state['hold_entry_step_count']) == (169, 176)
                    and walking['command_count'] == 1170 and walking['cycle_end_command'] == 1050
                    and len(walking['planned_cycles']) == 4 and walking['stopping_commands'] == 120
                    and memory['consecutive_settled_commands'] == 120, 'NO_KICK_FINITE_POPULATION')
            summary.update(ramp_commands=169, hold_commands=176, walking_commands=1170, planned_cycles=4,
                stopping_commands=120, consecutive_settled_commands=120,
                forward_advance_m=walking['pre_first_to_post_last_body_forward_m'])
        else:
            require(state['r10q_entry_kind'] == 'upright' and state['phase'] == 'failed'
                    and state['terminal_reason'] == 'phase_timeout:raise_body'
                    and state['upright_recovery_step_count'] == 601 and state['walking_resume_step_count'] == 0,
                    'UPRIGHT_TERMINAL')
            diagnosis = raise_diagnosis(report)
            summary.update(passive_descent_commands=240, upright_commands=601, walking_commands=0,
                terminal_reason=state['terminal_reason'], upright_stabilization_complete=False)
        summaries.append(summary)
        del report
    paths = [Path(__file__).relative_to(ROOT).as_posix(), 'sdk/conformance/development_recovery_smoke.py',
        'sdk/conformance/r10q_development.py', 'sdk/conformance/r10q_finite_task_audit.py', PROFILE, TASK, SAFETY,
        'sdk/recovery/r10q_entry_successor_design_v1.json', 'sdk/recovery/r10q_v55_walking_entry_contract_v7.json',
        'sdk/development/recovery_candidates/r10q-upright-recovery-core-v1.runtime.json']
    return dict(schema_version='sporespore_r10q_phase246_development_pair_closure_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='consumed_negative_development_pair_closure', question_class='development'),
        attempt_id=ATTEMPT, source_commit=SOURCE, evidence_root=EVIDENCE.as_posix(),
        status='valid_negative_phase246_development_pair', source_bindings=[binding(path) for path in paths],
        safety_gate=dict(stages=39, tests=184, passed=True, seconds=sum(s['seconds'] for s in stages)),
        retained_checkpoint=checkpoint, retained_evidence=[binding(p) for p in sorted(EVIDENCE.rglob('*')) if p.is_file()],
        physical_world_count=2, completed_solver_steps=2900, role_summaries=summaries, upright_raise_diagnosis=diagnosis,
        claim_boundary=dict(valid_development_pair=True, all_tasks_positive=False,
            no_kick_finite_task_positive=True, kicked_upright_task_negative=True,
            additional_phase_diagnostics_prerequisite_satisfied=False, additional_phase_diagnostics_run=False,
            held_out_population_selected=False, physical_acceptance_authority=False, release_authority=False,
            original_attempt_reclassified=False, sdk1_score='14/20'))

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--create', action='store_true')
    args = parser.parse_args()
    observed = reconstruct()
    if args.create:
        with RECORD.open('xb') as stream:
            stream.write((json.dumps(observed, indent=2, allow_nan=False) + '\n').encode())
    else:
        require(packet.same(read(RECORD), observed), 'IMMUTABLE_CLOSURE_BINDING')
    print('R10Q_DEVELOPMENT_PAIR_CLOSURE ' + json.dumps(dict(ok=True, status=observed['status'],
        physical_world_count=2, completed_solver_steps=2900, safety_tests=184,
        all_tasks_positive=False, additional_diagnostics_permitted=False, sdk1_score='14/20')))

if __name__ == '__main__': main()
