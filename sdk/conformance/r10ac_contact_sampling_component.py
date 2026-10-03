"""Audit frozen native contact sampling order without opening a physics world.

The algebraic cases demonstrate a coordinate-frame hazard, not the cause or
counterfactual outcome of any consumed recovery campaign.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import subprocess

from r10ac_support_loss_diagnosis import ROOT, binding, write

CONTRACT = ROOT / 'sdk/recovery/r24d157_godot_jolt_rotation_integration_energy_contract_v1.json'
RECORD = ROOT / 'sdk/recovery/r10ac_contact_sampling_component_v1.json'
PREDECESSOR = ROOT / 'sdk/recovery/r10ac_support_loss_component_v1.json'
NATIVE = ROOT / 'sdk/adapters/godot/gdscript/recovery_native_world_v1.gd'
SAMPLER = ROOT / 'scripts/lab/mechanics/semantic_contact_rigid_body.gd'
LISTENER = 'modules/jolt_physics/spaces/jolt_contact_listener_3d.cpp'
SPACE = 'modules/jolt_physics/spaces/jolt_space_3d.cpp'
BODY = 'modules/jolt_physics/objects/jolt_body_3d.cpp'
STATE = 'modules/jolt_physics/objects/jolt_physics_direct_body_state_3d.cpp'
SYSTEM = 'thirdparty/jolt_physics/Jolt/Physics/PhysicsSystem.cpp'
CONTACTS = 'thirdparty/jolt_physics/Jolt/Physics/Constraints/ContactConstraintManager.cpp'
read = lambda path: json.loads(Path(path).read_text(encoding='utf-8-sig'))


def git(path, *args):
    return subprocess.check_output(['git', '-C', str(path), *args], cwd=ROOT)


def check_frozen_source():
    contract = read(CONTRACT)
    source = contract['exact_external_source']
    checkout = Path(source['checkout_path'])
    assert git(checkout, 'rev-parse', 'HEAD').decode().strip() == source['upstream_commit']
    assert git(checkout, 'remote', 'get-url', 'origin').decode().strip() == source['origin_url']
    diff = git(checkout, 'diff', '--binary', '--full-index', '--no-ext-diff', 'HEAD')
    assert len(diff) == source['diff_byte_length']
    assert 'sha256:' + hashlib.sha256(diff).hexdigest() == source['diff_raw_sha256']
    for item in source['bound_patches'] + source['source_files']:
        base = ROOT if item in source['bound_patches'] else checkout
        observed = binding(base / item['path'])
        assert all(observed[k] == item[k] for k in ('raw_sha256', 'byte_length'))
    runtime = contract['exact_runtime']
    engine = binding(runtime['engine_path'])
    assert engine['raw_sha256'] == runtime['engine_sha256']
    assert engine['byte_length'] == runtime['engine_byte_length']
    return checkout, dict(upstream_commit=source['upstream_commit'],
        diff_raw_sha256=source['diff_raw_sha256'], diff_byte_length=len(diff), engine=engine)


def excerpt(path, first, last):
    lines = path.read_text(encoding='utf-8').splitlines()
    start = next(i for i, line in enumerate(lines) if first in line)
    end = next(i for i in range(start, len(lines)) if last in lines[i])
    return dict(path=path.as_posix(), first_line=start+1, last_line=end+1,
                text='\n'.join(lines[start:end+1]))


def source_trace(checkout):
    # Excerpts make the code-review argument inspectable; exact file/diff hashes
    # pin it. They are not a substitute for dynamic observation of a recovery.
    trace = {
        'discrete_contact_preferred': excerpt(checkout/LISTENER,
            'if (unlikely(!manifold.contacts1.is_empty()))', 'return false;'),
        'world_point_at_detection': excerpt(checkout/LISTENER,
            'const JPH::RVec3 world_point1', 'contact1.point_other'),
        'solved_impulses_only_replaced': excerpt(checkout/LISTENER,
            'const Vector3 combined_impulse = to_godot(', 'manifold.contacts2[i].impulse = combined_impulse;'),
        'unchanged_points_flushed': excerpt(checkout/LISTENER,
            'for (const Contact &contact : manifold.contacts1)', 'contact.point_self, contact.point_other'),
        'body_stores_world_point': excerpt(checkout/BODY,
            'contact->normal = p_normal;', 'contact->collider_position = p_collider_position;'),
        'direct_state_returns_stored_point': excerpt(checkout/STATE,
            'Vector3 JoltPhysicsDirectBodyState3D::get_contact_local_position', 'return body->get_contact(p_contact_idx).position;'),
        'direct_state_returns_current_transform': excerpt(checkout/STATE,
            'Transform3D JoltPhysicsDirectBodyState3D::get_transform()', 'return body->get_transform_scaled();'),
        'update_before_flush': excerpt(checkout/SPACE,
            'const JPH::EPhysicsUpdateError update_error = physics_system->Update', '_post_step(p_step);'),
        'collision_before_integration': excerpt(checkout/SYSTEM,
            '// Finalize islands is a dependency on find collisions', '// This job will update the positions of all active bodies'),
        'position_solve_after_integration': excerpt(checkout/SYSTEM,
            '// This job will update the positions and velocities for all bodies', '// depends on: resolve ccd contacts, body set island index, finish building jobs.'),
        'host_uses_callback_transform': excerpt(NATIVE,
            'var local_point := body_transform.affine_inverse() * point_world', 'classified_as_foot = local_point.y'),
        'scalar_joint_angle_not_full_pose': excerpt(NATIVE,
            'func _signed_relative_angle_z(', 'rotation.get_angle()'),
    }
    return trace


def transform(point, origin, angle):
    c, s = math.cos(angle), math.sin(angle)
    return [origin[0]+c*point[0]-s*point[1], origin[1]+s*point[0]+c*point[1]]


def inverse(point, origin, angle):
    x, y = point[0]-origin[0], point[1]-origin[1]
    c, s = math.cos(angle), math.sin(angle)
    return [c*x+s*y, -s*x+c*y]


def algebraic_cases():
    center, tolerance = -0.1, 1e-6
    rows = []
    for name, local_y, delta_y, angle in (
        ('stationary_control', center, 0.0, 0.0),
        ('translation_false_nonfoot', center, -0.0001, 0.0),
        ('translation_false_foot', center+0.00005, 0.0001, 0.0),
        ('rotation_false_nonfoot', center, 0.0, -0.01),
    ):
        point, before, after = [0.02, local_y], [0.0, 0.25], [0.0, 0.25+delta_y]
        world_at_detection = transform(point, before, 0.0)
        same_frame = inverse(world_at_detection, before, 0.0)
        mixed_frame = inverse(world_at_detection, after, angle)
        moved_point = transform(point, after, angle)
        advected_same_frame = inverse(moved_point, after, angle)
        classify = lambda p: p[1] <= center+tolerance
        assert math.dist(same_frame, point) < 1e-14
        assert math.dist(advected_same_frame, point) < 1e-14
        assert classify(same_frame) == classify(advected_same_frame)
        rows.append(dict(name=name, point_body_local_m=point,
            post_translation_y_m=delta_y, post_rotation_z_rad=angle,
            collision_frame_foot=classify(same_frame),
            later_frame_foot=classify(mixed_frame),
            later_frame_local_y_m=mixed_frame[1]))
    assert [(r['collision_frame_foot'], r['later_frame_foot']) for r in rows] == [
        (True,True), (True,False), (False,True), (True,False)]
    return dict(synthetic_only=True, cap_center_y_m=center,
                unchanged_classification_tolerance_m=tolerance, cases=rows)


def observations():
    checkout, frozen = check_frozen_source()
    paths = [Path(__file__), CONTRACT, PREDECESSOR, NATIVE, SAMPLER,
             ROOT/'sdk/conformance/r10ac_support_loss_diagnosis.py']
    paths += [checkout/p for p in (LISTENER, SPACE, BODY, STATE, SYSTEM, CONTACTS)]
    return dict(ok=True, frozen_source=frozen,
        source_bindings=[binding(p) for p in paths], source_trace=source_trace(checkout),
        algebraic_coordinate_checks=algebraic_cases(),
        discrete_contact_world_position_precedes_final_body_transform=True,
        same_host_callback_does_not_imply_same_native_sampling_phase=True,
        measured_effect_on_consumed_recovery=None,
        consumed_results_regraded=False, controller_changed=False, threshold_changed=False,
        causal_repair_proven=False, physical_population_declared=False,
        world_build_count=0, solver_step_count=0,
        physical_acceptance_authority=False, release_authority=False)


def capture():
    value = dict(schema_version='sporespore_r10ac_contact_sampling_component_v1',
        ledger_scope=dict(subsystem='recovery', engine_scope='godot_jolt',
            authority_mode='frozen_source_and_algebraic_contact_sampling_diagnosis', question_class='development'),
        observed=observations(),
        interpretation='The reader combines a detection-stage world point with a later body transform. Synthetic rigid transforms can change cap membership in either direction without changing the cap definition. This is a demonstrated source-level coordinate hazard, not measured causality for R10AA or R10AB.',
        next_action='Implement and zero-world qualify an opt-in diagnostic capture of detection-stage body-local contact points and exact body transforms, paired with callback transforms and solved impulses. Keep the existing classification and controller unchanged while measuring the discrepancy in a distinct development population.',
        required_capture=['exact frozen engine and adapter identities',
            'contact-detection body transform and body-local point for both bodies',
            'contact world points, subshape pair, within-manifold index and step sequence',
            'discrete or CCD provenance with missing and duplicate coverage refusals',
            'callback body transforms for all nine bodies and their existing source hash',
            'original foot classification plus diagnostic collision-frame classification',
            'complete fresh bounded tail and independent replay; no old-run regrading'],
        non_goals=['no widened cap or tolerance', 'no controller tuning',
            'no consumed campaign rerun', 'no held-out or acceptance authority'])
    write(RECORD, value)
    return value['observed']


def audit():
    value = read(RECORD)
    assert value['observed'] == observations()
    return value['observed']


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture', action='store_true')
    result = capture() if parser.parse_args().capture else audit()
    print('R10AC_CONTACT_SAMPLING_COMPONENT '+json.dumps({k:v for k,v in result.items()
        if k not in ('source_bindings', 'source_trace')}), flush=True)
