extends SceneTree

const CanonicalJsonScript := preload("res://scripts/lab/canonical_json.gd")
const ClassifierScript := preload("res://scripts/lab/mechanics/pose_classifier.gd")
const FactoryScript := preload("res://scripts/lab/mechanics/br12_pose_recovery_fixture_factory.gd")
const OracleScript := preload("res://scripts/lab/mechanics/labeled_box_pose_oracle.gd")

var _passed := 0
var _failed := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("=== Experimental BR12.1 deterministic pose classifier ===")
	var config := FactoryScript.classifier_configuration()
	var compiled := ClassifierScript.build_configuration(config)
	_check(bool(compiled.get("ok", false)), "strict profile-specific classifier seals")
	for pose in ["upright", "prone", "supine", "left_side", "right_side"]:
		var result := _classify(config, FactoryScript.box_state(pose))
		var classification: Dictionary = result.get("classification", {})
		_check(
			(
				bool(result.get("ok", false))
				and String(classification.get("pose", "")) == pose
				and float(classification.get("confidence", 0.0)) > 0.15
			),
			"canonical labeled-box %s classifies deterministically" % pose
		)
	var first := _classify(config, FactoryScript.box_state("prone"))
	var second := _classify(config, FactoryScript.box_state("prone"))
	_check(
		CanonicalJsonScript.stringify(first) == CanonicalJsonScript.stringify(second),
		"identical observations produce byte-identical classification"
	)
	var ambiguous := _classify(config, FactoryScript.box_state("ambiguous_prone_left"))
	_check(
		(
			String((ambiguous["classification"] as Dictionary)["pose"]) == "unknown"
			and (
				String((ambiguous["classification"] as Dictionary)["reason"])
				== "POSE_CLASS_AMBIGUOUS"
			)
		),
		"nearly tied side/prone evidence remains explicitly ambiguous"
	)
	var missing_contact_state := FactoryScript.box_state("prone")
	missing_contact_state["contact_regions"] = []
	var missing_contact := _classify(config, missing_contact_state)
	_check(
		(
			String((missing_contact["classification"] as Dictionary)["pose"]) == "unknown"
			and (
				String((missing_contact["classification"] as Dictionary)["reason"])
				== "POSE_REQUIRED_EVIDENCE_MISSING"
			)
		),
		"strong orientation without required region contact does not classify"
	)
	var low_upright_state := FactoryScript.box_state("upright")
	low_upright_state["support_height_m"] = 0.2
	var low_upright := _classify(config, low_upright_state)
	_check(
		String((low_upright["classification"] as Dictionary)["pose"]) == "unknown",
		"low body with upright axis cannot masquerade as supported upright"
	)
	var invalid_observation := (
		(OracleScript.observe(FactoryScript.box_state("upright"))["observation"] as Dictionary)
		. duplicate(true)
	)
	invalid_observation["sensor_valid"] = false
	var invalid := ClassifierScript.classify(config, invalid_observation)
	_check(
		(
			String((invalid["classification"] as Dictionary)["pose"]) == "unknown"
			and not bool((invalid["classification"] as Dictionary)["sensor_valid"])
		),
		"sensor-invalid observation returns UNKNOWN with zero authority"
	)
	var result := _classify(config, FactoryScript.box_state("upright"))
	var classification: Dictionary = result["classification"]
	_check(
		(
			not bool(classification["automatic_creature_guidance_allowed"])
			and not bool(classification["recovery_actuation_authorized"])
		),
		"classification grants neither recovery actuation nor creature guidance"
	)
	var guided := config.duplicate(true)
	guided["automatic_creature_guidance_enabled"] = true
	_check(
		not bool(ClassifierScript.build_configuration(guided).get("ok", true)),
		"classifier configuration cannot authorize guidance"
	)
	var loose := config.duplicate(true)
	loose["face_vertical_dot_min"] = 0.1
	_check(
		not bool(ClassifierScript.build_configuration(loose).get("ok", true)),
		"threshold too weak to preserve pose identity fails closed"
	)
	_finish()


func _classify(config: Dictionary, state: Dictionary) -> Dictionary:
	var observed := OracleScript.observe(state)
	if not bool(observed.get("ok", false)):
		return observed
	return ClassifierScript.classify(config, observed["observation"])


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("  PASS  ", label)
	else:
		_failed += 1
		printerr("  FAIL  ", label)


func _finish() -> void:
	print("=== %d passed, %d failed ===" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)
