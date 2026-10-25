"""Serialization-only reader successor; the v2 controller remains unchanged."""
from dynamic_control_component_task_v3 import *
import dynamic_control_component_task_v3 as parent
from dynamic_control_empty_force_failure import ATTEMPT as EMPTY_ATTEMPT,RECEIPT_SHA as EMPTY_SHA,verify_failure as verify_empty

CONTRACT=HERE/"dynamic_control_component_v4.json"
SOURCES=(*parent.SOURCES,"dynamic_control_component_task_v4.py","audit_dynamic_control_component_v4.py",
    "run_dynamic_control_component_v4.py","test_dynamic_control_audit_v4.py","dynamic_control_empty_force_failure.py")
GATES=(*parent.GATES,("empty-force","test_dynamic_control_audit_v4",3))
CONTROLS=sum(n for _,_,n in GATES)


def expected_contract():
    c=parent.expected_contract()
    c.update(schema_version="locolemotion_dynamic_control_component_contract_v4",
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        consumed_empty_force_reader=dict(attempt_id=EMPTY_ATTEMPT,receipt_sha256=EMPTY_SHA,command=160,controls_passed=107),
        controls_required=CONTROLS,safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        controller_v2_bytes_unchanged=True,empty_contact_force_shape=[0,3])
    return c


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Dynamic exact serialization successor declaration");return c


def verify_inputs(c):
    require(c==declaration(),"Dynamic serialization successor contract")
    value=parent.verify_inputs(parent.declaration());value["consumed_empty_force_reader"]=verify_empty()
    return value
