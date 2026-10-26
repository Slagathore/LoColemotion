"""Successor provider behind the unchanged public sequence host and transfer guard."""
from predictive_sequence_control_v2 import PredictiveSequenceController as ParentController,terminal_error,transfer_targets
from predictive_sequence_policy_v3 import Policy
from residual_recovery_control import RecoveryController
from actuation_recovery_mechanics import require


class PredictiveSequenceController(ParentController):
    def __init__(self,core,compiled,contract,model,episode_id,profile,kernel_path):
        self.force_policy=Policy(core,profile,kernel_path)
        require(compiled["morphology"]["morphology_spec"]==profile["prepared_model"]["morphology_spec"]
            and compiled["descriptor"]==profile["nominal_profile"]["descriptor"],"Sequence successor host morphology")
        RecoveryController.__init__(self,core,compiled,contract,model,"early_selected",episode_id)
        self.force_memory=None
