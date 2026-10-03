"""MuJoCo host adapter for the SporeSpore engine-neutral locomotion core.

The conformance module is deliberately not imported here. This keeps
``python -m sporespore_mujoco_adapter.conformance`` single-loaded and avoids a
runpy double-import warning in evidence transcripts.

This package marker is an exact-byte R23D62 dependency and remains LF-stable.
"""
