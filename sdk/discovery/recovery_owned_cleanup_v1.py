"""Retain and verify bounded cleanup before releasing a leaf's job handle."""
import time
import recovery_discovery as D


def drain(job, windows, receipt, timeout=10):
    # The caller has already collected the primary process's exit status.
    # Preserve every residual identity; never exempt a process by image name.
    before = []
    for pid in job.pids():
        identity = windows.identity(pid)
        try:
            image = D.image_path(pid) if identity is not None else None
        except (ValueError, OSError):
            image = None
        before.append(dict(pid=pid, identity=identity, image=image))
    if before:
        job.terminate()
    deadline = time.monotonic() + timeout
    while job.pids() and time.monotonic() < deadline:
        time.sleep(.05)
    remaining = job.pids()
    D.write_new(receipt, dict(before_termination=before,
        termination_requested=bool(before), remaining_owned_pids=remaining,
        cleanup_complete=not remaining, timeout_seconds=timeout))
    D.require(not remaining, 'LEAF_OWNED_CLEANUP_INCOMPLETE')
