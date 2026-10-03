"""Read-only SDK1 M20 closure check; never launches a physics engine."""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import sys

SDK=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(SDK/'explorer'))
from audit_showcase import audit, bound_file, require

EDIT_CHECKS={'edited_construction_refuses_native_launch','generated_body_refuses_native_launch',
    'exact_native_body_restored','camera_orbit','camera_zoom','wireframe_toggle','camera_reset',
    'three_evidence_labels','runtime_and_source_provenance','presentation_has_no_native_bodies'}
REPLAY_CHECKS={'recorded_replay_advances','explicit_replay_label','replay_reaches_original_last_frame',
    'presentation_has_no_native_bodies','retained_session_loaded'}
CHECKER_PATHS={'conformance/check_showcase_desktop.py','conformance/check_showcase_desktop.gd','release/check_explorer.py'}


def validate(closure):
    result=audit(closure)
    require(set(closure['desktop_checker_sources'])==CHECKER_PATHS,'Desktop checker source population')
    for relative,binding in closure['desktop_checker_sources'].items():
        require(bound_file(binding).resolve()==(SDK/relative).resolve(),'Desktop checker source identity')
    layout=json.loads(bound_file(closure['isolated_layout']).read_text())
    require(layout['git_present'] is False and layout['game_project_present'] is False and layout['source_only'] is True,'Isolated layout boundary')
    require(layout['candidate_package'] is False and layout['release_authority'] is False,'Layout authority')
    for cell in closure['engines'].values():
        receipt=json.loads(bound_file(cell['receipt']).read_text())
        require(receipt['source_commit']==layout['source_commit'],'Mixed isolated source freezes')
    for mode,required in [('editing',EDIT_CHECKS),('replay',REPLAY_CHECKS)]:
        row=closure['desktop_interactions'][mode]
        report=json.loads(bound_file(row['report']).read_text())
        require(report['ok'] is True and report['mode']==mode,'Desktop interaction result')
        require(type(report['world_build_count']) is int and report['world_build_count']==0 and report['native_launch_count']==0,'Desktop check launched physics')
        require(required<=set(report['checks']),'Incomplete desktop interaction coverage')
        require('SHOWCASE_DESKTOP_PASS' in bound_file(row['log']).read_text(),'Desktop interaction log')
        bound_file(row['screenshot'])
    result['desktop_interactions_passed']=True
    result['isolated_source_commit']=layout['source_commit']
    return result


def controls(closure,folder):
    folder.mkdir(parents=True,exist_ok=False)
    cases=[]
    def mutation(name,fn):
        value=copy.deepcopy(closure);fn(value);cases.append((name,value))
    mutation('authority_overclaim',lambda v:v.update(release_authority=True))
    mutation('missing_engine',lambda v:v['engines'].pop('mujoco'))
    mutation('altered_native_receipt',lambda v:v['engines']['godot_jolt']['receipt'].update(sha256='0'*64))
    mutation('altered_native_stream',lambda v:v['engines']['rapier_parry']['stream'].update(sha256='0'*64))
    mutation('unreviewed_ui',lambda v:v['visible_ui'].update(visually_reviewed=False))
    mutation('altered_checker',lambda v:v['desktop_checker_sources']['conformance/check_showcase_desktop.gd'].update(sha256='0'*64))
    mutation('missing_replay',lambda v:v['desktop_interactions'].pop('replay'))
    for mode in ['editing','replay']:
        for fault in ['world','coverage']:
            value=copy.deepcopy(closure)
            report=json.loads(bound_file(value['desktop_interactions'][mode]['report']).read_text())
            if fault=='world':report['world_build_count']=1
            else:report['checks']=[]
            path=folder/(mode+'-'+fault+'.json');path.write_text(json.dumps(report),encoding='utf-8')
            value['desktop_interactions'][mode]['report']={'path':str(path),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
            cases.append((mode+'_'+fault,value))
    passed=[]
    for name,value in cases:
        try:validate(value)
        except (ValueError,KeyError):passed.append(name)
        else:raise ValueError('Negative control accepted: '+name)
    return passed


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--closure',type=Path,default=SDK/'explorer/showcase_closure_v1.json')
    parser.add_argument('--output',type=Path)
    parser.add_argument('--negative-controls',type=Path)
    args=parser.parse_args()
    try:
        closure=json.loads(args.closure.read_text(encoding='utf-8-sig'))
        result=validate(closure)
        if args.negative_controls:result['negative_controls_passed']=controls(closure,args.negative_controls)
    except Exception as exc:
        print(json.dumps(dict(ok=False,error=str(exc),world_build_count=0)));return 1
    if args.output:
        with args.output.open('x',encoding='utf-8') as out:json.dump(result,out,indent=2)
    print(json.dumps(result));return 0


if __name__=='__main__':raise SystemExit(main())
