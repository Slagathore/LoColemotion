extends RefCounted

static func run(legacy: Script, native: Object, sources: Array) -> Dictionary:
	var cases: Array = [null,true,false,0,1,-1,0.0,-0.0,INF,-INF,NAN,"",Vector3.ZERO,
		Vector3(INF,0,0),Vector2.ZERO,PackedByteArray([1]),StringName("name"),{},[],
		{"ok":[1,2.5,null,"x",true]}, {1:"invalid key"},{"bad":[NAN]},
		{"vector":[Vector3.ONE]},Callable(),RefCounted.new()]
	var typed_array: Array[int] = [1,2]
	var typed_dict: Dictionary[String,int] = {"x":1}
	cases.append(typed_array);cases.append(typed_dict)
	for count in [127,128,129]:
		var deep: Variant = 1
		for ignored in count:deep=[deep]
		cases.append(deep)
		deep=[]
		for ignored in count:deep={"next":deep}
		cases.append(deep)
	# Compare deterministic mixed trees, plus their malformed siblings, against
	# the unchanged predecessor. This tests behavior rather than its new loop.
	var rng := RandomNumberGenerator.new()
	rng.seed=70418
	for index in 128:
		var tree: Variant = [rng.randi_range(-1000,1000),rng.randf_range(-5,5),index % 2 == 0]
		for depth in rng.randi_range(0,8):
			tree={"nested":tree,"number":rng.randf(),"text":"source"} if depth % 2 else [tree,null]
		cases.append(tree);cases.append({"tree":tree,"bad":[INF]})
	for value in sources:cases.append(value)
	var cycle: Array = []
	cycle.append(cycle);cases.append(cycle)
	cases.append_array([PackedInt32Array([1]),PackedInt64Array([1]),PackedFloat32Array([1]),
		PackedFloat64Array([1]),PackedStringArray(["x"]),{StringName("x"):1},Vector3(NAN,0,0),NodePath("x")])
	var dictionary_cycle: Dictionary = {}
	dictionary_cycle["self"] = dictionary_cycle;cases.append(dictionary_cycle)
	var checks := 0
	var failures: Array = []
	for index in cases.size():
		for source_link in [false,true]:
			for depth in [0,127,128,129]:
				var expected: bool = legacy._studio_reference_json_source_v1(cases[index],depth,source_link)
				var actual: bool = native.validate_source_v1(cases[index],depth,source_link)
				checks+=1
				if actual!=expected:failures.append({"case":index,"source_link":source_link,"depth":depth})
	cycle.clear();dictionary_cycle.clear()
	return {"ok":failures.is_empty(),"checks":checks,"cases":cases.size(),"failures":failures,
		"world_build_count":0,"solver_steps":0,"oracle":"unchanged predecessor finite-source validator"}
