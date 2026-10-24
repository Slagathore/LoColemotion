"""Bind the unchanged selector to the distinct command-resolution casebook."""
import importlib.util
from pathlib import Path
import sys
from . import feedback_dense_v1

_directory = Path(__file__).resolve().parent
_spec = importlib.util.spec_from_file_location(__name__,_directory/"conditioned_feedback_v1.py")
_runtime = importlib.util.module_from_spec(_spec)
sys.modules[__name__] = _runtime
_spec.loader.exec_module(_runtime)
_runtime.learner = feedback_dense_v1
_runtime.CONTRACT = _directory/"conditioned_feedback_v2.json"
_runtime.FIT_RECORD = _runtime.ROOT/"sdk/discovery/command_resolution_repertoire_closure_v1.json"
_runtime.FIT_SHA = "19fa595e36719c287f2985298d062e7ce89e25a12f41654c4c46655f7231c7bb"
_runtime.CASEBOOK_SHA = "sha256:bcf801782709a33d9e5b398770ad606029c33b1067b2bf7a3bac9a9ecba233cb"
_runtime.CASE_COUNT = 21165
_runtime.PROVIDER_SCHEMA = "locolemotion_conditioned_feedback_provider_v2"
