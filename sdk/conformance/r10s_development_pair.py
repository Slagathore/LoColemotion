"""Audit the consumed positive R10S pair without launching or promoting it."""
import argparse
import json
import uuid

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify
import r10s_development as development

RECORD=ROOT/'sdk/recovery/r10s_phase246_development_pair_closure_v1.json'
RUN=EVIDENCE/'development-recovery-smoke-ece7ab1f5de14c94b322a031a32433a0'
OUTER=EVIDENCE/'r10s-fresh-pair-launch-9e5cb92d156240a0b663bc9410f7824b'
SINGLE=EVIDENCE/'development-recovery-smoke-afe3876955d849b7933f15e759a719e2'
HEAD='72f242959fed95f9afc20ae1e4b1b1fdfcbb1105'
RESERVATION=EVIDENCE/'r10s_paired_commissioning_41046_consumption_v1.json'
CLAIMS=dict(question_class='development',fresh_pair_commissioned=True,baseline_reused=False,
    causal_or_superiority_effect_proven=False,held_out_population_declared=False,
    physical_acceptance_authority=False,release_authority=False,sdk1_score='14/20',full_program_score='14/25')


def reference(path):
    item=bind(path)
    return dict(path=item['path'],raw_sha256=item['raw_sha256'])


def observed():
    declaration=read(RUN/'declaration.json');supervisor=read(RUN/'supervisor_result.json')
    audit=read(RUN/'independent_audit.stdout.json')
    text=(RUN/'published_marker.txt').read_text(encoding='utf-8');prefix='DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    assert text.startswith(prefix) and json.loads(text[len(prefix):])==supervisor
    assert supervisor['ok'] is True and supervisor['failure_code']=='' and audit['ok'] is True
    assert supervisor['independent_audit']==audit
    assert declaration['source_snapshot']==supervisor['source_snapshot']==dict(head=HEAD,dirty=False,status=[],changed_file_bindings=[])
    assert declaration['development_execution_mode']==development.PAIR and declaration['baseline_reused'] is False
    context=declaration['r10s_development'];assert context['stage']=='paired_commissioning'
    assert declaration['seed']==41046 and context['seed']['prefix_phase']==246
    assert context['prerequisite_single_diagnostic']==dict(**reference(SINGLE/'independent_audit.stdout.json'),attempt_id=SINGLE.name.removeprefix('development-recovery-smoke-'))
    stages=supervisor['safety_stages'];assert stages==declaration['safety_stages']
    assert len(stages)==41 and sum(s['test_count'] for s in stages)==192 and all(s['passed'] is True for s in stages)
    launch=read(RUN/'r10s_development_launch.json')
    assert launch['stage']=='paired_commissioning' and launch['declaration']==reference(RUN/'declaration.json')
    assert launch['first_single_reservation'] is None and launch['stage_reservation']==reference(RESERVATION)
    assert launch['freeze']==dict(root=ROOT.as_posix(),remote='https://github.com/Slagathore/sporespore.git',branch='main',head=HEAD,origin_main=HEAD,live_origin_main=HEAD,clean=True)
    assert read(RESERVATION)==dict(schema_version='sporespore_r10s_stage_consumption_v1',design_sha256=development.DESIGN_SHA,
        stage='paired_commissioning',seed=41046,attempt_id=declaration['attempt_id'],declaration=reference(RUN/'declaration.json'),source_commit=HEAD,attempt_limit=1)
    finite=audit['r10s_finite_development'];assert development.positive_result(finite,declaration['candidate_profile'],paired=True)
    assert [c['role'] for c in declaration['children']]==development.ROLES
    prior_ids={c['child_attempt_id'] for c in read(SINGLE/'declaration.json')['children']}
    ids=[c['child_attempt_id'] for c in declaration['children']]
    assert len(set(ids))==2 and not (set(ids)&prior_ids)
    cells=[]
    for cell,child in zip(finite['cells'],audit['children'],strict=True):
        measurement=cell['measurement'];walking=measurement['walking'];replay=child['passive_entry_replay']
        assert cell['role']==child['role'] and all(v is True for v in measurement['predicates'].values())
        assert replay['ok'] is True and replay['complete_report_timeline_replayed'] is True
        assert read(RUN/'children'/cell['role']/'passive_entry_replay_result.json')==replay
        assert replay['transition_count']==child['solver_steps']
        assert child['stop_reason']=='diagnostic_cycle_aligned_stop_complete'
        assert len(walking['planned_cycles'])==4 and walking['stopping_commands']==120
        assert walking['command_count']==walking['cycle_end_command']+120
        assert replay['walking_control_replay']['cycle_stop_final_memory']['consecutive_settled_commands']==120
        assert replay['finite_recovery_task']['cycle_and_stop_boundary_reached'] is True
        assert replay['finite_recovery_task']['fixed_tail_coverage_reinterpreted'] is False
        cells.append(dict(role=cell['role'],child_attempt_id=cell['child_attempt_id'],entry_kind=cell['entry_kind'],
            physical_solver_steps=child['solver_steps'],walking_commands=walking['command_count'],cycle_end_command=walking['cycle_end_command'],
            planned_cycles=4,stopping_commands=120,consecutive_settled_stop_commands=120,
            forward_advance_m=walking['pre_first_to_post_last_body_forward_m'],predicates=measurement['predicates'],
            entry=measurement['entry'],whole_walking_envelope=measurement['envelope']['metrics']))
    assert [c['physical_solver_steps'] for c in cells]==[1787,2128] and audit['total_solver_steps']==3915
    assert [c['walking_commands'] for c in cells]==[1170,1240]
    assert audit['coverage_complete'] is False
    execution=read(OUTER/'execution.json')
    assert execution['exit_code']==0 and execution['source_commit_after']==HEAD and execution['source_status_after']==[]
    return dict(ok=True,classification='valid_positive_fresh_pair_development',seed=41046,prefix_phase=246,
        physical_worlds=2,physical_kicks=1,total_physical_solver_steps=3915,cells=cells,
        complete_safety_stages=41,complete_safety_tests=192,unchanged_fixed_tail_coverage=False,
        next_permitted_stage='declared_phase245_241_243_single_branch_diagnostics',**CLAIMS)


def audit(reconstruct=False):
    record=read(RECORD)
    assert record['schema_version']=='sporespore_r10s_development_pair_closure_v1' and record['claim_boundary']==CLAIMS
    for item in record['bindings']+[record['auditor'],record['evidence_manifest']]:verify(item)
    for item in read(record['evidence_manifest']['path'])['files']:verify(item)
    result=observed();assert result==record['observed']
    if reconstruct:
        import development_recovery_smoke as smoke
        assert smoke.retained_checkpoint(RUN)['observed']==read(RUN/'independent_audit.stdout.json')
    return dict(result,retained_checkpoint_reconstructed=reconstruct)


def create():
    assert not RECORD.exists()
    out=EVIDENCE/('r10s-pair-review-'+uuid.uuid4().hex);out.mkdir();manifest=out/'retained-evidence-manifest.json'
    value=dict(schema_version='sporespore_r10s_pair_retention_v1',files=[bind(p) for root in [RUN,OUTER] for p in sorted(root.rglob('*')) if p.is_file()])
    with manifest.open('x',encoding='utf-8',newline='\n') as stream:json.dump(value,stream,indent=2);stream.write('\n')
    record=dict(schema_version='sporespore_r10s_development_pair_closure_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='consumed_fresh_pair_development_closure',question_class='development'),
        source_commit=HEAD,evidence_root=RUN.as_posix(),auditor=bind(__file__),evidence_manifest=bind(manifest),
        bindings=[bind(p) for p in [RESERVATION,SINGLE/'independent_audit.stdout.json',SINGLE/'supervisor_result.json',
            ROOT/'sdk/recovery/r10s_phase246_initial_single_closure_v1.json',ROOT/'sdk/recovery/r10s_extended_preparation_design_v1.json',
            ROOT/'sdk/recovery/r10s_extended_preparation_finite_cycle_contract_v1.json',ROOT/'sdk/recovery/r10s_v56_walking_entry_contract_v7.json',
            ROOT/'sdk/development/r10s_safety_stage_contract_v1.json',ROOT/'sdk/conformance/r10s_development.py',ROOT/'sdk/conformance/r10s_launch_component.py']],
        observed=observed(),claim_boundary=CLAIMS)
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    return audit()


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true');parser.add_argument('--reconstruct',action='store_true');args=parser.parse_args()
    result=create() if args.create else audit(args.reconstruct)
    print('R10S_DEVELOPMENT_PAIR '+json.dumps(result))
