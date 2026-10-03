"""One prospective contact-mode replan at R10BB's retained terminal model pose.

Only source markers still at their original contact height may support load.
Original lifted markers cannot become supports by being listed in a packet.
"""
import argparse
import json
import numpy as np

import r10bb_nonlinear_contact_path as P

B, T, S, C, G, Z = P.B, P.T, P.S, P.C, P.G, P.Z
STUDY = C.ROOT/'sdk/recovery/r10bc_terminal_contact_replan_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bc_terminal_contact_replan_result_v1.json'


def eligible_contacts(original, current):
    return [i for i in range(len(current)) if abs(current[i, 1]-original[i, 1]) <= 1e-9]


def restrict(problem, eligible):
    for i in range(problem.n):
        if i not in eligible:
            problem.lower[problem.base+6*i] = 1.
            problem.upper[problem.base+6*i+1:problem.base+6*i+6] = 0.


def controls():
    result = P.controls()
    original = np.zeros((3, 3)); current = original.copy(); current[1, 1] = 2e-9; current[2, 1] = -2e-9
    assert eligible_contacts(original, current) == [0]
    current[:, 1] = [.5e-9, 0., -.5e-9]
    assert eligible_contacts(original, current) == [0, 1, 2]
    class Manufactured:
        n = 3; base = 2
        lower = np.zeros(20); upper = np.ones(20)
    problem = Manufactured(); restrict(problem, [0, 2])
    assert problem.lower[8] == 1. and np.all(problem.upper[9:14] == 0.)
    assert np.all(problem.lower[2:8] == 0.) and np.all(problem.upper[2:8] == 1.)
    assert np.all(problem.lower[14:20] == 0.) and np.all(problem.upper[14:20] == 1.)
    result['additional_contact_height_eligibility_and_binary_bound_controls'] = 5
    return result


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); descriptor, samples = S.statics.tracking.rows(); entry = samples[0]
    packet = next(r['packet'] for r in G.records(C.CHILD/'worker_report.json', 'r10af_contact_frames', 'records') if r['packet']['semantic_step'] == 513)
    replay = S.statics.replay.replay(packet, 513, packet['model_instance_id'], packet['body_population_instance_sha256']); assert replay['ok']
    model = S.Model(packet, descriptor, entry['joint_positions_rad']); original = T.snapshot(model)
    caps = [v/G.DT for v in entry['caps']]; path = C.read(P.RESULT)
    for row in path['trajectory']:
        if row['admitted']:
            assert T.snapshot(model) == row['before']
            model = T.advance(model, np.array(row['nodes'][-1]['delta']))
            assert T.snapshot(model) == row['after']
    assert T.snapshot(model) == path['final']
    heading = np.array(original['torso_basis_columns'])[0].copy(); heading[1] = 0.; heading /= np.linalg.norm(heading)
    contacts = model.contact_points(np.zeros(14)); original_contacts = np.array(original['original_contact_markers_m'])
    eligible = eligible_contacts(original_contacts, contacts)
    problem = Z.Problem(model, caps, heading); restrict(problem, eligible)
    # Certify the old mode's tangent objective before considering a new mode.
    old_solution, old_certificate = problem.certify_mode(path['selected_contact_modes'])
    old = dict(modes=path['selected_contact_modes'], physical_solution=old_solution.tolist(), certificate=old_certificate,
        forward_linear_progress_m=float(old_solution[:3]@heading))
    search = problem.solve(); verification = None; nodes = []; global_checks = []
    if search['proposal'] is not None:
        modes = search['proposal']['modes']
        assert all(mode == 0 or i in eligible for i, mode in enumerate(modes))
        solution, certificate = problem.certify_mode(modes)
        assert abs(certificate['maximum_progress']['primal_objective']-search['proposal']['recomputed_objective']) <= 1e-6
        verification = dict(modes=modes, physical_solution=solution.tolist(), certificate=certificate,
            forward_linear_progress_m=float(solution[:3]@heading))
        if verification['forward_linear_progress_m'] > 1e-9:
            nodes = B.finite(model, caps, modes, solution[:14], heading)
            for node in nodes:
                delta = np.array(node['delta']); points = model.contact_points(delta)
                # A newly sticking point anchors at the declared transition,
                # while original normal/floor/headroom references stay global.
                checks = P.global_guards(model, delta, contacts, np.array(original['shape_bottom_witnesses_m']),
                    np.array(original['joints_rad']), modes)
                checks['residuals']['source_marker_descent'] = float(np.max(original_contacts[:, 1]-points[:, 1]))
                checks['ok'] = B.geometry_allowed(checks['residuals']); global_checks.append(checks)
    passed = len(nodes) == len(B.FRACTIONS) and all(n['admitted'] for n in nodes) and all(c['ok'] for c in global_checks)
    summary = dict(eligible_contact_indices=eligible, old_mode_linear_progress_m=old['forward_linear_progress_m'],
        search_status=search['status'], selected_modes=None if verification is None else verification['modes'],
        selected_linear_progress_m=None if verification is None else verification['forward_linear_progress_m'],
        finite_step_admitted=passed, checked_nodes=len(nodes),
        node_refusal=None if not nodes else nodes[-1]['refusal'],
        initial_gap_m=model.gap(np.zeros(14)), final_gap_m=nodes[-1]['foot_hull_gap_m'] if passed else None,
        torso_forward_translation_m=nodes[-1]['forward_progress_m'] if passed else None)
    return dict(schema_version='sporespore_r10bc_terminal_contact_replan_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        terminal_snapshot=T.snapshot(model), contact_height_change_m=(contacts[:, 1]-original_contacts[:, 1]).tolist(),
        previous_mode=old, search=search, fixed_mode_verification=verification, nodes=nodes,
        global_checks=global_checks, summary=summary, **declaration['claim_boundary'])


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
