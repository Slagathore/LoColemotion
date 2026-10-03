import ctypes
import os
from pathlib import Path
import unittest

from portable_api.conformance import ConformanceError, _parse_python_ctypes_signatures
from python.sporespore_locomotion_sdk1 import LocomotionCore, legacy

SOURCE = Path(__file__).resolve().parents[1] / "python/sporespore_locomotion_sdk1.py"


class Sdk1ExtensionTests(unittest.TestCase):
    def test_conditional_signature_fields_are_required(self):
        source = SOURCE.read_text()
        self.assertEqual(len(_parse_python_ctypes_signatures(source)), 4)
        for broken in (source.replace("function.restype = ctypes.c_int", "pass"),
                       source.replace("function is not None", "False")):
            with self.assertRaises(ConformanceError):
                _parse_python_ctypes_signatures(broken)

    def test_successor_retains_legacy_inheritance(self):
        self.assertTrue(issubclass(LocomotionCore, legacy.LocomotionCore))
        self.assertIs(LocomotionCore.compile_bounded_quadruped,
                      legacy.LocomotionCore.compile_bounded_quadruped)

    def test_real_library_additions_load_and_return_typed_refusal(self):
        core = LocomotionCore(os.environ["SPORESPORE_LOCOMOTION_LIBRARY"])
        for name in _parse_python_ctypes_signatures(SOURCE.read_text()):
            function = getattr(core._library, name)
            self.assertEqual(function.restype, ctypes.c_int)
            self.assertEqual(len(function.argtypes), 5)
            method = getattr(core, name.removeprefix("ss_").removesuffix("_json"))
            with self.assertRaises(legacy.LocomotionCoreError) as caught:
                method({})
            self.assertNotEqual(caught.exception.status, legacy.SS_PANIC_CAUGHT)
            self.assertFalse(caught.exception.failure_code.startswith("ABI_"))


if __name__ == "__main__":
    unittest.main(verbosity=2)
