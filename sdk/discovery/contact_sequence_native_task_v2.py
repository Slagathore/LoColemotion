"""Fresh lifecycle successor; all scientific inputs remain bound to native v1."""
import copy
import contact_sequence_native_task_v1 as previous
from contact_sequence_native_task_v1 import (ROOT,HERE,FLAGS,MODEL,PARENT_CLOSURE,
    DIAGNOSIS,COMPONENT_CONTRACT,COMPONENT_RESULT,COMPONENT_SHA,COVERAGE_RESULT,
    read,sha,require,bridge,provider,controller_contract,initial_arrays,frozen_model,
    retained,DLL,DLL_SHA,profile_for,controller_for,verify_component,verify_gate_coverage)

CONTRACT=HERE/"contact_sequence_native_v2.json"
FAILED_RESULT=HERE/"contact_sequence_native_prelaunch_failure_v1.json"
FAILED_SHA="faf277eac5ee49110e8ab9bb034bd45441b058ec7f419c22253215a02d6578c5"
LIFECYCLE_RESULT=HERE/"contained_stage_cleanup_result_v2.json"
LIFECYCLE_SHA="2da4bf09487b6a5d8bd2826ee9c389768df2af24b1e0b756c8a5636672cc6de7"
PREDECESSORS=dict(
    failed_native=dict(attempt_id="sdk2-contact-sequence-native-v1-111482303b2140a2a51f85ca79e708f8",
        receipt_sha256="7676172756c0b0587ca9ba09cb507952f664330d831d605c20760a187c5ffef0",
        result_sha256=FAILED_SHA),
    lifecycle_diagnostic=dict(attempt_id="sdk2-contained-stage-diagnostic-v2-b55cad837104470081c6d19b8c51bedf",
        receipt_sha256="d5013be13ce2dad9daa8f36eeb91c45bc503eb4599c60537388ebb96d7086bfd",
        result_sha256=LIFECYCLE_SHA))
SOURCES=("contact_sequence_native_task_v2.py","contact_sequence_native_trial_v2.py",
    "contact_sequence_native_v2.py","contact_sequence_native_trial_audit_v2.py",
    "audit_contact_sequence_native_v2.py","run_contact_sequence_native_v2.py",
    "test_contact_sequence_native_v2.py","test_contact_sequence_containment_v2.py",
    "contained_stage_owner_v2.py","test_contained_stage_owner_v2.py",
    "run_contained_stage_diagnostic_v2.py")
ROUTE_CONTROLS=52
GATES=(*previous.GATES,("contained-stage-lifecycle-v2","test_contained_stage_owner_v2",17),
    ("contact-sequence-native-v2","test_contact_sequence_native_v2",ROUTE_CONTROLS))
EXPECTED_CONTROLS=sum(n for _,_,n in GATES)+3
IDENTITY_FIELDS=frozenset(("schema_version","lane","production_entrypoints",
    "independent_selected_row_reader","gate_applicability","safety_controls",
    "complete_safety_control_count","implementation_bindings","inherited_source_bindings"))


def expected_declaration():
    c=copy.deepcopy(previous.declaration())
    c.update(schema_version="locolemotion_contact_sequence_native_contract_v2",
        lane="contact_sequence_native_v2",
        lifecycle_predecessors=copy.deepcopy(PREDECESSORS),
        previous_contact_native_contract_sha256=sha(previous.CONTRACT),
        stage_owner=dict(module="contained_stage_owner_v2",class_name="OwnedChild",
            invoke="run_contact_sequence_native_v2:invoke",cleanup_seconds=10.,
            exact_job_membership=True,stable_handles=True,pid_reopened_after_job_close=False,
            scope=["every gate stage","containment gate","runtime preflight","physical worker",
                "audit reader","reconstruction reader"]),
        gate_applicability=dict(prior_declared_controls=previous.EXPECTED_CONTROLS,
            prior_complete_gate_passed=False,prior_controls_retained=True,
            added_lifecycle_controls=17,new_route_controls=ROUTE_CONTROLS,total=EXPECTED_CONTROLS,
            containment_control="original assertions with retained-handle owner substitution"),
        safety_controls=[dict(name=n,module=m,count=k) for n,m,k in GATES],
        complete_safety_control_count=EXPECTED_CONTROLS,
        implementation_bindings={name:sha(HERE/name) for name in SOURCES},
        inherited_source_bindings={**c["inherited_source_bindings"],
            **{name:sha(HERE/name) for name in previous.SOURCES}})
    for key in ("worker","native_trial","trial_reader"):
        c["production_entrypoints"][key]=c["production_entrypoints"][key].replace("_v1.py:","_v2.py:")
    c["independent_selected_row_reader"]=c["independent_selected_row_reader"].replace("_v1.py:","_v2.py:")
    require(previous.EXPECTED_CONTROLS==1546 and EXPECTED_CONTROLS==1615
        and len({n for n,_,_ in GATES})==len(GATES)
        and len({m for _,m,_ in GATES})==len(GATES),"Contact v2 exact complete gate mapping")
    validate_science(c,previous.declaration())
    return c


def validate_science(c,parent):
    """Only route identity, lifecycle evidence and gate bindings may differ."""
    require(all(c.get(k)==v for k,v in parent.items() if k not in IDENTITY_FIELDS),
        "Contact v2 scientific contract changed")
    for key in ("candidate","reference","resolver","stepping"):
        require(c["production_entrypoints"][key]==parent["production_entrypoints"][key],
            "Contact v2 production science changed")


def declaration():
    c=read(CONTRACT)
    require(c==expected_declaration(),"Contact v2 exact contract")
    return c


def plans(c):
    validate_science(c,previous.declaration())
    return [dict(p,stage="contact_sequence_native_v2") for p in previous.plans(c)]


def validate_lifecycle_documents(failed,result,receipt,decl):
    require(all(failed[k]==v for k,v in PREDECESSORS["failed_native"].items() if k!="result_sha256")
        and failed["accepted_controls"]==1091 and failed["complete_gate_required"]==1546
        and failed["complete_gate_passed"] is False
        and failed["constructed_cpu_worlds"]==failed["constructed_gpu_worlds"]==0
        and failed["original_incident_cause_established"] is False,"Contact v2 failed predecessor scope")
    require(result["attempt_id"]==PREDECESSORS["lifecycle_diagnostic"]["attempt_id"]
        and result["receipt_sha256"]==PREDECESSORS["lifecycle_diagnostic"]["receipt_sha256"]
        and result["status"]=="verified_finite_stable_handle_cleanup_diagnostic"
        and result["controls_passed"]==receipt["controls_passed"]==decl["controls_planned"]==42
        and result["lifecycle_controls"]==17 and result["original_selector_controls"]==25
        and result["cleanup_reports"]==16 and result["expected_negative_cleanup_reports"]==2
        and receipt["ok"] is True and receipt["source_runtime_unchanged"] is True
        and result["source_runtime_unchanged"] is True
        and result["original_native_attempt"]==receipt["failed_parent"]
        and result["cleanup_population"]==receipt["cleanup_population"],"Contact v2 lifecycle scope")
    for value in (result,receipt,decl):
        require(value["worlds_opened"]==value["solver_steps"]==0
            and value["physical_acceptance_authority"] is False and value["release_authority"] is False
            and value["training_data_authority"] is False and value["tier2_qualified"] is False
            and value["tier3_benefit_established"] is False
            and value["original_incident_cause_established"] is False,"Contact v2 lifecycle authority")


def verify_lifecycle(evidence):
    from run_contained_stage_diagnostic_v2 import verify_failed_parent,cleanup_population,CONTROLS
    from audit_contact_force_observer_closure import validate_bindings
    from audit_residual_training_closure import verify_population
    from run_contact_sequence_native_v1 import inventory
    from run_residual_native import verify_tests
    require(sha(FAILED_RESULT)==FAILED_SHA and sha(LIFECYCLE_RESULT)==LIFECYCLE_SHA,
        "Contact v2 lifecycle closure hashes")
    failed=read(FAILED_RESULT);result=read(LIFECYCLE_RESULT)
    folder=evidence/PREDECESSORS["lifecycle_diagnostic"]["attempt_id"]
    receipt=read(folder/"receipt.json");decl=read(folder/"declaration.json")
    require(sha(folder/"receipt.json")==result["receipt_sha256"]
        and sha(folder/"declaration.json")==result["declaration_sha256"],"Contact v2 lifecycle retained hashes")
    validate_lifecycle_documents(failed,result,receipt,decl)
    require(verify_failed_parent()==result["original_native_attempt"],"Contact v2 failed predecessor reconstruction")
    require(cleanup_population(folder)==result["cleanup_population"],"Contact v2 complete retained cleanup population")
    verify_population(receipt["artifacts"],inventory(folder));validate_bindings(decl["binding"])
    for name,module,count in CONTROLS:verify_tests(folder/(name+"-controls"),count)
    for name,digest in result["source_bindings"].items():
        require(sha(HERE/name)==digest,"Contact v2 lifecycle source bytes")
    return dict(ok=True,predecessors=copy.deepcopy(PREDECESSORS),controls_passed=42,
        cleanup_reports=16,expected_negative_cleanup_reports=2,worlds_opened=0,solver_steps=0,
        original_incident_cause_established=False,physical_acceptance_authority=False,release_authority=False)


def validate_launch_documents(owner,gate,consumed,c,source,attempt_id,declaration_sha,gate_sha):
    require(attempt_id.startswith("sdk2-contact-sequence-native-v2-") and owner["source_commit"]==source
        and owner["contract"]==c and owner["planned_trials"]==plans(c) and owner["source_status"]==[]
        and owner["component_only"] is False and all(owner[k] is False for k in FLAGS),
        "Contact v2 owner scope/clean source")
    require(gate["ok"] is True and gate["source_commit"]==source and gate["declaration_sha256"]==declaration_sha
        and gate["safety_controls"]=={**{n:k for n,_,k in GATES},"provider":2,"containment":1}
        and gate["preflight"]["ok"] is True and gate["preflight"]["component_evidence_verified"] is True
        and gate["preflight"]["gate_coverage_verified"] is True
        and gate["preflight"].get("lifecycle_evidence_verified") is True
        and gate["preflight"].get("lifecycle_evidence",{}).get("predecessors")==PREDECESSORS
        and gate["preflight"]["world_build_count"]==gate["preflight"]["solver_steps"]==0,
        "Contact v2 complete zero-world launch gate")
    require(consumed==dict(attempt_id=attempt_id,source_commit=source,contract_sha256=sha(CONTRACT),
        declaration_sha256=declaration_sha,gate_receipt_sha256=gate_sha,trials=plans(c)),
        "Contact v2 single-use consumed identity")


def launch_records(folder,c,source):
    attempt=folder.parent
    require(folder.name=="physical" and attempt.name.startswith("sdk2-contact-sequence-native-v2-")
        and attempt.parent.resolve()==(ROOT.parent/"SporeSpore_Evidence").resolve(),"Contact v2 durable output boundary")
    owner,gate,consumed=[read(attempt/name) for name in ("declaration.json","gate-receipt.json","consumed.json")]
    validate_launch_documents(owner,gate,consumed,c,source,attempt.name,sha(attempt/"declaration.json"),sha(attempt/"gate-receipt.json"))
    return owner
