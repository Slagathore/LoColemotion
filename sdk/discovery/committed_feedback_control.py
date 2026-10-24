"""Compare current and committed selection through the same production host."""
import copy
import importlib.util
from pathlib import Path
import sys

from adaptation_provider.retrieval import committed_feedback_v1 as provider
import conditioned_feedback_dense_control as current

require = provider.require
PROVIDER_KIND = "committed_feedback_comparison_v1"
COMMITTED_HOST_KIND = "committed_feedback_selection_v1"
MODEL_SHA = "sha256:2b41a1b8c48b8157a077ba98398c1ca8332aa079bbfa394516f385d82c23fd11"
CURRENT_MODEL_SHA = "sha256:8cc55e0017e01a1f7d188a74bcd7729acdcc0ef9e65fa2916d6a3bc96f0c1a96"
ROLES = [
    dict(id="baseline",mode="baseline",implementation="committed",delegate_role_index=0,fixed_candidate_index=0),
    dict(id="disabled",mode="disabled",implementation="committed",delegate_role_index=1,fixed_candidate_index=None),
    dict(id="current_frozen",mode="frozen",implementation="current",delegate_role_index=2,fixed_candidate_index=None),
    dict(id="current_shuffled",mode="shuffled",implementation="current",delegate_role_index=3,fixed_candidate_index=None),
    dict(id="committed_frozen",mode="frozen",implementation="committed",delegate_role_index=2,fixed_candidate_index=None),
    dict(id="committed_shuffled",mode="shuffled",implementation="committed",delegate_role_index=3,fixed_candidate_index=None)]

# A private module instance binds the unchanged host mechanics to the distinct
# provider. The original sparse and dense host modules remain independently usable.
_spec=importlib.util.spec_from_file_location("_committed_feedback_host",
    Path(__file__).with_name("conditioned_feedback_control.py"))
_committed=importlib.util.module_from_spec(_spec)
sys.modules[_spec.name]=_committed
_spec.loader.exec_module(_committed)
_committed.provider=provider
_committed.require=require
_committed.PROVIDER_KIND=COMMITTED_HOST_KIND


def expected_provider():
    return dict(kind=PROVIDER_KIND,model_sha256=MODEL_SHA,definition=provider.definition(),
        current_model_sha256=CURRENT_MODEL_SHA,current_definition=current.provider.definition())


def role_contract(contract, role, model):
    committed=role["implementation"]=="committed"
    require(model.sha256==(MODEL_SHA if committed else CURRENT_MODEL_SHA),
        "Committed comparison role/model crossing")
    return dict(contract,provider=dict(kind=COMMITTED_HOST_KIND if committed else current.PROVIDER_KIND,
        model_sha256=model.sha256,definition=provider.definition() if committed else current.provider.definition()))


class CommittedFeedbackController:
    def __init__(self,core,compiled,contract,role_index,model=None):
        require(type(role_index) is int and 0<=role_index<len(ROLES),"Committed comparison host role")
        require(contract["provider"]==expected_provider(),"Committed comparison definition/model")
        committed_model=provider.ConditionedModel.load(core) if model is None else model
        require(isinstance(committed_model,provider.ConditionedModel) and committed_model.sha256==MODEL_SHA,
            "Committed comparison model identity")
        self.role=copy.deepcopy(ROLES[role_index])
        self.mode=self.role["mode"]
        self.model=(current.provider.ConditionedModel.load(core)
            if self.role["implementation"]=="current" else committed_model)
        runtime=current if self.role["implementation"]=="current" else _committed
        self.delegate=runtime.ConditionedFeedbackController(core,compiled,
            role_contract(contract,self.role,self.model),self.role["delegate_role_index"],self.model)

    @property
    def closed(self):
        return self.delegate.closed

    def close(self):
        self.delegate.close()

    def step(self,state,stability,kinematics):
        row=self.delegate.step(state,stability,kinematics)
        row["selection"]["role"]=copy.deepcopy(self.role)
        return row
