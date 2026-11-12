"""One prepared-state host copy per field, using the pinned engine's converter.

The lease ends before controller application or integration. No native step,
field omission, world reset, or persistent observation cache is introduced.
"""
import copy
from dataclasses import fields, is_dataclass
import math

import numpy as np
import warp as wp

from creature_batch import require
from audit_gpu_batch_execution import same_bits
from gpu_batch_execution import CAPTURE_FIELDS
from portable_search_control import VIEW_FIELDS


def options(c):
    value = c.get("readback", {"mode": "per_world", "reference_check": False})
    require(type(value) is dict and set(value) == {"mode", "reference_check"}
            and value["mode"] in ("per_world", "shared_snapshot")
            and type(value["reference_check"]) is bool, "Creature readback options")
    require(not value["reference_check"] or
            (value["mode"] == "shared_snapshot" and c["mode"] == "route_ghost"),
            "Creature readback reference scope")
    require(c["native_reads_reduced"] is (value["mode"] == "shared_snapshot"),
            "Creature readback reduction declaration")
    return value


class _HostArray:
    def __init__(self, owner, path, source):
        self.owner, self.path, self.source = owner, path, source
        self.shape = tuple(source.shape)

    def numpy(self):
        require(self.owner.active, "Creature readback lease closed")
        self.owner.requests += 1
        if self.path not in self.owner.arrays:
            # Own the bytes even for CPU-backed fixtures; never alias native data.
            value = self.source.numpy().copy(order="C")
            require(value.dtype.kind in "biuf", "Creature readback array dtype")
            value.setflags(write=False)
            self.owner.arrays[self.path] = value
        return self.owner.arrays[self.path]


class PreparedReadback:
    """Single-use lease: callers finish all host observations before leaving it."""
    def __init__(self, data):
        self.active, self.used, self.requests, self.arrays = False, False, 0, {}
        def wrap(value, path):
            if isinstance(value, wp.array):
                return _HostArray(self, path, value)
            if is_dataclass(value):
                result = copy.copy(value)
                for field in fields(value):
                    child = field.name if not path else path + "." + field.name
                    object.__setattr__(result, field.name, wrap(getattr(value, field.name), child))
                return result
            if isinstance(value, (tuple, list)):
                items = [wrap(v, path + "[" + str(i) + "]") for i, v in enumerate(value)]
                return tuple(items) if isinstance(value, tuple) else items
            require(value is None or isinstance(value, (bool, int, float, str, bytes, np.generic)),
                    "Unsupported readback field: " + path)
            return value
        self.data = wrap(data, "")

    def __enter__(self):
        require(not self.used, "Creature readback lease reused")
        self.active = self.used = True
        return self

    def __exit__(self, *_):
        self.active = False

    def report(self):
        require(self.used and not self.active, "Creature readback report before closure")
        return dict(device_arrays_read=len(self.arrays), numpy_requests=self.requests,
            fields=[dict(path=path, shape=list(value.shape), dtype=value.dtype.str, bytes=value.nbytes)
                    for path, value in sorted(self.arrays.items())])


def reference_order(outer):
    return ["shared", "reference"] if outer % 2 == 0 else ["reference", "shared"]


def validate_record(row, c, outer, controls):
    opt = options(c)
    require(opt["mode"] == "shared_snapshot" and type(row) is dict
            and set(row) == {"outer_step", "device_arrays_read", "numpy_requests", "fields", "order", "reference"}
            and type(row["outer_step"]) is int and row["outer_step"] == outer
            and len(controls) == len(c["cells"]), "Creature readback row")
    entries = row["fields"]
    require(type(entries) is list and entries and all(type(v) is dict for v in entries), "Creature readback field list")
    names = [v.get("path") for v in entries]
    require(all(type(p) is str and p for p in names) and names == sorted(set(names))
            and set(CAPTURE_FIELDS + VIEW_FIELDS).issubset(names), "Creature readback fields omitted or repeated")
    require(type(row["device_arrays_read"]) is int and row["device_arrays_read"] == len(entries)
            and type(row["numpy_requests"]) is int and row["numpy_requests"] >= len(entries),
            "Creature readback transfer accounting")
    for entry in entries:
        require(set(entry) == {"path", "shape", "dtype", "bytes"} and type(entry["shape"]) is list
                and all(type(n) is int and n >= 0 for n in entry["shape"])
                and type(entry["dtype"]) is str and type(entry["bytes"]) is int, "Creature readback field shape")
        dtype = np.dtype(entry["dtype"])
        require(dtype.kind in "biuf" and entry["bytes"] == math.prod(entry["shape"])*dtype.itemsize,
                "Creature readback byte accounting")
        if entry["path"] in VIEW_FIELDS + ["time", "overflow", "nefc"]:
            require(entry["shape"] and entry["shape"][0] == len(c["cells"]), "Creature readback world dimension")
    expected_order = reference_order(outer) if opt["reference_check"] else ["shared"]
    require(row["order"] == expected_order and type(row["reference"]) is list, "Creature readback order")
    require(len(row["reference"]) == (len(controls) if opt["reference_check"] else 0), "Creature readback reference denominator")
    for index, (reference, control) in enumerate(zip(row["reference"], controls)):
        require(type(reference) is dict and set(reference) == {"cell", "observation", "native_observation", "contact_compatibility_copy"}
                and type(reference["cell"]) is int and reference["cell"] == control["cell"] == index
                and control["outer_step"] == outer,
                "Creature readback reference identity")
        binding = control["binding"]
        observation = dict(cell_id=binding["cell_id"], descriptor_sha256=binding["descriptor_sha256"],
            model_xml_sha256=binding["model_xml_sha256"], state=control["request"]["state"],
            stability=control["stability"], kinematics=control["kinematics"])
        require(same_bits(reference["observation"], observation)
                and same_bits(reference["native_observation"], control["native_observation"])
                and same_bits(reference["contact_compatibility_copy"], control["contact_compatibility_copy"]),
                "Creature shared and original readback differ")
    return dict(device_arrays_read=row["device_arrays_read"], numpy_requests=row["numpy_requests"],
                reference_observations_checked=len(row["reference"]))
