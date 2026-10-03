class_name LabSourceStateGate
extends RefCounted

## G14: dirty-source experiments remain useful development evidence, but can
## never be promoted as canonical knowledge.


static func assess(
		git_commit: String,
		dirty_worktree: bool,
		loaded_resource_hashes: Dictionary) -> Dictionary:
	var reasons: Array = []
	var commit_regex := RegEx.new()
	commit_regex.compile("^[0-9a-f]{40}$")
	if commit_regex.search(git_commit.to_lower()) == null:
		reasons.append("GIT_COMMIT_UNRESOLVED")
	if dirty_worktree:
		reasons.append("DIRTY_WORKTREE")
	var hash_regex := RegEx.new()
	hash_regex.compile("^sha256:[0-9a-f]{64}$")
	if loaded_resource_hashes.is_empty():
		reasons.append("LOADED_RESOURCE_HASHES_EMPTY")
	for path in loaded_resource_hashes.keys():
		if String(path).is_empty() or hash_regex.search(
				String(loaded_resource_hashes[path])) == null:
			reasons.append("INVALID_LOADED_RESOURCE_HASH:%s" % String(path))
	reasons.sort()
	return {
		"gate_id": "G14_SOURCE_STATE",
		"pass": reasons.is_empty(),
		"execution_mode": "promotion" if reasons.is_empty() else "development",
		"reproducibility": (
			"clean_committed_source"
			if reasons.is_empty()
			else "partial_dirty_or_unresolved_source"),
		"reasons": reasons,
	}


static func probe_repository(repo_path: String) -> Dictionary:
	var commit_output: Array = []
	var status_output: Array = []
	var commit_exit := OS.execute(
		"git", ["-C", repo_path, "rev-parse", "HEAD"], commit_output, true)
	var status_exit := OS.execute(
		"git", ["-C", repo_path, "status", "--porcelain=v1"], status_output, true)
	var commit := ""
	if commit_exit == 0 and not commit_output.is_empty():
		commit = String(commit_output[0]).strip_edges()
	var status_text := "\n".join(status_output).strip_edges()
	return {
		"ok": commit_exit == 0 and status_exit == 0,
		"git_commit": commit,
		"dirty_worktree": status_exit != 0 or not status_text.is_empty(),
		"status_porcelain": status_text,
	}
