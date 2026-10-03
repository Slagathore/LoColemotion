class_name GenomeHistory
extends RefCounted

## F4 — minimal undo/redo over a PartGene genome, built on GenomeSnapshot.deep_copy.
##
## Model: a stack of committed genome STATES (deep, isolated copies). The top of `_undo` is the
## current state. `push` after each committed edit; `undo`/`redo` walk the stack and hand back a
## FRESH isolated copy to install as the live genome (so the live tree never aliases a stored
## entry — a later edit can't corrupt history, and undoing again is still byte-exact).
##
## SCOPE: the snapshot/restore contract only. The undo-stack UI plumbing — command labels,
## coalescing/merging of rapid edits into one undo step, keybindings — is the editor's job,
## once this contract is fixed.

var _undo: Array[PartGene] = []
var _redo: Array[PartGene] = []


## Initialise history with the genome's starting state. Clears any prior history.
func reset(root: PartGene) -> void:
	_undo = [GenomeSnapshot.deep_copy(root)]
	_redo = []


## Record a new committed state. Call AFTER applying an edit to the live `root`.
## Drops the redo branch (standard linear-history behaviour). O(genome size).
func push(root: PartGene) -> void:
	_undo.append(GenomeSnapshot.deep_copy(root))
	_redo = []


func can_undo() -> bool:
	return _undo.size() > 1


func can_redo() -> bool:
	return not _redo.is_empty()


## Step back one state. Returns a fresh isolated copy to install as the live genome,
## or null if there is nothing to undo.
func undo() -> PartGene:
	if not can_undo():
		return null
	_redo.append(_undo.pop_back())
	return GenomeSnapshot.deep_copy(_undo.back())


## Step forward one state. Returns a fresh isolated copy to install, or null if nothing to redo.
func redo() -> PartGene:
	if not can_redo():
		return null
	var state: PartGene = _redo.pop_back()
	_undo.append(state)
	return GenomeSnapshot.deep_copy(state)


func depth() -> int:
	return _undo.size()
