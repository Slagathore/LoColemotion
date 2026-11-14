use godot::builtin::{AnyArray, AnyDictionary, VariantType};
use godot::prelude::*;

#[derive(GodotClass)]
#[class(init, base=RefCounted)]
struct SporeFiniteSourceValidator {
    base: Base<RefCounted>,
}

#[godot_api]
impl SporeFiniteSourceValidator {
    #[func]
    fn validation_version(&self) -> GString {
        "sporespore_finite_source_validation_v1".into()
    }

    /// Preserve the existing collection transport's type and depth rules.
    /// Variant type tags are checked before conversion: StringName keys,
    /// packed arrays, objects and portable-request vectors remain invalid.
    #[func]
    fn validate_source_v1(&self, value: Variant, depth: i64, source_link: bool) -> bool {
        // An explicit stack avoids native recursion on cyclic host containers.
        // Every nested child still consumes the original depth allowance.
        let mut pending = vec![(value, depth)];
        while let Some((value, depth)) = pending.pop() {
            if depth > 128 {
                return false;
            }
            match value.get_type() {
                VariantType::NIL | VariantType::BOOL | VariantType::INT | VariantType::STRING => {}
                VariantType::FLOAT => {
                    if !value.try_to::<f64>().is_ok_and(f64::is_finite) {
                        return false;
                    }
                }
                VariantType::VECTOR3 => {
                    if !source_link
                        || !value
                            .try_to::<Vector3>()
                            .is_ok_and(|v| v.x.is_finite() && v.y.is_finite() && v.z.is_finite())
                    {
                        return false;
                    }
                }
                VariantType::ARRAY => {
                    let Ok(array) = value.try_to::<AnyArray>() else {
                        return false;
                    };
                    for child in array.iter_shared() {
                        pending.push((child, depth + 1));
                    }
                }
                VariantType::DICTIONARY => {
                    let Ok(dictionary) = value.try_to::<AnyDictionary>() else {
                        return false;
                    };
                    for (key, child) in dictionary.iter_shared() {
                        if key.get_type() != VariantType::STRING {
                            return false;
                        }
                        pending.push((child, depth + 1));
                    }
                }
                _ => return false,
            }
        }
        true
    }
}

struct FiniteSourceValidation;

#[gdextension]
unsafe impl ExtensionLibrary for FiniteSourceValidation {}
