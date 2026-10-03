class_name ScoreScheduler
extends RefCounted

## F5 — the live re-score concurrency contract: how a worker-thread evaluate()/run_probe runs
## against a genome being actively edited, so that (a) no stale result overwrites a newer one and
## (b) the probe never reads the genome while the main thread mutates it.
##
## Two ORTHOGONAL mechanisms, both deterministic:
##
##   1. COALESCING (debounce support).  request() keeps only the LATEST pending snapshot. When the
##      editor's debounce timer fires it calls take_pending(), so at most ONE eval is dispatched
##      per window no matter how many edits arrived.
##   2. STALENESS (generation).  Every request carries a monotonically increasing generation;
##      accept() applies a result only if it is NEWER than the last applied. Debounce reduces but
##      never fully removes overlap, so two evals can be in flight at once — the late-arriving
##      OLDER one is dropped, never displayed.
##
## NO DATA RACE: the genome is deep-copied (GenomeSnapshot) at REQUEST time, so the worker reads an
## immutable snapshot. Main-thread mutation of the live genome after dispatch cannot reach an
## in-flight eval. evaluate()/run_probe themselves are untouched pure functions — this is a
## scheduling/ownership contract, not a math change.
##
## The CORE (request / take_pending / accept) is fully synchronous and does NOT depend on thread
## timing — that is the whole point, and it is what the tests pin. `run_pending_blocking` is a
## thin, verifiable worker adapter. For the live editor, prefer the non-blocking pattern:
##
##     var job := sched.take_pending()
##     if not job.is_empty():
##         WorkerThreadPool.add_task(func ():
##             var r := CharacteristicsEvaluator.evaluate(job["snapshot"])
##             sched._apply_deferred.bind(job["gen"], r).call_deferred())   # accept() on main thread
##
## SCOPE: scheduling / snapshot / cancellation. OUT: the debounce timer, panel wiring, progress UI.

var _gen: int = 0              # last assigned generation (monotonic)
var _applied_gen: int = 0      # highest generation whose result is current
var _pending: Dictionary = {}  # {gen:int, snapshot:PartGene} — only the LATEST survives
var _current: Dictionary = {}  # last applied evaluate() result


## Main thread. Record a re-score request for the current live genome. Snapshots immediately
## (isolating the worker from later edits) and returns the new generation. Coalescing: a newer
## request overwrites the pending slot, so N rapid edits leave exactly one (the latest) pending.
func request(root: PartGene) -> int:
	_gen += 1
	_pending = {"gen": _gen, "snapshot": GenomeSnapshot.deep_copy(root)}
	return _gen


func has_pending() -> bool:
	return not _pending.is_empty()


## Called when the debounce timer fires. Returns {gen, snapshot} to dispatch to a worker, or {}
## if nothing is pending, and clears the slot (only the latest snapshot is dispatched).
func take_pending() -> Dictionary:
	if _pending.is_empty():
		return {}
	var job := _pending
	_pending = {}
	return job


## Main thread. Called when a worker finishes. Applies the result only if it is newer than the
## last applied generation; otherwise the stale result is dropped. Returns true iff displayed.
func accept(gen: int, result: Dictionary) -> bool:
	if gen <= _applied_gen:
		return false
	_applied_gen = gen
	_current = result
	return true


func current() -> Dictionary:
	return _current


func generation() -> int:
	return _gen


func applied_generation() -> int:
	return _applied_gen


## Verifiable worker adapter: dispatch the latest pending eval onto a real worker thread, BLOCK
## until it finishes, apply via accept(), and return {gen, result, applied} ({} if nothing
## pending). Blocking is for tests / headless determinism; the live editor uses the non-blocking
## pattern in the class docstring. The worker reads only the immutable snapshot.
func run_pending_blocking() -> Dictionary:
	var job := take_pending()
	if job.is_empty():
		return {}
	var gen: int = job["gen"]
	var snap: PartGene = job["snapshot"]
	var box := {"r": {}}
	var tid := WorkerThreadPool.add_task(func (): box["r"] = CharacteristicsEvaluator.evaluate(snap))
	WorkerThreadPool.wait_for_task_completion(tid)        # happens-before: worker done before we read
	var applied := accept(gen, box["r"])
	return {"gen": gen, "result": box["r"], "applied": applied}


## Helper for the non-blocking editor pattern: apply a worker result on the main thread.
func _apply_deferred(gen: int, result: Dictionary) -> void:
	accept(gen, result)
