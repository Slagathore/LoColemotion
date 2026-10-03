"""Bounded continuation of R10BA with immutable global contact/shape guards.

Synthetic rebasing does not create native observations or new support points.
No contact-mode changes or retries are allowed within this declared path.
"""
import argparse
import json
import sys
import numpy as np

import r10ba_nonlinear_contact_step as B
import r10at_fixed_contact_path as T

S, C, G, Z = B.S, B.C, B.G, B.Z
STUDY = C.ROOT/'sdk/recovery/r10bb_nonlinear_contact_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bb_nonlinear_contact_path_result_v1.json'
MAX_STEPS = 600


def global_guards(model, delta, contacts, floor, joints, modes):
    points = model.contact_points(delta)
    equality = Z.contact_residual(model, delta, modes, contacts)
    extent = np.maximum(S.LIMITS-.02, np.abs(joints))
    residual = dict(original_active_anchor=float(np.max(np.abs(equality))),
        original_marker_descent=float(np.max(contacts[:, 1]-points[:, 1])),
        original_floor=float(np.max(np.minimum(0., floor)-model.features_y(delta))),
        original_joint_headroom=float(np.max(np.abs(model.joints+delta[6:])-extent)))
    return dict(ok=B.geometry_allowed(residual), residuals=residual)


def controls():
    checked = B.controls()
    class Manufactured:
        joints = np.zeros(8)
        def contact_points(self, delta):return np.array([[0., 0., 0.], [1., 0., 0.]])+delta[:3]
        def features_y(self, delta):return np.array([-.002, .01])+delta[1]
    model = Manufactured(); zero = np.zeros(14); contacts = model.contact_points(zero); floor = model.features_y(zero)
    def allowed(delta, modes=(1, 2)):
        return global_guards(model, delta, contacts, floor, model.joints, modes)['ok']
    assert allowed(zero)
    first = zero.copy(); first[0] = .75e-9
    assert allowed(first) and not allowed(2*first)
    down = zero.copy(); down[1] = -2e-9
    assert not allowed(down)
    up = zero.copy(); up[1] = 2e-9
    assert not allowed(up, (0, 2))
    slide = zero.copy(); slide[0] = .1
    assert allowed(slide, (0, 2))
    over = zero.copy(); over[6] = S.LIMITS[0]-.02+2e-9
    assert not allowed(over)
    checked['additional_global_sticking_sliding_height_floor_headroom_and_ratchet_controls'] = 7
    return checked


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    assert entry['semantic_step'] == 513 and entry['partial_step'] == 1
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet, descriptor, entry['joint_positions_rad']); caps = [v/G.DT for v in entry['caps']]
    modes = declaration['model']['selected_contact_modes']; prior = C.read(B.RESULT)
    assert modes == C.read(B.STUDY)['model']['selected_contact_modes']
    proposal = np.array(C.read(Z.RESULT)['fixed_mode_verification']['physical_solution'][:14])
    zero = np.zeros(14); initial = T.snapshot(model)
    contacts = model.contact_points(zero); floor = model.features_y(zero); joints = model.joints.copy()
    heading = model.r['torso'][:, 0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    trajectory = []; accepted = 0; stop = 'finite_model_horizon'
    for index in range(MAX_STEPS):
        before = T.snapshot(model); nodes = B.finite(model, caps, modes, proposal, heading)
        if index == 0:assert nodes == prior['nodes']
        global_checks = [global_guards(model, np.array(n['delta']), contacts, floor, joints, modes) for n in nodes]
        row = dict(model_step=index+1, before=before, nodes=nodes, global_checks=global_checks, admitted=False, refusal=None)
        trajectory.append(row)
        if len(nodes) != len(B.FRACTIONS) or not all(n['admitted'] for n in nodes):
            row['refusal'] = nodes[-1]['refusal']
        elif not all(c['ok'] for c in global_checks):row['refusal'] = 'global_contact_floor_or_headroom_guard'
        elif nodes[-1]['foot_hull_gap_m'] >= before['foot_hull_gap_m']-1e-9:row['refusal'] = 'no_finite_support_transfer_progress'
        if row['refusal'] is not None:stop = row['refusal']; break
        row['admitted'] = True; accepted += 1
        proposal = np.array(nodes[-1]['delta']); model = T.advance(model, proposal); row['after'] = T.snapshot(model)
        assert abs(row['after']['foot_hull_gap_m']-nodes[-1]['foot_hull_gap_m']) < 1e-12
        if row['after']['foot_hull_gap_m'] <= 1e-6 and nodes[-1]['load']['minimum_nonfoot_weight_fraction'] <= 1e-6:
            stop = 'selected_mode_foot_support_model_target'; break
        if (index+1) % 20 == 0:print(f'R10BB model steps admitted: {accepted}', file=sys.stderr, flush=True)
    final = T.snapshot(model); final_load = Z.load(model, zero, modes, caps)
    summary = dict(stop_reason=stop, accepted_model_steps=accepted, attempted_model_steps=len(trajectory),
        initial_gap_m=initial['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        gap_reduction_m=initial['foot_hull_gap_m']-final['foot_hull_gap_m'],
        torso_translation_m=(np.array(final['torso_position_m'])-initial['torso_position_m']).tolist(),
        torso_forward_translation_m=float((np.array(final['torso_position_m'])-initial['torso_position_m'])@heading),
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        model_target_reached=stop == 'selected_mode_foot_support_model_target')
    return dict(schema_version='sporespore_r10bb_nonlinear_contact_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        selected_contact_modes=modes, initial=initial, final=final, final_load=final_load,
        summary=summary, trajectory=trajectory, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); args = parser.parse_args()
    if args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
