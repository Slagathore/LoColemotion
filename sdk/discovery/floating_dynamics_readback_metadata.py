"""Validate native model metadata against bound XML and every retained state."""
import xml.etree.ElementTree as ET
import numpy as np
from floating_base_dynamics_inputs import C,numeric
from actuation_recovery_mechanics import xyz,require


def verify_metadata(meta,xml,rows):
    option=ET.fromstring(xml).find("option")
    require(option is not None,"Readback explicit native options")
    gravity=numeric(option.get("gravity"),3,"Readback explicit XML gravity")
    require(len(rows)==66,"Readback complete metadata state population")
    for row in rows:
        expected=C.T @ xyz(row["request"]["state"]["gravity_world_m_s2"])
        require(np.array_equal(gravity,expected),"Readback XML/state gravity identity")
    require(meta==dict(nv=14,nq=15,nbody=10,nu=8,joint_dof_addresses=[0,*range(6,14)],
        body_rootid=[0]+[1]*9,armature=[0.]*6+[.01]*8,damping=[0.]*14,
        higher_order_damping_nonzero=0,gravity=gravity.tolist()),"Readback input-derived model identity")
    return gravity.tolist()
