class_name Lineage
extends Resource

## Replay/debug record for analytic evolution. It intentionally stores compact
## signatures and fitness summaries, not whole populations.

@export var edges: Array[Dictionary] = []
@export var best_by_generation: Array[Dictionary] = []


func record_child(generation: int, parent_a: String, parent_b: String, child: String,
		fitness: float) -> void:
	edges.append({
		"generation": generation,
		"parent_a": parent_a,
		"parent_b": parent_b,
		"child": child,
		"fitness": fitness,
	})


func record_best(generation: int, signature: String, fitness: float) -> void:
	best_by_generation.append({
		"generation": generation,
		"signature": signature,
		"fitness": fitness,
	})


func last_best_fitness() -> float:
	if best_by_generation.is_empty():
		return -INF
	return float(best_by_generation[best_by_generation.size() - 1]["fitness"])
