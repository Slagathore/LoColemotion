"""Source/identity custody, full native replay and unchanged mechanical task checks."""
import json
import os
from pathlib import Path
import sys
import types
import recovery_discovery as D
import recovery_panel as P
sys.path.insert(0,str(D.ROOT/'sdk/conformance'))
sys.path.insert(0,str(D.ROOT/'sdk/python'))
import r10ap_finite_task_audit as T
import recovery_panel_contacts as C
from sporespore_locomotion import LocomotionCore

MARKER = 'SPORESPORE_DEVELOPMENT_RECOVERY_SMOKE_RAW '
FILE_MARKER = 'DISCOVERY_FULL_REPORT_FILE '


def retain_report(child,declaration):
    """Validate the declared wire and retain every byte before either reader."""
    if declaration.get('report_publication') == 'direct_file_v1':
        lines=(child/'stdout.log').read_text(encoding='utf-8-sig').splitlines()
        publications=[json.loads(line[len(FILE_MARKER):]) for line in lines if line.startswith(FILE_MARKER)]
        D.require(len(publications)==1 and not any(line.startswith(MARKER) for line in lines),'PANEL_ONE_FILE_PUBLICATION')
        value=publications[0];path=child/'worker-streamed-report.json'
        D.require(value.get('ok') is True and value.get('telemetry_reduced') is False
                  and value.get('physical_acceptance_authority') is False and value.get('release_authority') is False
                  and value.get('transport_id')=='godot_4_7_sorted_full_precision_authoritative_json_v1'
                  and value.get('parent_attempt_id')==declaration['attempt_id']
                  and value.get('child_attempt_id')==declaration['children'][0]['child_attempt_id'],'PANEL_FILE_PUBLICATION_CONTEXT')
        D.require(value.get('path')==path.as_posix() and not Path(str(path)+'.partial').exists(),'PANEL_FILE_PUBLICATION_PATH')
        D.require({key:value.get(key) for key in ('path','byte_length','raw_sha256')}==D.binding(path),'PANEL_FILE_PUBLICATION_BYTES')
        # Persist the completed native file before acknowledging retention.
        with path.open('r+b') as stream:stream.flush();os.fsync(stream.fileno())
        return path
    found=0;path=child/'worker-report.json'
    with (child/'stdout.log').open(encoding='utf-8-sig') as stream:
        for line in stream:
            if line.startswith(MARKER):
                found+=1
                with path.open('x',encoding='utf-8',newline='\n') as output:output.write(line[len(MARKER):])
    D.require(found==1,'PANEL_ONE_REPORT')
    return path


def validate_report_header(report, declaration):
    child=declaration['children'][0];cell=declaration['discovery_cell']
    D.require(report['ok'] is True and all(report.get(k) is False for k in D.FLAGS+('held_out','complete_route_proven')), 'PANEL_REPORT_CLAIMS')
    D.require(report['parent_attempt_id']==declaration['attempt_id'] and report['child_attempt_id']==child['child_attempt_id']
              and report['arm_id']==child['role']==cell['role'] and report['source_commit']==declaration['source_snapshot']['head']
              and report['seed']==declaration['seed'], 'PANEL_REPORT_IDENTITY')
    expected=dict(schema_version='sporespore_full_recovery_discovery_context_v1',cell=cell,manifest=declaration['discovery_manifest'],
                  allowed_entry_kinds=['partial','prone','upright'],historical_partial_only_task_regraded=False,
                  physical_acceptance_authority=False,release_authority=False)
    D.require(report.get('recovery_panel')==expected and report.get('held_out_cell_access_count')==0, 'PANEL_REPORT_CONTEXT')
    label='DISCOVERY-PHASE-'+str(cell['phase'])+'-V1'
    D.require(report['seed_label']==label and report['seed_sha256']==D.digest(label.encode()), 'PANEL_REPORT_SEED')
    D.require(report['world_build_count']==1 and report['global_solver_frame_count']==report['solver_step_count'], 'PANEL_REPORT_WORLD')
    sessions=[s for s in report['retained_arm']['walking_sessions'] if s['evaluation_segment_id']=='walking_prefix']
    D.require(len(sessions)==1 and sessions[0]['start_receipt']['initial_gait_steps']==dict.fromkeys(('front_left','front_right','rear_left','rear_right'),cell['phase']), 'PANEL_PREFIX_PHASE')
    D.require(report['terminal_same_body_identity_receipt']['ok'] is True,'PANEL_TERMINAL_IDENTITY')


def measure(report,compiled):
    # The historical mechanical helpers are unchanged. Only allowed entry-kind
    # membership is prospectively broader in this discovery task.
    task=T.contract();role=report['arm_id'];count=report['solver_step_count']
    T.require(role in T.ROLES and report['ok'] is True,'PANEL_ROLE')
    bound=task['limits']['maximum_no_kick_child_solver_steps' if role==T.ROLES[0] else 'maximum_kicked_child_solver_steps']
    T.require(type(count) is int and 0<count<=bound,'PANEL_BOUND')
    rows=report['retained_arm']['trace_rows']
    T.require(len(rows)==count and [r['global_semantic_step'] for r in rows]==list(range(1,count+1)) and all(r['arm_id']==role for r in rows),'PANEL_TRACE')
    T.require(report['external_kick_application_count']==int(role==T.ROLES[1]),'PANEL_KICK')
    T.require(report['stance_entry']['task_contract_sha256']=='sha256:'+T.TASK_SHA,'PANEL_TASK')
    entry=T.entry_measurement(report,compiled);recovery=T.recovery_measurement(report)
    control=report.get('development_walking_entry',{}).get('rows',[])
    measured=dict(status='walking_not_reached');bounds=dict(sample_count=0,passed=False)
    if control:
        measured=T.walking.measure(report,compiled,task)
        first,last=control[0]['commanded_global_step'],control[-1]['commanded_global_step']
        T.require(last==count and last-first+1==len(control),'PANEL_WALKING_BOUND')
        selected=rows[first-1:last];ids={r['walking_session_id'] for r in selected}
        T.require(len(ids)==1 and '' not in ids,'PANEL_WALKING_SESSION')
        sessions=[s for s in report['retained_arm']['walking_sessions'] if s['session_id']==next(iter(ids))]
        T.require(len(sessions)==1 and sessions[0]['evaluation_segment_id']==task['fresh_roles'][T.ROLES.index(role)]['post_interaction_segment'],'PANEL_SEGMENT')
        T.require([r['walking_session_local_step'] for r in selected]==list(range(1,len(control)+1)),'PANEL_LOCAL_CLOCK')
        base=control[0]['request']['state']['base_pose_world']
        bounds=T.envelope(selected,T.walking.vector(base['position_m']),T.walking.rotate(base['orientation_xyzw'],(0.,0.,1.)))
    predicates=dict(entry_ready=entry['passed'],planned_cycles=measured.get('planned_cycle_predicate',False),
                    forward_advance=measured.get('body_forward_predicate',False),settled_stop=measured.get('complete_stop_predicate',False),whole_walking_envelope=bounds['passed'])
    if role==T.ROLES[1]:
        predicates.update(recovery_completed=recovery['passed'],declared_entry_kind=recovery['entry_kind'] in ('partial','prone','upright'))
    return dict(predicates=predicates,finite_task_predicates_passed=all(predicates.values()),
                historical_partial_only_branch_met=recovery['entry_kind']=='partial',
                entry=entry,recovery=recovery,walking=measured,envelope=bounds,
                task_contract_sha256='sha256:'+T.TASK_SHA,physical_acceptance_authority=False,release_authority=False)


def audit_batch(batch,cell_id=None):
    batch=Path(batch);summaries=[]
    for row in D.read(batch/'cells.json'):
        if cell_id is not None and row['cell']['cell_id']!=cell_id:continue
        folder=Path(row['folder']);declaration=D.read(folder/'declaration.json');child=Path(declaration['children'][0]['evidence_path'])
        if not (child/'process.json').exists():continue
        if (child/'discovery-audit.json').exists():summary=D.read(child/'discovery-audit.json')
        else:
            try:
                D.require(D.read(child/'relationship-audit.json')['ok'] is True and (child/'stderr.log').read_bytes()==b'', 'PANEL_PROCESS')
                D.require((child/'world-claim.json').exists(),'PANEL_WORLD_CLAIM')
                report_path=retain_report(child,declaration)
                report=D.read(report_path)
                validate_report_header(report,declaration)
                D.require(report['diagnostic_declaration_sha256']==D.binding(folder/'declaration.json')['raw_sha256'],'PANEL_REPORT_DECLARATION')
                contact=C.replay_report(report,declaration,types.SimpleNamespace(validate_report_header=validate_report_header))
                core=LocomotionCore(declaration['runtime']['images']['candidate_dll']['path'])
                measured=measure(report,core.compile_bounded_quadruped(report['configuration']['base_descriptor']))
                steps=report['solver_step_count'];del report,core
                D.process(child,'full-native-replay',[declaration['runtime']['images']['godot_engine']['path'],'--headless','--path',D.ROOT,
                          '--script','res://sdk/discovery/recovery_panel_reader_v1.gd','--','physical',folder/'declaration.json',report_path,child/'full-native-replay.json'],timeout=declaration['reader_timeout_seconds'])
                native=D.read(child/'full-native-replay.json')
                D.require(native['ok'] is True and native['test_only'] is False and native['world_build_count']==native['solver_step_count']==0,'PANEL_NATIVE_REPLAY')
                D.require(native['contact_replay']['diagnostic_steps_replayed']==contact['diagnostic_steps_replayed']==steps,'PANEL_REPLAY_POPULATION')
                summary=dict(cell=row['cell'],valid=True,solver_steps=steps,measurement=measured,contact_replay=contact,report=D.binding(report_path),physical_acceptance_authority=False,release_authority=False)
            except Exception as exc:
                summary=dict(cell=row['cell'],valid=False,failure=str(exc),physical_acceptance_authority=False,release_authority=False)
            D.write_new(child/'discovery-audit.json',summary)
        summaries.append(summary)
    out=batch/('summary-'+D.uuid.uuid4().hex+'.json')
    D.write_new(out,dict(cells=summaries,valid_count=sum(s['valid'] for s in summaries),planned_count=len(D.read(batch/'cells.json')),physical_acceptance_authority=False,release_authority=False))
    print(json.dumps(dict(summary=out.as_posix(),completed=len(summaries),valid=sum(s['valid'] for s in summaries))),flush=True)
    D.require(all(s['valid'] for s in summaries),'PANEL_INVALID_CELL_RETAINED')
