"""Six controls bind the retained shadow warning result without new fitting."""
import copy
import os
from pathlib import Path
import unittest

import audit_residual_warning_closure as closure
from gpu_measurement_probe import write_new


class WarningClosureControls(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.expected=closure.expected()
        cls.record=closure.read(closure.CLOSURE)
        cls.owner=closure.read(closure.ROOT.parent/"SporeSpore_Evidence"/closure.ATTEMPT/"receipt.json")

    def test_complete_retained_closure(self):
        self.assertTrue(closure.validate(self.record,self.expected))
        write_new(Path(os.environ["EXPLORER_TEST_OUTPUT"])/"complete-binding-check.json",
            dict(ok=True,closure_sha256=closure.sha(closure.CLOSURE),attempt_id=closure.ATTEMPT,
                receipt_sha256=closure.RECEIPT_SHA,artifacts=self.record["retained_artifact_count"],
                original_training_episodes=64,worlds_opened=0,solver_steps=0,
                fitting_repeated=False,controller_replay_repeated=False))

    def test_owner_authority_and_completion_mutations(self):
        for key,value in (("ok",False),("source_runtime_unchanged",False),("worlds_opened",1),
                          ("physical_started",True),("automatic_withdrawal_authority",True),
                          ("controls_passed",19),("reader_corruption_controls_passed",7),
                          ("planned_training_episodes",63),("source_commit","0"*40)):
            changed=copy.deepcopy(self.owner);changed[key]=value
            with self.assertRaises(ValueError):closure.validate_owner(changed)

    def test_recipe_model_receipt_and_source_bindings(self):
        for key in ("definition_sha256","recipe_sha256","receipt_sha256","audit_sha256",
                    "fit_sha256","final_model_sha256","dataset_sha256","source_base_commit"):
            changed=copy.deepcopy(self.record);changed[key]="0"*64
            with self.assertRaises(ValueError):closure.validate(changed,self.expected)

    def test_denominators_and_original_negatives_cannot_disappear(self):
        for key in ("training_trial_count","eligible_episodes","failed_episodes","controller_rows",
                    "internal_rows","retained_artifact_count","retained_artifact_bytes"):
            changed=copy.deepcopy(self.record);changed[key]-=1
            with self.assertRaises(ValueError):closure.validate(changed,self.expected)
        changed=copy.deepcopy(self.record);changed["row_categories"]["already_failed"]-=1
        with self.assertRaises(ValueError):closure.validate(changed,self.expected)

    def test_warning_metrics_and_threshold_cannot_be_regraded(self):
        for section in ("crossfit_tuned_threshold_diagnostics","full_fit_diagnostics"):
            changed=copy.deepcopy(self.record);changed[section]["known_negative_warning_commands"]+=1
            with self.assertRaises(ValueError):closure.validate(changed,self.expected)
        changed=copy.deepcopy(self.record);changed["threshold"]+=.01
        with self.assertRaises(ValueError):closure.validate(changed,self.expected)

    def test_no_calibration_safety_reserved_or_release_promotion(self):
        for key in ("warning_score_is_probability","threshold_has_independent_validation",
                    "safe_backup_established","automatic_withdrawal_authority",
                    "physical_acceptance_authority","tier2_complete","tier3_complete","release_authority"):
            changed=copy.deepcopy(self.record);changed[key]=True
            with self.assertRaises(ValueError):closure.validate(changed,self.expected)
        changed=copy.deepcopy(self.record);changed["reserved_starts_opened"]=4
        with self.assertRaises(ValueError):closure.validate(changed,self.expected)


if __name__=="__main__":unittest.main()
