"""Verify the consumed positive R10S single; never launch or promote a claim."""
import argparse
import json
from pathlib import Path
import uuid

from r10s_launch_component import ROOT, EVIDENCE, bind, read, verify
import r10s_development as development
import r10s_development_launch as launch

RECORD = ROOT/'sdk/recovery/r10s_phase246_initial_single_closure_v1.json'
RUN = EVIDENCE/'development-recovery-smoke-afe3876955d849b7933f15e759a719e2'
OUTER = EVIDENCE/'r10s-first-single-launch-d702da88d3ae4b62a1616e0ce6160721'
HEAD = '26e8833309edc206d71467d9184c07a9a6f95514'
ARCHIVE = EVIDENCE/'r10s-launcher-verification-fb21d56b92f14e4f9baad64d99af38af/source-v7/source-archive.json'
CLAIMS = dict(question_class='development', single_role_only=True, paired_effect_proven=False,
    held_out_population_declared=False, physical_acceptance_authority=False,
    release_authority=False, sdk1_score='14/20', full_program_score='14/25')


def observed():
    declaration=read(RUN/'declaration.json')
    supervisor=read(RUN/'supervisor_result.json')
    audit=read(RUN/'independent_audit.stdout.json')
    published=(RUN/'published_marker.txt').read_text(encoding='utf-8')
    prefix='DEVELOPMENT_RECOVERY_SMOKE_COMPLETE '
    assert published.startswith(prefix) and json.loads(published[len(prefix):]) == supervisor
    assert supervisor['ok'] is True and supervisor['failure_code'] == ''
    assert supervisor['independent_audit'] == audit and audit['ok'] is True
    assert supervisor['source_snapshot'] == declaration['source_snapshot'] == dict(head=HEAD,dirty=False,status=[],changed_file_bindings=[])
    assert declaration['r10s_development']['stage'] == 'initial_single_diagnostic'
    assert declaration['seed'] == 41046 and declaration['r10s_development']['seed']['prefix_phase'] == 246
    assert [c['role'] for c in declaration['children']] == [development.ROLES[1]]
    assert declaration['development_execution_mode'] == development.SINGLE
    assert launch.verify(RUN/'declaration.json')['ok']
    stages=supervisor['safety_stages']
    assert len(stages)==41 and sum(s['test_count'] for s in stages)==192 and all(s['passed'] is True for s in stages)
    finite=audit['r10s_finite_development']
    assert development.positive_result(finite,declaration['candidate_profile'],paired=False)
    measurement=finite['cells'][0]['measurement'];walking=measurement['walking']
    child=audit['children'][0];replay=child['passive_entry_replay']
    assert replay['ok'] is True and replay['complete_report_timeline_replayed'] is True
    assert read(RUN/'children'/development.ROLES[1]/'passive_entry_replay_result.json') == replay
    assert walking['command_count']==1240 and walking['cycle_end_command']==1120 and walking['stopping_commands']==120
    assert len(walking['planned_cycles'])==4 and replay['transition_count']==audit['total_solver_steps']==2128
    assert replay['entry_observation_count']==240 and replay['upright_observation_count']==376
    assert replay['walking_control_replay']['cycle_stop_final_memory']['consecutive_settled_commands']==120
    assert all(v is True for v in measurement['predicates'].values())
    assert child['stop_reason']=='diagnostic_cycle_aligned_stop_complete'
    # The old fixed-tail coverage flag remains false. The separate declared
    # finite cycle/stop predicate is the authority for this development result.
    assert audit['coverage_complete'] is False and replay['finite_recovery_task']['fixed_tail_coverage_reinterpreted'] is False
    execution=read(OUTER/'execution.json')
    assert execution['exit_code']==0 and execution['source_commit_after']==HEAD and execution['source_status_after']==[]
    return dict(ok=True,classification='valid_positive_initial_single_development',seed=41046,prefix_phase=246,
        physical_worlds=1,physical_kicks=1,physical_solver_steps=2128,entry_commands=240,upright_commands=376,
        walking_commands=1240,cycle_end_command=1120,planned_cycles=4,stopping_commands=120,
        consecutive_settled_stop_commands=120,forward_advance_m=walking['pre_first_to_post_last_body_forward_m'],
        predicates=measurement['predicates'],whole_walking_envelope=measurement['envelope']['metrics'],
        independently_replayed_transitions=2128,complete_safety_stages=41,complete_safety_tests=192,
        unchanged_fixed_tail_coverage=False,next_permitted_stage='fresh_phase246_pair_after_required_gate',**CLAIMS)


def audit(reconstruct=False):
    record=read(RECORD)
    assert record['schema_version']=='sporespore_r10s_initial_single_closure_v1' and record['claim_boundary']==CLAIMS
    for item in record['bindings']+[record['auditor'],record['evidence_manifest']]:verify(item)
    for item in read(record['evidence_manifest']['path'])['files']:verify(item)
    for item in read(ARCHIVE)['files']:
        actual=bind(ARCHIVE.parent/item['path'])
        assert actual['raw_sha256']==item['raw_sha256'] and actual['byte_length']==item['byte_length']
    result=observed();assert result==record['observed']
    if reconstruct:
        import development_recovery_smoke as smoke
        reopened=smoke.retained_checkpoint(RUN)
        assert reopened['observed']==read(RUN/'independent_audit.stdout.json')
    return dict(result,retained_checkpoint_reconstructed=reconstruct)


def create():
    assert not RECORD.exists()
    out=EVIDENCE/('r10s-initial-single-review-'+uuid.uuid4().hex);out.mkdir()
    manifest=out/'retained-evidence-manifest.json'
    value=dict(schema_version='sporespore_r10s_initial_single_retention_v1',
        files=[bind(p) for root in [RUN,OUTER] for p in sorted(root.rglob('*')) if p.is_file()])
    with manifest.open('x',encoding='utf-8',newline='\n') as stream:json.dump(value,stream,indent=2);stream.write('\n')
    record=dict(schema_version='sporespore_r10s_initial_single_closure_v1',
        ledger_scope=dict(subsystem='recovery',engine_scope='godot_jolt',authority_mode='consumed_initial_single_development_closure',question_class='development'),
        source_commit=HEAD,evidence_root=RUN.as_posix(),auditor=bind(__file__),evidence_manifest=bind(manifest),
        bindings=[bind(p) for p in [ARCHIVE,ROOT/'sdk/recovery/r10s_extended_preparation_design_v1.json',
            ROOT/'sdk/recovery/r10s_extended_preparation_finite_cycle_contract_v1.json',
            ROOT/'sdk/recovery/r10s_v56_walking_entry_contract_v7.json',
            ROOT/'sdk/recovery/r10s_launch_component_v1.json',EVIDENCE/launch.FIRST_FILE]],
        observed=observed(),claim_boundary=CLAIMS)
    with RECORD.open('x',encoding='utf-8',newline='\n') as stream:json.dump(record,stream,indent=2);stream.write('\n')
    return audit()


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--create',action='store_true')
    parser.add_argument('--reconstruct',action='store_true');args=parser.parse_args()
    print('R10S_INITIAL_SINGLE '+json.dumps(create() if args.create else audit(args.reconstruct)))
