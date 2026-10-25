"""Exact inputs and zero-world contract for the configured dynamic controller."""
import importlib.metadata as metadata
from pathlib import Path
from hold_horizon_task import ROOT,HERE,read,sha,require
from audit_contact_force_observer_closure import validate_bindings
from audit_residual_training_closure import verify_population
from run_support_reach_native import inventory
from run_residual_native import verify_tests
from dynamic_force_policy_v2 import parameters,SOLVER_RUNTIME
from dynamic_qp_solver_v2 import settings
from dynamic_control_failure import FAILED,FAILED_SHA,verify_failure

EVIDENCE=ROOT.parent/"SporeSpore_Evidence"
CONTRACT=HERE/"dynamic_control_component_v2.json"
READBACK=HERE/"floating_dynamics_readback_result_v1.json"
FAILURE=HERE/"contact_posture_failure_result_v1.json"
DEPENDENCIES=HERE/"dynamic_qp_dependencies_v1.json"
LOCK=ROOT/"sdk/adapters/mujoco/requirements-dynamic-qp-lock.txt"
PROVISION="sdk2-dynamic-qp-runtime-aa8130d0f7e34abcbe07e2db07caf30a"
PROVISION_SHA="b3228d4fce463dde8e1e64997e570ff0277930c526671d05bfdd2d93e296058c"
ORIGINAL="sdk2-contact-posture-native-51b63e3d72c24fbd83c604934d836110"
TRIALS=(("reach_hold_left_075_train_001",1440),("posture_hold_left_075_train_001",1231))
INPUTS=("compiled.json","inputs.json","controller.jsonl","model.xml","force-profile.json")
SOURCES=("dynamic_qp_solver_v2.py","dynamic_inverse_dynamics_v2.py","dynamic_force_policy_v2.py","dynamic_hold_control_v2.py",
    "test_dynamic_qp_solver_v2.py","test_dynamic_inverse_dynamics_v2.py","test_dynamic_force_policy_v2.py",
    "dynamic_control_component_task_v2.py","audit_dynamic_control_component_v2.py","run_dynamic_control_component_v2.py",
    "test_dynamic_control_audit_v2.py","provision_dynamic_qp.py","dynamic_control_failure.py")
GATES=(("mechanics","test_actuation_recovery_mechanics",25),("dynamics","test_floating_base_dynamics",22),
    ("native-inputs","test_floating_base_dynamics_inputs",9),("qp","test_dynamic_qp_solver_v2",12),
    ("inverse","test_dynamic_inverse_dynamics_v2",14),("policy","test_dynamic_force_policy_v2",15),
    ("reader","test_dynamic_control_audit_v2",8))
CONTROLS=sum(n for _,_,n in GATES)
FLAGS=("physical_launch_authority","physical_acceptance_authority","training_data_authority","release_authority",
    "equivalence_authority","dynamic_feasibility_established","held_contact_guaranteed",
    "alternative_actions_generated_observations","recovery_benefit_established","tier2_qualified",
    "tier3_benefit_established","capability_estimated","total_target_slew_guaranteed")


def expected_contract():
    return dict(schema_version="locolemotion_dynamic_control_component_contract_v2",
        ledger_scope=dict(subsystem="adaptation",engine_scope="core",authority_mode="retained_dynamic_controller_convergence_successor",
            question_class="development"),
        consumed_predecessor=dict(attempt_id=FAILED,receipt_sha256=FAILED_SHA,command=128,controls_passed=103),
        source_bindings={n:sha(HERE/n) for n in SOURCES},
        parent_results={READBACK.name:sha(READBACK),FAILURE.name:sha(FAILURE)},
        dependency_manifest_sha256=sha(DEPENDENCIES),dependency_lock_sha256=sha(LOCK),
        provisioning_attempt=PROVISION,provisioning_receipt_sha256=PROVISION_SHA,
        original_attempt=ORIGINAL,
        input_bindings={trial:{n:sha(EVIDENCE/ORIGINAL/"physical"/trial/n) for n in INPUTS} for trial,_ in TRIALS},
        trials=[dict(trial_id=t,commands=n) for t,n in TRIALS],commands=2671,post_handoff_commands=2551,
        core_reconstructions=2,complete_reader_invocations=2,unchanged_prefix_commands_per_trial=60,
        original_terminal_prepared_state_included=True,parameters=parameters(),solver_settings=settings(),
        solver_runtime=SOLVER_RUNTIME,contact_acceleration_is_soft_task=True,
        model_equations_absolute_tolerance=2e-6,transferred_equations_absolute_tolerance=4e-6,
        observation_source="all retained original states; synthetic alternative commands never generated observations",
        maximum_stream_bytes=512*2**20,minimum_free_storage_bytes=8*2**30,maximum_reader_wall_seconds=1200,
        controls_required=CONTROLS,safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        synthetic=True,world_build_count=0,solver_steps=0,**{k:False for k in FLAGS})


def declaration():
    c=read(CONTRACT);require(c==expected_contract(),"Dynamic exact component declaration");return c


def verify_owner(path,key,expected_sha,controls,source_count):
    require(sha(path)==expected_sha,"Dynamic parent result identity")
    result=read(path);folder=EVIDENCE/result[key]
    for field,name in (("receipt_sha256","receipt.json"),("declaration_sha256","declaration.json"),
                       ("audit_sha256","audit.json"),("reconstruction_sha256","reconstruction.json")):
        require(sha(folder/name)==result[field],"Dynamic parent retained artifact")
    receipt=read(folder/"receipt.json");decl=read(folder/"declaration.json")
    require(receipt["ok"] is True and receipt["controls_passed"]==controls
        and receipt["source_binding_count"]==source_count and receipt["runtime_binding_count"]==1359
        and read(folder/"audit.json")==read(folder/"reconstruction.json"),"Dynamic complete prior verification")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(decl["binding"])
    require(len(decl["binding"]["source"])==source_count and len(decl["binding"]["runtime"])==1359,
        "Dynamic parent binding denominator")
    for child in folder.glob("*-controls"):
        text=(child/"stderr.log").read_text(encoding="utf-8")
        require(text.rstrip().endswith("OK"),"Dynamic prior controls successful")
    return dict(attempt_id=folder.name,receipt_sha256=sha(folder/"receipt.json"),
        source_bindings=source_count,runtime_bindings=1359,controls_passed=controls)


def verify_inputs(c):
    require(c==declaration(),"Dynamic verified contract")
    parents=[
        verify_owner(READBACK,"attempt_id","e042080786791f93611e353f719cd3c8cff701b1a15be4ceddb3dc35fbf8b247",37,728),
        verify_owner(FAILURE,"verification_attempt","ca6348ed7abfb102af29e4717c46b26177bb5dc9fe8ae8b6601ca88f8757e900",12,699)]
    folder=EVIDENCE/PROVISION;receipt=read(folder/"receipt.json")
    require(sha(folder/"receipt.json")==PROVISION_SHA and receipt["ok"] is True and receipt["pip_check_passed"] is True
        and receipt["old_source_bindings_unchanged"]==728 and receipt["old_runtime_bindings_unchanged"]==1359
        and receipt["world_build_count"]==receipt["solver_steps"]==0,"Dynamic additive dependency receipt")
    actual={p.name:sha(p) for p in folder.iterdir() if p.is_file() and p.name!="receipt.json"}
    require(actual==receipt["artifacts"] and receipt["manifest_sha256"]==sha(DEPENDENCIES)
        and receipt["script_sha256"]==sha(HERE/"provision_dynamic_qp.py","dynamic_control_failure.py"),"Dynamic complete provisioning artifacts")
    manifest=read(DEPENDENCIES)
    versions=dict(manifest["existing_versions"],**{r["name"]:r["version"] for r in manifest["packages"]})
    require({n:metadata.version(n) for n in versions}==versions,"Dynamic exact additive runtime versions")
    before=read(folder/"before-packages.json");after=read(folder/"after-packages.json")
    require(all(after[n]==v for n,v in before.items()),"Dynamic no replaced packages")
    for trial,files in c["input_bindings"].items():
        for name,digest in files.items():require(sha(EVIDENCE/ORIGINAL/"physical"/trial/name)==digest,"Dynamic full retained input")
    return dict(parents=parents,provisioning_receipt_sha256=PROVISION_SHA,versions=versions,consumed_predecessor=verify_failure())
