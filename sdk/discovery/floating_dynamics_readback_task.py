"""Bind the consumed oracle failure and a separate retained-readback closure."""
from pathlib import Path
import floating_dynamics_oracle_task as route
from floating_dynamics_oracle_task import ROOT,HERE,read,sha,require,FLAGS
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_floating_dynamics_oracle import inventory
from run_residual_native import verify_tests

CONTRACT=HERE/"floating_dynamics_readback_v1.json"
PARENT_RESULT=route.CONTRACT
ATTEMPT="sdk2-floating-dynamics-oracle-7ef8178d2b1f425bb334494b71d7ed92"
FREEZE="2c479b71cae6f8e246a9bceb3f5ade619daab622"
SOURCE_FILES=("floating_dynamics_readback_metadata.py","floating_dynamics_readback_task.py",
    "audit_floating_dynamics_readback.py","test_floating_dynamics_readback.py","run_floating_dynamics_readback.py")
SOURCES=SOURCE_FILES
GATES=(("oracle","test_floating_dynamics_oracle",26),("readback","test_floating_dynamics_readback",11))
CONTROLS=37
ORIGINAL_HASHES={
 "receipt.json":"6abc6abe80c344baa061c34d1433cc0615db42b02ed160e997029c15cd132e7f",
 "declaration.json":"2955432db024f030e8f89ae8488e7ac6150cd8d5d6b987a17d50d4ac4734c812",
 "gate-receipt.json":"9300693943704b4c13e733fc44d688a421d9b699f241eb83262120f896ed3bf8",
 "consumed.json":"1b7d16ef1c1ac44a25d95c4f0e179f36aa8f263dc33a27864eaa011a2c993387",
 "native/worker-result.json":"146f56543ddff08e68cf966c83c2298950a4223ec64d195941b436c37e9eed2d",
 "audit-reader/stderr.log":"dad4a1afc513ddcc47c5165da019d3f10997bc6699955610f033a9ebef4ac4ee"}


def expected_contract():
    return dict(schema_version="locolemotion_floating_dynamics_readback_contract_v1",
        ledger_scope=dict(subsystem="adaptation",engine_scope="mujoco_cpu",
            authority_mode="retained_native_dynamics_readback_closure",question_class="development"),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        original_attempt=ATTEMPT,original_source_commit=FREEZE,original_artifact_sha256=ORIGINAL_HASHES,
        original_route_contract_sha256=sha(route.CONTRACT),original_auditor_sha256=sha(HERE/"audit_floating_dynamics_oracle.py"),
        original_owner_ok=False,original_worker_ok=True,original_controls_passed=83,
        original_native_models=2,original_native_worlds=2,original_solver_steps=0,
        states=132,body_observations=1188,controls_required=CONTROLS,complete_reader_invocations=2,
        original_reader_gravity_assumption_m_s2=9.81,explicit_fixture_gravity_m_s2=9.8,
        metadata_gravity_authority="exact retained XML joined to every original canonical state",
        numerical_comparison_implementation="unchanged floating_dynamics_oracle_math.py",
        absolute_tolerance=1e-9,relative_tolerance=1e-9,original_tolerances_unchanged=True,
        reader_world_build_count=0,reader_solver_steps=0,**{k:False for k in FLAGS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Readback exact successor declaration");return c


def verify_attempt():
    c=declaration();folder=route.EVIDENCE/ATTEMPT
    for name,digest in ORIGINAL_HASHES.items():require(sha(folder/name)==digest,"Readback original artifact identity")
    receipt=read(folder/"receipt.json");owner=read(folder/"declaration.json")
    gate=read(folder/"gate-receipt.json");consumed=read(folder/"consumed.json")
    route.validate_launch(owner,gate,consumed,route.declaration(),FREEZE,ATTEMPT,
        ORIGINAL_HASHES["declaration.json"],ORIGINAL_HASHES["gate-receipt.json"])
    require(receipt["ok"] is False and receipt["zero_world_gate_passed"] is True
        and receipt["source_commit"]==FREEZE and receipt["constructed_models"]==receipt["constructed_cpu_worlds"]==2
        and receipt["constructed_gpu_worlds"]==receipt["solver_steps"]==0
        and receipt["safety_controls"]==gate["safety_controls"] and sum(receipt["safety_controls"].values())==83
        and "audit-reader" in receipt["error"] and all(receipt[k] is False for k in FLAGS),
        "Readback original failed owner remains failed")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(owner["binding"])
    for name,_,count in route.GATES:verify_tests(folder/(name+"-controls"),count)
    verify_tests(folder/"containment-controls",1)
    require(not (folder/"audit.json").exists() and not (folder/"reconstruction.json").exists(),
        "Readback original readers did not complete")
    import audit_floating_dynamics_oracle as original
    try:original.audit(folder/"native")
    except ValueError as exc:require(str(exc)=="Oracle model readback identity","Readback exact original refusal")
    else:raise ValueError("Readback original refusal was not reproduced")
    return folder,dict(original_owner_ok=False,original_worker_ok=True,original_controls_passed=83,
        original_refusal_reproduced=True,source_runtime_reverified=True,
        original_source_bindings=len(owner["binding"]["source"]),original_runtime_bindings=len(owner["binding"]["runtime"]))
