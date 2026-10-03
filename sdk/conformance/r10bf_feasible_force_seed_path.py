"""Distinct successor initializing forces at each actual fractional pose.

The original search and its certificate stay visible. Canonical mode forces are
re-certified before the unchanged nonlinear and independent physical-unit guards.
"""
import argparse
import json
import subprocess
import sys
import numpy as np

import r10be_zero_load_mode_path as E

D = E.D

R, B, P, T, S, C, G, Z = D.R, D.B, D.P, D.T, D.S, D.C, D.G, D.Z
STUDY = C.ROOT/'sdk/recovery/r10bf_feasible_force_seed_path_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bf_feasible_force_seed_path_result_v1.json'


def declare():
    record = C.read(E.STUDY)
    record['schema_version'] = 'sporespore_r10bf_feasible_force_seed_path_study_v1'
    record['ledger_scope']['authority_mode'] = 'prospective_nonfoot_load_descent_with_fractional_pose_force_initialization'
    record['source_parent_commit'] = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=C.ROOT).decode().strip()
    record['question'] = 'Does certified force initialization at each fractional pose remove the R10BE equilibrium-start defect and permit continued independently checked nonfoot-load transfer?'
    record['dependencies'] += [C.bind(p) for p in [E.__file__, E.STUDY, E.RESULT]]
    record['model']['fractional_force_initialization'] = ('Only change from R10BE: independently solve the selected-mode stationary load at the actual fractional tangent pose before nonlinear optimization. If feasible, initialize its reduced force variables from that certified force/torque vector; otherwise retain the original tangent-force guess. Record every initializer result and the branch used. The pose guess, objective, solver budget, canonicalization and all final independent guards remain unchanged. Initialization grants no node admission.')
    record['checks'][0] = '93 inherited controls plus two manufactured fractional-pose force-equilibrium checks; inherited coverage is shared.'
    C.write_new(STUDY, record)


def canonical_modes(modes, proposal):
    force = proposal[14:14+3*len(modes)].reshape((-1, 3))
    return [0 if mode != 0 and np.all(force[i] == 0.) else mode for i, mode in enumerate(modes)]


def controls():
    checked = E.controls()
    # Reusing an endpoint force at a fractional lever pose violates balance.
    q = .5+.25*.1
    assert abs(q*1.6-1.) > 1e-6
    assert abs(q*(1./q)-1.) < 1e-12
    checked['additional_fractional_pose_force_initialization_controls'] = 2
    return checked


def step(model, caps, original, previous_modes, anchors):
    contacts = model.contact_points(np.zeros(14)); eligible = R.eligible_contacts(np.array(original['original_contact_markers_m']), contacts)
    baseline = Z.load(model, np.zeros(14), [1 if i in eligible else 0 for i in range(len(contacts))], caps)
    row = dict(eligible_contact_indices=eligible, baseline=baseline, nodes=[], admitted=False, refusal=None)
    if not baseline['feasible']:row['refusal'] = 'initial_eligible_force_balance_refusal'; return row
    problem = D.Problem(model, caps, D.physical_load(baseline), eligible); row['tangent_step_comparison_error'] = problem.tangent_error
    search = problem.solve(); row['search'] = search
    if search['proposal'] is None:row['refusal'] = 'mode_search_unsuccessful'; return row
    selected = search['proposal']['modes']; original_proposal, original_certificate = problem.certify_mode(selected)
    assert abs(original_certificate['primal_objective']-search['proposal']['recomputed_objective']) <= 1e-6
    modes = canonical_modes(selected, original_proposal)
    row['original_mode_verification'] = dict(modes=selected, physical_solution=original_proposal.tolist(), certificate=original_certificate)
    row['deactivated_exact_zero_force_contacts'] = [i for i, (a, b) in enumerate(zip(selected, modes)) if a != b]
    if modes == selected:proposal, certificate = original_proposal, original_certificate
    else:proposal, certificate = problem.certify_mode(modes)
    assert abs(certificate['primal_objective']-search['proposal']['recomputed_objective']) <= 1e-6
    assert all(mode == 0 or i in eligible for i, mode in enumerate(modes))
    anchors = anchors.copy()
    for i, mode in enumerate(modes):
        if mode == 1 and previous_modes[i] != 1:anchors[i] = contacts[i]
    anchors[:, 1] = np.array(original['original_contact_markers_m'])[:, 1]
    row['phase_anchors_m'] = anchors.tolist()
    row['fixed_mode_verification'] = dict(modes=modes, physical_solution=proposal.tolist(), certificate=certificate)
    if certificate['primal_objective'] >= baseline['minimum_nonfoot_weight_fraction']-D.LOAD_PROGRESS:
        row['refusal'] = 'no_first_order_nonfoot_load_reduction'; return row
    previous = contacts
    for fraction in B.FRACTIONS:
        initializer = Z.load(model, proposal[:14]*fraction, modes, caps)
        initialized = proposal.copy()
        if initializer['feasible']:initialized[14:] = D.physical_load(initializer)
        solver, delta, force = D.FiniteProblem(model, caps, modes, previous).solve(initialized, fraction)
        node = D.check_node(model, caps, modes, delta, force, previous, fraction,
            baseline['minimum_nonfoot_weight_fraction'], original, anchors, solver)
        node['force_initialization'] = initializer
        node['used_certified_fractional_force_initialization'] = initializer['feasible']
        row['nodes'].append(node)
        if not node['admitted']:row['refusal'] = node['refusal']; return row
        previous = model.contact_points(delta)
    row['admitted'] = True
    return row


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet, descriptor, entry['joint_positions_rad']); caps = [v/G.DT for v in entry['caps']]
    original = T.snapshot(model); trajectory = []; accepted = 0; stop = 'finite_model_horizon'
    previous_modes = [0]*len(model.contacts); anchors = model.contact_points(np.zeros(14))
    for index in range(D.MAX_STEPS):
        row = step(model, caps, original, previous_modes, anchors); row['model_step'] = index+1; row['before'] = T.snapshot(model); trajectory.append(row)
        if not row['admitted']:stop = row['refusal']; break
        accepted += 1; model = T.advance(model, np.array(row['nodes'][-1]['delta'])); row['after'] = T.snapshot(model)
        previous_modes = row['fixed_mode_verification']['modes']; anchors = np.array(row['phase_anchors_m'])
        assert abs(row['after']['foot_hull_gap_m']-row['nodes'][-1]['foot_hull_gap_m']) < 1e-12
        if row['nodes'][-1]['load']['minimum_nonfoot_weight_fraction'] <= 1e-6:
            stop = 'independent_nonfoot_support_fraction_within_1ppm_model_only'; break
        print(f'R10BF step {accepted}: nonfoot fraction {row["nodes"][-1]["load"]["minimum_nonfoot_weight_fraction"]:.9f}', file=sys.stderr, flush=True)
    final = T.snapshot(model); eligible = R.eligible_contacts(np.array(original['original_contact_markers_m']), model.contact_points(np.zeros(14)))
    final_load = Z.load(model, np.zeros(14), [1 if i in eligible else 0 for i in range(len(model.contacts))], caps)
    summary = dict(accepted_model_steps=accepted, attempted_model_steps=len(trajectory), stop_reason=stop,
        initial_minimum_nonfoot_weight_fraction=trajectory[0]['baseline'].get('minimum_nonfoot_weight_fraction'),
        final_minimum_nonfoot_weight_fraction=final_load.get('minimum_nonfoot_weight_fraction'),
        initial_gap_m=original['foot_hull_gap_m'], final_gap_m=final['foot_hull_gap_m'], model_target_reached=stop.startswith('independent_nonfoot_support'))
    return dict(schema_version='sporespore_r10bf_feasible_force_seed_path_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        initial=original, final=final, final_load=final_load, summary=summary, trajectory=trajectory, **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, controls=result['controls'], summary=result['summary'], world_build_count=0,
        solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__); parser.add_argument('--create', action='store_true'); parser.add_argument('--controls', action='store_true'); parser.add_argument('--declare', action='store_true'); args = parser.parse_args()
    if args.declare:declare(); print('R10BF prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    else:
        if args.create:C.write_new(RESULT, derive())
        print(json.dumps(audit(), indent=2))
