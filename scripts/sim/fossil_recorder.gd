class_name FossilRecorder
extends RefCounted

## M51 Toybox (FUN-2) — the Fossil Ghost. Records each generation's champion (a GenomeSnapshot +
## its SimRollout.trajectory) so an earlier ancestor can be replayed as a translucent ghost running
## the same track beside the current champion: you watch evolution outrun its past self, and it
## doubles as a regression check ("did this gen actually improve?"). Cheap — trajectories are
## already collected by SimRollout. The ghost RENDERING is play-tested; record/replay is unit-tested.

var _fossils: Array[Dictionary] = []


func record(generation: int, root: PartGene, trajectory: Array, fitness := 0.0) -> void:
	if root == null:
		return
	var traj: Array = []
	for p in trajectory:
		traj.append(p)
	_fossils.append({
		"generation": generation,
		"snapshot": GenomeSnapshot.to_dictionary(root),
		"trajectory": traj,
		"fitness": fitness,
	})


func count() -> int:
	return _fossils.size()


func fossil(index: int) -> Dictionary:
	if index < 0 or index >= _fossils.size():
		return {}
	return _fossils[index]


# Reconstruct an ancestor's genome (for spawning the ghost body).
func ghost_genome(index: int) -> PartGene:
	var f := fossil(index)
	if f.is_empty():
		return null
	return GenomeSnapshot.from_dictionary(f["snapshot"])


# The ghost's CoM position at a normalized time t in [0,1] along its recorded trajectory.
func replay_position(index: int, t: float) -> Vector3:
	var f := fossil(index)
	var traj: Array = f.get("trajectory", [])
	if traj.is_empty():
		return Vector3.ZERO
	if traj.size() == 1:
		return traj[0]
	var u := clampf(t, 0.0, 1.0) * float(traj.size() - 1)
	var i := int(floor(u))
	var frac := u - float(i)
	var a: Vector3 = traj[i]
	var b: Vector3 = traj[mini(i + 1, traj.size() - 1)]
	return a.lerp(b, frac)


# Did the latest generation improve on the best ancestor? (the regression-check use)
func improved() -> bool:
	if _fossils.size() < 2:
		return true
	var latest := float(_fossils[_fossils.size() - 1]["fitness"])
	var best_prior := -INF
	for i in _fossils.size() - 1:
		best_prior = maxf(best_prior, float(_fossils[i]["fitness"]))
	return latest >= best_prior
