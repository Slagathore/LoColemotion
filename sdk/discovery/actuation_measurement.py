"""Measurement semantics for new discovery; never rescore a frozen campaign.

The scalar implicitfast oracle applies only to a constant-inertia, unloaded,
single hinge with one affine velocity actuator and no other force channels.
It is deliberately not an inverse-dynamics estimator for contact-rich bodies.
"""
from __future__ import annotations

import math


def finite(value: float, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ValueError(f"Invalid {name}")
    return float(value)


def positive(value: float, name: str) -> float:
    value = finite(value, name)
    if value <= 0:
        raise ValueError(f"Nonpositive {name}")
    return value


def scalar_implicitfast_step(*, velocity: float, target: float, inertia: float,
                             damping: float, force_cap: float, dt: float) -> dict:
    """Solve the pinned scalar equation, including the force-clamp derivative.

    MuJoCo 3.11.0 omits the velocity derivative when force is at either limit.
    Otherwise (I + dt*k) * delta_v = dt*k*(target-v). Re-evaluating force at
    v_next describes effective impulse only in that unsaturated scalar case.
    """
    v, target = finite(velocity, "velocity"), finite(target, "target")
    inertia, damping = positive(inertia, "inertia"), positive(damping, "damping")
    cap, dt = positive(force_cap, "force_cap"), positive(dt, "dt")
    requested = damping * (target - v)
    force = max(-cap, min(cap, requested))
    saturated = abs(force) >= cap
    delta_v = dt * force / (inertia if saturated else inertia + dt * damping)
    post = max(-cap, min(cap, damping * (target - (v + delta_v))))
    result = dict(velocity_next_rad_s=v + delta_v,
                  completed_step_force_nm=force,
                  post_state_force_nm=post,
                  force_clamped=saturated,
                  absolute_force_time_budget_nms=abs(force) * dt,
                  effective_motor_impulse_nms=inertia * delta_v)
    for key, value in result.items():
        if key != "force_clamped":
            finite(value, key)
    return result


def rapier_impulse_summary(*, outer_budget_nms: float, outer_dt_s: float,
                          substeps: int, final_readback_nms: float,
                          signed_substep_impulses: list[float] | None = None) -> dict:
    """Keep final readback separate from an explicitly measured substep sum.

    A last-substep value cannot reconstruct earlier varying loads. Exact sums
    require a complete same-coordinate sequence, or the existing qualified
    solver-application observer, not last_impulse * substeps.
    """
    budget = positive(outer_budget_nms, "budget")
    dt = positive(outer_dt_s, "dt")
    final = finite(final_readback_nms, "final_readback")
    if type(substeps) is not int or not 1 <= substeps <= 1024:
        raise ValueError("Invalid substep count")
    result = dict(max_force_nm=budget / dt, substep_cap_nms=budget / substeps,
                  final_substep_readback_nms=final, outer_signed_impulse_nms=None,
                  outer_absolute_impulse_nms=None, outer_impulse_measured=False)
    if signed_substep_impulses is not None:
        if len(signed_substep_impulses) != substeps:
            raise ValueError("Incomplete substep impulse population")
        values = [finite(v, "substep impulse") for v in signed_substep_impulses]
        if values[-1] != final:
            raise ValueError("Final impulse does not match substep stream")
        result.update(outer_signed_impulse_nms=math.fsum(values),
                      outer_absolute_impulse_nms=math.fsum(abs(v) for v in values),
                      outer_impulse_measured=True)
    return result


def named_force_samples(model, data, actuator: str, joint: str) -> dict:
    """Read explicit sensors immediately after stepping, before any forward.

    The model must declare actuatorfrc '<actuator>_force' and jointactuatorfrc
    '<joint>_actuator_force'. Validate object identity as well as the name: a
    sensor pointed at another joint must not silently become a training label.
    """
    import mujoco

    result = {}
    for name, expected_type, object_id, field in (
        (actuator + "_force", mujoco.mjtSensor.mjSENS_ACTUATORFRC,
         model.actuator(actuator).id, "actuator_force_nm"),
        (joint + "_actuator_force", mujoco.mjtSensor.mjSENS_JOINTACTFRC,
         model.joint(joint).id, "joint_actuator_force_nm"),
    ):
        sensor_id = model.sensor(name).id
        if (int(model.sensor_type[sensor_id]) != int(expected_type)
                or int(model.sensor_objid[sensor_id]) != object_id
                or int(model.sensor_dim[sensor_id]) != 1):
            raise ValueError("Force sensor binding mismatch: " + name)
        result[field] = finite(float(data.sensordata[int(model.sensor_adr[sensor_id])]), name)
    return result
