"""Dynamic recovery host with the unchanged prefix and public resolver."""
from recovery_hold_control import HoldForceController
from residual_recovery_control import RecoveryController
from dynamic_force_policy_v2 import Policy
from actuation_recovery_mechanics import require


class DynamicHoldController(HoldForceController):
    def __init__(self,core,compiled,contract,model,episode_id,profile):
        self.force_policy=Policy(core,profile)
        require(compiled["morphology"]["morphology_spec"]==profile["morphology_spec"]
            and compiled["descriptor"]==profile["descriptor"],"Dynamic host morphology binding")
        RecoveryController.__init__(self,core,compiled,contract,model,"early_selected",episode_id)
        self.force_memory=None
