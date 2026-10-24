"""Live frozen selection with actual first-response history and private context."""
import copy

from adaptation_provider.retrieval import conditioned_feedback_v1 as provider
from adaptation_provider.retrieval import causal_history_v1 as history
from portable_search_control import Controller, bridge, map_resolution, proposal_request
from context_probe_control import no_proposal
from phase_release_control import PhaseReleaseController

require = provider.require
PROVIDER_KIND = "conditioned_feedback_selection_v1"
ROLES = [dict(id="baseline",mode="baseline",fixed_candidate_index=0),
    dict(id="disabled",mode="disabled",fixed_candidate_index=None),
    dict(id="frozen",mode="frozen",fixed_candidate_index=None),
    dict(id="shuffled",mode="shuffled",fixed_candidate_index=None),
    dict(id="phase_reference",mode="phase_reference",fixed_candidate_index=4)]


class ConditionedFeedbackController(Controller):
    def __init__(self, core, compiled, contract, role_index, model=None):
        require(type(role_index) is int and 0 <= role_index < len(ROLES), "Conditioned host role")
        self.role = copy.deepcopy(ROLES[role_index]); self.mode = self.role["mode"]
        self.model = provider.ConditionedModel.load(core) if model is None else model
        family = provider.feedback.definition()
        provider.feedback.validate_geometry(compiled,family)
        require(contract["provider"]["kind"] == PROVIDER_KIND
            and contract["provider"]["model_sha256"] == self.model.sha256
            and contract["provider"]["definition"] == provider.definition(), "Conditioned host frozen model")
        native_provider = dict(kind="untrained_phase_release_feedback_v1",candidates=family["candidates"],
            envelope_selection=family["envelope_selection"],ground_domain=family["ground_domain"])
        self.reference = None
        if self.mode == "phase_reference":
            self.reference = PhaseReleaseController(core,compiled,dict(contract,provider=native_provider),2)
        else:
            bound = dict(contract,provider=dict(native_provider,maximum_absolute_correction_rad_s=3.5,maximum_slew_per_step_rad_s=.08))
            super().__init__(core,compiled,bound,0)
            self.provider_memory = provider.empty_memory(core,self.model)
        self.next_step, self.closed, self.history = 0, False, history.empty()

    def close(self):
        if not self.closed:
            if self.reference is not None:self.reference.close()
            else:super().close()
            self.closed = True

    def step(self, state, stability, kinematics):
        require(not self.closed and type(state["semantic_step"]) is int
            and state["semantic_step"] == self.next_step, "Conditioned host lifecycle/clock")
        try:
            step = self.next_step
            if self.reference is not None:
                row = self.reference.step(state,stability,kinematics)
                row["selection"] = dict(role=self.role,decision=None,provider_error=None,history_boundary=None,learned_selection=False)
                self.next_step += 1
                return row
            command = bridge._motion_command(step,self.c["phase_mode"])
            request = dict(memory=self.memory,state=state,command=command)
            limbs = bridge._ordered_limb_steps(self.memory,self.context.morphology["ordered_limb_ids"])
            output = self.session.step(request)
            actuation = output["actuation"]
            require(actuation["receipt"]["controller_error"] is None and not actuation["failure_codes"], "Conditioned host baseline refusal")
            composition = bridge.compose_bw19v_step(self.context,actuation,stability,kinematics,limbs,self.composition_memory)
            proposed = proposal_request(self.core,self.c,self.candidate,state,command,output,
                composition["canonical_actuation"],self.provider_memory,self.previous)
            proposed = provider.bind_request(self.core,proposed,self.model,self.mode,self.provider_memory,self.previous)
            proposed = history.attach(proposed,self.history if step <= 1 else history.empty())
            if self.mode == "baseline":
                called = dict(provider_response=no_proposal(self.core,proposed),decision=None,provider_error=None)
            else:
                called = provider.call_provider(self.core,proposed,self.model,self.mode)
            resolution_request = dict(schema_version="sporespore_adaptation_resolution_request_v1",
                provider_request=proposed,provider_response=called["provider_response"])
            resolved = self.core.resolve_adaptation_v1(resolution_request)
            targets = map_resolution(composition["host_mapping"],resolved)
            # The frozen estimator consumes only command zero. All subsequent
            # states/actions remain in the raw streams, without duplicating a
            # history window that this Tier 2 policy does not read.
            following, boundary = history.append_resolved(self.core,proposed,resolved) if step == 0 else (history.empty(),None)
            self.memory,self.provider_memory = output["next_memory"],resolved["next_memory"]
            self.previous = [r["applied_correction_rad_s"] for r in resolved["ordered_commands"]]
            self.history,self.next_step = following,step+1
            return dict(request=request,output=output,stability=stability,kinematics=kinematics,composition=composition,
                resolution_request=resolution_request,resolution=resolved,native_targets=targets,
                selection=dict(role=self.role,decision=called["decision"],provider_error=called["provider_error"],
                    history_boundary=boundary,learned_selection=self.mode != "baseline" and step > 0))
        except BaseException:
            self.close()
            raise
