"""Generate the opt-in contact-frame observer patch against exact frozen v6.

This tool reads the frozen dependency and writes a repository patch only. It
does not alter the frozen engine, build a runtime or create a physics world.
"""
import argparse
import difflib
import hashlib
import json
from pathlib import Path

from r10ac_contact_sampling_component import check_frozen_source, ROOT, git, binding

PATCH = ROOT / 'sdk/adapters/godot/engine_patches/godot_4_7_jolt_contact_frames_v7.patch'
PREFIX = 'modules/jolt_physics/'


def once(text, old, new):
    assert text.count(old) == 1, old
    return text.replace(old, new, 1)


def transformed(checkout):
    names = ['spaces/jolt_contact_listener_3d.h', 'spaces/jolt_contact_listener_3d.cpp',
             'spaces/jolt_space_3d.h', 'spaces/jolt_space_3d.cpp',
             'jolt_physics_server_3d.h', 'jolt_physics_server_3d.cpp']
    original = {PREFIX+p: (checkout/PREFIX/p).read_text(encoding='utf-8') for p in names}
    edited = dict(original)
    p = PREFIX+'spaces/jolt_contact_listener_3d.h'
    edited[p] = once(edited[p], '#include "core/variant/variant.h"', '#include "core/variant/variant.h"\n#include "core/variant/dictionary.h"')
    edited[p] = once(edited[p], '\t\tfloat depth = 0.0f;', '''		float depth = 0.0f;
		// Diagnostic snapshots only; neither collision points nor constraints change.
		Transform3D frame_transform1;
		Transform3D frame_transform2;
		bool frame_captured = false;
		uint32_t frame_duplicate_callback_count = 0;''')
    edited[p] = once(edited[p], '\tbool solved_contact_telemetry_valid = false;', '''	bool solved_contact_telemetry_valid = false;
	bool contact_frames_enabled = false;
	Dictionary contact_frames_snapshot;
	void _capture_contact_frames(uint64_t p_space_step_sequence);''')
    edited[p] = once(edited[p], '\tvoid pre_step();', '''	void set_contact_frames_enabled(bool p_enabled);
	Dictionary get_contact_frames() const;
	void pre_step();''')

    p = PREFIX+'spaces/jolt_contact_listener_3d.cpp'
    edited[p] = once(edited[p], '#include "jolt_contact_listener_3d.h"', '#include "jolt_contact_listener_3d.h"\n\n#include "core/variant/array.h"')
    edited[p] = once(edited[p], '\tif (unlikely(!manifold.contacts1.is_empty())) {', '''	if (unlikely(!manifold.contacts1.is_empty())) {
		if (contact_frames_enabled) {
			manifold.frame_duplicate_callback_count++;
		}''')
    edited[p] = once(edited[p], '\tconst JPH::uint contact_count = p_manifold.mRelativeContactPointsOn1.size();', '''	if (contact_frames_enabled) {
		// Same shape-origin and local scale convention as get_transform_scaled().
		// Use the callback bodies directly: do not re-lock them from this callback.
		manifold.frame_transform1 = Transform3D(to_godot(p_jolt_body1.GetRotation()), to_godot(p_jolt_body1.GetPosition())).scaled_local(body1->get_scale());
		manifold.frame_transform2 = Transform3D(to_godot(p_jolt_body2.GetRotation()), to_godot(p_jolt_body2.GetPosition())).scaled_local(body2->get_scale());
		manifold.frame_captured = true;
	}

	const JPH::uint contact_count = p_manifold.mRelativeContactPointsOn1.size();''')
    edited[p] = once(edited[p], 'void JoltContactListener3D::pre_step() {', '''void JoltContactListener3D::set_contact_frames_enabled(bool p_enabled) {
	contact_frames_enabled = p_enabled;
	contact_frames_snapshot.clear();
}

Dictionary JoltContactListener3D::get_contact_frames() const {
	return contact_frames_snapshot.duplicate(true);
}

void JoltContactListener3D::pre_step() {
	if (contact_frames_enabled) {
		contact_frames_snapshot.clear();
		for (KeyValue<JPH::SubShapeIDPair, Manifold> &E : manifolds_by_shape_pair) {
			E.value.frame_captured = false;
			E.value.frame_duplicate_callback_count = 0;
		}
	}''')
    edited[p] = once(edited[p], '\t\t\tsolved_contact_telemetry.nonfinite_impulse_count == 0;\n}', '''			solved_contact_telemetry.nonfinite_impulse_count == 0;
	if (contact_frames_enabled) {
		_capture_contact_frames(p_space_step_sequence);
	}
}''')
    insertion = '''void JoltContactListener3D::_capture_contact_frames(uint64_t p_space_step_sequence) {
	Array points;
	uint32_t missing_frames = 0;
	uint32_t duplicate_callbacks = 0;
	uint32_t invalid_frames = 0;
	bool overflow = false;
	for (const KeyValue<JPH::SubShapeIDPair, Manifold> &E : manifolds_by_shape_pair) {
		const Manifold &manifold = E.value;
		if (manifold.contacts1.is_empty() && manifold.contacts2.is_empty()) {
			continue;
		}
		duplicate_callbacks += manifold.frame_duplicate_callback_count;
		if (!manifold.frame_captured) {
			missing_frames++;
			continue;
		}
		if (!manifold.frame_transform1.is_finite() || !manifold.frame_transform2.is_finite() ||
				Math::is_zero_approx(manifold.frame_transform1.basis.determinant()) ||
				Math::is_zero_approx(manifold.frame_transform2.basis.determinant())) {
			invalid_frames++;
			continue;
		}
		JoltBody3D *body1 = space->try_get_body(E.key.GetBody1ID());
		JoltBody3D *body2 = space->try_get_body(E.key.GetBody2ID());
		if (body1 == nullptr || body2 == nullptr || manifold.contacts1.size() != manifold.contacts2.size()) {
			missing_frames++;
			continue;
		}
		const Transform3D inverse1 = manifold.frame_transform1.affine_inverse();
		const Transform3D inverse2 = manifold.frame_transform2.affine_inverse();
		for (uint32_t i = 0; i < manifold.contacts1.size(); i++) {
			if (points.size() >= 4096) {
				overflow = true;
				break;
			}
			const Contact &contact1 = manifold.contacts1[i];
			const Contact &contact2 = manifold.contacts2[i];
			if (!contact1.point_self.is_finite() || !contact2.point_self.is_finite() ||
					!contact1.normal.is_finite() || !contact2.normal.is_finite() ||
					!contact1.impulse.is_finite() || !contact2.impulse.is_finite()) {
				invalid_frames++;
				continue;
			}
			Dictionary point;
			point["body1_jolt_id"] = static_cast<int64_t>(E.key.GetBody1ID().GetIndexAndSequenceNumber());
			point["body2_jolt_id"] = static_cast<int64_t>(E.key.GetBody2ID().GetIndexAndSequenceNumber());
			point["body1_instance_id"] = static_cast<int64_t>(body1->get_instance_id());
			point["body2_instance_id"] = static_cast<int64_t>(body2->get_instance_id());
			point["subshape1_id"] = static_cast<int64_t>(E.key.GetSubShapeID1().GetValue());
			point["subshape2_id"] = static_cast<int64_t>(E.key.GetSubShapeID2().GetValue());
			point["shape1_index"] = body1->find_shape_index(E.key.GetSubShapeID1());
			point["shape2_index"] = body2->find_shape_index(E.key.GetSubShapeID2());
			point["manifold_point_index"] = i;
			point["body1_transform_at_detection"] = manifold.frame_transform1;
			point["body2_transform_at_detection"] = manifold.frame_transform2;
			point["point1_world_m"] = contact1.point_self;
			point["point2_world_m"] = contact2.point_self;
			point["point1_body_local_m"] = inverse1.xform(contact1.point_self);
			point["point2_body_local_m"] = inverse2.xform(contact2.point_self);
			point["normal1_world_unit"] = contact1.normal;
			point["normal2_world_unit"] = contact2.normal;
			point["impulse1_world_ns"] = contact1.impulse;
			point["impulse2_world_ns"] = contact2.impulse;
			points.push_back(point);
		}
	}
	contact_frames_snapshot["schema"] = "sporespore.godot_jolt_contact_frames.v1";
	contact_frames_snapshot["profile_id"] = "godot_4_7_jolt_sporespore_contact_frames_v7";
	contact_frames_snapshot["capture_space_step_sequence"] = static_cast<int64_t>(p_space_step_sequence);
	contact_frames_snapshot["captured_during_active_step"] = space->is_stepping();
	contact_frames_snapshot["sampling_stage"] = solved_contact_telemetry.complete && duplicate_callbacks == 0 ? "contact_detection_before_integration" : "unqualified_contact_callback";
	contact_frames_snapshot["discrete_sampling_qualified"] = solved_contact_telemetry.complete && duplicate_callbacks == 0;
	contact_frames_snapshot["reported_point_count"] = solved_contact_telemetry.reported_contact_point_count;
	contact_frames_snapshot["missing_manifold_count"] = solved_contact_telemetry.missing_manifold_count;
	contact_frames_snapshot["ccd_only_manifold_count"] = solved_contact_telemetry.ccd_only_manifold_count;
	contact_frames_snapshot["point_count_mismatch_count"] = solved_contact_telemetry.point_count_mismatch_count;
	contact_frames_snapshot["nonfinite_impulse_count"] = solved_contact_telemetry.nonfinite_impulse_count;
	contact_frames_snapshot["missing_frame_count"] = missing_frames;
	contact_frames_snapshot["duplicate_callback_count"] = duplicate_callbacks;
	contact_frames_snapshot["invalid_frame_count"] = invalid_frames;
	contact_frames_snapshot["point_limit_exceeded"] = overflow;
	contact_frames_snapshot["points"] = points;
	contact_frames_snapshot["complete"] = solved_contact_telemetry.complete && missing_frames == 0 &&
			duplicate_callbacks == 0 && invalid_frames == 0 && !overflow &&
			static_cast<uint32_t>(points.size()) == solved_contact_telemetry.reported_contact_point_count;
}

'''
    edited[p] = once(edited[p], 'bool JoltContactListener3D::try_get_solved_contact_telemetry(', insertion+'bool JoltContactListener3D::try_get_solved_contact_telemetry(')
    p = PREFIX+'spaces/jolt_space_3d.h'
    edited[p] = once(edited[p], '#pragma once', '#pragma once\n\n#include "core/variant/dictionary.h"')
    edited[p] = once(edited[p], '\tvoid call_queries();', '''	void set_contact_frames_enabled(bool p_enabled);
	Dictionary get_contact_frames() const;
	void call_queries();''')
    p = PREFIX+'spaces/jolt_space_3d.cpp'
    edited[p] = once(edited[p], 'void JoltSpace3D::call_queries() {', '''void JoltSpace3D::set_contact_frames_enabled(bool p_enabled) {
	contact_listener->set_contact_frames_enabled(p_enabled);
}

Dictionary JoltSpace3D::get_contact_frames() const {
	return contact_listener->get_contact_frames();
}

void JoltSpace3D::call_queries() {''')
    p = PREFIX+'jolt_physics_server_3d.h'
    edited[p] = once(edited[p], '\tstatic Variant space_get_solved_contact_telemetry(RID p_space);', '''	static bool space_set_contact_frames_enabled(RID p_space, bool p_enabled);
	static Variant space_get_contact_frames(RID p_space);
	static Variant space_get_solved_contact_telemetry(RID p_space);''')
    p = PREFIX+'jolt_physics_server_3d.cpp'
    edited[p] = once(edited[p], 'void JoltPhysicsServer3D::_bind_methods() {', '''void JoltPhysicsServer3D::_bind_methods() {
	ClassDB::bind_static_method("JoltPhysicsServer3D", D_METHOD("space_set_contact_frames_enabled", "space", "enabled"), &JoltPhysicsServer3D::space_set_contact_frames_enabled);
	ClassDB::bind_static_method("JoltPhysicsServer3D", D_METHOD("space_get_contact_frames", "space"), &JoltPhysicsServer3D::space_get_contact_frames);''')
    edited[p] = once(edited[p], 'Variant JoltPhysicsServer3D::space_get_solved_contact_telemetry(', '''bool JoltPhysicsServer3D::space_set_contact_frames_enabled(RID p_space, bool p_enabled) {
	JoltPhysicsServer3D *physics_server = get_singleton();
	if (physics_server == nullptr || (physics_server->on_separate_thread && !physics_server->doing_sync)) {
		return false;
	}
	JoltSpace3D *space = physics_server->space_owner.get_or_null(p_space);
	if (space == nullptr || space->is_stepping()) {
		return false;
	}
	space->set_contact_frames_enabled(p_enabled);
	return true;
}

Variant JoltPhysicsServer3D::space_get_contact_frames(RID p_space) {
	JoltPhysicsServer3D *physics_server = get_singleton();
	if (physics_server == nullptr || (physics_server->on_separate_thread && !physics_server->doing_sync)) {
		return Variant();
	}
	JoltSpace3D *space = physics_server->space_owner.get_or_null(p_space);
	if (space == nullptr || space->is_stepping()) {
		return Variant();
	}
	Dictionary result = space->get_contact_frames();
	if (result.is_empty()) {
		return Variant();
	}
	result["read_space_step_sequence"] = static_cast<int64_t>(space->get_step_sequence());
	result["snapshot_is_current_space_step"] = int64_t(result["capture_space_step_sequence"]) == static_cast<int64_t>(space->get_step_sequence());
	return result;
}

Variant JoltPhysicsServer3D::space_get_solved_contact_telemetry(''')
    return original, edited


def render():
    checkout, _ = check_frozen_source()
    original, edited = transformed(checkout)
    return ''.join('diff --git a/'+name+' b/'+name+'\n'+''.join(difflib.unified_diff(
        original[name].splitlines(keepends=True), edited[name].splitlines(keepends=True),
        fromfile='a/'+name, tofile='b/'+name)) for name in sorted(original))


def verify_checkout(target):
    checkout, frozen = check_frozen_source()
    original, edited = transformed(checkout)
    target = Path(target).resolve()
    assert target != checkout.resolve()
    assert git(target, 'rev-parse', 'HEAD') == git(checkout, 'rev-parse', 'HEAD')
    assert git(target, 'remote', 'get-url', 'origin') == git(checkout, 'remote', 'get-url', 'origin')
    paths = sorted(set(git(checkout, 'diff', '--name-only', 'HEAD').decode().splitlines()) | set(edited))
    assert sorted(git(target, 'diff', '--name-only', 'HEAD').decode().splitlines()) == paths
    for name in paths:
        expected = edited[name] if name in edited else (checkout/name).read_text(encoding='utf-8')
        assert (target/name).read_text(encoding='utf-8') == expected, name
    diff = git(target, 'diff', '--binary', '--full-index', '--no-ext-diff', 'HEAD')
    return dict(checkout=target.as_posix(), upstream_commit=frozen['upstream_commit'],
        diff_raw_sha256='sha256:'+hashlib.sha256(diff).hexdigest(), diff_byte_length=len(diff),
        files=[binding(target/p) for p in paths], patch=binding(PATCH))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--write', action='store_true')
    parser.add_argument('--verify-checkout')
    args = parser.parse_args()
    value = render()
    if args.write:
        with PATCH.open('x', encoding='utf-8', newline='\n') as stream:
            stream.write(value)
    else:
        assert PATCH.read_text(encoding='utf-8') == value
    if args.verify_checkout:
        print(json.dumps(verify_checkout(args.verify_checkout)))
    else:
        print('R10AC_CONTACT_FRAME_PATCH '+str(len(value.encode()))+' bytes; zero worlds')
