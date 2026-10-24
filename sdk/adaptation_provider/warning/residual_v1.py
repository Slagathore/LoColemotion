"""Causal development failure warnings; scores are not safety probabilities."""
from dataclasses import dataclass
import hashlib
import json
import math
from pathlib import Path

from .. import bounded_residual_features_v1 as features
from ..bounded_residual_ars_v1 import require,finite

ROOT=Path(__file__).resolve().parents[3]
CONTRACT=Path(__file__).with_suffix(".json")
EXTRA=("episode_fraction","tilt_fraction","linear_speed_fraction","angular_speed_fraction",
       "max_joint_speed_fraction","max_response_error_fraction","support_fraction")
NAMES=features.NAMES+EXTRA
FEATURE_KEYS={"schema_version","names","values","history_entries","previous_semantic_step",
    "previous_request_sha256","previous_resolution_sha256","exact_local_phase_commands",
    "support_distance","confidence_is_calibrated"}
DIMENSION=len(NAMES)
HORIZON=1440
LOOKAHEAD=30
REENTRY=30
HYSTERESIS=.05


def sha(path):
    with Path(path).open("rb") as stream:return hashlib.file_digest(stream,"sha256").hexdigest()


def encode_json(value):
    return json.dumps(value,sort_keys=True,separators=(",",":"),allow_nan=False)


def digest(value):return "sha256:"+hashlib.sha256(encode_json(value).encode("utf-8")).hexdigest()


def scales():
    values=[]
    for name in features.NAMES:
        if name.startswith("linear_velocity_body_m_s_"):scale=10.
        elif name.startswith("angular_velocity_body_rad_s_"):scale=20.
        elif name.startswith("desired_velocity_body_m_s_"):scale=.2
        elif name.endswith("_position_rad"):scale=math.pi
        elif name.endswith("_velocity_rad_s"):scale=20.
        elif any(name.endswith("_"+s) for s in ("baseline_command_rad_s","maximum_command_speed_rad_s",
                "previous_final_command_rad_s","previous_correction_rad_s")):scale=3.5
        elif name.endswith("_previous_response_error_rad_s"):scale=40.
        else:scale=1.
        values.append(scale)
    return tuple(values)


SCALES=scales()


def expected_definition():
    return dict(schema_version="locolemotion_residual_warning_definition_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",
            authority_mode="development_warning_component",question_class="development"),
        feature_schema=features.schema(),feature_names=list(NAMES),feature_count=DIMENSION,
        fixed_scales=list(SCALES),maximum_episode_commands=HORIZON,
        target="first physical violation or safe-no-actuation in the next 30 commands",
        lookahead_commands=LOOKAHEAD,score="regularized_linear_warning_score_not_probability",
        current_state_and_actual_prior_action_only=True,privileged_motor_parameters=False,
        enter="score >= entry_threshold or unsupported observation",
        leave="30 consecutive supported scores strictly below exit_threshold",
        exit_threshold_offset=HYSTERESIS,reentry_commands=REENTRY,
        calibration_scope="retrospective_grouped_training_crossfit_only",
        confidence_is_calibrated=False,probabilistic_risk_guarantee=False,safe_backup_established=False,
        source_bindings={str(p.relative_to(ROOT)).replace("\\","/"):sha(p)
            for p in (Path(__file__),Path(features.__file__))},
        physical_launch_authority=False,physical_acceptance_authority=False,
        tier2_complete=False,tier3_complete=False,release_authority=False)


def definition():
    value=json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value==expected_definition(),"Warning definition/source bindings")
    return value


def encode(feature,step):
    """Encode only the contemporaneous actor feature, never its future label."""
    require(type(step) is int and 0<=step<HORIZON,"Warning episode clock/domain")
    require(isinstance(feature,dict) and set(feature)==FEATURE_KEYS
        and feature["schema_version"]==features.SCHEMA and feature["names"]==list(features.NAMES)
        and feature["confidence_is_calibrated"] is False
        and type(feature["history_entries"]) is int and feature["history_entries"]==int(step>0)
        and feature["previous_semantic_step"]==(step-1 if step else None)
        and finite(feature["support_distance"]) and 0<=feature["support_distance"]<=1.,
        "Warning feature identity/domain")
    for key in ("previous_request_sha256","previous_resolution_sha256"):
        value=feature[key]
        require(value is None if step==0 else (
            isinstance(value,str) and len(value)==71 and value.startswith("sha256:")
            and all(c in "0123456789abcdef" for c in value[7:])),"Warning prior action digest")
    phases=feature["exact_local_phase_commands"]
    require(isinstance(phases,list) and len(phases)==4
        and all(type(v) is int and 0<=v<360 for v in phases),"Warning exact phase domain")
    raw=feature["values"]
    require(isinstance(raw,list) and len(raw)==len(SCALES) and all(finite(v) for v in raw),
        "Warning finite feature vector")
    x=tuple(v/s for v,s in zip(raw,SCALES,strict=True))
    require(all(abs(v)<= (2. if i<6 else 1.+1e-12) for i,v in enumerate(x)),
        "Warning normalized mechanical domain")
    named=dict(zip(features.NAMES,raw,strict=True))
    require(named["previous_action_available"]==float(step>0),"Warning action availability")
    require(.2<=named["height_m"]<=1.
        and all(named["morphology_"+k]==features.DESCRIPTOR[k] for k in features.MORPHOLOGY_FIELDS)
        and all(named[leg+"_observed_support"] in (0.,1.) for leg in features.LEGS),
        "Warning morphology/height/support")
    def norm(prefix):return math.sqrt(math.fsum(named[prefix+"_"+axis]**2 for axis in "xyz"))
    tilt=math.acos(max(-1.,min(1.,named["up_body_y"])))
    extra=(step/HORIZON,tilt/.6,norm("linear_velocity_body_m_s")/10.,
        norm("angular_velocity_body_rad_s")/20.,
        max(abs(named[j+"_velocity_rad_s"]) for j in features.JOINTS)/20.,
        max(abs(named[j+"_previous_response_error_rad_s"]) for j in features.JOINTS)/40.,
        math.fsum(named[leg+"_observed_support"] for leg in features.LEGS)/4.)
    require(all(finite(v) and 0<=v<=1.+1e-12 for v in extra),"Warning derived feature domain")
    return x+extra


def score(weights,vector):
    require(len(weights)==DIMENSION+1 and len(vector)==DIMENSION
        and all(finite(v) for v in (*weights,*vector)),"Warning score shape/finiteness")
    result=math.fsum([weights[0]]+[w*x for w,x in zip(weights[1:],vector,strict=True)])
    require(finite(result),"Warning score overflow")
    return result


@dataclass(frozen=True)
class FrozenWarning:
    weights:tuple
    entry_threshold:float
    exit_threshold:float
    serialized:str
    sha256:str

    @classmethod
    def load(cls,value):
        require(isinstance(value,dict) and set(value)=={"schema_version","definition","weights",
            "entry_threshold","exit_threshold","training"},"Warning model shape")
        require(value["schema_version"]=="locolemotion_residual_warning_model_v1"
            and value["definition"]==definition(),"Warning model definition")
        weights=tuple(value["weights"])
        require(len(weights)==DIMENSION+1 and all(finite(v) and abs(v)<=1e6 for v in weights),
            "Warning model weights")
        enter,leave=value["entry_threshold"],value["exit_threshold"]
        require(finite(enter) and finite(leave) and leave==enter-HYSTERESIS,
            "Warning hysteresis thresholds")
        training=value["training"]
        require(set(training)=={"kind","data_sha256","recipe_sha256","training_trial_count",
            "comparison_trials_used","reserved_starts_opened","held_out_start_id"}
            and ((training["kind"]=="retrospective_complete_training_population"
                and training["training_trial_count"]==64 and training["held_out_start_id"] is None)
                or (training["kind"]=="retrospective_grouped_training_fold"
                and training["training_trial_count"]==48
                and training["held_out_start_id"] in ("train_001","train_003","train_004","train_006")))
            and training["comparison_trials_used"]==0
            and training["reserved_starts_opened"]==0,"Warning training provenance")
        for key in ("data_sha256","recipe_sha256"):
            s=training[key]
            require(isinstance(s,str) and len(s)==71 and s.startswith("sha256:")
                and all(c in "0123456789abcdef" for c in s[7:]),"Warning data/recipe digest")
        encoded=encode_json(value)
        return cls(weights,float(enter),float(leave),encoded,digest(value))

    def document(self):return json.loads(self.serialized)

    def predict(self,feature,step):return score(self.weights,encode(feature,step))


@dataclass(frozen=True)
class Memory:
    model_sha256:str
    episode_id:str
    reset_epoch:int
    last_step:int=-1
    withheld:bool=False
    clear_commands:int=0


def empty_memory(model,episode_id,reset_epoch=0):
    require(isinstance(episode_id,str) and 0<len(episode_id)<=96
        and all(c.isascii() and (c.isalnum() or c in "_-") for c in episode_id)
        and type(reset_epoch) is int and reset_epoch>=0,"Warning episode/reset identity")
    return Memory(model.sha256,episode_id,reset_epoch)


def advance_score(model,memory,step,value):
    require(isinstance(memory,Memory) and memory.model_sha256==model.sha256
        and type(step) is int and type(memory.last_step) is int
        and step==memory.last_step+1 and 0<=step<HORIZON
        and isinstance(memory.episode_id,str) and 0<len(memory.episode_id)<=96
        and all(c.isascii() and (c.isalnum() or c in "_-") for c in memory.episode_id)
        and type(memory.reset_epoch) is int and memory.reset_epoch>=0
        and (step>0 or (memory.withheld is False and memory.clear_commands==0))
        and type(memory.withheld) is bool and type(memory.clear_commands) is int
        and 0<=memory.clear_commands<REENTRY
        and (memory.withheld or memory.clear_commands==0)
        and (value is None or finite(value)),"Warning state/clock/model")
    if value is None:
        withheld,clear,reason=True,0,"unsupported_observation"
    elif value>=model.entry_threshold:
        withheld,clear,reason=True,0,"prediction_threshold"
    elif memory.withheld:
        clear=memory.clear_commands+1 if value<model.exit_threshold else 0
        withheld=clear<REENTRY
        reason="hysteresis_hold" if withheld else "supported_reentry"
        if not withheld:clear=0
    else:withheld,clear,reason=False,0,"supported_below_threshold"
    following=Memory(model.sha256,memory.episode_id,memory.reset_epoch,step,withheld,clear)
    return following,dict(step=step,score=value,withdraw_requested=withheld,reason=reason,
        entry_threshold=model.entry_threshold,exit_threshold=model.exit_threshold,
        clear_commands=clear,model_sha256=model.sha256,confidence_is_calibrated=False,
        safe_backup_established=False,physical_acceptance_authority=False)


def advance(model,memory,step,feature):
    # Invalid or unavailable features can only request withdrawal; they cannot
    # manufacture a low risk score. Clock/model errors remain terminal.
    try:value=model.predict(feature,step) if feature is not None else None
    except (ValueError,KeyError,TypeError,OverflowError):value=None
    return advance_score(model,memory,step,value)
