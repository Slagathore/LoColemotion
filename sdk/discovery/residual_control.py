"""Production controller composition with immutable residuals and ongoing history."""
import copy

from adaptation_provider import bounded_residual_provider_v1 as provider
from adaptation_provider.retrieval import causal_history_v1 as history
from portable_search_control import Controller,bridge,map_resolution,proposal_request

require=provider.require
KIND="bounded_residual_policy_v1"


def expected_provider(model):
    return dict(kind=KIND,model_sha256=model.sha256,definition=provider.definition(),
        maximum_absolute_correction_rad_s=3.5,maximum_slew_per_step_rad_s=.08)


class ResidualController(Controller):
    def __init__(self,core,compiled,contract,model,mode,episode_id):
        require(mode in provider.MODES and contract["provider"]==expected_provider(model),
                "Residual host declaration/model")
        require(compiled["descriptor"]==provider.features.DESCRIPTOR,"Residual host morphology")
        bound=dict(contract,provider=dict(contract["provider"],candidates=[dict(id=model.model_id,factor=None)]))
        super().__init__(core,compiled,bound,0)
        try:
            self.model,self.mode,self.episode_id=model,mode,episode_id
            self.provider_memory=provider.empty_memory(core,model,mode,contract["seed"],episode_id)
            self.history,self.next_step,self.closed=history.empty(),0,False
        except BaseException:
            super().close()
            raise

    def close(self):
        if not self.closed:
            super().close();self.closed=True

    def step(self,state,stability,kinematics):
        try:
            require(not self.closed and type(state["semantic_step"]) is int
                    and state["semantic_step"]==self.next_step,"Residual host lifecycle/clock")
            step=self.next_step
            command=bridge._motion_command(step,self.c["phase_mode"])
            request=dict(memory=self.memory,state=state,command=command)
            limbs=bridge._ordered_limb_steps(self.memory,self.context.morphology["ordered_limb_ids"])
            output=self.session.step(request);actuation=output["actuation"]
            require(actuation["receipt"]["controller_error"] is None and not actuation["failure_codes"],
                    "Residual baseline refused")
            composition=bridge.compose_bw19v_step(self.context,actuation,stability,kinematics,limbs,self.composition_memory)
            proposed=proposal_request(self.core,self.c,self.candidate,state,command,output,
                composition["canonical_actuation"],self.provider_memory,self.previous)
            proposed=provider.bind_request(self.core,proposed,self.model,self.mode,
                self.provider_memory,self.previous,self.episode_id)
            proposed=history.attach(proposed,self.history)
            called=provider.call_provider(self.core,proposed,self.model,self.mode)
            resolution_request=dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=proposed,provider_response=called["provider_response"])
            resolved=self.core.resolve_adaptation_v1(resolution_request)
            targets=map_resolution(composition["host_mapping"],resolved)
            following,boundary=history.append_resolved(self.core,proposed,resolved)
            # v1 has no status for an absent or invalid provider. Keep that
            # original receipt and the empty history; never invent a status.
            expected_absence=(self.mode=="absent" and called["provider_error"] is None
                and resolved["fallback_reason"] in ("provider_absent","safe_no_actuation"))
            terminal_error=called["provider_error"]
            if boundary is not None and not expected_absence and terminal_error is None:
                terminal_error=dict(type="UnrepresentableResolution",
                    message="Residual history cannot represent the actual resolution")
            # This policy needs only the latest resolved command/observation.
            # Append through the shared validator, then retain that exact entry.
            following["ordered_entries"]=following["ordered_entries"][-1:]
            self.memory,self.provider_memory=output["next_memory"],resolved["next_memory"]
            self.previous=[r["applied_correction_rad_s"] for r in resolved["ordered_commands"]]
            self.history,self.next_step=following,step+1
            row=dict(request=request,output=output,stability=stability,kinematics=kinematics,
                composition=composition,resolution_request=resolution_request,resolution=resolved,
                native_targets=targets,residual=dict(mode=self.mode,episode_id=self.episode_id,
                    model_sha256=self.model.sha256,decision=called["decision"],
                    provider_error=called["provider_error"],terminal_error=terminal_error,history_boundary=boundary,
                    ongoing_history_entries=len(following["ordered_entries"])))
            # A malformed provider produces the core's baseline receipt, but
            # ends this host instance. A native worker must retain the row and
            # reject terminal_error before transferring another solver input.
            if terminal_error is not None:self.close()
            return row
        except BaseException:
            self.close()
            raise
