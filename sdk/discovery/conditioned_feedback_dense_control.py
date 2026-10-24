"""Separate host binding for the dense frozen provider; sparse host stays usable."""
import importlib.util
from pathlib import Path
import sys
from adaptation_provider.retrieval import conditioned_feedback_v2

_spec = importlib.util.spec_from_file_location(__name__,Path(__file__).with_name("conditioned_feedback_control.py"))
_runtime = importlib.util.module_from_spec(_spec)
sys.modules[__name__] = _runtime
_spec.loader.exec_module(_runtime)
_runtime.provider = conditioned_feedback_v2
_runtime.require = conditioned_feedback_v2.require
_runtime.PROVIDER_KIND = "conditioned_feedback_selection_v2"
