"""The public entry point changes transport identity, never audit authority."""
import copy
import json
import unittest
from unittest import mock

import check_licensing
from check_licensing import (AGPL_TEXT, CONTRACT, LEGACY, current_negative_controls, pinned_checker,
                             validate_public_contract)


class LicensingEntryControls(unittest.TestCase):
    def test_only_the_expected_remote_changes(self):
        checker = pinned_checker()
        self.assertEqual(checker.REMOTE, "https://github.com/Slagathore/LoColemotion.git")
        self.assertEqual(checker.ROOT / "sdk/release/licensing/check_licensing.py", LEGACY)
        # The legacy contract still measures the legacy file's actual bytes.
        self.assertEqual(checker.binding(LEGACY)["path"], "sdk/release/licensing/check_licensing.py")
        self.assertIn("sdk/release/licensing/check_licensing.py", checker.SOURCE_PATHS)
        self.assertTrue(callable(checker.validate))
        self.assertTrue(callable(checker.negative_controls))

    def test_current_scope_cannot_include_reserved_material(self):
        value = json.loads(CONTRACT.read_bytes())
        value["covered_directories"].append("docs/")
        with self.assertRaisesRegex(ValueError, "CURRENT_SCOPE"):
            validate_public_contract(value)

    def test_current_check_cannot_claim_qualification(self):
        value = json.loads(CONTRACT.read_bytes())
        value["authority"]["sdk1_qualification"] = True
        with self.assertRaisesRegex(ValueError, "CURRENT_AUTHORITY"):
            validate_public_contract(value)

    def test_current_authority_must_use_literal_false_values(self):
        value = json.loads(CONTRACT.read_bytes())
        value["authority"]["sdk1_qualification"] = 0
        with self.assertRaisesRegex(ValueError, "CURRENT_AUTHORITY"):
            validate_public_contract(value)

    def test_current_ledger_cannot_be_promoted(self):
        value = json.loads(CONTRACT.read_bytes())
        value["ledger_scope"]["authority_mode"] = "official_qualification"
        with self.assertRaisesRegex(ValueError, "CURRENT_LEDGER"):
            validate_public_contract(value)

    def test_missing_and_forged_source_bindings_refuse(self):
        value = json.loads(CONTRACT.read_bytes())
        changed = copy.deepcopy(value); changed["source_pins"].pop()
        with self.assertRaisesRegex(ValueError, "CURRENT_PIN_POPULATION"):
            validate_public_contract(changed)
        changed = copy.deepcopy(value)
        changed["source_pins"][0]["exact_byte_variants"] = [{"byte_length": 1, "sha256": "sha256:" + "0" * 64}]
        with self.assertRaisesRegex(ValueError, "CURRENT_PIN_IDENTITY"):
            validate_public_contract(changed)

    def test_revenue_cap_cannot_return(self):
        value = json.loads(CONTRACT.read_bytes())
        value["policy"]["revenue_cap_usd"] = 100000
        with self.assertRaisesRegex(ValueError, "CURRENT_POLICY"):
            validate_public_contract(value)

    def test_public_license_must_stay_the_gnu_text(self):
        value = json.loads(CONTRACT.read_bytes())
        self.assertIn(AGPL_TEXT, {row["path"] for row in value["source_pins"]})
        with mock.patch.object(check_licensing, "AGPL_LF_SHA256", "sha256:" + "0" * 64):
            with self.assertRaisesRegex(ValueError, "CURRENT_PUBLIC_LICENSE_TEXT"):
                validate_public_contract(value)

    def test_superseded_declaration_cannot_be_revived(self):
        value = json.loads(CONTRACT.read_bytes())
        value["predecessor"]["status"] = "current"
        with self.assertRaisesRegex(ValueError, "CURRENT_PREDECESSOR"):
            validate_public_contract(value)

    def test_every_current_corruption_refuses(self):
        passed = current_negative_controls(json.loads(CONTRACT.read_bytes()))
        self.assertEqual(len(passed), 8)


if __name__ == "__main__":
    unittest.main()
