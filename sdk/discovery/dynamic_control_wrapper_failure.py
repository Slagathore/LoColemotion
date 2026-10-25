"""Verify the consumed v2 wrapper's pre-population provenance error."""
from dynamic_control_failure import ROOT,read,sha,require,validate_bindings,verify_population,inventory,verify_tests
import dynamic_control_component_task_v2 as original

ATTEMPT="sdk2-dynamic-control-component-v2-93d02d572ac54a12900e18c4ce6e3e2a"
RECEIPT_SHA="724a87602582505bd8a33f910f656a4d3f2e93d6e16cbe5c515e44a1b2b96eaf"


def verify_failure():
    folder=ROOT.parent/"SporeSpore_Evidence"/ATTEMPT;receipt=read(folder/"receipt.json")
    require(sha(folder/"receipt.json")==RECEIPT_SHA and receipt["ok"] is False and receipt["controls_passed"]==105
        and receipt["worlds_opened"]==receipt["solver_steps"]==0 and not (folder/"audit").exists()
        and not (folder/"audit.json").exists() and not (folder/"reconstruction.json").exists(),
        "Dynamic consumed wrapper failure before population")
    verify_population(receipt["artifacts"],inventory(folder))
    declaration=read(folder/"declaration.json");validate_bindings(declaration["binding"])
    for name,_,count in original.GATES:verify_tests(folder/(name+"-controls"),count)
    try:original.verify_inputs(original.declaration())
    except TypeError as exc:require(str(exc)=="sha() takes 1 positional argument but 2 were given","Dynamic exact wrapper failure")
    else:raise ValueError("Dynamic wrapper failure was not reproduced")
    return dict(attempt_id=ATTEMPT,receipt_sha256=RECEIPT_SHA,ok=False,controls_passed=105,
        exception="TypeError",message="sha() takes 1 positional argument but 2 were given",refusal_reproduced=True,
        retained_states_processed=0,complete_readers=0,world_build_count=0,solver_steps=0)
