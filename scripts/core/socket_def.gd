class_name SocketDef
extends Resource

## How a part attaches to its parent. The frame law composes these:
##   child_world = parent_world * parent_attachment * child_anchor
## (scale is tracked separately, never baked into the transform). hinge_axis ZERO
## means a rigid attachment; non-zero is a 1-DoF hinge used by the gait probe.

@export var id:                StringName                          # stable within the part (round-trip key)
@export var display_name:      String                              # rename-safe label; never the key
@export var parent_attachment: Transform3D = Transform3D.IDENTITY  # pose of the socket on the parent
@export var child_anchor:      Transform3D = Transform3D.IDENTITY  # the child's own anchor frame
@export var hinge_axis:        Vector3 = Vector3.ZERO              # ZERO = rigid; non-zero = 1-DoF hinge (probe-driven)

# -----------------------------------------------------------------------------
# D1 LOCKED (2026-06-26): 1-DoF is the CANONICAL actuated joint. 2-DoF is DEFERRED,
# not abandoned. The rationale + re-entry conditions are pinned here so the decision
# is greppable and the field below is never a silent trap.
#
# WHY 1-DoF IS ENOUGH FOR NOW:
#   hinge_axis is a free Vector3, not body-locked. A single ORIENTED hinge already
#   spans the whole upright-runner body plan and the full standard gait taxonomy
#   (walk / trot / pace / bound / gallop) -- those gaits differ only by PHASE, which
#   lives in GaitDef.assignments, NOT by a second axis. Tilting the lone hinge also
#   fakes much apparent multi-planar motion (scuttle, pseudo-sprawl) for free.
#   Biology rhymes: evolution defaults distal limb joints to hinges (knee / elbow /
#   ankle) and only pays for a true 2nd axis at the proximal joints of specialists.
#
# WHEN 2-DoF BECOMES REAL (the "can't fake it with an oriented hinge" niche):
#   - ball/socket steering joints that swing fore-aft AND abduct on an INDEPENDENT
#     phase (sprawlers: lizards, salamanders, crocs)
#   - active pronation / supination as its own DoF
#   - grasping / opposition (climbers, manipulators)
#   A creature whose CORE IDENTITY is one of those flips this decision.
#
# WHAT BUILDING IT REQUIRES (do NOT free-hand -- route through Foundry Q3 first):
#   a 2nd drive angle, a phase relation to the primary axis, a lateral-thrust term in
#   the probe, and a HARD L4 PROOF: hinge_axis_2 == ZERO must stay byte-identical to
#   the 1-DoF path (the same presence-toggle trick E3 uses for muscle torque).
# TODO(H1 / Foundry-Q3): 2-DoF probe dynamics + full dof_axes land here.
# -----------------------------------------------------------------------------
@export var hinge_axis_2:      Vector3 = Vector3.ZERO              # RESERVED, authored-but-UNDRIVEN. See D1 block. ZERO = 1-DoF, L4-safe.


## True iff a non-zero second hinge axis is authored. Cheap predicate for the future
## 2-DoF probe path and its L4 gate -- when 2-DoF exists, the contract is:
##   if not socket.has_second_axis(): <1-DoF path>   # must stay byte-identical
## Also the basis of authoring_warning() below.
func has_second_axis() -> bool:
	return not hinge_axis_2.is_zero_approx()


## Load/validation-time guard. Returns "" when the socket is clean, else a warning.
## hinge_axis_2 is a SILENT NO-OP until 2-DoF dynamics exist (D1 deferred): an author
## who sets it expecting lateral thrust gets nothing, with no error -- this turns that
## trap into a visible warning. Call ONCE PER SOCKET at load time, NEVER in the probe
## hot loop.
## TODO(S1): invoke from the .tres loader where sockets[id] -> gene.socket resolves:
##   var w := socket.authoring_warning()
##   if w: push_warning(w)
func authoring_warning() -> String:
	if has_second_axis():
		return "SocketDef '%s': hinge_axis_2 is set (%s) but 2-DoF is not driven yet (D1 deferred / H1). This axis is a no-op today; the probe drives hinge_axis only." % [id, hinge_axis_2]
	return ""
