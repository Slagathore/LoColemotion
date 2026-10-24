"""Real-ABI controls for timing, support withdrawal and unchanged fitted bytes."""
import copy
import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch

from adaptation_provider.retrieval import committed_feedback_v1 as provider
from adaptation_provider.retrieval import causal_history_v1 as history

_spec=importlib.util.spec_from_file_location("_committed_provider_template",
    Path(__file__).with_name("test_conditioned_feedback_dense_provider.py"))
_template=importlib.util.module_from_spec(_spec)
sys.modules[_spec.name]=_template
_spec.loader.exec_module(_template)
_template.provider=provider


class CommittedProviderControls(_template.ConditionedDenseProviderControls):

    def test_commitment_holds_thirty_commands_then_reconsiders(self):
        plan=self.models[0].plan()
        p={1:dict(quality_m_s=-.2),2:dict(quality_m_s=-.1)}
        for step in range(1,31):
            got=provider.choose_committed(p,1,None,plan,step,31)
            self.assertEqual(got,(1,"temporal_commitment",31,"continued"))
        self.assertEqual(provider.choose_committed(p,1,None,plan,31,31),
            (2,"current_case_retrieval",61,"expired"))
        self.assertEqual(provider.choose_committed(p,None,None,plan,1,None),
            (2,"current_case_retrieval",31,"initial"))

    def test_support_loss_terminates_before_reselection_and_default_stays_baseline(self):
        plan=self.models[0].plan()
        p={2:dict(quality_m_s=-.1)}
        self.assertEqual(provider.choose_committed(p,1,None,plan,2,31),
            (2,"current_case_retrieval",32,"support_terminated"))
        self.assertEqual(provider.choose_committed({},1,None,plan,2,31),
            (None,"no_current_case_support",None,"support_terminated"))
        self.assertEqual(provider.choose_committed(p,1,0,plan,2,31),
            (0,"complete_condition_default",None,"default"))

    def test_real_abi_holds_improving_alternative_then_expires(self):
        for core,model in zip(self.cores,self.models,strict=True):
            _,second=self.pair(core,model,"left_075_train_001","frozen")
            held=second[1]["decision"]["logical_action_index"];other=3-held
            p={held:dict(quality_m_s=-.2,support_distance=.1,case_ids=["synthetic-held"]),
                other:dict(quality_m_s=-.1,support_distance=.1,case_ids=["synthetic-other"])}
            previous=[r["applied_correction_rad_s"] for r in second[2]["ordered_commands"]]
            row=copy.deepcopy(self.rows["left_075_train_001"][2])
            with patch.object(provider.ConditionedModel,"predictions",return_value=p):
                request,call,resolved=_template.bound_call(core,model,row,"frozen",
                    second[2]["next_memory"],previous,history.empty())
            self.assertIsNone(call["provider_error"])
            self.assertEqual(call["decision"]["logical_action_index"],held)
            self.assertEqual(call["decision"]["commitment"]["event"],"continued")
            self.assertEqual(call["decision"]["commitment"]["until_step"],31)
            self.assertTrue(resolved["adaptation_applied"])
            expiry=copy.deepcopy(second[2]["next_memory"])
            expiry["sequence"]=31;expiry["opaque_state"]["last_step"]=30
            expiry["opaque_state_sha256"]=provider.learner.digest(core,expiry["opaque_state"])
            group=next(g for g in self.result["groups"] if g["group_id"]=="left_075_train_001")
            # Use the retained command and observation together; changing only
            # state time would correctly fail the resolver's command lease.
            row=copy.deepcopy(_template.retained_rows(group,32)[31])
            with patch.object(provider.ConditionedModel,"predictions",return_value=p):
                _,call,resolved=_template.bound_call(core,model,row,"frozen",expiry,previous,history.empty())
            self.assertIsNone(call["provider_error"])
            self.assertEqual(call["decision"]["logical_action_index"],other)
            self.assertEqual(call["decision"]["commitment"],dict(event="expired",until_step=61,commands=30))
            self.assertTrue(resolved["adaptation_applied"])

    def test_real_abi_support_withdrawal_clears_option_without_residual(self):
        core,model=self.cores[0],self.models[0]
        _,second=self.pair(core,model,"left_075_train_001","frozen")
        previous=[r["applied_correction_rad_s"] for r in second[2]["ordered_commands"]]
        with patch.object(provider.ConditionedModel,"predictions",return_value={}):
            request,call,resolved=_template.bound_call(core,model,self.rows["left_075_train_001"][2],
                "frozen",second[2]["next_memory"],previous,history.empty())
        self.assertIsNone(call["provider_error"]);self.assert_baseline(request,resolved)
        self.assertEqual(call["decision"]["commitment"]["event"],"support_terminated")
        self.assertIsNone(resolved["next_memory"]["opaque_state"]["committed_until_step"])
        self.assertIsNone(resolved["next_memory"]["opaque_state"]["previous_action"])

    def test_rehashed_invalid_commitment_and_crossed_legacy_memory_refuse(self):
        core,model=self.cores[0],self.models[0]
        _,second=self.pair(core,model,"left_075_train_001","frozen")
        for until in [True,1,32,-1,1.5,None]:
            memory=copy.deepcopy(second[2]["next_memory"])
            memory["opaque_state"]["committed_until_step"]=until
            memory["opaque_state_sha256"]=provider.learner.digest(core,memory["opaque_state"])
            request,call,resolved=_template.bound_call(core,model,self.rows["left_075_train_001"][2],
                "frozen",memory,[0.]*8,history.empty())
            self.assertIsNotNone(call["provider_error"]);self.assert_baseline(request,resolved)
        memory=copy.deepcopy(second[2]["next_memory"])
        memory["opaque_state"].pop("committed_until_step")
        memory["opaque_state"]["schema_version"]="locolemotion_conditioned_feedback_memory_v1"
        memory["opaque_state_sha256"]=provider.learner.digest(core,memory["opaque_state"])
        request,call,resolved=_template.bound_call(core,model,self.rows["left_075_train_001"][2],
            "frozen",memory,[0.]*8,history.empty())
        self.assertIsNotNone(call["provider_error"]);self.assert_baseline(request,resolved)

    def test_expert_refusal_clears_committed_proposal(self):
        core,model=self.cores[0],self.models[0]
        with patch.object(provider.feedback,"feedback",side_effect=ValueError("synthetic expert refusal")):
            _,second=self.pair(core,model,"left_075_train_001","frozen")
        request,call,resolved=second
        self.assertIsNone(call["provider_error"]);self.assert_baseline(request,resolved)
        self.assertEqual(call["provider_response"]["status"],"unsupported")
        for k in ["logical_action_index","proposed_action_index","candidate_index"]:
            self.assertIsNone(call["decision"][k])
        self.assertIsNone(resolved["next_memory"]["opaque_state"]["committed_until_step"])

    def test_new_model_identity_leaves_parent_frozen_artifact_unchanged(self):
        for core,model in zip(self.cores,self.models,strict=True):
            original=provider.parent.ConditionedModel.load(core)
            self.assertNotEqual(model.sha256,original.sha256)
            self.assertEqual(model.casebook.sha256,original.casebook.sha256)
            self.assertEqual(model.context_serialized,original.context_serialized)
            self.assertEqual(model.bounds_serialized,original.bounds_serialized)
            self.assertEqual(model.feedback_serialized,original.feedback_serialized)
            self.assertEqual(model.corpus_sha256,original.corpus_sha256)
            self.assertEqual(provider.WINDOW,model.plan()["decision_window_steps"])
            self.assertFalse(provider.definition()["rule"]["commitment_is_outcome_memory"])


if __name__ == "__main__": unittest.main()
