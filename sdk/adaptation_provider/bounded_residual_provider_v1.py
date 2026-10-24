"""Immutable residual proposals through the public v1 adaptation interface.

The initial scope is development on an explicitly bounded S169 flat task.
Confidence denotes declared mechanical-domain membership, not calibrated
performance or recoverability. Native training and promotion are separate.
"""
import copy
from dataclasses import dataclass
import hashlib
import json
from pathlib import Path

from . import bounded_residual_ars_v1 as ars
from . import bounded_residual_features_v1 as features

require=ars.require
CONTRACT=Path(__file__).with_suffix(".json")
ROOT=Path(__file__).resolve().parents[2]
PROVIDER_ID="s169_bounded_residual_v1"
VERSION="bounded_residual_runtime_v1"
MODES=("frozen","disabled","absent")
IMPLEMENTATIONS=("bounded_residual_ars_v1.py","bounded_residual_features_v1.py","bounded_residual_provider_v1.py",
    "stance_feedback_v1.py","phase_release_feedback_v1.py","retrieval/causal_history_v1.py")


def digest(core,value):
    return core.canonicalize_json(value)["sha256"]


def expected_definition():
    return dict(schema_version="locolemotion_bounded_residual_provider_definition_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="development_component",question_class="development"),
        provider_id=PROVIDER_ID,provider_version=VERSION,observation=features.schema(),
        ordered_actuator_ids=list(features.ACTUATORS),modes=list(MODES),
        controller_dt_s=features.DT,maximum_correction_rad_s=3.5,
        maximum_slew_per_command_rad_s=.08,maximum_final_speed_rad_s=3.5,
        minimum_confidence=1.,maximum_support_distance=1.,maximum_memory_bytes=4096,
        first_command="baseline_only",history_entries=1,
        model_digest_basis="sha256_utf8_sorted_compact_json_without_numeric_rounding",
        final_speed_limit="actual_per_actuator_baseline_limit_at_each_command",
        confidence_is_calibrated=False,weights_updated_online=False,
        source_implementations={p:hashlib.sha256((CONTRACT.parent/p).read_bytes()).hexdigest() for p in IMPLEMENTATIONS},
        physical_launch_authority=False,physical_acceptance_authority=False,
        training_data_authority=False,tier3_benefit_established=False,release_authority=False)


def definition():
    value=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value==expected_definition(),"Residual definition/source bindings changed")
    return value


@dataclass(frozen=True)
class FrozenModel:
    policy: ars.Policy
    serialized: str
    sha256: str
    corpus_id: str
    corpus_sha256: str
    confidence_ceiling: float

    @classmethod
    def load(cls,core,value):
        # Round-trip into owned bytes before deriving the inference object.
        require(isinstance(value,dict) and set(value)=={"schema_version","definition","policy","corpus","confidence_ceiling"},
                "Residual artifact shape")
        require(value["schema_version"]=="locolemotion_bounded_residual_model_v1"
            and value["definition"]==definition(),"Residual model definition")
        p=value["policy"]
        moments=ars.Moments(p["count"],tuple(p["mean"]),tuple(p["m2"]))
        policy=ars.Policy(tuple(tuple(row) for row in p["weights"]),moments,tuple(p["output_limits"]),p["variance_floor"])
        policy.validate()
        require(json.loads(json.dumps(policy.document(),allow_nan=False))==p and len(policy.weights)==8
            and len(moments.mean)==features.DIMENSION and policy.output_limits==(3.5,)*8,
            "Residual policy schema/dimensions/limits")
        corpus=value["corpus"]
        require(isinstance(corpus,dict) and set(corpus)=={"corpus_id","kind","source_record_sha256","training_data_authority"}
            and isinstance(corpus["corpus_id"],str) and bool(corpus["corpus_id"])
            and corpus["kind"] in ("untrained_development_probe","development_training_checkpoint"),
            "Residual corpus identity")
        if corpus["kind"]=="untrained_development_probe":
            require(corpus["source_record_sha256"] is None and corpus["training_data_authority"] is False,
                    "Untrained residual cannot claim a training corpus")
        else:
            h=corpus["source_record_sha256"]
            require(isinstance(h,str) and h.startswith("sha256:") and len(h)==71
                and all(c in "0123456789abcdef" for c in h[7:]) and corpus["training_data_authority"] is True,
                "Residual training lineage")
        ceiling=value["confidence_ceiling"]
        require(ars.finite(ceiling) and 0<=ceiling<=1,"Residual confidence ceiling")
        # Core canonical JSON deliberately quantizes binary64 for receipt
        # identity. Model storage must preserve every weight/statistic bit.
        encoded=json.dumps(value,sort_keys=True,separators=(",",":"),allow_nan=False)
        return cls(policy,encoded,"sha256:"+hashlib.sha256(encoded.encode("utf-8")).hexdigest(),corpus["corpus_id"],
            digest(core,corpus),float(ceiling))

    @property
    def model_id(self):return "residual_"+self.sha256[7:31]

    def document(self):return json.loads(self.serialized)


def artifact(policy,corpus,confidence_ceiling=1.):
    policy.validate()
    return dict(schema_version="locolemotion_bounded_residual_model_v1",definition=definition(),
        policy=json.loads(json.dumps(policy.document(),allow_nan=False)),
        corpus=copy.deepcopy(corpus),confidence_ceiling=confidence_ceiling)


def empty_memory(core,model,mode,seed,episode_id,reset_epoch=0):
    require(mode in MODES and type(seed) is int and seed>=0
        and type(reset_epoch) is int and reset_epoch>=0
        and isinstance(episode_id,str) and episode_id and len(episode_id)<=96
        and all(c.isascii() and (c.isalnum() or c in "_-") for c in episode_id),"Residual fresh identity")
    opaque=dict(schema_version="locolemotion_residual_memory_v1",model_sha256=model.sha256,
        mode=mode,seed=seed,episode_id=episode_id,last_step=-1,previous_binding=None)
    return dict(schema_version="sporespore_adaptation_provider_memory_v1",provider_id=PROVIDER_ID,
        reset_epoch=reset_epoch,sequence=0,opaque_state=opaque,opaque_state_sha256=digest(core,opaque),
        weights_mutated=False)


def bind_request(core,request,model,mode,memory,previous,episode_id):
    require(mode in MODES and len(previous)==8,"Residual host mode/envelope")
    value=copy.deepcopy(request);step=value["state"]["semantic_step"]
    value.update(request_id="residual_"+episode_id+"_"+str(step),provider_id=PROVIDER_ID,
        expected_provider_version=VERSION+"_"+mode,expected_model_id=model.model_id,
        expected_model_sha256=model.sha256,expected_training_corpus_id=model.corpus_id,
        expected_training_corpus_sha256=model.corpus_sha256,provider_memory=copy.deepcopy(memory))
    value["safety_envelope"].update(minimum_confidence=1.,maximum_support_distance=1.)
    for row,old in zip(value["safety_envelope"]["ordered_actuator_limits"],previous,strict=True):
        row.update(maximum_absolute_correction_rad_s=3.5,maximum_slew_per_step_rad_s=.08,
                   previous_applied_correction_rad_s=old)
    return value


def respond(core,request,model,mode):
    require(mode in ("frozen","disabled"),"Residual proposal mode")
    require(request["provider_id"]==PROVIDER_ID and request["expected_provider_version"]==VERSION+"_"+mode
        and request["expected_model_id"]==model.model_id and request["expected_model_sha256"]==model.sha256
        and request["expected_training_corpus_id"]==model.corpus_id
        and request["expected_training_corpus_sha256"]==model.corpus_sha256,"Residual artifact binding")
    step=request["state"]["semantic_step"];memory=copy.deepcopy(request["provider_memory"])
    require(type(step) is int and step>=0 and memory["provider_id"]==PROVIDER_ID
        and memory["weights_mutated"] is False and type(memory["sequence"]) is int
        and memory["sequence"]==step and digest(core,memory["opaque_state"])==memory["opaque_state_sha256"],
        "Residual memory digest/sequence")
    opaque=memory["opaque_state"]
    require(set(opaque)=={"schema_version","model_sha256","mode","seed","episode_id","last_step","previous_binding"}
        and opaque["schema_version"]=="locolemotion_residual_memory_v1"
        and opaque["model_sha256"]==model.sha256 and opaque["mode"]==mode and opaque["seed"]==request["seed"]
        and type(opaque["last_step"]) is int and opaque["last_step"]==step-1
        and request["request_id"]=="residual_"+opaque["episode_id"]+"_"+str(step)
        and ((step==0 and opaque["previous_binding"] is None)
             or (step>0 and isinstance(opaque["previous_binding"],dict)
                 and set(opaque["previous_binding"])=={"request_sha256","observation_sha256"})),
        "Residual crossed/stale episode memory")
    require(request["safety_envelope"]["minimum_confidence"]==1.
        and request["safety_envelope"]["maximum_support_distance"]==1.,"Residual confidence/support threshold")
    status,confidence,distance,corrections="unsupported",0.,0.,[]
    detail=dict(mode=mode,step=step,model_sha256=model.sha256,features=None,
        raw_correction_rad_s=None,reason=None,confidence_is_calibrated=False)
    try:
        feature=features.extract(core,request,opaque["previous_binding"])
        detail["features"]=feature;distance=feature["support_distance"]
        confidence=model.confidence_ceiling
        raw=model.policy.action(feature["values"]);detail["raw_correction_rad_s"]=list(raw)
        if step==0:
            status,reason="no_proposal","initial_baseline_observation"
        elif request["deterministic_baseline"]["safe_no_actuation"]:
            status,reason="no_proposal","deterministic_safe_no_actuation"
        elif confidence<1.:
            status,reason="uncertain","artifact_confidence_ceiling"
        elif mode=="disabled":
            status,reason="no_proposal","disabled_shadow_only"
        else:
            status,reason="applied","frozen_bounded_residual"
            corrections=[dict(actuator_id=a,canonical_velocity_delta_rad_s=v)
                         for a,v in zip(features.ACTUATORS,raw,strict=True)]
        detail["reason"]=reason
    except (ValueError,KeyError,TypeError,OverflowError) as exc:
        detail["reason"]="unsupported_observation: "+str(exc)
    request_sha=digest(core,request)
    opaque.update(last_step=step,previous_binding=dict(request_sha256=request_sha,
        observation_sha256=features.observation_binding(core,request)))
    memory.update(sequence=step+1,opaque_state=opaque,opaque_state_sha256=digest(core,opaque))
    require(len(core.canonicalize_json(opaque)["canonical_json"].encode("utf-8"))<=4096,"Residual memory capacity")
    response=dict(schema_version="sporespore_adaptation_provider_response_v1",request_id=request["request_id"],
        request_sha256=request_sha,status=status,confidence=confidence,support_distance=distance,
        ordered_corrections=corrections,next_memory=memory,
        provenance=dict(provider_id=PROVIDER_ID,provider_version=request["expected_provider_version"],
            model_id=model.model_id,model_sha256=model.sha256,training_corpus_id=model.corpus_id,
            training_corpus_sha256=model.corpus_sha256,seed=request["seed"],engine_specific_logic_used=False,
            direct_world_access_used=False,weights_mutated=False,physical_acceptance_authority=False),
        candidate_experience=None,diagnostics=["residual development; confidence is declared domain membership, not calibrated safety",
            "decision:"+str(detail["reason"])],physical_acceptance_authority=False)
    detail["status"]=status
    return response,detail


def call_provider(core,request,model,mode):
    if mode=="absent":return dict(provider_response=None,decision=None,provider_error=None)
    try:
        response,detail=respond(core,request,model,mode)
        return dict(provider_response=response,decision=detail,provider_error=None)
    except Exception as exc:
        return dict(provider_response=None,decision=None,provider_error=dict(type=type(exc).__name__,message=str(exc)))
