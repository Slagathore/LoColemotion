use std::process::ExitCode;

use serde_json::json;
use sporespore_locomotion_core::{
    BoundedQuadrupedDescriptor, balanced_wave_profile_for_policy, digest_serializable,
};

fn main() -> ExitCode {
    let mut arguments = std::env::args().skip(1);
    let Some(policy_id) = arguments.next() else {
        eprintln!("usage: inspect_policy_profile <balanced-wave-policy-id>");
        return ExitCode::from(2);
    };
    if arguments.next().is_some() {
        eprintln!("inspect_policy_profile accepts exactly one policy id");
        return ExitCode::from(2);
    }

    let descriptor = BoundedQuadrupedDescriptor::reference("policy_profile_inspector_reference");
    let profile = match balanced_wave_profile_for_policy(&descriptor, &policy_id) {
        Ok(profile) => profile,
        Err(error) => {
            eprintln!("policy profile inspection failed: {error}");
            return ExitCode::FAILURE;
        }
    };
    let profile_sha256 = match digest_serializable(&profile) {
        Ok(digest) => digest,
        Err(error) => {
            eprintln!("policy profile digest failed: {error}");
            return ExitCode::FAILURE;
        }
    };
    let receipt = json!({
        "schema_version": "sporespore_policy_profile_inspection_receipt_v1",
        "ok": true,
        "policy_id": policy_id,
        "reference_descriptor": descriptor,
        "profile": profile,
        "profile_sha256": profile_sha256,
        "actual_world_build_count": 0,
        "physics_state_modified": false,
        "locomotion_outcome_exposed": false,
        "physical_acceptance_authority": false
    });
    println!("{receipt}");
    ExitCode::SUCCESS
}
