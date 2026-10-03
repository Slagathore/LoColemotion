"""Retained V44 loading and support geometry; no new commands or physics.

Triangle margins describe geometry, not dynamic stability or contact truth.
The portable hinge reconstruction is labeled an estimate and compared with
retained measured body/COM observations before it can inform a successor.
"""
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET
import development_recovery_v44_support_diagnosis as source

ROOT = source.ROOT
LIMBS = tuple(source.LIMBS)
geometry = source.geometry
MJC_CLOSURE = ROOT/'sdk/development/v44_mujoco_fixed_command_closure_v1.json'
MJC_CLOSURE_SHA = 'sha256:d09dbea914e80880bf9db5f658537f146fdd58bb40a57c51c6c134e7f7265f64'


def require(value, code):
    if not value:
        raise ValueError('V44_PRELIFT_' + code)


def add(a,b): return [x+y for x,y in zip(a,b)]
def sub(a,b): return [x-y for x,y in zip(a,b)]
def scale(a,s): return [x*s for x in a]
def cross(a,b): return [a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]


def triangle_margin(point, vertices):
    require(len(vertices) == 3 and len(point) == 2 and all(len(v)==2 for v in vertices), 'TRIANGLE_SHAPE')
    require(all(math.isfinite(x) for v in [point,*vertices] for x in v), 'TRIANGLE_NONFINITE')
    center=[sum(v[k] for v in vertices)/3 for k in (0,1)]
    ordered=sorted(vertices,key=lambda v:math.atan2(v[1]-center[1],v[0]-center[0]))
    edges=list(zip(ordered,ordered[1:]+ordered[:1]))
    require(all(math.dist(a,b)>1e-12 for a,b in edges), 'TRIANGLE_COLLAPSED')
    area=sum(a[0]*b[1]-a[1]*b[0] for a,b in edges)
    require(area>1e-12, 'TRIANGLE_COLLAPSED')
    return min(((b[0]-a[0])*(point[1]-a[1])-(b[1]-a[1])*(point[0]-a[0]))/math.dist(a,b) for a,b in edges)


def masses():
    raw=MJC_CLOSURE.read_bytes()
    require(source.digest(raw)==MJC_CLOSURE_SHA, 'MODEL_CLOSURE')
    closure=json.loads(raw)
    item=next(a for a in closure['artifacts'] if Path(a['path']).name=='replay.xml')
    raw=Path(item['path']).read_bytes()
    require(source.digest(raw)==item['sha256'] and len(raw)==item['byte_length'], 'MODEL_XML')
    bodies=ET.fromstring(raw).findall('.//body')
    require(len(bodies)==9 and all(b.find('inertial').get('pos')=='0 0 0' for b in bodies), 'MASS_CENTERS')
    result={b.get('name'):float(b.find('inertial').get('mass')) for b in bodies}
    require(abs(sum(result.values())-4.72)<1e-12, 'TOTAL_MASS')
    return result


def estimated_bodies(state, descriptor):
    """Rigid hinge estimate from the walking StateFrame available to the core."""
    upper=.35*descriptor['upper_length_fraction']; lower=.35-upper
    span=descriptor['hip_span_scale']; pose=state['base_pose_world']; twist=state['base_twist_world']
    origin=geometry.vector(pose['position_m']); velocity=geometry.vector(twist['linear_velocity_m_s'])
    omega=geometry.vector(twist['angular_velocity_rad_s']); q=pose['orientation_xyzw']
    # Native anatomical x/y/z correspond to walking-observation z/y/-x.
    def rotate(v): return geometry.rotate(q,[-v[2],v[1],v[0]])
    joints={j['joint_id']:j for j in state['ordered_joint_observations']}
    result={'torso':dict(position=origin,velocity=velocity)}
    for limb in LIMBS:
        h,k=(joints[limb+'_'+name] for name in ('hip','knee'))
        hip,knee=h['position_rad'],k['position_rad']; hd,kd=h['velocity_rad_s'],k['velocity_rad_s']
        anchor=[(.2 if limb.startswith('front') else -.2)*span,0,(-.18 if limb.endswith('left') else .18)*span]
        for part in ('upper','distal'):
            if part=='upper':
                relative=[upper/2*math.sin(hip),-upper/2*math.cos(hip),0]
                rate=[upper/2*math.cos(hip)*hd,upper/2*math.sin(hip)*hd,0]
            else:
                relative=[upper*math.sin(hip)+lower/2*math.sin(hip+knee),-upper*math.cos(hip)-lower/2*math.cos(hip+knee),0]
                rate=[upper*math.cos(hip)*hd+lower/2*math.cos(hip+knee)*(hd+kd),upper*math.sin(hip)*hd+lower/2*math.sin(hip+knee)*(hd+kd),0]
            offset=rotate(add(anchor,relative))
            result[limb+'_'+part]=dict(position=add(origin,offset),velocity=add(velocity,add(cross(omega,offset),rotate(rate))))
    return result


def weighted(items, mass, key):
    require(set(items)==set(mass), 'BODY_POPULATION')
    return [sum(items[name][key][k]*m for name,m in mass.items())/sum(mass.values()) for k in range(3)]


def summarize(report):
    mass=masses(); dims=source.algebra.dimensions(report)
    native=[r for r in report['development_native_walking_contacts']['rows'] if r['segment_id']=='walking_resume']
    entries=report['development_walking_entry']['rows']
    require(len(native)==len(entries)==400, 'POPULATION')
    rows=[]
    for n,(entry,contact) in enumerate(zip(entries,native),1):
        observed=contact['native_source']['observation']; state=entry['request']['state']
        require(entry['session_local_step']==contact['session_local_step']==n and
                entry['measured_global_step']==observed['semantic_step']==857+n, 'CLOCK')
        com=observed['center_of_mass']
        require(com['source_measurement'] is True, 'MEASURED_COM')
        position=geometry.vector(com['position_world_m']); velocity=geometry.vector(com['linear_velocity_world_m_s'])
        require(all(math.isfinite(v) for v in position+velocity), 'COM_NONFINITE')
        measured={b['body_id']:dict(position=geometry.vector(b['pose_world']['position_m']),
            velocity=geometry.vector(b['twist_world']['linear_velocity_m_s'])) for b in entry['ordered_body_states']}
        estimated=estimated_bodies(state,report['configuration']['base_descriptor'])
        body_com=weighted(measured,mass,'position'); body_velocity=weighted(measured,mass,'velocity')
        require(math.dist(body_com,position)<1e-6 and math.dist(body_velocity,velocity)<1e-6, 'MEASURED_MASS_CROSSCHECK')
        feet={}
        for body in entry['ordered_body_states']:
            if body['body_id'].endswith('_distal'):
                point=add(geometry.vector(body['pose_world']['position_m']),geometry.rotate(body['pose_world']['orientation_xyzw'],[0,-dims[1]/2,0]))
                feet[body['body_id'].removesuffix('_distal')]=[point[0],point[2]]
        wave=entry['native_output']['actuation']['receipt']['recovery_support_plane']['wave_velocity']['current_wave']
        scheduled=[limb for i,limb in enumerate(LIMBS) if wave['active'] and wave['ordered_limbs'][i]['scheduled_phase_step']<=72]
        require(len(scheduled)<=1, 'SCHEDULED_SWING_POPULATION')
        support={limb:state['ordered_contact_observations'][i]['bears_support'] for i,limb in enumerate(LIMBS)}
        impulses={f['contact_site_id'].removesuffix('_foot'):f['bearing_normal_impulse_ns'] for f in observed['ordered_foot_bearing_observations']}
        require(set(impulses)==set(LIMBS) and all(math.isfinite(v) and v>=0 for v in impulses.values()), 'IMPULSE_POPULATION')
        planned=scheduled[0] if scheduled else None
        remaining=[limb for limb in LIMBS if limb!=planned] if planned else []
        margin=triangle_margin([position[0],position[2]],[feet[l] for l in remaining]) if planned else None
        raw=contact['native_source']['contact_source_receipt']['ordered_contact_samples']
        points={}
        for limb in remaining:
            samples=[c for c in raw if c['body_id']==limb+'_distal' and c['classified_as_foot'] and c['normal_impulse_ns']>0]
            total=sum(c['normal_impulse_ns'] for c in samples)
            if total>0:
                points[limb]=[sum(c['normal_impulse_ns']*c['position_world_m'][axis] for c in samples)/total for axis in ('x','z')]
        actual_margin=triangle_margin([position[0],position[2]],[points[l] for l in remaining]) if planned and len(points)==3 else None
        rows.append(dict(precommand_local=n,source_observation_global_step=857+n,planned_swing_limb=planned,
            precommand_support=support,normal_impulse_ns=impulses,measured_com_position=position,measured_com_velocity=velocity,
            projected_capsule_endpoint_xz=feet,remaining_three_measured_bearing=bool(planned and all(support[l] for l in remaining)),
            hypothetical_remaining_triangle_margin_m=margin,actual_three_contact_centroid_margin_m=actual_margin,
            estimated_com_position=weighted(estimated,mass,'position'),estimated_com_velocity=weighted(estimated,mass,'velocity'),
            estimated_com_position_error_m=math.dist(position,weighted(estimated,mass,'position')),
            estimated_com_velocity_error_m_s=math.dist(velocity,weighted(estimated,mass,'velocity')),
            measured_mass_position_crosscheck_error_m=math.dist(position,body_com),
            maximum_estimated_body_center_error_m=max(math.dist(measured[k]['position'],estimated[k]['position']) for k in mass)))
    return dict(schema_version='sporespore_v44_pre_liftoff_retained_diagnosis_v1',source_report_sha256=source.REPORT_SHA,
        ledger_scope=dict(subsystem='recovery',engine_scope=['godot'],authority_mode='retained_data_diagnosis',question_class='development'),
        measured_precommand_rows=400,total_mass_kg=sum(mass.values()),all_samples=rows,first_swing_loading_window=rows[:24],
        maximum_estimated_com_position_error_m=max(r['estimated_com_position_error_m'] for r in rows),
        maximum_estimated_com_velocity_error_m_s=max(r['estimated_com_velocity_error_m_s'] for r in rows),
        maximum_estimated_body_center_error_m=max(r['maximum_estimated_body_center_error_m'] for r in rows),
        maximum_measured_mass_position_crosscheck_error_m=max(r['measured_mass_position_crosscheck_error_m'] for r in rows),
        interpretation='The first front-left lift begins with millimetres of static COM margin. Static geometry alone is not dynamic stability. Before another controller, test explicit pre-liftoff support transfer with body-velocity damping; retain contact truth and a bounded failure path.',
        geometry_is_contact_authority=False,causal_attribution_proven=False,successful_controller_predicted=False,
        new_world_count=0,new_solver_step_count=0,physical_acceptance_authority=False,release_authority=False)
