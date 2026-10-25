"""Fixed command-60 handoff to force recovery with coherent hold input.

The inherited challenge prefix and public command limits are unchanged.
The force policy uses a contact-first hierarchy with retained refusals. Residual
slew bounds corrections; it does not certify total target slew at the handoff.
"""
from adaptation_provider.retrieval import causal_history_v1 as history
from residual_recovery_control import RecoveryController
from portable_search_control import bridge, map_resolution, proposal_request
from hierarchical_force_policy_v3 import Policy,HANDOFF
from actuation_recovery_mechanics import require
from recovery_hold_composition import hold_motion_command,compose_recovery_step


class HierarchicalHoldController(RecoveryController):
    def __init__(self,core,compiled,contract,model,episode_id,profile):
        # Construct/validate the pure force policy before opening a core session.
        self.force_policy=Policy(core,profile)
        require(compiled["morphology"]["morphology_spec"]==profile["morphology_spec"]
            and compiled["descriptor"]==profile["descriptor"],"Force host morphology binding")
        super().__init__(core,compiled,contract,model,"early_selected",episode_id)
        self.force_memory=None

    def step(self,state,stability,kinematics):
        if self.next_step<HANDOFF:return super().step(state,stability,kinematics)
        try:
            require(not self.closed and type(state["semantic_step"]) is int
                and state["semantic_step"]==self.next_step,"Force host lifecycle/clock")
            step=self.next_step;command=hold_motion_command(step,self.c["phase_mode"])
            request=dict(memory=self.memory,state=state,command=command)
            limbs=bridge._ordered_limb_steps(self.memory,self.context.morphology["ordered_limb_ids"])
            output=self.session.step(request);actuation=output["actuation"]
            require(actuation["receipt"]["controller_error"] is None and not actuation["failure_codes"],
                "Force baseline refused")
            composition=compose_recovery_step(self.context,actuation,stability,kinematics,limbs,self.composition_memory,command)
            memory=self.force_policy.memory(self.episode_id) if self.force_memory is None else self.force_memory
            proposed=proposal_request(self.core,self.c,self.candidate,state,command,output,
                composition["canonical_actuation"],memory,self.previous)
            proposed=history.attach(self.force_policy.bind(proposed,stability,memory,self.episode_id),self.history)
            response=None;decision=None;error=None
            try:response,decision=self.force_policy.respond(proposed)
            except Exception as exc:
                error=dict(type=type(exc).__name__,message=str(exc));decision=getattr(exc,"decision",None)
            resolution_request=dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=proposed,provider_response=response)
            resolved=self.core.resolve_adaptation_v1(resolution_request)
            targets=map_resolution(composition["host_mapping"],resolved)
            following,boundary=history.append_resolved(self.core,proposed,resolved)
            if error is None and (boundary is not None or resolved["provider_status"] not in ("applied","no_proposal")):
                error=dict(type="ForceResolutionRefused",message=str(resolved["fallback_reason"]))
            following["ordered_entries"]=following["ordered_entries"][-1:]
            self.memory,self.force_memory=output["next_memory"],resolved["next_memory"]
            self.previous=[r["applied_correction_rad_s"] for r in resolved["ordered_commands"]]
            self.history,self.next_step=following,step+1
            row=dict(request=request,output=output,stability=stability,kinematics=kinematics,
                composition=composition,resolution_request=resolution_request,resolution=resolved,native_targets=targets,
                force_reference=dict(episode_id=self.episode_id,handoff_command=HANDOFF,
                    prefix_model_sha256=self.model.sha256,profile_sha256=self.force_policy.sha,
                    decision=decision,provider_error=error,terminal_error=error,history_boundary=boundary,
                    ongoing_history_entries=len(following["ordered_entries"])))
            row["recovery_hold"]=dict(handoff_command=HANDOFF,motion_command_sha256=self.core.canonicalize_json(command)["sha256"],
                gait_amplitude=0.0,actual_resolved_history_continues=True,total_target_slew_guaranteed=False)
            if error is not None:self.close()
            return row
        except BaseException:
            self.close();raise


def terminal_error(row):
    return row["force_reference"]["terminal_error"] if "force_reference" in row else row["residual"]["terminal_error"]
