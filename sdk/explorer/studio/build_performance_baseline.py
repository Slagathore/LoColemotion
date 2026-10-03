"""Describe retained showcase timing without launching or ranking engines.

The three runs exercise different schedules and telemetry. Their reported
native-loop clocks include controller work, transport and intentional pacing.
They are application measurements, never pure solver benchmarks.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

SDK=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(SDK/'explorer'))
from audit_showcase import audit, bound_file


def summarize(receipt,frames):
    last=frames[-1]
    simulated=float(last['simulation_time_s'])
    loop=float(last['physics_wall_time_s'])
    session=float(receipt['physical']['elapsed_s'])
    if not 0<loop<=session or simulated<=0:raise ValueError('Invalid clock population')
    phases=[];impulses=[];previous=None
    for frame in frames:
        phase=frame.get('phase','native_walking')
        if phase!=previous:
            phases.append(dict(phase=phase,first_step=frame['frame_index'],simulation_time_s=frame['simulation_time_s']))
            previous=phase
        for impulse in frame.get('applied_impulses',[]):
            impulses.append(dict(observed_step=frame['frame_index'],simulation_time_s=frame['simulation_time_s'],receipt=impulse))
    return dict(solver_steps=last['frame_index'],published_frames=len(frames),
        simulated_seconds=simulated,reported_native_loop_seconds=loop,
        physical_session_seconds=session,
        outside_reported_native_loop_seconds=session-loop,
        native_loop_realtime_factor=simulated/loop,
        preflight_seconds=receipt['preflight']['elapsed_s'],
        phase_entries=phases,impulses=impulses,
        outcome=receipt['physical']['completed'].get('outcome'),
        hello={k:v for k,v in receipt['physical']['hello'].items() if k!='scene'},
        runtime=receipt['runtime'])


def compile_report(closure):
    audit(closure)
    rows={};series={}
    for engine,bindings in closure['engines'].items():
        receipt=json.loads(bound_file(bindings['receipt']).read_text())
        with bound_file(bindings['stream']).open(encoding='utf-8') as stream:
            frames=[r for line in stream if (r:=json.loads(line)).get('message_type')=='frame']
        rows[engine]=summarize(receipt,frames)
        series[engine]=[]
        for frame in frames:
            torso=next(b for b in frame['ordered_bodies'] if b['body_id']=='torso')
            series[engine].append(dict(simulation_time_s=frame['simulation_time_s'],height_m=torso['position_m']['y'],forward_m=torso['position_m']['x']))
        if engine=='godot_jolt':
            costs=receipt['physical']['completed']['summary']['cost']
            rows[engine]['exclusive_profile_seconds']={k:v['exclusive_us']/1e6 for k,v in costs.items()}
    return dict(schema_version='sporespore_explorer_application_performance_baseline_v1',
        ledger_scope=dict(subsystem='explorer',engine_scope='3e',authority_mode='retrospective_application_timing',question_class='development'),
        comparison_kind='unmatched_application_diagnostics',engines=rows,series=series,
        original_inputs=closure['engines'],
        interpretation=['Schedules, starting poses and telemetry differ; these runs cannot rank physics engines.',
            'Reported native-loop time includes controller, observation, transport and pacing work.',
            'Time outside the reported loop is an arithmetic residual, not a separately profiled startup component.',
            'Between-callback timing is not an isolated physics-solver benchmark.',
            'Profiles report wall time on this host; no confidence interval or general performance guarantee is inferred.'],
        world_build_count=0,solver_step_count=0,physical_acceptance_authority=False,release_authority=False)


def render(report,folder):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.size':10,'axes.spines.top':False,'axes.spines.right':False})
    names={'godot_jolt':'Godot / Jolt','mujoco':'MuJoCo','rapier_parry':'Rapier / Parry'}
    colors={'godot_jolt':'#137c8b','mujoco':'#bb6023','rapier_parry':'#7652a3'}
    fig,axes=plt.subplots(1,2,figsize=(13,5.5))
    for i,(engine,row) in enumerate(report['engines'].items()):
        rate=row['native_loop_realtime_factor']
        axes[0].barh(i,rate,color=colors[engine]);axes[0].text(rate+.025,i,f'{rate:.3f}×',va='center')
        axes[1].barh(i,row['reported_native_loop_seconds'],color=colors[engine])
        axes[1].barh(i,row['outside_reported_native_loop_seconds'],left=row['reported_native_loop_seconds'],color='#b8c0cb')
    for ax in axes:ax.set_yticks(range(3),[names[e] for e in report['engines']]);ax.invert_yaxis()
    axes[0].axvline(1,color='#555',ls='--',lw=1);axes[0].set_xlim(0,1.22);axes[0].set_xlabel('Reported native-loop real-time factor')
    axes[1].set_xlabel('Physical-session wall seconds');axes[1].set_title('Colored: reported loop • gray: residual outside loop',fontsize=10)
    fig.suptitle('Showcase application baseline — different tasks and telemetry',fontsize=15)
    fig.text(.5,.025,'One retained run per engine. No solver ranking, cross-engine equivalence or throughput ceiling is established.',ha='center',fontsize=10)
    fig.tight_layout(rect=(0,.07,1,.92));fig.savefig(folder/'application-timing.png',dpi=150);fig.savefig(folder/'application-timing.svg');plt.close(fig)
    fig,axes=plt.subplots(2,1,figsize=(12,9))
    costs=report['engines']['godot_jolt']['exclusive_profile_seconds']
    top=sorted(costs.items(),key=lambda item:item[1],reverse=True)[:9]
    axes[0].barh([name.replace('_',' ') for name,_ in reversed(top)],[cost for _,cost in reversed(top)],color='#137c8b')
    axes[0].set_xlabel('Exclusive profiled wall seconds');axes[0].set_title('Godot diagnostic pipeline: largest measured costs')
    for engine,rows in report['series'].items():
        axes[1].plot([r['simulation_time_s'] for r in rows],[r['height_m'] for r in rows],label=names[engine],color=colors[engine])
    for event in report['engines']['godot_jolt']['phase_entries']:
        if event['phase'] in ['native_kick_or_matched_no_kick_step','measured_upright_stabilization','fresh_selected_policy_walking_resume']:
            axes[1].axvline(event['simulation_time_s'],ls=':',alpha=.6,color=colors['godot_jolt'])
    axes[1].set_xlabel('Simulation seconds, including each route’s setup');axes[1].set_ylabel('Native torso height (m)');axes[1].legend()
    axes[1].set_title('Different initial states and schedules are visible in the retained traces')
    fig.tight_layout();fig.savefig(folder/'diagnostic-cost-and-traces.png',dpi=150);fig.savefig(folder/'diagnostic-cost-and-traces.svg');plt.close(fig)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--closure',type=Path,default=SDK/'explorer/showcase_closure_v1.json')
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args();report=compile_report(json.loads(args.closure.read_text()))
    args.output.mkdir(parents=True,exist_ok=False)
    (args.output/'report.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    fields=['engine','solver_steps','published_frames','simulated_seconds','reported_native_loop_seconds','physical_session_seconds','outside_reported_native_loop_seconds','native_loop_realtime_factor','preflight_seconds']
    with (args.output/'summary.csv').open('w',encoding='utf-8',newline='') as out:
        writer=csv.DictWriter(out,fieldnames=fields);writer.writeheader()
        for engine,row in report['engines'].items():writer.writerow(dict(engine=engine,**{k:row[k] for k in fields[1:]}))
    render(report,args.output)
    manifest={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in args.output.iterdir() if p.is_file()}
    (args.output/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'ok':True,'output':str(args.output),'native_loop_realtime_factors':{e:r['native_loop_realtime_factor'] for e,r in report['engines'].items()},'world_build_count':0}))


if __name__=='__main__':main()
