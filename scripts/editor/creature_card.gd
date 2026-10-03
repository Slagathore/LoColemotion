class_name CreatureCard
extends Resource

## A saved/editor-visible creature. T1/T2 uses embedded roots so loading is
## self-contained while the catalog and authored-part pipeline are still moving.

@export var display_name: String = "Untitled"
@export var root: PartGene
@export var schema_version: int = 1
@export var notes: String = ""
# M51: display-only skin palette (base/secondary color + pattern id). Never feeds physics/scoring
# (Principle 22); applied to the skin material by SkinBuilder.apply_palette. Round-trips with the card.
@export var palette: Dictionary = {}
