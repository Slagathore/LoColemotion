// The wire enum is generated at build time from the same data as the scripts.
// No Python installation, engine, or physics world is needed to build the core.
use std::{collections::HashSet, env, fs, path::PathBuf};

fn main() {
    let source = PathBuf::from(env::var_os("CARGO_MANIFEST_DIR").unwrap())
        .join("contracts/recovery_interfaces_v1.json");
    println!("cargo:rerun-if-changed={}", source.display());
    let contract: serde_json::Value =
        serde_json::from_slice(&fs::read(source).expect("recovery interface contract")).unwrap();
    assert_eq!(
        contract["schema_version"],
        "sporespore_recovery_interfaces_v1"
    );
    let owners = contract["canonical_owners"].as_array().unwrap();
    assert!(!owners.is_empty());
    let mut variants = HashSet::new();
    let mut wires = HashSet::new();
    let mut generated = String::from(
        "#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]\n\
         pub enum RecoveryControllerOwnerV1 {\n",
    );
    for owner in owners {
        let variant = owner["rust_variant"].as_str().unwrap();
        let wire = owner["wire_name"].as_str().unwrap();
        assert!(variant.starts_with(|c: char| c.is_ascii_uppercase()));
        assert!(variant.chars().all(|c| c.is_ascii_alphanumeric()));
        assert!(wire.starts_with(|c: char| c.is_ascii_lowercase()));
        assert!(
            wire.chars()
                .all(|c| c.is_ascii_lowercase() || c.is_ascii_digit() || c == '_')
        );
        assert!(variants.insert(variant) && wires.insert(wire));
        generated.push_str(&format!(
            "    #[serde(rename = \"{wire}\")]\n    {variant},\n"
        ));
    }
    generated.push_str("}\n");
    let output =
        PathBuf::from(env::var_os("OUT_DIR").unwrap()).join("recovery_controller_owner_v1.rs");
    fs::write(output, generated).unwrap();
}
