"""Frozen actor plus causal warnings through unchanged public v1 resolution."""
import copy
from dataclasses import dataclass,replace
import json
from pathlib import Path

from .. import bounded_residual_provider_v1 as actor_provider
from . import residual_v1 as warning

ars,features=actor_provider.ars,actor_provider.features
require=ars.require
ROOT=Path(__file__).resolve().parents[3]
CONTRACT=Path(__file__).with_suffix(".json")
PROVIDER_ID="s169_residual_withdrawal_v1"
VERSION="residual_withdrawal_runtime_v1"
MODES=("shadow","frozen","forced_route","disabled","absent")
FORCED_COMMAND=90


def digest(core,value):return core.canonicalize_json(value)["sha256"]


def expected_definition():
    return dict(schema_version="locolemotion_residual_withdrawal_definition_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="development_withdrawal_component",question_class="development"),
        provider_id=PROVIDER_ID,provider_version=VERSION,modes=list(MODES),
        actor_definition=actor_provider.definition(),warning_definition=warning.definition(),
        forced_route=dict(command=FORCED_COMMAND,event="explicit one-command withdrawal request",
            changes_observation=False,changes_prediction=False,prediction_evidence=False),
        shadow="record natural monitor decisions; preserve supported actor proposals",
        frozen="uncertain status while monitor requests withdrawal",
        reentry="unchanged warning hysteresis; real issued baseline commands remain in history",
        fallback="unchanged v1 immediate zero residual; no slew through fallback",
        first_command="baseline_only",maximum_memory_bytes=4096,
        maximum_correction_rad_s=3.5,maximum_slew_per_command_rad_s=.08,maximum_final_speed_rad_s=3.5,
        confidence_semantics="proposal permission indicator, not probability",
        confidence_is_calibrated=False,safe_backup_established=False,weights_updated_online=False,
        source_bindings={Path(__file__).relative_to(ROOT).as_posix():warning.sha(Path(__file__)),
            actor_provider.CONTRACT.relative_to(ROOT).as_posix():warning.sha(actor_provider.CONTRACT),
            warning.CONTRACT.relative_to(ROOT).as_posix():warning.sha(warning.CONTRACT)},
        physical_launch_authority=False,physical_acceptance_authority=False,
        tier2_complete=False,tier3_complete=False,release_authority=False)


def definition():
    value=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value==expected_definition(),"Withdrawal definition/source bindings")
    return value


@dataclass(frozen=True)
class FrozenModel:
    actor:actor_provider.FrozenModel
    warning:warning.FrozenWarning
    serialized:str
    sha256:str
    corpus_id:str
    corpus_sha256:str

    @classmethod
    def load(cls,core,value):
        require(isinstance(value,dict) and set(value)=={"schema_version","definition","actor","warning"}
            and value["schema_version"]=="locolemotion_residual_withdrawal_model_v1"
            and value["definition"]==definition(),"Withdrawal composite model shape/definition")
        actor=actor_provider.FrozenModel.load(core,value["actor"])
        monitor=warning.FrozenWarning.load(value["warning"])
        require(value["warning"]["training"]["kind"]=="retrospective_complete_training_population"
            and value["warning"]["training"]["held_out_start_id"] is None,"Withdrawal requires full frozen warning")
        encoded=warning.encode_json(value)
        corpus=dict(schema_version="locolemotion_residual_withdrawal_corpus_v1",
            actor_model_sha256=actor.sha256,actor_corpus=actor.document()["corpus"],
            warning_model_sha256=monitor.sha256,warning_training=monitor.document()["training"])
        return cls(actor,monitor,encoded,warning.digest(value),"residual_warning_training_64_v1",digest(core,corpus))

    @property
    def model_id(self):return "withdrawal_"+self.sha256[7:31]

    @property
    def policy(self):return self.actor.policy

    def document(self):return json.loads(self.serialized)


def artifact(actor,monitor):
    return dict(schema_version="locolemotion_residual_withdrawal_model_v1",
        definition=definition(),actor=actor.document(),warning=monitor.document())


def empty_memory(core,model,mode,seed,episode_id,reset_epoch=0):
    require(mode in MODES and type(seed) is int and seed>=0,"Withdrawal fresh mode/seed")
    state=warning.empty_memory(model.warning,episode_id,reset_epoch)
    opaque=dict(schema_version="locolemotion_residual_withdrawal_memory_v1",
        model_sha256=model.sha256,mode=mode,seed=seed,episode_id=episode_id,
        last_step=-1,previous_binding=None,warning_state=state.__dict__)
    return dict(schema_version="sporespore_adaptation_provider_memory_v1",provider_id=PROVIDER_ID,
        reset_epoch=reset_epoch,sequence=0,opaque_state=opaque,opaque_state_sha256=digest(core,opaque),weights_mutated=False)


def bind_request(core,request,model,mode,memory,previous,episode_id):
    require(mode in MODES and len(previous)==8,"Withdrawal host mode/envelope")
    value=copy.deepcopy(request);step=value["state"]["semantic_step"]
    value.update(request_id="withdrawal_"+episode_id+"_"+str(step),provider_id=PROVIDER_ID,
        expected_provider_version=VERSION+"_"+mode,expected_model_id=model.model_id,
        expected_model_sha256=model.sha256,expected_training_corpus_id=model.corpus_id,
        expected_training_corpus_sha256=model.corpus_sha256,provider_memory=copy.deepcopy(memory))
    value["safety_envelope"].update(minimum_confidence=1.,maximum_support_distance=1.)
    for row,old in zip(value["safety_envelope"]["ordered_actuator_limits"],previous,strict=True):
        row.update(maximum_absolute_correction_rad_s=3.5,maximum_slew_per_step_rad_s=.08,
            previous_applied_correction_rad_s=old)
    return value


def respond(core,request,model,mode):
    require(mode in MODES and mode!="absent","Withdrawal response mode")
    require(request["provider_id"]==PROVIDER_ID and request["expected_provider_version"]==VERSION+"_"+mode
        and request["expected_model_id"]==model.model_id and request["expected_model_sha256"]==model.sha256
        and request["expected_training_corpus_id"]==model.corpus_id
        and request["expected_training_corpus_sha256"]==model.corpus_sha256,"Withdrawal artifact binding")
    step=request["state"]["semantic_step"];memory=copy.deepcopy(request["provider_memory"])
    require(type(step) is int and 0<=step<warning.HORIZON and memory["provider_id"]==PROVIDER_ID
        and memory["weights_mutated"] is False and type(memory["sequence"]) is int and memory["sequence"]==step
        and type(memory["reset_epoch"]) is int and memory["reset_epoch"]>=0
        and digest(core,memory["opaque_state"])==memory["opaque_state_sha256"],"Withdrawal memory digest/sequence")
    opaque=memory["opaque_state"]
    require(set(opaque)=={"schema_version","model_sha256","mode","seed","episode_id","last_step","previous_binding","warning_state"}
        and opaque["schema_version"]=="locolemotion_residual_withdrawal_memory_v1"
        and opaque["model_sha256"]==model.sha256 and opaque["mode"]==mode and opaque["seed"]==request["seed"]
        and type(opaque["last_step"]) is int and opaque["last_step"]==step-1
        and request["request_id"]=="withdrawal_"+opaque["episode_id"]+"_"+str(step)
        and ((step==0 and opaque["previous_binding"] is None) or
            (step>0 and isinstance(opaque["previous_binding"],dict)
                and set(opaque["previous_binding"])=={"request_sha256","observation_sha256"})),
        "Withdrawal crossed/stale episode")
    state=warning.Memory(**opaque["warning_state"])
    require(state.episode_id==opaque["episode_id"] and state.reset_epoch==memory["reset_epoch"],
        "Withdrawal warning episode/reset join")
    require(request["safety_envelope"]["minimum_confidence"]==1.
        and request["safety_envelope"]["maximum_support_distance"]==1.,"Withdrawal immutable thresholds")
    feature=None;raw=None;unsupported=None
    try:feature=features.extract(core,request,opaque["previous_binding"])
    except (ValueError,KeyError,TypeError,OverflowError) as exc:unsupported="unsupported_observation: "+str(exc)
    if feature is not None:raw=model.policy.action(feature["values"])
    following,natural=warning.advance(model.warning,state,step,feature)
    forced=mode=="forced_route" and step==FORCED_COMMAND
    if forced:
        # This is a declared control request, not an invented observation or score.
        following=replace(following,withheld=True,clear_commands=0)
    withdraw=following.withheld and mode in ("frozen","forced_route")
    confidence=model.actor.confidence_ceiling if feature is not None else 0.
    distance=feature["support_distance"] if feature is not None else 0.
    corrections=[]
    if feature is None:status,reason="unsupported",unsupported
    elif step==0:status,reason="no_proposal","initial_baseline_observation"
    elif request["deterministic_baseline"]["safe_no_actuation"]:status,reason="no_proposal","deterministic_safe_no_actuation"
    elif mode=="disabled":status,reason="no_proposal","disabled_shadow_only"
    elif confidence<1.:status,reason="uncertain","artifact_confidence_ceiling"
    elif withdraw:
        status,reason,confidence="uncertain",("declared_route_withdrawal" if forced else "warning_withdrawal"),0.
    else:
        status,reason="applied","frozen_bounded_residual"
        corrections=[dict(actuator_id=a,canonical_velocity_delta_rad_s=v)
            for a,v in zip(features.ACTUATORS,raw,strict=True)]
    request_sha=digest(core,request)
    opaque.update(last_step=step,previous_binding=dict(request_sha256=request_sha,
        observation_sha256=features.observation_binding(core,request)),warning_state=following.__dict__)
    memory.update(sequence=step+1,opaque_state=opaque,opaque_state_sha256=digest(core,opaque))
    require(len(core.canonicalize_json(opaque)["canonical_json"].encode("utf-8"))<=4096,"Withdrawal memory capacity")
    response=dict(schema_version="sporespore_adaptation_provider_response_v1",request_id=request["request_id"],
        request_sha256=request_sha,status=status,confidence=confidence,support_distance=distance,
        ordered_corrections=corrections,next_memory=memory,
        provenance=dict(provider_id=PROVIDER_ID,provider_version=request["expected_provider_version"],
            model_id=model.model_id,model_sha256=model.sha256,training_corpus_id=model.corpus_id,
            training_corpus_sha256=model.corpus_sha256,seed=request["seed"],engine_specific_logic_used=False,
            direct_world_access_used=False,weights_mutated=False,physical_acceptance_authority=False),
        candidate_experience=None,diagnostics=["development withdrawal; no safe backup or calibrated probability",
            "decision:"+str(reason)],physical_acceptance_authority=False)
    detail=dict(mode=mode,step=step,model_sha256=model.sha256,actor_model_sha256=model.actor.sha256,
        warning_model_sha256=model.warning.sha256,features=feature,
        raw_correction_rad_s=list(raw) if raw is not None else None,status=status,reason=reason,
        warning=dict(natural_decision=natural,forced_route_request=forced,
            withheld=following.withheld,clear_commands=following.clear_commands,
            withdrawal_requested_for_mode=withdraw,
            withdrawal_applied_to_proposal=status=="uncertain" and reason in ("declared_route_withdrawal","warning_withdrawal")),
        confidence_is_calibrated=False,safe_backup_established=False)
    return response,detail


def call_provider(core,request,model,mode):
    if mode=="absent":return dict(provider_response=None,decision=None,provider_error=None)
    try:
        response,detail=respond(core,request,model,mode)
        return dict(provider_response=response,decision=detail,provider_error=None)
    except Exception as exc:
        return dict(provider_response=None,decision=None,provider_error=dict(type=type(exc).__name__,message=str(exc)))
