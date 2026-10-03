"""Retained-data diagnosis only. No physical launch or old-result correction."""
import hashlib
import json
from pathlib import Path
import subprocess

import development_recovery_smoke as smoke

ROOT = Path(__file__).resolve().parents[2]
CHECKPOINT = ROOT / 'sdk/development_recovery_prone_deadline_checkpoint_v1.json'
SOURCE = 'ea8c699f6816143356c5a6b95159cf79f59677f6'


def diagnose():
    checkpoint = smoke.read(CHECKPOINT)
    evidence = Path(checkpoint['evidence_root'])
    smoke.validate_checkpoint(checkpoint, smoke.retained_checkpoint(evidence))
    path = evidence / 'children/kick_passive_recovery_resume/worker_report.json'
    report = smoke.read(path)
    arm = report['retained_arm']
    pre = report['precondition_terminal_receipt']
    memory = arm['recovery_memory']
    raw_observation = json.loads(arm['last_recovery_collection_transport_retention']['response']['utf8_text'])
    observation = raw_observation['value']['observation']
    smoke.require(memory['start_semantic_step'] == 273 and memory['total_steps_observed'] == 60
                  and memory['terminal_failure_code'] == 'phase_timeout:confirm_prone', 'ENTRY_DIAGNOSIS_MEMORY')
    source_bindings = []
    paths = ('sdk/core/src/recovery.rs',
             'sdk/adapters/godot/gdscript/qsdk_r10f_l15_no_actuation_worker_stage_v1.gd',
             'tests/test_sdk_qsdk_r10f_continuous_passive_recovery_worker.gd')
    for relative in paths:
        raw = subprocess.check_output(['git', 'show', f'{SOURCE}:{relative}'], cwd=ROOT)
        source_bindings.append(dict(path=relative, commit=SOURCE, byte_length=len(raw),
                                    git_blob_content_sha256='sha256:' + hashlib.sha256(raw).hexdigest()))
    prone_reference = pre['recovery_memory']['initial_center_of_mass_height_m']
    postkick_reference = memory['initial_center_of_mass_height_m']
    # A derived value, not a replacement for a retained native measurement.
    standing_com = prone_reference + pre['recovery_classification']['center_of_mass_height_gain_m']
    rise = 0.22  # Frozen profile; the Rust classifier regression checks this exact value.
    return dict(
        schema_version='sporespore_development_recovery_entry_initialization_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
                          authority_mode='retained_data_diagnosis', question_class='development'),
        source_commit=SOURCE, source_bindings=source_bindings, evidence_root=evidence.as_posix(),
        worker_report_sha256=smoke.sha(path),
        observed=dict(
            canonical_prone_reference_com_m=prone_reference,
            postkick_reference_com_m=postkick_reference,
            postkick_controller_first_sample_global_step=memory['start_semantic_step'],
            postkick_controller_samples=memory['total_steps_observed'],
            postkick_prone_samples=arm['orchestrator_state']['consecutive_prone_sample_count'],
            terminal_com_m=observation['center_of_mass']['position_world_m']['y'],
            terminal_com_vertical_speed_m_s=observation['center_of_mass']['linear_velocity_world_m_s']['y'],
            terminal_applied_motor_impulses_nms=[v['applied_angular_impulse_nms']
                                               for v in observation['applied_actuation']['ordered_applied_impulses']],
            terminal_feet_bearing=[v['bears_support'] for v in observation['state']['ordered_contact_observations']],
            observed_failure='phase_timeout:confirm_prone'),
        derived=dict(
            minimum_com_rise_m=rise,
            precondition_standing_com_m_from_retained_reference_and_gain=standing_com,
            required_com_using_prone_reference_m=prone_reference + rise,
            required_com_using_postkick_reference_m=postkick_reference + rise,
            same_precondition_stance_gain_using_postkick_reference_m=standing_com - postkick_reference),
        diagnosis=dict(
            confirmation_clock_includes_passive_descent=True,
            rise_reference_captured_before_prone=True,
            later_rise_reference_obstacle_is_counterfactual_not_an_observed_raise_body_failure=True,
            longer_timeout_alone_does_not_change_rise_reference=True),
        selected_successor_requirements=[
            'Separate bounded passive descent from canonical prone confirmation.',
            'Start canonical get-up from an actual measured prone boundary, with explicit ownership and sequence checks.',
            'Keep the original 12-sample dwell, 60-step confirmation timeout and 0.22 m rise predicate unchanged.',
            'Keep the post-kick energy ledger continuous; a control reference boundary is not an energy reset.',
            'Retain descent samples, refusal and timeout outcomes; do not repeatedly reinitialize to hide failures.',
            'Declare new source/runtime/attempt bindings before a fresh physical diagnostic.'],
        physical_worlds_started=0, native_physics_reads=0, solver_steps=0,
        runtime_fix_integrated=False, later_stance_physically_observed=False,
        behavioral_conclusion='none', physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    print(json.dumps(diagnose(), indent=2))
