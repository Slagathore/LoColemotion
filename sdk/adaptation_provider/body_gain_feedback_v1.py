"""Finite body-attitude/rate factorial with the existing support-posture objective."""
import hashlib
import itertools
import json
from pathlib import Path
from . import posture_feedback_v1 as parent
from . import stance_feedback_v1 as body

CONTRACT = Path(__file__).with_suffix(".json")
require = parent.require
validate_geometry = parent.validate_geometry
posture_adjustment = parent.posture_adjustment


def expected_candidates():
    baseline = dict(parent.expected_candidates()[0])
    reference = parent.expected_candidates()[8]
    return [baseline] + [dict(reference, id=f"feedback_kp{k}_kd{label}",
        attitude_gain_s_inv=float(k), angular_damping=rate)
        for k,(rate,label) in itertools.product([3,6],[(.5,"05"),(1.,"10")])]


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value["schema_version"] == "locolemotion_body_gain_feedback_v1"
        and value["candidate_count"] == 5 and value["candidates"] == expected_candidates()
        and value["posture_reference_rad"] == dict(hip=-.3,knee=.6)
        and value["posture_scope"] == "observed_support_only"
        and value["envelope_selection"] == "prospectively_declared_candidate_bound_host_envelope"
        and all(value[k] is False for k in ["trained","training_data_authority",
            "physical_acceptance_authority","release_authority","equivalence_authority"]), "Body-gain definition")
    for key,name in [("parent_model","posture_feedback_v1.json"),("parent_implementation","posture_feedback_v1.py")]:
        path = CONTRACT.with_name(name)
        require(value[key] == dict(path="sdk/adaptation_provider/"+name,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest()), "Body-gain parent bytes")
    model = parent.definition(); model.update(value)
    return model


def validate_candidate(candidate):
    require(candidate in expected_candidates(), "Body-gain candidate outside frozen factorial")
    body.validate_candidate(candidate)


def feedback(state, command, candidate, model):
    validate_candidate(candidate)
    delta,detail = body.feedback(state,command,candidate,model)
    angles = {r["joint_id"]:r["position_rad"] for r in state["ordered_joint_observations"]}
    reference,gain = model["posture_reference_rad"],candidate["posture_gain_s_inv"]
    combined = list(delta)
    for i,(leg,receipt) in enumerate(zip(model["legs"],detail["legs"],strict=True)):
        q = [angles[leg["id"]+"_"+name] for name in ["hip","knee"]]
        preferred = [gain*(reference[name]-value) for name,value in zip(["hip","knee"],q,strict=True)]
        if receipt["support"] and gain != 0.:
            _,jacobian = body.foot_geometry(leg,*q)
            adjustment = posture_adjustment(jacobian,preferred,model["jacobian_damping_m"])
            combined[2*i:2*i+2] = [b+p for b,p in zip(delta[2*i:2*i+2],adjustment,strict=True)]
        else:
            adjustment = [0.,0.]
        receipt.update(preferred_posture_velocity_rad_s=preferred,
            posture_regularization_delta_rad_s=adjustment,raw_combined_rad_s=combined[2*i:2*i+2])
    detail.update(posture_reference_rad=reference,posture_gain_s_inv=gain)
    return combined,detail
