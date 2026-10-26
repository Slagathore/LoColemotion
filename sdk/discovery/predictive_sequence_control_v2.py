"""Predictive policy with inherited public resolution and actual history.

The prefix remains unchanged. Refusal or any difference between the selected
target and the core-resolved target closes the host before native transfer.
"""
from hierarchical_hold_control_v8 import HierarchicalHoldController,terminal_error
from residual_recovery_control import RecoveryController
from predictive_sequence_policy_v2 import Policy,HANDOFF
from actuation_recovery_mechanics import require


class PredictiveSequenceController(HierarchicalHoldController):
    def __init__(self,core,compiled,contract,model,episode_id,profile,kernel_path):
        self.force_policy=Policy(core,profile,kernel_path)
        require(compiled["morphology"]["morphology_spec"]==profile["prepared_model"]["morphology_spec"]
            and compiled["descriptor"]==profile["nominal_profile"]["descriptor"],"Predictive host morphology binding")
        RecoveryController.__init__(self,core,compiled,contract,model,"early_selected",episode_id)
        self.force_memory=None

    def step(self,state,stability,kinematics):
        try:
            row=super().step(state,stability,kinematics)
            if state["semantic_step"]<HANDOFF:return row
            reference=row["force_reference"];decision=reference["decision"]
            if reference["terminal_error"] is None:
                selected=decision["selection"]
                actual=[c["final_canonical_target_velocity_rad_s"] for c in row["resolution"]["ordered_commands"]]
                corrections=[c["applied_correction_rad_s"] for c in row["resolution"]["ordered_commands"]]
                if actual!=selected["selected_target"] or corrections!=selected["selected_correction"]:
                    error=dict(type="PredictiveResolutionMismatch",message="Selected prediction differs from final public command")
                    reference.update(terminal_error=error,provider_error=error)
                    self.close()
            row["recovery_hold"]["actual_resolved_history_continues"]=reference["history_boundary"] is None
            row["predictive_sequence"]=dict(profile_sha256=self.force_policy.sha,
                prepared_model_sha256=self.force_policy.prepared_sha,
                selected_prediction_matches_final_public_command=reference["terminal_error"] is None,
                nominal_prediction_applies_to_transfer=False,
                actual_resolved_history_continues=reference["history_boundary"] is None,total_target_slew_guaranteed=False,
                physical_acceptance_authority=False)
            return row
        except BaseException:
            self.close();raise


def transfer_targets(row,data):
    require(terminal_error(row) is None,"Predictive terminal provider failure")
    data.ctrl[:]=row["native_targets"]
