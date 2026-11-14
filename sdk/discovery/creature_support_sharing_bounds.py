"""Affine static-request bounds shared by sharing control and retained diagnosis."""
import numpy as np
from actuation_recovery_mechanics import array, require


def bounded_load_scale(gravity, contact, ranges):
    """Static request -gravity-scale*contact inside bounds, with scale in [0,1].

    This intersects affine inequalities. It is a request bound at one measured
    posture, not an estimate of ground reaction or held-interval feasibility.
    """
    n = len(gravity)
    g = array(gravity, (n,), "Load scale gravity")
    c = array(contact, (n,), "Load scale contact")
    bounds = array(ranges, (n, 2), "Load scale ranges")
    require(n > 0 and np.all(bounds[:, 0] <= bounds[:, 1]), "Load scale ordered ranges")
    low, high = 0., 1.
    for offset, slope, (lo, hi) in zip(-g, -c, bounds, strict=True):
        if slope == 0.:
            if not lo <= offset <= hi:
                return None
            continue
        a, b = (lo-offset)/slope, (hi-offset)/slope
        low, high = max(low, min(a, b)), min(high, max(a, b))
        if low > high:
            return None
    return [float(low), float(high)]
