"""Supported temporal commitment over the existing frozen feedback casebook.

Only selection timing changes. This component neither fits new cases nor learns
from outcomes; physical usefulness requires its own prospective comparison.
"""
import copy
import json
from pathlib import Path
from . import conditioned_feedback_v2 as parent

learner, context, feedback = parent.learner, parent.context, parent.feedback
require, ROOT = parent.require, parent.ROOT
FIT_RECORD, FIT_SHA = parent.FIT_RECORD, parent.FIT_SHA
CASEBOOK_SHA, CASE_COUNT = parent.CASEBOOK_SHA, parent.CASE_COUNT
MODES = parent.MODES
CONTRACT = Path(__file__).with_suffix(".json")
PROVIDER_SCHEMA = "locolemotion_committed_feedback_provider_v1"
WINDOW = 30
RULE = dict(parent.RULE,
    selection="Retain a supported logical expert for thirty commands; at expiry use the unchanged gain rule. Loss of its current case support terminates commitment before any new proposal.",
    commitment_commands=WINDOW,
    commitment_clock="start inclusive, end exclusive; commands one through thirty expire at command thirty-one",
    support_scope="Current logical expert before shuffled mapping; shuffled associations intentionally corrupt which expert is applied.",
    commitment_does_not_override_posture_or_safe_no_actuation=True,
    commitment_is_outcome_memory=False)
sha, choose, empty_memory = parent.sha, parent.choose, parent.empty_memory


def expected_definition():
    value = parent.expected_definition()
    value.update(schema_version=PROVIDER_SCHEMA, rule=RULE)
    return value


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value == expected_definition(), "Committed feedback definition")
    return value


class ConditionedModel(parent.ConditionedModel):
    @classmethod
    def load(cls, core, path=None):
        original = parent.ConditionedModel.load(core, path)
        body = json.loads(original.serialized)
        body.update(schema_version="locolemotion_committed_feedback_model_v1", definition=definition())
        encoded = json.dumps(body, sort_keys=True, separators=(",", ":"), allow_nan=False)
        return cls(original.casebook, encoded, learner.digest(core, body),
            original.condition_rows, original.defaults, original.context_serialized,
            original.bounds_serialized, original.feedback_serialized, original.corpus_sha256)

    @property
    def model_id(self):
        return "s169_committed_feedback_"+self.sha256[7:27]


def bind_request(core, request, model, mode, memory, previous):
    value = parent.bind_request(core, request, model, mode, memory, previous)
    value.update(request_id="committed_feedback_"+mode+"_step_"+str(value["state"]["semantic_step"]),
        expected_provider_version=model.plan()["provider_version"]+"_committed_runtime_v1_"+mode)
    return value


def choose_committed(predictions, previous, default, plan, step, until):
    require(type(step) is int and step > 0, "Committed selection clock")
    if default is not None:
        return default, "complete_condition_default", None, "default"
    if previous in predictions and until is not None and step < until:
        return previous, "temporal_commitment", until, "continued"
    event = ("support_terminated" if previous is not None and previous not in predictions
        else "expired" if previous is not None else "initial")
    selected, reason = choose(predictions, previous, default, plan)
    return selected, reason, step+WINDOW if selected is not None else None, event


def respond(core, request, model, mode):
    plan = model.plan(); memory = copy.deepcopy(request["provider_memory"])
    require(mode in MODES and request["provider_id"] == plan["provider_id"]
        and request["expected_provider_version"] == plan["provider_version"]+"_committed_runtime_v1_"+mode
        and request["expected_model_id"] == model.model_id and request["expected_model_sha256"] == model.sha256
        and request["expected_training_corpus_id"] == "phase_release_conditioned_feedback_v1"
        and request["expected_training_corpus_sha256"] == model.corpus_sha256, "Committed feedback identity")
    require(learner.digest(core,request["descriptor"]) == plan["descriptor_sha256"], "Committed feedback morphology")
    baseline = request["deterministic_baseline"]["ordered_commands"]
    require([b["actuator_id"] for b in baseline] == plan["ordered_actuator_ids"], "Committed feedback actuator order")
    step = request["state"]["semantic_step"]
    require(type(step) is int and step >= 0 and request["state"]["sample_time_s"] == step*plan["controller_dt_s"], "Committed feedback clock")
    require(memory["provider_id"] == plan["provider_id"] and memory["weights_mutated"] is False
        and learner.digest(core,memory["opaque_state"]) == memory["opaque_state_sha256"]
        and type(memory["sequence"]) is int and memory["sequence"] == step, "Committed feedback memory binding/sequence")
    opaque = memory["opaque_state"]
    if not opaque:
        require(step == 0, "Committed feedback missing initial context")
        opaque = dict(schema_version="locolemotion_committed_feedback_memory_v1", model_sha256=model.sha256,
            mode=mode,seed=request["seed"],last_step=-1,context=None,previous_action=None,committed_until_step=None)
    require(set(opaque) == {"schema_version","model_sha256","mode","seed","last_step","context","previous_action","committed_until_step"}
        and opaque["schema_version"] == "locolemotion_committed_feedback_memory_v1"
        and opaque["model_sha256"] == model.sha256 and opaque["mode"] == mode and opaque["seed"] == request["seed"]
        and type(opaque["last_step"]) is int and opaque["last_step"] == step-1
        and (opaque["previous_action"] is None or type(opaque["previous_action"]) is int and opaque["previous_action"] in range(3))
        and ((opaque["previous_action"] in [None,0] and opaque["committed_until_step"] is None)
            or (opaque["previous_action"] in [1,2] and type(opaque["committed_until_step"]) is int
                and 0 < opaque["committed_until_step"]-opaque["last_step"] <= WINDOW)),
        "Committed feedback crossed/stale memory")
    detail = dict(mode=mode,step=step,context=None,query=None,predictions=[],logical_action_index=None,
        proposed_action_index=None,candidate_index=None,selection_reason="baseline_observation",feedback=None,commitment=None)
    status, distance, corrections = "no_proposal", 0., []
    if step == 1:
        feature = context.features(request)
        opaque["context"] = dict(feature=feature,decision=model.infer(feature))
    if step > 0:
        saved = opaque["context"]
        require(isinstance(saved,dict) and set(saved) == {"feature","decision"}
            and model.infer(saved["feature"]) == saved["decision"], "Committed feedback context binding")
        detail["context"] = copy.deepcopy(saved["decision"])
        label = saved["decision"]["condition_id"]
        status = "unsupported"; detail["selection_reason"] = "unsupported_initial_context"
        opaque_previous,previous_until = opaque["previous_action"],opaque["committed_until_step"]
        opaque["previous_action"],opaque["committed_until_step"] = None,None
        if label is not None and not request["deterministic_baseline"]["safe_no_actuation"]:
            try:
                query = learner.cue(request,plan)
                predictions = model.predictions(query,label)
                selected, reason, next_until, event = choose_committed(predictions,opaque_previous,
                    model.defaults[context.LABELS.index(label)],plan,step,previous_until)
                detail.update(query=query,predictions=[dict(action_index=a,**p) for a,p in sorted(predictions.items())],
                    logical_action_index=selected,selection_reason=reason,commitment=dict(event=event,until_step=next_until,commands=WINDOW))
                if selected is not None:
                    actual = RULE["shuffled_action_indices"][selected] if mode == "shuffled" else selected
                    candidate_index = RULE["candidate_indices"][actual]
                    detail.update(proposed_action_index=actual,candidate_index=candidate_index)
                    distance = predictions[selected]["support_distance"] if selected in predictions else 0.
                    status = "no_proposal"
                    if actual:
                        definition_value = json.loads(model.feedback_serialized)
                        candidate = definition_value["candidates"][candidate_index]
                        delta, receipt = feedback.feedback(request["state"],request["command"],candidate,
                            definition_value,request["deterministic_baseline"],request["controller_context"])
                        detail["feedback"] = receipt
                        if mode != "disabled":
                            status = "applied"
                            corrections = [dict(actuator_id=b["actuator_id"],canonical_velocity_delta_rad_s=d+k*b["combined_canonical_target_velocity_rad_s"])
                                for b,k,d in zip(baseline,candidate["ordered_coefficients"],delta,strict=True)]
                    opaque["previous_action"] = selected
                    opaque["committed_until_step"] = next_until
            except (ValueError,KeyError,TypeError) as exc:
                status, distance, corrections = "unsupported", 0., []
                detail["selection_reason"] = "unsupported_current_observation: "+str(exc)
                opaque["previous_action"],opaque["committed_until_step"] = None,None
                detail.update(logical_action_index=None,proposed_action_index=None,candidate_index=None,
                    feedback=None,commitment=dict(event="observation_or_expert_refusal",until_step=None,commands=WINDOW))
    opaque["last_step"] = step
    memory.update(sequence=step+1,opaque_state=opaque,opaque_state_sha256=learner.digest(core,opaque))
    require(len(core.canonicalize_json(opaque)["canonical_json"].encode()) <= plan["episodic_memory"]["maximum_opaque_state_bytes"], "Committed feedback memory capacity")
    response = dict(schema_version="sporespore_adaptation_provider_response_v1",request_id=request["request_id"],
        request_sha256=learner.digest(core,request),status=status,confidence=1.,support_distance=distance,
        ordered_corrections=corrections,next_memory=memory,
        provenance=dict(provider_id=plan["provider_id"],provider_version=request["expected_provider_version"],model_id=model.model_id,
            model_sha256=model.sha256,training_corpus_id="phase_release_conditioned_feedback_v1",training_corpus_sha256=model.corpus_sha256,
            seed=request["seed"],engine_specific_logic_used=False,direct_world_access_used=False,weights_mutated=False,physical_acceptance_authority=False),
        candidate_experience=None,diagnostics=["supported thirty-command commitment; confidence denotes logical case support, not calibrated safety", "selection:"+detail["selection_reason"]],
        physical_acceptance_authority=False)
    detail["status"] = status
    return response,detail


def call_provider(core, request, model, mode):
    try:
        response,detail = respond(core,request,model,mode)
        return dict(provider_response=response,decision=detail,provider_error=None)
    except Exception as exc:
        return dict(provider_response=None,decision=None,provider_error=dict(type=type(exc).__name__,message=str(exc)))
