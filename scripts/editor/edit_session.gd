class_name EditSession
extends RefCounted
## The single mutation path for an authored genome (P0 spine). Every edit -- a knob
## nudge, a part add, a gizmo release -- goes through apply_edit() and nothing else.
## Invariants enforced here: I3 (operate on a fresh deep_copy; reject aliasing via
## GenomeSnapshot.validate_unique; undo/redo install isolated copies) and I4 (re-score
## is debounced through ScoreScheduler, never inline). Views listen to the signals;
## they NEVER mutate _root and NEVER compute physics (I2) -- they render current().
##
## Undo/redo is delegated to the F4 GenomeHistory (scripts/core/genome_history.gd),
## which owns the snapshot-isolation contract: reset/push copy IN, undo/redo hand back
## a FRESH isolated copy, so the live tree never aliases a stored frame.

signal genome_changed(root: PartGene)     # the tree changed; rebuild the viewport from root()
signal score_changed(result: Dictionary)  # a fresh evaluate() applied; repaint the overlay
signal edit_rejected(reason: String)       # an edit failed the uniqueness guard; surface it

var _root: PartGene
var _scheduler: ScoreScheduler
var _history: GenomeHistory
var _last_error: String = ""

func _init(initial_root: PartGene, sched: ScoreScheduler = null) -> void:
    _history = GenomeHistory.new()
    _scheduler = sched if sched != null else ScoreScheduler.new()
    _root = GenomeSnapshot.deep_copy(initial_root)   # own a private copy; caller keeps theirs
    _history.reset(_root)                              # seed history with the starting state
    _scheduler.request(_root)                          # prime an initial score

func root() -> PartGene:
    return _root

func last_error() -> String:
    return _last_error

func scheduler() -> ScoreScheduler:
    return _scheduler

func current_score() -> Dictionary:
    return _scheduler.current()

## Apply a mutation. The mutator receives a FRESH deep copy and edits it in place.
## Returns false (leaving the live tree untouched) if the result aliases a sub-resource.
func apply_edit(mutator: Callable) -> bool:
    var next := GenomeSnapshot.deep_copy(_root)        # I3: never touch the live tree
    mutator.call(next)                                  # caller mutates the COPY
    var chk := GenomeSnapshot.validate_unique(next)     # I3: structural legality
    if not bool(chk["ok"]):
        _last_error = String(chk["error"])
        edit_rejected.emit(_last_error)
        return false
    _root = next
    _history.push(_root)                                # F4: record the new committed state
    _scheduler.request(_root)                           # I4: debounced re-score
    genome_changed.emit(_root)
    return true

func can_undo() -> bool:
    return _history.can_undo()

func can_redo() -> bool:
    return _history.can_redo()

func undo() -> bool:
    var prev: PartGene = _history.undo()               # returns a fresh isolated copy, or null
    if prev == null:
        return false
    _root = prev
    _scheduler.request(_root)
    genome_changed.emit(_root)
    return true

func redo() -> bool:
    var nxt: PartGene = _history.redo()
    if nxt == null:
        return false
    _root = nxt
    _scheduler.request(_root)
    genome_changed.emit(_root)
    return true

## Synchronous drain of the F5 scheduler (headless/tests, or a simple main-thread pump).
## Returns true if a fresh score was applied. The live UI in P2 may instead use
## take_pending()/evaluate()/accept() on a worker; this is the blocking equivalent.
func pump_blocking() -> bool:
    if not _scheduler.has_pending():
        return false
    var r := _scheduler.run_pending_blocking()
    if r.is_empty():
        return false
    score_changed.emit(_scheduler.current())
    return true
