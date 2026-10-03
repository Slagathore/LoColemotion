# Retained upright-stabilization observation

This directory preserves the source of Cole's unofficial visible diagnostic and
its [retained observation record](retained_observation_v1.json). It is development
evidence, not an official qualification or a new SDK acceptance mark.

The completed 15-second simulated clip applies one kick at five seconds. Initial
canonical prone setup precedes displayed time zero. The native selector enters
upright stabilization at 7.008333 seconds, resumes walking at 9.766667 seconds and
remains in walking resume when the clip ends at 15 seconds. Minimum post-kick torso
center height is 0.309714645 m and maximum tilt is 9.696676 degrees. No post-kick
prone-recovery branch is selected. The inherited phase name
`controller_free_descent_to_measured_prone` denotes the passive observation phase;
its name is not evidence that this body reached prone.

The two seconds after the kick are passive observation. Active stabilization
follows. These measurements support the recorded branch sequence, not a claim of
instantaneous active balance at impact, realistic gait, arbitrary kick recovery,
or complete official contact/energy/no-cheat verification.

The original data, configuration and logs remain in the durable evidence root.
The closure binds their exact bytes. Diagnostic source was separately preserved
after the run, before the licensing commit; this is explicitly a retrospective
source snapshot, not a prospective freeze. Git text normalization must not be
mistaken for byte identity with that retained snapshot.

**Do not execute `launch.py` or reuse `active_config.txt` to rerun this identity.**
They are preserved forensic source and point at the consumed diagnostic folder.
Any new experiment needs fresh ownership, identity, output paths and its applicable
safety checks. The full directory is excluded from the distributable SDK projection.

The earlier stopped and infrastructure-refused visual attempts remain at their
original `visual-phase74-658c0865542e4e73b58ba88b757973ee` and
`visual-phase74-d64f2e2485eb423eaee433bf8c69ee7d` evidence locations; they are not
reclassified as completed successes by this observation.
