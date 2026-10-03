class_name CreatureMigrations
extends RefCounted

## Version gate for CreatureCard resources. Migrations are deliberately small and
## idempotent: each step owns exactly one schema bump.

const CURRENT := 1


static func migrate(card: CreatureCard) -> CreatureCard:
	if card == null:
		return null
	var migrated := card.duplicate(true) as CreatureCard
	if migrated == null:
		return null
	while migrated.schema_version < CURRENT:
		var next := migrated.schema_version + 1
		match next:
			1:
				migrated = _to_v1(migrated)
			_:
				push_error("CreatureMigrations: no migration path to schema %d" % next)
				return null
	return migrated


static func _to_v1(card: CreatureCard) -> CreatureCard:
	card.schema_version = 1
	if card.display_name.strip_edges() == "":
		card.display_name = "Untitled"
	return card
