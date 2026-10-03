extends RefCounted

## Retained experiment, NOT installed in the production reader. Its complete
## retained-record replay was slower; see sdk/development/recovery_performance_v1.json.
## Preserve authoritative-JSON equality without repeatedly escaping whole
## retained JSON strings. No cache, tolerance, hashing shortcut or mutation.
## Numeric and unusual Variant cases retain the original serializer semantics.
const Transport := preload("res://sdk/trace_analysis/godot_authoritative_json_transport.gd")


static func same_v1(left: Variant, right: Variant, depth: int = 0) -> bool:
	var kind := typeof(left)
	if kind != typeof(right) or depth >= 64:
		return Transport.stringify(left) == Transport.stringify(right)
	match kind:
		TYPE_NIL:
			return true
		TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return left == right
		TYPE_ARRAY:
			if left.size() != right.size():
				return false
			for index in range(left.size()):
				if not same_v1(left[index], right[index], depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			# Only JSON's unambiguous string-key domain uses the structural path.
			# Engine coercion/collisions for other key types stay with the serializer.
			for key in left:
				if typeof(key) != TYPE_STRING:
					return Transport.stringify(left) == Transport.stringify(right)
			for key in right:
				if typeof(key) != TYPE_STRING:
					return Transport.stringify(left) == Transport.stringify(right)
			if left.size() != right.size():
				return false
			for key in left:
				if not right.has(key) or not same_v1(left[key], right[key], depth + 1):
					return false
			return true
	# Floats deliberately include signed zero/nonfinite formatting. Mixed int/
	# float kinds above also preserve the existing full-precision wire behavior.
	return Transport.stringify(left) == Transport.stringify(right)
