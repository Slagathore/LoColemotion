"""Measured-motion joint command shaping, opt-in and simulator independent.

The acceleration parameter shapes a stopping-speed envelope. It is a declared
estimate, not a verified actuator deceleration or a physical safety guarantee.
The caller must still apply its observed-bound guard and record every breach.
"""
import math

SCHEMA = "locolemotion_anticipatory_joint_braking_v1"
FIELDS = ("schema_version", "margin_rad", "lookahead_steps", "braking_acceleration_rad_s2")


def require(ok, message):
    if not ok:
        raise ValueError(message)


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def policy(value):
    require(type(value) is dict and set(value) == set(FIELDS), "Joint braking policy fields")
    require(value["schema_version"] == SCHEMA
            and finite(value["margin_rad"]) and .01 <= value["margin_rad"] <= .08
            and type(value["lookahead_steps"]) is int and 1 <= value["lookahead_steps"] <= 4
            and finite(value["braking_acceleration_rad_s2"])
            and 1. <= value["braking_acceleration_rad_s2"] <= 20., "Joint braking policy bounds")
    return value.copy()


def shape(position, velocity, command, speed, lower, upper, dt, settings):
    """Pure command envelope; measured velocity determines the projected reserve."""
    p = policy(settings)
    require(all(finite(v) for v in (position, velocity, command, speed, lower, upper, dt))
            and lower < 0 < upper and 0 < speed <= 3.5 and 0 < dt <= .1
            and abs(command) <= speed, "Joint braking finite input or bounds")
    predicted = position + velocity * dt * p["lookahead_steps"]
    require(math.isfinite(predicted), "Joint braking projected position overflow")
    acceleration = p["braking_acceleration_rad_s2"]
    # Clip the distance first: a distant boundary cannot increase the speed cap.
    distance_cap = speed * speed / (2 * acceleration)
    low_distance = max(0., min(distance_cap, predicted - lower - p["margin_rad"]))
    high_distance = max(0., min(distance_cap, upper - predicted - p["margin_rad"]))
    low = -min(speed, math.sqrt(2 * acceleration * low_distance))
    high = min(speed, math.sqrt(2 * acceleration * high_distance))
    shaped = max(low, min(high, command))
    return dict(predicted_position_rad=predicted, lower_velocity_rad_s=low,
        upper_velocity_rad_s=high, incoming_velocity_rad_s=command,
        shaped_velocity_rad_s=shaped, applied=shaped != command)
