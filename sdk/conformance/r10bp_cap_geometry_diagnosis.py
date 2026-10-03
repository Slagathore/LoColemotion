"""Controlled cap-site/floor-witness geometry diagnosis at the retained probe.

Aligned variants are explicitly counterfactual model geometry. They do not
correct native evidence, prove the actual collision shape, or admit a path.
"""
import argparse
import json
import subprocess
import numpy as np

import r10bo_velocity_field_diagnosis as O

L, C, S, G, Z, I, T, N = O.L, O.C, O.S, O.G, O.Z, O.I, O.T, O.N
STUDY = C.ROOT/'sdk/recovery/r10bp_cap_geometry_diagnosis_study_v1.json'
RESULT = C.ROOT/'sdk/recovery/r10bp_cap_geometry_diagnosis_result_v1.json'
CASES = ('original', 'front_right_cap_aligned', 'all_distal_caps_aligned')


class AlignedModel(I.CapModel):
    def __init__(self, model, variant):
        super().__init__(model.packet, model.d, model.joints)
        selected = [] if variant == 'original' else (['front_right'] if variant == 'front_right_cap_aligned' else list(G.FEET))
        assert variant in CASES
        for index, (body, point, radius) in enumerate(self.features):
            if any(body == foot+'_distal' for foot in selected):
                foot = body[:-len('_distal')]
                self.features[index] = (body, self.local_caps[foot].copy()*(1. if point[1] < 0. else -1.), radius)


def geometry(model):
    zero = np.zeros(14); poses = model.poses(zero); floor_j = L.floor_jacobian(model); material = I.material_jacobian(model)
    rows = []
    for foot in G.FEET:
        body = foot+'_distal'; index = next(i for i,(name,p,_) in enumerate(model.features) if name == body and p[1] < 0.)
        contact = next(i for i,p in enumerate(model.contacts) if p['body_id'] == body and p['classified_as_foot'])
        point = model.features[index][1]; cap = model.local_caps[foot]
        rows.append(dict(foot=foot, floor_feature=index, contact=contact, floor_endpoint_local_m=point.tolist(),
            configured_cap_local_m=cap.tolist(), endpoint_offset_local_m=(point-cap).tolist(),
            floor_vs_material_normal_jacobian_difference=(floor_j[index]-material[contact,1]).tolist(),
            maximum_normal_jacobian_difference=float(np.max(np.abs(floor_j[index]-material[contact,1]))),
            floor_vs_cap_site_height_difference_m=float(model.features_y(zero)[index]-model.contact_points(zero)[contact,1])))
    return rows


def controls():
    checked = O.controls()
    # This binary32 endpoint differs from its binary64 construction, but using
    # one endpoint for two names must restore exact geometric identity.
    nominal = np.array([0., -.09123456789, 0.]); rounded = nominal.astype(np.float32).astype(float)
    assert not np.array_equal(nominal, rounded)
    assert np.array_equal(rounded.copy(), rounded)
    assert np.array_equal(-(-rounded), rounded)
    assert CASES == ('original', 'front_right_cap_aligned', 'all_distal_caps_aligned')
    checked['additional_mixed_precision_endpoint_identity_mirroring_and_variant_controls'] = 4
    return checked


def declare():
    old = C.read(O.STUDY)
    record = dict(schema_version='sporespore_r10bp_cap_geometry_diagnosis_study_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='engine_neutral_model_from_godot_measurements',
            authority_mode='prospective_cap_site_floor_geometry_diagnosis', question_class='development'),
        source_parent_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=C.ROOT).decode().strip(),
        question='Do slightly different representations of the same distal cap endpoint explain sensitivity of the retained R10BN probe velocity?',
        dependencies=old['dependencies']+[C.bind(p) for p in [O.__file__, O.STUDY, O.RESULT, __file__,
            C.ROOT/'sdk/core/src/quadruped.rs', C.ROOT/'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd']],
        population=old['population'], variants=list(CASES),
        design=dict(reconstruction='Exact O.reconstruct retained64-delta reconstruction. Same center and57 declared probes as R10BO for each variant.',
            original='Original measured/counterfactual pose, floor witnesses and cap sites unchanged. All57 results must reproduce R10BO solutions and certificates exactly.',
            aligned='Only replace both distal capsule-axis endpoint witnesses for the named foot or all four feet with +/- configured lower-cap local center, already rounded to native vector precision in S.Model. Keep radii, poses, contact sites, constraints, limits, solver and objectives unchanged.',
            source='Compiler quadruped.rs declares both contact-site center and distal capsule-axis endpoint at -lower_length/2. The adapter constructs a capsule from segment_length and radius, and casts configured contact centers to Vector3. Alignment is a coherent surrogate choice; this study does not inspect or certify actual native collision-resource rounding.',
            outputs='Retain original and aligned endpoint offsets, height differences, normal-Jacobian differences, every solution/certificate/refusal, and the same local sensitivity summaries. Perturbed probes are never admitted poses.',
            boundary='No geometry variant is selected for production, no numerical/path budget changes, no integration or new world. Full cold replay; original R10BN and R10BO remain immutable.'),
        numerics=old['numerics'], checks=['148 inherited plus4 mixed-precision endpoint identity, mirroring and variant-population controls; inherited coverage shared.',
            'Unchanged original reproduces all57 saved probes. Aligned endpoints and contact sites remain identical before solving.'],
        research_sources=old['research_sources'], claim_boundary=old['claim_boundary'])
    C.write_new(STUDY, record)


def derive():
    declaration = C.read(STUDY)
    for binding in [*declaration['dependencies'], declaration['population']['report']]:assert C.bind(binding['path']) == binding
    assert np.__version__ == declaration['numerics']['numpy'] and S.statics.scipy.__version__ == declaration['numerics']['scipy']
    checked = controls(); base, previous, replay = O.reconstruct(); original = C.read(O.RESULT)
    center_delta = np.array(previous['trajectory'][-1]['last_integration_probe']['delta']); modes = previous['summary']['selected_modes']
    cases = []
    for variant in CASES:
        rows = []; center = None
        for specification in O.probes():
            delta = center_delta.copy()
            if specification['coordinate'] is not None:
                i = specification['coordinate']; delta[i] += specification['sign']*specification['scale']*S.MAXIMUM[i]
            prior_model = I.advance(base, delta); model = AlignedModel(prior_model, variant)
            assert np.array_equal(model.contact_points(np.zeros(14)), prior_model.contact_points(np.zeros(14)))
            row = dict(specification=specification, delta=delta.tolist(), result=None, refusal=None); rows.append(row)
            try:computed = O.problem(model, modes)
            except L.VelocityRefusal as failure:row['refusal'] = failure.record; continue
            row['result'] = {k:v for k,v in computed.items() if k not in ['equality', 'equality_rhs', 'inequality', 'inequality_rhs', 'bounds', 'cost']}
            if specification['coordinate'] is None:center = computed
        if variant == 'original':assert rows == original['probes']
        sensitivity = []
        if center is not None:
            reference = np.array(center['normalized_velocity'])
            for scale in O.SCALES:
                changes = [dict(specification=row['specification'], maximum_normalized_velocity_change=float(np.max(np.abs(np.array(row['result']['normalized_velocity'])-reference))),
                    primary_objective_change_m=row['result']['primary_certificate']['primal_objective']-center['primary_certificate']['primal_objective'])
                    for row in rows if row['specification']['scale'] == scale and row['result'] is not None]
                sensitivity.append(dict(scale=scale, successful_probes=len(changes), largest_change=max(changes,key=lambda row:row['maximum_normalized_velocity_change']) if changes else None))
        cases.append(dict(variant=variant, center_geometry=geometry(AlignedModel(I.advance(base, center_delta),variant)),
            center_problem=center, probes=rows, summary=dict(successful_probes=sum(row['result'] is not None for row in rows), sensitivity=sensitivity)))
    return dict(schema_version='sporespore_r10bp_cap_geometry_diagnosis_result_v1', ledger_scope=declaration['ledger_scope'],
        declaration=C.bind(STUDY), implementation=C.bind(__file__), controls=checked, entry_contact_replay=replay,
        cases=cases, summary=dict(variants=len(cases), velocity_probes=sum(len(case['probes']) for case in cases),
            cases=[dict(variant=case['variant'], **case['summary']) for case in cases], new_model_increments=0),
        **declaration['claim_boundary'])


def audit():
    result = C.read(RESULT); assert result == derive()
    return dict(ok=True, full_replay_passed=True, controls=result['controls'], summary=result['summary'],
        world_build_count=0, solver_step_count=0, physical_acceptance_authority=False, release_authority=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for option in ('create', 'controls', 'declare'):parser.add_argument('--'+option, action='store_true')
    args = parser.parse_args()
    if args.declare:declare(); print('R10BP prospective declaration created')
    elif args.controls:print(json.dumps(controls(), indent=2))
    elif args.create:
        assert not RESULT.exists(); result=derive(); C.write_new(RESULT,result)
        print(json.dumps(dict(ok=True,full_replay_passed=False,controls=result['controls'],summary=result['summary']),indent=2))
    else:print(json.dumps(audit(),indent=2))
