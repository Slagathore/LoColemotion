"""Bounded finite raising path for R10BM's original-entry torso-raise mode.

This fresh model diagnostic checks the preparatory lift direction. It is not a
motor controller, native recovery, full support transfer or acceptance attempt.
"""
import argparse
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import numpy as np

import r10bm_entry_raise_directions as M

L, C, S, G, Z, I, T = M.L, M.C, M.S, M.G, M.Z, M.I, M.T
STUDY = C.ROOT/'sdk/recovery/r10bn_bounded_torso_raise_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bn_bounded_torso_raise_path_result_v1.json'
MAX_STEPS = 120
HEADING = np.array([0., 1., 0.])


def declare():
    old = C.read(M.STUDY)
    chosen = next(row for row in C.read(M.RESULT)['cases'] if row['target'] == 'torso_raise')
    assert chosen['refusal'] is None
    record = dict(schema_version='sporespore_r10bn_bounded_torso_raise_path_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_bounded_torso_raise_rolling_path', question_class='development'),
        source_parent_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip(),
        question='Does the verified original-entry torso-raise direction survive a bounded finite rolling path under unchanged geometry, force, headroom and material-work admission?',
        dependencies=old['dependencies']+[C.bind(p) for p in [M.__file__, M.STUDY, M.RESULT, __file__]],
        population=old['population'], selected_modes=chosen['verification']['modes'],
        design=dict(selection='R10BM torso_raise case only, selected before this fresh original-entry path. Fixed declared modes throughout; no retries or mode replanning.',
            objective='Maximize world-Y torso-origin rise, then minimize normalized absolute velocity within1e-10 m of its optimum. Exact L.velocity with heading[0,1,0].',
            entry='Rebuild the original R10AP semantic513 cap model. Reverify selected mode with M.certify_mode and original force/actuator limits.',
            propagation='Reuse L.step, including DOP853 integration, per-probe LP certificates, four sampled geometry/load/material-work checks, global original anchors/floor/headroom guards and nonaccumulating tolerances.',
            horizon='At most120 model increments, at most2048 RHS calls each; first refusal stops. At existing vertical speed limit this can request at most57.735 mm of torso rise. This is a bounded preparatory-lift diagnostic, not full recovery coverage.',
            retention='Exclusive incremental durable journal and exact refused step/LP inputs; separate full cold replay. Imported forward_progress_m is explicitly renamed vertical_progress_m in retained nodes because heading is worldY.',
            outcome='Report height, gap, required nonfoot support and rear-hip heights. Neither positive height nor a zero geometric gap alone establishes load transfer, contact acquisition, dynamic feasibility or physical recovery.'),
        numerics=dict(old['numerics'], integrator=I.INTEGRATOR, maximum_steps=MAX_STEPS, maximum_rhs_calls=I.MAX_RHS),
        checks=old['checks']+['142 inherited controls; exact selected-mode recertification and unchanged per-node guards.'],
        research_sources=old['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def derive(journal=None):
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = M.controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    packet = copy.deepcopy(packet); packet['counterfactual_model_only'] = True
    model = I.CapModel(packet, descriptor, entry['joint_positions_rad']); zero = np.zeros(14); caps = [v/G.DT for v in entry['caps']]
    reference = T.snapshot(model); modes = declaration['selected_modes']; material = T.advance(model, zero)
    jacobian_error = float(np.max(np.abs(I.material_jacobian(model)-S.derivative(material.contact_points, zero))))
    floor_error = float(np.max(np.abs(L.floor_jacobian(model)-S.derivative(model.features_y, zero))))
    assert jacobian_error <= 1e-7 and floor_error <= 1e-7
    problem = Z.Problem(material, caps, HEADING)
    solution, certificate = M.certify_mode(problem, modes)
    verification = dict(modes=modes, physical_solution=solution.tolist(), certificate=certificate,
        initial_load=Z.load(model, zero, modes, caps))
    def hip_heights(current):
        return {name:float(current.point(current.poses(zero), 'torso', M.target_point(current, name))[1]) for name in M.TARGETS[1:]}
    initial_hips = hip_heights(model); digest = hashlib.sha256(); count = 0
    def retain(value):
        nonlocal count
        line = L.journal_line(value); digest.update(line); count += 1
        if journal is not None:journal.write(line); journal.flush()
    retain(dict(kind='inputs', declaration=C.bind(STUDY), implementation=C.bind(__file__), verification=verification))
    trajectory = []; accepted = 0; stop = 'initial_mode_load_refusal'
    if verification['initial_load']['feasible']:
        stop = 'bounded_preparatory_model_horizon'
        for index in range(MAX_STEPS):
            row = L.step(model, modes, caps, HEADING, reference)
            for node in row['nodes']:node['vertical_progress_m'] = node.pop('forward_progress_m')
            row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
            if not row['admitted']:stop = row['refusal']; retain(dict(kind='model_step', value=row)); break
            accepted += 1; model = I.advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
            retain(dict(kind='model_step', value=row))
            print(f'R10BN step {accepted}: height {model.p["torso"][1]:.9f}, gap {model.gap(zero):.9f}', file=sys.stderr, flush=True)
    final = T.snapshot(model)
    final_load = trajectory[accepted-1]['nodes'][-1]['load'] if accepted else verification['initial_load']
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        selected_modes=modes, initial_gap_m=reference['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'],
        torso_vertical_translation_m=final['torso_position_m'][1]-reference['torso_position_m'][1],
        initial_hip_heights_m=initial_hips, final_hip_heights_m=hip_heights(model),
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        total_integrator_rhs_calls=sum(row['rhs_calls'] for row in trajectory), complete_transfer_or_rise_proven=False)
    retain(dict(kind='terminal_summary', value=summary))
    return dict(schema_version='sporespore_r10bn_bounded_torso_raise_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        material_jacobian_comparison_error=jacobian_error, initial_floor_jacobian_comparison_error=floor_error,
        fixed_mode_verification=verification, initial=reference, final=final, summary=summary, trajectory=trajectory,
        journal=dict(line_count=count, raw_sha256='sha256:'+digest.hexdigest()), **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive(); return L.present(result, True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ('create', 'controls', 'declare'):parser.add_argument('--'+option, action='store_true')
    parser.add_argument('--journal'); args = parser.parse_args()
    if args.declare:declare(); print('R10BN prospective declaration created')
    elif args.controls:print(json.dumps(M.controls(), indent=2))
    elif args.create:
        if not args.journal:parser.error('--create requires a fresh durable --journal path')
        path = Path(args.journal).resolve(); assert path.is_relative_to(C.EVIDENCE.resolve()) and not RESULT.exists()
        with path.open('xb') as journal:result = derive(journal)
        C.write_new(RESULT, result); print(json.dumps(L.present(result, False), indent=2))
    else:print(json.dumps(audit(), indent=2))
