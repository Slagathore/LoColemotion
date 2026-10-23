"""Independent complete-population reader; numerical differences stay observations."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import xml.etree.ElementTree as ET

FLAGS=['physical_acceptance_authority','release_authority','equivalence_authority','training_data_authority']


def require(ok,message):
    if not ok:raise ValueError(message)


def f32(x):
    return struct.unpack('<f',struct.pack('<f',x))[0]


def sha(path):
    with path.open('rb') as stream:return hashlib.file_digest(stream,'sha256').hexdigest()


def expected_control(c,cell,step,pose,project):
    p=c['control'];profile=p['cells'][cell]
    base=2*math.pi*p['frequency_hz']*(step-1)*c['timestep_s']
    references=[]
    for offset in p['limb_phase_pi']:
        references.extend([profile['hip_amplitude_rad']*math.sin(base+math.pi*offset),
            p['knee_offset_rad']+profile['knee_amplitude_rad']*(1-math.cos(base+math.pi*offset))/2])
    return [project(max(-p['velocity_limit_rad_s'],min(p['velocity_limit_rad_s'],p['gain_per_s']*(x-y))))
            for x,y in zip(references,pose[7:])]


def audit(folder):
    declaration=json.loads((folder.parent/'declaration.json').read_text());c=declaration['contract']
    result=json.loads((folder/'worker-result.json').read_text())
    require(result['ok'] is True,'Worker did not complete; preserve its incomplete denominator')
    require(all(result[k] is False and c[k] is False for k in FLAGS),'Probe authority changed')
    require(c['schema_version']=='locolemotion_gpu_quadruped_probe_v1' and c['worlds_per_backend']==4,'Probe schema/population')
    synthetic=declaration.get('synthetic',False)
    require(result['synthetic'] is synthetic,'Synthetic/native identity crossed')
    steps=c['steps_per_world']
    require(type(steps) is int and 1<=steps<=1200 and (synthetic or steps==1200),'Probe horizon')
    require(result['completed_steps']=={key:[steps]*4 for key in ['cpu','gpu']}
            and result['constructed_worlds']==dict(cpu=4,gpu=4),'Worker counters')
    require(sha(folder/'trace.jsonl')==result['trace_sha256'],'Raw trace digest')
    require(sha(folder/'model.xml')==c['model_xml_sha256']==result['model_sha256'],'Model digest')
    model=json.loads((folder/'native-model.json').read_text())
    spec=json.loads((folder/'inputs.json').read_text())
    compiled=json.loads((folder/'compiled.json').read_text())
    for name in ['model','inputs','compiled']:
        require(model[name+'_sha256']==sha(folder/(name+'.xml' if name=='model' else name+'.json')),'Native model/input binding')
    require(compiled['world_build_count']==0 and compiled['descriptor_sha256']==c['descriptor_sha256'],'Compiler identity')
    require(tuple(model[k] for k in ['nq','nv','nu','nbody','ngeom','nsensordata'])==(15,14,8,10,10,16),'Native topology')
    require(model['sensor_addresses']==[[2*i,2*i+1] for i in range(8)],'Named sensor ordering')
    require(model['contact_and_force_stage']=='force_evaluation_state' and model['root_post_state_source']=='qpos','Sampling stage')
    xml=ET.fromstring((folder/'model.xml').read_text());motors=xml.findall('actuator/velocity')
    require(len(motors)==8 and len(xml.findall('.//body'))==9 and len(xml.findall('.//freejoint'))==1,'XML topology')
    expected_pose=[float(x) for x in xml.find('worldbody/body').attrib['pos'].split()]+[1.,0.,0.,0.]+[0.]*8
    rng=random.Random(c['seed'])
    expected_inputs=dict(initial_qpos=expected_pose,initial_lateral_velocities=[rng.uniform(-.005,.005) for _ in range(4)],
        ordered_actuators=[r.attrib['name'] for r in motors],ordered_joints=[r.attrib['joint'] for r in motors],
        force_ranges=[[float(x) for x in r.attrib['forcerange'].split()] for r in motors],geom_names=[r.attrib['name'] for r in xml.findall('.//geom')])
    require(spec==expected_inputs and model['force_ranges']==spec['force_ranges'] and model['ordered_geoms']==spec['geom_names'],'Crossed compiled input')
    sensors=xml.findall('sensor/*')
    for i,motor in enumerate(motors):
        require(sensors[2*i].tag=='actuatorfrc' and sensors[2*i].attrib==dict(name=motor.attrib['name']+'_force',actuator=motor.attrib['name']),'Named actuator sensor identity')
        require(sensors[2*i+1].tag=='jointactuatorfrc' and sensors[2*i+1].attrib==dict(name=motor.attrib['joint']+'_actuator_force',joint=motor.attrib['joint']),'Named joint sensor identity')
    expected_order=[('gpu',cell,step) for step in range(1,steps+1) for cell in range(4)]
    expected_order += [('cpu',cell,step) for cell in range(4) for step in range(1,steps+1)]
    rows={};stats={(backend,cell):dict(contact_steps=0,maximum_contacts=0,maximum_tilt_rad=0.,minimum_contact_distance_m=0.,force_cap_samples=0)
                  for backend in ['gpu','cpu'] for cell in range(4)}
    sensor_error=0.
    with (folder/'trace.jsonl').open() as stream:
        for index,line in enumerate(stream):
            r=json.loads(line);key=(r['backend'],r['cell'],r['step'])
            require(index<len(expected_order) and key==expected_order[index] and key not in rows,'Missing, repeated or crossed row')
            backend,cell,step=key;project=f32 if backend=='gpu' else float;eps=2**(-23 if backend=='gpu' else -52)
            require(r['cell_id']==c['control']['cells'][cell]['id'],'Crossed control profile')
            for field,size in [('before_qpos',15),('qpos',15),('before_qvel',14),('qvel',14),('ctrl',8),('actuator_force_nm',8),('joint_force_nm',8)]:
                require(len(r[field])==size and all(type(x) in [int,float] and math.isfinite(x) for x in r[field]),'Invalid native vector: '+field)
            prior=rows.get((backend,cell,step-1))
            initial_velocity=[0.]*14;initial_velocity[1]=project(spec['initial_lateral_velocities'][cell])
            require(r['before_qpos']==(prior['qpos'] if prior else list(map(project,expected_pose)))
                    and r['before_qvel']==(prior['qvel'] if prior else initial_velocity),'Discontinuous native state')
            require(r['ctrl']==expected_control(c,cell,step,r['before_qpos'],project),'Controller/native target mismatch')
            require(math.isfinite(r['time_s']) and abs(r['time_s']-step*c['timestep_s'])<=4*eps*step*step*c['timestep_s'],'Native clock')
            require(abs(sum(x*x for x in r['qpos'][3:7])-1)<=128*eps,'Invalid native quaternion')
            require(len(r['warnings'])==(c['cpu_warning_count'] if backend=='cpu' else 0),'Missing native warning population')
            require(all(type(r[k]) is int and r[k]>=0 for k in ['overflow','nefc','batch_contacts']),'Invalid native capacity counter')
            require(r['overflow']==0 and not any(r['warnings']) and 0<=r['nefc']<=c['njmax'],'Native overflow/warning')
            caps=[[project(x) for x in pair] for pair in spec['force_ranges']]
            require(r['on_force_cap']==[f<=lo or f>=hi for f,(lo,hi) in zip(r['actuator_force_nm'],caps)],'Clamp branch label')
            for motor,joint,(lo,hi) in zip(r['actuator_force_nm'],r['joint_force_nm'],caps):
                require(lo-32*eps*abs(lo)<=motor<=hi+32*eps*abs(hi),'Native actuator force cap')
                sensor_error=max(sensor_error,abs(motor-joint));require(abs(motor-joint)<=32*eps*max(abs(lo),abs(hi)),'Actuator/joint force disagreement')
            contacts=r['contacts'];require(0<=r['batch_contacts']<=c['naconmax'],'Contact capacity')
            if backend=='cpu':require(r['batch_contacts']==len(contacts),'CPU contact population')
            indices=[]
            for contact in contacts:
                require(contact['world']==cell and type(contact['native_index']) is int and 0<=contact['native_index']<r['batch_contacts'],'Contact world/slot attribution')
                pair=contact['geom'];require(len(pair)==2 and 0 in pair and all(type(x) is int and 0<=x<10 for x in pair) and pair[0]!=pair[1],'Contact geometry mapping')
                require(len(contact['position_m'])==3 and all(math.isfinite(x) for x in [contact['distance_m'],*contact['position_m']]),'Nonfinite contact')
                indices.append(contact['native_index'])
            require(len(indices)==len(set(indices)),'Repeated native contact slot')
            if backend=='cpu':require(sorted(indices)==list(range(len(contacts))),'Missing CPU contact')
            s=stats[backend,cell];s['contact_steps']+=bool(contacts);s['maximum_contacts']=max(s['maximum_contacts'],len(contacts))
            s['force_cap_samples']+=sum(r['on_force_cap'])
            s['maximum_tilt_rad']=max(s['maximum_tilt_rad'],math.acos(max(-1.,min(1.,1-2*(r['qpos'][4]**2+r['qpos'][5]**2)))))
            s['minimum_contact_distance_m']=min([s['minimum_contact_distance_m']]+[x['distance_m'] for x in contacts])
            rows[key]=r
    require(len(rows)==8*steps,'Incomplete batch denominator')
    for step in range(1,steps+1):
        batch=[rows['gpu',cell,step] for cell in range(4)]
        require(len({r['batch_contacts'] for r in batch})==1,'Crossed GPU contact counts')
        indices=[x['native_index'] for r in batch for x in r['contacts']]
        require(sorted(indices)==list(range(batch[0]['batch_contacts'])),'Missing/repeated global GPU contact slots')
    cells=[]
    for cell in range(4):
        entry=dict(cell=cell,id=c['control']['cells'][cell]['id'],backends={})
        for backend in ['gpu','cpu']:
            end=rows[backend,cell,steps]
            entry['backends'][backend]=dict(stats[backend,cell],steps=steps,final_root_position_m=end['qpos'][:3],forward_displacement_m=end['qpos'][0]-expected_pose[0])
        entry['cpu_gpu_max_root_distance_m']=max(math.dist(rows['cpu',cell,s]['qpos'][:3],rows['gpu',cell,s]['qpos'][:3]) for s in range(1,steps+1))
        entry['clamp_branch_disagreement_samples']=sum(a!=b for s in range(1,steps+1) for a,b in zip(rows['cpu',cell,s]['on_force_cap'],rows['gpu',cell,s]['on_force_cap']))
        entry['contact_count_disagreement_steps']=sum(len(rows['cpu',cell,s]['contacts'])!=len(rows['gpu',cell,s]['contacts']) for s in range(1,steps+1))
        cells.append(entry)
    require(all(s['contact_steps']>0 for s in stats.values()),'Contact-bearing route was not exercised in every declared cell')
    return dict(ok=True,synthetic=synthetic,rows=len(rows),worlds_per_backend=4,steps_per_world=steps,
                sensor_max_disagreement_nm=sensor_error,cells=cells,
                interpretation='Complete finite contact/control observations. The feedback servo is unqualified. No ranking, locomotion success, effective motor impulse, throughput or equivalence decision.',**{k:False for k in FLAGS})


def verify_closure(path,evidence_root):
    """Reopen retained bytes and recompute; a stored success summary is insufficient."""
    closure=json.loads(path.read_text());root=evidence_root.resolve(strict=True)
    attempt=(root/closure['attempt_id']).resolve(strict=True)
    require(attempt.parent==root,'Crossed attempt directory')
    require(all(closure[k] is False for k in FLAGS),'Closure authority changed')
    indexed=set()
    for item in closure['artifacts']:
        target=(root/item['evidence_relative_path']).resolve(strict=True)
        require(target.is_relative_to(attempt) and target not in indexed,'Crossed/repeated artifact')
        require(target.stat().st_size==item['byte_length'] and sha(target)==item['sha256'],'Retained artifact changed')
        indexed.add(target)
    require(indexed=={p.resolve() for p in attempt.rglob('*') if p.is_file()},'Incomplete retained artifact inventory')
    required=['declaration.json','consumed.json','receipt.json','independent-audit.json',
              'physical/worker-result.json','physical/trace.jsonl','physical/model.xml',
              'physical/inputs.json','physical/compiled.json','physical/native-model.json',
              'physical/stdout.log','physical/stderr.log']
    require(all((attempt/name).resolve() in indexed for name in required),'Missing required retained artifact')
    receipt=json.loads((attempt/'receipt.json').read_text())
    declaration=json.loads((attempt/'declaration.json').read_text())
    consumed=json.loads((attempt/'consumed.json').read_text())
    require(receipt['ok'] is True and receipt['physical_started'] is True and receipt['zero_world_gate_passed'] is True,'Incomplete owned execution')
    require(receipt['source_commit']==declaration['source_commit']==consumed['source_commit']==closure['source_commit'],'Crossed source freeze')
    require(consumed['attempt_id']==closure['attempt_id'] and receipt['binding']==declaration['binding'],'Crossed attempt/runtime binding')
    require(receipt['synthetic'] is closure['synthetic'],'Crossed synthetic/native closure')
    observed=audit(attempt/'physical')
    require(observed==closure['independent_audit']==receipt['audit']==json.loads((attempt/'independent-audit.json').read_text()),'Recomputed audit changed')
    return dict(ok=True,artifacts=len(indexed),rows=observed['rows'],synthetic=observed['synthetic'],**{k:False for k in FLAGS})


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('path',type=Path)
    parser.add_argument('--closure',action='store_true');parser.add_argument('--evidence-root',type=Path)
    args=parser.parse_args()
    if args.closure and args.evidence_root is None:parser.error('Closure verification needs --evidence-root')
    print(json.dumps(verify_closure(args.path,args.evidence_root) if args.closure else audit(args.path),indent=2))
