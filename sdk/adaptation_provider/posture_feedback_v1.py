"""Support-conditioned posture preference with a bounded host-owned envelope.

The preference changes the centre of the damped least-squares regularizer.
It is not an exact nullspace projection or a physical stability guarantee.
The original body-feedback implementation and its geometry remain immutable.
"""
import hashlib
import itertools
import json
from pathlib import Path

from . import stance_feedback_v1 as parent

CONTRACT = Path(__file__).with_suffix(".json")
require = parent.require


def expected_candidates():
    def row(name, mode, cap, slew, gain):
        return dict(id=name, mode=mode, factor=None if mode == "baseline" else 0.,
            ordered_coefficients=[0.]*8, attitude_gain_s_inv=0. if mode == "baseline" else 3.,
            angular_damping=0. if mode == "baseline" else .5, velocity_gain_s_inv=0.,
            maximum_absolute_correction_rad_s=cap, maximum_slew_per_step_rad_s=slew,
            posture_gain_s_inv=gain)
    result = [row("baseline", "baseline", .25, .02, 0.)]
    for (cap, a), (slew, s), (gain, p) in itertools.product(
            [(.25,"025"),(3.5,"350")], [(.02,"002"),(.08,"008")], [(0.,"0"),(8.,"8")]):
        result.append(row(f"feedback_a{a}_s{s}_p{p}", "feedback", cap, slew, gain))
    return result


def definition():
    value = json.loads(CONTRACT.read_text(encoding="utf-8"))
    require(value["schema_version"] == "locolemotion_posture_feedback_v1"
        and value["candidate_count"] == 9 and value["candidates"] == expected_candidates()
        and value["posture_reference_rad"] == dict(hip=-.3, knee=.6)
        and value["posture_scope"] == "observed_support_only"
        and value["envelope_selection"] == "prospectively_declared_candidate_bound_host_envelope"
        and all(value[k] is False for k in ["trained", "training_data_authority",
            "physical_acceptance_authority", "release_authority", "equivalence_authority"]), "Posture definition")
    for key, name in [("parent_model", "stance_feedback_v1.json"), ("parent_implementation", "stance_feedback_v1.py")]:
        path = CONTRACT.with_name(name)
        require(value[key] == dict(path="sdk/adaptation_provider/"+name,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest()), "Posture parent bytes")
    model = parent.definition()
    # There is no global envelope in this family: each host session must bind
    # the exact prospective candidate's limits into every provider request.
    del model["maximum_absolute_correction_rad_s"], model["maximum_slew_per_step_rad_s"]
    model.update(value)
    return model


def validate_candidate(candidate):
    require(candidate in expected_candidates(), "Posture candidate outside frozen factorial")
    parent.validate_candidate(candidate)


def validate_geometry(compiled, model):
    parent.validate_geometry(compiled, model)
    reference = model["posture_reference_rad"]
    for joint in compiled["morphology"]["morphology_spec"]["joints"]:
        target = reference[joint["joint_id"].rsplit("_", 1)[1]]
        require(joint["lower_limit_rad"] < target < joint["upper_limit_rad"], "Posture reference outside joint limits")


def posture_adjustment(jacobian, preferred, damping):
    """(I - J# J) u for damped J#; generally not an exact nullspace map."""
    velocity = [sum(j*v for j,v in zip(axis, preferred, strict=True)) for axis in jacobian]
    projected = parent.inverse_velocity(jacobian, velocity, damping)
    return [u-p for u,p in zip(preferred, projected, strict=True)]


def feedback(state, command, candidate, model):
    validate_candidate(candidate)
    body, detail = parent.feedback(state, command, candidate, model)
    angles = {r["joint_id"]: r["position_rad"] for r in state["ordered_joint_observations"]}
    reference, gain = model["posture_reference_rad"], candidate["posture_gain_s_inv"]
    combined = list(body)
    for i, (leg, receipt) in enumerate(zip(model["legs"], detail["legs"], strict=True)):
        q = [angles[leg["id"]+"_"+name] for name in ["hip", "knee"]]
        preferred = [gain*(reference[name]-value) for name,value in zip(["hip","knee"],q,strict=True)]
        if receipt["support"] and gain != 0.:
            _, jacobian = parent.foot_geometry(leg, *q)
            adjustment = posture_adjustment(jacobian, preferred, model["jacobian_damping_m"])
            combined[2*i:2*i+2] = [b+p for b,p in zip(body[2*i:2*i+2], adjustment, strict=True)]
        else:
            adjustment = [0.,0.]
        receipt.update(preferred_posture_velocity_rad_s=preferred,
            posture_regularization_delta_rad_s=adjustment, raw_combined_rad_s=combined[2*i:2*i+2])
    detail.update(posture_reference_rad=reference, posture_gain_s_inv=gain)
    return combined, detail
