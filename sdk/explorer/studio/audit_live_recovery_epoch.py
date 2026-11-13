"""Independent reader for fresh live observation boundaries, not recovery success."""
import argparse
import copy
import json
import math
from pathlib import Path
import struct
import sys

SDK = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(SDK / 'python'))
from sporespore_locomotion import LocomotionCore
from audit_live_godot import audit as audit_walking, require
from showcase_model import sha

BODY_IDS = {'torso', *(f'{side}_{part}' for side in
    ('front_left', 'front_right', 'rear_left', 'rear_right') for part in ('upper', 'distal'))}
FLOAT32_EPSILON = 2 ** -23
STAGING_ROUNDING_MULTIPLIER = 64


def digest(core, value):
    return core.canonicalize_json({k: v for k, v in value.items() if k != 'payload_sha256'})['sha256']


def bound(core, value):
    require(type(value) is dict and value.get('payload_sha256') == digest(core, value), 'Changed epoch payload')


def vec(value):
    numbers = [value[k] for k in ('x', 'y', 'z')] if type(value) is dict else value
    require(type(numbers) is list and len(numbers) == 3 and all(type(x) in (int, float) and math.isfinite(x) for x in numbers), 'Finite numeric vector required')
    return numbers


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def dot(left, right):
    terms = [f32(a * b) for a, b in zip(left, right, strict=True)]
    return f32(f32(terms[0] + terms[1]) + terms[2])


def staging_reference(pairs, displacement):
    """Reconstruct source terms with explicit binary32 vector operations.

    The declared roundoff allowance covers operation ordering in the native
    vector implementation; it is not a physical acceptance threshold.
    """
    kinetic = 0.0
    absolute_terms = 0.0
    total = [0.0] * 3
    gravity = vec(pairs[0]['total_gravity_world_m_s2'])
    for pair in pairs:
        pre, post = vec(pair['pre_position_world_m']), vec(pair['post_position_world_m'])
        velocity = vec(pair['pre_linear_velocity_world_m_s'])
        dt, mass = pair['solver_step_s'], pair['mass_kg']
        force_velocity = [f32(v + f32(g * f32(dt))) for v, g in zip(velocity, gravity, strict=True)]
        term = 0.5 * mass * (dot(force_velocity, force_velocity) - dot(velocity, velocity))
        kinetic += term
        absolute_terms += abs(term)
        total = [f32(t + f32(f32(mass) * f32(b - a))) for t, a, b in zip(total, pre, post, strict=True)]
    displacement = vec(displacement)
    whole = -dot(gravity, total)
    constraint = -dot(gravity, displacement)
    integration = -dot(gravity, [f32(a - b) for a, b in zip(total, displacement, strict=True)])
    values = dict(force_integration_kinetic_exchange_j=kinetic, whole_step_gravity_potential_exchange_j=whole,
        position_constraint_potential_exchange_j=constraint, position_integration_potential_exchange_j=integration,
        signed_discrete_staging_exchange_j=kinetic + integration)
    allowance = STAGING_ROUNDING_MULTIPLIER * FLOAT32_EPSILON * max(1.0, absolute_terms + abs(whole) + abs(constraint) + abs(integration))
    return values, allowance


def audit_rows(core, rows, start=300, expected_count=3):
    require(type(expected_count) is int and expected_count >= 2 and type(rows) is list and len(rows) == expected_count,
        'Epoch needs its declared origin and contiguous successors')
    origin = rows[0]['capture']
    previous = None
    accumulated = 0.0
    maximum_staging_difference = 0.0
    for index, row in enumerate(rows):
        frame, transition = row['capture'], row['transition']
        bound(core, frame)
        require(frame['schema_version'] == 'sporespore_live_recovery_completed_boundary_v1' and frame['ok'] is True, 'Frame schema')
        boundary, sources = frame['completed_boundary'], frame['ordered_body_sources']
        bound(core, boundary)
        require(boundary['boundary_sequence'] == start + index and boundary['source_measurement'] is True, 'Completed callback clock')
        require(len(sources) == len(boundary['ordered_bodies']) == 9 and set(boundary['ordered_body_ids']) == BODY_IDS, 'Native body population')
        require(len({s['instance_id'] for s in sources}) == 9, 'Distinct native body instances')
        for body, source, body_id in zip(boundary['ordered_bodies'], sources, boundary['ordered_body_ids'], strict=True):
            require(body['body_id'] == source['body_id'] == body_id and source['callback_sequence'] == start + index, 'Body order or callback')
            require(type(source['instance_id']) is int and source['instance_id'] > 0 and source['mass_kg'] == body['mass_kg'] > 0, 'Body identity or mass')
            require(source['solver_step_s'] == body['solver_step_s'] > 0, 'Body solver step')
            for key in ('position_world_m', 'linear_velocity_world_m_s', 'total_gravity_world_m_s2'):
                require(vec(source[key]) == vec(body[key]), 'Source and boundary projection')
            vec(source['angular_velocity_world_rad_s'])
            for key in ('orientation_basis', 'inverse_inertia_tensor_world_kg_inv_m2'):
                require(len(source[key]) == 3, 'Basis population')
                for axis in source[key]: vec(axis)
        solver = frame['solver_energy_source']
        sequence = origin['native_space_step_sequence'] + index
        require(frame['native_space_step_sequence'] == solver['capture_space_step_sequence'] == solver['read_space_step_sequence'] == sequence, 'Native solver clock')
        require(solver['ok'] is True and math.isfinite(frame['mechanical_energy_j']), 'Native measurement finite and valid')
        for key in ('physics_state_modified', 'complete_recovery_energy_partition', 'physical_acceptance_authority', 'release_authority'):
            require(frame[key] is False, 'Frame overclaim')
        state = transition['state'] if index == 0 else transition['state_after']
        bound(core, state)
        require(state['schema_version'] == 'sporespore_live_recovery_observation_epoch_v1' and transition['ok'] is True, 'Epoch state')
        require(state['origin'] == origin and state['latest'] == frame and state['observed_pair_count'] == index, 'Epoch state join')
        require(type(state['epoch_id']) is str and bool(state['epoch_id']), 'Epoch identity')
        for key in ('world_build_count', 'solver_step_count'):
            require(transition[key] == 0, 'Observation created physics')
        for key in ('physics_state_modified', 'recovery_command_emitted'):
            require(transition[key] is False, 'Observation changed physics')
        for key in ('global_sequence_rewritten', 'unobserved_pre_epoch_history_claimed', 'complete_recovery_energy_partition', 'physical_acceptance_authority', 'release_authority'):
            require(state[key] is False, 'Epoch overclaim')
        if previous is not None:
            bound(core, transition)
            require(transition['state_before_sha256'] == previous['payload_sha256'], 'Previous observer state')
            require(state['epoch_id'] == previous['epoch_id'] and state['trigger_source_sha256'] == previous['trigger_source_sha256'], 'Crossed epoch identity')
            require(transition['completed_global_step'] == start + index and transition['epoch_local_step'] == index, 'Global/local clock join')
            for key in ('attempt_id', 'arm_id', 'model_instance_id'):
                require(boundary[key] == previous['latest']['completed_boundary'][key], 'Crossed model identity')
            pairs = transition['boundary_pairs']
            require(len(pairs) == 9, 'Boundary pair population')
            for body_index, (pair, old, new) in enumerate(zip(pairs, previous['latest']['ordered_body_sources'], sources, strict=True)):
                for key in ('body_id', 'instance_id', 'mass_kg', 'total_gravity_world_m_s2', 'solver_step_s'):
                    require(old[key] == new[key], 'Native body or physical profile changed')
                require(pair['pre_boundary_sequence'] == start + index - 1 and pair['post_boundary_sequence'] == start + index, 'Pair clocks')
                require(pair['body_id'] == old['body_id'] and pair['body_index'] == body_index, 'Pair body identity')
                require(pair['pre_source_event_id'] == previous['latest']['completed_boundary']['source_event_id'] and pair['post_source_event_id'] == boundary['source_event_id'], 'Pair event identity')
                require(pair['pre_source_measurement'] is True and pair['post_source_measurement'] is True, 'Pair source provenance')
                require(vec(pair['total_gravity_world_m_s2']) == vec(old['total_gravity_world_m_s2']), 'Pair gravity changed')
                for phase, source in [('pre', old), ('post', new)]:
                    for field in ('position_world_m', 'linear_velocity_world_m_s'):
                        require(vec(pair[phase + '_' + field]) == vec(source[field]), 'Pair source values changed')
                require(pair['mass_kg'] == old['mass_kg'] and pair['solver_step_s'] == old['solver_step_s'], 'Pair physical inputs changed')
            observer = transition['staging_observer_receipt']
            expected, allowance = staging_reference(pairs, solver['position_constraint_mass_weighted_displacement_kg_m'])
            require(observer['ok'] is True and observer['sequence'] == start + index and observer['previous_sequence'] == start + index - 1, 'Staging observer clocks')
            for key, value in expected.items():
                difference = abs(observer[key] - value)
                require(math.isfinite(difference) and difference <= allowance, 'Staging source reconstruction')
                maximum_staging_difference = max(maximum_staging_difference, difference)
            accumulated += observer['signed_discrete_staging_exchange_j']
        require(state['cumulative_signed_discrete_staging_exchange_j'] == accumulated, 'Observer accumulator')
        previous = state
    return dict(ok=True, native_boundaries=len(rows), contiguous_pairs=len(rows)-1, body_boundary_observations=9*len(rows),
        maximum_staging_reconstruction_difference_j=maximum_staging_difference,
        staging_roundoff_multiplier=STAGING_ROUNDING_MULTIPLIER, reader_world_build_count=0,
        complete_recovery_energy_partition=False, recovery_success_established=False,
        physical_acceptance_authority=False, release_authority=False)


def controls(core, rows):
    audit_rows(core, rows)
    refused = 0
    mutations = [lambda x: x.pop(), lambda x: x.reverse(),
        lambda x: x[1]['capture'].__setitem__('native_space_step_sequence', 5),
        lambda x: x[1]['capture'].__setitem__('complete_recovery_energy_partition', True),
        lambda x: x[1]['transition']['state_after'].__setitem__('observed_pair_count', 4),
        lambda x: x[1]['transition']['state_after'].__setitem__('global_sequence_rewritten', True),
        lambda x: x[1]['transition']['boundary_pairs'][0].__setitem__('mass_kg', 3.0),
        lambda x: x[1]['transition']['boundary_pairs'][0].__setitem__('post_position_world_m', [0.0, 0.0, 0.0]),
        lambda x: x[1]['transition']['staging_observer_receipt'].__setitem__('signed_discrete_staging_exchange_j', 100.0)]
    def reseal(value):
        if isinstance(value, dict):
            for child in value.values(): reseal(child)
            if 'payload_sha256' in value: value['payload_sha256'] = digest(core, value)
        elif isinstance(value, list):
            for child in value: reseal(child)
    for mutate in mutations:
        changed = copy.deepcopy(rows)
        mutate(changed)
        reseal(changed)
        try: audit_rows(core, changed)
        except (ValueError, KeyError, TypeError): refused += 1
        else: raise ValueError('Epoch reader accepted a corruption control')
    return dict(ok=True, controls=1 + refused, negative_controls=refused, world_build_count=0, solver_step_count=0)


def audit(folder, core_path):
    walking = audit_walking(folder)
    receipt = json.loads((folder / 'receipt.json').read_text())
    summary = receipt['physical']['completed']['summary']['live_recovery_epoch']
    retention = summary['retained']; path = Path(retention['path']).resolve()
    require(path.is_relative_to((folder / 'physical').resolve()) and sha(path) == retention['sha256'], 'Epoch retention binding')
    core = LocomotionCore(core_path)
    result = audit_rows(core, json.loads(path.read_text()))
    require(summary['observed_pair_count'] == 2 and summary['zero_world']['ok'] is True, 'Native gate and pair count')
    return dict(result, walking=walking, core_sha256=sha(core_path))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder', type=Path); parser.add_argument('--core', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(audit(args.folder, args.core), indent=2))
