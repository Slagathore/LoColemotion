"""Fast real-host interface checks; all outputs are disposable test fixtures."""
import json
import hashlib
import math
from pathlib import Path
import random
import struct
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
sys.path.insert(0, str(ROOT / 'sdk/publication'))
from historical_source import read_blob
import qsdk_r10f_l15_retained_integrity_failure as frozen_failure


class ExactJsonTransport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        frozen_failure.verify_population(frozen_failure.EVIDENCE, frozen_failure.inventory())
        cls.same = staticmethod(frozen_failure.frozen_functions(
            read_blob(frozen_failure.SOURCE, frozen_failure.RETENTION))['same'])

    def host(self, payload, *arguments, success=True):
        result = subprocess.run([
            'C:/Program Files/PowerShell/7/pwsh.exe', '-NoLogo', '-NoProfile', '-NonInteractive',
            '-File', str(ROOT / 'tests/test_exact_json_transport.ps1'), *arguments],
            input=payload, cwd=ROOT, text=True, encoding='utf-8',
            capture_output=True, timeout=90, creationflags=subprocess.CREATE_NO_WINDOW)
        if success:
            self.assertEqual(0, result.returncode, result.stderr[:2000])
            self.assertEqual('', result.stderr)
        return result

    def test_portable_float_edges_types_unicode_and_empty_values(self):
        value = dict(numbers=[2.9802322387695312e-08, 0.0, -0.0, 1.0, -1.0,
                              5e-324, 1.7976931348623157e308, 0.1, 9007199254740992.0],
                     integers=[0, -1, 2**63-1, 2**64-1, 2**80],
                     nested=[None, True, False, [], {}, ['a', '"\\\n\t', '🌱…日本語']],
                     timestamp='2026-09-07T12:30:40.8204496Z')
        raw = json.dumps(value, ensure_ascii=False, allow_nan=False)
        for args in ((), ('-Indented',)):
            with self.subTest(args=args):
                self.assertTrue(self.same(value, json.loads(self.host(raw, *args).stdout)))
        # A surrogate pair straddles the prospective 1 Mi-character boundary;
        # quotes, slashes, controls and Unicode must survive the same real host.
        text = 'a' * (1024 * 1024 - 1) + '🌱"\\\n\t日本語' + 'z' * (1024 * 1024)
        self.assertEqual(text, json.loads(self.host(json.dumps(text)).stdout))

    def test_deterministic_random_binary64_population(self):
        generator = random.Random(17315)
        values = []
        while len(values) < 2048:
            value = struct.unpack('>d', generator.getrandbits(64).to_bytes(8, 'big'))[0]
            if math.isfinite(value): values.append(value)
        self.assertTrue(self.same(values, json.loads(self.host(json.dumps(values)).stdout)))

    def test_real_production_writer_preserves_whole_original_l15_reports(self):
        for role in frozen_failure.ROLES:
            child = frozen_failure.EVIDENCE / 'children' / role
            original = next(line[len(frozen_failure.RAW_MARKER):] for line in
                            (child/'worker.stdout.txt').read_text(encoding='utf-8').splitlines()
                            if line.startswith(frozen_failure.RAW_MARKER))
            with self.subTest(role=role), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)/'report.json'
                self.host(original, '-Mode', 'ProductionWrite', '-OutputPath', str(output))
                self.assertTrue(self.same(json.loads(original), json.loads(output.read_text(encoding='utf-8'))))
                before = output.read_bytes()
                refused = self.host(original, '-Mode', 'ProductionWrite', '-OutputPath', str(output), success=False)
                self.assertNotEqual(0, refused.returncode)
                self.assertEqual(before, output.read_bytes())
        # Real 182 MB stdout crossed the host's single-token writer limit.
        # Exercise the actual production writer at that size before physics.
        source = ROOT.parent / 'SporeSpore_Evidence/development-recovery-smoke-f3761195cea64b7c9b58a34f04651173/children/kick_passive_recovery_resume/worker.stdout.txt'
        expected = '108a1ba034c848db8015446c547af362f54635c6d47ed5d01e7342b1ee79a7e1'
        self.assertEqual(expected, hashlib.sha256(source.read_bytes()).hexdigest())
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'termination-shaped.json'
            self.host('', '-Mode', 'SourceStringWrite', '-InputPath', str(source), '-OutputPath', str(output))
            result = json.loads(output.read_text(encoding='utf-8'))
            self.assertEqual(expected, hashlib.sha256(result['stdout'].encode()).hexdigest())
            self.assertEqual(182106256, len(result['stdout'].encode()))
            self.assertFalse(result['physical_acceptance_authority'])
            self.assertFalse(result['release_authority'])
        self.assertEqual(expected, hashlib.sha256(source.read_bytes()).hexdigest())

    def test_actual_writer_and_publisher_are_single_output_and_equal(self):
        value = dict(measurement=2.9802322387695312e-08, integral_float=1.0, negative_zero=-0.0,
                     authority=False, nested=dict(values=[False, None, 'source']))
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)/'supervisor_result.json'
            result = self.host(json.dumps(value), '-Mode', 'ProductionPublish', '-OutputPath', str(output))
            prefix = 'DEVELOPMENT_INTERFACE_PUBLICATION '
            self.assertEqual(1, len(result.stdout.splitlines()))
            self.assertTrue(result.stdout.startswith(prefix))
            self.assertTrue(self.same(value, json.loads(result.stdout[len(prefix):])))
            self.assertTrue(self.same(value, json.loads(output.read_text(encoding='utf-8'))))

    def test_nonfinite_unsupported_types_invalid_text_and_cycles_refuse(self):
        self.assertEqual('EXACT_JSON_REFUSALS_PASS 8', self.host('', '-Mode', 'Refusals').stdout.strip())


if __name__ == '__main__':
    unittest.main()
