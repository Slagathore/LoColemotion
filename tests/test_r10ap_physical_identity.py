"""Real catalog exclusion, independent of isolated reservation-test namespaces."""
import copy
from pathlib import Path
import sys
import unittest
from unittest import mock
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'sdk/conformance'))
import r10ap_physical_identity as identity
import r10ap_report_fixtures as fixtures


class PhysicalIdentity(unittest.TestCase):
    def test_every_real_fixture_id_refused_after_flag_removal(self):
        population = []
        for _, catalog in fixtures.catalogs():
            for case in catalog['cases'].values():
                declaration = copy.deepcopy(case['declaration'])
                population.append(declaration['attempt_id'])
                del declaration['report_fixture_only']
                with self.subTest(attempt=declaration['attempt_id']):
                    with self.assertRaisesRegex(ValueError, 'RESERVED_FIXTURE_ID'):
                        identity.require_physical_declaration(declaration)
        self.assertGreaterEqual(len(population), 13)
        self.assertEqual(len(population), len(set(population)))

    def test_fixture_flag_cannot_be_relabelled_false_or_numeric(self):
        for flag in (True, False, 0, 1, None, 'false'):
            with self.subTest(flag=flag), self.assertRaisesRegex(ValueError, 'SYNTHETIC_DECLARATION'):
                identity.require_physical_declaration(dict(attempt_id=uuid.uuid4().hex, report_fixture_only=flag))

    def test_invalid_catalog_refuses_instead_of_treating_id_as_fresh(self):
        with mock.patch.object(fixtures, 'reserved_for_fixture', side_effect=AssertionError('damaged catalog')):
            with self.assertRaisesRegex(ValueError, 'FIXTURE_CATALOG_INVALID'):
                identity.require_physical_declaration(dict(attempt_id=uuid.uuid4().hex))

    def test_malformed_identity_refuses(self):
        for value in (None, [], {}, dict(attempt_id=True), dict(attempt_id='a'*31), dict(attempt_id='A'*32)):
            with self.subTest(value=value), self.assertRaises(ValueError):
                identity.require_physical_declaration(value)

    def test_fresh_identity_filter_grants_no_authority_or_reservation(self):
        before = {p: p.read_bytes() for p in fixtures.EVIDENCE.glob('r10ap*consumption*.json')}
        value = dict(attempt_id=uuid.uuid4().hex)
        self.assertIsNone(identity.require_physical_declaration(value))
        self.assertEqual({'attempt_id'}, set(value))
        self.assertEqual(before, {p: p.read_bytes() for p in fixtures.EVIDENCE.glob('r10ap*consumption*.json')})


if __name__ == '__main__':
    unittest.main()
