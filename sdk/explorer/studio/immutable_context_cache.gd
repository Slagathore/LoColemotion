extends RefCounted
## Process-local memoization for source-bound pure context predicates only.
## No caller-owned value is frozen or changed. Observations are never cached.
const MAX_NODES := 4096
const MAX_BYTES := 262144
const MAX_DEPTH := 48
const MAX_ENTRIES := 64
static var enabled := false
static var entries: Dictionary = {}
static var hits := 0
static var misses := 0

static func check(owner: Object, context: Dictionary, predicate: String, oracle: Callable) -> bool:
	if not enabled:return bool(oracle.call())
	var entry: Dictionary=entries.get(predicate,{})
	# Equality against a bounded, object-free snapshot is the cheap structural
	# guard. Native binary encoding then preserves int/float and signed-zero
	# distinctions which Variant equality alone does not preserve.
	if entry.get("owner")==owner and not entry.is_empty() and context==entry.snapshot:
		if var_to_bytes(context)==entry.key:
			hits+=1
			return true
	entries.erase(predicate);misses+=1
	var accepted:=bool(oracle.call())
	if accepted and eligible(context,0,[MAX_NODES,MAX_BYTES]):
		var key:=var_to_bytes(context)
		if key.size()<=MAX_BYTES:
			var snapshot:=context.duplicate(true)
			freeze(snapshot)
			if entries.size()>=MAX_ENTRIES:entries.clear()
			entries[predicate]={"owner":owner,"snapshot":snapshot,"key":key}
	return accepted

static func reset() -> void:
	entries.clear();hits=0;misses=0

static func eligible(value: Variant, depth: int, budget: Array) -> bool:
	budget[0]-=1
	if depth>MAX_DEPTH or budget[0]<0:return false
	match typeof(value):
		TYPE_NIL,TYPE_BOOL,TYPE_INT:return true
		TYPE_FLOAT:return is_finite(value)
		TYPE_STRING:
			budget[1]-=value.to_utf8_buffer().size()
			return budget[1]>=0
		TYPE_ARRAY:
			if value.is_typed() or value.size()>budget[0]:return false
			for item in value:
				if not eligible(item,depth+1,budget):return false
			return true
		TYPE_DICTIONARY:
			if value.is_typed() or value.size()*2>budget[0]:return false
			for key in value:
				if typeof(key)!=TYPE_STRING or not eligible(key,depth+1,budget) or not eligible(value[key],depth+1,budget):return false
			return true
	return false

static func freeze(value: Variant) -> void:
	if value is Array:
		for item in value:freeze(item)
		value.make_read_only()
	elif value is Dictionary:
		for item in value.values():freeze(item)
		value.make_read_only()
