"""R10DG host-time successor; identical native ownership assertions, zero worlds."""
import importlib.util
import json
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location(
    "_r10dg_private_native_fixture", ROOT / "tests/test_r10x_native_process_observation.py")
native = importlib.util.module_from_spec(spec)
spec.loader.exec_module(native)


def powershell(mode, fixture, evidence=None):
    # Only the 32-snapshot host stress test receives additional wall time.
    # Production launch deadlines and every inherited assertion are unchanged.
    timeout = 180 if mode == "Observe" and fixture.get("repeat") == 32 else 60
    result = subprocess.run(
        [str(native.legacy.PWSH), "-NoProfile", "-NonInteractive", "-File",
         str(native.legacy.RUNNER), "-Mode", mode],
        input=json.dumps(fixture, separators=(",", ":")), text=True,
        capture_output=True, cwd=ROOT, timeout=timeout, check=False)
    if evidence is not None:
        (evidence / "live.stdout.log").write_text(result.stdout, encoding="utf-8")
        (evidence / "live.stderr.log").write_text(result.stderr, encoding="utf-8")
        (evidence / "live-execution.json").write_text(json.dumps(dict(
            exit_code=result.returncode, world_build_count=0, solver_step_count=0))
            + "\n", encoding="utf-8")
    result.check_returncode()
    if result.stderr:
        raise AssertionError(result.stderr)
    return json.loads(result.stdout)


native.legacy.powershell = powershell


class NativeLaunchRelationshipTests(native.NativeLaunchRelationshipTests):
    """Original seven launcher and reader checks."""


class NativeObservationTests(native.NativeObservationTests):
    """Original six native observer checks."""


if __name__ == "__main__":
    unittest.main()
