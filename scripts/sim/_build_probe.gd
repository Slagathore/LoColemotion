extends SceneTree

func _initialize() -> void:
	print("probe: start")
	var g = PartCatalog.make_quadruped_v2()
	print("probe: made quad")
	var n := 0
	var stack := [g]
	while not stack.is_empty() and n < 1000:
		var p = stack.pop_back()
		n += 1
		for c in p.children:
			stack.append(c)
	print("probe: part count = ", n)
	var sy = SimRollout.spawn_y(g)
	print("probe: spawn_y = ", sy)
	quit(0)
