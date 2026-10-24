"""Frozen condition/state retrieval through bounded, engine-neutral proposals.

Inference changes episode context, never the fitted model. This is a Tier 2
development provider; useful physical selection and Tier 3 benefit need proof.
"""
import copy
from dataclasses import dataclass, replace
import hashlib
import json
from pathlib import Path

from . import feedback_flat_v1 as learner
from . import first_response_features_v1 as context
from .. import phase_release_feedback_v1 as feedback

require = learner.require
ROOT = Path(__file__).resolve().parents[3]
CONTRACT = Path(__file__).with_suffix(".json")
FIT_RECORD = ROOT/"sdk/discovery/first_response_repertoire_closure_v1.json"
FIT_SHA = "dcd829f123b0ec15aa383049ebed5ba2b8d1bc0fc3854109b880d2435f6aefec"
CASEBOOK_SHA = "sha256:4f80591a7964c50a13f11fb4e92115f0d223c4f169071900efce18d69fe55c7f"
CASE_COUNT = 720
PROVIDER_SCHEMA = "locolemotion_conditioned_feedback_provider_v1"
MODES = ("frozen", "disabled", "shuffled")
RULE = dict(context_step=1, context_history="one actual baseline command and two observed joint positions",
    context_support="closed per-condition coordinate minima/maxima of the four training features; no padding",
    condition_default="complete four-start controller ranked by whole-episode quality, then action index",
    retrieval="current command phase/contact and scaled state distance; immutable condition-filtered cases",
    selection="highest predicted quality, then action index; retain a supported previous action unless gain reaches 0.001 m/s",
    unsupported="withdraw to current deterministic baseline", candidate_indices=[0,3,4],
    shuffled_action_indices=[0,2,1], history_retained_after_context_step=False,
    online_outcome_updates=False, base_weights_mutated=False)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_definition():
    return dict(schema_version=PROVIDER_SCHEMA,
        ledger_scope=dict(subsystem="adaptation", engine_scope="core", authority_mode="development_component", question_class="development"),
        source_fit=dict(path=FIT_RECORD.relative_to(ROOT).as_posix(), sha256=FIT_SHA),
        fitted_casebook_sha256=CASEBOOK_SHA, rule=RULE, modes=list(MODES),
        physical_launch_authority=False, physical_acceptance_authority=False,
        adaptation_benefit_established=False, tier3_benefit_established=False, release_authority=False)


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value == expected_definition(), "Conditioned feedback definition")
    return value


@dataclass(frozen=True)
class ConditionedModel:
    casebook: learner.FrozenModel
    serialized: str
    sha256: str
    condition_rows: tuple
    defaults: tuple
    context_serialized: str
    bounds_serialized: str
    feedback_serialized: str
    corpus_sha256: str

    @classmethod
    def load(cls, core, path=None):
        path = FIT_RECORD if path is None else Path(path)
        require(sha(path) == FIT_SHA, "Conditioned feedback fitted source changed")
        result = json.loads(path.read_text(encoding="utf-8"))["result"]
        casebook = learner.FrozenModel.load(core, result["model"])
        require(casebook.sha256 == result["model_sha256"] == CASEBOOK_SHA, "Conditioned feedback casebook identity")
        groups = result["groups"]
        bounds = []
        for label in context.LABELS:
            rows = [g["features"]["values"] for g in groups if g["condition_id"] == label]
            require(len(rows) == 4, "Conditioned feedback feature support population")
            bounds.append(dict(condition_id=label, minimum=[min(r[j] for r in rows) for j in range(16)],
                maximum=[max(r[j] for r in rows) for j in range(16)]))
        plan = casebook.plan(); document = casebook.document()
        by_group = {g["group_id"]:g["condition_id"] for g in plan["groups"]}
        by_episode = {e["episode_id"]:by_group[e["group_id"]] for e in document["ordered_episode_ledger"]}
        by_case = {c["case_id"]:by_episode[c["episode_id"]] for c in document["ordered_cases"]}
        rows = tuple(tuple(r for r in casebook.cases if by_case[r[-1]] == label) for label in context.LABELS)
        defaults = tuple(d["default_action_index"] for d in result["complete_condition_defaults"])
        require(defaults == (None,0) and sum(map(len,rows)) == CASE_COUNT, "Conditioned feedback retained coverage/defaults")
        context_model = result["evaluation"]["all_training_model"]
        corpus = dict(casebook_corpus_sha256=document["frozen_corpus_sha256"],
            context_training_data_sha256=context_model["training_data_sha256"], source_fit_sha256=FIT_SHA)
        body = dict(schema_version="locolemotion_conditioned_feedback_model_v1", definition=definition(),
            casebook_sha256=casebook.sha256, context_model=context_model, context_bounds=bounds,
            complete_condition_defaults=result["complete_condition_defaults"], feedback_definition=feedback.definition(),
            training_corpus=corpus, base_model_immutable=True, physical_acceptance_authority=False)
        encode = lambda value:json.dumps(value,sort_keys=True,separators=(",",":"),allow_nan=False)
        return cls(casebook,encode(body),learner.digest(core,body),rows,defaults,encode(context_model),
            encode(bounds),encode(body["feedback_definition"]),learner.digest(core,corpus))

    @property
    def model_id(self): return "s169_conditioned_feedback_"+self.sha256[7:27]

    def plan(self): return self.casebook.plan()

    def infer(self, feature):
        prediction = context.predict(json.loads(self.context_serialized),feature)
        label = prediction["condition_id"]
        support = False
        if label is not None:
            box = json.loads(self.bounds_serialized)[context.LABELS.index(label)]
            support = all(lo <= v <= hi for lo,v,hi in zip(box["minimum"],feature["values"],box["maximum"],strict=True))
        return dict(prediction=prediction, feature_supported=support,
            condition_id=label if support else None, confidence_is_calibrated=False)

    def predictions(self, query, label):
        require(label in context.LABELS, "Conditioned feedback unknown context")
        # Only the search rows are filtered. The immutable source artifact still
        # retains its complete positive and failed episode ledger.
        local = replace(self.casebook,cases=self.condition_rows[context.LABELS.index(label)])
        return local.predictions(query)


def empty_memory(core, model):
    return learner.empty_memory(core,plan=model.plan())


def bind_request(core, request, model, mode, memory, previous):
    require(mode in (*MODES,"baseline") and len(previous) == 8, "Conditioned feedback host mode/envelope")
    value = copy.deepcopy(request); plan = model.plan()
    value.update(request_id="conditioned_feedback_"+mode+"_step_"+str(value["state"]["semantic_step"]),
        provider_id=plan["provider_id"], expected_provider_version=plan["provider_version"]+"_runtime_v1_"+mode,
        expected_model_id=model.model_id, expected_model_sha256=model.sha256,
        expected_training_corpus_id="phase_release_conditioned_feedback_v1",
        expected_training_corpus_sha256=model.corpus_sha256, provider_memory=copy.deepcopy(memory))
    value["safety_envelope"].update(minimum_confidence=1., maximum_support_distance=plan["maximum_support_distance"])
    for limit,old in zip(value["safety_envelope"]["ordered_actuator_limits"],previous,strict=True):
        limit.update(maximum_absolute_correction_rad_s=3.5,maximum_slew_per_step_rad_s=.08,previous_applied_correction_rad_s=old)
    return value


def choose(predictions, previous, default, plan):
    if default is not None: return default, "complete_condition_default"
    if not predictions: return None, "no_current_case_support"
    chosen = min(predictions,key=lambda a:(-predictions[a]["quality_m_s"],a))
    if previous in predictions and predictions[chosen]["quality_m_s"] < predictions[previous]["quality_m_s"]+plan["minimum_predicted_gain_m_s"]:
        chosen = previous
    return chosen, "current_case_retrieval"


def respond(core, request, model, mode):
    plan = model.plan(); memory = copy.deepcopy(request["provider_memory"])
    require(mode in MODES and request["provider_id"] == plan["provider_id"]
        and request["expected_provider_version"] == plan["provider_version"]+"_runtime_v1_"+mode
        and request["expected_model_id"] == model.model_id and request["expected_model_sha256"] == model.sha256
        and request["expected_training_corpus_id"] == "phase_release_conditioned_feedback_v1"
        and request["expected_training_corpus_sha256"] == model.corpus_sha256, "Conditioned feedback identity")
    require(learner.digest(core,request["descriptor"]) == plan["descriptor_sha256"], "Conditioned feedback morphology")
    baseline = request["deterministic_baseline"]["ordered_commands"]
    require([b["actuator_id"] for b in baseline] == plan["ordered_actuator_ids"], "Conditioned feedback actuator order")
    step = request["state"]["semantic_step"]
    require(type(step) is int and step >= 0 and request["state"]["sample_time_s"] == step*plan["controller_dt_s"], "Conditioned feedback clock")
    require(memory["provider_id"] == plan["provider_id"] and memory["weights_mutated"] is False
        and learner.digest(core,memory["opaque_state"]) == memory["opaque_state_sha256"]
        and type(memory["sequence"]) is int and memory["sequence"] == step, "Conditioned feedback memory binding/sequence")
    opaque = memory["opaque_state"]
    if not opaque:
        require(step == 0, "Conditioned feedback missing initial context")
        opaque = dict(schema_version="locolemotion_conditioned_feedback_memory_v1", model_sha256=model.sha256,
            mode=mode,seed=request["seed"],last_step=-1,context=None,previous_action=None)
    require(set(opaque) == {"schema_version","model_sha256","mode","seed","last_step","context","previous_action"}
        and opaque["schema_version"] == "locolemotion_conditioned_feedback_memory_v1"
        and opaque["model_sha256"] == model.sha256 and opaque["mode"] == mode and opaque["seed"] == request["seed"]
        and type(opaque["last_step"]) is int and opaque["last_step"] == step-1
        and (opaque["previous_action"] is None or type(opaque["previous_action"]) is int and opaque["previous_action"] in range(3)),
        "Conditioned feedback crossed/stale memory")
    detail = dict(mode=mode,step=step,context=None,query=None,predictions=[],logical_action_index=None,
        proposed_action_index=None,candidate_index=None,selection_reason="baseline_observation",feedback=None)
    status, distance, corrections = "no_proposal", 0., []
    if step == 1:
        feature = context.features(request)
        opaque["context"] = dict(feature=feature,decision=model.infer(feature))
    if step > 0:
        saved = opaque["context"]
        require(isinstance(saved,dict) and set(saved) == {"feature","decision"}
            and model.infer(saved["feature"]) == saved["decision"], "Conditioned feedback context binding")
        detail["context"] = copy.deepcopy(saved["decision"])
        label = saved["decision"]["condition_id"]
        status = "unsupported"; detail["selection_reason"] = "unsupported_initial_context"
        opaque_previous = opaque["previous_action"]; opaque["previous_action"] = None
        if label is not None and not request["deterministic_baseline"]["safe_no_actuation"]:
            try:
                query = learner.cue(request,plan)
                predictions = model.predictions(query,label)
                selected, reason = choose(predictions,opaque_previous,model.defaults[context.LABELS.index(label)],plan)
                detail.update(query=query,predictions=[dict(action_index=a,**p) for a,p in sorted(predictions.items())],
                    logical_action_index=selected,selection_reason=reason)
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
            except (ValueError,KeyError,TypeError) as exc:
                status, distance, corrections = "unsupported", 0., []
                detail["selection_reason"] = "unsupported_current_observation: "+str(exc)
                opaque["previous_action"] = None
    opaque["last_step"] = step
    memory.update(sequence=step+1,opaque_state=opaque,opaque_state_sha256=learner.digest(core,opaque))
    require(len(core.canonicalize_json(opaque)["canonical_json"].encode()) <= plan["episodic_memory"]["maximum_opaque_state_bytes"], "Conditioned feedback memory capacity")
    response = dict(schema_version="sporespore_adaptation_provider_response_v1",request_id=request["request_id"],
        request_sha256=learner.digest(core,request),status=status,confidence=1.,support_distance=distance,
        ordered_corrections=corrections,next_memory=memory,
        provenance=dict(provider_id=plan["provider_id"],provider_version=request["expected_provider_version"],model_id=model.model_id,
            model_sha256=model.sha256,training_corpus_id="phase_release_conditioned_feedback_v1",training_corpus_sha256=model.corpus_sha256,
            seed=request["seed"],engine_specific_logic_used=False,direct_world_access_used=False,weights_mutated=False,physical_acceptance_authority=False),
        candidate_experience=None,diagnostics=["frozen condition/state retrieval; confidence denotes declared support, not calibrated safety", "selection:"+detail["selection_reason"]],
        physical_acceptance_authority=False)
    detail["status"] = status
    return response,detail


def call_provider(core, request, model, mode):
    try:
        response,detail = respond(core,request,model,mode)
        return dict(provider_response=response,decision=detail,provider_error=None)
    except Exception as exc:
        return dict(provider_response=None,decision=None,provider_error=dict(type=type(exc).__name__,message=str(exc)))
