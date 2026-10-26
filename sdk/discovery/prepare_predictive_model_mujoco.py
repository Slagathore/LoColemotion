"""MuJoCo model preparation only; never called during provider selection."""
import copy
import xml.etree.ElementTree as ET
import numpy as np
from held_contact_rollout import HeldContactRollout,C
from floating_base_dynamics_inputs import native_parameters,numeric
from prepared_predictive_model import SCHEMA,FRAME,law,validate_model


def prepare(profile,xml):
    # The consumed parser checks the supported XML subset and the exact
    # morphology/motor joins before any native label is removed from the data.
    original=HeldContactRollout(profile,xml)
    parameters=native_parameters(xml,profile["morphology_spec"])
    root=numeric(ET.fromstring(xml).find("worldbody/body").get("pos"),3,"Prepared adapter reference")
    geometry=[]
    for g in original.geometry:
        shape=dict(body_id=g["body_id"],kind=g["kind"])
        if g["kind"]=="box":shape["halfsize_m"]=np.abs(C @ g["size"]).tolist()
        else:shape.update(radius_m=g["radius"],endpoints_local_m=(g["endpoints"] @ C.T).tolist())
        geometry.append(shape)
    result=dict(schema_version=SCHEMA,coordinate_frame_id=FRAME,law=law(),
        morphology_spec=copy.deepcopy(profile["morphology_spec"]),
        joint_inertia_kg_m2=parameters["joint_inertia_kg_m2"],
        velocity_gains=copy.deepcopy(profile["velocity_gains"]),force_ranges=copy.deepcopy(profile["force_ranges"]),
        reference_position_m=(C @ root).tolist(),ordered_geometry=geometry)
    validate_model(result)
    return result
