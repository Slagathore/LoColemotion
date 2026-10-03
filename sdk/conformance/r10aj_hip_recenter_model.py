"""Prospective hip-only placement model; no native admission or world control.

Aim the hip-to-foot vector along gravity projected into the authored sagittal
joint plane. Knees keep their measured angle, except explicit limit return.
This does not treat a modeled ground penetration as native support.
"""
import math

import r10af_rise_tracking_analysis as geometry
import r10ab_loaded_rise_diagnosis as vectors

DT = 1.0/120.0
FOOT_SPEED = .1
JOINT_SPEED = 4.0


def plan(descriptor, orientation, measured, active):
    if len(measured) != 8 or len(active) != 4 or not all(type(v) is bool for v in active):
        raise ValueError('RECENTER_POPULATION')
    if not all(math.isfinite(x) for x in measured): raise ValueError('RECENTER_NONFINITE')
    if set(orientation) != {'x','y','z','w'} or not all(math.isfinite(v) for v in orientation.values()):
        raise ValueError('RECENTER_ORIENTATION')
    if abs(sum(v*v for v in orientation.values())-1.) > 1e-5: raise ValueError('RECENTER_QUATERNION')
    if not all(abs(q) <= (1.6 if j%2==0 else 1.1)+JOINT_SPEED*DT for j,q in enumerate(measured)):
        raise ValueError('RECENTER_SOURCE_JOINT_RANGE')
    upper = .35*descriptor['upper_length_fraction']; lower = .35-upper
    if not (0 < upper < .35): raise ValueError('RECENTER_GEOMETRY')
    down = vectors.rotate(vectors.inverse(orientation),[0.,-1.,0.])
    projection = math.hypot(down[0],down[1])
    targets = [max(-(1.6 if j%2==0 else 1.1),min(1.6 if j%2==0 else 1.1,q)) for j,q in enumerate(measured)]
    if projection < 1e-12:
        return dict(targets=targets,hold_reason='gravity_normal_to_joint_plane',active=active,
            desired_hip_angles=[None]*4,hip_step_bounds=[0.]*4)
    desired_leg_angle = math.atan2(down[0],-down[1])
    desired, bounds = [], []
    for i in range(4):
        knee = targets[2*i+1]
        beta = math.atan2(lower*math.sin(knee),upper+lower*math.cos(knee))
        goal = desired_leg_angle-beta
        # The fixed target interval has no wrap; evaluate equivalent angles and
        # retain the one nearest the actual source before enforcing limits.
        goal = min((goal-2*math.pi,goal,goal+2*math.pi),key=lambda v:abs(v-measured[2*i]))
        goal = max(-1.6,min(1.6,goal))
        radius = math.hypot(upper+lower*math.cos(knee),lower*math.sin(knee))
        bound = min(JOINT_SPEED*DT, FOOT_SPEED*DT/radius)
        desired.append(goal);bounds.append(bound)
        if active[i]:
            delta = max(-bound,min(bound,goal-measured[2*i]))
            targets[2*i] = max(-1.6,min(1.6,measured[2*i]+delta))
    assert all(abs(t-q) <= JOINT_SPEED*DT+1e-12 for t,q in zip(targets,measured))
    return dict(targets=targets,hold_reason=None,active=active,
        desired_hip_angles=desired,hip_step_bounds=bounds)


def displacement(descriptor, orientation, before, after):
    old,new = geometry.fk(descriptor,before),geometry.fk(descriptor,after)
    return [geometry.rotate(orientation,[b[j]-a[j] for j in range(3)]) for a,b in zip(old,new)]
