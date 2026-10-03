class_name GenomeLoader
extends RefCounted

## Resolves a genome's STABLE KEYS into the RESOLVED SNAPSHOTS the evaluator reads.
##
## The genome persists stable keys for round-trip / L5 (PartGene.part_id, .socket_id);
## the evaluator reads resolved snapshots (PartGene.socket, .joint, and root.gait). This is
## the bridge between them -- the ".tres loader" the schema always assumed but that did not
## exist until S1. Before this, every genome was hand-built by setting .socket directly, so
## the joints/gait stamp from a parent PartResource was never exercised end-to-end.
##
## WHAT IT STAMPS (and ONLY this):
##   gene.socket  <- parent_resource.sockets[gene.socket_id]   # frame-law attachment snapshot
##   gene.joint   <- parent_resource.joints[gene.socket_id]    # Fork B3 actuation envelope
##   root.gait    <- the creature-level GaitDef                # Fork C2 (root gene only)
## and it fires SocketDef.authoring_warning() once per resolved socket (the D1 no-op guard).
##
## DELIBERATELY OUT OF SCOPE: descriptor / definition / shape authority. That is Foundry Q1
## (physics authority) and S2 -- unsettled. Resolving shape here would front-run that fork, so
## the loader leaves gene.definition / gene.descriptor exactly as authored and touches nothing
## but attachment + actuation + gait.
##
## L4 / PASS-THROUGH: a gene with no part_id/socket_id (legacy hand-built or un-authored tree)
## is left untouched, so resolve() on a legacy genome is a no-op -> byte-identical probe.
## CYCLE/DAG-SAFE: each node is resolved exactly once (mirrors fold_graph's seen-set guard).


## Resolve a genome in place and return root (for chaining).
## parts_by_id: Dictionary[StringName part_id -> PartResource]. A node's resource describes how
## its CHILDREN attach -- sockets/joints keyed by the child's socket_id -- mirroring fold semantics.
static func resolve(root: PartGene, parts_by_id: Dictionary,
		gait: GaitDef = null, warn := true) -> PartGene:
	if root == null:
		return null
	if gait != null:
		root.gait = gait                       # C2: gait is creature-level, ROOT gene only
	var seen := {}
	_resolve_node(root, parts_by_id, warn, seen)
	return root


## Collect authoring warnings for the whole tree WITHOUT emitting them. The editor/validation
## surface (S5) calls this to show problems inline; resolve() emits the same via push_warning.
## Returns one string per problem; empty array = clean genome.
static func validate(root: PartGene) -> PackedStringArray:
	var out := PackedStringArray()
	var seen := {}
	_collect_warnings(root, seen, out)
	return out


static func _resolve_node(node: PartGene, parts_by_id: Dictionary, warn: bool, seen: Dictionary) -> void:
	if node == null or seen.has(node):
		return
	seen[node] = true
	# This node's resource describes how ITS CHILDREN attach (sockets/joints keyed by child.socket_id).
	var res: PartResource = parts_by_id.get(node.part_id, null)
	for child in node.children:
		if child == null:
			continue
		# Stamp only when this node has a resource AND the child names a socket on it.
		# socket_id == &"" is an intentional rigid/anonymous attach: leave snapshots as-authored.
		if res != null and child.socket_id != &"":
			if res.sockets.has(child.socket_id):
				child.socket = res.sockets[child.socket_id]
			elif warn:
				push_warning("GenomeLoader: part '%s' has no socket '%s' (child '%s' unresolved)"
						% [node.part_id, child.socket_id, child.part_id])
			if res.joints.has(child.socket_id):
				child.joint = res.joints[child.socket_id]      # B3; absent key -> engine default (null)
			if warn and child.socket != null:
				var w := child.socket.authoring_warning()       # D1 no-op guard, once per resolved socket
				if w != "":
					push_warning(w)
		_resolve_node(child, parts_by_id, warn, seen)


static func _collect_warnings(node: PartGene, seen: Dictionary, out: PackedStringArray) -> void:
	if node == null or seen.has(node):
		return
	seen[node] = true
	if node.socket != null:
		var w := node.socket.authoring_warning()
		if w != "":
			out.append(w)
	for child in node.children:
		_collect_warnings(child, seen, out)
