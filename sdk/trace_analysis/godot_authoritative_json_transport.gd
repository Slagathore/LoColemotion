class_name SdkGodotAuthoritativeJsonTransport
extends RefCounted

## One explicit JSON transport for evidence-bearing Godot values.
##
## Godot's default JSON.stringify precision is intentionally not used here.
## Both terminal receipts and retained trace rows must pass through this same
## operation so a Python binary64 consumer sees one numeric identity.

const TRANSPORT_ID := "godot_4_7_sorted_full_precision_authoritative_json_v1"
const GODOT_INVOCATION := "JSON.stringify(value, \"\", true, true)"


static func stringify(value: Variant) -> String:
	return JSON.stringify(value, "", true, true)


static func line(value: Variant) -> String:
	return stringify(value) + "\n"


static func receipt() -> Dictionary:
	return {
		"schema_version": "sporespore_godot_authoritative_json_transport_receipt_v1",
		"transport_id": TRANSPORT_ID,
		"godot_runtime_version": String(Engine.get_version_info().get("string", "")),
		"selected_godot_invocation": GODOT_INVOCATION,
		"sorted_keys": true,
		"full_precision": true,
		"numeric_consumer": "cpython_json_ieee754_binary64",
		"physical_acceptance_authority": false,
	}
