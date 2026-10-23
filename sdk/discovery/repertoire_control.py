"""Native training-corpus proposals through unchanged baseline and provider APIs.

Each action is untrained and fixed for one episode. Fitting belongs to a later
immutable corpus step; this host cannot promote a provider or a release.
"""
import copy
from dataclasses import asdict

from portable_search_control import Controller, bridge, map_resolution, proposal, proposal_request
from portable_batch_control import BatchController, CanonicalCache, pure_batch, values


def repertoire_request(core, c, candidate, state, command, output, baseline, memory, previous):
    request = proposal_request(core, c, candidate, state, command, output, baseline, memory, previous)
    request.update(provider_id="bounded_repertoire_search", expected_provider_version="untrained_bilateral_v1")
    return request


def repertoire_proposal(core, request, candidate):
    response = proposal(core, request, candidate)
    if response is not None:
        rows = request["deterministic_baseline"]["ordered_commands"]
        coefficients = candidate["ordered_coefficients"]
        if len(coefficients) != 8 or any(type(v) not in (int, float) or not -.25 <= v <= .25 for v in coefficients):
            raise ValueError("Declared repertoire coefficients")
        response["ordered_corrections"] = [dict(actuator_id=r["actuator_id"],
            canonical_velocity_delta_rad_s=k*r["combined_canonical_target_velocity_rad_s"])
            for k, r in zip(coefficients, rows, strict=True)]
        response["diagnostics"] = ["untrained_bilateral_repertoire; confidence denotes declared action support only"]
    return response


class RepertoireController(BatchController):
    def __init__(self, core, compiled, contract, candidate_cells=None):
        super().__init__(core, compiled, contract, candidate_cells)
        for controller in self.controllers:
            controller.provider_memory["provider_id"] = "bounded_repertoire_search"

    def step(self, observations):
        if len(observations) != len(self.controllers):
            raise ValueError("Batch observation denominator")
        ids = [str(i) for i in range(len(self.controllers))]
        calls = []
        requests = []
        for cell_id, controller, (state, stability, kinematics) in zip(ids, self.controllers, observations, strict=True):
            request = dict(memory=controller.memory, state=state,
                           command=bridge._motion_command(state["semantic_step"], self.contract["phase_mode"]))
            requests.append(request)
            calls.append(dict(cell_id=cell_id, session_handle=controller.session.batch_handle, request=dict(
                **request, stability=stability, kinematics=kinematics,
                composition_memory=asdict(controller.composition_memory),
                host_profile=bridge._mujoco_host_profile(controller.context.profile_id))))
        receipt = self.core.bw19v_composition_batch_v1(calls)
        if receipt.get("schema_version") != "sporespore_bw19v_composition_batch_receipt_v1":
            raise ValueError("Composition batch schema")
        baseline = values(receipt, ids)
        # Only static model/corpus hashes persist. Per-step caches die with this
        # call; neither historical requests nor controller memory accumulate.
        cache = CanonicalCache(self.core, [b["output"]["next_memory"] for b in baseline], self.static)
        providers = [repertoire_request(cache, self.contract, c.candidate, request["state"], request["command"],
                    b["output"], b["composition"]["canonical_actuation"], c.provider_memory, c.previous)
                     for c, request, b in zip(self.controllers, requests, baseline, strict=True)]
        cache = CanonicalCache(self.core, providers, cache)
        resolution_requests = [dict(schema_version="sporespore_adaptation_resolution_request_v1",
            provider_request=provider, provider_response=repertoire_proposal(cache, provider, c.candidate))
            for c, provider in zip(self.controllers, providers, strict=True)]
        resolutions = pure_batch(self.core, "resolve_adaptation_v1", resolution_requests)
        records = []
        for request, observation, b, resolution_request, resolution in zip(requests, observations, baseline, resolution_requests, resolutions, strict=True):
            if resolution["fallback_reason"] not in ("none", "provider_absent", "safe_no_actuation"):
                raise ValueError("Unexpected provider refusal: " + resolution["fallback_reason"])
            targets = map_resolution(b["composition"]["host_mapping"], resolution)
            records.append(dict(request=copy.deepcopy(request), output=b["output"], stability=observation[1],
                kinematics=observation[2], composition=b["composition"], resolution_request=resolution_request,
                resolution=resolution, native_targets=targets))
        # Commit explicit host memory only after every result and mapping passed.
        for c, b, resolution in zip(self.controllers, baseline, resolutions, strict=True):
            c.memory = b["output"]["next_memory"]
            c.composition_memory = bridge.CompositionMemory(**b["next_composition_memory"])
            c.provider_memory = resolution["next_memory"]
            c.previous = [r["applied_correction_rad_s"] for r in resolution["ordered_commands"]]
        return records


class ScalarRepertoireController(Controller):
    """Original scalar baseline path used by independent native-data replay."""
    def __init__(self, core, compiled, contract, cell):
        super().__init__(core, compiled, contract, cell)
        self.provider_memory["provider_id"] = "bounded_repertoire_search"

    def step(self,state,stability,kinematics):
        step=state['semantic_step'];command=bridge._motion_command(step,self.c['phase_mode'])
        request=dict(memory=self.memory,state=state,command=command)
        limb_steps=bridge._ordered_limb_steps(self.memory,self.context.morphology['ordered_limb_ids'])
        output=self.session.step(request);actuation=output['actuation']
        if actuation['receipt']['controller_error'] is not None or actuation['failure_codes']:
            raise ValueError('Portable controller refused: '+str(actuation['failure_codes']))
        composition=bridge.compose_bw19v_step(self.context,actuation,stability,kinematics,limb_steps,self.composition_memory)
        provider=repertoire_request(self.core,self.c,self.candidate,state,command,output,composition['canonical_actuation'],self.provider_memory,self.previous)
        response=repertoire_proposal(self.core,provider,self.candidate)
        resolution_request=dict(schema_version='sporespore_adaptation_resolution_request_v1',provider_request=provider,provider_response=response)
        resolution=self.core.resolve_adaptation_v1(resolution_request)
        if resolution['fallback_reason'] not in ('none','provider_absent','safe_no_actuation'):raise ValueError('Unexpected provider refusal: '+resolution['fallback_reason'])
        targets=map_resolution(composition['host_mapping'],resolution)
        self.memory=output['next_memory'];self.provider_memory=resolution['next_memory'];self.previous=[r['applied_correction_rad_s'] for r in resolution['ordered_commands']]
        return dict(request=request,output=output,stability=stability,kinematics=kinematics,composition=composition,
                    resolution_request=resolution_request,resolution=resolution,native_targets=targets)

