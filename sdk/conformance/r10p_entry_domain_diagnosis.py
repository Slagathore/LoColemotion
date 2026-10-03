"""Reconstruct the three R10P entry negatives without opening a physics world.

The immutable closure supplies the original result and raw report bindings.
This diagnostic describes exposed states; it never runs a successor predicate
on an old campaign or changes that campaign's acceptance decision.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ROOT.parent / 'SporeSpore_Evidence'
SOURCE = 'fb5e72ab528fa19f008dad1100ddea80d6d6f035'
CLOSURE = 'sdk/recovery/r10p_held_out_physical_closure_v1.json'
CLOSURE_SHA = 'sha256:659d0d697bf36348945f049999b608dc3b81adbea94a296c1ff49172b48185a7'
RECORD = 'sdk/recovery/r10p_entry_domain_diagnosis_v1.json'
KICK = 'kick_passive_recovery_resume'
NO_KICK = 'matched_no_kick_continuation'
HOLD_POLICY = 'sporespore_balanced_wave_recovery_startup_reference_velocity_v1'


def require(value, code):
    if not value:
        raise ValueError('R10P_ENTRY_DIAGNOSIS_' + code)


def digest(raw):
    return 'sha256:' + hashlib.sha256(raw).hexdigest()


def binding(path):
    with path.open('rb') as stream:
        sha = 'sha256:' + hashlib.file_digest(stream, 'sha256').hexdigest()
    return dict(path=path.as_posix(), byte_length=path.stat().st_size, raw_sha256=sha)


def read_report(cell, child):
    path = Path(child['evidence_path']) / 'worker_report.json'
    require(path.resolve().is_relative_to(EVIDENCE.resolve()), 'EVIDENCE_ROOT')
    bound = binding(path)
    require(bound['raw_sha256'] == cell['original_report_sha256'], 'ORIGINAL_REPORT_BYTES')
    report = json.loads(path.read_text(encoding='utf-8'))
    require(report['source_commit'] == SOURCE and report['held_out'] is True
            and report['child_attempt_id'] == cell['child_attempt_id']
            and report['seed'] == cell['seed'] and report['arm_id'] == cell['role']
            and report['solver_step_count'] == cell['solver_steps'], 'ORIGINAL_IDENTITY')
    return report, bound


def summarize_descent(samples):
    require(len(samples) == 240, 'DESCENT_POPULATION')
    first = samples[0]['semantic_step']
    require(type(first) is int and first > 0, 'DESCENT_CLOCK_TYPE')
    fields = ('torso_height_ratio', 'torso_up_dot', 'terminal_linear_speed_m_s',
              'terminal_angular_speed_rad_s', 'minimum_nonfoot_clearance_m')
    for index, row in enumerate(samples):
        require(type(row['semantic_step']) is int and row['semantic_step'] == first + index, 'DESCENT_CLOCK')
        for key in fields:
            value = row['classification'][key]
            require(type(value) in (int, float) and math.isfinite(value), 'NONFINITE_' + key)
    classes = [row['classification'] for row in samples]
    return dict(sample_count=len(samples), first_semantic_step=first,
        last_semantic_step=samples[-1]['semantic_step'],
        ranges={key: [min(c[key] for c in classes), max(c[key] for c in classes)] for key in fields},
        original_partial_geometry_samples=sum(0.25 < c['torso_height_ratio'] <= 0.5
                                             and c['torso_up_dot'] >= 0.5 for c in classes),
        original_prone_gate_samples=sum(c['entry_prone_gate'] is True for c in classes),
        joint_limits_respected_samples=sum(c['joint_limits_respected'] is True for c in classes),
        all_four_support_samples=sum(c['all_four_distal_sites_bearing'] is True for c in classes),
        final_classification=classes[-1])


def summarize_ramp(rows):
    require(len(rows) == 240, 'RAMP_POPULATION')
    first = rows[0]['semantic_step']
    for index, row in enumerate(rows):
        require(type(row['semantic_step']) is int and row['semantic_step'] == first + index, 'RAMP_CLOCK')
        require(all(type(row[key]) is bool for key in ('complete', 'four_supports', 'geometry_feasible', 'ready')), 'RAMP_SAMPLE_TYPE')
    complete = [i + 1 for i, row in enumerate(rows) if row['complete']]
    supports = [i + 1 for i, row in enumerate(rows) if row['four_supports']]
    return dict(sample_count=len(rows), first_reference_complete_command=min(complete, default=None),
        last_four_support_command=max(supports, default=None),
        complete_reference_samples=len(complete), four_support_samples=len(supports),
        original_handoff_eligible_samples=sum(row['complete'] and row['four_supports'] for row in rows),
        feasible_geometry_samples=sum(row['geometry_feasible'] for row in rows), final_sample=rows[-1])


def reconstruct():
    require(Path(subprocess.check_output(['git', 'rev-parse', '--show-toplevel'], cwd=ROOT, text=True).strip()).resolve() == ROOT, 'REPOSITORY_ROOT')
    require(subprocess.check_output(['git', 'remote', 'get-url', 'origin'], cwd=ROOT, text=True).strip()
            == 'https://github.com/Slagathore/sporespore.git', 'REPOSITORY_REMOTE')
    raw = (ROOT / CLOSURE).read_bytes()
    require(digest(raw) == CLOSURE_SHA, 'CLOSURE_BYTES')
    closure = json.loads(raw)
    audit = closure['independent_audit']
    require(audit['source_commit'] == SOURCE and audit['execution_valid'] is True
            and audit['outcome'] == 'negative' and audit['total_world_builds'] == 6
            and audit['total_solver_steps'] == 7032, 'ORIGINAL_CAMPAIGN')
    require([c['outcome'] for c in audit['cells']] == ['positive'] * 3 + ['negative'] * 3, 'ORIGINAL_RESULTS')
    claim = json.loads((Path(closure['evidence_root']) / 'campaign_claim.json').read_text(encoding='utf-8'))
    require(binding(Path(closure['evidence_root']) / 'campaign_claim.json')['raw_sha256']
            == audit['campaign_claim_sha256'], 'CLAIM_BYTES')
    children = {child['cell_id']: child for child in claim['children']}
    observations = []
    for cell in audit['cells'][3:]:
        report, bound = read_report(cell, children[cell['cell_id']])
        require(cell['execution_valid'] is True and cell['finite_task_predicates_passed'] is False
                and cell['solver_steps'] == 512, 'ORIGINAL_NEGATIVE')
        if cell['role'] == KICK:
            packets = report['passive_entry']['entry_packets']
            samples = [dict(semantic_step=p['original_passive_receipt']['memory']['last_semantic_step'],
                            classification=p['original_passive_receipt']['classification']) for p in packets]
            result = summarize_descent(samples)
            require(report['retained_arm']['orchestrator_state']['r10k_entry_kind'] == 'timeout'
                    and not report['passive_entry']['canonical_packets']
                    and not report['r10k_partial_recovery']['step_packets'], 'NO_RECOVERY_HANDOFF')
            result['terminal_joint_positions_rad'] = [dict(joint_id=j['joint_id'], position_rad=j['position_rad'])
                for j in packets[-1]['native_receipt']['collection']['collection']['observation']['state']['ordered_joint_observations']]
        else:
            entry = report['stance_entry']
            require(not entry['hold_control_rows'] and len(entry['readiness_rows']) == len(entry['neutral_control_rows']), 'NO_HOLD_HANDOFF')
            rows = []
            for ready, control in zip(entry['readiness_rows'], entry['neutral_control_rows']):
                require(ready['global_semantic_step'] == control['step']['global_semantic_step'], 'RAMP_READINESS_CLOCK')
                memory = control['step']['portable_step_receipt']['native_output']['next_memory']['joint_pose_entry']
                r = ready['source']['readiness']
                rows.append(dict(semantic_step=ready['global_semantic_step'], complete=memory['reference_ramp_complete'],
                    four_supports=r['checks']['four_native_supports'], geometry_feasible=r['checks']['zero_bias_reference_path_feasible'], ready=r['ready']))
            result = summarize_ramp(rows)
        observations.append(dict(cell_id=cell['cell_id'], seed=cell['seed'], role=cell['role'],
            original_outcome='negative', report=bound, observations=result))
    # Verify the hold identity from actual original commands, not the DLL name.
    positive = audit['cells'][2]
    report, hold_bound = read_report(positive, children[positive['cell_id']])
    holds = report['stance_entry']['hold_control_rows']
    require(len(holds) == 160 and all(row['step']['portable_step_receipt']['controller_policy_id'] == HOLD_POLICY for row in holds), 'ACTUAL_HOLD_POLICY')
    paths = ('sdk/core/src/recovery/partial_fall.rs', 'sdk/core/src/recovery.rs',
             'sdk/core/src/joint_pose_entry.rs', 'sdk/adapters/godot/gdscript/development_recovery_candidate_worker_v1.gd',
             'sdk/recovery/r10o_v50_hold_policy_contract_v1.json')
    sources = []
    for path in paths:
        original = subprocess.check_output(['git', 'show', SOURCE + ':' + path], cwd=ROOT)
        sources.append(dict(path=path, source_commit=SOURCE, byte_length=len(original), raw_sha256=digest(original)))
    return dict(schema_version='sporespore_r10p_entry_domain_diagnosis_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt', authority_mode='post_exposure_retained_diagnosis', question_class='development'),
        original_closure=dict(path=CLOSURE, raw_sha256=CLOSURE_SHA), original_source_commit=SOURCE,
        source_bindings=sources, negative_cells=observations,
        verified_hold=dict(policy_id=HOLD_POLICY, sample_count=160, report=hold_bound),
        original_campaign_outcome='negative', original_population_consumed=True,
        original_results_regraded=False, successor_physics_observed=False,
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--verify', action='store_true')
    args = parser.parse_args()
    result = reconstruct()
    if args.verify:
        require(json.loads((ROOT / RECORD).read_text(encoding='utf-8')) == result, 'RECONSTRUCTION')
        print(json.dumps(dict(ok=True, cells=3, original_outcome='negative', world_build_count=0)))
    else:
        print(json.dumps(result, allow_nan=False))
