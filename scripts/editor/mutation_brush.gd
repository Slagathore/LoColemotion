class_name MutationBrush
extends RefCounted

## M53 Toybox (FUN-5) — the mutation brush. Pure, deterministic genome-edit operators the editor
## "paints" onto a selected part through EditSession (so each stroke is validated + undoable). These
## bridge hand-authoring and evolution: nudge a creature toward an idea and watch fitness react.
## UI (the brush tool + live re-score) is play-tested; these operators are unit-tested.

static func paint(gene: PartGene, op: StringName, factor := 1.25) -> void:
	match op:
		&"lengthen":
			lengthen(gene, factor)
		&"thicken":
			thicken(gene, factor)
		&"shrink":
			lengthen(gene, 1.0 / maxf(factor, 0.01))
		&"mirror_x":
			mirror_x(gene)


# Stretch along the part's long axis (Y) — make a leg/segment longer.
static func lengthen(gene: PartGene, factor := 1.25) -> void:
	if gene == null:
		return
	gene.scale.y = maxf(gene.scale.y * factor, 0.01)


# Fatten across the part's cross-section (X, Z) — thicker limb/body.
static func thicken(gene: PartGene, factor := 1.25) -> void:
	if gene == null:
		return
	gene.scale.x = maxf(gene.scale.x * factor, 0.01)
	gene.scale.z = maxf(gene.scale.z * factor, 0.01)


# Mirror a subtree across the creature's left-right (X) axis: flip socket X offset + hinge X for
# the whole subtree. (A lightweight authoring symmetry aid; the editor's full Mirror does more.)
static func mirror_x(gene: PartGene) -> void:
	if gene == null:
		return
	if gene.socket != null:
		var pa := gene.socket.parent_attachment
		pa.origin.x = -pa.origin.x
		gene.socket.parent_attachment = pa
		gene.socket.hinge_axis.x = -gene.socket.hinge_axis.x
	for c in gene.children:
		mirror_x(c)
