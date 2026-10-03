class_name CreatureStage
extends Node3D

## M12 Loop-1 (MVP): a creature is placed in a world, LOCOMOTES to food (steering via
## the M7C turn_rate toward the nearest morsel), EATS on contact, and when the patch is
## cleared (or the generation times out) REPRODUCES — its genome mutates and the next
## generation forages a fresh patch. Survival (food eaten) drives evolution.
##
## Pure-script scene: instantiate and add to the tree, or attach to a Node3D in a .tscn.
## Headless-safe (the smoke test drives it without a window).

const CreatureBodyScript := preload("res://scripts/sim/creature_body.gd")
const CpgControllerScript := preload("res://scripts/sim/cpg_controller.gd")
const SimWorldScript := preload("res://scripts/sim/sim_world.gd")
const WorldObjectScript := preload("res://scripts/sim/world_object.gd")
const CreatureStageLoopScript := preload("res://scripts/sim/creature_stage_loop.gd")

const SETTLE_FRAMES := 90
const EAT_RADIUS := 1.8         # forgiving: the morsel is a physics body the creature bumps
const STEER_GAIN := 1.6
const MAX_TURN := 1.2
const GEN_TIME := 20.0          # seconds before a generation is force-ended

@export var food_count := 6
@export var food_radius := 7.0
@export var population_size := 4
@export var render_uses_measured_selection := true

var _seed_root: PartGene
var _genome: PartGene
var _body: Node3D
var _controller: Node
var _population: Array[PartGene] = []
var _bodies: Array[Node3D] = []
var _controllers: Array[Node] = []
var _food: Array[RigidBody3D] = []
var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _gen_t := 0.0
var _settle_left := 0
var _generation := 0
var _eaten_this_gen := 0
var _total_eaten := 0
var _best_eaten := 0
var _label: Label
var _started := false
var _ending_generation := false
var _selection_history: Array[Dictionary] = []


func _ready() -> void:
	_rng.seed = 20260627
	var floor_body := SimWorldScript.add_floor(self, 1.0)
	_add_floor_mesh(floor_body)
	_add_camera()
	_add_hud()
	if _seed_root == null:
		_seed_root = PartCatalog.make_flagship_quadruped()
	_population = EvolutionEngine.initial_population(_seed_root, population_size, int(_rng.seed), null)
	if _population.is_empty():
		_population = [GenomeSnapshot.deep_copy(_seed_root)]
	_genome = GenomeSnapshot.deep_copy(_population[0])
	_begin_generation()
	_started = true


# Optional: seed the stage with a specific creature before adding it to the tree.
func configure(seed_root: PartGene) -> void:
	_seed_root = seed_root


func generation() -> int:
	return _generation


func total_eaten() -> int:
	return _total_eaten


func visible_agent_count() -> int:
	return _bodies.size()


func selection_history() -> Array[Dictionary]:
	return _selection_history.duplicate(true)


func _begin_generation() -> void:
	_clear_food()
	_spawn_food()
	_spawn_creatures()
	_gen_t = 0.0
	_eaten_this_gen = 0
	_settle_left = SETTLE_FRAMES
	_ending_generation = false
	_update_hud()


func _physics_process(delta: float) -> void:
	if not _started or _controllers.is_empty() or _ending_generation:
		return
	if _settle_left > 0:
		_settle_left -= 1
		return
	_t += delta
	_gen_t += delta
	for i in _controllers.size():
		var ctrl := _controllers[i]
		var rb := _root_body_for(_bodies[i]) if i < _bodies.size() else null
		_steer_toward_food(ctrl, rb)
		ctrl.call("tick", _t, delta)
	_eat_check()
	if _food.is_empty() or _gen_t >= GEN_TIME:
		_end_generation()


func _steer_toward_food(ctrl: Node, rb: RigidBody3D) -> void:
	if ctrl == null or rb == null:
		return
	var target := _nearest_food(rb.global_position)
	if target == null:
		ctrl.call("set_turn_rate", 0.0)
		return
	var heading := rb.global_basis * Vector3.FORWARD
	heading.y = 0.0
	var to_food := target.global_position - rb.global_position
	to_food.y = 0.0
	if heading.length() < 0.001 or to_food.length() < 0.001:
		return
	heading = heading.normalized()
	to_food = to_food.normalized()
	# Signed bearing (left/right) from heading to the food, about world up.
	var bearing := atan2(heading.cross(to_food).y, heading.dot(to_food))
	ctrl.call("set_turn_rate", clampf(bearing * STEER_GAIN, -MAX_TURN, MAX_TURN))


func _eat_check() -> void:
	for i in range(_food.size() - 1, -1, -1):
		var f := _food[i]
		if f == null:
			_food.remove_at(i)
			continue
		for body in _bodies:
			var rb := _root_body_for(body)
			if rb == null:
				continue
			var d := rb.global_position - f.global_position
			d.y = 0.0
			if d.length() <= EAT_RADIUS:
				f.queue_free()
				_food.remove_at(i)
				_eaten_this_gen += 1
				_total_eaten += 1
				_update_hud()
				break


func _end_generation() -> void:
	if _ending_generation:
		return
	_ending_generation = true
	_best_eaten = maxi(_best_eaten, _eaten_this_gen)
	_generation += 1
	call_deferred("_advance_generation_from_measurement")


func _advance_generation_from_measurement() -> void:
	if render_uses_measured_selection:
		var cfg := CreatureStageLoopScript.Config.new()
		cfg.population_size = maxi(population_size, _population.size())
		cfg.food_count = food_count
		cfg.horizon = 0.45
		cfg.prescreen_keep = maxi(1, _population.size())
		cfg.hazard_count = 0
		cfg.agent_count = 0
		cfg.seed = 5000 + _generation
		var scored: Array = await CreatureStageLoopScript.measure_population_loop2(
				_population, cfg, get_tree(), _rng, _generation)
		_selection_history.append({
			"generation": _generation,
			"measured": true,
			"synthetic_contact": false,
			"visible_agents": _bodies.size(),
			"scored": scored.size(),
			"best_forward": float(scored[0].get("forward", 0.0)) if not scored.is_empty() else 0.0,
			"credible_rate": _credible_rate(scored),
		})
		_population = _next_population_from_scored(scored)
	else:
		var next: Array[PartGene] = []
		for g in _population:
			next.append(GenomeMutator.mutate(g, null, _rng))
		_population = next
	if _population.is_empty():
		_population = [GenomeSnapshot.deep_copy(_seed_root)]
	_genome = GenomeSnapshot.deep_copy(_population[0])
	_begin_generation()


# --- world construction -------------------------------------------------------

func _spawn_food() -> void:
	for i in food_count:
		var pos := Vector3.FORWARD * food_radius
		if i > 0:
			var a := TAU * float(i - 1) / float(maxi(food_count - 1, 1))
			pos = Vector3(cos(a) * food_radius, 0.4, sin(a) * food_radius)
		pos.y = 0.4
		var f := WorldObjectScript.make_food(pos)
		add_child(f)
		_food.append(f)


func _clear_food() -> void:
	for f in _food:
		if f != null:
			f.queue_free()
	_food.clear()


func _spawn_creatures() -> void:
	if _body != null:
		_body.queue_free()
	if _controller != null:
		_controller.queue_free()
	for body in _bodies:
		if body != null:
			body.queue_free()
	for ctrl in _controllers:
		if ctrl != null:
			ctrl.queue_free()
	_bodies.clear()
	_controllers.clear()
	for i in _population.size():
		var angle := TAU * float(i) / float(maxi(_population.size(), 1))
		var pos := Vector3(cos(angle) * 2.0, 0.0, sin(angle) * 2.0)
		_spawn_creature(_population[i], pos)
	if not _bodies.is_empty():
		_body = _bodies[0]
		_controller = _controllers[0]
	else:
		_body = null
		_controller = null
	_t = 0.0


func _spawn_creature(genome: PartGene, offset: Vector3) -> void:
	var fold := CharacteristicsEvaluator.fold_graph(genome, Transform3D.IDENTITY)
	var min_y := 0.0
	for p in fold["parts"]:
		min_y = minf(min_y, p.world_aabb.position.y)
	var spawn_y := maxf(0.4 - min_y, 0.6)
	var body := CreatureBodyScript.build(GenomeSnapshot.deep_copy(genome),
			Transform3D(Basis.IDENTITY, Vector3(offset.x, spawn_y, offset.z)))
	add_child(body)
	_add_part_meshes(body)
	var controller := CpgControllerScript.new()
	controller.call("bind", body, genome, _controller_params_from_gait(genome.gait))
	add_child(controller)
	_bodies.append(body)
	_controllers.append(controller)


func _root_body() -> RigidBody3D:
	return _root_body_for(_body)


func _root_body_for(body_node: Node3D) -> RigidBody3D:
	if body_node == null or not body_node.has_method("part_bodies"):
		return null
	var bodies: Array = body_node.call("part_bodies")
	return bodies[0] as RigidBody3D if not bodies.is_empty() else null


func _nearest_food(from: Vector3) -> RigidBody3D:
	var best: RigidBody3D = null
	var best_d := INF
	for f in _food:
		if f == null:
			continue
		var d := from.distance_to(f.global_position)
		if d < best_d:
			best_d = d
			best = f
	return best


func _controller_params_from_gait(gait: GaitDef) -> CpgControllerScript.Params:
	var p := CpgControllerScript.Params.new()
	if gait != null:
		p.amplitude_scale = gait.amplitude_scale
		p.frequency_scale = gait.frequency_scale
		p.gain_scale = gait.gain_scale
		p.traction_scale = gait.traction_scale
		p.posture_scale = gait.posture_scale
	return p


func _add_part_meshes(body_node: Node3D) -> void:
	if body_node == null or not body_node.has_method("part_bodies"):
		return
	var bodies: Array = body_node.call("part_bodies")
	var parts: Array = body_node.call("parts")
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.47, 0.74)
	mat.roughness = 0.75
	for i in bodies.size():
		var rb := bodies[i] as RigidBody3D
		if rb == null or i >= parts.size():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = PartMeshProvider.mesh_for(parts[i].definition.part_type, parts[i].dims)
		mi.material_override = mat
		rb.add_child(mi)


func _add_floor_mesh(floor_body: StaticBody3D) -> void:
	if floor_body == null:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(40.0, 0.2, 40.0)
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.22, 0.17)
	mi.material_override = mat
	floor_body.add_child(mi)


func _add_camera() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 14.0, 16.0)
	cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
	add_child(cam)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55.0, -35.0, 0.0)
	add_child(light)


func _add_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_label.offset_left = 16.0
	_label.offset_top = 12.0
	_label.offset_right = 620.0
	_label.offset_bottom = 64.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_label)


func _update_hud() -> void:
	if _label != null:
		_label.text = "Gen %d   agents: %d   eaten: %d   total: %d   best: %d" % [
			_generation, _bodies.size(), _eaten_this_gen, _total_eaten, _best_eaten]


func _credible_rate(scored: Array) -> float:
	if scored.is_empty():
		return 0.0
	var n := 0
	for row in scored:
		if bool((row as Dictionary).get("credible", false)):
			n += 1
	return float(n) / float(scored.size())


func _next_population_from_scored(scored: Array) -> Array[PartGene]:
	var survivors: Array[PartGene] = []
	for i in mini(scored.size(), maxi(1, population_size / 2)):
		var row: Dictionary = scored[i]
		if bool(row.get("alive", true)):
			survivors.append(row["root"])
	if survivors.is_empty() and not scored.is_empty():
		survivors.append((scored[0] as Dictionary)["root"])
	var next: Array[PartGene] = []
	for s in survivors:
		next.append(GenomeSnapshot.deep_copy(s))
	while next.size() < population_size and not survivors.is_empty():
		var parent: PartGene = survivors[_rng.randi_range(0, survivors.size() - 1)]
		next.append(GenomeMutator.mutate(parent, null, _rng))
	return next
