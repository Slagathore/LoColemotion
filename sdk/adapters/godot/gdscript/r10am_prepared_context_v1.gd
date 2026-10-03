extends RefCounted
## Pure selected-runtime context input binding. No candidate-source admission,
## population reservation, or world authorization is granted by this interface.
const Seed := preload("res://sdk/adapters/godot/gdscript/r10am_development_seed_v1.gd")

static func inputs_v1(declaration: Dictionary) -> Dictionary:
    var identity := Seed.seed_identity_v1(Seed.SEED)
    if not Seed.authorized_v1(declaration, str(Seed.SEED), identity.label, identity.sha256,
        Seed.ROLE, declaration.get("source_snapshot", {}).get("head", "")):
        return {}
    var profile: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Seed.PROFILE))
    for row in [{"path": profile.runtime_binding, "sha": profile.runtime_binding_sha256},
        {"path": profile.extension, "sha": profile.extension_sha256}]:
        if "sha256:" + FileAccess.get_sha256(row.path) != row.sha: return {}
    var runtime: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(profile.runtime_binding))
    if runtime.runtime.raw_sha256 != profile.runtime_sha256: return {}
    var schedule_path := "res://sdk/development/recovery_schedules/" + str(profile.diagnostic_schedule_id) + ".json"
    if "sha256:" + FileAccess.get_sha256(schedule_path) != profile.diagnostic_schedule_sha256: return {}
    var schedule: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(schedule_path)).schedules[profile.diagnostic_schedule_id]
    return {"candidate_selection": {"candidate_profile": declaration.candidate_profile,
        "post_kick_controller_id": profile.post_kick_controller_id, "diagnostic_schedule": schedule,
        "worker_selection": {"extension": profile.extension, "binding": profile.runtime_binding}},
        "entry_runtime": runtime, "seed": Seed.SEED, "source_admission_checked": false,
        "physical_execution_authorized": false, "physical_acceptance_authority": false, "release_authority": false}
