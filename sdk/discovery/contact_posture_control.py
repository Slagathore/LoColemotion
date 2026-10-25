"""Successor hold host with a reach-aware policy and unchanged public resolver."""
from recovery_hold_control import HoldForceController
from residual_recovery_control import RecoveryController
from contact_posture_force_policy import Policy
from actuation_recovery_mechanics import require


class ContactPostureController(HoldForceController):
    def __init__(self,core,compiled,contract,model,episode_id,profile):
        self.force_policy=Policy(core,profile)
        require(compiled["morphology"]["morphology_spec"]==profile["morphology_spec"]
            and compiled["descriptor"]==profile["descriptor"],"Reach host morphology binding")
        RecoveryController.__init__(self,core,compiled,contract,model,"early_selected",episode_id)
        self.force_memory=None
