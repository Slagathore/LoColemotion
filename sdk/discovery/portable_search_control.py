"""Production portable controller and bounded, explicitly untrained proposals."""
import copy
import json
import math
from pathlib import Path
import struct
import sys
from types import SimpleNamespace

from gpu_quadruped_model import ROOT,FLAGS,sha,build_inputs

sys.path[:0]=[str(ROOT/'sdk/python'),str(ROOT/'sdk/adapters/mujoco'),str(ROOT/'sdk/explorer')]
from sporespore_mujoco_adapter import selected_policy_development as bridge
from showcase_model import S169

CONTRACT=Path(__file__).with_name('gpu_portable_search_v2.json')
EMPTY_CORPUS=dict(schema_version='locolemotion_untrained_candidate_origin_v1',trained=False,training_corpus=None)
VIEW_FIELDS=['qpos','qvel','xpos','xmat','xipos','subtree_com','cvel','xanchor','xaxis']


def contract():
    c=json.loads(CONTRACT.read_text())
    if c['schema_version']!='locolemotion_gpu_portable_search_v2' or c['worlds_per_backend']!=4 or c['outer_steps']!=480 or any(c[k] is not False for k in FLAGS):
        raise ValueError('Portable discovery contract')
    if c['policy_id']!=bridge.SELECTED_POLICY_ID or c['stability_policy_id']!=bridge.STABILITY_POLICY_ID:
        raise ValueError('Portable policy binding changed')
    return c


def inputs(core_path,c):
    compiled,xml,spec=build_inputs(core_path,c)
    # All candidates share the same declared initialization, not different seeds.
    spec['initial_lateral_velocities']=[spec['initial_lateral_velocities'][0]]*4
    return compiled,xml,spec


def robot_view(core,compiled,model,data):
    """Attach the existing observation methods; this function constructs no world."""
    robot=object.__new__(bridge.MujocoBw19vRobot)
    robot.core=core;robot.profile_id=bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID
    robot.descriptor=dict(S169);robot.compiled=compiled;robot.morphology=compiled['morphology'];robot.spec=robot.morphology['morphology_spec']
    robot.model=model;robot.data=data;robot.ground_geom_id=model.geom('ground').id
    robot.body_geom_ids={k:model.geom(k+'_geom').id for k in robot.morphology['ordered_body_ids']}
    robot.joint_ids={k:model.joint(k).id for k in robot.morphology['ordered_joint_ids']}
    robot.actuator_ids={k:model.actuator(k).id for k in robot.morphology['ordered_actuator_ids']}
    robot.actuator_specs={r['actuator_id']:r for r in robot.spec['actuators']}
    robot.contact_sites={r['contact_site_id']:r for r in robot.spec['contact_sites']}
    robot.limbs={r['limb_id']:r for r in robot.spec['limbs']}
    robot._validate_model_identity()
    return robot


def initial_memory(core):
    return dict(schema_version='sporespore_adaptation_provider_memory_v1',provider_id='portable_parameter_search',
        reset_epoch=0,sequence=0,opaque_state={},opaque_state_sha256=core.canonicalize_json({})['sha256'],weights_mutated=False)


def proposal_request(core,c,candidate,state,command,output,baseline,memory,previous):
    model=dict(kind=c['provider']['kind'],candidate=candidate,trained=False)
    return dict(schema_version='sporespore_adaptation_provider_request_v1',request_id='portable_search_step_'+str(state['semantic_step']),
        provider_id='portable_parameter_search',expected_provider_version='untrained_parameter_v1',
        expected_model_id=candidate['id'],expected_model_sha256=core.canonicalize_json(model)['sha256'],
        expected_training_corpus_id='untrained_no_training_corpus',expected_training_corpus_sha256=core.canonicalize_json(EMPTY_CORPUS)['sha256'],
        descriptor=dict(S169),state=state,command=command,deterministic_baseline=baseline,
        controller_context=dict(schema_version='sporespore_adaptation_controller_context_v1',source_policy_id=c['policy_id'],skill_id='bounded_walk',phase_id=None,
            controller_memory_schema_version=output['next_memory']['schema_version'],controller_memory=output['next_memory'],
            controller_memory_sha256=core.canonicalize_json(output['next_memory'])['sha256'],engine_specific=False,physical_acceptance_authority=False),
        history=dict(schema_version='sporespore_adaptation_history_v1',ordered_entries=[]),provider_memory=memory,
        safety_envelope=dict(schema_version='sporespore_adaptation_safety_envelope_v1',correction_kind='canonical_velocity_delta_rad_s',
            minimum_confidence=1.0,maximum_support_distance=0.0,
            ordered_actuator_limits=[dict(actuator_id=r['actuator_id'],maximum_absolute_correction_rad_s=c['provider']['maximum_absolute_correction_rad_s'],
                maximum_slew_per_step_rad_s=c['provider']['maximum_slew_per_step_rad_s'],previous_applied_correction_rad_s=previous[i]) for i,r in enumerate(baseline['ordered_commands'])],
            deterministic_baseline_fallback_required=True,engine_specific_output_allowed=False,direct_world_access_allowed=False,safety_limit_override_allowed=False,physical_acceptance_authority=False),
        seed=c['seed'],provider_may_build_worlds=False,provider_may_modify_physics_state=False,provider_has_physical_acceptance_authority=False)


def proposal(core,request,candidate):
    if candidate['factor'] is None:return None
    if request['descriptor']!=S169:raise ValueError('Untrained candidate outside exact S169 domain')
    memory=copy.deepcopy(request['provider_memory']);memory['sequence']+=1
    return dict(schema_version='sporespore_adaptation_provider_response_v1',request_id=request['request_id'],
        request_sha256=core.canonicalize_json(request)['sha256'],status='applied',confidence=1.0,support_distance=0.0,
        ordered_corrections=[dict(actuator_id=r['actuator_id'],canonical_velocity_delta_rad_s=candidate['factor']*r['combined_canonical_target_velocity_rad_s']) for r in request['deterministic_baseline']['ordered_commands']],
        next_memory=memory,provenance=dict(provider_id=request['provider_id'],provider_version=request['expected_provider_version'],
            model_id=request['expected_model_id'],model_sha256=request['expected_model_sha256'],training_corpus_id=request['expected_training_corpus_id'],
            training_corpus_sha256=request['expected_training_corpus_sha256'],seed=request['seed'],engine_specific_logic_used=False,direct_world_access_used=False,weights_mutated=False,physical_acceptance_authority=False),
        candidate_experience=None,diagnostics=['untrained_parameter_search; confidence denotes exact declared support only'],physical_acceptance_authority=False)


def map_resolution(mapping,resolution):
    """The adapter owns the sign conversion; never relabel a changed baseline receipt."""
    if (mapping['engine_id']!='mujoco' or mapping['host_profile_id']!=bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID
            or mapping['canonical_to_host_velocity_sign']!=1.0 or mapping['native_position_stiffness']!=0.0
            or mapping['independent_native_position_feedback_applied'] or len(resolution['ordered_commands'])!=8):
        raise ValueError('Provider/native mapping identity')
    targets=[]
    for old,new in zip(mapping['ordered_commands'],resolution['ordered_commands'],strict=True):
        value=new['final_canonical_target_velocity_rad_s']*mapping['canonical_to_host_velocity_sign']
        if old['actuator_id']!=new['actuator_id'] or old['native_target_position_rad'] is not None or not math.isfinite(value) or abs(value)>old['maximum_host_target_speed_rad_s']:
            raise ValueError('Provider/native command order or bounds')
        if old['canonical_target_velocity_rad_s']!=new['baseline_canonical_target_velocity_rad_s']:
            raise ValueError('Crossed provider baseline')
        if resolution['deterministic_baseline_fallback_used'] and struct.pack('d',value)!=struct.pack('d',old['host_target_velocity_rad_s']):
            raise ValueError('Absent/rejected provider changed baseline bits')
        targets.append(value)
    return targets


class Controller:
    def __init__(self,core,compiled,c,cell):
        self.core=core;self.c=c;self.candidate=c['provider']['candidates'][cell]
        self.context=SimpleNamespace(core=core,descriptor=dict(S169),morphology=compiled['morphology'],profile_id=bridge.PER_ACTUATOR_DEVELOPMENT_PROFILE_ID)
        self.memory=core.balanced_wave_initial_memory();self.composition_memory=bridge.CompositionMemory()
        self.provider_memory=initial_memory(core);self.previous=[0.]*8
        self.session=core.create_balanced_wave_policy_session(c['policy_id'],S169)

    def close(self):self.session.close()

    def step(self,state,stability,kinematics):
        step=state['semantic_step'];command=bridge._motion_command(step,self.c['phase_mode'])
        request=dict(memory=self.memory,state=state,command=command)
        limb_steps=bridge._ordered_limb_steps(self.memory,self.context.morphology['ordered_limb_ids'])
        output=self.session.step(request);actuation=output['actuation']
        if actuation['receipt']['controller_error'] is not None or actuation['failure_codes']:
            raise ValueError('Portable controller refused: '+str(actuation['failure_codes']))
        composition=bridge.compose_bw19v_step(self.context,actuation,stability,kinematics,limb_steps,self.composition_memory)
        provider=proposal_request(self.core,self.c,self.candidate,state,command,output,composition['canonical_actuation'],self.provider_memory,self.previous)
        response=proposal(self.core,provider,self.candidate)
        resolution_request=dict(schema_version='sporespore_adaptation_resolution_request_v1',provider_request=provider,provider_response=response)
        resolution=self.core.resolve_adaptation_v1(resolution_request)
        if resolution['fallback_reason'] not in ('none','provider_absent','safe_no_actuation'):raise ValueError('Unexpected provider refusal: '+resolution['fallback_reason'])
        targets=map_resolution(composition['host_mapping'],resolution)
        self.memory=output['next_memory'];self.provider_memory=resolution['next_memory'];self.previous=[r['applied_correction_rad_s'] for r in resolution['ordered_commands']]
        return dict(request=request,output=output,stability=stability,kinematics=kinematics,composition=composition,
                    resolution_request=resolution_request,resolution=resolution,native_targets=targets)


def rank(c,metrics):
    result=[]
    for i,m in enumerate(metrics):
        eligible=(m['minimum_height_m']>=c['selection']['minimum_height_m'] and m['maximum_tilt_rad']<=c['selection']['maximum_tilt_rad']
                  and m['torso_contact_steps']<=c['selection']['maximum_torso_contact_steps'] and m['safe_no_actuation_steps']==0)
        result.append(dict(cell=i,candidate=c['provider']['candidates'][i]['id'],eligible=eligible,forward_displacement_m=m['forward_displacement_m']))
    ordered=sorted((r for r in result if r['eligible']),key=lambda r:(-r['forward_displacement_m'],r['cell']))
    return dict(candidates=result,ranked_cells=[r['cell'] for r in ordered],selected_cell=ordered[0]['cell'] if ordered else None,
                selection_scope='exposed_finite_gpu_discovery',trained_provider=False,physical_acceptance_authority=False)
