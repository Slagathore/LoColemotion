"""Bind the unchanged retrieval algorithm to a distinct immutable feedback plan.

Loading a separate module gives its functions and dataclass their own globals;
the consumed v1 module and CONTRACT remain untouched. Both source files and the
new plan are bound by the native campaign, and both variants can coexist.
"""
import importlib.util
from pathlib import Path
import sys

_directory = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(__name__, _directory / "learner.py")
_runtime = importlib.util.module_from_spec(_spec)
sys.modules[__name__] = _runtime
_spec.loader.exec_module(_runtime)
_runtime.CONTRACT = _directory / "feedback_contract_v1.json"
