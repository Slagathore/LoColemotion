"""Audit the bounded, retained ideal-kinematics probe without physics."""
import argparse
import json
import math
from pathlib import Path
import r10y_first_support_closure as prior
import r10z_stance_workspace_probe as probe
import r10z_support_geometry_diagnosis as geometry

RECORD = prior.ROOT/'sdk/recovery/r10z_stance_workspace_component_v1.json'
RUN = prior.EVIDENCE/'r10z-stance-workspace-63af20c26ce147db941aae98a5b216e1'


def observed():
    retained = prior.read(RUN/'probe.json')
    assert not (RUN/'stderr.txt').read_bytes()
    assert retained == probe.probe()
    model = probe.Model(*probe.retained_entry())
    assert len(retained['trace']) == 390
    residuals, motion = [], []
    previous = None
    for index,row in enumerate(retained['trace']):
        assert row['step'] == index
        dx, y, alpha = row['virtual_pose']
        q = {k:(1-alpha)*model.q[k]+alpha*model.end_q[k] for k in model.q}
        norm = math.sqrt(sum(v*v for v in q.values()))
        q = {k:v/norm for k,v in q.items()}
        position = [model.position[0]+dx*math.cos(model.yaw),y,model.position[2]-dx*math.sin(model.yaw)]
        # Independent forward reconstruction of every inverse solution, not
        # just agreement with the optimizer's cost or stopping condition.
        for i,original in enumerate(model.feet):
            hip,knee = row['joints_rad'][2*i:2*i+2]
            assert abs(hip) <= 1.6 and abs(knee) <= 1.1
            local = [( .2 if i < 2 else -.2)*model.descriptor['hip_span_scale']+model.upper*math.sin(hip)+model.lower*math.sin(hip+knee),
                     -model.upper*math.cos(hip)-model.lower*math.cos(hip+knee),
                     (-.18 if i % 2 == 0 else .18)*model.descriptor['hip_span_scale']]
            reconstructed = [p+r for p,r in zip(position,geometry.rotate(q,local))]
            residuals.append(math.dist(reconstructed,original))
        if previous is not None:
            delta = max(abs(a-b) for a,b in zip(row['joints_rad'],previous['joints_rad']))
            assert delta <= 4/120
            assert row['cost'] < previous['cost']-1e-12
            motion.append(delta)
        previous = row
    assert max(residuals) < .00015
    final = retained['trace'][-1]
    return dict(model_updates=389,terminal_reason=retained['terminal_reason'],
        initial_virtual_pose=retained['trace'][0]['virtual_pose'],terminal_virtual_pose=final['virtual_pose'],
        goal=retained['model_goal'],initial_cost=retained['trace'][0]['cost'],terminal_cost=final['cost'],
        maximum_forward_reconstruction_error_m=max(residuals),maximum_joint_increment_rad=max(motion),
        independent_forward_reconstruction_passed=True,deterministic_reproduction_passed=True,
        residual_is_unactuated_lateral_approximation=True,model_joint_and_rate_bounds_respected=True,
        controller_implemented=False,native_tracking_proven=False,force_balance_evaluated=False,
        collision_feasibility_evaluated=False,recovery_task_evaluated=False,world_build_count=0,solver_step_count=0,
        physical_acceptance_authority=False,release_authority=False)


def bindings():
    return [prior.binding(p) for p in [Path(__file__),Path(probe.__file__),Path(geometry.__file__),
        geometry.RECORD,prior.RECORD,RUN/'probe.json',RUN/'stdout.txt',RUN/'stderr.txt']]


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',action='store_true')
    args = parser.parse_args()
    result = observed()
    if args.capture:
        value = dict(schema_version='sporespore_r10z_stance_workspace_component_v1',
            ledger_scope=dict(subsystem='recovery',engine_scope='engine_neutral_geometry',authority_mode='retained_offline_model_audit',question_class='development'),
            dependencies=bindings(),observed=result,
            interpretation='This finite ideal path supports developing a torso-pose and foot-placement controller. It proves neither a deployable policy nor contact, collision, force, tracking or task success. The original consumed R10Y negative remains unchanged.')
        with RECORD.open('x',encoding='utf-8',newline='\n') as stream:
            stream.write(json.dumps(value,indent=2,allow_nan=False)+'\n')
    else:
        value = prior.read(RECORD)
        assert value['dependencies'] == bindings()
        assert value['observed'] == result
    print('R10Z_STANCE_WORKSPACE_COMPONENT '+json.dumps(result))
